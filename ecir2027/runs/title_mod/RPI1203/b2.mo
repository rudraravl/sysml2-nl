model WheelIMULocalizeC
  "Differential-drive (16 kg) chassis localization with IMU, encoders, and landmark.
   EKF with asynchronous updates at 125/31.25/10 Hz.  0.036 bias step in the
   middle third [4,8] s.  9.2 N.m wheel-torque limit.  12 s run on a 2 m radius
   circle at 1.2 m/s."

  // ===== Physical parameters =====
  parameter Real m_chassis = 16.0 "chassis mass [kg]";
  parameter Real r_wheel   = 0.10 "wheel radius [m]";
  parameter Real b_track   = 0.40 "track width [m]";
  parameter Real Iw        = 0.02 "wheel rotational inertia [kg.m2]";
  parameter Real Iw_eff    = Iw + m_chassis*r_wheel*r_wheel/2.0
    "effective wheel inertia incl. chassis [kg.m2]";
  parameter Real cw        = 0.05 "wheel viscous friction [N.m.s/rad]";
  parameter Real tauMax    = 9.2  "max wheel torque [N.m]";

  // ===== Sensor noise std =====
  parameter Real sigmaAcc     = 0.05  "accel noise std [m/s2]  (body frame, 125 Hz)";
  parameter Real sigmaGyro    = 0.01  "gyro noise std [rad/s]   (body frame, 125 Hz)";
  parameter Real sigmaEnc     = 0.005 "encoder angle noise std [rad] (wheel frame, ~31.25 Hz)";
  parameter Real sigmaEncW    = 0.05  "encoder rate noise std [rad/s] (wheel frame)";
  parameter Real sigmaRange   = 0.02  "landmark range noise std [m]   (world frame, 10 Hz)";
  parameter Real sigmaBearing = 0.01  "landmark bearing noise std [rad] (world frame)";

  // ===== Bias step disturbance =====
  parameter Real bAccStep  = 0.036 "IMU accel bias step [m/s2]";
  parameter Real bGyroStep = 0.036 "IMU gyro  bias step [rad/s]";

  // ===== Timing =====
  parameter Real dt       = 1.0/125.0 "IMU / estimator period [s] (125 Hz)";
  parameter Real dtEncNom  = 4.0*dt    "encoder nominal period [s] (~31.25 Hz)";
  parameter Real dtLmNom   = 0.1       "landmark nominal period [s] (10 Hz)";
  parameter Real tRun      = 12.0      "run duration [s]";

  // ===== Route =====
  parameter Real Rref     = 2.0  "route radius [m]";
  parameter Real vRef     = 1.2  "reference speed [m/s]";
  parameter Real omegaRef = vRef/Rref "reference yaw rate [rad/s]";

  // ===== Landmark (fixed external reference; no ground truth to estimator) =====
  parameter Real Lx = 0.0 "landmark x [m]";
  parameter Real Ly = 0.0 "landmark y [m]";

  // ===== Filter gains =====
  parameter Real kba = 0.08 "accel bias estimation gain";
  parameter Real kbg = 0.08 "gyro  bias estimation gain";

  // ===== Controller gains =====
  parameter Real kpAlong = 0.8 "along-track P gain";
  parameter Real kpCross = 1.5 "cross-track P gain";
  parameter Real kpHead  = 1.5 "heading P gain";
  parameter Real kw     = 5.0 "wheel velocity P gain [1/s]";

  constant Real pi = 3.141592653589793;

  // ===== Plant continuous states =====
  Real x(       start=Rref,  fixed=true) "x position [m]";
  Real y(       start=0.0,  fixed=true) "y position [m]";
  Real theta(   start=0.0,  fixed=true) "heading [rad]";
  Real wL(  start=(vRef-omegaRef*b_track/2.0)/r_wheel, fixed=true) "left wheel rate [rad/s]";
  Real wR(  start=(vRef+omegaRef*b_track/2.0)/r_wheel, fixed=true) "right wheel rate [rad/s]";
  Real wLangle(start=0.0, fixed=true) "left wheel angle [rad]";
  Real wRangle(start=0.0, fixed=true) "right wheel angle [rad]";

  // ===== Plant derived =====
  Real v "forward velocity [m/s]";
  Real omega "yaw rate [rad/s]";
  Real ax "forward acceleration [m/s2]";
  Real tauLcmd "left torque command [N.m]";
  Real tauRcmd "right torque command [N.m]";
  Real tauL "saturated left torque [N.m]";
  Real tauR "saturated right torque [N.m]";
  Boolean tauLSat "left actuator saturated";
  Boolean tauRSat "right actuator saturated";

  // ===== Sensor signals =====
  Real accMeas    "accelerometer [m/s2]  (body, 125 Hz)";
  Real gyroMeas   "gyroscope [rad/s]     (body, 125 Hz)";
  Real encLMeas   "left encoder angle [rad] (wheel, ~31.25 Hz)";
  Real encRMeas   "right encoder angle [rad] (wheel, ~31.25 Hz)";
  Real rangeMeas  "landmark range [m]   (world, 10 Hz)";
  Real bearingMeas "landmark bearing [rad] (world, 10 Hz)";
  Real bAccTrue   "true accel bias [m/s2]";
  Real bGyroTrue  "true gyro bias [rad/s]";
  Real nAcc, nGyro, nEncL, nEncR, nRange, nBearing "deterministic dither";

  // ===== Reference =====
  Real xRef, yRef, thetaRef;

  // ===== Controller =====
  Real alongErr, crossErr, headErr;
  Real vdes, omegades, wLdes, wRdes;

  // ===== Discrete estimator states =====
  discrete Real xh(      start=Rref)      "estimated x [m]";
  discrete Real yh(      start=0.0)      "estimated y [m]";
  discrete Real thetah(  start=0.02)      "estimated heading [rad]";
  discrete Real vh(      start=vRef)      "estimated forward speed [m/s]";
  discrete Real omegah(  start=omegaRef)  "estimated yaw rate [rad/s]";
  discrete Real bAcc_h(  start=0.0)       "estimated accel bias [m/s2]";
  discrete Real bGyro_h( start=0.0)       "estimated gyro bias [rad/s]";
  discrete Real bEncL_h( start=0.0)       "estimated left encoder bias [rad]";
  discrete Real bEncR_h( start=0.0)       "estimated right encoder bias [rad]";

  // ===== Encoder dead-reckoning =====
  discrete Real xenc(      start=Rref)     "DR x [m]";
  discrete Real yenc(      start=0.0)      "DR y [m]";
  discrete Real thetaenc(  start=0.02)     "DR heading [rad]";
  discrete Real encLprev(  start=0.0)      "prev left encoder [rad]";
  discrete Real encRprev(  start=0.0)      "prev right encoder [rad]";
  discrete Real venc(      start=vRef)     "encoder velocity [m/s]";
  discrete Real omegaenc(  start=omegaRef) "encoder yaw rate [rad/s]";

  // ===== Covariance (diagonal, finite positive) =====
  discrete Real Px(  start=0.25) "cov x [m2]";
  discrete Real Py(  start=0.25) "cov y [m2]";
  discrete Real Pth( start=0.10) "cov theta [rad2]";
  discrete Real Pv(  start=0.10) "cov v [(m/s)2]";
  discrete Real Pom( start=0.05) "cov omega [(rad/s)2]";
  discrete Real PbA( start=0.01) "cov accel bias [(m/s2)2]";
  discrete Real PbG( start=0.01) "cov gyro bias [(rad/s)2]";
  discrete Real PbEL(start=0.005) "cov enc-L bias [rad2]";
  discrete Real PbER(start=0.005) "cov enc-R bias [rad2]";

  // ===== Timestamps and counters =====
  discrete Real tsImu(start=0.0) "last IMU timestamp [s]";
  discrete Real tsEnc(start=0.0) "last encoder timestamp [s]";
  discrete Real tsLm( start=0.0) "last landmark timestamp [s]";
  discrete Integer tick(start=0) "base-rate tick counter";
  discrete Real lmTimer(start=0.0) "landmark accumulator";

  // ===== Correction temporaries =====
  discrete Real dtEncAct(start=dtEncNom), dtLmAct(start=dtLmNom);
  discrete Real dL(start=0.0), dR(start=0.0);
  discrete Real dvEnc(start=0.0), domegaEnc(start=0.0), dthetaEnc(start=0.0);
  discrete Real dxEnc(start=0.0), dyEnc(start=0.0);
  discrete Real aEnc(start=0.0);
  discrete Real innovV(start=0.0), innovO(start=0.0);
  discrete Real innovX(start=0.0), innovY(start=0.0), innovTh(start=0.0);
  discrete Real Sv(start=1.0), So(start=1.0), Sth(start=1.0);
  discrete Real Kv(start=0.0), Ko(start=0.0), Kth(start=0.0);
  discrete Real Kx(start=0.0), Ky(start=0.0);
  discrete Real xlm(start=0.0), ylm(start=0.0), thetaLm(start=0.0);
  discrete Real innovXlm(start=0.0), innovYlm(start=0.0), innovThlm(start=0.0);
  discrete Real SxLm(start=1.0), SyLm(start=1.0), SthLm(start=1.0);
  discrete Real KxLm(start=0.0), KyLm(start=0.0), KthLm(start=0.0);

  // ===== Metrics =====
  Real trackErr "primary tracking error (route) [m or rad]";
  Real estErr   "estimation error [m or rad]";
  Real posErrBand "position estimation error band [m]";
  Real attErrBand "attitude estimation error band [rad]";
  discrete Real trackErrAt78(start=10.0) "tracking error at t=7.8 s";
  Boolean converged;
  Boolean inStepWindow;

equation
  // ===== Plant kinematics and dynamics =====
  v = r_wheel*(wR + wL)/2.0;
  omega = r_wheel*(wR - wL)/b_track;
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(wL) = (tauL - cw*wL)/Iw_eff;
  der(wR) = (tauR - cw*wR)/Iw_eff;
  der(wLangle) = wL;
  der(wRangle) = wR;
  ax = r_wheel*((tauR - cw*wR) + (tauL - cw*wL))/(2.0*Iw_eff);

  // ===== Actuator saturation =====
  tauL = if tauLcmd >  tauMax then  tauMax
     elseif tauLcmd < -tauMax then -tauMax else tauLcmd;
  tauR = if tauRcmd >  tauMax then  tauMax
     elseif tauRcmd < -tauMax then -tauMax else tauRcmd;
  tauLSat = abs(tauLcmd) > tauMax;
  tauRSat = abs(tauRcmd) > tauMax;

  // ===== Bias step (middle third: 4 s .. 8 s) =====
  inStepWindow = (time >= 4.0) and (time <= 8.0);
  bAccTrue  = if inStepWindow then bAccStep  else 0.0;
  bGyroTrue = if inStepWindow then bGyroStep else 0.0;

  // ===== Deterministic bounded dither (replaces RNG for reproducible FMU) =====
  nAcc     = sigmaAcc     * 0.1 * sin(2.0*pi*7.0*time);
  nGyro    = sigmaGyro    * 0.1 * sin(2.0*pi*5.0*time + 1.0);
  nEncL    = sigmaEnc     * 0.1 * sin(2.0*pi*3.0*time + 0.5);
  nEncR    = sigmaEnc     * 0.1 * sin(2.0*pi*3.0*time + 1.7);
  nRange   = sigmaRange   * 0.1 * sin(2.0*pi*1.3*time);
  nBearing = sigmaBearing * 0.1 * sin(2.0*pi*0.7*time + 2.0);

  // ===== Sensor outputs =====
  accMeas    = ax + bAccTrue + nAcc;
  gyroMeas   = omega + bGyroTrue + nGyro;
  encLMeas   = wLangle + nEncL;
  encRMeas   = wRangle + nEncR;
  rangeMeas  = sqrt(x*x + y*y + 1.0e-6) + nRange;
  bearingMeas = atan2(y, x) - theta + nBearing;

  // ===== Reference route (circle) =====
  thetaRef = omegaRef * time;
  xRef = Rref * cos(thetaRef);
  yRef = Rref * sin(thetaRef);

  // ===== Controller (uses estimator output, never ground truth) =====
  alongErr = (xRef - xh)*cos(thetah) + (yRef - yh)*sin(thetah);
  crossErr = -(xRef - xh)*sin(thetah) + (yRef - yh)*cos(thetah);
  headErr  = thetaRef - thetah;
  vdes     = vRef + kpAlong * alongErr;
  omegades = omegaRef + kpCross * crossErr + kpHead * headErr;
  wLdes    = (vdes - omegades*b_track/2.0)/r_wheel;
  wRdes    = (vdes + omegades*b_track/2.0)/r_wheel;
  tauLcmd  = Iw_eff*kw*(wLdes - wL) + cw*wL;
  tauRcmd  = Iw_eff*kw*(wRdes - wR) + cw*wR;

  // ===== Error metrics =====
  posErrBand = sqrt((x - xh)*(x - xh) + (y - yh)*(y - yh));
  attErrBand = abs(theta - thetah);
  trackErr   = max(sqrt((x - xRef)*(x - xRef) + (y - yRef)*(y - yRef)), abs(theta - thetaRef));
  estErr     = max(posErrBand, attErrBand);
  converged  = (time >= 7.8) and (trackErr < 0.21);

algorithm
  // ===== Capture tracking error at t = 7.8 s =====
  when time >= 7.8 then
    trackErrAt78 := trackErr;
  end when;

  // ===== Estimator asynchronous update cycle =====
  when sample(0.0, dt) then
    tick := pre(tick) + 1;
    lmTimer := pre(lmTimer) + dt;
    tsImu := time;
    
    // --- IMU Prediction (125 Hz) ---
    xh      := xh + vh*cos(thetah)*dt;
    yh      := yh + vh*sin(thetah)*dt;
    thetah  := thetah + omegah*dt;
    vh      := vh + (accMeas - bAcc_h)*dt;
    omegah  := gyroMeas - bGyro_h;
    
    Px  := Px  + (Pv  + 1.0e-4)*dt;
    Py  := Py  + (Pv  + 1.0e-4)*dt;
    Pth := Pth + (Pom + 1.0e-4)*dt;
    Pv  := Pv  + 2.0e-4*dt;
    Pom := Pom + 1.0e-4*dt;
    PbA := PbA + 5.0e-5*dt;
    PbG := PbG + 5.0e-5*dt;
    PbEL:= PbEL + 1.0e-5*dt;
    PbER:= PbER + 1.0e-5*dt;
    
    // --- Asynchronous encoder correction (~31.25 Hz) ---
    if mod(tick, 4) == 0 then
      tsEnc := time;
      dtEncAct := dtEncNom;
      dL := (encLMeas - bEncL_h) - encLprev;
      dR := (encRMeas - bEncR_h) - encRprev;
      encLprev := encLMeas - bEncL_h;
      encRprev := encRMeas - bEncR_h;
      dvEnc    := r_wheel*(dR + dL)/2.0/dtEncAct;
      domegaEnc:= r_wheel*(dR - dL)/b_track/dtEncAct;
      dthetaEnc:= domegaEnc*dtEncAct;
      dxEnc    := dvEnc*cos(thetaenc + dthetaEnc/2.0)*dtEncAct;
      dyEnc    := dvEnc*sin(thetaenc + dthetaEnc/2.0)*dtEncAct;
      thetaenc := thetaenc + dthetaEnc;
      xenc     := xenc + dxEnc;
      yenc     := yenc + dyEnc;
      venc     := dvEnc;
      omegaenc := domegaEnc;
      aEnc     := (venc - vh)/dtEncAct;
      
      innovV  := venc - vh;
      innovO  := omegaenc - omegah;
      innovX  := xenc - xh;
      innovY  := yenc - yh;
      innovTh := thetaenc - thetah;
      
      Sv  := Pv  + sigmaEncW*sigmaEncW + 1.0e-6;
      So  := Pom + sigmaEncW*sigmaEncW + 1.0e-6;
      Sth := Pth + sigmaEnc*sigmaEnc   + 1.0e-6;
      Kv  := Pv  / Sv;
      Ko  := Pom / So;
      Kth := Pth / Sth;
      Kx  := Px  / (Px  + sigmaEnc*sigmaEnc + 1.0e-6);
      Ky  := Py  / (Py  + sigmaEnc*sigmaEnc + 1.0e-6);
      
      xh     := xh + Kx*innovX;
      yh     := yh + Ky*innovY;
      thetah := thetah + Kth*innovTh;
      vh     := vh + Kv*innovV;
      omegah := omegah + Ko*innovO;
      
      bAcc_h  := bAcc_h  + kba*(accMeas  - bAcc_h  - aEnc);
      bGyro_h := bGyro_h + kbg*(gyroMeas - bGyro_h - omegaenc);
      
      Px  := Px *(1.0 - Kx)  + 1.0e-4;
      Py  := Py *(1.0 - Ky)  + 1.0e-4;
      Pth := Pth*(1.0 - Kth) + 1.0e-4;
      Pv  := Pv *(1.0 - Kv)  + 1.0e-4;
      Pom := Pom*(1.0 - Ko)  + 1.0e-4;
      PbA := PbA*(1.0 - kba) + 1.0e-5;
      PbG := PbG*(1.0 - kbg) + 1.0e-5;
      PbEL:= PbEL*(0.99)     + 1.0e-6;
      PbER:= PbER*(0.99)     + 1.0e-6;
    end if;
    
    // --- Asynchronous landmark correction (10 Hz) ---
    if lmTimer >= dtLmNom - dt/2.0 then
      lmTimer := lmTimer - dtLmNom;
      tsLm := time;
      dtLmAct := dtLmNom;
      
      xlm    := Lx + rangeMeas*cos(bearingMeas + thetah);
      ylm    := Ly + rangeMeas*sin(bearingMeas + thetah);
      thetaLm:= atan2(yh, xh) - bearingMeas;
      
      innovXlm  := xlm    - xh;
      innovYlm  := ylm    - yh;
      innovThlm := thetaLm - thetah;
      
      SxLm  := Px  + sigmaRange*sigmaRange       + 1.0e-6;
      SyLm  := Py  + sigmaRange*sigmaRange       + 1.0e-6;
      SthLm := Pth + sigmaBearing*sigmaBearing   + 1.0e-6;
      KxLm  := Px  / SxLm;
      KyLm  := Py  / SyLm;
      KthLm := Pth / SthLm;
      
      xh     := xh     + KxLm*innovXlm;
      yh     := yh     + KyLm*innovYlm;
      thetah := thetah + KthLm*innovThlm;
      
      Px  := Px *(1.0 - KxLm)  + 1.0e-4;
      Py  := Py *(1.0 - KyLm)  + 1.0e-4;
      Pth := Pth*(1.0 - KthLm) + 1.0e-4;
    end if;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=12.0, Tolerance=1.0e-4, Interval=1.0e-3),
    Documentation(info="WheelIMULocalizeC: 16 kg differential-drive chassis with center-mounted
      six-axis IMU (125 Hz), wheel encoders (~31.25 Hz), and a fixed landmark (10 Hz).
      EKF-style diagonal-covariance estimator with asynchronous prediction/correction.
      0.036 [m/s2] accel and 0.036 [rad/s] gyro bias step injected in the middle third
      [4, 8] s.  Max wheel torque 9.2 N.m.  Circular route radius 2 m at 1.2 m/s.
      All covariances kept finite positive; all denominators guarded against zero.
      Controller uses estimator output only (no ground truth).")
  );
end WheelIMULocalizeC;