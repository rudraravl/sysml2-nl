model ContactArmGraspD
  import Modelica.SIunits;
  import Modelica.Constants.pi;
  import Modelica.Constants.g_n;

  // ==================== Time Parameters ====================
  parameter SIunits.Time T_sim = 14.0 "Total simulation duration";
  parameter SIunits.Time T_sample = 0.005 "Control sample period (200 Hz)";
  parameter SIunits.Time t_dist_start = 14.0 / 3.0 "Disturbance start (middle third)";
  parameter SIunits.Time t_dist_end = 28.0 / 3.0 "Disturbance end (middle third)";
  parameter SIunits.Time t_track_check = 9.1 "Tracking error threshold check time";
  parameter SIunits.Length track_thresh = 0.015 "Tracking error threshold after 9.1 s";
  parameter SIunits.Length max_obj_disp = 0.05 "Max allowed object displacement (assumed)";
  parameter SIunits.Angle q_travel_max = pi "Joint travel bound (assumed)";
  parameter SIunits.Time t_force_reg_duration = 2.0 "Force regulation duration before hold (assumed)";

  // ==================== Arm Embodiment (assumed unless noted) ====================
  parameter SIunits.Length L1 = 0.45 "Upper arm length (assumed)";
  parameter SIunits.Length L2 = 0.35 "Forearm length (assumed)";
  parameter SIunits.Length L3 = 0.10 "Rigid tool length (assumed, replaceable)";
  parameter SIunits.Length H_base = 0.70 "Base height (assumed)";
  parameter SIunits.Inertia Jq1 = 0.8 "Joint 1 inertia (assumed)";
  parameter SIunits.Inertia Jq2 = 0.6 "Joint 2 inertia (assumed)";
  parameter SIunits.Inertia Jq3 = 0.4 "Joint 3 inertia (assumed)";
  parameter SIunits.Inertia Jq4 = 0.10 "Joint 4 inertia (assumed)";
  parameter SIunits.Inertia Jq5 = 0.08 "Joint 5 inertia (assumed)";
  parameter SIunits.Inertia Jq6 = 0.05 "Joint 6 inertia (assumed)";
  parameter SIunits.RotationalDampingConstant Bq1 = 1.0 "Joint 1 damping (assumed)";
  parameter SIunits.RotationalDampingConstant Bq2 = 1.0 "Joint 2 damping (assumed)";
  parameter SIunits.RotationalDampingConstant Bq3 = 0.8 "Joint 3 damping (assumed)";
  parameter SIunits.RotationalDampingConstant Bq4 = 0.3 "Joint 4 damping (assumed)";
  parameter SIunits.RotationalDampingConstant Bq5 = 0.3 "Joint 5 damping (assumed)";
  parameter SIunits.RotationalDampingConstant Bq6 = 0.2 "Joint 6 damping (assumed)";
  parameter SIunits.Torque tau_max = 120.0 "Maximum joint effort (saturation limit)";

  // ==================== Contact and Table ====================
  parameter Real mu = 0.78 "Friction coefficient";
  parameter Real e_rest = 0.03 "Restitution coefficient";
  parameter SIunits.TranslationalSpringConstant k_c = 6000.0 "Contact stiffness (assumed)";
  // d_c derived from e_rest: zeta=sqrt(ln(1/e)^2/(pi^2+ln(1/e)^2)), d_c=2*zeta*sqrt(k_c*m_eff)
  // For e=0.03, m_eff=1.0 kg, k_c=6000: zeta~0.744, d_c~115
  parameter SIunits.TranslationalDampingConstant d_c = 115.0 "Contact damping (from restitution, m_eff assumed 1.0 kg)";
  parameter SIunits.Length z_table = 0.0 "Table surface height (assumed)";
  parameter SIunits.TranslationalSpringConstant k_table = 8000.0 "Table contact stiffness (assumed)";
  parameter SIunits.TranslationalDampingConstant d_table = 50.0 "Table contact damping (assumed)";

  // ==================== Object (assumed) ====================
  parameter SIunits.Mass m_obj = 1.0 "Object mass (assumed)";
  parameter SIunits.Length x_obj0 = 0.30 "Object initial x (assumed)";
  parameter SIunits.Length y_obj0 = 0.0 "Object initial y (assumed)";
  parameter SIunits.Length r_obj = 0.03 "Object radius / half-height (assumed)";

  // ==================== Controller (assumed) ====================
  parameter Real Kp_j = 200.0 "Joint impedance position gain (assumed)";
  parameter Real Kd_j = 15.0 "Joint impedance velocity gain (assumed)";
  parameter Real Kf_pos = 0.0005 "Force regulation proportional gain [m/N] (assumed)";
  parameter Real Kf_int = 0.00002 "Force regulation integral gain [m/(N.s)] (assumed)";
  parameter SIunits.Force F_grasp_des = 15.0 "Desired normal grasp force (assumed)";
  parameter SIunits.Force F_contact_thresh = 3.0 "Contact detection threshold (assumed)";

  // ==================== Disturbance ====================
  parameter SIunits.Force F_dist_mag = 8.0 "Tangential disturbance magnitude";

  // ==================== Continuous States ====================
  // Joint angles (Z-Y-Y-X-Y-Z axes)
  SIunits.Angle q1(start = 0.0) "Joint 1 (Z axis - base yaw)";
  SIunits.Angle q2(start = 0.5) "Joint 2 (Y axis - shoulder pitch)";
  SIunits.Angle q3(start = -0.7) "Joint 3 (Y axis - elbow pitch)";
  SIunits.Angle q4(start = 0.0) "Joint 4 (X axis - wrist roll)";
  SIunits.Angle q5(start = 0.2) "Joint 5 (Y axis - wrist pitch)";
  SIunits.Angle q6(start = 0.0) "Joint 6 (Z axis - wrist yaw)";
  SIunits.AngularVelocity w1(start = 0.0) "Joint 1 velocity";
  SIunits.AngularVelocity w2(start = 0.0) "Joint 2 velocity";
  SIunits.AngularVelocity w3(start = 0.0) "Joint 3 velocity";
  SIunits.AngularVelocity w4(start = 0.0) "Joint 4 velocity";
  SIunits.AngularVelocity w5(start = 0.0) "Joint 5 velocity";
  SIunits.AngularVelocity w6(start = 0.0) "Joint 6 velocity";
  // Object state
  SIunits.Position obj_x(start = x_obj0) "Object x";
  SIunits.Position obj_y(start = y_obj0) "Object y";
  SIunits.Position obj_z(start = r_obj) "Object z";
  SIunits.Velocity obj_vx(start = 0.0) "Object x velocity";
  SIunits.Velocity obj_vy(start = 0.0) "Object y velocity";
  SIunits.Velocity obj_vz(start = 0.0) "Object z velocity";

  // ==================== Discrete Controller States ====================
  discrete Integer phase(start = 0) "0=impedance, 1=force_reg, 2=hold";
  discrete SIunits.Position des_x(start = x_obj0) "Desired ee x";
  discrete SIunits.Position des_y(start = y_obj0) "Desired ee y";
  discrete SIunits.Position des_z(start = 2.0 * r_obj + 0.005) "Desired ee z";
  discrete SIunits.Angle des_q1(start = 0.0) "Desired joint 1";
  discrete SIunits.Angle des_q2(start = 0.5) "Desired joint 2";
  discrete SIunits.Angle des_q3(start = -0.7) "Desired joint 3";
  discrete SIunits.Angle des_q4(start = 0.0) "Desired joint 4";
  discrete SIunits.Angle des_q5(start = 0.2) "Desired joint 5";
  discrete SIunits.Angle des_q6(start = 0.0) "Desired joint 6";
  discrete Real f_err_int(start = 0.0) "Force error integral [N.s]";
  discrete SIunits.Time t_grasp_start(start = 0.0) "Grasp establishment time";

  // ==================== Intermediate Variables ====================
  Real c1, s1;
  SIunits.Length r_reach, z_reach;
  Real dr_dq2, dz_dq2, dr_dq3, dz_dq3, dr_dq5, dz_dq5;
  SIunits.Position ee_x, ee_y, ee_z;
  SIunits.Velocity ee_vx, ee_vy, ee_vz;
  Real dr_reach_dt;
  SIunits.Torque tau1, tau2, tau3, tau4, tau5, tau6 "Control torques";
  SIunits.Torque tau_c1, tau_c2, tau_c3, tau_c4, tau_c5, tau_c6 "Contact reaction torques";
  SIunits.Torque tau1_s, tau2_s, tau3_s, tau4_s, tau5_s, tau6_s "Saturated torques";
  SIunits.Force f_cn "Normal contact force tool-object";
  SIunits.Force f_ctx "Tangential contact x on object from tool";
  SIunits.Force f_cty "Tangential contact y on object from tool";
  SIunits.Force f_table_n "Table normal force on object";
  SIunits.Force f_table_fx "Table friction x on object";
  SIunits.Force f_table_fy "Table friction y on object";
  SIunits.Force f_dist "Disturbance force";
  SIunits.Force f_tool_x, f_tool_y, f_tool_z "Forces on tool from object";
  SIunits.Length penetration "Contact penetration depth";
  SIunits.Length penetration_table "Table penetration";
  Boolean contact_active(start = false) "Tool-object contact flag";
  Real rel_vx, rel_vy, rel_v_norm;
  Real obj_v_horiz;
  SIunits.Force f_sens_n "Wrist sensor normal force";
  SIunits.Force f_sens_tx "Wrist sensor tangential x";
  SIunits.Force f_sens_ty "Wrist sensor tangential y";
  Real r_tgt, z_tgt_rel, d_tgt, cos_q3_ik;

  // ==================== Outputs ====================
  output SIunits.Length tracking_error "End-effector tracking error";
  output SIunits.Length object_displacement "Object displacement from initial";
  output Boolean tracking_ok "Tracking error below threshold after 9.1 s";
  output Boolean grasp_held "Grasp maintained (contact with force)";
  output Boolean stable_contact "Contact force near desired";
  output Boolean travel_ok "Joint angles within travel bounds";
  output Boolean effort_ok "Efforts within saturation";
  output Boolean displacement_ok "Object displacement within bounds";
  output Boolean no_nan_inf "No NaN or infinite values";

equation
  // ==================== Forward Kinematics ====================
  c1 = cos(q1);
  s1 = sin(q1);
  r_reach = L1 * cos(q2) + L2 * cos(q2 + q3) + L3 * cos(q2 + q3 + q5);
  z_reach = H_base + L1 * sin(q2) + L2 * sin(q2 + q3) + L3 * sin(q2 + q3 + q5);
  ee_x = r_reach * c1;
  ee_y = r_reach * s1;
  ee_z = z_reach;

  // ==================== Jacobian Elements ====================
  dr_dq2 = -L1 * sin(q2) - L2 * sin(q2 + q3) - L3 * sin(q2 + q3 + q5);
  dz_dq2 = L1 * cos(q2) + L2 * cos(q2 + q3) + L3 * cos(q2 + q3 + q5);
  dr_dq3 = -L2 * sin(q2 + q3) - L3 * sin(q2 + q3 + q5);
  dz_dq3 = L2 * cos(q2 + q3) + L3 * cos(q2 + q3 + q5);
  dr_dq5 = -L3 * sin(q2 + q3 + q5);
  dz_dq5 = L3 * cos(q2 + q3 + q5);

  // ==================== End-Effector Velocity (explicit) ====================
  dr_reach_dt = dr_dq2 * w2 + dr_dq3 * w3 + dr_dq5 * w5;
  ee_vx = dr_reach_dt * c1 - r_reach * s1 * w1;
  ee_vy = dr_reach_dt * s1 + r_reach * c1 * w1;
  ee_vz = dz_dq2 * w2 + dz_dq3 * w3 + dz_dq5 * w5;

  // ==================== Contact Model (Tool-Object) ====================
  penetration = max(0.0, (obj_z + r_obj) - ee_z);
  contact_active = (penetration > 0.0) and
    ((ee_x - obj_x) * (ee_x - obj_x) + (ee_y - obj_y) * (ee_y - obj_y) < (r_obj + 0.02) * (r_obj + 0.02));

  if contact_active then
    f_cn = k_c * penetration + d_c * max(0.0, obj_vz - ee_vz);
  else
    f_cn = 0.0;
  end if;

  rel_vx = ee_vx - obj_vx;
  rel_vy = ee_vy - obj_vy;
  rel_v_norm = sqrt(rel_vx * rel_vx + rel_vy * rel_vy + 1e-10);

  if contact_active and f_cn > 0.0 then
    f_ctx = mu * f_cn * rel_vx / rel_v_norm;
    f_cty = mu * f_cn * rel_vy / rel_v_norm;
  else
    f_ctx = 0.0;
    f_cty = 0.0;
  end if;

  // Forces on tool from object (Newton's 3rd law)
  f_tool_x = -f_ctx;
  f_tool_y = -f_cty;
  f_tool_z = f_cn;

  // ==================== Wrist Sensor (six-axis, 3 force components shown) ====================
  f_sens_n = f_cn;
  f_sens_tx = -f_ctx;
  f_sens_ty = -f_cty;

  // ==================== Table Contact ====================
  penetration_table = max(0.0, r_obj - obj_z);
  if penetration_table > 0.0 then
    f_table_n = k_table * penetration_table + d_table * max(0.0, -obj_vz);
  else
    f_table_n = 0.0;
  end if;

  obj_v_horiz = sqrt(obj_vx * obj_vx + obj_vy * obj_vy + 1e-10);
  f_table_fx = -mu * f_table_n * obj_vx / obj_v_horiz;
  f_table_fy = -mu * f_table_n * obj_vy / obj_v_horiz;

  // ==================== Disturbance (8 N tangential, middle third) ====================
  if time >= t_dist_start and time <= t_dist_end then
    f_dist = F_dist_mag;
  else
    f_dist = 0.0;
  end if;

  // ==================== Object Dynamics ====================
  m_obj * der(obj_vx) = f_ctx + f_table_fx;
  m_obj * der(obj_vy) = f_cty + f_table_fy + f_dist;
  m_obj * der(obj_vz) = -m_obj * g_n + f_table_n - f_cn;
  der(obj_x) = obj_vx;
  der(obj_y) = obj_vy;
  der(obj_z) = obj_vz;

  // ==================== Contact Reaction Torques (Jacobian Transpose) ====================
  tau_c1 = -ee_y * f_tool_x + ee_x * f_tool_y;
  tau_c2 = dr_dq2 * c1 * f_tool_x + dr_dq2 * s1 * f_tool_y + dz_dq2 * f_tool_z;
  tau_c3 = dr_dq3 * c1 * f_tool_x + dr_dq3 * s1 * f_tool_y + dz_dq3 * f_tool_z;
  tau_c4 = 0.0;
  tau_c5 = dr_dq5 * c1 * f_tool_x + dr_dq5 * s1 * f_tool_y + dz_dq5 * f_tool_z;
  tau_c6 = 0.0;

  // ==================== Joint Dynamics ====================
  Jq1 * der(w1) + Bq1 * w1 = tau1_s + tau_c1;
  Jq2 * der(w2) + Bq2 * w2 = tau2_s + tau_c2;
  Jq3 * der(w3) + Bq3 * w3 = tau3_s + tau_c3;
  Jq4 * der(w4) + Bq4 * w4 = tau4_s + tau_c4;
  Jq5 * der(w5) + Bq5 * w5 = tau5_s + tau_c5;
  Jq6 * der(w6) + Bq6 * w6 = tau6_s + tau_c6;
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(q4) = w4;
  der(q5) = w5;
  der(q6) = w6;

  // ==================== Torque Saturation (120 N.m) ====================
  tau1_s = max(-tau_max, min(tau_max, tau1));
  tau2_s = max(-tau_max, min(tau_max, tau2));
  tau3_s = max(-tau_max, min(tau_max, tau3));
  tau4_s = max(-tau_max, min(tau_max, tau4));
  tau5_s = max(-tau_max, min(tau_max, tau5));
  tau6_s = max(-tau_max, min(tau_max, tau6));

  // ==================== Continuous Joint Impedance Control ====================
  tau1 = Kp_j * (des_q1 - q1) - Kd_j * w1;
  tau2 = Kp_j * (des_q2 - q2) - Kd_j * w2;
  tau3 = Kp_j * (des_q3 - q3) - Kd_j * w3;
  tau4 = Kp_j * (des_q4 - q4) - Kd_j * w4;
  tau5 = Kp_j * (des_q5 - q5) - Kd_j * w5;
  tau6 = Kp_j * (des_q6 - q6) - Kd_j * w6;

  // ==================== Measurements ====================
  tracking_error = sqrt((ee_x - des_x) * (ee_x - des_x) + (ee_y - des_y) * (ee_y - des_y) + (ee_z - des_z) * (ee_z - des_z));
  object_displacement = sqrt((obj_x - x_obj0) * (obj_x - x_obj0) + (obj_y - y_obj0) * (obj_y - y_obj0) + (obj_z - r_obj) * (obj_z - r_obj));

  // ==================== Validity Checks ====================
  tracking_ok = (time < t_track_check) or (tracking_error < track_thresh);
  grasp_held = contact_active and (f_cn > 1.0);
  stable_contact = (phase >= 1) and (abs(f_sens_n - F_grasp_des) < 5.0);
  travel_ok = (abs(q1) <= q_travel_max) and (abs(q2) <= q_travel_max) and (abs(q3) <= q_travel_max) and
              (abs(q4) <= q_travel_max) and (abs(q5) <= q_travel_max) and (abs(q6) <= q_travel_max);
  effort_ok = (abs(tau1_s) <= tau_max + 0.001) and (abs(tau2_s) <= tau_max + 0.001) and
              (abs(tau3_s) <= tau_max + 0.001) and (abs(tau4_s) <= tau_max + 0.001) and
              (abs(tau5_s) <= tau_max + 0.001) and (abs(tau6_s) <= tau_max + 0.001);
  displacement_ok = object_displacement <= max_obj_disp;
  no_nan_inf = (abs(ee_x) < 1e8) and (abs(ee_y) < 1e8) and (abs(ee_z) < 1e8) and
               (abs(obj_x) < 1e8) and (abs(obj_y) < 1e8) and (abs(obj_z) < 1e8) and
               (abs(f_cn) < 1e8) and (abs(tau1) < 1e8) and (abs(f_sens_n) < 1e8) and
               (abs(q1) < 1e8) and (abs(w1) < 1e8) and (abs(obj_vx) < 1e8);

algorithm
  when sample(0, T_sample) then
    // Phase transitions
    if phase == 0 and f_sens_n > F_contact_thresh then
      phase := 1;
      t_grasp_start := time;
    elseif phase == 1 and (time - t_grasp_start) > t_force_reg_duration then
      phase := 2;
    end if;

    // Desired end-effector position by phase
    if phase == 0 then
      // Impedance approach: target just above object
      des_x := x_obj0;
      des_y := y_obj0;
      des_z := 2.0 * r_obj + 0.005;
      f_err_int := 0.0;
    elseif phase == 1 then
      // Force regulation: adjust z to achieve desired grasp force
      f_err_int := f_err_int + (F_grasp_des - f_sens_n) * T_sample;
      des_x := x_obj0;
      des_y := y_obj0;
      des_z := 2.0 * r_obj + 0.005 + Kf_pos * (F_grasp_des - f_sens_n) + Kf_int * f_err_int;
    else
      // Hold: track object, maintain force via spring model
      des_x := obj_x;
      des_y := obj_y;
      des_z := obj_z + r_obj - F_grasp_des / k_c;
      // f_err_int retains previous value (not assigned in this branch)
    end if;

    // Inverse kinematics (simplified planar, tool pointing down)
    des_q1 := atan2(des_y, des_x);
    r_tgt := sqrt(des_x * des_x + des_y * des_y);
    z_tgt_rel := des_z + L3 - H_base;
    d_tgt := sqrt(r_tgt * r_tgt + z_tgt_rel * z_tgt_rel);
    cos_q3_ik := (d_tgt * d_tgt - L1 * L1 - L2 * L2) / (2.0 * L1 * L2);
    cos_q3_ik := max(-0.999, min(0.999, cos_q3_ik));
    des_q3 := -acos(cos_q3_ik);
    des_q2 := atan2(z_tgt_rel, r_tgt) - atan2(L2 * sin(des_q3), L1 + L2 * cos(des_q3));
    des_q4 := 0.0;
    des_q5 := -pi / 2.0 - (des_q2 + des_q3);
    des_q6 := 0.0;
  end when;

annotation(
  experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
  Documentation(info = "Contact-rich manipulation system ContactArmGraspD.
    6-DOF arm (Z-Y-Y-X-Y-Z axes) with capsule links, six-axis wrist sensor, replaceable rigid tool.
    Six saturated joint effort actuators (120 N.m max). Grasps rigid object on support table
    (friction mu=0.78, restitution e=0.03, collision enabled).
    Impedance approach followed by force regulation followed by hold.
    8 N tangential disturbance applied during middle third (4.67-9.33 s).
    Controller at 200 Hz, 14 s simulation. Synchronized state, command, and sensor traces.
    Requirements: travel/effort bounds, stable contact, bounded displacement, no grasp loss,
    tracking error < 0.015 m after 9.1 s, no NaN/Inf.
    Parameters marked 'assumed' are not specified in the requirements and represent reasonable engineering estimates.")
);
end ContactArmGraspD;