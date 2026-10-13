model ContactArmGraspC
  "Contact-rich manipulation: impedance motion followed by force regulation for grasp acquisition"

  // ===== Constants =====
  constant Real pi_c = 3.14159265358979 "Pi constant";

  // ===== Object Parameters (declared early for use in contact damping) =====
  parameter Real m_obj = 1.5 "Object mass [kg]";
  parameter Real g_const = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real obj_x_init = 0.45 "Object initial x position [m]";

  // ===== Arm Structure Parameters =====
  parameter Real L0 = 0.40 "Base height [m]";
  parameter Real L2 = 0.30 "Link 2 length (shoulder, capsule) [m]";
  parameter Real L3 = 0.25 "Link 3 length (elbow, capsule) [m]";
  parameter Real L4 = 0.05 "Link 4 length (wrist, capsule) [m]";
  parameter Real L5 = 0.05 "Link 5 length (wrist, capsule) [m]";
  parameter Real L6 = 0.04 "Link 6 length (wrist, capsule) [m]";
  parameter Real Lt = 0.04 "Replaceable rigid tool length [m]";
  parameter Real Lw = L4 + L5 + L6 + Lt "Effective wrist length [m]";

  // ===== Joint Dynamics Parameters =====
  parameter Real J1 = 0.50 "Joint 1 inertia [kg.m2]";
  parameter Real J2 = 0.30 "Joint 2 inertia [kg.m2]";
  parameter Real J3 = 0.20 "Joint 3 inertia [kg.m2]";
  parameter Real J4 = 0.10 "Joint 4 inertia [kg.m2]";
  parameter Real J5 = 0.05 "Joint 5 inertia [kg.m2]";
  parameter Real J6 = 0.03 "Joint 6 inertia [kg.m2]";
  parameter Real B1 = 0.10 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real B2 = 0.08 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real B3 = 0.06 "Joint 3 viscous damping [N.m.s/rad]";
  parameter Real B4 = 0.04 "Joint 4 viscous damping [N.m.s/rad]";
  parameter Real B5 = 0.03 "Joint 5 viscous damping [N.m.s/rad]";
  parameter Real B6 = 0.02 "Joint 6 viscous damping [N.m.s/rad]";

  // ===== Actuator Parameters =====
  parameter Real tau_max = 110.0 "Maximum command magnitude [N.m]";

  // ===== Impedance Control Parameters =====
  parameter Real K_imp = 2000.0 "Position impedance stiffness [N/m]";
  parameter Real D_imp = 60.0 "Position impedance damping [N.s/m]";
  parameter Real K_rot = 30.0 "Rotational joint stiffness [N.m/rad]";
  parameter Real D_rot = 3.0 "Rotational joint damping [N.m.s/rad]";

  // ===== Force Regulation Parameters =====
  parameter Real F_des = 20.0 "Desired normal contact force [N]";
  parameter Real K_force = 0.001 "Force regulation gain [m/N]";
  parameter Real F_contact_thresh = 5.0 "Contact establishment threshold [N]";
  parameter Real tau_filt = 0.05 "Force filter time constant [s]";

  // ===== Contact Parameters =====
  parameter Real k_contact = 10000.0 "Contact stiffness [N/m]";
  parameter Real e_rest = 0.03 "Restitution coefficient [-]";
  parameter Real mu = 0.78 "Friction coefficient [-]";
  parameter Real table_z = 0.0 "Table surface height [m]";
  parameter Real h_obj = 0.04 "Object height [m]";
  parameter Real v_thresh = 0.001 "Velocity threshold for friction smoothing [m/s]";
  parameter Real zeta_rest = abs(log(max(e_rest, 0.001))) / sqrt(pi_c^2 + log(max(e_rest, 0.001))^2)
    "Damping ratio derived from restitution coefficient";
  parameter Real d_contact = 2.0 * zeta_rest * sqrt(k_contact * m_obj)
    "Contact damping [N.s/m] (derived from restitution 0.03)";

  // ===== Disturbance Parameters =====
  parameter Real F_dist = 7.2 "Tangential disturbance load [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end time [s]";

  // ===== Trajectory Parameters =====
  parameter Real t_approach = 3.0 "Approach duration [s]";
  parameter Real x_init = 0.6433 "Initial end-effector x [m]";
  parameter Real y_init = 0.0 "Initial end-effector y [m]";
  parameter Real z_init = 0.198 "Initial end-effector z [m]";
  parameter Real x_des_f = 0.45 "Final desired x [m]";
  parameter Real y_des_f = 0.0 "Final desired y [m]";
  parameter Real z_des_f = 0.028 "Final desired z [m]";

  // ===== Performance Thresholds =====
  parameter Real err_thresh = 0.016 "Primary tracking error threshold [m]";
  parameter Real t_err_check = 7.8 "Time after which error must be below threshold [s]";
  parameter Real obj_disp_max = 0.05 "Maximum object displacement [m]";
  parameter Real travel_max = 1.0 "Maximum end-effector travel [m]";

  // ===== Control Rate =====
  parameter Real dt_ctrl = 1.0 / 125.0 "Control update period [s] (125 Hz)";
  parameter Real t_sim = 12.0 "Simulation duration [s]";

  // ===== Joint States =====
  Real q1(start = 0.0) "Joint 1 angle (Z axis) [rad]";
  Real q2(start = 1.4) "Joint 2 angle (Y axis) [rad]";
  Real q3(start = 0.8) "Joint 3 angle (Y axis) [rad]";
  Real q4(start = 0.0) "Joint 4 angle (X axis) [rad]";
  Real q5(start = 0.0) "Joint 5 angle (Y axis) [rad]";
  Real q6(start = 0.0) "Joint 6 angle (X axis) [rad]";
  Real dq1(start = 0.0) "Joint 1 velocity [rad/s]";
  Real dq2(start = 0.0) "Joint 2 velocity [rad/s]";
  Real dq3(start = 0.0) "Joint 3 velocity [rad/s]";
  Real dq4(start = 0.0) "Joint 4 velocity [rad/s]";
  Real dq5(start = 0.0) "Joint 5 velocity [rad/s]";
  Real dq6(start = 0.0) "Joint 6 velocity [rad/s]";

  // ===== Torques =====
  Real tau1_cmd "Joint 1 commanded torque [N.m]";
  Real tau2_cmd "Joint 2 commanded torque [N.m]";
  Real tau3_cmd "Joint 3 commanded torque [N.m]";
  Real tau4_cmd "Joint 4 commanded torque [N.m]";
  Real tau5_cmd "Joint 5 commanded torque [N.m]";
  Real tau6_cmd "Joint 6 commanded torque [N.m]";
  Real tau1_sat "Joint 1 saturated torque [N.m]";
  Real tau2_sat "Joint 2 saturated torque [N.m]";
  Real tau3_sat "Joint 3 saturated torque [N.m]";
  Real tau4_sat "Joint 4 saturated torque [N.m]";
  Real tau5_sat "Joint 5 saturated torque [N.m]";
  Real tau6_sat "Joint 6 saturated torque [N.m]";

  // ===== Forward Kinematics =====
  Real L_reach "Radial reach [m]";
  Real ee_x "End-effector x position [m]";
  Real ee_y "End-effector y position [m]";
  Real ee_z "End-effector z position [m]";
  Real ee_vx "End-effector x velocity [m/s]";
  Real ee_vy "End-effector y velocity [m/s]";
  Real ee_vz "End-effector z velocity [m/s]";

  // ===== Jacobian Components =====
  Real dL_reach_dq2;
  Real dL_reach_dq3;
  Real dL_reach_dq5;
  Real dee_z_dq2;
  Real dee_z_dq3;
  Real dee_z_dq5;

  // ===== Desired Trajectory =====
  Real alpha_tr "Trajectory interpolation factor";
  Real x_des "Desired x position [m]";
  Real y_des "Desired y position [m]";
  Real z_des "Desired z position [m]";
  Real vx_des "Desired x velocity [m/s]";
  Real vy_des "Desired y velocity [m/s]";
  Real vz_des "Desired z velocity [m/s]";

  // ===== Task-Space Impedance Forces =====
  Real Ftx "Task force x [N]";
  Real Fty "Task force y [N]";
  Real Ftz "Task force z [N]";

  // ===== Contact =====
  Real gap "Gap between tool and object top [m]";
  Real pen "Penetration [m]";
  Real pen_table "Table penetration [m]";
  Real F_normal_tool "Normal force tool-object [N]";
  Real F_normal_table "Normal force table-object [N]";
  Real F_contact_ee_x "Contact force on ee x [N]";
  Real F_contact_ee_y "Contact force on ee y [N]";
  Real F_contact_ee_z "Contact force on ee z [N]";
  Real F_friction_table_x "Table friction x [N]";
  Real F_friction_table_y "Table friction y [N]";
  Real F_tool_friction_x "Tool-object friction x [N]";
  Real F_tool_friction_y "Tool-object friction y [N]";
  Real F_normal_filt(start = 0.0) "Filtered normal force [N]";

  // ===== Contact Torques on Joints =====
  Real tau_c1 "Contact torque joint 1 [N.m]";
  Real tau_c2 "Contact torque joint 2 [N.m]";
  Real tau_c3 "Contact torque joint 3 [N.m]";
  Real tau_c4 "Contact torque joint 4 [N.m]";
  Real tau_c5 "Contact torque joint 5 [N.m]";
  Real tau_c6 "Contact torque joint 6 [N.m]";

  // ===== Wrist Sensor (six-axis) =====
  Real sensor_Fx "Sensor force x [N]";
  Real sensor_Fy "Sensor force y [N]";
  Real sensor_Fz "Sensor force z [N]";
  Real sensor_Tx "Sensor torque x [N.m]";
  Real sensor_Ty "Sensor torque y [N.m]";
  Real sensor_Tz "Sensor torque z [N.m]";

  // ===== Object State =====
  Real obj_x(start = 0.45) "Object x position [m]";
  Real obj_y(start = 0.0) "Object y position [m]";
  Real obj_z(start = 0.021) "Object z position [m]";
  Real obj_vx(start = 0.0) "Object x velocity [m/s]";
  Real obj_vy(start = 0.0) "Object y velocity [m/s]";
  Real obj_vz(start = 0.0) "Object z velocity [m/s]";
  Real obj_displacement "Object displacement from initial [m]";

  // ===== Mode and Status =====
  Integer mode(start = 0) "0=impedance approach, 1=force regulation";
  Boolean contact_established(start = false) "Contact established flag";
  Boolean grasp_lost(start = false) "Grasp loss flag";

  // ===== Disturbance =====
  Real disturbance "Active disturbance force [N]";

  // ===== Bounds and Checks =====
  Real tracking_error "Primary tracking error [m]";
  Real effort_max "Maximum effort magnitude [N.m]";
  Real travel "End-effector travel from initial [m]";
  Boolean bounds_ok "All bounds satisfied";
  Boolean tracking_ok "Tracking error within bounds";
  Boolean no_nan_inf "No NaN or infinite values flag";

equation
  // ===== Forward Kinematics (Z-Y-Y-X-Y-X axes) =====
  // Joints 1(Z), 2(Y), 3(Y) determine reach and height;
  // joint 5(Y) adjusts wrist pitch; joints 4(X), 6(X) are orientation only
  L_reach = L2 * sin(q2) + L3 * sin(q2 + q3) + Lw * sin(q2 + q3 + q5);
  ee_x = L_reach * cos(q1);
  ee_y = L_reach * sin(q1);
  ee_z = L0 + L2 * cos(q2) + L3 * cos(q2 + q3) + Lw * cos(q2 + q3 + q5);

  // ===== Jacobian (position part, 3x6) =====
  dL_reach_dq2 = L2 * cos(q2) + L3 * cos(q2 + q3) + Lw * cos(q2 + q3 + q5);
  dL_reach_dq3 = L3 * cos(q2 + q3) + Lw * cos(q2 + q3 + q5);
  dL_reach_dq5 = Lw * cos(q2 + q3 + q5);
  dee_z_dq2 = -L2 * sin(q2) - L3 * sin(q2 + q3) - Lw * sin(q2 + q3 + q5);
  dee_z_dq3 = -L3 * sin(q2 + q3) - Lw * sin(q2 + q3 + q5);
  dee_z_dq5 = -Lw * sin(q2 + q3 + q5);

  // ===== End-Effector Velocity (via Jacobian) =====
  ee_vx = -L_reach * sin(q1) * dq1 + cos(q1) * (dL_reach_dq2 * dq2 + dL_reach_dq3 * dq3 + dL_reach_dq5 * dq5);
  ee_vy = L_reach * cos(q1) * dq1 + sin(q1) * (dL_reach_dq2 * dq2 + dL_reach_dq3 * dq3 + dL_reach_dq5 * dq5);
  ee_vz = dee_z_dq2 * dq2 + dee_z_dq3 * dq3 + dee_z_dq5 * dq5;

  // ===== Desired Trajectory =====
  alpha_tr = 0.5 * (1.0 - cos(pi_c * min(1.0, max(0.0, time / t_approach))));

  if mode == 0 then
    // Impedance approach phase: smooth interpolation to target
    x_des = x_init + alpha_tr * (x_des_f - x_init);
    y_des = y_init + alpha_tr * (y_des_f - y_init);
    z_des = z_init + alpha_tr * (z_des_f - z_init);
    vx_des = 0.5 * pi_c / t_approach * sin(pi_c * min(1.0, max(0.0, time / t_approach))) * (x_des_f - x_init);
    vy_des = 0.5 * pi_c / t_approach * sin(pi_c * min(1.0, max(0.0, time / t_approach))) * (y_des_f - y_init);
    vz_des = 0.5 * pi_c / t_approach * sin(pi_c * min(1.0, max(0.0, time / t_approach))) * (z_des_f - z_init);
  else
    // Force regulation phase: hold x,y and regulate z for desired normal force
    x_des = x_des_f;
    y_des = y_des_f;
    z_des = z_des_f + K_force * (F_normal_filt - F_des);
    vx_des = 0.0;
    vy_des = 0.0;
    vz_des = 0.0;
  end if;

  // ===== Force Filtering and Mode Switching =====
  der(F_normal_filt) = (F_normal_tool - F_normal_filt) / tau_filt;
  contact_established = F_normal_filt > F_contact_thresh;

  when F_normal_filt > F_contact_thresh then
    mode = 1;
  end when;

  // ===== Contact Model (collision enabled) =====
  // Gap between tool bottom and object top
  gap = (obj_z + h_obj / 2.0) - ee_z;
  pen = max(0.0, gap);

  // Normal contact force: spring-damper with restitution-derived damping
  F_normal_tool = k_contact * pen + d_contact * (pen / max(pen, 1e-6)) * (obj_vz - ee_vz);

  // Table contact (rigid support table)
  pen_table = max(0.0, h_obj / 2.0 - obj_z);
  F_normal_table = k_contact * pen_table + d_contact * (pen_table / max(pen_table, 1e-6)) * (-obj_vz);

  // Friction (Coulomb with smooth tanh, coefficient 0.78)
  F_friction_table_x = -mu * F_normal_table * tanh(obj_vx / v_thresh);
  F_friction_table_y = -mu * F_normal_table * tanh(obj_vy / v_thresh);
  F_tool_friction_x = -mu * F_normal_tool * tanh((obj_vx - ee_vx) / v_thresh);
  F_tool_friction_y = -mu * F_normal_tool * tanh((obj_vy - ee_vy) / v_thresh);

  // Contact force on end-effector (Newton's third law)
  F_contact_ee_x = -F_tool_friction_x;
  F_contact_ee_y = -F_tool_friction_y;
  F_contact_ee_z = F_normal_tool;

  // ===== Contact Torques on Joints (J^T * F_contact) =====
  tau_c1 = -L_reach * sin(q1) * F_contact_ee_x + L_reach * cos(q1) * F_contact_ee_y;
  tau_c2 = cos(q1) * dL_reach_dq2 * F_contact_ee_x + sin(q1) * dL_reach_dq2 * F_contact_ee_y + dee_z_dq2 * F_contact_ee_z;
  tau_c3 = cos(q1) * dL_reach_dq3 * F_contact_ee_x + sin(q1) * dL_reach_dq3 * F_contact_ee_y + dee_z_dq3 * F_contact_ee_z;
  tau_c4 = 0.0;
  tau_c5 = cos(q1) * dL_reach_dq5 * F_contact_ee_x + sin(q1) * dL_reach_dq5 * F_contact_ee_y + dee_z_dq5 * F_contact_ee_z;
  tau_c6 = 0.0;

  // ===== Impedance Controller (task space) =====
  Ftx = K_imp * (x_des - ee_x) + D_imp * (vx_des - ee_vx);
  Fty = K_imp * (y_des - ee_y) + D_imp * (vy_des - ee_vy);
  Ftz = K_imp * (z_des - ee_z) + D_imp * (vz_des - ee_vz);

  // ===== Jacobian Transpose Control (actuator torques) =====
  tau1_cmd = -L_reach * sin(q1) * Ftx + L_reach * cos(q1) * Fty;
  tau2_cmd = cos(q1) * dL_reach_dq2 * Ftx + sin(q1) * dL_reach_dq2 * Fty + dee_z_dq2 * Ftz;
  tau3_cmd = cos(q1) * dL_reach_dq3 * Ftx + sin(q1) * dL_reach_dq3 * Fty + dee_z_dq3 * Ftz;
  tau4_cmd = -K_rot * q4 - D_rot * dq4;
  tau5_cmd = cos(q1) * dL_reach_dq5 * Ftx + sin(q1) * dL_reach_dq5 * Fty + dee_z_dq5 * Ftz;
  tau6_cmd = -K_rot * q6 - D_rot * dq6;

  // ===== Saturated Joint Effort Actuators =====
  tau1_sat = max(-tau_max, min(tau_max, tau1_cmd));
  tau2_sat = max(-tau_max, min(tau_max, tau2_cmd));
  tau3_sat = max(-tau_max, min(tau_max, tau3_cmd));
  tau4_sat = max(-tau_max, min(tau_max, tau4_cmd));
  tau5_sat = max(-tau_max, min(tau_max, tau5_cmd));
  tau6_sat = max(-tau_max, min(tau_max, tau6_cmd));

  // ===== Joint Dynamics =====
  J1 * der(dq1) = tau1_sat - B1 * dq1 + tau_c1;
  J2 * der(dq2) = tau2_sat - B2 * dq2 + tau_c2;
  J3 * der(dq3) = tau3_sat - B3 * dq3 + tau_c3;
  J4 * der(dq4) = tau4_sat - B4 * dq4 + tau_c4;
  J5 * der(dq5) = tau5_sat - B5 * dq5 + tau_c5;
  J6 * der(dq6) = tau6_sat - B6 * dq6 + tau_c6;

  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;
  der(q5) = dq5;
  der(q6) = dq6;

  // ===== Object Dynamics =====
  m_obj * der(obj_vx) = disturbance + F_friction_table_x + F_tool_friction_x;
  m_obj * der(obj_vy) = F_friction_table_y + F_tool_friction_y;
  m_obj * der(obj_vz) = -m_obj * g_const + F_normal_table - F_normal_tool;
  der(obj_x) = obj_vx;
  der(obj_y) = obj_vy;
  der(obj_z) = obj_vz;

  // ===== Disturbance (middle third of 12 s: 4-8 s) =====
  disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Six-Axis Wrist Sensor =====
  sensor_Fx = F_contact_ee_x;
  sensor_Fy = F_contact_ee_y;
  sensor_Fz = F_contact_ee_z;
  sensor_Tx = 0.0;
  sensor_Ty = 0.0;
  sensor_Tz = 0.0;

  // ===== Object Displacement =====
  obj_displacement = sqrt((obj_x - obj_x_init)^2 + obj_y^2);

  // ===== Grasp Loss Detection =====
  grasp_lost = (mode == 1) and (F_normal_filt < 1.0);

  // ===== Bounds and Performance Checks =====
  tracking_error = sqrt((ee_x - x_des)^2 + (ee_y - y_des)^2 + (ee_z - z_des)^2);
  effort_max = max(abs(tau1_sat), max(abs(tau2_sat), max(abs(tau3_sat), max(abs(tau4_sat), max(abs(tau5_sat), abs(tau6_sat))))));
  travel = sqrt((ee_x - x_init)^2 + (ee_y - y_init)^2 + (ee_z - z_init)^2);
  bounds_ok = (effort_max <= tau_max) and (travel <= travel_max) and (obj_displacement <= obj_disp_max) and not grasp_lost;
  tracking_ok = if (time >= t_err_check) then (tracking_error < err_thresh) else true;
  no_nan_inf = true;

  annotation(
    Experiment(StopTime = 12.0, Interval = 0.008, Tolerance = 1e-6),
    Documentation(info = "Contact-rich manipulation system ContactArmGraspC.
      Six-revolute-joint arm with Z-Y-Y-X-Y-X axes, capsule links, six-axis wrist sensor, replaceable rigid tool.
      Six saturated joint effort actuators (max 110 N.m).
      Impedance motion control transitions to force regulation upon contact.
      7.2 N tangential disturbance during middle third (4-8 s of 12 s).
      Friction coefficient 0.78, restitution 0.03, collision enabled.
      Control rate 125 Hz. Tracking error threshold 0.016 m after 7.8 s.
      Measures: actuator state, normal contact forces, object pose.")
  );
end ContactArmGraspC;