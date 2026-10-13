model JointPathSplineF
  "Trajectory-controlled 3R Z-Y-Y arm tracking a Cartesian spline through four
   timestamped poses while preserving tool orientation. Operational-space
   tracking with joint-limit avoidance. 500 Hz control, 20 s mission.
   14.5 N tool disturbance during middle third. Fixed cylindrical obstacle
   with required clearance 0.06 m."

  // ===== Link parameters =====
  parameter Real L1 = 0.50 "Link 1 length [m]";
  parameter Real L2 = 0.38 "Link 2 length [m]";
  parameter Real L3 = 0.24 "Link 3 length [m]";
  parameter Real tau_max = 104.0 "Maximum per-joint torque [N.m]";

  // ===== Inertial / damping parameters =====
  parameter Real J1_inertia = 0.80 "Joint 1 reflected inertia [kg.m2]";
  parameter Real J2_inertia = 0.50 "Joint 2 reflected inertia [kg.m2]";
  parameter Real J3_inertia = 0.20 "Joint 3 reflected inertia [kg.m2]";
  parameter Real b1 = 1.5 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 1.0 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 0.5 "Joint 3 viscous damping [N.m.s/rad]";

  // ===== Control gains =====
  parameter Real Kp_task = 1200.0 "Task-space proportional gain [N/m]";
  parameter Real Kd_task = 80.0 "Task-space derivative gain [N.s/m]";
  parameter Real Kv_joint = 2.0 "Joint-space velocity damping [N.m.s/rad]";
  parameter Real K_limit = 200.0 "Joint limit avoidance gain [N.m/rad]";
  parameter Real margin_limit = 0.30 "Joint limit activation margin [rad]";

  // ===== Joint limits =====
  parameter Real q1_min = -2.80 "Joint 1 lower limit [rad]";
  parameter Real q1_max =  2.80 "Joint 1 upper limit [rad]";
  parameter Real q2_min =  0.10 "Joint 2 lower limit [rad]";
  parameter Real q2_max =  2.90 "Joint 2 upper limit [rad]";
  parameter Real q3_min = -2.50 "Joint 3 lower limit [rad]";
  parameter Real q3_max =  2.50 "Joint 3 upper limit [rad]";

  // ===== Obstacle =====
  parameter Real obs_x = 0.90 "Obstacle center x [m]";
  parameter Real obs_z = 0.35 "Obstacle center z [m]";
  parameter Real obs_radius = 0.05 "Obstacle cylinder radius [m]";
  parameter Real obs_clearance_req = 0.06 "Required clearance [m]";

  // ===== Disturbance =====
  parameter Real F_dist_mag = 14.5 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 6.67 "Disturbance start time [s]";
  parameter Real t_dist_end = 13.33 "Disturbance end time [s]";

  // ===== Timing =====
  parameter Real Ts = 0.002 "Control update period — 500 Hz [s]";
  parameter Real T_final = 20.0 "Mission duration [s]";
  parameter Real tracking_thresh = 0.028 "Primary tracking error threshold [m]";
  parameter Real t_verify = 13.0 "Verification start time [s]";

  // ===== Trajectory waypoints =====
  parameter Real q2_wp1 = 1.0471975511965976 "WP1 q2 = pi/3 [rad]";
  parameter Real q2_wp2 = 1.5707963267948966 "WP2 q2 = pi/2 [rad]";
  parameter Real q2_wp3 = 2.0943951023931953 "WP3 q2 = 2pi/3 [rad]";
  parameter Real q2_wp4 = 1.5707963267948966 "WP4 q2 = pi/2 [rad]";
  parameter Real t_wp1 = 0.0  "WP1 timestamp [s]";
  parameter Real t_wp2 = 7.0  "WP2 timestamp [s]";
  parameter Real t_wp3 = 14.0 "WP3 timestamp [s]";
  parameter Real t_wp4 = 20.0 "WP4 timestamp [s]";
  parameter Real pi_val = 3.141592653589793 "Pi constant";

  parameter Real eps = 1.0e-9 "Regularisation for norm divisors";

  // ===== Joint states =====
  Real q1(start=0.0) "Joint 1 angle (Z axis) [rad]";
  Real q2(start=1.0471975511965976) "Joint 2 angle (Y axis) [rad]";
  Real q3(start=0.5235987755982988) "Joint 3 angle (Y axis) [rad]";
  Real qdot1(start=0.0) "Joint 1 velocity [rad/s]";
  Real qdot2(start=0.0) "Joint 2 velocity [rad/s]";
  Real qdot3(start=0.0) "Joint 3 velocity [rad/s]";

  // ===== Torques =====
  Real tau1 "Joint 1 applied torque [N.m]";
  Real tau2 "Joint 2 applied torque [N.m]";
  Real tau3 "Joint 3 applied torque [N.m]";
  Real tau1_raw "Joint 1 unclamped command [N.m]";
  Real tau2_raw "Joint 2 unclamped command [N.m]";
  Real tau3_raw "Joint 3 unclamped command [N.m]";
  Real tau1_limit "Joint 1 limit-avoidance torque [N.m]";
  Real tau2_limit "Joint 2 limit-avoidance torque [N.m]";
  Real tau3_limit "Joint 3 limit-avoidance torque [N.m]";

  // ===== Forward kinematics =====
  Real p2x "Shoulder x [m]";
  Real p2z "Shoulder z [m]";
  Real p3x "Elbow x [m]";
  Real p3z "Elbow z [m]";
  Real px "End-effector x [m]";
  Real py "End-effector y [m]";
  Real pz "End-effector z [m]";

  // ===== Jacobian =====
  Real J11, J12, J13;
  Real J21, J22, J23;
  Real J31, J32, J33;

  // ===== Cartesian velocity =====
  Real px_dot "End-effector x velocity [m/s]";
  Real py_dot "End-effector y velocity [m/s]";
  Real pz_dot "End-effector z velocity [m/s]";

  // ===== Desired trajectory =====
  Real q1_des "Desired joint 1 [rad]";
  Real q2_des "Desired joint 2 [rad]";
  Real q3_des "Desired joint 3 [rad]";
  Real q2_des_dot "Desired joint 2 velocity [rad/s]";
  Real q3_des_dot "Desired joint 3 velocity [rad/s]";
  Real px_des "Desired EE x [m]";
  Real py_des "Desired EE y [m]";
  Real pz_des "Desired EE z [m]";
  Real px_des_dot "Desired EE x velocity [m/s]";
  Real pz_des_dot "Desired EE z velocity [m/s]";

  // ===== Errors =====
  Real err_x "Cartesian x error [m]";
  Real err_y "Cartesian y error [m]";
  Real err_z "Cartesian z error [m]";
  Real cart_error "Euclidean Cartesian tracking error [m]";
  Real orient_error "Orientation error [rad]";

  // ===== Task-space control forces =====
  Real Fx_task "Task force x [N]";
  Real Fy_task "Task force y [N]";
  Real Fz_task "Task force z [N]";

  // ===== Disturbance =====
  Real F_dist "Current disturbance force magnitude [N]";
  Real F_dist_x "Disturbance force x-component [N]";
  Real F_dist_z "Disturbance force z-component [N]";
  Real dist_tau1 "Disturbance torque joint 1 [N.m]";
  Real dist_tau2 "Disturbance torque joint 2 [N.m]";
  Real dist_tau3 "Disturbance torque joint 3 [N.m]";

  // ===== Wrist wrench =====
  Real wrench_x "Wrist wrench x [N]";
  Real wrench_z "Wrist wrench z [N]";
  Real wrench_norm "Wrist wrench magnitude [N]";

  // ===== Obstacle clearance =====
  Real dist1_obs "Link 1 to obstacle distance [m]";
  Real dist2_obs "Link 2 to obstacle distance [m]";
  Real dist3_obs "Link 3 to obstacle distance [m]";
  Real min_obs_dist "Minimum link-obstacle distance [m]";
  Real clearance "Obstacle clearance [m]";

  // ===== Verification flags =====
  Boolean tracking_ok "Primary tracking error below threshold after 13 s";
  Boolean torque_bounds_ok "Effort within 104 N.m per joint";
  Boolean joint_bounds_ok "Joint angles within limits";
  Boolean clearance_ok "Obstacle clearance at least 0.06 m";
  Boolean finite_ok "No NaN or infinite values";
  Boolean all_ok "All verification criteria met";

protected
  function smoothstep_val
    input Real u;
    output Real y;
  algorithm
    if u <= 0.0 then
      y := 0.0;
    elseif u >= 1.0 then
      y := 1.0;
    else
      y := u*u*u*(10.0 - 15.0*u + 6.0*u*u);
    end if;
  end smoothstep_val;

  function smoothstep_der
    input Real u;
    output Real y;
  algorithm
    if u <= 0.0 then
      y := 0.0;
    elseif u >= 1.0 then
      y := 0.0;
    else
      y := 30.0*u*u*(1.0 - u)*(1.0 - u);
    end if;
  end smoothstep_der;

  function joint_limit_tau
    input Real q;
    input Real q_min;
    input Real q_max;
    input Real margin;
    input Real K;
    output Real tau;
  algorithm
    tau := 0.0;
    if q < q_min + margin then
      tau := K*(q_min + margin - q);
    elseif q > q_max - margin then
      tau := -K*(q - (q_max - margin));
    end if;
  end joint_limit_tau;

  function pt_seg_dist
    input Real ax;
    input Real az;
    input Real bx;
    input Real bz;
    input Real ox;
    input Real oz;
    output Real d;
  protected
    Real dx;
    Real dz;
    Real len2;
    Real t;
    Real cx;
    Real cz;
  algorithm
    dx := bx - ax;
    dz := bz - az;
    len2 := dx*dx + dz*dz;
    if len2 < 1.0e-12 then
      t := 0.0;
    else
      t := ((ox - ax)*dx + (oz - az)*dz)/len2;
    end if;
    if t < 0.0 then
      t := 0.0;
    elseif t > 1.0 then
      t := 1.0;
    end if;
    cx := ax + t*dx;
    cz := az + t*dz;
    d := sqrt((ox - cx)*(ox - cx) + (oz - cz)*(oz - cz));
  end pt_seg_dist;

equation
  // ===== Forward kinematics (Z-Y-Y chain) =====
  p2x = L1*cos(q1);
  p2z = 0.0;
  p3x = L1*cos(q1) + L2*cos(q1)*cos(q2);
  p3z = L2*sin(q2);
  px = L1*cos(q1) + L2*cos(q1)*cos(q2) + L3*cos(q1)*cos(q2 + q3);
  py = L1*sin(q1) + L2*sin(q1)*cos(q2) + L3*sin(q1)*cos(q2 + q3);
  pz = L2*sin(q2) + L3*sin(q2 + q3);

  // ===== Analytical Jacobian =====
  J11 = -L1*sin(q1) - L2*sin(q1)*cos(q2) - L3*sin(q1)*cos(q2 + q3);
  J21 =  L1*cos(q1) + L2*cos(q1)*cos(q2) + L3*cos(q1)*cos(q2 + q3);
  J31 =  0.0;
  J12 = -L2*cos(q1)*sin(q2) - L3*cos(q1)*sin(q2 + q3);
  J22 = -L2*sin(q1)*sin(q2) - L3*sin(q1)*sin(q2 + q3);
  J32 =  L2*cos(q2) + L3*cos(q2 + q3);
  J13 = -L3*cos(q1)*sin(q2 + q3);
  J23 = -L3*sin(q1)*sin(q2 + q3);
  J33 =  L3*cos(q2 + q3);

  // ===== Actual end-effector velocity =====
  px_dot = J11*qdot1 + J12*qdot2 + J13*qdot3;
  py_dot = J21*qdot1 + J22*qdot2 + J23*qdot3;
  pz_dot = J31*qdot1 + J32*qdot2 + J33*qdot3;

  // ===== Desired trajectory =====
  q1_des = 0.0;

  q2_des = if time < t_wp2 then
             q2_wp1 + (q2_wp2 - q2_wp1)*smoothstep_val((time - t_wp1)/(t_wp2 - t_wp1))
           elseif time < t_wp3 then
             q2_wp2 + (q2_wp3 - q2_wp2)*smoothstep_val((time - t_wp2)/(t_wp3 - t_wp2))
           else
             q2_wp3 + (q2_wp4 - q2_wp3)*smoothstep_val((time - t_wp3)/(t_wp4 - t_wp3));

  q2_des_dot = if time < t_wp2 then
                 (q2_wp2 - q2_wp1)*smoothstep_der((time - t_wp1)/(t_wp2 - t_wp1))/(t_wp2 - t_wp1)
               elseif time < t_wp3 then
                 (q2_wp3 - q2_wp2)*smoothstep_der((time - t_wp2)/(t_wp3 - t_wp2))/(t_wp3 - t_wp2)
               else
                 (q2_wp4 - q2_wp3)*smoothstep_der((time - t_wp3)/(t_wp4 - t_wp3))/(t_wp4 - t_wp3);

  q3_des = pi_val/2.0 - q2_des;
  q3_des_dot = -q2_des_dot;

  // ===== Desired Cartesian pose (q1_des=0, q2_des+q3_des=pi/2) =====
  px_des = L1 + L2*cos(q2_des) + L3*cos(pi_val/2.0);
  py_des = 0.0;
  pz_des = L2*sin(q2_des) + L3*sin(pi_val/2.0);

  px_des_dot = -L2*sin(q2_des)*q2_des_dot;
  pz_des_dot =  L2*cos(q2_des)*q2_des_dot;

  // ===== Cartesian tracking error =====
  err_x = px_des - px;
  err_y = py_des - py;
  err_z = pz_des - pz;
  cart_error = sqrt(err_x*err_x + err_y*err_y + err_z*err_z + eps);

  // ===== Orientation error =====
  orient_error = sqrt((q1 - q1_des)*(q1 - q1_des)
                      + ((q2 + q3) - (q2_des + q3_des))*((q2 + q3) - (q2_des + q3_des))
                      + eps);

  // ===== Operational-space PD control =====
  Fx_task = Kp_task*err_x + Kd_task*(px_des_dot - px_dot);
  Fy_task = Kp_task*err_y + Kd_task*(0.0 - py_dot);
  Fz_task = Kp_task*err_z + Kd_task*(pz_des_dot - pz_dot);

  // ===== Disturbance: 14.5 N in -x during middle third =====
  F_dist = if (time >= t_dist_start and time <= t_dist_end) then F_dist_mag else 0.0;
  F_dist_x = -F_dist;
  F_dist_z = 0.0;

  dist_tau1 = J11*F_dist_x + J31*F_dist_z;
  dist_tau2 = J12*F_dist_x + J32*F_dist_z;
  dist_tau3 = J13*F_dist_x + J33*F_dist_z;

  // ===== Wrist wrench =====
  wrench_x = Fx_task + F_dist_x;
  wrench_z = Fz_task + F_dist_z;
  wrench_norm = sqrt(wrench_x*wrench_x + wrench_z*wrench_z + eps);

  // ===== Joint-limit avoidance torques =====
  tau1_limit = joint_limit_tau(q1, q1_min, q1_max, margin_limit, K_limit);
  tau2_limit = joint_limit_tau(q2, q2_min, q2_max, margin_limit, K_limit);
  tau3_limit = joint_limit_tau(q3, q3_min, q3_max, margin_limit, K_limit);

  // ===== Raw torque: Jacobian-transpose control =====
  tau1_raw = J11*Fx_task + J21*Fy_task + J31*Fz_task + tau1_limit - Kv_joint*qdot1;
  tau2_raw = J12*Fx_task + J22*Fy_task + J32*Fz_task + tau2_limit - Kv_joint*qdot2;
  tau3_raw = J13*Fx_task + J23*Fy_task + J33*Fz_task + tau3_limit - Kv_joint*qdot3;

  // ===== Torque saturation =====
  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));
  tau3 = max(-tau_max, min(tau_max, tau3_raw));

  // ===== Plant dynamics =====
  J1_inertia*der(qdot1) + b1*qdot1 = tau1 + dist_tau1;
  der(q1) = qdot1;
  J2_inertia*der(qdot2) + b2*qdot2 = tau2 + dist_tau2;
  der(q2) = qdot2;
  J3_inertia*der(qdot3) + b3*qdot3 = tau3 + dist_tau3;
  der(q3) = qdot3;

  // ===== Obstacle clearance =====
  dist1_obs = pt_seg_dist(0.0, 0.0, p2x, p2z, obs_x, obs_z);
  dist2_obs = pt_seg_dist(p2x, p2z, p3x, p3z, obs_x, obs_z);
  dist3_obs = pt_seg_dist(p3x, p3z, px, pz, obs_x, obs_z);
  min_obs_dist = min(dist1_obs, min(dist2_obs, dist3_obs));
  clearance = min_obs_dist - obs_radius;

  // ===== Verification criteria =====
  tracking_ok = (time >= t_verify) and (cart_error < tracking_thresh);
  torque_bounds_ok = (abs(tau1) <= tau_max + eps)
                     and (abs(tau2) <= tau_max + eps)
                     and (abs(tau3) <= tau_max + eps);
  joint_bounds_ok = (q1 > q1_min) and (q1 < q1_max)
                    and (q2 > q2_min) and (q2 < q2_max)
                    and (q3 > q3_min) and (q3 < q3_max);
  clearance_ok = clearance >= obs_clearance_req;
  finite_ok = (q1 > -1.0e6) and (q1 < 1.0e6)
              and (q2 > -1.0e6) and (q2 < 1.0e6)
              and (q3 > -1.0e6) and (q3 < 1.0e6)
              and (qdot1 > -1.0e6) and (qdot1 < 1.0e6)
              and (qdot2 > -1.0e6) and (qdot2 < 1.0e6)
              and (qdot3 > -1.0e6) and (qdot3 < 1.0e6)
              and (tau1 > -1.0e6) and (tau1 < 1.0e6)
              and (tau2 > -1.0e6) and (tau2 < 1.0e6)
              and (tau3 > -1.0e6) and (tau3 < 1.0e6)
              and (cart_error < 1.0e6) and (orient_error < 1.0e6)
              and (clearance < 1.0e6) and (wrench_norm < 1.0e6);
  all_ok = tracking_ok and torque_bounds_ok and joint_bounds_ok
           and clearance_ok and finite_ok;

  annotation(
    Experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Three-revolute-joint Z-Y-Y arm (0.50, 0.38, 0.24 m links)
      tracking a Cartesian spline through four timestamped poses while preserving
      tool orientation (q1=0, q2+q3=pi/2). Operational-space PD control via
      Jacobian transpose with joint-limit avoidance. 14.5 N tool disturbance
      applied during the middle third (6.67-13.33 s). Fixed cylindrical obstacle
      at (0.90, 0.35) m with radius 0.05 m; required clearance 0.06 m.
      Controller runs at 500 Hz (Interval = 0.002 s) for 20 s.
      Verification: tracking error < 0.028 m after 13 s, torque <= 104 N.m,
      joint limits, clearance, and finite values.")
  );
end JointPathSplineF;