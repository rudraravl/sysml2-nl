model WheelIMUMapC
  import SI = Modelica.SIunits;

  // ====================================================================
  // WheelIMUMapC : Differential-drive pose filtering with loop closure
  // Unknown/unresolved facts (not stated in request) are left as
  // placeholder comments rather than fabricated:
  //  - exact obstacle-avoidance control law : NOT specified -> none added
  //  - exact camera/sonar feature model      : NOT specified -> raw passthrough
  //  - exact loop-closure optimization        : NOT specified -> single blend
  // ====================================================================

  // ---------------- Time / rate ----------------
  parameter Real fSample = 125 "Declared estimator/output rate [Hz]";
  parameter Real Tend    = 12  "Mission duration [s]";
  parameter Real dtEst   = 1/fSample "Estimator period [s]";
  final parameter Real outputRateHz = fSample "Declared output rate [Hz]";

  // ---------------- Chassis ----------------
  parameter SI.Mass     m       = 16 "Chassis mass";
  parameter SI.Length   rWheel  = 0.08 "Wheel radius";
  parameter SI.Length   Lwheel  = 0.40 "Wheelbase";
  parameter Real         Izz     = 0.80 "Yaw inertia [kg.m2]";
  parameter Real         bDrag   = 1.20 "Wheel viscous drag [N.s/m]";
  parameter Real         mEffL   = m/2 "Effective left wheel inertia mass";
  parameter Real         mEffR   = m/2 "Effective right wheel inertia mass";
  parameter Real         tauMax  = 9.20 "Max command magnitude per wheel [N.m]";

  // ---------------- Reference closed route (one loop in Tend) ----------------
  parameter SI.Length   Rref     = 2.60 "Reference circle radius [m]";
  parameter Real         omegaRef = 2*Modelica.Constants.pi/Tend "Reference yaw rate [rad/s]";
  parameter SI.Velocity  vRef     = Rref*omegaRef "Reference forward speed [m/s]";

  // ---------------- Landmarks (>=6) and obstacles (>=2) ----------------
  parameter SI.Length Lx[6] = { 4.0,  0.0, -4.0,  0.0,  3.0, -3.0};
  parameter SI.Length Ly[6] = { 0.0,  4.0,  0.0, -4.0,  3.0, -3.0};
  parameter SI.Length Ox[2] = { 0.0, -2.5};
  parameter SI.Length Oy[2] = { 0.0,  2.5};
  parameter SI.Length Orad[2] = {0.50, 0.45} "Obstacle radius [m]";

  // ---------------- Landmark perturbation (middle third) ----------------
  parameter SI.Length dPert      = 0.18 "Landmark perturbation disturbance [m]";
  parameter Real      tPertStart = Tend/3;
  parameter Real      tPertEnd   = 2*Tend/3;

  // ---------------- Sensor noise / bias (declared) ----------------
  parameter Real encNoiseStd   = 0.010 "Encoder velocity noise std [m/s]";
  parameter Real gyroBias     = 0.0020 "Gyro bias [rad/s]";
  parameter Real gyroNoiseStd = 0.0050 "Gyro noise std [rad/s]";
  parameter Real accelBiasX   = 0.030  "Accel x bias [m/s2]";
  parameter Real accelBiasY   = 0.030  "Accel y bias [m/s2]";
  parameter Real accelNoiseStd = 0.050 "Accel noise std [m/s2]";
  parameter Real rangeNoiseStd = 0.050 "Range noise std [m]";

  // ---------------- Controller gains ----------------
  parameter Real kpV    = 12.0;
  parameter Real kpTheta= 6.0;
  parameter Real kdTheta= 1.5;

  // ---------------- EKF process / measurement noise ----------------
  parameter Real qPos   = 1.0e-4 "Position process variance [m2]";
  parameter Real qTheta= 1.0e-5 "Heading process variance [rad2]";
  parameter Real rRange = 0.050*0.050 "Range measurement variance [m2]";

  // ---------------- Loop-closure reference (start pose) ----------------
  parameter SI.Length xStart    = Rref;
  parameter SI.Length yStart    = 0.0;
  parameter SI.Angle  thetaStart= Modelica.Constants.pi/2;

  // ====================================================================
  // Plant continuous states
  // ====================================================================
  SI.Length        x(start=Rref)        "True x";
  SI.Length        y(start=0.0)         "True y";
  SI.Angle         theta(start=Modelica.Constants.pi/2) "True heading";
  SI.Velocity      vL(start=vRef)       "Left wheel linear velocity";
  SI.Velocity      vR(start=vRef)       "Right wheel linear velocity";
  SI.Angle         phiL(start=0.0)      "Left wheel angle (encoder)";
  SI.Angle         phiR(start=0.0)      "Right wheel angle (encoder)";

  // Derived plant quantities
  SI.Velocity      v         "Forward speed";
  SI.AngularVelocity omega   "Yaw rate";
  SI.Acceleration  aForward  "Body forward accel";
  SI.Acceleration  aLateral  "Body lateral (centripetal) accel";

  // Commands
  Real uL_raw(start=0.0) "Raw left wheel command [N.m]";
  Real uR_raw(start=0.0) "Raw right wheel command [N.m]";
  SI.Torque tauL "Saturated left wheel torque [N.m]";
  SI.Torque tauR "Saturated right wheel torque [N.m]";

  // Reference
  SI.Angle   thetaRef;
  SI.Length  xRef;
  SI.Length  yRef;
  Real       thetaErrWrapped;
  SI.Velocity vErr;
  Real       turnCmd;

  // Tracking performance
  SI.Length  trackErr;
  Boolean    trackErrOK "Primary tracking error < 0.263 m after 7.8 s";

  // ---------------- Encoders (raw observations) ----------------
  SI.Velocity encVelL;
  SI.Velocity encVelR;

  // ---------------- IMU (six-axis: ax,ay,wz; biases declared) ----------------
  SI.Acceleration  axBody "Measured body-x accel";
  SI.Acceleration  ayBody "Measured body-y accel";
  SI.AngularVelocity wzMeas "Measured gyro z";
  // unused three-axis placeholders kept to honor "six-axis" declaration:
  SI.Acceleration  azBody(start=0) "Measured body-z accel (level, ~0)";
  SI.AngularVelocity wxMeas(start=0) "Measured gyro x (level, ~0)";
  SI.AngularVelocity wyMeas(start=0) "Measured gyro y (level, ~0)";

  // ---------------- Range exteroceptive (fused) ----------------
  SI.Length rangeMeas[6];
  Real      perturbActive;

  // ---------------- Camera / sonar raw (preserved separately) ----------------
  Real cameraRaw[3] "Raw camera features (passthrough, model not specified)";
  Real sonarRaw[2]  "Raw sonar ranges to obstacles (preserved separately)";
  SI.Length sonarMeas[2];

  // ---------------- Obstacle / collision ----------------
  SI.Length dObs1;
  SI.Length dObs2;
  SI.Length minObsDist;
  Boolean   collisionFree;

  // ====================================================================
  // Estimator (discrete EKF, 125 Hz)
  // ====================================================================
  discrete SI.Length  xEst(start=Rref) "Estimated x";
  discrete SI.Length  yEst(start=0.0)   "Estimated y";
  discrete SI.Angle   thetaEst(start=Modelica.Constants.pi/2) "Estimated heading";
  discrete Real Pxx(start=0.01);
  discrete Real Pxy(start=0.0);
  discrete Real Pxth(start=0.0);
  discrete Real Pyy(start=0.01);
  discrete Real Pyth(start=0.0);
  discrete Real Pthth(start=0.01);

  // Loop-closure
  discrete SI.Length  loopPosErr(start=0.0) "Loop-closure position error [m]";
  discrete SI.Angle   loopHeadErr(start=0.0) "Loop-closure heading error [rad]";
  discrete Real       loopClosureDone(start=0.0);
  discrete SI.Length  xEstCorr(start=Rref)   "Loop-closure-corrected x";
  discrete SI.Length  yEstCorr(start=0.0)    "Loop-closure-corrected y";
  discrete SI.Angle   thetaEstCorr(start=Modelica.Constants.pi/2) "Corrected heading";

  // Covariance finiteness flag (always true here; exposed for trace)
  Boolean covFinite "Covariance finite and non-singular guard";

  // ====================================================================
  // Continuous plant equations
  // ====================================================================
equation
  // Reference closed route
  thetaRef = omegaRef*time;
  xRef     = Rref*cos(thetaRef);
  yRef     = Rref*sin(thetaRef);

  // Wheel dynamics (decoupled per-wheel approximation)
  mEffL*der(vL) = tauL/rWheel - bDrag*vL;
  mEffR*der(vR) = tauR/rWheel - bDrag*vR;

  // Kinematics
  v     = (vL + vR)/2;
  omega = (vR - vL)/Lwheel;
  der(x)     = v*cos(theta);
  der(y)     = v*sin(theta);
  der(theta) = omega;
  der(phiL)  = vL/rWheel;
  der(phiR)  = vR/rWheel;

  // Body-frame accelerations (center-mounted IMU)
  aForward = (der(vL) + der(vR))/2;
  aLateral = -omega*v;

  // IMU measurements (declared bias + deterministic noise surrogate scaled by std)
  axBody = aForward + accelBiasX + accelNoiseStd*sin(13.0*time + 1.1);
  ayBody = aLateral + accelBiasY + accelNoiseStd*sin(17.0*time + 2.3);
  wzMeas = omega    + gyroBias  + gyroNoiseStd *sin(11.0*time + 0.7);
  azBody = 0.0      + accelNoiseStd*sin(19.0*time + 3.1);
  wxMeas = 0.0      + gyroNoiseStd *sin(23.0*time + 1.7);
  wyMeas = 0.0      + gyroNoiseStd *sin(29.0*time + 2.9);

  // Encoders
  encVelL = vL + encNoiseStd*sin(31.0*time + 0.3);
  encVelR = vR + encNoiseStd*sin(37.0*time + 1.9);

  // Landmark perturbation disturbance (middle third of run)
  perturbActive = if (time >= tPertStart and time < tPertEnd) then 1.0 else 0.0;

  // Range measurements (fused) with perturbation on measured landmark x
  for i in 1:6 loop
    rangeMeas[i] = sqrt((x - (Lx[i] + perturbActive*dPert))^2 + (y - Ly[i])^2)
                   + rangeNoiseStd*sin((7.0 + i)*time + i);
  end for;

  // Sonar raw (to obstacles, preserved separately)
  for i in 1:2 loop
    sonarMeas[i] = sqrt((x - Ox[i])^2 + (y - Oy[i])^2) - Orad[i]
                   + rangeNoiseStd*sin((11.0 + i)*time + i);
    sonarRaw[i]  = sonarMeas[i];
  end for;

  // Camera raw (preserved separately; exact feature model not specified)
  cameraRaw[1] = x     + 0.10*sin(41.0*time + 0.5);
  cameraRaw[2] = y     + 0.10*sin(43.0*time + 1.5);
  cameraRaw[3] = theta + 0.02*sin(47.0*time + 2.5);

  // Controller: track reference heading + speed
  thetaErrWrapped = atan2(sin(thetaRef - theta), cos(thetaRef - theta));
  vErr = vRef - v;
  turnCmd = kpTheta*thetaErrWrapped + kdTheta*(omegaRef - omega);
  uL_raw = kpV*vErr - turnCmd;
  uR_raw = kpV*vErr + turnCmd;
  // Saturate to max command magnitude per wheel
  tauL = max(-tauMax, min(tauMax, uL_raw));
  tauR = max(-tauMax, min(tauMax, uR_raw));

  // Tracking performance
  trackErr = sqrt((x - xRef)^2 + (y - yRef)^2);
  trackErrOK = if time > 7.8 then trackErr < 0.263 else true;

  // Obstacle distances and collision flag
  dObs1 = sqrt((x - Ox[1])^2 + (y - Oy[1])^2);
  dObs2 = sqrt((x - Ox[2])^2 + (y - Oy[2])^2);
  minObsDist = if dObs1 < dObs2 then dObs1 else dObs2;
  collisionFree = minObsDist > max(Orad[1], Orad[2]);

  // Covariance finiteness guard (exposed for trace, always true)
  covFinite = Pxx > 0 and Pyy > 0 and Pthth > 0
              and Pxx < 1e6 and Pyy < 1e6 and Pthth < 1e6
              and not (Modelica.Math.isNaN(Pxx) or Modelica.Math.isNaN(Pyy)
                       or Modelica.Math.isNaN(Pthth));

  // ====================================================================
  // Discrete EKF + loop closure at declared output rate (125 Hz)
  // ====================================================================
  when sample(0, dtEst) then
    (xEst, yEst, thetaEst, Pxx, Pxy, Pxth, Pyy, Pyth, Pthth) =
      ekfUpdate(pre(xEst), pre(yEst), pre(thetaEst),
                pre(Pxx), pre(Pxy), pre(Pxth), pre(Pyy), pre(Pyth), pre(Pthth),
                encVelL, encVelR, wzMeas, gyroBias,
                rangeMeas, Lx, Ly,
                qPos, qTheta, rRange, dtEst, Lwheel);

    if time >= Tend - dtEst - 1e-9 and pre(loopClosureDone) < 0.5 then
      loopPosErr  = sqrt((xEst - xStart)^2 + (yEst - yStart)^2);
      loopHeadErr = atan2(sin(thetaEst - thetaStart), cos(thetaEst - thetaStart));
      xEstCorr     = xEst    - 0.5*(xEst - xStart);
      yEstCorr     = yEst    - 0.5*(yEst - yStart);
      thetaEstCorr = thetaEst - 0.5*loopHeadErr;
      loopClosureDone = 1.0;
    else
      loopPosErr     = pre(loopPosErr);
      loopHeadErr    = pre(loopHeadErr);
      xEstCorr       = pre(xEstCorr);
      yEstCorr       = pre(yEstCorr);
      thetaEstCorr   = pre(thetaEstCorr);
      loopClosureDone= pre(loopClosureDone);
    end if;
  end when;

  annotation (
    Documentation(info="WheelIMUMapC: 16 kg differential-drive chassis with wheel
      encoders, six-axis center IMU (declared noise/bias), two wheel-torque
      actuators (max 9.2 N.m), 6 landmarks + 2 obstacles. EKF fuses odometry,
      IMU gyro and range updates at 125 Hz; camera/sonar raw preserved
      separately. 0.18 m landmark perturbation injected in middle third.
      Loop-closure correction blends estimator back to start pose at run end."),
    experiment(StopTime=12, Tolerance=1e-6, Interval=1/fSample));

end WheelIMUMapC;

// ====================================================================
// EKF step: predict with odometry + IMU gyro, sequential range updates
// ====================================================================
function ekfUpdate
  input Real x, y, th;
  input Real Pxx, Pxy, Pxth, Pyy, Pyth, Pthth;
  input Real vLenc, vRenc, wzIMU, gyroBias;
  input Real rangeMeas[6];
  input Real Lx[6], Ly[6];
  input Real qPos, qTheta, rRange;
  input Real dt, Lwheel;
  output Real xo, yo, tho;
  output Real Pxxo, Pxyo, Pxtho, Pyyo, Pytho, Pththo;
protected
  Real vOdo, wOdo, wIMU, wFuse;
  Real c, s, F13, F23;
  Real xp, yp, thp;
  Real Pxxp, Pxyp, Pxthp, Pyyp, Pythp, Pththp;
  Real d, dx, dy, Hx, Hy, inn, S, Kx, Ky, Kth;
  Real r0, r1, r2;
  Real eps = 1e-6;
  Integer i;
algorithm
  vOdo  := (vLenc + vRenc)/2.0;
  wOdo  := (vRenc - vLenc)/Lwheel;
  wIMU  := wzIMU - gyroBias;
  wFuse := 0.5*(wOdo + wIMU);
  c := cos(th);
  s := sin(th);
  F13 := -vOdo*dt*s;
  F23 :=  vOdo*dt*c;
  xp  := x  + vOdo*dt*c;
  yp  := y  + vOdo*dt*s;
  thp := th + wFuse*dt;

  // P_pred = F P F' + Q
  Pxthp  := Pxth + F13*Pthth;
  Pythp  := Pyth + F23*Pthth;
  Pxxp   := Pxx  + F13*Pxth + F13*Pxthp + qPos;
  Pxyp   := Pxy  + F13*Pyth + F23*Pxthp;
  Pyyp   := Pyy  + F23*Pyth + F23*Pythp + qPos;
  Pththp := Pthth + qTheta;

  // Sequential scalar range updates for all 6 landmarks
  for i in 1:6 loop
    dx := xp - Lx[i];
    dy := yp - Ly[i];
    d  := sqrt(dx*dx + dy*dy);
    if d > eps then
      Hx  := dx/d;
      Hy  := dy/d;
      inn := rangeMeas[i] - d;
      r0  := Hx*Pxxp + Hy*Pxyp;
      r1  := Hx*Pxyp + Hy*Pyyp;
      r2  := Hx*Pxthp + Hy*Pythp;
      S   := Hx*r0 + Hy*r1 + rRange;
      if S > eps then
        Kx  := r0/S;
        Ky  := r1/S;
        Kth := r2/S;
        xp     := xp     + Kx*inn;
        yp     := yp     + Ky*inn;
        thp    := thp    + Kth*inn;
        Pxxp   := Pxxp   - Kx*r0;
        Pxyp   := Pxyp   - Kx*r1;
        Pxthp  := Pxthp  - Kx*r2;
        Pyyp   := Pyyp   - Ky*r1;
        Pythp  := Pythp  - Ky*r2;
        Pththp := Pththp - Kth*r2;
      end if;
    end if;
  end for;

  xo    := xp;
  yo    := yp;
  tho   := thp;
  Pxxo  := Pxxp;
  Pxyo  := Pxyp;
  Pxtho := Pxthp;
  Pyyo  := Pyyp;
  Pytho := Pythp;
  Pththo:= Pththp;
end ekfUpdate;