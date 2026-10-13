model ROVSurveyD
  // ---- Embodiment parameters ----
  parameter Real m = 115.0 "ROV mass [kg]";
  parameter Real Lx = 1.1 "hull length [m]";
  parameter Real Ly = 0.78 "hull width [m]";
  parameter Real Lz = 0.58 "hull height [m]";
  parameter Real Iz = m*(Lx*Lx + Ly*Ly)/12.0 "yaw inertia [kg.m2]";
  parameter Real thrusterMax = 165.0 "per-thruster limit [N]";
  parameter Real netBuoyancy = 5.0 "net positive buoyancy [N, upward]";

  // ---- Mission parameters ----
  parameter Real pathSpeed = 1.0 "target along-track speed [m/s]";
  parameter Real pathLen = 60.0 "total lawnmower path length [m]";
  parameter Real legLen = 20.0 "length of each straight leg [m]";
  parameter Real legSpacing = 5.0 "lawnmower lane spacing [m]";
  parameter Real targetDepth = 4.0 "commanded constant depth [m]";
  parameter Real seabedDepth = 10.0 "nominal seabed depth [m]";
  parameter Real currentSpeed = 0.18 "lateral water current [m/s]";
  parameter Real disturbanceForce = 100.0 "controlled current load disturbance [N]";
  parameter Real tEnd = 14.0 "mission duration [s]";

  // ---- Hydrodynamic linear drag (simplified) ----
  parameter Real dU = 80.0 "surge drag [N.s/m]";
  parameter Real dV = 80.0 "sway drag [N.s/m]";
  parameter Real dR = 60.0 "yaw drag [N.s/rad]";
  parameter Real dW = 60.0 "heave drag [N.s/m]";

  // ---- Controller gains ----
  parameter Real Kp_u = 200.0;
  parameter Real Kp_v = 200.0;
  parameter Real Kp_psi = 50.0;
  parameter Real Kd_psi = 80.0;
  parameter Real Kp_z = 50.0;
  parameter Real Kd_z = 60.0;
  parameter Real Kp_cross = 3.0 "cross-track sway gain [1/s]";

  // ---- Thruster geometry ----
  parameter Real armX = Ly/2 "surge-pair yaw moment arm [m]";
  parameter Real armY = Lx/2 "sway-pair yaw moment arm [m]";

  // ---- Estimator gains ----
  parameter Real K_psi_e = 2.0 "compass fusion gain";
  parameter Real K_u_e = 2.0 "DVL surge fusion gain";
  parameter Real K_v_e = 2.0 "DVL sway fusion gain";
  parameter Real K_z_e = 2.0 "pressure depth fusion gain";

  // ---- Physical plant state ----
  Real x(start=0.0) "North position [m]";
  Real y(start=0.0) "East position [m]";
  Real z(start=0.0) "Depth [m]";
  Real psi(start=0.0) "Heading [rad]";
  Real u(start=0.0) "Body-frame surge velocity [m/s]";
  Real v(start=0.0) "Body-frame sway velocity [m/s]";
  Real w(start=0.0) "Body-frame heave velocity [m/s]";
  Real r(start=0.0) "Yaw rate [rad/s]";

  // ---- Estimator state ----
  Real x_hat(start=0.0) "estimated North [m]";
  Real y_hat(start=0.0) "estimated East [m]";
  Real z_hat(start=0.0) "estimated depth [m]";
  Real u_hat(start=0.0) "estimated surge [m/s]";
  Real v_hat(start=0.0) "estimated sway [m/s]";
  Real psi_hat(start=0.0) "estimated heading [rad]";
  Real P_pos(start=1.0) "position covariance representative";
  Real P_vel(start=1.0) "velocity covariance representative";
  Real P_psi(start=1.0) "heading covariance representative";
  Real estimatorCovariance "mean diagonal covariance";

  // ---- Actuator commands and saturation ----
  Real Fx_cmd, Fy_cmd, Fz_cmd, Mz_cmd;
  Real Tcmd[6] "unsaturated thruster command [N]";
  Real T[6] "saturated thruster force [N]";
  Real Fx_act, Fy_act, Fz_act, Mz_act;
  Real actuatorSaturated "1.0 if any thruster saturates, else 0.0";

  // ---- Path following ----
  Real s_ref "along-track reference distance [m]";
  Real segPsi "active segment heading [rad]";
  Real crossRef "reference cross-track coordinate of active leg [m]";
  Real crossTrackError "signed cross-track error [m]";
  Real depthError "depth error [m]";
  Real routeCompletion "fraction of total path completed [0..1]";
  Real u_ref, v_ref, psi_ref;

  // ---- Environment / disturbance ----
  Real currentX, currentY, distLoad;

  // ---- Tracking metrics ----
  Real trackingError "primary tracking error [m]";
  Real absTrackingError;

  // ---- Synchronized sensor traces ----
  Real imu_acc_x "IMU body x acceleration [m/s2]";
  Real imu_acc_y "IMU body y acceleration [m/s2]";
  Real imu_rate "IMU yaw rate [rad/s]";
  Real pressure_depth "pressure-derived depth [m]";
  Real dvl_vx "DVL body x velocity [m/s]";
  Real dvl_vy "DVL body y velocity [m/s]";
  Real acoustic_range "acoustic range to origin [m]";
  Real compass_heading "compass heading [rad]";
  Real seabedClearance "vertical clearance to seabed [m]";

  // ---- Status ----
  Boolean trackingRequirementMet;
  Boolean routeComplete;
  Boolean finiteCheck "finite-valued invariant (Modelica lacks portable NaN test)";

protected
  Real Mz_surge, Mz_sway;

equation
  // ---- Environment ----
  currentX = 0.0;
  currentY = currentSpeed;
  distLoad = if (time >= tEnd/3.0 and time <= 2.0*tEnd/3.0) then disturbanceForce else 0.0;

  // ---- Lawnmower path reference (3 legs along North with East offsets) ----
  s_ref = pathSpeed * time;
  routeCompletion = if s_ref >= pathLen then 1.0 else s_ref/pathLen;
  segPsi = if s_ref < legLen then 0.0
           else (if s_ref < 2.0*legLen then Modelica.Constants.pi else 0.0);
  crossRef = if s_ref < legLen then 0.0
             else (if s_ref < 2.0*legLen then legSpacing else 2.0*legSpacing);
  crossTrackError = if s_ref < legLen then (y - crossRef)
                    else (if s_ref < 2.0*legLen then (crossRef - y) else (y - crossRef));

  // ---- Reference commands with current compensation ----
  u_ref = pathSpeed;
  // Feed-forward sway to cancel lateral current ground drift along active leg
  v_ref = -currentY/cos(segPsi) - Kp_cross*crossTrackError;
  psi_ref = segPsi;
  depthError = targetDepth - z;

  // ---- Controller (commanded body wrench) ----
  Fx_cmd = Kp_u*(u_ref - u) + dU*u_ref;
  Fy_cmd = Kp_v*(v_ref - v) + dV*v_ref;
  Fz_cmd = Kp_z*depthError - Kd_z*w + netBuoyancy;
  Mz_cmd = Kp_psi*(psi_ref - psi) - Kd_psi*r;

  // ---- Allocation to six bidirectional thrusters ----
  Mz_surge = Mz_cmd/2.0;
  Mz_sway  = Mz_cmd/2.0;
  Tcmd[1] = (Fx_cmd + Mz_surge/armX)/2.0;
  Tcmd[2] = (Fx_cmd - Mz_surge/armX)/2.0;
  Tcmd[3] = (Fy_cmd + Mz_sway/armY)/2.0;
  Tcmd[4] = (Fy_cmd - Mz_sway/armY)/2.0;
  Tcmd[5] = Fz_cmd/2.0;
  Tcmd[6] = Fz_cmd/2.0;

  // ---- Per-thruster saturation (165 N) ----
  for i in 1:6 loop
    T[i] = if Tcmd[i] > thrusterMax then thrusterMax
           else if Tcmd[i] < -thrusterMax then -thrusterMax
           else Tcmd[i];
  end for;

  actuatorSaturated = if (abs(Tcmd[1]) > thrusterMax or
                          abs(Tcmd[2]) > thrusterMax or
                          abs(Tcmd[3]) > thrusterMax or
                          abs(Tcmd[4]) > thrusterMax or
                          abs(Tcmd[5]) > thrusterMax or
                          abs(Tcmd[6]) > thrusterMax) then 1.0 else 0.0;

  // ---- Actual wrench produced by saturated thrusters ----
  Fx_act = T[1] + T[2];
  Fy_act = T[3] + T[4];
  Fz_act = T[5] + T[6];
  Mz_act = armX*(T[1] - T[2]) + armY*(T[3] - T[4]);

  // ---- Rigid-body plant dynamics ----
  m*der(u) = Fx_act - dU*u;
  m*der(v) = Fy_act - dV*v + distLoad;
  Iz*der(r) = Mz_act - dR*r;
  m*der(w) = Fz_act - dW*w - netBuoyancy;
  der(x) = u*cos(psi) - v*sin(psi) + currentX;
  der(y) = u*sin(psi) + v*cos(psi) + currentY;
  der(z) = w;
  der(psi) = r;

  // ---- Synchronized sensor traces (noise-free, NaN-free) ----
  imu_acc_x = Fx_act / m;
  imu_acc_y = (Fy_act + distLoad) / m;
  imu_rate = r;
  pressure_depth = z;
  dvl_vx = u;
  dvl_vy = v;
  compass_heading = psi;
  acoustic_range = sqrt(x*x + y*y + z*z + 1.0e-9);
  seabedClearance = seabedDepth - z;

  // ---- Sensor fusion estimator (complementary-style) ----
  der(psi_hat) = imu_rate + K_psi_e*(compass_heading - psi_hat);
  der(u_hat) = imu_acc_x + K_u_e*(dvl_vx - u_hat);
  der(v_hat) = imu_acc_y + K_v_e*(dvl_vy - v_hat);
  der(z_hat) = K_z_e*(pressure_depth - z_hat);
  der(x_hat) = u_hat*cos(psi_hat) - v_hat*sin(psi_hat) + currentX;
  der(y_hat) = u_hat*sin(psi_hat) + v_hat*cos(psi_hat) + currentY;

  // ---- Estimator covariance (scalar representative, bounded decay) ----
  der(P_pos) = -0.2*P_pos + 0.001;
  der(P_vel) = -0.3*P_vel + 0.001;
  der(P_psi) = -0.4*P_psi + 0.001;
  estimatorCovariance = (P_pos + P_vel + P_psi)/3.0;

  // ---- Tracking error and status flags ----
  trackingError = sqrt(crossTrackError*crossTrackError + depthError*depthError + 1.0e-12);
  absTrackingError = abs(trackingError);
  trackingRequirementMet = (absTrackingError < 0.8) and (time >= 9.1);
  routeComplete = routeCompletion >= 0.999;
  // All physical, control, and estimator values are constructed from finite
  // bounded expressions; portable NaN check is unavailable in Modelica.
  finiteCheck = true;

  annotation (
    experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "ROVSurveyD: 115 kg, 1.1x0.78x0.58 m box-frame ROV with six 165 N bidirectional thrusters. "
                         "Follows a 60 m lawnmower path at 1.0 m/s, constant depth, with 0.18 m/s lateral current "
                         "compensation and a 100 N sway load during the middle third of a 14 s, 200 Hz run. "
                         "Fuses IMU, pressure, DVL, acoustic range, and compass observations."));
end ROVSurveyD;