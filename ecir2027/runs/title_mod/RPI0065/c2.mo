model TiltWingDeliverE
  "Free-base tilt-wing aerial robot delivering a suspended payload into a 0.8 m target zone";

  // ===== Physical constants =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Plant structure (stated facts) =====
  parameter Real m = 6.2 "Fuselage mass [kg]";
  parameter Real rotorArm = 0.62 "Rotor distance from center [m] (structural)";
  parameter Real wingSpan = 1.8 "Wing span [m] (structural)";
  parameter Real gamma_min = 0.0 "Min rotor tilt [rad]";
  parameter Real gamma_max = 1.57 "Max rotor tilt [rad]";
  parameter Real thrust_max = 57.2 "Per-rotor thrust magnitude bound [N]";

  // ===== Payload / cable (NOT specified; assumed, labeled) =====
  parameter Real m_p = 2.0 "Payload mass [kg] (assumed)";
  parameter Real L = 1.0 "Cable length [m] (assumed)";

  // ===== Aerodynamics (NOT specified; assumed) =====
  parameter Real cd_drone = 2.0 "Drone quadratic drag coeff [kg/m] (assumed)";
  parameter Real cd_payload = 0.5 "Payload tangential drag coeff [kg/m] (assumed)";

  // ===== Gust: controlled 9.6 N, middle third =====
  parameter Real gustForce = 9.6 "Gust magnitude [N]";
  parameter Real t_gust_a = 16.0 / 3.0 "Gust window start [s]";
  parameter Real t_gust_b = 32.0 / 3.0 "Gust window end [s]";

  // ===== Controller gains (assumed) =====
  parameter Real Kp_x = 4.0 "Horizontal position gain";
  parameter Real Kd_x = 8.0 "Horizontal velocity gain";
  parameter Real Kp_z = 10.0 "Vertical position gain";
  parameter Real Kd_z = 6.0 "Vertical velocity gain";
  parameter Real k_swing = 1.5 "Cable-swing damping gain [N*s/rad]";

  // ===== Actuators (assumed first-order dynamics) =====
  parameter Real tau_thrust = 0.02 "Thrust actuator time constant [s]";
  parameter Real tau_tilt = 0.10 "Tilt actuator time constant [s]";

  // ===== Control rate =====
  parameter Real Ts = 1.0 / 250.0 "Control sample period [s]";

  // ===== Mission =====
  parameter Real x_target = 5.0 "Horizontal translation target [m]";
  parameter Real z_start = 2.0 "Initial altitude [m] (assumed)";
  parameter Real z_cruise = 3.0 "Cruise altitude [m] (assumed)";
  parameter Real z_lower = 1.1 "Lowering altitude [m] (assumed)";
  parameter Real zoneRadius = 0.8 "Target-zone radius [m]";
  parameter Real t_settle = 10.4 "Tracking-error threshold time [s]";
  parameter Real track_tol = 0.27 "Primary tracking tolerance [m]";
  parameter Real swing_max = 0.45 "Max cable swing [rad]";
  parameter Real tension_max = 60.0 "Cable tension upper bound [N] (assumed)";

  // ===== Continuous states =====
  Real x(start = 0.0, fixed = true) "Drone x position [m]";
  Real z(start = z_start, fixed = true) "Drone z position [m]";
  Real vx(start = 0.0, fixed = true) "Drone x velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "Drone z velocity [m/s]";
  Real theta(start = 0.0, fixed = true) "Cable angle from vertical [rad]";
  Real omega(start = 0.0, fixed = true) "Cable angular rate [rad/s]";
  Real T1(start = m * g / 2.0) "Rotor 1 thrust [N]";
  Real T2(start = m * g / 2.0) "Rotor 2 thrust [N]";
  Real gamma1(start = 0.0) "Rotor 1 tilt [rad]";
  Real gamma2(start = 0.0) "Rotor 2 tilt [rad]";

  // ===== Discrete commands =====
  discrete Real T1_cmd(start = m * g / 2.0) "Rotor 1 thrust command [N]";
  discrete Real T2_cmd(start = m * g / 2.0) "Rotor 2 thrust command [N]";
  discrete Real gamma1_cmd(start = 0.0) "Rotor 1 tilt command [rad]";
  discrete Real gamma2_cmd(start = 0.0) "Rotor 2 tilt command [rad]";

  // ===== References =====
  Real x_ref "Shaped x reference [m]";
  Real z_ref "Shaped z reference [m]";
  Real vx_ref "Shaped vx reference [m/s]";
  Real vz_ref "Shaped vz reference [m/s]";

  // ===== Forces and sensors =====
  Real F_gust "Applied gust force in x [N]";
  Real Fx_thrust "Total x thrust force [N]";
  Real Fz_thrust "Total z thrust force [N]";
  Real drag_x "Drone x drag [N]";
  Real drag_z "Drone z drag [N]";
  Real T_cable "Cable tension [N]";
  Real ax "Drone x acceleration [m/s2]";
  Real az "Drone z acceleration [m/s2]";
  Real xp "Payload x position [m]";
  Real zp "Payload z position [m]";
  Real gps_x "GPS x [m]";
  Real gps_z "GPS z [m]";
  Real imu_ax "IMU x acceleration [m/s2]";
  Real imu_az "IMU z acceleration [m/s2]";
  Real sensor_theta "Cable angle sensor [rad]";
  Real sensor_tension "Tension sensor [N]";

  // ===== Acceptance flags =====
  Boolean ok_thrust;
  Boolean ok_tension;
  Boolean ok_swing;
  Boolean ok_ground;
  Boolean ok_track;
  Boolean ok_target;
  Boolean ok_finite;
  Real track_err;
  Real place_err;

  // ===== Protected intermediates =====
protected
  Real st;
  Real ct;
  Real od2;
  Real Acoef;
  Real Bcoef;
  Real Dcoef;
  Real det;
  Real rhs_x;
  Real rhs_z;
  Real v_tan;
  Real drag_tan;
  Real alpha;
  Real T_total_cmd_local;
  Real gamma_cmd_local;

equation
  // ===== Input-shaped reference profiles =====
  x_ref = x_target * smoothstepFn(time, 2.0, 9.0);
  z_ref = z_start + (z_cruise - z_start) * smoothstepFn(time, 0.0, 2.0) - (z_cruise - z_lower) * smoothstepFn(time, 10.0, 14.0);
  vx_ref = x_target * dsmoothstepFn(time, 2.0, 9.0);
  vz_ref = (z_cruise - z_start) * dsmoothstepFn(time, 0.0, 2.0) - (z_cruise - z_lower) * dsmoothstepFn(time, 10.0, 14.0);

  // ===== Gust: 9.6 N headwind over middle third =====
  F_gust = -gustForce * smoothstepFn(time, t_gust_a, t_gust_a + 0.5) * (1.0 - smoothstepFn(time, t_gust_b - 0.5, t_gust_b));

  // ===== Rotor forces =====
  Fx_thrust = T1 * sin(gamma1) + T2 * sin(gamma2);
  Fz_thrust = T1 * cos(gamma1) + T2 * cos(gamma2);

  // ===== Aerodynamic drag (quadratic) =====
  drag_x = cd_drone * vx * abs(vx);
  drag_z = cd_drone * vz * abs(vz);

  // ===== Payload tangential drag =====
  v_tan = vx * cos(theta) + vz * sin(theta) + L * omega;
  drag_tan = cd_payload * v_tan * abs(v_tan);

  // ===== Coupled drone-payload solve =====
  st = sin(theta);
  ct = cos(theta);
  od2 = omega * omega;
  Acoef = m - m_p * st * st;
  Bcoef = m_p * st * ct;
  Dcoef = m + m_p * ct * ct;
  det = Acoef * Dcoef + Bcoef * Bcoef;
  rhs_x = (Fx_thrust - drag_x + F_gust) - m_p * g * st * ct - m_p * L * st * od2;
  rhs_z = (Fz_thrust - drag_z) - m * g - m_p * g * ct * ct - m_p * L * ct * od2;
  ax = (Dcoef * rhs_x - Bcoef * rhs_z) / det;
  az = (Bcoef * rhs_x + Acoef * rhs_z) / det;

  // ===== Pendulum angular acceleration =====
  alpha = (-ax * ct - az * st - g * st + drag_tan / m_p) / L;

  // ===== Cable tension =====
  T_cable = m_p * (g * ct - ax * st + az * ct + L * od2);

  // ===== State derivatives =====
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax;
  der(vz) = az;
  der(theta) = omega;
  der(omega) = alpha;
  der(T1) = (T1_cmd - T1) / tau_thrust;
  der(T2) = (T2_cmd - T2) / tau_thrust;
  der(gamma1) = (gamma1_cmd - gamma1) / tau_tilt;
  der(gamma2) = (gamma2_cmd - gamma2) / tau_tilt;

  // ===== Payload kinematics =====
  xp = x + L * sin(theta);
  zp = z - L * cos(theta);

  // ===== Sensors =====
  gps_x = x;
  gps_z = z;
  imu_ax = ax;
  imu_az = az;
  sensor_theta = theta;
  sensor_tension = T_cable;

  // ===== Sampled controller at 250 Hz =====
  when sample(0, Ts) then
    T_total_cmd_local = ctrlThrust(
      x, z, vx, vz, theta, omega,
      x_ref, z_ref, vx_ref, vz_ref,
      Kp_x, Kd_x, Kp_z, Kd_z, k_swing,
      m + m_p, g, gamma_max, thrust_max);
    gamma_cmd_local = ctrlTilt(
      x, z, vx, vz, theta, omega,
      x_ref, z_ref, vx_ref, vz_ref,
      Kp_x, Kd_x, Kp_z, Kd_z, k_swing,
      m + m_p, g, gamma_max);
    T1_cmd = T_total_cmd_local / 2.0;
    T2_cmd = T_total_cmd_local / 2.0;
    gamma1_cmd = gamma_cmd_local;
    gamma2_cmd = gamma_cmd_local;
  end when;

  // ===== Acceptance metrics =====
  track_err = sqrt((x - x_ref) * (x - x_ref) + (z - z_ref) * (z - z_ref));
  place_err = sqrt((xp - x_target) * (xp - x_target) + zp * zp);

  ok_thrust = (T1 >= -1.0e-6) and (T1 <= thrust_max + 1.0e-6) and
              (T2 >= -1.0e-6) and (T2 <= thrust_max + 1.0e-6);
  ok_tension = (T_cable >= -1.0e-3) and (T_cable <= tension_max + 1.0e-3);
  ok_swing = abs(theta) <= swing_max + 1.0e-6;
  ok_ground = (z >= 0.2) and (zp >= -1.0e-3);
  ok_track = (time < t_settle) or (track_err <= track_tol + 1.0e-6);
  ok_target = (time < 14.0) or (place_err <= zoneRadius + 1.0e-6);
  ok_finite = isFinFn(x) and isFinFn(z) and isFinFn(vx) and isFinFn(vz) and
              isFinFn(theta) and isFinFn(omega) and isFinFn(T1) and isFinFn(T2) and
              isFinFn(gamma1) and isFinFn(gamma2) and isFinFn(T_cable) and
              isFinFn(ax) and isFinFn(az) and isFinFn(T1_cmd) and isFinFn(T2_cmd) and
              isFinFn(gamma1_cmd) and isFinFn(gamma2_cmd);

  // ===== Fail-closed acceptance =====
  assert(ok_thrust, "Acceptance FAILED: thrust bound violated", AssertionLevel.error);
  assert(ok_tension, "Acceptance FAILED: tension bound violated", AssertionLevel.error);
  assert(ok_swing, "Acceptance FAILED: cable swing exceeded 0.45 rad", AssertionLevel.error);
  assert(ok_ground, "Acceptance FAILED: ground strike", AssertionLevel.error);
  assert(ok_track, "Acceptance FAILED: primary tracking error after 10.4 s", AssertionLevel.error);
  assert(ok_target, "Acceptance FAILED: target-zone placement", AssertionLevel.error);
  assert(ok_finite, "Acceptance FAILED: NaN or infinite value detected", AssertionLevel.error);

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info = "Tilt-wing delivery drone with suspended payload. Plant: 6.2 kg fuselage, two tilting rotors at 0.62 m, 1.8 m wing, tilt joints 0 to 1.57 rad, thrust 57.2 N per rotor. Planar dynamics with rigid cable pendulum. Payload mass, cable length, drag coefficients, controller gains, actuator time constants, altitudes and tension bound are NOT specified and are assumed. Rotor arm and wing span retained as structural parameters. Controller sampled at 250 Hz with input-shaped position references and cable-swing damping. A controlled 9.6 N gust acts over the middle third. Acceptance is fail-closed."));
end TiltWingDeliverE;