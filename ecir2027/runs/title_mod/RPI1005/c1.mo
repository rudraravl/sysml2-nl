model AckermannRoverBrakeC
  "Floating-base rear-drive Ackermann rover with deterministic emergency-stop state machine"

  // Stated physical parameters
  parameter Real m_chassis(unit="kg") = 34.0 "Chassis mass";
  parameter Real L_length(unit="m") = 1.05 "Chassis length";
  parameter Real W_width(unit="m") = 0.64 "Chassis width";
  parameter Real L_wheelbase(unit="m") = 0.74 "Wheelbase";
  parameter Real steer_limit(unit="rad") = 0.52 "Front steering joint limit";
  parameter Real tau_max(unit="N.m") = 25.8 "Maximum command magnitude";
  parameter Real mu_floor = 0.70 "Floor friction coefficient";
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";
  parameter Real v_target(unit="m/s") = 1.2 "Target cruise speed";
  parameter Real d_safety(unit="m") = 1.4 "Emergency-stop safety range";
  parameter Real x_barrier(unit="m") = 7.0 "Fixed barrier position ahead";
  parameter Real F_disturb(unit="N") = 162.0 "Payload disturbance magnitude";

  // Assumed parameters (not stated in requirement; labeled, not fabricated from examples)
  parameter Real r_wheel(unit="m") = 0.13 "Wheel radius (assumed, not specified)";
  parameter Real Kp_speed = 200.0 "Speed PI proportional gain (assumed, tuned)";
  parameter Real Ki_speed = 100.0 "Speed PI integral gain (assumed, tuned)";
  parameter Real Ts_ctrl(unit="s") = 0.008 "Control period 125 Hz";
  parameter Real Ts_cam(unit="s") = 1.0 / 30.0 "Depth camera period 30 Hz";
  parameter Real F_fric(unit="N") = mu_floor * m_chassis * g "Friction-limited tire force";

  // Continuous plant states
  Real x(start=0.0, fixed=true, unit="m") "Longitudinal position of chassis";
  Real v(start=0.0, fixed=true, unit="m/s") "Longitudinal velocity";
  Real a_long(unit="m/s2") "Longitudinal acceleration";

  // Continuous signals
  Real tau_cmd(unit="N.m") "Rear traction command";
  Real tau_sat(unit="N.m") "Saturated rear traction torque";
  Real steer_cmd(unit="rad") "Front steering command";
  Real steer_sat(unit="rad") "Saturated steering command";
  Real F_tire(unit="N") "Tire-road longitudinal force";
  Real F_disturb_applied(unit="N") "Applied disturbance force";
  Real dist_to_barrier(unit="m") "Distance from chassis to barrier";
  Real v_ref(unit="m/s") "Reference speed";
  Real speed_error(unit="m/s") "Speed tracking error";
  Real imu_accel(unit="m/s2") "IMU measured acceleration";
  Real enc_speed(unit="m/s") "Encoder-derived wheel speed";
  Real depth_dist_cont(unit="m") "Depth camera continuous distance";

  // Discrete controller / estimator / sensor traces
  discrete Integer ctrl_state(start=0) "0=NORMAL, 1=EMERGENCY";
  discrete Real tau_cmd_d(start=0.0, unit="N.m") "Commanded torque at 125 Hz";
  discrete Real steer_cmd_d(start=0.0, unit="rad") "Commanded steering at 125 Hz";
  discrete Real integral_err(start=0.0) "Integral of speed error";
  discrete Real tau_candidate(start=0.0, unit="N.m") "Unclamped torque candidate for anti-windup";
  discrete Real depth_sample(start=7.0, unit="m") "Depth camera sampled distance at 30 Hz";
  discrete Real state_sampled(start=0.0) "Sampled controller state for synchronized trace";
  discrete Real v_at_stop(start=0.0, unit="m/s") "Residual speed captured at 7.8 s";

  // Safety / requirement checks
  Boolean collision "True if chassis reaches barrier";
  Boolean monotonic_braking "True if braking command is non-positive in emergency";
  Boolean speed_limit_ok "True if speed within operational limits";
  Boolean effort_limit_ok "True if effort within command limits";
  Real residual_speed_after_7p8(unit="m/s") "Residual speed after 7.8 s";
  Real margin_after_7p8(unit="m") "Stopping margin to barrier after 7.8 s";
  Real tracking_error_after_7p8(unit="m") "Primary tracking error after 7.8 s";

equation
  // Geometry: distance from chassis to fixed barrier
  dist_to_barrier = x_barrier - x;

  // Disturbance: resistive payload force opposing forward motion, middle third (4-8 s)
  F_disturb_applied = if (time >= 4.0 and time <= 8.0 and v > 0.001) then F_disturb else 0.0;

  // Tire force: torque through wheel radius, friction-limited
  // When stopped (v near zero), only allow forward force — no backward push from braking
  F_tire = if v > 0.001 then
             max(-F_fric, min(F_fric, tau_sat / r_wheel))
           else
             max(0.0, min(F_fric, tau_sat / r_wheel));

  // Longitudinal dynamics on rigid floor
  a_long = (F_tire - F_disturb_applied) / m_chassis;
  der(x) = v;
  der(v) = a_long;

  // Independent actuator saturation
  tau_sat = max(-tau_max, min(tau_max, tau_cmd));
  steer_sat = max(-steer_limit, min(steer_limit, steer_cmd));
  tau_cmd = tau_cmd_d;
  steer_cmd = steer_cmd_d;

  // Reference speed and tracking error
  v_ref = if ctrl_state == 1 then 0.0 else v_target;
  speed_error = v_ref - v;

  // Instrumentation: encoders, IMU, depth camera (continuous)
  enc_speed = v;
  imu_accel = a_long;
  depth_dist_cont = dist_to_barrier;

  // Requirement checks
  collision = x >= x_barrier;
  monotonic_braking = (ctrl_state == 0) or (tau_cmd <= 0.0);
  speed_limit_ok = abs(v) <= v_target + 0.5;
  effort_limit_ok = abs(tau_cmd) <= tau_max + 1e-9;
  residual_speed_after_7p8 = if time >= 7.8 then abs(v) else 0.0;
  margin_after_7p8 = if time >= 7.8 then (x_barrier - x) else 7.0;
  tracking_error_after_7p8 = if time >= 7.8 then abs(x - (x_barrier - d_safety)) else 0.0;

algorithm
  // 125 Hz deterministic control loop and emergency-stop state machine
  when sample(0, Ts_ctrl) then
    // Deterministic emergency-stop: NORMAL -> EMERGENCY when obstacle enters safety range
    if ctrl_state == 0 and (x_barrier - x) <= d_safety then
      ctrl_state := 1;
    end if;

    if ctrl_state == 0 then
      // PI speed control toward v_target with conditional anti-windup
      tau_candidate := Kp_speed * (v_target - v) + Ki_speed * integral_err;
      if tau_candidate < tau_max and tau_candidate > -tau_max then
        integral_err := integral_err + (v_target - v) * Ts_ctrl;
      end if;
      tau_cmd_d := Kp_speed * (v_target - v) + Ki_speed * integral_err;
    else
      // EMERGENCY: maximum monotonic brake command, reset integral
      integral_err := 0.0;
      tau_cmd_d := -tau_max;
    end if;

    // Steering held at zero (straight-line motion)
    steer_cmd_d := 0.0;
  end when;

  // 30 Hz depth camera sampling (synchronized trace)
  when sample(0, Ts_cam) then
    depth_sample := x_barrier - x;
    state_sampled := ctrl_state;
  end when;

  // Residual-speed evidence snapshot at 7.8 s
  when time >= 7.8 then
    v_at_stop := v;
  end when;

annotation(
  experiment(StopTime = 12, Tolerance = 1e-6, Interval = 0.008)
);

end AckermannRoverBrakeC;