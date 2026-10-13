model WheelLegRecoverE "Floating-base wheel-legged robot with balance recovery from lateral impulse"

  // Requirement parameters
  parameter Real m_body(unit = "kg") = 28.0 "Torso mass";
  parameter Real r_wheel(unit = "m") = 0.10 "Wheel radius";
  parameter Real mu = 0.90 "Ground friction coefficient";
  parameter Real tau_max(unit = "N.m") = 60.5 "Per-joint torque limit";
  parameter Real F_push(unit = "N") = 168.0 "Lateral push force";
  parameter Real f_ctrl(unit = "Hz") = 250.0 "Control rate";
  parameter Real t_sim(unit = "s") = 16.0 "Run duration";
  parameter Real slip_limit(unit = "m") = 0.03 "Foot slip limit";
  parameter Real track_limit(unit = "rad") = 0.108 "Tracking error limit";
  parameter Real t_check(unit = "s") = 10.4 "Recovery check time";
  parameter Real dt_ctrl(unit = "s") = 1.0 / f_ctrl "Control period";

  // Design parameters (engineering assumptions, not stated in requirement)
  parameter Real L1(unit = "m") = 0.20 "Upper leg length";
  parameter Real L2(unit = "m") = 0.20 "Lower leg length";
  parameter Real half_len(unit = "m") = 0.20 "Half body length";
  parameter Real half_wid(unit = "m") = 0.15 "Half body width";
  parameter Real I_pitch(unit = "kg.m2") = 1.2 "Base pitch inertia";
  parameter Real I_roll(unit = "kg.m2") = 1.0 "Base roll inertia";
  parameter Real J_leg(unit = "kg.m2") = 0.02 "Leg joint inertia";
  parameter Real J_wheel(unit = "kg.m2") = 0.003 "Wheel inertia";
  parameter Real m_leg(unit = "kg") = 0.5 "Leg link mass";
  parameter Real k_gnd(unit = "N/m") = 100000.0 "Ground stiffness";
  parameter Real d_gnd(unit = "N.s/m") = 1000.0 "Ground damping";
  parameter Real grav(unit = "m/s2") = 9.81 "Gravitational acceleration";
  parameter Real q1_nom(unit = "rad") = 0.30 "Nominal hip angle";
  parameter Real q2_nom(unit = "rad") = 0.70 "Nominal knee angle";
  parameter Real z_nom(unit = "m") = L1 * cos(q1_nom) + L2 * cos(q1_nom + q2_nom) "Nominal leg length";
  parameter Real z_eq(unit = "m") = z_nom - m_body * grav / (4.0 * k_gnd) "Equilibrium body height";
  parameter Real kp_joint = 400.0 "Joint PD proportional gain";
  parameter Real kd_joint = 20.0 "Joint PD derivative gain";
  parameter Real kp_pitch = 300.0 "Pitch balance gain";
  parameter Real kd_pitch = 30.0 "Pitch rate gain";
  parameter Real kp_roll = 200.0 "Roll balance gain";
  parameter Real kd_roll = 20.0 "Roll rate gain";
  parameter Real kp_z = 3000.0 "Height control gain";
  parameter Real kd_z = 150.0 "Height rate gain";
  parameter Real kp_x = 800.0 "X position gain";
  parameter Real kd_x = 60.0 "X velocity gain";
  parameter Real kp_y = 300.0 "Lateral position gain";
  parameter Real kd_y = 30.0 "Lateral velocity gain";
  parameter Real v_eps(unit = "m/s") = 0.01 "Friction smoothing velocity";
  parameter Real b_wheel(unit = "N.m.s") = 0.05 "Wheel bearing friction";
  parameter Real F_contact_thresh(unit = "N") = 5.0 "Force-qualified contact threshold";
  parameter Real alpha_est = 0.1 "Estimator correction gain";
  parameter Real J21_nom = L1 * sin(q1_nom) + L2 * sin(q1_nom + q2_nom);
  parameter Real J22_nom = L2 * sin(q1_nom + q2_nom);
  parameter Real tau1_ff(unit = "N.m") = J21_nom * m_body * grav / 4.0 + m_leg * grav * (L1 / 2.0) * sin(q1_nom) + m_leg * grav * (L2 / 2.0) * sin(q1_nom + q2_nom);
  parameter Real tau2_ff(unit = "N.m") = J22_nom * m_body * grav / 4.0 + m_leg * grav * (L2 / 2.0) * sin(q1_nom + q2_nom);
  parameter Real hx[4] = {half_len, half_len, -half_len, -half_len} "Hip x offsets";
  parameter Real hy[4] = {half_wid, -half_wid, half_wid, -half_wid} "Hip y offsets";
  parameter Real roll_sign[4] = {1.0, -1.0, 1.0, -1.0} "Roll sign per leg";

  // Base states
  Real x(start = 0, fixed = true) "Base x [m]";
  Real vx(start = 0, fixed = true) "Base vx [m/s]";
  Real y(start = 0, fixed = true) "Base y [m]";
  Real vy(start = 0, fixed = true) "Base vy [m/s]";
  Real z(start = z_eq, fixed = true) "Base z [m]";
  Real vz(start = 0, fixed = true) "Base vz [m/s]";
  Real theta(start = 0, fixed = true) "Base pitch [rad]";
  Real omega_th(start = 0, fixed = true) "Base pitch rate [rad/s]";
  Real phi(start = 0, fixed = true) "Base roll [rad]";
  Real omega_ph(start = 0, fixed = true) "Base roll rate [rad/s]";

  // Leg states
  Real q1[4](start = {q1_nom, q1_nom, q1_nom, q1_nom}, each fixed = true) "Hip angles [rad]";
  Real dq1[4](start = {0, 0, 0, 0}, each fixed = true) "Hip rates [rad/s]";
  Real q2[4](start = {q2_nom, q2_nom, q2_nom, q2_nom}, each fixed = true) "Knee angles [rad]";
  Real dq2[4](start = {0, 0, 0, 0}, each fixed = true) "Knee rates [rad/s]";

  // Wheel states
  Real wphi[4](start = {0, 0, 0, 0}, each fixed = true) "Wheel angles [rad]";
  Real dwphi[4](start = {0, 0, 0, 0}, each fixed = true) "Wheel rates [rad/s]";

  // Estimator states
  Real theta_est(start = 0, fixed = true) "Estimated pitch [rad]";
  Real phi_est(start = 0, fixed = true) "Estimated roll [rad]";
  Real x_est(start = 0, fixed = true) "Estimated x [m]";
  Real y_est(start = 0, fixed = true) "Estimated y [m]";
  Real vx_est(start = 0, fixed = true) "Estimated vx [m/s]";
  Real vy_est(start = 0, fixed = true) "Estimated vy [m/s]";

  // Slip accumulator
  Real slip_accum[4](start = {0, 0, 0, 0}, each fixed = true) "Accumulated slip [m]";

  // Kinematic intermediates
  Real c_th "cos(theta)";
  Real s_th "sin(theta)";
  Real c_ph "cos(phi)";
  Real s_ph "sin(phi)";
  Real c_q1[4] "cos(q1)";
  Real s_q1[4] "sin(q1)";
  Real c_q12[4] "cos(q1+q2)";
  Real s_q12[4] "sin(q1+q2)";
  Real fx_rel[4] "Foot x offset from hip [m]";
  Real fz_rel[4] "Foot z offset from hip [m]";
  Real fx_vel[4] "Foot x offset velocity [m/s]";
  Real fz_vel[4] "Foot z offset velocity [m/s]";

  // Hip positions and velocities
  Real hip_x[4] "Hip x world [m]";
  Real hip_y[4] "Hip y world [m]";
  Real hip_z[4] "Hip z world [m]";
  Real hip_vx[4] "Hip x velocity [m/s]";
  Real hip_vy[4] "Hip y velocity [m/s]";
  Real hip_vz[4] "Hip z velocity [m/s]";

  // Foot positions and velocities
  Real foot_x[4] "Foot x world [m]";
  Real foot_y[4] "Foot y world [m]";
  Real foot_z[4] "Foot z world [m]";
  Real foot_vx[4] "Foot x velocity [m/s]";
  Real foot_vy[4] "Foot y velocity [m/s]";
  Real foot_vz[4] "Foot z velocity [m/s]";

  // Contact
  Real GRF_n[4] "Normal GRF [N]";
  Real GRF_x[4] "X friction [N]";
  Real GRF_y[4] "Y friction [N]";
  Real penetration[4] "Foot penetration [m]";
  Boolean in_contact[4] "Contact flag";

  // Jacobians
  Real J11[4] "Jacobian 11";
  Real J12[4] "Jacobian 12";
  Real J21[4] "Jacobian 21";
  Real J22[4] "Jacobian 22";

  // Torques
  Real tau1_cmd[4] "Hip torque command [N.m]";
  Real tau2_cmd[4] "Knee torque command [N.m]";
  Real tau1[4] "Applied hip torque [N.m]";
  Real tau2[4] "Applied knee torque [N.m]";
  Real tau_w_cmd[4] "Wheel torque command [N.m]";
  Real tau_w[4] "Applied wheel torque [N.m]";

  // Controller desired values
  Real q1_des[4] "Desired hip angle [rad]";
  Real q2_des[4] "Desired knee angle [rad]";

  // Sampled controller state
  Real x_c(start = 0) "Sampled x [m]";
  Real vx_c(start = 0) "Sampled vx [m/s]";
  Real y_c(start = 0) "Sampled y [m]";
  Real vy_c(start = 0) "Sampled vy [m/s]";
  Real z_c(start = z_eq) "Sampled z [m]";
  Real vz_c(start = 0) "Sampled vz [m/s]";
  Real theta_c(start = 0) "Sampled pitch [rad]";
  Real omega_th_c(start = 0) "Sampled pitch rate [rad/s]";
  Real phi_c(start = 0) "Sampled roll [rad]";
  Real omega_ph_c(start = 0) "Sampled roll rate [rad/s]";
  Real q1_c[4](start = {q1_nom, q1_nom, q1_nom, q1_nom}) "Sampled hip angles [rad]";
  Real dq1_c[4](start = {0, 0, 0, 0}) "Sampled hip rates [rad/s]";
  Real q2_c[4](start = {q2_nom, q2_nom, q2_nom, q2_nom}) "Sampled knee angles [rad]";
  Real dq2_c[4](start = {0, 0, 0, 0}) "Sampled knee rates [rad/s]";

  // IMU
  Real imu_ax "IMU x acceleration [m/s2]";
  Real imu_ay "IMU y acceleration [m/s2]";
  Real imu_wx "IMU roll rate [rad/s]";
  Real imu_wy "IMU pitch rate [rad/s]";

  // Disturbance and forces
  Real F_dist "Disturbance force [N]";
  Real Fx_total "Total x force [N]";
  Real Fy_total "Total y force [N]";
  Real Fz_total "Total z force [N]";
  Real M_pitch "Pitch moment [N.m]";
  Real M_roll "Roll moment [N.m]";

  // Estimator corrections
  Real contact_corr_theta "Pitch estimator correction";
  Real contact_corr_phi "Roll estimator correction";
  Real contact_corr_vx "Vx estimator correction";
  Real contact_corr_vy "Vy estimator correction";
  Real contact_corr_x "X estimator correction";
  Real contact_corr_y "Y estimator correction";

  // Acceptance
  Real tracking_error "Attitude tracking error [rad]";
  Real max_slip "Maximum slip [m]";
  Boolean no_slip_ok "No slip criterion";
  Boolean height_ok "Height criterion";
  Boolean tracking_ok "Tracking criterion";
  Boolean torque_ok "Torque criterion";
  Boolean no_nan_inf "No NaN/inf criterion";
  Boolean all_ok "Fail-closed acceptance";

equation
  // Trig helpers
  c_th = cos(theta);
  s_th = sin(theta);
  c_ph = cos(phi);
  s_ph = sin(phi);

  // Disturbance: 168 N lateral push during middle third of 16 s run
  F_dist = if time >= t_sim / 3.0 and time <= 2.0 * t_sim / 3.0 then F_push else 0.0;

  // Leg kinematics (decoupled pitch/roll approximation)
  for i in 1:4 loop
    c_q1[i] = cos(q1[i]);
    s_q1[i] = sin(q1[i]);
    c_q12[i] = cos(q1[i] + q2[i]);
    s_q12[i] = sin(q1[i] + q2[i]);

    fx_rel[i] = L1 * s_q1[i] + L2 * s_q12[i];
    fz_rel[i] = -(L1 * c_q1[i] + L2 * c_q12[i]);

    fx_vel[i] = L1 * c_q1[i] * dq1[i] + L2 * c_q12[i] * (dq1[i] + dq2[i]);
    fz_vel[i] = L1 * s_q1[i] * dq1[i] + L2 * s_q12[i] * (dq1[i] + dq2[i]);

    hip_x[i] = x + c_th * hx[i];
    hip_y[i] = y + c_ph * hy[i];
    hip_z[i] = z - s_th * hx[i] - s_ph * hy[i];

    hip_vx[i] = vx - s_th * omega_th * hx[i];
    hip_vy[i] = vy - s_ph * omega_ph * hy[i];
    hip_vz[i] = vz - c_th * omega_th * hx[i] - c_ph * omega_ph * hy[i];

    foot_x[i] = hip_x[i] + c_th * fx_rel[i] - s_th * fz_rel[i];
    foot_y[i] = hip_y[i] - s_ph * fz_rel[i];
    foot_z[i] = hip_z[i] + s_th * fx_rel[i] + c_th * fz_rel[i];

    foot_vx[i] = hip_vx[i] - s_th * omega_th * fx_rel[i] + c_th * fx_vel[i]
               - c_th * omega_th * fz_rel[i] - s_th * fz_vel[i];
    foot_vy[i] = hip_vy[i] - c_ph * omega_ph * fz_rel[i] - s_ph * fz_vel[i];
    foot_vz[i] = hip_vz[i] + c_th * omega_th * fx_rel[i] + s_th * fx_vel[i]
               - s_th * omega_th * fz_rel[i] + c_th * fz_vel[i];
  end for;

  // Ground contact (unilateral spring-damper, smoothed Coulomb friction)
  for i in 1:4 loop
    penetration[i] = max(0.0, -foot_z[i]);
    in_contact[i] = penetration[i] > 0.0;
    GRF_n[i] = max(0.0, k_gnd * penetration[i] - d_gnd * foot_vz[i]);
    GRF_x[i] = -GRF_n[i] * mu * tanh((foot_vx[i] - r_wheel * dwphi[i]) / v_eps);
    GRF_y[i] = -GRF_n[i] * mu * tanh(foot_vy[i] / v_eps);
  end for;

  // Jacobians (leg frame)
  for i in 1:4 loop
    J11[i] = L1 * c_q1[i] + L2 * c_q12[i];
    J12[i] = L2 * c_q12[i];
    J21[i] = L1 * s_q1[i] + L2 * s_q12[i];
    J22[i] = L2 * s_q12[i];
  end for;

  // Controller sampling at 250 Hz
  when sample(0, dt_ctrl) then
    x_c = x;
    vx_c = vx;
    y_c = y;
    vy_c = vy;
    z_c = z;
    vz_c = vz;
    theta_c = theta;
    omega_th_c = omega_th;
    phi_c = phi;
    omega_ph_c = omega_ph;
    for i in 1:4 loop
      q1_c[i] = q1[i];
      dq1_c[i] = dq1[i];
      q2_c[i] = q2[i];
      dq2_c[i] = dq2[i];
    end for;
  end when;

  // Whole-body balance control
  for i in 1:4 loop
    q1_des[i] = q1_nom + kp_pitch * theta_c + kd_pitch * omega_th_c
                         - kp_x * x_c - kd_x * vx_c;
    q2_des[i] = q2_nom - kp_z * (z_c - z_eq) - kd_z * vz_c
              + roll_sign[i] * (kp_roll * (phi_c + kp_y * y_c + kd_y * vy_c)
                               + kd_roll * omega_ph_c);

    tau1_cmd[i] = tau1_ff + kp_joint * (q1_des[i] - q1_c[i])
                         + kd_joint * (0.0 - dq1_c[i]);
    tau2_cmd[i] = tau2_ff + kp_joint * (q2_des[i] - q2_c[i])
                         + kd_joint * (0.0 - dq2_c[i]);
    tau_w_cmd[i] = -kd_x * vx_c * 0.05;

    // Contact switching and torque saturation
    tau1[i] = if in_contact[i] then
                max(-tau_max, min(tau_max, tau1_cmd[i]))
              else
                max(-tau_max, min(tau_max, 0.1 * tau1_cmd[i]));
    tau2[i] = if in_contact[i] then
                max(-tau_max, min(tau_max, tau2_cmd[i]))
              else
                max(-tau_max, min(tau_max, 0.1 * tau2_cmd[i]));
    tau_w[i] = max(-tau_max, min(tau_max, tau_w_cmd[i]));
  end for;

  // Simulated IMU
  imu_ax = Fx_total / m_body;
  imu_ay = Fy_total / m_body;
  imu_wx = omega_ph;
  imu_wy = omega_th;

  // Estimator corrections (force-qualified stance contacts)
  contact_corr_theta = ((if GRF_n[1] > F_contact_thresh then theta - theta_est else 0.0)
    + (if GRF_n[2] > F_contact_thresh then theta - theta_est else 0.0)
    + (if GRF_n[3] > F_contact_thresh then theta - theta_est else 0.0)
    + (if GRF_n[4] > F_contact_thresh then theta - theta_est else 0.0)) / 4.0;
  contact_corr_phi = ((if GRF_n[1] > F_contact_thresh then phi - phi_est else 0.0)
    + (if GRF_n[2] > F_contact_thresh then phi - phi_est else 0.0)
    + (if GRF_n[3] > F_contact_thresh then phi - phi_est else 0.0)
    + (if GRF_n[4] > F_contact_thresh then phi - phi_est else 0.0)) / 4.0;
  contact_corr_vx = ((if GRF_n[1] > F_contact_thresh then vx - vx_est else 0.0)
    + (if GRF_n[2] > F_contact_thresh then vx - vx_est else 0.0)
    + (if GRF_n[3] > F_contact_thresh then vx - vx_est else 0.0)
    + (if GRF_n[4] > F_contact_thresh then vx - vx_est else 0.0)) / 4.0;
  contact_corr_vy = ((if GRF_n[1] > F_contact_thresh then vy - vy_est else 0.0)
    + (if GRF_n[2] > F_contact_thresh then vy - vy_est else 0.0)
    + (if GRF_n[3] > F_contact_thresh then vy - vy_est else 0.0)
    + (if GRF_n[4] > F_contact_thresh then vy - vy_est else 0.0)) / 4.0;
  contact_corr_x = ((if GRF_n[1] > F_contact_thresh then x - x_est else 0.0)
    + (if GRF_n[2] > F_contact_thresh then x - x_est else 0.0)
    + (if GRF_n[3] > F_contact_thresh then x - x_est else 0.0)
    + (if GRF_n[4] > F_contact_thresh then x - x_est else 0.0)) / 4.0;
  contact_corr_y = ((if GRF_n[1] > F_contact_thresh then y - y_est else 0.0)
    + (if GRF_n[2] > F_contact_thresh then y - y_est else 0.0)
    + (if GRF_n[3] > F_contact_thresh then y - y_est else 0.0)
    + (if GRF_n[4] > F_contact_thresh then y - y_est else 0.0)) / 4.0;

  // Complementary filter estimator
  der(theta_est) = imu_wy + alpha_est * contact_corr_theta;
  der(phi_est) = imu_wx + alpha_est * contact_corr_phi;
  der(vx_est) = imu_ax + alpha_est * contact_corr_vx;
  der(vy_est) = imu_ay + alpha_est * contact_corr_vy;
  der(x_est) = vx_est + alpha_est * contact_corr_x;
  der(y_est) = vy_est + alpha_est * contact_corr_y;

  // Base forces and moments
  Fx_total = GRF_x[1] + GRF_x[2] + GRF_x[3] + GRF_x[4];
  Fy_total = GRF_y[1] + GRF_y[2] + GRF_y[3] + GRF_y[4] + F_dist;
  Fz_total = GRF_n[1] + GRF_n[2] + GRF_n[3] + GRF_n[4] - m_body * grav;
  M_pitch = (hip_x[1] - x) * GRF_n[1] - (hip_z[1] - z) * GRF_x[1]
          + (hip_x[2] - x) * GRF_n[2] - (hip_z[2] - z) * GRF_x[2]
          + (hip_x[3] - x) * GRF_n[3] - (hip_z[3] - z) * GRF_x[3]
          + (hip_x[4] - x) * GRF_n[4] - (hip_z[4] - z) * GRF_x[4];
  M_roll = -(hip_y[1] - y) * GRF_n[1] + (hip_z[1] - z) * GRF_y[1]
         - (hip_y[2] - y) * GRF_n[2] + (hip_z[2] - z) * GRF_y[2]
         - (hip_y[3] - y) * GRF_n[3] + (hip_z[3] - z) * GRF_y[3]
         - (hip_y[4] - y) * GRF_n[4] + (hip_z[4] - z) * GRF_y[4];

  // Base dynamics
  der(x) = vx;
  der(vx) = Fx_total / m_body;
  der(y) = vy;
  der(vy) = Fy_total / m_body;
  der(z) = vz;
  der(vz) = Fz_total / m_body;
  der(theta) = omega_th;
  der(omega_th) = M_pitch / I_pitch;
  der(phi) = omega_ph;
  der(omega_ph) = M_roll / I_roll;

  // Leg joint dynamics
  for i in 1:4 loop
    der(q1[i]) = dq1[i];
    der(dq1[i]) = (tau1[i]
                   - (J11[i] * GRF_x[i] + J21[i] * GRF_n[i])
                   - m_leg * grav * (L1 / 2.0) * s_q1[i]
                   - m_leg * grav * (L2 / 2.0) * s_q12[i])
                  / J_leg;
    der(q2[i]) = dq2[i];
    der(dq2[i]) = (tau2[i]
                   - (J12[i] * GRF_x[i] + J22[i] * GRF_n[i])
                   - m_leg * grav * (L2 / 2.0) * s_q12[i])
                  / J_leg;
  end for;

  // Wheel dynamics
  for i in 1:4 loop
    der(wphi[i]) = dwphi[i];
    der(dwphi[i]) = (tau_w[i] - GRF_x[i] * r_wheel - b_wheel * dwphi[i]) / J_wheel;
  end for;

  // Slip accumulation
  for i in 1:4 loop
    der(slip_accum[i]) = if in_contact[i] then
        sqrt(foot_vx[i] * foot_vx[i] + foot_vy[i] * foot_vy[i])
      else
        0.0;
  end for;

  // Acceptance criteria
  tracking_error = abs(theta) + abs(phi);
  max_slip = max({slip_accum[1], slip_accum[2], slip_accum[3], slip_accum[4]});

  no_slip_ok = max_slip <= slip_limit;
  height_ok = z > 0.0;
  tracking_ok = (time < t_check) or (tracking_error < track_limit);
  torque_ok = (abs(tau1[1]) <= tau_max + 0.001) and (abs(tau2[1]) <= tau_max + 0.001)
           and (abs(tau_w[1]) <= tau_max + 0.001) and (abs(tau1[2]) <= tau_max + 0.001)
           and (abs(tau2[2]) <= tau_max + 0.001) and (abs(tau_w[2]) <= tau_max + 0.001)
           and (abs(tau1[3]) <= tau_max + 0.001) and (abs(tau2[3]) <= tau_max + 0.001)
           and (abs(tau_w[3]) <= tau_max + 0.001) and (abs(tau1[4]) <= tau_max + 0.001)
           and (abs(tau2[4]) <= tau_max + 0.001) and (abs(tau_w[4]) <= tau_max + 0.001);
  no_nan_inf = abs(x) < 1e8 and abs(y) < 1e8 and abs(z) < 1e8
             and abs(theta) < 1e8 and abs(phi) < 1e8
             and abs(tau1[1]) < 1e8 and abs(tau2[1]) < 1e8
             and abs(x_est) < 1e8 and abs(theta_est) < 1e8
             and abs(GRF_n[1]) < 1e8;
  all_ok = no_slip_ok and height_ok and tracking_ok and torque_ok and no_nan_inf;

end WheelLegRecoverE;