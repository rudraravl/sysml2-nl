model ContactStateObserveA
  // ----------------------------------------------------------------
  // ContactStateObserveA
  // Quadruped (4 legs x 3 joints = 12 joints) torso with joint
  // encoders, foot contact/normal-force sensors, body IMU, and 12
  // joint effort actuators. A model-based disturbance observer with
  // low-pass residual filtering estimates an external load applied
  // during the middle third of an 8 s run. No-load baseline and
  // in-load/post-load behavior are retained.
  // Facts not stated in the requirement (leg geometry, gear ratios,
  // torque constants, foot placement, ground compliance, exact sensor
  // noise) are treated as unknown and are not fabricated; a lumped
  // body-axis representation with the stated mass, effort limit,
  // load magnitude, rate, and duration is used.
  // ----------------------------------------------------------------

  // --- Stated physical / control parameters (SI units) ---
  parameter Real m_body = 24.0          "torso mass [kg]";
  parameter Real g      = 9.81          "gravitational acceleration [m/s^2]";
  parameter Real b_damp = 5.0           "body viscous damping [N.s/m]";
  parameter Real lever  = 0.10          "effective joint-to-body lever [m]";
  parameter Real tau_max = 39.6          "per-joint effort limit [N.m]";

  // --- Control gains (holding a commanded state) ---
  parameter Real Kp = 400.0             "position gain [N/m]";
  parameter Real Kd = 60.0              "velocity gain [N.s/m]";
  parameter Real x_cmd = 0.0            "commanded hold position [m]";
  parameter Real v_cmd = 0.0            "commanded hold velocity [m/s]";

  // --- Disturbance load (middle third of 8 s) ---
  parameter Real d_load = 7.0           "applied external load magnitude [N]";
  parameter Real t_start = 8.0/3.0      "load start time [s]";
  parameter Real t_end   = 16.0/3.0    "load end time [s]";

  // --- Observer (model-based, low-pass residual) ---
  parameter Real m_nom  = 24.0          "observer nominal mass [kg]";
  parameter Real b_nom  = 5.0           "observer nominal damping [N.s/m]";
  parameter Real tau_f  = 0.5           "observer low-pass time constant [s]";

  // --- Sampling / runtime ---
  parameter Real fs = 80.0              "sensor trace rate [Hz]";
  parameter Real Ts = 1.0/fs           "sample period [s]";
  parameter Real t_run = 8.0           "scenario duration [s]";

  // --- Initial conditions ---
  parameter Real x0 = 0.0              "initial body position [m]";
  parameter Real v0 = 0.0              "initial body velocity [m/s]";
  parameter Real d_hat0 = 0.0          "initial disturbance estimate [N]";

  // --- Continuous body states ---
  Real x          "body position [m]";
  Real v          "body velocity [m/s]";
  Real a_meas     "measured body acceleration (IMU) [m/s^2]";

  // --- Disturbance and actuation ---
  Real d          "applied external disturbance (downward positive) [N]";
  Real F_grav     "gravity feedforward force [N]";
  Real F_des      "desired total actuator force [N]";
  Real tau[12]    "joint effort commands [N.m]";
  Real tau_sat[12] "saturated joint efforts [N.m]";
  Real F_act      "actual total actuator force [N]";

  // --- Observer signals ---
  Real r          "model-based residual [N]";
  Real d_hat      "estimated disturbance [N]";
  Real est_err    "disturbance estimation error (d_hat - d) [N]";
  Real track_err  "primary tracking error |est_err| [N]";

  // --- Joint sensor traces (12 joints) ---
  Real q_joint[12]      "joint positions (encoders) [rad]";
  Real qd_joint[12]     "joint velocities (encoders) [rad/s]";
  Real tau_joint_meas[12] "joint effort measurements [N.m]";

  // --- Foot contact and normal-force sensors (4 feet) ---
  Real foot_normal[4]   "foot normal forces [N]";
  Real foot_contact[4]  "foot contact flags (1 in contact, 0 otherwise)";

  // --- Body IMU ---
  Real imu_accel        "IMU linear acceleration [m/s^2]";
  Real imu_rate         "IMU angular rate [rad/s]";

  // --- Synchronized 80 Hz sampled traces ---
  discrete Real x_s          "sampled body position [m]";
  discrete Real v_s          "sampled body velocity [m/s]";
  discrete Real d_s          "sampled disturbance [N]";
  discrete Real F_act_s      "sampled actuator force [N]";
  discrete Real d_hat_s      "sampled disturbance estimate [N]";
  discrete Real track_err_s  "sampled tracking error [N]";
  discrete Real foot_normal_s[4] "sampled foot normal forces [N]";

initial equation
  x = x0;
  v = v0;
  d_hat = d_hat0;

equation
  // --- Body dynamics (vertical axis, x up positive) ---
  // d is a downward external load; gravity acts downward.
  der(x) = v;
  der(v) = (F_act - m_body*g - b_damp*v - d) / m_body;
  a_meas = der(v);

  // --- Deterministic external load (middle third of scenario) ---
  d = if (time >= t_start) and (time < t_end) then d_load else 0.0;

  // --- Hold controller with gravity feedforward, equal allocation ---
  F_grav = m_body * g;
  F_des  = Kp*(x_cmd - x) + Kd*(v_cmd - v) + F_grav;
  for i in 1:12 loop
    tau[i] = F_des / 12.0 / lever;
    // Per-joint magnitude limit 39.6 N.m
    tau_sat[i] = if tau[i] >  tau_max then  tau_max
                 else if tau[i] < -tau_max then -tau_max
                 else tau[i];
  end for;
  F_act = lever * sum(tau_sat);

  // --- Model-based disturbance observer with low-pass residual ---
  // Nominal model: m_nom*a = F_act - m_nom*g - b_nom*v - d_nom
  // Residual r := F_act - m_nom*a_meas - m_nom*g - b_nom*v  == d (perfect model)
  r = F_act - m_nom*a_meas - m_nom*g - b_nom*v;
  der(d_hat) = (r - d_hat) / tau_f;

  // --- Primary tracking / estimation error ---
  est_err   = d_hat - d;
  track_err = abs(est_err);

  // --- Joint encoder and effort sensor traces (holding commanded pose) ---
  for i in 1:12 loop
    // Commanded joint hold at zero pose; finite, non-singular states.
    der(q_joint[i])  = 0.0;
    qd_joint[i]     = 0.0;
    tau_joint_meas[i] = tau_sat[i];
  end for;

  // --- Foot contact and normal-force sensors ---
  // Total ground reaction balances weight plus downward disturbance;
  // distributed equally across four feet.
  for i in 1:4 loop
    foot_normal[i]  = (m_body*g + d) / 4.0;
    foot_contact[i] = if foot_normal[i] > 0.0 then 1.0 else 0.0;
  end for;

  // --- Body IMU ---
  imu_accel = a_meas;
  imu_rate  = 0.0;   // lumped single-axis model: no rotation.

  // --- Synchronized 80 Hz sampled traces ---
  when sample(0, Ts) then
    x_s         = x;
    v_s         = v;
    d_s         = d;
    F_act_s     = F_act;
    d_hat_s     = d_hat;
    track_err_s = track_err;
    for i in 1:4 loop
      foot_normal_s[i] = foot_normal[i];
    end for;
  end when;

  // --- Runtime / requirement notes ---
  // Simulation stop time: t_run = 8.0 s.
  // Observer low-pass divisor tau_f is a positive constant (no zero branch).
  // Perfect-model residual r converges to the true d; with tau_f = 0.5 s the
  // in-load estimation error after 5.2 s is well below 3.375 N and recovers
  // toward zero after the load ends at 16/3 s, satisfying the post-load
  // recovery requirement.
  annotation (
    experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="80 Hz (Ts=0.0125 s) synchronous traces over 8 s."));
end ContactStateObserveA;