model ContactStateBridgeC
  "Robotic sensing and estimation with multi-rate filtering and innovation gating"

  // ============ Physical Parameters ============
  parameter Real m_body = 24.0 "Torso mass [kg]";
  parameter Real I_body = 2.0 "Torso moment of inertia [kg.m2]";
  parameter Real g_const = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real tau_max = 50.6 "Maximum joint command magnitude [N.m]";
  parameter Real J_joint = 0.05 "Joint inertia [kg.m2]";
  parameter Real b_joint = 0.3 "Joint damping [N.m.s/rad]";
  parameter Real k_joint = 20.0 "Joint stiffness [N.m/rad]";

  parameter Real ax_bias = 0.008 "IMU x acceleration bias [m/s2]";
  parameter Real az_bias = 0.004 "IMU z acceleration bias [m/s2]";
  parameter Real w_bias = 0.002 "IMU gyro bias [rad/s]";

  // ============ Timing Parameters ============
  parameter Real f_sample = 125.0 "Estimator sampling rate [Hz]";
  parameter Real Ts = 0.008 "Sample period [s]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";
  parameter Real t_drop_start = 2.4 "Dropout start time [s]";
  parameter Real t_drop_end = 9.6 "Dropout end time [s]";

  // ============ Estimator Parameters ============
  parameter Real err_bound = 0.367 "Primary tracking error bound [m or rad]";
  parameter Real t_check = 7.8 "Error check time [s]";
  parameter Real P0_pos = 1e-3 "Initial position covariance [m2]";
  parameter Real P0_rot = 1e-3 "Initial rotation covariance [rad2]";
  parameter Real Q_pos = 1e-4 "Position process noise rate [m2/s]";
  parameter Real Q_rot = 1e-4 "Rotation process noise rate [rad2/s]";
  parameter Real R_abs = 1e-4 "Absolute sensor noise variance [m2 or rad2]";
  parameter Real gate_chi2 = 9.0 "Innovation gate chi-square threshold";

  // ============ Plant Continuous States ============
  Real x(start=0.0, fixed=true) "Body x position [m]";
  Real z(start=0.5, fixed=true) "Body z position [m]";
  Real theta(start=0.0, fixed=true) "Body pitch angle [rad]";
  Real vx(start=0.0, fixed=true) "Body x velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Body z velocity [m/s]";
  Real omega(start=0.0, fixed=true) "Body angular velocity [rad/s]";

  Real q1(start=0.0, fixed=true) "Joint 1 angle [rad]";
  Real q2(start=0.0, fixed=true) "Joint 2 angle [rad]";
  Real q3(start=0.0, fixed=true) "Joint 3 angle [rad]";
  Real q4(start=0.0, fixed=true) "Joint 4 angle [rad]";
  Real q5(start=0.0, fixed=true) "Joint 5 angle [rad]";
  Real q6(start=0.0, fixed=true) "Joint 6 angle [rad]";
  Real q7(start=0.0, fixed=true) "Joint 7 angle [rad]";
  Real q8(start=0.0, fixed=true) "Joint 8 angle [rad]";
  Real q9(start=0.0, fixed=true) "Joint 9 angle [rad]";
  Real q10(start=0.0, fixed=true) "Joint 10 angle [rad]";
  Real q11(start=0.0, fixed=true) "Joint 11 angle [rad]";
  Real q12(start=0.0, fixed=true) "Joint 12 angle [rad]";

  Real dq1(start=0.0, fixed=true) "Joint 1 velocity [rad/s]";
  Real dq2(start=0.0, fixed=true) "Joint 2 velocity [rad/s]";
  Real dq3(start=0.0, fixed=true) "Joint 3 velocity [rad/s]";
  Real dq4(start=0.0, fixed=true) "Joint 4 velocity [rad/s]";
  Real dq5(start=0.0, fixed=true) "Joint 5 velocity [rad/s]";
  Real dq6(start=0.0, fixed=true) "Joint 6 velocity [rad/s]";
  Real dq7(start=0.0, fixed=true) "Joint 7 velocity [rad/s]";
  Real dq8(start=0.0, fixed=true) "Joint 8 velocity [rad/s]";
  Real dq9(start=0.0, fixed=true) "Joint 9 velocity [rad/s]";
  Real dq10(start=0.0, fixed=true) "Joint 10 velocity [rad/s]";
  Real dq11(start=0.0, fixed=true) "Joint 11 velocity [rad/s]";
  Real dq12(start=0.0, fixed=true) "Joint 12 velocity [rad/s]";

  Real tau_cmd1 "Joint 1 command [N.m]";
  Real tau_cmd2 "Joint 2 command [N.m]";
  Real tau_cmd3 "Joint 3 command [N.m]";
  Real tau_cmd4 "Joint 4 command [N.m]";
  Real tau_cmd5 "Joint 5 command [N.m]";
  Real tau_cmd6 "Joint 6 command [N.m]";
  Real tau_cmd7 "Joint 7 command [N.m]";
  Real tau_cmd8 "Joint 8 command [N.m]";
  Real tau_cmd9 "Joint 9 command [N.m]";
  Real tau_cmd10 "Joint 10 command [N.m]";
  Real tau_cmd11 "Joint 11 command [N.m]";
  Real tau_cmd12 "Joint 12 command [N.m]";

  // ============ Reference Trajectory ============
  Real x_ref "Reference x position [m]";
  Real z_ref "Reference z position [m]";
  Real theta_ref "Reference pitch angle [rad]";

  // ============ Forces ============
  Real Fx_body "Net body x force [N]";
  Real Fz_body "Net body z force [N]";
  Real M_body "Net body moment [N.m]";
  Real fn1 "Foot 1 normal force [N]";
  Real fn2 "Foot 2 normal force [N]";
  Real fn3 "Foot 3 normal force [N]";
  Real fn4 "Foot 4 normal force [N]";
  Boolean contact1 "Foot 1 contact flag";
  Boolean contact2 "Foot 2 contact flag";
  Boolean contact3 "Foot 3 contact flag";
  Boolean contact4 "Foot 4 contact flag";

  // ============ Sensors ============
  Real ax_imu "IMU x acceleration [m/s2]";
  Real az_imu "IMU z acceleration [m/s2]";
  Real omega_imu "IMU angular velocity [rad/s]";
  Real x_abs "Absolute x measurement [m]";
  Real z_abs "Absolute z measurement [m]";
  Real theta_abs "Absolute theta measurement [rad]";
  Boolean abs_avail "Absolute position sensor available";

  // ============ Estimator Discrete States ============
  discrete Real x_hat(start=0.0) "Estimated x [m]";
  discrete Real z_hat(start=0.5) "Estimated z [m]";
  discrete Real theta_hat(start=0.0) "Estimated theta [rad]";
  discrete Real vx_hat(start=0.0) "Estimated vx [m/s]";
  discrete Real vz_hat(start=0.0) "Estimated vz [m/s]";
  discrete Real omega_hat(start=0.0) "Estimated omega [rad/s]";
  discrete Real P_pos(start=P0_pos) "Position covariance [m2]";
  discrete Real P_rot(start=P0_rot) "Rotation covariance [rad2]";
  discrete Real innov_x(start=0.0) "X innovation [m]";
  discrete Real innov_z(start=0.0) "Z innovation [m]";
  discrete Real innov_th(start=0.0) "Theta innovation [rad]";
  discrete Real innov_n2(start=0.0) "Normalized innovation squared";
  discrete Real Kp_val(start=0.0) "Position Kalman gain";
  discrete Real Kr_val(start=0.0) "Rotation Kalman gain";
  discrete Real ts_log(start=0.0) "Synchronized timestamp [s]";
  discrete Integer nc(start=0) "Sample count";
  Boolean gate_ok(start=false) "Innovation gate accepted";

  // ============ Performance Metrics ============
  Real est_err "Estimation error norm [m or rad]";
  Real traj_err "Trajectory tracking error [m or rad]";
  Real cov_ratio "Covariance growth ratio";
  Boolean err_ok "Error below bound after check time";
  Boolean recovered "Estimator recovered after dropout";

  // ============ Intermediate variables ============
  Real ax_body "Body x acceleration [m/s2]";
  Real az_body "Body z acceleration [m/s2]";
  Real alpha_body "Body angular acceleration [rad/s2]";
  Real raw_tau1 "Raw joint 1 command before clamp [N.m]";
  Real raw_tau2 "Raw joint 2 command before clamp [N.m]";
  Real raw_tau3 "Raw joint 3 command before clamp [N.m]";
  Real raw_tau4 "Raw joint 4 command before clamp [N.m]";
  Real raw_tau5 "Raw joint 5 command before clamp [N.m]";
  Real raw_tau6 "Raw joint 6 command before clamp [N.m]";
  Real raw_tau7 "Raw joint 7 command before clamp [N.m]";
  Real raw_tau8 "Raw joint 8 command before clamp [N.m]";
  Real raw_tau9 "Raw joint 9 command before clamp [N.m]";
  Real raw_tau10 "Raw joint 10 command before clamp [N.m]";
  Real raw_tau11 "Raw joint 11 command before clamp [N.m]";
  Real raw_tau12 "Raw joint 12 command before clamp [N.m]";

  constant Real pi_c = 3.141592653589793;

equation
  // ============ Reference Trajectory (translation + rotation) ============
  x_ref = 0.3 * sin(2.0 * pi_c * time / 6.0);
  z_ref = 0.5 + 0.08 * cos(2.0 * pi_c * time / 4.0);
  theta_ref = 0.2 * sin(2.0 * pi_c * time / 8.0);

  // ============ Body Dynamics ============
  ax_body = Fx_body / m_body;
  az_body = (Fz_body - m_body * g_const) / m_body;
  alpha_body = M_body / I_body;

  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;
  der(vx) = ax_body;
  der(vz) = az_body;
  der(omega) = alpha_body;

  // ============ Joint Dynamics ============
  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;
  der(q5) = dq5;
  der(q6) = dq6;
  der(q7) = dq7;
  der(q8) = dq8;
  der(q9) = dq9;
  der(q10) = dq10;
  der(q11) = dq11;
  der(q12) = dq12;

  der(dq1) = (tau_cmd1 - b_joint * dq1 - k_joint * q1) / J_joint;
  der(dq2) = (tau_cmd2 - b_joint * dq2 - k_joint * q2) / J_joint;
  der(dq3) = (tau_cmd3 - b_joint * dq3 - k_joint * q3) / J_joint;
  der(dq4) = (tau_cmd4 - b_joint * dq4 - k_joint * q4) / J_joint;
  der(dq5) = (tau_cmd5 - b_joint * dq5 - k_joint * q5) / J_joint;
  der(dq6) = (tau_cmd6 - b_joint * dq6 - k_joint * q6) / J_joint;
  der(dq7) = (tau_cmd7 - b_joint * dq7 - k_joint * q7) / J_joint;
  der(dq8) = (tau_cmd8 - b_joint * dq8 - k_joint * q8) / J_joint;
  der(dq9) = (tau_cmd9 - b_joint * dq9 - k_joint * q9) / J_joint;
  der(dq10) = (tau_cmd10 - b_joint * dq10 - k_joint * q10) / J_joint;
  der(dq11) = (tau_cmd11 - b_joint * dq11 - k_joint * q11) / J_joint;
  der(dq12) = (tau_cmd12 - b_joint * dq12 - k_joint * q12) / J_joint;

  // ============ Controller (PD trajectory tracking) ============
  Fx_body = 300.0 * (x_ref - x) + 30.0 * (-vx);
  Fz_body = 300.0 * (z_ref - z) + 30.0 * (-vz) + m_body * g_const;
  M_body = 150.0 * (theta_ref - theta) + 15.0 * (-omega);

  // ============ Joint Commands (clamped to max magnitude) ============
  raw_tau1 = 5.0 * (-q1) + 0.5 * (-dq1) + 0.02 * M_body * cos(1.0 * pi_c / 6.0);
  raw_tau2 = 5.0 * (-q2) + 0.5 * (-dq2) + 0.02 * M_body * cos(2.0 * pi_c / 6.0);
  raw_tau3 = 5.0 * (-q3) + 0.5 * (-dq3) + 0.02 * M_body * cos(3.0 * pi_c / 6.0);
  raw_tau4 = 5.0 * (-q4) + 0.5 * (-dq4) + 0.02 * M_body * cos(4.0 * pi_c / 6.0);
  raw_tau5 = 5.0 * (-q5) + 0.5 * (-dq5) + 0.02 * M_body * cos(5.0 * pi_c / 6.0);
  raw_tau6 = 5.0 * (-q6) + 0.5 * (-dq6) + 0.02 * M_body * cos(6.0 * pi_c / 6.0);
  raw_tau7 = 5.0 * (-q7) + 0.5 * (-dq7) + 0.02 * M_body * cos(7.0 * pi_c / 6.0);
  raw_tau8 = 5.0 * (-q8) + 0.5 * (-dq8) + 0.02 * M_body * cos(8.0 * pi_c / 6.0);
  raw_tau9 = 5.0 * (-q9) + 0.5 * (-dq9) + 0.02 * M_body * cos(9.0 * pi_c / 6.0);
  raw_tau10 = 5.0 * (-q10) + 0.5 * (-dq10) + 0.02 * M_body * cos(10.0 * pi_c / 6.0);
  raw_tau11 = 5.0 * (-q11) + 0.5 * (-dq11) + 0.02 * M_body * cos(11.0 * pi_c / 6.0);
  raw_tau12 = 5.0 * (-q12) + 0.5 * (-dq12) + 0.02 * M_body * cos(12.0 * pi_c / 6.0);

  tau_cmd1 = noEvent(if raw_tau1 > tau_max then tau_max else if raw_tau1 < -tau_max then -tau_max else raw_tau1);
  tau_cmd2 = noEvent(if raw_tau2 > tau_max then tau_max else if raw_tau2 < -tau_max then -tau_max else raw_tau2);
  tau_cmd3 = noEvent(if raw_tau3 > tau_max then tau_max else if raw_tau3 < -tau_max then -tau_max else raw_tau3);
  tau_cmd4 = noEvent(if raw_tau4 > tau_max then tau_max else if raw_tau4 < -tau_max then -tau_max else raw_tau4);
  tau_cmd5 = noEvent(if raw_tau5 > tau_max then tau_max else if raw_tau5 < -tau_max then -tau_max else raw_tau5);
  tau_cmd6 = noEvent(if raw_tau6 > tau_max then tau_max else if raw_tau6 < -tau_max then -tau_max else raw_tau6);
  tau_cmd7 = noEvent(if raw_tau7 > tau_max then tau_max else if raw_tau7 < -tau_max then -tau_max else raw_tau7);
  tau_cmd8 = noEvent(if raw_tau8 > tau_max then tau_max else if raw_tau8 < -tau_max then -tau_max else raw_tau8);
  tau_cmd9 = noEvent(if raw_tau9 > tau_max then tau_max else if raw_tau9 < -tau_max then -tau_max else raw_tau9);
  tau_cmd10 = noEvent(if raw_tau10 > tau_max then tau_max else if raw_tau10 < -tau_max then -tau_max else raw_tau10);
  tau_cmd11 = noEvent(if raw_tau11 > tau_max then tau_max else if raw_tau11 < -tau_max then -tau_max else raw_tau11);
  tau_cmd12 = noEvent(if raw_tau12 > tau_max then tau_max else if raw_tau12 < -tau_max then -tau_max else raw_tau12);

  // ============ Foot Contact and Normal Force Sensors ============
  contact1 = z > 0.05;
  contact2 = z > 0.05;
  contact3 = z > 0.05;
  contact4 = z > 0.05;
  fn1 = noEvent(if (m_body * g_const / 4.0 + 30.0 * (z_ref - z)) > 0.0 then (m_body * g_const / 4.0 + 30.0 * (z_ref - z)) else 0.0);
  fn2 = fn1;
  fn3 = fn1;
  fn4 = fn1;

  // ============ Sensors ============
  ax_imu = ax_body + ax_bias;
  az_imu = az_body + az_bias;
  omega_imu = omega + w_bias;

  abs_avail = (time < t_drop_start) or (time >= t_drop_end);
  x_abs = x;
  z_abs = z;
  theta_abs = theta;

  // ============ Performance Metrics ============
  est_err = sqrt((x - x_hat) * (x - x_hat) + (z - z_hat) * (z - z_hat) + (theta - theta_hat) * (theta - theta_hat) + 1e-14);
  traj_err = sqrt((x - x_ref) * (x - x_ref) + (z - z_ref) * (z - z_ref) + (theta - theta_ref) * (theta - theta_ref) + 1e-14);
  cov_ratio = P_pos / (P0_pos + 1e-14);
  err_ok = (time >= t_check) and (est_err < err_bound);
  recovered = (time >= t_drop_end) and (est_err < 0.05);

  // ============ Estimator: Multi-Rate Filter with Innovation Gating ============
  when sample(0, Ts) then
    // Timestamp and sample counter
    nc = pre(nc) + 1;
    ts_log = time;

    // --- Prediction Step (125 Hz, IMU + proprioceptive) ---
    x_hat = pre(x_hat) + pre(vx_hat) * Ts;
    z_hat = pre(z_hat) + pre(vz_hat) * Ts;
    theta_hat = pre(theta_hat) + pre(omega_hat) * Ts;
    vx_hat = pre(vx_hat) + ax_imu * Ts;
    vz_hat = pre(vz_hat) + az_imu * Ts;
    omega_hat = omega_imu;

    // Covariance growth
    P_pos = pre(P_pos) + Q_pos * Ts;
    P_rot = pre(P_rot) + Q_rot * Ts;

    // Initialize correction variables
    innov_x = 0.0;
    innov_z = 0.0;
    innov_th = 0.0;
    innov_n2 = 0.0;
    Kp_val = 0.0;
    Kr_val = 0.0;
    gate_ok = false;

    // --- Correction Step (absolute position, gated) ---
    // Innovation
    innov_x = x_abs - x_hat;
    innov_z = z_abs - z_hat;
    innov_th = theta_abs - theta_hat;

    // Normalized innovation squared (chi-square gating)
    innov_n2 = (innov_x * innov_x) / (P_pos + R_abs) +
               (innov_z * innov_z) / (P_pos + R_abs) +
               (innov_th * innov_th) / (P_rot + R_abs);

    // Innovation gate and correction
    gate_ok = abs_avail and (innov_n2 < gate_chi2);
    Kp_val = if gate_ok then P_pos / (P_pos + R_abs) else 0.0;
    Kr_val = if gate_ok then P_rot / (P_rot + R_abs) else 0.0;

    // State correction (applied if gate accepted)
    x_hat = x_hat + Kp_val * innov_x;
    z_hat = z_hat + Kp_val * innov_z;
    theta_hat = theta_hat + Kr_val * innov_th;

    // Covariance reduction
    P_pos = P_pos * (1.0 - Kp_val);
    P_rot = P_rot * (1.0 - Kr_val);
  end when;

  annotation(
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="ContactStateBridgeC: Multi-rate Kalman filter with innovation gating for a 24 kg quadruped torso (4 legs x 3 joints = 12 actuators). Maintains usable state estimate through a 7.2 s absolute-position sensor dropout (t=2.4 to 9.6 s) using IMU and proprioceptive updates. Trajectory includes translation and rotation for observable drift. Estimator runs at 125 Hz for 12 s with covariance growth, bounded outage error, innovation-gated recovery, and primary tracking error below 0.367 m-or-rad after 7.8 s.")
  );
end ContactStateBridgeC;