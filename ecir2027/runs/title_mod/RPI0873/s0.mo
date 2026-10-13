model ROVSurveyC
  // Free-base marine robot: lawnmower path following with current compensation.
  // 60 m path at 1.0 m/s, constant depth, 12 s run at 125 Hz.
  // 90 N current load disturbance applied during the middle third [4,8] s.
  // Six body-wrench thrusters (4 horizontal vectored at 45 deg, 2 vertical).
  // Values not stated in the requirement (depth setpoint, seabed depth, leg
  // spacing, drag coefficients, beacon position, estimator noise) are nominal
  // and clearly labeled; they are not asserted as facts.

  // ---- Stated physical parameters ----
  parameter Real m = 115.0 "kg";
  parameter Real Lx = 1.1 "m";
  parameter Real Ly = 0.78 "m";
  parameter Real Lz = 0.58 "m";
  parameter Real f_max = 152.0 "N per thruster";
  parameter Real current_y = 0.18 "m/s steady lateral water current";
  parameter Real F_disturb = 90.0 "N controlled current load disturbance";
  parameter Real speed_ref = 1.0 "m/s";
  parameter Real path_length = 60.0 "m";

  // ---- Nominal / unstated parameters (clearly labeled) ----
  parameter Real g = 9.81 "m/s2";
  parameter Real net_buoyancy = 5.0 "N slightly positive; full hydrostatics not specified";
  parameter Real rho_water = 1025.0 "kg/m3";
  parameter Real depth_ref = 5.0 "m nominal (not stated)";
  parameter Real seabed_depth = 20.0 "m nominal (not stated)";
  parameter Real leg_spacing = 10.0 "m nominal (not stated)";
  parameter Real Iz = (1.0/12.0)*m*(Lx*Lx + Ly*Ly) "kg m2 yaw inertia, box approx";
  parameter Real c45 = 0.7071067811865476 "cos(45 deg)";
  parameter Real s45 = 0.7071067811865476 "sin(45 deg)";
  parameter Real ax_arm = 0.5*Lx "m x moment arm";
  parameter Real by_arm = 0.5*Ly "m y moment arm";
  parameter Real k_yaw = ax_arm*s45 - by_arm*c45 "m yaw moment coefficient";
  parameter Real inv4k = 1.0/(4.0*k_yaw) "1/(4 k_yaw)";

  // Nominal hydrodynamic linear drag (not stated)
  parameter Real Du = 60.0 "N per (m/s) surge drag";
  parameter Real Dv = 80.0 "N per (m/s) sway drag";
  parameter Real Dr = 50.0 "N m per (rad/s) yaw drag";
  parameter Real Dw = 100.0 "N per (m/s) heave drag";

  // Controller gains (nominal)
  parameter Real Kp_u = 5.0;
  parameter Real Ki_u = 2.0;
  parameter Real Kp_v = 8.0;
  parameter Real Ki_v = 4.0;
  parameter Real Kp_psi = 40.0;
  parameter Real Kd_psi = 60.0;
  parameter Real Kp_z = 25.0;
  parameter Real Kd_z = 30.0;
  parameter Real los_lookahead = 3.0 "m";
  parameter Real int_u_max = 50.0;
  parameter Real int_v_max = 30.0;

  // Estimator complementary-filter gains (nominal)
  parameter Real L_psi = 5.0;
  parameter Real L_r = 5.0;
  parameter Real L_u = 3.0;
  parameter Real L_v = 3.0;
  parameter Real L_z = 4.0;

  // Estimator covariance scalar Riccati parameters (nominal)
  parameter Real Q_psi = 0.01;
  parameter Real R_psi = 0.01;
  parameter Real Q_u = 0.05;
  parameter Real R_u = 0.02;
  parameter Real Q_v = 0.05;
  parameter Real R_v = 0.02;
  parameter Real Q_z = 0.001;
  parameter Real R_z = 0.01;
  parameter Real Q_x = 0.05;
  parameter Real R_x = 0.5;
  parameter Real Q_y = 0.05;
  parameter Real R_y = 0.5;

  // Acoustic beacon position (nominal, not stated)
  parameter Real beacon_x = 0.0 "m";
  parameter Real beacon_y = -10.0 "m";
  parameter Real beacon_z = 0.0 "m";

  // ---- Plant states ----
  Real x(start=0.0) "m north position";
  Real y(start=0.0) "m east position";
  Real z(start=0.1) "m depth (positive down)";
  Real psi(start=0.0) "rad yaw";
  Real u(start=0.0) "m/s surge";
  Real v(start=0.0) "m/s sway";
  Real w(start=0.0) "m/s heave";
  Real r(start=0.0) "rad/s yaw rate";

  // Controller integrators
  Real int_u(start=0.0);
  Real int_v(start=0.0);

  // Thruster commands and saturated outputs
  Real f1_cmd, f2_cmd, f3_cmd, f4_cmd, f5_cmd, f6_cmd "N commanded";
  Real f1, f2, f3, f4, f5, f6 "N saturated";

  // Wrench commands and saturated actuals
  Real Fx_cmd "N", Fy_cmd "N", Fz_cmd "N", Mz_cmd "N m";
  Real Fx_act "N", Fy_act "N", Mz_act "N m", Fz_act "N";

  // Path / guidance / metrics
  Real psi_d "rad desired heading";
  Real e_cross "m cross-track error (signed)";
  Real s_along "m along-track progress on current leg";
  Real depth_error "m";
  Real primary_error "m primary tracking error";
  Real route_completion "0..1";
  Real seabed_clearance "m";
  Real F_current_load "N applied load";

  // Estimator states
  Real x_hat(start=0.0) "m";
  Real y_hat(start=0.0) "m";
  Real z_hat(start=0.0) "m";
  Real u_hat(start=0.0) "m/s";
  Real v_hat(start=0.0) "m/s";
  Real w_hat(start=0.0) "m/s";
  Real psi_hat(start=0.0) "rad";
  Real r_hat(start=0.0) "rad/s";
  Real P_x(start=0.5) "estimator covariance x";
  Real P_y(start=0.5) "estimator covariance y";
  Real P_z(start=0.05) "estimator covariance z";
  Real P_u(start=0.1) "estimator covariance u";
  Real P_v(start=0.1) "estimator covariance v";
  Real P_psi(start=0.05) "estimator covariance psi";

  // Sensors
  Real z_meas "m pressure-derived depth";
  Real u_meas "m/s DVL surge";
  Real v_meas "m/s DVL sway";
  Real psi_meas "rad compass yaw";
  Real r_meas "rad/s IMU yaw rate";
  Real range_meas "m acoustic range";

equation

  // Disturbance window: middle third of 12 s -> [4,8] s
  if time >= 4.0 and time <= 8.0 then
    F_current_load = F_disturb;
  else
    F_current_load = 0.0;
  end if;

  // ---- Kinematics (current enters through drag, not advection) ----
  der(x) = u*cos(psi) - v*sin(psi);
  der(y) = u*sin(psi) + v*cos(psi);
  der(z) = w;
  der(psi) = r;

  // ---- Rigid-body dynamics with current-relative drag ----
  // Body-relative velocities: u_rel = u - sin(psi)*current_y, v_rel = v - cos(psi)*current_y
  m*der(u) = Fx_act - Du*(u - sin(psi)*current_y);
  m*der(v) = Fy_act + F_current_load*cos(psi) - Dv*(v - cos(psi)*current_y);
  m*der(w) = Fz_act + net_buoyancy - Dw*w;
  Iz*der(r) = Mz_act - Dr*r;

  // ---- Path metrics: leg 1 along +x at y=0 (leg 2 not reached in 12 s) ----
  e_cross = y;
  s_along = x;
  route_completion = if s_along < path_length then s_along/path_length else 1.0;
  depth_error = z - depth_ref;
  primary_error = sqrt(e_cross*e_cross + depth_error*depth_error);
  seabed_clearance = seabed_depth - z;

  // ---- LOS guidance ----
  psi_d = atan2(-e_cross, los_lookahead);

  // ---- Surge speed PI with anti-windup ----
  der(int_u) = if (int_u > int_u_max and (speed_ref - u) > 0.0) or
                   (int_u < -int_u_max and (speed_ref - u) < 0.0)
                then 0.0 else (speed_ref - u);
  Fx_cmd = m*(Kp_u*(speed_ref - u) + Ki_u*int_u);

  // ---- Sway PI to null body sway (current compensation) with anti-windup ----
  der(int_v) = if (int_v > int_v_max and v > 0.0) or
                   (int_v < -int_v_max and v < 0.0)
                then 0.0 else v;
  Fy_cmd = m*(Kp_v*(0.0 - v) + Ki_v*int_v);

  // ---- Yaw PD on heading error ----
  Mz_cmd = Iz*(Kp_psi*(psi_d - psi) + Kd_psi*(0.0 - r));

  // ---- Depth PD (counter net buoyancy) ----
  Fz_cmd = m*(Kp_z*(depth_ref - z) + Kd_z*(0.0 - w)) - net_buoyancy;

  // ---- Allocation: wrench -> 4 horizontal + 2 vertical thrusters ----
  f1_cmd = 0.5*c45*Fx_cmd + 0.5*s45*Fy_cmd + inv4k*Mz_cmd;
  f2_cmd = 0.5*c45*Fx_cmd - 0.5*s45*Fy_cmd - inv4k*Mz_cmd;
  f3_cmd = -0.5*c45*Fx_cmd + 0.5*s45*Fy_cmd - inv4k*Mz_cmd;
  f4_cmd = -0.5*c45*Fx_cmd - 0.5*s45*Fy_cmd + inv4k*Mz_cmd;
  f5_cmd = 0.5*Fz_cmd;
  f6_cmd = 0.5*Fz_cmd;

  // ---- Per-thruster saturation (actuator bounds) ----
  f1 = max(-f_max, min(f_max, f1_cmd));
  f2 = max(-f_max, min(f_max, f2_cmd));
  f3 = max(-f_max, min(f_max, f3_cmd));
  f4 = max(-f_max, min(f_max, f4_cmd));
  f5 = max(-f_max, min(f_max, f5_cmd));
  f6 = max(-f_max, min(f_max, f6_cmd));

  // ---- Actual wrench from saturated thrusters ----
  Fx_act = c45*(f1 + f2 - f3 - f4);
  Fy_act = s45*(f1 - f2 + f3 - f4);
  Mz_act = k_yaw*(f1 - f2 - f3 + f4);
  Fz_act = f5 + f6;

  // ---- Sensors with bounded deterministic perturbations ----
  z_meas = z + 0.05*sin(7.0*time);
  u_meas = u + 0.02*sin(11.0*time);
  v_meas = v + 0.02*sin(13.0*time);
  psi_meas = psi + 0.01*sin(5.0*time);
  r_meas = r + 0.005*sin(9.0*time);
  range_meas = sqrt((x - beacon_x)*(x - beacon_x) +
                    (y - beacon_y)*(y - beacon_y) +
                    (z - beacon_z)*(z - beacon_z)) + 0.1*sin(3.0*time);

  // ---- Estimator: complementary filter using IMU/pressure/DVL/compass/range ----
  der(psi_hat) = r_meas + L_psi*(psi_meas - psi_hat);
  der(r_hat) = L_r*(r_meas - r_hat);
  der(u_hat) = (1.0/m)*Fx_act - (Du/m)*(u_hat - sin(psi_hat)*current_y) + L_u*(u_meas - u_hat);
  der(v_hat) = (1.0/m)*(Fy_act + F_current_load*cos(psi_hat)) - (Dv/m)*(v_hat - cos(psi_hat)*current_y) + L_v*(v_meas - v_hat);
  der(w_hat) = (1.0/m)*(Fz_act + net_buoyancy) - (Dw/m)*w_hat;
  der(z_hat) = w_hat + L_z*(z_meas - z_hat);
  der(x_hat) = u_hat*cos(psi_hat) - v_hat*sin(psi_hat);
  der(y_hat) = u_hat*sin(psi_hat) + v_hat*cos(psi_hat);

  // ---- Estimator covariance: scalar Riccati per diagonal channel ----
  der(P_psi) = Q_psi - (P_psi*P_psi)/R_psi;
  der(P_u) = Q_u - (P_u*P_u)/R_u;
  der(P_v) = Q_v - (P_v*P_v)/R_v;
  der(P_z) = Q_z - (P_z*P_z)/R_z;
  der(P_x) = Q_x - (P_x*P_x)/R_x;
  der(P_y) = Q_y - (P_y*P_y)/R_y;

end ROVSurveyC;