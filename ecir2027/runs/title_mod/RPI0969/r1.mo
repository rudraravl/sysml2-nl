model DiffRoverClimbC
  // -------------------------------------------------------------------
  // Physical parameters
  // -------------------------------------------------------------------
  parameter Real m        = 19.0  "chassis mass [kg]";
  parameter Real Lx       = 0.65  "chassis length [m]";
  parameter Real Ly       = 0.44  "chassis width [m]";
  parameter Real Lz       = 0.22  "chassis height [m]";
  parameter Real r_w      = 0.10  "driven wheel radius [m]";
  parameter Real b_w      = 0.46  "wheel separation [m]";
  parameter Real mu       = 0.76  "friction coefficient [1]";
  parameter Real g        = 9.81  "gravitational acceleration [m/s2]";
  parameter Real J_w      = 0.02  "wheel inertia [kg.m2]";
  parameter Real C_traction = 200.0 "tire longitudinal stiffness [N.s/m]";
  parameter Real F_drag_k = 0.5   "linear drag coefficient [N.s/m]";

  // -------------------------------------------------------------------
  // Mission parameters
  // -------------------------------------------------------------------
  parameter Real ramp_deg   = 12.0  "ramp inclination [deg]";
  parameter Real ridge_h    = 0.05  "ridge height [m]";
  parameter Real s_ramp1    = 2.0   "ramp start position [m]";
  parameter Real s_ramp2    = 4.0   "ramp end / plateau start [m]";
  parameter Real s_plateau2 = 6.0   "plateau end / descending edge [m]";
  parameter Real s_stop     = 5.8   "stopping target with margin [m]";
  parameter Real s_ridgeA   = 1.0   "first ridge center [m]";
  parameter Real s_ridgeB   = 4.7   "second ridge center [m]";
  parameter Real ridge_w    = 0.05  "ridge interaction width [m]";
  parameter Real ridge_F    = 30.0  "ridge resistance pulse amplitude [N]";
  parameter Real F_payload  = 135.0 "payload disturbance force [N]";
  parameter Real t_dist1   = 4.0   "disturbance start [s]";
  parameter Real t_dist2   = 8.0   "disturbance end [s]";

  // -------------------------------------------------------------------
  // Controller / requirement parameters
  // -------------------------------------------------------------------
  parameter Real tau_max        = 12.0   "max command magnitude [N.m]";
  parameter Real slip_max       = 0.35   "slip ratio limit [1]";
  parameter Real pitch_max      = 0.40   "pitch limit [rad]";
  parameter Real roll_max       = 0.40   "roll limit [rad]";
  parameter Real v_track_tol    = 0.189  "tracking error tolerance [m/s]";
  parameter Real t_track_check  = 7.8    "tracking check time [s]";
  parameter Real v_cruise       = 1.20   "cruise speed [m/s]";
  parameter Real a_brake        = 1.0    "reference braking deceleration [m/s2]";
  parameter Real Kp_v           = 1500.0 "velocity proportional gain [N.s/m]";
  parameter Real Kp_pos         = 1500.0 "position hold gain (active near stop) [N/m]";
  parameter Real s_brake_zone   = 0.50   "braking zone width [m]";
  parameter Real eps             = 1.0e-3 "division guard [m/s]";

  // -------------------------------------------------------------------
  // Simulation parameters
  // -------------------------------------------------------------------
  parameter Real T_end    = 12.0 "simulation horizon [s]";
  parameter Real f_sample = 125.0 "loop rate [Hz]";
  parameter Real Ts       = 1.0/f_sample "sample period [s]";

  // -------------------------------------------------------------------
  // Dynamic states
  // -------------------------------------------------------------------
  Real s(start=0.0, fixed=true)        "path position [m]";
  Real v(start=0.0, fixed=true)        "longitudinal speed [m/s]";
  Real omega_L(start=0.0, fixed=true)  "left wheel angular velocity [rad/s]";
  Real omega_R(start=0.0, fixed=true)  "right wheel angular velocity [rad/s]";

  // -------------------------------------------------------------------
  // Algebraic physical quantities
  // -------------------------------------------------------------------
  Real ramp_angle  "local path inclination [rad]";
  Real theta       "chassis pitch [rad]";
  Real phi         "chassis roll [rad]";
  Real F_grav      "gravity along path [N]";
  Real N_normal    "total normal load [N]";
  Real F_tr_max    "friction-limited total traction [N]";
  Real F_tr_L      "left wheel traction force [N]";
  Real F_tr_R      "right wheel traction force [N]";
  Real slip_state_L "left wheel slip velocity [m/s]";
  Real slip_state_R "right wheel slip velocity [m/s]";
  Real slip_L      "left slip ratio [1]";
  Real slip_R      "right slip ratio [1]";
  Real slip_avg    "average slip ratio [1]";
  Real F_dist      "payload disturbance force [N]";
  Real F_ridge     "ridge resistance force [N]";
  Real F_drag      "linear drag force [N]";

  // -------------------------------------------------------------------
  // Controller quantities
  // -------------------------------------------------------------------
  Real slip_gain      "slip-aware torque scaling [1]";
  Real v_ref         "reference velocity [m/s]";
  Real v_err         "velocity tracking error [m/s]";
  Real s_err         "position-to-stop error [m]";
  Real position_term "position hold contribution (gated to braking zone) [N]";
  Real F_cmd_total   "commanded total traction force [N]";
  Real tau_cmd       "commanded wheel torque per wheel [N.m]";
  Real tau_L         "applied left wheel torque [N.m]";
  Real tau_R         "applied right wheel torque [N.m]";

  // -------------------------------------------------------------------
  // Sensors
  // -------------------------------------------------------------------
  Real v_enc      "encoder-measured speed [m/s]";
  Real pitch_imu  "IMU pitch [rad]";
  Real roll_imu   "IMU roll [rad]";
  Real d_depth    "forward depth to descending edge [m]";

  // -------------------------------------------------------------------
  // Synchronized traces (state, command, sensor)
  // -------------------------------------------------------------------
  output Real trace_t          "time [s]";
  output Real trace_s          "position [m]";
  output Real trace_v          "velocity [m/s]";
  output Real trace_theta      "pitch [rad]";
  output Real trace_phi        "roll [rad]";
  output Real trace_omega_L    "left wheel angular velocity [rad/s]";
  output Real trace_omega_R    "right wheel angular velocity [rad/s]";
  output Real trace_tau_L      "left torque [N.m]";
  output Real trace_tau_R      "right torque [N.m]";
  output Real trace_slip        "average slip ratio [1]";
  output Real trace_v_enc       "encoder speed [m/s]";
  output Real trace_pitch_imu   "imu pitch [rad]";
  output Real trace_roll_imu    "imu roll [rad]";
  output Real trace_d_depth     "depth to descending edge [m]";
  output Real trace_v_ref       "reference velocity [m/s]";
  output Real trace_v_err       "velocity error [m/s]";
  output Real trace_F_dist      "disturbance force [N]";
  output Real trace_F_tr        "total traction force [N]";
  output Real trace_active_dist "disturbance active flag [1]";

  // -------------------------------------------------------------------
  // Requirement status indicators
  // -------------------------------------------------------------------
  output Boolean stop_achieved  "stop condition reached";
  output Boolean slip_ok        "slip within limit";
  output Boolean attitude_ok    "attitude within limits";
  output Boolean tracking_ok    "tracking error within tolerance after check time";
  output Boolean torque_ok      "applied torques within actuator limits";
  output Boolean finite_check   "all states finite and bounded";

equation
  // Smooth path inclination profile (tanh transitions at ramp start/end)
  ramp_angle = (Modelica.Constants.D2R*ramp_deg/2.0)*
               (Modelica.Math.tanh((s - s_ramp1)/0.05) -
                Modelica.Math.tanh((s - s_ramp2)/0.05));

  // Chassis attitude: rigid-contact, planar straight-line motion (no roll excitation)
  theta = ramp_angle;
  phi   = 0.0;

  // Forces along path
  F_grav    = m*g*Modelica.Math.sin(ramp_angle);
  N_normal  = m*g*Modelica.Math.cos(ramp_angle);
  F_tr_max  = mu*N_normal;

  // Disturbance: payload force during middle third of horizon, opposing motion
  F_dist = if (time >= t_dist1 and time <= t_dist2) then F_payload else 0.0;

  // Ridges: smooth Gaussian-like resistance pulses at two surface ridge crossings
  F_ridge = ridge_F*Modelica.Math.exp(-((s - s_ridgeA)/ridge_w)^2) +
            ridge_F*Modelica.Math.exp(-((s - s_ridgeB)/ridge_w)^2);

  // Linear drag opposing motion
  F_drag = F_drag_k*v;

  // Plant longitudinal dynamics
  der(s) = v;
  m*der(v) = (F_tr_L + F_tr_R) - F_grav - F_dist - F_ridge - F_drag;

  // Wheel slip velocities (relative tangential speed at contact)
  slip_state_L = r_w*omega_L - v;
  slip_state_R = r_w*omega_R - v;

  // Traction force: linear slip stiffness with Coulomb friction saturation
  // (per wheel, half normal load on each driven wheel; caster carries no drive)
  F_tr_L = max(-F_tr_max/2.0, min(F_tr_max/2.0, C_traction*slip_state_L));
  F_tr_R = max(-F_tr_max/2.0, min(F_tr_max/2.0, C_traction*slip_state_R));

  // Slip ratios for monitoring and slip-aware control (guarded against v=0)
  slip_L   = slip_state_L/Modelica.Math.max(abs(v), eps);
  slip_R   = slip_state_R/Modelica.Math.max(abs(v), eps);
  slip_avg = (slip_L + slip_R)/2.0;

  // Slip-aware gain: progressively reduce torque once slip exceeds half the limit
  slip_gain = max(0.0, 1.0 - max(0.0, abs(slip_avg) - 0.5*slip_max)/(0.5*slip_max));

  // Reference velocity: cruise with sqrt-braking near stop target
  s_err = s_stop - s;
  v_ref = if s_err <= 0.0 then 0.0
          elseif s_err < (v_cruise*v_cruise)/(2.0*a_brake)
          then Modelica.Math.sqrt(2.0*a_brake*s_err)
          else v_cruise;

  v_err = v_ref - v;

  // Position hold term: gated to braking zone via smooth tanh window
  // (active only when within s_brake_zone of the stop target)
  position_term = Kp_pos*s_err*0.5*
                  (1.0 + Modelica.Math.tanh((s_brake_zone - s_err)/0.05));

  // Commanded total traction force (PD on velocity + position hold near stop)
  F_cmd_total = Kp_v*v_err + position_term;

  // Per-wheel torque command with gravity feedforward (symmetric allocation)
  tau_cmd = (F_cmd_total/2.0)*r_w + (F_grav/2.0)*r_w;

  // Slip-aware scaling and bounded braking / actuator saturation
  tau_L = max(-tau_max, min(tau_max, slip_gain*tau_cmd));
  tau_R = max(-tau_max, min(tau_max, slip_gain*tau_cmd));

  // Wheel dynamics (continuous Y-axis rotational joints, independent motors)
  J_w*der(omega_L) = tau_L - F_tr_L*r_w;
  J_w*der(omega_R) = tau_R - F_tr_R*r_w;

  // Sensors (encoders, IMU, forward depth)
  v_enc     = (r_w*omega_L + r_w*omega_R)/2.0;
  pitch_imu = theta;
  roll_imu  = phi;
  d_depth   = max(0.0, s_plateau2 - s);

  // -------------------------------------------------------------------
  // Synchronized traces
  // -------------------------------------------------------------------
  trace_t          = time;
  trace_s          = s;
  trace_v          = v;
  trace_theta      = theta;
  trace_phi        = phi;
  trace_omega_L    = omega_L;
  trace_omega_R    = omega_R;
  trace_tau_L      = tau_L;
  trace_tau_R      = tau_R;
  trace_slip       = slip_avg;
  trace_v_enc      = v_enc;
  trace_pitch_imu  = pitch_imu;
  trace_roll_imu   = roll_imu;
  trace_d_depth    = d_depth;
  trace_v_ref      = v_ref;
  trace_v_err      = v_err;
  trace_F_dist      = F_dist;
  trace_F_tr       = F_tr_L + F_tr_R;
  trace_active_dist = if (time >= t_dist1 and time <= t_dist2) then 1.0 else 0.0;

  // -------------------------------------------------------------------
  // Requirement status indicators
  // -------------------------------------------------------------------
  stop_achieved = (s >= s_stop - 0.05) and (abs(v) < 0.05) and (d_depth > 0.0);
  slip_ok       = abs(slip_avg) < slip_max;
  attitude_ok   = (abs(theta) < pitch_max) and (abs(phi) < roll_max);
  torque_ok     = (abs(tau_L) <= tau_max + 1.0e-6) and (abs(tau_R) <= tau_max + 1.0e-6);
  tracking_ok   = (time < t_track_check) or (abs(v_err) < v_track_tol);

  // Finite / non-NaN sanity check via bounded-range assertion (no isFinite dependency)
  finite_check = noEvent(
                  abs(s) < 1.0e4 and
                  abs(v) < 1.0e2 and
                  abs(omega_L) < 1.0e3 and
                  abs(omega_R) < 1.0e3 and
                  abs(tau_L) <= tau_max + 1.0 and
                  abs(tau_R) <= tau_max + 1.0 and
                  abs(slip_avg) < 1.0e3 and
                  abs(v_ref) < 1.0e2 and
                  abs(d_depth) < 1.0e3);

  annotation (
    experiment(StopTime = 12.0, Tolerance = 1.0e-6, Interval = 0.008),
    Documentation(info = "DiffRoverClimbC: floating-base differential-drive rover with slip-aware traction control and bounded braking. Ascends a 12 deg ramp, traverses a 2 m plateau, and stops before the descending edge. A 135 N payload disturbance is injected during the middle third of the 12 s horizon. Plant is a 19 kg box chassis (0.65 x 0.44 x 0.22 m) with two 0.10 m radius driven wheels (0.46 m separation) and one passive caster, friction 0.76, two 0.05 m ridges. Sensors: encoders (speed), IMU (attitude), forward depth (edge distance)."));
end DiffRoverClimbC;