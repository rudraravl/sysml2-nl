model DuctInspectDeliverF
  // ---------------------------------------------------------------
  // Free-base ducted-fan aerial robot: lift suspended payload,
  // translate 5 m horizontally, lower into 0.8 m-radius target zone.
  // Planar (x,z,pitch) rigid-body model + cable pendulum payload.
  // ---------------------------------------------------------------

  // Physical constants
  parameter Real g = 9.81 "m/s2";

  // Body embodiment
  parameter Real m_body = 2.7 "kg";
  parameter Real I_body = 0.06 "kg.m2";      // assumed (not stated)
  parameter Real arm_len = 0.30 "m";          // assumed fan moment arm
  parameter Real cd_x = 0.35 "N.s2/m2";       // assumed aerodynamic drag
  parameter Real cd_z = 0.35 "N.s2/m2";
  parameter Real probe_len = 0.18 "m";       // compliant inspection probe
  parameter Real F_probe_max = 6.0 "N";       // assumed probe-force bound

  // Cable and payload (assumed values - not stated)
  parameter Real L_cable = 1.0 "m";
  parameter Real m_payload = 3.0 "kg";

  // Actuation bounds
  parameter Real T_max_fan = 22.0 "N";
  parameter Real T_max_total = 4.0*T_max_fan "N";

  // Mission geometry
  parameter Real x_target = 5.0 "m";
  parameter Real r_target = 0.8 "m";
  parameter Real z_ground = 0.0 "m";

  // Gust (robustness case): 11.6 N during middle third of 20 s run
  parameter Real F_gust_amp = 11.6 "N";
  parameter Real t_gust_start = 20.0/3.0 "s";
  parameter Real t_gust_end   = 40.0/3.0 "s";

  // Control gains
  parameter Real Kp_pos = 6.0;
  parameter Real Kd_pos = 3.5;
  parameter Real Kp_th  = 12.0;
  parameter Real Kd_th  = 3.0;
  parameter Real K_swing = 1.5;       // cable-swing damping gain

  // Input-shaping reference filter
  parameter Real wn_shape = 2.0 "rad/s";
  parameter Real zeta_shape = 0.9;

  // Tension bound (assumed; thrust bound 22 N/fan is given)
  parameter Real T_cable_max = 60.0 "N";

  // ---------------- Body states ----------------
  Real x(start=0.0, fixed=true) "m";
  Real vx(start=0.0, fixed=true) "m/s";
  Real z(start=1.6, fixed=true) "m";
  Real vz(start=0.0, fixed=true) "m/s";
  Real theta(start=0.0, fixed=true) "rad (pitch, + = forward tilt)";
  Real omega(start=0.0, fixed=true) "rad/s";

  // ---------------- Payload (pendulum) states ----------------
  Real phi(start=0.0, fixed=true) "rad (cable angle from vertical)";
  Real phidot(start=0.0, fixed=true) "rad/s";

  // ---------------- Input-shaping filter states ----------------
  Real x_shape(start=0.0, fixed=true) "m";
  Real x_shape_v(start=0.0, fixed=true) "m/s";
  Real z_shape(start=1.6, fixed=true) "m";
  Real z_shape_v(start=0.0, fixed=true) "m/s";

  // ---------------- Derived kinematics ----------------
  Real xp "payload x (m)";
  Real zp "payload z (m)";
  Real ax_pivot "body (pivot) x accel (m/s2)";
  Real az_pivot "body (pivot) z accel (m/s2)";
  Real T_cable "cable tension (N)";

  // ---------------- Actuators ----------------
  Real F_gust "N";
  Real F_probe_cmd "N";
  Real F_probe "N";
  Real T1, T2, T3, T4 "per-fan thrust (N)";
  Real T_total "N";
  Real Tf, Tr "front/rear pair thrust (N)";
  Real M_cmd "pitch moment (N.m)";

  // ---------------- Reference / command ----------------
  Real x_ref "m";
  Real z_ref "m";
  Real ax_des, az_des "m/s2";
  Real theta_des "rad";
  Real T_total_raw "N";

  // ---------------- Sensors ----------------
  Real gps_x, gps_z;
  Real imu_ax, imu_az;
  Real gyro_w;
  Real cable_angle_sensor;
  Real tension_sensor;

  // ---------------- Verification metrics ----------------
  Real tracking_err "m (vs shaped reference)";
  Real swing_abs "rad";
  Real target_dist "m (from (x_target,z_ground))";
  Boolean thrust_ok;
  Boolean tension_ok;
  Boolean swing_ok;
  Boolean no_ground_strike;
  Boolean tracking_ok;
  Boolean placement_ok_final(start=false);
  Boolean tracking_ok_final(start=false);

equation
  // ---------------- Mission trajectory ----------------
  x_ref = if time < 2.0 then 0.0
          else if time < 13.0 then 5.0*(time - 2.0)/11.0
          else 5.0;
  z_ref = if time < 2.0 then 1.6 + (3.0 - 1.6)*time/2.0
          else if time < 13.0 then 3.0
          else if time < 18.0 then 3.0 - (3.0 - 1.05)*(time - 13.0)/5.0
          else 1.05;

  // ---------------- Input-shaped reference (2nd-order) ----------------
  der(x_shape) = x_shape_v;
  der(x_shape_v) = wn_shape^2*(x_ref - x_shape) - 2.0*zeta_shape*wn_shape*x_shape_v;
  der(z_shape) = z_shape_v;
  der(z_shape_v) = wn_shape^2*(z_ref - z_shape) - 2.0*zeta_shape*wn_shape*z_shape_v;

  // ---------------- Input-shaped position control + cable-swing damping ----------------
  ax_des = Kp_pos*(x_shape - x) + Kd_pos*(x_shape_v - vx) + K_swing*phidot;
  az_des = Kp_pos*(z_shape - z) + Kd_pos*(z_shape_v - vz);

  // Thrust magnitude and pitch command (gravity feedforward)
  theta_des = Modelica.Math.atan2(ax_des, az_des + g);
  T_total_raw = m_body*sqrt(ax_des^2 + (az_des + g)^2);
  T_total = if T_total_raw > T_max_total then T_max_total
            elseif T_total_raw < 0.0 then 0.0
            else T_total_raw;
  M_cmd = Kp_th*(theta_des - theta) - Kd_th*omega;

  // ---------------- Fan allocation (4 channels, bounded) ----------------
  Tf = T_total/4.0 + M_cmd/(2.0*arm_len);
  Tr = T_total/4.0 - M_cmd/(2.0*arm_len);
  T1 = if Tf < 0.0 then 0.0 elseif Tf > T_max_fan then T_max_fan else Tf;
  T2 = T1;
  T3 = if Tr < 0.0 then 0.0 elseif Tr > T_max_fan then T_max_fan else Tr;
  T4 = T3;

  // ---------------- Gust disturbance ----------------
  F_gust = if time >= t_gust_start and time <= t_gust_end then F_gust_amp else 0.0;

  // ---------------- Probe-force actuator (idle during delivery) ----------------
  F_probe_cmd = 0.0;
  F_probe = if F_probe_cmd > F_probe_max then F_probe_max
            elseif F_probe_cmd < -F_probe_max then -F_probe_max
            else F_probe_cmd;

  // ---------------- Pivot acceleration (algebraic) ----------------
  ax_pivot = (T_total*sin(theta) - cd_x*vx + F_gust + F_probe*cos(theta))/m_body;
  az_pivot = (T_total*cos(theta) - m_body*g - cd_z*vz - F_probe*sin(theta))/m_body;

  // ---------------- Body rigid-body dynamics ----------------
  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;
  der(vx) = ax_pivot;
  der(vz) = az_pivot;
  der(omega) = M_cmd/I_body;

  // ---------------- Payload pendulum (cable-swing) ----------------
  der(phi) = phidot;
  der(phidot) = -(g/L_cable)*sin(phi)
               - (ax_pivot/L_cable)*cos(phi)
               - (az_pivot/L_cable)*sin(phi);

  // ---------------- Payload pose ----------------
  xp = x + L_cable*sin(phi);
  zp = z - L_cable*cos(phi);

  // ---------------- Cable tension (no division, well-defined at phi=0) ----------------
  T_cable = m_payload*(g*cos(phi)
                      + ax_pivot*sin(phi)
                      - az_pivot*cos(phi)
                      - L_cable*phidot^2);

  // ---------------- Sensors (ideal) ----------------
  gps_x = x;
  gps_z = z;
  imu_ax = ax_pivot;
  imu_az = az_pivot;
  gyro_w = omega;
  cable_angle_sensor = phi;
  tension_sensor = T_cable;

  // ---------------- Verification criteria ----------------
  tracking_err = sqrt((x_shape - x)^2 + (z_shape - z)^2);
  swing_abs = abs(phi);
  target_dist = sqrt((xp - x_target)^2 + (zp - z_ground)^2);

  thrust_ok = (T1 <= T_max_fan + 1e-6) and (T2 <= T_max_fan + 1e-6)
          and (T3 <= T_max_fan + 1e-6) and (T4 <= T_max_fan + 1e-6)
          and (T1 >= 0.0) and (T2 >= 0.0) and (T3 >= 0.0) and (T4 >= 0.0);
  tension_ok = (T_cable >= 0.0) and (T_cable <= T_cable_max);
  swing_ok = swing_abs <= 0.45;
  no_ground_strike = (zp > z_ground) and (z > z_ground);
  tracking_ok = tracking_err <= 0.24;
algorithm
  when terminal() then
    // Final placement in target zone and final tracking check
    placement_ok_final := target_dist <= r_target;
    tracking_ok_final := tracking_err <= 0.24;
  end when;
  annotation (experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002));
end DuctInspectDeliverF;