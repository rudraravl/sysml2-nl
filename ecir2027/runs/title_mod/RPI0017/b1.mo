model QuadScoutDeliverE
  function smoothstep "Smooth (cosine) transition from 0 to 1 over [a,b]"
    input Real t;
    input Real a;
    input Real b;
    output Real y;
  algorithm
    if b <= a then
      y := 0.0;
    elseif t <= a then
      y := 0.0;
    elseif t >= b then
      y := 1.0;
    else
      y := 0.5 * (1.0 - Modelica.Math.cos(Modelica.Constants.pi * (t - a) / (b - a)));
    end if;
  end smoothstep;

  // Physical constants
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";

  // Plant parameters specified by requirement
  parameter Real m_quad = 1.8 "fuselage (box) mass [kg]";
  parameter Real arm = 0.22 "rotor arm length [m]";
  parameter Real Tmax = 13.2 "max thrust per rotor [N]";

  // Assumed plant parameters (not specified; required for dynamics)
  parameter Real m_load = 0.5 "payload mass [kg] - assumed";
  parameter Real L_cable = 1.0 "cable length [m] - assumed";
  parameter Real Ixx = 0.04 "roll inertia [kg.m2] - assumed";
  parameter Real Iyy = 0.04 "pitch inertia [kg.m2] - assumed";
  parameter Real Izz = 0.07 "yaw inertia [kg.m2] - assumed";
  parameter Real k_yaw = 0.05 "signed yaw-moment coefficient [N.m/N] - assumed";
  parameter Real Cd_lin = 0.2 "linear aerodynamic drag coefficient [N.s/m] - assumed";

  // Scenario
  parameter Real target_x = 5.0 "horizontal translation distance [m]";
  parameter Real target_r = 0.8 "target zone radius [m]";
  parameter Real z_init = 1.1 "initial quad altitude [m]";
  parameter Real z_hover = 3.0 "cruise altitude [m] - assumed";
  parameter Real z_final = 1.05 "final quad altitude for placement [m] - assumed";
  parameter Real t_gust_a = 16.0/3.0 "gust ramp-up start [s]";
  parameter Real t_gust_b = 32.0/3.0 "gust ramp-down end [s]";
  parameter Real F_gust = 9.6 "gust force magnitude [N]";

  // Controller gains (assumed)
  parameter Real Kp_pos = 20.0 "position proportional gain [1/s2]";
  parameter Real Kd_pos = 8.0 "position derivative gain [1/s]";
  parameter Real Kp_att = 6.0 "attitude proportional gain [1/s2]";
  parameter Real Kd_att = 1.3 "attitude derivative gain [1/s]";
  parameter Real k_swing = 0.3 "cable swing proportional feedback [dimensionless]";
  parameter Real d_swing = 1.0 "cable swing derivative feedback [s]";

  // Quadrotor translational state
  Real x(start=0.0, fixed=true) "quad x position [m]";
  Real y(start=0.0, fixed=true) "quad y position [m]";
  Real z(start=z_init, fixed=true) "quad z position [m]";
  Real vx(start=0.0, fixed=true) "quad x velocity [m/s]";
  Real vy(start=0.0, fixed=true) "quad y velocity [m/s]";
  Real vz(start=0.0, fixed=true) "quad z velocity [m/s]";

  // Quadrotor attitude state
  Real phi(start=0.0, fixed=true) "roll [rad]";
  Real theta(start=0.0, fixed=true) "pitch [rad]";
  Real psi(start=0.0, fixed=true) "yaw [rad]";
  Real p(start=0.0, fixed=true) "roll rate [rad/s]";
  Real q(start=0.0, fixed=true) "pitch rate [rad/s]";
  Real r(start=0.0, fixed=true) "yaw rate [rad/s]";

  // Cable / payload state
  Real cx(start=0.0, fixed=true) "cable angle from vertical, x-direction [rad]";
  Real cy(start=0.0, fixed=true) "cable angle from vertical, y-direction [rad]";
  Real dcx(start=0.0, fixed=true) "cable angle rate, x [rad/s]";
  Real dcy(start=0.0, fixed=true) "cable angle rate, y [rad/s]";
  Real px "payload x position [m]";
  Real py "payload y position [m]";
  Real pz "payload z position [m]";

  // Rotor thrusts and body moments (independently commanded)
  Real T1 "rotor 1 (front) thrust [N]";
  Real T2 "rotor 2 (right) thrust [N]";
  Real T3 "rotor 3 (back) thrust [N]";
  Real T4 "rotor 4 (left) thrust [N]";
  Real T_total_thrust "total thrust [N]";
  Real T1_raw "unclamped rotor 1 thrust [N]";
  Real T2_raw "unclamped rotor 2 thrust [N]";
  Real T3_raw "unclamped rotor 3 thrust [N]";
  Real T4_raw "unclamped rotor 4 thrust [N]";
  Real tau_phi_a "actual roll moment [N.m]";
  Real tau_theta_a "actual pitch moment [N.m]";
  Real tau_psi_a "actual yaw moment [N.m]";
  Real tau_phi_c "commanded roll moment [N.m]";
  Real tau_theta_c "commanded pitch moment [N.m]";
  Real tau_psi_c "commanded yaw moment [N.m]";
  Real tension "cable tension [N]";

  // Sensors (IMU, GPS, cable-angle, tension)
  Real gps_x "GPS x [m]";
  Real gps_y "GPS y [m]";
  Real gps_z "GPS z [m]";
  Real imu_phi "IMU roll [rad]";
  Real imu_theta "IMU pitch [rad]";
  Real imu_psi "IMU yaw [rad]";
  Real sense_cx "cable-angle sensor, x [rad]";
  Real sense_cy "cable-angle sensor, y [rad]";
  Real sense_tension "tension sensor [N]";

  // Reference (input-shaped) and command signals
  Real ref_x "reference x [m]";
  Real ref_y "reference y [m]";
  Real ref_z "reference z [m]";
  Real v_ref_x "reference velocity x [m/s]";
  Real v_ref_y "reference velocity y [m/s]";
  Real v_ref_z "reference velocity z [m/s]";
  Real a_des_x "desired world x-acceleration [m/s2]";
  Real a_des_y "desired world y-acceleration [m/s2]";
  Real a_des_z "desired world z-acceleration [m/s2]";
  Real T_cmd "commanded total thrust [N]";
  Real T_safe "saturated-away-from-zero commanded thrust [N]";
  Real phi_des "commanded roll [rad]";
  Real theta_des "commanded pitch [rad]";
  Real e_x "position tracking error x [m]";
  Real e_y "position tracking error y [m]";
  Real e_z "position tracking error z [m]";

  // Plant-internal auxiliary
  Real thrust_world_x "thrust world x-component [N]";
  Real thrust_world_y "thrust world y-component [N]";
  Real thrust_world_z "thrust world z-component [N]";
  Real drag_x "aerodynamic drag x [N]";
  Real drag_y "aerodynamic drag y [N]";
  Real drag_z "aerodynamic drag z [N]";
  Real gust_force "applied lateral gust force [N]";
  Real s_lift "smoothstep for lift phase";
  Real s_trans "smoothstep for translation phase";
  Real s_lower "smoothstep for lower phase";
  Real s_gust_on "smoothstep for gust onset";
  Real s_gust_off "smoothstep for gust offset";

  // Acceptance metrics and flags (fail-closed)
  Real track_err "primary tracking error [m]";
  Real placement_err "payload placement error from target center [m]";
  Real max_swing "cable swing magnitude [rad]";
  Boolean thrust_ok;
  Boolean tension_ok;
  Boolean swing_ok;
  Boolean placement_ok;
  Boolean track_ok;
  Boolean ground_strike;
  Boolean no_nan;
  Boolean acceptance;

equation
  // Input-shaped reference trajectory (smoothstep transitions)
  s_lift = smoothstep(time, 0.0, 3.0);
  s_trans = smoothstep(time, 3.0, 12.0);
  s_lower = smoothstep(time, 12.0, 16.0);
  ref_x = target_x * s_trans;
  ref_y = 0.0;
  ref_z = z_init + (z_hover - z_init) * s_lift + (z_final - z_hover) * s_lower;

  // Reference velocity feedforward (analytic derivative of smoothstep)
  v_ref_x = if time > 3.0 and time < 12.0 then
              target_x * Modelica.Constants.pi / 18.0 * Modelica.Math.sin(Modelica.Constants.pi * (time - 3.0) / 9.0)
            else 0.0;
  v_ref_y = 0.0;
  v_ref_z = if time > 0.0 and time < 3.0 then
              (z_hover - z_init) * Modelica.Constants.pi / 6.0 * Modelica.Math.sin(Modelica.Constants.pi * time / 3.0)
            elseif time > 12.0 and time < 16.0 then
              (z_final - z_hover) * Modelica.Constants.pi / 8.0 * Modelica.Math.sin(Modelica.Constants.pi * (time - 12.0) / 4.0)
            else 0.0;

  // Controlled (shaped) lateral gust during the middle third of the run
  s_gust_on = smoothstep(time, t_gust_a, t_gust_a + 1.5);
  s_gust_off = smoothstep(time, t_gust_b - 1.5, t_gust_b);
  gust_force = F_gust * s_gust_on * (1.0 - s_gust_off);

  // Position tracking errors
  e_x = ref_x - x;
  e_y = ref_y - y;
  e_z = ref_z - z;

  // PD position control with velocity feedforward and cable-swing damping
  a_des_x = Kp_pos * e_x - Kd_pos * (vx - v_ref_x) + (k_swing * cx + d_swing * dcx) * g;
  a_des_y = Kp_pos * e_y - Kd_pos * (vy - v_ref_y) + (k_swing * cy + d_swing * dcy) * g;
  a_des_z = Kp_pos * e_z - Kd_pos * (vz - v_ref_z);

  // Total thrust command (weight + desired vertical accel)
  T_cmd = (m_quad + m_load) * (g + a_des_z);
  T_safe = if T_cmd > 1.0 then T_cmd else 1.0;

  // Desired attitude from desired horizontal acceleration (small-angle)
  theta_des = (m_quad + m_load) * a_des_x / T_safe;
  phi_des = -(m_quad + m_load) * a_des_y / T_safe;

  // Attitude PD (yaw regulated to zero)
  tau_phi_c = Kp_att * (phi_des - phi) - Kd_att * p;
  tau_theta_c = Kp_att * (theta_des - theta) - Kd_att * q;
  tau_psi_c = -Kp_att * psi - Kd_att * r;

  // Rotor thrust allocation (4 independent commands)
  T1_raw = T_cmd/4.0 - tau_theta_c/(2.0*arm) - tau_psi_c/(4.0*k_yaw);
  T2_raw = T_cmd/4.0 - tau_phi_c/(2.0*arm)  + tau_psi_c/(4.0*k_yaw);
  T3_raw = T_cmd/4.0 + tau_theta_c/(2.0*arm) - tau_psi_c/(4.0*k_yaw);
  T4_raw = T_cmd/4.0 + tau_phi_c/(2.0*arm)  + tau_psi_c/(4.0*k_yaw);

  // Saturate each rotor to [0, Tmax]
  T1 = max(min(T1_raw, Tmax), 0.0);
  T2 = max(min(T2_raw, Tmax), 0.0);
  T3 = max(min(T3_raw, Tmax), 0.0);
  T4 = max(min(T4_raw, Tmax), 0.0);

  T_total_thrust = T1 + T2 + T3 + T4;

  // Actual body moments produced by the four (saturated) thrusts
  tau_phi_a = arm * (T4 - T2);
  tau_theta_a = arm * (T3 - T1);
  tau_psi_a = k_yaw * (-T1 + T2 - T3 + T4);

  // Thrust direction in world frame (small-angle approximation)
  thrust_world_x = T_total_thrust * theta;
  thrust_world_y = -T_total_thrust * phi;
  thrust_world_z = T_total_thrust * Modelica.Math.cos(phi) * Modelica.Math.cos(theta);

  // Aerodynamic drag (linear model)
  drag_x = -Cd_lin * vx;
  drag_y = -Cd_lin * vy;
  drag_z = -Cd_lin * vz;

  // Cable tension in closed form (eliminates algebraic loop with vz derivative)
  tension = max(m_load * (thrust_world_z + drag_z + m_quad * L_cable * (dcx*dcx + dcy*dcy)) / (m_quad + m_load), 0.0);

  // Quadrotor translational dynamics (gravity, drag, thrust, gust, cable tension)
  m_quad * der(vx) = thrust_world_x + drag_x + tension * cx;
  m_quad * der(vy) = thrust_world_y + drag_y + gust_force + tension * cy;
  m_quad * der(vz) = thrust_world_z - m_quad * g + drag_z - tension;
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  // Quadrotor attitude dynamics
  der(phi) = p;
  der(theta) = q;
  der(psi) = r;
  Ixx * der(p) = tau_phi_a;
  Iyy * der(q) = tau_theta_a;
  Izz * der(r) = tau_psi_a;

  // Cable pendulum dynamics (pivot acceleration substituted for explicitness)
  L_cable * der(dcx) = -g * cx - (thrust_world_x + drag_x + tension * cx) / m_quad;
  L_cable * der(dcy) = -g * cy - (thrust_world_y + drag_y + gust_force + tension * cy) / m_quad;
  der(cx) = dcx;
  der(cy) = dcy;

  // Payload kinematics (small-angle)
  px = x + L_cable * cx;
  py = y + L_cable * cy;
  pz = z - L_cable * (1.0 - 0.5 * (cx*cx + cy*cy));

  // Sensors
  gps_x = x;
  gps_y = y;
  gps_z = z;
  imu_phi = phi;
  imu_theta = theta;
  imu_psi = psi;
  sense_cx = cx;
  sense_cy = cy;
  sense_tension = tension;

  // Acceptance metrics
  track_err = sqrt(e_x*e_x + e_y*e_y + e_z*e_z);
  placement_err = sqrt((px - target_x)*(px - target_x) + py*py);
  max_swing = sqrt(cx*cx + cy*cy);

  thrust_ok = T1 >= -1e-9 and T1 <= Tmax + 1e-6 and
              T2 >= -1e-9 and T2 <= Tmax + 1e-6 and
              T3 >= -1e-9 and T3 <= Tmax + 1e-6 and
              T4 >= -1e-9 and T4 <= Tmax + 1e-6;
  tension_ok = tension >= 0.0 and tension < 100.0;
  swing_ok = max_swing < 0.45;
  placement_ok = placement_err < target_r and pz < 0.3;
  track_ok = if time > 10.4 then track_err < 0.27 else true;
  ground_strike = pz < 0.0 or z < 0.0;
  no_nan = abs(x) < 1e6 and abs(y) < 1e6 and abs(z) < 1e6 and
           abs(vx) < 1e6 and abs(vy) < 1e6 and abs(vz) < 1e6 and
           abs(phi) < 1e6 and abs(theta) < 1e6 and abs(psi) < 1e6 and
           abs(cx) < 1e6 and abs(cy) < 1e6 and abs(tension) < 1e6 and
           abs(T1) < 1e6 and abs(T2) < 1e6 and abs(T3) < 1e6 and abs(T4) < 1e6 and
           abs(track_err) < 1e6 and abs(placement_err) < 1e6;
  acceptance = thrust_ok and tension_ok and swing_ok and placement_ok and track_ok and (not ground_strike) and no_nan;

  // Fail-closed: halt at end of simulation if any acceptance criterion is violated
  when terminal() then
    assert(acceptance, "QuadScoutDeliverE: acceptance criteria failed (fail-closed)");
  end when;

  annotation(experiment(StartTime=0.0, StopTime=16.0, Interval=0.004, Tolerance=1e-6));
end QuadScoutDeliverE;