model ContactArmGraspC
  "Contact-rich manipulation: impedance motion then force regulation"

  // === Simulation parameters ===
  parameter Real Ts = 0.008 "Control sample period [s] (125 Hz)";
  parameter Real T_total = 12.0 "Simulation duration [s]";

  // === Arm link lengths (capsule links) ===
  parameter Real L1 = 0.30 "Link 1 length [m]";
  parameter Real L2 = 0.30 "Link 2 length [m]";
  parameter Real L3 = 0.25 "Link 3 length [m]";
  parameter Real L4 = 0.12 "Link 4 length [m]";
  parameter Real L5 = 0.10 "Link 5 length [m]";
  parameter Real L6 = 0.08 "Link 6 length [m] (replaceable rigid tool)";

  // === Joint inertias and damping ===
  parameter Real I1 = 0.20 "Joint 1 inertia [kg.m2]";
  parameter Real I2 = 0.15 "Joint 2 inertia [kg.m2]";
  parameter Real I3 = 0.10 "Joint 3 inertia [kg.m2]";
  parameter Real I4 = 0.03 "Joint 4 inertia [kg.m2]";
  parameter Real I5 = 0.015 "Joint 5 inertia [kg.m2]";
  parameter Real I6 = 0.008 "Joint 6 inertia [kg.m2]";
  parameter Real b1 = 0.10 "Joint 1 damping [N.m.s/rad]";
  parameter Real b2 = 0.08 "Joint 2 damping [N.m.s/rad]";
  parameter Real b3 = 0.06 "Joint 3 damping [N.m.s/rad]";
  parameter Real b4 = 0.04 "Joint 4 damping [N.m.s/rad]";
  parameter Real b5 = 0.03 "Joint 5 damping [N.m.s/rad]";
  parameter Real b6 = 0.02 "Joint 6 damping [N.m.s/rad]";

  // === Actuator saturation ===
  parameter Real tau_max = 110.0 "Maximum command magnitude [N.m]";

  // === Contact and table parameters ===
  parameter Real mu = 0.78 "Friction coefficient";
  parameter Real e_rest = 0.03 "Restitution coefficient (modeled via high contact damping)";
  parameter Real k_contact = 5.0e4 "Contact stiffness [N/m]";
  parameter Real d_contact = 200.0 "Contact damping [N.s/m]";
  parameter Real table_z = 0.0 "Table surface height [m]";

  // === Object parameters ===
  parameter Real m_obj = 1.0 "Object mass [kg]";
  parameter Real obj_half = 0.04 "Object half-size [m]";
  parameter Real obj_x0 = 0.35 "Object initial x [m]";
  parameter Real obj_y0 = 0.0 "Object initial y [m]";
  parameter Real obj_z0 = 0.04 "Object initial z [m]";

  // === Disturbance ===
  parameter Real F_dist = 7.2 "Tangential disturbance magnitude [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end time [s]";

  // === Controller gains ===
  parameter Real Kp_imp = 400.0 "Impedance position gain [N/m]";
  parameter Real Kd_imp = 40.0 "Impedance velocity gain [N.s/m]";
  parameter Real Kf_force = 0.5 "Force regulation proportional gain";
  parameter Real F_grasp_des = 25.0 "Desired grasp normal force [N]";

  // === Reference ===
  parameter Real ee_x_ref_final = 0.35 "Final EE x reference [m]";
  parameter Real ee_y_ref_final = 0.0 "Final EE y reference [m]";
  parameter Real ee_z_ref_final = 0.04 "Final EE z reference [m]";
  parameter Real tau_approach = 1.0 "Approach time constant [s]";

  // === Joint states ===
  Real q1(start = 0.0) "Joint 1 angle (Z axis) [rad]";
  Real q2(start = 0.4) "Joint 2 angle (Y axis) [rad]";
  Real q3(start = 0.6) "Joint 3 angle (Y axis) [rad]";
  Real q4(start = 0.0) "Joint 4 angle (X axis) [rad]";
  Real q5(start = 0.0) "Joint 5 angle (Y axis) [rad]";
  Real q6(start = 0.0) "Joint 6 angle (X axis) [rad]";
  Real dq1(start = 0.0) "Joint 1 velocity [rad/s]";
  Real dq2(start = 0.0) "Joint 2 velocity [rad/s]";
  Real dq3(start = 0.0) "Joint 3 velocity [rad/s]";
  Real dq4(start = 0.0) "Joint 4 velocity [rad/s]";
  Real dq5(start = 0.0) "Joint 5 velocity [rad/s]";
  Real dq6(start = 0.0) "Joint 6 velocity [rad/s]";

  // === Torque commands and saturated outputs ===
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

  // === End-effector pose ===
  Real ee_x "End-effector x [m]";
  Real ee_y "End-effector y [m]";
  Real ee_z "End-effector z [m]";
  Real ee_r "End-effector radial reach [m]";

  // === Object state ===
  Real obj_x(start = 0.35) "Object x position [m]";
  Real obj_y(start = 0.0) "Object y position [m]";
  Real obj_z(start = 0.04) "Object z position [m]";
  Real obj_vx(start = 0.0) "Object x velocity [m/s]";
  Real obj_vy(start = 0.0) "Object y velocity [m/s]";
  Real obj_vz(start = 0.0) "Object z velocity [m/s]";

  // === Contact and sensor signals ===
  Real F_normal "Normal contact force tool-object [N]";
  Real F_contact_x "Contact force x on tool [N]";
  Real F_contact_y "Contact force y on tool [N]";
  Real F_contact_z "Contact force z on tool [N]";
  Real F_table "Table normal force on object [N]";
  Real F_friction_x "Table friction x on object [N]";
  Real F_friction_y "Table friction y on object [N]";

  // === Six-axis wrist sensor ===
  Real sensor_Fx "Wrist sensor force x [N]";
  Real sensor_Fy "Wrist sensor force y [N]";
  Real sensor_Fz "Wrist sensor force z [N]";
  Real sensor_Mx "Wrist sensor moment x [N.m]";
  Real sensor_My "Wrist sensor moment y [N.m]";
  Real sensor_Mz "Wrist sensor moment z [N.m]";

  // === Object pose measurement ===
  Real pose_meas_x "Measured object x [m]";
  Real pose_meas_y "Measured object y [m]";
  Real pose_meas_z "Measured object z [m]";

  // === Controller variables ===
  Real ee_x_ref "EE x reference [m]";
  Real ee_y_ref "EE y reference [m]";
  Real ee_z_ref "EE z reference [m]";
  Real tracking_error "Primary tracking error [m]";
  Real phase "Control phase (0=approach,1=grasp,2=hold)";
  Real F_normal_meas "Measured normal force from sensor [N]";

  // === Disturbance ===
  Real F_dist_x "Disturbance force x [N]";
  Real F_dist_y "Disturbance force y [N]";

  // === Joint accelerations ===
  Real ddq1 "Joint 1 acceleration [rad/s2]";
  Real ddq2 "Joint 2 acceleration [rad/s2]";
  Real ddq3 "Joint 3 acceleration [rad/s2]";
  Real ddq4 "Joint 4 acceleration [rad/s2]";
  Real ddq5 "Joint 5 acceleration [rad/s2]";
  Real ddq6 "Joint 6 acceleration [rad/s2]";

  // === Monitors ===
  Real contact_established "Contact established flag (1=yes,0=no)";
  Real grasp_lost "Grasp loss flag (1=yes,0=no)";
  Real effort_norm "Command effort norm [N.m]";
  Real obj_displacement "Object displacement from initial [m]";

  // === Intermediate kinematic variables ===
  Real c1 "cos(q1)";
  Real s1 "sin(q1)";
  Real c2 "cos(q2)";
  Real s2 "sin(q2)";
  Real c23 "cos(q2+q3)";
  Real s23 "sin(q2+q3)";
  Real r_reach "Radial reach [m]";
  Real J11 "Jacobian element [m]";
  Real J12 "Jacobian element [m]";
  Real J13 "Jacobian element [m]";
  Real J21 "Jacobian element [m]";
  Real J22 "Jacobian element [m]";
  Real J23 "Jacobian element [m]";
  Real J31 "Jacobian element [m]";
  Real J32 "Jacobian element [m]";
  Real J33 "Jacobian element [m]";
  Real v_ee_x "EE velocity x [m/s]";
  Real v_ee_y "EE velocity y [m/s]";
  Real v_ee_z "EE velocity z [m/s]";

  // === Contact intermediates ===
  Real delta_x "Tool-object x difference [m]";
  Real delta_y "Tool-object y difference [m]";
  Real delta_z "Tool-object z difference [m]";
  Real dist_ee_obj "Distance tool to object [m]";
  Real n_x "Normal unit x";
  Real n_y "Normal unit y";
  Real n_z "Normal unit z";
  Real penetration "Contact penetration depth [m]";
  Real v_rel_x "Relative velocity x [m/s]";
  Real v_rel_y "Relative velocity y [m/s]";
  Real v_rel_z "Relative velocity z [m/s]";
  Real v_normal "Normal approach velocity [m/s]";
  Real pen_active "Penetration active (1=yes,0=no)";
  Real v_pos "Positive normal velocity [m/s]";
  Real v_normal_damp "Damped normal velocity [m/s]";

  // === Table contact intermediates ===
  Real table_pen "Table penetration [m]";
  Real table_damp_v "Damped table velocity [m/s]";
  Real v_slip "Slip velocity magnitude [m/s]";
  Real F_friction_mag "Friction force magnitude [N]";

  // === Control intermediates ===
  Real F_imp_x "Impedance force x [N]";
  Real F_imp_y "Impedance force y [N]";
  Real F_imp_z "Impedance force z [N]";
  Real F_reg_z "Force regulation z [N]";
  Real F_cmd_x "Total Cartesian force x [N]";
  Real F_cmd_y "Total Cartesian force y [N]";
  Real F_cmd_z "Total Cartesian force z [N]";

  // === Object dynamics intermediates ===
  Real obj_ax "Object acceleration x [m/s2]";
  Real obj_ay "Object acceleration y [m/s2]";
  Real obj_az "Object acceleration z [m/s2]";

  // === Synchronized trace clock ===
  Real clock_125 "125 Hz synchronized trace clock [s]";

equation
  // === Forward kinematics (Z-Y-Y-X-Y-X serial chain) ===
  c1 = cos(q1);
  s1 = sin(q1);
  c2 = cos(q2);
  s2 = sin(q2);
  c23 = cos(q2 + q3);
  s23 = sin(q2 + q3);

  r_reach = L2 * c2 + L3 * c23 + L4 + L5 + L6;
  ee_r = r_reach;
  ee_x = r_reach * c1;
  ee_y = r_reach * s1;
  ee_z = L1 + L2 * s2 + L3 * s23;

  // === Translational Jacobian (q1,q2,q3 affect EE position) ===
  J11 = -r_reach * s1;
  J12 = (-L2 * s2 - L3 * s23) * c1;
  J13 = (-L3 * s23) * c1;
  J21 = r_reach * c1;
  J22 = (-L2 * s2 - L3 * s23) * s1;
  J23 = (-L3 * s23) * s1;
  J31 = 0.0;
  J32 = L2 * c2 + L3 * c23;
  J33 = L3 * c23;

  // === End-effector velocity ===
  v_ee_x = dq1 * J11 + dq2 * J12 + dq3 * J13;
  v_ee_y = dq1 * J21 + dq2 * J22 + dq3 * J23;
  v_ee_z = dq1 * J31 + dq2 * J32 + dq3 * J33;

  // === Reference trajectory (exponential approach to grasp pose) ===
  ee_x_ref = ee_x_ref_final * (1.0 - exp(-time / tau_approach));
  ee_y_ref = ee_y_ref_final * (1.0 - exp(-time / tau_approach));
  ee_z_ref = ee_z_ref_final * (1.0 - exp(-time / tau_approach));

  // === Control phase indicator ===
  phase = noEvent(if time < 3.0 then 0.0 elseif time < 7.0 then 1.0 else 2.0);

  // === Impedance control (Cartesian space) ===
  F_imp_x = Kp_imp * (ee_x_ref - ee_x) - Kd_imp * v_ee_x;
  F_imp_y = Kp_imp * (ee_y_ref - ee_y) - Kd_imp * v_ee_y;
  F_imp_z = Kp_imp * (ee_z_ref - ee_z) - Kd_imp * v_ee_z;

  // === Force regulation (active when contact established) ===
  F_reg_z = noEvent(if F_normal > 1.0 then -Kf_force * (F_grasp_des - F_normal) else 0.0);

  F_cmd_x = F_imp_x;
  F_cmd_y = F_imp_y;
  F_cmd_z = F_imp_z + F_reg_z;

  // === Torque commands via Jacobian transpose ===
  tau1_cmd = J11 * F_cmd_x + J21 * F_cmd_y + J31 * F_cmd_z;
  tau2_cmd = J12 * F_cmd_x + J22 * F_cmd_y + J32 * F_cmd_z;
  tau3_cmd = J13 * F_cmd_x + J23 * F_cmd_y + J33 * F_cmd_z;
  tau4_cmd = 0.0;
  tau5_cmd = 0.0;
  tau6_cmd = noEvent(if F_normal > 1.0 then 5.0 else 0.0);

  // === Actuator saturation (six saturated joint effort actuators) ===
  tau1_sat = noEvent(if tau1_cmd > tau_max then tau_max elseif tau1_cmd < -tau_max then -tau_max else tau1_cmd);
  tau2_sat = noEvent(if tau2_cmd > tau_max then tau_max elseif tau2_cmd < -tau_max then -tau_max else tau2_cmd);
  tau3_sat = noEvent(if tau3_cmd > tau_max then tau_max elseif tau3_cmd < -tau_max then -tau_max else tau3_cmd);
  tau4_sat = noEvent(if tau4_cmd > tau_max then tau_max elseif tau4_cmd < -tau_max then -tau_max else tau4_cmd);
  tau5_sat = noEvent(if tau5_cmd > tau_max then tau_max elseif tau5_cmd < -tau_max then -tau_max else tau5_cmd);
  tau6_sat = noEvent(if tau6_cmd > tau_max then tau_max elseif tau6_cmd < -tau_max then -tau_max else tau6_cmd);

  // === Joint dynamics (six revolute joints) ===
  I1 * ddq1 + b1 * dq1 = tau1_sat;
  I2 * ddq2 + b2 * dq2 = tau2_sat;
  I3 * ddq3 + b3 * dq3 = tau3_sat;
  I4 * ddq4 + b4 * dq4 = tau4_sat;
  I5 * ddq5 + b5 * dq5 = tau5_sat;
  I6 * ddq6 + b6 * dq6 = tau6_sat;

  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;
  der(q5) = dq5;
  der(q6) = dq6;

  // === Contact model (tool-object, spring-damper with collision) ===
  delta_x = ee_x - obj_x;
  delta_y = ee_y - obj_y;
  delta_z = ee_z - obj_z;
  dist_ee_obj = sqrt(delta_x * delta_x + delta_y * delta_y + delta_z * delta_z);

  // Normal unit vector from object center toward tool (zero-error branch)
  n_x = delta_x / (dist_ee_obj + 1e-9);
  n_y = delta_y / (dist_ee_obj + 1e-9);
  n_z = delta_z / (dist_ee_obj + 1e-9);

  // Penetration depth (positive when tool overlaps object)
  penetration = noEvent(if obj_half > dist_ee_obj then obj_half - dist_ee_obj else 0.0);
  pen_active = noEvent(if penetration > 0.0 then 1.0 else 0.0);

  // Relative velocity and normal component
  v_rel_x = v_ee_x - obj_vx;
  v_rel_y = v_ee_y - obj_vy;
  v_rel_z = v_ee_z - obj_vz;
  v_normal = v_rel_x * n_x + v_rel_y * n_y + v_rel_z * n_z;
  v_pos = noEvent(if v_normal > 0.0 then v_normal else 0.0);
  v_normal_damp = pen_active * v_pos;

  // Normal contact force (stiffness + damping only during penetration)
  F_normal = k_contact * penetration + d_contact * v_normal_damp;

  // Contact force on tool (repulsive)
  F_contact_x = F_normal * n_x;
  F_contact_y = F_normal * n_y;
  F_contact_z = F_normal * n_z;

  // === Disturbance (7.2 N tangential, middle third: 4-8 s) ===
  F_dist_x = noEvent(if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0);
  F_dist_y = 0.0;

  // === Table contact (rigid support table, collision enabled) ===
  table_pen = noEvent(if obj_z < obj_half + table_z then obj_half + table_z - obj_z else 0.0);
  table_damp_v = noEvent(if obj_vz < 0.0 and obj_z < obj_half + table_z then -obj_vz else 0.0);
  F_table = k_contact * table_pen + d_contact * table_damp_v;

  // === Table friction (Coulomb, coefficient 0.78) ===
  v_slip = sqrt(obj_vx * obj_vx + obj_vy * obj_vy);
  F_friction_mag = mu * F_table;
  F_friction_x = noEvent(if v_slip > 1e-4 then -F_friction_mag * obj_vx / (v_slip + 1e-9) else 0.0);
  F_friction_y = noEvent(if v_slip > 1e-4 then -F_friction_mag * obj_vy / (v_slip + 1e-9) else 0.0);

  // === Object dynamics ===
  obj_ax = (-F_contact_x + F_dist_x + F_friction_x) / m_obj;
  obj_ay = (-F_contact_y + F_dist_y + F_friction_y) / m_obj;
  obj_az = (-F_contact_z - m_obj * 9.81 + F_table) / m_obj;

  der(obj_vx) = obj_ax;
  der(obj_vy) = obj_ay;
  der(obj_vz) = obj_az;
  der(obj_x) = obj_vx;
  der(obj_y) = obj_vy;
  der(obj_z) = obj_vz;

  // === Six-axis wrist force/torque sensor ===
  sensor_Fx = F_contact_x;
  sensor_Fy = F_contact_y;
  sensor_Fz = F_contact_z;
  sensor_Mx = 0.0;
  sensor_My = 0.0;
  sensor_Mz = 0.0;

  // === Object pose measurement ===
  pose_meas_x = obj_x;
  pose_meas_y = obj_y;
  pose_meas_z = obj_z;

  // === Measured normal force (from wrist sensor) ===
  F_normal_meas = sqrt(sensor_Fx * sensor_Fx
                     + sensor_Fy * sensor_Fy
                     + sensor_Fz * sensor_Fz);

  // === Primary tracking error ===
  tracking_error = sqrt((ee_x - ee_x_ref) * (ee_x - ee_x_ref)
                      + (ee_y - ee_y_ref) * (ee_y - ee_y_ref)
                      + (ee_z - ee_z_ref) * (ee_z - ee_z_ref));

  // === Monitors and requirement checks ===
  contact_established = noEvent(if F_normal > 1.0 then 1.0 else 0.0);
  grasp_lost = noEvent(if time > 5.0 and F_normal < 0.5 then 1.0 else 0.0);
  effort_norm = sqrt(tau1_sat * tau1_sat + tau2_sat * tau2_sat
                   + tau3_sat * tau3_sat + tau4_sat * tau4_sat
                   + tau5_sat * tau5_sat + tau6_sat * tau6_sat);
  obj_displacement = sqrt((obj_x - obj_x0) * (obj_x - obj_x0)
                        + (obj_y - obj_y0) * (obj_y - obj_y0)
                        + (obj_z - obj_z0) * (obj_z - obj_z0));

  // === Synchronized trace clock ===
  clock_125 = time;

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "Contact-rich manipulation system ContactArmGraspC.
      Plant: fixed 6-DOF revolute arm (Z-Y-Y-X-Y-X axes), capsule links,
      six-axis wrist sensor, replaceable rigid tool (L6).
      Six saturated joint effort actuators (max 110 N.m).
      Impedance motion control followed by force regulation.
      Rigid support table (friction 0.78, restitution 0.03, collision enabled).
      7.2 N tangential disturbance during middle third (4-8 s of 12 s).
      125 Hz control, 12 s simulation. Synchronized state, command, and sensor traces.
      Requirements: travel and effort bounds, stable contact, bounded object
      displacement, no grasp loss, primary tracking error below 0.016 m after 7.8 s,
      no NaN or infinite physical, control, or estimator values.
      Restitution 0.03 modeled via high contact damping ratio (near-plastic impact).")
  );
end ContactArmGraspC;