model MonoHopWalkC
  // Stated physical parameters
  parameter Real m = 10.0 "body mass [kg]";
  parameter Real k = 15000.0 "leg axial spring [N/m]";
  parameter Real c = 170.0 "leg axial damper [N.s/m]";
  parameter Real rMin = 0.30 "minimum telescoping leg length [m]";
  parameter Real rMax = 0.60 "maximum telescoping leg length [m]";
  parameter Real mu = 0.85 "rigid plane friction coefficient";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real Fmax = 874.0 "maximum command magnitude [N]";
  parameter Real Fpush = 63.0 "body push disturbance [N]";
  parameter Real vRef = 0.4 "forward gait reference [m/s]";
  parameter Real Ts = 0.008 "control and sensor sample period [s]";

  // Unspecified but finite compile-time placeholders; facts not stated in request
  parameter Real rFoot = 0.02 "spherical foot radius [m]";
  parameter Real J_body = 0.20 "body pitch inertia [kg.m2]";
  parameter Real rRest = 0.55 "leg spring rest length [m]";
  parameter Real hNom = 0.515 "nominal body height [m]";
  parameter Real kStop = 100000.0 "leg stop stiffness [N/m]";
  parameter Real qPhaseAmp = 0.005 "phase joint swing amplitude [rad]";
  parameter Real F_hop = 5.0 "hopping energy injection amplitude [N]";
  parameter Real qBound = 0.60 "joint/leg angle bound [rad]";

  // Controller gains
  parameter Real Kp_v = 1000.0 "forward velocity gain [N.s/m]";
  parameter Real Kp_z = 1000.0 "height gain [N/m]";
  parameter Real Kd_z = 100.0 "height damping gain [N.s/m]";
  parameter Real Tq = 0.05 "joint angle servo time constant [s]";
  parameter Real zetaQ = 1.0 "joint angle servo damping ratio";
  parameter Real Kp_q = 20.0 "joint impedance gain [N.m/rad]";
  parameter Real Kd_q = 5.0 "joint impedance damping [N.m.s/rad]";
  parameter Real Kp_theta = 100.0 "body attitude gain [N.m/rad]";
  parameter Real Kd_theta = 20.0 "body attitude damping [N.m.s/rad]";
  parameter Real tauMax = 262.2 "joint torque bound [N.m]";

  // Continuous states
  Real x(start=0, fixed=true) "forward position [m]";
  Real vx(start=0.4, fixed=true) "forward velocity [m/s]";
  Real z(start=0.515, fixed=true) "body height [m]";
  Real vz(start=0, fixed=true) "vertical velocity [m/s]";
  Real theta(start=0, fixed=true) "torso pitch [rad]";
  Real omega(start=0, fixed=true) "torso pitch rate [rad/s]";
  Real phi(start=0, fixed=true) "absolute leg angle [rad]";
  Real phidot(start=0, fixed=true) "leg angular rate [rad/s]";

  // Outputs
  output Real Fcmd "bounded leg actuator command [N]";
  output Real tauCmd "bounded joint torque command [N.m]";
  output Real r "leg length [m]";
  output Real N "foot normal contact force [N]";
  output Real Fx "foot tangential contact force [N]";
  output Real contactCount "supporting contact count";
  output Real trackingError "primary tracking error [m/s]";
  output Real trackingErrorMet "1.0 if requirement met else 0.0";
  output Real Fdist "body push disturbance [N]";
  output Real q "joint encoder angle [rad]";

  // Sampled 125 Hz sensor and command traces
  discrete Real sensorTime(start=0);
  discrete Real sensorX(start=0);
  discrete Real sensorVx(start=0.4);
  discrete Real sensorZ(start=0.515);
  discrete Real sensorVz(start=0);
  discrete Real sensorTheta(start=0);
  discrete Real sensorOmega(start=0);
  discrete Real sensorPhi(start=0);
  discrete Real sensorR(start=0.495);
  discrete Real sensorQ(start=0);
  discrete Real sensorN(start=98.1);
  discrete Real sensorFx(start=0);
  discrete Real sensorContact(start=1);
  discrete Real sensorFcmd(start=-726.9);
  discrete Real sensorTau(start=0);
  discrete Real sensorFdist(start=0);
  discrete Real sensorPhase(start=0);
  discrete Real sensorTrackingError(start=0);

  // Intermediate variables
  Real cosPhi;
  Real sinPhi;
  Real phase;
  Real omegaHop;
  Real Fspring;
  Real Fstop;
  Real FcmdRaw;
  Real Faxial;
  Real FxUnlim;
  Real FxDes;
  Real phiDesRaw;
  Real phiDesTotal;
  Real qDes;
  Real qdot;
  Real qErr;
  Real tauRaw;
  Real rdot;
  Real hLeg;
  Real cosPhiSafe;

equation
  // Gait phase generator
  omegaHop = sqrt(k / m);
  phase = mod(omegaHop * time, 6.283185307179586);

  // Controlled body push during middle third of 12 s run
  Fdist = if time >= 4.0 and time <= 8.0 then Fpush else 0.0;

  // Leg geometry with safe divisor
  cosPhi = cos(phi);
  sinPhi = sin(phi);
  hLeg = z - rFoot;
  cosPhiSafe = max(cosPhi, 0.01);
  r = hLeg / cosPhiSafe;
  rdot = (vz * cosPhiSafe + hLeg * sinPhi * phidot) / (cosPhiSafe * cosPhiSafe);

  // Telescoping leg spring, damper, and hard stops
  Fspring = k * (rRest - r) - c * rdot;
  Fstop = noEvent(if r < rMin then kStop * (rMin - r) elseif r > rMax then kStop * (rMax - r) else 0.0);

  // Bounded linear leg actuator with height feedforward and hopping injection
  FcmdRaw = m * g / cosPhiSafe - k * (rRest - r) + Kp_z * (hNom - z) - Kd_z * vz + F_hop * sin(phase);
  Fcmd = max(-Fmax, min(Fmax, FcmdRaw));
  Faxial = Fspring + Fcmd + Fstop;

  // Foot contact-force sensor and friction-limited tangential force
  N = max(0.0, Faxial * cosPhi);
  FxUnlim = -Faxial * sinPhi;
  Fx = noEvent(if N > 1e-6 then (if abs(FxUnlim) <= mu * N then FxUnlim else mu * N * sign(FxUnlim)) else 0.0);
  contactCount = if N > 1e-6 then 1.0 else 0.0;

  // Floating-base translational dynamics
  der(x) = vx;
  der(vx) = (Fx + Fdist) / m;
  der(z) = vz;
  der(vz) = (Faxial * cosPhi - m * g) / m;

  // Body-attitude dynamics driven by bounded joint torque
  der(theta) = omega;
  der(omega) = -tauCmd / J_body;

  // Phase-based joint impedance and forward-gait foot placement
  FxDes = Kp_v * (vRef - vx);
  phiDesRaw = -atan(FxDes / (m * g));
  phiDesTotal = max(-qBound, min(qBound, phiDesRaw + qPhaseAmp * sin(phase)));
  qDes = phiDesTotal;
  der(phi) = phidot;
  der(phidot) = (phiDesTotal - phi) / (Tq * Tq) - 2.0 * zetaQ / Tq * phidot;

  // Joint encoder, impedance error, and bounded torque
  q = phi - theta;
  qdot = phidot - omega;
  qErr = qDes - q;
  tauRaw = Kp_q * qErr - Kd_q * qdot + Kp_theta * theta + Kd_theta * omega;
  tauCmd = max(-tauMax, min(tauMax, tauRaw));

  // Evidence and requirements
  trackingError = abs(vx - vRef);
  trackingErrorMet = if time < 7.8 then 1.0 elseif trackingError < 0.105 then 1.0 else 0.0;

  // Bounds verification
  assert(abs(Fcmd) <= Fmax + 1e-6, "leg actuator command bound violated");
  assert(abs(tauCmd) <= tauMax + 1e-6, "joint torque command bound violated");
  assert(contactCount >= 0.0 and contactCount <= 1.0, "invalid contact count");
  assert(time < 7.8 or trackingError < 0.105, "primary tracking error requirement violated after 7.8 s");

  // Synchronized 125 Hz sampled traces
  when sample(0, Ts) then
    sensorTime = time;
    sensorX = x;
    sensorVx = vx;
    sensorZ = z;
    sensorVz = vz;
    sensorTheta = theta;
    sensorOmega = omega;
    sensorPhi = phi;
    sensorR = r;
    sensorQ = q;
    sensorN = N;
    sensorFx = Fx;
    sensorContact = contactCount;
    sensorFcmd = Fcmd;
    sensorTau = tauCmd;
    sensorFdist = Fdist;
    sensorPhase = phase;
    sensorTrackingError = trackingError;
  end when;

  annotation(experiment(StartTime=0, StopTime=12, Interval=0.008, Tolerance=1e-6));
end MonoHopWalkC;