model DuoArmRejectF
  /* DuoArmRejectF : 2-DOF fixed-base articulated manipulator.
     Mission: hold nonzero joint target while rejecting a finite-duration
     lateral (X) load at the distal link tip.
     Gravity modeled; self-collision between nonadjacent links (link 2 vs
     the 20 kg box pedestal) is represented by a soft repulsive penalty
     and joint-limit penalties; joint limits +/- 1.6 rad enforced.
     Saturated state-feedback with integral disturbance rejection.
     Disturbance 26.1 N applied during the middle third of the 20 s run
     (6.667 s .. 13.333 s).
     Verification (declared, checked post-sim):
       - finite states, no NaN/Inf in physical/control/estimator signals
       - no self-collision (|q1|,|q2| < 1.6 rad)
       - peak deviation < 0.18 rad
       - primary tracking error < 0.028 rad after 13 s
       - recovery to target band
  */

  // ---- Link / base parameters (SI) ----
  parameter Real m_ped   = 20.0  "pedestal mass kg (fixed base)";
  parameter Real m1      = 5.0   "link 1 mass kg";
  parameter Real m2      = 3.0   "link 2 mass kg";
  parameter Real l1      = 0.55  "link 1 length m";
  parameter Real l2      = 0.38  "link 2 length m";
  parameter Real g       = 9.81  "m/s2";
  parameter Real q_limit = 1.6   "rad joint limit";
  parameter Real tau_max = 85.4  "N.m actuator limit";
  parameter Real Ts      = 0.002 "s control period (500 Hz)";

  // ---- Mission target (nonzero) ----
  parameter Real q1_ref = 0.7  "rad";
  parameter Real q2_ref = -0.5 "rad";

  // ---- Disturbance ----
  parameter Real F_dist  = 26.1 "N lateral load at distal tip";
  parameter Real t_start = 6.6666666667 "s middle-third start";
  parameter Real t_end   = 13.333333333 "s middle-third end";

  // ---- Controller gains ----
  parameter Real Kp1 = 150.0;
  parameter Real Kp2 = 100.0;
  parameter Real Kd1 = 25.0;
  parameter Real Kd2 = 15.0;
  parameter Real Ki1 = 150.0;
  parameter Real Ki2 = 80.0;
  parameter Real integ1_max = 0.5 "anti-windup clamp";
  parameter Real integ2_max = 0.5 "anti-windup clamp";

  // ---- Derived inertial constants ----
  parameter Real r1 = l1/2        "m com offset link1";
  parameter Real r2 = l2/2        "m com offset link2";
  parameter Real I1 = m1*l1*l1/12 "kg.m2 link1 inertia about com";
  parameter Real I2 = m2*l2*l2/12 "kg.m2 link2 inertia about com";

  // ---- Continuous states ----
  Real q1(start = q1_ref, fixed = true) "rad";
  Real q2(start = q2_ref, fixed = true) "rad";
  Real qd1(start = 0.0, fixed = true)   "rad/s";
  Real qd2(start = 0.0, fixed = true)   "rad/s";

  // ---- Dynamics intermediates ----
  Real M11, M12, M22;
  Real C1, C2;
  Real G1, G2;
  Real ddq1, ddq2;

  // ---- Actuators ----
  Real tau1_act "N.m applied (post-saturation) joint1";
  Real tau2_act "N.m applied (post-saturation) joint2";

  // ---- Discrete controller (500 Hz) ----
  discrete Real tau1_cmd(start = 0.0) "N.m commanded joint1";
  discrete Real tau2_cmd(start = 0.0) "N.m commanded joint2";
  discrete Real integ1(start = 0.0)   "integral state joint1";
  discrete Real integ2(start = 0.0)   "integral state joint2";

  // ---- External load ----
  Real Fx_ext   "N lateral force at tip";
  Real tau1_ext "N.m joint torque from load";
  Real tau2_ext "N.m joint torque from load";

  // ---- Collision / limit penalties ----
  Real tau1_lim "N.m soft joint-limit penalty";
  Real tau2_lim "N.m soft joint-limit penalty";
  Real tau_coll_base "N.m base self-collision penalty on joint1";
  Boolean collision_violation;

  // ---- End-effector kinematics ----
  Real x_ee "m";
  Real z_ee "m";

  // ---- Estimator (state estimate = sensor reading, ideal encoders) ----
  Real q1_hat(start = q1_ref) "rad encoder estimate";
  Real q2_hat(start = q2_ref) "rad encoder estimate";
  Real qd1_hat "rad/s";
  Real qd2_hat "rad/s";

  // ---- Tracking metrics (observable) ----
  Real err1 "rad";
  Real err2 "rad";
  discrete Real peak_dev(start = 0.0) "rad";

equation
  // ===== Manipulator dynamics (planar, revolute about Y, motion in X-Z) =====
  M11 = I1 + I2 + m1*r1*r1 + m2*(l1*l1 + r2*r2 + 2.0*l1*r2*cos(q2));
  M12 = I2 + m2*(r2*r2 + l1*r2*cos(q2));
  M22 = I2 + m2*r2*r2;

  C1 = -m2*l1*r2*sin(q2)*qd2*qd2 - 2.0*m2*l1*r2*sin(q2)*qd1*qd2;
  C2 =  m2*l1*r2*sin(q2)*qd1*qd1;

  G1 = (m1*r1 + m2*l1)*g*cos(q1) + m2*r2*g*cos(q1 + q2);
  G2 = m2*r2*g*cos(q1 + q2);

  // ===== External lateral disturbance at tip =====
  Fx_ext = if (time >= t_start and time <= t_end) then F_dist else 0.0;
  tau1_ext = -Fx_ext*(l1*sin(q1) + l2*sin(q1 + q2));
  tau2_ext = -Fx_ext*l2*sin(q1 + q2);

  // ===== Soft joint-limit penalty (prevents exceeding +/- q_limit) =====
  tau1_lim = if q1 > (q_limit - 0.05) then
               -tau_max*20.0*(q1 - (q_limit - 0.05))
             elseif q1 < -(q_limit - 0.05) then
               -tau_max*20.0*(q1 + (q_limit - 0.05))
             else 0.0;
  tau2_lim = if q2 > (q_limit - 0.05) then
               -tau_max*20.0*(q2 - (q_limit - 0.05))
             elseif q2 < -(q_limit - 0.05) then
               -tau_max*20.0*(q2 + (q_limit - 0.05))
             else 0.0;

  // ===== Soft base self-collision penalty (link 2 folding into pedestal) =====
  // Pedestal box approximated as half-width 0.15 m about origin.
  // Penalty activates when link-2 proximal segment dips toward base region.
  tau_coll_base = if (z_ee < 0.20 and x_ee*x_ee + z_ee*z_ee < 0.30*0.30)
                  then -tau_max*15.0*(0.30 - sqrt(x_ee*x_ee + z_ee*z_ee + 1e-9))
                  else 0.0;

  // ===== Saturated actuator =====
  tau1_act = max(-tau_max, min(tau_max, tau1_cmd));
  tau2_act = max(-tau_max, min(tau_max, tau2_cmd));

  // ===== Equations of motion =====
  M11*ddq1 + M12*ddq2 + C1 + G1 = tau1_act + tau1_ext + tau1_lim + tau_coll_base;
  M12*ddq1 + M22*ddq2 + C2 + G2 = tau2_act + tau2_ext + tau2_lim;

  der(q1)  = qd1;
  der(q2)  = qd2;
  der(qd1) = ddq1;
  der(qd2) = ddq2;

  // ===== End-effector position =====
  x_ee = l1*cos(q1) + l2*cos(q1 + q2);
  z_ee = l1*sin(q1) + l2*sin(q1 + q2);

  // ===== Ideal encoder estimator (state observation) =====
  q1_hat  = q1;
  q2_hat  = q2;
  qd1_hat = qd1;
  qd2_hat = qd2;

  // ===== Tracking error =====
  err1 = q1_ref - q1;
  err2 = q2_ref - q2;

  // ===== Self-collision flag =====
  collision_violation = (abs(q1) >= q_limit) or (abs(q2) >= q_limit);

  // ===== Discrete saturated state-feedback + integral disturbance rejection =====
  when sample(0.0, Ts) then
    // integral with anti-windup clamp
    integ1 = max(-integ1_max, min(integ1_max, pre(integ1) + Ts*(q1_ref - q1)));
    integ2 = max(-integ2_max, min(integ2_max, pre(integ2) + Ts*(q2_ref - q2)));

    // gravity feedforward + state feedback + integral
    tau1_cmd = Kp1*(q1_ref - q1) - Kd1*qd1 + Ki1*integ1 + G1;
    tau2_cmd = Kp2*(q2_ref - q2) - Kd2*qd2 + Ki2*integ2 + G2;

    // peak deviation bookkeeping
    peak_dev = max(pre(peak_dev), max(abs(q1 - q1_ref), abs(q2 - q2_ref)));
  end when;

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "DuoArmRejectF: fixed-base 2-DOF articulated manipulator holding a nonzero target while rejecting a 26.1 N lateral load applied during the middle third of a 20 s, 500 Hz run.")
  );
end DuoArmRejectF;