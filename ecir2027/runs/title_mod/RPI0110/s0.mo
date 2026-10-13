model CoaxLiftDeliverB
  "Free-base coaxial aerial robot: lift, translate 5 m, deliver payload into 0.8 m-radius target zone.
   Simulate for 10 s with output interval 0.01 s (100 Hz).";

  // ---------- Physical parameters ----------
  parameter Real m_platform    = 4.40 "Platform mass [kg]";
  parameter Real m_payload     = 1.20 "Payload mass [kg]";
  parameter Real L_cable       = 0.70 "Massless cable length [m]";
  parameter Real g_acc          = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_max_rotor    = 8.20 "Max thrust per rotor channel [N]";
  parameter Integer n_rotors    = 8    "Number of rotor channels";
  parameter Real F_max_total    = n_rotors * F_max_rotor "Max total thrust [N]";
  parameter Real c_drag         = 0.12 "Quadratic aerodynamic drag coefficient [N/(m/s)^2]";
  parameter Real F_gust         = 5.60 "Gust disturbance magnitude [N]";
  parameter Real r_target       = 0.80 "Target zone radius [m]";
  parameter Real x_target       = 5.00 "Target zone centre x [m]";
  parameter Real z_target       = 0.00 "Target zone centre z [m]";
  parameter Real z_cruise       = 2.50 "Cruise altitude [m]";
  parameter Real z_start        = 0.70 "Initial / final platform altitude (payload at ground) [m]";
  parameter Real T_cable_max    = 50.0 "Cable tension upper bound [N]";
  parameter Real pi_val         = 3.14159265358979 "Pi constant";

  // ---------- Derived total mass ----------
  Real M_total = m_platform + m_payload "Combined mass [kg]";

  // ---------- Platform states ----------
  Real x (start=0.0, fixed=true) "Platform x position [m]";
  Real z (start=0.70, fixed=true) "Platform z position [m]";
  Real vx(start=0.0, fixed=true) "Platform x velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Platform z velocity [m/s]";

  // ---------- Cable pendulum states ----------
  Real theta(start=0.0, fixed=true) "Cable angle from vertical [rad]";
  Real omega(start=0.0, fixed=true) "Cable angular rate [rad/s]";

  // ---------- Payload kinematics ----------
  Real x_pl = x + L_cable*sin(theta) "Payload x position [m]";
  Real z_pl = z - L_cable*cos(theta) "Payload z position [m]";

  // ---------- Input-shaping filter (2nd-order) ----------
  parameter Real wn_sh   = 2.00 "Shaping filter natural frequency [rad/s]";
  parameter Real zeta_sh = 0.85 "Shaping filter damping ratio";
  Real xf  (start=0.0,  fixed=true) "Shaped x reference [m]";
  Real xf_d(start=0.0,  fixed=true) "Shaped x reference velocity [m/s]";
  Real zf  (start=0.70, fixed=true) "Shaped z reference [m]";
  Real zf_d(start=0.0,  fixed=true) "Shaped z reference velocity [m/s]";

  // ---------- Mission references ----------
  Real x_ref_raw "Raw x trajectory [m]";
  Real z_ref_raw "Raw z trajectory [m]";
  Real x_ref = xf     "Shaped x reference [m]";
  Real z_ref = zf     "Shaped z reference [m]";
  Real x_ref_d = xf_d "Shaped x ref velocity [m/s]";
  Real z_ref_d = zf_d "Shaped z ref velocity [m/s]";
  Real x_ref_dd "Shaped x ref acceleration [m/s2]";
  Real z_ref_dd "Shaped z ref acceleration [m/s2]";

  // ---------- Controller gains ----------
  parameter Real Kp_x   = 35.0 "x position gain [N/m]";
  parameter Real Kd_x   = 24.0 "x velocity gain [Ns/m]";
  parameter Real Kp_z   = 25.0 "z position gain [N/m]";
  parameter Real Kd_z   = 20.0 "z velocity gain [Ns/m]";
  parameter Real K_swing = 8.0  "Cable swing damping gain [N/(rad/s)]";

  // ---------- Commands ----------
  Real F_x_cmd "Unlimited horizontal force command [N]";
  Real T_cmd   "Unlimited total thrust command [N]";
  Real F_x     "Saturated horizontal force [N]";
  Real T_total "Saturated total thrust [N]";
  Real thrust_per_rotor "Thrust per rotor channel [N]";

  // ---------- Dynamics ----------
  Real ax    "Platform x acceleration [m/s2]";
  Real az    "Platform z acceleration [m/s2]";
  Real alpha "Cable angular acceleration [rad/s2]";

  // ---------- Disturbances ----------
  Real drag_x "Aerodynamic drag x [N]";
  Real drag_z "Aerodynamic drag z [N]";
  Real gust   "Gust disturbance force [N]";
  Boolean gust_active "Gust active flag";

  // ---------- Cable tension ----------
  Real T_cx   "Tension x-component [N]";
  Real T_cz   "Tension z-component [N]";
  Real T_cable "Cable tension magnitude [N]";

  // ---------- Sensors ----------
  Real imu_ax       "IMU x acceleration [m/s2]";
  Real imu_az       "IMU z acceleration [m/s2]";
  Real gps_x        "GPS x position [m]";
  Real gps_z        "GPS z position [m]";
  Real sensor_theta "Cable angle measurement [rad]";
  Real sensor_tension "Cable tension measurement [N]";

  // ---------- Mission metrics ----------
  Real tracking_error   "Primary tracking error (platform vs shaped ref) [m]";
  Real payload_dist     "Payload distance to target centre [m]";
  Real swing_ok         "1.0 if swing < 0.45 rad";
  Real target_ok       "1.0 if payload in zone near end";
  Real ground_ok       "1.0 if no ground strike";
  Real thrust_ok       "1.0 if thrust within bounds";
  Real tension_ok      "1.0 if tension within bounds";
  Real error_ok        "1.0 if tracking error < 0.36 m after 6.5 s";

equation
  // === Gust: controlled 5.6 N disturbance during middle third [3.33, 6.67] s ===
  gust_active = (time >= 10.0/3.0) and (time <= 20.0/3.0);
  gust = if gust_active then F_gust else 0.0;

  // === Raw mission trajectory ===
  // Z: lift [0,2], cruise [2,8], lower [8,10]
  z_ref_raw =
    if time < 2.0 then
      z_start + (z_cruise - z_start) * (1.0 - cos(pi_val * time / 2.0)) / 2.0
    elseif time < 8.0 then
      z_cruise
    else
      z_cruise - (z_cruise - z_start) * (1.0 - cos(pi_val * (time - 8.0) / 2.0)) / 2.0;

  // X: hold [0,2], translate [2,8], hold [8,10]
  x_ref_raw =
    if time < 2.0 then
      0.0
    elseif time < 8.0 then
      x_target * (1.0 - cos(pi_val * (time - 2.0) / 6.0)) / 2.0
    else
      x_target;

  // === Input-shaping filter (2nd-order low-pass) ===
  der(xf)   = xf_d;
  der(xf_d) = wn_sh^2 * x_ref_raw - 2.0*zeta_sh*wn_sh*xf_d - wn_sh^2*xf;
  der(zf)   = zf_d;
  der(zf_d) = wn_sh^2 * z_ref_raw - 2.0*zeta_sh*wn_sh*zf_d - wn_sh^2*zf;

  x_ref_dd = wn_sh^2 * x_ref_raw - 2.0*zeta_sh*wn_sh*xf_d - wn_sh^2*xf;
  z_ref_dd = wn_sh^2 * z_ref_raw - 2.0*zeta_sh*wn_sh*zf_d - wn_sh^2*zf;

  // === Aerodynamic drag (quadratic) ===
  drag_x = c_drag * vx * abs(vx);
  drag_z = c_drag * vz * abs(vz);

  // === Control: input-shaped position control + feedforward + swing damping ===
  F_x_cmd = Kp_x*(x_ref - x) + Kd_x*(x_ref_d - vx) + M_total*x_ref_dd + K_swing*omega;
  T_cmd   = M_total*g_acc + Kp_z*(z_ref - z) + Kd_z*(z_ref_d - vz);

  // === Command saturation ===
  T_total = max(0.0, min(F_max_total, T_cmd));
  F_x     = max(-F_max_total, min(F_max_total, F_x_cmd));
  thrust_per_rotor = T_total / n_rotors;

  // === Cable angular acceleration (Lagrangian derivation) ===
  // alpha = -((F_x - drag_x - gust)*cos(theta) + (T_total - drag_z)*sin(theta)) / (m_platform * L)
  alpha = -((F_x - drag_x - gust)*cos(theta) + (T_total - drag_z)*sin(theta))
          / (m_platform * L_cable);

  // === Platform accelerations ===
  ax = (F_x - drag_x - gust
        - m_payload*L_cable*(alpha*cos(theta) - omega^2*sin(theta))) / M_total;
  az = (T_total - drag_z - M_total*g_acc
        - m_payload*L_cable*(alpha*sin(theta) + omega^2*cos(theta))) / M_total;

  // === State derivatives ===
  der(x)     = vx;
  der(z)     = vz;
  der(vx)    = ax;
  der(vz)    = az;
  der(theta) = omega;
  der(omega) = alpha;

  // === Cable tension (from payload Newton equations) ===
  T_cx = m_payload * (ax + L_cable*(alpha*cos(theta) - omega^2*sin(theta)));
  T_cz = m_payload * (az + L_cable*(alpha*sin(theta) + omega^2*cos(theta))) + m_payload*g_acc;
  T_cable = sqrt(max(0.0, T_cx^2 + T_cz^2));

  // === Sensors ===
  imu_ax       = ax;
  imu_az       = az;
  gps_x        = x;
  gps_z        = z;
  sensor_theta = theta;
  sensor_tension = T_cable;

  // === Mission metrics ===
  tracking_error = sqrt(max(0.0, (x_ref - x)^2 + (z_ref - z)^2));
  payload_dist   = sqrt(max(0.0, (x_pl - x_target)^2 + (z_pl - z_target)^2));
  swing_ok       = if abs(theta) < 0.45 then 1.0 else 0.0;
  target_ok      = if (time >= 9.5) and (payload_dist < r_target) then 1.0 else 0.0;
  ground_ok      = if (z_pl >= -0.001) and (z >= -0.001) then 1.0 else 0.0;
  thrust_ok      = if (T_total >= 0.0) and (T_total <= F_max_total) then 1.0 else 0.0;
  tension_ok     = if (T_cable >= 0.0) and (T_cable <= T_cable_max) then 1.0 else 0.0;
  error_ok       = if (time >= 6.5) and (tracking_error < 0.36) then 1.0 else 0.0;

end CoaxLiftDeliverB;