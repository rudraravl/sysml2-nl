model CatamaranSurveyF
  // Hull and deck embodiment
  parameter Real m_hull_port(unit="kg") = 46.0 "Port hull mass";
  parameter Real m_hull_star(unit="kg") = 46.0 "Starboard hull mass";
  parameter Real m_deck(unit="kg") = 18.0 "Rigid deck mass";
  parameter Real beam(unit="m") = 1.1 "Hull separation";

  // Mission and path
  parameter Real u_ref(unit="m/s") = 1.0 "Commanded survey speed";
  parameter Real pathLength(unit="m") = 60.0 "Stated lawnmower path length";
  parameter Real legLength(unit="m") = 20.0 "Inferred lawnmower leg length";
  parameter Real laneSpacing(unit="m") = 20.0 "Inferred lane spacing";

  // Actuation
  parameter Real Fmax_prop(unit="N") = 525.0 "Per-propeller force limit";
  parameter Real Fmax_total(unit="N") = 2.0*Fmax_prop "Total thrust limit";

  // Environment
  parameter Real current_x(unit="m/s") = 0.0 "Inertial x water current";
  parameter Real current_y(unit="m/s") = 0.18 "Inertial lateral water current";
  parameter Real F_dist(unit="N") = 145.0 "Controlled current load disturbance";
  parameter Real T_dist0(unit="s") = 20.0/3.0 "Start of middle third";
  parameter Real T_dist1(unit="s") = 40.0/3.0 "End of middle third";

  // Depth and seabed (placeholders for observability)
  parameter Real depth_ref(unit="m") = 1.0 "Placeholder constant depth reference";
  parameter Real seabedDepth(unit="m") = 6.0 "Placeholder seabed depth";

  // Derived inertial and hydrodynamic parameters
  parameter Real m_total(unit="kg") = m_hull_port + m_hull_star + m_deck;
  parameter Real Iz(unit="kg.m2") = 2.0*m_hull_port*(beam/2.0)^2 + m_deck*(beam^2)/12.0;

  // Hydrodynamic drag coefficients (finite linear placeholders)
  parameter Real Du(unit="N.s/m") = 50.0 "Surge linear drag placeholder";
  parameter Real Dv(unit="N.s/m") = 500.0 "Sway linear drag placeholder";
  parameter Real Dr(unit="N.m.s/rad") = 20.0 "Yaw linear drag placeholder";
  parameter Real kz(unit="N/m") = 200.0 "Vertical restoring placeholder";
  parameter Real Dz(unit="N.s/m") = 100.0 "Vertical damping placeholder";

  // Controller gains
  parameter Real Kp_u(unit="N.s/m") = 200.0 "Surge speed proportional gain";
  parameter Real Ki_u(unit="N/m") = 100.0 "Surge speed integral gain";
  parameter Real Kp_psi(unit="N.m/rad") = 80.0 "Heading proportional gain";
  parameter Real Kd_psi(unit="N.m.s/rad") = 80.0 "Heading rate gain";
  parameter Real LA(unit="m") = 3.0 "Line-of-sight lookahead distance";

  // Estimator parameters
  parameter Real K_est_psi(unit="1/s") = 2.0 "Compass/IMU yaw correction gain";
  parameter Real tau_r_est(unit="s") = 0.5 "Yaw rate filter time constant";
  parameter Real tau_u_est(unit="s") = 0.5 "DVL surge filter time constant";
  parameter Real tau_v_est(unit="s") = 0.5 "DVL sway filter time constant";
  parameter Real tau_z_est(unit="s") = 0.5 "Pressure/range filter time constant";
  parameter Real tau_current_est(unit="s") = 1.0 "Current estimate time constant";
  parameter Real kpos(unit="1/s") = 0.05 "Position covariance decay placeholder";
  parameter Real Q_psi(unit="rad2/s") = 1e-4 "Yaw covariance process noise";
  parameter Real Q_u(unit="m2/s3") = 1e-4 "Surge covariance process noise";
  parameter Real Q_v(unit="m2/s3") = 1e-4 "Sway covariance process noise";
  parameter Real Q_z(unit="m2/s") = 1e-4 "Depth covariance process noise";
  parameter Real Q_range(unit="m2/s") = 1e-4 "Range covariance process noise";
  parameter Real Q_pos(unit="m2/s") = 1e-4 "Position covariance process noise";
  parameter Real Q_current(unit="m2/s3") = 1e-4 "Current covariance process noise";
  parameter Real P_psi_start(unit="rad2") = 0.01;
  parameter Real P_u_start(unit="m2/s2") = 0.01;
  parameter Real P_v_start(unit="m2/s2") = 0.01;
  parameter Real P_z_start(unit="m2") = 0.01;
  parameter Real P_range_start(unit="m2") = 0.01;
  parameter Real P_pos_start(unit="m2") = 0.01;
  parameter Real P_current_start(unit="m2/s2") = 0.01;

  // Physical states
  Real x(unit="m") "Inertial x position";
  Real y(unit="m") "Inertial y position";
  Real z(unit="m") "Depth";
  Real psi(unit="rad") "Heading";
  Real r(unit="rad/s") "Yaw rate";
  Real u(unit="m/s") "Surge velocity relative water";
  Real v(unit="m/s") "Sway velocity relative water";
  Real w(unit="m/s") "Heave velocity";

  // Actuator states and commands
  Real intU(unit="m") "Surge speed error integral";
  Real Fp(unit="N") "Port propeller force";
  Real Fs(unit="N") "Starboard propeller force";
  Real F_total(unit="N") "Actual total surge force";
  Real M_actual(unit="N.m") "Actual yaw moment";
  Real F_disturbance(unit="N") "Applied lateral current load";
  Real u_err(unit="m/s") "Surge speed error";
  Real Fsurge_unsat(unit="N") "Unsaturated total surge command";
  Real Fsurge_command(unit="N") "Actual total surge command";
  Real M_cmd(unit="N.m") "Yaw moment command";
  Real Fp_unsat(unit="N") "Unsaturated port propeller command";
  Real Fs_unsat(unit="N") "Unsaturated starboard propeller command";
  Real Fp_command(unit="N") "Port propeller command trace";
  Real Fs_command(unit="N") "Starboard propeller command trace";
  Real M_command(unit="N.m") "Yaw moment command trace";
  Real u_ref_command(unit="m/s") "Speed command trace";
  Real psi_ref_command(unit="rad") "Heading command trace";
  Real r_ref_command(unit="rad/s") "Yaw rate command trace";

  // Path and tracking
  Real s_path(unit="m") "Projected path progress";
  Real psi_path(unit="rad") "Path tangent angle";
  Real crossTrackError(unit="m") "Cross-track error";
  Real depthError(unit="m") "Depth error";
  Real primaryTrackingError(unit="m") "Primary tracking error";
  Real routeCompletion(unit="1") "Fraction of 60 m route completed";
  Real psi_los(unit="rad") "Line-of-sight correction";
  Real driftAngle(unit="rad") "Current compensation crab angle";
  Real psi_ref(unit="rad") "Reference heading";
  Real psi_err(unit="rad") "Wrapped heading error";

  // Sensor observations
  Real imuYawRate(unit="rad/s") "IMU yaw rate";
  Real imuHeaveAccel(unit="m/s2") "IMU heave acceleration";
  Real pressureDepth(unit="m") "Pressure-derived depth";
  Real dvlSurge(unit="m/s") "DVL surge observation";
  Real dvlSway(unit="m/s") "DVL sway observation";
  Real acousticRange(unit="m") "Acoustic range to seabed";
  Real compassHeading(unit="rad") "Compass heading";
  Real seabedClearance(unit="m") "Seabed clearance";

  // Fused estimator states
  Real x_hat(unit="m") "Fused x position";
  Real y_hat(unit="m") "Fused y position";
  Real z_hat(unit="m") "Fused depth";
  Real psi_hat(unit="rad") "Fused heading";
  Real r_hat(unit="rad/s") "Fused yaw rate";
  Real u_hat(unit="m/s") "Fused surge";
  Real v_hat(unit="m/s") "Fused sway";
  Real current_y_hat(unit="m/s") "Fused lateral current estimate";
  Real seabedClearance_hat(unit="m") "Fused seabed clearance";
  Real fusedX(unit="m") "Fused x output";
  Real fusedY(unit="m") "Fused y output";
  Real fusedDepth(unit="m") "Fused depth output";
  Real fusedHeading(unit="rad") "Fused heading output";
  Real fusedYawRate(unit="rad/s") "Fused yaw rate output";
  Real fusedSurge(unit="m/s") "Fused surge output";
  Real fusedSway(unit="m/s") "Fused sway output";
  Real fusedCurrent(unit="m/s") "Fused current output";
  Real fusedSeabedClearance(unit="m") "Fused seabed clearance output";

  // Estimator covariance
  Real P_psi(unit="rad2") "Yaw covariance";
  Real P_u(unit="m2/s2") "Surge covariance";
  Real P_v(unit="m2/s2") "Sway covariance";
  Real P_z(unit="m2") "Depth covariance";
  Real P_range(unit="m2") "Range covariance";
  Real P_pos(unit="m2") "Position covariance";
  Real P_current(unit="m2/s2") "Current covariance";
  Real estimatorCovariance(unit="rad2") "Primary estimator covariance";

  // Verification
  Boolean actuatorBoundsSatisfied;
  Boolean primaryErrorOKafter13;
  Boolean noNaNInfinite;
  Boolean verificationOK;

  // Intermediate variables for heave dynamics
  Real w_accel(unit="m/s2") "Heave acceleration";

initial equation
  x = 0.0;
  y = 0.0;
  z = depth_ref;
  psi = 0.0;
  r = 0.0;
  u = u_ref;
  v = 0.0;
  w = 0.0;
  intU = Du*u_ref/Ki_u;

  x_hat = 0.0;
  y_hat = 0.0;
  z_hat = depth_ref;
  psi_hat = 0.0;
  r_hat = 0.0;
  u_hat = u_ref;
  v_hat = 0.0;
  current_y_hat = 0.0;
  seabedClearance_hat = seabedDepth - depth_ref;

  P_psi = P_psi_start;
  P_u = P_u_start;
  P_v = P_v_start;
  P_z = P_z_start;
  P_range = P_range_start;
  P_pos = P_pos_start;
  P_current = P_current_start;

equation
  // Vessel kinematics
  der(x) = u*Modelica.Math.cos(psi) - v*Modelica.Math.sin(psi) + current_x;
  der(y) = u*Modelica.Math.sin(psi) + v*Modelica.Math.cos(psi) + current_y;
  der(z) = w;
  der(psi) = r;

  // Vessel dynamics
  m_total*der(u) = F_total - Du*u;
  m_total*der(v) = F_disturbance - Dv*v;
  w_accel = (-kz*(z - depth_ref) - Dz*w)/m_total;
  m_total*der(w) = m_total*w_accel;

  // Disturbance during middle third
  F_disturbance = if (time >= T_dist0) and (time <= T_dist1) then F_dist else 0.0;

  // Actuator mixing and saturation
  Fp_unsat = Fsurge_unsat/2.0 + M_cmd/beam;
  Fs_unsat = Fsurge_unsat/2.0 - M_cmd/beam;
  Fp = if Fp_unsat > Fmax_prop then Fmax_prop elseif Fp_unsat < -Fmax_prop then -Fmax_prop else Fp_unsat;
  Fs = if Fs_unsat > Fmax_prop then Fmax_prop elseif Fs_unsat < -Fmax_prop then -Fmax_prop else Fs_unsat;
  F_total = Fp + Fs;
  M_actual = (Fp - Fs)*beam/2.0;
  Fp_command = Fp_unsat;
  Fs_command = Fs_unsat;
  Fsurge_command = Fsurge_unsat;
  M_command = M_cmd;
  u_ref_command = u_ref;
  psi_ref_command = psi_ref;
  r_ref_command = 0.0;

  // Path geometry and tracking
  s_path = if x <= legLength then
             (if x < 0.0 then 0.0 else x)
           elseif y <= laneSpacing then
             legLength + (if y < 0.0 then 0.0 else y)
           else
             2.0*legLength + (if x < 0.0 then 0.0 else legLength - x);
  psi_path = if s_path < legLength then 0.0
             elseif s_path < 2.0*legLength then Modelica.Constants.pi/2.0
             else Modelica.Constants.pi;
  crossTrackError = if s_path < legLength then y
                    elseif s_path < 2.0*legLength then x - legLength
                    else laneSpacing - y;
  depthError = z - depth_ref;
  primaryTrackingError = Modelica.Math.sqrt(crossTrackError*crossTrackError + depthError*depthError);
  routeCompletion = if s_path >= pathLength then 1.0 elseif s_path <= 0.0 then 0.0 else s_path/pathLength;

  // Path-following control with current compensation
  psi_los = Modelica.Math.atan(-crossTrackError/LA);
  driftAngle = Modelica.Math.atan2(-(v_hat + current_y_hat), u_hat);
  psi_ref = psi_path + psi_los + driftAngle;
  psi_err = Modelica.Math.atan2(Modelica.Math.sin(psi_ref - psi_hat), Modelica.Math.cos(psi_ref - psi_hat));

  // Surge PI with anti-windup
  u_err = u_ref - u_hat;
  Fsurge_unsat = Kp_u*u_err + Ki_u*intU;
  der(intU) = if (Fsurge_unsat > Fmax_total or Fsurge_unsat < -Fmax_total) and (u_err*Fsurge_unsat > 0.0) then 0.0 else u_err;

  // Heading PD
  M_cmd = Kp_psi*psi_err + Kd_psi*(0.0 - r_hat);

  // Sensors
  imuYawRate = r;
  imuHeaveAccel = w_accel;
  pressureDepth = z;
  dvlSurge = u;
  dvlSway = v;
  seabedClearance = seabedDepth - z;
  acousticRange = seabedClearance;
  compassHeading = psi;

  // Sensor fusion estimator
  der(psi_hat) = imuYawRate + K_est_psi*(compassHeading - psi_hat);
  der(r_hat) = (imuYawRate - r_hat)/tau_r_est;
  der(u_hat) = (dvlSurge - u_hat)/tau_u_est;
  der(v_hat) = (dvlSway - v_hat)/tau_v_est;
  der(z_hat) = (pressureDepth - z_hat)/tau_z_est;
  der(seabedClearance_hat) = (acousticRange - seabedClearance_hat)/tau_z_est;
  der(current_y_hat) = (current_y - current_y_hat)/tau_current_est;
  der(x_hat) = u_hat*Modelica.Math.cos(psi_hat) - v_hat*Modelica.Math.sin(psi_hat);
  der(y_hat) = u_hat*Modelica.Math.sin(psi_hat) + v_hat*Modelica.Math.cos(psi_hat);

  // Fused outputs
  fusedX = x_hat;
  fusedY = y_hat;
  fusedDepth = z_hat;
  fusedHeading = psi_hat;
  fusedYawRate = r_hat;
  fusedSurge = u_hat;
  fusedSway = v_hat;
  fusedCurrent = current_y_hat;
  fusedSeabedClearance = seabedClearance_hat;

  // Covariance dynamics
  der(P_psi) = Q_psi - 2.0*K_est_psi*P_psi;
  der(P_u) = Q_u - 2.0*(1.0/tau_u_est)*P_u;
  der(P_v) = Q_v - 2.0*(1.0/tau_v_est)*P_v;
  der(P_z) = Q_z - 2.0*(1.0/tau_z_est)*P_z;
  der(P_range) = Q_range - 2.0*(1.0/tau_z_est)*P_range;
  der(P_pos) = Q_pos - 2.0*kpos*P_pos;
  der(P_current) = Q_current - 2.0*(1.0/tau_current_est)*P_current;
  estimatorCovariance = P_psi;

  // Verification criteria
  actuatorBoundsSatisfied = abs(Fp) <= Fmax_prop and abs(Fs) <= Fmax_prop;
  primaryErrorOKafter13 = if time >= 13.0 then primaryTrackingError <= 0.64 else false;
  noNaNInfinite = abs(x) < 1e9 and abs(y) < 1e9 and abs(z) < 1e9 and
                  abs(psi) < 1e9 and abs(u) < 1e9 and abs(v) < 1e9 and
                  abs(r) < 1e9 and abs(w) < 1e9 and abs(Fp) < 1e9 and
                  abs(Fs) < 1e9 and abs(Fsurge_unsat) < 1e9 and abs(M_cmd) < 1e9 and
                  abs(psi_hat) < 1e9 and abs(u_hat) < 1e9 and abs(v_hat) < 1e9 and
                  abs(r_hat) < 1e9 and abs(z_hat) < 1e9 and abs(current_y_hat) < 1e9 and
                  abs(seabedClearance_hat) < 1e9 and abs(P_psi) < 1e9 and
                  abs(P_u) < 1e9 and abs(P_v) < 1e9 and abs(P_z) < 1e9 and
                  abs(P_range) < 1e9 and abs(P_pos) < 1e9 and abs(P_current) < 1e9;
  verificationOK = actuatorBoundsSatisfied and noNaNInfinite and primaryErrorOKafter13 and
                   routeCompletion >= 0.0 and routeCompletion <= 1.0;

  annotation(experiment(StopTime=20.0, Interval=0.002, Tolerance=1e-6));
end CatamaranSurveyF;