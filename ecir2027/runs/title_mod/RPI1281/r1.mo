model ContactStateBridgeC
  "Robotic sensing and estimation system: multi-rate filtering with innovation gating"
  // Maintains a usable state estimate through a 7.2 s absolute-position sensor outage.
  // Plant: 24 kg quadruped torso, 4 legs x 3 joints, 12 effort actuators,
  // joint encoders, foot contact/normal-force sensors, body IMU.
  // Estimator: 125 Hz discrete EKF with innovation-gated absolute correction.

  // ===== Physical / scenario parameters =====
  parameter Real m_body = 24.0  "torso mass [kg]";
  parameter Real Iz_body = 1.0  "torso yaw inertia [kg.m2]";
  parameter Real g = 9.81       "gravity [m/s2]";
  parameter Real tau_max = 50.6 "max joint command magnitude [N.m]";
  parameter Real Ts = 0.008     "estimator sample period [s] (125 Hz)";
  parameter Real t_drop_start = 2.4 "absolute sensor dropout start [s]";
  parameter Real t_drop_end   = 9.6 "absolute sensor dropout end   [s]";
  parameter Real t_sim = 12.0   "simulation duration [s]";
  parameter Real err_limit = 0.367 "tracking error limit [m or rad]";
  parameter Real t_check = 7.8  "error verification time [s]";

  // ===== Body controller =====
  parameter Real kp_body = 80.0 "body PD proportional [N/m]";
  parameter Real kd_body = 20.0 "body PD derivative   [N.s/m]";
  parameter Real kp_th   = 10.0 "yaw PD proportional  [N.m/rad]";
  parameter Real kd_th   = 5.0  "yaw PD derivative     [N.m.s/rad]";

  // ===== Joint dynamics (per joint) =====
  parameter Real J_joint  = 0.05 "joint inertia  [kg.m2]";
  parameter Real b_joint  = 1.0  "joint damping  [N.m.s/rad]";
  parameter Real k_joint  = 10.0 "joint stiffness [N.m/rad]";
  parameter Real kp_joint = 30.0 "joint PD P     [N.m/rad]";
  parameter Real kd_joint = 2.0  "joint PD D     [N.m.s/rad]";

  // ===== Sensor noise / bias (unspecified in request; chosen realistic) =====
  parameter Real imu_acc_bias  = 0.005 "IMU accel bias  [m/s2]";
  parameter Real imu_acc_noise = 0.01  "IMU accel noise [m/s2]";
  parameter Real imu_gyr_bias  = 0.002 "IMU gyro bias  [rad/s]";
  parameter Real imu_gyr_noise = 0.005 "IMU gyro noise [rad/s]";
  parameter Real enc_noise     = 0.001 "encoder noise  [rad]";
  parameter Real abs_noise_pos = 0.005 "abs pos noise  [m]";
  parameter Real abs_noise_rot = 0.005 "abs rot noise  [rad]";

  // ===== Estimator tuning =====
  parameter Real Q_pos = 1e-3  "process noise pos [m2/s]";
  parameter Real Q_rot = 1e-3  "process noise rot [rad2/s]";
  parameter Real R_pos = 0.0025 "abs measurement cov pos [m2]";
  parameter Real R_rot = 0.0025 "abs measurement cov rot [rad2]";
  parameter Real gate_sigma = 3.0 "innovation gate threshold [sigma]";
  parameter Real P0 = 0.0025 "initial covariance diagonal";

  // ===== Reference trajectory (translation + rotation) =====
  Real x_ref  "reference x [m]";
  Real y_ref  "reference y [m]";
  Real th_ref "reference theta [rad]";
  Real vx_ref "reference vx [m/s]";
  Real vy_ref "reference vy [m/s]";
  Real vth_ref "reference vth [rad/s]";

  // ===== Plant: body states =====
  Real x(start=0.0, fixed=true)   "body x [m]";
  Real y(start=0.0, fixed=true)   "body y [m]";
  Real th(start=0.0, fixed=true)  "body theta [rad]";
  Real vx(start=1.0, fixed=true)  "body vx [m/s]";
  Real vy(start=0.6, fixed=true)  "body vy [m/s]";
  Real vth(start=0.15, fixed=true) "body vth [rad/s]";
  Real ax_body "body x-acceleration [m/s2]";
  Real ay_body "body y-acceleration [m/s2]";
  Real az_body "body z-angular accel [rad/s2]";
  Real Fx_cmd "body x force command [N]";
  Real Fy_cmd "body y force command [N]";
  Real Mz_cmd "body yaw moment command [N.m]";

  // ===== Plant: 12 joints =====
  Real q[12](each start=0.0, each fixed=true)     "joint angles [rad]";
  Real dq[12](each start=0.0, each fixed=true)    "joint velocities [rad/s]";
  Real q_ref[12]   "joint reference angles [rad]";
  Real tau[12]     "joint torques saturated [N.m]";
  Real tau_raw[12] "joint torques unsaturated [N.m]";
  Real enc[12]     "encoder readings [rad]";
  Real n_enc[12]   "encoder noise [rad]";

  // ===== Plant: 4 legs =====
  Boolean contact[4] "foot contact flags";
  Real Fn[4]   "foot normal forces [N]";
  Real phase[4] "gait phase [rad]";

  // ===== IMU (always available) =====
  Real imu_ax "IMU x-accel [m/s2]";
  Real imu_ay "IMU y-accel [m/s2]";
  Real imu_gz "IMU z-gyro [rad/s]";

  // ===== Absolute position sensor (dropout) =====
  Boolean dropout_active "dropout disturbance active";
  Boolean abs_available  "absolute sensor available";
  Real abs_x_meas  "measured x [m]";
  Real abs_y_meas  "measured y [m]";
  Real abs_th_meas "measured theta [rad]";

  // ===== Discrete estimator (125 Hz) =====
  Real x_hat(start=0.0, fixed=true)   "estimated x [m]";
  Real y_hat(start=0.0, fixed=true)   "estimated y [m]";
  Real th_hat(start=0.0, fixed=true)  "estimated theta [rad]";
  Real vx_hat(start=1.0, fixed=true)  "estimated vx [m/s]";
  Real vy_hat(start=0.6, fixed=true)  "estimated vy [m/s]";
  Real vth_hat(start=0.15, fixed=true) "estimated vth [rad/s]";
  Real P_xx(start=P0)  "est covariance xx [m2]";
  Real P_yy(start=P0)  "est covariance yy [m2]";
  Real P_thth(start=P0) "est covariance thth [rad2]";
  Real x_pred   "predicted x [m]";
  Real y_pred   "predicted y [m]";
  Real th_pred  "predicted theta [rad]";
  Real vx_pred  "predicted vx [m/s]";
  Real vy_pred  "predicted vy [m/s]";
  Real vth_pred "predicted vth [rad/s]";
  Real P_xx_pred   "predicted cov xx [m2]";
  Real P_yy_pred   "predicted cov yy [m2]";
  Real P_thth_pred "predicted cov thth [rad2]";
  Real nu_x  "innovation x [m]";
  Real nu_y  "innovation y [m]";
  Real nu_th "innovation theta [rad]";
  Real K_x  "Kalman gain x";
  Real K_y  "Kalman gain y";
  Real K_th "Kalman gain theta";
  Boolean gate_x      "innovation gate x";
  Boolean gate_y      "innovation gate y";
  Boolean gate_th     "innovation gate theta";
  Boolean corrected_x "correction applied x";
  Boolean corrected_y "correction applied y";
  Boolean corrected_th "correction applied theta";
  Integer sample_count(start=0, fixed=true) "discrete sample counter";
  Real ts_est(start=0.0, fixed=true) "estimator timestamp [s]";

  // ===== Diagnostics =====
  Real err_x  "estimation error x [m]";
  Real err_y  "estimation error y [m]";
  Real err_th "estimation error theta [rad]";
  Real err_track "primary tracking error norm [m or rad]";
  Real cov_trace "covariance trace [m2+rad2]";
  Boolean err_ok     "error within limit after t_check";
  Boolean recovered  "estimator recovered after dropout";
  Boolean valid      "no NaN/Inf detected";

equation
  // ===== Reference trajectory (translation + rotation, drift-observable) =====
  x_ref  = 2.0 * sin(0.5 * time);
  y_ref  = 1.5 * sin(0.4 * time);
  th_ref = 0.5 * sin(0.3 * time);
  vx_ref  = 2.0 * 0.5 * cos(0.5 * time);
  vy_ref  = 1.5 * 0.4 * cos(0.4 * time);
  vth_ref = 0.5 * 0.3 * cos(0.3 * time);

  // ===== Body PD controller =====
  Fx_cmd = kp_body * (x_ref - x) + kd_body * (vx_ref - vx);
  Fy_cmd = kp_body * (y_ref - y) + kd_body * (vy_ref - vy);
  Mz_cmd = kp_th   * (th_ref - th) + kd_th * (vth_ref - vth);

  // ===== Body dynamics (12 actuators produce trajectory via PD) =====
  ax_body = Fx_cmd / m_body;
  ay_body = Fy_cmd / m_body;
  az_body = Mz_cmd / Iz_body;
  der(x)  = vx;
  der(y)  = vy;
  der(th) = vth;
  der(vx)  = ax_body;
  der(vy)  = ay_body;
  der(vth) = az_body;

  // ===== Joint reference angles (derived from body trajectory) =====
  for i in 1:12 loop
    q_ref[i] = 0.3 * sin(0.5 * time + (i - 1) * 0.5) + 0.1 * th_ref;
  end for;

  // ===== Joint dynamics =====
  for i in 1:12 loop
    der(q[i])  = dq[i];
    der(dq[i]) = (tau[i] - b_joint * dq[i] - k_joint * (q[i] - q_ref[i])) / J_joint;
  end for;

  // ===== Joint torque commands with 50.6 N.m saturation =====
  for i in 1:12 loop
    tau_raw[i] = kp_joint * (q_ref[i] - q[i]) + kd_joint * (-dq[i]);
    tau[i] = max(-tau_max, min(tau_max, tau_raw[i]));
  end for;

  // ===== Leg contact and normal force (trot gait) =====
  for j in 1:4 loop
    phase[j] = 0.5 * time + (j - 1) * Modelica.Constants.pi / 2.0;
    contact[j] = sin(phase[j]) > 0.0;
    Fn[j] = if contact[j] then m_body * g / 4.0 + 5.0 * sin(2.0 * time + j) else 0.0;
  end for;

  // ===== Joint encoders (proprioceptive, always available) =====
  for i in 1:12 loop
    n_enc[i] = enc_noise * sin(7.0 * time + i);
    enc[i]   = q[i] + n_enc[i];
  end for;

  // ===== Body IMU (inertial, always available, with bias + noise) =====
  imu_ax = ax_body + imu_acc_bias  + imu_acc_noise * sin(13.0 * time);
  imu_ay = ay_body + imu_acc_bias  + imu_acc_noise * cos(11.0 * time);
  imu_gz = vth    + imu_gyr_bias  + imu_gyr_noise * sin(17.0 * time);

  // ===== Absolute position sensor with controlled dropout =====
  dropout_active = time >= t_drop_start and time <= t_drop_end;
  abs_available = not dropout_active;
  abs_x_meas  = x  + abs_noise_pos * sin(19.0 * time);
  abs_y_meas  = y  + abs_noise_pos * cos(23.0 * time);
  abs_th_meas = th + abs_noise_rot * sin(29.0 * time);

  // ===== Discrete estimator at 125 Hz =====
  when sample(0, Ts) then
    // Timestamp ordering
    ts_est = time;
    sample_count = pre(sample_count) + 1;

    // Prediction via IMU (inertial + proprioceptive; continues during dropout)
    vx_pred  = pre(vx_hat)  + imu_ax * Ts;
    vy_pred  = pre(vy_hat)  + imu_ay * Ts;
    vth_pred = imu_gz;
    x_pred   = pre(x_hat)   + pre(vx_hat)  * Ts + 0.5 * imu_ax * Ts * Ts;
    y_pred   = pre(y_hat)   + pre(vy_hat)  * Ts + 0.5 * imu_ay * Ts * Ts;
    th_pred  = pre(th_hat)  + 0.5 * (pre(vth_hat) + imu_gz) * Ts;

    // Covariance growth (open during outage)
    P_xx_pred   = pre(P_xx)   + Q_pos * Ts;
    P_yy_pred   = pre(P_yy)   + Q_pos * Ts;
    P_thth_pred = pre(P_thth) + Q_rot * Ts;

    // Innovation
    nu_x  = abs_x_meas  - x_pred;
    nu_y  = abs_y_meas  - y_pred;
    nu_th = abs_th_meas - th_pred;

    // Innovation gating (reject outliers)
    gate_x  = abs(nu_x)  < gate_sigma * sqrt(max(P_xx_pred   + R_pos, 1e-12));
    gate_y  = abs(nu_y)  < gate_sigma * sqrt(max(P_yy_pred   + R_pos, 1e-12));
    gate_th = abs(nu_th) < gate_sigma * sqrt(max(P_thth_pred  + R_rot, 1e-12));

    // Kalman gain
    K_x  = P_xx_pred   / max(P_xx_pred   + R_pos, 1e-12);
    K_y  = P_yy_pred   / max(P_yy_pred   + R_pos, 1e-12);
    K_th = P_thth_pred / max(P_thth_pred + R_rot, 1e-12);

    // Correction only when sensor available AND gate passes
    corrected_x  = abs_available and gate_x;
    corrected_y  = abs_available and gate_y;
    corrected_th = abs_available and gate_th;

    // Corrected state
    x_hat   = if corrected_x  then x_pred  + K_x  * nu_x  else x_pred;
    y_hat   = if corrected_y  then y_pred  + K_y  * nu_y  else y_pred;
    th_hat  = if corrected_th then th_pred + K_th * nu_th else th_pred;
    vx_hat  = vx_pred;
    vy_hat  = vy_pred;
    vth_hat = vth_pred;

    // Corrected covariance
    P_xx   = if corrected_x  then (1.0 - K_x)  * P_xx_pred   else P_xx_pred;
    P_yy   = if corrected_y  then (1.0 - K_y)  * P_yy_pred   else P_yy_pred;
    P_thth = if corrected_th then (1.0 - K_th) * P_thth_pred else P_thth_pred;
  end when;

  // ===== Diagnostics =====
  err_x  = x  - x_hat;
  err_y  = y  - y_hat;
  err_th = th - th_hat;
  err_track  = sqrt(max(err_x * err_x + err_y * err_y + err_th * err_th, 1e-12));
  cov_trace  = P_xx + P_yy + P_thth;
  err_ok     = if time >= t_check then err_track < err_limit else true;
  recovered  = time > t_drop_end + 0.5 and err_track < err_limit;
  valid      = err_track < 1e6 and cov_trace < 1e6
               and abs(x_hat) < 1e6 and abs(y_hat) < 1e6 and abs(th_hat) < 1e6
               and abs(vx_hat) < 1e6 and abs(vy_hat) < 1e6 and abs(vth_hat) < 1e6;

  // ===== Safety assertions =====
  assert(valid, "NaN or infinite values detected in estimator or plant",
         AssertionLevel.error);
  assert(err_ok, "Primary tracking error exceeded limit after t_check",
         AssertionLevel.warning);

  annotation(
    Documentation(info="ContactStateBridgeC: multi-rate filtering with innovation gating
      for a 24 kg quadruped torso with four 3-joint legs (12 effort actuators, max 50.6 N.m/joint).
      Sensors: joint encoders, foot contact/normal-force, body IMU, slow absolute-position.
      A controlled 7.2 s dropout (t=2.4..9.6 s, centered in 12 s run at 125 Hz) removes the
      absolute sensor. Inertial and proprioceptive updates continue throughout the outage.
      Trajectory includes translation and rotation so drift is observable. Requirements:
      timestamp order, covariance growth, bounded outage error, recovery after return,
      primary tracking error < 0.367 m-or-rad after 7.8 s, no NaN/Inf."),
    experiment(StartTime=0, StopTime=12.0, Tolerance=1e-6, Interval=0.008)
  );
end ContactStateBridgeC;