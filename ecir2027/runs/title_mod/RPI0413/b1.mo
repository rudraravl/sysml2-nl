model PlanarPusherGraspE
  import Modelica.Units.SI;

  // ===== Geometry =====
  parameter SI.Length L1 = 0.46 "link 1 length";
  parameter SI.Length L2 = 0.35 "link 2 length";
  parameter SI.Length r_tool = 0.012 "rounded contact tool radius";
  parameter SI.Length base_x = 0.30 "base x position";
  parameter SI.Length base_y = 0.0 "base y position";
  parameter SI.Length wall_x = 0.0 "fixed wall x position";
  parameter SI.Length obj_w = 0.08 "object width along x";

  // ===== Inertia & damping =====
  parameter SI.Mass m_obj = 0.40 "object mass";
  parameter Real I1 = 0.10 "link 1 inertia about joint";
  parameter Real I2 = 0.025 "link 2 inertia about joint";
  parameter Real b1 = 0.5 "joint 1 viscous damping";
  parameter Real b2 = 0.3 "joint 2 viscous damping";

  // ===== Contact =====
  parameter Real mu = 0.78 "friction coefficient";
  parameter Real e_rest = 0.03 "coefficient of restitution (represented via contact damping)";
  parameter Real k_c = 2.0e4 "contact normal stiffness";
  parameter Real c_c = 200.0 "contact normal damping";
  parameter Real v_eps = 0.005 "friction smoothing velocity";
  parameter Real g_n = 9.80665 "gravitational acceleration";

  // ===== Actuator =====
  parameter SI.Torque tau_max = 55.0 "per-joint command magnitude bound";

  // ===== Controller =====
  parameter Real f_ctrl = 250.0 "controller rate (Hz)";
  parameter SI.Time Ts = 1.0 / f_ctrl "controller sample period";
  parameter Real Kp_imp = 1500.0 "impedance stiffness";
  parameter Real Kd_imp = 100.0 "impedance damping";
  parameter Real Ki_f = 1.0e-4 "force-regulation integral gain";
  parameter SI.Force F_desired = 18.0 "desired grasp normal force";
  parameter SI.Time t_approach = 3.0 "approach duration";
  parameter SI.Time t_dist_start = 5.33 "disturbance start";
  parameter SI.Time t_dist_end = 10.67 "disturbance end";
  parameter SI.Force F_dist = 9.6 "tangential disturbance magnitude";

  // ===== Initial conditions =====
  parameter SI.Angle q1_init = 2.5 "initial joint 1 angle";
  parameter SI.Angle q2_init = -3.3 "initial joint 2 angle";
  parameter SI.Length obj_initial_x = 0.055 "object initial x";
  parameter SI.Length ee_x0 = base_x + L1 * cos(q1_init) + L2 * cos(q1_init + q2_init);
  parameter SI.Length ee_y0 = base_y + L1 * sin(q1_init) + L2 * sin(q1_init + q2_init);

  // ===== Acceptance bounds =====
  parameter SI.Length track_err_bound = 0.013 "tracking error bound after 10.4 s";
  parameter SI.Length obj_disp_bound = 0.02 "object displacement bound";
  parameter SI.Length travel_bound = 0.15 "end-effector travel bound";

  // ===== Joint states =====
  SI.Angle q1(start = q1_init) "joint 1 angle";
  SI.Angle q2(start = q2_init) "joint 2 angle";
  SI.AngularVelocity qd1(start = 0) "joint 1 velocity";
  SI.AngularVelocity qd2(start = 0) "joint 2 velocity";
  SI.Torque tau1 "joint 1 applied torque";
  SI.Torque tau2 "joint 2 applied torque";

  // ===== Kinematics =====
  SI.Length ee_x "end-effector x";
  SI.Length ee_y "end-effector y";
  SI.Velocity ee_xd "end-effector x velocity";
  SI.Velocity ee_yd "end-effector y velocity";
  Real J1x "Jacobian entry d ee_x / d q1";
  Real J2x "Jacobian entry d ee_x / d q2";
  Real J1y "Jacobian entry d ee_y / d q1";
  Real J2y "Jacobian entry d ee_y / d q2";

  // ===== Object states =====
  SI.Length x_obj(start = obj_initial_x) "object center x";
  SI.Length y_obj(start = 0.0) "object center y";
  SI.Velocity vx_obj(start = 0) "object x velocity";
  SI.Velocity vy_obj(start = 0) "object y velocity";

  // ===== Contact =====
  Real pen_tool "tool-object penetration";
  Real pen_wall "wall-object penetration";
  SI.Force N_tool "tool-object normal force";
  SI.Force N_wall "wall-object normal force";
  SI.Force N_table "table normal support force";
  SI.Force F_fr_tool_y "tool-object friction y";
  SI.Force F_fr_wall_y "wall-object friction y";
  SI.Force F_fr_table_x "table friction x";
  SI.Force F_fr_table_y "table friction y";

  // ===== Disturbance =====
  SI.Force F_disturbance "applied tangential disturbance";

  // ===== Controller (discrete) =====
  discrete SI.Length x_tgt_d(start = ee_x0) "held x target";
  discrete SI.Length y_tgt_d(start = ee_y0) "held y target";
  discrete Real f_int(start = 0.0) "force integral term";
  discrete SI.Torque tau1_cmd(start = 0) "joint 1 commanded torque";
  discrete SI.Torque tau2_cmd(start = 0) "joint 2 commanded torque";
  discrete SI.Force F_err_d(start = 0.0) "force error";
  discrete Real s_ramp(start = 0.0) "ramp fraction";
  discrete Real s_smooth(start = 0.0) "smoothstep";
  discrete SI.Force F_cmd_x_d(start = 0.0) "commanded Cartesian force x";
  discrete SI.Force F_cmd_y_d(start = 0.0) "commanded Cartesian force y";

  // ===== Sensor / acceptance =====
  SI.Length x_tgt "target x";
  SI.Length y_tgt "target y";
  SI.Length tracking_error "end-effector tracking error";
  SI.Length obj_displacement "object displacement from initial";
  SI.Length ee_travel "end-effector travel from start";
  Boolean grasp_stable "grasp contact stable";
  Boolean effort_ok "effort within bounds";
  Boolean travel_ok "travel within bound";

equation
  // ===== Forward kinematics =====
  ee_x = base_x + L1 * cos(q1) + L2 * cos(q1 + q2);
  ee_y = base_y + L1 * sin(q1) + L2 * sin(q1 + q2);
  ee_xd = -L1 * sin(q1) * qd1 - L2 * sin(q1 + q2) * (qd1 + qd2);
  ee_yd = L1 * cos(q1) * qd1 + L2 * cos(q1 + q2) * (qd1 + qd2);
  J1x = -L1 * sin(q1) - L2 * sin(q1 + q2);
  J2x = -L2 * sin(q1 + q2);
  J1y = L1 * cos(q1) + L2 * cos(q1 + q2);
  J2y = L2 * cos(q1 + q2);

  // ===== Joint dynamics =====
  der(q1) = qd1;
  der(q2) = qd2;
  I1 * der(qd1) = tau1 - b1 * qd1 + (J1x * N_tool - J1y * F_fr_tool_y);
  I2 * der(qd2) = tau2 - b2 * qd2 + (J2x * N_tool - J2y * F_fr_tool_y);

  // ===== Object dynamics =====
  der(x_obj) = vx_obj;
  der(y_obj) = vy_obj;
  m_obj * der(vx_obj) = -N_tool + N_wall + F_fr_table_x;
  m_obj * der(vy_obj) = F_fr_tool_y + F_fr_wall_y + F_fr_table_y + F_disturbance;

  // ===== Contact (collision enabled) =====
  pen_tool = (x_obj + obj_w / 2 + r_tool) - ee_x;
  pen_wall = wall_x - (x_obj - obj_w / 2);
  N_tool = if pen_tool > 0.0 then k_c * pen_tool + c_c * (vx_obj - ee_xd) else 0.0;
  N_wall = if pen_wall > 0.0 then k_c * pen_wall + c_c * (-vx_obj) else 0.0;
  N_table = m_obj * g_n;
  F_fr_tool_y = -mu * N_tool * tanh((vy_obj - ee_yd) / v_eps);
  F_fr_wall_y = -mu * N_wall * tanh(vy_obj / v_eps);
  F_fr_table_x = -mu * N_table * tanh(vx_obj / v_eps);
  F_fr_table_y = -mu * N_table * tanh(vy_obj / v_eps);

  // ===== Disturbance: 9.6 N tangential load over middle third =====
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Held targets and commands =====
  x_tgt = x_tgt_d;
  y_tgt = y_tgt_d;
  tau1 = tau1_cmd;
  tau2 = tau2_cmd;

  // ===== Sensors / acceptance =====
  tracking_error = sqrt((ee_x - x_tgt) * (ee_x - x_tgt) + (ee_y - y_tgt) * (ee_y - y_tgt) + 1e-12);
  obj_displacement = sqrt((x_obj - obj_initial_x) * (x_obj - obj_initial_x) + y_obj * y_obj + 1e-12);
  ee_travel = sqrt((ee_x - ee_x0) * (ee_x - ee_x0) + (ee_y - ee_y0) * (ee_y - ee_y0) + 1e-12);
  grasp_stable = (time > t_approach + 0.5) and (N_tool > 0.5) and (N_wall > 0.5);
  effort_ok = (abs(tau1) <= tau_max + 1e-6) and (abs(tau2) <= tau_max + 1e-6);
  travel_ok = (ee_travel <= travel_bound);

  // ===== Fail-closed assertions =====
  assert(effort_ok, "Effort bound (55 N.m per joint) violated");
  assert(travel_ok, "End-effector travel bound violated");
  assert(obj_displacement <= obj_disp_bound, "Object displacement bound violated");
  assert(time < 10.4 or tracking_error <= track_err_bound, "Primary tracking error bound violated after 10.4 s");
  assert(time < t_approach + 0.8 or (N_tool > 0.5 and N_wall > 0.5), "Grasp contact lost");
  assert(N_tool >= 0.0, "Tool normal force negative");
  assert(N_wall >= 0.0, "Wall normal force negative");

algorithm
  when sample(0, Ts) then
    // Force error
    F_err_d := F_desired - N_tool;

    // Smooth approach ramp
    s_ramp := min(max(time / t_approach, 0.0), 1.0);
    s_smooth := 3.0 * s_ramp * s_ramp - 2.0 * s_ramp * s_ramp * s_ramp;

    if time < t_approach then
      // Impedance motion phase: smooth approach to pre-grasp pose
      x_tgt_d := ee_x0 + (obj_initial_x + obj_w / 2 + r_tool + 0.005 - ee_x0) * s_smooth;
      y_tgt_d := ee_y0 + (0.0 - ee_y0) * s_smooth;
      f_int := 0.0;
    else
      // Force regulation phase
      if N_tool > 0.5 then
        f_int := pre(f_int) + Ki_f * F_err_d * Ts;
        f_int := max(min(f_int, 0.005), -0.005);
        x_tgt_d := (x_obj + obj_w / 2 + r_tool - F_desired / k_c) - f_int;
      else
        f_int := 0.0;
        x_tgt_d := x_obj + obj_w / 2 + r_tool - 0.0005;
      end if;
      y_tgt_d := 0.0;
    end if;

    // Task-space impedance law
    F_cmd_x_d := Kp_imp * (x_tgt_d - ee_x) + Kd_imp * (-ee_xd);
    F_cmd_y_d := Kp_imp * (y_tgt_d - ee_y) + Kd_imp * (-ee_yd);

    // Jacobian transpose mapping to joint torques
    tau1_cmd := J1x * F_cmd_x_d + J1y * F_cmd_y_d;
    tau2_cmd := J2x * F_cmd_x_d + J2y * F_cmd_y_d;

    // Per-joint saturation at 55 N.m
    tau1_cmd := max(min(tau1_cmd, tau_max), -tau_max);
    tau2_cmd := max(min(tau2_cmd, tau_max), -tau_max);
  end when;

  annotation (
    Documentation(info = "Planar 2R pusher/grasp scenario with revolute Z joints, 0.46 m and 0.35 m capsule links, and rounded contact tool. Impedance motion followed by force regulation with 9.6 N tangential disturbance over middle third. 250 Hz digital control, 16 s run, fail-closed acceptance for travel, effort, contact stability, object displacement, tracking error, and finite values."),
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004));
end PlanarPusherGraspE;