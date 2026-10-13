model AssemblyArmRejectF
  "4-DOF fixed-base articulated manipulator: saturated state-feedback with integral disturbance rejection"
  // Simulation: configure solver step to 0.002 s for 500 Hz, stop time 20 s.

  // ==================== Link parameters ====================
  parameter Modelica.Units.SI.Length L1 = 0.50 "Link 1 length [m]";
  parameter Modelica.Units.SI.Length L2 = 0.40 "Link 2 length [m]";
  parameter Modelica.Units.SI.Length L3 = 0.28 "Link 3 length [m]";
  parameter Modelica.Units.SI.Length L4 = 0.16 "Link 4 length [m]";
  parameter Modelica.Units.SI.Mass m1 = 7.0 "Link 1 mass [kg]";
  parameter Modelica.Units.SI.Mass m2 = 5.0 "Link 2 mass [kg]";
  parameter Modelica.Units.SI.Mass m3 = 3.0 "Link 3 mass [kg]";
  parameter Modelica.Units.SI.Mass m4 = 1.0 "Link 4 mass [kg]";
  parameter Modelica.Units.SI.Acceleration g_const = 9.81 "Gravity [m/s2]";

  // ==================== Actuation ====================
  parameter Modelica.Units.SI.Torque tau_max = 134.0 "Maximum motor torque [N.m]";

  // ==================== Joint targets ====================
  parameter Modelica.Units.SI.Angle q1_t = 0.50 "Joint 1 target (Z-axis) [rad]";
  parameter Modelica.Units.SI.Angle q2_t = 0.30 "Joint 2 target (Y-axis) [rad]";
  parameter Modelica.Units.SI.Angle q3_t = -0.20 "Joint 3 target (Y-axis) [rad]";
  parameter Modelica.Units.SI.Angle q4_t = 0.10 "Joint 4 target (X-axis) [rad]";

  // ==================== Control gains ====================
  parameter Real Kp1 = 500.0 "Joint 1 proportional gain";
  parameter Real Kp2 = 800.0 "Joint 2 proportional gain";
  parameter Real Kp3 = 400.0 "Joint 3 proportional gain";
  parameter Real Kp4 = 200.0 "Joint 4 proportional gain";
  parameter Real Kd1 = 50.0 "Joint 1 derivative gain";
  parameter Real Kd2 = 60.0 "Joint 2 derivative gain";
  parameter Real Kd3 = 30.0 "Joint 3 derivative gain";
  parameter Real Kd4 = 15.0 "Joint 4 derivative gain";
  parameter Real Ki1 = 200.0 "Joint 1 integral gain";
  parameter Real Ki2 = 300.0 "Joint 2 integral gain";
  parameter Real Ki3 = 150.0 "Joint 3 integral gain";
  parameter Real Ki4 = 80.0 "Joint 4 integral gain";
  parameter Real Kaw1 = 5.0 "Joint 1 anti-windup gain";
  parameter Real Kaw2 = 5.0 "Joint 2 anti-windup gain";
  parameter Real Kaw3 = 5.0 "Joint 3 anti-windup gain";
  parameter Real Kaw4 = 5.0 "Joint 4 anti-windup gain";

  // ==================== Joint damping ====================
  parameter Real b1 = 0.8 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.6 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 0.4 "Joint 3 viscous damping [N.m.s/rad]";
  parameter Real b4 = 0.2 "Joint 4 viscous damping [N.m.s/rad]";

  // ==================== Disturbance ====================
  parameter Modelica.Units.SI.Force F_dist = 26.1 "Disturbance force magnitude [N]";
  parameter Modelica.Units.SI.Time t_on = 6.6667 "Disturbance start (middle third) [s]";
  parameter Modelica.Units.SI.Time t_off = 13.3333 "Disturbance end (middle third) [s]";

  // ==================== Collision threshold ====================
  // NOTE: capsule radii not specified in requirement; conservative default used.
  parameter Modelica.Units.SI.Length clr_thresh = 0.02 "Minimum nonadjacent link clearance [m]";

  // ==================== Lumped inertias ====================
  parameter Modelica.Units.SI.Inertia J1 = m1*L1*L1/3.0 + (m2+m3+m4)*L1*L1;
  parameter Modelica.Units.SI.Inertia J2 = m2*L2*L2/3.0 + (m3+m4)*L2*L2;
  parameter Modelica.Units.SI.Inertia J3 = m3*L3*L3/3.0 + m4*L3*L3;
  parameter Modelica.Units.SI.Inertia J4 = m4*L4*L4/3.0;

  // ==================== Dynamic states ====================
  Modelica.Units.SI.Angle q1(start = 0.50) "Joint 1 angle (Z-axis) [rad]";
  Modelica.Units.SI.Angle q2(start = 0.30) "Joint 2 angle (Y-axis) [rad]";
  Modelica.Units.SI.Angle q3(start = -0.20) "Joint 3 angle (Y-axis) [rad]";
  Modelica.Units.SI.Angle q4(start = 0.10) "Joint 4 angle (X-axis) [rad]";
  Modelica.Units.SI.AngularVelocity dq1(start = 0.0) "Joint 1 velocity [rad/s]";
  Modelica.Units.SI.AngularVelocity dq2(start = 0.0) "Joint 2 velocity [rad/s]";
  Modelica.Units.SI.AngularVelocity dq3(start = 0.0) "Joint 3 velocity [rad/s]";
  Modelica.Units.SI.AngularVelocity dq4(start = 0.0) "Joint 4 velocity [rad/s]";

  // Integral disturbance-rejection states
  Real xi1(start = 0.0) "Integral error joint 1";
  Real xi2(start = 0.0) "Integral error joint 2";
  Real xi3(start = 0.0) "Integral error joint 3";
  Real xi4(start = 0.0) "Integral error joint 4";

  // ==================== Control signals ====================
  Modelica.Units.SI.Torque tau1_cmd "Unsaturated command joint 1 [N.m]";
  Modelica.Units.SI.Torque tau2_cmd "Unsaturated command joint 2 [N.m]";
  Modelica.Units.SI.Torque tau3_cmd "Unsaturated command joint 3 [N.m]";
  Modelica.Units.SI.Torque tau4_cmd "Unsaturated command joint 4 [N.m]";
  Modelica.Units.SI.Torque tau1 "Saturated torque joint 1 [N.m]";
  Modelica.Units.SI.Torque tau2 "Saturated torque joint 2 [N.m]";
  Modelica.Units.SI.Torque tau3 "Saturated torque joint 3 [N.m]";
  Modelica.Units.SI.Torque tau4 "Saturated torque joint 4 [N.m]";

  // ==================== Disturbance torques ====================
  Modelica.Units.SI.Force F_active "Active disturbance force [N]";
  Modelica.Units.SI.Torque td1 "Disturbance torque joint 1 [N.m]";
  Modelica.Units.SI.Torque td2 "Disturbance torque joint 2 [N.m]";
  Modelica.Units.SI.Torque td3 "Disturbance torque joint 3 [N.m]";
  Modelica.Units.SI.Torque td4 "Disturbance torque joint 4 [N.m]";

  // ==================== Gravity torques ====================
  Modelica.Units.SI.Torque tg2 "Gravity torque joint 2 [N.m]";
  Modelica.Units.SI.Torque tg3 "Gravity torque joint 3 [N.m]";

  // ==================== Sensors and verification ====================
  Modelica.Units.SI.Force wrist_wrench "Wrist wrench sensor [N]";
  Real track_err "Maximum absolute joint tracking error [rad]";
  Real peak_dev(start = 0.0) "Peak deviation observed so far [rad]";
  Boolean recovered "True if tracking error below 0.028 rad after 13 s";
  Boolean no_coll "True if no self-collision detected";

  // ==================== Forward kinematics (planar) ====================
  Real x_l1c "Link 1 center x [m]";
  Real y_l1c "Link 1 center y [m]";
  Real x_l2c "Link 2 center x [m]";
  Real y_l2c "Link 2 center y [m]";
  Real x_l3c "Link 3 center x [m]";
  Real y_l3c "Link 3 center y [m]";
  Real x_l4c "Link 4 center x [m]";
  Real y_l4c "Link 4 center y [m]";
  Real d_13 "Clearance between links 1 and 3 [m]";
  Real d_14 "Clearance between links 1 and 4 [m]";
  Real d_24 "Clearance between links 2 and 4 [m]";
  Real min_clr "Minimum nonadjacent link clearance [m]";

equation
  // ========== Disturbance activation (middle third of 20 s) ==========
  F_active = if time >= t_on and time <= t_off then F_dist else 0.0;

  // ========== Forward kinematics (planar projection; q4 is X-roll, no planar displacement) ==========
  x_l1c = 0.5*L1*cos(q2);
  y_l1c = 0.5*L1*sin(q2);
  x_l2c = L1*cos(q2) + 0.5*L2*cos(q2 + q3);
  y_l2c = L1*sin(q2) + 0.5*L2*sin(q2 + q3);
  x_l3c = L1*cos(q2) + L2*cos(q2 + q3) + 0.5*L3*cos(q2 + q3);
  y_l3c = L1*sin(q2) + L2*sin(q2 + q3) + 0.5*L3*sin(q2 + q3);
  x_l4c = L1*cos(q2) + (L2 + L3)*cos(q2 + q3) + 0.5*L4*cos(q2 + q3);
  y_l4c = L1*sin(q2) + (L2 + L3)*sin(q2 + q3) + 0.5*L4*sin(q2 + q3);

  // ========== Self-collision detection (nonadjacent: 1-3, 1-4, 2-4) ==========
  d_13 = sqrt((x_l1c - x_l3c)*(x_l1c - x_l3c) + (y_l1c - y_l3c)*(y_l1c - y_l3c));
  d_14 = sqrt((x_l1c - x_l4c)*(x_l1c - x_l4c) + (y_l1c - y_l4c)*(y_l1c - y_l4c));
  d_24 = sqrt((x_l2c - x_l4c)*(x_l2c - x_l4c) + (y_l2c - y_l4c)*(y_l2c - y_l4c));
  min_clr = min(d_13, min(d_14, d_24));
  no_coll = min_clr > clr_thresh;

  // ========== Gravity torques (potential energy derivatives) ==========
  // Joint 1 (Z-axis) and joint 4 (X-roll): no gravity torque
  tg2 = -g_const*cos(q2)*(0.5*m1*L1 + (m2+m3+m4)*L1)
        - g_const*cos(q2+q3)*(0.5*m2*L2 + m3*(L2+0.5*L3) + m4*(L2+L3+0.5*L4));
  tg3 = -g_const*cos(q2+q3)*(0.5*m2*L2 + m3*(L2+0.5*L3) + m4*(L2+L3+0.5*L4));

  // ========== Disturbance torques (lateral force at distal link) ==========
  td1 = F_active * 0.3;
  td2 = F_active * (-L1*sin(q2) - (L2+L3+L4)*sin(q2+q3));
  td3 = F_active * (-(L2+L3+L4)*sin(q2+q3));
  td4 = F_active * 0.1;

  // ========== Saturated state-feedback control with integral ==========
  tau1_cmd = Kp1*(q1_t - q1) - Kd1*dq1 + Ki1*xi1;
  tau2_cmd = Kp2*(q2_t - q2) - Kd2*dq2 + Ki2*xi2;
  tau3_cmd = Kp3*(q3_t - q3) - Kd3*dq3 + Ki3*xi3;
  tau4_cmd = Kp4*(q4_t - q4) - Kd4*dq4 + Ki4*xi4;

  // Torque saturation (effort limit 134 N.m)
  tau1 = max(-tau_max, min(tau_max, tau1_cmd));
  tau2 = max(-tau_max, min(tau_max, tau2_cmd));
  tau3 = max(-tau_max, min(tau_max, tau3_cmd));
  tau4 = max(-tau_max, min(tau_max, tau4_cmd));

  // Anti-windup via back-calculation
  der(xi1) = (q1_t - q1) - Kaw1*(tau1_cmd - tau1);
  der(xi2) = (q2_t - q2) - Kaw2*(tau2_cmd - tau2);
  der(xi3) = (q3_t - q3) - Kaw3*(tau3_cmd - tau3);
  der(xi4) = (q4_t - q4) - Kaw4*(tau4_cmd - tau4);

  // ========== Plant dynamics (lumped-inertia decoupled model) ==========
  J1*der(dq1) = tau1 - b1*dq1 + td1;
  J2*der(dq2) = tau2 - b2*dq2 + tg2 + td2;
  J3*der(dq3) = tau3 - b3*dq3 + tg3 + td3;
  J4*der(dq4) = tau4 - b4*dq4 + td4;

  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;

  // ========== Sensors ==========
  wrist_wrench = F_active;
  track_err = max(abs(q1 - q1_t), max(abs(q2 - q2_t), max(abs(q3 - q3_t), abs(q4 - q4_t))));
  recovered = time >= 13.0 and track_err < 0.028;

  // ========== Peak deviation tracker ==========
  der(peak_dev) = 0.0;
  when track_err > pre(peak_dev) then
    reinit(peak_dev, track_err);
  end when;

end AssemblyArmRejectF;