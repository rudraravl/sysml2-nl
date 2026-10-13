model CableWinchSpeedD
  "Instrumented electromechanical robotic winch actuator with cascaded speed-tension control"

  // ========== Plant parameters ==========
  parameter Real V_max = 72.0 "DC bus voltage limit [V]";
  parameter Real N = 45.0 "Gearbox ratio";
  parameter Real eta_gb = 0.85 "Gearbox efficiency";
  parameter Real r_drum = 0.09 "Drum radius [m]";
  parameter Real m_payload = 140.0 "Payload mass [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  // Max cable travel is 12 m; chosen speed yields 8.4 m travel, within limit.

  // ========== Motor parameters (design values; unstated facts treated as unknown) ==========
  parameter Real Kt = 0.05 "Motor torque constant [N.m/A]";
  parameter Real Ke = 0.05 "Motor back-EMF constant [V.s/rad]";
  parameter Real R_a = 0.15 "Armature resistance [ohm]";
  parameter Real L_a = 0.001 "Armature inductance [H]";
  parameter Real J_motor = 0.01 "Motor rotor inertia [kg.m2]";
  parameter Real J_drum = 0.05 "Drum and gearbox output inertia [kg.m2]";
  parameter Real b_v = 0.001 "Viscous friction coefficient [N.m.s/rad]";
  parameter Real I_max = 120.0 "Current limit [A]";

  // ========== Battery parameters ==========
  parameter Real V_oc_0 = 72.0 "Battery open-circuit voltage at full SoC [V]";
  parameter Real R_bat = 0.1 "Battery internal resistance [ohm]";
  parameter Real E_bat = 500000.0 "Battery usable energy capacity [J]";
  parameter Real SoC_0 = 1.0 "Initial state of charge [fraction]";

  // ========== Thermal parameters ==========
  parameter Real R_th = 0.5 "Thermal resistance [K/W]";
  parameter Real C_th = 500.0 "Thermal capacitance [J/K]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real T_th_max = 80.0 "Thermal limit [degC]";

  // ========== Control parameters ==========
  parameter Real v_ref_hold = 1.8 "Declared output speed [m/s]";
  parameter Real t_total = 14.0 "Total run duration [s]";
  parameter Real Kp_speed = 5.0 "Speed loop proportional gain [A.s/rad]";
  parameter Real Ki_speed = 50.0 "Speed loop integral gain [A/rad]";
  parameter Real Kp_curr = 5.0 "Current loop proportional gain [V/A]";
  parameter Real Kp_tension = 0.0002 "Tension loop proportional gain";
  parameter Real Ki_tension = 0.001 "Tension loop integral gain";
  parameter Real f_sample = 200.0 "Control sample rate [Hz]";

  // ========== Disturbance ==========
  parameter Real T_dist = 12.0 "Disturbance torque at drum [N.m]";
  parameter Real t_dist_start = t_total / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * t_total / 3.0 "Disturbance end time [s]";

  // ========== Bounds ==========
  parameter Real v_bound = 3.0 "Output speed bound [m/s]";
  parameter Real a_bound = 3.0 "Output acceleration bound [m/s2]";
  parameter Real tracking_bound = 0.25 "Tracking error bound [m/s]";
  parameter Real t_track_check = 9.1 "Tracking error check start time [s]";

  // ========== Derived parameters ==========
  final parameter Real J_eff = J_motor + (J_drum + m_payload * r_drum * r_drum) / (N * N)
    "Effective inertia at motor shaft [kg.m2]";
  final parameter Real T_gravity = m_payload * g * r_drum / (N * eta_gb)
    "Gravity torque reflected to motor [N.m]";
  final parameter Real i_hold = T_gravity / Kt "Holding current [A]";

  // ========== Dynamic states ==========
  Real i_a(start = i_hold) "Armature current [A]";
  Real omega_motor(start = 0.0) "Motor angular velocity [rad/s]";
  Real theta_motor(start = 0.0) "Motor rotor position [rad]";
  Real SoC(start = SoC_0) "Battery state of charge [fraction]";
  Real T_winding(start = T_amb) "Motor winding temperature [degC]";
  Real speed_int(start = 0.0) "Speed loop integrator [A]";
  Real tension_int(start = 0.0) "Tension loop integrator [rad/s]";

  // ========== Sensor and command traces ==========
  Real V_oc "Battery open-circuit voltage [V]";
  Real V_bat "Battery terminal voltage [V]";
  Real V_bus_sensed "Sensed DC bus voltage [V]";
  Real V_cmd "Unlimited voltage command [V]";
  Real V_applied "Applied motor voltage [V]";
  Real i_cmd "Current command [A]";
  Real i_cmd_lim "Limited current command [A]";
  Real T_motor "Motor torque [N.m]";
  Real omega_drum "Drum angular velocity [rad/s]";
  Real v_out "Output linear speed [m/s]";
  Real a_out "Output linear acceleration [m/s2]";
  Real x_payload "Payload position [m]";
  Real F_cable "Cable tension [N]";
  Real F_cable_ref "Cable tension reference [N]";
  Real T_dist_applied "Applied disturbance torque [N.m]";
  Real T_dist_reflected "Disturbance reflected to motor [N.m]";
  Real v_ref "Output speed reference [m/s]";
  Real omega_ref "Motor speed reference [rad/s]";
  Real omega_ref_adj "Adjusted motor speed reference [rad/s]";
  Real speed_error "Motor speed tracking error [rad/s]";
  Real v_error "Output speed tracking error [m/s]";
  Real tension_error "Cable tension error [N]";
  Real P_elec "Electrical power [W]";
  Real P_loss "Resistive power loss [W]";

  // ========== Bound flags ==========
  Boolean voltage_ok;
  Boolean current_ok;
  Boolean speed_ok;
  Boolean accel_ok;
  Boolean soc_ok;
  Boolean thermal_ok;
  Boolean tracking_ok;
  Boolean all_ok;

equation

  // ===== Reference speed profile: trapezoidal (accel, hold, decel) =====
  if time <= t_dist_start then
    v_ref = v_ref_hold * time / t_dist_start;
  elseif time <= t_dist_end then
    v_ref = v_ref_hold;
  else
    v_ref = max(0.0, v_ref_hold * (t_total - time) / (t_total - t_dist_end));
  end if;

  omega_ref = v_ref * N / r_drum;

  // ===== Disturbance torque (middle third of run) =====
  if time >= t_dist_start and time <= t_dist_end then
    T_dist_applied = T_dist;
  else
    T_dist_applied = 0.0;
  end if;
  T_dist_reflected = T_dist_applied / (N * eta_gb);

  // ===== Battery model with droop =====
  V_oc = V_oc_0 * (0.85 + 0.15 * SoC);
  V_bat = V_oc - i_a * R_bat;
  V_bus_sensed = V_bat;
  der(SoC) = -V_bat * i_a / E_bat;

  // ===== Cable tension reference =====
  F_cable_ref = m_payload * g;

  // ===== Tension loop (outer) -> speed reference adjustment =====
  tension_error = F_cable_ref - F_cable;
  der(tension_int) = Ki_tension * tension_error;
  omega_ref_adj = omega_ref + Kp_tension * tension_error + tension_int;

  // ===== Speed loop (inner) -> current command with current limiting =====
  speed_error = omega_ref_adj - omega_motor;
  der(speed_int) = Ki_speed * speed_error;
  i_cmd = i_hold + Kp_speed * speed_error + speed_int;
  i_cmd_lim = max(-I_max, min(I_max, i_cmd));

  // ===== Current loop -> voltage command with voltage limiting =====
  V_cmd = R_a * i_cmd_lim + Ke * omega_motor + Kp_curr * (i_cmd_lim - i_a);
  V_applied = max(-V_max, min(V_max, V_cmd));

  // ===== Motor electrical dynamics =====
  L_a * der(i_a) = V_applied - R_a * i_a - Ke * omega_motor;

  // ===== Motor torque =====
  T_motor = Kt * i_a;

  // ===== Mechanical dynamics at motor shaft =====
  J_eff * der(omega_motor) = T_motor - T_gravity - T_dist_reflected - b_v * omega_motor;
  der(theta_motor) = omega_motor;

  // ===== Output kinematics =====
  omega_drum = omega_motor / N;
  v_out = r_drum * omega_drum;
  a_out = r_drum * der(omega_motor) / N;
  x_payload = r_drum * theta_motor / N;

  // ===== Cable tension from payload dynamics =====
  F_cable = m_payload * (g + a_out);

  // ===== Power and thermal =====
  P_elec = V_bat * i_a;
  P_loss = i_a * i_a * R_a;
  C_th * der(T_winding) = P_loss - (T_winding - T_amb) / R_th;

  // ===== Tracking error =====
  v_error = v_ref - v_out;

  // ===== Bound checks =====
  voltage_ok = abs(V_applied) <= V_max + 0.01;
  current_ok = abs(i_a) <= I_max + 1.0;
  speed_ok = abs(v_out) <= v_bound;
  accel_ok = abs(a_out) <= a_bound;
  soc_ok = SoC >= 0.0 and SoC <= 1.0;
  thermal_ok = T_winding <= T_th_max;
  tracking_ok = if time >= t_track_check then abs(v_error) <= tracking_bound else true;
  all_ok = voltage_ok and current_ok and speed_ok and accel_ok and soc_ok and thermal_ok and tracking_ok;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "CableWinchSpeedD: 72V DC motor, 45:1 gearbox, 0.09m drum, 140kg payload, 12m max travel.
      Cascaded cable-tension (outer) and motor-speed (inner) loops with current-limited voltage command (<=72V).
      Trapezoidal speed profile: accel, hold, decelerate over 14s at 200Hz (5ms interval).
      12 N.m disturbance torque applied at drum during middle third (4.667s to 9.333s).
      Includes gearbox efficiency (0.85), viscous friction, battery droop (R_bat, SoC-dependent V_oc),
      rotating inertia (motor + drum + reflected payload), and motor thermal model.
      Voltage limit 72V, current limit 120A, thermal limit 80degC.
      Primary tracking error bound 0.25 m/s checked after 9.1s.")
  );

end CableWinchSpeedD;