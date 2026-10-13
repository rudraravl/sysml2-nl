model HydBoomPositionD
  "Instrumented hydraulic boom/stick position system with load-sensing pump, relief valve, compressibility, leakage, end stops, pressure-aware sampled PID, external disturbance, and bounded traces."

  // Stated geometry and payload
  parameter Real L1(unit="m") = 2.0 "Boom length";
  parameter Real L2(unit="m") = 1.4 "Stick length";
  parameter Real mLoad(unit="kg") = 300.0 "Payload mass";
  constant Real g(unit="m/s2") = 9.81;

  // Simulation and control timing (stated)
  parameter Real Tsim(unit="s") = 14.0 "Simulation duration";
  parameter Real Ts(unit="s") = 1.0/200.0 "Controller and sensor sample period";
  parameter Real FdistStart(unit="s") = Tsim/3.0 "Start of middle-third disturbance";
  parameter Real FdistEnd(unit="s") = 2.0*Tsim/3.0 "End of middle-third disturbance";
  parameter Real FdistMag(unit="N") = 100.0 "External load disturbance magnitude";
  parameter Real trackingTime(unit="s") = 9.1 "Time after which primary error is bounded";
  parameter Real trackingErrorBound(unit="m") = 0.012 "Primary tracking error bound";

  // Hydraulic supply/return (values not stated in requirement; assumed finite)
  parameter Real pSupply(unit="Pa") = 25.0e5 "Declared supply pressure, assumed";
  parameter Real pReturn(unit="Pa") = 5.0e5 "Declared return pressure, assumed";
  parameter Real pRelief(unit="Pa") = pSupply "Relief valve pressure";
  parameter Real Qpmax(unit="m3/s") = 0.004 "Pump flow limit";
  parameter Real beta(unit="Pa") = 1.4e8 "Effective fluid bulk modulus, assumed";
  parameter Real VS(unit="m3") = 0.02 "Supply-line volume, assumed";
  parameter Real Gbleed(unit="m3/(s.Pa)") = 1.0e-12 "Pump/return leakage conductance, assumed";
  parameter Real Grelief(unit="m3/(s.Pa)") = 5.0e-9 "Relief valve conductance, assumed";

  // Cylinder geometry (unstated values assumed for an executable finite model)
  parameter Real Aa1(unit="m2") = 0.005 "Boom cap-side area, assumed";
  parameter Real Ab1(unit="m2") = 0.004 "Boom rod-side area, assumed";
  parameter Real Aa2(unit="m2") = 0.005 "Stick cap-side area, assumed";
  parameter Real Ab2(unit="m2") = 0.004 "Stick rod-side area, assumed";
  parameter Real Vdead1(unit="m3") = 0.001 "Boom chamber dead volume, assumed";
  parameter Real Vdead2(unit="m3") = 0.001 "Stick chamber dead volume, assumed";
  parameter Real Gv1(unit="m3/(s.Pa)") = 1.2e-9 "Boom valve conductance, assumed";
  parameter Real Gv2(unit="m3/(s.Pa)") = 1.2e-9 "Stick valve conductance, assumed";
  parameter Real Cleak1(unit="m3/(s.Pa)") = 1.0e-12 "Boom internal leakage conductance, assumed";
  parameter Real Cleak2(unit="m3/(s.Pa)") = 1.0e-12 "Stick internal leakage conductance, assumed";

  // Boom/stick joint limits and effective cylinder moment arms (assumed)
  parameter Real q1_min(unit="rad") = 0.2 "Boom joint lower stop, assumed";
  parameter Real q1_max(unit="rad") = 1.2 "Boom joint upper stop, assumed";
  parameter Real q2_min(unit="rad") = 0.1 "Stick joint lower stop, assumed";
  parameter Real q2_max(unit="rad") = 3.141592653589793 - 0.1 "Stick joint upper stop, assumed";
  parameter Real r1(unit="m/rad") = 0.5 "Boom cylinder moment arm, assumed";
  parameter Real r2(unit="m/rad") = 0.4 "Stick cylinder moment arm, assumed";

  // Actuator strokes
  parameter Real s1_min(unit="m") = 0.0 "Boom cylinder lower stop";
  parameter Real s1_max(unit="m") = r1*(q1_max - q1_min) "Boom cylinder available stroke";
  parameter Real s2_max(unit="m") = r2*(q2_max - q2_min) "Stick cylinder available stroke";

  // Initial coordinates (unstated; chosen finite and within stops)
  parameter Real s1_start(unit="m") = 0.1 "Initial boom cylinder coordinate, assumed";
  parameter Real s2_start(unit="m") = r2*(q2_max - 1.6) "Initial stick cylinder coordinate, assumed";

  // Available endpoint travel from stated boom/stick lengths
  parameter Real rMin(unit="m") = abs(L1 - L2) "Minimum radial reach";
  parameter Real rMax(unit="m") = L1 + L2 "Maximum radial reach";
  parameter Real availableTravel(unit="m") = rMax - rMin "Available radial travel";
  parameter Real rRef(unit="m") = rMin + 0.7*availableTravel "70 percent of available radial travel";

  // Reference coordinates
  parameter Real q2_ref(unit="rad") = acos(max(min((rRef^2 - L1^2 - L2^2)/(2.0*L1*L2), 1.0), -1.0)) "Stick angle for 70 percent radial travel";
  parameter Real s1_ref(unit="m") = 0.7*s1_max "Boom reference coordinate";
  parameter Real s2_ref(unit="m") = r2*(q2_max - q2_ref) "Stick reference coordinate";

  // Reflected inertias from stated payload and geometry (decoupled approximation)
  parameter Real mEff1(unit="kg") = mLoad*((L1 + L2)/r1)^2 "Boom reflected inertia, assumed mapping";
  parameter Real mEff2(unit="kg") = mLoad*(L2/r2)^2 "Stick reflected inertia, assumed mapping";

  // Mechanical damping and end-stop stiffness (assumed)
  parameter Real cFric1(unit="N.s/m") = 1000.0 "Boom viscous friction, assumed";
  parameter Real cFric2(unit="N.s/m") = 800.0 "Stick viscous friction, assumed";
  parameter Real kStop1(unit="N/m") = 1.0e7 "Boom end-stop stiffness, assumed";
  parameter Real dStop1(unit="N.s/m") = 1.0e5 "Boom end-stop damping, assumed";
  parameter Real kStop2(unit="N/m") = 1.0e7 "Stick end-stop stiffness, assumed";
  parameter Real dStop2(unit="N.s/m") = 1.0e5 "Stick end-stop damping, assumed";

  // Initial chamber pressures (assumed to balance initial loads)
  parameter Real pA1_start(unit="Pa") = 1.9e6 "Boom cap-side initial pressure, assumed";
  parameter Real pB1_start(unit="Pa") = pReturn "Boom rod-side initial pressure, assumed";
  parameter Real pA2_start(unit="Pa") = 1.7e6 "Stick cap-side initial pressure, assumed";
  parameter Real pB2_start(unit="Pa") = pReturn "Stick rod-side initial pressure, assumed";

  // Pressure-aware PID gains (assumed tuning)
  parameter Real Kp1(unit="1/m") = 8.0 "Boom proportional gain";
  parameter Real Ki1(unit="1/(m.s)") = 1.0 "Boom integral gain";
  parameter Real Kd1(unit="s/m") = 2.0 "Boom derivative gain";
  parameter Real Kf1(unit="1") = 0.5 "Boom pressure-force feedback gain";
  parameter Real Kp2(unit="1/m") = 10.0 "Stick proportional gain";
  parameter Real Ki2(unit="1/(m.s)") = 2.0 "Stick integral gain";
  parameter Real Kd2(unit="s/m") = 2.0 "Stick derivative gain";
  parameter Real Kf2(unit="1") = 0.5 "Stick pressure-force feedback gain";

  // Continuous states and sensors
  Real s1(unit="m") "Boom cylinder position";
  Real v1(unit="m/s") "Boom cylinder velocity";
  Real s2(unit="m") "Stick cylinder position";
  Real v2(unit="m/s") "Stick cylinder velocity";
  Real pS(unit="Pa") "Supply pressure";
  Real pA1(unit="Pa") "Boom cap-side pressure";
  Real pB1(unit="Pa") "Boom rod-side pressure";
  Real pA2(unit="Pa") "Stick cap-side pressure";
  Real pB2(unit="Pa") "Stick rod-side pressure";

  // Kinematic and load variables
  Real q1(unit="rad") "Boom angle";
  Real q2(unit="rad") "Stick relative angle";
  Real w1(unit="rad/s") "Boom angular velocity";
  Real w2(unit="rad/s") "Stick angular velocity";
  Real q12(unit="rad") "Absolute stick angle";
  Real xTip(unit="m") "Tip x coordinate";
  Real yTip(unit="m") "Tip y coordinate";
  Real rTip(unit="m") "Radial reach";
  Real G1(unit="N.m") "Payload gravity torque on boom";
  Real G2(unit="N.m") "Payload gravity torque on stick";
  Real Fload1(unit="N") "Boom load force opposing extension";
  Real Fload2(unit="N") "Stick load force opposing extension";
  Real Fhyd1(unit="N") "Boom cylinder hydraulic force";
  Real Fhyd2(unit="N") "Stick cylinder hydraulic force";
  Real Ferr1(unit="N") "Boom pressure-aware force error";
  Real Ferr2(unit="N") "Stick pressure-aware force error";
  Real Fstop1(unit="N") "Boom end-stop force";
  Real Fstop2(unit="N") "Stick end-stop force";
  Real Fdist(unit="N") "External disturbance force";
  Real pSsafe(unit="Pa") "Non-singular supply pressure divisor";

  // Hydraulic flows
  Real Q_A1(unit="m3/s") "Boom cap-side valve flow into chamber";
  Real Q_B1(unit="m3/s") "Boom rod-side valve flow into chamber";
  Real Q_A2(unit="m3/s") "Stick cap-side valve flow into chamber";
  Real Q_B2(unit="m3/s") "Stick rod-side valve flow into chamber";
  Real Qsupply(unit="m3/s") "Total supply flow demanded by valves";
  Real Qpump(unit="m3/s") "Load-sensing pump flow";
  Real Qrelief(unit="m3/s") "Relief valve flow";
  Real VA1(unit="m3") "Boom cap-side volume";
  Real VB1(unit="m3") "Boom rod-side volume";
  Real VA2(unit="m3") "Stick cap-side volume";
  Real VB2(unit="m3") "Stick rod-side volume";

  // Measured plant outputs
  Real s1_meas(unit="m") = s1 "Measured boom actuator position";
  Real v1_meas(unit="m/s") = v1 "Measured boom actuator velocity";
  Real pA1_meas(unit="Pa") = pA1 "Measured boom cap-side pressure";
  Real pB1_meas(unit="Pa") = pB1 "Measured boom rod-side pressure";
  Real u1_meas = u1 "Measured boom valve command";
  Real s2_meas(unit="m") = s2 "Measured stick actuator position";
  Real v2_meas(unit="m/s") = v2 "Measured stick actuator velocity";
  Real pA2_meas(unit="Pa") = pA2 "Measured stick cap-side pressure";
  Real pB2_meas(unit="Pa") = pB2 "Measured stick rod-side pressure";
  Real u2_meas = u2 "Measured stick valve command";
  Real rTip_meas(unit="m") = rTip "Measured radial reach";
  Real primaryTrackingError(unit="m") "Primary radial tracking error";
  Real s2TrackingError(unit="m") "Stick actuator tracking error";

  // Discrete control and synchronized 200 Hz traces
  discrete Real u1(start=0.0) "Boom valve command";
  discrete Real u2(start=0.0) "Stick valve command";
  discrete Real uRaw1(start=0.0) "Unsaturated boom valve command";
  discrete Real uRaw2(start=0.0) "Unsaturated stick valve command";
  discrete Real eInt1(start=0.0, unit="m.s") "Boom integral state";
  discrete Real eInt2(start=0.0, unit="m.s") "Stick integral state";
  discrete Real e1(start=0.0, unit="m") "Boom position error";
  discrete Real e2(start=0.0, unit="m") "Stick position error";

  discrete Real tLog(start=0.0, unit="s") "Synchronized log time";
  discrete Real s1_log(start=0.0, unit="m") "Logged boom position";
  discrete Real v1_log(start=0.0, unit="m/s") "Logged boom velocity";
  discrete Real pA1_log(start=0.0, unit="Pa") "Logged boom cap pressure";
  discrete Real pB1_log(start=0.0, unit="Pa") "Logged boom rod pressure";
  discrete Real u1_log(start=0.0) "Logged boom command";
  discrete Real s2_log(start=0.0, unit="m") "Logged stick position";
  discrete Real v2_log(start=0.0, unit="m/s") "Logged stick velocity";
  discrete Real pA2_log(start=0.0, unit="Pa") "Logged stick cap pressure";
  discrete Real pB2_log(start=0.0, unit="Pa") "Logged stick rod pressure";
  discrete Real u2_log(start=0.0) "Logged stick command";
  discrete Real rTip_log(start=0.0, unit="m") "Logged radial reach";
  discrete Real pS_log(start=0.0, unit="Pa") "Logged supply pressure";
  discrete Real Qpump_log(start=0.0, unit="m3/s") "Logged pump flow";

equation
  // Kinematics
  q1 = q1_min + s1/r1;
  q2 = q2_max - s2/r2;
  w1 = v1/r1;
  w2 = -v2/r2;
  q12 = q1 + q2;
  xTip = L1*cos(q1) + L2*cos(q12);
  yTip = L1*sin(q1) + L2*sin(q12);
  rTip = sqrt(max(xTip*xTip + yTip*yTip, 1.0e-12));

  // Payload gravity torques and reflected cylinder loads
  G1 = mLoad*g*(L1*cos(q1) + L2*cos(q12));
  G2 = mLoad*g*L2*cos(q12);
  Fload1 = G1/r1;
  Fload2 = -G2/r2;
  Fhyd1 = pA1*Aa1 - pB1*Ab1;
  Fhyd2 = pA2*Aa2 - pB2*Ab2;
  Ferr1 = Fload1 - Fhyd1;
  Ferr2 = Fload2 - Fhyd2;

  // End stops
  Fstop1 = if s1 < s1_min then kStop1*(s1_min - s1) - dStop1*v1
           elseif s1 > s1_max then -kStop1*(s1 - s1_max) - dStop1*v1
           else 0.0;
  Fstop2 = if s2 < 0.0 then kStop2*(0.0 - s2) - dStop2*v2
           elseif s2 > s2_max then -kStop2*(s2 - s2_max) - dStop2*v2
           else 0.0;

  // External disturbance during middle third
  Fdist = if time >= FdistStart and time <= FdistEnd then FdistMag else 0.0;

  // Mechanical dynamics
  der(s1) = v1;
  der(s2) = v2;
  mEff1*der(v1) = Fhyd1 - Fload1 + Fstop1 - cFric1*v1;
  mEff2*der(v2) = Fhyd2 - Fload2 + Fstop2 - cFric2*v2 - Fdist;

  // Safe supply pressure divisor
  pSsafe = max(pS, pReturn);

  // Chamber volumes
  VA1 = Vdead1 + Aa1*s1;
  VB1 = Vdead1 + Ab1*(s1_max - s1);
  VA2 = Vdead2 + Aa2*s2;
  VB2 = Vdead2 + Ab2*(s2_max - s2);

  // Valve flows: positive command extends, negative command retracts
  Q_A1 = if u1 >= 0.0 then Gv1*u1*max(pS - pA1, 0.0) else Gv1*u1*max(pA1 - pReturn, 0.0);
  Q_B1 = if u1 >= 0.0 then -Gv1*u1*max(pB1 - pReturn, 0.0) else -Gv1*u1*max(pS - pB1, 0.0);
  Q_A2 = if u2 >= 0.0 then Gv2*u2*max(pS - pA2, 0.0) else Gv2*u2*max(pA2 - pReturn, 0.0);
  Q_B2 = if u2 >= 0.0 then -Gv2*u2*max(pB2 - pReturn, 0.0) else -Gv2*u2*max(pS - pB2, 0.0);

  // Pressure dynamics with compressibility and internal leakage
  der(pA1) = beta/VA1*(Q_A1 - Aa1*v1 - Cleak1*(pA1 - pB1));
  der(pB1) = beta/VB1*(Q_B1 + Ab1*v1 + Cleak1*(pA1 - pB1));
  der(pA2) = beta/VA2*(Q_A2 - Aa2*v2 - Cleak2*(pA2 - pB2));
  der(pB2) = beta/VB2*(Q_B2 + Ab2*v2 + Cleak2*(pA2 - pB2));

  // Shared load-sensing pump, relief valve, and pump flow limit
  Qsupply = max(0.0, Q_A1) + max(0.0, Q_B1) + max(0.0, Q_A2) + max(0.0, Q_B2);
  Qrelief = if pS > pRelief then Grelief*(pS - pRelief) else 0.0;
  Qpump = min(Qsupply + Gbleed*(pS - pReturn), Qpmax);
  der(pS) = beta/VS*(Qpump - Qsupply - Gbleed*(pS - pReturn) - Qrelief);

  // Tracking errors
  primaryTrackingError = if time >= trackingTime then abs(rTip - rRef) else 0.0;
  s2TrackingError = if time >= trackingTime then abs(s2 - s2_ref) else 0.0;

  // Pressure-aware sampled PID and synchronized sensor/state/command traces
  when sample(0.0, Ts) then
    e1 = s1_ref - s1;
    e2 = s2_ref - s2;
    uRaw1 = Kp1*e1 + Ki1*(pre(eInt1) + Ts*e1) - Kd1*v1 + Kf1*Ferr1/(Aa1*pSsafe);
    uRaw2 = Kp2*e2 + Ki2*(pre(eInt2) + Ts*e2) - Kd2*v2 + Kf2*Ferr2/(Aa2*pSsafe);
    u1 = if uRaw1 > 1.0 then 1.0 elseif uRaw1 < -1.0 then -1.0 else uRaw1;
    u2 = if uRaw2 > 1.0 then 1.0 elseif uRaw2 < -1.0 then -1.0 else uRaw2;
    eInt1 = if abs(uRaw1) <= 1.0 then pre(eInt1) + Ts*e1 else pre(eInt1);
    eInt2 = if abs(uRaw2) <= 1.0 then pre(eInt2) + Ts*e2 else pre(eInt2);

    tLog = time;
    s1_log = s1;
    v1_log = v1;
    pA1_log = pA1;
    pB1_log = pB1;
    u1_log = u1;
    s2_log = s2;
    v2_log = v2;
    pA2_log = pA2;
    pB2_log = pB2;
    u2_log = u2;
    rTip_log = rTip;
    pS_log = pS;
    Qpump_log = Qpump;
  end when;

  // Bounds and finite/NaN checks
  assert(s1 >= -1.0e-4 and s1 <= s1_max + 1.0e-4, "Boom cylinder travel bound violated");
  assert(s2 >= -1.0e-4 and s2 <= s2_max + 1.0e-4, "Stick cylinder travel bound violated");
  assert(u1 >= -1.001 and u1 <= 1.001, "Boom valve command bound violated");
  assert(u2 >= -1.001 and u2 <= 1.001, "Stick valve command bound violated");
  assert(pS >= 0.0 and pS <= 1.5*pRelief, "Supply pressure bound or NaN/infinite check failed");
  assert(pA1 >= 0.0 and pA1 <= 1.5*pRelief, "Boom cap pressure bound or NaN/infinite check failed");
  assert(pB1 >= 0.0 and pB1 <= 1.5*pRelief, "Boom rod pressure bound or NaN/infinite check failed");
  assert(pA2 >= 0.0 and pA2 <= 1.5*pRelief, "Stick cap pressure bound or NaN/infinite check failed");
  assert(pB2 >= 0.0 and pB2 <= 1.5*pRelief, "Stick rod pressure bound or NaN/infinite check failed");
  assert(abs(v1) <= 5.0, "Boom velocity bound violated");
  assert(abs(v2) <= 5.0, "Stick velocity bound violated");
  assert(rTip >= 0.95*rMin and rTip <= 1.05*rMax, "Endpoint radial travel bound violated");
  assert(Qpump >= -1.0e-6 and Qpump <= Qpmax + 1.0e-6, "Pump flow bound or NaN/infinite check failed");
  assert(not (time >= trackingTime) or primaryTrackingError <= trackingErrorBound,
         "Primary tracking error bound violated after 9.1 s");
  assert(not (time >= 13.5) or abs(s2 - s2_ref) <= 0.004, "Final stick actuator position bound violated");
  assert(not (time >= 13.5) or abs(s1 - s1_ref) <= 0.02, "Final boom actuator position bound violated");

initial equation
  s1 = s1_start;
  v1 = 0.0;
  s2 = s2_start;
  v2 = 0.0;
  pS = pSupply;
  pA1 = pA1_start;
  pB1 = pB1_start;
  pA2 = pA2_start;
  pB2 = pB2_start;

  annotation(experiment(StopTime=14, Tolerance=1e-6, Interval=0.005));
end HydBoomPositionD;