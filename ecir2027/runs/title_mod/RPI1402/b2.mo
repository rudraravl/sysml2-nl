model ShapeLockGraspD
  "Six-section continuum arm with thermally activated stiffness for fragile object grasping"

  // Physical parameters
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

  // Controller parameters
  parameter Real F_n_total_ref = 8.0 "Target total normal force [N]";
  parameter Real F_n_total_min = 5.0 "Min total normal force band [N]";
  parameter Real F_n_total_max = 11.0 "Max total normal force band [N]";
  parameter Real F_n_per_max = 4.0 "Per-contact overload threshold [N]";
  parameter Real tau_base = 20.0 "Base tendon pre-tension [N]";
  parameter Real delta_tau_ff = 5.0 "Feedforward differential tension [N]";
  parameter Real Kp_force = 3.0 "Force regulation proportional gain";
  parameter Real Kp_dist = 0.5 "Disturbance compensation gain";
  parameter Real Kp_redist = 0.3 "Contact redistribution gain";
  parameter Real dt_ctrl = 0.005 "Controller sample time (200 Hz) [s]";
  parameter Real t_soft = 2.0 "Softening phase end time [s]";
  parameter Real t_stiff = 5.0 "Stiffening phase end time [s]";
  parameter Real t_dist_start = 4.667 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 9.333 "Disturbance end (middle third) [s]";
  parameter Real F_dist = 4.0 "Tangential disturbance magnitude [N]";

  // Section bending states
  Real theta1(start = 0.0, fixed = true) "Section 1 bending angle [rad]";
  Real theta2(start = 0.0, fixed = true) "Section 2 bending angle [rad]";
  Real theta3(start = 0.0, fixed = true) "Section 3 bending angle [rad]";
  Real theta4(start = 0.0, fixed = true) "Section 4 bending angle [rad]";
  Real theta5(start = 0.0, fixed = true) "Section 5 bending angle [rad]";
  Real theta6(start = 0.0, fixed = true) "Section 6 bending angle [rad]";

  Real theta_dot1(start = 0.0, fixed = true) "Section 1 angular velocity [rad/s]";
  Real theta_dot2(start = 0.0, fixed = true) "Section 2 angular velocity [rad/s]";
  Real theta_dot3(start = 0.0, fixed = true) "Section 3 angular velocity [rad/s]";
  Real theta_dot4(start = 0.0, fixed = true) "Section 4 angular velocity [rad/s]";
  Real theta_dot5(start = 0.0, fixed = true) "Section 5 angular velocity [rad/s]";
  Real theta_dot6(start = 0.0, fixed = true) "Section 6 angular velocity [rad/s]";

  // Section thermal states
  Real T_sec1(start = 320.0, fixed = true) "Section 1 temperature [K]";
  Real T_sec2(start = 320.0, fixed = true) "Section 2 temperature [K]";
  Real T_sec3(start = 320.0, fixed = true) "Section 3 temperature [K]";
  Real T_sec4(start = 320.0, fixed = true) "Section 4 temperature [K]";
  Real T_sec5(start = 320.0, fixed = true) "Section 5 temperature [K]";
  Real T_sec6(start = 320.0, fixed = true) "Section 6 temperature [K]";

  // Object states
  Real x_obj(start = 0.0, fixed = true) "Object tangential displacement [m]";
  Real x_obj_dot(start = 0.0, fixed = true) "Object tangential velocity [m/s]";
  Real y_obj(start = 0.0, fixed = true) "Object height above surface [m]";
  Real y_obj_dot(start = 0.0, fixed = true) "Object vertical velocity [m/s]";

  // Actuator outputs
  Real tau1 "Tendon 1 tension [N]";
  Real tau2 "Tendon 2 tension [N]";
  Real tau3 "Tendon 3 tension [N]";
  Real P_heat1 "Section 1 heater power [W]";
  Real P_heat2 "Section 2 heater power [W]";
  Real P_heat3 "Section 3 heater power [W]";
  Real P_heat4 "Section 4 heater power [W]";
  Real P_heat5 "Section 5 heater power [W]";
  Real P_heat6 "Section 6 heater power [W]";

  // Controller commands
  Real tau_cmd1 "Tendon 1 command [N]";
  Real tau_cmd2 "Tendon 2 command [N]";
  Real tau_cmd3 "Tendon 3 command [N]";
  Real P_heat_cmd1 "Heater 1 command [W]";
  Real P_heat_cmd2 "Heater 2 command [W]";
  Real P_heat_cmd3 "Heater 3 command [W]";
  Real P_heat_cmd4 "Heater 4 command [W]";
  Real P_heat_cmd5 "Heater 5 command [W]";
  Real P_heat_cmd6 "Heater 6 command [W]";

  // Bending stiffness
  Real EI1 "Section 1 bending stiffness [N.m^2]";
  Real EI2 "Section 2 bending stiffness [N.m^2]";
  Real EI3 "Section 3 bending stiffness [N.m^2]";
  Real EI4 "Section 4 bending stiffness [N.m^2]";
  Real EI5 "Section 5 bending stiffness [N.m^2]";
  Real EI6 "Section 6 bending stiffness [N.m^2]";

  // Contact thresholds
  Real theta_ct1 "Section 1 contact threshold [rad]";
  Real theta_ct2 "Section 2 contact threshold [rad]";
  Real theta_ct3 "Section 3 contact threshold [rad]";
  Real theta_ct4 "Section 4 contact threshold [rad]";
  Real theta_ct5 "Section 5 contact threshold [rad]";
  Real theta_ct6 "Section 6 contact threshold [rad]";

  // Contact forces
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

  // Contact indicators
  Real contact_active1 "Section 1 contact indicator";
  Real contact_active2 "Section 2 contact indicator";
  Real contact_active3 "Section 3 contact indicator";
  Real contact_active4 "Section 4 contact indicator";
  Real contact_active5 "Section 5 contact indicator";
  Real contact_active6 "Section 6 contact indicator";

  // Aggregate forces
  Real F_n_total "Total normal grasp force [N]";
  Real F_t_total "Total tangential grasp force [N]";

  // Surface interaction
  Real N_surface "Surface normal force on object [N]";
  Real surface_pen "Surface penetration depth [m]";
  Real F_friction_surface "Surface friction force [N]";
  Real F_disturbance "Applied tangential disturbance [N]";

  // Tendon moment
  Real M_tendon "Tendon moment shared across sections [N.m]";

  // Controller intermediates
  Real F_n_total_err "Total force error [N]";
  Real F_n_overload_total "Sum of per-contact overloads [N]";
  Real ov1 "Section 1 overload [N]";
  Real ov2 "Section 2 overload [N]";
  Real ov3 "Section 3 overload [N]";
  Real ov4 "Section 4 overload [N]";
  Real ov5 "Section 5 overload [N]";
  Real ov6 "Section 6 overload [N]";
  Real phase "Control phase";
  Real theta_track_err "Primary tracking error [m]";

  // Sensors: actuator sensing
  Real tau_meas1 "Measured tendon 1 tension [N]";
  Real tau_meas2 "Measured tendon 2 tension [N]";
  Real tau_meas3 "Measured tendon 3 tension [N]";
  Real P_meas1 "Measured section 1 heater power [W]";
  Real P_meas2 "Measured section 2 heater power [W]";
  Real P_meas3 "Measured section 3 heater power [W]";
  Real P_meas4 "Measured section 4 heater power [W]";
  Real P_meas5 "Measured section 5 heater power [W]";
  Real P_meas6 "Measured section 6 heater power [W]";
  Real T_meas1 "Measured section 1 temperature [K]";
  Real T_meas2 "Measured section 2 temperature [K]";
  Real T_meas3 "Measured section 3 temperature [K]";
  Real T_meas4 "Measured section 4 temperature [K]";
  Real T_meas5 "Measured section 5 temperature [K]";
  Real T_meas6 "Measured section 6 temperature [K]";

  // Sensors: distributed contact sensing
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

  // Sensors: object pose measurement
  Real x_obj_meas "Measured object tangential position [m]";
  Real y_obj_meas "Measured object vertical position [m]";

  // Deformation sensors
  Real theta_meas1 "Measured section 1 angle [rad]";
  Real theta_meas2 "Measured section 2 angle [rad]";
  Real theta_meas3 "Measured section 3 angle [rad]";
  Real theta_meas4 "Measured section 4 angle [rad]";
  Real theta_meas5 "Measured section 5 angle [rad]";
  Real theta_meas6 "Measured section 6 angle [rad]";

  // Bound checks
  Real actuator_ok "Actuator bounds satisfied";
  Real deformation_ok "Deformation bounds satisfied";
  Real force_band_ok "Per-contact and total force bands satisfied";
  Real no_contact_loss "No contact loss after grasp established";
  Real tracking_ok "Primary tracking error below 0.015 m after 9.1 s";

  // Bound computation intermediates
  Real max_tau_val;
  Real max_P_val;
  Real max_abs_theta_val;
  Real max_Fn_per_val;
  Real abs_th1;
  Real abs_th2;
  Real abs_th3;
  Real abs_th4;
  Real abs_th5;
  Real abs_th6;
  Real P_12;
  Real P_34;
  Real P_56;
  Real at_12;
  Real at_34;
  Real at_56;
  Real Fn_12;
  Real Fn_34;
  Real Fn_56;

equation

  // ---- Contact thresholds distributed across sections ----
  theta_ct1 = theta_0;
  theta_ct2 = theta_0 + d_theta;
  theta_ct3 = theta_0 + 2.0 * d_theta;
  theta_ct4 = theta_0 + 3.0 * d_theta;
  theta_ct5 = theta_0 + 4.0 * d_theta;
  theta_ct6 = theta_0 + 5.0 * d_theta;

  // ---- Temperature-dependent stiffness (clamped linear interpolation) ----
  EI1 = EI_min + (EI_max - EI_min) * ((T_high - T_sec1) / (T_high - T_low));
  EI2 = EI_min + (EI_max - EI_min) * ((T_high - T_sec2) / (T_high - T_low));
  EI3 = EI_min + (EI_max - EI_min) * ((T_high - T_sec3) / (T_high - T_low));
  EI4 = EI_min + (EI_max - EI_min) * ((T_high - T_sec4) / (T_high - T_low));
  EI5 = EI_min + (EI_max - EI_min) * ((T_high - T_sec5) / (T_high - T_low));
  EI6 = EI_min + (EI_max - EI_min) * ((T_high - T_sec6) / (T_high - T_low));

  // ---- Tendon moment (all sections share three tendons) ----
  M_tendon = r_tendon * (tau1 - 0.5 * tau2 - 0.5 * tau3);

  // ---- Normal contact forces (unilateral compliant) ----
  F_n1 = if k_contact * (theta1 - theta_ct1) + b_contact * theta_dot1 > 0.0 then k_contact * (theta1 - theta_ct1) + b_contact * theta_dot1 else 0.0;
  F_n2 = if k_contact * (theta2 - theta_ct2) + b_contact * theta_dot2 > 0.0 then k_contact * (theta2 - theta_ct2) + b_contact * theta_dot2 else 0.0;
  F_n3 = if k_contact * (theta3 - theta_ct3) + b_contact * theta_dot3 > 0.0 then k_contact * (theta3 - theta_ct3) + b_contact * theta_dot3 else 0.0;
  F_n4 = if k_contact * (theta4 - theta_ct4) + b_contact * theta_dot4 > 0.0 then k_contact * (theta4 - theta_ct4) + b_contact * theta_dot4 else 0.0;
  F_n5 = if k_contact * (theta5 - theta_ct5) + b_contact * theta_dot5 > 0.0 then k_contact * (theta5 - theta_ct5) + b_contact * theta_dot5 else 0.0;
  F_n6 = if k_contact * (theta6 - theta_ct6) + b_contact * theta_dot6 > 0.0 then k_contact * (theta6 - theta_ct6) + b_contact * theta_dot6 else 0.0;

  // ---- Smooth contact active indicators ----
  contact_active1 = 0.5 + 0.5 * tanh(100.0 * (theta1 - theta_ct1));
  contact_active2 = 0.5 + 0.5 * tanh(100.0 * (theta2 - theta_ct2));
  contact_active3 = 0.5 + 0.5 * tanh(100.0 * (theta3 - theta_ct3));
  contact_active4 = 0.5 + 0.5 * tanh(100.0 * (theta4 - theta_ct4));
  contact_active5 = 0.5 + 0.5 * tanh(100.0 * (theta5 - theta_ct5));
  contact_active6 = 0.5 + 0.5 * tanh(100.0 * (theta6 - theta_ct6));

  // ---- Tangential contact forces (friction-limited compliant spring) ----
  F_t1 = if -k_tang * x_obj * contact_active1 < -mu * F_n1 then -mu * F_n1 elseif -k_tang * x_obj * contact_active1 > mu * F_n1 then mu * F_n1 else -k_tang * x_obj * contact_active1;
  F_t2 = if -k_tang * x_obj * contact_active2 < -mu * F_n2 then -mu * F_n2 elseif -k_tang * x_obj * contact_active2 > mu * F_n2 then mu * F_n2 else -k_tang * x_obj * contact_active2;
  F_t3 = if -k_tang * x_obj * contact_active3 < -mu * F_n3 then -mu * F_n3 elseif -k_tang * x_obj * contact_active3 > mu * F_n3 then mu * F_n3 else -k_tang * x_obj * contact_active3;
  F_t4 = if -k_tang * x_obj * contact_active4 < -mu * F_n4 then -mu * F_n4 elseif -k_tang * x_obj * contact_active4 > mu * F_n4 then mu * F_n4 else -k_tang * x_obj * contact_active4;
  F_t5 = if -k_tang * x_obj * contact_active5 < -mu * F_n5 then -mu * F_n5 elseif -k_tang * x_obj * contact_active5 > mu * F_n5 then mu * F_n5 else -k_tang * x_obj * contact_active5;
  F_t6 = if -k_tang * x_obj * contact_active6 < -mu * F_n6 then -mu * F_n6 elseif -k_tang * x_obj * contact_active6 > mu * F_n6 then mu * F_n6 else -k_tang * x_obj * contact_active6;

  // ---- Aggregate forces ----
  F_n_total = F_n1 + F_n2 + F_n3 + F_n4 + F_n5 + F_n6;
  F_t_total = F_t1 + F_t2 + F_t3 + F_t4 + F_t5 + F_t6;

  // ---- Rigid surface interaction (unilateral compliant with friction) ----
  surface_pen = if y_obj < 0.0 then -y_obj else 0.0;
  N_surface = k_surface * surface_pen + b_surface * (if y_obj_dot < 0.0 then -y_obj_dot else 0.0);
  F_friction_surface = -mu * N_surface * tanh(x_obj_dot / v_small);

  // ---- Controlled tangential disturbance (middle third of 14 s) ----
  F_disturbance = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // ---- Section bending dynamics ----
  der(theta1) = theta_dot1;
  I_sec * der(theta_dot1) = M_tendon - EI1 * theta1 / L_sec - b_sec * theta_dot1 - F_n1 * L_sec;

  der(theta2) = theta_dot2;
  I_sec * der(theta_dot2) = M_tendon - EI2 * theta2 / L_sec - b_sec * theta_dot2 - F_n2 * L_sec;

  der(theta3) = theta_dot3;
  I_sec * der(theta_dot3) = M_tendon - EI3 * theta3 / L_sec - b_sec * theta_dot3 - F_n3 * L_sec;

  der(theta4) = theta_dot4;
  I_sec * der(theta_dot4) = M_tendon - EI4 * theta4 / L_sec - b_sec * theta_dot4 - F_n4 * L_sec;

  der(theta5) = theta_dot5;
  I_sec * der(theta_dot5) = M_tendon - EI5 * theta5 / L_sec - b_sec * theta_dot5 - F_n5 * L_sec;

  der(theta6) = theta_dot6;
  I_sec * der(theta_dot6) = M_tendon - EI6 * theta6 / L_sec - b_sec * theta_dot6 - F_n6 * L_sec;

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

  // ---- Actuator saturation (tendon <= 46 N, heater <= 18 W) ----
  tau1 = if tau_cmd1 > F_tendon_max then F_tendon_max elseif tau_cmd1 < 0.0 then 0.0 else tau_cmd1;
  tau2 = if tau_cmd2 > F_tendon_max then F_tendon_max elseif tau_cmd2 < 0.0 then 0.0 else tau_cmd2;
  tau3 = if tau_cmd3 > F_tendon_max then F_tendon_max elseif tau_cmd3 < 0.0 then 0.0 else tau_cmd3;

  P_heat1 = if P_heat_cmd1 > P_heat_max then P_heat_max elseif P_heat_cmd1 < 0.0 then 0.0 else P_heat_cmd1;
  P_heat2 = if P_heat_cmd2 > P_heat_max then P_heat_max elseif P_heat_cmd2 < 0.0 then 0.0 else P_heat_cmd2;
  P_heat3 = if P_heat_cmd3 > P_heat_max then P_heat_max elseif P_heat_cmd3 < 0.0 then 0.0 else P_heat_cmd3;
  P_heat4 = if P_heat_cmd4 > P_heat_max then P_heat_max elseif P_heat_cmd4 < 0.0 then 0.0 else P_heat_cmd4;
  P_heat5 = if P_heat_cmd5 > P_heat_max then P_heat_max elseif P_heat_cmd5 < 0.0 then 0.0 else P_heat_cmd5;
  P_heat6 = if P_heat_cmd6 > P_heat_max then P_heat_max elseif P_heat_cmd6 < 0.0 then 0.0 else P_heat_cmd6;

  // ---- Controller: force error and per-contact overload ----
  F_n_total_err = F_n_total - F_n_total_ref;

  ov1 = if F_n1 > F_n_per_max then F_n1 - F_n_per_max else 0.0;
  ov2 = if F_n2 > F_n_per_max then F_n2 - F_n_per_max else 0.0;
  ov3 = if F_n3 > F_n_per_max then F_n3 - F_n_per_max else 0.0;
  ov4 = if F_n4 > F_n_per_max then F_n4 - F_n_per_max else 0.0;
  ov5 = if F_n5 > F_n_per_max then F_n5 - F_n_per_max else 0.0;
  ov6 = if F_n6 > F_n_per_max then F_n6 - F_n_per_max else 0.0;
  F_n_overload_total = ov1 + ov2 + ov3 + ov4 + ov5 + ov6;

  // ---- Tendon commands: pre-tension + feedforward + force regulation + redistribution ----
  tau_cmd1 = tau_base + delta_tau_ff - Kp_force * F_n_total_err + Kp_dist * F_disturbance - Kp_redist * F_n_overload_total;
  tau_cmd2 = tau_base - 0.5 * delta_tau_ff + 0.5 * Kp_force * F_n_total_err - 0.5 * Kp_dist * F_disturbance + 0.5 * Kp_redist * F_n_overload_total;
  tau_cmd3 = tau_base - 0.5 * delta_tau_ff + 0.5 * Kp_force * F_n_total_err - 0.5 * Kp_dist * F_disturbance + 0.5 * Kp_redist * F_n_overload_total;

  // ---- Heater commands: full power during soften phase, off thereafter ----
  P_heat_cmd1 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd2 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd3 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd4 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd5 = if time < t_soft then P_heat_max else 0.0;
  P_heat_cmd6 = if time < t_soft then P_heat_max else 0.0;

  // ---- Control phase indicator ----
  phase = if time < t_soft then 0.0 elseif time < t_stiff then 1.0 else 2.0;

  // ---- Primary tracking error (object displacement) ----
  theta_track_err = abs(x_obj);

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

  // ---- Bound computations (explicit scalar if-then-else, no array reduction) ----
  max_tau_val = if tau1 > tau2 then (if tau1 > tau3 then tau1 else tau3) else (if tau2 > tau3 then tau2 else tau3);

  P_12 = if P_heat1 > P_heat2 then P_heat1 else P_heat2;
  P_34 = if P_heat3 > P_heat4 then P_heat3 else P_heat4;
  P_56 = if P_heat5 > P_heat6 then P_heat5 else P_heat6;
  max_P_val = if P_12 > P_34 then (if P_12 > P_56 then P_12 else P_56) else (if P_34 > P_56 then P_34 else P_56);

  abs_th1 = if theta1 < 0.0 then -theta1 else theta1;
  abs_th2 = if theta2 < 0.0 then -theta2 else theta2;
  abs_th3 = if theta3 < 0.0 then -theta3 else theta3;
  abs_th4 = if theta4 < 0.0 then -theta4 else theta4;
  abs_th5 = if theta5 < 0.0 then -theta5 else theta5;
  abs_th6 = if theta6 < 0.0 then -theta6 else theta6;
  at_12 = if abs_th1 > abs_th2 then abs_th1 else abs_th2;
  at_34 = if abs_th3 > abs_th4 then abs_th3 else abs_th4;
  at_56 = if abs_th5 > abs_th6 then abs_th5 else abs_th6;
  max_abs_theta_val = if at_12 > at_34 then (if at_12 > at_56 then at_12 else at_56) else (if at_34 > at_56 then at_34 else at_56);

  Fn_12 = if F_n1 > F_n2 then F_n1 else F_n2;
  Fn_34 = if F_n3 > F_n4 then F_n3 else F_n4;
  Fn_56 = if F_n5 > F_n6 then F_n5 else F_n6;
  max_Fn_per_val = if Fn_12 > Fn_34 then (if Fn_12 > Fn_56 then Fn_12 else Fn_56) else (if Fn_34 > Fn_56 then Fn_34 else Fn_56);

  // ---- Bound checks ----
  actuator_ok = if (max_tau_val <= F_tendon_max + 1.0e-6) and (max_P_val <= P_heat_max + 1.0e-6) then 1.0 else 0.0;
  deformation_ok = if max_abs_theta_val <= theta_max_bound then 1.0 else 0.0;
  force_band_ok = if ((F_n_total >= F_n_total_min) and (F_n_total <= F_n_total_max) and (max_Fn_per_val <= F_n_per_max + 1.0e-6)) or (time < t_stiff) then 1.0 else 0.0;
  no_contact_loss = if (F_n_total > 0.0) or (time < t_stiff) then 1.0 else 0.0;
  tracking_ok = if (theta_track_err < 0.015) or (time < 9.1) then 1.0 else 0.0;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005));
end ShapeLockGraspD;