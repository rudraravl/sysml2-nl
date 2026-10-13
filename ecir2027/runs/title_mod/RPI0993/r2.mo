model AckermannRoverClimbC
  extends Modelica.Icons.Example;

  // ===== Requirement-specified parameters =====
  parameter Real m = 34.0 "chassis mass [kg]";
  parameter Real chassisL = 1.05 "chassis length [m]";
  parameter Real chassisW = 0.64 "chassis width [m]";
  parameter Real wheelbase = 0.74 "wheelbase [m]";
  parameter Real delta_max = 0.52 "front steering joint limit [rad]";
  parameter Real tau_max = 25.8 "maximum command magnitude [N.m]";
  parameter Real mu = 0.76 "friction coefficient [-]";
  parameter Real ridge_h = 0.05 "surface ridge height [m]";
  parameter Real ramp_deg = 12.0 "ramp angle [deg]";
  parameter Real ramp_angle = ramp_deg*Modelica.Constants.pi/180.0 "ramp angle [rad]";
  parameter Real L_plateau = 2.0 "plateau length [m]";
  parameter Real t_final = 12.0 "run duration [s]";
  parameter Real F_payload = 135.0 "payload disturbance force [N]";
  parameter Real slip_limit = 0.35 "slip ratio limit [-]";
  parameter Real angle_limit = 0.40 "roll/pitch limit [rad]";
  parameter Real e_track_limit = 0.189 "primary tracking error limit after 7.8 s [m/s]";
  parameter Real t_settle = 7.8 "tracking-error evaluation time [s]";

  // ===== Assumed parameters (NOT specified in requirement; labeled, not fabricated as fact) =====
  parameter Real R_w = 0.10 "wheel radius [m] // assumed; not specified in requirement";
  parameter Real J_w = 0.05 "rear axle inertia [kg.m2] // assumed; not specified";
  parameter Real C_rr = 0.02 "rolling resistance coefficient [-] // assumed";
  parameter Real v_cruise = 0.6 "cruise speed reference [m/s] // assumed reference";
  parameter Real a_brake = 0.3 "nominal braking deceleration [m/s2] // assumed";
  parameter Real L_ramp = 1.5 "ramp length [m] // assumed; only plateau (2 m) specified";
  parameter Real x_ramp_start = 0.5 "approach length [m] // assumed";
  parameter Real ridge_w = 0.20 "ridge half-width [m] // assumed";
  parameter Real x_ridge1_offset = 0.4 "first ridge offset past ramp end [m] // assumed";
  parameter Real x_ridge2_offset = 1.3 "second ridge offset past ramp end [m] // assumed";
  parameter Real stop_margin = 0.3 "stopping margin before descending edge [m] // assumed";
  parameter Real Kp_v = 80.0 "speed tracking proportional gain // assumed";
  parameter Real Ki_v = 120.0 "speed tracking integral gain // assumed";
  parameter Real int_e_max = 5.0 "anti-windup bound on integral error // assumed";
  parameter Real k_pitch = 400.0 "pitch restoring stiffness [N.m/rad] // assumed";
  parameter Real c_pitch = 40.0 "pitch damping [N.m.s/rad] // assumed";
  parameter Real k_roll = 600.0 "roll restoring stiffness [N.m/rad] // assumed";
  parameter Real c_roll = 50.0 "roll damping [N.m.s/rad] // assumed";
  parameter Real tau_delta = 0.1 "steering actuator time constant [s] // assumed";
  parameter Real v_eps = 0.05 "slip-ratio denominator floor [m/s] // zero-error branch";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";

  // Derived geometry
  parameter Real x_ramp_end = x_ramp_start + L_ramp;
  parameter Real x_edge = x_ramp_end + L_plateau;
  parameter Real x_stop = x_edge - stop_margin;
  parameter Real d_brake = v_cruise*v_cruise/(2.0*a_brake);
  parameter Real x_ridge1 = x_ramp_end + x_ridge1_offset;
  parameter Real x_ridge2 = x_ramp_end + x_ridge2_offset;
  parameter Real J_pitch = m*chassisL*chassisL/12.0 "uniform-rod assumption // assumed";
  parameter Real J_roll = m*chassisW*chassisW/12.0 "uniform-rod assumption // assumed";

  // Dynamic states
  Real x(start=0.0, fixed=true) "longitudinal position [m]";
  Real v(start=0.0, fixed=true) "longitudinal speed [m/s]";
  Real theta(start=0.0, fixed=true) "pitch angle [rad]";
  Real omega_pitch(start=0.0, fixed=true) "pitch rate [rad/s]";
  Real phi_roll(start=0.0, fixed=true) "roll angle [rad]";
  Real omega_roll(start=0.0, fixed=true) "roll rate [rad/s]";
  Real omega_w(start=0.0, fixed=true) "rear wheel angular speed [rad/s]";
  Real delta(start=0.0, fixed=true) "front steering angle [rad]";
  Real int_e(start=0.0, fixed=true) "integral of tracking error [m]";

  // Terrain
  Real grade "terrain grade [rad]";
  Real h_terrain "terrain height [m]";
  Real h_ridge "ridge bump height [m]";
  Real dh_ridge_dx "ridge local slope [-]";
  Real local_slope "effective slope including ridges [rad]";

  // Forces and slip
  Real N_load "normal load [N]";
  Real F_traction "tractive force [N]";
  Real F_grade "grade gravity force [N]";
  Real F_roll "rolling resistance [N]";
  Real F_payload_force "payload disturbance force [N]";
  Real slip_ratio "wheel slip ratio [-]";

  // Control
  Real v_ref "speed reference [m/s]";
  Real e_track "primary tracking error [m/s]";
  Real e_track_abs "abs tracking error [m/s]";
  Real anti_windup "anti-windup gating factor [-]";
  Real tau_raw "unbounded torque command [N.m]";
  Real slip_factor "slip-aware reduction factor [-]";
  Real tau_pre "torque before final saturation [N.m]";
  Real tau "bounded rear traction torque command [N.m]";
  Real delta_cmd_raw "raw steering command [rad]";
  Real delta_cmd "bounded steering command [rad]";

  // Sensors
  Real v_meas "encoder-measured speed [m/s]";
  Real pitch_meas "IMU-measured pitch [rad]";
  Real roll_meas "IMU-measured roll [rad]";
  Real edge_dist "forward depth-sensor edge distance [m]";

equation
  // ----- Terrain geometry -----
  grade = if x < x_ramp_start then 0.0
          elseif x < x_ramp_end then ramp_angle
          else 0.0;
  h_terrain = if x < x_ramp_start then 0.0
              elseif x < x_ramp_end then ramp_angle*(x - x_ramp_start)
              else ramp_angle*L_ramp;
  h_ridge = ridge_h*exp(-((x - x_ridge1)/ridge_w)^2)
          + ridge_h*exp(-((x - x_ridge2)/ridge_w)^2);
  dh_ridge_dx = ridge_h*(-2.0*(x - x_ridge1)/ridge_w^2)*exp(-((x - x_ridge1)/ridge_w)^2)
              + ridge_h*(-2.0*(x - x_ridge2)/ridge_w^2)*exp(-((x - x_ridge2)/ridge_w)^2);
  local_slope = grade + dh_ridge_dx;

  // ----- Load and resistance forces -----
  N_load = m*g*cos(local_slope);
  F_grade = m*g*sin(local_slope);
  F_roll = C_rr*N_load;
  F_payload_force = if (time >= t_final/3.0 and time <= 2.0*t_final/3.0) then -F_payload else 0.0;

  // ----- Slip and traction (well-defined denominator branch) -----
  slip_ratio = (R_w*omega_w - v)/max(abs(v), v_eps);
  F_traction = mu*N_load*tanh(slip_ratio/0.15);

  // ----- Longitudinal + wheel dynamics -----
  der(x) = v;
  der(v) = (F_traction - F_grade - F_roll + F_payload_force)/m;
  der(omega_w) = (tau - F_traction*R_w)/J_w;

  // ----- Pitch dynamics (tracks effective terrain slope) -----
  der(theta) = omega_pitch;
  der(omega_pitch) = (k_pitch*(local_slope - theta) - c_pitch*omega_pitch)/J_pitch;

  // ----- Roll dynamics (straight climb, damped about zero) -----
  der(phi_roll) = omega_roll;
  der(omega_roll) = (-k_roll*phi_roll - c_roll*omega_roll)/J_roll;

  // ----- Steering actuator (independently bounded) -----
  delta_cmd_raw = 0.0 "straight ascent commanded; lateral lane not specified";
  delta_cmd = if delta_cmd_raw > delta_max then delta_max
              elseif delta_cmd_raw < -delta_max then -delta_max
              else delta_cmd_raw;
  der(delta) = (delta_cmd - delta)/tau_delta;

  // ----- Speed reference profile (stop before descending edge) -----
  v_ref = v_cruise * (if (x_stop - x)/d_brake < 0.0 then 0.0
                      elseif (x_stop - x)/d_brake > 1.0 then 1.0
                      else (x_stop - x)/d_brake);

  // ----- Tracking error with anti-windup -----
  e_track = v_ref - v;
  e_track_abs = abs(e_track);
  anti_windup = if (int_e > int_e_max and e_track > 0.0) or
                   (int_e < -int_e_max and e_track < 0.0) then 0.0 else 1.0;
  der(int_e) = e_track*anti_windup;

  // ----- Slip-aware traction control with bounded braking -----
  tau_raw = Kp_v*e_track + Ki_v*int_e;
  slip_factor = 1.0 - (if (abs(slip_ratio) - 0.25)/0.10 < 0.0 then 0.0
                      elseif (abs(slip_ratio) - 0.25)/0.10 > 1.0 then 1.0
                      else (abs(slip_ratio) - 0.25)/0.10);
  tau_pre = tau_raw*slip_factor;
  tau = if tau_pre > tau_max then tau_max
        elseif tau_pre < -tau_max then -tau_max
        else tau_pre;

  // ----- Instrumentation -----
  v_meas = v + 0.002*Modelica.Math.sin(2.0*Modelica.Constants.pi*3.0*time);
  pitch_meas = theta + 0.001*Modelica.Math.sin(2.0*Modelica.Constants.pi*2.0*time);
  roll_meas = phi_roll + 0.001*Modelica.Math.cos(2.0*Modelica.Constants.pi*1.5*time);
  edge_dist = x_edge - x;

  // ----- Requirement monitors (non-fatal; preserve traces) -----
  assert(abs(tau) <= tau_max + 1e-6, "Rear traction actuator limit violated",
         AssertionLevel.error);
  assert(abs(slip_ratio) < slip_limit, "Slip ratio limit exceeded",
         AssertionLevel.warning);
  assert(abs(theta) < angle_limit, "Pitch angle limit exceeded",
         AssertionLevel.warning);
  assert(abs(phi_roll) < angle_limit, "Roll angle limit exceeded",
         AssertionLevel.warning);
  assert(x < x_edge, "Stopping margin violated: overshot descending edge",
         AssertionLevel.warning);
  assert(time < t_settle or e_track_abs < e_track_limit,
         "Primary tracking error limit exceeded after 7.8 s",
         AssertionLevel.warning);
  assert(abs(v) < 1e6 and abs(x) < 1e6 and abs(theta) < 1e6 and
         abs(phi_roll) < 1e6 and abs(slip_ratio) < 1e6 and abs(tau) < 1e6,
         "Non-finite physical/control/estimator value detected",
         AssertionLevel.error);

  annotation (
    Documentation(info="AckermannRoverClimbC: floating-base rear-wheel-drive rover ascending a 12 deg ramp, traversing a 2 m plateau with two 0.05 m ridges, and stopping before the descending edge. Slip-aware traction control with bounded braking (25.8 N.m) and 135 N payload disturbance in the middle third. Logged at 125 Hz over 12 s. Parameters not stated in the requirement are marked assumed; only requirement-specified numerics are treated as fact."),
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1e-6, NumberOfIntervals=1500));
end AckermannRoverClimbC;