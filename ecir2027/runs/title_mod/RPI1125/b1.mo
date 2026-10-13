model GroundTrioResilientC
  "Three 18 kg differential-drive warehouse robots with distributed predictive
   control that maintains coordinated motion through a 0.9 s communication
   dropout in the middle third of the run and recovers formation tracking after."

  /* --- Physical parameters (SI) ---
     Only m, wheel torque bound, dropout duration and run rate are stated.
     Wheel radius, wheelbase, inertia and damping are required for a
     simulatable plant and are set to reasonable warehouse-robot values; they
     are labeled as assumptions where the request does not state them. */
  parameter Real m       = 18.0  "robot mass [kg] (stated)";
  parameter Real r_w     = 0.10  "wheel radius [m] (assumed)";
  parameter Real L_w     = 0.40  "wheelbase [m] (assumed)";
  parameter Real I_z     = 0.90  "yaw inertia [kg.m2] (assumed)";
  parameter Real b_lin   = 6.0   "linear viscous damping [N.s/m] (assumed)";
  parameter Real b_ang   = 1.2   "yaw damping [N.m.s/rad] (assumed)";
  parameter Real tau_max = 11.0  "max wheel torque magnitude [N.m] (stated)";

  /* --- Mission / schedule parameters --- */
  parameter Real v_ref        = 0.60 "route speed [m/s] (assumed)";
  parameter Real x_end        = 7.00 "route end x [m] (assumed so route completes by 12 s)";
  parameter Real Ts           = 1.0/125.0 "control & sensor update rate [s] (stated: 125 Hz)";
  parameter Real t_drop_start = 6.00 "dropout start [s] (middle third of 12 s is [4,8])";
  parameter Real t_drop_end   = 6.90 "dropout end [s], duration 0.9 s (stated)";
  parameter Real t_route_end  = x_end / v_ref "route completion time [s]";

  /* --- Disturbance (shared, active only while communication unavailable) --- */
  parameter Real F_dist = 3.0 "shared environmental disturbance [N] (assumed)";

  /* --- Controller gains (assumed; tuned for finite, bounded response) --- */
  parameter Real k_p    = 30.0 "position gain";
  parameter Real k_d    = 60.0 "velocity gain";
  parameter Real k_form = 6.0  "formation gain";
  parameter Real k_coll = 40.0 "collision-avoidance gain";
  parameter Real k_th   = 20.0 "heading gain";
  parameter Real k_w    = 8.0  "yaw-rate gain";
  parameter Real d_safe = 0.35 "collision avoidance range [m] (assumed)";

  /* --- Formation geometry offsets [m] (assumed triangle) --- */
  parameter Real dx1 = 0.0,  dy1 = 0.5;
  parameter Real dx2 = 0.0,  dy2 = -0.5;
  parameter Real dx3 = 0.866, dy3 = 0.0;

  /* --- Reference route --- */
  Real x_ref(start = 0.0) "route x [m]";
  Real vx_ref "route speed command [m/s]";
  Boolean routeCompleted;

  /* --- Robot 1 --- */
  Real x1(start = 0.0),  y1(start = 0.5), th1(start = 0.0);
  Real vx1(start = 0.0), vy1(start = 0.0), w1(start = 0.0);
  Real F1x_des, F1y_des, F1_body, M1_body, th1_d;
  Real e1x, e1y, ff1x, ff1y, c1x, c1y;
  output Real tau1R, tau1L;
  Real tau1R_raw, tau1L_raw;
  output Real posErr1;

  /* --- Robot 2 --- */
  Real x2(start = 0.0),  y2(start = -0.5), th2(start = 0.0);
  Real vx2(start = 0.0), vy2(start = 0.0), w2(start = 0.0);
  Real F2x_des, F2y_des, F2_body, M2_body, th2_d;
  Real e2x, e2y, ff2x, ff2y, c2x, c2y;
  output Real tau2R, tau2L;
  Real tau2R_raw, tau2L_raw;
  output Real posErr2;

  /* --- Robot 3 --- */
  Real x3(start = 0.866), y3(start = 0.0), th3(start = 0.0);
  Real vx3(start = 0.0), vy3(start = 0.0), w3(start = 0.0);
  Real F3x_des, F3y_des, F3_body, M3_body, th3_d;
  Real e3x, e3y, ff3x, ff3y, c3x, c3y;
  output Real tau3R, tau3L;
  Real tau3R_raw, tau3L_raw;
  output Real posErr3;

  /* --- Communication state (last-received peer state + timestamp) --- */
  Boolean commDrop(start = false);
  discrete Real rx21(start = 0.0),  ry21(start = -0.5), rvx21(start = 0.0), rvy21(start = 0.0), rth21(start = 0.0), t21(start = 0.0);
  discrete Real rx31(start = 0.866), ry31(start = 0.0),  rvx31(start = 0.0), rvy31(start = 0.0), rth31(start = 0.0), t31(start = 0.0);
  discrete Real rx12(start = 0.0),  ry12(start = 0.5),  rvx12(start = 0.0), rvy12(start = 0.0), rth12(start = 0.0), t12(start = 0.0);
  discrete Real rx32(start = 0.866), ry32(start = 0.0), rvx32(start = 0.0), rvy32(start = 0.0), rth32(start = 0.0), t32(start = 0.0);
  discrete Real rx13(start = 0.0),  ry13(start = 0.5),  rvx13(start = 0.0), rvy13(start = 0.0), rth13(start = 0.0), t13(start = 0.0);
  discrete Real rx23(start = 0.0),  ry23(start = -0.5), rvx23(start = 0.0), rvy23(start = 0.0), rth23(start = 0.0), t23(start = 0.0);

  /* --- Predicted peer positions (constant-velocity predictor) --- */
  Real px21, py21, px31, py31;
  Real px12, py12, px32, py32;
  Real px13, py13, px23, py23;

  /* --- Lidar inter-robot ranges [m] --- */
  Real r12, r13, r23;

  /* --- Disturbance applied to fleet --- */
  Real Fdx, Fdy;

  /* --- Observables --- */
  output Real primaryTrackingError "RMS of three position tracking errors [m]";
  output Real formationError "current formation error [m]";
  discrete Real formationErrorDegraded(start = 0.0) "peak formation error during dropout [m]";
  output Boolean commDropOut;
  output Boolean routeCompleted_out;
  output Boolean noNaNInf "runtime finite-state health flag";

equation
  /* ===== Reference route (smooth, completes before 12 s) ===== */
  vx_ref = if time < t_route_end then v_ref else 0.0;
  der(x_ref) = vx_ref;
  routeCompleted = x_ref >= (x_end - 1e-3);
  routeCompleted_out = routeCompleted;

  /* ===== Communication dropout flag ===== */
  commDropOut = commDrop;

  /* shared disturbance active only while communication unavailable */
  Fdx = if commDrop then (-F_dist) else 0.0;
  Fdy = 0.0;

  /* ===== Lidar ranges (with zero-error branch for the sqrt divisor) ===== */
  r12 = sqrt(max(1e-6, (x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2)));
  r13 = sqrt(max(1e-6, (x1 - x3)*(x1 - x3) + (y1 - y3)*(y1 - y3)));
  r23 = sqrt(max(1e-6, (x2 - x3)*(x2 - x3) + (y2 - y3)*(y2 - y3)));

  /* ===== Collision-avoidance forces (repulsive, lidar-based) ===== */
  c1x = k_coll * ((x1 - x2)/r12 * max(0.0, d_safe - r12) + (x1 - x3)/r13 * max(0.0, d_safe - r13));
  c1y = k_coll * ((y1 - y2)/r12 * max(0.0, d_safe - r12) + (y1 - y3)/r13 * max(0.0, d_safe - r13));
  c2x = k_coll * ((x2 - x1)/r12 * max(0.0, d_safe - r12) + (x2 - x3)/r23 * max(0.0, d_safe - r23));
  c2y = k_coll * ((y2 - y1)/r12 * max(0.0, d_safe - r12) + (y2 - y3)/r23 * max(0.0, d_safe - r23));
  c3x = k_coll * ((x3 - x1)/r13 * max(0.0, d_safe - r13) + (x3 - x2)/r23 * max(0.0, d_safe - r23));
  c3y = k_coll * ((y3 - y1)/r13 * max(0.0, d_safe - r13) + (y3 - y2)/r23 * max(0.0, d_safe - r23));

  /* ===== Predicted peer states (used by distributed controllers) ===== */
  px21 = rx21 + rvx21 * (time - t21);
  py21 = ry21 + rvy21 * (time - t21);
  px31 = rx31 + rvx31 * (time - t31);
  py31 = ry31 + rvy31 * (time - t31);
  px12 = rx12 + rvx12 * (time - t12);
  py12 = ry12 + rvy12 * (time - t12);
  px32 = rx32 + rvx32 * (time - t32);
  py32 = ry32 + rvy32 * (time - t32);
  px13 = rx13 + rvx13 * (time - t13);
  py13 = ry13 + rvy13 * (time - t13);
  px23 = rx23 + rvx23 * (time - t23);
  py23 = ry23 + rvy23 * (time - t23);

  /* ===== Robot 1 distributed controller ===== */
  e1x = (x_ref + dx1) - x1;
  e1y = (0.0    + dy1) - y1;
  ff1x = k_form * ((dx1 - dx2 - (x1 - px21)) + (dx1 - dx3 - (x1 - px31)));
  ff1y = k_form * ((dy1 - dy2 - (y1 - py21)) + (dy1 - dy3 - (y1 - py31)));
  F1x_des = k_p * e1x + k_d * (vx_ref - vx1) + b_lin * vx_ref + ff1x + c1x;
  F1y_des = k_p * e1y + k_d * (0.0    - vy1) + ff1y + c1y;
  th1_d   = if (F1x_des*F1x_des + F1y_des*F1y_des) > 1e-6 then atan2(F1y_des, F1x_des) else th1;
  F1_body = F1x_des * cos(th1) + F1y_des * sin(th1);
  M1_body = k_th * (th1_d - th1) - k_w * w1;
  tau1R_raw = (r_w / 2.0) * (F1_body + 2.0 * M1_body / L_w);
  tau1L_raw = (r_w / 2.0) * (F1_body - 2.0 * M1_body / L_w);
  tau1R = max(-tau_max, min(tau_max, tau1R_raw));
  tau1L = max(-tau_max, min(tau_max, tau1L_raw));

  /* ===== Robot 2 distributed controller ===== */
  e2x = (x_ref + dx2) - x2;
  e2y = (0.0    + dy2) - y2;
  ff2x = k_form * ((dx2 - dx1 - (x2 - px12)) + (dx2 - dx3 - (x2 - px32)));
  ff2y = k_form * ((dy2 - dy1 - (y2 - py12)) + (dy2 - dy3 - (y2 - py32)));
  F2x_des = k_p * e2x + k_d * (vx_ref - vx2) + b_lin * vx_ref + ff2x + c2x;
  F2y_des = k_p * e2y + k_d * (0.0    - vy2) + ff2y + c2y;
  th2_d   = if (F2x_des*F2x_des + F2y_des*F2y_des) > 1e-6 then atan2(F2y_des, F2x_des) else th2;
  F2_body = F2x_des * cos(th2) + F2y_des * sin(th2);
  M2_body = k_th * (th2_d - th2) - k_w * w2;
  tau2R_raw = (r_w / 2.0) * (F2_body + 2.0 * M2_body / L_w);
  tau2L_raw = (r_w / 2.0) * (F2_body - 2.0 * M2_body / L_w);
  tau2R = max(-tau_max, min(tau_max, tau2R_raw));
  tau2L = max(-tau_max, min(tau_max, tau2L_raw));

  /* ===== Robot 3 distributed controller ===== */
  e3x = (x_ref + dx3) - x3;
  e3y = (0.0    + dy3) - y3;
  ff3x = k_form * ((dx3 - dx1 - (x3 - px13)) + (dx3 - dx2 - (x3 - px23)));
  ff3y = k_form * ((dy3 - dy1 - (y3 - py13)) + (dy3 - dy2 - (y3 - py23)));
  F3x_des = k_p * e3x + k_d * (vx_ref - vx3) + b_lin * vx_ref + ff3x + c3x;
  F3y_des = k_p * e3y + k_d * (0.0    - vy3) + ff3y + c3y;
  th3_d   = if (F3x_des*F3x_des + F3y_des*F3y_des) > 1e-6 then atan2(F3y_des, F3x_des) else th3;
  F3_body = F3x_des * cos(th3) + F3y_des * sin(th3);
  M3_body = k_th * (th3_d - th3) - k_w * w3;
  tau3R_raw = (r_w / 2.0) * (F3_body + 2.0 * M3_body / L_w);
  tau3L_raw = (r_w / 2.0) * (F3_body - 2.0 * M3_body / L_w);
  tau3R = max(-tau_max, min(tau_max, tau3R_raw));
  tau3L = max(-tau_max, min(tau_max, tau3L_raw));

  /* ===== Robot 1 dynamics (differential drive on rigid floor) ===== */
  der(x1)  = vx1;
  der(y1)  = vy1;
  der(th1) = w1;
  der(vx1) = (( (tau1R + tau1L) / r_w ) * cos(th1) - b_lin * vx1 + Fdx) / m;
  der(vy1) = (( (tau1R + tau1L) / r_w ) * sin(th1) - b_lin * vy1 + Fdy) / m;
  der(w1)  = ( ( (tau1R - tau1L) * L_w / (2.0 * r_w) ) - b_ang * w1 ) / I_z;

  /* ===== Robot 2 dynamics ===== */
  der(x2)  = vx2;
  der(y2)  = vy2;
  der(th2) = w2;
  der(vx2) = (( (tau2R + tau2L) / r_w ) * cos(th2) - b_lin * vx2 + Fdx) / m;
  der(vy2) = (( (tau2R + tau2L) / r_w ) * sin(th2) - b_lin * vy2 + Fdy) / m;
  der(w2)  = ( ( (tau2R - tau2L) * L_w / (2.0 * r_w) ) - b_ang * w2 ) / I_z;

  /* ===== Robot 3 dynamics ===== */
  der(x3)  = vx3;
  der(y3)  = vy3;
  der(th3) = w3;
  der(vx3) = (( (tau3R + tau3L) / r_w ) * cos(th3) - b_lin * vx3 + Fdx) / m;
  der(vy3) = (( (tau3R + tau3L) / r_w ) * sin(th3) - b_lin * vy3 + Fdy) / m;
  der(w3)  = ( ( (tau3R - tau3L) * L_w / (2.0 * r_w) ) - b_ang * w3 ) / I_z;

  /* ===== Per-robot tracking errors (proprioception vs route) ===== */
  posErr1 = sqrt(e1x*e1x + e1y*e1y);
  posErr2 = sqrt(e2x*e2x + e2y*e2y);
  posErr3 = sqrt(e3x*e3x + e3y*e3y);
  primaryTrackingError = sqrt((posErr1*posErr1 + posErr2*posErr2 + posErr3*posErr3) / 3.0);

  /* ===== Formation error (inter-robot offsets vs desired geometry) ===== */
  formationError = sqrt(
    ( ((x1 - x2) - (dx1 - dx2))*((x1 - x2) - (dx1 - dx2)) +
      ((y1 - y2) - (dy1 - dy2))*((y1 - y2) - (dy1 - dy2)) +
      ((x1 - x3) - (dx1 - dx3))*((x1 - x3) - (dx1 - dx3)) +
      ((y1 - y3) - (dy1 - dy3))*((y1 - y3) - (dy1 - dy3)) +
      ((x2 - x3) - (dx2 - dx3))*((x2 - x3) - (dx2 - dx3)) +
      ((y2 - y3) - (dy2 - dy3))*((y2 - y3) - (dy2 - dy3)) ) / 3.0 );

  /* ===== Finite-state health flag (no NaN / no Inf physical, control, estimator) ===== */
  noNaNInf = (x1 == x1) and (y1 == y1) and (vx1 == vx1) and (vy1 == vy1) and (th1 == th1) and (w1 == w1) and
             (x2 == x2) and (y2 == y2) and (vx2 == vx2) and (vy2 == vy2) and (th2 == th2) and (w2 == w2) and
             (x3 == x3) and (y3 == y3) and (vx3 == vx3) and (vy3 == vy3) and (th3 == th3) and (w3 == w3) and
             (abs(x1) < 1e12) and (abs(y1) < 1e12) and (abs(vx1) < 1e12) and (abs(vy1) < 1e12) and
             (abs(x2) < 1e12) and (abs(y2) < 1e12) and (abs(vx2) < 1e12) and (abs(vy2) < 1e12) and
             (abs(x3) < 1e12) and (abs(y3) < 1e12) and (abs(vx3) < 1e12) and (abs(vy3) < 1e12) and
             (abs(tau1R) < 1e12) and (abs(tau1L) < 1e12) and
             (abs(tau2R) < 1e12) and (abs(tau2L) < 1e12) and
             (abs(tau3R) < 1e12) and (abs(tau3L) < 1e12) and
             (abs(px21) < 1e12) and (abs(py21) < 1e12) and
             (abs(px31) < 1e12) and (abs(py31) < 1e12) and
             (abs(px12) < 1e12) and (abs(py12) < 1e12) and
             (abs(px32) < 1e12) and (abs(py32) < 1e12) and
             (abs(px13) < 1e12) and (abs(py13) < 1e12) and
             (abs(px23) < 1e12) and (abs(py23) < 1e12);

  /* ===== 125 Hz discrete update: communication, peer messages, dropout peak ===== */
  when sample(0, Ts) then
    commDrop = (time >= t_drop_start) and (time < t_drop_end);
    /* peer messages are received (with timestamps) only when communication is up */
    if not commDrop then
      rx21 = x2;  ry21 = y2;  rvx21 = vx2; rvy21 = vy2; rth21 = th2; t21 = time;
      rx31 = x3;  ry31 = y3;  rvx31 = vx3; rvy31 = vy3; rth31 = th3; t31 = time;
      rx12 = x1;  ry12 = y1;  rvx12 = vx1; rvy12 = vy1; rth12 = th1; t12 = time;
      rx32 = x3;  ry32 = y3;  rvx32 = vx3; rvy32 = vy3; rth32 = th3; t32 = time;
      rx13 = x1;  ry13 = y1;  rvx13 = vx1; rvy13 = vy1; rth13 = th1; t13 = time;
      rx23 = x2;  ry23 = y2;  rvx23 = vx2; rvy23 = vy2; rth23 = th2; t23 = time;
    end if;
    /* track peak formation error while communication is unavailable */
    if commDrop then
      if formationError > pre(formationErrorDegraded) then
        formationErrorDegraded = formationError;
      else
        formationErrorDegraded = pre(formationErrorDegraded);
      end if;
    else
      formationErrorDegraded = pre(formationErrorDegraded);
    end if;
  end when;

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 1.0/125.0),
    Documentation(info = "Three 18 kg differential-drive warehouse robots with
      distributed predictive control. A 0.9 s communication dropout is injected
      at [6.0, 6.9] s (within the middle third of a 12 s run). While communication
      is unavailable a shared environmental disturbance is applied and each
      robot predicts peer states from the last-received message and timestamp.
      Six wheel torques are bounded at +/-11 N.m. The route completes before 12 s
      and primary tracking error is required below 0.63 m after 7.8 s."));
end GroundTrioResilientC;