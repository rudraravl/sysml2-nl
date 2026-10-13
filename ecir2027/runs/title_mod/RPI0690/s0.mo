model HydBoomTrackF
  "Fluid-power robotic actuator (boom+stick) tracking a two-segment
   trajectory under a 319 N payload step disturbance in the middle third."

  // ----- Given facts -----
  parameter Real L_boom      = 2.0  "m";
  parameter Real L_stick     = 1.4  "m";
  parameter Real m_payload   = 300.0 "kg";
  parameter Real Q_pump_max  = 0.004 "m3/s pump flow bound";
  parameter Real F_dist_step = 319.0 "N payload step disturbance";
  parameter Real P_relief    = 2.5e7 "Pa relief valve setting";
  parameter Real g           = 9.81  "m/s2";

  // ----- Assumed (not stated, required for simulation) -----
  parameter Real m_boom   = 120.0 "kg assumed boom mass";
  parameter Real m_stick  = 60.0  "kg assumed stick mass";
  parameter Real J1_eff   = m_boom*L_boom^2/3 + m_stick*L_boom^2 + m_payload*L_boom^2 "kg m2";
  parameter Real J2_eff   = m_stick*L_stick^2/3 + m_payload*L_stick^2 "kg m2";

  // ----- Cylinder geometry (assumed) -----
  parameter Real Aa1 = 0.005 "m2 boom cap area";
  parameter Real Ab1 = 0.003 "m2 boom rod area";
  parameter Real Aa2 = 0.003 "m2 stick cap area";
  parameter Real Ab2 = 0.002 "m2 stick rod area";
  parameter Real r1  = 0.6   "m boom lever arm";
  parameter Real r2  = 0.5   "m stick lever arm";
  parameter Real Lstroke1 = 1.0 "m";
  parameter Real Lstroke2 = 0.8 "m";
  parameter Real Vdead_a1 = 2.0e-4 "m3";
  parameter Real Vdead_b1 = 2.0e-4 "m3";
  parameter Real Vdead_a2 = 1.5e-4 "m3";
  parameter Real Vdead_b2 = 1.5e-4 "m3";
  parameter Real Vs       = 2.0e-3 "m3 supply line volume";
  parameter Real beta     = 1.6e9  "Pa oil bulk modulus";

  // ----- Dissipation -----
  parameter Real b_cyl1   = 5.0e3 "N s/m";
  parameter Real b_cyl2   = 3.0e3 "N s/m";
  parameter Real b_joint1 = 50.0  "N m s/rad";
  parameter Real b_joint2 = 30.0  "N m s/rad";
  parameter Real cleak1   = 1.0e-12 "m3/(s Pa)";
  parameter Real cleak2   = 1.0e-12 "m3/(s Pa)";

  // ----- Valve / pump -----
  parameter Real Kv1     = 3.0e-4 "m3/s per unit command";
  parameter Real Kv2     = 2.0e-4 "m3/s per unit command";
  parameter Real Krelief = 1.0e-7 "m3/(s Pa)";
  parameter Real u_lim   = 1.0;

  // ----- Controller (feedforward flow + position/velocity + pressure feedback) -----
  parameter Real Kp1       = 18.0;
  parameter Real Kd1       = 4.0;
  parameter Real Kp_press1 = 1.0e-8;
  parameter Real Kp2       = 14.0;
  parameter Real Kd2       = 3.0;
  parameter Real Kp_press2 = 1.0e-8;
  parameter Real P_press1_ref = 5.0e6 "Pa reference for pressure feedback";
  parameter Real P_press2_ref = 3.5e6 "Pa";

  // ----- Dynamic states -----
  Real theta1(start=0.0) "rad boom angle";
  Real omega1(start=0.0) "rad/s";
  Real theta2(start=0.3) "rad stick angle";
  Real omega2(start=0.0) "rad/s";
  Real Pa1(start=5.0e6) "Pa boom cap pressure";
  Real Pb1(start=1.0e6) "Pa boom rod pressure";
  Real Pa2(start=3.5e6) "Pa stick cap pressure";
  Real Pb2(start=1.0e6) "Pa stick rod pressure";
  Real Ps(start=1.0e7)  "Pa supply pressure";

  // ----- Computed observables -----
  Real x1, v1, x2, v2;
  Real Va1, Vb1, Va2, Vb2;
  Real F1, F2;
  Real Qa1, Qb1, Qa2, Qb2;
  Real Qa1_pos, Qa2_pos, Q_demand, Qpump, Qrelief;
  Real u1_raw, u2_raw, u1, u2;
  Real theta1_ref, omega1_ref, theta2_ref, omega2_ref;
  Real x_tip, y_tip, x_tip_ref;
  Real tracking_err "m primary tracking error";
  Real F_disturb "N payload step disturbance";
  Real tau_g1, tau_g2, tau_dist1, tau_dist2;
  Real tau_net1, tau_net2;
  Real accel_tip "m/s2 tangential acceleration";
  Real cl1, cl2, s1v, s2v, sd1v, sd2v;

equation
  // ----- Two-segment smooth reference trajectory for boom -----
  cl1 = max(0.0, min(1.0, (time - 2.0)/6.0));     // segment 1: 2..8 s
  cl2 = max(0.0, min(1.0, (time - 12.0)/6.0));   // segment 2: 12..18 s
  s1v = cl1*cl1*(3.0 - 2.0*cl1);
  s2v = cl2*cl2*(3.0 - 2.0*cl2);
  sd1v = 6.0*cl1*(1.0 - cl1)/6.0;
  sd2v = 6.0*cl2*(1.0 - cl2)/6.0;
  theta1_ref = 0.5*s1v - 0.3*s2v;     // 0 -> 0.5 -> 0.2 rad
  omega1_ref = 0.5*sd1v - 0.3*sd2v;
  theta2_ref = 0.3;
  omega2_ref = 0.0;

  // ----- Cylinder kinematics -----
  x1 = r1*theta1;
  v1 = r1*omega1;
  x2 = r2*theta2;
  v2 = r2*omega2;
  Va1 = Vdead_a1 + Aa1*x1;
  Vb1 = Vdead_b1 + Ab1*(Lstroke1 - x1);
  Va2 = Vdead_a2 + Aa2*x2;
  Vb2 = Vdead_b2 + Ab2*(Lstroke2 - x2);

  // ----- Controller -----
  u1_raw = (Aa1*omega1_ref*r1)/Kv1
         + Kp1*(theta1_ref - theta1)
         + Kd1*(omega1_ref - omega1)
         - Kp_press1*(Pa1 - P_press1_ref);
  u2_raw = (Aa2*omega2_ref*r2)/Kv2
         + Kp2*(theta2_ref - theta2)
         + Kd2*(omega2_ref - omega2)
         - Kp_press2*(Pa2 - P_press2_ref);
  u1 = max(-u_lim, min(u_lim, u1_raw));
  u2 = max(-u_lim, min(u_lim, u2_raw));

  // ----- Valve flows (linear 4-way, one command per section) -----
  Qa1 = Kv1*u1;
  Qb1 = -Kv1*u1;
  Qa2 = Kv2*u2;
  Qb2 = -Kv2*u2;

  // ----- Load-sensing pump with relief valve -----
  Qa1_pos = max(0.0, Qa1);
  Qa2_pos = max(0.0, Qa2);
  Q_demand = Qa1_pos + Qa2_pos;
  Qpump  = if Q_demand <= Q_pump_max then Q_demand else Q_pump_max;
  Qrelief = if Ps > P_relief then Krelief*(Ps - P_relief) else 0.0;
  der(Ps) = (beta/Vs)*(Qpump - Qrelief - Qa1_pos - Qa2_pos);

  // ----- Chamber pressure dynamics with leakage -----
  der(Pa1) = (beta/Va1)*(Qa1 - Aa1*v1 - cleak1*(Pa1 - Pb1));
  der(Pb1) = (beta/Vb1)*(-Qb1 + Ab1*v1 + cleak1*(Pa1 - Pb1));
  der(Pa2) = (beta/Va2)*(Qa2 - Aa2*v2 - cleak2*(Pa2 - Pb2));
  der(Pb2) = (beta/Vb2)*(-Qb2 + Ab2*v2 + cleak2*(Pa2 - Pb2));

  // ----- Cylinder forces (viscous friction included) -----
  F1 = Aa1*Pa1 - Ab1*Pb1 - b_cyl1*v1;
  F2 = Aa2*Pa2 - Ab2*Pb2 - b_cyl2*v2;

  // ----- Tip kinematics -----
  x_tip = L_boom*cos(theta1) + L_stick*cos(theta1 + theta2);
  y_tip = L_boom*sin(theta1) + L_stick*sin(theta1 + theta2);

  // ----- Gravity torques about each pivot -----
  tau_g1 = m_boom*g*(L_boom/2.0)*cos(theta1)
         + m_stick*g*(L_boom*cos(theta1) + (L_stick/2.0)*cos(theta1 + theta2))
         + m_payload*g*x_tip;
  tau_g2 = m_stick*g*(L_stick/2.0)*cos(theta1 + theta2)
         + m_payload*g*L_stick*cos(theta1 + theta2);

  // ----- Finite-duration payload step disturbance (middle third: 6.667..13.333 s) -----
  F_disturb = if (time >= 6.6667 and time <= 13.3333) then F_dist_step else 0.0;
  tau_dist1 = -y_tip*F_disturb;
  tau_dist2 = -L_stick*sin(theta1 + theta2)*F_disturb;

  // ----- Joint dynamics -----
  tau_net1 = F1*r1 - tau_g1 - tau_dist1 - b_joint1*omega1;
  tau_net2 = F2*r2 - tau_g2 - tau_dist2 - b_joint2*omega2;
  der(omega1) = tau_net1/J1_eff;
  der(theta1) = omega1;
  der(omega2) = tau_net2/J2_eff;
  der(theta2) = omega2;

  // ----- Primary tracking error (tip x position) -----
  x_tip_ref = L_boom*cos(theta1_ref) + L_stick*cos(theta1_ref + theta2_ref);
  tracking_err = x_tip - x_tip_ref;
  accel_tip = abs(der(omega1))*L_boom;

  // ----- Verification criteria (soft warnings) -----
  assert(Pa1 < P_relief and Pa2 < P_relief and Ps <= P_relief + 1.0e6,
         "Pressure bound exceeded", AssertionLevel.warning);
  assert(Qpump <= Q_pump_max + 1.0e-6, "Pump flow bound exceeded", AssertionLevel.warning);
  assert(accel_tip < 20.0, "Acceleration bound exceeded", AssertionLevel.warning);
  assert(abs(tracking_err) <= 0.014 or time < 13.0,
         "Primary tracking error > 0.014 m after 13 s", AssertionLevel.warning);
  assert(theta1 > -0.5 and theta1 < 1.5 and theta2 > -0.5 and theta2 < 1.0,
         "Travel bound exceeded", AssertionLevel.warning);
  assert(Qrelief >= 0.0, "Relief valve flow negative", AssertionLevel.warning);

end HydBoomTrackF;