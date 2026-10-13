model ElectroSoftAvoidC
  // ===========================================================================
  // Stated parameters
  // ===========================================================================
  parameter Real L0 = 0.20 "Membrane length [m]";
  parameter Real W_mem = 0.05 "Membrane width [m]";
  parameter Real t_mem = 0.8e-3 "Membrane thickness [m]";
  parameter Real V_max = 4600.0 "Maximum command magnitude [V] (4.6 kV)";
  parameter Real F_dist_val = 7.2 "Lateral tip load disturbance [N]";
  parameter Real mu_friction = 0.55 "Friction coefficient";
  parameter Real f_sample = 125.0 "Sample rate [Hz]";
  parameter Real t_sim = 12.0 "Simulation duration [s]";

  // ===========================================================================
  // Assumed parameters (not stated in requirement — labeled as assumed)
  // ===========================================================================
  parameter Real epsilon_0 = 8.854187817e-12 "Vacuum permittivity [F/m]";
  parameter Real epsilon_r = 5000.0 "Relative permittivity (assumed high-k DEA composite)";
  parameter Real E_mod = 2.0e7 "Elastic modulus [Pa] (assumed)";
  parameter Real tau_visco = 0.4 "Viscoelastic time constant [s] (assumed)";
  parameter Real R_leak = 1.0e9 "Leakage resistance [Ohm] (assumed)";
  parameter Real cp_mem = 1700.0 "Specific heat capacity [J/(kg.K)] (assumed)";
  parameter Real rho_mem = 1100.0 "Density [kg/m3] (assumed)";
  parameter Real h_conv = 20.0 "Convective heat transfer coefficient [W/(m2.K)] (assumed)";
  parameter Real T_amb = 293.15 "Ambient temperature [K] (assumed)";
  parameter Real V_slew_rate = 2000.0 "Voltage slew rate [V/s] (assumed)";
  parameter Real m_eff = 0.012 "Effective tip mass [kg] (assumed)";
  parameter Real damping_ratio = 0.08 "Damping ratio (assumed)";

  // Obstacle geometry (assumed)
  parameter Real x_obs = 0.20 "Obstacle center x [m] (assumed)";
  parameter Real y_obs = 0.022 "Obstacle center y [m] (assumed)";
  parameter Real r_obs = 0.018 "Obstacle cylinder radius [m] (assumed)";
  parameter Real r_tip = 0.003 "Tip contact radius [m] (assumed)";
  parameter Real k_contact = 2.0e4 "Contact penalty stiffness [N/m] (assumed)";
  parameter Real c_contact = 30.0 "Contact damping [N.s/m] (assumed)";

  // Target (assumed)
  parameter Real x_target = 0.205 "Target x [m] (assumed)";
  parameter Real y_target = 0.0 "Target y [m] (assumed)";

  // Control gains (assumed)
  parameter Real kp_approach = 0.5 "Approach proportional gain (assumed)";
  parameter Real kd_approach = 0.05 "Approach derivative gain (assumed)";
  parameter Real kp_hold = 2.0 "Hold proportional gain (assumed)";
  parameter Real kd_hold = 0.15 "Hold derivative gain (assumed)";
  parameter Real k_stiff_hold = 2.0e7 "Stiffness boost in hold phase [V^2] (assumed)";
  parameter Real t_stiffen = 7.8 "Stiffening start time [s]";

  // ===========================================================================
  // Derived constants
  // ===========================================================================
  final parameter Real k_spring = E_mod * W_mem * t_mem / L0
    "Membrane spring stiffness [N/m]";
  final parameter Real c_damp_val = 2.0 * sqrt(max(k_spring * m_eff, 1.0e-6)) * damping_ratio
    "Damping coefficient [N.s/m]";
  final parameter Real alpha_act = epsilon_0 * epsilon_r / (E_mod * t_mem * t_mem)
    "Actuation strain coefficient [1/V^2]";
  final parameter Real m_thermal = rho_mem * L0 * W_mem * t_mem
    "Membrane thermal mass [kg]";
  final parameter Real A_surf = 2.0 * L0 * W_mem
    "Convective surface area [m2]";
  final parameter Real L_target = sqrt(x_target * x_target + y_target * y_target)
    "Target distance from base [m]";
  final parameter Real eps_target = (L_target - L0) / L0
    "Target strain [dimensionless]";

  // ===========================================================================
  // State variables
  // ===========================================================================
  Real x_tip(start = L0) "Tip x position [m]";
  Real y_tip(start = 0.0) "Tip y position [m]";
  Real vx(start = 0.0) "Tip x velocity [m/s]";
  Real vy(start = 0.0) "Tip y velocity [m/s]";
  Real V_act(start = 0.0) "Actual voltage, slew-limited [V]";
  Real T_mem(start = T_amb) "Membrane temperature [K]";
  Real z_visco(start = 0.0) "Viscoelastic internal strain state";

  // ===========================================================================
  // Sensor / computed variables
  // ===========================================================================
  Real L_tip "Current membrane length [m] (tip pose sensor)";
  Real ux "Unit vector x from tip to base";
  Real uy "Unit vector y from tip to base";
  Real v_along "Velocity along membrane extension [m/s]";
  Real eps_act "Actuation strain from Maxwell stress";
  Real eps_current "Current total strain (section deformation sensor)";
  Real eps_visco "Viscoelastic strain component";
  Real L_rest "Voltage-dependent rest length [m]";
  Real F_spring "Spring force magnitude [N]";
  Real F_spring_x "Spring force x [N]";
  Real F_spring_y "Spring force y [N]";
  Real F_damp_x "Damping force x [N]";
  Real F_damp_y "Damping force y [N]";
  Real F_dist "Active disturbance force [N]";
  Real d_obs "Distance from tip to obstacle center [m]";
  Real clearance "Obstacle clearance [m] (obstacle-clearance sensor)";
  Real penetration "Contact penetration depth [m]";
  Real nx "Contact normal x";
  Real ny "Contact normal y";
  Real tx "Contact tangent x";
  Real ty "Contact tangent y";
  Real v_normal "Normal velocity at contact [m/s]";
  Real v_tangent "Tangent velocity at contact [m/s]";
  Real contact_active "Contact active flag (0 or 1)";
  Real F_contact_mag "Contact normal force magnitude [N] (contact-force sensor)";
  Real F_friction_mag "Friction force magnitude [N]";
  Real F_contact_x "Total contact force x [N]";
  Real F_contact_y "Total contact force y [N]";
  Real I_leak "Leakage current [A] (actuator state sensor)";
  Real P_leak "Leakage power [W]";
  Real P_diss "Dissipation power [W]";
  Real error_x "Tracking error x [m]";
  Real error_y "Tracking error y [m]";
  Real error_mag "Tracking error magnitude [m] (tip-error sensor)";
  Real V_cmd_sq "Voltage command squared [V^2]";
  Real V_cmd_raw "Raw voltage command before slew [V]";
  Real V_cmd_bounded "Bounded voltage command [V]";
  Real kp_eff "Effective proportional gain";
  Real kd_eff "Effective derivative gain";
  Real stiff_boost "Stiffness boost factor [V^2]";
  Real deformation "Section deformation (strain) sensor";

equation
  // ====== Kinematics ======
  L_tip = sqrt(x_tip * x_tip + y_tip * y_tip + 1.0e-10);
  ux = -x_tip / L_tip;
  uy = -y_tip / L_tip;
  v_along = -(vx * ux + vy * uy);
  eps_current = (L_tip - L0) / L0;

  // ====== Actuation strain (Maxwell stress: eps = eps0*epsr*(V/t)^2 / E) ======
  eps_act = alpha_act * V_act * V_act;

  // ====== Viscoelasticity (first-order creep model) ======
  der(z_visco) = (eps_act - z_visco) / tau_visco;
  eps_visco = z_visco;

  // ====== Rest length (depends on voltage and viscoelastic state) ======
  L_rest = L0 * (1.0 + eps_act + eps_visco);

  // ====== Spring force (along membrane axis, toward rest length) ======
  F_spring = k_spring * (L_tip - L_rest);
  F_spring_x = F_spring * ux;
  F_spring_y = F_spring * uy;

  // ====== Viscous damping ======
  F_damp_x = -c_damp_val * vx;
  F_damp_y = -c_damp_val * vy;

  // ====== Disturbance: 7.2 N lateral tip load during middle third (4-8 s) ======
  F_dist = if (time >= 4.0 and time <= 8.0) then F_dist_val else 0.0;

  // ====== Obstacle contact (penalty-based with Coulomb friction, mu=0.55) ======
  d_obs = sqrt((x_tip - x_obs) * (x_tip - x_obs) +
               (y_tip - y_obs) * (y_tip - y_obs) + 1.0e-10);
  clearance = d_obs - (r_obs + r_tip);
  penetration = max(0.0, (r_obs + r_tip) - d_obs);

  // Contact normal (from obstacle center toward tip)
  nx = (x_tip - x_obs) / d_obs;
  ny = (y_tip - y_obs) / d_obs;

  // Contact tangent (perpendicular to normal)
  tx = -ny;
  ty = nx;

  // Contact velocities
  v_normal = vx * nx + vy * ny;
  v_tangent = vx * tx + vy * ty;

  // Contact active flag
  contact_active = if penetration > 0.0 then 1.0 else 0.0;

  // Normal contact force (penalty spring + damper)
  F_contact_mag = (k_contact * penetration +
                   c_contact * max(0.0, -v_normal)) * contact_active;

  // Coulomb friction (smoothed to avoid discontinuity)
  F_friction_mag = mu_friction * F_contact_mag *
                   v_tangent / (abs(v_tangent) + 1.0e-3);

  // Total contact force
  F_contact_x = F_contact_mag * nx + F_friction_mag * tx;
  F_contact_y = F_contact_mag * ny + F_friction_mag * ty;

  // ====== Leakage and thermal model ======
  I_leak = V_act / R_leak;
  P_leak = V_act * I_leak;
  P_diss = c_damp_val * (vx * vx + vy * vy) +
           c_contact * max(0.0, -v_normal) * max(0.0, -v_normal) * contact_active;
  der(T_mem) = (P_leak + P_diss - h_conv * A_surf * (T_mem - T_amb)) /
               (m_thermal * cp_mem);

  // ====== Controller with bounded stiffness scheduling ======
  // Tracking error
  error_x = x_target - x_tip;
  error_y = y_target - y_tip;
  error_mag = sqrt(error_x * error_x + error_y * error_y + 1.0e-10);

  // Gain scheduling: approach phase vs hold/stiffen phase
  kp_eff = if time >= t_stiffen then kp_hold else kp_approach;
  kd_eff = if time >= t_stiffen then kd_hold else kd_approach;
  stiff_boost = if time >= t_stiffen then k_stiff_hold else 0.0;

  // Voltage command from strain feedback + stiffness boost
  // Higher voltage => larger rest length => tip extends
  // Stiffness boost increases tension for lateral disturbance rejection
  V_cmd_sq = (eps_target + kp_eff * (eps_target - eps_current) -
              kd_eff * v_along / L0 - z_visco) / alpha_act + stiff_boost;
  V_cmd_raw = sqrt(max(0.0, V_cmd_sq));
  V_cmd_bounded = min(V_max, V_cmd_raw);

  // Slew-limited high-voltage channel
  der(V_act) = max(-V_slew_rate,
                   min(V_slew_rate, V_cmd_bounded - V_act));

  // ====== Newton's second law (2D tip dynamics) ======
  m_eff * der(vx) = F_spring_x + F_damp_x + F_contact_x;
  m_eff * der(vy) = F_spring_y + F_damp_y + F_contact_y + F_dist;
  der(x_tip) = vx;
  der(y_tip) = vy;

  // ====== Section deformation measurement ======
  deformation = eps_current;

  // ====== Bounds and assertions (no NaN or infinite values) ======
  assert(V_act >= -0.1 and V_act <= V_max + 0.1,
         "Actuator voltage bound exceeded");
  assert(abs(deformation) < 0.5,
         "Deformation bound exceeded");
  assert(F_contact_mag >= -0.1 and F_contact_mag < 1000.0,
         "Contact force bound exceeded");
  assert(T_mem > 200.0 and T_mem < 500.0,
         "Temperature out of bounds");
  assert(clearance > -0.1,
         "Obstacle clearance violated beyond penalty");
  assert(error_mag < 1.0,
         "Tracking error exceeded safety limit");
  assert(V_cmd_raw >= 0.0 and V_cmd_raw < 1.0e5,
         "Voltage command out of range");

annotation(
  experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
  Documentation(info = "ElectroSoftAvoidC: Contact-aware shape control with bounded stiffness scheduling
    for a dielectric-elastomer membrane soft robot.
    Plant: 0.20 m x 0.05 m x 0.8 mm DEA membrane with explicit permittivity, viscoelasticity,
    leakage resistance, and thermal state. Slew-limited HV channel (max 4.6 kV) controls elongation.
    Fixed cylinder obstacle with friction coefficient 0.55 and collision enabled.
    Disturbance: 7.2 N lateral tip load during middle third (4-8 s of 12 s).
    Run at 125 Hz (Interval = 0.008 s) for 12 s. Synchronized state, command, and sensor traces
    retained as model variables. Primary tracking error required below 0.042 m after 7.8 s.
    Parameters not stated in the requirement are assumed and labeled as such in comments."));
end ElectroSoftAvoidC;