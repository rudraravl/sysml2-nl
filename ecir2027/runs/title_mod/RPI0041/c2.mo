model HexaSurveyDeliverE
  "Free-base hexacopter with suspended payload: lift, translate 5 m, lower into target zone"

  // ---- Physical parameters (stated by requirement) ----
  parameter Real m_fuselage(unit="kg") = 3.2 "Cylindrical fuselage mass";
  parameter Real m_camera(unit="kg") = 0.4 "Downward camera payload mass";
  parameter Real R_rotor(unit="m") = 0.35 "Rotor radius from center";
  parameter Real T_max_rotor(unit="N") = 12.1 "Max thrust per rotor";
  parameter Real target_radius(unit="m") = 0.8 "Target zone radius";
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";
  parameter Real x_target(unit="m") = 5.0;

  // ---- Physical parameters (not stated; assumed and labeled) ----
  parameter Real m_payload(unit="kg") = 2.0 "Suspended payload mass (not stated; assumed)";
  parameter Real L_cable(unit="m") = 1.0 "Cable length (not stated; assumed)";
  parameter Real cd_drag(unit="N.s/m") = 0.15 "Linear aerodynamic drag coefficient (not stated; assumed)";
  parameter Real tau_pitch(unit="s") = 0.25 "Pitch response time constant (not stated; assumed)";
  parameter Real I_yy(unit="kg.m2") = 0.12 "Pitch moment of inertia (not stated; assumed)";
  parameter Real z_cruise(unit="m") = 2.0 "Cruise height (not stated; assumed)";
  parameter Real z_start(unit="m") = 1.1 "Initial vehicle height (not stated; assumed)";
  parameter Real z_final(unit="m") = 1.05 "Final vehicle height (not stated; assumed)";

  // ---- Derived constants ----
  parameter Real m_vehicle(unit="kg") = m_fuselage + m_camera;
  parameter Real m_total(unit="kg") = m_vehicle + m_payload;
  parameter Real T_total_max(unit="N") = 6.0 * T_max_rotor;

  // ---- Controller gains (not stated; tuned for acceptance) ----
  parameter Real K_px = 0.8;
  parameter Real K_dx = 0.8;
  parameter Real K_pz = 1.5;
  parameter Real K_dz = 2.5;
  parameter Real K_swing_p = 1.5;
  parameter Real K_swing_d = 0.8;
  parameter Real cable_nat_damp(unit="1/s") = 0.3;

  // ---- Dynamic state variables ----
  Real x_v(start=0.0, fixed=true, unit="m");
  Real z_v(start=1.1, fixed=true, unit="m");
  Real vx_v(start=0.0, fixed=true, unit="m/s");
  Real vz_v(start=0.0, fixed=true, unit="m/s");
  Real phi(start=0.0, fixed=true, unit="rad");
  Real theta(start=0.0, fixed=true, unit="rad");
  Real theta_dot(start=0.0, fixed=true, unit="rad/s");

  // ---- Computed physical quantities ----
  Real T_total(unit="N");
  Real T_total_raw(unit="N");
  Real T_cable(unit="N");
  Real T_cable_raw(unit="N");
  Real ax_v(unit="m/s2");
  Real az_v(unit="m/s2");
  Real x_p(unit="m");
  Real z_p(unit="m");
  Real F_gust(unit="N");
  Real F_drag_x(unit="N");
  Real F_drag_z(unit="N");

  // ---- Six rotor thrust channels ----
  Real T_rotor1(unit="N");
  Real T_rotor2(unit="N");
  Real T_rotor3(unit="N");
  Real T_rotor4(unit="N");
  Real T_rotor5(unit="N");
  Real T_rotor6(unit="N");
  Real max_rotor(unit="N");
  Real min_rotor(unit="N");
  Real delta_T(unit="N");

  // ---- Controller signals ----
  Real x_cmd(unit="m");
  Real z_cmd(unit="m");
  Real vx_cmd(unit="m/s");
  Real vz_cmd(unit="m/s");
  Real phi_cmd(unit="rad");
  Real err_x(unit="m");
  Real err_z(unit="m");
  Real tracking_err(unit="m");

  // ---- Sensor outputs ----
  Real gps_x(unit="m");
  Real gps_z(unit="m");
  Real imu_ax(unit="m/s2");
  Real imu_az(unit="m/s2");
  Real imu_wpitch(unit="rad/s");
  Real cable_angle_meas(unit="rad");
  Real cable_tension_meas(unit="N");

  // ---- Acceptance flags (fail-closed) ----
  Boolean thrust_ok;
  Boolean tension_ok;
  Boolean swing_ok;
  Boolean placement_ok;
  Boolean no_ground_strike;
  Boolean tracking_ok;
  Boolean no_nan_inf;
  Real placement_err(unit="m");

  // ---- Helpers ----
  Real A0;
  Real B0;
  Real mu;
  Real clamp_hi_phi_cmd;
  Real max_r1, max_r2, max_r3;
  Real min_r1, min_r2, min_r3;
  Real s1, s2, s3, s1d, s2d, s3d;
  Real x_s1, x_s2, x_s3;
  Real gs1, gs2, x_gs1, x_gs2;

equation
  // ============ Trajectory generation (input-shaped) ============
  x_s1 = if time <= 0.0 then 0.0 elseif time >= 3.5 then 1.0 else time/3.5;
  s1 = if time <= 0.0 then 0.0 elseif time >= 3.5 then 1.0 else x_s1*x_s1*x_s1*(x_s1*(6.0*x_s1 - 15.0) + 10.0);
  s1d = if time <= 0.0 or time >= 3.5 then 0.0 else 30.0*x_s1*x_s1*(x_s1 - 1.0)*(x_s1 - 1.0)/3.5;

  x_s2 = if time <= 3.5 then 0.0 elseif time >= 9.5 then 1.0 else (time-3.5)/6.0;
  s2 = if time <= 3.5 then 0.0 elseif time >= 9.5 then 1.0 else x_s2*x_s2*x_s2*(x_s2*(6.0*x_s2 - 15.0) + 10.0);
  s2d = if time <= 3.5 or time >= 9.5 then 0.0 else 30.0*x_s2*x_s2*(x_s2 - 1.0)*(x_s2 - 1.0)/6.0;

  x_s3 = if time <= 9.5 then 0.0 elseif time >= 15.5 then 1.0 else (time-9.5)/6.0;
  s3 = if time <= 9.5 then 0.0 elseif time >= 15.5 then 1.0 else x_s3*x_s3*x_s3*(x_s3*(6.0*x_s3 - 15.0) + 10.0);
  s3d = if time <= 9.5 or time >= 15.5 then 0.0 else 30.0*x_s3*x_s3*(x_s3 - 1.0)*(x_s3 - 1.0)/6.0;

  x_cmd = x_target * s2;
  z_cmd = z_start + (z_cruise - z_start) * s1 - (z_cruise - z_final) * s3;

  vx_cmd = x_target * s2d;
  vz_cmd = (z_cruise - z_start) * s1d - (z_cruise - z_final) * s3d;

  // ============ Gust disturbance (middle third, 9.6 N) ============
  x_gs1 = if time <= 5.33 then 0.0 elseif time >= 5.83 then 1.0 else (time-5.33)/0.5;
  gs1 = if time <= 5.33 then 0.0 elseif time >= 5.83 then 1.0 else x_gs1*x_gs1*x_gs1*(x_gs1*(6.0*x_gs1 - 15.0) + 10.0);

  x_gs2 = if time <= 10.17 then 0.0 elseif time >= 10.67 then 1.0 else (time-10.17)/0.5;
  gs2 = if time <= 10.17 then 0.0 elseif time >= 10.67 then 1.0 else x_gs2*x_gs2*x_gs2*(x_gs2*(6.0*x_gs2 - 15.0) + 10.0);

  F_gust = 9.6 * gs1 * (1.0 - gs2);

  // ============ Aerodynamic drag (linear) ============
  F_drag_x = -cd_drag * vx_v;
  F_drag_z = -cd_drag * vz_v;

  // ============ Position controller with cable-swing damping ============
  err_x = x_cmd - gps_x;
  err_z = z_cmd - gps_z;

  clamp_hi_phi_cmd = K_px * err_x + K_dx * (vx_cmd - vx_v) - K_swing_p * theta - K_swing_d * theta_dot;
  phi_cmd = max(-0.25, min(clamp_hi_phi_cmd, 0.25));

  T_total_raw = m_total * g + K_pz * m_total * err_z + K_dz * m_total * (vz_cmd - vz_v) - m_payload * g * (cos(theta) - 1.0);
  T_total = max(0.0, min(T_total_raw, T_total_max));

  // Pitch dynamics (first-order lag)
  der(phi) = (phi_cmd - phi) / tau_pitch;
  imu_wpitch = der(phi);

  // ============ Rotor thrust allocation ============
  delta_T = I_yy * (phi_cmd - phi) / (tau_pitch * 3.0 * R_rotor);
  T_rotor1 = max(0.0, min(T_total / 6.0 - delta_T, T_max_rotor));
  T_rotor2 = max(0.0, min(T_total / 6.0 - delta_T / 2.0, T_max_rotor));
  T_rotor3 = max(0.0, min(T_total / 6.0 + delta_T / 2.0, T_max_rotor));
  T_rotor4 = max(0.0, min(T_total / 6.0 + delta_T, T_max_rotor));
  T_rotor5 = max(0.0, min(T_total / 6.0 + delta_T / 2.0, T_max_rotor));
  T_rotor6 = max(0.0, min(T_total / 6.0 - delta_T / 2.0, T_max_rotor));

  max_r1 = max(T_rotor1, T_rotor2);
  max_r2 = max(T_rotor3, T_rotor4);
  max_r3 = max(T_rotor5, T_rotor6);
  max_rotor = max(max(max_r1, max_r2), max_r3);

  min_r1 = min(T_rotor1, T_rotor2);
  min_r2 = min(T_rotor3, T_rotor4);
  min_r3 = min(T_rotor5, T_rotor6);
  min_rotor = min(min(min_r1, min_r2), min_r3);

  // ============ Coupled vehicle-payload dynamics (explicit) ============
  A0 = (T_total * sin(phi) + F_drag_x + F_gust) / m_vehicle;
  B0 = (T_total * cos(phi) - m_vehicle * g + F_drag_z) / m_vehicle;

  mu = m_payload * m_vehicle / (m_payload + m_vehicle);

  T_cable_raw = mu * (-A0 * sin(theta) + B0 * cos(theta) + L_cable * theta_dot * theta_dot + g * cos(theta));
  T_cable = max(0.0, T_cable_raw);

  ax_v = A0 + T_cable * sin(theta) / m_vehicle;
  az_v = B0 - T_cable * cos(theta) / m_vehicle;

  der(theta) = theta_dot;
  der(theta_dot) = -(g * sin(theta) + ax_v * cos(theta) + az_v * sin(theta)) / L_cable - cable_nat_damp * theta_dot;

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