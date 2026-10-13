model ShapeLockShapeC
  "Six-section continuum arm with 3 tendons, thermally activated stiffness, and reduced-order shape feedback";

  // ===== Physical parameters =====
  parameter Real L_sec = 0.04 "Section length [m]";
  parameter Real r_tendon = 0.03 "Tendon moment arm [m]";
  parameter Real T_amb = 320.0 "Ambient / low temperature [K]";
  parameter Real T_high = 345.0 "High activation temperature [K]";
  parameter Real k_min = 8.0 "Bending stiffness at T_amb [N.m/rad]";
  parameter Real k_max = 30.0 "Bending stiffness at T_high [N.m/rad]";
  parameter Real J_sec = 1.0e-4 "Section rotary inertia [kg.m2]";
  parameter Real b_sec = 0.02 "Section damping [N.m.s/rad]";
  parameter Real C_th = 10.0 "Thermal capacitance per section [J/K]";
  parameter Real h_th = 1.0 "Thermal conductance to ambient [W/K]";
  parameter Real m_sec = 0.03 "Section mass [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_max = 42.3 "Maximum tendon command [N]";
  parameter Real P_max = 18.0 "Maximum heater command [W]";
  parameter Real F_dist = 5.4 "Disturbance tip load magnitude [N]";

  // ===== Target shape =====
  parameter Real x_target = 0.08 "Target tip x [m]";
  parameter Real z_target = 0.22 "Target tip z [m]";

  // ===== Controller gains =====
  parameter Real Kp_m = 30.0 "Proportional gain on tip error [N.m/m]";
  parameter Real Kd_m = 5.0 "Derivative gain [N.m.s/m]";
  parameter Real Ki_m = 3.0 "Integral gain [N.m/(m.s)]";
  parameter Real Kp_temp = 1.0 "Temperature controller gain [W/K]";
  parameter Real T_set_hold = 340.0 "Hold temperature setpoint [K]";
  parameter Real F_bias = 5.0 "Tendon bias tension [N]";
  parameter Real integ_limit = 0.3 "Integral anti-windup limit [m.s]";

  // ===== Continuous dynamic states =====
  Real theta[6] "Section bending angle [rad]";
  Real omega[6] "Angular velocity [rad/s]";
  Real T_sec[6] "Section temperature [K]";
  Real integ_err "Integral of x error [m.s]";

  // ===== Discrete state =====
  discrete Real mode_val(start = 1.0, fixed = true) "1 = move, 2 = hold";

  // ===== Commands and actuated outputs =====
  Real M_des "Desired bending moment [N.m]";
  Real F_cmd[3] "Commanded tendon tensions [N]";
  Real P_cmd[6] "Commanded heater powers [W]";
  Real F_tendon[3] "Saturated tendon tensions [N]";
  Real P_heater[6] "Saturated heater powers [W]";

  // ===== Sensors =====
  Real F_sensor[3] "Tendon force sensors [N]";
  Real kappa_sensor[6] "Curvature sensors [1/m]";
  Real T_sensor[6] "Temperature sensors [K]";
  Real x_tip "Tip x position [m]";
  Real z_tip "Tip z position [m]";
  Real x_tip_undef "Undeformed tip x [m]";
  Real z_tip_undef "Undeformed tip z [m]";

  // ===== Computed quantities =====
  Real cum_angle[7] "Cumulative angle from base [rad]";
  Real EI[6] "Bending stiffness per section [N.m/rad]";
  Real tip_error "Primary tracking error [m]";
  Real F_disturbance "Applied disturbance force [N]";
  Real M_gravity[6] "Gravity moment per section [N.m]";
  Real M_tendon[6] "Tendon moment per section [N.m]";
  Real M_dist[6] "Disturbance moment per section [N.m]";
  Real err_x "Tip x error [m]";
  Real err_z "Tip z error [m]";
  Real err_x_rate "Tip x velocity [m/s]";

  // ===== Bound-check intermediate variables =====
  Real at1 "abs theta 1";
  Real at2 "abs theta 2";
  Real at3 "abs theta 3";
  Real at4 "abs theta 4";
  Real at5 "abs theta 5";
  Real at6 "abs theta 6";
  Real mt12 "max abs theta 1-2";
  Real mt34 "max abs theta 3-4";
  Real mt56 "max abs theta 5-6";
  Real mt1234 "max abs theta 1-4";
  Real mxT12 "max T 1-2";
  Real mxT34 "max T 3-4";
  Real mxT56 "max T 5-6";
  Real mxT1234 "max T 1-4";
  Real mnT12 "min T 1-2";
  Real mnT34 "min T 3-4";
  Real mnT56 "min T 5-6";
  Real mnT1234 "min T 1-4";
  Real mxP12 "max P 1-2";
  Real mxP34 "max P 3-4";
  Real mxP56 "max P 5-6";
  Real mxP1234 "max P 1-4";

  // ===== Bound-check results =====
  Boolean actuator_ok;
  Boolean curvature_ok;
  Boolean temperature_ok;
  Boolean finite_state_ok;
  Boolean shape_error_ok;
  Real max_theta_abs "Maximum absolute section angle [rad]";
  Real max_T_val "Maximum temperature [K]";
  Real min_T_val "Minimum temperature [K]";
  Real max_F_val "Maximum tendon force [N]";
  Real min_F_val "Minimum tendon force [N]";
  Real max_P_val "Maximum heater power [W]";
  Real state_norm "L1 norm of states for finiteness proxy";

initial equation
  for i in 1:6 loop
    theta[i] = 0.0;
    omega[i] = 0.0;
    T_sec[i] = T_amb;
  end for;
  integ_err = 0.0;

equation
  // ---- Cumulative angle ----
  cum_angle[1] = 0.0;
  cum_angle[2] = theta[1];
  cum_angle[3] = cum_angle[2] + theta[2];
  cum_angle[4] = cum_angle[3] + theta[3];
  cum_angle[5] = cum_angle[4] + theta[4];
  cum_angle[6] = cum_angle[5] + theta[5];
  cum_angle[7] = cum_angle[6] + theta[6];

  // ---- Tip position and undeformed geometry (shared z-up frame) ----
  x_tip = L_sec * (sin(cum_angle[2]) + sin(cum_angle[3]) + sin(cum_angle[4])
                  + sin(cum_angle[5]) + sin(cum_angle[6]) + sin(cum_angle[7]));
  z_tip = L_sec * (cos(cum_angle[2]) + cos(cum_angle[3]) + cos(cum_angle[4])
                  + cos(cum_angle[5]) + cos(cum_angle[6]) + cos(cum_angle[7]));
  x_tip_undef = 0.0;
  z_tip_undef = 6.0 * L_sec;

  // ---- Bending stiffness from temperature (clamped linear interpolation) ----
  for i in 1:6 loop
    EI[i] = k_min + (k_max - k_min)
      * max(0.0, min(1.0, (T_sec[i] - T_amb) / (T_high - T_amb)));
  end for;

  // ---- Sensors ----
  F_sensor[1] = F_tendon[1];
  F_sensor[2] = F_tendon[2];
  F_sensor[3] = F_tendon[3];
  for i in 1:6 loop
    kappa_sensor[i] = theta[i] / L_sec;
    T_sensor[i] = T_sec[i];
  end for;

  // ---- Disturbance: 5.4 N tip load during middle third (4 s to 8 s) ----
  if time >= 4.0 and time <= 8.0 then
    F_disturbance = F_dist;
  else
    F_disturbance = 0.0;
  end if;

  // ---- Gravity moment (weight of sections above section i) ----
  for i in 1:6 loop
    M_gravity[i] = -m_sec * g * (7 - i) * L_sec * sin(cum_angle[i + 1]);
  end for;

  // ---- Tendon moment (antagonistic pair F1-F2; F3 for bias/shape) ----
  for i in 1:6 loop
    M_tendon[i] = r_tendon * (F_tendon[1] - F_tendon[2]);
  end for;

  // ---- Disturbance moment (horizontal tip load) ----
  for i in 1:6 loop
    M_dist[i] = F_disturbance * (7 - i) * L_sec * cos(cum_angle[i + 1]);
  end for;

  // ---- Section angular dynamics ----
  for i in 1:6 loop
    der(theta[i]) = omega[i];
    J_sec * der(omega[i]) = M_tendon[i] + M_gravity[i] + M_dist[i]
      - EI[i] * theta[i] - b_sec * omega[i];
  end for;

  // ---- Thermal dynamics ----
  for i in 1:6 loop
    C_th * der(T_sec[i]) = P_heater[i] - h_th * (T_sec[i] - T_amb);
  end for;

  // ---- Tip tracking errors ----
  err_x = x_target - x_tip;
  err_z = z_target - z_tip;
  err_x_rate = -L_sec * (
      cos(cum_angle[2]) * omega[1] + cos(cum_angle[3]) * omega[2]
    + cos(cum_angle[4]) * omega[3] + cos(cum_angle[5]) * omega[4]
    + cos(cum_angle[6]) * omega[5] + cos(cum_angle[7]) * omega[6]);
  tip_error = sqrt(err_x * err_x + err_z * err_z);

  // ---- Integral with anti-windup ----
  der(integ_err) = if (mode_val < 1.5 and abs(integ_err) < integ_limit) then err_x else 0.0;

  // ---- Mode transition to hold at 7.8 s ----
  when time >= 7.8 then
    mode_val = 2.0;
  end when;

  // ---- Shape controller: PID on tip error -> desired moment ----
  M_des = if mode_val < 1.5 then
      (Kp_m * err_x + Kd_m * err_x_rate + Ki_m * integ_err)
    else
      0.3 * (Kp_m * err_x + Kd_m * err_x_rate + Ki_m * integ_err);

  // ---- Map desired moment to antagonistic tendon tensions ----
  F_cmd[1] = F_bias + max(0.0, M_des) / r_tendon;
  F_cmd[2] = F_bias + max(0.0, -M_des) / r_tendon;
  F_cmd[3] = F_bias;

  // ---- Temperature controller: heat during hold ----
  for i in 1:6 loop
    P_cmd[i] = if mode_val > 1.5 then Kp_temp * (T_set_hold - T_sec[i]) else 0.0;
  end for;

  // ---- Actuator saturation ----
  for j in 1:3 loop
    F_tendon[j] = max(0.0, min(F_max, F_cmd[j]));
  end for;
  for i in 1:6 loop
    P_heater[i] = max(0.0, min(P_max, P_cmd[i]));
  end for;

  // ---- Bound-check intermediates (scalar two-argument max/min) ----
  at1 = abs(theta[1]);
  at2 = abs(theta[2]);
  at3 = abs(theta[3]);
  at4 = abs(theta[4]);
  at5 = abs(theta[5]);
  at6 = abs(theta[6]);
  mt12 = max(at1, at2);
  mt34 = max(at3, at4);
  mt56 = max(at5, at6);
  mt1234 = max(mt12, mt34);
  max_theta_abs = max(mt1234, mt56);

  mxT12 = max(T_sec[1], T_sec[2]);
  mxT34 = max(T_sec[3], T_sec[4]);
  mxT56 = max(T_sec[5], T_sec[6]);
  mxT1234 = max(mxT12, mxT34);
  max_T_val = max(mxT1234, mxT56);

  mnT12 = min(T_sec[1], T_sec[2]);
  mnT34 = min(T_sec[3], T_sec[4]);
  mnT56 = min(T_sec[5], T_sec[6]);
  mnT1234 = min(mnT12, mnT34);
  min_T_val = min(mnT1234, mnT56);

  mxP12 = max(P_heater[1], P_heater[2]);
  mxP34 = max(P_heater[3], P_heater[4]);
  mxP56 = max(P_heater[5], P_heater[6]);
  mxP1234 = max(mxP12, mxP34);
  max_P_val = max(mxP1234, mxP56);

  max_F_val = max(F_tendon[1], max(F_tendon[2], F_tendon[3]));
  min_F_val = min(F_tendon[1], min(F_tendon[2], F_tendon[3]));

  state_norm = abs(theta[1]) + abs(theta[2]) + abs(theta[3])
    + abs(theta[4]) + abs(theta[5]) + abs(theta[6])
    + abs(omega[1]) + abs(omega[2]) + abs(omega[3])
    + abs(omega[4]) + abs(omega[5]) + abs(omega[6])
    + abs(T_sec[1]) + abs(T_sec[2]) + abs(T_sec[3])
    + abs(T_sec[4]) + abs(T_sec[5]) + abs(T_sec[6])
    + abs(integ_err);

  // ---- Bound checks ----
  actuator_ok = (max_F_val <= F_max + 0.01) and (max_P_val <= P_max + 0.01)
    and (min_F_val >= -0.01);
  curvature_ok = max_theta_abs <= 1.5708;
  temperature_ok = (min_T_val >= T_amb - 1.0) and (max_T_val <= T_high + 5.0);
  finite_state_ok = state_norm < 1.0e6;
  shape_error_ok = (time < 7.8) or (tip_error <= 0.047);

  annotation(
    Experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "ShapeLockShapeC: six-section continuum arm (3 tendons, 6 heaters) with reduced-order curvature feedback. Thermal stiffness varies 320-345 K. 125 Hz (Interval=0.008), 12 s run. Disturbance 5.4 N at tip during 4-8 s. Target shape at (0.08, 0.22) m. Tracking error < 0.047 m after 7.8 s.")
  );

end ShapeLockShapeC;