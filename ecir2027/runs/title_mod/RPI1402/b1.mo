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
  Real theta1 "Section 1 bending angle [rad]";
  Real theta2 "Section 2 bending angle [rad]";
  Real theta3 "Section 3 bending angle [rad]";
  Real theta4 "Section 4 bending angle [rad]";
  Real theta5 "Section 5 bending angle [rad]";
  Real theta6 "Section 6 bending angle [rad]";
  
  Real theta_dot1 "Section 1 angular velocity [rad/s]";
  Real theta_dot2 "Section 2 angular velocity [rad/s]";
  Real theta_dot3 "Section 3 angular velocity [rad/s]";
  Real theta_dot4 "Section 4 angular velocity [rad/s]";
  Real theta_dot5 "Section 5 angular velocity [rad/s]";
  Real theta_dot6 "Section 6 angular velocity [rad/s]";
  
  Real T_sec1 "Section 1 temperature [K]";
  Real T_sec2 "Section 2 temperature [K]";
  Real T_sec3 "Section 3 temperature [K]";
  Real T_sec4 "Section 4 temperature [K]";
  Real T_sec5 "Section 5 temperature [K]";
  Real T_sec6 "Section 6 temperature [K]";

  // ============ Derived physical quantities ============
  Real EI1 "Section 1 bending stiffness [N.m^2]";
  Real EI2 "Section 2 bending stiffness [N.m^2]";
  Real EI3 "Section 3 bending stiffness [N.m^2]";
  Real EI4 "Section 4 bending stiffness [N.m^2]";
  Real EI5 "Section 5 bending stiffness [N.m^2]";
  Real EI6 "Section 6 bending stiffness [N.m^2]";
  
  Real M_tendon1 "Section 1 tendon moment [N.m]";
  Real M_tendon2 "Section 2 tendon moment [N.m]";
  Real M_tendon3 "Section 3 tendon moment [N.m]";
  Real M_tendon4 "Section 4 tendon moment [N.m]";
  Real M_tendon5 "Section 5 tendon moment [N.m]";
  Real M_tendon6 "Section 6 tendon moment [N.m]";
  
  Real M_contact1 "Section 1 contact moment [N.m]";
  Real M_contact2 "Section 2 contact moment [N.m]";
  Real M_contact3 "Section 3 contact moment [N.m]";
  Real M_contact4 "Section 4 contact moment [N.m]";
  Real M_contact5 "Section 5 contact moment [N.m]";
  Real M_contact6 "Section 6 contact moment [N.m]";
  
  Real F_n1 "Section 1 normal contact force [N]";
  Real F_n2 "Section 2 normal contact force [N]";
  Real F_n3 "Section 3 normal contact force [N]";
  Real F_n4 "Section 4 normal contact force [N]";
  Real F_n5 "Section 5 normal contact force [N]";
  Real F_n6 "Section 6 normal contact force [N]";
  
  Real F_t1 "Section 1 tangential contact force [N]";
  Real F_t2 "Section 2 tangential contact force [N]";
  Real F_t3 "Section 3 tangential contact force [N]";
  Real F_t4 "Section 4 tangential contact force [N]";
  Real F_t5 "Section 5 tangential contact force [N]";
  Real F_t6 "Section 6 tangential contact force [N]";
  
  Real contact_active1 "Section 1 contact indicator";
  Real contact_active2 "Section 2 contact indicator";
  Real contact_active3 "Section 3 contact indicator";
  Real contact_active4 "Section 4 contact indicator";
  Real contact_active5 "Section 5 contact indicator";
  Real contact_active6 "Section 6 contact indicator";
  
  Real theta_ct1 "Section 1 contact threshold [rad]";
  Real theta_ct2 "Section 2 contact threshold [rad]";
  Real theta_ct3 "Section 3 contact threshold [rad]";
  Real theta_ct4 "Section 4 contact threshold [rad]";
  Real theta_ct5 "Section 5 contact threshold [rad]";
  Real theta_ct6 "Section 6 contact threshold [rad]";

  // ============ Actuator commands and outputs ============
  Real tau1 "Tendon 1 tension (actuator output) [N]";
  Real tau2 "Tendon 2 tension (actuator output) [N]";
  Real tau3 "Tendon 3 tension (actuator output) [N]";
  
  Real P_heat1 "Section 1 heater power (actuator output) [W]";
  Real P_heat2 "Section 2 heater power (actuator output) [W]";
  Real P_heat3 "Section 3 heater power (actuator output) [W]";
  Real P_heat4 "Section 4 heater power (actuator output) [W]";
  Real P_heat5 "Section 5 heater power (actuator output) [W]";
  Real P_heat6 "Section 6 heater power (actuator output) [W]";
  
  Real tau_cmd_c1 "Continuous tendon 1 command [N]";
  Real tau_cmd_c2 "Continuous tendon 2 command [N]";
  Real tau_cmd_c3 "Continuous tendon 3 command [N]";
  
  Real P_heat_cmd_c1 "Continuous heater 1 command [W]";
  Real P_heat_cmd_c2 "Continuous heater 2 command [W]";
  Real P_heat_cmd_c3 "Continuous heater 3 command [W]";
  Real P_heat_cmd_c4 "Continuous heater 4 command [W]";
  Real P_heat_cmd_c5 "Continuous heater 5 command [W]";
  Real P_heat_cmd_c6 "Continuous heater 6 command [W]";
  
  discrete Real tau_cmd_d1 "Discrete 200 Hz tendon 1 command [N]";
  discrete Real tau_cmd_d2 "Discrete 200 Hz tendon 2 command [N]";
  discrete Real tau_cmd_d3 "Discrete 200 Hz tendon 3 command [N]";
  
  discrete Real P_heat_cmd_d1 "Discrete 200 Hz heater 1 command [W]";
  discrete Real P_heat_cmd_d2 "Discrete 200 Hz heater 2 command [W]";
  discrete Real P_heat_cmd_d3 "Discrete 200 Hz heater 3 command [W]";
  discrete Real P_heat_cmd_d4 "Discrete 200 Hz heater 4 command [W]";
  discrete Real P_heat_cmd_d5 "Discrete 200 Hz heater 5 command [W]";
  discrete Real P_heat_cmd_d6 "Discrete 200 Hz heater 6 command [W]";

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

  // ============ Sensor traces ============
  Real theta_meas1 "Measured section 1 angle [rad]";
  Real theta_meas2 "Measured section 2 angle [rad]";
  Real theta_meas3 "Measured section 3 angle [rad]";
  Real theta_meas4 "Measured section 4 angle [rad]";
  Real theta_meas5 "Measured section 5 angle [rad]";
  Real theta_meas6 "Measured section 6 angle [rad]";
  
  Real T_meas1 "Measured section 1 temperature [K]";
  Real T_meas2 "Measured section 2 temperature [K]";
  Real T_meas3 "Measured section 3 temperature [K]";
  Real T_meas4 "Measured section 4 temperature [K]";
  Real T_meas5 "Measured section 5 temperature [K]";
  Real T_meas6 "Measured section 6 temperature [K]";
  
  Real tau_meas1 "Measured tendon 1 tension [N]";
  Real tau_meas2 "Measured tendon 2 tension [N]";
  Real tau_meas3 "Measured tendon 3 tension [N]";
  
  Real P_meas1 "Measured section 1 heater power [W]";
  Real P_meas2 "Measured section 2 heater power [W]";
  Real P_meas3 "Measured section 3 heater power [W]";
  Real P_meas4 "Measured section 4 heater power [W]";
  Real P_meas5 "Measured section 5 heater power [W]";
  Real P_meas6 "Measured section 6 heater power [W]";
  
  Real F_n_meas1 "Measured section 1 normal force [N]";
  Real F_n_meas2 "Measured section 2 normal force [N]";
  Real F_n_meas3 "Measured section 3 normal force [N]";
  Real F_n_meas4 "Measured section 4 normal force [N]";
  Real F_n_meas5 "Measured section 5 normal force [N]";
  Real F_n_meas6 "Measured section 6 normal force [N]";
  
  Real F_t_meas1 "Measured section 1 tangential force [N]";
  Real F_t_meas2 "Measured section 2 tangential force [N]";
  Real F_t_meas3 "Measured section 3 tangential force [N]";
  Real F_t_meas4 "Measured section 4 tangential force [N]";
  Real F_t_meas5 "Measured section 5 tangential force [N]";
  Real F_t_meas6 "Measured section 6 tangential force [N]";
  
  Real x_obj_meas "Measured object tangential position [m]";
  Real y_obj_meas "Measured object vertical position [m]";

  // ============ Bound check indicators ============
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
  theta_ct1 = theta_0;
  theta_ct2 = theta_0 + d_theta;
  theta_ct3 = theta_0 + 2.0 * d_theta;
  theta_ct4 = theta_0 + 3.0 * d_theta;
  theta_ct5 = theta_0 + 4.0 * d_theta;
  theta_ct6 = theta_0 + 5.0 * d_theta;

  // ---- Temperature-dependent stiffness (clamped to [EI_min, EI_max]) ----
  EI1 = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec1) / (T_high - T_low)));
  EI2 = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec2) / (T_high - T_low)));
  EI3 = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec3) / (T_high - T_low)));
  EI4 = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec4) / (T_high - T_low)));
  EI5 = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec5) / (T_high - T_low)));
  EI6 = EI_min + (EI_max - EI_min) * max(0.0, min(1.0, (T_high - T_sec6) / (T_high - T_low)));

  // ---- Tendon moment (all sections share three tendons) ----
  M_tendon1 = r_tendon * (tau1 - 0.5 * tau2 - 0.5 * tau3);
  M_tendon2 = M_tendon1;
  M_tendon3 = M_tendon1;
  M_tendon4 = M_tendon1;
  M_tendon5 = M_tendon1;
  M_tendon6 = M_tendon1;

  // ---- Compliant contact normal force per section ----
  F_n1 = max(0.0, k_contact * (theta1 - theta_ct1) + b_contact * theta_dot1);
  F_n2 = max(0.0, k_contact * (theta2 - theta_ct2) + b_contact * theta_dot2);
  F_n3 = max(0.0, k_contact * (theta3 - theta_ct3) + b_contact * theta_dot3);
  F_n4 = max(0.0, k_contact * (theta4 - theta_ct4) + b_contact * theta_dot4);
  F_n5 = max(0.0, k_contact * (theta5 - theta_ct5) + b_contact * theta_dot5);
  F_n6 = max(0.0, k_contact * (theta6 - theta_ct6) + b_contact * theta_dot6);

  // ---- Smooth contact active indicator ----
  contact_active1 = 0.5 + 0.5 * tanh(100.0 * (theta1 - theta_ct1));
  contact_active2 = 0.5 + 0.5 * tanh(100.0 * (theta2 - theta_ct2));
  contact_active3 = 0.5 + 0.5 * tanh(100.0 * (theta3 - theta_ct3));
  contact_active4 = 0.5 + 0.5 * tanh(100.0 * (theta4 - theta_ct4));
  contact_active5 = 0.5 + 0.5 * tanh(100.0 * (theta5 - theta_ct5));
  contact_active6 = 0.5 + 0.5 * tanh(100.0 * (theta6 - theta_ct6));

  // ---- Contact moment on each section ----
  M_contact1 = F_n1 * L_sec;
  M_contact2 = F_n2 * L_sec;
  M_contact3 = F_n3 * L_sec;
  M_contact4 = F_n4 * L_sec;
  M_contact5 = F_n5 * L_sec;
  M_contact6 = F_n6 * L_sec;

  // ---- Tangential contact force (compliant spring, friction-limited) ----
  F_t1 = max(-mu * F_n1, min(mu * F_n1, -k_tang * x_obj * contact_active1));
  F_t2 = max(-mu * F_n2, min(mu * F_n2, -k_tang * x_obj * contact_active2));
  F_t3 = max(-mu * F_n3, min(mu * F_n3, -k_tang * x_obj * contact_active3));
  F_t4 = max(-mu * F_n4, min(mu * F_n4, -k_tang * x_obj * contact_active4));
  F_t5 = max(-mu * F_n5, min(mu * F_n5, -k_tang * x_obj * contact_active5));
  F_t6 = max(-mu * F_n6, min(mu * F_n6, -k_tang * x_obj * contact_active6));

  // ---- Aggregate forces ----
  F_n_total = F_n1 + F_n2 + F_n3 + F_n4 + F_n5 + F_n6;
  F_t_total = F_t1 + F_t2 + F_t3 + F_t4 + F_t5 + F_t6;

  // ---- Rigid surface interaction (unilateral, compliant) ----
  surface_pen = max(0.0, -y_obj);
  N_surface = k_surface * surface_pen + b_surface * max(0.0, -y_obj_dot);
  F_friction_surface = -mu * N_surface * tanh(x_obj_dot / v_small);

  // ---- Controlled tangential disturbance (middle third) ----
  F_disturbance = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // ---- Section bending dynamics ----
  theta_dot1 = der(theta1);
  I_sec * der(theta_dot1) = M_tendon1 - EI1 * theta1 / L_sec - b_sec * theta_dot1 - M_contact1;

  theta_dot2 = der(theta2);
  I_sec * der(theta_dot2) = M_tendon2 - EI2 * theta2 / L_sec - b_sec * theta_dot2 - M_contact2;

  theta_dot3 = der(theta3);
  I_sec * der(theta_dot3) = M_tendon3 - EI3 * theta3 / L_sec - b_sec * theta_dot3 - M_contact3;

  theta_dot4 = der(theta4);
  I_sec * der(theta_dot4) = M_tendon4 - EI4 * theta4 / L_sec - b_sec * theta_dot4 - M_contact4;

  theta_dot5 = der(theta5);
  I_sec * der(theta_dot5) = M_tendon5 - EI5 * theta5 / L_sec - b_sec * theta_dot5 - M_contact5;

  theta_dot6 = der(theta6);
  I_sec * der(theta_dot6) = M_tendon6 - EI6 * theta6 / L_sec - b_sec * theta_dot6 - M_contact6;

  // ---- Section thermal dynamics ----
  C_th * der(T_sec1) = P_heat1 - (T_sec1 - T_amb) / R_th;
  C_th * der(T_sec2) = P_heat2 - (T_sec2 - T_amb) / R_th;
  C_th * der(T_sec3) = P_heat3 - (T_sec3 - T_amb) / R_th;
  C_th * der(T_sec4) = P_heat4 - (T_sec4 - T_amb) / R_th;
  C_th * der(T_sec5) = P_heat5 - (T_sec5 - T_amb) / R_th;
  C_th * der(T_sec6) = P_heat6 - (T_sec6 - T_amb) / R_th;

  // ---- Object dynamics ----
  der(x_obj) = x_obj_dot;
  m_obj * der(x_obj_dot) = F_disturbance + F_t_total + F_friction_surface;
  der(y_obj) = y_obj_dot;
  m_obj * der(y_obj_dot) = -m_obj * g_const + F_n_total - N_surface;

  // ---- Actuator saturation (tendon tension <= 46 N, heater power <= 18 W) ----
  tau1 = max(0.0, min(F_tendon_max, tau_cmd_d1));
  tau2 = max(0.0, min(F_tendon_max, tau_cmd_d2));
  tau3 = max(0.0, min(F_tendon_max, tau_cmd_d3));

  P_heat1 = max(0.0, min(P_heat_max, P_heat_cmd_d1));
  P_heat2 = max(0.0, min(P_heat_max, P_heat_cmd_d2));
  P_heat3 = max(0.0, min(P_heat_max, P_heat_cmd_d3));
  P_heat4 = max(0.0, min(P_heat_max, P_heat_cmd_d4));
  P_heat5 = max(0.0, min(P_heat_max, P_heat_cmd_d5));
  P_heat6 = max(0.0, min(P_heat_max, P_heat_cmd_d6));

  // ---- Continuous controller ----
  F_n_total_err = F_n_total - F_n_total_ref;

  F_n_overload_total = max(0.0, F_n1 - F_n_per_max) + max(0.0, F_n2 - F_n_per_max) +
                       max(0.0, F_n3 - F_n_per_max) + max(0.0, F_n4 - F_n_per_max) +
                       max(0.0, F_n5 - F_n_per_max) + max(0.0, F_n6 - F_n_per_max);

  // Tendon commands: pre-tension + feedforward + force regulation + disturbance comp
  tau_cmd_c1 = tau_base + delta_tau_ff - Kp_force * F_n_total_err + Kp_dist * F_disturbance - Kp_redist * F_n_overload_total;
  tau_cmd_c2 = tau_base - 0.5 * delta_tau_ff + 0.5 * Kp_force * F_n_total_err - 0.5 * Kp_dist * F_disturbance + 0.5 * Kp_redist * F_n_overload_total;
  tau_cmd_c3 = tau_base - 0.5 * delta_tau_ff + 0.5 * Kp_force * F_n_total_err - 0.5 * Kp_dist * F_disturbance + 0.5 * Kp_redist * F_n_overload_total;

  // Heater command: full power during soften phase, off thereafter
  P_heat_cmd_c1 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c2 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c3 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c4 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c5 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd_c6 = if time < t_soft then P_heat_max else 0.0;

  // ---- Control phase indicator ----
  phase = if time < t_soft then 0.0 else if time < t_stiff then 1.0 else 2.0;

  // ---- Primary tracking error = object displacement ----
  theta_track_err = abs(x_obj);

  // ---- Discrete 200 Hz controller ----
  when sample(0, dt) loop
    tau_cmd_d1 = tau_cmd_c1;
    tau_cmd_d2 = tau_cmd_c2;
    tau_cmd_d3 = tau_cmd_c3;
    P_heat_cmd_d1 = P_heat_cmd_c1;
    P_heat_cmd_d2 = P_heat_cmd_c2;
    P_heat_cmd_d3 = P_heat_cmd_c3;
    P_heat_cmd_d4 = P_heat_cmd_c4;
    P_heat_cmd_d5 = P_heat_cmd_c5;
    P_heat_cmd_d6 = P_heat_cmd_c6;
  end when;

  // ---- Sensor traces (synchronized with state and commands) ----
  theta_meas1 = theta1;
  theta_meas2 = theta2;
  theta_meas3 = theta3;
  theta_meas4 = theta4;
  theta_meas5 = theta5;
  theta_meas6 = theta6;

  T_meas1 = T_sec1;
  T_meas2 = T_sec2;
  T_meas3 = T_sec3;
  T_meas4 = T_sec4;
  T_meas5 = T_sec5;
  T_meas6 = T_sec6;

  tau_meas1 = tau1;
  tau_meas2 = tau2;
  tau_meas3 = tau3;

  P_meas1 = P_heat1;
  P_meas2 = P_heat2;
  P_meas3 = P_heat3;
  P_meas4 = P_heat4;
  P_meas5 = P_heat5;
  P_meas6 = P_heat6;

  F_n_meas1 = F_n1;
  F_n_meas2 = F_n2;
  F_n_meas3 = F_n3;
  F_n_meas4 = F_n4;
  F_n_meas5 = F_n5;
  F_n_meas6 = F_n6;

  F_t_meas1 = F_t1;
  F_t_meas2 = F_t2;
  F_t_meas3 = F_t3;
  F_t_meas4 = F_t4;
  F_t_meas5 = F_t5;
  F_t_meas6 = F_t6;

  x_obj_meas = x_obj;
  y_obj_meas = y_obj;

  // ---- Scalar bound computation (explicit, no array reduction) ----
  max_tau_val = max(max(tau1, tau2), tau3);

  max_P_val = max(max(P_heat1, P_heat2), max(max(P_heat3, P_heat4), max(P_heat5, P_heat6)));

  max_abs_theta_val = max(max(abs(theta1), abs(theta2)), max(max(abs(theta3), abs(theta4)), max(abs(theta5), abs(theta6))));

  max_Fn_per_val = max(max(F_n1, F_n2), max(max(F_n3, F_n4), max(F_n5, F_n6)));

  // ---- Bound checks ----
  actuator_ok     = if (max_tau_val <= F_tendon_max + 1.0e-6) and (max_P_val <= P_heat_max + 1.0e-6) then 1.0 else 0.0;
  deformation_ok  = if max_abs_theta_val <= theta_max_bound then 1.0 else 0.0;
  force_band_ok   = if ((F_n_total >= F_n_total_min) and (F_n_total <= F_n_total_max) and (max_Fn_per_val <= F_n_per_max + 1.0e-6)) or (time < t_stiff) then 1.0 else 0.0;
  no_contact_loss = if (F_n_total > 0.0) or (time < t_stiff) then 1.0 else 0.0;
  tracking_ok     = if (theta_track_err < 0.015) or (time < 9.1) then 1.0 else 0.0;

initial equation
  theta1 = 0.0;
  theta2 = 0.0;
  theta3 = 0.0;
  theta4 = 0.0;
  theta5 = 0.0;
  theta6 = 0.0;
  
  theta_dot1 = 0.0;
  theta_dot2 = 0.0;
  theta_dot3 = 0.0;
  theta_dot4 = 0.0;
  theta_dot5 = 0.0;
  theta_dot6 = 0.0;
  
  T_sec1 = T_amb;
  T_sec2 = T_amb;
  T_sec3 = T_amb;
  T_sec4 = T_amb;
  T_sec5 = T_amb;
  T_sec6 = T_amb;
  
  x_obj = 0.0;
  x_obj_dot = 0.0;
  y_obj = 0.0;
  y_obj_dot = 0.0;
  
  tau_cmd_d1 = tau_base;
  tau_cmd_d2 = tau_base;
  tau_cmd_d3 = tau_base;
  
  P_heat_cmd_d1 = 0.0;
  P_heat_cmd_d2 = 0.0;
  P_heat_cmd_d3 = 0.0;
  P_heat_cmd_d4 = 0.0;
  P_heat_cmd_d5 = 0.0;
  P_heat_cmd_d6 = 0.0;

annotation(
  experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
  Documentation(info = "ShapeLockGraspD: Instrumented soft robotic grasp system.
  Embodiment: six-section continuum arm with three tendons and thermally activated stiffness elements.
  Sensors: actuator sensing, distributed contact sensing, object pose measurement.
  Behavior: conform around a fragile object, regulate total normal grasp force, no local overload.
  Compliance: friction 0.70 on rigid support surface, 4 N tangential load disturbance in middle third.
  Runs at 200 Hz for 14 s, retaining synchronized state, command, and sensor traces."));
end ShapeLockGraspD;