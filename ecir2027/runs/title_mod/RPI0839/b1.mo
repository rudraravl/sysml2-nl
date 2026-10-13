model WheelLegRecoverE
  "Floating-base wheel-legged robot with balance recovery from lateral impulse";

  // ======================== REQUIREMENT PARAMETERS ========================
  parameter Real m_body = 28.0   "Torso mass [kg] (from requirement)";
  parameter Real r_wheel = 0.10  "Wheel radius [m] (from requirement)";
  parameter Real mu = 0.90       "Ground friction coefficient [-] (from requirement)";
  parameter Real tau_max = 60.5   "Per-joint torque limit [N.m] (from requirement)";
  parameter Real F_push = 168.0   "Lateral push force [N] (from requirement)";
  parameter Real f_ctrl = 250.0   "Control rate [Hz] (from requirement)";
  parameter Real t_sim = 16.0     "Run duration [s] (from requirement)";
  parameter Real slip_limit = 0.03 "Foot slip limit [m] (from requirement)";
  parameter Real track_limit = 0.108 "Tracking error limit [rad] (from requirement)";
  parameter Real t_check = 10.4   "Recovery check time [s] (from requirement)";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control period [s]";

  // ======================== DESIGN PARAMETERS ==============================
  parameter Real L1 = 0.20        "Upper leg link length [m]";
  parameter Real L2 = 0.20        "Lower leg link length [m]";
  parameter Real half_len = 0.20  "Half body length (hip x offset) [m]";
  parameter Real half_wid = 0.15  "Half body width (hip y offset) [m]";
  parameter Real I_pitch = 1.2    "Base pitch inertia [kg.m^2]";
  parameter Real I_roll = 1.0     "Base roll inertia [kg.m^2]";
  parameter Real J_leg = 0.02     "Leg joint reflected inertia [kg.m^2]";
  parameter Real J_wheel = 0.003  "Wheel inertia [kg.m^2]";
  parameter Real m_leg = 0.5      "Leg link mass [kg]";
  parameter Real k_gnd = 100000.0 "Ground normal stiffness [N/m]";
  parameter Real d_gnd = 1000.0   "Ground normal damping [N.s/m]";
  parameter Real grav = 9.81      "Gravitational acceleration [m/s^2]";
  parameter Real q1_nom = 0.30    "Nominal hip angle [rad]";
  parameter Real q2_nom = 0.70    "Nominal knee angle [rad]";
  parameter Real z_nom = L1 * cos(q1_nom) + L2 * cos(q1_nom + q2_nom) "Nominal body height [m]";
  parameter Real kp_joint = 400.0 "Joint PD proportional gain";
  parameter Real kd_joint = 20.0  "Joint PD derivative gain";
  parameter Real kp_pitch = 300.0 "Pitch balance gain";
  parameter Real kd_pitch = 30.0  "Pitch rate gain";
  parameter Real kp_roll = 200.0  "Roll balance gain";
  parameter Real kd_roll = 20.0   "Roll rate gain";
  parameter Real kp_z = 300.0    "Height control gain";
  parameter Real kd_z = 150.0     "Height rate gain";
  parameter Real kp_x = 800.0     "X position gain";
  parameter Real kd_x = 60.0      "X velocity gain";
  parameter Real kp_y = 300.0     "Lateral position gain";
  parameter Real kd_y = 30.0      "Lateral velocity gain";
  parameter Real v_eps = 0.01     "Friction smoothing velocity [m/s]";
  parameter Real b_wheel = 0.05   "Wheel bearing friction [N.m.s]";
  parameter Real F_contact_thresh = 5.0 "Force-qualified contact threshold [N]";
  parameter Real alpha_est = 0.1  "Estimator correction gain";

  // Gravity-compensation feedforward torques
  parameter Real J21_nom = L1 * sin(q1_nom) + L2 * sin(q1_nom + q2_nom);
  parameter Real J22_nom = L2 * sin(q1_nom + q2_nom);
  parameter Real tau1_ff = J21_nom * m_body * grav / 4.0
      + m_leg * grav * (L1 / 2.0) * sin(q1_nom)
      + m_leg * grav * (L2 / 2.0) * sin(q1_nom + q2_nom);
  parameter Real tau2_ff = J22_nom * m_body * grav / 4.0
      + m_leg * grav * (L2 / 2.0) * sin(q1_nom + q2_nom);

  // Hip offsets and roll sign for left/right legs
  parameter Real hx[4] = {half_len, half_len, -half_len, -half_len};
  parameter Real hy[4] = {half_wid, -half_wid, half_wid, -half_wid};
  parameter Real roll_sign[4] = {1.0, -1.0, 1.0, -1.0};

  // ======================== STATE VARIABLES ================================
  Real x(start = 0, fixed = true)       "Base x position [m]";
  Real vx(start = 0, fixed = true)      "Base x velocity [m/s]";
  Real y(start = 0, fixed = true)       "Base y position [m]";
  Real vy(start = 0, fixed = true)      "Base y velocity [m/s]";
  Real z(start = 0.30, fixed = true)    "Base z position [m]";
  Real vz(start = 0, fixed = true)      "Base z velocity [m/s]";
  Real theta(start = 0, fixed = true)   "Base pitch [rad]";
  Real omega_th(start = 0, fixed = true) "Base pitch rate [rad/s]";
  Real phi(start = 0, fixed = true)     "Base roll [rad]";
  Real omega_ph(start = 0, fixed = true) "Base roll rate [rad/s]";

  Real q1[4](start = {q1_nom, q1_nom, q1_nom, q1_nom}, each fixed = true) "Hip angles [rad]";
  Real dq1[4](start = {0, 0, 0, 0}, each fixed = true)                    "Hip rates [rad/s]";
  Real q2[4](start = {q2_nom, q2_nom, q2_nom, q2_nom}, each fixed = true) "Knee angles [rad]";
  Real dq2[4](start = {0, 0, 0, 0}, each fixed = true)                    "Knee rates [rad/s]";

  Real wphi[4](start = {0, 0, 0, 0}, each fixed = true)  "Wheel angles [rad]";
  Real dwphi[4](start = {0, 0, 0, 0}, each fixed = true) "Wheel rates [rad/s]";

  Real theta_est(start = 0, fixed = true) "Estimated pitch [rad]";
  Real phi_est(start = 0, fixed = true)   "Estimated roll [rad]";
  Real x_est(start = 0, fixed = true)     "Estimated x [m]";
  Real y_est(start = 0, fixed = true)     "Estimated y [m]";
  Real vx_est(start = 0, fixed = true)    "Estimated vx [m/s]";
  Real vy_est(start = 0, fixed = true)    "Estimated vy [m/s]";

  Real slip_accum[4](start = {0, 0, 0, 0}, each fixed = true) "Accumulated foot slip [m]";

  // ======================== ALGEBRAIC VARIABLES ===========================
  Real fx_rel[4]  "Foot x relative to hip in base frame [m]";
  Real fz_rel[4]  "Foot z relative to hip in base frame [m]";
  Real hip_x[4]   "Hip x world [m]";
  Real hip_y[4]   "Hip y world [m]";
  Real hip_z[4]   "Hip z world [m]";
  Real foot_x[4]  "Foot x world [m]";
  Real foot_y[4]  "Foot y world [m]";
  Real foot_z[4]  "Foot z world [m]";
  Real foot_vx[4] "Foot x velocity [m/s]";
  Real foot_vy[4] "Foot y velocity [m/s]";
  Real foot_vz[4] "Foot z velocity [m/s]";

  Real GRF_n[4]      "Normal ground reaction force [N]";
  Real GRF_x[4]      "X ground friction force [N]";
  Real GRF_y[4]      "Y ground friction force [N]";
  Real penetration[4] "Foot penetration [m]";
  Boolean in_contact[4] "Contact flag";

  Real J11[4];
  Real J12[4];
  Real J21[4];
  Real J22[4];

  Real tau1_cmd[4] "Hip torque command [N.m]";
  Real tau2_cmd[4] "Knee torque command [N.m]";
  Real tau1[4]     "Applied hip torque [N.m]";
  Real tau2[4]     "Applied knee torque [N.m]";
  Real tau_w_cmd[4] "Wheel torque command [N.m]";
  Real tau_w[4]     "Applied wheel torque [N.m]";

  Real q1_des[4] "Desired hip angle [rad]";
  Real q2_des[4] "Desired knee angle [rad]";

  discrete Real x_c(start = 0)       "Sampled x [m]";
  discrete Real vx_c(start = 0)      "Sampled vx [m/s]";
  discrete Real y_c(start = 0)       "Sampled y [m]";
  discrete Real vy_c(start = 0)      "Sampled vy [m/s]";
  discrete Real z_c(start = 0.30)    "Sampled z [m]";
  discrete Real vz_c(start = 0)      "Sampled vz [m/s]";
  discrete Real theta_c(start = 0)   "Sampled pitch [rad]";
  discrete Real omega_th_c(start = 0) "Sampled pitch rate [rad/s]";
  discrete Real phi_c(start = 0)     "Sampled roll [rad]";
  discrete Real omega_ph_c(start = 0) "Sampled roll rate [rad/s]";
  discrete Real q1_c[4](start = {q1_nom, q1_nom, q1_nom, q1_nom})  "Sampled hip angles [rad]";
  discrete Real dq1_c[4](start = {0, 0, 0, 0})                     "Sampled hip rates [rad/s]";
  discrete Real q2_c[4](start = {q2_nom, q2_nom, q2_nom, q2_nom})  "Sampled knee angles [rad]";
  discrete Real dq2_c[4](start = {0, 0, 0, 0})                     "Sampled knee rates [rad/s]";

  Real imu_ax  "IMU x acceleration [m/s^2]";
  Real imu_ay  "IMU y acceleration [m/s^2]";
  Real imu_wx  "IMU roll rate [rad/s]";
  Real imu_wy  "IMU pitch rate [rad/s]";

  Real F_dist "Lateral disturbance force [N]";

  Real Fx_total "Total x force [N]";
  Real Fy_total "Total y force [N]";
  Real Fz_total "Total z force [N]";
  Real M_pitch  "Pitch moment [N.m]";
  Real M_roll   "Roll moment [N.m]";

  Real tracking_error "Attitude tracking error [rad]";
  Real max_slip       "Maximum accumulated slip [m]";
  Real torque_violations "Torque bound violation count";
  Boolean no_slip_ok;
  Boolean height_ok;
  Boolean tracking_ok;
  Boolean torque_ok;
  Boolean no_nan_inf;
  Boolean all_ok "Fail-closed acceptance flag";

equation
  // ======================== DISTURBANCE ===================================
  F_dist = if (time >= t_sim / 3.0 and time <= 2.0 * t_sim / 3.0) then F_push else 0.0;

  // ======================== KINEMATICS =====================================
  for i in 1:4 loop
    fx_rel[i] = L1 * sin(q1[i]) + L2 * sin(q1[i] + q2[i]);
    fz_rel[i] = -(L1 * cos(q1[i]) + L2 * cos(q1[i] + q2[i]));

    hip_x[i] = x + cos(theta) * hx[i];
    hip_y[i] = y + sin(phi) * sin(theta) * hx[i] + cos(phi) * hy[i];
    hip_z[i] = z - cos(phi) * sin(theta) * hx[i] + sin(phi) * hy[i];

    foot_x[i] = hip_x[i] + cos(theta) * fx_rel[i] + sin(theta) * fz_rel[i];
    foot_y[i] = hip_y[i] + sin(phi) * sin(theta) * fx_rel[i] - sin(phi) * cos(theta) * fz_rel[i];
    foot_z[i] = hip_z[i] - cos(phi) * sin(theta) * fx_rel[i] + cos(phi) * cos(theta) * fz_rel[i];

    foot_vx[i] = der(foot_x[i]);
    foot_vy[i] = der(foot_y[i]);
    foot_vz[i] = der(foot_z[i]);
  end for;

  // ======================== GROUND CONTACT =================================
  for i in 1:4 loop
    penetration[i] = max(0, -foot_z[i]);
    in_contact[i] = penetration[i] > 0;

    GRF_n[i] = max(0, k_gnd * penetration[i] - d_gnd * foot_vz[i]);
    GRF_x[i] = -GRF_n[i] * mu * tanh((foot_vx[i] - r_wheel * dwphi[i]) / v_eps);
    GRF_y[i] = -GRF_n[i] * mu * tanh(foot_vy[i] / v_eps);
  end for;

  // ======================== JACOBIAN =======================================
  for i in 1:4 loop
    J11[i] = L1 * cos(q1[i]) + L2 * cos(q1[i] + q2[i]);
    J12[i] = L2 * cos(q1[i] + q2[i]);
    J21[i] = L1 * sin(q1[i]) + L2 * sin(q1[i] + q2[i]);
    J22[i] = L2 * sin(q1[i] + q2[i]);
  end for;

  // ======================== CONTROLLER (250 Hz) ===========================
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

  for i in 1:4 loop
    q1_des[i] = q1_nom + kp_pitch * theta_c + kd_pitch * omega_th_c
                         - kp_x * x_c - kd_x * vx_c;

    q2_des[i] = q2_nom + kp_z * (z_c - z_nom) + kd_z * vz_c
              - roll_sign[i] * (kp_roll * (phi_c + kp_y * y_c + kd_y * vy_c)
                               + kd_roll * omega_ph_c);
  end for;

  for i in 1:4 loop
    tau1_cmd[i] = tau1_ff + kp_joint * (q1_des[i] - q1_c[i])
                         + kd_joint * (0.0 - dq1_c[i]);
    tau2_cmd[i] = tau2_ff + kp_joint * (q2_des[i] - q2_c[i])
                         + kd_joint * (0.0 - dq2_c[i]);
    tau_w_cmd[i] = -kd_x * vx_c * 0.05;

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

  // ======================== ESTIMATOR ======================================
  imu_ax = Fx_total / m_body;
  imu_ay = Fy_total / m_body;
  imu_wx = omega_ph;
  imu_wy = omega_th;

  der(theta_est) = imu_wy + alpha_est * sum(
      if GRF_n[i] > F_contact_thresh then (theta - theta_est) / 4.0 else 0.0
      for i in 1:4);
  der(phi_est) = imu_wx + alpha_est * sum(
      if GRF_n[i] > F_contact_thresh then (phi - phi_est) / 4.0 else 0.0
      for i in 1:4);
  der(vx_est) = imu_ax + alpha_est * sum(
      if GRF_n[i] > F_contact_thresh then (vx - vx_est) / 4.0 else 0.0
      for i in 1:4);
  der(vy_est) = imu_ay + alpha_est * sum(
      if GRF_n[i] > F_contact_thresh then (vy - vy_est) / 4.0 else 0.0
      for i in 1:4);
  der(x_est) = vx_est + alpha_est * sum(
      if GRF_n[i] > F_contact_thresh then (x - x_est) / 4.0 else 0.0
      for i in 1:4);
  der(y_est) = vy_est + alpha_est * sum(
      if GRF_n[i] > F_contact_thresh then (y - y_est) / 4.0 else 0.0
      for i in 1:4);

  // ======================== DYNAMICS =======================================
  Fx_total = sum(GRF_x);
  Fy_total = sum(GRF_y) + F_dist;
  Fz_total = sum(GRF_n) - m_body * grav;
  M_pitch = sum((hip_x[i] - x) * GRF_n[i] - (hip_z[i] - z) * GRF_x[i] for i in 1:4);
  M_roll  = sum(-(hip_y[i] - y) * GRF_n[i] + (hip_z[i] - z) * GRF_y[i] for i in 1:4);

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

  for i in 1:4 loop
    der(q1[i]) = dq1[i];
    der(dq1[i]) = (tau1[i]
                   - (J11[i] * GRF_x[i] + J21[i] * GRF_n[i])
                   - m_leg * grav * (L1 / 2.0) * sin(q1[i])
                   - m_leg * grav * (L2 / 2.0) * sin(q1[i] + q2[i]))
                  / J_leg;
    der(q2[i]) = dq2[i];
    der(dq2[i]) = (tau2[i]
                   - (J12[i] * GRF_x[i] + J22[i] * GRF_n[i])
                   - m_leg * grav * (L2 / 2.0) * sin(q1[i] + q2[i]))
                  / J_leg;
  end for;

  for i in 1:4 loop
    der(wphi[i]) = dwphi[i];
    der(dwphi[i]) = (tau_w[i] - GRF_x[i] * r_wheel - b_wheel * dwphi[i]) / J_wheel;
  end for;

  for i in 1:4 loop
    der(slip_accum[i]) = if in_contact[i] then
        sqrt(foot_vx[i] * foot_vx[i] + foot_vy[i] * foot_vy[i])
      else
        0.0;
  end for;

  // ======================== ACCEPTANCE CRITERIA ===========================
  tracking_error = abs(theta) + abs(phi);
  max_slip = max(slip_accum);

  no_slip_ok = max_slip <= slip_limit;
  height_ok = z > 0.0;
  tracking_ok = (time < t_check) or (tracking_error < track_limit);

  torque_violations = sum(
      if (abs(tau1[i]) > tau_max + 0.001 or
          abs(tau2[i]) > tau_max + 0.001 or
          abs(tau_w[i]) > tau_max + 0.001)
        then 1.0 else 0.0
      for i in 1:4);
  torque_ok = torque_violations < 0.5;

  no_nan_inf = abs(x) < 1e8 and abs(y) < 1e8 and abs(z) < 1e8
              and abs(theta) < 1e8 and abs(phi) < 1e8
              and abs(tau1[1]) < 1e8 and abs(tau2[1]) < 1e8
              and abs(x_est) < 1e8 and abs(theta_est) < 1e8
              and abs(GRF_n[1]) < 1e8;

  all_ok = no_slip_ok and height_ok and tracking_ok and torque_ok and no_nan_inf;

end WheelLegRecoverE;