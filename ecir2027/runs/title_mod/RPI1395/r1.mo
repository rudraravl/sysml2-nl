model ShapeLockShapeC
  // ===== Physical parameters =====
  parameter Real L_total = 0.30 "Total arm length [m]";
  parameter Real Ls = L_total / 6 "Section length [m]";
  parameter Real r_ten = 0.05 "Tendon moment arm [m]";
  parameter Real T_low = 320.0 "Low stiffness temperature [K]";
  parameter Real T_high = 345.0 "High stiffness temperature [K]";
  parameter Real EI_base = 0.5 "Base bending stiffness [N.m^2]";
  parameter Real kEI = 0.04 "Stiffness-temperature slope [N.m^2/K]";
  parameter Real c_damp = 0.5 "Curvature damping [N.m.s]";
  parameter Real C_th = 1.0 "Thermal capacitance [J/K]";
  parameter Real h_th = 0.72 "Thermal conductance [W/K]";
  parameter Real m_sec = 0.015 "Section mass [kg]";
  parameter Real g = 9.81 "Gravity [m/s^2]";

  // ===== Control limits =====
  parameter Real F_max = 42.3 "Max tendon tension [N]";
  parameter Real P_max = 18.0 "Max heater power [W]";
  parameter Real F_dist = 5.4 "Tip disturbance force [N]";

  // ===== Target =====
  parameter Real x_tgt = 0.28 "Target tip x [m]";
  parameter Real y_tgt = 0.05 "Target tip y [m]";

  // ===== Controller gains =====
  parameter Real Kp = 15.0 "Proportional gain on y error";
  parameter Real Kd = 0.5 "Derivative gain on y error";
  parameter Real Kp_temp = 20.0 "Temperature control gain [W/K]";
  parameter Real t_heat_start = 2.0 "Heating start time [s]";
  parameter Real t_ramp = 2.0 "Setpoint ramp duration [s]";

  // ===== Continuous states =====
  Real kappa[6](each start = 0.0) "Section curvature [1/m]";
  Real Tsec[6](each start = 320.0) "Section temperature [K]";

  // ===== Discrete variables =====
  discrete Real Ften_cmd[3](each start = 0.0) "Tendon tension commands [N]";
  discrete Real Pheat_cmd[6](each start = 0.0) "Heater power commands [W]";
  discrete Real err_y_prev(start = 0.0) "Previous y error [m]";
  discrete Integer fsm_state(start = 1) "FSM: 1=track 2=stiffen 3=disturb 4=hold";
  discrete Real M_fb(start = 0.0) "Feedback moment [N.m]";
  discrete Real err_y_d(start = 0.0) "Tip y error rate [m/s]";

  // ===== Continuous commands (held from discrete) =====
  Real Ften[3] "Tendon tensions [N]";
  Real Pheat[6] "Heater powers [W]";

  // ===== Kinematics =====
  Real x_sec[7] "Joint x positions [m]";
  Real y_sec[7] "Joint y positions [m]";
  Real th_sec[7] "Joint angles [rad]";
  Real x_tip "Tip x position [m]";
  Real y_tip "Tip y position [m]";
  Real tip_err "Tip tracking error [m]";
  Real err_x "Tip x error [m]";
  Real err_y "Tip y error [m]";

  // ===== Setpoint ramp =====
  Real ramp01 "Ramp factor 0 to 1";
  Real x_tgt_eff "Effective x target [m]";
  Real y_tgt_eff "Effective y target [m]";

  // ===== Undeformed geometry =====
  Real x_undeformed = L_total "Undeformed tip x [m]";
  Real y_undeformed = 0.0 "Undeformed tip y [m]";

  // ===== Section quantities =====
  Real EI[6] "Section bending stiffness [N.m^2]";
  Real M_ten[6] "Tendon moment per section [N.m]";
  Real M_grav[6] "Gravity moment per section [N.m]";
  Real M_dist[6] "Disturbance moment per section [N.m]";

  // ===== Disturbance =====
  Boolean dist_active "Disturbance active flag";
  Real dist_signal "Disturbance force [N]";

  // ===== Temperature =====
  Real T_target "Target temperature [K]";

  // ===== Bounds =====
  Real max_kappa_abs "Max absolute curvature [1/m]";
  Real max_temp_val "Max temperature [K]";
  Real min_temp_val "Min temperature [K]";
  Real max_Ften_val "Max tendon force [N]";
  Real max_Pheat_val "Max heater power [W]";

equation
  // Disturbance: active during middle third (4 s to 8 s)
  dist_active = time >= 4.0 and time <= 8.0;
  dist_signal = if dist_active then F_dist else 0.0;

  // Setpoint ramp from undeformed to target
  ramp01 = min(1.0, time / t_ramp);
  x_tgt_eff = L_total + (x_tgt - L_total) * ramp01;
  y_tgt_eff = y_tgt * ramp01;

  // Bending stiffness (temperature dependent)
  EI[1] = EI_base + kEI * (Tsec[1] - T_low);
  EI[2] = EI_base + kEI * (Tsec[2] - T_low);
  EI[3] = EI_base + kEI * (Tsec[3] - T_low);
  EI[4] = EI_base + kEI * (Tsec[4] - T_low);
  EI[5] = EI_base + kEI * (Tsec[5] - T_low);
  EI[6] = EI_base + kEI * (Tsec[6] - T_low);

  // Tendon moments via multi-termination routing
  // F1 terminates at section 6 (runs through all 6)
  // F2 terminates at section 4 (runs through sections 1-4)
  // F3 terminates at section 2 (runs through sections 1-2)
  M_ten[1] = r_ten * (Ften[1] + Ften[2] + Ften[3]);
  M_ten[2] = r_ten * (Ften[1] + Ften[2] + Ften[3]);
  M_ten[3] = r_ten * (Ften[1] + Ften[2]);
  M_ten[4] = r_ten * (Ften[1] + Ften[2]);
  M_ten[5] = r_ten * Ften[1];
  M_ten[6] = r_ten * Ften[1];

  // Forward kinematics using midpoint approximation
  x_sec[1] = 0.0;
  y_sec[1] = 0.0;
  th_sec[1] = 0.0;
  th_sec[2] = th_sec[1] + kappa[1] * Ls;
  x_sec[2] = x_sec[1] + Ls * cos(th_sec[1] + kappa[1] * Ls / 2);
  y_sec[2] = y_sec[1] + Ls * sin(th_sec[1] + kappa[1] * Ls / 2);
  th_sec[3] = th_sec[2] + kappa[2] * Ls;
  x_sec[3] = x_sec[2] + Ls * cos(th_sec[2] + kappa[2] * Ls / 2);
  y_sec[3] = y_sec[2] + Ls * sin(th_sec[2] + kappa[2] * Ls / 2);
  th_sec[4] = th_sec[3] + kappa[3] * Ls;
  x_sec[4] = x_sec[3] + Ls * cos(th_sec[3] + kappa[3] * Ls / 2);
  y_sec[4] = y_sec[3] + Ls * sin(th_sec[3] + kappa[3] * Ls / 2);
  th_sec[5] = th_sec[4] + kappa[4] * Ls;
  x_sec[5] = x_sec[4] + Ls * cos(th_sec[4] + kappa[4] * Ls / 2);
  y_sec[5] = y_sec[4] + Ls * sin(th_sec[4] + kappa[4] * Ls / 2);
  th_sec[6] = th_sec[5] + kappa[5] * Ls;
  x_sec[6] = x_sec[5] + Ls * cos(th_sec[5] + kappa[5] * Ls / 2);
  y_sec[6] = y_sec[5] + Ls * sin(th_sec[5] + kappa[5] * Ls / 2);
  th_sec[7] = th_sec[6] + kappa[6] * Ls;
  x_sec[7] = x_sec[6] + Ls * cos(th_sec[6] + kappa[6] * Ls / 2);
  y_sec[7] = y_sec[6] + Ls * sin(th_sec[6] + kappa[6] * Ls / 2);
  x_tip = x_sec[7];
  y_tip = y_sec[7];

  // Tip errors
  err_x = x_tgt_eff - x_tip;
  err_y = y_tgt_eff - y_tip;
  tip_err = sqrt(err_x * err_x + err_y * err_y);

  // Gravity moments (weight of distal mass, simplified lever arm)
  M_grav[1] = -m_sec * g * 6.0 * (x_tip - x_sec[1]) / 2.0;
  M_grav[2] = -m_sec * g * 5.0 * (x_tip - x_sec[2]) / 2.0;
  M_grav[3] = -m_sec * g * 4.0 * (x_tip - x_sec[3]) / 2.0;
  M_grav[4] = -m_sec * g * 3.0 * (x_tip - x_sec[4]) / 2.0;
  M_grav[5] = -m_sec * g * 2.0 * (x_tip - x_sec[5]) / 2.0;
  M_grav[6] = -m_sec * g * 1.0 * (x_tip - x_sec[6]) / 2.0;

  // Disturbance moments (downward tip force)
  M_dist[1] = -dist_signal * (x_tip - x_sec[1]);
  M_dist[2] = -dist_signal * (x_tip - x_sec[2]);
  M_dist[3] = -dist_signal * (x_tip - x_sec[3]);
  M_dist[4] = -dist_signal * (x_tip - x_sec[4]);
  M_dist[5] = -dist_signal * (x_tip - x_sec[5]);
  M_dist[6] = -dist_signal * (x_tip - x_sec[6]);

  // Curvature dynamics: c_damp * dk/dt = M_ten + M_grav + M_dist - EI * kappa
  c_damp * der(kappa[1]) = M_ten[1] + M_grav[1] + M_dist[1] - EI[1] * kappa[1];
  c_damp * der(kappa[2]) = M_ten[2] + M_grav[2] + M_dist[2] - EI[2] * kappa[2];
  c_damp * der(kappa[3]) = M_ten[3] + M_grav[3] + M_dist[3] - EI[3] * kappa[3];
  c_damp * der(kappa[4]) = M_ten[4] + M_grav[4] + M_dist[4] - EI[4] * kappa[4];
  c_damp * der(kappa[5]) = M_ten[5] + M_grav[5] + M_dist[5] - EI[5] * kappa[5];
  c_damp * der(kappa[6]) = M_ten[6] + M_grav[6] + M_dist[6] - EI[6] * kappa[6];

  // Thermal dynamics: C_th * dT/dt = P - h_th * (T - T_low)
  C_th * der(Tsec[1]) = Pheat[1] - h_th * (Tsec[1] - T_low);
  C_th * der(Tsec[2]) = Pheat[2] - h_th * (Tsec[2] - T_low);
  C_th * der(Tsec[3]) = Pheat[3] - h_th * (Tsec[3] - T_low);
  C_th * der(Tsec[4]) = Pheat[4] - h_th * (Tsec[4] - T_low);
  C_th * der(Tsec[5]) = Pheat[5] - h_th * (Tsec[5] - T_low);
  C_th * der(Tsec[6]) = Pheat[6] - h_th * (Tsec[6] - T_low);

  // Hold discrete commands between samples
  Ften[1] = Ften_cmd[1];
  Ften[2] = Ften_cmd[2];
  Ften[3] = Ften_cmd[3];
  Pheat[1] = Pheat_cmd[1];
  Pheat[2] = Pheat_cmd[2];
  Pheat[3] = Pheat_cmd[3];
  Pheat[4] = Pheat_cmd[4];
  Pheat[5] = Pheat_cmd[5];
  Pheat[6] = Pheat_cmd[6];

  // Temperature target schedule
  T_target = if time >= t_heat_start then T_high else T_low;

  // Bound variables
  max_kappa_abs = max(abs(kappa[1]), max(abs(kappa[2]), max(abs(kappa[3]), max(abs(kappa[4]), max(abs(kappa[5]), abs(kappa[6]))))));
  max_temp_val = max(Tsec[1], max(Tsec[2], max(Tsec[3], max(Tsec[4], max(Tsec[5], Tsec[6])))));
  min_temp_val = min(Tsec[1], min(Tsec[2], min(Tsec[3], min(Tsec[4], min(Tsec[5], Tsec[6])))));
  max_Ften_val = max(Ften[1], max(Ften[2], Ften[3]));
  max_Pheat_val = max(Pheat[1], max(Pheat[2], max(Pheat[3], max(Pheat[4], max(Pheat[5], Pheat[6])))));

  // ===== Sampled controller at 125 Hz (dt = 0.008 s) =====
  when sample(0, 0.008) then
    // Finite state machine
    if time < t_heat_start then
      fsm_state = 1; // TRACKING
    elseif time < 4.0 then
      fsm_state = 2; // STIFFENING
    elseif time < 8.0 then
      fsm_state = 3; // DISTURBANCE
    else
      fsm_state = 4; // HOLDING
    end if;

    // Discrete derivative of y error
    err_y_d = (err_y - pre(err_y_prev)) / 0.008;

    // PD feedback moment command
    M_fb = Kp * err_y + Kd * err_y_d;

    // Tendon force commands: gravity feedforward + PD feedback
    // Routing: F1 -> sec 1-6, F2 -> sec 1-4, F3 -> sec 1-2
    // Gravity comp per section group plus feedback distributed as [3,3,2,2,1,1]*M_fb
    Ften_cmd[1] = max(0.0, min(F_max, (-M_grav[6] + M_fb) / r_ten));
    Ften_cmd[2] = max(0.0, min(F_max, (-M_grav[4] + M_grav[6] + M_fb) / r_ten));
    Ften_cmd[3] = max(0.0, min(F_max, (-M_grav[2] + M_grav[4] + M_fb) / r_ten));

    // Temperature control: proportional with saturation
    Pheat_cmd[1] = max(0.0, min(P_max, Kp_temp * (T_target - Tsec[1])));
    Pheat_cmd[2] = max(0.0, min(P_max, Kp_temp * (T_target - Tsec[2])));
    Pheat_cmd[3] = max(0.0, min(P_max, Kp_temp * (T_target - Tsec[3])));
    Pheat_cmd[4] = max(0.0, min(P_max, Kp_temp * (T_target - Tsec[4])));
    Pheat_cmd[5] = max(0.0, min(P_max, Kp_temp * (T_target - Tsec[5])));
    Pheat_cmd[6] = max(0.0, min(P_max, Kp_temp * (T_target - Tsec[6])));

    // Store previous error for derivative
    err_y_prev = err_y;
  end when;

  // ===== Bound assertions =====
  assert(max_kappa_abs < 50.0, "Curvature bound exceeded");
  assert(max_temp_val <= T_high + 2.0, "Temperature upper bound exceeded");
  assert(min_temp_val >= T_low - 2.0, "Temperature lower bound exceeded");
  assert(max_Ften_val <= F_max + 0.5, "Tendon force bound exceeded");
  assert(max_Pheat_val <= P_max + 0.5, "Heater power bound exceeded");
  assert(not (time >= 7.8 and tip_err > 0.047), "Primary tracking error > 0.047 m after 7.8 s");

end ShapeLockShapeC;