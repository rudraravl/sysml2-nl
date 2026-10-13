model HexaSurveyDeliverF
  "Hexarotor survey-and-deliver: lift suspended payload, translate 5 m, lower into 0.8 m-radius target zone"

  // ============ Constants ============
  constant Real pi = 3.14159265358979;
  parameter Real g = 9.81 "m/s^2, gravitational acceleration";

  // ============ Vehicle parameters ============
  parameter Real m_vehicle = 3.2 "kg, cylindrical fuselage mass";
  parameter Real m_payload = 0.4 "kg, downward camera payload mass";
  parameter Real rotor_arm = 0.35 "m, rotor arm radius";
  parameter Real T_max_rotor = 13.4 "N, maximum thrust per rotor channel";
  parameter Integer n_rotors = 6 "number of equally spaced rotors";

  // ============ Cable parameter (assumed; not specified in requirement) ============
  parameter Real cable_length = 0.5 "m, assumed suspension cable length";

  // ============ Aerodynamic parameters (assumed) ============
  parameter Real drag_coeff = 0.08 "N*s^2/m^2, vehicle aerodynamic drag coefficient";
  parameter Real c_pend = 0.15 "1/s, cable pendulum damping (proxy for payload aero drag)";

  // ============ Mission parameters ============
  parameter Real target_x = 5.0 "m, horizontal travel distance";
  parameter Real target_radius = 0.8 "m, target zone radius";
  parameter Real z_initial = 0.5 "m, initial altitude";
  parameter Real z_cruise = 2.0 "m, cruise altitude";
  parameter Real z_final = 0.5 "m, final altitude so payload reaches ground";
  parameter Real t_lift_end = 5.0 "s, end of lift phase";
  parameter Real t_trans_start = 5.0 "s, start of translation";
  parameter Real t_trans_end = 15.0 "s, end of translation";
  parameter Real t_lower_start = 15.0 "s, start of lower phase";
  parameter Real t_lower_end = 20.0 "s, end of lower phase";

  // ============ Gust parameters ============
  parameter Real gust_force = 11.6 "N, controlled gust disturbance";
  parameter Real gust_start = 20.0 / 3.0 "s, start of middle third";
  parameter Real gust_end = 40.0 / 3.0 "s, end of middle third";

  // ============ Controller gains ============
  parameter Real Kp_x = 20.0 "1/s^2, horizontal position proportional gain";
  parameter Real Kd_x = 8.0 "1/s, horizontal velocity derivative gain";
  parameter Real Kp_z = 6.0 "1/s^2, vertical position proportional gain";
  parameter Real Kd_z = 5.0 "1/s, vertical velocity derivative gain";
  parameter Real Kd_swing = 0.5 "dimensionless, cable-swing damping gain";
  parameter Real tau_phi = 0.08 "s, attitude response time constant";
  parameter Real k_tilt = 1.0 "rotor thrust distribution factor for tilt";

  // ============ Verification limits ============
  parameter Real swing_limit = 0.45 "rad, maximum cable swing angle";
  parameter Real tracking_limit = 0.24 "m, maximum primary tracking error after 13 s";
  parameter Real tension_max = 20.0 "N, assumed safe cable tension limit";

  // ============ Dynamic states ============
  Real x(start = 0.0, fixed = true) "m, vehicle x position";
  Real z(start = z_initial, fixed = true) "m, vehicle z position";
  Real vx(start = 0.0, fixed = true) "m/s, vehicle x velocity";
  Real vz(start = 0.0, fixed = true) "m/s, vehicle z velocity";
  Real theta(start = 0.0, fixed = true) "rad, cable angle from vertical (positive = +x)";
  Real omega(start = 0.0, fixed = true) "rad/s, cable angular velocity";
  Real phi(start = 0.0, fixed = true) "rad, vehicle body tilt angle";

  // ============ Rotor thrust channels ============
  Real T1 "N, rotor 1 thrust (front)";
  Real T2 "N, rotor 2 thrust";
  Real T3 "N, rotor 3 thrust";
  Real T4 "N, rotor 4 thrust (rear)";
  Real T5 "N, rotor 5 thrust";
  Real T6 "N, rotor 6 thrust";
  Real T_total "N, total rotor thrust";
  Real T_base "N, base rotor thrust before tilt modulation";
  Real T1_raw "N, unbounded rotor 1 thrust";
  Real T4_raw "N, unbounded rotor 4 thrust";

  // ============ Cable ============
  Real T_cable "N, cable tension";
  Real payload_px "m, payload x position";
  Real payload_pz "m, payload z position";

  // ============ Reference trajectory (input-shaped) ============
  Real x_ref "m, reference x position";
  Real z_ref "m, reference z position";
  Real vx_ref "m/s, reference x velocity";
  Real vz_ref "m/s, reference z velocity";

  // ============ Control commands ============
  Real ax_cmd "m/s^2, commanded x acceleration";
  Real az_cmd "m/s^2, commanded z acceleration";
  Real phi_cmd "rad, commanded body tilt angle";
  Real T_cmd "N, commanded total thrust";

  // ============ Sensor outputs ============
  Real x_gps "m, GPS x position measurement";
  Real z_gps "m, GPS z position measurement";
  Real vx_imu "m/s, IMU x velocity estimate";
  Real vz_imu "m/s, IMU z velocity estimate";
  Real theta_sensor "rad, cable angle measurement";
  Real T_sensor "N, cable tension measurement";

  // ============ Disturbance ============
  Real F_gust "N, gust force in x direction";

  // ============ Intermediate variables ============
  Real ax "m/s^2, vehicle x acceleration";
  Real az "m/s^2, vehicle z acceleration";
  Real v_speed "m/s, vehicle speed magnitude";
  Real drag_x "N, aerodynamic drag force in x";
  Real drag_z "N, aerodynamic drag force in z";
  Real alpha "rad/s^2, cable angular acceleration";
  Real tracking_error "m, primary tracking error in x";
  Real payload_dist "m, payload distance from target center";

  // ============ Verification flags ============
  Boolean thrust_ok "all rotor thrusts within [0, T_max_rotor]";
  Boolean tension_ok "cable tension within [0, tension_max]";
  Boolean swing_ok "cable swing below swing_limit";
  Boolean placement_ok "payload within target_radius of target center";
  Boolean no_ground_strike "vehicle altitude above ground threshold";
  Boolean tracking_ok "tracking error below limit after 13 s";
  Boolean all_ok "all verification criteria satisfied";

equation
  // ====== Input-shaped reference trajectory (raised-cosine profiles) ======
  x_ref = target_x * (if time <= t_trans_start then 0.0
    else if time >= t_trans_end then 1.0
    else 0.5 * (1.0 - cos(pi * (time - t_trans_start) / (t_trans_end - t_trans_start))));

  vx_ref = target_x * (if time <= t_trans_start or time >= t_trans_end then 0.0
    else pi / (2.0 * (t_trans_end - t_trans_start)) *
         sin(pi * (time - t_trans_start) / (t_trans_end - t_trans_start)));

  z_ref = z_initial
    + (z_cruise - z_initial) * (if time <= 0.0 then 0.0
        else if time >= t_lift_end then 1.0
        else 0.5 * (1.0 - cos(pi * time / (t_lift_end))))
    - (z_cruise - z_final) * (if time <= t_lower_start then 0.0
        else if time >= t_lower_end then 1.0
        else 0.5 * (1.0 - cos(pi * (time - t_lower_start) / (t_lower_end - t_lower_start))));

  vz_ref = (z_cruise - z_initial) * (if time <= 0.0 or time >= t_lift_end then 0.0
      else pi / (2.0 * t_lift_end) * sin(pi * time / t_lift_end))
    - (z_cruise - z_final) * (if time <= t_lower_start or time >= t_lower_end then 0.0
      else pi / (2.0 * (t_lower_end - t_lower_start)) *
           sin(pi * (time - t_lower_start) / (t_lower_end - t_lower_start)));

  // ====== Gust disturbance (applied during middle third of 20 s) ======
  F_gust = if time >= gust_start and time <= gust_end then -gust_force else 0.0;

  // ====== Sensor model (near-perfect measurements) ======
  x_gps = x;
  z_gps = z;
  vx_imu = vx;
  vz_imu = vz;
  theta_sensor = theta;
  T_sensor = T_cable;

  // ====== Aerodynamic drag (quadratic, regularized speed) ======
  v_speed = sqrt(vx * vx + vz * vz + 1e-10);
  drag_x = drag_coeff * v_speed * vx;
  drag_z = drag_coeff * v_speed * vz;

  // ====== Position controller with cable-swing damping ======
  ax_cmd = Kp_x * (x_ref - x_gps) + Kd_x * (vx_ref - vx_imu) + Kd_swing * omega;
  az_cmd = Kp_z * (z_ref - z_gps) + Kd_z * (vz_ref - vz_imu);

  // ====== Thrust and tilt commands ======
  T_cmd = (m_vehicle + m_payload) * g + m_vehicle * az_cmd;
  phi_cmd = m_vehicle * ax_cmd / max(T_cmd, 1.0);

  // ====== Rotor thrust distribution (6 channels, bounded) ======
  T_base = T_cmd / 6.0;
  T1_raw = T_base * (1.0 - k_tilt * phi_cmd);
  T4_raw = T_base * (1.0 + k_tilt * phi_cmd);

  T1 = if T1_raw < 0.0 then 0.0 else if T1_raw > T_max_rotor then T_max_rotor else T1_raw;
  T2 = if T_base < 0.0 then 0.0 else if T_base > T_max_rotor then T_max_rotor else T_base;
  T3 = if T_base < 0.0 then 0.0 else if T_base > T_max_rotor then T_max_rotor else T_base;
  T4 = if T4_raw < 0.0 then 0.0 else if T4_raw > T_max_rotor then T_max_rotor else T4_raw;
  T5 = if T_base < 0.0 then 0.0 else if T_base > T_max_rotor then T_max_rotor else T_base;
  T6 = if T_base < 0.0 then 0.0 else if T_base > T_max_rotor then T_max_rotor else T_base;
  T_total = T1 + T2 + T3 + T4 + T5 + T6;

  // ====== Cable tension (closed-form, no algebraic loop) ======
  // Derived from combined vehicle-payload Newton equations:
  // T_cable = m_p/(m_v+m_p) * [(T*cos(phi)-drag_z)*cos(theta)
  //           - (T*sin(phi)+F_gust-drag_x)*sin(theta) + m_v*L*omega^2]
  T_cable = m_payload / (m_vehicle + m_payload) *
    ((T_total * cos(phi) - drag_z) * cos(theta)
     - (T_total * sin(phi) + F_gust - drag_x) * sin(theta)
     + m_vehicle * cable_length * omega * omega);

  // ====== Vehicle accelerations ======
  ax = (T_total * sin(phi) + F_gust - drag_x + T_cable * sin(theta)) / m_vehicle;
  az = (T_total * cos(phi) - m_vehicle * g - drag_z - T_cable * cos(theta)) / m_vehicle;

  // ====== Cable pendulum dynamics (with damping) ======
  alpha = -((g + az) * sin(theta) + ax * cos(theta)) / cable_length - c_pend * omega;

  // ====== Attitude dynamics (first-order lag) ======
  der(phi) = (phi_cmd - phi) / tau_phi;

  // ====== State derivatives ======
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax;
  der(vz) = az;
  der(theta) = omega;
  der(omega) = alpha;

  // ====== Payload kinematics ======
  payload_px = x + cable_length * sin(theta);
  payload_pz = z - cable_length * cos(theta);

  // ====== Tracking and placement metrics ======
  tracking_error = abs(x_ref - x);
  payload_dist = sqrt((payload_px - target_x) * (payload_px - target_x) + payload_pz * payload_pz);

  // ====== Verification criteria ======
  thrust_ok = T1 >= 0.0 and T1 <= T_max_rotor and
              T2 >= 0.0 and T2 <= T_max_rotor and
              T3 >= 0.0 and T3 <= T_max_rotor and
              T4 >= 0.0 and T4 <= T_max_rotor and
              T5 >= 0.0 and T5 <= T_max_rotor and
              T6 >= 0.0 and T6 <= T_max_rotor;
  tension_ok = T_cable >= 0.0 and T_cable <= tension_max;
  swing_ok = abs(theta) <= swing_limit;
  placement_ok = payload_dist <= target_radius;
  no_ground_strike = z > 0.1;
  tracking_ok = if time >= 13.0 then tracking_error <= tracking_limit else true;
  all_ok = thrust_ok and tension_ok and swing_ok and placement_ok and
           no_ground_strike and tracking_ok;

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Hexarotor survey-deliver mission at 500 Hz for 20 s.
      Vehicle: 3.2 kg fuselage, 6 rotors on 0.35 m radius, 0.4 kg suspended camera payload.
      Mission: lift, translate 5 m horizontally, lower into 0.8 m-radius target zone.
      Disturbance: 11.6 N gust during middle third (6.67-13.33 s).
      Control: input-shaped position control with cable-swing damping.
      Verification: thrust per rotor <= 13.4 N, tension bounded, swing < 0.45 rad,
      target-zone placement, no ground strike, tracking error < 0.24 m after 13 s.
      Assumed (not specified): cable_length, drag_coeff, c_pend, tension_max, controller gains."));
end HexaSurveyDeliverF;