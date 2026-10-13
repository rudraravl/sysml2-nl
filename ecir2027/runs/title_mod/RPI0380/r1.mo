model ParallelGripPolishB
  "Contact-rich manipulation: parallel gripper polishing along curved surface"
  
  // === Physical parameters ===
  parameter Real m_palm = 6.0 "Palm mass [kg]";
  parameter Real m_finger = 0.5 "Each finger mass [kg]";
  parameter Real finger_travel = 0.05 "Prismatic joint travel [m]";
  parameter Real mu = 0.50 "Surface friction coefficient";
  parameter Real k_surface = 50000.0 "Surface normal stiffness [N/m]";
  parameter Real d_surface = 500.0 "Surface normal damping [N.s/m]";
  parameter Real k_pad = 5000.0 "Pad stiffness [N/m]";
  parameter Real d_pad = 50.0 "Pad damping [N.s/m]";
  parameter Real f_act_max = 36.9 "Max finger actuator force [N]";
  parameter Real f_normal_set = 20.0 "Normal force setpoint [N]";
  parameter Real path_length = 0.50 "Surface path length [m]";
  parameter Real T_mission = 10.0 "Mission duration [s]";
  parameter Real T_ctrl = 0.01 "Control period [s] (100 Hz)";
  parameter Real q_pad_contact = 0.0 "Pad contact onset position [m]";
  // Curvature profile of fixed workpiece is unknown; modeled as locally flat
  // compliant contact along the tangential path direction.
  
  // === Controller gains ===
  parameter Real kp_path = 2000.0 "Tangential P gain [N/m]";
  parameter Real kd_path = 200.0 "Tangential D gain [N.s/m]";
  parameter Real kp_force = 15.0 "Normal force regulation gain";
  parameter Real kp_finger = 500.0 "Finger closure P gain [N/m]";
  parameter Real kd_finger = 30.0 "Finger closure D gain [N.s/m]";
  parameter Real q_finger_ref = 0.025 "Finger reference position [m]";
  parameter Real v_ref = 0.05 "Reference tangential velocity [m/s]";
  
  // === Continuous states ===
  Real s(start=0.0) "Tangential position along path [m]";
  Real s_dot(start=0.0) "Tangential velocity [m/s]";
  Real n_pos(start=0.0004) "Normal penetration [m]";
  Real n_dot(start=0.0) "Normal velocity [m/s]";
  Real q1(start=0.001) "Left finger joint position [m]";
  Real q1_dot(start=0.0) "Left finger joint velocity [m/s]";
  Real q2(start=0.001) "Right finger joint position [m]";
  Real q2_dot(start=0.0) "Right finger joint velocity [m/s]";
  
  // === Discrete control variables (100 Hz zero-order hold) ===
  Real s_ref_d(start=0.0) "Discrete path reference [m]";
  Real s_meas_d(start=0.0) "Discrete tangential position sensor [m]";
  Real s_dot_meas_d(start=0.0) "Discrete tangential velocity sensor [m/s]";
  Real f_norm_meas_d(start=20.0) "Discrete normal force sensor [N]";
  Real q1_meas_d(start=0.001) "Discrete left encoder [m]";
  Real q2_meas_d(start=0.001) "Discrete right encoder [m]";
  Real q1_dot_meas_d(start=0.0) "Discrete left velocity [m/s]";
  Real q2_dot_meas_d(start=0.0) "Discrete right velocity [m/s]";
  
  // === Forces ===
  Real f_normal "Normal contact force [N]";
  Real f_friction "Tangential friction force [N]";
  Real f_tang_ctrl "Tangential wrist control force [N]";
  Real f_wrist_normal "Normal wrist control force [N]";
  Real f_dist "Surface disturbance force [N]";
  Real f_act1_raw "Left actuator raw command [N]";
  Real f_act2_raw "Right actuator raw command [N]";
  Real f_act1 "Left actuator bounded force [N]";
  Real f_act2 "Right actuator bounded force [N]";
  Real f_pad1 "Left pad force [N]";
  Real f_pad2 "Right pad force [N]";
  
  // === Sensors ===
  Real enc_q1 "Joint encoder left [m]";
  Real enc_q2 "Joint encoder right [m]";
  Real wrench_t "Wrist wrench tangential [N]";
  Real wrench_n "Wrist wrench normal [N]";
  Real tip_x "Tool-tip pose x [m]";
  Real tip_y "Tool-tip pose y [m]";
  
  // === Performance metrics ===
  Real path_error "Path tracking error [m]";
  Boolean contact_continuous "Continuous contact maintained";
  Boolean force_in_bounds "Normal force in [12,30] N";
  Boolean tracking_satisfied "Tracking < 0.024 m after 6.5 s";
  Boolean effort_bounded "Finger efforts within 36.9 N";
  Boolean joint_bounded "Finger joints within travel";
  
equation
  // === Discrete control loop at 100 Hz ===
  when sample(0, T_ctrl) then
    s_ref_d = path_length * min(time, T_mission) / T_mission;
    s_meas_d = s;
    s_dot_meas_d = s_dot;
    f_norm_meas_d = f_normal;
    q1_meas_d = q1;
    q2_meas_d = q2;
    q1_dot_meas_d = q1_dot;
    q2_dot_meas_d = q2_dot;
  end when;
  
  // === Disturbance: 4.9 N opposing motion during middle third ===
  f_dist = if (time >= T_mission / 3.0 and time <= 2.0 * T_mission / 3.0) then -4.9 else 0.0;
  
  // === Normal contact force (compliant) ===
  f_normal = if n_pos > 0.0 then k_surface * n_pos + d_surface * n_dot else 0.0;
  
  // === Friction (smooth Coulomb, well-defined zero-velocity branch) ===
  f_friction = if f_normal > 0.5 then -mu * f_normal * tanh(s_dot / 0.01) else 0.0;
  
  // === Tangential trajectory control using sampled sensor data ===
  f_tang_ctrl = kp_path * (s_ref_d - s_meas_d) + kd_path * (v_ref - s_dot_meas_d);
  
  // === Normal force regulation using sampled wrench sensor ===
  f_wrist_normal = f_normal_set + kp_force * (f_normal_set - f_norm_meas_d);
  
  // === Finger actuator commands (bounded to 36.9 N per finger) ===
  f_act1_raw = kp_finger * (q_finger_ref - q1_meas_d) - kd_finger * q1_dot_meas_d;
  f_act2_raw = kp_finger * (q_finger_ref - q2_meas_d) - kd_finger * q2_dot_meas_d;
  f_act1 = max(-f_act_max, min(f_act_max, f_act1_raw));
  f_act2 = max(-f_act_max, min(f_act_max, f_act2_raw));
  
  // === Pad contact forces (compliant pads) ===
  f_pad1 = if q1 > q_pad_contact then k_pad * (q1 - q_pad_contact) + d_pad * q1_dot else 0.0;
  f_pad2 = if q2 > q_pad_contact then k_pad * (q2 - q_pad_contact) + d_pad * q2_dot else 0.0;
  
  // === Palm tangential dynamics ===
  der(s) = s_dot;
  m_palm * der(s_dot) = f_tang_ctrl + f_friction + f_dist;
  
  // === Palm normal dynamics ===
  der(n_pos) = n_dot;
  m_palm * der(n_dot) = f_wrist_normal - f_normal;
  
  // === Left finger dynamics ===
  der(q1) = q1_dot;
  m_finger * der(q1_dot) = f_act1 - f_pad1;
  
  // === Right finger dynamics ===
  der(q2) = q2_dot;
  m_finger * der(q2_dot) = f_act2 - f_pad2;
  
  // === Sensor outputs ===
  enc_q1 = q1;
  enc_q2 = q2;
  wrench_t = f_tang_ctrl + f_friction + f_dist;
  wrench_n = f_normal;
  tip_x = s;
  tip_y = -n_pos;
  
  // === Performance metrics ===
  path_error = abs(s_ref_d - s);
  contact_continuous = f_normal > 0.0;
  force_in_bounds = (f_normal >= 12.0) and (f_normal <= 30.0);
  tracking_satisfied = if time > 6.5 then path_error < 0.024 else true;
  effort_bounded = (abs(f_act1) <= f_act_max) and (abs(f_act2) <= f_act_max);
  joint_bounded = (q1 >= 0.0) and (q1 <= finger_travel) and
                  (q2 >= 0.0) and (q2 <= finger_travel);
  
end ParallelGripPolishB;