model ParallelGripGraspC
  "Parallel-gripper grasp: impedance approach then force regulation with tangential disturbance"

  // === Plant parameters ===
  parameter Real m_palm(unit="kg") = 6.0 "Palm mass (fixed support)";
  parameter Real m_finger(unit="kg") = 0.5 "Per-finger mass";
  parameter Real finger_travel(unit="m") = 0.05 "Prismatic joint travel";
  parameter Real pad_k(unit="N/m") = 5.0e4 "Compliant pad stiffness (assumption)";
  parameter Real mu_table = 0.78 "Table friction coefficient";
  parameter Real mu_pad = 0.78 "Pad friction coefficient (assumption; not specified)";
  parameter Real e_rest = 0.03 "Restitution coefficient";
  parameter Real m_obj(unit="kg") = 1.0 "Object mass - NOT specified, assumption";
  parameter Real obj_width(unit="m") = 0.03 "Object width - NOT specified, assumption";
  parameter Real gap_rest(unit="m") = 0.06 "Initial finger-object half-gap (assumption)";
  parameter Real g(unit="m/s2") = 9.81 "Gravity";
  parameter Real pi_val = 3.14159265358979 "Pi constant";
  final parameter Real m_eff(unit="kg") = m_finger*m_obj/(m_finger+m_obj) "Effective contact mass";
  final parameter Real ln_e = -1.0*ln(max(e_rest,1.0e-6)) "Positive log of restitution";
  final parameter Real pad_d(unit="N.s/m") =
    2.0*sqrt(pad_k*m_eff)*ln_e/sqrt(pi_val*pi_val + ln_e*ln_e)
    "Pad damping derived from restitution coefficient";

  // === Control parameters ===
  parameter Real F_max(unit="N") = 41.4 "Max command magnitude per finger";
  parameter Real F_grasp_des(unit="N") = 20.0 "Desired grasp normal force per finger (assumption)";
  parameter Real K_imp(unit="N/m") = 1000.0 "Impedance stiffness (assumption)";
  parameter Real D_imp(unit="N.s/m") = 50.0 "Impedance damping (assumption)";
  parameter Real K_force = 4.0 "Force regulation gain (assumption)";
  parameter Real x_closure_des(unit="m") = 0.048 "Impedance closure target (assumption)";
  parameter Real F_dist(unit="N") = 7.2 "Tangential disturbance magnitude";
  parameter Real t_dist_start(unit="s") = 4.0 "Disturbance start (middle third of 12 s)";
  parameter Real t_dist_end(unit="s") = 8.0 "Disturbance end";
  parameter Real dt_sample(unit="s") = 1.0/125.0 "Sample period (125 Hz)";
  parameter Real F_contact_thresh(unit="N") = 0.5 "Contact detection threshold";
  parameter Real v_reg(unit="m/s") = 1.0e-3 "Friction regularization velocity";
  parameter Real stop_k(unit="N/m") = 1.0e6 "Joint stop stiffness";
  parameter Real stop_d(unit="N.s/m") = 1.0e3 "Joint stop damping";
  parameter Real pen_eps(unit="m") = 1.0e-9 "Penetration threshold";

  // === Continuous plant states ===
  Real x_L(start=0.0, unit="m") "Left finger closure position";
  Real v_L(start=0.0, unit="m/s") "Left finger velocity";
  Real x_R(start=0.0, unit="m") "Right finger closure position";
  Real v_R(start=0.0, unit="m/s") "Right finger velocity";
  Real x_obj(start=0.0, unit="m") "Object normal position";
  Real vx_obj(start=0.0, unit="m/s") "Object normal velocity";
  Real y_obj(start=0.0, unit="m") "Object tangential position";
  Real vy_obj(start=0.0, unit="m/s") "Object tangential velocity";

  // === Sensor / derived signals ===
  Real x_L_tip(unit="m") "Left finger tip world position";
  Real x_R_tip(unit="m") "Right finger tip world position";
  Real gap1(unit="m") "Left finger-object gap";
  Real gap2(unit="m") "Right finger-object gap";
  Real pen1(unit="m") "Left penetration";
  Real pen2(unit="m") "Right penetration";
  Real F_n1(unit="N") "Left normal contact force";
  Real F_n2(unit="N") "Right normal contact force";
  Real F_disturbance(unit="N") "Tangential disturbance force";
  Real N_table(unit="N") "Table normal reaction";
  Real F_friction(unit="N") "Tangential friction on object";
  Real F_friction_cap(unit="N") "Friction capacity";

  // === Discrete controller / sensor state ===
  discrete Real x_L_m(start=0.0, unit="m") "Sampled left finger position";
  discrete Real v_L_m(start=0.0, unit="m/s") "Sampled left finger velocity";
  discrete Real x_R_m(start=0.0, unit="m") "Sampled right finger position";
  discrete Real v_R_m(start=0.0, unit="m/s") "Sampled right finger velocity";
  discrete Real F_n1_m(start=0.0, unit="N") "Sampled left normal force";
  discrete Real F_n2_m(start=0.0, unit="N") "Sampled right normal force";
  discrete Real y_obj_m(start=0.0, unit="m") "Sampled object tangential position";
  discrete Real vy_obj_m(start=0.0, unit="m/s") "Sampled object tangential velocity";
  discrete Real phase(start=1.0) "1 = impedance approach, 2 = force regulation";

  // === Commands ===
  Real u1_raw(unit="N") "Raw left command";
  Real u2_raw(unit="N") "Raw right command";
  Real u1(unit="N") "Bounded left command";
  Real u2(unit="N") "Bounded right command";

  // === Joint stops ===
  Real F_stop_L(unit="N") "Left joint stop force";
  Real F_stop_R(unit="N") "Right joint stop force";

  // === Performance metric ===
  Real tracking_error(unit="m") "Primary tracking error = |y_obj|";

equation
  // Palm is a fixed support (mass retained as parameter; static).
  // No dynamics for palm since it is fixed.

  // === Geometric relations ===
  x_L_tip = -gap_rest + x_L;
  x_R_tip =  gap_rest - x_R;
  gap1 = (x_obj - obj_width/2) - x_L_tip;
  gap2 = x_R_tip - (x_obj + obj_width/2);
  pen1 = max(0.0, -gap1);
  pen2 = max(0.0, -gap2);

  // === Compliant-pad normal contact forces (collision enabled via compliant model) ===
  F_n1 = if pen1 > pen_eps then pad_k*pen1 + pad_d*max(0.0, v_L - vx_obj) else 0.0;
  F_n2 = if pen2 > pen_eps then pad_k*pen2 + pad_d*max(0.0, vx_obj - v_R) else 0.0;

  // === Tangential disturbance injected during middle third (4 s .. 8 s of 12 s) ===
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // === Friction: rigid support table friction + grasp pad friction (regularized Coulomb) ===
  N_table = m_obj*g;
  F_friction_cap = mu_table*N_table + mu_pad*(F_n1 + F_n2);
  F_friction = F_friction_cap*tanh(vy_obj/v_reg);

  // === Finger dynamics (two bounded linear actuators regulate closure) ===
  der(x_L) = v_L;
  m_finger*der(v_L) = u1 - F_n1 - F_stop_L;
  der(x_R) = v_R;
  m_finger*der(v_R) = u2 - F_n2 - F_stop_R;

  // Joint travel bounds [0, finger_travel] enforced by compliant stops
  F_stop_L = if x_L < 0.0 then stop_k*(-x_L) + stop_d*max(0.0, -v_L)
             else if x_L > finger_travel then stop_k*(finger_travel - x_L) - stop_d*max(0.0, v_L)
             else 0.0;
  F_stop_R = if x_R < 0.0 then stop_k*(-x_R) + stop_d*max(0.0, -v_R)
             else if x_R > finger_travel then stop_k*(finger_travel - x_R) - stop_d*max(0.0, v_R)
             else 0.0;

  // === Object dynamics (rigid object) ===
  der(x_obj) = vx_obj;
  m_obj*der(vx_obj) = F_n1 - F_n2;
  der(y_obj) = vy_obj;
  m_obj*der(vy_obj) = F_disturbance - F_friction;

  // === Sampled instrumentation and phase supervisor at 125 Hz ===
  when sample(0, dt_sample) then
    x_L_m  = x_L;
    v_L_m  = v_L;
    x_R_m  = x_R;
    v_R_m  = v_R;
    F_n1_m = F_n1;
    F_n2_m = F_n2;
    y_obj_m = y_obj;
    vy_obj_m = vy_obj;
    phase = if (F_n1_m > F_contact_thresh and F_n2_m > F_contact_thresh) then 2.0 else 1.0;
  end when;

  // === Controller: impedance motion followed by force regulation ===
  u1_raw = if phase < 1.5 then (K_imp*(x_closure_des - x_L_m) - D_imp*v_L_m)
           else (F_grasp_des + K_force*(F_grasp_des - F_n1_m));
  u2_raw = if phase < 1.5 then (K_imp*(x_closure_des - x_R_m) - D_imp*v_R_m)
           else (F_grasp_des + K_force*(F_grasp_des - F_n2_m));

  // Effort bounds (max command magnitude 41.4 N per finger)
  u1 = max(-F_max, min(F_max, u1_raw));
  u2 = max(-F_max, min(F_max, u2_raw));

  // === Primary tracking error (object tangential displacement) ===
  tracking_error = abs(y_obj);

  annotation(
    experiment(StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="Parallel-gripper grasp system ParallelGripGraspC. Impedance motion brings the two opposing fingers to the rigid object; once bilateral normal contact is detected, force regulation maintains the grasp normal force. A 7.2 N tangential load disturbance is injected during the middle third (4 s to 8 s) of the 12 s run. Plant: 6 kg fixed palm, two 0.5 kg opposing box fingers on prismatic joints with 0.05 m travel and compliant pads, rigid object on a rigid support table with friction coefficient 0.78 and restitution 0.03 (collision enabled via compliant contact). Instrumentation: actuator state (x_L,v_L,x_R,v_R,u1,u2), normal contact forces (F_n1,F_n2), object pose (x_obj,y_obj). Commands are bounded at 41.4 N per finger. Object mass and object width are not specified in the requirement and are placeholder assumptions."),
    Diagram(graphics={}));
end ParallelGripGraspC;