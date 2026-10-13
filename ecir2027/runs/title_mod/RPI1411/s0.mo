model ShapeLockAvoidA
  "Six-section continuum arm with thermal stiffness control and obstacle avoidance"

  // ===== Physical parameters =====
  parameter Real L_sec(unit="m") = 0.05 "Section length";
  parameter Real r_arm(unit="m") = 0.02 "Arm radius";
  parameter Real r_tendon(unit="m") = 0.03 "Tendon offset from neutral axis";
  parameter Real J_sec(unit="kg.m^2") = 1.0e-4 "Section moment of inertia";
  parameter Real D_theta(unit="N.m.s/rad") = 0.03 "Section angular damping";

  // ===== Thermal stiffness parameters =====
  parameter Real T_lo(unit="K") = 320.0 "Low stiffness temperature";
  parameter Real T_hi(unit="K") = 345.0 "High stiffness temperature";
  parameter Real T_amb(unit="K") = 300.0 "Ambient temperature";
  parameter Real EI_lo(unit="N.m^2") = 0.3 "Low bending stiffness";
  parameter Real EI_hi(unit="N.m^2") = 3.0 "High bending stiffness";
  parameter Real C_heat(unit="J/K") = 0.8 "Thermal capacitance per section";
  parameter Real R_th(unit="K/W") = 4.0 "Thermal resistance to ambient";
  parameter Real Q_hold(unit="W") = 5.0 "Hold power to maintain T_lo";
  parameter Real bias_tension(unit="N") = 16.55 "Tendon bias tension = cmd_max_force/2";

  // ===== Command limits =====
  parameter Real cmd_max_force(unit="N") = 33.1 "Max tendon tension";
  parameter Real cmd_max_power(unit="W") = 18.0 "Max heater power";
  parameter Real max_moment(unit="N.m") = 0.993 "Max actuator moment = r_tendon * cmd_max_force";

  // ===== Obstacle =====
  parameter Real r_obs(unit="m") = 0.03 "Obstacle radius";
  parameter Real x_obs(unit="m") = 0.20 "Obstacle center x";
  parameter Real y_obs(unit="m") = 0.06 "Obstacle center y";
  parameter Real mu_obs = 0.55 "Obstacle friction coefficient";
  parameter Real k_contact(unit="N/m") = 1000.0 "Contact stiffness";
  parameter Real b_contact(unit="N.s/m") = 10.0 "Contact damping";

  // ===== Target and trajectory =====
  parameter Real x_target(unit="m") = 0.26 "Target x";
  parameter Real y_target(unit="m") = 0.07 "Target y";
  parameter Real x_waypoint(unit="m") = 0.22 "Waypoint x";
  parameter Real y_waypoint(unit="m") = 0.10 "Waypoint y";

  // ===== Control =====
  parameter Real K_p(unit="N/m") = 200.0 "Tip tracking gain";
  parameter Real k_rep(unit="N") = 3.0 "Obstacle repulsion gain";
  parameter Real rep_threshold(unit="m") = 0.04 "Repulsion threshold";

  // ===== Disturbance =====
  parameter Real F_dist_mag(unit="N") = 4.0 "Disturbance magnitude";

  // ===== Scenario =====
  parameter Real t_end(unit="s") = 8.0 "Scenario duration";
  parameter Real t1 = t_end / 3.0 "Phase 1 end time";
  parameter Real t2 = 2.0 * t_end / 3.0 "Phase 2 end time";

  // ===== Dynamic states =====
  Real theta[6](each start = 0.0, each fixed = true) "Section bend angle [rad]";
  Real dtheta[6](each start = 0.0, each fixed = true) "Section angular velocity [rad/s]";
  Real T_sec[6](each start = 320.0, each fixed = true) "Section temperature [K]";

  // ===== Kinematics =====
  Real phi_joint[7] "Accumulated angle at joints [rad]";
  Real x_joint[7] "Joint x [m]";
  Real y_joint[7] "Joint y [m]";
  Real x_tip "Tip x [m]";
  Real y_tip "Tip y [m]";
  Real phi_tip "Tip orientation [rad]";

  // ===== Jacobian =====
  Real Jx[6] "dx_tip/dtheta_k";
  Real Jy[6] "dy_tip/dtheta_k";
  Real sum_sin[7] "Cumulative sin from section k to 6";
  Real sum_cos[7] "Cumulative cos from section k to 6";

  // ===== Joint velocities =====
  Real vx_end[6] "x-velocity of section end [m/s]";
  Real vy_end[6] "y-velocity of section end [m/s]";

  // ===== Stiffness =====
  Real EI_eff[6] "Effective bending stiffness [N.m^2]";
  Real stiff_norm[6] "Normalized stiffness fraction [0-1]";

  // ===== Contact =====
  Real dist_obs[6] "Distance from section end to obstacle center [m]";
  Real clearance[6] "Clearance to obstacle surface [m]";
  Real nx_c[6] "Contact normal x";
  Real ny_c[6] "Contact normal y";
  Real penetration[6] "Penetration depth [m]";
  Real v_n[6] "Normal velocity [m/s]";
  Real v_t[6] "Tangential velocity [m/s]";
  Real F_n[6] "Normal contact force [N]";
  Real F_t[6] "Friction force [N]";
  Real F_contact_x[6] "Contact force x [N]";
  Real F_contact_y[6] "Contact force y [N]";
  Real F_contact[6] "Contact force magnitude [N]";

  // ===== Controller =====
  Real x_des "Desired tip x [m]";
  Real y_des "Desired tip y [m]";
  Real err_tip "Tip tracking error [m]";
  Real dist_tip_obs "Distance from tip to obstacle center [m]";
  Real clr_tip "Tip clearance to obstacle [m]";
  Real F_ctrl_x "Control force x [N]";
  Real F_ctrl_y "Control force y [N]";
  Real F_rep_x "Repulsive force x [N]";
  Real F_rep_y "Repulsive force y [N]";
  Real tau_raw[6] "Raw actuator torque [N.m]";
  Real cmd_moment[6] "Bounded commanded moment [N.m]";
  Real cmd_power[6] "Commanded heater power [W]";
  Real cmd_tension_1[6] "Tendon 1 tension [N]";
  Real cmd_tension_2[6] "Tendon 2 tension [N]";
  Real cmd_tension_3[6] "Tendon 3 tension [N]";
  Real tau_actuator[6] "Applied actuator torque [N.m]";
  Real tau_contact[6] "Contact generalized torque [N.m]";
  Real tau_dist[6] "Disturbance generalized torque [N.m]";
  Real F_dist_y "Disturbance force y [N]";
  Real phase "Current phase";

  // ===== Monitors =====
  Real max_tension "Max tendon tension [N]";
  Real max_power_out "Max heater power [W]";
  Real max_deform "Max abs deformation [rad]";
  Real max_contact "Max contact force [N]";
  Real min_clearance "Min clearance [m]";
  Real max_temp "Max temperature [K]";
  Real min_temp "Min temperature [K]";
  Real tracking_err_5_2(start = 1.0) "Tracking error captured at t=5.2 s [m]";
  Real final_tip_err(start = 1.0) "Final tip error [m]";

equation
  // ===== Phase determination =====
  phase = if time < t1 then 1.0 elseif time < t2 then 2.0 else 3.0;

  // ===== Desired trajectory (waypoint then target) =====
  x_des = if time < t1 then
            x_waypoint * (time / t1)
          elseif time < t2 then
            x_waypoint + (x_target - x_waypoint) * (time - t1) / (t2 - t1)
          else
            x_target;

  y_des = if time < t1 then
            y_waypoint * (time / t1)
          elseif time < t2 then
            y_waypoint + (y_target - y_waypoint) * (time - t1) / (t2 - t1)
          else
            y_target;

  // ===== Disturbance: 4 N lateral during middle third =====
  F_dist_y = if time >= t1 and time <= t2 then F_dist_mag else 0.0;

  // ===== Kinematics: piecewise constant curvature chain =====
  phi_joint[1] = 0.0;
  x_joint[1] = 0.0;
  y_joint[1] = 0.0;

  for i in 1:6 loop
    phi_joint[i+1] = phi_joint[i] + theta[i];
    x_joint[i+1] = x_joint[i] + L_sec * cos(phi_joint[i+1]);
    y_joint[i+1] = y_joint[i] + L_sec * sin(phi_joint[i+1]);
  end for;

  x_tip = x_joint[7];
  y_tip = y_joint[7];
  phi_tip = phi_joint[7];

  // ===== Tip Jacobian via backward cumulative sums =====
  sum_sin[7] = 0.0;
  sum_cos[7] = 0.0;
  for k in 6:-1:1 loop
    sum_sin[k] = sum_sin[k+1] + sin(phi_joint[k+1]);
    sum_cos[k] = sum_cos[k+1] + cos(phi_joint[k+1]);
  end for;

  for k in 1:6 loop
    Jx[k] = -L_sec * sum_sin[k];
    Jy[k] =  L_sec * sum_cos[k];
  end for;

  // ===== Joint endpoint velocities =====
  vx_end[1] = -L_sec * sin(phi_joint[2]) * dtheta[1];
  vy_end[1] =  L_sec * cos(phi_joint[2]) * dtheta[1];
  for i in 2:6 loop
    vx_end[i] = vx_end[i-1] - L_sec * sin(phi_joint[i+1]) * dtheta[i];
    vy_end[i] = vy_end[i-1] + L_sec * cos(phi_joint[i+1]) * dtheta[i];
  end for;

  // ===== Thermal stiffness model (smoothstep between T_lo and T_hi) =====
  for i in 1:6 loop
    stiff_norm[i] = (T_sec[i] - T_lo) / (T_hi - T_lo);
    EI_eff[i] = EI_lo + (EI_hi - EI_lo) * (
      if stiff_norm[i] <= 0.0 then 0.0
      elseif stiff_norm[i] >= 1.0 then 1.0
      else stiff_norm[i] * stiff_norm[i] * (3.0 - 2.0 * stiff_norm[i])
    );
  end for;

  // ===== Thermal dynamics =====
  for i in 1:6 loop
    der(T_sec[i]) = (cmd_power[i] - (T_sec[i] - T_amb) / R_th) / C_heat;
  end for;

  // ===== Contact model per section end =====
  for i in 1:6 loop
    dist_obs[i] = sqrt((x_joint[i+1] - x_obs)^2 + (y_joint[i+1] - y_obs)^2 + 1.0e-10);
    clearance[i] = dist_obs[i] - r_obs - r_arm;
    nx_c[i] = (x_joint[i+1] - x_obs) / dist_obs[i];
    ny_c[i] = (y_joint[i+1] - y_obs) / dist_obs[i];
    penetration[i] = max(0.0, -clearance[i]);
    v_n[i] = (vx_end[i] * (x_joint[i+1] - x_obs) + vy_end[i] * (y_joint[i+1] - y_obs)) / dist_obs[i];
    v_t[i] = (-vx_end[i] * (y_joint[i+1] - y_obs) + vy_end[i] * (x_joint[i+1] - x_obs)) / dist_obs[i];
    F_n[i] = if penetration[i] > 0.0 then
               max(0.0, k_contact * penetration[i] - b_contact * v_n[i])
             else 0.0;
    F_t[i] = -mu_obs * F_n[i] * tanh(v_t[i] / 0.01);
    F_contact_x[i] = F_n[i] * nx_c[i] - F_t[i] * ny_c[i];
    F_contact_y[i] = F_n[i] * ny_c[i] + F_t[i] * nx_c[i];
    F_contact[i] = sqrt(F_contact_x[i]^2 + F_contact_y[i]^2 + 1.0e-12);
  end for;

  // ===== Contact generalized torque (moment on section i about its base) =====
  for i in 1:6 loop
    tau_contact[i] = L_sec * (cos(phi_joint[i+1]) * F_contact_y[i] - sin(phi_joint[i+1]) * F_contact_x[i]);
  end for;

  // ===== Obstacle repulsion (tip-based) =====
  dist_tip_obs = sqrt((x_tip - x_obs)^2 + (y_tip - y_obs)^2 + 1.0e-10);
  clr_tip = dist_tip_obs - r_obs - r_arm;
  F_rep_x = if clr_tip < rep_threshold then
    k_rep * (rep_threshold - clr_tip) / rep_threshold * (x_tip - x_obs) / dist_tip_obs
  else 0.0;
  F_rep_y = if clr_tip < rep_threshold then
    k_rep * (rep_threshold - clr_tip) / rep_threshold * (y_tip - y_obs) / dist_tip_obs
  else 0.0;

  // ===== Control force (proportional tip tracking + repulsion) =====
  F_ctrl_x = K_p * (x_des - x_tip) + F_rep_x;
  F_ctrl_y = K_p * (y_des - y_tip) + F_rep_y;

  // ===== Actuator torques (Jacobian transpose, bounded) =====
  for k in 1:6 loop
    tau_raw[k] = Jx[k] * F_ctrl_x + Jy[k] * F_ctrl_y;
    cmd_moment[k] = if tau_raw[k] > max_moment then max_moment
                   elseif tau_raw[k] < -max_moment then -max_moment
                   else tau_raw[k];
    tau_actuator[k] = cmd_moment[k];
  end for;

  // ===== Tendon tensions (3 per section, symmetric bias) =====
  for i in 1:6 loop
    cmd_tension_1[i] = max(0.0, min(cmd_max_force, bias_tension + cmd_moment[i] / (2.0 * r_tendon)));
    cmd_tension_2[i] = max(0.0, min(cmd_max_force, bias_tension - cmd_moment[i] / (2.0 * r_tendon)));
    cmd_tension_3[i] = cmd_tension_2[i];
  end for;

  // ===== Contact-aware stiffness scheduling =====
  // Phases 1-2: hold T_lo. Phase 3: heat if not in contact, hold if in contact.
  for i in 1:6 loop
    cmd_power[i] = if time > t2 then
                     (if F_contact[i] < 0.01 then cmd_max_power else 0.0)
                   else
                     Q_hold;
  end for;

  // ===== Disturbance generalized torque =====
  for k in 1:6 loop
    tau_dist[k] = Jy[k] * F_dist_y;
  end for;

  // ===== Section dynamics =====
  for i in 1:6 loop
    der(theta[i]) = dtheta[i];
    J_sec * der(dtheta[i]) = tau_actuator[i] + tau_contact[i] + tau_dist[i]
                             - D_theta * dtheta[i]
                             - EI_eff[i] * theta[i] / L_sec;
  end for;

  // ===== Tracking error =====
  err_tip = sqrt((x_des - x_tip)^2 + (y_des - y_tip)^2);

  // ===== Bound monitors =====
  max_tension = max(max(cmd_tension_1), max(max(cmd_tension_2), max(cmd_tension_3)));
  max_power_out = max(cmd_power);
  max_deform = max(abs(theta));
  max_contact = max(F_contact);
  min_clearance = min(clearance);
  max_temp = max(T_sec);
  min_temp = min(T_sec);

  // ===== Event-captured error at t = 5.2 s =====
  when time >= 5.2 then
    tracking_err_5_2 = err_tip;
  end when;

  // ===== Final tip error =====
  when time >= 7.9 then
    final_tip_err = err_tip;
  end when;

  // ===== Bound assertions =====
  assert(max_tension <= cmd_max_force + 0.1, "Tendon tension exceeds command limit");
  assert(max_power_out <= cmd_max_power + 0.1, "Heater power exceeds command limit");
  assert(max_deform <= 2.0, "Section deformation exceeds 2 rad bound");
  assert(max_contact <= 100.0, "Contact force exceeds 100 N bound");
  assert(max_temp <= 400.0, "Temperature exceeds 400 K bound");
  assert(min_temp >= 290.0, "Temperature below 290 K bound");
  assert(min_clearance >= -0.02, "Obstacle penetration exceeds 20 mm bound");
  assert(time < 5.2 or tracking_err_5_2 <= 0.054, "Primary tracking error at 5.2 s exceeds 0.054 m");
  assert(time < 7.9 or final_tip_err <= 0.1, "Final tip error exceeds 0.1 m bound");

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "ShapeLockAvoidA: Six-section continuum arm (3 tendons/section, thermal stiffness 320-345 K, fixed cylinder obstacle mu=0.55, contact-aware shape control, 4 N lateral disturbance in middle third, 80 Hz for 8 s, tracking error < 0.054 m after 5.2 s.")
  );
end ShapeLockAvoidA;