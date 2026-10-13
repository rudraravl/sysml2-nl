model ContactArmGraspD
  "Instrumented contact-rich manipulation: 6-DOF arm grasp with impedance/force-regulation control";

  // --- Physical parameters ---
  parameter Real tau_max   = 120.0 "Maximum joint effort (N.m)";
  parameter Real mu         = 0.78  "Friction coefficient";
  parameter Real e_rest     = 0.03  "Restitution coefficient";
  parameter Real m_obj      = 1.0   "Object mass (kg)";
  parameter Real I_joint    = 0.5   "Joint inertia (kg.m^2)";

  // --- Contact parameters ---
  parameter Real K_contact  = 2000.0 "Normal contact stiffness (N/m)";
  parameter Real D_contact  = 50.0   "Normal contact damping (N.s/m)";
  parameter Real K_grip     = 5000.0 "Grip tangential stiffness (N/m)";
  parameter Real D_grip     = 50.0   "Grip tangential damping (N.s/m)";

  // --- Control parameters ---
  parameter Real K_imp      = 500.0  "Impedance stiffness approach (N/m)";
  parameter Real D_imp      = 100.0  "Impedance damping approach (N.s/m)";
  parameter Real K_imp_y    = 2000.0 "Impedance stiffness lateral (N/m)";
  parameter Real D_imp_y    = 200.0  "Impedance damping lateral (N.s/m)";
  parameter Real K_force    = 20.0   "Force regulation gain";
  parameter Real D_force    = 800.0  "Force regulation damping (N.s/m)";
  parameter Real F_grasp    = 15.0   "Target normal grasp force (N)";

  // --- Scenario parameters ---
  parameter Real F_dist      = 8.0  "Tangential disturbance (N)";
  parameter Real Ts          = 0.005 "Control sample time (s) - 200 Hz";
  parameter Real T_total     = 14.0  "Total simulation duration (s)";
  parameter Real T_imp2force = 4.0   "Impedance to force-regulation switch (s)";
  parameter Real T_dist_start = T_total / 3.0      "Disturbance start (s)";
  parameter Real T_dist_end   = 2.0 * T_total / 3.0 "Disturbance end (s)";
  parameter Real x_des       = 0.30  "Desired approach position (m)";
  parameter Real y_des       = 0.0   "Desired lateral position (m)";
  parameter Real x_obj0      = 0.30  "Object position in approach direction (m)";

  // --- Joint states ---
  Real q[6](start = {0.1, 0.0, 0.0, 0.0, 0.0, 0.0}) "Joint angles (rad)";
  Real dq[6](start = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}) "Joint velocities (rad/s)";
  Real tau_cmd[6] "Commanded joint torques (N.m)";
  Real tau_sat[6]  "Saturated joint torques (N.m)";

  // --- End-effector kinematics ---
  Real x_ee  "End-effector approach position (m)";
  Real y_ee  "End-effector lateral position (m)";
  Real dx_ee "End-effector approach velocity (m/s)";
  Real dy_ee "End-effector lateral velocity (m/s)";

  // --- Jacobian (simplified constant for Z-Y-Y-X-Y-X arm) ---
  Real J[2, 6];

  // --- Object state ---
  Real y_obj(start = 0.0, fixed = true)  "Object lateral position (m)";
  Real dy_obj(start = 0.0, fixed = true) "Object lateral velocity (m/s)";

  // --- Contact and grip ---
  Real penetration      "Contact penetration depth (m)";
  Real F_normal         "Normal contact force (N)";
  Real F_grip_raw       "Raw grip tangential force (N)";
  Real F_grip           "Friction-limited grip force on arm (N)";
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

  // --- Synchronized instrumented traces ---
  Real q_trace[6]    "Joint state trace";
  Real dq_trace[6]   "Joint velocity trace";
  Real tau_trace[6]  "Saturated torque trace";

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
  J[1,1] = 0.15;  J[1,2] = 0.08;  J[1,3] = 0.05;
  J[1,4] = 0.0;   J[1,5] = 0.0;   J[1,6] = 0.0;
  J[2,1] = 0.0;   J[2,2] = 0.0;   J[2,3] = 0.0;
  J[2,4] = 0.12;  J[2,5] = 0.07;  J[2,6] = 0.04;

  // Forward kinematics
  x_ee  = 0.40 + J[1,1]*q[1] + J[1,2]*q[2] + J[1,3]*q[3];
  y_ee  = J[2,4]*q[4] + J[2,5]*q[5] + J[2,6]*q[6];
  dx_ee = J[1,1]*dq[1] + J[1,2]*dq[2] + J[1,3]*dq[3];
  dy_ee = J[2,4]*dq[4] + J[2,5]*dq[5] + J[2,6]*dq[6];

  // Control mode and disturbance scheduling
  mode = if noEvent(time < T_imp2force) then 0.0 else 1.0;
  F_disturbance = if noEvent(time >= T_dist_start and time <= T_dist_end) then F_dist else 0.0;

  // Normal contact: spring-damper, clamped non-negative
  penetration = x_obj0 - x_ee;
  F_normal = noEvent(max(0.0, K_contact * penetration + D_contact * (1.0 + e_rest) * (-dx_ee)));

  // Tangential grip: spring-damper limited by Coulomb friction mu * F_normal
  F_friction_limit = mu * F_normal;
  F_grip_raw = K_grip * (y_obj - y_ee) + D_grip * (dy_obj - dy_ee);
  F_grip = noEvent(if F_grip_raw > F_friction_limit then F_friction_limit
           elseif F_grip_raw < -F_friction_limit then -F_friction_limit
           else F_grip_raw);

  // Object lateral dynamics (table constrains x; friction holds y)
  der(dy_obj) = (F_disturbance - F_grip) / m_obj;
  der(y_obj) = dy_obj;

  // Wrist six-axis sensor (two dominant axes modelled)
  F_sensor_n = F_normal;
  F_sensor_t = F_grip;

  // Control law: approach impedance -> force regulation
  F_ctrl_x = if noEvent(mode < 0.5) then
      K_imp * (x_des - x_ee) - D_imp * dx_ee
    else
      K_force * (F_grasp - F_normal) - D_force * dx_ee;

  // Lateral: position-holding impedance in both modes
  F_ctrl_y = K_imp_y * (y_des - y_ee) - D_imp_y * dy_ee;

  // Operational-space force -> joint torques via Jacobian transpose
  tau_cmd[1] = J[1,1] * F_ctrl_x + J[2,1] * F_ctrl_y;
  tau_cmd[2] = J[1,2] * F_ctrl_x + J[2,2] * F_ctrl_y;
  tau_cmd[3] = J[1,3] * F_ctrl_x + J[2,3] * F_ctrl_y;
  tau_cmd[4] = J[1,4] * F_ctrl_x + J[2,4] * F_ctrl_y;
  tau_cmd[5] = J[1,5] * F_ctrl_x + J[2,5] * F_ctrl_y;
  tau_cmd[6] = J[1,6] * F_ctrl_x + J[2,6] * F_ctrl_y;

  // Saturated actuators (plus/minus 120 N.m)
  tau_sat[1] = noEvent(if tau_cmd[1] > tau_max then tau_max elseif tau_cmd[1] < -tau_max then -tau_max else tau_cmd[1]);
  tau_sat[2] = noEvent(if tau_cmd[2] > tau_max then tau_max elseif tau_cmd[2] < -tau_max then -tau_max else tau_cmd[2]);
  tau_sat[3] = noEvent(if tau_cmd[3] > tau_max then tau_max elseif tau_cmd[3] < -tau_max then -tau_max else tau_cmd[3]);
  tau_sat[4] = noEvent(if tau_cmd[4] > tau_max then tau_max elseif tau_cmd[4] < -tau_max then -tau_max else tau_cmd[4]);
  tau_sat[5] = noEvent(if tau_cmd[5] > tau_max then tau_max elseif tau_cmd[5] < -tau_max then -tau_max else tau_cmd[5]);
  tau_sat[6] = noEvent(if tau_cmd[6] > tau_max then tau_max elseif tau_cmd[6] < -tau_max then -tau_max else tau_cmd[6]);

  // Joint dynamics: I * ddq = tau_sat + J^T * F_ext_contact
  der(dq[1]) = (tau_sat[1] + J[1,1] * F_normal + J[2,1] * F_grip) / I_joint;
  der(dq[2]) = (tau_sat[2] + J[1,2] * F_normal + J[2,2] * F_grip) / I_joint;
  der(dq[3]) = (tau_sat[3] + J[1,3] * F_normal + J[2,3] * F_grip) / I_joint;
  der(dq[4]) = (tau_sat[4] + J[1,4] * F_normal + J[2,4] * F_grip) / I_joint;
  der(dq[5]) = (tau_sat[5] + J[1,5] * F_normal + J[2,5] * F_grip) / I_joint;
  der(dq[6]) = (tau_sat[6] + J[1,6] * F_normal + J[2,6] * F_grip) / I_joint;

  der(q[1]) = dq[1];
  der(q[2]) = dq[2];
  der(q[3]) = dq[3];
  der(q[4]) = dq[4];
  der(q[5]) = dq[5];
  der(q[6]) = dq[6];

  // Tracking error with well-defined zero branch
  track_err = sqrt((x_ee - x_des)*(x_ee - x_des) + (y_ee - y_des)*(y_ee - y_des) + 1.0e-12);

  // Internal trace arrays
  q_trace[1]   = q[1];   q_trace[2]   = q[2];   q_trace[3]   = q[3];
  q_trace[4]   = q[4];   q_trace[5]   = q[5];   q_trace[6]   = q[6];
  dq_trace[1]  = dq[1];  dq_trace[2]  = dq[2];  dq_trace[3]  = dq[3];
  dq_trace[4]  = dq[4];  dq_trace[5]  = dq[5];  dq_trace[6]  = dq[6];
  tau_trace[1] = tau_sat[1]; tau_trace[2] = tau_sat[2]; tau_trace[3] = tau_sat[3];
  tau_trace[4] = tau_sat[4]; tau_trace[5] = tau_sat[5]; tau_trace[6] = tau_sat[6];

  // Scalar FMI outputs
  F_n_trace    = F_sensor_n;
  F_t_trace    = F_sensor_t;
  pose_y_trace = y_obj;
  err_trace    = track_err;
  q1_trace     = q[1];
  q2_trace     = q[2];
  q3_trace     = q[3];
  q4_trace     = q[4];
  q5_trace     = q[5];
  q6_trace     = q[6];
  tau1_trace   = tau_sat[1];
  tau2_trace   = tau_sat[2];
  tau3_trace   = tau_sat[3];
  tau4_trace   = tau_sat[4];
  tau5_trace   = tau_sat[5];
  tau6_trace   = tau_sat[6];

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "Contact-rich 6-DOF arm grasp: impedance then force regulation with tangential disturbance in middle third. 200 Hz, 14 s."));
end ContactArmGraspD;