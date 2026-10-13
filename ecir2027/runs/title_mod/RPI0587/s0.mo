model CableWinchSpeedE
  "Electromechanical robotic cable-winch actuator: accelerate, hold, decelerate
   72 V motor, 45:1 gearbox, 0.09 m drum, 140 kg payload, 12 m travel.
   Cascaded motor-speed / cable-tension loops with current-limited voltage command.
   Battery droop, gearbox efficiency, drum friction, rotating inertia, thermal model."

  // ============ Motor parameters ============
  parameter Real V_nominal = 72.0  "Nominal motor voltage [V]";
  parameter Real Ra = 0.5           "Armature resistance [ohm]";
  parameter Real La = 5.0e-4        "Armature inductance [H]";
  parameter Real Ke = 0.10          "Back-EMF constant [V.s/rad]";
  parameter Real Kt = 0.10          "Torque constant [N.m/A]";
  parameter Real J_rotor = 1.0e-3  "Rotor inertia [kg.m2]";
  parameter Real B_rotor = 5.0e-5  "Rotor viscous friction [N.m.s/rad]";

  // ============ Gearbox & drum ============
  parameter Real N_gear = 45.0     "Gear ratio (motor : drum) [-]";
  parameter Real eta_gb = 0.92     "Gearbox efficiency [-]";
  parameter Real B_drum = 0.01     "Drum viscous friction [N.m.s/rad]";
  parameter Real T_Coulomb = 0.5   "Coulomb friction at drum [N.m]";
  parameter Real omega_eps = 0.05  "Friction smoothing speed [rad/s]";
  parameter Real r_drum = 0.09     "Drum radius [m]";
  parameter Real L_travel = 12.0   "Cable travel distance [m]";

  // ============ Payload ============
  parameter Real m_payload = 140.0 "Payload mass [kg]";
  parameter Real g = 9.81          "Gravitational acceleration [m/s2]";

  // ============ Battery ============
  parameter Real V_oc_full = 72.0  "Open-circuit voltage, full charge [V]";
  parameter Real V_oc_empty = 60.0 "Open-circuit voltage, empty [V]";
  parameter Real R_bat = 0.08      "Battery internal resistance [ohm]";
  parameter Real Q_bat = 3.6e4     "Battery capacity [C] (10 Ah)";

  // ============ Thermal ============
  parameter Real C_thermal = 800.0  "Thermal capacitance [J/K]";
  parameter Real R_thermal = 0.3   "Thermal resistance [K/W]";
  parameter Real T_ambient = 25.0  "Ambient temperature [degC]";

  // ============ Control bounds ============
  parameter Real V_max = 79.2      "Voltage command magnitude bound [V]";
  parameter Real I_max = 100.0     "Current limit [A]";

  // ============ Reference profile ============
  parameter Real v_ref_hold = 1.0  "Hold cable speed [m/s]";
  parameter Real t_acc = 4.0       "Acceleration duration [s]";
  parameter Real t_hold_end = 12.0 "End of hold phase [s]";
  parameter Real t_total = 16.0    "Total run time [s]";

  // ============ Disturbance (middle third of run) ============
  parameter Real F_dist = 14.4      "Disturbance load force [N]";
  parameter Real t_dist_start = 5.3333  "Disturbance start [s]";
  parameter Real t_dist_end = 10.6667   "Disturbance end [s]";

  // ============ Acceptance bounds ============
  parameter Real V_bound = 80.0     "Physical voltage bound [V]";
  parameter Real I_bound = 110.0   "Physical current bound [A]";
  parameter Real v_bound = 2.0     "Physical speed bound [m/s]";
  parameter Real a_bound = 5.0     "Physical acceleration bound [m/s2]";
  parameter Real SOC_min = 0.05    "Minimum state-of-charge [-]";
  parameter Real T_max_motor = 80.0 "Motor thermal bound [degC]";
  parameter Real err_bound = 0.225  "Tracking error bound after 10.4 s [m/s]";

  // ============ Controller gains ============
  parameter Real Kp_speed = 1200.0  "Speed loop proportional gain [N/(m/s)]";
  parameter Real Ki_speed = 4000.0  "Speed loop integral gain [N/(m/s)/s]";
  parameter Real Kp_tension = 0.04  "Tension loop proportional gain [V/N]";
  parameter Real Ki_tension = 0.30  "Tension loop integral gain [V/N/s]";

  // ============ Dynamic states ============
  Real i_arm(start = 29.8565, fixed = true)
    "Armature current [A]";
  Real omega_drum(start = 0.0, fixed = true)
    "Drum angular speed [rad/s]";
  Real theta_motor(start = 0.0, fixed = true)
    "Motor rotor position [rad]";
  Real x_cable(start = 0.0, fixed = true)
    "Cable linear position [m]";
  Real SOC(start = 1.0, fixed = true)
    "Battery state of charge [-]";
  Real T_motor(start = 25.0, fixed = true)
    "Motor winding temperature [degC]";
  Real speed_int(start = 1373.4, fixed = true)
    "Speed-loop integrator state [N]";
  Real tension_int(start = 14.9283, fixed = true)
    "Tension-loop integrator state [V]";

  // ============ Algebraic variables ============
  Real omega_motor "Motor angular speed [rad/s]";
  Real v_cable     "Cable linear speed [m/s]";
  Real a_cable     "Cable linear acceleration [m/s2]";
  Real J_eq        "Equivalent inertia at drum [kg.m2]";
  Real tau_drum    "Motor torque reflected to drum [N.m]";
  Real tau_load    "Load torque at drum [N.m]";
  Real T_fric      "Friction torque at drum [N.m]";
  Real T_cable     "Cable tension [N]";
  Real F_gravity   "Gravity load force [N]";
  Real F_disturbance "Disturbance force [N]";

  // ============ Battery & bus ============
  Real V_oc        "Battery open-circuit voltage [V]";
  Real V_bus       "DC bus voltage [V]";

  // ============ Control signals ============
  Real v_ref          "Reference cable speed [m/s]";
  Real v_err          "Speed tracking error [m/s]";
  Real T_cable_ref_raw "Raw tension reference [N]";
  Real T_cable_ref    "Current-limited tension reference [N]";
  Real T_cable_max    "Max cable tension from current limit [N]";
  Real T_err          "Tension error [N]";
  Real V_cmd_raw      "Unbounded voltage command [V]";
  Real V_cmd          "Bounded voltage command [V]";

  // ============ Sensors ============
  Real i_sense       "Armature current sensor [A]";
  Real theta_sense   "Rotor position sensor [rad]";
  Real omega_sense   "Output (drum) speed sensor [rad/s]";
  Real Vbus_sense    "DC-bus voltage sensor [V]";

  // ============ Monitoring ============
  Real tracking_error "Primary tracking error |v_ref - v_cable| [m/s]";
  Boolean voltage_ok  "Voltage within physical bound";
  Boolean current_ok  "Current within physical bound";
  Boolean speed_ok    "Speed within physical bound";
  Boolean accel_ok    "Acceleration within physical bound";
  Boolean soc_ok      "State-of-charge above minimum";
  Boolean thermal_ok  "Temperature within bound";
  Boolean tracking_ok "Tracking error within bound after 10.4 s";
  Boolean no_nan_inf  "No NaN or infinite values detected";
  Boolean fail_closed "Fail-closed acceptance: all checks pass";

equation
  // ---- Equivalent inertia at drum level ----
  J_eq = J_rotor * N_gear * N_gear / eta_gb + m_payload * r_drum * r_drum;

  // ---- Gravity and disturbance forces ----
  F_gravity = m_payload * g;
  if time >= t_dist_start and time <= t_dist_end then
    F_disturbance = F_dist;
  else
    F_disturbance = 0.0;
  end if;

  // ---- Trapezoidal speed reference: accelerate, hold, decelerate ----
  if time < t_acc then
    v_ref = v_ref_hold * time / t_acc;
  elseif time < t_hold_end then
    v_ref = v_ref_hold;
  elseif time < t_total then
    v_ref = v_ref_hold * (t_total - time) / (t_total - t_hold_end);
  else
    v_ref = 0.0;
  end if;

  // ---- Friction model (smooth Coulomb + viscous) ----
  T_fric = T_Coulomb * tanh(omega_drum / omega_eps) + B_drum * omega_drum;

  // ---- Drum / payload dynamics ----
  tau_drum = Kt * i_arm * N_gear * eta_gb;
  tau_load = (F_gravity + F_disturbance) * r_drum + T_fric;
  J_eq * der(omega_drum) = tau_drum - tau_load;

  // ---- Cable kinematics ----
  v_cable = omega_drum * r_drum;
  der(x_cable) = v_cable;
  a_cable = r_drum * (tau_drum - tau_load) / J_eq;

  // ---- Motor kinematics ----
  omega_motor = omega_drum * N_gear;
  der(theta_motor) = omega_motor;

  // ---- Motor electrical dynamics ----
  La * der(i_arm) = V_cmd - Ra * i_arm - Ke * omega_motor;

  // ---- Cable tension from motor current ----
  T_cable = Kt * i_arm * N_gear * eta_gb / r_drum;

  // ---- Battery model with droop ----
  V_oc = V_oc_empty + (V_oc_full - V_oc_empty) * SOC;
  V_bus = V_oc - i_arm * R_bat;
  der(SOC) = -abs(i_arm) / Q_bat;

  // ---- Thermal model ----
  der(T_motor) = (i_arm * i_arm * Ra - (T_motor - T_ambient) / R_thermal) / C_thermal;

  // ============ Cascaded control ============
  // ---- Outer loop: motor speed -> cable tension reference ----
  v_err = v_ref - v_cable;
  der(speed_int) = Ki_speed * v_err;
  T_cable_ref_raw = Kp_speed * v_err + speed_int;

  // ---- Current-limited tension reference (tension >= 0, bounded) ----
  T_cable_max = Kt * I_max * N_gear * eta_gb / r_drum;
  if T_cable_ref_raw > T_cable_max then
    T_cable_ref = T_cable_max;
  elseif T_cable_ref_raw < 0.0 then
    T_cable_ref = 0.0;
  else
    T_cable_ref = T_cable_ref_raw;
  end if;

  // ---- Inner loop: cable tension -> voltage command ----
  T_err = T_cable_ref - T_cable;
  der(tension_int) = Ki_tension * T_err;
  V_cmd_raw = Kp_tension * T_err + tension_int;

  // ---- Voltage command saturation ----
  if V_cmd_raw > V_max then
    V_cmd = V_max;
  elseif V_cmd_raw < -V_max then
    V_cmd = -V_max;
  else
    V_cmd = V_cmd_raw;
  end if;

  // ============ Sensors ============
  i_sense = i_arm;
  theta_sense = theta_motor;
  omega_sense = omega_drum;
  Vbus_sense = V_bus;

  // ============ Monitoring & acceptance ============
  tracking_error = abs(v_ref - v_cable);
  voltage_ok  = abs(V_cmd) <= V_bound + 0.001;
  current_ok  = abs(i_arm) <= I_bound;
  speed_ok    = abs(v_cable) <= v_bound;
  accel_ok    = abs(a_cable) <= a_bound;
  soc_ok      = SOC >= SOC_min;
  thermal_ok  = T_motor <= T_max_motor;
  tracking_ok = (time < 10.4) or (tracking_error <= err_bound);
  no_nan_inf  = (v_cable > -1.0e12) and (v_cable < 1.0e12)
    and (i_arm > -1.0e12) and (i_arm < 1.0e12)
    and (V_cmd > -1.0e12) and (V_cmd < 1.0e12)
    and (omega_drum > -1.0e12) and (omega_drum < 1.0e12)
    and (x_cable > -1.0e12) and (x_cable < 1.0e12)
    and (T_motor > -1.0e12) and (T_motor < 1.0e12)
    and (SOC > -1.0e12) and (SOC < 1.0e12)
    and (speed_int > -1.0e12) and (speed_int < 1.0e12)
    and (tension_int > -1.0e12) and (tension_int < 1.0e12);
  fail_closed = voltage_ok and current_ok and speed_ok and accel_ok
    and soc_ok and thermal_ok and tracking_ok and no_nan_inf;

  annotation (
    Documentation(info = "CableWinchSpeedE: Electromechanical robotic cable winch actuator.
      72 V DC motor (Ra=0.5 ohm, La=0.5 mH, Ke=Kt=0.1) drives a 45:1 gearbox (eta=0.92)
      and 0.09 m-radius drum lifting 140 kg payload over 12 m massless cable.
      Cascaded control: outer speed PI -> cable tension reference (current-limited),
      inner tension PI -> voltage command (bounded at 79.2 V).
      Battery model with internal resistance droop and SOC depletion.
      Thermal model with Joule heating and convective cooling.
      14.4 N load disturbance applied during middle third (5.33-10.67 s) of 16 s run.
      Run at 250 Hz for 16 s. Acceptance is fail-closed."),
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004)
  );
end CableWinchSpeedE;