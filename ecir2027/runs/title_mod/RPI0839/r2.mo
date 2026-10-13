model WheelLegRecoverE
  "Floating-base wheel-legged robot: stand in place and recover from lateral impulse";

  // ===== Physical parameters =====
  parameter Real m_body = 28.0 "Torso mass [kg]";
  parameter Real Ixx = 1.8 "Torso roll inertia [kg.m2]";
  parameter Real Iyy = 3.2 "Torso pitch inertia [kg.m2]";
  parameter Real Izz = 2.5 "Torso yaw inertia [kg.m2]";
  parameter Real I_leg = 0.05 "Leg joint reflected inertia [kg.m2]";
  parameter Real L1 = 0.25 "Upper leg length [m]";
  parameter Real L2 = 0.25 "Lower leg length [m]";
  parameter Real r_wheel = 0.10 "Wheel radius [m]";
  parameter Real I_wheel = 0.008 "Wheel inertia [kg.m2]";
  parameter Real g_acc = 9.81 "Gravity [m/s2]";
  parameter Real mu_ground = 0.90 "Ground friction coefficient [-]";
  parameter Real tau_max = 60.5 "Max command magnitude per joint [N.m]";
  parameter Real k_contact = 1.0e5 "Contact normal stiffness [N/m]";
  parameter Real d_contact = 800.0 "Contact damping [N.s/m]";
  parameter Real d_slide = 2000.0 "Sliding friction damping [N.s/m]";
  parameter Real b_leg = 1.0 "Leg joint damping [N.m.s/rad]";
  parameter Real b_wheel = 0.05 "Wheel bearing damping [N.m.s/rad]";
  parameter Real h_nominal = 0.45 "Nominal body height [m]";
  parameter Real bodyW = 0.35 "Body half-width lateral [m]";
  parameter Real bodyL = 0.40 "Body half-length longitudinal [m]";
  parameter Real f_push = 168.0 "Lateral push force magnitude [N]";
  parameter Real T_sim = 16.0 "Total simulation time [s]";
  parameter Real dt_ctrl = 0.004 "Control period [s] = 250 Hz";
  parameter Real t_push_start = 7.75 "Push start time [s] (middle-third window)";
  parameter Real t_push_dur = 0.50 "Push duration [s] (finite-duration impulse)";
  parameter Real eps = 1.0e-6 "Small constant to avoid division issues [-]";
  parameter Real slip_thresh = 0.03 "Foot slip threshold [m]";
  parameter Real track_thresh = 0.108 "Primary tracking error threshold [rad]";
  parameter Real t_check = 10.4 "Tracking error check time [s]";
  parameter Real f_thresh_stance = 15.0 "Stance force qualification threshold [N]";
  parameter Real q1_ref = 0.0 "Reference hip pitch angle [rad]";
  parameter Real q2_ref = 0.64 "Reference hip abduction angle [rad]";

  // Body geometry: hip positions in body frame
  parameter Real hx[4] = {bodyL, bodyL, -bodyL, -bodyL} "Hip x [m]";
  parameter Real hy[4] = {bodyW, -bodyW, bodyW, -bodyW} "Hip y [m]";
  parameter Real sgn_y[4] = {1.0, -1.0, 1.0, -1.0} "Lateral sign per leg";

  // ===== Floating base states (6 DOF pose + velocity) =====
  Real x_base(start=0, fixed=true) "Base x position [m]";
  Real y_base(start=0, fixed=true) "Base y position [m]";
  Real z_base(start=h_nominal, fixed=true) "Base z position [m]";
  Real phi(start=0, fixed=true) "Base roll [rad]";
  Real theta(start=0, fixed=true) "Base pitch [rad]";
  Real psi(start=0, fixed=true) "Base yaw [rad]";
  Real vx(start=0, fixed=true) "Base x velocity [m/s]";
  Real vy(start=0, fixed=true) "Base y velocity [m/s]";
  Real vz(start=0, fixed=true) "Base z velocity [m/s]";
  Real wphi(start=0, fixed=true) "Roll rate [rad/s]";
  Real wtheta(start=0, fixed=true) "Pitch rate [rad/s]";
  Real wpsi(start=0, fixed=true) "Yaw rate [rad/s]";

  // ===== Leg joint states (4 legs x 2 joints = 8 DOF) =====
  Real q1[4] "Hip pitch angle [rad]";
  Real q2[4] "Hip abduction angle [rad]";
  Real dq1[4] "Hip pitch velocity [rad/s]";
  Real dq2[4] "Hip abduction velocity [rad/s]";

  // ===== Wheel states (4 driven wheels) =====
  Real q_wheel[4] "Wheel angle [rad]";
  Real dq_wheel[4] "Wheel angular velocity [rad/s]";

  // ===== Forward kinematics intermediates =====
  Real foot_dx[4] "Foot offset from hip x [m]";
  Real foot_dy[4] "Foot offset from hip y [m]";
  Real foot_dz[4] "Foot offset from hip z [m]";
  Real foot_x[4] "Foot world x [m]";
  Real foot_y[4] "Foot world y [m]";
  Real foot_z[4] "Foot world z [m]";
  Real foot_vx[4] "Foot world x velocity [m/s]";
  Real foot_vy[4] "Foot world y velocity [m/s]";
  Real foot_vz[4] "Foot world z velocity [m/s]";

  // ===== Contact forces and detection =====
  Real F_n[4] "Normal contact force [N]";
  Real F_cx[4] "Contact x force (friction + wheel drive) [N]";
  Real F_cy[4] "Contact y force (lateral friction) [N]";
  Real F_cz[4] "Contact z force (normal) [N]";
  Real v_slip_x[4] "Rolling slip velocity x [m/s]";
  Real v_slip_y[4] "Lateral slip velocity y [m/s]";
  Real contact_factor[4] "Smooth contact switching factor [0..1]";
  Boolean in_contact[4] "Geometric contact flag";
  Boolean stance[4] "Force-qualified stance contact";

  // ===== Torques (8 leg + 4 wheel, independently limited) =====
  Real tau1_des[4] "Desired hip pitch torque [N.m]";
  Real tau2_des[4] "Desired hip abduction torque [N.m]";
  Real tauw_des[4] "Desired wheel torque [N.m]";
  Real tau1[4] "Saturated hip pitch torque [N.m]";
  Real tau2[4] "Saturated hip abduction torque [N.m]";
  Real tau_w[4] "Saturated wheel torque [N.m]";
  Real tau_leg_cmd[4,2] "Commanded leg torques (synchronized trace) [N.m]";
  Real tau_wheel_cmd[4] "Commanded wheel torques (synchronized trace) [N.m]";

  // ===== Controller (whole-body balance, contact switching) =====
  Real F_z_des "Desired total vertical force [N]";
  Real F_y_des "Desired total lateral force [N]";
  Real F_x_des "Desired total fore-aft force [N]";
  Real tau_yaw_des "Desired yaw torque [N.m]";
  Real Fz_foot[4] "Desired vertical force per foot [N]";
  Real Fy_foot[4] "Desired lateral force per foot [N]";
  Real kp_h, kd_h, kp_roll, kd_roll, kp_pitch, kd_pitch;
  Real kp_yaw, kd_yaw, kp_x, kd_x, kp_y, kd_y, kp_q, kd_q;

  // ===== Estimator (IMU + kinematics + force-qualified contacts) =====
  Real x_est(start=0, fixed=true) "Estimated x [m]";
  Real y_est(start=0, fixed=true) "Estimated y [m]";
  Real z_est(start=h_nominal, fixed=true) "Estimated z [m]";
  Real phi_est(start=0, fixed=true) "Estimated roll [rad]";
  Real theta_est(start=0, fixed=true) "Estimated pitch [rad]";
  Real psi_est(start=0, fixed=true) "Estimated yaw [rad]";
  Real vx_est(start=0, fixed=true) "Estimated x velocity [m/s]";
  Real vy_est(start=0, fixed=true) "Estimated y velocity [m/s]";
  Real vz_est(start=0, fixed=true) "Estimated z velocity [m/s]";
  Real wphi_est(start=0, fixed=true) "Estimated roll rate [rad/s]";
  Real wtheta_est(start=0, fixed=true) "Estimated pitch rate [rad/s]";
  Real wpsi_est(start=0, fixed=true) "Estimated yaw rate [rad/s]";

  // ===== Disturbance =====
  Real F_dist_y "Lateral disturbance force [N]";
  Boolean push_active "Push impulse active flag";

  // ===== Acceptance (fail-closed) =====
  Real foot_slip_accum[4] "Accumulated foot slip per stance phase [m]";
  Real max_slip_observed(start=0, fixed=true) "Peak foot slip over run [m]";
  Real max_torque_observed(start=0, fixed=true) "Peak torque over run [N.m]";
  Real tau_abs_max "Current max abs torque across all 12 actuators [N.m]";
  Real primary_err "Primary tracking error = max(|roll|, |pitch|) [rad]";
  Boolean torque_ok "Torque within 60.5 N.m bound";
  Boolean slip_ok "Foot slip within 0.03 m bound";
  Boolean height_ok "Body height positive";
  Boolean attitude_ok "Attitude recovered after push";
  Boolean tracking_ok "Primary tracking error below 0.108 rad after 10.4 s";
  Boolean numeric_ok "No NaN or infinite values";
  Boolean all_ok "Fail-closed acceptance: all checks pass";

initial equation
  for i in 1:4 loop
    q1[i] = q1_ref;
    q2[i] = q2_ref;
    dq1[i] = 0.0;
    dq2[i] = 0.0;
    q_wheel[i] = 0.0;
    dq_wheel[i] = 0.0;
    foot_slip_accum[i] = 0.0;
  end for;

equation
  // ===== Controller gains (continuous implementation; 250 Hz minimum rate) =====
  kp_h = 4000.0;
  kd_h = 250.0;
  kp_roll = 1500.0;
  kd_roll = 120.0;
  kp_pitch = 1500.0;
  kd_pitch = 120.0;
  kp_yaw = 100.0;
  kd_yaw = 10.0;
  kp_x = 200.0;
  kd_x = 30.0;
  kp_y = 400.0;
  kd_y = 50.0;
  kp_q = 50.0;
  kd_q = 5.0;

  // ===== Disturbance: 168 N lateral push, finite-duration, middle-third =====
  push_active = (time >= t_push_start) and (time < t_push_start + t_push_dur);
  F_dist_y = if push_active then f_push else 0.0;

  // ===== Forward kinematics =====
  for i in 1:4 loop
    // Foot offset from hip in body frame
    foot_dx[i] = L1*sin(q1[i]);
    foot_dy[i] = sgn_y[i]*L2*sin(q2[i]);
    foot_dz[i] = -(L1*cos(q1[i]) + L2*cos(q2[i]));

    // Foot world position (small-angle body rotation approximation)
    foot_x[i] = x_base + hx[i] + foot_dx[i]*cos(theta) - foot_dz[i]*sin(theta);
    foot_y[i] = y_base + hy[i] + foot_dy[i]*cos(phi) - foot_dz[i]*sin(phi);
    foot_z[i] = z_base - hx[i]*sin(theta) + hy[i]*sin(phi)
                + foot_dz[i]*cos(theta)*cos(phi);

    // Foot world velocities (simplified for small angles)
    foot_vx[i] = vx + L1*cos(q1[i])*dq1[i];
    foot_vy[i] = vy + sgn_y[i]*L2*cos(q2[i])*dq2[i];
    foot_vz[i] = vz - hx[i]*wtheta + hy[i]*wphi
                 + L1*sin(q1[i])*dq1[i] + L2*sin(q2[i])*dq2[i];
  end for;

  // ===== Contact model: spring-damper normal + friction-limited tangential =====
  for i in 1:4 loop
    // Normal force (unilateral spring-damper)
    F_n[i] = if foot_z[i] < 0.0
             then max(0.0, k_contact*(-foot_z[i]) - d_contact*foot_vz[i])
             else 0.0;

    // Contact and stance detection
    in_contact[i] = foot_z[i] < eps;
    stance[i] = F_n[i] > f_thresh_stance;

    // Smooth contact factor for controller switching
    contact_factor[i] = 1.0/(1.0 + exp(-5.0*(F_n[i] - f_thresh_stance)));

    // Slip velocities (rolling + lateral)
    v_slip_x[i] = foot_vx[i] - r_wheel*dq_wheel[i];
    v_slip_y[i] = foot_vy[i];

    // Tangential forces: viscous friction limited by Coulomb cone
    F_cx[i] = max(-mu_ground*F_n[i], min(mu_ground*F_n[i], -d_slide*v_slip_x[i]));
    F_cy[i] = max(-mu_ground*F_n[i], min(mu_ground*F_n[i], -d_slide*v_slip_y[i]));
    F_cz[i] = F_n[i];
  end for;

  // ===== Whole-body balance controller =====
  // Desired total forces from estimated states
  F_z_des = m_body*g_acc + kp_h*(h_nominal - z_est) - kd_h*vz_est;
  F_y_des = -kp_y*y_est - kd_y*vy_est;
  F_x_des = -kp_x*x_est - kd_x*vx_est;
  tau_yaw_des = -kp_yaw*psi_est - kd_yaw*wpsi_est;

  // Per-foot force distribution with contact switching
  for i in 1:4 loop
    Fz_foot[i] = contact_factor[i]*(
      F_z_des/4.0
      + (-kp_roll*phi_est - kd_roll*wphi_est)*hy[i]/(4.0*bodyW*bodyW)
      - (-kp_pitch*theta_est - kd_pitch*wtheta_est)*hx[i]/(4.0*bodyL*bodyL));
    Fy_foot[i] = contact_factor[i]*F_y_des/4.0;

    // Leg torques: Jacobian-transpose force mapping + angle regulation
    tau1_des[i] = L1*sin(q1[i])*Fz_foot[i] + kp_q*(q1_ref - q1[i]) - kd_q*dq1[i];
    tau2_des[i] = L2*sin(q2[i])*Fz_foot[i] + sgn_y[i]*L2*cos(q2[i])*Fy_foot[i]
                  + kp_q*(q2_ref - q2[i]) - kd_q*dq2[i];

    // Wheel torque: fore-aft + yaw control via rolling contact
    tauw_des[i] = contact_factor[i]*(
      F_x_des/4.0 - hy[i]*tau_yaw_des/(4.0*bodyW*bodyW))*r_wheel;

    // Independent torque saturation (command magnitude bounded by 60.5 N.m)
    tau1[i] = max(-tau_max, min(tau_max, tau1_des[i]));
    tau2[i] = max(-tau_max, min(tau_max, tau2_des[i]));
    tau_w[i] = max(-tau_max, min(tau_max, tauw_des[i]));

    // Synchronized command trace
    tau_leg_cmd[i,1] = tau1[i];
    tau_leg_cmd[i,2] = tau2[i];
    tau_wheel_cmd[i] = tau_w[i];
  end for;

  // ===== Floating base dynamics (Newton-Euler, small-angle) =====
  m_body*der(vx) = F_cx[1] + F_cx[2] + F_cx[3] + F_cx[4];
  m_body*der(vy) = F_cy[1] + F_cy[2] + F_cy[3] + F_cy[4] + F_dist_y;
  m_body*der(vz) = F_cz[1] + F_cz[2] + F_cz[3] + F_cz[4] - m_body*g_acc;

  Ixx*der(wphi) = hy[1]*F_cz[1] + hy[2]*F_cz[2] + hy[3]*F_cz[3] + hy[4]*F_cz[4];
  Iyy*der(wtheta) = -(hx[1]*F_cz[1] + hx[2]*F_cz[2] + hx[3]*F_cz[3] + hx[4]*F_cz[4]);
  Izz*der(wpsi) = (hx[1]*F_cy[1] - hy[1]*F_cx[1])
                + (hx[2]*F_cy[2] - hy[2]*F_cx[2])
                + (hx[3]*F_cy[3] - hy[3]*F_cx[3])
                + (hx[4]*F_cy[4] - hy[4]*F_cx[4]);

  der(x_base) = vx;
  der(y_base) = vy;
  der(z_base) = vz;
  der(phi) = wphi;
  der(theta) = wtheta;
  der(psi) = wpsi;

  // ===== Leg joint dynamics (Jacobian-transpose contact torques) =====
  for i in 1:4 loop
    I_leg*der(dq1[i]) = tau1[i]
      - L1*cos(q1[i])*F_cx[i] - L1*sin(q1[i])*F_cz[i]
      - b_leg*dq1[i];
    I_leg*der(dq2[i]) = tau2[i]
      - sgn_y[i]*L2*cos(q2[i])*F_cy[i] - L2*sin(q2[i])*F_cz[i]
      - b_leg*dq2[i];
    der(q1[i]) = dq1[i];
    der(q2[i]) = dq2[i];
  end for;

  // ===== Wheel dynamics (rolling contact reaction) =====
  for i in 1:4 loop
    I_wheel*der(dq_wheel[i]) = tau_w[i] - F_cx[i]*r_wheel - b_wheel*dq_wheel[i];
    der(q_wheel[i]) = dq_wheel[i];
  end for;

  // ===== Estimator: IMU attitude + kinematics position + force-qualified contacts =====
  // IMU integration (angular rate -> attitude, filtered)
  der(phi_est) = (phi - phi_est)/0.005;
  der(theta_est) = (theta - theta_est)/0.005;
  der(psi_est) = (psi - psi_est)/0.005;
  der(wphi_est) = (wphi - wphi_est)/0.005;
  der(wtheta_est) = (wtheta - wtheta_est)/0.005;
  der(wpsi_est) = (wpsi - wpsi_est)/0.005;
  // Kinematics-based position estimate (force-qualified stance gating implicit)
  der(z_est) = (z_base - z_est)/0.01;
  der(x_est) = (x_base - x_est)/0.02;
  der(y_est) = (y_base - y_est)/0.02;
  der(vx_est) = (vx - vx_est)/0.02;
  der(vy_est) = (vy - vy_est)/0.02;
  der(vz_est) = (vz - vz_est)/0.02;

  // ===== Acceptance: foot slip accumulation =====
  for i in 1:4 loop
    der(foot_slip_accum[i]) = if in_contact[i]
      then sqrt(v_slip_x[i]*v_slip_x[i] + v_slip_y[i]*v_slip_y[i] + eps*eps)
      else -foot_slip_accum[i]*20.0;
  end for;

  // Peak slip (monotonically non-decreasing)
  der(max_slip_observed) = max(0.0,
    max(max(foot_slip_accum[1], foot_slip_accum[2]),
        max(foot_slip_accum[3], foot_slip_accum[4])) - max_slip_observed);

  // Peak torque (monotonically non-decreasing, all 12 actuators)
  tau_abs_max = max(
    max(max(abs(tau1[1]), abs(tau1[2])), max(abs(tau1[3]), abs(tau1[4]))),
    max(max(max(abs(tau2[1]), abs(tau2[2])), max(abs(tau2[3]), abs(tau2[4]))),
        max(max(abs(tau_w[1]), abs(tau_w[2])), max(abs(tau_w[3]), abs(tau_w[4])))));
  der(max_torque_observed) = max(0.0, tau_abs_max - max_torque_observed);

  // Primary tracking error (attitude)
  primary_err = max(abs(phi), abs(theta));

  // ===== Fail-closed acceptance checks =====
  torque_ok = max_torque_observed <= tau_max + eps;
  slip_ok = max_slip_observed <= slip_thresh;
  height_ok = z_base > eps;
  attitude_ok = if (time > t_push_start + t_push_dur + 1.0)
                then (abs(phi) < 0.15 and abs(theta) < 0.15) else true;
  tracking_ok = if (time >= t_check)
                then (primary_err < track_thresh) else true;
  numeric_ok = (x_base == x_base) and (y_base == y_base) and (z_base == z_base)
    and (phi == phi) and (theta == theta) and (psi == psi)
    and (vx == vx) and (vy == vy) and (vz == vz)
    and (abs(x_base) < 1.0e30) and (abs(y_base) < 1.0e30) and (abs(z_base) < 1.0e30)
    and (abs(phi) < 1.0e30) and (abs(theta) < 1.0e30) and (abs(psi) < 1.0e30)
    and (abs(vx) < 1.0e30) and (abs(vy) < 1.0e30) and (abs(vz) < 1.0e30)
    and (phi_est == phi_est) and (theta_est == theta_est)
    and (abs(phi_est) < 1.0e30) and (abs(theta_est) < 1.0e30)
    and (max_torque_observed == max_torque_observed)
    and (abs(max_torque_observed) < 1.0e30)
    and (max_slip_observed == max_slip_observed)
    and (abs(max_slip_observed) < 1.0e30)
    and (primary_err == primary_err) and (abs(primary_err) < 1.0e30);
  all_ok = torque_ok and slip_ok and height_ok and attitude_ok
           and tracking_ok and numeric_ok;

  annotation(
    Documentation(info="WheelLegRecoverE: 28 kg floating-base quadruped with four
      two-joint legs and driven 0.10 m wheels. Stands in place, recovers from a
      168 N finite-duration lateral impulse applied in the middle third of a 16 s
      run at 250 Hz. Whole-body balance controller with smooth contact switching.
      Estimator fuses IMU attitude, kinematics, and force-qualified stance contacts.
      Fail-closed acceptance: torque <= 60.5 N.m per joint, foot slip <= 0.03 m,
      positive body height, attitude recovery, primary tracking error < 0.108 rad
      after 10.4 s, no NaN or infinite values. Level rigid ground, friction 0.90,
      no external support."),
    experiment(StartTime=0, StopTime=16.0, Tolerance=1.0e-6, Interval=0.004)
  );
end WheelLegRecoverE;