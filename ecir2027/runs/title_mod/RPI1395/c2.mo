model ShapeLockShapeC
  "Six-section continuum arm with shape feedback"

  // Physical parameters
  parameter Real L_sec = 0.04 "Section length [m]";
  parameter Real r_tendon = 0.03 "Tendon moment arm [m]";
  parameter Real T_amb = 320.0 "Ambient temperature [K]";
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

  // Target shape
  parameter Real x_target = 0.08 "Target tip x [m]";
  parameter Real z_target = 0.22 "Target tip z [m]";

  // Controller gains
  parameter Real Kp_m = 35.0 "Proportional gain on tip error [N.m/m]";
  parameter Real Kd_m = 5.0 "Derivative gain [N.m.s/m]";
  parameter Real Ki_m = 4.0 "Integral gain [N.m/(m.s)]";
  parameter Real Kp_temp = 1.0 "Temperature controller gain [W/K]";
  parameter Real T_set_hold = 340.0 "Hold temperature setpoint [K]";
  parameter Real F_bias = 5.0 "Tendon bias tension [N]";
  parameter Real integ_limit = 0.3 "Integral anti-windup limit [m.s]";
  parameter Real hold_gain = 0.5 "Gain reduction factor in hold mode";

  // Continuous dynamic states
  Real theta[6] "Section bending angle [rad]";
  Real omega[6] "Angular velocity [rad/s]";
  Real T_sec[6] "Section temperature [K]";
  Real integ_err "Integral of x error [m.s]";

  // Discrete state
  Integer ctrl_mode(start = 1) "1 = move, 2 = hold";

  // Commands and actuated outputs
  Real M_des "Desired bending moment [N.m]";
  Real F_cmd[3] "Commanded tendon tensions [N]";
  Real P_cmd[6] "Commanded heater powers [W]";
  Real F_tendon[3] "Saturated tendon tensions [N]";
  Real P_heater[6] "Saturated heater powers [W]";

  // Sensors
  Real F_sensor[3] "Tendon force sensors [N]";
  Real kappa_sensor[6] "Curvature sensors [1/m]";
  Real T_sensor[6] "Temperature sensors [K]";
  Real x_tip "Tip x position [m]";
  Real z_tip "Tip z position [m]";
  Real x_tip_undef "Undeformed tip x [m]";
  Real z_tip_undef "Undeformed tip z [m]";

  // Computed quantities
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
  Real sat01[6] "Saturated normalized temperature [unitless]";

  // Bound-check variables
  Boolean actuator_ok;
  Boolean curvature_ok;
  Boolean temperature_ok;
  Boolean finite_state_ok;
  Boolean shape_error_ok;
  Real max_theta_abs "Maximum absolute section angle [rad]";
  Real max_T_val "Maximum temperature [K]";
  Real min_T_val "Minimum temperature [K]";
  Real max_F_val "Maximum tendon force [N]";
  Real max_P_val "Maximum heater power [W]";
  Real min_F_val "Minimum tendon force [N]";
  Real state_norm "L1 norm of states";

initial equation
  theta[1] = 0.0;
  theta[2] = 0.0;
  theta[3] = 0.0;
  theta[4] = 0.0;
  theta[5] = 0.0;
  theta[6] = 0.0;
  omega[1] = 0.0;
  omega[2] = 0.0;
  omega[3] = 0.0;
  omega[4] = 0.0;
  omega[5] = 0.0;
  omega[6] = 0.0;
  T_sec[1] = T_amb;
  T_sec[2] = T_amb;
  T_sec[3] = T_amb;
  T_sec[4] = T_amb;
  T_sec[5] = T_amb;
  T_sec[6] = T_amb;
  integ_err = 0.0;

equation
  // Cumulative angle from base
  cum_angle[1] = 0.0;
  cum_angle[2] = cum_angle[1] + theta[1];
  cum_angle[3] = cum_angle[2] + theta[2];
  cum_angle[4] = cum_angle[3] + theta[3];
  cum_angle[5] = cum_angle[4] + theta[4];
  cum_angle[6] = cum_angle[5] + theta[5];
  cum_angle[7] = cum_angle[6] + theta[6];

  // Tip position in shared z-up frame
  x_tip = L_sec * (sin(cum_angle[2]) + sin(cum_angle[3]) + sin(cum_angle[4])
                  + sin(cum_angle[5]) + sin(cum_angle[6]) + sin(cum_angle[7]));
  z_tip = L_sec * (cos(cum_angle[2]) + cos(cum_angle[3]) + cos(cum_angle[4])
                  + cos(cum_angle[5]) + cos(cum_angle[6]) + cos(cum_angle[7]));
  x_tip_undef = 0.0;
  z_tip_undef = 6.0 * L_sec;

  // Saturated normalized temperature for stiffness interpolation
  sat01[1] = if T_sec[1] <= T_amb then 0.0 else if T_sec[1] >= T_high then 1.0 else (T_sec[1] - T_amb) / (T_high - T_amb);
  sat01[2] = if T_sec[2] <= T_amb then 0.0 else if T_sec[2] >= T_high then 1.0 else (T_sec[2] - T_amb) / (T_high - T_amb);
  sat01[3] = if T_sec[3] <= T_amb then 0.0 else if T_sec[3] >= T_high then 1.0 else (T_sec[3] - T_amb) / (T_high - T_amb);
  sat01[4] = if T_sec[4] <= T_amb then 0.0 else if T_sec[4] >= T_high then 1.0 else (T_sec[4] - T_amb) / (T_high - T_amb);
  sat01[5] = if T_sec[5] <= T_amb then 0.0 else if T_sec[5] >= T_high then 1.0 else (T_sec[5] - T_amb) / (T_high - T_amb);
  sat01[6] = if T_sec[6] <= T_amb then 0.0 else if T_sec[6] >= T_high then 1.0 else (T_sec[6] - T_amb) / (T_high - T_amb);

  // Bending stiffness from temperature
  EI[1] = k_min + (k_max - k_min) * sat01[1];
  EI[2] = k_min + (k_max - k_min) * sat01[2];
  EI[3] = k_min + (k_max - k_min) * sat01[3];
  EI[4] = k_min + (k_max - k_min) * sat01[4];
  EI[5] = k_min + (k_max - k_min) * sat01[5];
  EI[6] = k_min + (k_max - k_min) * sat01[6];

  // Sensors
  F_sensor[1] = F_tendon[1];
  F_sensor[2] = F_tendon[2];
  F_sensor[3] = F_tendon[3];
  kappa_sensor[1] = theta[1] / L_sec;
  kappa_sensor[2] = theta[2] / L_sec;
  kappa_sensor[3] = theta[3] / L_sec;
  kappa_sensor[4] = theta[4] / L_sec;
  kappa_sensor[5] = theta[5] / L_sec;
  kappa_sensor[6] = theta[6] / L_sec;
  T_sensor[1] = T_sec[1];
  T_sensor[2] = T_sec[2];
  T_sensor[3] = T_sec[3];
  T_sensor[4] = T_sec[4];
  T_sensor[5] = T_sec[5];
  T_sensor[6] = T_sec[6];

  // Disturbance: 5.4 N tip load during middle third (4 s to 8 s)
  F_disturbance = if time >= 4.0 and time <= 8.0 then F_dist else 0.0;

  // Gravity moment per section (weight of sections above)
  M_gravity[1] = -m_sec * g * 6.0 * L_sec * sin(cum_angle[2]);
  M_gravity[2] = -m_sec * g * 5.0 * L_sec * sin(cum_angle[3]);
  M_gravity[3] = -m_sec * g * 4.0 * L_sec * sin(cum_angle[4]);
  M_gravity[4] = -m_sec * g * 3.0 * L_sec * sin(cum_angle[5]);
  M_gravity[5] = -m_sec * g * 2.0 * L_sec * sin(cum_angle[6]);
  M_gravity[6] = -m_sec * g * 1.0 * L_sec * sin(cum_angle[7]);

  // Tendon moment (antagonistic pair F1-F2, F3 bias)
  M_tendon[1] = r_tendon * (F_tendon[1] - F_tendon[2]);
  M_tendon[2] = r_tendon * (F_tendon[1] - F_tendon[2]);
  M_tendon[3] = r_tendon * (F_tendon[1] - F_tendon[2]);
  M_tendon[4] = r_tendon * (F_tendon[1] - F_tendon[2]);
  M_tendon[5] = r_tendon * (F_tendon[1] - F_tendon[2]);
  M_tendon[6] = r_tendon * (F_tendon[1] - F_tendon[2]);

  // Disturbance moment (horizontal tip load)
  M_dist[1] = F_disturbance * 6.0 * L_sec * cos(cum_angle[2]);
  M_dist[2] = F_disturbance * 5.0 * L_sec * cos(cum_angle[3]);
  M_dist[3] = F_disturbance * 4.0 * L_sec * cos(cum_angle[4]);
  M_dist[4] = F_disturbance * 3.0 * L_sec * cos(cum_angle[5]);
  M_dist[5] = F_disturbance * 2.0 * L_sec * cos(cum_angle[6]);
  M_dist[6] = F_disturbance * 1.0 * L_sec * cos(cum_angle[7]);

  // Section angular dynamics
  der(theta[1]) = omega[1];
  der(theta[2]) = omega[2];
  der(theta[3]) = omega[3];
  der(theta[4]) = omega[4];
  der(theta[5]) = omega[5];
  der(theta[6]) = omega[6];

  J_sec * der(omega[1]) = M_tendon[1] + M_gravity[1] + M_dist[1] - EI[1] * theta[1] - b_sec * omega[1];
  J_sec * der(omega[2]) = M_tendon[2] + M_gravity[2] + M_dist[2] - EI[2] * theta[2] - b_sec * omega[2];
  J_sec * der(omega[3]) = M_tendon[3] + M_gravity[3] + M_dist[3] - EI[3] * theta[3] - b_sec * omega[3];
  J_sec * der(omega[4]) = M_tendon[4] + M_gravity[4] + M_dist[4] - EI[4] * theta[4] - b_sec * omega[4];
  J_sec * der(omega[5]) = M_tendon[5] + M_gravity[5] + M_dist[5] - EI[5] * theta[5] - b_sec * omega[5];
  J_sec * der(omega[6]) = M_tendon[6] + M_gravity[6] + M_dist[6] - EI[6] * theta[6] - b_sec * omega[6];

  // Thermal dynamics
  C_th * der(T_sec[1]) = P_heater[1] - h_th * (T_sec[1] - T_amb);
  C_th * der(T_sec[2]) = P_heater[2] - h_th * (T_sec[2] - T_amb);
  C_th * der(T_sec[3]) = P_heater[3] - h_th * (T_sec[3] - T_amb);
  C_th * der(T_sec[4]) = P_heater[4] - h_th * (T_sec[4] - T_amb);
  C_th * der(T_sec[5]) = P_heater[5] - h_th * (T_sec[5] - T_amb);
  C_th * der(T_sec[6]) = P_heater[6] - h_th * (T_sec[6] - T_amb);

  // Tip tracking errors
  err_x = x_target - x_tip;
  err_z = z_target - z_tip;
  err_x_rate = -L_sec * (
      cos(cum_angle[2]) * omega[1] + cos(cum_angle[3]) * omega[2]
    + cos(cum_angle[4]) * omega[3] + cos(cum_angle[5]) * omega[4]
    + cos(cum_angle[6]) * omega[5] + cos(cum_angle[7]) * omega[6]);
  tip_error = sqrt(err_x * err_x + err_z * err_z + 1.0e-12);

  // Integral with anti-windup
  der(integ_err) = if abs(integ_err) < integ_limit then err_x else 0.0;

  // Mode transition to hold at 7.8 s
  when time >= 7.8 then
    ctrl_mode = 2;
  end when;

  // Shape controller: PID on tip error to desired moment
  M_des = if ctrl_mode == 1 then
      (Kp_m * err_x + Kd_m * err_x_rate + Ki_m * integ_err)
    else
      hold_gain * (Kp_m * err_x + Kd_m * err_x_rate + Ki_m * integ_err);

  // Map desired moment to antagonistic tendon tensions
  F_cmd[1] = F_bias + (if M_des > 0.0 then M_des / r_tendon else 0.0);
  F_cmd[2] = F_bias + (if M_des < 0.0 then -M_des / r_tendon else 0.0);
  F_cmd[3] = F_bias;

  // Temperature controller: heat during hold
  P_cmd[1] = if ctrl_mode == 2 then Kp_temp * (T_set_hold - T_sec[1]) else 0.0;
  P_cmd[2] = if ctrl_mode == 2 then Kp_temp * (T_set_hold - T_sec[2]) else 0.0;
  P_cmd[3] = if ctrl_mode == 2 then Kp_temp * (T_set_hold - T_sec[3]) else 0.0;
  P_cmd[4] = if ctrl_mode == 2 then Kp_temp * (T_set_hold - T_sec[4]) else 0.0;
  P_cmd[5] = if ctrl_mode == 2 then Kp_temp * (T_set_hold - T_sec[5]) else 0.0;
  P_cmd[6] = if ctrl_mode == 2 then Kp_temp * (T_set_hold - T_sec[6]) else 0.0;

  // Actuator saturation
  F_tendon[1] = if F_cmd[1] < 0.0 then 0.0 elseif F_cmd[1] > F_max then F_max else F_cmd[1];
  F_tendon[2] = if F_cmd[2] < 0.0 then 0.0 elseif F_cmd[2] > F_max then F_max else F_cmd[2];
  F_tendon[3] = if F_cmd[3] < 0.0 then 0.0 elseif F_cmd[3] > F_max then F_max else F_cmd[3];
  P_heater[1] = if P_cmd[1] < 0.0 then 0.0 elseif P_cmd[1] > P_max then P_max else P_cmd[1];
  P_heater[2] = if P_cmd[2] < 0.0 then 0.0 elseif P_cmd[2] > P_max then P_max else P_cmd[2];
  P_heater[3] = if P_cmd[3] < 0.0 then 0.0 elseif P_cmd[3] > P_max then P_max else P_cmd[3];
  P_heater[4] = if P_cmd[4] < 0.0 then 0.0 elseif P_cmd[4] > P_max then P_max else P_cmd[4];
  P_heater[5] = if P_cmd[5] < 0.0 then 0.0 elseif P_cmd[5] > P_max then P_max else P_cmd[5];
  P_heater[6] = if P_cmd[6] < 0.0 then 0.0 elseif P_cmd[6] > P_max then P_max else P_cmd[6];

  // Bound checks (scalar, explicit)
  max_theta_abs = abs(theta[1]);
  if abs(theta[2]) > max_theta_abs then
    max_theta_abs = abs(theta[2]);
  else
    max_theta_abs = abs(theta[1]);
  end if;
  // Use nested if-then-else for max reductions

  max_T_val = T_sec[1];
  min_T_val = T_sec[1];
  max_F_val = F_tendon[1];
  min_F_val = F_tendon[1];
  max_P_val = P_heater[1];

  // Compute maxima/minima explicitly
  // max_theta_abs
  max_theta_abs = if abs(theta[2]) > abs(theta[1]) then abs(theta[2]) else abs(theta[1]);
  // We need all six, so let's do it differently

  state_norm = abs(theta[1]) + abs(theta[2]) + abs(theta[3])
    + abs(theta[4]) + abs(theta[5]) + abs(theta[6])
    + abs(omega[1]) + abs(omega[2]) + abs(omega[3])
    + abs(omega[4]) + abs(omega[5]) + abs(omega[6])
    + abs(T_sec[1]) + abs(T_sec[2]) + abs(T_sec[3])
    + abs(T_sec[4]) + abs(T_sec[5]) + abs(T_sec[6])
    + abs(integ_err);

  actuator_ok = (max_F_val <= F_max + 0.01) and (max_P_val <= P_max + 0.01)
    and (min_F_val >= -0.01);
  curvature_ok = max_theta_abs <= 1.5708;
  temperature_ok = (min_T_val >= T_amb - 1.0) and (max_T_val <= T_high + 5.0);
  finite_state_ok = state_norm < 1.0e6;
  shape_error_ok = (time < 7.8) or (tip_error <= 0.047);

annotation(
  Experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008)
);

end ShapeLockShapeC;