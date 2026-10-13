model BLDCWheelRecoverF
  "BLDC wheel drive with FOC, feedforward control, disturbance observer, thermal and protection"
  // ==================== BATTERY ====================
  parameter Real V_bat_oc = 48.0 "Battery open-circuit voltage [V]";
  parameter Real R_bat = 0.05 "Battery internal resistance [Ohm]";
  parameter Real C_bus = 0.005 "DC bus capacitance [F]";

  // ==================== MOTOR (PMSM, surface-mount) ====================
  parameter Integer p = 4 "Number of pole pairs";
  parameter Real Rs = 0.15 "Stator phase resistance [Ohm]";
  parameter Real Ls = 0.0005 "Stator phase inductance [H]";
  parameter Real lambda_pm = 0.05 "PM flux linkage [Wb]";
  parameter Real Kt = 1.5 * p * lambda_pm "Torque constant [N.m/A]";

  // ==================== MECHANICAL ====================
  parameter Real J_rot = 0.0002 "Rotor inertia [kg.m2]";
  parameter Real b_rot = 0.00005 "Rotor viscous friction [N.m.s]";
  parameter Real n_gear = 9.0 "Gearbox ratio";
  parameter Real r_wheel = 0.12 "Wheel radius [m]";
  parameter Real J_load = 0.01 "Wheel/load inertia [kg.m2]";
  parameter Real b_load = 0.002 "Wheel/load viscous friction [N.m.s]";

  // ==================== THERMAL ====================
  parameter Real R_th = 0.5 "Winding thermal resistance [K/W]";
  parameter Real C_th = 150.0 "Winding thermal capacitance [J/K]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real T_limit = 85.0 "Thermal limit [degC]";

  // ==================== DISTURBANCE ====================
  parameter Real F_dist = 29.0 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 20.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * 20.0 / 3.0 "Disturbance end time [s]";

  // ==================== LIMITS ====================
  parameter Real V_bus_limit = 58.6 "DC bus voltage limit [V]";
  parameter Real I_q_max = 80.0 "Max quadrature current [A]";

  // ==================== CONTROL ====================
  parameter Real Kp_pos = 200.0 "Position loop proportional gain";
  parameter Real Kd_pos = 20.0 "Position loop derivative gain";
  parameter Real Kff = 1.0 "Feedforward gain";
  parameter Real K_obs = 30.0 "Disturbance observer gain";
  parameter Real tau_current = 0.001 "Current loop time constant [s]";

  // ==================== DERIVED ====================
  parameter Real J_eff = J_rot / (n_gear * n_gear) + J_load "Effective inertia at wheel [kg.m2]";
  parameter Real b_eff = b_rot / (n_gear * n_gear) + b_load "Effective friction at wheel [N.m.s]";

  // ==================== INITIAL ====================
  parameter Real theta0 = 0.0 "Initial wheel angle [rad]";

  // ==================== DYNAMIC STATES ====================
  Real theta_wheel(start = theta0, fixed = true) "Wheel angular position [rad]";
  Real omega_wheel(start = 0.0, fixed = true) "Wheel angular velocity [rad/s]";
  Real i_q(start = 0.0, fixed = true) "Quadrature-axis current [A]";
  Real d_hat(start = 0.0, fixed = true) "Disturbance force estimate [N]";
  Real T_winding(start = T_amb, fixed = true) "Winding temperature [degC]";
  Real V_bus(start = V_bat_oc, fixed = true) "DC bus voltage [V]";
  Real e_pos_peak(start = 0.0, fixed = true) "Peak absolute position error [rad]";

  // ==================== COMMAND ====================
  Real theta_cmd "Commanded wheel position [rad]";
  Real omega_cmd "Commanded wheel angular velocity [rad/s]";
  Real alpha_cmd "Commanded wheel angular acceleration [rad/s2]";

  // ==================== ELECTRICAL OBSERVABLES ====================
  Real omega_rot "Rotor angular velocity [rad/s]";
  Real omega_e "Electrical angular velocity [rad/s]";
  Real i_d "Direct-axis current [A]";
  Real i_q_unsat "Unsaturated quadrature current command [A]";
  Real i_q_cmd "Saturated quadrature current command [A]";
  Real V_d "Direct-axis voltage [V]";
  Real V_q "Quadrature-axis voltage [V]";
  Real I_bat "Battery current [A]";
  Real I_inv "Inverter DC-side current [A]";
  Real T_motor "Motor electromagnetic torque [N.m]";
  Real P_loss "Copper loss [W]";
  Real P_elec "Electrical power from DC bus [W]";

  // ==================== MECHANICAL OBSERVABLES ====================
  Real F_disturbance "Applied disturbance force [N]";
  Real T_dist "Disturbance torque at wheel [N.m]";
  Real alpha_nom "Nominal angular acceleration from model [rad/s2]";

  // ==================== TRACKING ====================
  Real e_pos "Position tracking error [rad]";
  Real e_pos_terminal "Terminal position error [rad]";

  // ==================== PROTECTION ====================
  Boolean V_bus_trip "DC bus over-voltage trip";
  Boolean T_winding_trip "Thermal over-temperature trip";
  Boolean trip "Combined protection trip";

equation
  // === Smooth sinusoidal motion command ===
  theta_cmd = 3.0 * Modelica.Math.sin(0.3 * time);
  omega_cmd = 3.0 * 0.3 * Modelica.Math.cos(0.3 * time);
  alpha_cmd = -3.0 * 0.3 * 0.3 * Modelica.Math.sin(0.3 * time);

  // === Disturbance (smooth onset/off during middle third of 20 s) ===
  F_disturbance = F_dist * 0.5 * (Modelica.Math.tanh(20.0 * (time - t_dist_start))
                                  - Modelica.Math.tanh(20.0 * (time - t_dist_end)));
  T_dist = F_disturbance * r_wheel;

  // === Tracking error ===
  e_pos = theta_cmd - theta_wheel;
  e_pos_terminal = e_pos;

  // === Control: feedforward + feedback + disturbance compensation ===
  i_q_unsat = (J_eff * alpha_cmd * Kff + b_eff * omega_cmd + d_hat * r_wheel
               + Kp_pos * e_pos + Kd_pos * (omega_cmd - omega_wheel)) / (Kt * n_gear);
  i_q_cmd = if i_q_unsat > I_q_max then I_q_max
            elseif i_q_unsat < -I_q_max then -I_q_max
            else i_q_unsat;

  // === Current loop (first-order dynamics) ===
  der(i_q) = (i_q_cmd - i_q) / tau_current;

  // === FOC: d-axis current commanded to zero ===
  i_d = 0.0;

  // === Motor torque ===
  T_motor = Kt * i_q;

  // === Mechanical dynamics at wheel side ===
  der(theta_wheel) = omega_wheel;
  J_eff * der(omega_wheel) = T_motor * n_gear - T_dist - b_eff * omega_wheel;

  // === Kinematic relationships ===
  omega_rot = n_gear * omega_wheel;
  omega_e = p * omega_rot;

  // === Motor electrical (d-q frame voltage equations) ===
  V_d = Rs * i_d - omega_e * Ls * i_q;
  V_q = Rs * i_q + omega_e * Ls * i_d + lambda_pm * omega_e;

  // === Power balance ===
  P_elec = 1.5 * (V_d * i_d + V_q * i_q);
  P_loss = 1.5 * Rs * (i_d * i_d + i_q * i_q);

  // === DC bus dynamics (battery + capacitance + inverter load) ===
  I_bat = (V_bat_oc - V_bus) / R_bat;
  I_inv = P_elec * V_bus / (V_bus * V_bus + 0.01);
  C_bus * der(V_bus) = I_bat - I_inv;

  // === Disturbance observer ===
  // Nominal acceleration from known motor torque and friction (no disturbance)
  alpha_nom = (T_motor * n_gear - b_eff * omega_wheel) / J_eff;
  // Observer uses acceleration residual to estimate disturbance force
  der(d_hat) = K_obs * (alpha_nom - der(omega_wheel)) * J_eff / r_wheel - K_obs * d_hat;

  // === Thermal dynamics ===
  C_th * der(T_winding) = P_loss - (T_winding - T_amb) / R_th;

  // === Peak error tracking (running maximum) ===
  der(e_pos_peak) = 1000.0 * max(0.0, abs(e_pos) - e_pos_peak);

  // === Protection ===
  V_bus_trip = V_bus > V_bus_limit;
  T_winding_trip = T_winding > T_limit;
  trip = V_bus_trip or T_winding_trip;

  annotation(
    Documentation(info = "BLDC/PMSM wheel drive with field-oriented control, "
                 "feedforward motion command, disturbance observer, thermal model, "
                 "and protection monitoring. 48 V bus, 4 pole-pair motor, 9:1 gearbox, "
                 "0.12 m wheel. Disturbance of 29 N applied during middle third. "
                 "Run at 500 Hz for 20 s. Verification: tracking error below 0.032 rad "
                 "after 13 s, bus voltage below 58.6 V, no protection trip."),
    experiment(StartTime = 0.0, StopTime = 20.0, Interval = 0.002, Tolerance = 1e-6)
  );
end BLDCWheelRecoverF;