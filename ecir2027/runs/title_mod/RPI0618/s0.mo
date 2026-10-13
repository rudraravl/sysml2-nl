model HydCylinderTrackF
  "Hydraulic double-acting cylinder tracking a smooth two-segment trajectory under payload disturbance"
  extends Modelica.Icons.Example;

  // === Physical parameters ===
  parameter Real Ap = 0.0040 "Piston (cap-side) area [m2]";
  parameter Real Ar = 0.0032 "Rod-side area [m2]";
  parameter Real L = 0.50 "Stroke [m]";
  parameter Real m_mass = 110.0 "Moving mass [kg]";
  parameter Real Qmax = 0.001 "Maximum valve flow [m3/s]";
  parameter Real Psupply = 10.0e6 "Supply pressure [Pa]";
  parameter Real Ptank = 0.1e6 "Tank pressure [Pa]";
  parameter Real Prelief = 18.0e6 "Relief-valve cracking pressure [Pa]";
  parameter Real beta = 1.4e9 "Effective oil bulk modulus [Pa]";
  parameter Real Vdead1 = 1.0e-4 "Dead volume cap end [m3]";
  parameter Real Vdead2 = 1.0e-4 "Dead volume rod end [m3]";
  parameter Real b_visc = 3000.0 "Viscous friction coefficient [N.s/m]";
  parameter Real C_leak = 5.0e-13 "Internal leakage conductance [m3/(s.Pa)]";
  parameter Real R_relief = 5.0e8 "Relief-valve resistance [Pa.s/m3]";
  parameter Real Fdist = 319.0 "Payload step disturbance force [N]";

  // === Control gains ===
  parameter Real Kff = 1.0 "Feedforward gain";
  parameter Real Kp_pos = 0.03 "Position feedback gain [m3/(s.m)]";
  parameter Real Kp_vel = 0.003 "Velocity feedback gain [m3/(s.(m/s))]";
  parameter Real Kp_pres = 1.0e-8 "Pressure (force) feedback gain [m3/(s.N)]";

  // === Initial conditions ===
  parameter Real x0 = 0.05 "Initial cylinder position [m]";
  parameter Real P10 = 0.8e6 "Initial cap-end pressure [Pa]";
  parameter Real P20 = 1.0e6 "Initial rod-end pressure [Pa]";

  // === Dynamic states ===
  Real x(start=x0, fixed=true) "Cylinder position [m]";
  Real v(start=0.0, fixed=true) "Cylinder velocity [m/s]";
  Real P1(start=P10, fixed=true) "Cap-end chamber pressure [Pa]";
  Real P2(start=P20, fixed=true) "Rod-end chamber pressure [Pa]";

  // === Derived and observed variables ===
  Real a "Cylinder acceleration [m/s2]";
  Real V1 "Cap-end chamber volume [m3]";
  Real V2 "Rod-end chamber volume [m3]";
  Real Q1 "Valve flow to cap end [m3/s]";
  Real Q2 "Valve flow from rod end [m3/s]";
  Real Qsupply "Supply (pump) flow [m3/s]";
  Real Qleak "Internal leakage flow cap->rod [m3/s]";
  Real Qrelief1 "Relief-valve flow cap end [m3/s]";
  Real Qrelief2 "Relief-valve flow rod end [m3/s]";
  Real u_cmd "Unlimited valve command";
  Real u_limited "Limited valve command [-1,1]";
  Real x_ref "Reference position [m]";
  Real v_ref "Reference velocity [m/s]";
  Real a_ref "Reference acceleration [m/s2]";
  Real x_err "Tracking error x_ref - x [m]";
  Real F_ext "External disturbance force [N]";
  Real F_ref "Feedforward reference force [N]";
  Real F_actual "Actual cylinder force [N]";
  Real Q_cmd "Commanded flow [m3/s]";

  // === Verification flags ===
  Boolean track_ok "Tracking error below 0.014 m after 13 s";
  Boolean bounds_ok "All physical bounds satisfied";
  Boolean no_nan "No NaN or infinite values detected";

equation
  // === Smooth two-segment reference trajectory ===
  // Segment 1: t in [0, 8] s, position 0.05 -> 0.40 m (cosine blend)
  // Segment 2: t in [8, 20] s, position 0.40 -> 0.20 m (cosine blend)
  if time < 8.0 then
    x_ref = 0.05 + 0.35 * 0.5 * (1.0 - cos(Modelica.Constants.pi * time / 8.0));
    v_ref = 0.35 * 0.5 * Modelica.Constants.pi / 8.0 * sin(Modelica.Constants.pi * time / 8.0);
    a_ref = 0.35 * 0.5 * Modelica.Constants.pi * Modelica.Constants.pi / 64.0 * cos(Modelica.Constants.pi * time / 8.0);
  else
    x_ref = 0.40 - 0.20 * 0.5 * (1.0 - cos(Modelica.Constants.pi * (time - 8.0) / 12.0));
    v_ref = -0.20 * 0.5 * Modelica.Constants.pi / 12.0 * sin(Modelica.Constants.pi * (time - 8.0) / 12.0);
    a_ref = -0.20 * 0.5 * Modelica.Constants.pi * Modelica.Constants.pi / 144.0 * cos(Modelica.Constants.pi * (time - 8.0) / 12.0);
  end if;

  // === Payload disturbance: 319 N step during middle third of 20 s ===
  F_ext = if noEvent(time >= 6.6667 and time <= 13.3333) then Fdist else 0.0;

  // === Mechanical dynamics ===
  der(x) = v;
  a = (Ap * P1 - Ar * P2 - b_visc * v - F_ext) / m_mass;
  der(v) = a;

  // === Chamber volumes ===
  V1 = Vdead1 + Ap * x;
  V2 = Vdead2 + Ar * (L - x);

  // === Control: feedforward flow + pressure-position feedback ===
  F_ref = m_mass * a_ref + b_visc * v_ref;
  F_actual = Ap * P1 - Ar * P2;
  x_err = x_ref - x;
  Q_cmd = Kff * Ap * v_ref
        + Kp_pos * x_err
        + Kp_vel * (v_ref - v)
        + Kp_pres * (F_ref - F_actual);
  u_cmd = Q_cmd / Qmax;
  u_limited = max(-1.0, min(1.0, u_cmd));

  // === Four-way proportional valve (linear metering) ===
  Q1 = u_limited * Qmax;
  Q2 = u_limited * Qmax;
  Qsupply = abs(u_limited) * Qmax;

  // === Internal leakage (cap to rod) ===
  Qleak = C_leak * (P1 - P2);

  // === Relief valves (pressure limiting to tank) ===
  Qrelief1 = if noEvent(P1 > Prelief) then (P1 - Prelief) / R_relief else 0.0;
  Qrelief2 = if noEvent(P2 > Prelief) then (P2 - Prelief) / R_relief else 0.0;

  // === Chamber pressure dynamics (fluid compressibility) ===
  der(P1) = (beta / V1) * (Q1 - Qleak - Ap * v - Qrelief1);
  der(P2) = (beta / V2) * (Qleak - Q2 + Ar * v - Qrelief2);

  // === Verification criteria ===
  // Tracking: primary error below 0.014 m after 13 s
  track_ok = noEvent(time < 13.0 or abs(x_err) < 0.014);

  // Bounds: travel, pressure, flow, acceleration, relief-valve limits
  bounds_ok = noEvent(
    x >= 0.0 and x <= L
    and P1 >= 0.0 and P1 <= Prelief * 1.2
    and P2 >= 0.0 and P2 <= Prelief * 1.2
    and abs(Qsupply) <= Qmax * 1.05
    and abs(a) <= 100.0
  );

  // No NaN or infinite physical, control, or estimator values
  no_nan = noEvent(x == x and v == v and P1 == P1 and P2 == P2 and u_limited == u_limited);

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "<html>
<p>Double-acting hydraulic cylinder (Ap=0.0040 m2, Ar=0.0032 m2, stroke=0.50 m,
mass=110 kg) with two compressible chambers, four-way proportional valve
(Qmax=0.001 m3/s), viscous friction, internal leakage, and relief valves.</p>
<p>Mission: follow a smooth two-segment position trajectory (0.05->0.40->0.20 m)
over 20 s at 500 Hz, with a 319 N payload step disturbance during the middle third.</p>
<p>Control: feedforward flow with pressure-position feedback.</p>
<p>Verification: tracking error < 0.014 m after 13 s, all travel/pressure/flow/
acceleration/relief bounds satisfied, no NaN or infinite values.</p>
</html>")
  );
end HydCylinderTrackF;