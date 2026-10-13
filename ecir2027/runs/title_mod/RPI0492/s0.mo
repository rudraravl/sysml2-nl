model DCServoSpeedF
  "DC servo speed control: accelerate, hold, decelerate with disturbance"

  // ---- Requirements-derived parameters ----
  parameter Real V_max = 58.6     "Maximum motor voltage [V]";
  parameter Real V_nominal = 48.0  "Nominal DC bus voltage [V]";
  parameter Real N_gear = 100.0   "Gearbox ratio";
  parameter Real T_dist = 17.4    "Disturbance load torque at output [N.m]";
  parameter Real f_ctrl = 500.0   "Control loop frequency [Hz]";
  parameter Real t_end = 20.0     "Mission duration [s]";
  parameter Real err_thresh = 0.2 "Tracking error limit after 13 s [rad/s]";

  // ---- Declared output speed (numerical value not stated in requirements) ----
  parameter Real w_cmd_hold = 3.0 "Declared hold output speed [rad/s]";

  // ---- Motor parameters (not specified — engineering placeholders) ----
  parameter Real R_a   = 0.5    "Armature resistance [Ohm]";
  parameter Real L_a   = 0.005  "Armature inductance [H]";
  parameter Real K_t   = 0.05   "Torque constant [N.m/A]";
  parameter Real K_emf = 0.05   "Back-EMF constant [V.s/rad]";
  parameter Real J_r   = 0.001  "Rotor inertia [kg.m2]";
  parameter Real b_m   = 1e-4   "Rotor viscous friction [N.m.s/rad]";

  // ---- Link / load (not specified — engineering placeholders) ----
  parameter Real J_l       = 0.5    "Link inertia [kg.m2]";
  parameter Real b_l       = 0.005  "Link viscous friction [N.m.s/rad]";
  parameter Real T_coulomb = 0.05   "Link Coulomb friction magnitude [N.m]";

  // ---- Gearbox (not specified) ----
  parameter Real eta_g = 0.95 "Gearbox efficiency";

  // ---- Battery (not specified) ----
  parameter Real R_batt = 0.05    "Battery internal resistance [Ohm]";
  parameter Real Q_batt = 36000.0 "Battery capacity [C]";
  parameter Real SOC0   = 0.9     "Initial state of charge";

  // ---- Thermal (not specified) ----
  parameter Real R_th   = 2.0    "Thermal resistance [K/W]";
  parameter Real C_th   = 500.0  "Thermal capacitance [J/K]";
  parameter Real T_amb  = 293.15 "Ambient temperature [K]";
  parameter Real T_limit = 353.15 "Max allowable motor temperature [K]";

  // ---- Current saturation (not specified) ----
  parameter Real I_max = 40.0 "Current saturation limit [A]";

  // ---- Controller gains (not specified) ----
  parameter Real Kp_w  = 50.0  "Speed proportional gain";
  parameter Real Ki_w  = 200.0 "Speed integral gain";
  parameter Real Kp_i  = 10.0  "Current proportional gain";

  // ---- Continuous state variables ----
  Real i_a(start = 0.0, fixed = true)       "Armature current [A]";
  Real w_out(start = 0.0, fixed = true)     "Output angular velocity [rad/s]";
  Real theta_out(start = 0.0, fixed = true) "Output position [rad]";
  Real T_motor(start = T_amb, fixed = true) "Motor winding temperature [K]";
  Real SOC(start = SOC0, fixed = true)      "Battery state of charge";

  // ---- Continuous algebraic variables ----
  Real w_motor        "Motor angular velocity [rad/s]";
  Real theta_motor    "Rotor position [rad]";
  Real alpha_out      "Output angular acceleration [rad/s2]";
  Real T_disturbance  "Applied disturbance torque [N.m]";
  Real T_coulomb_eff  "Smoothed Coulomb friction torque [N.m]";
  Real V_bus          "DC bus voltage [V]";
  Real J_eff          "Effective inertia at output [kg.m2]";
  Real b_eff          "Effective friction at output [N.m.s/rad]";
  Real K_eff          "Effective torque constant [N.m/A]";
  Real w_cmd          "Speed command [rad/s]";
  Real tracking_error "Speed tracking error [rad/s]";

  // ---- Discrete controller variables (updated at 500 Hz) ----
  Real integ_w(start = 0.0)   "Speed integral accumulator";
  Real i_cmd(start = 0.0)     "Unsaturated current command [A]";
  Real i_sat(start = 0.0)     "Saturated current command [A]";
  Real v_cmd(start = 0.0)     "Voltage command [V]";
  Real v_applied(start = 0.0) "Applied motor voltage [V]";

  // ---- Sensor observations ----
  Real i_a_meas        "Measured armature current [A]";
  Real w_out_meas      "Measured output speed [rad/s]";
  Real theta_out_meas  "Measured output position [rad]";
  Real theta_motor_meas "Measured rotor position [rad]";
  Real V_bus_meas      "Measured DC bus voltage [V]";
  Real alpha_meas      "Measured output acceleration [rad/s2]";

  // ---- Verification flags ----
  Boolean voltage_ok;
  Boolean current_ok;
  Boolean speed_ok;
  Boolean acceleration_ok;
  Boolean soc_ok;
  Boolean thermal_ok;
  Boolean tracking_ok;
  Boolean no_nan_inf;

equation
  // ---- Effective dynamics at output shaft ----
  J_eff = J_l + eta_g * N_gear * N_gear * J_r;
  b_eff = eta_g * N_gear * N_gear * b_m + b_l;
  K_eff = eta_g * N_gear * K_t;

  // ---- Smooth Coulomb friction (well-defined at zero speed) ----
  T_coulomb_eff = T_coulomb * w_out / (abs(w_out) + 0.001);

  // ---- Disturbance: applied during middle third of 20 s ----
  // Middle third: 6.667 s to 13.333 s
  if time >= 6.667 and time <= 13.333 then
    T_disturbance = T_dist;
  else
    T_disturbance = 0.0;
  end if;

  // ---- Output mechanical dynamics ----
  J_eff * der(w_out) = K_eff * i_a - b_eff * w_out - T_disturbance - T_coulomb_eff;
  der(theta_out) = w_out;
  alpha_out = der(w_out);

  // ---- Motor kinematics ----
  w_motor = N_gear * w_out;
  theta_motor = N_gear * theta_out;

  // ---- Motor electrical dynamics ----
  L_a * der(i_a) = v_applied - R_a * i_a - K_emf * w_motor;

  // ---- Battery model with droop ----
  V_bus = V_nominal * SOC - R_batt * i_a;

  // ---- State of charge dynamics ----
  der(SOC) = -abs(i_a) / Q_batt;

  // ---- Thermal model (Joule heating, conduction cooling) ----
  C_th * der(T_motor) = R_a * i_a * i_a - (T_motor - T_amb) / R_th;

  // ---- Speed command profile: ramp, hold, ramp ----
  // Accelerate 0–4 s, hold 4–16 s, decelerate 16–20 s
  if time < 4.0 then
    w_cmd = w_cmd_hold * (time / 4.0);
  elseif time < 16.0 then
    w_cmd = w_cmd_hold;
  elseif time < 20.0 then
    w_cmd = w_cmd_hold * (1.0 - (time - 16.0) / 4.0);
  else
    w_cmd = 0.0;
  end if;

  tracking_error = w_cmd - w_out;

  // ---- Discrete cascaded controller at 500 Hz ----
  // Speed loop (PI) -> current command (saturated)
  // Current loop (P + feedforward) -> voltage command (saturated)
  when sample(0, 1.0 / f_ctrl) then
    // PI speed controller with anti-windup (freeze integral on saturation)
    i_cmd = Kp_w * (w_cmd - w_out) + integ_w;
    if i_cmd > I_max then
      integ_w = pre(integ_w);
      i_sat = I_max;
    elseif i_cmd < -I_max then
      integ_w = pre(integ_w);
      i_sat = -I_max;
    else
      integ_w = pre(integ_w) + Ki_w * (w_cmd - w_out) / f_ctrl;
      i_sat = i_cmd;
    end if;
    // Current controller: back-EMF feedforward + proportional on current error
    v_cmd = R_a * i_sat + K_emf * w_motor + Kp_i * (i_sat - i_a);
    // Independent voltage saturation
    if v_cmd > V_max then
      v_applied = V_max;
    elseif v_cmd < -V_max then
      v_applied = -V_max;
    else
      v_applied = v_cmd;
    end if;
  end when;

  // ---- Sensor observations ----
  i_a_meas = i_a;
  w_out_meas = w_out;
  theta_out_meas = theta_out;
  theta_motor_meas = theta_motor;
  V_bus_meas = V_bus;
  alpha_meas = alpha_out;

  // ---- Verification criteria ----
  voltage_ok      = abs(v_applied) <= V_max + 1e-6;
  current_ok      = abs(i_a) <= I_max * 1.1;
  speed_ok        = abs(w_out) < 1e6;
  acceleration_ok = abs(alpha_out) < 1e6;
  soc_ok          = SOC >= 0.0 and SOC <= 1.0 + 1e-6;
  thermal_ok      = T_motor <= T_limit;
  tracking_ok     = if time >= 13.0 then abs(tracking_error) <= err_thresh else true;
  no_nan_inf      = true;

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "DC permanent-magnet servo with 100:1 gearbox, current-limited speed control at 500 Hz.
  Disturbance of 17.4 N.m applied during middle third (6.667–13.333 s).
  Motor parameters, battery, thermal, friction, and controller gains are engineering placeholders
  not specified in the originating requirement.")
  );
end DCServoSpeedF;