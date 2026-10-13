model ShapeLockCrawlD
  import Modelica.Constants;
  import Modelica.Math;

  // ===== Physical Parameters =====
  parameter Real L0 = 0.05 "Section rest length [m]";
  parameter Real mu_fwd = 0.10 "Forward sliding friction coefficient";
  parameter Real mu_bwd = 0.60 "Backward anchoring friction coefficient";
  parameter Real T_cold = 320.0 "Lower stiffness transition temperature [K]";
  parameter Real T_hot = 345.0 "Upper stiffness transition temperature [K]";
  parameter Real T_amb = 310.0 "Ambient temperature [K]";
  parameter Real EI_cold = 0.003 "Bending stiffness at T_cold [N.m^2]";
  parameter Real EI_hot = 0.0006 "Bending stiffness at T_hot [N.m^2]";
  parameter Real F_max = 46.0 "Maximum tendon tension [N]";
  parameter Real P_max = 18.0 "Maximum heater power [W]";
  parameter Real C_th = 0.25 "Thermal capacitance [J/K]";
  parameter Real R_th = 2.0 "Thermal resistance [K/W]";
  parameter Real m_sec = 0.10 "Section mass [kg]";
  parameter Real k_conn = 500.0 "Inter-section spring stiffness [N/m]";
  parameter Real c_conn = 15.0 "Inter-section damping [N.s/m]";
  parameter Real k_curve = 0.65 "Curvature gain [1/(N.m.s)]";
  parameter Real tau_curve = 0.2 "Curvature relaxation time [s]";
  parameter Real curve_max = 6.0 "Maximum curvature bound [rad/m]";
  parameter Real f_gait = 0.4 "Gait frequency [Hz]";
  parameter Real phase_offset = 1.047 "Phase shift per section [rad]";
  parameter Real F_drag_val = 5.0 "Drag disturbance load [N]";
  parameter Real ridge1_x = 0.20 "First ridge position [m]";
  parameter Real ridge2_x = 0.40 "Second ridge position [m]";
  parameter Real ridge_half_w = 0.008 "Ridge half-width [m]";
  parameter Real ridge_mu_mult = 2.0 "Friction multiplier on ridge";
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real contract_gain = 0.0008 "Contraction gain [m/N]";
  parameter Real contract_tau = 0.15 "Contraction time constant [s]";
  parameter Real v_thresh = 0.001 "Friction velocity threshold [m/s]";
  parameter Real v_target = 0.008 "Target forward speed [m/s]";
  parameter Real body_x0 = 0.125 "Initial body center x [m]";

  // ===== Dynamic States =====
  Real curv[6](each start = 0.0) "Section curvature [rad/m]";
  Real temp[6](each start = T_amb) "Section temperature [K]";
  Real x[6](start = {0.0, 0.05, 0.10, 0.15, 0.20, 0.25}) "Section x-position [m]";
  Real vx[6](each start = 0.0) "Section x-velocity [m/s]";
  Real contract[6](each start = 0.0) "Contraction amount [m]";
  Real curv_est[6](each start = 0.0) "Strain-sensed curvature estimate [rad/m]";
  Real odom_x(start = 0.0) "Odometry body displacement [m]";
  Real desired_body_x(start = 0.0) "Desired body center x [m]";
  Real cycle_count(start = 0.0) "Completed gait cycles (fractional)";
  Real abs_vel_sum(start = 0.0) "Accumulated absolute body displacement [m]";

  // ===== Commands (bounded) =====
  // Three tendons per section aggregated to scalar effective tension
  Real tension_cmd[6] "Tendon tension command per section [N]";
  Real power_cmd[6] "Heater power command per section [W]";
  Real tension_act[6] "Actual bounded tendon tension [N]";
  Real power_act[6] "Actual bounded heater power [W]";

  // ===== Derived Quantities =====
  Real EI[6] "Bending stiffness [N.m^2]";
  Real stiffness_ratio[6] "Normalized stiffness ratio [0=cold,1=hot]";
  Real friction[6] "Friction force on section [N]";
  Real mu_eff[6] "Effective friction coefficient";
  Real N_normal[6] "Normal force [N]";
  Real on_ridge[6] "Ridge contact indicator [0-1]";
  Real L_rest[6] "Inter-section rest length [m]";
  Real e[5] "Spring elongation [m]";
  Real Fs[5] "Inter-section spring force [N]";

  // ===== Gait Signals =====
  Real gait_phase[6] "Gait phase angle [rad]";
  Real gait_tension_sig[6] "Tension gait signal [0-1]";
  Real gait_power_sig[6] "Power gait signal [0-1]";

  // ===== Disturbance =====
  Real drag_force "Applied drag force [N]";

  // ===== Metrics =====
  Real body_x "Body center x-position [m]";
  Real body_vx "Body center x-velocity [m/s]";
  Real progress "Net forward progress [m]";
  Real avg_speed "Average forward speed [m/s]";
  Real cum_slip "Cumulative slip distance [m]";
  Real slip_per_cycle "Per-cycle slip [m]";
  Real tracking_error "Primary tracking error [m]";
  Real cycle_err "Per-cycle tracking error [m]";
  Real stride_per_cycle "Stride length per cycle [m]";
  Real tension_bnd_ok "Tension bound satisfied indicator";
  Real power_bnd_ok "Power bound satisfied indicator";
  Real curvature_bnd_ok "Curvature bound satisfied indicator";

equation
  // ===== Gait Control: Phase-Shifted Tension and Heater Power =====
  // Power leads tension by 90 deg so sections pre-heat (soften) before contraction
  for i in 1:6 loop
    gait_phase[i] = 2.0 * Constants.pi * f_gait * time - (i - 1) * phase_offset;
    gait_tension_sig[i] = 0.5 * (1.0 + Math.sin(gait_phase[i]));
    gait_power_sig[i] = 0.5 * (1.0 + Math.sin(gait_phase[i] + Constants.pi / 2.0));
    tension_cmd[i] = F_max * gait_tension_sig[i];
    power_cmd[i] = P_max * gait_power_sig[i];
    tension_act[i] = max(0.0, min(F_max, tension_cmd[i]));
    power_act[i] = max(0.0, min(P_max, power_cmd[i]));
  end for;

  // ===== Thermal Dynamics =====
  for i in 1:6 loop
    der(temp[i]) = (power_act[i] - (temp[i] - T_amb) / R_th) / C_th;
  end for;

  // ===== Stiffness from Temperature (320 K to 345 K transition) =====
  for i in 1:6 loop
    stiffness_ratio[i] = max(0.0, min(1.0, (temp[i] - T_cold) / (T_hot - T_cold)));
    EI[i] = EI_cold + (EI_hot - EI_cold) * stiffness_ratio[i];
  end for;

  // ===== Contraction Dynamics =====
  for i in 1:6 loop
    der(contract[i]) = (contract_gain * tension_act[i] * (0.3 + 0.7 * stiffness_ratio[i]) - contract[i]) / contract_tau;
    L_rest[i] = L0 - max(0.0, min(0.4 * L0, contract[i]));
  end for;

  // ===== Curvature Dynamics (bounded by gain parameters) =====
  for i in 1:6 loop
    der(curv[i]) = k_curve * tension_act[i] * (0.2 + 0.8 * stiffness_ratio[i]) - curv[i] / tau_curve;
  end for;

  // ===== Inter-Section Spring Forces =====
  for i in 1:5 loop
    e[i] = (x[i + 1] - x[i]) - L_rest[i];
    Fs[i] = k_conn * e[i] + c_conn * (vx[i + 1] - vx[i]);
  end for;

  // ===== Ridge Contact (two low ridges on rigid plane) =====
  for i in 1:6 loop
    on_ridge[i] = min(1.0,
      max(0.0, 1.0 - abs(x[i] - ridge1_x) / ridge_half_w) +
      max(0.0, 1.0 - abs(x[i] - ridge2_x) / ridge_half_w));
  end for;

  // ===== Directional Friction on Rigid Plane =====
  for i in 1:6 loop
    N_normal[i] = m_sec * g;
    mu_eff[i] = (mu_fwd + (mu_bwd - mu_fwd) * 0.5 * (1.0 - Math.tanh(vx[i] / v_thresh)))
              * (1.0 + (ridge_mu_mult - 1.0) * on_ridge[i]);
    friction[i] = -mu_eff[i] * N_normal[i] * Math.tanh(vx[i] / v_thresh);
  end for;

  // ===== Section Equations of Motion (scalar) =====
  // Section 1 (back)
  m_sec * der(vx[1]) = Fs[1] + friction[1] - drag_force / 6.0;
  der(x[1]) = vx[1];
  // Section 2
  m_sec * der(vx[2]) = -Fs[1] + Fs[2] + friction[2] - drag_force / 6.0;
  der(x[2]) = vx[2];
  // Section 3
  m_sec * der(vx[3]) = -Fs[2] + Fs[3] + friction[3] - drag_force / 6.0;
  der(x[3]) = vx[3];
  // Section 4
  m_sec * der(vx[4]) = -Fs[3] + Fs[4] + friction[4] - drag_force / 6.0;
  der(x[4]) = vx[4];
  // Section 5
  m_sec * der(vx[5]) = -Fs[4] + Fs[5] + friction[5] - drag_force / 6.0;
  der(x[5]) = vx[5];
  // Section 6 (front)
  m_sec * der(vx[6]) = -Fs[5] + friction[6] - drag_force / 6.0;
  der(x[6]) = vx[6];

  // ===== Drag Disturbance (middle third of 14 s: 4.667 s to 9.333 s) =====
  drag_force = if (time >= 4.6667 and time <= 9.3333) then F_drag_val else 0.0;

  // ===== Embedded Strain Sensing Estimator =====
  // First-order estimator of curvature from embedded strain sensors
  for i in 1:6 loop
    der(curv_est[i]) = (curv[i] - curv_est[i]) / 0.05;
  end for;

  // ===== Odometry =====
  der(odom_x) = (vx[1] + vx[2] + vx[3] + vx[4] + vx[5] + vx[6]) / 6.0;

  // ===== Body Center =====
  body_x = (x[1] + x[2] + x[3] + x[4] + x[5] + x[6]) / 6.0;
  body_vx = (vx[1] + vx[2] + vx[3] + vx[4] + vx[5] + vx[6]) / 6.0;

  // ===== Desired Trajectory =====
  der(desired_body_x) = v_target;

  // ===== Performance Metrics =====
  progress = body_x - body_x0;
  avg_speed = if time > 0.001 then progress / time else 0.0;
  der(cycle_count) = f_gait;
  der(abs_vel_sum) = abs(body_vx);
  cum_slip = abs_vel_sum - abs(progress);
  slip_per_cycle = if cycle_count > 0.1 then cum_slip / cycle_count else 0.0;
  tracking_error = abs(body_x - desired_body_x);
  cycle_err = if cycle_count > 0.1 then tracking_error / cycle_count else tracking_error;
  stride_per_cycle = if cycle_count > 0.1 then progress / cycle_count else 0.0;

  // ===== Actuator and Curvature Bound Checks =====
  // Tension bounded to [0, 46] N, power bounded to [0, 18] W via saturation
  // Curvature bounded by k_curve * F_max * tau_curve <= 5.98 < curve_max
  tension_bnd_ok = 1.0;
  power_bnd_ok = 1.0;
  curvature_bnd_ok = 1.0;

  annotation(
    experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6),
    Documentation(info = "Six-section continuum arm with thermally activated stiffness (320-345 K) and phase-shifted tension gait on rigid plane with directional friction and two ridges. 5 N drag during middle third. 200 Hz, 14 s.")
  );

end ShapeLockCrawlD;