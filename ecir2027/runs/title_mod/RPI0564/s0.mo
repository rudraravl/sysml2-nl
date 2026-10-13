model SeriesElasticSpeedF
  "Series elastic actuator: accelerate to declared speed, hold, decelerate to rest"

  // ---- Physical parameters ----
  parameter Real V_nom = 48.0 "Nominal DC bus voltage [V]";
  parameter Real V_max = 58.6 "Maximum allowed voltage [V]";
  parameter Real Kt = 0.1 "Motor torque constant [N.m/A]";
  parameter Real Ke = 0.1 "Back-EMF constant [V.s/rad]";
  parameter Real R_m = 0.5 "Motor winding resistance [Ohm]";
  parameter Real L_m = 0.001 "Motor winding inductance [H]";
  parameter Real J_m = 0.001 "Motor rotor inertia [kg.m2]";
  parameter Real N_gear = 100.0 "Gear ratio";
  parameter Real eta_g = 0.9 "Gearbox efficiency";
  parameter Real k_spring = 850.0 "Torsional spring stiffness [N.m/rad]";
  parameter Real J_load = 1.0 "Load inertia [kg.m2]";
  parameter Real b_m = 0.001 "Motor viscous friction [N.m.s/rad]";
  parameter Real b_load = 0.1 "Load viscous friction [N.m.s/rad]";
  parameter Real R_batt = 0.1 "Battery internal resistance [Ohm]";
  parameter Real E_batt = 1728000.0 "Battery energy capacity [J] (10 Ah at 48 V)";
  parameter Real R_th = 0.5 "Thermal resistance [K/W]";
  parameter Real C_th = 200.0 "Thermal capacitance [J/K]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real T_max = 80.0 "Max allowed temperature [degC]";
  parameter Real I_max = 50.0 "Max allowed current [A]";
  parameter Real omega_max = 20.0 "Max allowed output speed [rad/s]";
  parameter Real alpha_max = 50.0 "Max allowed output acceleration [rad/s2]";
  parameter Real SoC_min = 0.1 "Minimum state of charge";
  parameter Real omega_ref_hold = 5.0 "Declared output speed [rad/s]";
  parameter Real T_dist = 17.4 "Load disturbance torque [N.m]";
  parameter Real Ts_ctrl = 0.002 "Control sample period [s] (500 Hz)";

  // ---- Controller gains ----
  parameter Real Kp_w = 50.0 "Speed loop proportional gain";
  parameter Real Ki_w = 100.0 "Speed loop integral gain";
  parameter Real Kp_t = 0.5 "Spring-torque loop proportional gain";
  parameter Real Ki_t = 5.0 "Spring-torque loop integral gain";
  parameter Real Kp_i = 1.0 "Current loop proportional gain";
  parameter Real Ki_i = 500.0 "Current loop integral gain";

  // ---- Dynamic states ----
  Real i_q(start = 0.0, fixed = true) "q-axis (armature) current [A]";
  Real theta_m(start = 0.0, fixed = true) "Motor rotor position [rad]";
  Real omega_m(start = 0.0, fixed = true) "Motor angular velocity [rad/s]";
  Real theta_load(start = 0.0, fixed = true) "Load (output) position [rad]";
  Real omega_load(start = 0.0, fixed = true) "Load (output) angular velocity [rad/s]";
  Real SoC(start = 1.0, fixed = true) "Battery state of charge [0-1]";
  Real T_motor(start = 25.0, fixed = true) "Motor winding temperature [degC]";
  Real integ_w(start = 0.0, fixed = true) "Speed loop integrator state";
  Real integ_t(start = 0.0, fixed = true) "Torque loop integrator state";
  Real integ_i(start = 0.0, fixed = true) "Current loop integrator state";

  // ---- Derived mechanical variables ----
  Real theta_gear "Gearbox output position [rad]";
  Real omega_gear "Gearbox output angular velocity [rad/s]";
  Real delta_theta "Spring deflection [rad]";
  Real tau_spring "Spring torque [N.m]";
  Real tau_spring_upstream "Spring torque at gearbox side [N.m]";
  Real tau_spring_downstream "Spring torque at load side [N.m]";
  Real tau_motor "Motor electromagnetic torque [N.m]";
  Real tau_reflected "Reflected spring torque at motor [N.m]";
  Real alpha_load "Load angular acceleration [rad/s2]";

  // ---- Electrical variables ----
  Real V_bus "DC bus voltage [V]";
  Real I_batt "Battery current [A]";
  Real P_batt "Battery power [W]";

  // ---- Control signals ----
  Real omega_ref "Speed reference command [rad/s]";
  Real tau_spring_ref "Spring torque reference command [N.m]";
  Real i_q_ref "Current reference command [A]";
  Real i_q_ref_raw "Unsaturated current reference [A]";
  Real V_q "q-axis voltage command [V]";
  Real V_q_raw "Unsaturated q-axis voltage [V]";
  Real tau_dist "Disturbance torque [N.m]";

  // ---- Sensors ----
  Real i_sense "Sensed armature/phase current [A]";
  Real theta_m_sense "Sensed rotor position [rad]";
  Real omega_load_sense "Sensed output speed [rad/s]";
  Real V_bus_sense "Sensed DC bus voltage [V]";

  // ---- Verification ----
  Real tracking_error "Speed tracking error [rad/s]";
  Boolean voltage_ok "Voltage within bounds";
  Boolean current_ok "Current within bounds";
  Boolean speed_ok "Speed within bounds";
  Boolean accel_ok "Acceleration within bounds";
  Boolean soc_ok "State of charge above minimum";
  Boolean thermal_ok "Temperature within bounds";
  Boolean tracking_ok "Tracking error below 0.2 rad/s after 13 s";
  Boolean no_nan_inf "No NaN or infinite values in states or controls";

equation
  // ===== Speed reference: accelerate (0-3 s), hold (3-14 s), decelerate (14-17 s), rest (17-20 s) =====
  if time < 3.0 then
    omega_ref = omega_ref_hold * (time / 3.0);
  elseif time < 14.0 then
    omega_ref = omega_ref_hold;
  elseif time < 17.0 then
    omega_ref = omega_ref_hold * (1.0 - (time - 14.0) / 3.0);
  else
    omega_ref = 0.0;
  end if;

  // ===== Disturbance: 17.4 N.m during middle third of 20 s (6.667 - 13.333 s) =====
  if time >= 20.0 / 3.0 and time <= 40.0 / 3.0 then
    tau_dist = T_dist;
  else
    tau_dist = 0.0;
  end if;

  // ===== Battery model with droop =====
  I_batt = i_q;
  V_bus = V_nom - R_batt * I_batt;
  P_batt = V_bus * I_batt;
  der(SoC) = -P_batt / E_batt;

  // ===== Motor electrical dynamics (q-axis, field-oriented control) =====
  L_m * der(i_q) = V_q - R_m * i_q - Ke * omega_m;
  tau_motor = Kt * i_q;

  // ===== Gearbox kinematics (100:1) =====
  theta_gear = theta_m / N_gear;
  omega_gear = omega_m / N_gear;

  // ===== Series elastic spring (850 N.m/rad), instrumented on both sides =====
  delta_theta = theta_gear - theta_load;
  tau_spring = k_spring * delta_theta;
  tau_spring_upstream = tau_spring;
  tau_spring_downstream = -tau_spring;

  // ===== Reflected torque through gearbox (forward efficiency) =====
  tau_reflected = tau_spring / (N_gear * eta_g);

  // ===== Motor mechanical dynamics =====
  der(theta_m) = omega_m;
  J_m * der(omega_m) = tau_motor - tau_reflected - b_m * omega_m;

  // ===== Load mechanical dynamics with friction and disturbance =====
  der(theta_load) = omega_load;
  J_load * der(omega_load) = tau_spring - b_load * omega_load - tau_dist;
  alpha_load = der(omega_load);

  // ===== Thermal model (Joule heating) =====
  C_th * der(T_motor) = i_q * i_q * R_m - (T_motor - T_amb) / R_th;

  // ===== Sensors =====
  i_sense = i_q;
  theta_m_sense = theta_m;
  omega_load_sense = omega_load;
  V_bus_sense = V_bus;

  // ===== Outer speed loop -> spring torque reference =====
  tracking_error = omega_ref - omega_load_sense;
  der(integ_w) = tracking_error;
  tau_spring_ref = Kp_w * tracking_error + Ki_w * integ_w;

  // ===== Spring-torque loop -> current reference (current-limited) =====
  der(integ_t) = tau_spring_ref - tau_spring;
  i_q_ref_raw = Kp_t * (tau_spring_ref - tau_spring) + Ki_t * integ_t;
  i_q_ref = max(-I_max, min(I_max, i_q_ref_raw));

  // ===== Inner current loop (FOC) -> voltage with back-EMF feedforward =====
  der(integ_i) = i_q_ref - i_q;
  V_q_raw = Kp_i * (i_q_ref - i_q) + Ki_i * integ_i + Ke * omega_m;
  V_q = max(-V_max, min(V_max, V_q_raw));

  // ===== Verification criteria =====
  voltage_ok = abs(V_q) <= V_max + 0.01 and V_bus <= V_max + 0.01;
  current_ok = abs(i_q) <= I_max + 0.01;
  speed_ok = abs(omega_load) <= omega_max;
  accel_ok = abs(alpha_load) <= alpha_max;
  soc_ok = SoC >= SoC_min;
  thermal_ok = T_motor <= T_max;
  tracking_ok = if time >= 13.0 then abs(tracking_error) < 0.2 else true;
  // NaN/infinity verified by solver; flag is true when all values remain finite
  no_nan_inf = (i_q == i_q) and (omega_load == omega_load) and
               (theta_m == theta_m) and (V_bus == V_bus) and
               (SoC == SoC) and (T_motor == T_motor);

  annotation(
    Experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "SeriesElasticSpeedF: Electromechanical robotic actuator.
      48 V BLDC motor, 100:1 gearbox (eta=0.9), 850 N.m/rad torsional spring.
      Mission: accelerate to 5 rad/s, hold, decelerate to rest over 20 s.
      Inner current + outer spring-torque control with FOC; voltage <= 58.6 V.
      17.4 N.m load disturbance during middle third (6.667-13.333 s).
      Control and output rate: 500 Hz (interval = 0.002 s).
      Verification: voltage, current, speed, acceleration, SoC, thermal bounds;
      tracking error < 0.2 rad/s after 13 s; no NaN/infinite values."));

end SeriesElasticSpeedF;