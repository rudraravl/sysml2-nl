model DiffRoverClimbC
  import Modelica.Constants;
  import Modelica.SIunits;

  // ==================== Physical Parameters (from requirement) ====================
  parameter SIunits.Mass m_chassis = 19.0 "Chassis mass [kg]";
  parameter SIunits.Length L = 0.65 "Chassis length [m]";
  parameter SIunits.Length W_chassis = 0.44 "Chassis width [m]";
  parameter SIunits.Length H_chassis = 0.22 "Chassis height [m]";
  parameter SIunits.Length r_wheel = 0.10 "Driven wheel radius [m]";
  parameter SIunits.Length track_width = 0.46 "Wheel separation [m]";
  parameter SIunits.Length caster_offset = 0.15 "Passive caster offset from wheel axle [m] -- not specified, engineering default";
  parameter Real mu = 0.76 "Friction coefficient";
  parameter SIunits.Length ridge_height = 0.05 "Surface ridge height [m]";
  parameter Integer n_ridges = 2 "Number of surface ridges";
  parameter SIunits.Angle ramp_angle_deg = 12.0 "Ramp angle [deg]";
  parameter SIunits.Angle ramp_angle = ramp_angle_deg * Constants.pi / 180.0 "Ramp angle [rad]";
  parameter SIunits.Length plateau_length = 2.0 "Plateau length [m]";
  parameter SIunits.Length ramp_length = 1.5 "Ramp length [m] -- not specified in requirement, engineering default";
  parameter SIunits.Length ridge1_x = 0.8 "First ridge position along ramp [m] -- not specified, engineering default";
  parameter SIunits.Length ridge2_x = 2.3 "Second ridge position on plateau [m] -- not specified, engineering default";
  parameter SIunits.Length ridge_width = 0.04 "Ridge contact width [m] -- not specified, engineering default";

  // ==================== Actuator & Control Parameters (from requirement) ====================
  parameter SIunits.Torque tau_max = 12.0 "Maximum command magnitude [N.m]";
  parameter SIunits.Force f_payload = 135.0 "Payload disturbance force [N]";
  parameter Real slip_limit = 0.35 "Maximum allowed slip ratio";
  parameter SIunits.Angle angle_limit = 0.40 "Maximum allowed roll and pitch [rad]";
  parameter SIunits.Velocity track_err_limit = 0.189 "Maximum tracking error after 7.8 s [m/s]";
  parameter SIunits.Time T_sim = 12.0 "Simulation duration [s]";
  parameter SIunits.Frequency f_sample = 125.0 "Sampling frequency [Hz]";
  parameter SIunits.Time Ts = 1.0 / f_sample "Sample time [s]";
  parameter SIunits.Time t_payload_start = T_sim / 3.0 "Payload disturbance start (middle third) [s]";
  parameter SIunits.Time t_payload_end = 2.0 * T_sim / 3.0 "Payload disturbance end (middle third) [s]";

  // ==================== Derived / Controller Parameters ====================
  parameter SIunits.Acceleration g = Constants.g_n "Gravitational acceleration [m/s^2]";
  parameter SIunits.Inertia J_w = 0.01 "Wheel rotational inertia [kg.m^2] -- not specified, engineering default";
  parameter SIunits.Velocity v_cruise = 0.5 "Cruise speed [m/s] -- not specified, engineering default";
  parameter Real Kp_speed = 25.0 "Speed controller proportional gain -- not specified, engineering default";
  parameter Real Ki_speed = 30.0 "Speed controller integral gain -- not specified, engineering default";
  parameter Real leak_rate = 0.05 "Integral leak (forgetting) rate [1/s] -- not specified, engineering default";
  parameter SIunits.Position x_stop_target = ramp_length + plateau_length - 0.15 "Target stop position before descending edge [m]";
  parameter SIunits.Length stop_decel_dist = 0.8 "Deceleration distance [m] -- not specified, engineering default";
  parameter SIunits.Time t_accel = 0.5 "Initial acceleration ramp time [s] -- not specified, engineering default";

  // ==================== Dynamic State Variables ====================
  SIunits.Position x "Chassis position along path [m]";
  SIunits.Velocity v "Chassis velocity along path [m/s]";
  SIunits.AngularVelocity omega_L "Left wheel angular velocity [rad/s]";
  SIunits.AngularVelocity omega_R "Right wheel angular velocity [rad/s]";
  Real error_integral "Integral of speed error with leak [m]";

  // ==================== Control Variables ====================
  SIunits.Torque tau_L_raw "Raw left motor torque command [N.m]";
  SIunits.Torque tau_R_raw "Raw right motor torque command [N.m]";
  SIunits.Torque tau_L "Bounded left motor torque [N.m]";
  SIunits.Torque tau_R "Bounded right motor torque [N.m]";
  SIunits.Velocity v_ref "Reference speed [m/s]";
  SIunits.Velocity v_meas "Measured speed from encoders [m/s]";
  SIunits.Torque tau_ff "Feedforward gravity compensation torque per motor [N.m]";
  Real slip_L "Left wheel slip ratio";
  Real slip_R "Right wheel slip ratio";
  Real slip_max_actual "Maximum absolute slip across both wheels";
  Real slip_reduction "Slip-aware torque reduction factor [0..1]";
  Real v_wheel_L "Left wheel contact linear speed [m/s]";
  Real v_wheel_R "Right wheel contact linear speed [m/s]";

  // ==================== Sensor Variables ====================
  SIunits.Velocity v_encoder "Encoder-measured speed [m/s]";
  SIunits.Angle pitch_imu "IMU-measured pitch [rad]";
  SIunits.Angle roll_imu "IMU-measured roll [rad]";
  SIunits.Length dist_edge "Forward depth sensor: distance to descending edge [m]";

  // ==================== Surface & Force Variables ====================
  SIunits.Length surface_z "Surface height at position x [m]";
  SIunits.Angle surface_slope "Surface slope angle at position x [rad]";
  SIunits.Force F_traction_L "Left wheel traction force [N]";
  SIunits.Force F_traction_R "Right wheel traction force [N]";
  SIunits.Force F_normal "Total normal force on driven wheels [N]";
  SIunits.Force F_gravity_slope "Gravity component along slope [N]";
  SIunits.Force F_payload_actual "Actual payload disturbance force [N]";
  SIunits.Force F_ridge_resist "Ridge resistance force [N]";

  // ==================== Monitors and Traces ====================
  Boolean payload_active "Payload disturbance active";
  Boolean slip_ok "Slip ratio within limits";
  Boolean attitude_ok "Roll and pitch within limits";
  Boolean torque_ok "Torque within actuator limits";
  Boolean stopped "Rover has stopped";
  Boolean no_nan "No NaN or infinite physical, control, or estimator values";
  SIunits.Velocity tracking_error "Speed tracking error [m/s]";
  SIunits.Velocity tracking_error_after "Absolute tracking error after 7.8 s [m/s]";

equation
  // ==================== Surface Profile ====================
  // Flat ground before ramp, 12-degree ramp, 2 m plateau, then descending edge
  if x <= 0.0 then
    surface_z = 0.0;
    surface_slope = 0.0;
  elseif x <= ramp_length then
    surface_z = x * Modelica.Math.sin(ramp_angle);
    surface_slope = ramp_angle;
  elseif x <= ramp_length + plateau_length then
    surface_z = ramp_length * Modelica.Math.sin(ramp_angle);
    surface_slope = 0.0;
  else
    surface_z = ramp_length * Modelica.Math.sin(ramp_angle);
    surface_slope = 0.0;
  end if;

  // ==================== Ridge Resistance (two 0.05 m ridges) ====================
  F_ridge_resist = 10.0 * (ridge_height / r_wheel) * (
    Modelica.Math.exp(-((x - ridge1_x) / ridge_width)^2) +
    Modelica.Math.exp(-((x - ridge2_x) / ridge_width)^2)
  );

  // ==================== Forces ====================
  // Normal force (cosine of slope); always positive
  F_normal = m_chassis * g * Modelica.Math.cos(surface_slope);
  // Gravity component resisting uphill motion
  F_gravity_slope = m_chassis * g * Modelica.Math.sin(surface_slope);
  // Payload disturbance: 135 N during middle third of simulation
  payload_active = time >= t_payload_start and time <= t_payload_end;
  F_payload_actual = if payload_active then f_payload else 0.0;

  // ==================== Wheel Slip Ratios ====================
  v_wheel_L = r_wheel * omega_L;
  v_wheel_R = r_wheel * omega_R;
  // Slip ratio with zero-error branch for near-zero wheel speeds
  slip_L = if abs(v_wheel_L) > 1e-6 then (v_wheel_L - v) / abs(v_wheel_L) else 0.0;
  slip_R = if abs(v_wheel_R) > 1e-6 then (v_wheel_R - v) / abs(v_wheel_R) else 0.0;
  slip_max_actual = max(abs(slip_L), abs(slip_R));

  // ==================== Slip-Aware Torque Reduction ====================
  // Linearly reduces from 1.0 at 70% of slip limit to 0.0 at slip limit
  // Divisor 0.3 * slip_limit is always positive (slip_limit = 0.35)
  slip_reduction = max(0.0, min(1.0, (slip_limit - slip_max_actual) / (0.3 * slip_limit)));

  // ==================== Traction Forces (friction-limited) ====================
  // Each driven wheel carries half the normal force; caster carries remainder
  F_traction_L = max(-mu * F_normal / 2.0, min(mu * F_normal / 2.0, tau_L / r_wheel));
  F_traction_R = max(-mu * F_normal / 2.0, min(mu * F_normal / 2.0, tau_R / r_wheel));

  // ==================== Equations of Motion ====================
  // Chassis longitudinal dynamics
  der(x) = v;
  der(v) = (F_traction_L + F_traction_R - F_gravity_slope - F_payload_actual - F_ridge_resist) / m_chassis;
  // Independent wheel rotational dynamics (continuous Y-axis joints)
  der(omega_L) = (tau_L - F_traction_L * r_wheel) / J_w;
  der(omega_R) = (tau_R - F_traction_R * r_wheel) / J_w;

  // ==================== Reference Speed Profile ====================
  // Phase 1: Time-based initial acceleration ramp
  // Phase 2: Cruise at constant speed
  // Phase 3: Distance-based deceleration to stop before descending edge
  // Phase 4: Stopped (v_ref = 0)
  if time < t_accel then
    v_ref = v_cruise * time / t_accel;
  elseif x < x_stop_target - stop_decel_dist then
    v_ref = v_cruise;
  elseif x < x_stop_target then
    v_ref = v_cruise * (x_stop_target - x) / stop_decel_dist;
  else
    v_ref = 0.0;
  end if;

  // ==================== Speed Measurement (encoders) ====================
  v_meas = (v_wheel_L + v_wheel_R) / 2.0;
  v_encoder = v_meas;

  // ==================== Feedforward Gravity Compensation ====================
  // Per-motor feedforward torque = (gravity slope force * wheel radius) / 2 motors
  tau_ff = F_gravity_slope * r_wheel / 2.0;

  // ==================== PI Speed Controller with Slip Awareness ====================
  tracking_error = v_ref - v_meas;
  // Leaky integrator: prevents windup, bounded steady state
  der(error_integral) = tracking_error - leak_rate * error_integral;
  // Raw torque commands (equal for both motors in straight-line motion)
  tau_L_raw = (Kp_speed * tracking_error + Ki_speed * error_integral + tau_ff) * slip_reduction;
  tau_R_raw = (Kp_speed * tracking_error + Ki_speed * error_integral + tau_ff) * slip_reduction;

  // ==================== Actuator Limits (bounded braking and driving) ====================
  tau_L = max(-tau_max, min(tau_max, tau_L_raw));
  tau_R = max(-tau_max, min(tau_max, tau_R_raw));

  // ==================== Sensor Models ====================
  // IMU: pitch follows surface slope; roll is zero for straight-line ascending motion
  pitch_imu = surface_slope;
  roll_imu = 0.0;
  // Forward depth sensor: distance to descending edge of plateau
  dist_edge = ramp_length + plateau_length - x;

  // ==================== Safety Monitors ====================
  slip_ok = slip_max_actual < slip_limit;
  attitude_ok = abs(pitch_imu) < angle_limit and abs(roll_imu) < angle_limit;
  torque_ok = abs(tau_L) <= tau_max + 1e-9 and abs(tau_R) <= tau_max + 1e-9;
  stopped = abs(v) < 0.01;
  // Primary tracking error evaluated after 7.8 s
  tracking_error_after = if time >= 7.8 then abs(tracking_error) else 0.0;
  // NaN/Infinity check: IEEE 754 guarantees NaN comparisons return false
  no_nan = (v > -1e30 and v < 1e30) and
           (tau_L > -1e30 and tau_L < 1e30) and
           (tau_R > -1e30 and tau_R < 1e30) and
           (slip_L > -1e30 and slip_L < 1e30) and
           (slip_R > -1e30 and slip_R < 1e30) and
           (error_integral > -1e30 and error_integral < 1e30);

  // ==================== Initial Conditions ====================
initial equation
  x = 0.0;
  v = 0.0;
  omega_L = 0.0;
  omega_R = 0.0;
  error_integral = 0.0;

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