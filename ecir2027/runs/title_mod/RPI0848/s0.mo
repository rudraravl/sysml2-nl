model AUVSurveyB
  // Physical parameters
  parameter Real m = 85.0 "Mass [kg]";
  parameter Real Iz = 15.9 "Yaw inertia [kg.m2]";
  parameter Real du = 20.0 "Surge linear drag [N.s/m]";
  parameter Real dv = 120.0 "Sway linear drag [N.s/m]";
  parameter Real dr = 10.0 "Yaw linear drag [N.s/rad]";
  parameter Real dw = 20.0 "Heave linear drag [N.s/m]";
  parameter Real thr_max = 90.2 "Max thruster force [N]";
  parameter Real thr_arm = 0.3 "Thruster moment arm [m]";

  // State variables
  Real x "Inertial X position [m]";
  Real y "Inertial Y position [m]";
  Real z "Depth [m]";
  Real u "Surge velocity [m/s]";
  Real v "Sway velocity [m/s]";
  Real w "Heave velocity [m/s]";
  Real psi "Heading [rad]";
  Real r "Yaw rate [rad/s]";

  // Actuator commands and forces
  Real F1 "Surge port thruster [N]";
  Real F2 "Surge stbd thruster [N]";
  Real F3 "Heave port thruster [N]";
  Real F4 "Heave stbd thruster [N]";
  Real Fx "Total surge force [N]";
  Real Mz "Total yaw moment [N.m]";
  Real Fz "Total heave force [N]";
  Real Fx_cmd "Surge force command [N]";
  Real Mz_cmd "Yaw moment command [N.m]";
  Real Fz_cmd "Heave force command [N]";

  // Control references
  Real u_des "Desired surge speed [m/s]";
  Real psi_des "Desired heading [rad]";

  // Environment
  Real F_ext_y "External lateral disturbance [N]";

  // Sensor measurements
  Real ax_meas "IMU surge acceleration [m/s2]";
  Real ay_meas "IMU sway acceleration [m/s2]";
  Real r_meas "IMU yaw rate [rad/s]";
  Real z_meas "Pressure depth [m]";
  Real u_meas "DVL surge velocity [m/s]";
  Real v_meas "DVL sway velocity [m/s]";
  Real psi_meas "Compass heading [rad]";
  Real range_meas "Acoustic range to seabed [m]";

  // Estimator states
  Real x_hat "Estimated X [m]";
  Real y_hat "Estimated Y [m]";
  Real z_hat "Estimated depth [m]";
  Real u_hat "Estimated surge [m/s]";
  Real v_hat "Estimated sway [m/s]";
  Real w_hat "Estimated heave [m/s]";
  Real psi_hat "Estimated heading [rad]";

  // Estimator covariance (diagonal simplified)
  Real P_x "Covariance of X [m2]";
  Real P_y "Covariance of Y [m2]";
  Real P_z "Covariance of Z [m2]";
  Real P_psi "Covariance of heading [rad2]";

  // Mission metrics
  Real cross_track_err "Cross-track error [m]";
  Real depth_err "Depth error [m]";
  Real route_completion "Fraction of 60m path completed [0-1]";
  Real primary_track_err "Primary tracking error [m]";

initial equation
  x = 0.0;
  y = 0.0;
  z = 5.0;
  u = 1.0;
  v = 0.0;
  w = 0.0;
  psi = 0.181; // Crab angle to cancel 0.18 m/s current
  r = 0.0;

  x_hat = 0.0;
  y_hat = 0.0;
  z_hat = 5.0;
  u_hat = 1.0;
  v_hat = 0.0;
  w_hat = 0.0;
  psi_hat = 0.181;

equation
  // Disturbance injection during middle third (3.33s to 6.67s)
  F_ext_y = if (time > 10.0/3.0 and time < 20.0/3.0) then 70.0 else 0.0;

  // Vehicle dynamics (6-DOF simplified)
  der(u) = (Fx - du * u) / m;
  der(v) = (F_ext_y - dv * v) / m;
  der(w) = (Fz - dw * w) / m;
  der(r) = (Mz - dr * r) / Iz;
  der(psi) = r;
  der(x) = u * cos(psi) - v * sin(psi);
  der(y) = u * sin(psi) + v * cos(psi) - 0.18; // 0.18 m/s lateral current
  der(z) = w;

  // Actuator allocation and bounds
  Fx = F1 + F2;
  Mz = (F2 - F1) * thr_arm;
  Fz = F3 + F4;

  F1 = max(-thr_max, min(thr_max, Fx_cmd / 2.0 + Mz_cmd / (2.0 * thr_arm)));
  F2 = max(-thr_max, min(thr_max, Fx_cmd / 2.0 - Mz_cmd / (2.0 * thr_arm)));
  F3 = max(-thr_max, min(thr_max, Fz_cmd / 2.0));
  F4 = max(-thr_max, min(thr_max, Fz_cmd / 2.0));

  // Path-following control with current compensation
  u_des = 1.0;
  Fx_cmd = 50.0 * (u_des - u_hat) - 10.0 * u_hat;
  Fz_cmd = 20.0 * (5.0 - z_hat) - 10.0 * w_hat;
  psi_des = 0.18 - 3.0 * y_hat; // Current feedforward + cross-track P-control
  Mz_cmd = 10.0 * (psi_des - psi_hat) - 5.0 * r_meas;

  // Sensor models
  ax_meas = (Fx - du * u) / m;
  ay_meas = (F_ext_y - dv * v) / m;
  r_meas = r;
  z_meas = z;
  u_meas = u;
  v_meas = v;
  psi_meas = psi;
  range_meas = 20.0 - z; // Seabed at 20m

  // Sensor fusion observer (Complementary filter)
  der(u_hat) = ax_meas + 2.0 * (u_meas - u_hat);
  der(v_hat) = ay_meas + 2.0 * (v_meas - v_hat);
  der(w_hat) = (Fz / m) + 2.0 * (z_meas - z_hat);
  der(psi_hat) = r_meas + 2.0 * (psi_meas - psi_hat);
  der(z_hat) = w_hat;
  der(x_hat) = u_hat * cos(psi_hat) - v_hat * sin(psi_hat);
  der(y_hat) = u_hat * sin(psi_hat) + v_hat * cos(psi_hat) - 0.18;

  // Estimator covariance outputs
  P_x = 0.1;
  P_y = 0.1;
  P_z = 0.05;
  P_psi = 0.01;

  // Mission metrics
  cross_track_err = abs(y);
  depth_err = abs(z - 5.0);
  route_completion = max(0.0, min(1.0, x / 60.0));
  primary_track_err = abs(y);

end AUVSurveyB;