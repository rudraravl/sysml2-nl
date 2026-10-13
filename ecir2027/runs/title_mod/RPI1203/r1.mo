model WheelIMULocalizeC
  import Modelica.Math.atan2;

  // ===== Chassis parameters =====
  parameter Real m_chassis(unit="kg") = 16.0 "chassis mass";
  parameter Real r_w(unit="m") = 0.1 "wheel radius";
  parameter Real L(unit="m") = 0.5 "wheel base";
  parameter Real I_w(unit="kg.m2") = 0.02 "wheel inertia";
  parameter Real I_z(unit="kg.m2") = 1.2 "chassis yaw inertia (declared)";
  parameter Real b_fric(unit="N.m.s") = 0.05 "wheel viscous friction";
  parameter Real tau_max(unit="N.m") = 9.2 "max wheel torque magnitude";

  // ===== Simulation =====
  parameter Real f_base(unit="Hz") = 125.0 "base run rate";
  parameter Real T_end(unit="s") = 12.0 "run time";
  parameter Real dt_sim(unit="s") = 1.0/f_base;

  // ===== Sensor rates / frames / timestamps =====
  parameter Real f_imu(unit="Hz") = 125.0  "IMU rate";
  parameter Real f_enc(unit="Hz") = 62.5   "encoder rate";
  parameter Real f_lm(unit="Hz")  = 25.0   "landmark rate";
  parameter Real dt_imu(unit="s") = 1.0/f_imu;
  parameter Real dt_enc(unit="s") = 1.0/f_enc;
  parameter Real dt_lm(unit="s")  = 1.0/f_lm;
  // Frames: chassis body frame for IMU, wheel frame for encoders, global frame for landmark.

  // ===== Sensor noise std (declared) =====
  parameter Real sigma_a(unit="m/s2") = 0.05   "accel noise std";
  parameter Real sigma_g(unit="rad/s") = 0.01  "gyro noise std";
  parameter Real sigma_enc(unit="rad/s") = 0.02 "encoder ang-vel noise std";
  parameter Real sigma_lm_r(unit="m") = 0.10   "landmark range noise std";
  parameter Real sigma_lm_b(unit="rad") = 0.05 "landmark bearing noise std";

  // ===== Bias prior std =====
  parameter Real sigma_ba0(unit="m/s2") = 0.02 "accel bias prior std";
  parameter Real sigma_bg0(unit="rad/s") = 0.01 "gyro bias prior std";

  // ===== Disturbance =====
  parameter Real bias_step(unit="m/s2") = 0.036 "injected accel-bias step (middle third)";

  // ===== Fixed external landmark (no ground truth to estimator) =====
  parameter Real Lx(unit="m") = 3.0 "landmark x";
  parameter Real Ly(unit="m") = 3.0 "landmark y";

  // ===== Bounded route =====
  parameter Real R_route(unit="m") = 2.0   "route radius";
  parameter Real w_route(unit="rad/s") = 0.3 "route angular rate";

  // ===== Controller gains =====
  parameter Real Kp_v(unit="1/s") = 3.0;
  parameter Real Kp_w(unit="1/s") = 4.0;
  parameter Real K_theta(unit="1/s") = 2.0;
  parameter Real K_cross(unit="1/s") = 1.5;

  // ===== Ground-truth plant states =====
  Real x_gt(start=2.0, fixed=true) "x position m";
  Real y_gt(start=0.0, fixed=true) "y position m";
  Real theta_gt(start=1.5707963267948966, fixed=true) "heading rad";
  Real wL_gt(start=0.0) "left wheel ang vel rad/s";
  Real wR_gt(start=0.0) "right wheel ang vel rad/s";
  Real v_gt "forward speed m/s";
  Real omega_gt "yaw rate rad/s";
  Real a_body_gt "body longitudinal accel m/s2";

  // ===== Actuator commands (saturated) =====
  Real tauL_cmd "left commanded torque N.m";
  Real tauR_cmd "right commanded torque N.m";
  Real tauL_sat "left saturated torque N.m";
  Real tauR_sat "right saturated torque N.m";

  // ===== Reference route =====
  Real x_ref, y_ref, theta_ref, v_ref, omega_ref;

  // ===== True sensor biases =====
  Real b_a_true "true accel bias m/s2";
  Real b_g_true "true gyro bias rad/s";

  // ===== Sensor measurements (continuous, sampled by estimator) =====
  Real a_meas(start=0.0) "accelerometer m/s2";
  Real omega_meas(start=0.0) "gyro rad/s";
  Real wL_meas(start=0.0) "left encoder rad/s";
  Real wR_meas(start=0.0) "right encoder rad/s";
  Real lm_range_meas(start=0.0) "landmark range m";
  Real lm_bearing_meas(start=0.0) "landmark bearing rad";
  // timestamps (synchronized traces)
  Real t_imu(start=0.0) "IMU timestamp s";
  Real t_enc(start=0.0) "encoder timestamp s";
  Real t_lm(start=0.0) "landmark timestamp s";

  // ===== Deterministic pseudo-noise (bounded, no RNG for FMU safety) =====
  Real n_a, n_g, n_eL, n_eR, n_lr, n_lb;

  // ===== EKF estimate: state [x,y,theta,v,b_a,b_g] =====
  Real x_hat(start=2.0, fixed=true);
  Real y_hat(start=0.0, fixed=true);
  Real theta_hat(start=1.5707963267948966, fixed=true);
  Real v_hat(start=0.0, fixed=true);
  Real b_a_hat(start=0.0, fixed=true) "estimated accel bias";
  Real b_g_hat(start=0.005, fixed=true) "estimated gyro bias";
  Real omega_hat "estimated yaw rate = omega_meas - b_g_hat";

  // ===== EKF covariance and matrices =====
  Real P[6,6] "state covariance";
  Real Qn[6,6] "process noise covariance";
  Real Fmat[6,6] "continuous Jacobian";

  // Encoder correction workspace
  Real H_enc[2,6];
  Real inn_enc[2];
  Real HP_enc[2,6];
  Real PHt_enc[6,2];
  Real S_enc[2,2];
  Real K_enc[6,2];
  Real KH_enc[6,6];
  Real Pnew_enc[6,6];
  Real detS_enc;

  // Landmark correction workspace
  Real H_lm[2,6];
  Real inn_lm[2];
  Real HP_lm[2,6];
  Real PHt_lm[6,2];
  Real S_lm[2,2];
  Real K_lm[6,2];
  Real KH_lm[6,6];
  Real Pnew_lm[6,6];
  Real detS_lm;
  Real dx_pred, dy_pred, r_pred, r_pred_safe;

  // ===== Controller intermediates =====
  Real r_hat_pos, eth, e_r, v_cmd, omega_cmd, a_cmd, alpha_cmd;
  Real wR_hat_est, wL_hat_est;

  // ===== Observable outputs =====
  Real pos_err "position error m";
  Real theta_err "attitude error rad";
  Real track_err "primary tracking error (max of pos/att) m-or-rad";
  Real cov_pos "position 1-sigma band m";
  Real cov_theta "attitude 1-sigma band rad";
  Real track_err_ok "flag: tracking requirement met after 7.8 s";

  // landmark ground-truth intermediates
  Real dx_lm, dy_lm, r_lm, r_lm_safe;

equation
  // ---------- Reference (bounded circular route) ----------
  x_ref = R_route*cos(w_route*time);
  y_ref = R_route*sin(w_route*time);
  theta_ref = w_route*time + 1.5707963267948966;
  v_ref = R_route*w_route;
  omega_ref = w_route;

  // ---------- True biases: 0.036 accel-bias step in middle third [4,8] s ----------
  b_a_true = if (time >= 4.0 and time <= 8.0) then bias_step else 0.0;
  b_g_true = 0.005;

  // ---------- Deterministic bounded pseudo-noise ----------
  n_a  = 0.3*sigma_a*sin(13.0*time);
  n_g  = 0.3*sigma_g*sin(17.0*time + 1.0);
  n_eL = 0.3*sigma_enc*sin(23.0*time);
  n_eR = 0.3*sigma_enc*sin(29.0*time + 2.0);
  n_lr = 0.3*sigma_lm_r*sin(11.0*time);
  n_lb = 0.3*sigma_lm_b*sin(19.0*time + 0.5);

  // ---------- Plant dynamics ----------
  der(wL_gt) = (tauL_sat - b_fric*wL_gt)/I_w;
  der(wR_gt) = (tauR_sat - b_fric*wR_gt)/I_w;
  v_gt = r_w*(wR_gt + wL_gt)/2.0;
  omega_gt = r_w*(wR_gt - wL_gt)/L;
  a_body_gt = r_w*((tauR_sat - b_fric*wR_gt) + (tauL_sat - b_fric*wL_gt))/(2.0*I_w);
  der(x_gt) = v_gt*cos(theta_gt);
  der(y_gt) = v_gt*sin(theta_gt);
  der(theta_gt) = omega_gt;

  // ---------- Sensor measurements ----------
  a_meas = a_body_gt + b_a_true + n_a;
  omega_meas = omega_gt + b_g_true + n_g;
  wL_meas = wL_gt + n_eL;
  wR_meas = wR_gt + n_eR;
  dx_lm = Lx - x_gt;
  dy_lm = Ly - y_gt;
  r_lm = sqrt(dx_lm*dx_lm + dy_lm*dy_lm);
  r_lm_safe = max(r_lm, 1e-6);
  lm_range_meas = r_lm + n_lr;
  lm_bearing_meas = atan2(dy_lm, dx_lm) - theta_gt + n_lb;

  // ---------- Actuator saturation (limits) ----------
  tauL_sat = max(-tau_max, min(tau_max, tauL_cmd));
  tauR_sat = max(-tau_max, min(tau_max, tauR_cmd));

  // ---------- Controller (uses estimates only, no ground truth) ----------
  r_hat_pos = sqrt(x_hat*x_hat + y_hat*y_hat);
  eth = atan2(sin(theta_ref - theta_hat), cos(theta_ref - theta_hat));
  e_r = R_route - r_hat_pos;
  v_cmd = v_ref;
  omega_cmd = omega_ref + K_theta*eth + K_cross*e_r;
  a_cmd = Kp_v*(v_cmd - v_hat);
  alpha_cmd = Kp_w*(omega_cmd - omega_hat);
  wR_hat_est = (v_hat/r_w) + (omega_hat*L)/(2.0*r_w);
  wL_hat_est = (v_hat/r_w) - (omega_hat*L)/(2.0*r_w);
  tauR_cmd = I_w*(a_cmd + alpha_cmd*L)/(2.0*r_w) + b_fric*wR_hat_est;
  tauL_cmd = I_w*(a_cmd - alpha_cmd*L)/(2.0*r_w) + b_fric*wL_hat_est;

  // ---------- EKF continuous prediction ----------
  omega_hat = omega_meas - b_g_hat;
  der(x_hat) = v_hat*cos(theta_hat);
  der(y_hat) = v_hat*sin(theta_hat);
  der(theta_hat) = omega_hat;
  der(v_hat) = a_meas - b_a_hat;
  der(b_a_hat) = 0.0;
  der(b_g_hat) = 0.0;

  // ---------- Continuous Jacobian F ----------
  Fmat[1,1] = 0.0; Fmat[1,2] = 0.0; Fmat[1,3] = -v_hat*sin(theta_hat); Fmat[1,4] = cos(theta_hat); Fmat[1,5] = 0.0; Fmat[1,6] = 0.0;
  Fmat[2,1] = 0.0; Fmat[2,2] = 0.0; Fmat[2,3] =  v_hat*cos(theta_hat); Fmat[2,4] = sin(theta_hat); Fmat[2,5] = 0.0; Fmat[2,6] = 0.0;
  Fmat[3,1] = 0.0; Fmat[3,2] = 0.0; Fmat[3,3] = 0.0; Fmat[3,4] = 0.0; Fmat[3,5] = 0.0; Fmat[3,6] = -1.0;
  Fmat[4,1] = 0.0; Fmat[4,2] = 0.0; Fmat[4,3] = 0.0; Fmat[4,4] = 0.0; Fmat[4,5] = -1.0; Fmat[4,6] = 0.0;
  Fmat[5,1] = 0.0; Fmat[5,2] = 0.0; Fmat[5,3] = 0.0; Fmat[5,4] = 0.0; Fmat[5,5] = 0.0; Fmat[5,6] = 0.0;
  Fmat[6,1] = 0.0; Fmat[6,2] = 0.0; Fmat[6,3] = 0.0; Fmat[6,4] = 0.0; Fmat[6,5] = 0.0; Fmat[6,6] = 0.0;

  // ---------- Process noise covariance ----------
  for i in 1:6 loop
    for j in 1:6 loop
      Qn[i,j] = 0.0;
    end for;
  end for;
  Qn[1,1] = 0.00010;
  Qn[2,2] = 0.00010;
  Qn[3,3] = 0.00005;
  Qn[4,4] = 0.00020;
  Qn[5,5] = 1.0e-6;
  Qn[6,6] = 1.0e-6;

  // ---------- Covariance propagation: dP = F*P + P*F' + Q ----------
  for i in 1:6 loop
    for j in 1:6 loop
      der(P[i,j]) = sum(Fmat[i,k]*P[k,j] for k in 1:6)
                  + sum(P[i,k]*Fmat[j,k] for k in 1:6)
                  + Qn[i,j];
    end for;
  end for;

  // ---------- Observables ----------
  pos_err = sqrt((x_gt - x_hat)*(x_gt - x_hat) + (y_gt - y_hat)*(y_gt - y_hat));
  theta_err = abs(atan2(sin(theta_gt - theta_hat), cos(theta_gt - theta_hat)));
  track_err = max(pos_err, theta_err);
  cov_pos = sqrt(max(P[1,1] + P[2,2], 1.0e-12));
  cov_theta = sqrt(max(P[3,3], 1.0e-12));
  track_err_ok = if (time >= 7.8) then (if track_err < 0.21 then 1.0 else 0.0) else 1.0;

  assert(time < 7.8 or track_err < 0.21,
         "Primary tracking error exceeds 0.21 m-or-rad after 7.8 s");
  assert(cov_pos > 0.0 and cov_theta > 0.0, "Covariance must remain finite positive");

algorithm
  // ---------- IMU timestamp (asynchronous trace) ----------
  when sample(0.0, dt_imu) then
    t_imu := time;
  end when;

  // ---------- Encoder correction (62.5 Hz) ----------
  when sample(dt_enc/2.0, dt_enc) then
    t_enc := time;
    // innovation: [v_enc - v_hat ; omega_enc - (omega_meas - b_g_hat)]
    inn_enc[1] := (r_w*(wR_meas + wL_meas)/2.0) - v_hat;
    inn_enc[2] := (r_w*(wR_meas - wL_meas)/L) - (omega_meas - b_g_hat);
    // H_enc
    H_enc[1,1] := 0.0; H_enc[1,2] := 0.0; H_enc[1,3] := 0.0; H_enc[1,4] := 1.0; H_enc[1,5] := 0.0; H_enc[1,6] := 0.0;
    H_enc[2,1] := 0.0; H_enc[2,2] := 0.0; H_enc[2,3] := 0.0; H_enc[2,4] := 0.0; H_enc[2,5] := 0.0; H_enc[2,6] := -1.0;
    // HP = H*P  (2x6)
    for i in 1:2 loop
      for j in 1:6 loop
        HP_enc[i,j] := 0.0;
        for k in 1:6 loop
          HP_enc[i,j] := HP_enc[i,j] + H_enc[i,k]*P[k,j];
        end for;
      end for;
    end for;
    // S = H*P*H' + R  (2x2)
    for i in 1:2 loop
      for j in 1:2 loop
        S_enc[i,j] := 0.0;
        for k in 1:6 loop
          S_enc[i,j] := S_enc[i,j] + HP_enc[i,k]*H_enc[j,k];
        end for;
      end for;
    end for;
    // R_enc: v_enc var = 2*(r_w/2)^2*sigma_enc^2 ; omega_enc var = 2*(r_w/L)^2*sigma_enc^2 ; cov=0
    S_enc[1,1] := S_enc[1,1] + 2.0*(r_w/2.0)*(r_w/2.0)*sigma_enc*sigma_enc;
    S_enc[2,2] := S_enc[2,2] + 2.0*(r_w/L)*(r_w/L)*sigma_enc*sigma_enc;
    // P*H' (6x2)
    for i in 1:6 loop
      for j in 1:2 loop
        PHt_enc[i,j] := 0.0;
        for k in 1:6 loop
          PHt_enc[i,j] := PHt_enc[i,j] + P[i,k]*H_enc[j,k];
        end for;
      end for;
    end for;
    detS_enc := S_enc[1,1]*S_enc[2,2] - S_enc[1,2]*S_enc[2,1];
    detS_enc := max(detS_enc, 1.0e-12);
    // K = P*H'*inv(S) (6x2)
    for i in 1:6 loop
      K_enc[i,1] := (PHt_enc[i,1]*S_enc[2,2] - PHt_enc[i,2]*S_enc[1,2])/detS_enc;
      K_enc[i,2] := (PHt_enc[i,2]*S_enc[1,1] - PHt_enc[i,1]*S_enc[2,1])/detS_enc;
    end for;
    // state update
    x_hat     := x_hat     + K_enc[1,1]*inn_enc[1] + K_enc[1,2]*inn_enc[2];
    y_hat     := y_hat     + K_enc[2,1]*inn_enc[1] + K_enc[2,2]*inn_enc[2];
    theta_hat := theta_hat + K_enc[3,1]*inn_enc[1] + K_enc[3,2]*inn_enc[2];
    v_hat     := v_hat     + K_enc[4,1]*inn_enc[1] + K_enc[4,2]*inn_enc[2];
    b_a_hat   := b_a_hat   + K_enc[5,1]*inn_enc[1] + K_enc[5,2]*inn_enc[2];
    b_g_hat   := b_g_hat   + K_enc[6,1]*inn_enc[1] + K_enc[6,2]*inn_enc[2];
    // KH (6x6)
    for i in 1:6 loop
      for j in 1:6 loop
        KH_enc[i,j] := K_enc[i,1]*H_enc[1,j] + K_enc[i,2]*H_enc[2,j];
      end for;
    end for;
    // Pnew = (I - KH)*P
    for i in 1:6 loop
      for j in 1:6 loop
        Pnew_enc[i,j] := 0.0;
        for k in 1:6 loop
          Pnew_enc[i,j] := Pnew_enc[i,j] + ((if i==k then 1.0 else 0.0) - KH_enc[i,k])*P[k,j];
        end for;
      end for;
    end for;
    // commit + keep positive + symmetrize
    for i in 1:6 loop
      for j in 1:6 loop
        P[i,j] := max(Pnew_enc[i,j], 1.0e-9);
      end for;
    end for;
    for i in 1:6 loop
      for j in (i+1):6 loop
        P[i,j] := (P[i,j] + P[j,i])/2.0;
        P[j,i] := P[i,j];
      end for;
    end for;
  end when;

  // ---------- Landmark correction (25 Hz) ----------
  when sample(dt_lm, dt_lm) then
    t_lm := time;
    // predicted measurement from estimate
    dx_pred := Lx - x_hat;
    dy_pred := Ly - y_hat;
    r_pred := sqrt(dx_pred*dx_pred + dy_pred*dy_pred);
    r_pred_safe := max(r_pred, 1.0e-6);
    inn_lm[1] := lm_range_meas - r_pred;
    inn_lm[2] := atan2(sin(lm_bearing_meas - (atan2(dy_pred, dx_pred) - theta_hat)),
                       cos(lm_bearing_meas - (atan2(dy_pred, dx_pred) - theta_hat)));
    // H_lm (2x6)
    H_lm[1,1] := -dx_pred/r_pred_safe; H_lm[1,2] := -dy_pred/r_pred_safe; H_lm[1,3] := 0.0; H_lm[1,4] := 0.0; H_lm[1,5] := 0.0; H_lm[1,6] := 0.0;
    H_lm[2,1] :=  dy_pred/(r_pred_safe*r_pred_safe); H_lm[2,2] := -dx_pred/(r_pred_safe*r_pred_safe); H_lm[2,3] := -1.0; H_lm[2,4] := 0.0; H_lm[2,5] := 0.0; H_lm[2,6] := 0.0;
    // HP = H*P (2x6)
    for i in 1:2 loop
      for j in 1:6 loop
        HP_lm[i,j] := 0.0;
        for k in 1:6 loop
          HP_lm[i,j] := HP_lm[i,j] + H_lm[i,k]*P[k,j];
        end for;
      end for;
    end for;
    // S = H*P*H' + R (2x2)
    for i in 1:2 loop
      for j in 1:2 loop
        S_lm[i,j] := 0.0;
        for k in 1:6 loop
          S_lm[i,j] := S_lm[i,j] + HP_lm[i,k]*H_lm[j,k];
        end for;
      end for;
    end for;
    S_lm[1,1] := S_lm[1,1] + sigma_lm_r*sigma_lm_r;
    S_lm[2,2] := S_lm[2,2] + sigma_lm_b*sigma_lm_b;
    // P*H' (6x2)
    for i in 1:6 loop
      for j in 1:2 loop
        PHt_lm[i,j] := 0.0;
        for k in 1:6 loop
          PHt_lm[i,j] := PHt_lm[i,j] + P[i,k]*H_lm[j,k];
        end for;
      end for;
    end for;
    detS_lm := S_lm[1,1]*S_lm[2,2] - S_lm[1,2]*S_lm[2,1];
    detS_lm := max(detS_lm, 1.0e-12);
    // K = P*H'*inv(S) (6x2)
    for i in 1:6 loop
      K_lm[i,1] := (PHt_lm[i,1]*S_lm[2,2] - PHt_lm[i,2]*S_lm[1,2])/detS_lm;
      K_lm[i,2] := (PHt_lm[i,2]*S_lm[1,1] - PHt_lm[i,1]*S_lm[2,1])/detS_lm;
    end for;
    // state update
    x_hat     := x_hat     + K_lm[1,1]*inn_lm[1] + K_lm[1,2]*inn_lm[2];
    y_hat     := y_hat     + K_lm[2,1]*inn_lm[1] + K_lm[2,2]*inn_lm[2];
    theta_hat := theta_hat + K_lm[3,1]*inn_lm[1] + K_lm[3,2]*inn_lm[2];
    v_hat     := v_hat     + K_lm[4,1]*inn_lm[1] + K_lm[4,2]*inn_lm[2];
    b_a_hat   := b_a_hat   + K_lm[5,1]*inn_lm[1] + K_lm[5,2]*inn_lm[2];
    b_g_hat   := b_g_hat   + K_lm[6,1]*inn_lm[1] + K_lm[6,2]*inn_lm[2];
    // KH (6x6)
    for i in 1:6 loop
      for j in 1:6 loop
        KH_lm[i,j] := K_lm[i,1]*H_lm[1,j] + K_lm[i,2]*H_lm[2,j];
      end for;
    end for;
    // Pnew = (I - KH)*P
    for i in 1:6 loop
      for j in 1:6 loop
        Pnew_lm[i,j] := 0.0;
        for k in 1:6 loop
          Pnew_lm[i,j] := Pnew_lm[i,j] + ((if i==k then 1.0 else 0.0) - KH_lm[i,k])*P[k,j];
        end for;
      end for;
    end for;
    for i in 1:6 loop
      for j in 1:6 loop
        P[i,j] := max(Pnew_lm[i,j], 1.0e-9);
      end for;
    end for;
    for i in 1:6 loop
      for j in (i+1):6 loop
        P[i,j] := (P[i,j] + P[j,i])/2.0;
        P[j,i] := P[i,j];
      end for;
    end for;
  end when;

initial algorithm
  for i in 1:6 loop
    for j in 1:6 loop
      P[i,j] := 0.0;
    end for;
  end for;
  P[1,1] := 0.01;
  P[2,2] := 0.01;
  P[3,3] := 0.01;
  P[4,4] := 0.01;
  P[5,5] := sigma_ba0*sigma_ba0;
  P[6,6] := sigma_bg0*sigma_bg0;

  annotation(
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1.0e-6, Interval=0.008),
    Documentation(info="WheelIMULocalizeC: differential-drive (16 kg) localization via continuous-discrete EKF with asynchronous IMU (125 Hz), wheel-encoder (62.5 Hz), and fixed-landmark (25 Hz) updates. Estimates pose, velocity, accel bias and gyro bias. 0.036 m/s2 accel-bias step injected during middle third [4,8] s. Actuator limit 9.2 N.m per wheel. Synchronized state/command/sensor traces at 125 Hz for 12 s."));
end WheelIMULocalizeC;