model TrackCrawlerInspectA
  import SI = Modelica.SIunits;

  // Stated robot and scenario parameters
  parameter SI.Mass m = 52.0 "hull mass";
  parameter SI.Length hullLength = 1.1 "capsule hull length";
  parameter SI.Length r_sprocket = 0.14 "effective track sprocket radius";
  parameter SI.Length trackSeparation = 0.50 "left-right track separation";
  parameter SI.Torque tauMax = 30.2 "per-drive torque command limit";
  parameter SI.Velocity v_ref = 0.8 "desired path speed";
  parameter SI.Length corridorWidth = 1.8 "fixed wall spacing";
  parameter SI.Length corridorHalfWidth = corridorWidth/2 "0.9 m";
  parameter SI.Time Ts = 0.0125 "80 Hz control and sensor sample period";
  parameter SI.Time tStart = 8.0/3.0 "middle-third disturbance start";
  parameter SI.Time tEnd = 16.0/3.0 "middle-third disturbance end";
  parameter SI.Force FsideDist = 45.0 "controlled side load";

  // Nominal values for facts not stated in the requirement
  parameter SI.MomentOfInertia I_zz = m*(hullLength^2 + trackSeparation^2)/12
    "nominal planar yaw inertia from stated length and separation";
  parameter Real C_drag = 10.0 "nominal longitudinal track damping, N/(m/s)";
  parameter Real C_rd = 5.0 "nominal yaw damping, N.m/(rad/s)";
  parameter Real C_lat = 1500.0 "nominal track lateral damping, N/(m/s)";
  parameter SI.Length pathAmp = 0.45 "nominal centered S-path amplitude";
  parameter SI.Length pathSeg = 3.2 "nominal S half-period";
  parameter SI.Length pathLength = v_ref*8.0 "6.4 m route length";
  parameter SI.Length bodyHalfWidth = trackSeparation/2 "nominal half width";
  parameter SI.Length alcoveRecess = 0.30 "nominal unspecified alcove recess";
  parameter SI.Length safeRange = 0.30 "obstacle avoidance trigger range";
  parameter Real kx = 1.0 "along-path speed gain, 1/s";
  parameter Real ky = 1.5 "lateral path gain, 1/(m.s)";
  parameter Real kpsi = 2.0 "heading gain, 1/s";
  parameter Real K_force = 150.0 "speed servo gain, N/(m/s)";
  parameter Real K_yaw = 80.0 "yaw servo gain, N.m/(rad/s)";
  parameter Real kavoid = 2.0 "avoidance gain, 1/(m.s)";
  parameter Real Qx = 1.0e-4 "odometry process covariance, m^2";
  parameter Real Qy = 1.0e-4 "odometry process covariance, m^2";
  parameter Real Qpsi = 1.0e-4 "IMU process covariance, rad^2";
  parameter Real Rx = 2.5e-3 "lidar map-match covariance, m^2";
  parameter Real Ry = 2.5e-3 "lidar map-match covariance, m^2";
  parameter Real Rpsi = 2.5e-3 "lidar map-match covariance, rad^2";
  parameter Real P_min = 1.0e-6 "finite covariance floor";

  // Physical plant states
  SI.Length x(start=0, fixed=true) "world x";
  SI.Length y(start=0, fixed=true) "world y";
  SI.Angle psi(start=0, fixed=true) "heading";
  SI.Velocity v(start=0.8, fixed=true) "body forward speed";
  SI.Velocity vy(start=0, fixed=true) "body lateral speed";
  SI.AngularVelocity r(start=0, fixed=true) "yaw rate";

  SI.Torque tauL "left track torque";
  SI.Torque tauR "right track torque";
  SI.Force Fx "track propulsion force";
  SI.Torque Mz "track yaw moment";
  SI.Force Fside "applied side load";
  SI.Velocity vL "left track linear speed";
  SI.Velocity vR "right track linear speed";
  SI.AngularVelocity omegaL "left sprocket speed";
  SI.AngularVelocity omegaR "right sprocket speed";

  // Sensor traces
  SI.Velocity v_odom "wheel odometry forward speed";
  SI.AngularVelocity w_odom "wheel odometry yaw rate";
  SI.AngularVelocity w_imu "IMU yaw rate";
  SI.Length rangeLeft "planar lidar left range";
  SI.Length rangeRight "planar lidar right range";

  // Corridor and clearance
  SI.Length yCenter "corridor centerline at x";
  Real inAlcove1 "first alcove indicator";
  Real inAlcove2 "second alcove indicator";
  SI.Length wallHalf "local half width";
  SI.Length clearance "minimum wall clearance";

  // Path reference
  SI.Length s_ref(start=0, fixed=true) "arc-length reference";
  SI.Length x_ref(start=0, fixed=true) "reference x";
  SI.Length y_ref "reference y";
  SI.Angle psi_ref "reference heading";
  Real ypx "dy/dx";
  Real ypp "d2y/dx2";
  Real kappa_ref "reference curvature";
  SI.AngularVelocity r_ref "reference yaw rate";
  Real routeCompletion "fraction of route completed";

  // Tracking and requirement traces
  SI.Length e_x_out "along-path error";
  SI.Length e_y_out "cross-path error";
  SI.Length e_track "primary tracking error";
  SI.Angle headingError "heading error";
  SI.Torque commandMagnitude "max track command";
  Real finiteCovariance "minimum covariance";
  Boolean clearanceOK;
  Boolean trackingOK;
  Boolean covarianceOK;
  Boolean commandOK;
  Boolean routeOK;

  // Discrete controller and estimator states
  discrete SI.Torque tauL_cmd(start=0, fixed=true) "bounded left command";
  discrete SI.Torque tauR_cmd(start=0, fixed=true) "bounded right command";
  discrete SI.Velocity v_cmd(start=0.8, fixed=true) "commanded speed";
  discrete SI.AngularVelocity r_cmd(start=0, fixed=true) "commanded yaw rate";
  discrete SI.Length x_lidar(start=0, fixed=true) "lidar map-match x";
  discrete SI.Length y_lidar(start=0, fixed=true) "lidar map-match y";
  discrete SI.Angle psi_lidar(start=0, fixed=true) "lidar map-match heading";
  discrete SI.Length x_od(start=0, fixed=true) "estimated x";
  discrete SI.Length y_od(start=0, fixed=true) "estimated y";
  discrete SI.Angle psi_od(start=0, fixed=true) "estimated heading";
  discrete Real P_x(start=0.01, fixed=true) "x covariance";
  discrete Real P_y(start=0.01, fixed=true) "y covariance";
  discrete Real P_psi(start=0.01, fixed=true) "heading covariance";

  // Discrete algorithm intermediates
  discrete Real Px_pred;
  discrete Real Py_pred;
  discrete Real Ppsi_pred;
  discrete Real Kf_x;
  discrete Real Kf_y;
  discrete Real Kf_psi;
  discrete SI.Length ex;
  discrete SI.Length ey;
  discrete SI.Angle e_psi_ctl;
  discrete SI.Length minRange;
  discrete Real dirAvoid;
  discrete SI.AngularVelocity r_avoid;
  discrete SI.Velocity v_cmd_val;
  discrete SI.AngularVelocity r_cmd_val;
  discrete SI.Force Fd;
  discrete SI.Torque Md;
  discrete SI.Torque tauSum;
  discrete SI.Torque tauDiff;

  // Estimated pose outputs
  SI.Length x_est;
  SI.Length y_est;
  SI.Angle psi_est;

equation
  // S-path reference with arc-length speed 0.8 m/s
  ypx = pathAmp*Modelica.Constants.pi/pathSeg*cos(Modelica.Constants.pi*x_ref/pathSeg);
  ypp = -pathAmp*Modelica.Constants.pi^2/pathSeg^2*sin(Modelica.Constants.pi*x_ref/pathSeg);
  der(s_ref) = if s_ref < pathLength - 1.0e-9 then v_ref else 0.0;
  der(x_ref) = if s_ref < pathLength - 1.0e-9 then v_ref/sqrt(1.0 + ypx*ypx) else 0.0;
  y_ref = pathAmp*sin(Modelica.Constants.pi*x_ref/pathSeg);
  psi_ref = Modelica.Math.atan2(ypx, 1.0);
  kappa_ref = ypp/(1.0 + ypx*ypx);
  r_ref = if s_ref < pathLength - 1.0e-9 then kappa_ref*v_ref else 0.0;
  routeCompletion = min(1.0, s_ref/pathLength);

  // Planar floating-base dynamics
  der(x) = v*cos(psi) - vy*sin(psi);
  der(y) = v*sin(psi) + vy*cos(psi);
  der(psi) = r;
  m*der(v) = Fx - C_drag*v + m*r*vy;
  m*der(vy) = Fside - C_lat*vy - m*v*r;
  I_zz*der(r) = Mz - C_rd*r;

  // Side load disturbance during middle third
  Fside = if time >= tStart and time <= tEnd then FsideDist else 0.0;

  // Skid-steer track kinematics and odometry
  vL = v - r*trackSeparation/2.0;
  vR = v + r*trackSeparation/2.0;
  omegaL = vL/r_sprocket;
  omegaR = vR/r_sprocket;
  v_odom = v;
  w_odom = r;
  w_imu = r;

  // Bounded track drive commands
  tauL = tauL_cmd;
  tauR = tauR_cmd;
  Fx = (tauL + tauR)/r_sprocket;
  Mz = (tauR - tauL)*trackSeparation/(2.0*r_sprocket);

  // Fixed corridor walls with two recessed alcoves
  yCenter = pathAmp*sin(Modelica.Constants.pi*x/pathSeg);
  inAlcove1 = if x >= 1.1 and x <= 1.7 then 1.0 else 0.0;
  inAlcove2 = if x >= 4.3 and x <= 4.9 then 1.0 else 0.0;
  wallHalf = corridorHalfWidth + alcoveRecess*(inAlcove1 + inAlcove2);
  rangeLeft = min(15.0, max(0.001, wallHalf - (y - yCenter) - bodyHalfWidth));
  rangeRight = min(15.0, max(0.001, wallHalf + (y - yCenter) - bodyHalfWidth));
  clearance = min(rangeLeft, rangeRight);

  // Requirement traces
  e_x_out = (x - x_ref)*cos(psi_ref) + (y - y_ref)*sin(psi_ref);
  e_y_out = -(x - x_ref)*sin(psi_ref) + (y - y_ref)*cos(psi_ref);
  e_track = sqrt(max(0.0, e_x_out*e_x_out + e_y_out*e_y_out));
  headingError = Modelica.Math.atan2(sin(psi - psi_ref), cos(psi - psi_ref));
  x_est = x_od;
  y_est = y_od;
  psi_est = psi_od;
  commandMagnitude = max(abs(tauL_cmd), abs(tauR_cmd));
  finiteCovariance = min(P_x, min(P_y, P_psi));

  clearanceOK = clearance > 0.18;
  trackingOK = time < 5.2 or e_track <= 0.27;
  covarianceOK = finiteCovariance > 0.0;
  commandOK = commandMagnitude <= tauMax + 1.0e-9;
  routeOK = routeCompletion >= 0.0 and routeCompletion <= 1.0 + 1.0e-9;

  assert(clearanceOK, "wall clearance below 0.18 m");
  assert(trackingOK, "primary tracking error above 0.27 m after 5.2 s");
  assert(covarianceOK, "covariance not finite");
  assert(commandOK, "track command limit violated");
  assert(routeOK, "route completion invalid");

algorithm
  when sample(0, Ts) then
    // 15 m planar lidar map-matched pose; no noise specified
    x_lidar := x;
    y_lidar := y;
    psi_lidar := psi;

    // Covariance-weighted fusion of odometry/IMU prediction with lidar
    Px_pred := P_x + Qx;
    Kf_x := Px_pred/(Px_pred + Rx);
    x_od := x_od + Kf_x*(x_lidar - x_od);
    P_x := max(P_min, (1.0 - Kf_x)*Px_pred);

    Py_pred := P_y + Qy;
    Kf_y := Py_pred/(Py_pred + Ry);
    y_od := y_od + Kf_y*(y_lidar - y_od);
    P_y := max(P_min, (1.0 - Kf_y)*Py_pred);

    Ppsi_pred := P_psi + Qpsi;
    Kf_psi := Ppsi_pred/(Ppsi_pred + Rpsi);
    psi_od := psi_od + Kf_psi*Modelica.Math.atan2(sin(psi_lidar - psi_od), cos(psi_lidar - psi_od));
    P_psi := max(P_min, (1.0 - Kf_psi)*Ppsi_pred);

    // Localization-aware path tracking errors
    ex := (x_od - x_ref)*cos(psi_ref) + (y_od - y_ref)*sin(psi_ref);
    ey := -(x_od - x_ref)*sin(psi_ref) + (y_od - y_ref)*cos(psi_ref);
    e_psi_ctl := Modelica.Math.atan2(sin(psi_od - psi_ref), cos(psi_od - psi_ref));

    // Obstacle avoidance from lidar ranges
    minRange := min(rangeLeft, rangeRight);
    if rangeLeft < rangeRight then
      dirAvoid := -1.0;
    else
      dirAvoid := 1.0;
    end if;
    r_avoid := kavoid*max(0.0, safeRange - minRange)*dirAvoid;

    // Skid-steer command synthesis
    v_cmd_val := max(0.0, min(v_ref*1.5, v_ref - kx*ex));
    r_cmd_val := r_ref - ky*ey - kpsi*e_psi_ctl + r_avoid;

    Fd := C_drag*v_cmd_val + K_force*(v_cmd_val - v);
    Md := C_rd*r_cmd_val + K_yaw*(r_cmd_val - r);

    tauSum := Fd*r_sprocket;
    tauDiff := Md*2.0*r_sprocket/trackSeparation;
    tauL_cmd := max(-tauMax, min(tauMax, 0.5*(tauSum - tauDiff)));
    tauR_cmd := max(-tauMax, min(tauMax, 0.5*(tauSum + tauDiff)));

    v_cmd := v_cmd_val;
    r_cmd := r_cmd_val;

    // Propagate odometry/IMU dead-reckoning for next 80 Hz interval
    x_od := x_od + Ts*(v_odom*cos(psi_od));
    y_od := y_od + Ts*(v_odom*sin(psi_od));
    psi_od := psi_od + Ts*w_odom;
  end when;

  annotation(experiment(StopTime=8, Interval=0.0125));
end TrackCrawlerInspectA;