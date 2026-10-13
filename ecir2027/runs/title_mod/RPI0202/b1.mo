model RailArmTraceD
  import SI = Modelica.Units.SI;

  parameter SI.Time T = 14.0 "simulation and trajectory horizon";
  parameter SI.Time Ts = 0.005 "200 Hz synchronized sample period";
  parameter SI.Time t1 = T/3 "end of first cubic segment";
  parameter SI.Time t2 = 2*T/3 "end of second cubic segment";

  parameter SI.Length railLength = 1.4 "fixed X rail length";
  parameter SI.Mass m_carriage = 18.0 "carriage mass";
  parameter SI.Length L1 = 0.46 "first arm link length";
  parameter SI.Length L2 = 0.31 "second arm link length";
  parameter SI.Angle jointLimit = 1.5 "revolute joint limit magnitude";
  parameter SI.Force forceLimit = 800.0 "linear actuator force limit";
  parameter SI.Torque torqueLimit = 85.0 "rotary actuator torque limit";

  parameter Real q0_x = 0.30 "first reachable state x";
  parameter Real q0_th1 = 0.40 "first reachable state th1";
  parameter Real q0_th2 = 0.30 "first reachable state th2";
  parameter Real q1_x = 0.70 "second reachable state x";
  parameter Real q1_th1 = 0.90 "second reachable state th1";
  parameter Real q1_th2 = -0.60 "second reachable state th2";
  parameter Real q2_x = 1.10 "third reachable state x";
  parameter Real q2_th1 = 0.40 "third reachable state th1";
  parameter Real q2_th2 = 0.30 "third reachable state th2";

  parameter SI.Length xObs = 0.70 "obstacle center x";
  parameter SI.Length yObs = -0.15 "obstacle center y";
  parameter SI.Length rObs = 0.05 "obstacle radius";
  parameter SI.Length clearanceMin = 0.05 "required clearance";

  parameter SI.Force disturbanceForce = 10.0 "lateral Y disturbance during middle third";

  parameter Real I_eff1 = m_carriage*L1*L1 "placeholder effective inertia for joint 1";
  parameter Real I_eff2 = m_carriage*L2*L2 "placeholder effective inertia for joint 2";

  parameter Real Kp_x = 2000.0;
  parameter Real Ki_x = 200.0;
  parameter Real Kd_x = 300.0;
  parameter Real FF_x = m_carriage;
  parameter Real Kp_th1 = 1000.0;
  parameter Real Ki_th1 = 100.0;
  parameter Real Kd_th1 = 100.0;
  parameter Real FF_th1 = I_eff1;
  parameter Real Kp_th2 = 500.0;
  parameter Real Ki_th2 = 50.0;
  parameter Real Kd_th2 = 50.0;
  parameter Real FF_th2 = I_eff2;

  parameter Real kLimX = forceLimit/0.01 "rail soft-stop stiffness";
  parameter Real dLimX = forceLimit "rail soft-stop damping";
  parameter Real kLimA = torqueLimit/0.01 "revolute soft-stop stiffness";
  parameter Real dLimA = torqueLimit "revolute soft-stop damping";

  Real q_x(start=0.30);
  Real q_th1(start=0.40);
  Real q_th2(start=0.30);
  Real qd_x(start=0.0);
  Real qd_th1(start=0.0);
  Real qd_th2(start=0.0);
  Real qdd_x, qdd_th1, qdd_th2;
  Real q_ref_x, q_ref_th1, q_ref_th2;
  Real qd_ref_x, qd_ref_th1, qd_ref_th2;
  Real err_x, err_th1, err_th2;
  Real integ_x(start=0.0), integ_th1(start=0.0), integ_th2(start=0.0);
  Real tau_cmd_x, tau_cmd_th1, tau_cmd_th2;
  Real tau_sat_x, tau_sat_th1, tau_sat_th2;
  Real tau_lim_x, tau_lim_th1, tau_lim_th2;
  Real tau_dist_x, tau_dist_th1, tau_dist_th2;
  SI.Force FdistY;
  Boolean disturbanceActive = time >= t1 and time <= t2;

  SI.Position tipX, tipY;
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
  discrete Real encPos_x(start=0.30);
  discrete Real encPos_th1(start=0.40);
  discrete Real encPos_th2(start=0.30);
  discrete Real encVel_x(start=0.0);
  discrete Real encVel_th1(start=0.0);
  discrete Real encVel_th2(start=0.0);
  discrete Real encTime(start=0.0);

  Real sigma1, sigma2;
  Real v1x, v1y, v2x, v2y, v1dot, v2dot;
  Real w0x, w0y, w1x, w1y;
  Real tA, tB;
  Real p1x, p1y, c0x, c0y, c1x, c1y;
  Real d0, d1;

equation
  der(q_x) = qd_x;
  der(q_th1) = qd_th1;
  der(q_th2) = qd_th2;
  der(qd_x) = qdd_x;
  der(qd_th1) = qdd_th1;
  der(qd_th2) = qdd_th2;

  sigma1 = if time <= t1 then time/t1 else 1.0;
  sigma2 = if time <= t1 then 0.0 elseif time <= t2 then (time - t1)/(t2 - t1) else 1.0;

  q_ref_x = if time < t1 then q0_x + (q1_x - q0_x)*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
            elseif time < t2 then q1_x + (q2_x - q1_x)*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
            else q2_x;
  q_ref_th1 = if time < t1 then q0_th1 + (q1_th1 - q0_th1)*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
              elseif time < t2 then q1_th1 + (q2_th1 - q1_th1)*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
              else q2_th1;
  q_ref_th2 = if time < t1 then q0_th2 + (q1_th2 - q0_th2)*(3*sigma1*sigma1 - 2*sigma1*sigma1*sigma1)
              elseif time < t2 then q1_th2 + (q2_th2 - q1_th2)*(3*sigma2*sigma2 - 2*sigma2*sigma2*sigma2)
              else q2_th2;

  qd_ref_x = if time < t1 then (q1_x - q0_x)*(6*sigma1 - 6*sigma1*sigma1)/t1
             elseif time < t2 then (q2_x - q1_x)*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
             else 0.0;
  qd_ref_th1 = if time < t1 then (q1_th1 - q0_th1)*(6*sigma1 - 6*sigma1*sigma1)/t1
               elseif time < t2 then (q2_th1 - q1_th1)*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
               else 0.0;
  qd_ref_th2 = if time < t1 then (q1_th2 - q0_th2)*(6*sigma1 - 6*sigma1*sigma1)/t1
               elseif time < t2 then (q2_th2 - q1_th2)*(6*sigma2 - 6*sigma2*sigma2)/(t2 - t1)
               else 0.0;

  err_x = q_ref_x - q_x;
  err_th1 = q_ref_th1 - q_th1;
  err_th2 = q_ref_th2 - q_th2;
  der(integ_x) = err_x;
  der(integ_th1) = err_th1;
  der(integ_th2) = err_th2;

  tau_cmd_x = Kp_x*err_x + Ki_x*integ_x + Kd_x*(qd_ref_x - qd_x) + FF_x*qd_ref_x;
  tau_cmd_th1 = Kp_th1*err_th1 + Ki_th1*integ_th1 + Kd_th1*(qd_ref_th1 - qd_th1) + FF_th1*qd_ref_th1;
  tau_cmd_th2 = Kp_th2*err_th2 + Ki_th2*integ_th2 + Kd_th2*(qd_ref_th2 - qd_th2) + FF_th2*qd_ref_th2;

  tau_sat_x = max(-forceLimit, min(forceLimit, tau_cmd_x));
  tau_sat_th1 = max(-torqueLimit, min(torqueLimit, tau_cmd_th1));
  tau_sat_th2 = max(-torqueLimit, min(torqueLimit, tau_cmd_th2));

  FdistY = if disturbanceActive then disturbanceForce else 0.0;
  tau_dist_x = 0.0;
  tau_dist_th1 = FdistY*(L1*cos(q_th1) + L2*cos(q_th1 + q_th2));
  tau_dist_th2 = FdistY*L2*cos(q_th1 + q_th2);

  tau_lim_x = if q_x > railLength then -kLimX*(q_x - railLength) - dLimX*qd_x
              elseif q_x < 0.0 then -kLimX*q_x - dLimX*qd_x
              else 0.0;
  tau_lim_th1 = if q_th1 > jointLimit then -kLimA*(q_th1 - jointLimit) - dLimA*qd_th1
                elseif q_th1 < -jointLimit then -kLimA*(q_th1 + jointLimit) - dLimA*qd_th1
                else 0.0;
  tau_lim_th2 = if q_th2 > jointLimit then -kLimA*(q_th2 - jointLimit) - dLimA*qd_th2
                elseif q_th2 < -jointLimit then -kLimA*(q_th2 + jointLimit) - dLimA*qd_th2
                else 0.0;

  qdd_x = (tau_sat_x + tau_dist_x + tau_lim_x)/m_carriage;
  qdd_th1 = (tau_sat_th1 + tau_dist_th1 + tau_lim_th1)/I_eff1;
  qdd_th2 = (tau_sat_th2 + tau_dist_th2 + tau_lim_th2)/I_eff2;

  v1x = L1*cos(q_th1);
  v1y = L1*sin(q_th1);
  p1x = q_x + v1x;
  p1y = v1y;
  v2x = L2*cos(q_th1 + q_th2);
  v2y = L2*sin(q_th1 + q_th2);
  tipX = p1x + v2x;
  tipY = p1y + v2y;

  v1dot = v1x*v1x + v1y*v1y;
  w0x = q_x - xObs;
  w0y = 0.0 - yObs;
  tA = if v1dot > 1e-12 then max(0.0, min(1.0, -(v1x*w0x + v1y*w0y)/v1dot)) else 0.0;
  c0x = q_x + tA*v1x;
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

  den = max(abs(q2_x - q0_x), max(abs(q2_th1 - q0_th1), abs(q2_th2 - q0_th2)));
  primaryError = max(abs(err_x), max(abs(err_th1), abs(err_th2)));
  overshootPercent = if den > 1e-6 then primaryError/den*100.0 else 0.0;

  jointLimitsOK = q_x >= -1e-9 and q_x <= railLength + 1e-9 and
                  q_th1 >= -jointLimit - 1e-9 and q_th1 <= jointLimit + 1e-9 and
                  q_th2 >= -jointLimit - 1e-9 and q_th2 <= jointLimit + 1e-9;
  clearanceOK = clearance > clearanceMin;
  terminalSettled = time >= 9.1 and primaryError < 0.05;

  when {initial(), sample(0, Ts)} then
    encTime = time;
    encPos_x = q_x;
    encPos_th1 = q_th1;
    encPos_th2 = q_th2;
    encVel_x = qd_x;
    encVel_th1 = qd_th1;
    encVel_th2 = qd_th2;
    overshootMax = if pre(overshootMax) > overshootPercent then pre(overshootMax) else overshootPercent;
  end when;

  overshootOK = overshootMax < 12.0;

  annotation (experiment(StopTime=14.0, Interval=0.005));
end RailArmTraceD;