model DuctInspectDeliverB
  "Free-base aerial robot with suspended payload: lift, translate 5 m, lower into target zone";

  // ========= Parameters stated in requirement =========
  parameter Real m_body = 2.7 "Body mass [kg]";
  parameter Real F_max_per_fan = 14.8 "Allowed command magnitude per fan [N]";
  parameter Real probe_length = 0.18 "Inspection probe length along body X [m]";
  parameter Real target_radius = 0.8 "Target zone radius [m]";
  parameter Real x_target = 5.0 "Horizontal translation distance [m]";
  parameter Real F_gust = 5.6 "Gust disturbance force [N]";
  parameter Real swing_limit = 0.45 "Max cable swing angle [rad]";
  parameter Real tracking_limit = 0.36 "Max primary tracking error after 6.5 s [m]";
  parameter Real T_sim = 10.0 "Mission duration [s]";
  parameter Real f_ctrl = 100.0 "Control loop frequency [Hz]";

  // ========= Assumed parameters (not stated; labeled as assumed) =========
  parameter Real L_cable = 1.0 "Cable length [m] -- assumed";
  parameter Real m_payload = 0.5 "Payload mass [kg] -- assumed";
  parameter Real z0 = 2.0 "Initial body height [m] -- assumed";
  parameter Real z_cruise = 3.5 "Cruise body height [m] -- assumed";
  parameter Real z_ground = 0.0 "Ground level [m] -- assumed";
  parameter Real c_drag = 0.15 "Aerodynamic drag coefficient [N.s/m] -- assumed";
  parameter Real c_cable = 0.05 "Cable damping coefficient [N.m.s/rad] -- assumed";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ========= Assumed control gains =========
  parameter Real Kp_x = 12.0 "X position proportional gain -- assumed";
  parameter Real Kd_x = 6.0 "X velocity derivative gain -- assumed";
  parameter Real Kp_z = 20.0 "Z position proportional gain -- assumed";
  parameter Real Kd_z = 8.0 "Z velocity derivative gain -- assumed";
  parameter Real K_swing = 4.0 "Cable swing damping gain -- assumed";

  // ========= Derived constants =========
  parameter Real F_max_total = 4.0 * F_max_per_fan "Total max thrust [N]";
  parameter Real M_total = m_body + m_payload "Total suspended mass [kg]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control timestep [s]";
  parameter Real T1 = T_sim / 3.0 "End of lift phase [s]";
  parameter Real T2 = 2.0 * T_sim / 3.0 "End of translate phase [s]";
  parameter Real z_lower = L_cable + 0.15 "Body height during lowering [m] -- assumed";

  // ========= Body states =========
  Real x(start = 0.0, fixed = true) "Body x position [m]";
  Real z(start = z0, fixed = true) "Body z position [m]";
  Real vx(start = 0.0, fixed = true) "Body x velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "Body z velocity [m/s]";

  // ========= Cable states =========
  Real theta(start = 0.0, fixed = true) "Cable angle from vertical [rad]";
  Real theta_dot(start = 0.0, fixed = true) "Cable angular velocity [rad/s]";

  // ========= Payload position (derived) =========
  Real x_payload "Payload x position [m]";
  Real z_payload "Payload z position [m]";

  // ========= Cable tension =========
  Real T_cable "Cable tension [N]";

  // ========= Control commands =========
  Real F_x_cmd "Unsaturated x-force command [N]";
  Real F_z_cmd "Unsaturated z-force command [N]";
  Real F_x_sat "Saturated x-force [N]";
  Real F_z_sat "Saturated z-force [N]";
  Real F_total "Total thrust magnitude [N]";
  Real F_total_sat "Saturated total thrust [N]";
  Real F_total_safe "Total thrust magnitude with zero-guard [N]";

  // ========= Individual fan thrusts =========
  Real f1 "Fan 1 thrust [N]";
  Real f2 "Fan 2 thrust [N]";
  Real f3 "Fan 3 thrust [N]";
  Real f4 "Fan 4 thrust [N]";

  // ========= Probe =========
  // Probe-force actuator bound and interaction model are unknown;
  // command is set to zero and compliance is not modeled.
  Real F_probe "Probe-force actuator command [N]";
  Real x_probe_tip "Probe tip x position [m]";

  // ========= Body attitude (derived, observable) =========
  Real phi "Body tilt angle for force direction [rad]";

  // ========= Reference trajectory (input-shaped) =========
  Real x_ref "Reference x position [m]";
  Real z_ref "Reference z position [m]";
  Real vx_ref "Reference x velocity [m/s]";
  Real vz_ref "Reference z velocity [m/s]";

  // ========= Discrete control references (100 Hz) =========
  discrete Real x_ref_d(start = 0.0, fixed = true) "Sampled x reference [m]";
  discrete Real z_ref_d(start = z0, fixed = true) "Sampled z reference [m]";
  discrete Real vx_ref_d(start = 0.0, fixed = true) "Sampled vx reference [m/s]";
  discrete Real vz_ref_d(start = 0.0, fixed = true) "Sampled vz reference [m/s]";

  // ========= Gust disturbance =========
  Real gust_force "Applied gust force [N]";

  // ========= Sensors =========
  Real imu_ax "IMU x acceleration [m/s2]";
  Real imu_az "IMU z acceleration [m/s2]";
  Real gps_x "GPS x position [m]";
  Real gps_z "GPS z position [m]";
  Real sensor_theta "Cable angle measurement [rad]";
  Real sensor_tension "Tension measurement [N]";

  // ========= Performance metrics =========
  Real tracking_error "Primary tracking error [m]";
  Real final_payload_distance "Payload distance from target center [m]";

  // ========= Intermediate dynamics =========
  Real ax "Body x acceleration [m/s2]";
  Real az_acc "Body z acceleration [m/s2]";
  Real theta_ddot "Cable angular acceleration [rad/s2]";
  Real s_th "sin(theta)";
  Real c_th "cos(theta)";
  Real det_sys "System determinant [kg2]";
  Real RHS_x "Right-hand side x [N]";
  Real RHS_z "Right-hand side z [N]";
  Real F_swing_x "Swing damping x-force [N]";
  Real F_swing_z "Swing damping z-force [N]";

equation
  // ---- Trigonometric helpers ----
  s_th = sin(theta);
  c_th = cos(theta);
  det_sys = m_body * M_total;

  // ---- Payload position from cable geometry ----
  x_payload = x + L_cable * s_th;
  z_payload = z - L_cable * c_th;

  // ---- Probe tip (body assumed near-upright) ----
  x_probe_tip = x + probe_length;
  F_probe = 0.0;

  // ---- Gust: injected during middle third of mission ----
  gust_force = if (time >= T1 and time <= T2) then F_gust else 0.0;

  // ======== Input-shaped reference trajectory (smooth cosine profiles) ========
  z_ref = if time <= T1 then
      z0 + (z_cruise - z0) * (1.0 - cos(3.14159265358979 * time / T1)) / 2.0
    elseif time <= T2 then
      z_cruise
    else
      z_cruise + (z_lower - z_cruise) * (1.0 - cos(3.14159265358979 * (time - T2) / (T_sim - T2))) / 2.0;

  vz_ref = if time <= T1 then
      (z_cruise - z0) * 3.14159265358979 / T1 * sin(3.14159265358979 * time / T1) / 2.0
    elseif time <= T2 then
      0.0
    else
      (z_lower - z_cruise) * 3.14159265358979 / (T_sim - T2) * sin(3.14159265358979 * (time - T2) / (T_sim - T2)) / 2.0;

  x_ref = if time <= T1 then
      0.0
    elseif time <= T2 then
      x_target * (1.0 - cos(3.14159265358979 * (time - T1) / (T2 - T1))) / 2.0
    else
      x_target;

  vx_ref = if time <= T1 then
      0.0
    elseif time <= T2 then
      x_target * 3.14159265358979 / (T2 - T1) * sin(3.14159265358979 * (time - T1) / (T2 - T1)) / 2.0
    else
      0.0;

  // ======== Discrete control sampling at 100 Hz ========
  when sample(0, dt_ctrl) then
    x_ref_d = x_ref;
    z_ref_d = z_ref;
    vx_ref_d = vx_ref;
    vz_ref_d = vz_ref;
  end when;

  // ======== Swing damping force (opposes cable angular velocity) ========
  F_swing_x = -K_swing * theta_dot * c_th;
  F_swing_z = K_swing * theta_dot * s_th;

  // ======== Position control with input-shaped reference ========
  F_x_cmd = Kp_x * (x_ref_d - x) + Kd_x * (vx_ref_d - vx) + F_swing_x;
  F_z_cmd = Kp_z * (z_ref_d - z) + Kd_z * (vz_ref_d - vz) + M_total * g + F_swing_z;

  // ======== Thrust saturation ========
  F_total = sqrt(F_x_cmd * F_x_cmd + F_z_cmd * F_z_cmd);
  F_total_safe = if F_total > 0.001 then F_total else 0.001;
  F_total_sat = if F_total > F_max_total then F_max_total else F_total;
  // Guard against division by zero when total command is near zero
  F_x_sat = if F_total > 0.001 then F_total_sat * F_x_cmd / F_total_safe else 0.0;
  F_z_sat = if F_total > 0.001 then F_total_sat * F_z_cmd / F_total_safe else F_max_total;

  // Individual fan thrusts (equal distribution)
  f1 = F_total_sat / 4.0;
  f2 = F_total_sat / 4.0;
  f3 = F_total_sat / 4.0;
  f4 = F_total_sat / 4.0;

  // Body tilt angle for force direction (safe atan)
  phi = if F_z_sat > 0.001 then atan(F_x_sat / F_z_sat) else 0.0;

  // ======== Dynamics: pendulum on moving support (2D, x-z plane) ========
  RHS_x = F_x_sat - c_drag * vx + gust_force
          + m_payload * g * c_th * s_th
          + (c_cable / L_cable) * c_th * theta_dot
          + m_payload * L_cable * s_th * theta_dot * theta_dot;

  RHS_z = F_z_sat - c_drag * vz - M_total * g
          + m_payload * g * s_th * s_th
          - (c_cable / L_cable) * s_th * theta_dot
          - m_payload * L_cable * c_th * theta_dot * theta_dot;

  // Solve 2x2 linear system for body accelerations
  ax = ((m_body + m_payload * c_th * c_th) * RHS_x
        + m_payload * c_th * s_th * RHS_z) / det_sys;
  az_acc = (m_payload * s_th * c_th * RHS_x
            + (m_body + m_payload * s_th * s_th) * RHS_z) / det_sys;

  // Cable angular acceleration from pendulum equation
  theta_ddot = (-ax * c_th - az_acc * s_th - g * s_th
                - (c_cable / (m_payload * L_cable)) * theta_dot) / L_cable;

  // State derivatives
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax;
  der(vz) = az_acc;
  der(theta) = theta_dot;
  der(theta_dot) = theta_ddot;

  // Cable tension from radial constraint of payload
  T_cable = m_payload * (g * c_th - ax * s_th + az_acc * c_th
                         + L_cable * theta_dot * theta_dot);

  // ======== Sensors ========
  imu_ax = ax;
  imu_az = az_acc;
  gps_x = x;
  gps_z = z;
  sensor_theta = theta;
  sensor_tension = T_cable;

  // ======== Performance metrics ========
  tracking_error = sqrt((x - x_ref) * (x - x_ref) + (z - z_ref) * (z - z_ref));
  final_payload_distance = sqrt((x_payload - x_target) * (x_payload - x_target)
                                + z_payload * z_payload);

  // ======== Requirement assertions ========
  assert(f1 <= F_max_per_fan + 1e-6, "Fan 1 thrust exceeded 14.8 N bound");
  assert(f2 <= F_max_per_fan + 1e-6, "Fan 2 thrust exceeded 14.8 N bound");
  assert(f3 <= F_max_per_fan + 1e-6, "Fan 3 thrust exceeded 14.8 N bound");
  assert(f4 <= F_max_per_fan + 1e-6, "Fan 4 thrust exceeded 14.8 N bound");
  assert(T_cable >= -1e-6, "Cable tension went negative (slack cable)");
  assert(abs(theta) <= swing_limit + 1e-6, "Cable swing exceeded 0.45 rad");
  assert(z > z_ground + 0.05, "Body ground strike detected");
  assert(z_payload >= z_ground - 0.01, "Payload ground strike detected");
  assert(time < 6.5 or tracking_error <= tracking_limit + 1e-6,
         "Primary tracking error exceeded 0.36 m after 6.5 s");
  assert(time < T_sim - 0.01 or final_payload_distance <= target_radius + 1e-6,
         "Payload not within 0.8 m target zone at mission end");

end DuctInspectDeliverB;