model AckermannRoverClimbE
  // Physical constants
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real pi_val = 3.1415926535897932 "Pi constant";

  // Chassis parameters (from requirement)
  parameter Real m_chassis = 34.0 "Chassis mass [kg]";
  parameter Real L_chassis = 1.05 "Chassis length [m]";
  parameter Real W_chassis = 0.64 "Chassis width [m]";
  parameter Real L_wheelbase = 0.74 "Wheelbase [m]";
  parameter Real mu = 0.76 "Friction coefficient";
  parameter Real steer_limit = 0.52 "Front steering joint limit [rad]";
  parameter Real torque_limit = 30.8 "Actuator command magnitude bound [N.m]";

  // Terrain parameters (from requirement)
  parameter Real ramp_angle = 12.0 * pi_val / 180.0 "Ramp angle [rad] (12 deg)";
  parameter Real plateau_length = 2.0 "Plateau length [m]";
  parameter Real ridge_height = 0.05 "Surface ridge height [m]";
  parameter Real payload_force = 180.0 "Payload force [N]";

  // Assumed parameters (not specified in requirement, labeled as assumed)
  parameter Real r_wheel = 0.12 "Wheel radius [m] - assumed";
  parameter Real I_wheel = 0.5 "Rear wheel inertia [kg.m2] - assumed";
  parameter Real x_ramp_start = 1.0 "Ramp start position [m] - assumed";
  parameter Real ramp_length = 4.0 "Ramp length [m] - assumed";
  parameter Real x_ramp_end = x_ramp_start + ramp_length "Ramp end / plateau start [m]";
  parameter Real x_plateau_end = x_ramp_end + plateau_length "Plateau end / descending edge [m]";
  parameter Real x_ridge1 = x_ramp_start + 1.5 "First ridge position [m] - assumed";
  parameter Real x_ridge2 = x_ramp_end + 1.0 "Second ridge position [m] - assumed";
  parameter Real ridge_half_width = 0.1 "Ridge half-width [m] - assumed";

  // Control parameters
  parameter Real dt_control = 1.0 / 250.0 "Control period [s] (250 Hz)";
  parameter Real T_sim = 16.0 "Simulation duration [s]";
  parameter Real K_speed = 200.0 "Speed controller proportional gain";

  // Acceptance thresholds (from requirement)
  parameter Real slip_limit = 0.35 "Slip ratio limit";
  parameter Real roll_pitch_limit = 0.40 "Roll/pitch limit [rad]";
  parameter Real tracking_error_limit = 0.162 "Tracking error limit [m/s]";
  parameter Real t_tracking_check = 10.4 "Tracking error check time [s]";
  parameter Real stop_vel_threshold = 0.05 "Stopped velocity threshold [m/s]";

  // ===== DYNAMIC STATES =====
  Real x(start = 0.0, fixed = true) "Longitudinal position [m]";
  Real v(start = 0.0, fixed = true) "Longitudinal velocity [m/s]";
  Real pitch(start = 0.0, fixed = true) "Pitch angle [rad]";
  Real roll(start = 0.0, fixed = true) "Roll angle [rad]";
  Real omega_rear(start = 0.0, fixed = true) "Rear wheel angular velocity [rad/s]";
  Real theta_steer(start = 0.0, fixed = true) "Front steering angle [rad]";

  // ===== ESTIMATOR / SENSOR STATES =====
  Real v_est(start = 0.0) "Encoder-filtered speed estimate [m/s]";
  Real pitch_est(start = 0.0) "IMU pitch estimate [rad]";
  Real roll_est(start = 0.0) "IMU roll estimate [rad]";

  // ===== DISCRETE CONTROLLER VARIABLES =====
  discrete Real tau_traction_cmd(start = 0.0) "Traction torque command [N.m]";
  discrete Real tau_steer_cmd(start = 0.0) "Steering torque command [N.m]";
  discrete Real v_ref(start = 0.0) "Speed reference [m/s]";

  // ===== CONTINUOUS COMPUTED VARIABLES =====
  Real tau_traction_sat "Saturated traction torque [N.m]";
  Real tau_steer_sat "Saturated steering torque [N.m]";
  Real speed_error "Speed tracking error [m/s]";
  Real slip_ratio "Wheel slip ratio";
  Real terrain_slope "Terrain slope at current position [rad]";
  Real terrain_height "Terrain height at current position [m]";
  Real F_traction "Ground traction force [N]";
  Real F_gravity_slope "Gravity slope resistance [N]";
  Real F_normal "Normal force [N]";
  Real F_max_friction "Maximum friction force [N]";
  Real F_payload_normal "Payload downward force [N]";
  Real F_ridge "Ridge disturbance force [N]";
  Real F_total_long "Total longitudinal force on chassis [N]";
  Real depth_meas "Forward depth sensor: distance to descending edge [m]";
  Real v_enc "Encoder speed measurement [m/s]";
  Real ridge_profile_val "Ridge profile value [0..1]";
  Real K_payload "Payload active factor [0 or 1]";

  // ===== ACCEPTANCE MONITORS =====
  Boolean actuator_limit_ok;
  Boolean slip_ok;
  Boolean roll_pitch_ok;
  Boolean stopped_before_edge;
  Boolean tracking_ok;
  Boolean no_nan_inf;
  Boolean acceptance_pass;

equation
  // ===== TERRAIN PROFILE =====
  // Flat ground, 12-degree ramp, 2 m plateau, then descending edge
  if x < x_ramp_start then
    terrain_height = 0.0;
    terrain_slope = 0.0;
  elseif x < x_ramp_end then
    terrain_height = (x - x_ramp_start) * sin(ramp_angle);
    terrain_slope = ramp_angle;
  elseif x < x_plateau_end then
    terrain_height = ramp_length * sin(ramp_angle);
    terrain_slope = 0.0;
  else
    terrain_height = ramp_length * sin(ramp_angle) - (x - x_plateau_end) * sin(ramp_angle);
    terrain_slope = -ramp_angle;
  end if;

  // ===== RIDGE PROFILE (two 0.05 m ridges as smooth cosine bumps) =====
  if abs(x - x_ridge1) < ridge_half_width then
    ridge_profile_val = 0.5 * (1.0 + cos(pi_val * (x - x_ridge1) / ridge_half_width));
  elseif abs(x - x_ridge2) < ridge_half_width then
    ridge_profile_val = 0.5 * (1.0 + cos(pi_val * (x - x_ridge2) / ridge_half_width));
  else
    ridge_profile_val = 0.0;
  end if;

  // Ridge resistance force (proportional to ridge height and chassis weight)
  F_ridge = m_chassis * g * ridge_height * ridge_profile_val / (2.0 * ridge_half_width);

  // ===== PAYLOAD (180 N, middle-third disturbance) =====
  K_payload = if (time > T_sim / 3.0 and time < 2.0 * T_sim / 3.0) then 1.0 else 0.0;
  F_payload_normal = payload_force * K_payload;

  // ===== FORCES =====
  F_normal = (m_chassis * g + F_payload_normal) * cos(terrain_slope);
  F_gravity_slope = (m_chassis * g + F_payload_normal) * sin(terrain_slope);
  F_max_friction = mu * F_normal;

  // Tire friction model: traction force from slip ratio
  F_traction = F_max_friction * tanh(slip_ratio * 5.0);

  // ===== SLIP RATIO =====
  // (omega * r - v) / (|v| + 0.1) — well-defined zero-error branch at v = 0
  slip_ratio = (omega_rear * r_wheel - v) / (abs(v) + 0.1);

  // ===== ACTUATOR SATURATION (independent bounds, 30.8 N.m) =====
  tau_traction_sat = if abs(tau_traction_cmd) > torque_limit then torque_limit * sign(tau_traction_cmd) else tau_traction_cmd;
  tau_steer_sat = if abs(tau_steer_cmd) > torque_limit then torque_limit * sign(tau_steer_cmd) else tau_steer_cmd;

  // ===== REAR WHEEL DYNAMICS (rear-wheel drive) =====
  der(omega_rear) = (tau_traction_sat - F_traction * r_wheel) / I_wheel;

  // ===== CHASSIS LONGITUDINAL DYNAMICS =====
  F_total_long = F_traction - F_gravity_slope - F_ridge;
  der(v) = F_total_long / m_chassis;
  der(x) = v;

  // ===== PITCH DYNAMICS (follows terrain with lag) =====
  der(pitch) = (terrain_slope - pitch) / 0.15;

  // ===== ROLL DYNAMICS (disturbance from ridges with damping) =====
  der(roll) = -roll / 0.3 + ridge_profile_val * 0.3;

  // ===== STEERING DYNAMICS (front steering, joint-limited to +/- 0.52 rad) =====
  der(theta_steer) = tau_steer_sat / 10.0
    - 50.0 * max(0.0, theta_steer - steer_limit)
    + 50.0 * max(0.0, -steer_limit - theta_steer);

  // ===== SENSORS =====
  // Encoder
  v_enc = v;
  // Forward depth sensor: distance to descending edge
  depth_meas = x_plateau_end - x;

  // Sensor estimator dynamics
  der(v_est) = (v_enc - v_est) / 0.05;
  der(pitch_est) = (pitch - pitch_est) / 0.02;
  der(roll_est) = (roll - roll_est) / 0.02;

  // ===== SPEED TRACKING ERROR (continuous, for monitoring) =====
  speed_error = v_ref - v;

  // ===== DISCRETE CONTROLLER (250 Hz, slip-aware, bounded braking) =====
  when sample(0, dt_control) then
    // Speed reference: climb ramp, traverse plateau, stop before edge
    if x < x_ramp_start then
      v_ref = 0.5;
    elseif x < x_ramp_end then
      v_ref = 0.6;
    elseif depth_meas > 0.6 then
      v_ref = 0.4;
    elseif depth_meas > 0.1 then
      v_ref = 0.15;
    else
      v_ref = 0.0;
    end if;

    // Slip-aware traction control with bounded braking
    if abs(slip_ratio) > 0.28 then
      // Slip exceeds threshold: reduce torque proportionally
      tau_traction_cmd = K_speed * (v_ref - v) * max(0.0, 1.0 - (abs(slip_ratio) - 0.28) / 0.07);
    else
      // Normal operation: proportional speed control
      tau_traction_cmd = K_speed * (v_ref - v);
    end if;

    // Steering control: maintain zero steering on straight path
    tau_steer_cmd = -5.0 * theta_steer;
  end when;

  // ===== ACCEPTANCE MONITORS (fail-closed) =====

  // Actuator limits satisfied
  actuator_limit_ok = (abs(tau_traction_sat) <= torque_limit + 1.0e-6)
    and (abs(tau_steer_sat) <= torque_limit + 1.0e-6)
    and (abs(theta_steer) <= steer_limit + 1.0e-3);

  // Slip ratio below 0.35
  slip_ok = abs(slip_ratio) < slip_limit;

  // Roll and pitch below 0.40 rad
  roll_pitch_ok = (abs(roll) < roll_pitch_limit) and (abs(pitch) < roll_pitch_limit);

  // Stopped before descending edge (checked near end of simulation)
  stopped_before_edge = (time < T_sim - 1.0) or (v < stop_vel_threshold and x < x_plateau_end - 0.02);

  // Tracking error below 0.162 m/s after 10.4 s
  tracking_ok = (time < t_tracking_check) or (abs(speed_error) < tracking_error_limit);

  // No NaN or infinite physical, control, or estimator values
  no_nan_inf = (x > -1.0e12) and (x < 1.0e12)
    and (v > -1.0e12) and (v < 1.0e12)
    and (pitch > -1.0e12) and (pitch < 1.0e12)
    and (roll > -1.0e12) and (roll < 1.0e12)
    and (tau_traction_sat > -1.0e12) and (tau_traction_sat < 1.0e12)
    and (tau_steer_sat > -1.0e12) and (tau_steer_sat < 1.0e12)
    and (slip_ratio > -1.0e12) and (slip_ratio < 1.0e12)
    and (v_ref > -1.0e12) and (v_ref < 1.0e12)
    and (F_traction > -1.0e12) and (F_traction < 1.0e12)
    and (v_est > -1.0e12) and (v_est < 1.0e12)
    and (pitch_est > -1.0e12) and (pitch_est < 1.0e12)
    and (roll_est > -1.0e12) and (roll_est < 1.0e12);

  // Fail-closed: all conditions must be satisfied simultaneously
  acceptance_pass = actuator_limit_ok and slip_ok and roll_pitch_ok
    and stopped_before_edge and tracking_ok and no_nan_inf;

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "<html>
      <p>AckermannRoverClimbE: Floating-base mobile robot ascending a 12-degree ramp,
      traversing a 2 m plateau, and stopping before the descending edge.</p>
      <p>Plant: 34 kg chassis, 1.05 m long, 0.64 m wide, 0.74 m wheelbase,
      rear-wheel drive, front steering joints limited to +/- 0.52 rad.</p>
      <p>Actuators independently bounded at 30.8 N.m. Friction 0.76.
      Two 0.05 m surface ridges. 180 N payload force during middle third.</p>
      <p>Controller: slip-aware traction control at 250 Hz with bounded braking.</p>
      <p>Acceptance: fail-closed — actuator limits, slip < 0.35, roll/pitch < 0.40 rad,
      stopping margin, tracking error < 0.162 m/s after 10.4 s, no NaN/infinite values.</p>
      <p>Assumed parameters (not specified in requirement): wheel radius 0.12 m,
      wheel inertia 0.5 kg.m2, ramp start at 1.0 m, ramp length 4.0 m,
      ridge positions and half-width.</p>
    </html>")
  );
end AckermannRoverClimbE;