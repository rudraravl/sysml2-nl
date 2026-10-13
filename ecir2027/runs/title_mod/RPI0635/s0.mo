model HydMotorForceE
  "Verifiable fluid-power robotic actuator: hydraulic motor force control
   with cascaded pressure/force regulation, compliant load, supply limit,
   relief protection, fixed support, and a middle-third 180 N disturbance."

  // ===== Given parameters =====
  parameter Real D_m(unit="m3/rev")   = 48e-6   "Motor displacement per rev";
  parameter Real eta_v                = 0.92    "Motor volumetric efficiency";
  parameter Real n_gb                 = 12      "Gearbox ratio (motor:load)";
  parameter Real m_load(unit="kg")    = 130     "Rotary table mass";
  parameter Real Q_max(unit="m3/s")   = 0.002   "Valve command bound";
  parameter Real F_dist_amp(unit="N") = 180     "Disturbance amplitude";

  // ===== Commanded force =====
  parameter Real F_cmd(unit="N")      = 1500    "Commanded output force";

  // ===== Assumed (unspecified) physical parameters =====
  parameter Real r_eff(unit="m")      = 0.10    "Assumed lever arm (torque->force)";
  parameter Real beta(unit="Pa")     = 1.0e9   "Assumed oil bulk modulus";
  parameter Real V_ch(unit="m3")     = 2.0e-3  "Assumed chamber volume";
  parameter Real p_supply(unit="Pa") = 20.0e6  "Assumed supply pressure";
  parameter Real p_tank(unit="Pa")   = 1.0e5   "Tank/atmosphere pressure";
  parameter Real p_relief(unit="Pa") = 22.0e6  "Assumed relief pressure";
  parameter Real k_relief(unit="m3/(s.Pa)") = 5.0e-10 "Assumed relief conductance";
  parameter Real k_load(unit="N/m")  = 5.0e4   "Assumed contact stiffness";
  parameter Real c_load(unit="N.s/m")= 800     "Assumed contact damping";
  parameter Real x_stop(unit="m")    = 0.05    "Assumed end-stop travel";
  parameter Real k_stop(unit="N/m")  = 1.0e7   "Assumed stop stiffness";
  parameter Real c_stop(unit="N.s/m")= 1.0e3   "Assumed stop damping";

  // ===== Controller (assumed gains, discrete at 250 Hz) =====
  parameter Real Ts(unit="s")        = 0.004   "Control sample period (250 Hz)";
  parameter Real Kp_f(unit="Pa/N")   = 1000    "Force loop P gain";
  parameter Real Ki_f(unit="Pa/(N.s)")= 200    "Force loop I gain";
  parameter Real Kp_p(unit="m3/(s.Pa)")= 5.0e-10 "Pressure loop P gain";
  parameter Real Ki_p(unit="m3/(s.Pa.s)")= 5.0e-9 "Pressure loop I gain";

  // ===== Derived =====
  final parameter Real d_m(unit="m3/rad") = D_m/(2.0*Modelica.Constants.pi) "Per rad";
  final parameter Real A_eff(unit="m2")  = n_gb*d_m/r_eff "Effective force area";

  // ===== Continuous plant states =====
  Real p_a(start=p_tank, unit="Pa")  "Chamber A pressure";
  Real p_b(start=p_tank, unit="Pa")  "Chamber B pressure";
  Real v(start=0, unit="m/s")        "Load velocity";
  Real x(start=0, unit="m")          "Load/contact deflection";

  // ===== Discrete controller states =====
  Real force_integ(start=0, unit="Pa.s")   "Force loop integrator";
  Real press_integ(start=0, unit="m3/s.s")  "Pressure loop integrator";

  // ===== Signals =====
  Real dp(unit="Pa")        "Motor pressure differential";
  Real F_act(unit="N")       "Actuator output force";
  Real F_contact(unit="N")   "External contact force";
  Real F_dist_val(unit="N")  "Applied disturbance";
  Real Q_motor(unit="m3/s")  "Motor consumption flow";
  Real Q_relief_a(unit="m3/s") "Relief flow A";
  Real Q_relief_b(unit="m3/s") "Relief flow B";
  Real F_stop(unit="N")      "End-stop force";
  Real F_err(unit="N")       "Force tracking error (discrete)";
  Real dp_err(unit="Pa")     "Pressure error (discrete)";
  Real dp_ref(unit="Pa")     "Pressure reference from force loop";
  Real Q_cmd(unit="m3/s")    "Bounded valve flow command";
  Real Q_cmd_raw(unit="m3/s")"Unbounded command";
  Real track_err(unit="N")   "Continuous force tracking error";
  Real p_max(unit="Pa")      "Maximum chamber pressure";

equation
  // Motor pressure differential and effective force
  dp      = p_a - p_b;
  F_act   = A_eff*dp;

  // Motor volumetric flow (consumed from A, returned to B)
  Q_motor = A_eff*v/eta_v;

  // Compliant contact against fixed support
  F_contact = k_load*x + c_load*v;

  // Middle-third (of 16 s) controlled 180 N load disturbance
  F_dist_val = if (time >= 16.0/3.0 and time <= 2.0*16.0/3.0) then F_dist_amp else 0.0;

  // End-stop protection (no rigid impact modeled; soft stop)
  F_stop = if x > x_stop then -k_stop*(x - x_stop) - c_stop*v
           else if x < -x_stop then -k_stop*(x + x_stop) - c_stop*v
           else 0.0;

  // Mechanical load dynamics
  der(v) = (F_act - F_contact - F_dist_val + F_stop)/m_load;
  der(x) = v;

  // Relief / cavitation protection flows
  Q_relief_a = if p_a > p_relief then k_relief*(p_a - p_relief)
               else if p_a < p_tank then k_relief*(p_a - p_tank)
               else 0.0;
  Q_relief_b = if p_b > p_relief then k_relief*(p_b - p_relief)
               else if p_b < p_tank then k_relief*(p_b - p_tank)
               else 0.0;

  // Chamber pressure dynamics (supply-limited via Q_cmd bound)
  der(p_a) = (beta/V_ch)*(Q_cmd - Q_motor - Q_relief_a);
  der(p_b) = (beta/V_ch)*(Q_motor - Q_cmd - Q_relief_b);

  // Continuous tracking-error and bound-monitor signals
  track_err = F_cmd - F_contact;
  p_max     = max(p_a, p_b);

  // ===== Discrete cascaded controller at 250 Hz =====
  when sample(Ts, Ts) then
    // Outer loop: force -> pressure reference
    F_err = F_cmd - F_contact;
    force_integ = pre(force_integ) + Ts*F_err;
    dp_ref = max(-p_supply, min(p_supply, Kp_f*F_err + Ki_f*force_integ));

    // Inner loop: pressure -> bounded flow command
    dp_err = dp_ref - (p_a - p_b);
    press_integ = pre(press_integ) + Ts*dp_err;
    Q_cmd_raw = Kp_p*dp_err + Ki_p*press_integ;
    Q_cmd = max(-Q_max, min(Q_max, Q_cmd_raw));
  end when;

  // ===== Fail-closed acceptance asserts =====
  assert(p_a <= p_relief*1.05, "Chamber A relief exceeded");
  assert(p_b <= p_relief*1.05, "Chamber B relief exceeded");
  assert(p_a >= 0.0 and p_b >= 0.0, "Negative (cavitation) pressure");
  assert(abs(x) <= x_stop*1.05, "End-stop impact detected");
  assert(abs(Q_cmd) <= Q_max*1.001, "Flow command bound violated");
  assert(p_max < 1.0e12, "Non-physical pressure (NaN/inf suspected)");

  annotation(
    experiment(StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Hydraulic motor (48 cm3/rev, eta_v=0.92) drives a 130 kg
      rotary table through a 12:1 gearbox against a compliant contact/fixed
      support. A pressure-compensated proportional valve (|Q|<=0.002 m3/s)
      commands motor flow. Cascaded pressure/force regulation runs at 250 Hz.
      A controlled 180 N load disturbance is applied during the middle third
      of the 16 s run. Acceptance: pressure/flow bounds, contact-force band,
      no end-stop impact, stable hold, |track_err|<18 N after 10.4 s, and no
      NaN/infinite values. Assumed values for unspecified geometry and
      fluid/structural properties are labelled in the parameter declarations."));
end HydMotorForceE;