model ContactArmGraspD
  "Instrumented contact-rich manipulation: 6-DOF arm grasp with impedance/force-regulation control";

  // --- Physical parameters ---
  parameter Real tau_max  = 120.0 "Maximum joint effort (N.m)";
  parameter Real mu        = 0.78  "Friction coefficient";
  parameter Real e_rest    = 0.03  "Restitution coefficient";
  parameter Real m_obj     = 1.0   "Object mass (kg)";
  parameter Real I_joint   = 0.5   "Joint inertia (kg.m^2)";

  // --- Contact parameters ---
  parameter Real K_contact = 2000.0 "Normal contact stiffness (N/m)";
  parameter Real D_contact = 50.0   "Normal contact damping (N.s/m)";
  parameter Real K_grip    = 5000.0 "Grip tangential stiffness (N/m)";
  parameter Real D_grip    = 50.0   "Grip tangential damping (N.s/m)";

  // --- Control parameters ---
  parameter Real K_imp     = 500.0  "Impedance stiffness approach (N/m)";
  parameter Real D_imp     = 100.0  "Impedance damping approach (N.s/m)";
  parameter Real K_imp_y   = 2000.0 "Impedance stiffness lateral (N/m)";
  parameter Real D_imp_y   = 200.0  "Impedance damping lateral (N.s/m)";
  parameter Real K_force   = 20.0   "Force regulation gain";
  parameter Real D_force   = 800.0  "Force regulation damping (N.s/m)";
  parameter Real F_grasp   = 15.0   "Target normal grasp force (N)";

  // --- Scenario parameters ---
  parameter Real F_dist       = 8.0  "Tangential disturbance (N)";
  parameter Real Ts           = 0.005 "Control sample time (s) - 200 Hz";
  parameter Real T_total      = 14.0  "Total simulation duration (s)";
  parameter Real T_imp2force  = 4.0   "Impedance to force-regulation switch (s)";
  parameter Real T_dist_start = T_total / 3.0      "Disturbance start (s)";
  parameter Real T_dist_end   = 2.0 * T_total / 3.0 "Disturbance end (s)";
  parameter Real x_des       = 0.30  "Desired approach position (m)";
  parameter Real y_des       = 0.0   "Desired lateral position (m)";
  parameter Real x_obj0      = 0.30  "Object position in approach direction (m)";

  // --- Joint states (scalars to avoid array-related codegen issues) ---
  Real q1(start = 0.1) "Joint 1 angle (rad)";
  Real q2(start = 0.0) "Joint 2 angle (rad)";
  Real q3(start = 0.0) "Joint 3 angle (rad)";
  Real q4(start = 0.0) "Joint 4 angle (rad)";
  Real q5(start = 0.0) "Joint 5 angle (rad)";
  Real q6(start = 0.0) "Joint 6 angle (rad)";
  Real dq1(start = 0.0) "Joint 1 velocity (rad/s)";
  Real dq2(start = 0.0) "Joint 2 velocity (rad/s)";
  Real dq3(start = 0.0) "Joint 3 velocity (rad/s)";
  Real dq4(start = 0.0) "Joint 4 velocity (rad/s)";
  Real dq5(start = 0.0) "Joint 5 velocity (rad/s)";
  Real dq6(start = 0.0) "Joint 6 velocity (rad/s)";

  // --- Commanded and saturated torques ---
  Real tau_cmd1 "Commanded joint 1 torque (N.m)";
  Real tau_cmd2 "Commanded joint 2 torque (N.m)";
  Real tau_cmd3 "Commanded joint 3 torque (N.m)";
  Real tau_cmd4 "Commanded joint 4 torque (N.m)";
  Real tau_cmd5 "Commanded joint 5 torque (N.m)";
  Real tau_cmd6 "Commanded joint 6 torque (N.m)";
  Real tau_sat1 "Saturated joint 1 torque (N.m)";
  Real tau_sat2 "Saturated joint 2 torque (N.m)";
  Real tau_sat3 "Saturated joint 3 torque (N.m)";
  Real tau_sat4 "Saturated joint 4 torque (N.m)";
  Real tau_sat5 "Saturated joint 5 torque (N.m)";
  Real tau_sat6 "Saturated joint 6 torque (N.m)";

  // --- End-effector kinematics ---
  Real x_ee  "End-effector approach position (m)";
  Real y_ee  "End-effector lateral position (m)";
  Real dx_ee "End-effector approach velocity (m/s)";
  Real dy_ee "End-effector lateral velocity (m/s)";

  // --- Jacobian elements (constant simplified for Z-Y-Y-X-Y-X) ---
  Real J11; Real J12; Real J13;
  Real J14; Real J15; Real J16;
  Real J21; Real J22; Real J23;
  Real J24; Real J25; Real J26;

  // --- Object state ---
  Real y_obj(start = 0.0, fixed = true)  "Object lateral position (m)";
  Real dy_obj(start = 0.0, fixed = true) "Object lateral velocity (m/s)";

  // --- Contact and grip ---
  Real penetration       "Contact penetration depth (m)";
  Real F_normal_raw      "Raw normal contact force (N)";
  Real F_normal          "Clamped normal contact force (N)";
  Real F_grip_raw        "Raw grip tangential force (N)";
  Real F_grip            "Friction-limited grip force on arm (N)";
  Real F_friction_limit  "Coulomb friction limit (N)";

  // --- Control ---
  Real mode          "0 = impedance, 1 = force regulation";
  Real F_ctrl_x      "Control force approach (N)";
  Real F_ctrl_y      "Control force lateral (N)";
  Real F_disturbance "Disturbance force (N)";

  // --- Sensors ---
  Real F_sensor_n "Wrist sensor normal force (N)";
  Real F_sensor_t "Wrist sensor tangential force (N)";

  // --- Tracking ---
  Real track_err "Primary tracking error (m)";

  // --- Scalar FMI outputs ---
  output Real F_n_trace    "Normal force sensor trace (N)";
  output Real F_t_trace    "Tangential force sensor trace (N)";
  output Real pose_y_trace "Object lateral pose trace (m)";
  output Real err_trace    "Tracking error trace (m)";
  output Real q1_trace     "Joint 1 angle trace (rad)";
  output Real q2_trace     "Joint 2 angle trace (rad)";
  output Real q3_trace     "Joint 3 angle trace (rad)";
  output Real q4_trace     "Joint 4 angle trace (rad)";
  output Real q5_trace     "Joint 5 angle trace (rad)";
  output Real q6_trace     "Joint 6 angle trace (rad)";
  output Real tau1_trace   "Joint 1 saturated torque trace (N.m)";
  output Real tau2_trace   "Joint 2 saturated torque trace (N.m)";
  output Real tau3_trace   "Joint 3 saturated torque trace (N.m)";
  output Real tau4_trace   "Joint 4 saturated torque trace (N.m)";
  output Real tau5_trace   "Joint 5 saturated torque trace (N.m)";
  output Real tau6_trace   "Joint 6 saturated torque trace (N.m)";

equation
  // Simplified constant Jacobian
  J11 = 0.15;  J12 = 0.08;  J13 = 0.05;
  J14 = 0.0;   J15 = 0.0;   J16 = 0.0;
  J21 = 0.0;   J22 = 0.0;   J23 = 0.0;
  J24 = 0.12;  J25 = 0.07;  J26 = 0.04;

  // Forward kinematics
  x_ee  = 0.40 + J11*q1 + J12*q2 + J13*q3;
  y_ee  = J24*q4 + J25*q5 + J26*q6;
  dx_ee = J11*dq1 + J12*dq2 + J13*dq3;
  dy_ee = J24*dq4 + J25*dq5 + J26*dq6;

  // Control mode and disturbance scheduling
  mode = if time < T_imp2force then 0.0 else 1.0;
  F_disturbance = if (time >= T_dist_start and time <= T_dist_end) then F_dist else 0.0;

  // Normal contact: spring-damper, clamped non-negative
  penetration   = x_obj0 - x_ee;
  F_normal_raw  = K_contact * penetration + D_contact * (1.0 + e_rest) * (-dx_ee);
  F_normal      = if F_normal_raw > 0.0 then F_normal_raw else 0.0;

  // Tangential grip: spring-damper limited by Coulomb friction mu * F_normal
  F_friction_limit = mu * F_normal;
  F_grip_raw = K_grip * (y_obj - y_ee) + D_grip * (dy_obj - dy_ee);
  F_grip = if F_grip_raw > F_friction_limit then F_friction_limit
           else if F_grip_raw < -F_friction_limit then -F_friction_limit
           else F_grip_raw;

  // Object lateral dynamics
  der(dy_obj) = (F_disturbance - F_grip) / m_obj;
  der(y_obj)  = dy_obj;

  // Wrist six-axis sensor (two dominant axes modelled)
  F_sensor_n = F_normal;
  F_sensor_t = F_grip;

  // Control law: approach impedance -> force regulation
  F_ctrl_x = if mode < 0.5 then
      K_imp * (x_des - x_ee) - D_imp * dx_ee
    else
      K_force * (F_grasp - F_normal) - D_force * dx_ee;

  // Lateral: position-holding impedance in both modes
  F_ctrl_y = K_imp_y * (y_des - y_ee) - D_imp_y * dy_ee;

  // Operational-space force -> joint torques via Jacobian transpose
  tau_cmd1 = J11 * F_ctrl_x + J21 * F_ctrl_y;
  tau_cmd2 = J12 * F_ctrl_x + J22 * F_ctrl_y;
  tau_cmd3 = J13 * F_ctrl_x + J23 * F_ctrl_y;
  tau_cmd4 = J14 * F_ctrl_x + J24 * F_ctrl_y;
  tau_cmd5 = J15 * F_ctrl_x + J25 * F_ctrl_y;
  tau_cmd6 = J16 * F_ctrl_x + J26 * F_ctrl_y;

  // Saturated actuators (plus/minus 120 N.m)
  tau_sat1 = if tau_cmd1 > tau_max then tau_max else if tau_cmd1 < -tau_max then -tau_max else tau_cmd1;
  tau_sat2 = if tau_cmd2 > tau_max then tau_max else if tau_cmd2 < -tau_max then -tau_max else tau_cmd2;
  tau_sat3 = if tau_cmd3 > tau_max then tau_max else if tau_cmd3 < -tau_max then -tau_max else tau_cmd3;
  tau_sat4 = if tau_cmd4 > tau_max then tau_max else if tau_cmd4 < -tau_max then -tau_max else tau_cmd4;
  tau_sat5 = if tau_cmd5 > tau_max then tau_max else if tau_cmd5 < -tau_max then -tau_max else tau_cmd5;
  tau_sat6 = if tau_cmd6 > tau_max then tau_max else if tau_cmd6 < -tau_max then -tau_max else tau_cmd6;

  // Joint dynamics: I * ddq = tau_sat + J^T * F_ext_contact
  der(dq1) = (tau_sat1 + J11 * F_normal + J21 * F_grip) / I_joint;
  der(dq2) = (tau_sat2 + J12 * F_normal + J22 * F_grip) / I_joint;
  der(dq3) = (tau_sat3 + J13 * F_normal + J23 * F_grip) / I_joint;
  der(dq4) = (tau_sat4 + J14 * F_normal + J24 * F_grip) / I_joint;
  der(dq5) = (tau_sat5 + J15 * F_normal + J25 * F_grip) / I_joint;
  der(dq6) = (tau_sat6 + J16 * F_normal + J26 * F_grip) / I_joint;

  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;
  der(q5) = dq5;
  der(q6) = dq6;

  // Tracking error with well-defined zero branch
  track_err = sqrt((x_ee - x_des)*(x_ee - x_des) + (y_ee - y_des)*(y_ee - y_des) + 1.0e-12);

  // Scalar FMI outputs
  F_n_trace    = F_sensor_n;
  F_t_trace    = F_sensor_t;
  pose_y_trace = y_obj;
  err_trace    = track_err;
  q1_trace     = q1;
  q2_trace     = q2;
  q3_trace     = q3;
  q4_trace     = q4;
  q5_trace     = q5;
  q6_trace     = q6;
  tau1_trace   = tau_sat1;
  tau2_trace   = tau_sat2;
  tau3_trace   = tau_sat3;
  tau4_trace   = tau_sat4;
  tau5_trace   = tau_sat5;
  tau6_trace   = tau_sat6;

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "Contact-rich 6-DOF arm grasp: impedance then force regulation with tangential disturbance in middle third. 200 Hz, 14 s."));
end ContactArmGraspD;