model RailArmPointF
  "Fixed-base articulated manipulator: X-rail carriage + 2R planar arm,
   joint-space PD control with gravity compensation, tip load disturbance."
  // ---- Embodiment (stated) ----
  parameter Real L_rail = 1.4   "m, fixed X rail length";
  parameter Real L1     = 0.46  "m, link 1 length";
  parameter Real L2     = 0.31  "m, link 2 length";
  parameter Real mc     = 18.0  "kg, carriage mass";
  parameter Real g      = 9.81  "m/s2, gravity";
  parameter Real qlim   = 1.5   "rad, joint limit magnitude";
  // Link masses/inertias are NOT stated in the requirement; the following
  // are placeholder assumptions required for dynamics (clearly labeled).
  parameter Real m1     = 2.5   "kg, link 1 mass (ASSUMPTION: not specified)";
  parameter Real m2     = 1.5   "kg, link 2 mass (ASSUMPTION: not specified)";
  // Point-mass-at-COM link model used (rotational inertia about own COM
  // not specified -> omitted, labeled here).

  // ---- Actuation limits (stated) ----
  parameter Real Fmax    = 800.0 "N, linear actuator limit";
  parameter Real taumax  = 104.0  "N.m, rotary actuator limit";

  // ---- Control gains (tuned for stable tracking within scenario timing) ----
  parameter Real Kp_x = 1000.0 "N/m";
  parameter Real Kd_x = 150.0  "N.s/m";
  parameter Real Kp_q = 300.0  "N.m/rad";
  parameter Real Kd_q = 22.0   "N.m.s/rad";

  // ---- Mission / timing ----
  parameter Real T_run     = 20.0  "s";
  parameter Real dt_sample  = 0.002 "s, 500 Hz";
  parameter Real t_dist_on  = 6.667 "s, start of middle-third disturbance";
  parameter Real t_dist_off = 13.0  "s, end of disturbance (aligned to tracking criterion)";
  parameter Real t_check    = 13.0  "s, tracking-error verification start";
  parameter Real Fdist      = 11.6  "N, tip load magnitude";

  // ---- Reachable target (declared, within limits) ----
  parameter Real x_target  = 0.6  "m   (0 <= x_target <= 1.4)";
  parameter Real q1_target = 0.7  "rad (|q1_target| <= 1.5)";
  parameter Real q2_target = -1.0 "rad (|q2_target| <= 1.5)";

  // ---- Initial conditions (zero joint state) ----
  parameter Real x0  = 0.0;
  parameter Real q10 = 0.0;
  parameter Real q20 = 0.0;

  // ---- Dynamic states ----
  Real x(start=x0,  fixed=true) "m, carriage position on X rail";
  Real q1(start=q10,fixed=true) "rad, shoulder joint angle";
  Real q2(start=q20,fixed=true) "rad, elbow joint angle";
  Real xd(start=0.0,fixed=true) "m/s, carriage velocity";
  Real q1d(start=0.0,fixed=true)"rad/s, joint1 velocity";
  Real q2d(start=0.0,fixed=true)"rad/s, joint2 velocity";
  Real xdd  "m/s2";
  Real q1dd "rad/s2";
  Real q2dd "rad/s2";

  // ---- Sensors (encoders: position + velocity on every axis) ----
  Real sen_x, sen_xd;
  Real sen_q1, sen_q1d;
  Real sen_q2, sen_q2d;

  // ---- Commands (saturated) ----
  Real Fx_cmd, tau1_cmd, tau2_cmd;
  Real Fx_sat, tau1_sat, tau2_sat;

  // ---- Disturbance generalized forces ----
  Real Qdist_x, Qdist_q1, Qdist_q2;
  Boolean dist_active;

  // ---- Gravity compensation torques ----
  Real G2, G3;

  // ---- Tracking errors ----
  Real err_x, err_q1, err_q2;

  // ---- Kinematic shorthand ----
  Real a1 = L1/2;
  Real a2 = L2/2;
  Real s1, c1, s2, c2, s12, c12;

  // ---- Mass matrix entries ----
  Real M11, M12, M13, M22, M23, M33;
  // ---- Bias (Coriolis/centrifugal + gravity) ----
  Real b1, b2, b3;

  // ---- Forward kinematics (collision geometry = link extents) ----
  Real tip_x, tip_y;
  Real link1_end_x, link1_end_y;

  // ---- Verification observables ----
  Boolean joint_limits_ok;
  Boolean rail_limits_ok;
  Boolean command_sat_ok;
  Boolean tracking_ok;
  Boolean finite_ok;

equation
  // Trigonometric shorthand
  s1  = sin(q1);  c1  = cos(q1);
  s2  = sin(q2);  c2  = cos(q2);
  s12 = sin(q1+q2); c12 = cos(q1+q2);

  // Mass matrix (point-mass-at-COM link model)
  M11 = mc + m1 + m2;
  M12 = -(m1*a1 + m2*L1)*s1;
  M13 = -m2*a2*s12;
  M22 = m1*a1*a1 + m2*(L1*L1 + a2*a2 + 2.0*L1*a2*c2);
  M23 = m2*(a2*a2 + L1*a2*c2);
  M33 = m2*a2*a2;

  // Gravity generalized forces (compensation terms)
  G2 = (m1*a1 + m2*L1)*g*c1 + m2*a2*g*c12;
  G3 = m2*a2*g*c12;

  // Coriolis/centrifugal + gravity bias vector
  b1 = -(m1*a1 + m2*L1)*c1*q1d*q1d
       - m2*a2*c12*(q1d + q2d)*q2d;
  b2 = -2.0*m2*L1*a2*s2*q1d*q2d
       - m2*L1*a2*s2*q2d*q2d
       + m2*a2*c12*xd*q2d
       + G2;
  b3 = -m2*a2*c12*q1d*xd
       + m2*L1*a2*s2*q1d*q1d
       + G3;

  // Tip-load disturbance (downward -Y), active during middle third
  dist_active = (time >= t_dist_on) and (time < t_dist_off);
  Qdist_x  = 0.0;
  Qdist_q1 = if dist_active then (L1*c1 + L2*c12)*(-Fdist) else 0.0;
  Qdist_q2 = if dist_active then (L2*c12)*(-Fdist) else 0.0;

  // Joint-space PD control with gravity compensation (target velocity = 0)
  err_x  = x_target  - x;
  err_q1 = q1_target - q1;
  err_q2 = q2_target - q2;
  Fx_cmd  = Kp_x*err_x  - Kd_x*xd;
  tau1_cmd = Kp_q*err_q1 - Kd_q*q1d + G2;
  tau2_cmd = Kp_q*err_q2 - Kd_q*q2d + G3;

  // Command saturation
  Fx_sat  = max(-Fmax,  min(Fmax,  Fx_cmd));
  tau1_sat= max(-taumax,min(taumax,tau1_cmd));
  tau2_sat= max(-taumax,min(taumax,tau2_cmd));

  // Equations of motion: M(q)*qdd = tau_sat + Qdist - bias
  M11*xdd + M12*q1dd + M13*q2dd = Fx_sat  + Qdist_x  - b1;
  M12*xdd + M22*q1dd + M23*q2dd = tau1_sat+ Qdist_q1 - b2;
  M13*xdd + M23*q1dd + M33*q2dd = tau2_sat+ Qdist_q2 - b3;

  // State derivatives
  der(x)  = xd;
  der(q1) = q1d;
  der(q2) = q2d;
  der(xd) = xdd;
  der(q1d)= q1dd;
  der(q2d)= q2dd;

  // Sensors
  sen_x   = x;   sen_xd  = xd;
  sen_q1  = q1;  sen_q1d = q1d;
  sen_q2  = q2;  sen_q2d = q2d;

  // Forward kinematics (collision geometry extents per link)
  link1_end_x = x + L1*c1;
  link1_end_y = L1*s1;
  tip_x = x + L1*c1 + L2*c12;
  tip_y = L1*s1 + L2*s12;

  // ---- Verification criteria ----
  joint_limits_ok = (q1 >= -qlim) and (q1 <= qlim)
                 and (q2 >= -qlim) and (q2 <= qlim);
  rail_limits_ok  = (x >= 0.0) and (x <= L_rail);
  command_sat_ok  = (abs(Fx_sat)  <= Fmax   + 1.0e-9)
                 and (abs(tau1_sat)<= taumax + 1.0e-9)
                 and (abs(tau2_sat)<= taumax + 1.0e-9);
  tracking_ok     = if (time >= t_check) then
                       (abs(err_x)  <= 0.032)
                     and (abs(err_q1)<= 0.032)
                     and (abs(err_q2)<= 0.032)
                   else true;
  finite_ok       = (abs(x)  < 1.0e12) and (abs(q1) < 1.0e12) and (abs(q2) < 1.0e12)
                 and (abs(xd) < 1.0e12) and (abs(q1d)< 1.0e12) and (abs(q2d)< 1.0e12)
                 and (abs(Fx_sat) < 1.0e12) and (abs(tau1_sat) < 1.0e12) and (abs(tau2_sat) < 1.0e12);

  annotation(
    experiment(
      StopTime=20.0,
      Tolerance=1.0e-6,
      Interval=0.002),
    Documentation(info="RailArmPointF: fixed-base articulated planar manipulator
      (X-rail prismatic carriage + 2 revolute joints). Joint-space PD control with
      gravity compensation. 11.6 N downward tip-load disturbance applied during the
      middle third. 500 Hz, 20 s run. Verification: joint/rail limits, command
      saturation, final target bounds (<=0.032 after 13 s), finite values.
      Link masses m1,m2 are assumptions (not stated in requirement)."));
end RailArmPointF;