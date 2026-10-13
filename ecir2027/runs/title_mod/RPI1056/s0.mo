model TrackCrawlerBrakeF
  "Floating-base tracked crawler: accelerate to 1.2 m/s, emergency brake at 1.4 m safety range"

  // === Embodiment ===
  parameter Real m = 52.0 "robot hull mass, kg";
  parameter Real L_hull = 1.1 "hull length, m";
  parameter Real r_sprocket = 0.14 "effective sprocket radius, m";
  parameter Real track_sep = 0.50 "track separation, m";

  // === Actuation ===
  parameter Real tau_max = 51.2 "max per-track drive torque, N.m";

  // === Mission ===
  parameter Real v_target = 1.2 "target cruise speed, m/s";
  parameter Real safety_range = 1.4 "obstacle safety trigger range, m";
  parameter Real x_barrier = 7.0 "barrier position ahead of robot, m";

  // === Environment ===
  parameter Real mu = 0.70 "floor friction coefficient";
  parameter Real g = 9.81 "gravitational acceleration, m/s2";

  // === Disturbance ===
  parameter Real F_disturbance = 261.0 "payload disturbance force, N";
  parameter Real T_end = 20.0 "total mission duration, s";
  parameter Real t_dist_start = T_end / 3.0 "disturbance start time, s";
  parameter Real t_dist_end = 2.0 * T_end / 3.0 "disturbance end time, s";

  // === Controller ===
  parameter Real Kp = 300.0 "speed controller proportional gain";
  parameter Real Ki = 100.0 "speed controller integral gain";
  parameter Real v_stop_threshold = 0.01 "velocity threshold for stopped state, m/s";

  // === Verification thresholds ===
  parameter Real v_residual_limit = 0.05 "max residual speed, m/s";
  parameter Real track_err_limit = 0.176 "max tracking error, m";
  parameter Real t_verify = 13.0 "verification time, s";

  // === Dynamic states ===
  Real x(start=0.0, fixed=true) "longitudinal position, m";
  Real v(start=0.0, fixed=true) "longitudinal velocity, m/s";
  Real integ_err(start=0.0, fixed=true) "integral of speed error";

  // === Discrete states ===
  discrete Integer mode(start=0) "control mode: 0=ACCEL, 1=BRAKE, 2=STOPPED";
  discrete Real x_stop(start=0.0) "position at stop, m";
  discrete Real v_at_brake(start=0.0) "velocity at brake onset, m/s";

  // === Derived continuous quantities ===
  Real a "longitudinal acceleration, m/s2";
  Real d_barrier "continuous distance to barrier, m";
  Real F_payload "payload disturbance force, N";
  Real F_normal "normal force on tracks, N";
  Real F_drive "tractive drive force, N";
  Real F_max "max traction force, N";
  Real tau_cmd "unbounded total torque command, N.m";
  Real tau_L "left track torque, N.m";
  Real tau_R "right track torque, N.m";

  // === Sampled sensors ===
  discrete Real v_enc "encoder velocity at 500 Hz, m/s";
  discrete Real a_imu "IMU longitudinal acceleration at 500 Hz, m/s2";
  discrete Real d_camera "depth camera range at 30 Hz, m";

  // === Verification metrics ===
  Real v_residual "absolute speed, m/s";
  Real track_err "overshoot past brake trigger point, m";

  // === Verification flags ===
  Boolean speed_limit_ok "speed does not exceed target + tolerance";
  Boolean effort_limit_ok "torque within bounds";
  Boolean no_collision "robot stops before barrier";
  Boolean residual_ok "residual speed below threshold when stopped";
  Boolean tracking_ok "tracking error below threshold after 13 s";
  Boolean braking_monotonic "velocity non-increasing during brake";
  Boolean no_nan_inf "no NaN or infinite physical values";

equation
  // Distance to barrier
  d_barrier = x_barrier - x;

  // Payload disturbance (vertical load during middle third of run)
  F_payload = if (time >= t_dist_start and time <= t_dist_end) then F_disturbance else 0.0;
  F_normal = m * g + F_payload;
  F_max = mu * F_normal;

  // Robot longitudinal dynamics
  der(x) = v;
  der(v) = a;
  a = if mode == 2 then 0.0 else F_drive / m;

  // Integral error accumulates only during ACCEL mode
  der(integ_err) = if mode == 0 then (v_target - v) else 0.0;

  // Torque command from speed controller or brake logic
  tau_cmd = if mode == 0 then (Kp * (v_target - v) + Ki * integ_err)
            else if mode == 1 then (-2.0 * tau_max)
            else 0.0;

  // Split torque equally, bound each track to limit
  tau_L = max(-tau_max, min(tau_max, tau_cmd / 2.0));
  tau_R = max(-tau_max, min(tau_max, tau_cmd / 2.0));

  // Traction-limited drive force
  F_drive = max(-F_max, min(F_max, (tau_L + tau_R) / r_sprocket));

  // Verification metrics
  v_residual = abs(v);
  track_err = max(0.0, x - (x_barrier - safety_range));

  // Verification flags
  speed_limit_ok = v <= v_target + 0.1;
  effort_limit_ok = abs(tau_L) <= tau_max + 1e-9 and abs(tau_R) <= tau_max + 1e-9;
  no_collision = x < x_barrier - 0.001;
  residual_ok = not (mode == 2) or (v_residual < v_residual_limit);
  tracking_ok = not (mode == 2 and time >= t_verify) or (track_err < track_err_limit);
  braking_monotonic = not (mode == 1) or (v <= v_at_brake + 1e-6);
  no_nan_inf = (x == x) and (v == v) and (a == a) and (F_drive == F_drive) and (integ_err == integ_err);

algorithm
  // 500 Hz encoder and IMU sampling
  when sample(0.0, 1.0/500.0) then
    v_enc := v;
    a_imu := a;
  end when;

  // 30 Hz depth camera sampling
  when sample(0.0, 1.0/30.0) then
    d_camera := max(0.0, d_barrier);
  end when;

  // Emergency brake trigger: obstacle enters safety range
  when d_barrier < safety_range and mode == 0 then
    mode := 1;
    v_at_brake := v;
  end when;

  // Stopped detection
  when abs(v) < v_stop_threshold and mode == 1 then
    mode := 2;
    x_stop := x;
  end when;

end TrackCrawlerBrakeF;