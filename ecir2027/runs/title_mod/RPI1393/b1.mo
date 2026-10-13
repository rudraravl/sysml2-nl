model ShapeLockShapeA
  "Six-section continuum arm with tendons and thermally activated stiffness";

  // ---- Scenario timing ----
  parameter Real fSample = 80.0 "Sampling frequency [Hz]";
  parameter Real tFinal = 8.0 "Scenario duration [s]";
  parameter Real tDistStart = tFinal / 3.0 "Disturbance start [s]";
  parameter Real tDistEnd = 2.0 * tFinal / 3.0 "Disturbance end [s]";
  parameter Real tTrackingCheck = 5.2 "Tracking error check time [s]";
  parameter Real trackBound = 0.061 "Primary tracking error bound after 5.2 s [m]";

  // ---- Arm geometry ----
  parameter Real L_section = 0.10 "Section length [m]";
  parameter Real L_total = 6.0 * L_section "Total arm length [m]";
  parameter Real d_tendon = 0.012 "Tendon offset radius [m]";
  parameter Real r_section = 0.010 "Section bending radius scale [m]";

  // ---- Thermal stiffness ----
  parameter Real T_low = 320.0 "Lower stiffness transition temperature [K]";
  parameter Real T_high = 345.0 "Upper stiffness transition temperature [K]";
  parameter Real T_amb = 295.0 "Ambient temperature [K]";
  parameter Real c_thermal = 50.0 "Thermal capacitance per section [J/K]";
  parameter Real R_thermal = 2.5 "Thermal resistance to ambient [K/W]";
  parameter Real EI_soft = 0.002 "Bending stiffness when soft [N.m^2]";
  parameter Real EI_stiff = 0.080 "Bending stiffness when stiff [N.m^2]";

  // ---- Actuator limits ----
  parameter Real F_cmd_max = 33.1 "Maximum tendon tension command magnitude [N]";
  parameter Real P_cmd_max = 18.0 "Maximum heater power command [W]";
  parameter Real F_dist = 3.0 "Tip load disturbance magnitude [N]";

  // ---- Gravity ----
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";

  // ---- Control gains ----
  parameter Real k_shape = 2.0 "Shape feedback gain [N/m]";
  parameter Real k_temp = 0.8 "Temperature tracking gain [W/K]";
  parameter Real k_tendon_bias = 5.0 "Tendon bias gain [N]";

  // ---- Targets ----
  parameter Real target_tip_x = 0.30 "Target tip x position [m]";
  parameter Real target_tip_y = 0.15 "Target tip y position [m]";
  parameter Real target_tip_z = 0.40 "Target tip z position [m]";

  // ---- Finite-state machine ----
  discrete Integer phase(start = 1) "1=move, 3=disturbance, 2=hold";

  // ---- Section states ----
  Real kappa[6](each start = 0.0) "Section curvature [1/m]";
  Real T_sec[6](each start = T_amb) "Section temperature [K]";
  Real EI_eff[6] "Effective bending stiffness [N.m^2]";
  Real P_sec[6] "Heater power per section [W]";
  Real F_tendon[3](each start = 0.0) "Tendon tensions [N]";

  // ---- Raw and limited commands ----
  Real F_cmd_raw[3] "Raw tendon tension commands [N]";
  Real P_cmd_raw[6] "Raw heater power commands [W]";
  Real F_cmd[3] "Limited tendon tension commands [N]";
  Real P_cmd[6] "Limited heater power commands [W]";

  // ---- Kinematics ----
  Real theta_cum[7](each start = 0.0) "Cumulative bending angle [rad]";
  Real x_node[7](each start = 0.0) "Node x [m]";
  Real y_node[7](each start = 0.0) "Node y [m]";
  Real z_node[7](each start = 0.0) "Node z [m]";
  Real tip_x "Tip x [m]";
  Real tip_y "Tip y [m]";
  Real tip_z "Tip z [m]";

  // ---- Undeformed geometry (shared frame) ----
  Real x_undeformed[7] "Undeformed node x [m]";
  Real z_undeformed[7] "Undeformed node z [m]";

  // ---- Disturbance ----
  Real F_dist_x "Disturbance force x [N]";
  Real F_dist_z "Disturbance force z [N]";
  Real dist_effect "Disturbance effect on curvature rate [1/(m.s)]";

  // ---- Sensors and errors ----
  Real tip_error "Tip tracking error [m]";
  Real shape_error "Final shape error bound [m]";
  Real tracking_error "Primary tracking error [m]";
  Real tracking_error_after "Tracking error after 5.2 s [m]";
  discrete Real tracking_error_sampled(start = 1.0) "Sampled tracking error [m]";

  // ---- Estimator ----
  Real kappa_est[6](each start = 0.0) "Estimated curvature [1/m]";
  Real tip_error_est "Estimated tip error [m]";

  // ---- Flags ----
  Boolean actuator_bound_ok "Actuator bounds satisfied";
  Boolean temperature_bound_ok "Temperature within range satisfied";
  Boolean curvature_bound_ok "Curvature finite bound satisfied";
  Boolean finite_state_ok "Finite-state machine valid";
  Boolean shape_error_ok "Final shape error bound satisfied";
  Boolean no_nan_inf "No NaN or infinite values detected";

protected
  function smoothStepStiff "Smooth unit step for stiffness transition"
    input Real x;
    input Real a;
    input Real b;
    input Real s "Steepness";
    output Real y;
  algorithm
    if x <= a then
      y := 0.0;
    elseif x >= b then
      y := 1.0;
    else
      y := 0.5 * (1.0 + Modelica.Math.tanh(s * (2.0 * (x - a) / (b - a) - 1.0)));
    end if;
  end smoothStepStiff;

  function isFiniteVal "Returns true if finite and not NaN"
    input Real x;
    output Boolean y;
  algorithm
    y := (x >= -1e30) and (x <= 1e30) and (x == x);
  end isFiniteVal;

equation

  // ---- Finite-state machine at 80 Hz ----
  when sample(0.0, 1.0 / fSample) then
    if time < tDistStart then
      phase = 1;
    elseif time < tDistEnd then
      phase = 3;
    else
      phase = 2;
    end if;
  end when;

  when sample(0.0, 1.0 / fSample) then
    if time >= tTrackingCheck then
      tracking_error_sampled = tracking_error;
    else
      tracking_error_sampled = pre(tracking_error_sampled);
    end if;
  end when;

  // ---- Temperature-dependent stiffness ----
  for i in 1:6 loop
    EI_eff[i] = EI_soft + (EI_stiff - EI_soft) * smoothStepStiff(T_sec[i], T_low, T_high, 4.0);
  end for;

  // ---- Thermal dynamics ----
  for i in 1:6 loop
    der(T_sec[i]) = (P_sec[i] - (T_sec[i] - T_amb) / R_thermal) / c_thermal;
  end for;

  // ---- Disturbance force and effect ----
  if time >= tDistStart and time <= tDistEnd then
    F_dist_x = F_dist * 0.7;
    F_dist_z = -F_dist * 0.7;
  else
    F_dist_x = 0.0;
    F_dist_z = 0.0;
  end if;

  dist_effect = (F_dist_z * L_section) / max(EI_eff[6], 1e-6) * 0.2;

  // ---- Curvature dynamics ----
  for i in 1:5 loop
    der(kappa[i]) = (d_tendon * (F_tendon[1] - F_tendon[2]) / 6.0
      - EI_eff[i] * kappa[i]) / max(EI_eff[i] * 0.5, 1e-6);
  end for;
  der(kappa[6]) = (d_tendon * (F_tendon[1] - F_tendon[2]) / 6.0
    - EI_eff[6] * kappa[6]) / max(EI_eff[6] * 0.5, 1e-6) + dist_effect;

  // ---- Raw commands (shape feedback) ----
  F_cmd_raw[1] = k_tendon_bias + k_shape * (target_tip_x - tip_x);
  F_cmd_raw[2] = k_tendon_bias - k_shape * (target_tip_x - tip_x);
  F_cmd_raw[3] = k_shape * (target_tip_z - tip_z);

  for i in 1:6 loop
    P_cmd_raw[i] = k_temp * (T_high - T_sec[i]);
  end for;

  // ---- Command limits ----
  for i in 1:3 loop
    F_cmd[i] = max(-F_cmd_max, min(F_cmd_max, F_cmd_raw[i]));
  end for;
  for i in 1:6 loop
    P_cmd[i] = max(0.0, min(P_cmd_max, P_cmd_raw[i]));
  end for;

  // ---- Actuator connections ----
  for i in 1:3 loop
    F_tendon[i] = F_cmd[i];
  end for;
  for i in 1:6 loop
    P_sec[i] = P_cmd[i];
  end for;

  // ---- Kinematics: arc integration with gravity sag ----
  theta_cum[1] = 0.0;
  x_node[1] = 0.0;
  y_node[1] = 0.0;
  z_node[1] = 0.0;

  for i in 1:6 loop
    theta_cum[i + 1] = theta_cum[i] + kappa[i] * L_section;
    x_node[i + 1] = x_node[i] + L_section * cos(theta_cum[i] + kappa[i] * L_section / 2.0);
    z_node[i + 1] = z_node[i] + L_section * sin(theta_cum[i] + kappa[i] * L_section / 2.0)
                   - g * i * 0.0004;
    y_node[i + 1] = y_node[i] + L_section * (F_tendon[3] / max(F_cmd_max, 1e-6)) * 0.05;
  end for;

  tip_x = x_node[7];
  tip_y = y_node[7];
  tip_z = z_node[7];

  // ---- Undeformed geometry ----
  for i in 1:7 loop
    x_undeformed[i] = (i - 1) * L_section;
    z_undeformed[i] = 0.0;
  end for;

  // ---- Sensors and errors ----
  tip_error = sqrt(
    (tip_x - target_tip_x) * (tip_x - target_tip_x) +
    (tip_y - target_tip_y) * (tip_y - target_tip_y) +
    (tip_z - target_tip_z) * (tip_z - target_tip_z));
  shape_error = tip_error;
  tracking_error = tip_error;
  tracking_error_after = tracking_error_sampled;

  // ---- Estimator (reduced-order) ----
  for i in 1:5 loop
    der(kappa_est[i]) = (d_tendon * (F_cmd[1] - F_cmd[2]) / 6.0
      - EI_eff[i] * kappa_est[i]) / max(EI_eff[i] * 0.5, 1e-6);
  end for;
  der(kappa_est[6]) = (d_tendon * (F_cmd[1] - F_cmd[2]) / 6.0
    - EI_eff[6] * kappa_est[6]) / max(EI_eff[6] * 0.5, 1e-6) + dist_effect;
  tip_error_est = tip_error;

  // ---- Bound checks ----
  actuator_bound_ok =
    (abs(F_cmd[1]) <= F_cmd_max + 1e-6) and
    (abs(F_cmd[2]) <= F_cmd_max + 1e-6) and
    (abs(F_cmd[3]) <= F_cmd_max + 1e-6) and
    (P_cmd[1] <= P_cmd_max + 1e-6) and
    (P_cmd[2] <= P_cmd_max + 1e-6) and
    (P_cmd[3] <= P_cmd_max + 1e-6) and
    (P_cmd[4] <= P_cmd_max + 1e-6) and
    (P_cmd[5] <= P_cmd_max + 1e-6) and
    (P_cmd[6] <= P_cmd_max + 1e-6);

  temperature_bound_ok =
    (T_sec[1] >= T_amb - 5.0) and (T_sec[1] <= T_high + 10.0) and
    (T_sec[6] >= T_amb - 5.0) and (T_sec[6] <= T_high + 10.0);

  curvature_bound_ok =
    (abs(kappa[1]) <= 50.0) and (abs(kappa[6]) <= 50.0) and
    (abs(kappa_est[1]) <= 50.0) and (abs(kappa_est[6]) <= 50.0);

  finite_state_ok = (phase >= 1) and (phase <= 3);

  shape_error_ok = (tracking_error_after <= trackBound);

  no_nan_inf =
    isFiniteVal(tip_error) and isFiniteVal(kappa[1]) and isFiniteVal(kappa[6]) and
    isFiniteVal(T_sec[1]) and isFiniteVal(T_sec[6]) and
    isFiniteVal(kappa_est[1]) and isFiniteVal(kappa_est[6]) and
    isFiniteVal(F_cmd[1]) and isFiniteVal(F_cmd[2]) and isFiniteVal(F_cmd[3]) and
    isFiniteVal(P_cmd[1]) and isFiniteVal(P_cmd[6]) and
    isFiniteVal(tip_x) and isFiniteVal(tip_y) and isFiniteVal(tip_z);

end ShapeLockShapeA;