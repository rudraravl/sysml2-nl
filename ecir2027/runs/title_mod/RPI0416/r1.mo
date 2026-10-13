model PlanarPusherInsertB
  "Contact-rich planar peg insertion with Cartesian impedance control"

  // ===== Physical parameters (specified in requirement) =====
  parameter Real L1 = 0.46 "Link 1 length [m]";
  parameter Real L2 = 0.35 "Link 2 length [m]";
  parameter Real tau_max = 41.0 "Max joint torque magnitude per joint [N.m]";
  parameter Real clearance = 0.001 "Hole radial clearance [m]";
  parameter Real mu_contact = 0.35 "Contact friction coefficient";
  parameter Real F_dist_amp = 7.0 "Lateral disturbance amplitude [N]";
  parameter Real insertion_target = 0.06 "Required insertion depth [m]";
  parameter Real alignment_tol = 0.002 "Alignment tolerance after 6.5 s [m]";
  parameter Real dt_ctrl = 0.01 "Control sample period (100 Hz) [s]";

  // ===== Physical parameters (not specified in requirement; chosen for demonstration) =====
  // Link inertias, hole location, contact stiffness, and controller gains are not given.
  // Values below are reasonable engineering choices, not facts from the requirement.
  parameter Real J1_inertia = 0.5 "Link 1 inertia about joint axis [kg.m2]";
  parameter Real J2_inertia = 0.2 "Link 2 inertia about joint axis [kg.m2]";
  parameter Real x_hole = 0.65 "Hole entrance x position [m]";
  parameter Real y_hole = 0.30 "Hole center y position [m]";
  parameter Real k_contact = 1.0e5 "Contact stiffness (rigid collision) [N/m]";
  parameter Real d_contact = 1000.0 "Contact damping [N.s/m]";
  parameter Real v_max = 0.015 "Bounded insertion speed [m/s]";
  parameter Real Kpx = 1500.0 "Impedance stiffness x [N/m]";
  parameter Real Kpy = 4000.0 "Impedance stiffness y [N/m]";
  parameter Real Kdx = 40.0 "Impedance damping x [N.s/m]";
  parameter Real Kdy = 100.0 "Impedance damping y [N.s/m]";
  parameter Real F_lateral_limit = 50.0 "Lateral force limit [N]";
  parameter Real F_axial_limit = 30.0 "Axial force limit [N]";
  parameter Real peg_tilt_limit = 0.10 "Peg tilt limit [rad]";

  // ===== Joint states =====
  Real q1(start = 0.95, fixed = true) "Joint 1 angle [rad]";
  Real q2(start = -1.15, fixed = true) "Joint 2 angle [rad]";
  Real q1d(start = 0.0, fixed = true) "Joint 1 angular velocity [rad/s]";
  Real q2d(start = 0.0, fixed = true) "Joint 2 angular velocity [rad/s]";

  // ===== End effector kinematics =====
  Real x_ee "End effector x [m]";
  Real y_ee "End effector y [m]";
  Real x_ee_d "End effector x velocity [m/s]";
  Real y_ee_d "End effector y velocity [m/s]";

  // ===== Jacobian =====
  Real J11 "Jacobian dx/dq1 [m/rad]";
  Real J12 "Jacobian dx/dq2 [m/rad]";
  Real J21 "Jacobian dy/dq1 [m/rad]";
  Real J22 "Jacobian dy/dq2 [m/rad]";

  // ===== Contact and external forces =====
  Real F_contact_y "Lateral contact force from hole wall [N]";
  Real F_normal "Normal contact force magnitude [N]";
  Real F_friction_x "Friction force along insertion direction [N]";
  Real F_dist_y "Lateral disturbance force [N]";
  Real F_ext_x "Total external force x [N]";
  Real F_ext_y "Total external force y [N]";
  Real insertion_depth "Current insertion depth [m]";
  Real peg_tilt "Peg tilt from insertion axis [rad]";
  Real abs_xee_d "Abs end effector x velocity [m/s]";

  // ===== Controller (sampled at 100 Hz) =====
  Real x_des_cont "Continuous desired x [m]";
  Real xd_des_cont "Continuous desired x velocity [m/s]";
  Real x_des_h(start = 0.65, fixed = true) "Held desired x [m]";
  Real y_des_h(start = 0.30, fixed = true) "Held desired y [m]";
  Real xd_des_h(start = 0.0, fixed = true) "Held desired x velocity [m/s]";
  Real yd_des_h(start = 0.0, fixed = true) "Held desired y velocity [m/s]";
  Real F_cmd_x_h(start = 0.0, fixed = true) "Held commanded Cartesian force x [N]";
  Real F_cmd_y_h(start = 0.0, fixed = true) "Held commanded Cartesian force y [N]";
  Real tau1_raw_h(start = 0.0, fixed = true) "Held raw torque 1 [N.m]";
  Real tau2_raw_h(start = 0.0, fixed = true) "Held raw torque 2 [N.m]";
  Real tau1_abs_h(start = 0.0, fixed = true) "Abs held raw torque 1 [N.m]";
  Real tau2_abs_h(start = 0.0, fixed = true) "Abs held raw torque 2 [N.m]";
  Real tau1_cmd(start = 0.0, fixed = true) "Saturated commanded torque 1 [N.m]";
  Real tau2_cmd(start = 0.0, fixed = true) "Saturated commanded torque 2 [N.m]";

  // ===== Sensor traces (six-axis contact wrench) =====
  Real Fx_meas "Measured force x [N]";
  Real Fy_meas "Measured force y [N]";
  Real Fz_meas "Measured force z (planar: zero) [N]";
  Real Mx_meas "Measured moment x (planar: zero) [N.m]";
  Real My_meas "Measured moment y (planar: zero) [N.m]";
  Real Mz_meas "Measured moment z (planar: nominally zero) [N.m]";

  // ===== Monitoring =====
  Real alignment_error "Lateral alignment error [m]";
  Real F_lateral_max(start = 0.0, fixed = true) "Running max lateral force [N]";
  Real F_axial_max(start = 0.0, fixed = true) "Running max axial force [N]";
  Boolean alignment_ok "Alignment within tolerance after 6.5 s";
  Boolean insertion_ok "Insertion depth achieved";
  Boolean tilt_ok "Peg tilt within limit";
  Boolean actuator_ok "Actuator torques within bounds";
  Boolean lateral_force_ok "Lateral force within limit";
  Boolean axial_force_ok "Axial force within limit";
  Boolean no_nan_inf "No NaN or infinite values detected";

equation
  // ===== Forward kinematics =====
  x_ee = L1 * cos(q1) + L2 * cos(q1 + q2);
  y_ee = L1 * sin(q1) + L2 * sin(q1 + q2);
  x_ee_d = -L1 * sin(q1) * q1d - L2 * sin(q1 + q2) * (q1d + q2d);
  y_ee_d = L1 * cos(q1) * q1d + L2 * cos(q1 + q2) * (q1d + q2d);

  // ===== Jacobian =====
  J11 = -L1 * sin(q1) - L2 * sin(q1 + q2);
  J12 = -L2 * sin(q1 + q2);
  J21 = L1 * cos(q1) + L2 * cos(q1 + q2);
  J22 = L2 * cos(q1 + q2);

  // ===== Insertion depth and peg tilt =====
  insertion_depth = max(0.0, x_ee - x_hole);
  peg_tilt = q1 + q2;

  // ===== Contact model: rigid collision via stiff spring-damper =====
  // Lateral contact only when peg is inside the hole (x_ee > x_hole)
  // Upper wall contact: y_ee exceeds y_hole + clearance
  // Lower wall contact: y_ee below y_hole - clearance
  F_contact_y = if x_ee > x_hole and (y_ee - y_hole) > clearance then
      -k_contact * (y_ee - y_hole - clearance) - d_contact * y_ee_d
    elseif x_ee > x_hole and (y_ee - y_hole) < -clearance then
      -k_contact * (y_ee - y_hole + clearance) - d_contact * y_ee_d
    else
      0.0;

  // Normal force magnitude
  F_normal = abs(F_contact_y);

  // Coulomb friction with zero-velocity regularization (prevents division by zero)
  abs_xee_d = abs(x_ee_d);
  F_friction_x = if abs_xee_d > 1e-6 then
      -mu_contact * F_normal * (x_ee_d / abs_xee_d)
    else
      0.0;

  // ===== Disturbance: controlled 7 N lateral load during middle third =====
  // Middle third of 10 s: t in [10/3, 20/3] = [3.333, 6.667] s
  F_dist_y = if time >= 10.0/3.0 and time <= 20.0/3.0 then F_dist_amp else 0.0;

  // ===== Total external forces on end effector =====
  F_ext_x = F_friction_x;
  F_ext_y = F_contact_y + F_dist_y;

  // ===== Dynamics: decoupled joint inertias with Jacobian-transpose force mapping =====
  J1_inertia * der(q1d) = tau1_cmd + J11 * F_ext_x + J21 * F_ext_y;
  J2_inertia * der(q2d) = tau2_cmd + J12 * F_ext_x + J22 * F_ext_y;
  der(q1) = q1d;
  der(q2) = q2d;

  // ===== Desired trajectory (bounded insertion speed) =====
  // Phase 1: 0-2 s  approach and align at hole entrance
  // Phase 2: 2-6 s   insert at v_max (0.06 m in 4 s)
  // Phase 3: 6-10 s  hold at full insertion
  x_des_cont = if time <= 2.0 then
      x_hole
    elseif time <= 6.0 then
      x_hole + v_max * (time - 2.0)
    else
      x_hole + v_max * 4.0;
  xd_des_cont = if time > 2.0 and time < 6.0 then v_max else 0.0;

  // ===== Sampled controller at 100 Hz =====
  when sample(0, dt_ctrl) then
    // Hold desired trajectory
    x_des_h = x_des_cont;
    y_des_h = y_hole;
    xd_des_h = xd_des_cont;
    yd_des_h = 0.0;

    // Cartesian impedance force (feedback from current continuous state)
    F_cmd_x_h = Kpx * (x_des_h - x_ee) + Kdx * (xd_des_h - x_ee_d);
    F_cmd_y_h = Kpy * (y_des_h - y_ee) + Kdy * (yd_des_h - y_ee_d);

    // Jacobian transpose: Cartesian force to joint torques
    tau1_raw_h = J11 * F_cmd_x_h + J21 * F_cmd_y_h;
    tau2_raw_h = J12 * F_cmd_x_h + J22 * F_cmd_y_h;

    // Torque saturation with zero-error branch (division guarded by > check)
    tau1_abs_h = abs(tau1_raw_h);
    tau2_abs_h = abs(tau2_raw_h);
    tau1_cmd = if tau1_abs_h > tau_max then tau_max * (tau1_raw_h / tau1_abs_h) else tau1_raw_h;
    tau2_cmd = if tau2_abs_h > tau_max then tau_max * (tau2_raw_h / tau2_abs_h) else tau2_raw_h;

    // Running max force tracking
    F_lateral_max = max(pre(F_lateral_max), abs(Fy_meas));
    F_axial_max = max(pre(F_axial_max), abs(Fx_meas));
  end when;

  // ===== Six-axis wrench sensor =====
  // Planar model: Fx and Fy measured; Fz, Mx, My identically zero; Mz nominally zero
  Fx_meas = F_friction_x;
  Fy_meas = F_contact_y + F_dist_y;
  Fz_meas = 0.0;
  Mx_meas = 0.0;
  My_meas = 0.0;
  Mz_meas = 0.0;

  // ===== Monitoring and constraint checks =====
  alignment_error = abs(y_ee - y_hole);
  alignment_ok = time >= 6.5 and alignment_error < alignment_tol;
  insertion_ok = insertion_depth >= insertion_target;
  tilt_ok = abs(peg_tilt) < peg_tilt_limit;
  actuator_ok = abs(tau1_cmd) <= tau_max + 1e-6 and abs(tau2_cmd) <= tau_max + 1e-6;
  lateral_force_ok = F_lateral_max <= F_lateral_limit;
  axial_force_ok = F_axial_max <= F_axial_limit;

  // NaN/infinity check: NaN != NaN in IEEE 754, so self-comparison fails for NaN
  no_nan_inf = (q1 == q1) and (q2 == q2) and (q1d == q1d) and (q2d == q2d) and
              (x_ee == x_ee) and (y_ee == y_ee) and (tau1_cmd == tau1_cmd) and
              (tau2_cmd == tau2_cmd) and (F_cmd_x_h == F_cmd_x_h) and
              (F_cmd_y_h == F_cmd_y_h) and (F_contact_y == F_contact_y) and
              (F_friction_x == F_friction_x);

  annotation(
    experiment(StopTime = 10.0, StartTime = 0.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "PlanarPusherInsertB: 2-DOF planar revolute arm (0.46 m, 0.35 m links)
      performing contact-rich peg-in-hole insertion with 1 mm radial clearance.
      Two joint-torque drives, 41 N.m limit. Contact friction 0.35. Rigid collision model.
      Cartesian impedance control at 100 Hz with bounded insertion speed 0.015 m/s.
      7 N lateral disturbance during middle third (t in [3.33, 6.67] s).
      Insertion target: 0.06 m. Alignment tolerance: 0.002 m after 6.5 s.
      Instrumentation: joint angle/velocity sensing + six-axis contact wrench.
      Parameters not stated in the requirement (inertias, hole location, gains, limits)
      are engineering choices, not specified facts.")
  );
end PlanarPusherInsertB;