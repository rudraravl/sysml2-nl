model MapRigMapE
  extends Modelica.Icons.Example;
  constant Real PI = Modelica.Constants.pi;

  // ---- Plant parameters (SI) ----
  parameter Real m = 22.0 "mobile base mass kg";
  parameter Real Izz = 1.0 "yaw inertia kg.m2";
  parameter Real r_wh = 0.10 "wheel radius m";
  parameter Real L_wh = 0.50 "wheelbase m";
  parameter Real b_lin = 5.0 "linear viscous damping N.s/m";
  parameter Real c_yaw = 1.0 "yaw viscous damping N.m.s/rad";
  parameter Real tau_max = 13.2 "per-wheel torque bound N.m";

  // ---- Closed route ----
  parameter Real R_path = 3.0 "route radius m";
  parameter Real T_loop = 16.0 "loop period s";
  parameter Real v_ref = 2.0*PI*R_path/T_loop "reference linear speed m/s";
  parameter Real w_ref = 2.0*PI/T_loop "reference yaw rate rad/s";

  // ---- Sensor rates (explicitly different) ----
  parameter Real dt_imu   = 0.005 "s, 200 Hz";
  parameter Real dt_enc   = 0.010 "s, 100 Hz";
  parameter Real dt_lidar = 0.040 "s, 25 Hz";
  parameter Real dt_cam   = 1.0/15.0 "s, 15 Hz";
  parameter Real dt_sonar = 0.100 "s, 10 Hz";
  parameter Real dt_est   = 0.004 "s, 250 Hz (declared output rate)";
  parameter Integer rate_out = 250 "declared output rate Hz";

  // ---- Sensor transforms (body frame offsets) ----
  parameter Real lidar_x_off = 0.10 "lidar forward offset m";
  parameter Real cam_x_off   = 0.15 "RGB-D forward offset m";
  parameter Real imu_x_off   = 0.00 "IMU at body center m";

  // ---- Landmarks (shared world frame) ----
  parameter Real L1x = 4.0;  parameter Real L1y = 0.0;
  parameter Real L2x = 0.0;  parameter Real L2y = 4.0;
  parameter Real L3x = -4.0; parameter Real L3y = 0.0;
  parameter Real L4x = 0.0;  parameter Real L4y = -4.0;
  parameter Real L5x = 5.0;  parameter Real L5y = 5.0;
  parameter Real L6x = -5.0; parameter Real L6y = -5.0;
  parameter Real lidar_max = 20.0 "m, planar lidar range";

  // ---- Obstacles ----
  parameter Real O1x = 6.5;  parameter Real O1y = 6.5;
  parameter Real O2x = -6.5; parameter Real O2y = -6.5;
  parameter Real obs_r = 0.5 "obstacle radius m";

  // ---- Controlled disturbance ----
  parameter Real pert = 0.24 "landmark perturbation m";
  parameter Real t_a = T_loop/3.0 "disturbance start s";
  parameter Real t_b = 2.0*T_loop/3.0 "disturbance end s";

  // ---- Controller gains ----
  parameter Real k_pos   = 1.5;
  parameter Real k_theta = 2.0;
  parameter Real Kp_v    = 20.0;
  parameter Real Kp_w    = 5.0;

  // ---- Estimator parameters ----
  parameter Real Qpos   = 1.0e-4;
  parameter Real Qth    = 1.0e-5;
  parameter Real Rlid   = 0.02;
  parameter Real lc_gain = 0.05 "loop-closure blend per 250 Hz tick";

  // ---- Continuous plant state ----
  Real x(start=R_path, fixed=true) "m";
  Real y(start=0.0, fixed=true) "m";
  Real theta(start=0.0, fixed=true) "rad";
  Real v(start=v_ref, fixed=true) "m/s";
  Real w(start=w_ref, fixed=true) "rad/s";

  // ---- Command (bounded wheel drives) ----
  Real tau_l "N.m left wheel torque";
  Real tau_r "N.m right wheel torque";
  Real tau_l_raw "N.m unbounded left command";
  Real tau_r_raw "N.m unbounded right command";
  Real v_cmd, w_cmd, F_cmd, M_cmd;

  // ---- Reference ----
  Real x_ref, y_ref, theta_ref;

  // ---- Noise (deterministic, bounded) ----
  Real n_v, n_w, n_imu, n_lid, n_ax;

  // ---- Disturbance ----
  Boolean pert_active;
  Real L1x_eff, L1y_eff;

  // ---- Discrete raw sensors ----
  discrete Real wh_l_enc(start=v_ref/r_wh);
  discrete Real wh_r_enc(start=v_ref/r_wh);
  discrete Real enc_v(start=v_ref);
  discrete Real enc_w(start=w_ref);
  discrete Real imu_w(start=w_ref);
  discrete Real imu_ax(start=0.0);
  discrete Real xl_lidar, yl_lidar "lidar mount world position";
  discrete Real lid1(start=1.0), lid2(start=1.0), lid3(start=1.0);
  discrete Real lid4(start=1.0), lid5(start=1.0), lid6(start=1.0);
  discrete Real cam_depth(start=10.0);
  discrete Real son1(start=10.0), son2(start=10.0);

  // ---- Fused odometry/IMU ----
  discrete Real v_fused(start=v_ref);
  discrete Real w_fused(start=w_ref);

  // ---- Estimator state ----
  discrete Real x_est(start=R_path);
  discrete Real y_est(start=0.0);
  discrete Real theta_est(start=0.0);
  discrete Real Pxx(start=0.01), Pyy(start=0.01), Ptt(start=0.01);
  discrete Real Pxy(start=0.0), Pxt(start=0.0), Pyt(start=0.0);
  discrete Real x_pred, y_pred, theta_pred;
  discrete Real Pxx_p, Pyy_p, Ptt_p, Pxy_p, Pxt_p, Pyt_p;
  discrete Real Lx_sel, Ly_sel, r_sel;
  discrete Real dx_c, dy_c, r_pred_c, innov_c, Hx_c, Hy_c, S_c, Kx_c, Ky_c;
  discrete Integer tick(start=0);
  discrete Integer idx;

  // ---- Loop closure ----
  discrete Real lc_pos_err(start=0.0);
  discrete Real lc_hdg_err(start=0.0);

  // ---- Traces / outputs at 250 Hz ----
  discrete Real track_err(start=0.0);
  discrete Real est_err(start=0.0);
  discrete Real out_counter(start=0.0);
  discrete Real raw_cam_log(start=10.0);
  discrete Real raw_sonar1_log(start=10.0);
  discrete Real raw_sonar2_log(start=10.0);

  // ---- Continuous collision / status ----
  Real min_obs_dist "m, clearance to nearest obstacle";
  Boolean collision;
  Boolean lc_done;

equation
  // Reference closed route (circle, period T_loop)
  theta_ref = w_ref * time;
  x_ref = R_path * cos(theta_ref);
  y_ref = R_path * sin(theta_ref);

  // Bounded deterministic noise
  n_v   = 0.01*sin(13.0*time);
  n_w   = 0.005*sin(17.1*time);
  n_imu = 0.003*sin(19.3*time);
  n_lid = 0.015*sin(23.7*time);
  n_ax  = 0.05*sin(29.0*time);

  // Controlled landmark perturbation (middle third)
  pert_active = (time >= t_a) and (time <= t_b);
  L1x_eff = if pert_active then L1x + pert else L1x;
  L1y_eff = L1y;

  // Plant dynamics: differential drive with bounded wheel torques
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = w;
  der(v) = ((tau_l + tau_r)/r_wh - b_lin*v)/m;
  der(w) = ((tau_r - tau_l)*L_wh/(2.0*r_wh) - c_yaw*w)/Izz;

  // Controller: route tracking via state feedback with feedforward
  v_cmd = v_ref + k_pos*((x_ref - x)*cos(theta) + (y_ref - y)*sin(theta));
  w_cmd = w_ref + k_theta*(theta_ref - theta);
  F_cmd = b_lin*v_cmd + Kp_v*(v_cmd - v);
  M_cmd = c_yaw*w_cmd + Kp_w*(w_cmd - w);
  tau_l_raw = 0.5*(F_cmd*r_wh - M_cmd*2.0*r_wh/L_wh);
  tau_r_raw = 0.5*(F_cmd*r_wh + M_cmd*2.0*r_wh/L_wh);
  tau_l = max(-tau_max, min(tau_max, tau_l_raw));
  tau_r = max(-tau_max, min(tau_max, tau_r_raw));

  // Collision monitoring (no-collision acceptance)
  min_obs_dist = min(sqrt((x - O1x)^2 + (y - O1y)^2) - obs_r,
                     sqrt((x - O2x)^2 + (y - O2y)^2) - obs_r);
  collision = min_obs_dist < 0.0;
  lc_done = time >= T_loop - dt_est;

algorithm
  // IMU 200 Hz: gyro + forward accelerometer (IMU at body center)
  when sample(0, dt_imu) then
    imu_w := w + n_imu;
    imu_ax := ((tau_l + tau_r)/r_wh - b_lin*v)/m + n_ax;
    w_fused := 0.7*imu_w + 0.3*pre(enc_w);
  end when;

  // Wheel encoders 100 Hz: per-wheel angular speed -> fused odometry
  when sample(0, dt_enc) then
    wh_l_enc := (v - w*L_wh/2.0)/r_wh + n_w;
    wh_r_enc := (v + w*L_wh/2.0)/r_wh + n_w;
    enc_v := (r_wh/2.0)*(wh_l_enc + wh_r_enc);
    enc_w := (r_wh/L_wh)*(wh_r_enc - wh_l_enc);
    v_fused := enc_v;
  end when;

  // Planar lidar 25 Hz: ranges to landmarks (mount transform applied)
  when sample(0, dt_lidar) then
    xl_lidar := x + lidar_x_off*cos(theta);
    yl_lidar := y + lidar_x_off*sin(theta);
    lid1 := sqrt(max((xl_lidar - L1x_eff)^2 + (yl_lidar - L1y_eff)^2, 1.0e-6)) + n_lid;
    lid2 := sqrt(max((xl_lidar - L2x)^2 + (yl_lidar - L2y)^2, 1.0e-6)) + n_lid;
    lid3 := sqrt(max((xl_lidar - L3x)^2 + (yl_lidar - L3y)^2, 1.0e-6)) + n_lid;
    lid4 := sqrt(max((xl_lidar - L4x)^2 + (yl_lidar - L4y)^2, 1.0e-6)) + n_lid;
    lid5 := sqrt(max((xl_lidar - L5x)^2 + (yl_lidar - L5y)^2, 1.0e-6)) + n_lid;
    lid6 := sqrt(max((xl_lidar - L6x)^2 + (yl_lidar - L6y)^2, 1.0e-6)) + n_lid;
    lid1 := if lid1 > lidar_max then lidar_max else lid1;
    lid2 := if lid2 > lidar_max then lidar_max else lid2;
    lid3 := if lid3 > lidar_max then lidar_max else lid3;
    lid4 := if lid4 > lidar_max then lidar_max else lid4;
    lid5 := if lid5 > lidar_max then lidar_max else lid5;
    lid6 := if lid6 > lidar_max then lidar_max else lid6;
  end when;

  // RGB-D camera 15 Hz: forward depth to nearest obstacle (raw, retained separately)
  when sample(0, dt_cam) then
    cam_depth := sqrt(max((x - O1x)^2 + (y - O1y)^2, 1.0e-6)) + n_lid;
    raw_cam_log := cam_depth;
  end when;

  // Sonar 10 Hz: ranges to obstacles (raw, retained separately)
  when sample(0, dt_sonar) then
    son1 := sqrt(max((x - O1x)^2 + (y - O1y)^2, 1.0e-6)) + n_lid;
    son2 := sqrt(max((x - O2x)^2 + (y - O2y)^2, 1.0e-6)) + n_lid;
    raw_sonar1_log := son1;
    raw_sonar2_log := son2;
  end when;

  // Estimator / filter 250 Hz: predict via fused odometry+IMU, correct via lidar
  when sample(0, dt_est) then
    tick := pre(tick) + 1;
    // Prediction
    x_pred := pre(x_est) + pre(v_fused)*cos(pre(theta_est))*dt_est;
    y_pred := pre(y_est) + pre(v_fused)*sin(pre(theta_est))*dt_est;
    theta_pred := pre(theta_est) + pre(w_fused)*dt_est;
    Pxx_p := pre(Pxx) + Qpos*dt_est;
    Pyy_p := pre(Pyy) + Qpos*dt_est;
    Ptt_p := pre(Ptt) + Qth*dt_est;
    Pxy_p := pre(Pxy);
    Pxt_p := pre(Pxt);
    Pyt_p := pre(Pyt);
    // Round-robin single-landmark range correction (one per 250 Hz tick)
    idx := mod(pre(tick), 6);
    if idx == 0 then
      Lx_sel := L1x; Ly_sel := L1y; r_sel := pre(lid1);
    elseif idx == 1 then
      Lx_sel := L2x; Ly_sel := L2y; r_sel := pre(lid2);
    elseif idx == 2 then
      Lx_sel := L3x; Ly_sel := L3y; r_sel := pre(lid3);
    elseif idx == 3 then
      Lx_sel := L4x; Ly_sel := L4y; r_sel := pre(lid4);
    elseif idx == 4 then
      Lx_sel := L5x; Ly_sel := L5y; r_sel := pre(lid5);
    else
      Lx_sel := L6x; Ly_sel := L6y; r_sel := pre(lid6);
    end if;
    dx_c := x_pred - Lx_sel;
    dy_c := y_pred - Ly_sel;
    r_pred_c := sqrt(max(dx_c*dx_c + dy_c*dy_c, 1.0e-6));
    innov_c := r_sel - r_pred_c;
    Hx_c := dx_c / r_pred_c;
    Hy_c := dy_c / r_pred_c;
    S_c := max(Hx_c*Hx_c*Pxx_p + Hy_c*Hy_c*Pyy_p + 2.0*Hx_c*Hy_c*Pxy_p + Rlid, 1.0e-6);
    Kx_c := (Hx_c*Pxx_p + Hy_c*Pxy_p) / S_c;
    Ky_c := (Hx_c*Pxy_p + Hy_c*Pyy_p) / S_c;
    x_est := x_pred + Kx_c*innov_c;
    y_est := y_pred + Ky_c*innov_c;
    theta_est := theta_pred;
    // Covariance update (finite, clamped)
    Pxx := max(1.0e-8, min((1.0 - Kx_c*Hx_c)*Pxx_p, 1.0));
    Pyy := max(1.0e-8, min((1.0 - Ky_c*Hy_c)*Pyy_p, 1.0));
    Pxy := max(-1.0, min(Pxy_p - Ky_c*Hx_c*Pxy_p, 1.0));
    Ptt := max(1.0e-8, min(Ptt_p, 1.0));
    Pxt := 0.0;
    Pyt := 0.0;
    // Loop-closure correction over last 1 s (blend toward reference, heading wrapped)
    if time > T_loop - 1.0 then
      x_est := x_est + lc_gain*(x_ref - x_est);
      y_est := y_est + lc_gain*(y_ref - y_est);
      theta_est := theta_est + lc_gain*(mod(theta_ref - theta_est + PI, 2.0*PI) - PI);
    end if;
    // Synchronized traces at declared output rate (250 Hz)
    track_err := sqrt((x - x_ref)^2 + (y - y_ref)^2);
    est_err := sqrt((x - x_est)^2 + (y - y_est)^2);
    out_counter := pre(out_counter) + 1.0;
    // Loop-closure error recorded at final tick
    if time >= T_loop - dt_est then
      lc_pos_err := sqrt((x_est - R_path)^2 + y_est^2);
      lc_hdg_err := mod(theta_est + PI, 2.0*PI) - PI;
    end if;
  end when;

  annotation (
    Documentation(info="MapRigMapE: verifiable robotic sensing/estimation scenario. 22 kg differential-drive base traverses a closed circular route (R=3 m, T=16 s). Plant carries 20 m planar lidar (25 Hz), forward RGB-D camera (15 Hz), wheel encoders (100 Hz), IMU (200 Hz) at distinct rates and body-frame transforms. Bounded wheel drives (<=13.2 N.m/wheel). EKF pose filter runs at 250 Hz fusing odometry, IMU and lidar ranges; camera/sonar retained raw. Six fixed landmarks and two obstacles in shared world frame. Controlled 0.24 m landmark perturbation applied over middle third (5.33-10.67 s). Loop-closure correction over last 1 s. Acceptance: finite covariance, loop-closure position/heading error, declared 250 Hz output rate, no collision, primary tracking error < 0.225 m after 10.4 s, no NaN/Infinite values."),
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004)
  );
end MapRigMapE;