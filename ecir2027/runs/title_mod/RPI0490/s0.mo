model DCServoSpeedD
  "Instrumented electromechanical robotic actuator: 48V PMDC motor, 100:1 gearbox, current-limited speed control"

  // === Motor electrical parameters ===
  parameter Real V_nominal = 48.0 "Nominal DC bus voltage [V]";
  parameter Real R_motor = 0.8 "Armature resistance [Ohm]";
  parameter Real L_motor = 0.01 "Armature inductance [H]";
  parameter Real Kt = 0.05 "Torque constant [N.m/A]";
  parameter Real Ke = 0.05 "Back-EMF constant [V.s/rad]";

  // === Motor mechanical parameters ===
  parameter Real J_rotor = 1.0e-5 "Rotor inertia [kg.m2]";
  parameter Real b_motor = 1.0e-6 "Motor viscous friction [N.m.s/rad]";

  // === Gearbox parameters ===
  parameter Real N_gear = 100.0 "Gear ratio (motor:output)";
  parameter Real eta_gear = 0.9 "Gearbox efficiency [1]";

  // === Load parameters ===
  parameter Real J_load = 0.1 "Load (revolute link) inertia [kg.m2]";
  parameter Real b_load = 0.02 "Load viscous friction [N.m.s/rad]";

  // === Battery parameters ===
  parameter Real R_batt = 0.05 "Battery internal resistance [Ohm]";
  parameter Real C_batt = 10000.0 "Battery capacity [A.s]";
  parameter Real SOC_init = 1.0 "Initial state of charge [1]";

  // === Thermal parameters ===
  parameter Real R_th = 1.0 "Thermal resistance [K/W]";
  parameter Real C_th = 60.0 "Thermal capacitance [J/K]";
  parameter Real T_ambient = 25.0 "Ambient temperature [degC]";

  // === Controller parameters ===
  parameter Real Kp_speed = 5.0 "Speed controller proportional gain [A.s/rad]";
  parameter Real Ki_speed = 100.0 "Speed controller integral gain [A/(rad/s)]";
  parameter Real K_aw = 1.0 "Anti-windup gain [1]";

  // === Command profile ===
  parameter Real omega_ref_output = 5.0 "Declared output speed reference [rad/s]";
  parameter Real t_accel_end = 2.0 "End of acceleration phase [s]";
  parameter Real t_hold_end = 10.0 "End of hold phase [s]";
  parameter Real t_decel_end = 12.0 "End of deceleration phase [s]";

  // === Disturbance ===
  parameter Real T_load_dist = 12.0 "Load disturbance torque magnitude [N.m]";
  parameter Real t_dist_start = 14.0 / 3.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 28.0 / 3.0 "Disturbance end (middle third) [s]";
  parameter Real t_dist_ramp = 0.2 "Disturbance ramp time [s]";

  // === Bounds ===
  parameter Real V_max = 48.0 "Voltage bound [V]";
  parameter Real I_max = 48.0 "Current bound [A]";
  parameter Real T_max = 80.0 "Thermal bound [degC]";
  parameter Real SOC_min = 0.05 "Minimum state of charge [1]";
  parameter Real omega_motor_bound = 1000.0 "Motor speed bound [rad/s]";
  parameter Real omega_output_bound = 20.0 "Output speed bound [rad/s]";
  parameter Real acc_bound = 500.0 "Output acceleration bound [rad/s2]";

  // === Dynamic states ===
  Real i_arm(start = 0.0, fixed = true) "Armature current [A]";
  Real omega_motor(start = 0.0, fixed = true) "Rotor angular velocity [rad/s]";
  Real theta_motor(start = 0.0, fixed = true) "Rotor position [rad]";
  Real SOC(start = SOC_init, fixed = true) "Battery state of charge [1]";
  Real T_winding(start = T_ambient, fixed = true) "Winding temperature [degC]";
  Real integral_error(start = 0.0, fixed = true) "Integral of speed tracking error [rad/s]";

  // === Computed (algebraic) variables ===
  Real omega_output "Output speed [rad/s]";
  Real theta_output "Output position [rad]";
  Real accel_output "Output acceleration [rad/s2]";
  Real omega_ref "Speed reference command [rad/s]";
  Real tracking_error "Primary tracking error [rad/s]";
  Real I_command_raw "Raw current command [A]";
  Real I_limited "Current-limited command [A]";
  Real V_command "Voltage command [V]";
  Real V_applied "Applied motor voltage [V]";
  Real V_bus "Sensed DC bus voltage [V]";
  Real T_motor "Motor electromagnetic torque [N.m]";
  Real T_load_applied "Applied load disturbance torque [N.m]";
  Real J_total_motor "Total reflected inertia at motor side [kg.m2]";
  Real aw_error "Anti-windup correction [A]";
  Real V_saturated "Voltage saturation indicator [1]";
  Real I_saturated "Current saturation indicator [1]";

  // === Sensor outputs (explicit instrumentation) ===
  Real i_arm_meas = i_arm "Measured armature current [A]";
  Real theta_motor_meas = theta_motor "Measured rotor position [rad]";
  Real omega_output_meas = omega_output "Measured output speed [rad/s]";
  Real V_bus_meas = V_bus "Measured DC bus voltage [V]";

equation
  // === Speed reference: trapezoidal profile ===
  // Accelerate 0-2s, hold 2-10s, decelerate 10-12s, rest 12-14s
  omega_ref = if time < t_accel_end then
                omega_ref_output * time / t_accel_end
              else if time < t_hold_end then
                omega_ref_output
              else if time < t_decel_end then
                omega_ref_output * (t_decel_end - time) / (t_decel_end - t_hold_end)
              else
                0.0;

  // === Load torque disturbance: ramped, applied during middle third of 14 s ===
  T_load_applied = if time < t_dist_start then
                     0.0
                   else if time < t_dist_start + t_dist_ramp then
                     T_load_dist * (time - t_dist_start) / t_dist_ramp
                   else if time < t_dist_end - t_dist_ramp then
                     T_load_dist
                   else if time < t_dist_end then
                     T_load_dist * (t_dist_end - time) / t_dist_ramp
                   else
                     0.0;

  // === Primary tracking error ===
  tracking_error = omega_ref - omega_output;

  // === Current-limited PI speed controller with anti-windup ===
  I_command_raw = Kp_speed * tracking_error + Ki_speed * integral_error;
  I_limited = max(-I_max, min(I_max, I_command_raw));
  aw_error = I_limited - I_command_raw;
  der(integral_error) = tracking_error + K_aw * aw_error;
  I_saturated = if abs(I_command_raw) >= I_max then 1.0 else 0.0;

  // === Voltage command (resistive + back-EMF feedforward) with independent saturation ===
  V_command = R_motor * I_limited + Ke * omega_motor;
  V_applied = max(-V_max, min(V_max, V_command));
  V_saturated = if abs(V_command) > V_max then 1.0 else 0.0;

  // === Battery model with droop and state-of-charge ===
  V_bus = V_nominal * SOC - R_batt * i_arm;
  der(SOC) = -i_arm / C_batt;

  // === Motor electrical dynamics ===
  L_motor * der(i_arm) = V_applied - R_motor * i_arm - Ke * omega_motor;

  // === Motor torque ===
  T_motor = Kt * i_arm;

  // === Reflected inertia at motor side ===
  J_total_motor = J_rotor + J_load / (N_gear * N_gear);

  // === Mechanical dynamics (motor side) ===
  // Gearbox efficiency reduces torque transmitted from output to motor
  J_total_motor * der(omega_motor) = T_motor
    - b_motor * omega_motor
    - (T_load_applied + b_load * omega_output) / (N_gear * eta_gear);

  der(theta_motor) = omega_motor;

  // === Output kinematics ===
  omega_output = omega_motor / N_gear;
  der(theta_output) = omega_output;
  accel_output = der(omega_motor) / N_gear;

  // === Thermal model (lumped winding temperature) ===
  C_th * der(T_winding) = i_arm * i_arm * R_motor - (T_winding - T_ambient) / R_th;

  // === Bounds assertions ===
  assert(T_winding <= T_max, "Thermal bound exceeded", AssertionLevel.warning);
  assert(SOC >= SOC_min, "State of charge below minimum", AssertionLevel.warning);
  assert(abs(omega_motor) <= omega_motor_bound, "Motor speed bound exceeded", AssertionLevel.warning);
  assert(abs(omega_output) <= omega_output_bound, "Output speed bound exceeded", AssertionLevel.warning);
  assert(abs(accel_output) <= acc_bound, "Acceleration bound exceeded", AssertionLevel.warning);

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "DC servo speed control system DCServoSpeedD.
    48V PMDC motor with explicit resistance (0.8 Ohm), inductance (0.01 H), torque constant (0.05 N.m/A),
    rotor inertia (1e-5 kg.m2), and lumped thermal state driving a revolute link through a 100:1 gearbox
    (efficiency 0.9). Voltage and current independently saturated at 48 V and 48 A.
    Current-limited PI speed regulation with back-EMF feedforward and anti-windup.
    Battery droop model with state-of-charge tracking. Mechanical friction (viscous) at motor and load.
    12 N.m load torque disturbance (ramped 0.2 s) applied during middle third (4.667-9.333 s).
    Simulation at 200 Hz (5 ms interval) for 14 s.
    Tracking error requirement: below 0.25 rad/s after 9.1 s.
    Instrumented outputs: armature current, rotor position, output speed, DC-bus voltage."),
    uses(Modelica(version = "4.0.0"))
  );
end DCServoSpeedD;