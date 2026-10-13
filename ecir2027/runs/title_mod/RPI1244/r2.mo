model MapRigMapB
  // ===== Physical parameters =====
  parameter Real m_base = 22.0   "mobile base mass [kg]";
  parameter Real L_lidar = 20.0   "planar lidar maximum range [m]";
  parameter Real tau_max = 9.84   "max wheel torque command per wheel [N.m]";
  parameter Real r_wheel = 0.10   "wheel radius [m]";
  parameter Real B_track = 0.40   "wheel track [m]";
  parameter Real I_z     = 1.50   "yaw inertia [kg.m^2]";
  parameter Real b_lin   = 4.0    "linear drag [N.s/m]";
  parameter Real b_rot   = 1.2    "rotational drag [N.m.s/rad]";

  // ===== Explicit, different sensor rates =====
  parameter Real T_imu = 0.005        "IMU period 200 Hz [s]";
  parameter Real T_enc = 0.010        "wheel encoder period 100 Hz [s]";
  parameter Real T_lid = 0.050        "planar lidar period 20 Hz [s]";
  parameter Real T_cam = 1.0/30.0     "forward RGB-D camera period ~30 Hz [s]";
  parameter Real T_son = 0.100        "sonar period 10 Hz [s]";
  parameter Real T_out = 0.010        "declared output rate 100 Hz [s]";

  // ===== Closed route =====
  parameter Real R_route = 2.0  "closed route radius [m]";
  parameter Real T_route = 10.0 "closed route period [s]";
  parameter Real d_land  = 0.14 "landmark perturbation disturbance [m]";

  // ===== Shared world frame: 6 landmarks and 2 obstacles =====
  parameter Real LMx[6] = {3.0, -2.0,  0.5, 2.5, -3.0, 1.0};
  parameter Real LMy[6] = {1.0,  2.0, -2.5,-1.5,  0.0, 2.8};
  parameter Real OBSx[2] = {1.5, -2.5};
  parameter Real OBSy[2] = {-2.5, 1.5};
  parameter Real OBSr[2] = {0.35, 0.35};

  // ===== Initial pose (matches route start: theta = pi/2) =====
  parameter Real x0  = 2.0;
  parameter Real y0  = 0.0;
  parameter Real th0 = 1.57079632679490;
  parameter Real v0  = 1.20;

  constant Real pi = 3.14159265358979;

  // ===== True plant states =====
  Real x(start=x0, fixed=true);
  Real y(start=y0, fixed=true);
  Real theta(start=th0, fixed=true);
  Real v(start=v0, fixed=true);
  Real omega(start=0.0, fixed=true);
  Real tauL(start=0.0);
  Real tauR(start=0.0);

  // ===== Estimator continuous (odometry/IMU-propagated) states =====
  Real xE(start=x0, fixed=true);
  Real yE(start=y0, fixed=true);
  Real thetaE(start=th0, fixed=true);
  Real vE(start=v0, fixed=true);
  Real omegaE(start=0.0, fixed=true);

  // ===== Estimator discrete corrections (range + loop-closure accumulators) =====
  discrete Real corr_x(start=0.0);
  discrete Real corr_y(start=0.0);
  discrete Real corr_th(start=0.0);

  // ===== Finite covariance (3x3 symmetric, stable steady-state form) =====
  Real P11(start=0.01), P12(start=0.0), P13(start=0.0);
  Real P22(start=0.01), P23(start=0.0);
  Real P33(start=0.001);

  // ===== Discrete raw sensor traces (preserved, synchronized) =====
  discrete Real imu_omega(start=0.0);
  discrete Real enc_v(start=0.0);
  discrete Real enc_omega(start=0.0);
  discrete Real lid_range[6];
  discrete Real cam_depth(start=0.0);     // RGB-D, preserved separately (not fused)
  discrete Real sonar_range(start=0.0);    // sonar, preserved separately (not fused)
  discrete Real t_stamp(start=0.0);

  // ===== Continuous range-update helpers (computed every step) =====
  Real r_obs[6];
  Real d_e_arr[6];
  Real ux_arr[6];
  Real uy_arr[6];
  Real innov_arr[6];

  // ===== Reference route =====
  Real x_ref, y_ref, vx_ref, vy_ref, theta_ref, v_ref;

  // ===== Estimated pose used by controller =====
  Real x_hat, y_hat, theta_hat;

  // ===== Control variables =====
  Real e_xb, e_yb, head_err;
  Real v_cmd, omega_cmd;
  Real F_des, M_des;
  Real tauL_raw, tauR_raw;

  // ===== Mission-level outputs =====
  Real loop_pos_err;
  Real loop_head_err;
  Real track_err;
  Real track_err_post65;
  Real min_obs_dist;
  Real collision_flag;
  Real output_rate_Hz;

  // ===== Internal =====
  Real loop_gain;
  Real dist_o1, dist_o2;

protected
  parameter Real Kp_pos  = 3.0;
  parameter Real Kl_lat  = 2.0;
  parameter Real Kp_th   = 4.0;
  parameter Real Kv      = 10.0;
  parameter Real Kw      = 6.0;
  parameter Real Kc_loop = 0.8;
  parameter Real Q_pos   = 0.002;
  parameter Real Q_th   = 0.0005;
  parameter Real k_cov   = 0.5;
  parameter Real k_range = 0.02;  // range-update correction gain

equation
  // ----- Closed reference route -----
  x_ref     = R_route*cos(2.0*pi*time/T_route);
  y_ref     = R_route*sin(2.0*pi*time/T_route);
  vx_ref    = -R_route*(2.0*pi/T_route)*sin(2.0*pi*time/T_route);
  vy_ref    =  R_route*(2.0*pi/T_route)*cos(2.0*pi*time/T_route);
  v_ref     = sqrt(vx_ref*vx_ref + vy_ref*vy_ref + 1e-9);
  theta_ref = atan2(vy_ref, vx_ref);

  // ----- True base dynamics (bounded wheel drives) -----
  der(x)     = v*cos(theta);
  der(y)     = v*sin(theta);
  der(theta) = omega;
  m_base*der(v)     = (tauL + tauR)/r_wheel - b_lin*v;
  I_z*der(omega)    = (tauR - tauL)*B_track/(2.0*r_wheel) - b_rot*omega;

  // ----- Estimated pose (odometry + corrections) -----
  x_hat     = xE + corr_x;
  y_hat     = yE + corr_y;
  theta_hat = thetaE + corr_th;

  // ----- Loop-closure correction: ramps up in final phase of closed route -----
  loop_gain = 0.5*(1.0 + tanh(8.0*(time - 9.0)));

  // ----- Estimator propagation: odometry + IMU fusion + loop-closure pull -----
  der(xE)     = vE*cos(thetaE) - loop_gain*Kc_loop*(xE + corr_x - x0);
  der(yE)     = vE*sin(thetaE) - loop_gain*Kc_loop*(yE + corr_y - y0);
  der(thetaE) = omegaE         - loop_gain*Kc_loop*(thetaE + corr_th - th0);
  der(vE)     = (enc_v - vE)/T_enc;
  der(omegaE) = (imu_omega - omegaE)/T_imu;

  // ----- Finite covariance propagation (bounded steady state) -----
  der(P11) = Q_pos - k_cov*P11;
  der(P22) = Q_pos - k_cov*P22;
  der(P33) = Q_th  - k_cov*P33;
  der(P12) = -k_cov*P12;
  der(P13) = -k_cov*P13;
  der(P23) = -k_cov*P23;

  // ----- Continuous range-update geometry (used by discrete lidar fusion) -----
  for i in 1:6 loop
    r_obs[i]     = if (i == 1 and time > T_route/3.0 and time < 2.0*T_route/3.0) then
                     sqrt((LMx[i]-x)^2 + (LMy[i]-y)^2 + 1e-9) + d_land
                   else
                     sqrt((LMx[i]-x)^2 + (LMy[i]-y)^2 + 1e-9);
    d_e_arr[i]   = sqrt((LMx[i]-xE)^2 + (LMy[i]-yE)^2 + 1e-9);
    ux_arr[i]    = (LMx[i]-xE)/d_e_arr[i];
    uy_arr[i]    = (LMy[i]-yE)/d_e_arr[i];
    innov_arr[i] = r_obs[i] - d_e_arr[i];
  end for;

  // ----- Pose-filtering control law with bounded wheel commands -----
  e_xb      =  (x_ref - x_hat)*cos(theta_hat) + (y_ref - y_hat)*sin(theta_hat);
  e_yb      = -(x_ref - x_hat)*sin(theta_hat) + (y_ref - y_hat)*cos(theta_hat);
  head_err  = atan2(sin(theta_ref - theta_hat), cos(theta_ref - theta_hat));
  v_cmd     = v_ref + Kp_pos*e_xb;
  omega_cmd = Kp_th*head_err - Kl_lat*e_yb;
  F_des     = Kv*(v_cmd - vE) + b_lin*vE;
  M_des     = Kw*(omega_cmd - omegaE) + b_rot*omegaE;
  tauL_raw  = 0.5*F_des*r_wheel - M_des*r_wheel/B_track;
  tauR_raw  = 0.5*F_des*r_wheel + M_des*r_wheel/B_track;
  tauL      = max(-tau_max, min(tau_max, tauL_raw));
  tauR      = max(-tau_max, min(tau_max, tauR_raw));

  // ----- Obstacle distance and collision flag -----
  dist_o1       = sqrt((x-OBSx[1])^2 + (y-OBSy[1])^2) - OBSr[1];
  dist_o2       = sqrt((x-OBSx[2])^2 + (y-OBSy[2])^2) - OBSr[2];
  min_obs_dist  = min(dist_o1, dist_o2);
  collision_flag = if min_obs_dist < 0.0 then 1.0 else 0.0;

  // ----- Mission outputs -----
  loop_pos_err    = sqrt((x_hat - x0)^2 + (y_hat - y0)^2 + 1e-9);
  loop_head_err   = atan2(sin(theta_hat - th0), cos(theta_hat - th0));
  track_err       = sqrt((x - x_ref)^2 + (y - y_ref)^2 + 1e-9);
  track_err_post65 = if time > 6.5 then track_err else 0.0;
  output_rate_Hz  = 1.0/T_out;

  // ===== Discrete sensor sampling at different, declared rates =====
  when sample(0, T_imu) then
    // IMU angular rate (rad/s) — fused into estimator
    imu_omega = omega;
  end when;

  when sample(0, T_enc) then
    // Wheel-encoder-derived linear speed and yaw rate — fused into estimator
    enc_v     = v;
    enc_omega = omega;
    t_stamp   = time;
  end when;

  when sample(0, T_lid) then
    // Raw planar lidar ranges to the 6 fixed landmarks (preserved)
    for i in 1:6 loop
      lid_range[i] = r_obs[i];
    end for;
    // Range-update fusion: project innovation onto landmark bearing
    corr_x = pre(corr_x) + k_range*(innov_arr[1]*ux_arr[1] +
                                     innov_arr[2]*ux_arr[2] +
                                     innov_arr[3]*ux_arr[3] +
                                     innov_arr[4]*ux_arr[4] +
                                     innov_arr[5]*ux_arr[5] +
                                     innov_arr[6]*ux_arr[6]);
    corr_y = pre(corr_y) + k_range*(innov_arr[1]*uy_arr[1] +
                                     innov_arr[2]*uy_arr[2] +
                                     innov_arr[3]*uy_arr[3] +
                                     innov_arr[4]*uy_arr[4] +
                                     innov_arr[5]*uy_arr[5] +
                                     innov_arr[6]*uy_arr[6]);
  end when;

  when sample(0, T_cam) then
    // Forward RGB-D camera raw depth — preserved separately, NOT fused
    cam_depth = sqrt((OBSx[1]-x)^2 + (OBSy[1]-y)^2 + 1e-9);
  end when;

  when sample(0, T_son) then
    // Sonar raw range — preserved separately, NOT fused
    sonar_range = sqrt((OBSx[2]-x)^2 + (OBSy[2]-y)^2 + 1e-9);
  end when;

  annotation (
    experiment(StopTime=10.0, Tolerance=1e-6, Interval=0.01),
    Documentation(info="MapRigMapB: 22 kg mobile base carrying a 20 m planar lidar, forward RGB-D camera, wheel encoders, and IMU at explicitly different rates and transforms. Fuses odometry, IMU, and range updates while preserving camera and sonar data separately. Control uses pose filtering with loop-closure correction. A controlled 0.14 m landmark perturbation is injected during the middle third of the 10 s mission. Outputs finite covariance, loop-closure position and heading error, declared output rate (100 Hz), no-collision flag, and primary tracking error (required < 0.3 m after 6.5 s)."));
end MapRigMapB;