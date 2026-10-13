model CartesianToolGraspE
  // ------------------------------------------------------------------
  // Contact-rich Cartesian tool grasp scenario.
  // Plant: 3 orthogonal prismatic axes moving a 2.5 kg tool carriage.
  // Grasp: impedance motion + force regulation pressing the object
  //        onto a rigid table; friction (mu=0.78) resists a 9.6 N
  //        tangential disturbance applied over the middle third of 16 s.
  // Control loop: 250 Hz (Ts = 0.004 s).
  // Acceptance: fail-closed flags aggregated in all_ok.
  // ------------------------------------------------------------------

  // ---- Parameters (explicit SI) ----
  parameter Modelica.Units.SI.Mass m_carriage = 2.5 "tool carriage mass";
  parameter Modelica.Units.SI.Mass m_obj = 0.5
    "object mass (nominal; requirement does not specify)";
  parameter Modelica.Units.SI.Length x_lim = 0.10 "X travel (+/-)";
  parameter Modelica.Units.SI.Length y_lim = 0.10 "Y travel (+/-)";
  parameter Modelica.Units.SI.Length z_lim = 0.30 "Z travel (+/-)";
  parameter Modelica.Units.SI.Force F_max = 385.0 "per-axis command bound";
  parameter Real mu = 0.78 "friction coefficient (table and gripper-object)";
  parameter Real e_rest = 0.03 "coefficient of restitution (reflected in contact damping)";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_imp = 8000.0
    "impedance stiffness";
  parameter Modelica.Units.SI.TranslationalDampingConstant d_imp = 120.0
    "impedance damping";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_contact = 1.0e6
    "normal contact stiffness (gripper-object and object-table)";
  parameter Modelica.Units.SI.TranslationalDampingConstant d_contact = 1000.0
    "normal contact damping (near-plastic, e=0.03)";
  parameter Modelica.Units.SI.Force F_z_reg_hold = 10.0
    "regulated downward grasp force (nominal; requirement does not specify)";
  parameter Modelica.Units.SI.Force F_dist = 9.6 "tangential disturbance load";
  parameter Modelica.Units.SI.Time Ts = 0.004 "control sample period (250 Hz)";
  parameter Modelica.Units.SI.Time t_end = 16.0 "simulation duration";
  parameter Modelica.Units.SI.Length z_table = 0.0 "table surface height";
  parameter Modelica.Units.SI.Length z_obj_h = 0.04 "object half-height";
  parameter Modelica.Units.SI.Length z_approach = 0.08 "object top height";
  parameter Modelica.Units.SI.Time t_grasp = 3.0 "grasp engage time";
  parameter Modelica.Units.SI.Length err_bound = 0.013
    "primary tracking error bound after t_check";
  parameter Modelica.Units.SI.Time t_check = 10.4;
  parameter Modelica.Units.SI.Time t_d_start = 16.0/3.0
    "disturbance start (middle third)";
  parameter Modelica.Units.SI.Time t_d_end = 32.0/3.0
    "disturbance end (middle third)";
  parameter Modelica.Units.SI.Length max_obj_disp = 0.005
    "bounded object displacement threshold";
  parameter Real eps_friction = 1.0e-5
    "friction regularization velocity (zero-error branch)";
  parameter Modelica.Units.SI.Acceleration g_n = 9.81;

  // ---- Continuous states ----
  Modelica.Units.SI.Length x_g(start=0.0) "carriage X";
  Modelica.Units.SI.Length y_g(start=0.0) "carriage Y";
  Modelica.Units.SI.Length z_g(start=0.30) "carriage Z";
  Modelica.Units.SI.Velocity vx_g(start=0.0);
  Modelica.Units.SI.Velocity vy_g(start=0.0);
  Modelica.Units.SI.Velocity vz_g(start=0.0);
  Modelica.Units.SI.Length x_obj(start=0.0) "object X";
  Modelica.Units.SI.Length y_obj(start=0.0) "object Y";
  Modelica.Units.SI.Length z_obj(start=z_obj_h) "object Z";
  Modelica.Units.SI.Velocity vx_obj(start=0.0);
  Modelica.Units.SI.Velocity vy_obj(start=0.0);
  Modelica.Units.SI.Velocity vz_obj(start=0.0);

  // ---- Discrete controller commands ----
  discrete Modelica.Units.SI.Length x_cmd(start=0.0);
  discrete Modelica.Units.SI.Length y_cmd(start=0.0);
  discrete Modelica.Units.SI.Length z_cmd(start=0.30);
  discrete Modelica.Units.SI.Force F_z_reg(start=0.0)
    "regulated Z force (downward)";

  // ---- Actuator commands / forces ----
  Modelica.Units.SI.Force Fx_raw, Fy_raw, Fz_raw;
  Modelica.Units.SI.Force Fx_act, Fy_act, Fz_act;

  // ---- Contact / grasp forces ----
  Modelica.Units.SI.Force F_normal_grip "gripper-object normal (>=0)";
  Modelica.Units.SI.Force F_table_normal "table-object normal (>=0)";
  Modelica.Units.SI.Force F_table_fx, F_table_fy "table tangential friction";
  Modelica.Units.SI.Force F_grip_fx, F_grip_fy "gripper-object tangential friction";
  Modelica.Units.SI.Force F_friction_cap "total friction capacity holding object";
  Modelica.Units.SI.Force F_disturbance_x;

  // ---- Flags ----
  Boolean grasp_engaged;
  Boolean contact_established;

  // ---- Sensors ----
  Modelica.Units.SI.Length act_pose_x = x_g;
  Modelica.Units.SI.Length act_pose_y = y_g;
  Modelica.Units.SI.Length act_pose_z = z_g;
  Modelica.Units.SI.Velocity act_vel_x = vx_g;
  Modelica.Units.SI.Velocity act_vel_y = vy_g;
  Modelica.Units.SI.Velocity act_vel_z = vz_g;
  Modelica.Units.SI.Length obj_pose_x = x_obj;
  Modelica.Units.SI.Length obj_pose_y = y_obj;
  Modelica.Units.SI.Length obj_pose_z = z_obj;

  // ---- Tracking errors ----
  Modelica.Units.SI.Length err_x = x_cmd - x_g;
  Modelica.Units.SI.Length err_y = y_cmd - y_g;
  Modelica.Units.SI.Length err_z = z_cmd - z_g;
  Modelica.Units.SI.Length err_primary;

  // ---- Acceptance flags (fail-closed) ----
  Boolean travel_ok;
  Boolean effort_ok;
  Boolean contact_stable;
  Boolean obj_disp_ok;
  Boolean grasp_ok;
  Boolean tracking_ok;
  Boolean no_nan_inf;
  Boolean all_ok;

  // ---- Helpers ----
  Modelica.Units.SI.Length z_pen_grip;
  Modelica.Units.SI.Length z_pen_table;
  Modelica.Units.SI.Length obj_disp;
  Modelica.Units.SI.Acceleration ax_g, ay_g, az_g;
  Modelica.Units.SI.Acceleration ax_obj, ay_obj, az_obj;

equation
  // ---- Disturbance (middle third of 16 s) ----
  F_disturbance_x = if (time >= t_d_start and time <= t_d_end) then F_dist else 0.0;

  // ---- Normal contact: gripper descends onto object top ----
  z_pen_grip = max(0.0, (z_obj + z_obj_h) - z_g);
  F_normal_grip = k_contact*z_pen_grip
                  + d_contact*max(0.0, vz_obj - vz_g);

  // ---- Normal contact: object on rigid table ----
  z_pen_table = max(0.0, z_obj_h - z_obj);
  F_table_normal = k_contact*z_pen_table
                   + d_contact*max(0.0, -vz_obj);

  // ---- Contact / grasp flags ----
  contact_established = F_normal_grip > 1.0;
  grasp_engaged = (time >= t_grasp) and contact_established;

  // ---- Total friction capacity holding the object ----
  if grasp_engaged then
    F_friction_cap = mu*(F_normal_grip + F_table_normal);
  else
    F_friction_cap = mu*F_table_normal;
  end if;

  // ---- Tangential friction (regularized Coulomb, zero-error branch via tanh) ----
  F_table_fx = -mu*F_table_normal*Modelica.Math.tanh(vx_obj/eps_friction);
  F_table_fy = -mu*F_table_normal*Modelica.Math.tanh(vy_obj/eps_friction);
  F_grip_fx  = -mu*F_normal_grip*Modelica.Math.tanh((vx_obj - vx_g)/eps_friction);
  F_grip_fy  = -mu*F_normal_grip*Modelica.Math.tanh((vy_obj - vy_g)/eps_friction);

  // ---- Impedance motion + Z force regulation ----
  Fx_raw = k_imp*(x_cmd - x_g) - d_imp*vx_g;
  Fy_raw = k_imp*(y_cmd - y_g) - d_imp*vy_g;
  Fz_raw = k_imp*(z_cmd - z_g) - d_imp*vz_g - F_z_reg;

  // ---- Per-axis command saturation (385 N) ----
  Fx_act = max(-F_max, min(F_max, Fx_raw));
  Fy_act = max(-F_max, min(F_max, Fy_raw));
  Fz_act = max(-F_max, min(F_max, Fz_raw));

  // ---- Carriage dynamics ----
  m_carriage*ax_g = Fx_act - F_grip_fx;
  m_carriage*ay_g = Fy_act - F_grip_fy;
  m_carriage*az_g = Fz_act + F_normal_grip - m_carriage*g_n;
  der(x_g) = vx_g;  der(y_g) = vy_g;  der(z_g) = vz_g;
  der(vx_g) = ax_g; der(vy_g) = ay_g; der(vz_g) = az_g;

  // ---- Object dynamics ----
  m_obj*ax_obj = F_disturbance_x + F_table_fx + F_grip_fx;
  m_obj*ay_obj = F_table_fy + F_grip_fy;
  m_obj*az_obj = -F_normal_grip + F_table_normal - m_obj*g_n;
  der(x_obj) = vx_obj;  der(y_obj) = vy_obj;  der(z_obj) = vz_obj;
  der(vx_obj) = ax_obj; der(vy_obj) = ay_obj; der(vz_obj) = az_obj;

  // ---- Primary tracking error (well-defined safe norm) ----
  err_primary = sqrt(err_x*err_x + err_y*err_y + err_z*err_z + 1.0e-12);

  // ---- Bounded object displacement from initial pose ----
  obj_disp = sqrt(x_obj*x_obj + y_obj*y_obj
                  + (z_obj - z_obj_h)*(z_obj - z_obj_h) + 1.0e-12);

  // ---- Acceptance: fail-closed ----
  travel_ok      = (abs(x_g) <= x_lim + 1.0e-6)
                and (abs(y_g) <= y_lim + 1.0e-6)
                and (z_g >= -1.0e-6) and (z_g <= z_lim + 1.0e-6);
  effort_ok      = (abs(Fx_act) <= F_max + 1.0e-6)
                and (abs(Fy_act) <= F_max + 1.0e-6)
                and (abs(Fz_act) <= F_max + 1.0e-6);
  contact_stable = if (time > t_grasp + 1.0) then (F_normal_grip > 0.5) else true;
  obj_disp_ok    = obj_disp <= max_obj_disp;
  grasp_ok       = if grasp_engaged
                     then (F_friction_cap > abs(F_disturbance_x) + 1.0)
                     else true;
  tracking_ok    = if (time >= t_check) then (err_primary <= err_bound) else true;
  no_nan_inf     = Modelica.Math.isFinite(x_g) and Modelica.Math.isFinite(y_g)
                and Modelica.Math.isFinite(z_g) and Modelica.Math.isFinite(x_obj)
                and Modelica.Math.isFinite(y_obj) and Modelica.Math.isFinite(z_obj)
                and Modelica.Math.isFinite(Fx_act) and Modelica.Math.isFinite(Fy_act)
                and Modelica.Math.isFinite(Fz_act) and Modelica.Math.isFinite(F_normal_grip)
                and Modelica.Math.isFinite(F_table_normal) and Modelica.Math.isFinite(err_primary);
  all_ok = travel_ok and effort_ok and contact_stable and obj_disp_ok
        and grasp_ok and tracking_ok and no_nan_inf;

  // ---- 250 Hz controller: trajectory + force regulation ----
  when sample(0, Ts) then
    if time < 2.0 then
      // Phase 1: approach (impedance motion)
      z_cmd = 0.30 - (0.30 - z_approach)*(time/2.0);
      x_cmd = 0.0;
      y_cmd = 0.0;
      F_z_reg = 0.0;
    elseif time < 3.0 then
      // Phase 2: contact + force regulation ramp (establish grasp)
      z_cmd = z_approach;
      x_cmd = 0.0;
      y_cmd = 0.0;
      F_z_reg = F_z_reg_hold*(time - 2.0);
    else
      // Phase 3: hold stable grasp (force regulation maintained)
      z_cmd = z_approach;
      x_cmd = 0.0;
      y_cmd = 0.0;
      F_z_reg = F_z_reg_hold;
    end if;
  end when;

  annotation (
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.004),
    Documentation(info="CartesianToolGraspE: contact-rich manipulation test.
Three prismatic axes (X,Y,Z) move a 2.5 kg carriage over +/-0.10 m (X,Y) and +/-0.30 m (Z).
Per-axis actuator commands bounded to 385 N. Impedance motion followed by Z force
regulation presses a rigid object onto a rigid table (mu=0.78, e=0.03, collision enabled).
A 9.6 N tangential disturbance is applied over the middle third [5.333,10.667] s.
Control runs at 250 Hz (Ts=0.004 s) for 16 s. Acceptance is fail-closed (all_ok).")
  );
end CartesianToolGraspE;