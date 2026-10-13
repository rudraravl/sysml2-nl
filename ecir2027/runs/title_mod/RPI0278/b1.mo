model FiveBarPositionB
  // Geometry and bounds
  parameter Real a(unit="m") = 0.25 "base half pitch";
  parameter Real L1(unit="m") = 0.30 "actuated link length";
  parameter Real L2(unit="m") = 0.42 "passive link length";
  parameter Real tau_max(unit="N.m") = 31.2 "allowed actuator command magnitude";

  // Bounded platform load (vertical downward; direction not otherwise stated)
  parameter Real F_load_mag(unit="N") = 9.8;
  parameter Real F_load_x(unit="N") = 0.0;
  parameter Real F_load_y(unit="N") = -F_load_mag;

  // Mission timing and control rate
  parameter Real Ts(unit="s") = 0.01 "100 Hz control and trace period";
  parameter Real t_final(unit="s") = 10.0;
  parameter Real t_load_on(unit="s") = t_final/3.0;
  parameter Real t_load_off(unit="s") = 2.0*t_final/3.0;

  // Desired nonzero pose (symmetric upper branch)
  parameter Real x_set(unit="m") = 0.0;
  parameter Real y_set(unit="m") = L1 + sqrt(max(0.0, L2*L2 - a*a));

  // Initial conditions (feasible nonzero symmetric pose)
  parameter Real q1_start(unit="rad") = 1.2;
  parameter Real q2_start(unit="rad") = Modelica.Constants.pi - q1_start;

  // Inertia, damping, gains (not stated; nominal SI values)
  parameter Real I_act(unit="kg.m2") = 0.1;
  parameter Real d_act(unit="N.m.s/rad") = 0.2;
  parameter Real Kp(unit="N.m/rad") = 50.0;
  parameter Real Kd(unit="N.m.s/rad") = 5.0;

  // States
  Real q1(start=q1_start, fixed=true);
  Real q2(start=q2_start, fixed=true);
  Real qd1(start=0.0, fixed=true);
  Real qd2(start=0.0, fixed=true);

  // Commands
  discrete Real tau1_cmd(start=0.0);
  discrete Real tau2_cmd(start=0.0);
  Real tau1;
  Real tau2;
  Real tau_ext1;
  Real tau_ext2;

  // External load
  Real Fx_ext;
  Real Fy_ext;

  // Kinematics
  Real ex;
  Real ey;
  Real j1x, j1y, j2x, j2y;
  Boolean feasible;
  Real res1, res2;
  Real Cx, Cy, Dx, Dy;
  Real Ax, Ay, Bx, By;

  // Pose
  Real pose_theta = 0.0;
  Real pose_error;
  Real primary_tracking_error;

  // Closure residuals
  Real closure_residual1;
  Real closure_residual2;
  Real actuator_residual1;
  Real actuator_residual2;
  Real closure_residual_norm;

  // Reaction forces
  Real F_passive1;
  Real F_passive2;

  // Self-collision checks
  Boolean collision_AC_BD;
  Boolean collision_AC_DE;
  Boolean collision_BD_CE;
  Boolean collision_any;

  // Bounds
  Boolean travel_bound_ok;
  Boolean force_bound_ok;

  // Sensors
  Real sensor_q1, sensor_q2, sensor_qd1, sensor_qd2;
  Real sensor_pose_x, sensor_pose_y, sensor_pose_theta;
  Real sensor_F_reaction1, sensor_F_reaction2;

  // Synchronized 100 Hz traces
  discrete Real trace_time(start=0.0);
  discrete Real trace_q1(start=q1_start);
  discrete Real trace_q2(start=q2_start);
  discrete Real trace_qd1(start=0.0);
  discrete Real trace_qd2(start=0.0);
  discrete Real trace_tau1(start=0.0);
  discrete Real trace_tau2(start=0.0);
  discrete Real trace_pose_x(start=x_set);
  discrete Real trace_pose_y(start=y_set);
  discrete Real trace_F1(start=0.0);
  discrete Real trace_F2(start=0.0);
  discrete Real trace_pose_error(start=0.0);

protected
  Real q1_set_c;
  Real q2_set_c;
  Boolean ik_ok_c;

  discrete Boolean ik_ok_s;
  discrete Boolean feasible_s;
  discrete Real q1_ik(unit="rad");
  discrete Real q2_ik(unit="rad");
  discrete Real ex_s(unit="m");
  discrete Real ey_s(unit="m");
  discrete Real j1x_s(unit="m/rad");
  discrete Real j1y_s(unit="m/rad");
  discrete Real j2x_s(unit="m/rad");
  discrete Real j2y_s(unit="m/rad");
  discrete Real res1_s(unit="m2");
  discrete Real res2_s(unit="m2");
  discrete Real tau_load1_s(unit="N.m");
  discrete Real tau_load2_s(unit="N.m");

  function fiveBarKinematics
    input Real q1;
    input Real q2;
    input Real a;
    input Real L1;
    input Real L2;
    output Real ex;
    output Real ey;
    output Real j1x;
    output Real j1y;
    output Real j2x;
    output Real j2y;
    output Boolean feasible;
    output Real res1;
    output Real res2;
  protected
    Real Cxk, Cyk, Dxk, Dyk, px, py, d2, d, h, nx, ny, coeff, A11, A12, A21, A22;
    Real Cdotx, Cdoty, Ddotx, Ddoty;
    Real eps;
  algorithm
    eps := 1.0e-9;
    Cxk := -a + L1*cos(q1);
    Cyk := L1*sin(q1);
    Dxk := a + L1*cos(q2);
    Dyk := L1*sin(q2);
    px := Dxk - Cxk;
    py := Dyk - Cyk;
    d2 := px*px + py*py;
    d := sqrt(d2);
    if d <= eps or d > 2.0*L2 then
      ex := 0.5*(Cxk+Dxk);
      ey := max(Cyk,Dyk);
      j1x := 0.0; j1y := 0.0; j2x := 0.0; j2y := 0.0;
      feasible := false;
      res1 := L2*L2 - 0.25*d2;
      res2 := L2*L2 - 0.25*d2;
    else
      h := sqrt(max(0.0, L2*L2 - 0.25*d2));
      if h < eps then
        h := eps;
      end if;
      nx := -py/d;
      ny := px/d;
      ex := 0.5*(Cxk+Dxk) + h*nx;
      ey := 0.5*(Cyk+Dyk) + h*ny;
      coeff := -1.0/(4.0*h) - h/d2;
      A11 := 0.5 + coeff*nx*px;
      A12 := -h/d + coeff*nx*py;
      A21 := h/d + coeff*ny*px;
      A22 := 0.5 + coeff*ny*py;
      Cdotx := -L1*sin(q1);
      Cdoty := L1*cos(q1);
      Ddotx := -L1*sin(q2);
      Ddoty := L1*cos(q2);
      j1x := (-A11)*Cdotx + (-A12)*Cdoty;
      j1y := (-A21)*Cdotx + (-A22)*Cdoty;
      j2x := A11*Ddotx + A12*Ddoty;
      j2y := A21*Ddotx + A22*Ddoty;
      feasible := true;
      res1 := (ex-Cxk)*(ex-Cxk) + (ey-Cyk)*(ey-Cyk) - L2*L2;
      res2 := (ex-Dxk)*(ex-Dxk) + (ey-Dyk)*(ey-Dyk) - L2*L2;
    end if;
  end fiveBarKinematics;

  function symmetricIK
    input Real y_set;
    input Real a;
    input Real L1;
    input Real L2;
    output Real q1;
    output Real q2;
    output Boolean ok;
  protected
    Real Cc, R, theta, cr, eps;
  algorithm
    eps := 1.0e-9;
    Cc := (a*a + L1*L1 + y_set*y_set - L2*L2)/(2.0*L1);
    R := sqrt(a*a + y_set*y_set);
    if R < eps then
      q1 := Modelica.Constants.pi/2;
      q2 := Modelica.Constants.pi/2;
      ok := false;
    else
      cr := max(-1.0, min(1.0, Cc/R));
      theta := atan2(y_set,a) + acos(cr);
      q1 := theta;
      q2 := Modelica.Constants.pi - theta;
      ok := true;
    end if;
  end symmetricIK;

  function passiveLinkForces
    input Real ex;
    input Real ey;
    input Real q1;
    input Real q2;
    input Real Fx;
    input Real Fy;
    input Real a;
    input Real L1;
    input Real L2;
    output Real F1;
    output Real F2;
  protected
    Real Cxk, Cyk, Dxk, Dyk, u1x, u1y, u2x, u2y, det, eps;
  algorithm
    eps := 1.0e-12;
    Cxk := -a + L1*cos(q1);
    Cyk := L1*sin(q1);
    Dxk := a + L1*cos(q2);
    Dyk := L1*sin(q2);
    u1x := (ex-Cxk)/L2;
    u1y := (ey-Cyk)/L2;
    u2x := (ex-Dxk)/L2;
    u2y := (ey-Dyk)/L2;
    det := u1x*u2y - u1y*u2x;
    if abs(det) < eps then
      F1 := 0.0;
      F2 := 0.0;
    else
      F1 := (Fx*u2y - Fy*u2x)/det;
      F2 := (u1x*Fy - u1y*Fx)/det;
    end if;
  end passiveLinkForces;

  function segmentsIntersect
    input Real x1;
    input Real y1;
    input Real x2;
    input Real y2;
    input Real x3;
    input Real y3;
    input Real x4;
    input Real y4;
    output Boolean collide;
  protected
    Real rx, ry, sx, sy, d1, d2, d3, d4;
  algorithm
    rx := x2-x1;
    ry := y2-y1;
    sx := x4-x3;
    sy := y4-y3;
    d1 := rx*(y3-y1) - ry*(x3-x1);
    d2 := rx*(y4-y1) - ry*(x4-x1);
    d3 := sx*(y1-y3) - sy*(x1-x3);
    d4 := sx*(y2-y3) - sy*(x2-x3);
    collide := (d1*d2 <= 0.0) and (d3*d4 <= 0.0);
  end segmentsIntersect;

equation
  Ax = -a; Ay = 0.0;
  Bx = a;  By = 0.0;

  (ex,ey,j1x,j1y,j2x,j2y,feasible,res1,res2) = fiveBarKinematics(q1,q2,a,L1,L2);
  Cx = -a + L1*cos(q1);
  Cy = L1*sin(q1);
  Dx = a + L1*cos(q2);
  Dy = L1*sin(q2);

  closure_residual1 = res1;
  closure_residual2 = res2;
  actuator_residual1 = (Cx-Ax)*(Cx-Ax) + (Cy-Ay)*(Cy-Ay) - L1*L1;
  actuator_residual2 = (Dx-Bx)*(Dx-Bx) + (Dy-By)*(Dy-By) - L1*L1;
  closure_residual_norm = sqrt(max(0.0, res1*res1 + res2*res2));

  Fx_ext = if time >= t_load_on and time <= t_load_off then F_load_x else 0.0;
  Fy_ext = if time >= t_load_on and time <= t_load_off then F_load_y else 0.0;

  tau_ext1 = j1x*Fx_ext + j1y*Fy_ext;
  tau_ext2 = j2x*Fx_ext + j2y*Fy_ext;

  tau1 = tau1_cmd;
  tau2 = tau2_cmd;

  der(q1) = qd1;
  der(q2) = qd2;
  der(qd1) = (tau1 + tau_ext1 - d_act*qd1)/I_act;
  der(qd2) = (tau2 + tau_ext2 - d_act*qd2)/I_act;

  (F_passive1,F_passive2) = passiveLinkForces(ex,ey,q1,q2,Fx_ext,Fy_ext,a,L1,L2);

  pose_error = sqrt(max(0.0, (x_set-ex)*(x_set-ex) + (y_set-ey)*(y_set-ey)));
  primary_tracking_error = pose_error;

  (q1_set_c,q2_set_c,ik_ok_c) = symmetricIK(y_set,a,L1,L2);

  collision_AC_BD = segmentsIntersect(Ax,Ay,Cx,Cy,Bx,By,Dx,Dy);
  collision_AC_DE = segmentsIntersect(Ax,Ay,Cx,Cy,Dx,Dy,ex,ey);
  collision_BD_CE = segmentsIntersect(Bx,By,Dx,Dy,Cx,Cy,ex,ey);
  collision_any = collision_AC_BD or collision_AC_DE or collision_BD_CE;

  travel_bound_ok = feasible;
  force_bound_ok = (abs(tau1_cmd) <= tau_max + 1.0e-6) and (abs(tau2_cmd) <= tau_max + 1.0e-6);

  sensor_q1 = q1;
  sensor_q2 = q2;
  sensor_qd1 = qd1;
  sensor_qd2 = qd2;
  sensor_pose_x = ex;
  sensor_pose_y = ey;
  sensor_pose_theta = pose_theta;
  sensor_F_reaction1 = F_passive1;
  sensor_F_reaction2 = F_passive2;

  assert(ik_ok_c, "constrained inverse kinematics infeasible for desired pose");
  assert(travel_bound_ok, "actuator travel/closure bound exceeded");
  assert(force_bound_ok, "actuator force bound exceeded");
  assert(not collision_any, "self-collision detected between links");
  assert(closure_residual_norm < 1.0e-6, "closure residual nonzero");
  assert(time <= 6.5 or primary_tracking_error <= 0.007, "primary tracking error > 0.007 m after 6.5 s");
  assert(abs(q1) < 1.0e12 and abs(q2) < 1.0e12 and abs(qd1) < 1.0e12 and abs(qd2) < 1.0e12 and abs(tau1_cmd) < 1.0e12 and abs(tau2_cmd) < 1.0e12 and abs(ex) < 1.0e12 and abs(ey) < 1.0e12 and abs(F_passive1) < 1.0e12 and abs(F_passive2) < 1.0e12, "non-finite physical, control, or estimator value");

  when sample(0.0,Ts) then
    (q1_ik,q2_ik,ik_ok_s) = symmetricIK(y_set,a,L1,L2);
    (ex_s,ey_s,j1x_s,j1y_s,j2x_s,j2y_s,feasible_s,res1_s,res2_s) = fiveBarKinematics(q1,q2,a,L1,L2);
    assert(ik_ok_s and feasible_s and abs(res1_s) < 1.0e-6 and abs(res2_s) < 1.0e-6, "sampled IK or closure infeasible");
    tau_load1_s = j1x_s*Fx_ext + j1y_s*Fy_ext;
    tau_load2_s = j2x_s*Fx_ext + j2y_s*Fy_ext;
    tau1_cmd = max(-tau_max, min(tau_max, Kp*(q1_ik - q1) - Kd*qd1 - tau_load1_s));
    tau2_cmd = max(-tau_max, min(tau_max, Kp*(q2_ik - q2) - Kd*qd2 - tau_load2_s));
    trace_time = time;
    trace_q1 = q1;
    trace_q2 = q2;
    trace_qd1 = qd1;
    trace_qd2 = qd2;
    trace_tau1 = tau1_cmd;
    trace_tau2 = tau2_cmd;
    trace_pose_x = ex_s;
    trace_pose_y = ey_s;
    trace_F1 = F_passive1;
    trace_F2 = F_passive2;
    trace_pose_error = sqrt(max(0.0, (x_set-ex_s)*(x_set-ex_s) + (y_set-ey_s)*(y_set-ey_s)));
  end when;

  annotation(experiment(StopTime=10.0, Tolerance=1.0e-6));
end FiveBarPositionB;