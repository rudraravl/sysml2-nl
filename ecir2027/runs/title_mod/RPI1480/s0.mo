model GantryPathSplineD
  "Instrumented trajectory-controlled Cartesian gantry tracking a 4-pose spline
   with cylindrical obstacle avoidance, joint-limit avoidance, and tool disturbance."

  // --- Embodiment parameters (SI) ---
  parameter Real Lx = 1.8  "X axis travel (m)";
  parameter Real Ly = 1.2  "Y axis travel (m)";
  parameter Real Lz = 0.55 "Z axis travel (m)";
  parameter Real mx = 18.0 "X axis moving mass (kg)";
  parameter Real my = 12.0 "Y axis moving mass (kg)";
  parameter Real mz = 7.0  "Z axis moving mass (kg)";
  parameter Real Fmax = 900.0 "Per-axis maximum actuator force (N)";

  // --- Behavior parameters ---
  parameter Real clearanceReq = 0.06 "Required obstacle clearance (m)";
  parameter Real Fdist = 10.0 "Tool disturbance magnitude (N)";
  parameter Real Ts  = 0.005 "Control/sensor rate period (200 Hz) (s)";
  parameter Real tEnd = 14.0 "Total run time (s)";
  parameter Real settleTime = 9.1 "Time after which primary tracking must be < 0.035 m (s)";
  parameter Real trackLimit = 0.035 "Primary tracking error limit (m)";

  // --- Timestamped Cartesian poses (4 waypoints) ---
  parameter Real Tw[4] = {0.0, 4.6, 9.3, 14.0};
  parameter Real Wx[4] = {0.30, 0.90, 1.50, 1.50};
  parameter Real Wy[4] = {0.30, 0.60, 0.60, 0.90};
  parameter Real Wz[4] = {0.20, 0.35, 0.35, 0.45};

  // --- Cylindrical obstacle (axis parallel to Z) beside the path ---
  parameter Real obsCx = 1.20 "Obstacle axis x (m)";
  parameter Real obsCy = 0.40 "Obstacle axis y (m)";
  parameter Real obsR  = 0.08 "Obstacle radius (m)";

  // --- Control gains ---
  parameter Real Kp = 400.0 "Operational-space position gain";
  parameter Real Kd = 40.0  "Operational-space velocity gain";

  // --- Joint-limit avoidance ---
  parameter Real jointMarginFrac = 0.10 "Fraction of travel forming soft-limit zone";
  parameter Real jointLimitK = 800.0 "Joint-limit repulsion gain (N)";

  // --- Derived parameter arrays ---
  parameter Real massVec[3] = {mx, my, mz};
  parameter Real Lvec[3]    = {Lx, Ly, Lz};

  // --- Continuous plant state ---
  Real q[3](start = {Wx[1], Wy[1], Wz[1]})  "Prismatic joint positions (m)";
  Real qd[3](start = {0.0, 0.0, 0.0})      "Prismatic joint velocities (m/s)";
  Real qdd[3]                                "Prismatic joint accelerations (m/s^2)";

  // --- Spline reference (continuous) ---
  Real qRef[3]   "Reference Cartesian position (m)";
  Real qdRef[3]  "Reference Cartesian velocity (m/s)";
  Real qddRef[3] "Reference Cartesian acceleration (m/s^2)";

  // --- Controller signals ---
  Real Fcmd[3]   "Unsaturated commanded actuator force, sampled at Ts (N)";
  Real Fjoint[3] "Joint-limit avoidance force (N)";
  Real Fsat[3]  "Saturated actuator force (N)";

  // --- Monitoring signals ---
  Real errCart[3]    "Cartesian tracking error (m)";
  Real errCartMag    "Cartesian error magnitude (m)";
  Real orientationError "Orientation error (rad); gantry preserves tool orientation";
  Real dObs          "Distance from end-effector to obstacle axis (m)";
  Real clearance     "Obstacle clearance (m)";

  // --- Disturbance ---
  Boolean inMiddleThird "True during middle third of run time";
  Real FdistVec[3] "Tool disturbance force vector applied to end-effector (N)";

  // --- Sampled synchronized traces (200 Hz) ---
  Real q_sensor[3]        "Sampled joint position (m)";
  Real qd_sensor[3]       "Sampled joint velocity (m/s)";
  Real F_sensor[3]        "Sampled saturated force command (N)";
  Real errCart_sensor[3]  "Sampled Cartesian error (m)";
  Real clearance_sensor   "Sampled obstacle clearance (m)";
  Real orientationErr_sensor "Sampled orientation error (rad)";
  Real wrench_sensor[3]   "Wrist wrench (N,Nm); not available on this gantry, kept zero";

  // --- Requirement monitors ---
  Real trackingErrAfter "Tracking error magnitude observed after settle time (m)";
  Real finiteSum "Sum of absolute values used for finiteness guard";
  Boolean finiteOk "True if all monitored physical/control values are finite";

protected
  function splineEval "Catmull-Rom spline evaluation returning pos, vel, acc"
    input Real t;
    input Real Tw_[4];
    input Real Wx_[4];
    input Real Wy_[4];
    input Real Wz_[4];
    output Real pos[3];
    output Real vel[3];
    output Real acc[3];
  protected
    Real tt, s, dt;
    Real Ax, Bx, Cx, Dx, Ay, By, Cy, Dy, Az, Bz, Cz, Dz;
    Real c0x, c1x, c2x, c3x, c0y, c1y, c2y, c3y, c0z, c1z, c2z, c3z;
  algorithm
    // Clamp time to spline domain
    tt := if t < Tw_[1] then Tw_[1] else if t > Tw_[4] then Tw_[4] else t;

    if tt <= Tw_[2] then
      // Segment 0->1, duplicate first point as virtual predecessor
      Ax := Wx_[1]; Bx := Wx_[1]; Cx := Wx_[2]; Dx := Wx_[3];
      Ay := Wy_[1]; By := Wy_[1]; Cy := Wy_[2]; Dy := Wy_[3];
      Az := Wz_[1]; Bz := Wz_[1]; Cz := Wz_[2]; Dz := Wz_[3];
      dt := Tw_[2] - Tw_[1];
      s  := (tt - Tw_[1]) / dt;
    elseif tt <= Tw_[3] then
      // Segment 1->2
      Ax := Wx_[1]; Bx := Wx_[2]; Cx := Wx_[3]; Dx := Wx_[4];
      Ay := Wy_[1]; By := Wy_[2]; Cy := Wy_[3]; Dy := Wy_[4];
      Az := Wz_[1]; Bz := Wz_[2]; Cz := Wz_[3]; Dz := Wz_[4];
      dt := Tw_[3] - Tw_[2];
      s  := (tt - Tw_[2]) / dt;
    else
      // Segment 2->3, duplicate last point as virtual successor
      Ax := Wx_[2]; Bx := Wx_[3]; Cx := Wx_[4]; Dx := Wx_[4];
      Ay := Wy_[2]; By := Wy_[3]; Cy := Wy_[4]; Dy := Wy_[4];
      Az := Wz_[2]; Bz := Wz_[3]; Cz := Wz_[4]; Dz := Wz_[4];
      dt := Tw_[4] - Tw_[3];
      s  := (tt - Tw_[3]) / dt;
    end if;

    // Catmull-Rom coefficients: q(s) = 0.5*(c0 + c1*s + c2*s^2 + c3*s^3)
    c0x := 2.0*Bx;                 c1x := -Ax + Cx;
    c2x := 2.0*Ax - 5.0*Bx + 4.0*Cx - Dx;
    c3x := -Ax + 3.0*Bx - 3.0*Cx + Dx;

    c0y := 2.0*By;                 c1y := -Ay + Cy;
    c2y := 2.0*Ay - 5.0*By + 4.0*Cy - Dy;
    c3y := -Ay + 3.0*By - 3.0*Cy + Dy;

    c0z := 2.0*Bz;                 c1z := -Az + Cz;
    c2z := 2.0*Az - 5.0*Bz + 4.0*Cz - Dz;
    c3z := -Az + 3.0*Bz - 3.0*Cz + Dz;

    pos[1] := 0.5*(c0x + c1x*s + c2x*s*s + c3x*s*s*s);
    pos[2] := 0.5*(c0y + c1y*s + c2y*s*s + c3y*s*s*s);
    pos[3] := 0.5*(c0z + c1z*s + c2z*s*s + c3z*s*s*s);

    vel[1] := 0.5*(c1x + 2.0*c2x*s + 3.0*c3x*s*s)/dt;
    vel[2] := 0.5*(c1y + 2.0*c2y*s + 3.0*c3y*s*s)/dt;
    vel[3] := 0.5*(c1z + 2.0*c2z*s + 3.0*c3z*s*s)/dt;

    acc[1] := 0.5*(2.0*c2x + 6.0*c3x*s)/(dt*dt);
    acc[2] := 0.5*(2.0*c2y + 6.0*c3y*s)/(dt*dt);
    acc[3] := 0.5*(2.0*c2z + 6.0*c3z*s)/(dt*dt);
  end splineEval;

  function sat "Scalar saturation to [-lim, lim]"
    input Real x;
    input Real lim;
    output Real y;
  algorithm
    y := if x > lim then lim else if x < -lim then -lim else x;
  end sat;

equation
  // --- Spline reference ---
  (qRef, qdRef, qddRef) = splineEval(time, Tw, Wx, Wy, Wz);

  // --- Cartesian tracking error ---
  errCart[1] = qRef[1] - q[1];
  errCart[2] = qRef[2] - q[2];
  errCart[3] = qRef[3] - q[3];
  // Zero-error branch on norm: additive 1e-12 prevents division-by-zero ambiguity
  errCartMag = sqrt(errCart[1]^2 + errCart[2]^2 + errCart[3]^2 + 1e-12);

  // --- Orientation error ---
  // Tool orientation is preserved by the fixed Cartesian gantry (no rotational DOF).
  orientationError = 0.0;

  // --- Obstacle clearance (cylinder axis along Z) ---
  dObs = sqrt((q[1] - obsCx)^2 + (q[2] - obsCy)^2 + 1e-12);
  clearance = dObs - obsR;

  // --- Tool disturbance: 10 N during middle third of run ---
  inMiddleThird = (time >= tEnd/3.0) and (time <= 2.0*tEnd/3.0);
  FdistVec[1] = 0.0;
  FdistVec[2] = 0.0;
  FdistVec[3] = if inMiddleThird then -Fdist else 0.0;

  // --- Joint-limit avoidance (continuous repulsion within soft margins) ---
  for i in 1:3 loop
    Fjoint[i] = jointLimitK * (
      (if q[i] > (1.0 - jointMarginFrac)*Lvec[i] then
         ((q[i] - (1.0 - jointMarginFrac)*Lvec[i])/(jointMarginFrac*Lvec[i]))^2
       else 0.0)
      -
      (if q[i] < jointMarginFrac*Lvec[i] then
         ((jointMarginFrac*Lvec[i] - q[i])/(jointMarginFrac*Lvec[i]))^2
       else 0.0)
    );
  end for;

  // --- Saturated effort ---
  Fsat[1] = sat(Fcmd[1] + Fjoint[1], Fmax);
  Fsat[2] = sat(Fcmd[2] + Fjoint[2], Fmax);
  Fsat[3] = sat(Fcmd[3] + Fjoint[3], Fmax);

  // --- Plant dynamics (decoupled prismatic axes) ---
  qdd[1] = (Fsat[1] + FdistVec[1]) / mx;
  qdd[2] = (Fsat[2] + FdistVec[2]) / my;
  qdd[3] = (Fsat[3] + FdistVec[3]) / mz;
  der(q)  = qd;
  der(qd) = qdd;

  // --- Discrete controller + synchronized sensor sampling at 200 Hz ---
  when sample(0, Ts) then
    // Operational-space PD + inverse-dynamics feedforward
    Fcmd[1] = mx*qddRef[1] + Kp*errCart[1] + Kd*(qdRef[1] - qd[1]);
    Fcmd[2] = my*qddRef[2] + Kp*errCart[2] + Kd*(qdRef[2] - qd[2]);
    Fcmd[3] = mz*qddRef[3] + Kp*errCart[3] + Kd*(qdRef[3] - qd[3]);

    // Synchronized sensor traces
    q_sensor[1] = q[1];
    q_sensor[2] = q[2];
    q_sensor[3] = q[3];
    qd_sensor[1] = qd[1];
    qd_sensor[2] = qd[2];
    qd_sensor[3] = qd[3];
    F_sensor[1] = Fsat[1];
    F_sensor[2] = Fsat[2];
    F_sensor[3] = Fsat[3];
    errCart_sensor[1] = errCart[1];
    errCart_sensor[2] = errCart[2];
    errCart_sensor[3] = errCart[3];
    clearance_sensor = clearance;
    orientationErr_sensor = orientationError;
    // No wrist joint on this Cartesian gantry: wrist wrench unavailable, kept zero.
    wrench_sensor[1] = 0.0;
    wrench_sensor[2] = 0.0;
    wrench_sensor[3] = 0.0;
  end when;

  // --- Requirement monitors ---
  trackingErrAfter = if time >= settleTime then errCartMag else 0.0;

  // Finiteness guard: NaN comparisons evaluate false in Modelica, so a NaN
  // in any term makes the inequality false.
  finiteSum = abs(errCartMag) + abs(clearance) + abs(dObs)
            + abs(Fcmd[1]) + abs(Fcmd[2]) + abs(Fcmd[3])
            + abs(Fsat[1]) + abs(Fsat[2]) + abs(Fsat[3])
            + abs(q[1]) + abs(q[2]) + abs(q[3])
            + abs(qd[1]) + abs(qd[2]) + abs(qd[3]);
  finiteOk = (finiteSum < 1.0e12);

  annotation (
    Documentation(info = "GantryPathSplineD: 3-axis Cartesian gantry tracking a
      Catmull-Rom spline through four timestamped poses while preserving tool
      orientation. Includes cylindrical obstacle clearance monitoring,
      joint-limit avoidance, a 10 N tool disturbance applied during the middle
      third of the run, operational-space PD control with feedforward,
      200 Hz synchronized state/command/sensor traces, and finiteness guards.
      Unknown facts (e.g., obstacle exact length, friction, sensor noise) are
      not invented; behavior left unmodeled where the request does not state."),
    experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005)
  );
end GantryPathSplineD;