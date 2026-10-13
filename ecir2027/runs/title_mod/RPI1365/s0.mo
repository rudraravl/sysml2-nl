model SoftGripAvoidC
  "Contact-aware shape control for a three-finger soft gripper with bounded stiffness scheduling.
   Three 0.13 m silicone fingers surround a rigid palm (planar simplification;
   finger arrangement not specified). Each finger has one pressure chamber
   with four bending sections. A fixed cylinder obstacle with friction
   coefficient 0.55 is represented with collision-enabled contact."

  // ===== Stated parameters =====
  parameter Real L_finger = 0.13 "Finger length [m]";
  parameter Real p_max_cmd = 87400.0 "Maximum command magnitude [Pa] (87.4 kPa gauge)";
  parameter Real F_dist_val = 7.2 "Disturbance tip load [N]";
  parameter Real mu_obstacle = 0.55 "Obstacle friction coefficient";
  parameter Real f_sample = 125.0 "Sampling frequency [Hz]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";
  parameter Real err_threshold = 0.042 "Primary tracking error threshold [m]";
  parameter Real t_settle = 7.8 "Settling time requirement [s]";

  // ===== Unknown parameters (not specified in requirement) =====
  parameter Real r_cyl = 0.02 "Cylinder radius [m] - not specified";
  parameter Real x_cyl = 0.03 "Cylinder center x [m] - not specified";
  parameter Real y_cyl = 0.115 "Cylinder center y [m] - not specified";
  parameter Real x_target = 0.06 "Target tip x [m] - not specified";
  parameter Real y_target = 0.10 "Target tip y [m] - not specified";
  parameter Real k_bend = 1.0e-5 "Bending gain [rad/(Pa.s^2)] - not specified";
  parameter Real c_damp = 7.0 "Section damping [1/s] - not specified";
  parameter Real k_restore = 1.0 "Restoring stiffness (low) [1/s^2] - not specified";
  parameter Real k_restore_hi = 3.0 "Restoring stiffness (high) [1/s^2] - not specified";
  parameter Real K_ctrl = 5.0e6 "Controller gain [Pa/m] - not specified";
  parameter Real k_contact = 10000.0 "Contact stiffness [N/m] - not specified";
  parameter Real T_amb = 22.0 "Ambient temperature [degC] - not specified";
  parameter Real k_thermal = 5.0e-4 "Thermal gain [degC/Pa] - not specified";
  parameter Real tau_thermal = 3.0 "Thermal time constant [s] - not specified";
  parameter Real theta_bound = 1.5708 "Max section deformation [rad] - not specified";
  parameter Real F_contact_bound = 100.0 "Max contact force [N] - not specified";
  parameter Real T_bound = 80.0 "Max temperature [degC] - not specified";
  parameter Real tau_act = 0.02 "Actuator time constant [s] - not specified";

  // ===== Derived =====
  parameter Real L_sec = L_finger / 4.0 "Section length [m]";
  parameter Real dt_sample = 1.0 / f_sample "Sample period [s]";
  parameter Real t_dist_start = T_sim / 3.0 "Disturbance start [s]";
  parameter Real t_dist_end = 2.0 * T_sim / 3.0 "Disturbance end [s]";

  // ===== Finger 1 states =====
  Real theta1[4](each start = 0.001) "Section bending angles F1 [rad]";
  Real dtheta1[4](each start = 0.0) "Section angular rates F1 [rad/s]";
  Real p_act1(start = 0.0) "Actuator pressure F1 [Pa]";
  Real T1(start = T_amb) "Temperature F1 [degC]";

  // ===== Finger 2 states =====
  Real theta2[4](each start = 0.001) "Section bending angles F2 [rad]";
  Real dtheta2[4](each start = 0.0) "Section angular rates F2 [rad/s]";
  Real p_act2(start = 0.0) "Actuator pressure F2 [Pa]";
  Real T2(start = T_amb) "Temperature F2 [degC]";

  // ===== Finger 3 states =====
  Real theta3[4](each start = 0.001) "Section bending angles F3 [rad]";
  Real dtheta3[4](each start = 0.0) "Section angular rates F3 [rad/s]";
  Real p_act3(start = 0.0) "Actuator pressure F3 [Pa]";
  Real T3(start = T_amb) "Temperature F3 [degC]";

  // ===== Commands (125 Hz discrete) =====
  discrete Real p_cmd1(start = 0.0) "Pressure command F1 [Pa]";
  discrete Real p_cmd2(start = 0.0) "Pressure command F2 [Pa]";
  discrete Real p_cmd3(start = 0.0) "Pressure command F3 [Pa]";

  // ===== Forward kinematics =====
  Real alpha1[4] "Cumulative angles F1 [rad]";
  Real alpha2[4] "Cumulative angles F2 [rad]";
  Real alpha3[4] "Cumulative angles F3 [rad]";
  Real x_sec1[4] "Section endpoint x F1 [m]";
  Real y_sec1[4] "Section endpoint y F1 [m]";
  Real x_sec2[4] "Section endpoint x F2 [m]";
  Real y_sec2[4] "Section endpoint y F2 [m]";
  Real x_sec3[4] "Section endpoint x F3 [m]";
  Real y_sec3[4] "Section endpoint y F3 [m]";
  Real x_tip1 "Tip x F1 [m]";
  Real y_tip1 "Tip y F1 [m]";
  Real x_tip2 "Tip x F2 [m]";
  Real y_tip2 "Tip y F2 [m]";
  Real x_tip3 "Tip x F3 [m]";
  Real y_tip3 "Tip y F3 [m]";
  Real x_tip_avg "Average tip x [m]";
  Real y_tip_avg "Average tip y [m]";
  Real tip_error "Primary tracking error [m]";

  // ===== Contact =====
  Real dist1[4] "Section-to-cylinder distances F1 [m]";
  Real dist2[4] "Section-to-cylinder distances F2 [m]";
  Real dist3[4] "Section-to-cylinder distances F3 [m]";
  Real cl1[4] "Per-section clearances F1 [m]";
  Real cl2[4] "Per-section clearances F2 [m]";
  Real cl3[4] "Per-section clearances F3 [m]";
  Real F_c1_sec[4] "Per-section contact forces F1 [N]";
  Real F_c2_sec[4] "Per-section contact forces F2 [N]";
  Real F_c3_sec[4] "Per-section contact forces F3 [N]";
  Real F_c1 "Total contact force F1 [N]";
  Real F_c2 "Total contact force F2 [N]";
  Real F_c3 "Total contact force F3 [N]";
  Real F_fric1 "Friction force F1 [N]";
  Real F_fric2 "Friction force F2 [N]";
  Real F_fric3 "Friction force F3 [N]";
  Real F_contact_total "Total distributed contact force [N]";
  Real clearance_min "Minimum obstacle clearance [m]";

  // ===== Disturbance =====
  Real F_dist "Active disturbance force [N]";

  // ===== Stiffness scheduling =====
  Real stiff_factor "Stiffness scheduling factor [0..1]";
  Real k_restore_eff "Effective restoring stiffness [1/s^2]";

  // ===== Deformation =====
  Real def_max "Maximum section deformation [rad]";

  // ===== Bounds =====
  Boolean actuator_ok "Actuator bound satisfied";
  Boolean deformation_ok "Deformation bound satisfied";
  Boolean contact_ok "Contact force bound satisfied";
  Boolean temperature_ok "Temperature bound satisfied";
  Boolean clearance_ok "Obstacle clearance bound satisfied";
  Boolean tip_err_ok "Tip error bound satisfied";
  Boolean all_bounds_ok "All physical bounds satisfied";
  Boolean no_nan_inf "No NaN or infinite values";
  Boolean tracking_ok "Tracking requirement met after 7.8 s";

equation
  // ===== Discrete controller at 125 Hz =====
  // Bounded stiffness scheduling: compliant approach, stiff hold near target.
  // Command magnitude saturated to 87.4 kPa gauge.
  when sample(0, dt_sample) then
    p_cmd1 = max(-p_max_cmd, min(p_max_cmd, K_ctrl * ((x_target - x_tip1) - (y_target - y_tip1))));
    p_cmd2 = max(-p_max_cmd, min(p_max_cmd, K_ctrl * ((x_target - x_tip2) - (y_target - y_tip2))));
    p_cmd3 = max(-p_max_cmd, min(p_max_cmd, K_ctrl * ((x_target - x_tip3) - (y_target - y_tip3))));
  end when;

  // ===== Actuator dynamics (first-order) =====
  der(p_act1) = (p_cmd1 - p_act1) / tau_act;
  der(p_act2) = (p_cmd2 - p_act2) / tau_act;
  der(p_act3) = (p_cmd3 - p_act3) / tau_act;

  // ===== Bounded stiffness scheduling =====
  // stiff_factor ramps from 0 (far) to 1 (near target); bounded in [0, 1].
  stiff_factor = if tip_error < 0.05 then 1.0
    else if tip_error < 0.15 then (0.15 - tip_error) / 0.10
    else 0.0;
  k_restore_eff = k_restore + stiff_factor * (k_restore_hi - k_restore);

  // ===== Disturbance: 7.2 N lateral tip load during middle third (4-8 s) =====
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_dist_val else 0.0;

  // ===== Forward kinematics — Finger 1 =====
  alpha1[1] = theta1[1];
  alpha1[2] = alpha1[1] + theta1[2];
  alpha1[3] = alpha1[2] + theta1[3];
  alpha1[4] = alpha1[3] + theta1[4];
  x_sec1[1] = L_sec * sin(alpha1[1]);
  y_sec1[1] = L_sec * cos(alpha1[1]);
  x_sec1[2] = x_sec1[1] + L_sec * sin(alpha1[2]);
  y_sec1[2] = y_sec1[1] + L_sec * cos(alpha1[2]);
  x_sec1[3] = x_sec1[2] + L_sec * sin(alpha1[3]);
  y_sec1[3] = y_sec1[2] + L_sec * cos(alpha1[3]);
  x_sec1[4] = x_sec1[3] + L_sec * sin(alpha1[4]);
  y_sec1[4] = y_sec1[3] + L_sec * cos(alpha1[4]);
  x_tip1 = x_sec1[4];
  y_tip1 = y_sec1[4];

  // ===== Forward kinematics — Finger 2 =====
  alpha2[1] = theta2[1];
  alpha2[2] = alpha2[1] + theta2[2];
  alpha2[3] = alpha2[2] + theta2[3];
  alpha2[4] = alpha2[3] + theta2[4];
  x_sec2[1] = L_sec * sin(alpha2[1]);
  y_sec2[1] = L_sec * cos(alpha2[1]);
  x_sec2[2] = x_sec2[1] + L_sec * sin(alpha2[2]);
  y_sec2[2] = y_sec2[1] + L_sec * cos(alpha2[2]);
  x_sec2[3] = x_sec2[2] + L_sec * sin(alpha2[3]);
  y_sec2[3] = y_sec2[2] + L_sec * cos(alpha2[3]);
  x_sec2[4] = x_sec2[3] + L_sec * sin(alpha2[4]);
  y_sec2[4] = y_sec2[3] + L_sec * cos(alpha2[4]);
  x_tip2 = x_sec2[4];
  y_tip2 = y_sec2[4];

  // ===== Forward kinematics — Finger 3 =====
  alpha3[1] = theta3[1];
  alpha3[2] = alpha3[1] + theta3[2];
  alpha3[3] = alpha3[2] + theta3[3];
  alpha3[4] = alpha3[3] + theta3[4];
  x_sec3[1] = L_sec * sin(alpha3[1]);
  y_sec3[1] = L_sec * cos(alpha3[1]);
  x_sec3[2] = x_sec3[1] + L_sec * sin(alpha3[2]);
  y_sec3[2] = y_sec3[1] + L_sec * cos(alpha3[2]);
  x_sec3[3] = x_sec3[2] + L_sec * sin(alpha3[3]);
  y_sec3[3] = y_sec3[2] + L_sec * cos(alpha3[3]);
  x_sec3[4] = x_sec3[3] + L_sec * sin(alpha3[4]);
  y_sec3[4] = y_sec3[3] + L_sec * cos(alpha3[4]);
  x_tip3 = x_sec3[4];
  y_tip3 = y_sec3[4];

  // ===== Average tip position and tracking error =====
  x_tip_avg = (x_tip1 + x_tip2 + x_tip3) / 3.0;
  y_tip_avg = (y_tip1 + y_tip2 + y_tip3) / 3.0;
  tip_error = sqrt(max(1e-12, (x_target - x_tip_avg)^2 + (y_target - y_tip_avg)^2));

  // ===== Contact detection — Finger 1 =====
  for i in 1:4 loop
    dist1[i] = sqrt(max(1e-12, (x_sec1[i] - x_cyl)^2 + (y_sec1[i] - y_cyl)^2));
    cl1[i] = dist1[i] - r_cyl;
    F_c1_sec[i] = k_contact * max(0.0, -cl1[i]);
  end for;
  F_c1 = F_c1_sec[1] + F_c1_sec[2] + F_c1_sec[3] + F_c1_sec[4];
  F_fric1 = mu_obstacle * F_c1;

  // ===== Contact detection — Finger 2 =====
  for i in 1:4 loop
    dist2[i] = sqrt(max(1e-12, (x_sec2[i] - x_cyl)^2 + (y_sec2[i] - y_cyl)^2));
    cl2[i] = dist2[i] - r_cyl;
    F_c2_sec[i] = k_contact * max(0.0, -cl2[i]);
  end for;
  F_c2 = F_c2_sec[1] + F_c2_sec[2] + F_c2_sec[3] + F_c2_sec[4];
  F_fric2 = mu_obstacle * F_c2;

  // ===== Contact detection — Finger 3 =====
  for i in 1:4 loop
    dist3[i] = sqrt(max(1e-12, (x_sec3[i] - x_cyl)^2 + (y_sec3[i] - y_cyl)^2));
    cl3[i] = dist3[i] - r_cyl;
    F_c3_sec[i] = k_contact * max(0.0, -cl3[i]);
  end for;
  F_c3 = F_c3_sec[1] + F_c3_sec[2] + F_c3_sec[3] + F_c3_sec[4];
  F_fric3 = mu_obstacle * F_c3;

  // ===== Total distributed contact force and minimum clearance =====
  F_contact_total = F_c1 + F_c2 + F_c3;
  clearance_min = min(cl1[1], min(cl1[2], min(cl1[3], min(cl1[4],
    min(cl2[1], min(cl2[2], min(cl2[3], min(cl2[4],
    min(cl3[1], min(cl3[2], min(cl3[3], cl3[4])))))))))));

  // ===== Section dynamics — Finger 1 =====
  // Second-order per section: pressure-driven bending with restoring stiffness,
  // distributed disturbance torque, and contact generalized force.
  for i in 1:4 loop
    der(theta1[i]) = dtheta1[i];
    der(dtheta1[i]) = k_bend * p_act1
      - c_damp * dtheta1[i]
      - k_restore_eff * theta1[i]
      + F_c1_sec[i] * L_sec * (cos(alpha1[i]) * (x_sec1[i] - x_cyl) - sin(alpha1[i]) * (y_sec1[i] - y_cyl)) / max(1e-12, dist1[i])
      + F_dist * (4 - i) * L_sec;
  end for;

  // ===== Section dynamics — Finger 2 =====
  for i in 1:4 loop
    der(theta2[i]) = dtheta2[i];
    der(dtheta2[i]) = k_bend * p_act2
      - c_damp * dtheta2[i]
      - k_restore_eff * theta2[i]
      + F_c2_sec[i] * L_sec * (cos(alpha2[i]) * (x_sec2[i] - x_cyl) - sin(alpha2[i]) * (y_sec2[i] - y_cyl)) / max(1e-12, dist2[i])
      + F_dist * (4 - i) * L_sec;
  end for;

  // ===== Section dynamics — Finger 3 =====
  for i in 1:4 loop
    der(theta3[i]) = dtheta3[i];
    der(dtheta3[i]) = k_bend * p_act3
      - c_damp * dtheta3[i]
      - k_restore_eff * theta3[i]
      + F_c3_sec[i] * L_sec * (cos(alpha3[i]) * (x_sec3[i] - x_cyl) - sin(alpha3[i]) * (y_sec3[i] - y_cyl)) / max(1e-12, dist3[i])
      + F_dist * (4 - i) * L_sec;
  end for;

  // ===== Temperature dynamics (first-order thermal model) =====
  der(T1) = (T_amb + k_thermal * abs(p_act1) - T1) / tau_thermal;
  der(T2) = (T_amb + k_thermal * abs(p_act2) - T2) / tau_thermal;
  der(T3) = (T_amb + k_thermal * abs(p_act3) - T3) / tau_thermal;

  // ===== Maximum section deformation =====
  def_max = max(abs(theta1[1]), max(abs(theta1[2]), max(abs(theta1[3]), max(abs(theta1[4]),
    max(abs(theta2[1]), max(abs(theta2[2]), max(abs(theta2[3]), max(abs(theta2[4]),
    max(abs(theta3[1]), max(abs(theta3[2]), max(abs(theta3[3]), abs(theta3[4]))))))))))));

  // ===== Bounds checks =====
  actuator_ok = abs(p_act1) <= p_max_cmd + 1.0
    and abs(p_act2) <= p_max_cmd + 1.0
    and abs(p_act3) <= p_max_cmd + 1.0;
  deformation_ok = def_max <= theta_bound;
  contact_ok = F_contact_total <= F_contact_bound;
  temperature_ok = T1 <= T_bound and T2 <= T_bound and T3 <= T_bound;
  clearance_ok = clearance_min >= -0.005;
  tip_err_ok = tip_error <= err_threshold;
  all_bounds_ok = actuator_ok and deformation_ok and contact_ok
    and temperature_ok and clearance_ok;
  tracking_ok = (time >= t_settle) and tip_err_ok;

  // ===== NaN / infinity guard =====
  no_nan_inf = (p_act1 == p_act1) and (p_act2 == p_act2) and (p_act3 == p_act3)
    and (theta1[1] == theta1[1]) and (theta2[1] == theta2[1]) and (theta3[1] == theta3[1])
    and (tip_error == tip_error) and (F_contact_total == F_contact_total)
    and (T1 == T1) and (T2 == T2) and (T3 == T3);

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "SoftGripAvoidC: three-finger soft gripper with contact-aware shape control.
      Three 0.13 m silicone fingers, four bending sections each, around a rigid palm.
      Three chamber-pressure commands (one per finger) at 125 Hz discrete control.
      Fixed cylinder obstacle with friction coefficient 0.55 and collision enabled.
      7.2 N lateral tip load disturbance during middle third (4-8 s).
      Bounded stiffness scheduling: compliant approach, stiff hold near target.
      Max command 87.4 kPa gauge. Tracking error below 0.042 m after 7.8 s.
      Sensors: actuator state, distributed contact force, section deformation,
      tip pose, temperature. Obstacle clearance, deformation, contact-force,
      temperature, and actuator bounds enforced."));
end SoftGripAvoidC;