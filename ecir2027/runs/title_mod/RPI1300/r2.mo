model MarineNavLocalizeD
  "Underwater vehicle navigation/localization with EKF, asynchronous sensors, bounded thrusters."

  // ---------- Helper functions ----------
  function wrap "Wrap angle to [-pi,pi]"
    input Real a;
    output Real b;
  algorithm
    b := atan2(sin(a), cos(a));
  end wrap;

  function rangeTo "Range from point to beacon with zero-guard"
    input Real px, py, pz, bx, by, bz;
    output Real r;
  algorithm
    r := sqrt(max((px-bx)^2 + (py-by)^2 + (pz-bz)^2, 1e-9));
  end rangeTo;

  function sat "Saturation"
    input Real x, lim;
    output Real y;
  algorithm
    y := if x > lim then lim else if x < -lim then -lim else x;
  end sat;

  function ekfUpdate "Scalar (sensor) EKF update returning state and covariance"
    input Real x_in[12];
    input Real P_in[12,12];
    input Real H[12];
    input Real inn;
    input Real R;
    output Real x_out[12];
    output Real P_out[12,12];
  protected
    Real S, K[12], HP[12];
  algorithm
    S := R;
    for k in 1:12 loop
      for l in 1:12 loop
        S := S + H[k]*P_in[k,l]*H[l];
      end for;
    end for;
    S := max(S, 1e-12);
    for k in 1:12 loop
      K[k] := 0.0;
      for l in 1:12 loop
        K[k] := K[k] + P_in[k,l]*H[l];
      end for;
      K[k] := K[k]/S;
    end for;
    for k in 1:12 loop
      x_out[k] := x_in[k] + K[k]*inn;
    end for;
    for j in 1:12 loop
      HP[j] := 0.0;
      for l in 1:12 loop
        HP[j] := HP[j] + H[l]*P_in[l,j];
      end for;
    end for;
    for i in 1:12 loop
      for j in 1:12 loop
        P_out[i,j] := P_in[i,j] - K[i]*HP[j];
      end for;
    end for;
  end ekfUpdate;

  // ---------- Timing ----------
  parameter Real T_sim = 14.0 "Simulation duration [s]";
  parameter Real dt = 0.005 "EKF/IMU loop period (200 Hz) [s]";

  // ---------- Vehicle ----------
  parameter Real m = 120.0 "Mass [kg]";
  parameter Real Iz = 25.0 "Yaw inertia [kg.m2]";
  parameter Real Xu = 80.0 "Forward drag [N.s/m]";
  parameter Real Yv = 90.0 "Lateral drag [N.s/m]";
  parameter Real Zw = 70.0 "Vertical drag [N.s/m]";
  parameter Real Nr = 18.0 "Yaw rotational drag [N.m.s]";
  parameter Real Fmax = 105.0 "Per-thruster force limit [N]";
  parameter Real Lt = 0.8 "Thruster moment arm [m]";

  // ---------- Route ----------
  parameter Real R_route = 2.5 "Route radius [m]";
  parameter Real w_route = 0.25 "Route angular rate [rad/s]";
  parameter Real z_ref = 1.5 "Reference depth [m]";

  // ---------- Sensor rates [Hz] ----------
  parameter Real f_imu = 200.0;
  parameter Real f_depth = 50.0;
  parameter Real f_doppler = 5.0;
  parameter Real f_compass = 10.0;
  parameter Real f_range = 1.0;

  // ---------- Sensor std devs ----------
  parameter Real sigma_a = 0.03 "Accel std [m/s2]";
  parameter Real sigma_g = 0.005 "Gyro std [rad/s]";
  parameter Real sigma_z = 0.04 "Depth std [m]";
  parameter Real sigma_d = 0.015 "Doppler std [m/s]";
  parameter Real sigma_c = 0.015 "Compass std [rad]";
  parameter Real sigma_r = 0.08 "Acoustic range std [m]";

  // ---------- Bias disturbance (middle third) ----------
  parameter Real t_a = 14.0/3.0 "Middle third start [s]";
  parameter Real t_b = 28.0/3.0 "Middle third end [s]";
  parameter Real dbias = 0.04 "Bias step magnitude";

  // ---------- Fixed landmarks ----------
  parameter Real L1x = 6.0; parameter Real L1y = 0.0; parameter Real L1z = 0.5;
  parameter Real L2x = 0.0; parameter Real L2y = 6.0; parameter Real L2z = 0.5;

  // ---------- Controller gains ----------
  parameter Real Kp_pos = 40.0;
  parameter Real Kd_pos = 28.0;
  parameter Real Kp_dep = 60.0;
  parameter Real Kd_dep = 30.0;
  parameter Real Kp_yaw = 18.0;
  parameter Real Kd_yaw = 12.0;

  // ---------- Process noise ----------
  parameter Real q_pos = 1e-6;
  parameter Real q_vel = 1e-4;
  parameter Real q_yaw = 1e-5;
  parameter Real q_bias = 1e-7;
  parameter Real Pfloor = 1e-9 "Covariance diagonal floor";

  // ---------- Plant continuous states ----------
  Real x_t, y_t, z_t, u_t, v_t, w_t, yaw_t, r_t;
  Real b_a_t, b_g_t, b_z_t, b_d_t, b_c_t;

  // Thrusters
  Real T1_cmd, T2_cmd, T3_cmd, T4_cmd;
  Real T1, T2, T3, T4;
  Real Fx_b, Fy_b, Fz_b, Mz_b;
  Real Fx_cmd, Fy_cmd, Fz_cmd, Mz_cmd;

  // Measurements
  Real a_meas, w_meas;
  Real z_meas, du_meas, dv_meas, dw_meas, c_meas;
  Real r1_meas, r2_meas;

  // Reference
  Real x_r, y_r, z_r, yaw_r;
  Real x_rdot, y_rdot, x_rddot, y_rddot;
  Real u_ref, v_ref, a_ref_f, a_ref_l, r_ref;

  // Controller
  Real ex, ey, ez, eyaw, ex_b, ey_b;
  Real u_est_body, v_est_body;

  // EKF discrete
  discrete Real x_est[12];
  discrete Real P[12,12];
  discrete Integer tick;

  // EKF working
  Real F[12,12];
  Real Q[12,12];
  Real Pn[12,12];
  Real Hvec[12];
  Real Kvec[12];
  Real HPvec[12];
  Real S_up, inn_up;

  // Observables
  Real pos_track_err "True position tracking error [m]";
  Real att_track_err "True attitude tracking error [rad]";
  Real track_err "Primary tracking error [m or rad]";
  Real pos_err "Estimator position error vs truth [m]";
  Real att_err "Estimator attitude error vs truth [rad]";
  Real bias_err_a, bias_err_g, bias_err_z, bias_err_d, bias_err_c;
  Real cov_pos "Position covariance trace [m2]";
  Real cov_yaw "Yaw variance [rad2]";
  Real cov_b_a "Accel bias variance [(m/s2)2]";
  Real T1_abs, T2_abs, T3_abs, T4_abs;

initial equation
  x_t = R_route; y_t = 0.0; z_t = z_ref;
  u_t = R_route*w_route; v_t = 0.0; w_t = 0.0;
  yaw_t = 1.5707963267948966; r_t = w_route;

initial algorithm
  for i in 1:12 loop
    for j in 1:12 loop
      P[i,j] := 0.0;
      Pn[i,j] := 0.0;
      F[i,j] := 0.0;
      Q[i,j] := 0.0;
    end for;
    Hvec[i] := 0.0; Kvec[i] := 0.0; HPvec[i] := 0.0;
  end for;
  P[1,1] := 0.25; P[2,2] := 0.25; P[3,3] := 0.25;
  P[4,4] := 0.1; P[5,5] := 0.1; P[6,6] := 0.1;
  P[7,7] := 0.05;
  P[8,8] := 1e-4; P[9,9] := 1e-5; P[10,10] := 1e-4; P[11,11] := 1e-4; P[12,12] := 1e-4;
  x_est[1] := R_route; x_est[2] := 0.0; x_est[3] := z_ref + 0.15;
  x_est[4] := 0.0; x_est[5] := 0.6; x_est[6] := 0.0; x_est[7] := 1.4;
  x_est[8] := 0.0; x_est[9] := 0.0; x_est[10] := 0.0; x_est[11] := 0.0; x_est[12] := 0.0;
  tick := 0;

equation
  // Process noise covariance (constant diagonal)
  for i in 1:12 loop
    for j in 1:12 loop
      if i == j then
        Q[i,j] = if i <= 3 then q_pos elseif i <= 6 then q_vel elseif i == 7 then q_yaw else q_bias;
      else
        Q[i,j] = 0.0;
      end if;
    end for;
  end for;

  // ---------- Route reference (bounded circle) ----------
  x_r = R_route*cos(w_route*time);
  y_r = R_route*sin(w_route*time);
  z_r = z_ref;
  x_rdot = -R_route*w_route*sin(w_route*time);
  y_rdot =  R_route*w_route*cos(w_route*time);
  x_rddot = -R_route*w_route*w_route*cos(w_route*time);
  y_rddot = -R_route*w_route*w_route*sin(w_route*time);
  yaw_r = atan2(y_rdot, x_rdot);
  r_ref = w_route;
  u_ref = x_rdot*cos(yaw_r) + y_rdot*sin(yaw_r);
  v_ref = -x_rdot*sin(yaw_r) + y_rdot*cos(yaw_r);
  a_ref_f = x_rddot*cos(yaw_r) + y_rddot*sin(yaw_r);
  a_ref_l = -x_rddot*sin(yaw_r) + y_rddot*cos(yaw_r);

  // ---------- Plant dynamics ----------
  der(x_t) = u_t*cos(yaw_t) - v_t*sin(yaw_t);
  der(y_t) = u_t*sin(yaw_t) + v_t*cos(yaw_t);
  der(z_t) = w_t;
  der(u_t) = (Fx_b - Xu*u_t)/m;
  der(v_t) = (Fy_b - Yv*v_t)/m;
  der(w_t) = (Fz_b - Zw*w_t)/m;
  der(yaw_t) = r_t;
  der(r_t) = (Mz_b - Nr*r_t)/Iz;

  // ---------- True sensor biases (with 0.04 step in middle third) ----------
  b_a_t = 0.01 + (if time >= t_a and time < t_b then dbias else 0.0);
  b_g_t = 0.002 + (if time >= t_a and time < t_b then 0.04*0.1 else 0.0);
  b_z_t = 0.02 + (if time >= t_a and time < t_b then dbias else 0.0);
  b_d_t = 0.01 + (if time >= t_a and time < t_b then dbias else 0.0);
  b_c_t = 0.01 + (if time >= t_a and time < t_b then 0.04*0.5 else 0.0);

  // ---------- Thruster allocation + saturation ----------
  T1_cmd = (Fx_cmd + Mz_cmd/Lt)/2;
  T2_cmd = (Fx_cmd - Mz_cmd/Lt)/2;
  T3_cmd = (Fz_cmd + Fy_cmd)/2;
  T4_cmd = (Fz_cmd - Fy_cmd)/2;
  T1 = sat(T1_cmd, Fmax);
  T2 = sat(T2_cmd, Fmax);
  T3 = sat(T3_cmd, Fmax);
  T4 = sat(T4_cmd, Fmax);
  Fx_b = T1 + T2;
  Fy_b = T3 - T4;
  Fz_b = T3 + T4;
  Mz_b = (T1 - T2)*Lt;
  T1_abs = abs(T1); T2_abs = abs(T2); T3_abs = abs(T3); T4_abs = abs(T4);

  // ---------- Controller (uses estimates; no ground truth) ----------
  ex = x_r - x_est[1];
  ey = y_r - x_est[2];
  ez = z_r - x_est[3];
  eyaw = wrap(yaw_r - x_est[7]);
  ex_b = ex*cos(x_est[7]) + ey*sin(x_est[7]);
  ey_b = -ex*sin(x_est[7]) + ey*cos(x_est[7]);
  u_est_body = x_est[4]*cos(x_est[7]) + x_est[5]*sin(x_est[7]);
  v_est_body = -x_est[4]*sin(x_est[7]) + x_est[5]*cos(x_est[7]);
  Fx_cmd = m*a_ref_f + Xu*u_ref + Kp_pos*ex_b - Kd_pos*(u_est_body - u_ref);
  Fy_cmd = m*a_ref_l + Yv*v_ref + Kp_pos*ey_b - Kd_pos*(v_est_body - v_ref);
  Fz_cmd = Kp_dep*ez - Kd_dep*x_est[6];
  Mz_cmd = Nr*r_ref + Kp_yaw*eyaw - Kd_yaw*((w_meas - x_est[9]) - r_ref);

  // ---------- Sensor measurements (truth + bias + bounded pseudo-noise) ----------
  a_meas = (Fx_b - Xu*u_t)/m + b_a_t + sigma_a*sin(13.0*time);
  w_meas = r_t + b_g_t + sigma_g*sin(17.0*time);
  z_meas = z_t + b_z_t + sigma_z*sin(11.0*time);
  du_meas = u_t + b_d_t + sigma_d*sin(19.0*time);
  dv_meas = v_t + sigma_d*cos(23.0*time);
  dw_meas = w_t + sigma_d*sin(29.0*time);
  c_meas = yaw_t + b_c_t + sigma_c*sin(9.0*time);
  r1_meas = rangeTo(x_t,y_t,z_t,L1x,L1y,L1z) + sigma_r*sin(5.0*time);
  r2_meas = rangeTo(x_t,y_t,z_t,L2x,L2y,L2z) + sigma_r*cos(5.0*time + 1.0);

  // ---------- Observables ----------
  pos_track_err = sqrt((x_r - x_t)^2 + (y_r - y_t)^2 + (z_r - z_t)^2);
  att_track_err = abs(wrap(yaw_r - yaw_t));
  track_err = max(pos_track_err, att_track_err);
  pos_err = sqrt((x_est[1]-x_t)^2 + (x_est[2]-y_t)^2 + (x_est[3]-z_t)^2);
  att_err = abs(wrap(x_est[7] - yaw_t));
  bias_err_a = x_est[8] - b_a_t;
  bias_err_g = x_est[9] - b_g_t;
  bias_err_z = x_est[10] - b_z_t;
  bias_err_d = x_est[11] - b_d_t;
  bias_err_c = x_est[12] - b_c_t;
  cov_pos = P[1,1] + P[2,2] + P[3,3];
  cov_yaw = P[7,7];
  cov_b_a = P[8,8];

algorithm
  when sample(0, dt) then
    // ----- Tick counter for asynchronous scheduling -----
    tick := pre(tick) + 1;

    // ----- State prediction (IMU-driven, 200 Hz) -----
    x_est[1] := pre(x_est[1]) + pre(x_est[4])*dt;
    x_est[2] := pre(x_est[2]) + pre(x_est[5])*dt;
    x_est[3] := pre(x_est[3]) + pre(x_est[6])*dt;
    x_est[4] := pre(x_est[4]) + (a_meas - pre(x_est[8]))*cos(pre(x_est[7]))*dt;
    x_est[5] := pre(x_est[5]) + (a_meas - pre(x_est[8]))*sin(pre(x_est[7]))*dt;
    x_est[6] := pre(x_est[6]);
    x_est[7] := wrap(pre(x_est[7]) + (w_meas - pre(x_est[9]))*dt);
    x_est[8] := pre(x_est[8]);
    x_est[9] := pre(x_est[9]);
    x_est[10] := pre(x_est[10]);
    x_est[11] := pre(x_est[11]);
    x_est[12] := pre(x_est[12]);

    // ----- Build Jacobian F = I + dt*A -----
    for i in 1:12 loop
      for j in 1:12 loop
        F[i,j] := 0.0;
      end for;
      F[i,i] := 1.0;
    end for;
    F[1,4] := dt;
    F[2,5] := dt;
    F[3,6] := dt;
    F[4,7] := -dt*(a_meas - pre(x_est[8]))*sin(pre(x_est[7]));
    F[4,8] := -dt*cos(pre(x_est[7]));
    F[5,7] := dt*(a_meas - pre(x_est[8]))*cos(pre(x_est[7]));
    F[5,8] := -dt*sin(pre(x_est[7]));
    F[7,9] := -dt;

    // ----- Covariance prediction: P = F*pre(P)*F' + Q -----
    for i in 1:12 loop
      for j in 1:12 loop
        Pn[i,j] := 0.0;
        for k in 1:12 loop
          Pn[i,j] := Pn[i,j] + F[i,k]*pre(P[k,j]);
        end for;
      end for;
    end for;
    for i in 1:12 loop
      for j in 1:12 loop
        P[i,j] := 0.0;
        for k in 1:12 loop
          P[i,j] := P[i,j] + Pn[i,k]*F[j,k];
        end for;
        P[i,j] := P[i,j] + Q[i,j];
      end for;
    end for;

    // ----- Depth update (50 Hz) -----
    if mod(tick, 4) == 0 then
      for k in 1:12 loop Hvec[k] := 0.0; end for;
      Hvec[3] := 1.0; Hvec[10] := 1.0;
      inn_up := z_meas - x_est[3];
      (x_est, P) := ekfUpdate(x_est, P, Hvec, inn_up, sigma_z^2);
    end if;

    // ----- Compass update (10 Hz) -----
    if mod(tick, 20) == 0 then
      for k in 1:12 loop Hvec[k] := 0.0; end for;
      Hvec[7] := 1.0; Hvec[12] := 1.0;
      inn_up := wrap(c_meas - x_est[7]);
      (x_est, P) := ekfUpdate(x_est, P, Hvec, inn_up, sigma_c^2);
    end if;

    // ----- Doppler update (5 Hz, forward-body velocity) -----
    if mod(tick, 40) == 0 then
      for k in 1:12 loop Hvec[k] := 0.0; end for;
      Hvec[4] := cos(x_est[7]);
      Hvec[5] := sin(x_est[7]);
      Hvec[7] := -x_est[4]*sin(x_est[7]) + x_est[5]*cos(x_est[7]);
      Hvec[11] := 1.0;
      inn_up := du_meas - (x_est[4]*cos(x_est[7]) + x_est[5]*sin(x_est[7]) + x_est[11]);
      (x_est, P) := ekfUpdate(x_est, P, Hvec, inn_up, sigma_d^2);
    end if;

    // ----- Acoustic range updates (1 Hz) -----
    if mod(tick, 200) == 0 then
      // Beacon 1
      for k in 1:12 loop Hvec[k] := 0.0; end for;
      S_up := rangeTo(x_est[1], x_est[2], x_est[3], L1x, L1y, L1z);
      Hvec[1] := (x_est[1] - L1x)/S_up;
      Hvec[2] := (x_est[2] - L1y)/S_up;
      Hvec[3] := (x_est[3] - L1z)/S_up;
      inn_up := r1_meas - S_up;
      (x_est, P) := ekfUpdate(x_est, P, Hvec, inn_up, sigma_r^2);
      // Beacon 2
      for k in 1:12 loop Hvec[k] := 0.0; end for;
      S_up := rangeTo(x_est[1], x_est[2], x_est[3], L2x, L2y, L2z);
      Hvec[1] := (x_est[1] - L2x)/S_up;
      Hvec[2] := (x_est[2] - L2y)/S_up;
      Hvec[3] := (x_est[3] - L2z)/S_up;
      inn_up := r2_meas - S_up;
      (x_est, P) := ekfUpdate(x_est, P, Hvec, inn_up, sigma_r^2);
    end if;

    // ----- Symmetrize and floor covariance -----
    for i in 1:12 loop
      for j in 1:12 loop
        Pn[i,j] := P[i,j];
      end for;
    end for;
    for i in 1:12 loop
      for j in 1:12 loop
        P[i,j] := 0.5*(Pn[i,j] + Pn[j,i]);
      end for;
    end for;
    for i in 1:12 loop
      P[i,i] := max(P[i,i], Pfloor);
    end for;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "MarineNavLocalizeD: 200 Hz EKF-based underwater vehicle localization with IMU, pressure depth, Doppler velocity, compass, and 1 Hz acoustic range sensors. Four thrusters bounded to 105 N each. A 0.04 bias step disturbance is applied during the middle third [4.667 s, 9.333 s]. Fixed landmarks provide external references; the estimator receives no ground truth."));
end MarineNavLocalizeD;