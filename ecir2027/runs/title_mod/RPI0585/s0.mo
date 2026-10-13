model CableWinchSpeedC
  "Cable winch speed control with cascaded motor-speed and cable-tension loops"

  // === Physical parameters ===
  parameter Real V_max = 66.2 "Max voltage command [V]";
  parameter Real V_nom = 72.0 "Nominal battery voltage [V]";
  parameter Real R_bat = 0.08 "Battery internal resistance [Ohm]";
  parameter Real E_bat = 5.184e6 "Battery energy capacity [J] (72V 20Ah)";

  parameter Real R_a = 0.5 "Armature resistance [Ohm]";
  parameter Real L_a = 5e-3 "Armature inductance [H]";
  parameter Real K_t = 0.08 "Torque constant [N.m/A]";
  parameter Real K_e = 0.08 "Back-EMF constant [V.s/rad]";
  parameter Real J_m = 1e-3 "Motor inertia [kg.m2]";
  parameter Real b_m = 1e-3 "Motor viscous friction [N.m.s/rad]";

  parameter Real J_d = 1e-2 "Drum inertia [kg.m2]";
  parameter Real b_d = 1e-2 "Drum viscous friction [N.m.s/rad]";
  parameter Real N_gear = 45.0 "Gearbox ratio";
  parameter Real eta_g = 0.90 "Gearbox efficiency";
  parameter Real r_drum = 0.09 "Drum radius [m]";
  parameter Real m_load = 140.0 "Payload mass [kg]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real travel_max = 12.0 "Max cable travel [m]";
  parameter Real T_dist = 10.8 "Disturbance torque at drum [N.m]";

  parameter Real R_th = 0.05 "Thermal resistance [K/W]";
  parameter Real C_th = 500.0 "Thermal capacitance [J/K]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";

  // === Controller parameters ===
  parameter Real dt_ctrl = 1.0 / 125.0 "Controller sample time [s]";
  parameter Real v_ref_hold = 1.0 "Hold speed reference [m/s]";
  parameter Real Kp_w = 100.0 "Speed loop proportional gain";
  parameter Real Ki_w = 400.0 "Speed loop integral gain";
  parameter Real Kp_i = 8.0 "Current loop proportional gain";
  parameter Real Ki_i = 500.0 "Current loop integral gain";
  parameter Real I_max = 120.0 "Current limit [A]";
  parameter Real T_max_thermal = 85.0 "Max winding temperature [degC]";
  parameter Real SOC_min = 0.05 "Min state of charge";
  parameter Real v_max_bound = 3.0 "Max speed bound [m/s]";
  parameter Real a_max_bound = 10.0 "Max acceleration bound [m/s2]";

  // === Continuous states ===
  Real i_a(start = 0.0) "Armature/phase current [A]";
  Real omega_d(start = 0.0) "Drum angular velocity [rad/s]";
  Real theta_m(start = 0.0) "Rotor position [rad]";
  Real theta_d(start = 0.0) "Drum/output position [rad]";
  Real x_load(start = 0.0) "Payload height [m]";
  Real SOC(start = 1.0) "State of charge [0-1]";
  Real T_winding(start = T_amb) "Winding temperature [degC]";

  // === Discrete controller states ===
  discrete Real v_ref(start = 0.0) "Speed reference [m/s]";
  discrete Real i_cmd(start = 0.0) "Current command [A]";
  discrete Real i_cmd_sat(start = 0.0) "Saturated current command [A]";
  discrete Real V_cmd(start = 0.0) "Voltage command [V]";
  discrete Real V_cmd_sat(start = 0.0) "Saturated voltage command [V]";
  discrete Real integ_w(start = 0.0) "Speed loop integrator state";
  discrete Real integ_i(start = 0.0) "Current loop integrator state";
  discrete Real speed_err(start = 0.0) "Speed error [m/s]";
  discrete Real curr_err(start = 0.0) "Current error [A]";

  // === Derived continuous quantities (sensors) ===
  Real omega_m "Motor angular velocity [rad/s]";
  Real v_load "Output/payload velocity [m/s]";
  Real a_load "Payload acceleration [m/s2]";
  Real T_motor "Motor torque [N.m]";
  Real T_gravity "Gravity torque at drum [N.m]";
  Real T_cable "Cable tension [N]";
  Real V_bus "DC bus voltage [V]";
  Real T_disturbance "Disturbance torque [N.m]";
  Real J_eq "Equivalent inertia at drum [kg.m2]";
  Real b_eq "Equivalent friction at drum [N.m.s/rad]";
  Real T_drive "Drive torque at drum [N.m]";
  Real P_loss "Copper loss [W]";
  Real P_batt "Battery power [W]";
  Real tracking_err "Speed tracking error [m/s]";

equation
  // === Kinematics ===
  omega_m = N_gear * omega_d;
  v_load = omega_d * r_drum;
  a_load = der(omega_d) * r_drum;
  der(theta_m) = omega_m;
  der(theta_d) = omega_d;
  der(x_load) = v_load;

  // === Equivalent parameters reflected to drum ===
  J_eq = J_d + J_m / (N_gear * N_gear) + m_load * r_drum * r_drum;
  b_eq = b_d + b_m / (N_gear * N_gear);

  // === Disturbance: middle third (4 to 8 s) ===
  if time >= 4.0 and time < 8.0 then
    T_disturbance = T_dist;
  else
    T_disturbance = 0.0;
  end if;

  // === Torques ===
  T_gravity = m_load * g * r_drum;
  T_motor = K_t * i_a;
  T_drive = T_motor * N_gear * eta_g;
  T_cable = m_load * (g + a_load);

  // === Mechanical dynamics (combined inertia at drum) ===
  J_eq * der(omega_d) = T_drive - T_gravity - T_disturbance - b_eq * omega_d;

  // === Motor electrical dynamics ===
  L_a * der(i_a) = V_cmd_sat - R_a * i_a - K_e * omega_m;

  // === Battery with droop ===
  V_bus = V_nom - R_bat * i_a;
  P_batt = V_bus * i_a;
  der(SOC) = -P_batt / E_bat;

  // === Thermal model ===
  P_loss = i_a * i_a * R_a;
  C_th * der(T_winding) = P_loss - (T_winding - T_amb) / R_th;

  // === Tracking error (primary metric after 7.8 s) ===
  tracking_err = if time >= 7.8 then abs(v_ref - v_load) else 0.0;

  // === Discrete controller at 125 Hz ===
  when sample(0, dt_ctrl) then
    // Trapezoidal speed reference: accel 0-4s, hold 4-8s, decel 8-12s
    if time < 4.0 then
      v_ref = v_ref_hold * time / 4.0;
    elseif time < 8.0 then
      v_ref = v_ref_hold;
    elseif time < 12.0 then
      v_ref = v_ref_hold * (12.0 - time) / 4.0;
    else
      v_ref = 0.0;
    end if;

    // Speed error (output speed feedback)
    speed_err = v_ref - v_load;

    // Outer loop: speed PI with gravity/tension feedforward -> current command
    i_cmd = Kp_w * speed_err + pre(integ_w)
            + T_gravity / (N_gear * eta_g * K_t);

    // Current limiting with anti-windup
    if i_cmd > I_max then
      i_cmd_sat = I_max;
      integ_w = pre(integ_w);
    elseif i_cmd < -I_max then
      i_cmd_sat = -I_max;
      integ_w = pre(integ_w);
    else
      i_cmd_sat = i_cmd;
      integ_w = pre(integ_w) + Ki_w * speed_err * dt_ctrl;
    end if;

    // Current error (armature current feedback)
    curr_err = i_cmd_sat - i_a;

    // Inner loop: current PI with back-EMF feedforward -> voltage command
    V_cmd = Kp_i * curr_err + pre(integ_i) + K_e * omega_m + R_a * i_cmd_sat;

    // Voltage limiting with anti-windup
    if V_cmd > V_max then
      V_cmd_sat = V_max;
      integ_i = pre(integ_i);
    elseif V_cmd < -V_max then
      V_cmd_sat = -V_max;
      integ_i = pre(integ_i);
    else
      V_cmd_sat = V_cmd;
      integ_i = pre(integ_i) + Ki_i * curr_err * dt_ctrl;
    end if;
  end when;

  // === Bound checks (warnings) ===
  assert(abs(V_cmd_sat) <= V_max + 1e-6, "Voltage bound violated", AssertionLevel.warning);
  assert(abs(i_a) <= I_max * 2.0, "Current bound exceeded", AssertionLevel.warning);
  assert(abs(v_load) <= v_max_bound, "Speed bound exceeded", AssertionLevel.warning);
  assert(abs(a_load) <= a_max_bound, "Acceleration bound exceeded", AssertionLevel.warning);
  assert(SOC >= SOC_min, "SOC bound violated", AssertionLevel.warning);
  assert(T_winding <= T_max_thermal, "Thermal bound exceeded", AssertionLevel.warning);

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "Cable winch speed control (CableWinchSpeedC).
      Plant: 72V motor, 45:1 gearbox (eff=0.90), 0.09m drum, 140kg payload, 12m travel.
      Controller: 125Hz cascaded motor-speed (outer) and cable-tension/current (inner) loops.
      Voltage limit: 66.2V. Current limit: 120A.
      Disturbance: 10.8 N.m at drum during 4-8s (middle third).
      Tracking target: < 0.263 m/s after 7.8s.
      Sensors: armature current, rotor position, output speed, DC-bus voltage.
      Includes: gearbox efficiency, mechanical friction, battery droop, rotating inertia, thermal model.")
  );
end CableWinchSpeedC;