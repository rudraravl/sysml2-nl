model AssemblyArmTraceA
  "Fixed-base articulated manipulator: 4-DOF Z-Y-Y-X with PID+FF trajectory control";

  // ===== Link parameters =====
  parameter Real L1 = 0.50 "Link 1 length (m)";
  parameter Real L2 = 0.40 "Link 2 length (m)";
  parameter Real L3 = 0.28 "Link 3 length (m)";
  parameter Real L4 = 0.16 "Link 4 length (m)";
  parameter Real m1 = 7.0  "Link 1 mass (kg)";
  parameter Real m2 = 5.0  "Link 2 mass (kg)";
  parameter Real m3 = 3.0  "Link 3 mass (kg)";
  parameter Real m4 = 1.0  "Link 4 mass (kg)";

  // ===== Actuator limit =====
  parameter Real tau_max = 79.2 "Command magnitude limit (N.m)";

  // ===== Sampling and timing =====
  parameter Real Ts = 1.0/80.0     "Encoder sample period (s)";
  parameter Real T_end = 8.0       "Scenario duration (s)";
  parameter Real tB = 8.0/3.0      "Second state time (s)";
  parameter Real tC = 16.0/3.0     "Third state time (s)";
  parameter Real t_dist_start = 8.0/3.0  "Disturbance start (s)";
  parameter Real t_dist_end = 16.0/3.0   "Disturbance end (s)";

  // ===== Trajectory waypoints (three reachable states) =====
  parameter Real qA1 = 0.0 "State A joint 1 (rad)";
  parameter Real qA2 = 0.0 "State A joint 2 (rad)";
  parameter Real qA3 = 0.0 "State A joint 3 (rad)";
  parameter Real qA4 = 0.0 "State A joint 4 (rad)";
  parameter Real qB1 = 0.0 "State B joint 1 (rad)";
  parameter Real qB2 = 0.6 "State B joint 2 (rad)";
  parameter Real qB3 = 0.4 "State B joint 3 (rad)";
  parameter Real qB4 = 0.0 "State B joint 4 (rad)";
  parameter Real qC1 = 0.0 "State C joint 1 (rad)";
  parameter Real qC2 = 1.0 "State C joint 2 (rad)";
  parameter Real qC3 = 0.6 "State C joint 3 (rad)";
  parameter Real qC4 = 0.3 "State C joint 4 (rad)";

  // ===== Joint limits =====
  parameter Real q1_lo = -3.14159265 "Joint 1 lower limit (rad)";
  parameter Real q1_hi =  3.14159265  "Joint 1 upper limit (rad)";
  parameter Real q2_lo = -1.57079633 "Joint 2 lower limit (rad)";
  parameter Real q2_hi =  1.57079633 "Joint 2 upper limit (rad)";
  parameter Real q3_lo = -1.57079633 "Joint 3 lower limit (rad)";
  parameter Real q3_hi =  1.57079633 "Joint 3 upper limit (rad)";
  parameter Real q4_lo = -3.14159265 "Joint 4 lower limit (rad)";
  parameter Real q4_hi =  3.14159265 "Joint 4 upper limit (rad)";

  // ===== Plant dynamics (diagonal lumped inertia, viscous damping) =====
  parameter Real J1 = 2.0  "Joint 1 inertia (kg.m^2)";
  parameter Real J2 = 0.8  "Joint 2 inertia (kg.m^2)";
  parameter Real J3 = 0.3  "Joint 3 inertia (kg.m^2)";
  parameter Real J4 = 0.06 "Joint 4 inertia (kg.m^2)";
  parameter Real d1 = 1.5 "Joint 1 damping (N.m.s/rad)";
  parameter Real d2 = 0.8 "Joint 2 damping (N.m.s/rad)";
  parameter Real d3 = 0.4 "Joint 3 damping (N.m.s/rad)";
  parameter Real d4 = 0.1 "Joint 4 damping (N.m.s/rad)";

  // ===== Controller gains (PID + velocity feedforward) =====
  parameter Real Kp1 = 350.0;
  parameter Real Kp2 = 180.0;
  parameter Real Kp3 = 100.0;
  parameter Real Kp4 = 25.0;
  parameter Real Ki1 = 500.0;
  parameter Real Ki2 = 250.0;
  parameter Real Ki3 = 140.0;
  parameter Real Ki4 = 35.0;
  parameter Real Kd1 = 45.0;
  parameter Real Kd2 = 22.0;
  parameter Real Kd3 = 12.0;
  parameter Real Kd4 = 3.0;
  parameter Real Kff1 = 1.5 "Velocity feedforward gain 1";
  parameter Real Kff2 = 0.8 "Velocity feedforward gain 2";
  parameter Real Kff3 = 0.4 "Velocity feedforward gain 3";
  parameter Real Kff4 = 0.1 "Velocity feedforward gain 4";
  parameter Real Kb1 = 5.0 "Anti-windup back-calculation gain 1";
  parameter Real Kb2 = 5.0 "Anti-windup back-calculation gain 2";
  parameter Real Kb3 = 5.0 "Anti-windup back-calculation gain 3";
  parameter Real Kb4 = 5.0 "Anti-windup back-calculation gain 4";

  // ===== Disturbance =====
  parameter Real F_dist = 5.0 "Lateral disturbance force magnitude (N)";

  // ===== Obstacle (fixed cylindrical keep-out beside nominal path) =====
  parameter Real obs_x = 0.0  "Obstacle center x (m)";
  parameter Real obs_y = 0.25 "Obstacle center y (m)";
  parameter Real obs_z = 0.40 "Obstacle center z (m)";
  parameter Real obs_r = 0.05 "Obstacle radius (m)";
  parameter Real link_r = 0.02 "Link capsule radius (m)";

  // ===== Soft joint-limit enforcement =====
  parameter Real kl = 2000.0 "Joint limit spring stiffness (N.m/rad)";
  parameter Real dl = 50.0   "Joint limit damper (N.m.s/rad)";

  // Small epsilon to avoid division by zero in segment distance
  parameter Real eps_seg = 1.0e-9 "Segment length epsilon (m)";

  // ===== Joint states =====
  Real q1(start = 0.0) "Joint 1 angle (rad)";
  Real q2(start = 0.0) "Joint 2 angle (rad)";
  Real q3(start = 0.0) "Joint 3 angle (rad)";
  Real q4(start = 0.0) "Joint 4 angle (rad)";
  Real dq1(start = 0.0) "Joint 1 velocity (rad/s)";
  Real dq2(start = 0.0) "Joint 2 velocity (rad/s)";
  Real dq3(start = 0.0) "Joint 3 velocity (rad/s)";
  Real dq4(start = 0.0) "Joint 4 velocity (rad/s)";

  // ===== PID integrator states =====
  Real integ1(start = 0.0) "Joint 1 PID integral (rad)";
  Real integ2(start = 0.0) "Joint 2 PID integral (rad)";
  Real integ3(start = 0.0) "Joint 3 PID integral (rad)";
  Real integ4(start = 0.0) "Joint 4 PID integral (rad)";

  // ===== Sampled encoder (synchronized at 80 Hz) =====
  Real q1_enc(start = 0.0)  "Joint 1 sampled position (rad)";
  Real q2_enc(start = 0.0)  "Joint 2 sampled position (rad)";
  Real q3_enc(start = 0.0)  "Joint 3 sampled position (rad)";
  Real q4_enc(start = 0.0)  "Joint 4 sampled position (rad)";
  Real dq1_enc(start = 0.0) "Joint 1 sampled velocity (rad/s)";
  Real dq2_enc(start = 0.0) "Joint 2 sampled velocity (rad/s)";
  Real dq3_enc(start = 0.0) "Joint 3 sampled velocity (rad/s)";
  Real dq4_enc(start = 0.0) "Joint 4 sampled velocity (rad/s)";

  // ===== Reference trajectory =====
  Real q1_ref  "Reference joint 1 (rad)";
  Real q2_ref  "Reference joint 2 (rad)";
  Real q3_ref  "Reference joint 3 (rad)";
  Real q4_ref  "Reference joint 4 (rad)";
  Real dq1_ref "Reference velocity 1 (rad/s)";
  Real dq2_ref "Reference velocity 2 (rad/s)";
  Real dq3_ref "Reference velocity 3 (rad/s)";
  Real dq4_ref "Reference velocity 4 (rad/s)";

  // ===== Tracking errors =====
  Real e1, e2, e3, e4    "Position errors (rad)";
  Real de1, de2, de3, de4 "Velocity errors (rad/s)";
  Real ae1, ae2, ae3, ae4 "Absolute position errors (rad)";
  Real max12, max34       "Intermediate max values";
  Real primary_error      "Primary tracking error (rad)";

  // ===== Commands =====
  Real tau1, tau2, tau3, tau4           "Unsaturated commands (N.m)";
  Real tau1_sat, tau2_sat, tau3_sat, tau4_sat "Saturated commands (N.m)";

  // ===== Disturbance =====
  Real F_dist_y "Lateral disturbance force (N)";
  Real tau1_dist, tau2_dist, tau3_dist, tau4_dist "Disturbance torques (N.m)";

  // ===== Joint limit torques =====
  Real tau1_lim, tau2_lim, tau3_lim, tau4_lim "Joint limit torques (N.m)";

  // ===== Forward kinematics =====
  Real sq1, cq1, s2, c2, s23, c23, s4, c4;
  Real px1, py1, pz1 "Link 1 endpoint (m)";
  Real px2, py2, pz2 "Link 2 endpoint (m)";
  Real px3, py3, pz3 "Link 3 endpoint (m)";
  Real px4, py4, pz4 "Link 4 endpoint / tip (m)";

  // ===== Jacobian (Y direction) =====
  Real Jy1, Jy2, Jy3, Jy4;

  // ===== Obstacle clearance =====
  Real dist1, dist2, dist3, dist4;
  Real min12, min34 "Intermediate min values";
  Real min_dist     "Minimum distance to obstacle center (m)";
  Real clearance    "Obstacle clearance (m)";

  // Segment distance intermediate variables
  Real ax1, ay1, az1, bx1, by1, bz1;
  Real abx1, aby1, abz1, apx1, apy1, apz1;
  Real ab2_1, t_raw1, t1, cx1, cy1, cz1, dx1, dy1, dz1;

  Real ax2, ay2, az2, bx2, by2, bz2;
  Real abx2, aby2, abz2, apx2, apy2, apz2;
  Real ab2_2, t_raw2, t2, cx2, cy2, cz2, dx2, dy2, dz2;

  Real ax3, ay3, az3, bx3, by3, bz3;
  Real abx3, aby3, abz3, apx3, apy3, apz3;
  Real ab2_3, t_raw3, t3, cx3, cy3, cz3, dx3, dy3, dz3;

  Real ax4, ay4, az4, bx4, by4, bz4;
  Real abx4, aby4, abz4, apx4, apy4, apz4;
  Real ab2_4, t_raw4, t4, cx4, cy4, cz4, dx4, dy4, dz4;

  // ===== Trajectory interpolation =====
  Real s_seg "Normalized segment time";

equation
  // ========== Trigonometric intermediates ==========
  sq1 = sin(q1);   cq1 = cos(q1);
  s2  = sin(q2);   c2  = cos(q2);
  s23 = sin(q2 + q3);  c23 = cos(q2 + q3);
  s4  = sin(q4);   c4  = cos(q4);

  // ========== Cubic Trajectory Generator ==========
  // Zero-velocity cubic: q(s) = q0 + (q1-q0)*(3s^2 - 2s^3)
  // dq/dt = (q1-q0)/T * (6s - 6s^2)
  if time < tB then
    s_seg = time / tB;
    q1_ref = qA1 + (qB1 - qA1) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    q2_ref = qA2 + (qB2 - qA2) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    q3_ref = qA3 + (qB3 - qA3) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    q4_ref = qA4 + (qB4 - qA4) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    dq1_ref = (qB1 - qA1) / tB * (6.0*s_seg - 6.0*s_seg*s_seg);
    dq2_ref = (qB2 - qA2) / tB * (6.0*s_seg - 6.0*s_seg*s_seg);
    dq3_ref = (qB3 - qA3) / tB * (6.0*s_seg - 6.0*s_seg*s_seg);
    dq4_ref = (qB4 - qA4) / tB * (6.0*s_seg - 6.0*s_seg*s_seg);
  elseif time < tC then
    s_seg = (time - tB) / (tC - tB);
    q1_ref = qB1 + (qC1 - qB1) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    q2_ref = qB2 + (qC2 - qB2) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    q3_ref = qB3 + (qC3 - qB3) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    q4_ref = qB4 + (qC4 - qB4) * (3.0*s_seg*s_seg - 2.0*s_seg*s_seg*s_seg);
    dq1_ref = (qC1 - qB1) / (tC - tB) * (6.0*s_seg - 6.0*s_seg*s_seg);
    dq2_ref = (qC2 - qB2) / (tC - tB) * (6.0*s_seg - 6.0*s_seg*s_seg);
    dq3_ref = (qC3 - qB3) / (tC - tB) * (6.0*s_seg - 6.0*s_seg*s_seg);
    dq4_ref = (qC4 - qB4) / (tC - tB) * (6.0*s_seg - 6.0*s_seg*s_seg);
  else
    s_seg = 1.0;
    q1_ref = qC1;
    q2_ref = qC2;
    q3_ref = qC3;
    q4_ref = qC4;
    dq1_ref = 0.0;
    dq2_ref = 0.0;
    dq3_ref = 0.0;
    dq4_ref = 0.0;
  end if;

  // ========== Encoder (synchronized sampling at 80 Hz) ==========
  when sample(0, Ts) then
    q1_enc = q1;
    q2_enc = q2;
    q3_enc = q3;
    q4_enc = q4;
    dq1_enc = dq1;
    dq2_enc = dq2;
    dq3_enc = dq3;
    dq4_enc = dq4;
  end when;

  // ========== PID + Velocity Feedforward Controller ==========
  e1 = q1_ref - q1_enc;
  e2 = q2_ref - q2_enc;
  e3 = q3_ref - q3_enc;
  e4 = q4_ref - q4_enc;
  de1 = dq1_ref - dq1_enc;
  de2 = dq2_ref - dq2_enc;
  de3 = dq3_ref - dq3_enc;
  de4 = dq4_ref - dq4_enc;

  // PID + velocity feedforward command
  tau1 = Kp1*e1 + Ki1*integ1 + Kd1*de1 + Kff1*dq1_ref;
  tau2 = Kp2*e2 + Ki2*integ2 + Kd2*de2 + Kff2*dq2_ref;
  tau3 = Kp3*e3 + Ki3*integ3 + Kd3*de3 + Kff3*dq3_ref;
  tau4 = Kp4*e4 + Ki4*integ4 + Kd4*de4 + Kff4*dq4_ref;

  // Saturated effort drives (command magnitude limit)
  tau1_sat = if tau1 > tau_max then tau_max elseif tau1 < -tau_max then -tau_max else tau1;
  tau2_sat = if tau2 > tau_max then tau_max elseif tau2 < -tau_max then -tau_max else tau2;
  tau3_sat = if tau3 > tau_max then tau_max elseif tau3 < -tau_max then -tau_max else tau3;
  tau4_sat = if tau4 > tau_max then tau_max elseif tau4 < -tau_max then -tau_max else tau4;

  // Anti-windup via back-calculation
  der(integ1) = e1 - Kb1 * (tau1 - tau1_sat);
  der(integ2) = e2 - Kb2 * (tau2 - tau2_sat);
  der(integ3) = e3 - Kb3 * (tau3 - tau3_sat);
  der(integ4) = e4 - Kb4 * (tau4 - tau4_sat);

  // ========== Disturbance (5 N lateral during middle third) ==========
  F_dist_y = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // Jacobian for Y-direction (tip position)
  Jy1 = cq1*(L2*s2 + L3*s23) + L4*(cq1*s23*c4 + sq1*s4);
  Jy2 = sq1*(L2*c2 + L3*c23) + L4*sq1*c23*c4;
  Jy3 = sq1*L3*c23 + L4*sq1*c23*c4;
  Jy4 = L4*(-sq1*s23*s4 - cq1*c4);

  // Disturbance torques via Jacobian transpose
  tau1_dist = F_dist_y * Jy1;
  tau2_dist = F_dist_y * Jy2;
  tau3_dist = F_dist_y * Jy3;
  tau4_dist = F_dist_y * Jy4;

  // ========== Joint Limit Enforcement (soft spring-damper) ==========
  tau1_lim = if q1 > q1_hi then -kl*(q1 - q1_hi) - dl*dq1
             elseif q1 < q1_lo then -kl*(q1 - q1_lo) - dl*dq1
             else 0.0;
  tau2_lim = if q2 > q2_hi then -kl*(q2 - q2_hi) - dl*dq2
             elseif q2 < q2_lo then -kl*(q2 - q2_lo) - dl*dq2
             else 0.0;
  tau3_lim = if q3 > q3_hi then -kl*(q3 - q3_hi) - dl*dq3
             elseif q3 < q3_lo then -kl*(q3 - q3_lo) - dl*dq3
             else 0.0;
  tau4_lim = if q4 > q4_hi then -kl*(q4 - q4_hi) - dl*dq4
             elseif q4 < q4_lo then -kl*(q4 - q4_lo) - dl*dq4
             else 0.0;

  // ========== Plant Dynamics ==========
  J1 * der(dq1) = tau1_sat - d1*dq1 - tau1_dist + tau1_lim;
  J2 * der(dq2) = tau2_sat - d2*dq2 - tau2_dist + tau2_lim;
  J3 * der(dq3) = tau3_sat - d3*dq3 - tau3_dist + tau3_lim;
  J4 * der(dq4) = tau4_sat - d4*dq4 - tau4_dist + tau4_lim;

  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;
  der(q4) = dq4;

  // ========== Forward Kinematics (Z-Y-Y-X serial chain) ==========
  px1 = 0.0;
  py1 = 0.0;
  pz1 = L1;

  px2 = cq1 * L2 * s2;
  py2 = sq1 * L2 * s2;
  pz2 = L1 + L2 * c2;

  px3 = cq1 * (L2*s2 + L3*s23);
  py3 = sq1 * (L2*s2 + L3*s23);
  pz3 = L1 + L2*c2 + L3*c23;

  px4 = px3 + L4*(cq1*s23*c4 + sq1*s4);
  py4 = py3 + L4*(sq1*s23*c4 - cq1*s4);
  pz4 = pz3 + L4*c23*c4;

  // ========== Obstacle Clearance (inline point-to-segment distance) ==========
  // Segment 1: from base (0,0,0) to link1 end (px1,py1,pz1)
  ax1 = 0.0; ay1 = 0.0; az1 = 0.0;
  bx1 = px1; by1 = py1; bz1 = pz1;
  abx1 = bx1 - ax1; aby1 = by1 - ay1; abz1 = bz1 - az1;
  apx1 = obs_x - ax1; apy1 = obs_y - ay1; apz1 = obs_z - az1;
  ab2_1 = abx1*abx1 + aby1*aby1 + abz1*abz1;
  t_raw1 = (apx1*abx1 + apy1*aby1 + apz1*abz1) / (ab2_1 + eps_seg);
  t1 = if t_raw1 < 0.0 then 0.0 elseif t_raw1 > 1.0 then 1.0 else t_raw1;
  cx1 = ax1 + t1*abx1; cy1 = ay1 + t1*aby1; cz1 = az1 + t1*abz1;
  dx1 = obs_x - cx1; dy1 = obs_y - cy1; dz1 = obs_z - cz1;
  dist1 = sqrt(dx1*dx1 + dy1*dy1 + dz1*dz1);

  // Segment 2: from link1 end to link2 end
  ax2 = px1; ay2 = py1; az2 = pz1;
  bx2 = px2; by2 = py2; bz2 = pz2;
  abx2 = bx2 - ax2; aby2 = by2 - ay2; abz2 = bz2 - az2;
  apx2 = obs_x - ax2; apy2 = obs_y - ay2; apz2 = obs_z - az2;
  ab2_2 = abx2*abx2 + aby2*aby2 + abz2*abz2;
  t_raw2 = (apx2*abx2 + apy2*aby2 + apz2*abz2) / (ab2_2 + eps_seg);
  t2 = if t_raw2 < 0.0 then 0.0 elseif t_raw2 > 1.0 then 1.0 else t_raw2;
  cx2 = ax2 + t2*abx2; cy2 = ay2 + t2*aby2; cz2 = az2 + t2*abz2;
  dx2 = obs_x - cx2; dy2 = obs_y - cy2; dz2 = obs_z - cz2;
  dist2 = sqrt(dx2*dx2 + dy2*dy2 + dz2*dz2);

  // Segment 3: from link2 end to link3 end
  ax3 = px2; ay3 = py2; az3 = pz2;
  bx3 = px3; by3 = py3; bz3 = pz3;
  abx3 = bx3 - ax3; aby3 = by3 - ay3; abz3 = bz3 - az3;
  apx3 = obs_x - ax3; apy3 = obs_y - ay3; apz3 = obs_z - az3;
  ab2_3 = abx3*abx3 + aby3*aby3 + abz3*abz3;
  t_raw3 = (apx3*abx3 + apy3*aby3 + apz3*abz3) / (ab2_3 + eps_seg);
  t3 = if t_raw3 < 0.0 then 0.0 elseif t_raw3 > 1.0 then 1.0 else t_raw3;
  cx3 = ax3 + t3*abx3; cy3 = ay3 + t3*aby3; cz3 = az3 + t3*abz3;
  dx3 = obs_x - cx3; dy3 = obs_y - cy3; dz3 = obs_z - cz3;
  dist3 = sqrt(dx3*dx3 + dy3*dy3 + dz3*dz3);

  // Segment 4: from link3 end to tip
  ax4 = px3; ay4 = py3; az4 = pz3;
  bx4 = px4; by4 = py4; bz4 = pz4;
  abx4 = bx4 - ax4; aby4 = by4 - ay4; abz4 = bz4 - az4;
  apx4 = obs_x - ax4; apy4 = obs_y - ay4; apz4 = obs_z - az4;
  ab2_4 = abx4*abx4 + aby4*aby4 + abz4*abz4;
  t_raw4 = (apx4*abx4 + apy4*aby4 + apz4*abz4) / (ab2_4 + eps_seg);
  t4 = if t_raw4 < 0.0 then 0.0 elseif t_raw4 > 1.0 then 1.0 else t_raw4;
  cx4 = ax4 + t4*abx4; cy4 = ay4 + t4*aby4; cz4 = az4 + t4*abz4;
  dx4 = obs_x - cx4; dy4 = obs_y - cy4; dz4 = obs_z - cz4;
  dist4 = sqrt(dx4*dx4 + dy4*dy4 + dz4*dz4);

  // Explicit scalar reductions (no array reduction)
  min12 = if dist1 < dist2 then dist1 else dist2;
  min34 = if dist3 < dist4 then dist3 else dist4;
  min_dist = if min12 < min34 then min12 else min34;
  clearance = min_dist - obs_r - link_r;

  // ========== Tracking Error Metrics ==========
  ae1 = abs(e1);
  ae2 = abs(e2);
  ae3 = abs(e3);
  ae4 = abs(e4);
  max12 = if ae1 > ae2 then ae1 else ae2;
  max34 = if ae3 > ae4 then ae3 else ae4;
  primary_error = if max12 > max34 then max12 else max34;

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "<html>
      <p>AssemblyArmTraceA: 4-DOF fixed-base articulated manipulator (Z-Y-Y-X axes).</p>
      <p>Link lengths 0.50, 0.40, 0.28, 0.16 m; masses 7, 5, 3, 1 kg.</p>
      <p>PID + velocity-feedforward trajectory control with 79.2 N.m saturation.</p>
      <p>80 Hz synchronized encoder sampling; 8 s scenario.</p>
      <p>Cubic trajectory through three reachable states, stop at last state.</p>
      <p>5 N lateral disturbance during middle third of scenario.</p>
      <p>Fixed cylindrical keep-out obstacle beside (not on) nominal path at Y=0.25 m.</p>
      <p>Requirements: joint limits, clearance above 0.05 m, overshoot below 12 percent,</p>
      <p>terminal settling, primary tracking error below 0.068 rad after 5.2 s.</p>
    </html>")
  );
end AssemblyArmTraceA;