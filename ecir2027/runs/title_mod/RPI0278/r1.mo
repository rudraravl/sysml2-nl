model FiveBarPositionB

  function endpointPosition
    "Upper-branch planar five-bar endpoint from the two actuated base angles"
    input Real q1;
    input Real q2;
    input Real Ax;
    input Real Ay;
    input Real Bx;
    input Real By;
    input Real L1;
    input Real L2;
    output Real Px;
    output Real Py;
  protected
    Real M1x, M1y, M2x, M2y, dx, dy, D2, D, h, midx, midy;
  algorithm
    M1x := Ax + L1*cos(q1);
    M1y := Ay + L1*sin(q1);
    M2x := Bx + L1*cos(q2);
    M2y := By + L1*sin(q2);
    dx := M2x - M1x;
    dy := M2y - M1y;
    D2 := max(dx*dx + dy*dy, 1.0e-12);
    D := sqrt(D2);
    h := sqrt(max(L2*L2 - 0.25*D2, 0.0));
    midx := 0.5*(M1x + M2x);
    midy := 0.5*(M1y + M2y);
    Px := midx - h*dy/D;
    Py := midy + h*dx/D;
  end endpointPosition;

  function endpointJacobian
    "Finite-difference Jacobian dP/dq with a zero-safe endpoint evaluation"
    input Real q1;
    input Real q2;
    input Real Ax;
    input Real Ay;
    input Real Bx;
    input Real By;
    input Real L1;
    input Real L2;
    output Real J11;
    output Real J12;
    output Real J21;
    output Real J22;
  protected
    Real eps = 1.0e-6;
    Real P0x, P0y, Ppx, Ppy, Pmx, Pmy, Pq2px, Pq2py, Pq2mx, Pq2my;
  algorithm
    (P0x, P0y) := endpointPosition(q1, q2, Ax, Ay, Bx, By, L1, L2);
    (Ppx, Ppy) := endpointPosition(q1 + eps, q2, Ax, Ay, Bx, By, L1, L2);
    (Pmx, Pmy) := endpointPosition(q1 - eps, q2, Ax, Ay, Bx, By, L1, L2);
    (Pq2px, Pq2py) := endpointPosition(q1, q2 + eps, Ax, Ay, Bx, By, L1, L2);
    (Pq2mx, Pq2my) := endpointPosition(q1, q2 - eps, Ax, Ay, Bx, By, L1, L2);
    J11 := (Ppx - Pmx)/(2.0*eps);
    J21 := (Ppy - Pmy)/(2.0*eps);
    J12 := (Pq2px - Pq2mx)/(2.0*eps);
    J22 := (Pq2py - Pq2my)/(2.0*eps);
  end endpointJacobian;

  function ikAngleLeft
    "Constrained left-base inverse kinematics angle for a feasible desired endpoint"
    input Real Px;
    input Real Py;
    input Real Ax;
    input Real Ay;
    input Real L1;
    input Real L2;
    output Real theta;
  protected
    Real vx, vy, d2, d, a, h2, h, ex, ey, perpx, perpy, mx, my;
  algorithm
    vx := Px - Ax;
    vy := Py - Ay;
    d2 := max(vx*vx + vy*vy, 1.0e-12);
    d := sqrt(d2);
    a := (d2 + L1*L1 - L2*L2)/(2.0*d);
    h2 := L1*L1 - a*a;
    h := sqrt(max(h2, 0.0));
    ex := vx/d;
    ey := vy/d;
    perpx := -ey;
    perpy := ex;
    mx := Ax + a*ex + h*perpx;
    my := Ay + a*ey + h*perpy;
    theta := atan2(my - Ay, mx - Ax);
  end ikAngleLeft;

  function ikAngleRight
    "Constrained right-base inverse kinematics angle for a feasible desired endpoint"
    input Real Px;
    input Real Py;
    input Real Bx;
    input Real By;
    input Real L1;
    input Real L2;
    output Real theta;
  protected
    Real vx, vy, d2, d, a, h2, h, ex, ey, perpx, perpy, mx, my;
  algorithm
    vx := Px - Bx;
    vy := Py - By;
    d2 := max(vx*vx + vy*vy, 1.0e-12);
    d := sqrt(d2);
    a := (d2 + L1*L1 - L2*L2)/(2.0*d);
    h2 := L1*L1 - a*a;
    h := sqrt(max(h2, 0.0));
    ex := vx/d;
    ey := vy/d;
    perpx := ey;
    perpy := -ex;
    mx := Bx + a*ex + h*perpx;
    my := By + a*ey + h*perpy;
    theta := atan2(my - By, mx - Bx);
  end ikAngleRight;

  function segmentDistance
    "Closest distance between two finite planar segments"
    input Real x1;
    input Real y1;
    input Real x2;
    input Real y2;
    input Real x3;
    input Real y3;
    input Real x4;
    input Real y4;
    output Real dist;
  protected
    Real ux, uy, vx, vy, wx, wy, a, b, c, d, e, D, s, t, cx, cy, bx, by;
  algorithm
    ux := x2 - x1;
    uy := y2 - y1;
    vx := x4 - x3;
    vy := y4 - y3;
    wx := x1 - x3;
    wy := y1 - y3;
    a := ux*ux + uy*uy;
    b := ux*vx + uy*vy;
    c := vx*vx + vy*vy;
    d := ux*wx + uy*wy;
    e := vx*wx + vy*wy;
    D := a*c - b*b;
    if D > 1.0e-12 then
      s := (b*e - c*d)/D;
      t := (a*e - b*d)/D;
      s := max(0.0, min(1.0, s));
      t := max(0.0, min(1.0, t));
    else
      s := 0.0;
      t := 0.0;
    end if;
    cx := x1 + ux*s;
    cy := y1 + uy*s;
    bx := x3 + vx*t;
    by := y3 + vy*t;
    dist := sqrt(max((cx - bx)*(cx - bx) + (cy - by)*(cy - by), 0.0));
  end segmentDistance;

  // Rigid base geometry and link lengths from the requirement.
  parameter Real Ax = -0.25(unit = "m") "left base pivot x";
  parameter Real Ay = 0.0(unit = "m") "left base pivot y";
  parameter Real Bx = 0.25(unit = "m") "right base pivot x";
  parameter Real By = 0.0(unit = "m") "right base pivot y";
  parameter Real L1 = 0.30(unit = "m") "actuated link length";
  parameter Real L2 = 0.42(unit = "m") "passive link length";
  parameter Real tauMax = 31.2(unit = "N.m") "allowed actuator command magnitude";
  parameter Real Fload = 9.8(unit = "N") "bounded platform load disturbance magnitude";
  parameter Real loadStart = 10.0/3.0(unit = "s") "middle third start";
  parameter Real loadEnd = 20.0/3.0(unit = "s") "middle third end";
  parameter Real Ts = 0.01(unit = "s") "100 Hz control and sensor sampling period";

  // Chosen feasible initial and nonzero target poses; the requirement did not specify numeric poses.
  parameter Real P0x = 0.0(unit = "m") "initial output pose x";
  parameter Real P0y = 0.30(unit = "m") "initial output pose y";
  parameter Real P1x = 0.0(unit = "m") "target nonzero output pose x";
  parameter Real P1y = 0.45(unit = "m") "target nonzero output pose y";
  parameter Real moveStart = 0.5(unit = "s") "motion start time";
  parameter Real moveEnd = 2.5(unit = "s") "motion end time";

  // Nominal dynamic parameters; masses/inertias were not stated in the requirement.
  parameter Real J1 = 1.0(unit = "kg.m2") "nominal left actuator inertia";
  parameter Real J2 = 1.0(unit = "kg.m2") "nominal right actuator inertia";
  parameter Real B1 = 10.0(unit = "N.m.s/rad") "nominal left actuator damping";
  parameter Real B2 = 10.0(unit = "N.m.s/rad") "nominal right actuator damping";
  parameter Real Kp = 8000.0(unit = "N.m/rad") "joint-space proportional gain";
  parameter Real Kd = 150.0(unit = "N.m.s/rad") "joint-space derivative gain";
  parameter Real Kp_pose = 0.2(unit = "1") "pose feedback gain into constrained inverse kinematics";

  parameter Real q1_start = ikAngleLeft(P0x, P0y, Ax, Ay, L1, L2) "initial left actuator coordinate";
  parameter Real q2_start = ikAngleRight(P0x, P0y, Bx, By, L1, L2) "initial right actuator coordinate";

  // Dynamic states.
  Real q1(unit = "rad", start = q1_start) "left actuator coordinate";
  Real q2(unit = "rad", start = q2_start) "right actuator coordinate";
  Real qd1(unit = "rad/s", start = 0.0) "left actuator velocity";
  Real qd2(unit = "rad/s", start = 0.0) "right actuator velocity";

  // Continuous kinematics and sensors.
  Real M1x(unit = "m"), M1y(unit = "m") "left actuated link tip";
  Real M2x(unit = "m"), M2y(unit = "m") "right actuated link tip";
  Real Px(unit = "m"), Py(unit = "m") "output platform planar position";
  Real phi_meas(unit = "rad") = 0.0 "platform orientation; unactuated point platform, not stated in requirement";
  Real Prefx(unit = "m"), Prefy(unit = "m") "reference output pose";
  Real pose_error(unit = "m") "primary tracking error";

  // Jacobian and generalized disturbance.
  Real J11(unit = "m/rad"), J12(unit = "m/rad"), J21(unit = "m/rad"), J22(unit = "m/rad");
  Real FdistX(unit = "N"), FdistY(unit = "N");
  Real tau_dist1(unit = "N.m"), tau_dist2(unit = "N.m");

  // Discrete controller commands at 100 Hz.
  discrete Real Pcorrx(start = P0x, unit = "m") "pose-feedback-corrected desired x";
  discrete Real Pcorry(start = P0y, unit = "m") "pose-feedback-corrected desired y";
  discrete Real dL(start = 0.0, unit = "m") "left IK reach";
  discrete Real dR(start = 0.0, unit = "m") "right IK reach";
  discrete Real q1_ref(start = q1_start, unit = "rad") "constrained IK left reference";
  discrete Real q2_ref(start = q2_start, unit = "rad") "constrained IK right reference";
  discrete Real tau1_cmd(start = 0.0, unit = "N.m") "left saturated torque command";
  discrete Real tau2_cmd(start = 0.0, unit = "N.m") "right saturated torque command";

  // Synchronized sampled traces.
  discrete Real sensor_time(start = 0.0, unit = "s");
  discrete Real sensor_q1(start = q1_start, unit = "rad");
  discrete Real sensor_q2(start = q2_start, unit = "rad");
  discrete Real sensor_qd1(start = 0.0, unit = "rad/s");
  discrete Real sensor_qd2(start = 0.0, unit = "rad/s");
  discrete Real sensor_x(start = P0x, unit = "m");
  discrete Real sensor_y(start = P0y, unit = "m");
  discrete Real sensor_phi(start = 0.0, unit = "rad");
  discrete Real sensor_tau1(start = 0.0, unit = "N.m");
  discrete Real sensor_tau2(start = 0.0, unit = "N.m");
  discrete Real sensor_FdistX(start = 0.0, unit = "N");
  discrete Real sensor_FdistY(start = 0.0, unit = "N");
  discrete Real sensor_reactionFx1(start = 0.0, unit = "N");
  discrete Real sensor_reactionFy1(start = 0.0, unit = "N");
  discrete Real sensor_reactionFx2(start = 0.0, unit = "N");
  discrete Real sensor_reactionFy2(start = 0.0, unit = "N");
  discrete Real sensor_pose_error(start = 0.0, unit = "m");

  // Self-collision checks and closure residuals.
  Real d_active_left_active_right(unit = "m");
  Real d_active_left_passive_right(unit = "m");
  Real d_active_right_passive_left(unit = "m");
  Real clearance(unit = "m");
  Boolean no_self_collision;
  Real closure_res1(unit = "m");
  Real closure_res2(unit = "m");
  Real closure_res_base1(unit = "m");
  Real closure_res_base2(unit = "m");
  Boolean closure_ok;

  // Reaction forces at the base pivots for the external load.
  Real reactionFx1(unit = "N"), reactionFy1(unit = "N");
  Real reactionFx2(unit = "N"), reactionFy2(unit = "N");

  // Requirement checks.
  Boolean force_bound1;
  Boolean force_bound2;
  Boolean actuator_travel_bound_met;
  Boolean tracking_requirement_met;
  Boolean finite_values;

protected
  constant Real eps = 1.0e-12;
  Real D2, D, h;
  Real u_move, s_move;

equation
  // Rigid base geometry and actuated link tips.
  M1x = Ax + L1*cos(q1);
  M1y = Ay + L1*sin(q1);
  M2x = Bx + L1*cos(q2);
  M2y = By + L1*sin(q2);

  // Closed-chain endpoint from the upper intersection branch.
  D2 = max((M2x - M1x)*(M2x - M1x) + (M2y - M1y)*(M2y - M1y), eps);
  D = sqrt(D2);
  h = sqrt(max(L2*L2 - 0.25*D2, 0.0));
  Px = 0.5*(M1x + M2x) - h*(M2y - M1y)/D;
  Py = 0.5*(M1y + M2y) + h*(M2x - M1x)/D;

  // Jacobian for mapping endpoint load to actuator torques.
  (J11, J12, J21, J22) = endpointJacobian(q1, q2, Ax, Ay, Bx, By, L1, L2);

  // Controlled middle-third load disturbance.
  FdistX = 0.0;
  FdistY = if (time >= loadStart) and (time <= loadEnd) then -Fload else 0.0;
  tau_dist1 = J11*FdistX + J21*FdistY;
  tau_dist2 = J12*FdistX + J22*FdistY;

  // Actuator dynamics with base-joint torque commands.
  der(q1) = qd1;
  der(q2) = qd2;
  J1*der(qd1) = tau1_cmd + tau_dist1 - B1*qd1;
  J2*der(qd2) = tau2_cmd + tau_dist2 - B2*qd2;

  // Smooth move to a nonzero pose and hold.
  u_move = if time <= moveStart then 0.0 elseif time >= moveEnd then 1.0 else (time - moveStart)/(moveEnd - moveStart);
  s_move = 3.0*u_move*u_move - 2.0*u_move*u_move*u_move;
  Prefx = P0x + (P1x - P0x)*s_move;
  Prefy = P0y + (P1y - P0y)*s_move;

  pose_error = sqrt(max((Prefx - Px)*(Prefx - Px) + (Prefy - Py)*(Prefy - Py), 0.0));

  // Closure residuals.
  closure_res1 = sqrt(max((Px - M1x)*(Px - M1x) + (Py - M1y)*(Py - M1y), 0.0)) - L2;
  closure_res2 = sqrt(max((Px - M2x)*(Px - M2x) + (Py - M2y)*(Py - M2y), 0.0)) - L2;
  closure_res_base1 = sqrt(max((M1x - Ax)*(M1x - Ax) + (M1y - Ay)*(M1y - Ay), 0.0)) - L1;
  closure_res_base2 = sqrt(max((M2x - Bx)*(M2x - Bx) + (M2y - By)*(M2y - By), 0.0)) - L1;
  closure_ok = abs(closure_res1) < 1.0e-6 and abs(closure_res2) < 1.0e-6 and abs(closure_res_base1) < 1.0e-6 and abs(closure_res_base2) < 1.0e-6;

  // Self-collision checks between non-adjacent links/struts.
  d_active_left_active_right = segmentDistance(Ax, Ay, M1x, M1y, Bx, By, M2x, M2y);
  d_active_left_passive_right = segmentDistance(Ax, Ay, M1x, M1y, M2x, M2y, Px, Py);
  d_active_right_passive_left = segmentDistance(Bx, By, M2x, M2y, M1x, M1y, Px, Py);
  clearance = min(d_active_left_active_right, min(d_active_left_passive_right, d_active_right_passive_left));
  no_self_collision = clearance > 0.0;

  // Base reaction forces for the bounded external load.
  reactionFx1 = -0.5*FdistX;
  reactionFy1 = -0.5*FdistY;
  reactionFx2 = -0.5*FdistX;
  reactionFy2 = -0.5*FdistY;

  // Bounds and requirement status.
  force_bound1 = abs(tau1_cmd) <= tauMax + 1.0e-9;
  force_bound2 = abs(tau2_cmd) <= tauMax + 1.0e-9;
  // No numerical actuator travel bound was stated in the requirement;
  // physical travel is bounded here by closure feasibility and self-collision.
  actuator_travel_bound_met = closure_ok and no_self_collision;
  tracking_requirement_met = (time < 6.5) or (pose_error <= 0.007);
  finite_values = abs(q1) < 1.0e12 and abs(q2) < 1.0e12 and abs(qd1) < 1.0e12 and abs(qd2) < 1.0e12 and abs(tau1_cmd) < 1.0e12 and abs(tau2_cmd) < 1.0e12 and abs(Px) < 1.0e12 and abs(Py) < 1.0e12;

  assert(force_bound1 and force_bound2, "actuator force bound violated");
  assert(actuator_travel_bound_met, "actuator travel/closure/collision bound violated");
  assert(no_self_collision, "self collision detected");
  assert(closure_ok, "closure residual violated");
  assert(finite_values, "non-finite physical, control, or estimator value detected");
  assert(time < 6.5 or pose_error <= 0.007, "primary tracking error > 0.007 m after 6.5 s");

  // 100 Hz pose-feedback controller through constrained inverse kinematics.
  when sample(0, Ts) then
    Pcorrx = Prefx + Kp_pose*(Prefx - Px);
    Pcorry = Prefy + Kp_pose*(Prefy - Py);
    dL = sqrt(max((Pcorrx - Ax)*(Pcorrx - Ax) + (Pcorry - Ay)*(Pcorry - Ay), eps));
    dR = sqrt(max((Pcorrx - Bx)*(Pcorrx - Bx) + (Pcorry - By)*(Pcorry - By), eps));
    if (dL <= L1 + L2 and dL >= abs(L1 - L2) and dR <= L1 + L2 and dR >= abs(L1 - L2)) then
      q1_ref = ikAngleLeft(Pcorrx, Pcorry, Ax, Ay, L1, L2);
      q2_ref = ikAngleRight(Pcorrx, Pcorry, Bx, By, L1, L2);
    else
      q1_ref = pre(q1_ref);
      q2_ref = pre(q2_ref);
    end if;
    tau1_cmd = max(-tauMax, min(tauMax, Kp*(q1_ref - q1) - Kd*qd1));
    tau2_cmd = max(-tauMax, min(tauMax, Kp*(q2_ref - q2) - Kd*qd2));

    sensor_time = time;
    sensor_q1 = q1;
    sensor_q2 = q2;
    sensor_qd1 = qd1;
    sensor_qd2 = qd2;
    sensor_x = Px;
    sensor_y = Py;
    sensor_phi = 0.0;
    sensor_tau1 = tau1_cmd;
    sensor_tau2 = tau2_cmd;
    sensor_FdistX = FdistX;
    sensor_FdistY = FdistY;
    sensor_reactionFx1 = reactionFx1;
    sensor_reactionFy1 = reactionFy1;
    sensor_reactionFx2 = reactionFx2;
    sensor_reactionFy2 = reactionFy2;
    sensor_pose_error = pose_error;
  end when;

initial equation
  q1 = q1_start;
  q2 = q2_start;
  qd1 = 0.0;
  qd2 = 0.0;

  annotation(experiment(StopTime = 10, Interval = 0.01, Tolerance = 1.0e-6));
end FiveBarPositionB;