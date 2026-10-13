model AUVDockC
  "Free-base marine robot: speed-scheduled pose control with contact transition"

  // ==================== Physical Constants ====================
  parameter Real rho_sw = 1025 "Seawater density [kg/m3]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";

  // ==================== Vehicle Parameters ====================
  parameter Real m_hull = 85 "Hull mass [kg]";
  parameter Real L_hull = 1.5 "Hull length [m]";
  parameter Real V_disp = 0.083 "Displaced volume [m3]";
  parameter Real I_z = m_hull * L_hull ^ 2 / 12 "Yaw moment of inertia [kg.m2]";
  parameter Real arm_th = L_hull / 2 "Thruster moment arm [m]";

  // ==================== Actuator Limit ====================
  parameter Real F_max = 101 "Maximum command per thruster [N]";

  // ==================== Controller Parameters ====================
  parameter Real v_cruise = 2.5 "Cruise approach speed [m/s]";
  parameter Real Kp_u = 300 "Surge velocity proportional gain [N.s/m]";
  parameter Real Kp_psi = 100 "Yaw proportional gain [N.m/rad]";
  parameter Real Kd_psi = 40 "Yaw derivative gain [N.m.s/rad]";
  parameter Real K_y = 0.5 "Lateral steering gain [rad/m]";
  parameter Real psi_max = 0.8 "Maximum yaw command magnitude [rad]";
  parameter Real Kp_z = 100 "Heave proportional gain [N/m]";
  parameter Real Kd_z = 50 "Heave derivative gain [N.s/m]";

  // ==================== Drag Coefficients ====================
  parameter Real Cd_u = 25 "Surge quadratic drag [kg/m]";
  parameter Real Cd_v = 40 "Sway quadratic drag [kg/m]";
  parameter Real Cd_w = 25 "Heave quadratic drag [kg/m]";
  parameter Real Cd_r = 3 "Yaw quadratic drag [kg.m2]";

  // ==================== Contact & Funnel Parameters ====================
  parameter Real k_contact = 2000 "Compliant ring axial stiffness [N/m]";
  parameter Real d_contact = 300 "Compliant ring axial damping [N.s/m]";
  parameter Real k_funnel = 800 "Funnel lateral stiffness [N/m]";
  parameter Real d_funnel = 80 "Funnel lateral damping [N.s/m]";
  parameter Real r_funnel_in = 0.25 "Funnel entrance radius [m]";
  parameter Real r_funnel_out = 0.02 "Funnel throat radius [m]";
  parameter Real funnel_len = 0.3 "Funnel length [m]";
  parameter Real r_capture = 0.15 "Capture tolerance radius [m]";
  parameter Real psi_capture = 0.1 "Capture yaw tolerance [rad]";

  // ==================== Disturbance Parameters ====================
  parameter Real F_current = 126 "Current force magnitude [N]";
  parameter Real t_current_start = 4.0 "Current disturbance start time [s]";
  parameter Real t_current_end = 8.0 "Current disturbance end time [s]";

  // ==================== Dock Geometry ====================
  parameter Real x_dock = 0.0 "Dock face x position [m]";
  parameter Real y_dock = 0.0 "Dock center y position [m]";
  parameter Real z_dock = 0.0 "Dock center z position [m]";

  // ==================== Speed Limit ====================
  parameter Real speed_limit = 3.0 "Maximum allowable speed [m/s]";

  // ==================== Dynamic States ====================
  Real x(start = -8.0, fixed = true) "AUV x position [m]";
  Real y(start = 0.0, fixed = true) "AUV y position [m]";
  Real z(start = 0.0, fixed = true) "AUV z position [m]";
  Real psi(start = 0.0, fixed = true) "Yaw angle [rad]";
  Real u(start = 0.0, fixed = true) "Surge velocity body frame [m/s]";
  Real v(start = 0.0, fixed = true) "Sway velocity body frame [m/s]";
  Real w(start = 0.0, fixed = true) "Heave velocity body frame [m/s]";
  Real r(start = 0.0, fixed = true) "Yaw rate body frame [rad/s]";

  // ==================== Kinematic Variables ====================
  Real x_dot "Inertial x velocity [m/s]";
  Real y_dot "Inertial y velocity [m/s]";
  Real z_dot "Inertial z velocity [m/s]";

  // ==================== Buoyancy ====================
  Real F_buoy "Buoyancy force [N]";
  Real F_net_buoy "Net buoyancy positive upward [N]";

  // ==================== Nose & Distance ====================
  Real nose_x "Nose x position [m]";
  Real nose_dist "Nose distance to dock face [m]";

  // ==================== Contact ====================
  Real penetration "Axial contact penetration [m]";
  Real F_contact_axial "Axial contact force inertial x [N]";
  Real F_contact_mag "Contact force magnitude [N]";

  // ==================== Funnel ====================
  Boolean funnel_active "Funnel region active";
  Real r_funnel_val "Funnel radius at nose position [m]";
  Real y_pen "Lateral penetration into funnel wall [m]";
  Real z_pen "Vertical penetration into funnel wall [m]";
  Real F_funnel_y "Funnel lateral force inertial y [N]";
  Real F_funnel_z "Funnel vertical force inertial z [N]";
  Real F_funnel_mag "Funnel force magnitude [N]";

  // ==================== Current Disturbance ====================
  Real F_current_y "Current force inertial y [N]";
  Real F_current_u "Current force body surge [N]";
  Real F_current_v "Current force body sway [N]";

  // ==================== Drag ====================
  Real F_drag_u "Surge drag [N]";
  Real F_drag_v "Sway drag [N]";
  Real F_drag_w "Heave drag [N]";
  Real M_drag_r "Yaw drag moment [N.m]";

  // ==================== Control Commands ====================
  Real v_cmd "Commanded surge speed [m/s]";
  Real psi_cmd "Commanded yaw [rad]";
  Real F_surge_total_cmd "Total surge force command [N]";
  Real M_yaw_cmd "Yaw moment command [N.m]";
  Real F_heave_cmd "Total heave force command [N]";

  // ==================== Thruster Commands & Saturated Forces ====================
  Real F_surge_port_cmd "Port surge command [N]";
  Real F_surge_stbd_cmd "Starboard surge command [N]";
  Real F_heave_fwd_cmd "Forward heave command [N]";
  Real F_heave_aft_cmd "Aft heave command [N]";
  Real F_surge_port "Port surge force saturated [N]";
  Real F_surge_stbd "Starboard surge force saturated [N]";
  Real F_heave_fwd "Forward heave force saturated [N]";
  Real F_heave_aft "Aft heave force saturated [N]";
  Real F_surge_total "Total surge force [N]";
  Real F_heave_total "Total heave force [N]";

  // ==================== Body-frame Contact & Funnel Forces ====================
  Real F_contact_u "Contact force body surge [N]";
  Real F_contact_v "Contact force body sway [N]";
  Real F_funnel_u "Funnel force body surge [N]";
  Real F_funnel_v "Funnel force body sway [N]";
  Real F_funnel_w "Funnel force body heave [N]";
  Real M_funnel_r "Funnel yaw moment [N.m]";
  Real M_contact_r "Contact yaw moment [N.m]";

  // ==================== Sensors ====================
  Real sonar_range "Sonar range to dock [m]";
  Real pressure_depth "Pressure-derived depth [m]";
  Real imu_u "IMU surge velocity [m/s]";
  Real imu_v "IMU sway velocity [m/s]";
  Real imu_w "IMU heave velocity [m/s]";
  Real imu_r "IMU yaw rate [rad/s]";
  Boolean optical_valid "Optical pose sensor in range";
  Real optical_x "Optical relative x [m]";
  Real optical_y "Optical relative y [m]";
  Real optical_psi "Optical relative yaw [rad]";

  // ==================== Performance Metrics ====================
  Real speed "Total speed [m/s]";
  Real track_error "Primary tracking error [m]";
  Boolean speed_bounded "Speed within bounds";
  Boolean actuator_bounded "All actuators within limits";
  Boolean contact_safe "Contact force below 500 N";
  Boolean aligned "Lateral and yaw aligned";
  Boolean captured "Capture established";
  Boolean no_nan_inf "No NaN or infinite values";

equation
  // ==================== Buoyancy ====================
  F_buoy = rho_sw * V_disp * g_acc;
  F_net_buoy = F_buoy - m_hull * g_acc;

  // ==================== Kinematics ====================
  x_dot = u * cos(psi) - v * sin(psi);
  y_dot = u * sin(psi) + v * cos(psi);
  z_dot = w;

  der(x) = x_dot;
  der(y) = y_dot;
  der(z) = z_dot;
  der(psi) = r;

  // ==================== Nose Position & Distance ====================
  nose_x = x + L_hull / 2.0;
  nose_dist = x_dock - nose_x;

  // ==================== Current Disturbance (middle third 4 to 8 s) ====================
  F_current_y = if (time >= t_current_start and time <= t_current_end) then F_current else 0.0;
  F_current_u = F_current_y * sin(psi);
  F_current_v = F_current_y * cos(psi);

  // ==================== Quadratic Drag ====================
  F_drag_u = -Cd_u * abs(u) * u;
  F_drag_v = -Cd_v * abs(v) * v;
  F_drag_w = -Cd_w * abs(w) * w;
  M_drag_r = -Cd_r * abs(r) * r;

  // ==================== Compliant Ring Contact (Axial) ====================
  penetration = max(0.0, nose_x - x_dock);
  F_contact_axial = if (penetration > 0.0) then -(k_contact * penetration + d_contact * x_dot) else 0.0;
  F_contact_mag = abs(F_contact_axial);

  // Contact force in body frame
  F_contact_u = F_contact_axial * cos(psi);
  F_contact_v = -F_contact_axial * sin(psi);
  M_contact_r = (L_hull / 2.0) * F_contact_v;

  // ==================== Funnel Lateral Guidance ====================
  funnel_active = nose_x > (x_dock - funnel_len);
  r_funnel_val = if funnel_active then
    max(r_funnel_out, r_funnel_in - (r_funnel_in - r_funnel_out) * (nose_x - (x_dock - funnel_len)) / funnel_len)
  else 10.0;

  y_pen = max(0.0, abs(y - y_dock) - r_funnel_val);
  z_pen = max(0.0, abs(z - z_dock) - r_funnel_val);

  F_funnel_y = if (funnel_active and (y - y_dock) > r_funnel_val) then
    -k_funnel * ((y - y_dock) - r_funnel_val) - d_funnel * y_dot
  else if (funnel_active and (y - y_dock) < -r_funnel_val) then
    -k_funnel * ((y - y_dock) + r_funnel_val) - d_funnel * y_dot
  else 0.0;

  F_funnel_z = if (funnel_active and (z - z_dock) > r_funnel_val) then
    -k_funnel * ((z - z_dock) - r_funnel_val) - d_funnel * z_dot
  else if (funnel_active and (z - z_dock) < -r_funnel_val) then
    -k_funnel * ((z - z_dock) + r_funnel_val) - d_funnel * z_dot
  else 0.0;

  F_funnel_mag = sqrt(F_funnel_y ^ 2 + F_funnel_z ^ 2);

  // Funnel force in body frame
  F_funnel_u = F_funnel_y * sin(psi);
  F_funnel_v = F_funnel_y * cos(psi);
  F_funnel_w = F_funnel_z;
  M_funnel_r = (L_hull / 2.0) * F_funnel_v;

  // ==================== Speed-Scheduled Pose Controller ====================
  // Surge speed: full cruise beyond 1 m, linear reduction inside 1 m, zero at contact
  v_cmd = if (nose_dist > 1.0) then v_cruise
    else if (nose_dist > 0.0) then v_cruise * nose_dist
    else 0.0;

  // Lateral alignment via yaw steering command
  psi_cmd = max(-psi_max, min(psi_max, -K_y * (y - y_dock)));

  // Surge velocity controller (proportional)
  F_surge_total_cmd = Kp_u * (v_cmd - u);

  // Yaw controller (proportional-derivative)
  M_yaw_cmd = Kp_psi * (psi_cmd - psi) - Kd_psi * r;

  // Heave controller (PD with buoyancy feedforward)
  F_heave_cmd = Kp_z * (z_dock - z) - Kd_z * w - F_net_buoy;

  // ==================== Thruster Allocation ====================
  F_surge_port_cmd = F_surge_total_cmd / 2.0 - M_yaw_cmd / (2.0 * arm_th);
  F_surge_stbd_cmd = F_surge_total_cmd / 2.0 + M_yaw_cmd / (2.0 * arm_th);
  F_heave_fwd_cmd = F_heave_cmd / 2.0;
  F_heave_aft_cmd = F_heave_cmd / 2.0;

  // ==================== Thruster Saturation ====================
  F_surge_port = max(-F_max, min(F_max, F_surge_port_cmd));
  F_surge_stbd = max(-F_max, min(F_max, F_surge_stbd_cmd));
  F_heave_fwd = max(-F_max, min(F_max, F_heave_fwd_cmd));
  F_heave_aft = max(-F_max, min(F_max, F_heave_aft_cmd));

  F_surge_total = F_surge_port + F_surge_stbd;
  F_heave_total = F_heave_fwd + F_heave_aft;

  // ==================== Rigid-Body Dynamics ====================
  der(u) = (F_surge_total + F_current_u + F_drag_u + F_contact_u + F_funnel_u) / m_hull;
  der(v) = (F_current_v + F_drag_v + F_contact_v + F_funnel_v) / m_hull;
  der(w) = (F_heave_total + F_net_buoy + F_drag_w + F_funnel_w) / m_hull;
  der(r) = ((F_surge_stbd - F_surge_port) * arm_th + M_drag_r + M_funnel_r + M_contact_r) / I_z;

  // ==================== Instrumentation Models ====================
  sonar_range = max(0.0, nose_dist);
  pressure_depth = z;
  imu_u = u;
  imu_v = v;
  imu_w = w;
  imu_r = r;
  optical_valid = (nose_dist < 1.0) and (nose_dist > -0.2);
  optical_x = if optical_valid then (x_dock - x) else 0.0;
  optical_y = if optical_valid then (y_dock - y) else 0.0;
  optical_psi = if optical_valid then (0.0 - psi) else 0.0;

  // ==================== Performance Metrics ====================
  speed = sqrt(u ^ 2 + v ^ 2 + w ^ 2);
  track_error = sqrt((x - (x_dock - L_hull / 2.0)) ^ 2 + (y - y_dock) ^ 2 + (z - z_dock) ^ 2);

  speed_bounded = speed <= speed_limit + 0.01;
  actuator_bounded = (abs(F_surge_port) <= F_max + 0.001) and
                    (abs(F_surge_stbd) <= F_max + 0.001) and
                    (abs(F_heave_fwd) <= F_max + 0.001) and
                    (abs(F_heave_aft) <= F_max + 0.001);
  contact_safe = (F_contact_mag < 500.0) and (F_funnel_mag < 500.0);
  aligned = (abs(y - y_dock) < r_capture) and (abs(psi) < psi_capture);
  captured = (penetration > 0.001) and (abs(y - y_dock) < r_capture) and
             (abs(z - z_dock) < r_capture) and (abs(psi) < psi_capture);
  no_nan_inf = (abs(x) < 1e8) and (abs(y) < 1e8) and (abs(z) < 1e8) and
               (abs(u) < 1e8) and (abs(v) < 1e8) and (abs(w) < 1e8) and
               (abs(psi) < 1e8) and (abs(r) < 1e8) and
               (abs(F_surge_port) < 1e8) and (abs(F_surge_stbd) < 1e8) and
               (abs(F_heave_fwd) < 1e8) and (abs(F_heave_aft) < 1e8);

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "AUVDockC: Free-base marine robot with speed-scheduled pose control and contact transition. 85 kg capsule hull (1.5 m, 0.083 m3) in seawater. Approaches fixed docking funnel from 8 m. Speed reduces inside 1 m. Four bidirectional thrusters (2 surge, 2 heave) with 101 N per-thruster limit. 126 N cross-current during middle third (4-8 s). Compliant capture ring and funnel guidance. Sonar, pressure, IMU, and optical pose sensors. Runs at 125 Hz for 12 s."));
end AUVDockC;