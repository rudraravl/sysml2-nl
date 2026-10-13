model ContactStateObserveD
  // ------------------------------------------------------------------
  // Plant embodiment: 24 kg quadruped torso, 4 legs x 3 joints = 12 effort actuators
  // Sensing: joint encoders (pos/vel), foot contact & normal-force sensors,
  //          body IMU (acceleration), actuator effort (current/pressure proxy).
  // This model uses a scalar aggregate body-axis representation of the
  // torso dynamics to keep equations explicit, finite, and FMU-exportable.
  // Mapping from 12 joint torques to a single Cartesian aggregate force is
  // not specified by the request and is therefore represented as a
  // lumped effort-equivalent with the declared per-joint limit.
  // ------------------------------------------------------------------

  parameter Integer nLegs = 4 "number of legs";
  parameter Integer nJointsPerLeg = 3 "joints per leg";
  parameter Integer nActuators = nLegs * nJointsPerLeg "12 effort actuators";
  parameter Real m_body = 24.0 "torso mass [kg]";
  parameter Real tau_max_per_joint = 55.0 "per-joint effort limit [N.m]";
  // Aggregate effort-equivalent limit (unknown Jacobian -> linear sum bound)
  parameter Real F_actuator_limit = nActuators * tau_max_per_joint "aggregate effort-equivalent limit [N]";

  // Commanded hold state
  parameter Real x_cmd = 0.0 "commanded hold position [m]";
  parameter Real v_cmd = 0.0 "commanded hold velocity [m/s]";

  // PD tracking controller (holds commanded state against disturbance)
  parameter Real Kp = 400.0 "position gain [N/m]";
  parameter Real Kd = 40.0 "damping gain [N.s/m]";

  // Disturbance schedule: 14 N load during middle third of 14 s window
  parameter Real F_dist_amp = 14.0 "disturbance amplitude [N]";
  parameter Real t_start = 14.0 / 3.0 "load start [s]";
  parameter Real t_end = 2.0 * 14.0 / 3.0 "load end [s]";

  // Low-pass residual filter for model-based disturbance observer
  parameter Real fc = 10.0 "low-pass cutoff frequency [Hz]";
  parameter Real tau_lp = 1.0 / (2.0 * 3.14159265358979 * fc) "low-pass time constant [s]";

  // Execution
  parameter Real Ts = 0.005 "sample period [s] (200 Hz)";
  parameter Real t_end_sim = 14.0 "simulation end time [s]";

  // Dynamic plant states
  Real x(start = 0.0, fixed = true) "body position [m]";
  Real v(start = 0.0, fixed = true) "body velocity [m/s]";
  Real a "body acceleration [m/s2]";

  // Actuator command and applied aggregate effort
  Real F_cmd "commanded aggregate actuator effort [N]";
  Real F_actuator "applied aggregate actuator effort [N]";

  // Disturbance
  Real F_dist "applied external disturbance force [N]";
  Boolean load_active "true during middle-third load interval";

  // Synchronized sensor traces
  Real x_meas "encoder position measurement [m]";
  Real v_meas "encoder velocity measurement [m/s]";
  Real a_meas "body IMU acceleration measurement [m/s2]";
  Real F_actuator_meas "actuator effort (current/pressure) measurement [N]";
  Real F_contact_meas "wrench/normal-force-related aggregate measurement [N]";

  // Observer states
  Real residual "raw model-based observer residual [N]";
  Real F_dist_hat(start = 0.0, fixed = true) "estimated disturbance [N]";

  // Estimator performance
  Real tracking_error "disturbance estimation error [N]";
  Real residual_norm "filtered residual magnitude for diagnostics [N]";

  function saturate
    input Real u;
    input Real limit;
    output Real y;
  algorithm
    if u > limit then
      y := limit;
    elseif u < -limit then
      y := -limit;
    else
      y := u;
    end if;
  end saturate;

equation
  // Disturbance schedule (deterministic load at declared body location,
  // applied as aggregate body-axis force; baseline is no-load before/after)
  load_active = (time >= t_start) and (time <= t_end);
  F_dist = if load_active then F_dist_amp else 0.0;

  // PD hold controller generating actuator effort command
  F_cmd = Kp * (x_cmd - x) + Kd * (v_cmd - v);
  // Per-joint effort limit enforced as aggregate bound
  F_actuator = saturate(F_cmd, F_actuator_limit);

  // Plant dynamics (Newton's second law on aggregate body axis)
  a = (F_actuator + F_dist) / m_body;
  der(x) = v;
  der(v) = a;

  // Ideal synchronized sensor traces
  x_meas = x;
  v_meas = v;
  a_meas = a;
  F_actuator_meas = F_actuator;
  // Wrench-related aggregate (contact/normal-force proxy): net external load
  F_contact_meas = F_dist;

  // Model-based disturbance observer:
  // Plant model (no disturbance): m_body * a = F_actuator
  // Residual = measured inertia force - measured actuator effort
  //          = m_body * a_meas - F_actuator_meas
  // In ideal case this equals F_dist.
  residual = m_body * a_meas - F_actuator_meas;

  // Low-pass filtered residual -> estimated disturbance
  der(F_dist_hat) = (residual - F_dist_hat) / tau_lp;

  // Estimation (tracking) error
  tracking_error = F_dist - F_dist_hat;

  // Diagnostics: magnitude with zero-error branch (avoid div-by-zero)
  // (no division used here; kept as a simple signed-state norm proxy)
  residual_norm = abs(residual);

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "ContactStateObserveD: instrumented robotic sensing and estimation system. 24 kg quadruped torso aggregate model with 12 limited joint-effort actuators, body IMU, encoders, contact/wrench sensors. Model-based disturbance observer with low-pass residual filtering estimates a 14 N load applied during the middle third of a 14 s hold. Primary tracking error converges below 2.5 N well before 9.1 s."),
    Diagram());
end ContactStateObserveD;