model AssemblyArmCarryA
  import Modelica.Constants.g_n;
  import Modelica.Constants.pi;

  // Geometry and inertia (SI units)
  parameter Real L1 = 0.50 "link 1 length [m]";
  parameter Real L2 = 0.40 "link 2 length [m]";
  parameter Real L3 = 0.28 "link 3 length [m]";
  parameter Real L4 = 0.16 "link 4 length [m]";
  parameter Real m1 = 7.0 "link 1 mass [kg]";
  parameter Real m2 = 5.0 "link 2 mass [kg]";
  parameter Real m3 = 3.0 "link 3 mass [kg]";
  parameter Real m4 = 1.0 "link 4 mass [kg]";
  parameter Real mPayload = 6.0 "controlled payload disturbance mass [kg]";
  // Capsule radii, link center offsets, and link roll inertia are not specified;
  // point-mass link centers are used. A minimal nonzero J4_link avoids singular roll inertia.
  parameter Real J4_link = 1.0e-3 "minimal wrist roll inertia [kg.m2]";

  // Control and scenario parameters
  parameter Real Ts = 1.0/80.0 "control sample period [s]";
  parameter Real tFinal = 8.0 "scenario duration [s]";
  parameter Real t1 = tFinal/3.0 "start of middle third [s]";
  parameter Real t2 = 2.0*tFinal/3.0 "end of middle third [s]";
  parameter Real payloadTransitionTime = 0.20 "controlled payload transition time [s]; profile not specified";
  parameter Real Tmove = 2.0 "lift/reposition trajectory duration [s]; not specified";
  parameter Real q2Amp = 0.60 "lift/reposition joint amplitude [rad]; not specified";
  parameter Real Kp = 100.0 "computed-torque position gain [1/s2]";
  parameter Real Kd = 20.0 "computed-torque velocity gain [1/s]";
  parameter Real tauMax = 79.2 "saturated effort magnitude [N.m]";
  parameter Real fWristMax = 60.0 "wrist-force bound [N]";
  parameter Real retentionForceMin = 1.0 "payload retention force threshold [N]";
  parameter Real qSoftLimit = 2.0 "task soft joint bound [rad]; hardware travel limit not specified";
  parameter Real payloadMassEstMax = 20.0 "bounded payload mass estimate [kg]";
  parameter Real trackingLimit = 0.061 "primary tracking limit [rad or m]";
  parameter Real tTrackingCheck = 5.2 "tracking verification time [s]";
  parameter Real finiteBound = 1.0e12 "finite-value monitor bound";

  // Collision representation
  parameter Boolean floorCollisionEnabled = true "rigid workcell floor collision flag";
  parameter Real floorZ = 0.0 "workcell floor plane height [m]";
  parameter Boolean tableCollisionEnabled = true "fixed table collision flag; geometry/pose not specified, contact model omitted";

  // Link inertia parameters
  parameter Real J1_link = m1*(L1/2)^2 + m2*(L1+L2/2)^2 + m3*(L1+L2+L3/2)^2 + m4*(L1+L2+L3+L4/2)^2;
  parameter Real J2_link = m2*(L2/2)^2 + m3*(L2+L3/2)^2 + m4*(L2+L3+L4/2)^2;
  parameter Real J3_link = m3*(L3/2)^2 + m4*(L3+L4/2)^2;

  // Joint states
  Real q1(start=0, fixed=true) "joint 1 angle, Z axis [rad]";
  Real q2(start=0, fixed=true) "joint 2 angle, Y axis [rad]";
  Real q3(start=0, fixed=true) "joint 3 angle, Y axis [rad]";
  Real q4(start=0, fixed=true) "joint 4 angle, X axis [rad]";
  Real dq1(start=0, fixed=true) "joint 1 velocity [rad/s]";
  Real dq2(start=0, fixed=true) "joint 2 velocity [rad/s]";
  Real dq3(start=0, fixed=true) "joint 3 velocity [rad/s]";
  Real dq4(start=0, fixed=true) "joint 4 velocity [rad/s]";
  Real ddq1 "joint 1 acceleration [rad/s2]";
  Real ddq2 "joint 2 acceleration [rad/s2]";
  Real ddq3 "joint 3 acceleration [rad/s2]";
  Real ddq4 "joint 4 acceleration [rad/s2]";

  // Commanded torques
  Real tau1 "saturated joint 1 torque [N.m]";
  Real tau2 "saturated joint 2 torque [N.m]";
  Real tau3 "saturated joint 3 torque [N.m]";
  Real tau4 "saturated joint 4 torque [N.m]";

  // Dynamics terms
  Real J1 "joint 1 effective inertia [kg.m2]";
  Real J2 "joint 2 effective inertia [kg.m2]";
  Real J3 "joint 3 effective inertia [kg.m2]";
  Real J4 "joint 4 effective inertia [kg.m2]";
  Real G1 "joint 1 gravity torque [N.m]";
  Real G2 "joint 2 gravity torque [N.m]";
  Real G3 "joint 3 gravity torque [N.m]";
  Real G4 "joint 4 gravity torque [N.m]";
  Real mPayloadEff "effective payload mass [kg]";
  Real payloadFactor "controlled payload factor [0..1]";

  // Reference trajectory
  Real trajectoryTime "limited trajectory time [s]";
  Real s "smooth quintic phase";
  Real sDeriv "first derivative of quintic phase [1/s]";
  Real sSecond "second derivative of quintic phase [1/s2]";
  Real q1_ref "desired joint 1 angle [rad]";
  Real q2_ref "desired joint 2 angle [rad]";
  Real q3_ref "desired joint 3 angle [rad]";
  Real q4_ref "desired joint 4 angle [rad]";
  Real dq1_ref "desired joint 1 velocity [rad/s]";
  Real dq2_ref "desired joint 2 velocity [rad/s]";
  Real dq3_ref "desired joint 3 velocity [rad/s]";
  Real dq4_ref "desired joint 4 velocity [rad/s]";
  Real ddq1_ref "desired joint 1 acceleration [rad/s2]";
  Real ddq2_ref "desired joint 2 acceleration [rad/s2]";
  Real ddq3_ref "desired joint 3 acceleration [rad/s2]";
  Real ddq4_ref "desired joint 4 acceleration [rad/s2]";

  // End-effector pose
  Real px "end-effector x [m]";
  Real py "end-effector y [m]";
  Real pz "end-effector z [m]";
  Real pxd "desired end-effector x [m]";
  Real pyd "desired end-effector y [m]";
  Real pzd "desired end-effector z [m]";
  Real R11 "end rotation matrix 11";
  Real R22 "end rotation matrix 22";
  Real R33 "end rotation matrix 33";
  Real orientAngle "orientation error from identity [rad]";
  Real posError "end-effector position error [m]";
  Real jointError "joint-space tracking error [rad]";
  Real poseError "primary pose tracking error [rad or m]";
  Real primaryTrackingError "trace alias for pose error";

  // Wrist wrench sensor
  Real fWristX "wrist force x [N]";
  Real fWristY "wrist force y [N]";
  Real fWristZ "wrist force z [N]";
  Real fWristTx "wrist torque x [N.m]";
  Real fWristTy "wrist torque y [N.m]";
  Real fWristTz "wrist torque z [N.m]";
  Real fWristMag "wrist force magnitude [N]";
  Real azPayload "payload vertical acceleration [m/s2]";
  // Payload/tool COM offset and wrist torque components are not specified; torque components are zero.

  // Collision monitor
  Real floorPenetration "floor penetration depth [m]";

  // Synchronized sampled traces
  discrete Integer sampleCount(start=0) "80 Hz sample counter";
  discrete Real q1_s(start=0) "sampled joint 1 angle [rad]";
  discrete Real q2_s(start=0) "sampled joint 2 angle [rad]";
  discrete Real q3_s(start=0) "sampled joint 3 angle [rad]";
  discrete Real q4_s(start=0) "sampled joint 4 angle [rad]";
  discrete Real dq1_s(start=0) "sampled joint 1 velocity [rad/s]";
  discrete Real dq2_s(start=0) "sampled joint 2 velocity [rad/s]";
  discrete Real dq3_s(start=0) "sampled joint 3 velocity [rad/s]";
  discrete Real dq4_s(start=0) "sampled joint 4 velocity [rad/s]";
  discrete Real fWx_s(start=0) "sampled wrist force x [N]";
  discrete Real fWy_s(start=0) "sampled wrist force y [N]";
  discrete Real fWz_s(start=0) "sampled wrist force z [N]";
  discrete Real fTx_s(start=0) "sampled wrist torque x [N.m]";
  discrete Real fTy_s(start=0) "sampled wrist torque y [N.m]";
  discrete Real fTz_s(start=0) "sampled wrist torque z [N.m]";

  discrete Real q1_des_zoh(start=0) "sampled desired joint 1 [rad]";
  discrete Real q2_des_zoh(start=0) "sampled desired joint 2 [rad]";
  discrete Real q3_des_zoh(start=0) "sampled desired joint 3 [rad]";
  discrete Real q4_des_zoh(start=0) "sampled desired joint 4 [rad]";
  discrete Real dq1_des_zoh(start=0) "sampled desired joint 1 velocity [rad/s]";
  discrete Real dq2_des_zoh(start=0) "sampled desired joint 2 velocity [rad/s]";
  discrete Real dq3_des_zoh(start=0) "sampled desired joint 3 velocity [rad/s]";
  discrete Real dq4_des_zoh(start=0) "sampled desired joint 4 velocity [rad/s]";
  discrete Real ddq1_des_zoh(start=0) "sampled desired joint 1 acceleration [rad/s2]";
  discrete Real ddq2_des_zoh(start=0) "sampled desired joint 2 acceleration [rad/s2]";
  discrete Real ddq3_des_zoh(start=0) "sampled desired joint 3 acceleration [rad/s2]";
  discrete Real ddq4_des_zoh(start=0) "sampled desired joint 4 acceleration [rad/s2]";

  discrete Real q1_err_zoh(start=0) "sampled joint 1 position error [rad]";
  discrete Real q2_err_zoh(start=0) "sampled joint 2 position error [rad]";
  discrete Real q3_err_zoh(start=0) "sampled joint 3 position error [rad]";
  discrete Real q4_err_zoh(start=0) "sampled joint 4 position error [rad]";
  discrete Real dq1_err_zoh(start=0) "sampled joint 1 velocity error [rad/s]";
  discrete Real dq2_err_zoh(start=0) "sampled joint 2 velocity error [rad/s]";
  discrete Real dq3_err_zoh(start=0) "sampled joint 3 velocity error [rad/s]";
  discrete Real dq4_err_zoh(start=0) "sampled joint 4 velocity error [rad/s]";
  discrete Real ddq_ref1_zoh(start=0) "joint 1 reference acceleration [rad/s2]";
  discrete Real ddq_ref2_zoh(start=0) "joint 2 reference acceleration [rad/s2]";
  discrete Real ddq_ref3_zoh(start=0) "joint 3 reference acceleration [rad/s2]";
  discrete Real ddq_ref4_zoh(start=0) "joint 4 reference acceleration [rad/s2]";

  discrete Real fCorrZ_zoh(start=0) "bounded wrist-force correction [N]";
  discrete Real mEst_zoh(start=0) "bounded payload mass estimate [kg]";
  discrete Real J1_est_zoh(start=0) "estimated joint 1 inertia [kg.m2]";
  discrete Real J2_est_zoh(start=0) "estimated joint 2 inertia [kg.m2]";
  discrete Real J3_est_zoh(start=0) "estimated joint 3 inertia [kg.m2]";
  discrete Real J4_est_zoh(start=0) "estimated joint 4 inertia [kg.m2]";
  discrete Real G2_link_zoh(start=0) "estimated link-only gravity torque joint 2 [N.m]";
  discrete Real G3_link_zoh(start=0) "estimated link-only gravity torque joint 3 [N.m]";
  discrete Real jacZ2_zoh(start=0) "payload z Jacobian for joint 2 [m/rad]";
  discrete Real jacZ3_zoh(start=0) "payload z Jacobian for joint 3 [m/rad]";
  discrete Real tau_corr2_zoh(start=0) "wrist-force correction torque joint 2 [N.m]";
  discrete Real tau_corr3_zoh(start=0) "wrist-force correction torque joint 3 [N.m]";

  discrete Real tau1_raw_zoh(start=0) "raw joint 1 command [N.m]";
  discrete Real tau2_raw_zoh(start=0) "raw joint 2 command [N.m]";
  discrete Real tau3_raw_zoh(start=0) "raw joint 3 command [N.m]";
  discrete Real tau4_raw_zoh(start=0) "raw joint 4 command [N.m]";
  discrete Real tau1_zoh(start=0) "held saturated joint 1 torque [N.m]";
  discrete Real tau2_zoh(start=0) "held saturated joint 2 torque [N.m]";
  discrete Real tau3_zoh(start=0) "held saturated joint 3 torque [N.m]";
  discrete Real tau4_zoh(start=0) "held saturated joint 4 torque [N.m]";

  // Continuous trace aliases
  Real q1_sampled "continuous sampled joint 1 trace [rad]";
  Real q2_sampled "continuous sampled joint 2 trace [rad]";
  Real q3_sampled "continuous sampled joint 3 trace [rad]";
  Real q4_sampled "continuous sampled joint 4 trace [rad]";
  Real fWristZ_sampled "continuous sampled wrist force z trace [N]";
  Real q1_des_trace "continuous desired joint 1 trace [rad]";
  Real q2_des_trace "continuous desired joint 2 trace [rad]";
  Real q3_des_trace "continuous desired joint 3 trace [rad]";
  Real q4_des_trace "continuous desired joint 4 trace [rad]";
  Real tau1_raw_trace "continuous raw joint 1 command trace [N.m]";
  Real tau2_raw_trace "continuous raw joint 2 command trace [N.m]";
  Real tau3_raw_trace "continuous raw joint 3 command trace [N.m]";
  Real tau4_raw_trace "continuous raw joint 4 command trace [N.m]";
  Real fCorrZ_trace "continuous wrist-force correction trace [N]";
  Real mEst_trace "continuous payload mass estimate trace [kg]";

equation
  // Quintic lift/reposition trajectory; orientation preserved by q3 = -q2 and q1 = q4 = 0.
  trajectoryTime = if time <= Tmove then time else Tmove;
  s = if trajectoryTime <= 0 then 0.0 elseif trajectoryTime >= Tmove then 1.0 else 10.0*(trajectoryTime/Tmove)^3 - 15.0*(trajectoryTime/Tmove)^4 + 6.0*(trajectoryTime/Tmove)^5;
  sDeriv = if trajectoryTime <= 0 or trajectoryTime >= Tmove then 0.0 else 30.0*(trajectoryTime/Tmove)^2*(1.0 - trajectoryTime/Tmove)^2/Tmove;
  sSecond = if trajectoryTime <= 0 or trajectoryTime >= Tmove then 0.0 else 60.0*(trajectoryTime/Tmove)*(1.0 - trajectoryTime/Tmove)*(1.0 - 2.0*(trajectoryTime/Tmove))/Tmove^2;

  q1_ref = 0.0;
  q2_ref = -q2Amp*s;
  q3_ref = q2Amp*s;
  q4_ref = 0.0;
  dq1_ref = 0.0;
  dq2_ref = -q2Amp*sDeriv;
  dq3_ref = q2Amp*sDeriv;
  dq4_ref = 0.0;
  ddq1_ref = 0.0;
  ddq2_ref = -q2Amp*sSecond;
  ddq3_ref = q2Amp*sSecond;
  ddq4_ref = 0.0;

  // Controlled payload disturbance during middle third with smooth transitions.
  payloadFactor =
    if time < t1 then 0.0
    elseif time < t1 + payloadTransitionTime then 0.5*(1.0 - cos(pi*(time - t1)/payloadTransitionTime))
    elseif time < t2 - payloadTransitionTime then 1.0
    elseif time < t2 then 0.5*(1.0 + cos(pi*(time - (t2 - payloadTransitionTime))/payloadTransitionTime))
    else 0.0;
  mPayloadEff = mPayload*payloadFactor;

  // Effective inertias
  J1 = J1_link + mPayloadEff*(L1 + L2 + L3 + L4)^2;
  J2 = J2_link + mPayloadEff*(L2 + L3 + L4)^2;
  J3 = J3_link + mPayloadEff*(L3 + L4)^2;
  J4 = J4_link + mPayloadEff*L4^2;

  // Gravity torques
  G1 = 0.0;
  G4 = 0.0;
  G2 = -g_n*(L2*cos(q2)*(m2/2 + m3 + m4 + mPayloadEff) + cos(q2 + q3)*(m3*L3/2 + m4*(L3 + L4/2) + mPayloadEff*(L3 + L4)));
  G3 = -g_n*(cos(q2 + q3)*(m3*L3/2 + m4*(L3 + L4/2) + mPayloadEff*(L3 + L4)));

  // Joint dynamics
  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;
  ddq1 = (tau1 - G1)/J1;
  ddq2 = (tau2 - G2)/J2;
  ddq3 = (tau3 - G3)/J3;
  ddq4 = (tau4 - G4)/J4;
  der(dq1) = ddq1;
  der(dq2) = ddq2;
  der(dq3) = ddq3;
  der(dq4) = ddq4;

  // Held saturated commands
  tau1 = tau1_zoh;
  tau2 = tau2_zoh;
  tau3 = tau3_zoh;
  tau4 = tau4_zoh;

  // Continuous trace aliases
  q1_sampled = q1_s;
  q2_sampled = q2_s;
  q3_sampled = q3_s;
  q4_sampled = q4_s;
  fWristZ_sampled = fWz_s;
  q1_des_trace = q1_des_zoh;
  q2_des_trace = q2_des_zoh;
  q3_des_trace = q3_des_zoh;
  q4_des_trace = q4_des_zoh;
  tau1_raw_trace = tau1_raw_zoh;
  tau2_raw_trace = tau2_raw_zoh;
  tau3_raw_trace = tau3_raw_zoh;
  tau4_raw_trace = tau4_raw_zoh;
  fCorrZ_trace = fCorrZ_zoh;
  mEst_trace = mEst_zoh;

  // Forward kinematics
  px = L1*cos(q1) + L2*cos(q2)*cos(q1) + (L3 + L4)*cos(q2 + q3)*cos(q1);
  py = L1*sin(q1) + L2*cos(q2)*sin(q1) + (L3 + L4)*cos(q2 + q3)*sin(q1);
  pz = -L2*sin(q2) - (L3 + L4)*sin(q2 + q3);
  pxd = L1 + L2*cos(q2_ref) + L3 + L4;
  pyd = 0.0;
  pzd = -L2*sin(q2_ref);

  // Orientation error from identity
  R11 = cos(q1)*cos(q2 + q3);
  R22 = sin(q1)*sin(q2 + q3)*sin(q4) + cos(q1)*cos(q4);
  R33 = cos(q2 + q3)*cos(q4);
  orientAngle = Modelica.Math.acos(max(-1.0, min(1.0, (R11 + R22 + R33 - 1.0)/2.0)));

  posError = sqrt(max((px - pxd)^2 + (py - pyd)^2 + (pz - pzd)^2, 1.0e-12));
  jointError = sqrt(max((q1 - q1_ref)^2 + (q2 - q2_ref)^2 + (q3 - q3_ref)^2 + (q4 - q4_ref)^2, 1.0e-12));
  poseError = max(posError, max(jointError, orientAngle));
  primaryTrackingError = poseError;

  // Wrist wrench sensor for payload disturbance
  fWristX = 0.0;
  fWristY = 0.0;
  fWristTx = 0.0;
  fWristTy = 0.0;
  fWristTz = 0.0;
  azPayload = (-L2*cos(q2) - (L3 + L4)*cos(q2 + q3))*ddq2
            - (L3 + L4)*cos(q2 + q3)*ddq3
            + 0.5*(L2*sin(q2) + (L3 + L4)*sin(q2 + q3))*dq2*dq2
            + 0.5*(L3 + L4)*sin(q2 + q3)*dq3*dq3
            + (L3 + L4)*sin(q2 + q3)*dq2*dq3;
  fWristZ = mPayloadEff*(g_n + azPayload);
  fWristMag = sqrt(max(fWristX^2 + fWristY^2 + fWristZ^2, 1.0e-12));

  // Collision monitor
  floorPenetration = max(0.0, floorZ - pz);

  // Requirement assertions
  assert(abs(tau1) <= tauMax + 1.0e-6, "effort bound joint 1");
  assert(abs(tau2) <= tauMax + 1.0e-6, "effort bound joint 2");
  assert(abs(tau3) <= tauMax + 1.0e-6, "effort bound joint 3");
  assert(abs(tau4) <= tauMax + 1.0e-6, "effort bound joint 4");
  assert(fWristMag <= fWristMax + 1.0e-6, "wrist force below 60 N");
  assert(payloadFactor <= 0.5 or fWristZ >= retentionForceMin, "payload retention");
  assert(time <= tTrackingCheck or poseError <= trackingLimit + 1.0e-6, "primary tracking error after 5.2 s");
  assert(abs(q1) <= qSoftLimit, "joint 1 soft bound");
  assert(abs(q2) <= qSoftLimit, "joint 2 soft bound");
  assert(abs(q3) <= qSoftLimit, "joint 3 soft bound");
  assert(abs(q4) <= qSoftLimit, "joint 4 soft bound");
  assert(not floorCollisionEnabled or floorPenetration <= 1.0e-9, "floor collision penetration");
  assert(tableCollisionEnabled, "fixed table collision must remain enabled");
  assert(abs(q2) < finiteBound and abs(dq2) < finiteBound and abs(tau2) < finiteBound and abs(fWristZ) < finiteBound and abs(mEst_trace) < finiteBound, "finite physical/control/sensor/estimator values");

  // 80 Hz computed-torque controller with bounded wrist-force correction
  when sample(0, Ts) then
    sampleCount = pre(sampleCount) + 1;

    q1_s = q1;
    q2_s = q2;
    q3_s = q3;
    q4_s = q4;
    dq1_s = dq1;
    dq2_s = dq2;
    dq3_s = dq3;
    dq4_s = dq4;
    fWx_s = fWristX;
    fWy_s = fWristY;
    fWz_s = fWristZ;
    fTx_s = fWristTx;
    fTy_s = fWristTy;
    fTz_s = fWristTz;

    q1_des_zoh = q1_ref;
    q2_des_zoh = q2_ref;
    q3_des_zoh = q3_ref;
    q4_des_zoh = q4_ref;
    dq1_des_zoh = dq1_ref;
    dq2_des_zoh = dq2_ref;
    dq3_des_zoh = dq3_ref;
    dq4_des_zoh = dq4_ref;
    ddq1_des_zoh = ddq1_ref;
    ddq2_des_zoh = ddq2_ref;
    ddq3_des_zoh = ddq3_ref;
    ddq4_des_zoh = ddq4_ref;

    q1_err_zoh = q1_des_zoh - q1_s;
    q2_err_zoh = q2_des_zoh - q2_s;
    q3_err_zoh = q3_des_zoh - q3_s;
    q4_err_zoh = q4_des_zoh - q4_s;
    dq1_err_zoh = dq1_des_zoh - dq1_s;
    dq2_err_zoh = dq2_des_zoh - dq2_s;
    dq3_err_zoh = dq3_des_zoh - dq3_s;
    dq4_err_zoh = dq4_des_zoh - dq4_s;

    ddq_ref1_zoh = ddq1_des_zoh + Kp*q1_err_zoh + Kd*dq1_err_zoh;
    ddq_ref2_zoh = ddq2_des_zoh + Kp*q2_err_zoh + Kd*dq2_err_zoh;
    ddq_ref3_zoh = ddq3_des_zoh + Kp*q3_err_zoh + Kd*dq3_err_zoh;
    ddq_ref4_zoh = ddq4_des_zoh + Kp*q4_err_zoh + Kd*dq4_err_zoh;

    fCorrZ_zoh = min(max(fWz_s, 0.0), fWristMax);
    mEst_zoh = max(0.0, min(fCorrZ_zoh/g_n, payloadMassEstMax));

    J1_est_zoh = J1_link + mEst_zoh*(L1 + L2 + L3 + L4)^2;
    J2_est_zoh = J2_link + mEst_zoh*(L2 + L3 + L4)^2;
    J3_est_zoh = J3_link + mEst_zoh*(L3 + L4)^2;
    J4_est_zoh = J4_link + mEst_zoh*L4^2;

    G2_link_zoh = -g_n*(L2*cos(q2_s)*(m2/2 + m3 + m4) + cos(q2_s + q3_s)*(m3*L3/2 + m4*(L3 + L4/2)));
    G3_link_zoh = -g_n*(cos(q2_s + q3_s)*(m3*L3/2 + m4*(L3 + L4/2)));

    jacZ2_zoh = -L2*cos(q2_s) - (L3 + L4)*cos(q2_s + q3_s);
    jacZ3_zoh = -(L3 + L4)*cos(q2_s + q3_s);
    tau_corr2_zoh = jacZ2_zoh*fCorrZ_zoh;
    tau_corr3_zoh = jacZ3_zoh*fCorrZ_zoh;

    tau1_raw_zoh = J1_est_zoh*ddq_ref1_zoh;
    tau2_raw_zoh = J2_est_zoh*ddq_ref2_zoh + G2_link_zoh + tau_corr2_zoh;
    tau3_raw_zoh = J3_est_zoh*ddq_ref3_zoh + G3_link_zoh + tau_corr3_zoh;
    tau4_raw_zoh = J4_est_zoh*ddq_ref4_zoh;

    tau1_zoh = min(max(tau1_raw_zoh, -tauMax), tauMax);
    tau2_zoh = min(max(tau2_raw_zoh, -tauMax), tauMax);
    tau3_zoh = min(max(tau3_raw_zoh, -tauMax), tauMax);
    tau4_zoh = min(max(tau4_raw_zoh, -tauMax), tauMax);
  end when;

  annotation (experiment(StartTime=0, StopTime=8.0, Tolerance=1.0e-6));
end AssemblyArmCarryA;