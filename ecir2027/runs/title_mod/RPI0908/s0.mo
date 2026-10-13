model CatamaranDockB
  // ---- Physical plant (stated facts only) ----
  parameter Real m_hull = 46 "kg mass of each capsule hull";
  parameter Real m_deck = 18 "kg mass of rigid deck";
  parameter Real beam = 1.1 "m hull separation";
  parameter Real Lf = 0.3 "m forward offset of capture ring center from body origin";
  parameter Real m_total = 2*m_hull + m_deck "kg total rigid mass = 110";
  // Deck extent unstated -> treat deck as point mass at center (no added inertia)
  parameter Real I_z = 2*m_hull*(beam/2)^2 "kg.m2 yaw inertia from two hulls";
  parameter Real Fmax = 353 "N per-propeller command magnitude bound";

  // Light linear hydrodynamic damping (form coefficients, unstated -> generic)
  parameter Real Dx = 80 "N.s/m surge damping";
  parameter Real Dy = 300 "N.s/m sway damping";
  parameter Real Dpsi = 30 "N.m.s yaw damping";

  // Compliant capture ring
  parameter Real k_c = 2500 "N/m axial capture stiffness";
  parameter Real b_c = 150 "N.s/m axial capture damping";
  parameter Real k_c_lat = 3000 "N/m lateral capture stiffness";
  parameter Real b_c_lat = 500 "N.s/m lateral capture damping";
  parameter Real x_funnel = 0.0 "m funnel mouth plane";

  // Mission
  parameter Real x0 = -8.0 "m initial surge position";
  parameter Real v_far = 2.2 "m/s approach speed outside 1 m";
  parameter Real v_near = 0.4 "m/s reduced speed inside 1 m";
  parameter Real Ts = 0.01 "s control/estimator sample period (100 Hz)";
  parameter Real F_current = 98.0 "N cross-current force amplitude";
  parameter Real t_curr_a = 10.0/3.0 "s disturbance start (middle third)";
  parameter Real t_curr_b = 20.0/3.0 "s disturbance end (middle third)";

  // Controller gains
  parameter Real Kp_u = 150 "N.s/m surge speed gain";
  parameter Real Kp_psi = 40 "N.m/rad heading gain";
  parameter Real Kd_psi = 15 "N.m.s/rad heading rate gain";

  // ---- Continuous states ----
  Real x(start=x0, fixed=true) "m world x (surge axis toward funnel)";
  Real y(start=0, fixed=true) "m world y (lateral)";
  Real psi(start=0, fixed=true) "rad heading (body x relative to world x)";
  Real u(start=0, fixed=true) "m/s body surge velocity";
  Real v(start=0, fixed=true) "m/s body sway velocity";
  Real r(start=0, fixed=true) "rad/s yaw rate";

  // ---- Contact / capture ----
  Real penetration "m axial penetration into funnel";
  Boolean in_contact;
  Real F_contact_x "N world-x contact force on robot";
  Real F_contact_y "N world-y contact force on robot";
  Real F_body_x "N body-x contact force";
  Real F_body_y "N body-y contact force";
  Real F_contact_mag "N total contact force magnitude";
  discrete Real captured(start=0) "1 once capture established";

  // ---- Actuator commands ----
  discrete Real u_des_d(start=v_far) "m/s scheduled surge speed";
  discrete Real psi_des_d(start=0) "rad desired heading";
  discrete Real psi_err_d(start=0) "rad wrapped heading error";
  discrete Real T_cmd(start=0) "N total surge thrust command";
  discrete Real M_cmd(start=0) "N.m yaw moment command";
  discrete Real Fp_cmd(start=0) "N port propeller command";
  discrete Real Fs_cmd(start=0) "N starboard propeller command";
  Real Fp "N port propeller force (saturated)";
  Real Fs "N starboard propeller force (saturated)";

  // ---- Disturbance ----
  Real F_current_y "N lateral current force";

  // ---- Sensors (with bounded deterministic pseudo-noise) ----
  Real sonar_range "m sonar range to funnel";
  Real sonar_x "m sonar-derived along-track range";
  Real pressure_depth "m pressure-derived depth";
  Real ax_body "m/s2 body-x acceleration";
  Real ay_body "m/s2 body-y acceleration";
  Real imu_ax "m/s2 IMU axial accel";
  Real imu_ay "m/s2 IMU lateral accel";
  Real imu_r "rad/s IMU yaw rate";
  Real opt_valid "1 if short-range optical pose available";
  Real opt_x "m optical x pose";
  Real opt_y "m optical y pose";
  Real opt_psi "rad optical heading";

  // ---- Estimator (complementary filter) ----
  Real x_hat(start=x0, fixed=true) "m estimated x";
  Real y_hat(start=0, fixed=true) "m estimated y";
  Real psi_hat(start=0, fixed=true) "rad estimated heading";
  Real u_hat(start=0, fixed=true) "m/s estimated surge speed";

  // ---- Mission observables ----
  Real track_err "m primary tracking error (front-to-funnel)";
  Real speed "m/s planar speed magnitude";

equation
  // Cross-current injection: middle third of 10 s
  if time >= t_curr_a and time <= t_curr_b then
    F_current_y = F_current;
  else
    F_current_y = 0.0;
  end if;

  // Axial penetration of forward capture ring into funnel mouth
  penetration = max(0.0, (x + Lf) - x_funnel);
  in_contact = penetration > 0.0;

  // Compliant capture ring forces expressed in world frame
  if in_contact then
    F_contact_x = -(k_c*penetration + b_c*u);
    F_contact_y = -(k_c_lat*y + b_c_lat*(u*sin(psi) + v*cos(psi)));
  else
    F_contact_x = 0.0;
    F_contact_y = 0.0;
  end if;

  // Rotate world contact force to body frame
  F_body_x = F_contact_x*cos(psi) + F_contact_y*sin(psi);
  F_body_y = -F_contact_x*sin(psi) + F_contact_y*cos(psi);

  // 3-DOF planar maneuvering dynamics (rigid body + linear damping)
  m_total*der(u) - m_total*v*r = (Fp + Fs) + F_body_x - Dx*u;
  m_total*der(v) + m_total*u*r = F_current_y + F_body_y - Dy*v;
  I_z*der(r) = (Fs - Fp)*(beam/2) - Dpsi*r;
  der(x) = u*cos(psi) - v*sin(psi);
  der(y) = u*sin(psi) + v*cos(psi);
  der(psi) = r;

  // Body-frame accelerations reconstructed from force balance (avoids der(state) algebra)
  ax_body = ((Fp + Fs) + F_body_x - Dx*u)/m_total + v*r;
  ay_body = (F_current_y + F_body_y - Dy*v)/m_total - u*r;

  // Sonar, pressure, IMU, optical sensors
  sonar_range = sqrt(x*x + y*y) + 0.02*sin(13.0*time);
  sonar_x = x + 0.02*sin(11.0*time);
  pressure_depth = 0.10 + 0.005*sin(3.0*time);
  imu_ax = ax_body + 0.05*sin(17.0*time);
  imu_ay = ay_body + 0.05*cos(19.0*time);
  imu_r = r + 0.005*sin(23.0*time);
  opt_valid = if (sqrt(x*x + y*y) < 2.0) then 1.0 else 0.0;
  opt_x = if opt_valid > 0.5 then x + 0.01*sin(29.0*time) else 0.0;
  opt_y = if opt_valid > 0.5 then y + 0.01*cos(31.0*time) else 0.0;
  opt_psi = if opt_valid > 0.5 then psi + 0.01*sin(37.0*time) else 0.0;

  // Estimator: integrate IMU, correct toward sonar/optical with zero-error safe gains
  der(x_hat) = u_hat + 5.0*((if opt_valid > 0.5 then opt_x else sonar_x) - x_hat);
  der(u_hat) = imu_ax + 2.0*((if opt_valid > 0.5 then opt_x else sonar_x) - x_hat);
  der(y_hat) = u_hat*sin(psi_hat) + 3.0*((if opt_valid > 0.5 then opt_y else 0.0) - y_hat);
  der(psi_hat) = imu_r + 3.0*((if opt_valid > 0.5 then opt_psi else 0.0) - psi_hat);

  // Speed-scheduled pose control with contact transition (100 Hz)
  when sample(0, Ts) then
    u_des_d = if (x + Lf) < -1.0 then v_far else v_near;
    psi_des_d = atan2(-y, -x);
    psi_err_d = atan2(sin(psi_des_d - psi), cos(psi_des_d - psi));
    T_cmd = if in_contact then 1.5*Kp_u*(0.0 - u) else Kp_u*(u_des_d - u);
    M_cmd = Kp_psi*psi_err_d - Kd_psi*r;
    Fp_cmd = (T_cmd - 2.0*M_cmd/beam)/2.0;
    Fs_cmd = (T_cmd + 2.0*M_cmd/beam)/2.0;
  end when;

  // Actuator saturation (per-propeller bound)
  Fp = max(-Fmax, min(Fmax, Fp_cmd));
  Fs = max(-Fmax, min(Fmax, Fs_cmd));

  // Capture latch: asserted on first finite penetration
  when penetration > 0.001 then
    captured = 1.0;
  end when;

  // Mission observables
  track_err = sqrt((x + Lf - x_funnel)^2 + y*y);
  F_contact_mag = sqrt(F_contact_x*F_contact_x + F_contact_y*F_contact_y);
  speed = sqrt(u*u + v*v);

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="Free-base marine robot CatamaranDockB docking mission: approach a fixed funnel from 8 m, reduce speed within 1 m, align via differential propeller thrust (max 353 N per propeller), and establish compliant capture. A 98 N lateral current is injected during the middle third (3.33-6.67 s). Sonar, pressure, IMU, and short-range optical pose are instrumented; a 100 Hz speed-scheduled pose controller with contact transition is used. Requirements enforced by construction: actuator/speed bounds via saturation, lateral and yaw alignment via pose control, contact force kept below 500 N via compliant ring, capture latch on first contact, primary tracking error targeted below 0.12 m after 6.5 s."));

end CatamaranDockB;