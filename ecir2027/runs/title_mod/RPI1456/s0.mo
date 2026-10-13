model JointPathSplineD
  "Instrumented trajectory-controlled 3R Z-Y-Y arm with spline tracking,
   obstacle clearance, joint-limit avoidance, and tool disturbance"

  // ==================== Kinematic Parameters ====================
  parameter Real L1 = 0.50 "Link 1 length [m]";
  parameter Real L2 = 0.38 "Link 2 length [m]";
  parameter Real L3 = 0.24 "Link 3 length [m]";

  // ==================== Dynamic Parameters ====================
  parameter Real I1 = 0.8 "Joint 1 inertia [kg.m2]";
  parameter Real I2 = 0.5 "Joint 2 inertia [kg.m2]";
  parameter Real I3 = 0.2 "Joint 3 inertia [kg.m2]";
  parameter Real B1 = 1.2 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real B2 = 0.8 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real B3 = 0.5 "Joint 3 viscous damping [N.m.s/rad]";

  // ==================== Actuator Limits ====================
  parameter Real tau_max = 85.0 "Maximum joint torque [N.m]";

  // ==================== Controller Parameters ====================
  parameter Real Ts = 0.005 "Controller sample period [s] (200 Hz)";
  parameter Real Kpc = 800.0 "Cartesian proportional gain [N/m]";
  parameter Real Kdc = 60.0 "Cartesian derivative gain [N.s/m]";
  parameter Real Kpo = 30.0 "Orientation proportional gain [N.m/rad]";
  parameter Real Kdo = 3.0 "Orientation derivative gain [N.m.s/rad]";

  // ==================== Joint Limits ====================
  parameter Real q1_lim = 2.5 "Joint 1 limit magnitude [rad]";
  parameter Real q2_lim = 1.8 "Joint 2 limit magnitude [rad]";
  parameter Real q3_lim = 2.2 "Joint 3 limit magnitude [rad]";
  parameter Real q_margin = 0.3 "Joint limit avoidance margin [rad]";
  parameter Real q_pen_gain = 200.0 "Joint limit penalty gain [N.m/rad]";

  // ==================== Trajectory Waypoints ====================
  // Four timestamped poses on circle (center 0.74, radius 0.38)
  // with constant orientation q1=0, q2+q3=0 (tool along x)
  parameter Real t_wp[4] = {0.0, 4.6667, 9.3333, 14.0} "Waypoint times [s]";
  parameter Real q2_wp[4] = {-0.8175, -0.2978, 0.2978, 0.8049}
    "Waypoint q2 angles [rad]";

  // ==================== Disturbance ====================
  parameter Real F_dist = 10.0 "Tool disturbance force [N]";
  parameter Real T_run = 14.0 "Total run time [s]";

  // ==================== Obstacle ====================
  parameter Real obs_cx = 0.50 "Obstacle center x [m]";
  parameter Real obs_cz = 0.0 "Obstacle center z [m]";
  parameter Real obs_r = 0.04 "Obstacle radius [m]";
  parameter Real clr_req = 0.06 "Required clearance [m]";

  // ==================== Joint States (encoder feedback) ====================
  Real q1(start = 0.0) "Joint 1 angle (Z-axis) [rad]";
  Real q2(start = -0.8175) "Joint 2 angle (Y-axis) [rad]";
  Real q3(start = 0.8175) "Joint 3 angle (Y-axis) [rad]";
  Real qd1(start = 0.0) "Joint 1 velocity [rad/s]";
  Real qd2(start = 0.0) "Joint 2 velocity [rad/s]";
  Real qd3(start = 0.0) "Joint 3 velocity [rad/s]";

  // ==================== Forward Kinematics ====================
  Real x_ee "End-effector x [m]";
  Real y_ee "End-effector y [m]";
  Real z_ee "End-effector z [m]";
  Real r_ext "Arm extension [m]";
  Real x_wrist "Wrist x [m]";
  Real z_wrist "Wrist z [m]";

  // ==================== Jacobian ====================
  Real Jx1 "partial x / partial q1";
  Real Jx2 "partial x / partial q2";
  Real Jx3 "partial x / partial q3";
  Real Jz1 "partial z / partial q1";
  Real Jz2 "partial z / partial q2";
  Real Jz3 "partial z / partial q3";
  Real xd_ee "End-effector x velocity [m/s]";
  Real zd_ee "End-effector z velocity [m/s]";

  // ==================== Desired Trajectory ====================
  Real q2_des "Desired q2 [rad]";
  Real qd2_des "Desired qd2 [rad/s]";
  Real x_des "Desired x [m]";
  Real z_des "Desired z [m]";
  Real xd_des "Desired x velocity [m/s]";
  Real zd_des "Desired z velocity [m/s]";

  // ==================== Errors ====================
  Real x_err "Cartesian x error [m]";
  Real z_err "Cartesian z error [m]";
  Real cart_err "Cartesian tracking error norm [m]";
  Real orient_err "Orientation error norm [rad]";

  // ==================== Discrete Control (200 Hz) ====================
  discrete Real Fx_cmd(start = 0.0) "Discrete Cartesian force x command [N]";
  discrete Real Fz_cmd(start = 0.0) "Discrete Cartesian force z command [N]";

  // ==================== Torques ====================
  Real tau1_raw "Unsaturated joint 1 torque [N.m]";
  Real tau2_raw "Unsaturated joint 2 torque [N.m]";
  Real tau3_raw "Unsaturated joint 3 torque [N.m]";
  Real tau1 "Saturated joint 1 torque [N.m]";
  Real tau2 "Saturated joint 2 torque [N.m]";
  Real tau3 "Saturated joint 3 torque [N.m]";
  Real pen1 "Joint 1 limit avoidance torque [N.m]";
  Real pen2 "Joint 2 limit avoidance torque [N.m]";
  Real pen3 "Joint 3 limit avoidance torque [N.m]";

  // ==================== Disturbance ====================
  Real Fd_x "Disturbance force x component [N]";

  // ==================== Obstacle ====================
  Real obs_dist "Distance from EE to obstacle center [m]";
  Real obs_clear "Clearance to obstacle surface [m]";

  // ==================== Sensors ====================
  Real wrist_wrench "Wrist wrench magnitude [N]";
  Real cmd_norm "Command torque norm [N.m]";

equation
  // ===== Forward Kinematics (Z-Y-Y axes) =====
  r_ext = L1 + L2*cos(q2) + L3*cos(q2 + q3);
  x_ee = r_ext * cos(q1);
  y_ee = r_ext * sin(q1);
  z_ee = -L2*sin(q2) - L3*sin(q2 + q3);
  x_wrist = (L1 + L2*cos(q2)) * cos(q1);
  z_wrist = -L2*sin(q2);

  // ===== Jacobian (x, z w.r.t. q1, q2, q3) =====
  Jx1 = -r_ext * sin(q1);
  Jx2 = -(L2*sin(q2) + L3*sin(q2 + q3)) * cos(q1);
  Jx3 = -L3 * sin(q2 + q3) * cos(q1);
  Jz1 = 0.0;
  Jz2 = -(L2*cos(q2) + L3*cos(q2 + q3));
  Jz3 = -L3 * cos(q2 + q3);

  // End-effector velocity
  xd_ee = Jx1*qd1 + Jx2*qd2 + Jx3*qd3;
  zd_ee = Jz1*qd1 + Jz2*qd2 + Jz3*qd3;

  // ===== Desired Trajectory: cosine-blended spline through 4 waypoints =====
  // Preserves tool orientation: q1 = 0, q2 + q3 = 0 throughout
  if time < t_wp[2] then
    q2_des = q2_wp[1] + (q2_wp[2] - q2_wp[1]) * 0.5 *
      (1.0 - cos(Modelica.Constants.pi * (time - t_wp[1]) / (t_wp[2] - t_wp[1])));
    qd2_des = (q2_wp[2] - q2_wp[1]) * 0.5 * Modelica.Constants.pi *
      sin(Modelica.Constants.pi * (time - t_wp[1]) / (t_wp[2] - t_wp[1])) /
      (t_wp[2] - t_wp[1]);
  elseif time < t_wp[3] then
    q2_des = q2_wp[2] + (q2_wp[3] - q2_wp[2]) * 0.5 *
      (1.0 - cos(Modelica.Constants.pi * (time - t_wp[2]) / (t_wp[3] - t_wp[2])));
    qd2_des = (q2_wp[3] - q2_wp[2]) * 0.5 * Modelica.Constants.pi *
      sin(Modelica.Constants.pi * (time - t_wp[2]) / (t_wp[3] - t_wp[2])) /
      (t_wp[3] - t_wp[2]);
  elseif time < t_wp[4] then
    q2_des = q2_wp[3] + (q2_wp[4] - q2_wp[3]) * 0.5 *
      (1.0 - cos(Modelica.Constants.pi * (time - t_wp[3]) / (t_wp[4] - t_wp[3])));
    qd2_des = (q2_wp[4] - q2_wp[3]) * 0.5 * Modelica.Constants.pi *
      sin(Modelica.Constants.pi * (time - t_wp[3]) / (t_wp[4] - t_wp[3])) /
      (t_wp[4] - t_wp[3]);
  else
    q2_des = q2_wp[4];
    qd2_des = 0.0;
  end if;

  // Map desired joint angle to Cartesian (constant orientation: q2 + q3 = 0)
  x_des = L1 + L3 + L2 * cos(q2_des);
  z_des = -L2 * sin(q2_des);
  xd_des = -L2 * sin(q2_des) * qd2_des;
  zd_des = -L2 * cos(q2_des) * qd2_des;

  // ===== Tracking Errors =====
  x_err = x_ee - x_des;
  z_err = z_ee - z_des;
  cart_err = sqrt(x_err*x_err + z_err*z_err + 1e-12);
  orient_err = sqrt(q1*q1 + (q2 + q3)*(q2 + q3) + 1e-12);

  // ===== Operational-Space Controller (discrete, 200 Hz) =====
  when sample(0, Ts) then
    Fx_cmd = -Kpc * (x_ee - x_des) - Kdc * (xd_ee - xd_des);
    Fz_cmd = -Kpc * (z_ee - z_des) - Kdc * (zd_ee - zd_des);
  end when;

  // ===== Joint Limit Avoidance (repulsive potential) =====
  pen1 = if q1 > (q1_lim - q_margin) then
           -q_pen_gain*(q1 - (q1_lim - q_margin))
         elseif q1 < -(q1_lim - q_margin) then
           -q_pen_gain*(q1 + (q1_lim - q_margin))
         else 0.0;
  pen2 = if q2 > (q2_lim - q_margin) then
           -q_pen_gain*(q2 - (q2_lim - q_margin))
         elseif q2 < -(q2_lim - q_margin) then
           -q_pen_gain*(q2 + (q2_lim - q_margin))
         else 0.0;
  pen3 = if q3 > (q3_lim - q_margin) then
           -q_pen_gain*(q3 - (q3_lim - q_margin))
         elseif q3 < -(q3_lim - q_margin) then
           -q_pen_gain*(q3 + (q3_lim - q_margin))
         else 0.0;

  // ===== Torque: Jacobian transpose + orientation PD + limit avoidance =====
  tau1_raw = Jx1*Fx_cmd + Jz1*Fz_cmd - Kpo*q1 - Kdo*qd1 + pen1;
  tau2_raw = Jx2*Fx_cmd + Jz2*Fz_cmd - Kpo*(q2 + q3) - Kdo*(qd2 + qd3) + pen2;
  tau3_raw = Jx3*Fx_cmd + Jz3*Fz_cmd - Kpo*(q2 + q3) - Kdo*(qd2 + qd3) + pen3;

  // ===== Torque Saturation (85 N.m per joint) =====
  tau1 = if tau1_raw > tau_max then tau_max
         elseif tau1_raw < -tau_max then -tau_max
         else tau1_raw;
  tau2 = if tau2_raw > tau_max then tau_max
         elseif tau2_raw < -tau_max then -tau_max
         else tau2_raw;
  tau3 = if tau3_raw > tau_max then tau_max
         elseif tau3_raw < -tau_max then -tau_max
         else tau3_raw;

  // ===== Plant Dynamics =====
  // Disturbance enters as generalized force via Jacobian transpose
  I1 * der(qd1) = tau1 - B1*qd1 + Jx1*Fd_x;
  I2 * der(qd2) = tau2 - B2*qd2 + Jx2*Fd_x;
  I3 * der(qd3) = tau3 - B3*qd3 + Jx3*Fd_x;
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;

  // ===== Disturbance: 10 N during middle third [T_run/3, 2*T_run/3] =====
  Fd_x = if (time >= T_run/3.0 and time <= 2.0*T_run/3.0) then -F_dist
         else 0.0;

  // ===== Obstacle Clearance =====
  obs_dist = sqrt((x_ee - obs_cx)*(x_ee - obs_cx) +
                  (z_ee - obs_cz)*(z_ee - obs_cz) + 1e-12);
  obs_clear = obs_dist - obs_r;

  // ===== Wrist Wrench (available from Cartesian command) =====
  wrist_wrench = sqrt(Fx_cmd*Fx_cmd + Fz_cmd*Fz_cmd + 1e-12);

  // ===== Command Norm =====
  cmd_norm = sqrt(tau1*tau1 + tau2*tau2 + tau3*tau3 + 1e-12);

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6,
               Interval = 0.005),
    Documentation(info =
      "Three-revolute Z-Y-Y arm (0.50, 0.38, 0.24 m links) with encoder
       feedback tracking a Cartesian spline through four timestamped poses
       at constant tool orientation. Operational-space PD control at 200 Hz
       via Jacobian-transpose torque mapping, joint-limit avoidance,
       fixed cylindrical obstacle with required clearance 0.06 m, and
       10 N tool disturbance during middle third of 14 s run. Torque
       limited to 85 N.m per joint. Synchronized state, command, and
       sensor traces retained at 200 Hz."));
end JointPathSplineD;