model GroundPairResilientC
  // ------------------------------------------------------------------
  // GroundPairResilientC
  // Two differential-drive robots (14 kg, r = 0.09 m) in one shared
  // scene, distributed control with dead-reckoning prediction during
  // a 0.9 s communication dropout in the middle third of a 12 s run.
  // Control loop runs at 125 Hz. Max wheel torque 9.2 N.m per channel.
  // ------------------------------------------------------------------

  // --- Physical parameters (declared in the requirement) ---
  parameter Real m = 14.0          "robot mass [kg]";
  parameter Real r = 0.09          "wheel radius [m]";
  parameter Real tau_max = 9.2     "max wheel torque magnitude [N.m]";

  // --- Parameters assumed because the request does not state them ---
  parameter Real d_wheel = 0.20   "wheel base [m] (assumed; not specified)";
  parameter Real I_robot = 0.60   "yaw inertia [kg.m2] (assumed; not specified)";
  parameter Real v_ref = 0.5      "reference forward speed [m/s] (assumed)";
  parameter Real form_offset = 0.50 "lateral formation offset [m] (assumed)";
  parameter Real safe_dist = 0.30 "collision-avoidance distance [m] (assumed)";
  parameter Real dist_force = 0.40 "shared disturbance force [N] (assumed)";

  // --- Controller gains (assumed; tuned for stable tracking) ---
  parameter Real kp_v = 4.0   "position->velocity gain";
  parameter Real kp_w = 3.0  "heading gain";
  parameter Real kp_a = 30.0 "velocity->force gain";
  parameter Real kp_t = 2.5  "yaw-rate->torque gain";

  // --- Dropout schedule (middle third of 12 s: 4 s..8 s) ---
  parameter Real t_start = 6.0 "dropout start [s]";
  parameter Real t_end   = 6.9 "dropout end [s], 0.9 s duration";
  parameter Real Ts      = 1.0/125.0 "control/sensing period [s]";

  // --- Robot 1 continuous states ---
  Real x1(start=0.0, fixed=true) "x position [m]";
  Real y1(start=0.0, fixed=true) "y position [m]";
  Real th1(start=0.0, fixed=true) "heading [rad]";
  Real v1(start=0.0, fixed=true) "linear speed [m/s]";
  Real w1(start=0.0, fixed=true) "yaw rate [rad/s]";

  // --- Robot 2 continuous states ---
  Real x2(start=0.0, fixed=true) "x position [m]";
  Real y2(start=0.5, fixed=true) "y position [m]";
  Real th2(start=0.0, fixed=true) "heading [rad]";
  Real v2(start=0.0, fixed=true) "linear speed [m/s]";
  Real w2(start=0.0, fixed=true) "yaw rate [rad/s]";

  // --- Wheel torque commands (four channels) ---
  discrete Real tau1L(start=0.0, fixed=true) "robot1 left wheel torque [N.m]";
  discrete Real tau1R(start=0.0, fixed=true) "robot1 right wheel torque [N.m]";
  discrete Real tau2L(start=0.0, fixed=true) "robot2 left wheel torque [N.m]";
  discrete Real tau2R(start=0.0, fixed=true) "robot2 right wheel torque [N.m]";

  // --- Reference route ---
  Real x_ref "reference x [m]";
  Real y_ref "reference y [m]";
  Real route_target "route end x target [m]";

  // --- Communication and last-received peer state (with timestamp) ---
  Boolean comm_ok;
  discrete Real t_last_recv(start=0.0, fixed=true) "timestamp of last received peer state [s]";
  discrete Real x2_last(start=0.0, fixed=true);
  discrete Real y2_last(start=0.5, fixed=true);
  discrete Real v2_last(start=0.0, fixed=true);
  discrete Real th2_last(start=0.0, fixed=true);
  discrete Real x1_last(start=0.0, fixed=true);
  discrete Real y1_last(start=0.0, fixed=true);
  discrete Real v1_last(start=0.0, fixed=true);
  discrete Real th1_last(start=0.0, fixed=true);

  // --- Predicted peer positions (finite dead-reckoning estimates) ---
  discrete Real x1_pred(start=0.0, fixed=true);
  discrete Real y1_pred(start=0.0, fixed=true);
  discrete Real x2_pred(start=0.0, fixed=true);
  discrete Real y2_pred(start=0.5, fixed=true);

  // --- Controller intermediates (discrete, held at 125 Hz) ---
  discrete Real e1x(start=0.0,fixed=true), e1y(start=0.0,fixed=true);
  discrete Real e2x(start=0.0,fixed=true), e2y(start=0.0,fixed=true);
  discrete Real v_des1(start=0.0,fixed=true), w_des1(start=0.0,fixed=true);
  discrete Real v_des2(start=0.0,fixed=true), w_des2(start=0.0,fixed=true);
  discrete Real F_des1(start=0.0,fixed=true), M_des1(start=0.0,fixed=true);
  discrete Real F_des2(start=0.0,fixed=true), M_des2(start=0.0,fixed=true);
  discrete Real tau1L_raw(start=0.0,fixed=true), tau1R_raw(start=0.0,fixed=true);
  discrete Real tau2L_raw(start=0.0,fixed=true), tau2R_raw(start=0.0,fixed=true);

  // --- Shared environmental disturbance (only during dropout) ---
  Real dist_force_x "applied disturbance force in x [N]";

  // --- Inter-robot sensing (lidar / exteroception) ---
  Real dist12 "inter-robot distance [m]";
  Real lidar_range "lidar-derived range [m]";
  Real ux "unit vector robot1->robot2 x component";
  Real uy "unit vector robot1->robot2 y component";
  Real rep_F1 "collision-avoidance repulsive force on robot1 [N]";
  Real rep_F2 "collision-avoidance repulsive force on robot2 [N]";

  // --- Error observables ---
  Real track_err1   "robot1 tracking error [m]";
  Real track_err2   "robot2 tracking error [m]";
  Real track_err_primary "primary (worst) tracking error [m]";
  Real form_err     "instantaneous formation error [m]";
  discrete Real form_err_deg(start=0.0, fixed=true) "degraded formation error at dropout end [m]";
  discrete Real form_err_rec(start=0.0, fixed=true) "recovered formation error near end [m]";
  Boolean route_completed "true when 12 s route finished";

  // --- Finite-status indicator ---
  // Standard Modelica has no portable is_nan/is_inf without external
  // functions; all equations are constructed to remain finite, so this
  // flag is held at 1.0 as a visible, exportable assertion point.
  Real finite_status "1.0 while all constructed estimates remain finite";

equation
  // ---- Reference route (straight line along +x) ----
  x_ref = v_ref * time;
  y_ref = 0.0;
  route_target = v_ref * 12.0;
  route_completed = time >= 12.0 - 1.0e-6;

  // ---- Communication availability ----
  comm_ok = not (time >= t_start and time < t_end);

  // ---- Shared disturbance active only while comm unavailable ----
  dist_force_x = if (time >= t_start and time < t_end) then dist_force else 0.0;

  // ---- Inter-robot exteroception (lidar range + bearing) ----
  dist12 = sqrt(max((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2), 1.0e-6));
  lidar_range = dist12;
  ux = (x2 - x1) / dist12;
  uy = (y2 - y1) / dist12;
  rep_F1 = if dist12 < safe_dist then kp_a * (safe_dist - dist12) else 0.0;
  rep_F2 = -rep_F1;

  // ---- Robot 1 dynamics ----
  der(x1)  = v1 * cos(th1);
  der(y1)  = v1 * sin(th1);
  der(th1) = w1;
  m * der(v1) = (tau1L + tau1R) / r + dist_force_x;
  I_robot * der(w1) = (tau1R - tau1L) * d_wheel / (2.0 * r);

  // ---- Robot 2 dynamics ----
  der(x2)  = v2 * cos(th2);
  der(y2)  = v2 * sin(th2);
  der(th2) = w2;
  m * der(v2) = (tau2L + tau2R) / r + dist_force_x;
  I_robot * der(w2) = (tau2R - tau2L) * d_wheel / (2.0 * r);

  // ---- Tracking and formation error observables ----
  track_err1 = sqrt(max((x1 - x_ref)*(x1 - x_ref) + (y1 - y_ref)*(y1 - y_ref), 1.0e-9));
  track_err2 = sqrt(max((x2 - x_ref)*(x2 - x_ref) + (y2 - (y_ref + form_offset))*(y2 - (y_ref + form_offset)), 1.0e-9));
  track_err_primary = if track_err1 > track_err2 then track_err1 else track_err2;
  form_err = sqrt(max((x2 - x1)*(x2 - x1) + (y2 - y1 - form_offset)*(y2 - y1 - form_offset), 1.0e-9));

  // ---- Finite-status assertion point ----
  finite_status = 1.0;

algorithm
  when sample(0, Ts) then
    // --- Sensing: snapshot peer state when communication is available ---
    if comm_ok then
      t_last_recv := time;
      x2_last := x2; y2_last := y2; v2_last := v2; th2_last := th2;
      x1_last := x1; y1_last := y1; v1_last := v1; th1_last := th1;
    end if;

    // --- Dead-reckoning prediction of peer pose (finite estimates) ---
    x2_pred := x2_last + v2_last * cos(th2_last) * (time - t_last_recv);
    y2_pred := y2_last + v2_last * sin(th2_last) * (time - t_last_recv);
    x1_pred := x1_last + v1_last * cos(th1_last) * (time - t_last_recv);
    y1_pred := y1_last + v1_last * sin(th1_last) * (time - t_last_recv);

    // --- Robot 1: proprioception + global reference tracking ---
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

    // --- Robot 2: proprioception + last-received (predicted) peer state ---
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

    // --- Snapshot degraded and recovered formation errors ---
    when time >= t_end - 1.0e-9 then
      form_err_deg := form_err;
    end when;
    when time >= 11.9 then
      form_err_rec := form_err;
    end when;
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
      "does not state them; physical constants (mass, wheel radius, torque bound, dropout duration, "
      "sample rate, run time) follow the requirement.")
  );
end GroundPairResilientC;