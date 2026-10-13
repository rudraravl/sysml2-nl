model BLDCWheelTorqueC
  "BLDC wheel torque control: inner FOC current loop with outer force feedback"

  // --- Electrical parameters ---
  parameter Real V_bus_nominal = 48.0 "Nominal battery voltage [V]";
  parameter Real V_cmd_max = 44.2 "Maximum voltage command magnitude [V]";
  parameter Real R_batt = 0.05 "Battery internal resistance [Ohm]";
  parameter Real R_phase = 0.18 "Motor phase resistance [Ohm]";
  parameter Real L_phase = 0.0008 "Motor phase inductance [H]";
  parameter Real Ke = 0.025 "Back-EMF constant [V/(rad/s)]";
  parameter Real Kt = 0.025 "Torque constant [N.m/A]";
  parameter Integer p = 4 "Number of pole pairs";

  // --- Mechanical parameters ---
  parameter Real J_motor = 1.0e-5 "Motor inertia [kg.m2]";
  parameter Real b_motor = 1.0e-6 "Motor viscous friction [N.m.s/rad]";
  parameter Real gear_ratio = 9.0 "Gearbox ratio";
  parameter Real eta_gear = 0.92 "Gearbox efficiency";
  parameter Real J_wheel = 0.002 "Wheel inertia [kg.m2]";
  parameter Real r_wheel = 0.12 "Wheel radius [m]";
  parameter Real b_wheel = 0.001 "Wheel viscous friction [N.m.s/rad]";

  // --- Compliance and contact ---
  parameter Real k_trans = 5000.0 "Transmission stiffness [N.m/rad]";
  parameter Real c_trans = 20.0 "Transmission damping [N.m.s/rad]";
  parameter Real k_contact = 10000.0 "Contact stiffness [N/m]";
  parameter Real c_contact = 50.0 "Contact damping [N.s/m]";
  parameter Real x_gap = 0.0 "Initial contact gap [m]";

  // --- Load ---
  parameter Real m_load = 5.0 "Load mass [kg]";
  parameter Real k_load = 2000.0 "Load spring stiffness [N/m]";
  parameter Real c_load = 30.0 "Load damping [N.s/m]";

  // --- Controller gains ---
  parameter Real Kp_i = 50.0 "Current loop proportional gain";
  parameter Real Ki_i = 5000.0 "Current loop integral gain";
  parameter Real Kp_f = 40.0 "Force loop proportional gain";
  parameter Real Ki_f = 200.0 "Force loop integral gain";

  // --- Thermal ---
  parameter Real Rth = 1.5 "Thermal resistance [K/W]";
  parameter Real Cth = 50.0 "Thermal capacitance [J/K]";
  parameter Real T_ambient = 25.0 "Ambient temperature [degC]";

  // --- Disturbance and command ---
  parameter Real F_dist = 13.5 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end time [s]";
  parameter Real F_cmd_amp = 20.0 "Force command amplitude [N]";
  parameter Real t_cmd_step = 1.0 "Command step time [s]";

  // --- Simulation ---
  parameter Real dt_sample = 1.0 / 125.0 "Controller sample period [s]";

  // --- Dynamic states ---
  Real i_q(start = 0.0) "q-axis current [A]";
  Real i_d(start = 0.0) "d-axis current [A]";
  Real omega_m(start = 0.0) "Motor angular velocity [rad/s]";
  Real theta_m(start = 0.0) "Motor angle [rad]";
  Real theta_wheel(start = 0.0) "Wheel angle [rad]";
  Real omega_wheel(start = 0.0) "Wheel angular velocity [rad/s]";
  Real x_load(start = 0.0) "Load position [m]";
  Real v_load(start = 0.0) "Load velocity [m/s]";
  Real integ_i(start = 0.0) "Current integrator state";
  Real integ_f(start = 0.0) "Force integrator state";
  Real T_motor_winding(start = 25.0) "Winding temperature [degC]";

  // --- Algebraic variables ---
  Real omega_e "Electrical angular velocity [rad/s]";
  Real T_motor "Motor electromagnetic torque [N.m]";
  Real T_trans "Transmission torque [N.m]";
  Real T_gear_out "Gearbox output torque [N.m]";
  Real F_contact "Contact force [N]";
  Real F_load_spring "Load restoring force [N]";
  Real V_bus "DC bus voltage [V]";
  Real I_bus "DC bus current [A]";
  Real V_q "q-axis voltage command [V]";
  Real V_d "d-axis voltage command [V]";
  Real V_q_raw "Unclamped q-axis voltage [V]";
  Real V_d_raw "Unclamped d-axis voltage [V]";
  Real F_cmd "Force command [N]";
  Real F_meas "Measured contact force [N]";
  Real F_err "Force tracking error [N]";
  Real i_q_cmd "q-axis current command [A]";
  Real i_err "Current tracking error [A]";
  Real F_disturbance "Disturbance force [N]";
  Real x_trans_deflection "Transmission deflection [rad]";
  Real x_wheel "Wheel linear position [m]";
  Real v_wheel "Wheel linear velocity [m/s]";
  Real contact_penetration "Contact penetration depth [m]";
  Real contact_penetration_vel "Contact penetration velocity [m/s]";
  Real P_loss_copper "Copper loss [W]";
  Real P_loss_total "Total power loss [W]";

  // --- Sensor traces ---
  Real sens_motor_current "Motor current sensor [A]";
  Real sens_trans_in_torque "Transmission input-side torque [N.m]";
  Real sens_trans_out_torque "Transmission output-side torque [N.m]";
  Real sens_output_position "Output position [m]";
  Real sens_output_velocity "Output velocity [m/s]";
  Real sens_contact_force "Contact force sensor [N]";
  Real sens_temperature "Temperature sensor [degC]";

  // --- Performance metrics and bounds ---
  Real tracking_error "Primary tracking error [N]";
  Boolean tracking_ok "Tracking within 2.1 N after 7.8 s";
  Real max_current_abs "Instantaneous motor current magnitude [A]";
  Real max_temperature "Instantaneous winding temperature [degC]";
  Real max_trans_deflection "Instantaneous transmission deflection magnitude [rad]";
  Real max_contact_force "Instantaneous contact force magnitude [N]";

equation
  // === Command generation ===
  F_cmd = F_cmd_amp * (if time >= t_cmd_step then 1.0 else 0.0);

  // === Disturbance injection (middle third: 4 s to 8 s) ===
  F_disturbance = F_dist * (if time >= t_dist_start and time < t_dist_end then 1.0 else 0.0);

  // === Outer force feedback loop ===
  F_meas = F_contact;
  F_err = F_cmd - F_meas;
  der(integ_f) = F_err;
  i_q_cmd = Kp_f * F_err + Ki_f * integ_f;

  // === Inner current loop (field-oriented q-axis) ===
  i_err = i_q_cmd - i_q;
  der(integ_i) = i_err;
  V_q_raw = Kp_i * i_err + Ki_i * integ_i;
  // d-axis regulated to zero (simple proportional)
  V_d_raw = -Kp_i * i_d;

  // Voltage saturation at maximum command magnitude
  V_q = noEvent(if V_q_raw > V_cmd_max then V_cmd_max
           elseif V_q_raw < -V_cmd_max then -V_cmd_max
           else V_q_raw);
  V_d = noEvent(if V_d_raw > V_cmd_max then V_cmd_max
           elseif V_d_raw < -V_cmd_max then -V_cmd_max
           else V_d_raw);

  // === Battery model with internal resistance ===
  I_bus = (T_motor * omega_m + R_phase * (i_q * i_q + i_d * i_d)) / noEvent(max(abs(V_bus_nominal), 1.0));
  V_bus = V_bus_nominal - R_batt * I_bus;

  // === Motor electrical dynamics (rotor reference frame) ===
  omega_e = p * omega_m;
  L_phase * der(i_d) = V_d - R_phase * i_d + omega_e * L_phase * i_q;
  L_phase * der(i_q) = V_q - R_phase * i_q - omega_e * L_phase * i_d - Ke * omega_m;

  // === Motor torque and mechanical dynamics ===
  T_motor = Kt * i_q;
  J_motor * der(omega_m) = T_motor - b_motor * omega_m - T_trans / gear_ratio;
  der(theta_m) = omega_m;

  // === Gearbox ===
  T_gear_out = T_trans * eta_gear;

  // === Transmission compliance (both sides instrumented) ===
  x_trans_deflection = theta_m / gear_ratio - theta_wheel;
  T_trans = k_trans * x_trans_deflection + c_trans * (omega_m / gear_ratio - omega_wheel);

  // === Wheel dynamics ===
  J_wheel * der(omega_wheel) = T_gear_out - b_wheel * omega_wheel - r_wheel * F_contact;
  der(theta_wheel) = omega_wheel;
  v_wheel = omega_wheel * r_wheel;
  x_wheel = theta_wheel * r_wheel;

  // === Contact model (compliant, rigid support geometry) ===
  contact_penetration = noEvent(if x_wheel - x_load - x_gap > 0.0 then x_wheel - x_load - x_gap else 0.0);
  contact_penetration_vel = noEvent(if x_wheel - x_load - x_gap > 0.0 then v_wheel - v_load else 0.0);
  F_contact = k_contact * contact_penetration + c_contact * contact_penetration_vel;

  // === Load dynamics ===
  m_load * der(v_load) = F_contact - F_load_spring + F_disturbance;
  F_load_spring = k_load * x_load + c_load * v_load;
  der(x_load) = v_load;

  // === Thermal model ===
  P_loss_copper = R_phase * (i_q * i_q + i_d * i_d);
  P_loss_total = P_loss_copper + b_motor * omega_m * omega_m + b_wheel * omega_wheel * omega_wheel;
  Cth * der(T_motor_winding) = P_loss_copper - (T_motor_winding - T_ambient) / Rth;

  // === Sensor traces (synchronized) ===
  sens_motor_current = i_q;
  sens_trans_in_torque = T_trans / gear_ratio;
  sens_trans_out_torque = T_gear_out;
  sens_output_position = x_wheel;
  sens_output_velocity = v_wheel;
  sens_contact_force = F_contact;
  sens_temperature = T_motor_winding;

  // === Performance metrics and bound monitoring ===
  tracking_error = noEvent(if F_err >= 0.0 then F_err else -F_err);
  tracking_ok = noEvent(if time >= 7.8 then tracking_error < 2.1 else true);

  max_current_abs = noEvent(if i_q >= 0.0 then i_q else -i_q);
  max_temperature = T_motor_winding;
  max_trans_deflection = noEvent(if x_trans_deflection >= 0.0 then x_trans_deflection else -x_trans_deflection);
  max_contact_force = noEvent(if F_contact >= 0.0 then F_contact else -F_contact);

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "BLDCWheelTorqueC: Electromechanical robotic actuator system.
      Inner FOC current control with outer force feedback tracking a compliant load.
      Plant: 48 V three-phase PM motor, 4 pole pairs, 9:1 gearbox, 0.12 m wheel,
      battery with internal resistance, field-oriented inverter.
      13.5 N disturbance injected during middle third (4-8 s).
      Sensors: motor current, transmission input/output torque, output state,
      contact force, temperature.
      Controller sample rate 125 Hz (simulation interval 0.008 s).
      Tracking error target: below 2.1 N after 7.8 s.
      Bounds monitored: electrical (V_cmd_max, current), thermal, joint motion,
      transmission deflection, contact force."));
end BLDCWheelTorqueC;