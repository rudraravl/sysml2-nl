model HydCylinderConserveE
  // ===================== Given parameters =====================
  parameter Real A_p = 0.0040 "Piston (cap-side) area [m2]";
  parameter Real A_r = 0.0032 "Rod cross-section area [m2]";
  parameter Real L = 0.50 "Cylinder stroke [m]";
  parameter Real m = 110 "Moving mass [kg]";
  parameter Real u_max = 0.001 "Valve command magnitude bound [m3/s]";
  parameter Real F_dist = 216 "Load disturbance magnitude [N]";

  // ===================== Assumed parameters (labeled; not stated in request) =====================
  parameter Real Ps = 7.0e6 "Supply pressure [Pa] (assumed)";
  parameter Real Pt = 2.0e5 "Realistic return/tank pressure [Pa] (assumed)";
  parameter Real beta = 3.0e8 "Effective bulk modulus incl. entrained-air compressibility [Pa] (assumed)";
  parameter Real V_dead = 1.0e-4 "Dead volume per chamber [m3] (assumed)";
  parameter Real b_visc = 3000 "Viscous damping [N.s/m] (assumed)";
  parameter Real F_coul = 200 "Coulomb friction magnitude [N] (assumed)";
  parameter Real C_leak = 1.0e-15 "Internal leakage conductance [m3/(s.Pa)] (assumed)";
  parameter Real E_cap = 55000 "Declared energy-use cap [J] (assumed)";
  parameter Real Kp = 80.0 "Position proportional gain [1/m] (assumed)";
  parameter Real Kd = 10.0 "Velocity derivative gain [s/m] (assumed)";
  parameter Real T_cycle = 8.0 "Reference cycle period - 2 cycles in 16 s [s] (assumed)";
  final parameter Real pi = 3.141592653589793;
  final parameter Real A_b = A_p - A_r "Rod-side annular area [m2]";

  // ===================== Dynamic states =====================
  Real x(start = 0.0, fixed = true) "Piston position from fully retracted end [m]";
  Real v(start = 0.0, fixed = true) "Piston velocity [m/s]";
  Real p_a(start = 2.0e5, fixed = true) "Cap-side chamber pressure [Pa]";
  Real p_b(start = 1.0e6, fixed = true) "Rod-side chamber pressure [Pa]";
  Real E_acc(start = 0.0, fixed = true) "Accumulated hydraulic supply energy [J]";

  // ===================== Chamber volumes =====================
  Real V_a "Cap-side instantaneous volume [m3]";
  Real V_b "Rod-side instantaneous volume [m3]";

  // ===================== Valve signals =====================
  Real u_cmd "Raw (pre-saturation) valve command";
  Real u_sat "Saturated valve command [-1, +1]";
  Real Q_a "Net flow into cap-side chamber [m3/s]";
  Real Q_b "Net flow into rod-side chamber [m3/s]";
  Real Q_s "Supply (pump) flow drawn through valve [m3/s]";

  // ===================== Reference trajectory =====================
  Real x_ref "Reference position [m]";
  Real v_ref "Reference velocity [m/s]";

  // ===================== Control & energy-awareness =====================
  Real e_pos "Position tracking error [m]";
  Real e_vel "Velocity tracking error [m/s]";
  Real energy_scale "Energy-aware command scaling factor, bounded [0.5, 1.0]";

  // ===================== Disturbance & forces =====================
  Real F_ext "External load disturbance (middle-third) [N]";
  Real F_hydraulic "Net hydraulic actuation force [N]";
  Real track_error "Absolute tracking error magnitude [m]";

  // ===================== Acceptance / verification =====================
  Boolean bounds_ok "Physical bounds respected";
  Boolean cycle_complete "Two full cycles completed";
  Boolean energy_ok "Accumulated energy within declared cap";
  Boolean terminal_error_ok "Terminal tracking error within tolerance";
  Boolean tracking_ok "Primary tracking error below 0.018 m after 10.4 s";
  Boolean no_nan_inf "No NaN or infinite values in physical/control signals";
  Boolean acceptance "Fail-closed acceptance flag";

equation
  // ---- Chamber volumes (compressibility) ----
  V_a = V_dead + A_p * x;
  V_b = V_dead + A_b * (L - x);

  // ---- Reference: 2 full sinusoidal cycles over 16 s ----
  x_ref = L / 2.0 * (1.0 - cos(2.0 * pi * time / T_cycle));
  v_ref = L / 2.0 * (2.0 * pi / T_cycle) * sin(2.0 * pi * time / T_cycle);

  // ---- Middle-third disturbance: 216 N during [16/3, 32/3] s ----
  F_ext = if (time >= 16.0 / 3.0 and time <= 32.0 / 3.0) then F_dist else 0.0;

  // ---- Tracking errors ----
  e_pos = x_ref - x;
  e_vel = v_ref - v;
  track_error = abs(e_pos);

  // ---- Energy-aware scaling: full authority until 70% of cap, then linearly degrade to 0.5 at cap ----
  energy_scale = max(0.5, min(1.0, 1.0 - 0.5 * (E_acc - 0.7 * E_cap) / (0.3 * E_cap)));

  // ---- PD controller with energy-aware bounded degradation ----
  u_cmd = energy_scale * (Kp * e_pos + Kd * e_vel);
  u_sat = max(-1.0, min(1.0, u_cmd));

  // ---- Four-way proportional valve: metering flows ----
  // u_sat > 0: extend (supply->cap, rod->tank)
  // u_sat < 0: retract (supply->rod, cap->tank)
  Q_a = u_sat * u_max;
  Q_b = -u_sat * u_max;
  Q_s = abs(u_sat) * u_max;

  // ---- Chamber pressure dynamics with compressibility and leakage ----
  der(p_a) = (beta / V_a) * (Q_a - A_p * v - C_leak * (p_a - Pt));
  der(p_b) = (beta / V_b) * (Q_b + A_b * v - C_leak * (p_b - Pt));

  // ---- Mechanical force balance ----
  F_hydraulic = p_a * A_p - p_b * A_b;
  m * der(v) = F_hydraulic - b_visc * v - F_coul * tanh(v / 0.01) - F_ext;
  der(x) = v;

  // ---- Accumulated supply energy ----
  der(E_acc) = Ps * Q_s;

  // ---- Acceptance criteria (fail-closed) ----
  bounds_ok = x >= -0.001 and x <= L + 0.001 and p_a >= 0.0 and p_a <= 2.0 * Ps and p_b >= 0.0 and p_b <= 2.0 * Ps;
  cycle_complete = if time >= 15.9 then abs(x - x_ref) < 0.05 else true;
  energy_ok = E_acc <= E_cap;
  terminal_error_ok = if time >= 15.5 then track_error < 0.05 else true;
  tracking_ok = if time >= 10.4 then track_error < 0.018 else true;
  no_nan_inf = x >= -1.0 and x <= 1.0 and v >= -100.0 and v <= 100.0 and p_a >= 0.0 and p_a <= 1.0e9 and p_b >= 0.0 and p_b <= 1.0e9 and E_acc >= 0.0 and E_acc <= 1.0e12 and abs(u_cmd) <= 100.0 and abs(u_sat) <= 1.0;
  acceptance = bounds_ok and cycle_complete and energy_ok and terminal_error_ok and tracking_ok and no_nan_inf;

  annotation(
    experiment(StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Double-acting hydraulic cylinder (A_p=0.0040 m2, A_r=0.0032 m2, L=0.50 m, m=110 kg) with two compressible chambers, four-way proportional valve (|u_max|=0.001 m3/s), energy-aware PD motion control with bounded 50% performance degradation, 216 N middle-third disturbance, 2 full cycles over 16 s at 250 Hz output rate. All non-specified parameters are labeled as assumed."));
end HydCylinderConserveE;