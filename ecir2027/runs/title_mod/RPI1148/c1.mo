model AirTrioResilientB
  "Three-quadrotor resilient formation under a finite comms dropout."

  // ----------------------------------------------------------------
  // Physical parameters
  // ----------------------------------------------------------------
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real rotorMax = 9.84 "allowed rotor-thrust command magnitude [N]";
  parameter Real kDrag = 0.15 "linear drag coefficient [N*s/m]";

  // Control gains
  parameter Real kp = 12.0 "position tracking gain [1/s2]";
  parameter Real kd = 6.0  "velocity damping gain [1/s]";
  parameter Real kForm = 8.0 "formation coupling gain [N/m]";
  parameter Real kObs = 40.0 "collision-avoidance gain [N]";
  parameter Real dSafe = 0.9 "collision safe distance [m]";

  // Mission / dropout (middle third of 10 s, 0.7 s duration)
  parameter Real tDropStart = 4.65 "dropout start time [s]";
  parameter Real tDropEnd   = 5.35 "dropout end time [s]";
  parameter Real wMag  = 1.2 "shared environmental disturbance magnitude [N]";
  parameter Real wDirX = 0.8 "disturbance direction x";
  parameter Real wDirY = 0.6 "disturbance direction y";
  parameter Real wDirZ = 0.0 "disturbance direction z";

  // Formation geometry (triangle in horizontal plane)
  parameter Real off1[3] = { 0.00,  0.60, 0.00};
  parameter Real off2[3] = { 0.52, -0.30, 0.00};
  parameter Real off3[3] = {-0.52, -0.30, 0.00};
  parameter Real zHover = 1.0 "nominal hover height [m]";
  parameter Real xEnd = 3.0 "route end x-coordinate [m]";
  parameter Real tau = 1.6 "route time constant [s]";

  // ----------------------------------------------------------------
  // Route
  // ----------------------------------------------------------------
  Real rc[3]  "route center position [m]";
  Real rcd[3] "route center velocity [m/s]";

  // ----------------------------------------------------------------
  // Robot states
  // ----------------------------------------------------------------
  Real p1[3], p2[3], p3[3];
  Real v1[3], v2[3], v3[3];
  Real a1[3], a2[3], a3[3];

  // Received peer state with timestamps
  Real pr1[3], pr2[3], pr3[3];
  Real vr1[3], vr2[3], vr3[3];
  Real ts1, ts2, ts3;
  Real dt1, dt2, dt3;

  // Predicted peer state (constant-velocity prediction during dropout)
  Real pp1[3], pp2[3], pp3[3];
  Real vp1[3], vp2[3], vp3[3];

  // Comms flags
  Boolean commsUp;
  Boolean dropActive;

  // Disturbance
  Real wDist[3];

  // Rotor commands (12 independent groups, 4 per quadrotor)
  Real r1[4], r2[4], r3[4];

  // Desired force, thrust magnitude, saturated thrust, unit vector, applied force
  Real F1des[3], F2des[3], F3des[3];
  Real T1, T2, T3;
  Real T1sat, T2sat, T3sat;
  Real n1[3], n2[3], n3[3];
  Real F1app[3], F2app[3], F3app[3];

  // Distances (predicted-based for control)
  Real d12, d13, d23;
  // Actual distances (for metrics)
  Real da12, da13, da23;
  Real d12des, d13des, d23des;

  // Errors
  Real e1, e2, e3 "per-robot primary tracking error [m]";
  Real eForm "formation error metric [m]";
  Real primaryErr "max primary tracking error [m]";

  // ----------------------------------------------------------------
initial equation
  p1 = off1 + {0,0,zHover};
  p2 = off2 + {0,0,zHover};
  p3 = off3 + {0,0,zHover};
  v1 = {0,0,0};
  v2 = {0,0,0};
  v3 = {0,0,0};
  pr1 = p1; pr2 = p2; pr3 = p3;
  vr1 = {0,0,0}; vr2 = {0,0,0}; vr3 = {0,0,0};
  ts1 = 0.0; ts2 = 0.0; ts3 = 0.0;

equation
  // --------------------------------------------------------------
  // Route
  // --------------------------------------------------------------
  rc[1]  = xEnd * (1.0 - exp(-time/tau));
  rc[2]  = 0.0;
  rc[3]  = zHover;
  rcd[1] = (xEnd/tau) * exp(-time/tau);
  rcd[2] = 0.0;
  rcd[3] = 0.0;

  // --------------------------------------------------------------
  // Communication state
  // --------------------------------------------------------------
  commsUp    = not (time >= tDropStart and time <= tDropEnd);
  dropActive =      (time >= tDropStart and time <= tDropEnd);

  // Shared environmental disturbance applied only during dropout
  wDist[1] = if dropActive then wMag*wDirX else 0.0;
  wDist[2] = if dropActive then wMag*wDirY else 0.0;
  wDist[3] = if dropActive then wMag*wDirZ else 0.0;

  // --------------------------------------------------------------
  // Received-state estimator: tracks truth while comms up,
  // frozen (with timestamp) while comms down.
  // --------------------------------------------------------------
  der(pr1) = if commsUp then v1 else {0,0,0};
  der(pr2) = if commsUp then v2 else {0,0,0};
  der(pr3) = if commsUp then v3 else {0,0,0};
  der(vr1) = if commsUp then a1 else {0,0,0};
  der(vr2) = if commsUp then a2 else {0,0,0};
  der(vr3) = if commsUp then a3 else {0,0,0};
  der(ts1) = if commsUp then 1.0 else 0.0;
  der(ts2) = if commsUp then 1.0 else 0.0;
  der(ts3) = if commsUp then 1.0 else 0.0;

  dt1 = time - ts1;
  dt2 = time - ts2;
  dt3 = time - ts3;

  // Constant-velocity prediction from last received peer state
  pp1 = pr1 + vr1*dt1;
  pp2 = pr2 + vr2*dt2;
  pp3 = pr3 + vr3*dt3;
  vp1 = vr1;
  vp2 = vr2;
  vp3 = vr3;

  // --------------------------------------------------------------
  // Inter-robot distances (predicted-based for control logic)
  // --------------------------------------------------------------
  d12 = sqrt((p1[1]-pp2[1])^2 + (p1[2]-pp2[2])^2 + (p1[3]-pp2[3])^2);
  d13 = sqrt((p1[1]-pp3[1])^2 + (p1[2]-pp3[2])^2 + (p1[3]-pp3[3])^2);
  d23 = sqrt((p2[1]-pp3[1])^2 + (p2[2]-pp3[2])^2 + (p2[3]-pp3[3])^2);

  // Actual distances (for formation error metric)
  da12 = sqrt((p1[1]-p2[1])^2 + (p1[2]-p2[2])^2 + (p1[3]-p2[3])^2);
  da13 = sqrt((p1[1]-p3[1])^2 + (p1[2]-p3[2])^2 + (p1[3]-p3[3])^2);
  da23 = sqrt((p2[1]-p3[1])^2 + (p2[2]-p3[2])^2 + (p2[3]-p3[3])^2);

  d12des = sqrt((off1[1]-off2[1])^2 + (off1[2]-off2[2])^2 + (off1[3]-off2[3])^2);
  d13des = sqrt((off1[1]-off3[1])^2 + (off1[2]-off3[2])^2 + (off1[3]-off3[3])^2);
  d23des = sqrt((off2[1]-off3[1])^2 + (off2[2]-off3[2])^2 + (off2[3]-off3[3])^2);

  // --------------------------------------------------------------
  // Robot 1 distributed controller (tracking + formation + avoidance + gravity)
  // --------------------------------------------------------------
  F1des = m*(kp*(rc + off1 - p1) + kd*(rcd - v1))
        + kForm*(((off1-off2)-(p1-pp2)) + ((off1-off3)-(p1-pp3)))
        + (kObs*max(0.0,dSafe-d12)/max(d12,0.1))*((p1-pp2)/max(d12,0.05))
        + (kObs*max(0.0,dSafe-d13)/max(d13,0.1))*((p1-pp3)/max(d13,0.05))
        - kDrag*v1 + {0,0,m*g};

  T1 = sqrt(F1des[1]^2 + F1des[2]^2 + F1des[3]^2);
  T1sat = min(T1, 4.0*rotorMax);
  n1 = F1des/max(T1,1e-3);
  F1app = T1sat*n1;
  r1[1] = min(T1sat/4.0, rotorMax);
  r1[2] = min(T1sat/4.0, rotorMax);
  r1[3] = min(T1sat/4.0, rotorMax);
  r1[4] = min(T1sat/4.0, rotorMax);

  // --------------------------------------------------------------
  // Robot 2 distributed controller
  // --------------------------------------------------------------
  F2des = m*(kp*(rc + off2 - p2) + kd*(rcd - v2))
        + kForm*(((off2-off1)-(p2-pp1)) + ((off2-off3)-(p2-pp3)))
        + (kObs*max(0.0,dSafe-d12)/max(d12,0.1))*((p2-pp1)/max(d12,0.05))
        + (kObs*max(0.0,dSafe-d23)/max(d23,0.1))*((p2-pp3)/max(d23,0.05))
        - kDrag*v2 + {0,0,m*g};

  T2 = sqrt(F2des[1]^2 + F2des[2]^2 + F2des[3]^2);
  T2sat = min(T2, 4.0*rotorMax);
  n2 = F2des/max(T2,1e-3);
  F2app = T2sat*n2;
  r2[1] = min(T2sat/4.0, rotorMax);
  r2[2] = min(T2sat/4.0, rotorMax);
  r2[3] = min(T2sat/4.0, rotorMax);
  r2[4] = min(T2sat/4.0, rotorMax);

  // --------------------------------------------------------------
  // Robot 3 distributed controller
  // --------------------------------------------------------------
  F3des = m*(kp*(rc + off3 - p3) + kd*(rcd - v3))
        + kForm*(((off3-off1)-(p3-pp1)) + ((off3-off2)-(p3-pp2)))
        + (kObs*max(0.0,dSafe-d13)/max(d13,0.1))*((p3-pp1)/max(d13,0.05))
        + (kObs*max(0.0,dSafe-d23)/max(d23,0.1))*((p3-pp2)/max(d23,0.05))
        - kDrag*v3 + {0,0,m*g};

  T3 = sqrt(F3des[1]^2 + F3des[2]^2 + F3des[3]^2);
  T3sat = min(T3, 4.0*rotorMax);
  n3 = F3des/max(T3,1e-3);
  F3app = T3sat*n3;
  r3[1] = min(T3sat/4.0, rotorMax);
  r3[2] = min(T3sat/4.0, rotorMax);
  r3[3] = min(T3sat/4.0, rotorMax);
  r3[4] = min(T3sat/4.0, rotorMax);

  // --------------------------------------------------------------
  // Dynamics: m*a = applied thrust - gravity + shared disturbance
  // --------------------------------------------------------------
  der(p1) = v1;
  der(p2) = v2;
  der(p3) = v3;

  m*a1 = F1app - {0,0,m*g} + wDist;
  m*a2 = F2app - {0,0,m*g} + wDist;
  m*a3 = F3app - {0,0,m*g} + wDist;

  der(v1) = a1;
  der(v2) = a2;
  der(v3) = a3;

  // --------------------------------------------------------------
  // Error metrics
  // --------------------------------------------------------------
  e1 = sqrt((rc[1]+off1[1]-p1[1])^2 + (rc[2]+off1[2]-p1[2])^2 + (rc[3]+off1[3]-p1[3])^2);
  e2 = sqrt((rc[1]+off2[1]-p2[1])^2 + (rc[2]+off2[2]-p2[2])^2 + (rc[3]+off2[3]-p2[3])^2);
  e3 = sqrt((rc[1]+off3[1]-p3[1])^2 + (rc[2]+off3[2]-p3[2])^2 + (rc[3]+off3[3]-p3[3])^2);

  primaryErr = max(e1, max(e2, e3));

  eForm = sqrt((da12-d12des)^2 + (da13-d13des)^2 + (da23-d23des)^2);

end AirTrioResilientB;