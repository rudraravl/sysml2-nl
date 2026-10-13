model QuadScoutDeliverA
  // Physical facts from requirement
  parameter Real m_q = 1.8 "fuselage mass, kg";
  parameter Real arm = 0.22 "rotor arm length, m";
  parameter Real f_max = 8.64 "per-rotor thrust command limit, N";
  parameter Real g = 9.81 "gravitational acceleration, m/s^2";
  parameter Real x_target = 5.0 "horizontal translation distance, m";
  parameter Real target_radius = 0.8 "target-zone radius, m";
  parameter Real t_final = 8.0 "scenario duration, s";
  parameter Real Ts = 1.0/80.0 "controller/sensor sample period, s";
  parameter Real F_gust_amp = 4.0 "controlled gust disturbance, N";

  // Facts not stated in the requirement are marked as placeholders below.
  // They are bound only to make the model executable; replace with identified values.
  parameter Real m_p = 0.5 "payload mass, not specified; placeholder";
  parameter Real L_cable = 0.6 "cable length, not specified; placeholder";
  parameter Real c_drag = 0.2 "aerodynamic drag coefficient, not specified; placeholder";
  parameter Real Iyy = 0.02 "pitch inertia, not specified; placeholder";
  parameter Real Izz = 0.03 "yaw inertia, not specified; placeholder";
  parameter Real kYaw = 0.10 "rotor yaw-moment coefficient, not specified; placeholder";
  parameter Real T_cable_max = 30.0 "cable tension bound, not specified; placeholder";

  // Derived constants
  parameter Real m_total = m_q + m_p;
  parameter Real T_total_max = 4.0*f_max;
  parameter Real t_gust_start = t_final/3.0;
  parameter Real t_gust_end = 2.0*t_final/3.0;

  // Scenario geometry/timing placeholders
  parameter Real x0 = 0.0;
  parameter Real z0 = 1.8;
  parameter Real z_cruise = 3.0;
  parameter Real z_target_drone = 1.0;
  parameter Real t_lift = 1.0;
  parameter Real t_x_start = 1.5;
  parameter Real t_x_end = 4.5;
  parameter Real t_lower_start = 5.0;
  parameter Real t_lower_end = 6.5;

  // Controller gains (design choices)
  parameter Real Kp_x = 4.0;
  parameter Real Kd_x = 5.5;
  parameter Real Kp_z = 5.0;
  parameter Real Kd_z = 7.0;
  parameter Real Kp_pitch = 5.0;
  parameter Real Kd_pitch = 1.5;
  parameter Real Kp_yaw = 3.0;
  parameter Real Kd_yaw = 2.0;
  parameter Real K_swing = 1.0;
  parameter Real K_swing_d = 1.5;
  parameter Real theta_max = 0.35;
  parameter Real c_pitch = 0.01;
  parameter Real c_yaw = 0.01;

  // Continuous states
  Real x(start=x0, fixed=true);
  Real vx(start=0, fixed=true);
  Real z(start=z0, fixed=true);
  Real vz(start=0, fixed=true);
  Real theta(start=0, fixed=true) "pitch angle, rad";
  Real theta_dot(start=0, fixed=true);
  Real psi(start=0, fixed=true) "yaw angle, rad";
  Real psi_dot(start=0, fixed=true);
  Real phi(start=0, fixed=true) "cable angle from vertical, rad";
  Real phi_dot(start=0, fixed=true);

  // Algebraic physical variables
  Real ax;
  Real az;
  Real theta_ddot;
  Real psi_ddot;
  Real phi_ddot;
  Real Fc "cable tension, N";
  Real F_gust;
  Real D_x;
  Real D_z;
  Real sphi;
  Real cphi;
  Real A11;
  Real A12;
  Real A21;
  Real A22;
  Real b1;
  Real b2;
  Real detM;
  Real detSafe;
  Real L_cable_safe;
  Real Iyy_safe;
  Real Izz_safe;
  Real kYaw_safe;

  // Rotor commands and actual outputs
  discrete Real T_cmd(start=m_total*g, fixed=true);
  discrete Real theta_cmd(start=0, fixed=true);
  discrete Real M_pitch_cmd(start=0, fixed=true);
  discrete Real M_yaw_cmd(start=0, fixed=true);
  discrete Real ax_des(start=0, fixed=true);
  Real f1_cmd;
  Real f2_cmd;
  Real f3_cmd;
  Real f4_cmd;
  Real f1;
  Real f2;
  Real f3;
  Real f4;
  Real T_actual;
  Real M_pitch_actual;
  Real M_yaw_actual;

  // Sensors
  Real gps_x;
  Real gps_z;
  Real gps_vx;
  Real gps_vz;
  Real imu_ax;
  Real imu_az;
  Real imu_theta;
  Real imu_theta_dot;
  Real imu_psi;
  Real imu_psi_dot;
  Real cable_angle_meas;
  Real cable_rate_meas;
  Real cable_tension_meas;

  // Simple sensor-fusion estimator (no estimator algorithm specified)
  Real est_x;
  Real est_z;
  Real est_theta;

  // Payload state
  Real x_payload;
  Real z_payload;
  Real vx_payload;
  Real vz_payload;

  // Reference and monitoring
  Real tau_x;
  Real Sx;
  Real x_ref;
  Real vx_ref;
  Real tau_l;
  Real z_ref;
  Real vz_ref;
  Real tracking_error;
  Real target_zone_error;
  Boolean in_target_zone;
  Boolean no_ground_strike;
  Boolean swing_ok;
  Boolean thrust_bounds_ok;
  Boolean tension_bounds_ok;
  Boolean primary_error_ok;

  // Synchronized 80 Hz traces
  discrete Integer tick(start=0, fixed=true);
  discrete Real x_tick(start=x0, fixed=true);
  discrete Real z_tick(start=z0, fixed=true);
  discrete Real vx_tick(start=0, fixed=true);
  discrete Real vz_tick(start=0, fixed=true);
  discrete Real theta_tick(start=0, fixed=true);
  discrete Real phi_tick(start=0, fixed=true);
  discrete Real gps_x_tick(start=x0, fixed=true);
  discrete Real gps_z_tick(start=z0, fixed=true);
  discrete Real imu_ax_tick(start=0, fixed=true);
  discrete Real cable_angle_tick(start=0, fixed=true);
  discrete Real cable_tension_tick(start=0, fixed=true);
  discrete Real T_cmd_tick(start=m_total*g, fixed=true);
  discrete Real theta_cmd_tick(start=0, fixed=true);
  discrete Real M_pitch_cmd_tick(start=0, fixed=true);
  discrete Real M_yaw_cmd_tick(start=0, fixed=true);

equation
  // Safe divisors and inertias
  L_cable_safe = if L_cable > 1e-3 then L_cable else 1e-3;
  Iyy_safe = if Iyy > 1e-4 then Iyy else 1e-4;
  Izz_safe = if Izz > 1e-4 then Izz else 1e-4;
  kYaw_safe = if kYaw > 1e-4 then kYaw else 1e-4;

  // State derivatives
  der(x) = vx;
  der(vx) = ax;
  der(z) = vz;
  der(vz) = az;
  der(theta) = theta_dot;
  der(theta_dot) = theta_ddot;
  der(psi) = psi_dot;
  der(psi_dot) = psi_ddot;
  der(phi) = phi_dot;
  der(phi_dot) = phi_ddot;

  // Input-shaped horizontal reference
  tau_x = (time - t_x_start)/(t_x_end - t_x_start);
  Sx = if time <= t_x_start then 0.0 elseif time >= t_x_end then 1.0 else 3.0*tau_x*tau_x - 2.0*tau_x*tau_x*tau_x;
  x_ref = x_target*Sx;
  vx_ref = if time <= t_x_start or time >= t_x_end then 0.0 else x_target*(6.0*tau_x - 6.0*tau_x*tau_x)/(t_x_end - t_x_start);

  // Input-shaped vertical reference: lift, cruise, lower
  tau_l = (time - t_lower_start)/(t_lower_end - t_lower_start);
  z_ref =
    if time <= t_lift then z0 + (z_cruise - z0)*(3.0*(time/t_lift)*(time/t_lift) - 2.0*(time/t_lift)*(time/t_lift)*(time/t_lift))
    elseif time <= t_lower_start then z_cruise
    elseif time <= t_lower_end then z_cruise + (z_target_drone - z_cruise)*(3.0*tau_l*tau_l - 2.0*tau_l*tau_l*tau_l)
    else z_target_drone;

  vz_ref =
    if time <= t_lift then (z_cruise - z0)*(6.0*(time/t_lift) - 6.0*(time/t_lift)*(time/t_lift))/t_lift
    elseif time <= t_lower_start then 0.0
    elseif time <= t_lower_end then (z_target_drone - z_cruise)*(6.0*tau_l - 6.0*tau_l*tau_l)/(t_lower_end - t_lower_start)
    else 0.0;

  // Gust during middle third of scenario
  F_gust = if time >= t_gust_start and time <= t_gust_end then F_gust_amp else 0.0;

  // Aerodynamic drag
  D_x = c_drag*vx;
  D_z = c_drag*vz;

  // Sensors
  gps_x = x;
  gps_z = z;
  gps_vx = vx;
  gps_vz = vz;
  imu_ax = ax;
  imu_az = az;
  imu_theta = theta;
  imu_theta_dot = theta_dot;
  imu_psi = psi;
  imu_psi_dot = psi_dot;
  cable_angle_meas = phi;
  cable_rate_meas = phi_dot;
  cable_tension_meas = if Fc > 0.0 then Fc else 0.0;

  // Estimator (ideal fusion placeholder)
  est_x = gps_x;
  est_z = gps_z;
  est_theta = imu_theta;

  // Discrete controller and synchronized trace update at 80 Hz
  when sample(0, Ts) then
    tick = pre(tick) + 1;

    // Input-shaped position control with cable-swing damping
    ax_des = Kp_x*(x_ref - gps_x) + Kd_x*(vx_ref - gps_vx) + K_swing*cable_angle_meas + K_swing_d*cable_rate_meas;

    T_cmd = max(1.0, min(T_total_max, m_total*g + Kp_z*(z_ref - gps_z) + Kd_z*(vz_ref - gps_vz)));
    theta_cmd = max(-theta_max, min(theta_max, atan2(m_total*ax_des, max(T_cmd, 1.0))));
    M_pitch_cmd = Kp_pitch*(theta_cmd - imu_theta) - Kd_pitch*imu_theta_dot;
    M_yaw_cmd = -Kp_yaw*imu_psi - Kd_yaw*imu_psi_dot;

    x_tick = x;
    z_tick = z;
    vx_tick = vx;
    vz_tick = vz;
    theta_tick = theta;
    phi_tick = phi;
    gps_x_tick = gps_x;
    gps_z_tick = gps_z;
    imu_ax_tick = imu_ax;
    cable_angle_tick = cable_angle_meas;
    cable_tension_tick = cable_tension_meas;
    T_cmd_tick = T_cmd;
    theta_cmd_tick = theta_cmd;
    M_pitch_cmd_tick = M_pitch_cmd;
    M_yaw_cmd_tick = M_yaw_cmd;
  end when;

  // Rotor mixing: front=(1,4), rear=(2,3); pitch, yaw, and total thrust
  f1_cmd = T_cmd/4.0 + M_pitch_cmd/(4.0*arm) + M_yaw_cmd/(4.0*kYaw_safe);
  f2_cmd = T_cmd/4.0 - M_pitch_cmd/(4.0*arm) - M_yaw_cmd/(4.0*kYaw_safe);
  f3_cmd = T_cmd/4.0 - M_pitch_cmd/(4.0*arm) + M_yaw_cmd/(4.0*kYaw_safe);
  f4_cmd = T_cmd/4.0 + M_pitch_cmd/(4.0*arm) - M_yaw_cmd/(4.0*kYaw_safe);

  f1 = max(0.0, min(f_max, f1_cmd));
  f2 = max(0.0, min(f_max, f2_cmd));
  f3 = max(0.0, min(f_max, f3_cmd));
  f4 = max(0.0, min(f_max, f4_cmd));

  T_actual = f1 + f2 + f3 + f4;
  M_pitch_actual = arm*(f1 + f4 - f2 - f3);
  M_yaw_actual = kYaw_safe*(f1 - f2 + f3 - f4);

  // Attitude dynamics
  theta_ddot = (M_pitch_actual - c_pitch*theta_dot)/Iyy_safe;
  psi_ddot = (M_yaw_actual - c_yaw*psi_dot)/Izz_safe;

  // Coupled drone-payload translational dynamics
  sphi = sin(phi);
  cphi = cos(phi);

  A11 = m_q + m_p*sphi*sphi;
  A12 = -m_p*sphi*cphi;
  A21 = m_p*cphi*sphi;
  A22 = m_q + m_p*cphi*cphi;

  b1 = T_actual*sin(theta) - D_x + F_gust + m_p*sphi*(g*cphi + L_cable_safe*phi_dot*phi_dot);
  b2 = T_actual*cos(theta) - m_q*g - D_z - m_p*cphi*(g*cphi + L_cable_safe*phi_dot*phi_dot);

  detM = A11*A22 - A12*A21;
  detSafe = if detM > 1e-9 then detM else 1e-9;

  ax = (b1*A22 - A12*b2)/detSafe;
  az = (A11*b2 - A21*b1)/detSafe;

  phi_ddot = (-g*sphi - ax*cphi - az*sphi)/L_cable_safe;
  Fc = m_p*((g + az)*cphi - ax*sphi + L_cable_safe*phi_dot*phi_dot);

  // Payload kinematics
  x_payload = x + L_cable_safe*sin(phi);
  z_payload = z - L_cable_safe*cos(phi);
  vx_payload = vx + L_cable_safe*phi_dot*cos(phi);
  vz_payload = vz + L_cable_safe*phi_dot*sin(phi);

  // Monitoring quantities
  tracking_error = sqrt(max((x_ref - x)*(x_ref - x) + (z_ref - z)*(z_ref - z), 0.0));
  target_zone_error = sqrt(max((x_payload - x_target)*(x_payload - x_target) + z_payload*z_payload, 0.0));
  in_target_zone = target_zone_error <= target_radius;
  no_ground_strike = z > 0.1 and z_payload > 0.05;
  swing_ok = abs(phi) <= 0.45;
  thrust_bounds_ok =
    f1 >= -1e-6 and f2 >= -1e-6 and f3 >= -1e-6 and f4 >= -1e-6 and
    f1 <= f_max + 1e-6 and f2 <= f_max + 1e-6 and f3 <= f_max + 1e-6 and f4 <= f_max + 1e-6;
  tension_bounds_ok = cable_tension_meas >= -1e-6 and cable_tension_meas <= T_cable_max + 1e-6;
  primary_error_ok = time < 5.2 or tracking_error <= 0.405;

  // Requirement assertions
  assert(thrust_bounds_ok, "rotor thrust bound violated");
  assert(tension_bounds_ok, "cable tension bound violated");
  assert(swing_ok, "cable swing exceeded 0.45 rad");
  assert(no_ground_strike, "ground strike detected");
  assert(primary_error_ok, "primary tracking error after 5.2 s exceeded 0.405 m");
  assert(time < 7.5 or in_target_zone, "target-zone placement violated");
  assert(
    abs(x) < 1e6 and abs(z) < 1e6 and abs(vx) < 1e6 and abs(vz) < 1e6 and
    abs(theta) < 1e6 and abs(phi) < 1e6 and abs(psi) < 1e6 and
    abs(T_cmd) < 1e6 and abs(theta_cmd) < 1e6 and abs(M_pitch_cmd) < 1e6 and
    abs(M_yaw_cmd) < 1e6 and abs(ax_des) < 1e6 and
    abs(est_x) < 1e6 and abs(est_z) < 1e6 and abs(est_theta) < 1e6,
    "non-finite physical, control, or estimator value");

  annotation(experiment(StartTime=0, StopTime=8, Tolerance=1e-6, Interval=0.0125));
end QuadScoutDeliverA;