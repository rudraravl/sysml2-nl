model MarineNavLocalizeA
  "Underwater vehicle sensing, estimation, and route-following with asynchronous EKF updates."

  constant Real pi = 3.141592653589793;

  // Scenario timing and 80 Hz execution
  parameter Real Ts=0.0125 "80 Hz loop period [s]";
  parameter Real Tfinal=8.0 "scenario duration [s]";
  parameter Real TstepStart=8.0/3.0 "middle third start [s]";
  parameter Real TstepEnd=16.0/3.0 "middle third end [s]";
  parameter Real biasStepAmp=0.02 "controlled sensor-bias step in each sensor native unit";

  // Declared sensor rates
  parameter Integer imuRateHz=80 "IMU rate [Hz]";
  parameter Integer pressureRateHz=40 "pressure depth rate [Hz]";
  parameter Integer dvlRateHz=20 "Doppler velocity rate [Hz]";
  parameter Integer compassRateHz=20 "compass rate [Hz]";
  parameter Integer rangeRateHz=1 "acoustic range rate [Hz]";
  parameter Integer pressureDiv=2 "80 Hz / pressureRateHz";
  parameter Integer dvlDiv=4 "80 Hz / dvlRateHz";
  parameter Integer compassDiv=4 "80 Hz / compassRateHz";
  parameter Integer rangeDiv=80 "80 Hz / rangeRateHz";

  // Frames (declared, not estimated from ground truth)
  constant String frameN="NED_inertial";
  constant String frameB="body_forward_starboard_down";
  constant String frameIMU="bodyB";
  constant String frameDepth="bodyB";
  constant String frameDVL="bodyB";
  constant String frameCompass="bodyB";
  constant String frameRange1="bodyB";
  constant String frameRange2="bodyB";
  constant String frameRange3="bodyB";
  constant String frameLandmark="NED_inertial";

  // Extrinsic transforms. No nonzero extrinsics were specified; identity offsets are used.
  parameter Real pIMU_x=0.0 "IMU extrinsic position offset x [m]";
  parameter Real pIMU_y=0.0 "IMU extrinsic position offset y [m]";
  parameter Real pIMU_z=0.0 "IMU extrinsic position offset z [m]";
  parameter Real pDepth_x=0.0 "pressure sensor extrinsic offset x [m]";
  parameter Real pDepth_y=0.0 "pressure sensor extrinsic offset y [m]";
  parameter Real pDepth_z=0.0 "pressure sensor extrinsic offset z [m]";
  parameter Real pDVL_x=0.0 "DVL extrinsic offset x [m]";
  parameter Real pDVL_y=0.0 "DVL extrinsic offset y [m]";
  parameter Real pDVL_z=0.0 "DVL extrinsic offset z [m]";
  parameter Real pCompass_x=0.0 "compass extrinsic offset x [m]";
  parameter Real pCompass_y=0.0 "compass extrinsic offset y [m]";
  parameter Real pCompass_z=0.0 "compass extrinsic offset z [m]";
  parameter Real compassYawOffset=0.0 "compass extrinsic yaw offset [rad]";
  parameter Real pRange1_x=0.0 "acoustic transponder 1 extrinsic offset x [m]";
  parameter Real pRange1_y=0.0 "acoustic transponder 1 extrinsic offset y [m]";
  parameter Real pRange1_z=0.0 "acoustic transponder 1 extrinsic offset z [m]";
  parameter Real pRange2_x=0.0 "acoustic transponder 2 extrinsic offset x [m]";
  parameter Real pRange2_y=0.0 "acoustic transponder 2 extrinsic offset y [m]";
  parameter Real pRange2_z=0.0 "acoustic transponder 2 extrinsic offset z [m]";
  parameter Real pRange3_x=0.0 "acoustic transponder 3 extrinsic offset x [m]";
  parameter Real pRange3_y=0.0 "acoustic transponder 3 extrinsic offset y [m]";
  parameter Real pRange3_z=0.0 "acoustic transponder 3 extrinsic offset z [m]";

  // Vehicle physical parameters
  parameter Real m=10.0 "vehicle mass [kg]";
  parameter Real Iz=2.0 "yaw inertia [kg.m2]";
  parameter Real drag_u=20.0 "surge drag coefficient [Ns/m]";
  parameter Real drag_v=20.0 "sway drag coefficient [Ns/m]";
  parameter Real drag_w=20.0 "heave drag coefficient [Ns/m]";
  parameter Real drag_r=2.0 "yaw drag coefficient [Nms/rad]";
  parameter Real thrusterArm=0.5 "thruster moment arm [m]";
  parameter Real cmdLimit=75.6 "per-thruster command magnitude limit [N]";

  // Bounded survey route
  parameter Real routeR=1.0 "route radius [m]";
  parameter Real routeOmega=0.25 "route angular rate [rad/s]";
  parameter Real depthRef=-1.0 "route depth [m]";

  // Fixed external landmarks (known to estimator, not ground truth)
  parameter Real lm1x=5.0 "landmark 1 x [m]";
  parameter Real lm1y=0.0 "landmark 1 y [m]";
  parameter Real lm1z=0.0 "landmark 1 z [m]";
  parameter Real lm2x=0.0 "landmark 2 x [m]";
  parameter Real lm2y=5.0 "landmark 2 y [m]";
  parameter Real lm2z=0.0 "landmark 2 z [m]";
  parameter Real lm3x=-5.0 "landmark 3 x [m]";
  parameter Real lm3y=0.0 "landmark 3 y [m]";
  parameter Real lm3z=0.0 "landmark 3 z [m]";

  // Sensor standard deviations and variances
  parameter Real stdIMUax=0.05 "IMU accel x std [m/s2]";
  parameter Real stdIMUay=0.05 "IMU accel y std [m/s2]";
  parameter Real stdIMUaz=0.05 "IMU accel z std [m/s2]";
  parameter Real stdGyro=0.01 "IMU gyro std [rad/s]";
  parameter Real stdDepth=0.02 "pressure depth std [m]";
  parameter Real stdDVLu=0.01 "DVL surge std [m/s]";
  parameter Real stdDVLv=0.01 "DVL sway std [m/s]";
  parameter Real stdDVLw=0.01 "DVL heave std [m/s]";
  parameter Real stdCompass=0.02 "compass yaw std [rad]";
  parameter Real stdRange=0.05 "acoustic range std [m]";
  parameter Real R_IMUax=stdIMUax^2 "IMU accel x variance [(m/s2)^2]";
  parameter Real R_IMUay=stdIMUay^2 "IMU accel y variance [(m/s2)^2]";
  parameter Real R_IMUaz=stdIMUaz^2 "IMU accel z variance [(m/s2)^2]";
  parameter Real R_Gyro=stdGyro^2 "gyro variance [(rad/s)^2]";
  parameter Real R_depth=stdDepth^2 "depth variance [m2]";
  parameter Real R_DVLu=stdDVLu^2 "DVL surge variance [(m/s)^2]";
  parameter Real R_DVLv=stdDVLv^2 "DVL sway variance [(m/s)^2]";
  parameter Real R_DVLw=stdDVLw^2 "DVL heave variance [(m/s)^2]";
  parameter Real R_compass=stdCompass^2 "compass variance [rad2]";
  parameter Real R_range=stdRange^2 "range variance [m2]";

  // Controller gains
  parameter Real KpPos=2.0 "horizontal position gain [1/s2]";
  parameter Real KdVel=4.0 "horizontal velocity gain [1/s]";
  parameter Real KpDepth=4.0 "depth position gain [1/s2]";
  parameter Real KdDepth=3.0 "depth velocity gain [1/s]";
  parameter Real KpYaw=3.0 "yaw gain [1/s2]";
  parameter Real KdYaw=1.5 "yaw rate gain [1/s]";

  // EKF covariance and bias gains
  parameter Real Qpos=1.0e-4 "position process covariance rate [m2/s]";
  parameter Real Qvel=1.0e-4 "velocity process covariance rate [(m/s)^2/s]";
  parameter Real Qyaw=1.0e-5 "yaw process covariance rate [rad2/s]";
  parameter Real Qbias=1.0e-8 "bias process covariance rate [native2/s]";
  parameter Real Pmin=1.0e-12 "minimum finite covariance";
  parameter Real Kbd=0.05 "depth bias correction gain";
  parameter Real Kbdvl=0.05 "DVL bias correction gain";
  parameter Real Kbimu=0.02 "IMU accel bias correction gain";
  parameter Real Kbgyro=0.02 "gyro bias correction gain";
  parameter Real Kbcompass=0.02 "compass bias correction gain";
  parameter Real Kbrange=0.5 "acoustic range bias correction gain";

  // Time and counters
  discrete Real t(start=0.0) "current synchronized timestamp [s]";
  Integer tick(start=0) "80 Hz sample counter";
  Boolean pressureSample;
  Boolean dvlSample;
  Boolean compassSample;
  Boolean rangeSample;

  // True physical states
  discrete Real x(start=1.0) "true inertial x [m]";
  discrete Real y(start=0.0) "true inertial y [m]";
  discrete Real z(start=-1.0) "true inertial z [m]";
  discrete Real yaw(start=pi/2) "true yaw [rad]";
  discrete Real u(start=0.25) "true surge velocity [m/s]";
  discrete Real v(start=0.0) "true sway velocity [m/s]";
  discrete Real w(start=0.0) "true heave velocity [m/s]";
  discrete Real r(start=0.25) "true yaw rate [rad/s]";

  // True sensor bias states
  discrete Real biasStep(start=0.0);
  discrete Real bIMUaxTrue(start=0.0) "true IMU accel x bias [m/s2]";
  discrete Real bIMUayTrue(start=0.0) "true IMU accel y bias [m/s2]";
  discrete Real bIMUazTrue(start=0.0) "true IMU accel z bias [m/s2]";
  discrete Real bGyroTrue(start=0.0) "true gyro bias [rad/s]";
  discrete Real bDepthTrue(start=0.0) "true depth bias [m]";
  discrete Real bDVLuTrue(start=0.0) "true DVL surge bias [m/s]";
  discrete Real bDVLvTrue(start=0.0) "true DVL sway bias [m/s]";
  discrete Real bDVLwTrue(start=0.0) "true DVL heave bias [m/s]";
  discrete Real bCompassTrue(start=0.0) "true compass bias [rad]";
  discrete Real bRange1True(start=0.0) "true range 1 bias [m]";
  discrete Real bRange2True(start=0.0) "true range 2 bias [m]";
  discrete Real bRange3True(start=0.0) "true range 3 bias [m]";

  // Sensor measurements and timestamps
  discrete Real axMeas(start=0.0) "IMU accel x measurement [m/s2]";
  discrete Real ayMeas(start=0.0) "IMU accel y measurement [m/s2]";
  discrete Real azMeas(start=0.0) "IMU accel z measurement [m/s2]";
  discrete Real gyroMeas(start=0.0) "IMU gyro measurement [rad/s]";
  discrete Real zMeas(start=-1.0) "pressure depth measurement [m]";
  discrete Real uMeas(start=0.0) "DVL surge measurement [m/s]";
  discrete Real vMeas(start=0.0) "DVL sway measurement [m/s]";
  discrete Real wMeas(start=0.0) "DVL heave measurement [m/s]";
  discrete Real yawMeas(start=pi/2) "compass yaw measurement [rad]";
  discrete Real rangeMeas1(start=0.0) "acoustic range 1 measurement [m]";
  discrete Real rangeMeas2(start=0.0) "acoustic range 2 measurement [m]";
  discrete Real rangeMeas3(start=0.0) "acoustic range 3 measurement [m]";
  discrete Real lastIMUTime(start=0.0) "last IMU timestamp [s]";
  discrete Real lastDepthTime(start=0.0) "last depth timestamp [s]";
  discrete Real lastDVLTime(start=0.0) "last DVL timestamp [s]";
  discrete Real lastCompassTime(start=0.0) "last compass timestamp [s]";
  discrete Real lastRangeTime(start=0.0) "last range timestamp [s]";

  // Control variables
  discrete Real refX(start=1.0) "route x [m]";
  discrete Real refY(start=0.0) "route y [m]";
  discrete Real refZ(start=-1.0) "route z [m]";
  discrete Real refYaw(start=pi/2) "route yaw [rad]";
  discrete Real refVx(start=0.0) "route inertial vx [m/s]";
  discrete Real refVy(start=0.25) "route inertial vy [m/s]";
  discrete Real refVz(start=0.0) "route inertial vz [m/s]";
  discrete Real refU(start=0.25) "route surge [m/s]";
  discrete Real refV(start=0.0) "route sway [m/s]";
  discrete Real refW(start=0.0) "route heave [m/s]";
  discrete Real refR(start=0.25) "route yaw rate [rad/s]";
  discrete Real refAccX(start=0.0) "route inertial ax [m/s2]";
  discrete Real refAccY(start=0.0) "route inertial ay [m/s2]";
  discrete Real refAccBodyX(start=0.0) "route body ax [m/s2]";
  discrete Real refAccBodyY(start=0.0) "route body ay [m/s2]";
  discrete Real refAccBodyZ(start=0.0) "route body az [m/s2]";
  discrete Real ex(start=0.0) "estimated x error [m]";
  discrete Real ey(start=0.0) "estimated y error [m]";
  discrete Real ez(start=0.0) "estimated z error [m]";
  discrete Real ePosBodyX(start=0.0) "body x position error [m]";
  discrete Real ePosBodyY(start=0.0) "body y position error [m]";
  discrete Real eYaw(start=0.0) "yaw error [rad]";
  discrete Real eU(start=0.0) "surge error [m/s]";
  discrete Real eV(start=0.0) "sway error [m/s]";
  discrete Real eW(start=0.0) "heave error [m/s]";
  discrete Real eR(start=0.0) "yaw rate error [rad/s]";
  discrete Real aDesU(start=0.0) "desired surge accel [m/s2]";
  discrete Real aDesV(start=0.0) "desired sway accel [m/s2]";
  discrete Real aDesW(start=0.0) "desired heave accel [m/s2]";
  discrete Real aDesR(start=0.0) "desired yaw accel [rad/s2]";
  discrete Real FxDes(start=0.0) "desired surge force [N]";
  discrete Real FyDes(start=0.0) "desired sway force [N]";
  discrete Real FzDes(start=0.0) "desired heave force [N]";
  discrete Real MzDes(start=0.0) "desired yaw moment [N.m]";
  discrete Real aThr(start=0.0) "moment equivalent force [N]";
  discrete Real cmd1Raw(start=0.0) "thruster 1 raw command [N]";
  discrete Real cmd2Raw(start=0.0) "thruster 2 raw command [N]";
  discrete Real cmd3Raw(start=0.0) "thruster 3 raw command [N]";
  discrete Real cmd4Raw(start=0.0) "thruster 4 raw command [N]";
  discrete Real cmd1(start=0.0) "thruster 1 limited command [N]";
  discrete Real cmd2(start=0.0) "thruster 2 limited command [N]";
  discrete Real cmd3(start=0.0) "thruster 3 limited command [N]";
  discrete Real cmd4(start=0.0) "thruster 4 limited command [N]";
  discrete Real Fx_body(start=0.0) "actual surge force [N]";
  discrete Real Fy_body(start=0.0) "actual sway force [N]";
  discrete Real Fz_body(start=0.0) "actual heave force [N]";
  discrete Real Mz(start=0.0) "actual yaw moment [N.m]";
  discrete Real axTrue(start=0.0) "true surge accel [m/s2]";
  discrete Real ayTrue(start=0.0) "true sway accel [m/s2]";
  discrete Real azTrue(start=0.0) "true heave accel [m/s2]";
  discrete Real alphaTrue(start=0.0) "true yaw accel [rad/s2]";

  // Estimator states
  discrete Real xE(start=1.0) "estimated x [m]";
  discrete Real yE(start=0.0) "estimated y [m]";
  discrete Real zE(start=-1.0) "estimated z [m]";
  discrete Real yawE(start=pi/2) "estimated yaw [rad]";
  discrete Real uE(start=0.25) "estimated surge [m/s]";
  discrete Real vE(start=0.0) "estimated sway [m/s]";
  discrete Real wE(start=0.0) "estimated heave [m/s]";
  discrete Real rE(start=0.25) "estimated yaw rate [rad/s]";
  discrete Real bIMUaxE(start=0.0) "estimated IMU accel x bias [m/s2]";
  discrete Real bIMUayE(start=0.0) "estimated IMU accel y bias [m/s2]";
  discrete Real bIMUazE(start=0.0) "estimated IMU accel z bias [m/s2]";
  discrete Real bGyroE(start=0.0) "estimated gyro bias [rad/s]";
  discrete Real bDepthE(start=0.0) "estimated depth bias [m]";
  discrete Real bDVLuE(start=0.0) "estimated DVL surge bias [m/s]";
  discrete Real bDVLvE(start=0.0) "estimated DVL sway bias [m/s]";
  discrete Real bDVLwE(start=0.0) "estimated DVL heave bias [m/s]";
  discrete Real bCompassE(start=0.0) "estimated compass bias [rad]";
  discrete Real bRange1E(start=0.0) "estimated range 1 bias [m]";
  discrete Real bRange2E(start=0.0) "estimated range 2 bias [m]";
  discrete Real bRange3E(start=0.0) "estimated range 3 bias [m]";

  // Predicted estimator states
  discrete Real xEp(start=1.0);
  discrete Real yEp(start=0.0);
  discrete Real zEp(start=-1.0);
  discrete Real yawEp(start=pi/2);
  discrete Real uEp(start=0.25);
  discrete Real vEp(start=0.0);
  discrete Real wEp(start=0.0);
  discrete Real rEp(start=0.25);
  discrete Real bDepthEp(start=0.0);
  discrete Real bDVLuEp(start=0.0);
  discrete Real bDVLvEp(start=0.0);
  discrete Real bDVLwEp(start=0.0);
  discrete Real bCompassEp(start=0.0);

  // Covariance states
  discrete Real Px(start=0.01);
  discrete Real Py(start=0.01);
  discrete Real Pz(start=0.01);
  discrete Real Pyaw(start=0.001);
  discrete Real Pu(start=0.01);
  discrete Real Pv(start=0.01);
  discrete Real Pw(start=0.01);
  discrete Real Pr(start=0.001);
  discrete Real PbIMUax(start=1.0e-4);
  discrete Real PbIMUay(start=1.0e-4);
  discrete Real PbIMUaz(start=1.0e-4);
  discrete Real PbGyro(start=1.0e-4);
  discrete Real PbDepth(start=1.0e-4);
  discrete Real PbDVLu(start=1.0e-4);
  discrete Real PbDVLv(start=1.0e-4);
  discrete Real PbDVLw(start=1.0e-4);
  discrete Real PbCompass(start=1.0e-4);
  discrete Real PbRange1(start=1.0e-4);
  discrete Real PbRange2(start=1.0e-4);
  discrete Real PbRange3(start=1.0e-4);

  // Predicted covariance
  discrete Real PxP(start=0.01);
  discrete Real PyP(start=0.01);
  discrete Real PzP(start=0.01);
  discrete Real PyawP(start=0.001);
  discrete Real PuP(start=0.01);
  discrete Real PvP(start=0.01);
  discrete Real PwP(start=0.01);
  discrete Real PrP(start=0.001);

  // Correction intermediates
  discrete Real zE1(start=-1.0);
  discrete Real zE2(start=-1.0);
  discrete Real zE3(start=-1.0);
  discrete Real xE1(start=1.0);
  discrete Real xE2(start=1.0);
  discrete Real yE1(start=0.0);
  discrete Real yE2(start=0.0);
  discrete Real PzD(start=0.01);
  discrete Real Px1(start=0.01);
  discrete Real Py1(start=0.01);
  discrete Real Pz1(start=0.01);
  discrete Real Px2(start=0.01);
  discrete Real Py2(start=0.01);
  discrete Real Pz2(start=0.01);
  discrete Real Px3(start=0.01);
  discrete Real Py3(start=0.01);
  discrete Real Pz3(start=0.01);
  discrete Real Kz(start=0.0);
  discrete Real Ku(start=0.0);
  discrete Real Kv(start=0.0);
  discrete Real Kw(start=0.0);
  discrete Real Kyaw(start=0.0);
  discrete Real Kx1(start=0.0);
  discrete Real Ky1(start=0.0);
  discrete Real Kz1(start=0.0);
  discrete Real Kx2(start=0.0);
  discrete Real Ky2(start=0.0);
  discrete Real Kz2(start=0.0);
  discrete Real Kx3(start=0.0);
  discrete Real Ky3(start=0.0);
  discrete Real Kz3(start=0.0);
  discrete Real innovDepth(start=0.0);
  discrete Real innovU(start=0.0);
  discrete Real innovV(start=0.0);
  discrete Real innovW(start=0.0);
  discrete Real innovYaw(start=0.0);
  discrete Real innovRange1(start=0.0);
  discrete Real innovRange2(start=0.0);
  discrete Real innovRange3(start=0.0);
  discrete Real dx1(start=0.0);
  discrete Real dy1(start=0.0);
  discrete Real dz1(start=0.0);
  discrete Real dist1(start=0.0);
  discrete Real H1x(start=0.0);
  discrete Real H1y(start=0.0);
  discrete Real H1z(start=0.0);
  discrete Real dx2(start=0.0);
  discrete Real dy2(start=0.0);
  discrete Real dz2(start=0.0);
  discrete Real dist2(start=0.0);
  discrete Real H2x(start=0.0);
  discrete Real H2y(start=0.0);
  discrete Real H2z(start=0.0);
  discrete Real dx3(start=0.0);
  discrete Real dy3(start=0.0);
  discrete Real dz3(start=0.0);
  discrete Real dist3(start=0.0);
  discrete Real H3x(start=0.0);
  discrete Real H3y(start=0.0);
  discrete Real H3z(start=0.0);

  // Observable metrics
  discrete Real posErr(start=0.0) "estimator position error [m]";
  discrete Real posBand(start=0.0) "position covariance band [m]";
  discrete Real attErr(start=0.0) "estimator attitude error [rad]";
  discrete Real attBand(start=0.0) "attitude covariance band [rad]";
  discrete Real biasErr(start=0.0) "bias convergence metric";
  discrete Real trackErrPos(start=0.0) "route position tracking error [m]";
  discrete Real trackErrYaw(start=0.0) "route yaw tracking error [rad]";
  discrete Real primaryTrackingError(start=0.0) "primary tracking error [m or rad]";

algorithm
  when sample(0, Ts) and time <= Tfinal then
    tick := pre(tick) + 1;
    t := time;

    pressureSample := mod(tick - 1, pressureDiv) == 0;
    dvlSample := mod(tick - 1, dvlDiv) == 0;
    compassSample := mod(tick - 1, compassDiv) == 0;
    rangeSample := mod(tick - 1, rangeDiv) == 0;

    // Controlled 0.02 sensor-bias step during middle third
    biasStep := if (t >= TstepStart and t <= TstepEnd) then biasStepAmp else 0.0;
    bIMUaxTrue := biasStep;
    bIMUayTrue := biasStep;
    bIMUazTrue := biasStep;
    bGyroTrue := biasStep;
    bDepthTrue := biasStep;
    bDVLuTrue := biasStep;
    bDVLvTrue := biasStep;
    bDVLwTrue := biasStep;
    bCompassTrue := biasStep;
    bRange1True := biasStep;
    bRange2True := biasStep;
    bRange3True := biasStep;

    // Bounded route reference
    refX := routeR * cos(routeOmega * t);
    refY := routeR * sin(routeOmega * t);
    refZ := depthRef;
    refVx := -routeR * routeOmega * sin(routeOmega * t);
    refVy := routeR * routeOmega * cos(routeOmega * t);
    refVz := 0.0;
    refYaw := atan2(refVy, refVx);
    refR := routeOmega;
    refAccX := -routeR * routeOmega * routeOmega * cos(routeOmega * t);
    refAccY := -routeR * routeOmega * routeOmega * sin(routeOmega * t);
    refU := refVx * cos(pre(yawE)) + refVy * sin(pre(yawE));
    refV := -refVx * sin(pre(yawE)) + refVy * cos(pre(yawE));
    refW := 0.0;
    refAccBodyX := refAccX * cos(pre(yawE)) + refAccY * sin(pre(yawE));
    refAccBodyY := -refAccX * sin(pre(yawE)) + refAccY * cos(pre(yawE));
    refAccBodyZ := 0.0;

    // Controller from estimated state
    ex := pre(xE) - refX;
    ey := pre(yE) - refY;
    ez := pre(zE) - refZ;
    ePosBodyX := ex * cos(pre(yawE)) + ey * sin(pre(yawE));
    ePosBodyY := -ex * sin(pre(yawE)) + ey * cos(pre(yawE));
    eYaw := mod(refYaw - pre(yawE) + pi, 2.0 * pi) - pi;
    eU := refU - pre(uE);
    eV := refV - pre(vE);
    eW := refW - pre(wE);
    eR := refR - pre(rE);
    aDesU := KpPos * ePosBodyX + KdVel * eU + refAccBodyX;
    aDesV := KpPos * ePosBodyY + KdVel * eV + refAccBodyY;
    aDesW := KpDepth * ez + KdDepth * eW + refAccBodyZ;
    aDesR := KpYaw * eYaw + KdYaw * eR;
    FxDes := m * aDesU + drag_u * pre(uE);
    FyDes := m * aDesV + drag_v * pre(vE);
    FzDes := m * aDesW + drag_w * pre(wE);
    MzDes := Iz * aDesR + drag_r * pre(rE);
    aThr := MzDes / thrusterArm;
    cmd1Raw := 0.25 * (FxDes + FyDes + FzDes + aThr);
    cmd2Raw := 0.25 * (FxDes + FyDes - FzDes - aThr);
    cmd3Raw := 0.25 * (FxDes - FyDes + FzDes - aThr);
    cmd4Raw := 0.25 * (FxDes - FyDes - FzDes + aThr);
    cmd1 := max(-cmdLimit, min(cmdLimit, cmd1Raw));
    cmd2 := max(-cmdLimit, min(cmdLimit, cmd2Raw));
    cmd3 := max(-cmdLimit, min(cmdLimit, cmd3Raw));
    cmd4 := max(-cmdLimit, min(cmdLimit, cmd4Raw));
    Fx_body := cmd1 + cmd2 + cmd3 + cmd4;
    Fy_body := cmd1 + cmd2 - cmd3 - cmd4;
    Fz_body := cmd1 - cmd2 + cmd3 - cmd4;
    Mz := thrusterArm * (cmd1 - cmd2 - cmd3 + cmd4);

    // Plant propagation
    axTrue := (Fx_body - drag_u * pre(u)) / m;
    ayTrue := (Fy_body - drag_v * pre(v)) / m;
    azTrue := (Fz_body - drag_w * pre(w)) / m;
    alphaTrue := (Mz - drag_r * pre(r)) / Iz;
    u := pre(u) + Ts * axTrue;
    v := pre(v) + Ts * ayTrue;
    w := pre(w) + Ts * azTrue;
    r := pre(r) + Ts * alphaTrue;
    x := pre(x) + Ts * (pre(u) * cos(pre(yaw)) - pre(v) * sin(pre(yaw)));
    y := pre(y) + Ts * (pre(u) * sin(pre(yaw)) + pre(v) * cos(pre(yaw)));
    z := pre(z) + Ts * pre(w);
    yaw := mod(pre(yaw) + Ts * pre(r) + pi, 2.0 * pi) - pi;

    // Sensor generation with declared rates, timestamps, frames, std, and bias states
    axMeas := axTrue + bIMUaxTrue;
    ayMeas := ayTrue + bIMUayTrue;
    azMeas := azTrue + bIMUazTrue;
    gyroMeas := pre(r) + bGyroTrue;
    zMeas := pre(z) + pDepth_z + bDepthTrue;
    uMeas := pre(u) + bDVLuTrue;
    vMeas := pre(v) + bDVLvTrue;
    wMeas := pre(w) + bDVLwTrue;
    yawMeas := mod(pre(yaw) + compassYawOffset + bCompassTrue + pi, 2.0 * pi) - pi;
    rangeMeas1 := sqrt(max((pre(x) - lm1x)^2 + (pre(y) - lm1y)^2 + (pre(z) - lm1z)^2, 1.0e-12)) + bRange1True;
    rangeMeas2 := sqrt(max((pre(x) - lm2x)^2 + (pre(y) - lm2y)^2 + (pre(z) - lm2z)^2, 1.0e-12)) + bRange2True;
    rangeMeas3 := sqrt(max((pre(x) - lm3x)^2 + (pre(y) - lm3y)^2 + (pre(z) - lm3z)^2, 1.0e-12)) + bRange3True;

    lastIMUTime := t;
    lastDepthTime := if pressureSample then t else pre(lastDepthTime);
    lastDVLTime := if dvlSample then t else pre(lastDVLTime);
    lastCompassTime := if compassSample then t else pre(lastCompassTime);
    lastRangeTime := if rangeSample then t else pre(lastRangeTime);

    // EKF prediction from IMU
    xEp := pre(xE) + Ts * (pre(uE) * cos(pre(yawE)) - pre(vE) * sin(pre(yawE)));
    yEp := pre(yE) + Ts * (pre(uE) * sin(pre(yawE)) + pre(vE) * cos(pre(yawE)));
    zEp := pre(zE) + Ts * pre(wE);
    yawEp := mod(pre(yawE) + Ts * pre(rE) + pi, 2.0 * pi) - pi;
    uEp := pre(uE) + Ts * ((axMeas - pre(bIMUaxE)) - drag_u * pre(uE) / m);
    vEp := pre(vE) + Ts * ((ayMeas - pre(bIMUayE)) - drag_v * pre(vE) / m);
    wEp := pre(wE) + Ts * ((azMeas - pre(bIMUazE)) - drag_w * pre(wE) / m);
    rEp := pre(rE) + Ts * ((gyroMeas - pre(bGyroE)) - drag_r * pre(rE) / Iz);

    PxP := max(pre(Px) + Qpos * Ts, Pmin);
    PyP := max(pre(Py) + Qpos * Ts, Pmin);
    PzP := max(pre(Pz) + Qpos * Ts, Pmin);
    PyawP := max(pre(Pyaw) + Qyaw * Ts, Pmin);
    PuP := max(pre(Pu) + Qvel * Ts, Pmin);
    PvP := max(pre(Pv) + Qvel * Ts, Pmin);
    PwP := max(pre(Pw) + Qvel * Ts, Pmin);
    PrP := max(pre(Pr) + Qyaw * Ts, Pmin);

    // Asynchronous pressure depth update
    bDepthEp := pre(bDepthE);
    innovDepth := zMeas - (zEp + pDepth_z + bDepthEp);
    Kz := PzP / (PzP + R_depth);
    zE1 := if pressureSample then zEp + Kz * innovDepth else zEp;
    PzD := if pressureSample then max((1.0 - Kz) * PzP, Pmin) else PzP;
    bDepthE := if pressureSample then bDepthEp + Kbd * innovDepth else bDepthEp;
    PbDepth := if pressureSample then max(pre(PbDepth) + Qbias * Ts - Kbd * pre(PbDepth), Pmin) else max(pre(PbDepth) + Qbias * Ts, Pmin);

    // Asynchronous DVL velocity update
    bDVLuEp := pre(bDVLuE);
    bDVLvEp := pre(bDVLvE);
    bDVLwEp := pre(bDVLwE);
    innovU := uMeas - (uEp + bDVLuEp);
    innovV := vMeas - (vEp + bDVLvEp);
    innovW := wMeas - (wEp + bDVLwEp);
    Ku := PuP / (PuP + R_DVLu);
    Kv := PvP / (PvP + R_DVLv);
    Kw := PwP / (PwP + R_DVLw);
    uE := if dvlSample then uEp + Ku * innovU else uEp;
    vE := if dvlSample then vEp + Kv * innovV else vEp;
    wE := if dvlSample then wEp + Kw * innovW else wEp;
    Pu := if dvlSample then max((1.0 - Ku) * PuP, Pmin) else PuP;
    Pv := if dvlSample then max((1.0 - Kv) * PvP, Pmin) else PvP;
    Pw := if dvlSample then max((1.0 - Kw) * PwP, Pmin) else PwP;
    bDVLuE := if dvlSample then bDVLuEp + Kbdvl * innovU else bDVLuEp;
    bDVLvE := if dvlSample then bDVLvEp + Kbdvl * innovV else bDVLvEp;
    bDVLwE := if dvlSample then bDVLwEp + Kbdvl * innovW else bDVLwEp;
    PbDVLu := if dvlSample then max(pre(PbDVLu) + Qbias * Ts - Kbdvl * pre(PbDVLu), Pmin) else max(pre(PbDVLu) + Qbias * Ts, Pmin);
    PbDVLv := if dvlSample then max(pre(PbDVLv) + Qbias * Ts - Kbdvl * pre(PbDVLv), Pmin) else max(pre(PbDVLv) + Qbias * Ts, Pmin);
    PbDVLw := if dvlSample then max(pre(PbDVLw) + Qbias * Ts - Kbdvl * pre(PbDVLw), Pmin) else max(pre(PbDVLw) + Qbias * Ts, Pmin);
    bIMUaxE := if dvlSample then pre(bIMUaxE) + Kbimu * innovU else pre(bIMUaxE);
    bIMUayE := if dvlSample then pre(bIMUayE) + Kbimu * innovV else pre(bIMUayE);
    bIMUazE := if dvlSample then pre(bIMUazE) + Kbimu * innovW else pre(bIMUazE);
    PbIMUax := if dvlSample then max(pre(PbIMUax) + Qbias * Ts - Kbimu * pre(PbIMUax), Pmin) else max(pre(PbIMUax) + Qbias * Ts, Pmin);
    PbIMUay := if dvlSample then max(pre(PbIMUay) + Qbias * Ts - Kbimu * pre(PbIMUay), Pmin) else max(pre(PbIMUay) + Qbias * Ts, Pmin);
    PbIMUaz := if dvlSample then max(pre(PbIMUaz) + Qbias * Ts - Kbimu * pre(PbIMUaz), Pmin) else max(pre(PbIMUaz) + Qbias * Ts, Pmin);

    // Asynchronous compass yaw update
    bCompassEp := pre(bCompassE);
    innovYaw := mod(yawMeas - (yawEp + bCompassEp) + pi, 2.0 * pi) - pi;
    Kyaw := PyawP / (PyawP + R_compass);
    yawE := if compassSample then mod(yawEp + Kyaw * innovYaw + pi, 2.0 * pi) - pi else yawEp;
    Pyaw := if compassSample then max((1.0 - Kyaw) * PyawP, Pmin) else PyawP;
    bCompassE := if compassSample then bCompassEp + Kbcompass * innovYaw else bCompassEp;
    PbCompass := if compassSample then max(pre(PbCompass) + Qbias * Ts - Kbcompass * pre(PbCompass), Pmin) else max(pre(PbCompass) + Qbias * Ts, Pmin);
    bGyroE := if compassSample then pre(bGyroE) + Kbgyro * innovYaw else pre(bGyroE);
    PbGyro := if compassSample then max(pre(PbGyro) + Qbias * Ts - Kbgyro * pre(PbGyro), Pmin) else max(pre(PbGyro) + Qbias * Ts, Pmin);
    rE := rEp;
    Pr := PrP;

    // Asynchronous 1 Hz acoustic range EKF updates
    dx1 := xEp - lm1x;
    dy1 := yEp - lm1y;
    dz1 := zE1 - lm1z;
    dist1 := sqrt(max(dx1 * dx1 + dy1 * dy1 + dz1 * dz1, 1.0e-12));
    H1x := dx1 / dist1;
    H1y := dy1 / dist1;
    H1z := dz1 / dist1;
    innovRange1 := rangeMeas1 - (dist1 + pre(bRange1E));
    Kx1 := PxP / (PxP + R_range);
    Ky1 := PyP / (PyP + R_range);
    Kz1 := PzD / (PzD + R_range);
    xE1 := if rangeSample then xEp + Kx1 * innovRange1 * H1x else xEp;
    yE1 := if rangeSample then yEp + Ky1 * innovRange1 * H1y else yEp;
    zE2 := if rangeSample then zE1 + Kz1 * innovRange1 * H1z else zE1;
    Px1 := if rangeSample then max((1.0 - Kx1) * PxP, Pmin) else PxP;
    Py1 := if rangeSample then max((1.0 - Ky1) * PyP, Pmin) else PyP;
    Pz1 := if rangeSample then max((1.0 - Kz1) * PzD, Pmin) else PzD;
    bRange1E := if rangeSample then pre(bRange1E) + Kbrange * innovRange1 else pre(bRange1E);
    PbRange1 := if rangeSample then max(pre(PbRange1) + Qbias * Ts - Kbrange * pre(PbRange1), Pmin) else max(pre(PbRange1) + Qbias * Ts, Pmin);

    dx2 := xE1 - lm2x;
    dy2 := yE1 - lm2y;
    dz2 := zE2 - lm2z;
    dist2 := sqrt(max(dx2 * dx2 + dy2 * dy2 + dz2 * dz2, 1.0e-12));
    H2x := dx2 / dist2;
    H2y := dy2 / dist2;
    H2z := dz2 / dist2;
    innovRange2 := rangeMeas2 - (dist2 + pre(bRange2E));
    Kx2 := Px1 / (Px1 + R_range);
    Ky2 := Py1 / (Py1 + R_range);
    Kz2 := Pz1 / (Pz1 + R_range);
    xE2 := if rangeSample then xE1 + Kx2 * innovRange2 * H2x else xE1;
    yE2 := if rangeSample then yE1 + Ky2 * innovRange2 * H2y else yE1;
    zE3 := if rangeSample then zE2 + Kz2 * innovRange2 * H2z else zE2;
    Px2 := if rangeSample then max((1.0 - Kx2) * Px1, Pmin) else Px1;
    Py2 := if rangeSample then max((1.0 - Ky2) * Py1, Pmin) else Py1;
    Pz2 := if rangeSample then max((1.0 - Kz2) * Pz1, Pmin) else Pz1;
    bRange2E := if rangeSample then pre(bRange2E) + Kbrange * innovRange2 else pre(bRange2E);
    PbRange2 := if rangeSample then max(pre(PbRange2) + Qbias * Ts - Kbrange * pre(PbRange2), Pmin) else max(pre(PbRange2) + Qbias * Ts, Pmin);

    dx3 := xE2 - lm3x;
    dy3 := yE2 - lm3y;
    dz3 := zE3 - lm3z;
    dist3 := sqrt(max(dx3 * dx3 + dy3 * dy3 + dz3 * dz3, 1.0e-12));
    H3x := dx3 / dist3;
    H3y := dy3 / dist3;
    H3z := dz3 / dist3;
    innovRange3 := rangeMeas3 - (dist3 + pre(bRange3E));
    Kx3 := Px2 / (Px2 + R_range);
    Ky3 := Py2 / (Py2 + R_range);
    Kz3 := Pz2 / (Pz2 + R_range);
    xE := if rangeSample then xE2 + Kx3 * innovRange3 * H3x else xE2;
    yE := if rangeSample then yE2 + Ky3 * innovRange3 * H3y else yE2;
    zE := if rangeSample then zE3 + Kz3 * innovRange3 * H3z else zE3;
    Px3 := if rangeSample then max((1.0 - Kx3) * Px2, Pmin) else Px2;
    Py3 := if rangeSample then max((1.0 - Ky3) * Py2, Pmin) else Py2;
    Pz3 := if rangeSample then max((1.0 - Kz3) * Pz2, Pmin) else Pz2;
    bRange3E := if rangeSample then pre(bRange3E) + Kbrange * innovRange3 else pre(bRange3E);
    PbRange3 := if rangeSample then max(pre(PbRange3) + Qbias * Ts - Kbrange * pre(PbRange3), Pmin) else max(pre(PbRange3) + Qbias * Ts, Pmin);

    Px := Px3;
    Py := Py3;
    Pz := Pz3;

    // Synchronized observable metrics
    posErr := sqrt(max((x - xE)^2 + (y - yE)^2 + (z - zE)^2, 1.0e-12));
    posBand := sqrt(max(Px + Py + Pz, 1.0e-12));
    attErr := abs(mod(yaw - yawE + pi, 2.0 * pi) - pi);
    attBand := sqrt(max(Pyaw, 1.0e-12));
    biasErr := sqrt(max(
      (bIMUaxTrue - bIMUaxE)^2 + (bIMUayTrue - bIMUayE)^2 + (bIMUazTrue - bIMUazE)^2 +
      (bGyroTrue - bGyroE)^2 + (bDepthTrue - bDepthE)^2 +
      (bDVLuTrue - bDVLuE)^2 + (bDVLvTrue - bDVLvE)^2 + (bDVLwTrue - bDVLwE)^2 +
      (bCompassTrue - bCompassE)^2 +
      (bRange1True - bRange1E)^2 + (bRange2True - bRange2E)^2 + (bRange3True - bRange3E)^2,
      1.0e-12));
    trackErrPos := sqrt(max((x - refX)^2 + (y - refY)^2 + (z - refZ)^2, 1.0e-12));
    trackErrYaw := abs(mod(yaw - refYaw + pi, 2.0 * pi) - pi);
    primaryTrackingError := sqrt(max(trackErrPos^2 + trackErrYaw^2, 1.0e-12));

    assert(Px > 0.0 and Py > 0.0 and Pz > 0.0 and Pyaw > 0.0 and Pu > 0.0 and Pv > 0.0 and Pw > 0.0 and Pr > 0.0 and
      PbIMUax > 0.0 and PbIMUay > 0.0 and PbIMUaz > 0.0 and PbGyro > 0.0 and PbDepth > 0.0 and
      PbDVLu > 0.0 and PbDVLv > 0.0 and PbDVLw > 0.0 and PbCompass > 0.0 and
      PbRange1 > 0.0 and PbRange2 > 0.0 and PbRange3 > 0.0, "covariance not positive finite");
    assert(abs(cmd1) <= cmdLimit + 1.0e-6 and abs(cmd2) <= cmdLimit + 1.0e-6 and
      abs(cmd3) <= cmdLimit + 1.0e-6 and abs(cmd4) <= cmdLimit + 1.0e-6, "actuator limit violated");
    assert(abs(x) < 1.0e6 and abs(y) < 1.0e6 and abs(z) < 1.0e6 and abs(yaw) < 1.0e6 and
      abs(u) < 1.0e6 and abs(v) < 1.0e6 and abs(w) < 1.0e6 and abs(r) < 1.0e6 and
      abs(xE) < 1.0e6 and abs(yE) < 1.0e6 and abs(zE) < 1.0e6 and abs(yawE) < 1.0e6 and
      abs(uE) < 1.0e6 and abs(vE) < 1.0e6 and abs(wE) < 1.0e6 and abs(rE) < 1.0e6 and
      abs(primaryTrackingError) < 1.0e6, "non-finite or unbounded physical/control/estimator value");
    assert(time <= 5.2 or primaryTrackingError <= 0.27, "primary tracking error above 0.27 m-or-rad after 5.2 s");
  end when;

  annotation(experiment(StopTime=8.0, Tolerance=1.0e-6));
end MarineNavLocalizeA;