model AUVHoldB
  "Free-base AUV station keeping beside offshore cylinder structure"

  // ---- Physical constants ----
  constant Real g = 9.81;
  constant Real rho_sw = 1025.0;

  // ---- Vehicle parameters ----
  parameter Real m = 85.0 "Hull mass [kg]";
  parameter Real L_hull = 1.5 "Hull length [m]";
  parameter Real V_disp = 0.083 "Displaced volume in seawater [m3]";
  parameter Real F_max_thr = 90.2 "Max force per thruster [N]";
  parameter Real Ixx = 8.0 "Roll inertia [kg.m2]";
  parameter Real Iyy = 8.0 "Pitch inertia [kg.m2]";
  parameter Real Izz = 6.0 "Yaw inertia [kg.m2]";

  // ---- Added mass ----
  parameter Real Xua = 15.0 "Surge added mass [kg]";
  parameter Real Yva = 15.0 "Sway added mass [kg]";
  parameter Real Zwa = 15.0 "Heave added mass [kg]";
  parameter Real Kpa = 1.0 "Roll added inertia [kg.m2]";
  parameter Real Mqa = 1.0 "Pitch added inertia [kg.m2]";
  parameter Real Nra = 1.0 "Yaw added inertia [kg.m2]";

  // ---- Linear drag ----
  parameter Real Xdu = 40.0 "Surge linear drag [N.s/m]";
  parameter Real Ydv = 40.0 "Sway linear drag [N.s/m]";
  parameter Real Zdw = 40.0 "Heave linear drag [N.s/m]";
  parameter Real Kdp = 3.0 "Roll angular drag [N.m.s/rad]";
  parameter Real Mdq = 3.0 "Pitch angular drag [N.m.s/rad]";
  parameter Real Ndr = 3.0 "Yaw angular drag [N.m.s/rad]";

  // ---- Weight and buoyancy ----
  Real W = m * g "Vehicle weight [N]";
  Real B = rho_sw * V_disp * g "Buoyancy force [N]";

  // ---- Target pose (6-DOF) ----
  parameter Real x_t = 5.0 "Target x [m]";
  parameter Real y_t = 0.0 "Target y [m]";
  parameter Real z_t = -3.0 "Target depth [m]";
  parameter Real roll_t = 0.0 "Target roll [rad]";
  parameter Real pitch_t = 0.0 "Target pitch [rad]";
  parameter Real yaw_t = 0.0 "Target yaw [rad]";

  // ---- Translational states ----
  Real x(start = 4.5, fixed = true) "x position [m]";
  Real y(start = 0.5, fixed = true) "y position [m]";
  Real z(start = -2.5, fixed = true) "Depth [m]";
  Real u(start = 0.0, fixed = true) "Surge velocity [m/s]";
  Real v(start = 0.0, fixed = true) "Sway velocity [m/s]";
  Real w(start = 0.0, fixed = true) "Heave velocity [m/s]";
  Real ax "Surge acceleration [m/s2]";
  Real ay "Sway acceleration [m/s2]";
  Real az "Heave acceleration [m/s2]";

  // ---- Rotational states ----
  Real roll(start = 0.05, fixed = true) "Roll [rad]";
  Real pitch(start = -0.03, fixed = true) "Pitch [rad]";
  Real yaw(start = 0.02, fixed = true) "Yaw [rad]";
  Real p(start = 0.0, fixed = true) "Roll rate [rad/s]";
  Real q(start = 0.0, fixed = true) "Pitch rate [rad/s]";
  Real r(start = 0.0, fixed = true) "Yaw rate [rad/s]";

  // ---- Controller gains ----
  parameter Real Kp_xy = 300.0 "Proportional gain xy [N/m]";
  parameter Real Kd_xy = 120.0 "Derivative gain xy [N.s/m]";
  parameter Real Kp_z = 300.0 "Proportional gain z [N/m]";
  parameter Real Kd_z = 120.0 "Derivative gain z [N.s/m]";
  parameter Real Kp_att = 50.0 "Proportional gain attitude [N.m/rad]";
  parameter Real Kd_att = 15.0 "Derivative gain attitude [N.m.s/rad]";

  // ---- Wrench commands (raw and bounded) ----
  Real Fx_raw, Fy_raw, Fz_raw;
  Real Mroll_raw, Mpitch_raw, Myaw_raw;
  Real Fx_cmd, Fy_cmd, Fz_cmd;
  Real Mroll, Mpitch, Myaw;

  // ---- Thruster limits ----
  Real F_limit_surge = 2.0 * F_max_thr "Total surge force limit [N]";
  Real F_limit_heave = 2.0 * F_max_thr "Total heave force limit [N]";
  Real M_limit = 90.0 "Moment limit per axis [N.m]";

  // ---- Thruster forces (2 surge, 2 heave) ----
  Real F_surge1, F_surge2, F_heave1, F_heave2;

  // ---- Tether / current disturbance ----
  parameter Real F_tether = 84.0 "Tether/current load magnitude [N]";
  parameter Real t_dist_start = 10.0 / 3.0 "Disturbance start [s]";
  parameter Real t_dist_end = 20.0 / 3.0 "Disturbance end [s]";
  Real F_dist_x, F_dist_y, F_dist_z;

  // ---- Structure (fixed collidable cylinder) ----
  parameter Real R_struct = 1.0 "Structure radius [m]";
  parameter Real H_struct = 10.0 "Structure height [m]";
  parameter Real z_struct_center = -3.0 "Structure vertical center [m]";
  Real horiz_dist "Horizontal distance to structure center [m]";
  Real clearance "Clearance from structure surface [m]";
  Boolean collision "Collision flag";

  // ---- Sensors ----
  Real p_pressure "Pressure sensor reading [Pa]";
  Real imu_ax, imu_ay, imu_az "IMU accelerations [m/s2]";
  Real imu_p, imu_q, imu_r "IMU angular rates [rad/s]";
  Real dvl_u, dvl_v, dvl_w "DVL velocity [m/s]";
  Real sonar_range "Forward sonar range [m]";

  // ---- Error metrics ----
  Real pos_error "Euclidean position error [m]";
  Real att_error "Euclidean attitude error [rad]";
  Real tracking_error "Primary tracking error (= pos_error) [m]";
  Real tracking_error_after "Tracking error sampled after 6.5 s [m]";

equation
  // ============================
  // Translational dynamics (inertial frame, simplified)
  // ============================
  ax = (Fx_cmd + F_dist_x - Xdu * u) / (m + Xua);
  ay = (Fy_cmd + F_dist_y - Ydv * v) / (m + Yva);
  az = (Fz_cmd + F_dist_z - Zdw * w + (B - W)) / (m + Zwa);

  der(u) = ax;
  der(v) = ay;
  der(w) = az;
  der(x) = u;
  der(y) = v;
  der(z) = w;

  // ============================
  // Rotational dynamics (decoupled)
  // ============================
  der(p) = (Mroll - Kdp * p) / (Ixx + Kpa);
  der(q) = (Mpitch - Mdq * q) / (Iyy + Mqa);
  der(r) = (Myaw - Ndr * r) / (Izz + Nra);
  der(roll) = p;
  der(pitch) = q;
  der(yaw) = r;

  // ============================
  // Bounded body-wrench station-keeping controller (PD)
  // ============================
  Fx_raw = Kp_xy * (x_t - x) + Kd_xy * (0.0 - u);
  Fy_raw = Kp_xy * (y_t - y) + Kd_xy * (0.0 - v);
  Fz_raw = Kp_z * (z_t - z) + Kd_z * (0.0 - w);
  Mroll_raw = Kp_att * (roll_t - roll) + Kd_att * (0.0 - p);
  Mpitch_raw = Kp_att * (pitch_t - pitch) + Kd_att * (0.0 - q);
  Myaw_raw = Kp_att * (yaw_t - yaw) + Kd_att * (0.0 - r);

  // Saturation to thruster bounds
  Fx_cmd = max(-F_limit_surge, min(F_limit_surge, Fx_raw));
  Fy_cmd = max(-F_limit_surge, min(F_limit_surge, Fy_raw));
  Fz_cmd = max(-F_limit_heave, min(F_limit_heave, Fz_raw));
  Mroll = max(-M_limit, min(M_limit, Mroll_raw));
  Mpitch = max(-M_limit, min(M_limit, Mpitch_raw));
  Myaw = max(-M_limit, min(M_limit, Myaw_raw));

  // ============================
  // Thruster allocation (2 surge + 2 heave, equal split)
  // ============================
  F_surge1 = Fx_cmd / 2.0;
  F_surge2 = Fx_cmd / 2.0;
  F_heave1 = Fz_cmd / 2.0;
  F_heave2 = Fz_cmd / 2.0;

  // ============================
  // Disturbance injection (middle third of 10 s)
  // 84 N load split: 73 N x + 42 N y (cos30/sin30 decomposition)
  // ============================
  F_dist_x = if (time >= t_dist_start and time <= t_dist_end) then F_tether * 0.866 else 0.0;
  F_dist_y = if (time >= t_dist_start and time <= t_dist_end) then F_tether * 0.5 else 0.0;
  F_dist_z = 0.0;

  // ============================
  // Structure clearance (fixed cylinder at origin)
  // ============================
  horiz_dist = sqrt(x * x + y * y);
  clearance = horiz_dist - R_struct - L_hull / 2.0;
  collision = clearance < 0.0;

  // ============================
  // Sensors
  // ============================
  p_pressure = rho_sw * g * (-z) + 101325.0;
  imu_ax = ax;
  imu_ay = ay;
  imu_az = az;
  imu_p = p;
  imu_q = q;
  imu_r = r;
  dvl_u = u;
  dvl_v = v;
  dvl_w = w;
  sonar_range = max(0.1, horiz_dist - R_struct);

  // ============================
  // Error metrics
  // ============================
  pos_error = sqrt((x - x_t) ^ 2 + (y - y_t) ^ 2 + (z - z_t) ^ 2);
  att_error = sqrt((roll - roll_t) ^ 2 + (pitch - pitch_t) ^ 2 + (yaw - yaw_t) ^ 2);
  tracking_error = pos_error;

  // Sample tracking error after 6.5 s for requirement verification
  when time >= 6.5 then
    tracking_error_after = tracking_error;
  end when;
  when time < 6.5 then
    tracking_error_after = 0.0;
  end when;

  // ============================
  // Requirement assertions
  // ============================
  assert(not collision, "Structure clearance violation: AUV intersects cylinder");
  assert(tracking_error_after <= 0.36 or time < 6.5,
         "Primary tracking error exceeds 0.36 m after 6.5 s");
  assert(abs(F_surge1) <= F_max_thr + 0.01, "Surge thruster 1 bound exceeded");
  assert(abs(F_surge2) <= F_max_thr + 0.01, "Surge thruster 2 bound exceeded");
  assert(abs(F_heave1) <= F_max_thr + 0.01, "Heave thruster 1 bound exceeded");
  assert(abs(F_heave2) <= F_max_thr + 0.01, "Heave thruster 2 bound exceeded");

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "AUVHoldB: 6-DOF station keeping beside offshore cylinder.
      85 kg AUV, 1.5 m hull, 0.083 m3 displacement in seawater.
      4 thrusters (2 surge, 2 heave), 90.2 N max each.
      PD bounded body-wrench controller at 100 Hz for 10 s.
      84 N tether/current disturbance during middle third [3.33, 6.67] s.
      Sensors: pressure, IMU, DVL, forward sonar.
      Requirement: tracking error < 0.36 m after 6.5 s, maintain structure clearance."));

end AUVHoldB;