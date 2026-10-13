model JointPathSplineE
  "Trajectory-controlled 3R Z-Y-Y robotic arm with Cartesian spline tracking,
   obstacle clearance, joint-limit avoidance, and 12 N tool disturbance.
   Fail-closed acceptance: all checks must remain true throughout the run."

  // ===== Link geometry =====
  parameter Real a1 = 0.50 "Link 1 length (vertical column) [m]";
  parameter Real a2 = 0.38 "Link 2 length [m]";
  parameter Real a3 = 0.24 "Link 3 length [m]";

  // ===== Inertial and damping parameters =====
  parameter Real J1 = 0.80 "Joint 1 reflected inertia [kg.m2]";
  parameter Real J2 = 0.40 "Joint 2 reflected inertia [kg.m2]";
  parameter Real J3 = 0.15 "Joint 3 reflected inertia [kg.m2]";
  parameter Real b1 = 0.80 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.50 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 0.30 "Joint 3 viscous damping [N.m.s/rad]";
  parameter Real m2 = 1.50 "Link 2 mass [kg]";
  parameter Real m3 = 1.00 "Link 3 mass [kg]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Actuator limit =====
  parameter Real tau_max = 93.5 "Maximum joint torque magnitude [N.m]";

  // ===== Control parameters =====
  parameter Real dt_ctrl = 1.0 / 250.0 "Control sampling period [s]";
  parameter Real T_end  = 16.0        "Total simulation run time [s]";
  parameter Real Kp_pos = 800.0 "Cartesian position proportional gain [N/m]";
  parameter Real Kd_pos = 60.0  "Cartesian position derivative gain [N.s/m]";
  parameter Real k_avoid = 30.0 "Joint-limit avoidance gain [N.m/rad]";
  parameter Real q_margin = 0.15 "Joint-limit avoidance margin [rad]";

  // ===== Joint limits =====
  parameter Real q1_lo = -2.50 "Joint 1 lower limit [rad]";
  parameter Real q1_hi =  2.50 "Joint 1 upper limit [rad]";
  parameter Real q2_lo = -1.50 "Joint 2 lower limit [rad]";
  parameter Real q2_hi =  1.50 "Joint 2 upper limit [rad]";
  parameter Real q3_lo = -1.50 "Joint 3 lower limit [rad]";
  parameter Real q3_hi =  1.50 "Joint 3 upper limit [rad]";

  // ===== Timestamped Cartesian waypoints =====
  parameter Real wp1_t = 0.0;
  parameter Real wp2_t = 5.0;
  parameter Real wp3_t = 10.0;
  parameter Real wp4_t = 15.0;
  parameter Real wp1_x = 0.45;  parameter Real wp1_y =  0.22;  parameter Real wp1_z = 0.50;
  parameter Real wp2_x = 0.50;  parameter Real wp2_y =  0.10;  parameter Real wp2_z = 0.55;
  parameter Real wp3_x = 0.52;  parameter Real wp3_y = -0.05;  parameter Real wp3_z = 0.45;
  parameter Real wp4_x = 0.45;  parameter Real wp4_y = -0.20;  parameter Real wp4_z = 0.55;

  // ===== Cylindrical obstacle (vertical, beside path) =====
  parameter Real obs_cx = 0.90 "Obstacle center x [m]";
  parameter Real obs_cy = 0.20 "Obstacle center y [m]";
  parameter Real obs_r  = 0.05 "Obstacle radius [m]";
  parameter Real obs_h  = 0.60 "Obstacle height [m]";
  parameter Real arm_r  = 0.03 "Arm link cross-section radius [m]";
  parameter Real clearance_req = 0.06 "Required clearance [m]";

  // ===== Disturbance =====
  parameter Real F_dist_mag = 12.0 "Tool disturbance force magnitude [N]";

  // ===== Desired constant orientation (preserved) =====
  parameter Real des_q1  = 0.453  "Desired q1 for orientation [rad]";
  parameter Real des_q23 = -0.814 "Desired q2+q3 for orientation [rad]";

  // ===== Joint states =====
  Real q1(start = 0.453)  "Joint 1 angle [rad]";
  Real q2(start = 0.479)  "Joint 2 angle [rad]";
  Real q3(start = -1.293) "Joint 3 angle [rad]";
  Real dq1(start = 0.0)   "Joint 1 angular velocity [rad/s]";
  Real dq2(start = 0.0)   "Joint 2 angular velocity [rad/s]";
  Real dq3(start = 0.0)   "Joint 3 angular velocity [rad/s]";

  // ===== Forward kinematics =====
  Real p2x, p2y, p2z "Elbow position (after link 1) [m]";
  Real p3x, p3y, p3z "Wrist position (after link 2) [m]";
  Real px, py, pz    "End-effector position [m]";
  Real ee_yaw        "End-effector yaw (q1) [rad]";
  Real ee_pitch       "End-effector pitch (q2+q3) [rad]";

  // ===== Desired trajectory =====
  Real pxd, pyd, pzd       "Desired EE position [m]";
  Real pxd_dot, pyd_dot, pzd_dot "Desired EE velocity [m/s]";

  // ===== Tracking errors =====
  Real ex, ey, ez "Position error components [m]";
  Real e_pos      "Position error norm [m]";
  Real e_orient   "Orientation error metric [rad]";

  // ===== Jacobian elements =====
  Real J11, J12, J13, J21, J22, J23, J31, J32, J33;

  // ===== Gravity torques =====
  Real grav_tau2 "Gravity torque on joint 2 [N.m]";
  Real grav_tau3 "Gravity torque on joint 3 [N.m]";

  // ===== Sampled controller outputs (250 Hz) =====
  discrete Real Fx_cmd(start = 0.0) "Commanded Cartesian force x [N]";
  discrete Real Fy_cmd(start = 0.0) "Commanded Cartesian force y [N]";
  discrete Real Fz_cmd(start = 0.0) "Commanded Cartesian force z [N]";
  discrete Real tau1_raw(start = 0.0) "Raw torque joint 1 [N.m]";
  discrete Real tau2_raw(start = 0.0) "Raw torque joint 2 [N.m]";
  discrete Real tau3_raw(start = 0.0) "Raw torque joint 3 [N.m]";

  // ===== Joint-limit avoidance torques (continuous) =====
  Real tau1_avoid "Joint 1 avoidance torque [N.m]";
  Real tau2_avoid "Joint 2 avoidance torque [N.m]";
  Real tau3_avoid "Joint 3 avoidance torque [N.m]";

  // ===== Unsaturated and saturated actuator torques =====
  Real tau1_unsat, tau2_unsat, tau3_unsat "Unsaturated torques [N.m]";
  Real tau1_sat,   tau2_sat,   tau3_sat   "Saturated torques [N.m]";

  // ===== Disturbance =====
  Real Fd_x, Fd_y, Fd_z "Disturbance force components [N]";

  // ===== Wrist wrench =====
  Real wrist_fx, wrist_fy, wrist_fz "Wrist wrench components [N]";

  // ===== Encoder feedback =====
  Real q1_enc, q2_enc, q3_enc "Encoder readings [rad]";

  // ===== Obstacle clearance =====
  Real d_ee_obs    "EE horizontal distance to obstacle axis [m]";
  Real d_wrist_obs "Wrist horizontal distance to obstacle axis [m]";
  Real obs_clearance "Minimum obstacle clearance [m]";

  // ===== Safety and acceptance =====
  Boolean safety_ok         "Physical safety flag (fail-closed)";
  Boolean ok_joint_bounds   "Joints within limits";
  Boolean ok_effort_bounds  "Effort within bounds";
  Boolean ok_cart_error     "Cartesian error finite";
  Boolean ok_orient_error   "Orientation error finite";
  Boolean ok_clearance      "Obstacle clearance satisfied";
  Boolean ok_finite_cmds    "Commands finite";
  Boolean ok_primary_tracking "Primary tracking < 0.032 m after 10.4 s";
  Boolean ok_finite_all    "All physical/control/estimator values finite";
  Boolean all_passed        "All acceptance checks pass (fail-closed)";

  // ===== Trajectory helpers =====
  Real seg_s, seg_alpha, seg_alpha_dot, seg_dur;

equation
  // ===== Forward kinematics: Z-Y-Y, link 1 vertical along Z =====
  p2x = 0.0;
  p2y = 0.0;
  p2z = a1;

  p3x = cos(q1) * a2 * cos(q2);
  p3y = sin(q1) * a2 * cos(q2);
  p3z = a1 + a2 * sin(q2);

  px = p3x + a3 * cos(q1) * cos(q2 + q3);
  py = p3y + a3 * sin(q1) * cos(q2 + q3);
  pz = p3z + a3 * sin(q2 + q3);

  ee_yaw   = q1;
  ee_pitch = q2 + q3;

  // ===== Encoder feedback =====
  q1_enc = q1;
  q2_enc = q2;
  q3_enc = q3;

  // ===== Jacobian (Z-Y-Y, link 1 vertical) =====
  J11 = -sin(q1) * (a2 * cos(q2) + a3 * cos(q2 + q3));
  J12 = cos(q1) * (-a2 * sin(q2) - a3 * sin(q2 + q3));
  J13 = cos(q1) * (-a3 * sin(q2 + q3));
  J21 = cos(q1) * (a2 * cos(q2) + a3 * cos(q2 + q3));
  J22 = sin(q1) * (-a2 * sin(q2) - a3 * sin(q2 + q3));
  J23 = sin(q1) * (-a3 * sin(q2 + q3));
  J31 = 0.0;
  J32 = a2 * cos(q2) + a3 * cos(q2 + q3);
  J33 = a3 * cos(q2 + q3);

  // ===== Gravity torques (joint 1 about Z: no gravity torque) =====
  grav_tau2 = m2 * g_acc * (a2 / 2.0) * cos(q2)
            + m3 * g_acc * (a2 * cos(q2) + (a3 / 2.0) * cos(q2 + q3));
  grav_tau3 = m3 * g_acc * (a3 / 2.0) * cos(q2 + q3);

  // ===== Trajectory generation: smoothstep interpolation =====
  if time <= wp1_t then
    seg_s = 0.0;  seg_alpha = 0.0;  seg_alpha_dot = 0.0;  seg_dur = 1.0;
    pxd = wp1_x;  pyd = wp1_y;  pzd = wp1_z;
    pxd_dot = 0.0;  pyd_dot = 0.0;  pzd_dot = 0.0;
  elseif time <= wp2_t then
    seg_dur = wp2_t - wp1_t;
    seg_s = (time - wp1_t) / seg_dur;
    seg_alpha = 3.0 * seg_s * seg_s - 2.0 * seg_s * seg_s * seg_s;
    seg_alpha_dot = (6.0 * seg_s - 6.0 * seg_s * seg_s) / seg_dur;
    pxd = wp1_x + seg_alpha * (wp2_x - wp1_x);
    pyd = wp1_y + seg_alpha * (wp2_y - wp1_y);
    pzd = wp1_z + seg_alpha * (wp2_z - wp1_z);
    pxd_dot = (wp2_x - wp1_x) * seg_alpha_dot;
    pyd_dot = (wp2_y - wp1_y) * seg_alpha_dot;
    pzd_dot = (wp2_z - wp1_z) * seg_alpha_dot;
  elseif time <= wp3_t then
    seg_dur = wp3_t - wp2_t;
    seg_s = (time - wp2_t) / seg_dur;
    seg_alpha = 3.0 * seg_s * seg_s - 2.0 * seg_s * seg_s * seg_s;
    seg_alpha_dot = (6.0 * seg_s - 6.0 * seg_s * seg_s) / seg_dur;
    pxd = wp2_x + seg_alpha * (wp3_x - wp2_x);
    pyd = wp2_y + seg_alpha * (wp3_y - wp2_y);
    pzd = wp2_z + seg_alpha * (wp3_z - wp2_z);
    pxd_dot = (wp3_x - wp2_x) * seg_alpha_dot;
    pyd_dot = (wp3_y - wp2_y) * seg_alpha_dot;
    pzd_dot = (wp3_z - wp2_z) * seg_alpha_dot;
  elseif time <= wp4_t then
    seg_dur = wp4_t - wp3_t;
    seg_s = (time - wp3_t) / seg_dur;
    seg_alpha = 3.0 * seg_s * seg_s - 2.0 * seg_s * seg_s * seg_s;
    seg_alpha_dot = (6.0 * seg_s - 6.0 * seg_s * seg_s) / seg_dur;
    pxd = wp3_x + seg_alpha * (wp4_x - wp3_x);
    pyd = wp3_y + seg_alpha * (wp4_y - wp3_y);
    pzd = wp3_z + seg_alpha * (wp4_z - wp3_z);
    pxd_dot = (wp4_x - wp3_x) * seg_alpha_dot;
    pyd_dot = (wp4_y - wp3_y) * seg_alpha_dot;
    pzd_dot = (wp4_z - wp3_z) * seg_alpha_dot;
  else
    seg_s = 1.0;  seg_alpha = 1.0;  seg_alpha_dot = 0.0;  seg_dur = 1.0;
    pxd = wp4_x;  pyd = wp4_y;  pzd = wp4_z;
    pxd_dot = 0.0;  pyd_dot = 0.0;  pzd_dot = 0.0;
  end if;

  // ===== Tracking errors =====
  ex = pxd - px;
  ey = pyd - py;
  ez = pzd - pz;
  e_pos = sqrt(ex * ex + ey * ey + ez * ez + 1.0e-12);
  e_orient = sqrt((q1 - des_q1) * (q1 - des_q1)
                + (q2 + q3 - des_q23) * (q2 + q3 - des_q23) + 1.0e-12);

  // ===== Sampled operational-space controller (250 Hz) =====
  when sample(0, dt_ctrl) then
    Fx_cmd = Kp_pos * (pxd - px)
           + Kd_pos * (pxd_dot - (J11 * dq1 + J12 * dq2 + J13 * dq3));
    Fy_cmd = Kp_pos * (pyd - py)
           + Kd_pos * (pyd_dot - (J21 * dq1 + J22 * dq2 + J23 * dq3));
    Fz_cmd = Kp_pos * (pzd - pz)
           + Kd_pos * (pzd_dot - (J31 * dq1 + J32 * dq2 + J33 * dq3));
    tau1_raw = J11 * Fx_cmd + J21 * Fy_cmd + J31 * Fz_cmd;
    tau2_raw = J12 * Fx_cmd + J22 * Fy_cmd + J32 * Fz_cmd + grav_tau2;
    tau3_raw = J13 * Fx_cmd + J23 * Fy_cmd + J33 * Fz_cmd + grav_tau3;
  end when;

  // ===== Joint-limit avoidance (continuous repulsive torque) =====
  tau1_avoid = if q1 > (q1_hi - q_margin) then -k_avoid * (q1 - (q1_hi - q_margin))
               else if q1 < (q1_lo + q_margin) then -k_avoid * (q1 - (q1_lo + q_margin))
               else 0.0;
  tau2_avoid = if q2 > (q2_hi - q_margin) then -k_avoid * (q2 - (q2_hi - q_margin))
               else if q2 < (q2_lo + q_margin) then -k_avoid * (q2 - (q2_lo + q_margin))
               else 0.0;
  tau3_avoid = if q3 > (q3_hi - q_margin) then -k_avoid * (q3 - (q3_hi - q_margin))
               else if q3 < (q3_lo + q_margin) then -k_avoid * (q3 - (q3_lo + q_margin))
               else 0.0;

  // ===== Unsaturated commands =====
  tau1_unsat = tau1_raw + tau1_avoid;
  tau2_unsat = tau2_raw + tau2_avoid;
  tau3_unsat = tau3_raw + tau3_avoid;

  // ===== Safety check (fail-closed: zero commands when unsafe) =====
  safety_ok = abs(q1) < 1.0e6 and abs(q2) < 1.0e6 and abs(q3) < 1.0e6 and
              abs(dq1) < 1.0e6 and abs(dq2) < 1.0e6 and abs(dq3) < 1.0e6 and
              q1 >= q1_lo and q1 <= q1_hi and
              q2 >= q2_lo and q2 <= q2_hi and
              q3 >= q3_lo and q3 <= q3_hi;

  // ===== Torque saturation with fail-closed =====
  tau1_sat = if not safety_ok then 0.0
             else if tau1_unsat >  tau_max then  tau_max
             else if tau1_unsat < -tau_max then -tau_max
             else tau1_unsat;
  tau2_sat = if not safety_ok then 0.0
             else if tau2_unsat >  tau_max then  tau_max
             else if tau2_unsat < -tau_max then -tau_max
             else tau2_unsat;
  tau3_sat = if not safety_ok then 0.0
             else if tau3_unsat >  tau_max then  tau_max
             else if tau3_unsat < -tau_max then -tau_max
             else tau3_unsat;

  // ===== Disturbance: 12 N in +x during middle third =====
  Fd_x = if time >= T_end / 3.0 and time <= 2.0 * T_end / 3.0 then F_dist_mag else 0.0;
  Fd_y = 0.0;
  Fd_z = 0.0;

  // ===== Wrist wrench (external wrench at end-effector) =====
  wrist_fx = Fd_x;
  wrist_fy = Fd_y;
  wrist_fz = Fd_z;

  // ===== Joint dynamics =====
  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;

  J1 * der(dq1) + b1 * dq1 = tau1_sat + (J11 * Fd_x + J21 * Fd_y + J31 * Fd_z);
  J2 * der(dq2) + b2 * dq2 = tau2_sat + (J12 * Fd_x + J22 * Fd_y + J32 * Fd_z) - grav_tau2;
  J3 * der(dq3) + b3 * dq3 = tau3_sat + (J13 * Fd_x + J23 * Fd_y + J33 * Fd_z) - grav_tau3;

  // ===== Obstacle clearance (horizontal distance, conservative) =====
  d_ee_obs    = sqrt((px  - obs_cx) * (px  - obs_cx) + (py  - obs_cy) * (py  - obs_cy) + 1.0e-12);
  d_wrist_obs = sqrt((p3x - obs_cx) * (p3x - obs_cx) + (p3y - obs_cy) * (p3y - obs_cy) + 1.0e-12);
  obs_clearance = (if d_ee_obs < d_wrist_obs then d_ee_obs else d_wrist_obs) - obs_r - arm_r;

  // ===== Acceptance checks (fail-closed) =====
  ok_joint_bounds = q1 >= q1_lo and q1 <= q1_hi and
                    q2 >= q2_lo and q2 <= q2_hi and
                    q3 >= q3_lo and q3 <= q3_hi;
  ok_effort_bounds = abs(tau1_sat) <= tau_max + 1.0e-6 and
                     abs(tau2_sat) <= tau_max + 1.0e-6 and
                     abs(tau3_sat) <= tau_max + 1.0e-6;
  ok_cart_error   = e_pos >= 0.0 and e_pos < 1.0e6;
  ok_orient_error = e_orient >= 0.0 and e_orient < 1.0e6;
  ok_clearance    = obs_clearance >= clearance_req;
  ok_finite_cmds  = abs(tau1_raw) < 1.0e6 and abs(tau2_raw) < 1.0e6 and abs(tau3_raw) < 1.0e6 and
                    abs(tau1_sat) < 1.0e6 and abs(tau2_sat) < 1.0e6 and abs(tau3_sat) < 1.0e6;
  ok_primary_tracking = if time >= 10.4 then e_pos < 0.032 else true;
  ok_finite_all = abs(q1) < 1.0e6 and abs(q2) < 1.0e6 and abs(q3) < 1.0e6 and
                  abs(dq1) < 1.0e6 and abs(dq2) < 1.0e6 and abs(dq3) < 1.0e6 and
                  abs(px) < 1.0e6 and abs(py) < 1.0e6 and abs(pz) < 1.0e6 and
                  abs(e_pos) < 1.0e6 and abs(e_orient) < 1.0e6 and
                  abs(Fd_x) < 1.0e6 and abs(obs_clearance) < 1.0e6 and
                  abs(wrist_fx) < 1.0e6;
  all_passed = ok_joint_bounds and ok_effort_bounds and ok_cart_error and
               ok_orient_error and ok_clearance and ok_finite_cmds and
               ok_primary_tracking and ok_finite_all;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "3-revolute Z-Y-Y arm (0.50, 0.38, 0.24 m links) tracking a 4-waypoint
      Cartesian spline with constant tool orientation. Operational-space PD control at 250 Hz
      with Jacobian-transpose torque mapping, gravity compensation, joint-limit avoidance,
      93.5 N.m torque saturation, and fail-closed safety. A 12 N disturbance acts in +x during
      the middle third (5.33-10.67 s). A vertical cylindrical obstacle at (0.90, 0.20) with 0.05 m
      radius must maintain >= 0.06 m clearance. Primary tracking error must be < 0.032 m after 10.4 s.")
  );
end JointPathSplineE;