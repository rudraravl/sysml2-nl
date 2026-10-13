model VacuumToolPolishC
  import Modelica.Constants.pi;

  // Run configuration
  parameter Modelica.SIunits.Length pathLength = 0.50 "Required surface path length";
  parameter Modelica.SIunits.Time T_run = 12.0 "Required run duration";
  parameter Modelica.SIunits.Time Ts = 0.008 "Sample period for 125 Hz control and sensing";

  // Physical parameters
  parameter Modelica.SIunits.Mass m_cup = 0.8 "Compliant suction cup mass";
  parameter Modelica.SIunits.Length r_cup = 0.038 "Suction cup radius";
  parameter Modelica.SIunits.Area A_vac = pi * r_cup * r_cup "Effective vacuum area";
  parameter Modelica.SIunits.Pressure pMax = 0.0 "Upper pressure command, gauge";
  parameter Modelica.SIunits.Pressure pMin = -70000.0 "Lower pressure command, gauge";
  parameter Modelica.SIunits.Force Fmax = 294.0 "Maximum linear actuator command magnitude";
  parameter Real mu = 0.50 "Workpiece friction coefficient";

  // Workpiece and contact (values not specified by requirement; selected for explicit simulation)
  parameter Modelica.SIunits.Length workpieceAmplitude = 0.02 "Fixed curved workpiece amplitude";
  parameter Real k_contact(final unit = "N/m") = 20000.0 "Compliant normal contact stiffness";
  parameter Real c_contact(final unit = "N.s/m") = 200.0 "Compliant normal contact damping";

  // Requirement bounds
  parameter Modelica.SIunits.Force F_normal_min = 12.0 "Required minimum normal tool force";
  parameter Modelica.SIunits.Force F_normal_max = 30.0 "Required maximum normal tool force";
  parameter Modelica.SIunits.Force F_normal_ref = 21.0 "Constant normal force setpoint within required band";
  parameter Modelica.SIunits.Length trackingTol = 0.021 "Required primary tracking error tolerance after 7.8 s";
  parameter Modelica.SIunits.Time trackingTime = 7.8 "Time after which tracking tolerance applies";
  parameter Modelica.SIunits.Force F_dist_mag = 6.3 "Controlled surface-force disturbance magnitude";

  // Controller gains (values not specified by requirement; selected for explicit simulation)
  parameter Real Kp_s(final unit = "1/s2") = 4000.0 "Tangential position gain";
  parameter Real Kd_s(final unit = "1/s") = 120.0 "Tangential velocity gain";
  parameter Real Kp_f(final unit = "1/m2") = 300.0 "Normal force pressure gain";
  parameter Modelica.SIunits.Time tau_p = 0.01 "Vacuum pressure actuator time constant";
  parameter Modelica.SIunits.Velocity v_eps = 0.001 "Friction regularization velocity";

  // Derived parameters
  parameter Modelica.SIunits.Length delta0 = F_normal_ref / k_contact "Initial normal indentation";
  parameter Modelica.SIunits.Pressure p0 = -F_normal_ref / A_vac "Initial vacuum pressure command, gauge";

  // Continuous states
  Modelica.SIunits.Length s(start = 0.0) "Tangential path coordinate";
  Modelica.SIunits.Velocity v(start = 0.0) "Tangential velocity";
  Modelica.SIunits.Length z(start = delta0) "Vertical prismatic carriage position";
  Modelica.SIunits.Velocity vz(start = 0.0) "Vertical carriage velocity";
  Modelica.SIunits.Pressure p_vac(start = p0) "Actual vacuum pressure, gauge";

  // Continuous algebraic variables
  Modelica.SIunits.Length y_w "Workpiece surface height at s";
  Real dy_w(unit = "1") "Surface slope dy/ds";
  Modelica.SIunits.Length delta "Normal indentation";
  Modelica.SIunits.Velocity delta_vel "Normal indentation rate";
  Modelica.SIunits.Force F_normal "Normal contact force";
  Modelica.SIunits.Force F_vac "Vacuum-generated force";
  Modelica.SIunits.Force F_friction "Friction force opposing motion";
  Modelica.SIunits.Force F_dist "Injected surface-force disturbance";
  Real tau_traj(unit = "1") "Normalized trajectory time";
  Modelica.SIunits.Length s_ref "Reference path coordinate";
  Modelica.SIunits.Velocity v_ref "Reference path velocity";
  Modelica.SIunits.Acceleration a_ref "Reference path acceleration";
  Modelica.SIunits.Length z_ref "Reference vertical position";
  Modelica.SIunits.Length pathError "Primary tangential tracking error";

  // Discrete control variables
  discrete Modelica.SIunits.Force F_cmd_d(start = 0.0) "Bounded tangential force command";
  discrete Modelica.SIunits.Pressure p_cmd_d(start = p0) "Bounded pressure command";
  discrete Modelica.SIunits.Length s_meas_d(start = 0.0) "Sampled tangential position";
  discrete Modelica.SIunits.Velocity v_est_d(start = 0.0) "Estimated tangential velocity";
  discrete Modelica.SIunits.Force F_n_meas_d(start = F_normal_ref) "Sampled normal force";

  // Discrete synchronized traces at 125 Hz
  discrete Modelica.SIunits.Force F_cmd_trace(start = 0.0);
  discrete Modelica.SIunits.Pressure p_cmd_trace(start = p0);
  discrete Modelica.SIunits.Length s_trace(start = 0.0);
  discrete Modelica.SIunits.Velocity v_trace(start = 0.0);
  discrete Modelica.SIunits.Length z_trace(start = delta0);
  discrete Modelica.SIunits.Pressure p_vac_trace(start = p0);
  discrete Modelica.SIunits.Force F_normal_trace(start = F_normal_ref);
  discrete Modelica.SIunits.Length pathError_trace(start = 0.0);

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
  s_ref = pathLength * (10.0 * tau_traj ^ 3 - 15.0 * tau_traj ^ 4 + 6.0 * tau_traj ^ 5);
  v_ref = pathLength / T_run * (30.0 * tau_traj ^ 2 - 60.0 * tau_traj ^ 3 + 30.0 * tau_traj ^ 4);
  a_ref = pathLength / (T_run * T_run) * (60.0 * tau_traj - 180.0 * tau_traj ^ 2 + 120.0 * tau_traj ^ 3);

  // Fixed curved workpiece surface
  y_w = workpieceAmplitude * sin(pi * s / pathLength);
  dy_w = workpieceAmplitude * pi / pathLength * cos(pi * s / pathLength);
  z_ref = workpieceAmplitude * sin(pi * s_ref / pathLength) + delta0;

  // Compliant normal contact
  delta = z - y_w;
  delta_vel = vz - dy_w * v;
  F_normal = k_contact * delta + c_contact * delta_vel;
  F_vac = -A_vac * p_vac;
  F_friction = mu * abs(F_normal) * tanh(v / v_eps);

  // Controlled disturbance injection during middle third
  F_dist = if time >= T_run / 3.0 and time <= 2.0 * T_run / 3.0 then -F_dist_mag else 0.0;

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
  pressureOK = p_cmd_d >= pMin - 1.0e-3 and p_cmd_d <= pMax + 1.0e-3;
  jointOK = s >= -1.0e-6 and s <= pathLength + 1.0e-6;
  forceBandOK = F_normal >= F_normal_min and F_normal <= F_normal_max;
  continuousContactOK = delta > 1.0e-6;
  trackingOK = time < trackingTime or pathError <= trackingTol;
  finiteOK = abs(s) < 1.0e6 and abs(v) < 1.0e6 and abs(z) < 1.0e6 and abs(vz) < 1.0e6 and abs(F_normal) < 1.0e6 and abs(p_vac) < 1.0e9 and abs(F_cmd_d) < 1.0e6 and abs(p_cmd_d) < 1.0e9;
  requirementOK = effortOK and pressureOK and jointOK and forceBandOK and continuousContactOK and trackingOK and finiteOK;

  // Discrete control and sensing at 125 Hz
  when sample(0.0, Ts) then
    // Sensor sampling
    s_meas_d = s;
    v_est_d = (s - pre(s_meas_d)) / Ts;
    F_n_meas_d = F_normal;

    // Tangential trajectory control with effort bound
    F_cmd_d = max(-Fmax, min(Fmax, m_cup * (a_ref + Kp_s * (s_ref - s_meas_d) + Kd_s * (v_ref - v_est_d)) + mu * abs(F_n_meas_d) * tanh(v_est_d / v_eps)));

    // Normal force regulation via vacuum pressure with bound
    p_cmd_d = max(pMin, min(pMax, -F_normal_ref / A_vac - Kp_f * (F_normal_ref - F_n_meas_d)));

    // Synchronized traces
    F_cmd_trace = F_cmd_d;
    p_cmd_trace = p_cmd_d;
    s_trace = s;
    v_trace = v;
    z_trace = z;
    p_vac_trace = p_vac;
    F_normal_trace = F_normal;
    pathError_trace = pathError;
  end when;

  assert(effortOK, "Linear actuator effort bound violated");
  assert(pressureOK, "Vacuum pressure actuator bound violated");
  assert(jointOK, "Tangential joint/path bound violated");
  assert(forceBandOK, "Normal tool force outside required 12 N to 30 N band");
  assert(continuousContactOK, "Continuous contact lost");
  assert(trackingOK, "Primary tracking error requirement violated after 7.8 s");
  assert(finiteOK, "Non-finite physical, control, or estimator value detected");

  annotation(experiment(StopTime = 12.0, Interval = 0.008, Tolerance = 1.0e-6));
end VacuumToolPolishC;