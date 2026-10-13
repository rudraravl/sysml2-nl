model AirStageConserveE
  "Pneumatic robotic actuator with energy-aware motion control and conservation"

  // ===== Physical constants (assumed ambient conditions) =====
  constant Real R_air = 287.0 "J/(kg.K) specific gas constant for air";
  constant Real g = 9.81 "m/s2 gravitational acceleration";
  constant Real T_amb = 293.15 "K ambient temperature (assumed)";
  constant Real k_poly = 1.2 "polytropic exponent (assumed, thermal/compressibility)";
  constant Real P_atm = 101325.0 "Pa atmospheric pressure";
  constant Real pi = 3.14159265358979;

  // ===== Stated parameters =====
  parameter Real m_carriage = 42.0 "kg carriage mass";
  parameter Real L_stroke = 0.70 "m cylinder stroke";
  parameter Real mdot_max = 0.017 "kg/s valve command magnitude bound";
  parameter Real F_dist = 216.0 "N load variation disturbance magnitude";
  parameter Real t_total = 16.0 "s total simulation duration";
  parameter Real dt_sim = 1.0/250.0 "s simulation step (250 Hz)";
  parameter Real e_track_bound = 0.018 "m tracking error bound after 10.4 s";
  parameter Real t_track_check = 10.4 "s tracking error check start time";

  // ===== Initial conditions =====
  parameter Real x_init = 0.35 "m initial position at mid-stroke";
  parameter Real v_init = 0.0 "m/s initial velocity";
  parameter Real P_cap_init = 233121.0 "Pa initial cap-end pressure (gravity balance)";
  parameter Real P_rod_init = 2.0e5 "Pa initial rod-end pressure (return pressure)";

  // ===== Cylinder geometry (assumed, unequal areas by design) =====
  parameter Real A_cap = 3.14e-3 "m2 cap-end (blind-side) piston area";
  parameter Real A_rod = 1.6e-3 "m2 rod-end piston area (smaller, rod reduces area)";
  parameter Real V_dead_cap = 5.0e-5 "m3 cap-end dead volume";
  parameter Real V_dead_rod = 5.0e-5 "m3 rod-end dead volume";

  // ===== Pressures (assumed supply and return) =====
  parameter Real P_supply = 6.0e5 "Pa pneumatic supply pressure (assumed)";
  parameter Real P_return = 2.0e5 "Pa return/exhaust back pressure (assumed, realistic)";

  // ===== Disturbance timing (middle-third of 16 s) =====
  parameter Real t_dist_start = 16.0/3.0 "s disturbance start (middle third)";
  parameter Real t_dist_end = 32.0/3.0 "s disturbance end (middle third)";

  // ===== Trajectory (assumed repeated sinusoidal cycle) =====
  parameter Real x_center = 0.35 "m cycle center at mid-stroke";
  parameter Real x_amp = 0.30 "m cycle amplitude";
  parameter Real T_cycle = 8.0 "s cycle period (2 full cycles in 16 s)";
  parameter Real omega = 2.0*pi/T_cycle "rad/s angular frequency";

  // ===== Controller gains (assumed, tuned for bounded tracking) =====
  parameter Real Kp_pos = 20000.0 "N/m position proportional gain";
  parameter Real Kd_pos = 1500.0 "N.s/m velocity derivative gain";
  parameter Real Kvf = 5.0e-6 "kg/(s.N) valve force-to-flow gain";
  parameter Real Ke_energy = 0.2 "energy-aware degradation coefficient";
  parameter Real degradation_min = 0.7 "minimum controller performance (bounded degradation)";

  // ===== Energy and air-use caps (assumed) =====
  parameter Real E_cap = 20000.0 "J accumulated supply energy cap";
  parameter Real m_air_cap = 0.5 "kg accumulated air mass cap";

  // ===== Dynamic states =====
  Real x(start=x_init, fixed=true) "m carriage position (0=retracted, L_stroke=extended)";
  Real v(start=v_init, fixed=true) "m/s carriage velocity";
  Real P_cap(start=P_cap_init, fixed=true) "Pa cap-end chamber pressure";
  Real P_rod(start=P_rod_init, fixed=true) "Pa rod-end chamber pressure";
  Real E_accum(start=0.0, fixed=true) "J accumulated supply energy";
  Real m_air_total(start=0.0, fixed=true) "kg total air mass consumed from supply";

  // ===== Latched violation accumulators (for fail-closed acceptance) =====
  Real track_violation(start=0.0, fixed=true) "s tracking violation accumulated time";
  Real bounds_violation(start=0.0, fixed=true) "s bounds violation accumulated time";
  Real energy_violation(start=0.0, fixed=true) "s energy cap violation time";
  Real air_violation(start=0.0, fixed=true) "s air cap violation time";
  Real nan_violation(start=0.0, fixed=true) "s NaN/infinity violation time";

  // ===== Derived quantities =====
  Real V_cap "m3 cap-end chamber volume";
  Real V_rod "m3 rod-end chamber volume";
  Real F_actual "N actual pneumatic force on carriage";
  Real F_gravity "N gravitational force";
  Real F_disturbance "N applied disturbance force";
  Real F_net "N net force on carriage";
  Real F_cmd_raw "N raw force command before degradation";
  Real F_cmd "N commanded force after energy-aware degradation";
  Real degradation "controller performance factor [degradation_min, 1.0]";
  Real x_ref "m reference position trajectory";
  Real v_ref "m/s reference velocity trajectory";
  Real e_pos "m position error (reference - actual)";
  Real e_vel "m/s velocity error (reference - actual)";
  Real e_track "m signed tracking error";
  Real e_track_abs "m absolute tracking error";

  // ===== Valve commands (proportional, independent) =====
  Real u_fill_cap "fill valve command cap end [0, mdot_max] kg/s";
  Real u_exh_cap "exhaust valve command cap end [0, mdot_max] kg/s";
  Real u_fill_rod "fill valve command rod end [0, mdot_max] kg/s";
  Real u_exh_rod "exhaust valve command rod end [0, mdot_max] kg/s";

  // ===== Saturated valve mass flows (with pressure-direction limits) =====
  Real mdot_fill_cap "kg/s actual fill flow cap end";
  Real mdot_exh_cap "kg/s actual exhaust flow cap end";
  Real mdot_fill_rod "kg/s actual fill flow rod end";
  Real mdot_exh_rod "kg/s actual exhaust flow rod end";
  Real mdot_supply "kg/s total supply flow from source";

  // ===== Observable outputs =====
  output Real x_out = x "position m";
  output Real v_out = v "velocity m/s";
  output Real e_out = e_track_abs "tracking error m";
  output Real E_out = E_accum "accumulated energy J";
  output Real m_out = m_air_total "accumulated air mass kg";
  output Real P_cap_out = P_cap "cap-end pressure Pa";
  output Real P_rod_out = P_rod "rod-end pressure Pa";
  output Real mdot_supply_out = mdot_supply "supply flow kg/s";

  // ===== Acceptance flags (fail-closed) =====
  Boolean b_cycle_complete "simulation reached total time";
  Boolean b_track_ok "tracking error within bound after 10.4 s";
  Boolean b_energy_ok "accumulated energy within cap";
  Boolean b_air_ok "accumulated air mass within cap";
  Boolean b_bounds_ok "physical bounds satisfied";
  Boolean b_no_nan "no NaN or infinite values detected";
  Boolean accept "fail-closed acceptance flag (true only if all conditions met)";

equation
  // ===== Chamber volumes (function of position) =====
  V_cap = V_dead_cap + A_cap * x;
  V_rod = V_dead_rod + A_rod * (L_stroke - x);

  // ===== Pressure dynamics (polytropic compressibility with mass flow and volume change) =====
  // dP/dt = (k*R*T/V) * mdot_net - (k*P/V) * dV/dt
  der(P_cap) = (k_poly * R_air * T_amb / V_cap) * (mdot_fill_cap - mdot_exh_cap)
    - (k_poly * P_cap / V_cap) * A_cap * v;
  der(P_rod) = (k_poly * R_air * T_amb / V_rod) * (mdot_fill_rod - mdot_exh_rod)
    + (k_poly * P_rod / V_rod) * A_rod * v;

  // ===== Force balance =====
  F_gravity = -m_carriage * g;
  F_actual = P_cap * A_cap - P_rod * A_rod;
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;
  F_net = F_actual + F_gravity + F_disturbance;

  // ===== Newton's second law (vertical carriage) =====
  der(x) = v;
  der(v) = F_net / m_carriage;

  // ===== Reference trajectory (repeated sinusoidal actuation cycle) =====
  x_ref = x_center + x_amp * sin(omega * time);
  v_ref = x_amp * omega * cos(omega * time);

  // ===== Tracking errors =====
  e_pos = x_ref - x;
  e_vel = v_ref - v;
  e_track = x_ref - x;
  e_track_abs = abs(e_track);

  // ===== Energy-aware degradation (bounded performance degradation) =====
  degradation = max(degradation_min, 1.0 - Ke_energy * E_accum / E_cap);

  // ===== PD position controller with gravity feedforward =====
  F_cmd_raw = Kp_pos * e_pos + Kd_pos * e_vel + m_carriage * g;
  F_cmd = F_cmd_raw * degradation;

  // ===== Valve command mapping (force command to four independent valve commands) =====
  // F_cmd > 0: need upward force -> fill cap end, exhaust rod end
  // F_cmd < 0: need downward force -> exhaust cap end, fill rod end
  u_fill_cap = max(0.0, min(mdot_max, Kvf * F_cmd));
  u_exh_cap = max(0.0, min(mdot_max, -Kvf * F_cmd));
  u_fill_rod = max(0.0, min(mdot_max, -Kvf * F_cmd));
  u_exh_rod = max(0.0, min(mdot_max, Kvf * F_cmd));

  // ===== Saturated valve flows with pressure-direction physical limits =====
  // Fill only operates when chamber pressure below supply pressure
  // Exhaust only operates when chamber pressure above return pressure
  mdot_fill_cap = if P_cap < P_supply then max(0.0, min(mdot_max, u_fill_cap)) else 0.0;
  mdot_exh_cap = if P_cap > P_return then max(0.0, min(mdot_max, u_exh_cap)) else 0.0;
  mdot_fill_rod = if P_rod < P_supply then max(0.0, min(mdot_max, u_fill_rod)) else 0.0;
  mdot_exh_rod = if P_rod > P_return then max(0.0, min(mdot_max, u_exh_rod)) else 0.0;

  // ===== Supply flow (total fill flow from supply line) =====
  mdot_supply = mdot_fill_cap + mdot_fill_rod;

  // ===== Accumulated energy (isothermal flow work from supply) =====
  der(E_accum) = mdot_supply * R_air * T_amb;

  // ===== Accumulated air mass consumed from supply =====
  der(m_air_total) = mdot_supply;

  // ===== Acceptance latches (integrate time spent in violation) =====

  // Tracking error latch: accumulates when error exceeds bound after t_track_check
  der(track_violation) = if (time >= t_track_check and e_track_abs >= e_track_bound) then 1.0 else 0.0;
  b_track_ok = track_violation < 0.5;

  // Physical bounds latch: position within stroke, pressures positive and bounded
  der(bounds_violation) = if (x < 0.0 or x > L_stroke or P_cap < P_atm or P_rod < P_atm
    or P_cap > P_supply * 1.5 or P_rod > P_supply * 1.5) then 1.0 else 0.0;
  b_bounds_ok = bounds_violation < 0.5;

  // Energy cap latch
  der(energy_violation) = if (E_accum > E_cap) then 1.0 else 0.0;
  b_energy_ok = energy_violation < 0.5;

  // Air mass cap latch
  der(air_violation) = if (m_air_total > m_air_cap) then 1.0 else 0.0;
  b_air_ok = air_violation < 0.5;

  // NaN/infinity latch: checks for unbounded physical, control, or estimator values
  der(nan_violation) = if (abs(x) > 1e6 or abs(v) > 1e6 or P_cap > 1e8 or P_rod > 1e8
    or E_accum > 1e8 or abs(F_cmd) > 1e6 or abs(e_track_abs) > 1e6) then 1.0 else 0.0;
  b_no_nan = nan_violation < 0.5;

  // Cycle completion
  b_cycle_complete = (time >= t_total - 1e-6);

  // Fail-closed acceptance: all conditions must be satisfied simultaneously
  accept = b_cycle_complete and b_track_ok and b_energy_ok and b_air_ok
    and b_bounds_ok and b_no_nan;

  annotation(
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="AirStageConserveE: Double-acting pneumatic cylinder with energy-aware
      motion control. Stated: 42 kg carriage, 0.70 m stroke, 0.017 kg/s valve bound,
      216 N middle-third disturbance, 250 Hz, 16 s, tracking < 0.018 m after 10.4 s.
      Assumed (labeled in code): cylinder areas, dead volumes, supply/return pressures,
      controller gains, trajectory shape, energy/air caps, polytropic exponent.
      Acceptance is fail-closed: accept=true only if all conditions hold at end of run.")
  );
end AirStageConserveE;