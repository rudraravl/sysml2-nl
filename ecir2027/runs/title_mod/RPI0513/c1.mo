model BLDCWheelSpeedC
  "Electromechanical robotic actuator: BLDC/PMSM wheel speed control with field-oriented current regulation"

  // ============ SPECIFIED PARAMETERS ============
  parameter Real V_max = 44.2 "Maximum command magnitude [V-DC-bus]";
  parameter Real T_load_dist = 10.8 "Load torque disturbance [N.m]";
  parameter Real V_oc_nom = 48.0 "Battery nominal voltage [V]";
  parameter Integer p = 4 "Pole pairs";
  parameter Real N = 9.0 "Gear ratio (motor:wheel)";
  parameter Real r_wheel = 0.12 "Wheel radius [m]";

  // ============ DECLARED OUTPUT SPEED ============
  parameter Real v_ref_hold = 6.0 "Declared output speed to hold [m/s]";

  // ============ ASSUMED MOTOR PARAMETERS ============
  parameter Real Rs = 0.10 "Stator resistance [Ohm] (assumed)";
  parameter Real Lq = 0.5e-3 "q-axis inductance [H] (assumed)";
  parameter Real psi_f = 0.01 "PM flux linkage [Wb] (assumed)";
  parameter Real J_motor = 1.0e-3 "Rotor inertia [kg.m2] (assumed)";
  parameter Real B_motor = 0.5e-3 "Motor viscous friction [N.m.s/rad] (assumed)";
  parameter Real kt = 1.5 * p * psi_f "Torque constant [N.m/A]";

  // ============ ASSUMED GEARBOX/WHEEL/VEHICLE ============
  parameter Real eta_gb = 0.90 "Gearbox efficiency (assumed)";
  parameter Real J_wheel = 0.010 "Wheel inertia [kg.m2] (assumed)";
  parameter Real B_wheel = 0.010 "Wheel bearing friction [N.m.s/rad] (assumed)";
  parameter Real m_vehicle = 5.0 "Equivalent reflected vehicle mass [kg] (assumed)";

  // ============ ASSUMED BATTERY ============
  parameter Real R_int = 0.05 "Battery internal resistance [Ohm] (assumed)";
  parameter Real Q_bat = 18000.0 "Battery capacity [C] = 5 Ah (assumed)";
  parameter Real SoC_init = 1.0 "Initial state of charge";
  parameter Real SoC_min = 0.10 "Minimum SOC bound";

  // ============ ASSUMED THERMAL ============
  parameter Real R_th = 2.0 "Thermal resistance [K/W] (assumed)";
  parameter Real C_th = 100.0 "Thermal capacitance [J/K] (assumed)";
  parameter Real Temp_max = 80.0 "Max temperature rise [K] (assumed)";

  // ============ ASSUMED CONTROL ============
  parameter Real I_max = 40.0 "Maximum phase current [A] (assumed)";
  parameter Real Kp_speed = 5.0 "Speed PI proportional gain";
  parameter Real Ki_speed = 50.0 "Speed PI integral gain";
  parameter Real Kp_curr = 0.5 "Current PI proportional gain";
  parameter Real Ki_curr = 200.0 "Current PI integral gain";

  // ============ ASSUMED BOUNDS ============
  parameter Real I_bound = 40.0 "Current bound [A] (assumed)";
  parameter Real v_bound = 10.0 "Speed bound [m/s] (assumed)";
  parameter Real a_bound = 20.0 "Acceleration bound [m/s2] (assumed)";

  // ============ TIMING ============
  parameter Real t_accel_end = 3.0 "End of acceleration [s]";
  parameter Real t_hold_end = 8.0 "End of hold / start decel [s]";
  parameter Real t_sim_end = 12.0 "Total simulation time [s]";
  parameter Real t_dist_start = 4.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end [s]";

  // ============ STATES ============
  Real iq(start = 0.0) "q-axis current [A]";
  Real omega_motor(start = 0.0) "Motor angular speed [rad/s]";
  Real theta_motor(start = 0.0) "Motor rotor position [rad]";
  Real SOC(start = SoC_init) "Battery state of charge [0..1]";
  Real Temp(start = 0.0) "Motor temperature rise above ambient [K]";
  Real speed_int(start = 0.0) "Speed controller integrator state";
  Real curr_int(start = 0.0) "Current controller integrator state";

  // ============ ALGEBRAIC VARIABLES ============
  Real id "d-axis current [A]";
  Real vd "d-axis voltage [V]";
  Real vq "q-axis voltage [V]";
  Real vq_cmd_raw "Unsaturated voltage command [V]";
  Real T_motor "Motor electromagnetic torque [N.m]";
  Real omega_wheel "Wheel angular speed [rad/s]";
  Real theta_wheel "Wheel position [rad]";
  Real v_out "Output linear speed [m/s]";
  Real a_out "Output linear acceleration [m/s2]";
  Real T_load "Load torque at wheel [N.m]";
  Boolean disturbance_active "Load disturbance active flag";

  // Reference
  Real v_ref "Reference output speed [m/s]";
  Real omega_ref "Reference wheel speed [rad/s]";

  // Controller
  Real speed_err "Speed tracking error [rad/s]";
  Real iq_ref_raw "Unsaturated current reference [A]";
  Real iq_ref "Saturated current reference [A]";
  Real curr_err "Current error [A]";

  // Battery
  Real V_bus "DC bus voltage [V]";
  Real I_bus "Battery current [A]";
  Real P_elec "Electrical power [W]";
  Real P_cu "Copper loss [W]";

  // Sensors
  Real I_armature "Armature current magnitude [A]";
  Real I_phase_rms "RMS phase current [A]";
  Real tracking_error "Wheel speed tracking error [rad/s]";
  Real tracking_error_ms "Linear speed tracking error [m/s]";

  // Equivalent parameters
  Real J_eq "Equivalent inertia at motor shaft [kg.m2]";
  Real B_eq "Equivalent friction at motor shaft [N.m.s/rad]";
  Real T_load_eq "Reflected load torque at motor [N.m]";

  // Bounds checks
  Boolean voltage_ok "Voltage within bounds";
  Boolean current_ok "Current within bounds";
  Boolean speed_ok "Speed within bounds";
  Boolean accel_ok "Acceleration within bounds";
  Boolean soc_ok "SOC within bounds";
  Boolean thermal_ok "Temperature within bounds";

initial equation
  iq = 0.0;
  omega_motor = 0.0;
  theta_motor = 0.0;
  SOC = SoC_init;
  Temp = 0.0;
  speed_int = 0.0;
  curr_int = 0.0;

equation
  // === Equivalent mechanical parameters at motor shaft ===
  J_eq = J_motor + (J_wheel + m_vehicle * r_wheel * r_wheel) / (N * N);
  B_eq = B_motor + B_wheel / (N * N);
  T_load_eq = T_load / (N * eta_gb);

  // === Speed reference: accelerate, hold, decelerate ===
  if time < t_accel_end then
    v_ref = v_ref_hold * time / t_accel_end;
  elseif time < t_hold_end then
    v_ref = v_ref_hold;
  elseif time < t_sim_end then
    v_ref = v_ref_hold * (t_sim_end - time) / (t_sim_end - t_hold_end);
  else
    v_ref = 0.0;
  end if;
  omega_ref = v_ref / r_wheel;

  // === Load disturbance: middle third (4-8 s) ===
  disturbance_active = time >= t_dist_start and time < t_dist_end;
  T_load = if disturbance_active then T_load_dist else 0.0;

  // === Speed controller (PI with clamping anti-windup) ===
  speed_err = omega_ref - omega_wheel;
  iq_ref_raw = Kp_speed * speed_err + Ki_speed * speed_int;
  iq_ref = if iq_ref_raw > I_max then I_max
    elseif iq_ref_raw < (-I_max) then -I_max
    else iq_ref_raw;
  der(speed_int) = if (iq_ref_raw > I_max and speed_err > 0.0) or
                      (iq_ref_raw < (-I_max) and speed_err < 0.0) then 0.0
    else speed_err;

  // === Current controller (PI with clamping anti-windup) ===
  curr_err = iq_ref - iq;
  vq_cmd_raw = Kp_curr * curr_err + Ki_curr * curr_int;
  vq = if vq_cmd_raw > V_max then V_max
    elseif vq_cmd_raw < (-V_max) then -V_max
    else vq_cmd_raw;
  der(curr_int) = if (vq_cmd_raw > V_max and curr_err > 0.0) or
                     (vq_cmd_raw < (-V_max) and curr_err < 0.0) then 0.0
    else curr_err;

  // === FOC: id = 0 strategy ===
  id = 0.0;
  vd = -p * omega_motor * Lq * iq;

  // === Motor electrical dynamics (q-axis) ===
  Lq * der(iq) = vq - Rs * iq - p * omega_motor * psi_f;

  // === Motor torque ===
  T_motor = kt * iq;

  // === Mechanical dynamics (combined at motor shaft) ===
  J_eq * der(omega_motor) = T_motor - B_eq * omega_motor - T_load_eq;

  // === Rotor position ===
  der(theta_motor) = omega_motor;
  theta_wheel = theta_motor / N;

  // === Wheel kinematics ===
  omega_wheel = omega_motor / N;
  v_out = omega_wheel * r_wheel;
  a_out = r_wheel * (T_motor - B_eq * omega_motor - T_load_eq) / (J_eq * N);

  // === Battery model with internal resistance droop ===
  P_elec = 1.5 * (vq * iq + vd * id);
  V_bus = (V_oc_nom + sqrt(max(0.0, V_oc_nom * V_oc_nom - 4.0 * R_int * P_elec))) / 2.0;
  I_bus = if abs(V_bus) > 1e-6 then P_elec / V_bus else 0.0;

  // === State of charge ===
  der(SOC) = -I_bus / Q_bat;

  // === Thermal model ===
  P_cu = 1.5 * Rs * (iq * iq + id * id);
  C_th * der(Temp) = P_cu - Temp / R_th;

  // === Sensors ===
  I_armature = sqrt(iq * iq + id * id);
  I_phase_rms = I_armature / sqrt(2.0);
  tracking_error = omega_ref - omega_wheel;
  tracking_error_ms = v_ref - v_out;

  // === Bounds checks ===
  voltage_ok = abs(vq) <= V_max + 0.01;
  current_ok = abs(iq) <= I_bound + 0.01;
  speed_ok = abs(v_out) <= v_bound + 0.01;
  accel_ok = abs(a_out) <= a_bound + 0.01;
  soc_ok = SOC >= SoC_min;
  thermal_ok = Temp <= Temp_max + 0.01;

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "BLDC/PMSM wheel speed control with field-oriented current regulation. 48V battery, 4 pole pairs, 9:1 gearbox, 0.12m wheel. Max command 44.2V. Load disturbance 10.8 N.m during middle third 4-8s. Speed profile accelerate 0-3s hold 3-8s decelerate 8-12s. Run at 125 Hz for 12 s. Parameters not specified in requirements are labeled assumed.")
  );
end BLDCWheelSpeedC;