model TorqueObserverLocalizeE
  "Robotic sensing and estimation: EKF with motor current, joint encoder, landmark bearings"

  // ==================== PHYSICAL CONSTANTS ====================
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";

  // ==================== PLANT PARAMETERS (from requirement) ====================
  parameter Real L = 0.58 "Capsule link length [m]";
  parameter Real m_link = 8.0 "Capsule link mass [kg]";
  parameter Real N_gear = 70.0 "Gearbox ratio";
  parameter Real tau_max = 82.5 "Output torque limit [N.m]";
  parameter Real J_link = m_link * L * L / 3.0 "Link inertia about pivot [kg.m^2]";

  // ==================== MOTOR PARAMETERS (assumed — not specified in requirement) ====================
  parameter Real Kt = 0.10 "Motor torque constant [N.m/A] (assumed)";
  parameter Real Ke = 0.10 "Back-EMF constant [V.s/rad] (assumed)";
  parameter Real R_m = 2.0 "Motor winding resistance [Ohm] (assumed)";
  parameter Real L_m = 0.005 "Motor winding inductance [H] (assumed)";
  parameter Real b_link = 0.02 "Link viscous friction [N.m.s/rad] (assumed)";
  parameter Real V_max = 36.0 "Drive voltage limit [V] (assumed)";
  parameter Real I_max = 15.0 "Drive current limit [A] (assumed)";

  // ==================== TIMING ====================
  parameter Real fs_base = 250.0 "Base loop rate [Hz]";
  parameter Real dt = 1.0 / fs_base "Base loop period [s]";
  parameter Real T_sim = 16.0 "Simulation duration [s]";

  // ==================== SENSOR PARAMETERS ====================
  parameter Real fs_enc = 250.0 "Encoder rate [Hz]";
  parameter Real fs_cur = 125.0 "Current sensor rate [Hz]";
  parameter Real fs_lm = 25.0 "Landmark bearing rate [Hz]";
  parameter Integer enc_period = 1 "Encoder period in base ticks";
  parameter Integer cur_period = 2 "Current period in base ticks";
  parameter Integer lm_period = 10 "Landmark period in base ticks";
  parameter Real sigma_enc = 0.001 "Encoder std dev [rad]";
  parameter Real sigma_cur = 0.05 "Current sensor std dev [A]";
  parameter Real sigma_lm = 0.01 "Landmark bearing std dev [rad]";
  parameter Real R_var_enc = sigma_enc * sigma_enc "Encoder measurement variance";
  parameter Real R_var_cur = sigma_cur * sigma_cur "Current measurement variance";
  parameter Real R_var_lm = sigma_lm * sigma_lm "Landmark measurement variance";

  // ==================== DISTURBANCE ====================
  parameter Real bias_step = 0.048 "Sensor-bias step magnitude";
  parameter Real t_dist_start = T_sim / 3.0 "Disturbance onset [s] (middle-third start)";
  parameter Real t_dist_end = 2.0 * T_sim / 3.0 "Disturbance end [s] (middle-third end)";

  // ==================== LANDMARKS (fixed external references) ====================
  parameter Real lm1_x = 1.2 "Landmark 1 x [m]";
  parameter Real lm1_y = 0.8 "Landmark 1 y [m]";
  parameter Real lm2_x = -0.6 "Landmark 2 x [m]";
  parameter Real lm2_y = 1.5 "Landmark 2 y [m]";

  // ==================== REFERENCE TRAJECTORY ====================
  parameter Real ref_amp = 0.4 "Reference amplitude [rad]";
  parameter Real ref_freq = 0.15 "Reference frequency [Hz]";
  parameter Real ref_w = 2.0 * Modelica.Constants.pi * ref_freq "Reference angular freq [rad/s]";

  // ==================== CONTROLLER GAINS ====================
  parameter Real Kp = 60.0 "Proportional gain [N.m/rad]";
  parameter Real Kd = 6.0 "Derivative gain [N.m.s/rad]";

  // ==================== EKF PARAMETERS ====================
  parameter Real P_init = 0.01 "Initial covariance diagonal";
  parameter Real Q_theta = 1.0e-5 "Process noise variance — angle [rad^2]";
  parameter Real Q_omega = 1.0e-3 "Process noise variance — angular velocity [(rad/s)^2]";
  parameter Real Q_bcur = 1.0e-4 "Process noise variance — current bias [A^2]";
  parameter Real Q_benc = 1.0e-4 "Process noise variance — encoder bias [rad^2]";
  parameter Real P_floor = 1.0e-12 "Covariance diagonal floor";
  parameter Real S_floor = 1.0e-12 "Innovation covariance floor";

  // ==================== ACCEPTANCE BANDS ====================
  parameter Real pos_err_band = 0.15 "Position error band [m]";
  parameter Real att_err_band = 0.15 "Attitude error band [rad]";
  parameter Real bias_conv_band = 0.02 "Bias convergence band";
  parameter Real bias_settle = 3.0 "Bias settling time after disturbance [s]";
  parameter Real primary_track_band = 0.18 "Primary tracking error band [rad]";
  parameter Real t_track_check = 10.4 "Tracking check time [s]";

  // ==================== CONTINUOUS PLANT STATES ====================
  Real theta(start = 0.0, fixed = true) "Link angle [rad]";
  Real omega(start = 0.0, fixed = true) "Link angular velocity [rad/s]";
  Real i_motor(start = 0.0, fixed = true) "Motor current [A]";

  // ==================== CONTINUOUS PLANT VARIABLES ====================
  Real i_limited "Current-limited motor current [A]";
  Real tau_out "Gearbox output torque [N.m]";
  Real tip_x "Link tip x [m] (ground truth, not given to estimator)";
  Real tip_y "Link tip y [m] (ground truth, not given to estimator)";
  Real theta_ref "Reference angle [rad]";
  Real omega_ref "Reference angular velocity [rad/s]";
  Real alpha_ref "Reference angular acceleration [rad/s^2]";

  // ==================== TRUE SENSOR BIAS ====================
  Real bias_enc_true "True encoder bias [rad]";
  Real bias_cur_true "True current bias [A]";

  // ==================== CONTINUOUS SENSOR SIGNALS ====================
  Real noise_enc "Encoder noise [rad]";
  Real noise_cur "Current sensor noise [A]";
  Real noise_lm1 "Landmark 1 bearing noise [rad]";
  Real noise_lm2 "Landmark 2 bearing noise [rad]";
  Real enc_signal "Continuous encoder signal [rad]";
  Real cur_signal "Continuous current signal [A]";
  Real lm1_signal "Continuous landmark 1 bearing [rad]";
  Real lm2_signal "Continuous landmark 2 bearing [rad]";

  // ==================== DISCRETE EKF STATES ====================
  discrete Real theta_hat(start = 0.0) "Estimated link angle [rad]";
  discrete Real omega_hat(start = 0.0) "Estimated angular velocity [rad/s]";
  discrete Real bcur_hat(start = 0.0) "Estimated current bias [A]";
  discrete Real benc_hat(start = 0.0) "Estimated encoder bias [rad]";

  // ==================== DISCRETE EKF COVARIANCE (4x4) ====================
  discrete Real P00(start = P_init), P01(start = 0.0), P02(start = 0.0), P03(start = 0.0);
  discrete Real P10(start = 0.0), P11(start = P_init), P12(start = 0.0), P13(start = 0.0);
  discrete Real P20(start = 0.0), P21(start = 0.0), P22(start = P_init), P23(start = 0.0);
  discrete Real P30(start = 0.0), P31(start = 0.0), P32(start = 0.0), P33(start = P_init);

  // ==================== DISCRETE SENSOR SAMPLES ====================
  discrete Real enc_samp(start = 0.0) "Sampled encoder [rad]";
  discrete Real cur_samp(start = 0.0) "Sampled current [A]";
  discrete Real lm1_samp(start = 0.0) "Sampled landmark 1 bearing [rad]";
  discrete Real lm2_samp(start = 0.0) "Sampled landmark 2 bearing [rad]";
  discrete Real ts_enc(start = 0.0) "Encoder timestamp [s]";
  discrete Real ts_cur(start = 0.0) "Current timestamp [s]";
  discrete Real ts_lm(start = 0.0) "Landmark timestamp [s]";
  discrete Integer frame_enc(start = 0) "Encoder frame index";
  discrete Integer frame_cur(start = 0) "Current frame index";
  discrete Integer frame_lm(start = 0) "Landmark frame index";
  discrete Integer sample_cnt(start = 0) "Base loop sample counter";

  // ==================== DISCRETE COMMAND ====================
  discrete Real tau_cmd(start = 0.0) "Unsaturated torque command [N.m]";
  discrete Real tau_sat(start = 0.0) "Saturated torque command [N.m]";
  discrete Real V_cmd(start = 0.0) "Voltage command [V]";

  // ==================== EKF INTERMEDIATES ====================
  discrete Real F10_val, F11_val;
  discrete Real T00, T01, T02, T03, T10, T11, T12, T13;
  discrete Real T20, T21, T22, T23, T30, T31, T32, T33;
  discrete Real theta_pre, omega_pre, bcur_pre, benc_pre;
  discrete Real i_pred, tau_pred, tau_pred_sat;
  discrete Real Se_val, Ke0, Ke1, Ke2, Ke3, innov_e;
  discrete Real Sc_val, Kc0, Kc1, Kc2, Kc3, innov_c, h1_cur;
  discrete Real Sl1_val, Kl1_0, Kl1_1, Kl1_2, Kl1_3, innov_l1;
  discrete Real Sl2_val, Kl2_0, Kl2_1, Kl2_2, Kl2_3, innov_l2;
  discrete Real lm1_dx, lm1_dy, lm1_r2, lm1_h_val, lm1_dh;
  discrete Real lm2_dx, lm2_dy, lm2_r2, lm2_h_val, lm2_dh;

  // ==================== ACCEPTANCE ====================
  Real pos_err "Position error at tip [m]";
  Real att_err "Attitude error [rad]";
  Real bias_enc_err "Encoder bias estimation error [rad]";
  Real bias_cur_err "Current bias estimation error [A]";
  Real primary_track_err "Primary tracking error [rad]";
  Boolean cov_finite_pos "Covariance finite and positive";
  Boolean err_bands_ok "Position and attitude error bands satisfied";
  Boolean bias_conv_ok "Bias convergence achieved";
  Boolean actuator_ok "Actuator limits satisfied";
  Boolean tracking_ok "Primary tracking within band after check time";
  Boolean values_finite "No NaN or infinite values";
  Boolean fail_closed "Overall acceptance (fail-closed)";

equation
  // ==================== PLANT DYNAMICS ====================
  der(theta) = omega;
  J_link * der(omega) = tau_out - m_link * g * (L / 2.0) * sin(theta) - b_link * omega;
  L_m * der(i_motor) = V_cmd - R_m * i_motor - Ke * N_gear * omega;

  // Current limiting (smooth saturation)
  i_limited = I_max * Modelica.Math.tanh(i_motor / I_max);

  // Output torque through gearbox
  tau_out = N_gear * Kt * i_limited;

  // Tip position (ground truth — not given to estimator)
  tip_x = L * cos(theta);
  tip_y = L * sin(theta);

  // ==================== REFERENCE TRAJECTORY (bounded route) ====================
  theta_ref = ref_amp * sin(ref_w * time);
  omega_ref = ref_amp * ref_w * cos(ref_w * time);
  alpha_ref = -ref_amp * ref_w * ref_w * sin(ref_w * time);

  // ==================== TRUE SENSOR BIAS (step disturbance) ====================
  bias_enc_true = if time >= t_dist_start then bias_step else 0.0;
  bias_cur_true = 0.0;

  // ==================== DETERMINISTIC PSEUDO-NOISE ====================
  noise_enc = sigma_enc * sin(2.0 * Modelica.Constants.pi * 137.0 * time + 0.1);
  noise_cur = sigma_cur * sin(2.0 * Modelica.Constants.pi * 139.0 * time + 0.3);
  noise_lm1 = sigma_lm * sin(2.0 * Modelica.Constants.pi * 41.0 * time + 0.7);
  noise_lm2 = sigma_lm * sin(2.0 * Modelica.Constants.pi * 43.0 * time + 1.3);

  // ==================== CONTINUOUS SENSOR SIGNALS ====================
  enc_signal = theta + bias_enc_true + noise_enc;
  cur_signal = i_motor + bias_cur_true + noise_cur;
  lm1_signal = Modelica.Math.atan2(lm1_y - tip_y, lm1_x - tip_x) + noise_lm1;
  lm2_signal = Modelica.Math.atan2(lm2_y - tip_y, lm2_x - tip_x) + noise_lm2;

  // ==================== ACCEPTANCE METRICS ====================
  pos_err = abs(L * (theta - theta_hat));
  att_err = abs(theta - theta_hat);
  bias_enc_err = abs(bias_enc_true - benc_hat);
  bias_cur_err = abs(bias_cur_true - bcur_hat);
  primary_track_err = abs(theta_ref - theta);

  cov_finite_pos = (P00 > P_floor) and (P11 > P_floor) and
                   (P22 > P_floor) and (P33 > P_floor) and
                   (P00 < 1.0e6) and (P11 < 1.0e6) and
                   (P22 < 1.0e6) and (P33 < 1.0e6);
  err_bands_ok = (pos_err < pos_err_band) and (att_err < att_err_band);
  bias_conv_ok = (time < t_dist_start + bias_settle) or
                 (bias_enc_err < bias_conv_band and
                  bias_cur_err < bias_conv_band);
  actuator_ok = (abs(tau_sat) <= tau_max + 1.0e-6) and
               (abs(V_cmd) <= V_max + 1.0e-6);
  tracking_ok = (time < t_track_check) or
                (primary_track_err < primary_track_band);
  values_finite = (theta > -1.0e10) and (theta < 1.0e10) and
                  (omega > -1.0e10) and (omega < 1.0e10) and
                  (i_motor > -1.0e10) and (i_motor < 1.0e10) and
                  (theta_hat > -1.0e10) and (theta_hat < 1.0e10) and
                  (omega_hat > -1.0e10) and (omega_hat < 1.0e10) and
                  (bcur_hat > -1.0e10) and (bcur_hat < 1.0e10) and
                  (benc_hat > -1.0e10) and (benc_hat < 1.0e10) and
                  (P00 > -1.0e10) and (P00 < 1.0e10) and
                  (P11 > -1.0e10) and (P11 < 1.0e10) and
                  (P22 > -1.0e10) and (P22 < 1.0e10) and
                  (P33 > -1.0e10) and (P33 < 1.0e10) and
                  (tau_cmd > -1.0e10) and (tau_cmd < 1.0e10) and
                  (V_cmd > -1.0e10) and (V_cmd < 1.0e10);
  fail_closed = cov_finite_pos and err_bands_ok and bias_conv_ok and
                actuator_ok and tracking_ok and values_finite;

algorithm
  when sample(0, dt) then
    // === Increment base loop counter ===
    sample_cnt := pre(sample_cnt) + 1;

    // ================================================================
    // EKF PREDICTION
    // ================================================================

    // Predict motor current from previous voltage command and state
    i_pred := (pre(V_cmd) - Ke * N_gear * pre(omega_hat)) / R_m;
    tau_pred := N_gear * Kt * i_pred;
    tau_pred_sat := tau_max * Modelica.Math.tanh(tau_pred / tau_max);

    // State prediction (Euler integration)
    theta_pre := pre(theta_hat) + pre(omega_hat) * dt;
    omega_pre := pre(omega_hat) + (
                  tau_pred_sat / J_link
                  - m_link * g * (L / 2.0) * sin(pre(theta_hat)) / J_link
                  - b_link * pre(omega_hat) / J_link) * dt;
    bcur_pre := pre(bcur_hat);
    benc_pre := pre(benc_hat);

    // Jacobian of prediction model
    F10_val := -m_link * g * (L / 2.0) * cos(theta_pre) * dt / J_link;
    F11_val := 1.0 - b_link * dt / J_link;

    // Covariance prediction: P = F * P * F^T + Q
    // Step 1: T = F * P
    T00 := pre(P00) + dt * pre(P10);
    T01 := pre(P01) + dt * pre(P11);
    T02 := pre(P02) + dt * pre(P12);
    T03 := pre(P03) + dt * pre(P13);
    T10 := F10_val * pre(P00) + F11_val * pre(P10);
    T11 := F10_val * pre(P01) + F11_val * pre(P11);
    T12 := F10_val * pre(P02) + F11_val * pre(P12);
    T13 := F10_val * pre(P03) + F11_val * pre(P13);
    T20 := pre(P20);
    T21 := pre(P21);
    T22 := pre(P22);
    T23 := pre(P23);
    T30 := pre(P30);
    T31 := pre(P31);
    T32 := pre(P32);
    T33 := pre(P33);

    // Step 2: P = T * F^T + Q
    P00 := T00 + T01 * dt + Q_theta;
    P01 := T00 * F10_val + T01 * F11_val;
    P02 := T02;
    P03 := T03;
    P10 := T10 + T11 * dt;
    P11 := T10 * F10_val + T11 * F11_val + Q_omega;
    P12 := T12;
    P13 := T13;
    P20 := T20 + T21 * dt;
    P21 := T20 * F10_val + T21 * F11_val;
    P22 := T22 + Q_bcur;
    P23 := T23;
    P30 := T30 + T31 * dt;
    P31 := T30 * F10_val + T31 * F11_val;
    P32 := T32;
    P33 := T33 + Q_benc;

    // ================================================================
    // ENCODER UPDATE (250 Hz — every base tick)
    // H_enc = [1, 0, 0, 1]
    // ================================================================
    enc_samp := enc_signal;
    ts_enc := time;
    frame_enc := pre(frame_enc) + 1;

    Se_val := max(P00 + P03 + P30 + P33 + R_var_enc, S_floor);
    Ke0 := (P00 + P03) / Se_val;
    Ke1 := (P10 + P13) / Se_val;
    Ke2 := (P20 + P23) / Se_val;
    Ke3 := (P30 + P33) / Se_val;
    innov_e := enc_samp - (theta_pre + benc_pre);

    // State correction
    theta_pre := theta_pre + Ke0 * innov_e;
    omega_pre := omega_pre + Ke1 * innov_e;
    bcur_pre := bcur_pre + Ke2 * innov_e;
    benc_pre := benc_pre + Ke3 * innov_e;

    // Covariance correction: P = (I - K*H) * P
    T00 := P00 - Ke0 * (P00 + P30);
    T01 := P01 - Ke0 * (P01 + P31);
    T02 := P02 - Ke0 * (P02 + P32);
    T03 := P03 - Ke0 * (P03 + P33);
    T10 := P10 - Ke1 * (P00 + P30);
    T11 := P11 - Ke1 * (P01 + P31);
    T12 := P12 - Ke1 * (P02 + P32);
    T13 := P13 - Ke1 * (P03 + P33);
    T20 := P20 - Ke2 * (P00 + P30);
    T21 := P21 - Ke2 * (P01 + P31);
    T22 := P22 - Ke2 * (P02 + P32);
    T23 := P23 - Ke2 * (P03 + P33);
    T30 := P30 - Ke3 * (P00 + P30);
    T31 := P31 - Ke3 * (P01 + P31);
    T32 := P32 - Ke3 * (P02 + P32);
    T33 := P33 - Ke3 * (P03 + P33);

    P00 := max(T00, P_floor);
    P01 := T01;
    P02 := T02;
    P03 := T03;
    P10 := T10;
    P11 := max(T11, P_floor);
    P12 := T12;
    P13 := T13;
    P20 := T20;
    P21 := T21;
    P22 := max(T22, P_floor);
    P23 := T23;
    P30 := T30;
    P31 := T31;
    P32 := T32;
    P33 := max(T33, P_floor);

    // ================================================================
    // CURRENT UPDATE (125 Hz — asynchronous, offset 1)
    // H_cur = [0, -Ke*N/R, 1, 0]
    // ================================================================
    if mod(pre(sample_cnt), cur_period) == 1 then
      cur_samp := cur_signal;
      ts_cur := time;
      frame_cur := pre(frame_cur) + 1;

      h1_cur := -Ke * N_gear / R_m;

      // Innovation covariance
      Sc_val := max(h1_cur * h1_cur * P11 + 2.0 * h1_cur * P12 + P22 + R_var_cur,
                    S_floor);

      // Kalman gain
      Kc0 := (P01 * h1_cur + P02) / Sc_val;
      Kc1 := (P11 * h1_cur + P12) / Sc_val;
      Kc2 := (P21 * h1_cur + P22) / Sc_val;
      Kc3 := (P31 * h1_cur + P32) / Sc_val;

      // Innovation (predicted current + bias)
      innov_c := cur_samp - ((pre(V_cmd) - Ke * N_gear * omega_pre) / R_m + bcur_pre);

      // State correction
      theta_pre := theta_pre + Kc0 * innov_c;
      omega_pre := omega_pre + Kc1 * innov_c;
      bcur_pre := bcur_pre + Kc2 * innov_c;
      benc_pre := benc_pre + Kc3 * innov_c;

      // Covariance correction: P = (I - K*H) * P
      T00 := P00 - Kc0 * (h1_cur * P10 + P20);
      T01 := P01 - Kc0 * (h1_cur * P11 + P21);
      T02 := P02 - Kc0 * (h1_cur * P12 + P22);
      T03 := P03 - Kc0 * (h1_cur * P13 + P23);
      T10 := P10 - Kc1 * (h1_cur * P10 + P20);
      T11 := P11 - Kc1 * (h1_cur * P11 + P21);
      T12 := P12 - Kc1 * (h1_cur * P12 + P22);
      T13 := P13 - Kc1 * (h1_cur * P13 + P23);
      T20 := P20 - Kc2 * (h1_cur * P10 + P20);
      T21 := P21 - Kc2 * (h1_cur * P11 + P21);
      T22 := P22 - Kc2 * (h1_cur * P12 + P22);
      T23 := P23 - Kc2 * (h1_cur * P13 + P23);
      T30 := P30 - Kc3 * (h1_cur * P10 + P20);
      T31 := P31 - Kc3 * (h1_cur * P11 + P21);
      T32 := P32 - Kc3 * (h1_cur * P12 + P22);
      T33 := P33 - Kc3 * (h1_cur * P13 + P23);

      P00 := max(T00, P_floor);
      P01 := T01;
      P02 := T02;
      P03 := T03;
      P10 := T10;
      P11 := max(T11, P_floor);
      P12 := T12;
      P13 := T13;
      P20 := T20;
      P21 := T21;
      P22 := max(T22, P_floor);
      P23 := T23;
      P30 := T30;
      P31 := T31;
      P32 := T32;
      P33 := max(T33, P_floor);
    end if;

    // ================================================================
    // LANDMARK BEARING UPDATE (25 Hz — asynchronous, offset 5)
    // H_lm = [dh/dtheta, 0, 0, 0]
    // ================================================================
    if mod(pre(sample_cnt), lm_period) == 5 then
      lm1_samp := lm1_signal;
      lm2_samp := lm2_signal;
      ts_lm := time;
      frame_lm := pre(frame_lm) + 1;

      // --- Landmark 1 ---
      lm1_dx := lm1_x - L * cos(theta_pre);
      lm1_dy := lm1_y - L * sin(theta_pre);
      lm1_r2 := lm1_dx * lm1_dx + lm1_dy * lm1_dy + 1.0e-10;
      lm1_h_val := Modelica.Math.atan2(lm1_dy, lm1_dx);
      lm1_dh := (lm1_dx * (-L * cos(theta_pre))
                 - lm1_dy * (L * sin(theta_pre))) / lm1_r2;

      Sl1_val := max(lm1_dh * lm1_dh * P00 + R_var_lm, S_floor);
      Kl1_0 := (lm1_dh * P00) / Sl1_val;
      Kl1_1 := (lm1_dh * P10) / Sl1_val;
      Kl1_2 := (lm1_dh * P20) / Sl1_val;
      Kl1_3 := (lm1_dh * P30) / Sl1_val;
      innov_l1 := lm1_samp - lm1_h_val;
      innov_l1 := Modelica.Math.atan2(sin(innov_l1), cos(innov_l1));

      theta_pre := theta_pre + Kl1_0 * innov_l1;
      omega_pre := omega_pre + Kl1_1 * innov_l1;
      bcur_pre := bcur_pre + Kl1_2 * innov_l1;
      benc_pre := benc_pre + Kl1_3 * innov_l1;

      T00 := P00 - Kl1_0 * lm1_dh * P00;
      T01 := P01 - Kl1_0 * lm1_dh * P01;
      T02 := P02 - Kl1_0 * lm1_dh * P02;
      T03 := P03 - Kl1_0 * lm1_dh * P03;
      T10 := P10 - Kl1_1 * lm1_dh * P00;
      T11 := P11 - Kl1_1 * lm1_dh * P01;
      T12 := P12 - Kl1_1 * lm1_dh * P02;
      T13 := P13 - Kl1_1 * lm1_dh * P03;
      T20 := P20 - Kl1_2 * lm1_dh * P00;
      T21 := P21 - Kl1_2 * lm1_dh * P01;
      T22 := P22 - Kl1_2 * lm1_dh * P02;
      T23 := P23 - Kl1_2 * lm1_dh * P03;
      T30 := P30 - Kl1_3 * lm1_dh * P00;
      T31 := P31 - Kl1_3 * lm1_dh * P01;
      T32 := P32 - Kl1_3 * lm1_dh * P02;
      T33 := P33 - Kl1_3 * lm1_dh * P03;

      P00 := max(T00, P_floor);
      P01 := T01;
      P02 := T02;
      P03 := T03;
      P10 := T10;
      P11 := max(T11, P_floor);
      P12 := T12;
      P13 := T13;
      P20 := T20;
      P21 := T21;
      P22 := max(T22, P_floor);
      P23 := T23;
      P30 := T30;
      P31 := T31;
      P32 := T32;
      P33 := max(T33, P_floor);

      // --- Landmark 2 ---
      lm2_dx := lm2_x - L * cos(theta_pre);
      lm2_dy := lm2_y - L * sin(theta_pre);
      lm2_r2 := lm2_dx * lm2_dx + lm2_dy * lm2_dy + 1.0e-10;
      lm2_h_val := Modelica.Math.atan2(lm2_dy, lm2_dx);
      lm2_dh := (lm2_dx * (-L * cos(theta_pre))
                 - lm2_dy * (L * sin(theta_pre))) / lm2_r2;

      Sl2_val := max(lm2_dh * lm2_dh * P00 + R_var_lm, S_floor);
      Kl2_0 := (lm2_dh * P00) / Sl2_val;
      Kl2_1 := (lm2_dh * P10) / Sl2_val;
      Kl2_2 := (lm2_dh * P20) / Sl2_val;
      Kl2_3 := (lm2_dh * P30) / Sl2_val;
      innov_l2 := lm2_samp - lm2_h_val;
      innov_l2 := Modelica.Math.atan2(sin(innov_l2), cos(innov_l2));

      theta_pre := theta_pre + Kl2_0 * innov_l2;
      omega_pre := omega_pre + Kl2_1 * innov_l2;
      bcur_pre := bcur_pre + Kl2_2 * innov_l2;
      benc_pre := benc_pre + Kl2_3 * innov_l2;

      T00 := P00 - Kl2_0 * lm2_dh * P00;
      T01 := P01 - Kl2_0 * lm2_dh * P01;
      T02 := P02 - Kl2_0 * lm2_dh * P02;
      T03 := P03 - Kl2_0 * lm2_dh * P03;
      T10 := P10 - Kl2_1 * lm2_dh * P00;
      T11 := P11 - Kl2_1 * lm2_dh * P01;
      T12 := P12 - Kl2_1 * lm2_dh * P02;
      T13 := P13 - Kl2_1 * lm2_dh * P03;
      T20 := P20 - Kl2_2 * lm2_dh * P00;
      T21 := P21 - Kl2_2 * lm2_dh * P01;
      T22 := P22 - Kl2_2 * lm2_dh * P02;
      T23 := P23 - Kl2_2 * lm2_dh * P03;
      T30 := P30 - Kl2_3 * lm2_dh * P00;
      T31 := P31 - Kl2_3 * lm2_dh * P01;
      T32 := P32 - Kl2_3 * lm2_dh * P02;
      T33 := P33 - Kl2_3 * lm2_dh * P03;

      P00 := max(T00, P_floor);
      P01 := T01;
      P02 := T02;
      P03 := T03;
      P10 := T10;
      P11 := max(T11, P_floor);
      P12 := T12;
      P13 := T13;
      P20 := T20;
      P21 := T21;
      P22 := max(T22, P_floor);
      P23 := T23;
      P30 := T30;
      P31 := T31;
      P32 := T32;
      P33 := max(T33, P_floor);
    end if;

    // ================================================================
    // FINAL EKF STATE ASSIGNMENT
    // ================================================================
    theta_hat := theta_pre;
    omega_hat := omega_pre;
    bcur_hat := bcur_pre;
    benc_hat := benc_pre;

    // ================================================================
    // CONTROLLER (PD + gravity compensation using EKF estimates)
    // ================================================================
    tau_cmd := Kp * (theta_ref - theta_hat)
               + Kd * (omega_ref - omega_hat)
               + m_link * g * (L / 2.0) * sin(theta_hat);
    // Torque command bounded at 82.5 N.m output
    tau_sat := tau_max * Modelica.Math.tanh(tau_cmd / tau_max);
    // Voltage command with back-EMF feedforward, voltage limited
    V_cmd := V_max * Modelica.Math.tanh(
               (R_m * (tau_sat / (N_gear * Kt)) + Ke * N_gear * omega_hat)
               / V_max);

  end when;

  annotation(
    experiment(StopTime = 16.0, StartTime = 0.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "<html>
      <p><b>TorqueObserverLocalizeE</b>: Robotic sensing and estimation system.</p>
      <p>Plant: 0.58 m, 8 kg capsule link, 70:1 gearbox, motor current and joint encoder sensors.</p>
      <p>Estimator: Extended Kalman Filter (4-state: angle, angular velocity, current bias, encoder bias)
         with asynchronous updates (encoder 250 Hz, current 125 Hz, landmark 25 Hz).</p>
      <p>Motor parameters (Kt, Ke, R, L, V_max, I_max) are assumed — not specified in requirement.</p>
      <p>Bias step disturbance of 0.048 rad applied at t = T/3 (middle-third start).</p>
      <p>Acceptance: fail-closed. Finite positive covariance, position/attitude error bands,
         bias convergence, actuator limits, primary tracking error < 0.18 after 10.4 s, no NaN/Inf.</p>
    </html>")
  );
end TorqueObserverLocalizeE;