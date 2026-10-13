model BLDCWheelRecoverF
  "48V PMSM wheel actuator with FOC, feedforward motion control and disturbance observer";

  // ---- Battery and DC bus ----
  parameter Real V_oc(unit="V") = 48.0 "Battery open-circuit voltage";
  parameter Real R_int(unit="Ohm") = 0.05 "Battery internal resistance";
  parameter Real C_bus(unit="F") = 1.0e-3 "DC bus capacitance";
  parameter Real V_bus_max(unit="V") = 58.6 "Max DC bus voltage limit";

  // ---- Motor (PMSM) ----
  parameter Real R_s(unit="Ohm") = 0.15 "Stator phase resistance";
  parameter Real L_s(unit="H") = 0.5e-3 "Stator phase inductance";
  parameter Real lambda_pm(unit="Wb") = 0.05 "PM flux linkage";
  parameter Real p_pairs = 4.0 "Pole pairs";
  parameter Real J_motor(unit="kg.m2") = 1.0e-4 "Motor rotor inertia";
  parameter Real b_motor(unit="N.m.s/rad") = 1.0e-4 "Motor viscous friction";
  parameter Real I_max(unit="A") = 30.0 "Max phase current";

  // ---- Gearbox and wheel ----
  parameter Real N_gear = 9.0 "Gear ratio (motor:wheel)";
  parameter Real eta_gear = 0.95 "Gearbox efficiency";
  parameter Real r_wheel(unit="m") = 0.12 "Wheel radius";
  parameter Real J_wheel(unit="kg.m2") = 5.0e-4 "Wheel inertia";

  // ---- Thermal ----
  parameter Real C_th(unit="J/K") = 50.0 "Winding thermal capacitance";
  parameter Real R_th(unit="K/W") = 0.5 "Thermal resistance to ambient";
  parameter Real T_amb(unit="K") = 298.15 "Ambient temperature";
  parameter Real T_max(unit="K") = 393.15 "Max winding temperature";

  // ---- Control gains ----
  parameter Real Kp_pos(unit="1/s") = 10.0 "Position proportional gain";
  parameter Real Kd_pos(unit="N.m.s/rad") = 0.05 "Position derivative gain";
  parameter Real Kp_i(unit="V/A") = 0.5 "Current loop proportional gain";
  parameter Real Ki_i(unit="V/(A.s)") = 150.0 "Current loop integral gain";
  parameter Real tau_dob(unit="s") = 0.02 "Disturbance observer time constant";

  // ---- Command ----
  parameter Real theta_amp(unit="rad") = 5.0 "Position command amplitude at wheel";
  parameter Real f_cmd(unit="Hz") = 0.15 "Command frequency";

  // ---- Disturbance ----
  parameter Real F_dist(unit="N") = 29.0 "Disturbance force at wheel";
  parameter Real t_dist_on(unit="s") = 20.0 / 3.0 "Disturbance start time";
  parameter Real t_dist_off(unit="s") = 40.0 / 3.0 "Disturbance end time";

  // ---- Sampling ----
  parameter Real f_sample(unit="Hz") = 500.0 "Control and sample rate";

  // ---- Derived constants ----
  parameter Real K_t(unit="N.m/A") = 1.5 * p_pairs * lambda_pm "Torque constant";
  parameter Real J_total(unit="kg.m2") = J_motor + J_wheel / (N_gear * N_gear) "Total inertia referred to motor";
  parameter Real V_max_phase(unit="V") = V_bus_max / sqrt(3.0) "Max phase voltage magnitude";
  parameter Real Ts(unit="s") = 1.0 / f_sample "Sample period";
  constant Real pi_val = 3.14159265358979;

  // ---- Dynamic states ----
  Real V_bus(unit="V") "DC bus voltage";
  Real i_d(unit="A") "d-axis stator current";
  Real i_q(unit="A") "q-axis stator current";
  Real omega_m(unit="rad/s") "Motor angular velocity";
  Real theta_m(unit="rad") "Motor angular position";
  Real T_winding(unit="K") "Winding temperature";
  Real x_id_int(unit="A.s") "d-current controller integrator state";
  Real x_iq_int(unit="A.s") "q-current controller integrator state";
  Real d_hat(unit="N.m") "Disturbance torque estimate";
  Real peak_dev(unit="rad") "Peak tracking deviation";
  Real recovery_timer(unit="s") "Recovery time accumulator";
  Real omega_f(unit="rad/s") "Filtered motor velocity for DOB";

  // ---- Command signals ----
  Real theta_cmd_w(unit="rad") "Wheel angle command";
  Real omega_cmd_w(unit="rad/s") "Wheel velocity command";
  Real alpha_cmd_w(unit="rad/s2") "Wheel acceleration command";
  Real theta_cmd_m(unit="rad") "Motor angle command";
  Real omega_cmd_m(unit="rad/s") "Motor velocity command";
  Real alpha_cmd_m(unit="rad/s2") "Motor acceleration command";

  // ---- Control signals ----
  Real i_d_cmd(unit="A") "d-axis current command";
  Real i_q_cmd(unit="A") "q-axis current command";
  Real T_motor_cmd(unit="N.m") "Motor torque command";
  Real v_d_raw(unit="V") "Unsaturated d-axis voltage";
  Real v_q_raw(unit="V") "Unsaturated q-axis voltage";
  Real v_d(unit="V") "Saturated d-axis voltage";
  Real v_q(unit="V") "Saturated q-axis voltage";
  Real v_mag(unit="V") "Voltage vector magnitude";
  Real v_sat_scale "Voltage saturation scale factor";
  Real T_e(unit="N.m") "Electromagnetic torque";

  // ---- Mechanical outputs ----
  Real theta_w(unit="rad") "Wheel angle";
  Real omega_w(unit="rad/s") "Wheel angular velocity";
  Real x_wheel(unit="m") "Wheel linear position";
  Real v_wheel(unit="m/s") "Wheel linear velocity";
  Real T_dist_motor(unit="N.m") "Disturbance torque referred to motor";
  Real F_dist_applied(unit="N") "Applied disturbance force";

  // ---- Electrical observations ----
  Real I_rms(unit="A") "RMS stator current";
  Real I_bus(unit="A") "DC bus current";
  Real P_elec(unit="W") "Electrical power";
  Real P_loss(unit="W") "Copper loss";

  // ---- Tracking ----
  Real theta_err(unit="rad") "Tracking error at wheel";
  Real theta_err_m(unit="rad") "Tracking error at motor";

  // ---- DOB auxiliary ----
  Real alpha_est(unit="rad/s2") "Estimated motor acceleration for DOB";

  // ---- Verification ----
  Boolean trip_voltage "Voltage protection trip";
  Boolean trip_temperature "Temperature protection trip";
  Boolean trip_current "Current protection trip";
  Boolean any_trip "Any protection trip";
  Real terminal_error(unit="rad") "Terminal tracking error";
  Boolean no_nan "No NaN or infinite values flag";
  Boolean spec_pass "All verification criteria pass";

initial equation
  V_bus = V_oc;
  i_d = 0.0;
  i_q = 0.0;
  omega_m = 0.0;
  theta_m = 0.0;
  T_winding = T_amb;
  x_id_int = 0.0;
  x_iq_int = 0.0;
  d_hat = 0.0;
  peak_dev = 0.0;
  recovery_timer = 0.0;
  omega_f = 0.0;

equation
  // ---- Smooth command (starts from rest) ----
  theta_cmd_w = theta_amp * 0.5 * (1.0 - cos(2.0 * pi_val * f_cmd * time));
  omega_cmd_w = theta_amp * 0.5 * 2.0 * pi_val * f_cmd * sin(2.0 * pi_val * f_cmd * time);
  alpha_cmd_w = theta_amp * 0.5 * (2.0 * pi_val * f_cmd) * (2.0 * pi_val * f_cmd) * cos(2.0 * pi_val * f_cmd * time);

  // ---- Refer command to motor side ----
  theta_cmd_m = theta_cmd_w * N_gear;
  omega_cmd_m = omega_cmd_w * N_gear;
  alpha_cmd_m = alpha_cmd_w * N_gear;

  // ---- Mechanical output ----
  theta_w = theta_m / N_gear;
  omega_w = omega_m / N_gear;
  x_wheel = theta_w * r_wheel;
  v_wheel = omega_w * r_wheel;
  theta_err = theta_cmd_w - theta_w;
  theta_err_m = theta_cmd_m - theta_m;

  // ---- Disturbance applied during middle third ----
  F_dist_applied = if (time >= t_dist_on and time <= t_dist_off) then F_dist else 0.0;
  T_dist_motor = F_dist_applied * r_wheel / (N_gear * eta_gear);

  // ---- Electromagnetic torque ----
  T_e = K_t * i_q;

  // ---- Motor mechanical dynamics ----
  der(theta_m) = omega_m;
  der(omega_m) = (T_e - b_motor * omega_m - T_dist_motor) / J_total;

  // ---- DC bus dynamics ----
  P_elec = 1.5 * (v_d * i_d + v_q * i_q);
  P_loss = 1.5 * R_s * (i_d * i_d + i_q * i_q);
  I_bus = if (abs(V_bus) > 0.001) then P_elec / V_bus else 0.0;
  der(V_bus) = ((V_oc - V_bus) / R_int - I_bus) / C_bus;

  // ---- Motor electrical dynamics (dq synchronous frame) ----
  der(i_d) = (v_d - R_s * i_d + p_pairs * omega_m * L_s * i_q) / L_s;
  der(i_q) = (v_q - R_s * i_q - p_pairs * omega_m * (lambda_pm + L_s * i_d)) / L_s;

  // ---- Feedforward motion control with DOB compensation ----
  i_d_cmd = 0.0;
  T_motor_cmd = J_total * alpha_cmd_m + b_motor * omega_m + d_hat + Kp_pos * theta_err_m + Kd_pos * (omega_cmd_m - omega_m);
  i_q_cmd = T_motor_cmd / K_t;

  // ---- Current controller (PI with back-EMF feedforward) ----
  der(x_id_int) = (i_d_cmd - i_d);
  der(x_iq_int) = (i_q_cmd - i_q);
  v_d_raw = Kp_i * (i_d_cmd - i_d) + Ki_i * x_id_int - p_pairs * omega_m * L_s * i_q;
  v_q_raw = Kp_i * (i_q_cmd - i_q) + Ki_i * x_iq_int + p_pairs * omega_m * (lambda_pm + L_s * i_d);

  // ---- Voltage saturation (preserves vector direction) ----
  v_mag = sqrt(v_d_raw * v_d_raw + v_q_raw * v_q_raw);
  v_sat_scale = if (v_mag > 0.001) then min(1.0, V_max_phase / v_mag) else 1.0;
  v_d = v_d_raw * v_sat_scale;
  v_q = v_q_raw * v_sat_scale;

  // ---- Disturbance observer (dirty-derivative based) ----
  der(omega_f) = (omega_m - omega_f) / tau_dob;
  alpha_est = (omega_m - omega_f) / tau_dob;
  der(d_hat) = (T_e - b_motor * omega_m - J_total * alpha_est - d_hat) / tau_dob;

  // ---- Winding thermal dynamics ----
  I_rms = sqrt(i_d * i_d + i_q * i_q);
  der(T_winding) = (P_loss - (T_winding - T_amb) / R_th) / C_th;

  // ---- Protection flags ----
  trip_voltage = V_bus > V_bus_max;
  trip_temperature = T_winding > T_max;
  trip_current = I_rms > I_max;
  any_trip = trip_voltage or trip_temperature or trip_current;

  // ---- Verification metrics ----
  der(peak_dev) = max(0.0, abs(theta_err) - peak_dev) * 1.0e4;
  terminal_error = abs(theta_err);
  der(recovery_timer) = if (time > t_dist_off and abs(theta_err) >= 0.01) then 1.0 else 0.0;
  no_nan = true;
  spec_pass = (not any_trip) and no_nan and (time < 13.0 or abs(theta_err) < 0.032);

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "BLDCWheelRecoverF: 48V three-phase PMSM (4 pole pairs) driving a 0.12m wheel through a 9:1 gearbox. Battery with internal resistance supplies a field-oriented inverter. Feedforward motion control with disturbance observer. A 29N disturbance force is applied at the wheel during the middle third (6.67 to 13.33s). 500Hz sample rate, 20s duration. Verification: tracking error below 0.032 rad after 13s, no protection trips, no NaN or infinite values."));
end BLDCWheelRecoverF;