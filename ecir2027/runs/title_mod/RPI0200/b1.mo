model RailArmTraceB
  "Fixed-base articulated manipulator on X-rail, cubic trajectory, PID+FF control at 100 Hz";

  // ===== Physical parameters =====
  parameter Real L_rail = 1.4 "Rail length [m]";
  parameter Real m_c = 18.0 "Carriage mass [kg]";
  parameter Real l1 = 0.46 "Link 1 length [m]";
  parameter Real l2 = 0.31 "Link 2 length [m]";
  parameter Real m1 = 2.0 "Link 1 mass [kg] — assumed, not specified in requirement";
  parameter Real m2 = 1.5 "Link 2 mass [kg] — assumed, not specified in requirement";
  parameter Real lc1 = 0.23 "Link 1 COM distance [m] — assumed uniform rod";
  parameter Real lc2 = 0.155 "Link 2 COM distance [m] — assumed uniform rod";
  parameter Real I1 = m1*lc1^2/3.0 "Link 1 inertia [kg.m2] — assumed uniform rod";
  parameter Real I2 = m2*lc2^2/3.0 "Link 2 inertia [kg.m2] — assumed uniform rod";
  parameter Real g_acc = 9.81 "Gravity [m/s2]";

  // ===== Actuator limits =====
  parameter Real F_max = 800.0 "Max linear actuator force [N]";
  parameter Real tau_max = 69.7 "Max rotary actuator torque [N.m]";

  // ===== Joint limits =====
  parameter Real q_limit = 1.5 "Joint limit magnitude [rad]";

  // ===== Obstacle =====
  parameter Real x_obs = 1.20 "Obstacle center x [m]";
  parameter Real y_obs = -0.20 "Obstacle center y [m]";
  parameter Real r_obs = 0.04 "Obstacle radius [m]";
  parameter Real d_clear_req = 0.05 "Required clearance [m]";

  // ===== Trajectory waypoints =====
  parameter Real t_seg1 = 10.0/3.0 "End of segment 1 [s]";
  parameter Real t_seg2 = 20.0/3.0 "End of segment 2 [s]";

  parameter Real x_wp0 = 0.30 "Waypoint 0 carriage x [m]";
  parameter Real x_wp1 = 0.70 "Waypoint 1 carriage x [m]";
  parameter Real x_wp2 = 1.10 "Waypoint 2 carriage x [m]";
  parameter Real q1_wp0 = 0.00 "Waypoint 0 joint 1 [rad]";
  parameter Real q1_wp1 = 0.40 "Waypoint 1 joint 1 [rad]";
  parameter Real q1_wp2 = -0.20 "Waypoint 2 joint 1 [rad]";
  parameter Real q2_wp0 = 0.00 "Waypoint 0 joint 2 [rad]";
  parameter Real q2_wp1 = 0.20 "Waypoint 1 joint 2 [rad]";
  parameter Real q2_wp2 = 0.30 "Waypoint 2 joint 2 [rad]";

  // ===== Controller gains =====
  parameter Real Ts = 0.01 "Control sample period [s] (100 Hz)";
  parameter Real kp_x = 3000.0 "Carriage P gain";
  parameter Real kd_x = 400.0 "Carriage D gain";
  parameter Real ki_x = 200.0 "Carriage I gain";
  parameter Real kff_x = 40.0 "Carriage velocity feedforward gain";
  parameter Real kp_q1 = 120.0 "Joint 1 P gain";
  parameter Real kd_q1 = 12.0 "Joint 1 D gain";
  parameter Real ki_q1 = 15.0 "Joint 1 I gain";
  parameter Real kff_q1 = 5.0 "Joint 1 velocity feedforward gain";
  parameter Real kp_q2 = 40.0 "Joint 2 P gain";
  parameter Real kd_q2 = 3.0 "Joint 2 D gain";
  parameter Real ki_q2 = 8.0 "Joint 2 I gain";
  parameter Real kff_q2 = 2.0 "Joint 2 velocity feedforward gain";

  // ===== Disturbance =====
  parameter Real F_dist_mag = 7.0 "Lateral disturbance force [N]";

  // ===== Dynamic states =====
  Real x(start = x_wp0, fixed = true) "Carriage position [m]";
  Real xdot(start = 0.0, fixed = true) "Carriage velocity [m/s]";
  Real q1(start = q1_wp0, fixed = true) "Joint 1 angle [rad]";
  Real q1dot(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real q2(start = q2_wp0, fixed = true) "Joint 2 angle [rad]";
  Real q2dot(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";

  // ===== Discrete controller states =====
  discrete Real integ_x(start = 0.0, fixed = true) "Carriage integral error";
  discrete Real integ_q1(start = 0.0, fixed = true) "Joint 1 integral error";
  discrete Real integ_q2(start = 0.0, fixed = true) "Joint 2 integral error";

  // ===== Control commands (discrete, ZOH between samples) =====
  discrete Real F_cmd(start = 0.0) "Saturated carriage force [N]";
  discrete Real tau1_cmd(start = 0.0) "Saturated joint 1 torque [N.m]";
  discrete Real tau2_cmd(start = 0.0) "Saturated joint 2 torque [N.m]";

  // ===== Trajectory references =====
  Real x_des "Desired carriage position [m]";
  Real xdot_des "Desired carriage velocity [m/s]";
  Real q1_des "Desired joint 1 [rad]";
  Real q1dot_des "Desired joint 1 velocity [rad/s]";
  Real q2_des "Desired joint 2 [rad]";
  Real q2dot_des "Desired joint 2 velocity [rad/s]";

  // ===== Sensor outputs (encoders) =====
  Real x_enc "Carriage position encoder [m]";
  Real xdot_enc "Carriage velocity encoder [m/s]";
  Real q1_enc "Joint 1 position encoder [rad]";
  Real q1dot_enc "Joint 1 velocity encoder [rad/s]";
  Real q2_enc "Joint 2 position encoder [rad]";
  Real q2dot_enc "Joint 2 velocity encoder [rad/s]";

  // ===== End-effector and obstacle =====
  Real x_ee "End-effector x [m]";
  Real y_ee "End-effector y [m]";
  Real x_j2 "Joint 2 x [m]";
  Real y_j2 "Joint 2 y [m]";
  Real d_link1 "Distance obstacle to link 1 [m]";
  Real d_link2 "Distance obstacle to link 2 [m]";
  Real d_min "Minimum distance to arm [m]";
  Real clearance "Obstacle clearance [m]";

  // ===== Tracking errors =====
  Real e_x "Carriage tracking error [m]";
  Real e_q1 "Joint 1 tracking error [rad]";
  Real e_q2 "Joint 2 tracking error [rad]";

  // ===== Dynamics intermediates =====
  Real s1, c1, s12, c12, s2, c2;
  Real M01, M02, M11, M12, M22;
  Real C0, C1, C2;
  Real G1, G2;
  Real Fd1, Fd2;
  Real detM "Mass matrix determinant";
  Real inv00, inv01, inv02, inv11, inv12, inv22 "Inverse mass matrix elements";
  Real rhs0, rhs1, rhs2 "Right-hand side of dynamics";

  // Trajectory intermediates
  Real tau_s "Normalized segment time";
  Real h_s "Smoothstep value";
  Real hd_s "Smoothstep derivative";

  // Obstacle distance intermediates
  Real t1_uncl "Unclamped projection parameter link 1";
  Real t2_uncl "Unclamped projection parameter link 2";
  Real t1_cl "Clamped projection parameter link 1";
  Real t2_cl "Clamped projection parameter link 2";
  Real cx1, cy1 "Closest point on link 1";
  Real cx2, cy2 "Closest point on link 2";

  // Parameter intermediates
  parameter Real A_c = m1*lc1 + m2*l1;
  parameter Real B_c = m2*lc2;
  parameter Real a1_c = m1*lc1^2 + I1 + m2*l1^2;
  parameter Real a2_c = m2*lc2^2 + I2;
  parameter Real a3_c = m2*l1*lc2;
  parameter Real M00 = m_c + m1 + m2;

equation
  // Trigonometric shorthands
  s1 = sin(q1);   c1 = cos(q1);
  s12 = sin(q1 + q2);  c12 = cos(q1 + q2);
  s2 = sin(q2);   c2 = cos(q2);

  // ===== Trajectory: cubic smoothstep, zero velocity at waypoints, hold after t_seg2 =====
  tau_s = if time < t_seg1 then time / t_seg1
          else if time < t_seg2 then (time - t_seg1) / (t_seg2 - t_seg1)
          else 1.0;
  h_s = 3.0*tau_s^2 - 2.0*tau_s^3;
  hd_s = 6.0*tau_s - 6.0*tau_s^2;

  x_des = if time < t_seg1 then x_wp0 + (x_wp1 - x_wp0)*h_s
          else if time < t_seg2 then x_wp1 + (x_wp2 - x_wp1)*h_s
          else x_wp2;
  xdot_des = if time < t_seg1 then (x_wp1 - x_wp0)*hd_s / t_seg1
             else if time < t_seg2 then (x_wp2 - x_wp1)*hd_s / (t_seg2 - t_seg1)
             else 0.0;

  q1_des = if time < t_seg1 then q1_wp0 + (q1_wp1 - q1_wp0)*h_s
           else if time < t_seg2 then q1_wp1 + (q1_wp2 - q1_wp1)*h_s
           else q1_wp2;
  q1dot_des = if time < t_seg1 then (q1_wp1 - q1_wp0)*hd_s / t_seg1
              else if time < t_seg2 then (q1_wp2 - q1_wp1)*hd_s / (t_seg2 - t_seg1)
              else 0.0;

  q2_des = if time < t_seg1 then q2_wp0 + (q2_wp1 - q2_wp0)*h_s
           else if time < t_seg2 then q2_wp1 + (q2_wp2 - q2_wp1)*h_s
           else q2_wp2;
  q2dot_des = if time < t_seg1 then (q2_wp1 - q2_wp0)*hd_s / t_seg1
              else if time < t_seg2 then (q2_wp2 - q2_wp1)*hd_s / (t_seg2 - t_seg1)
              else 0.0;

  // ===== Sensors: ideal encoders providing synchronized position and velocity =====
  x_enc = x;        xdot_enc = xdot;
  q1_enc = q1;      q1dot_enc = q1dot;
  q2_enc = q2;      q2dot_enc = q2dot;

  // ===== Discrete PID + velocity-feedforward controller at 100 Hz =====
  when sample(0, Ts) then
    integ_x = pre(integ_x) + Ts*(x_des - x_enc);
    integ_q1 = pre(integ_q1) + Ts*(q1_des - q1_enc);
    integ_q2 = pre(integ_q2) + Ts*(q2_des - q2_enc);

    F_cmd = max(-F_max, min(F_max,
      kp_x*(x_des - x_enc) + kd_x*(xdot_des - xdot_enc)
      + ki_x*integ_x + kff_x*xdot_des));

    tau1_cmd = max(-tau_max, min(tau_max,
      kp_q1*(q1_des - q1_enc) + kd_q1*(q1dot_des - q1dot_enc)
      + ki_q1*integ_q1 + kff_q1*q1dot_des));

    tau2_cmd = max(-tau_max, min(tau_max,
      kp_q2*(q2_des - q2_enc) + kd_q2*(q2dot_des - q2dot_enc)
      + ki_q2*integ_q2 + kff_q2*q2dot_des));
  end when;

  // ===== Mass matrix (3-DOF: x, q1, q2) =====
  M01 = -A_c*s1;
  M02 = -B_c*s12;
  M11 = a1_c + a2_c + 2.0*a3_c*c2;
  M12 = a2_c + a3_c*c2;
  M22 = a2_c;

  // ===== Coriolis / centrifugal terms =====
  C0 = -A_c*c1*q1dot^2 - B_c*c12*q2dot*(q1dot + q2dot);
  C1 = B_c*c12*xdot*q2dot - a3_c*s2*q2dot*(2.0*q1dot + q2dot);
  C2 = -B_c*c12*xdot*q1dot + a3_c*s2*q1dot^2;

  // ===== Gravity torques =====
  G1 = A_c*g_acc*c1 + B_c*g_acc*c12;
  G2 = B_c*g_acc*c12;

  // ===== Disturbance: 7 N lateral (Y) force at end-effector during middle third =====
  Fd1 = if (time >= t_seg1) and (time <= t_seg2)
        then F_dist_mag*(l1*c1 + l2*c12) else 0.0;
  Fd2 = if (time >= t_seg1) and (time <= t_seg2)
        then F_dist_mag*l2*c12 else 0.0;

  // ===== Equations of motion: explicit inverse of mass matrix =====
  detM = M00*(M11*M22 - M12^2) - M01*(M01*M22 - M12*M02) + M02*(M01*M12 - M11*M02);
  inv00 = (M11*M22 - M12^2) / detM;
  inv01 = (M12*M02 - M01*M22) / detM;
  inv02 = (M01*M12 - M11*M02) / detM;
  inv11 = (M00*M22 - M02^2) / detM;
  inv12 = (M01*M02 - M00*M12) / detM;
  inv22 = (M00*M11 - M01^2) / detM;

  rhs0 = F_cmd - C0;
  rhs1 = tau1_cmd + Fd1 - C1 - G1;
  rhs2 = tau2_cmd + Fd2 - C2 - G2;

  der(xdot) = inv00*rhs0 + inv01*rhs1 + inv02*rhs2;
  der(q1dot) = inv01*rhs0 + inv11*rhs1 + inv12*rhs2;
  der(q2dot) = inv02*rhs0 + inv12*rhs1 + inv22*rhs2;

  // State integration
  der(x) = xdot;
  der(q1) = q1dot;
  der(q2) = q2dot;

  // ===== End-effector and joint 2 positions =====
  x_j2 = x + l1*c1;
  y_j2 = l1*s1;
  x_ee = x_j2 + l2*c12;
  y_ee = y_j2 + l2*s12;

  // ===== Obstacle clearance: point-to-segment distance for both links =====
  t1_uncl = ((x_obs - x)*(x_j2 - x) + y_obs*y_j2) / (l1^2 + 1.0e-12);
  t2_uncl = ((x_obs - x_j2)*(x_ee - x_j2) + (y_obs - y_j2)*(y_ee - y_j2))
            / (l2^2 + 1.0e-12);
  t1_cl = max(0.0, min(1.0, t1_uncl));
  t2_cl = max(0.0, min(1.0, t2_uncl));
  cx1 = x + t1_cl*(x_j2 - x);
  cy1 = t1_cl*y_j2;
  cx2 = x_j2 + t2_cl*(x_ee - x_j2);
  cy2 = y_j2 + t2_cl*(y_ee - y_j2);
  d_link1 = sqrt((x_obs - cx1)^2 + (y_obs - cy1)^2);
  d_link2 = sqrt((x_obs - cx2)^2 + (y_obs - cy2)^2);
  d_min = min(d_link1, d_link2);
  clearance = d_min - r_obs;

  // ===== Tracking errors =====
  e_x = x_des - x;
  e_q1 = q1_des - q1;
  e_q2 = q2_des - q2;

  // ===== Safety requirement assertions =====
  assert(abs(q1) <= q_limit, "Joint 1 limit violated");
  assert(abs(q2) <= q_limit, "Joint 2 limit violated");
  assert(clearance >= d_clear_req, "Obstacle clearance violated");
  assert(x >= 0.0 and x <= L_rail, "Carriage outside rail bounds");

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "RailArmTraceB: Fixed-base articulated manipulator on 1.4 m X-rail.
      18 kg carriage, 2-revolute-joint planar arm (0.46 m, 0.31 m links),
      joint limits +-1.5 rad. Linear force actuator (800 N) and two rotary
      torque actuators (69.7 N.m). PID + velocity-feedforward trajectory
      control at 100 Hz. Cubic joint trajectory through 3 reachable waypoints
      with hold at final state. 7 N lateral (Y) disturbance at end-effector
      during middle third of mission. Cylindrical keep-out obstacle at
      (1.20, -0.20) m, radius 0.04 m, clearance requirement 0.05 m.

      Assumed values (not specified in requirement): link masses (2.0, 1.5 kg),
      COM distances (mid-link), inertias (uniform rod model).")
  );
end RailArmTraceB;