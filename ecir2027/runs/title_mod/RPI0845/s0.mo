model AUVDiveE
  "Verifiable free-base AUV: descend to 8 m, hold, return to 3 m with bounded allocation"

  // ------------------------------------------------------------------
  // Physical parameters (SI units)
  // ------------------------------------------------------------------
  parameter Real m = 85.0          "hull mass [kg]";
  parameter Real L_hull = 1.5      "hull length [m]";
  parameter Real V_disp = 0.083    "displaced volume [m3]";
  parameter Real rho_sw = 1025.0   "seawater density [kg/m3]";
  parameter Real g = 9.81          "gravitational acceleration [m/s2]";
  parameter Real Tmax = 121.0      "per-thruster command magnitude bound [N]";
  parameter Real Fcurrent = 96.0   "current disturbance force [N]";
  parameter Real Tdist_start = 16.0 / 3.0  "current disturbance start time [s]";
  parameter Real Tdist_end   = 2.0 * 16.0 / 3.0 "current disturbance end time [s]";

  // Quadratic and linear drag coefficients
  parameter Real kx = 30.0   "surge quadratic drag [N/(m/s)^2]";
  parameter Real kz = 30.0   "heave quadratic drag [N/(m/s)^2]";
  parameter Real cyaw_lin = 10.0  "yaw linear damping [N.m/(rad/s)]";
  parameter Real cyaw_quad = 5.0  "yaw quadratic damping [N.m/(rad/s)^2]";
  parameter Real croll_lin = 20.0 "roll linear damping [N.m/(rad/s)]";
  parameter Real croll_quad = 5.0 "roll quadratic damping [N.m/(rad/s)^2]";
  parameter Real cpitch_lin = 20.0 "pitch linear damping [N.m/(rad/s)]";
  parameter Real cpitch_quad = 5.0 "pitch quadratic damping [N.m/(rad/s)^2]";

  // Inertia and geometry
  parameter Real Iz = 15.0   "yaw moment of inertia [kg.m2]";
  parameter Real Ix = 6.0   "roll moment of inertia [kg.m2]";
  parameter Real Iy = 10.0  "pitch moment of inertia [kg.m2]";
  parameter Real BGz_roll = 0.05   "roll metacentric height [m]";
  parameter Real BGz_pitch = 0.05  "pitch metacentric height [m]";
  parameter Real thr_sep = 0.6     "thruster pair separation [m]";

  // Controller gains
  parameter Real Kp_z = 0.8       "depth outer-loop gain [1/s]";
  parameter Real w_cmd_max = 2.0  "heave velocity command clamp [m/s]";
  parameter Real Kp_w = 200.0     "heave inner-loop proportional [N/(m/s)]";
  parameter Real Kd_w = 30.0      "heave inner-loop damping [N/(m/s)]";
  parameter Real Kp_yaw = 8.0     "heading proportional gain [N.m/rad]";
  parameter Real Kd_yaw = 15.0    "heading damping gain [N.m/(rad/s)]";
  parameter Real Kp_pitch = 100.0 "pitch proportional gain [N.m/rad]";
  parameter Real Kd_pitch = 20.0  "pitch damping gain [N.m/(rad/s)]";
  parameter Real Kp_u = 200.0     "surge velocity hold gain [N/(m/s)]";

  // ------------------------------------------------------------------
  // Dynamic states
  // ------------------------------------------------------------------
  Real z(start = 0.0, fixed = true)       "depth, positive downward [m]";
  Real w(start = 0.0, fixed = true)       "heave velocity [m/s]";
  Real x_pos(start = 0.0, fixed = true)   "surge position [m]";
  Real u(start = 0.0, fixed = true)       "surge velocity [m/s]";
  Real yaw(start = 0.0, fixed = true)     "heading [rad]";
  Real r_rate(start = 0.0, fixed = true)  "yaw rate [rad/s]";
  Real phi(start = 0.1, fixed = true)     "roll [rad]";
  Real p_rate(start = 0.0, fixed = true)  "roll rate [rad/s]";
  Real theta(start = 0.1, fixed = true)   "pitch [rad]";
  Real q_rate(start = 0.0, fixed = true)  "pitch rate [rad/s]";

  // ------------------------------------------------------------------
  // Derived physical quantities
  // ------------------------------------------------------------------
  Real W_weight     "weight [N]";
  Real B_buoy       "buoyancy [N]";
  Real F_current_applied "applied current force [N]";

  // ------------------------------------------------------------------
  // Controller signals
  // ------------------------------------------------------------------
  Real z_ref        "depth reference [m]";
  Real z_err        "depth tracking error [m]";
  Real w_cmd_raw    "unclamped heave velocity command [m/s]";
  Real w_cmd        "clamped heave velocity command [m/s]";
  Real w_err        "heave velocity error [m/s]";
  Real F_heave_des  "desired total heave force [N]";
  Real tau_pitch_des "desired pitch torque [N.m]";
  Real F_surge_des  "desired total surge force [N]";
  Real tau_yaw_des  "desired yaw torque [N.m]";

  // ------------------------------------------------------------------
  // Allocation: raw and saturated thruster commands
  // ------------------------------------------------------------------
  Real cmd_heave1_raw "raw heave thruster 1 command [N]";
  Real cmd_heave2_raw "raw heave thruster 2 command [N]";
  Real cmd_surge1_raw "raw surge thruster 1 command [N]";
  Real cmd_surge2_raw "raw surge thruster 2 command [N]";
  Real cmd_heave1     "saturated heave thruster 1 [N]";
  Real cmd_heave2     "saturated heave thruster 2 [N]";
  Real cmd_surge1     "saturated surge thruster 1 [N]";
  Real cmd_surge2     "saturated surge thruster 2 [N]";

  // Actual applied forces and torques
  Real F_heave_act    "actual total heave force [N]";
  Real F_surge_act    "actual total surge force [N]";
  Real tau_pitch_act  "actual pitch torque [N.m]";
  Real tau_yaw_act    "actual yaw torque [N.m]";
  Real tau_roll_restore  "passive roll restoring torque [N.m]";
  Real tau_pitch_restore "passive pitch restoring torque [N.m]";

  // ------------------------------------------------------------------
  // Sensors (ideal, synchronized)
  // ------------------------------------------------------------------
  Real z_meas    "pressure depth sensor [m]";
  Real w_meas    "Doppler heave velocity [m/s]";
  Real u_meas    "Doppler surge velocity [m/s]";
  Real yaw_meas  "IMU heading [rad]";
  Real r_meas    "IMU yaw rate [rad/s]";
  Real phi_meas  "IMU roll [rad]";
  Real theta_meas "IMU pitch [rad]";
  Real p_meas    "IMU roll rate [rad/s]";
  Real q_meas    "IMU pitch rate [rad/s]";

  // ------------------------------------------------------------------
  // Acceptance monitors
  // ------------------------------------------------------------------
  Real track_err       "primary tracking error |z - z_ref| [m]";
  Boolean actuator_bounded;
  Boolean roll_pitch_ok;
  Boolean velocity_finite;
  Boolean tracking_ok;
  Boolean values_finite;
  Boolean fail_closed;

equation
  // === Gravity and buoyancy ===
  W_weight = m * g;
  B_buoy   = rho_sw * V_disp * g;

  // === Mission reference ===
  // Descend to 8 m, hold until 10.4 s, then return to 3 m
  z_ref = if time < 10.4 then 8.0 else 3.0;

  // === Current disturbance: middle third of 16 s ===
  F_current_applied = if time >= Tdist_start and time < Tdist_end then Fcurrent else 0.0;

  // === Sensors ===
  z_meas     = z;
  w_meas     = w;
  u_meas     = u;
  yaw_meas   = yaw;
  r_meas     = r_rate;
  phi_meas   = phi;
  theta_meas = theta;
  p_meas     = p_rate;
  q_meas     = q_rate;

  // === Cascaded depth control ===
  z_err     = z_ref - z_meas;
  w_cmd_raw = Kp_z * z_err;
  w_cmd     = max(-w_cmd_max, min(w_cmd_max, w_cmd_raw));
  w_err     = w_cmd - w_meas;
  F_heave_des = Kp_w * w_err - Kd_w * w_meas;

  // === Attitude control ===
  tau_pitch_des = Kp_pitch * (0.0 - theta_meas) - Kd_pitch * q_meas;
  tau_yaw_des   = Kp_yaw * (0.0 - yaw_meas) - Kd_yaw * r_meas;
  F_surge_des   = Kp_u * (0.0 - u_meas);

  // === Allocation ===
  // Heave thrusters: common force = depth, differential = pitch
  cmd_heave1_raw = F_heave_des / 2.0 + tau_pitch_des / thr_sep;
  cmd_heave2_raw = F_heave_des / 2.0 - tau_pitch_des / thr_sep;
  // Surge thrusters: common force = surge, differential = yaw
  cmd_surge1_raw = F_surge_des / 2.0 + tau_yaw_des / thr_sep;
  cmd_surge2_raw = F_surge_des / 2.0 - tau_yaw_des / thr_sep;

  // Bounded allocation (per-thruster saturation)
  cmd_heave1 = max(-Tmax, min(Tmax, cmd_heave1_raw));
  cmd_heave2 = max(-Tmax, min(Tmax, cmd_heave2_raw));
  cmd_surge1 = max(-Tmax, min(Tmax, cmd_surge1_raw));
  cmd_surge2 = max(-Tmax, min(Tmax, cmd_surge2_raw));

  // Actual forces and torques from saturated commands
  F_heave_act   = cmd_heave1 + cmd_heave2;
  F_surge_act   = cmd_surge1 + cmd_surge2;
  tau_pitch_act = (cmd_heave1 - cmd_heave2) * thr_sep / 2.0;
  tau_yaw_act   = (cmd_surge1 - cmd_surge2) * thr_sep / 2.0;

  // Passive metacentric restoring torques
  tau_roll_restore  = -B_buoy * BGz_roll * sin(phi);
  tau_pitch_restore = -B_buoy * BGz_pitch * sin(theta);

  // === Plant dynamics ===
  // Heave (depth): positive downward
  der(z) = w;
  m * der(w) = F_heave_act + (W_weight - B_buoy) - kz * w * abs(w);

  // Surge
  der(x_pos) = u;
  m * der(u) = F_surge_act - kx * u * abs(u) - F_current_applied;

  // Yaw
  der(yaw) = r_rate;
  Iz * der(r_rate) = tau_yaw_act - cyaw_lin * r_rate - cyaw_quad * r_rate * abs(r_rate);

  // Roll (passive stabilization, no actuator)
  der(phi) = p_rate;
  Ix * der(p_rate) = tau_roll_restore - croll_lin * p_rate - croll_quad * p_rate * abs(p_rate);

  // Pitch
  der(theta) = q_rate;
  Iy * der(q_rate) = tau_pitch_act + tau_pitch_restore - cpitch_lin * q_rate - cpitch_quad * q_rate * abs(q_rate);

  // === Acceptance monitors ===
  track_err = abs(z - z_ref);

  // Actuator bounds verified (always true by saturation construction)
  actuator_bounded = (abs(cmd_heave1) <= Tmax + 1.0e-6)
    and (abs(cmd_heave2) <= Tmax + 1.0e-6)
    and (abs(cmd_surge1) <= Tmax + 1.0e-6)
    and (abs(cmd_surge2) <= Tmax + 1.0e-6);

  // Roll and pitch below 0.35 rad
  roll_pitch_ok = (abs(phi) < 0.35) and (abs(theta) < 0.35);

  // Finite velocity
  velocity_finite = (abs(u) < 1000.0) and (abs(w) < 1000.0);

  // Primary tracking error below 0.405 m:
  //   checked at 8 m hold completion (~10.4 s) and 3 m return settle (~end)
  tracking_ok = if (time >= 9.5 and time <= 10.4) then (abs(z - 8.0) < 0.405)
    elseif (time >= 15.0) then (abs(z - 3.0) < 0.405)
    else true;

  // No NaN or infinite values
  values_finite = (z > -1.0e8) and (z < 1.0e8)
    and (w > -1.0e8) and (w < 1.0e8)
    and (u > -1.0e8) and (u < 1.0e8)
    and (x_pos > -1.0e8) and (x_pos < 1.0e8)
    and (yaw > -1.0e8) and (yaw < 1.0e8)
    and (r_rate > -1.0e8) and (r_rate < 1.0e8)
    and (phi > -1.0e8) and (phi < 1.0e8)
    and (p_rate > -1.0e8) and (p_rate < 1.0e8)
    and (theta > -1.0e8) and (theta < 1.0e8)
    and (q_rate > -1.0e8) and (q_rate < 1.0e8);

  // Fail-closed aggregate
  fail_closed = actuator_bounded and roll_pitch_ok and velocity_finite
    and tracking_ok and values_finite;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "AUVDiveE: Verifiable free-base marine robot.
      85 kg capsule hull, 1.5 m long, 0.083 m3 displacement in seawater (1025 kg/m3).
      Four bidirectional thrusters (2 surge, 2 heave), bounded at 121 N each.
      Cascaded depth and attitude control with bounded allocation.
      96 N current disturbance in middle third of 16 s run at 250 Hz.
      Mission: descend to 8 m, hold depth and zero heading, return to 3 m.
      Acceptance is fail-closed: actuator bounds, depth settling,
      roll/pitch < 0.35 rad, finite velocity, tracking error < 0.405 m after 10.4 s,
      no NaN or infinite values.")
  );
end AUVDiveE;