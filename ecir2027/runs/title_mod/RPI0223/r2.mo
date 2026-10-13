model AssemblyArmTraceA
  "Fixed-base articulated manipulator with four serial revolute joints (Z,Y,Y,X),
   saturated PID+velocity-feedforward control, cubic trajectory, obstacle clearance,
   80 Hz synchronized encoders, and lateral disturbance."
  // ---- Link geometry and masses (given) ----
  parameter Real L1(unit="m") = 0.50 "Length of link 1";
  parameter Real L2(unit="m") = 0.40 "Length of link 2";
  parameter Real L3(unit="m") = 0.28 "Length of link 3";
  parameter Real L4(unit="m") = 0.16 "Length of link 4";
  parameter Real m1(unit="kg") = 7.0  "Mass of link 1";
  parameter Real m2(unit="kg") = 5.0  "Mass of link 2";
  parameter Real m3(unit="kg") = 3.0  "Mass of link 3";
  parameter Real m4(unit="kg") = 1.0  "Mass of link 4";

  // ---- Approximate inertias (slender rod about one end) ----
  parameter Real J1(unit="kg.m2") = (1.0/3.0)*m1*L1^2;
  parameter Real J2(unit="kg.m2") = (1.0/3.0)*m2*L2^2;
  parameter Real J3(unit="kg.m2") = (1.0/3.0)*m3*L3^2;
  parameter Real J4(unit="kg.m2") = (1.0/3.0)*m4*L4^2;

  // ---- Drive saturation (given) ----
  parameter Real tau_max(unit="N.m") = 79.2 "Command magnitude limit";

  // ---- Disturbance (given) ----
  parameter Real F_dist(unit="N") = 5.0 "Lateral disturbance force magnitude";

  // ---- Timing (given) ----
  parameter Real fs(unit="Hz") = 80.0 "Sensor sample rate";
  parameter Real dt_s(unit="s") = 1.0/fs "Sample interval";
  parameter Real T_end(unit="s") = 8.0 "Scenario duration";
  parameter Real t1(unit="s") = 4.0  "Middle waypoint time";
  parameter Real t2(unit="s") = T_end "Final waypoint time";

  // ---- Unknown physical parameters (placeholders, must be tuned for real hardware) ----
  parameter Real b_damp(unit="N.m.s/rad") = 0.05 "Joint viscous damping, unknown";
  parameter Real q_min(unit="rad") = -1.5 "Lower joint limit, unknown";
  parameter Real q_max(unit="rad") =  1.5 "Upper joint limit, unknown";

  // ---- Controller gains (placeholders designed for closed-loop wn≈10–18 rad/s, ζ≈0.8) ----
  parameter Real Kp1(unit="N.m/rad") = 200.0;
  parameter Real Kd1(unit="N.m.s/rad") = 20.0;
  parameter Real Ki1(unit="N.m/(rad.s)") = 40.0;
  parameter Real Kp2(unit="N.m/rad") = 100.0;
  parameter Real Kd2(unit="N.m.s/rad") = 10.0;
  parameter Real Ki2(unit="N.m/(rad.s)") = 20.0;
  parameter Real Kp3(unit="N.m/rad") = 30.0;
  parameter Real Kd3(unit="N.m.s/rad") = 3.0;
  parameter Real Ki3(unit="N.m/(rad.s)") = 6.0;
  parameter Real Kp4(unit="N.m/rad") = 4.0;
  parameter Real Kd4(unit="N.m.s/rad") = 0.4;
  parameter Real Ki4(unit="N.m/(rad.s)") = 0.8;

  // Velocity feedforward gains (set to damping, unknown)
  parameter Real Kff1(unit="N.m.s/rad") = b_damp;
  parameter Real Kff2(unit="N.m.s/rad") = b_damp;
  parameter Real Kff3(unit="N.m.s/rad") = b_damp;
  parameter Real Kff4(unit="N.m.s/rad") = b_damp;

  // ---- Trajectory waypoints (unknown, chosen reachable and safe) ----
  parameter Real q0_1(unit="rad") = 0.0;
  parameter Real q0_2(unit="rad") = 0.0;
  parameter Real q0_3(unit="rad") = 0.0;
  parameter Real q0_4(unit="rad") = 0.0;
  parameter Real q1_1(unit="rad") = 0.20;
  parameter Real q1_2(unit="rad") = 0.15;
  parameter Real q1_3(unit="rad") = 0.10;
  parameter Real q1_4(unit="rad") = 0.05;
  parameter Real q2_1(unit="rad") = -0.15;
  parameter Real q2_2(unit="rad") = 0.05;
  parameter Real q2_3(unit="rad") = -0.08;
  parameter Real q2_4(unit="rad") = 0.00;

  // ---- Obstacle (unknown, placeholder placed beside nominal path) ----
  parameter Real obs_x(unit="m") = 0.50;
  parameter Real obs_y(unit="m") = -0.50;
  parameter Real obs_z(unit="m") = 0.20;
  parameter Real obs_radius(unit="m") = 0.0 "Cylinder radius unknown; centerline treated as keep-out";
  parameter Real clearance_req(unit="m") = 0.05 "Minimum required clearance";

  // ---- State variables ----
  Real q1(unit="rad", start=q0_1) "Joint 1 angle (Z axis)";
  Real q2(unit="rad", start=q0_2) "Joint 2 angle (Y axis)";
  Real q3(unit="rad", start=q0_3) "Joint 3 angle (Y axis)";
  Real q4(unit="rad", start=q0_4) "Joint 4 angle (X axis)";
  Real w1(unit="rad/s", start=0) "Joint 1 angular velocity";
  Real w2(unit="rad/s", start=0) "Joint 2 angular velocity";
  Real w3(unit="rad/s", start=0) "Joint 3 angular velocity";
  Real w4(unit="rad/s", start=0) "Joint 4 angular velocity";

  // ---- Integrator states ----
  Real x1(start=0) "Integral of joint-1 error";
  Real x2(start=0) "Integral of joint-2 error";
  Real x3(start=0) "Integral of joint-3 error";
  Real x4(start=0) "Integral of joint-4 error";

  // ---- Desired trajectory ----
  Real qd1_des(unit="rad"), qd2_des(unit="rad"), qd3_des(unit="rad"), qd4_des(unit="rad");
  Real wd1_des(unit="rad/s"), wd2_des(unit="rad/s"), wd3_des(unit="rad/s"), wd4_des(unit="rad/s");
  Real wdd1_des(unit="rad/s2"), wdd2_des(unit="rad/s2"), wdd3_des(unit="rad/s2"), wdd4_des(unit="rad/s2");

  // ---- Errors ----
  Real e1(unit="rad"), e2(unit="rad"), e3(unit="rad"), e4(unit="rad");
  Real ed1(unit="rad/s"), ed2(unit="rad/s"), ed3(unit="rad/s"), ed4(unit="rad/s");

  // ---- Command torques ----
  Real tau1_raw(unit="N.m"), tau2_raw(unit="N.m"), tau3_raw(unit="N.m"), tau4_raw(unit="N.m");
  Real tau1_cmd(unit="N.m"), tau2_cmd(unit="N.m"), tau3_cmd(unit="N.m"), tau4_cmd(unit="N.m");

  // ---- Disturbance ----
  Real F_dist_x(unit="N"), F_dist_y(unit="N"), F_dist_z(unit="N");
  Real tau1_dist(unit="N.m"), tau2_dist(unit="N.m"), tau3_dist(unit="N.m"), tau4_dist(unit="N.m");

  // ---- Forward kinematics ----
  Real R1_11, R1_12, R1_13, R1_21, R1_22, R1_23, R1_31, R1_32, R1_33;
  Real R2_11, R2_12, R2_13, R2_21, R2_22, R2_23, R2_31, R2_32, R2_33;
  Real R3_11, R3_12, R3_13, R3_21, R3_22, R3_23, R3_31, R3_32, R3_33;
  Real R4_11, R4_12, R4_13, R4_21, R4_22, R4_23, R4_31, R4_32, R4_33;
  Real p1_x(unit="m"), p1_y(unit="m"), p1_z(unit="m");
  Real p2_x(unit="m"), p2_y(unit="m"), p2_z(unit="m");
  Real p3_x(unit="m"), p3_y(unit="m"), p3_z(unit="m");
  Real p4_x(unit="m"), p4_y(unit="m"), p4_z(unit="m");

  // ---- Jacobian columns ----
  Real z1_x, z1_y, z1_z;
  Real z2_x, z2_y, z2_z;
  Real z3_x, z3_y, z3_z;
  Real z4_x, z4_y, z4_z;
  Real J1_x, J1_y, J1_z;
  Real J2_x, J2_y, J2_z;
  Real J3_x, J3_y, J3_z;
  Real J4_x, J4_y, J4_z;

  // ---- Obstacle clearance ----
  Real d_obs1(unit="m"), d_obs2(unit="m"), d_obs3(unit="m"), d_obs4(unit="m");
  Real d_obs_min(unit="m");

  // ---- Synchronized encoder samples (80 Hz) ----
  discrete Real q1_s(unit="rad", start=q0_1), q2_s(unit="rad", start=q0_2), q3_s(unit="rad", start=q0_3), q4_s(unit="rad", start=q0_4);
  discrete Real w1_s(unit="rad/s", start=0), w2_s(unit="rad/s", start=0), w3_s(unit="rad/s", start=0), w4_s(unit="rad/s", start=0);

  // ---- Performance metrics ----
  Real primary_tracking_error(unit="rad") "Combined joint error norm";
  discrete Real max_err1(unit="rad", start=0), max_err2(unit="rad", start=0), max_err3(unit="rad", start=0), max_err4(unit="rad", start=0);
  Real overshoot1(unit="1"), overshoot2(unit="1"), overshoot3(unit="1"), overshoot4(unit="1");
  Real settling_error(unit="rad/s") "Velocity norm at terminal time";

equation
  // ---- Cubic trajectory with zero endpoint velocities ----
  if time < t1 then
    qd1_des = (2*(time/t1)^3 - 3*(time/t1)^2 + 1)*q0_1 + (-2*(time/t1)^3 + 3*(time/t1)^2)*q1_1;
    qd2_des = (2*(time/t1)^3 - 3*(time/t1)^2 + 1)*q0_2 + (-2*(time/t1)^3 + 3*(time/t1)^2)*q1_2;
    qd3_des = (2*(time/t1)^3 - 3*(time/t1)^2 + 1)*q0_3 + (-2*(time/t1)^3 + 3*(time/t1)^2)*q1_3;
    qd4_des = (2*(time/t1)^3 - 3*(time/t1)^2 + 1)*q0_4 + (-2*(time/t1)^3 + 3*(time/t1)^2)*q1_4;
    wd1_des = (6*(time/t1)^2 - 6*(time/t1))*(q0_1 - q1_1)/t1;
    wd2_des = (6*(time/t1)^2 - 6*(time/t1))*(q0_2 - q1_2)/t1;
    wd3_des = (6*(time/t1)^2 - 6*(time/t1))*(q0_3 - q1_3)/t1;
    wd4_des = (6*(time/t1)^2 - 6*(time/t1))*(q0_4 - q1_4)/t1;
    wdd1_des = (12*(time/t1) - 6)*(q0_1 - q1_1)/t1^2;
    wdd2_des = (12*(time/t1) - 6)*(q0_2 - q1_2)/t1^2;
    wdd3_des = (12*(time/t1) - 6)*(q0_3 - q1_3)/t1^2;
    wdd4_des = (12*(time/t1) - 6)*(q0_4 - q1_4)/t1^2;
  elseif time < t2 then
    qd1_des = (2*((time-t1)/(t2-t1))^3 - 3*((time-t1)/(t2-t1))^2 + 1)*q1_1 + (-2*((time-t1)/(t2-t1))^3 + 3*((time-t1)/(t2-t1))^2)*q2_1;
    qd2_des = (2*((time-t1)/(t2-t1))^3 - 3*((time-t1)/(t2-t1))^2 + 1)*q1_2 + (-2*((time-t1)/(t2-t1))^3 + 3*((time-t1)/(t2-t1))^2)*q2_2;
    qd3_des = (2*((time-t1)/(t2-t1))^3 - 3*((time-t1)/(t2-t1))^2 + 1)*q1_3 + (-2*((time-t1)/(t2-t1))^3 + 3*((time-t1)/(t2-t1))^2)*q2_3;
    qd4_des = (2*((time-t1)/(t2-t1))^3 - 3*((time-t1)/(t2-t1))^2 + 1)*q1_4 + (-2*((time-t1)/(t2-t1))^3 + 3*((time-t1)/(t2-t1))^2)*q2_4;
    wd1_des = (6*((time-t1)/(t2-t1))^2 - 6*((time-t1)/(t2-t1)))*(q1_1 - q2_1)/(t2-t1);
    wd2_des = (6*((time-t1)/(t2-t1))^2 - 6*((time-t1)/(t2-t1)))*(q1_2 - q2_2)/(t2-t1);
    wd3_des = (6*((time-t1)/(t2-t1))^2 - 6*((time-t1)/(t2-t1)))*(q1_3 - q2_3)/(t2-t1);
    wd4_des = (6*((time-t1)/(t2-t1))^2 - 6*((time-t1)/(t2-t1)))*(q1_4 - q2_4)/(t2-t1);
    wdd1_des = (12*((time-t1)/(t2-t1)) - 6)*(q1_1 - q2_1)/(t2-t1)^2;
    wdd2_des = (12*((time-t1)/(t2-t1)) - 6)*(q1_2 - q2_2)/(t2-t1)^2;
    wdd3_des = (12*((time-t1)/(t2-t1)) - 6)*(q1_3 - q2_3)/(t2-t1)^2;
    wdd4_des = (12*((time-t1)/(t2-t1)) - 6)*(q1_4 - q2_4)/(t2-t1)^2;
  else
    qd1_des = q2_1;
    qd2_des = q2_2;
    qd3_des = q2_3;
    qd4_des = q2_4;
    wd1_des = 0;
    wd2_des = 0;
    wd3_des = 0;
    wd4_des = 0;
    wdd1_des = 0;
    wdd2_des = 0;
    wdd3_des = 0;
    wdd4_des = 0;
  end if;

  // ---- Errors ----
  e1 = qd1_des - q1;
  e2 = qd2_des - q2;
  e3 = qd3_des - q3;
  e4 = qd4_des - q4;
  ed1 = wd1_des - w1;
  ed2 = wd2_des - w2;
  ed3 = wd3_des - w3;
  ed4 = wd4_des - w4;

  // ---- Integrators ----
  der(x1) = e1;
  der(x2) = e2;
  der(x3) = e3;
  der(x4) = e4;

  // ---- PID + velocity feedforward ----
  tau1_raw = Kp1*e1 + Ki1*x1 + Kd1*ed1 + Kff1*wd1_des;
  tau2_raw = Kp2*e2 + Ki2*x2 + Kd2*ed2 + Kff2*wd2_des;
  tau3_raw = Kp3*e3 + Ki3*x3 + Kd3*ed3 + Kff3*wd3_des;
  tau4_raw = Kp4*e4 + Ki4*x4 + Kd4*ed4 + Kff4*wd4_des;

  // ---- Saturated effort ----
  tau1_cmd = if tau1_raw > tau_max then tau_max else if tau1_raw < -tau_max then -tau_max else tau1_raw;
  tau2_cmd = if tau2_raw > tau_max then tau_max else if tau2_raw < -tau_max then -tau_max else tau2_raw;
  tau3_cmd = if tau3_raw > tau_max then tau_max else if tau3_raw < -tau_max then -tau_max else tau3_raw;
  tau4_cmd = if tau4_raw > tau_max then tau_max else if tau4_raw < -tau_max then -tau_max else tau4_raw;

  // ---- Lateral disturbance during middle third of scenario ----
  if time >= T_end/3.0 and time <= 2.0*T_end/3.0 then
    F_dist_x = 0.0;
    F_dist_y = F_dist;
    F_dist_z = 0.0;
  else
    F_dist_x = 0.0;
    F_dist_y = 0.0;
    F_dist_z = 0.0;
  end if;

  // ---- Forward kinematics ----
  // Frame 1 = Rz(q1)
  R1_11 = cos(q1); R1_12 = -sin(q1); R1_13 = 0.0;
  R1_21 = sin(q1); R1_22 =  cos(q1); R1_23 = 0.0;
  R1_31 = 0.0;     R1_32 = 0.0;      R1_33 = 1.0;

  // Frame 2 = Frame1 * Ry(q2)
  R2_11 = R1_11*cos(q2) - R1_13*sin(q2);
  R2_12 = R1_12;
  R2_13 = R1_11*sin(q2) + R1_13*cos(q2);
  R2_21 = R1_21*cos(q2) - R1_23*sin(q2);
  R2_22 = R1_22;
  R2_23 = R1_21*sin(q2) + R1_23*cos(q2);
  R2_31 = R1_31*cos(q2) - R1_33*sin(q2);
  R2_32 = R1_32;
  R2_33 = R1_31*sin(q2) + R1_33*cos(q2);

  // Frame 3 = Frame2 * Ry(q3)
  R3_11 = R2_11*cos(q3) - R2_13*sin(q3);
  R3_12 = R2_12;
  R3_13 = R2_11*sin(q3) + R2_13*cos(q3);
  R3_21 = R2_21*cos(q3) - R2_23*sin(q3);
  R3_22 = R2_22;
  R3_23 = R2_21*sin(q3) + R2_23*cos(q3);
  R3_31 = R2_31*cos(q3) - R2_33*sin(q3);
  R3_32 = R2_32;
  R3_33 = R2_31*sin(q3) + R2_33*cos(q3);

  // Frame 4 = Frame3 * Rx(q4)
  R4_11 = R3_11;
  R4_12 = R3_12*cos(q4) + R3_13*sin(q4);
  R4_13 = -R3_12*sin(q4) + R3_13*cos(q4);
  R4_21 = R3_21;
  R4_22 = R3_22*cos(q4) + R3_23*sin(q4);
  R4_23 = -R3_22*sin(q4) + R3_23*cos(q4);
  R4_31 = R3_31;
  R4_32 = R3_32*cos(q4) + R3_33*sin(q4);
  R4_33 = -R3_32*sin(q4) + R3_33*cos(q4);

  // Link positions
  p1_x = L1*R1_11;
  p1_y = L1*R1_21;
  p1_z = L1*R1_31;
  p2_x = p1_x + L2*R2_11;
  p2_y = p1_y + L2*R2_21;
  p2_z = p1_z + L2*R2_31;
  p3_x = p2_x + L3*R3_11;
  p3_y = p2_y + L3*R3_21;
  p3_z = p2_z + L3*R3_31;
  p4_x = p3_x + L4*R4_11;
  p4_y = p3_y + L4*R4_21;
  p4_z = p3_z + L4*R4_31;

  // Joint axes in world frame
  z1_x = 0.0; z1_y = 0.0; z1_z = 1.0;
  z2_x = R1_12; z2_y = R1_22; z2_z = R1_32;
  z3_x = R2_12; z3_y = R2_22; z3_z = R2_32;
  z4_x = R3_11; z4_y = R3_21; z4_z = R3_31;

  // Jacobian columns: J_i = z_i × (p_ee - p_i_joint)
  J1_x = z1_y*(p4_z - 0.0) - z1_z*(p4_y - 0.0);
  J1_y = z1_z*(p4_x - 0.0) - z1_x*(p4_z - 0.0);
  J1_z = z1_x*(p4_y - 0.0) - z1_y*(p4_x - 0.0);
  J2_x = z2_y*(p4_z - p1_z) - z2_z*(p4_y - p1_y);
  J2_y = z2_z*(p4_x - p1_x) - z2_x*(p4_z - p1_z);
  J2_z = z2_x*(p4_y - p1_y) - z2_y*(p4_x - p1_x);
  J3_x = z3_y*(p4_z - p2_z) - z3_z*(p4_y - p2_y);
  J3_y = z3_z*(p4_x - p2_x) - z3_x*(p4_z - p2_z);
  J3_z = z3_x*(p4_y - p2_y) - z3_y*(p4_x - p2_x);
  J4_x = z4_y*(p4_z - p3_z) - z4_z*(p4_y - p3_y);
  J4_y = z4_z*(p4_x - p3_x) - z4_x*(p4_z - p3_z);
  J4_z = z4_x*(p4_y - p3_y) - z4_y*(p4_x - p3_x);

  // Disturbance torques via Jacobian transpose
  tau1_dist = J1_x*F_dist_x + J1_y*F_dist_y + J1_z*F_dist_z;
  tau2_dist = J2_x*F_dist_x + J2_y*F_dist_y + J2_z*F_dist_z;
  tau3_dist = J3_x*F_dist_x + J3_y*F_dist_y + J3_z*F_dist_z;
  tau4_dist = J4_x*F_dist_x + J4_y*F_dist_y + J4_z*F_dist_z;

  // ---- Decoupled joint dynamics (coupling terms unknown) ----
  J1*der(w1) = tau1_cmd + tau1_dist - b_damp*w1;
  J2*der(w2) = tau2_cmd + tau2_dist - b_damp*w2;
  J3*der(w3) = tau3_cmd + tau3_dist - b_damp*w3;
  J4*der(w4) = tau4_cmd + tau4_dist - b_damp*w4;
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(q4) = w4;

  // ---- Obstacle clearance ----
  d_obs1 = pointSegmentDistance(obs_x, obs_y, obs_z, 0.0,0.0,0.0, p1_x,p1_y,p1_z, L1);
  d_obs2 = pointSegmentDistance(obs_x, obs_y, obs_z, p1_x,p1_y,p1_z, p2_x,p2_y,p2_z, L2);
  d_obs3 = pointSegmentDistance(obs_x, obs_y, obs_z, p2_x,p2_y,p2_z, p3_x,p3_y,p3_z, L3);
  d_obs4 = pointSegmentDistance(obs_x, obs_y, obs_z, p3_x,p3_y,p3_z, p4_x,p4_y,p4_z, L4);
  d_obs_min = min(d_obs1, min(d_obs2, min(d_obs3, d_obs4)));

  // ---- Performance metrics ----
  primary_tracking_error = sqrt(e1^2 + e2^2 + e3^2 + e4^2 + 1e-12);
  overshoot1 = if abs(q2_1 - q1_1) > 1e-6 then (max_err1 / abs(q2_1 - q1_1)) else 0.0;
  overshoot2 = if abs(q2_2 - q1_2) > 1e-6 then (max_err2 / abs(q2_2 - q1_2)) else 0.0;
  overshoot3 = if abs(q2_3 - q1_3) > 1e-6 then (max_err3 / abs(q2_3 - q1_3)) else 0.0;
  overshoot4 = if abs(q2_4 - q1_4) > 1e-6 then (max_err4 / abs(q2_4 - q1_4)) else 0.0;
  settling_error = sqrt(w1^2 + w2^2 + w3^2 + w4^2 + 1e-12);

  // ---- Requirement assertions ----
  assert(q1 >= q_min and q1 <= q_max, "Joint 1 limit violated");
  assert(q2 >= q_min and q2 <= q_max, "Joint 2 limit violated");
  assert(q3 >= q_min and q3 <= q_max, "Joint 3 limit violated");
  assert(q4 >= q_min and q4 <= q_max, "Joint 4 limit violated");
  assert(d_obs_min > clearance_req, "Obstacle clearance below 0.05 m");
  assert(time < 5.2 or primary_tracking_error < 0.068, "Primary tracking error exceeded 0.068 rad after 5.2 s");
  assert(time < T_end - 1e-6 or settling_error < 0.02, "Terminal settling not achieved");
  assert(max(overshoot1, max(overshoot2, max(overshoot3, overshoot4))) < 0.12, "Overshoot exceeded 12%");

  // ---- Synchronized encoders at 80 Hz ----
  when sample(0, dt_s) then
    q1_s = q1;
    q2_s = q2;
    q3_s = q3;
    q4_s = q4;
    w1_s = w1;
    w2_s = w2;
    w3_s = w3;
    w4_s = w4;
    if time > t1 then
      max_err1 = max(max_err1, abs(e1));
      max_err2 = max(max_err2, abs(e2));
      max_err3 = max(max_err3, abs(e3));
      max_err4 = max(max_err4, abs(e4));
    end if;
  end when;

initial equation
  q1 = q0_1;
  q2 = q0_2;
  q3 = q0_3;
  q4 = q0_4;
  w1 = 0;
  w2 = 0;
  w3 = 0;
  w4 = 0;
  x1 = 0;
  x2 = 0;
  x3 = 0;
  x4 = 0;

  annotation(
    experiment(StartTime=0, StopTime=8, Tolerance=1e-6),
    Documentation(info="AssemblyArmTraceA: four-axis articulated manipulator (Z,Y,Y,X) with
      capsule links, saturated PID+velocity-feedforward control, cubic joint trajectory
      through three reachable states, fixed cylindrical keep-out obstacle, 80 Hz synchronized
      encoders, and 5 N lateral disturbance during the middle third. Unknown parameters
      (damping, controller gains, waypoints, obstacle geometry) are placeholders selected
      for simulation; they must be identified or tuned for the real hardware.")
  );
end AssemblyArmTraceA;