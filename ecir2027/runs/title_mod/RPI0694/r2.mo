model HydBoomConserveD
  import SI = Modelica.SIunits;

  constant Real pi = 3.141592653589793;
  constant SI.Acceleration g = 9.81;

  // Stated geometry and payload
  parameter SI.Length L1 = 2.0 "stated boom length";
  parameter SI.Length L2 = 1.4 "stated stick length";
  parameter SI.Mass mPayload = 300.0 "stated payload mass";

  // Assumed cylinder-to-joint geometry; exact mounting geometry is not stated
  parameter SI.Length x1_0 = 0.30 "initial boom cylinder extension";
  parameter SI.Length x2_0 = 0.20 "initial stick cylinder extension";
  parameter Real theta1_0 = 0.349065850398 "assumed initial boom angle, rad";
  parameter Real theta2_0 = -0.174532925199 "assumed initial stick relative angle, rad";
  parameter Real kTheta1 = 0.5 "assumed cylinder-to-boom gain, rad/m";
  parameter Real kTheta2 = 0.5 "assumed cylinder-to-stick gain, rad/m";
  parameter SI.Length x1_min = 0.08 "assumed boom cylinder stroke lower bound";
  parameter SI.Length x1_max = 0.52 "assumed boom cylinder stroke upper bound";
  parameter SI.Length x2_min = 0.03 "assumed stick cylinder stroke lower bound";
  parameter SI.Length x2_max = 0.37 "assumed stick cylinder stroke upper bound";

  // Assumed cylinder areas and volumes; exact hardware data is not stated
  parameter SI.Area A_A1 = 0.0050 "assumed boom cap-side area";
  parameter SI.Area A_B1 = 0.0020 "assumed boom rod-side area";
  parameter SI.Area A_A2 = 0.0035 "assumed stick cap-side area";
  parameter SI.Area A_B2 = 0.0015 "assumed stick rod-side area";
  parameter SI.Volume Vd1 = 0.00020 "assumed boom dead volume";
  parameter SI.Volume Vd2 = 0.00015 "assumed stick dead volume";
  parameter SI.Pressure beta = 1.0e8 "assumed effective fluid bulk modulus for compressibility";

  // Hydraulic supply and relief; relief pressure value is assumed
  parameter SI.VolumeFlowRate Qpmax = 0.004 "stated pump flow limit";
  parameter SI.Pressure pT = 0.50e6 "assumed realistic return pressure";
  parameter SI.Pressure pRelief = 20.0e6 "assumed relief pressure";
  parameter SI.Pressure pMargin = 2.0e6 "assumed load-sensing margin";
  parameter Real Kpump = 1.0e-8 "assumed pump pressure-regulation gain, m3/(s.Pa)";
  parameter SI.Volume Vs = 0.05 "assumed supply manifold volume";
  parameter Real kleak = 1.0e-12 "assumed leakage conductance, m3/(s.Pa)";
  parameter Real Krelief = 5.0e-8 "assumed relief conductance, m3/(s.Pa)";

  // Motion cycle and control
  parameter SI.Time Tcyc = 7.0 "one actuation cycle, repeated twice in 14 s";
  parameter SI.Length x1_ref0 = 0.30 "boom reference center";
  parameter SI.Length x1_amp = 0.20 "boom reference amplitude";
  parameter SI.Length x2_ref0 = 0.20 "stick reference center";
  parameter SI.Length x2_amp = 0.15 "stick reference amplitude";
  parameter SI.Pressure dpNom = 2.0e6 "assumed nominal valve pressure drop";
  parameter SI.Pressure pFF = 10.0e6 "assumed force feedforward pressure";
  parameter Real Kp1 = 12.0 "boom position gain, 1/m";
  parameter Real Kd1 = 1.5 "boom velocity gain, s/m";
  parameter Real Ki1 = 3.0 "boom integral gain, 1/(s.m)";
  parameter Real Kp2 = 12.0 "stick position gain, 1/m";
  parameter Real Kd2 = 1.5 "stick velocity gain, s/m";
  parameter Real Ki2 = 3.0 "stick integral gain, 1/(s.m)";
  final parameter Real Kvf1 = A_A1/(Cq1*dpNom) "assumed boom velocity feedforward";
  final parameter Real Kvf2 = A_A2/(Cq2*dpNom) "assumed stick velocity feedforward";
  final parameter Real Kdist1 = 1.0/(A_A1*pFF) "assumed disturbance feedforward";
  parameter Real Cq1 = 1.2e-9 "assumed boom valve conductance, m3/(s.Pa)";
  parameter Real Cq2 = 1.2e-9 "assumed stick valve conductance, m3/(s.Pa)";
  parameter Real b1 = 8000.0 "assumed boom damping, N.s/m";
  parameter Real b2 = 5000.0 "assumed stick damping, N.s/m";
  parameter SI.Force Ff1 = 200.0 "assumed boom seal friction";
  parameter SI.Force Ff2 = 120.0 "assumed stick seal friction";
  parameter Real kStop = 1.0e7 "assumed end-stop stiffness, N/m";
  parameter Real dStop = 1.0e4 "assumed end-stop damping, N.s/m";
  parameter SI.Mass mInert1 = 50.0 "assumed minimum boom reflected inertia";
  parameter SI.Mass mInert2 = 20.0 "assumed minimum stick reflected inertia";

  // Energy and thermal assumptions
  parameter SI.Energy Ecap = 1.2e6 "declared hydraulic energy-use cap";
  parameter SI.Temperature T0 = 313.15 "assumed initial fluid temperature";
  parameter SI.Temperature Tamb = 293.15 "assumed ambient temperature";
  parameter SI.SpecificHeatCapacity cp_fluid = 1800.0 "assumed fluid heat capacity";
  parameter SI.Mass mFluid = 20.0 "assumed fluid mass in thermal lump";
  parameter Real UA = 20.0 "assumed thermal conductance, W/K";

  // Disturbance: 180 N load variation during middle third
  parameter SI.Force FdistAmp = 180.0 "stated disturbance amplitude";
  parameter SI.Time tDistStart = 14.0/3.0 "middle third start";
  parameter SI.Time tDistEnd = 28.0/3.0 "middle third end";
  parameter SI.Time dtDist = 0.05 "assumed smooth disturbance transition time";

  // Synchronized 200 Hz traces
  parameter SI.Time Ts = 0.005 "200 Hz sample period";

  // Continuous measured outputs
  output SI.VolumeFlowRate sensorSupplyFlow;
  output SI.Pressure sensorSupplyPressure;
  output SI.Length sensorActuatorState1;
  output SI.Length sensorActuatorState2;
  output SI.Velocity sensorVelocity1;
  output SI.Velocity sensorVelocity2;
  output SI.Energy sensorEnergyUse;
  output SI.Temperature sensorFluidTemperature;
  output SI.Length primaryTrackingError;
  output Real command1;
  output Real command2;
  output SI.Energy energyCap;
  output SI.Energy energyMargin;
  output Real energyFactor;
  output Real performanceDegradation;

  // Synchronized sampled traces
  output SI.Time time_s(start=0);
  output SI.Length state1_s(start=x1_0);
  output SI.Length state2_s(start=x2_0);
  output SI.Velocity velocity1_s(start=0);
  output SI.Velocity velocity2_s(start=0);
  output Real command1_s(start=0);
  output Real command2_s(start=0);
  output SI.VolumeFlowRate supplyFlow_s(start=0);
  output SI.Pressure supplyPressure_s(start=0);
  output SI.Energy energy_s(start=0);
  output SI.Temperature temperature_s(start=T0);
  output SI.Length trackingError_s(start=0);

  // Actuator states
  SI.Length x1(start=x1_0);
  SI.Length x2(start=x2_0);
  SI.Velocity v1(start=0);
  SI.Velocity v2(start=0);

  // Hydraulic chamber pressures
  SI.Pressure pA1(start=2.0e6);
  SI.Pressure pB1(start=0.6e6);
  SI.Pressure pA2(start=1.0e6);
  SI.Pressure pB2(start=0.6e6);
  SI.Pressure pS(start=3.5e6);

  // Integral control states
  Real int1(start=0);
  Real int2(start=0);

  // Energy and thermal states
  SI.Energy Euse(start=0);
  SI.Temperature T(start=T0);

  // Kinematic and dynamic variables
  Real theta1;
  Real theta2;
  SI.Length yP;
  Real J1;
  Real J2;
  SI.Force Fload1;
  SI.Force Fload2;
  SI.Mass mEff1;
  SI.Mass mEff2;
  SI.Force Fhyd1;
  SI.Force Fhyd2;
  SI.Force Ffr1;
  SI.Force Ffr2;
  SI.Force Fstop1;
  SI.Force Fstop2;
  SI.Force Fdist1;
  Real pulseDist;

  // Valve flows
  SI.VolumeFlowRate qA1;
  SI.VolumeFlowRate qB1;
  SI.VolumeFlowRate qA2;
  SI.VolumeFlowRate qB2;

  // Supply variables
  SI.Pressure pLoadSense;
  SI.Pressure pRef;
  SI.VolumeFlowRate Qdemand1;
  SI.VolumeFlowRate Qdemand2;
  SI.VolumeFlowRate Qdemand;
  SI.VolumeFlowRate Qleak;
  SI.VolumeFlowRate Qrelief;
  SI.VolumeFlowRate Qp;
  SI.Power Puse;
  SI.Power Ploss;

  // Reference and control variables
  Real omega;
  SI.Length r1;
  SI.Velocity r1d;
  SI.Acceleration r1dd;
  SI.Length r2;
  SI.Velocity r2d;
  SI.Acceleration r2dd;
  SI.Length e1;
  SI.Length e2;
  Real u1nom;
  Real u2nom;
  Real u1sat;
  Real u2sat;

equation
  // Kinematics: cylinder extensions map to boom/stick joint angles
  theta1 = theta1_0 + kTheta1*(x1 - x1_0);
  theta2 = theta2_0 + kTheta2*(x2 - x2_0);
  yP = L1*sin(theta1) + L2*sin(theta1 + theta2);
  J1 = (L1*cos(theta1) + L2*cos(theta1 + theta2))*kTheta1;
  J2 = L2*cos(theta1 + theta2)*kTheta2;
  Fload1 = mPayload*g*J1;
  Fload2 = mPayload*g*J2;
  mEff1 = mPayload*J1*J1 + mInert1;
  mEff2 = mPayload*J2*J2 + mInert2;

  // Cylinder dynamics
  Fhyd1 = pA1*A_A1 - pB1*A_B1;
  Fhyd2 = pA2*A_A2 - pB2*A_B2;
  Ffr1 = Ff1*tanh(v1/0.01);
  Ffr2 = Ff2*tanh(v2/0.01);
  Fstop1 = if x1 > x1_max then kStop*(x1 - x1_max) + dStop*max(0.0, v1)
           else if x1 < x1_min then kStop*(x1_min - x1) - dStop*max(0.0, -v1)
           else 0.0;
  Fstop2 = if x2 > x2_max then kStop*(x2 - x2_max) + dStop*max(0.0, v2)
           else if x2 < x2_min then kStop*(x2_min - x2) - dStop*max(0.0, -v2)
           else 0.0;

  der(x1) = v1;
  der(v1) = (Fhyd1 - Fload1 - Fdist1 - b1*v1 - Ffr1 - Fstop1)/mEff1;
  der(x2) = v2;
  der(v2) = (Fhyd2 - Fload2 - b2*v2 - Ffr2 - Fstop2)/mEff2;

  // Controlled 180 N load variation during middle third
  pulseDist = 0.5*(1.0 + tanh((time - tDistStart)/dtDist))*
              0.5*(1.0 + tanh((tDistEnd - time)/dtDist));
  Fdist1 = FdistAmp*pulseDist;

  // Hydraulic chamber volumes and compressibility
  // Cap-side volume increases with extension; rod-side volume decreases
  // Pressure dynamics use double-acting cylinder continuity
  qA1 = if u1sat >= 0.0 then Cq1*u1sat*max(0.0, pS - pA1) else Cq1*u1sat*max(0.0, pA1 - pT);
  qB1 = if u1sat >= 0.0 then Cq1*u1sat*max(0.0, pB1 - pT) else Cq1*u1sat*max(0.0, pS - pB1);
  qA2 = if u2sat >= 0.0 then Cq2*u2sat*max(0.0, pS - pA2) else Cq2*u2sat*max(0.0, pA2 - pT);
  qB2 = if u2sat >= 0.0 then Cq2*u2sat*max(0.0, pB2 - pT) else Cq2*u2sat*max(0.0, pS - pB2);

  der(pA1) = beta/(Vd1 + A_A1*x1)*(qA1 - A_A1*v1);
  der(pB1) = beta/(Vd1 + A_B1*(x1_max - x1))*(A_B1*v1 - qB1);
  der(pA2) = beta/(Vd2 + A_A2*x2)*(qA2 - A_A2*v2);
  der(pB2) = beta/(Vd2 + A_B2*(x2_max - x2))*(A_B2*v2 - qB2);

  // Load-sensing pump shared by two valve sections, with relief
  pLoadSense = max(pA1, max(pB1, max(pA2, pB2)));
  pRef = min(pRelief, pLoadSense + pMargin);
  Qdemand1 = if u1sat >= 0.0 then max(0.0, qA1) else max(0.0, -qB1);
  Qdemand2 = if u2sat >= 0.0 then max(0.0, qA2) else max(0.0, -qB2);
  Qdemand = Qdemand1 + Qdemand2;
  Qleak = kleak*(pS - pT);
  Qrelief = max(0.0, Krelief*(pS - pRelief));
  Qp = max(0.0, min(Qpmax, Qdemand + Qleak + Kpump*(pRef - pS)));
  der(pS) = beta/Vs*(Qp - Qdemand - Qleak - Qrelief);

  // Energy accounting and thermal loss
  Puse = (pS - pT)*Qp;
  der(Euse) = Puse;
  Ploss = (pS - pT)*(Qleak + Qrelief);
  der(T) = (Ploss - UA*(T - Tamb))/(mFluid*cp_fluid);

  // Repeated actuation cycle
  omega = 2*pi/Tcyc;
  r1 = x1_ref0 + x1_amp*sin(omega*time);
  r1d = x1_amp*omega*cos(omega*time);
  r1dd = -x1_amp*omega*omega*sin(omega*time);
  r2 = x2_ref0 - x2_amp*sin(omega*time);
  r2d = -x2_amp*omega*cos(omega*time);
  r2dd = x2_amp*omega*omega*sin(omega*time);

  e1 = r1 - x1;
  e2 = r2 - x2;

  // Energy-aware motion control with bounded degradation
  energyFactor = 1.0 - 0.5*max(0.0, min(1.0, (Euse - 0.8*Ecap)/(0.2*Ecap)));
  performanceDegradation = 1.0 - energyFactor;

  u1nom = energyFactor*(Kvf1*r1d + Kp1*e1 + Kd1*(r1d - v1) + Ki1*int1 + Kdist1*Fdist1);
  u2nom = energyFactor*(Kvf2*r2d + Kp2*e2 + Kd2*(r2d - v2) + Ki2*int2);
  u1sat = max(-1.0, min(1.0, u1nom));
  u2sat = max(-1.0, min(1.0, u2nom));

  // Integral anti-windup
  der(int1) = if abs(u1sat) < 0.999 then e1 else 0.0;
  der(int2) = if abs(u2sat) < 0.999 then e2 else 0.0;

  // Continuous sensor outputs
  sensorSupplyFlow = Qp;
  sensorSupplyPressure = pS;
  sensorActuatorState1 = x1;
  sensorActuatorState2 = x2;
  sensorVelocity1 = v1;
  sensorVelocity2 = v2;
  sensorEnergyUse = Euse;
  sensorFluidTemperature = T;
  primaryTrackingError = abs(r1 - x1);
  command1 = u1sat;
  command2 = u2sat;
  energyCap = Ecap;
  energyMargin = Ecap - Euse;

  // Synchronized 200 Hz state, command, and sensor traces
  when sample(0, Ts) then
    time_s = time;
    state1_s = x1;
    state2_s = x2;
    velocity1_s = v1;
    velocity2_s = v2;
    command1_s = u1sat;
    command2_s = u2sat;
    supplyFlow_s = Qp;
    supplyPressure_s = pS;
    energy_s = Euse;
    temperature_s = T;
    trackingError_s = abs(r1 - x1);
  end when;

  // Physical bounds and performance requirements
  assert(noEvent(Qp <= Qpmax + 1e-9), "pump flow bound violated");
  assert(noEvent(pS <= pRelief + 1.0e4), "relief pressure bound violated");
  assert(noEvent(Euse <= Ecap + 1.0e-3), "declared energy-use cap violated");
  assert(noEvent(x1 >= x1_min - 1.0e-4 and x1 <= x1_max + 1.0e-4), "boom cylinder stroke bound violated");
  assert(noEvent(x2 >= x2_min - 1.0e-4 and x2 <= x2_max + 1.0e-4), "stick cylinder stroke bound violated");
  assert(noEvent(pA1 >= 0.0 and pB1 >= 0.0 and pA2 >= 0.0 and pB2 >= 0.0), "cylinder pressure nonnegativity violated");
  assert(noEvent(u1sat >= -1.0 and u1sat <= 1.0 and u2sat >= -1.0 and u2sat <= 1.0), "valve saturation bound violated");
  assert(noEvent(energyFactor >= 0.5 and energyFactor <= 1.0), "bounded performance degradation violated");
  assert(noEvent(time < 9.1 or abs(r1 - x1) <= 0.02), "primary tracking error > 0.02 m after 9.1 s");
  assert(noEvent(abs(x1) < 1.0e12 and abs(v1) < 1.0e12 and abs(x2) < 1.0e12 and abs(v2) < 1.0e12),
         "finite actuator state violated");
  assert(noEvent(pA1 < 1.0e12 and pB1 < 1.0e12 and pA2 < 1.0e12 and pB2 < 1.0e12 and pS < 1.0e12),
         "finite pressure state violated");
  assert(noEvent(abs(u1sat) < 1.0e12 and abs(u2sat) < 1.0e12 and abs(int1) < 1.0e12 and abs(int2) < 1.0e12),
         "finite control state violated");
  assert(noEvent(Euse < 1.0e12 and T < 1.0e12 and Qp < 1.0e12), "finite energy/thermal/flow state violated");

  // Terminal cycle completion, terminal error, and energy cap
  when terminal() then
    assert(abs(x1 - x1_ref0) <= 0.02 and abs(x2 - x2_ref0) <= 0.02, "cycle completion at 14 s failed");
    assert(abs(r1 - x1) <= 0.02, "terminal primary tracking error failed");
    assert(Euse <= Ecap, "terminal energy cap failed");
  end when;

initial equation
  x1 = x1_0;
  x2 = x2_0;
  v1 = 0.0;
  v2 = 0.0;
  pB1 = pT;
  pB2 = pT;
  pA1 = (Fload1 + pB1*A_B1)/A_A1;
  pA2 = (Fload2 + pB2*A_B2)/A_A2;
  pS = min(pRelief, max(pA1, max(pB1, max(pA2, pB2))) + pMargin);
  Euse = 0.0;
  T = T0;
  int1 = 0.0;
  int2 = 0.0;

  annotation(
    experiment(StopTime=14.0, Interval=0.005, Tolerance=1.0e-6),
    __OpenModelica_simulationFlags(s="dassl")
  );
end HydBoomConserveD;