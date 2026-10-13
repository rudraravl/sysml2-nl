model ForkArmPointC
  "3-DOF articulated manipulator: joint-space PD with gravity compensation"

  // --- Physical constants ---
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // --- Masses (from requirement) ---
  parameter Real m_ped = 24.0 "Pedestal mass, fixed base [kg]";
  parameter Real m1    = 7.0  "Mast (revolute Z) moving mass [kg]";
  parameter Real m2    = 3.0  "Camera boom (revolute X) moving mass [kg]";
  parameter Real m3    = 2.0  "Tool slide (prismatic Y) moving mass [kg]";

  // --- Link geometry ---
  // Exact link dimensions are NOT specified in the requirement; declared as
  // design parameters so the model is self-contained and simulatable.
  parameter Real L1 = 0.5 "Mast height [m]";
  parameter Real L2 = 0.6 "Boom length [m]";
  parameter Real r1 = L1 / 2.0 "Mast center of mass offset [m]";
  parameter Real r2 = L2 / 2.0 "Boom center of mass offset [m]";

  // --- Collision geometry (one entry per rigid link) ---
  parameter Real ped_col_r = 0.15 "Pedestal collision radius [m]";
  parameter Real ped_col_h = 0.20 "Pedestal collision height [m]";
  parameter Real mast_col_r = 0.05 "Mast link collision radius [m]";
  parameter Real boom_col_r = 0.04 "Boom link collision radius [m]";
  parameter Real slide_col_r = 0.03 "Slide link collision radius [m]";
  parameter Real slide_col_l = 0.15 "Slide link collision length [m]";

  // --- Joint limits ---
  parameter Real q1_lim_pos = 3.14159 "Joint 1 upper limit [rad]";
  parameter Real q1_lim_neg = -3.14159 "Joint 1 lower limit [rad]";
  parameter Real q2_lim_pos = 1.5708  "Joint 2 upper limit [rad]";
  parameter Real q2_lim_neg = -1.5708  "Joint 2 lower limit [rad]";
  parameter Real q3_lim_pos = L2      "Joint 3 upper limit [m]";
  parameter Real q3_lim_neg = 0.0     "Joint 3 lower limit [m]";

  // --- Actuator command limits ---
  parameter Real tau_max = 73.6 "Max revolute joint command magnitude [N.m]";
  parameter Real F_max   = 700.0 "Max prismatic joint command magnitude [N]";

  // --- Disturbance ---
  parameter Real F_dist = 7.2 "Tip load disturbance magnitude [N]";

  // --- Control gains ---
  parameter Real Kp1 = 300.0 "Joint 1 proportional gain [N.m/rad]";
  parameter Real Kd1 = 50.0  "Joint 1 derivative gain [N.m.s/rad]";
  parameter Real Kp2 = 200.0 "Joint 2 proportional gain [N.m/rad]";
  parameter Real Kd2 = 30.0  "Joint 2 derivative gain [N.m.s/rad]";
  parameter Real Kp3 = 300.0 "Joint 3 proportional gain [N/m]";
  parameter Real Kd3 = 40.0  "Joint 3 derivative gain [N.s/m]";

  // --- Target (declared, within joint limits) ---
  parameter Real q1_t = 0.7854 "Target mast angle [rad]  (pi/4)";
  parameter Real q2_t = 0.5236 "Target boom angle [rad]  (pi/6)";
  parameter Real q3_t = 0.30   "Target slide position [m]";

  // --- Timing ---
  parameter Real T_total = 12.0  "Total run time [s]";
  parameter Real T_move  = 8.0   "Motion phase end (hold starts) [s]";
  parameter Real T_d0    = 4.0   "Disturbance start [s]  (middle third begin)";
  parameter Real T_d1    = 8.0   "Disturbance end [s]    (middle third end)";
  parameter Real e_bound = 0.042 "Primary tracking error bound after 7.8 s [rad or m]";

  // --- Derived inertias (algebraic) ---
  Real J1 = m1 * r1 ^ 2 + (m2 + m3) * L1 ^ 2 "Mast effective inertia [kg.m2]";
  Real J2 = m2 * r2 ^ 2 + m3 * (L2 + q3) ^ 2 "Boom effective inertia [kg.m2]";

  // --- Joint states ---
  Real q1(start = 0.0, fixed = true)  "Mast angle [rad]";
  Real q2(start = 0.0, fixed = true)  "Boom angle [rad]";
  Real q3(start = 0.0, fixed = true)  "Slide position [m]";
  Real dq1(start = 0.0, fixed = true) "Mast angular velocity [rad/s]";
  Real dq2(start = 0.0, fixed = true) "Boom angular velocity [rad/s]";
  Real dq3(start = 0.0, fixed = true) "Slide velocity [m/s]";
  Real ddq1 "Mast angular acceleration [rad/s2]";
  Real ddq2 "Boom angular acceleration [rad/s2]";
  Real ddq3 "Slide acceleration [m/s2]";

  // --- Encoder sensor traces ---
  Real q1_enc  "Joint 1 encoder position [rad]";
  Real q2_enc  "Joint 2 encoder position [rad]";
  Real q3_enc  "Joint 3 encoder position [m]";
  Real dq1_enc "Joint 1 encoder velocity [rad/s]";
  Real dq2_enc "Joint 2 encoder velocity [rad/s]";
  Real dq3_enc "Joint 3 encoder velocity [m/s]";

  // --- Reference trajectory ---
  Real q1_ref  "Reference mast angle [rad]";
  Real q2_ref  "Reference boom angle [rad]";
  Real q3_ref  "Reference slide position [m]";
  Real dq1_ref "Reference mast velocity [rad/s]";
  Real dq2_ref "Reference boom velocity [rad/s]";
  Real dq3_ref "Reference slide velocity [m/s]";

  // --- Gravity compensation ---
  Real gc1 "Gravity comp. torque joint 1 [N.m]";
  Real gc2 "Gravity comp. torque joint 2 [N.m]";
  Real gc3 "Gravity comp. force joint 3 [N]";

  // --- Commands ---
  Real tau1_cmd "Raw joint 1 command [N.m]";
  Real tau2_cmd "Raw joint 2 command [N.m]";
  Real F3_cmd   "Raw joint 3 command [N]";
  Real tau1     "Saturated joint 1 torque [N.m]";
  Real tau2     "Saturated joint 2 torque [N.m]";
  Real F3       "Saturated joint 3 force [N]";

  // --- Disturbance generalized forces ---
  Real d_tau1 "Disturbance torque on joint 1 [N.m]";
  Real d_tau2 "Disturbance torque on joint 2 [N.m]";
  Real d_F3   "Disturbance force on joint 3 [N]";
  Boolean dist_on "Disturbance active flag";

  // --- Tracking error ---
  Real e1    "Joint 1 tracking error [rad]";
  Real e2    "Joint 2 tracking error [rad]";
  Real e3    "Joint 3 tracking error [m]";
  Real e_max "Primary (max) tracking error [rad or m]";

equation
  // Disturbance window: middle third (4 s to 8 s)
  dist_on = time >= T_d0 and time < T_d1;

  // Reference: smooth cosine ramp 0 -> target over T_move, then hold
  q1_ref = if time < T_move then
    q1_t * (1.0 - cos(Modelica.Constants.pi * time / T_move)) / 2.0 else q1_t;
  q2_ref = if time < T_move then
    q2_t * (1.0 - cos(Modelica.Constants.pi * time / T_move)) / 2.0 else q2_t;
  q3_ref = if time < T_move then
    q3_t * (1.0 - cos(Modelica.Constants.pi * time / T_move)) / 2.0 else q3_t;

  dq1_ref = if time < T_move then
    q1_t * Modelica.Constants.pi / T_move *
      sin(Modelica.Constants.pi * time / T_move) / 2.0 else 0.0;
  dq2_ref = if time < T_move then
    q2_t * Modelica.Constants.pi / T_move *
      sin(Modelica.Constants.pi * time / T_move) / 2.0 else 0.0;
  dq3_ref = if time < T_move then
    q3_t * Modelica.Constants.pi / T_move *
      sin(Modelica.Constants.pi * time / T_move) / 2.0 else 0.0;

  // Gravity compensation from encoder state
  // Joint 1 rotates about Z (parallel to gravity): zero gravity torque
  gc1 = 0.0;
  // Joint 2 rotates about X: gravity torque from boom and slide weights
  gc2 = g * (m2 * r2 + m3 * (L2 + q3_enc)) * cos(q2_enc);
  // Joint 3 prismatic along boom: gravity component along slide
  gc3 = m3 * g * sin(q2_enc);

  // Disturbance: 7.2 N vertical force at tool tip
  d_tau1 = 0.0;  // Vertical force -> no torque about Z
  d_tau2 = if dist_on then F_dist * (L2 + q3) * cos(q2) else 0.0;
  d_F3   = if dist_on then F_dist * sin(q2) else 0.0;

  // Encoder feedback (ideal joint encoders)
  q1_enc  = q1;
  q2_enc  = q2;
  q3_enc  = q3;
  dq1_enc = dq1;
  dq2_enc = dq2;
  dq3_enc = dq3;

  // PD control with gravity compensation (independent per branch)
  tau1_cmd = Kp1 * (q1_ref - q1_enc) + Kd1 * (dq1_ref - dq1_enc) + gc1;
  tau2_cmd = Kp2 * (q2_ref - q2_enc) + Kd2 * (dq2_ref - dq2_enc) + gc2;
  F3_cmd   = Kp3 * (q3_ref - q3_enc) + Kd3 * (dq3_ref - dq3_enc) + gc3;

  // Command saturation
  tau1 = max(-tau_max, min(tau_max, tau1_cmd));
  tau2 = max(-tau_max, min(tau_max, tau2_cmd));
  F3   = max(-F_max,   min(F_max,   F3_cmd));

  // Plant dynamics (lumped-inertia explicit model)
  // Joint 1: revolute Z, no gravity torque
  J1 * ddq1 = tau1 - d_tau1;
  // Joint 2: revolute X, gravity torque acts in plant
  J2 * ddq2 = tau2 - g * (m2 * r2 + m3 * (L2 + q3)) * cos(q2) - d_tau2;
  // Joint 3: prismatic Y, gravity component along slide
  m3 * ddq3 = F3 - m3 * g * sin(q2) - d_F3;

  // State integration
  der(q1)  = dq1;
  der(q2)  = dq2;
  der(q3)  = dq3;
  der(dq1) = ddq1;
  der(dq2) = ddq2;
  der(dq3) = ddq3;

  // Tracking errors
  e1 = abs(q1 - q1_ref);
  e2 = abs(q2 - q2_ref);
  e3 = abs(q3 - q3_ref);
  e_max = max(e1, max(e2, e3));

  // Joint limit enforcement
  assert(q1 >= q1_lim_neg and q1 <= q1_lim_pos,
    "Joint 1 position limit exceeded");
  assert(q2 >= q2_lim_neg and q2 <= q2_lim_pos,
    "Joint 2 position limit exceeded");
  assert(q3 >= q3_lim_neg and q3 <= q3_lim_pos,
    "Joint 3 position limit exceeded");

  // Primary tracking error bound after 7.8 s
  assert(time < 7.8 or e_max < e_bound,
    "Primary tracking error exceeds bound after 7.8 s");

  // NaN / Inf guard on key physical and control quantities
  assert(q1 == q1 and dq1 == dq1, "NaN detected in joint 1 state");
  assert(q2 == q2 and dq2 == dq2, "NaN detected in joint 2 state");
  assert(q3 == q3 and dq3 == dq3, "NaN detected in joint 3 state");
  assert(tau1 == tau1 and tau2 == tau2 and F3 == F3,
    "NaN detected in control commands");

annotation(
  experiment(
    StartTime  = 0.0,
    StopTime   = 12.0,
    Tolerance = 1e-6,
    Interval  = 0.008
  ),
  Documentation(info = "ForkArmPointC: fixed-base 3-DOF articulated manipulator.

  Plant: 24 kg pedestal (fixed) carries a revolute-Z mast (7 kg),
  branching into a revolute-X camera boom (3 kg) and a prismatic-Y
  tool slide (2 kg). Three effort actuators (torque/torque/force)
  independently drive the branches with encoder position and velocity
  feedback.

  Control: per-joint PD with gravity compensation. Command saturation
  at 73.6 N.m (revolute) and 700 N (prismatic).

  Trajectory: cosine ramp from zero state to declared target over 8 s,
  hold for final third (8-12 s). A 7.2 N vertical tip load disturbance
  is injected during the middle third (4-8 s).

  Requirement: primary tracking error < 0.042 rad-or-m after 7.8 s.
  No NaN or infinite physical, control, or estimator values.

  Gravity 9.81 m/s2. Collision geometry declared for every link.
  Simulation at 125 Hz (interval 0.008 s) for 12 s with synchronized
  state, command, and sensor traces.

  NOTE: Exact link lengths, CG offsets, control gains, and target
  pose are NOT specified in the requirement. They are declared here
  as self-contained design parameters to produce a compilable,
  simulatable, and FMI-exportable model.")
);
end ForkArmPointC;