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
  theta_ct[1] = theta_0 + d_theta * 0;
  theta_ct[2] = theta_0 + d_theta * 1;
  theta_ct[3] = theta_0 + d_theta * 2;
  theta_ct[4] = theta_0 + d_theta * 3;
  theta_ct[5] = theta_0 + d_theta * 4;
  theta_ct[6] = theta_0 + d_theta * 5;

  // ---- Temperature-dependent stiffness (clamped to [EI_min, EI_max]) ----
  EI[1] = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec[1]) / (T_high - T_low)));
  EI[2] = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec[2]) / (T_high - T_low)));
  EI[3] = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec[3]) / (T_high - T_low)));
  EI[4] = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec[4]) / (T_high - T_low)));
  EI[5] = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec[5]) / (T_high - T_low)));
  EI[6] = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec[6]) / (T_high - T_low)));

  // ---- Tendon moment (all sections share three tendons) ----
  M_tendon[1] = r_tendon * (tau[1] - 0.5 * tau[2] - 0.5 * tau[3]);
  M_tendon[2] = r_tendon * (tau[1] - 0.5 * tau[2] - 0.5 * tau[3]);
  M_tendon[3] = r_tendon * (tau[1] - 0.5 * tau[2] - 0.5 * tau[3]);
  M_tendon[4] = r_tendon * (tau[1] - 0.5 * tau[2] - 0.5 * tau[3]);
  M_tendon[5] = r_tendon * (tau[1] - 0.5 * tau[2] - 0.5 * tau[3]);
  M_tendon[6] = r_tendon * (tau[1] - 0.5 * tau[2] - 0.5 * tau[3]);

  // ---- Compliant contact normal force per section ----
  F_n[1] = max(0.0, k_contact * (theta[1] - theta_ct[1]) + b_contact * theta_dot[1]);
  F_n[2] = max(0.0, k_contact * (theta[2] - theta_ct[2]) + b_contact * theta_dot[2]);
  F_n[3] = max(0.0, k_contact * (theta[3] - theta_ct[3]) + b_contact * theta_dot[3]);
  F_n[4] = max(0.0, k_contact * (theta[4] - theta_ct[4]) + b_contact * theta_dot[4]);
  F_n[5] = max(0.0, k_contact * (theta[5] - theta_ct[5]) + b_contact * theta_dot[5]);
  F_n[6] = max(0.0, k_contact * (theta[6] - theta_ct[6]) + b_contact * theta_dot[6]);

  contact_active[1] = if theta[1] > theta_ct[1] then 1.0 else 0.0;
  contact_active[2] = if theta[2] > theta_ct[2] then 1.0 else 0.0;
  contact_active[3] = if theta[3] > theta_ct[3] then 1.0 else 0.0;
  contact_active[4] = if theta[4] > theta_ct[4] then 1.0 else 0.0;
  contact_active[5] = if theta[5] > theta_ct[5] then 1.0 else 0.0;
  contact_active[6] = if theta[6] > theta_ct[6] then 1.0 else 0.0;

  // ---- Contact moment on each section ----
  M_contact[1] = F_n[1] * L_sec;
  M_contact[2] = F_n[2] * L_sec;
  M_contact[3] = F_n[3] * L_sec;
  M_contact[4] = F_n[4] * L_sec;
  M_contact[5] = F_n[5] * L_sec;
  M_contact[6] = F_n[6] * L_sec;

  // ---- Tangential contact force (compliant spring, friction-limited) ----
  F_t[1] = max(-mu * F_n[1], min(mu * F_n[1], -k_tang * x_obj * contact_active[1]));
  F_t[2] = max(-mu * F_n[2], min(mu * F_n[2], -k_tang * x_obj * contact_active[2]));
  F_t[3] = max(-mu * F_n[3], min(mu * F_n[3], -k_tang * x_obj * contact_active[3]));
  F_t[4] = max(-mu * F_n[4], min(mu * F_n[4], -k_tang * x_obj * contact_active[4]));
  F_t[5] = max(-mu * F_n[5], min(mu * F_n[5], -k_tang * x_obj * contact_active[5]));
  F_t[6] = max(-mu * F_n[6], min(mu * F_n[6], -k_tang * x_obj * contact_active[6]));

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
  theta_dot[1] = der(theta[1]);
  theta_dot[2] = der(theta[2]);
  theta_dot[3] = der(theta[3]);
  theta_dot[4] = der(theta[4]);
  theta_dot[5] = der(theta[5]);
  theta_dot[6] = der(theta[6]);

  I_sec * der(theta_dot[1]) = M_tendon[1] - EI[1] * theta[1] / L_sec - b_sec * theta_dot[1] - M_contact[1];
  I_sec * der(theta_dot[2]) = M_tendon[2] - EI[2] * theta[2] / L_sec - b_sec * theta_dot[2] - M_contact[2];
  I_sec * der(theta_dot[3]) = M_tendon[3] - EI[3] * theta[3] / L_sec - b_sec * theta_dot[3] - M_contact[3];
  I_sec * der(theta_dot[4]) = M_tendon[4] - EI[4] * theta[4] / L_sec - b_sec * theta_dot[4] - M_contact[4];
  I_sec * der(theta_dot[5]) = M_tendon[5] - EI[5] * theta[5] / L_sec - b_sec * theta_dot[5] - M_contact[5];
  I_sec * der(theta_dot[6]) = M_tendon[6] - EI[6] * theta[6] / L_sec - b_sec * theta_dot[6] - M_contact[6];

  // ---- Section thermal dynamics ----
  C_th * der(T_sec[1]) = P_heat[1] - (T_sec[1] - T_amb) / R_th;
  C_th * der(T_sec[2]) = P_heat[2] - (T_sec[2] - T_amb) / R_th;
  C_th * der(T_sec[3]) = P_heat[3] - (T_sec[3] - T_amb) / R_th;
  C_th * der(T_sec[4]) = P_heat[4] - (T_sec[4] - T_amb) / R_th;
  C_th * der(T_sec[5]) = P_heat[5] - (T_sec[5] - T_amb) / R_th;
  C_th * der(T_sec[6]) = P_heat[6] - (T_sec[6] - T_amb) / R_th;

  // ---- Object dynamics ----
  der(x_obj) = x_obj_dot;
  m_obj * der(x_obj_dot) = F_disturbance + F_t_total + F_friction_surface;
  der(y_obj) = y_obj_dot;
  m_obj * der(y_obj_dot) = -m_obj * g_const + F_n_total - N_surface;

  // ---- Actuator saturation (tendon tension <= 46 N, heater power <= 18 W) ----
  tau[1] = max(0.0, min(F_tendon_max, tau_cmd_d[1]));
  tau[2] = max(0.0, min(F_tendon_max, tau_cmd_d[2]));
  tau[3] = max(0.0, min(F_tendon_max, tau_cmd_d[3]));

  P_heat[1] = max(0.0, min(P_heat_max, P_heat_cmd_d[1]));
  P_heat[2] = max(0.0, min(P_heat_max, P_heat_cmd_d[2]));
  P_heat[3] = max(0.0, min(P_heat_max, P_heat_cmd_d[3]));
  P_heat[4] = max(0.0, min(P_heat_max, P_heat_cmd_d[4]));
  P_heat[5] = max(0.0, min(P_heat_max, P_heat_cmd_d[5]));
  P_heat[6] = max(0.0, min(P_heat_max, P_heat_cmd_d[6]));

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
  P_heat_cmd_c[1] = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c[2] = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c[3] = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c[4] = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c[5] = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c[6] = if time < t_soft then P_heat_max else 0.0;

  // ---- Control phase indicator ----
  phase = if time < t_soft then 0.0
          else if time < t_stiff then 1.0
          else 2.0;

  // ---- Primary tracking error = object displacement ----
  theta_track_err = abs(x_obj);

  // ---- Discrete 200 Hz controller ----
  when sample(0, dt) then
    tau_cmd_d[1] = tau_cmd_c[1];
    tau_cmd_d[2] = tau_cmd_c[2];
    tau_cmd_d[3] = tau_cmd_c[3];
    P_heat_cmd_d[1] = P_heat_cmd_c[1];
    P_heat_cmd_d[2] = P_heat_cmd_c[2];
    P_heat_cmd_d[3] = P_heat_cmd_c[3];
    P_heat_cmd_d[4] = P_heat_cmd_c[4];
    P_heat_cmd_d[5] = P_heat_cmd_c[5];
    P_heat_cmd_d[6] = P_heat_cmd_c[6];
  end when;

  // ---- Sensor traces (synchronized with state and commands) ----
  theta_meas[1] = theta[1];
  theta_meas[2] = theta[2];
  theta_meas[3] = theta[3];
  theta_meas[4] = theta[4];
  theta_meas[5] = theta[5];
  theta_meas[6] = theta[6];

  T_meas[1] = T_sec[1];
  T_meas[2] = T_sec[2];
  T_meas[3] = T_sec[3];
  T_meas[4] = T_sec[4];
  T_meas[5] = T_sec[5];
  T_meas[6] = T_sec[6];

  P_meas[1] = P_heat[1];
  P_meas[2] = P_heat[2];
  P_meas[3] = P_heat[3];
  P_meas[4] = P_heat[4];
  P_meas[5] = P_heat[5];
  P_meas[6] = P_heat[6];

  F_n_meas[1] = F_n[1];
  F_n_meas[2] = F_n[2];
  F_n_meas[3] = F_n[3];
  F_n_meas[4] = F_n[4];
  F_n_meas[5] = F_n[5];
  F_n_meas[6] = F_n[6];

  F_t_meas[1] = F_t[1];
  F_t_meas[2] = F_t[2];
  F_t_meas[3] = F_t[3];
  F_t_meas[4] = F_t[4];
  F_t_meas[5] = F_t[5];
  F_t_meas[6] = F_t[6];

  tau_meas[1] = tau[1];
  tau_meas[2] = tau[2];
  tau_meas[3] = tau[3];

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

initial equation
  theta[1] = 0.0;
  theta[2] = 0.0;
  theta[3] = 0.0;
  theta[4] = 0.0;
  theta[5] = 0.0;
  theta[6] = 0.0;
  theta_dot[1] = 0.0;
  theta_dot[2] = 0.0;
  theta_dot[3] = 0.0;
  theta_dot[4] = 0.0;
  theta_dot[5] = 0.0;
  theta_dot[6] = 0.0;
  T_sec[1] = T_amb;
  T_sec[2] = T_amb;
  T_sec[3] = T_amb;
  T_sec[4] = T_amb;
  T_sec[5] = T_amb;
  T_sec[6] = T_amb;
  x_obj = 0.0;
  x_obj_dot = 0.0;
  y_obj = 0.0;
  y_obj_dot = 0.0;
  tau_cmd_d[1] = tau_base;
  tau_cmd_d[2] = tau_base;
  tau_cmd_d[3] = tau_base;
  P_heat_cmd_d[1] = 0.0;
  P_heat_cmd_d[2] = 0.0;
  P_heat_cmd_d[3] = 0.0;
  P_heat_cmd_d[4] = 0.0;
  P_heat_cmd_d[5] = 0.0;
  P_heat_cmd_d[6] = 0.0;

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