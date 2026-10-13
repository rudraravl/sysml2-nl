model AUVHoldA
  "AUVHoldA: Free-base 85 kg AUV holding 6-DOF pose beside offshore cylinder"
  
  // ===== Hull and environment parameters =====
  parameter Real m = 85.0 "hull mass [kg]";
  parameter Real L_hull = 1.5 "hull length [m]";
  parameter Real Vdisp = 0.083 "displaced volume in seawater [m3]";
  parameter Real rho_sw = 1025.0 "seawater density [kg/m3]";
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";
  parameter Real W = m * g_acc "hull weight [N]";
  parameter Real Bf = rho_sw * g_acc * Vdisp "buoyancy force [N]";
  
  // ===== Thruster parameters =====
  parameter Real F_thr_max = 79.2 "per-thruster command magnitude limit [N]";
  parameter Real d_yaw_arm = 0.30 "surge thruster pair yaw moment arm [m]";
  parameter Real d_roll_arm = 0.30 "heave thruster pair roll moment arm [m]";
  
  // ===== Inertia and hydrodynamic damping =====
  parameter Real Ixx = 5.0 "roll inertia [kg.m2]";
  parameter Real Iyy = 20.0 "pitch inertia [kg.m2]";
  parameter Real Izz = 5.0 "yaw inertia [kg.m2]";
  parameter Real Xu = 20.0 "surge linear damping [N/(m/s)]";
  parameter Real Yv = 20.0 "sway linear damping [N/(m/s)]";
  parameter Real Zw = 20.0 "heave linear damping [N/(m/s)]";
  parameter Real Kpd = 2.0 "roll angular damping [N.m/(rad/s)]";
  parameter Real Mqd = 5.0 "pitch angular damping [N.m/(rad/s)]";
  parameter Real Nrd = 2.0 "yaw angular damping [N.m/(rad/s)]";
  parameter Real GM_rest = 0.05 "metacentric restoring height [m]";
  
  // ===== Disturbance / tether =====
  parameter Real F_dist = 60.0 "applied tether/current load [N]";
  parameter Real t_dist_start = 8.0 / 3.0 "disturbance start (middle third) [s]";
  parameter Real t_dist_end = 16.0 / 3.0 "disturbance end (middle third) [s]";
  parameter Real tether_limit = 80.0 "tether load limit [N]";
  
  // ===== Offshore structure (fixed collidable cylinder) =====
  parameter Real cyl_x = 8.0 "cylinder center x [m]";
  parameter Real cyl_y = 0.0 "cylinder center y [m]";
  parameter Real cyl_r = 1.0 "cylinder radius [m]";
  
  // ===== Setpoint pose =====
  parameter Real x_sp = 4.0 "setpoint x [m]";
  parameter Real y_sp = 0.0 "setpoint y [m]";
  parameter Real z_sp = -2.0 "setpoint depth [m]";
  parameter Real phi_sp = 0.0 "setpoint roll [rad]";
  parameter Real theta_sp = 0.0 "setpoint pitch [rad]";
  parameter Real psi_sp = 0.0 "setpoint yaw [rad]";
  
  // ===== Controller gains =====
  parameter Real Kp_sur = 70.0 "surge P gain [N/m]";
  parameter Real Kd_sur = 45.0 "surge D gain [N/(m/s)]";
  parameter Real Ki_sur = 30.0 "surge I gain [N/s]";
  parameter Real leak_u = 0.05 "surge integrator leak rate [1/s]";
  parameter Real Kp_hev = 70.0 "heave P gain [N/m]";
  parameter Real Kd_hev = 45.0 "heave D gain [N/(m/s)]";
  parameter Real Ki_hev = 30.0 "heave I gain [N/s]";
  parameter Real leak_w = 0.05 "heave integrator leak rate [1/s]";
  parameter Real Kp_yaw = 15.0 "yaw P gain [N.m/rad]";
  parameter Real Kd_yaw = 5.0 "yaw D gain [N.m/(rad/s)]";
  parameter Real K_yaw_couple = 1.5 "yaw-to-sway coupling gain [rad/m]";
  parameter Real Kp_roll = 12.0 "roll P gain [N.m/rad]";
  parameter Real Kd_roll = 3.0 "roll D gain [N.m/(rad/s)]";
  
  // ===== Initial conditions =====
  parameter Real x0 = 4.0 "initial x [m]";
  parameter Real y0 = 0.10 "initial y [m]";
  parameter Real z0 = -1.90 "initial z [m]";
  
  // ===== Sampling / scenario =====
  parameter Real Ts = 1.0 / 80.0 "sample period [s]";
  parameter Real T_end = 8.0 "scenario duration [s]";
  
  // ===== State variables =====
  Real x(start = x0, fixed = true) "north position [m]";
  Real y(start = y0, fixed = true) "east position [m]";
  Real z(start = z0, fixed = true) "depth [m]";
  Real phi(start = 0.0, fixed = true) "roll angle [rad]";
  Real theta(start = 0.0, fixed = true) "pitch angle [rad]";
  Real psi(start = 0.0, fixed = true) "yaw angle [rad]";
  Real u(start = 0.0, fixed = true) "surge velocity [m/s]";
  Real v(start = 0.0, fixed = true) "sway velocity [m/s]";
  Real w(start = 0.0, fixed = true) "heave velocity [m/s]";
  Real p_ang(start = 0.0, fixed = true) "roll rate [rad/s]";
  Real q_ang(start = 0.0, fixed = true) "pitch rate [rad/s]";
  Real r_ang(start = 0.0, fixed = true) "yaw rate [rad/s]";
  Real xi_u(start = 0.0, fixed = true) "surge leaky integrator state [m]";
  Real xi_w(start = 0.0, fixed = true) "heave leaky integrator state [m]";
  
  // ===== Thruster forces (bounded) =====
  Real T_surge1 "surge thruster 1 force [N]";
  Real T_surge2 "surge thruster 2 force [N]";
  Real T_heave1 "heave thruster 1 force [N]";
  Real T_heave2 "heave thruster 2 force [N]";
  
  // ===== Commanded wrench =====
  Real Fx_cmd "commanded surge force [N]";
  Real Fz_cmd "commanded heave force [N]";
  Real M_roll_cmd "commanded roll moment [N.m]";
  Real M_yaw_cmd "commanded yaw moment [N.m]";
  
  // ===== Errors =====
  Real err_x "x position error [m]";
  Real err_y "y position error [m]";
  Real err_z "z position error [m]";
  Real err_phi "roll error [rad]";
  Real err_theta "pitch error [rad]";
  Real err_psi "yaw error [rad]";
  Real body_x_err "body-frame surge position error [m]";
  Real pos_err "3D position tracking error [m]";
  Real att_err "attitude error norm [rad]";
  
  // ===== Disturbance / tether =====
  Real F_dist_x "disturbance force in x [N]";
  Real F_tether "tether load magnitude [N]";
  
  // ===== Sensor outputs =====
  Real p_depth "pressure-derived depth [m]";
  Real imu_phi "IMU roll [rad]";
  Real imu_theta "IMU pitch [rad]";
  Real imu_psi "IMU yaw [rad]";
  Real dvl_u "DVL surge velocity [m/s]";
  Real dvl_v "DVL sway velocity [m/s]";
  Real dvl_w "DVL heave velocity [m/s]";
  Real sonar_range "forward sonar range to structure [m]";
  
  // ===== Requirement monitors =====
  Real clearance "cylinder clearance [m]";
  Boolean req_tracking "pos_err < 0.405 m after 5.2 s";
  Boolean req_clearance_ok "clearance positive";
  Boolean req_thruster_ok "thruster within bounds";
  Boolean req_tether_ok "tether within limit";
  Boolean req_no_nan "no NaN/Inf detected";
  Real nan_check "finite-value check sum";
  
equation
  // ===== Disturbance: 60 N in +x during middle third of 8 s scenario =====
  F_dist_x = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;
  F_tether = abs(F_dist_x);
  
  // ===== Position and attitude errors =====
  err_x = x_sp - x;
  err_y = y_sp - y;
  err_z = z_sp - z;
  err_phi = phi_sp - phi;
  err_theta = theta_sp - theta;
  err_psi = atan2(sin(psi_sp - psi), cos(psi_sp - psi));
  body_x_err = err_x * cos(psi) + err_y * sin(psi);
  pos_err = sqrt(err_x * err_x + err_y * err_y + err_z * err_z + 1e-12);
  att_err = sqrt(err_phi * err_phi + err_theta * err_theta + err_psi * err_psi + 1e-12);
  
  // ===== Leaky integrators with anti-windup (freeze integration when saturated) =====
  der(xi_u) = if (abs(T_surge1) < F_thr_max - 0.5 and abs(T_surge2) < F_thr_max - 0.5)
              then (body_x_err - leak_u * xi_u) else (-leak_u * xi_u);
  der(xi_w) = if (abs(T_heave1) < F_thr_max - 0.5 and abs(T_heave2) < F_thr_max - 0.5)
              then (err_z - leak_w * xi_w) else (-leak_w * xi_w);
  
  // ===== Bounded body-wrench station-keeping controller =====
  // Surge (body x): PD + leaky integral
  Fx_cmd = Kp_sur * body_x_err - Kd_sur * u + Ki_sur * xi_u;
  // Heave (body z): PD + leaky integral; weight-buoyancy handled in dynamics
  Fz_cmd = Kp_hev * err_z - Kd_hev * w + Ki_hev * xi_w;
  // Roll: PD on roll error
  M_roll_cmd = Kp_roll * err_phi - Kd_roll * p_ang;
  // Yaw: PD on heading with sway-coupling to correct underactuated y-error
  M_yaw_cmd = Kp_yaw * (err_psi + K_yaw_couple * err_y) - Kd_yaw * r_ang;
  
  // ===== Thruster allocation with per-thruster saturation =====
  // Fx = T_surge1 + T_surge2;  M_yaw = (T_surge1 - T_surge2) * d_yaw_arm
  T_surge1 = max(-F_thr_max, min(F_thr_max, (Fx_cmd + M_yaw_cmd / d_yaw_arm) / 2.0));
  T_surge2 = max(-F_thr_max, min(F_thr_max, (Fx_cmd - M_yaw_cmd / d_yaw_arm) / 2.0));
  // Fz = T_heave1 + T_heave2;  M_roll = (T_heave1 - T_heave2) * d_roll_arm
  T_heave1 = max(-F_thr_max, min(F_thr_max, (Fz_cmd + M_roll_cmd / d_roll_arm) / 2.0));
  T_heave2 = max(-F_thr_max, min(F_thr_max, (Fz_cmd - M_roll_cmd / d_roll_arm) / 2.0));
  
  // ===== 6-DOF dynamics (small-angle Newton-Euler, decoupled damping) =====
  // Translational
  m * der(u) = (T_surge1 + T_surge2) - Xu * u + F_dist_x;
  m * der(v) = -Yv * v;
  m * der(w) = (W - Bf) + (T_heave1 + T_heave2) - Zw * w;
  // Rotational (pitch uses passive metacentric restoring; sway is underactuated)
  Ixx * der(p_ang) = (T_heave1 - T_heave2) * d_roll_arm - Kpd * p_ang;
  Iyy * der(q_ang) = -Bf * GM_rest * sin(theta) - Mqd * q_ang;
  Izz * der(r_ang) = (T_surge1 - T_surge2) * d_yaw_arm - Nrd * r_ang;
  // Kinematics (small-angle Euler)
  der(x) = u * cos(psi) - v * sin(psi);
  der(y) = u * sin(psi) + v * cos(psi);
  der(z) = w;
  der(phi) = p_ang;
  der(theta) = q_ang;
  der(psi) = r_ang;
  
  // ===== Sensor models (direct measurement; noise not specified) =====
  p_depth = z;
  imu_phi = phi;
  imu_theta = theta;
  imu_psi = psi;
  dvl_u = u;
  dvl_v = v;
  dvl_w = w;
  sonar_range = max(0.1, sqrt((cyl_x - x) * (cyl_x - x) + (cyl_y - y) * (cyl_y - y) + 1e-12) - cyl_r);
  
  // ===== Requirement monitors =====
  clearance = sqrt((x - cyl_x) * (x - cyl_x) + (y - cyl_y) * (y - cyl_y) + 1e-12) - cyl_r;
  req_tracking = (time > 5.2) and (pos_err < 0.405);
  req_clearance_ok = clearance > 0.0;
  req_thruster_ok = (abs(T_surge1) <= F_thr_max + 1e-6) and (abs(T_surge2) <= F_thr_max + 1e-6)
                    and (abs(T_heave1) <= F_thr_max + 1e-6) and (abs(T_heave2) <= F_thr_max + 1e-6);
  req_tether_ok = F_tether <= tether_limit + 1e-6;
  nan_check = x + y + z + phi + theta + psi + u + v + w
              + T_surge1 + T_surge2 + T_heave1 + T_heave2 + pos_err + clearance;
  req_no_nan = abs(nan_check) < 1e20;
  
  annotation(
    experiment(StartTime = 0.0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "AUVHoldA: 85 kg AUV (1.5 m hull, 0.083 m3 displaced volume) with two surge and two heave bidirectional thrusters (79.2 N limit each) holding a fixed 6-DOF pose beside a fixed collidable cylinder structure. A 60 N tether/current disturbance is applied during the middle third (2.667 s to 5.333 s). Controller uses bounded body-wrench station keeping with leaky-integral surge/heave PD, roll PD, and yaw PD with sway coupling. Pitch uses passive metacentric restoring; sway is underactuated via yaw+surge coupling. Pressure, IMU, DVL, and forward sonar sensors are modeled. Requirements: primary tracking error < 0.405 m after 5.2 s, positive structure clearance, thruster and tether bounds, no NaN/Inf. Runs at 80 Hz for 8 s.")
  );
end AUVHoldA;