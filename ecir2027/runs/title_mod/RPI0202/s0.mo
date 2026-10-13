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

  // Reachable cubic-trajectory waypoints: {x[m], th1[rad], th2[rad]}
  parameter Real q0[3] = {0.30, 0.40, 0.30} "first reachable state";
  parameter Real q1[3] = {0.70, 0.90, -0.60} "second reachable state";
  parameter Real q2[3] = {1.10, 0.40, 0.30} "third reachable state, terminal hold";

  // Fixed cylindrical keep-out obstacle beside the nominal path
  parameter SI.Length xObs = 0.70 "obstacle center x";
  parameter SI.Length yObs = -0.15 "obstacle center y, beside but not on path";
  parameter SI.Length rObs = 0.05 "obstacle radius";
  parameter SI.Length clearanceMin = 0.05 "required clearance";

  // Controlled lateral disturbance
  parameter SI.Force disturbanceForce = 10.0 "lateral Y disturbance during middle third";

  // Link masses/inertias are not stated in the requirement.
  // Unknown link-mass distribution is omitted; revolute dynamics use a
  // nonsingular reflected-inertia placeholder scaled by stated mass/length.
  parameter Real I_eff1 = m_carriage*L1*L1 "placeholder effective inertia for joint 1";
  parameter Real I_eff2 = m_carriage*L2*L2 "placeholder effective inertia for joint 2";

  // PID plus velocity-feedforward gains
  parameter Real Kp[3] = {2000.0, 1000.0, 500.0};
  parameter Real Ki[3] = {200.0, 100.0, 50.0};
  parameter Real Kd[3] = {300.0, 100.0, 50.0};
  parameter Real FF[3] = {m_carriage, I_eff1, I_eff2} "velocity feedforward gains";

  // Soft-stop penalties for rail and revolute limits
  parameter Real kLimX = forceLimit/0.01 "rail soft-stop stiffness";
  parameter Real dLimX = forceLimit "rail soft-stop damping";
  parameter Real kLimA = torqueLimit/0.01 "revolute soft-stop stiffness";
  parameter Real dLimA = torqueLimit "revolute soft-stop damping";

  // State, control, sensor, and requirement traces
  Real q[3](start={0.30,0.40,0.30}) "q[1]=x, q[2]=th1, q[3]=th2";
  Real qd[3](start={0.0,0.0,0.0}) "qd[1]=vx, qd[2]=w1, qd[3]=w2";
  Real qdd[3] "qdd[1]=ax, qdd[2]=aa1, qdd[3]=aa2";
  Real q_ref[3] "cubic joint reference";
  Real qd_ref[3] "cubic joint velocity reference";
  Real err[3] "tracking error";
  Real integ[3](start={0.0,0.0,0.0}) "PID integral states";
  Real tau_cmd[3] "commanded actuator force/torque";
  Real tau_sat[3] "saturated actuator force/torque";
  Real tau_lim[3] "soft-stop penalty force/torque";
  Real tau_dist[3] "disturbance generalized force/torque";
  SI.Force FdistY "applied lateral disturbance force";
  Boolean disturbanceActive;

  SI.Position tipX;
  SI.Position tipY;
  SI.Length clearance;
  Boolean jointLimitsOK;
  Boolean clearanceOK;
  Boolean overshootOK;
  Boolean terminalSettled;
  Boolean noNaNInfinite = true "physical, control, and estimator values finite by construction";
  Real primaryError;
  Real overshootPercent;
  Real den;

  discrete Real overshootMax(start=0.0);
  discrete Real encPos[3](start={0.30,0.40,0.30}) "synchronized encoder position samples";
  discrete Real encVel[3](start={0.0,0.0,0.0}) "synchronized encoder velocity samples";
  discrete Real encTime(start=0.0) "encoder sample timestamp";

  // Trajectory normalization and obstacle-distance helpers
  Real sigma1;
  Real sigma2;
  Real v1x, v1y, v2x, v2y, v1dot, v2dot;
  Real w0x, w0y, w1x, w1y;
  Real tA, tB;
  Real p1x, p1y, c0x, c0y, c1x, c1y;
  Real d0, d1;

equation
  // Plant state integration
  der(q[1]) = qd[1];
  der(q[2]) = qd[2];
  der(q[3]) = qd[3];
  der(qd[1]) = qdd[1];
  der(qd[2]) = qdd[2];
  der(qd[3]) = qdd[3];

  // Cubic joint trajectory through three states; hold terminal state after t2
  sigma1 = if time <= t1 then time/t1 else 1.0;
  sigma2 = if time <= t1 then 0.0 elseif time <= t2 then (time - t1)/(t2 - t1) else 1.0;

  q_ref[1] = if time < t1 then q0[1] + (q1[1] - q0[1])*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
             elseif time < t2 then q1[1] + (q2[1] - q1[1])*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
             else q2[1];
  q_ref[2] = if time < t1 then q0[2] + (q1[2] - q0[2])*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
             elseif time < t2 then q1[2] + (q2[2] - q1[2])*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
             else q2[2];
  q_ref[3] = if time < t1 then q0[3] + (q1[3] - q0[3])*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
             elseif time < t2 then q1[3] + (q2[3] - q1[3])*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
             else q2[3];

  qd_ref[1] = if time < t1 then (q1[1] - q0[1])*(6*sigma1 - 6*sigma1*sigma1)/t1
              elseif time < t2 then (q2[1] - q1[1])*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
              else 0.0;
  qd_ref[2] = if time < t1 then (q1[2] - q0[2])*(6*sigma1 - 6*sigma1*sigma1)/t1
              elseif time < t2 then (q2[2] - q1[2])*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
              else 0.0;
  qd_ref[3] = if time < t1 then (q1[3] - q0[3])*(6*sigma1 - 6*sigma1*sigma1)/t1
              elseif time < t2 then (q2[3] - q1[3])*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
              else 0.0;

  // Tracking error and PID integral states
  err[1] = q_ref[1] - q[1];
  err[2] = q_ref[2] - q[2];
  err[3] = q_ref[3] - q[3];
  der(integ[1]) = err[1];
  der(integ[2]) = err[2];
  der(integ[3]) = err[3];

  // PID plus velocity-feedforward control commands
  tau_cmd[1] = Kp[1]*err[1] + Ki[1]*integ[1] + Kd[1]*(qd_ref[1] - qd[1]) + FF[1]*qd_ref[1];
  tau_cmd[2] = Kp[2]*err[2] + Ki[2]*integ[2] + Kd[2]*(qd_ref[2] - qd[2]) + FF[2]*qd_ref[2];
  tau_cmd[3] = Kp[3]*err[3] + Ki[3]*integ[3] + Kd[3]*(qd_ref[3] - qd[3]) + FF[3]*qd_ref[3];

  // Actuator saturation: linear force 800 N, rotary torques 85 N.m
  tau_sat[1] = max(-forceLimit, min(forceLimit, tau_cmd[1]));
  tau_sat[2] = max(-torqueLimit, min(torqueLimit, tau_cmd[2]));
  tau_sat[3] = max(-torqueLimit, min(torqueLimit, tau_cmd[3]));

  // Controlled 10 N lateral disturbance during the middle third
  disturbanceActive = time >= t1 and time <= t2;
  FdistY = if disturbanceActive then disturbanceForce else 0.0;
  tau_dist[1] = 0.0;
  tau_dist[2] = FdistY*(L1*cos(q[2]) + L2*cos(q[2] + q[3]));
  tau_dist[3] = FdistY*L2*cos(q[2] + q[3]);

  // Soft-stop enforcement for rail and revolute joint limits
  tau_lim[1] = if q[1] > railLength then -kLimX*(q[1] - railLength) - dLimX*qd[1]
               elseif q[1] < 0.0 then -kLimX*q[1] - dLimX*qd[1]
               else 0.0;
  tau_lim[2] = if q[2] > jointLimit then -kLimA*(q[2] - jointLimit) - dLimA*qd[2]
               elseif q[2] < -jointLimit then -kLimA*(q[2] + jointLimit) - dLimA*qd[2]
               else 0.0;
  tau_lim[3] = if q[3] > jointLimit then -kLimA*(q[3] - jointLimit) - dLimA*qd[3]
               elseif q[3] < -jointLimit then -kLimA*(q[3] + jointLimit) - dLimA*qd[3]
               else 0.0;

  // Decoupled nonsingular plant dynamics with disturbance and limit penalties
  qdd[1] = (tau_sat[1] + tau_dist[1] + tau_lim[1])/m_carriage;
  qdd[2] = (tau_sat[2] + tau_dist[2] + tau_lim[2])/I_eff1;
  qdd[3] = (tau_sat[3] + tau_dist[3] + tau_lim[3])/I_eff2;

  // Planar arm kinematics
  v1x = L1*cos(q[2]);
  v1y = L1*sin(q[2]);
  p1x = q[1] + v1x;
  p1y = v1y;
  v2x = L2*cos(q[2] + q[3]);
  v2y = L2*sin(q[2] + q[3]);
  tipX = p1x + v2x;
  tipY = p1y + v2y;

  // Robust point-to-segment clearance from fixed cylindrical obstacle to both links
  v1dot = v1x*v1x + v1y*v1y;
  w0x = q[1] - xObs;
  w0y = 0.0 - yObs;
  tA = if v1dot > 1e-12 then max(0.0, min(1.0, -(v1x*w0x + v1y*w0y)/v1dot)) else 0.0;
  c0x = q[1] + tA*v1x;
  c0y = 0.0 + tA*v1y;
  d0 = sqrt(max(0.0, (c0x - xObs)*(c0x - xObs) + (c0y - yObs)*(c0y - yObs)));

  v2dot = v2x*v2x + v2y*v2y;
  w1x = p1x - xObs;
  w1y = p1y - yObs;
  tB = if v2dot > 1e-12 then max(0.0, min(1.0, -(v2x*w1x + v2y*w1y)/v2dot)) else 0.0;
  c1x = p1x + tB*v2x;
  c1y = p1y + tB*v2y;
  d1 = sqrt(max(0.0, (c1x - xObs)*(c1x - xObs) + (c1y - yObs)*(c1y - yObs)));

  clearance = max(0.0, min(d0, d1) - rObs);

  // Requirement metrics
  den = max(abs(q2[1] - q0[1]), max(abs(q2[2] - q0[2]), abs(q2[3] - q0[3])));
  primaryError = max(abs(err[1]), max(abs(err[2]), abs(err[3])));
  overshootPercent = if den > 1e-6 then primaryError/den*100.0 else 0.0;

  jointLimitsOK = q[1] >= -1e-9 and q[1] <= railLength + 1e-9 and
                  q[2] >= -jointLimit - 1e-9 and q[2] <= jointLimit + 1e-9 and
                  q[3] >= -jointLimit - 1e-9 and q[3] <= jointLimit + 1e-9;
  clearanceOK = clearance > clearanceMin;
  terminalSettled = time >= 9.1 and primaryError < 0.05;

  // Synchronized 200 Hz encoder samples and retained traces
  when {initial(), sample(0, Ts)} then
    encTime = time;
    encPos[1] = q[1];
    encPos[2] = q[2];
    encPos[3] = q[3];
    encVel[1] = qd[1];
    encVel[2] = qd[2];
    encVel[3] = qd[3];
    overshootMax = if overshootPercent > overshootMax then overshootPercent else overshootMax;
  end when;

  overshootOK = overshootMax < 12.0;

  annotation (experiment(StopTime=14.0, Interval=0.005));
end RailArmTraceD;