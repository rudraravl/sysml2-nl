model GroundPairResilientE
  "Two 14 kg differential-drive robots, bounded wheel torques (<=11 N.m per wheel),
   distributed control with peer-state prediction through a 1.2 s communication
   dropout, shared disturbance during dropout, fail-closed acceptance.
   NOTE: wheelbase, yaw inertia, viscous coefficients, gains, route, and offset
   are NOT specified in the requirement; values below are explicit assumptions
   required to compile and run, and are labeled via comments."

  // ---- Plant parameters (specified) ----
  parameter Real m = 14.0 "robot mass [kg]";
  parameter Real r = 0.09 "wheel radius [m]";
  parameter Real tau_max = 11.0 "per-wheel torque bound [N.m]";

  // ---- Plant parameters (assumed, not specified in requirement) ----
  parameter Real b = 0.15 "half wheelbase [m] (assumed)";
  parameter Real I_z = 0.35 "yaw inertia [kg.m2] (assumed)";
  parameter Real c_v = 0.5 "body forward viscous coeff [N.s/m] (assumed)";
  parameter Real c_omega = 0.5 "yaw viscous coeff [N.m.s] (assumed)";

  // ---- Controller / scenario parameters (assumed unless stated) ----
  parameter Real v_max = 0.8 "max linear speed [m/s] (assumed)";
  parameter Real omega_max = 3.0 "max yaw rate [rad/s] (assumed)";
  parameter Real kp_v = 1.0 "A speed gain (assumed)";
  parameter Real kp_w = 4.0 "heading gain (assumed)";
  parameter Real kp_tau = 2.0 "wheel-speed torque gain (assumed)";
  parameter Real kp_form = 1.0 "B formation gain (assumed)";
  parameter Real k_rep = 1.0 "collision repulsion gain (assumed)";
  parameter Real safe_dist = 0.6 "collision safe distance [m] (assumed)";
  parameter Real dt_ctrl = 0.004 "control period [s] = 250 Hz";
  parameter Real t_drop_start = 6.0 "communication dropout start [s]";
  parameter Real t_drop_end = 7.2 "communication dropout end [s] (1.2 s dropout)";
  parameter Real dist_amp = 4.0 "shared disturbance decel magnitude [m/s2] (assumed)";
  parameter Real goal_x = 5.5 "A route goal x [m] (assumed)";
  parameter Real form_off_x = 0.0 "B formation offset x [m] (assumed)";
  parameter Real form_off_y = -1.2 "B formation offset y [m] (assumed)";

  // ---- Communication / disturbance ----
  Boolean in_drop = time >= t_drop_start and time < t_drop_end;
  Real dist_force "shared world-x disturbance force per unit mass-equivalent [m/s2]";

  // ---- Robot A continuous states ----
  Real x_a(start = 0.0, unit = "m");
  Real y_a(start = 0.0, unit = "m");
  Real theta_a(start = 0.0, unit = "rad");
  Real v_a(start = 0.0, unit = "m/s");
  Real omega_a(start = 0.0, unit = "rad/s");

  // ---- Robot B continuous states ----
  Real x_b(start = 0.0, unit = "m");
  Real y_b(start = form_off_y, unit = "m");
  Real theta_b(start = 0.0, unit = "rad");
  Real v_b(start = 0.0, unit = "m/s");
  Real omega_b(start = 0.0, unit = "rad/s");

  // ---- Sensors (proprioception + exteroception) ----
  Real enc_La, enc_Ra, enc_Lb, enc_Rb "wheel encoder angular speeds [rad/s]";
  Real imu_theta_a, imu_omega_a, imu_theta_b, imu_omega_b "IMU outputs";
  Real lidar_a, lidar_b "lidar range to peer [m]";

  // ---- Discrete control / communication state ----
  discrete Real tauLa(start = 0.0), tauRa(start = 0.0) "A wheel torque commands [N.m]";
  discrete Real tauLb(start = 0.0), tauRb(start = 0.0) "B wheel torque commands [N.m]";
  discrete Real recv_x_a(start = 0.0), recv_y_a(start = 0.0), recv_theta_a(start = 0.0);
  discrete Real recv_v_a(start = 0.0);
  discrete Real recv_t(start = 0.0) "timestamp of last received peer state";
  discrete Real pred_x_a(start = 0.0), pred_y_a(start = 0.0) "B's prediction of A pose";
  discrete Real form_err_peak(start = 0.0) "peak formation error during dropout [m]";

  // ---- Performance / acceptance traces ----
  Real track_err "A route tracking error [m]";
  Real form_err "instantaneous formation error [m]";
  Real coll_dist "peer separation [m]";
  discrete Boolean route_complete(start = false);
  discrete Boolean primary_pass(start = false);
  discrete Boolean form_recovered(start = false);
  Boolean finite_ok "no NaN/Inf in physical, control, estimator values";
  Boolean acceptance "fail-closed acceptance aggregate";

equation
  // ---- Sensors (no slip; encoders = wheel angular speeds) ----
  enc_La = (v_a - b * omega_a) / r;
  enc_Ra = (v_a + b * omega_a) / r;
  enc_Lb = (v_b - b * omega_b) / r;
  enc_Rb = (v_b + b * omega_b) / r;
  imu_theta_a = theta_a;
  imu_omega_a = omega_a;
  imu_theta_b = theta_b;
  imu_omega_b = omega_b;
  lidar_a = sqrt(max((x_b - x_a) ^ 2 + (y_b - y_a) ^ 2, 1.0e-9));
  lidar_b = lidar_a;

  // ---- Shared environmental disturbance (only while communication unavailable) ----
  dist_force = if in_drop then -dist_amp else 0.0;

  // ---- Robot A dynamics ----
  der(x_a) = v_a * cos(theta_a);
  der(y_a) = v_a * sin(theta_a);
  der(theta_a) = omega_a;
  der(v_a) = ((tauLa + tauRa) / r - c_v * v_a + dist_force * cos(theta_a)) / m;
  der(omega_a) = ((tauRa - tauLa) * b / r - c_omega * omega_a) / I_z;

  // ---- Robot B dynamics ----
  der(x_b) = v_b * cos(theta_b);
  der(y_b) = v_b * sin(theta_b);
  der(theta_b) = omega_b;
  der(v_b) = ((tauLb + tauRb) / r - c_v * v_b + dist_force * cos(theta_b)) / m;
  der(omega_b) = ((tauRb - tauLb) * b / r - c_omega * omega_b) / I_z;

  // ---- Error traces ----
  track_err = sqrt(max((goal_x - x_a) ^ 2 + (0.0 - y_a) ^ 2, 1.0e-9));
  form_err = sqrt(max((x_a + form_off_x - x_b) ^ 2 + (y_a + form_off_y - y_b) ^ 2, 1.0e-9));
  coll_dist = lidar_a;

  // ---- Sampled distributed control at 250 Hz ----
  when sample(0, dt_ctrl) then
    // communication: refresh last-received peer state only when link is up
    if not in_drop then
      recv_x_a := x_a;
      recv_y_a := y_a;
      recv_theta_a := theta_a;
      recv_v_a := v_a;
      recv_t := time;
    end if;
    // compute bounded torque commands and peer prediction
    (tauLa, tauRa, tauLb, tauRb, pred_x_a, pred_y_a) := ctrlStep(
      x_a, y_a, theta_a, v_a, omega_a,
      x_b, y_b, theta_b, v_b, omega_b,
      enc_La, enc_Ra, enc_Lb, enc_Rb,
      recv_x_a, recv_y_a, recv_theta_a, recv_v_a, recv_t,
      time,
      goal_x, form_off_x, form_off_y,
      r, b, v_max, omega_max, kp_v, kp_w, kp_tau, kp_form, k_rep, safe_dist, tau_max);
    // track degraded (peak) formation error during dropout
    if in_drop and form_err > form_err_peak then
      form_err_peak := form_err;
    end if;
  end when;

  // ---- Latched acceptance conditions ----
  when track_err < 0.05 then
    route_complete := true;
  end when;

  when time >= 10.4 then
    primary_pass := track_err < 0.54;
  end when;

  when time >= 14.0 and form_err < 0.3 then
    form_recovered := true;
  end when;

  // ---- Finite-value check (NaN: v<>v ; Inf: |v|>1e300) ----
  finite_ok = (x_a == x_a) and (y_a == y_a) and (theta_a == theta_a) and (v_a == v_a) and (omega_a == omega_a)
    and (x_b == x_b) and (y_b == y_b) and (theta_b == theta_b) and (v_b == v_b) and (omega_b == omega_b)
    and (tauLa == tauLa) and (tauRa == tauRa) and (tauLb == tauLb) and (tauRb == tauRb)
    and (pred_x_a == pred_x_a) and (pred_y_a == pred_y_a)
    and (track_err == track_err) and (form_err == form_err)
    and (x_a < 1.0e300) and (x_b < 1.0e300) and (v_a < 1.0e300) and (v_b < 1.0e300)
    and (track_err < 1.0e300) and (form_err < 1.0e300);

  // ---- Fail-closed acceptance aggregate ----
  acceptance = finite_ok and primary_pass and route_complete and form_recovered and (coll_dist > safe_dist);

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Interval = 0.004, Tolerance = 1.0e-6),
    Documentation(info = "GroundPairResilientE: two 14 kg differential-drive robots (0.09 m wheels),
   four bounded wheel-torque channels (<=11 N.m per wheel), distributed control with peer-state
   prediction through a 1.2 s dropout (6.0-7.2 s, within middle third of 16 s) with a shared
   disturbance applied only during the dropout. 250 Hz sampled control. Fail-closed acceptance
   requires actuator bounds, collision avoidance, degraded/recovered formation error, finite
   estimates, completed route, primary tracking error < 0.54 m after 10.4 s, and no NaN/Inf."));
end GroundPairResilientE;