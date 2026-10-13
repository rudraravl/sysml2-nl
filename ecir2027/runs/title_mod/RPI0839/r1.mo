model WheelLegRecoverE
  "Floating-base wheeled-leg robot scenario: stand/step in place and recover from a finite lateral push.";

  // Known physical constants
  constant Real g = 9.81 "standard gravity, SI";
  constant Real eps = 1.0e-9 "regularization floor for safe divisors and comparisons";

  // Facts stated by the requirement
  parameter Real m = 28.0 "torso mass, SI";
  parameter Real r = 0.10 "driven wheel radius, SI";
  parameter Real mu = 0.90 "level rigid ground friction coefficient";
  parameter Real tauLim = 60.5 "per-joint torque and command magnitude bound, SI";
  parameter Real Ts = 1.0/250.0 "control and estimator sampling period, SI";
  parameter Real tEnd = 16.0 "run duration, SI";
  parameter Real pushForce = 168.0 "controlled lateral body push force, SI";

  // Placeholder values for facts not stated; they are finite, nonzero, and labelled
  parameter Real pushStart = tEnd/3.0 "middle-third start time";
  parameter Real pushDuration = 50.0*Ts "finite push duration placeholder; exact duration unspecified";
  parameter Real halfWidth = r "unspecified body half-width, scaled to known wheel radius";
  parameter Real halfLength = r "unspecified body half-length, scaled to known wheel radius";
  parameter Real rho0 = 2.0*r "unspecified nominal leg length, scaled to known wheel radius";
  parameter Real J1 = r "unspecified hip lever, scaled to known wheel radius";
  parameter Real J2 = r "unspecified knee lever, scaled to known wheel radius";
  parameter Real Iroll = m*r*r "unspecified roll inertia placeholder";
  parameter Real Ipitch = m*r*r "unspecified pitch inertia placeholder";
  parameter Real Iyaw = m*r*r "unspecified yaw inertia placeholder";
  parameter Real Iq = m*r*r/100.0 "unspecified joint inertia placeholder";
  parameter Real Kq = 100.0 "unspecified joint position gain placeholder";
  parameter Real Dq = 2.0 "unspecified joint damping placeholder";
  parameter Real ky = 20.0*m*g/r "unspecified lateral contact stiffness placeholder";
  parameter Real cy = 2.0*sqrt(m*ky) "unspecified lateral contact damping placeholder";
  parameter Real kc = ky "unspecified normal contact stiffness placeholder";
  parameter Real dc = cy "unspecified normal contact damping placeholder";
  parameter Real Kz = 2000.0 "unspecified height balance gain placeholder";
  parameter Real Dz = 400.0 "unspecified height balance damping placeholder";
  parameter Real Kroll = 600.0 "unspecified roll balance gain placeholder";
  parameter Real Droll = 30.0 "unspecified roll balance damping placeholder";
  parameter Real Kpitch = 600.0 "unspecified pitch balance gain placeholder";
  parameter Real Dpitch = 30.0 "unspecified pitch balance damping placeholder";
  parameter Real alphaEst = 0.98 "unspecified estimator IMU/kinematics blend placeholder";
  parameter Real Nmin = m*g/100.0 "unspecified stance force qualification threshold placeholder";

  // Derived safe parameters
  parameter Real safeR = max(r, eps);
  parameter Real safeDen = max(J1*J1 + J2*J2, eps);
  parameter Real zDes = rho0 + r;
  parameter Real rhoDes = zDes - r;
  parameter Real qDes = (rhoDes - rho0)/(2.0*J1);
  parameter Real FzMax = (tauLim*J1 + tauLim*J2)/safeDen;

  // Leg attachment offsets: 1 front-left, 2 hind-left, 3 front-right, 4 hind-right
  parameter Real aX1 = halfLength;
  parameter Real aY1 = halfWidth;
  parameter Real aX2 = -halfLength;
  parameter Real aY2 = halfWidth;
  parameter Real aX3 = halfLength;
  parameter Real aY3 = -halfWidth;
  parameter Real aX4 = -halfLength;
  parameter Real aY4 = -halfWidth;

  // Floating-base states
  Real x(start=0.0), vx(start=0.0);
  Real y(start=0.0), vy(start=0.0);
  Real z(start=zDes), vz(start=0.0);
  Real roll(start=0.0), omegaRoll(start=0.0);
  Real pitch(start=0.0), omegaPitch(start=0.0);
  Real yaw(start=0.0), omegaYaw(start=0.0);

  // Leg joint states, two joints per leg
  Real qHip1(start=0.0), vqHip1(start=0.0);
  Real qKnee1(start=0.0), vqKnee1(start=0.0);
  Real qHip2(start=0.0), vqHip2(start=0.0);
  Real qKnee2(start=0.0), vqKnee2(start=0.0);
  Real qHip3(start=0.0), vqHip3(start=0.0);
  Real qKnee3(start=0.0), vqKnee3(start=0.0);
  Real qHip4(start=0.0), vqHip4(start=0.0);
  Real qKnee4(start=0.0), vqKnee4(start=0.0);

  // Wheel states
  Real phiWheel1(start=0.0), omegaWheel1;
  Real phiWheel2(start=0.0), omegaWheel2;
  Real phiWheel3(start=0.0), omegaWheel3;
  Real phiWheel4(start=0.0), omegaWheel4;

  // Plant auxiliary variables
  Real pushY;
  Real rho1, vrho1, Fleg1, N1, Ncontact1, pen1, wheelCenterZ1, wheelCenterVZ1;
  Real rho2, vrho2, Fleg2, N2, Ncontact2, pen2, wheelCenterZ2, wheelCenterVZ2;
  Real rho3, vrho3, Fleg3, N3, Ncontact3, pen3, wheelCenterZ3, wheelCenterVZ3;
  Real rho4, vrho4, Fleg4, N4, Ncontact4, pen4, wheelCenterZ4, wheelCenterVZ4;
  Real footXRel1, footYRel1, footZRel1, footVx1, footVy1;
  Real footXRel2, footYRel2, footZRel2, footVx2, footVy2;
  Real footXRel3, footYRel3, footZRel3, footVx3, footVy3;
  Real footXRel4, footYRel4, footZRel4, footVx4, footVy4;
  Real slipY1, slipX1, slipMag1, Fy1, Fx1, Mroll1, Mpitch1, Myaw1;
  Real slipY2, slipX2, slipMag2, Fy2, Fx2, Mroll2, Mpitch2, Myaw2;
  Real slipY3, slipX3, slipMag3, Fy3, Fx3, Mroll3, Mpitch3, Myaw3;
  Real slipY4, slipX4, slipMag4, Fy4, Fx4, Mroll4, Mpitch4, Myaw4;

  // Actuator commands and saturated actual torques
  discrete Real tauHipCmd1(start=m*g*r/4.0);
  discrete Real tauKneeCmd1(start=m*g*r/4.0);
  discrete Real tauHipCmd2(start=m*g*r/4.0);
  discrete Real tauKneeCmd2(start=m*g*r/4.0);
  discrete Real tauHipCmd3(start=m*g*r/4.0);
  discrete Real tauKneeCmd3(start=m*g*r/4.0);
  discrete Real tauHipCmd4(start=m*g*r/4.0);
  discrete Real tauKneeCmd4(start=m*g*r/4.0);
  discrete Real tauWheelCmd1(start=0.0);
  discrete Real tauWheelCmd2(start=0.0);
  discrete Real tauWheelCmd3(start=0.0);
  discrete Real tauWheelCmd4(start=0.0);
  Real tauHipAct1, tauKneeAct1, tauWheelAct1;
  Real tauHipAct2, tauKneeAct2, tauWheelAct2;
  Real tauHipAct3, tauKneeAct3, tauWheelAct3;
  Real tauHipAct4, tauKneeAct4, tauWheelAct4;

  // Contact qualification
  Boolean contactActive1, contactActive2, contactActive3, contactActive4;

  // Estimator states and traces
  discrete Real estRoll(start=0.0);
  discrete Real estPitch(start=0.0);
  discrete Real estYaw(start=0.0);
  discrete Real estZ(start=zDes);
  discrete Real estY(start=0.0);
  discrete Real estX(start=0.0);
  discrete Real estVz(start=0.0);
  discrete Real estOmegaRoll(start=0.0);
  discrete Real estOmegaPitch(start=0.0);
  discrete Real estOmegaYaw(start=0.0);
  Real primaryTrackingError;

  // Controller intermediates
  discrete Real FzBase;
  discrete Real MrollDes, dFroll, MpitchDes, dFpitch;
  discrete Real FzDes1, FzDes2, FzDes3, FzDes4;
  discrete Real rollKin, rollKinValid, pitchKin, pitchKinValid, zKin;
  discrete Real yKin1, yKin2, yKin3, yKin4;

equation
  // Controlled finite-duration lateral body push, placed inside the middle third
  pushY = if time >= pushStart and time < pushStart + pushDuration then pushForce else 0.0;

  // Independent torque saturation for all eight leg joints and four wheel joints
  tauHipAct1 = max(-tauLim, min(tauLim, tauHipCmd1));
  tauKneeAct1 = max(-tauLim, min(tauLim, tauKneeCmd1));
  tauHipAct2 = max(-tauLim, min(tauLim, tauHipCmd2));
  tauKneeAct2 = max(-tauLim, min(tauLim, tauKneeCmd2));
  tauHipAct3 = max(-tauLim, min(tauLim, tauHipCmd3));
  tauKneeAct3 = max(-tauLim, min(tauLim, tauKneeCmd3));
  tauHipAct4 = max(-tauLim, min(tauLim, tauHipCmd4));
  tauKneeAct4 = max(-tauLim, min(tauLim, tauKneeCmd4));
  tauWheelAct1 = max(-tauLim, min(tauLim, tauWheelCmd1));
  tauWheelAct2 = max(-tauLim, min(tauLim, tauWheelCmd2));
  tauWheelAct3 = max(-tauLim, min(tauLim, tauWheelCmd3));
  tauWheelAct4 = max(-tauLim, min(tauLim, tauWheelCmd4));

  // Leg 1: front-left
  rho1 = rho0 + J1*qHip1 + J2*qKnee1;
  vrho1 = J1*vqHip1 + J2*vqKnee1;
  der(qHip1) = vqHip1;
  der(qKnee1) = vqKnee1;
  footXRel1 = aX1 + rho1*pitch;
  footYRel1 = aY1 + rho1*roll;
  footZRel1 = aY1*roll - aX1*pitch - rho1;
  footVx1 = vx + omegaYaw*footYRel1 - omegaPitch*footZRel1;
  footVy1 = vy + vrho1*roll + rho1*omegaRoll - omegaYaw*footXRel1;
  wheelCenterZ1 = z + footZRel1;
  wheelCenterVZ1 = vz + aY1*omegaRoll - aX1*omegaPitch - vrho1;
  pen1 = r - wheelCenterZ1;
  Ncontact1 = max(0.0, kc*pen1 + dc*wheelCenterVZ1);
  Fleg1 = (tauHipAct1*J1 + tauKneeAct1*J2)/safeDen;
  N1 = max(0.0, Fleg1 + Ncontact1);
  contactActive1 = N1 > Nmin;
  slipY1 = y + footYRel1 - aY1;
  slipX1 = 0.0;
  slipMag1 = sqrt(slipY1*slipY1 + slipX1*slipX1 + eps);
  Fy1 = max(-mu*N1, min(mu*N1, -ky*slipY1 - cy*footVy1));
  omegaWheel1 = footVx1/safeR;
  der(phiWheel1) = omegaWheel1;
  Fx1 = max(-mu*N1, min(mu*N1, tauWheelAct1/safeR));
  Mroll1 = footYRel1*N1 - footZRel1*Fy1;
  Mpitch1 = footZRel1*Fx1 - footXRel1*N1;
  Myaw1 = footXRel1*Fy1 - footYRel1*Fx1;
  Iq*der(vqHip1) = tauHipAct1 - Fleg1*J1 - Dq*vqHip1 - Kq*(qHip1 - qDes);
  Iq*der(vqKnee1) = tauKneeAct1 - Fleg1*J2 - Dq*vqKnee1 - Kq*(qKnee1 - qDes);

  // Leg 2: hind-left
  rho2 = rho0 + J1*qHip2 + J2*qKnee2;
  vrho2 = J1*vqHip2 + J2*vqKnee2;
  der(qHip2) = vqHip2;
  der(qKnee2) = vqKnee2;
  footXRel2 = aX2 + rho2*pitch;
  footYRel2 = aY2 + rho2*roll;
  footZRel2 = aY2*roll - aX2*pitch - rho2;
  footVx2 = vx + omegaYaw*footYRel2 - omegaPitch*footZRel2;
  footVy2 = vy + vrho2*roll + rho2*omegaRoll - omegaYaw*footXRel2;
  wheelCenterZ2 = z + footZRel2;
  wheelCenterVZ2 = vz + aY2*omegaRoll - aX2*omegaPitch - vrho2;
  pen2 = r - wheelCenterZ2;
  Ncontact2 = max(0.0, kc*pen2 + dc*wheelCenterVZ2);
  Fleg2 = (tauHipAct2*J1 + tauKneeAct2*J2)/safeDen;
  N2 = max(0.0, Fleg2 + Ncontact2);
  contactActive2 = N2 > Nmin;
  slipY2 = y + footYRel2 - aY2;
  slipX2 = 0.0;
  slipMag2 = sqrt(slipY2*slipY2 + slipX2*slipX2 + eps);
  Fy2 = max(-mu*N2, min(mu*N2, -ky*slipY2 - cy*footVy2));
  omegaWheel2 = footVx2/safeR;
  der(phiWheel2) = omegaWheel2;
  Fx2 = max(-mu*N2, min(mu*N2, tauWheelAct2/safeR));
  Mroll2 = footYRel2*N2 - footZRel2*Fy2;
  Mpitch2 = footZRel2*Fx2 - footXRel2*N2;
  Myaw2 = footXRel2*Fy2 - footYRel2*Fx2;
  Iq*der(vqHip2) = tauHipAct2 - Fleg2*J1 - Dq*vqHip2 - Kq*(qHip2 - qDes);
  Iq*der(vqKnee2) = tauKneeAct2 - Fleg2*J2 - Dq*vqKnee2 - Kq*(qKnee2 - qDes);

  // Leg 3: front-right
  rho3 = rho0 + J1*qHip3 + J2*qKnee3;
  vrho3 = J1*vqHip3 + J2*vqKnee3;
  der(qHip3) = vqHip3;
  der(qKnee3) = vqKnee3;
  footXRel3 = aX3 + rho3*pitch;
  footYRel3 = aY3 + rho3*roll;
  footZRel3 = aY3*roll - aX3*pitch - rho3;
  footVx3 = vx + omegaYaw*footYRel3 - omegaPitch*footZRel3;
  footVy3 = vy + vrho3*roll + rho3*omegaRoll - omegaYaw*footXRel3;
  wheelCenterZ3 = z + footZRel3;
  wheelCenterVZ3 = vz + aY3*omegaRoll - aX3*omegaPitch - vrho3;
  pen3 = r - wheelCenterZ3;
  Ncontact3 = max(0.0, kc*pen3 + dc*wheelCenterVZ3);
  Fleg3 = (tauHipAct3*J1 + tauKneeAct3*J2)/safeDen;
  N3 = max(0.0, Fleg3 + Ncontact3);
  contactActive3 = N3 > Nmin;
  slipY3 = y + footYRel3 - aY3;
  slipX3 = 0.0;
  slipMag3 = sqrt(slipY3*slipY3 + slipX3*slipX3 + eps);
  Fy3 = max(-mu*N3, min(mu*N3, -ky*slipY3 - cy*footVy3));
  omegaWheel3 = footVx3/safeR;
  der(phiWheel3) = omegaWheel3;
  Fx3 = max(-mu*N3, min(mu*N3, tauWheelAct3/safeR));
  Mroll3 = footYRel3*N3 - footZRel3*Fy3;
  Mpitch3 = footZRel3*Fx3 - footXRel3*N3;
  Myaw3 = footXRel3*Fy3 - footYRel3*Fx3;
  Iq*der(vqHip3) = tauHipAct3 - Fleg3*J1 - Dq*vqHip3 - Kq*(qHip3 - qDes);
  Iq*der(vqKnee3) = tauKneeAct3 - Fleg3*J2 - Dq*vqKnee3 - Kq*(qKnee3 - qDes);

  // Leg 4: hind-right
  rho4 = rho0 + J1*qHip4 + J2*qKnee4;
  vrho4 = J1*vqHip4 + J2*vqKnee4;
  der(qHip4) = vqHip4;
  der(qKnee4) = vqKnee4;
  footXRel4 = aX4 + rho4*pitch;
  footYRel4 = aY4 + rho4*roll;
  footZRel4 = aY4*roll - aX4*pitch - rho4;
  footVx4 = vx + omegaYaw*footYRel4 - omegaPitch*footZRel4;
  footVy4 = vy + vrho4*roll + rho4*omegaRoll - omegaYaw*footXRel4;
  wheelCenterZ4 = z + footZRel4;
  wheelCenterVZ4 = vz + aY4*omegaRoll - aX4*omegaPitch - vrho4;
  pen4 = r - wheelCenterZ4;
  Ncontact4 = max(0.0, kc*pen4 + dc*wheelCenterVZ4);
  Fleg4 = (tauHipAct4*J1 + tauKneeAct4*J2)/safeDen;
  N4 = max(0.0, Fleg4 + Ncontact4);
  contactActive4 = N4 > Nmin;
  slipY4 = y + footYRel4 - aY4;
  slipX4 = 0.0;
  slipMag4 = sqrt(slipY4*slipY4 + slipX4*slipX4 + eps);
  Fy4 = max(-mu*N4, min(mu*N4, -ky*slipY4 - cy*footVy4));
  omegaWheel4 = footVx4/safeR;
  der(phiWheel4) = omegaWheel4;
  Fx4 = max(-mu*N4, min(mu*N4, tauWheelAct4/safeR));
  Mroll4 = footYRel4*N4 - footZRel4*Fy4;
  Mpitch4 = footZRel4*Fx4 - footXRel4*N4;
  Myaw4 = footXRel4*Fy4 - footYRel4*Fx4;
  Iq*der(vqHip4) = tauHipAct4 - Fleg4*J1 - Dq*vqHip4 - Kq*(qHip4 - qDes);
  Iq*der(vqKnee4) = tauKneeAct4 - Fleg4*J2 - Dq*vqKnee4 - Kq*(qKnee4 - qDes);

  // Floating-base Newton-Euler equations
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(roll) = omegaRoll;
  der(pitch) = omegaPitch;
  der(yaw) = omegaYaw;
  m*der(vx) = Fx1 + Fx2 + Fx3 + Fx4;
  m*der(vy) = Fy1 + Fy2 + Fy3 + Fy4 + pushY;
  m*der(vz) = N1 + N2 + N3 + N4 - m*g;
  Iroll*der(omegaRoll) = Mroll1 + Mroll2 + Mroll3 + Mroll4;
  Ipitch*der(omegaPitch) = Mpitch1 + Mpitch2 + Mpitch3 + Mpitch4;
  Iyaw*der(omegaYaw) = Myaw1 + Myaw2 + Myaw3 + Myaw4;

  // Observable primary acceptance metric
  primaryTrackingError = abs(estRoll);

  // Fail-closed acceptance assertions
  assert(abs(tauHipCmd1) <= tauLim + eps, "command bound violated: hip1");
  assert(abs(tauKneeCmd1) <= tauLim + eps, "command bound violated: knee1");
  assert(abs(tauHipCmd2) <= tauLim + eps, "command bound violated: hip2");
  assert(abs(tauKneeCmd2) <= tauLim + eps, "command bound violated: knee2");
  assert(abs(tauHipCmd3) <= tauLim + eps, "command bound violated: hip3");
  assert(abs(tauKneeCmd3) <= tauLim + eps, "command bound violated: knee3");
  assert(abs(tauHipCmd4) <= tauLim + eps, "command bound violated: hip4");
  assert(abs(tauKneeCmd4) <= tauLim + eps, "command bound violated: knee4");
  assert(abs(tauWheelCmd1) <= tauLim + eps, "command bound violated: wheel1");
  assert(abs(tauWheelCmd2) <= tauLim + eps, "command bound violated: wheel2");
  assert(abs(tauWheelCmd3) <= tauLim + eps, "command bound violated: wheel3");
  assert(abs(tauWheelCmd4) <= tauLim + eps, "command bound violated: wheel4");

  assert(abs(tauHipAct1) <= tauLim + eps, "torque bound violated: hip1");
  assert(abs(tauKneeAct1) <= tauLim + eps, "torque bound violated: knee1");
  assert(abs(tauHipAct2) <= tauLim + eps, "torque bound violated: hip2");
  assert(abs(tauKneeAct2) <= tauLim + eps, "torque bound violated: knee2");
  assert(abs(tauHipAct3) <= tauLim + eps, "torque bound violated: hip3");
  assert(abs(tauKneeAct3) <= tauLim + eps, "torque bound violated: knee3");
  assert(abs(tauHipAct4) <= tauLim + eps, "torque bound violated: hip4");
  assert(abs(tauKneeAct4) <= tauLim + eps, "torque bound violated: knee4");
  assert(abs(tauWheelAct1) <= tauLim + eps, "torque bound violated: wheel1");
  assert(abs(tauWheelAct2) <= tauLim + eps, "torque bound violated: wheel2");
  assert(abs(tauWheelAct3) <= tauLim + eps, "torque bound violated: wheel3");
  assert(abs(tauWheelAct4) <= tauLim + eps, "torque bound violated: wheel4");

  assert(z > eps, "positive body height violated");
  assert(slipMag1 <= 0.03 + eps, "foot slip limit violated: wheel1");
  assert(slipMag2 <= 0.03 + eps, "foot slip limit violated: wheel2");
  assert(slipMag3 <= 0.03 + eps, "foot slip limit violated: wheel3");
  assert(slipMag4 <= 0.03 + eps, "foot slip limit violated: wheel4");
  assert(time <= 10.4 or primaryTrackingError < 0.108, "primary tracking error acceptance violated after 10.4 s");

  // Finite-value checks for physical, control, and estimator traces
  assert(abs(x) < 1.0e6, "finite check failed: x");
  assert(abs(y) < 1.0e6, "finite check failed: y");
  assert(abs(z) < 1.0e6, "finite check failed: z");
  assert(abs(roll) < 1.0e6, "finite check failed: roll");
  assert(abs(pitch) < 1.0e6, "finite check failed: pitch");
  assert(abs(yaw) < 1.0e6, "finite check failed: yaw");
  assert(abs(tauHipAct1) < 1.0e6, "finite check failed: tauHipAct1");
  assert(abs(tauKneeAct1) < 1.0e6, "finite check failed: tauKneeAct1");
  assert(abs(tauWheelAct1) < 1.0e6, "finite check failed: tauWheelAct1");
  assert(abs(estRoll) < 1.0e6, "finite check failed: estRoll");
  assert(abs(estZ) < 1.0e6, "finite check failed: estZ");
  assert(abs(primaryTrackingError) < 1.0e6, "finite check failed: primaryTrackingError");

  when time >= tEnd then
    terminate("16 s run completed");
  end when;

algorithm
  when sample(0, Ts) then
    // Whole-body balance control with contact switching
    FzBase := (m*g + Kz*(zDes - z) - Dz*vz)/4.0;
    MrollDes := -Kroll*roll - Droll*omegaRoll;
    dFroll := MrollDes/(4.0*max(halfWidth, eps));
    MpitchDes := -Kpitch*pitch - Dpitch*omegaPitch;
    dFpitch := MpitchDes/(4.0*max(halfLength, eps));

    FzDes1 := FzBase + dFroll + dFpitch;
    FzDes2 := FzBase + dFroll - dFpitch;
    FzDes3 := FzBase - dFroll + dFpitch;
    FzDes4 := FzBase - dFroll - dFpitch;

    if N1 > Nmin then
      FzDes1 := max(0.0, min(FzMax, FzDes1));
    else
      FzDes1 := 0.0;
    end if;
    if N2 > Nmin then
      FzDes2 := max(0.0, min(FzMax, FzDes2));
    else
      FzDes2 := 0.0;
    end if;
    if N3 > Nmin then
      FzDes3 := max(0.0, min(FzMax, FzDes3));
    else
      FzDes3 := 0.0;
    end if;
    if N4 > Nmin then
      FzDes4 := max(0.0, min(FzMax, FzDes4));
    else
      FzDes4 := 0.0;
    end if;

    tauHipCmd1 := max(-tauLim, min(tauLim, FzDes1*safeDen/(2.0*J1) + Kq*(qDes - qHip1) - Dq*vqHip1));
    tauKneeCmd1 := max(-tauLim, min(tauLim, FzDes1*safeDen/(2.0*J2) + Kq*(qDes - qKnee1) - Dq*vqKnee1));
    tauHipCmd2 := max(-tauLim, min(tauLim, FzDes2*safeDen/(2.0*J1) + Kq*(qDes - qHip2) - Dq*vqHip2));
    tauKneeCmd2 := max(-tauLim, min(tauLim, FzDes2*safeDen/(2.0*J2) + Kq*(qDes - qKnee2) - Dq*vqKnee2));
    tauHipCmd3 := max(-tauLim, min(tauLim, FzDes3*safeDen/(2.0*J1) + Kq*(qDes - qHip3) - Dq*vqHip3));
    tauKneeCmd3 := max(-tauLim, min(tauLim, FzDes3*safeDen/(2.0*J2) + Kq*(qDes - qKnee3) - Dq*vqKnee3));
    tauHipCmd4 := max(-tauLim, min(tauLim, FzDes4*safeDen/(2.0*J1) + Kq*(qDes - qHip4) - Dq*vqHip4));
    tauKneeCmd4 := max(-tauLim, min(tauLim, FzDes4*safeDen/(2.0*J2) + Kq*(qDes - qKnee4) - Dq*vqKnee4));

    // Wheel torque commands remain zero for stand/step-in-place; rolling locomotion is structurally represented
    tauWheelCmd1 := 0.0;
    tauWheelCmd2 := 0.0;
    tauWheelCmd3 := 0.0;
    tauWheelCmd4 := 0.0;

    // Base pose estimator: IMU rates, leg kinematics, and force-qualified stance contacts
    estOmegaRoll := omegaRoll;
    estOmegaPitch := omegaPitch;
    estOmegaYaw := omegaYaw;

    rollKin := ((rho3 + rho4) - (rho1 + rho2))/(4.0*max(halfWidth, eps));
    pitchKin := ((rho1 + rho3) - (rho2 + rho4))/(4.0*max(halfLength, eps));
    zKin := r + (rho1 + rho2 + rho3 + rho4)/4.0;

    if contactActive1 or contactActive2 or contactActive3 or contactActive4 then
      rollKinValid := rollKin;
      pitchKinValid := pitchKin;
      zKin := r + (rho1 + rho2 + rho3 + rho4)/4.0;
    else
      rollKinValid := pre(estRoll);
      pitchKinValid := pre(estPitch);
      zKin := pre(estZ);
    end if;

    estRoll := alphaEst*(pre(estRoll) + Ts*estOmegaRoll) + (1.0 - alphaEst)*rollKinValid;
    estPitch := alphaEst*(pre(estPitch) + Ts*estOmegaPitch) + (1.0 - alphaEst)*pitchKinValid;
    estYaw := pre(estYaw) + Ts*estOmegaYaw;
    estZ := alphaEst*(pre(estZ) + Ts*pre(estVz)) + (1.0 - alphaEst)*zKin;
    estVz := vz;

    if contactActive1 then
      yKin1 := aY1 - (aY1 + rho1*estRoll);
    else
      yKin1 := pre(estY);
    end if;
    if contactActive2 then
      yKin2 := aY2 - (aY2 + rho2*estRoll);
    else
      yKin2 := pre(estY);
    end if;
    if contactActive3 then
      yKin3 := aY3 - (aY3 + rho3*estRoll);
    else
      yKin3 := pre(estY);
    end if;
    if contactActive4 then
      yKin4 := aY4 - (aY4 + rho4*estRoll);
    else
      yKin4 := pre(estY);
    end if;

    estY := (yKin1 + yKin2 + yKin3 + yKin4)/4.0;
    estX := pre(estX) + Ts*r*(omegaWheel1 + omegaWheel2 + omegaWheel3 + omegaWheel4)/4.0;
  end when;
end WheelLegRecoverE;