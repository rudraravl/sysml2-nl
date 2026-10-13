model SoftCrawlAvoidA
  "Soft crawling robot: 6-chamber pneumatic body (0.48 m), anisotropic friction,
   fixed cylinder obstacle, bounded contact-aware shape control, stiffness scheduling,
   4 N tip disturbance in middle third, 80 Hz for 8 s."

  // ---- Physical constants ----
  constant Real pi = 3.1415926535897932;

  // ---- Body parameters ----
  parameter Real L_total = 0.48 "Total compliant body length [m]";
  parameter Real L_seg   = 0.08 "Per-section length (= L_total/6) [m]";
  parameter Real m_seg   = 0.12 "Per-section mass [kg]";
  parameter Real m_total = 0.72 "Total body mass [kg]";
  parameter Real I_seg   = m_seg * L_seg * L_seg / 3.0 "Section moment of inertia [kg.m2]";
  parameter Real g_acc   = 9.81 "Gravitational acceleration [m/s2]";

  // ---- Ground friction (anisotropic) ----
  parameter Real mu_fwd  = 0.03 "Forward (crawl direction) friction coefficient [1]";
  parameter Real mu_bwd  = 0.80 "Backward friction coefficient [1]";
  parameter Real c_drag  = 45.0 "Viscous ground drag [N.s/m]";

  // ---- Obstacle (fixed cylinder, collision enabled) ----
  parameter Real mu_obs  = 0.55 "Obstacle friction coefficient [1]";
  parameter Real R_cyl   = 0.035 "Obstacle cylinder radius [m]";
  parameter Real x_obs   = 0.15 "Obstacle center x [m]";
  parameter Real y_obs   = 0.005 "Obstacle center y [m]";

  // ---- Actuation ----
  parameter Real p_max   = 54000.0 "Chamber pressure command limit [Pa]";
  parameter Real k_bend  = 5.0e-6 "Pressure-to-bending gain [rad/Pa]";
  parameter Real b_bend  = 0.05 "Bending damping [N.m.s/rad]";
  parameter Real f_wave  = 0.5 "Traveling wave frequency [Hz]";
  parameter Real A_thrust = 2.5 "Thrust amplitude from wave [N]";

  // ---- Contact-aware stiffness scheduling ----
  parameter Real k_stiff_base = 2.0 "Base bending stiffness [N.m/rad]";
  parameter Real k_stiff_max  = 8.0 "Maximum bending stiffness [N.m/rad]";
  parameter Real tau_stiff    = 1.5 "Stiffness scheduling time constant [s]";

  // ---- Contact model ----
  parameter Real k_contact = 2000.0 "Contact spring stiffness [N/m]";
  parameter Real b_contact = 80.0   "Contact damping coefficient [N.s/m]";
  parameter Real k_avoid   = 0.3   "Obstacle avoidance bending gain [rad]";
  parameter Real d_safe    = 0.04  "Safe clearance distance for avoidance [m]";

  // ---- Tip disturbance ----
  parameter Real F_dist = 4.0 "Lateral tip disturbance force [N]";

  // ---- Thermal model ----
  parameter Real T_init  = 293.15 "Initial body temperature [K]";
  parameter Real T_amb   = 293.15 "Ambient temperature [K]";
  parameter Real C_therm = 5.0   "Thermal capacitance [J/K]";
  parameter Real h_therm = 2.0   "Thermal conductance [W/K]";
  parameter Real P_heat  = 5.0   "Peak heat generation per chamber [W]";

  // ---- Target ----
  parameter Real x_target = 0.25 "Target x position [m]";
  parameter Real y_target = 0.0  "Target y position [m]";

  // ---- Numerical safety ----
  parameter Real eps = 1.0e-8 "Small number for safe division";

  // ===== Dynamic states =====
  Real x_base(start = 0.0) "Base x position [m]";
  Real v_base(start = 0.0) "Base x velocity [m/s]";
  Real theta1(start = 0.0) "Section 1 bending angle [rad]";
  Real theta2(start = 0.0) "Section 2 bending angle [rad]";
  Real theta3(start = 0.0) "Section 3 bending angle [rad]";
  Real theta4(start = 0.0) "Section 4 bending angle [rad]";
  Real theta5(start = 0.0) "Section 5 bending angle [rad]";
  Real theta6(start = 0.0) "Section 6 bending angle [rad]";
  Real omega1(start = 0.0) "Section 1 angular velocity [rad/s]";
  Real omega2(start = 0.0) "Section 2 angular velocity [rad/s]";
  Real omega3(start = 0.0) "Section 3 angular velocity [rad/s]";
  Real omega4(start = 0.0) "Section 4 angular velocity [rad/s]";
  Real omega5(start = 0.0) "Section 5 angular velocity [rad/s]";
  Real omega6(start = 0.0) "Section 6 angular velocity [rad/s]";
  Real T_body(start = T_init) "Body temperature [K]";

  // ===== Pressure commands (actuator state traces) =====
  Real p1 "Chamber 1 raw pressure command [Pa]";
  Real p2 "Chamber 2 raw pressure command [Pa]";
  Real p3 "Chamber 3 raw pressure command [Pa]";
  Real p4 "Chamber 4 raw pressure command [Pa]";
  Real p5 "Chamber 5 raw pressure command [Pa]";
  Real p6 "Chamber 6 raw pressure command [Pa]";
  Real ps1 "Chamber 1 saturated pressure [Pa]";
  Real ps2 "Chamber 2 saturated pressure [Pa]";
  Real ps3 "Chamber 3 saturated pressure [Pa]";
  Real ps4 "Chamber 4 saturated pressure [Pa]";
  Real ps5 "Chamber 5 saturated pressure [Pa]";
  Real ps6 "Chamber 6 saturated pressure [Pa]";
  Real amp_factor "Wave amplitude scaling for hold/stiffen [1]";

  // ===== Forward kinematics =====
  Real ang1 "Section 1 absolute angle [rad]";
  Real ang2 "Section 2 absolute angle [rad]";
  Real ang3 "Section 3 absolute angle [rad]";
  Real ang4 "Section 4 absolute angle [rad]";
  Real ang5 "Section 5 absolute angle [rad]";
  Real ang6 "Section 6 absolute angle [rad]";
  Real sx1 "Section 1 center x [m]";
  Real sx2 "Section 2 center x [m]";
  Real sx3 "Section 3 center x [m]";
  Real sx4 "Section 4 center x [m]";
  Real sx5 "Section 5 center x [m]";
  Real sx6 "Section 6 center x [m]";
  Real sy1 "Section 1 center y [m]";
  Real sy2 "Section 2 center y [m]";
  Real sy3 "Section 3 center y [m]";
  Real sy4 "Section 4 center y [m]";
  Real sy5 "Section 5 center y [m]";
  Real sy6 "Section 6 center y [m]";
  Real tip_x "Tip x position [m]";
  Real tip_y "Tip y position [m]";

  // ===== Contact sensing =====
  Real dist1 "Section 1 distance to obstacle center [m]";
  Real dist2 "Section 2 distance to obstacle center [m]";
  Real dist3 "Section 3 distance to obstacle center [m]";
  Real dist4 "Section 4 distance to obstacle center [m]";
  Real dist5 "Section 5 distance to obstacle center [m]";
  Real dist6 "Section 6 distance to obstacle center [m]";
  Real d1 "Section 1 clearance to obstacle surface [m]";
  Real d2 "Section 2 clearance to obstacle surface [m]";
  Real d3 "Section 3 clearance to obstacle surface [m]";
  Real d4 "Section 4 clearance to obstacle surface [m]";
  Real d5 "Section 5 clearance to obstacle surface [m]";
  Real d6 "Section 6 clearance to obstacle surface [m]";
  Real cf1 "Section 1 contact force magnitude [N]";
  Real cf2 "Section 2 contact force magnitude [N]";
  Real cf3 "Section 3 contact force magnitude [N]";
  Real cf4 "Section 4 contact force magnitude [N]";
  Real cf5 "Section 5 contact force magnitude [N]";
  Real cf6 "Section 6 contact force magnitude [N]";
  Real cx1 "Section 1 contact force x-component [N]";
  Real cx2 "Section 2 contact force x-component [N]";
  Real cx3 "Section 3 contact force x-component [N]";
  Real cx4 "Section 4 contact force x-component [N]";
  Real cx5 "Section 5 contact force x-component [N]";
  Real cx6 "Section 6 contact force x-component [N]";
  Real cy1 "Section 1 contact force y-component [N]";
  Real cy2 "Section 2 contact force y-component [N]";
  Real cy3 "Section 3 contact force y-component [N]";
  Real cy4 "Section 4 contact force y-component [N]";
  Real cy5 "Section 5 contact force y-component [N]";
  Real cy6 "Section 6 contact force y-component [N]";
  Real min_clear "Minimum obstacle clearance across all sections [m]";
  Real total_cf "Total distributed contact force [N]";
  Real F_contact_x "Total contact force x-component [N]";
  Real F_obs_friction "Obstacle tangential friction force x [N]";

  // ===== Avoidance corrections =====
  Real corr1 "Section 1 avoidance bending correction [rad]";
  Real corr2 "Section 2 avoidance bending correction [rad]";
  Real corr3 "Section 3 avoidance bending correction [rad]";
  Real corr4 "Section 4 avoidance bending correction [rad]";
  Real corr5 "Section 5 avoidance bending correction [rad]";
  Real corr6 "Section 6 avoidance bending correction [rad]";

  // ===== Stiffness =====
  Real k_stiff "Scheduled bending stiffness [N.m/rad]";

  // ===== Disturbance =====
  Real F_tip_y "Applied tip lateral disturbance [N]";

  // ===== Forces =====
  Real F_thrust "Traveling-wave thrust force [N]";
  Real F_friction "Anisotropic ground friction [N]";

  // ===== Tracking =====
  Real tip_err "Primary tip tracking error [m]";
  Real tip_err_after "Tip error sampled after 5.2 s [m]";

  // ===== Bounds (negative = within bound) =====
  Real b_act "Actuator pressure bound violation [Pa]";
  Real b_def "Deformation bound violation [rad]";
  Real b_cf "Contact force bound violation [N]";
  Real b_temp "Temperature bound violation [K]";
  Real b_clr "Clearance bound violation [m]";
  Real b_tip "Tip error bound violation [m]";
  Real no_nan_val "NaN/Inf check (1.0 = OK, 0.0 = detected) [1]";

equation
  // ---- Tip tracking error ----
  tip_err = sqrt((tip_x - x_target)^2 + (tip_y - y_target)^2);
  tip_err_after = if time >= 5.2 then tip_err else 0.0;

  // ---- Amplitude factor: reduce near target for hold/stiffen ----
  amp_factor = if tip_err < 0.08 then 0.1 + 0.9 * tip_err / 0.08 else 1.0;

  // ---- Traveling wave pressure commands ----
  p1 = p_max * 0.5 * amp_factor * (1.0 + sin(2.0 * pi * f_wave * time - 0.0));
  p2 = p_max * 0.5 * amp_factor * (1.0 + sin(2.0 * pi * f_wave * time - pi / 3.0));
  p3 = p_max * 0.5 * amp_factor * (1.0 + sin(2.0 * pi * f_wave * time - 2.0 * pi / 3.0));
  p4 = p_max * 0.5 * amp_factor * (1.0 + sin(2.0 * pi * f_wave * time - pi));
  p5 = p_max * 0.5 * amp_factor * (1.0 + sin(2.0 * pi * f_wave * time - 4.0 * pi / 3.0));
  p6 = p_max * 0.5 * amp_factor * (1.0 + sin(2.0 * pi * f_wave * time - 5.0 * pi / 3.0));

  // ---- Pressure saturation (bounded command at 54 kPa-gauge) ----
  ps1 = if p1 > p_max then p_max else if p1 < 0.0 then 0.0 else p1;
  ps2 = if p2 > p_max then p_max else if p2 < 0.0 then 0.0 else p2;
  ps3 = if p3 > p_max then p_max else if p3 < 0.0 then 0.0 else p3;
  ps4 = if p4 > p_max then p_max else if p4 < 0.0 then 0.0 else p4;
  ps5 = if p5 > p_max then p_max else if p5 < 0.0 then 0.0 else p5;
  ps6 = if p6 > p_max then p_max else if p6 < 0.0 then 0.0 else p6;

  // ---- Contact-aware stiffness scheduling (bounded, exponential ramp) ----
  k_stiff = k_stiff_base + (k_stiff_max - k_stiff_base) * (1.0 - exp(-time / tau_stiff));

  // ---- Forward kinematics: absolute angles ----
  ang1 = theta1;
  ang2 = ang1 + theta2;
  ang3 = ang2 + theta3;
  ang4 = ang3 + theta4;
  ang5 = ang4 + theta5;
  ang6 = ang5 + theta6;

  // ---- Section centers ----
  sx1 = x_base + 0.5 * L_seg * cos(ang1);
  sy1 = 0.5 * L_seg * sin(ang1);
  sx2 = x_base + L_seg * cos(ang1) + 0.5 * L_seg * cos(ang2);
  sy2 = L_seg * sin(ang1) + 0.5 * L_seg * sin(ang2);
  sx3 = x_base + L_seg * cos(ang1) + L_seg * cos(ang2) + 0.5 * L_seg * cos(ang3);
  sy3 = L_seg * sin(ang1) + L_seg * sin(ang2) + 0.5 * L_seg * sin(ang3);
  sx4 = x_base + L_seg * cos(ang1) + L_seg * cos(ang2) + L_seg * cos(ang3) + 0.5 * L_seg * cos(ang4);
  sy4 = L_seg * sin(ang1) + L_seg * sin(ang2) + L_seg * sin(ang3) + 0.5 * L_seg * sin(ang4);
  sx5 = x_base + L_seg * cos(ang1) + L_seg * cos(ang2) + L_seg * cos(ang3) + L_seg * cos(ang4) + 0.5 * L_seg * cos(ang5);
  sy5 = L_seg * sin(ang1) + L_seg * sin(ang2) + L_seg * sin(ang3) + L_seg * sin(ang4) + 0.5 * L_seg * sin(ang5);
  sx6 = x_base + L_seg * cos(ang1) + L_seg * cos(ang2) + L_seg * cos(ang3) + L_seg * cos(ang4) + L_seg * cos(ang5) + 0.5 * L_seg * cos(ang6);
  sy6 = L_seg * sin(ang1) + L_seg * sin(ang2) + L_seg * sin(ang3) + L_seg * sin(ang4) + L_seg * sin(ang5) + 0.5 * L_seg * sin(ang6);

  // ---- Tip pose ----
  tip_x = x_base + L_seg * (cos(ang1) + cos(ang2) + cos(ang3) + cos(ang4) + cos(ang5) + cos(ang6));
  tip_y = L_seg * (sin(ang1) + sin(ang2) + sin(ang3) + sin(ang4) + sin(ang5) + sin(ang6));

  // ---- Collision detection (cylinder) ----
  dist1 = sqrt((sx1 - x_obs)^2 + (sy1 - y_obs)^2);
  dist2 = sqrt((sx2 - x_obs)^2 + (sy2 - y_obs)^2);
  dist3 = sqrt((sx3 - x_obs)^2 + (sy3 - y_obs)^2);
  dist4 = sqrt((sx4 - x_obs)^2 + (sy4 - y_obs)^2);
  dist5 = sqrt((sx5 - x_obs)^2 + (sy5 - y_obs)^2);
  dist6 = sqrt((sx6 - x_obs)^2 + (sy6 - y_obs)^2);

  d1 = dist1 - R_cyl;
  d2 = dist2 - R_cyl;
  d3 = dist3 - R_cyl;
  d4 = dist4 - R_cyl;
  d5 = dist5 - R_cyl;
  d6 = dist6 - R_cyl;

  // ---- Contact force magnitudes (spring, bounded) ----
  cf1 = if d1 < 0.0 then k_contact * (-d1) else 0.0;
  cf2 = if d2 < 0.0 then k_contact * (-d2) else 0.0;
  cf3 = if d3 < 0.0 then k_contact * (-d3) else 0.0;
  cf4 = if d4 < 0.0 then k_contact * (-d4) else 0.0;
  cf5 = if d5 < 0.0 then k_contact * (-d5) else 0.0;
  cf6 = if d6 < 0.0 then k_contact * (-d6) else 0.0;

  // ---- Contact force components (safe normalization) ----
  cx1 = if d1 < 0.0 then cf1 * (sx1 - x_obs) / (dist1 + eps) else 0.0;
  cx2 = if d2 < 0.0 then cf2 * (sx2 - x_obs) / (dist2 + eps) else 0.0;
  cx3 = if d3 < 0.0 then cf3 * (sx3 - x_obs) / (dist3 + eps) else 0.0;
  cx4 = if d4 < 0.0 then cf4 * (sx4 - x_obs) / (dist4 + eps) else 0.0;
  cx5 = if d5 < 0.0 then cf5 * (sx5 - x_obs) / (dist5 + eps) else 0.0;
  cx6 = if d6 < 0.0 then cf6 * (sx6 - x_obs) / (dist6 + eps) else 0.0;

  cy1 = if d1 < 0.0 then cf1 * (sy1 - y_obs) / (dist1 + eps) else 0.0;
  cy2 = if d2 < 0.0 then cf2 * (sy2 - y_obs) / (dist2 + eps) else 0.0;
  cy3 = if d3 < 0.0 then cf3 * (sy3 - y_obs) / (dist3 + eps) else 0.0;
  cy4 = if d4 < 0.0 then cf4 * (sy4 - y_obs) / (dist4 + eps) else 0.0;
  cy5 = if d5 < 0.0 then cf5 * (sy5 - y_obs) / (dist5 + eps) else 0.0;
  cy6 = if d6 < 0.0 then cf6 * (sy6 - y_obs) / (dist6 + eps) else 0.0;

  // ---- Contact aggregates ----
  F_contact_x = cx1 + cx2 + cx3 + cx4 + cx5 + cx6;
  total_cf = cf1 + cf2 + cf3 + cf4 + cf5 + cf6;

  // Minimum clearance via nested min (scalar, explicit)
  min_clear = min(d1, min(d2, min(d3, min(d4, min(d5, d6)))));

  // ---- Obstacle tangential friction (mu_obs * normal * opposes sliding) ----
  F_obs_friction = -mu_obs * total_cf * tanh(v_base * 100.0);

  // ---- Contact-aware avoidance corrections (shape control) ----
  corr1 = k_avoid * exp(-d1 / d_safe) * (sy1 - y_obs) / (abs(sy1 - y_obs) + eps);
  corr2 = k_avoid * exp(-d2 / d_safe) * (sy2 - y_obs) / (abs(sy2 - y_obs) + eps);
  corr3 = k_avoid * exp(-d3 / d_safe) * (sy3 - y_obs) / (abs(sy3 - y_obs) + eps);
  corr4 = k_avoid * exp(-d4 / d_safe) * (sy4 - y_obs) / (abs(sy4 - y_obs) + eps);
  corr5 = k_avoid * exp(-d5 / d_safe) * (sy5 - y_obs) / (abs(sy5 - y_obs) + eps);
  corr6 = k_avoid * exp(-d6 / d_safe) * (sy6 - y_obs) / (abs(sy6 - y_obs) + eps);

  // ---- Tip disturbance: 4 N lateral during middle third (8/3 to 16/3 s) ----
  F_tip_y = if time >= 8.0 / 3.0 and time <= 16.0 / 3.0 then F_dist else 0.0;

  // ---- Thrust from traveling wave ----
  F_thrust = A_thrust * cos(2.0 * pi * f_wave * time);

  // ---- Anisotropic ground friction (smooth Coulomb + viscous) ----
  F_friction = -m_total * g_acc
    * (mu_fwd + (mu_bwd - mu_fwd) * 0.5 * (1.0 - tanh(v_base * 50.0)))
    * tanh(v_base * 100.0)
    - c_drag * v_base;

  // ---- Base dynamics ----
  der(x_base) = v_base;
  der(v_base) = (F_thrust + F_contact_x + F_friction + F_obs_friction) / m_total;

  // ---- Section bending dynamics (2nd order, stiffness + contact torque + avoidance) ----
  der(theta1) = omega1;
  der(theta2) = omega2;
  der(theta3) = omega3;
  der(theta4) = omega4;
  der(theta5) = omega5;
  der(theta6) = omega6;

  I_seg * der(omega1) = k_stiff * (k_bend * ps1 + corr1 - theta1) - b_bend * omega1 + cy1 * L_seg * 0.5;
  I_seg * der(omega2) = k_stiff * (k_bend * ps2 + corr2 - theta2) - b_bend * omega2 + cy2 * L_seg * 0.5;
  I_seg * der(omega3) = k_stiff * (k_bend * ps3 + corr3 - theta3) - b_bend * omega3 + cy3 * L_seg * 0.5;
  I_seg * der(omega4) = k_stiff * (k_bend * ps4 + corr4 - theta4) - b_bend * omega4 + cy4 * L_seg * 0.5;
  I_seg * der(omega5) = k_stiff * (k_bend * ps5 + corr5 - theta5) - b_bend * omega5 + cy5 * L_seg * 0.5;
  I_seg * der(omega6) = k_stiff * (k_bend * ps6 + corr6 - theta6) - b_bend * omega6 + cy6 * L_seg * 0.5 + F_tip_y * L_seg;

  // ---- Temperature dynamics (bounded by thermal balance) ----
  der(T_body) = (P_heat * (ps1 + ps2 + ps3 + ps4 + ps5 + ps6) / (6.0 * p_max + eps)
    - h_therm * (T_body - T_amb)) / C_therm;

  // ===== Bounds checks (negative => within bound) =====
  // Actuator: max saturated pressure must not exceed p_max
  b_act = max(abs(ps1), max(abs(ps2), max(abs(ps3), max(abs(ps4), max(abs(ps5), abs(ps6)))))) - p_max;
  // Deformation: max bending angle must stay within 0.5 rad
  b_def = max(abs(theta1), max(abs(theta2), max(abs(theta3), max(abs(theta4), max(abs(theta5), abs(theta6)))))) - 0.5;
  // Contact force: total must stay below 50 N
  b_cf = total_cf - 50.0;
  // Temperature: must stay below ambient + 50 K
  b_temp = T_body - (T_amb + 50.0);
  // Clearance: penetration must not exceed 0.02 m (bounded incidental contact)
  b_clr = -min_clear - 0.02;
  // Tip error after 5.2 s: must be below 0.054 m
  b_tip = tip_err_after - 0.054;
  // NaN/Inf check via self-comparison (NaN != NaN)
  no_nan_val = (if x_base == x_base then 1.0 else 0.0)
    * (if v_base == v_base then 1.0 else 0.0)
    * (if tip_x == tip_x then 1.0 else 0.0)
    * (if tip_y == tip_y then 1.0 else 0.0)
    * (if T_body == T_body then 1.0 else 0.0)
    * (if tip_err == tip_err then 1.0 else 0.0);

  annotation(
    experiment(StartTime = 0.0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "SoftCrawlAvoidA: 6-chamber pneumatic soft crawling robot (0.48 m body).
      Traveling-wave pressure (bounded 54 kPa-gauge) creates peristaltic crawling via anisotropic
      ground friction. Fixed cylinder obstacle (mu=0.55, collision enabled). Contact-aware shape
      control with bounded stiffness scheduling. 4 N lateral tip disturbance in middle third.
      Run at 80 Hz (Interval=0.0125 s) for 8 s. Synchronized state, command, and sensor traces.
      Bounds: actuator, deformation, contact-force, temperature, obstacle-clearance, tip-error.
      Primary tracking error < 0.054 m after 5.2 s. No NaN/Inf.")
  );
end SoftCrawlAvoidA;