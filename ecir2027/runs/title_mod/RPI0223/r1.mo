model AssemblyArmTraceA
  "Fixed-base articulated manipulator, four Z/Y/Y/X revolute joints, cubic trajectory, PID+velocity feedforward, keep-out cylinder, disturbance, 80 Hz traces"

  // Sampling and scenario timing
  parameter Modelica.SIunits.Time Ts=0.0125 "80 Hz synchronized sample period";
  parameter Integer N=641 "samples over 8 s including t=0";
  parameter Modelica.SIunits.Time t0=0.0 "initial state time";
  parameter Modelica.SIunits.Time t1=8.0/3.0 "second state time";
  parameter Modelica.SIunits.Time t2=5.0 "third/final state time";
  parameter Modelica.SIunits.Time tEnd=8.0 "scenario duration";
  parameter Modelica.SIunits.Time tDistStart=tEnd/3.0 "middle third start";
  parameter Modelica.SIunits.Time tDistEnd=2.0*tEnd/3.0 "middle third end";

  // Link lengths and masses (given)
  parameter Modelica.SIunits.Length L1=0.50 "capsule-link length 1";
  parameter Modelica.SIunits.Length L2=0.40 "capsule-link length 2";
  parameter Modelica.SIunits.Length L3=0.28 "capsule-link length 3";
  parameter Modelica.SIunits.Length L4=0.16 "capsule-link length 4";
  parameter Modelica.SIunits.Mass m1=7.0 "link 1 mass";
  parameter Modelica.SIunits.Mass m2=5.0 "link 2 mass";
  parameter Modelica.SIunits.Mass m3=3.0 "link 3 mass";
  parameter Modelica.SIunits.Mass m4=1.0 "link 4 mass";

  // Inertias: capsule radii are not specified; uniform slender rod about joint end is used
  parameter Modelica.SIunits.Inertia J1=m1*L1^2/3.0;
  parameter Modelica.SIunits.Inertia J2=m2*L2^2/3.0;
  parameter Modelica.SIunits.Inertia J3=m3*L3^2/3.0;
  parameter Modelica.SIunits.Inertia J4=m4*L4^2/3.0;

  // Joint limits
  parameter Modelica.SIunits.Angle q1Min=-Modelica.Constants.pi;
  parameter Modelica.SIunits.Angle q1Max=Modelica.Constants.pi;
  parameter Modelica.SIunits.Angle q2Min=-Modelica.Constants.pi;
  parameter Modelica.SIunits.Angle q2Max=Modelica.Constants.pi;
  parameter Modelica.SIunits.Angle q3Min=-Modelica.Constants.pi;
  parameter Modelica.SIunits.Angle q3Max=Modelica.Constants.pi;
  parameter Modelica.SIunits.Angle q4Min=-Modelica.Constants.pi;
  parameter Modelica.SIunits.Angle q4Max=Modelica.Constants.pi;

  // Reachable trajectory states (state0, state1, state2)
  parameter Modelica.SIunits.Angle q1_0=0.0;
  parameter Modelica.SIunits.Angle q2_0=0.0;
  parameter Modelica.SIunits.Angle q3_0=0.0;
  parameter Modelica.SIunits.Angle q4_0=0.0;
  parameter Modelica.SIunits.Angle q1_1=0.0;
  parameter Modelica.SIunits.Angle q2_1=0.40;
  parameter Modelica.SIunits.Angle q3_1=0.30;
  parameter Modelica.SIunits.Angle q4_1=0.20;
  parameter Modelica.SIunits.Angle q1_2=0.0;
  parameter Modelica.SIunits.Angle q2_2=0.80;
  parameter Modelica.SIunits.Angle q3_2=0.50;
  parameter Modelica.SIunits.Angle q4_2=0.40;

  // Saturated effort limit
  parameter Modelica.SIunits.Torque tauMax=79.2;

  // Controller gains (PID plus velocity feedforward)
  parameter Real Kp1=600 "N.m/rad";
  parameter Real Kp2=300 "N.m/rad";
  parameter Real Kp3=150 "N.m/rad";
  parameter Real Kp4=50 "N.m/rad";
  parameter Real Ki1=20 "N.m/(rad.s)";
  parameter Real Ki2=10 "N.m/(rad.s)";
  parameter Real Ki3=5 "N.m/(rad.s)";
  parameter Real Ki4=1 "N.m/(rad.s)";
  parameter Real Kd1=120 "N.m/(rad/s)";
  parameter Real Kd2=60 "N.m/(rad/s)";
  parameter Real Kd3=20 "N.m/(rad/s)";
  parameter Real Kd4=4 "N.m/(rad/s)";
  parameter Real Kff1=0.5 "velocity feedforward, N.m/(rad/s)";
  parameter Real Kff2=0.2 "velocity feedforward, N.m/(rad/s)";
  parameter Real Kff3=0.1 "velocity feedforward, N.m/(rad/s)";
  parameter Real Kff4=0.05 "velocity feedforward, N.m/(rad/s)";

  // Fixed cylindrical keep-out obstacle beside nominal y=0 path
  parameter Modelica.SIunits.Length obstacleX=1.10;
  parameter Modelica.SIunits.Length obstacleY=0.50;
  parameter Modelica.SIunits.Length obstacleZ0=-1.00;
  parameter Modelica.SIunits.Length obstacleZ1=1.00;
  parameter Modelica.SIunits.Length obstacleR=0.05;

  // Continuous joint states
  Modelica.SIunits.Angle q1(start=q1_0) "joint 1 angle, Z axis";
  Modelica.SIunits.Angle q2(start=q2_0) "joint 2 angle, Y axis";
  Modelica.SIunits.Angle q3(start=q3_0) "joint 3 angle, Y axis";
  Modelica.SIunits.Angle q4(start=q4_0) "joint 4 angle, X axis";
  Modelica.SIunits.AngularVelocity w1(start=0) "joint 1 velocity";
  Modelica.SIunits.AngularVelocity w2(start=0) "joint 2 velocity";
  Modelica.SIunits.AngularVelocity w3(start=0) "joint 3 velocity";
  Modelica.SIunits.AngularVelocity w4(start=0) "joint 4 velocity";

  // Trajectory references
  Modelica.SIunits.Angle q1_des;
  Modelica.SIunits.Angle q2_des;
  Modelica.SIunits.Angle q3_des;
  Modelica.SIunits.Angle q4_des;
  Modelica.SIunits.AngularVelocity qd1_des;
  Modelica.SIunits.AngularVelocity qd2_des;
  Modelica.SIunits.AngularVelocity qd3_des;
  Modelica.SIunits.AngularVelocity qd4_des;
  Modelica.SIunits.AngularAcceleration qdd1_des;
  Modelica.SIunits.AngularAcceleration qdd2_des;
  Modelica.SIunits.AngularAcceleration qdd3_des;
  Modelica.SIunits.AngularAcceleration qdd4_des;

  // Commands and disturbance torques
  discrete Modelica.SIunits.Torque tau1_cmd(start=0);
  discrete Modelica.SIunits.Torque tau2_cmd(start=0);
  discrete Modelica.SIunits.Torque tau3_cmd(start=0);
  discrete Modelica.SIunits.Torque tau4_cmd(start=0);
  Modelica.SIunits.Torque tauDist1;
  Modelica.SIunits.Torque tauDist2;
  Modelica.SIunits.Torque tauDist3;
  Modelica.SIunits.Torque tauDist4;
  Modelica.SIunits.Force FdistY "lateral disturbance force in y";

  // Sensors
  discrete Modelica.SIunits.Angle q1_s(start=q1_0);
  discrete Modelica.SIunits.Angle q2_s(start=q2_0);
  discrete Modelica.SIunits.Angle q3_s(start=q3_0);
  discrete Modelica.SIunits.Angle q4_s(start=q4_0);
  discrete Modelica.SIunits.AngularVelocity qd1_s(start=0);
  discrete Modelica.SIunits.AngularVelocity qd2_s(start=0);
  discrete Modelica.SIunits.AngularVelocity qd3_s(start=0);
  discrete Modelica.SIunits.AngularVelocity qd4_s(start=0);

  // Control intermediates
  discrete Modelica.SIunits.Angle e1;
  discrete Modelica.SIunits.Angle e2;
  discrete Modelica.SIunits.Angle e3;
  discrete Modelica.SIunits.Angle e4;
  discrete Modelica.SIunits.AngularVelocity ed1;
  discrete Modelica.SIunits.AngularVelocity ed2;
  discrete Modelica.SIunits.AngularVelocity ed3;
  discrete Modelica.SIunits.AngularVelocity ed4;
  discrete Modelica.SIunits.Torque raw1;
  discrete Modelica.SIunits.Torque raw2;
  discrete Modelica.SIunits.Torque raw3;
  discrete Modelica.SIunits.Torque raw4;
  discrete Real integ1(start=0) "integral term 1, rad.s";
  discrete Real integ2(start=0) "integral term 2, rad.s";
  discrete Real integ3(start=0) "integral term 3, rad.s";
  discrete Real integ4(start=0) "integral term 4, rad.s";

  // Requirement metrics
  Modelica.SIunits.Angle primaryError;
  Modelica.SIunits.AngularVelocity maxAbsVel;
  discrete Real overshoot2(start=0);
  discrete Real overshoot3(start=0);
  discrete Real overshoot4(start=0);
  Real overshootFrac;
  Boolean settled;
  Modelica.SIunits.Length clearance;

  // Forward kinematics and obstacle distances
  Modelica.SIunits.Position p1x,p1y,p1z;
  Modelica.SIunits.Position p2x,p2y,p2z;
  Modelica.SIunits.Position p3x,p3y,p3z;
  Modelica.SIunits.Position p4x,p4y,p4z;
  Modelica.SIunits.Length dxy1,dxy2,dxy3,dxy4;
  Modelica.SIunits.Length clear1,clear2,clear3,clear4;

  // Traces
  discrete Modelica.SIunits.Time traceTime[N];
  discrete Modelica.SIunits.Angle traceQ1[N];
  discrete Modelica.SIunits.Angle traceQ2[N];
  discrete Modelica.SIunits.Angle traceQ3[N];
  discrete Modelica.SIunits.Angle traceQ4[N];
  discrete Modelica.SIunits.AngularVelocity traceQd1[N];
  discrete Modelica.SIunits.AngularVelocity traceQd2[N];
  discrete Modelica.SIunits.AngularVelocity traceQd3[N];
  discrete Modelica.SIunits.AngularVelocity traceQd4[N];
  discrete Modelica.SIunits.Torque traceCmd1[N];
  discrete Modelica.SIunits.Torque traceCmd2[N];
  discrete Modelica.SIunits.Torque traceCmd3[N];
  discrete Modelica.SIunits.Torque traceCmd4[N];
  discrete Modelica.SIunits.Angle traceSensQ1[N];
  discrete Modelica.SIunits.Angle traceSensQ2[N];
  discrete Modelica.SIunits.Angle traceSensQ3[N];
  discrete Modelica.SIunits.Angle traceSensQ4[N];
  discrete Modelica.SIunits.AngularVelocity traceSensQd1[N];
  discrete Modelica.SIunits.AngularVelocity traceSensQd2[N];
  discrete Modelica.SIunits.AngularVelocity traceSensQd3[N];
  discrete Modelica.SIunits.AngularVelocity traceSensQd4[N];
  discrete Integer k(start=0);

protected
  Real dt1=max(t1-t0,1e-9);
  Real dt2=max(t2-t1,1e-9);
  Real s1=if time <= t0 then 0.0 elseif time >= t1 then 1.0 else (time-t0)/dt1;
  Real s2=if time >= t2 then 1.0 elseif time <= t1 then 0.0 else (time-t1)/dt2;
  Real c1=cos(q1);
  Real s1q=sin(q1);
  Real c2=cos(q2);
  Real s2q=sin(q2);
  Real c23=cos(q2+q3);
  Real s23=sin(q2+q3);
  Modelica.SIunits.Length A2=L1+L2*c2;
  Modelica.SIunits.Length A3=L1+L2*c2+L3*c23;
  Modelica.SIunits.Length A4=L1+L2*c2+(L3+L4)*c23;

equation
  // Cubic Hermite trajectory with zero endpoint velocities, then hold final state
  q1_des = if time <= t1 then q1_0+(q1_1-q1_0)*(3.0*s1*s1-2.0*s1*s1*s1) else q1_1+(q1_2-q1_1)*(3.0*s2*s2-2.0*s2*s2*s2);
  q2_des = if time <= t1 then q2_0+(q2_1-q2_0)*(3.0*s1*s1-2.0*s1*s1*s1) else q2_1+(q2_2-q2_1)*(3.0*s2*s2-2.0*s2*s2*s2);
  q3_des = if time <= t1 then q3_0+(q3_1-q3_0)*(3.0*s1*s1-2.0*s1*s1*s1) else q3_1+(q3_2-q3_1)*(3.0*s2*s2-2.0*s2*s2*s2);
  q4_des = if time <= t1 then q4_0+(q4_1-q4_0)*(3.0*s1*s1-2.0*s1*s1*s1) else q4_1+(q4_2-q4_1)*(3.0*s2*s2-2.0*s2*s2*s2);

  qd1_des = if time <= t1 then (q1_1-q1_0)*(6.0*s1-6.0*s1*s1)/dt1 else (q1_2-q1_1)*(6.0*s2-6.0*s2*s2)/dt2;
  qd2_des = if time <= t1 then (q2_1-q2_0)*(6.0*s1-6.0*s1*s1)/dt1 else (q2_2-q2_1)*(6.0*s2-6.0*s2*s2)/dt2;
  qd3_des = if time <= t1 then (q3_1-q3_0)*(6.0*s1-6.0*s1*s1)/dt1 else (q3_2-q3_1)*(6.0*s2-6.0*s2*s2)/dt2;
  qd4_des = if time <= t1 then (q4_1-q4_0)*(6.0*s1-6.0*s1*s1)/dt1 else (q4_2-q4_1)*(6.0*s2-6.0*s2*s2)/dt2;

  qdd1_des = if time <= t1 then (q1_1-q1_0)*(6.0-12.0*s1)/(dt1*dt1) elseif time >= t2 then 0.0 else (q1_2-q1_1)*(6.0-12.0*s2)/(dt2*dt2);
  qdd2_des = if time <= t1 then (q2_1-q2_0)*(6.0-12.0*s1)/(dt1*dt1) elseif time >= t2 then 0.0 else (q2_2-q2_1)*(6.0-12.0*s2)/(dt2*dt2);
  qdd3_des = if time <= t1 then (q3_1-q3_0)*(6.0-12.0*s1)/(dt1*dt1) elseif time >= t2 then 0.0 else (q3_2-q3_1)*(6.0-12.0*s2)/(dt2*dt2);
  qdd4_des = if time <= t1 then (q4_1-q4_0)*(6.0-12.0*s1)/(dt1*dt1) elseif time >= t2 then 0.0 else (q4_2-q4_1)*(6.0-12.0*s2)/(dt2*dt2);

  // Forward kinematics for link endpoints
  p1x = c1*L1;
  p1y = s1q*L1;
  p1z = 0.0;
  p2x = c1*A2;
  p2y = s1q*A2;
  p2z = -L2*s2q;
  p3x = c1*A3;
  p3y = s1q*A3;
  p3z = -L2*s2q-L3*s23;
  p4x = c1*A4;
  p4y = s1q*A4;
  p4z = -L2*s2q-(L3+L4)*s23;

  // Obstacle distances; capsule radii are not specified, so clearance uses link centerlines
  dxy1 = sqrt((p1x-obstacleX)^2+(p1y-obstacleY)^2);
  dxy2 = sqrt((p2x-obstacleX)^2+(p2y-obstacleY)^2);
  dxy3 = sqrt((p3x-obstacleX)^2+(p3y-obstacleY)^2);
  dxy4 = sqrt((p4x-obstacleX)^2+(p4y-obstacleY)^2);
  clear1 = if p1z < obstacleZ0 then sqrt(dxy1^2+(obstacleZ0-p1z)^2)-obstacleR elseif p1z > obstacleZ1 then sqrt(dxy1^2+(p1z-obstacleZ1)^2)-obstacleR else dxy1-obstacleR;
  clear2 = if p2z < obstacleZ0 then sqrt(dxy2^2+(obstacleZ0-p2z)^2)-obstacleR elseif p2z > obstacleZ1 then sqrt(dxy2^2+(p2z-obstacleZ1)^2)-obstacleR else dxy2-obstacleR;
  clear3 = if p3z < obstacleZ0 then sqrt(dxy3^2+(obstacleZ0-p3z)^2)-obstacleR elseif p3z > obstacleZ1 then sqrt(dxy3^2+(p3z-obstacleZ1)^2)-obstacleR else dxy3-obstacleR;
  clear4 = if p4z < obstacleZ0 then sqrt(dxy4^2+(obstacleZ0-p4z)^2)-obstacleR elseif p4z > obstacleZ1 then sqrt(dxy4^2+(p4z-obstacleZ1)^2)-obstacleR else dxy4-obstacleR;
  clearance = min(min(clear1,clear2),min(clear3,clear4));

  // Lateral disturbance force in y, active during middle third
  FdistY = if time >= tDistStart and time <= tDistEnd then 5.0 else 0.0;
  tauDist1 = FdistY*c1*A4;
  tauDist2 = FdistY*s1q*(-L2*s2q-(L3+L4)*s23);
  tauDist3 = FdistY*s1q*(-(L3+L4)*s23);
  tauDist4 = 0.0;

  // Plant dynamics
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(q4) = w4;
  J1*der(w1) = tau1_cmd + tauDist1;
  J2*der(w2) = tau2_cmd + tauDist2;
  J3*der(w3) = tau3_cmd + tauDist3;
  J4*der(w4) = tau4_cmd + tauDist4;

  // Requirement metrics
  primaryError = max(abs(q1-q1_des),max(abs(q2-q2_des),max(abs(q3-q3_des),abs(q4-q4_des))));
  maxAbsVel = max(abs(w1),max(abs(w2),max(abs(w3),abs(w4))));
  overshootFrac = max(overshoot2,max(overshoot3,overshoot4));
  settled = time >= 5.2 and primaryError <= 0.068;

  // Requirement assertions
  assert(q1 >= q1Min and q1 <= q1Max, "joint 1 limit violated");
  assert(q2 >= q2Min and q2 <= q2Max, "joint 2 limit violated");
  assert(q3 >= q3Min and q3 <= q3Max, "joint 3 limit violated");
  assert(q4 >= q4Min and q4 <= q4Max, "joint 4 limit violated");
  assert(clearance > 0.05, "obstacle clearance below 0.05 m");
  assert(overshootFrac < 0.12, "overshoot exceeds 12 percent");
  assert(time <= 5.2 or primaryError <= 0.068, "primary tracking error after 5.2 s exceeds 0.068 rad");
  assert(abs(q1) <= 1e6 and abs(q2) <= 1e6 and abs(q3) <= 1e6 and abs(q4) <= 1e6 and
         abs(w1) <= 1e6 and abs(w2) <= 1e6 and abs(w3) <= 1e6 and abs(w4) <= 1e6 and
         abs(tau1_cmd) <= 1e6 and abs(tau2_cmd) <= 1e6 and abs(tau3_cmd) <= 1e6 and abs(tau4_cmd) <= 1e6 and
         abs(q1_s) <= 1e6 and abs(q2_s) <= 1e6 and abs(q3_s) <= 1e6 and abs(q4_s) <= 1e6,
         "non-finite physical/control/sensor value detected");

algorithm
  when sample(0,Ts) then
    // Synchronized encoder samples
    q1_s := q1;
    q2_s := q2;
    q3_s := q3;
    q4_s := q4;
    qd1_s := w1;
    qd2_s := w2;
    qd3_s := w3;
    qd4_s := w4;

    // PID plus velocity-feedforward control with anti-windup and effort saturation
    e1 := q1_des - q1_s;
    e2 := q2_des - q2_s;
    e3 := q3_des - q3_s;
    e4 := q4_des - q4_s;
    ed1 := qd1_des - qd1_s;
    ed2 := qd2_des - qd2_s;
    ed3 := qd3_des - qd3_s;
    ed4 := qd4_des - qd4_s;

    raw1 := Kp1*e1 + Ki1*pre(integ1) + Kd1*ed1 + Kff1*qd1_des;
    raw2 := Kp2*e2 + Ki2*pre(integ2) + Kd2*ed2 + Kff2*qd2_des;
    raw3 := Kp3*e3 + Ki3*pre(integ3) + Kd3*ed3 + Kff3*qd3_des;
    raw4 := Kp4*e4 + Ki4*pre(integ4) + Kd4*ed4 + Kff4*qd4_des;

    if raw1 > tauMax then
      tau1_cmd := tauMax;
      integ1 := pre(integ1);
    elseif raw1 < -tauMax then
      tau1_cmd := -tauMax;
      integ1 := pre(integ1);
    else
      tau1_cmd := raw1;
      integ1 := pre(integ1) + Ts*e1;
    end if;

    if raw2 > tauMax then
      tau2_cmd := tauMax;
      integ2 := pre(integ2);
    elseif raw2 < -tauMax then
      tau2_cmd := -tauMax;
      integ2 := pre(integ2);
    else
      tau2_cmd := raw2;
      integ2 := pre(integ2) + Ts*e2;
    end if;

    if raw3 > tauMax then
      tau3_cmd := tauMax;
      integ3 := pre(integ3);
    elseif raw3 < -tauMax then
      tau3_cmd := -tauMax;
      integ3 := pre(integ3);
    else
      tau3_cmd := raw3;
      integ3 := pre(integ3) + Ts*e3;
    end if;

    if raw4 > tauMax then
      tau4_cmd := tauMax;
      integ4 := pre(integ4);
    elseif raw4 < -tauMax then
      tau4_cmd := -tauMax;
      integ4 := pre(integ4);
    else
      tau4_cmd := raw4;
      integ4 := pre(integ4) + Ts*e4;
    end if;

    // Overshoot fractions relative to final commanded displacement
    if time >= t2 then
      if abs(q2_2-q2_0) > 1e-6 then
        overshoot2 := if abs(q2-q2_2)/abs(q2_2-q2_0) > pre(overshoot2) then abs(q2-q2_2)/abs(q2_2-q2_0) else pre(overshoot2);
      else
        overshoot2 := 0.0;
      end if;
      if abs(q3_2-q3_0) > 1e-6 then
        overshoot3 := if abs(q3-q3_2)/abs(q3_2-q3_0) > pre(overshoot3) then abs(q3-q3_2)/abs(q3_2-q3_0) else pre(overshoot3);
      else
        overshoot3 := 0.0;
      end if;
      if abs(q4_2-q4_0) > 1e-6 then
        overshoot4 := if abs(q4-q4_2)/abs(q4_2-q4_0) > pre(overshoot4) then abs(q4-q4_2)/abs(q4_2-q4_0) else pre(overshoot4);
      else
        overshoot4 := 0.0;
      end if;
    else
      overshoot2 := pre(overshoot2);
      overshoot3 := pre(overshoot3);
      overshoot4 := pre(overshoot4);
    end if;

    // Synchronized state, command, and sensor traces
    k := if pre(k) < N then pre(k)+1 else N;
    traceTime[k] := time;
    traceQ1[k] := q1;
    traceQ2[k] := q2;
    traceQ3[k] := q3;
    traceQ4[k] := q4;
    traceQd1[k] := w1;
    traceQd2[k] := w2;
    traceQd3[k] := w3;
    traceQd4[k] := w4;
    traceCmd1[k] := tau1_cmd;
    traceCmd2[k] := tau2_cmd;
    traceCmd3[k] := tau3_cmd;
    traceCmd4[k] := tau4_cmd;
    traceSensQ1[k] := q1_s;
    traceSensQ2[k] := q2_s;
    traceSensQ3[k] := q3_s;
    traceSensQ4[k] := q4_s;
    traceSensQd1[k] := qd1_s;
    traceSensQd2[k] := qd2_s;
    traceSensQd3[k] := qd3_s;
    traceSensQd4[k] := qd4_s;
  end when;

  annotation (experiment(StopTime=8.0, Tolerance=1e-6));
end AssemblyArmTraceA;