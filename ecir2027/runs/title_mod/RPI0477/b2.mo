model VacuumToolPolishC
  parameter Real pi_c = 3.14159265358979 "Circle constant";

  // Run configuration
  parameter Real pathLength = 0.50 "Required surface path length [m]";
  parameter Real T_run = 12.0 "Required run duration [s]";
  parameter Real Ts = 0.008 "Sample period for 125 Hz [s]";

  // Physical parameters
  parameter Real m_cup = 0.8 "Compliant suction cup mass [kg]";
  parameter Real r_cup = 0.038 "Suction cup radius [m]";
  parameter Real A_vac = pi_c * r_cup * r_cup "Effective vacuum area [m2]";
  parameter Real pMax = 0.0 "Upper pressure command gauge [Pa]";
  parameter Real pMin = -70000.0 "Lower pressure command gauge [Pa]";
  parameter Real Fmax = 294.0 "Maximum linear actuator command magnitude [N]";
  parameter Real mu = 0.50 "Workpiece friction coefficient";

  // Workpiece and contact
  parameter Real workpieceAmplitude = 0.02 "Fixed curved workpiece amplitude [m]";
  parameter Real k_contact = 20000.0 "Compliant normal contact stiffness [N/m]";
  parameter Real c_contact = 200.0 "Compliant normal contact damping [N.s/m]";

  // Requirement bounds
  parameter Real F_normal_min = 12.0 "Required minimum normal tool force [N]";
  parameter Real F_normal_max = 30.0 "Required maximum normal tool force [N]";
  parameter Real F_normal_ref = 21.0 "Constant normal force setpoint [N]";
  parameter Real trackingTol = 0.021 "Required tracking error tolerance [m]";
  parameter Real trackingTime = 7.8 "Time after which tolerance applies [s]";
  parameter Real F_dist_mag = 6.3 "Surface-force disturbance magnitude [N]";

  // Controller gains
  parameter Real Kp_s = 4000.0 "Tangential position gain";
  parameter Real Kd_s = 120.0 "Tangential velocity gain";
  parameter Real Kp_f = 300.0 "Normal force pressure gain";
  parameter Real tau_p = 0.01 "Vacuum pressure actuator time constant [s]";
  parameter Real v_eps = 0.001 "Friction regularization velocity [m/s]";

  // Derived parameters
  parameter Real delta0 = F_normal_ref / k_contact "Initial normal indentation [m]";
  parameter Real p0 = -F_normal_ref / A_vac "Initial vacuum pressure command [Pa]";

  // Continuous states
  Real s(start = 0.0) "Tangential path coordinate [m]";
  Real v(start = 0.0) "Tangential velocity [m/s]";
  Real z(start = delta0) "Vertical prismatic carriage position [m]";
  Real vz(start = 0.0) "Vertical carriage velocity [m/s]";
  Real p_vac(start = p0) "Actual vacuum pressure gauge [Pa]";

  // Continuous algebraic variables
  Real y_w "Workpiece surface height at s [m]";
  Real dy_w "Surface slope dy/ds [1]";
  Real delta "Normal indentation [m]";
  Real delta_vel "Normal indentation rate [m/s]";
  Real F_normal "Normal contact force [N]";
  Real F_vac "Vacuum-generated force [N]";
  Real F_friction "Friction force opposing motion [N]";
  Real F_dist "Injected surface-force disturbance [N]";
  Real tau_traj "Normalized trajectory time [1]";
  Real s_ref "Reference path coordinate [m]";
  Real v_ref "Reference path velocity [m/s]";
  Real a_ref "Reference path acceleration [m/s2]";
  Real z_ref "Reference vertical position [m]";
  Real pathError "Primary tangential tracking error [m]";

  // Discrete control variables
  discrete Real F_cmd_d(start = 0.0) "Bounded tangential force command [N]";
  discrete Real p_cmd_d(start = p0) "Bounded pressure command [Pa]";
  discrete Real s_meas_d(start = 0.0) "Sampled tangential position [m]";
  discrete Real v_est_d(start = 0.0) "Estimated tangential velocity [m/s]";
  discrete Real F_n_meas_d(start = F_normal_ref) "Sampled normal force [N]";

  // Discrete synchronized traces at 125 Hz
  discrete Real F_cmd_trace(start = 0.0);
  discrete Real p_cmd_trace(start = p0);
  discrete Real s_trace(start = 0.0);
  discrete Real v_trace(start = 0.0);
  discrete Real z_trace(start = delta0);
  discrete Real p_vac_trace(start = p0);
  discrete Real F_normal_trace(start = F_normal_ref);
  discrete Real pathError_trace(start = 0.0);

  // Requirement status indicators
  Boolean effortOK;
  Boolean pressureOK;
  Boolean jointOK;
  Boolean forceBandOK;
  Boolean continuousContactOK;
  Boolean trackingOK;
  Boolean finiteOK;
  Boolean requirementOK;

equation
  // Trajectory reference (5th-order smooth polynomial)
  tau_traj = time / T_run;
  s_ref = pathLength * (10.0 * tau_traj^3 - 15.0 * tau_traj^4 + 6.0 * tau_traj^5);
  v_ref = (pathLength / T_run) * (30.0 * tau_traj^2 - 60.0 * tau_traj^3 + 30.0 * tau_traj^4);
  a_ref = (pathLength / (T_run * T_run)) * (60.0 * tau_traj - 180.0 * tau_traj^2 + 120.0 * tau_traj^3);

  // Fixed curved workpiece surface
  y_w = workpieceAmplitude * sin(pi_c * s / pathLength);
  dy_w = (workpieceAmplitude * pi_c / pathLength) * cos(pi_c * s / pathLength);
  z_ref = workpieceAmplitude * sin(pi_c * s_ref / pathLength) + delta0;

  // Compliant normal contact
  delta = z - y_w;
  delta_vel = vz - dy_w * v;
  F_normal = k_contact * delta + c_contact * delta_vel;
  F_vac = -A_vac * p_vac;
  F_friction = mu * abs(F_normal) * tanh(v / v_eps);

  // Controlled disturbance injection during middle third
  F_dist = if (time >= T_run / 3.0) and (time <= 2.0 * T_run / 3.0) then -F_dist_mag else 0.0;

  // Plant dynamics
  der(s) = v;
  der(v) = (F_cmd_d - F_friction + F_dist) / m_cup;
  der(z) = vz;
  der(vz) = (F_vac - F_normal) / m_cup;
  der(p_vac) = (p_cmd_d - p_vac) / tau_p;

  // Tracking error
  pathError = abs(s_ref - s);

  // Requirement checks
  effortOK = abs(F_cmd_d) <= Fmax + 1.0e-6;
  pressureOK = (p_cmd_d >= pMin - 1.0e-3) and (p_cmd_d <= pMax + 1.0e-3);
  jointOK = (s >= -1.0e-6) and (s <= pathLength + 1.0e-6);
  forceBandOK = (F_normal >= F_normal_min) and (F_normal <= F_normal_max);
  continuousContactOK = delta > 1.0e-6;
  trackingOK = (time < trackingTime) or (pathError <= trackingTol);
  finiteOK = (abs(s) < 1.0e6) and (abs(v) < 1.0e6) and (abs(z) < 1.0e6) and (abs(vz) < 1.0e6) and (abs(F_normal) < 1.0e6) and (abs(p_vac) < 1.0e9) and (abs(F_cmd_d) < 1.0e6) and (abs(p_cmd_d) < 1.0e9);
  requirementOK = effortOK and pressureOK and jointOK and forceBandOK and continuousContactOK and trackingOK and finiteOK;

  // Discrete control and sensing at 125 Hz
  when sample(0.0, Ts) then
    s_meas_d = s;
    v_est_d = (s - pre(s_meas_d)) / Ts;
    F_n_meas_d = F_normal;
    F_cmd_d = max(-Fmax, min(Fmax, m_cup * (a_ref + Kp_s * (s_ref - s_meas_d) + Kd_s * (v_ref - v_est_d)) + mu * abs(F_n_meas_d) * tanh(v_est_d / v_eps)));
    p_cmd_d = max(pMin, min(pMax, -F_normal_ref / A_vac - Kp_f * (F_normal_ref - F_n_meas_d)));
    F_cmd_trace = F_cmd_d;
    p_cmd_trace = p_cmd_d;
    s_trace = s;
    v_trace = v;
    z_trace = z;
    p_vac_trace = p_vac;
    F_normal_trace = F_normal;
    pathError_trace = pathError;
  end when;

  annotation(experiment(StopTime = 12.0, Interval = 0.008, Tolerance = 1.0e-6));
end VacuumToolPolishC;