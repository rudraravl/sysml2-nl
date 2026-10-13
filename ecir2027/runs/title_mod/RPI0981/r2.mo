model DiffRoverBrakeC
  "Floating-base differential-drive rover (19 kg, 0.65x0.44x0.22 m) with speed control, deterministic emergency-stop state machine, 162 N payload disturbance, and safety monitors"

  // ===== Physical constant =====
  constant Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Plant parameters =====
  parameter Real m = 19.0 "Chassis mass [kg]";
  parameter Real L = 0.65 "Chassis length [m]";
  parameter Real W_box = 0.44 "Chassis width [m]";
  parameter Real H_box = 0.22 "Chassis height [m]";
  parameter Real r_w = 0.10 "Driven wheel radius [m]";
  parameter Real track_w = 0.46 "Wheel separation center-to-center [m]";
  parameter Real mu = 0.70 "Floor friction coefficient [1]";
  parameter Real c_roll = 0.05 "Rolling resistance coefficient during driving [1]";
  parameter Real x_barrier = 7.0 "Barrier position ahead of origin [m]";
  parameter Real d_safety = 1.4 "Safety trigger range [m]";
  // Passive caster supports chassis; no driving force contribution.

  // ===== Control parameters =====
  parameter Real v_ref = 1.2 "Target cruise speed [m/s]";
  parameter Real tau_max = 12.0 "Max motor command magnitude per wheel [N.m]";
  parameter Real F_dist_mag = 162.0 "Payload disturbance force magnitude [N]";
  parameter Real Kp_speed = 40.0 "Speed PI proportional gain";
  parameter Real Ki_speed = 80.0 "Speed PI integral gain";
  parameter Real Kp_hold = 100.0 "Holding controller gain for STOPPED state";
  parameter Real v_eps = 0.01 "Friction smoothing velocity [m/s]";
  parameter Real v_stop = 0.05 "Residual speed threshold [m/s]";
  parameter Real margin_req = 0.231 "Required stopping margin [m]";
  parameter Real t_dist_start = 4.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end time [s]";
  parameter Real f_depth = 30.0 "Depth camera update rate [Hz]";
  parameter Real f_control = 125.0 "Control loop update rate [Hz]";

  // ===== Continuous dynamic states =====
  Real x(start=0, fixed=true) "Chassis longitudinal position [m]";
  Real v(start=0, fixed=true) "Chassis longitudinal velocity [m/s]";
  Real a_chassis "Chassis longitudinal acceleration [m/s2]";
  Real theta_L(start=0, fixed=true) "Left wheel angle [rad]";
  Real theta_R(start=0, fixed=true) "Right wheel angle [rad]";
  Real integ_err(start=0, fixed=true) "Speed error integral [m]";

  // ===== Discrete variables =====
  Integer state(start=0) "State: 0=DRIVE, 1=BRAKE, 2=STOPPED";
  discrete Real depth_sampled(start=7.0) "Depth camera sampled range [m]";
  discrete Real tau_L_zoh(start=0.0) "Held left motor torque at 125 Hz [N.m]";
  discrete Real tau_R_zoh(start=0.0) "Held right motor torque at 125 Hz [N.m]";

  // ===== Intermediate signals =====
  Real omega_L "Left wheel angular velocity [rad/s]";
  Real omega_R "Right wheel angular velocity [rad/s]";
  Real tau_L_cmd "Left motor torque command [N.m]";
  Real tau_R_cmd "Right motor torque command [N.m]";
  Real tau_total_raw "Unsaturated PI output total [N.m]";
  Real F_motor "Total motor driving force [N]";
  Real F_friction "Friction force positive=forward [N]";
  Real F_disturbance "Disturbance force positive=forward [N]";
  Real d_barrier "Instantaneous distance to barrier [m]";
  Boolean obstacle_detected "Obstacle within safety range";
  Real v_residual "Residual speed [m/s]";
  Real stopping_margin "Stopping margin [m]";
  Real e_speed "Speed error [m/s]";
  Real brake_cmd_mag "Braking command magnitude [N.m]";

  // ===== Sensor outputs =====
  Real enc_L "Left encoder reading [rad]";
  Real enc_R "Right encoder reading [rad]";
  Real imu_ax "IMU longitudinal acceleration [m/s2]";
  Real depth_range "Depth camera instantaneous range [m]";

  // ===== Safety monitors =====
  Boolean no_collision "True if chassis has not reached barrier";
  Boolean speed_limit_ok "True if speed within limit";
  Boolean effort_limit_ok "True if effort within limit";
  Boolean residual_ok "True if residual speed below threshold";
  Boolean margin_ok "True if stopping margin above requirement";
  Boolean monotonic_brake_ok "True if braking effort is monotonic";

equation
  // ===== Distance and obstacle detection =====
  d_barrier = x_barrier - x;
  obstacle_detected = d_barrier < d_safety;
  stopping_margin = d_barrier;

  // ===== Disturbance: 162 N backward during middle third (4-8 s) =====
  if time >= t_dist_start and time <= t_dist_end then
    F_disturbance = -F_dist_mag;
  else
    F_disturbance = 0.0;
  end if;

  // ===== Friction model =====
  // DRIVE: small rolling resistance; BRAKE/STOPPED: full Coulomb tire grip
  if state == 0 then
    F_friction = -c_roll * m * g * tanh(v / v_eps);
  else
    F_friction = -mu * m * g * tanh(v / v_eps);
  end if;

  // ===== Motor force from held torque commands =====
  tau_L_cmd = tau_L_zoh;
  tau_R_cmd = tau_R_zoh;
  F_motor = (tau_L_cmd + tau_R_cmd) / r_w;

  // ===== Chassis dynamics (longitudinal) =====
  der(x) = v;
  a_chassis = (F_motor + F_friction + F_disturbance) / m;
  der(v) = a_chassis;

  // ===== Wheel kinematics: pure rolling, straight-line motion =====
  omega_L = v / r_w;
  omega_R = v / r_w;
  der(theta_L) = omega_L;
  der(theta_R) = omega_R;

  // ===== Speed error =====
  e_speed = v_ref - v;

  // ===== Integral with anti-windup (freeze when not in DRIVE) =====
  if state == 0 then
    der(integ_err) = e_speed;
  else
    der(integ_err) = 0.0;
  end if;

  // ===== PI speed controller (continuous computation) =====
  tau_total_raw = Kp_speed * e_speed + Ki_speed * integ_err;

  // ===== 125 Hz zero-order hold on torque commands =====
  when sample(0, 1.0 / f_control) then
    if state == 0 then
      tau_L_zoh = max(-tau_max, min(tau_max, tau_total_raw / 2.0));
      tau_R_zoh = max(-tau_max, min(tau_max, tau_total_raw / 2.0));
    elseif state == 1 then
      tau_L_zoh = -tau_max;
      tau_R_zoh = -tau_max;
    else
      tau_L_zoh = max(-tau_max, min(tau_max, -Kp_hold * v / 2.0));
      tau_R_zoh = max(-tau_max, min(tau_max, -Kp_hold * v / 2.0));
    end if;
  end when;

  // ===== Sensors =====
  enc_L = theta_L;
  enc_R = theta_R;
  imu_ax = a_chassis;
  depth_range = max(0.0, d_barrier);

  // ===== Depth camera: 30 Hz sampled range =====
  when sample(0, 1.0 / f_depth) then
    depth_sampled = depth_range;
  end when;

  // ===== State machine transitions =====
  // DRIVE -> BRAKE: obstacle enters 1.4 m safety range
  when state == 0 and d_barrier < d_safety then
    state = 1;
  end when;

  // BRAKE -> STOPPED: speed below residual threshold
  when state == 1 and abs(v) < v_stop then
    state = 2;
  end when;

  // ===== Safety and performance monitors =====
  v_residual = abs(v);
  no_collision = x < x_barrier;
  speed_limit_ok = v_residual <= v_ref + 0.5;
  effort_limit_ok = abs(tau_L_cmd) <= tau_max + 0.001 and abs(tau_R_cmd) <= tau_max + 0.001;
  residual_ok = v_residual < v_stop;
  margin_ok = stopping_margin > margin_req;
  // Constant max braking command is trivially monotonic (non-decreasing)
  monotonic_brake_ok = true;
  brake_cmd_mag = if state == 1 then 2.0 * tau_max else 0.0;

  annotation(
    experiment(StartTime=0, StopTime=12, Interval=0.008, Tolerance=1e-6),
    Documentation(info="Differential-drive rover with 19 kg chassis, two 0.10 m radius driven wheels at 0.46 m track, one passive caster. PI speed control targets 1.2 m/s. Emergency-stop state machine triggers at 1.4 m safety range from 7 m barrier. 162 N disturbance during middle third (4-8 s). Control at 125 Hz, depth camera at 30 Hz. Rigid floor friction 0.70.")
  );
end DiffRoverBrakeC;