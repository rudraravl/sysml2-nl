model HydBoomConserveD
  "Instrumented fluid-power robotic actuator: 2-cylinder boom+stick with
   energy-aware motion control, load-sensing pump, relief, compressibility,
   return pressure, valve saturation, 180 N mid-cycle disturbance.
   NOTE: numeric values not specified by the requirement (cylinder areas,
   moment arms, dead volumes, pressures, control gains, energy cap value,
   cycle shape/period, disturbance application point) are engineering
   assumptions and are flagged in comments; only boom/stick length, payload,
   and pump flow limit come from the requirement."

  import Modelica.Constants.pi;

  // --- Run / sampling ---
  parameter Real Ts      = 0.005 "Sample period (200 Hz) [s]";
  parameter Real Tfinal  = 14.0  "Run duration [s]";

  // --- Geometry & payload (from requirement) ---
  parameter Real Lboom   = 2.0   "Boom length [m] (from requirement)";
  parameter Real Lstick  = 1.4   "Stick length [m] (from requirement)";
  parameter Real mpay    = 300.0 "Payload mass [kg] (from requirement)";
  parameter Real g       = 9.81  "Gravity [m/s2]";

  // --- Cylinders (assumed geometry, not specified by requirement) ---
  parameter Real Aa_b    = 1.5e-3 "Boom cap-side area [m2] (assumed)";
  parameter Real Ar_b    = 1.0e-3 "Boom rod-side area [m2] (assumed)";
  parameter Real Aa_s    = 1.0e-3 "Stick cap-side area [m2] (assumed)";
  parameter Real Ar_s    = 7.0e-4 "Stick rod-side area [m2] (assumed)";
  parameter Real Vdead   = 1.0e-4 "Cylinder dead volume per chamber [m3] (assumed)";
  parameter Real Lstr_b  = 0.6    "Boom cylinder stroke [m] (assumed)";
  parameter Real Lstr_s  = 0.5    "Stick cylinder stroke [m] (assumed)";
  parameter Real rb      = 0.45   "Boom cylinder moment arm [m] (assumed)";
  parameter Real rs      = 0.35   "Stick cylinder moment arm [m] (assumed)";
  parameter Real xb0     = 0.30   "Boom cylinder nominal position [m] (assumed)";
  parameter Real xs0     = 0.25   "Stick cylinder nominal position [m] (assumed)";

  // --- Hydraulics ---
  parameter Real beta    = 1.2e9  "Effective bulk modulus (compr./thermal effect) [Pa] (assumed)";
  parameter Real pT      = 0.5e6  "Return pressure [Pa] (assumed, realistic)";
  parameter Real pmax    = 20.0e6 "Relief pressure [Pa] (assumed)";
  parameter Real Qpmax   = 0.004  "Pump flow limit [m3/s] (from requirement)";
  parameter Real Kv      = 6.0e-8 "Valve orifice conductance [m3/s/sqrt(Pa)] (assumed)";
  parameter Real Krel    = 5.0e-10 "Relief conductance [m3/s/Pa] (assumed)";
  parameter Real Vs      = 2.0e-3  "Supply manifold volume [m3] (assumed)";
  parameter Real Kleak   = 1.0e-14 "Leakage conductance [m3/s/Pa] (assumed)";

  // --- Energy ---
  parameter Real Ecap    = 350.0e3 "Declared energy-use cap [J] (assumed; requirement did not state value)";

  // --- Control ---
  parameter Real Kp1     = 60.0  "Boom proportional gain (assumed)";
  parameter Real Kd1     = 12.0  "Boom derivative gain (assumed)";
  parameter Real Ki1     = 2.0   "Boom integral gain (assumed)";
  parameter Real Kp2     = 40.0  "Stick proportional gain (assumed)";
  parameter Real Kd2     = 8.0   "Stick derivative gain (assumed)";
  parameter Real Ki2     = 1.5   "Stick integral gain (assumed)";
  parameter Real kEmin   = 0.3   "Minimum energy scaling (bounded degradation)";

  // --- Disturbance ---
  parameter Real Fdist   = 180.0 "Load variation disturbance [N] (from requirement)";

  // --- Cycle ---
  parameter Real Tcycle  = 7.0   "Actuation cycle period [s] (assumed; two cycles in 14 s)";

  // --- Continuous states ---
  Real theta1, omega1;
  Real theta2, omega2;
  Real pA_b, pB_b, pA_s, pB_s;
  Real pS;
  Real Eused;
  Real xint1, xint2;

  // --- Computed / algebraic ---
  Real xb, xs;
  Real Va_b, Vb_b, Va_s, Vb_s;
  Real I1, I2;
  Real Fb, Fs, tau1, tau2;
  Real tau_g1, tau_g2, tau_d1;
  Real u1, u2;
  Real u1p, u1n, u2p, u2n;
  Real QvA_b, QvB_b, QvA_s, QvB_s;
  Real Qdem, Qpump, Qrelief, Qleak_p;
  Real QsA_b, QsB_b, QsA_s, QsB_s;
  Real theta1_ref, theta2_ref;
  Real dtheta1_ref, dtheta2_ref;
  Real e1, e2;
  Real kE;
  Real tip_x, tip_y, tip_xr, tip_yr, tip_err;
  Real Fdist_window;
  Real u1raw, u2raw;

  // --- Synchronized discrete sensor/command/state traces (200 Hz) ---
  discrete Real theta1_s, theta2_s, omega1_s, omega2_s;
  discrete Real pA_b_s, pB_b_s, pA_s_s, pB_s_s, pS_s;
  discrete Real Qpump_s, Eused_s, Fdist_s;
  discrete Real theta1_ref_s, theta2_ref_s, u1_s, u2_s;
  discrete Real e1_s, e2_s, tip_err_s;

  // --- Status flags ---
  Boolean cycle_done;
  Boolean energy_ok;
  Boolean tracking_ok;

initial equation
  theta1 = 0.7;
  omega1 = 0.0;
  theta2 = 0.0;
  omega2 = 0.0;
  pA_b   = 6.0e6;
  pB_b   = 1.0e6;
  pA_s   = 4.0e6;
  pB_s   = 1.0e6;
  pS     = 6.0e6;
  Eused  = 0.0;
  xint1  = 0.0;
  xint2  = 0.0;

equation
  // Reference cycle (repeated, smooth)
  theta1_ref   = 0.7  + 0.25*sin(2*pi*time/Tcycle);
  theta2_ref   = 0.0  + 0.20*sin(2*pi*time/Tcycle + pi/2);
  dtheta1_ref  = 0.25*(2*pi/Tcycle)*cos(2*pi*time/Tcycle);
  dtheta2_ref  = 0.20*(2*pi/Tcycle)*cos(2*pi*time/Tcycle + pi/2);

  // Cylinder positions and chamber volumes
  xb   = xb0 + rb*theta1;
  xs   = xs0 + rs*theta2;
  Va_b = Vdead + Aa_b*xb;
  Vb_b = Vdead + Ar_b*(Lstr_b - xb);
  Va_s = Vdead + Aa_s*xs;
  Vb_s = Vdead + Ar_s*(Lstr_s - xs);

  // Inertias (payload-dominated, geometry-grounded)
  I1 = mpay*(Lboom*Lboom + 2.0*Lboom*Lstick*cos(theta2) + Lstick*Lstick);
  I2 = mpay*Lstick*Lstick;

  // Energy-aware scaling (bounded degradation, never below kEmin)
  kE = max(kEmin, 1.0 - Eused/Ecap);

  // Tracking errors
  e1 = theta1_ref - theta1;
  e2 = theta2_ref - theta2;

  // Integral with conditional anti-windup (freeze when saturated)
  der(xint1) = if (u1raw > 0.99 and e1 > 0) or (u1raw < -0.99 and e1 < 0) then 0.0 else e1;
  der(xint2) = if (u2raw > 0.99 and e2 > 0) or (u2raw < -0.99 and e2 < 0) then 0.0 else e2;

  // Control law with feedforward velocity and energy scaling
  u1raw = Kp1*e1 + Kd1*(dtheta1_ref - omega1) + Ki1*xint1;
  u2raw = Kp2*e2 + Kd2*(dtheta2_ref - omega2) + Ki2*xint2;
  u1 = kE*tanh(u1raw);  // smooth saturation to [-1,1]
  u2 = kE*tanh(u2raw);

  // Valve command split
  u1p = max(0.0, u1);
  u1n = max(0.0, -u1);
  u2p = max(0.0, u2);
  u2n = max(0.0, -u2);

  // Orifice flows from supply (meter-in) and to tank (meter-out)
  QsA_b = Kv*u1p*sqrt(max(1.0e3, pS - pA_b));
  QsB_b = Kv*u1n*sqrt(max(1.0e3, pS - pB_b));
  QsA_s = Kv*u2p*sqrt(max(1.0e3, pS - pA_s));
  QsB_s = Kv*u2n*sqrt(max(1.0e3, pS - pB_s));

  QvA_b = QsA_b - Kv*u1n*sqrt(max(1.0e3, pA_b - pT));
  QvB_b = QsB_b - Kv*u1p*sqrt(max(1.0e3, pB_b - pT));
  QvA_s = QsA_s - Kv*u2n*sqrt(max(1.0e3, pA_s - pT));
  QvB_s = QsB_s - Kv*u2p*sqrt(max(1.0e3, pB_s - pT));

  // Pump: load-sensing demand capped at Qpmax (requirement bound)
  Qdem   = QsA_b + QsB_b + QsA_s + QsB_s;
  Qpump  = min(Qpmax, max(0.0, Qdem));

  // Relief valve (over-center protection)
  Qrelief = if pS > pmax then Krel*(pS - pmax) else 0.0;

  // Leakage
  Qleak_p = Kleak*(pS - pT);

  // Supply manifold pressure dynamics (compressibility)
  der(pS) = (beta/Vs)*(Qpump - Qrelief - Qleak_p - QsA_b - QsB_b - QsA_s - QsB_s);

  // Chamber pressure dynamics (compressibility + thermal effective bulk modulus)
  der(pA_b) = (beta/Va_b)*(QvA_b - Aa_b*rb*omega1);
  der(pB_b) = (beta/Vb_b)*(Ar_b*rb*omega1 - QvB_b);
  der(pA_s) = (beta/Va_s)*(QvA_s - Aa_s*rs*omega2);
  der(pB_s) = (beta/Vb_s)*(Ar_s*rs*omega2 - QvB_s);

  // Cylinder forces and joint torques
  Fb   = pA_b*Aa_b - pB_b*Ar_b;
  Fs   = pA_s*Aa_s - pB_s*Ar_s;
  tau1 = Fb*rb;
  tau2 = Fs*rs;

  // Gravity torques (vertical-plane boom/stick)
  tau_g1 = mpay*g*(Lboom*cos(theta1) + Lstick*cos(theta1 + theta2));
  tau_g2 = mpay*g*Lstick*cos(theta1 + theta2);

  // 180 N disturbance applied during middle third of run
  Fdist_window = if (time > Tfinal/3.0 and time < 2.0*Tfinal/3.0) then Fdist else 0.0;
  tau_d1 = Fdist_window*Lboom*cos(theta1);

  // Rigid-body joint dynamics
  der(theta1) = omega1;
  der(omega1) = (tau1 - tau_g1 + tau_d1)/I1;
  der(theta2) = omega2;
  der(omega2) = (tau2 - tau_g2)/I2;

  // Accumulated hydraulic energy
  der(Eused) = pS*Qpump;

  // Cartesian tip tracking error (primary metric)
  tip_x   = Lboom*cos(theta1) + Lstick*cos(theta1 + theta2);
  tip_y   = Lboom*sin(theta1) + Lstick*sin(theta1 + theta2);
  tip_xr  = Lboom*cos(theta1_ref) + Lstick*cos(theta1_ref + theta2_ref);
  tip_yr  = Lboom*sin(theta1_ref) + Lstick*sin(theta1_ref + theta2_ref);
  tip_err = sqrt(max(1.0e-12, (tip_x - tip_xr)*(tip_x - tip_xr) + (tip_y - tip_yr)*(tip_y - tip_yr)));

  // Synchronized 200 Hz trace capture
  when sample(0, Ts) then
    theta1_s     = theta1;
    theta2_s     = theta2;
    omega1_s     = omega1;
    omega2_s     = omega2;
    pA_b_s       = pA_b;
    pB_b_s       = pB_b;
    pA_s_s       = pA_s;
    pB_s_s       = pB_s;
    pS_s         = pS;
    Qpump_s      = Qpump;
    Eused_s      = Eused;
    Fdist_s      = Fdist_window;
    theta1_ref_s = theta1_ref;
    theta2_ref_s = theta2_ref;
    u1_s         = u1;
    u2_s         = u2;
    e1_s         = e1;
    e2_s         = e2;
    tip_err_s    = tip_err;
  end when;

  // Compliance/status flags
  cycle_done  = time >= Tfinal;
  energy_ok   = Eused <= Ecap;
  tracking_ok = (time < 9.1) or (tip_err < 0.02);

end HydBoomConserveD;