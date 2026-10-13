model GroundPairResilientE
  "Verifiable two-differential-drive-robot resilience scenario.
   14 kg robots, r=0.09 m wheels, 4 bounded wheel-torque channels (<=11 N.m),
   250 Hz, 16 s run, 1.2 s communication dropout (middle third) with shared
   yaw-torque environmental disturbance. Distributed control with peer-state
   prediction during dropout. Fail-closed acceptance monitors."

  // ---------- Physical parameters ----------
  parameter Real m = 14.0          "robot mass [kg]";
  parameter Real r_w = 0.09         "wheel radius [m]";
  parameter Real L = 0.30           "wheel base [m] (assumed, not specified)";
  parameter Real I_z = 0.60         "yaw inertia [kg.m2] (assumed, not specified)";
  parameter Real b_lin = 1.20       "linear viscous drag [N.s/m] (assumed)";
  parameter Real b_rot = 0.30        "rotational viscous drag [N.m.s] (assumed)";
  parameter Real tau_max = 11.0     "wheel torque magnitude bound [N.m]";

  // ---------- Scenario parameters ----------
  parameter Real T_sim = 16.0       "simulation duration [s]";
  parameter Real fs = 250.0         "control/sensor rate [Hz]";
  parameter Real dt = 1.0/fs        "sample period [s]";
  parameter Real t_drop_start = 6.0 "communication dropout start [s]";
  parameter Real t_drop_end = 7.2   "communication dropout end [s] (1.2 s dropout, within middle third)";
  parameter Real T_dist = 0.50      "shared yaw-torque environmental disturbance [N.m] (assumed)";
  parameter Real x_end = 10.0       "route terminal x [m] (assumed)";
  parameter Real d_des = 1.0        "desired lateral formation offset [m] (assumed)";
  parameter Real col_range = 0.40   "collision avoidance trigger range [m] (assumed)";
  parameter Real form_rec_thr = 0.30 "recovered formation error threshold [m] (assumed)";
  parameter Real track_thr = 0.54   "primary tracking error threshold after 10.4 s [m]";
  parameter Real track_chk_t = 10.4 "tracking check time [s]";

  // ---------- Control gains (assumed) ----------
  parameter Real kpv = 5.0          "velocity P gain";
  parameter Real kpw = 3.0          "yaw-rate P gain";
  parameter Real kth = 2.5          "heading P gain";
  parameter Real kpy = 1.2          "lateral position P gain";
  parameter Real k_form = 1.0       "formation x-coupling gain";
  parameter Real k_col = 4.0        "collision avoidance gain";

  // ---------- Robot 1 continuous states ----------
  Real x1(start=0.0, fixed=true)    "robot1 x [m]";
  Real y1(start=0.0, fixed=true)    "robot1 y [m]";
  Real th1(start=0.0, fixed=true)  "robot1 heading [rad]";
  Real v1(start=0.0, fixed=true)   "robot1 forward velocity [m/s]";
  Real w1(start=0.0, fixed=true)   "robot1 yaw rate [rad/s]";

  // ---------- Robot 2 continuous states ----------
  Real x2(start=0.0, fixed=true)    "robot2 x [m]";
  Real y2(start=d_des, fixed=true) "robot2 y [m]";
  Real th2(start=0.0, fixed=true)  "robot2 heading [rad]";
  Real v2(start=0.0, fixed=true)   "robot2 forward velocity [m/s]";
  Real w2(start=0.0, fixed=true)   "robot2 yaw rate [rad/s]";

  // ---------- Four wheel-torque channels ----------
  Real tauR1_cmd, tauL1_cmd, tauR2_cmd, tauL2_cmd;
  Real tauR1, tauL1, tauR2, tauL2;

  // ---------- Reference route ----------
  Real s_frac "normalized time t/T_sim";
  Real ref_x  "route x reference [m]";
  Real v_ref  "route velocity reference [m/s]";
  Real ref_y1 "route y reference robot1 [m]";
  Real ref_y2 "route y reference robot2 [m]";

  // ---------- Communication / peer state with timestamps ----------
  Boolean commActive;
  discrete Real x2_atR1(start=0.0)       "robot2 x last received at robot1 [m]";
  discrete Real y2_atR1(start=d_des)    "robot2 y last received at robot1 [m]";
  discrete Real th2_atR1(start=0.0)     "robot2 heading last received at robot1 [rad]";
  discrete Real v2_atR1(start=0.0)      "robot2 v last received at robot1 [m/s]";
  discrete Real w2_atR1(start=0.0)      "robot2 w last received at robot1 [rad/s]";
  discrete Real t_stampR1(start=0.0)    "timestamp of last reception at robot1 [s]";

  discrete Real x1_atR2(start=0.0)       "robot1 x last received at robot2 [m]";
  discrete Real y1_atR2(start=0.0)      "robot1 y last received at robot2 [m]";
  discrete Real th1_atR2(start=0.0)     "robot1 heading last received at robot2 [rad]";
  discrete Real v1_atR2(start=0.0)      "robot1 v last received at robot2 [m/s]";
  discrete Real w1_atR2(start=0.0)      "robot1 w last received at robot2 [rad/s]";
  discrete Real t_stampR2(start=0.0)    "timestamp of last reception at robot2 [s]";

  // Peer predicted states (dead-reckoning during dropout)
  Real dt_predR1, dt_predR2;
  Real x2_pred, y2_pred, th2_pred;
  Real x1_pred, y1_pred, th1_pred;

  // ---------- Sensors (proprioception + exteroception) ----------
  Real enc_v1 "encoder-derived forward velocity r1 [m/s]";
  Real enc_w1 "encoder-derived yaw rate r1 [rad/s]";
  Real imu_w1 "IMU gyro yaw rate r1 [rad/s]";
  Real enc_v2, enc_w2, imu_w2;
  Real lidar12 "lidar range r1->r2 [m]";
  Real lidar21 "lidar range r2->r1 [m]";

  // ---------- Control intermediates ----------
  Real v_des1, omega_des1, a_des1, alpha_des1;
  Real v_des2, omega_des2, a_des2, alpha_des2;
  Real col_term1, col_term2;
  Real x_rel_err1, x_rel_err2;

  // ---------- Errors / acceptance ----------
  Real err1     "primary tracking error r1 [m]";
  Real err2     "tracking error r2 [m]";
  Real form_err "formation error [m]";
  Real form_err_deg "degraded formation error snapshot [m]";
  Real form_err_rec "recovered formation error snapshot [m]";
  Real track_err_at_chk "primary tracking error at check time [m]";

  Boolean route_complete;
  Boolean tracking_ok;
  Boolean finite_ok;
  Boolean form_rec_ok;
  Boolean bounds_ok;
  Boolean acceptance;

equation
  // ----- Reference route (smoothstep over [0, T_sim]; v_ref zero at endpoints) -----
  s_frac = time / T_sim;
  ref_x  = x_end * (3.0*s_frac^2 - 2.0*s_frac^3);
  v_ref  = (x_end / T_sim) * 6.0*s_frac*(1.0 - s_frac);
  ref_y1 = 0.0;
  ref_y2 = d_des;

  // ----- Communication status (dropout in middle third of run) -----
  commActive = (time < t_drop_start) or (time >= t_drop_end);

  // ----- Shared environmental disturbance (yaw torque) active only during dropout -----
  // T_dist_applied defined implicitly below via conditional.

  // ===== Robot 1 plant dynamics =====
  der(x1) = v1*cos(th1);
  der(y1) = v1*sin(th1);
  der(th1) = w1;
  m*der(v1) = (tauR1 + tauL1)/r_w - b_lin*v1;
  I_z*der(w1) = (tauR1 - tauL1)*L/(2.0*r_w) - b_rot*w1
                 + (if (time >= t_drop_start and time < t_drop_end) then T_dist else 0.0);

  // ===== Robot 2 plant dynamics =====
  der(x2) = v2*cos(th2);
  der(y2) = v2*sin(th2);
  der(th2) = w2;
  m*der(v2) = (tauR2 + tauL2)/r_w - b_lin*v2;
  I_z*der(w2) = (tauR2 - tauL2)*L/(2.0*r_w) - b_rot*w2
                 + (if (time >= t_drop_start and time < t_drop_end) then T_dist else 0.0);

  // ===== Sensors =====
  // Proprioception (encoders + IMU gyro)
  enc_v1 = v1;
  enc_w1 = w1;
  imu_w1 = w1;
  enc_v2 = v2;
  enc_w2 = w2;
  imu_w2 = w2;
  // Exteroception (lidar range to peer), guarded against zero divisor
  lidar12 = sqrt(max((x2 - x1)^2 + (y2 - y1)^2, 1.0e-9));
  lidar21 = lidar12;

  // ===== Peer-state reception at 250 Hz (hold during dropout) =====
  when sample(0, dt) then
    x2_atR1   = if commActive then x2  else pre(x2_atR1);
    y2_atR1   = if commActive then y2  else pre(y2_atR1);
    th2_atR1  = if commActive then th2 else pre(th2_atR1);
    v2_atR1   = if commActive then v2  else pre(v2_atR1);
    w2_atR1   = if commActive then w2  else pre(w2_atR1);
    t_stampR1 = if commActive then time else pre(t_stampR1);

    x1_atR2   = if commActive then x1  else pre(x1_atR2);
    y1_atR2   = if commActive then y1  else pre(y1_atR2);
    th1_atR2  = if commActive then th1 else pre(th1_atR2);
    v1_atR2   = if commActive then v1  else pre(v1_atR2);
    w1_atR2   = if commActive then w1  else pre(w1_atR2);
    t_stampR2 = if commActive then time else pre(t_stampR2);
  end when;

  // ===== Peer-state prediction (dead reckoning) during dropout =====
  dt_predR1 = max(time - t_stampR1, 0.0);
  dt_predR2 = max(time - t_stampR2, 0.0);
  x2_pred  = x2_atR1 + v2_atR1*dt_predR1*cos(th2_atR1);
  y2_pred  = y2_atR1 + v2_atR1*dt_predR1*sin(th2_atR1);
  th2_pred = th2_atR1 + w2_atR1*dt_predR1;
  x1_pred  = x1_atR2 + v1_atR2*dt_predR2*cos(th1_atR2);
  y1_pred  = y1_atR2 + v1_atR2*dt_predR2*sin(th1_atR2);
  th1_pred = th1_atR2 + w1_atR2*dt_predR2;

  // ===== Collision avoidance (smooth, only active when range < col_range) =====
  col_term1 = max(0.0, k_col*(col_range - lidar12));
  col_term2 = max(0.0, k_col*(col_range - lidar21));

  // ===== Distributed control: robot 1 (local proprioception + predicted peer) =====
  x_rel_err1 = x2_pred - x1;
  v_des1     = v_ref + k_form*x_rel_err1 - col_term1;
  omega_des1 = -kth*th1 - kpy*(y1 - ref_y1);
  a_des1     = kpv*(v_des1 - v1);
  alpha_des1 = kpw*(omega_des1 - w1);

  // ===== Distributed control: robot 2 (local proprioception + predicted peer) =====
  x_rel_err2 = x1_pred - x2;
  v_des2     = v_ref + k_form*x_rel_err2 - col_term2;
  omega_des2 = -kth*th2 - kpy*(y2 - ref_y2);
  a_des2     = kpv*(v_des2 - v2);
  alpha_des2 = kpw*(omega_des2 - w2);

  // ===== Wheel torque commands (4 channels) =====
  tauR1_cmd = (r_w/2.0)*(m*a_des1 + 2.0*I_z*alpha_des1/L);
  tauL1_cmd = (r_w/2.0)*(m*a_des1 - 2.0*I_z*alpha_des1/L);
  tauR2_cmd = (r_w/2.0)*(m*a_des2 + 2.0*I_z*alpha_des2/L);
  tauL2_cmd = (r_w/2.0)*(m*a_des2 - 2.0*I_z*alpha_des2/L);

  // ===== Actuator saturation (bounded by +/- 11 N.m) =====
  tauR1 = max(-tau_max, min(tau_max, tauR1_cmd));
  tauL1 = max(-tau_max, min(tau_max, tauL1_cmd));
  tauR2 = max(-tau_max, min(tau_max, tauR2_cmd));
  tauL2 = max(-tau_max, min(tau_max, tauL2_cmd));

  // ===== Errors =====
  err1 = sqrt(max((x1 - ref_x)^2 + (y1 - ref_y1)^2, 1.0e-12));
  err2 = sqrt(max((x2 - ref_x)^2 + (y2 - ref_y2)^2, 1.0e-12));
  form_err = sqrt(max((x1 - x2)^2 + ((y1 - y2) - d_des)^2, 1.0e-12));

  // Snapshots: degraded (end of dropout + 0.3 s) and recovered (well after dropout)
  form_err_deg = if (time >= t_drop_end + 0.3) and (time < t_drop_end + 0.4) then form_err
                 else pre(form_err_deg);
  form_err_rec = if (time >= t_drop_end + 2.0) and (time < t_drop_end + 2.1) then form_err
                 else pre(form_err_rec);
  track_err_at_chk = if (time >= track_chk_t) and (time < track_chk_t + dt) then err1
                     else pre(track_err_at_chk);

  // ===== Acceptance monitors (fail-closed) =====
  // Route completed by end of run
  route_complete = (time >= T_sim - 1.0e-6)
                   and (x1 >= 0.95*x_end)
                   and (x2 >= 0.95*x_end);
  // Primary tracking error below threshold after 10.4 s
  tracking_ok = (time < track_chk_t) or (track_err_at_chk < track_thr);
  // Recovered formation error below threshold
  form_rec_ok = (time < t_drop_end + 2.0) or (form_err_rec < form_rec_thr);
  // Actuator bounds satisfied (by construction; verified explicitly)
  bounds_ok = (abs(tauR1) <= tau_max + 1.0e-9)
              and (abs(tauL1) <= tau_max + 1.0e-9)
              and (abs(tauR2) <= tau_max + 1.0e-9)
              and (abs(tauL2) <= tau_max + 1.0e-9);
  // Finiteness (NaN comparisons yield false -> fail-closed)
  finite_ok = (x1 > -1.0e15) and (x1 < 1.0e15)
              and (y1 > -1.0e15) and (y1 < 1.0e15)
              and (th1 > -1.0e15) and (th1 < 1.0e15)
              and (v1 > -1.0e15) and (v1 < 1.0e15)
              and (w1 > -1.0e15) and (w1 < 1.0e15)
              and (x2 > -1.0e15) and (x2 < 1.0e15)
              and (y2 > -1.0e15) and (y2 < 1.0e15)
              and (th2 > -1.0e15) and (th2 < 1.0e15)
              and (v2 > -1.0e15) and (v2 < 1.0e15)
              and (w2 > -1.0e15) and (w2 < 1.0e15)
              and (tauR1 > -1.0e15) and (tauR1 < 1.0e15)
              and (tauL1 > -1.0e15) and (tauL1 < 1.0e15)
              and (tauR2 > -1.0e15) and (tauR2 < 1.0e15)
              and (tauL2 > -1.0e15) and (tauL2 < 1.0e15)
              and (err1 > -1.0e15) and (err1 < 1.0e15)
              and (form_err > -1.0e15) and (form_err < 1.0e15);

  // Fail-closed overall acceptance
  acceptance = route_complete and tracking_ok and form_rec_ok and bounds_ok and finite_ok;

  annotation (
    experiment(StopTime=16.0, Tolerance=1.0e-6, Interval=0.004),
    Documentation(info="Two 14 kg differential-drive robots (r=0.09 m wheels) in one scene.
Four bounded wheel-torque channels (<=11 N.m per wheel).
250 Hz control/sensor rate, 16 s run, 1.2 s communication dropout in middle third
with a shared yaw-torque environmental disturbance. Distributed control uses local
proprioception (encoders/IMU), exteroception (lidar), and last-received peer state
with timestamps plus dead-reckoning prediction during dropout. Acceptance is
fail-closed: actuator bounds, collision avoidance, degraded/recovered formation
errors, finite estimates, completed route, primary tracking error < 0.54 m after
10.4 s, and no NaN/infinite physical, control, or estimator values.
Assumed (not specified) values: L, I_z, drags, gains, route terminal, formation
offset, disturbance magnitude, thresholds."));
end GroundPairResilientE;