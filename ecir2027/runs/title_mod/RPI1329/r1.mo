model TendonSoftGraspC
  "Soft robotic tendon-driven grasp with contact-force redistribution"

  // ===== Requirement-specified parameters =====
  parameter Real L_body(unit="m") = 0.55 "Continuum body length";
  parameter Integer n_sec = 6 "Number of constant-curvature sections";
  parameter Real L_sec(unit="m") = L_body/n_sec "Section length";
  parameter Real T_max(unit="N") = 38.6 "Maximum tendon command magnitude";
  parameter Real F_dist(unit="N") = 3.6 "Tangential disturbance load";
  parameter Real mu = 0.70 "Friction coefficient on rigid support";
  parameter Real f_sample(unit="Hz") = 125.0 "Control sampling rate";
  parameter Real dt_s(unit="s") = 1.0/f_sample "Sample period";
  parameter Real t_sim(unit="s") = 12.0 "Total simulation time";
  parameter Real t_dist_start(unit="s") = t_sim/3.0 "Disturbance start (middle third)";
  parameter Real t_dist_end(unit="s") = 2.0*t_sim/3.0 "Disturbance end (middle third)";
  parameter Real track_err_thresh(unit="m") = 0.016 "Tracking error threshold";
  parameter Real t_track(unit="s") = 7.8 "Tracking evaluation time";

  // Tendon geometry: 120-degree spacing
  parameter Real theta1(unit="rad") = 0.0 "Tendon 1 angular position";
  parameter Real theta2(unit="rad") = 2.0943951023932 "Tendon 2 angular position (120 deg)";
  parameter Real theta3(unit="rad") = 4.1887902047864 "Tendon 3 angular position (240 deg)";
  parameter Real c1 = abs(cos(theta1)) "Tendon 1 coupling magnitude in grasp direction";
  parameter Real c2 = abs(cos(theta2)) "Tendon 2 coupling magnitude";
  parameter Real c3 = abs(cos(theta3)) "Tendon 3 coupling magnitude";

  // ===== Design parameters (not specified in requirement) =====
  parameter Real r_tendon(unit="m") = 0.012 "Tendon moment arm -- design choice";
  parameter Real EI_body(unit="N.m^2") = 0.04 "Flexural rigidity -- design choice";
  parameter Real c_t = r_tendon/EI_body "Base tendon-curvature coupling [1/(N.m)]";
  parameter Real k_contact(unit="N/m") = 120.0 "Contact stiffness -- design choice";
  parameter Real m_obj(unit="kg") = 0.15 "Object mass -- design choice";
  parameter Real g_acc(unit="m/s^2") = 9.81 "Gravitational acceleration";
  parameter Real tau_curv(unit="s") = 0.03 "Curvature response time constant -- design choice";
  parameter Real tau_tendon(unit="s") = 0.015 "Tendon actuator time constant -- design choice";
  parameter Real kappa_max(unit="1/m") = 8.0 "Maximum allowable curvature -- design choice";
  parameter Real kappa_contact(unit="1/m") = 0.5 "Curvature threshold for contact -- design choice";
  parameter Real F_des_nom(unit="N") = 3.0 "Nominal desired total normal force -- design choice";
  parameter Real F_des_max(unit="N") = 15.0 "Maximum desired total normal force -- design choice";
  parameter Real F_max_contact(unit="N") = 3.5 "Maximum per-contact force -- design choice";
  parameter Real F_total_min(unit="N") = 1.0 "Minimum total force for no contact loss -- design choice";
  parameter Real F_total_max(unit="N") = 15.0 "Maximum total force -- design choice";
  parameter Real k_restore(unit="1/m") = 100.0 "Body restoring coefficient -- design choice";
  parameter Real v_small(unit="m/s") = 0.02 "Friction smoothing velocity -- design choice";
  // Controller gains
  parameter Real Kp_f = 0.5 "Force controller proportional gain -- design choice";
  parameter Real Ki_f = 2.0 "Force controller integral gain -- design choice";
  parameter Real Kd_f = 0.001 "Force controller derivative gain -- design choice";
  parameter Real K_red = 0.3 "Force redistribution gain -- design choice";
  parameter Real K_obj = 200.0 "Object displacement to force gain -- design choice";
  parameter Real I_f_max(unit="N") = 5.0 "Integral anti-windup limit -- design choice";

  // ===== Continuous states =====
  Real kappa1(unit="1/m") "Section 1 curvature";
  Real kappa2(unit="1/m") "Section 2 curvature";
  Real kappa3(unit="1/m") "Section 3 curvature";
  Real kappa4(unit="1/m") "Section 4 curvature";
  Real kappa5(unit="1/m") "Section 5 curvature";
  Real kappa6(unit="1/m") "Section 6 curvature";
  Real T1(unit="N") "Tendon 1 tension";
  Real T2(unit="N") "Tendon 2 tension";
  Real T3(unit="N") "Tendon 3 tension";
  Real x_obj(unit="m") "Object tangential displacement";
  Real v_obj(unit="m/s") "Object tangential velocity";

  // ===== Discrete controller variables (125 Hz) =====
  Real T1_cmd(unit="N") "Commanded tendon 1 tension";
  Real T2_cmd(unit="N") "Commanded tendon 2 tension";
  Real T3_cmd(unit="N") "Commanded tendon 3 tension";
  Real I_f(unit="N") "Force controller integral term";
  Real F_des(unit="N") "Desired total normal force";
  Real F_total_prev(unit="N") "Previous total force for derivative";
  Real e_f(unit="N") "Force error";
  Real T_base(unit="N") "Base tension from PID";
  Real T1_raw(unit="N") "Unsaturated tendon 1 command";
  Real T2_raw(unit="N") "Unsaturated tendon 2 command";
  Real T3_raw(unit="N") "Unsaturated tendon 3 command";

  // ===== Sensors =====
  Real T1_meas(unit="N") "Measured tendon 1 tension (actuator sensing)";
  Real T2_meas(unit="N") "Measured tendon 2 tension (actuator sensing)";
  Real T3_meas(unit="N") "Measured tendon 3 tension (actuator sensing)";
  Real Fn1(unit="N") "Section 1 contact force (distributed contact sensing)";
  Real Fn2(unit="N") "Section 2 contact force";
  Real Fn3(unit="N") "Section 3 contact force";
  Real Fn4(unit="N") "Section 4 contact force";
  Real Fn5(unit="N") "Section 5 contact force";
  Real Fn6(unit="N") "Section 6 contact force";
  Real F_total(unit="N") "Total normal grasp force";
  Real x_obj_meas(unit="m") "Measured object displacement (pose measurement)";

  // ===== Physical quantities =====
  Real F_dist_active(unit="N") "Active tangential disturbance";
  Real pen1(unit="m") "Section 1 contact penetration";
  Real pen2(unit="m") "Section 2 contact penetration";
  Real pen3(unit="m") "Section 3 contact penetration";
  Real pen4(unit="m") "Section 4 contact penetration";
  Real pen5(unit="m") "Section 5 contact penetration";
  Real pen6(unit="m") "Section 6 contact penetration";
  Real N_normal(unit="N") "Normal force on support surface";
  Real F_friction(unit="N") "Friction force on object";
  Real F_restore(unit="N") "Body restoring force on object";

  // ===== Monitoring and bounds =====
  Real track_error(unit="m") "Primary tracking error";
  Real max_Fn(unit="N") "Maximum per-contact force";
  Real min_Fn(unit="N") "Minimum per-contact force";
  Real max_kappa(unit="1/m") "Maximum curvature";
  Real max_T_cmd(unit="N") "Maximum commanded tension";
  Real n_active "Number of active contacts";
  Boolean contact_loss "Contact loss flag";
  Boolean viol_actuator "Actuator bound violation";
  Boolean viol_deform "Deformation bound violation";
  Boolean viol_per_contact "Per-contact force band violation";
  Boolean viol_total_force "Total force band violation";
  Boolean viol_tracking "Tracking error violation after t_track";
  Boolean all_ok "All requirements satisfied";

initial equation
  kappa1 = 0; kappa2 = 0; kappa3 = 0;
  kappa4 = 0; kappa5 = 0; kappa6 = 0;
  T1 = 0; T2 = 0; T3 = 0;
  x_obj = 0; v_obj = 0;
  I_f = 0; F_total_prev = 0; F_des = F_des_nom;
  T1_cmd = 0; T2_cmd = 0; T3_cmd = 0;

equation
  // === Disturbance: 3.6 N during middle third (4 to 8 s) ===
  F_dist_active = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // === Tendon actuator dynamics (first-order lag) ===
  der(T1) = (T1_cmd - T1) / tau_tendon;
  der(T2) = (T2_cmd - T2) / tau_tendon;
  der(T3) = (T3_cmd - T3) / tau_tendon;

  // === Curvature dynamics with 120-degree tendon coupling ===
  // Tendon 1 -> sections 1-2, Tendon 2 -> sections 3-4, Tendon 3 -> sections 5-6
  // Coupling magnitude from |cos(tendon_angle)| in grasp direction
  // Deformation bounded by kappa_max
  der(kappa1) = (max(0.0, min(kappa_max, c_t*c1*T1)) - kappa1) / tau_curv;
  der(kappa2) = (max(0.0, min(kappa_max, c_t*c1*T1)) - kappa2) / tau_curv;
  der(kappa3) = (max(0.0, min(kappa_max, c_t*c2*T2)) - kappa3) / tau_curv;
  der(kappa4) = (max(0.0, min(kappa_max, c_t*c2*T2)) - kappa4) / tau_curv;
  der(kappa5) = (max(0.0, min(kappa_max, c_t*c3*T3)) - kappa5) / tau_curv;
  der(kappa6) = (max(0.0, min(kappa_max, c_t*c3*T3)) - kappa6) / tau_curv;

  // === Compliant contact model ===
  pen1 = max(0.0, kappa1 - kappa_contact) * L_sec;
  pen2 = max(0.0, kappa2 - kappa_contact) * L_sec;
  pen3 = max(0.0, kappa3 - kappa_contact) * L_sec;
  pen4 = max(0.0, kappa4 - kappa_contact) * L_sec;
  pen5 = max(0.0, kappa5 - kappa_contact) * L_sec;
  pen6 = max(0.0, kappa6 - kappa_contact) * L_sec;

  Fn1 = k_contact * pen1;
  Fn2 = k_contact * pen2;
  Fn3 = k_contact * pen3;
  Fn4 = k_contact * pen4;
  Fn5 = k_contact * pen5;
  Fn6 = k_contact * pen6;

  // === Total normal grasp force ===
  F_total = Fn1 + Fn2 + Fn3 + Fn4 + Fn5 + Fn6;

  // === Object dynamics on rigid support surface ===
  // Body presses object down: surface normal = weight + grasp force
  N_normal = m_obj * g_acc + F_total;
  // Coulomb friction with smooth approximation
  F_friction = mu * N_normal * tanh(v_obj / v_small);
  // Body elastic restoring force proportional to grasp force and displacement
  F_restore = k_restore * F_total * x_obj;
  // Newton's second law for object
  der(v_obj) = (F_dist_active - F_friction - F_restore) / m_obj;
  der(x_obj) = v_obj;

  // === Sensors ===
  T1_meas = T1;
  T2_meas = T2;
  T3_meas = T3;
  x_obj_meas = x_obj;

  // === Discrete controller at 125 Hz ===
  when sample(0, dt_s) then
    // Disturbance rejection: increase desired force based on object displacement
    F_des = min(F_des_nom + K_obj * abs(pre(x_obj)), F_des_max);
    // Force tracking error
    e_f = F_des - F_total;
    // Integral with anti-windup
    I_f = max(-I_f_max, min(I_f_max, pre(I_f) + e_f * dt_s));
    // PID output (derivative on measurement)
    T_base = Kp_f * e_f + Ki_f * I_f + Kd_f * (F_total - pre(F_total_prev)) / dt_s;
    // Contact-force redistribution: equalize per-contact forces across tendon groups
    T1_raw = T_base + K_red * (F_total/6.0 - (Fn1 + Fn2)/2.0);
    T2_raw = T_base + K_red * (F_total/6.0 - (Fn3 + Fn4)/2.0);
    T3_raw = T_base + K_red * (F_total/6.0 - (Fn5 + Fn6)/2.0);
    // Actuator saturation at 38.6 N
    T1_cmd = max(0.0, min(T_max, T1_raw));
    T2_cmd = max(0.0, min(T_max, T2_raw));
    T3_cmd = max(0.0, min(T_max, T3_raw));
    F_total_prev = F_total;
  end when;

  // === Monitoring and bounds checking ===
  track_error = abs(x_obj);
  max_Fn = max(Fn1, max(Fn2, max(Fn3, max(Fn4, max(Fn5, Fn6)))));
  min_Fn = min(Fn1, min(Fn2, min(Fn3, min(Fn4, min(Fn5, Fn6)))));
  max_kappa = max(kappa1, max(kappa2, max(kappa3, max(kappa4, max(kappa5, kappa6)))));
  max_T_cmd = max(T1_cmd, max(T2_cmd, T3_cmd));
  n_active = (if kappa1 > kappa_contact then 1.0 else 0.0) +
             (if kappa2 > kappa_contact then 1.0 else 0.0) +
             (if kappa3 > kappa_contact then 1.0 else 0.0) +
             (if kappa4 > kappa_contact then 1.0 else 0.0) +
             (if kappa5 > kappa_contact then 1.0 else 0.0) +
             (if kappa6 > kappa_contact then 1.0 else 0.0);
  contact_loss = (F_total < F_total_min) or (n_active < 3.0 and time > 2.0);
  viol_actuator = max_T_cmd > T_max + 0.001;
  viol_deform = max_kappa > kappa_max + 0.001;
  viol_per_contact = max_Fn > F_max_contact + 0.01;
  viol_total_force = (F_total < F_total_min - 0.01) or (F_total > F_total_max + 0.01);
  viol_tracking = (time >= t_track) and (track_error > track_err_thresh);
  all_ok = not (contact_loss or viol_actuator or viol_deform or
               viol_per_contact or viol_total_force or viol_tracking);

  annotation(
    Experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "TendonSoftGraspC: Tendon-driven soft robotic grasp with contact-force redistribution.
      Plant: 0.55 m cylindrical continuum body, 6 constant-curvature sections, 3 tendons at 120 deg spacing.
      Max command 38.6 N/tendon. 3.6 N tangential disturbance during middle third (4-8 s).
      Friction coefficient 0.70 on rigid support surface. Control at 125 Hz for 12 s.
      Sensors: actuator tension, distributed contact force, object pose.
      Design parameters marked as such are not specified in the requirement.")
  );
end TendonSoftGraspC;