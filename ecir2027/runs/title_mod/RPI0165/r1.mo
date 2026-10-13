model SCARARejectC
  // Physical parameters
  parameter Real L1 = 0.48 "link 1 length [m]";
  parameter Real L2 = 0.34 "link 2 length [m]";
  parameter Real L3_travel = 0.30 "prismatic travel [m]";
  parameter Real m_base = 28.0 "cylindrical base mass [kg]";
  parameter Real m1 = 6.0 "link 1 moving mass [kg]";
  parameter Real m2 = 4.0 "link 2 moving mass [kg]";
  parameter Real m3 = 2.0 "carriage moving mass [kg]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real b1 = 0.5 "joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.3 "joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 5.0 "joint 3 viscous damping [N.s/m]";

  // Nonzero joint targets
  parameter Real q1_t = 0.50 "target joint 1 angle [rad]";
  parameter Real q2_t = 0.40 "target joint 2 angle [rad]";
  parameter Real q3_t = 0.15 "target joint 3 height [m]";

  // Saturated state-feedback with integral disturbance rejection
  parameter Real Kp1 = 80.0;
  parameter Real Kd1 = 20.0;
  parameter Real Ki1 = 15.0;
  parameter Real Kp2 = 30.0;
  parameter Real Kd2 = 8.0;
  parameter Real Ki2 = 5.0;
  parameter Real Kp3 = 300.0;
  parameter Real Kd3 = 50.0;
  parameter Real Ki3 = 80.0;

  // Saturation limits
  parameter Real u1_max = 87.4 "max joint 1 torque command [N.m]";
  parameter Real u2_max = 87.4 "max joint 2 torque command [N.m]";
  parameter Real u3_max = 900.0 "max joint 3 force command [N]";

  // Disturbance: finite-duration lateral load at distal link (middle third of 12 s)
  parameter Real F_dist_mag = 16.2 "lateral disturbance force magnitude [N]";
  parameter Real t_dist_start = 4.0 "disturbance start [s]";
  parameter Real t_dist_end = 8.0 "disturbance end [s]";

  // Self-collision between nonadjacent links (1 and 3): compliant barrier on q2
  parameter Real q2_collision_limit = 2.8 "rad, fold-back collision barrier";
  parameter Real k_contact = 500.0 "contact stiffness [N.m/rad]";

  // Prismatic travel stops
  parameter Real q3_min = 0.0 "lower travel bound [m]";
  parameter Real q3_max = 0.30 "upper travel bound [m]";
  parameter Real k_stop = 2000.0 "stop stiffness [N/m]";

  // Control intended rate (continuous-time realization of 125 Hz controller)
  parameter Real Ts_ctrl = 1.0/125.0 "nominal control period [s]";

  // Dynamic states
  Real q1(start=0.0, fixed=true) "joint 1 angle [rad]";
  Real q1_dot(start=0.0, fixed=true) "joint 1 velocity [rad/s]";
  Real q2(start=0.0, fixed=true) "joint 2 angle [rad]";
  Real q2_dot(start=0.0, fixed=true) "joint 2 velocity [rad/s]";
  Real q3(start=0.0, fixed=true) "joint 3 height [m]";
  Real q3_dot(start=0.0, fixed=true) "joint 3 velocity [m/s]";
  Real xi1(start=0.0, fixed=true) "integral state 1";
  Real xi2(start=0.0, fixed=true) "integral state 2";
  Real xi3(start=0.0, fixed=true) "integral state 3";

  // Commands
  Real u1_raw, u2_raw, u3_raw;
  Real u1 "joint 1 torque command [N.m]";
  Real u2 "joint 2 torque command [N.m]";
  Real u3 "joint 3 force command [N]";

  // Tracking errors
  Real e1, e2, e3;

  // Disturbance
  Real F_dist "applied lateral force [N]";
  Real tau_dist1 "disturbance torque on joint 1 [N.m]";
  Real tau_dist2 "disturbance torque on joint 2 [N.m]";

  // Contact / stops
  Real F_contact1, F_contact2;
  Real F_stop3;

  // Inertia / Coriolis
  Real M11, M12, M21, M22, detM;
  Real h_cor, cor1, cor2;
  Real rhs1, rhs2;
  Real r1c, r2c, cq2, sq2;

  // Wrist wrench sensor
  Real F_wrist_x "wrist force x [N]";
  Real F_wrist_y "wrist force y [N]";
  Real F_wrist_z "wrist force z [N]";

  // Wrist kinematics
  Real x_wrist, y_wrist, z_wrist;
  Real r_wrist "horizontal distance from base [m]";

equation
  // Centers of mass
  r1c = L1/2.0;
  r2c = L2/2.0;
  cq2 = cos(q2);
  sq2 = sin(q2);

  // Inertia matrix (planar 2-link with point masses at link centers and carriage at tip)
  M11 = m1*r1c^2 + m2*(L1^2 + 2.0*L1*r2c*cq2 + r2c^2) + m3*(L1^2 + 2.0*L1*L2*cq2 + L2^2);
  M12 = m2*(r2c^2 + L1*r2c*cq2) + m3*(L2^2 + L1*L2*cq2);
  M21 = M12;
  M22 = m2*r2c^2 + m3*L2^2;
  detM = M11*M22 - M12*M21;

  // Coriolis / centrifugal
  h_cor = (m2*L1*r2c + m3*L1*L2)*sq2;
  cor1 = -h_cor*(2.0*q1_dot + q2_dot)*q2_dot;
  cor2 = h_cor*q1_dot^2;

  // Disturbance: lateral (y) force at wrist during middle third of run
  F_dist = if (time >= t_dist_start and time <= t_dist_end) then F_dist_mag else 0.0;
  tau_dist1 = (L1*cos(q1) + L2*cos(q1+q2))*F_dist;
  tau_dist2 = L2*cos(q1+q2)*F_dist;

  // Self-collision between nonadjacent links (base link 1 and carriage link 3)
  F_contact1 = 0.0;
  F_contact2 = if (q2 > q2_collision_limit) then -k_contact*(q2 - q2_collision_limit)
               else if (q2 < -q2_collision_limit) then -k_contact*(q2 + q2_collision_limit)
               else 0.0;

  // Prismatic travel stops
  F_stop3 = if (q3 < q3_min) then -k_stop*(q3 - q3_min)
            else if (q3 > q3_max) then -k_stop*(q3 - q3_max)
            else 0.0;

  // Tracking errors
  e1 = q1 - q1_t;
  e2 = q2 - q2_t;
  e3 = q3 - q3_t;

  // Integral states
  der(xi1) = e1;
  der(xi2) = e2;
  der(xi3) = e3;

  // Saturated state-feedback commands with gravity feedforward on prismatic axis
  u1_raw = -(Kp1*e1 + Kd1*q1_dot + Ki1*xi1);
  u2_raw = -(Kp2*e2 + Kd2*q2_dot + Ki2*xi2);
  u3_raw = -(Kp3*e3 + Kd3*q3_dot + Ki3*xi3) + m3*g;

  u1 = if (u1_raw > u1_max) then u1_max else if (u1_raw < -u1_max) then -u1_max else u1_raw;
  u2 = if (u2_raw > u2_max) then u2_max else if (u2_raw < -u2_max) then -u2_max else u2_raw;
  u3 = if (u3_raw > u3_max) then u3_max else if (u3_raw < -u3_max) then -u3_max else u3_raw;

  // Revolute dynamics (invert 2x2 inertia)
  rhs1 = u1 - cor1 - b1*q1_dot - tau_dist1 - F_contact1;
  rhs2 = u2 - cor2 - b2*q2_dot - tau_dist2 - F_contact2;
  der(q1) = q1_dot;
  der(q2) = q2_dot;
  der(q1_dot) = (M22*rhs1 - M12*rhs2)/detM;
  der(q2_dot) = (M11*rhs2 - M21*rhs1)/detM;

  // Prismatic dynamics (vertical, gravity included)
  der(q3) = q3_dot;
  der(q3_dot) = (u3 - m3*g - b3*q3_dot + F_stop3)/m3;

  // Wrist wrench sensor (measures external lateral load)
  F_wrist_x = 0.0;
  F_wrist_y = F_dist;
  F_wrist_z = 0.0;

  // Wrist kinematics
  x_wrist = L1*cos(q1) + L2*cos(q1+q2);
  y_wrist = L1*sin(q1) + L2*sin(q1+q2);
  z_wrist = q3;
  r_wrist = sqrt(x_wrist^2 + y_wrist^2);

  annotation(
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="Fixed-base articulated SCARA manipulator with saturated state-feedback control and integral disturbance rejection. Two revolute Z links (0.48 m, 0.34 m) and one prismatic Z carriage (0.30 m travel). 16.2 N lateral disturbance applied at distal link during 4-8 s. Control realized continuously at the 125 Hz intended rate."));
end SCARARejectC;