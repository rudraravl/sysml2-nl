model ContactArmGraspD
  "Instrumented contact-rich manipulation 6-DOF arm grasp with impedance and force regulation";

  // --- Physical parameters ---
  parameter Real tau_max = 120.0 "Maximum joint effort (N.m)";
  parameter Real mu = 0.78 "Friction coefficient";
  parameter Real e_rest = 0.03 "Restitution coefficient";
  parameter Real m_obj = 1.0 "Object mass (kg)";
  parameter Real I_joint = 0.5 "Joint inertia (kg.m^2)";

  // --- Contact parameters ---
  parameter Real K_contact = 2000.0 "Normal contact stiffness (N/m)";
  parameter Real D_contact = 50.0 "Normal contact damping (N.s/m)";
  parameter Real K_grip = 5000.0 "Grip tangential stiffness (N/m)";
  parameter Real D_grip = 50.0 "Grip tangential damping (N.s/m)";

  // --- Control parameters ---
  parameter Real K_imp = 500.0 "Impedance stiffness approach (N/m)";
  parameter Real D_imp = 100.0 "Impedance damping approach (N.s/m)";
  parameter Real K_imp_y = 2000.0 "Impedance stiffness lateral (N/m)";
  parameter Real D_imp_y = 200.0 "Impedance damping lateral (N.s/m)";
  parameter Real K_force = 20.0 "Force regulation gain";
  parameter Real D_force = 800.0 "Force regulation damping (N.s/m)";
  parameter Real F_grasp = 15.0 "Target normal grasp force (N)";

  // --- Scenario parameters ---
  parameter Real F_dist = 8.0 "Tangential disturbance (N)";
  parameter Real Ts = 0.005 "Control sample time (s) 200 Hz";
  parameter Real T_total = 14.0 "Total simulation duration (s)";
  parameter Real T_imp2force = 4.0 "Impedance to force regulation switch (s)";
  parameter Real T_dist_start = 4.666667 "Disturbance start middle third (s)";
  parameter Real T_dist_end = 9.333333 "Disturbance end middle third (s)";
  parameter Real x_des = 0.30 "Desired approach position (m)";
  parameter Real y_des = 0.0 "Desired lateral position (m)";
  parameter Real x_obj0 = 0.30 "Object position in approach direction (m)";

  // --- Joint states ---
  Real q1 "Joint 1 angle (rad)";
  Real q2 "Joint 2 angle (rad)";
  Real q3 "Joint 3 angle (rad)";
  Real q4 "Joint 4 angle (rad)";
  Real q5 "Joint 5 angle (rad)";
  Real q6 "Joint 6 angle (rad)";
  Real dq1 "Joint 1 velocity (rad/s)";
  Real dq2 "Joint 2 velocity (rad/s)";
  Real dq3 "Joint 3 velocity (rad/s)";
  Real dq4 "Joint 4 velocity (rad/s)";
  Real dq5 "Joint 5 velocity (rad/s)";
  Real dq6 "Joint 6 velocity (rad/s)";
  Real tau_cmd1 "Commanded torque joint 1 (N.m)";
  Real tau_cmd2 "Commanded torque joint 2 (N.m)";
  Real tau_cmd3 "Commanded torque joint 3 (N.m)";
  Real tau_cmd4 "Commanded torque joint 4 (N.m)";
  Real tau_cmd5 "Commanded torque joint 5 (N.m)";
  Real tau_cmd6 "Commanded torque joint 6 (N.m)";
  Real tau_sat1 "Saturated torque joint 1 (N.m)";
  Real tau_sat2 "Saturated torque joint 2 (N.m)";
  Real tau_sat3 "Saturated torque joint 3 (N.m)";
  Real tau_sat4 "Saturated torque joint 4 (N.m)";
  Real tau_sat5 "Saturated torque joint 5 (N.m)";
  Real tau_sat6 "Saturated torque joint 6 (N.m)";

  // --- End-effector kinematics ---
  Real x_ee "End-effector approach position (m)";
  Real y_ee "End-effector lateral position (m)";
  Real dx_ee "End-effector approach velocity (m/s)";
  Real dy_ee "End-effector lateral velocity (m/s)";

  // --- Jacobian entries (constant simplified) ---
  Real J11 "Jacobian row 1 col 1";
  Real J12 "Jacobian row 1 col 2";
  Real J13 "Jacobian row 1 col 3";
  Real J24 "Jacobian row 2 col 4";
  Real J25 "Jacobian row 2 col 5";
  Real J26 "Jacobian row 2 col 6";

  // --- Object state ---
  Real y_obj "Object lateral position (m)";
  Real dy_obj "Object lateral velocity (m/s)";

  // --- Contact and grip ---
  Real penetration "Contact penetration depth (m)";
  Real F_normal "Normal contact force (N)";
  Real F_grip_raw "Raw grip tangential force (N)";
  Real F_grip "Friction-limited grip force (N)";
  Real F_friction_limit "Coulomb friction limit (N)";

  // --- Control ---
  Real mode "0 impedance 1 force regulation";
  Real F_ctrl_x "Control force approach (N)";
  Real F_ctrl_y "Control force lateral (N)";
  Real F_disturbance "Disturbance force (N)";

  // --- Sensors ---
  Real F_sensor_n "Wrist sensor normal force (N)";
  Real F_sensor_t "Wrist sensor tangential force (N)";

  // --- Tracking ---
  Real track_err "Primary tracking error (m)";

  // --- Synchronized instrumented traces ---
  output Real q_trace1 "Joint 1 state trace";
  output Real q_trace2 "Joint 2 state trace";
  output Real q_trace3 "Joint 3 state trace";
  output Real q_trace4 "Joint 4 state trace";
  output Real q_trace5 "Joint 5 state trace";
  output Real q_trace6 "Joint 6 state trace";
  output Real dq_trace1 "Joint 1 velocity trace";
  output Real dq_trace2 "Joint 2 velocity trace";
  output Real dq_trace3 "Joint 3 velocity trace";
  output Real dq_trace4 "Joint 4 velocity trace";
  output Real dq_trace5 "Joint 5 velocity trace";
  output Real dq_trace6 "Joint 6 velocity trace";
  output Real tau_trace1 "Saturated torque 1 trace";
  output Real tau_trace2 "Saturated torque 2 trace";
  output Real tau_trace3 "Saturated torque 3 trace";
  output Real tau_trace4 "Saturated torque 4 trace";
  output Real tau_trace5 "Saturated torque 5 trace";
  output Real tau_trace6 "Saturated torque 6 trace";
  output Real F_n_trace "Normal force sensor trace";
  output Real F_t_trace "Tangential force sensor trace";
  output Real pose_y_trace "Object lateral pose trace";
  output Real err_trace "Tracking error trace";

initial equation
  q1 = 0.1;
  q2 = 0.0;
  q3 = 0.0;
  q4 = 0.0;
  q5 = 0.0;
  q6 = 0.0;
  dq1 = 0.0;
  dq2 = 0.0;
  dq3 = 0.0;
  dq4 = 0.0;
  dq5 = 0.0;
  dq6 = 0.0;
  y_obj = 0.0;
  dy_obj = 0.0;

equation
  // Simplified constant Jacobian
  J11 = 0.15;
  J12 = 0.08;
  J13 = 0.05;
  J24 = 0.12;
  J25 = 0.07;
  J26 = 0.04;

  // Forward kinematics
  x_ee = 0.40 + J11 * q1 + J12 * q2 + J13 * q3;
  y_ee = J24 * q4 + J25 * q5 + J26 * q6;
  dx_ee = J11 * dq1 + J12 * dq2 + J13 * dq3;
  dy_ee = J24 * dq4 + J25 * dq5 + J26 * dq6;

  // Control mode and disturbance scheduling
  mode = if time < T_imp2force then 0.0 else 1.0;
  F_disturbance = if time >= T_dist_start and time <= T_dist_end then F_dist else 0.0;

  // Normal contact: spring-damper clamped non-negative
  penetration = x_obj0 - x_ee;
  F_normal = max(0.0, K_contact * penetration + D_contact * (1.0 + e_rest) * (-dx_ee));

  // Tangential grip: spring-damper limited by Coulomb friction
  F_friction_limit = mu * F_normal;
  F_grip_raw = K_grip * (y_obj - y_ee) + D_grip * (dy_obj - dy_ee);
  F_grip = if F_grip_raw > F_friction_limit then F_friction_limit
           elseif F_grip_raw < -F_friction_limit then -F_friction_limit
           else F_grip_raw;

  // Object lateral dynamics
  m_obj * der(dy_obj) = F_disturbance - F_grip;
  der(y_obj) = dy_obj;

  // Wrist six-axis sensor (two dominant axes)
  F_sensor_n = F_normal;
  F_sensor_t = F_grip;

  // Approach control: impedance then force regulation
  F_ctrl_x = if mode < 0.5 then
      K_imp * (x_des - x_ee) - D_imp * dx_ee
    else
      K_force * (F_grasp - F_normal) - D_force * dx_ee;

  // Lateral control: position-holding impedance
  F_ctrl_y = K_imp_y * (y_des - y_ee) - D_imp_y * dy_ee;

  // Operational-space force to joint torques via Jacobian transpose
  tau_cmd1 = J11 * F_ctrl_x;
  tau_cmd2 = J12 * F_ctrl_x;
  tau_cmd3 = J13 * F_ctrl_x;
  tau_cmd4 = J24 * F_ctrl_y;
  tau_cmd5 = J25 * F_ctrl_y;
  tau_cmd6 = J26 * F_ctrl_y;

  // Saturated actuators
  tau_sat1 = if tau_cmd1 > tau_max then tau_max elseif tau_cmd1 < -tau_max then -tau_max else tau_cmd1;
  tau_sat2 = if tau_cmd2 > tau_max then tau_max elseif tau_cmd2 < -tau_max then -tau_max else tau_cmd2;
  tau_sat3 = if tau_cmd3 > tau_max then tau_max elseif tau_cmd3 < -tau_max then -tau_max else tau_cmd3;
  tau_sat4 = if tau_cmd4 > tau_max then tau_max elseif tau_cmd4 < -tau_max then -tau_max else tau_cmd4;
  tau_sat5 = if tau_cmd5 > tau_max then tau_max elseif tau_cmd5 < -tau_max then -tau_max else tau_cmd5;
  tau_sat6 = if tau_cmd6 > tau_max then tau_max elseif tau_cmd6 < -tau_max then -tau_max else tau_cmd6;

  // Joint dynamics
  I_joint * der(dq1) = tau_sat1 + J11 * F_normal;
  I_joint * der(dq2) = tau_sat2 + J12 * F_normal;
  I_joint * der(dq3) = tau_sat3 + J13 * F_normal;
  I_joint * der(dq4) = tau_sat4 + J24 * F_grip;
  I_joint * der(dq5) = tau_sat5 + J25 * F_grip;
  I_joint * der(dq6) = tau_sat6 + J26 * F_grip;
  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;
  der(q5) = dq5;
  der(q6) = dq6;

  // Tracking error with well-defined zero branch
  track_err = sqrt((x_ee - x_des) ^ 2 + (y_ee - y_des) ^ 2 + 1.0e-12);

  // Synchronized traces
  q_trace1 = q1;
  q_trace2 = q2;
  q_trace3 = q3;
  q_trace4 = q4;
  q_trace5 = q5;
  q_trace6 = q6;
  dq_trace1 = dq1;
  dq_trace2 = dq2;
  dq_trace3 = dq3;
  dq_trace4 = dq4;
  dq_trace5 = dq5;
  dq_trace6 = dq6;
  tau_trace1 = tau_sat1;
  tau_trace2 = tau_sat2;
  tau_trace3 = tau_sat3;
  tau_trace4 = tau_sat4;
  tau_trace5 = tau_sat5;
  tau_trace6 = tau_sat6;
  F_n_trace = F_sensor_n;
  F_t_trace = F_sensor_t;
  pose_y_trace = y_obj;
  err_trace = track_err;

end ContactArmGraspD;