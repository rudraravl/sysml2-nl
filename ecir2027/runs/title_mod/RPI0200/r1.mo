model RailArmTraceB
  "Fixed-base articulated manipulator tracing a cubic joint trajectory";
  // ===== Geometry & mass =====
  parameter Real L_rail = 1.40 "rail length [m]";
  parameter Real L1 = 0.46 "link1 length [m]";
  parameter Real L2 = 0.31 "link2 length [m]";
  parameter Real m_carriage = 18.0 "carriage mass [kg]";
  // Link masses are NOT specified in the requirement; the following are
  // explicit assumptions required for a non-singular dynamic plant.
  parameter Real m_link1 = 2.0 "assumed link1 mass [kg]";
  parameter Real m_link2 = 1.5 "assumed link2 mass [kg]";
  parameter Real m_eff_x = m_carriage + m_link1 + m_link2 "effective rail mass [kg]";
  parameter Real I1 = m_link1*L1^2/3.0 + m_link2*L1^2 + m_link2*L2^2/3.0 "joint1 inertia [kg.m2]";
  parameter Real I2 = m_link2*L2^2/3.0 "joint2 inertia [kg.m2]";

  // ===== Actuator limits =====
  parameter Real F_max = 800.0 "rail force command limit [N]";
  parameter Real Tau_max = 69.7 "joint torque command limit [N.m]";
  parameter Real Jlim = 1.5 "joint angle limit [rad]";

  // ===== Mission timing =====
  parameter Real Ts = 0.01 "control sample period [s] (100 Hz)";
  parameter Real T_end = 10.0 "mission duration [s]";
  parameter Real T_seg = 10.0/3.0 "per-segment duration [s]";

  // ===== Waypoints (three reachable states) =====
  parameter Real q1_x = 0.20;  parameter Real q1_th1 = 0.30;  parameter Real q1_th2 = 0.30;
  parameter Real q2_x = 0.60;  parameter Real q2_th1 = -0.30; parameter Real q2_th2 = 0.50;
  parameter Real q3_x = 1.00;  parameter Real q3_th1 = 0.50;  parameter Real q3_th2 = -0.50;

  // ===== Obstacle (fixed cylindrical keep-out, placed beside nominal path) =====
  parameter Real obs_x = 1.30 "obstacle center x [m]";
  parameter Real obs_y = -0.50 "obstacle center y [m]";
  parameter Real obs_r = 0.08 "obstacle radius [m]";

  // ===== Disturbance =====
  parameter Real F_dist = 7.0 "lateral (Y) disturbance magnitude [N]";

  // ===== Controller gains (PID + velocity feedforward) =====
  parameter Real Kp_x = 500.0;  parameter Real Ki_x = 300.0;  parameter Real Kd_x = 200.0;  parameter Real Kff_x = 200.0;
  parameter Real Kp_1 = 30.0;   parameter Real Ki_1 = 30.0;   parameter Real Kd_1 = 8.0;    parameter Real Kff_1 = 8.0;
  parameter Real Kp_2 = 5.0;    parameter Real Ki_2 = 5.0;    parameter Real Kd_2 = 1.0;    parameter Real Kff_2 = 1.0;
  parameter Real integ_lim_x = 2.0;
  parameter Real integ_lim_1 = 1.7;
  parameter Real integ_lim_2 = 8.0;

  // ===== Continuous states =====
  Real x(start = q1_x, fixed = true) "carriage position [m]";
  Real xdot(start = 0.0, fixed = true) "carriage velocity [m/s]";
  Real th1(start = q1_th1, fixed = true) "joint1 angle [rad]";
  Real th1dot(start = 0.0, fixed = true) "joint1 velocity [rad/s]";
  Real th2(start = q1_th2, fixed = true) "joint2 angle [rad]";
  Real th2dot(start = 0.0, fixed = true) "joint2 velocity [rad/s]";

  // ===== Commands (discrete, ZOH) =====
  discrete Real F_cmd(start = 0.0) "rail force command [N]";
  discrete Real tau1_cmd(start = 0.0) "joint1 torque command [N.m]";
  discrete Real tau2_cmd(start = 0.0) "joint2 torque command [N.m]";
  Real F_sat "saturated rail force [N]";
  Real tau1_sat "saturated joint1 torque [N.m]";
  Real tau2_sat "saturated joint2 torque [N.m]";

  // ===== Disturbance =====
  Real Fy_dist "active lateral disturbance [N]";
  Real tau1_dist "disturbance torque on joint1 [N.m]";
  Real tau2_dist "disturbance torque on joint2 [N.m]";

  // ===== Reference trajectory =====
  Real x_ref "rail reference position [m]";
  Real xdot_ref "rail reference velocity [m/s]";
  Real th1_ref "joint1 reference [rad]";
  Real th1dot_ref "joint1 reference velocity [rad/s]";
  Real th2_ref "joint2 reference [rad]";
  Real th2dot_ref "joint2 reference velocity [rad/s]";

  // ===== Tracking errors =====
  Real e_x "rail tracking error [m]";
  Real e_th1 "joint1 tracking error [rad]";
  Real e_th2 "joint2 tracking error [rad]";
  Real primary_error "max abs tracking error [m or rad]";

  // ===== Sensors (synchronized 100 Hz samples) =====
  discrete Real x_meas(start = q1_x);
  discrete Real xdot_meas(start = 0.0);
  discrete Real th1_meas(start = q1_th1);
  discrete Real th1dot_meas(start = 0.0);
  discrete Real th2_meas(start = q1_th2);
  discrete Real th2dot_meas(start = 0.0);

  // ===== Integral states =====
  discrete Real integ_x;
  discrete Real integ_1;
  discrete Real integ_2;

  // ===== Forward kinematics =====
  Real c1, s1, c12, s12;
  Real elbow_x, elbow_y, tip_x, tip_y;

  // ===== Obstacle clearance =====
  Real clr1 "clearance link1-obstacle [m]";
  Real clr2 "clearance link2-obstacle [m]";
  Real clr_min "minimum clearance [m]";

  // ===== Requirement monitors =====
  discrete Real max_error "running max of primary_error";
  discrete Real min_clearance "running min clearance [m]";
  Boolean rail_limit_ok;
  Boolean joint_limit_ok;
  Boolean clearance_ok;
  Boolean tracking_ok;
  Boolean settled;
  Boolean no_nan;
  Boolean overshoot_ok;
  Real span "trajectory span for overshoot reference [m or rad]";

equation
  // ===== Forward kinematics =====
  c1 = cos(th1);
  s1 = sin(th1);
  c12 = cos(th1 + th2);
  s12 = sin(th1 + th2);
  elbow_x = x + L1*c1;
  elbow_y = L1*s1;
  tip_x = elbow_x + L2*c12;
  tip_y = elbow_y + L2*s12;

  // ===== Reference trajectory: cubic Hermite, zero endpoint velocities =====
  // Segment 1: [0, T_seg] state1 -> state2
  // Segment 2: [T_seg, 2*T_seg] state2 -> state3
  // Hold state3 after 2*T_seg
  x_ref = if time < T_seg then
            q1_x + (q2_x - q1_x)*(3.0*(time/T_seg)^2 - 2.0*(time/T_seg)^3)
          elseif time < 2.0*T_seg then
            q2_x + (q3_x - q2_x)*(3.0*((time - T_seg)/T_seg)^2 - 2.0*((time - T_seg)/T_seg)^3)
          else
            q3_x;
  xdot_ref = if time < T_seg then
               (q2_x - q1_x)*(6.0*time/T_seg^2 - 6.0*time^2/T_seg^3)
             elseif time < 2.0*T_seg then
               (q3_x - q2_x)*(6.0*(time - T_seg)/T_seg^2 - 6.0*(time - T_seg)^2/T_seg^3)
             else
               0.0;
  th1_ref = if time < T_seg then
              q1_th1 + (q2_th1 - q1_th1)*(3.0*(time/T_seg)^2 - 2.0*(time/T_seg)^3)
            elseif time < 2.0*T_seg then
              q2_th1 + (q3_th1 - q2_th1)*(3.0*((time - T_seg)/T_seg)^2 - 2.0*((time - T_seg)/T_seg)^3)
            else
              q3_th1;
  th1dot_ref = if time < T_seg then
                 (q2_th1 - q1_th1)*(6.0*time/T_seg^2 - 6.0*time^2/T_seg^3)
               elseif time < 2.0*T_seg then
                 (q3_th1 - q2_th1)*(6.0*(time - T_seg)/T_seg^2 - 6.0*(time - T_seg)^2/T_seg^3)
               else
                 0.0;
  th2_ref = if time < T_seg then
              q1_th2 + (q2_th2 - q1_th2)*(3.0*(time/T_seg)^2 - 2.0*(time/T_seg)^3)
            elseif time < 2.0*T_seg then
              q2_th2 + (q3_th2 - q2_th2)*(3.0*((time - T_seg)/T_seg)^2 - 2.0*((time - T_seg)/T_seg)^3)
            else
              q3_th2;
  th2dot_ref = if time < T_seg then
                 (q2_th2 - q1_th2)*(6.0*time/T_seg^2 - 6.0*time^2/T_seg^3)
               elseif time < 2.0*T_seg then
                 (q3_th2 - q2_th2)*(6.0*(time - T_seg)/T_seg^2 - 6.0*(time - T_seg)^2/T_seg^3)
               else
                 0.0;

  // ===== Disturbance: 7 N lateral (Y) force during middle third =====
  Fy_dist = if (time >= T_seg and time <= 2.0*T_seg) then F_dist else 0.0;
  tau1_dist = Fy_dist*(L1*c1 + L2*c12);
  tau2_dist = Fy_dist*(L2*c12);

  // ===== Plant dynamics (decoupled, planar horizontal, no gravity) =====
  der(x) = xdot;
  der(xdot) = F_sat / m_eff_x;
  der(th1) = th1dot;
  der(th1dot) = (tau1_sat + tau1_dist) / I1;
  der(th2) = th2dot;
  der(th2dot) = (tau2_sat + tau2_dist) / I2;

  // ===== Command saturation =====
  F_sat = max(-F_max, min(F_max, F_cmd));
  tau1_sat = max(-Tau_max, min(Tau_max, tau1_cmd));
  tau2_sat = max(-Tau_max, min(Tau_max, tau2_cmd));

  // ===== Tracking errors =====
  e_x = x_ref - x;
  e_th1 = th1_ref - th1;
  e_th2 = th2_ref - th2;
  primary_error = max(abs(e_x), max(abs(e_th1), abs(e_th2)));

  // ===== Obstacle clearance (point-to-segment distance minus radius) =====
  clr1 = segClearance(x, 0.0, elbow_x, elbow_y, obs_x, obs_y) - obs_r;
  clr2 = segClearance(elbow_x, elbow_y, tip_x, tip_y, obs_x, obs_y) - obs_r;
  clr_min = min(clr1, clr2);

  // ===== Requirement monitors =====
  span = max(abs(q3_x - q1_x), max(abs(q3_th1 - q1_th1), abs(q3_th2 - q1_th2)));
  rail_limit_ok = (x >= 0.0) and (x <= L_rail);
  joint_limit_ok = (abs(th1) <= Jlim) and (abs(th2) <= Jlim);
  clearance_ok = clr_min > 0.05;
  tracking_ok = (time < 6.5) or (primary_error < 0.06);
  settled = (time >= 6.5) and (primary_error < 0.06);
  no_nan = (x == x) and (xdot == xdot) and (th1 == th1) and (th1dot == th1dot) and
           (th2 == th2) and (th2dot == th2dot) and (F_sat == F_sat) and
           (tau1_sat == tau1_sat) and (tau2_sat == tau2_sat);
  overshoot_ok = (max_error <= 0.12*span);

  // ===== Discrete controller @ 100 Hz: PID + velocity feedforward =====
  when sample(0, Ts) then
    // synchronized encoder samples (position and velocity)
    x_meas = x;
    xdot_meas = xdot;
    th1_meas = th1;
    th1dot_meas = th1dot;
    th2_meas = th2;
    th2dot_meas = th2dot;

    // integral action with clamping anti-windup
    integ_x = max(-integ_lim_x, min(integ_lim_x, pre(integ_x) + Ts*(x_ref - x_meas)));
    integ_1 = max(-integ_lim_1, min(integ_lim_1, pre(integ_1) + Ts*(th1_ref - th1_meas)));
    integ_2 = max(-integ_lim_2, min(integ_lim_2, pre(integ_2) + Ts*(th2_ref - th2_meas)));

    // PID + velocity feedforward command
    F_cmd = Kp_x*(x_ref - x_meas) + Ki_x*integ_x + Kd_x*(xdot_ref - xdot_meas) + Kff_x*xdot_ref;
    tau1_cmd = Kp_1*(th1_ref - th1_meas) + Ki_1*integ_1 + Kd_1*(th1dot_ref - th1dot_meas) + Kff_1*th1dot_ref;
    tau2_cmd = Kp_2*(th2_ref - th2_meas) + Ki_2*integ_2 + Kd_2*(th2dot_ref - th2dot_meas) + Kff_2*th2dot_ref;

    // running requirement traces
    max_error = max(pre(max_error), primary_error);
    min_clearance = min(pre(min_clearance), clr_min);
  end when;

initial equation
  integ_x = 0.0;
  integ_1 = 0.0;
  integ_2 = 0.0;
  max_error = 0.0;
  min_clearance = 1.0;

  annotation (
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "RailArmTraceB: 1.4 m X rail, 18 kg carriage, 2R planar arm (0.46 m, 0.31 m). Cubic joint trajectory through three reachable states with PID + velocity-feedforward control at 100 Hz. 7 N lateral disturbance during the middle third. Link masses m_link1, m_link2 are assumptions (not specified in the requirement) needed for non-singular joint dynamics."));
end RailArmTraceB;