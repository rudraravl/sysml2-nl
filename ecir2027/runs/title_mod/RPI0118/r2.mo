model CoaxLiftTouchD
  "Instrumented free-base aerial robot: coaxial counter-rotating rotor pairs, probe contact inspection"

  // ===== Physical parameters =====
  parameter Real m_platform = 4.4 "Platform mass [kg]";
  parameter Real m_payload  = 1.2 "Payload mass [kg]";
  parameter Real L_cable    = 0.70 "Cable length [m]";
  parameter Real g          = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_rotor_max = 10.0 "Max thrust per rotor [N]";
  parameter Real mu_wall    = 0.55 "Wall friction coefficient [-]";
  parameter Real arm_length = 0.25 "Arm length center to rotor [m]";
  parameter Real probe_length = 0.35 "Probe length from center [m]";
  parameter Real I_platform = 0.06 "Platform pitch inertia [kg.m2]";
  parameter Real K_contact  = 5000.0 "Contact spring stiffness [N/m]";
  parameter Real D_contact  = 50.0 "Contact damping coefficient [N.s/m]";
  parameter Real x_wall     = 2.8 "Wall x position [m]";
  parameter Real z_ref_val  = 1.0 "Reference altitude [m]";

  // ===== Control parameters =====
  parameter Real Kp_x   = 2.0  "Position x proportional gain [1/s2]";
  parameter Real Kv_x   = 6.0  "Velocity x feedforward gain [1/s]";
  parameter Real Kp_z   = 20.0 "Position z proportional gain [N/m]";
  parameter Real Kd_z   = 6.0  "Position z derivative gain [N.s/m]";
  parameter Real Kp_att = 25.0 "Attitude proportional gain [N.m/rad]";
  parameter Real Kd_att = 5.0  "Attitude derivative gain [N.m.s/rad]";
  parameter Real D_imp  = 20.0 "Impedance damping [N.s/m]";
  parameter Real F_contact_ref = 9.5 "Reference contact force [N]";
  parameter Real approach_speed = 0.35 "Approach speed [m/s]";
  parameter Real theta_max = 0.30 "Max pitch angle [rad]";

  // ===== Mission parameters =====
  parameter Real F_contact_min = 5.0 "Min contact force [N]";
  parameter Real F_contact_max = 14.0 "Max contact force [N]";
  parameter Real t_end  = 14.0 "Total run time [s]";
  parameter Real F_wind = 3.0  "Tangential wind force [N]";
  parameter Real t_wind_start = t_end / 3.0 "Wind start (1/3) [s]";
  parameter Real t_wind_end   = 2.0 * t_end / 3.0 "Wind end (2/3) [s]";
  parameter Real t_hold_start = 3.0 * t_end / 4.0 "Hold contact start (last quarter) [s]";

  // ===== Dynamic states =====
  Real x(start=0.0, fixed=true)       "Platform x position [m]";
  Real vx(start=0.0, fixed=true)     "Platform x velocity [m/s]";
  Real z(start=1.0, fixed=true)      "Platform z position [m]";
  Real vz(start=0.0, fixed=true)     "Platform z velocity [m/s]";
  Real theta(start=0.0, fixed=true)  "Platform pitch [rad]";
  Real omega(start=0.0, fixed=true)  "Platform pitch rate [rad/s]";
  Real phi(start=0.0, fixed=true)    "Payload pendulum angle [rad]";
  Real phidot(start=0.0, fixed=true) "Payload pendulum rate [rad/s]";

  // ===== Rotor thrust channels (8 rotors) =====
  Real F1 "Rotor 1 thrust (front coaxial upper) [N]";
  Real F2 "Rotor 2 thrust (front coaxial lower) [N]";
  Real F3 "Rotor 3 thrust (rear coaxial upper) [N]";
  Real F4 "Rotor 4 thrust (rear coaxial lower) [N]";
  Real F5 "Rotor 5 thrust (front coaxial upper mirror) [N]";
  Real F6 "Rotor 6 thrust (front coaxial lower mirror) [N]";
  Real F7 "Rotor 7 thrust (rear coaxial upper mirror) [N]";
  Real F8 "Rotor 8 thrust (rear coaxial lower mirror) [N]";
  Real F_total "Total thrust [N]";
  Real tau     "Net pitch torque [N.m]";
  Real F_front "Front group per-rotor thrust [N]";
  Real F_rear  "Rear group per-rotor thrust [N]";

  // ===== Contact =====
  Real delta_pen "Probe penetration into wall [m]";
  Real F_contact "Normal contact force [N]";
  Real F_friction "Wall friction force (z-direction) [N]";
  Boolean in_contact "Contact flag";

  // ===== Wind disturbance =====
  Real F_wind_z "Wind force in z [N]";

  // ===== Sensors =====
  Real imu_theta "IMU pitch angle [rad]";
  Real imu_omega "IMU pitch rate [rad/s]";
  Real imu_ax    "IMU x-axis acceleration [m/s2]";
  Real imu_az    "IMU z-axis acceleration [m/s2]";
  Real lidar_dist "Lidar distance to wall [m]";
  Real flow_vx   "Optical flow x velocity [m/s]";
  Real flow_vz   "Optical flow z velocity [m/s]";
  Real probe_force_sensor "Probe force sensor reading [N]";

  // ===== Controller commands =====
  Real F_thrust_cmd "Commanded total thrust [N]";
  Real tau_cmd      "Commanded pitch torque [N.m]";
  Real tau_cmd_raw  "Unsaturated torque command [N.m]";
  Real theta_cmd    "Commanded pitch angle [rad]";
  Real theta_cmd_raw "Unsaturated pitch command [rad]";
  Real Fx_cmd       "Commanded horizontal force [N]";
  Real x_ref        "Reference x position [m]";
  Real z_ref        "Reference z position [m]";

  // ===== Diagnostics =====
  Real tracking_error "Primary tracking error [m]";
  Real m_total "Total mass [kg]";
  Real ax      "Platform x acceleration [m/s2]";
  Real az      "Platform z acceleration [m/s2]";

equation
  // Total mass
  m_total = m_platform + m_payload;

  // Reference trajectory: ramp at approach_speed until contact point
  x_ref = min(approach_speed * time, x_wall - probe_length);
  z_ref = z_ref_val;

  // Wind disturbance: 3 N tangential (vertical) during middle third
  F_wind_z = if (time >= t_wind_start and time <= t_wind_end) then F_wind else 0.0;

  // Contact model: unilateral spring-damper at probe tip
  delta_pen = max(0.0, (x + probe_length) - x_wall);
  in_contact = delta_pen > 1e-6;
  F_contact = if delta_pen > 0.0 then
    K_contact * delta_pen + D_contact * max(0.0, vx)
  else 0.0;
  // Friction opposes vertical sliding (Coulomb, smoothed)
  F_friction = if in_contact then
    -mu_wall * F_contact * tanh(vz / 0.02)
  else 0.0;

  // Platform translational dynamics (platform + payload treated as combined mass)
  ax = (F_total * sin(theta) - F_contact) / m_total;
  az = (F_total * cos(theta) - m_total * g + F_wind_z - F_friction) / m_total;
  der(x) = vx;
  der(vx) = ax;
  der(z) = vz;
  der(vz) = az;
  der(theta) = omega;
  der(omega) = tau / I_platform;

  // Payload pendulum on massless cable
  der(phi) = phidot;
  der(phidot) = -(g / L_cable) * sin(phi) - 0.5 * phidot + (ax * cos(phi)) / L_cable;

  // Thrust allocation: 4 coaxial pairs
  // Front group (rotors 1,2,5,6) contributes positive pitch torque
  // Rear group (rotors 3,4,7,8) contributes negative pitch torque
  F_front = max(0.0, min(F_rotor_max, F_thrust_cmd / 8.0 + tau_cmd / (4.0 * arm_length)));
  F_rear  = max(0.0, min(F_rotor_max, F_thrust_cmd / 8.0 - tau_cmd / (4.0 * arm_length)));
  F1 = F_front;
  F2 = F_front;
  F5 = F_front;
  F6 = F_front;
  F3 = F_rear;
  F4 = F_rear;
  F7 = F_rear;
  F8 = F_rear;
  F_total = 4.0 * F_front + 4.0 * F_rear;
  tau = arm_length * (4.0 * F_front - 4.0 * F_rear);

  // ===== Controller: position-to-impedance hybrid =====
  // Vertical channel: PD position control
  F_thrust_cmd = m_total * g + Kp_z * (z_ref - z) - Kd_z * vz;

  // Horizontal channel: position control in free flight, impedance in contact
  Fx_cmd = if in_contact then
    F_contact_ref + D_imp * (-vx)
  else
    Kp_x * (x_ref - x) + Kv_x * (approach_speed - vx);

  // Convert horizontal force to pitch command (small-angle approximation)
  theta_cmd_raw = Fx_cmd / max(F_thrust_cmd, 1.0);
  theta_cmd = max(-theta_max, min(theta_max, theta_cmd_raw));

  // Inner loop: attitude PD
  tau_cmd_raw = Kp_att * (theta_cmd - theta) - Kd_att * omega;
  tau_cmd = max(-4.0 * arm_length * F_rotor_max,
               min( 4.0 * arm_length * F_rotor_max, tau_cmd_raw));

  // ===== Sensors =====
  imu_theta = theta;
  imu_omega = omega;
  imu_ax = ax;
  imu_az = az;
  lidar_dist = max(0.0, x_wall - (x + probe_length));
  flow_vx = vx;
  flow_vz = vz;
  probe_force_sensor = F_contact;

  // ===== Diagnostics =====
  tracking_error = abs((x + probe_length) - x_wall);

  annotation(
    experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6),
    Documentation(info = "CoaxLiftTouchD: 4.4 kg cargo platform with 8 coaxial rotors (10 N max each) carrying 1.2 kg payload on 0.70 m cable. Approaches vertical wall at x=2.8 m, establishes probe contact (5-14 N), holds during last quarter. Position-to-impedance hybrid control. 3 N vertical wind in middle third. Wall friction mu=0.55. 200 Hz, 14 s. Probe (0.35 m) extends beyond rotor plane (0.25 m) to prevent fan collision.")
  );

end CoaxLiftTouchD;