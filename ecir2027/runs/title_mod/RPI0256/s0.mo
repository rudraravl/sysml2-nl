model FourBarPositionD
  "Closed-chain four-bar mechanism with constrained IK pose control, bounded crank torque, load disturbance, self-collision checks, and sensor traces"

  // ---------- Stated geometry and bounds ----------
  final parameter Real L0 = 0.50 "ground pivot distance, m";
  final parameter Real a = 0.20 "crank length, m";
  final parameter Real b = 0.44 "coupler length, m";
  final parameter Real d = 0.35 "rocker length, m";
  final parameter Real tauMax = 25.0 "bounded crank torque, N.m";
  final parameter Real loadMagnitude = 14.0 "platform load magnitude, N";
  // Load direction is not specified in the requirement; a unit x-direction is used for simulation.
  parameter Real loadDirectionX = -1.0 "unitless load direction, unspecified by requirement";
  parameter Real loadDirectionY = 0.0 "unitless load direction, unspecified by requirement";
  final parameter Real runDuration = 14.0 "s";
  final parameter Real Ts = 0.005 "controller sample period, 200 Hz, s";
  final parameter Real q_max = 3.141592653589793 "rad";

  // ---------- Non-stated physical assumptions (explicit placeholders) ----------
  // Mass, inertia, damping, initial pose, and setpoint are not stated in the requirement.
  // Unit-valued placeholders are used so the model remains executable and FMI-exportable.
  parameter Real m_crank = 1.0 "kg, unspecified placeholder";
  parameter Real m_rocker = 1.0 "kg, unspecified placeholder";
  parameter Real m_coupler = 1.0 "kg, unspecified placeholder";
  parameter Real m_platform = 1.0 "kg, unspecified placeholder";
  final parameter Real m3 = m_coupler + m_platform "kg";
  final parameter Real I_crank = m_crank*a*a/12 "kg.m2, slender-rod placeholder";
  final parameter Real I_rocker = m_rocker*d*d/12 "kg.m2, slender-rod placeholder";
  final parameter Real I_coupler = m_coupler*b*b/12 "kg.m2, slender-rod placeholder";
  parameter Real I_platform = 0.0 "kg.m2, platform geometry unspecified";
  final parameter Real I3 = I_coupler + I_platform "kg.m2";
  parameter Real Damp = 2.0 "N.m.s/rad, unspecified placeholder";
  parameter Real branchSign = -1.0 "assembly branch, unspecified by requirement";
  parameter Real q_start = 0.5 "rad, initial crank angle, nonzero and nonsingular";
  parameter Real q_set = 1.0 "rad, chosen nonzero setpoint, unspecified by requirement";
  parameter Real Kp = 100.0 "N.m/rad";
  parameter Real Kd = 5.0 "N.m.s/rad";
  final parameter Real fd = 1e-6 "finite-difference step, rad";
  final parameter Real loadFx = loadMagnitude*loadDirectionX "N";
  final parameter Real loadFy = loadMagnitude*loadDirectionY "N";
  final parameter Real detEps = 1e-9;

  // ---------- Kinematics record ----------
  record Kinematics
    Real r "m, distance from rocker base to crank end";
    Real psi "rad, rocker angle";
    Real phi "rad, coupler angle";
    Real Px "m, output pose x";
    Real Py "m, output pose y";
    Real psi_q "d psi / d q";
    Real phi_q "d phi / d q";
    Real Pqx "d Px / d q";
    Real Pqy "d Py / d q";
  end Kinematics;

  function kinematics "Forward kinematics and first derivatives for planar four-bar"
    input Real q;
    input Real L0, a, b, d, branchSign;
    output Kinematics k;
  protected
    Real Cx, Cy, vx, vy, r2, r, gx, kc, alpha, psi, Dx, Dy, wx, wy, phi;
    Real r_q, gamma_q, k_q, alpha_q, psi_q;
    Real wx_q, wy_q, phi_q, Pqx, Pqy;
  algorithm
    Cx := a*cos(q);
    Cy := a*sin(q);
    vx := Cx - L0;
    vy := Cy;
    r2 := max(vx*vx + vy*vy, 1e-12);
    r := sqrt(r2);
    gx := Modelica.Math.atan2(vy, vx);
    kc := (r2 + d*d - b*b)/(2.0*d*r);
    kc := max(min(kc, 0.999999999), -0.999999999);
    alpha := Modelica.Math.acos(kc);
    psi := gx + branchSign*alpha;
    Dx := L0 + d*cos(psi);
    Dy := d*sin(psi);
    wx := Dx - Cx;
    wy := Dy - Cy;
    phi := Modelica.Math.atan2(wy, wx);

    r_q := a*L0*sin(q)/r;
    gamma_q := a*(a - L0*cos(q))/r2;
    k_q := r_q*(r2 - d*d + b*b)/(2.0*d*r2);
    alpha_q := -k_q/sqrt(max(1.0 - kc*kc, 1e-12));
    psi_q := gamma_q + branchSign*alpha_q;

    wx_q := -d*sin(psi)*psi_q + a*sin(q);
    wy_q := d*cos(psi)*psi_q - a*cos(q);
    phi_q := (wx*wy_q - wy*wx_q)/max(b*b, 1e-12);
    Pqx := (-a*sin(q) - d*sin(psi)*psi_q)/2.0;
    Pqy := (a*cos(q) + d*cos(psi)*psi_q)/2.0;

    k.r := r;
    k.psi := psi;
    k.phi := phi;
    k.Px := (Cx + Dx)/2.0;
    k.Py := (Cy + Dy)/2.0;
    k.psi_q := psi_q;
    k.phi_q := phi_q;
    k.Pqx := Pqx;
    k.Pqy := Pqy;
  end kinematics;

  function Meff "Generalized inertia as function of crank angle"
    input Real q;
    input Real L0, a, b, d, branchSign;
    input Real m_crank, m_rocker, m_coupler, m_platform;
    input Real I_crank, I_rocker, I_coupler, I_platform;
    output Real M;
  protected
    Kinematics k;
  algorithm
    k := kinematics(q, L0, a, b, d, branchSign);
    M := m_crank*(a/2.0)^2 + I_crank
       + (m_rocker*(d/2.0)^2 + I_rocker)*k.psi_q^2
       + (m_coupler + m_platform)*(k.Pqx^2 + k.Pqy^2)
       + (I_coupler + I_platform)*k.phi_q^2;
    M := max(M, 1e-9);
  end Meff;

  function inverseKinematics "Constrained 1-DOF inverse kinematics projection onto feasible four-bar pose"
    input Real xDes;
    input Real yDes;
    input Real phiDes;
    input Real qSeed;
    input Real L0, a, b, d, branchSign;
    output Real qOut;
  protected
    Kinematics k;
    Real dx, dy, dphi, denom, step;
    Integer i;
  algorithm
    qOut := qSeed;
    for i in 1:30 loop
      k := kinematics(qOut, L0, a, b, d, branchSign);
      dx := xDes - k.Px;
      dy := yDes - k.Py;
      dphi := Modelica.Math.atan2(sin(phiDes - k.phi), cos(phiDes - k.phi));
      denom := k.Pqx^2 + k.Pqy^2 + 0.01*k.phi_q^2;
      denom := max(denom, 1e-12);
      step := (k.Pqx*dx + k.Pqy*dy + 0.01*k.phi_q*dphi)/denom;
      step := max(min(step, 0.2), -0.2);
      qOut := qOut + step;
      qOut := Modelica.Math.atan2(sin(qOut), cos(qOut));
    end for;
  end inverseKinematics;

  function cross2 "2D cross product r x F"
    input Real rx, ry, fx, fy;
    output Real c;
  algorithm
    c := rx*fy - ry*fx;
  end cross2;

  function orientation "Orientation of ordered triple for segment intersection"
    input Real ax, ay, bx, by, cx, cy;
    output Real o;
  algorithm
    o := (bx - ax)*(cy - ay) - (by - ay)*(cx - ax);
  end orientation;

  function segmentsIntersect "Planar segment intersection test"
    input Real ax, ay, bx, by, cx, cy, dx, dy;
    output Boolean inter;
  protected
    Real d1, d2, d3, d4;
  algorithm
    d1 := orientation(cx, cy, dx, dy, ax, ay);
    d2 := orientation(cx, cy, dx, dy, bx, by);
    d3 := orientation(ax, ay, bx, by, cx, cy);
    d4 := orientation(ax, ay, bx, by, dx, dy);
    inter := ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0))
          and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0));
  end segmentsIntersect;

  function pointSegmentDistance "Distance from point to segment"
    input Real px, py, ax, ay, bx, by;
    output Real dist;
  protected
    Real abx, aby, ab2, t, qx, qy, ddx, ddy;
  algorithm
    abx := bx - ax;
    aby := by - ay;
    ab2 := max(abx*abx + aby*aby, 1e-12);
    t := ((px - ax)*abx + (py - ay)*aby)/ab2;
    t := max(0.0, min(1.0, t));
    qx := ax + t*abx;
    qy := ay + t*aby;
    ddx := px - qx;
    ddy := py - qy;
    dist := sqrt(ddx*ddx + ddy*ddy);
  end pointSegmentDistance;

  function segmentDistance "Minimum distance between two planar segments"
    input Real ax, ay, bx, by, cx, cy, dx, dy;
    output Real dist;
  protected
    Real d1, d2, d3, d4;
  algorithm
    if segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy) then
      dist := 0.0;
    else
      d1 := pointSegmentDistance(ax, ay, cx, cy, dx, dy);
      d2 := pointSegmentDistance(bx, by, cx, cy, dx, dy);
      d3 := pointSegmentDistance(cx, cy, ax, ay, bx, by);
      d4 := pointSegmentDistance(dx, dy, ax, ay, bx, by);
      dist := min(min(d1, d2), min(d3, d4));
    end if;
  end segmentDistance;

  // ---------- Continuous state ----------
  Real q(start=q_start) "crank angle / actuator coordinate, rad";
  Real qd(start=0.0) "crank angular velocity, rad/s";
  Real qdd "crank angular acceleration, rad/s2";

  // ---------- Discrete control traces (200 Hz) ----------
  discrete Real sampleCount(start=0) "sample counter";
  discrete Real q_fb(start=q_start) "measured-pose IK feedback coordinate, rad";
  discrete Real q_cmd(start=q_set) "commanded actuator coordinate from desired pose, rad";
  discrete Real err_q(start=q_set - q_start) "control error, rad";
  discrete Real tau_raw(start=0.0) "unbounded controller torque, N.m";
  discrete Real tau(start=0.0) "bounded applied crank torque, N.m";

  // ---------- Kinematic records ----------
  Kinematics k "measured kinematics";
  Kinematics kdes "desired kinematics";
  Kinematics k_p "curvature forward";
  Kinematics k_m "curvature backward";

  // ---------- Output pose ----------
  Real poseX "m";
  Real poseY "m";
  Real posePhi "rad";
  Real poseDesX "m";
  Real poseDesY "m";
  Real poseDesPhi "rad";
  Real poseError "m, primary position tracking error";
  Real poseErrorPhi "rad";

  // ---------- Geometry and closure ----------
  Real Cx, Cy, Dx, Dy, wx, wy, hx, hy;
  Real closureResidualX "m";
  Real closureResidualY "m";
  Real closureResidualNorm "m";
  Real lengthResidual "m";

  // ---------- Inertia and dynamics ----------
  Real M "kg.m2";
  Real Msafe "kg.m2";
  Real Mq "d M / d q";
  Real Q_load "N.m generalized load";
  Boolean loadActive;
  Real Fx "N";
  Real Fy "N";

  // ---------- Reaction forces at four revolute Z joints ----------
  Real r1x, r1y, r2x, r2y;
  Real psi_dot, phi_dot, psi_dd, phi_dd;
  Real psi_qq, phi_qq, Pqqx, Pqqy;
  Real a1x, a1y, a2x, a2y, a3x, a3y;
  Real Sx, Sy, B1, B2, rhs1, rhs2, det, detSafe;
  Real RCx, RCy, RDx, RDy, RAx, RAy, RBx, RBy;
  Real R_Ax, R_Ay, R_Bx, R_By, R_Cx, R_Cy, R_Dx, R_Dy;
  Real couplerMomentResidual "N.m, dynamic consistency residual";

  // ---------- Self-collision ----------
  Real crankRockerClear "m";
  Real couplerGroundClear "m";
  Real minClearance "m";
  Boolean selfCollision;
  final parameter Boolean collisionCheckEnabled = true;

  // ---------- Synchronized traces ----------
  Real actuatorCoordinate;
  Real actuatorVelocity;
  Real actuatorAcceleration;
  Real actuatorTorque;
  Real actuatorTorqueRaw;
  Real commandCoordinate;
  Real feedbackCoordinate;
  Real controlError;
  Real estimatorError;
  Real loadForceX;
  Real loadForceY;

initial equation
  q = q_start;
  qd = 0.0;

equation
  // Forward kinematics
  k = kinematics(q, L0, a, b, d, branchSign);
  kdes = kinematics(q_set, L0, a, b, d, branchSign);
  k_p = kinematics(q + fd, L0, a, b, d, branchSign);
  k_m = kinematics(q - fd, L0, a, b, d, branchSign);

  poseX = k.Px;
  poseY = k.Py;
  posePhi = k.phi;
  poseDesX = kdes.Px;
  poseDesY = kdes.Py;
  poseDesPhi = kdes.phi;

  // Rigid base geometry and loop closure
  Cx = a*cos(q);
  Cy = a*sin(q);
  Dx = L0 + d*cos(k.psi);
  Dy = d*sin(k.psi);
  wx = Dx - Cx;
  wy = Dy - Cy;
  hx = wx/2.0;
  hy = wy/2.0;

  closureResidualX = wx - b*cos(k.phi);
  closureResidualY = wy - b*sin(k.phi);
  closureResidualNorm = sqrt(closureResidualX^2 + closureResidualY^2);
  lengthResidual = sqrt(wx^2 + wy^2) - b;

  // Curvature and accelerations
  psi_qq = (k_p.psi_q - k_m.psi_q)/(2.0*fd);
  phi_qq = (k_p.phi_q - k_m.phi_q)/(2.0*fd);
  Pqqx = (k_p.Pqx - k_m.Pqx)/(2.0*fd);
  Pqqy = (k_p.Pqy - k_m.Pqy)/(2.0*fd);

  psi_dot = k.psi_q*qd;
  phi_dot = k.phi_q*qd;
  psi_dd = psi_qq*qd^2 + k.psi_q*qdd;
  phi_dd = phi_qq*qd^2 + k.phi_q*qdd;

  a1x = (a/2.0)*(-cos(q)*qd^2 - sin(q)*qdd);
  a1y = (a/2.0)*(-sin(q)*qd^2 + cos(q)*qdd);
  a2x = (d/2.0)*(-cos(k.psi)*psi_dot^2 - sin(k.psi)*psi_dd);
  a2y = (d/2.0)*(-sin(k.psi)*psi_dot^2 + cos(k.psi)*psi_dd);
  a3x = Pqqx*qd^2 + k.Pqx*qdd;
  a3y = Pqqy*qd^2 + k.Pqy*qdd;

  // Generalized inertia and plant dynamics
  M = m_crank*(a/2.0)^2 + I_crank
      + (m_rocker*(d/2.0)^2 + I_rocker)*k.psi_q^2
      + m3*(k.Pqx^2 + k.Pqy^2)
      + I3*k.phi_q^2;
  Msafe = max(M, 1e-9);
  Mq = (Meff(q + fd, L0, a, b, d, branchSign,
             m_crank, m_rocker, m_coupler, m_platform,
             I_crank, I_rocker, I_coupler, I_platform)
        - Meff(q - fd, L0, a, b, d, branchSign,
             m_crank, m_rocker, m_coupler, m_platform,
             I_crank, I_rocker, I_coupler, I_platform))/(2.0*fd);

  loadActive = time >= runDuration/3.0 and time <= 2.0*runDuration/3.0;
  Fx = if loadActive then loadFx else 0.0;
  Fy = if loadActive then loadFy else 0.0;
  Q_load = k.Pqx*Fx + k.Pqy*Fy;

  qdd = (tau + Q_load - 0.5*Mq*qd^2 - Damp*qd)/Msafe;
  der(q) = qd;
  der(qd) = qdd;

  // Reaction force solve for four revolute joints
  r1x = (a/2.0)*cos(q);
  r1y = (a/2.0)*sin(q);
  r2x = (d/2.0)*cos(k.psi);
  r2y = (d/2.0)*sin(k.psi);

  Sx = Fx - m3*a3x;
  Sy = Fy - m3*a3y;
  B1 = (I_crank*qdd - tau + cross2(r1x, r1y, m_crank*a1x, m_crank*a1y))/2.0;
  B2 = (I_rocker*psi_dd + cross2(r2x, r2y, m_rocker*a2x, m_rocker*a2y))/2.0;
  rhs1 = B1;
  rhs2 = cross2(r2x, r2y, Sx, Sy) - B2;
  det = cross2(r1x, r1y, r2x, r2y);
  detSafe = if abs(det) > detEps then det else detEps;

  RCx = (r2x*rhs1 - r1x*rhs2)/detSafe;
  RCy = (r2y*rhs1 - r1y*rhs2)/detSafe;
  RDx = Sx - RCx;
  RDy = Sy - RCy;
  RAx = m_crank*a1x - RCx;
  RAy = m_crank*a1y - RCy;
  RBx = m_rocker*a2x - RDx;
  RBy = m_rocker*a2y - RDy;

  R_Ax = RAx;
  R_Ay = RAy;
  R_Bx = RBx;
  R_By = RBy;
  R_Cx = RCx;
  R_Cy = RCy;
  R_Dx = RDx;
  R_Dy = RDy;
  couplerMomentResidual = cross2(hx, hy, RCx - RDx, RCy - RDy) - I3*phi_dd;

  // Pose error
  poseError = sqrt((poseX - poseDesX)^2 + (poseY - poseDesY)^2);
  poseErrorPhi = Modelica.Math.atan2(sin(posePhi - poseDesPhi), cos(posePhi - poseDesPhi));

  // Self-collision checks between non-adjacent links
  crankRockerClear = segmentDistance(0.0, 0.0, Cx, Cy, L0, 0.0, Dx, Dy);
  couplerGroundClear = segmentDistance(Cx, Cy, Dx, Dy, 0.0, 0.0, L0, 0.0);
  minClearance = min(crankRockerClear, couplerGroundClear);
  selfCollision = minClearance <= 0.0;

  // Synchronized traces
  actuatorCoordinate = q;
  actuatorVelocity = qd;
  actuatorAcceleration = qdd;
  actuatorTorque = tau;
  actuatorTorqueRaw = tau_raw;
  commandCoordinate = q_cmd;
  feedbackCoordinate = q_fb;
  controlError = err_q;
  estimatorError = q_fb - q;
  loadForceX = Fx;
  loadForceY = Fy;

  // 200 Hz controller with constrained IK pose feedback
  when sample(0, Ts) then
    sampleCount = pre(sampleCount) + 1.0;
    q_fb = inverseKinematics(poseX, poseY, posePhi, q, L0, a, b, d, branchSign);
    q_cmd = inverseKinematics(poseDesX, poseDesY, poseDesPhi, q_set, L0, a, b, d, branchSign);
    err_q = q_cmd - q_fb;
    tau_raw = Kp*err_q - Kd*qd;
    tau = max(min(tau_raw, tauMax), -tauMax);
  end when;

  // Requirements
  assert(abs(q) <= q_max + 1e-6, "actuator travel bound violated");
  assert(abs(tau) <= tauMax + 1e-6, "actuator torque bound violated");
  assert(closureResidualNorm < 1e-6, "closure residual violated");
  assert(abs(lengthResidual) < 1e-6, "length closure residual violated");
  assert(not selfCollision, "self-collision detected");
  assert(time < 9.1 or poseError < 0.006, "primary tracking error > 0.006 m after 9.1 s");
  assert(abs(q) < 1e9 and abs(qd) < 1e9 and abs(qdd) < 1e9
         and abs(tau) < 1e9 and abs(tau_raw) < 1e9
         and abs(q_cmd) < 1e9 and abs(q_fb) < 1e9
         and abs(poseError) < 1e9 and abs(M) < 1e9
         and abs(R_Ax) < 1e9 and abs(R_Ay) < 1e9
         and abs(R_Bx) < 1e9 and abs(R_By) < 1e9
         and abs(R_Cx) < 1e9 and abs(R_Cy) < 1e9
         and abs(R_Dx) < 1e9 and abs(R_Dy) < 1e9,
         "NaN or infinite physical/control/estimator value detected");

  annotation(experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005));
end FourBarPositionD;