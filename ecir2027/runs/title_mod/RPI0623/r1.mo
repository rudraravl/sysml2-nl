model HydCylinderConserveE
  "Verifiable fluid-power robotic actuator with energy-aware motion control";

  // ===== Parameters from requirement =====
  parameter Modelica.Units.SI.Area A_p = 0.0040 "Piston (cap-side) area";
  parameter Modelica.Units.SI.Area A_r = 0.0032 "Rod-side annular area";
  parameter Modelica.Units.SI.Length stroke = 0.50 "Cylinder stroke";
  parameter Modelica.Units.SI.Mass m = 110.0 "Moving mass";
  parameter Modelica.Units.SI.VolumeFlowRate u_max = 0.001 "Valve command magnitude bound";
  parameter Modelica.Units.SI.Force F_dist = 216.0 "Disturbance load in middle third";
  parameter Modelica.Units.SI.Time t_end = 16.0 "Total run duration";
  parameter Modelica.Units.SI.Time dt_sample = 0.004 "Sample period (250 Hz)";

  // ===== Assumed engineering parameters (not stated in requirement) =====
  parameter Modelica.Units.SI.Length L_dead = 0.08 "Dead length per chamber (assumed)";
  parameter Modelica.Units.SI.BulkModulus beta = 1.5e8 "Effective bulk modulus incl. entrained air (assumed)";
  parameter Modelica.Units.SI.Pressure p_s = 7.0e6 "Supply pressure (assumed)";
  parameter Modelica.Units.SI.Pressure p_t = 5.0e5 "Return/tank pressure (assumed realistic)";
  parameter Modelica.Units.SI.Density rho_oil = 850 "Oil density (assumed)";
  parameter Real C_leak_int(unit="m3/(s.Pa)") = 5.0e-12 "Internal leakage coeff. (assumed)";
  parameter Real C_leak_ext(unit="m3/(s.Pa)") = 1.0e-12 "External leakage coeff. (assumed)";
  parameter Modelica.Units.SI.TranslationalDampingConstant b_vis = 5000.0 "Viscous damping (assumed)";
  parameter Real F_coulomb_val(unit="N") = 50.0 "Coulomb friction level (assumed)";
  parameter Modelica.Units.SI.Stiffness k_stop = 1.0e7 "End-stop stiffness (assumed)";
  parameter Modelica.Units.SI.DampingConstant b_stop = 1.0e4 "End-stop damping (assumed)";

  // ===== Controller parameters (design choice) =====
  parameter Real K_p = 0.05 "Position gain";
  parameter Real K_d = 0.1 "Velocity gain";
  parameter Real ff_gain = 0.0036 "Feedforward gain (avg of A_p, A_r)";
  parameter Modelica.Units.SI.Energy E_cap = 120000.0 "Declared energy cap";
  parameter Real scale_min = 0.3 "Min controller scale (bounded degradation)";
  parameter Modelica.Units.SI.Time T_cycle = 8.0 "Cycle period (2 cycles in 16 s)";
  parameter Modelica.Units.SI.Length x_amp = 0.20 "Reference amplitude (80% stroke)";

  // Derived disturbance timing: middle third of 16 s run
  final parameter Modelica.Units.SI.Time t_dist_start = t_end / 3.0 "Disturbance start";
  final parameter Modelica.Units.SI.Time t_dist_end = 2.0 * t_end / 3.0 "Disturbance end";

  // ===== Continuous state variables =====
  Modelica.Units.SI.Length x "Piston position (0 = retracted)";
  Modelica.Units.SI.Velocity v "Piston velocity";
  Modelica.Units.SI.Pressure p_A "Chamber A (cap-side) pressure";
  Modelica.Units.SI.Pressure p_B "Chamber B (rod-side) pressure";
  Modelica.Units.SI.Energy E_acc "Accumulated supply energy";

  // ===== Algebraic variables (sensors and intermediate quantities) =====
  Modelica.Units.SI.Acceleration a "Piston acceleration";
  Modelica.Units.SI.Volume V_A "Chamber A volume";
  Modelica.Units.SI.Volume V_B "Chamber B volume";
  Modelica.Units.SI.VolumeFlowRate u_cmd "Unsaturated valve command";
  Modelica.Units.SI.VolumeFlowRate u_sat "Saturated valve command";
  Modelica.Units.SI.VolumeFlowRate Q_A "Net flow into chamber A";
  Modelica.Units.SI.VolumeFlowRate Q_B "Net flow into chamber B";
  Modelica.Units.SI.VolumeFlowRate Q_supply "Supply flow (sensor)";
  Modelica.Units.SI.VolumeFlowRate Q_leak_AB "Internal leakage A to B";
  Modelica.Units.SI.VolumeFlowRate Q_leak_A_t "External leakage A to tank";
  Modelica.Units.SI.VolumeFlowRate Q_leak_B_t "External leakage B to tank";
  Modelica.Units.SI.Force F_cyl "Cylinder force";
  Modelica.Units.SI.Force F_friction "Total friction force";
  Modelica.Units.SI.Force F_stop "End-stop contact force";
  Modelica.Units.SI.Force F_load "Disturbance load";
  Modelica.Units.SI.Power P_supply "Instantaneous supply power (sensor)";
  Real ctrl_scale "Energy-aware controller scale factor";
  Modelica.Units.SI.Length x_ref "Reference position";
  Modelica.Units.SI.Velocity v_ref "Reference velocity";
  Modelica.Units.SI.Length track_error "Position tracking error";

  // ===== Discrete variables =====
  discrete Real track_err_max_post(start=0.0, fixed=true)
    "Max absolute tracking error after t=10.4 s (sampled at 250 Hz)";

  // ===== Acceptance flags (fail-closed) =====
  Boolean cycle_complete "At least 2 full cycles completed";
  Boolean terminal_ok "Terminal tracking error acceptable";
  Boolean tracking_ok "Tracking error below 0.018 m after 10.4 s";
  Boolean energy_ok "Energy within declared cap";
  Boolean no_nan_ok "No NaN or infinite physical/control values";
  Boolean all_accept "All acceptance criteria met (fail-closed)";

  // Local constant
  constant Real pi_val = 3.14159265358979;

initial equation
  x = 0.005;
  v = 0;
  p_A = p_t;
  p_B = p_t;
  E_acc = 0;

equation
  // --- Reference trajectory: 2 full sinusoidal cycles (0 -> 0.4 -> 0) ---
  x_ref = x_amp * (1.0 - cos(2.0 * pi_val * time / T_cycle));
  v_ref = x_amp * (2.0 * pi_val / T_cycle) * sin(2.0 * pi_val * time / T_cycle);

  // --- Compressible chamber volumes ---
  V_A = A_p * (L_dead + x);
  V_B = A_r * (L_dead + stroke - x);

  // --- Valve saturation (command magnitude bounded) ---
  u_sat = max(-u_max, min(u_max, u_cmd));

  // --- Four-way proportional valve metering ---
  // u_sat > 0: P->A and B->T (extend); u_sat < 0: P->B and A->T (retract)
  Q_A = u_sat;
  Q_B = -u_sat;
  Q_supply = abs(u_sat);

  // --- Leakage paths (internal and external) ---
  Q_leak_AB = C_leak_int * (p_A - p_B);
  Q_leak_A_t = C_leak_ext * (p_A - p_t);
  Q_leak_B_t = C_leak_ext * (p_B - p_t);

  // --- Pressure dynamics with fluid compressibility ---
  // dp/dt = (beta/V) * (Q_in - Q_leak - dV/dt)
  der(p_A) = (beta / V_A) * (Q_A - Q_leak_AB - Q_leak_A_t - A_p * v);
  der(p_B) = (beta / V_B) * (Q_B + Q_leak_AB - Q_leak_B_t + A_r * v);

  // --- Forces ---
  F_cyl = p_A * A_p - p_B * A_r;
  F_friction = b_vis * v + F_coulomb_val * tanh(100.0 * v);

  // End-stop: spring-damper engages beyond physical bounds
  F_stop = if x < 0.0 then -k_stop * x - b_stop * v
           elseif x > stroke then -k_stop * (x - stroke) - b_stop * v
           else 0.0;

  // Disturbance load during middle third of run (opposing extension)
  F_load = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // --- Newton's second law ---
  a = (F_cyl + F_stop - F_friction - F_load) / m;
  der(x) = v;
  der(v) = a;

  // --- Supply energy accumulation (sensor trace) ---
  P_supply = p_s * Q_supply;
  der(E_acc) = P_supply;

  // --- Energy-aware motion controller with bounded degradation ---
  // Scale factor decreases quadratically with energy usage, floored at scale_min
  ctrl_scale = max(scale_min, 1.0 - (E_acc / E_cap) * (E_acc / E_cap));
  u_cmd = ctrl_scale * (K_p * (x_ref - x) + K_d * (v_ref - v) + ff_gain * v_ref);

  // --- Tracking error ---
  track_error = x_ref - x;

  // --- Synchronized discrete sampling at 250 Hz ---
  // Tracks maximum absolute tracking error after t = 10.4 s
  when sample(0, dt_sample) then
    track_err_max_post = if time >= 10.4 then
        max(pre(track_err_max_post), abs(track_error))
      else
        pre(track_err_max_post);
  end when;

  // --- Acceptance checks (fail-closed: all must be true) ---
  cycle_complete = time >= 2.0 * T_cycle - 0.1;
  terminal_ok = abs(track_error) < 0.018;
  tracking_ok = track_err_max_post < 0.018;
  energy_ok = E_acc <= E_cap;
  no_nan_ok = (x > -1.0e6) and (x < 1.0e6) and
              (v > -1.0e6) and (v < 1.0e6) and
              (p_A > -1.0e8) and (p_A < 1.0e8) and
              (p_B > -1.0e8) and (p_B < 1.0e8) and
              (E_acc > -1.0e6) and (E_acc < 1.0e8) and
              (u_cmd > -1.0e6) and (u_cmd < 1.0e6);
  all_accept = cycle_complete and terminal_ok and tracking_ok and energy_ok and no_nan_ok;

end HydCylinderConserveE;