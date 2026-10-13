model ElectroSoftShapeC
  "Soft robotic DE membrane system with shape feedback, reduced-order deformation model"

  // === Geometry (from requirement) ===
  parameter Real L0 = 0.20 "Undeformed membrane length [m]";
  parameter Real W_mem = 0.05 "Membrane width [m]";
  parameter Real t_mem = 0.8e-3 "Membrane thickness [m]";

  // === Material properties (unstated: typical DE values used) ===
  parameter Real eps0 = 8.854187817e-12 "Vacuum permittivity [F/m]";
  parameter Real eps_r = 4.7 "Relative permittivity (unstated, typical DE)";
  parameter Real E_mod = 1.0e6 "Young's modulus [Pa] (unstated)";
  parameter Real rho_mem = 1000.0 "Density [kg/m3] (unstated)";
  parameter Real cp_mem = 1500.0 "Specific heat [J/(kg.K)] (unstated)";
  parameter Real sigma_leak = 1.0e-13 "Leakage conductivity [S/m] (unstated)";
  parameter Real h_conv = 10.0 "Convection coefficient [W/(m2.K)] (unstated)";
  parameter Real T_amb = 293.15 "Ambient temperature [K] (unstated)";

  // === Viscoelasticity (unstated) ===
  parameter Real c_visco = 5.0 "Kelvin-Voigt viscous damping [N.s/m] (unstated)";
  parameter Real k_maxwell = 100.0 "Maxwell spring stiffness [N/m] (unstated)";
  parameter Real tau_maxwell = 0.5 "Maxwell relaxation time [s] (unstated)";

  // === Control parameters ===
  parameter Real Vmax = 4600.0 "Maximum command voltage [V] = 4.6 kV (from requirement)";
  parameter Real slew_rate = 2000.0 "Voltage slew rate limit [V/s] (unstated)";
  parameter Real target_elong = 0.03 "Declared target elongation [m] (unstated, declared by system)";
  parameter Real Kp = 500.0 "Proportional gain [N/m] (unstated)";
  parameter Real Kd = 15.0 "Derivative gain [N.s/m] (unstated)";
  parameter Real Ts = 1.0 / 125.0 "Controller sample period [s] = 125 Hz (from requirement)";
  parameter Real T_sim = 12.0 "Simulation duration [s] (from requirement)";

  // === Disturbance (from requirement) ===
  parameter Real F_disturb_mag = 5.4 "Tip load disturbance magnitude [N] (from requirement)";
  parameter Real t_dist_start = 4.0 "Disturbance start [s] (middle third of 12 s)";
  parameter Real t_dist_end = 8.0 "Disturbance end [s] (middle third of 12 s)";

  // === Physical constants ===
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // === Tip mass (unstated) ===
  parameter Real m_tip = 0.05 "Tip payload mass [kg] (unstated)";

  // === Bounds (unstated, declared for verification) ===
  parameter Real strain_limit = 0.5 "Maximum allowable strain magnitude [-] (unstated)";
  parameter Real temp_limit = 353.15 "Maximum allowable temperature [K] (unstated)";
  parameter Real tracking_limit = 0.047 "Primary tracking error limit after 7.8 s [m] (from requirement)";

  // === Derived parameters ===
  parameter Real A_cross = W_mem * t_mem "Cross-section area [m2]";
  parameter Real k_spring = E_mod * A_cross / L0 "Elastic stiffness [N/m]";
  parameter Real m_membrane = rho_mem * W_mem * L0 * t_mem "Membrane mass [kg]";
  parameter Real m_total = m_membrane + m_tip "Total moving mass [kg]";
  parameter Real alpha_act = eps0 * eps_r * W_mem * L0 / (t_mem * t_mem)
    "Maxwell stress actuation coefficient [N/V2]";
  parameter Real A_surf = 2.0 * W_mem * L0 "Surface area for convection [m2]";
  parameter Real c_maxwell = k_maxwell * tau_maxwell "Maxwell damper coefficient [N.s/m]";

  // === Continuous dynamic states ===
  Real x(start = 0.0, fixed = true) "Elongation from undeformed [m]";
  Real v(start = 0.0, fixed = true) "Elongation velocity [m/s]";
  Real F_maxwell_state(start = 0.0, fixed = true) "Maxwell viscoelastic force state [N]";
  Real T(start = T_amb, fixed = true) "Membrane temperature [K]";
  Real V(start = 0.0, fixed = true) "Applied high voltage [V]";

  // === Discrete controller variables ===
  discrete Real V_cmd(start = 0.0) "Clipped voltage command [V]";
  discrete Real x_s(start = 0.0) "Sampled elongation [m]";
  discrete Real v_s(start = 0.0) "Sampled velocity [m/s]";
  discrete Real F_des(start = 0.0) "Desired actuation force [N]";

  // === Finite state machine ===
  discrete Integer mode(start = 0) "0=init, 1=nominal tracking, 2=disturbance rejection, 3=recovery";

  // === Forces (synchronized state traces) ===
  Real F_actuation "Dielectric elastomer actuation force [N]";
  Real F_elastic "Elastic restoring force [N]";
  Real F_visco "Kelvin-Voigt viscous force [N]";
  Real F_gravity "Gravitational force on total mass [N]";
  Real F_dist "Active disturbance force [N]";
  Real pressure_DE "Dielectric Maxwell pressure [Pa]";

  // === Leakage and thermal ===
  Real I_leak "Leakage current [A]";
  Real P_leak "Leakage power dissipation [W]";
  Real P_visco "Viscoelastic dissipation power [W]";
  Real P_total_diss "Total thermal dissipation [W]";

  // === Sensor traces ===
  Real strain "Measured strain [-]";
  Real curvature_est "Estimated curvature [1/m] (0 for 1D elongation model)";
  Real tip_y_undeformed "Undeformed tip y-position in shared frame [m]";
  Real tip_y_actuated "Actuated tip y-position in shared frame [m]";
  Real F_tendon_sensor "Tendon/actuation force sensor [N]";
  Real T_sensor "Temperature sensor [K]";

  // === Tracking and bounds ===
  Real tracking_error "Primary tracking error |target - actual| [m]";
  discrete Real tracking_error_7_8(start = 0.0) "Tracking error captured at t=7.8 s [m]";
  Real actuator_violation "Actuator bound excess [V]";
  Real strain_mag "Strain magnitude [-]";
  Real temp_excess "Temperature excess above limit [K]";
  Real tracking_violation "Tracking bound violation after 7.8 s (0=OK, 1=violated)";
  Real finite_check "Finite-state check (0=all finite, 1=violation)";

equation
  // === Disturbance injection: 5.4 N during middle third (4-8 s of 12 s) ===
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_disturb_mag else 0.0;

  // === Finite state machine ===
  when time >= 0.01 then
    mode = 1;
  end when;
  when time >= t_dist_start then
    mode = 2;
  end when;
  when time >= t_dist_end then
    mode = 3;
  end when;

  // === Force computations ===
  F_gravity = m_total * g;
  F_elastic = k_spring * x;
  F_visco = c_visco * v;
  der(F_maxwell_state) = k_maxwell * v - F_maxwell_state / tau_maxwell;

  // === Dielectric elastomer actuation via Maxwell stress ===
  pressure_DE = eps0 * eps_r * (V / t_mem) * (V / t_mem);
  F_actuation = pressure_DE * W_mem * L0;

  // === Plant dynamics: vertical hanging membrane, gravity along elongation ===
  // Shared frame: origin at fixed (top) end, y positive downward along gravity
  // Undeformed tip at y = L0, actuated tip at y = L0 + x
  der(x) = v;
  m_total * der(v) = F_actuation + F_gravity - F_dist - F_elastic - F_visco - F_maxwell_state;

  // === Leakage current and thermal model ===
  I_leak = sigma_leak * (V / t_mem) * W_mem * L0;
  P_leak = V * I_leak;
  P_visco = c_visco * v * v + F_maxwell_state * F_maxwell_state / c_maxwell;
  P_total_diss = P_leak + P_visco;
  m_membrane * cp_mem * der(T) = P_total_diss - h_conv * A_surf * (T - T_amb);

  // === Slew-limited high-voltage channel ===
  // V tracks V_cmd with rate limited to slew_rate
  der(V) = max(-slew_rate, min(slew_rate, 100.0 * (V_cmd - V)));

  // === Discrete controller at 125 Hz ===
  // Feedforward: equilibrium force k_spring*target - m_total*g
  // Feedback: PD on tracking error
  // Inversion: V = sqrt(F / alpha_act), clipped to [0, Vmax]
  when sample(0, Ts) then
    x_s = x;
    v_s = v;
    F_des = k_spring * target_elong - m_total * g + Kp * (target_elong - x_s) - Kd * v_s;
    if F_des > 0.0 then
      V_cmd = min(Vmax, sqrt(F_des / alpha_act));
    else
      V_cmd = 0.0;
    end if;
  end when;

  // === Sensor outputs ===
  strain = x / L0;
  curvature_est = 0.0;
  tip_y_undeformed = L0;
  tip_y_actuated = L0 + x;
  F_tendon_sensor = F_actuation;
  T_sensor = T;

  // === Tracking error ===
  tracking_error = abs(target_elong - x);

  when time >= 7.8 then
    tracking_error_7_8 = abs(target_elong - x);
  end when;

  // === Bound verification ===
  actuator_violation = max(0.0, V - Vmax);
  strain_mag = abs(strain);
  temp_excess = max(0.0, T - temp_limit);
  tracking_violation = if time >= 7.8 and tracking_error > tracking_limit then 1.0 else 0.0;
  finite_check = if noEvent(x > -1.0e10 and x < 1.0e10 and
                            v > -1.0e10 and v < 1.0e10 and
                            T > 0.0 and T < 1.0e10 and
                            V >= 0.0 and V < 1.0e10 and
                            F_maxwell_state > -1.0e10 and F_maxwell_state < 1.0e10)
                  then 0.0 else 1.0;

  // === Safety assertions ===
  assert(V <= Vmax + 1.0e-3, "Actuator voltage exceeds 4.6 kV maximum command magnitude");
  assert(strain_mag <= strain_limit, "Strain exceeds allowable bound");
  assert(T <= temp_limit, "Temperature exceeds allowable bound");
  assert(finite_check < 0.5, "Non-finite physical, control, or estimator value detected");

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1.0e-6, Interval = 0.008),
    Documentation(info = "ElectroSoftShapeC: Dielectric-elastomer membrane soft robot.
    Membrane: 0.20 m x 0.05 m, 0.8 mm thickness, vertical hanging orientation.
    Shared frame: origin at fixed end, y positive downward (gravity direction).
    Controller: 125 Hz sampled PD with feedforward, slew-limited HV channel.
    Disturbance: 5.4 N tip load during middle third (4-8 s of 12 s).
    Tracking target: 0.03 m elongation. Error < 0.047 m required after 7.8 s.
    Unstated parameters use physically typical DE values; see individual comments."));
end ElectroSoftShapeC;