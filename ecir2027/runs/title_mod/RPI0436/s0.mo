model ContactArmGraspD
  "Instrumented contact-rich manipulation: 6-DOF arm grasp with impedance/force-regulation control";

  // --- Physical parameters ---
  parameter Real tau_max    = 120.0  "Maximum joint effort (N.m)";
  parameter Real mu          = 0.78   "Friction coefficient (gripper-object and table)";
  parameter Real e_rest      = 0.03   "Restitution coefficient";
  parameter Real m_obj       = 1.0    "Object mass (kg)";
  parameter Real I_joint     = 0.5    "Joint inertia (kg.m^2)";

  // --- Contact parameters ---
  parameter Real K_contact   = 2000.0 "Normal contact stiffness (N/m)";
  parameter Real D_contact   = 50.0   "Normal contact damping (N.s/m)";
  parameter Real K_grip      = 5000.0 "Grip tangential stiffness (N/m)";
  parameter Real D_grip      = 50.0   "Grip tangential damping (N.s/m)";

  // --- Control parameters ---
  parameter Real K_imp       = 500.0  "Impedance stiffness – approach (N/m)";
  parameter Real D_imp       = 100.0  "Impedance damping – approach (N.s/m)";
  parameter Real K_imp_y     = 2000.0 "Impedance stiffness – lateral (N/m)";
  parameter Real D_imp_y     = 200.0  "Impedance damping – lateral (N.s/m)";
  parameter Real K_force     = 20.0   "Force regulation gain";
  parameter Real D_force     = 800.0  "Force regulation damping (N.s/m)";
  parameter Real F_grasp     = 15.0   "Target normal grasp force (N)";

  // --- Scenario parameters ---
  parameter Real F_dist      = 8.0   "Tangential disturbance (N)";
  parameter Real Ts           = 0.005 "Control sample time (s) – 200 Hz";
  parameter Real T_total      = 14.0  "Total simulation duration (s)";
  parameter Real T_imp2force  = 4.0   "Impedance -> force-regulation switch (s)";
  parameter Real T_dist_start = T_total / 3.0      "Disturbance start – middle third (s)";
  parameter Real T_dist_end   = 2.0 * T_total / 3.0 "Disturbance end – middle third (s)";
  parameter Real x_des        = 0.30  "Desired approach position (m)";
  parameter Real y_des        = 0.0   "Desired lateral position (m)";
  parameter Real x_obj0       = 0.30  "Object position in approach direction (m)";

  // --- Joint states ---
  Real q[6](start = {0.1, 0.0, 0.0, 0.0, 0.0, 0.0}) "Joint angles (rad)";
  Real dq[6](start = zeros(6))                      "Joint velocities (rad/s)";
  Real tau_cmd[6] "Commanded joint torques (N.m)";
  Real tau_sat[6] "Saturated joint torques (N.m)";

  // --- End-effector kinematics ---
  Real x_ee  "End-effector approach position (m)";
  Real y_ee  "End-effector lateral position (m)";
  Real dx_ee "End-effector approach velocity (m/s)";
  Real dy_ee "End-effector lateral velocity (m/s)";

  // --- Jacobian (simplified, constant for Z-Y-Y-X-Y-X arm) ---
  Real J[2, 6];

  // --- Object state (lateral dynamics; x held by grasp) ---
  Real y_obj(start = 0.0)  "Object lateral position (m)";
  Real dy_obj(start = 0.0) "Object lateral velocity (m/s)";

  // --- Contact and grip ---
  Real penetration       "Contact penetration depth (m)";
  Real F_normal          "Normal contact force (N)";
  Real F_grip_raw        "Raw grip tangential force (N)";
  Real F_grip            "Friction-limited grip force on arm (N)";
  Real F_friction_limit  "Coulomb friction limit (N)";

  // --- Control ---
  Real mode          "0 = impedance, 1 = force regulation";
  Real F_ctrl_x      "Control force – approach (N)";
  Real F_ctrl_y      "Control force – lateral (N)";
  Real F_disturbance "Disturbance force (N)";

  // --- Sensors ---
  Real F_sensor_n "Wrist sensor normal force (N)";
  Real F_sensor_t "Wrist sensor tangential force (N)";

  // --- Tracking ---
  Real track_err "Primary tracking error (m)";

  // --- Synchronized instrumented traces (FMI outputs) ---
  output Real q_trace[6]    "Joint state trace";
  output Real dq_trace[6]   "Joint velocity trace";
  output Real tau_trace[6]  "Saturated torque trace";
  output Real F_n_trace     "Normal force sensor trace";
  output Real F_t_trace     "Tangential force sensor trace";
  output Real pose_y_trace  "Object lateral pose trace";
  output Real err_trace     "Tracking error trace";

equation
  // Simplified constant Jacobian (approach: joints 1-3, lateral: joints 4-6)
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
  mode = if time < T_imp2force then 0.0 else 1.0;
  F_disturbance = if time >= T_dist_start and time <= T_dist_end then F_dist else 0.0;

  // Normal contact: spring-damper, clamped non-negative
  penetration = x_obj0 - x_ee;
  F_normal = max(0.0, K_contact * penetration
                      + D_contact * (1.0 + e_rest) * (-dx_ee));

  // Tangential grip: spring-damper limited by Coulomb friction mu * F_normal
  F_friction_limit = mu * F_normal;
  F_grip_raw = K_grip * (y_obj - y_ee) + D_grip * (dy_obj - dy_ee);
  F_grip = if F_grip_raw > F_friction_limit then F_friction_limit
           elseif F_grip_raw < -F_friction_limit then -F_friction_limit
           else F_grip_raw;

  // Object lateral dynamics (table constrains x; friction holds y)
  m_obj * der(dy_obj) = F_disturbance - F_grip;
  der(y_obj) = dy_obj;

  // Wrist six-axis sensor (two dominant axes modelled)
  F_sensor_n = F_normal;
  F_sensor_t = F_grip;

  // --- Control law ---
  // Approach: impedance -> force regulation
  F_ctrl_x = if mode < 0.5 then
      K_imp * (x_des - x_ee) - D_imp * dx_ee
    else
      K_force * (F_grasp - F_normal) - D_force * dx_ee;

  // Lateral: position-holding impedance in both modes
  F_ctrl_y = K_imp_y * (y_des - y_ee) - D_imp_y * dy_ee;

  // Operational-space force -> joint torques via Jacobian transpose
  for i in 1:6 loop
    tau_cmd[i] = J[1,i] * F_ctrl_x + J[2,i] * F_ctrl_y;
  end for;

  // Saturated actuators (±120 N.m)
  for i in 1:6 loop
    tau_sat[i] = if tau_cmd[i] > tau_max then tau_max
                 elseif tau_cmd[i] < -tau_max then -tau_max
                 else tau_cmd[i];
  end for;

  // Joint dynamics: I * ddq = tau_sat + J^T * F_ext_contact
  // Contact on arm: +F_normal (pushes arm away from object),
  //                 +F_grip   (grip friction drags arm tangentially)
  for i in 1:6 loop
    I_joint * der(dq[i]) = tau_sat[i] + J[1,i] * F_normal + J[2,i] * F_grip;
    der(q[i]) = dq[i];
  end for;

  // Tracking error with well-defined zero branch
  track_err = sqrt((x_ee - x_des)^2 + (y_ee - y_des)^2 + 1.0e-12);

  // Synchronized traces
  for i in 1:6 loop
    q_trace[i]   = q[i];
    dq_trace[i]  = dq[i];
    tau_trace[i] = tau_sat[i];
  end for;
  F_n_trace    = F_sensor_n;
  F_t_trace    = F_sensor_t;
  pose_y_trace = y_obj;
  err_trace    = track_err;

end ContactArmGraspD;