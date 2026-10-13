model SCARAPointD
  parameter Real m_base = 28.0 "Base mass [kg]";
  parameter Real m1 = 6.0 "Link 1 moving mass [kg]";
  parameter Real m2 = 4.0 "Link 2 moving mass [kg]";
  parameter Real m3 = 2.0 "Carriage moving mass [kg]";
  parameter Real l1 = 0.48 "Link 1 length [m]";
  parameter Real l2 = 0.34 "Link 2 length [m]";
  parameter Real z_travel = 0.30 "Prismatic joint travel [m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // Collision geometry (cylindrical/spherical rigid links)
  parameter Real link1_radius = 0.04 "Link 1 collision cylinder radius [m]";
  parameter Real link2_radius = 0.03 "Link 2 collision cylinder radius [m]";
  parameter Real carriage_radius = 0.05 "Carriage collision sphere radius [m]";
  parameter Real base_radius = 0.12 "Base collision cylinder radius [m]";
  parameter Real base_height = 0.20 "Base collision cylinder height [m]";

  // Joint limits
  parameter Real q1_min = -3.14159 "Joint 1 lower limit [rad]";
  parameter Real q1_max = 3.14159 "Joint 1 upper limit [rad]";
  parameter Real q2_min = -3.14159 "Joint 2 lower limit [rad]";
  parameter Real q2_max = 3.14159 "Joint 2 upper limit [rad]";
  parameter Real q3_min = 0.0 "Joint 3 lower limit [m]";
  parameter Real q3_max = 0.30 "Joint 3 upper limit [m]";

  // Actuator saturation limits
  parameter Real tau1_max = 95.0 "Joint 1 torque saturation [N.m]";
  parameter Real tau2_max = 95.0 "Joint 2 torque saturation [N.m]";
  parameter Real F3_max = 900.0 "Joint 3 force saturation [N]";

  // Reachable target
  parameter Real q1_target = 0.785398 "Target joint 1 position [rad]";
  parameter Real q2_target = -0.523599 "Target joint 2 position [rad]";
  parameter Real q3_target = 0.15 "Target joint 3 position [m]";

  // PD gains
  parameter Real kp1 = 300.0 "Joint 1 proportional gain";
  parameter Real kd1 = 30.0 "Joint 1 derivative gain";
  parameter Real kp2 = 200.0 "Joint 2 proportional gain";
  parameter Real kd2 = 20.0 "Joint 2 derivative gain";
  parameter Real kp3 = 400.0 "Joint 3 proportional gain";
  parameter Real kd3 = 40.0 "Joint 3 derivative gain";

  // Disturbance
  parameter Real F_dist = 8.0 "Tip load disturbance magnitude [N]";

  // Run configuration
  parameter Real T_run = 14.0 "Total run duration [s]";
  parameter Real f_sample = 200.0 "Sampling frequency [Hz]";

  // Dynamic states
  Real q1(start=0.0, fixed=true) "Joint 1 position [rad]";
  Real q1d(start=0.0, fixed=true) "Joint 1 velocity [rad/s]";
  Real q2(start=0.0, fixed=true) "Joint 2 position [rad]";
  Real q2d(start=0.0, fixed=true) "Joint 2 velocity [rad/s]";
  Real q3(start=0.0, fixed=true) "Joint 3 position [m]";
  Real q3d(start=0.0, fixed=true) "Joint 3 velocity [m/s]";

  // Pre-saturation commands
  Real tau1_cmd "Joint 1 unsaturated command [N.m]";
  Real tau2_cmd "Joint 2 unsaturated command [N.m]";
  Real F3_cmd "Joint 3 unsaturated command [N]";

  // Saturated actuator outputs
  Real tau1 "Joint 1 applied torque [N.m]";
  Real tau2 "Joint 2 applied torque [N.m]";
  Real F3 "Joint 3 applied force [N]";

  // Encoder sensor traces
  Real q1_meas "Joint 1 measured position [rad]";
  Real q1d_meas "Joint 1 measured velocity [rad/s]";
  Real q2_meas "Joint 2 measured position [rad]";
  Real q2d_meas "Joint 2 measured velocity [rad/s]";
  Real q3_meas "Joint 3 measured position [m]";
  Real q3d_meas "Joint 3 measured velocity [m/s]";

  // Tracking errors
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [m]";

  // Disturbance and gravity compensation
  Real F_disturbance "Active tip disturbance force [N]";
  Real grav3 "Joint 3 gravity compensation force [N]";

  // Dynamics intermediates
  Real M11 "Inertia matrix element (1,1) [kg.m2]";
  Real M12 "Inertia matrix element (1,2) [kg.m2]";
  Real M22 "Inertia matrix element (2,2) [kg.m2]";
  Real C1 "Coriolis/centrifugal term 1 [N.m]";
  Real C2 "Coriolis/centrifugal term 2 [N.m]";
  Real q1dd "Joint 1 acceleration [rad/s2]";
  Real q2dd "Joint 2 acceleration [rad/s2]";
  Real q3dd "Joint 3 acceleration [m/s2]";
  Real detM "Inertia matrix determinant [kg2.m4]";

  // Cartesian tip position
  Real x_tip "Tip x-coordinate [m]";
  Real y_tip "Tip y-coordinate [m]";
  Real z_tip "Tip z-coordinate [m]";

protected
  parameter Real r1 = 0.5 * l1 "Link 1 center of mass distance [m]";
  parameter Real r2 = 0.5 * l2 "Link 2 center of mass distance [m]";

equation
  // Disturbance: 8 N downward tip load during middle third of run
  F_disturbance = if (time >= T_run / 3.0 and time < 2.0 * T_run / 3.0) then F_dist else 0.0;

  // Gravity compensation: only prismatic joint affected by gravity.
  // Revolute joints rotate about vertical Z axis so gravity torque is zero.
  grav3 = m3 * g;

  // Tracking errors
  e1 = q1_target - q1;
  e2 = q2_target - q2;
  e3 = q3_target - q3;

  // PD control with gravity compensation
  tau1_cmd = kp1 * e1 + kd1 * (-q1d);
  tau2_cmd = kp2 * e2 + kd2 * (-q2d);
  F3_cmd = kp3 * e3 + kd3 * (-q3d) - grav3;

  // Actuator saturation
  tau1 = max(-tau1_max, min(tau1_max, tau1_cmd));
  tau2 = max(-tau2_max, min(tau2_max, tau2_cmd));
  F3 = max(-F3_max, min(F3_max, F3_cmd));

  // Encoder measurements (perfect sensors)
  q1_meas = q1;
  q1d_meas = q1d;
  q2_meas = q2;
  q2d_meas = q2d;
  q3_meas = q3;
  q3d_meas = q3d;

  // Cartesian tip position
  x_tip = l1 * cos(q1) + l2 * cos(q1 + q2);
  y_tip = l1 * sin(q1) + l2 * sin(q1 + q2);
  z_tip = -q3;

  // Inertia matrix (planar 2-link, lumped masses at link COM)
  M11 = m1 * r1 * r1 + m2 * (l1 * l1 + r2 * r2 + 2.0 * l1 * r2 * cos(q2)) + m3 * (l1 * l1 + l2 * l2 + 2.0 * l1 * l2 * cos(q2));
  M12 = m2 * (r2 * r2 + l1 * r2 * cos(q2)) + m3 * (l2 * l2 + l1 * l2 * cos(q2));
  M22 = m2 * r2 * r2 + m3 * l2 * l2;
  detM = max(M11 * M22 - M12 * M12, 1.0e-6);

  // Coriolis and centrifugal terms
  C1 = -(m2 * r2 + m3 * l2) * l1 * sin(q2) * q2d * q2d - 2.0 * (m2 * r2 + m3 * l2) * l1 * sin(q2) * q1d * q2d;
  C2 = (m2 * r2 + m3 * l2) * l1 * sin(q2) * q1d * q1d;

  // Revolute joint dynamics: M * qdd + C = tau
  q1dd = (M22 * (tau1 - C1) - M12 * (tau2 - C2)) / detM;
  q2dd = (M11 * (tau2 - C2) - M12 * (tau1 - C1)) / detM;

  // Prismatic joint dynamics: m3 * q3dd = F3 + m3*g + F_disturbance
  // q3 positive downward; gravity and downward disturbance act in positive q3 direction
  q3dd = (F3 + m3 * g + F_disturbance) / m3;

  // State derivatives
  der(q1) = q1d;
  der(q1d) = q1dd;
  der(q2) = q2d;
  der(q2d) = q2dd;
  der(q3) = q3d;
  der(q3d) = q3dd;

  // Joint limit hard stops
  when q1 < q1_min then
    reinit(q1, q1_min);
    reinit(q1d, 0.0);
  end when;
  when q1 > q1_max then
    reinit(q1, q1_max);
    reinit(q1d, 0.0);
  end when;
  when q2 < q2_min then
    reinit(q2, q2_min);
    reinit(q2d, 0.0);
  end when;
  when q2 > q2_max then
    reinit(q2, q2_max);
    reinit(q2d, 0.0);
  end when;
  when q3 < q3_min then
    reinit(q3, q3_min);
    reinit(q3d, 0.0);
  end when;
  when q3 > q3_max then
    reinit(q3, q3_max);
    reinit(q3d, 0.0);
  end when;

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "SCARA articulated manipulator SCARAPointD: two revolute Z-axis joints (0.48 m, 0.34 m links) and one prismatic Z-axis joint (0.30 m travel). Moving masses 6, 4, 2 kg on 28 kg fixed base. Joint-space PD control with gravity compensation. 8 N tip disturbance during middle third. 200 Hz sample rate, 14 s run. Saturated actuators: 95 N.m (revolute) / 900 N (prismatic)."));
end SCARAPointD;