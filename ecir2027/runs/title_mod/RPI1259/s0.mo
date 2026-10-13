model TorqueObserverBridgeE
  "Robotic torque-driven capsule link with multi-rate torque/current/encoder observer,
   9.6 s centered absolute-position dropout, fail-closed acceptance checks."

  constant Real PI = 3.141592653589793;
  constant Real TWO_PI = 2.0 * PI;

  // Plant parameters from requirement
  parameter Real L = 0.58 "m, fixed capsule link length";
  parameter Real m = 8.0 "kg, link mass";
  parameter Real N = 70.0 "gearbox ratio";
  parameter Real tau_max = 82.5 "N.m output command bound";
  parameter Real k_t = 1.0 "N.m/A, normalized motor torque constant; motor electrical constants not specified";
  parameter Real J_link = m * L * L / 3.0 "kg.m2, slender-rod end inertia approximation for fixed capsule link";

  // Timing from requirement
  parameter Real Ts = 1.0 / 250.0 "s, 250 Hz rate";
  parameter Real T_run = 16.0 "s";
  parameter Real T_drop_duration = 9.6 "s";
  parameter Real T_drop_start = (T_run - T_drop_duration) / 2.0 "s, centered dropout start";
  parameter Real T_drop_end = T_drop_start + T_drop_duration "s, dropout end";
  parameter Real T_slow = 0.1 "s, assumed slow absolute sensor period; not specified in requirement";
  parameter Integer n_slow = integer(T_slow / Ts + 0.5);
  parameter Integer n_drop_start = integer(T_drop_start / Ts + 0.5);
  parameter Integer n_drop_end = integer(T_drop_end / Ts + 0.5);
  parameter Integer n_recovery = integer((T_drop_end + 0.2) / Ts + 0.5);
  parameter Integer n_104 = integer(10.4 / Ts + 0.5);

  // Verification trajectory parameters; not plant facts
  parameter Real A_q = 0.8 "rad";
  parameter Real f_q = 0.1 "Hz";
  parameter Real w_q = TWO_PI * f_q "rad/s";
  parameter Real Kp = 80.0 "1/s^2";
  parameter Real Kd = 18.0 "1/s";

  // Estimator parameters
  parameter Real P0 = 0.001 "initial absolute covariance surrogate";
  parameter Real Q_abs = 0.01 "covariance growth rate per s";
  parameter Real R_abs = 0.001 "absolute sensor variance surrogate";
  parameter Real gate_enc = 0.5 "rad encoder innovation gate";
  parameter Real gate_abs = 0.3 "m-or-rad absolute innovation gate";
  parameter Real K_enc = 0.5 "encoder position gain";
  parameter Real K_enc_v = 0.5 "encoder velocity gain";

  // Continuous plant state and signals
  Real q(start = 0.0) "rad, joint/link angle";
  Real qd(start = 0.0) "rad/s";
  Real x "m, link end x";
  Real y "m, link end y";
  Real yaw "rad, link yaw";
  Real omega_motor "rad/s, motor side speed";
  Real tau_cmd "N.m output";
  Real tau_motor "N.m motor";
  Real i_motor "A";
  Real q_ref "rad";
  Real qd_ref "rad/s";
  Real qdd_ref "rad/s^2";
  Real x_ref "m";
  Real y_ref "m";
  Real tau_raw "N.m output before saturation";
  Real err_primary "m-or-rad, estimator vs true pose";
  Real err_track "m-or-rad, reference vs plant";

  // Estimate-derived continuous signals
  Real x_hat "m";
  Real y_hat "m";
  Real yaw_hat "rad";

  // Discrete estimator and sensor variables
  Integer n_tick(start = 0);
  Boolean sensor_avail(start = false);
  discrete Real x_sens(start = L);
  discrete Real y_sens(start = 0.0);
  discrete Real yaw_sens(start = 0.0);
  discrete Real q_hat(start = 0.0) "rad";
  discrete Real qd_hat(start = 0.0) "rad/s";
  discrete Real P_abs(start = P0);
  discrete Real q_enc_prev(start = 0.0);
  discrete Real qd_enc(start = 0.0);

  // Synchronized traces
  discrete Real t_log(start = 0.0);
  discrete Real q_log(start = 0.0);
  discrete Real qd_log(start = 0.0);
  discrete Real x_log(start = L);
  discrete Real y_log(start = 0.0);
  discrete Real yaw_log(start = 0.0);
  discrete Real tau_log(start = 0.0);
  discrete Real i_log(start = 0.0);
  discrete Real q_ref_log(start = 0.0);
  discrete Real q_enc_log(start = 0.0);
  discrete Real qd_enc_log(start = 0.0);
  discrete Real x_sens_log(start = L);
  discrete Real y_sens_log(start = 0.0);
  discrete Real yaw_sens_log(start = 0.0);
  Boolean sensor_avail_log(start = false);
  discrete Real x_hat_log(start = L);
  discrete Real y_hat_log(start = 0.0);
  discrete Real yaw_hat_log(start = 0.0);
  discrete Real q_hat_log(start = 0.0);
  discrete Real qd_hat_log(start = 0.0);
  discrete Real P_log(start = P0);
  discrete Real err_log(start = 0.0);
  discrete Real err_track_log(start = 0.0);

  // Acceptance records
  discrete Real err_outage_max(start = 0.0);
  discrete Real P_pre_drop(start = 0.0);
  discrete Real P_drop_end(start = 0.0);
  discrete Real P_post_recovery(start = 0.0);
  discrete Real err_at_104(start = 0.0);

  protected
  discrete Real q_pred(start = 0.0);
  discrete Real qd_pred(start = 0.0);
  discrete Real P_pred(start = 0.0);
  discrete Real innov_enc(start = 0.0);
  discrete Real qd_meas(start = 0.0);
  discrete Real dx(start = 0.0);
  discrete Real dy(start = 0.0);
  discrete Real dyaw(start = 0.0);
  discrete Real innov_norm(start = 0.0);
  discrete Real den(start = 1.0);
  discrete Real K_abs(start = 0.0);
  discrete Real err_now(start = 0.0);
  Boolean slow_tick(start = false);
  Boolean dropout(start = false);

  function wrapAngle
    input Real a;
    output Real b;
  protected
    constant Real twoPi = 6.283185307179586;
  algorithm
    b := a - twoPi * floor(a / twoPi + 0.5);
  end wrapAngle;

  function isFiniteValue
    input Real x;
    output Boolean y;
  algorithm
    y := (x < 1.0e300) and (x > -1.0e300);
  end isFiniteValue;

equation
  der(q) = qd;
  der(qd) = tau_cmd / J_link;

  x = L * cos(q);
  y = L * sin(q);
  yaw = q;
  omega_motor = N * qd;

  q_ref = A_q * sin(w_q * time);
  qd_ref = A_q * w_q * cos(w_q * time);
  qdd_ref = -A_q * w_q * w_q * sin(w_q * time);
  x_ref = L * cos(q_ref);
  y_ref = L * sin(q_ref);

  tau_raw = J_link * (qdd_ref + Kp * (q_ref - q) + Kd * (qd_ref - qd));
  tau_cmd = if tau_raw > tau_max then tau_max else if tau_raw < -tau_max then -tau_max else tau_raw;
  tau_motor = tau_cmd / N;
  i_motor = tau_motor / k_t;

  x_hat = L * cos(q_hat);
  y_hat = L * sin(q_hat);
  yaw_hat = q_hat;

  err_primary = sqrt((x - x_hat) * (x - x_hat) + (y - y_hat) * (y - y_hat) + (yaw - yaw_hat) * (yaw - yaw_hat));
  err_track = sqrt((x_ref - x) * (x_ref - x) + (y_ref - y) * (y_ref - y) + (q_ref - q) * (q_ref - q));

algorithm
  when sample(Ts, Ts) then
    n_tick := pre(n_tick) + 1;
    dropout := time >= T_drop_start and time < T_drop_end;
    slow_tick := mod(n_tick, n_slow) == 0;
    sensor_avail := slow_tick and not dropout;

    assert(time > pre(t_log), "TorqueObserverBridgeE: timestamp order violated");

    // Slow absolute-position sensor sampling
    if sensor_avail then
      x_sens := x;
      y_sens := y;
      yaw_sens := yaw;
    end if;

    // Proprioceptive joint encoder velocity
    qd_meas := (q - pre(q_enc_prev)) / Ts;
    q_enc_prev := q;
    qd_enc := qd_meas;

    // Inertial propagation
    q_pred := pre(q_hat) + Ts * pre(qd_hat);
    qd_pred := pre(qd_hat) + Ts * (tau_cmd / J_link);
    P_pred := pre(P_abs) + Q_abs * Ts;

    // Fast proprioceptive update with innovation gating
    innov_enc := q - q_pred;
    if abs(innov_enc) <= gate_enc then
      q_hat := q_pred + K_enc * innov_enc;
      qd_hat := qd_pred + K_enc_v * (qd_meas - qd_pred);
    else
      q_hat := q_pred;
      qd_hat := qd_pred;
    end if;

    // Slow absolute update with innovation gating
    if sensor_avail then
      dx := x_sens - L * cos(q_hat);
      dy := y_sens - L * sin(q_hat);
      dyaw := wrapAngle(yaw_sens - q_hat);
      innov_norm := sqrt(dx * dx + dy * dy + dyaw * dyaw);
      if innov_norm <= gate_abs then
        den := P_pred + R_abs;
        if den < 1.0e-12 then
          den := 1.0e-12;
        end if;
        K_abs := P_pred / den;
        q_hat := q_hat + K_abs * dyaw;
        qd_hat := qd_hat + K_abs * 0.01 * dyaw / Ts;
        P_abs := (1.0 - K_abs) * P_pred;
      else
        P_abs := P_pred;
      end if;
    else
      P_abs := P_pred;
    end if;

    // Synchronous estimator error after updates
    err_now := sqrt((x - L * cos(q_hat)) * (x - L * cos(q_hat)) + (y - L * sin(q_hat)) * (y - L * sin(q_hat)) + (yaw - q_hat) * (yaw - q_hat));

    // Acceptance records
    if n_tick == n_drop_start then
      P_pre_drop := P_pred;
    end if;
    if n_tick == n_drop_end then
      P_drop_end := P_pred;
    end if;
    if n_tick == n_recovery then
      P_post_recovery := P_abs;
    end if;

    if dropout then
      if err_now > pre(err_outage_max) then
        err_outage_max := err_now;
      else
        err_outage_max := pre(err_outage_max);
      end if;
    end if;

    if n_tick == n_104 then
      err_at_104 := err_now;
    end if;

    // Synchronized traces
    t_log := time;
    q_log := q;
    qd_log := qd;
    x_log := x;
    y_log := y;
    yaw_log := yaw;
    tau_log := tau_cmd;
    i_log := i_motor;
    q_ref_log := q_ref;
    q_enc_log := q;
    qd_enc_log := qd_enc;
    x_sens_log := x_sens;
    y_sens_log := y_sens;
    yaw_sens_log := yaw_sens;
    sensor_avail_log := sensor_avail;
    x_hat_log := x_hat;
    y_hat_log := y_hat;
    yaw_hat_log := yaw_hat;
    q_hat_log := q_hat;
    qd_hat_log := qd_hat;
    P_log := P_abs;
    err_log := err_now;
    err_track_log := err_track;

    // No NaN or infinite physical/control/estimator values
    assert(isFiniteValue(q), "TorqueObserverBridgeE: q not finite");
    assert(isFiniteValue(qd), "TorqueObserverBridgeE: qd not finite");
    assert(isFiniteValue(x), "TorqueObserverBridgeE: x not finite");
    assert(isFiniteValue(y), "TorqueObserverBridgeE: y not finite");
    assert(isFiniteValue(tau_cmd), "TorqueObserverBridgeE: tau_cmd not finite");
    assert(isFiniteValue(i_motor), "TorqueObserverBridgeE: i_motor not finite");
    assert(isFiniteValue(q_hat), "TorqueObserverBridgeE: q_hat not finite");
    assert(isFiniteValue(qd_hat), "TorqueObserverBridgeE: qd_hat not finite");
    assert(isFiniteValue(P_abs), "TorqueObserverBridgeE: P_abs not finite");
    assert(isFiniteValue(err_now), "TorqueObserverBridgeE: err_now not finite");
    assert(isFiniteValue(err_track), "TorqueObserverBridgeE: err_track not finite");

    // Fail-closed acceptance
    if n_tick == n_drop_end then
      assert(P_drop_end > P_pre_drop + 1.0e-6, "TorqueObserverBridgeE: covariance did not grow during dropout");
      assert(err_outage_max <= 0.315, "TorqueObserverBridgeE: outage error exceeded 0.315 m-or-rad");
    end if;

    if n_tick == n_104 then
      assert(err_at_104 <= 0.315, "TorqueObserverBridgeE: primary tracking error after 10.4 s exceeded 0.315 m-or-rad");
    end if;

    if n_tick == n_recovery then
      assert(P_post_recovery < P_drop_end, "TorqueObserverBridgeE: covariance did not recover after measurements returned");
      assert(err_now <= 0.315, "TorqueObserverBridgeE: tracking error after recovery exceeded 0.315 m-or-rad");
    end if;

    if time >= 10.4 then
      assert(err_now <= 0.315, "TorqueObserverBridgeE: primary tracking error after 10.4 s exceeded 0.315 m-or-rad");
    end if;
  end when;

  annotation(experiment(StopTime = 16.0, Interval = 0.004));
end TorqueObserverBridgeE;