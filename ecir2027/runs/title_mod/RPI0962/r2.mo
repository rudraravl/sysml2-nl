model DiffRoverRouteB
  /* Differential-drive rover following waypoints [0,0] -> [4,0] -> [7,2] -> [10,2]
     with lateral push disturbance during middle third of 10 s mission.
     Unknown facts (obstacle geometry, caster dynamics, motor electrical model,
     sensor noise) are omitted rather than fabricated. */

  // --- Physical parameters ---
  parameter Real m = 19.0 "chassis mass [kg]";
  parameter Real Lx = 0.65 "chassis length [m]";
  parameter Real Ly = 0.44 "chassis width [m]";
  parameter Real Lz = 0.22 "chassis height [m]";
  parameter Real r_w = 0.10 "wheel radius [m]";
  parameter Real L_w = 0.46 "wheel separation [m]";
  parameter Real mu = 0.82 "floor friction coefficient [-]";
  parameter Real tau_max = 10.7 "max wheel torque [N.m]";
  parameter Real v_lim = 1.5 "speed limit [m/s]";
  parameter Real g = 9.81 "gravity [m/s2]";

  // Derived inertia
  parameter Real I_z = m*(Lx*Lx + Ly*Ly)/12.0 "yaw inertia [kg.m2]";

  // Waypoint coordinates
  parameter Real wx0=0.0, wy0=0.0;
  parameter Real wx1=4.0, wy1=0.0;
  parameter Real wx2=7.0, wy2=2.0;
  parameter Real wx3=10.0, wy3=2.0;

  // Segment 1 direction data
  parameter Real s1len = sqrt((wx2-wx1)*(wx2-wx1)+(wy2-wy1)*(wy2-wy1)) "segment 1 length [m]";

  // Controller parameters
  parameter Real v_cmd = 1.2 "cruise speed command [m/s]";
  parameter Real k_cross = 2.5 "cross-track gain [1/s]";
  parameter Real k_head = 4.0 "heading-error gain [1/s]";
  parameter Real k_tau = 20.0 "wheel velocity gain [N.s/m]";
  parameter Real omega_lim = 1.2 "desired yaw-rate limit [rad/s]";
  parameter Real b_roll = 5.0 "rolling resistance [N.s/m]";
  parameter Real b_yaw = 0.3 "yaw damping [N.m.s/rad]";
  parameter Real b_lat = 1000.0 "lateral grip damping [N.s/m]";
  parameter Real pi_const = 3.14159265358979;

  // Disturbance timing (middle third of 10 s)
  parameter Real t_push_a = 10.0/3.0 "push start [s]";
  parameter Real t_push_b = 20.0/3.0 "push end [s]";
  parameter Real F_push = 84.0 "lateral push magnitude [N]";

  // --- Dynamic states ---
  Real x(start=0.0, fixed=true) "global x [m]";
  Real y(start=0.0, fixed=true) "global y [m]";
  Real theta(start=0.0, fixed=true) "heading [rad]";
  Real v(start=0.0, fixed=true) "forward speed [m/s]";
  Real v_n(start=0.0, fixed=true) "lateral speed [m/s]";
  Real omega(start=0.0, fixed=true) "yaw rate [rad/s]";

  // --- Algebraic: plant ---
  Real v_r "right wheel tangential speed [m/s]";
  Real v_l "left wheel tangential speed [m/s]";
  Real tau_r "right wheel torque [N.m]";
  Real tau_l "left wheel torque [N.m]";
  Real F_drv "net drive force [N]";
  Real T_drv "net drive yaw torque [N.m]";
  Real F_lateral "applied lateral push in body frame [N]";

  // --- Algebraic: controller ---
  Real e_ct "cross-track error [m]";
  Real theta_ref "reference heading [rad]";
  Real th_err "heading error wrapped [rad]";
  Real th_err_raw "unwrapped heading error [rad]";
  Real d_final "distance to final waypoint [m]";
  Real v_des "desired speed [m/s]";
  Real om_des "desired yaw rate [rad/s]";
  Real om_des_s "saturated desired yaw rate [rad/s]";
  Real vr_des "desired right wheel speed [m/s]";
  Real vl_des "desired left wheel speed [m/s]";

  // --- Sensors / estimator (ideal in this model) ---
  Real x_est(start=0.0) "odometric x estimate [m]";
  Real y_est(start=0.0) "odometric y estimate [m]";
  Real th_est(start=0.0) "IMU/odometry heading estimate [rad]";
  Real v_est "estimated forward speed [m/s]";
  Real om_est "estimated yaw rate [rad/s]";
  Real vr_enc "right encoder wheel speed [m/s]";
  Real vl_enc "left encoder wheel speed [m/s]";

  // --- Metrics / observables ---
  Real track_err "primary tracking error [m]";
  Real cross_err "cross-track error [m]";
  Real chassis_att "chassis attitude [rad]";
  Real chassis_spd "chassis speed [m/s]";
  Boolean collision "collision flag";
  Boolean speed_ok "wheel speed within bound";
  Boolean actuator_ok "torque within bound";

equation
  // ---- Wheel kinematics ----
  v_r = v + omega * L_w / 2.0;
  v_l = v - omega * L_w / 2.0;

  // ---- Drive forces ----
  F_drv = (tau_r + tau_l) / r_w;
  T_drv = (tau_r - tau_l) * L_w / (2.0 * r_w);

  // ---- Lateral push disturbance (body lateral y) ----
  F_lateral = if (time >= t_push_a) and (time <= t_push_b) then F_push else 0.0;

  // ---- Body-frame dynamics ----
  der(v) = (F_drv - b_roll * v) / m;
  der(v_n) = (F_lateral - b_lat * v_n) / m;
  der(omega) = (T_drv - b_yaw * omega) / I_z;

  // ---- Global kinematics ----
  der(x) = v * cos(theta) - v_n * sin(theta);
  der(y) = v * sin(theta) + v_n * cos(theta);
  der(theta) = omega;

  // ---- Segment selection and path errors ----
  if x < 4.0 then
    e_ct = y;
    theta_ref = 0.0;
  elseif x < 7.0 then
    e_ct = (-(x - wx1) * (wy2 - wy1) + (y - wy1) * (wx2 - wx1)) / s1len;
    theta_ref = atan2(wy2 - wy1, wx2 - wx1);
  else
    e_ct = y - 2.0;
    theta_ref = 0.0;
  end if;

  // ---- Heading error with single wrap ----
  th_err_raw = theta_ref - theta;
  th_err = if th_err_raw > pi_const then th_err_raw - 2.0*pi_const
         elseif th_err_raw < -pi_const then th_err_raw + 2.0*pi_const
         else th_err_raw;

  // ---- Distance to final waypoint ----
  d_final = sqrt((x - wx3)*(x - wx3) + (y - wy3)*(y - wy3));

  // ---- Desired speed (smooth deceleration near goal) ----
  v_des = v_cmd * (1.0 - exp(-d_final / 0.5));

  // ---- Desired yaw rate ----
  om_des = k_head * th_err - k_cross * e_ct;
  om_des_s = if om_des > omega_lim then omega_lim
           elseif om_des < -omega_lim then -omega_lim
           else om_des;

  // ---- Desired wheel speeds with limit ----
  vr_des = v_des + om_des_s * L_w / 2.0;
  vl_des = v_des - om_des_s * L_w / 2.0;

  // ---- Wheel torque commands with actuator saturation ----
  tau_r = if k_tau * (vr_des - v_r) > tau_max then tau_max
        elseif k_tau * (vr_des - v_r) < -tau_max then -tau_max
        else k_tau * (vr_des - v_r);
  tau_l = if k_tau * (vl_des - v_l) > tau_max then tau_max
        elseif k_tau * (vl_des - v_l) < -tau_max then -tau_max
        else k_tau * (vl_des - v_l);

  // ---- Ideal sensors / estimator ----
  x_est = x;
  y_est = y;
  th_est = theta;
  v_est = v;
  om_est = omega;
  vr_enc = v_r;
  vl_enc = v_l;

  // ---- Metrics ----
  track_err = abs(e_ct);
  cross_err = e_ct;
  chassis_att = theta;
  chassis_spd = sqrt(v*v + v_n*v_n);
  collision = false; // obstacle positions not specified; path assumed clear
  speed_ok = (abs(v_r) <= v_lim + 0.01) and (abs(v_l) <= v_lim + 0.01);
  actuator_ok = (abs(tau_r) <= tau_max + 0.01) and (abs(tau_l) <= tau_max + 0.01);

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="DiffRoverRouteB: 19 kg differential-drive rover (0.65x0.44x0.22 m, "
      "0.10 m radius wheels, 0.46 m separation) follows planar waypoints with bounded "
      "path-following and wheel-speed control. 84 N lateral push applied during middle "
      "third [3.33, 6.67] s. Floor friction 0.82. Controller and estimator run at 100 Hz "
      "output interval. Tracking error required < 0.3 m after 6.5 s.")
  );
end DiffRoverRouteB;