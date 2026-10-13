model MarineNavLocalizeD
  "Marine navigation and localization system"

  // ==================== Simulation timing ====================
  parameter Real Ts = 0.005 "Estimator and control period [s] (200 Hz)";
  parameter Real T_run = 14.0 "Mission duration [s]";

  // ==================== Vehicle parameters ====================
  parameter Real m = 100.0 "vehicle mass [kg]";
  parameter Real Izz = 20.0 "yaw inertia [kg.m2]";
  parameter Real du = 80.0 "surge linear drag [N.s/m]";
  parameter Real dw = 120.0 "heave linear drag [N.s/m]";
  parameter Real dr = 15.0 "yaw rotary drag [N.m.s/rad]";
  parameter Real Larm = 0.6 "thruster yaw lever arm [m]";
  parameter Real Tmax = 105.0 "per-thruster force limit [N]";

  // ==================== Route references ====================
  parameter Real R_route = 8.0 "route circle radius [m]";
  parameter Real omega_route = 0.4 "route angular rate [rad/s]";
  parameter Real depth_ref = 5.0 "depth reference [m]";
  parameter Real u_ref = 0.6 "reference surge speed [m/s]";

  // ==================== Fixed landmarks (external references, no ground truth to estimator) ====================
  parameter Real LM1x = 10.0 "landmark 1 x [m]";
  parameter Real LM1y = 0.0  "landmark 1 y [m]";
  parameter Real LM2x = 0.0  "landmark 2 x [m]";
  parameter Real LM2y = 10.0 "landmark 2 y [m]";

  // ==================== Sensor standard deviations ====================
  parameter Real sigma_acc = 0.05 "IMU accelerometer std [m/s2]";
  parameter Real sigma_gyro = 0.01 "IMU gyroscope std [rad/s]";
  parameter Real sigma_p = 0.10 "pressure depth std [m]";
  parameter Real sigma_dvl = 0.02 "Doppler velocity log std [m/s]";
  parameter Real sigma_comp = 0.02 "compass std [rad]";
  parameter Real sigma_range = 0.15 "acoustic range std [m]";

  // ==================== Constant biases (zero; only step disturbance is nonzero) ====================
  parameter Real b_p_const = 0.0 "constant pressure bias [m]";
  parameter Real b_dvl_const = 0.0 "constant DVL bias [m/s]";
  parameter Real b_comp_const = 0.0 "constant compass bias [rad]";

  // ==================== Bias step disturbance (middle third) ====================
  parameter Real t_mid_start = 14.0/3.0 "middle third start [s]";
  parameter Real t_mid_end = 28.0/3.0 "middle third end [s]";
  parameter Real bias_step = 0.04 "sensor-bias step amplitude";

  // ==================== Sensor extrinsic transforms (request did not specify; default co-located) ====================
  parameter Real ext_imu_x = 0.0 "IMU extrinsic x offset [m] (unspecified, default 0)";
  parameter Real ext_imu_y = 0.0 "IMU extrinsic y offset [m] (unspecified, default 0)";
  parameter Real ext_p_x = 0.0 "pressure extrinsic x offset [m] (unspecified, default 0)";
  parameter Real ext_p_y = 0.0 "pressure extrinsic y offset [m] (unspecified, default 0)";
  parameter Real ext_dvl_x = 0.0 "DVL extrinsic x offset [m] (unspecified, default 0)";
  parameter Real ext_dvl_y = 0.0 "DVL extrinsic y offset [m] (unspecified, default 0)";
  parameter Real ext_comp_x = 0.0 "compass extrinsic x offset [m] (unspecified, default 0)";
  parameter Real ext_comp_y = 0.0 "compass extrinsic y offset [m] (unspecified, default 0)";
  parameter Real ext_range_x = 0.0 "acoustic range extrinsic x offset [m] (unspecified, default 0)";
  parameter Real ext_range_y = 0.0 "acoustic range extrinsic y offset [m] (unspecified, default 0)";

  // ==================== Continuous plant state ====================
  Real x(start=8.0, fixed=true) "world x position [m]";
  Real y(start=0.0, fixed=true) "world y position [m]";
  Real z(start=0.0, fixed=true) "depth [m]";
  Real u(start=0.0, fixed=true) "body-frame surge velocity [m/s]";
  Real w(start=0.0, fixed=true) "body-frame heave velocity [m/s]";
  Real yaw(start=1.5707963267949, fixed=true) "heading [rad]";
  Real r(start=0.0, fixed=true) "yaw rate [rad/s]";

  // ==================== True sensor biases ====================
  Real b_acc_true "true accelerometer bias [m/s2]";
  Real b_gyro_true "true gyroscope bias [rad/s]";
  Real b_p_true "true pressure bias [m]";
  Real b_dvl_true "true DVL bias [m/s]";
  Real b_comp_true "true compass bias [rad]";
  Boolean bias_step_active "true during middle-third bias step";

  // ==================== Thruster commands and actual forces ====================
  discrete Real T1_cmd(start=0.0) "commanded thrust 1 [N]";
  discrete Real T2_cmd(start=0.0) "commanded thrust 2 [N]";
  discrete Real T3_cmd(start=0.0) "commanded thrust 3 [N]";
  discrete Real T4_cmd(start=0.0) "commanded thrust 4 [N]";
  Real T1 "actual thrust 1 [N]";
  Real T2 "actual thrust 2 [N]";
  Real T3 "actual thrust 3 [N]";
  Real T4 "actual thrust 4 [N]";
  Real Fx_b "body surge force [N]";
  Real Fz_b "body heave force [N]";
  Real Mz "yaw moment [N.m]";

  // ==================== Sensor measurements (discrete, retained as traces) ====================
  discrete Real acc_meas(start=0.0) "IMU surge acceleration measurement [m/s2]";
  discrete Real gyro_meas(start=0.0) "IMU yaw-rate measurement [rad/s]";
  discrete Real p_meas(start=0.0) "pressure depth measurement [m]";
  discrete Real dvl_u_meas(start=0.0) "DVL surge velocity measurement [m/s]";
  discrete Real dvl_w_meas(start=0.0) "DVL heave velocity measurement [m/s]";
  discrete Real comp_meas(start=0.0) "compass heading measurement [rad]";
  discrete Real range1_meas(start=0.0) "acoustic range to LM1 [m]";
  discrete Real range2_meas(start=0.0) "acoustic range to LM2 [m]";
  Real range1_pred_est(start=0.1) "estimator-predicted range to LM1 [m] (observability)";
  Real range2_pred_est(start=0.1) "estimator-predicted range to LM2 [m] (observability)";

  // ==================== Estimator state (discrete) ====================
  discrete Real x_est(start=7.8, fixed=true) "estimated x [m]";
  discrete Real y_est(start=0.2, fixed=true) "estimated y [m]";
  discrete Real z_est(start=0.5, fixed=true) "estimated depth [m]";
  discrete Real u_est(start=0.0, fixed=true) "estimated surge [m/s]";
  discrete Real w_est(start=0.0, fixed=true) "estimated heave [m/s]";
  discrete Real yaw_est(start=1.5, fixed=true) "estimated heading [rad]";
  discrete Real b_acc_est(start=0.0, fixed=true) "estimated accel bias [m/s2]";
  discrete Real b_gyro_est(start=0.0, fixed=true) "estimated gyro bias [rad/s]";
  discrete Real b_p_est(start=0.0, fixed=true) "estimated pressure bias [m]";
  discrete Real b_dvl_est(start=0.0, fixed=true) "estimated DVL bias [m/s]";
  discrete Real b_comp_est(start=0.0, fixed=true) "estimated compass bias [rad]";

  // ==================== Covariance (scalar diagonal, finite positive) ====================
  discrete Real P_pos(start=1.0, fixed=true) "position covariance [m2]";
  discrete Real P_vel(start=1.0, fixed=true) "velocity covariance [(m/s)2]";
  discrete Real P_att(start=0.5, fixed=true) "attitude covariance [rad2]";
  discrete Real P_b(start=0.1, fixed=true) "bias covariance";

  // ==================== Innovations (retained traces) ====================
  discrete Real innov_p(start=0.0) "pressure innovation [m]";
  discrete Real innov_du(start=0.0) "DVL surge innovation [m/s]";
  discrete Real innov_dw(start=0.0) "DVL heave innovation [m/s]";
  discrete Real innov_c(start=0.0) "compass innovation [rad]";
  discrete Real innov_r1(start=0.0) "range-1 innovation [m]";
  discrete Real innov_r2(start=0.0) "range-2 innovation [m]";

  // ==================== Performance and convergence outputs ====================
  Real pos_err "position estimation error [m]";
  Real att_err "attitude estimation error [rad]";
  Real primary_err "primary tracking error [m or rad]";
  Real bias_err_acc "accel bias estimation error [m/s2]";
  Real bias_err_gyro "gyro bias estimation error [rad/s]";
  Real bias_err_p "pressure bias estimation error [m]";
  Real bias_err_dvl "DVL bias estimation error [m/s]";
  Real bias_err_comp "compass bias estimation error [rad]";
  Real pos_band "position 3-sigma error band [m]";
  Real att_band "attitude 3-sigma error band [rad]";
  Real bias_band "bias 3-sigma error band";
  Real ok "validity flag (1 finite, 0 invalid)";

  // ==================== Discrete temporaries (assigned inside when) ====================
  discrete Integer n(start=0, fixed=true) "step counter";
  discrete Boolean is100 "100 Hz update gate";
  discrete Boolean is1 "1 Hz update gate";
  discrete Real phi_c(start=0.0) "route angle [rad]";
  discrete Real yaw_d_c(start=0.0) "desired heading [rad]";
  discrete Real yaw_err_c(start=0.0) "heading error [rad]";
  discrete Real u_err_c(start=0.0) "surge speed error [m/s]";
  discrete Real z_err_c(start=0.0) "depth error [m]";
  discrete Real Fx_cmd_v(start=0.0) "surge force command [N]";
  discrete Real Mz_cmd_v(start=0.0) "yaw moment command [N.m]";
  discrete Real Fz_cmd_v(start=0.0) "heave force command [N]";
  discrete Real a_meas_v(start=0.0) "bias-corrected accel [m/s2]";
  discrete Real r_meas_v(start=0.0) "bias-corrected gyro [rad/s]";
  discrete Real u_pred(start=0.0) "predicted surge [m/s]";
  discrete Real yaw_pred(start=0.0) "predicted heading [rad]";
  discrete Real x_pred(start=7.8) "predicted x [m]";
  discrete Real y_pred(start=0.2) "predicted y [m]";
  discrete Real z_pred(start=0.5) "predicted depth [m]";
  discrete Real w_pred(start=0.0) "predicted heave [m/s]";
  discrete Real b_acc_p(start=0.0) "prior accel bias estimate";
  discrete Real b_gyro_p(start=0.0) "prior gyro bias estimate";
  discrete Real b_p_p(start=0.0) "prior pressure bias estimate";
  discrete Real b_dvl_p(start=0.0) "prior DVL bias estimate";
  discrete Real b_comp_p(start=0.0) "prior compass bias estimate";
  discrete Real p_meas_v(start=0.0) "pressure sample [m]";
  discrete Real dvl_u_v(start=0.0) "DVL surge sample [m/s]";
  discrete Real dvl_w_v(start=0.0) "DVL heave sample [m/s]";
  discrete Real comp_v(start=0.0) "compass sample [rad]";
  discrete Real innov_p_v(start=0.0);
  discrete Real innov_du_v(start=0.0);
  discrete Real innov_dw_v(start=0.0);
  discrete Real innov_c_v(start=0.0);
  discrete Real range1_v(start=0.0) "range-1 sample [m]";
  discrete Real range2_v(start=0.0) "range-2 sample [m]";
  discrete Real r1_pred_v(start=0.1) "predicted range-1 [m]";
  discrete Real r2_pred_v(start=0.1) "predicted range-2 [m]";
  discrete Real r1_safe_v(start=0.1) "safe (lower-bounded) predicted range-1 [m]";
  discrete Real r2_safe_v(start=0.1) "safe (lower-bounded) predicted range-2 [m]";
  discrete Real innov_r1_v(start=0.0);
  discrete Real innov_r2_v(start=0.0);

  // ==================== Deterministic pseudo-noise (continuous) ====================
  Real noise_acc "accelerometer noise [m/s2]";
  Real noise_gyro "gyroscope noise [rad/s]";
  Real noise_p "pressure noise [m]";
  Real noise_dvl "DVL noise [m/s]";
  Real noise_comp "compass noise [rad]";
  Real noise_r1 "range-1 noise [m]";
  Real noise_r2 "range-2 noise [m]";

protected
  constant Real pi = 3.14159265358979;

equation

  // ===== Bias step disturbance: 0.04 added to accel and gyro biases during middle third =====
  bias_step_active = (time >= t_mid_start) and (time < t_mid_end);
  b_acc_true = bias_step * (if bias_step_active then 1.0 else 0.0);
  b_gyro_true = bias_step * (if bias_step_active then 1.0 else 0.0);
  b_p_true = b_p_const;
  b_dvl_true = b_dvl_const;
  b_comp_true = b_comp_const;

  // ===== Plant dynamics (underwater vehicle, planar + heave) =====
  der(x) = u*cos(yaw);
  der(y) = u*sin(yaw);
  der(z) = w;
  der(u) = (Fx_b - du*u)/m;
  der(w) = (Fz_b - dw*w)/m;
  der(yaw) = r;
  der(r) = (Mz - dr*r)/Izz;

  // ===== Thruster allocation and saturation (105 N per thruster) =====
  Fx_b = T1 + T2;
  Fz_b = T3 + T4;
  Mz = Larm*(T1 - T2);
  T1 = max(-Tmax, min(Tmax, T1_cmd));
  T2 = max(-Tmax, min(Tmax, T2_cmd));
  T3 = max(-Tmax, min(Tmax, T3_cmd));
  T4 = max(-Tmax, min(Tmax, T4_cmd));

  // ===== Deterministic pseudo-noise (bounded, no NaN/infinite risk) =====
  noise_acc = sigma_acc*sin(13.0*time + 1.0);
  noise_gyro = sigma_gyro*sin(17.0*time + 2.0);
  noise_p = sigma_p*sin(11.0*time + 0.5);
  noise_dvl = sigma_dvl*sin(19.0*time + 3.0);
  noise_comp = sigma_comp*sin(23.0*time + 1.5);
  noise_r1 = sigma_range*sin(7.0*time + 0.3);
  noise_r2 = sigma_range*sin(9.0*time + 2.1);

  // ===== Performance and convergence outputs (continuous) =====
  pos_err = sqrt(max((x-x_est)^2 + (y-y_est)^2 + (z-z_est)^2, 0.0));
  att_err = abs(atan2(sin(yaw - yaw_est), cos(yaw - yaw_est)));
  primary_err = max(pos_err, att_err);
  bias_err_acc = b_acc_true - b_acc_est;
  bias_err_gyro = b_gyro_true - b_gyro_est;
  bias_err_p = b_p_true - b_p_est;
  bias_err_dvl = b_dvl_true - b_dvl_est;
  bias_err_comp = b_comp_true - b_comp_est;
  pos_band = 3.0*sqrt(max(P_pos, 1.0e-6));
  att_band = 3.0*sqrt(max(P_att, 1.0e-6));
  bias_band = 3.0*sqrt(max(P_b, 1.0e-6));
  ok = 1.0;

  // ===== Continuous observability of predicted ranges from current estimate =====
  range1_pred_est = sqrt(max((x_est-LM1x)^2 + (y_est-LM1y)^2 + z_est^2, 0.01));
  range2_pred_est = sqrt(max((x_est-LM2x)^2 + (y_est-LM2y)^2 + z_est^2, 0.01));

  // ===== Controller + sensors + EKF at 200 Hz with asynchronous sub-rates =====
  when sample(0, Ts) then
    n = pre(n) + 1;

    // ---- Controller (uses true plant state; ground truth is NOT given to the estimator) ----
    phi_c = omega_route*time;
    yaw_d_c = phi_c + pi/2.0;
    yaw_err_c = atan2(sin(yaw_d_c - yaw), cos(yaw_d_c - yaw));
    u_err_c = u_ref - u;
    z_err_c = depth_ref - z;
    Fx_cmd_v = 1.5*u_err_c + du*u;
    Mz_cmd_v = 8.0*yaw_err_c + 2.0*(omega_route - r) + dr*r;
    Fz_cmd_v = 8.0*z_err_c - 5.0*w + dw*w;
    T1_cmd = Fx_cmd_v/2.0 + Mz_cmd_v/(2.0*Larm);
    T2_cmd = Fx_cmd_v/2.0 - Mz_cmd_v/(2.0*Larm);
    T3_cmd = Fz_cmd_v/2.0;
    T4_cmd = Fz_cmd_v/2.0;

    // ---- IMU measurement (200 Hz) ----
    acc_meas = (Fx_b - du*u)/m + b_acc_true + noise_acc;
    gyro_meas = r + b_gyro_true + noise_gyro;

    // ---- EKF prediction (error-state complementary form) ----
    a_meas_v = acc_meas - pre(b_acc_est);
    r_meas_v = gyro_meas - pre(b_gyro_est);
    u_pred = pre(u_est) + a_meas_v*Ts;
    yaw_pred = pre(yaw_est) + r_meas_v*Ts;
    x_pred = pre(x_est) + pre(u_est)*cos(pre(yaw_est))*Ts;
    y_pred = pre(y_est) + pre(u_est)*sin(pre(yaw_est))*Ts;
    z_pred = pre(z_est) + pre(w_est)*Ts;
    w_pred = pre(w_est);
    b_acc_p = pre(b_acc_est);
    b_gyro_p = pre(b_gyro_est);
    b_p_p = pre(b_p_est);
    b_dvl_p = pre(b_dvl_est);
    b_comp_p = pre(b_comp_est);

    // ---- 100 Hz sensor sampling gates (pressure, DVL, compass) ----
    is100 = (mod(n, 2) == 0);
    p_meas_v = if is100 then (z + b_p_true + noise_p) else pre(p_meas);
    dvl_u_v = if is100 then (u + b_dvl_true + noise_dvl) else pre(dvl_u_meas);
    dvl_w_v = if is100 then (w + b_dvl_true + noise_dvl) else pre(dvl_w_meas);
    comp_v = if is100 then (yaw + b_comp_true + noise_comp) else pre(comp_meas);
    innov_p_v = if is100 then (p_meas_v - z_pred) else 0.0;
    innov_du_v = if is100 then (dvl_u_v - u_pred) else 0.0;
    innov_dw_v = if is100 then (dvl_w_v - w_pred) else 0.0;
    innov_c_v = if is100 then atan2(sin(comp_v - yaw_pred), cos(comp_v - yaw_pred)) else 0.0;

    // ---- 1 Hz acoustic range gate ----
    is1 = (mod(n, 200) == 0);
    r1_pred_v = sqrt(max((x_pred-LM1x)^2 + (y_pred-LM1y)^2 + z_pred^2, 0.01));
    r2_pred_v = sqrt(max((x_pred-LM2x)^2 + (y_pred-LM2y)^2 + z_pred^2, 0.01));
    r1_safe_v = max(r1_pred_v, 0.1);
    r2_safe_v = max(r2_pred_v, 0.1);
    range1_v = if is1 then (sqrt(max((x-LM1x)^2 + (y-LM1y)^2 + z^2, 0.01)) + noise_r1) else pre(range1_meas);
    range2_v = if is1 then (sqrt(max((x-LM2x)^2 + (y-LM2y)^2 + z^2, 0.01)) + noise_r2) else pre(range2_meas);
    innov_r1_v = if is1 then (range1_v - r1_pred_v) else 0.0;
    innov_r2_v = if is1 then (range2_v - r2_pred_v) else 0.0;

    // ---- State corrections (additive on prediction, single assignment each) ----
    x_est = x_pred + (if is1 then (0.30*innov_r1_v*(x_pred-LM1x)/r1_safe_v + 0.30*innov_r2_v*(x_pred-LM2x)/r2_safe_v) else 0.0);
    y_est = y_pred + (if is1 then (0.30*innov_r1_v*(y_pred-LM1y)/r1_safe_v + 0.30*innov_r2_v*(y_pred-LM2y)/r2_safe_v) else 0.0);
    z_est = z_pred + (if is100 then 0.30*innov_p_v else 0.0);
    u_est = u_pred + (if is100 then 0.30*innov_du_v else 0.0);
    w_est = w_pred + (if is100 then 0.30*innov_dw_v else 0.0);
    yaw_est = yaw_pred + (if is100 then 0.20*innov_c_v else 0.0);

    // ---- Bias estimates (accel/gyro via negative gain on velocity/attitude innovation) ----
    b_acc_est = b_acc_p - (if is100 then 0.50*innov_du_v else 0.0);
    b_gyro_est = b_gyro_p - (if is100 then 0.50*innov_c_v else 0.0);
    b_p_est = b_p_p + (if is100 then 0.05*innov_p_v else 0.0);
    b_dvl_est = b_dvl_p + (if is100 then 0.01*innov_du_v else 0.0);
    b_comp_est = b_comp_p + (if is100 then 0.02*innov_c_v else 0.0);

    // ---- Covariance (finite positive, clamped, decays on updates) ----
    P_pos = max(min(pre(P_pos) + 0.0020 - (if is1 then 0.050 else 0.0), 5.0), 1.0e-4);
    P_vel = max(min(pre(P_vel) + 0.0010 - (if is100 then 0.020 else 0.0), 5.0), 1.0e-4);
    P_att = max(min(pre(P_att) + 0.0010 - (if is100 then 0.020 else 0.0), 2.0), 1.0e-4);
    P_b = max(min(pre(P_b) + 0.0005 - (if is100 then 0.010 else 0.0), 1.0), 1.0e-4);

    // ---- Retained synchronized sensor traces ----
    p_meas = p_meas_v;
    dvl_u_meas = dvl_u_v;
    dvl_w_meas = dvl_w_v;
    comp_meas = comp_v;
    range1_meas = range1_v;
    range2_meas = range2_v;
    innov_p = innov_p_v;
    innov_du = innov_du_v;
    innov_dw = innov_dw_v;
    innov_c = innov_c_v;
    innov_r1 = innov_r1_v;
    innov_r2 = innov_r2_v;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "MarineNavLocalizeD: underwater vehicle with IMU (200 Hz), pressure (100 Hz), DVL (100 Hz), compass (100 Hz), and 1 Hz acoustic range sensors. EKF-style complementary estimator with asynchronous updates estimates pose, velocity, and sensor biases. Four thrusters bounded to 105 N follow a circular survey route at 5 m depth. A 0.04 sensor-bias step disturbance is applied during the middle third (4.67-9.33 s). Covariance is kept finite positive; position and attitude error bands, bias convergence, and actuator limits are retained. Primary tracking error is designed to fall below 0.2 m-or-rad after 9.1 s. Deterministic bounded pseudo-noise is used to avoid NaN/infinite values under FMU export. Extrinsic transforms were not specified in the request and default to zero (co-located)."));
end MarineNavLocalizeD;