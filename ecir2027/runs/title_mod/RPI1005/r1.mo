model AckermannRoverBrakeC
  "Floating-base Ackermann rover with speed control and deterministic emergency-stop state machine"

  // --- Chassis parameters ---
  parameter Real m = 34.0 "chassis mass [kg]";
  parameter Real L_chassis = 1.05 "chassis length [m]";
  parameter Real W_chassis = 0.64 "chassis width [m]";
  parameter Real wheelbase = 0.74 "wheelbase [m]";
  parameter Real mu = 0.70 "floor friction coefficient [-]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  // Wheel radius is not stated in the requirement; a nominal value is assumed
  // so the torque-to-force conversion is well defined and the model compiles.
  parameter Real r_wheel = 0.10 "wheel radius [m] — assumed nominal; not stated in requirement";

  // --- Control parameters ---
  parameter Real v_target = 1.2 "target cruise speed [m/s]";
  parameter Real tau_max = 25.8 "maximum command magnitude [N.m]";
  parameter Real steer_max = 0.52 "front steering joint limit [rad]";
  parameter Real safety_range = 1.4 "obstacle safety range [m]";
  parameter Real kp_speed = 500.0 "speed controller proportional gain [N/(m/s)]";
  parameter Real ki_speed = 300.0 "speed controller integral gain [N/(m/s)/s]";

  // --- Disturbance ---
  parameter Real F_dist = 162.0 "payload disturbance magnitude [N]";
  parameter Real t_dist_start = 4.0 "disturbance start time [s] (middle third)";
  parameter Real t_dist_end = 8.0 "disturbance end time [s] (middle third)";

  // --- Environment ---
  parameter Real x_barrier = 7.0 "fixed barrier position ahead [m]";

  // --- Sampling rates ---
  parameter Real Ts_cam = 1.0 / 30.0 "depth camera period [s] (30 Hz)";
  parameter Real Ts_ctrl = 0.008 "control update period [s] (125 Hz)";

  // --- Dynamic states ---
  Real x(start = 0.0, fixed = true) "chassis longitudinal position [m]";
  Real v(start = 0.0, fixed = true) "chassis longitudinal speed [m/s]";
  Real integ(start = 0.0, fixed = true) "speed controller integrator state [m]";

  // --- Commands (bounded actuators) ---
  Real tau_drive "rear traction command [N.m]";
  Real tau_brake "braking command [N.m]";
  Real steer_cmd "front steering command [rad]";

  // --- Forces ---
  Real F_drive "drive force at wheel contact [N]";
  Real F_brake "braking force at wheel contact [N]";
  Real F_ext "external disturbance force [N]";
  Real F_net "net longitudinal force [N]";
  Real F_brake_limit "friction-limited maximum braking force [N]";

  // --- Sensors ---
  Real v_encoder "encoder speed measurement [m/s]";
  Real a_imu "IMU longitudinal acceleration [m/s2]";
  Real d_depth(start = x_barrier) "depth camera sampled range [m]";
  Real d_depth_raw "instantaneous distance to barrier [m]";

  // --- State machine ---
  Integer mode(start = 0) "0=ACCEL, 1=BRAKE, 2=STOPPED";
  Boolean obstacle_in_range "obstacle within safety range flag";

  // --- Monitoring / evidence ---
  Real a "longitudinal acceleration [m/s2]";
  Real v_err "speed tracking error [m/s]";
  Real v_ref "reference speed [m/s]";
  Real stop_margin "stopping margin to barrier [m]";
  Real tracking_error "primary tracking error [m/s]";
  Real residual_speed "absolute chassis speed [m/s]";
  Boolean collision "barrier collision indicator";

equation
  // --- Distance to barrier (non-negative) ---
  d_depth_raw = max(x_barrier - x, 0.0);
  obstacle_in_range = d_depth_raw <= safety_range;

  // --- Disturbance: 162 N forward push during middle third of 12 s run ---
  F_ext = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // --- Friction-limited braking force ---
  F_brake_limit = mu * m * g;

  // --- Torque-to-force conversion ---
  F_drive = tau_drive / r_wheel;
  F_brake = tau_brake / r_wheel;
  F_net = F_drive - F_brake + F_ext;
  a = F_net / m;

  // --- Vehicle longitudinal dynamics ---
  der(x) = v;
  der(v) = a;

  // --- Speed controller integrator (active only in ACCEL mode) ---
  v_err = v_target - v;
  der(integ) = if mode == 0 then v_err else 0.0;

  // --- Reference and tracking error ---
  v_ref = if mode == 0 then v_target else 0.0;
  tracking_error = abs(v - v_ref);

  // --- Sensor readings ---
  v_encoder = v;
  a_imu = a;

  // --- Depth camera at 30 Hz (synchronized sensor trace) ---
  when sample(0, Ts_cam) then
    d_depth = d_depth_raw;
  end when;

  // --- Deterministic emergency-stop state machine ---
  when initial() then
    mode = 0;
  end when;

  // ACCEL -> BRAKE when obstacle enters safety range
  when obstacle_in_range and pre(mode) == 0 then
    mode = 1;
  end when;

  // BRAKE -> STOPPED when speed is near zero
  when abs(v) < 0.01 and pre(mode) == 1 then
    mode = 2;
  end when;

  // --- Control law (effort-limited, monotonic braking) ---
  if mode == 0 then
    // ACCEL: bounded PI speed control toward v_target
    tau_drive = max(-tau_max, min(tau_max, (kp_speed * v_err + ki_speed * integ) * r_wheel));
    tau_brake = 0.0;
    steer_cmd = 0.0;
  elseif mode == 1 then
    // BRAKE: maximum friction-limited braking, monotonically held
    tau_drive = 0.0;
    tau_brake = min(tau_max, F_brake_limit * r_wheel);
    steer_cmd = 0.0;
  else
    // STOPPED: hold position against any active disturbance
    tau_drive = 0.0;
    tau_brake = min(tau_max, max(0.0, F_ext * r_wheel));
    steer_cmd = 0.0;
  end if;

  // --- Monitoring quantities ---
  stop_margin = d_depth_raw;
  residual_speed = abs(v);
  collision = x >= x_barrier;

  // --- Requirement verification assertions ---
  assert(not collision, "Barrier collision detected");
  assert(time < 7.8 or residual_speed < 0.05,
    "Residual speed exceeds 0.05 m/s after 7.8 s");
  assert(abs(steer_cmd) <= steer_max + 1e-6,
    "Steering command exceeds joint limit");
  assert(abs(tau_drive) <= tau_max + 1e-6,
    "Drive torque exceeds maximum command magnitude");
  assert(tau_brake <= tau_max + 1e-6,
    "Brake torque exceeds maximum command magnitude");

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "AckermannRoverBrakeC: 34 kg rear-wheel-drive Ackermann rover on rigid floor (mu=0.70). "
      "Accelerates to 1.2 m/s, performs emergency braking when a fixed barrier 7 m ahead enters the 1.4 m safety range. "
      "162 N forward disturbance injected during middle third (4-8 s). "
      "Control update rate 125 Hz; depth camera 30 Hz; 12 s run. "
      "Rear traction and front steering independently bounded at 25.8 N.m and +/-0.52 rad. "
      "Wheel radius assumed 0.10 m (not stated in requirement) for torque-force conversion.")
  );
end AckermannRoverBrakeC;