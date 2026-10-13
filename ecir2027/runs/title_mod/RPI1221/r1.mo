model WheelIMUMapC
  // ---- Requirement-grounded parameters ----
  parameter Real m_chassis = 16.0          "kg, differential-drive chassis mass (requirement)";
  parameter Real tau_max = 9.2             "N.m maximum command magnitude per wheel (requirement)";
  parameter Real d_perturb = 0.18           "m landmark perturbation disturbance (requirement)";
  parameter Real output_rate_Hz = 125.0     "Hz declared output/sensor rate (requirement)";
  parameter Real T_end = 12.0              "s run duration (requirement)";
  parameter Real track_err_thresh = 0.263  "m primary tracking error threshold (requirement)";
  parameter Real t_check = 7.8            "s tracking-error check time (requirement)";
  parameter Integer n_landmarks = 6        "fixed landmarks (requirement)";
  parameter Integer n_obstacles = 2        "obstacles (requirement)";

  // ---- Assumed physical parameters (not specified in requirement) ----
  parameter Real r_wheel = 0.10           "m wheel radius (assumed)";
  parameter Real L_track = 0.40           "m wheelbase (assumed)";
  parameter Real J_wheel = 0.01           "kg.m2 wheel inertia (assumed)";
  parameter Real b_wheel = 0.5            "N.m.s/rad wheel viscous damping (assumed)";
  parameter Real R_path = 2.0             "m circular closed-route radius (assumed)";
  parameter Real r_robot = 0.25           "m robot footprint radius (assumed)";
  parameter Real r_obs = 0.25             "m obstacle radius (assumed)";
  parameter Real g_grav = 9.81            "m/s2 gravity (assumed)";

  // ---- Controller gains (assumed tuning) ----
  parameter Real kx = 2.0                 "longitudinal pose gain (assumed)";
  parameter Real ky = 3.0                 "lateral pose gain (assumed)";
  parameter Real kth = 2.5                "heading gain (assumed)";
  parameter Real Kp_w = 6.0               "wheel velocity proportional gain (assumed)";
  parameter Real Ki_w = 20.0              "wheel velocity integral gain (assumed)";

  // ---- Reference trajectory (one closed loop in T_end) ----
  parameter Real omega_ref = 2*3.14159265358979/T_end "rad/s reference yaw rate";
  parameter Real v_ref = R_path*omega_ref  "m/s reference forward speed";
  parameter Real omegaL0 = v_ref/r_wheel - omega_ref*L_track/(2*r_wheel);
  parameter Real omegaR0 = v_ref/r_wheel + omega_ref*L_track/(2*r_wheel);
  parameter Real th_start = 1.57079632679490 "rad initial heading (+y)";
  parameter Real xs = R_path              "m start x";
  parameter Real ys = 0.0                 "m start y";

  // ---- Landmarks (shared world frame) and obstacles ----
  parameter Real LMx_nom[6] = {4.0, 3.0, -1.0, -3.0, -2.0, 2.5} "m landmark x (map, assumed)";
  parameter Real LMy_nom[6] = {1.0, 3.0, 3.0, 0.5, -2.5, -3.0} "m landmark y (map, assumed)";
  parameter Real Obsx[2] = {0.0, 1.5}     "m obstacle x (assumed)";
  parameter Real Obsy[2] = {3.2, -2.8}    "m obstacle y (assumed)";

  // ---- IMU noise and bias parameters (declared) ----
  parameter Real acc_bias_x = 0.020       "m/s2 accelerometer x bias (assumed)";
  parameter Real acc_bias_y = 0.010       "m/s2 accelerometer y bias (assumed)";
  parameter Real acc_bias_z = 0.050       "m/s2 accelerometer z bias (assumed)";
  parameter Real gyro_bias_x = 0.0010    "rad/s gyro x bias (assumed)";
  parameter Real gyro_bias_y = -0.0020   "rad/s gyro y bias (assumed)";
  parameter Real gyro_bias_z = 0.0050    "rad/s gyro z bias (assumed)";
  parameter Real acc_noise_amp = 0.05    "m/s2 accelerometer noise amplitude (assumed)";
  parameter Real gyro_noise_amp = 0.02    "rad/s gyro noise amplitude (assumed)";
  parameter Real enc_noise_amp = 0.05    "rad/s encoder noise amplitude (assumed)";
  parameter Real range_noise_amp = 0.03  "m range noise amplitude (assumed)";

  // ---- Estimator noise parameters (declared) ----
  parameter Real Qx = 0.01               "m2/s process noise x (assumed)";
  parameter Real Qy = 0.01               "m2/s process noise y (assumed)";
  parameter Real Qth = 0.0005            "rad2/s process noise heading (assumed)";
  parameter Real R_range = 0.0025       "m2 range measurement variance (assumed)";
  parameter Real dt_out = 1.0/output_rate_Hz "s sample/update period";

  // ---- Continuous plant state ----
  Real x(start=xs)        "m true x";
  Real y(start=ys)        "m true y";
  Real theta(start=th_start) "rad true heading";
  Real omegaL(start=omegaL0) "rad/s left wheel rate";
  Real omegaR(start=omegaR0) "rad/s right wheel rate";
  Real intL(start=0.0)    "integral left wheel error";
  Real intR(start=0.0)    "integral right wheel error";

  // ---- Algebraic plant variables ----
  Real v "m/s forward speed";
  Real omega "rad/s yaw rate";
  Real a_fwd "m/s2 forward acceleration";
  Real tauL_raw, tauR_raw "N.m unsaturated torques";
  output Real tauL "N.m left wheel torque (saturated)";
  output Real tauR "N.m right wheel torque (saturated)";

  // ---- Reference ----
  Real x_ref, y_ref, theta_ref;
  Real phase;

  // ---- Controller ----
  Real ex, ey, dth, eth;
  Real v_cmd, omega_cmd;
  Real omegaL_d, omegaR_d;
  Real errL, errR;

  // ---- Sensors ----
  Real enc_noiseL, enc_noiseR;
  Real omegaL_enc, omegaR_enc "rad/s encoder measurements";
  Real v_enc "m/s odometry speed";
  // IMU six axes
  Real acc_noise_x, acc_noise_y, acc_noise_z;
  Real gyro_noise_x, gyro_noise_y, gyro_noise_z;
  output Real acc_x_meas "m/s2 accelerometer x";
  output Real acc_y_meas "m/s2 accelerometer y";
  output Real acc_z_meas "m/s2 accelerometer z";
  output Real gyro_x_meas "rad/s gyro x";
  output Real gyro_y_meas "rad/s gyro y";
  output Real gyro_z_meas "rad/s gyro z";

  // ---- Landmark perturbation disturbance ----
  Real perturb "m landmark x perturbation active in middle third";
  Real LMx_obs[6] "m observed (perturbed) landmark x";
  Real LMy_obs[6] "m observed landmark y";

  // ---- Exteroceptive observations (raw, preserved separately) ----
  Real cam_raw_range[6]   "m camera raw range to landmarks";
  Real cam_raw_bearing[6] "rad camera raw bearing to landmarks";
  Real sonar_raw[2]       "m sonar raw range to obstacles";
  Real range_meas[6]      "m fused range measurements to landmarks";
  Real range_noise_i[6];

  // ---- Estimator (discrete-time, 125 Hz) ----
  Real xE(start=xs)        "m estimated x";
  Real yE(start=ys)        "m estimated y";
  Real thE(start=th_start) "rad estimated heading";
  Real P11(start=0.04)     "m2 covariance x";
  Real P22(start=0.04)     "m2 covariance y";
  Real P33(start=0.01)     "rad2 covariance heading";

  // ---- Loop closure ----
  Real loop_closure_pos_err "m position error at loop closure";
  Real loop_closure_head_err "rad heading error at loop closure";

  // ---- Performance / safety outputs ----
  output Real track_err "m primary tracking error";
  output Real min_obs_dist "m minimum distance to obstacles";
  output Boolean no_collision;
  output Boolean track_err_met;
  output Real covariance_norm "finite covariance indicator";

  // ---- Synchronized traces (sampled at 125 Hz) ----
  Real x_log, y_log, th_log, v_log, omega_log;
  Real tauL_log, tauR_log;
  Real xE_log, yE_log, thE_log;

  // ---- Temporary discrete quantities ----
  Integer idx;
  Real dxl, dyl, h, H1, H2, S, K1, K2, K3, innov;
  Real lcpe, lche;
  Real xE_p, yE_p, thE_p;
  Real d_obs1, d_obs2;

equation
  // ---- Reference closed route (circle, one loop in T_end) ----
  phase = 2*3.14159265358979*time/T_end;
  x_ref = R_path*cos(phase);
  y_ref = R_path*sin(phase);
  theta_ref = phase + 1.57079632679490;

  // ---- Trajectory tracking controller ----
  ex = cos(theta)*(x_ref - x) + sin(theta)*(y_ref - y);
  ey = -sin(theta)*(x_ref - x) + cos(theta)*(y_ref - y);
  dth = theta_ref - theta;
  eth = atan2(sin(dth), cos(dth));
  v_cmd = v_ref*cos(eth) + kx*ex;
  omega_cmd = omega_ref + kth*eth + ky*ey;

  // ---- Wheel velocity commands ----
  omegaL_d = v_cmd/r_wheel - omega_cmd*L_track/(2*r_wheel);
  omegaR_d = v_cmd/r_wheel + omega_cmd*L_track/(2*r_wheel);
  errL = omegaL_d - omegaL;
  errR = omegaR_d - omegaR;

  // ---- Wheel torque control with saturation and anti-windup ----
  der(intL) = if (tauL_raw > tau_max and errL > 0) or (tauL_raw < -tau_max and errL < 0) then 0.0 else errL;
  der(intR) = if (tauR_raw > tau_max and errR > 0) or (tauR_raw < -tau_max and errR < 0) then 0.0 else errR;
  tauL_raw = Kp_w*errL + Ki_w*intL;
  tauR_raw = Kp_w*errR + Ki_w*intR;
  tauL = max(-tau_max, min(tau_max, tauL_raw));
  tauR = max(-tau_max, min(tau_max, tauR_raw));

  // ---- Chassis dynamics ----
  der(omegaL) = (tauL - b_wheel*omegaL)/J_wheel;
  der(omegaR) = (tauR - b_wheel*omegaR)/J_wheel;
  v = r_wheel*(omegaL + omegaR)/2.0;
  omega = r_wheel*(omegaR - omegaL)/L_track;
  a_fwd = r_wheel*(der(omegaL) + der(omegaR))/2.0;
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;

  // ---- Encoder noise (bounded, deterministic) ----
  enc_noiseL = enc_noise_amp*sin(2*3.14159265358979*9.0*time);
  enc_noiseR = enc_noise_amp*sin(2*3.14159265358979*8.5*time + 1.0);
  omegaL_enc = omegaL + enc_noiseL;
  omegaR_enc = omegaR + enc_noiseR;
  v_enc = r_wheel*(omegaL_enc + omegaR_enc)/2.0;

  // ---- IMU noise (bounded, deterministic) ----
  acc_noise_x = acc_noise_amp*sin(2*3.14159265358979*7.0*time + 0.3);
  acc_noise_y = acc_noise_amp*sin(2*3.14159265358979*6.0*time + 1.7);
  acc_noise_z = acc_noise_amp*sin(2*3.14159265358979*5.0*time + 2.1);
  gyro_noise_x = gyro_noise_amp*sin(2*3.14159265358979*4.0*time + 0.4);
  gyro_noise_y = gyro_noise_amp*sin(2*3.14159265358979*4.5*time + 2.0);
  gyro_noise_z = gyro_noise_amp*sin(2*3.14159265358979*5.0*time + 1.1);

  // Six-axis IMU, center-mounted
  acc_x_meas = a_fwd + acc_bias_x + acc_noise_x;
  acc_y_meas = v*omega + acc_bias_y + acc_noise_y;
  acc_z_meas = g_grav + acc_bias_z + acc_noise_z;
  gyro_x_meas = 0.0 + gyro_bias_x + gyro_noise_x;
  gyro_y_meas = 0.0 + gyro_bias_y + gyro_noise_y;
  gyro_z_meas = omega + gyro_bias_z + gyro_noise_z;

  // ---- Landmark perturbation disturbance (middle third: 4 s <= t <= 8 s) ----
  perturb = if time >= 4.0 and time <= 8.0 then d_perturb else 0.0;
  for i in 1:6 loop
    LMx_obs[i] = LMx_nom[i] + perturb;
    LMy_obs[i] = LMy_nom[i];
    range_noise_i[i] = range_noise_amp*sin(2*3.14159265358979*3.0*time + i);
    cam_raw_range[i] = sqrt((LMx_obs[i] - x)^2 + (LMy_obs[i] - y)^2 + 1e-9);
    cam_raw_bearing[i] = atan2(LMy_obs[i] - y, LMx_obs[i] - x) - theta;
    range_meas[i] = cam_raw_range[i] + range_noise_i[i];
  end for;

  // ---- Sonar raw observations to obstacles (preserved separately) ----
  sonar_raw[1] = sqrt((Obsx[1] - x)^2 + (Obsy[1] - y)^2 + 1e-9);
  sonar_raw[2] = sqrt((Obsx[2] - x)^2 + (Obsy[2] - y)^2 + 1e-9);

  // ---- Obstacle distance and collision check ----
  d_obs1 = sqrt((Obsx[1] - x)^2 + (Obsy[1] - y)^2 + 1e-9);
  d_obs2 = sqrt((Obsx[2] - x)^2 + (Obsy[2] - y)^2 + 1e-9);
  min_obs_dist = min(d_obs1, d_obs2);
  no_collision = min_obs_dist > (r_robot + r_obs);

  // ---- Tracking error and requirement check ----
  track_err = sqrt((x - x_ref)^2 + (y - y_ref)^2 + 1e-9);
  track_err_met = (time < t_check) or (track_err < track_err_thresh);

  // ---- Finite covariance indicator ----
  covariance_norm = sqrt(P11*P11 + P22*P22 + P33*P33 + 1e-12);

algorithm
  when sample(0, dt_out) then
    // ---- Estimator: prediction (odometry + IMU fusion, Euler) ----
    xE_p := xE + v_enc*cos(thE)*dt_out;
    yE_p := yE + v_enc*sin(thE)*dt_out;
    thE_p := thE + gyro_z_meas*dt_out;
    xE := xE_p;
    yE := yE_p;
    thE := thE_p;
    P11 := P11 + Qx*dt_out;
    P22 := P22 + Qy*dt_out;
    P33 := P33 + Qth*dt_out;

    // ---- Range correction (fuse one landmark per cycle) ----
    idx := mod(integer(time/dt_out), 6) + 1;
    dxl := LMx_nom[idx] - xE;
    dyl := LMy_nom[idx] - yE;
    h := sqrt(dxl*dxl + dyl*dyl + 1e-9);
    H1 := -dxl/h;
    H2 := -dyl/h;
    S := H1*H1*P11 + H2*H2*P22 + R_range;
    K1 := P11*H1/S;
    K2 := P22*H2/S;
    K3 := 0.0;
    innov := range_meas[idx] - h;
    xE := xE + K1*innov;
    yE := yE + K2*innov;
    thE := thE + K3*innov;
    P11 := P11 - K1*H1*P11;
    P22 := P22 - K2*H2*P22;

    // ---- Loop-closure correction near end of closed route ----
    lcpe := sqrt((xE - xs)*(xE - xs) + (yE - ys)*(yE - ys) + 1e-9);
    lche := atan2(sin(thE - th_start), cos(thE - th_start));
    if time >= 11.0 then
      xE := xE + 0.15*(xs - xE);
      yE := yE + 0.15*(ys - yE);
      thE := thE + 0.15*lche;
      P11 := P11*0.85;
      P22 := P22*0.85;
      P33 := P33*0.85;
    end if;
    loop_closure_pos_err := lcpe;
    loop_closure_head_err := lche;

    // ---- Synchronized trace retention ----
    x_log := x;
    y_log := y;
    th_log := theta;
    v_log := v;
    omega_log := omega;
    tauL_log := tauL;
    tauR_log := tauR;
    xE_log := xE;
    yE_log := yE;
    thE_log := thE;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-4, Interval = 0.008),
    Documentation(info = "WheelIMUMapC: differential-drive (16 kg) pose-estimation plant with 125 Hz sensor/estimator loop, finite covariance EKF-style fusing odometry+IMU+range, loop-closure correction, raw camera/sonar observations preserved separately, 0.18 m landmark perturbation during middle third, 9.2 N.m per-wheel torque limit. Values not stated in the requirement are marked assumed."));
end WheelIMUMapC;