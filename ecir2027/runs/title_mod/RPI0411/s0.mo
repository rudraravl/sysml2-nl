model PlanarPusherGraspC
  "Contact-rich planar manipulation: impedance motion then force regulation"

  // ---- Link parameters (SI) ----
  parameter Real L1 = 0.46 "Link 1 length [m]";
  parameter Real L2 = 0.35 "Link 2 length [m]";
  parameter Real m1 = 2.0  "Link 1 mass [kg]";
  parameter Real m2 = 1.5  "Link 2 mass [kg]";
  parameter Real I1 = m1*L1^2/12 "Link 1 inertia about COM [kg.m2]";
  parameter Real I2 = m2*L2^2/12 "Link 2 inertia about COM [kg.m2]";
  parameter Real r1c = L1/2  "Link 1 COM distance [m]";
  parameter Real r2c = L2/2  "Link 2 COM distance [m]";

  // ---- Object and environment parameters ----
  parameter Real M_obj  = 1.0   "Object mass [kg]";
  parameter Real R_obj  = 0.05  "Object radius [m]";
  parameter Real R_tool = 0.02  "Rounded tool radius [m]";
  parameter Real mu     = 0.78  "Friction coefficient (all contacts)";
  parameter Real e_rest = 0.03  "Coefficient of restitution";
  parameter Real g      = 9.81  "Gravitational acceleration [m/s2]";
  parameter Real x_wall = 0.75  "Fixed wall (support stop) x position [m]";
  parameter Real k_contact = 1.0e4 "Contact stiffness [N/m]";
  parameter Real c_contact = 150.0 "Contact damping [N.s/m] (tuned for e=0.03)";
  parameter Real k_wall = 1.0e4   "Wall contact stiffness [N/m]";
  parameter Real c_wall = 150.0   "Wall contact damping [N.s/m]";

  // ---- Control parameters ----
  parameter Real tau_max       = 46.0  "Maximum command magnitude per joint [N.m]";
  parameter Real F_dist        = 7.2   "Tangential disturbance load [N]";
  parameter Real F_normal_des  = 15.0  "Desired normal grasp force [N]";
  parameter Real K_imp = 800.0  "Impedance stiffness [N/m]";
  parameter Real D_imp = 40.0   "Impedance damping [N.s/m]";
  parameter Real t_approach   = 3.0  "Impedance approach duration [s]";
  parameter Real t_dist_start = 4.0  "Disturbance start (middle third) [s]";
  parameter Real t_dist_end   = 8.0  "Disturbance end (middle third) [s]";

  // ---- Initial conditions ----
  parameter Real q1_0     = 0.8   "Initial joint 1 angle [rad]";
  parameter Real q2_0     = -0.2  "Initial joint 2 angle [rad]";
  parameter Real x_obj_0  = 0.70  "Initial object x position [m]";
  parameter Real y_obj_0  = 0.0   "Initial object y position [m]";

  // ---- Regularization ----
  parameter Real v_thresh  = 1.0e-3 "Friction regularization velocity [m/s]";
  parameter Real eps_N     = 1.0e-2 "Contact force smoothing constant [N]";
  parameter Real eps_dist   = 1.0e-6 "Distance regularization [m]";

  // ---- Robot states ----
  Real q1(start=q1_0, fixed=true)  "Joint 1 angle [rad]";
  Real q2(start=q2_0, fixed=true)  "Joint 2 angle [rad]";
  Real dq1(start=0.0, fixed=true)  "Joint 1 velocity [rad/s]";
  Real dq2(start=0.0, fixed=true)  "Joint 2 velocity [rad/s]";

  // ---- Object states ----
  Real x_obj(start=x_obj_0, fixed=true)  "Object x position [m]";
  Real y_obj(start=y_obj_0, fixed=true)  "Object y position [m]";
  Real dx_obj(start=0.0, fixed=true)     "Object x velocity [m/s]";
  Real dy_obj(start=0.0, fixed=true)     "Object y velocity [m/s]";

  // ---- Forward kinematics ----
  Real x_tip  "Tip x position [m]";
  Real y_tip  "Tip y position [m]";
  Real dx_tip "Tip x velocity [m/s]";
  Real dy_tip "Tip y velocity [m/s]";
  Real J11, J12, J21, J22 "Jacobian elements";

  // ---- Inertia matrix ----
  Real M11, M12, M22 "Inertia matrix elements [kg.m2]";
  Real det_M "Inertia matrix determinant [kg.m2]^2";

  // ---- Coriolis ----
  Real h  "Coriolis coupling coefficient [kg.m2]";
  Real C1 "Coriolis term joint 1 [N.m]";
  Real C2 "Coriolis term joint 2 [N.m]";

  // ---- Trajectory ----
  Real s_traj     "Trajectory progress [0..1]";
  Real x_d        "Desired tip x [m]";
  Real y_d        "Desired tip y [m]";
  Real dx_d       "Desired tip x velocity [m/s]";
  Real dy_d       "Desired tip y velocity [m/s]";
  Real x_tip_init "Initial tip x [m]";
  Real y_tip_init "Initial tip y [m]";
  Real x_target   "Target tip x [m]";
  Real y_target   "Target tip y [m]";

  // ---- Control ----
  Real F_cmd_x  "Commanded Cartesian force x [N]";
  Real F_cmd_y  "Commanded Cartesian force y [N]";
  Real tau1_raw "Raw joint 1 torque [N.m]";
  Real tau2_raw "Raw joint 2 torque [N.m]";
  Real tau1     "Saturated joint 1 torque [N.m]";
  Real tau2     "Saturated joint 2 torque [N.m]";
  Real rhs1     "Right-hand side joint 1 dynamics [N.m]";
  Real rhs2     "Right-hand side joint 2 dynamics [N.m]";

  // ---- Contact geometry (tool-object) ----
  Real dx_to      "Tip-to-object x [m]";
  Real dy_to      "Tip-to-object y [m]";
  Real dist_to    "Tip-to-object distance [m]";
  Real dist_to_safe "Regularized distance [m]";
  Real nx  "Contact normal x";
  Real ny  "Contact normal y";
  Real tx  "Contact tangent x";
  Real ty  "Contact tangent y";
  Real pen "Penetration [m]";
  Real pen_dot "Penetration rate [m/s]";

  // ---- Contact forces (tool-object) ----
  Real N_contact   "Normal contact force [N]";
  Real v_rel_t     "Relative tangential velocity [m/s]";
  Real f_friction  "Tool-object friction force [N]";
  Real F_contact_x "Contact force on object x [N]";
  Real F_contact_y "Contact force on object y [N]";

  // ---- Wall contact ----
  Real pen_wall  "Wall penetration [m]";
  Real N_wall    "Wall normal force [N]";
  Real f_wall    "Wall friction force [N]";
  Real F_wall_x  "Wall force on object x [N]";
  Real F_wall_y  "Wall force on object y [N]";

  // ---- Table friction ----
  Real v_obj_mag      "Object speed [m/s]";
  Real v_obj_mag_safe "Regularized object speed [m/s]";
  Real F_table_max    "Maximum table friction [N]";
  Real F_table_x      "Table friction x [N]";
  Real F_table_y      "Table friction y [N]";

  // ---- Disturbance ----
  Real F_dist_y "Applied tangential disturbance [N]";

  // ---- Sensors / evidence ----
  Real F_normal_meas   "Measured normal contact force [N]";
  Real tracking_error  "Primary tip tracking error [m]";
  Real obj_displacement "Object displacement from initial [m]";

  // ---- Phase / status flags ----
  Boolean in_approach       "Approach (impedance motion) phase";
  Boolean in_force_reg      "Force regulation phase";
  Boolean disturbance_active "Disturbance active flag";
  Boolean collision_enabled  "Collision enabled flag";
  Boolean contact_established "Contact established flag";
  Boolean grasp_lost         "Grasp loss flag";

equation
  // ===== Forward kinematics =====
  x_tip = L1*cos(q1) + L2*cos(q1 + q2);
  y_tip = L1*sin(q1) + L2*sin(q1 + q2);
  J11 = -L1*sin(q1) - L2*sin(q1 + q2);
  J12 = -L2*sin(q1 + q2);
  J21 =  L1*cos(q1) + L2*cos(q1 + q2);
  J22 =  L2*cos(q1 + q2);
  dx_tip = J11*dq1 + J12*dq2;
  dy_tip = J21*dq1 + J22*dq2;

  // ===== Inertia matrix (uniform rods) =====
  M11 = m1*r1c^2 + I1 + m2*(L1^2 + r2c^2 + 2*L1*r2c*cos(q2)) + I2;
  M12 = m2*(r2c^2 + L1*r2c*cos(q2)) + I2;
  M22 = m2*r2c^2 + I2;
  det_M = M11*M22 - M12*M12;

  // ===== Coriolis / centrifugal =====
  h  = m2*L1*r2c*sin(q2);
  C1 = -h*dq2^2 - 2*h*dq1*dq2;
  C2 =  h*dq1^2;

  // ===== Trajectory targets =====
  x_tip_init = L1*cos(q1_0) + L2*cos(q1_0 + q2_0);
  y_tip_init = L1*sin(q1_0) + L2*sin(q1_0 + q2_0);
  x_target   = x_obj_0 - (R_obj + R_tool);
  y_target   = y_obj_0;

  // Smoothstep trajectory  s(t) = 3u^2 - 2u^3
  s_traj = if time <= t_approach then
             3*(time/t_approach)^2 - 2*(time/t_approach)^3
           else 1.0;
  x_d = x_tip_init + (x_target - x_tip_init)*s_traj;
  y_d = y_tip_init + (y_target - y_tip_init)*s_traj;
  dx_d = if time < t_approach then
           (x_target - x_tip_init)*(6.0*time/t_approach^2 - 6.0*time^2/t_approach^3)
         else 0.0;
  dy_d = if time < t_approach then
           (y_target - y_tip_init)*(6.0*time/t_approach^2 - 6.0*time^2/t_approach^3)
         else 0.0;

  // ===== Phase flags =====
  in_approach        = time < t_approach;
  in_force_reg       = time >= t_approach;
  disturbance_active = (time >= t_dist_start) and (time <= t_dist_end);
  collision_enabled  = true;

  // ===== Control law =====
  // Phase 1: Cartesian impedance motion tracking.
  // Phase 2: impedance hold + normal force regulation along contact normal.
  F_cmd_x = if in_approach then
              K_imp*(x_d - x_tip) + D_imp*(dx_d - dx_tip)
            else
              K_imp*(x_target - x_tip) + D_imp*(0.0 - dx_tip) + F_normal_des*nx;
  F_cmd_y = if in_approach then
              K_imp*(y_d - y_tip) + D_imp*(dy_d - dy_tip)
            else
              K_imp*(y_target - y_tip) + D_imp*(0.0 - dy_tip) + F_normal_des*ny;

  // Convert Cartesian command to joint torques via Jacobian transpose
  tau1_raw = J11*F_cmd_x + J21*F_cmd_y;
  tau2_raw = J12*F_cmd_x + J22*F_cmd_y;

  // Saturate to ±tau_max (46 N.m per joint)
  tau1 = if tau1_raw >  tau_max then  tau_max
    else if tau1_raw < -tau_max then -tau_max else tau1_raw;
  tau2 = if tau2_raw >  tau_max then  tau_max
    else if tau2_raw < -tau_max then -tau_max else tau2_raw;

  // ===== Contact geometry (tool–object) =====
  dx_to = x_obj - x_tip;
  dy_to = y_obj - y_tip;
  dist_to = sqrt(dx_to^2 + dy_to^2);
  dist_to_safe = if dist_to > eps_dist then dist_to else eps_dist;
  nx = dx_to / dist_to_safe;
  ny = dy_to / dist_to_safe;
  tx = -ny;
  ty =  nx;
  pen = (R_obj + R_tool) - dist_to;
  pen_dot = -(dx_to*(dx_obj - dx_tip) + dy_to*(dy_obj - dy_tip)) / dist_to_safe;

  // ===== Tool–object contact force (smooth, non-negative) =====
  // Spring-damper with restitution approximated by damping ratio for e=0.03.
  N_contact = (k_contact*pen + c_contact*pen_dot
               + sqrt((k_contact*pen + c_contact*pen_dot)^2 + eps_N^2)) / 2.0;

  // Relative tangential velocity (object w.r.t. tip)
  v_rel_t = (dx_obj - dx_tip)*tx + (dy_obj - dy_tip)*ty;

  // Regularized Coulomb friction
  f_friction = -mu * N_contact * tanh(v_rel_t / v_thresh);

  // Total contact force on object from tool
  F_contact_x = N_contact*nx + f_friction*tx;
  F_contact_y = N_contact*ny + f_friction*ty;

  // ===== Wall contact (object against fixed stop) =====
  pen_wall = (x_obj + R_obj) - x_wall;
  N_wall = (k_wall*pen_wall + c_wall*dx_obj
            + sqrt((k_wall*pen_wall + c_wall*dx_obj)^2 + eps_N^2)) / 2.0;
  f_wall = -mu * N_wall * tanh(dy_obj / v_thresh);
  F_wall_x = -N_wall;
  F_wall_y =  f_wall;

  // ===== Table friction (isotropic Coulomb, regularized) =====
  v_obj_mag = sqrt(dx_obj^2 + dy_obj^2);
  v_obj_mag_safe = sqrt(v_obj_mag^2 + v_thresh^2);
  F_table_max = mu * M_obj * g;
  F_table_x = -F_table_max * dx_obj / v_obj_mag_safe;
  F_table_y = -F_table_max * dy_obj / v_obj_mag_safe;

  // ===== Disturbance (middle third of 12 s) =====
  F_dist_y = if disturbance_active then F_dist else 0.0;

  // ===== Robot dynamics (explicit inverse inertia form) =====
  rhs1 = tau1 - C1 - (J11*F_contact_x + J21*F_contact_y);
  rhs2 = tau2 - C2 - (J12*F_contact_x + J22*F_contact_y);
  der(q1)  = dq1;
  der(q2)  = dq2;
  der(dq1) = ( M22*rhs1 - M12*rhs2) / det_M;
  der(dq2) = (-M12*rhs1 + M11*rhs2) / det_M;

  // ===== Object dynamics =====
  der(x_obj)  = dx_obj;
  der(y_obj)  = dy_obj;
  M_obj*der(dx_obj) = F_contact_x + F_wall_x + F_table_x;
  M_obj*der(dy_obj) = F_contact_y + F_wall_y + F_table_y + F_dist_y;

  // ===== Sensors and evidence =====
  F_normal_meas    = N_contact;
  tracking_error   = sqrt((x_d - x_tip)^2 + (y_d - y_tip)^2);
  obj_displacement = sqrt((x_obj - x_obj_0)^2 + (y_obj - y_obj_0)^2);
  contact_established = N_contact > 0.5;
  grasp_lost = (N_contact < 0.1) and (time > t_approach + 0.5);

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "PlanarPusherGraspC: two-link planar manipulator (0.46 m + 0.35 m)
      on revolute Z joints with a rounded contact tool. Impedance motion for approach
      followed by force regulation to grasp a rigid object against a fixed wall.
      Friction coefficient 0.78, restitution 0.03, collision enabled.
      Max command 46 N.m per joint. 7.2 N tangential disturbance during middle third.
      Sample rate 125 Hz (Interval = 0.008 s) over 12 s.
      Sensors: actuator state (q1,q2,dq1,dq2), normal contact force, object pose (x_obj,y_obj).")
  );
end PlanarPusherGraspC;