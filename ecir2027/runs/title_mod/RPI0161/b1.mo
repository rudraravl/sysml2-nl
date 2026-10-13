model SCARACarryE
  "Fixed-base SCARA articulated manipulator with computed-torque control, saturated actuators, wrist-force correction, and payload disturbance";

  // ===== Physical Parameters =====
  parameter Real m_base = 28.0 "Cylindrical base mass [kg] (fixed to floor)";
  parameter Real L1 = 0.48 "Link 1 length [m]";
  parameter Real L2 = 0.34 "Link 2 length [m]";
  parameter Real d3_travel = 0.30 "Prismatic joint travel [m]";
  parameter Real m1 = 6.0 "Link 1 moving mass [kg]";
  parameter Real m2 = 4.0 "Link 2 moving mass [kg]";
  parameter Real m3 = 2.0 "Carriage mass [kg]";
  parameter Real m_payload = 14.4 "Payload mass [kg]";
  parameter Real I_payload = 0.05 "Nominal payload inertia about Z [kg.m2]";
  parameter Real g = Modelica.Constants.g_n "Gravitational acceleration [m/s2]";
  parameter Real base_height = 0.20 "Base height above rigid floor [m]";
  parameter Real table_x = 0.50 "Table center x position [m]";
  parameter Real table_y = 0.50 "Table center y position [m]";
  parameter Real table_height = 0.80 "Table top height [m]";
  parameter Real table_radius = 0.10 "Table radius [m]";

  // ===== Actuator Limits =====
  parameter Real tau_max = 105.0 "Max revolute joint torque [N.m]";
  parameter Real f3_max = 900.0 "Max prismatic joint force [N]";
  parameter Real F_wrist_limit = 60.0 "Wrist force limit [N]";
  parameter Real track_err_limit = 0.041 "Tracking error limit [rad or m]";
  parameter Real t_settle = 10.4 "Settling time [s]";
  parameter Real T_sim = 16.0 "Simulation duration [s]";
  parameter Real f_sample = 250.0 "Controller sample rate [Hz]";
  parameter Real T_s = 1.0 / f_sample "Sample period [s]";

  // ===== Controller Gains =====
  parameter Real Kp1 = 400.0 "Joint 1 proportional gain [1/s2]";
  parameter Real Kd1 = 40.0 "Joint 1 derivative gain [1/s]";
  parameter Real Kp2 = 300.0 "Joint 2 proportional gain [1/s2]";
  parameter Real Kd2 = 30.0 "Joint 2 derivative gain [1/s]";
  parameter Real Kp3 = 2000.0 "Joint 3 proportional gain [1/s2]";
  parameter Real Kd3 = 200.0 "Joint 3 derivative gain [1/s]";
  parameter Real Kw = 0.5 "Wrist force correction gain [dimensionless]";
  parameter Real F_corr_max = 50.0 "Max wrist force correction magnitude [N]";

  // ===== Joint Limit Spring-Damper =====
  parameter Real k_limit = 10000.0 "Joint limit stiffness [N/m]";
  parameter Real c_limit = 100.0 "Joint limit damping [N.s/m]";

  // ===== Trajectory Parameters =====
  parameter Real q1_target = Modelica.Constants.pi / 3.0 "Joint 1 target angle [rad]";
  parameter Real q2_target = Modelica.Constants.pi / 6.0 "Joint 2 target angle [rad]";
  parameter Real q3_target = 0.15 "Joint 3 target displacement [m]";
  parameter Real t_traj_start = 1.0 "Trajectory start time [s]";
  parameter Real t_traj_end = 8.0 "Trajectory end time [s]";

  // ===== Joint States (observable) =====
  Real q1(start=0.0, fixed=true) "Joint 1 angle [rad]";
  Real q2(start=0.0, fixed=true) "Joint 2 relative angle [rad]";
  Real q3(start=0.0, fixed=true) "Joint 3 displacement [m]";
  Real qd1(start=0.0, fixed=true) "Joint 1 velocity [rad/s]";
  Real qd2(start=0.0, fixed=true) "Joint 2 velocity [rad/s]";
  Real qd3(start=0.0, fixed=true) "Joint 3 velocity [m/s]";
  Real qdd1 "Joint 1 acceleration [rad/s2]";
  Real qdd2 "Joint 2 acceleration [rad/s2]";
  Real qdd3 "Joint 3 acceleration [m/s2]";

  // ===== Saturated Actuator Commands (discrete, observable) =====
  discrete Real tau1_sat(start=0.0) "Saturated joint 1 torque [N.m]";
  discrete Real tau2_sat(start=0.0) "Saturated joint 2 torque [N.m]";
  discrete Real f3_sat(start=0.0) "Saturated joint 3 force [N]";

  // ===== Reference Trajectories (observable) =====
  Real q1_ref "Joint 1 reference [rad]";
  Real q2_ref "Joint 2 reference [rad]";
  Real q3_ref "Joint 3 reference [m]";
  Real qd1_ref "Joint 1 reference velocity [rad/s]";
  Real qd2_ref "Joint 2 reference velocity [rad/s]";
  Real qd3_ref "Joint 3 reference velocity [m/s]";
  Real qdd1_ref "Joint 1 reference acceleration [rad/s2]";
  Real qdd2_ref "Joint 2 reference acceleration [rad/s2]";
  Real qdd3_ref "Joint 3 reference acceleration [m/s2]";

  // ===== Tracking Errors (observable) =====
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [m]";
  Real e_phi "Orientation tracking error [rad]";
  Real track_err "Combined tracking error [rad or m]";

  // ===== End-Effector Kinematics (observable) =====
  Real ee_x "End-effector x position [m]";
  Real ee_y "End-effector y position [m]";
  Real ee_z "End-effector z position [m]";
  Real ee_phi "End-effector orientation angle [rad]";

  // ===== Dynamics Terms =====
  Real M11 "Mass matrix element (1,1) [kg.m2]";
  Real M12 "Mass matrix element (1,2) [kg.m2]";
  Real M22 "Mass matrix element (2,2) [kg.m2]";
  Real M33 "Mass matrix element (3,3) [kg]";
  Real det_M "Determinant of 2x2 mass sub-matrix [kg2.m4]";
  Real C1 "Coriolis/centrifugal term joint 1 [N.m]";
  Real C2 "Coriolis/centrifugal term joint 2 [N.m]";
  Real G3 "Gravity term joint 3 [N]";
  Real f3_limit "Joint limit reaction force [N]";

  // ===== Wrist Wrench Sensor (observable) =====
  Real Fx_wrist "Wrist force x [N]";
  Real Fy_wrist "Wrist force y [N]";
  Real Fz_wrist "Wrist force z quasi-static for control [N]";
  Real Fz_wrist_meas "Wrist force z dynamic measured [N]";
  Real Tx_wrist "Wrist torque x [N.m]";
  Real Ty_wrist "Wrist torque y [N.m]";
  Real Tz_wrist "Wrist torque z [N.m]";
  Real F_wrist_mag "Wrist dynamic force magnitude [N]";
  Real F_wrist_corr "Bounded wrist force correction [N]";

  // ===== Disturbance =====
  Real F_dist "Payload disturbance force [N]";
  Boolean disturbance_active "Disturbance active flag";

  // ===== Collision Detection =====
  Boolean collision_floor "Floor collision detected";
  Boolean collision_table "Table collision detected";
  Boolean collision_joint_limit "Joint limit violation detected";
  Real dist_to_table "End-effector distance to table center [m]";

  // ===== Acceptance Criteria =====
  Boolean ok_joint_bounds "Joint position within limits";
  Boolean ok_effort_bounds "Actuator effort within limits";
  Boolean ok_wrist_force "Wrist force below limit";
  Boolean ok_payload_retained "Payload retained";
  Boolean ok_tracking "Tracking error below threshold after settling";
  Boolean ok_no_nan "No NaN or infinite values";
  Boolean fail_closed "Fail-closed acceptance";

protected
  function smoothstep
    "Smooth step function from 0 to 1 using cosine profile"
    input Real t;
    input Real t0;
    input Real t1;
    output Real s;
  algorithm
    if t <= t0 then
      s := 0.0;
    elseif t >= t1 then
      s := 1.0;
    else
      s := 0.5 - 0.5 * cos(Modelica.Constants.pi * (t - t0) / (t1 - t0));
    end if;
  end smoothstep;

  function smoothstep_d
    "First derivative of smoothstep"
    input Real t;
    input Real t0;
    input Real t1;
    output Real sd;
  algorithm
    if (t <= t0) or (t >= t1) then
      sd := 0.0;
    else
      sd := 0.5 * Modelica.Constants.pi / (t1 - t0) *
            sin(Modelica.Constants.pi * (t - t0) / (t1 - t0));
    end if;
  end smoothstep_d;

  function smoothstep_dd
    "Second derivative of smoothstep"
    input Real t;
    input Real t0;
    input Real t1;
    output Real sdd;
  algorithm
    if (t <= t0) or (t >= t1) then
      sdd := 0.0;
    else
      sdd := 0.5 * Modelica.Constants.pi * Modelica.Constants.pi / ((t1 - t0) * (t1 - t0)) *
            cos(Modelica.Constants.pi * (t - t0) / (t1 - t0));
    end if;
  end smoothstep_dd;

  function is_finite
    "Check if value is finite (not NaN, not infinite)"
    input Real x;
    output Boolean y;
  algorithm
    y := abs(x) < 1.0e300;
  end is_finite;

equation
  // ===== Reference Trajectory (smooth cosine interpolation) =====
  q1_ref = q1_target * smoothstep(time, t_traj_start, t_traj_end);
  q2_ref = q2_target * smoothstep(time, t_traj_start, t_traj_end);
  q3_ref = q3_target * smoothstep(time, t_traj_start, t_traj_end);
  qd1_ref = q1_target * smoothstep_d(time, t_traj_start, t_traj_end);
  qd2_ref = q2_target * smoothstep_d(time, t_traj_start, t_traj_end);
  qd3_ref = q3_target * smoothstep_d(time, t_traj_start, t_traj_end);
  qdd1_ref = q1_target * smoothstep_dd(time, t_traj_start, t_traj_end);
  qdd2_ref = q2_target * smoothstep_dd(time, t_traj_start, t_traj_end);
  qdd3_ref = q3_target * smoothstep_dd(time, t_traj_start, t_traj_end);

  // ===== Forward Kinematics =====
  ee_x = L1 * cos(q1) + L2 * cos(q1 + q2);
  ee_y = L1 * sin(q1) + L2 * sin(q1 + q2);
  ee_z = base_height + q3;
  ee_phi = q1 + q2;

  // ===== Mass Matrix (SCARA dynamics, point-mass links) =====
  M11 = m1 * (L1 / 2.0) * (L1 / 2.0)
        + (m2 + m3 + m_payload) * L1 * L1
        + m2 * (L2 / 2.0) * (L2 / 2.0)
        + (m3 + m_payload) * L2 * L2
        + 2.0 * (m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * cos(q2);
  M12 = m2 * (L2 / 2.0) * (L2 / 2.0)
        + (m3 + m_payload) * L2 * L2
        + (m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * cos(q2);
  M22 = m2 * (L2 / 2.0) * (L2 / 2.0) + (m3 + m_payload) * L2 * L2;
  M33 = m3 + m_payload;
  det_M = max(M11 * M22 - M12 * M12, 1.0e-10);

  // ===== Coriolis and Centrifugal Terms =====
  C1 = -(m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * sin(q2)
        * (qd2 * qd2 + 2.0 * qd1 * qd2);
  C2 = (m2 * (L2 / 2.0) + (m3 + m_payload) * L2) * L1 * sin(q2) * qd1 * qd1;

  // ===== Gravity (only prismatic joint) =====
  G3 = (m3 + m_payload) * g;

  // ===== Joint Limit Reaction Force (spring-damper at travel bounds) =====
  f3_limit = if q3 < 0.0 then
               (-k_limit * q3 - c_limit * qd3)
             elseif q3 > d3_travel then
               (-k_limit * (q3 - d3_travel) - c_limit * qd3)
             else
               0.0;

  // ===== Tracking Errors =====
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;
  e_phi = (q1_ref + q2_ref) - (q1 + q2);
  track_err = max(abs(e1), max(abs(e2), max(abs(e3), abs(e_phi))));

  // ===== Disturbance: controlled payload middle-third sinusoid =====
  disturbance_active = (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0);
  F_dist = if disturbance_active then
             25.0 * sin(2.0 * Modelica.Constants.pi * 0.5 * (time - T_sim / 3.0))
           else
             0.0;

  // ===== Wrist Wrench Sensor (six-axis) =====
  // Horizontal forces from payload inertial acceleration at end-effector
  Fx_wrist = m_payload * (-L1 * cos(q1) * qd1 * qd1 - L1 * sin(q1) * qdd1
             - L2 * cos(q1 + q2) * (qd1 + qd2) * (qd1 + qd2)
             - L2 * sin(q1 + q2) * (qdd1 + qdd2));
  Fy_wrist = m_payload * (-L1 * sin(q1) * qd1 * qd1 + L1 * cos(q1) * qdd1
             - L2 * sin(q1 + q2) * (qd1 + qd2) * (qd1 + qd2)
             + L2 * cos(q1 + q2) * (qdd1 + qdd2));
  // Quasi-static vertical force for control (no acceleration dependency to avoid algebraic loop)
  Fz_wrist = m_payload * g - F_dist * m_payload / (m3 + m_payload);
  // Dynamic measured vertical force for sensor trace
  Fz_wrist_meas = m_payload * (qdd3 + g) - F_dist * m_payload / (m3 + m_payload);
  // Wrist torques
  Tx_wrist = 0.0;
  Ty_wrist = 0.0;
  Tz_wrist = I_payload * (qdd1 + qdd2);

  // Dynamic wrist force magnitude (gravity-compensated) with zero-error branch
  F_wrist_mag = if (Fx_wrist * Fx_wrist + Fy_wrist * Fy_wrist + (Fz_wrist_meas - m_payload * g) * (Fz_wrist_meas - m_payload * g)) > 1.0e-12 then
                  sqrt(Fx_wrist * Fx_wrist + Fy_wrist * Fy_wrist + (Fz_wrist_meas - m_payload * g) * (Fz_wrist_meas - m_payload * g))
                else
                  0.0;

  // Bounded wrist force correction (continuous, quasi-static, no algebraic loop)
  F_wrist_corr = max(-F_corr_max, min(F_corr_max, Kw * (Fz_wrist - m_payload * g)));

  // ===== Explicit Plant Dynamics =====
  // Revolute joints: solve 2x2 mass matrix explicitly
  qdd1 = (M22 * (tau1_sat - C1) - M12 * (tau2_sat - C2)) / det_M;
  qdd2 = (M11 * (tau2_sat - C2) - M12 * (tau1_sat - C1)) / det_M;
  // Prismatic joint: actuator force - gravity + disturbance + limit reaction
  qdd3 = (f3_sat - G3 + F_dist + f3_limit) / M33;

  // ===== State Derivatives =====
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  der(qd1) = qdd1;
  der(qd2) = qdd2;
  der(qd3) = qdd3;

  // ===== Discrete Controller at 250 Hz: Computed Torque with Saturation =====
  when sample(0, T_s) then
    tau1_sat = max(-tau_max, min(tau_max,
      M11 * (qdd1_ref + Kd1 * (qd1_ref - qd1) + Kp1 * e1)
      + M12 * (qdd2_ref + Kd2 * (qd2_ref - qd2) + Kp2 * e2)
      + C1));
    tau2_sat = max(-tau_max, min(tau_max,
      M12 * (qdd1_ref + Kd1 * (qd1_ref - qd1) + Kp1 * e1)
      + M22 * (qdd2_ref + Kd2 * (qd2_ref - qd2) + Kp2 * e2)
      + C2));
    f3_sat = max(-f3_max, min(f3_max,
      M33 * (qdd3_ref + Kd3 * (qd3_ref - qd3) + Kp3 * e3)
      + G3 - F_wrist_corr));
  end when;

  // ===== Collision Detection (rigid floor and fixed table) =====
  collision_floor = ee_z < 0.001;
  dist_to_table = sqrt(max((ee_x - table_x) * (ee_x - table_x) + (ee_y - table_y) * (ee_y - table_y), 1.0e-12));
  collision_table = (dist_to_table < table_radius) and (ee_z < table_height);
  collision_joint_limit = (q3 < -0.01) or (q3 > d3_travel + 0.01);

  // ===== Acceptance Criteria (fail-closed) =====
  ok_joint_bounds = (q3 >= -0.001) and (q3 <= d3_travel + 0.001)
                    and (abs(q1) <= Modelica.Constants.pi)
                    and (abs(q2) <= Modelica.Constants.pi);
  ok_effort_bounds = (abs(tau1_sat) <= tau_max + 0.1)
                     and (abs(tau2_sat) <= tau_max + 0.1)
                     and (abs(f3_sat) <= f3_max + 0.1);
  ok_wrist_force = F_wrist_mag < F_wrist_limit;
  ok_payload_retained = Fz_wrist_meas > 0.0;
  ok_tracking = if time >= t_settle then track_err < track_err_limit else true;
  ok_no_nan = is_finite(q1) and is_finite(q2) and is_finite(q3)
              and is_finite(qd1) and is_finite(qd2) and is_finite(qd3)
              and is_finite(tau1_sat) and is_finite(tau2_sat) and is_finite(f3_sat)
              and is_finite(F_wrist_mag) and is_finite(F_wrist_corr)
              and is_finite(e1) and is_finite(e2) and is_finite(e3)
              and is_finite(track_err) and is_finite(det_M);
  fail_closed = ok_joint_bounds and ok_effort_bounds and ok_wrist_force
                and ok_payload_retained and ok_tracking and ok_no_nan;

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.001),
    Documentation(info = "SCARA fixed-base articulated manipulator with 28 kg cylindrical base, two revolute Z links (0.48 m, 0.34 m), prismatic Z carriage (0.30 m travel), moving masses 6/4/2 kg, 14.4 kg payload. Computed-torque control at 250 Hz with saturated actuators (105 N.m / 900 N), bounded wrist-force correction, middle-third disturbance, collision-enabled floor and table. Fail-closed acceptance: joint bounds, effort bounds, wrist force < 60 N, payload retention, tracking error < 0.041 after 10.4 s, no NaN/infinite values."));
end SCARACarryE;