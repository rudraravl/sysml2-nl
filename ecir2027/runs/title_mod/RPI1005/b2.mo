model AckermannRoverBrakeC
  "Floating-base rear-drive Ackermann rover with deterministic emergency-stop state machine"

  // Stated physical parameters
  parameter Real m_chassis(unit="kg") = 34.0 "chassis mass";
  parameter Real L_length(unit="m") = 1.05 "chassis length";
  parameter Real W_width(unit="m") = 0.64 "chassis width";
  parameter Real L_wheelbase(unit="m") = 0.74 "wheelbase";
  parameter Real steer_limit(unit="rad") = 0.52 "front steering joint limit (+/-)";
  parameter Real tau_max(unit="N.m") = 25.8 "maximum command magnitude";
  parameter Real mu_floor = 0.70 "floor friction coefficient";
  parameter Real g(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real v_target(unit="m/s") = 1.2 "target cruise speed";
  parameter Real d_safety(unit="m") = 1.4 "emergency-stop safety range";
  parameter Real x_barrier(unit="m") = 7.0 "fixed barrier position ahead";
  parameter Real F_disturb(unit="N") = 162.0 "payload disturbance magnitude";

  // Assumed (not stated in requirement; labeled accordingly)
  parameter Real r_wheel(unit="m") = 0.13 "wheel radius (assumed; not specified)";
  parameter Real Kp_speed = 60.0 "speed PI proportional gain (tuned; assumed)";
  parameter Real Ki_speed = 100.0 "speed PI integral gain (tuned; assumed)";
  parameter Real Ts_ctrl(unit="s") = 0.008 "control period (125 Hz)";
  parameter Real Ts_cam(unit="s") = 1.0/30.0 "depth camera period (30 Hz)";

  // Continuous plant states
  Real x(start=0.0, fixed=true, unit="m") "longitudinal position of chassis base";
  Real v(start=0.0, fixed=true, unit="m/s") "longitudinal velocity";

  // Continuous signals
  Real a_long(unit="m/s2") "longitudinal acceleration";
  Real tau_sat(unit="N.m") "saturated rear traction torque";
  Real steer_sat(unit="rad") "saturated front steering command";
  Real F_tire(unit="N") "tire-road longitudinal force";
  Real F_disturb_applied(unit="N") "applied disturbance force";
  Real dist_to_barrier(unit="m") "distance from chassis to barrier";
  Real v_ref(unit="m/s") "reference speed";
  Real speed_error(unit="m/s") "speed tracking error";
  Real tracking_margin(unit="m") "stopping margin to barrier";
  Real imu_accel(unit="m/s2") "IMU measured acceleration";
  Real enc_speed(unit="m/s") "encoder-derived wheel speed";
  Real depth_dist_cont(unit="m") "depth camera raw distance (continuous)";

  // Discrete controller / estimator / sensor traces
  discrete Real mode(start=0.0) "0=NORMAL, 1=EMERGENCY";
  discrete Real tau_cmd(start=0.0, unit="N.m") "commanded rear traction torque";
  discrete Real steer_cmd(start=0.0, unit="rad") "commanded steering";
  discrete Real integral_err(start=0.0) "integral of speed error";
  discrete Real depth_sample(start=7.0, unit="m") "depth camera sampled distance";
  discrete Real mode_sampled(start=0.0) "sampled mode for synchronized trace";
  discrete Real v_at_stop(start=0.0, unit="m/s") "residual speed captured after 7.8 s";

  // One-time capture flag
  Boolean captured(start=false) "true after v_at_stop has been captured";

  // Safety / requirement checks
  Boolean collision "barrier collision flag";
  Boolean monotonic_braking "monotonic braking flag";
  Real residual_speed_after_7p8(unit="m/s") "residual speed after 7.8 s";
  Real margin_after_7p8(unit="m") "stopping margin after 7.8 s";

equation
  // Geometry / range
  dist_to_barrier = x_barrier - x;

  // Disturbance injected only during middle third of run (4 s to 8 s)
  F_disturb_applied = if (time >= 4.0 and time <= 8.0) then F_disturb else 0.0;

  // Tire force: torque through wheel radius, friction-limited
  F_tire = max(-mu_floor*m_chassis*g, min(mu_floor*m_chassis*g, tau_sat/r_wheel));

  // Longitudinal dynamics on rigid floor
  a_long = (F_tire - F_disturb_applied)/m_chassis;
  der(x) = v;
  der(v) = a_long;

  // Independent actuator saturation (rear traction and front steering bounded separately)
  tau_sat = max(-tau_max, min(tau_max, tau_cmd));
  steer_sat = max(-steer_limit, min(steer_limit, steer_cmd));

  // Reference and errors
  v_ref = if mode > 0.5 then 0.0 else v_target;
  speed_error = v_ref - v;
  tracking_margin = dist_to_barrier;

  // Instrumentation: encoders, IMU, depth camera (continuous raw)
  enc_speed = v;
  imu_accel = a_long;
  depth_dist_cont = dist_to_barrier;

  // Requirement checks
  collision = x >= x_barrier;
  residual_speed_after_7p8 = if (time >= 7.8) then v else 0.0;
  margin_after_7p8 = if (time >= 7.8) then (x_barrier - x) else 0.0;
  monotonic_braking = (mode < 0.5) or (tau_cmd <= 0.0);

algorithm
  // 125 Hz deterministic control + state machine
  when sample(0, Ts_ctrl) then
    // Deterministic emergency-stop state machine:
    // NORMAL -> EMERGENCY when obstacle enters 1.4 m safety range
    if mode < 0.5 and (x_barrier - x) <= d_safety then
      mode := 1.0;
    end if;

    if mode < 0.5 then
      // PI speed control toward v_target
      integral_err := integral_err + (v_target - v)*Ts_ctrl;
      // Anti-windup: keep integral contribution within +/- tau_max
      if integral_err > tau_max/Ki_speed then
        integral_err := tau_max/Ki_speed;
      elseif integral_err < -tau_max/Ki_speed then
        integral_err := -tau_max/Ki_speed;
      end if;
      tau_cmd := Kp_speed*(v_target - v) + Ki_speed*integral_err;
    else
      // EMERGENCY: maximum monotonic brake command
      integral_err := 0.0;
      tau_cmd := -tau_max;
    end if;

    // Steering command (zero for straight-line motion)
    steer_cmd := 0.0;

    // Capture residual speed once at or after 7.8 s
    if (not captured) and time >= 7.8 then
      v_at_stop := v;
      captured := true;
    end if;
  end when;

  // 30 Hz depth camera sampling (synchronized trace)
  when sample(0, Ts_cam) then
    depth_sample := x_barrier - x;
    mode_sampled := mode;
  end when;

  annotation(
    experiment(StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info =
      "AckermannRoverBrakeC: 34 kg rear-wheel-drive floating-base rover with front steering "
      "joints (+/-0.52 rad), 1.05 m x 0.64 m chassis, 0.74 m wheelbase on rigid floor (mu=0.70). "
      "Speed-controlled to 1.2 m/s with deterministic emergency-stop state machine triggering "
      "when a fixed barrier 7 m ahead enters a 1.4 m safety range. "
      "162 N payload disturbance injected during middle third (4-8 s). "
      "Max command magnitude 25.8 N.m, independently bounded rear traction and front steering. "
      "Instrumentation: encoders, IMU acceleration, 30 Hz depth camera. "
      "Control loop 125 Hz, 12 s run. Requirements: speed/effort limits, monotonic braking, "
      "no barrier collision, residual speed < 0.05 m/s, primary tracking margin after 7.8 s "
      "below 0.231 m, no NaN/infinite physical/control/estimator values. "
      "Wheel radius and controller gains are assumed (not stated in requirement) and labeled accordingly.")
  );
end AckermannRoverBrakeC;