model VacuumToolPolishC
  import Modelica.Constants.pi;
  import Modelica.SIunits.*;

  parameter Length pathLength = 0.50 "Required surface path length";
  parameter Time T_run = 12.0 "Required run duration";
  parameter Frequency sampleRate = 125.0 "Required control/sensor rate";
  parameter Time Ts = 1.0 / sampleRate "Sample period";

  parameter Mass m_cup = 0.8 "Compliant suction cup mass";
  parameter Length r_cup = 0.038 "Suction cup radius";
  parameter Area A_vac = pi * r_cup * r_cup "Effective vacuum area";
  parameter Pressure pMax = 0.0 "Upper pressure command, gauge";
  parameter Pressure pMin = -70000.0 "Lower pressure command, gauge";
  parameter Force Fmax = 294.0 "Maximum linear actuator command magnitude";

  parameter Real mu = 0.50 "Workpiece friction coefficient";
  parameter Length workpieceAmplitude = 0.02 "Fixed curved workpiece amplitude; not specified by requirement, selected for explicit simulation";
  parameter TranslationalSpringConstant k_contact = 20000.0 "Compliant normal contact stiffness; not specified by requirement, selected for explicit simulation";
  parameter TranslationalDampingConstant c_contact = 200.0 "Compliant normal contact damping; not specified by requirement, selected for explicit simulation";

  parameter Force F_normal_min = 12.0 "Required minimum normal tool force";
  parameter Force F_normal_max = 30.0 "Required maximum normal tool force";
  parameter Force F_normal_ref = 21.0 "Constant normal force setpoint within required band";
  parameter Length trackingTol = 0.021 "Required primary tracking error tolerance after 7.8 s";
  parameter Time trackingTime = 7.8 "Time after which tracking tolerance applies";
  parameter Force F_dist_mag = 6.3 "Controlled surface-force disturbance magnitude";

  parameter Real Kp_s = 4000.0 "Tangential position gain";
  parameter Real Kd_s = 120.0 "Tangential velocity gain";
  parameter Real Kp_f = 300.0 "Normal force pressure gain";
  parameter Time tau_p = 0.01 "Vacuum pressure actuator time constant";
  parameter Velocity v_eps = 0.001 "Friction regularization velocity";

  parameter Length delta0 = F_normal_ref / k_contact "Initial normal indentation";
  parameter Pressure p0 = -F_normal_ref / A_vac "Initial vacuum pressure command";

  Length s "Tangential path coordinate";
  Velocity v "Tangential velocity";
  Length z "Vertical prismatic carriage position";
  Velocity vz "Vertical carriage velocity";
  Pressure p_vac(start = p0) "Actual vacuum pressure, gauge";

  Length y_w "Workpiece surface height at s";
  Real dy_w(unit = "1") "Surface height derivative with respect to s";
  Length delta "Normal indentation";
  Velocity delta_vel "Normal indentation rate";
  Force F_normal "Normal contact/tool force";
  Force F_vac "Vacuum-generated normal force";
  Force F_friction_mag "Friction magnitude opposing motion";
  Force F_dist "Injected surface-force disturbance";

  Real tau(unit = "1") "Normalized trajectory time";
  Length s_ref "Reference path coordinate";
  Velocity v_ref "Reference path velocity";
  Acceleration a_ref "Reference path acceleration";
  Length z_ref "Reference vertical carriage position";

  Length pathError "Primary tangential tracking error";
  Length poseError "Tool-tip pose error";
  Force wrenchTangent "Tangential wrist wrench";
  Force wrenchNormal "Normal wrist wrench";

  discrete Time sensorTime_d(start = 0.0);
  discrete Real tick_d(start = 0.0);
  discrete Force F_cmd_raw_d(start = 0.0);
  discrete Force F_cmd_d(start = 0.0);
  discrete Pressure p_cmd_raw_d(start = p0);
  discrete Pressure p_cmd_d(start = p0);

  discrete Length s_meas_d(start = 0.0);
  discrete Length z_meas_d(start = delta0);
  discrete Velocity v_est_d(start = 0.0);
  discrete Force F_n_meas_d(start = F_normal_ref);

  discrete Length s_ref_trace(start = 0.0);
  discrete Velocity v_ref_trace(start = 0.0);
  discrete Acceleration a_ref_trace(start = 0.0);

  discrete Length s_state_trace(start = 0.0);
  discrete Velocity v_state_trace(start = 0.0);
  discrete Length z_state_trace(start = delta0);
  discrete Velocity vz_state_trace(start = 0.0);
  discrete Length delta_state_trace(start = delta0);
  discrete Pressure p_vac_trace(start = p0);
  discrete Force F_normal_trace(start = F_normal_ref);
  discrete Force F_friction_trace(start = 0.0);
  discrete Force F_dist_trace(start = 0.0);

  discrete Force F_cmd_trace(start = 0.0);
  discrete Pressure p_cmd_trace(start = p0);
  discrete Pressure p_cmd_raw_trace(start = p0);

  discrete Length s_encoder_trace(start = 0.0);
  discrete Length z_encoder_trace(start = delta0);
  discrete Force wrenchTangent_trace(start = 0.0);
  discrete Force wrenchNormal_trace(start = F_normal_ref);
  discrete Length poseX_trace(start = 0.0);
  discrete Length poseY_trace(start = delta0);

  discrete Length s_est_trace(start = 0.0);
  discrete Velocity v_est_trace(start = 0.0);
  discrete Force F_normal_est_trace(start = F_normal_ref);

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
  poseError = sqrt(max(0.0, (s_ref - s) ^ 2 + (z_ref - z) ^ 2));

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