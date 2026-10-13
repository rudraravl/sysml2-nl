model VacuumToolPolishC
  import Modelica.Constants.pi;

  parameter Real pathLength(unit = "m") = 0.50 "Required surface path length";
  parameter Real T_run(unit = "s") = 12.0 "Required run duration";
  parameter Real sampleRate(unit = "Hz") = 125.0 "Required control/sensor rate";
  parameter Real Ts(unit = "s") = 1.0 / sampleRate "Sample period";

  parameter Real m_cup(unit = "kg") = 0.8 "Compliant suction cup mass";
  parameter Real r_cup(unit = "m") = 0.038 "Suction cup radius";
  parameter Real A_vac(unit = "m2") = pi * r_cup * r_cup "Effective vacuum area";
  parameter Real pMax(unit = "Pa") = 0.0 "Upper pressure command, gauge";
  parameter Real pMin(unit = "Pa") = -70000.0 "Lower pressure command, gauge";
  parameter Real Fmax(unit = "N") = 294.0 "Maximum linear actuator command magnitude";

  parameter Real mu = 0.50 "Workpiece friction coefficient";
  parameter Real workpieceAmplitude(unit = "m") = 0.02 "Fixed curved workpiece amplitude; not specified by requirement, selected for explicit simulation";
  parameter Real k_contact(unit = "N/m") = 20000.0 "Compliant normal contact stiffness; not specified by requirement, selected for explicit simulation";
  parameter Real c_contact(unit = "N.s/m") = 200.0 "Compliant normal contact damping; not specified by requirement, selected for explicit simulation";

  parameter Real F_normal_min(unit = "N") = 12.0 "Required minimum normal tool force";
  parameter Real F_normal_max(unit = "N") = 30.0 "Required maximum normal tool force";
  parameter Real F_normal_ref(unit = "N") = 21.0 "Constant normal force setpoint within required band";
  parameter Real trackingTol(unit = "m") = 0.021 "Required primary tracking error tolerance after 7.8 s";
  parameter Real trackingTime(unit = "s") = 7.8 "Time after which tracking tolerance applies";
  parameter Real F_dist_mag(unit = "N") = 6.3 "Controlled surface-force disturbance magnitude";

  parameter Real Kp_s(unit = "N/m") = 4000.0 "Tangential position gain";
  parameter Real Kd_s(unit = "N.s/m") = 120.0 "Tangential velocity gain";
  parameter Real Kp_f(unit = "Pa/N") = 300.0 "Normal force pressure gain";
  parameter Real tau_p(unit = "s") = 0.01 "Vacuum pressure actuator time constant";
  parameter Real v_eps(unit = "m/s") = 0.001 "Friction regularization velocity";

  parameter Real delta0(unit = "m") = F_normal_ref / k_contact "Initial normal indentation";
  parameter Real p0(unit = "Pa") = -F_normal_ref / A_vac "Initial vacuum pressure command";

  Real s(unit = "m") "Tangential path coordinate";
  Real v(unit = "m/s") "Tangential velocity";
  Real z(unit = "m") "Vertical prismatic carriage position";
  Real vz(unit = "m/s") "Vertical carriage velocity";
  Real p_vac(unit = "Pa", start = p0) "Actual vacuum pressure, gauge";

  Real y_w(unit = "m") "Workpiece surface height at s";
  Real dy_w(unit = "1") "Surface height derivative with respect to s";
  Real delta(unit = "m") "Normal indentation";
  Real delta_vel(unit = "m/s") "Normal indentation rate";
  Real F_normal(unit = "N") "Normal contact/tool force";
  Real F_vac(unit = "N") "Vacuum-generated normal force";
  Real F_friction_mag(unit = "N") "Friction magnitude opposing motion";
  Real F_dist(unit = "N") "Injected surface-force disturbance";

  Real tau(unit = "1") "Normalized trajectory time";
  Real s_ref(unit = "m") "Reference path coordinate";
  Real v_ref(unit = "m/s") "Reference path velocity";
  Real a_ref(unit = "m/s2") "Reference path acceleration";
  Real z_ref(unit = "m") "Reference vertical carriage position";

  Real pathError(unit = "m") "Primary tangential tracking error";
  Real poseError(unit = "m") "Tool-tip pose error";
  Real wrenchTangent(unit = "N") "Tangential wrist wrench";
  Real wrenchNormal(unit = "N") "Normal wrist wrench";

  discrete Real sensorTime_d(unit = "s", start = 0.0);
  discrete Real tick_d(start = 0.0);
  discrete Real F_cmd_raw_d(unit = "N", start = 0.0);
  discrete Real F_cmd_d(unit = "N", start = 0.0);
  discrete Real p_cmd_raw_d(unit = "Pa", start = p0);
  discrete Real p_cmd_d(unit = "Pa", start = p0);

  discrete Real s_meas_d(unit = "m", start = 0.0);
  discrete Real z_meas_d(unit = "m", start = delta0);
  discrete Real v_est_d(unit = "m/s", start = 0.0);
  discrete Real F_n_meas_d(unit = "N", start = F_normal_ref);

  discrete Real s_ref_trace(unit = "m", start = 0.0);
  discrete Real v_ref_trace(unit = "m/s", start = 0.0);
  discrete Real a_ref_trace(unit = "m/s2", start = 0.0);

  discrete Real s_state_trace(unit = "m", start = 0.0);
  discrete Real v_state_trace(unit = "m/s", start = 0.0);
  discrete Real z_state_trace(unit = "m", start = delta0);
  discrete Real vz_state_trace(unit = "m/s", start = 0.0);
  discrete Real delta_state_trace(unit = "m", start = delta0);
  discrete Real p_vac_trace(unit = "Pa", start = p0);
  discrete Real F_normal_trace(unit = "N", start = F_normal_ref);
  discrete Real F_friction_trace(unit = "N", start = 0.0);
  discrete Real F_dist_trace(unit = "N", start = 0.0);

  discrete Real F_cmd_trace(unit = "N", start = 0.0);
  discrete Real p_cmd_trace(unit = "Pa", start = p0);
  discrete Real p_cmd_raw_trace(unit = "Pa", start = p0);

  discrete Real s_encoder_trace(unit = "m", start = 0.0);
  discrete Real z_encoder_trace(unit = "m", start = delta0);
  discrete Real wrenchTangent_trace(unit = "N", start = 0.0);
  discrete Real wrenchNormal_trace(unit = "N", start = F_normal_ref);
  discrete Real poseX_trace(unit = "m", start = 0.0);
  discrete Real poseY_trace(unit = "m", start = delta0);

  discrete Real s_est_trace(unit = "m", start = 0.0);
  discrete Real v_est_trace(unit = "m/s", start = 0.0);
  discrete Real F_normal_est_trace(unit = "N", start = F_normal_ref);

  Boolean effortOK;
  Boolean pressureOK;
  Boolean jointOK;
  Boolean boundsOK;
  Boolean forceBandOK;
  Boolean continuousContactOK;
  Boolean trackingOK;
  Boolean finitePhysical;
  Boolean finiteControl;
  Boolean finiteEstimator;
  Boolean requirementOK;

initial equation
  s = 0.0;
  v = 0.0;
  z = delta0;
  vz = 0.0;
  p_vac = p0;

equation
  tau = time / T_run;
  s_ref = pathLength * (10.0 * tau ^ 3 - 15.0 * tau ^ 4 + 6.0 * tau ^ 5);
  v_ref = pathLength / T_run * (30.0 * tau ^ 2 - 60.0 * tau ^ 3 + 30.0 * tau ^ 4);
  a_ref = pathLength / (T_run * T_run) * (60.0 * tau - 180.0 * tau ^ 2 + 120.0 * tau ^ 3);

  y_w = workpieceAmplitude * sin(pi * s / pathLength);
  dy_w = workpieceAmplitude * pi / pathLength * cos(pi * s / pathLength);
  z_ref = workpieceAmplitude * sin(pi * s_ref / pathLength) + delta0;

  delta = z - y_w;
  delta_vel = vz - dy_w * v;
  F_normal = k_contact * delta + c_contact * delta_vel;
  F_vac = -A_vac * p_vac;
  F_friction_mag = mu * F_normal * tanh(v / v_eps);
  F_dist = if time >= T_run / 3.0 and time <= 2.0 * T_run / 3.0 then -F_dist_mag else 0.0;

  der(s) = v;
  der(v) = (F_cmd_d - F_friction_mag + F_dist) / m_cup;
  der(z) = vz;
  der(vz) = (F_vac - F_normal) / m_cup;
  der(p_vac) = (p_cmd_d - p_vac) / tau_p;

  wrenchTangent = F_dist - F_friction_mag;
  wrenchNormal = F_normal;
  pathError = abs(s_ref - s);
  poseError = sqrt(max(1.0e-12, (s_ref - s) ^ 2 + (z_ref - z) ^ 2));

  effortOK = abs(F_cmd_d) <= Fmax + 1.0e-6;
  pressureOK = p_cmd_d >= pMin - 1.0e-3 and p_cmd_d <= pMax + 1.0e-3;
  jointOK = s >= -1.0e-6 and s <= pathLength + 1.0e-6;
  boundsOK = effortOK and pressureOK and jointOK;
  forceBandOK = F_normal >= F_normal_min and F_normal <= F_normal_max;
  continuousContactOK = delta > 1.0e-6;
  trackingOK = time < trackingTime or pathError <= trackingTol;
  finitePhysical = abs(s) < 1.0e6 and abs(v) < 1.0e6 and abs(z) < 1.0e6 and abs(vz) < 1.0e6 and abs(delta) < 1.0e6 and abs(F_normal) < 1.0e6 and abs(p_vac) < 1.0e9;
  finiteControl = abs(F_cmd_d) < 1.0e6 and abs(p_cmd_d) < 1.0e9 and abs(F_cmd_raw_d) < 1.0e6 and abs(p_cmd_raw_d) < 1.0e9;
  finiteEstimator = abs(s_meas_d) < 1.0e6 and abs(v_est_d) < 1.0e6 and abs(F_n_meas_d) < 1.0e6 and abs(z_meas_d) < 1.0e6;
  requirementOK = boundsOK and forceBandOK and continuousContactOK and trackingOK and finitePhysical and finiteControl and finiteEstimator;

  assert(effortOK, "Linear actuator effort bound violated");
  assert(pressureOK, "Vacuum pressure actuator bound violated");
  assert(jointOK, "Tangential joint/path bound violated");
  assert(forceBandOK, "Normal tool force outside required 12 N to 30 N band");
  assert(continuousContactOK, "Continuous contact lost");
  assert(trackingOK, "Primary tracking error requirement violated after 7.8 s");
  assert(finitePhysical and finiteControl and finiteEstimator, "Non-finite physical, control, or estimator value detected");

  when sample(0, Ts) then
    tick_d = pre(tick_d) + 1.0;
    sensorTime_d = time;

    s_meas_d = s;
    z_meas_d = z;
    v_est_d = (s - pre(s_meas_d)) / Ts;
    F_n_meas_d = F_normal;

    F_cmd_raw_d = m_cup * (a_ref + Kp_s * (s_ref - s_meas_d) + Kd_s * (v_ref - v_est_d)) + mu * F_n_meas_d * tanh(v_est_d / v_eps);
    F_cmd_d = max(-Fmax, min(Fmax, F_cmd_raw_d));

    p_cmd_raw_d = -F_normal_ref / A_vac - Kp_f * (F_normal_ref - F_n_meas_d);
    p_cmd_d = max(pMin, min(pMax, p_cmd_raw_d));

    s_ref_trace = s_ref;
    v_ref_trace = v_ref;
    a_ref_trace = a_ref;

    s_state_trace = s;
    v_state_trace = v;
    z_state_trace = z;
    vz_state_trace = vz;
    delta_state_trace = delta;
    p_vac_trace = p_vac;
    F_normal_trace = F_normal;
    F_friction_trace = F_friction_mag;
    F_dist_trace = F_dist;

    F_cmd_trace = F_cmd_d;
    p_cmd_trace = p_cmd_d;
    p_cmd_raw_trace = p_cmd_raw_d;

    s_encoder_trace = s_meas_d;
    z_encoder_trace = z_meas_d;
    wrenchTangent_trace = F_dist - F_friction_mag;
    wrenchNormal_trace = F_normal;
    poseX_trace = s;
    poseY_trace = z;

    s_est_trace = s_meas_d;
    v_est_trace = v_est_d;
    F_normal_est_trace = F_n_meas_d;
  end when;

  annotation(experiment(StopTime = 12.0, Interval = 0.008, Tolerance = 1.0e-6));
end VacuumToolPolishC;