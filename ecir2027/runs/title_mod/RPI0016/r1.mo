model QuadScoutDeliverD
  "Instrumented free-base aerial robot with suspended payload delivery mission";

  // === Physical parameters (from requirement) ===
  parameter Real m_body = 1.8 "fuselage mass [kg]";
  parameter Real L_arm = 0.22 "rotor arm length [m]";
  parameter Real T_max = 12.0 "max thrust per rotor [N]";
  parameter Real g = 9.81 "gravitational acceleration [m/s^2]";
  parameter Real rho_air = 1.225 "air density [kg/m^3]";
  parameter Real Cd_A = 0.015 "drag coefficient times frontal area [m^2]";

  // === Assumed parameters (not stated in requirement) ===
  parameter Real m_payload = 0.5 "payload mass [kg] -- assumed";
  parameter Real L_cable = 0.8 "cable length [m] -- assumed";
  parameter Real Ixx = 0.015 "roll inertia [kg.m^2] -- estimated";
  parameter Real Iyy = 0.015 "pitch inertia [kg.m^2] -- estimated";
  parameter Real Izz = 0.030 "yaw inertia [kg.m^2] -- estimated";
  parameter Real k_yaw = 0.06 "yaw moment coefficient [N.m/N] -- estimated";

  // === Derived constants ===
  parameter Real L2 = L_arm / sqrt(2.0) "effective moment arm for X-config [m]";
  constant Real pi_val = 3.141592653589793;
  constant Real eps = 1.0e-6;

  // === Mission parameters ===
  parameter Real z_cruise = 3.0 "cruise altitude [m]";
  parameter Real x_target = 5.0 "horizontal translation distance [m]";
  parameter Real z_lower = 0.5 "payload lowering altitude [m]";
  parameter Real target_radius = 0.8 "target zone radius [m]";
  parameter Real gust_force = 8.0 "gust disturbance force [N]";
  parameter Real swing_limit = 0.45 "max cable swing angle [rad]";
  parameter Real track_err_limit = 0.3 "tracking error limit after 9.1 s [m]";

  // === Controller gains ===
  parameter Real kp_pos = 2.5 "position proportional gain";
  parameter Real kd_pos = 3.0 "position derivative gain";
  parameter Real kp_att = 10.0 "attitude proportional gain";
  parameter Real kd_att = 3.0 "attitude derivative gain";
  parameter Real kp_yaw = 5.0 "yaw proportional gain";
  parameter Real kd_yaw = 2.0 "yaw derivative gain";
  parameter Real k_swing = 1.5 "cable-swing damping gain";
  parameter Real tau_filt = 0.02 "cable-rate filter time constant [s]";

  // === Body translational states ===
  Real x(start=0.0, fixed=true) "body x position [m]";
  Real y(start=0.0, fixed=true) "body y position [m]";
  Real z(start=0.9, fixed=true) "body z position [m]";
  Real vx(start=0.0, fixed=true) "body x velocity [m/s]";
  Real vy(start=0.0, fixed=true) "body y velocity [m/s]";
  Real vz(start=0.0, fixed=true) "body z velocity [m/s]";

  // === Body rotational states ===
  Real phi(start=0.0, fixed=true) "roll angle [rad]";
  Real theta_a(start=0.0, fixed=true) "pitch angle [rad]";
  Real psi(start=0.0, fixed=true) "yaw angle [rad]";
  Real pb(start=0.0, fixed=true) "roll rate [rad/s]";
  Real qb(start=0.0, fixed=true) "pitch rate [rad/s]";
  Real rb(start=0.0, fixed=true) "yaw rate [rad/s]";

  // === Cable-pendulum states ===
  Real alpha_x(start=0.0, fixed=true) "cable angle in x-z plane [rad]";
  Real alpha_y(start=0.0, fixed=true) "cable angle in y-z plane [rad]";
  Real alpha_xd(start=0.0, fixed=true) "cable angular rate x [rad/s]";
  Real alpha_yd(start=0.0, fixed=true) "cable angular rate y [rad/s]";
  Real alpha_xd_f(start=0.0, fixed=true) "filtered cable rate x [rad/s]";
  Real alpha_yd_f(start=0.0, fixed=true) "filtered cable rate y [rad/s]";

  // === Actuator variables ===
  Real T1_cmd "commanded thrust rotor 1 [N]";
  Real T2_cmd "commanded thrust rotor 2 [N]";
  Real T3_cmd "commanded thrust rotor 3 [N]";
  Real T4_cmd "commanded thrust rotor 4 [N]";
  Real T1 "actual thrust rotor 1 [N]";
  Real T2 "actual thrust rotor 2 [N]";
  Real T3 "actual thrust rotor 3 [N]";
  Real T4 "actual thrust rotor 4 [N]";
  Real T_total "total actual thrust [N]";
  Real T_total_cmd "commanded total thrust [N]";
  Real Mx "roll moment [N.m]";
  Real My "pitch moment [N.m]";
  Real Mz "yaw moment [N.m]";

  // === Reference and controller variables ===
  Real x_ref "reference x [m]";
  Real y_ref "reference y [m]";
  Real z_ref "reference z [m]";
  Real ax_des "desired x acceleration [m/s^2]";
  Real ay_des "desired y acceleration [m/s^2]";
  Real az_des "desired z acceleration [m/s^2]";
  Real theta_des "desired pitch [rad]";
  Real phi_des "desired roll [rad]";
  Real ss_lift "smoothstep for lift phase";
  Real ss_trans "smoothstep for translation phase";
  Real ss_lower "smoothstep for lower phase";

  // === Environmental variables ===
  Real gust_x "lateral gust force [N]";
  Real F_drag_x "drag force x [N]";
  Real F_drag_y "drag force y [N]";
  Real F_drag_z "drag force z [N]";

  // === Cable and payload variables ===
  Real tension "cable tension [N]";
  Real px "payload x [m]";
  Real py "payload y [m]";
  Real pz "payload z [m]";

  // === Sensor outputs ===
  Real gps_x "GPS x measurement [m]";
  Real gps_y "GPS y measurement [m]";
  Real gps_z "GPS z measurement [m]";
  Real imu_ax "IMU x acceleration [m/s^2]";
  Real imu_ay "IMU y acceleration [m/s^2]";
  Real imu_az "IMU z acceleration [m/s^2]";
  Real imu_pb "IMU roll rate [rad/s]";
  Real imu_qb "IMU pitch rate [rad/s]";
  Real imu_rb "IMU yaw rate [rad/s]";
  Real cable_alpha_x_meas "cable angle x measurement [rad]";
  Real cable_alpha_y_meas "cable angle y measurement [rad]";
  Real tension_meas "tension measurement [N]";

  // === Diagnostic variables ===
  Real track_error "primary tracking error [m]";
  Real swing_mag "cable swing magnitude [rad]";
  Real placement_err "payload placement error [m]";
  Real phase "mission phase indicator";
  Boolean thrust_ok "thrust bounds satisfied";
  Boolean tension_ok "tension bounds satisfied";
  Boolean no_ground_strike "no ground strike";

equation
  // ================================================================
  // Input-shaped reference trajectory (smooth cosine transitions)
  // ================================================================
  ss_lift = if time <= 0.5 then 0.0 elseif time >= 2.5 then 1.0
           else 0.5 * (1.0 - cos(pi_val * (time - 0.5) / 2.0));
  ss_trans = if time <= 3.0 then 0.0 elseif time >= 9.0 then 1.0
           else 0.5 * (1.0 - cos(pi_val * (time - 3.0) / 6.0));
  ss_lower = if time <= 10.0 then 0.0 elseif time >= 13.0 then 1.0
           else 0.5 * (1.0 - cos(pi_val * (time - 10.0) / 3.0));

  x_ref = x_target * ss_trans;
  y_ref = 0.0;
  z_ref = z_cruise * ss_lift - (z_cruise - z_lower) * ss_lower;

  // ================================================================
  // Gust disturbance (middle third of 14 s: [4.667, 9.333] s)
  // ================================================================
  gust_x = if (time >= 4.667 and time <= 9.333) then gust_force else 0.0;

  // ================================================================
  // Aerodynamic drag (quadratic)
  // ================================================================
  F_drag_x = -0.5 * rho_air * Cd_A * vx * abs(vx);
  F_drag_y = -0.5 * rho_air * Cd_A * vy * abs(vy);
  F_drag_z = -0.5 * rho_air * Cd_A * vz * abs(vz);

  // ================================================================
  // Cable tension and payload position
  // ================================================================
  tension = m_payload * (g * cos(alpha_x) * cos(alpha_y)
           + L_cable * (alpha_xd * alpha_xd + alpha_yd * alpha_yd));

  px = x + L_cable * sin(alpha_x);
  py = y + L_cable * sin(alpha_y);
  pz = z - L_cable * cos(alpha_x) * cos(alpha_y);

  // ================================================================
  // Controller: input-shaped position control with cable-swing damping
  // ================================================================
  ax_des = kp_pos * (x_ref - x) - kd_pos * vx - k_swing * alpha_xd_f;
  ay_des = kp_pos * (y_ref - y) - kd_pos * vy - k_swing * alpha_yd_f;
  az_des = kp_pos * (z_ref - z) - kd_pos * vz;

  // Desired attitude from desired acceleration (small-angle mapping)
  theta_des = atan(ax_des / max(az_des + g, 0.1));
  phi_des = atan(-ay_des / max(az_des + g, 0.1));

  // Commanded total thrust
  T_total_cmd = m_body * (az_des + g) / max(cos(phi_des) * cos(theta_des), eps);

  // Attitude PD controller
  Mx = kp_att * (phi_des - phi) - kd_att * pb;
  My = kp_att * (theta_des - theta_a) - kd_att * qb;
  Mz = kp_yaw * (0.0 - psi) - kd_yaw * rb;

  // ================================================================
  // Motor mixing (X-configuration quadrotor)
  // Rotor positions: (+L2,+L2), (-L2,+L2), (-L2,-L2), (+L2,-L2)
  // Yaw moments: R1 CCW(-), R2 CW(+), R3 CCW(-), R4 CW(+)
  // ================================================================
  T1_cmd = T_total_cmd / 4.0 + Mx / (2.0 * L2) + My / (2.0 * L2) - Mz / (4.0 * k_yaw);
  T2_cmd = T_total_cmd / 4.0 - Mx / (2.0 * L2) + My / (2.0 * L2) + Mz / (4.0 * k_yaw);
  T3_cmd = T_total_cmd / 4.0 - Mx / (2.0 * L2) - My / (2.0 * L2) - Mz / (4.0 * k_yaw);
  T4_cmd = T_total_cmd / 4.0 + Mx / (2.0 * L2) - My / (2.0 * L2) + Mz / (4.0 * k_yaw);

  // Thrust saturation [0, T_max]
  T1 = max(0.0, min(T_max, T1_cmd));
  T2 = max(0.0, min(T_max, T2_cmd));
  T3 = max(0.0, min(T_max, T3_cmd));
  T4 = max(0.0, min(T_max, T4_cmd));
  T_total = T1 + T2 + T3 + T4;

  // ================================================================
  // Body translational dynamics
  // Thrust along body Z, transformed by ZYX Euler angles
  // Includes: gravity, drag, gust, cable tension feedback
  // ================================================================
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (T_total * (cos(psi) * sin(theta_a) * cos(phi) + sin(psi) * sin(phi))
           + F_drag_x + gust_x + tension * sin(alpha_x)) / m_body;
  der(vy) = (T_total * (sin(psi) * sin(theta_a) * cos(phi) - cos(psi) * sin(phi))
           + F_drag_y + tension * sin(alpha_y)) / m_body;
  der(vz) = (T_total * cos(theta_a) * cos(phi) - m_body * g
           + F_drag_z - tension * cos(alpha_x) * cos(alpha_y)) / m_body;

  // ================================================================
  // Body rotational dynamics (rigid body Euler equations)
  // ================================================================
  der(phi) = pb;
  der(theta_a) = qb;
  der(psi) = rb;
  der(pb) = (Mx - (Izz - Iyy) * qb * rb) / Ixx;
  der(qb) = (My - (Ixx - Izz) * pb * rb) / Iyy;
  der(rb) = (Mz - (Iyy - Ixx) * pb * qb) / Izz;

  // ================================================================
  // Cable pendulum dynamics (moving-pivot pendulum)
  // ================================================================
  der(alpha_x) = alpha_xd;
  der(alpha_y) = alpha_yd;
  der(alpha_xd) = -(g / L_cable) * sin(alpha_x) - (der(vx) / L_cable) * cos(alpha_x);
  der(alpha_yd) = -(g / L_cable) * sin(alpha_y) - (der(vy) / L_cable) * cos(alpha_y);

  // Filtered cable angular rates (breaks algebraic loop in controller)
  der(alpha_xd_f) = (alpha_xd - alpha_xd_f) / tau_filt;
  der(alpha_yd_f) = (alpha_yd - alpha_yd_f) / tau_filt;

  // ================================================================
  // Sensors (direct measurement model)
  // ================================================================
  gps_x = x;
  gps_y = y;
  gps_z = z;
  imu_ax = der(vx);
  imu_ay = der(vy);
  imu_az = der(vz);
  imu_pb = pb;
  imu_qb = qb;
  imu_rb = rb;
  cable_alpha_x_meas = alpha_x;
  cable_alpha_y_meas = alpha_y;
  tension_meas = tension;

  // ================================================================
  // Diagnostics
  // ================================================================
  track_error = sqrt((x - x_ref) * (x - x_ref) + (y - y_ref) * (y - y_ref)
               + (z - z_ref) * (z - z_ref) + eps);
  swing_mag = sqrt(alpha_x * alpha_x + alpha_y * alpha_y + eps);
  placement_err = sqrt((px - x_target) * (px - x_target) + py * py + pz * pz + eps);

  thrust_ok = (T1 >= 0.0 and T1 <= T_max and T2 >= 0.0 and T2 <= T_max
               and T3 >= 0.0 and T3 <= T_max and T4 >= 0.0 and T4 <= T_max);
  tension_ok = (tension >= 0.0 and tension <= 100.0);
  no_ground_strike = (z >= 0.0 and pz >= 0.0);

  phase = if time < 2.5 then 1.0 elseif time < 10.0 then 2.0 else 3.0;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "QuadScoutDeliverD: 1.8 kg quadrotor with four rotors at 0.22 m arm
      length, each producing thrust along body Z and a signed yaw moment. Thrust limited to
      12 N per rotor. Suspended payload on cable with angle and tension measurements.

      Mission: lift to 3 m cruise altitude, translate 5 m horizontally, lower payload into
      0.8 m-radius target zone. 8 N lateral gust during middle third [4.667, 9.333] s.
      Input-shaped position control with cable-swing damping via filtered cable angular rate.

      Runs at 200 Hz (Interval=0.005) for 14 s. Synchronized state, command, and sensor
      traces retained as model variables.

      Assumed values not specified in requirement: payload mass 0.5 kg, cable length 0.8 m,
      body inertias Ixx=Iyy=0.015 kg.m^2, Izz=0.030 kg.m^2, yaw moment coefficient 0.06 N.m/N,
      drag area 0.015 m^2, cruise altitude 3 m, lowering altitude 0.5 m.

      Constraints: thrust in [0,12] N, tension non-negative, swing below 0.45 rad,
      target-zone placement within 0.8 m, no ground strike, tracking error below 0.3 m
      after 9.1 s, no NaN or infinite values.")
  );
end QuadScoutDeliverD;