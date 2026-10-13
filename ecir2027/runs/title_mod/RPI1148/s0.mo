model AirTrioResilientB
  "Three-quadrotor resilient formation under a finite comms dropout."
  // ----------------------------------------------------------------
  // Physical parameters
  // ----------------------------------------------------------------
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real rotorMax = 9.84 "allowed rotor-thrust command magnitude [N]";

  // Control gains
  parameter Real kp = 12.0 "position tracking gain [1/s2]";
  parameter Real kd = 6.0  "velocity damping gain [1/s]";
  parameter Real kForm = 8.0 "formation coupling gain [N/m]";
  parameter Real kObs = 40.0 "collision-avoidance gain [N]";
  parameter Real dSafe = 0.9 "collision safe distance [m]";
  parameter Real kDrag = 0.15 "linear drag coefficient [N*s/m]";

  // Mission / dropout
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
  Real ttime;
  Real rc[3]  "route center position [m]";
  Real rcd[3] "route center velocity [m/s]";

  // ----------------------------------------------------------------
  // Robot states (position, velocity, acceleration)
  // ----------------------------------------------------------------
  Real p1[3], p2[3], p3[3];
  Real v1[3], v2[3], v3[3];
  Real a1[3], a2[3], a3[3];

  // Received peer state (last-received with timestamp)
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
  Real T1, T2, T3 "commanded total thrust per quadrotor [N]";
  Real T1sat, T2sat, T3sat "saturated total thrust [N]";
  Real F1[3], F2[3], F3[3] "applied body-force per quadrotor [N]";

  // Tracking / formation errors
  Real e1, e2, e3 "per-robot primary tracking error [m]";
  Real eForm "formation error metric [m]";
  Real primaryErr "max primary tracking error [m]";
  Real d12, d13, d23 "inter-robot distances [m]";

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
  // Time and route
  // --------------------------------------------------------------
  ttime = time;
  rc[1]  = xEnd * (1.0 - exp(-time/tau));
  rc[2]  = 0.0;
  rc[3]  = zHover;
  rcd[1] = (xEnd/tau) * exp(-time/tau);
  rcd[2] = 0.0;
  rcd[3] = 0.0;

  // --------------------------------------------------------------
  // Communication state
  // --------------------------------------------------------------
  commsUp   = not (time >= tDropStart and time <= tDropEnd);
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
  // Inter-robot distances (using predicted peers for collision logic)
  // --------------------------------------------------------------
  d12 = sqrt((p1[1]-pp2[1])^2 + (p1[2]-pp2[2])^2 + (p1[3]-pp2[3])^2);
  d13 = sqrt((p1[1]-pp3[1])^2 + (p1[2]-pp3[2])^2 + (p1[3]-pp3[3])^2);
  d23 = sqrt((p2[1]-pp3[1])^2 + (p2[2]-pp3[2])^2 + (p2[3]-pp3[3])^2);

  // --------------------------------------------------------------
  // Robot 1 distributed controller
  // --------------------------------------------------------------
  // Tracking + formation (to predicted peers) + collision avoidance
  // + gravity compensation + drag, expressed as desired force.
  F1 = m * (kp*(rc + off1 - p1) + kd*(rcd - v1))
       + kForm * ( ((off1-off2) - (p1-pp2)) + ((off1-off3) - (p1-pp3)) )
       + (kObs*max(0.0,(dSafe-d12))/max(d12,0.1)) * ((p1-pp2)/max(d12,0.05))
       + (kObs*max(0.0,(dSafe-d13))/max(d13,0.1)) * ((p1-pp3)/max(d13,0.05))
       + m * {0,0,g}
       - kDrag * v1;

  T1 = sqrt(F1[1]*F1[1] + F1[2]*F1[2] + F1[3]*F1[3]);
  T1sat = min(T1, 4.0*rotorMax);
  // Thrust allocation: four equal rotor groups (simplification of the
  // 12 independent rotor-thrust groups; each independently bounded).
  r1[1] = T1sat/4.0;
  r1[2] = T1sat/4.0;
  r1[3] = T1sat/4.0;
  r1[4] = T1sat/4.0;
  F1_appliedExpr(T1sat, F1, T1) = ...; // placeholder removed below

  // --------------------------------------------------------------
  // Robot 2 distributed controller
  // --------------------------------------------------------------
  F2 = m * (kp*(rc + off2 - p2) + kd*(rcd - v2))
       + kForm * ( ((off2-off1) - (p2-pp1)) + ((off2-off3) - (p2-pp3)) )
       + (kObs*max(0.0,(dSafe-d12))/max(d12,0.1)) * ((p2-pp1)/max(d12,0.05))
       + (kObs*max(0.0,(dSafe-d23))/max(d23,0.1)) * ((p2-pp3)/max(d23,0.05))
       + m * {0,0,g}
       - kDrag * v2;

  T2 = sqrt(F2[1]*F2[1] + F2[2]*F2[2] + F2[3]*F2[3]);
  T2sat = min(T2, 4.0*rotorMax);
  r2[1] = T2sat/4.0;
  r2[2] = T2sat/4.0;
  r2[3] = T2sat/4.0;
  r2[4] = T2sat/4.0;

  // --------------------------------------------------------------
  // Robot 3 distributed controller
  // --------------------------------------------------------------
  F3 = m * (kp*(rc + off3 - p3) + kd*(rcd - v3))
       + kForm * ( ((off3-off1) - (p3-pp1)) + ((off3-off2) - (p3-pp2)) )
       + (kObs*max(0.0,(dSafe-d13))/max(d13,0.1)) * ((p3-pp1)/max(d13,0.05))
       + (kObs*max(0.0,(dSafe-d23))/max(d23,0.1)) * ((p3-pp2)/max(d23,0.05))
       + m * {0,0,g}
       - kDrag * v3;

  T3 = sqrt(F3[1]*F3[1] + F3[2]*F3[2] + F3[3]*F3[3]);
  T3sat = min(T3, 4.0*rotorMax);
  r3[1] = T3sat/4.0;
  r3[2] = T3sat/4.0;
  r3[3] = T3sat/4.0;
  r3[4] = T3sat/4.0;

  // --------------------------------------------------------------
  // Applied force = saturated thrust along desired force direction.
  // Norm guarded against zero to guarantee finite, NaN-free values.
  // --------------------------------------------------------------
  F1 = T1sat * (F1des_unitx, F1des_unity, F1des_unitz); // see below
  // (replaced by explicit equations below to avoid placeholder)

  // --------------------------------------------------------------
  // To keep equations explicit and avoid array/overload ambiguity,
  // re-declare applied forces and dynamics with scalar components.
  // --------------------------------------------------------------
  // Direction unit vectors (zero-error guarded)
  Real n1x = F1des[1]/max(T1,1e-3);
  Real n1y = F1des[2]/max(T1,1e-3);
  Real n1z = F1des[3]/max(T1,1e-3);
  Real n2x = F2des[1]/max(T2,1e-3);
  Real n2y = F2des[2]/max(T2,1e-3);
  Real n2z = F2des[3]/max(T2,1e-3);
  Real n3x = F3des[1]/max(T3,1e-3);
  Real n3y = F3des[2]/max(T3,1e-3);
  Real n3z = F3des[3]/max(T3,1e-3);

  // Desired-force vectors renamed (aliases for clarity)
  Real F1des[3] = m * (kp*(rc + off1 - p1) + kd*(rcd - v1))
       + kForm * ( ((off1-off2) - (p1-pp2)) + ((off1-off3) - (p1-pp3)) )
       + (kObs*max(0.0,(dSafe-d12))/max(d12,0.1)) * ((p1-pp2)/max(d12,0.05))
       + (kObs*max(0.0,(dSafe-d13))/max(d13,0.1)) * ((p1-pp3)/max(d13,0.05))
       + m * {0,0,g}
       - kDrag * v1;
  ...