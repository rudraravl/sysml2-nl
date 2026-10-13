model BLDCWheelSpeedC
  "BLDC/PMSM wheel speed control with field-oriented current regulation"

  // ============ SPECIFIED PARAMETERS ============
  parameter Real V_max = 44.2 "Maximum command magnitude [V]";
  parameter Real T_load_dist = 10.8 "Load torque disturbance [N.m]";
  parameter Real V_oc_nom = 48.0 "Battery nominal voltage [V]";
  parameter Real n_pp = 4.0 "Pole pairs";
  parameter Real gear_ratio = 9.0 "Gear ratio";
  parameter Real r_wheel = 0.12 "Wheel radius [m]";
  parameter Real v_ref_hold = 6.0 "Declared output speed to hold [m/s]";

  // ============ MOTOR PARAMETERS (assumed) ============
  parameter Real Rs = 0.10 "Stator resistance [Ohm]";
  parameter Real Lq = 0.5e-3 "q-axis inductance [H]";
  parameter Real psi_f = 0.01 "PM flux linkage [Wb]";
  parameter Real J_motor = 1.0e-3 "Rotor inertia [kg.m2]";
  parameter Real B_motor = 0.5e-3 "Motor viscous friction [N.m.s/rad]";
  parameter Real kt = 1.5 * n_pp * psi_f "Torque constant [N.m/A]";

  // ============ GEARBOX / WHEEL / VEHICLE (assumed) ============
  parameter Real eta_gb = 0.90 "Gearbox efficiency";
  parameter Real J_wheel = 0.010 "Wheel inertia [kg.m2]";
  parameter Real B_wheel = 0.010 "Wheel bearing friction [N.m.s/rad]";
  parameter Real m_vehicle = 5.0 "Equivalent reflected vehicle mass [kg]";

  // ============ BATTERY (assumed) ============
  parameter Real R_int = 0.05 "Battery internal resistance [Ohm]";
  parameter Real Q_bat = 18000.0 "Battery capacity [C] = 5 Ah";
  parameter Real SoC_init = 1.0 "Initial state of charge";

  // ============ THERMAL (assumed) ============
  parameter Real R_th = 2.0 "Thermal resistance [K/W]";
  parameter Real C_th = 100.0 "Thermal capacitance [J/K]";

  // ============ CONTROL (assumed) ============
  parameter Real I_max = 40.0 "Maximum phase current [A]";
  parameter Real Kp_speed = 5.0 "Speed controller proportional gain";
  parameter Real Ki_speed = 50.0 "Speed controller integral gain";
  parameter Real Kp_curr = 0.5 "Current controller proportional gain";
  parameter Real Ki_curr = 200.0 "Current controller integral gain";

  // ============ TIMING ============
  parameter Real t_accel_end = 3.0 "End of acceleration [s]";
  parameter Real t_hold_end = 8.0 "End of hold / start decel [s]";
  parameter Real t_sim_end = 12.0 "Total simulation time [s]";
  parameter Real t_dist_start = 4.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end [s]";

  // ============ DYNAMIC STATES ============
  Real iq(start = 0.0, fixed = true) "q-axis current [A]";
  Real omega_motor(start = 0.0, fixed = true) "Motor angular speed [rad/s]";
  Real theta_motor(start = 0.0, fixed = true) "Motor rotor position [rad]";
  Real SOC(start = 1.0, fixed = true) "Battery state of charge [0..1]";
  Real Temp(start = 0.0, fixed = true) "Motor temperature rise above ambient [K]";
  Real speed_int(start = 0.0, fixed = true) "Speed controller integrator state";
  Real curr_int(start = 0.0, fixed = true) "Current controller integrator state";

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
  Real v_ref "Reference output speed [m/s]";
  Real omega_ref "Reference wheel speed [rad/s]";
  Real speed_err "Speed tracking error [rad/s]";
  Real iq_ref_raw "Unsaturated current reference [A]";
  Real iq_ref "Saturated current reference [A]";
  Real curr_err "Current error [A]";
  Real V_bus "DC bus voltage [V]";
  Real I_bus "Battery current [A]";
  Real P_elec "Electrical power [W]";
  Real P_cu "Copper loss [W]";
  Real I_armature "Armature current magnitude [A]";
  Real I_phase_rms "RMS phase current [A]";
  Real tracking_error "Wheel speed tracking error [rad/s]";
  Real J_eq "Equivalent inertia at motor shaft [kg.m2]";
  Real B_eq "Equivalent friction at motor shaft [N.m.s/rad]";
  Real T_load_eq "Reflected load torque at motor [N.m]";
  Real speed_int_der "Speed integrator derivative";
  Real curr_int_der "Current integrator derivative";
  Real speed_aw "Speed anti-windup flag";
  Real curr_aw "Current anti-windup flag";

  // ============ BOUNDS CHECKS (1.0 = OK, 0.0 = violated) ============
  Real voltage_ok;
  Real current_ok;
  Real speed_ok;
  Real accel_ok;
  Real soc_ok;
  Real thermal_ok;

equation
  // === Equivalent mechanical parameters at motor shaft ===
  J_eq = J_motor + (J_wheel + m_vehicle * r_wheel * r_wheel) / (gear_ratio * gear_ratio);
  B_eq = B_motor + B_wheel / (gear_ratio * gear_ratio);
  T_load_eq = T_load / (gear_ratio * eta_gb);

  // === Speed reference: accelerate, hold, decelerate ===
  v_ref = if time < t_accel_end then v_ref_hold * time / t_accel_end
    else if time < t_hold_end then v_ref_hold
    else if time < t_sim_end then v_ref_hold * (t_sim_end - time) / (t_sim_end - t_hold_end)
    else 0.0;
  omega_ref = v_ref / r_wheel;

  // === Load disturbance: middle third (4-8 s) ===
  T_load = if time >= t_dist_start and time < t_dist_end then T_load_dist else 0.0;

  // === Speed controller (PI with clamping anti-windup) ===
  speed_err = omega_ref - omega_wheel;
  iq_ref_raw = Kp_speed * speed_err + Ki_speed * speed_int;
  iq_ref = if iq_ref_raw > I_max then I_max else if iq_ref_raw < (-I_max) then -I_max else iq_ref_raw;
  speed_aw = if (iq_ref_raw > I_max and speed_err > 0.0) or (iq_ref_raw < (-I_max) and speed_err < 0.0) then 1.0 else 0.0;
  speed_int_der = if speed_aw > 0.5 then 0.0 else speed_err;
  der(speed_int) = speed_int_der;

  // === Current controller (PI with clamping anti-windup) ===
  curr_err = iq_ref - iq;
  vq_cmd_raw = Kp_curr * curr_err + Ki_curr * curr_int;
  vq = if vq_cmd_raw > V_max then V_max else if vq_cmd_raw < (-V_max) then -V_max else vq_cmd_raw;
  curr_aw = if (vq_cmd_raw > V_max and curr_err > 0.0) or (vq_cmd_raw < (-V_max) and curr_err < 0.0) then 1.0 else 0.0;
  curr_int_der = if curr_aw > 0.5 then 0.0 else curr_err;
  der(curr_int) = curr_int_der;

  // === FOC: id = 0 strategy ===
  id = 0.0;
  vd = -n_pp * omega_motor * Lq * iq;

  // === Motor electrical dynamics (q-axis) ===
  Lq * der(iq) = vq - Rs * iq - n_pp * omega_motor * psi_f;

  // === Motor torque ===
  T_motor = kt * iq;

  // === Mechanical dynamics (combined at motor shaft) ===
  J_eq * der(omega_motor) = T_motor - B_eq * omega_motor - T_load_eq;

  // === Rotor position ===
  der(theta_motor) = omega_motor;
  theta_wheel = theta_motor / gear_ratio;

  // === Wheel kinematics ===
  omega_wheel = omega_motor / gear_ratio;
  v_out = omega_wheel * r_wheel;
  a_out = r_wheel * (T_motor - B_eq * omega_motor - T_load_eq) / (J_eq * gear_ratio);

  // === Battery model with internal resistance droop ===
  P_elec = 1.5 * (vq * iq + vd * id);
  I_bus = if V_oc_nom > 0.1 then P_elec / V_oc_nom else 0.0;
  V_bus = V_oc_nom - R_int * I_bus;

  // === State of charge ===
  der(SOC) = -I_bus / Q_bat;

  // === Thermal model ===
  P_cu = 1.5 * Rs * (iq * iq + id * id);
  C_th * der(Temp) = P_cu - Temp / R_th;

  // === Sensors ===
  I_armature = sqrt(iq * iq + id * id);
  I_phase_rms = I_armature / 1.41421356237;
  tracking_error = omega_ref - omega_wheel;

  // === Bounds checks ===
  voltage_ok = if vq > V_max then 0.0 elseif vq < (-V_max) then 0.0 else 1.0;
  current_ok = if iq > I_max then 0.0 elseif iq < (-I_max) then 0.0 else 1.0;
  speed_ok = if v_out > 10.0 then 0.0 elseif v_out < (-10.0) then 0.0 else 1.0;
  accel_ok = if a_out > 20.0 then 0.0 elseif a_out < (-20.0) then 0.0 else 1.0;
  soc_ok = if SOC < 0.10 then 0.0 else 1.0;
  thermal_ok = if Temp > 80.0 then 0.0 else 1.0;

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "BLDC/PMSM wheel speed control with field-oriented current regulation. "
      "48V battery, 4 pole pairs, 9:1 gearbox, 0.12m wheel. "
      "Max command 44.2V. Load disturbance 10.8 N.m during middle third (4-8s). "
      "Speed profile: accelerate 0-3s, hold 3-8s, decelerate 8-12s. "
      "Run at 125 Hz (dt=0.008s) for 12 s. "
      "Parameters not specified in requirements are labeled assumed.")
  );
end BLDCWheelSpeedC;