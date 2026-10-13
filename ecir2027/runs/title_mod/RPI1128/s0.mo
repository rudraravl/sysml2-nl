model GroundTrioResilientF
  // Requirement-driven constants
  parameter Real mass(unit="kg") = 18.0 "robot mass";
  parameter Real tauMax(unit="N.m") = 14.6 "per-wheel torque bound";
  parameter Real Ts(unit="s") = 0.002 "500 Hz communication/control period";
  parameter Real tFinal(unit="s") = 20.0 "simulation duration";
  parameter Real tDropStart(unit="s") = 8.0 "dropout start, inside middle third";
  parameter Real tDropDur(unit="s") = 1.45 "controlled dropout duration";
  parameter Real tDropEnd(unit="s") = 9.45 "dropout end";
  parameter Real trackLimit(unit="m") = 0.48 "primary tracking limit after 13 s";

  // Geometry/inertia required for code generation but not specified by requirement
  parameter Real wheelRadius(unit="m") = 0.05 "assumed wheel radius";
  parameter Real wheelBase(unit="m") = 0.30 "assumed wheel base";
  parameter Real I_z(unit="kg.m2") = 0.90 "assumed yaw inertia";

  // Route and formation assumed for verification only
  parameter Real routeEndX(unit="m") = 10.0 "assumed route end";
  parameter Real routeSpeed(unit="m/s") = 0.6 "assumed route speed";
  parameter Real off2x(unit="m") = -1.0 "assumed formation offset, robot 2";
  parameter Real off2y(unit="m") = -0.80 "assumed formation offset, robot 2";
  parameter Real off3x(unit="m") = -1.0 "assumed formation offset, robot 3";
  parameter Real off3y(unit="m") = 0.80 "assumed formation offset, robot 3";

  // Controller and estimator tuning
  parameter Real safeDist(unit="m") = 0.60 "collision avoidance distance";
  parameter Real vmax(unit="m/s") = 0.80 "speed cap";
  parameter Real kp = 2.0 "position-to-velocity gain";
  parameter Real k_rep = 1.2 "repulsion gain";
  parameter Real ktheta = 3.0 "heading gain";
  parameter Real kv = 3.0 "forward velocity gain";
  parameter Real kom = 3.0 "yaw rate gain";
  parameter Real k_est = 8.0 "estimator correction gain";
  parameter Real distYaw(unit="rad/s2") = 0.25 "assumed shared dropout disturbance";

  constant Real eps = 1.0e-6;

  Boolean commAvailable "true when peer messages are received";
  discrete Real x1r2(start=0.0, fixed=true);
  discrete Real y1r2(start=0.0, fixed=true);
  discrete Real th1r2(start=0.0, fixed=true);
  discrete Real v1r2(start=0.0, fixed=true);
  discrete Real om1r2(start=0.0, fixed=true);
  discrete Real ts2(start=0.0, fixed=true);
  discrete Real x1r3(start=0.0, fixed=true);
  discrete Real y1r3(start=0.0, fixed=true);
  discrete Real th1r3(start=0.0, fixed=true);
  discrete Real v1r3(start=0.0, fixed=true);
  discrete Real om1r3(start=0.0, fixed=true);
  discrete Real ts3(start=0.0, fixed=true);

  Real age2(unit="s");
  Real age3(unit="s");
  Real x1p2, y1p2, th1p2;
  Real x1p3, y1p3, th1p3;

  // Robot 1 states
  Real x1(start=0.0, fixed=true, unit="m");
  Real y1(start=0.0, fixed=true, unit="m");
  Real th1(start=0.0, fixed=true, unit="rad");
  Real v1(start=0.0, fixed=true, unit="m/s");
  Real om1(start=0.0, fixed=true, unit="rad/s");

  // Robot 2 states
  Real x2(start=-1.0, fixed=true, unit="m");
  Real y2(start=-0.80, fixed=true, unit="m");
  Real th2(start=0.0, fixed=true, unit="rad");
  Real v2(start=0.0, fixed=true, unit="m/s");
  Real om2(start=0.0, fixed=true, unit="rad/s");

  // Robot 3 states
  Real x3(start=-1.0, fixed=true, unit="m");
  Real y3(start=0.80, fixed=true, unit="m");
  Real th3(start=0.0, fixed=true, unit="rad");
  Real v3(start=0.0, fixed=true, unit="m/s");
  Real om3(start=0.0, fixed=true, unit="rad/s");

  // Local estimators
  Real est_x1(start=0.0, fixed=true, unit="m");
  Real est_y1(start=0.0, fixed=true, unit="m");
  Real est_th1(start=0.0, fixed=true, unit="rad");
  Real est_x2(start=-1.0, fixed=true, unit="m");
  Real est_y2(start=-0.80, fixed=true, unit="m");
  Real est_th2(start=0.0, fixed=true, unit="rad");
  Real est_x3(start=-1.0, fixed=true, unit="m");
  Real est_y3(start=0.80, fixed=true, unit="m");
  Real est_th3(start=0.0, fixed=true, unit="rad");

  // Robot 1 control
  Real x_des1, y_des1, u1x, u1y, ux1, uy1, n1, vdes1, thdes1, h1, omdes1, avdes1, aomdes1;
  Real tauR1d, tauL1d, tauR1, tauL1;

  // Robot 2 control
  Real x_des2, y_des2, u2x, u2y, ux2, uy2, n2, vdes2, thdes2, h2, omdes2, avdes2, aomdes2;
  Real tauR2d, tauL2d, tauR2, tauL2;

  // Robot 3 control
  Real x_des3, y_des3, u3x, u3y, ux3, uy3, n3, vdes3, thdes3, h3, omdes3, avdes3, aomdes3;
  Real tauR3d, tauL3d, tauR3, tauL3;

  // Verification traces
  Real d12, d13, d23, mindist;
  Real trackErr1, formErr2, formErr3;
  Boolean routeCompleted;

equation
  commAvailable = not (time >= tDropStart and time < tDropEnd);

  // 500 Hz peer-state reception with timestamp; held during dropout
  when sample(0, Ts) then
    if commAvailable then
      x1r2 = x1; y1r2 = y1; th1r2 = th1; v1r2 = v1; om1r2 = om1; ts2 = time;
      x1r3 = x1; y1r3 = y1; th1r3 = th1; v1r3 = v1; om1r3 = om1; ts3 = time;
    end if;
  end when;

  age2 = time - ts2;
  age3 = time - ts3;

  // Dead-reckoning prediction of peer state during dropout
  x1p2 = x1r2 + v1r2*cos(th1r2)*age2;
  y1p2 = y1r2 + v1r2*sin(th1r2)*age2;
  th1p2 = th1r2 + om1r2*age2;
  x1p3 = x1r3 + v1r3*cos(th1r3)*age3;
  y1p3 = y1r3 + v1r3*sin(th1r3)*age3;
  th1p3 = th1r3 + om1r3*age3;

  // Local proprioceptive estimators
  der(est_x1) = v1*cos(est_th1) + k_est*(x1 - est_x1);
  der(est_y1) = v1*sin(est_th1) + k_est*(y1 - est_y1);
  der(est_th1) = om1 + k_est*(th1 - est_th1);
  der(est_x2) = v2*cos(est_th2) + k_est*(x2 - est_x2);
  der(est_y2) = v2*sin(est_th2) + k_est*(y2 - est_y2);
  der(est_th2) = om2 + k_est*(th2 - est_th2);
  der(est_x3) = v3*cos(est_th3) + k_est*(x3 - est_x3);
  der(est_y3) = v3*sin(est_th3) + k_est*(y3 - est_y3);
  der(est_th3) = om3 + k_est*(th3 - est_th3);

  // Exteroceptive relative distances with zero-error branch
  d12 = sqrt((x1 - x2)^2 + (y1 - y2)^2) + eps;
  d13 = sqrt((x1 - x3)^2 + (y1 - y3)^2) + eps;
  d23 = sqrt((x2 - x3)^2 + (y2 - y3)^2) + eps;
  mindist = min(d12, min(d13, d23));

  // Robot 1: route tracking with collision avoidance
  x_des1 = if time*routeSpeed < routeEndX then time*routeSpeed else routeEndX;
  y_des1 = 0.0;
  u1x = kp*(x_des1 - x1);
  u1y = kp*(y_des1 - y1);
  ux1 = u1x + (if d12 < safeDist then k_rep*(safeDist - d12)*(x1 - x2)/d12 else 0.0)
            + (if d13 < safeDist then k_rep*(safeDist - d13)*(x1 - x3)/d13 else 0.0);
  uy1 = u1y + (if d12 < safeDist then k_rep*(safeDist - d12)*(y1 - y2)/d12 else 0.0)
            + (if d13 < safeDist then k_rep*(safeDist - d13)*(y1 - y3)/d13 else 0.0);
  n1 = sqrt(ux1^2 + uy1^2);
  vdes1 = if n1 > vmax then vmax else n1;
  thdes1 = if n1 < eps then th1 else atan2(uy1, ux1);
  h1 = atan2(sin(thdes1 - th1), cos(thdes1 - th1));
  omdes1 = ktheta*h1;
  avdes1 = kv*(vdes1 - v1);
  aomdes1 = kom*(omdes1 - om1);
  tauR1d = wheelRadius*(mass*avdes1/2.0 + I_z*aomdes1/(2.0*wheelBase));
  tauL1d = wheelRadius*(mass*avdes1/2.0 - I_z*aomdes1/(2.0*wheelBase));
  tauR1 = if tauR1d > tauMax then tauMax else if tauR1d < -tauMax then -tauMax else tauR1d;
  tauL1 = if tauL1d > tauMax then tauMax else if tauL1d < -tauMax then -tauMax else tauL1d;

  // Robot 2: formation tracking relative to predicted leader
  x_des2 = x1p2 + off2x*cos(th1p2) - off2y*sin(th1p2);
  y_des2 = y1p2 + off2x*sin(th1p2) + off2y*cos(th1p2);
  u2x = kp*(x_des2 - x2);
  u2y = kp*(y_des2 - y2);
  ux2 = u2x + (if d12 < safeDist then k_rep*(safeDist - d12)*(x2 - x1)/d12 else 0.0)
            + (if d23 < safeDist then k_rep*(safeDist - d23)*(x2 - x3)/d23 else 0.0);
  uy2 = u2y + (if d12 < safeDist then k_rep*(safeDist - d12)*(y2 - y1)/d12 else 0.0)
            + (if d23 < safeDist then k_rep*(safeDist - d23)*(y2 - y3)/d23 else 0.0);
  n2 = sqrt(ux2^2 + uy2^2);
  vdes2 = if n2 > vmax then vmax else n2;
  thdes2 = if n2 < eps then th2 else atan2(uy2, ux2);
  h2 = atan2(sin(thdes2 - th2), cos(thdes2 - th2));
  omdes2 = ktheta*h2;
  avdes2 = kv*(vdes2 - v2);
  aomdes2 = kom*(omdes2 - om2);
  tauR2d = wheelRadius*(mass*avdes2/2.0 + I_z*aomdes2/(2.0*wheelBase));
  tauL2d = wheelRadius*(mass*avdes2/2.0 - I_z*aomdes2/(2.0*wheelBase));
  tauR2 = if tauR2d > tauMax then tauMax else if tauR2d < -tauMax then -tauMax else tauR2d;
  tauL2 = if tauL2d > tauMax then tauMax else if tauL2d < -tauMax then -tauMax else tauL2d;

  // Robot 3: formation tracking relative to predicted leader
  x_des3 = x1p3 + off3x*cos(th1p3) - off3y*sin(th1p3);
  y_des3 = y1p3 + off3x*sin(th1p3) + off3y*cos(th1p3);
  u3x = kp*(x_des3 - x3);
  u3y = kp*(y_des3 - y3);
  ux3 = u3x + (if d13 < safeDist then k_rep*(safeDist - d13)*(x3 - x1)/d13 else 0.0)
            + (if d23 < safeDist then k_rep*(safeDist - d23)*(x3 - x2)/d23 else 0.0);
  uy3 = u3y + (if d13 < safeDist then k_rep*(safeDist - d13)*(y3 - y1)/d13 else 0.0)
            + (if d23 < safeDist then k_rep*(safeDist - d23)*(y3 - y2)/d23 else 0.0);
  n3 = sqrt(ux3^2 + uy3^2);
  vdes3 = if n3 > vmax then vmax else n3;
  thdes3 = if n3 < eps then th3 else atan2(uy3, ux3);
  h3 = atan2(sin(thdes3 - th3), cos(thdes3 - th3));
  omdes3 = ktheta*h3;
  avdes3 = kv*(vdes3 - v3);
  aomdes3 = kom*(omdes3 - om3);
  tauR3d = wheelRadius*(mass*avdes3/2.0 + I_z*aomdes3/(2.0*wheelBase));
  tauL3d = wheelRadius*(mass*avdes3/2.0 - I_z*aomdes3/(2.0*wheelBase));
  tauR3 = if tauR3d > tauMax then tauMax else if tauR3d < -tauMax then -tauMax else tauR3d;
  tauL3 = if tauL3d > tauMax then tauMax else if tauL3d < -tauMax then -tauMax else tauL3d;

  // Differential-drive dynamics
  der(x1) = v1*cos(th1);
  der(y1) = v1*sin(th1);
  der(th1) = om1;
  der(v1) = (tauR1 + tauL1)/(wheelRadius*mass);
  der(om1) = (tauR1 - tauL1)*wheelBase/(wheelRadius*I_z) + (if commAvailable then 0.0 else distYaw);

  der(x2) = v2*cos(th2);
  der(y2) = v2*sin(th2);
  der(th2) = om2;
  der(v2) = (tauR2 + tauL2)/(wheelRadius*mass);
  der(om2) = (tauR2 - tauL2)*wheelBase/(wheelRadius*I_z) + (if commAvailable then 0.0 else distYaw);

  der(x3) = v3*cos(th3);
  der(y3) = v3*sin(th3);
  der(th3) = om3;
  der(v3) = (tauR3 + tauL3)/(wheelRadius*mass);
  der(om3) = (tauR3 - tauL3)*wheelBase/(wheelRadius*I_z) + (if commAvailable then 0.0 else distYaw);

  // Verification traces
  trackErr1 = sqrt((x1 - x_des1)^2 + (y1 - y_des1)^2);
  formErr2 = sqrt((x2 - x_des2)^2 + (y2 - y_des2)^2);
  formErr3 = sqrt((x3 - x_des3)^2 + (y3 - y_des3)^2);
  routeCompleted = x1 >= routeEndX - 0.05;

  annotation (experiment(StopTime=20, Interval=0.002, Tolerance=1e-6));
end GroundTrioResilientF;