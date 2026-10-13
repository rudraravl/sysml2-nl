model BLDCWheelTorqueC
  "BLDC wheel torque control: inner FOC current loop, outer torque feedback, compliant load contact"

  // ==================== Parameters ====================

  // Battery
  parameter Real V_bus_nom = 48.0 "Nominal bus voltage [V]";
  parameter Real R_batt = 0.05 "Battery internal resistance [Ohm]";

  // Motor electrical
  parameter Real R_motor = 0.5 "Stator phase resistance [Ohm]";
  parameter Real L_q = 0.5e-3 "Q-axis inductance [H] (surface PM: Ld=Lq)";
  parameter Real psi_f = 0.05 "PM flux linkage [Wb]";
  parameter Integer p = 4 "Number of pole pairs";
  parameter Real Kt = 1.5 * p * psi_f "Torque constant [N.m/A]";
  parameter Real I_max = 30.0 "Maximum q-axis current [A]";
  parameter Real V_max = 44.2 "Maximum inverter voltage command [V]";

  // Motor mechanical
  parameter Real J_m = 1.0e-4 "Motor rotor inertia [kg.m2]";
  parameter Real b_m = 1.0e-6 "Motor viscous friction [N.m.s/rad]";

  // Gearbox
  parameter Real n_gear = 9.0 "Gear ratio";

  // Transmission
  parameter Real k_trans = 500.0 "Transmission stiffness [N.m/rad]";
  parameter Real c_trans = 5.0 "Transmission damping [N.m.s/rad]";

  // Wheel
  parameter Real r_wheel = 0.12 "Wheel radius [m]";
  parameter Real J_w = 1.0e-3 "Wheel inertia [kg.m2]";
  parameter Real b_w = 1.0e-5 "Wheel friction [N.m.s/rad]";

  // Contact
  parameter Real k_contact = 1.0e5 "Contact stiffness [N/m]";
  parameter Real c_contact = 100.0 "Contact damping [N.s/m]";

  // Load
  parameter Real m_load = 1.0 "Load mass [kg]";
  parameter Real k_load = 5.0e4 "Load restoring stiffness [N/m]";
  parameter Real b_load = 200.0 "Load damping [N.s/m]";

  // Control
  parameter Real f_s = 125.0 "Control sampling frequency [Hz]";
  parameter Real Ts = 1.0 / f_s "Sampling period [s]";
  parameter Real T_cmd_amp = 20.0 "Torque command amplitude [N.m]";
  parameter Real T_dist = 13.5 "Disturbance torque magnitude [N.m]";
  parameter Real Kp_i = 20.0 "Current controller proportional gain";
  parameter Real Ki_i = 2000.0 "Current controller integral gain";
  parameter Real Kp_o = 0.2 "Outer torque controller proportional gain";
  parameter Real Ki_o = 1.0 "Outer torque controller integral gain";
  parameter Real T_motor_ref_max = 10.0 "Max motor torque reference [N.m]";

  // Thermal
  parameter Real R_th = 0.5 "Thermal resistance [K/W]";
  parameter Real C_th = 200.0 "Thermal capacitance [J/K]";
  parameter Real T_ambient = 25.0 "Ambient temperature [degC]";

  // ==================== State and Sensor Variables ====================

  // Electrical
  Real i_q(start = 0.0) "Q-axis current [A] -- sensor: motor current";
  Real i_q_err_int(start = 0.0) "Current error integral [A.s]";
  Real V_q "Q-axis voltage command [V]";
  Real omega_e "Electrical angular speed [rad/s]";

  // Motor mechanical
  Real theta_m(start = 0.0) "Motor angle [rad]";
  Real omega_m(start = 0.0) "Motor speed [rad/s]";
  Real T_em "Electromagnetic torque [N.m]";

  // Gearbox output — transmission input side sensor
  Real theta_g "Gearbox output angle [rad] -- sensor: transmission input side";
  Real omega_g "Gearbox output speed [rad/s]";

  // Wheel — transmission output side sensor and output state
  Real theta_w(start = 0.0) "Wheel angle [rad] -- sensor: transmission output side";
  Real omega_w(start = 0.0) "Wheel speed [rad/s] -- sensor: output state";
  Real delta_trans "Transmission deflection [rad]";
  Real T_trans "Transmission torque [N.m]";

  // Contact
  Real x_load(start = 0.0) "Load position [m]";
  Real v_load(start = 0.0) "Load velocity [m/s]";
  Real x_contact "Contact compression [m]";
  Real F_contact "Contact force [N] -- sensor: contact force";
  Real T_contact "Contact torque at wheel [N.m]";

  // Battery
  Real V_bus "Bus voltage [V]";
  Real I_bus "Bus current [A]";

  // Thermal
  Real T_motor_temp(start = 25.0) "Motor winding temperature [degC] -- sensor: temperature";
  Real Q_loss "Copper loss [W]";

  // Discrete controller (outer loop, 125 Hz)
  discrete Real T_err_int(start = 0.0) "Torque error integral [N.m.s]";
  discrete Real T_motor_ref(start = 0.0) "Motor torque reference [N.m]";
  discrete Real i_q_ref(start = 0.0) "Q-axis current reference [A]";

  // Command and disturbance
  Real T_cmd "Torque command [N.m]";
  Real T_disturbance "Disturbance torque [N.m]";

  // Measurement and tracking
  Real T_meas "Measured output torque [N.m]";
  Real tracking_error "Primary tracking error [N.m]";

  // Bound indicators (1.0 = within bound, 0.0 = violated)
  Real V_q_bound;
  Real i_q_bound;
  Real thermal_bound;
  Real trans_deflection_bound;
  Real contact_force_bound;

equation
  // --- Torque command: step at t = 1 s ---
  T_cmd = if time >= 1.0 then T_cmd_amp else 0.0;

  // --- Disturbance: 13.5 N.m during middle third (4 s to 8 s) ---
  T_disturbance = if time >= 4.0 and time < 8.0 then T_dist else 0.0;

  // --- Electrical speed and motor torque ---
  omega_e = p * omega_m;
  T_em = Kt * i_q;

  // --- q-axis electrical dynamics (FOC: Id = 0, Vd = 0) ---
  der(i_q) = (V_q - R_motor * i_q - omega_e * psi_f) / L_q;

  // --- Inner current controller (continuous PI) ---
  // Operating voltage far below V_max; anti-windup omitted for simplicity
  der(i_q_err_int) = i_q_ref - i_q;
  V_q = max(min(Kp_i * (i_q_ref - i_q) + Ki_i * i_q_err_int, V_max), -V_max);

  // --- Motor mechanical dynamics ---
  der(theta_m) = omega_m;
  der(omega_m) = (T_em - T_trans / n_gear - b_m * omega_m) / J_m;

  // --- Ideal gearbox (9:1) ---
  theta_g = theta_m / n_gear;
  omega_g = omega_m / n_gear;

  // --- Compliant transmission (spring-damper) ---
  delta_trans = theta_g - theta_w;
  T_trans = k_trans * delta_trans + c_trans * (omega_g - omega_w);

  // --- Wheel dynamics ---
  der(theta_w) = omega_w;
  der(omega_w) = (T_trans - T_contact - T_disturbance - b_w * omega_w) / J_w;

  // --- Contact model (spring-damper with rigid support geometry) ---
  x_contact = r_wheel * theta_w - x_load;
  F_contact = k_contact * x_contact + c_contact * (r_wheel * omega_w - v_load);
  T_contact = F_contact * r_wheel;

  // --- Load dynamics ---
  der(x_load) = v_load;
  der(v_load) = (F_contact - k_load * x_load - b_load * v_load) / m_load;

  // --- Output torque measurement and tracking error ---
  T_meas = T_contact;
  tracking_error = T_cmd - T_meas;

  // --- Battery with internal resistance ---
  I_bus = 1.5 * V_q * i_q / V_bus_nom;
  V_bus = V_bus_nom - R_batt * I_bus;

  // --- Thermal model (lumped copper loss) ---
  Q_loss = 1.5 * R_motor * i_q * i_q;
  der(T_motor_temp) = (Q_loss - (T_motor_temp - T_ambient) / R_th) / C_th;

  // --- Discrete outer torque controller at 125 Hz ---
  when sample(0, Ts) then
    T_err_int = pre(T_err_int) + (T_cmd - T_meas) * Ts;
    T_motor_ref = max(min(Kp_o * (T_cmd - T_meas) + Ki_o * T_err_int, T_motor_ref_max), -T_motor_ref_max);
    i_q_ref = max(min(T_motor_ref / Kt, I_max), -I_max);
  end when;

  // --- Bound checks ---
  V_q_bound = if abs(V_q) <= V_max + 0.1 then 1.0 else 0.0;
  i_q_bound = if abs(i_q) <= I_max + 1.0 then 1.0 else 0.0;
  thermal_bound = if T_motor_temp <= 120.0 then 1.0 else 0.0;
  trans_deflection_bound = if abs(delta_trans) <= 0.5 then 1.0 else 0.0;
  contact_force_bound = if abs(F_contact) <= 1000.0 then 1.0 else 0.0;

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.001),
    Documentation(info = "BLDCWheelTorqueC: 48V PM motor (4 pole pairs) driving 0.12 m wheel through 9:1 gearbox. "
      ~ "Inner continuous-PI FOC current loop; outer discrete-PI torque feedback at 125 Hz. "
      ~ "Compliant transmission and spring-damper contact with load. "
      ~ "13.5 N.m disturbance applied during middle third (4-8 s). "
      ~ "Tracking error target < 2.1 N.m after 7.8 s. "
      ~ "Sensors: motor current, transmission both sides, output state, contact force, temperature."));
end BLDCWheelTorqueC;