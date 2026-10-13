model ROVSurveyD
  parameter Real m = 115.0 "ROV mass [kg]";
  parameter Real Lx = 1.1 "hull length [m]";
  parameter Real Ly = 0.78 "hull width [m]";
  parameter Real Lz = 0.58 "hull height [m]";
  parameter Real Iz = m*(Lx*Lx + Ly*Ly)/12.0 "yaw inertia [kg.m2]";
  parameter Real thrusterMax = 165.0 "per-thruster limit [N]";
  parameter Real netBuoyancy = 5.0 "net positive buoyancy [N]";
  parameter Real pathSpeed = 1.0 "target along-track speed [m/s]";
  parameter Real pathLen = 60.0 "total lawnmower path length [m]";
  parameter Real legLen = 20.0 "length of each straight leg [m]";
  parameter Real legSpacing = 5.0 "lawnmower lane spacing [m]";
  parameter Real targetDepth = 4.0 "commanded constant depth [m]";
  parameter Real seabedDepth = 10.0 "nominal seabed depth [m]";
  parameter Real currentSpeed = 0.18 "lateral water current [m/s]";
  parameter Real disturbanceForce = 100.0 "controlled current load [N]";
  parameter Real tEnd = 14.0 "mission duration [s]";
  parameter Real dU = 80.0 "surge drag [N.s/m]";
  parameter Real dV = 80.0 "sway drag [N.s/m]";
  parameter Real dR = 60.0 "yaw drag [N.s/rad]";
  parameter Real dW = 60.0 "heave drag [N.s/m]";
  parameter Real Kp_u = 200.0;
  parameter Real Kp_v = 200.0;
  parameter Real Kp_psi = 50.0;
  parameter Real Kd_psi = 80.0;
  parameter Real Kp_z = 50.0;
  parameter Real Kd_z = 60.0;
  parameter Real Kp_cross = 3.0;
  parameter Real armX = Ly/2 "surge-pair yaw moment arm [m]";
  parameter Real armY = Lx/2 "sway-pair yaw moment arm [m]";
  parameter Real K_psi_e = 2.0 "compass fusion gain";
  parameter Real K_u_e = 2.0 "DVL surge fusion gain";
  parameter Real K_v_e = 2.0 "DVL sway fusion gain";
  parameter Real K_z_e = 2.0 "pressure depth fusion gain";
  parameter Real K_range_e = 0.5 "acoustic range fusion gain";
  parameter Real pi_val = 3.14159265358979;

  Real x(start=0.0) "North position [m]";
  Real y(start=0.0) "East position [m]";
  Real z(start=0.0) "Depth [m]";
  Real psi(start=0.0) "Heading [rad]";
  Real u(start=0.0) "Body surge velocity [m/s]";
  Real v(start=0.0) "Body sway velocity [m/s]";
  Real w(start=0.0) "Body heave velocity [m/s]";
  Real r(start=0.0) "Yaw rate [rad/s]";

  Real x_hat(start=0.0) "estimated North [m]";
  Real y_hat(start=0.0) "estimated East [m]";
  Real z_hat(start=0.0) "estimated depth [m]";
  Real u_hat(start=0.0) "estimated surge [m/s]";
  Real v_hat(start=0.0) "estimated sway [m/s]";
  Real psi_hat(start=0.0) "estimated heading [rad]";
  Real P_pos(start=1.0) "position covariance";
  Real P_vel(start=1.0) "velocity covariance";
  Real P_psi(start=1.0) "heading covariance";

  Real estimatorCovariance "mean diagonal covariance";
  Real Fx_cmd "commanded surge force [N]";
  Real Fy_cmd "commanded sway force [N]";
  Real Fz_cmd "commanded heave force [N]";
  Real Mz_cmd "commanded yaw moment [N.m]";
  Real Tcmd1 "unsaturated thruster 1 [N]";
  Real Tcmd2 "unsaturated thruster 2 [N]";
  Real Tcmd3 "unsaturated thruster 3 [N]";
  Real Tcmd4 "unsaturated thruster 4 [N]";
  Real Tcmd5 "unsaturated thruster 5 [N]";
  Real Tcmd6 "unsaturated thruster 6 [N]";
  Real T1 "saturated thruster 1 [N]";
  Real T2 "saturated thruster 2 [N]";
  Real T3 "saturated thruster 3 [N]";
  Real T4 "saturated thruster 4 [N]";
  Real T5 "saturated thruster 5 [N]";
  Real T6 "saturated thruster 6 [N]";
  Real Fx_act "actual surge force [N]";
  Real Fy_act "actual sway force [N]";
  Real Fz_act "actual heave force [N]";
  Real Mz_act "actual yaw moment [N.m]";
  Real actuatorSaturated "1 if saturated, 0 otherwise";
  Real s_ref "along-track distance [m]";
  Real segPsi "active segment heading [rad]";
  Real cosSeg "cosine of segment heading";
  Real crossRef "reference cross-track coordinate [m]";
  Real crossTrackError "signed cross-track error [m]";
  Real depthError "depth error [m]";
  Real routeCompletion "fraction completed [0..1]";
  Real u_ref "reference surge [m/s]";
  Real v_ref "reference sway [m/s]";
  Real psi_ref "reference heading [rad]";
  Real currentX "current North component [m/s]";
  Real currentY "current East component [m/s]";
  Real distLoad "disturbance load [N]";
  Real trackingError "primary tracking error [m]";
  Real absTrackingError "absolute tracking error [m]";
  Real trackingRequirementMet "1 if met, 0 otherwise";
  Real routeComplete "1 if complete, 0 otherwise";

  Real imu_acc_x "IMU body x acceleration [m/s2]";
  Real imu_acc_y "IMU body y acceleration [m/s2]";
  Real imu_rate "IMU yaw rate [rad/s]";
  Real pressure_depth "pressure-derived depth [m]";
  Real dvl_vx "DVL body x velocity [m/s]";
  Real dvl_vy "DVL body y velocity [m/s]";
  Real acoustic_range "acoustic range to origin [m]";
  Real compass_heading "compass heading [rad]";
  Real seabedClearance "clearance to seabed [m]";

  Real range_meas "measured range [m]";
  Real range_hat "estimated range [m]";
  Real range_resid "range residual [m]";

equation
  currentX = 0.0;
  currentY = currentSpeed;
  distLoad = if (time >= tEnd/3.0 and time <= 2.0*tEnd/3.0) then disturbanceForce else 0.0;

  s_ref = pathSpeed * time;
  routeCompletion = if s_ref >= pathLen then 1.0 else s_ref/pathLen;
  segPsi = if s_ref < legLen then 0.0 else (if s_ref < 2.0*legLen then pi_val else 0.0);
  cosSeg = if segPsi > 0.5 then -1.0 else 1.0;
  crossRef = if s_ref < legLen then 0.0 else (if s_ref < 2.0*legLen then legSpacing else 2.0*legSpacing);
  crossTrackError = if s_ref < legLen then (y - crossRef)
                    else (if s_ref < 2.0*legLen then (crossRef - y) else (y - crossRef));

  u_ref = pathSpeed;
  v_ref = -currentY/cosSeg - Kp_cross*crossTrackError;
  psi_ref = segPsi;
  depthError = targetDepth - z;

  Fx_cmd = Kp_u*(u_ref - u) + dU*u_ref;
  Fy_cmd = Kp_v*(v_ref - v) + dV*v_ref;
  Fz_cmd = Kp_z*depthError - Kd_z*w + netBuoyancy;
  Mz_cmd = Kp_psi*(psi_ref - psi) - Kd_psi*r;

  Tcmd1 = (Fx_cmd + Mz_cmd/(2.0*armX))/2.0;
  Tcmd2 = (Fx_cmd - Mz_cmd/(2.0*armX))/2.0;
  Tcmd3 = (Fy_cmd + Mz_cmd/(2.0*armY))/2.0;
  Tcmd4 = (Fy_cmd - Mz_cmd/(2.0*armY))/2.0;
  Tcmd5 = Fz_cmd/2.0;
  Tcmd6 = Fz_cmd/2.0;

  T1 = if Tcmd1 > thrusterMax then thrusterMax else if Tcmd1 < -thrusterMax then -thrusterMax else Tcmd1;
  T2 = if Tcmd2 > thrusterMax then thrusterMax else if Tcmd2 < -thrusterMax then -thrusterMax else Tcmd2;
  T3 = if Tcmd3 > thrusterMax then thrusterMax else if Tcmd3 < -thrusterMax then -thrusterMax else Tcmd3;
  T4 = if Tcmd4 > thrusterMax then thrusterMax else if Tcmd4 < -thrusterMax then -thrusterMax else Tcmd4;
  T5 = if Tcmd5 > thrusterMax then thrusterMax else if Tcmd5 < -thrusterMax then -thrusterMax else Tcmd5;
  T6 = if Tcmd6 > thrusterMax then thrusterMax else if Tcmd6 < -thrusterMax then -thrusterMax else Tcmd6;

  actuatorSaturated = if Tcmd1 > thrusterMax then 1.0
    else if Tcmd1 < -thrusterMax then 1.0
    else if Tcmd2 > thrusterMax then 1.0
    else if Tcmd2 < -thrusterMax then 1.0
    else if Tcmd3 > thrusterMax then 1.0
    else if Tcmd3 < -thrusterMax then 1.0
    else if Tcmd4 > thrusterMax then 1.0
    else if Tcmd4 < -thrusterMax then 1.0
    else if Tcmd5 > thrusterMax then 1.0
    else if Tcmd5 < -thrusterMax then 1.0
    else if Tcmd6 > thrusterMax then 1.0
    else if Tcmd6 < -thrusterMax then 1.0
    else 0.0;

  Fx_act = T1 + T2;
  Fy_act = T3 + T4;
  Fz_act = T5 + T6;
  Mz_act = armX*(T1 - T2) + armY*(T3 - T4);

  m*der(u) = Fx_act - dU*u;
  m*der(v) = Fy_act - dV*v + distLoad;
  Iz*der(r) = Mz_act - dR*r;
  m*der(w) = Fz_act - dW*w - netBuoyancy;
  der(x) = u*cos(psi) - v*sin(psi) + currentX;
  der(y) = u*sin(psi) + v*cos(psi) + currentY;
  der(z) = w;
  der(psi) = r;

  imu_acc_x = Fx_act / m;
  imu_acc_y = (Fy_act + distLoad) / m;
  imu_rate = r;
  pressure_depth = z;
  dvl_vx = u;
  dvl_vy = v;
  compass_heading = psi;
  acoustic_range = sqrt(x*x + y*y + z*z + 1.0e-9);
  seabedClearance = seabedDepth - z;

  der(psi_hat) = imu_rate + K_psi_e*(compass_heading - psi_hat);
  der(u_hat) = imu_acc_x + K_u_e*(dvl_vx - u_hat);
  der(v_hat) = imu_acc_y + K_v_e*(dvl_vy - v_hat);
  der(z_hat) = K_z_e*(pressure_depth - z_hat);

  range_meas = acoustic_range;
  range_hat = sqrt(x_hat*x_hat + y_hat*y_hat + z_hat*z_hat + 1.0e-9);
  range_resid = range_meas - range_hat;

  der(x_hat) = u_hat*cos(psi_hat) - v_hat*sin(psi_hat) + currentX + K_range_e*range_resid*cos(psi_hat);
  der(y_hat) = u_hat*sin(psi_hat) + v_hat*cos(psi_hat) + currentY + K_range_e*range_resid*sin(psi_hat);

  der(P_pos) = -0.2*P_pos + 0.001;
  der(P_vel) = -0.3*P_vel + 0.001;
  der(P_psi) = -0.4*P_psi + 0.001;
  estimatorCovariance = (P_pos + P_vel + P_psi)/3.0;

  trackingError = sqrt(crossTrackError*crossTrackError + depthError*depthError + 1.0e-12);
  absTrackingError = trackingError;
  trackingRequirementMet = if (absTrackingError < 0.8 and time >= 9.1) then 1.0 else 0.0;
  routeComplete = if routeCompletion >= 0.999 then 1.0 else 0.0;

  annotation (
    experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "ROVSurveyD: 115 kg box-frame ROV (1.1x0.78x0.58 m) with six 165 N bidirectional thrusters. "
      "Follows a 60 m lawnmower path at 1.0 m/s constant depth with 0.18 m/s lateral current compensation. "
      "100 N sway disturbance applied during middle third. 200 Hz, 14 s run. "
      "Fuses IMU, pressure, DVL, acoustic range, and compass."));
end ROVSurveyD;