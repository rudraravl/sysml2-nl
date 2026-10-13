model VacuumToolPolishF
  "Contact-rich manipulation: vacuum-tool polishing on curved surface with force regulation"

  // Physical parameters
  parameter Real m_tool(unit="kg") = 0.8 "Tool mass";
  parameter Real r_cup(unit="m") = 0.038 "Suction cup radius";
  parameter Real A_cup(unit="m2") = 3.14159265358979 * r_cup * r_cup "Effective cup area";
  parameter Real mu = 0.50 "Friction coefficient";
  parameter Real k_contact(unit="N/m") = 5000.0 "Compliant normal contact stiffness";
  parameter Real d_contact(unit="N.s/m") = 200.0 "Normal contact damping";

  // Actuator bounds
  parameter Real p_min(unit="Pa") = -70000.0 "Minimum gauge pressure (maximum vacuum)";
  parameter Real F_lin_max(unit="N") = 390.0 "Linear actuator force bound";

  // Mission parameters
  parameter Real F_normal_set(unit="N") = 20.0 "Target regulated normal force";
  parameter Real L_path(unit="m") = 0.50 "Surface path length";
  parameter Real T_run(unit="s") = 20.0 "Total mission duration";
  parameter Real v_ref(unit="m/s") = L_path / T_run "Reference tangential velocity";

  // Controller gains
  parameter Real Ki_pressure(unit="Pa/s/N") = 2000.0 "Normal-force pressure integrator gain";
  parameter Real Kp_traj(unit="N/m") = 2000.0 "Trajectory proportional gain";
  parameter Real Kd_traj(unit="N.s/m") = 100.0 "Trajectory derivative gain";

  // Dynamic states
  Real s(unit="m") "Tangential position along surface path";
  Real v_s(unit="m/s") "Tangential velocity";
  Real x_n(unit="m") "Normal penetration into compliant surface";
  Real v_n(unit="m/s") "Normal velocity";
  Real p_int(unit="Pa") "Pressure controller integrator state";

  // Commands
  Real F_lin(unit="N") "Linear actuator force command";
  Real p_cmd(unit="Pa") "Vacuum gauge pressure command";

  // Sensor / observation outputs
  Real s_ref(unit="m") "Reference path position";
  Real F_n(unit="N") "Measured normal contact force (wrist wrench normal component)";
  Real F_t(unit="N") "Tangential friction force";
  Real F_dist(unit="N") "Applied surface-force disturbance";
  Real tracking_error(unit="m") "Primary path tracking error |s_ref - s|";

initial equation
  s = 0.0;
  v_s = 0.0;
  x_n = F_normal_set / k_contact "Initial penetration for target normal force";
  v_n = 0.0;
  p_int = -F_normal_set / A_cup "Initial vacuum near equilibrium";

equation
  // Reference trajectory: constant-velocity ramp over full path
  s_ref = min(L_path * time / T_run, L_path);
  tracking_error = s_ref - s;

  // Robustness case: 10.2 N disturbance during middle third
  if time >= T_run / 3.0 and time <= 2.0 * T_run / 3.0 then
    F_dist = 10.2;
  else
    F_dist = 0.0;
  end if;

  // Compliant normal contact (spring-damper, observable wrench)
  F_n = k_contact * x_n + d_contact * v_n;

  // Coulomb friction with regularized sign (zero-error branch included)
  F_t = mu * F_n * (v_s / (abs(v_s) + 0.01));

  // Normal-force regulation via vacuum pressure (integral controller with saturation)
  der(p_int) = Ki_pressure * (F_normal_set - F_n);
  p_cmd = max(p_min, min(0.0, p_int));

  // Tangential trajectory control: PD with velocity feedforward, bounded actuator
  F_lin = max(-F_lin_max, min(F_lin_max,
    Kp_traj * (s_ref - s) - Kd_traj * (v_s - v_ref)));

  // Tangential dynamics: linear actuator drives, friction and disturbance oppose
  der(s) = v_s;
  der(v_s) = (F_lin - F_t - F_dist) / m_tool;

  // Normal dynamics: vacuum suction pulls tool into surface, contact resists
  der(x_n) = v_n;
  der(v_n) = (-p_cmd * A_cup - F_n) / m_tool;

  annotation (
    Documentation(info="VacuumToolPolishF: 0.50 m surface path with constant 20 N normal force.
Carries 0.8 kg compliant suction cup (r=0.038 m), vacuum command 0 to -70 kPa gauge.
Linear actuator bounded at 390 N. Friction coeff 0.50. 10.2 N disturbance in middle third.
500 Hz, 20 s run. Verification: force in [12,30] N, tracking error < 0.016 m after 13 s."),
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002)
  );
end VacuumToolPolishF;