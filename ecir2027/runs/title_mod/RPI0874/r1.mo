model ROVSurveyD
  /* Standalone instrumented marine robot model.
     Unknown physical details (exact inertia tensor, net buoyancy margin,
     hydrodynamic damping, thruster geometry, survey depth, seabed depth,
     acoustic transponder location, estimator noise, and lawnmower leg
     spacing) are not specified in the requirement; nominal values are used
     and labeled in comments. */

  // Physical embodiment parameters (stated)
  parameter Real m(unit="kg") = 115.0 "vehicle mass";
  parameter Real L(unit="m") = 1.1 "frame length";
  parameter Real W(unit="m") = 0.78 "frame width";
  parameter Real H(unit="m") = 0.58 "frame height";

  // Geometry halves used for nominal thruster moment arms
  parameter Real a(unit="m") = W/2 "half width, roll/thruster arm";
  parameter Real b(unit="m") = L/2 "half length, yaw/thruster arm";
  parameter Real c(unit="m") = H/2 "half height, pitch/thruster arm";

  // Nominal rectangular-prism inertia; actual box-frame inertia not specified
  parameter Real Ixx(unit="kg.m2") = m/12*(W^2 + H^2);
  parameter Real Iyy(unit="kg.m2") = m/12*(L^2 + H^2);
  parameter Real Izz(unit="kg.m2") = m/12*(L^2 + W^2);

  // Nominal hydrodynamic damping; actual damping not specified
  parameter Real du(unit="N/(m/s)") = 80.0 "surge linear damping";
  parameter Real dv(unit="N/(m/s)") = 120.0 "sway linear damping";
  parameter Real dw(unit="N/(m/s)") = 150.0 "heave linear damping";
  parameter Real dp(unit="N.m/(rad/s)") = 20.0 "roll damping";
  parameter Real dq(unit="N.m/(rad/s)") = 25.0 "pitch damping";
  parameter Real dr(unit="N.m/(rad/s)") = 30.0 "yaw damping";

  // Slight positive buoyancy margin; exact margin not specified
  parameter Real buoyancyMargin(unit="N") = 5.0 "upward net buoyancy magnitude";

  // Survey and path parameters (stated: 60 m path, 1.0 m/s, 14 s, 200 Hz)
  parameter Real speedRef(unit="m/s") = 1.0 "path speed";
  parameter Real pathLength(unit="m") = 60.0 "total lawnmower route length";
  parameter Real runTime(unit="s") = 14.0 "simulation/run time";
  parameter Real Ts(unit="s") = 0.005 "200 Hz sample period";

  // Lawnmower geometry selected to total 60 m; exact spacing not specified
  parameter Real leg1(unit="m") = 18.0 "first leg length";
  parameter Real turn1(unit="m") = 3.0 "first turn length";
  parameter Real leg2(unit="m") = 18.0 "second leg length";
  parameter Real turn2(unit="m") = 3.0 "second turn length";
  parameter Real leg3(unit="m") = 18.0 "third leg length";
  parameter Real s1(unit="m") = leg1;
  parameter Real s2(unit="m") = s1 + turn1;
  parameter Real s3(unit="m") = s2 + leg2;
  parameter Real s4(unit="m") = s3 + turn2;

  // Depth and seabed; exact survey/seabed depth not specified
  parameter Real depthRef(unit="m") = 5.0 "constant depth command";
  parameter Real seabedDepth(unit="m") = 10.0 "nominal seabed depth";

  // Water current and controlled current-load disturbance (stated)
  parameter Real currentX(unit="m/s") = 0.0 "inertial x current";
  parameter Real currentY(unit="m/s") = 0.18 "lateral inertial y current";
  parameter Real currentLoad(unit="N") = 100.0 "middle-third lateral load";
  parameter Real distStart(unit="s") = runTime/3 "disturbance start";
  parameter Real distEnd(unit="s") = 2*runTime/3 "disturbance end";

  // Actuator limits (stated)
  parameter Real thrustLimit(unit="N") = 165.0 "bidirectional thruster bound";

  // Controller gains (nominal)
  parameter Real ku = 2.5 "surge velocity gain";
  parameter Real kv = 2.5 "sway velocity gain";
  parameter Real kw = 2.5 "heave velocity gain";
  parameter Real kcte = 1.0 "cross-track velocity gain";
  parameter Real kDepth = 0.5 "depth-to-heave gain";
  parameter Real kYaw = 1.5 "heading-to-yaw-rate gain";
  parameter Real kr = 3.0 "yaw-rate gain";
  parameter Real krollP = 3.0 "roll-rate gain";
  parameter Real krollPhi = 10.0 "roll-angle gain";
  parameter Real kpitchQ = 3.0 "pitch-rate gain";
  parameter Real kpitchTheta = 10.0 "pitch-angle gain";

  // Estimator noise/covariance parameters (nominal)
  parameter Real Qvel = 1e-4 "velocity process noise";
  parameter Real Rvel = 1e-4 "DVL velocity measurement noise";
  parameter Real Qpos = 1e-4 "position process noise";
  parameter Real Rrange = 2.5e-3 "acoustic range measurement noise";
  parameter Real Rpressure = 1e-6 "pressure depth measurement noise";
  parameter Real Rcompass = 1e-6 "compass heading measurement noise";
  parameter Real epsR = 1e-12 "range norm guard";

  // Physical state
  Real x(start=0.0, unit="m") "inertial x position";
  Real y(start=0.0, unit="m") "inertial y position";
  Real z(start=depthRef, unit="m") "depth";
  Real u(start=0.0, unit="m/s") "body surge velocity relative water";
  Real v(start=0.0, unit="m/s") "body sway velocity relative water";
  Real w(start=0.0, unit="m/s") "body heave velocity relative water";
  Real phi(start=0.0, unit="rad") "roll";
  Real theta(start=0.0, unit="rad") "pitch";
  Real psi(start=0.0, unit="rad") "yaw/heading";
  Real p(start=0.0, unit="rad/s") "roll rate";
  Real q(start=0.0, unit="rad/s") "pitch rate";
  Real r(start=0.0, unit="rad/s") "yaw rate";

  // Sensor traces
  Real imu_ax(unit="m/s2") "IMU surge acceleration";
  Real imu_ay(unit="m/s2") "IMU sway acceleration";
  Real imu_az(unit="m/s2") "IMU heave acceleration";
  Real imu_p(unit="rad/s") "IMU roll rate";
  Real imu_q(unit="rad/s") "IMU pitch rate";
  Real imu_r(unit="rad/s") "IMU yaw rate";
  Real pressureDepth(unit="m") "pressure-derived depth";
  Real dvl_u(unit="m/s") "DVL surge velocity";
  Real dvl_v(unit="m/s") "DVL sway velocity";
  Real dvl_w(unit="m/s") "DVL heave velocity";
  Real acousticRange(unit="m") "acoustic range to nominal origin transponder";
  Real compassHeading(unit="rad") "compass heading";

  // Path and tracking traces
  Real sPath(unit="m") "path progress";
  Real x_ref(unit="m") "path reference x";
  Real y_ref(unit="m") "path reference y";
  Real tx "path tangent x";
  Real ty "path tangent y";
  Real nx "path normal x";
  Real ny "path normal y";
  Real crossTrackError(unit="m") "signed cross-track error";
  Real alongTrackError(unit="m") "along-track error";
  Real depthError(unit="m") "z - depthRef";
  Real seabedClearance(unit="m") "seabedDepth - z";
  Real primaryTrackingError(unit="m") "Euclidean tracking error";
  Real routeCompletion "fraction of 60 m route completed";

  // Current-load disturbance
  Real currentLoadY(unit="N") "applied lateral current load";
  Real Fdist_body_x(unit="N") "current load body-x component";
  Real Fdist_body_y(unit="N") "current load body-y component";

  // Command traces
  Real vDesX(unit="m/s") "desired inertial x velocity";
  Real vDesY(unit="m/s") "desired inertial y velocity";
  Real relDesX(unit="m/s") "desired relative x velocity";
  Real relDesY(unit="m/s") "desired relative y velocity";
  Real uCmd(unit="m/s") "commanded body surge";
  Real vCmd(unit="m/s") "commanded body sway";
  Real wCmd(unit="m/s") "commanded body heave";
  Real wCmdLim(unit="m/s") "limited heave command";
  Real psiDes(unit="rad") "desired heading";
  Real yawError(unit="rad") "wrapped heading error";
  Real rCmd(unit="rad/s") "commanded yaw rate";
  Real Fx_cmd(unit="N") "surge force command";
  Real Fy_cmd(unit="N") "sway force command";
  Real Fz_cmd(unit="N") "heave force command";
  Real Mx_cmd(unit="N.m") "roll moment command";
  Real My_cmd(unit="N.m") "pitch moment command";
  Real Mz_cmd(unit="N.m") "yaw moment command";
  Real T1_des(unit="N") "thruster 1 desired";
  Real T2_des(unit="N") "thruster 2 desired";
  Real T3_des(unit="N") "thruster 3 desired";
  Real T4_des(unit="N") "thruster 4 desired";
  Real T5_des(unit="N") "thruster 5 desired";
  Real T6_des(unit="N") "thruster 6 desired";
  Real T1_actual(unit="N") "thruster 1 actual";
  Real T2_actual(unit="N") "thruster 2 actual";
  Real T3_actual(unit="N") "thruster 3 actual";
  Real T4_actual(unit="N") "thruster 4 actual";
  Real T5_actual(unit="N") "thruster 5 actual";
  Real T6_actual(unit="N") "thruster 6 actual";
  Real Fx_act(unit="N") "actual surge force";
  Real Fy_act(unit="N") "actual sway force";
  Real Fz_act(unit="N") "actual heave force";
  Real Mx_act(unit="N.m") "actual roll moment";
  Real My_act(unit="N.m") "actual pitch moment";
  Real Mz_act(unit="N.m") "actual yaw moment";
  Boolean actuatorSaturated "true if any actual thruster is at bound";
  Boolean actuatorCommandWithinBounds "true if all desired commands within bound";

  // Estimator states and covariance traces
  discrete Real x_est(start=0.0, unit="m") "estimated x";
  discrete Real y_est(start=0.0, unit="m") "estimated y";
  discrete Real z_est(start=depthRef, unit="m") "estimated depth";
  discrete Real psi_est(start=0.0, unit="rad") "estimated heading";
  discrete Real u_est(start=0.0, unit="m/s") "estimated surge";
  discrete Real v_est(start=0.0, unit="m/s") "estimated sway";
  discrete Real w_est(start=0.0, unit="m/s") "estimated heave";
  discrete Real Pxx(start=1.0, unit="m2") "x position covariance";
  discrete Real Pyy(start=1.0, unit="m2") "y position covariance";
  discrete Real Pzz(start=1.0, unit="m2") "depth covariance";
  discrete Real Ppsi(start=1.0, unit="rad2") "heading covariance";
  discrete Real Puu(start=1.0, unit="(m/s)2") "surge covariance";
  discrete Real Pvv(start=1.0, unit="(m/s)2") "sway covariance";
  discrete Real Pww(start=1.0, unit="(m/s)2") "heave covariance";

protected
  discrete Real u_pred;
  discrete Real v_pred;
  discrete Real w_pred;
  discrete Real x_pred;
  discrete Real y_pred;
  discrete Real Puu_pred;
  discrete Real Pvv_pred;
  discrete Real Pww_pred;
  discrete Real Pxx_pred;
  discrete Real Pyy_pred;
  discrete Real Ku;
  discrete Real Kv;
  discrete Real Kw;
  discrete Real Krange;
  discrete Real rPred;
  discrete Real res;

equation
  // Path generation: 60 m lawnmower, three 18 m legs and two 3 m turns
  sPath = min(pathLength, speedRef*time);

  if noEvent(sPath < s1) then
    x_ref = sPath;
    y_ref = 0.0;
    tx = 1.0;
    ty = 0.0;
    nx = 0.0;
    ny = 1.0;
  elseif noEvent(sPath < s2) then
    x_ref = s1;
    y_ref = sPath - s1;
    tx = 0.0;
    ty = 1.0;
    nx = -1.0;
    ny = 0.0;
  elseif noEvent(sPath < s3) then
    x_ref = s3 - sPath;
    y_ref = turn1;
    tx = -1.0;
    ty = 0.0;
    nx = 0.0;
    ny = -1.0;
  elseif noEvent(sPath < s4) then
    x_ref = 0.0;
    y_ref = sPath - s3 + turn1;
    tx = 0.0;
    ty = 1.0;
    nx = -1.0;
    ny = 0.0;
  else
    x_ref = sPath - s4;
    y_ref = turn1 + turn2;
    tx = 1.0;
    ty = 0.0;
    nx = 0.0;
    ny = 1.0;
  end if;

  // Current-load disturbance during middle third of run
  currentLoadY = if noEvent(time >= distStart and time <= distEnd) then currentLoad else 0.0;
  Fdist_body_x = sin(psi)*currentLoadY;
  Fdist_body_y = cos(psi)*currentLoadY;

  // Sensors
  imu_ax = der(u);
  imu_ay = der(v);
  imu_az = der(w);
  imu_p = p;
  imu_q = q;
  imu_r = r;
  pressureDepth = z;
  dvl_u = u;
  dvl_v = v;
  dvl_w = w;
  compassHeading = psi;
  acousticRange = sqrt(max(0.0, x*x + y*y + z*z + epsR));

  // Tracking errors
  crossTrackError = (x_est - x_ref)*nx + (y_est - y_ref)*ny;
  alongTrackError = (x_est - x_ref)*tx + (y_est - y_ref)*ty;
  depthError = z - depthRef;
  seabedClearance = seabedDepth - z;
  primaryTrackingError = sqrt(max(0.0, (x - x_ref)^2 + (y - y_ref)^2 + depthError^2));
  routeCompletion = min(1.0, sPath/pathLength);

  // Path-following guidance with current compensation
  vDesX = speedRef*tx - kcte*crossTrackError*nx;
  vDesY = speedRef*ty - kcte*crossTrackError*ny;
  relDesX = vDesX - currentX;
  relDesY = vDesY - currentY;
  psiDes = atan2(relDesY, relDesX);
  yawError = atan2(sin(psiDes - psi_est), cos(psiDes - psi_est));
  rCmd = max(-1.0, min(1.0, kYaw*yawError));
  uCmd = cos(psi_est)*relDesX + sin(psi_est)*relDesY;
  vCmd = -sin(psi_est)*relDesX + cos(psi_est)*relDesY;
  wCmd = -kDepth*(z_est - depthRef);
  wCmdLim = max(-0.5, min(0.5, wCmd));

  // Wrench commands
  Fx_cmd = m*ku*(uCmd - u_est) + du*u_est;
  Fy_cmd = m*kv*(vCmd - v_est) + dv*v_est;
  Fz_cmd = m*kw*(wCmdLim - w_est) + dw*w_est + buoyancyMargin;
  Mx_cmd = Ixx*(-krollP*p - krollPhi*phi) + dp*p;
  My_cmd = Iyy*(-kpitchQ*q - kpitchTheta*theta) + dq*q;
  Mz_cmd = Izz*kr*(rCmd - r) + dr*r;

  // Control allocation: six body-wrench thrusters, block-decoupled pairs
  T1_des = (Fx_cmd + My_cmd/c)/2.0;
  T2_des = (Fx_cmd - My_cmd/c)/2.0;
  T3_des = (Fy_cmd + Mz_cmd/b)/2.0;
  T4_des = (Fy_cmd - Mz_cmd/b)/2.0;
  T5_des = (Fz_cmd + Mx_cmd/a)/2.0;
  T6_des = (Fz_cmd - Mx_cmd/a)/2.0;

  // Actuator bounds
  T1_actual = max(-thrustLimit, min(thrustLimit, T1_des));
  T2_actual = max(-thrustLimit, min(thrustLimit, T2_des));
  T3_actual = max(-thrustLimit, min(thrustLimit, T3_des));
  T4_actual = max(-thrustLimit, min(thrustLimit, T4_des));
  T5_actual = max(-thrustLimit, min(thrustLimit, T5_des));
  T6_actual = max(-thrustLimit, min(thrustLimit, T6_des));

  // Actual wrench from saturated thrusters
  Fx_act = T1_actual + T2_actual;
  Fy_act = T3_actual + T4_actual;
  Fz_act = T5_actual + T6_actual;
  Mx_act = a*(T5_actual - T6_actual);
  My_act = c*(T1_actual - T2_actual);
  Mz_act = b*(T3_actual - T4_actual);

  actuatorSaturated = noEvent(
    abs(T1_actual) > 0.999*thrustLimit or
    abs(T2_actual) > 0.999*thrustLimit or
    abs(T3_actual) > 0.999*thrustLimit or
    abs(T4_actual) > 0.999*thrustLimit or
    abs(T5_actual) > 0.999*thrustLimit or
    abs(T6_actual) > 0.999*thrustLimit);

  actuatorCommandWithinBounds = noEvent(
    abs(T1_des) <= thrustLimit and
    abs(T2_des) <= thrustLimit and
    abs(T3_des) <= thrustLimit and
    abs(T4_des) <= thrustLimit and
    abs(T5_des) <= thrustLimit and
    abs(T6_des) <= thrustLimit);

  // Rigid-body plant dynamics
  der(x) = cos(psi)*u - sin(psi)*v + currentX;
  der(y) = sin(psi)*u + cos(psi)*v + currentY;
  der(z) = w;
  der(phi) = p;
  der(theta) = q;
  der(psi) = r;

  m*der(u) = Fx_act + Fdist_body_x - du*u;
  m*der(v) = Fy_act + Fdist_body_y - dv*v;
  m*der(w) = Fz_act - buoyancyMargin - dw*w;
  Ixx*der(p) = Mx_act - dp*p;
  Iyy*der(q) = My_act - dq*q;
  Izz*der(r) = Mz_act - dr*r;

  // Requirement checks
  assert(noEvent(time <= 9.1 or primaryTrackingError < 0.8),
    "ROVSurveyD: primary tracking error exceeds 0.8 m after 9.1 s");
  assert(noEvent(seabedClearance > 0.0),
    "ROVSurveyD: seabed clearance violated");
  assert(noEvent(abs(T1_actual) <= thrustLimit and abs(T2_actual) <= thrustLimit and
    abs(T3_actual) <= thrustLimit and abs(T4_actual) <= thrustLimit and
    abs(T5_actual) <= thrustLimit and abs(T6_actual) <= thrustLimit),
    "ROVSurveyD: actuator bound violated");

algorithm
  when sample(0, Ts) then
    // IMU/DVL velocity fusion
    u_pred := pre(u_est) + imu_ax*Ts;
    v_pred := pre(v_est) + imu_ay*Ts;
    w_pred := pre(w_est) + imu_az*Ts;
    Puu_pred := pre(Puu) + Qvel*Ts;
    Pvv_pred := pre(Pvv) + Qvel*Ts;
    Pww_pred := pre(Pww) + Qvel*Ts;
    Ku := Puu_pred/(Puu_pred + Rvel);
    Kv := Pvv_pred/(Pvv_pred + Rvel);
    Kw := Pww_pred/(Pww_pred + Rvel);
    u_est := u_pred + Ku*(dvl_u - u_pred);
    v_est := v_pred + Kv*(dvl_v - v_pred);
    w_est := w_pred + Kw*(dvl_w - w_pred);
    Puu := (1.0 - Ku)*Puu_pred;
    Pvv := (1.0 - Kv)*Pvv_pred;
    Pww := (1.0 - Kw)*Pww_pred;

    // Compass and pressure direct observation
    psi_est := compassHeading;
    z_est := pressureDepth;
    Ppsi := Rcompass;
    Pzz := Rpressure;

    // Position prediction from fused velocity and known current
    x_pred := pre(x_est) + (cos(psi_est)*u_est - sin(psi_est)*v_est + currentX)*Ts;
    y_pred := pre(y_est) + (sin(psi_est)*u_est + cos(psi_est)*v_est + currentY)*Ts;
    Pxx_pred := pre(Pxx) + Qpos*Ts;
    Pyy_pred := pre(Pyy) + Qpos*Ts;

    // Acoustic range fusion
    rPred := sqrt(max(0.0, x_pred*x_pred + y_pred*y_pred + z_est*z_est + epsR));
    res := acousticRange - rPred;
    Krange := (Pxx_pred + Pyy_pred)/(Pxx_pred + Pyy_pred + Rrange);
    x_est := x_pred + Krange*res*x_pred/rPred;
    y_est := y_pred + Krange*res*y_pred/rPred;
    Pxx := (1.0 - Krange)*Pxx_pred;
    Pyy := (1.0 - Krange)*Pyy_pred;
  end when;

  annotation(experiment(StopTime=14.0, Tolerance=1e-6, Interval=0.005));
end ROVSurveyD;