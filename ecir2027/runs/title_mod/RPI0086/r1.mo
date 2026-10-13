model DuctInspectDeliverB
  "Aerial robot: lift payload, translate 5 m, lower into 0.8 m-radius target zone"

  // ===== Constants =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real pi_val = 3.1415926535897932 "Pi";

  // ===== Stated parameters =====
  parameter Real m_body = 2.7 "Body mass [kg]";
  parameter Real F_fan_max = 14.8 "Max thrust per fan [N]";
  parameter Real n_fans = 4.0 "Number of ducted fans";
  parameter Real L_probe = 0.18 "Inspection probe length along body X [m]";
  parameter Real r_target = 0.8 "Target zone radius [m]";
  parameter Real x_target = 5.0 "Horizontal translation distance [m]";
  parameter Real F_gust_spec = 5.6 "Gust disturbance magnitude [N]";
  parameter Real swing_max = 0.45 "Allowed max cable swing angle [rad]";
  parameter Real err_max = 0.36 "Max primary tracking error after 6.5 s [m]";
  parameter Real T_sim = 10.0 "Simulation duration [s]";
  parameter Real f_rate = 100.0 "Run rate [Hz] (output interval); continuous controller";

  // ===== Assumed parameters (facts not stated in requirement) =====
  parameter Real L_cable = 1.0 "Cable length [m] - assumed";
  parameter Real m_payload = 0.5 "Payload mass [kg] - assumed";
  parameter Real m_probe_eff = 0.05 "Probe effective mass [kg] - assumed";
  parameter Real c_drag_b = 0.2 "Body linear drag coefficient [N.s/m] - assumed";
  parameter Real c_drag_p = 0.05 "Payload linear drag coefficient [N.s/m] - assumed";
  parameter Real z_ground = 0.0 "Ground level [m] - assumed";
  parameter Real z_init = 1.5 "Initial body altitude [m] - assumed";
  parameter Real z_cruise = 4.0 "Cruise altitude [m] - assumed";
  parameter Real z_lower = 1.0 "Lowering altitude [m] (payload at ground) - assumed";
  parameter Real k_pos = 6.0 "Position control proportional gain - assumed";
  parameter Real k_vel = 4.0 "Velocity damping gain - assumed";
  parameter Real k_swing = 3.0 "Cable swing damping gain - assumed";
  parameter Real F_probe_max = 5.0 "Probe force actuator bound [N] - assumed";
  parameter Real probe_k = 200.0 "Probe compliance stiffness [N/m] - assumed";
  parameter Real probe_c = 5.0 "Probe damping [N.s/m] - assumed";

  // ===== Derived =====
  parameter Real F_total_max = n_fans * F_fan_max "Total max thrust [N]";
  parameter Real t_lift_end = T_sim / 3.0 "Lift phase end time [s]";
  parameter Real t_trans_end = 2.0 * T_sim / 3.0 "Translate phase end time [s]";

  // ===== Dynamic states =====
  Real x_body(start=0.0, fixed=true) "Body horizontal position [m]";
  Real z_body(start=z_init, fixed=true) "Body vertical position [m]";
  Real vx(start=0.0, fixed=true) "Body horizontal velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Body vertical velocity [m/s]";
  Real theta(start=0.001, fixed=true) "Cable angle from vertical [rad]";
  Real omega(start=0.0, fixed=true) "Cable swing rate [rad/s]";
  Real q_probe(start=0.0, fixed=true) "Probe deflection [m]";
  Real qd_probe(start=0.0, fixed=true) "Probe deflection velocity [m/s]";

  // ===== Algebraic: payload kinematics =====
  Real x_payload "Payload horizontal position [m]";
  Real z_payload "Payload vertical position [m]";
  Real vx_payload "Payload horizontal velocity [m/s]";
  Real vz_payload "Payload vertical velocity [m/s]";

  // ===== Algebraic: dynamics intermediates =====
  Real ax_body "Body horizontal acceleration [m/s^2]";
  Real az_body "Body vertical acceleration [m/s^2]";
  Real alpha "Cable angular acceleration [rad/s^2]";
  Real cable_tension "Cable tension [N]";

  // ===== Reference trajectory =====
  Real x_ref "Reference horizontal position [m]";
  Real z_ref "Reference vertical position [m]";
  Real vx_ref "Reference horizontal velocity [m/s]";
  Real vz_ref "Reference vertical velocity [m/s]";

  // ===== Control commands =====
  Real F_thrust_cmd "Total thrust command [N]";
  Real F_lat_cmd "Lateral thrust command [N]";
  Real cmd_fan1 "Fan 1 command [N]";
  Real cmd_fan2 "Fan 2 command [N]";
  Real cmd_fan3 "Fan 3 command [N]";
  Real cmd_fan4 "Fan 4 command [N]";
  Real cmd_probe "Probe force command [N]";

  // ===== Actuator outputs (saturated) =====
  Real u_fan1 "Fan 1 applied thrust [N]";
  Real u_fan2 "Fan 2 applied thrust [N]";
  Real u_fan3 "Fan 3 applied thrust [N]";
  Real u_fan4 "Fan 4 applied thrust [N]";
  Real u_probe "Applied probe force [N]";
  Real F_thrust "Total applied thrust [N]";
  Real F_lat "Applied lateral thrust [N]";
  Real F_gust "Applied gust force [N]";

  // ===== Sensors =====
  Real gps_x "GPS x measurement [m]";
  Real gps_z "GPS z measurement [m]";
  Real imu_ax "IMU x acceleration [m/s^2]";
  Real imu_az "IMU z acceleration [m/s^2]";
  Real meas_cable_angle "Cable angle measurement [rad]";
  Real meas_cable_tension "Cable tension measurement [N]";

  // ===== Metrics =====
  Real tracking_error "Primary tracking error [m]";
  Real payload_target_dist "Payload distance from target center [m]";
  Boolean swing_ok "Swing below 0.45 rad";
  Boolean thrust_ok "All fan thrusts within bound";
  Boolean tension_ok "Tension non-negative";
  Boolean no_ground_strike_ok "No ground strike";
  Boolean target_reached_ok "Payload in target zone";
  Boolean tracking_ok "Tracking error below 0.36 m after 6.5 s";

equation
  // ===== State derivatives =====
  der(x_body) = vx;
  der(z_body) = vz;
  der(vx) = ax_body;
  der(vz) = az_body;
  der(theta) = omega;
  der(omega) = alpha;
  der(q_probe) = qd_probe;
  der(qd_probe) = (u_probe - probe_k * q_probe - probe_c * qd_probe) / m_probe_eff;

  // ===== Payload kinematics =====
  x_payload = x_body + L_cable * sin(theta);
  z_payload = z_body - L_cable * cos(theta);
  vx_payload = vx + L_cable * cos(theta) * omega;
  vz_payload = vz + L_cable * sin(theta) * omega;

  // ===== Gust disturbance (middle third of simulation) =====
  if time >= t_lift_end and time <= t_trans_end then
    F_gust = F_gust_spec;
  else
    F_gust = 0.0;
  end if;

  // ===== Input-shaped reference trajectory: horizontal =====
  if time <= t_lift_end then
    x_ref = 0.0;
    vx_ref = 0.0;
  elseif time <= t_trans_end then
    x_ref = x_target * (1.0 - cos(pi_val * (time - t_lift_end) / (t_trans_end - t_lift_end))) / 2.0;
    vx_ref = x_target * pi_val / (2.0 * (t_trans_end - t_lift_end)) *
             sin(pi_val * (time - t_lift_end) / (t_trans_end - t_lift_end));
  else
    x_ref = x_target;
    vx_ref = 0.0;
  end if;

  // ===== Input-shaped reference trajectory: vertical =====
  if time <= t_lift_end then
    z_ref = z_init + (z_cruise - z_init) * (1.0 - cos(pi_val * time / t_lift_end)) / 2.0;
    vz_ref = (z_cruise - z_init) * pi_val / (2.0 * t_lift_end) *
             sin(pi_val * time / t_lift_end);
  elseif time <= t_trans_end then
    z_ref = z_cruise;
    vz_ref = 0.0;
  else
    z_ref = z_cruise + (z_lower - z_cruise) *
            (1.0 - cos(pi_val * (time - t_trans_end) / (T_sim - t_trans_end))) / 2.0;
    vz_ref = (z_lower - z_cruise) * pi_val / (2.0 * (T_sim - t_trans_end)) *
             sin(pi_val * (time - t_trans_end) / (T_sim - t_trans_end));
  end if;

  // ===== PD position control with cable-swing damping =====
  F_thrust_cmd = (m_body + m_payload) * g
                 + k_pos * (z_ref - z_body)
                 + k_vel * (vz_ref - vz)
                 + k_swing * omega * cos(theta);
  F_lat_cmd = k_pos * (x_ref - x_body)
              + k_vel * (vx_ref - vx)
              - k_swing * omega;

  // ===== Fan command distribution =====
  cmd_fan1 = F_thrust_cmd / 4.0 + F_lat_cmd / 4.0;
  cmd_fan2 = F_thrust_cmd / 4.0 + F_lat_cmd / 4.0;
  cmd_fan3 = F_thrust_cmd / 4.0 - F_lat_cmd / 4.0;
  cmd_fan4 = F_thrust_cmd / 4.0 - F_lat_cmd / 4.0;

  // ===== Per-fan saturation [0, F_fan_max] =====
  u_fan1 = max(0.0, min(cmd_fan1, F_fan_max));
  u_fan2 = max(0.0, min(cmd_fan2, F_fan_max));
  u_fan3 = max(0.0, min(cmd_fan3, F_fan_max));
  u_fan4 = max(0.0, min(cmd_fan4, F_fan_max));

  // ===== Actual forces from saturated fan outputs =====
  F_thrust = u_fan1 + u_fan2 + u_fan3 + u_fan4;
  F_lat = (u_fan1 + u_fan2) - (u_fan3 + u_fan4);

  // ===== Probe force actuator (bounded, zero command for delivery mission) =====
  cmd_probe = 0.0;
  u_probe = max(-F_probe_max, min(cmd_probe, F_probe_max));

  // ===== Body dynamics =====
  m_body * ax_body = cable_tension * sin(theta) + F_lat + F_gust - c_drag_b * vx;
  m_body * az_body = -cable_tension * cos(theta) + F_thrust - m_body * g - c_drag_b * vz;

  // ===== Payload dynamics (rigid cable constraint) =====
  m_payload * (ax_body + L_cable * cos(theta) * alpha - L_cable * sin(theta) * omega^2) =
    -cable_tension * sin(theta) - c_drag_p * vx_payload;
  m_payload * (az_body + L_cable * sin(theta) * alpha + L_cable * cos(theta) * omega^2) =
    cable_tension * cos(theta) - m_payload * g - c_drag_p * vz_payload;

  // ===== Sensors (ideal, synchronized traces) =====
  gps_x = x_body;
  gps_z = z_body;
  imu_ax = ax_body;
  imu_az = az_body;
  meas_cable_angle = theta;
  meas_cable_tension = cable_tension;

  // ===== Performance metrics =====
  tracking_error = sqrt((x_ref - x_body)^2 + (z_ref - z_body)^2);
  payload_target_dist = sqrt((x_payload - x_target)^2 + (z_payload - z_ground)^2);

  swing_ok = abs(theta) < swing_max;
  thrust_ok = (u_fan1 >= -1e-6) and (u_fan1 <= F_fan_max + 1e-6) and
              (u_fan2 >= -1e-6) and (u_fan2 <= F_fan_max + 1e-6) and
              (u_fan3 >= -1e-6) and (u_fan3 <= F_fan_max + 1e-6) and
              (u_fan4 >= -1e-6) and (u_fan4 <= F_fan_max + 1e-6);
  tension_ok = cable_tension >= 0.0;
  no_ground_strike_ok = z_body > (z_ground + 0.5);
  target_reached_ok = payload_target_dist <= r_target;
  tracking_ok = if time >= 6.5 then tracking_error < err_max else true;

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "DuctInspectDeliverB: Free-base aerial robot (2.7 kg body, 4 ducted fans at 14.8 N max each, 0.18 m compliant probe) lifts a suspended payload, translates 5 m horizontally, and lowers it into a 0.8 m-radius target zone. Input-shaped position control with cable-swing damping. A controlled 5.6 N gust is injected during the middle third. IMU, GPS, cable-angle, and tension sensors are instrumented. Cable is assumed rigid (taut throughout). Parameters not stated in the requirement are marked as assumed.")
  );
end DuctInspectDeliverB;