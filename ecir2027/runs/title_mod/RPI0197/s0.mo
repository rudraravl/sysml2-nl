model RailArmPointE
  // ============ Specified parameters (from request) ============
  parameter Real L_rail     = 1.4   "X rail length [m]";
  parameter Real m_c        = 18.0  "carriage mass [kg]";
  parameter Real L1         = 0.46  "link 1 length [m]";
  parameter Real L2         = 0.31  "link 2 length [m]";
  parameter Real q_lim      = 1.5   "revolute joint limit [rad]";
  parameter Real u_rot_max  = 93.5  "rotary actuator command bound [N.m]";
  parameter Real u_lin_max  = 800.0 "linear actuator command bound [N]";
  parameter Real g          = 9.81  "gravity [m/s2]";
  parameter Real F_tip_dist = 9.6   "tip load disturbance magnitude [N]";
  parameter Real dt_ctrl    = 1.0/250.0 "control sample period [s] (250 Hz)";
  parameter Real T_run      = 16.0  "run duration [s]";

  // ============ Assumed parameters (NOT stated in request) ============
  // Link masses are required for dynamics but were not provided; values below
  // are explicit engineering assumptions, labeled as such.
  parameter Real m1 = 2.0  "link 1 mass [kg] - ASSUMED, not specified";
  parameter Real m2 = 1.5  "link 2 mass [kg] - ASSUMED, not specified";

  // Derived inertias (uniform slender rod about CoM)
  parameter Real I1 = m1*L1^2/12.0 "link 1 inertia [kg.m2]";
  parameter Real I2 = m2*L2^2/12.0 "link 2 inertia [kg.m2]";

  // Coupling constants
  parameter Real A_cf = (m1/2.0 + m2)*L1  "linear/angular-1 coupling constant";
  parameter Real B_cf = m2*L2/2.0         "linear/angular-2 coupling constant";
  parameter Real D_cf = m2*L1*L2          "angular coupling constant";

  // ============ Declared reachable target ============
  parameter Real x_t   = 0.7 "target carriage position [m]";
  parameter Real th1_t = 0.5 "target joint 1 angle [rad]";
  parameter Real th2_t = 0.4 "target joint 2 angle [rad]";

  // ============ Controller gains (joint-space PD + gravity comp) ============
  parameter Real Kp_x = 600.0;
  parameter Real Kd_x = 120.0;
  parameter Real Kp_1 = 180.0;
  parameter Real Kd_1 = 18.0;
  parameter Real Kp_2 = 200.0;
  parameter Real Kd_2 = 20.0;

  // ============ Plant states ============
  Real x(start=0.0, fixed=true)   "carriage position [m]";
  Real xd(start=0.0, fixed=true)  "carriage velocity [m/s]";
  Real th1(start=0.0, fixed=true) "joint 1 angle [rad]";
  Real w1(start=0.0, fixed=true)  "joint 1 velocity [rad/s]";
  Real th2(start=0.0, fixed=true) "joint 2 angle [rad]";
  Real w2(start=0.0, fixed=true)  "joint 2 velocity [rad/s]";

  // ============ Encoders / sensors (position & velocity on every axis) ============
  Real x_enc   "carriage position encoder [m]";
  Real xd_enc  "carriage velocity encoder [m/s]";
  Real th1_enc "joint 1 position encoder [rad]";
  Real w1_enc  "joint 1 velocity encoder [rad/s]";
  Real th2_enc "joint 2 position encoder [rad]";
  Real w2_enc  "joint 2 velocity encoder [rad/s]";

  // ============ Commands (held between 250 Hz samples) ============
  Real u_x(start=0.0) "held linear command [N]";
  Real u_1(start=0.0) "held joint 1 command [N.m]";
  Real u_2(start=0.0) "held joint 2 command [N.m]";
  Real u_x_sat "saturated linear command [N]";
  Real u_1_sat "saturated joint 1 command [N.m]";
  Real u_2_sat "saturated joint 2 command [N.m]";

  // ============ Trigonometric helpers ============
  Real s1, c1, s12, c12;

  // ============ Dynamics intermediates ============
  Real M11, M12, M13, M22, M23, M33;
  Real c_c1, c_c2, c_c3;   // Coriolis / centrifugal generalized forces
  Real G1, G2, G3;          // gravity generalized forces
  Real Q1, Q2, Q3;          // total generalized forces

  // ============ Disturbance ============
  Real dist_active "1.0 during middle third, else 0.0";
  Real F_tip_y     "applied tip force in y [N]";

  // ============ Collision geometry (rigid link endpoints / CoMs) ============
  Real com1_x, com1_y   "link 1 center of mass [m]";
  Real com2_x, com2_y   "link 2 center of mass [m]";
  Real elbow_x, elbow_y "joint 2 (elbow) location [m]";
  Real tip_x, tip_y     "end-effector tip location [m]";

  // ============ Tracking errors ============
  Real err_x   "carriage tracking error [m]";
  Real err_th1 "joint 1 tracking error [rad]";
  Real err_th2 "joint 2 tracking error [rad]";

equation
  // ---- trigonometry ----
  s1  = sin(th1);
  c1  = cos(th1);
  s12 = sin(th1 + th2);
  c12 = cos(th1 + th2);

  // ---- mass matrix (planar, gravity in -y) ----
  M11 = m_c + m1 + m2;
  M12 = A_cf*c1 + B_cf*c12;
  M13 = B_cf*c12;
  M22 = (m1*L1^2/3.0 + m2*L1^2 + m2*L2^2/3.0) + D_cf*cos(th2);
  M23 = (D_cf/2.0)*cos(th2) + m2*L2^2/3.0;
  M33 = m2*L2^2/3.0;

  // ---- Coriolis / centrifugal terms ----
  c_c1 = -A_cf*s1*w1*w1 - B_cf*s12*(2.0*w1*w2 + w2*w2);
  c_c2 = -(D_cf/2.0)*sin(th2)*(2.0*w1*w2 + w2*w2);
  c_c3 =  (D_cf/2.0)*sin(th2)*w1*w1;

  // ---- gravity generalized forces ----
  G1 = 0.0;
  G2 = A_cf*g*s1 + B_cf*g*s12;
  G3 = B_cf*g*s12;

  // ---- middle-third tip load disturbance (downward) ----
  dist_active = if (time >= T_run/3.0 and time <= 2.0*T_run/3.0) then 1.0 else 0.0;
  F_tip_y = -F_tip_dist*dist_active;

  // ---- total generalized forces (actuator + tip disturbance via tip Jacobian) ----
  Q1 = u_x_sat;
  Q2 = u_1_sat + (L1*s1 + L2*s12)*F_tip_y;
  Q3 = u_2_sat + (L2*s12)*F_tip_y;

  // ---- equations of motion: M*qdd + Coriolis + Gravity = Q ----
  M11*der(xd) + M12*der(w1) + M13*der(w2) + c_c1 + G1 = Q1;
  M12*der(xd) + M22*der(w1) + M23*der(w2) + c_c2 + G2 = Q2;
  M13*der(xd) + M23*der(w1) + M33*der(w2) + c_c3 + G3 = Q3;

  // ---- kinematic state ----
  der(x)   = xd;
  der(th1) = w1;
  der(th2) = w2;

  // ---- sensors (ideal encoders) ----
  x_enc   = x;
  xd_enc  = xd;
  th1_enc = th1;
  w1_enc  = w1;
  th2_enc = th2;
  w2_enc  = w2;

  // ---- command saturation ----
  u_x_sat = max(-u_lin_max, min(u_lin_max, u_x));
  u_1_sat = max(-u_rot_max, min(u_rot_max, u_1));
  u_2_sat = max(-u_rot_max, min(u_rot_max, u_2));

  // ---- sampled 250 Hz joint-space PD controller with gravity compensation ----
  when sample(0, dt_ctrl) then
    u_x = Kp_x*(x_t - x) - Kd_x*xd;
    u_1 = Kp_1*(th1_t - th1) - Kd_1*w1 + (A_cf*g*sin(th1) + B_cf*g*sin(th1 + th2));
    u_2 = Kp_2*(th2_t - th2) - Kd_2*w2 + (B_cf*g*sin(th1 + th2));
  end when;

  // ---- collision geometry (one shape per rigid link + carriage + tip) ----
  com1_x = x + (L1/2.0)*s1;
  com1_y = -(L1/2.0)*c1;
  com2_x = x + L1*s1 + (L2/2.0)*s12;
  com2_y = -L1*c1 - (L2/2.0)*c12;
  elbow_x = x + L1*s1;
  elbow_y = -L1*c1;
  tip_x = x + L1*s1 + L2*s12;
  tip_y = -L1*c1 - L2*c12;

  // ---- tracking errors ----
  err_x   = x_t - x;
  err_th1 = th1_t - th1;
  err_th2 = th2_t - th2;

  // ================= Fail-closed acceptance assertions =================
  // target reachability (declared)
  assert(x_t >= 0.0 and x_t <= L_rail, "target x outside rail reach");
  assert(abs(th1_t) <= q_lim and abs(th2_t) <= q_lim, "target joints outside limits");

  // joint limits (hard fail)
  assert(abs(th1) <= q_lim + 1e-6, "joint 1 limit violated");
  assert(abs(th2) <= q_lim + 1e-6, "joint 2 limit violated");
  assert(x >= -1e-6 and x <= L_rail + 1e-6, "carriage rail limit violated");

  // command saturation enforcement
  assert(abs(u_x_sat) <= u_lin_max + 1e-6, "linear command saturation failed");
  assert(abs(u_1_sat) <= u_rot_max + 1e-6, "rotary command 1 saturation failed");
  assert(abs(u_2_sat) <= u_rot_max + 1e-6, "rotary command 2 saturation failed");

  // no NaN / infinite physical, control, or estimator values (boundedness)
  assert(abs(x)   < 1e8, "x not finite");
  assert(abs(xd)  < 1e8, "xd not finite");
  assert(abs(th1) < 1e8, "th1 not finite");
  assert(abs(w1)  < 1e8, "w1 not finite");
  assert(abs(th2) < 1e8, "th2 not finite");
  assert(abs(w2)  < 1e8, "w2 not finite");
  assert(abs(u_x_sat) < 1e8, "u_x not finite");
  assert(abs(u_1_sat) < 1e8, "u_1 not finite");
  assert(abs(u_2_sat) < 1e8, "u_2 not finite");
  assert(abs(x_enc)   < 1e8, "x_enc not finite");
  assert(abs(th1_enc) < 1e8, "th1_enc not finite");
  assert(abs(th2_enc) < 1e8, "th2_enc not finite");

  // primary tracking error bound after 10.4 s (final third hold window)
  assert(time <= 10.4 or
         (abs(err_x) < 0.036 and abs(err_th1) < 0.036 and abs(err_th2) < 0.036),
         "primary tracking error exceeded after 10.4 s");

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 1.0/250.0),
    Documentation(info="Fixed-base articulated manipulator: 1.4 m X rail, 18 kg carriage,
 planar two-revolute arm (0.46 m, 0.31 m links, +/-1.5 rad limits).
 One linear force actuator (<=800 N) and two rotary torque actuators (<=93.5 N.m).
 Joint-space PD control with gravity compensation sampled at 250 Hz for 16 s.
 9.6 N downward tip load applied during the middle third.
 Target (x,th1,th2) = (0.7 m, 0.5 rad, 0.4 rad) reached from zero state and held.
 Link masses m1,m2 assumed (not specified in request).
 Fail-closed assertions enforce limits, saturation, finite values, and
 primary tracking error < 0.036 rad-or-m after 10.4 s."));
end RailArmPointE;