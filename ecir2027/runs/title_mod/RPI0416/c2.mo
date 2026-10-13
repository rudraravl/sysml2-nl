model PlanarPusherInsertB
  // Geometry stated by the mission
  parameter Modelica.Units.SI.Length L1 = 0.46 "first capsule link length";
  parameter Modelica.Units.SI.Length L2 = 0.35 "second capsule link length";
  parameter Modelica.Units.SI.Length clearance = 0.001 "hole radial clearance";
  parameter Modelica.Units.SI.Length depthReq = 0.06 "required insertion depth";
  parameter Modelica.Units.SI.Torque tauMax = 41.0 "allowed joint-torque command magnitude";
  parameter Real mu = 0.35 "contact friction coefficient";
  parameter Modelica.Units.SI.Force Fdist = 7.0 "controlled lateral fixture load disturbance";
  parameter Modelica.Units.SI.Time tDistStart = 10.0/3.0 "middle third start";
  parameter Modelica.Units.SI.Time tDistEnd = 20.0/3.0 "middle third end";

  // Hole placement and motion schedule are not specified by the requirement.
  // Values below are selected only to keep the insertion target reachable by the stated links.
  parameter Modelica.Units.SI.Length xHole = 0.60 "hole mouth x-location";
  parameter Modelica.Units.SI.Length xHold0 = 0.56 "initial held x set-point";
  parameter Modelica.Units.SI.Time tHold = 2.0 "alignment hold end";
  parameter Modelica.Units.SI.Time tApp = 5.0 "approach end";
  parameter Modelica.Units.SI.Time tIns = 8.0 "insertion end";
  parameter Modelica.Units.SI.Velocity insertionSpeedLimit = 0.02 "bounded insertion speed";

  // Inertial properties are not specified; these are representative placeholders.
  parameter Modelica.Units.SI.Mass mLink1 = 1.2 "lumped first-link mass";
  parameter Modelica.Units.SI.Mass mLink2 = 0.8 "lumped second-link mass";
  parameter Modelica.Units.SI.Mass mPeg = 0.3 "peg and rounded contact-tool mass";
  parameter Modelica.Units.SI.Mass mp = mLink2 + mPeg "mass at end effector";
  parameter Modelica.Units.SI.Inertia I1 = 0.02 "first link rotational inertia";
  parameter Modelica.Units.SI.Inertia I2 = 0.01 "second link rotational inertia";
  parameter Real dJoint = 0.2 "joint damping (N.m.s/rad)";

  // Rigid collision regularization; high stiffness approximates rigid peg/fixture contact.
  parameter Real kLat = 2.0e5 "contact normal stiffness (N/m)";
  parameter Real dLat = 300.0 "contact normal damping (N.s/m)";
  parameter Modelica.Units.SI.Velocity vEps = 0.01 "friction velocity smoothing";

  // Force limits are required but not numerically specified; placeholders selected conservatively.
  parameter Modelica.Units.SI.Force FaxLimit = 25.0 "axial force limit";
  parameter Modelica.Units.SI.Force FlatLimit = 20.0 "lateral force limit";
  parameter Real tiltLimit(unit="rad") = 0.05 "peg tilt limit placeholder";
  parameter Modelica.Units.SI.Length trackingThreshold = 0.002 "primary alignment error threshold";

  // Cartesian impedance gains
  parameter Real Kpx = 4000.0 "axial stiffness (N/m)";
  parameter Real Kdx = 120.0 "axial damping (N.s/m)";
  parameter Real Kpy = 8000.0 "lateral stiffness (N/m)";
  parameter Real Kdy = 200.0 "lateral damping (N.s/m)";
  parameter Real Kphi = 150.0 "orientation stiffness (N.m/rad)";
  parameter Real Dphi = 15.0 "orientation damping (N.m.s/rad)";

  // Initial configuration
  parameter Modelica.Units.SI.Angle q1_start = 1.0 "initial joint 1 angle";
  parameter Modelica.Units.SI.Angle q2_start = -0.9 "initial joint 2 angle";

  // Sampling and traces
  constant Integer Nsamp = 1001 "100 Hz for 10 s inclusive";
  parameter Modelica.Units.SI.Time Ts = 0.01 "trace sampling period";
  constant Real eps = 1.0e-12;

  // States
  Modelica.Units.SI.Angle q1(start = q1_start, fixed = true);
  Modelica.Units.SI.Angle q2(start = q2_start, fixed = true);
  Modelica.Units.SI.AngularVelocity qd1(start = 0.0, fixed = true);
  Modelica.Units.SI.AngularVelocity qd2(start = 0.0, fixed = true);
  Modelica.Units.SI.AngularAcceleration qdd1;
  Modelica.Units.SI.AngularAcceleration qdd2;

  // Kinematics and sensing
  Modelica.Units.SI.Length x "end-effector/peg x";
  Modelica.Units.SI.Length y "end-effector/peg y";
  Modelica.Units.SI.Velocity x_dot;
  Modelica.Units.SI.Velocity y_dot;
  Modelica.Units.SI.Angle phi "peg orientation";
  Modelica.Units.SI.AngularVelocity phi_dot;
  Real J11;
  Real J12;
  Real J21;
  Real J22;

  // Dynamics
  Real M11;
  Real M12;
  Real M22;
  Real h;
  Real detM;
  Real detM_safe;
  Modelica.Units.SI.Torque C1;
  Modelica.Units.SI.Torque C2;
  Modelica.Units.SI.Torque rhs1;
  Modelica.Units.SI.Torque rhs2;
  Modelica.Units.SI.Torque tau_ext1;
  Modelica.Units.SI.Torque tau_ext2;
  Modelica.Units.SI.Torque tau1;
  Modelica.Units.SI.Torque tau2;
  Modelica.Units.SI.Torque tau1_raw;
  Modelica.Units.SI.Torque tau2_raw;
  Modelica.Units.SI.Torque tau_phi_raw;
  Modelica.Units.SI.Torque tau_phi_cmd;

  // Control
  Modelica.Units.SI.Length x_d;
  Modelica.Units.SI.Length y_d;
  Modelica.Units.SI.Angle phi_d;
  Modelica.Units.SI.Velocity xd_d;
  Modelica.Units.SI.Angle e_phi;
  Modelica.Units.SI.Force Fx_raw;
  Modelica.Units.SI.Force Fy_raw;
  Modelica.Units.SI.Force Fx_cmd;
  Modelica.Units.SI.Force Fy_cmd;

  // Contact and disturbance
  Boolean inHoleRegion;
  Modelica.Units.SI.Length pen;
  Real sL;
  Modelica.Units.SI.Velocity vNormal;
  Modelica.Units.SI.Force N;
  Modelica.Units.SI.Force F_contact_y;
  Modelica.Units.SI.Force F_axial_contact;
  Modelica.Units.SI.Force F_dist_y;
  Modelica.Units.SI.Force F_ext_x;
  Modelica.Units.SI.Force F_ext_y;

  // Six-axis contact wrench measurement
  Modelica.Units.SI.Force wrenchFx;
  Modelica.Units.SI.Force wrenchFy;
  Modelica.Units.SI.Force wrenchFz;
  Modelica.Units.SI.Torque wrenchMx;
  Modelica.Units.SI.Torque wrenchMy;
  Modelica.Units.SI.Torque wrenchMz;

  // Mission monitors
  Modelica.Units.SI.Length insertionDepth;
  Modelica.Units.SI.Angle tilt;
  Modelica.Units.SI.Length primaryTrackingError;
  Boolean actuatorBoundsOk;
  Boolean forceLimitsOk;
  Boolean tiltOk;
  Boolean depthOk;
  Boolean trackingOk;
  Boolean insertionSpeedBounded;
  Boolean noJamming;
  Boolean missionOk;

  // Synchronized 100 Hz traces
  Integer sampleIndex(start = 0);
  Real traceTime[Nsamp];
  Real traceQ1[Nsamp];
  Real traceQ2[Nsamp];
  Real traceQd1[Nsamp];
  Real traceQd2[Nsamp];
  Real traceX[Nsamp];
  Real traceY[Nsamp];
  Real tracePhi[Nsamp];
  Real traceDepth[Nsamp];
  Real traceTau1[Nsamp];
  Real traceTau2[Nsamp];
  Real traceFx_cmd[Nsamp];
  Real traceFy_cmd[Nsamp];
  Real traceWrenchFx[Nsamp];
  Real traceWrenchFy[Nsamp];
  Real traceWrenchFz[Nsamp];
  Real traceWrenchMx[Nsamp];
  Real traceWrenchMy[Nsamp];
  Real traceWrenchMz[Nsamp];
  Real traceTilt[Nsamp];
  Real traceAlignErr[Nsamp];

equation
  // Planar two-link kinematics on revolute Z joints
  phi = q1 + q2;
  x = L1*cos(q1) + L2*cos(phi);
  y = L1*sin(q1) + L2*sin(phi);
  phi_dot = qd1 + qd2;
  x_dot = -L1*sin(q1)*qd1 - L2*sin(phi)*phi_dot;
  y_dot = L1*cos(q1)*qd1 + L2*cos(phi)*phi_dot;

  // Jacobian
  J11 = -L1*sin(q1) - L2*sin(phi);
  J12 = -L2*sin(phi);
  J21 = L1*cos(q1) + L2*cos(phi);
  J22 = L2*cos(phi);

  // Cartesian impedance trajectory with bounded insertion speed
  x_d = if time < tHold then xHold0
        elseif time < tApp then xHold0 + (xHole - xHold0)*(time - tHold)/(tApp - tHold)
        elseif time < tIns then xHole + depthReq*(time - tApp)/(tIns - tApp)
        else xHole + depthReq;
  xd_d = if time < tHold then 0.0
         elseif time < tApp then (xHole - xHold0)/(tApp - tHold)
         elseif time < tIns then depthReq/(tIns - tApp)
         else 0.0;
  y_d = 0.0;
  phi_d = 0.0;

  // Cartesian impedance wrench with lateral and axial force limits
  Fx_raw = Kpx*(x_d - x) + Kdx*(xd_d - x_dot);
  Fy_raw = Kpy*(y_d - y) + Kdy*(0.0 - y_dot);
  Fx_cmd = max(-FaxLimit, min(FaxLimit, Fx_raw));
  Fy_cmd = max(-FlatLimit, min(FlatLimit, Fy_raw));

  // Orientation impedance about Z
  e_phi = atan2(sin(phi_d - phi), cos(phi_d - phi));
  tau_phi_raw = Kphi*e_phi + Dphi*(phi_d - phi_dot);
  tau_phi_cmd = max(-tauMax, min(tauMax, tau_phi_raw));

  // Joint-torque commands with per-joint actuator bounds
  tau1_raw = J11*Fx_cmd + J21*Fy_cmd + tau_phi_cmd;
  tau2_raw = J12*Fx_cmd + J22*Fy_cmd + tau_phi_cmd;
  tau1 = max(-tauMax, min(tauMax, tau1_raw));
  tau2 = max(-tauMax, min(tauMax, tau2_raw));

  // Rigid collision regularization for peg/fixture contact in the hole region
  inHoleRegion = x >= xHole - eps;
  pen = if inHoleRegion then max(0.0, abs(y) - clearance) else 0.0;
  sL = y/sqrt(y*y + eps);
  vNormal = y_dot*sL;
  N = if inHoleRegion then max(0.0, kLat*pen + dLat*max(0.0, vNormal)) else 0.0;
  F_contact_y = -sL*N;
  F_axial_contact = -mu*N*tanh(x_dot/vEps);

  // Controlled lateral fixture load disturbance during the middle third
  F_dist_y = if time >= tDistStart and time <= tDistEnd then Fdist else 0.0;

  F_ext_x = F_axial_contact;
  F_ext_y = F_contact_y + F_dist_y;

  // Six-axis wrench measurement in fixture frame
  wrenchFx = F_axial_contact;
  wrenchFy = F_contact_y + F_dist_y;
  wrenchFz = 0.0;
  wrenchMx = 0.0;
  wrenchMy = 0.0;
  wrenchMz = 0.0;

  // Manipulator dynamics
  M11 = I1 + I2 + mLink1*L1*L1 + mp*(L1*L1 + L2*L2 + 2.0*L1*L2*cos(q2));
  M12 = I2 + mp*(L2*L2 + L1*L2*cos(q2));
  M22 = I2 + mp*L2*L2;
  h = -mp*L1*L2*sin(q2);
  C1 = h*(2.0*qd1*qd2 + qd2*qd2);
  C2 = -h*qd1*qd1;
  detM = M11*M22 - M12*M12;
  detM_safe = max(detM, eps);

  tau_ext1 = J11*F_ext_x + J21*F_ext_y;
  tau_ext2 = J12*F_ext_x + J22*F_ext_y;

  rhs1 = tau1 + tau_ext1 - C1 - dJoint*qd1;
  rhs2 = tau2 + tau_ext2 - C2 - dJoint*qd2;
  qdd1 = (M22*rhs1 - M12*rhs2)/detM_safe;
  qdd2 = (-M12*rhs1 + M11*rhs2)/detM_safe;

  der(q1) = qd1;
  der(q2) = qd2;
  der(qd1) = qdd1;
  der(qd2) = qdd2;

  // Requirement monitors
  insertionDepth = max(0.0, x - xHole);
  tilt = atan2(abs(sin(phi)), abs(cos(phi)));
  primaryTrackingError = sqrt(y*y + (tilt*insertionDepth)*(tilt*insertionDepth));

  actuatorBoundsOk = abs(tau1) <= tauMax + eps and abs(tau2) <= tauMax + eps;
  forceLimitsOk = abs(Fx_cmd) <= FaxLimit + eps and abs(Fy_cmd) <= FlatLimit + eps and
                  abs(wrenchFx) <= FaxLimit + eps and abs(wrenchFy) <= FlatLimit + eps;
  tiltOk = tilt <= tiltLimit + eps;
  depthOk = insertionDepth >= depthReq - eps;
  trackingOk = if time >= 6.5 then primaryTrackingError <= trackingThreshold + eps else true;
  insertionSpeedBounded = abs(xd_d) <= insertionSpeedLimit + eps;
  noJamming = not (N > 1.0e-6 and abs(x_dot) < 1.0e-4 and abs(Fy_cmd) >= FlatLimit - 1.0e-6);
  missionOk = actuatorBoundsOk and forceLimitsOk and tiltOk and depthOk and trackingOk and insertionSpeedBounded and noJamming;

  // Synchronized state, command, and sensor traces at 100 Hz
  when sample(0.0, Ts) then
    sampleIndex = min(pre(sampleIndex) + 1, Nsamp);
    traceTime[sampleIndex] = time;
    traceQ1[sampleIndex] = q1;
    traceQ2[sampleIndex] = q2;
    traceQd1[sampleIndex] = qd1;
    traceQd2[sampleIndex] = qd2;
    traceX[sampleIndex] = x;
    traceY[sampleIndex] = y;
    tracePhi[sampleIndex] = phi;
    traceDepth[sampleIndex] = insertionDepth;
    traceTau1[sampleIndex] = tau1;
    traceTau2[sampleIndex] = tau2;
    traceFx_cmd[sampleIndex] = Fx_cmd;
    traceFy_cmd[sampleIndex] = Fy_cmd;
    traceWrenchFx[sampleIndex] = wrenchFx;
    traceWrenchFy[sampleIndex] = wrenchFy;
    traceWrenchFz[sampleIndex] = wrenchFz;
    traceWrenchMx[sampleIndex] = wrenchMx;
    traceWrenchMy[sampleIndex] = wrenchMy;
    traceWrenchMz[sampleIndex] = wrenchMz;
    traceTilt[sampleIndex] = tilt;
    traceAlignErr[sampleIndex] = primaryTrackingError;
  end when;

  annotation (experiment(StopTime = 10.0, Tolerance = 1.0e-4, Interval = 0.01));
end PlanarPusherInsertB;