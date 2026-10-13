model MapRigMapB
  extends Modelica.Icons.Example;
  import Modelica.Constants.pi;

  // ===== Physical parameters =====
  parameter Real m_base = 22.0      "Mobile base mass [kg]";
  parameter Real r_w    = 0.10       "Wheel radius [m]";
  parameter Real L_w    = 0.40       "Wheelbase [m]";
  parameter Real I_z    = m_base*(L_w^2)/12.0  "Yaw inertia [kg.m2]";
  parameter Real b_lin  = 2.0        "Translational damping [N.s/m]";
  parameter Real b_ang  = 0.5        "Yaw damping [N.m.s/rad]";
  parameter Real tau_max = 9.84      "Max wheel torque per wheel [N.m]";

  // ===== Mission parameters =====
  parameter Real R_route = 2.0       "Closed route radius [m]";
  parameter Real T_sim   = 10.0      "Mission duration [s]";
  parameter Real f_loop  = 100.0     "Declared control/output rate [Hz]";

  // ===== Sensor rates (explicitly different) =====
  parameter Real f_odom  = 100.0     "Wheel encoder rate [Hz]";
  parameter Real f_imu   = 200.0     "IMU rate [Hz]";
  parameter Real f_lidar = 50.0      "Planar lidar rate [Hz]";
  parameter Real f_cam   = 30.0      "RGB-D camera rate [Hz]";
  parameter Real f_sonar = 10.0      "Sonar rate [Hz]";
  parameter Real lidar_range = 20.0  "Planar lidar max range [m]";

  // ===== Sensor extrinsic transforms (m, body frame) =====
  parameter Real tf_lidar_x = 0.10  "Lidar forward offset [m]";
  parameter Real tf_lidar_y = 0.0   "Lidar lateral offset [m]";
  parameter Real tf_cam_x   = 0.15  "Camera forward offset [m]";
  parameter Real tf_cam_y   = 0.0   "Camera lateral offset [m]";
  parameter Real tf_imu_x   = 0.0   "IMU forward offset [m]";
  parameter Real tf_imu_y   = 0.0   "IMU lateral offset [m]";
  parameter Real tf_enc_x   = -0.10 "Encoder/wheel offset [m]";
  parameter Real tf_enc_y   = 0.0   "Encoder lateral offset [m]";

  // ===== Landmarks (6) in shared world frame =====
  parameter Real lx[6] = {1.0, 3.0, 3.0, 1.0, -1.0, 5.0}  "Landmark x [m]";
  parameter Real ly[6] = {0.0, 1.0, -1.0, 3.0, 2.0, 0.0}   "Landmark y [m]";

  // ===== Obstacles (2) in shared world frame =====
  parameter Real ox[2]   = {-2.0, 4.0}  "Obstacle x [m]";
  parameter Real oy[2]   = {-2.0, 3.0}  "Obstacle y [m]";
  parameter Real or_[2]  = {0.5, 0.5}   "Obstacle radius [m]";

  // ===== Disturbance =====
  parameter Real dpert = 0.14          "Landmark perturbation magnitude [m]";

  // ===== Controller gains =====
  parameter Real Kp_v = 4.0   "Pose position feedforward gain";
  parameter Real Kp_w = 3.0   "Pose heading gain";
  parameter Real Kf   = 20.0  "Velocity force gain";
  parameter Real Kw   = 5.0   "Yaw moment gain";

  // ===== Estimator gains =====
  parameter Real K_obs    = 1.5  "Range update gain";
  parameter Real K_lc     = 0.5  "Loop-closure correction gain";
  parameter Real Q_x      = 0.002  "Process noise x";
  parameter Real Q_y      = 0.002  "Process noise y";
  parameter Real Q_th     = 0.0005 "Process noise theta";
  parameter Real P_decay  = 0.5    "Covariance decay rate";
  parameter Real odom_bias = 0.01  "Odometry multiplicative bias";
  parameter Real imu_bias  = 0.005  "IMU multiplicative bias";

  // ===== Robot states (true pose) =====
  Real x(start=2.0, fixed=true)            "Base x [m]";
  Real y(start=0.0, fixed=true)            "Base y [m]";
  Real theta(start=pi/2, fixed=true)        "Base heading [rad]";
  Real v(start=R_route*2*pi/T_sim, fixed=true) "Body forward velocity [m/s]";
  Real w(start=2*pi/T_sim, fixed=true)      "Yaw rate [rad/s]";

  // ===== Wheel commands =====
  Real tau_L      "Unsaturated left wheel torque [N.m]";
  Real tau_R      "Unsaturated right wheel torque [N.m]";
  Real tau_L_sat  "Saturated left wheel torque [N.m]";
  Real tau_R_sat  "Saturated right wheel torque [N.m]";
  Real F_drive    "Commanded drive force [N]";
  Real M_drive    "Commanded yaw moment [N.m]";

  // ===== Reference closed route =====
  Real x_ref, y_ref, theta_ref, v_ref, w_ref;
  Real ex, ey, eth, ex_b, ey_b;
  Real v_cmd, w_cmd;

  // ===== Fused sensors (odometry + IMU, continuous) =====
  Real v_odom "Wheel-encoder velocity [m/s]";
  Real w_imu  "IMU yaw rate [rad/s]";

  // ===== Preserved (non-fused) exteroceptive traces =====
  Real cam_depth(start=5.0)  "RGB-D depth [m]";
  Real sonar_range(start=3.0) "Sonar range [m]";
  Real cam_frame(start=0.0)   "Camera frame stamp [s]";
  Real sonar_echo(start=0.0)  "Sonar echo stamp [s]";

  // ===== Sensor positions in world frame =====
  Real lidar_x, lidar_y       "Lidar sensor world position [m]";
  Real lidar_x_hat, lidar_y_hat "Lidar estimator world position [m]";

  // ===== Estimator states =====
  Real x_hat(start=2.0, fixed=true)    "Estimated x [m]";
  Real y_hat(start=0.0, fixed=true)    "Estimated y [m]";
  Real theta_hat(start=pi/2, fixed=true) "Estimated heading [rad]";
  Real P_x(start=0.01, fixed=true)     "Covariance x [m2]";
  Real P_y(start=0.01, fixed=true)      "Covariance y [m2]";
  Real P_th(start=0.001, fixed=true)   "Covariance theta [rad2]";
  Real corr_x, corr_y    "Range correction to estimate";
  Real corr_x_lc, corr_y_lc, corr_th_lc "Loop-closure corrections";

  // ===== Perturbed landmark positions =====
  Real lx_p[6], ly_p[6];
  Boolean perturb_active "Middle-third landmark perturbation";
  Boolean lc_active      "Loop-closure window active";

  // ===== Loop-closure errors =====
  Real lc_pos_err     "Loop-closure position error [m]";
  Real lc_heading_err "Loop-closure heading error [rad]";

  // ===== Performance / safety metrics =====
  Real track_err     "Primary tracking error [m]";
  Real min_obs_dist  "Minimum obstacle clearance [m]";
  Real cov_max       "Max estimator covariance";

  // ===== Declared outputs =====
  output Real o_track_err   = track_err;
  output Real o_x           = x;
  output Real o_y           = y;
  output Real o_theta       = theta;
  output Real o_x_hat       = x_hat;
  output Real o_y_hat       = y_hat;
  output Real o_theta_hat   = theta_hat;
  output Real o_cov_max     = cov_max;
  output Real o_lc_pos_err  = lc_pos_err;
  output Real o_lc_head_err = lc_heading_err;
  output Real o_out_rate    = f_loop;
  output Real o_tau_L       = tau_L_sat;
  output Real o_tau_R       = tau_R_sat;
  output Real o_cam_depth   = cam_depth;
  output Real o_sonar_range = sonar_range;

protected
  Real d1, d2;
  Real r_meas_i, r_exp_i, denom_i;

equation
  // ===== Reference closed route (circle traversed once in T_sim) =====
  x_ref     = R_route*cos(2*pi*time/T_sim);
  y_ref     = R_route*sin(2*pi*time/T_sim);
  theta_ref = 2*pi*time/T_sim + pi/2;
  v_ref     = R_route*2*pi/T_sim;
  w_ref     = 2*pi/T_sim;

  // ===== Tracking and safety metrics =====
  track_err    = sqrt((x - x_ref)^2 + (y - y_ref)^2);
  d1           = sqrt((x - ox[1])^2 + (y - oy[1])^2) - or_[1];
  d2           = sqrt((x - ox[2])^2 + (y - oy[2])^2) - or_[2];
  min_obs_dist = min(d1, d2);

  // ===== Middle-third landmark perturbation disturbance =====
  perturb_active = (time > T_sim/3.0) and (time < 2.0*T_sim/3.0);
  for i in 1:6 loop
    lx_p[i] = lx[i] + (if perturb_active then dpert else 0.0);
    ly_p[i] = ly[i];
  end for;

  // ===== Odometry + IMU (biased, fused into estimator) =====
  v_odom = v*(1.0 + odom_bias);
  w_imu  = w*(1.0 + imu_bias);

  // ===== Sensor world positions (extrinsic transforms applied) =====
  lidar_x     = x     + tf_lidar_x*cos(theta)     - tf_lidar_y*sin(theta);
  lidar_y     = y     + tf_lidar_x*sin(theta)     + tf_lidar_y*cos(theta);
  lidar_x_hat = x_hat + tf_lidar_x*cos(theta_hat) - tf_lidar_y*sin(theta_hat);
  lidar_y_hat = y_hat + tf_lidar_x*sin(theta_hat) + tf_lidar_y*cos(theta_hat);

  // ===== Controller: pose filtering on estimated pose =====
  ex   = x_ref - x_hat;
  ey   = y_ref - y_hat;
  eth  = theta_ref - theta_hat;
  ex_b = cos(theta)*ex + sin(theta)*ey;
  ey_b = -sin(theta)*ex + cos(theta)*ey;
  v_cmd = v_ref + Kp_v*ex_b;
  w_cmd = w_ref + Kp_w*eth;

  // ===== Bounded wheel drives (9.84 N.m per wheel) =====
  F_drive   = Kf*(v_cmd - v);
  M_drive   = Kw*(w_cmd - w);
  tau_L     = r_w/2.0*(F_drive - 2.0*M_drive/L_w);
  tau_R     = r_w/2.0*(F_drive + 2.0*M_drive/L_w);
  tau_L_sat = max(-tau_max, min(tau_max, tau_L));
  tau_R_sat = max(-tau_max, min(tau_max, tau_R));

  // ===== Robot dynamics =====
  der(v)     = ((tau_L_sat + tau_R_sat)/r_w - b_lin*v)/m_base;
  der(w)     = ((tau_R_sat - tau_L_sat)/r_w*(L_w/2.0) - b_ang*w)/I_z;
  der(x)     = v*cos(theta);
  der(y)     = v*sin(theta);
  der(theta) = w;

  // ===== Range-based correction (fuse planar lidar over all in-range landmarks) =====
  corr_x = K_obs * (sum(
      (if sqrt((lidar_x_hat - lx_p[i])^2 + (lidar_y_hat - ly_p[i])^2) < lidar_range
       then (sqrt((lidar_x - lx_p[i])^2 + (lidar_y - ly_p[i])^2)
             - sqrt((lidar_x_hat - lx_p[i])^2 + (lidar_y_hat - ly_p[i])^2))
            * (lidar_x_hat - lx_p[i])
            / max(sqrt((lidar_x_hat - lx_p[i])^2 + (lidar_y_hat - ly_p[i])^2), 0.01)
       else 0.0)
      for i in 1:6)) / 6.0;
  corr_y = K_obs * (sum(
      (if sqrt((lidar_x_hat - lx_p[i])^2 + (lidar_y_hat - ly_p[i])^2) < lidar_range
       then (sqrt((lidar_x - lx_p[i])^2 + (lidar_y - ly_p[i])^2)
             - sqrt((lidar_x_hat - lx_p[i])^2 + (lidar_y_hat - ly_p[i])^2))
            * (lidar_y_hat - ly_p[i])
            / max(sqrt((lidar_x_hat - lx_p[i])^2 + (lidar_y_hat - ly_p[i])^2), 0.01)
       else 0.0)
      for i in 1:6)) / 6.0;

  // ===== Loop-closure correction (last 10% of mission) =====
  lc_active   = time > 0.9*T_sim;
  corr_x_lc   = if lc_active then K_lc*(2.0 - x_hat) else 0.0;
  corr_y_lc   = if lc_active then K_lc*(0.0 - y_hat) else 0.0;
  corr_th_lc  = if lc_active then K_lc*((pi/2 + 2.0*pi) - theta_hat) else 0.0;

  // ===== Estimator (pose filter) dynamics =====
  der(x_hat)     = v_odom*cos(theta_hat) + corr_x + corr_x_lc;
  der(y_hat)     = v_odom*sin(theta_hat) + corr_y + corr_y_lc;
  der(theta_hat) = w_imu + corr_th_lc;

  // ===== Finite covariance propagation =====
  der(P_x)  = Q_x  - P_decay*P_x  - (if lc_active then K_lc*P_x  else 0.0);
  der(P_y)  = Q_y  - P_decay*P_y  - (if lc_active then K_lc*P_y  else 0.0);
  der(P_th) = Q_th - P_decay*P_th - (if lc_active then K_lc*P_th else 0.0);
  cov_max   = max(P_x, max(P_y, P_th));

  // ===== Loop-closure position and heading error =====
  lc_pos_err     = sqrt((x_hat - 2.0)^2 + (y_hat - 0.0)^2);
  lc_heading_err = theta_hat - (pi/2 + 2.0*pi);

  // ===== Preserved camera and sonar traces (discrete, separate from fusion) =====
  when sample(0, 1.0/f_cam) then
    cam_frame = time;
    cam_depth = 5.0;
  end when;
  when sample(0, 1.0/f_sonar) then
    sonar_echo  = time;
    sonar_range = 3.0;
  end when;

end MapRigMapB;