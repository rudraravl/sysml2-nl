model ElectroSoftShapeB
  "Dielectric-elastomer membrane soft robot: target shape tracking with tip load disturbance"

  // ==================== Membrane geometry (given) ====================
  parameter Real L0 = 0.20 "Undeformed length [m]";
  parameter Real W = 0.05 "Width [m]";
  parameter Real h_mem = 0.8e-3 "Thickness [m]";

  // ==================== Material properties ====================
  // Values assumed for VHB-type dielectric elastomer; not specified in requirement
  parameter Real eps_0 = 8.8541878128e-12 "Vacuum permittivity [F/m]";
  parameter Real eps_r = 4.7 "Relative permittivity [-]";
  parameter Real E_mod = 500.0e3 "Young's modulus [Pa]";
  parameter Real eta_v = 50.0e3 "Viscoelastic viscosity [Pa.s]";
  parameter Real rho_m = 1000.0 "Membrane density [kg/m3]";

  // ==================== Leakage ====================
  parameter Real sigma_leak = 1.0e-12 "Leakage conductivity [S/m]";

  // ==================== Thermal ====================
  parameter Real c_th = 0.05 "Thermal capacitance [J/K]";
  parameter Real k_th = 0.002 "Thermal conductance to ambient [W/K]";
  parameter Real T_amb = 293.15 "Ambient temperature [K]";

  // ==================== Gravity ====================
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ==================== Actuator ====================
  parameter Real V_max = 4100.0 "Max allowed voltage command [V]";
  parameter Real slew = 4000.0 "Voltage slew rate limit [V/s]";

  // ==================== Target shape ====================
  parameter Real x_target = 0.001 "Target tip displacement from undeformed [m]";

  // ==================== Disturbance (middle third of 10 s) ====================
  parameter Real F_dist = 4.2 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 10.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * 10.0 / 3.0 "Disturbance end time [s]";

  // ==================== Controller ====================
  parameter Real Kp_ctrl = 100000.0 "Proportional gain [V/m]";
  parameter Real Kd_ctrl = 1000.0 "Derivative gain [V/(m/s)]";
  parameter Real tau_est = 0.01 "Estimator time constant [s]";

  // ==================== Bounds ====================
  parameter Real strain_max = 0.5 "Max allowable strain [-]";
  parameter Real dT_max = 100.0 "Max allowable temperature rise [K]";
  parameter Real e_bound = 0.054 "Primary tracking error bound [m]";

  // ==================== Derived parameters ====================
  parameter Real A_cross = W * h_mem "Cross-sectional area [m2]";
  parameter Real m_mem = rho_m * L0 * W * h_mem "Membrane mass [kg]";
  parameter Real k_spring = E_mod * A_cross / L0 "Spring constant [N/m]";
  parameter Real c_damp = eta_v * A_cross / L0 "Damping coefficient [N.s/m]";
  parameter Real k_act = eps_0 * eps_r * W / h_mem "Actuator gain [N/V2]";
  parameter Real R_leak = h_mem / (sigma_leak * L0 * W) "Leakage resistance [Ohm]";
  parameter Real V_bias = sqrt(max(0.0, (k_spring * x_target - m_mem * g) / k_act))
    "Bias voltage for target equilibrium [V]";

  // ==================== Dynamic states ====================
  Real x_tip(start = x_target, fixed = true)
    "Tip displacement from undeformed position [m]";
  Real v_tip(start = 0.0, fixed = true) "Tip velocity [m/s]";
  Real V_act(start = V_bias, fixed = true)
    "Actual voltage across membrane [V]";
  Real T_temp(start = T_amb, fixed = true) "Membrane temperature [K]";
  Real x_est(start = x_target, fixed = true)
    "Estimated tip displacement from reduced-order model [m]";

  // ==================== Discrete state ====================
  Integer mission_state(start = 0)
    "Mission phase: 0=init, 1=hold, 2=disturbance, 3=recovery";

  // ==================== Computed quantities ====================
  Real p_maxwell "Maxwell electrostatic pressure [Pa]";
  Real F_act "Actuation force from Maxwell pressure [N]";
  Real F_gravity "Gravitational force on membrane [N]";
  Real F_disturbance "Applied disturbance force [N]";
  Real F_spring "Viscoelastic spring force [N]";
  Real F_damper "Viscoelastic damping force [N]";
  Real I_leak "Leakage current [A]";
  Real Q_joule "Joule heating power [W]";
  Real strain "Axial strain [-]";
  Real curvature "Estimated section curvature [1/m]";
  Real shape_error "Primary tracking error [m]";
  Real L_actuated "Actuated length in shared frame [m]";
  Real L_undeformed "Undeformed length in shared frame [m]";
  Real tip_x "Tip x-position in shared frame [m]";
  Real tip_y "Tip y-position in shared frame [m]";
  Real tip_theta "Tip angle in shared frame [rad]";
  Real V_cmd_raw "Raw controller output [V]";
  Real V_cmd "Saturated controller command [V]";
  Real v_est "Estimated tip velocity from reduced-order model [m/s]";

  // ==================== Sensor traces (synchronized) ====================
  Real s_force "Force sensor: total membrane reaction force [N]";
  Real s_strain "Strain sensor [-]";
  Real s_tip_x "Tip x-position sensor [m]";
  Real s_tip_y "Tip y-position sensor [m]";
  Real s_tip_theta "Tip angle sensor [rad]";
  Real s_temp "Temperature sensor [K]";
  Real s_curvature "Curvature sensor [1/m]";
  Real s_voltage "Voltage sensor [V]";
  Real s_current "Leakage current sensor [A]";

  // ==================== Bound monitors ====================
  Real bound_actuator "Actuator bound: V_act / V_max [-]";
  Real bound_strain "Strain bound: |strain| / strain_max [-]";
  Real bound_temp "Temperature bound: (T - T_amb) / dT_max [-]";
  Real bound_shape_error "Shape error bound: |error| / e_bound [-]";

equation
  // ===== Force computations =====
  F_gravity = m_mem * g;

  // Disturbance force during middle third of mission
  F_disturbance = if time >= t_dist_start and time <= t_dist_end
                  then F_dist else 0.0;

  // Maxwell pressure and actuation force (quadratic in voltage)
  p_maxwell = eps_0 * eps_r * (V_act / h_mem) * (V_act / h_mem);
  F_act = k_act * V_act * V_act;

  // Viscoelastic forces (Kelvin-Voigt: spring + damper in parallel)
  F_spring = k_spring * x_tip;
  F_damper = c_damp * v_tip;

  // ===== Mechanical dynamics =====
  // Membrane modeled as lumped mass-spring-damper with Maxwell actuation
  der(x_tip) = v_tip;
  m_mem * der(v_tip) = F_act + F_gravity + F_disturbance - F_spring - F_damper;

  // ===== Leakage and thermal state =====
  I_leak = V_act / R_leak;
  Q_joule = V_act * I_leak;
  c_th * der(T_temp) = Q_joule - k_th * (T_temp - T_amb);

  // ===== Voltage actuator with slew limiting =====
  // Smooth slew limiting via tanh: linear near target, saturates at slew rate
  V_cmd_raw = V_bias + Kp_ctrl * (x_target - x_est) - Kd_ctrl * v_est;
  V_cmd = max(0.0, min(V_max, V_cmd_raw));
  der(V_act) = slew * tanh(500.0 * (V_cmd - V_act) / slew);

  // ===== Reduced-order deformation model (estimator) =====
  // First-order complementary filter on measured tip position
  der(x_est) = (x_tip - x_est) / tau_est;
  v_est = (x_tip - x_est) / tau_est;

  // ===== Tracking error =====
  shape_error = x_target - x_tip;

  // ===== Geometry in shared frame =====
  // Undeformed and actuated geometry share common reference (clamp at origin)
  L_undeformed = L0;
  L_actuated = L0 + x_tip;
  strain = x_tip / L0;
  // Curvature estimate from distributed load (gravity) plus tip load
  curvature = (F_gravity + F_disturbance) / (E_mod * A_cross * L0);
  tip_x = x_tip;
  tip_y = 0.0;
  tip_theta = curvature * L0;

  // ===== Sensor traces (synchronized state, command, and sensors) =====
  s_force = F_spring + F_damper;
  s_strain = strain;
  s_tip_x = tip_x;
  s_tip_y = tip_y;
  s_tip_theta = tip_theta;
  s_temp = T_temp;
  s_curvature = curvature;
  s_voltage = V_act;
  s_current = I_leak;

  // ===== Bound monitors =====
  bound_actuator = V_act / V_max;
  bound_strain = abs(strain) / strain_max;
  bound_temp = (T_temp - T_amb) / dT_max;
  bound_shape_error = abs(shape_error) / e_bound;

  // ===== Finite-state machine for mission phases =====
  when {time >= 1.0, time >= t_dist_start, time >= t_dist_end} then
    mission_state = if time >= t_dist_end then 3
                    elseif time >= t_dist_start then 2
                    else 1;
  end when;

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "ElectroSoftShapeB: Dielectric-elastomer membrane soft robot.
      Mission: move tip to declared target shape (x_target = 0.001 m) and hold.
      A 4.2 N tip load disturbance is injected during the middle third (3.33-6.67 s).
      Controller uses shape feedback via a reduced-order deformation model (first-order estimator).
      Slew-limited HV channel (4100 V max, 4000 V/s slew).
      Run at 100 Hz (Interval=0.01 s) for 10 s.
      Primary tracking error bound: 0.054 m after 6.5 s."));
end ElectroSoftShapeB;