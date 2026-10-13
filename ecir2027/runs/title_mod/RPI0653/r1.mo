model PneuGripPositionE
  "Pneumatic gripper position servo: two opposing chambers, pressure-aware PID,
   mechanical end stops, leakage, compressible gas, 120 N middle-third disturbance,
   250 Hz control, fail-closed acceptance over 16 s."

  // === Specified parameters ===
  parameter Modelica.SIunits.Length L = 0.035 "cylinder travel";
  parameter Modelica.SIunits.Area Ap = 0.0012 "piston area";
  parameter Modelica.SIunits.Mass mfinger = 0.8 "each gripper finger mass";
  parameter Modelica.SIunits.MassFlowRate wmax = 0.001 "valve command magnitude bound";
  parameter Modelica.SIunits.Force FextMag = 120.0 "external load magnitude";
  parameter Modelica.SIunits.Frequency fs = 250.0 "control loop rate";
  parameter Real travelFrac = 0.70 "target fraction of available travel";
  parameter Modelica.SIunits.Time tEnd = 16.0 "total run time";
  parameter Modelica.SIunits.Time tSettle = 10.4 "settling check time";
  parameter Modelica.SIunits.Length errTol = 0.011 "tracking error tolerance after settle";

  // === Assumed parameters (not specified in request; labeled, not fabricated from examples) ===
  parameter Modelica.SIunits.Pressure Ps = 6.0e5 "supply pressure (assumed)";
  parameter Modelica.SIunits.Pressure Pr = 1.01325e5 "return pressure (assumed)";
  parameter Modelica.SIunits.Temperature Tgas = 293.15 "gas temperature (assumed)";
  parameter Modelica.SIunits.SpecificHeatCapacity Rg = 287.0 "air gas constant (assumed)";
  parameter Modelica.SIunits.Volume Vdead = 1.0e-5 "chamber dead volume (assumed)";
  parameter Real LeakG(min=0) = 1.0e-12 "leakage conductance [kg/(s.Pa)] (assumed)";
  parameter Real bvisc = 50.0 "viscous friction coefficient [N.s/m] (assumed)";
  parameter Modelica.SIunits.Stiffness kend = 1.0e6 "end-stop stiffness [N/m] (assumed)";
  parameter Modelica.SIunits.DampingCoefficient cend = 1.0e3 "end-stop damping [N.s/m] (assumed)";
  parameter Real Kp = 0.005 "PID proportional gain [kg/(s.m)] (assumed)";
  parameter Real Ki = 0.020 "PID integral gain [kg/(s.m.s)] (assumed)";
  parameter Real Kd = 0.0005 "PID derivative gain [kg.s/(s.m)] (assumed)";

  // === Derived parameters ===
  parameter Modelica.SIunits.Mass m = 2.0*mfinger "total moving mass (two fingers)";
  parameter Modelica.SIunits.Time Ts = 1.0/fs "control sample period";
  parameter Modelica.SIunits.Length xref = travelFrac*L "target position (70% travel)";
  parameter Modelica.SIunits.Time tDist0 = tEnd/3.0 "disturbance start (middle third of run)";
  parameter Modelica.SIunits.Time tDist1 = 2.0*tEnd/3.0 "disturbance end (middle third of run)";

  // === Continuous plant states (also sensors) ===
  Modelica.SIunits.Length x(start=0.0, fixed=true) "actuator position (sensor)";
  Modelica.SIunits.Velocity v(start=0.0, fixed=true) "actuator velocity (sensor)";
  Modelica.SIunits.Pressure pA(start=Pr, fixed=true) "chamber A pressure (sensor)";
  Modelica.SIunits.Pressure pB(start=Pr, fixed=true) "chamber B pressure (sensor)";

  // === Discrete control / valve states ===
  discrete Modelica.SIunits.MassFlowRate wA(start=0.0) "valve A command = applied mass flow (sensor)";
  discrete Modelica.SIunits.MassFlowRate wB(start=0.0) "valve B command = applied mass flow";
  discrete Real integ(start=0.0) "integral accumulator";
  discrete Real eprev(start=0.0) "previous sample error";
  discrete Real maxErrSettle(start=0.0) "max tracking error since settle time";
  discrete Boolean boundsOKd(start=true) "running sampled bounds check";
  discrete Boolean pass(start=false) "fail-closed acceptance flag";

  // === Computed continuous quantities ===
  Modelica.SIunits.MassFlowRate valveCmdMag "measured valve command magnitude (sensor)";
  Modelica.SIunits.Volume VA "chamber A volume";
  Modelica.SIunits.Volume VB "chamber B volume";
  Modelica.SIunits.Force Fpiston "pneumatic force";
  Modelica.SIunits.Force Ffric "friction force";
  Modelica.SIunits.Force Fend "end-stop force";
  Modelica.SIunits.Force Fext "external disturbance load";
  Modelica.SIunits.Length trackErr "instantaneous tracking error magnitude";
  Boolean boundsOKc "continuous bounds check";
  Boolean valid "finiteness / NaN check";

protected
  discrete Real e_aux(start=0.0) "current sample error";
  discrete Real de_aux(start=0.0) "current sample error derivative";
  discrete Real uRaw_aux(start=0.0) "raw controller output before saturation";
  discrete Integer sat_aux(start=0) "saturation state: -1,0,+1";

initial equation
  x = 0.0;
  v = 0.0;
  pA = Pr;
  pB = Pr;

equation
  // Chamber volumes (compressibility via ideal-gas pressure dynamics)
  VA = Vdead + Ap*x;
  VB = Vdead + Ap*(L - x);

  // Pressure dynamics: ideal gas, leakage to return, volume change work.
  // der(P) = (R*T/V)*(dm/dt) - (P/V)*(dV/dt)
  der(pA) = (Rg*Tgas/VA)*(wA - LeakG*(pA - Pr)) - (pA/VA)*Ap*v;
  der(pB) = (Rg*Tgas/VB)*(wB - LeakG*(pB - Pr)) + (pB/VB)*Ap*v;

  // Forces
  Fpiston = Ap*(pA - pB);
  Ffric = bvisc*v;
  // Mechanical end stops at x=0 and x=L (stiff spring + damping, only when penetrating)
  Fend = if x > L then -kend*(x - L) - cend*v
         elseif x < 0.0 then -kend*x - cend*v
         else 0.0;
  // 120 N external load applied during middle third of the 16 s run
  Fext = if time >= tDist0 and time <= tDist1 then FextMag else 0.0;

  // Equation of motion for the two opposing fingers (combined mass)
  m*der(v) = Fpiston - Ffric + Fend - Fext;
  der(x) = v;

  // Valve command magnitude measurement (symmetric drive: wB = -wA)
  valveCmdMag = abs(wA);

  // Primary tracking error
  trackErr = abs(xref - x);

  // Finiteness / NaN check (NaN compares unequal to itself)
  valid = (x == x) and (v == v) and (pA == pA) and (pB == pB)
          and (wA == wA) and (wB == wB) and (integ == integ)
          and abs(x) < 1.0e6 and abs(v) < 1.0e6
          and pA < 1.0e9 and pB < 1.0e9;

  // Continuous bounds: travel, velocity, pressure, valve command
  boundsOKc = x >= -1.0e-3 and x <= L + 1.0e-3
              and abs(v) <= 2.0
              and pA >= 0.0 and pA <= 2.0*Ps
              and pB >= 0.0 and pB <= 2.0*Ps
              and abs(wA) <= wmax*(1.0 + 1.0e-6)
              and abs(wB) <= wmax*(1.0 + 1.0e-6)
              and valid;

algorithm
  when sample(0, Ts) then
    // Position error and finite-difference derivative
    e_aux := xref - x;
    de_aux := (e_aux - eprev)/Ts;
    // PID core (pressure-awareness via saturation guards below)
    uRaw_aux := Kp*e_aux + Ki*integ + Kd*de_aux;
    // Pressure-aware guard: do not push a chamber further toward supply if already near supply
    if pA > 0.95*Ps and uRaw_aux > 0.0 then
      uRaw_aux := 0.0;
    end if;
    if pB > 0.95*Ps and uRaw_aux < 0.0 then
      uRaw_aux := 0.0;
    end if;
    // Command magnitude bound (fail-closed saturation)
    if uRaw_aux > wmax then
      wA := wmax;
      sat_aux := 1;
    elseif uRaw_aux < -wmax then
      wA := -wmax;
      sat_aux := -1;
    else
      wA := uRaw_aux;
      sat_aux := 0;
    end if;
    wB := -wA;
    // Anti-windup: integrate only when not saturating in the direction of the error
    if sat_aux == 0 or (sat_aux == 1 and e_aux < 0.0) or (sat_aux == -1 and e_aux > 0.0) then
      integ := integ + e_aux*Ts;
    end if;
    eprev := e_aux;
    // Running maximum of tracking error from settle time onward
    if time >= tSettle then
      maxErrSettle := max(maxErrSettle, trackErr);
    end if;
    // Running conjunction of bounds over all samples
    boundsOKd := boundsOKd and boundsOKc;
    // Fail-closed acceptance: becomes true only at end if every condition held
    if time >= tEnd then
      pass := boundsOKd and (maxErrSettle < errTol);
    end if;
  end when;

end PneuGripPositionE;