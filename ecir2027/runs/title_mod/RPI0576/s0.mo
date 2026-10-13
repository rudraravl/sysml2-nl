model SeriesElasticRecoverF
  "Series elastic actuator with disturbance observer, feedforward motion control, thermal and saturation dynamics"

  // === Physical parameters ===
  parameter Real V_supply(unit="V") = 48.0 "Motor supply voltage";
  parameter Real V_max(unit="V") = 58.6 "Maximum commanded voltage magnitude";
  parameter Real N = 100.0 "Gearbox reduction ratio";
  parameter Real k_spring(unit="N.m/rad") = 850.0 "Torsional spring stiffness";
  parameter Real Kt(unit="N.m/A") = 0.1 "Motor torque constant";
  parameter Real Ke(unit="V.s/rad") = 0.1 "Motor back-EMF constant";
  parameter Real R_w(unit="Ohm") = 0.5 "Winding resistance";
  parameter Real L_w(unit="H") = 0.001 "Winding inductance";
  parameter Real J_m(unit="kg.m2") = 0.0001 "Motor rotor inertia";
  parameter Real b_m(unit="N.m.s/rad") = 0.0001 "Motor viscous friction";
  parameter Real J_l(unit="kg.m2") = 5.0 "Load inertia";
  parameter Real b_l(unit="N.m.s/rad") = 0.5 "Load viscous friction";
  parameter Real T_amb(unit="degC") = 25.0 "Ambient temperature";
  parameter Real C_th(unit="J/K") = 50.0 "Winding thermal capacitance";
  parameter Real R_th(unit="K/W") = 2.0 "Winding thermal resistance";

  // === Disturbance parameters ===
  parameter Real tau_dist_amp(unit="N.m") = 29.0 "Disturbance magnitude";
  parameter Real t_dist_start(unit="s") = 6.6667 "Disturbance start (middle third begin)";
  parameter Real t_dist_end(unit="s") = 13.3333 "Disturbance end (middle third end)";

  // === Trajectory parameters ===
  parameter Real T_move(unit="s") = 4.0 "Reference motion duration";
  parameter Real theta_target(unit="rad") = 1.0 "Target output angle";

  // === Controller parameters ===
  parameter Real Kp_pos(unit="N.m/rad") = 100.0 "Position proportional gain";
  parameter Real Kd_pos(unit="N.m.s/rad") = 40.0 "Position derivative gain";
  parameter Real Kp_curr(unit="V/A") = 50.0 "Current loop proportional gain";
  parameter Real Ki_curr(unit="V/(A.s)") = 500.0 "Current loop integral gain";
  parameter Real T_dobs(unit="s") = 0.01 "Disturbance observer filter time constant";

  // === Continuous states ===
  Real i(unit="A") "Motor winding current";
  Real omega_m(unit="rad/s") "Motor angular velocity";
  Real theta_m(unit="rad") "Motor angle";
  Real omega_l(unit="rad/s") "Load angular velocity";
  Real theta_l(unit="rad") "Load angle";
  Real T_winding(unit="degC") "Winding temperature";
  Real integ_i_err(unit="A.s") "Current error integral (for PI anti-windup)";
  Real tau_dist_est(unit="N.m") "Filtered disturbance estimate";

  // === Derived / algebraic ===
  Real tau_s(unit="N.m") "Spring torque (instrumented on both sides)";
  Real tau_motor(unit="N.m") "Motor electromagnetic torque";
  Real tau_disturbance(unit="N.m") "Applied external disturbance";
  Real theta_ref(unit="rad") "Reference output angle";
  Real omega_ref(unit="rad/s") "Reference output velocity";
  Real alpha_ref(unit="rad/s2") "Reference output acceleration";
  Real tau_s_ref(unit="N.m") "Reference spring torque command";
  Real i_ref(unit="A") "Reference current command";
  Real V_cmd(unit="V") "Unsaturated voltage command";
  Real V(unit="V") "Applied (saturated) voltage";
  Real tau_dist_raw(unit="N.m") "Raw disturbance estimate";
  Real tracking_error(unit="rad") "Primary tracking error";
  Real V_sat "Voltage saturation indicator (1.0=saturated, 0.0=not)";
  Real eta "Normalized time for trajectory";

equation
  // === Reference trajectory: 5th-order rest-to-rest polynomial ===
  eta = time / T_move;
  theta_ref = if time <= T_move then
    theta_target * (10.0*eta^3 - 15.0*eta^4 + 6.0*eta^5)
  else
    theta_target;
  omega_ref = if time <= T_move then
    theta_target * (30.0*eta^2 - 60.0*eta^3 + 30.0*eta^4) / T_move
  else
    0.0;
  alpha_ref = if time <= T_move then
    theta_target * (60.0*eta - 180.0*eta^2 + 120.0*eta^3) / T_move^2
  else
    0.0;

  // === Disturbance: applied during middle third of 20 s simulation ===
  tau_disturbance = if time >= t_dist_start and time <= t_dist_end then
    tau_dist_amp
  else
    0.0;

  // === Spring torque (both sides instrumented: gearbox output and load) ===
  tau_s = k_spring * (theta_m / N - theta_l);

  // === Motor torque ===
  tau_motor = Kt * i;

  // === Plant dynamics: electrical ===
  L_w * der(i) = V - R_w * i - Ke * omega_m;

  // === Plant dynamics: motor mechanical (rotor + gearbox input) ===
  J_m * der(omega_m) = tau_motor - tau_s / N - b_m * omega_m;
  der(theta_m) = omega_m;

  // === Plant dynamics: load mechanical (output side of spring) ===
  J_l * der(omega_l) = tau_s - tau_disturbance - b_l * omega_l;
  der(theta_l) = omega_l;

  // === Thermal dynamics: lumped winding temperature ===
  C_th * der(T_winding) = R_w * i^2 - (T_winding - T_amb) / R_th;

  // === Disturbance observer: model inversion + first-order filter ===
  tau_dist_raw = tau_s - J_l * der(omega_l) - b_l * omega_l;
  der(tau_dist_est) = (tau_dist_raw - tau_dist_est) / T_dobs;

  // === Outer loop: spring-torque control = feedforward + PD + disturbance comp ===
  tau_s_ref = J_l * alpha_ref + b_l * omega_ref + tau_dist_est
    + Kp_pos * (theta_ref - theta_l) + Kd_pos * (omega_ref - omega_l);

  // === Inner loop: current control (torque-to-current + feedforward + PI) ===
  i_ref = tau_s_ref / (Kt * N);
  der(integ_i_err) = i_ref - i;
  V_cmd = R_w * i_ref + Ke * omega_m + Kp_curr * (i_ref - i) + Ki_curr * integ_i_err;

  // === Voltage saturation (preserves actuator limits) ===
  V = if V_cmd > V_max then V_max
    else if V_cmd < -V_max then -V_max
    else V_cmd;
  V_sat = if abs(V_cmd) > V_max then 1.0 else 0.0;

  // === Primary tracking error observation ===
  tracking_error = theta_ref - theta_l;

initial equation
  i = 0.0;
  omega_m = 0.0;
  theta_m = 0.0;
  omega_l = 0.0;
  theta_l = 0.0;
  T_winding = T_amb;
  integ_i_err = 0.0;
  tau_dist_est = 0.0;

  annotation (
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "
      Series Elastic Actuator recovery scenario at 500 Hz (Interval=0.002 s) for 20 s.
      A 29 N.m disturbance is applied during the middle third [6.6667, 13.3333] s.
      Primary tracking error target: below 0.032 rad after 13 s.
      Voltage limited to +/- 58.6 V. Winding temperature observed.
      Disturbance observer uses model inversion with first-order filter (T_dobs=0.01 s).
      Feedforward motion control uses 5th-order rest-to-rest polynomial reference.
    ")
  );
end SeriesElasticRecoverF;