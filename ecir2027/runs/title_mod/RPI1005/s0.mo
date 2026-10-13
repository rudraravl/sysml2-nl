model AckermannRoverBrakeC
  "Floating-base rear-drive Ackermann rover with deterministic emergency-stop state machine"

  // --- Stated physical parameters ---
  parameter Real m_chassis  = 34.0  "kg chassis mass";
  parameter Real L_length   = 1.05  "m chassis length";
  parameter Real W_width    = 0.64  "m chassis width";
  parameter Real L_wheelbase= 0.74  "m wheelbase";
  parameter Real steer_limit = 0.52 "rad front steering joint limit (±)";
  parameter Real tau_max    = 25.8  "N.m maximum command magnitude";
  parameter Real mu_floor   = 0.70  "floor friction coefficient";
  parameter Real g          = 9.81  "m/s2 gravitational acceleration";
  parameter Real v_target   = 1.2   "m/s target cruise speed";
  parameter Real d_safety   = 1.4   "m emergency-stop safety range";
  parameter Real x_barrier  = 7.0   "m fixed barrier position ahead";
  parameter Real F_disturb  = 162.0 "N payload disturbance magnitude";

  // --- Assumed (not stated in requirement; labeled, not fabricated from examples) ---
  parameter Real r_wheel    = 0.13  "m wheel radius (assumed; not specified)";
  parameter Real Kp_speed   = 60.0  "speed PI proportional gain (tuned)";
  parameter Real Ki_speed   = 100.0 "speed PI integral gain (tuned)";
  parameter Real Ts_ctrl    = 0.008 "s control period (125 Hz)";
  parameter Real Ts_cam     = 1.0/30.0 "s depth camera period (30 Hz)";

  // --- Continuous plant states ---
  Real x(start=0.0, fixed=true) "m longitudinal position of chassis base";
  Real v(start=0.0, fixed=true) "m/s longitudinal velocity";
  Real a_long                   "m/s2 longitudinal acceleration";

  // --- Continuous signals ---
  Real tau_cmd            "N.m rear traction command";
  Real tau_sat            "N.m saturated rear traction torque";
  Real steer_cmd          "rad front steering command";
  Real F_tire             "N tire-road longitudinal force";
  Real F_disturb_applied  "N disturbance force applied to chassis";
  Real dist_to_barrier    "m distance from chassis nose to barrier";
  Real v_ref              "m/s reference speed";
  Real speed_error        "m/s speed tracking error";
  Real tracking_margin    "m stopping margin to barrier";
  Real imu_accel          "m/s2 IMU measured acceleration";
  Real enc_speed          "m/s encoder-derived wheel speed";
  Real depth_dist_cont    "m depth camera raw distance (continuous)";

  // --- Discrete controller / estimator / sensor traces ---
  discrete Integer state(start=0)        "0=NORMAL, 1=EMERGENCY";
  discrete Real tau_cmd_d(start=0.0)     "N.m commanded torque (125 Hz)";
  discrete Real steer_cmd_d(start=0.0)   "rad commanded steering (125 Hz)";
  discrete Real integral_err(start=0.0)  "integral of speed error";
  discrete Real depth_sample(start=7.0)  "m depth camera sampled distance (30 Hz)";
  discrete Real state_sampled(start=0)   "sampled state for synchronized trace";
  discrete Real v_at_stop(start=0.0)     "m/s residual speed captured after 7.8 s";

  // --- Safety / requirement checks ---
  Boolean collision;
  Boolean monotonic_braking;
  Real residual_speed_after_7p8 "m/s";
  Real margin_after_7p8         "m";

equation
  // Geometry / range
  dist_to_barrier = x_barrier - x;

  // Disturbance injected only during middle third of run (4 s to 8 s)
  F_disturb_applied = if (time >= 4.0 and time <= 8.0) then F_disturb else 0.0;

  // Tire force: torque through wheel radius, friction-limited (independent actuator bound)
  F_tire = max(-mu_floor*m_chassis*g, min(mu_floor*m_chassis*g, tau_sat/r_wheel));

  // Longitudinal dynamics on rigid floor
  a_long = (F_tire - F_disturb_applied)/m_chassis;
  der(x) = v;
  der(v) = a_long;

  // Independent actuator saturation
  tau_sat    = max(-tau_max, min(tau_max, tau_cmd));
  steer_cmd  = max(-steer_limit, min(steer_limit, steer_cmd_d));
  tau_cmd    = tau_cmd_d;

  // Reference and errors
  v_ref       = if state == 1 then 0.0 else v_target;
  speed_error = v_ref - v;
  tracking_margin = dist_to_barrier;

  // Instrumentation
  enc_speed         = v;
  imu_accel         = a_long;
  depth_dist_cont   = dist_to_barrier;

  // Requirement checks
  collision                  = x >= x_barrier;
  residual_speed_after_7p8   = if (time >= 7.8) then v else 0.0;
  margin_after_7p8           = if (time >= 7.8) then (x_barrier - x) else 0.0;
  monotonic_braking          = (state == 0) or (tau_cmd <= 0.0);

algorithm
  // 125 Hz deterministic control + state machine
  when sample(0, Ts_ctrl) then
    // Deterministic emergency-stop state machine:
    // NORMAL -> EMERGENCY when obstacle enters 1.4 m safety range.
    if state == 0 and (x_barrier - x) <= d_safety then
      state := 1;
    end if;
    // No spontaneous reverse transitions (monotonic braking enforced).

    if state == 0 then
      // PI speed control toward v_target
      integral_err := integral_err + (v_target - v)*Ts_ctrl;
      // Anti-windup: keep integral contribution within ±tau_max
      if integral_err > tau_max/Ki_speed then
        integral_err := tau_max/Ki_speed;
      elseif integral_err < -tau_max/Ki_speed then
        integral_err := -tau_max/Ki_speed;
      end if;
      tau_cmd_d := Kp_speed*(v_target - v) + Ki_speed*integral_err;
    else
      // EMERGENCY: maximum monotonic brake command
      integral_err := 0.0;
      tau_cmd_d    := -tau_max;
    end if;
    steer_cmd_d := 0.0;
  end when;

  // 30 Hz depth camera sampling (synchronized trace)
  when sample(0, Ts_cam) then
    depth_sample := x_barrier - x;
    state_sampled := state;
  end when;

  // Residual-speed evidence snapshot after 7.8 s
  when time >= 7.8 then
    v_at_stop := v;
  end when;

annotation(
  experiment(StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
  Documentation(info =
    "AckermannRoverBrakeC: 34 kg rear-wheel-drive floating-base rover with front steering joints (±0.52 rad), "
    "1.05 m x 0.64 m chassis, 0.74 m wheelbase on rigid floor (mu=0.70). "
    "Speed-controlled to 1.2 m/s with deterministic emergency-stop state machine triggering "
    "when a fixed barrier 7 m ahead enters a 1.4 m safety range. "
    "162 N payload disturbance injected during middle third (4-8 s). "
    "Max command magnitude 25.8 N.m, independently bounded rear traction and front steering. "
    "Instrumentation: encoders, IMU acceleration, 30 Hz depth camera. "
    "Control loop 125 Hz, 12 s run. Requirements: speed/effort limits, monotonic braking, "
    "no barrier collision, residual speed < 0.05 m/s, primary tracking margin after 7.8 s < 0.231 m, "
    "no NaN/infinite physical/control/estimator values. "
    "Wheel radius and controller gains are assumed (not stated in requirement) and labeled accordingly.")
);
end AckermannRoverBrakeC;