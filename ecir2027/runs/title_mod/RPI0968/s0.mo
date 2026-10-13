model DiffRoverClimbB
  /* DiffRoverClimbB: floating-base differential-drive rover ascending a 12 deg
     ramp, traversing a 2 m plateau with two 0.05 m ridges, and stopping before
     the descending edge. Slip-aware traction control with bounded braking.
     A 105 N payload force disturbance is injected during the middle third
     (3.33 s to 6.67 s) of a 10 s / 100 Hz run.
     NOTE: Ramp length L_ramp is not specified by the requirement and is
     assumed here as 1.5 m to make the mission runnable. */

  // ---- Physical parameters (SI units) ----
  parameter Real  m_body = 19.0 "chassis mass [kg]";
  parameter Real  L_x = 0.65 "chassis length [m]";
  parameter Real  L_y = 0.44 "chassis width [m]";
  parameter Real  L_z = 0.22 "chassis height [m]";
  parameter Real  r_w = 0.10 "driven-wheel radius [m]";
  parameter Real  track = 0.46 "wheel separation [m]";
  parameter Real  tau_max = 10.7 "max motor torque per wheel [N.m]";
  parameter Real  mu = 0.76 "tire-ground friction coefficient";
  parameter Real  ridge_h = 0.05 "surface ridge height [m]";
  parameter Real  ramp_angle = 0.209439510239 "12 deg ramp angle [rad]";
  parameter Real  L_ramp = 1.5 "ramp length [m] (assumed; not specified)";
  parameter Real  L_plateau = 2.0 "plateau length [m]";
  parameter Real  g = 9.81 "gravity [m/s2]";
  parameter Real  J_w = 0.006 "wheel inertia [kg.m2]";
  parameter Real  v_min = 0.05 "slip denominator floor [m/s]";
  parameter Real  slip_crit = 0.10 "slip critical value for friction curve";
  parameter Real  slip_limit = 0.30 "slip-aware traction threshold";
  parameter Real  ridge_sigma = 0.08 "ridge pitch perturbation width [m]";

  // ---- Mission / control parameters ----
  parameter Real  T_sim = 10.0 "simulation horizon [s]";
  parameter Real  sample_dt = 0.01 "control / output period [s] (100 Hz)";
  parameter Real  F_payload = 105.0 "payload disturbance force [N]";
  parameter Real  cruise_v = 0.50 "cruise reference velocity [m/s]";
  parameter Real  a_brake = 0.60 "braking deceleration [m/s2]";
  parameter Real  stop_margin_target = 0.30 "target stopping margin [m]";
  parameter Real  Kp = 80.0 "velocity PI proportional gain";
  parameter Real  Ki = 150.0 "velocity PI integral gain";
  parameter Real  intErr_clip = 0.5 "integral anti-windup clip magnitude";

  // ---- Dynamic states ----
  Real x(start = 0.0, fixed = true) "path position along terrain [m]";
  Real v(start = 0.0, fixed = true) "longitudinal velocity [m/s]";
  Real omega_L(start = 0.0, fixed = true) "left wheel angular velocity [rad/s]";
  Real omega_R(start = 0.0, fixed = true) "right wheel angular velocity [rad/s]";
  Real pitch(start = 0.0, fixed = true) "pitch angle [rad]";
  Real pitch_rate(start = 0.0, fixed = true) "pitch rate [rad/s]";
  Real roll(start = 0.0, fixed = true) "roll angle [rad]";
  Real roll_rate(start = 0.0, fixed = true) "roll rate [rad/s]";
  Real intErr(start = 0.0, fixed = true) "velocity error integral [m]";

  // ---- Terrain & mission signals ----
  Boolean on_ramp;
  Boolean on_plateau;
  Real terrain_pitch "terrain pitch [rad]";
  Real ridge_pitch_pert "ridge-induced pitch perturbation [rad]";
  Real edge_distance "distance to descending edge [m]";
  Real target_stop_x "target stop position [m]";
  Real stop_margin "actual stopping margin [m]";

  // ---- Forces / loads ----
  Real N_normal "normal load on driven axle [N]";
  Real F_gravity "gravity along slope [N]";
  Real F_roll_resist "rolling resistance [N]";
  Real F_dist "payload disturbance force [N]";
  Real F_traction_L "left wheel traction force [N]";
  Real F_traction_R "right wheel traction force [N]";
  Real F_traction_total "total traction [N]";

  // ---- Slip ----
  Real s_L "left wheel slip ratio";
  Real s_R "right wheel slip ratio";
  Real slip_max "maximum slip magnitude";

  // ---- Control ----
  Real v_ref "reference velocity [m/s]";
  Real tracking_err "primary tracking error (v - v_ref) [m/s]";
  Real tau_unsat "unsaturated total commanded torque [N.m]";
  Real slip_factor "slip-aware torque scaling";
  Real tau_cmd_L "left commanded torque [N.m]";
  Real tau_cmd_R "right commanded torque [N.m]";
  Real tau_sat_L "saturated left torque [N.m]";
  Real tau_sat_R "saturated right torque [N.m]";
  Boolean saturated "actuator saturation flag (anti-windup)";
  Boolean disturb_active "payload disturbance window flag";

  // ---- Sensors ----
  Real v_encoder "encoder-derived speed [m/s]";
  Real pitch_imu "IMU pitch [rad]";
  Real roll_imu "IMU roll [rad]";
  Real depth_sensor "forward depth to descending edge [m]";

equation
  // ---- Terrain geometry ----
  on_ramp     = x < L_ramp;
  on_plateau  = (x >= L_ramp) and (x < (L_ramp + L_plateau));
  terrain_pitch = if on_ramp then ramp_angle else 0.0;

  // Two ridges on the plateau causing brief pitch perturbations
  ridge_pitch_pert = (ridge_h / r_w) * (
    0.10 * exp(-((x - (L_ramp + 0.5)) / ridge_sigma)^2) +
    0.10 * exp(-((x - (L_ramp + 1.5)) / ridge_sigma)^2));

  // ---- Pitch / roll attitude dynamics ----
  der(pitch)      = pitch_rate;
  der(pitch_rate) = 120.0 * (terrain_pitch + ridge_pitch_pert - pitch) - 8.0 * pitch_rate;
  der(roll)       = roll_rate;
  der(roll_rate)  = -60.0 * roll - 6.0 * roll_rate;

  // ---- Loads ----
  N_normal       = m_body * g * cos(pitch) * 0.80;
  F_gravity      = m_body * g * sin(pitch);
  F_roll_resist  = 0.02 * m_body * g * cos(pitch);

  // ---- Disturbance: middle third of the simulation ----
  disturb_active = (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0);
  F_dist         = if disturb_active then F_payload else 0.0;

  // ---- Slip ratios (longitudinal) ----
  s_L = (omega_L * r_w - v) / max(abs(v), v_min);
  s_R = (omega_R * r_w - v) / max(abs(v), v_min);
  slip_max = max(abs(s_L), abs(s_R));

  // ---- Tire force via simplified saturating friction curve ----
  F_traction_L    = mu * (N_normal / 2.0) * tanh(s_L / slip_crit);
  F_traction_R    = mu * (N_normal / 2.0) * tanh(s_R / slip_crit);
  F_traction_total = F_traction_L + F_traction_R;

  // ---- Longitudinal body dynamics ----
  der(x) = v;
  m_body * der(v) = F_traction_total - F_gravity - F_roll_resist - F_dist;

  // ---- Wheel rotational dynamics ----
  J_w * der(omega_L) = tau_sat_L - F_traction_L * r_w;
  J_w * der(omega_R) = tau_sat_R - F_traction_R * r_w;

  // ---- Mission edge / stop geometry ----
  target_stop_x = L_ramp + L_plateau - stop_margin_target;
  edge_distance = (L_ramp + L_plateau) - x;
  stop_margin    = max(edge_distance, 0.0);

  // ---- Reference velocity: cruise then position-based braking ----
  v_ref = if x < target_stop_x then
            min(cruise_v, sqrt(2.0 * a_brake * max(target_stop_x - x, 0.0)))
          else 0.0;

  // ---- Primary tracking error ----
  tracking_err = v - v_ref;

  // ---- PI control with anti-windup ----
  tau_unsat = Kp * (v_ref - v) + Ki * intErr;
  saturated = (abs(tau_unsat) > 2.0 * tau_max);
  der(intErr) = if saturated then 0.0 else
                  (if intErr > intErr_clip and tracking_err > 0.0 then 0.0 else
                    if intErr < -intErr_clip and tracking_err < 0.0 then 0.0 else tracking_err);

  // ---- Slip-aware traction control: scale torque if slip exceeds threshold ----
  slip_factor = if slip_max > slip_limit then
                  max(0.0, 1.0 - (slip_max - slip_limit) / 0.10)
                else 1.0;

  tau_cmd_L = 0.5 * tau_unsat * slip_factor;
  tau_cmd_R = 0.5 * tau_unsat * slip_factor;

  // ---- Bounded actuator torque (independent wheel motors) ----
  tau_sat_L = max(-tau_max, min(tau_max, tau_cmd_L));
  tau_sat_R = max(-tau_max, min(tau_max, tau_cmd_R));

  // ---- Sensors ----
  v_encoder   = 0.5 * (omega_L + omega_R) * r_w;
  pitch_imu   = pitch;
  roll_imu    = roll;
  depth_sensor = max(edge_distance, 0.0);

  // ---- Requirement assertions (soft checks; do not block code gen) ----
  assert(slip_max < 0.35,          "Slip ratio exceeded 0.35");
  assert(abs(roll)  < 0.40,        "Roll exceeded 0.40 rad");
  assert(abs(pitch) < 0.40,        "Pitch exceeded 0.40 rad");
  assert(stop_margin > 0.0,        "Robot passed the descending edge");
  assert((time < 6.5) or (abs(tracking_err) < 0.216),
         "Tracking error after 6.5 s exceeded 0.216 m/s");

  annotation(
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "DiffRoverClimbB: floating-base differential-drive rover. Ascends a 12 deg ramp, traverses a 2 m plateau with two 0.05 m ridges, and stops before the descending edge. Slip-aware traction control with bounded braking (10.7 N.m per wheel). A 105 N payload force disturbance is injected during the middle third (3.33-6.67 s). The model runs at 100 Hz for 10 s and exposes synchronized state, command, and sensor traces. Ramp length L_ramp is assumed (1.5 m) because it was not specified in the requirement."));
end DiffRoverClimbB;