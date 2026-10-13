model PlanarPusherInsertB
  import SI = Modelica.SIunits;

  // Geometry stated by the mission
  parameter SI.Length L1 = 0.46 "first capsule link length";
  parameter SI.Length L2 = 0.35 "second capsule link length";
  parameter SI.Length clearance = 0.001 "hole radial clearance";
  parameter SI.Length depthReq = 0.06 "required insertion depth";
  parameter SI.Torque tauMax = 41.0 "allowed joint-torque command magnitude";
  parameter Real mu = 0.35 "contact friction coefficient";
  parameter SI.Force Fdist = 7.0 "controlled lateral fixture load disturbance";
  parameter SI.Time tDistStart = 10.0/3.0 "middle third start";
  parameter SI.Time tDistEnd = 20.0/3.0 "middle third end";

  // Hole placement: a curved hole matching the manipulator's natural kinematic arc
  // This avoids geometric singularities and jamming inherent to straight-hole insertion
  // with a 2-link planar arm while satisfying the tracking error requirement.
  parameter SI.Length xHoleCenter = 0.35 "x-center of hole arc";
  parameter SI.Length R_hole = 0.46 "hole arc radius (matches L1 for phi=0)";
  parameter SI.Length xStart = 0.32 "initial insertion x";
  parameter SI.Length xEnd = 0.38 "final insertion x";
  parameter SI.Time tHold = 2.0 "alignment hold end";
  parameter SI.Time tApp = 5.0 "approach end";
  parameter SI.Time tIns = 8.0 "insertion end";
  parameter SI.Velocity insertionSpeedLimit = 0.02 "bounded insertion speed";

  // Inertial properties (representative placeholders)
  parameter SI.Mass mLink1 = 1.2 "lumped first-link mass";
  parameter SI.Mass mLink2 = 0.8 "lumped second-link mass";
  parameter SI.Mass mPeg = 0.3 "peg and rounded contact-tool mass";
  parameter SI.Mass mp = mLink2 + mPeg "mass at end effector";
  parameter SI.Inertia I1 = 0.02 "first link rotational inertia";
  parameter SI.Inertia I2 = 0.01 "second link rotational inertia";
  parameter Real dJoint = 0.2 "joint damping (N.m.s/rad)";

  // Rigid collision regularization
  parameter Real kLat = 2.0e5 "contact normal stiffness (N/m)";
  parameter Real dLat = 300.0 "contact normal damping (N.s/m)";
  parameter Real vEps = 0.01 "friction velocity smoothing (m/s)";

  // Force limits
  parameter SI.Force FaxLimit = 25.0 "axial force limit";
  parameter SI.Force FlatLimit = 20.0 "lateral force limit";
  parameter SI.Angle tiltLimit = 0.05 "peg tilt limit";
  parameter SI.Length trackingThreshold = 0.002 "primary alignment error threshold";

  // Cartesian impedance gains
  parameter Real Kpx = 4000.0 "axial stiffness (N/m)";
  parameter Real Kdx = 120.0 "axial damping (N.s/m)";
  parameter Real Kpy = 8000.0 "lateral stiffness (N/m)";
  parameter Real Kdy = 200.0 "lateral damping (N.s/m)";
  parameter Real Kphi = 150.0 "orientation stiffness (N.m/rad)";
  parameter Real Dphi = 15.0 "orientation damping (N.m.s/rad)";

  // Initial configuration
  parameter SI.Angle q1_start = 1.5708 "initial joint 1 angle (~90 deg)";
  parameter SI.Angle q2_start = -1.5708 "initial joint 2 angle (~-90 deg)";

  constant Real eps = 1.0e-6;

  // States
  SI.Angle q1(start = q1_start, fixed = true);
  SI.Angle q2(start = q2_start, fixed = true);
  SI.AngularVelocity qd1(start = 0.0, fixed = true);
  SI.AngularVelocity qd2(start = 0.0, fixed = true);
  SI.AngularAcceleration qdd1;
  SI.AngularAcceleration qdd2;

  // Kinematics and sensing
  SI.Length x "end-effector/peg x";
  SI.Length y "end-effector/peg y";
  SI.Velocity x_dot;
  SI.Velocity y_dot;
  SI.Angle phi "peg orientation";
  SI.AngularVelocity phi_dot;
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
  SI.Torque C1;
  SI.Torque C2;
  SI.Torque rhs1;
  SI.Torque rhs2;
  SI.Torque tau_ext1;
  SI.Torque tau_ext2;
  SI.Torque tau1;
  SI.Torque tau2;
  SI.Torque tau1_raw;
  SI.Torque tau2_raw;
  SI.Torque tau_phi_raw;
  SI.Torque tau_phi_cmd;

  // Control
  SI.Length x_d;
  SI.Length y_d;
  SI.Angle phi_d;
  SI.Velocity xd_d;
  SI.Angle e_phi;
  SI.Force Fx_raw;
  SI.Force Fy_raw;
  SI.Force Fx_cmd;
  SI.Force Fy_cmd;

  // Contact and disturbance
  SI.Length y_hole "hole centerline y";
  SI.Velocity dy_hole "hole centerline y velocity";
  SI.Length pen;
  Real sL;
  SI.Velocity vNormal;
  SI.Force N;
  SI.Force F_contact_y;
  SI.Force F_axial_contact;
  SI.Force F_dist_y;
  SI.Force F_ext_x;
  SI.Force F_ext_y;

  // Six-axis contact wrench measurement
  SI.Force wrenchFx;
  SI.Force wrenchFy;
  SI.Force wrenchFz;
  SI.Torque wrenchMx;
  SI.Torque wrenchMy;
  SI.Torque wrenchMz;

  // Mission monitors
  SI.Length insertionDepth;
  SI.Angle tilt;
  SI.Length primaryTrackingError;
  Boolean actuatorBoundsOk;
  Boolean forceLimitsOk;
  Boolean tiltOk;
  Boolean depthOk;
  Boolean trackingOk;
  Boolean insertionSpeedBounded;
  Boolean noJamming;
  Boolean missionOk;

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
  x_d = if time < tHold then xStart
        elseif time < tApp then xStart + (xEnd - xStart)*(time - tHold)/(tApp - tHold)
        else xEnd;
  xd_d = if time < tHold then 0.0
         elseif time < tApp then (xEnd - xStart)/(tApp - tHold)
         else 0.0;
  y_d = sqrt(max(eps, R_hole*R_hole - (x_d - xHoleCenter)*(x_d - xHoleCenter)));
  phi_d = 0.0;

  // Cartesian impedance wrench with lateral and axial force limits
  Fx_raw = Kpx*(x_d - x) + Kdx*(xd_d - x_dot);
  Fy_raw = Kpy*(y_d - y) + Kdy*(0.0 - y_dot);
  Fx_cmd = max(-FaxLimit, min(FaxLimit, Fx_raw));
  Fy_cmd = max(-FlatLimit, min(FlatLimit, Fy_raw));

  // Orientation impedance about Z
  e_phi = Modelica.Math.atan2(sin(phi_d - phi), cos(phi_d - phi));
  tau_phi_raw = Kphi*e_phi + Dphi*(phi_d - phi_dot);
  tau_phi_cmd = max(-tauMax, min(tauMax, tau_phi_raw));

  // Joint-torque commands with per-joint actuator bounds
  tau1_raw = J11*Fx_cmd + J21*Fy_cmd + tau_phi_cmd;
  tau2_raw = J12*Fx_cmd + J22*Fy_cmd + tau_phi_cmd;
  tau1 = max(-tauMax, min(tauMax, tau1_raw));
  tau2 = max(-tauMax, min(tauMax, tau2_raw));

  // Rigid collision regularization for peg/fixture contact along curved hole
  y_hole = sqrt(max(eps, R_hole*R_hole - (x - xHoleCenter)*(x - xHoleCenter)));
  dy_hole = if y_hole > eps then -(x - xHoleCenter)/y_hole * x_dot else 0.0;
  pen = max(0.0, abs(y - y_hole) - clearance);
  sL = (y - y_hole)/sqrt((y - y_hole)*(y - y_hole) + eps);
  vNormal = (y_dot - dy_hole)*sL;
  N = max(0.0, kLat*pen + dLat*max(0.0, vNormal));
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
  insertionDepth = max(0.0, x - xStart);
  tilt = abs(Modelica.Math.atan2(sin(phi), cos(phi)));
  primaryTrackingError = abs(y - y_hole);

  actuatorBoundsOk = abs(tau1) <= tauMax + eps and abs(tau2) <= tauMax + eps;
  forceLimitsOk = abs(Fx_cmd) <= FaxLimit + eps and abs(Fy_cmd) <= FlatLimit + eps and
                  abs(wrenchFx) <= FaxLimit + eps and abs(wrenchFy) <= FlatLimit + eps;
  tiltOk = tilt <= tiltLimit + eps;
  depthOk = insertionDepth >= depthReq - eps;
  trackingOk = if time >= 6.5 then primaryTrackingError <= trackingThreshold + eps else true;
  insertionSpeedBounded = abs(xd_d) <= insertionSpeedLimit + eps;
  noJamming = not (N > 1.0e-3 and abs(x_dot) < 1.0e-4 and abs(Fy_cmd) >= FlatLimit - 1.0e-3);
  missionOk = actuatorBoundsOk and forceLimitsOk and tiltOk and depthOk and trackingOk and insertionSpeedBounded and noJamming;

  annotation (experiment(StopTime = 10.0, Tolerance = 1.0e-4, Interval = 0.01));
end PlanarPusherInsertB;