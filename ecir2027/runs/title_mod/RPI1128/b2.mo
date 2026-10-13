model GroundTrioResilientF
  // Requirement-driven constants
  parameter Real mass = 18.0 "robot mass [kg]";
  parameter Real tauMax = 14.6 "per-wheel torque bound [N.m]";
  parameter Real tDropStart = 8.0 "dropout start, inside middle third [s]";
  parameter Real tDropDur = 1.45 "controlled dropout duration [s]";
  parameter Real tDropEnd = 9.45 "dropout end [s]";
  parameter Real trackLimit = 0.48 "primary tracking limit after 13 s [m]";

  // Assumed geometry/inertia (not specified by requirement)
  parameter Real wheelRadius = 0.05 "assumed wheel radius [m]";
  parameter Real wheelBase = 0.30 "assumed wheel base [m]";
  parameter Real I_z = 0.90 "assumed yaw inertia [kg.m2]";

  // Route and formation (assumed for verification)
  parameter Real routeEndX = 10.0 "assumed route end [m]";
  parameter Real routeSpeed = 0.6 "assumed route speed [m/s]";
  parameter Real off2x = -1.0 "assumed formation offset robot 2 x [m]";
  parameter Real off2y = -0.80 "assumed formation offset robot 2 y [m]";
  parameter Real off3x = -1.0 "assumed formation offset robot 3 x [m]";
  parameter Real off3y = 0.80 "assumed formation offset robot 3 y [m]";

  // Controller and estimator tuning
  parameter Real safeDist = 0.60 "collision avoidance distance [m]";
  parameter Real vmax = 0.80 "speed cap [m/s]";
  parameter Real kp = 2.0 "position-to-velocity gain";
  parameter Real k_rep = 1.2 "repulsion gain";
  parameter Real ktheta = 3.0 "heading gain";
  parameter Real kv = 3.0 "forward velocity gain";
  parameter Real kom = 3.0 "yaw rate gain";
  parameter Real k_est = 8.0 "estimator correction gain";
  parameter Real k_sync = 50.0 "peer state sync gain";
  parameter Real distYaw = 0.25 "assumed shared dropout disturbance [rad/s2]";

  constant Real eps = 1.0e-6;

  // Communication availability
  Boolean commAvailable;

  // Peer received state (continuous; syncs when comm available, holds during dropout)
  Real x1r2(start=0.0, fixed=true);
  Real y1r2(start=0.0, fixed=true);
  Real th1r2(start=0.0, fixed=true);
  Real v1r2(start=0.0, fixed=true);
  Real om1r2(start=0.0, fixed=true);
  Real x1r3(start=0.0, fixed=true);
  Real y1r3(start=0.0, fixed=true);
  Real th1r3(start=0.0, fixed=true);
  Real v1r3(start=0.0, fixed=true);
  Real om1r3(start=0.0, fixed=true);

  // Prediction age and predicted peer state
  Real predAge2;
  Real predAge3;
  Real x1p2;
  Real y1p2;
  Real th1p2;
  Real x1p3;
  Real y1p3;
  Real th1p3;

  // Robot 1 states
  Real x1(start=0.0, fixed=true);
  Real y1(start=0.0, fixed=true);
  Real th1(start=0.0, fixed=true);
  Real v1(start=0.0, fixed=true);
  Real om1(start=0.0, fixed=true);

  // Robot 2 states
  Real x2(start=-1.0, fixed=true);
  Real y2(start=-0.80, fixed=true);
  Real th2(start=0.0, fixed=true);
  Real v2(start=0.0, fixed=true);
  Real om2(start=0.0, fixed=true);

  // Robot 3 states
  Real x3(start=-1.0, fixed=true);
  Real y3(start=0.80, fixed=true);
  Real th3(start=0.0, fixed=true);
  Real v3(start=0.0, fixed=true);
  Real om3(start=0.0, fixed=true);

  // Local estimators
  Real est_x1(start=0.0, fixed=true);
  Real est_y1(start=0.0, fixed=true);
  Real est_th1(start=0.0, fixed=true);
  Real est_x2(start=-1.0, fixed=true);
  Real est_y2(start=-0.80, fixed=true);
  Real est_th2(start=0.0, fixed=true);
  Real est_x3(start=-1.0, fixed=true);
  Real est_y3(start=0.80, fixed=true);
  Real est_th3(start=0.0, fixed=true);

  // Robot 1 control intermediates
  Real x_des1;
  Real y_des1;
  Real ux1;
  Real uy1;
  Real n1;
  Real vdes1;
  Real thdes1;
  Real h1;
  Real omdes1;
  Real avdes1;
  Real aomdes1;
  Real tauR1d;
  Real tauL1d;
  Real tauR1;
  Real tauL1;

  // Robot 2 control intermediates
  Real x_des2;
  Real y_des2;
  Real ux2;
  Real uy2;
  Real n2;
  Real vdes2;
  Real thdes2;
  Real h2;
  Real omdes2;
  Real avdes2;
  Real aomdes2;
  Real tauR2d;
  Real tauL2d;
  Real tauR2;
  Real tauL2;

  // Robot 3 control intermediates
  Real x_des3;
  Real y_des3;
  Real ux3;
  Real uy3;
  Real n3;
  Real vdes3;
  Real thdes3;
  Real h3;
  Real omdes3;
  Real avdes3;
  Real aomdes3;
  Real tauR3d;
  Real tauL3d;
  Real tauR3;
  Real tauL3;

  // Verification traces
  Real d12;
  Real d13;
  Real d23;
  Real mindist;
  Real trackErr1;
  Real formErr2;
  Real formErr3;
  Boolean routeCompleted;

equation
  // Communication availability
  commAvailable = not (time >= tDropStart and time < tDropEnd);

  // Peer state synchronization (fast filter when comm available, hold during dropout)
  der(x1r2) = if commAvailable then k_sync*(x1 - x1r2) else 0.0;
  der(y1r2) = if commAvailable then k_sync*(y1 - y1r2) else 0.0;
  der(th1r2) = if commAvailable then k_sync*(th1 - th1r2) else 0.0;
  der(v1r2) = if commAvailable then k_sync*(v1 - v1r2) else 0.0;
  der(om1r2) = if commAvailable then k_sync*(om1 - om1r2) else 0.0;
  der(x1r3) = if commAvailable then k_sync*(x1 - x1r3) else 0.0;
  der(y1r3) = if commAvailable then k_sync*(y1 - y1r3) else 0.0;
  der(th1r3) = if commAvailable then k_sync*(th1 - th1r3) else 0.0;
  der(v1r3) = if commAvailable then k_sync*(v1 - v1r3) else 0.0;
  der(om1r3) = if commAvailable then k_sync*(om1 - om1r3) else 0.0;

  // Prediction age: zero when comm available, grows during dropout
  predAge2 = if commAvailable then 0.0 else (time - tDropStart);
  predAge3 = if commAvailable then 0.0 else (time - tDropStart);

  // Dead-reckoning prediction of peer state during dropout
  x1p2 = x1r2 + v1r2*cos(th1r2)*predAge2;
  y1p2 = y1r2 + v1r2*sin(th1r2)*predAge2;
  th1p2 = th1r2 + om1r2*predAge2;
  x1p3 = x1r3 + v1r3*cos(th1r3)*predAge3;
  y1p3 = y1r3 + v1r3*sin(th1r3)*predAge3;
  th1p3 = th1r3 + om1r3*predAge3;

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
  ux1 = kp*(x_des1 - x1)
      + (if d12 < safeDist then k_rep*(safeDist - d12)*(x1 - x2)/d12 else 0.0)
      + (if d13 < safeDist then k_rep*(safeDist - d13)*(x1 - x3)/d13 else 0.0);
  uy1 = kp*(y_des1 - y1)
      + (if d12 < safeDist then k_rep*(safeDist - d12)*(y1 - y2)/d12 else 0.0)
      + (if d13 < safeDist then k_rep*(safeDist - d13)*(y1 - y3)/d13 else 0.0);
  n1 = sqrt(ux1*ux1 + uy1*uy1);
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
  ux2 = kp*(x_des2 - x2)
      + (if d12 < safeDist then k_rep*(safeDist - d12)*(x2 - x1)/d12 else 0.0)
      + (if d23 < safeDist then k_rep*(safeDist - d23)*(x2 - x3)/d23 else 0.0);
  uy2 = kp*(y_des2 - y2)
      + (if d12 < safeDist then k_rep*(safeDist - d12)*(y2 - y1)/d12 else 0.0)
      + (if d23 < safeDist then k_rep*(safeDist - d23)*(y2 - y3)/d23 else 0.0);
  n2 = sqrt(ux2*ux2 + uy2*uy2);
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
  ux3 = kp*(x_des3 - x3)
      + (if d13 < safeDist then k_rep*(safeDist - d13)*(x3 - x1)/d13 else 0.0)
      + (if d23 < safeDist then k_rep*(safeDist - d23)*(x3 - x2)/d23 else 0.0);
  uy3 = kp*(y_des3 - y3)
      + (if d13 < safeDist then k_rep*(safeDist - d13)*(y3 - y1)/d13 else 0.0)
      + (if d23 < safeDist then k_rep*(safeDist - d23)*(y3 - y2)/d23 else 0.0);
  n3 = sqrt(ux3*ux3 + uy3*uy3);
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

  // Differential-drive dynamics with shared disturbance during dropout
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
  trackErr1 = sqrt((x1 - x_des1)*(x1 - x_des1) + (y1 - y_des1)*(y1 - y_des1));
  formErr2 = sqrt((x2 - x_des2)*(x2 - x_des2) + (y2 - y_des2)*(y2 - y_des2));
  formErr3 = sqrt((x3 - x_des3)*(x3 - x_des3) + (y3 - y_des3)*(y3 - y_des3));
  routeCompleted = x1 >= routeEndX - 0.05;

  annotation (experiment(StopTime=20, Interval=0.002, Tolerance=1e-6));
end GroundTrioResilientF;