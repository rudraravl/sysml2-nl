model CartesianToolGraspE
  // Requirement facts
  constant Real PI = 3.141592653589793;
  parameter Real m_tool = 2.5 "kg";
  parameter Real x_min = -0.10 "m";
  parameter Real x_max = 0.10 "m";
  parameter Real y_min = -0.10 "m";
  parameter Real y_max = 0.10 "m";
  parameter Real z_min = -0.30 "m";
  parameter Real z_max = 0.30 "m";
  parameter Real F_act_limit = 385 "N per axis";
  parameter Real mu = 0.78;
  parameter Real e_rest = 0.03;
  parameter Real F_disturbance = 9.6 "N";
  parameter Real Ts = 0.004 "s, 250 Hz control and trace rate";
  parameter Real T_end = 16 "s";
  parameter Real T_dist_start = T_end/3 "s, middle-third start";
  parameter Real T_dist_end = 2*T_end/3 "s, middle-third end";
  parameter Real F_normal_ref = F_disturbance/mu "N, minimal normal contact force from stated load and friction";

  // Design choices selected to satisfy bounds only
  parameter Real K_imp = 1000 "N/m";
  parameter Real D_imp = 80 "N.s/m";
  parameter Real K_imp_z = 1000 "N/m";
  parameter Real D_imp_z = 80 "N.s/m";
  parameter Real T_act = 0.02 "s";
  parameter Real k_contact = 1.0e5 "N/m";
  parameter Real k_grip = 1000 "N/m";
  parameter Real T_est = 0.02 "s";
  parameter Real tol = 1.0e-6;
  parameter Boolean collision_enabled = true;
  parameter Real table_z = 0.0 "m";
  parameter Real q_ref_x = 0.0 "m";
  parameter Real q_ref_y = 0.0 "m";
  parameter Real q_ref_z = 0.0 "m";
  parameter Real zeta_contact = -log(e_rest)/sqrt(PI*PI + log(e_rest)*log(e_rest)) "dimensionless";
  parameter Real d_contact = 2*zeta_contact*sqrt(k_contact*m_tool) "N.s/m";
  parameter Real object_bound = sqrt(x_max*x_max + y_max*y_max + z_max*z_max) "m";

  // Plant state: three orthogonal prismatic axes and tool carriage
  Real q_x(start=-0.05, fixed=true) "m";
  Real q_y(start=0.05, fixed=true) "m";
  Real q_z(start=0.10, fixed=true) "m";
  Real v_x(start=0.0, fixed=true) "m/s";
  Real v_y(start=0.0, fixed=true) "m/s";
  Real v_z(start=0.0, fixed=true) "m/s";
  Real tau_x(start=0.0, fixed=true) "N";
  Real tau_y(start=0.0, fixed=true) "N";
  Real tau_z(start=0.0, fixed=true) "N";

  // Control commands and actuator command state
  discrete Real u_x(start=0.0) "N";
  discrete Real u_y(start=0.0) "N";
  discrete Real u_z(start=0.0) "N";
  Real tau_cmd_x "N";
  Real tau_cmd_y "N";
  Real tau_cmd_z "N";
  discrete Boolean contact(start=false, fixed=true);
  discrete Boolean grasp_engaged(start=false, fixed=true);

  // Contact, friction, object pose, and sensors
  Real penetration "m";
  Real F_normal "N";
  Real M_friction "N";
  Real F_net_x "N";
  Real F_net_y "N";
  Real F_friction_x "N";
  Real F_friction_y "N";
  Real F_dist_x "N";
  Real F_slip_residual_x "N";
  Real delta_grip_x "m";
  Real p_obj_x "m";
  Real p_obj_y "m";
  Real p_obj_z "m";
  Real F_grip_normal "N";
  Real grasp_margin "N";
  Real primary_tracking_error "m";
  Real object_displacement "m";

  // Estimator values
  Real q_hat_x(start=-0.05, fixed=true) "m";
  Real q_hat_y(start=0.05, fixed=true) "m";
  Real q_hat_z(start=0.10, fixed=true) "m";
  Real v_hat_x(start=0.0, fixed=true) "m/s";
  Real v_hat_y(start=0.0, fixed=true) "m/s";
  Real v_hat_z(start=0.0, fixed=true) "m/s";
  Real F_normal_hat(start=0.0, fixed=true) "N";

equation
  // Prismatic axis dynamics
  der(q_x) = v_x;
  der(q_y) = v_y;
  der(q_z) = v_z;
  m_tool*der(v_x) = tau_x + F_dist_x + F_friction_x;
  m_tool*der(v_y) = tau_y + F_friction_y;
  m_tool*der(v_z) = tau_z + F_normal;

  // Force-limited actuators with first-order effort dynamics
  der(tau_x) = (tau_cmd_x - tau_x)/T_act;
  der(tau_y) = (tau_cmd_y - tau_y)/T_act;
  der(tau_z) = (tau_cmd_z - tau_z)/T_act;
  tau_cmd_x = max(-F_act_limit, min(F_act_limit, u_x));
  tau_cmd_y = max(-F_act_limit, min(F_act_limit, u_y));
  tau_cmd_z = max(-F_act_limit, min(F_act_limit, u_z));

  // Disturbance: controlled tangential load during middle third
  F_dist_x = if time >= T_dist_start and time <= T_dist_end then F_disturbance else 0.0;

  // Rigid support table contact with collision enabled
  penetration = max(0.0, table_z - q_z);
  F_normal = if collision_enabled then max(0.0, k_contact*penetration - d_contact*v_z) else 0.0;

  // Table friction, regularized as static Coulomb friction
  M_friction = mu*F_normal;
  F_net_x = tau_x + F_dist_x;
  F_net_y = tau_y;
  F_friction_x = if abs(F_net_x) > M_friction then -M_friction*sign(F_net_x) else -F_net_x;
  F_friction_y = if abs(F_net_y) > M_friction then -M_friction*sign(F_net_y) else -F_net_y;

  // Grasp compliance and object pose.
  F_slip_residual_x = if abs(F_dist_x) > M_friction then (abs(F_dist_x) - M_friction)*sign(F_dist_x) else 0.0;
  delta_grip_x = F_slip_residual_x/k_grip;
  p_obj_x = q_x + delta_grip_x;
  p_obj_y = q_y;
  p_obj_z = q_z;
  F_grip_normal = F_normal;
  grasp_margin = M_friction - abs(F_dist_x);

  // Tracking and displacement observables
  primary_tracking_error = sqrt(max(0.0, (q_ref_x - q_x)^2 + (q_ref_y - q_y)^2 + (q_ref_z - q_z)^2));
  object_displacement = sqrt(max(0.0, p_obj_x^2 + p_obj_y^2 + p_obj_z^2));

  // Estimator
  der(q_hat_x) = v_hat_x;
  der(q_hat_y) = v_hat_y;
  der(q_hat_z) = v_hat_z;
  T_est*der(v_hat_x) = v_x - v_hat_x;
  T_est*der(v_hat_y) = v_y - v_hat_y;
  T_est*der(v_hat_z) = v_z - v_hat_z;
  T_est*der(F_normal_hat) = F_normal - F_normal_hat;

  // Fail-closed acceptance checks
  assert(q_x >= x_min - tol and q_x <= x_max + tol, "X travel bound violated");
  assert(q_y >= y_min - tol and q_y <= y_max + tol, "Y travel bound violated");
  assert(q_z >= z_min - tol and q_z <= z_max + tol, "Z travel bound violated");
  assert(p_obj_x >= x_min - tol and p_obj_x <= x_max + tol, "object X displacement bound violated");
  assert(p_obj_y >= y_min - tol and p_obj_y <= y_max + tol, "object Y displacement bound violated");
  assert(p_obj_z >= z_min - tol and p_obj_z <= z_max + tol, "object Z displacement bound violated");
  assert(object_displacement <= object_bound + tol, "object displacement bound violated");
  assert(abs(tau_x) <= F_act_limit + tol and abs(tau_cmd_x) <= F_act_limit + tol, "X effort bound violated");
  assert(abs(tau_y) <= F_act_limit + tol and abs(tau_cmd_y) <= F_act_limit + tol, "Y effort bound violated");
  assert(abs(tau_z) <= F_act_limit + tol and abs(tau_cmd_z) <= F_act_limit + tol, "Z effort bound violated");
  assert(time < T_dist_start or F_normal > 0.0, "stable contact lost during hold");
  assert(time < T_dist_start or grasp_margin >= -1.0e-9, "grasp loss during tangential disturbance");
  assert(time < 10.4 or primary_tracking_error <= 0.013, "primary tracking error bound violated after 10.4 s");

  // NaN or infinite value checks
  assert(abs(q_x) < 1.0e30 and abs(q_y) < 1.0e30 and abs(q_z) < 1.0e30, "State infinity/NaN");
  assert(abs(v_x) < 1.0e30 and abs(v_y) < 1.0e30 and abs(v_z) < 1.0e30, "Velocity infinity/NaN");
  assert(abs(tau_x) < 1.0e30 and abs(tau_y) < 1.0e30 and abs(tau_z) < 1.0e30, "Effort infinity/NaN");
  assert(abs(tau_cmd_x) < 1.0e30 and abs(tau_cmd_y) < 1.0e30 and abs(tau_cmd_z) < 1.0e30, "Command infinity/NaN");
  assert(abs(F_normal) < 1.0e30 and abs(p_obj_x) < 1.0e30 and abs(p_obj_y) < 1.0e30 and abs(p_obj_z) < 1.0e30, "Contact/Obj infinity/NaN");
  assert(abs(q_hat_x) < 1.0e30 and abs(v_hat_x) < 1.0e30 and abs(F_normal_hat) < 1.0e30, "Estimator infinity/NaN");

algorithm
  when sample(0.0, Ts) then
    // Synchronized state, command, and sensor traces are retained in these variables for export
    contact := F_normal > 1.0e-6;
    grasp_engaged := contact and F_normal >= 0.5*F_normal_ref;

    // Impedance motion in X/Y; impedance descent in Z followed by normal force regulation after contact
    u_x := K_imp*(q_ref_x - q_x) - D_imp*v_x;
    u_y := K_imp*(q_ref_y - q_y) - D_imp*v_y;
    if contact then
      u_z := -F_normal_ref;
    else
      u_z := K_imp_z*(q_ref_z - q_z) - D_imp_z*v_z;
    end if;
  end when;

  annotation(experiment(StopTime=16, Interval=0.004, Tolerance=1.0e-6));
end CartesianToolGraspE;