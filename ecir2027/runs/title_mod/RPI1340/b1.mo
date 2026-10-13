model TendonSoftAvoidB
  "Soft continuum arm navigating around a fixed obstacle with bounded contact and stiffness scheduling"

  // ===== Physical Parameters =====
  parameter Real L_body = 0.55 "Body length [m]";
  parameter Real L_seg = L_body / 6.0 "Section length [m]";
  parameter Real body_r = 0.02 "Body cross-section radius [m] - assumed";
  parameter Real r_tendon = 0.018 "Tendon moment arm [m] - assumed";
  parameter Real T_max = 34.4 "Max tendon tension command [N]";
  parameter Real T_min = 0.0 "Min tendon tension [N]";
  parameter Real F_preload_nom = 12.0 "Nominal tendon preload [N] - assumed";
  parameter Real mu_obstacle = 0.55 "Obstacle friction coefficient [dimensionless]";

  // ===== Obstacle =====
  parameter Real obs_x = 0.25 "Obstacle center x [m] - assumed";
  parameter Real obs_y = 0.08 "Obstacle center y [m] - assumed";
  parameter Real obs_r = 0.03 "Obstacle radius [m] - assumed";

  // ===== Target =====
  parameter Real x_target = 0.50 "Target x [m] - assumed";
  parameter Real y_target = 0.15 "Target y [m] - assumed";

  // ===== Section Dynamics =====
  parameter Real J_sec = 0.002 "Section bending inertia [kg.m^2] - assumed";
  parameter Real k_sec_base = 0.5 "Base section stiffness [N.m/rad] - assumed";
  parameter Real c_sec = 0.20 "Section damping [N.m.s/rad] - assumed";

  // ===== Contact =====
  parameter Real k_contact = 5000.0 "Contact stiffness [N/m] - assumed";

  // ===== Disturbance =====
  parameter Real F_dist = 5.6 "Lateral tip disturbance magnitude [N]";
  parameter Real t_dist_start = 10.0 / 3.0 "Disturbance start [s]";
  parameter Real t_dist_end = 20.0 / 3.0 "Disturbance end [s]";
  parameter Real t_dist_ramp = 0.05 "Disturbance ramp time [s] - assumed";

  // ===== Controller =====
  parameter Real Kp_tip = 70.0 "Tip proportional gain [N/m] - assumed";
  parameter Real Kd_tip = 3.0 "Tip derivative gain [N.s/m] - assumed";
  parameter Real K_int = 0.5 "Integral gain [N/(m.s)] - assumed";
  parameter Real tau_int = 100.0 "Integral leak time constant [s] - assumed";
  parameter Real k_stiff_min = 1.0 "Min stiffness multiplier - assumed";
  parameter Real k_stiff_max = 8.0 "Max stiffness multiplier - assumed";

  // ===== Thermal =====
  parameter Real T_ambient = 293.15 "Ambient temperature [K] - assumed";
  parameter Real C_thermal = 100.0 "Thermal capacitance [J/K] - assumed";
  parameter Real R_thermal = 2.0 "Thermal resistance [K/W] - assumed";

  // ===== Bounds =====
  parameter Real bound_actuator = 34.4 "Actuator bound [N]";
  parameter Real bound_deformation = 10.0 "Deformation bound [rad/m] - assumed";
  parameter Real bound_contact = 100.0 "Contact force bound [N] - assumed";
  parameter Real bound_temperature = 350.0 "Temperature bound [K] - assumed";
  parameter Real bound_tip_error = 0.048 "Required tip error [m]";
  parameter Real t_settling = 6.5 "Settling time [s]";

  // ===== Curvature States =====
  Real kappa1 "Section 1 curvature [rad/m]";
  Real kappa2 "Section 2 curvature [rad/m]";
  Real kappa3 "Section 3 curvature [rad/m]";
  Real kappa4 "Section 4 curvature [rad/m]";
  Real kappa5 "Section 5 curvature [rad/m]";
  Real kappa6 "Section 6 curvature [rad/m]";
  Real kd1 "Section 1 curvature rate [rad/(m.s)]";
  Real kd2 "Section 2 curvature rate [rad/(m.s)]";
  Real kd3 "Section 3 curvature rate [rad/(m.s)]";
  Real kd4 "Section 4 curvature rate [rad/(m.s)]";
  Real kd5 "Section 5 curvature rate [rad/(m.s)]";
  Real kd6 "Section 6 curvature rate [rad/(m.s)]";

  // ===== Tendon Measurements =====
  Real Tm1 "Measured tendon 1 tension [N]";
  Real Tm2 "Measured tendon 2 tension [N]";
  Real Tm3 "Measured tendon 3 tension [N]";

  // ===== Integral and Thermal =====
  Real e_int "Integral of tip y-error with leak [m.s]";
  Real temp_est "Estimated actuator temperature [K]";

  // ===== Kinematics =====
  Real th2 "Node 2 tangent angle [rad]";
  Real th3 "Node 3 tangent angle [rad]";
  Real th4 "Node 4 tangent angle [rad]";
  Real th5 "Node 5 tangent angle [rad]";
  Real th6 "Node 6 tangent angle [rad]";
  Real th7 "Node 7 tangent angle [rad]";
  Real x2 "Node 2 x [m]";
  Real x3 "Node 3 x [m]";
  Real x4 "Node 4 x [m]";
  Real x5 "Node 5 x [m]";
  Real x6 "Node 6 x [m]";
  Real x7 "Node 7 x [m]";
  Real y2 "Node 2 y [m]";
  Real y3 "Node 3 y [m]";
  Real y4 "Node 4 y [m]";
  Real y5 "Node 5 y [m]";
  Real y6 "Node 6 y [m]";
  Real y7 "Node 7 y [m]";
  Real x_tip "Tip x [m]";
  Real y_tip "Tip y [m]";

  // ===== Contact =====
  Real dist1 "Section 1 obstacle distance [m]";
  Real dist2 "Section 2 obstacle distance [m]";
  Real dist3 "Section 3 obstacle distance [m]";
  Real dist4 "Section 4 obstacle distance [m]";
  Real dist5 "Section 5 obstacle distance [m]";
  Real dist6 "Section 6 obstacle distance [m]";
  Real clr1 "Section 1 clearance [m]";
  Real clr2 "Section 2 clearance [m]";
  Real clr3 "Section 3 clearance [m]";
  Real clr4 "Section 4 clearance [m]";
  Real clr5 "Section 5 clearance [m]";
  Real clr6 "Section 6 clearance [m]";
  Real Fn1 "Section 1 normal contact force [N]";
  Real Fn2 "Section 2 normal contact force [N]";
  Real Fn3 "Section 3 normal contact force [N]";
  Real Fn4 "Section 4 normal contact force [N]";
  Real Fn5 "Section 5 normal contact force [N]";
  Real Fn6 "Section 6 normal contact force [N]";
  Real vt1 "Section 1 tangential velocity proxy [m/s]";
  Real vt2 "Section 2 tangential velocity proxy [m/s]";
  Real vt3 "Section 3 tangential velocity proxy [m/s]";
  Real vt4 "Section 4 tangential velocity proxy [m/s]";
  Real vt5 "Section 5 tangential velocity proxy [m/s]";
  Real vt6 "Section 6 tangential velocity proxy [m/s]";
  Real Fcx1 "Section 1 contact force x [N]";
  Real Fcx2 "Section 2 contact force x [N]";
  Real Fcx3 "Section 3 contact force x [N]";
  Real Fcx4 "Section 4 contact force x [N]";
  Real Fcx5 "Section 5 contact force x [N]";
  Real Fcx6 "Section 6 contact force x [N]";
  Real Fcy1 "Section 1 contact force y [N]";
  Real Fcy2 "Section 2 contact force y [N]";
  Real Fcy3 "Section 3 contact force y [N]";
  Real Fcy4 "Section 4 contact force y [N]";
  Real Fcy5 "Section 5 contact force y [N]";
  Real Fcy6 "Section 6 contact force y [N]";
  Real Mc1 "Section 1 contact moment [N.m]";
  Real Mc2 "Section 2 contact moment [N.m]";
  Real Mc3 "Section 3 contact moment [N.m]";
  Real Mc4 "Section 4 contact moment [N.m]";
  Real Mc5 "Section 5 contact moment [N.m]";
  Real Mc6 "Section 6 contact moment [N.m]";

  // ===== Disturbance =====
  Real F_lateral "Lateral tip load [N]";
  Real Md1 "Section 1 disturbance moment [N.m]";
  Real Md2 "Section 2 disturbance moment [N.m]";
  Real Md3 "Section 3 disturbance moment [N.m]";
  Real Md4 "Section 4 disturbance moment [N.m]";
  Real Md5 "Section 5 disturbance moment [N.m]";
  Real Md6 "Section 6 disturbance moment [N.m]";

  // ===== Actuator =====
  Real Tc1 "Commanded tendon 1 tension [N]";
  Real Tc2 "Commanded tendon 2 tension [N]";
  Real Tc3 "Commanded tendon 3 tension [N]";
  Real Tr1 "Raw tendon 1 tension [N]";
  Real Tr2 "Raw tendon 2 tension [N]";
  Real Tr3 "Raw tendon 3 tension [N]";
  Real M_tendon "Tendon bending moment [N.m]";

  // ===== Controller =====
  Real e_x "Tip x-error [m]";
  Real e_y "Tip y-error [m]";
  Real tip_error "Euclidean tip error [m]";
  Real tip_vel_est "Estimated tip y-velocity [m/s]";
  Real M_des "Desired bending moment [N.m]";
  Real F_preload "Tendon preload [N]";
  Real k_sched "Scheduled stiffness multiplier";
  Real k_eff "Effective section stiffness [N.m/rad]";
  Real prox_factor "Contact proximity factor";
  Real conv_factor "Convergence factor";
  Real smax "Smooth max of prox and conv";
  Real clr_min_12 "Min clearance sections 1-2 [m]";
  Real clr_min_34 "Min clearance sections 3-4 [m]";
  Real clr_min_56 "Min clearance sections 5-6 [m]";
  Real clr_min_1234 "Min clearance sections 1-4 [m]";
  Real clearance_min "Minimum clearance all sections [m]";

  // ===== Sensors =====
  Real actuator_norm "Actuator command norm [N]";
  Real deformation_norm "Deformation norm [rad/m]";
  Real contact_force_norm "Contact force norm [N]";
  Real power_dissip "Power dissipation [W]";

  // ===== Bound Flags =====
  Boolean b_act "Actuator bound OK";
  Boolean b_def "Deformation bound OK";
  Boolean b_con "Contact force bound OK";
  Boolean b_tmp "Temperature bound OK";
  Boolean b_clr "Clearance bound OK";
  Boolean b_tip "Tip error bound OK";

equation
  // ===== Forward Kinematics (6 constant-curvature sections) =====
  th2 = kappa1 * L_seg;
  x2 = L_seg * cos(0.5 * kappa1 * L_seg);
  y2 = L_seg * sin(0.5 * kappa1 * L_seg);

  th3 = th2 + kappa2 * L_seg;
  x3 = x2 + L_seg * cos(th2 + 0.5 * kappa2 * L_seg);
  y3 = y2 + L_seg * sin(th2 + 0.5 * kappa2 * L_seg);

  th4 = th3 + kappa3 * L_seg;
  x4 = x3 + L_seg * cos(th3 + 0.5 * kappa3 * L_seg);
  y4 = y3 + L_seg * sin(th3 + 0.5 * kappa3 * L_seg);

  th5 = th4 + kappa4 * L_seg;
  x5 = x4 + L_seg * cos(th4 + 0.5 * kappa4 * L_seg);
  y5 = y4 + L_seg * sin(th4 + 0.5 * kappa4 * L_seg);

  th6 = th5 + kappa5 * L_seg;
  x6 = x5 + L_seg * cos(th5 + 0.5 * kappa5 * L_seg);
  y6 = y5 + L_seg * sin(th5 + 0.5 * kappa5 * L_seg);

  th7 = th6 + kappa6 * L_seg;
  x7 = x6 + L_seg * cos(th6 + 0.5 * kappa6 * L_seg);
  y7 = y6 + L_seg * sin(th6 + 0.5 * kappa6 * L_seg);

  x_tip = x7;
  y_tip = y7;

  // ===== Contact Model (penalty + Coulomb friction) =====
  // Section 1: node1 = (0, 0)
  dist1 = sqrt((0.5*x2 - obs_x)*(0.5*x2 - obs_x) + (0.5*y2 - obs_y)*(0.5*y2 - obs_y) + 1e-12);
  clr1 = dist1 - obs_r - body_r;
  Fn1 = k_contact * 0.5 * (sqrt(clr1*clr1 + 1e-10) - clr1);
  vt1 = kd1 * L_seg;
  Fcx1 = (Fn1 / (dist1 + 1e-12)) * ((0.5*x2 - obs_x) + mu_obstacle * (0.5*y2 - obs_y) * tanh(vt1 / 0.001));
  Fcy1 = (Fn1 / (dist1 + 1e-12)) * ((0.5*y2 - obs_y) - mu_obstacle * (0.5*x2 - obs_x) * tanh(vt1 / 0.001));
  Mc1 = 0.5 * x2 * Fcy1 - 0.5 * y2 * Fcx1;

  // Section 2
  dist2 = sqrt((0.5*(x2+x3) - obs_x)*(0.5*(x2+x3) - obs_x) + (0.5*(y2+y3) - obs_y)*(0.5*(y2+y3) - obs_y) + 1e-12);
  clr2 = dist2 - obs_r - body_r;
  Fn2 = k_contact * 0.5 * (sqrt(clr2*clr2 + 1e-10) - clr2);
  vt2 = kd2 * L_seg;
  Fcx2 = (Fn2 / (dist2 + 1e-12)) * ((0.5*(x2+x3) - obs_x) + mu_obstacle * (0.5*(y2+y3) - obs_y) * tanh(vt2 / 0.001));
  Fcy2 = (Fn2 / (dist2 + 1e-12)) * ((0.5*(y2+y3) - obs_y) - mu_obstacle * (0.5*(x2+x3) - obs_x) * tanh(vt2 / 0.001));
  Mc2 = 0.5 * (x3 - x2) * Fcy2 - 0.5 * (y3 - y2) * Fcx2;

  // Section 3
  dist3 = sqrt((0.5*(x3+x4) - obs_x)*(0.5*(x3+x4) - obs_x) + (0.5*(y3+y4) - obs_y)*(0.5*(y3+y4) - obs_y) + 1e-12);
  clr3 = dist3 - obs_r - body_r;
  Fn3 = k_contact * 0.5 * (sqrt(clr3*clr3 + 1e-10) - clr3);
  vt3 = kd3 * L_seg;
  Fcx3 = (Fn3 / (dist3 + 1e-12)) * ((0.5*(x3+x4) - obs_x) + mu_obstacle * (0.5*(y3+y4) - obs_y) * tanh(vt3 / 0.001));
  Fcy3 = (Fn3 / (dist3 + 1e-12)) * ((0.5*(y3+y4) - obs_y) - mu_obstacle * (0.5*(x3+x4) - obs_x) * tanh(vt3 / 0.001));
  Mc3 = 0.5 * (x4 - x3) * Fcy3 - 0.5 * (y4 - y3) * Fcx3;

  // Section 4
  dist4 = sqrt((0.5*(x4+x5) - obs_x)*(0.5*(x4+x5) - obs_x) + (0.5*(y4+y5) - obs_y)*(0.5*(y4+y5) - obs_y) + 1e-12);
  clr4 = dist4 - obs_r - body_r;
  Fn4 = k_contact * 0.5 * (sqrt(clr4*clr4 + 1e-10) - clr4);
  vt4 = kd4 * L_seg;
  Fcx4 = (Fn4 / (dist4 + 1e-12)) * ((0.5*(x4+x5) - obs_x) + mu_obstacle * (0.5*(y4+y5) - obs_y) * tanh(vt4 / 0.001));
  Fcy4 = (Fn4 / (dist4 + 1e-12)) * ((0.5*(y4+y5) - obs_y) - mu_obstacle * (0.5*(x4+x5) - obs_x) * tanh(vt4 / 0.001));
  Mc4 = 0.5 * (x5 - x4) * Fcy4 - 0.5 * (y5 - y4) * Fcx4;

  // Section 5
  dist5 = sqrt((0.5*(x5+x6) - obs_x)*(0.5*(x5+x6) - obs_x) + (0.5*(y5+y6) - obs_y)*(0.5*(y5+y6) - obs_y) + 1e-12);
  clr5 = dist5 - obs_r - body_r;
  Fn5 = k_contact * 0.5 * (sqrt(clr5*clr5 + 1e-10) - clr5);
  vt5 = kd5 * L_seg;
  Fcx5 = (Fn5 / (dist5 + 1e-12)) * ((0.5*(x5+x6) - obs_x) + mu_obstacle * (0.5*(y5+y6) - obs_y) * tanh(vt5 / 0.001));
  Fcy5 = (Fn5 / (dist5 + 1e-12)) * ((0.5*(y5+y6) - obs_y) - mu_obstacle * (0.5*(x5+x6) - obs_x) * tanh(vt5 / 0.001));
  Mc5 = 0.5 * (x6 - x5) * Fcy5 - 0.5 * (y6 - y5) * Fcx5;

  // Section 6
  dist6 = sqrt((0.5*(x6+x7) - obs_x)*(0.5*(x6+x7) - obs_x) + (0.5*(y6+y7) - obs_y)*(0.5*(y6+y7) - obs_y) + 1e-12);
  clr6 = dist6 - obs_r - body_r;
  Fn6 = k_contact * 0.5 * (sqrt(clr6*clr6 + 1e-10) - clr6);
  vt6 = kd6 * L_seg;
  Fcx6 = (Fn6 / (dist6 + 1e-12)) * ((0.5*(x6+x7) - obs_x) + mu_obstacle * (0.5*(y6+y7) - obs_y) * tanh(vt6 / 0.001));
  Fcy6 = (Fn6 / (dist6 + 1e-12)) * ((0.5*(y6+y7) - obs_y) - mu_obstacle * (0.5*(x6+x7) - obs_x) * tanh(vt6 / 0.001));
  Mc6 = 0.5 * (x7 - x6) * Fcy6 - 0.5 * (y7 - y6) * Fcx6;

  // ===== Disturbance (smooth pulse in -y during middle third) =====
  F_lateral = -F_dist
              * 0.5 * (1.0 + tanh((time - t_dist_start) / t_dist_ramp))
              * 0.5 * (1.0 - tanh((time - t_dist_end) / t_dist_ramp));

  Md1 = F_lateral * (x_tip - 0.0);
  Md2 = F_lateral * (x_tip - x2);
  Md3 = F_lateral * (x_tip - x3);
  Md4 = F_lateral * (x_tip - x4);
  Md5 = F_lateral * (x_tip - x5);
  Md6 = F_lateral * (x_tip - x6);

  // ===== Tendon-to-Moment Mapping =====
  M_tendon = r_tendon * 0.8660254 * (Tm2 - Tm3);

  // ===== Stiffness Scheduling =====
  clr_min_12 = if clr1 < clr2 then clr1 else clr2;
  clr_min_34 = if clr3 < clr4 then clr3 else clr4;
  clr_min_56 = if clr5 < clr6 then clr5 else clr6;
  clr_min_1234 = if clr_min_12 < clr_min_34 then clr_min_12 else clr_min_34;
  clearance_min = if clr_min_1234 < clr_min_56 then clr_min_1234 else clr_min_56;

  prox_factor = 0.5 * (1.0 + tanh(50.0 * (0.002 - clearance_min)));
  conv_factor = 0.5 * (1.0 + tanh(50.0 * (0.04 - tip_error)));
  smax = 0.5 * (prox_factor + conv_factor + sqrt((prox_factor - conv_factor)*(prox_factor - conv_factor) + 1e-8));
  k_sched = k_stiff_min + (k_stiff_max - k_stiff_min) * smax;
  k_eff = k_sec_base * k_sched;

  // ===== Section Dynamics =====
  J_sec * der(kd1) = M_tendon + Mc1 + Md1 - k_eff * kappa1 - c_sec * kd1;
  J_sec * der(kd2) = M_tendon + Mc2 + Md2 - k_eff * kappa2 - c_sec * kd2;
  J_sec * der(kd3) = M_tendon + Mc3 + Md3 - k_eff * kappa3 - c_sec * kd3;
  J_sec * der(kd4) = M_tendon + Mc4 + Md4 - k_eff * kappa4 - c_sec * kd4;
  J_sec * der(kd5) = M_tendon + Mc5 + Md5 - k_eff * kappa5 - c_sec * kd5;
  J_sec * der(kd6) = M_tendon + Mc6 + Md6 - k_eff * kappa6 - c_sec * kd6;

  der(kappa1) = kd1;
  der(kappa2) = kd2;
  der(kappa3) = kd3;
  der(kappa4) = kd4;
  der(kappa5) = kd5;
  der(kappa6) = kd6;

  // ===== Tendon Measurement Filter (first-order, tau = 10 ms) =====
  der(Tm1) = (Tc1 - Tm1) / 0.01;
  der(Tm2) = (Tc2 - Tm2) / 0.01;
  der(Tm3) = (Tc3 - Tm3) / 0.01;

  // ===== Contact-Aware Shape Controller =====
  e_x = x_target - x_tip;
  e_y = y_target - y_tip;
  tip_error = sqrt(e_x*e_x + e_y*e_y + 1e-12);

  tip_vel_est = L_seg * L_seg * (5.5 * kd1 + 4.5 * kd2 + 3.5 * kd3 + 2.5 * kd4 + 1.5 * kd5 + 0.5 * kd6);

  der(e_int) = e_y - e_int / tau_int;

  M_des = Kp_tip * e_y + K_int * e_int - Kd_tip * tip_vel_est;

  F_preload = if (F_preload_nom + 2.0 * abs(M_des) / r_tendon) < (3.0 * T_max)
              then (F_preload_nom + 2.0 * abs(M_des) / r_tendon)
              else (3.0 * T_max);

  Tr1 = F_preload / 3.0;
  Tr2 = F_preload / 3.0 + M_des / (r_tendon * 1.7320508);
  Tr3 = F_preload / 3.0 - M_des / (r_tendon * 1.7320508);

  Tc1 = if Tr1 > T_max then T_max else if Tr1 < T_min then T_min else Tr1;
  Tc2 = if Tr2 > T_max then T_max else if Tr2 < T_min then T_min else Tr2;
  Tc3 = if Tr3 > T_max then T_max else if Tr3 < T_min then T_min else Tr3;

  // ===== Sensor Aggregation =====
  actuator_norm = sqrt(Tc1*Tc1 + Tc2*Tc2 + Tc3*Tc3 + 1e-12);
  deformation_norm = sqrt(kappa1*kappa1 + kappa2*kappa2 + kappa3*kappa3 + kappa4*kappa4 + kappa5*kappa5 + kappa6*kappa6 + 1e-12);
  contact_force_norm = sqrt(Fn1*Fn1 + Fn2*Fn2 + Fn3*Fn3 + Fn4*Fn4 + Fn5*Fn5 + Fn6*Fn6 + 1e-12);

  power_dissip = c_sec * (kd1*kd1 + kd2*kd2 + kd3*kd3 + kd4*kd4 + kd5*kd5 + kd6*kd6);
  C_thermal * der(temp_est) = power_dissip - (temp_est - T_ambient) / R_thermal;

  // ===== Bound Checks =====
  b_act = actuator_norm <= bound_actuator * 1.7320508 + 1e-6;
  b_def = deformation_norm <= bound_deformation;
  b_con = contact_force_norm <= bound_contact;
  b_tmp = temp_est <= bound_temperature;
  b_clr = clearance_min >= -0.005;
  b_tip = (time < t_settling) or (tip_error <= bound_tip_error);

  assert(b_act, "Actuator bound exceeded", AssertionLevel.warning);
  assert(b_def, "Deformation bound exceeded", AssertionLevel.warning);
  assert(b_con, "Contact force bound exceeded", AssertionLevel.warning);
  assert(b_tmp, "Temperature bound exceeded", AssertionLevel.warning);
  assert(b_clr, "Clearance bound exceeded", AssertionLevel.warning);
  assert(b_tip, "Tip error bound exceeded after settling time", AssertionLevel.warning);

initial equation
  kappa1 = 0.0;
  kappa2 = 0.0;
  kappa3 = 0.0;
  kappa4 = 0.0;
  kappa5 = 0.0;
  kappa6 = 0.0;
  kd1 = 0.0;
  kd2 = 0.0;
  kd3 = 0.0;
  kd4 = 0.0;
  kd5 = 0.0;
  kd6 = 0.0;
  Tm1 = F_preload_nom / 3.0;
  Tm2 = F_preload_nom / 3.0;
  Tm3 = F_preload_nom / 3.0;
  e_int = 0.0;
  temp_est = T_ambient;

  annotation(
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "TendonSoftAvoidB: 6-section continuum soft arm (0.55 m) with 3 tendons at 120 deg "
      "spacing navigating around a fixed cylinder obstacle (friction coeff 0.55). Contact-aware shape control "
      "with bounded stiffness scheduling. 5.6 N lateral tip disturbance during middle third of 10 s mission at "
      "100 Hz. Measures actuator state (Tm1-3), distributed contact force (Fn1-6, Fcx1-6, Fcy1-6), "
      "section deformation (kappa1-6), and tip pose (x_tip, y_tip). Synchronized state, command, and sensor "
      "traces retained. Parameters not stated in the requirement are assumed and labeled as such.")
  );
end TendonSoftAvoidB;