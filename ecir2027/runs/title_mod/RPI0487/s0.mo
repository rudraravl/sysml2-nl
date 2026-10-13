model DCServoSpeedA
  "DC servo speed control: 48V PM motor, 100:1 gearbox, 80 Hz current-limited speed regulation"

  // --- Electrical parameters ---
  parameter Real V_nom = 48.0 "Nominal DC bus voltage [V]";
  parameter Real R_batt = 0.15 "Battery internal resistance [Ohm]";
  parameter Real R_a = 0.3 "Armature resistance [Ohm]";
  parameter Real L_a = 0.01 "Armature inductance [H]";
  parameter Real Kt = 0.05 "Torque constant [N.m/A]";
  parameter Real Ke = 0.05 "Back-EMF constant [V.s/rad]";
  parameter Real V_cmd_max = 34.6 "Command magnitude limit [V]";
  parameter Real I_max = 15.0 "Current limit [A]";
  parameter Real V_bound = 48.0 "Voltage bound [V]";

  // --- Mechanical parameters ---
  parameter Real J_rotor = 0.001 "Rotor inertia [kg.m2]";
  parameter Real J_link = 0.1 "Link inertia at output side [kg.m2]";
  parameter Real N_gear = 100.0 "Gearbox ratio";
  parameter Real eta_gear = 0.9 "Gearbox efficiency";
  parameter Real b_fric = 0.01 "Viscous friction at output [N.m.s/rad]";

  // --- Battery parameters ---
  parameter Real SOC_init = 1.0 "Initial state of charge [1]";
  parameter Real C_batt = 10000.0 "Battery capacity [C]";

  // --- Thermal parameters ---
  parameter Real R_th = 2.0 "Thermal resistance [K/W]";
  parameter Real C_th = 500.0 "Thermal capacitance [J/K]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real T_max = 80.0 "Thermal bound [degC]";

  // --- Speed profile ---
  parameter Real w_out_target = 5.0 "Declared output speed [rad/s]";

  // --- Control parameters ---
  parameter Real Ts_ctrl = 1.0 / 80.0 "Control sample time [s]";
  parameter Real Kp_sp = 3.0 "Speed loop proportional gain";
  parameter Real Ki_sp = 15.0 "Speed loop integral gain";
  parameter Real Kp_cur = 5.0 "Current loop proportional gain";
  parameter Real Ki_cur = 200.0 "Current loop integral gain";

  // --- Disturbance ---
  parameter Real T_dist = 6.0 "Load disturbance magnitude [N.m]";

  // === Continuous state variables ===
  Real i_a(start = 0.0) "Armature (phase) current [A]";
  Real theta_motor(start = 0.0) "Rotor position [rad]";
  Real w_motor(start = 0.0) "Rotor angular speed [rad/s]";
  Real SOC(start = SOC_init) "Battery state of charge [1]";
  Real T_winding(start = T_amb) "Motor winding temperature [degC]";

  // === Sensed / algebraic signals ===
  Real V_batt "Battery terminal voltage [V]";
  Real V_bus "Sensed DC bus voltage [V]";
  Real V_cmd "Unsaturated voltage command [V]";
  Real V_cmd_sat "Saturated (applied) voltage command [V]";
  Real i_cmd "Unsaturated current command [A]";
  Real i_cmd_sat "Saturated current command [A]";
  Real T_motor "Motor electromagnetic torque [N.m]";
  Real T_load "Load torque disturbance [N.m]";
  Real w_out "Output speed (sensed) [rad/s]";
  Real alpha_out "Output acceleration [rad/s2]";
  Real w_ref "Speed reference at output [rad/s]";
  Real track_err "Speed tracking error [rad/s]";
  Real P_elec "Electrical power drawn from bus [W]";
  Real J_total "Total inertia referred to motor shaft [kg.m2]";

  // === Discrete control states ===
  discrete Real i_err_int(start = 0.0) "Current loop integral accumulator [A.s]";
  discrete Real w_err_int(start = 0.0) "Speed loop integral accumulator [rad]";
  discrete Real i_cmd_disc(start = 0.0) "Discrete current command [A]";
  discrete Real V_cmd_disc(start = 0.0) "Discrete voltage command [V]";

  // === Bound flags ===
  Boolean voltage_ok "Voltage within bounds";
  Boolean current_ok "Current within bounds";
  Boolean speed_ok "Speed within bounds";
  Boolean thermal_ok "Temperature within bounds";
  Boolean soc_ok "State of charge within bounds";
  Boolean track_ok "Tracking error below 0.338 rad/s after 5.2 s";

equation
  // --- Battery model with droop ---
  V_batt = V_nom * SOC - R_batt * i_a;
  V_bus = V_batt;

  // State of charge (absolute current drain)
  der(SOC) = -abs(i_a) / C_batt;

  // --- Motor electrical dynamics ---
  L_a * der(i_a) = V_cmd_sat - R_a * i_a - Ke * w_motor;
  T_motor = Kt * i_a;

  // --- Thermal state (Joule heating) ---
  der(T_winding) = (R_a * i_a * i_a - (T_winding - T_amb) / R_th) / C_th;

  // --- Kinematics ---
  der(theta_motor) = w_motor;
  w_out = w_motor / N_gear;
  alpha_out = der(w_motor) / N_gear;

  // --- Mechanical dynamics lumped at motor side ---
  J_total = J_rotor + J_link / (N_gear * N_gear);
  J_total * der(w_motor) = T_motor - (b_fric * w_out + T_load) / (N_gear * eta_gear);

  // --- Load disturbance: 6 N.m during middle third of 8 s scenario ---
  T_load = if (time >= 8.0 / 3.0) and (time <= 16.0 / 3.0) then T_dist else 0.0;

  // --- Speed reference: ramp up, hold, ramp down ---
  w_ref = if time < 2.0 then w_out_target * time / 2.0
          elseif time < 6.0 then w_out_target
          elseif time < 8.0 then w_out_target * (8.0 - time) / 2.0
          else 0.0;

  track_err = w_ref - w_out;

  // --- Zero-order hold: continuous signals mirror discrete commands ---
  i_cmd = i_cmd_disc;
  i_cmd_sat = i_cmd_disc;
  V_cmd = V_cmd_disc;
  V_cmd_sat = V_cmd_disc;

  // --- Electrical power ---
  P_elec = V_bus * i_a;

  // --- Bound assertions ---
  voltage_ok = abs(V_cmd_sat) <= V_bound + 0.01;
  current_ok = abs(i_a) <= I_max + 0.5;
  speed_ok = abs(w_out) <= w_out_target * 2.0 + 0.01;
  thermal_ok = T_winding <= T_max + 0.01;
  soc_ok = SOC >= 0.0;
  track_ok = if time >= 5.2 then abs(track_err) < 0.338 else true;

algorithm
  when sample(0, Ts_ctrl) then
    // === Outer speed loop (PI) ===
    w_err_int := w_err_int + (w_ref - w_out) * Ts_ctrl;
    i_cmd_disc := Kp_sp * (w_ref - w_out) + Ki_sp * w_err_int;

    // Current saturation with anti-windup (undo integration on saturation)
    if i_cmd_disc > I_max then
      i_cmd_disc := I_max;
      w_err_int := w_err_int - (w_ref - w_out) * Ts_ctrl;
    elseif i_cmd_disc < -I_max then
      i_cmd_disc := -I_max;
      w_err_int := w_err_int - (w_ref - w_out) * Ts_ctrl;
    end if;

    // === Inner current loop (PI) ===
    i_err_int := i_err_int + (i_cmd_disc - i_a) * Ts_ctrl;
    V_cmd_disc := Kp_cur * (i_cmd_disc - i_a) + Ki_cur * i_err_int;

    // Voltage saturation with anti-windup
    if V_cmd_disc > V_cmd_max then
      V_cmd_disc := V_cmd_max;
      i_err_int := i_err_int - (i_cmd_disc - i_a) * Ts_ctrl;
    elseif V_cmd_disc < -V_cmd_max then
      V_cmd_disc := -V_cmd_max;
      i_err_int := i_err_int - (i_cmd_disc - i_a) * Ts_ctrl;
    end if;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.001),
    Documentation(info = "DC servo speed control system DCServoSpeedA.
      48 V permanent-magnet DC motor with armature resistance, inductance,
      torque constant, rotor inertia, and thermal state. Drives a revolute
      link through a 100:1 gearbox with efficiency. Cascaded current-limited
      speed regulation at 80 Hz. Voltage command limited to 34.6 V, current
      limited to 15 A. Speed profile: accelerate to 5 rad/s output, hold,
      decelerate to rest over 8 s. 6 N.m load disturbance during middle third.
      Battery droop, viscous friction, and rotating inertia included.
      Sensing: armature current, rotor position, output speed, DC bus voltage.
      Tracking error < 0.338 rad/s required after 5.2 s.")
  );
end DCServoSpeedA;