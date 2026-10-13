model GimbalPathMoveB
  // Physical parameters
  parameter Real m_camera = 4.0 "Camera mass [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real L_eff = 0.05 "Effective gravity lever arm [m] — assumed, not specified in request";
  parameter Real J_yaw = 0.15 "Yaw axis rotational inertia [kg.m2] — assumed";
  parameter Real J_pitch = 0.10 "Pitch axis rotational inertia [kg.m2] — assumed";
  parameter Real J_roll = 0.08 "Roll axis rotational inertia [kg.m2] — assumed";
  parameter Real b_yaw = 0.05 "Yaw viscous friction coefficient [N.m.s/rad] — assumed";
  parameter Real b_pitch = 0.05 "Pitch viscous friction coefficient [N.m.s/rad] — assumed";
  parameter Real b_roll = 0.05 "Roll viscous friction coefficient [N.m.s/rad] — assumed";

  // Bounds
  parameter Real tau_max = 16.4 "Maximum torque command magnitude [N.m]";
  parameter Real q_yaw_max = 2.8 "Yaw position limit [rad]";
  parameter Real q_pitch_min = -1.2 "Pitch minimum position [rad]";
  parameter Real q_pitch_max = 1.0 "Pitch maximum position [rad]";
  parameter Real q_roll_max = 0.8 "Roll position limit [rad]";
  parameter Real qd_max = 5.0 "Velocity limit [rad/s] — assumed, not specified in request";
  parameter Real qdd_max = 20.0 "Acceleration limit [rad/s2] — assumed, not specified in request";

  // Controller gains
  parameter Real Kp = 100.0 "Proportional gain";
  parameter Real Ki = 30.0 "Integral gain";
  parameter Real Kd = 10.0 "Derivative gain";

  // Trajectory waypoints
  parameter Real q_mid_yaw = 0.7 "Midpoint yaw [rad]";
  parameter Real q_mid_pitch = 0.25 "Midpoint pitch [rad]";
  parameter Real q_mid_roll = 0.15 "Midpoint roll [rad]";
  parameter Real q_final_yaw = 1.4 "Final yaw [rad]";
  parameter Real q_final_pitch = 0.5 "Final pitch [rad]";
  parameter Real q_final_roll = 0.3 "Final roll [rad]";
  parameter Real T_seg1 = 5.0 "First segment duration (zero to midpoint) [s]";
  parameter Real T_seg2 = 5.0 "Second segment duration (midpoint to final) [s]";

  // Disturbance
  parameter Real T_dist_start = 10.0 / 3.0 "Disturbance injection start (middle third) [s]";
  parameter Real T_dist_end = 20.0 / 3.0 "Disturbance injection end (middle third) [s]";
  parameter Real dist_frac = 0.035 "Payload change fraction (3.5 percent)";

  // Joint states
  Real q_yaw(start = 0.0, fixed = true) "Yaw position [rad]";
  Real q_pitch(start = 0.0, fixed = true) "Pitch position [rad]";
  Real q_roll(start = 0.0, fixed = true) "Roll position [rad]";
  Real qd_yaw(start = 0.0, fixed = true) "Yaw velocity [rad/s]";
  Real qd_pitch(start = 0.0, fixed = true) "Pitch velocity [rad/s]";
  Real qd_roll(start = 0.0, fixed = true) "Roll velocity [rad/s]";
  Real qdd_yaw "Yaw acceleration [rad/s2]";
  Real qdd_pitch "Pitch acceleration [rad/s2]";
  Real qdd_roll "Roll acceleration [rad/s2]";

  // Trajectory references (cubic interpolation)
  Real q_ref_yaw "Reference yaw position [rad]";
  Real q_ref_pitch "Reference pitch position [rad]";
  Real q_ref_roll "Reference roll position [rad]";
  Real qd_ref_yaw "Reference yaw velocity [rad/s]";
  Real qd_ref_pitch "Reference pitch velocity [rad/s]";
  Real qd_ref_roll "Reference roll velocity [rad/s]";
  Real qdd_ref_yaw "Reference yaw acceleration [rad/s2]";
  Real qdd_ref_pitch "Reference pitch acceleration [rad/s2]";
  Real qdd_ref_roll "Reference roll acceleration [rad/s2]";

  // Control signals
  Real e_yaw "Yaw position error [rad]";
  Real e_pitch "Pitch position error [rad]";
  Real e_roll "Roll position error [rad]";
  Real ie_yaw(start = 0.0) "Yaw integral error [rad.s]";
  Real ie_pitch(start = 0.0) "Pitch integral error [rad.s]";
  Real ie_roll(start = 0.0) "Roll integral error [rad.s]";
  Real de_yaw "Yaw velocity error [rad/s]";
  Real de_pitch "Pitch velocity error [rad/s]";
  Real de_roll "Roll velocity error [rad/s]";
  Real tau_raw_yaw "Unsaturated yaw torque command [N.m]";
  Real tau_raw_pitch "Unsaturated pitch torque command [N.m]";
  Real tau_raw_roll "Unsaturated roll torque command [N.m]";
  Real tau_yaw "Saturated yaw torque command [N.m]";
  Real tau_pitch "Saturated pitch torque command [N.m]";
  Real tau_roll "Saturated roll torque command [N.m]";

  // Encoders (sensors)
  Real sens_q_yaw "Yaw encoder position [rad]";
  Real sens_q_pitch "Pitch encoder position [rad]";
  Real sens_q_roll "Roll encoder position [rad]";
  Real sens_qd_yaw "Yaw encoder velocity [rad/s]";
  Real sens_qd_pitch "Pitch encoder velocity [rad/s]";
  Real sens_qd_roll "Roll encoder velocity [rad/s]";

  // Disturbance and tracking
  Real dist_factor "Payload mass multiplier during disturbance";
  Real track_error "Primary tracking error (max absolute joint error) [rad]";

  // Internal
protected
  Real t_seg "Time within current segment [s]";
  Real s_norm "Cubic position profile [-]";
  Real sd_norm "Cubic velocity profile [1/s]";
  Real sdd_norm "Cubic acceleration profile [1/s2]";
  Real J_yaw_eff "Effective yaw inertia including disturbance [kg.m2]";
  Real J_pitch_eff "Effective pitch inertia including disturbance [kg.m2]";
  Real J_roll_eff "Effective roll inertia including disturbance [kg.m2]";
  Real grav_pitch "Gravity torque on pitch axis [N.m]";

equation
  // ---- Segment timing ----
  t_seg = if time < T_seg1 then time else time - T_seg1;

  // ---- Cubic interpolation profile (quintic-free 3-4-5 replaced by standard cubic: zero vel at endpoints) ----
  // q(s) = 3*s^2 - 2*s^3,  s = t/T
  s_norm = if time < T_seg1 then
           3.0 * (t_seg / T_seg1)^2 - 2.0 * (t_seg / T_seg1)^3
         else
           3.0 * (t_seg / T_seg2)^2 - 2.0 * (t_seg / T_seg2)^3;

  sd_norm = if time < T_seg1 then
            6.0 * t_seg / T_seg1^2 - 6.0 * t_seg^2 / T_seg1^3
          else
            6.0 * t_seg / T_seg2^2 - 6.0 * t_seg^2 / T_seg2^3;

  sdd_norm = if time < T_seg1 then
             6.0 / T_seg1^2 - 12.0 * t_seg / T_seg1^3
           else
             6.0 / T_seg2^2 - 12.0 * t_seg / T_seg2^3;

  // ---- Reference trajectories (zero -> midpoint -> final) ----
  q_ref_yaw   = if time < T_seg1 then q_mid_yaw   * s_norm else q_mid_yaw   + (q_final_yaw   - q_mid_yaw)   * s_norm;
  q_ref_pitch = if time < T_seg1 then q_mid_pitch * s_norm else q_mid_pitch + (q_final_pitch - q_mid_pitch) * s_norm;
  q_ref_roll  = if time < T_seg1 then q_mid_roll   * s_norm else q_mid_roll   + (q_final_roll   - q_mid_roll)  * s_norm;

  qd_ref_yaw   = if time < T_seg1 then q_mid_yaw   * sd_norm else (q_final_yaw   - q_mid_yaw)   * sd_norm;
  qd_ref_pitch = if time < T_seg1 then q_mid_pitch * sd_norm else (q_final_pitch - q_mid_pitch) * sd_norm;
  qd_ref_roll  = if time < T_seg1 then q_mid_roll   * sd_norm else (q_final_roll  - q_mid_roll)  * sd_norm;

  qdd_ref_yaw   = if time < T_seg1 then q_mid_yaw   * sdd_norm else (q_final_yaw   - q_mid_yaw)   * sdd_norm;
  qdd_ref_pitch = if time < T_seg1 then q_mid_pitch * sdd_norm else (q_final_pitch - q_mid_pitch) * sdd_norm;
  qdd_ref_roll  = if time < T_seg1 then q_mid_roll   * sdd_norm else (q_final_roll  - q_mid_roll)  * sdd_norm;

  // ---- Disturbance: 3.5% payload change during middle third of 10 s ----
  dist_factor = if time >= T_dist_start and time <= T_dist_end then 1.0 + dist_frac else 1.0;

  // ---- Effective inertia (payload change modifies inertia) ----
  J_yaw_eff   = J_yaw   * dist_factor;
  J_pitch_eff = J_pitch * dist_factor;
  J_roll_eff  = J_roll  * dist_factor;

  // ---- Gravity torque on pitch (camera mass at effective lever arm) ----
  grav_pitch = m_camera * g * L_eff * sin(q_pitch);

  // ---- Position errors ----
  e_yaw   = q_ref_yaw   - q_yaw;
  e_pitch = q_ref_pitch - q_pitch;
  e_roll  = q_ref_roll  - q_roll;

  // ---- Velocity errors ----
  de_yaw   = qd_ref_yaw   - qd_yaw;
  de_pitch = qd_ref_pitch - qd_pitch;
  de_roll  = qd_ref_roll  - qd_roll;

  // ---- Integral with conditional anti-windup ----
  der(ie_yaw)   = if (abs(tau_yaw)   >= tau_max)   and (e_yaw   * tau_raw_yaw   > 0.0) then 0.0 else e_yaw;
  der(ie_pitch) = if (abs(tau_pitch) >= tau_max)   and (e_pitch * tau_raw_pitch > 0.0) then 0.0 else e_pitch;
  der(ie_roll)  = if (abs(tau_roll)  >= tau_max)   and (e_roll  * tau_raw_roll  > 0.0) then 0.0 else e_roll;

  // ---- PID + velocity feedforward (friction comp) + acceleration feedforward (inertia comp) ----
  tau_raw_yaw   = Kp * e_yaw   + Ki * ie_yaw   + Kd * de_yaw   + b_yaw   * qd_ref_yaw   + J_yaw_eff   * qdd_ref_yaw;
  tau_raw_pitch = Kp * e_pitch + Ki * ie_pitch + Kd * de_pitch + b_pitch * qd_ref_pitch + J_pitch_eff * qdd_ref_pitch + grav_pitch;
  tau_raw_roll  = Kp * e_roll  + Ki * ie_roll  + Kd * de_roll  + b_roll  * qd_ref_roll  + J_roll_eff  * qdd_ref_roll;

  // ---- Torque saturation (bounded actuators) ----
  tau_yaw   = max(-tau_max, min(tau_max, tau_raw_yaw));
  tau_pitch = max(-tau_max, min(tau_max, tau_raw_pitch));
  tau_roll  = max(-tau_max, min(tau_max, tau_raw_roll));

  // ---- Plant dynamics ----
  J_yaw_eff   * qdd_yaw   = tau_yaw   - b_yaw   * qd_yaw;
  J_pitch_eff * qdd_pitch = tau_pitch - b_pitch * qd_pitch - grav_pitch;
  J_roll_eff  * qdd_roll  = tau_roll  - b_roll  * qd_roll;

  der(q_yaw)   = qd_yaw;
  der(q_pitch) = qd_pitch;
  der(q_roll)  = qd_roll;
  der(qd_yaw)   = qdd_yaw;
  der(qd_pitch) = qdd_pitch;
  der(qd_roll)  = qdd_roll;

  // ---- Encoders (sensors) ----
  sens_q_yaw     = q_yaw;
  sens_q_pitch   = q_pitch;
  sens_q_roll    = q_roll;
  sens_qd_yaw    = qd_yaw;
  sens_qd_pitch  = qd_pitch;
  sens_qd_roll   = qd_roll;

  // ---- Primary tracking error ----
  track_error = max(abs(e_yaw), max(abs(e_pitch), abs(e_roll)));

  // ---- Requirement assertions ----
  // Position bounds
  assert(abs(q_yaw) <= q_yaw_max + 1e-6, "Yaw position limit exceeded");
  assert(q_pitch >= q_pitch_min - 1e-6, "Pitch lower position limit exceeded");
  assert(q_pitch <= q_pitch_max + 1e-6, "Pitch upper position limit exceeded");
  assert(abs(q_roll) <= q_roll_max + 1e-6, "Roll position limit exceeded");
  // Velocity bounds
  assert(abs(qd_yaw) <= qd_max + 1e-6, "Yaw velocity limit exceeded");
  assert(abs(qd_pitch) <= qd_max + 1e-6, "Pitch velocity limit exceeded");
  assert(abs(qd_roll) <= qd_max + 1e-6, "Roll velocity limit exceeded");
  // Acceleration bounds
  assert(abs(qdd_yaw) <= qdd_max + 1e-6, "Yaw acceleration limit exceeded");
  assert(abs(qdd_pitch) <= qdd_max + 1e-6, "Pitch acceleration limit exceeded");
  assert(abs(qdd_roll) <= qdd_max + 1e-6, "Roll acceleration limit exceeded");
  // Effort bounds
  assert(abs(tau_yaw) <= tau_max + 1e-6, "Yaw effort limit exceeded");
  assert(abs(tau_pitch) <= tau_max + 1e-6, "Pitch effort limit exceeded");
  assert(abs(tau_roll) <= tau_max + 1e-6, "Roll effort limit exceeded");
  // Terminal settling: tracking error below 0.036 rad after 6.5 s
  assert(time < 6.5 or track_error < 0.036, "Primary tracking error exceeds 0.036 rad after 6.5 s");
  // No NaN or infinite values
  assert(track_error >= 0.0 and track_error < 1e12, "Invalid (NaN or infinite) tracking error detected");

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "GimbalPathMoveB: Yaw-pitch-roll gimbal carrying 4 kg camera executing synchronized point-to-point move through one midpoint via cubic interpolation with PID + velocity/acceleration feedforward. 3.5 percent payload disturbance injected during middle third. 100 Hz control for 10 s."));
end GimbalPathMoveB;