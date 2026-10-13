model RailArmTraceE
  /* --------------------------------------------------------------------
     RailArmTraceE
     Fixed-base articulated manipulator: prismatic X rail + 2R planar arm.
     Follows a time-indexed cubic (Hermite) joint trajectory through three
     reachable waypoints and holds the last state. PID + velocity feedforward
     discrete controller at 250 Hz. Lateral disturbance (12 N) on the arm tip
     during the middle third. One fixed cylindrical keep-out obstacle.

     NOTE on unknowns (treated as assumptions, not facts):
       - Link masses/inertias are NOT given by the requirement; values below
         are engineering placeholders required for a simulatable plant.
       - Joint viscous damping coefficients are NOT given; assumed.
       - Obstacle position/radius are NOT given; placed beside (not on) the
         nominal path per requirement.
       - Arm plane orientation is NOT given; assumed horizontal (no gravity).
     -------------------------------------------------------------------- */

  // ---- Given physical parameters ----
  parameter Modelica.Units.SI.Length L_rail = 1.4 "X rail length";
  parameter Modelica.Units.SI.Mass  m_car = 18.0 "carriage mass";
  parameter Modelica.Units.SI.Length L1 = 0.46 "link 1 length";
  parameter Modelica.Units.SI.Length L2 = 0.31 "link 2 length";
  parameter Modelica.Units.SI.Angle th_lim = 1.5 "joint limit magnitude (+/-)";
  parameter Modelica.Units.SI.Force F_max = 800.0 "force actuator bound";
  parameter Modelica.Units.SI.Torque tau_max = 93.5 "torque actuator bound";
  parameter Modelica.Units.SI.Force F_dist = 12.0 "lateral disturbance magnitude";

  // ---- Unknown plant parameters (assumed for simulation) ----
  parameter Modelica.Units.SI.Mass m1 = 2.0  "link1 mass (assumed)";
  parameter Modelica.Units.SI.Mass m2 = 1.5  "link2 mass (assumed)";
  parameter Modelica.Units.SI.TranslationalDampingConstant b_x = 8.0  "carriage damping (assumed)";
  parameter Modelica.Units.SI.RotationalDampingConstant b1 = 1.2 "joint1 damping (assumed)";
  parameter Modelica.Units.SI.RotationalDampingConstant b2 = 0.8 "joint2 damping (assumed)";

  // ---- Obstacle (assumed placement, beside nominal path) ----
  parameter Modelica.Units.SI.Length obs_x = 0.65 "obstacle center x (assumed)";
  parameter Modelica.Units.SI.Length obs_y = 0.45 "obstacle center y (assumed)";
  parameter Modelica.Units.SI.Length obs_r = 0.08 "obstacle radius (assumed)";
  parameter Modelica.Units.SI.Length clearance_req = 0.05 "required clearance";

  // ---- Controller / sensor ----
  parameter Real Ts = 0.004 "sample period (250 Hz)";
  parameter Real Kp_x=600.0, Ki_x=200.0, Kd_x=40.0, Kff_x=18.0;
  parameter Real Kp_1=80.0,  Ki_1=30.0,  Kd_1=8.0,  Kff_1=1.5;
  parameter Real Kp_2=30.0,  Ki_2=12.0,  Kd_2=4.0,  Kff_2=0.5;
  parameter Real Ix_lim=2000.0, I1_lim=20.0, I2_lim=10.0 "anti-windup limits";

  // ---- Waypoints (reachable, within limits) ----
  parameter Modelica.Units.SI.Length x_wp0=0.30, x_wp1=0.80, x_wp2=1.10;
  parameter Modelica.Units.SI.Angle th1_wp0=0.20, th1_wp1=0.70, th1_wp2=0.40;
  parameter Modelica.Units.SI.Angle th2_wp0=0.30, th2_wp1=-0.50, th2_wp2=0.60;
  parameter Modelica.Units.SI.Time t_wp1=8.0, t_wp2=16.0;
  parameter Modelica.Units.SI.Time t_dist_a = 16.0/3.0 "disturbance start (middle third)";
  parameter Modelica.Units.SI.Time t_dist_b = 32.0/3.0 "disturbance end (middle third)";
  parameter Modelica.Units.SI.Time t_err_check = 10.4 "primary error check time";
  parameter Modelica.Units.SI.Velocity settle_vel = 0.05 "terminal velocity threshold";
  parameter Real overshoot_lim = 0.12 "max allowed overshoot fraction";
  parameter Real err_lim = 0.045 "primary tracking error limit after 10.4 s";

  // ---- Continuous states ----
  Modelica.Units.SI.Length x(start=x_wp0, fixed=true);
  Modelica.Units.SI.Angle th1(start=th1_wp0, fixed=true);
  Modelica.Units.SI.Angle th2(start=th2_wp0, fixed=true);
  Modelica.Units.SI.Velocity vx(start=0, fixed=true);
  Modelica.Units.SI.AngularVelocity w1(start=0, fixed=true);
  Modelica.Units.SI.AngularVelocity w2(start=0, fixed=true);

  // ---- Reference trajectory (continuous) ----
  Modelica.Units.SI.Length x_ref;
  Modelica.Units.SI.Velocity vx_ref;
  Modelica.Units.SI.Angle th1_ref, th2_ref;
  Modelica.Units.SI.AngularVelocity w1_ref, w2_ref;

  // ---- Disturbance ----
  Modelica.Units.SI.Force F_dist_y "lateral disturbance applied at tip (Y)";

  // ---- Generalized disturbance torques from lateral tip force ----
  Modelica.Units.SI.Torque Q_dist_1, Q_dist_2;

  // ---- Mass-matrix / dynamics terms ----
  Real a1 = L1/2.0;
  Real a2 = L2/2.0;
  Real I1 = m1*L1*L1/12.0;
  Real I2 = m2*L2*L2/12.0;
  Real M11, M12, M13, M22, M23, M33;
  Real C1, C2, C3;
  Real s_th1p = th1 + th2;

  // ---- Actuator commands (discrete, held) ----
  discrete Modelica.Units.SI.Force F_cmd(start=0.0);
  discrete Modelica.Units.SI.Torque tau1_cmd(start=0.0);
  discrete Modelica.Units.SI.Torque tau2_cmd(start=0.0);

  // ---- Encoder / estimator samples (discrete, synchronized) ----
  discrete Modelica.Units.SI.Length x_enc(start=x_wp0);
  discrete Modelica.Units.SI.Length th1_enc(start=th1_wp0);
  discrete Modelica.Units.SI.Length th2_enc(start=th2_wp0);
  discrete Modelica.Units.SI.Velocity vx_enc(start=0.0);
  discrete Modelica.Units.SI.AngularVelocity w1_enc(start=0.0);
  discrete Modelica.Units.SI.AngularVelocity w2_enc(start=0.0);

  // ---- Controller internals (discrete) ----
  discrete Real e_x(start=0.0), e1(start=0.0), e2(start=0.0);
  discrete Real epx(start=0.0), ep1(start=0.0), ep2(start=0.0);
  discrete Real de_x(start=0.0), de1(start=0.0), de2(start=0.0);
  discrete Real ix(start=0.0), i1(start=0.0), i2(start=0.0);
  discrete Real F_raw(start=0.0), t1_raw(start=0.0), t2_raw(start=0.0);

  // ---- Monitors (discrete) ----
  discrete Real qmax_x(start=x_wp0), qmin_x(start=x_wp0);
  discrete Real qmax_1(start=th1_wp0), qmin_1(start=th1_wp0);
  discrete Real qmax_2(start=th2_wp0), qmin_2(start=th2_wp0);
  discrete Real prim(start=0.0) "sampled primary tracking error";
  discrete Real err_post_max(start=0.0) "max primary error for time >= 10.4 s";

  // ---- Continuous traces ----
  Real e_x_c, e1_c, e2_c;
  Real primary_err "continuous primary tracking error";
  Real overshoot_x, overshoot_1, overshoot_2, overshoot_max;
  Boolean x_lim_ok, th1_lim_ok, th2_lim_ok, joint_lim_ok;
  Boolean settled;
  Boolean clearance_ok;
  Boolean no_nan_inf;
  Boolean accept;

  // ---- Obstacle clearance intermediates ----
  Real p0x, p0y, p1x, p1y, p2x, p2y;
  Real ab1x, ab1y, ap1x, ap1y, t1, tc1, d1;
  Real ab2x, ab2y, ap2x, ap2y, t2, tc2, d2;
  Real obs_clearance;

equation
  // ===== Kinematics =====
  der(x) = vx;
  der(th1) = w1;
  der(th2) = w2;

  // ===== Reference trajectory (cubic Hermite, rest-to-rest, holds last) =====
  if time <= 0.0 then
    x_ref = x_wp0;  vx_ref = 0.0;
    th1_ref = th1_wp0;  w1_ref = 0.0;
    th2_ref = th2_wp0;  w2_ref = 0.0;
  elseif time <= t_wp1 then
    x_ref = (2.0*(time/t_wp1)^3 - 3.0*(time/t_wp1)^2 + 1.0)*x_wp0
          + (-2.0*(time/t_wp1)^3 + 3.0*(time/t_wp1)^2)*x_wp1;
    vx_ref = (6.0*(time/t_wp1)*((time/t_wp1)-1.0)/t_wp1)*(x_wp0 - x_wp1);
    th1_ref = (2.0*(time/t_wp1)^3 - 3.0*(time/t_wp1)^2 + 1.0)*th1_wp0
            + (-2.0*(time/t_wp1)^3 + 3.0*(time/t_wp1)^2)*th1_wp1;
    w1_ref = (6.0*(time/t_wp1)*((time/t_wp1)-1.0)/t_wp1)*(th1_wp0 - th1_wp1);
    th2_ref = (2.0*(time/t_wp1)^3 - 3.0*(time/t_wp1)^2 + 1.0)*th2_wp0
            + (-2.0*(time/t_wp1)^3 + 3.0*(time/t_wp1)^2)*th2_wp1;
    w2_ref = (6.0*(time/t_wp1)*((time/t_wp1)-1.0)/t_wp1)*(th2_wp0 - th2_wp1);
  elseif time <= t_wp2 then
    x_ref = (2.0*((time-t_wp1)/(t_wp2-t_wp1))^3 - 3.0*((time-t_wp1)/(t_wp2-t_wp1))^2 + 1.0)*x_wp1
          + (-2.0*((time-t_wp1)/(t_wp2-t_wp1))^3 + 3.0*((time-t_wp1)/(t_wp2-t_wp1))^2)*x_wp2;
    vx_ref = (6.0*((time-t_wp1)/(t_wp2-t_wp1))*(((time-t_wp1)/(t_wp2-t_wp1))-1.0)/(t_wp2-t_wp1))*(x_wp1 - x_wp2);
    th1_ref = (2.0*((time-t_wp1)/(t_wp2-t_wp1))^3 - 3.0*((time-t_wp1)/(t_wp2-t_wp1))^2 + 1.0)*th1_wp1
            + (-2.0*((time-t_wp1)/(t_wp2-t_wp1))^3 + 3.0*((time-t_wp1)/(t_wp2-t_wp1))^2)*th1_wp2;
    w1_ref = (6.0*((time-t_wp1)/(t_wp2-t_wp1))*(((time-t_wp1)/(t_wp2-t_wp1))-1.0)/(t_wp2-t_wp1))*(th1_wp1 - th1_wp2);
    th2_ref = (2.0*((time-t_wp1)/(t_wp2-t_wp1))^3 - 3.0*((time-t_wp1)/(t_wp2-t_wp1))^2 + 1.0)*th2_wp1
            + (-2.0*((time-t_wp1)/(t_wp2-t_wp1))^3 + 3.0*((time-t_wp1)/(t_wp2-t_wp1))^2)*th2_wp2;
    w2_ref = (6.0*((time-t_wp1)/(t_wp2-t_wp1))*(((time-t_wp1)/(t_wp2-t_wp1))-1.0)/(t_wp2-t_wp1))*(th2_wp1 - th2_wp2);
  else
    x_ref = x_wp2;  vx_ref = 0.0;
    th1_ref = th1_wp2;  w1_ref = 0.0;
    th2_ref = th2_wp2;  w2_ref = 0.0;
  end if;

  // ===== Disturbance (lateral Y force at tip, middle third) =====
  if time < t_dist_a then
    F_dist_y = 0.0;
  elseif time > t_dist_b then
    F_dist_y = 0.0;
  else
    F_dist_y = F_dist;
  end if;
  // Generalized torques from lateral tip force: Q = J_tip_y^T * F_dist_y
  Q_dist_1 = F_dist_y*(L1*cos(th1) + L2*cos(s_th1p));
  Q_dist_2 = F_dist_y*L2*cos(s_th1p);

  // ===== Mass matrix =====
  M11 = m_car + m1 + m2;
  M12 = -m1*a1*sin(th1) - m2*(L1*sin(th1) + a2*sin(s_th1p));
  M13 = -m2*a2*sin(s_th1p);
  M22 = m1*a1*a1 + I1 + m2*(L1*L1 + a2*a2 + 2.0*L1*a2*cos(th2)) + I2;
  M23 = m2*(L1*a2*cos(th2) + a2*a2) + I2;
  M33 = m2*a2*a2 + I2;

  // ===== Coriolis / centrifugal terms =====
  C1 = (-m1*a1*cos(th1) - m2*(L1*cos(th1) + a2*cos(s_th1p)))*w1*w1
       - 2.0*m2*a2*cos(s_th1p)*w1*w2
       - m2*a2*cos(s_th1p)*w2*w2;
  C2 = -m2*L1*a2*sin(th2)*(2.0*w1*w2 + 0.5*w2*w2);
  C3 = m2*L1*a2*sin(th2)*w1*w1;

  // ===== Equations of motion (no gravity; horizontal plane assumed) =====
  M11*der(vx) + M12*der(w1) + M13*der(w2) = F_cmd - b_x*vx;
  M12*der(vx) + M22*der(w1) + M23*der(w2) = tau1_cmd - b1*w1 + Q_dist_1;
  M13*der(vx) + M23*der(w1) + M33*der(w2) = tau2_cmd - b2*w2 + Q_dist_2;

  // ===== Obstacle clearance (point-to-segment distance) =====
  p0x = x;        p0y = 0.0;
  p1x = x + L1*cos(th1);          p1y = L1*sin(th1);
  p2x = p1x + L2*cos(s_th1p);     p2y = p1y + L2*sin(s_th1p);
  ab1x = p1x - p0x;  ab1y = p1y - p0y;
  ap1x = obs_x - p0x; ap1y = obs_y - p0y;
  t1 = (ap1x*ab1x + ap1y*ab1y)/(ab1x*ab1x + ab1y*ab1y + 1.0e-12);
  tc1 = max(0.0, min(1.0, t1));
  d1 = sqrt((obs_x - (p0x + tc1*ab1x))^2 + (obs_y - (p0y + tc1*ab1y))^2);
  ab2x = p2x - p1x;  ab2y = p2y - p1y;
  ap2x = obs_x - p1x; ap2y = obs_y - p1y;
  t2 = (ap2x*ab2x + ap2y*ab2y)/(ab2x*ab2x + ab2y*ab2y + 1.0e-12);
  tc2 = max(0.0, min(1.0, t2));
  d2 = sqrt((obs_x - (p1x + tc2*ab2x))^2 + (obs_y - (p1y + tc2*ab2y))^2);
  obs_clearance = min(d1, d2) - obs_r;
  clearance_ok = obs_clearance > clearance_req;

  // ===== Continuous tracking traces =====
  e_x_c = x_ref - x;
  e1_c = th1_ref - th1;
  e2_c = th2_ref - th2;
  primary_err = max(abs(e_x_c), max(abs(e1_c), abs(e2_c)));

  // ===== Overshoot (relative to final waypoint, per DOF) =====
  overshoot_x = max(max(0.0, qmax_x - x_wp2), max(0.0, x_wp2 - qmin_x))
                / max(abs(x_wp2 - x_wp0), 1.0e-9);
  overshoot_1 = max(max(0.0, qmax_1 - th1_wp2), max(0.0, th1_wp2 - qmin_1))
                / max(abs(th1_wp2 - th1_wp0), 1.0e-9);
  overshoot_2 = max(max(0.0, qmax_2 - th2_wp2), max(0.0, th2_wp2 - qmin_2))
                / max(abs(th2_wp2 - th2_wp0), 1.0e-9);
  overshoot_max = max(overshoot_x, max(overshoot_1, overshoot_2));

  // ===== Limit / settling / finiteness checks =====
  x_lim_ok   = (x >= 0.0) and (x <= L_rail);
  th1_lim_ok = abs(th1) <= th_lim;
  th2_lim_ok = abs(th2) <= th_lim;
  joint_lim_ok = x_lim_ok and th1_lim_ok and th2_lim_ok;
  settled = (abs(vx) < settle_vel) and (abs(w1) < settle_vel) and (abs(w2) < settle_vel);
  no_nan_inf = (abs(x) < 1.0e20) and (abs(th1) < 1.0e20) and (abs(th2) < 1.0e20)
               and (abs(vx) < 1.0e20) and (abs(w1) < 1.0e20) and (abs(w2) < 1.0e20)
               and (abs(F_cmd) < 1.0e20) and (abs(tau1_cmd) < 1.0e20) and (abs(tau2_cmd) < 1.0e20)
               and (abs(x_enc) < 1.0e20) and (abs(th1_enc) < 1.0e20) and (abs(th2_enc) < 1.0e20)
               and (abs(vx_enc) < 1.0e20) and (abs(w1_enc) < 1.0e20) and (abs(w2_enc) < 1.0e20);

  // ===== Fail-closed acceptance (all criteria must hold) =====
  accept = joint_lim_ok and clearance_ok and (overshoot_max < overshoot_lim)
           and settled and (err_post_max < err_lim) and no_nan_inf;

  // ===== Discrete controller + encoders + monitors at 250 Hz =====
  when sample(0, Ts) then
    // Synchronized encoder position samples
    x_enc = x;
    th1_enc = th1;
    th2_enc = th2;
    // Encoder velocity estimates (backward difference) = estimator
    vx_enc = (x - pre(x_enc))/Ts;
    w1_enc = (th1 - pre(th1_enc))/Ts;
    w2_enc = (th2 - pre(th2_enc))/Ts;
    // Tracking errors (sampled)
    e_x = x_ref - x_enc;
    e1  = th1_ref - th1_enc;
    e2  = th2_ref - th2_enc;
    // PID integral with anti-windup clamp
    ix = max(-Ix_lim, min(Ix_lim, pre(ix) + Ts*e_x));
    i1 = max(-I1_lim, min(I1_lim, pre(i1) + Ts*e1));
    i2 = max(-I2_lim, min(I2_lim, pre(i2) + Ts*e2));
    // Error derivatives (backward difference)
    de_x = (e_x - pre(epx))/Ts;
    de1  = (e1  - pre(ep1))/Ts;
    de2  = (e2  - pre(ep2))/Ts;
    epx = e_x;
    ep1 = e1;
    ep2 = e2;
    // PID + velocity feedforward
    F_raw  = Kp_x*e_x + Ki_x*ix + Kd_x*de_x + Kff_x*vx_ref;
    t1_raw = Kp_1*e1   + Ki_1*i1  + Kd_1*de1  + Kff_1*w1_ref;
    t2_raw = Kp_2*e2   + Ki_2*i2  + Kd_2*de2  + Kff_2*w2_ref;
    // Saturate to actuator bounds
    F_cmd    = max(-F_max,   min(F_max,   F_raw));
    tau1_cmd = max(-tau_max, min(tau_max, t1_raw));
    tau2_cmd = max(-tau_max, min(tau_max, t2_raw));
    // Running extrema for overshoot
    qmax_x = max(pre(qmax_x), x);
    qmin_x = min(pre(qmin_x), x);
    qmax_1 = max(pre(qmax_1), th1);
    qmin_1 = min(pre(qmin_1), th1);
    qmax_2 = max(pre(qmax_2), th2);
    qmin_2 = min(pre(qmin_2), th2);
    // Primary error max after t_err_check
    prim = max(abs(e_x), max(abs(e1), abs(e2)));
    err_post_max = max(pre(err_post_max), if time >= t_err_check then prim else 0.0);
  end when;

  annotation (
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="RailArmTraceE: fixed-base prismatic+2R planar arm tracking a cubic joint trajectory through three reachable waypoints with PID+velocity-feedforward control at 250 Hz, a 12 N lateral tip disturbance in the middle third, and a fixed cylindrical keep-out obstacle. Fail-closed acceptance.")
  );
end RailArmTraceE;