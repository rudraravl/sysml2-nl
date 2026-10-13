model PlanarPusherGraspE
  import Modelica;
  import Modelica.Units.SI;
  import Modelica.Constants.g_n;

  // ===== Geometry & inertia =====
  parameter SI.Length L1=0.46 "link 1 length (m)";
  parameter SI.Length L2=0.35 "link 2 length (m)";
  parameter SI.Length r_tool=0.012 "rounded contact tool radius (m)";
  parameter SI.Length base_x=0.30 "base x position (m)";
  parameter SI.Length base_y=0.0 "base y position (m)";
  parameter SI.Length wall_x=0.0 "fixed wall x position (m)";
  parameter SI.Length obj_w=0.08 "object width along x (m)";
  parameter SI.Mass m_obj=0.40 "object mass (kg)";
  parameter SI.Mass m1=2.0 "link 1 mass (kg)";
  parameter SI.Mass m2=1.2 "link 2 mass (kg)";
  parameter SI.Mass m_tool=0.20 "tool mass (kg)";
  parameter Real I1=0.10 "link 1 inertia about joint (kg.m2)";
  parameter Real I2=0.025 "link 2 inertia about joint (kg.m2)";
  parameter Real b1=0.5 "joint 1 damping (N.m.s/rad)";
  parameter Real b2=0.3 "joint 2 damping (N.m.s/rad)";

  // ===== Contact =====
  parameter Real mu=0.78 "friction coefficient";
  parameter Real e_rest=0.03 "coefficient of restitution";
  parameter Real k_c=2.0e4 "contact normal stiffness (N/m)";
  parameter Real c_c=200.0 "contact normal damping (N.s/m)";
  parameter Real v_eps=0.005 "friction smoothing velocity (m/s)";

  // ===== Actuator =====
  parameter SI.Torque tau_max=55.0 "per-joint command magnitude bound (N.m)";

  // ===== Controller =====
  parameter SI.Frequency f_ctrl=250 "controller rate (Hz)";
  parameter SI.Time Ts=1.0/f_ctrl "controller sample period (s)";
  parameter Real Kp_imp=1500.0 "impedance stiffness (N/m)";
  parameter Real Kd_imp=100.0 "impedance damping (N.s/m)";
  parameter Real Ki_f=1.0e-4 "force-regulation integral gain (m/(N.s))";
  parameter SI.Force F_desired=18.0 "desired grasp normal force (N)";
  parameter SI.Time t_approach=3.0 "approach duration (s)";
  parameter SI.Time t_dist_start=5.33 "disturbance start (s)";
  parameter SI.Time t_dist_end=10.67 "disturbance end (s)";
  parameter SI.Force F_dist=9.6 "tangential disturbance magnitude (N)";
  parameter SI.Time T_end=16.0 "simulation duration (s)";

  // ===== Initial conditions =====
  parameter SI.Angle q1_init=2.5 "initial joint 1 angle (rad)";
  parameter SI.Angle q2_init=-3.3 "initial joint 2 angle (rad)";
  parameter SI.Length obj_initial_x=0.055 "object initial x (m)";
  parameter SI.Length ee_x0 = base_x + L1*Modelica.Math.cos(q1_init) + L2*Modelica.Math.cos(q1_init+q2_init);
  parameter SI.Length ee_y0 = base_y + L1*Modelica.Math.sin(q1_init) + L2*Modelica.Math.sin(q1_init+q2_init);

  // ===== Acceptance bounds =====
  parameter SI.Length track_err_bound=0.013 "tracking error bound after 10.4 s (m)";
  parameter SI.Length obj_disp_bound=0.02 "object displacement bound (m)";
  parameter SI.Length travel_bound=0.15 "end-effector travel bound (m)";

  // ===== Joint states =====
  SI.Angle q1(start=q1_init) "joint 1 angle (rad)";
  SI.Angle q2(start=q2_init) "joint 2 angle (rad)";
  SI.AngularVelocity qd1(start=0) "joint 1 velocity (rad/s)";
  SI.AngularVelocity qd2(start=0) "joint 2 velocity (rad/s)";
  SI.Torque tau1 "joint 1 applied torque (N.m)";
  SI.Torque tau2 "joint 2 applied torque (N.m)";

  // ===== Kinematics =====
  SI.Length ee_x "end-effector x (m)";
  SI.Length ee_y "end-effector y (m)";
  SI.Velocity ee_xd "end-effector x velocity (m/s)";
  SI.Velocity ee_yd "end-effector y velocity (m/s)";
  Real J1x, J2x, J1y, J2y "Jacobian components";

  // ===== Object states =====
  SI.Length x_obj(start=obj_initial_x) "object center x (m)";
  SI.Length y_obj(start=0.0) "object center y (m)";
  SI.Velocity vx_obj(start=0) "object x velocity (m/s)";
  SI.Velocity vy_obj(start=0) "object y velocity (m/s)";

  // ===== Contact =====
  Real pen_tool "tool-object penetration (m)";
  Real pen_wall "wall-object penetration (m)";
  SI.Force N_tool "tool-object normal force (N)";
  SI.Force N_wall "wall-object normal force (N)";
  SI.Force N_table "table normal force (N)";
  SI.Force F_fr_tool_y "tool-object friction y (N)";
  SI.Force F_fr_wall_y "wall-object friction y (N)";
  SI.Force F_fr_table_x "table friction x (N)";
  SI.Force F_fr_table_y "table friction y (N)";

  // ===== Disturbance =====
  SI.Force F_disturbance "applied tangential disturbance (N)";

  // ===== Controller (discrete, 250 Hz) =====
  discrete SI.Length x_tgt_d(start=ee_x0) "x target (m)";
  discrete SI.Length y_tgt_d(start=ee_y0) "y target (m)";
  discrete Real f_int(start=0.0) "force integral term (m)";
  discrete SI.Torque tau1_cmd(start=0) "joint 1 commanded torque (N.m)";
  discrete SI.Torque tau2_cmd(start=0) "joint 2 commanded torque (N.m)";
  discrete Real F_err_d(start=0.0) "force error (N)";
  discrete Real F_cmd_x_d(start=0.0) "commanded cartesian force x (N)";
  discrete Real F_cmd_y_d(start=0.0) "commanded cartesian force y (N)";
  discrete Real s_ramp(start=0.0) "ramp fraction";
  discrete Real s_smooth(start=0.0) "smoothstep";

  // ===== Sensor / acceptance =====
  SI.Length x_tgt "target x (m, held)";
  SI.Length y_tgt "target y (m, held)";
  SI.Length tracking_error "ee tracking error (m)";
  SI.Length obj_displacement "object displacement (m)";
  SI.Length ee_travel "end-effector travel from start (m)";
  Boolean grasp_stable "grasp contact stable";
  Boolean effort_ok "effort within bounds";
  Boolean travel_ok "travel within bound";

equation
  // ===== Forward kinematics (planar x-y, revolute Z joints) =====
  ee_x = base_x + L1*Modelica.Math.cos(q1) + L2*Modelica.Math.cos(q1+q2);
  ee_y = base_y + L1*Modelica.Math.sin(q1) + L2*Modelica.Math.sin(q1+q2);
  ee_xd = -L1*Modelica.Math.sin(q1)*qd1 - L2*Modelica.Math.sin(q1+q2)*(qd1+qd2);
  ee_yd = L1*Modelica.Math.cos(q1)*qd1 + L2*Modelica.Math.cos(q1+q2)*(qd1+qd2);
  J1x = -L1*Modelica.Math.sin(q1) - L2*Modelica.Math.sin(q1+q2);
  J2x = -L2*Modelica.Math.sin(q1+q2);
  J1y = L1*Modelica.Math.cos(q1) + L2*Modelica.Math.cos(q1+q2);
  J2y = L2*Modelica.Math.cos(q1+q2);

  // ===== Joint dynamics (horizontal plane, no gravity torque about Z) =====
  der(q1) = qd1;
  der(q2) = qd2;
  I1*der(qd1) = tau1 - b1*qd1 + (J1x*N_tool - J1y*F_fr_tool_y);
  I2*der(qd2) = tau2 - b2*qd2 + (J2x*N_tool - J2y*F_fr_tool_y);

  // ===== Object dynamics (on rigid table, z fixed by support) =====
  der(x_obj) = vx_obj;
  der(y_obj) = vy_obj;
  m_obj*der(vx_obj) = -N_tool + N_wall + F_fr_table_x;
  m_obj*der(vy_obj) = F_fr_tool_y + F_fr_wall_y + F_fr_table_y + F_disturbance;

  // ===== Contact (collision enabled, friction 0.78, restitution 0.03) =====
  pen_tool = (x_obj + obj_w/2 + r_tool) - ee_x;
  pen_wall = wall_x - (x_obj - obj_w/2);
  N_tool = if pen_tool > 0.0 then k_c*pen_tool + c_c*(vx_obj - ee_xd) else 0.0;
  N_wall = if pen_wall > 0.0 then k_c*pen_wall + c_c*(-vx_obj) else 0.0;
  N_table = m_obj*g_n "table supports object weight (object remains on table)";
  F_fr_tool_y = -mu*N_tool*Modelica.Math.tanh((vy_obj - ee_yd)/v_eps);
  F_fr_wall_y = -mu*N_wall*Modelica.Math.tanh(vy_obj/v_eps);
  F_fr_table_x = -mu*N_table*Modelica.Math.tanh(vx_obj/v_eps);
  F_fr_table_y = -mu*N_table*Modelica.Math.tanh(vy_obj/v_eps);

  // ===== Disturbance: 9.6 N tangential load over middle third =====
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Held targets and commands (zero-order hold at 250 Hz) =====
  x_tgt = x_tgt_d;
  y_tgt = y_tgt_d;
  tau1 = tau1_cmd;
  tau2 = tau2_cmd;

  // ===== Sensors / acceptance =====
  tracking_error = Modelica.Math.sqrt((ee_x - x_tgt)*(ee_x - x_tgt) + (ee_y - y_tgt)*(ee_y - y_tgt) + 1e-12);
  obj_displacement = Modelica.Math.sqrt((x_obj - obj_initial_x)*(x_obj - obj_initial_x) + (y_obj - 0.0)*(y_obj - 0.0) + 1e-12);
  ee_travel = Modelica.Math.sqrt((ee_x - ee_x0)*(ee_x - ee_x0) + (ee_y - ee_y0)*(ee_y - ee_y0) + 1e-12);
  grasp_stable = (time > t_approach + 0.5) and (N_tool > 0.5) and (N_wall > 0.5);
  effort_ok = (abs(tau1) <= tau_max + 1e-6) and (abs(tau2) <= tau_max + 1e-6);
  travel_ok = (ee_travel <= travel_bound);

  // ===== Fail-closed assertions =====
  assert(ee_x == ee_x, "NaN detected in ee_x");
  assert(ee_y == ee_y, "NaN detected in ee_y");
  assert(q1 == q1, "NaN detected in q1");
  assert(q2 == q2, "NaN detected in q2");
  assert(x_obj == x_obj, "NaN detected in x_obj");
  assert(y_obj == y_obj, "NaN detected in y_obj");
  assert(tau1 == tau1, "NaN detected in tau1");
  assert(tau2 == tau2, "NaN detected in tau2");
  assert(N_tool == N_tool, "NaN detected in N_tool");
  assert(N_wall == N_wall, "NaN detected in N_wall");
  assert(effort_ok, "Effort bound (55 N.m per joint) violated");
  assert(travel_ok, "End-effector travel bound violated");
  assert(obj_displacement <= obj_disp_bound, "Object displacement bound violated");
  assert(time < 10.4 or tracking_error <= track_err_bound, "Primary tracking error bound violated after 10.4 s");
  assert(time < t_approach + 0.8 or (N_tool > 0.5 and N_wall > 0.5), "Grasp contact lost");
  assert(N_tool >= 0.0, "Tool normal force negative");
  assert(N_wall >= 0.0, "Wall normal force negative");

algorithm
  when sample(0, Ts) then
    F_err_d := F_desired - N_tool;
    s_ramp := min(max(time/t_approach, 0.0), 1.0);
    s_smooth := 3.0*s_ramp*s_ramp - 2.0*s_ramp*s_ramp*s_ramp;
    if time < t_approach then
      // Impedance motion phase: smooth approach to pre-grasp pose
      x_tgt_d := ee_x0 + (obj_initial_x + obj_w/2 + r_tool + 0.005 - ee_x0)*s_smooth;
      y_tgt_d := ee_y0 + (0.0 - ee_y0)*s_smooth;
      f_int := 0.0;
    else
      // Force regulation phase
      if N_tool > 0.5 then
        f_int := pre(f_int) + Ki_f*F_err_d*Ts;
        f_int := max(min(f_int, 0.005), -0.005);
        x_tgt_d := (x_obj + obj_w/2 + r_tool - F_desired/k_c) - f_int;
      else
        f_int := 0.0;
        x_tgt_d := x_obj + obj_w/2 + r_tool - 0.0005;
      end if;
      y_tgt_d := 0.0;
    end if;
    // Task-space impedance law mapped to joint torques via Jacobian transpose
    F_cmd_x_d := Kp_imp*(x_tgt_d - ee_x) + Kd_imp*(-ee_xd);
    F_cmd_y_d := Kp_imp*(y_tgt_d - ee_y) + Kd_imp*(-ee_yd);
    tau1_cmd := J1x*F_cmd_x_d + J1y*F_cmd_y_d;
    tau2_cmd := J2x*F_cmd_x_d + J2y*F_cmd_y_d;
    // Per-joint command saturation at 55 N.m
    if tau1_cmd > tau_max then
      tau1_cmd := tau_max;
    elseif tau1_cmd < -tau_max then
      tau1_cmd := -tau_max;
    end if;
    if tau2_cmd > tau_max then
      tau2_cmd := tau_max;
    elseif tau2_cmd < -tau_max then
      tau2_cmd := -tau_max;
    end if;
  end when;

  annotation (
    Documentation(info="Planar 2R pusher/grasp scenario (revolute Z joints, 0.46 m and 0.35 m capsule links, rounded contact tool). Impedance motion then force regulation with a 9.6 N tangential disturbance over the middle third. 250 Hz digital control, 16 s run, fail-closed acceptance for travel, effort, contact stability, object displacement, tracking error and finite values."),
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.004));
end PlanarPusherGraspE;