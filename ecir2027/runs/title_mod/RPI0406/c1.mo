model CartesianToolPolishD
  "Instrumented contact-rich Cartesian polishing system with curved workpiece";

  // === Physical parameters ===
  parameter Real m_tool = 2.5 "Tool carriage mass [kg]";
  parameter Real x_min = -0.10 "X travel min [m]";
  parameter Real x_max = 0.10 "X travel max [m]";
  parameter Real y_min = -0.10 "Y travel min [m]";
  parameter Real y_max = 0.10 "Y travel max [m]";
  parameter Real z_min = -0.30 "Z travel min [m]";
  parameter Real z_max = 0.30 "Z travel max [m]";
  parameter Real F_max = 350.0 "Max actuator force per axis [N]";
  parameter Real mu = 0.50 "Friction coefficient [1]";
  parameter Real k_contact = 5000.0 "Normal contact stiffness [N/m]";
  parameter Real d_contact = 50.0 "Normal contact damping [N.s/m]";
  parameter Real A_surf = 0.06 "Surface curve amplitude [m]";
  parameter Real L_surf = 0.50 "Surface period [m]";
  parameter Real L_path = 0.50 "Nominal path length [m]";

  // === Controller parameters ===
  parameter Real F_normal_setpoint = 20.0 "Desired normal force [N]";
  parameter Real kp_pos = 400.0 "Position proportional gain [1/s^2]";
  parameter Real kd_pos = 40.0 "Position derivative gain [1/s]";
  parameter Real ki_force = 0.001 "Force integral gain [m/(N.s)]";
  parameter Real delta_n_0 = 0.004 "Initial normal penetration offset [m]";
  parameter Real delta_n_max = 0.015 "Max normal offset [m]";
  parameter Real v_thresh = 0.001 "Friction smoothing threshold [m/s]";

  // === Simulation / trajectory parameters ===
  parameter Real T_sim = 14.0 "Simulation duration [s]";
  parameter Real F_dist = 7.0 "Disturbance force magnitude [N]";
  parameter Real t_acc = 2.0 "Trajectory acceleration time [s]";
  parameter Real t_cruise = 10.0 "Trajectory cruise time [s]";
  parameter Real v_cruise = L_path / (t_cruise + t_acc) "Cruise velocity [m/s]";
  parameter Real a_acc = v_cruise / t_acc "Trajectory acceleration [m/s^2]";

  // === Dynamic states ===
  Real x(start = -0.004, fixed = true) "Tool X position [m]";
  Real y(start = 0.0, fixed = true) "Tool Y position [m]";
  Real z(start = -0.25, fixed = true) "Tool Z position [m]";
  Real vx(start = 0.0, fixed = true) "Tool X velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "Tool Y velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "Tool Z velocity [m/s]";
  Real force_integral(start = 0.0, fixed = true) "Force error integral [N.s]";

  // === Actuator commands (bounded) ===
  Real Fx_cmd "X force command [N]";
  Real Fy_cmd "Y force command [N]";
  Real Fz_cmd "Z force command [N]";
  Real Fx_act "X actual (saturated) force [N]";
  Real Fy_act "Y actual (saturated) force [N]";
  Real Fz_act "Z actual (saturated) force [N]";

  // === Contact model ===
  Real x_surf "Surface X at current z [m]";
  Real dx_dz "Surface slope dx/dz";
  Real n_norm "Normal vector norm";
  Real n_x "Outward normal X component";
  Real n_z "Outward normal Z component";
  Real t_x "Tangent X component";
  Real t_z "Tangent Z component";
  Real penetration "Contact penetration depth [m]";
  Real v_normal "Normal approach velocity (positive=approaching) [m/s]";
  Real v_tangent "Tangential velocity [m/s]";
  Real F_normal "Normal contact force on tool [N]";
  Real smooth_sgn "Smoothed sign of tangential velocity";
  Real F_fric_x "Friction force X [N]";
  Real F_fric_z "Friction force Z [N]";
  Real F_contact_x "Total contact force X [N]";
  Real F_contact_y "Total contact force Y [N]";
  Real F_contact_z "Total contact force Z [N]";

  // === Disturbance ===
  Real F_dist_t "Disturbance tangential force [N]";
  Real F_dist_x "Disturbance X component [N]";
  Real F_dist_z "Disturbance Z component [N]";

  // === Reference trajectory ===
  Real s_ref "Path parameter [m]";
  Real s_ref_dot "Path velocity [m/s]";
  Real z_ref "Reference Z [m]";
  Real x_ref "Reference X [m]";
  Real z_ref_dot "Reference Z velocity [m/s]";
  Real x_ref_dot "Reference X velocity [m/s]";
  Real dx_dz_ref "Surface slope at reference";
  Real n_norm_ref "Normal norm at reference";
  Real n_x_ref "Normal X at reference";
  Real n_z_ref "Normal Z at reference";

  // === Controller internals ===
  Real force_err "Force error [N]";
  Real delta_n "Normal offset (unclamped) [m]";
  Real delta_n_clamped "Normal offset (clamped) [m]";
  Real x_des "Desired X [m]";
  Real z_des "Desired Z [m]";
  Real vx_des "Desired X velocity [m/s]";
  Real vz_des "Desired Z velocity [m/s]";

  // === Sensors ===
  Real enc_x "Joint encoder X [m]";
  Real enc_y "Joint encoder Y [m]";
  Real enc_z "Joint encoder Z [m]";
  Real wrench_fx "Wrist wrench X [N]";
  Real wrench_fy "Wrist wrench Y [N]";
  Real wrench_fz "Wrist wrench Z [N]";
  Real pose_x "Tool-tip pose X [m]";
  Real pose_y "Tool-tip pose Y [m]";
  Real pose_z "Tool-tip pose Z [m]";
  Real F_normal_meas "Measured normal force [N]";

  // === Metrics / monitoring ===
  Real path_error "Path tracking error [m]";
  Real tracking_error "Primary tracking error [m]";
  Boolean in_contact "Contact flag";
  Boolean joint_bounds_ok "Joint bounds satisfied";
  Boolean effort_bounds_ok "Effort bounds satisfied";
  Boolean force_range_ok "Force in [12, 30] N";
  Boolean continuous_contact_ok "Continuous contact maintained";

protected
  constant Real pi = 3.141592653589793;
  constant Real eps = 1.0e-9;

equation
  // === Surface geometry at current tool position ===
  // Surface: x = A_surf * sin(2*pi*z / L_surf), extruded along Y
  x_surf = A_surf * sin(2.0 * pi * z / L_surf);
  dx_dz = A_surf * (2.0 * pi / L_surf) * cos(2.0 * pi * z / L_surf);
  n_norm = sqrt(1.0 + dx_dz * dx_dz + eps);
  n_x = 1.0 / n_norm;
  n_z = -dx_dz / n_norm;
  t_x = dx_dz / n_norm;
  t_z = 1.0 / n_norm;

  // === Compliant normal contact ===
  penetration = x_surf - x;
  v_normal = -(vx * n_x + vz * n_z);
  v_tangent = vx * t_x + vz * t_z;
  F_normal = if penetration > 0.0 then
    k_contact * penetration + d_contact * v_normal
  else
    0.0;

  // === Coulomb friction (smoothed) ===
  smooth_sgn = tanh(v_tangent / v_thresh);
  F_fric_x = -mu * F_normal * t_x * smooth_sgn;
  F_fric_z = -mu * F_normal * t_z * smooth_sgn;
  F_contact_x = F_normal * n_x + F_fric_x;
  F_contact_y = 0.0;
  F_contact_z = F_normal * n_z + F_fric_z;

  // === Disturbance: 7 N tangential during middle third ===
  F_dist_t = if (time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0) then
    F_dist
  else
    0.0;
  F_dist_x = F_dist_t * t_x;
  F_dist_z = F_dist_t * t_z;

  // === Trapezoidal reference trajectory ===
  if time < t_acc then
    s_ref = 0.5 * a_acc * time * time;
    s_ref_dot = a_acc * time;
  elseif time < t_acc + t_cruise then
    s_ref = 0.5 * a_acc * t_acc * t_acc + v_cruise * (time - t_acc);
    s_ref_dot = v_cruise;
  elseif time < T_sim then
    s_ref = 0.5 * a_acc * t_acc * t_acc
            + v_cruise * t_cruise
            + v_cruise * (time - t_acc - t_cruise)
            - 0.5 * a_acc * (time - t_acc - t_cruise) * (time - t_acc - t_cruise);
    s_ref_dot = v_cruise - a_acc * (time - t_acc - t_cruise);
  else
    s_ref = L_path;
    s_ref_dot = 0.0;
  end if;

  z_ref = s_ref - 0.25;
  x_ref = A_surf * sin(2.0 * pi * z_ref / L_surf);
  dx_dz_ref = A_surf * (2.0 * pi / L_surf) * cos(2.0 * pi * z_ref / L_surf);
  n_norm_ref = sqrt(1.0 + dx_dz_ref * dx_dz_ref + eps);
  n_x_ref = 1.0 / n_norm_ref;
  n_z_ref = -dx_dz_ref / n_norm_ref;
  z_ref_dot = s_ref_dot;
  x_ref_dot = dx_dz_ref * z_ref_dot;

  // === Force regulation (PI on normal force) ===
  force_err = F_normal_setpoint - F_normal;
  der(force_integral) = force_err;
  delta_n = delta_n_0 + ki_force * force_integral;
  delta_n_clamped = max(0.0, min(delta_n, delta_n_max));

  // === Desired pose: surface point offset inward by delta_n ===
  x_des = x_ref - delta_n_clamped * n_x_ref;
  z_des = z_ref - delta_n_clamped * n_z_ref;
  vx_des = x_ref_dot;
  vz_des = z_ref_dot;

  // === Tangential PD position controller ===
  Fx_cmd = m_tool * (kp_pos * (x_des - x) + kd_pos * (vx_des - vx));
  Fy_cmd = m_tool * (kp_pos * (0.0 - y) + kd_pos * (0.0 - vy));
  Fz_cmd = m_tool * (kp_pos * (z_des - z) + kd_pos * (vz_des - vz));

  // === Actuator saturation (force limit per axis) ===
  Fx_act = max(-F_max, min(Fx_cmd, F_max));
  Fy_act = max(-F_max, min(Fy_cmd, F_max));
  Fz_act = max(-F_max, min(Fz_cmd, F_max));

  // === Plant dynamics ===
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (Fx_act + F_contact_x + F_dist_x) / m_tool;
  der(vy) = (Fy_act + F_contact_y) / m_tool;
  der(vz) = (Fz_act + F_contact_z + F_dist_z) / m_tool;

  // === Sensors ===
  enc_x = x;
  enc_y = y;
  enc_z = z;
  wrench_fx = F_contact_x;
  wrench_fy = F_contact_y;
  wrench_fz = F_contact_z;
  pose_x = x;
  pose_y = y;
  pose_z = z;
  F_normal_meas = F_normal;

  // === Metrics ===
  path_error = abs(s_ref - (z + 0.25));
  tracking_error = path_error;
  in_contact = penetration > 0.0;
  joint_bounds_ok = (x >= x_min - eps) and (x <= x_max + eps) and
                    (y >= y_min - eps) and (y <= y_max + eps) and
                    (z >= z_min - eps) and (z <= z_max + eps);
  effort_bounds_ok = (abs(Fx_act) <= F_max + eps) and
                     (abs(Fy_act) <= F_max + eps) and
                     (abs(Fz_act) <= F_max + eps);
  force_range_ok = (F_normal >= 12.0 - eps) and (F_normal <= 30.0 + eps);
  continuous_contact_ok = in_contact;

  annotation (
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "CartesianToolPolishD: 3-axis prismatic polishing robot. Three orthogonal prismatic axes move a 2.5 kg tool carriage. Travel +/-0.10 m (X,Y), +/-0.30 m (Z). Force limit 350 N/axis. Curved sinusoidal workpiece, compliant normal contact, Coulomb friction mu=0.50. Tangential trajectory control with normal-force regulation setpoint 20 N. 7 N tangential disturbance during middle third of 14 s run. Logging rate 200 Hz (Interval 0.005 s). Path length 0.50 m. Force constraint 12-30 N. Tracking error target below 0.02 m after 9.1 s."));
end CartesianToolPolishD;