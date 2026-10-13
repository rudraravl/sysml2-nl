model SCARACarryE
  "SCARA manipulator with computed-torque control";

  parameter Real m_base = 28.0 "Cylindrical base mass [kg]";
  parameter Real L1 = 0.48 "Link 1 length [m]";
  parameter Real L2 = 0.34 "Link 2 length [m]";
  parameter Real d3_travel = 0.30 "Prismatic joint travel [m]";
  parameter Real m1 = 6.0 "Link 1 moving mass [kg]";
  parameter Real m2 = 4.0 "Link 2 moving mass [kg]";
  parameter Real m3 = 2.0 "Carriage mass [kg]";
  parameter Real m_payload = 14.4 "Payload mass [kg]";
  parameter Real I_payload = 0.05 "Payload inertia about Z [kg.m2]";
  parameter Real g = 9.80665 "Gravitational acceleration [m/s2]";
  parameter Real base_height = 0.20 "Base height above floor [m]";
  parameter Real table_x = 0.50 "Table center x [m]";
  parameter Real table_y = 0.50 "Table center y [m]";
  parameter Real table_height = 0.80 "Table top height [m]";
  parameter Real table_radius = 0.10 "Table radius [m]";

  parameter Real tau_max = 105.0 "Max revolute joint torque [N.m]";
  parameter Real f3_max = 900.0 "Max prismatic joint force [N]";
  parameter Real F_wrist_limit = 60.0 "Wrist force limit [N]";
  parameter Real track_err_limit = 0.041 "Tracking error limit [rad or m]";
  parameter Real t_settle = 10.4 "Settling time [s]";
  parameter Real T_sim = 16.0 "Simulation duration [s]";
  parameter Real T_s = 0.004 "Controller sample period [s]";

  parameter Real Kp1 = 400.0 "Joint 1 proportional gain [1/s2]";
  parameter Real Kd1 = 40.0 "Joint 1 derivative gain [1/s]";
  parameter Real Kp2 = 300.0 "Joint 2 proportional gain [1/s2]";
  parameter Real Kd2 = 30.0 "Joint 2 derivative gain [1/s]";
  parameter Real Kp3 = 2000.0 "Joint 3 proportional gain [1/s2]";
  parameter Real Kd3 = 200.0 "Joint 3 derivative gain [1/s]";
  parameter Real Kw = 0.5 "Wrist force correction gain";
  parameter Real F_corr_max = 50.0 "Max wrist force correction [N]";

  parameter Real k_limit = 10000.0 "Joint limit stiffness [N/m]";
  parameter Real c_limit = 100.0 "Joint limit damping [N.s/m]";

  parameter Real q1_target = 1.0471975511965976 "Joint 1 target angle [rad]";
  parameter Real q2_target = 0.5235987755982988 "Joint 2 target angle [rad]";
  parameter Real q3_target = 0.15 "Joint 3 target displacement [m]";
  parameter Real t_traj_start = 1.0 "Trajectory start time [s]";
  parameter Real t_traj_end = 8.0 "Trajectory end time [s]";
  parameter Real dt_traj = 7.0 "Trajectory duration [s]";

  constant Real pi = 3.141592653589793;

  Real q1(start=0.0, fixed=true) "Joint 1 angle [rad]";
  Real q2(start=0.0, fixed=true) "Joint 2 relative angle [rad]";
  Real q3(start=0.0, fixed=true) "Joint 3 displacement [m]";
  Real qd1(start=0.0, fixed=true) "Joint 1 velocity [rad/s]";
  Real qd2(start=0.0, fixed=true) "Joint 2 velocity [rad/s]";
  Real qd3(start=0.0, fixed=true) "Joint 3 velocity [m/s]";
  Real qdd1 "Joint 1 acceleration [rad/s2]";
  Real qdd2 "Joint 2 acceleration [rad/s2]";
  Real qdd3 "Joint 3 acceleration [m/s2]";

  Real s_traj "Trajectory shape 0 to 1";
  Real sd_traj "Trajectory shape derivative";
  Real sdd_traj "Trajectory shape second derivative";

  Real q1_ref "Joint 1 reference [rad]";
  Real q2_ref "Joint 2 reference [rad]";
  Real q3_ref "Joint 3 reference [m]";
  Real qd1_ref "Joint 1 reference velocity [rad/s]";
  Real qd2_ref "Joint 2 reference velocity [rad/s]";
  Real qd3_ref "Joint 3 reference velocity [m/s]";
  Real qdd1_ref "Joint 1 reference acceleration [rad/s2]";
  Real qdd2_ref "Joint 2 reference acceleration [rad/s2]";
  Real qdd3_ref "Joint 3 reference acceleration [m/s2]";

  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [m]";
  Real e_phi "Orientation tracking error [rad]";
  Real track_err "Combined tracking error [rad or m]";

  Real ee_x "End-effector x position [m]";
  Real ee_y "End-effector y position [m]";
  Real ee_z "End-effector z position [m]";
  Real ee_phi "End-effector orientation [rad]";

  Real M11 "Mass matrix element (1,1) [kg.m2]";
  Real M12 "Mass matrix element (1,2) [kg.m2]";
  Real M22 "Mass matrix element (2,2) [kg.m2]";
  Real M33 "Mass matrix element (3,3) [kg]";
  Real det_M "Determinant of 2x2 mass sub-matrix [kg2.m4]";
  Real C1 "Coriolis term joint 1 [N.m]";
  Real C2 "Coriolis term joint 2 [N.m]";
  Real G3 "Gravity term joint 3 [N]";
  Real f3_limit "Joint limit reaction force [N]";

  Real Fx_wrist "Wrist force x [N]";
  Real Fy_wrist "Wrist force y [N]";
  Real Fz_wrist "Wrist force z [N]";
  Real Tx_wrist "Wrist torque x [N.m]";
  Real Ty_wrist "Wrist torque y [N.m]";
  Real Tz_wrist "Wrist torque z [N.m]";
  Real F_wrist_mag "Wrist dynamic force magnitude [N]";
  Real F_wrist_corr "Bounded wrist force correction [N]";

  Real F_dist "Payload disturbance force [N]";
  Boolean disturbance_active "Disturbance active flag";

  Boolean collision_floor "Floor collision detected";
  Boolean collision_table "Table collision detected";
  Boolean collision_joint_limit "Joint limit violation detected";
  Real dist_to_table "Distance to table center [m]";

  discrete Real tau1_cmd(start=0.0) "Discrete joint 1 torque command [N.m]";
  discrete Real tau2_cmd(start=0.0) "Discrete joint 2 torque command [N.m]";
  discrete Real f3_cmd(start=0.0) "Discrete joint 3 force command [N]";
  Real tau1_sat "Saturated joint 1 torque [N.m]";
  Real tau2_sat "Saturated joint 2 torque [N.m]";
  Real f3_sat "Saturated joint 3 force [N]";

  Boolean ok_joint_bounds "Joint position within limits";
  Boolean ok_effort_bounds "Actuator effort within limits";
  Boolean ok_wrist_force "Wrist force below limit";
  Boolean ok_payload_retained "Payload retained";
  Boolean ok_tracking "Tracking error below threshold after settling";
  Boolean ok_no_nan "No NaN or infinite values";
  Boolean fail_closed "Fail-closed acceptance";

equation
  // Trajectory shape (smooth cosine interpolation)
  s_traj = if time <= t_traj_start then 0.0
           elseif time >= t_traj_end then 1.0
           else 0.5 - 0.5 * cos(pi * (time - t_traj_start) / dt_traj);

  sd_traj = if (time <= t_traj_start) or (time >= t_traj_end) then 0.0
            else 0.5 * pi / dt_traj * sin(pi * (time - t_traj_start) / dt_traj);

  sdd_traj = if (time <= t_traj_start) or (time >= t_traj_end) then 0.0
             else 0.5 * pi * pi / (dt_traj * dt_traj) * cos(pi * (time - t_traj_start) / dt_traj);

  // Reference trajectories
  q1_ref = q1_target * s_traj;
  q2_ref = q2_target * s_traj;
  q3_ref = q3_target * s_traj;
  qd1_ref = q1_target * sd_traj;
  qd2_ref = q2_target * sd_traj;
  qd3_ref = q3_target * sd_traj;
  qdd1_ref = q1_target * sdd_traj;
  qdd2_ref = q2_target * sdd_traj;
  qdd3_ref = q3_target * sdd_traj;

  // Forward kinematics
  ee_x = L1 * cos(q1) + L2 * cos(q1 + q2);
  ee_y = L1 * sin(q1) + L2 * sin(q1 + q2);
  ee_z = base_height + q3;
  ee_phi = q1 + q2;

  // Mass matrix (SCARA planar dynamics, point-mass links)
  M11 = m1 * (L1 / 2.0) ^ 2 + (m2 + m3 + m_payload) * L1 ^ 2
        + m2 * (L2 / 2.0) ^ 2 + (m3 + m_payload) * L2 ^ 2
        + 2.0 * (m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * cos(q2);
  M12 = m2 * (L2 / 2.0) ^ 2 + (m3 + m_payload) * L2 ^ 2
        + (m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * cos(q2);
  M22 = m2 * (L2 / 2.0) ^ 2 + (m3 + m_payload) * L2 ^ 2;
  M33 = m3 + m_payload;
  det_M = max(M11 * M22 - M12 ^ 2, 1.0e-10);

  // Coriolis and centrifugal terms
  C1 = -(m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * sin(q2)
        * (qd2 ^ 2 + 2.0 * qd1 * qd2);
  C2 = (m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * sin(q2) * qd1 ^ 2;

  // Gravity (prismatic joint only)
  G3 = (m3 + m_payload) * g;

  // Joint limit reaction (spring-damper at travel bounds)
  f3_limit = if q3 < 0.0 then
               (-k_limit * q3 - c_limit * qd3)
             elseif q3 > d3_travel then
               (-k_limit * (q3 - d3_travel) - c_limit * qd3)
             else
               0.0;

  // Tracking errors
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;
  e_phi = (q1_ref + q2_ref) - (q1 + q2);
  track_err = max(abs(e1), max(abs(e2), max(abs(e3), abs(e_phi))));

  // Disturbance: controlled payload middle-third sinusoid
  disturbance_active = (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0);
  F_dist = if disturbance_active then
             25.0 * sin(2.0 * pi * 0.5 * (time - T_sim / 3.0))
           else
             0.0;

  // Six-axis wrist wrench sensor
  Fx_wrist = m_payload * (-L1 * cos(q1) * qd1 ^ 2 - L1 * sin(q1) * qdd1
             - L2 * cos(q1 + q2) * (qd1 + qd2) ^ 2
             - L2 * sin(q1 + q2) * (qdd1 + qdd2));
  Fy_wrist = m_payload * (-L1 * sin(q1) * qd1 ^ 2 + L1 * cos(q1) * qdd1
             - L2 * sin(q1 + q2) * (qd1 + qd2) ^ 2
             + L2 * cos(q1 + q2) * (qdd1 + qdd2));
  Fz_wrist = m_payload * (qdd3 + g) - F_dist * m_payload / (m3 + m_payload);
  Tx_wrist = 0.0;
  Ty_wrist = 0.0;
  Tz_wrist = I_payload * (qdd1 + qdd2);

  // Gravity-compensated wrist force magnitude with zero-error branch
  F_wrist_mag = if (Fx_wrist ^ 2 + Fy_wrist ^ 2 + (Fz_wrist - m_payload * g) ^ 2) > 1.0e-12 then
                  sqrt(Fx_wrist ^ 2 + Fy_wrist ^ 2 + (Fz_wrist - m_payload * g) ^ 2)
                else
                  0.0;

  // Bounded wrist force correction
  F_wrist_corr = max(-F_corr_max, min(F_corr_max, Kw * (Fz_wrist - m_payload * g)));

  // Explicit plant dynamics
  qdd1 = (M22 * (tau1_sat - C1) - M12 * (tau2_sat - C2)) / det_M;
  qdd2 = (M11 * (tau2_sat - C2) - M12 * (tau1_sat - C1)) / det_M;
  qdd3 = (f3_sat - G3 + F_dist + f3_limit) / M33;

  // State derivatives
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  der(qd1) = qdd1;
  der(qd2) = qdd2;
  der(qd3) = qdd3;

  // Discrete computed-torque controller at 250 Hz
  when sample(0, T_s) then
    tau1_cmd = M11 * (qdd1_ref + Kd1 * (qd1_ref - qd1) + Kp1 * e1)
             + M12 * (qdd2_ref + Kd2 * (qd2_ref - qd2) + Kp2 * e2)
             + C1;
    tau2_cmd = M12 * (qdd1_ref + Kd1 * (qd1_ref - qd1) + Kp1 * e1)
             + M22 * (qdd2_ref + Kd2 * (qd2_ref - qd2) + Kp2 * e2)
             + C2;
    f3_cmd = M33 * (qdd3_ref + Kd3 * (qd3_ref - qd3) + Kp3 * e3)
           + G3 - F_wrist_corr;
  end when;

  // Actuator saturation
  tau1_sat = max(-tau_max, min(tau_max, tau1_cmd));
  tau2_sat = max(-tau_max, min(tau_max, tau2_cmd));
  f3_sat = max(-f3_max, min(f3_max, f3_cmd));

  // Collision detection (rigid floor and fixed table)
  collision_floor = ee_z < 0.001;
  dist_to_table = sqrt(max((ee_x - table_x) ^ 2 + (ee_y - table_y) ^ 2, 1.0e-12));
  collision_table = (dist_to_table < table_radius) and (ee_z < table_height);
  collision_joint_limit = (q3 < -0.01) or (q3 > d3_travel + 0.01);

  // Acceptance criteria (fail-closed)
  ok_joint_bounds = (q3 >= -0.001) and (q3 <= d3_travel + 0.001)
                    and (abs(q1) <= pi) and (abs(q2) <= pi);
  ok_effort_bounds = (abs(tau1_sat) <= tau_max + 0.1)
                     and (abs(tau2_sat) <= tau_max + 0.1)
                     and (abs(f3_sat) <= f3_max + 0.1);
  ok_wrist_force = F_wrist_mag < F_wrist_limit;
  ok_payload_retained = Fz_wrist > 0.0;
  ok_tracking = if time >= t_settle then track_err < track_err_limit else true;
  ok_no_nan = (abs(q1) < 1.0e300) and (abs(q2) < 1.0e300) and (abs(q3) < 1.0e300)
              and (abs(qd1) < 1.0e300) and (abs(qd2) < 1.0e300) and (abs(qd3) < 1.0e300)
              and (abs(tau1_sat) < 1.0e300) and (abs(tau2_sat) < 1.0e300) and (abs(f3_sat) < 1.0e300)
              and (abs(F_wrist_mag) < 1.0e300) and (abs(F_wrist_corr) < 1.0e300)
              and (abs(e1) < 1.0e300) and (abs(e2) < 1.0e300) and (abs(e3) < 1.0e300)
              and (abs(track_err) < 1.0e300) and (abs(det_M) < 1.0e300);
  fail_closed = ok_joint_bounds and ok_effort_bounds and ok_wrist_force
                and ok_payload_retained and ok_tracking and ok_no_nan;

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.001));
end SCARACarryE;