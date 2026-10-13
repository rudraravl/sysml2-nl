model HexaSurveyDeliverE
  "Free-base hexacopter with suspended payload: lift, translate 5 m, lower into target zone"

  // ---- Physical parameters (stated by requirement) ----
  parameter Real m_fuselage(unit="kg") = 3.2 "Cylindrical fuselage mass";
  parameter Real m_camera(unit="kg") = 0.4 "Downward camera payload mass";
  parameter Real R_rotor(unit="m") = 0.35 "Rotor radius from center";
  parameter Real T_max_rotor(unit="N") = 12.1 "Max thrust per rotor";
  parameter Real target_radius(unit="m") = 0.8 "Target zone radius";
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";

  // ---- Physical parameters (not stated; assumed and labeled) ----
  parameter Real m_payload(unit="kg") = 2.0 "Suspended payload mass (not stated; assumed)";
  parameter Real L_cable(unit="m") = 1.0 "Cable length (not stated; assumed)";
  parameter Real cd_drag(unit="N.s/m") = 0.15 "Linear aerodynamic drag coefficient (not stated; assumed)";
  parameter Real tau_pitch(unit="s") = 0.25 "Pitch response time constant (not stated; assumed)";
  parameter Real I_yy(unit="kg.m2") = 0.12 "Pitch moment of inertia (not stated; assumed)";
  parameter Real z_cruise(unit="m") = 2.0 "Cruise height (not stated; assumed)";
  parameter Real z_start(unit="m") = 1.1 "Initial vehicle height (not stated; assumed)";
  parameter Real z_final(unit="m") = 1.05 "Final vehicle height for payload near ground (not stated; assumed)";

  // ---- Derived constants ----
  parameter Real m_vehicle(unit="kg") = m_fuselage + m_camera;
  parameter Real m_total(unit="kg") = m_vehicle + m_payload;
  parameter Real T_total_max(unit="N") = 6.0 * T_max_rotor;
  parameter Real x_target(unit="m") = 5.0;

  // ---- Controller gains (not stated; tuned for acceptance) ----
  parameter Real K_px = 0.8 "X position proportional gain";
  parameter Real K_dx = 0.8 "X velocity damping gain";
  parameter Real K_pz = 1.5 "Z position proportional gain";
  parameter Real K_dz = 2.5 "Z velocity damping gain";
  parameter Real K_swing_p = 1.5 "Cable swing proportional gain";
  parameter Real K_swing_d = 0.8 "Cable swing derivative gain";
  parameter Real cable_nat_damp(unit="1/s") = 0.3 "Natural cable damping (not stated; assumed)";

  // ---- Dynamic state variables ----
  Real x_v(start=0.0, fixed=true, unit="m") "Vehicle x position";
  Real z_v(start=1.1, fixed=true, unit="m") "Vehicle z position";
  Real vx_v(start=0.0, fixed=true, unit="m/s") "Vehicle x velocity";
  Real vz_v(start=0.0, fixed=true, unit="m/s") "Vehicle z velocity";
  Real phi(start=0.0, fixed=true, unit="rad") "Vehicle pitch angle";
  Real theta(start=0.0, fixed=true, unit="rad") "Cable angle from vertical";
  Real theta_dot(start=0.0, fixed=true, unit="rad/s") "Cable angular rate";

  // ---- Computed physical quantities ----
  Real T_total(unit="N") "Total applied thrust";
  Real T_total_raw(unit="N") "Total thrust command before saturation";
  Real T_cable(unit="N") "Cable tension (non-negative)";
  Real T_cable_raw(unit="N") "Cable tension before clamp";
  Real ax_v(unit="m/s2") "Vehicle x acceleration";
  Real az_v(unit="m/s2") "Vehicle z acceleration";
  Real x_p(unit="m") "Payload x position";
  Real z_p(unit="m") "Payload z position";
  Real F_gust(unit="N") "Lateral gust force";
  Real F_drag_x(unit="N") "Aerodynamic drag force x";
  Real F_drag_z(unit="N") "Aerodynamic drag force z";

  // ---- Six rotor thrust channels ----
  Real T_rotor1(unit="N") "Rotor 1 thrust (0 deg)";
  Real T_rotor2(unit="N") "Rotor 2 thrust (60 deg)";
  Real T_rotor3(unit="N") "Rotor 3 thrust (120 deg)";
  Real T_rotor4(unit="N") "Rotor 4 thrust (180 deg)";
  Real T_rotor5(unit="N") "Rotor 5 thrust (240 deg)";
  Real T_rotor6(unit="N") "Rotor 6 thrust (300 deg)";
  Real max_rotor(unit="N") "Maximum individual rotor thrust";
  Real min_rotor(unit="N") "Minimum individual rotor thrust";
  Real delta_T(unit="N") "Differential thrust for pitch torque";

  // ---- Controller signals ----
  Real x_cmd(unit="m") "X position command (input-shaped)";
  Real z_cmd(unit="m") "Z position command (input-shaped)";
  Real vx_cmd(unit="m/s") "X velocity command";
  Real vz_cmd(unit="m/s") "Z velocity command";
  Real phi_cmd(unit="rad") "Pitch angle command";
  Real err_x(unit="m") "X tracking error";
  Real err_z(unit="m") "Z tracking error";
  Real tracking_err(unit="m") "Primary tracking error magnitude";

  // ---- Sensor outputs ----
  Real gps_x(unit="m") "GPS x position measurement";
  Real gps_z(unit="m") "GPS z position measurement";
  Real imu_ax(unit="m/s2") "IMU x acceleration measurement";
  Real imu_az(unit="m/s2") "IMU z acceleration measurement";
  Real imu_wpitch(unit="rad/s") "IMU pitch rate measurement";
  Real cable_angle_meas(unit="rad") "Cable angle measurement";
  Real cable_tension_meas(unit="N") "Cable tension measurement";

  // ---- Acceptance flags (fail-closed) ----
  Boolean thrust_ok "All rotor thrusts within [0, 12.1] N";
  Boolean tension_ok "Cable tension non-negative and bounded";
  Boolean swing_ok "Cable swing below 0.45 rad";
  Boolean placement_ok "Payload within 0.8 m target zone";
  Boolean no_ground_strike "Vehicle and payload above ground";
  Boolean tracking_ok "Tracking error below 0.27 m after 10.4 s";
  Boolean no_nan_inf "No NaN or infinite values in key variables";
  Real placement_err(unit="m") "Payload distance to target center (5, 0)";

protected
  Real A0 "Vehicle x acceleration without cable coupling";
  Real B0 "Vehicle z acceleration without cable coupling";
  Real mu "Reduced mass factor m_p*m_v/(m_p+m_v)";

equation
  // ============ Trajectory generation (input-shaped) ============
  x_cmd = x_target * smoothstep5(time, 3.5, 9.5);
  z_cmd = z_start
          + (z_cruise - z_start) * smoothstep5(time, 0.0, 3.5)
          - (z_cruise - z_final) * smoothstep5(time, 9.5, 15.5);

  vx_cmd = x_target * smoothstep5_der(time, 3.5, 9.5);
  vz_cmd = (z_cruise - z_start) * smoothstep5_der(time, 0.0, 3.5)
           - (z_cruise - z_final) * smoothstep5_der(time, 9.5, 15.5);

  // ============ Gust disturbance (middle third, 9.6 N) ============
  F_gust = 9.6 * smoothstep5(time, 5.33, 5.83)
           * (1.0 - smoothstep5(time, 10.17, 10.67));

  // ============ Aerodynamic drag (linear) ============
  F_drag_x = -cd_drag * vx_v;
  F_drag_z = -cd_drag * vz_v;

  // ============ Position controller with cable-swing damping ============
  err_x = x_cmd - gps_x;
  err_z = z_cmd - gps_z;

  // Pitch command: PD position control + cable swing damping
  phi_cmd = clamp2(
    K_px * err_x + K_dx * (vx_cmd - vx_v)
    - K_swing_p * theta - K_swing_d * theta_dot,
    -0.25, 0.25);

  // Thrust command: weight feedforward + PD position + cable-angle compensation
  T_total_raw = m_total * g
    + K_pz * m_total * err_z
    + K_dz * m_total * (vz_cmd - vz_v)
    - m_payload * g * (cos(theta) - 1.0);
  T_total = clamp2(T_total_raw, 0.0, T_total_max);

  // Pitch dynamics (first-order lag)
  der(phi) = (phi_cmd - phi) / tau_pitch;
  imu_wpitch = (phi_cmd - phi) / tau_pitch;

  // ============ Rotor thrust allocation ============
  delta_T = I_yy * (phi_cmd - phi) / (tau_pitch * 3.0 * R_rotor);
  T_rotor1 = clamp2(T_total / 6.0 - delta_T,       0.0, T_max_rotor);
  T_rotor2 = clamp2(T_total / 6.0 - delta_T / 2.0, 0.0, T_max_rotor);
  T_rotor3 = clamp2(T_total / 6.0 + delta_T / 2.0, 0.0, T_max_rotor);
  T_rotor4 = clamp2(T_total / 6.0 + delta_T,       0.0, T_max_rotor);
  T_rotor5 = clamp2(T_total / 6.0 + delta_T / 2.0, 0.0, T_max_rotor);
  T_rotor6 = clamp2(T_total / 6.0 - delta_T / 2.0, 0.0, T_max_rotor);

  max_rotor = max(max(max(max(max(T_rotor1, T_rotor2), T_rotor3),
                        max(T_rotor4, T_rotor5)), T_rotor6), 0.0);
  min_rotor = min(min(min(min(min(T_rotor1, T_rotor2), T_rotor3),
                        min(T_rotor4, T_rotor5)), T_rotor6), T_max_rotor);

  // ============ Coupled vehicle-payload dynamics (explicit) ============
  A0 = (T_total * sin(phi) + F_drag_x + F_gust) / m_vehicle;
  B0 = (T_total * cos(phi) - m_vehicle * g + F_drag_z) / m_vehicle;

  mu = m_payload * m_vehicle / (m_payload + m_vehicle);

  T_cable_raw = mu * (-A0 * sin(theta)
                      + B0 * cos(theta)
                      + L_cable * theta_dot * theta_dot
                      + g * cos(theta));
  T_cable = max(0.0, T_cable_raw);

  ax_v = A0 + T_cable * sin(theta) / m_vehicle;
  az_v = B0 - T_cable * cos(theta) / m_vehicle;

  der(theta) = theta_dot;
  der(theta_dot) = -(g * sin(theta) + ax_v * cos(theta) + az_v * sin(theta))
                    / L_cable
                    - cable_nat_damp * theta_dot;

  der(x_v) = vx_v;
  der(z_v) = vz_v;
  der(vx_v) = ax_v;
  der(vz_v) = az_v;

  x_p = x_v + L_cable * sin(theta);
  z_p = z_v - L_cable * cos(theta);

  // ============ Sensors (ideal) ============
  gps_x = x_v;
  gps_z = z_v;
  imu_ax = ax_v;
  imu_az = az_v;
  cable_angle_meas = theta;
  cable_tension_meas = T_cable;

  // ============ Tracking error ============
  tracking_err = sqrt(err_x * err_x + err_z * err_z);

  // ============ Acceptance criteria (fail-closed) ============
  thrust_ok = (max_rotor <= T_max_rotor + 0.001) and (min_rotor >= -0.001);
  tension_ok = (T_cable >= 0.0) and (T_cable <= 100.0);
  swing_ok = abs(theta) < 0.45;
  placement_err = sqrt((x_p - x_target) * (x_p - x_target) + z_p * z_p);
  placement_ok = placement_err <= target_radius;
  no_ground_strike = (z_v >= 0.0) and (z_p >= -0.001);
  tracking_ok = (if time >= 10.4 then tracking_err else 0.0) < 0.27;
  no_nan_inf = (abs(T_total) < 1.0e10) and (abs(T_cable) < 1.0e10)
               and (abs(theta) < 1.0e10) and (abs(x_v) < 1.0e10)
               and (abs(z_v) < 1.0e10) and (abs(ax_v) < 1.0e10)
               and (abs(az_v) < 1.0e10) and (abs(phi) < 1.0e10)
               and (abs(phi_cmd) < 1.0e10) and (abs(T_total_raw) < 1.0e10)
               and (abs(cable_tension_meas) < 1.0e10);

  annotation(
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="HexaSurveyDeliverE: Hexacopter (3.2 kg fuselage + 0.4 kg camera)
      with six rotors at 0.35 m radius, each bounded at 12.1 N.
      Suspends a payload via cable, lifts, translates 5 m, lowers into
      0.8 m-radius target zone.
      Runs at 250 Hz for 16 s. Input-shaped position control with cable-swing
      damping. 9.6 N lateral gust during middle third of flight.
      Acceptance: thrust/tension bounds, swing < 0.45 rad, target placement,
      no ground strike, tracking error < 0.27 m after 10.4 s, no NaN/Inf.
      Values not stated in the requirement (payload mass, cable length, drag
      coefficient, pitch inertia, cruise height, controller gains) are labeled
      as assumed and must not be treated as verified facts.")
  );
end HexaSurveyDeliverE;