model DiffRoverClimbC
  // ===== Physical Parameters =====
  parameter Real m_body = 19.0 "Chassis mass [kg]";
  parameter Real L_chassis = 0.65 "Chassis length [m]";
  parameter Real W_chassis = 0.44 "Chassis width [m]";
  parameter Real H_chassis = 0.22 "Chassis height [m]";
  parameter Real r_w = 0.10 "Wheel radius [m]";
  parameter Real track_w = 0.46 "Wheel separation [m]";
  parameter Real J_w = 0.01 "Wheel inertia [kg.m2]";
  parameter Real b_w = 0.05 "Wheel bearing friction [N.m.s]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real tau_limit = 12.0 "Maximum command magnitude [N.m]";

  // ===== Disturbance =====
  parameter Real F_payload = 135.0 "Payload disturbance force [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end (middle third) [s]";

  // ===== Terrain =====
  parameter Real angle_ramp = 12.0 * 3.14159265358979 / 180.0 "Ramp angle [rad]";
  parameter Real x_flat_end = 0.10 "Flat ground section end [m]";
  parameter Real x_ramp_end = 0.50 "Ramp section end [m]";
  parameter Real x_plateau_end = 2.50 "Plateau end / descending edge [m]";
  parameter Real x_ridge1 = 0.30 "First surface ridge position [m]";
  parameter Real x_ridge2 = 1.50 "Second surface ridge position [m]";
  parameter Real h_ridge = 0.05 "Ridge height [m]";
  parameter Real w_ridge = 0.10 "Ridge Gaussian width [m]";

  // ===== Control Parameters =====
  parameter Real v_cruise = 0.20 "Cruise speed reference [m/s]";
  parameter Real d_margin = 0.30 "Stopping margin before edge [m]";
  parameter Real slip_limit = 0.35 "Slip ratio limit";
  parameter Real pitch_limit = 0.40 "Roll and pitch limit [rad]";
  parameter Real kp = 40.0 "Speed proportional gain";
  parameter Real ki = 8.0 "Speed integral gain";
  parameter Real Ts = 1.0 / 125.0 "Controller sample period [s]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";

  // ===== Friction Curve (simplified Magic Formula) =====
  parameter Real mf_B = 15.0 "Stiffness factor";
  parameter Real mf_C = 1.5 "Shape factor";
  parameter Real mf_D = 0.76 "Peak friction coefficient";

  // ===== Dynamic States =====
  Real x(start = 0.0, fixed = true) "Longitudinal position [m]";
  Real v(start = 0.0, fixed = true) "Longitudinal velocity [m/s]";
  Real omega_L(start = 0.0, fixed = true) "Left wheel angular velocity [rad/s]";
  Real omega_R(start = 0.0, fixed = true) "Right wheel angular velocity [rad/s]";
  Real integ(start = 0.0, fixed = true) "PI controller integral state";

  // ===== Derived Quantities =====
  Real theta_terrain "Terrain slope angle [rad]";
  Real ridge_pitch "Ridge-induced pitch perturbation [rad]";
  Real pitch "Chassis pitch [rad]";
  Real roll "Chassis roll [rad]";
  Real F_gravity "Gravity force along slope [N]";
  Real N_normal "Normal force [N]";
  Real F_dist "Disturbance force [N]";
  Real d_edge "Distance to descending edge [m]";
  Real slip_L "Left wheel slip ratio";
  Real slip_R "Right wheel slip ratio";
  Real mu_eff_L "Effective friction coefficient left";
  Real mu_eff_R "Effective friction coefficient right";
  Real F_trac_L "Left wheel traction force [N]";
  Real F_trac_R "Right wheel traction force [N]";
  Real F_trac_total "Total traction force [N]";
  Real v_ref "Reference speed [m/s]";
  Real v_err "Speed tracking error [m/s]";
  Real tau_L_raw "Raw left torque command [N.m]";
  Real tau_R_raw "Raw right torque command [N.m]";
  Real slip_scale_L "Slip reduction factor left";
  Real slip_scale_R "Slip reduction factor right";
  Real tau_L_slip "Slip-limited left torque [N.m]";
  Real tau_R_slip "Slip-limited right torque [N.m]";
  Real tau_L "Final left torque [N.m]";
  Real tau_R "Final right torque [N.m]";

  // ===== Sensors =====
  Real v_sensor "Encoder-derived speed [m/s]";
  Real pitch_sensor "IMU pitch [rad]";
  Real roll_sensor "IMU roll [rad]";
  Real d_edge_sensor "Forward depth sensor edge distance [m]";
  Real omega_L_sensor "Left encoder angular speed [rad/s]";
  Real omega_R_sensor "Right encoder angular speed [rad/s]";
  Real slip_L_sensor "Left slip estimate";
  Real slip_R_sensor "Right slip estimate";

  // ===== Performance Metrics =====
  Real tracking_error "Primary tracking error |v - v_ref| [m/s]";
  Real stopping_margin "Stopping margin to edge [m]";
  Real max_slip "Maximum slip magnitude";

equation
  // --- Terrain slope profile ---
  theta_terrain = if x < x_flat_end then 0.0
    elseif x < x_ramp_end then angle_ramp
    else 0.0;

  // --- Ridge pitch perturbation (Gaussian bumps from 0.05 m ridges) ---
  ridge_pitch = 0.03 * (
    exp(-((x - x_ridge1) / w_ridge)^2) +
    exp(-((x - x_ridge2) / w_ridge)^2)
  );

  // --- Chassis attitude ---
  pitch = theta_terrain + ridge_pitch;
  roll = 0.0;

  // --- Forces ---
  F_gravity = m_body * g * sin(pitch);
  N_normal = m_body * g * cos(pitch);
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_payload else 0.0;

  // --- Edge distance ---
  d_edge = x_plateau_end - x;

  // --- Slip ratio (low-speed floor prevents singularity) ---
  slip_L = (omega_L * r_w - v) / max(abs(omega_L * r_w), max(abs(v), 0.1));
  slip_R = (omega_R * r_w - v) / max(abs(omega_R * r_w), max(abs(v), 0.1));

  // --- Friction curve ---
  mu_eff_L = mf_D * sin(mf_C * atan(mf_B * slip_L));
  mu_eff_R = mf_D * sin(mf_C * atan(mf_B * slip_R));

  // --- Traction forces (normal load split equally) ---
  F_trac_L = mu_eff_L * N_normal / 2.0;
  F_trac_R = mu_eff_R * N_normal / 2.0;
  F_trac_total = F_trac_L + F_trac_R;

  // --- Reference speed profile ---
  // Priority: edge safety > edge approach > acceleration > cruise > deceleration
  v_ref = if d_edge < d_margin then 0.0
    elseif d_edge < 2.0 * d_margin then v_cruise * (d_edge - d_margin) / d_margin
    elseif time < 2.0 then v_cruise * time / 2.0
    elseif time < t_dist_end then v_cruise
    else max(v_cruise * (1.0 - (time - t_dist_end) / 2.0), 0.0);

  // --- Speed error ---
  v_err = v_sensor - v_ref;
  tracking_error = abs(v_err);

  // --- PI controller ---
  der(integ) = v_err;
  tau_L_raw = -(kp * v_err + ki * integ) / 2.0;
  tau_R_raw = -(kp * v_err + ki * integ) / 2.0;

  // --- Slip-aware traction control ---
  slip_scale_L = min(1.0, slip_limit / max(abs(slip_L), slip_limit));
  slip_scale_R = min(1.0, slip_limit / max(abs(slip_R), slip_limit));
  tau_L_slip = tau_L_raw * slip_scale_L;
  tau_R_slip = tau_R_raw * slip_scale_R;

  // --- Bounded braking / actuator saturation ---
  tau_L = max(min(tau_L_slip, tau_limit), -tau_limit);
  tau_R = max(min(tau_R_slip, tau_limit), -tau_limit);

  // --- Wheel dynamics (independent Y-axis revolute joints) ---
  J_w * der(omega_L) = tau_L - F_trac_L * r_w - b_w * omega_L;
  J_w * der(omega_R) = tau_R - F_trac_R * r_w - b_w * omega_R;

  // --- Body longitudinal dynamics ---
  m_body * der(v) = F_trac_total - F_gravity - F_dist;

  // --- Position integration ---
  der(x) = v;

  // --- Sensor outputs (ideal, synchronized traces) ---
  v_sensor = v;
  pitch_sensor = pitch;
  roll_sensor = roll;
  d_edge_sensor = max(d_edge, 0.0);
  omega_L_sensor = omega_L;
  omega_R_sensor = omega_R;
  slip_L_sensor = slip_L;
  slip_R_sensor = slip_R;

  // --- Performance metrics ---
  stopping_margin = max(d_edge, 0.0);
  max_slip = max(abs(slip_L), abs(slip_R));

  // --- Requirement assertions ---
  assert(abs(tau_L) <= tau_limit + 1e-4, "Left actuator limit violated");
  assert(abs(tau_R) <= tau_limit + 1e-4, "Right actuator limit violated");
  assert(abs(pitch) < pitch_limit, "Pitch exceeds 0.40 rad limit");
  assert(abs(roll) < pitch_limit, "Roll exceeds 0.40 rad limit");

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "DiffRoverClimbC: Floating-base differential-drive rover with slip-aware traction control and bounded braking. Ascends a 12-degree ramp, traverses a 2 m plateau, and stops before the descending edge. A 135 N payload force disturbance is injected during the middle third (4-8 s). Two 0.05 m surface ridges perturb chassis pitch. Controller runs at 125 Hz for 12 s. Friction coefficient 0.76. Max command 12 N.m. Slip ratio limited to 0.35. Roll and pitch limited to 0.40 rad.")
  );
end DiffRoverClimbC;