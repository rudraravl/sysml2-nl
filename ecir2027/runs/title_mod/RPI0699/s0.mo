model AirStagePositionC
  // Stated requirement values
  parameter Real L=0.70 "available travel [m]";
  parameter Real r=0.70*L "target position, 70 percent of travel [m]";
  parameter Real m=42.0 "carriage mass [kg]";
  parameter Real qmax=0.014 "maximum valve command magnitude [kg/s]";
  parameter Real Fdist=90.0 "external load disturbance magnitude [N]";
  parameter Real tDistStart=4.0 "disturbance start, middle third of 12 s [s]";
  parameter Real tDistEnd=8.0 "disturbance end, middle third of 12 s [s]";

  // Plant values not stated in the requirement are assumed and marked accordingly
  parameter Real g=9.81 "gravity [m/s2]";
  parameter Real Aa=0.0050 "chamber A piston area [m2] (assumed, unequal)";
  parameter Real Ab=0.0040 "chamber B rod-side area [m2] (assumed, unequal)";
  parameter Real VdeadA=0.00050 "chamber A explicit dead volume [m3] (assumed)";
  parameter Real VdeadB=0.00050 "chamber B explicit dead volume [m3] (assumed)";
  parameter Real Ps=7.0e5 "declared supply pressure [Pa] (assumed)";
  parameter Real Pr=1.0e5 "declared return pressure [Pa] (assumed)";
  parameter Real T=293.15 "gas temperature [K] (assumed)";
  parameter Real Rs=287.05 "specific gas constant of air [J/(kg.K)]";
  parameter Real Cleak=1.0e-10 "leakage conductance to return [kg/(s.Pa)] (assumed)";
  parameter Real b=50.0 "viscous friction [N.s/m] (assumed)";
  parameter Real kstop=1.0e6 "end-stop stiffness [N/m] (assumed)";
  parameter Real cstop=1.0e4 "end-stop damping [N.s/m] (assumed)";

  // Controller gains not stated in the requirement are assumed
  parameter Real Kp_pos=50.0 "position proportional gain [1/s2] (assumed)";
  parameter Real Kd_pos=20.0 "position velocity gain [1/s] (assumed)";
  parameter Real Ki_pos=8.0 "position integral gain [1/s3] (assumed)";
  parameter Real Kforce=2.0e-5 "force-error-to-flow gain [kg/(s.N)] (assumed)";
  parameter Real Kaw=1.0 "anti-windup gain [m/(kg/s)] (assumed)";

  // Initial conditions
  parameter Real x0=0.0 "initial coordinate [m] (assumed lower end)";
  parameter Real v0=0.0 "initial velocity [m/s]";
  parameter Real PB0=Pr "initial chamber B pressure [Pa] (assumed at return)";
  parameter Real PA0=(m*g + PB0*Ab)/Aa "initial chamber A pressure [Pa] (assumed equilibrium)";

  // Dynamic states
  Real x(start=x0, fixed=true) "actuator position [m]";
  Real v(start=v0, fixed=true) "actuator velocity [m/s]";
  Real PA(start=PA0, fixed=true) "chamber A pressure [Pa]";
  Real PB(start=PB0, fixed=true) "chamber B pressure [Pa]";
  Real int_e(start=0, fixed=true) "position integral state [m.s]";

  // Tracking, sensors, and disturbance
  Real e "position error r-x [m]";
  Real trackingError "absolute tracking error [m]";
  Real Fload "external load disturbance [N]";
  Real positionSensor "measured position [m]";
  Real velocitySensor "measured velocity [m/s]";
  Real pressureASensor "measured chamber A pressure [Pa]";
  Real pressureBSensor "measured chamber B pressure [Pa]";
  Real valveCommandSensor "measured net valve command [kg/s]";

  // Mechanical variables
  Real acc "carriage acceleration [m/s2]";
  Real Fstop "end-stop force [N]";
  Real Fmeas "measured cylinder force from pressures [N]";
  Real Fdes "desired cylinder force from pressure-aware PID [N]";
  Real Ferr "force error [N]";

  // Pneumatic variables
  Real VA "chamber A volume [m3]";
  Real VB "chamber B volume [m3]";
  Real dVA "chamber A volume rate [m3/s]";
  Real dVB "chamber B volume rate [m3/s]";
  Real PA_safe "lower-bounded pressure A for compressibility [Pa]";
  Real PB_safe "lower-bounded pressure B for compressibility [Pa]";
  Real betaA "isothermal bulk modulus chamber A [Pa]";
  Real betaB "isothermal bulk modulus chamber B [Pa]";
  Real rhoA "gas density chamber A [kg/m3]";
  Real rhoB "gas density chamber B [kg/m3]";
  Real qLeakA "leakage mass flow from chamber A to return [kg/s]";
  Real qLeakB "leakage mass flow from chamber B to return [kg/s]";
  Real dmA "net mass rate chamber A [kg/s]";
  Real dmB "net mass rate chamber B [kg/s]";

  // Valve variables
  Real phiFillA "fill feasibility for chamber A [1]";
  Real phiExhA "exhaust feasibility for chamber A [1]";
  Real phiFillB "fill feasibility for chamber B [1]";
  Real phiExhB "exhaust feasibility for chamber B [1]";
  Real qA_fill_cmd "chamber A fill valve command [kg/s]";
  Real qA_exh_cmd "chamber A exhaust valve command [kg/s]";
  Real qB_fill_cmd "chamber B fill valve command [kg/s]";
  Real qB_exh_cmd "chamber B exhaust valve command [kg/s]";
  Real qA_in "actual mass flow into chamber A [kg/s]";
  Real qA_out "actual mass flow out of chamber A [kg/s]";
  Real qB_in "actual mass flow into chamber B [kg/s]";
  Real qB_out "actual mass flow out of chamber B [kg/s]";
  Real qDiffRaw "unclamped net flow command [kg/s]";
  Real qDiff "clamped net flow command [kg/s]";
  Real valveCommand "net valve command [kg/s]";

equation
  // Setpoint, tracking, and synchronized sensors
  e = r - x;
  trackingError = abs(e);
  positionSensor = x;
  velocitySensor = v;
  pressureASensor = PA;
  pressureBSensor = PB;
  valveCommandSensor = qDiff;
  valveCommand = qDiff;

  // Controlled 90 N downward load during the middle third of the 12 s run
  Fload = if time >= tDistStart and time <= tDistEnd then Fdist else 0.0;

  // Mechanical dynamics with mechanical end stops
  Fstop = if noEvent(x > L) then kstop*(L - x) - cstop*v elseif noEvent(x < 0) then kstop*(0.0 - x) - cstop*v else 0.0;
  acc = (PA*Aa - PB*Ab - m*g - Fload + Fstop - b*v)/m;
  der(x) = v;
  der(v) = acc;

  // Chamber volumes, explicit dead volumes, and fluid compressibility
  VA = VdeadA + Aa*x;
  VB = VdeadB + Ab*(L - x);
  dVA = Aa*v;
  dVB = -Ab*v;
  PA_safe = max(PA, 1000.0);
  PB_safe = max(PB, 1000.0);
  betaA = PA_safe;
  betaB = PB_safe;
  rhoA = PA_safe/(Rs*T);
  rhoB = PB_safe/(Rs*T);

  // Leakage and pressure dynamics
  qLeakA = Cleak*(PA - Pr);
  qLeakB = Cleak*(PB - Pr);
  dmA = qA_in - qA_out - qLeakA;
  dmB = qB_in - qB_out - qLeakB;
  der(PA) = (betaA/VA)*(dmA - rhoA*dVA);
  der(PB) = (betaB/VB)*(dmB - rhoB*dVB);

  // Valve feasibility from declared supply and return pressures
  phiFillA = if noEvent(Ps > PA) then 1.0 else 0.0;
  phiExhA = if noEvent(PA > Pr) then 1.0 else 0.0;
  phiFillB = if noEvent(Ps > PB) then 1.0 else 0.0;
  phiExhB = if noEvent(PB > Pr) then 1.0 else 0.0;

  // Pressure-aware PID: desired force compared with measured pressure-generated force
  Fmeas = PA*Aa - PB*Ab;
  Fdes = m*g + m*(Kp_pos*e + Kd_pos*(-v) + Ki_pos*int_e);
  Ferr = Fdes - Fmeas;
  qDiffRaw = Kforce*Ferr;
  qDiff = if qDiffRaw > qmax then qmax elseif qDiffRaw < -qmax then -qmax else qDiffRaw;
  der(int_e) = e - Kaw*(qDiffRaw - qDiff);

  // Independent fill/exhaust proportional valves for both chambers
  qA_fill_cmd = max(qDiff, 0.0);
  qA_exh_cmd = max(-qDiff, 0.0);
  qB_fill_cmd = max(-qDiff, 0.0);
  qB_exh_cmd = max(qDiff, 0.0);

  qA_in = qA_fill_cmd*phiFillA;
  qA_out = qA_exh_cmd*phiExhA;
  qB_in = qB_fill_cmd*phiFillB;
  qB_out = qB_exh_cmd*phiExhB;

  // Required bounds and finite-value checks
  assert(x >= -0.001 and x <= L + 0.001, "travel bound violated");
  assert(abs(qDiff) <= qmax + 1.0e-9, "valve command bound violated");
  assert(PA >= -1000.0 and PA <= Ps + 1.0e5, "pressure A bound violated");
  assert(PB >= -1000.0 and PB <= Ps + 1.0e5, "pressure B bound violated");
  assert(abs(v) <= 50.0, "velocity bound violated");
  assert(time < 7.8 or abs(x - r) <= 0.013, "primary tracking error after 7.8 s not met");
  assert(abs(PA) < 1.0e9 and abs(PB) < 1.0e9, "non-finite pressure");
  assert(abs(x) < 1.0e9 and abs(v) < 1.0e9 and abs(acc) < 1.0e9, "non-finite physical value");
  assert(abs(qDiffRaw) < 1.0e9 and abs(qDiff) < 1.0e9, "non-finite command value");
  assert(abs(Fdes) < 1.0e9 and abs(Ferr) < 1.0e9 and abs(int_e) < 1.0e9, "non-finite control or estimator value");

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1.0e-6, Interval = 0.008),
    Documentation(info = "125 Hz output interval (0.008 s) for a 12 s closed-loop pneumatic actuator run.")
  );
end AirStagePositionC;