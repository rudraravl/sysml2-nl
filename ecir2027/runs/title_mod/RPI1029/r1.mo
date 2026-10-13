model OmniCartBrakeC
  "Floating-base mobile robot with deterministic emergency-stop state machine"

  // ===== Physical parameters =====
  parameter Real m_platform = 25.0 "Platform mass [kg]";
  parameter Real r_wheel = 0.095 "Wheel radius [m]";
  parameter Real roller_angle_deg = 45.0 "Mecanum roller angle [deg]";
  parameter Real footprint_x = 0.58 "Footprint length [m]";
  parameter Real footprint_y = 0.46 "Footprint width [m]";
  parameter Real mu_floor = 0.70 "Floor friction coefficient [-]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Mission parameters =====
  parameter Real v_target = 1.2 "Target forward speed [m/s]";
  parameter Real safety_range = 1.4 "Obstacle safety range [m]";
  parameter Real barrier_dist = 7.0 "Barrier distance from origin [m]";
  parameter Real tau_max = 11.0 "Maximum command magnitude per wheel [N.m]";
  parameter Real F_dist_magnitude = 162.0 "Payload disturbance force [N]";

  // ===== Timing =====
  parameter Real dt_control = 0.008 "Control period [s] (1/125 Hz)";
  parameter Real dt_camera = 1.0 / 30.0 "Camera sample period [s]";
  parameter Real t_end = 12.0 "Simulation duration [s]";

  // ===== Controller gain =====
  parameter Real Kp_speed = 20.0 "Speed proportional gain";

  // ===== Continuous plant states =====
  Real x(start = 0.0, fixed = true) "Forward position [m]";
  Real v(start = 0.0, fixed = true) "Forward speed [m/s]";
  Real a_body "Body acceleration [m/s2]";

  // ===== Forces =====
  Real F_traction "Friction-limited forward traction force [N]";
  Real F_traction_raw "Unclamped forward traction force [N]";
  Real F_friction_limit "Coulomb friction force limit [N]";
  Real F_disturbance "Payload disturbance force [N]";

  // ===== Discrete controller variables (125 Hz) =====
  discrete Integer state(start = 0) "0=ACCEL, 1=BRAKE, 2=STOP";
  discrete Real tau_cmd "Per-wheel torque command [N.m]";
  discrete Real v_meas "Encoder-measured speed [m/s]";
  discrete Real obstacle_dist_meas "Measured obstacle distance [m]";

  // ===== Sensor outputs =====
  Real a_imu "IMU acceleration measurement [m/s2]";
  Real depth_range_continuous "Depth camera range continuous [m]";
  discrete Real depth_range_sampled(start = 7.0) "Depth camera sampled range [m]";
  discrete Integer camera_frame_count(start = 0) "Camera frame counter";

  // ===== Monitoring and metrics =====
  Real tracking_error "Speed tracking error [m/s]";
  Real stop_margin "Current stopping margin to barrier [m]";
  Boolean barrier_collision "True if barrier collision";
  discrete Real residual_speed_7_8(start = 0.0) "Residual speed at 7.8 s [m/s]";
  discrete Real stop_margin_7_8(start = 7.0) "Stopping margin at 7.8 s [m]";
  discrete Real speed_at_brake_onset(start = 0.0) "Speed when braking started [m/s]";
  discrete Real pos_at_brake_onset(start = 0.0) "Position when braking started [m]";
  Boolean nan_inf_free "True if all values finite and valid";

equation
  // Coulomb friction limit: mu * m * g
  F_friction_limit = mu_floor * m_platform * g;

  // Payload disturbance: backward drag during middle third of simulation (4 s to 8 s)
  F_disturbance = if (time >= 4.0 and time <= 8.0) then -F_dist_magnitude else 0.0;

  // Forward traction from four identical mecanum wheel torque commands
  // For pure forward motion, forward force = sum(tau_i) / r_wheel
  // Roller angle 45 deg affects lateral/rotational coupling, not forward component
  F_traction_raw = 4.0 * tau_cmd / r_wheel;

  // Friction-limited traction with well-defined zero-error branch
  F_traction = if F_traction_raw > F_friction_limit then F_friction_limit
    elseif F_traction_raw < -F_friction_limit then -F_friction_limit
    else F_traction_raw;

  // Newton's second law
  a_body = (F_traction + F_disturbance) / m_platform;
  der(x) = v;
  der(v) = a_body;

  // IMU acceleration sensor (ideal)
  a_imu = a_body;

  // Depth camera range (continuous value for monitoring)
  depth_range_continuous = barrier_dist - x;

  // Speed tracking error and stopping margin
  tracking_error = v_target - v;
  stop_margin = barrier_dist - x;
  barrier_collision = x >= barrier_dist;

  // NaN/Inf safety check (all physical variables must remain finite)
  nan_inf_free = (x > -1e9 and x < 1e9) and
                 (v > -1e9 and v < 1e9) and
                 (a_body > -1e9 and a_body < 1e9) and
                 (tau_cmd > -1e9 and tau_cmd < 1e9) and
                 (F_traction > -1e9 and F_traction < 1e9);

  // ===== 125 Hz digital controller with state machine =====
  when sample(0, dt_control) then
    // Sample sensors (encoders and depth-derived range)
    v_meas = v;
    obstacle_dist_meas = barrier_dist - x;

    // Deterministic state machine transitions
    // ACCEL(0) -> BRAKE(1): obstacle enters 1.4 m safety range
    // BRAKE(1) -> STOP(2): speed drops below 0.05 m/s
    if pre(state) == 0 and (barrier_dist - x) <= safety_range then
      state = 1;
    elseif pre(state) == 1 and v <= 0.05 then
      state = 2;
    else
      state = pre(state);
    end if;

    // Capture brake onset telemetry
    if pre(state) == 0 and state == 1 then
      speed_at_brake_onset = v;
      pos_at_brake_onset = x;
    else
      speed_at_brake_onset = pre(speed_at_brake_onset);
      pos_at_brake_onset = pre(pos_at_brake_onset);
    end if;

    // Controller output with effort limit (11 N.m per wheel)
    if state == 0 then
      // Proportional speed control toward v_target
      tau_cmd = max(-tau_max, min(tau_max, Kp_speed * (v_target - v)));
    elseif state == 1 then
      // Emergency braking: maximum braking torque (monotonic)
      tau_cmd = -tau_max;
    else
      // Stop: zero torque command
      tau_cmd = 0.0;
    end if;
  end when;

  // ===== 30 Hz depth camera =====
  when sample(0, dt_camera) then
    camera_frame_count = pre(camera_frame_count) + 1;
    depth_range_sampled = barrier_dist - x;
  end when;

  // ===== Performance metrics captured at 7.8 s =====
  when time >= 7.8 then
    residual_speed_7_8 = v;
    stop_margin_7_8 = barrier_dist - x;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "<html>
<p>OmniCartBrakeC: Floating-base mobile robot with speed control and deterministic emergency-stop state machine.</p>
<p>Plant: 25 kg box platform, four 0.095 m-radius mecanum wheels at 45 deg roller angle, 0.58 x 0.46 m footprint, rigid floor with friction 0.70.</p>
<p>Mission: accelerate to 1.2 m/s, emergency brake when forward obstacle (barrier at 7 m) enters 1.4 m safety range.</p>
<p>Controller: 125 Hz proportional speed control, 11 N.m per-wheel torque limit, 162 N backward payload disturbance during middle third (4-8 s).</p>
<p>Sensors: encoders (speed), IMU (acceleration), 30 Hz depth camera (range).</p>
<p>Requirements: residual speed < 0.05 m/s, stopping margin > 0.231 m at 7.8 s, no barrier collision, monotonic braking, no NaN/Inf.</p>
</html>")
  );

end OmniCartBrakeC;