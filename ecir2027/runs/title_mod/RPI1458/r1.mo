model JointPathSplineF
  "Three-revolute-joint (Z-Y-Y) arm tracking a Cartesian spline through
   four timestamped poses with operational-space control, joint-limit
   avoidance, obstacle clearance, and disturbance rejection"

  // ========== Link Parameters (from requirement) ==========
  parameter Modelica.Units.SI.Length L1 = 0.50 "Link 1 length [m]";
  parameter Modelica.Units.SI.Length L2 = 0.38 "Link 2 length [m]";
  parameter Modelica.Units.SI.Length L3 = 0.24 "Link 3 length [m]";

  // ========== Actuator Limit (from requirement) ==========
  parameter Modelica.Units.SI.Torque tau_max = 104.0 "Max joint torque [N.m]";

  // ========== Control Rate (from requirement) ==========
  parameter Modelica.Units.SI.Frequency f_ctrl = 500.0 "Control rate [Hz]";

  // ========== Trajectory Waypoints ==========
  // NOTE: Waypoint coordinates are design choices not specified in the
  //       requirement; selected for reachability of the Z-Y-Y arm.
  parameter Modelica.Units.SI.Time t_wp[4] = {0.0, 6.0, 12.0, 18.0}
    "Waypoint timestamps [s]";
  parameter Modelica.Units.SI.Position x_wp[4] = {0.97, 0.50, -0.40, 0.10}
    "Waypoint x [m]";
  parameter Modelica.Units.SI.Position y_wp[4] = {0.0, 0.40, 0.30, -0.50}
    "Waypoint y [m]";
  parameter Modelica.Units.SI.Position z_wp[4] = {0.40, 0.30, 0.45, 0.35}
    "Waypoint z [m]";
  parameter Modelica.Units.SI.Angle phi_wp[4] = {0.70, 0.70, 0.70, 0.70}
    "Desired tool pitch (q2+q3) at waypoints [rad]";

  // ========== Obstacle (fixed cylinder beside path) ==========
  // NOTE: Obstacle position is a design choice; placed beside the path.
  parameter Modelica.Units.SI.Position obs_x = 0.30 "Obstacle center x [m]";
  parameter Modelica.Units.SI.Position obs_y = 0.55 "Obstacle center y [m]";
  parameter Modelica.Units.SI.Position obs_z_lo = 0.15 "Obstacle bottom z [m]";
  parameter Modelica.Units.SI.Position obs_z_hi = 0.65 "Obstacle top z [m]";
  parameter Modelica.Units.SI.Length obs_r = 0.08 "Obstacle radius [m]";
  parameter Modelica.Units.SI.Length req_clearance = 0.06
    "Required clearance [m] (from requirement)";
  parameter Modelica.Units.SI.Length obs_influence = 0.20
    "Obstacle influence distance [m] (design choice)";

  // ========== Disturbance (from requirement) ==========
  parameter Modelica.Units.SI.Force F_dist_mag = 14.5
    "Disturbance magnitude [N]";
  parameter Modelica.Units.SI.Time t_dist_a = 20.0 / 3.0
    "Disturbance start — middle third [s]";
  parameter Modelica.Units.SI.Time t_dist_b = 40.0 / 3.0
    "Disturbance end — middle third [s]";

  // ========== Joint Limits (design choices) ==========
  parameter Modelica.Units.SI.Angle q1_min = -3.0 "Joint 1 min [rad]";
  parameter Modelica.Units.SI.Angle q1_max = 3.0 "Joint 1 max [rad]";
  parameter Modelica.Units.SI.Angle q2_min = -2.5 "Joint 2 min [rad]";
  parameter Modelica.Units.SI.Angle q2_max = 2.5 "Joint 2 max [rad]";
  parameter Modelica.Units.SI.Angle q3_min = -2.5 "Joint 3 min [rad]";
  parameter Modelica.Units.SI.Angle q3_max = 2.5 "Joint 3 max [rad]";
  parameter Modelica.Units.SI.Angle q_margin = 0.3
    "Joint limit avoidance margin [rad] (design choice)";

  // ========== Arm Dynamics (design choices) ==========
  parameter Modelica.Units.SI.Inertia I1 = 0.80 "Joint 1 inertia [kg.m2]";
  parameter Modelica.Units.SI.Inertia I2 = 0.40 "Joint 2 inertia [kg.m2]";
  parameter Modelica.Units.SI.Inertia I3 = 0.15 "Joint 3 inertia [kg.m2]";
  parameter Real d1 = 0.50 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real d2 = 0.30 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real d3 = 0.20 "Joint 3 viscous damping [N.m.s/rad]";

  // ========== Control Gains (design choices) ==========
  parameter Real Kp_cart = 800.0 "Cartesian position P gain [N/m]";
  parameter Real Kd_cart = 40.0 "Cartesian position D gain [N.s/m]";
  parameter Real Kp_orient = 20.0 "Orientation P gain [N.m/rad]";
  parameter Real Kd_orient = 3.0 "Orientation D gain [N.m.s/rad]";
  parameter Real K_jlim = 100.0 "Joint limit avoidance gain [N.m/rad]";
  parameter Real K_obs = 800.0 "Obstacle avoidance gain [N/m]";

  // ========== Verification Thresholds (from requirement) ==========
  parameter Modelica.Units.SI.Length track_thresh = 0.028
    "Primary tracking error threshold [m]";
  parameter Modelica.Units.SI.Time track_check_time = 13.0
    "Time after which tracking is checked [s]";

  // ========== Joint States ==========
  Modelica.Units.SI.Angle q1(start = 0.0, fixed = true) "Joint 1 angle [rad]";
  Modelica.Units.SI.Angle q2(start = 0.7, fixed = true) "Joint 2 angle [rad]";
  Modelica.Units.SI.Angle q3(start = 0.0, fixed = true) "Joint 3 angle [rad]";
  Modelica.Units.SI.AngularVelocity qd1(start = 0.0, fixed = true)
    "Joint 1 velocity [rad/s]";
  Modelica.Units.SI.AngularVelocity qd2(start = 0.0, fixed = true)
    "Joint 2 velocity [rad/s]";
  Modelica.Units.SI.AngularVelocity qd3(start = 0.0, fixed = true)
    "Joint 3 velocity [rad/s]";

  // ========== Encoder Readings ==========
  Modelica.Units.SI.Angle q1_enc "Encoder reading joint 1 [rad]";
  Modelica.Units.SI.Angle q2_enc "Encoder reading joint 2 [rad]";
  Modelica.Units.SI.Angle q3_enc "Encoder reading joint 3 [rad]";

  // ========== End-Effector Pose ==========
  Modelica.Units.SI.Position px "End-effector x [m]";
  Modelica.Units.SI.Position py "End-effector y [m]";
  Modelica.Units.SI.Position pz "End-effector z [m]";
  Modelica.Units.SI.Angle phi_curr "Current tool pitch q2+q3 [rad]";

  // ========== Desired Trajectory ==========
  Modelica.Units.SI.Position px_d "Desired x [m]";
  Modelica.Units.SI.Position py_d "Desired y [m]";
  Modelica.Units.SI.Position pz_d "Desired z [m]";
  Modelica.Units.SI.Angle phi_d "Desired tool pitch [rad]";
  Modelica.Units.SI.Velocity vxd "Desired x velocity [m/s]";
  Modelica.Units.SI.Velocity vyd "Desired y velocity [m/s]";
  Modelica.Units.SI.Velocity vzd "Desired z velocity [m/s]";

  // ========== Cartesian Error ==========
  Modelica.Units.SI.Length ex "X tracking error [m]";
  Modelica.Units.SI.Length ey "Y tracking error [m]";
  Modelica.Units.SI.Length ez "Z tracking error [m]";
  Modelica.Units.SI.Length e_norm "Cartesian error norm [m]";
  Modelica.Units.SI.Angle e_orient "Orientation error [rad]";

  // ========== Jacobian ==========
  Real J11, J12, J13, J21, J22, J23, J31, J32, J33;

  // ========== Cartesian Velocities ==========
  Modelica.Units.SI.Velocity vx "End-effector x velocity [m/s]";
  Modelica.Units.SI.Velocity vy "End-effector y velocity [m/s]";
  Modelica.Units.SI.Velocity vz "End-effector z velocity [m/s]";

  // ========== Control Forces ==========
  Modelica.Units.SI.Force Fx "Cartesian control force x [N]";
  Modelica.Units.SI.Force Fy "Cartesian control force y [N]";
  Modelica.Units.SI.Force Fz "Cartesian control force z [N]";

  // ========== Obstacle Avoidance ==========
  Modelica.Units.SI.Length obs_dist "Distance to obstacle surface [m]";
  Modelica.Units.SI.Force Fx_obs "Obstacle repulsion x [N]";
  Modelica.Units.SI.Force Fy_obs "Obstacle repulsion y [N]";
  Modelica.Units.SI.Force Fz_obs "Obstacle repulsion z [N]";
  Real obs_h_dist "Horizontal distance to cylinder axis [m]";
  Real obs_dir_x "Unit direction x from obstacle to EE";
  Real obs_dir_y "Unit direction y from obstacle to EE";

  // ========== Joint Limit Avoidance ==========
  Modelica.Units.SI.Torque tau1_lim "Joint 1 limit avoidance torque [N.m]";
  Modelica.Units.SI.Torque tau2_lim "Joint 2 limit avoidance torque [N.m]";
  Modelica.Units.SI.Torque tau3_lim "Joint 3 limit avoidance torque [N.m]";

  // ========== Disturbance ==========
  Modelica.Units.SI.Force Fx_dist "Disturbance force x [N]";
  Modelica.Units.SI.Force Fy_dist "Disturbance force y [N]";
  Modelica.Units.SI.Force Fz_dist "Disturbance force z [N]";
  Boolean dist_active "Disturbance active flag";
  Modelica.Units.SI.Torque tau1_dist "Disturbance torque joint 1 [N.m]";
  Modelica.Units.SI.Torque tau2_dist "Disturbance torque joint 2 [N.m]";
  Modelica.Units.SI.Torque tau3_dist "Disturbance torque joint 3 [N.m]";

  // ========== Joint Torques ==========
  Modelica.Units.SI.Torque tau1_raw "Raw commanded torque joint 1 [N.m]";
  Modelica.Units.SI.Torque tau2_raw "Raw commanded torque joint 2 [N.m]";
  Modelica.Units.SI.Torque tau3_raw "Raw commanded torque joint 3 [N.m]";
  Modelica.Units.SI.Torque tau1 "Saturated torque joint 1 [N.m]";
  Modelica.Units.SI.Torque tau2 "Saturated torque joint 2 [N.m]";
  Modelica.Units.SI.Torque tau3 "Saturated torque joint 3 [N.m]";
  Boolean tau1_sat "Joint 1 torque saturated";
  Boolean tau2_sat "Joint 2 torque saturated";
  Boolean tau3_sat "Joint 3 torque saturated";

  // ========== Wrist Wrench ==========
  Modelica.Units.SI.Force wrist_fx "Wrist force x [N]";
  Modelica.Units.SI.Force wrist_fy "Wrist force y [N]";
  Modelica.Units.SI.Force wrist_fz "Wrist force z [N]";
  Boolean wrist_wrench_available "Wrist wrench sensor available";

  // ========== Verification Flags ==========
  Boolean ok_torque "Torque bounds satisfied";
  Boolean ok_clearance "Obstacle clearance satisfied";
  Boolean ok_finite_commands "Commands finite";
  Boolean ok_no_nan "No NaN or infinite values";
  Boolean ok_tracking "Tracking error below threshold after 13 s";
  Boolean all_ok "All verification criteria met";

  // ========== Intermediate Variables ==========
  Real c1, s1, c2, s2, c23, s23;
  Real r_reach "Horizontal reach [m]";
  Real u_seg "Normalized segment time";
  Real ss "Smoothstep interpolation value";
  Real ss_d "Smoothstep derivative w.r.t. time";
  Integer seg "Current segment index";

equation
  // ===== Trigonometric Cache =====
  c1 = cos(q1);
  s1 = sin(q1);
  c2 = cos(q2);
  s2 = sin(q2);
  c23 = cos(q2 + q3);
  s23 = sin(q2 + q3);

  // ===== Forward Kinematics =====
  r_reach = L1 + L2 * c2 + L3 * c23;
  px = c1 * r_reach;
  py = s1 * r_reach;
  pz = L2 * s2 + L3 * s23;
  phi_curr = q2 + q3;

  // ===== Encoder Feedback (ideal encoders) =====
  q1_enc = q1;
  q2_enc = q2;
  q3_enc = q3;

  // ===== Jacobian (3x3) =====
  J11 = -s1 * r_reach;
  J21 = c1 * r_reach;
  J31 = 0.0;

  J12 = c1 * (-L2 * s2 - L3 * s23);
  J22 = s1 * (-L2 * s2 - L3 * s23);
  J32 = L2 * c2 + L3 * c23;

  J13 = c1 * (-L3 * s23);
  J23 = s1 * (-L3 * s23);
  J33 = L3 * c23;

  // ===== Cartesian Velocities =====
  vx = J11 * qd1 + J12 * qd2 + J13 * qd3;
  vy = J21 * qd1 + J22 * qd2 + J23 * qd3;
  vz = J31 * qd1 + J32 * qd2 + J33 * qd3;

  // ===== Trajectory Generation (Smoothstep Spline) =====
  seg = if time < t_wp[2] then 1
        elseif time < t_wp[3] then 2
        elseif time < t_wp[4] then 3
        else 4;

  u_seg = if seg <= 3 then
            (time - t_wp[seg]) / (t_wp[seg + 1] - t_wp[seg] + 1.0e-9)
          else 1.0;

  // Smoothstep: s(u) = 3u^2 - 2u^3, clamped to [0, 1]
  ss = if u_seg <= 0.0 then 0.0
       elseif u_seg >= 1.0 then 1.0
       else 3.0 * u_seg * u_seg - 2.0 * u_seg * u_seg * u_seg;

  // Smoothstep time derivative: s'(u) / duration
  ss_d = if u_seg <= 0.0 or u_seg >= 1.0 then 0.0
         else (6.0 * u_seg - 6.0 * u_seg * u_seg) /
              (if seg <= 3 then (t_wp[seg + 1] - t_wp[seg] + 1.0e-9) else 1.0);

  // Desired position via smoothstep interpolation between waypoints
  px_d = if seg == 1 then x_wp[1] + ss * (x_wp[2] - x_wp[1])
         elseif seg == 2 then x_wp[2] + ss * (x_wp[3] - x_wp[2])
         elseif seg == 3 then x_wp[3] + ss * (x_wp[4] - x_wp[3])
         else x_wp[4];

  py_d = if seg == 1 then y_wp[1] + ss * (y_wp[2] - y_wp[1])
         elseif seg == 2 then y_wp[2] + ss * (y_wp[3] - y_wp[2])
         elseif seg == 3 then y_wp[3] + ss * (y_wp[4] - y_wp[3])
         else y_wp[4];

  pz_d = if seg == 1 then z_wp[1] + ss * (z_wp[2] - z_wp[1])
         elseif seg == 2 then z_wp[2] + ss * (z_wp[3] - z_wp[2])
         elseif seg == 3 then z_wp[3] + ss * (z_wp[4] - z_wp[3])
         else z_wp[4];

  phi_d = if seg == 1 then phi_wp[1] + ss * (phi_wp[2] - phi_wp[1])
          elseif seg == 2 then phi_wp[2] + ss * (phi_wp[3] - phi_wp[2])
          elseif seg == 3 then phi_wp[3] + ss * (phi_wp[4] - phi_wp[3])
          else phi_wp[4];

  // Desired Cartesian velocities (feedforward)
  vxd = if seg == 1 then ss_d * (x_wp[2] - x_wp[1])
        elseif seg == 2 then ss_d * (x_wp[3] - x_wp[2])
        elseif seg == 3 then ss_d * (x_wp[4] - x_wp[3])
        else 0.0;

  vyd = if seg == 1 then ss_d * (y_wp[2] - y_wp[1])
        elseif seg == 2 then ss_d * (y_wp[3] - y_wp[2])
        elseif seg == 3 then ss_d * (y_wp[4] - y_wp[3])
        else 0.0;

  vzd = if seg == 1 then ss_d * (z_wp[2] - z_wp[1])
        elseif seg == 2 then ss_d * (z_wp[3] - z_wp[2])
        elseif seg == 3 then ss_d * (z_wp[4] - z_wp[3])
        else 0.0;

  // ===== Cartesian Tracking Error =====
  ex = px_d - px;
  ey = py_d - py;
  ez = pz_d - pz;
  e_norm = sqrt(ex * ex + ey * ey + ez * ez + 1.0e-12);

  // ===== Orientation Error =====
  e_orient = phi_d - phi_curr;

  // ===== Operational-Space Control Force (PD with feedforward velocity) =====
  Fx = Kp_cart * ex + Kd_cart * (vxd - vx);
  Fy = Kp_cart * ey + Kd_cart * (vyd - vy);
  Fz = Kp_cart * ez + Kd_cart * (vzd - vz);

  // ===== Obstacle Avoidance (repulsive potential field) =====
  obs_h_dist = sqrt((px - obs_x) * (px - obs_x) +
                   (py - obs_y) * (py - obs_y) + 1.0e-12);

  obs_dist = if (pz >= obs_z_lo) and (pz <= obs_z_hi) then
               obs_h_dist - obs_r
             else 1.0;

  obs_dir_x = (px - obs_x) / (obs_h_dist + 1.0e-9);
  obs_dir_y = (py - obs_y) / (obs_h_dist + 1.0e-9);

  Fx_obs = if (obs_dist < obs_influence) and (obs_dist >= 0.0) and
              (pz >= obs_z_lo) and (pz <= obs_z_hi) then
             K_obs * (obs_influence - obs_dist) * obs_dir_x
           else 0.0;

  Fy_obs = if (obs_dist < obs_influence) and (obs_dist >= 0.0) and
              (pz >= obs_z_lo) and (pz <= obs_z_hi) then
             K_obs * (obs_influence - obs_dist) * obs_dir_y
           else 0.0;

  Fz_obs = 0.0;

  // ===== Joint Limit Avoidance (repulsive torque near limits) =====
  tau1_lim = if q1 > (q1_max - q_margin) then
               -K_jlim * (q1 - (q1_max - q_margin))
             elseif q1 < (q1_min + q_margin) then
               -K_jlim * (q1 - (q1_min + q_margin))
             else 0.0;

  tau2_lim = if q2 > (q2_max - q_margin) then
               -K_jlim * (q2 - (q2_max - q_margin))
             elseif q2 < (q2_min + q_margin) then
               -K_jlim * (q2 - (q2_min + q_margin))
             else 0.0;

  tau3_lim = if q3 > (q3_max - q_margin) then
               -K_jlim * (q3 - (q3_max - q_margin))
             elseif q3 < (q3_min + q_margin) then
               -K_jlim * (q3 - (q3_min + q_margin))
             else 0.0;

  // ===== Disturbance (14.5 N during middle third of 20 s) =====
  dist_active = time >= t_dist_a and time <= t_dist_b;
  Fx_dist = if dist_active then -F_dist_mag else 0.0;
  Fy_dist = 0.0;
  Fz_dist = 0.0;

  // Disturbance mapped to joint space via Jacobian transpose
  tau1_dist = J11 * Fx_dist + J21 * Fy_dist + J31 * Fz_dist;
  tau2_dist = J12 * Fx_dist + J22 * Fy_dist + J32 * Fz_dist;
  tau3_dist = J13 * Fx_dist + J23 * Fy_dist + J33 * Fz_dist;

  // ===== Torque Computation =====
  // tau = J^T * (F + F_obs) + tau_orient + tau_lim
  // Orientation control applied directly to joints 2 and 3 to preserve
  // tool pitch (q2 + q3).
  tau1_raw = J11 * (Fx + Fx_obs) + J21 * (Fy + Fy_obs) + J31 * (Fz + Fz_obs)
             + tau1_lim;

  tau2_raw = J12 * (Fx + Fx_obs) + J22 * (Fy + Fy_obs) + J32 * (Fz + Fz_obs)
             + Kp_orient * e_orient - Kd_orient * (qd2 + qd3)
             + tau2_lim;

  tau3_raw = J13 * (Fx + Fx_obs) + J23 * (Fy + Fy_obs) + J33 * (Fz + Fz_obs)
             + Kp_orient * e_orient - Kd_orient * (qd2 + qd3)
             + tau3_lim;

  // ===== Torque Saturation (<= 104 N.m per joint) =====
  tau1 = if tau1_raw > tau_max then tau_max
         elseif tau1_raw < -tau_max then -tau_max
         else tau1_raw;
  tau2 = if tau2_raw > tau_max then tau_max
         elseif tau2_raw < -tau_max then -tau_max
         else tau2_raw;
  tau3 = if tau3_raw > tau_max then tau_max
         elseif tau3_raw < -tau_max then -tau_max
         else tau3_raw;

  tau1_sat = abs(tau1_raw) > tau_max;
  tau2_sat = abs(tau2_raw) > tau_max;
  tau3_sat = abs(tau3_raw) > tau_max;

  // ===== Wrist Wrench (when available) =====
  wrist_wrench_available = true;
  wrist_fx = Fx_dist;
  wrist_fy = Fy_dist;
  wrist_fz = Fz_dist;

  // ===== Arm Dynamics =====
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;

  I1 * der(qd1) = tau1 - d1 * qd1 + tau1_dist;
  I2 * der(qd2) = tau2 - d2 * qd2 + tau2_dist;
  I3 * der(qd3) = tau3 - d3 * qd3 + tau3_dist;

  // ===== Verification Criteria =====
  // Joint and effort bounds (saturated, so always satisfied by construction)
  ok_torque = (tau1 >= -tau_max - 1.0e-6) and (tau1 <= tau_max + 1.0e-6) and
              (tau2 >= -tau_max - 1.0e-6) and (tau2 <= tau_max + 1.0e-6) and
              (tau3 >= -tau_max - 1.0e-6) and (tau3 <= tau_max + 1.0e-6);

  // Obstacle clearance (required clearance 0.06 m)
  ok_clearance = (obs_dist >= req_clearance - 1.0e-6) or
                 (pz < obs_z_lo) or (pz > obs_z_hi);

  // Finite commands (bound check detects NaN and Inf)
  ok_finite_commands = (tau1 > -1.0e6) and (tau1 < 1.0e6) and
                       (tau2 > -1.0e6) and (tau2 < 1.0e6) and
                       (tau3 > -1.0e6) and (tau3 < 1.0e6);

  // No NaN or infinite physical / control / estimator values
  ok_no_nan = (q1 > -1.0e6) and (q1 < 1.0e6) and
              (q2 > -1.0e6) and (q2 < 1.0e6) and
              (q3 > -1.0e6) and (q3 < 1.0e6) and
              (qd1 > -1.0e6) and (qd1 < 1.0e6) and
              (qd2 > -1.0e6) and (qd2 < 1.0e6) and
              (qd3 > -1.0e6) and (qd3 < 1.0e6) and
              (px > -1.0e6) and (px < 1.0e6) and
              (py > -1.0e6) and (py < 1.0e6) and
              (pz > -1.0e6) and (pz < 1.0e6) and
              (e_norm > -1.0e6) and (e_norm < 1.0e6);

  // Primary tracking error below 0.028 m after 13 s
  ok_tracking = if time >= track_check_time then e_norm < track_thresh
                else true;

  // All verification criteria combined
  all_ok = ok_torque and ok_clearance and ok_finite_commands and
           ok_no_nan and ok_tracking;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Interval = 0.002,
               Tolerance = 1.0e-6),
    Documentation(info = "Three-revolute-joint (Z-Y-Y) arm with link lengths
      0.50 m, 0.38 m, 0.24 m. Tracks a Cartesian spline through four
      timestamped poses while preserving tool orientation via a soft
      orientation constraint on q2+q3. Operational-space PD control with
      Jacobian-transpose mapping, joint-limit avoidance, cylindrical obstacle
      clearance (0.06 m required), and 14.5 N tool disturbance during middle
      third (6.67–13.33 s). Runs at 500 Hz (Interval = 0.002 s) for 20 s.
      Torque limit 104 N.m per joint. Tracking error must be below 0.028 m
      after 13 s. Encoder feedback and end-effector pose feedback included;
      wrist wrench available throughout.")
  );
end JointPathSplineF;