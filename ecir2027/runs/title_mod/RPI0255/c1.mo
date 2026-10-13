model FourBarPositionC
  "Closed-chain four-bar mechanism with position control via constrained inverse kinematics"

  // --- Plant geometry (explicit four-bar: A-B-C-D, four revolute Z joints) ---
  parameter Real L_crank(unit = "m") = 0.20 "Crank length (joint A to B)";
  parameter Real L_coupler(unit = "m") = 0.44 "Coupler length (joint B to C)";
  parameter Real L_rocker(unit = "m") = 0.35 "Rocker length (joint D to C)";
  parameter Real L_base(unit = "m") = 0.50 "Fixed pivot separation (joint A to D)";

  // --- Actuator / load limits ---
  parameter Real tau_max(unit = "N.m") = 23.0 "Maximum crank torque";
  parameter Real F_dist(unit = "N") = 12.6 "Platform disturbance load magnitude";

  // --- Link properties ---
  parameter Real m_link(unit = "kg") = 0.5 "Link mass (per link)";
  parameter Real I_diag(unit = "kg.m2") = 0.005 "Link inertia (diagonal)";
  parameter Real I_eff(unit = "kg.m2") = 0.1 "Effective inertia reflected at crank";
  parameter Real b_damp(unit = "N.m.s/rad") = 2.0 "Viscous damping at crank";

  // --- Controller parameters ---
  parameter Real theta_target(unit = "rad") = 1.0471975511966
    "Target crank angle ~60 deg";
  parameter Real kp = 80.0 "Proportional gain";
  parameter Real kd = 8.0 "Derivative gain";
  parameter Real Ts(unit = "s") = 0.008 "Controller sample period (1/125 Hz)";

  // --- Target output pose (from forward kinematics at theta_target) ---
  parameter Real Bx_t = L_crank * cos(theta_target);
  parameter Real By_t = L_crank * sin(theta_target);
  parameter Real BD_t = sqrt(max(1e-10, (Bx_t - L_base) ^ 2 + By_t ^ 2));
  parameter Real cos_beta_t = max(-1.0, min(1.0, (BD_t ^ 2 + L_rocker ^ 2 - L_coupler ^ 2) / (2 * max(1e-10, BD_t * L_rocker))));
  parameter Real beta_t = acos(cos_beta_t);
  parameter Real angle_DB_t = atan2(By_t, Bx_t - L_base);
  parameter Real phi_t = angle_DB_t - beta_t;
  parameter Real Cx_t = L_base + L_rocker * cos(phi_t);
  parameter Real Cy_t = L_rocker * sin(phi_t);
  parameter Real x_target(unit = "m") = (Bx_t + Cx_t) / 2;
  parameter Real y_target(unit = "m") = (By_t + Cy_t) / 2;

  // --- Dynamic states ---
  Real theta(unit = "rad", start = 0.1, fixed = true) "Crank angle (actuated)";
  Real omega(unit = "rad/s", start = 0.0, fixed = true) "Crank angular velocity";

  // --- Kinematic (algebraic) variables ---
  Real phi(unit = "rad") "Rocker angle";
  Real Bx(unit = "m") "Crank tip x (joint B)";
  Real By(unit = "m") "Crank tip y (joint B)";
  Real Cx(unit = "m") "Rocker tip x (joint C)";
  Real Cy(unit = "m") "Rocker tip y (joint C)";
  Real BD(unit = "m") "Distance from B to fixed pivot D";
  Real cos_beta "Cosine of angle BDC";
  Real beta(unit = "rad") "Angle BDC";
  Real angle_DB(unit = "rad") "Angle of DB from D";
  Real phi_d "d(phi)/d(theta) from velocity constraint";
  Real e_x "Coupler direction unit x";
  Real e_y "Coupler direction unit y";

  // --- Output pose ---
  Real x_out(unit = "m") "Output platform x (coupler midpoint)";
  Real y_out(unit = "m") "Output platform y (coupler midpoint)";
  Real pose_error(unit = "m") "Pose tracking error vs target";

  // --- Measured actuator coordinates ---
  Real theta_crank(unit = "rad") "Measured crank angle";
  Real theta_rocker(unit = "rad") "Measured rocker angle";

  // --- Controller signals ---
  Real tau_cmd(unit = "N.m") "Unsaturated torque command";
  Real tau_sat(unit = "N.m") "Saturated torque command";
  Real err_sampled(start = 0.0) "Sampled angle error";
  Real omega_sampled(start = 0.0) "Sampled angular velocity";

  // --- Disturbance ---
  Real Fx_dist(unit = "N") "Disturbance force x-component";
  Real Fy_dist(unit = "N") "Disturbance force y-component";
  Real tau_dist(unit = "N.m") "Generalized disturbance torque on crank";

  // --- Reaction forces at crank pivot A ---
  Real F_react_x(unit = "N") "Reaction force x at crank pivot A";
  Real F_react_y(unit = "N") "Reaction force y at crank pivot A";
  Real alpha_crk(unit = "rad/s2") "Crank angular acceleration (algebraic)";
  Real a_CM_x(unit = "m/s2") "Crank CM acceleration x";
  Real a_CM_y(unit = "m/s2") "Crank CM acceleration y";

  // --- Closure residual ---
  Real closure_residual(unit = "m") "Loop closure residual | |BC| - L_coupler |";

  // --- Self-collision check between crank and rocker ---
  Real t_B "Projection parameter of B onto segment DC";
  Real cp_Bx(unit = "m") "Closest point on DC to B, x";
  Real cp_By(unit = "m") "Closest point on DC to B, y";
  Real dist_B_DC(unit = "m") "Distance from B to rocker segment DC";
  Real t_C "Projection parameter of C onto segment AB";
  Real cp_Cx(unit = "m") "Closest point on AB to C, x";
  Real cp_Cy(unit = "m") "Closest point on AB to C, y";
  Real dist_C_AB(unit = "m") "Distance from C to crank segment AB";
  Real min_link_distance(unit = "m") "Minimum crank-rocker distance";
  Boolean self_collision "Self-collision flag (true if links too close)";

  // --- Safety / monitoring ---
  Boolean no_nan_inf "No NaN/Inf in physical, control, or estimator values";
  Boolean tracking_ok "Tracking error below 0.006 m after 7.8 s";
  Boolean tau_in_bounds "Torque within bounds";
  Boolean force_in_bounds "Disturbance force within bounds";
  Boolean travel_in_bounds "Crank travel within bounds";

  // --- Constants ---
  constant Real eps = 1e-9;
  constant Real eps_len = 1e-6;

equation
  // ===== Joint positions (four revolute Z joints at A, B, C, D) =====
  Bx = L_crank * cos(theta);
  By = L_crank * sin(theta);

  // Rocker angle from loop closure (law of cosines in triangle BDC)
  BD = sqrt(max(eps, (Bx - L_base) ^ 2 + By ^ 2));
  cos_beta = max(-1.0, min(1.0,
    (BD ^ 2 + L_rocker ^ 2 - L_coupler ^ 2) /
    (2 * max(eps, BD * L_rocker))));
  beta = acos(cos_beta);
  angle_DB = atan2(By, Bx - L_base);
  phi = angle_DB - beta;

  Cx = L_base + L_rocker * cos(phi);
  Cy = L_rocker * sin(phi);

  // Coupler direction unit vector (B -> C)
  e_x = (Cx - Bx) / max(eps_len, L_coupler);
  e_y = (Cy - By) / max(eps_len, L_coupler);

  // d(phi)/d(theta) from velocity loop-closure constraint
  phi_d = (L_crank * ((Cy - By) * cos(theta) - (Cx - Bx) * sin(theta))) /
          max(eps, L_rocker * ((Cy - By) * cos(phi) - (Cx - Bx) * sin(phi)));

  // ===== Output pose (coupler midpoint) =====
  x_out = (Bx + Cx) / 2;
  y_out = (By + Cy) / 2;

  // ===== Disturbance force: 12.6 N downward during middle third (4-8 s) =====
  if time >= 4.0 and time <= 8.0 then
    Fx_dist = 0.0;
    Fy_dist = -F_dist;
  else
    Fx_dist = 0.0;
    Fy_dist = 0.0;
  end if;

  // Generalized disturbance torque via Jacobian transpose (virtual work)
  tau_dist = ((-L_crank * sin(theta) - L_rocker * sin(phi) * phi_d) / 2) * Fx_dist +
             ((L_crank * cos(theta) + L_rocker * cos(phi) * phi_d) / 2) * Fy_dist;

  // ===== Sampled PD controller at 125 Hz =====
  when sample(0, Ts) then
    err_sampled = theta_target - theta;
    omega_sampled = omega;
  end when;
  tau_cmd = kp * err_sampled - kd * omega_sampled;
  tau_sat = max(-tau_max, min(tau_max, tau_cmd));

  // ===== Plant dynamics (1-DOF constrained four-bar) =====
  der(theta) = omega;
  I_eff * der(omega) = tau_sat - b_damp * omega + tau_dist;

  // Crank angular acceleration (algebraic, for reaction-force computation)
  alpha_crk = (tau_sat - b_damp * omega + tau_dist) / I_eff;

  // Crank CM acceleration
  a_CM_x = (L_crank / 2) * (-cos(theta) * omega ^ 2 - sin(theta) * alpha_crk);
  a_CM_y = (L_crank / 2) * (-sin(theta) * omega ^ 2 + cos(theta) * alpha_crk);

  // Reaction forces at crank pivot A (crank inertial contribution)
  // NOTE: coupler-force contribution omitted; I_diag retained for completeness
  F_react_x = m_link * a_CM_x;
  F_react_y = m_link * a_CM_y;

  // ===== Measured actuator coordinates =====
  theta_crank = theta;
  theta_rocker = phi;

  // ===== Pose tracking error =====
  pose_error = sqrt(max(0, (x_out - x_target) ^ 2 + (y_out - y_target) ^ 2));

  // ===== Loop closure residual =====
  closure_residual = abs(sqrt(max(0, (Cx - Bx) ^ 2 + (Cy - By) ^ 2)) - L_coupler);

  // ===== Self-collision: minimum distance between crank (AB) and rocker (DC) =====
  // Distance from B to segment DC
  t_B = max(0.0, min(1.0,
    ((Bx - L_base) * (Cx - L_base) + By * Cy) /
    max(eps, (Cx - L_base) ^ 2 + Cy ^ 2)));
  cp_Bx = L_base + t_B * (Cx - L_base);
  cp_By = t_B * Cy;
  dist_B_DC = sqrt(max(0, (Bx - cp_Bx) ^ 2 + (By - cp_By) ^ 2));

  // Distance from C to segment AB
  t_C = max(0.0, min(1.0,
    (Cx * Bx + Cy * By) / max(eps, Bx ^ 2 + By ^ 2)));
  cp_Cx = t_C * Bx;
  cp_Cy = t_C * By;
  dist_C_AB = sqrt(max(0, (Cx - cp_Cx) ^ 2 + (Cy - cp_Cy) ^ 2));

  min_link_distance = min(dist_B_DC, dist_C_AB);
  self_collision = min_link_distance < 0.01;

  // ===== Safety checks =====
  tau_in_bounds = abs(tau_sat) <= tau_max + 1e-6;
  force_in_bounds = abs(Fy_dist) <= F_dist + 1e-6;
  travel_in_bounds = abs(theta) <= 10.0;
  tracking_ok = if time >= 7.8 then pose_error < 0.006 else true;
  no_nan_inf = (abs(x_out) < 1e6) and (abs(y_out) < 1e6) and
               (abs(tau_sat) < 1e6) and (abs(pose_error) < 1e6) and
               (abs(theta_crank) < 1e6) and (abs(theta_rocker) < 1e6) and
               (abs(F_react_x) < 1e6) and (abs(F_react_y) < 1e6) and
               (abs(omega) < 1e6) and (abs(phi) < 1e6) and
               (abs(closure_residual) < 1e6) and
               (abs(min_link_distance) < 1e6);

  annotation(
    Documentation(info = "<html>
<p>Closed-chain four-bar mechanism (A-B-C-D) with constrained inverse kinematics
and PD position control.</p>
<p>Geometry: base=0.50 m, crank=0.20 m, coupler=0.44 m, rocker=0.35 m;
four revolute Z joints at A, B, C, D.</p>
<p>Controller: sampled PD on crank angle at 125 Hz, torque limited to 23 N.m.</p>
<p>Disturbance: 12.6 N downward on coupler midpoint during t=4..8 s.</p>
<p>Requirement: tracking error below 0.006 m after 7.8 s.</p>
</html>"),
    experiment(StopTime = 12.0, Tolerance = 1e-6));
end FourBarPositionC;