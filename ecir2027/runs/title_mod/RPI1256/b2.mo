model TorqueObserverBridgeB
  import Modelica.Constants.PI;

  // Mission timing
  final parameter Real Ts = 0.01 "fast proprioceptive/control period [s]";
  final parameter Real Ts_slow = 0.1 "slow absolute-position sensor period [s]";
  parameter Real t_drop_start = 2.2 "start of controlled dropout [s]";
  final parameter Real t_drop_end = t_drop_start + 5.6 "5.6 s dropout disturbance [s]";

  // Stated physical parameters
  parameter Real L = 0.58 "link length [m]";
  parameter Real m_link = 8.0 "link mass [kg]";
  parameter Real N = 70.0 "gear ratio [-]";
  parameter Real tau_out_max = 61.5 "allowed output torque magnitude [N.m]";

  // Unknown physical details labeled as placeholders, not stated facts
  parameter Real r_eff = 1.0 "unknown effective radius placeholder [m]";
  parameter Real kT = 1.0 "unknown motor torque constant placeholder [N.m/A]";
  parameter Real bT = 0.05 "unknown translational damping placeholder [N.s/m]";
  parameter Real bR = 0.05 "unknown rotational damping placeholder [N.m.s/rad]";
  final parameter Real J = m_link * L * L / 12 "inertia about center [kg.m^2]";
  final parameter Real F_max = tau_out_max / r_eff "force limit from output torque limit [N]";
  final parameter Real i_max = tau_out_max / (N * kT) "current limit from output torque limit [A]";
  // Voltage limit not stated; voltage-limit behavior omitted.

  // Controlled dropout disturbance
  parameter Real F_dist = 0.1 "translational disturbance during dropout [N]";
  parameter Real tau_dist = 1.0 "rotational disturbance during dropout [N.m]";

  // Trajectory with translation and rotation
  parameter Real Ax = 0.15 "translation amplitude [m]";
  parameter Real At = 0.35 "rotation amplitude [rad]";
  parameter Real fx = 0.25 "translation frequency [Hz]";
  parameter Real ft = 1.0 / 7.0 "rotation frequency [Hz]";
  final parameter Real wx = 2 * PI * fx;
  final parameter Real wt = 2 * PI * ft;

  // Controller gains
  parameter Real Kp_x = 60.0;
  parameter Real Kd_x = 30.0;
  parameter Real Kp_t = 20.0;
  parameter Real Kd_t = 6.0;

  // Estimator covariance and innovation gating
  parameter Real P_x0 = 0.001 "initial position covariance";
  parameter Real Q_x = 0.01 "process noise variance rate";
  parameter Real R_x = 0.001 "absolute position measurement variance";
  parameter Real gate_x = 1.0 "absolute position innovation gate";
  parameter Real K_vx = 0.1 "velocity correction gain from position innovation";

  // Continuous plant states
  Real x(start = 0.0, fixed = true) "translation [m]";
  Real vx(start = 0.0, fixed = true) "translation velocity [m/s]";
  Real theta(start = 0.0, fixed = true) "rotation [rad]";
  Real omega(start = 0.0, fixed = true) "rotation velocity [rad/s]";

  // Drive and sensor traces
  Real F "applied translational force [N]";
  Real tau "applied rotational torque [N.m]";
  Real i_trans "motor current, translational drive [A]";
  Real i_rot "motor current, rotational drive [A]";
  Real motor_angle "joint encoder motor angle [rad]";
  Real x_abs "absolute position sensor [m]";
  Real theta_abs "absolute rotation sensor [rad]";
  Boolean dropout "declared dropout window";
  Real disturbanceF;
  Real disturbanceTau;

  // Reference traces
  Real x_ref, vx_ref, theta_ref, omega_ref;

  // Performance traces
  Real tracking_error;
  Real estimation_error;
  Real outage_error;
  Real recovery_error;
  Real command_torque_trans;
  Real command_torque_rot;

  // Discrete estimator/controller variables
  discrete Real x_est(start = 0.0, fixed = true);
  discrete Real vx_est(start = 0.0, fixed = true);
  discrete Real theta_est(start = 0.0, fixed = true);
  discrete Real omega_est(start = 0.0, fixed = true);
  discrete Real theta_enc_prev(start = 0.0, fixed = true);
  discrete Real P_x(start = P_x0, fixed = true);
  discrete Real x_abs_meas(start = 0.0, fixed = true);
  discrete Real theta_abs_meas(start = 0.0, fixed = true);
  discrete Real F_cmd_sat(start = 0.0, fixed = true);
  discrete Real tau_cmd_sat(start = 0.0, fixed = true);
  discrete Real innov_x(start = 0.0, fixed = true);
  discrete Real K_x(start = 0.0, fixed = true);
  discrete Real P_x_pred(start = P_x0, fixed = true);
  discrete Real x_pred(start = 0.0, fixed = true);
  discrete Real vx_pred(start = 0.0, fixed = true);
  discrete Real a_x(start = 0.0, fixed = true);
  discrete Real F_cmd(start = 0.0, fixed = true);
  discrete Real tau_cmd(start = 0.0, fixed = true);
  discrete Real i_trans_cmd(start = 0.0, fixed = true);
  discrete Real i_rot_cmd(start = 0.0, fixed = true);
  discrete Integer tick(start = 0, fixed = true);
  discrete Boolean gate_ok_x(start = false, fixed = true);

equation
  // Dropout window and controlled disturbance
  dropout = time >= t_drop_start and time <= t_drop_end;
  disturbanceF = if dropout then F_dist else 0.0;
  disturbanceTau = if dropout then tau_dist else 0.0;

  // Reference trajectory
  x_ref = Ax * sin(wx * time);
  vx_ref = Ax * wx * cos(wx * time);
  theta_ref = At * sin(wt * time);
  omega_ref = At * wt * cos(wt * time);

  // Plant dynamics
  der(x) = vx;
  der(vx) = (F - bT * vx + disturbanceF) / m_link;
  der(theta) = omega;
  der(omega) = (tau - bR * omega + disturbanceTau) / J;

  // Saturated drive commands applied to plant
  F = F_cmd_sat;
  tau = tau_cmd_sat;

  // Sensors
  i_trans = F * r_eff / (N * kT);
  i_rot = tau / (N * kT);
  motor_angle = N * theta;
  x_abs = x;
  theta_abs = theta;

  // Command traces
  command_torque_trans = F_cmd_sat * r_eff;
  command_torque_rot = tau_cmd_sat;

  // Performance metrics
  tracking_error = max(abs(x - x_ref), abs(theta - theta_ref));
  estimation_error = abs(x - x_est);
  outage_error = if dropout then estimation_error else 0.0;
  recovery_error = if time > t_drop_end then estimation_error else 0.0;

  // Requirement checks
  assert(abs(F_cmd_sat) <= F_max + 1e-9, "translation force/output-torque limit violated");
  assert(abs(command_torque_trans) <= tau_out_max + 1e-9, "translation output torque limit violated");
  assert(abs(command_torque_rot) <= tau_out_max + 1e-9, "rotation output torque limit violated");
  assert(time < 6.5 or tracking_error <= 0.42, "primary tracking error above 0.42 m-or-rad after 6.5 s");
  assert(not dropout or estimation_error <= 0.42, "outage estimation error unbounded");
  assert(time <= t_drop_end + 0.2 or estimation_error <= 0.1, "estimator recovery failed after measurements returned");

  when sample(0, Ts) then
    Real innov_local;
    Real K_local;
    Real F_cmd_local;
    Real tau_cmd_local;
    Real i_trans_local;
    Real i_rot_local;
    Boolean slow_now;
    Boolean use_abs;
  algorithm
    tick := pre(tick) + 1;
    slow_now := mod(pre(tick) + 1, 10) == 0;
    use_abs := slow_now and not (time >= t_drop_start and time <= t_drop_end);

    // Proprioceptive joint encoder update continues during dropout
    theta_enc_prev := theta;
    theta_est := theta;
    omega_est := (theta - pre(theta_enc_prev)) / Ts;

    // Inertial/proprioceptive propagation of translation
    a_x := (pre(F_cmd_sat) - bT * pre(vx_est)) / m_link;
    x_pred := pre(x_est) + pre(vx_est) * Ts + 0.5 * a_x * Ts * Ts;
    vx_pred := pre(vx_est) + a_x * Ts;
    P_x_pred := pre(P_x) + Q_x * Ts;

    // Multi-rate absolute sensor update with innovation gating
    if use_abs then
      x_abs_meas := x;
      theta_abs_meas := theta;
      innov_local := x - x_pred;
      innov_x := innov_local;
      if abs(innov_local) <= gate_x then
        K_local := P_x_pred / (P_x_pred + R_x);
        K_x := K_local;
        x_est := x_pred + K_local * innov_local;
        vx_est := vx_pred + K_vx * innov_local;
        P_x := (1.0 - K_local) * P_x_pred;
        gate_ok_x := true;
      else
        K_x := pre(K_x);
        x_est := x_pred;
        vx_est := vx_pred;
        P_x := P_x_pred;
        gate_ok_x := false;
      end if;
    else
      x_abs_meas := pre(x_abs_meas);
      theta_abs_meas := pre(theta_abs_meas);
      innov_x := pre(innov_x);
      K_x := pre(K_x);
      x_est := x_pred;
      vx_est := vx_pred;
      P_x := P_x_pred;
      gate_ok_x := false;
    end if;

    // Multi-rate controller using synchronized estimate
    F_cmd_local := Kp_x * (x_ref - x_est) + Kd_x * (vx_ref - vx_est);
    tau_cmd_local := Kp_t * (theta_ref - theta_est) + Kd_t * (omega_ref - omega_est);
    F_cmd := F_cmd_local;
    tau_cmd := tau_cmd_local;

    // Current and torque saturation
    i_trans_local := F_cmd_local * r_eff / (N * kT);
    if i_trans_local > i_max then
      F_cmd_sat := i_max * N * kT / r_eff;
    elseif i_trans_local < -i_max then
      F_cmd_sat := -i_max * N * kT / r_eff;
    else
      F_cmd_sat := F_cmd_local;
    end if;
    i_trans_cmd := F_cmd_local * r_eff / (N * kT);

    i_rot_local := tau_cmd_local / (N * kT);
    if i_rot_local > i_max then
      tau_cmd_sat := i_max * N * kT;
    elseif i_rot_local < -i_max then
      tau_cmd_sat := -i_max * N * kT;
    else
      tau_cmd_sat := tau_cmd_local;
    end if;
    i_rot_cmd := tau_cmd_local / (N * kT);
  end when;

  annotation(experiment(StopTime = 10, Tolerance = 1e-6, Interval = 0.01));
end TorqueObserverBridgeB;