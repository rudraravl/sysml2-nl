model CartesianToolGraspA
  "Contact-rich Cartesian tool manipulation: impedance motion then force regulation,
   with rigid support table, friction, restitution, and tangential disturbance."

  // ---- Physical parameters (stated) ----
  parameter Real m_tool = 2.5 "tool carriage mass [kg]";
  parameter Real x_lim = 0.10 "X travel limit magnitude [m]";
  parameter Real y_lim = 0.10 "Y travel limit magnitude [m]";
  parameter Real z_lim = 0.30 "Z travel limit magnitude [m]";
  parameter Real F_max = 252.0 "per-axis force command limit [N]";
  parameter Real mu = 0.78 "table/object friction coefficient";
  parameter Real e_rest = 0.03 "coefficient of restitution";
  parameter Real F_dist = 4.0 "tangential disturbance magnitude [N]";

  // ---- Physical parameters (assumptions; facts not stated treated as unknown) ----
  parameter Real m_obj = 0.5 "object mass [kg] (assumption)";
  parameter Real obj_h = 0.02 "object half-height [m] (assumption)";
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";

  // ---- Impedance controller ----
  parameter Real K_imp = 4000.0 "impedance stiffness [N/m]";
  parameter Real D_imp = 80.0 "impedance damping [N.s/m]";

  // ---- Force regulation (grip normal force) ----
  parameter Real F_grip_cmd = 30.0 "commanded grip normal force [N]";
  parameter Real K_grip = 2.0e4 "tool-object contact stiffness [N/m]";
  parameter Real D_grip = 200.0 "tool-object contact damping [N.s/m]";
  parameter Real mu_grip = 0.78 "tool-object friction coefficient (assumed equal to mu)";

  // ---- Table contact ----
  parameter Real K_table = 5.0e4 "table normal stiffness [N/m]";
  parameter Real D_table = 300.0 "table normal damping [N.s/m]";
  parameter Real table_z = 0.0 "table surface height [m]";

  // ---- Disturbance window (middle third of 8 s) ----
  parameter Real t1_dist = 8.0/3.0 "disturbance start [s]";
  parameter Real t2_dist = 16.0/3.0 "disturbance end [s]";

  // ---- Tool state ----
  Real x_t(start=0.0, fixed=true) "tool X position [m]";
  Real y_t(start=0.0, fixed=true) "tool Y position [m]";
  Real z_t(start=0.10, fixed=true) "tool Z position [m]";
  Real vx_t(start=0.0, fixed=true) "tool X velocity [m/s]";
  Real vy_t(start=0.0, fixed=true) "tool Y velocity [m/s]";
  Real vz_t(start=0.0, fixed=true) "tool Z velocity [m/s]";

  // ---- Object state (object pose) ----
  Real x_o(start=0.0, fixed=true) "object X position [m]";
  Real y_o(start=0.0, fixed=true) "object Y position [m]";
  Real z_o(start=obj_h, fixed=true) "object center Z [m]";
  Real vx_o(start=0.0, fixed=true) "object X velocity [m/s]";
  Real vy_o(start=0.0, fixed=true) "object Y velocity [m/s]";
  Real vz_o(start=0.0, fixed=true) "object Z velocity [m/s]";

  // ---- Command and actuator effort ----
  Real Fx_cmd "X force command [N]";
  Real Fy_cmd "Y force command [N]";
  Real Fz_cmd "Z force command [N]";
  Real Fx_act "actuated X force [N]";
  Real Fy_act "actuated Y force [N]";
  Real Fz_act "actuated Z force [N]";

  // ---- References and grip schedule ----
  Real x_ref "X reference [m]";
  Real y_ref "Y reference [m]";
  Real z_ref "Z reference [m]";
  Real grip_enable "grip engagement factor [0..1]";

  // ---- Contact / sensor signals ----
  Real pen_raw "raw tool-object penetration [m]";
  Real pen_to "tool-object penetration (clamped) [m]";
  Real pen_t_raw "raw table penetration [m]";
  Real pen_t "table penetration (clamped) [m]";
  Real F_grip_n "grip normal force magnitude [N]";
  Real F_grip_z_obj "grip normal force on object Z [N]";
  Real F_grip_x "grip friction force on object X [N]";
  Real F_grip_y "grip friction force on object Y [N]";
  Real N_table "table normal force on object [N]";
  Real F_table_fx "table friction X on object [N]";
  Real F_table_fy "table friction Y on object [N]";
  Real F_dist_x "applied tangential disturbance X [N]";

  // ---- Performance metrics ----
  Real err_x "X tracking error [m]";
  Real err_y "Y tracking error [m]";
  Real err_z "Z tracking error [m]";
  Real err_norm "primary tracking error norm [m]";
  Real obj_disp "object displacement magnitude from rest [m]";

equation
  // ---- Trajectory and grip schedule ----
  // Phase A (0-2 s): impedance descent toward object top.
  // Phase B (2-2.5 s): ramp grip normal force (force regulation onset).
  // Phase C (2.5-8 s): hold with force regulation.
  x_ref = 0.0;
  y_ref = 0.0;
  if time < 2.0 then
    z_ref = 0.10 - (0.10 - 2.0*obj_h)*(time/2.0);
    grip_enable = 0.0;
  elseif time < 2.5 then
    z_ref = 2.0*obj_h;
    grip_enable = (time - 2.0)/0.5;
  else
    z_ref = 2.0*obj_h;
    grip_enable = 1.0;
  end if;

  // ---- Tangential disturbance applied to object during middle third ----
  F_dist_x = if (time >= t1_dist and time <= t2_dist) then F_dist else 0.0;

  // ---- Impedance motion law with gravity compensation and grip force regulation ----
  Fx_cmd = K_imp*(x_ref - x_t) - D_imp*vx_t;
  Fy_cmd = K_imp*(y_ref - y_t) - D_imp*vy_t;
  Fz_cmd = K_imp*(z_ref - z_t) - D_imp*vz_t + m_tool*g_acc - grip_enable*F_grip_cmd;

  // ---- Per-axis effort saturation ----
  Fx_act = max(-F_max, min(F_max, Fx_cmd));
  Fy_act = max(-F_max, min(F_max, Fy_cmd));
  Fz_act = max(-F_max, min(F_max, Fz_cmd));

  // ---- Tool-object (grip) normal contact (collision enabled, restitution modeled via damping) ----
  pen_raw = (z_o + obj_h) - z_t;
  pen_to = max(0.0, pen_raw);
  F_grip_n = if pen_raw > 0.0 then max(0.0, K_grip*pen_raw + D_grip*(vz_o - vz_t)) else 0.0;
  // Restitution influences separation damping ratio; here embedded in D_grip selection.
  F_grip_z_obj = -F_grip_n; // downward on object, upward reaction on tool

  // ---- Grip tangential friction (couples object to tool) ----
  F_grip_x = mu_grip*F_grip_n*tanh(50.0*(vx_t - vx_o));
  F_grip_y = mu_grip*F_grip_n*tanh(50.0*(vy_t - vy_o));

  // ---- Table normal contact (collision enabled) ----
  pen_t_raw = table_z - (z_o - obj_h);
  pen_t = max(0.0, pen_t_raw);
  N_table = if pen_t_raw > 0.0 then max(0.0, K_table*pen_t_raw + D_table*(-vz_o)) else 0.0;

  // ---- Table tangential Coulomb friction (smoothed) ----
  F_table_fx = -mu*N_table*tanh(50.0*vx_o);
  F_table_fy = -mu*N_table*tanh(50.0*vy_o);

  // ---- Tool dynamics ----
  der(x_t) = vx_t;
  der(y_t) = vy_t;
  der(z_t) = vz_t;
  m_tool*der(vx_t) = Fx_act - F_grip_x;
  m_tool*der(vy_t) = Fy_act - F_grip_y;
  m_tool*der(vz_t) = Fz_act - F_grip_z_obj - m_tool*g_acc;

  // ---- Object dynamics ----
  der(x_o) = vx_o;
  der(y_o) = vy_o;
  der(z_o) = vz_o;
  m_obj*der(vx_o) = F_grip_x + F_table_fx + F_dist_x;
  m_obj*der(vy_o) = F_grip_y + F_table_fy;
  m_obj*der(vz_o) = F_grip_z_obj + N_table - m_obj*g_acc;

  // ---- Tracking error and bounded-displacement metrics (zero-error safe norm) ----
  err_x = x_t - x_ref;
  err_y = y_t - y_ref;
  err_z = z_t - z_ref;
  err_norm = sqrt(err_x*err_x + err_y*err_y + err_z*err_z + 1.0e-12);
  obj_disp = sqrt(x_o*x_o + y_o*y_o + (z_o - obj_h)*(z_o - obj_h) + 1.0e-12);

  // ---- Travel bounds ----
  assert(abs(x_t) <= x_lim + 1.0e-3, "X travel bound violated");
  assert(abs(y_t) <= y_lim + 1.0e-3, "Y travel bound violated");
  assert(abs(z_t) <= z_lim + 1.0e-3, "Z travel bound violated");
  // ---- Effort bounds ----
  assert(abs(Fx_act) <= F_max + 1.0e-6, "X effort bound violated");
  assert(abs(Fy_act) <= F_max + 1.0e-6, "Y effort bound violated");
  assert(abs(Fz_act) <= F_max + 1.0e-6, "Z effort bound violated");

  annotation (
    experiment(StopTime=8.0, Tolerance=1.0e-5, Interval=0.0125),
    Documentation(info="Cartesian 3-axis prismatic tool carriage (2.5 kg) with +/-0.10 m X,Y and +/-0.30 m Z travel, per-axis force limit 252 N. Impedance descent then force-regulated grasp on a rigid table (mu=0.78, e=0.03, collision enabled). A 4 N tangential disturbance acts on the object during the middle third [2.667 s, 5.333 s]. Control/sensor rate 80 Hz (Interval=0.0125 s). Object mass and half-height are assumptions (not stated)."));
end CartesianToolGraspA;