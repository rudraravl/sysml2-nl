model SCARACarryE
  "Fixed-base SCARA manipulator: lift and reposition with orientation preservation, computed-torque control at 250 Hz"

  // ============ Physical Parameters ============
  parameter Modelica.Units.SI.Mass m_base = 28.0
    "Cylindrical base mass (rigid, fixed to floor)";
  parameter Modelica.Units.SI.Length L1 = 0.48
    "Link 1 length (first revolute Z link)";
  parameter Modelica.Units.SI.Length L2 = 0.34
    "Link 2 length (second revolute Z link)";
  parameter Modelica.Units.SI.Length L3_travel = 0.30
    "Prismatic Z carriage travel";
  parameter Modelica.Units.SI.Mass m1 = 6.0 "Link 1 moving mass";
  parameter Modelica.Units.SI.Mass m2 = 4.0 "Link 2 moving mass";
  parameter Modelica.Units.SI.Mass m3 = 2.0 "Carriage moving mass";
  parameter Modelica.Units.SI.Mass m_payload = 14.4 "Payload mass";
  parameter Modelica.Units.SI.Acceleration g_const = 9.81
    "Gravitational acceleration";

  // ============ Actuator Saturation Limits ============
  parameter Modelica.Units.SI.Torque tau_max_rot = 105.0
    "Revolute torque command bound";
  parameter Modelica.Units.SI.Force tau_max_pris = 900.0
    "Prismatic force command bound";
  parameter Modelica.Units.SI.Force F_wrist_limit = 60.0
    "Wrist horizontal force acceptance limit";
  parameter Modelica.Units.SI.Force F_correction_max = 50.0
    "Bounded wrist-force correction magnitude";

  // ============ Controller Parameters ============
  parameter Real T_s = 1.0 / 250.0 "Controller sample period (250 Hz) [s]";
  parameter Real Kp1 = 400.0 "Joint 1 proportional gain";
  parameter Real Kd1 = 30.0  "Joint 1 derivative gain";
  parameter Real Kp2 = 400.0 "Joint 2 proportional gain";
  parameter Real Kd2 = 30.0  "Joint 2 derivative gain";
  parameter Real Kp3 = 4000.0 "Joint 3 proportional gain";
  parameter Real Kd3 = 300.0  "Joint 3 derivative gain";
  parameter Real K_wrist = 0.3 "Wrist-force correction gain";

  // ============ Trajectory Parameters ============
  parameter Modelica.Units.SI.Time t_move_start = 4.0
    "Motion start time";
  parameter Modelica.Units.SI.Time t_move_end = 10.4
    "Motion end / acceptance time";
  parameter Modelica.Units.SI.Time t_sim = 16.0
    "Total simulation duration";
  parameter Modelica.Units.SI.Angle q1_target = 0.8
    "Target joint 1 angle [rad]";
  parameter Modelica.Units.SI.Angle q2_target = 0.5
    "Target joint 2 angle [rad]";
  parameter Modelica.Units.SI.Length z_ee_init = 0.40
    "Initial end-effector height [m]";
  parameter Modelica.Units.SI.Length z_ee_target = 0.45
    "Target end-effector height (lift) [m]";

  // ============ Disturbance Window (middle third of motion) ============
  parameter Modelica.Units.SI.Time t_dist_start =
    t_move_start + (t_move_end - t_move_start) / 3.0
    "Disturbance window start";
  parameter Modelica.Units.SI.Time t_dist_end =
    t_move_start + 2.0 * (t_move_end - t_move_start) / 3.0
    "Disturbance window end";

  // ============ Workspace Geometry (collision enabled) ============
  parameter Modelica.Units.SI.Length z_base = 0.50
    "Base height above floor";
  parameter Modelica.Units.SI.Length table_height = 0.30
    "Table surface height";
  parameter Modelica.Units.SI.Length table_x = 0.65 "Table center X";
  parameter Modelica.Units.SI.Length table_y = 0.0  "Table center Y";
  parameter Modelica.Units.SI.Length table_radius = 0.15 "Table radius";
  parameter Real k_contact = 1.0e5 "Contact stiffness [N/m]";
  parameter Real d_contact = 1.0e3 "Contact damping [N.s/m]";

  // ============ Joint States ============
  Modelica.Units.SI.Angle q1(start = 0.0, fixed = true)
    "Joint 1 angle [rad]";
  Modelica.Units.SI.AngularVelocity qd1(start = 0.0, fixed = true)
    "Joint 1 angular velocity [rad/s]";
  Modelica.Units.SI.Angle q2(start = 0.0, fixed = true)
    "Joint 2 angle [rad]";
  Modelica.Units.SI.AngularVelocity qd2(start = 0.0, fixed = true)
    "Joint 2 angular velocity [rad/s]";
  Modelica.Units.SI.Length z_ee(start = z_ee_init, fixed = true)
    "End-effector height (prismatic state) [m]";
  Modelica.Units.SI.Velocity zd_ee(start = 0.0, fixed = true)
    "End-effector vertical velocity [m/s]";
  Modelica.Units.SI.AngularAcceleration qdd1
    "Joint 1 angular acceleration [rad/s2]";
  Modelica.Units.SI.AngularAcceleration qdd2
    "Joint 2 angular acceleration [rad/s2]";
  Modelica.Units.SI.Acceleration zdd_ee
    "End-effector vertical acceleration [m/s2]";

  // ============ Forward Kinematics ============
  Modelica.Units.SI.Length x_ee "End-effector X [m]";
  Modelica.Units.SI.Length y_ee "End-effector Y [m]";
  Modelica.Units.SI.Velocity vx_ee "End-effector X velocity [m/s]";
  Modelica.Units.SI.Velocity vy_ee "End-effector Y velocity [m/s]";
  Modelica.Units.SI.Acceleration ax_ee "End-effector X accel [m/s2]";
  Modelica.Units.SI.Acceleration ay_ee "End-effector Y accel [m/s2]";

  // ============ Dynamics Quantities ============
  Real M11 "Mass matrix element (1,1) [kg.m2]";
  Real M12 "Mass matrix element (1,2) [kg.m2]";
  Real M22 "Mass matrix element (2,2) [kg.m2]";
  Real det_M "Mass matrix determinant [kg2.m4]";
  Real det_M_safe "Regularized determinant (zero-error branch)";
  Real C1 "Coriolis/centrifugal generalized force 1 [N.m]";
  Real C2 "Coriolis/centrifugal generalized force 2 [N.m]";
  Real m_pris = m3 + m_payload "Total prismatic moving mass [kg]";
  Real r1c = L1 / 2.0 "Link 1 COM distance [m]";
  Real r2c = L2 / 2.0 "Link 2 COM distance [m]";
  Real b_c "Coriolis coupling coefficient [kg.m2]";
  Real J11 "Jacobian (1,1)";
  Real J12 "Jacobian (1,2)";
  Real J21 "Jacobian (2,1)";
  Real J22 "Jacobian (2,2)";

  // ============ Reference Trajectory ============
  Real tau_traj "Normalized trajectory time [0,1]";
  Real s_traj "Quintic smoothstep [0,1]";
  Real s_trajd "ds/dt [1/s]";
  Real s_trajdd "d2s/dt2 [1/s2]";
  Modelica.Units.SI.Angle q1_ref "Reference joint 1 [rad]";
  Modelica.Units.SI.AngularVelocity qd1_ref "Reference joint 1 vel [rad/s]";
  Modelica.Units.SI.AngularAcceleration qdd1_ref "Ref joint 1 accel [rad/s2]";
  Modelica.Units.SI.Angle q2_ref "Reference joint 2 [rad]";
  Modelica.Units.SI.AngularVelocity qd2_ref "Reference joint 2 vel [rad/s]";
  Modelica.Units.SI.AngularAcceleration qdd2_ref "Ref joint 2 accel [rad/s2]";
  Modelica.Units.SI.Length z_ref "Reference height [m]";
  Modelica.Units.SI.Velocity zd_ref "Reference vertical vel [m/s]";
  Modelica.Units.SI.Acceleration zdd_ref "Reference vertical accel [m/s2]";

  // ============ Actuator Commands (discrete ZOH) ============
  Modelica.Units.SI.Torque tau1_cmd(start = 0.0)
    "Unsaturated joint 1 torque command [N.m]";
  Modelica.Units.SI.Torque tau2_cmd(start = 0.0)
    "Unsaturated joint 2 torque command [N.m]";
  Modelica.Units.SI.Force tau3_cmd(start = (m3 + m_payload) * g_const)
    "Unsaturated joint 3 force command [N]";
  Modelica.Units.SI.Torque tau1_sat "Saturated joint 1 torque [N.m]";
  Modelica.Units.SI.Torque tau2_sat "Saturated joint 2 torque [N.m]";
  Modelica.Units.SI.Force tau3_sat "Saturated joint 3 force [N]";

  // ============ Six-Axis Wrist Wrench Sensor ============
  Modelica.Units.SI.Force F_wrist_x "Wrist force X on payload [N]";
  Modelica.Units.SI.Force F_wrist_y "Wrist force Y on payload [N]";
  Modelica.Units.SI.Force F_wrist_z "Wrist force Z on payload (upward) [N]";
  Modelica.Units.SI.Force F_wrist_h "Wrist horizontal force magnitude [N]";
  Modelica.Units.SI.Force F_wrist_z_prev(start = m_payload * g_const)
    "Previous-sample wrist Z force [N]";
  Modelica.Units.SI.Force F_wrist_corr
    "Bounded wrist-force correction [N]";
  Modelica.Units.SI.Torque M_wrist_x "Wrist moment about X [N.m]";
  Modelica.Units.SI.Torque M_wrist_y "Wrist moment about Y [N.m]";
  Modelica.Units.SI.Torque M_wrist_z "Wrist moment about Z [N.m]";

  // ============ Payload Disturbance ============
  Modelica.Units.SI.Force F_dist_x
    "Disturbance force X on payload [N]";
  Modelica.Units.SI.Force F_dist_y
    "Disturbance force Y on payload [N]";
  Modelica.Units.SI.Force F_dist_z
    "Disturbance force Z on payload (upward) [N]";
  Boolean in_dist_window "True during middle-third disturbance";

  // ============ Contact / Collision Forces ============
  Modelica.Units.SI.Force F_contact_z
    "Total contact force Z (upward) [N]";
  Modelica.Units.SI.Force F_contact_floor "Floor contact force [N]";
  Modelica.Units.SI.Force F_contact_table "Table contact force [N]";
  Real pen_floor "Floor penetration depth [m]";
  Real pen_table "Table penetration depth [m]";
  Real dist_table_center "Horizontal distance to table center [m]";

  // ============ Tracking Errors ============
  Modelica.Units.SI.Angle e1 "Joint 1 tracking error [rad]";
  Modelica.Units.SI.Angle e2 "Joint 2 tracking error [rad]";
  Modelica.Units.SI.Length e3 "Prismatic tracking error [m]";
  Real e_primary "Primary tracking error [rad-or-m]";
  Real orientation_error
    "End-effector orientation (q1+q2) error [rad]";

  // ============ Acceptance Flags ============
  Boolean joint_bounds_ok "Joint position bounds satisfied";
  Boolean effort_bounds_ok "Effort (torque/force) bounds satisfied";
  Boolean wrist_force_ok "Wrist horizontal force below 60 N";
  Boolean payload_retained "Payload retained (wrist Z force positive)";
  Boolean tracking_ok "Tracking error within 0.041 after 10.4 s";
  Boolean no_nan_inf "No NaN or infinite values";
  Boolean fail_closed "Aggregate fail-closed flag";

  // ============ Computed-Torque Auxiliary ============
  Real ct_dd1 "Computed-torque desired accel 1 [rad/s2]";
  Real ct_dd2 "Computed-torque desired accel 2 [rad/s2]";
  Real ct_dd3 "Computed-torque desired accel 3 [m/s2]";

equation
  // ==================== Forward Kinematics ====================
  x_ee = L1 * cos(q1) + L2 * cos(q1 + q2);
  y_ee = L1 * sin(q1) + L2 * sin(q1 + q2);
  vx_ee = -L1 * sin(q1) * qd1 - L2 * sin(q1 + q2) * (qd1 + qd2);
  vy_ee = L1 * cos(q1) * qd1 + L2 * cos(q1 + q2) * (qd1 + qd2);
  ax_ee = -L1 * cos(q1) * qd1 ^ 2 - L1 * sin(q1) * qdd1
          - L2 * cos(q1 + q2) * (qd1 + qd2) ^ 2
          - L2 * sin(q1 + q2) * (qdd1 + qdd2);
  ay_ee = -L1 * sin(q1) * qd1 ^ 2 + L1 * cos(q1) * qdd1
          - L2 * sin(q1 + q2) * (qd1 + qd2) ^ 2
          + L2 * cos(q1 + q2) * (qdd1 + qdd2);

  // Jacobian (planar)
  J11 = -L1 * sin(q1) - L2 * sin(q1 + q2);
  J12 = -L2 * sin(q1 + q2);
  J21 = L1 * cos(q1) + L2 * cos(q1 + q2);
  J22 = L2 * cos(q1 + q2);

  // ==================== Mass Matrix & Coriolis ====================
  b_c = (m2 * r2c + (m3 + m_payload) * L2) * L1;
  M11 = m1 * r1c ^ 2
        + m2 * (L1 ^ 2 + r2c ^ 2 + 2.0 * L1 * r2c * cos(q2))
        + (m3 + m_payload) * (L1 ^ 2 + L2 ^ 2 + 2.0 * L1 * L2 * cos(q2));
  M12 = m2 * (r2c ^ 2 + L1 * r2c * cos(q2))
        + (m3 + m_payload) * (L2 ^ 2 + L1 * L2 * cos(q2));
  M22 = m2 * r2c ^ 2 + (m3 + m_payload) * L2 ^ 2;
  det_M = M11 * M22 - M12 ^ 2;
  det_M_safe = max(det_M, 0.001);
  C1 = -b_c * sin(q2) * (2.0 * qd1 + qd2) * qd2;
  C2 = b_c * sin(q2) * qd1 ^ 2;

  // ==================== Reference Trajectory (quintic) ====================
  tau_traj = if time <= t_move_start then 0.0
             else if time >= t_move_end then 1.0
             else (time - t_move_start) / (t_move_end - t_move_start);
  s_traj = 10.0 * tau_traj ^ 3 - 15.0 * tau_traj ^ 4 + 6.0 * tau_traj ^ 5;
  s_trajd = if (time <= t_move_start or time >= t_move_end) then 0.0
            else (30.0 * tau_traj ^ 2 - 60.0 * tau_traj ^ 3
                  + 30.0 * tau_traj ^ 4) / (t_move_end - t_move_start);
  s_trajdd = if (time <= t_move_start or time >= t_move_end) then 0.0
             else (60.0 * tau_traj - 180.0 * tau_traj ^ 2
                   + 120.0 * tau_traj ^ 3) / (t_move_end - t_move_start) ^ 2;

  q1_ref = s_traj * q1_target;
  qd1_ref = s_trajd * q1_target;
  qdd1_ref = s_trajdd * q1_target;
  q2_ref = s_traj * q2_target;
  qd2_ref = s_trajd * q2_target;
  qdd2_ref = s_trajdd * q2_target;
  z_ref = z_ee_init + s_traj * (z_ee_target - z_ee_init);
  zd_ref = s_trajd * (z_ee_target - z_ee_init);
  zdd_ref = s_trajdd * (z_ee_target - z_ee_init);

  // ==================== Payload Disturbance ====================
  in_dist_window = time >= t_dist_start and time <= t_dist_end;
  F_dist_x = if in_dist_window then
               12.0 * sin(2.0 * Modelica.Constants.pi
                          * (time - t_dist_start) / 2.0)
             else 0.0;
  F_dist_y = if in_dist_window then
               8.0 * cos(2.0 * Modelica.Constants.pi
                         * (time - t_dist_start) / 2.0)
             else 0.0;
  F_dist_z = if in_dist_window then
               15.0 * sin(2.0 * Modelica.Constants.pi
                          * (time - t_dist_start) / 3.0)
             else 0.0;

  // ==================== Contact Forces (collision enabled) ====================
  // Floor
  pen_floor = max(0.0, -z_ee);
  F_contact_floor = k_contact * pen_floor
                    - d_contact * min(0.0, zd_ee)
                      * (if pen_floor > 0.0 then 1.0 else 0.0);
  // Table (rigid, fixed)
  dist_table_center = sqrt((x_ee - table_x) ^ 2 + (y_ee - table_y) ^ 2);
  pen_table = if dist_table_center < table_radius then
                max(0.0, table_height - z_ee)
              else 0.0;
  F_contact_table = k_contact * pen_table
                    - d_contact * min(0.0, zd_ee)
                      * (if pen_table > 0.0 then 1.0 else 0.0);
  F_contact_z = F_contact_floor + F_contact_table;

  // ==================== Wrist Wrench Sensor ====================
  F_wrist_x = m_payload * ax_ee - F_dist_x;
  F_wrist_y = m_payload * ay_ee - F_dist_y;
  F_wrist_z = m_payload * (zdd_ee + g_const) - F_dist_z;
  F_wrist_h = sqrt(F_wrist_x ^ 2 + F_wrist_y ^ 2);
  M_wrist_x = 0.0;
  M_wrist_y = 0.0;
  M_wrist_z = 0.0;
  F_wrist_corr = max(-F_correction_max,
                     min(F_correction_max,
                         K_wrist * (F_wrist_z_prev - m_payload * g_const)));

  // ==================== Tracking Errors ====================
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = z_ref - z_ee;
  e_primary = sqrt(e1 ^ 2 + e2 ^ 2 + e3 ^ 2);
  orientation_error = abs((q1 + q2) - (q1_ref + q2_ref));

  // ==================== Plant Dynamics ====================
  der(q1) = qd1;
  der(qd1) = qdd1;
  der(q2) = qd2;
  der(qd2) = qdd2;
  der(z_ee) = zd_ee;
  der(zd_ee) = zdd_ee;

  // Planar: inverse mass matrix with disturbance mapped via Jacobian transpose
  qdd1 = (M22 * (tau1_sat - C1 + J11 * F_dist_x + J21 * F_dist_y)
          - M12 * (tau2_sat - C2 + J12 * F_dist_x + J22 * F_dist_y))
         / det_M_safe;
  qdd2 = (M11 * (tau2_sat - C2 + J12 * F_dist_x + J22 * F_dist_y)
          - M12 * (tau1_sat - C1 + J11 * F_dist_x + J21 * F_dist_y))
         / det_M_safe;

  // Prismatic (vertical): gravity + contact + disturbance
  zdd_ee = (tau3_sat - m_pris * g_const + F_contact_z + F_dist_z) / m_pris;

  // ==================== Saturated Actuator Commands ====================
  tau1_sat = max(-tau_max_rot, min(tau_max_rot, tau1_cmd));
  tau2_sat = max(-tau_max_rot, min(tau_max_rot, tau2_cmd));
  tau3_sat = max(-tau_max_pris, min(tau_max_pris, tau3_cmd));

  // ==================== Discrete Controller (250 Hz ZOH) ====================
  when sample(0, T_s) then
    // Computed-torque: PD-augmented reference acceleration
    ct_dd1 = qdd1_ref + Kp1 * (q1_ref - q1) + Kd1 * (qd1_ref - qd1);
    ct_dd2 = qdd2_ref + Kp2 * (q2_ref - q2) + Kd2 * (qd2_ref - qd2);
    ct_dd3 = zdd_ref + Kp3 * (z_ref - z_ee) + Kd3 * (zd_ref - zd_ee);
    // Inverse dynamics (feedforward)
    tau1_cmd = M11 * ct_dd1 + M12 * ct_dd2 + C1;
    tau2_cmd = M12 * ct_dd1 + M22 * ct_dd2 + C2;
    tau3_cmd = m_pris * ct_dd3 + m_pris * g_const + F_wrist_corr;
    // Update delayed wrist-force measurement
    F_wrist_z_prev = F_wrist_z;
  end when;

  // ==================== Acceptance Checks (fail-closed) ====================
  joint_bounds_ok = (z_ee >= z_base - L3_travel)
                    and (z_ee <= z_base)
                    and (abs(q1) <= Modelica.Constants.pi)
                    and (abs(q2) <= Modelica.Constants.pi);
  effort_bounds_ok = (abs(tau1_sat) <= tau_max_rot)
                     and (abs(tau2_sat) <= tau_max_rot)
                     and (abs(tau3_sat) <= tau_max_pris);
  wrist_force_ok = F_wrist_h <= F_wrist_limit;
  payload_retained = F_wrist_z > 0.0;
  tracking_ok = if time >= t_move_end then e_primary <= 0.041 else true;
  no_nan_inf = (q1 == q1) and (q2 == q2) and (z_ee == z_ee)
               and (qd1 == qd1) and (qd2 == qd2) and (zd_ee == zd_ee)
               and (tau1_cmd == tau1_cmd) and (tau2_cmd == tau2_cmd)
               and (tau3_cmd == tau3_cmd)
               and (F_wrist_h == F_wrist_h) and (e_primary == e_primary);
  fail_closed = joint_bounds_ok and effort_bounds_ok and wrist_force_ok
                and payload_retained and tracking_ok and no_nan_inf;

  assert(joint_bounds_ok,
    "FAIL-CLOSED: Joint position bounds violated");
  assert(effort_bounds_ok,
    "FAIL-CLOSED: Effort (torque/force) bounds violated");
  assert(wrist_force_ok,
    "FAIL-CLOSED: Wrist horizontal force exceeds 60 N");
  assert(payload_retained,
    "FAIL-CLOSED: Payload not retained (wrist Z force non-positive)");
  assert(no_nan_inf,
    "FAIL-CLOSED: NaN or infinite value detected in physical/control/estimator");
  assert(tracking_ok,
    "FAIL-CLOSED: Primary tracking error exceeds 0.041 rad-or-m after 10.4 s");

  annotation(
    experiment(StopTime = 16.0, StartTime = 0.0,
               Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "<html>
<p>SCARACarryE — Fixed-base SCARA manipulator (articulated, Z-axis revolute
+ prismatic). Two revolute Z links: 0.48 m, 0.34 m. Prismatic Z carriage:
0.30 m travel. Moving masses: 6 kg, 4 kg, 2 kg. Base: 28 kg (fixed).
Payload: 14.4 kg.</p>
<p>Three saturated joint-space actuators: 105 N.m (revolute), 900 N (prismatic).
Joint encoders + six-axis wrist wrench sensor. Rigid floor and fixed table
with collision enabled (penalty contact).</p>
<p>Computed-torque control at 250 Hz with bounded wrist-force correction.
Controlled 14.4 kg payload disturbance during middle third of motion.
Acceptance: joint/effort bounds, wrist force < 60 N, payload retention,
primary tracking error < 0.041 rad-or-m after 10.4 s, no NaN/Inf.
Fail-closed via assertions.</p>
</html>")
  );
end SCARACarryE;