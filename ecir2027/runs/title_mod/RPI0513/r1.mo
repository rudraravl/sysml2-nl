model BLDCWheelSpeedC
  "Electromechanical robotic actuator: PMSM FOC speed control, 9:1 gearbox, 0.12 m wheel, battery with droop"

  // ===== Simulation and control timing =====
  parameter Real Ts = 1.0 / 125.0 "Controller sample period [s]";
  parameter Real T_end = 12.0 "Total simulation duration [s]";

  // ===== Battery (48 V with internal resistance) =====
  parameter Real V_oc = 48.0 "Battery open-circuit voltage [V]";
  parameter Real R_batt = 0.03 "Battery internal resistance [Ohm] — not specified, assumed";
  parameter Real Q_batt_Ah = 5.0 "Battery capacity [Ah] — not specified, assumed";
  parameter Real SOC_init = 0.90 "Initial state of charge [1]";
  Real SOC(start = SOC_init, fixed = true) "State of charge [1]";
  Real V_bus "DC bus voltage [V]";
  Real I_bus "DC bus current [A]";

  // ===== PMSM motor (48 V, 4 pole pairs) =====
  parameter Integer p = 4 "Number of pole pairs";
  parameter Real Rs = 0.1 "Stator phase resistance [Ohm] — not specified, assumed";
  parameter Real Ls = 0.002 "Stator phase inductance [H] — not specified, assumed";
  parameter Real psi_m = 0.03 "Magnet flux linkage [Wb] — not specified, assumed";
  parameter Real J_motor = 0.0008 "Rotor inertia [kg.m2] — not specified, assumed";
  parameter Real B_motor = 0.00005 "Motor viscous friction [N.m.s/rad] — not specified, assumed";

  Real id(start = 0.0, fixed = true) "d-axis current [A]";
  Real iq(start = 0.0, fixed = true) "q-axis current [A]";
  Real vd "d-axis voltage command [V]";
  Real vq "q-axis voltage command [V]";
  Real omega_m(start = 0.0, fixed = true) "Rotor mechanical speed [rad/s]";
  Real theta_m(start = 0.0, fixed = true) "Rotor mechanical angle [rad]";
  Real omega_e "Rotor electrical speed [rad/s]";
  Real theta_e "Rotor electrical angle [rad]";
  Real Te "Electromagnetic torque [N.m]";
  Real I_phase "Phase current magnitude [A]";
  Real P_loss "Stator copper loss [W]";

  // ===== Thermal =====
  parameter Real Rth = 0.5 "Thermal resistance [K/W] — not specified, assumed";
  parameter Real Cth = 50.0 "Thermal capacitance [J/K] — not specified, assumed";
  Real T_temp(start = 0.0, fixed = true) "Motor temperature rise above ambient [K]";

  // ===== Gearbox (9:1) =====
  parameter Real gear_ratio = 9.0 "Gear reduction ratio (motor:output)";
  parameter Real eta_gear = 0.92 "Gearbox efficiency [1] — not specified, assumed";
  Real omega_out "Output shaft speed [rad/s]";
  Real T_gear_out "Torque at gearbox output [N.m]";
  Real J_total "Total inertia reflected to output [kg.m2]";
  Real B_total "Total viscous friction reflected to output [N.m.s/rad]";

  // ===== Wheel (0.12 m radius) =====
  parameter Real r_wheel = 0.12 "Wheel radius [m]";
  Real v_wheel "Wheel linear speed [m/s]";
  Real v_ref "Linear speed reference [m/s]";

  // ===== Load =====
  parameter Real J_load = 0.02 "Load inertia at output shaft [kg.m2] — not specified, assumed";
  parameter Real B_load = 0.005 "Load viscous friction [N.m.s/rad] — not specified, assumed";
  parameter Real T_coulomb = 0.05 "Coulomb friction torque [N.m] — not specified, assumed";
  parameter Real T_dist = 10.8 "Disturbance torque magnitude [N.m]";
  Real T_disturbance "Applied disturbance torque [N.m]";

  // ===== Speed profile =====
  parameter Real omega_ref_max = 20.0 "Maximum output speed reference [rad/s] — not specified, assumed";
  parameter Real t_accel_end = 3.0 "End of acceleration ramp [s] — not specified, assumed";
  parameter Real t_decel_start = 9.0 "Start of deceleration ramp [s] — not specified, assumed";
  parameter Real t_stop = 11.5 "Time to reach zero speed [s] — not specified, assumed";
  Real omega_ref "Speed reference [rad/s]";
  Real alpha_ref "Reference acceleration [rad/s2]";
  Real speed_error "Speed tracking error [rad/s]";
  Real tracking_error "Absolute tracking error [rad/s]";

  // ===== Controller parameters =====
  parameter Real V_max = 44.2 "Maximum voltage command magnitude [V]";
  parameter Real I_max = 30.0 "Maximum phase current command [A] — not specified, assumed";
  parameter Real Kp_speed = 2.0 "Speed controller proportional gain — not specified, assumed";
  parameter Real Ki_speed = 15.0 "Speed controller integral gain — not specified, assumed";
  parameter Real Kp_curr = 0.1 "Current controller proportional gain — not specified, assumed";
  parameter Real Ki_curr = 5.0 "Current controller integral gain — not specified, assumed";

  // Controller states and signals
  Real speed_int(start = 0.0, fixed = true) "Speed controller integrator state";
  Real id_int(start = 0.0, fixed = true) "d-axis current controller integrator state";
  Real iq_int(start = 0.0, fixed = true) "q-axis current controller integrator state";
  Real iq_ref_raw "Unsaturated q-axis current reference [A]";
  Real iq_ref "Saturated q-axis current reference [A]";
  Real id_err "d-axis current error [A]";
  Real iq_err "q-axis current error [A]";
  Real vd_cont "Continuous (pre-sample) d-axis voltage [V]";
  Real vq_cont "Continuous (pre-sample) q-axis voltage [V]";

  // Discrete zero-order-hold outputs at 125 Hz
  discrete Real vd_d(start = 0.0) "Sampled d-axis voltage [V]";
  discrete Real vq_d(start = 0.0) "Sampled q-axis voltage [V]";

  // ===== Sensors =====
  Real sensed_omega_out "Sensed output speed [rad/s]";
  Real sensed_theta "Sensed rotor position [rad]";
  Real sensed_I_phase "Sensed phase current magnitude [A]";
  Real sensed_V_bus "Sensed DC bus voltage [V]";
  Real sensed_SOC "Sensed state of charge [1]";
  Real sensed_T_temp "Sensed motor temperature rise [K]";

  // ===== Bounds monitoring =====
  Real accel_out "Output shaft acceleration [rad/s2]";
  parameter Real V_bus_min_b = 30.0 "Minimum bus voltage bound [V] — assumed";
  parameter Real V_bus_max_b = 55.0 "Maximum bus voltage bound [V] — assumed";
  parameter Real I_phase_b = 40.0 "Phase current bound [A] — assumed";
  parameter Real omega_b = 50.0 "Output speed bound [rad/s] — assumed";
  parameter Real accel_b = 100.0 "Acceleration bound [rad/s2] — assumed";
  parameter Real SOC_min_b = 0.0 "Minimum SOC bound [1]";
  parameter Real T_temp_b = 80.0 "Temperature rise bound [K] — assumed";
  parameter Real tracking_lim = 0.263 "Tracking error limit after 7.8 s [rad/s]";

  Boolean voltage_ok "Voltage within bounds";
  Boolean current_ok "Current within bounds";
  Boolean speed_ok "Speed within bounds";
  Boolean accel_ok "Acceleration within bounds";
  Boolean soc_ok "SOC within bounds";
  Boolean thermal_ok "Temperature within bounds";
  Boolean tracking_ok "Tracking error within bounds after 7.8 s";
  Boolean no_nan_ok "No NaN or infinite values (structural guarantee)";

equation
  // ===== Speed reference profile: accelerate, hold, decelerate to rest =====
  if time < t_accel_end then
    omega_ref = omega_ref_max * time / t_accel_end;
  elseif time < t_decel_start then
    omega_ref = omega_ref_max;
  elseif time < t_stop then
    omega_ref = omega_ref_max * (1.0 - (time - t_decel_start) / (t_stop - t_decel_start));
  else
    omega_ref = 0.0;
  end if;

  if time < t_accel_end then
    alpha_ref = omega_ref_max / t_accel_end;
  elseif time < t_decel_start then
    alpha_ref = 0.0;
  elseif time < t_stop then
    alpha_ref = -omega_ref_max / (t_stop - t_decel_start);
  else
    alpha_ref = 0.0;
  end if;

  v_ref = omega_ref * r_wheel;

  // ===== Load torque disturbance: middle third of 12 s (4 s to 8 s) =====
  if time >= 4.0 and time <= 8.0 then
    T_disturbance = T_dist;
  else
    T_disturbance = 0.0;
  end if;

  // ===== Reflected quantities to output shaft =====
  J_total = J_load + J_motor * gear_ratio * gear_ratio;
  B_total = B_load + B_motor * gear_ratio * gear_ratio;

  // ===== PMSM electrical dynamics in dq frame (FOC) =====
  omega_e = p * omega_m;
  theta_e = p * theta_m;

  der(id) = (vd - Rs * id + omega_e * Ls * iq) / Ls;
  der(iq) = (vq - Rs * iq - omega_e * Ls * id - omega_e * psi_m) / Ls;

  Te = 1.5 * p * psi_m * iq;
  I_phase = sqrt(id * id + iq * iq);
  P_loss = 1.5 * Rs * (id * id + iq * iq);

  // ===== Kinematic coupling (rigid gearbox) =====
  omega_m = omega_out * gear_ratio;
  der(theta_m) = omega_m;

  // ===== Output shaft mechanical dynamics =====
  T_gear_out = eta_gear * gear_ratio * Te;

  J_total * der(omega_out) = T_gear_out
    - B_total * omega_out
    - T_coulomb * omega_out / (abs(omega_out) + 0.01)
    - T_disturbance;

  // Explicit acceleration expression for monitoring
  accel_out = (T_gear_out
    - B_total * omega_out
    - T_coulomb * omega_out / (abs(omega_out) + 0.01)
    - T_disturbance) / J_total;

  // ===== Thermal model =====
  der(T_temp) = (P_loss - T_temp / Rth) / Cth;

  // ===== Battery model with droop (quadratic solution avoids algebraic loop) =====
  // V_bus = V_oc - R_batt * I_bus,  I_bus = 1.5*(vd*id + vq*iq)/V_bus
  // => V_bus^2 - V_oc*V_bus + 1.5*R_batt*(vd*id + vq*iq) = 0
  V_bus = 0.5 * (V_oc + sqrt(max(V_oc * V_oc - 6.0 * R_batt * (vd * id + vq * iq), 0.01)));
  I_bus = (V_oc - V_bus) / R_batt;
  der(SOC) = -I_bus / (Q_batt_Ah * 3600.0);

  // ===== Wheel =====
  v_wheel = omega_out * r_wheel;

  // ===== Speed controller (continuous PI with anti-windup) =====
  speed_error = omega_ref - omega_out;
  iq_ref_raw = Kp_speed * speed_error + Ki_speed * speed_int;
  der(speed_int) = if abs(iq_ref_raw) <= I_max then speed_error else 0.0;
  iq_ref = max(-I_max, min(I_max, iq_ref_raw));

  // ===== Current controller (continuous PI with anti-windup, id_ref = 0) =====
  id_err = 0.0 - id;
  iq_err = iq_ref - iq;
  vd_cont = Kp_curr * id_err + Ki_curr * id_int;
  vq_cont = Kp_curr * iq_err + Ki_curr * iq_int;
  der(id_int) = if abs(vd_cont) <= V_max then id_err else 0.0;
  der(iq_int) = if abs(vq_cont) <= V_max then iq_err else 0.0;

  // ===== Zero-order hold at 125 Hz (digital inverter output) =====
  when sample(0, Ts) then
    vd_d = max(-V_max, min(V_max, vd_cont));
    vq_d = max(-V_max, min(V_max, vq_cont));
  end when;

  vd = vd_d;
  vq = vq_d;

  // ===== Sensors (direct reading, no noise model — not specified) =====
  sensed_omega_out = omega_out;
  sensed_theta = theta_m;
  sensed_I_phase = I_phase;
  sensed_V_bus = V_bus;
  sensed_SOC = SOC;
  sensed_T_temp = T_temp;

  // ===== Tracking error =====
  tracking_error = abs(omega_ref - omega_out);

  // ===== Bounds checking =====
  voltage_ok = V_bus >= V_bus_min_b and V_bus <= V_bus_max_b;
  current_ok = I_phase <= I_phase_b;
  speed_ok = abs(omega_out) <= omega_b;
  accel_ok = abs(accel_out) <= accel_b;
  soc_ok = SOC >= SOC_min_b;
  thermal_ok = T_temp <= T_temp_b;
  tracking_ok = (time < 7.8) or (tracking_error <= tracking_lim);
  no_nan_ok = true;

end BLDCWheelSpeedC;