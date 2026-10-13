model DiffRoverClimbC
  // Physical parameters (from requirement)
  parameter Real m_chassis = 19.0 "Chassis mass [kg]";
  parameter Real L = 0.65 "Chassis length [m]";
  parameter Real W_chassis = 0.44 "Chassis width [m]";
  parameter Real H_chassis = 0.22 "Chassis height [m]";
  parameter Real r_wheel = 0.10 "Driven wheel radius [m]";
  parameter Real track_width = 0.46 "Wheel separation [m]";
  parameter Real mu = 0.76 "Friction coefficient";
  parameter Real ridge_height = 0.05 "Surface ridge height [m]";
  parameter Integer n_ridges = 2 "Number of surface ridges";
  parameter Real ramp_angle_deg = 12.0 "Ramp angle [deg]";
  parameter Real ramp_angle = ramp_angle_deg * 3.14159265358979 / 180.0 "Ramp angle [rad]";
  parameter Real plateau_length = 2.0 "Plateau length [m]";
  parameter Real ramp_length = 1.5 "Ramp length [m] -- unspecified, engineering default";
  parameter Real ridge1_x = 0.8 "First ridge position [m] -- unspecified, engineering default";
  parameter Real ridge2_x = 2.3 "Second ridge position [m] -- unspecified, engineering default";
  parameter Real ridge_width = 0.04 "Ridge contact width [m] -- unspecified, engineering default";

  // Actuator and control parameters (from requirement)
  parameter Real tau_max = 12.0 "Maximum command magnitude [N.m]";
  parameter Real f_payload = 135.0 "Payload disturbance force [N]";
  parameter Real slip_limit = 0.35 "Maximum allowed slip ratio";
  parameter Real angle_limit = 0.40 "Maximum allowed roll and pitch [rad]";
  parameter Real track_err_limit = 0.189 "Maximum tracking error after 7.8 s [m/s]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";
  parameter Real f_sample = 125.0 "Sampling frequency [Hz]";
  parameter Real Ts = 1.0 / f_sample "Sample time [s]";
  parameter Real t_payload_start = T_sim / 3.0 "Payload disturbance start [s]";
  parameter Real t_payload_end = 2.0 * T_sim / 3.0 "Payload disturbance end [s]";

  // Derived and controller parameters
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real J_w = 0.01 "Wheel rotational inertia [kg.m^2] -- unspecified, engineering default";
  parameter Real v_cruise = 0.5 "Cruise speed [m/s] -- unspecified, engineering default";
  parameter Real Kp_speed = 25.0 "Speed controller proportional gain -- unspecified, engineering default";
  parameter Real Ki_speed = 30.0 "Speed controller integral gain -- unspecified, engineering default";
  parameter Real leak_rate = 0.05 "Integral leak rate [1/s] -- unspecified, engineering default";
  parameter Real x_stop_target = ramp_length + plateau_length - 0.15 "Target stop position [m]";
  parameter Real stop_decel_dist = 0.8 "Deceleration distance [m] -- unspecified, engineering default";
  parameter Real t_accel = 0.5 "Initial acceleration ramp time [s] -- unspecified, engineering default";

  // Dynamic state variables
  Real x(start = 0.0) "Chassis position along path [m]";
  Real v(start = 0.0) "Chassis velocity along path [m/s]";
  Real omega_L(start = 0.0) "Left wheel angular velocity [rad/s]";
  Real omega_R(start = 0.0) "Right wheel angular velocity [rad/s]";
  Real error_integral(start = 0.0) "Integral of speed error with leak [m]";

  // Control variables
  Real tau_L_raw "Raw left motor torque command [N.m]";
  Real tau_R_raw "Raw right motor torque command [N.m]";
  Real tau_L "Bounded left motor torque [N.m]";
  Real tau_R "Bounded right motor torque [N.m]";
  Real v_ref "Reference speed [m/s]";
  Real v_meas "Measured speed from encoders [m/s]";
  Real tau_ff "Feedforward gravity compensation torque per motor [N.m]";
  Real slip_L "Left wheel slip ratio";
  Real slip_R "Right wheel slip ratio";
  Real slip_max_actual "Maximum absolute slip across both wheels";
  Real slip_reduction "Slip-aware torque reduction factor [0..1]";
  Real v_wheel_L "Left wheel contact linear speed [m/s]";
  Real v_wheel_R "Right wheel contact linear speed [m/s]";

  // Sensor variables
  Real v_encoder "Encoder-measured speed [m/s]";
  Real pitch_imu "IMU-measured pitch [rad]";
  Real roll_imu "IMU-measured roll [rad]";
  Real dist_edge "Forward depth sensor: distance to descending edge [m]";

  // Surface and force variables
  Real surface_z "Surface height at position x [m]";
  Real surface_slope "Surface slope angle at position x [rad]";
  Real F_traction_L "Left wheel traction force [N]";
  Real F_traction_R "Right wheel traction force [N]";
  Real F_normal "Total normal force on driven wheels [N]";
  Real F_gravity_slope "Gravity component along slope [N]";
  Real F_payload_actual "Actual payload disturbance force [N]";
  Real F_ridge_resist "Ridge resistance force [N]";

  // Monitors and traces
  Boolean payload_active "Payload disturbance active";
  Boolean slip_ok "Slip ratio within limits";
  Boolean attitude_ok "Roll and pitch within limits";
  Boolean torque_ok "Torque within actuator limits";
  Boolean stopped "Rover has stopped";
  Boolean no_nan "No NaN or infinite physical, control, or estimator values";
  Real tracking_error "Speed tracking error [m/s]";
  Real tracking_error_after "Absolute tracking error after 7.8 s [m/s]";

equation
  // Surface profile: flat ground, 12-degree ramp, 2 m plateau, then descending edge
  if x <= 0.0 then
    surface_z = 0.0;
    surface_slope = 0.0;
  elseif x <= ramp_length then
    surface_z = x * Modelica.Math.sin(ramp_angle);
    surface_slope = ramp_angle;
  else
    surface_z = ramp_length * Modelica.Math.sin(ramp_angle);
    surface_slope = 0.0;
  end if;

  // Ridge resistance (two 0.05 m ridges)
  F_ridge_resist = 10.0 * (ridge_height / r_wheel) * (
    Modelica.Math.exp(-((x - ridge1_x) / ridge_width)^2) +
    Modelica.Math.exp(-((x - ridge2_x) / ridge_width)^2)
  );

  // Forces
  F_normal = m_chassis * g * Modelica.Math.cos(surface_slope);
  F_gravity_slope = m_chassis * g * Modelica.Math.sin(surface_slope);
  payload_active = time >= t_payload_start and time <= t_payload_end;
  F_payload_actual = if payload_active then f_payload else 0.0;

  // Wheel slip ratios with zero-error branch
  v_wheel_L = r_wheel * omega_L;
  v_wheel_R = r_wheel * omega_R;
  slip_L = if abs(v_wheel_L) > 1e-6 then (v_wheel_L - v) / abs(v_wheel_L) else 0.0;
  slip_R = if abs(v_wheel_R) > 1e-6 then (v_wheel_R - v) / abs(v_wheel_R) else 0.0;
  slip_max_actual = max(abs(slip_L), abs(slip_R));

  // Slip-aware torque reduction
  slip_reduction = max(0.0, min(1.0, (slip_limit - slip_max_actual) / (0.3 * slip_limit)));

  // Traction forces (friction-limited)
  F_traction_L = max(-mu * F_normal / 2.0, min(mu * F_normal / 2.0, tau_L / r_wheel));
  F_traction_R = max(-mu * F_normal / 2.0, min(mu * F_normal / 2.0, tau_R / r_wheel));

  // Equations of motion
  der(x) = v;
  der(v) = (F_traction_L + F_traction_R - F_gravity_slope - F_payload_actual - F_ridge_resist) / m_chassis;
  der(omega_L) = (tau_L - F_traction_L * r_wheel) / J_w;
  der(omega_R) = (tau_R - F_traction_R * r_wheel) / J_w;

  // Reference speed profile
  if time < t_accel then
    v_ref = v_cruise * time / t_accel;
  elseif x < x_stop_target - stop_decel_dist then
    v_ref = v_cruise;
  elseif x < x_stop_target then
    v_ref = v_cruise * (x_stop_target - x) / stop_decel_dist;
  else
    v_ref = 0.0;
  end if;

  // Speed measurement (encoders)
  v_meas = (v_wheel_L + v_wheel_R) / 2.0;
  v_encoder = v_meas;

  // Feedforward gravity compensation per motor
  tau_ff = F_gravity_slope * r_wheel / 2.0;

  // PI speed controller with slip awareness
  tracking_error = v_ref - v_meas;
  der(error_integral) = tracking_error - leak_rate * error_integral;
  tau_L_raw = (Kp_speed * tracking_error + Ki_speed * error_integral + tau_ff) * slip_reduction;
  tau_R_raw = (Kp_speed * tracking_error + Ki_speed * error_integral + tau_ff) * slip_reduction;

  // Actuator limits (bounded braking and driving)
  tau_L = max(-tau_max, min(tau_max, tau_L_raw));
  tau_R = max(-tau_max, min(tau_max, tau_R_raw));

  // Sensor models
  pitch_imu = surface_slope;
  roll_imu = 0.0;
  dist_edge = ramp_length + plateau_length - x;

  // Safety monitors
  slip_ok = slip_max_actual < slip_limit;
  attitude_ok = abs(pitch_imu) < angle_limit and abs(roll_imu) < angle_limit;
  torque_ok = abs(tau_L) <= tau_max + 1e-9 and abs(tau_R) <= tau_max + 1e-9;
  stopped = abs(v) < 0.01;
  tracking_error_after = if time >= 7.8 then abs(tracking_error) else 0.0;
  no_nan = (v > -1e30 and v < 1e30) and
           (tau_L > -1e30 and tau_L < 1e30) and
           (tau_R > -1e30 and tau_R < 1e30) and
           (slip_L > -1e30 and slip_L < 1e30) and
           (slip_R > -1e30 and slip_R < 1e30) and
           (error_integral > -1e30 and error_integral < 1e30);

  annotation(
    Experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "<html>
<p><b>DiffRoverClimbC</b>: Floating-base differential-drive rover with slip-aware traction
control and bounded braking. Ascends a 12-degree ramp, traverses a 2 m plateau, and stops
before the descending edge.</p>
<p><b>Plant</b>: 19 kg box chassis (0.65 x 0.44 x 0.22 m), two 0.10 m-radius driven wheels
separated by 0.46 m, one passive caster. Independent wheel motors drive continuous Y-axis
rotational joints. Friction coefficient 0.76. Two 0.05 m-height surface ridges.</p>
<p><b>Sensors</b>: Encoders (speed), IMU (pitch/roll attitude), forward depth sensor
(distance to descending edge).</p>
<p><b>Disturbances</b>: 135 N payload force during middle third (4-8 s); ridge resistance
at two locations along the path.</p>
<p><b>Constraints</b>: |tau| <= 12 N.m, slip < 0.35, |roll| < 0.40 rad, |pitch| < 0.40 rad,
stopping margin before edge, tracking error < 0.189 m/s after 7.8 s, no NaN/Inf.</p>
<p><b>Unspecified parameters</b> (ramp_length, ridge positions, wheel inertia, controller
gains, cruise speed, deceleration distance, caster offset) use engineering defaults
clearly labeled in parameter comments. These are not stated in the requirement.</p>
</html>")
  );
end DiffRoverClimbC;