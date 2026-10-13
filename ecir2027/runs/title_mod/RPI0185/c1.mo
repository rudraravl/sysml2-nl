model ForkArmCarryE
  // Timing and sampling
  parameter Real Ts = 0.004 "s, 250 Hz control/sensor sampling";
  parameter Real Tend = 16.0 "s";
  parameter Real T_dist1 = Tend/3 "s, start of controlled middle-third disturbance";
  parameter Real T_dist2 = 2*Tend/3 "s, end of controlled middle-third disturbance";
  parameter Real T_lift = 8.0 "s, trajectory duration";
  parameter Real track_time = 10.4 "s, tracking acceptance time";
  parameter Real eps = 1.0e-9;

  // Plant masses
  parameter Real m_ped = 24.0 "kg, fixed pedestal mass";
  parameter Real m1 = 7.0 "kg, moving mast body";
  parameter Real m2 = 3.0 "kg, moving camera boom body";
  parameter Real m3 = 2.0 "kg, moving tool slide body";
  parameter Real m_pl = 14.4 "kg, rigid tool payload";

  // Bounds and acceptance facts
  parameter Real tau_max = 88.0 "N.m, revolute command bound";
  parameter Real f_max = 700.0 "N, prismatic command bound";
  parameter Real Fw_limit = 60.0 "N, wrist force bound";
  parameter Real track_tol = 0.041 "rad-or-m, primary tracking tolerance";

  // Geometry (unit-normalized placeholders; facts not stated are unknown)
  parameter Real L1 = 1.0 "m, mast lever";
  parameter Real L2 = 1.0 "m, boom lever";
  parameter Real q1_start = 0.0 "rad, initial mast Z angle";
  parameter Real q2_start = 0.0 "rad, initial boom X angle";
  parameter Real q3_start = 0.4 "m, initial slide position";
  parameter Real delta_q3 = 0.2 "m, lift/reposition displacement";
  parameter Real a_dist = 1.0 "m/s2, disturbance acceleration";

  // Joint limits
  parameter Real q1_lo = -3.14159265358979 "rad";
  parameter Real q1_hi = 3.14159265358979 "rad";
  parameter Real q2_lo = -3.14159265358979 "rad";
  parameter Real q2_hi = 3.14159265358979 "rad";
  parameter Real q3_lo = 0.0 "m";
  parameter Real q3_hi = 1.0 "m";

  // Collision parameters
  parameter Real tableZ = 0.0 "m, table top plane";
  parameter Real floorZ = -0.2 "m, floor plane";
  parameter Real payloadRadius = 0.05 "m, payload radius";
  parameter Real k_contact = 1.0e6 "N/m, contact stiffness";
  parameter Real d_contact = 1.0e3 "N.s/m, contact damping";

  // Effective inertias
  parameter Real J1 = m1*L1*L1 + (m2 + m3 + m_pl)*L1*L1 "kg.m2";
  parameter Real J2 = m2*L2*L2 + (m3 + m_pl)*L2*L2 "kg.m2";
  parameter Real m_eff = m3 + m_pl "kg";

  // Controller gains
  parameter Real Kp1 = 100.0 "1/s2";
  parameter Real Kd1 = 20.0 "1/s";
  parameter Real Kp2 = 100.0 "1/s2";
  parameter Real Kd2 = 20.0 "1/s";
  parameter Real Kp3 = 100.0 "1/s2";
  parameter Real Kd3 = 20.0 "1/s";
  parameter Real Kw = 1.0 "N/N";
  parameter Real wristCorrBound = 60.0 "N";

  // Continuous plant states
  Real q1(start=q1_start) "rad, revolute Z mast encoder";
  Real w1(start=0.0) "rad/s, mast velocity";
  Real q2(start=q2_start) "rad, revolute X camera boom encoder";
  Real w2(start=0.0) "rad/s, boom velocity";
  Real q3(start=q3_start) "m, prismatic Y tool slide encoder";
  Real v3(start=0.0) "m/s, slide velocity";

  // Actuator outputs (discrete via when assignment)
  Real tau1(start=0.0) "N.m, mast effort";
  Real tau2(start=0.0) "N.m, boom effort";
  Real f3(start=0.0) "N, slide effort";

  // Trajectory
  Real u_lift;
  Real s_lift;
  Real sd_lift;
  Real sdd_lift;
  Real q1_des "rad";
  Real q2_des "rad";
  Real q3_des "m";
  Real v3_des "m/s";
  Real a1_des "rad/s2";
  Real a2_des "rad/s2";
  Real a3_des "m/s2";

  // Disturbance
  Real distProfile;
  Real Fd "N";
  Real Td1 "N.m";
  Real Td2 "N.m";

  // Collision
  Real penTable "m";
  Real penFloor "m";
  Real contactTable "N";
  Real contactFloor "N";

  // Six-axis wrist wrench sensor
  Real wristFx "N";
  Real wristFy "N";
  Real wristFz "N";
  Real wristTx "N.m";
  Real wristTy "N.m";
  Real wristTz "N.m";
  Real wristForceNorm "N";

  // Tracking and acceptance
  Real orientErr "rad";
  Real posErr "m";
  Real trackErr "rad-or-m";
  Boolean effortBoundsOK;
  Boolean jointBoundsOK;
  Boolean wrenchOK;
  Boolean payloadRetained;
  Boolean poseOK;
  Boolean finiteOK;
  Boolean failClosed;

  // Synchronized 250 Hz traces
  Real q1_s(start=q1_start) "rad";
  Real q2_s(start=q2_start) "rad";
  Real q3_s(start=q3_start) "m";
  Real w1_s(start=0.0) "rad/s";
  Real w2_s(start=0.0) "rad/s";
  Real v3_s(start=0.0) "m/s";
  Real tau1_s(start=0.0) "N.m";
  Real tau2_s(start=0.0) "N.m";
  Real f3_s(start=0.0) "N";
  Real wristFx_s(start=0.0) "N";
  Real wristFy_s(start=0.0) "N";
  Real wristFz_s(start=0.0) "N";
  Real wristTx_s(start=0.0) "N.m";
  Real wristTy_s(start=0.0) "N.m";
  Real wristTz_s(start=0.0) "N.m";
  Real wristForceNorm_s(start=0.0) "N";
  Real trackErr_s(start=0.0) "rad-or-m";

equation
  // Smooth lift/reposition trajectory; orientation held constant
  u_lift = noEvent(if time <= 0.0 then 0.0 elseif time >= T_lift then 1.0 else time/T_lift);
  s_lift = noEvent(if u_lift <= 0.0 then 0.0 elseif u_lift >= 1.0 then 1.0 else 10.0*u_lift^3 - 15.0*u_lift^4 + 6.0*u_lift^5);
  sd_lift = noEvent(if u_lift <= 0.0 then 0.0 elseif u_lift >= 1.0 then 0.0 else (30.0*u_lift^2 - 60.0*u_lift^3 + 30.0*u_lift^4)/T_lift);
  sdd_lift = noEvent(if u_lift <= 0.0 then 0.0 elseif u_lift >= 1.0 then 0.0 else (60.0*u_lift - 180.0*u_lift^2 + 120.0*u_lift^3)/(T_lift*T_lift));

  q1_des = q1_start;
  q2_des = q2_start;
  q3_des = q3_start + delta_q3*s_lift;
  v3_des = delta_q3*sd_lift;
  a1_des = 0.0;
  a2_des = 0.0;
  a3_des = delta_q3*sdd_lift;

  // Controlled payload middle-third disturbance
  distProfile = noEvent(if time <= T_dist1 or time >= T_dist2 then 0.0 else sin(3.14159265358979*(time - T_dist1)/(T_dist2 - T_dist1)));
  Fd = m_pl*a_dist*distProfile;
  Td1 = m_pl*L1*a_dist*distProfile;
  Td2 = m_pl*L2*a_dist*distProfile;

  // Articulated plant dynamics: fixed base, three independently driven branches
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = v3;
  J1*der(w1) = tau1 - Td1;
  J2*der(w2) = tau2 - Td2;
  m_eff*der(v3) = f3 - Fd + contactTable + contactFloor;

  // Rigid floor and fixed table with collision enabled
  penTable = max(0.0, tableZ + payloadRadius - q3);
  penFloor = max(0.0, floorZ + payloadRadius - q3);
  contactTable = noEvent(if penTable > 0.0 then k_contact*penTable - d_contact*v3 else 0.0);
  contactFloor = noEvent(if penFloor > 0.0 then k_contact*penFloor - d_contact*v3 else 0.0);

  // Six-axis wrist wrench sensor
  wristFx = m_pl*der(v3) + Fd;
  wristFy = 0.0;
  wristFz = 0.0;
  wristTx = m_pl*L1*der(w1) + Td1;
  wristTy = m_pl*L2*der(w2) + Td2;
  wristTz = 0.0;
  wristForceNorm = sqrt(wristFx*wristFx + wristFy*wristFy + wristFz*wristFz + 1.0e-12);

  // Pose tracking
  orientErr = sqrt((q1 - q1_des)^2 + (q2 - q2_des)^2 + 1.0e-12);
  posErr = abs(q3 - q3_des);
  trackErr = max(orientErr, posErr);

  // Acceptance checks (fail-closed)
  effortBoundsOK = abs(tau1) <= tau_max + eps and abs(tau2) <= tau_max + eps and abs(f3) <= f_max + eps;
  jointBoundsOK = q1 >= q1_lo - eps and q1 <= q1_hi + eps and q2 >= q2_lo - eps and q2 <= q2_hi + eps and q3 >= q3_lo - eps and q3 <= q3_hi + eps;
  wrenchOK = wristForceNorm < Fw_limit;
  payloadRetained = q3 >= q3_lo and q3 <= q3_hi and wrenchOK;
  poseOK = time < track_time or trackErr < track_tol;
  finiteOK = abs(q1) < 1.0e300 and abs(w1) < 1.0e300 and abs(q2) < 1.0e300 and abs(w2) < 1.0e300 and abs(q3) < 1.0e300 and abs(v3) < 1.0e300 and abs(tau1) < 1.0e300 and abs(tau2) < 1.0e300 and abs(f3) < 1.0e300;
  failClosed = effortBoundsOK and jointBoundsOK and wrenchOK and payloadRetained and poseOK and finiteOK;

algorithm
  when sample(0, Ts) then
    // Synchronized state and sensor traces
    q1_s := q1;
    q2_s := q2;
    q3_s := q3;
    w1_s := w1;
    w2_s := w2;
    v3_s := v3;
    wristFx_s := wristFx;
    wristFy_s := wristFy;
    wristFz_s := wristFz;
    wristTx_s := wristTx;
    wristTy_s := wristTy;
    wristTz_s := wristTz;
    wristForceNorm_s := wristForceNorm;
    trackErr_s := trackErr;

    // Computed-torque control with disturbance feedforward
    tau1 := J1*(a1_des + Kp1*(q1_des - q1) + Kd1*(0.0 - w1)) + Td1;
    tau2 := J2*(a2_des + Kp2*(q2_des - q2) + Kd2*(0.0 - w2)) + Td2;
    f3 := m_eff*(a3_des + Kp3*(q3_des - q3) + Kd3*(v3_des - v3)) + Fd;

    // Bounded wrist-force correction
    if wristForceNorm > Fw_limit then
      f3 := f3 - Kw*max(-wristCorrBound, min(wristCorrBound, wristFx));
    end if;

    // Effort bounds (88 N.m or 700 N)
    tau1 := max(-tau_max, min(tau_max, tau1));
    tau2 := max(-tau_max, min(tau_max, tau2));
    f3 := max(-f_max, min(f_max, f3));

    tau1_s := tau1;
    tau2_s := tau2;
    f3_s := f3;
  end when;

  annotation(experiment(StopTime=16.0, Interval=0.004, Tolerance=1.0e-6));
end ForkArmCarryE;