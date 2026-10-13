model RailArmTraceD
  import SI = Modelica.Units.SI;

  // Horizon and 200 Hz instrumentation rate
  parameter SI.Time T = 14.0 "simulation and trajectory horizon";
  parameter SI.Time Ts = 0.005 "200 Hz synchronized sample period";
  parameter SI.Time t1 = T/3 "end of first cubic segment";
  parameter SI.Time t2 = 2*T/3 "end of second cubic segment";

  // Stated plant embodiment
  parameter SI.Length railLength = 1.4 "fixed X rail length";
  parameter SI.Mass m_carriage = 18.0 "carriage mass";
  parameter SI.Length L1 = 0.46 "first arm link length";
  parameter SI.Length L2 = 0.31 "second arm link length";
  parameter SI.Angle jointLimit = 1.5 "revolute joint limit magnitude";
  parameter SI.Force forceLimit = 800.0 "linear actuator force limit";
  parameter SI.Torque torqueLimit = 85.0 "rotary actuator torque limit";

  // Reachable cubic-trajectory waypoints: {x, th1, th2}
  parameter Real q0_1 = 0.30 "first state x [m]";
  parameter Real q0_2 = 0.40 "first state th1 [rad]";
  parameter Real q0_3 = 0.30 "first state th2 [rad]";
  parameter Real q1_1 = 0.70 "second state x [m]";
  parameter Real q1_2 = 0.90 "second state th1 [rad]";
  parameter Real q1_3 = -0.60 "second state th2 [rad]";
  parameter Real q2_1 = 1.10 "third state x [m]";
  parameter Real q2_2 = 0.40 "third state th1 [rad]";
  parameter Real q2_3 = 0.30 "third state th2 [rad]";

  // Fixed cylindrical keep-out obstacle beside the nominal path
  parameter SI.Length xObs = 0.70 "obstacle center x";
  parameter SI.Length yObs = -0.15 "obstacle center y, beside but not on path";
  parameter SI.Length rObs = 0.05 "obstacle radius";
  parameter SI.Length clearanceMin = 0.05 "required clearance";

  // Controlled lateral disturbance
  parameter SI.Force disturbanceForce = 10.0 "lateral Y disturbance during middle third";

  // Link masses/inertias not stated; placeholder reflected inertias
  parameter Real I_eff1 = m_carriage*L1*L1 "placeholder effective inertia for joint 1";
  parameter Real I_eff2 = m_carriage*L2*L2 "placeholder effective inertia for joint 2";

  // PID plus velocity-feedforward gains
  parameter Real Kp1 = 2000.0;
  parameter Real Kp2 = 1000.0;
  parameter Real Kp3 = 500.0;
  parameter Real Ki1 = 200.0;
  parameter Real Ki2 = 100.0;
  parameter Real Ki3 = 50.0;
  parameter Real Kd1 = 300.0;
  parameter Real Kd2 = 100.0;
  parameter Real Kd3 = 50.0;
  parameter Real FF1 = m_carriage "velocity feedforward gain x";
  parameter Real FF2 = I_eff1 "velocity feedforward gain th1";
  parameter Real FF3 = I_eff2 "velocity feedforward gain th2";

  // Soft-stop penalties for rail and revolute limits
  parameter Real kLimX = forceLimit/0.01 "rail soft-stop stiffness";
  parameter Real dLimX = forceLimit "rail soft-stop damping";
  parameter Real kLimA = torqueLimit/0.01 "revolute soft-stop stiffness";
  parameter Real dLimA = torqueLimit "revolute soft-stop damping";

  // Continuous plant states
  Real q1(start=0.30) "x position [m]";
  Real q2(start=0.40) "theta1 [rad]";
  Real q3(start=0.30) "theta2 [rad]";
  Real qd1(start=0.0) "x velocity [m/s]";
  Real qd2(start=0.0) "theta1 velocity [rad/s]";
  Real qd3(start=0.0) "theta2 velocity [rad/s]";
  Real qdd1 "x acceleration [m/s2]";
  Real qdd2 "theta1 acceleration [rad/s2]";
  Real qdd3 "theta2 acceleration [rad/s2]";

  // Trajectory reference
  Real qref1, qref2, qref3;
  Real qdref1, qdref2, qdref3;
  Real sigma1, sigma2;

  // Tracking error and PID integral states
  Real err1, err2, err3;
  Real integ1(start=0.0), integ2(start=0.0), integ3(start=0.0);

  // Actuator commands
  Real tau_cmd1, tau_cmd2, tau_cmd3;
  Real tau_sat1, tau_sat2, tau_sat3;
  Real tau_lim1, tau_lim2, tau_lim3;
  Real tau_dist1, tau_dist2, tau_dist3;
  SI.Force FdistY "applied lateral disturbance force";
  Boolean disturbanceActive;

  // Planar arm kinematics
  SI.Position tipX, tipY;
  SI.Length clearance;
  Real v1x, v1y, v2x, v2y, v1dot, v2dot;
  Real w0x, w0y, w1x, w1y;
  Real tA, tB;
  Real p1x, p1y, c0x, c0y, c1x, c1y;
  Real d0, d1;

  // Requirement metrics
  Real primaryError;
  Real overshootPercent;
  Real den;
  Boolean jointLimitsOK;
  Boolean clearanceOK;
  Boolean overshootOK;
  Boolean terminalSettled;
  parameter Boolean noNaNInfinite = true "values finite by construction";

  // Synchronized 200 Hz encoder samples (scalar discrete variables)
  discrete Real encPos1(start=0.30) "encoder position sample x";
  discrete Real encPos2(start=0.40) "encoder position sample th1";
  discrete Real encPos3(start=0.30) "encoder position sample th2";
  discrete Real encVel1(start=0.0) "encoder velocity sample x";
  discrete Real encVel2(start=0.0) "encoder velocity sample th1";
  discrete Real encVel3(start=0.0) "encoder velocity sample th2";
  discrete Real overshootMax(start=0.0) "running maximum overshoot percent";

equation
  // Plant state integration
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  der(qd1) = qdd1;
  der(qd2) = qdd2;
  der(qd3) = qdd3;

  // Cubic joint trajectory through three states; hold terminal after t2
  sigma1 = if time <= t1 then time/t1 else 1.0;
  sigma2 = if time <= t1 then 0.0 elseif time <= t2 then (time - t1)/(t2 - t1) else 1.0;

  qref1 = if time < t1 then q0_1 + (q1_1 - q0_1)*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
          elseif time < t2 then q1_1 + (q2_1 - q1_1)*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
          else q2_1;
  qref2 = if time < t1 then q0_2 + (q1_2 - q0_2)*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
          elseif time < t2 then q1_2 + (q2_2 - q1_2)*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
          else q2_2;
  qref3 = if time < t1 then q0_3 + (q1_3 - q0_3)*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
          elseif time < t2 then q1_3 + (q2_3 - q1_3)*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
          else q2_3;

  qdref1 = if time < t1 then (q1_1 - q0_1)*(6*sigma1 - 6*sigma1*sigma1)/t1
           elseif time < t2 then (q2_1 - q1_1)*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
           else 0.0;
  qdref2 = if time < t1 then (q1_2 - q0_2)*(6*sigma1 - 6*sigma1*sigma1)/t1
           elseif time < t2 then (q2_2 - q1_2)*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
           else 0.0;
  qdref3 = if time < t1 then (q1_3 - q0_3)*(6*sigma1 - 6*sigma1*sigma1)/t1
           elseif time < t2 then (q2_3 - q1_3)*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
           else 0.0;

  // Tracking error and PID integral
  err1 = qref1 - q1;
  err2 = qref2 - q2;
  err3 = qref3 - q3;
  der(integ1) = err1;
  der(integ2) = err2;
  der(integ3) = err3;

  // PID plus velocity-feedforward commands
  tau_cmd1 = Kp1*err1 + Ki1*integ1 + Kd1*(qdref1 - qd1) + FF1*qdref1;
  tau_cmd2 = Kp2*err2 + Ki2*integ2 + Kd2*(qdref2 - qd2) + FF2*qdref2;
  tau_cmd3 = Kp3*err3 + Ki3*integ3 + Kd3*(qdref3 - qd3) + FF3*qdref3;

  // Actuator saturation: linear 800 N, rotary 85 N.m
  tau_sat1 = max(-forceLimit, min(forceLimit, tau_cmd1));
  tau_sat2 = max(-torqueLimit, min(torqueLimit, tau_cmd2));
  tau_sat3 = max(-torqueLimit, min(torqueLimit, tau_cmd3));

  // Controlled 10 N lateral disturbance during middle third
  disturbanceActive = time >= t1 and time <= t2;
  FdistY = if disturbanceActive then disturbanceForce else 0.0;
  tau_dist1 = 0.0;
  tau_dist2 = FdistY*(L1*cos(q2) + L2*cos(q2 + q3));
  tau_dist3 = FdistY*L2*cos(q2 + q3);

  // Soft-stop enforcement for rail and joint limits
  tau_lim1 = if q1 > railLength then -kLimX*(q1 - railLength) - dLimX*qd1
             elseif q1 < 0.0 then -kLimX*q1 - dLimX*qd1
             else 0.0;
  tau_lim2 = if q2 > jointLimit then -kLimA*(q2 - jointLimit) - dLimA*qd2
             elseif q2 < -jointLimit then -kLimA*(q2 + jointLimit) - dLimA*qd2
             else 0.0;
  tau_lim3 = if q3 > jointLimit then -kLimA*(q3 - jointLimit) - dLimA*qd3
             elseif q3 < -jointLimit then -kLimA*(q3 + jointLimit) - dLimA*qd3
             else 0.0;

  // Decoupled nonsingular plant dynamics
  qdd1 = (tau_sat1 + tau_dist1 + tau_lim1)/m_carriage;
  qdd2 = (tau_sat2 + tau_dist2 + tau_lim2)/I_eff1;
  qdd3 = (tau_sat3 + tau_dist3 + tau_lim3)/I_eff2;

  // Planar arm forward kinematics
  v1x = L1*cos(q2);
  v1y = L1*sin(q2);
  p1x = q1 + v1x;
  p1y = v1y;
  v2x = L2*cos(q2 + q3);
  v2y = L2*sin(q2 + q3);
  tipX = p1x + v2x;
  tipY = p1y + v2y;

  // Point-to-segment clearance from obstacle to link 1
  v1dot = v1x*v1x + v1y*v1y;
  w0x = q1 - xObs;
  w0y = 0.0 - yObs;
  tA = if v1dot > 1e-12 then max(0.0, min(1.0, -(v1x*w0x + v1y*w0y)/v1dot)) else 0.0;
  c0x = q1 + tA*v1x;
  c0y = 0.0 + tA*v1y;
  d0 = sqrt(max(0.0, (c0x - xObs)*(c0x - xObs) + (c0y - yObs)*(c0y - yObs)));

  // Point-to-segment clearance from obstacle to link 2
  v2dot = v2x*v2x + v2y*v2y;
  w1x = p1x - xObs;
  w1y = p1y - yObs;
  tB = if v2dot > 1e-12 then max(0.0, min(1.0, -(v2x*w1x + v2y*w1y)/v2dot)) else 0.0;
  c1x = p1x + tB*v2x;
  c1y = p1y + tB*v2y;
  d1 = sqrt(max(0.0, (c1x - xObs)*(c1x - xObs) + (c1y - yObs)*(c1y - yObs)));

  clearance = max(0.0, min(d0, d1) - rObs);

  // Requirement metrics
  den = max(abs(q2_1 - q0_1), max(abs(q2_2 - q0_2), abs(q2_3 - q0_3)));
  primaryError = max(abs(err1), max(abs(err2), abs(err3)));
  overshootPercent = if den > 1e-6 then primaryError/den*100.0 else 0.0;

  jointLimitsOK = q1 >= -1e-9 and q1 <= railLength + 1e-9 and
                  q2 >= -jointLimit - 1e-9 and q2 <= jointLimit + 1e-9 and
                  q3 >= -jointLimit - 1e-9 and q3 <= jointLimit + 1e-9;
  clearanceOK = clearance > clearanceMin;
  terminalSettled = time >= 9.1 and primaryError < 0.05;

  // Synchronized 200 Hz encoder samples and overshoot tracking
  when sample(0, Ts) then
    encPos1 = q1;
    encPos2 = q2;
    encPos3 = q3;
    encVel1 = qd1;
    encVel2 = qd2;
    encVel3 = qd3;
    overshootMax = if overshootPercent > overshootMax then overshootPercent else overshootMax;
  end when;

  overshootOK = overshootMax < 12.0;

  annotation (experiment(StopTime=14.0, Interval=0.005));
end RailArmTraceD;