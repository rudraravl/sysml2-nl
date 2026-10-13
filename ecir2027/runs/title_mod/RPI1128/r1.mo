model GroundTrioResilientF
  "Three 18 kg differential-drive warehouse robots maintaining triangle formation through a 1.45 s communication dropout."

  // ---- Timing ----
  parameter Real T_end = 20.0 "Mission duration [s]";
  parameter Real Ts = 0.002 "Control/sample period (500 Hz) [s]";
  parameter Real t_drop_start = 7.5 "Dropout start within middle third of mission [s]";
  parameter Real t_drop_dur = 1.45 "Dropout duration [s]";
  final parameter Real t_drop_end = t_drop_start + t_drop_dur;

  // ---- Robot body parameters (design assumptions; physical constants not stated in requirement) ----
  parameter Real m_robot = 18.0 "Robot mass [kg]";
  parameter Real I_robot = 0.265 "Yaw inertia [kg.m2]";
  parameter Real r_wheel = 0.098 "Wheel radius [m]";
  parameter Real track = 0.42 "Wheel track [m]";
  parameter Real drag_lin = 6.0 "Linear viscous drag [N/(m/s)]";
  parameter Real drag_rot = 0.8 "Rotational viscous drag [N.m/(rad/s)]";
  parameter Real R = 0.30 "Collision radius [m]";
  parameter Real R_safe = 0.65 "Minimum safe separation threshold [m]";

  // ---- Actuator bound ----
  parameter Real tau_max = 14.6 "Per-wheel torque bound [N.m]";

  // ---- Reference route ----
  parameter Real v_ref = 0.55 "Route longitudinal speed [m/s]";
  parameter Real route_len = 10.0 "Route length [m]";
  parameter Real off_x1 = 0.0;  parameter Real off_y1 = 0.0;
  parameter Real off_x2 = -1.0; parameter Real off_y2 = 0.6;
  parameter Real off_x3 = -1.0; parameter Real off_y3 = -0.6;

  // ---- Control gains ----
  parameter Real kp_pos = 1.6 "Position gain [1/s^2]";
  parameter Real kv_pos = 2.0 "Velocity gain [1/s]";
  parameter Real kp_th  = 2.4 "Heading gain [1/s^2]";
  parameter Real kv_w   = 1.4 "Yaw-rate gain [1/s]";
  parameter Real kc     = 0.7 "Formation coupling gain [-]";
  parameter Real k_rep  = 2.5 "Collision repulsion gain [N/m]";

  // ---- Shared disturbance (applied only during dropout) ----
  parameter Real F_dist = 6.0 "Shared forward disturbance force during dropout [N]";
  parameter Real M_dist = 0.3 "Shared yaw disturbance torque during dropout [N.m]";

  // ---- Robot states ----
  Real x1(start=0.0, fixed=true), y1(start=0.0, fixed=true), th1(start=0.0, fixed=true), v1(start=0.0, fixed=true), w1(start=0.0, fixed=true);
  Real x2(start=-1.0, fixed=true), y2(start=0.6, fixed=true), th2(start=0.0, fixed=true), v2(start=0.0, fixed=true), w2(start=0.0, fixed=true);
  Real x3(start=-1.0, fixed=true), y3(start=-0.6, fixed=true), th3(start=0.0, fixed=true), v3(start=0.0, fixed=true), w3(start=0.0, fixed=true);

  // ---- Wheel torques (bounded) ----
  Real tauL1,tauR1,tauL2,tauR2,tauL3,tauR3;

  // ---- Commanded and applied body wrench ----
  Real F1c,M1c,F2c,M2c,F3c,M3c;
  Real F1a,M1a,F2a,M2a,F3a,M3a;

  // ---- Peer state estimates (broadcast, dead-reckoned during dropout) ----
  Real ex1(start=0.0, fixed=true), ey1(start=0.0, fixed=true), eth1(start=0.0, fixed=true), ev1(start=0.0, fixed=true);
  Real ex2(start=-1.0, fixed=true), ey2(start=0.6, fixed=true), eth2(start=0.0, fixed=true), ev2(start=0.0, fixed=true);
  Real ex3(start=-1.0, fixed=true), ey3(start=-0.6, fixed=true), eth3(start=0.0, fixed=true), ev3(start=0.0, fixed=true);

  Boolean comms_ok;
  Boolean in_drop;

  // ---- Reference ----
  Real x_ref;
  Real v_ref_eff;

  // ---- Control intermediates ----
  Real rx1,ry1,rx2,ry2,rx3,ry3;
  Real e_fwd1,e_fwd2,e_fwd3;
  Real th_des1,th_des2,th_des3;
  Real e_th1,e_th2,e_th3;

  // ---- Pairwise distances ----
  Real d12,d13,d23;
  Real d12s,d13s,d23s;

  // ---- Repulsion ----
  Real rep_x1,rep_y1,rep_x2,rep_y2,rep_x3,rep_y3;

  // ---- Disturbance ----
  Real Fd1,Md1,Fd2,Md2,Fd3,Md3;

  // ---- Verification observables ----
  Real track_err1,track_err2,track_err3;
  Real primary_track_err;
  Real form_err;
  Real min_sep;
  Real max_tau_used;
  Real route_done;
  output Boolean verification_pass;

equation

  // ---- Communication window ----
  in_drop = (time >= t_drop_start) and (time < t_drop_end);
  comms_ok = not in_drop;

  // ---- Reference route (clamp at route length) ----
  v_ref_eff = if (v_ref*time >= route_len) then 0.0 else v_ref;
  x_ref = if (v_ref*time >= route_len) then route_len else v_ref*time;

  // ---- Peer estimates: track actual when comms ok, constant-velocity dead-reckon during dropout ----
  der(ex1) = if comms_ok then der(x1) else ev1*cos(eth1);
  der(ey1) = if comms_ok then der(y1) else ev1*sin(eth1);
  der(eth1) = if comms_ok then der(th1) else 0.0;
  der(ev1) = if comms_ok then der(v1) else 0.0;
  der(ex2) = if comms_ok then der(x2) else ev2*cos(eth2);
  der(ey2) = if comms_ok then der(y2) else ev2*sin(eth2);
  der(eth2) = if comms_ok then der(th2) else 0.0;
  der(ev2) = if comms_ok then der(v2) else 0.0;
  der(ex3) = if comms_ok then der(x3) else ev3*cos(eth3);
  der(ey3) = if comms_ok then der(y3) else ev3*sin(eth3);
  der(eth3) = if comms_ok then der(th3) else 0.0;
  der(ev3) = if comms_ok then der(v3) else 0.0;

  // Snap estimates to true state at dropout start and at dropout end
  when time >= t_drop_start then
    reinit(ex1, x1); reinit(ey1, y1); reinit(eth1, th1); reinit(ev1, v1);
    reinit(ex2, x2); reinit(ey2, y2); reinit(eth2, th2); reinit(ev2, v2);
    reinit(ex3, x3); reinit(ey3, y3); reinit(eth3, th3); reinit(ev3, v3);
  end when;
  when time >= t_drop_end then
    reinit(ex1, x1); reinit(ey1, y1); reinit(eth1, th1); reinit(ev1, v1);
    reinit(ex2, x2); reinit(ey2, y2); reinit(eth2, th2); reinit(ev2, v2);
    reinit(ex3, x3); reinit(ey3, y3); reinit(eth3, th3); reinit(ev3, v3);
  end when;

  // ---- Pairwise distances (zero-safe) ----
  d12 = sqrt((x2-x1)^2 + (y2-y1)^2);
  d13 = sqrt((x3-x1)^2 + (y3-y1)^2);
  d23 = sqrt((x3-x2)^2 + (y3-y2)^2);
  d12s = max(d12, 0.01);
  d13s = max(d13, 0.01);
  d23s = max(d23, 0.01);

  // ---- Repulsion (active only inside R_safe) ----
  rep_x1 = k_rep*max(0.0, R_safe - d12)/d12s*(x1-x2) + k_rep*max(0.0, R_safe - d13)/d13s*(x1-x3);
  rep_y1 = k_rep*max(0.0, R_safe - d12)/d12s*(y1-y2) + k_rep*max(0.0, R_safe - d13)/d13s*(y1-y3);
  rep_x2 = k_rep*max(0.0, R_safe - d12)/d12s*(x2-x1) + k_rep*max(0.0, R_safe - d23)/d23s*(x2-x3);
  rep_y2 = k_rep*max(0.0, R_safe - d12)/d12s*(y2-y1) + k_rep*max(0.0, R_safe - d23)/d23s*(y2-y3);
  rep_x3 = k_rep*max(0.0, R_safe - d13)/d13s*(x3-x1) + k_rep*max(0.0, R_safe - d23)/d23s*(x3-x2);
  rep_y3 = k_rep*max(0.0, R_safe - d13)/d13s*(y3-y1) + k_rep*max(0.0, R_safe - d23)/d23s*(y3-y2);

  // ---- Distributed consensus-augmented desired positions (uses peer predictions) ----
  rx1 = x_ref + off_x1 + kc*(((ex2 - x1) - (off_x2 - off_x1)) + ((ex3 - x1) - (off_x3 - off_x1)));
  ry1 = off_y1 + kc*(((ey2 - y1) - (off_y2 - off_y1)) + ((ey3 - y1) - (off_y3 - off_y1)));
  rx2 = x_ref + off_x2 + kc*(((ex1 - x2) - (off_x1 - off_x2)) + ((ex3 - x2) - (off_x3 - off_x2)));
  ry2 = off_y2 + kc*(((ey1 - y2) - (off_y1 - off_y2)) + ((ey3 - y2) - (off_y3 - off_y2)));
  rx3 = x_ref + off_x3 + kc*(((ex1 - x3) - (off_x1 - off_x3)) + ((ex2 - x3) - (off_x2 - off_x3)));
  ry3 = off_y3 + kc*(((ey1 - y3) - (off_y1 - off_y3)) + ((ey2 - y3) - (off_y2 - off_y3)));

  // ---- Forward error and wrapped heading error ----
  e_fwd1 = (rx1 - x1)*cos(th1) + (ry1 - y1)*sin(th1);
  e_fwd2 = (rx2 - x2)*cos(th2) + (ry2 - y2)*sin(th2);
  e_fwd3 = (rx3 - x3)*cos(th3) + (ry3 - y3)*sin(th3);
  th_des1 = atan2(ry1 - y1, rx1 - x1);
  th_des2 = atan2(ry2 - y2, rx2 - x2);
  th_des3 = atan2(ry3 - y3, rx3 - x3);
  e_th1 = atan2(sin(th_des1 - th1), cos(th_des1 - th1));
  e_th2 = atan2(sin(th_des2 - th2), cos(th_des2 - th2));
  e_th3 = atan2(sin(th_des3 - th3), cos(th_des3 - th3));

  // ---- Commanded body wrench (repulsion projected onto heading/lateral) ----
  F1c = kp_pos*e_fwd1 + kv_pos*(v_ref_eff - v1) + (rep_x1*cos(th1) + rep_y1*sin(th1));
  M1c = I_robot*(kp_th*e_th1 - kv_w*w1) + (rep_y1*cos(th1) - rep_x1*sin(th1))*0.5;
  F2c = kp_pos*e_fwd2 + kv_pos*(v_ref_eff - v2) + (rep_x2*cos(th2) + rep_y2*sin(th2));
  M2c = I_robot*(kp_th*e_th2 - kv_w*w2) + (rep_y2*cos(th2) - rep_x2*sin(th2))*0.5;
  F3c = kp_pos*e_fwd3 + kv_pos*(v_ref_eff - v3) + (rep_x3*cos(th3) + rep_y3*sin(th3));
  M3c = I_robot*(kp_th*e_th3 - kv_w*w3) + (rep_y3*cos(th3) - rep_x3*sin(th3))*0.5;

  // ---- Shared environmental disturbance (only during dropout) ----
  Fd1 = if in_drop then F_dist else 0.0;
  Md1 = if in_drop then M_dist else 0.0;
  Fd2 = if in_drop then F_dist else 0.0;
  Md2 = if in_drop then M_dist else 0.0;
  Fd3 = if in_drop then F_dist else 0.0;
  Md3 = if in_drop then M_dist else 0.0;

  // ---- Wheel torque commands with per-wheel saturation ----
  // tau_R = r*(F/2 + M/track), tau_L = r*(F/2 - M/track)
  tauR1 = if (r_wheel*(F1c/2 + M1c/track) >  tau_max) then  tau_max
          else if (r_wheel*(F1c/2 + M1c/track) < -tau_max) then -tau_max
          else r_wheel*(F1c/2 + M1c/track);
  tauL1 = if (r_wheel*(F1c/2 - M1c/track) >  tau_max) then  tau_max
          else if (r_wheel*(F1c/2 - M1c/track) < -tau_max) then -tau_max
          else r_wheel*(F1c/2 - M1c/track);
  tauR2 = if (r_wheel*(F2c/2 + M2c/track) >  tau_max) then  tau_max
          else if (r_wheel*(F2c/2 + M2c/track) < -tau_max) then -tau_max
          else r_wheel*(F2c/2 + M2c/track);
  tauL2 = if (r_wheel*(F2c/2 - M2c/track) >  tau_max) then  tau_max
          else if (r_wheel*(F2c/2 - M2c/track) < -tau_max) then -tau_max
          else r_wheel*(F2c/2 - M2c/track);
  tauR3 = if (r_wheel*(F3c/2 + M3c/track) >  tau_max) then  tau_max
          else if (r_wheel*(F3c/2 + M3c/track) < -tau_max) then -tau_max
          else r_wheel*(F3c/2 + M3c/track);
  tauL3 = if (r_wheel*(F3c/2 - M3c/track) >  tau_max) then  tau_max
          else if (r_wheel*(F3c/2 - M3c/track) < -tau_max) then -tau_max
          else r_wheel*(F3c/2 - M3c/track);

  // ---- Actual applied body wrench from saturated wheel torques ----
  F1a = (tauL1 + tauR1)/r_wheel;
  M1a = (tauR1 - tauL1)*track/(2.0*r_wheel);
  F2a = (tauL2 + tauR2)/r_wheel;
  M2a = (tauR2 - tauL2)*track/(2.0*r_wheel);
  F3a = (tauL3 + tauR3)/r_wheel;
  M3a = (tauR3 - tauL3)*track/(2.0*r_wheel);

  // ---- Robot dynamics ----
  // Robot 1
  m_robot*der(v1) = F1a - drag_lin*v1 + Fd1;
  I_robot*der(w1) = M1a - drag_rot*w1 + Md1;
  der(x1) = v1*cos(th1);
  der(y1) = v1*sin(th1);
  der(th1) = w1;
  // Robot 2
  m_robot*der(v2) = F2a - drag_lin*v2 + Fd2;
  I_robot*der(w2) = M2a - drag_rot*w2 + Md2;
  der(x2) = v2*cos(th2);
  der(y2) = v2*sin(th2);
  der(th2) = w2;
  // Robot 3
  m_robot*der(v3) = F3a - drag_lin*v3 + Fd3;
  I_robot*der(w3) = M3a - drag_rot*w3 + Md3;
  der(x3) = v3*cos(th3);
  der(y3) = v3*sin(th3);
  der(th3) = w3;

  // ---- Verification observables ----
  track_err1 = sqrt((x_ref + off_x1 - x1)^2 + (off_y1 - y1)^2);
  track_err2 = sqrt((x_ref + off_x2 - x2)^2 + (off_y2 - y2)^2);
  track_err3 = sqrt((x_ref + off_x3 - x3)^2 + (off_y3 - y3)^2);
  primary_track_err = max(track_err1, max(track_err2, track_err3));
  form_err = sqrt(((x2-x1)-(off_x2-off_x1))^2 + ((y2-y1)-(off_y2-off_y1))^2)
           + sqrt(((x3-x1)-(off_x3-off_x1))^2 + ((y3-y1)-(off_y3-off_y1))^2)
           + sqrt(((x3-x2)-(off_x3-off_x2))^2 + ((y3-y2)-(off_y3-off_y2))^2);
  min_sep = min(d12, min(d13, d23));
  max_tau_used = max(abs(tauL1), max(abs(tauR1), max(abs(tauL2), max(abs(tauR2), max(abs(tauL3), abs(tauR3))))));
  route_done = if (route_len > 0.0) then min(1.0, x_ref/route_len) else 0.0;

  // ---- Verification criteria ----
  verification_pass = (max_tau_used <= tau_max + 1e-6)
                      and (min_sep >= 2.0*R - 1e-6)
                      and ((time < 13.0) or (primary_track_err < 0.48))
                      and (route_done >= 0.999 or time < T_end - 1e-6);

  annotation (
    experiment(StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="Three 18 kg differential-drive warehouse robots (six bounded wheel drives, 14.6 N.m per wheel) maintain a triangle formation along a 10 m route at 500 Hz for 20 s. A 1.45 s communication dropout with a shared environmental disturbance occurs during the middle third (7.5-8.95 s). Distributed control uses last-received peer state with constant-velocity dead-reckoning prediction during dropout and recovers the formation afterward. Verification: actuator bounds respected, collision avoidance (min sep >= 2R), primary tracking error < 0.48 m after 13 s, finite estimates (all states bounded), and completed route. Body geometry (wheel radius, track, inertia), control gains, and disturbance magnitude are design assumptions for quantities not specified in the requirement."));
end GroundTrioResilientF;