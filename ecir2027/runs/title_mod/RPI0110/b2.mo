model CoaxLiftDeliverB
  "Free-base coaxial aerial robot: lift, translate 5 m, deliver payload into 0.8 m-radius target zone. Simulate for 10 s at 100 Hz.";

  // ---------- Physical parameters ----------
  parameter Real m_platform(final unit="kg") = 4.40 "Platform mass";
  parameter Real m_payload(final unit="kg")  = 1.20 "Payload mass";
  parameter Real L_cable(final unit="m")     = 0.70 "Massless cable length";
  parameter Real g_acc(final unit="m/s2")    = 9.81 "Gravitational acceleration";
  parameter Real F_max_rotor(final unit="N") = 8.20 "Max thrust per rotor channel";
  parameter Integer n_rotors                 = 8    "Number of rotor channels";
  parameter Real F_max_total(final unit="N")  = n_rotors * F_max_rotor "Max total thrust";
  parameter Real c_drag(final unit="N.s2/m2") = 0.12 "Quadratic drag coefficient";
  parameter Real F_gust(final unit="N")       = 5.60 "Gust disturbance magnitude";
  parameter Real r_target(final unit="m")     = 0.80 "Target zone radius";
  parameter Real x_target(final unit="m")     = 5.00 "Target zone centre x";
  parameter Real z_target(final unit="m")     = 0.00 "Target zone centre z";
  parameter Real z_cruise(final unit="m")     = 2.50 "Cruise altitude";
  parameter Real z_start(final unit="m")      = 0.70 "Initial/final platform altitude";
  parameter Real T_cable_max(final unit="N")  = 50.0 "Cable tension upper bound";
  constant Real pi_val                       = 3.14159265358979 "Pi constant";

  // ---------- Combined mass ----------
  Real M_total(final unit="kg") = m_platform + m_payload "Combined mass";

  // ---------- Platform states ----------
  Real x(final unit="m", start=0.0, fixed=true) "Platform x position";
  Real z(final unit="m", start=0.70, fixed=true) "Platform z position";
  Real vx(final unit="m/s", start=0.0, fixed=true) "Platform x velocity";
  Real vz(final unit="m/s", start=0.0, fixed=true) "Platform z velocity";

  // ---------- Cable pendulum states ----------
  Real theta(final unit="rad", start=0.0, fixed=true) "Cable angle from vertical";
  Real omega(final unit="rad/s", start=0.0, fixed=true) "Cable angular rate";

  // ---------- Payload kinematics ----------
  Real x_pl(final unit="m") = x + L_cable*sin(theta) "Payload x position";
  Real z_pl(final unit="m") = z - L_cable*cos(theta) "Payload z position";

  // ---------- Input-shaping filter ----------
  parameter Real wn_sh(final unit="rad/s")  = 2.00 "Shaping filter natural frequency";
  parameter Real zeta_sh                    = 0.85 "Shaping filter damping ratio";
  Real xf(final unit="m", start=0.0, fixed=true) "Shaped x reference";
  Real xf_d(final unit="m/s", start=0.0, fixed=true) "Shaped x ref velocity";
  Real zf(final unit="m", start=0.70, fixed=true) "Shaped z reference";
  Real zf_d(final unit="m/s", start=0.0, fixed=true) "Shaped z ref velocity";

  // ---------- Mission references ----------
  Real x_ref_raw(final unit="m") "Raw x trajectory";
  Real z_ref_raw(final unit="m") "Raw z trajectory";
  Real x_ref(final unit="m") = xf "Shaped x reference";
  Real z_ref(final unit="m") = zf "Shaped z reference";
  Real x_ref_d(final unit="m/s") = xf_d "Shaped x ref velocity";
  Real z_ref_d(final unit="m/s") = zf_d "Shaped z ref velocity";
  Real x_ref_dd(final unit="m/s2") "Shaped x ref acceleration";
  Real z_ref_dd(final unit="m/s2") "Shaped z ref acceleration";

  // ---------- Controller gains ----------
  parameter Real Kp_x(final unit="N/m")   = 35.0 "x position gain";
  parameter Real Kd_x(final unit="N.s/m") = 24.0 "x velocity gain";
  parameter Real Kp_z(final unit="N/m")   = 25.0 "z position gain";
  parameter Real Kd_z(final unit="N.s/m") = 20.0 "z velocity gain";
  parameter Real K_swing(final unit="N.s/rad") = 8.0 "Cable swing damping gain";

  // ---------- Commands ----------
  Real F_x_cmd(final unit="N") "Unlimited horizontal force command";
  Real T_cmd(final unit="N") "Unlimited total thrust command";
  Real F_x(final unit="N") "Saturated horizontal force";
  Real T_total(final unit="N") "Saturated total thrust";
  Real thrust_per_rotor(final unit="N") "Thrust per rotor channel";

  // ---------- Dynamics ----------
  Real ax(final unit="m/s2") "Platform x acceleration";
  Real az(final unit="m/s2") "Platform z acceleration";
  Real alpha(final unit="rad/s2") "Cable angular acceleration";

  // Explicit coupled-solution intermediates
  Real s_th "sin(theta)";
  Real c_th "cos(theta)";
  Real rx_dd(final unit="m/s2") "Payload relative x acceleration";
  Real rz_dd(final unit="m/s2") "Payload relative z acceleration";
  Real b1(final unit="N");
  Real b2(final unit="N");
  Real b3(final unit="m/s2");
  Real A11(final unit="kg");
  Real A22(final unit="kg");
  Real A13(final unit="kg.m");
  Real A23(final unit="kg.m");
  Real A31 "dimensionless";
  Real A32 "dimensionless";
  Real A33(final unit="m");
  Real det_factor(final unit="m");
  Real F_x_eff(final unit="N");
  Real F_z_eff(final unit="N");

  // ---------- Disturbances ----------
  Real drag_x(final unit="N") "Aerodynamic drag x";
  Real drag_z(final unit="N") "Aerodynamic drag z";
  Real gust(final unit="N") "Gust disturbance force";
  Boolean gust_active "Gust active flag";

  // ---------- Cable tension ----------
  Real T_cx(final unit="N") "Tension x-component";
  Real T_cz(final unit="N") "Tension z-component";
  Real T_cable(final unit="N") "Cable tension magnitude";

  // ---------- Sensors ----------
  Real imu_ax(final unit="m/s2") "IMU x acceleration";
  Real imu_az(final unit="m/s2") "IMU z acceleration";
  Real gps_x(final unit="m") "GPS x position";
  Real gps_z(final unit="m") "GPS z position";
  Real sensor_theta(final unit="rad") "Cable angle measurement";
  Real sensor_tension(final unit="N") "Cable tension measurement";

  // ---------- Mission metrics ----------
  Real tracking_error(final unit="m") "Primary tracking error";
  Real payload_dist(final unit="m") "Payload distance to target centre";
  Real swing_ok "1.0 if swing < 0.45 rad";
  Real target_ok "1.0 if payload in zone near end";
  Real ground_ok "1.0 if no ground strike";
  Real thrust_ok "1.0 if thrust within bounds";
  Real tension_ok "1.0 if tension within bounds";
  Real error_ok "1.0 if tracking error < 0.36 m after 6.5 s";

equation
  // === Gust during middle third ===
  gust_active = (time >= 10.0/3.0) and (time <= 20.0/3.0);
  gust = if gust_active then F_gust else 0.0;

  // === Raw mission trajectory ===
  z_ref_raw =
    if time < 2.0 then
      z_start + (z_cruise - z_start) * (1.0 - cos(pi_val * time / 2.0)) / 2.0
    elseif time < 8.0 then
      z_cruise
    else
      z_cruise - (z_cruise - z_start) * (1.0 - cos(pi_val * (time - 8.0) / 2.0)) / 2.0;

  x_ref_raw =
    if time < 2.0 then
      0.0
    elseif time < 8.0 then
      x_target * (1.0 - cos(pi_val * (time - 2.0) / 6.0)) / 2.0
    else
      x_target;

  // === Input-shaping filter ===
  der(xf)   = xf_d;
  der(xf_d) = wn_sh^2 * x_ref_raw - 2.0*zeta_sh*wn_sh*xf_d - wn_sh^2*xf;
  der(zf)   = zf_d;
  der(zf_d) = wn_sh^2 * z_ref_raw - 2.0*zeta_sh*wn_sh*zf_d - wn_sh^2*zf;

  x_ref_dd = wn_sh^2 * x_ref_raw - 2.0*zeta_sh*wn_sh*xf_d - wn_sh^2*xf;
  z_ref_dd = wn_sh^2 * z_ref_raw - 2.0*zeta_sh*wn_sh*zf_d - wn_sh^2*zf;

  // === Aerodynamic drag ===
  drag_x = c_drag * vx * abs(vx);
  drag_z = c_drag * vz * abs(vz);

  // === Control ===
  F_x_cmd = Kp_x*(x_ref - x) + Kd_x*(x_ref_d - vx) + M_total*x_ref_dd + K_swing*omega;
  T_cmd   = M_total*g_acc + Kp_z*(z_ref - z) + Kd_z*(z_ref_d - vz);

  T_total = max(0.0, min(F_max_total, T_cmd));
  F_x     = max(-F_max_total, min(F_max_total, F_x_cmd));
  thrust_per_rotor = T_total / n_rotors;

  // === Effective forces (excluding cable-coupling) ===
  F_x_eff = F_x - drag_x - gust;
  F_z_eff = T_total - drag_z;

  // === Coupled platform-pendulum linear solve (scalar) ===
  s_th = sin(theta);
  c_th = cos(theta);

  A11 = M_total;
  A22 = M_total;
  A13 = m_payload * L_cable * c_th;
  A23 = m_payload * L_cable * s_th;
  A31 = c_th;
  A32 = s_th;
  A33 = L_cable;

  b1 = F_x_eff + m_payload * L_cable * omega * omega * s_th;
  b2 = F_z_eff - m_payload * g_acc - m_payload * L_cable * omega * omega * c_th;
  b3 = -g_acc * s_th;

  det_factor = A33 - A31*A13/A11 - A32*A23/A22;
  alpha = (b3 - A31*b1/A11 - A32*b2/A22) / det_factor;

  ax = (b1 - A13*alpha) / A11;
  az = (b2 - A23*alpha) / A22;

  // === Relative payload acceleration components ===
  rx_dd = L_cable * (alpha * c_th - omega * omega * s_th);
  rz_dd = L_cable * (alpha * s_th + omega * omega * c_th);

  // === State derivatives ===
  der(x)     = vx;
  der(z)     = vz;
  der(vx)    = ax;
  der(vz)    = az;
  der(theta) = omega;
  der(omega) = alpha;

  // === Cable tension ===
  T_cx = m_payload * (ax + rx_dd);
  T_cz = m_payload * (az + rz_dd) + m_payload * g_acc;
  T_cable = sqrt(max(0.0, T_cx*T_cx + T_cz*T_cz));

  // === Sensors ===
  imu_ax       = ax;
  imu_az       = az;
  gps_x        = x;
  gps_z        = z;
  sensor_theta = theta;
  sensor_tension = T_cable;

  // === Mission metrics ===
  tracking_error = sqrt(max(0.0, (x_ref - x)*(x_ref - x) + (z_ref - z)*(z_ref - z)));
  payload_dist   = sqrt(max(0.0, (x_pl - x_target)*(x_pl - x_target) + (z_pl - z_target)*(z_pl - z_target)));
  swing_ok       = if abs(theta) < 0.45 then 1.0 else 0.0;
  target_ok      = if (time >= 9.5) and (payload_dist < r_target) then 1.0 else 0.0;
  ground_ok      = if (z_pl >= -0.001) and (z >= -0.001) then 1.0 else 0.0;
  thrust_ok      = if (T_total >= 0.0) and (T_total <= F_max_total) then 1.0 else 0.0;
  tension_ok     = if (T_cable >= 0.0) and (T_cable <= T_cable_max) then 1.0 else 0.0;
  error_ok       = if (time >= 6.5) and (tracking_error < 0.36) then 1.0 else 0.0;

end CoaxLiftDeliverB;