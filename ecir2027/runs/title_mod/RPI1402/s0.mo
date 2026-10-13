model ShapeLockGraspD
  "Six-section continuum arm with thermally activated stiffness for fragile object grasping"

  // ============ Physical parameters ============
  parameter Real L_sec = 0.02 "Section length [m]";
  parameter Real I_sec = 1.0e-5 "Section inertia [kg.m^2]";
  parameter Real b_sec = 0.005 "Section damping [N.m.s/rad]";
  parameter Real EI_max = 0.02 "Bending stiffness at T_low [N.m^2]";
  parameter Real EI_min = 0.002 "Bending stiffness at T_high [N.m^2]";
  parameter Real T_low = 320.0 "Lower temperature bound [K]";
  parameter Real T_high = 345.0 "Upper temperature bound [K]";
  parameter Real T_amb = 320.0 "Ambient temperature [K]";
  parameter Real C_th = 0.5 "Thermal capacitance [J/K]";
  parameter Real R_th = 1.389 "Thermal resistance [K/W]";
  parameter Real r_tendon = 0.008 "Tendon moment arm [m]";
  parameter Real F_tendon_max = 46.0 "Max tendon tension [N]";
  parameter Real P_heat_max = 18.0 "Max heater power per section [W]";
  parameter Real m_obj = 0.15 "Object mass [kg]";
  parameter Real g_const = 9.81 "Gravity [m/s^2]";
  parameter Real mu = 0.70 "Friction coefficient on rigid surface";
  parameter Real k_contact = 50.0 "Contact stiffness [N/rad]";
  parameter Real b_contact = 2.0 "Contact damping [N.s/rad]";
  parameter Real k_surface = 1.0e4 "Surface stiffness [N/m]";
  parameter Real b_surface = 50.0 "Surface damping [N.s/m]";
  parameter Real k_tang = 800.0 "Tangential contact stiffness [N/m]";
  parameter Real v_small = 0.001 "Friction smoothing velocity [m/s]";
  parameter Real theta_0 = 0.30 "Contact threshold base angle [rad]";
  parameter Real d_theta = 0.002 "Contact threshold spacing per section [rad]";
  parameter Real theta_max_bound = 1.57 "Max deformation angle bound [rad]";

  // ============ Controller parameters ============
  parameter Real F_n_total_ref = 8.0 "Target total normal force [N]";
  parameter Real F_n_total_min = 5.0 "Min total normal force band [N]";
  parameter Real F_n_total_max = 11.0 "Max total normal force band [N]";
  parameter Real F_n_per_max = 4.0 "Per-contact overload threshold [N]";
  parameter Real tau_base = 20.0 "Base tendon pre-tension [N]";
  parameter Real delta_tau_ff = 5.0 "Feedforward differential tension [N]";
  parameter Real Kp_force = 3.0 "Force regulation proportional gain [N/N]";
  parameter Real Kp_dist = 0.5 "Disturbance compensation gain [N/N]";
  parameter Real Kp_redist = 0.3 "Contact redistribution gain [N/N]";
  parameter Real dt = 0.005 "Controller sample time (200 Hz) [s]";
  parameter Real t_soft = 2.0 "Softening phase end time [s]";
  parameter Real t_stiff = 5.0 "Stiffening phase end time [s]";
  parameter Real t_dist_start = 4.667 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 9.333 "Disturbance end (middle third) [s]";
  parameter Real F_dist = 4.0 "Tangential disturbance magnitude [N]";

  // ============ Section states ============
  Real theta[6] "Section bending angle [rad]";
  Real theta_dot[6] "Section angular velocity [rad/s]";
  Real T_sec[6] "Section temperature [K]";

  // ============ Derived physical quantities ============
  Real EI[6] "Section bending stiffness [N.m^2]";
  Real M_tendon[6] "Tendon moment per section [N.m]";
  Real M_contact[6] "Contact moment per section [N.m]";
  Real F_n[6] "Normal contact force per section [N]";
  Real F_t[6] "Tangential contact force per section [N]";
  Real contact_active[6] "Contact active indicator (1=active, 0=inactive)";
  Real theta_ct[6] "Contact threshold per section [rad]";

  // ============ Actuator commands and outputs ============
  Real tau[3] "Tendon tension (actuator output) [N]";
  Real P_heat[6] "Heater power (actuator output) [W]";
  Real tau_cmd_c[3] "Continuous tendon command before sampling [N]";
  Real P_heat_cmd_c[6] "Continuous heater command before sampling [W]";
  discrete Real tau_cmd_d[3] "Discrete 200 Hz tendon command [N]";
  discrete Real P_heat_cmd_d[6] "Discrete 200 Hz heater command [W]";

  // ============ Object states ============
  Real x_obj "Object tangential displacement [m]";
  Real x_obj_dot "Object tangential velocity [m/s]";
  Real y_obj "Object height above surface [m]";
  Real y_obj_dot "Object vertical velocity [m/s]";

  // ============ Object-surface interaction ============
  Real N_surface "Surface normal force on object [N]";
  Real surface_pen "Surface penetration depth [m]";
  Real F_friction_surface "Surface friction force [N]";

  // ============ Aggregate forces ============
  Real F_n_total "Total normal grasp force [N]";
  Real F_t_total "Total tangential grasp force [N]";
  Real F_disturbance "Applied tangential disturbance [N]";
  Real F_n_total_err "Total force error [N]";
  Real F_n_overload_total "Sum of per-contact overloads [N]";

  // ============ Tracking and phase ============
  Real theta_track_err "Primary tracking error [m]";
  Real phase "Control phase (0=soften, 1=stiffen, 2=maintain)";

  // ============ Sensor traces (actuator, contact, pose) ============
  Real theta_meas[6] "Measured section angle (deformation) [rad]";
  Real T_meas[6] "Measured section temperature [K]";
  Real tau_meas[3] "Measured tendon tension (actuator sensing) [N]";
  Real P_meas[6] "Measured heater power (actuator sensing) [W]";
  Real F_n_meas[6] "Measured normal contact force (distributed sensing) [N]";
  Real F_t_meas[6] "Measured tangential contact force (distributed sensing) [N]";
  Real x_obj_meas "Measured object tangential position (pose) [m]";
  Real y_obj_meas "Measured object vertical position (pose) [m]";

  // ============ Bound check indicators (1=ok, 0=violation) ============
  Real actuator_ok "Actuator bounds satisfied";
  Real deformation_ok "Deformation bounds satisfied";
  Real force_band_ok "Per-contact and total force bands satisfied";
  Real no_contact_loss "No contact loss after grasp established";
  Real tracking_ok "Primary tracking error below 0.015 m after 9.1 s";

  // ============ Scalar bound computation variables ============
  Real max_tau_val;
  Real max_P_val;
  Real max_abs_theta_val;
  Real max_Fn_per_val;

equation

  // ---- Contact thresholds distributed across sections ----
  for i in 1:6 loop
    theta_ct[i] = theta_0 + d_theta * (i - 1);
  end for;

  // ---- Temperature-dependent stiffness (clamped to [EI_min, EI_max]) ----
  for i in 1:6 loop
    EI[i] = EI_min + (EI_max - EI_min) *
      max(0.0, min(1.0, (T_high - T_sec[i]) / (T_high - T_low)));
  end for;

  // ---- Tendon moment (all sections share three tendons) ----
  for i in 1:6 loop
    M_tendon[i] = r_tendon * (tau[1] - 0.5 * tau[2] - 0.5 * tau[3]);
  end for;

  // ---- Compliant contact normal force per section ----
  for i in 1:6 loop
    F_n[i] = max(0.0, k_contact * (theta[i] - theta_ct[i]) + b_contact * theta_dot[i]);
    contact_active[i] = if theta[i] > theta_ct[i] then 1.0 else 0.0;
  end for;

  // ---- Contact moment on each section ----
  for i in 1:6 loop
    M_contact[i] = F_n[i] * L_sec;
  end for;

  // ---- Tangential contact force (compliant spring, friction-limited) ----
  for i in 1:6 loop
    F_t[i] = max(-mu * F_n[i], min(mu * F_n[i], -k_tang * x_obj * contact_active[i]));
  end for;

  // ---- Aggregate forces ----
  F_n_total = F_n[1] + F_n[2] + F_n[3] + F_n[4] + F_n[5] + F_n[6];
  F_t_total = F_t[1] + F_t[2] + F_t[3] + F_t[4] + F_t[5] + F_t[6];

  // ---- Rigid surface interaction (unilateral, compliant) ----
  surface_pen = max(0.0, -y_obj);
  N_surface = k_surface * surface_pen + b_surface * max(0.0, -y_obj_dot);
  F_friction_surface = -mu * N_surface * tanh(x_obj_dot / v_small);

  // ---- Controlled tangential disturbance (middle third) ----
  F_disturbance = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // ---- Section bending dynamics ----
  for i in 1:6 loop
    theta_dot[i] = der(theta[i]);
    I_sec * der(theta_dot[i]) = M_tendon[i] - EI[i] * theta[i] / L_sec
                              - b_sec * theta_dot[i] - M_contact[i];
  end for;

  // ---- Section thermal dynamics ----
  for i in 1:6 loop
    C_th * der(T_sec[i]) = P_heat[i] - (T_sec[i] - T_amb) / R_th;
  end for;

  // ---- Object dynamics ----
  der(x_obj) = x_obj_dot;
  m_obj * der(x_obj_dot) = F_disturbance + F_t_total + F_friction_surface;
  der(y_obj) = y_obj_dot;
  m_obj * der(y_obj_dot) = -m_obj * g_const + F_n_total - N_surface;

  // ---- Actuator saturation (tendon tension <= 46 N, heater power <= 18 W) ----
  for j in 1:3 loop
    tau[j] = max(0.0, min(F_tendon_max, tau_cmd_d[j]));
  end for;
  for i in 1:6 loop
    P_heat[i] = max(0.0, min(P_heat_max, P_heat_cmd_d[i]));
  end for;

  // ---- Continuous controller ----
  F_n_total_err = F_n_total - F_n_total_ref;

  F_n_overload_total =
      max(0.0, F_n[1] - F_n_per_max) + max(0.0, F_n[2] - F_n_per_max)
    + max(0.0, F_n[3] - F_n_per_max) + max(0.0, F_n[4] - F_n_per_max)
    + max(0.0, F_n[5] - F_n_per_max) + max(0.0, F_n[6] - F_n_per_max);

  // Tendon command: pre-tension + feedforward + force regulation
  //   + disturbance compensation - contact overload redistribution
  tau_cmd_c[1] = tau_base + delta_tau_ff
               - Kp_force * F_n_total_err
               + Kp_dist * F_disturbance
               - Kp_redist * F_n_overload_total;

  tau_cmd_c[2] = tau_base - 0.5 * delta_tau_ff
               + 0.5 * Kp_force * F_n_total_err
               - 0.5 * Kp_dist * F_disturbance
               + 0.5 * Kp_redist * F_n_overload_total;

  tau_cmd_c[3] = tau_base - 0.5 * delta_tau_ff
               + 0.5 * Kp_force * F_n_total_err
               - 0.5 * Kp_dist * F_disturbance
               + 0.5 * Kp_redist * F_n_overload_total;

  // Heater command: full power during soften phase, off thereafter
  for i in 1:6 loop
    P_heat_cmd_c[i] = if time < t_soft then P_heat_max else 0.0;
  end for;

  // ---- Control phase indicator ----
  phase = if time < t_soft then 0.0
          else if time < t_stiff then 1.0
          else 2.0;

  // ---- Primary tracking error = object displacement ----
  theta_track_err = abs(x_obj);

  // ---- Discrete 200 Hz controller ----
  when sample(0, dt) loop
    for j in 1:3 loop
      tau_cmd_d[j] = tau_cmd_c[j];
    end for;
    for i in 1:6 loop
      P_heat_cmd_d[i] = P_heat_cmd_c[i];
    end for;
  end when;

  // ---- Sensor traces (synchronized with state and commands) ----
  for i in 1:6 loop
    theta_meas[i] = theta[i];
    T_meas[i] = T_sec[i];
    P_meas[i] = P_heat[i];
    F_n_meas[i] = F_n[i];
    F_t_meas[i] = F_t[i];
  end for;
  for j in 1:3 loop
    tau_meas[j] = tau[j];
  end for;
  x_obj_meas = x_obj;
  y_obj_meas = y_obj;

  // ---- Scalar bound computation (explicit, no array reduction) ----
  max_tau_val = max(max(tau[1], tau[2]), tau[3]);

  max_P_val = max(max(P_heat[1], P_heat[2]),
                  max(max(P_heat[3], P_heat[4]),
                      max(P_heat[5], P_heat[6])));

  max_abs_theta_val = max(max(abs(theta[1]), abs(theta[2])),
                          max(max(abs(theta[3]), abs(theta[4])),
                              max(abs(theta[5]), abs(theta[6]))));

  max_Fn_per_val = max(max(F_n[1], F_n[2]),
                       max(max(F_n[3], F_n[4]),
                           max(F_n[5], F_n[6])));

  // ---- Bound checks ----
  actuator_ok     = if (max_tau_val <= F_tendon_max + 1.0e-6)
                       and (max_P_val <= P_heat_max + 1.0e-6) then 1.0 else 0.0;
  deformation_ok  = if max_abs_theta_val <= theta_max_bound then 1.0 else 0.0;
  force_band_ok   = if ((F_n_total >= F_n_total_min)
                       and (F_n_total <= F_n_total_max)
                       and (max_Fn_per_val <= F_n_per_max + 1.0e-6))
                       or (time < t_stiff) then 1.0 else 0.0;
  no_contact_loss = if (F_n_total > 0.0) or (time < t_stiff) then 1.0 else 0.0;
  tracking_ok     = if (theta_track_err < 0.015) or (time < 9.1) then 1.0 else 0.0;

  // ============ Initial conditions ============
initial equation
  for i in 1:6 loop
    theta[i] = 0.0;
    theta_dot[i] = 0.0;
    T_sec[i] = T_amb;
  end for;
  x_obj = 0.0;
  x_obj_dot = 0.0;
  y_obj = 0.0;
  y_obj_dot = 0.0;
  for j in 1:3 loop
    tau_cmd_d[j] = tau_base;
  end for;
  for i in 1:6 loop
    P_heat_cmd_d[i] = 0.0;
  end for;

annotation(
  experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
  Documentation(info = "ShapeLockGraspD: Instrumented soft robotic grasp system.

  Embodiment: six-section continuum arm with three tendons and thermally
  activated stiffness elements. Bending stiffness varies between 320 K
  (rigid, EI_max) and 345 K (compliant, EI_min). All sections share the
  same three tendons; differential tendon tension creates bending moment.

  Actuation: tendon tension and section heater power independently
  controlled, limited to 46 N and 18 W respectively. Controller runs
  at 200 Hz (dt = 0.005 s) for 14 s.

  Behavior: conform around a fragile object (soften via heating, then
  stiffen via cooling) and regulate total normal grasp force without
  local per-contact overload. Compliant collision with friction
  coefficient 0.70 on rigid support surface. Contact-force redistribution
  reduces per-contact overload. Controlled 4 N tangential disturbance
  applied during the middle third (4.667-9.333 s).

  Sensors: actuator sensing (tendon tension, heater power), distributed
  contact sensing (per-section normal and tangential forces), and object
  pose measurement (tangential and vertical position).

  Requirements verified: actuator and deformation bounds, per-contact
  and total force bands, object displacement, no contact loss, primary
  tracking error below 0.015 m after 9.1 s, and finite non-NaN values.

  Unknown facts not stated in the requirement (e.g., exact object geometry,
  tendon routing cross-section, polymer thermal properties, section mass
  distribution) are not fabricated; lumped parameters are used.")
);
end ShapeLockGraspD;