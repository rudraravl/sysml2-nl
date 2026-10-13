model ForkArmCarryE
  // Run and sampling
  parameter Real Ts = 0.004 "s, 250 Hz control/sensor sampling";
  parameter Real Tend = 16.0 "s";
  parameter Real T_dist1 = Tend/3 "s, start of controlled middle-third disturbance";
  parameter Real T_dist2 = 2*Tend/3 "s, end of controlled middle-third disturbance";

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
  parameter Real track_time = 10.4 "s, tracking acceptance time";
  parameter Real eps = 1.0e-9;

  // Geometry and trajectory placeholders: not specified by the requirement.
  parameter Real L1 = 1.0 "m, unit-normalized mast lever";
  parameter Real L2 = 1.0 "m, unit-normalized boom lever";
  parameter Real q1_start = 0.0 "rad, initial mast Z angle";
  parameter Real q2_start = 0.0 "rad, initial boom X angle";
  parameter Real q3_start = 0.4 "m, normalized initial slide position";
  parameter Real delta_q3 = 0.2 "m, normalized lift/reposition displacement";
  parameter Real T_lift = 8.0 "s, trajectory duration placeholder";
  parameter Real a_dist = 1.0 "m/s2, unit-normalized disturbance acceleration";

  // Joint bounds placeholders: not specified by the requirement.
  parameter Real q1_min = -Modelica.Constants.pi "rad";
  parameter Real q1_max = Modelica.Constants.pi "rad";
  parameter Real q2_min = -Modelica.Constants.pi "rad";
  parameter Real q2_max = Modelica.Constants.pi "rad";
  parameter Real q3_min = 0.0 "m";
  parameter Real q3_max = 1.0 "m";

  // Workcell collision placeholders: not specified by the requirement.
  parameter Boolean baseFixed = true "fixed base";
  parameter Boolean collisionEnabled = true "collision enabled";
  parameter Boolean tableFixed = true "fixed table";
  parameter Boolean floorFixed = true "fixed floor";
  parameter Real tableZ = 0.0 "m, normalized table top plane";
  parameter Real floorZ = -0.2 "m, normalized floor plane";
  parameter Real payloadRadius = 0.05 "m, normalized payload radius";
  parameter Real k_contact = 1.0e6 "N/m, contact stiffness placeholder";
  parameter Real d_contact = 1.0e3 "N.s/m, contact damping placeholder";

  // Effective inertias for the scalar articulated structure
  parameter Real J1 = m1*L1*L1 + (m2 + m3 + m_pl)*L1*L1 "kg.m2";
  parameter Real J2 = m2*L2*L2 + (m3 + m_pl)*L2*L2 "kg.m2";
  parameter Real m_eff = m3 + m_pl "kg";

  // Controller tuning placeholders: not specified by the requirement.
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

  // Desired pose trajectory
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

  // Controlled payload middle-third disturbance
  Real distProfile;
  Real Fd "N";
  Real Td1 "N.m";
  Real Td2 "N.m";

  // Collision representation
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
  Real wristForceSum;
  Real wristForceNorm "N";
  Real wristWrenchSum;
  Real wristWrenchNorm "N-or-N.m";

  // Tracking and acceptance
  Real orientSum;
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
  Boolean failure;

  // Synchronized 250 Hz traces
  discrete Real q1_s(start=q1_start) "rad";
  discrete Real q2_s(start=q2_start) "rad";
  discrete Real q3_s(start=q3_start) "m";
  discrete Real w1_s(start=0.0) "rad/s";
  discrete Real w2_s(start=0.0) "rad/s";
  discrete Real v3_s(start=0.0) "m/s";
  discrete Real tau1_cmd_s(start=0.0) "N.m";
  discrete Real tau2_cmd_s(start=0.0) "N.m";
  discrete Real f3_cmd_s(start=0.0) "N";
  discrete Real tau1_sat_s(start=0.0) "N.m";
  discrete Real tau2_sat_s(start=0.0) "N.m";
  discrete Real f3_sat_s(start=0.0) "N";
  discrete Real wristFx_s(start=0.0) "N";
  discrete Real wristFy_s(start=0.0) "N";
  discrete Real wristFz_s(start=0.0) "N";
  discrete Real wristTx_s(start=0.0) "N.m";
  discrete Real wristTy_s(start=0.0) "N.m";
  discrete Real wristTz_s(start=0.0) "N.m";
  discrete Real wristForceNorm_s(start=0.0) "N";
  discrete Real wristWrenchNorm_s(start=0.0) "N-or-N.m";
  discrete Real trackErr_s(start=0.0) "rad-or-m";
  discrete Real q1_des_s(start=q1_start) "rad";
  discrete Real q2_des_s(start=q2_start) "rad";
  discrete Real q3_des_s(start=q3_start) "m";
  discrete Real v3_des_s(start=0.0) "m/s";
  discrete Real a1_des_s(start=0.0) "rad/s2";
  discrete Real a2_des_s(start=0.0) "rad/s2";
  discrete Real a3_des_s(start=0.0) "m/s2";
  discrete Real e1(start=0.0) "rad";
  discrete Real e2(start=0.0) "rad";
  discrete Real e3(start=0.0) "m";
  discrete Real wristErr(start=0.0) "N";
  discrete Real dir3(start=0.0);
  discrete Real corr1(start=0.0) "N.m";
  discrete Real corr2(start=0.0) "N.m";
  discrete Real corr3(start=0.0) "N";
  discrete Boolean failClosed_s(start=true);
  discrete Boolean failure_s(start=false);

equation
  // Smooth lift/reposition trajectory; orientation is held constant.
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

  // Controlled payload middle-third disturbance.
  distProfile = noEvent(if time <= T_dist1 or time >= T_dist2 then 0.0 else sin(Modelica.Constants.pi*(time - T_dist1)/(T_dist2 - T_dist1)));
  Fd = m_pl*a_dist*distProfile;
  Td1 = m_pl*L1*a_dist*distProfile;
  Td2 = m_pl*L2*a_dist*distProfile;

  // Articulated plant dynamics: fixed base, three independently driven branches.
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = v3;
  J1*der(w1) = tau1_sat_s - Td1;
  J2*der(w2) = tau2_sat_s - Td2;
  m_eff*der(v3) = f3_sat_s - Fd + contactTable + contactFloor;

  // Rigid floor and fixed table with collision enabled.
  penTable = max(0.0, tableZ + payloadRadius - q3);
  penFloor = max(0.0, floorZ + payloadRadius - q3);
  contactTable = noEvent(if collisionEnabled and tableFixed and penTable > 0.0 then k_contact*penTable - d_contact*v3 else 0.0);
  contactFloor = noEvent(if collisionEnabled and floorFixed and penFloor > 0.0 then k_contact*penFloor - d_contact*v3 else 0.0);

  // Six-axis wrist wrench sensor.
  wristFx = m_pl*der(v3) + Fd;
  wristFy = 0.0;
  wristFz = 0.0;
  wristTx = m_pl*L1*der(w1) + Td1;
  wristTy = m_pl*L2*der(w2) + Td2;
  wristTz = 0.0;

  wristForceSum = wristFx*wristFx + wristFy*wristFy + wristFz*wristFz;
  wristForceNorm = if wristForceSum > 1.0e-12 then sqrt(wristForceSum) else 0.0;
  wristWrenchSum = wristFx*wristFx + wristFy*wristFy + wristFz*wristFz + wristTx*wristTx + wristTy*wristTy + wristTz*wristTz;
  wristWrenchNorm = if wristWrenchSum > 1.0e-12 then sqrt(wristWrenchSum) else 0.0;

  // Pose tracking.
  orientSum = (q1 - q1_des)^2 + (q2 - q2_des)^2;
  orientErr = if orientSum > 1.0e-12 then sqrt(orientSum) else 0.0;
  posErr = abs(q3 - q3_des);
  trackErr = max(orientErr, posErr);

  // Acceptance checks.
  effortBoundsOK = abs(tau1_sat_s) <= tau_max + eps and abs(tau2_sat_s) <= tau_max + eps and abs(f3_sat_s) <= f_max + eps;
  jointBoundsOK = q1 >= q1_min - eps and q1 <= q1_max + eps and q2 >= q2_min - eps and q2 <= q2_max + eps and q3 >= q3_min - eps and q3 <= q3_max + eps;
  wrenchOK = wristForceNorm < Fw_limit;
  payloadRetained = baseFixed and m_ped > 0.0 and q3 >= q3_min and q3 <= q3_max and wrenchOK and effortBoundsOK;
  poseOK = time < track_time or trackErr < track_tol;

  finiteOK = not (
    (q1 <> q1) or (q2 <> q2) or (q3 <> q3) or (w1 <> w1) or (w2 <> w2) or (v3 <> v3) or
    (tau1_sat_s <> tau1_sat_s) or (tau2_sat_s <> tau2_sat_s) or (f3_sat_s <> f3_sat_s) or
    (tau1_cmd_s <> tau1_cmd_s) or (tau2_cmd_s <> tau2_cmd_s) or (f3_cmd_s <> f3_cmd_s) or
    (wristFx <> wristFx) or (wristFy <> wristFy) or (wristFz <> wristFz) or
    (wristTx <> wristTx) or (wristTy <> wristTy) or (wristTz <> wristTz) or
    (wristForceNorm <> wristForceNorm) or (wristWrenchNorm <> wristWrenchNorm) or
    (e1 <> e1) or (e2 <> e2) or (e3 <> e3) or (wristErr <> wristErr) or (corr3 <> corr3) or
    (abs(q1) > 1.0e300) or (abs(q2) > 1.0e300) or (abs(q3) > 1.0e300) or
    (abs(w1) > 1.0e300) or (abs(w2) > 1.0e300) or (abs(v3) > 1.0e300) or
    (abs(tau1_sat_s) > 1.0e300) or (abs(tau2_sat_s) > 1.0e300) or (abs(f3_sat_s) > 1.0e300) or
    (abs(tau1_cmd_s) > 1.0e300) or (abs(tau2_cmd_s) > 1.0e300) or (abs(f3_cmd_s) > 1.0e300) or
    (abs(e1) > 1.0e300) or (abs(e2) > 1.0e300) or (abs(e3) > 1.0e300) or (abs(corr3) > 1.0e300)
  );

  failClosed = effortBoundsOK and jointBoundsOK and wrenchOK and payloadRetained and poseOK and finiteOK;
  failure = not failClosed;

algorithm
  when sample(0, Ts) then
    // Synchronized state and sensor traces.
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
    wristWrenchNorm_s := wristWrenchNorm;
    trackErr_s := trackErr;

    // Sampled desired trajectory.
    q1_des_s := q1_des;
    q2_des_s := q2_des;
    q3_des_s := q3_des;
    v3_des_s := v3_des;
    a1_des_s := a1_des;
    a2_des_s := a2_des;
    a3_des_s := a3_des;

    // Encoder errors.
    e1 := q1_des_s - q1;
    e2 := q2_des_s - q2;
    e3 := q3_des_s - q3;

    // Bounded wrist-force correction.
    wristErr := max(wristForceNorm_s - Fw_limit, 0.0);
    dir3 := if wristFx_s > eps then 1.0 elseif wristFx_s < -eps then -1.0 else 0.0;
    corr1 := 0.0;
    corr2 := 0.0;
    corr3 := max(-wristCorrBound, min(wristCorrBound, -Kw*wristErr*dir3));

    // Computed-torque control with disturbance feedforward.
    tau1_cmd_s := J1*(a1_des_s + Kp1*e1 + Kd1*(0.0 - w1)) + Td1 + corr1;
    tau2_cmd_s := J2*(a2_des_s + Kp2*e2 + Kd2*(0.0 - w2)) + Td2 + corr2;
    f3_cmd_s := m_eff*(a3_des_s + Kp3*e3 + Kd3*(v3_des_s - v3)) + Fd + corr3;

    // Effort bounds.
    tau1_sat_s := max(-tau_max, min(tau_max, tau1_cmd_s));
    tau2_sat_s := max(-tau_max, min(tau_max, tau2_cmd_s));
    f3_sat_s := max(-f_max, min(f_max, f3_cmd_s));

    failClosed_s := failClosed;
    failure_s := not failClosed;
  end when;

  annotation(experiment(StopTime=16.0, Interval=0.004, Tolerance=1.0e-6));
end ForkArmCarryE;