model MonoHopWalkB
  "Floating-base legged robot MonoHopWalkB: monopedal hopper tracking 0.4 m/s forward gait"

  // === Physical parameters ===
  parameter Real m_body(unit="kg") = 10.0 "Body mass";
  parameter Real I_body(unit="kg.m2") = 0.2 "Body pitch inertia";
  parameter Real m_foot(unit="kg") = 0.1 "Foot mass";
  parameter Real L_min(unit="m") = 0.30 "Minimum leg length";
  parameter Real L_max(unit="m") = 0.60 "Maximum leg length";
  parameter Real L_rest(unit="m") = 0.45 "Spring rest length";
  parameter Real k_leg(unit="N/m") = 15000.0 "Leg spring stiffness";
  parameter Real c_leg(unit="N.s/m") = 170.0 "Leg damping";
  parameter Real F_act_max(unit="N") = 779.0 "Max actuator force magnitude";
  parameter Real mu = 0.85 "Ground friction coefficient";
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";
  parameter Real k_contact(unit="N/m") = 20000.0 "Contact stiffness";
  parameter Real c_contact(unit="N.s/m") = 500.0 "Contact damping";
  parameter Real r_foot(unit="m") = 0.02 "Spherical foot radius";
  parameter Real v_thresh(unit="m/s") = 0.01 "Friction velocity threshold";
  parameter Real L_eps(unit="m") = 0.001 "Safe minimum leg length for division";
  parameter Real tau_hip_max(unit="N.m") = 50.0 "Hip torque bound";
  parameter Real tau_att_max(unit="N.m") = 200.0 "Attitude torque bound";

  // === Control parameters ===
  parameter Real v_des(unit="m/s") = 0.4 "Desired forward velocity";
  parameter Real z_des(unit="m") = 0.45 "Desired body height";
  parameter Real kp_att = 80.0 "Attitude control proportional gain";
  parameter Real kd_att = 8.0 "Attitude control derivative gain";
  parameter Real kp_hip = 40.0 "Hip angle proportional gain";
  parameter Real kd_hip = 4.0 "Hip angle derivative gain";
  parameter Real kp_leg(unit="N/m") = 2000.0 "Leg impedance proportional gain";
  parameter Real kd_leg(unit="N.s/m") = 100.0 "Leg impedance derivative gain";
  parameter Real F_push(unit="N") = 49.0 "Body push disturbance magnitude";
  parameter Real t_start_push(unit="s") = 3.33 "Push disturbance start time";
  parameter Real t_end_push(unit="s") = 6.67 "Push disturbance end time";
  parameter Real k_limit(unit="N/m") = 100000.0 "Leg limit spring stiffness";
  parameter Real c_limit(unit="N.s/m") = 1000.0 "Leg limit damping";

  // === Continuous states ===
  Real x_b(start=0.0, fixed=true, unit="m") "Body x position";
  Real vx_b(start=0.0, fixed=true, unit="m/s") "Body x velocity";
  Real z_b(start=0.50, fixed=true, unit="m") "Body z position";
  Real vz_b(start=0.0, fixed=true, unit="m/s") "Body z velocity";
  Real theta(start=0.0, fixed=true, unit="rad") "Body pitch angle";
  Real omega_b(start=0.0, fixed=true, unit="rad/s") "Body pitch rate";
  Real x_f(start=0.0, fixed=true, unit="m") "Foot x position";
  Real vx_f(start=0.0, fixed=true, unit="m/s") "Foot x velocity";
  Real z_f(start=0.05, fixed=true, unit="m") "Foot z position";
  Real vz_f(start=0.0, fixed=true, unit="m/s") "Foot z velocity";

  // === Derived kinematic quantities ===
  Real L(unit="m") "Leg length";
  Real L_div(unit="m") "Safe leg length for division";
  Real vL(unit="m/s") "Leg length rate";
  Real phi(unit="rad") "Leg angle from vertical";
  Real dphi(unit="rad/s") "Leg angular rate";
  Real e_leg_x "Unit leg direction x (body to foot)";
  Real e_leg_z "Unit leg direction z (body to foot)";
  Real e_perp_x "Perpendicular to leg x (CCW)";
  Real e_perp_z "Perpendicular to leg z (CCW)";

  // === Contact ===
  Real N_contact(start=0.0, unit="N") "Contact normal force";
  Real F_fric(unit="N") "Friction force on foot";
  Real penetration(unit="m") "Ground penetration depth";
  Integer contact_count(start=0) "Supporting contact count";
  Boolean in_stance "Stance flag";

  // === Leg forces ===
  Real F_spring(unit="N") "Leg spring force";
  Real F_damper(unit="N") "Leg damper force";
  Real F_limit(unit="N") "Leg limit force";
  Real F_leg(unit="N") "Total leg axial force";
  Real F_act_sat(unit="N") "Saturated actuator force";

  // === Discrete control (100 Hz) ===
  discrete Real F_act_hold(start=0.0, unit="N") "Held actuator command";
  discrete Real tau_hip_hold(start=0.0, unit="N.m") "Held hip torque command";
  discrete Real tau_att_hold(start=0.0, unit="N.m") "Held attitude torque command";
  discrete Real phi_des_hold(start=0.0, unit="rad") "Held desired leg angle";
  discrete Boolean in_stance_hold(start=false) "Held stance flag";

  // === Saturated control outputs ===
  Real tau_hip_sat(unit="N.m") "Saturated hip torque";
  Real tau_att(unit="N.m") "Attitude torque applied";

  // === Disturbance ===
  Real F_push_actual(unit="N") "Current push force";

  // === Sensors ===
  Real leg_length_sensor(unit="m") "Joint encoder: leg length";
  Real leg_angle_sensor(unit="rad") "Joint encoder: leg angle";
  Real pitch_sensor(unit="rad") "Torso IMU: body pitch";
  Real pitch_rate_sensor(unit="rad/s") "Torso IMU: body pitch rate";
  Real vx_sensor(unit="m/s") "Torso IMU: forward velocity";
  Real vz_sensor(unit="m/s") "Torso IMU: vertical velocity";
  Real contact_force_sensor(unit="N") "Foot contact-force sensor";

  // === Performance metrics ===
  Real v_error(unit="m/s") "Forward velocity tracking error";
  Real z_error(unit="m") "Height tracking error";
  Real att_error(unit="rad") "Body attitude error";
  Real forward_progress(unit="m") "Forward progress";

  // === Safety checks ===
  Boolean leg_length_ok "Leg length within bounds";
  Boolean torque_ok "Torque within bounds";
  Boolean tracking_ok "Tracking error below 0.12 m/s after 6.5 s";
  Boolean no_nan_inf "No NaN or infinite values";

equation
  // === Kinematics ===
  L = sqrt((x_f - x_b)^2 + (z_f - z_b)^2);
  L_div = max(L_eps, L);
  e_leg_x = (x_f - x_b) / L_div;
  e_leg_z = (z_f - z_b) / L_div;
  e_perp_x = (z_b - z_f) / L_div;
  e_perp_z = (x_f - x_b) / L_div;
  vL = ((x_f - x_b)*(vx_f - vx_b) + (z_f - z_b)*(vz_f - vz_b)) / L_div;
  phi = atan2(x_f - x_b, z_b - z_f);
  dphi = (e_perp_x*(vx_f - vx_b) + e_perp_z*(vz_f - vz_b)) / L_div;

  // === Contact model (penalty-based, rigid plane) ===
  penetration = max(0.0, r_foot - z_f);
  N_contact = max(0.0, k_contact*penetration - c_contact*min(0.0, vz_f));
  F_fric = mu * N_contact * tanh(-vx_f / v_thresh);
  contact_count = if noEvent(N_contact > 1.0) then 1 else 0;
  in_stance = noEvent(N_contact > 1.0);

  // === Leg forces (spring + damper + actuator + limit) ===
  F_spring = k_leg * (L_rest - L);
  F_damper = -c_leg * vL;
  F_limit = noEvent(if L < L_min then k_limit*(L_min - L) - c_limit*min(0.0, vL)
                    else if L > L_max then k_limit*(L_max - L) - c_limit*max(0.0, vL)
                    else 0.0);
  F_act_sat = max(-F_act_max, min(F_act_max, F_act_hold));
  F_leg = F_spring + F_damper + F_act_sat + F_limit;

  // === Push disturbance (middle third of 10 s) ===
  F_push_actual = noEvent(if time >= t_start_push and time <= t_end_push then F_push else 0.0);

  // === Body dynamics ===
  der(x_b) = vx_b;
  der(z_b) = vz_b;
  m_body*der(vx_b) = -F_leg*e_leg_x - (tau_hip_sat/L_div)*e_perp_x + F_push_actual;
  m_body*der(vz_b) = -F_leg*e_leg_z - (tau_hip_sat/L_div)*e_perp_z - m_body*g;
  der(theta) = omega_b;
  I_body*der(omega_b) = tau_att - tau_hip_sat;

  // === Foot dynamics ===
  der(x_f) = vx_f;
  der(z_f) = vz_f;
  m_foot*der(vx_f) = F_leg*e_leg_x + (tau_hip_sat/L_div)*e_perp_x + F_fric;
  m_foot*der(vz_f) = F_leg*e_leg_z + (tau_hip_sat/L_div)*e_perp_z + N_contact - m_foot*g;

  // === Saturated commands ===
  tau_hip_sat = max(-tau_hip_max, min(tau_hip_max, tau_hip_hold));
  tau_att = max(-tau_att_max, min(tau_att_max, tau_att_hold));

  // === Discrete control loop at 100 Hz ===
  when sample(0, 0.01) then
    // Stance detection
    in_stance_hold = N_contact > 1.0;
    // Desired leg angle for forward velocity tracking (Raibert-inspired)
    phi_des_hold = 0.12*(v_des - vx_b) / max(0.1, sqrt(g*L_rest));
    // Phase-based joint impedance: stance injects energy, flight resets
    if in_stance_hold then
      F_act_hold = kp_leg*(L_rest - L) + kd_leg*(-vL);
    else
      F_act_hold = 0.5*kp_leg*(L_rest - L) + 0.5*kd_leg*(-vL);
    end if;
    // Hip control: drive leg to desired angle
    tau_hip_hold = kp_hip*(phi_des_hold - phi) - kd_hip*dphi;
    // Body attitude control: stabilize pitch to zero
    tau_att_hold = -kp_att*theta - kd_att*omega_b;
  end when;

  // === Sensors ===
  leg_length_sensor = L;
  leg_angle_sensor = phi;
  pitch_sensor = theta;
  pitch_rate_sensor = omega_b;
  vx_sensor = vx_b;
  vz_sensor = vz_b;
  contact_force_sensor = N_contact;

  // === Performance metrics ===
  v_error = abs(vx_b - v_des);
  z_error = abs(z_b - z_des);
  att_error = abs(theta);
  forward_progress = x_b;

  // === Safety checks ===
  leg_length_ok = noEvent((L >= L_min - 0.01) and (L <= L_max + 0.01));
  torque_ok = (abs(tau_hip_sat) <= tau_hip_max + 0.001) and (abs(tau_att) <= tau_att_max + 0.001);
  tracking_ok = noEvent(if time >= 6.5 then v_error < 0.12 else true);
  no_nan_inf = noEvent(abs(x_b) < 1e6 and abs(z_b) < 1e6 and abs(vx_b) < 1e6
    and abs(vz_b) < 1e6 and abs(L) < 1e6 and abs(N_contact) < 1e8
    and abs(F_leg) < 1e8 and abs(tau_hip_sat) < 1e6 and abs(tau_att) < 1e6);

  annotation(
    Documentation(info="MonoHopWalkB: Monopedal hopping robot.
      Tracks 0.4 m/s forward gait while holding nominal body height.
      10 kg cylindrical body, telescoping leg 0.30-0.60 m,
      15 kN/m spring, 170 N.s/m damper, spherical foot.
      Bounded linear actuator: 779 N max. Ground friction 0.85. Gravity 9.81 m/s2.
      Phase-based joint impedance + body-attitude control at 100 Hz.
      49 N body push disturbance during middle third (3.33-6.67 s).
      10 s simulation. Synchronized state, command, and sensor traces retained."),
    experiment(StopTime=10.0, Tolerance=1e-6, Interval=0.001)
  );
end MonoHopWalkB;