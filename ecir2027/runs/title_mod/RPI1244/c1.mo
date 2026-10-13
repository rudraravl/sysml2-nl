model MapRigMapB
  import Modelica.Constants.pi;
  import Modelica.Math.wrapAngle;

  // ===== Stated parameters =====
  parameter Real m_base = 22.0 "mobile base mass [kg] (stated)";
  parameter Real L_lidar = 20.0 "planar lidar maximum range [m] (stated)";
  parameter Real tau_wheel_max = 9.84 "allowed wheel command magnitude [N.m] (stated)";
  parameter Real perturb = 0.14 "landmark perturbation disturbance [m] (stated)";

  // ===== Assumed (not stated) geometric/inertial/design parameters =====
  parameter Real r_wheel = 0.10 "wheel radius [m] (assumed)";
  parameter Real track_w = 0.40 "wheel track [m] (assumed)";
  parameter Real I_z = 1.50 "yaw inertia [kg.m2] (assumed)";
  parameter Real R_path = 3.00 "closed-route radius [m] (assumed)";
  parameter Real T_period = 10.0 "loop period [s] (assumed = sim horizon)";
  parameter Real mu_drag = 0.60 "linear drag coefficient [N/(m/s)] (assumed)";
  parameter Real c_yaw = 0.50 "yaw damping [N.m/(rad/s)] (assumed)";
  parameter Real r_base = 0.30 "base collision radius [m] (assumed)";
  parameter Real r_obstacle = 0.50 "obstacle radius [m] (assumed)";

  // ===== Derived limits =====
  parameter Real F_max = 2.0*tau_wheel_max/r_wheel "max total drive force [N]";
  parameter Real M_max = tau_wheel_max*track_w "max yaw moment [N.m]";
  parameter Real w_path = 2.0*pi/T_period "reference angular rate [rad/s]";

  // ===== Rates (explicitly different) =====
  parameter Real T_ctrl = 0.01 "controller/estimator/output rate [s] = 100 Hz (stated)";
  parameter Real T_imu = 0.005 "IMU rate [s] = 200 Hz (assumed, different)";
  parameter Real T_enc = 0.01 "wheel-encoder rate [s] = 100 Hz (assumed, different)";
  parameter Real T_lidar = 0.02 "lidar range rate [s] = 50 Hz (assumed, different)";
  parameter Real T_cam = 0.04 "camera/sonar rate [s] = 25 Hz (assumed, different)";

  // ===== Controller gains (assumed, tuned) =====
  parameter Real Kp_ex = 12.0;
  parameter Real Kd_v = 15.0;
  parameter Real Kp_eth = 8.0;
  parameter Real Kd_w = 6.0;
  parameter Real Ky_ey = 4.0;

  // ===== Estimator noise and fusion gains (assumed finite) =====
  parameter Real q_pos = 1e-4 "process noise pos [m^2/s] (assumed)";
  parameter Real q_th = 1e-4 "process noise heading [rad^2/s] (assumed)";
  parameter Real r_range = 0.01 "range measurement noise [m^2] (assumed)";
  parameter Real k_enc = 0.40 "encoder fusion gain (assumed)";
  parameter Real k_imu = 0.40 "imu fusion gain (assumed)";
  parameter Real k_lc = 0.30 "loop-closure correction gain (assumed)";

  // ===== World: 6 landmarks, 2 obstacles (shared frame) =====
  parameter Real Lx[6] = {4.0, -2.0, -3.0, 2.5, 5.0, -4.0};
  parameter Real Ly[6] = {3.0, 4.0, -2.0, -3.5, 0.0, 1.0};
  parameter Real Ox[2] = {0.0, 5.5};
  parameter Real Oy[2] = {0.0, 5.5};

  // ===== Initial pose (loop start) =====
  parameter Real x0 = R_path;
  parameter Real y0 = 0.0;
  parameter Real th0 = pi/2;

  // ===== Continuous plant states =====
  Real x(start=x0, fixed=true);
  Real y(start=y0, fixed=true);
  Real theta(start=th0, fixed=true);
  Real v(start=R_path*w_path, fixed=true);
  Real w(start=w_path, fixed=true);

  // ===== Reference =====
  Real x_ref, y_ref, theta_ref;
  Real v_ref = R_path*w_path;
  Real w_ref = w_path;

  // ===== Discrete commands =====
  discrete Real F_cmd(start=0.0);
  discrete Real M_cmd(start=0.0);
  discrete Real F_sat(start=0.0);
  discrete Real M_sat(start=0.0);

  // ===== Discrete estimator states =====
  discrete Real xh(start=x0);
  discrete Real yh(start=y0);
  discrete Real th(start=th0);
  discrete Real vh(start=R_path*w_path);
  discrete Real wh(start=w_path);
  discrete Real Pxx(start=1e-3);
  discrete Real Pyy(start=1e-3);
  discrete Real Ptt(start=1e-3);

  // ===== Discrete sensor traces =====
  discrete Real imu_ax(start=0.0);
  discrete Real imu_wz(start=0.0);
  discrete Real enc_v(start=0.0);
  discrete Real enc_w(start=0.0);
  discrete Real lidar_range(start=0.0);
  discrete Real cam_rgb(start=0.0);
  discrete Real sonar(start=0.0);

  // ===== Controller temporaries =====
  discrete Real ex, ey, eth_raw, eth, F_raw, M_raw;

  // ===== Estimator temporaries =====
  discrete Real step_cnt(start=0);
  discrete Real vh_p, wh_p, th_p, xh_p, yh_p, Pxx_p, Pyy_p, Ptt_p;
  discrete Real r_pred, r_meas, innov, Hx, Hy, denom, Kx, Ky;
  discrete Real xh_u, yh_u, Pxx_u, Pyy_u;

  // ===== Loop-closure errors =====
  discrete Real lc_pos_err(start=0.0);
  discrete Real lc_head_err(start=0.0);
  Real lc_pos_plant, lc_head_plant;

  // ===== Disturbance flag and monitoring =====
  Boolean perturb_active;
  Boolean collision;
  Real track_err;

  // ===== Outputs (synchronized state, command, and sensor traces) =====
  output Real o_time = time;
  output Real o_x = x;
  output Real o_y = y;
  output Real o_theta = theta;
  output Real o_v = v;
  output Real o_w = w;
  output Real o_F_cmd = F_cmd;
  output Real o_M_cmd = M_cmd;
  output Real o_F_sat = F_sat;
  output Real o_M_sat = M_sat;
  output Real o_track_err = track_err;
  output Real o_xh = xh;
  output Real o_yh = yh;
  output Real o_th = th;
  output Real o_Pxx = Pxx;
  output Real o_Pyy = Pyy;
  output Real o_Ptt = Ptt;
  output Real o_lc_pos = lc_pos_err;
  output Real o_lc_head = lc_head_err;
  output Real o_lc_pos_plant = lc_pos_plant;
  output Real o_lc_head_plant = lc_head_plant;
  output Real o_imu_ax = imu_ax;
  output Real o_imu_wz = imu_wz;
  output Real o_enc_v = enc_v;
  output Real o_enc_w = enc_w;
  output Real o_lidar_range = lidar_range;
  output Real o_cam_rgb = cam_rgb;
  output Real o_sonar = sonar;
  output Real o_collision = if collision then 1.0 else 0.0;
  output Real o_output_rate = 1.0/T_ctrl "declared output rate [Hz] = 100";

equation
  // ---- Reference closed route (circle, one loop in T_period) ----
  x_ref = R_path*cos(w_path*time);
  y_ref = R_path*sin(w_path*time);
  theta_ref = w_path*time + pi/2;

  // ---- Plant dynamics ----
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = w;
  der(v) = (F_sat - mu_drag*v)/m_base;
  der(w) = (M_sat - c_yaw*w)/I_z;

  // ---- Primary tracking error ----
  track_err = sqrt((x - x_ref)^2 + (y - y_ref)^2);

  // ---- Loop-closure plant errors ----
  lc_pos_plant = sqrt((x - x0)^2 + (y - y0)^2);
  lc_head_plant = wrapAngle(theta - th0);

  // ---- Perturbation active during middle third ----
  perturb_active = (time >= T_period/3.0) and (time <= 2.0*T_period/3.0);

  // ---- Collision check (continuous, no collision expected) ----
  collision = (sqrt((x - Ox[1])^2 + (y - Oy[1])^2) < (r_base + r_obstacle)) or
              (sqrt((x - Ox[2])^2 + (y - Oy[2])^2) < (r_base + r_obstacle));

  // ---- IMU sampling (200 Hz) ----
  when sample(0, T_imu) then
    imu_ax = F_sat/m_base;   // accelerometer longitudinal measurement
    imu_wz = w;              // gyroscope yaw-rate measurement
  end when;

  // ---- Wheel encoder sampling (100 Hz) ----
  when sample(0, T_enc) then
    enc_v = v;
    enc_w = w;
  end when;

  // ---- Lidar range sampling (50 Hz), with perturbation disturbance ----
  when sample(0, T_lidar) then
    lidar_range = sqrt((x - Lx[1])^2 + (y - Ly[1])^2) +
                  (if perturb_active then perturb else 0.0);
  end when;

  // ---- Camera / sonar raw observations (25 Hz), preserved separately ----
  when sample(0, T_cam) then
    cam_rgb = sqrt((x - Ox[1])^2 + (y - Oy[1])^2);  // forward RGB-D depth to obstacle 1
    sonar   = sqrt((x - Ox[2])^2 + (y - Oy[2])^2);  // sonar range to obstacle 2
  end when;

  // ---- Controller + estimator at 100 Hz ----
  when sample(0, T_ctrl) then
    // ---- Pose-filtering controller (body-frame errors) ----
    ex = cos(theta)*(x_ref - x) + sin(theta)*(y_ref - y);
    ey = -sin(theta)*(x_ref - x) + cos(theta)*(y_ref - y);
    eth_raw = theta_ref - theta;
    eth = wrapAngle(eth_raw);
    F_raw = Kp_ex*ex + Kd_v*(v_ref - v) + mu_drag*v_ref;
    M_raw = Kp_eth*eth + Kd_w*(w_ref - w) - Ky_ey*ey + c_yaw*w_ref;
    F_cmd = F_raw;
    M_cmd = M_raw;
    F_sat = if F_raw > F_max then F_max else if F_raw < -F_max then -F_max else F_raw;
    M_sat = if M_raw > M_max then M_max else if M_raw < -M_max then -M_max else M_raw;

    // ---- Estimator propagation (fuse odometry + IMU) ----
    vh_p = (1.0 - k_enc)*pre(vh) + k_enc*pre(enc_v);
    wh_p = (1.0 - k_imu)*pre(wh) + k_imu*pre(imu_wz);
    th_p = pre(th) + wh_p*T_ctrl;
    xh_p = pre(xh) + vh_p*cos(th_p)*T_ctrl;
    yh_p = pre(yh) + vh_p*sin(th_p)*T_ctrl;
    Pxx_p = pre(Pxx) + q_pos*T_ctrl;
    Pyy_p = pre(Pyy) + q_pos*T_ctrl;
    Ptt_p = pre(Ptt) + q_th*T_ctrl;

    // ---- Range update from landmark 1 (50 Hz: every 2nd ctrl step) ----
    r_pred = sqrt((xh_p - Lx[1])^2 + (yh_p - Ly[1])^2 + 1e-9);
    r_meas = sqrt((x - Lx[1])^2 + (y - Ly[1])^2) +
             (if perturb_active then perturb else 0.0);
    innov = r_meas - r_pred;
    Hx = (xh_p - Lx[1])/r_pred;
    Hy = (yh_p - Ly[1])/r_pred;
    denom = Hx*Hx*Pxx_p + Hy*Hy*Pyy_p + r_range + 1e-9;
    Kx = Pxx_p*Hx/denom;
    Ky = Pyy_p*Hy/denom;

    // ---- Apply range update (every 2nd step) ----
    if mod(pre(step_cnt), 2.0) < 0.5 then
      xh_u = xh_p + Kx*innov;
      yh_u = yh_p + Ky*innov;
      Pxx_u = Pxx_p*(1.0 - Kx*Hx);
      Pyy_u = Pyy_p*(1.0 - Ky*Hy);
    else
      xh_u = xh_p;
      yh_u = yh_p;
      Pxx_u = Pxx_p;
      Pyy_u = Pyy_p;
    end if;

    // ---- Loop-closure correction (last 0.2 s of mission) ----
    if time >= T_period - 0.2 then
      xh = xh_u - k_lc*(xh_u - x0);
      yh = yh_u - k_lc*(yh_u - y0);
      th = th_p - k_lc*wrapAngle(th_p - th0);
      Pxx = 0.5*Pxx_u;
      Pyy = 0.5*Pyy_u;
      Ptt = 0.5*Ptt_p;
      lc_pos_err = sqrt((xh_u - x0)^2 + (yh_u - y0)^2);
      lc_head_err = wrapAngle(th_p - th0);
    else
      xh = xh_u;
      yh = yh_u;
      th = th_p;
      Pxx = Pxx_u;
      Pyy = Pyy_u;
      Ptt = Ptt_p;
      lc_pos_err = pre(lc_pos_err);
      lc_head_err = pre(lc_head_err);
    end if;

    vh = vh_p;
    wh = wh_p;
    step_cnt = pre(step_cnt) + 1;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=10.0, Tolerance=1e-6, Interval=0.01),
    Documentation(info="MapRigMapB: robotic sensing/estimation mission traversing a closed route with pose filtering, loop-closure correction, multi-rate sensing, and retained exteroceptive traces."));
end MapRigMapB;