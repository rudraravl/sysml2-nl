model GroundPairResilientC
  // --- Physical parameters (declared in the requirement) ---
  parameter Real m = 14.0   "robot mass [kg]";
  parameter Real r = 0.09   "wheel radius [m]";
  parameter Real tau_max = 9.2 "max wheel torque magnitude [N.m]";

  // --- Parameters assumed because the request does not state them ---
  parameter Real d_wheel = 0.20  "wheel base [m] (assumed)";
  parameter Real I_robot = 0.60  "yaw inertia [kg.m2] (assumed)";
  parameter Real v_ref = 0.5     "reference forward speed [m/s] (assumed)";
  parameter Real form_offset = 0.50 "lateral formation offset [m] (assumed)";
  parameter Real safe_dist = 0.30   "collision-avoidance distance [m] (assumed)";
  parameter Real dist_force = 0.40  "shared disturbance force [N] (assumed)";

  // --- Controller gains (assumed) ---
  parameter Real kp_v = 4.0;
  parameter Real kp_w = 3.0;
  parameter Real kp_a = 30.0;
  parameter Real kp_t = 2.5;

  // --- Dropout schedule: 0.9 s in middle third of 12 s ---
  parameter Real t_start = 6.0  "dropout start [s]";
  parameter Real t_end   = 6.9  "dropout end [s]";
  parameter Real Ts      = 1.0/125.0 "control period [s]";

  // --- Robot 1 continuous states ---
  Real x1(start=0.0, fixed=true);
  Real y1(start=0.0, fixed=true);
  Real th1(start=0.0, fixed=true);
  Real v1(start=0.0, fixed=true);
  Real w1(start=0.0, fixed=true);

  // --- Robot 2 continuous states ---
  Real x2(start=0.0, fixed=true);
  Real y2(start=0.5, fixed=true);
  Real th2(start=0.0, fixed=true);
  Real v2(start=0.0, fixed=true);
  Real w2(start=0.0, fixed=true);

  // --- Wheel torque commands (four channels, bounded) ---
  Real tau1L(start=0.0);
  Real tau1R(start=0.0);
  Real tau2L(start=0.0);
  Real tau2R(start=0.0);

  // --- Reference route ---
  Real x_ref;
  Real y_ref;
  Real route_target;
  Boolean route_completed;

  // --- Communication and last-received peer state ---
  Boolean comm_ok;
  Real t_last_recv(start=0.0);
  Real x2_last(start=0.0);
  Real y2_last(start=0.5);
  Real v2_last(start=0.0);
  Real th2_last(start=0.0);
  Real x1_last(start=0.0);
  Real y1_last(start=0.0);
  Real v1_last(start=0.0);
  Real th1_last(start=0.0);

  // --- Predicted peer positions ---
  Real x1_pred(start=0.0);
  Real y1_pred(start=0.0);
  Real x2_pred(start=0.0);
  Real y2_pred(start=0.5);

  // --- Controller intermediates ---
  Real e1x(start=0.0), e1y(start=0.0);
  Real e2x(start=0.0), e2y(start=0.0);
  Real v_des1(start=0.0), w_des1(start=0.0);
  Real v_des2(start=0.0), w_des2(start=0.0);
  Real F_des1(start=0.0), M_des1(start=0.0);
  Real F_des2(start=0.0), M_des2(start=0.0);
  Real tau1L_raw(start=0.0), tau1R_raw(start=0.0);
  Real tau2L_raw(start=0.0), tau2R_raw(start=0.0);

  // --- Disturbance ---
  Real dist_force_x;

  // --- Inter-robot sensing ---
  Real dist12;
  Real lidar_range;
  Real ux;
  Real uy;
  Real rep_F1;
  Real rep_F2;

  // --- Error observables ---
  Real track_err1;
  Real track_err2;
  Real track_err_primary;
  Real form_err;
  Real form_err_deg(start=0.0);
  Real form_err_rec(start=0.0);

  // --- Finite-status indicator ---
  Real finite_status;

equation
  x_ref = v_ref * time;
  y_ref = 0.0;
  route_target = v_ref * 12.0;
  route_completed = time >= 12.0 - 1.0e-6;

  comm_ok = not (time >= t_start and time < t_end);

  dist_force_x = if noEvent(time >= t_start and time < t_end) then dist_force else 0.0;

  dist12 = sqrt(max((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2), 1.0e-6));
  lidar_range = dist12;
  ux = (x2 - x1) / dist12;
  uy = (y2 - y1) / dist12;
  rep_F1 = if noEvent(dist12 < safe_dist) then kp_a * (safe_dist - dist12) else 0.0;
  rep_F2 = -rep_F1;

  der(x1)  = v1 * cos(th1);
  der(y1)  = v1 * sin(th1);
  der(th1) = w1;
  m * der(v1) = (tau1L + tau1R) / r + dist_force_x;
  I_robot * der(w1) = (tau1R - tau1L) * d_wheel / (2.0 * r);

  der(x2)  = v2 * cos(th2);
  der(y2)  = v2 * sin(th2);
  der(th2) = w2;
  m * der(v2) = (tau2L + tau2R) / r + dist_force_x;
  I_robot * der(w2) = (tau2R - tau2L) * d_wheel / (2.0 * r);

  track_err1 = sqrt(max((x1 - x_ref)*(x1 - x_ref) + (y1 - y_ref)*(y1 - y_ref), 1.0e-9));
  track_err2 = sqrt(max((x2 - x_ref)*(x2 - x_ref) + (y2 - (y_ref + form_offset))*(y2 - (y_ref + form_offset)), 1.0e-9));
  track_err_primary = if noEvent(track_err1 > track_err2) then track_err1 else track_err2;
  form_err = sqrt(max((x2 - x1)*(x2 - x1) + (y2 - y1 - form_offset)*(y2 - y1 - form_offset), 1.0e-9));

  finite_status = 1.0;

algorithm
  when sample(0, Ts) then
    if comm_ok then
      t_last_recv := time;
      x2_last := x2; y2_last := y2; v2_last := v2; th2_last := th2;
      x1_last := x1; y1_last := y1; v1_last := v1; th1_last := th1;
    end if;

    x2_pred := x2_last + v2_last * cos(th2_last) * (time - t_last_recv);
    y2_pred := y2_last + v2_last * sin(th2_last) * (time - t_last_recv);
    x1_pred := x1_last + v1_last * cos(th1_last) * (time - t_last_recv);
    y1_pred := y1_last + v1_last * sin(th1_last) * (time - t_last_recv);

    e1x := x_ref - x1;
    e1y := y_ref - y1;
    v_des1 := kp_v * (e1x * cos(th1) + e1y * sin(th1));
    w_des1 := kp_w * (atan2(e1y, e1x + 1.0e-9) - th1);
    F_des1 := kp_a * (v_des1 - v1) - rep_F1 * ux;
    M_des1 := kp_t * (w_des1 - w1);
    tau1L_raw := (F_des1 * r) / 2.0 - (M_des1 * r) / d_wheel;
    tau1R_raw := (F_des1 * r) / 2.0 + (M_des1 * r) / d_wheel;
    tau1L := if tau1L_raw > tau_max then tau_max elseif tau1L_raw < -tau_max then -tau_max else tau1L_raw;
    tau1R := if tau1R_raw > tau_max then tau_max elseif tau1R_raw < -tau_max then -tau_max else tau1R_raw;

    e2x := x1_pred - x2;
    e2y := (y1_pred + form_offset) - y2;
    v_des2 := kp_v * (e2x * cos(th2) + e2y * sin(th2));
    w_des2 := kp_w * (atan2(e2y, e2x + 1.0e-9) - th2);
    F_des2 := kp_a * (v_des2 - v2) - rep_F2 * ux;
    M_des2 := kp_t * (w_des2 - w2);
    tau2L_raw := (F_des2 * r) / 2.0 - (M_des2 * r) / d_wheel;
    tau2R_raw := (F_des2 * r) / 2.0 + (M_des2 * r) / d_wheel;
    tau2L := if tau2L_raw > tau_max then tau_max elseif tau2L_raw < -tau_max then -tau_max else tau2L_raw;
    tau2R := if tau2R_raw > tau_max then tau_max elseif tau2R_raw < -tau_max then -tau_max else tau2R_raw;
  end when;

  when time >= t_end then
    form_err_deg := form_err;
  end when;

  when time >= 11.9 then
    form_err_rec := form_err;
  end when;

  annotation(
    experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1.0e-6, Interval = 1.0/125.0),
    Documentation(info = "GroundPairResilientC: two 14 kg differential-drive robots (0.09 m wheels) "
      "coordinate in a shared scene under a 0.9 s communication dropout (6.0..6.9 s) inside the middle "
      "third of a 12 s, 125 Hz run. Four wheel-torque channels, bounded at 9.2 N.m, drive the pair. "
      "Each robot uses local proprioception, exteroception (lidar range/bearing), and last-received peer "
      "state with timestamps; during dropout a dead-reckoning prediction maintains coordination and a "
      "shared environmental disturbance is applied. Values for wheel base, inertia, reference speed, "
      "formation offset, safe distance, disturbance magnitude, and gains are assumed because the request "
      "does not state them; physical constants follow the requirement.")
  );
end GroundPairResilientC;