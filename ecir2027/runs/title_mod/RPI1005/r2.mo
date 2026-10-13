model AckermannRoverBrakeC
  "Floating-base Ackermann rover: speed control with deterministic emergency-stop state machine"

  // ===== Physical parameters (from requirement) =====
  parameter Real m = 34.0 "chassis mass [kg]";
  parameter Real L_chassis = 1.05 "chassis length [m]";
  parameter Real W_chassis = 0.64 "chassis width [m]";
  parameter Real wheelbase = 0.74 "wheelbase [m]";
  parameter Real mu_floor = 0.70 "rigid floor friction coefficient [-]";
  parameter Real steerLimit = 0.52 "front steering joint limit [rad]";
  parameter Real barrierPos = 7.0 "fixed barrier position ahead [m]";

  // ===== Control specification parameters =====
  parameter Real vRef = 1.2 "target cruise speed [m/s]";
  parameter Real safetyRange = 1.4 "obstacle safety range [m]";
  parameter Real tauMax = 25.8 "maximum command magnitude [N.m]";
  parameter Real Fdist = 162.0 "controlled payload disturbance [N]";

  // ===== Constants and placeholder parameters (not specified in requirement) =====
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real wheelRadius = 0.10 "// wheel radius not specified in requirement; placeholder for torque-to-force conversion [m]";
  parameter Real Kp = 200.0 "// speed controller proportional gain not specified; placeholder [N per (m/s)]";

  // ===== Sampling periods =====
  parameter Real Ts_ctrl = 0.008 "control loop period = 1/125 Hz [s]";
  parameter Real Ts_cam = 1.0 / 30.0 "depth camera period = 1/30 Hz [s]";

  // ===== Continuous dynamic states =====
  Real x(start = 0.0) "longitudinal position [m]";
  Real v(start = 0.001) "longitudinal velocity [m/s]";

  // ===== Continuous algebraic variables =====
  Real a_imu "IMU longitudinal acceleration [m/s2]";
  Real v_enc "encoder-measured speed [m/s]";
  Real depthRaw "instantaneous distance to barrier [m]";
  Real F_drive "tractive/braking force at ground [N]";
  Real F_dist "payload disturbance force [N]";
  Real F_net "net longitudinal force [N]";
  Real stopMargin "distance from barrier [m]";
  Real trackError "speed tracking error vRef - v [m/s]";
  Real brakeDistance "distance traveled since brake trigger [m]";
  Real steerCmd "front steering command unsaturated [rad]";
  Real tauCmdSat "saturated traction torque command [N.m]";
  Real steerCmdSat "saturated steering command [rad]";

  // ===== Discrete variables =====
  discrete Real depthSampled(start = 7.0) "30 Hz depth camera distance [m]";
  discrete Real v_err_z(start = 0.0) "zero-order-hold speed error [m/s]";
  discrete Real tauCmd_z(start = 0.0) "zero-order-hold torque command [N.m]";
  discrete Integer brakeState(start = 0) "0 = speed tracking, 1 = emergency brake";
  discrete Real brakeEntryTime(start = 0.0) "time when braking started [s]";
  discrete Real brakeTriggerX(start = 0.0) "position at brake trigger [m]";

equation
  // --- Disturbance injection: middle third of 12 s simulation (4 s to 8 s) ---
  F_dist = if (time >= 4.0 and time <= 8.0) then Fdist else 0.0;

  // --- Sensor measurements (encoders, IMU, depth) ---
  v_enc = v;
  a_imu = der(v);
  depthRaw = barrierPos - x;

  // --- 30 Hz depth camera sampling ---
  when sample(0, Ts_cam) then
    depthSampled = depthRaw;
  end when;

  // --- 125 Hz discrete speed controller with zero-order hold ---
  when sample(0, Ts_ctrl) then
    v_err_z = vRef - v;
    if brakeState == 0 then
      // Proportional speed control producing torque command
      tauCmd_z = Kp * v_err_z * wheelRadius;
    else
      // Emergency braking: full reverse torque (monotonic)
      tauCmd_z = -tauMax;
    end if;
  end when;

  // --- Deterministic emergency-stop state machine ---
  // Trigger when depth camera reports obstacle within safety range
  when depthSampled <= safetyRange and brakeState == 0 then
    brakeState = 1;
    brakeEntryTime = time;
    brakeTriggerX = x;
  end when;

  // --- Independent actuator saturation ---
  // Rear traction actuator bounded by tauMax
  tauCmdSat = max(-tauMax, min(tauMax, tauCmd_z));
  // Front steering actuator bounded by steerLimit
  steerCmd = 0.0;
  steerCmdSat = max(-steerLimit, min(steerLimit, steerCmd));

  // --- Ground force from motor torque, friction-limited ---
  // wheelRadius is fixed nonzero (0.10) so division is well-defined
  F_drive = max(-mu_floor * m * g, min(mu_floor * m * g, tauCmdSat / wheelRadius));

  // --- Rigid-floor longitudinal dynamics ---
  F_net = F_drive - F_dist;
  m * der(v) = F_net;
  der(x) = v;

  // --- Performance and safety metrics ---
  stopMargin = barrierPos - x;
  trackError = vRef - v;
  brakeDistance = if brakeState == 1 then x - brakeTriggerX else 0.0;

  // --- Safety and validity assertions ---
  assert(stopMargin > 0.0, "Barrier collision: rover reached the barrier");
  assert(v >= -100.0 and v <= 100.0, "Velocity out of physical range (possible NaN/Inf)");
  assert(x >= -100.0 and x <= 100.0, "Position out of physical range (possible NaN/Inf)");
  assert(F_drive >= -1.0e4 and F_drive <= 1.0e4, "Drive force out of range (possible NaN/Inf)");
  assert(tauCmdSat >= -tauMax - 1.0e-6 and tauCmdSat <= tauMax + 1.0e-6, "Torque saturation violated");
  assert(steerCmdSat >= -steerLimit - 1.0e-6 and steerCmdSat <= steerLimit + 1.0e-6, "Steering saturation violated");
  // Monotonic braking: once in brake state, command stays at full reverse
  assert(brakeState == 0 or tauCmd_z == -tauMax, "Braking must be monotonic at full reverse torque");

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "AckermannRoverBrakeC: 34 kg rear-wheel-drive Ackermann rover on rigid floor (mu=0.70). "
      "Accelerates to 1.2 m/s with proportional speed control. Deterministic emergency-stop state machine "
      "triggered by 30 Hz depth camera when forward obstacle enters 1.4 m safety range. "
      "162 N payload disturbance injected during middle third (4-8 s). "
      "Max traction command 25.8 N.m, front steering limited to +/-0.52 rad. "
      "Barrier fixed 7 m ahead. Control loop at 125 Hz, simulation 12 s. "
      "Requirements: speed/effort limits, monotonic braking, no barrier collision, "
      "residual speed < 0.05 m/s, stopping margin (brakeDistance) < 0.231 m after 7.8 s, "
      "no NaN/Inf values. "
      "NOTE: wheelRadius and Kp are placeholder values not specified in the requirement.")
  );
end AckermannRoverBrakeC;