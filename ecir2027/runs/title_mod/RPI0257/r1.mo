model FourBarPositionE
  "Four-bar closed-chain robotic mechanism: position control with bounded load"

  // ===== Stated parameters =====
  parameter Real L0(unit="m") = 0.50 "Ground pivot distance";
  parameter Real L1(unit="m") = 0.20 "Crank length";
  parameter Real L2(unit="m") = 0.44 "Coupler length";
  parameter Real L3(unit="m") = 0.35 "Rocker length";
  parameter Real tau_max(unit="N.m") = 27.5 "Crank torque command bound";
  parameter Real F_load(unit="N") = 16.8 "Platform load magnitude";
  parameter Real f_ctrl(unit="Hz") = 250.0 "Controller frequency";
  parameter Real T_end(unit="s") = 16.0 "Simulation duration";
  parameter Real T_settle(unit="s") = 10.4 "Settling time requirement";
  parameter Real e_tol(unit="m") = 0.005 "Pose error tolerance";

  // ===== Assumed parameters (not stated in requirement; labeled) =====
  parameter Real J_crank(unit="kg.m2") = 0.01 "Assumed crank inertia";
  parameter Real b_fric(unit="N.m.s/rad") = 0.02 "Assumed viscous friction";
  parameter Real Kp = 100.0 "Assumed proportional gain [N.m/rad]";
  parameter Real Kd = 15.0 "Assumed derivative gain [N.m.s/rad]";
  parameter Real Ki = 50.0 "Assumed integral gain [N.m/(rad.s)]";
  parameter Real theta1_target(unit="rad") = 1.0 "Target crank angle (nonzero pose)";
  parameter Real theta1_init(unit="rad") = 0.1 "Initial crank angle";
  parameter Real T_ramp_start(unit="s") = 1.0 "Ramp start time";
  parameter Real T_ramp_end(unit="s") = 5.0 "Ramp end time";
  parameter Real theta_travel_max(unit="rad") = 3.14159265358979 "Max crank travel";
  parameter Real F_reaction_max(unit="N") = 500.0 "Max reaction force";
  parameter Real collision_threshold(unit="m") = 0.02 "Min link clearance for self-collision";
  parameter Real Ts = 1.0 / f_ctrl "Controller sample period [s]";

  // ===== Dynamic states =====
  Real theta1(start = theta1_init, unit = "rad") "Crank angle (actuator coordinate 1)";
  Real omega1(start = 0.0, unit = "rad/s") "Crank angular velocity";
  Real alpha1(unit = "rad/s2") "Crank angular acceleration";

  // ===== Forward kinematics (actual mechanism) =====
  Real theta2(unit = "rad") "Coupler angle (actuator coordinate 2)";
  Real theta3(unit = "rad") "Rocker angle (actuator coordinate 3)";
  Real Bx(unit = "m") "Crank end B x-coordinate";
  Real By(unit = "m") "Crank end B y-coordinate";
  Real Cx(unit = "m") "Rocker end C x-coordinate";
  Real Cy(unit = "m") "Rocker end C y-coordinate";
  Real px(unit = "m") "Output platform x position";
  Real py(unit = "m") "Output platform y position";
  Real phi_p(unit = "rad") "Output platform orientation";

  // FK intermediates
  Real A_fk, B_fk, R_fk, C_fk, C_ratio_fk, phi_fk;
  Real dx_cb(unit = "m") "Coupler delta x (C - B)";
  Real dy_cb(unit = "m") "Coupler delta y (C - B)";

  // ===== Jacobian =====
  Real dtheta3_dtheta1 "dtheta3/dtheta1 [rad/rad]";
  Real Jpx(unit = "m/rad") "dpx/dtheta1";
  Real Jpy(unit = "m/rad") "dpy/dtheta1";
  Real M1, M2, den_jac;

  // ===== Reference trajectory and constrained IK =====
  Real ramp "Smooth ramp factor [0..1]";
  Real theta1_ref(unit = "rad") "Reference crank angle";
  Real A_ref, B_ref, R_ref, C_ref, C_ratio_ref, phi_ref, theta3_ref;
  Real px_des(unit = "m") "Desired platform x from FK of reference";
  Real py_des(unit = "m") "Desired platform y from FK of reference";
  Real P_ik, Q_ik, K_ik, R_ik, psi_ik, K_ratio_ik;
  Real theta1_des(unit = "rad") "Desired crank angle from constrained IK";

  // ===== Disturbance =====
  Real dist_active "Disturbance active [0 or 1]";
  Real F_dist_y(unit = "N") "Disturbance force y-component";
  Real tau_load(unit = "N.m") "Load torque reflected to crank";

  // ===== Reaction forces =====
  Real FCx "Coupler-rocker pin force x at C [N]";
  Real FCy "Coupler-rocker pin force y at C [N]";
  Real F_Ax(unit = "N") "Reaction at ground pivot A x";
  Real F_Ay(unit = "N") "Reaction at ground pivot A y";
  Real F_Dx(unit = "N") "Reaction at ground pivot D x";
  Real F_Dy(unit = "N") "Reaction at ground pivot D y";
  Real det_rv "Determinant of reaction-force 2x2 system";

  // ===== Sensors =====
  Real pose_error(unit = "m") "Platform pose error magnitude";
  Real closure_res_x(unit = "m") "Loop closure residual x";
  Real closure_res_y(unit = "m") "Loop closure residual y";
  Real closure_residual(unit = "m") "Total loop closure residual";

  // ===== Self-collision check =====
  Real dist_cr(unit = "m") "Crank midpoint to rocker midpoint distance";
  Real dist_cg(unit = "m") "Coupler midpoint to ground midpoint distance";
  Boolean no_collision "True if no self-collision detected";

  // ===== Acceptance criteria (fail-closed) =====
  Boolean torque_ok "Torque within bounds";
  Boolean travel_ok "Crank travel within bounds";
  Boolean force_ok "Reaction forces within bounds";
  Boolean residual_ok "Closure residual acceptable";
  Boolean pose_ok "Pose error acceptable after settle time";
  Boolean no_nan "No NaN or infinite values";
  Boolean acceptance "Overall fail-closed acceptance";

  // ===== Discrete controller and synchronized traces =====
  discrete Real e_theta(start = 0.0) "Angle error [rad]";
  discrete Real e_theta_int(start = 0.0) "Integral of angle error [rad.s]";
  discrete Real tau_cmd(start = 0.0) "Commanded torque [N.m]";
  discrete Real tau_sat(start = 0.0) "Saturated torque [N.m]";
  discrete Real theta1_log(start = theta1_init) "Crank angle trace [rad]";
  discrete Real tau_log(start = 0.0) "Torque trace [N.m]";
  discrete Real px_log(start = 0.0) "Platform x trace [m]";
  discrete Real py_log(start = 0.0) "Platform y trace [m]";
  discrete Real pose_err_log(start = 0.0) "Pose error trace [m]";
  discrete Real F_A_log(start = 0.0) "Reaction A magnitude trace [N]";
  discrete Real F_D_log(start = 0.0) "Reaction D magnitude trace [N]";

equation
  // ===== State derivative relations =====
  der(theta1) = omega1;
  der(omega1) = alpha1;

  // ===== Forward kinematics: planar four-bar with four revolute Z joints =====
  // Ground pivots: A at (0,0), D at (L0,0). Rigid base geometry.
  // Crank AB (length L1), coupler BC (length L2), rocker DC (length L3).
  Bx = L1 * cos(theta1);
  By = L1 * sin(theta1);

  // Analytical loop closure: solve for rocker angle theta3
  A_fk = L0 - L1 * cos(theta1);
  B_fk = -L1 * sin(theta1);
  R_fk = sqrt(A_fk * A_fk + B_fk * B_fk);
  C_fk = (L2 * L2 - A_fk * A_fk - B_fk * B_fk - L3 * L3) / (2.0 * L3);
  C_ratio_fk = max(-0.9999, min(0.9999, C_fk / max(R_fk, 1e-12)));
  phi_fk = atan2(B_fk, A_fk);
  theta3 = phi_fk + acos(C_ratio_fk);

  // Rocker end point C
  Cx = L0 + L3 * cos(theta3);
  Cy = L3 * sin(theta3);

  // Coupler angle theta2 from B and C
  dx_cb = Cx - Bx;
  dy_cb = Cy - By;
  theta2 = atan2(dy_cb, dx_cb);

  // Output platform at coupler midpoint
  px = 0.5 * (Bx + Cx);
  py = 0.5 * (By + Cy);
  phi_p = theta2;

  // Loop closure residual (verification of kinematic consistency)
  closure_res_x = Bx + L2 * cos(theta2) - Cx;
  closure_res_y = By + L2 * sin(theta2) - Cy;
  closure_residual = sqrt(closure_res_x * closure_res_x + closure_res_y * closure_res_y);

  // ===== Jacobian: d(theta3)/d(theta1) via implicit differentiation =====
  M1 = A_fk + L3 * cos(theta3);
  M2 = B_fk + L3 * sin(theta3);
  den_jac = L3 * (B_fk * cos(theta3) - A_fk * sin(theta3));
  dtheta3_dtheta1 = -L1 * (M1 * sin(theta1) - M2 * cos(theta1)) / (den_jac + 1e-12);
  Jpx = 0.5 * (-L1 * sin(theta1) - L3 * sin(theta3) * dtheta3_dtheta1);
  Jpy = 0.5 * (L1 * cos(theta1) + L3 * cos(theta3) * dtheta3_dtheta1);

  // ===== Reference trajectory (smooth cosine ramp) =====
  ramp = if time <= T_ramp_start then 0.0
         else if time >= T_ramp_end then 1.0
         else 0.5 * (1.0 - cos(Modelica.Constants.pi * (time - T_ramp_start) / (T_ramp_end - T_ramp_start)));
  theta1_ref = theta1_init + ramp * (theta1_target - theta1_init);

  // FK of reference angle to obtain desired platform pose
  A_ref = L0 - L1 * cos(theta1_ref);
  B_ref = -L1 * sin(theta1_ref);
  R_ref = sqrt(A_ref * A_ref + B_ref * B_ref);
  C_ref = (L2 * L2 - A_ref * A_ref - B_ref * B_ref - L3 * L3) / (2.0 * L3);
  C_ratio_ref = max(-0.9999, min(0.9999, C_ref / max(R_ref, 1e-12)));
  phi_ref = atan2(B_ref, A_ref);
  theta3_ref = phi_ref + acos(C_ratio_ref);
  px_des = 0.5 * (L1 * cos(theta1_ref) + L0 + L3 * cos(theta3_ref));
  py_des = 0.5 * (L1 * sin(theta1_ref) + L3 * sin(theta3_ref));

  // Constrained inverse kinematics: desired pose -> desired crank angle
  // Platform at coupler midpoint => C = 2*M - B; C constrained to rocker circle
  P_ik = 2.0 * px_des - L0;
  Q_ik = 2.0 * py_des;
  K_ik = (P_ik * P_ik + L1 * L1 + Q_ik * Q_ik - L3 * L3) / (2.0 * L1);
  R_ik = sqrt(P_ik * P_ik + Q_ik * Q_ik);
  psi_ik = atan2(Q_ik, P_ik);
  K_ratio_ik = max(-0.9999, min(0.9999, K_ik / max(R_ik, 1e-12)));
  theta1_des = psi_ik - acos(K_ratio_ik);

  // ===== Disturbance: 16.8 N downward load during middle third of simulation =====
  dist_active = if (time >= T_end / 3.0 and time <= 2.0 * T_end / 3.0) then 1.0 else 0.0;
  F_dist_y = -F_load * dist_active;
  // Load torque reflected to crank via Jacobian (principle of virtual work)
  tau_load = F_load * dist_active * Jpy;

  // ===== Crank dynamics =====
  J_crank * alpha1 = tau_sat - b_fric * omega1 - tau_load;

  // ===== Reaction forces from link static equilibrium =====
  // Coupler massless with load at midpoint; crank has inertia J_crank
  // 2x2 linear system: coupler moment about B + crank torque balance about A
  det_rv = L1 * (dx_cb * sin(theta1) - dy_cb * cos(theta1));
  FCx = dx_cb * (tau_sat - J_crank * alpha1 + 0.5 * F_dist_y * L1 * cos(theta1)) / (det_rv + 1e-12);
  FCy = (-dy_cb * (J_crank * alpha1 - tau_sat - L1 * cos(theta1) * F_dist_y)
         - 0.5 * L1 * sin(theta1) * dx_cb * F_dist_y) / (det_rv + 1e-12);
  F_Ax = -FCx;
  F_Ay = -FCy - F_dist_y;
  F_Dx = FCx;
  F_Dy = FCy;

  // ===== Pose error sensor =====
  pose_error = sqrt((px_des - px) * (px_des - px) + (py_des - py) * (py_des - py));

  // ===== Self-collision checks =====
  // Crank midpoint vs rocker midpoint
  dist_cr = sqrt((0.5 * Bx - (L0 + 0.5 * L3 * cos(theta3))) ** 2
                 + (0.5 * By - 0.5 * L3 * sin(theta3)) ** 2);
  // Coupler midpoint vs ground midpoint
  dist_cg = sqrt((px - 0.5 * L0) ** 2 + py ** 2);
  no_collision = (dist_cr > collision_threshold) and (dist_cg > collision_threshold)
                and (By > 0.0) and (Cy > 0.0);

  // ===== Acceptance criteria (fail-closed: AND of all checks) =====
  torque_ok = abs(tau_sat) <= tau_max + 1e-6;
  travel_ok = abs(theta1) <= theta_travel_max;
  force_ok = (abs(F_Ax) <= F_reaction_max) and (abs(F_Ay) <= F_reaction_max)
             and (abs(F_Dx) <= F_reaction_max) and (abs(F_Dy) <= F_reaction_max);
  residual_ok = closure_residual < 1e-6;
  pose_ok = if time >= T_settle then pose_error < e_tol else true;
  no_nan = (abs(theta1) < 1e10) and (abs(omega1) < 1e10) and (abs(tau_sat) < 1e10)
           and (abs(px) < 1e10) and (abs(py) < 1e10) and (abs(pose_error) < 1e10)
           and (abs(F_Ax) < 1e10) and (abs(F_Ay) < 1e10)
           and (abs(F_Dx) < 1e10) and (abs(F_Dy) < 1e10);
  acceptance = torque_ok and travel_ok and force_ok and residual_ok
               and pose_ok and no_nan and no_collision;

  // ===== Discrete PID controller at 250 Hz =====
  when sample(0, Ts) then
    e_theta = theta1_des - theta1;
    e_theta_int = pre(e_theta_int) + e_theta * Ts;
    tau_cmd = Kp * e_theta + Ki * e_theta_int
              + Kd * (e_theta - pre(e_theta)) / (Ts + 1e-12);
    tau_sat = if tau_cmd > tau_max then tau_max
              else if tau_cmd < -tau_max then -tau_max
              else tau_cmd;
    // Synchronized state, command, and sensor traces
    theta1_log = theta1;
    tau_log = tau_sat;
    px_log = px;
    py_log = py;
    pose_err_log = pose_error;
    F_A_log = sqrt(F_Ax * F_Ax + F_Ay * F_Ay);
    F_D_log = sqrt(F_Dx * F_Dx + F_Dy * F_Dy);
  end when;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6),
    Documentation(info = "Four-bar planar closed-chain mechanism FourBarPositionE.
      Ground pivots A(0,0) and D(0.50,0) m apart. Rigid base geometry.
      Crank L1=0.20 m, coupler L2=0.44 m, rocker L3=0.35 m.
      Four revolute Z joints (planar). Crank torque bounded at 27.5 N.m.
      Platform load 16.8 N downward during middle third (5.33-10.67 s).
      PID controller at 250 Hz with constrained inverse kinematics.
      Self-collision checks: crank-rocker and coupler-ground distances.
      Acceptance: torque/travel/force bounds, closure residuals < 1e-6 m,
      pose error < 0.005 m after 10.4 s, no NaN/Inf, no self-collision.
      Parameters not stated in requirement (J_crank, b_fric, gains, target angle,
      ramp times, force/travel/collision bounds) are assumed and labeled as such.")
  );
end FourBarPositionE;