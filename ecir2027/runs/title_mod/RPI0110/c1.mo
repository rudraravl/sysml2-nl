model CoaxLiftDeliverB
  "Free-base coaxial aerial robot: lift, translate 5 m, deliver payload into 0.8 m radius target zone. Simulate for 10 s with output interval 0.01 s (100 Hz)."

  // ---------- Physical parameters ----------
  parameter Real m_platform(unit="kg")     = 4.40 "Platform mass [kg]";
  parameter Real m_payload(unit="kg")      = 1.20 "Payload mass [kg]";
  parameter Real L_cable(unit="m")         = 0.70 "Massless cable length [m]";
  parameter Real g_acc(unit="m/s2")        = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_max_rotor(unit="N")     = 8.20 "Max thrust per rotor channel [N]";
  parameter Integer n_rotors               = 8    "Number of rotor channels";
  parameter Real F_max_total(unit="N")     = n_rotors * F_max_rotor "Max total thrust [N]";
  parameter Real c_drag(unit="N/(m/s)^2")  = 0.12 "Quadratic aerodynamic drag coefficient [N/(m/s)^2]";
  parameter Real F_gust(unit="N")          = 5.60 "Gust disturbance magnitude [N]";
  parameter Real r_target(unit="m")        = 0.80 "Target zone radius [m]";
  parameter Real x_target(unit="m")        = 5.00 "Target zone centre x [m]";
  parameter Real z_target(unit="m")        = 0.00 "Target zone centre z [m]";
  parameter Real z_cruise(unit="m")        = 2.50 "Cruise altitude [m]";
  parameter Real z_start(unit="m")         = 0.70 "Initial platform altitude (payload near ground) [m]";
  parameter Real T_cable_max(unit="N")     = 50.0 "Cable tension upper bound [N]";
  parameter Real pi_val                    = 3.14159265358979 "Pi constant";

  // ---------- Derived total mass ----------
  Real M_total(unit="kg") = m_platform + m_payload "Combined mass [kg]";

  // ---------- Platform states ----------
  Real x(unit="m", start=0.0, fixed=true)  "Platform x position [m]";
  Real z(unit="m", start=0.70, fixed=true) "Platform z position [m]";
  Real vx(unit="m/s", start=0.0, fixed=true) "Platform x velocity [m/s]";
  Real vz(unit="m/s", start=0.0, fixed=true) "Platform z velocity [m/s]";

  // ---------- Cable pendulum states ----------
  Real theta(unit="rad", start=0.0, fixed=true) "Cable angle from vertical [rad]";
  Real omega(unit="rad/s", start=0.0, fixed=true) "Cable angular rate [rad/s]";

  // ---------- Payload kinematics ----------
  Real x_pl(unit="m") = x + L_cable*sin(theta) "Payload x position [m]";
  Real z_pl(unit="m") = z - L_cable*cos(theta) "Payload z position [m]";

  // ---------- Input-shaping filter (2nd-order) ----------
  parameter Real wn_sh(unit="rad/s")   = 2.00 "Shaping filter natural frequency [rad/s]";
  parameter Real zeta_sh               = 0.85 "Shaping filter damping ratio";
  Real xf(unit="m", start=0.0, fixed=true)   "Shaped x reference [m]";
  Real xf_d(unit="m/s", start=0.0, fixed=true) "Shaped x reference velocity [m/s]";
  Real zf(unit="m", start=0.70, fixed=true) "Shaped z reference [m]";
  Real zf_d(unit="m/s", start=0.0, fixed=true) "Shaped z reference velocity [m/s]";

  // ---------- Mission references ----------
  Real x_ref_raw(unit="m")  "Raw x trajectory [m]";
  Real z_ref_raw(unit="m")  "Raw z trajectory [m]";
  Real x_ref(unit="m")      = xf     "Shaped x reference [m]";
  Real z_ref(unit="m")      = zf     "Shaped z reference [m]";
  Real x_ref_d(unit="m/s")  = xf_d   "Shaped x ref velocity [m/s]";
  Real z_ref_d(unit="m/s")  = zf_d   "Shaped z ref velocity [m/s]";
  Real x_ref_dd(unit="m/s2") "Shaped x ref acceleration [m/s2]";
  Real z_ref_dd(unit="m/s2") "Shaped z ref acceleration [m/s2]";

  // ---------- Controller gains ----------
  parameter Real Kp_x(unit="N/m")   = 35.0 "x position gain [N/m]";
  parameter Real Kd_x(unit="Ns/m") = 24.0 "x velocity gain [Ns/m]";
  parameter Real Kp_z(unit="N/m")   = 25.0 "z position gain [N/m]";
  parameter Real Kd_z(unit="Ns/m") = 20.0 "z velocity gain [Ns/m]";
  parameter Real K_swing(unit="N/(rad/s)") = 8.0 "Cable swing damping gain [N/(rad/s)]";

  // ---------- Commands ----------
  Real F_x_cmd(unit="N")      "Unlimited horizontal force command [N]";
  Real T_cmd(unit="N")        "Unlimited total thrust command [N]";
  Real F_x(unit="N")          "Saturated horizontal force [N]";
  Real T_total(unit="N")      "Saturated total thrust [N]";
  Real thrust_per_rotor(unit="N") "Thrust per rotor channel [N]";

  // ---------- Dynamics ----------
  Real ax(unit="m/s2")    "Platform x acceleration [m/s2]";
  Real az(unit="m/s2")    "Platform z acceleration [m/s2]";
  Real alpha(unit="rad/s2") "Cable angular acceleration [rad/s2]";

  // ---------- Disturbances ----------
  Real drag_x(unit="N") "Aerodynamic drag x [N]";
  Real drag_z(unit="N") "Aerodynamic drag z [N]";
  Real gust(unit="N")   "Gust disturbance force [N]";
  Boolean gust_active   "Gust active flag";

  // ---------- Cable tension ----------
  Real T_cx(unit="N")   "Tension x-component [N]";
  Real T_cz(unit="N")   "Tension z-component [N]";
  Real T_cable(unit="N") "Cable tension magnitude [N]";

  // ---------- Sensors ----------
  Real imu_ax(unit="m/s2")    "IMU x acceleration [m/s2]";
  Real imu_az(unit="m/s2")    "IMU z acceleration [m/s2]";
  Real gps_x(unit="m")       "GPS x position [m]";
  Real gps_z(unit="m")       "GPS z position [m]";
  Real sensor_theta(unit="rad") "Cable angle measurement [rad]";
  Real sensor_tension(unit="N") "Cable tension measurement [N]";

  // ---------- Mission metrics ----------
  Real tracking_error(unit="m")   "Primary tracking error (platform vs shaped ref) [m]";
  Real payload_dist(unit="m")     "Payload distance to target centre [m]";
  Real swing_ok                   "1.0 if swing < 0.45 rad";
  Real target_ok                  "1.0 if payload in zone near end";
  Real ground_ok                  "1.0 if no ground strike";
  Real thrust_ok                  "1.0 if thrust within bounds";
  Real tension_ok                 "1.0 if tension within bounds";
  Real error_ok                   "1.0 if tracking error < 0.36 m after 6.5 s";

equation
  // === Gust: controlled 5.6 N disturbance during middle third [3.33, 6.67] s ===
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