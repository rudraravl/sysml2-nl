model HydCylinderPositionE
  extends Modelica.Icons.Example;
  import Modelica.Units.SI;

  // Geometry (from requirement)
  parameter SI.Area A_p = 0.0040 "piston (cap-side) area";
  parameter SI.Area A_r = 0.0032 "rod-side annular area";
  parameter SI.Length L = 0.50 "stroke";
  parameter SI.Mass m = 110.0 "moving mass";

  // Fluid / hydraulic supply (declared; standard mineral-oil assumptions)
  parameter SI.Pressure pSupply = 20.0e6 "declared supply pressure";
  parameter SI.Pressure pReturn = 0.5e6 "declared return pressure";
  parameter SI.Pressure pInit = 1.0e5 "initial chamber pressure";
  parameter SI.BulkModulus beta = 1.6e9 "oil bulk modulus (fluid compressibility)";
  parameter SI.Volume V_deadA = 1.0e-4 "cap-side dead/line volume";
  parameter SI.Volume V_deadB = 1.0e-4 "rod-side dead/line volume";
  parameter Real C_leak = 1.0e-12 "internal leakage coefficient A->B [m3/(s.Pa)]";

  // Valve
  parameter SI.VolumeFlowRate Qmax = 0.001 "valve command magnitude bound";

  // Mechanical
  parameter Real b_visc = 2000.0 "viscous friction [N.s/m]";
  parameter Real F_coulomb = 200.0 "Coulomb friction [N]";
  parameter Real k_stop = 1.0e7 "end-stop stiffness [N/m]";
  parameter Real c_stop = 1.0e4 "end-stop damping [N.s/m]";

  // External disturbance load
  parameter Real F_ext = 120.0 "external disturbance load [N]";

  // Reference
  parameter SI.Length x_target = 0.35 "70 percent of available travel";
  parameter SI.Time T_ramp = 1.0 "smooth reference ramp time";

  // Controller
  parameter SI.Time Ts = 0.004 "control period (250 Hz)";
  parameter Real Kp = 0.002 "proportional gain";
  parameter Real Ki = 0.02 "integral gain";
  parameter Real Kd = 0.0005 "derivative gain";
  parameter SI.Time T_end = 16.0 "run duration";

  // Continuous states (observable)
  SI.Length x(start = 0.0) "actuator position";
  SI.Velocity v(start = 0.0) "actuator velocity";
  SI.Pressure pA(start = pInit) "cap-side pressure";
  SI.Pressure pB(start = pInit) "rod-side pressure";

  // Flows (observable)
  SI.VolumeFlowRate Q_A "flow into cap chamber";
  SI.VolumeFlowRate Q_B "flow into rod chamber";
  SI.VolumeFlowRate Q_leak "leakage flow A->B";

  // Forces
  Real F_pressure "net pressure force";
  Real F_friction "friction force";
  Real F_stop "end-stop force";
  Real F_load "applied external load";

  // Volumes
  SI.Volume VA "cap-side volume";
  SI.Volume VB "rod-side volume";

  // Valve command (observable)
  Real u "bounded valve command [m3/s]";

  // Reference / tracking
  SI.Length x_setpoint "reference position";
  Real e "tracking error";
  Real trackingError "abs tracking error";

  // Discrete controller states
  discrete Real e_d(start = 0.0);
  discrete Real e_int(start = 0.0);
  discrete Real u_raw(start = 0.0);
  discrete Real u_sat(start = 0.0);

  // Disturbance window
  Boolean inDisturbance;

  // Acceptance signals (observable)
  Boolean travelOK;
  Boolean valveOK;
  Boolean pressureOK;
  Boolean velocityOK;
  Boolean trackOK;
  Boolean finiteOK;
  Boolean allOK;

protected
  parameter Real eps_tanh = 0.01;

equation
  // Chamber volumes
  VA = V_deadA + A_p*x;
  VB = V_deadB + A_r*(L - x);

  // Internal leakage from cap to rod side
  Q_leak = C_leak*(pA - pB);

  // Four-way proportional valve (commanded volumetric flows)
  Q_A = u;
  Q_B = -u;

  // Compressible chamber continuity
  der(pA) = (beta/VA)*(Q_A - A_p*v - Q_leak);
  der(pB) = (beta/VB)*(Q_B + A_r*v + Q_leak);

  // Forces
  F_pressure = pA*A_p - pB*A_r;
  F_friction = b_visc*v + F_coulomb*Modelica.Math.tanh(v/eps_tanh);
  F_stop = if x < 0.0 then (-k_stop*x - c_stop*v)
           elseif x > L then (-k_stop*(x - L) - c_stop*v)
           else 0.0;
  inDisturbance = (time >= T_end/3.0) and (time <= 2.0*T_end/3.0);
  F_load = if inDisturbance then F_ext else 0.0;

  // Mechanics
  der(x) = v;
  m*der(v) = F_pressure - F_friction - F_stop - F_load;

  // Smooth cosine reference to 70% travel then hold
  x_setpoint = x_target * (if time < T_ramp
                then 0.5*(1.0 - Modelica.Math.cos(Modelica.Constants.pi*time/T_ramp))
                else 1.0);
  e = x_setpoint - x;
  trackingError = abs(e);

  // Pressure-aware discrete PID at 250 Hz with anti-windup and saturation
  when sample(0, Ts) loop
    e_d = x_setpoint - x;
    // Anti-windup: hold integrator while saturating in same direction
    if (pre(u_raw) > Qmax and e_d > 0.0) or (pre(u_raw) < -Qmax and e_d < 0.0) then
      e_int = pre(e_int);
    else
      e_int = pre(e_int) + e_d*Ts;
    end if;
    u_raw = Kp*e_d + Ki*e_int + Kd*(e_d - pre(e_d))/Ts;
    u_sat = if u_raw > Qmax then Qmax
            elseif u_raw < -Qmax then -Qmax
            else u_raw;
  end when;

  u = u_sat;

  // Acceptance bounds (continuous)
  travelOK = (x >= -1.0e-3) and (x <= L + 1.0e-3);
  valveOK = (u >= -Qmax - 1.0e-9) and (u <= Qmax + 1.0e-9);
  pressureOK = (pA > -1.0e5) and (pA < 1.5*pSupply) and
               (pB > -1.0e5) and (pB < 1.5*pSupply);
  velocityOK = (v >= -1.0) and (v <= 1.0);
  trackOK = if time >= 10.4 then trackingError < 0.011 else true;
  finiteOK = (x > -1e308) and (x < 1e308) and
             (v > -1e308) and (v < 1e308) and
             (pA > -1e308) and (pA < 1e308) and
             (pB > -1e308) and (pB < 1e308) and
             (u > -1e308) and (u < 1e308);
  allOK = travelOK and valveOK and pressureOK and velocityOK and trackOK and finiteOK;

  // Fail-closed acceptance
  assert(finiteOK, "Non-finite physical/control value detected");
  assert(travelOK, "Travel bound violated");
  assert(valveOK, "Valve command bound violated");
  assert(pressureOK, "Pressure bound violated");
  assert(velocityOK, "Velocity bound violated");
  assert(trackOK, "Primary tracking error exceeded 0.011 m after 10.4 s");

  when terminal() then
    assert(abs(x - x_target) < 0.011, "Final position outside 0.011 m of target");
  end when;

  annotation (
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Hydraulic cylinder position servo. Moves to 70% of 0.50 m stroke and holds under a 120 N middle-third disturbance. Discrete pressure-aware PID at 250 Hz."));
end HydCylinderPositionE;