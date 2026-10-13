model TorqueObserverLocalizeD "Instrumented robotic sensing and estimation: 1-DOF capsule link, 70:1 gearbox, EKF with asynchronous sensor updates, bias estimation, actuator limits"

  // ============ Physical Parameters (from requirement) ============
  parameter Real m_link = 8.0 "Link mass [kg]";
  parameter Real L_link = 0.58 "Link length [m]";
  parameter Real N_gear = 70.0 "Gearbox ratio [-]";
  parameter Real tau_out_max = 75.0 "Maximum output torque [N.m]";

  // ============ Physical Parameters (assumed, not specified in requirement) ============
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s2] (assumed)";
  parameter Real J_link = m_link * L_link * L_link / 3.0 "Link inertia about pivot [kg.m2]";
  parameter Real b_damp = 0.15 "Joint viscous damping [N.m.s/rad] (assumed)";
  parameter Real K_t_motor = 0.05 "Motor torque constant [N.m/A] (assumed)";

  // ============ Controller Parameters (assumed) ============
  parameter Real Kp_ctrl = 40.0 "Position feedback gain (assumed)";
  parameter Real Kd_ctrl = 6.0 "Velocity feedback gain (assumed)";

  // ============ Sensor Parameters ============
  parameter Real f_encoder = 100.0 "Encoder sampling rate [Hz]";
  parameter Real f_current = 200.0 "Current sensor sampling rate [Hz]";
  parameter Real dt_encoder = 1.0 / f_encoder "Encoder sample period [s]";
  parameter Real dt_current = 1.0 / f_current "Current sensor sample period [s]";
  parameter Real sigma_enc = 0.005 "Encoder measurement std dev [rad] (assumed)";
  parameter Real sigma_cur = 0.05 "Current measurement std dev [A] (assumed)";
  parameter Real R_enc = sigma_enc * sigma_enc "Encoder measurement variance [rad2]";
  parameter Real R_cur = sigma_cur * sigma_cur "Current measurement variance [A2]";

  // ============ Estimator Parameters (assumed) ============
  parameter Real L1 = 12.0 "Estimator angle correction gain";
  parameter Real L2 = 60.0 "Estimator velocity correction gain";
  parameter Real L3 = 1.5 "Estimator encoder-bias correction gain";
  parameter Real L4 = 4.0 "Estimator current-bias correction gain";
  parameter Real Q_theta = 1e-6 "Process noise variance rate - angle [rad2/s]";
  parameter Real Q_omega = 1e-4 "Process noise variance rate - velocity [rad2/s3]";
  parameter Real Q_be = 1e-8 "Process noise variance rate - encoder bias [rad2/s]";
  parameter Real Q_bi = 1e-8 "Process noise variance rate - current bias [A2/s]";

  // ============ Simulation Parameters ============
  parameter Real T_sim = 14.0 "Total simulation time [s]";
  parameter Real dt_sim = 1.0 / 200.0 "Base simulation timestep [s]";

  // ============ Bias Step Disturbance ============
  parameter Real bias_step_mag = 0.04 "Sensor bias step magnitude";
  parameter Real t_step_on = T_sim / 3.0 "Bias step onset time [s]";
  parameter Real t_step_off = 2.0 * T_sim / 3.0 "Bias step removal time [s]";

  // ============ Constants ============
  parameter Real pi_val = 3.141592653589793;

  // ============ Plant States ============
  Real theta(start = 0.0, fixed = true) "True link angle [rad]";
  Real omega(start = 0.0, fixed = true) "True link angular velocity [rad/s]";
  Real tau_motor_cmd "Commanded motor torque, motor side [N.m]";
  Real tau_out "Saturated output torque [N.m]";
  Real i_motor "True motor current [A]";

  // ============ Route Reference (external landmark, no ground truth to estimator) ============
  Real theta_ref "Reference angle [rad]";
  Real omega_ref "Reference angular velocity [rad/s]";

  // ============ True Sensor Biases ============
  Real bias_enc_true "True encoder bias [rad]";
  Real bias_cur_true "True current bias [A]";

  // ============ Sensor Measurements ============
  // Encoder frame: joint frame; Current frame: motor frame
  Real theta_meas_raw "Raw continuous encoder reading [rad]";
  Real i_meas_raw "Raw continuous current reading [A]";
  discrete Real theta_meas_held(start = 0.0) "Sampled-and-held encoder measurement [rad]";
  discrete Real i_meas_held(start = 0.0) "Sampled-and-held current measurement [A]";
  discrete Real t_enc_last(start = 0.0) "Last encoder sample timestamp [s]";
  discrete Real t_cur_last(start = 0.0) "Last current sample timestamp [s]";

  // ============ Estimator States ============
  Real theta_hat(start = 0.0, fixed = true) "Estimated angle [rad]";
  Real omega_hat(start = 0.0, fixed = true) "Estimated angular velocity [rad/s]";
  Real bias_enc_hat(start = 0.0, fixed = true) "Estimated encoder bias [rad]";
  Real bias_cur_hat(start = 0.0, fixed = true) "Estimated current bias [A]";

  // ============ Estimator Covariance (diagonal, guaranteed positive) ============
  Real P_theta(start = 0.01, fixed = true) "Angle estimate covariance [rad2]";
  Real P_omega(start = 0.01, fixed = true) "Velocity estimate covariance [rad2/s2]";
  Real P_be(start = 1e-4, fixed = true) "Encoder bias estimate covariance [rad2]";
  Real P_bi(start = 1e-4, fixed = true) "Current bias estimate covariance [A2]";

  // ============ Innovations ============
  Real innov_enc "Encoder innovation [rad]";
  Real innov_cur "Current innovation [A]";

  // ============ Error Metrics ============
  Real err_theta "Angle estimation error [rad]";
  Real err_omega "Velocity estimation error [rad/s]";
  Real err_bias_enc "Encoder bias estimation error [rad]";
  Real err_bias_cur "Current bias estimation error [A]";
  Real track_err "Primary tracking error [rad]";

  // ============ Error Bands (3-sigma) ============
  Real pos_err_band "Position error band (3-sigma) [rad]";
  Real att_err_band "Attitude error band (3-sigma) [rad]";

  // ============ Saturation Indicator ============
  Boolean saturated "True when actuator output is saturated";

equation
  // --- Reference route: bounded sinusoidal landmark trajectory ---
  theta_ref = 0.3 * sin(2.0 * pi_val * 0.15 * time);
  omega_ref = 0.3 * 2.0 * pi_val * 0.15 * cos(2.0 * pi_val * 0.15 * time);

  // --- Controller: PD with gravity compensation, using estimated states ---
  tau_motor_cmd = (Kp_ctrl * (theta_ref - theta_hat) + Kd_ctrl * (omega_ref - omega_hat)
                   + m_link * g_grav * (L_link / 2.0) * sin(theta_hat)) / N_gear;

  // --- Actuator saturation (output torque limited to +/- 75 N.m) ---
  tau_out = if (N_gear * tau_motor_cmd > tau_out_max) then tau_out_max
            else if (N_gear * tau_motor_cmd < -tau_out_max) then -tau_out_max
            else (N_gear * tau_motor_cmd);
  saturated = (abs(N_gear * tau_motor_cmd) > tau_out_max);

  // --- Plant dynamics: rotational 1-DOF link with gravity and damping ---
  der(theta) = omega;
  J_link * der(omega) = tau_out - m_link * g_grav * (L_link / 2.0) * sin(theta) - b_damp * omega;

  // --- Motor current ---
  i_motor = (tau_out / N_gear) / K_t_motor;

  // --- True sensor biases: step disturbance during middle third ---
  bias_enc_true = if (time >= t_step_on and time <= t_step_off) then bias_step_mag else 0.0;
  bias_cur_true = if (time >= t_step_on and time <= t_step_off) then bias_step_mag else 0.0;

  // --- Raw sensor readings (with true bias) ---
  theta_meas_raw = theta + bias_enc_true;
  i_meas_raw = i_motor + bias_cur_true;

  // --- Asynchronous sensor sampling: encoder at 100 Hz, current at 200 Hz ---
  when sample(0, dt_encoder) then
    theta_meas_held = theta_meas_raw;
    t_enc_last = time;
  end when;

  when sample(0, dt_current) then
    i_meas_held = i_meas_raw;
    t_cur_last = time;
  end when;

  // --- Estimator innovations ---
  innov_enc = theta_meas_held - (theta_hat + bias_enc_hat);
  innov_cur = i_meas_held - (tau_motor_cmd / K_t_motor + bias_cur_hat);

  // --- EKF-like estimator: continuous prediction with correction from async sensors ---
  der(theta_hat) = omega_hat + L1 * innov_enc;
  J_link * der(omega_hat) = N_gear * tau_motor_cmd
                            - m_link * g_grav * (L_link / 2.0) * sin(theta_hat)
                            - b_damp * omega_hat
                            + J_link * L2 * innov_enc;
  der(bias_enc_hat) = L3 * innov_enc;
  der(bias_cur_hat) = L4 * innov_cur;

  // --- Covariance propagation (simplified diagonal, steady-state positive) ---
  der(P_theta) = Q_theta - 2.0 * L1 * P_theta;
  der(P_omega) = Q_omega - 2.0 * L2 * P_omega;
  der(P_be) = Q_be - 2.0 * L3 * P_be;
  der(P_bi) = Q_bi - 2.0 * L4 * P_bi;

  // --- Error metrics ---
  err_theta = theta - theta_hat;
  err_omega = omega - omega_hat;
  err_bias_enc = bias_enc_true - bias_enc_hat;
  err_bias_cur = bias_cur_true - bias_cur_hat;
  track_err = theta_ref - theta;

  // --- Error bands (3-sigma), protected against zero ---
  pos_err_band = 3.0 * sqrt(max(P_theta, 1e-12));
  att_err_band = 3.0 * sqrt(max(P_theta, 1e-12));

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "1-DOF capsule link (0.58 m, 8 kg) driven through 70:1 gearbox with motor current and joint encoder sensors. EKF-like estimator with asynchronous updates (100 Hz encoder, 200 Hz current). Bias step of 0.04 applied during middle third of 14 s run. Actuator output limited to 75 N.m. Assumed parameters: damping, motor torque constant, controller/estimator gains, sensor noise."));
end TorqueObserverLocalizeD;