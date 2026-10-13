model GroundTrioResilientD
  // ===== Requirement-grounded constants =====
  parameter Real m_robot(unit="kg") = 18.0 "robot mass";
  parameter Real tau_max(unit="N.m") = 12.0 "wheel torque bound";
  parameter Real Ts(unit="s") = 0.005 "control/sample period (200 Hz)";
  parameter Real T_end(unit="s") = 14.0 "horizon";
  parameter Real t_dropout_start(unit="s") = 14.0/3.0 "middle-third begin";
  parameter Real t_dropout_end(unit="s") = 2.0*14.0/3.0 "middle-third end";
  parameter Real t_dist_start(unit="s") = 5.0 "1 s shared disturbance begin";
  parameter Real t_dist_end(unit="s") = 6.0 "1 s shared disturbance end";

  // ===== Assumed physical/scene parameters (NOT from requirement) =====
  parameter Real r_wheel(unit="m") = 0.10 "ASSUMED: wheel radius (unknown)";
  parameter Real wheelbase(unit="m") = 0.40 "ASSUMED: axle length (unknown)";
  parameter Real I_robot(unit="kg.m2") = 0.50 "ASSUMED: yaw inertia (unknown)";
  parameter Real b_drag(unit="N.s/m") = 0.50 "ASSUMED: linear drag (unknown)";
  parameter Real v_ref(unit="m/s") = 1.0 "ASSUMED: route speed (unknown)";
  parameter Real L_route(unit="m") = 12.0 "ASSUMED: route length (unknown)";
  parameter Real y_off1(unit="m") = -0.50 "ASSUMED: R1 lateral offset (unknown)";
  parameter Real y_off2(unit="m") = 0.0 "ASSUMED: R2 lateral offset (unknown)";
  parameter Real y_off3(unit="m") = 0.50 "ASSUMED: R3 lateral offset (unknown)";
  parameter Real F_dist(unit="N") = 6.0 "ASSUMED: shared disturbance magnitude (unknown)";
  parameter Real Kp_v = 25.0 "ASSUMED: velocity P gain (unknown)";
  parameter Real Kp_x = 6.0 "ASSUMED: position P gain (unknown)";
  parameter Real Kp_th = 8.0 "ASSUMED: heading P gain (unknown)";
  parameter Real Kd_w = 5.0 "ASSUMED: heading D gain (unknown)";
  parameter Real F_coll(unit="N") = 50.0 "ASSUMED: collision avoidance gain (unknown)";
  parameter Real d_safe(unit="m") = 0.30 "ASSUMED: collision safe distance (unknown)";
  parameter Real eps = 1.0e-6 "regularization for norms/divisors";

  // ===== Observables =====
  Boolean comm_ok "communication available flag";
  Boolean dist_active "shared disturbance active flag";
  Boolean route_done "leader completed route";
  Real F_shared(unit="N") "applied shared environmental disturbance";
  Real e_primary(unit="m") "primary (leader R2) tracking error";
  Real e_form1(unit="m") "degraded/recovered formation error of R1 vs R2";
  Real e_form3(unit="m") "degraded/recovered formation error of R3 vs R2";

  // ===== Pairwise exteroception distances =====
  Real d12, d13, d23;

  // ===== Robot 1 (follower, lateral offset y_off1) =====
  Real x1(start=0.0, unit="m"), y1(start=y_off1, unit="m"), th1(start=0.0, unit="rad");
  Real v1(start=0.0, unit="m/s"), w1(start=0.0, unit="rad/s");
  Real tauR1, tauL1, tauR1s, tauL1s;
  Real F1_cmd, M1_cmd, F1_act, M1_act;
  Real e1x, e1y, e1th;
  Real rep1x, rep1y, F_rep1, M_rep1;
  // last-received peer state (R2,R3) with timestamps (held during dropout)
  Real x2_l1(start=0.0), y2_l1(start=0.0), th2_l1(start=0.0), v2_l1(start=0.0), t2_l1(start=0.0);
  Real x3_l1(start=0.0), y3_l1(start=y_off3), th3_l1(start=0.0), v3_l1(start=0.0), t3_l1(start=0.0);
  // predicted peer poses used by R1 control
  Real x2p1, y2p1, x3p1, y3p1;

  // ===== Robot 2 (leader) =====
  Real x2(start=0.0, unit="m"), y2(start=y_off2, unit="m"), th2(start=0.0, unit="rad");
  Real v2(start=0.0, unit="m/s"), w2(start=0.0, unit="rad/s");
  Real tauR2, tauL2, tauR2s, tauL2s;
  Real F2_cmd, M2_cmd, F2_act, M2_act;
  Real e2x, e2y, e2th;
  Real x_ref2, y_ref2, th_ref2;
  Real rep2x, rep2y, F_rep2, M_rep2;
  Real x1_l2(start=0.0), y1_l2(start=y_off1), th1_l2(start=0.0), v1_l2(start=0.0), t1_l2(start=0.0);
  Real x3_l2(start=0.0), y3_l2(start=y_off3), th3_l2(start=0.0), v3_l2(start=0.0), t3_l2(start=0.0);
  Real x1p2, y1p2, x3p2, y3p2;

  // ===== Robot 3 (follower, lateral offset y_off3) =====
  Real x3(start=0.0, unit="m"), y3(start=y_off3, unit="m"), th3(start=0.0, unit="rad");
  Real v3(start=0.0, unit="m/s"), w3(start=0.0, unit="rad/s");
  Real tauR3, tauL3, tauR3s, tauL3s;
  Real F3_cmd, M3_cmd, F3_act, M3_act;
  Real e3x, e3y, e3th;
  Real rep3x, rep3y, F_rep3, M_rep3;
  Real x1_l3(start=0.0), y1_l3(start=y_off1), th1_l3(start=0.0), v1_l3(start=0.0), t1_l3(start=0.0);
  Real x2_l3(start=0.0), y2_l3(start=0.0), th2_l3(start=0.0), v2_l3(start=0.0), t2_l3(start=0.0);
  Real x1p3, y1p3, x2p3, y2p3;

equation
  // ===== Communication & shared disturbance =====
  comm_ok = not (time >= t_dropout_start and time < t_dropout_end);
  dist_active = time >= t_dist_start and time < t_dist_end;
  F_shared = if dist_active then F_dist else 0.0;

  // ===== Leader route reference (completed within horizon) =====
  x_ref2 = min(v_ref*time, L_route);
  y_ref2 = 0.0;
  th_ref2 = 0.0;
  route_done = x2 >= L_route - 1.0e-3;

  // ===== Pairwise distances (lidar exteroception) =====
  d12 = sqrt((x1-x2)^2 + (y1-y2)^2 + eps);
  d13 = sqrt((x1-x3)^2 + (y1-y3)^2 + eps);
  d23 = sqrt((x2-x3)^2 + (y2-y3)^2 + eps);

  // ===== R1 last-received peer state with timestamp (frozen during dropout) =====
  der(x2_l1)  = if comm_ok then der(x2)  else 0.0;
  der(y2_l1)  = if comm_ok then der(y2)  else 0.0;
  der(th2_l1) = if comm_ok then der(th2) else 0.0;
  der(v2_l1)  = if comm_ok then der(v2)  else 0.0;
  der(t2_l1)  = if comm_ok then 1.0       else 0.0;
  der(x3_l1)  = if comm_ok then der(x3)  else 0.0;
  der(y3_l1)  = if comm_ok then der(y3)  else 0.0;
  der(th3_l1) = if comm_ok then der(th3) else 0.0;
  der(v3_l1)  = if comm_ok then der(v3)  else 0.0;
  der(t3_l1)  = if comm_ok then 1.0       else 0.0;
  // R1 predictions of peers (constant-velocity propagation from last-received state)
  x2p1 = x2_l1 + v2_l1*cos(th2_l1)*(time - t2_l1);
  y2p1 = y2_l1 + v2_l1*sin(th2_l1)*(time - t2_l1);
  x3p1 = x3_l1 + v3_l1*cos(th3_l1)*(time - t3_l1);
  y3p1 = y3_l1 + v3_l1*sin(th3_l1)*(time - t3_l1);

  // ===== R2 last-received peer state with timestamp =====
  der(x1_l2)  = if comm_ok then der(x1)  else 0.0;
  der(y1_l2)  = if comm_ok then der(y1)  else 0.0;
  der(th1_l2) = if comm_ok then der(th1) else 0.0;
  der(v1_l2)  = if comm_ok then der(v1)  else 0.0;
  der(t1_l2)  = if comm_ok then 1.0       else 0.0;
  der(x3_l2)  = if comm_ok then der(x3)  else 0.0;
  der(y3_l2)  = if comm_ok then der(y3)  else 0.0;
  der(th3_l2) = if comm_ok then der(th3) else 0.0;
  der(v3_l2)  = if comm_ok then der(v3)  else 0.0;
  der(t3_l2)  = if comm_ok then 1.0       else 0.0;
  x1p2 = x1_l2 + v1_l2*cos(th1_l2)*(time - t1_l2);
  y1p2 = y1_l2 + v1_l2*sin(th1_l2)*(time - t1_l2);
  x3p2 = x3_l2 + v3_l2*cos(th3_l2)*(time - t3_l2);
  y3p2 = y3_l2 + v3_l2*sin(th3_l2)*(time - t3_l2);

  // ===== R3 last-received peer state with timestamp =====
  der(x1_l3)  = if comm_ok then der(x1)  else 0.0;
  der(y1_l3)  = if comm_ok then der(y1)  else 0.0;
  der(th1_l3) = if comm_ok then der(th1) else 0.0;
  der(v1_l3)  = if comm_ok then der(v1)  else 0.0;
  der(t1_l3)  = if comm_ok then 1.0       else 0.0;
  der(x2_l3)  = if comm_ok then der(x2)  else 0.0;
  der(y2_l3)  = if comm_ok then der(y2)  else 0.0;
  der(th2_l3) = if comm_ok then der(th2) else 0.0;
  der(v2_l3)  = if comm_ok then der(v2)  else 0.0;
  der(t2_l3)  = if comm_ok then 1.0       else 0.0;
  x1p3 = x1_l3 + v1_l3*cos(th1_l3)*(time - t1_l3);
  y1p3 = y1_l3 + v1_l3*sin(th1_l3)*(time - t1_l3);
  x2p3 = x2_l3 + v2_l3*cos(th2_l3)*(time - t2_l3);
  y2p3 = y2_l3 + v2_l3*sin(th2_l3)*(time - t2_l3);

  // ===== R1 distributed control (uses predicted peer R2) + collision avoidance =====
  e1x = x2p1 - x1;
  e1y = (y2p1 + (y_off1 - y_off2)) - y1;
  e1th = 0.0 - th1;
  rep1x = (if d12 < d_safe then F_coll*(d_safe-d12)/d12*(x1-x2) else 0.0)
        + (if d13 < d_safe then F_coll*(d_safe-d13)/d13*(x1-x3) else 0.0);
  rep1y = (if d12 < d_safe then F_coll*(d_safe-d12)/d12*(y1-y2) else 0.0)
        + (if d13 < d_safe then F_coll*(d_safe-d13)/d13*(y1-y3) else 0.0);
  F_rep1 = rep1x*cos(th1) + rep1y*sin(th1);
  M_rep1 = (-rep1x*sin(th1) + rep1y*cos(th1))*wheelbase/2;
  F1_cmd = Kp_v*(v_ref - v1) + Kp_x*e1x + F_rep1;
  M1_cmd = Kp_th*e1th - Kd_w*w1 + M_rep1;
  tauR1 = F1_cmd*r_wheel/2 + M1_cmd*r_wheel/wheelbase;
  tauL1 = F1_cmd*r_wheel/2 - M1_cmd*r_wheel/wheelbase;
  tauR1s = max(-tau_max, min(tau_max, tauR1));
  tauL1s = max(-tau_max, min(tau_max, tauL1));
  F1_act = (tauR1s + tauL1s)/r_wheel;
  M1_act = (tauR1s - tauL1s)*wheelbase/(2*r_wheel);
  der(x1) = v1*cos(th1);
  der(y1) = v1*sin(th1);
  der(th1) = w1;
  m_robot*der(v1) = F1_act - b_drag*v1 + F_shared*cos(th1);
  I_robot*der(w1) = M1_act - b_drag*w1;

  // ===== R2 leader control (local route tracking) + collision avoidance =====
  e2x = x_ref2 - x2;
  e2y = y_ref2 - y2;
  e2th = th_ref2 - th2;
  rep2x = (if d12 < d_safe then F_coll*(d_safe-d12)/d12*(x2-x1) else 0.0)
        + (if d23 < d_safe then F_coll*(d_safe-d23)/d23*(x2-x3) else 0.0);
  rep2y = (if d12 < d_safe then F_coll*(d_safe-d12)/d12*(y2-y1) else 0.0)
        + (if d23 < d_safe then F_coll*(d_safe-d23)/d23*(y2-y3) else 0.0);
  F_rep2 = rep2x*cos(th2) + rep2y*sin(th2);
  M_rep2 = (-rep2x*sin(th2) + rep2y*cos(th2))*wheelbase/2;
  F2_cmd = Kp_v*(v_ref - v2) + Kp_x*e2x + F_rep2;
  M2_cmd = Kp_th*e2th - Kd_w*w2 + M_rep2;
  tauR2 = F2_cmd*r_wheel/2 + M2_cmd*r_wheel/wheelbase;
  tauL2 = F2_cmd*r_wheel/2 - M2_cmd*r_wheel/wheelbase;
  tauR2s = max(-tau_max, min(tau_max, tauR2));
  tauL2s = max(-tau_max, min(tau_max, tauL2));
  F2_act = (tauR2s + tauL2s)/r_wheel;
  M2_act = (tauR2s - tauL2s)*wheelbase/(2*r_wheel);
  der(x2) = v2*cos(th2);
  der(y2) = v2*sin(th2);
  der(th2) = w2;
  m_robot*der(v2) = F2_act - b_drag*v2 + F_shared*cos(th2);
  I_robot*der(w2) = M2_act - b_drag*w2;

  // ===== R3 distributed control (uses predicted peer R2) + collision avoidance =====
  e3x = x2p3 - x3;
  e3y = (y2p3 + (y_off3 - y_off2)) - y3;
  e3th = 0.0 - th3;
  rep3x = (if d13 < d_safe then F_coll*(d_safe-d13)/d13*(x3-x1) else 0.0)
        + (if d23 < d_safe then F_coll*(d_safe-d23)/d23*(x3-x2) else 0.0);
  rep3y = (if d13 < d_safe then F_coll*(d_safe-d13)/d13*(y3-y1) else 0.0)
        + (if d23 < d_safe then F_coll*(d_safe-d23)/d23*(y3-y2) else 0.0);
  F_rep3 = rep3x*cos(th3) + rep3y*sin(th3);
  M_rep3 = (-rep3x*sin(th3) + rep3y*cos(th3))*wheelbase/2;
  F3_cmd = Kp_v*(v_ref - v3) + Kp_x*e3x + F_rep3;
  M3_cmd = Kp_th*e3th - Kd_w*w3 + M_rep3;
  tauR3 = F3_cmd*r_wheel/2 + M3_cmd*r_wheel/wheelbase;
  tauL3 = F3_cmd*r_wheel/2 - M3_cmd*r_wheel/wheelbase;
  tauR3s = max(-tau_max, min(tau_max, tauR3));
  tauL3s = max(-tau_max, min(tau_max, tauL3));
  F3_act = (tauR3s + tauL3s)/r_wheel;
  M3_act = (tauR3s - tauL3s)*wheelbase/(2*r_wheel);
  der(x3) = v3*cos(th3);
  der(y3) = v3*sin(th3);
  der(th3) = w3;
  m_robot*der(v3) = F3_act - b_drag*v3 + F_shared*cos(th3);
  I_robot*der(w3) = M3_act - b_drag*w3;

  // ===== Observables: degraded/recovered errors (finite, regularized) =====
  e_primary = sqrt(e2x^2 + e2y^2 + eps);
  e_form1 = sqrt((x1 - x2)^2 + (y1 - y2 - (y_off1 - y_off2))^2 + eps);
  e_form3 = sqrt((x3 - x2)^2 + (y3 - y2 - (y_off3 - y_off2))^2 + eps);

  annotation (
    Documentation(info="Three 18 kg differential-drive warehouse robots on rigid floor. "
      "Six bounded wheel drives (12 N.m). Local proprioception, lidar distances, and "
      "last-received peer state with timestamps. Distributed control with prediction "
      "during a finite communication dropout over the middle third of the 14 s run, with "
      "a controlled 1 s shared environmental disturbance applied while communication is "
      "unavailable. Primary tracking error (leader R2) required < 0.6 m after 9.1 s. "
      "Facts not stated in the requirement (wheel radius, wheelbase, inertia, drag, "
      "route speed/length, formation offsets, gains, disturbance magnitude) are labeled "
      "ASSUMED and are not derived from any example."),
    experiment(StartTime=0.0, StopTime=14.0, Tolerance=1e-6, Interval=0.005)
  );
end GroundTrioResilientD;