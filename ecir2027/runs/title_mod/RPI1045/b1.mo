model TrackCrawlerInspectA
  /* Tracked inspection crawler in an S-corridor with two recessed alcoves.
     Discrete controller/estimator at 80 Hz; continuous planar plant.
     Only values stated in the requirement are treated as facts; chosen
     tuning/geometry parameters are labeled "(chosen)". */

  // ---- Physical parameters (from requirement only) ----
  parameter Real m_hull = 52.0        "hull mass [kg]";
  parameter Real L_hull = 1.1         "hull length [m]";
  parameter Real r_sp   = 0.14        "effective sprocket radius [m]";
  parameter Real B_track = 0.50       "track separation [m]";
  parameter Real tau_max = 30.2       "bounded track command magnitude [N.m]";
  parameter Real v_ref   = 0.8        "target forward speed [m/s]";
  parameter Real wall_sep = 1.8       "corridor wall spacing [m]";
  parameter Real clearance_req = 0.18 "minimum wall clearance [m]";
  parameter Real F_side  = 45.0       "applied side load disturbance [N]";
  parameter Real T_end   = 8.0        "scenario duration [s]";
  parameter Real dt      = 1.0/80.0   "controller/estimator sample period [s]";

  // ---- Derived / chosen plant parameters ----
  parameter Real Iz      = m_hull*L_hull^2/12.0 "approx yaw inertia [kg.m2]  (chosen)";
  parameter Real C_lat   = 220.0  "lateral slip damping [N.s/m]  (chosen)";
  parameter Real L_total = v_ref*T_end          "total path length [m]";

  // ---- Corridor geometry (chosen to satisfy S-shape + two alcoves) ----
  parameter Real A_s = 0.40     "S-curve lateral amplitude [m]  (chosen)";
  parameter Real L_s = 3.20     "S-curve wavelength [m]  (chosen)";
  parameter Real alc_depth = 0.50 "alcove recess depth [m]  (chosen)";

  // ---- Continuous plant states ----
  Real x(start=0.0, fixed=true)     "world x [m]";
  Real y(start=0.0, fixed=true)     "world y [m]";
  Real theta(start=0.0, fixed=true) "heading [rad]";
  Real v_t(start=0.05, fixed=true)  "body forward speed [m/s]";
  Real v_n(start=0.0, fixed=true)   "body lateral speed [m/s]";
  Real omega(start=0.0, fixed=true) "yaw rate [rad/s]";

  // ---- Discrete command outputs (hold between samples) ----
  Real tau_L_cmd(start=0.0)  "left track commanded torque [N.m]";
  Real tau_R_cmd(start=0.0)  "right track commanded torque [N.m]";
  Real e_speed_int(start=0.0) "speed integral state [m]";

  // ---- Discrete estimator states (80 Hz) ----
  Real x_hat(start=0.0)    "estimated x [m]";
  Real y_hat(start=0.0)    "estimated y [m]";
  Real th_hat(start=0.0)   "estimated heading [rad]";
  Real v_hat(start=0.05)   "estimated forward speed [m/s]";
  Real om_hat(start=0.0)   "estimated yaw rate [rad/s]";
  Real P_x(start=0.02)     "estimated x covariance [m2]";
  Real P_y(start=0.02)     "estimated y covariance [m2]";
  Real P_th(start=0.02)    "estimated heading covariance [rad2]";

  // ---- Sensors ----
  Real d_left_lidar  "left lidar range to wall [m]";
  Real d_right_lidar "right lidar range to wall [m]";
  Real imu_omega     "IMU yaw rate measurement [rad/s]";
  Real odo_v         "odometry forward speed measurement [m/s]";

  // ---- Corridor walls (functions of x) ----
  Real ref_y_path    "centerline y at current x [m]";
  Real ref_th_path   "centerline heading at current x [rad]";
  Real wall_upper    "upper wall y at current x [m]";
  Real wall_lower    "lower wall y at current x [m]";
  Real alcove_off    "alcove recess offset at current x [m]";
  Real d_left_true   "true left clearance [m]";
  Real d_right_true  "true right clearance [m]";
  Real min_clearance "minimum of left/right clearance [m]";

  // ---- Disturbance ----
  Real F_side_now "active side load [N]";

  // ---- Tracking / performance monitors ----
  Real e_track     "primary lateral tracking error (true) [m]";
  Real e_head      "heading error (true) [rad]";
  Real route_frac  "route completion fraction [-]";
  Boolean track_ok "primary tracking error satisfied after 5.2 s";
  Boolean clear_ok "wall clearance satisfied";
  Boolean finite_ok "no NaN/infinite values";

  // ---- Controller internal (discrete) ----
  Real e_y_disc(start=0.0)    "lateral error from estimator [m]";
  Real e_th_disc(start=0.0)   "heading error from estimator [rad]";
  Real steer_term(start=0.0)  "steering torque contribution [N.m]";
  Real base_term(start=0.0)   "speed torque contribution [N.m]";
  Real obs_rep(start=0.0)     "obstacle repulsion term [N.m]";

  // Controller gains (chosen; labeled)
  parameter Real Kp_speed = 26.0 "(chosen)";
  parameter Real Ki_speed = 8.0  "(chosen)";
  parameter Real Kp_y     = 1.6  "(chosen)";
  parameter Real Kp_th    = 1.9  "(chosen)";
  parameter Real K_obs    = 4.0  "(chosen)";
  // Estimator gains (chosen; labeled)
  parameter Real K_odo_v   = 0.10 "(chosen)";
  parameter Real K_imu_w   = 0.10 "(chosen)";
  parameter Real K_lidar_y = 0.35 "(chosen)";
  parameter Real Q_p      = 1e-4  "process noise (chosen)";
  parameter Real R_y      = 1e-3  "lidar measurement noise (chosen)";

  // Continuous helper
  Real x_path_clamped "clamped x for wall lookup [m]";

protected
  // Continuous monitor helper
  Real e_head_raw "raw heading error (true) [rad]";

  // Discrete-only intermediates (assigned inside when only)
  Real y_meas_lidar "lidar-derived y measurement [m]";
  Real e_speed_disc "speed error from estimator [m/s]";
  Real e_head_disc_raw "raw heading error from estimator [rad]";
  Real tau_L_raw "unlimited left command [N.m]";
  Real tau_R_raw "unlimited right command [N.m]";
  Real d_left_thresh  "obstacle threshold left [m]";
  Real d_right_thresh "obstacle threshold right [m]";
  Real x_hat_pred "predicted x estimate [m]";
  Real y_hat_pred "predicted y estimate [m]";
  Real th_hat_pred "predicted heading estimate [rad]";
  Real P_x_pred "predicted x covariance [m2]";
  Real P_y_pred "predicted y covariance [m2]";
  Real P_th_pred "predicted heading covariance [rad2]";

equation
  // ---------- Path / corridor geometry ----------
  x_path_clamped = max(0.0, min(x, L_total));
  ref_y_path  = A_s*Modelica.Math.sin(2.0*Modelica.Constants.pi*x_path_clamped/L_s);
  ref_th_path = Modelica.Math.atan2(A_s*2.0*Modelica.Constants.pi/L_s*
                  Modelica.Math.cos(2.0*Modelica.Constants.pi*x_path_clamped/L_s), 1.0);
  alcove_off = if (x_path_clamped >= 1.5 and x_path_clamped <= 2.3) or
                  (x_path_clamped >= 4.0 and x_path_clamped <= 4.8)
               then alc_depth else 0.0;
  wall_upper = ref_y_path + wall_sep/2.0 + alcove_off;
  wall_lower = ref_y_path - wall_sep/2.0 - alcove_off;

  // ---------- True clearances ----------
  d_left_true  = y - wall_lower;
  d_right_true = wall_upper - y;
  min_clearance = 0.5*(d_left_true + d_right_true - abs(d_left_true - d_right_true));

  // ---------- Disturbance: middle third ----------
  F_side_now = if (time >= T_end/3.0 and time <= 2.0*T_end/3.0) then F_side else 0.0;

  // ---------- Continuous plant dynamics ----------
  der(x)     = v_t*Modelica.Math.cos(theta) - v_n*Modelica.Math.sin(theta);
  der(y)     = v_t*Modelica.Math.sin(theta) + v_n*Modelica.Math.cos(theta);
  der(theta) = omega;
  der(v_t)   = (tau_L_cmd/r_sp + tau_R_cmd/r_sp + F_side_now*Modelica.Math.sin(theta))/m_hull;
  der(v_n)   = (F_side_now*Modelica.Math.cos(theta) - C_lat*v_n)/m_hull;
  der(omega) = (tau_R_cmd - tau_L_cmd)*B_track/(2.0*Iz);

  // ---------- Sensors (continuous) ----------
  d_left_lidar  = max(0.05, d_left_true  + 0.015*Modelica.Math.sin(7.0*time));
  d_right_lidar = max(0.05, d_right_true + 0.015*Modelica.Math.sin(6.3*time + 1.0));
  imu_omega = omega + 0.003*Modelica.Math.sin(11.0*time);
  odo_v     = v_t   + 0.005*Modelica.Math.sin(9.0*time);

  // ---------- Tracking monitors (true) ----------
  e_track = y - ref_y_path;
  e_head_raw = theta - ref_th_path;
  e_head = Modelica.Math.atan2(Modelica.Math.sin(e_head_raw), Modelica.Math.cos(e_head_raw));
  route_frac = max(0.0, min(1.0, x_path_clamped/L_total));
  track_ok = if time >= 5.2 then abs(e_track) < 0.27 else true;
  clear_ok = (d_left_true > clearance_req) and (d_right_true > clearance_req);
  finite_ok = (abs(x) < 1e12) and (abs(y) < 1e12) and (abs(theta) < 1e6) and
              (abs(v_t) < 1e6) and (abs(v_n) < 1e6) and (abs(omega) < 1e6) and
              (abs(tau_L_cmd) < 1e6) and (abs(tau_R_cmd) < 1e6) and
              (abs(x_hat) < 1e12) and (abs(y_hat) < 1e12) and (abs(th_hat) < 1e6) and
              (abs(P_x) < 1e6) and (abs(P_y) < 1e6) and (abs(P_th) < 1e6);

  // ---------- Discrete controller + estimator at 80 Hz ----------
  when sample(dt, dt) then
    // --- Localization fusion (complementary EKF-lite) ---
    // Predict step from previous estimate using odometry/IMU
    x_hat_pred = pre(x_hat) + dt*(pre(v_hat)*Modelica.Math.cos(pre(th_hat)));
    y_hat_pred = pre(y_hat) + dt*(pre(v_hat)*Modelica.Math.sin(pre(th_hat)));
    th_hat_pred = pre(th_hat) + dt*imu_omega;
    P_x_pred  = max(1e-6, pre(P_x)  + Q_p);
    P_y_pred  = max(1e-6, pre(P_y)  + Q_p);
    P_th_pred = max(1e-6, pre(P_th) + Q_p);

    // Lidar-derived y measurement (15 m planar lidar covers corridor width)
    y_meas_lidar = (wall_lower + d_left_lidar + wall_upper - d_right_lidar)/2.0;

    // Correct step
    x_hat  = x_hat_pred + K_odo_v*(odo_v - pre(v_hat))*dt*Modelica.Math.cos(pre(th_hat));
    P_x    = max(1e-6, P_x_pred - K_odo_v*P_x_pred + 1e-4*K_odo_v);

    y_hat  = y_hat_pred + K_lidar_y*(y_meas_lidar - y_hat_pred);
    P_y    = max(1e-6, P_y_pred - K_lidar_y*P_y_pred + R_y*K_lidar_y);

    th_hat = Modelica.Math.atan2(Modelica.Math.sin(th_hat_pred),
                                  Modelica.Math.cos(th_hat_pred));
    P_th   = max(1e-6, P_th_pred - K_imu_w*P_th_pred + 1e-4*K_imu_w);

    v_hat  = pre(v_hat) + K_odo_v*(odo_v - pre(v_hat));
    om_hat = pre(om_hat) + K_imu_w*(imu_omega - pre(om_hat));

    // --- Path tracking (localization-aware) ---
    e_y_disc = y_hat - A_s*Modelica.Math.sin(2.0*Modelica.Constants.pi*
                 max(0.0, min(x_hat, L_total))/L_s);
    e_head_disc_raw = th_hat - Modelica.Math.atan2(A_s*2.0*Modelica.Constants.pi/L_s*
                 Modelica.Math.cos(2.0*Modelica.Constants.pi*max(0.0, min(x_hat, L_total))/L_s), 1.0);
    e_th_disc = Modelica.Math.atan2(Modelica.Math.sin(e_head_disc_raw),
                                    Modelica.Math.cos(e_head_disc_raw));

    // --- Obstacle avoidance from lidar ranges ---
    d_left_thresh  = clearance_req + 0.05;
    d_right_thresh = clearance_req + 0.05;
    obs_rep = (if d_left_lidar  < d_left_thresh  then 2.0*(d_left_thresh  - d_left_lidar)  else 0.0)
            - (if d_right_lidar < d_right_thresh then 2.0*(d_right_thresh - d_right_lidar) else 0.0);

    // --- Speed control (PI) ---
    e_speed_disc = v_ref - v_hat;
    e_speed_int  = max(-3.0, min(3.0, pre(e_speed_int) + e_speed_disc*dt));
    base_term    = Kp_speed*e_speed_disc + Ki_speed*e_speed_int;

    // --- Steering = path tracking + obstacle repulsion ---
    steer_term   = Kp_y*e_y_disc + Kp_th*e_th_disc + K_obs*obs_rep;

    // --- Track commands with magnitude bound 30.2 N.m ---
    tau_L_raw = base_term - steer_term;
    tau_R_raw = base_term + steer_term;
    tau_L_cmd = max(-tau_max, min(tau_max, tau_L_raw));
    tau_R_cmd = max(-tau_max, min(tau_max, tau_R_raw));
  end when;

  annotation (
    experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="Tracked crawler with EKF-lite fusion of odometry, IMU, and 15 m planar lidar. "
                       "S-corridor 1.8 m wide with two recessed alcoves. 45 N side load during middle third. "
                       "80 Hz discrete controller/estimator, 8 s run."));
end TrackCrawlerInspectA;