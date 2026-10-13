model AckermannRoverClimbD
  "Floating-base Ackermann rover: ramp climb, plateau traverse, edge stop"

  // ===== Specified physical parameters =====
  parameter Real m_chassis = 34.0 "Chassis mass [kg]";
  parameter Real L_chassis = 1.05 "Chassis length [m]";
  parameter Real W_chassis = 0.64 "Chassis width [m]";
  parameter Real L_wheelbase = 0.74 "Wheelbase [m]";
  parameter Real mu = 0.76 "Friction coefficient";
  parameter Real tau_max = 28.0 "Actuator torque limit [N.m]";
  parameter Real delta_max = 0.52 "Steering angle limit [rad]";
  parameter Real ramp_angle_deg = 12.0 "Ramp angle [deg]";
  parameter Real plateau_length = 2.0 "Plateau length [m]";
  parameter Real ridge_height = 0.05 "Ridge height [m]";
  parameter Real F_payload = 150.0 "Payload disturbance force [N]";
  parameter Real T_sim = 14.0 "Simulation duration [s]";
  parameter Real dt_control = 0.005 "Control period [s] (200 Hz)";

  // ===== Specified constraints =====
  parameter Real slip_limit = 0.35 "Maximum slip ratio";
  parameter Real attitude_limit = 0.40 "Maximum roll/pitch [rad]";
  parameter Real tracking_error_limit = 0.18 "Max tracking error after 9.1 s [m/s]";
  parameter Real t_convergence = 9.1 "Convergence time [s]";

  // ===== Assumed parameters (not specified in requirement) =====
  parameter Real r_wheel = 0.15 "Wheel radius [m] - assumed";
  parameter Real J_pitch = 2.5 "Pitch inertia [kg.m2] - assumed";
  parameter Real k_susp = 800.0 "Suspension stiffness [N.m/rad] - assumed";
  parameter Real c_susp = 80.0 "Suspension damping [N.m.s/rad] - assumed";
  parameter Real tau_slip = 0.05 "Slip time constant [s] - assumed";
  parameter Real tau_steer = 0.1 "Steering time constant [s] - assumed";
  parameter Real x_ramp_start = 1.5 "Ramp start position [m] - assumed";
  parameter Real L_ramp = 2.0 "Ramp length [m] - assumed";
  parameter Real ridge_width = 0.15 "Ridge half-width [m] - assumed";
  parameter Real stop_margin = 0.3 "Stopping margin before edge [m] - assumed";

  // ===== Derived terrain parameters =====
  parameter Real ramp_angle = ramp_angle_deg * Modelica.Constants.pi / 180.0 "Ramp angle [rad]";
  parameter Real x_plateau_start = x_ramp_start + L_ramp "Plateau start [m]";
  parameter Real x_edge = x_plateau_start + plateau_length "Descending edge [m]";
  parameter Real x_stop = x_edge - stop_margin - L_chassis / 2.0 "Stop position [m]";
  parameter Real x_ridge1 = x_ramp_start - 0.5 "First ridge on flat approach [m]";
  parameter Real x_ridge2 = x_plateau_start + 0.8 "Second ridge on plateau [m]";

  // ===== Controller gains (assumed) =====
  parameter Real kp_speed = 80.0 "Speed proportional gain - assumed";
  parameter Real ki_speed = 200.0 "Speed integral gain - assumed";
  parameter Real v_climb = 0.5 "Climbing speed [m/s] - assumed";
  parameter Real v_traverse = 0.4 "Traverse speed [m/s] - assumed";
  parameter Real slip_target = 0.15 "Target slip for limiting - assumed";
  parameter Real kp_steer = 2.0 "Steering lateral gain - assumed";
  parameter Real kp_heading = 0.5 "Heading gain - assumed";
  parameter Real Cd = 0.3 "Drag coefficient - assumed";
  parameter Real A_front = 0.3 "Frontal area [m2] - assumed";

  // ===== Continuous states =====
  Real x_pos(start = 0.0, fixed = true) "Longitudinal position [m]";
  Real v(start = 0.0, fixed = true) "Longitudinal velocity [m/s]";
  Real theta_pitch(start = 0.0, fixed = true) "Pitch angle [rad]";
  Real omega_pitch(start = 0.0, fixed = true) "Pitch rate [rad/s]";
  Real delta_steer(start = 0.0, fixed = true) "Steering angle [rad]";
  Real psi(start = 0.0, fixed = true) "Heading [rad]";
  Real y_pos(start = 0.0, fixed = true) "Lateral position [m]";
  Real integral_error(start = 0.0, fixed = true) "Integral speed error [m]";
  Real slip_ratio(start = 0.0, fixed = true) "Wheel slip ratio";

  // ===== Discrete controller outputs (200 Hz) =====
  discrete Real v_ref(start = 0.0) "Speed reference [m/s]";
  discrete Real tau_traction_cmd(start = 0.0) "Commanded traction torque [N.m]";
  discrete Real delta_cmd(start = 0.0) "Commanded steering [rad]";
  discrete Real F_brake_cmd(start = 0.0) "Commanded brake force [N]";
  discrete Real phase_d(start = 0.0) "Mission phase";
  discrete Boolean stop_cmd(start = false) "Stop command flag";

  // ===== Continuous variables =====
  Real terrain_slope "Terrain slope at rover [rad]";
  Real terrain_height "Terrain height at rover [m]";
  Real ridge_height_at_x "Ridge height contribution [m]";
  Real F_traction "Traction force [N]";
  Real F_gravity_long "Gravity longitudinal component [N]";
  Real F_normal "Normal force [N]";
  Real F_drag "Aerodynamic drag [N]";
  Real F_disturbance "Payload disturbance force [N]";
  Real F_brake "Braking force [N]";
  Real F_friction_max "Maximum friction force [N]";
  Real tau_traction_sat "Saturated traction torque [N.m]";
  Real delta_sat "Saturated steering [rad]";
  Real roll_angle "Roll angle [rad]";

  // ===== Sensor outputs =====
  Real v_meas "Encoder speed measurement [m/s]";
  Real pitch_meas "IMU pitch measurement [rad]";
  Real roll_meas "IMU roll measurement [rad]";
  Real yaw_rate_meas "IMU yaw rate measurement [rad/s]";
  Real edge_dist_meas "Depth sensor edge distance [m]";
  Real edge_distance "Distance to descending edge [m]";

  // ===== Monitoring =====
  Boolean disturbance_active "Disturbance active flag";
  Real primary_tracking_error "Primary tracking error [m/s]";
  Boolean slip_violation "Slip ratio exceeds limit";
  Boolean attitude_violation "Attitude exceeds limit";

protected
  constant Real g = 9.81 "Gravitational acceleration [m/s2]";
  constant Real v_eps = 0.01 "Velocity epsilon for zero-speed branch [m/s]";
  constant Real rho_air = 1.225 "Air density [kg/m3]";
  discrete Real tau_pi "PI controller torque output [N.m]";
  discrete Real v_error_d "Discrete speed error [m/s]";
  discrete Real slip_ratio_d "Discrete slip measurement";

equation
  // ===== Terrain model with ridges =====
  ridge_height_at_x = ridge_height *
    (Modelica.Math.exp(-((x_pos - x_ridge1)^2) / (2.0 * ridge_width^2)) +
     Modelica.Math.exp(-((x_pos - x_ridge2)^2) / (2.0 * ridge_width^2)));

  terrain_height = (if x_pos < x_ramp_start then 0.0
    elseif x_pos < x_plateau_start then (x_pos - x_ramp_start) * Modelica.Math.tan(ramp_angle)
    else L_ramp * Modelica.Math.tan(ramp_angle)) + ridge_height_at_x;

  // Total terrain slope: base slope plus ridge derivative
  terrain_slope = (if x_pos < x_ramp_start then 0.0
    elseif x_pos < x_plateau_start then ramp_angle
    else 0.0)
    - ridge_height * (
      (x_pos - x_ridge1) / ridge_width^2 * Modelica.Math.exp(-((x_pos - x_ridge1)^2) / (2.0 * ridge_width^2)) +
      (x_pos - x_ridge2) / ridge_width^2 * Modelica.Math.exp(-((x_pos - x_ridge2)^2) / (2.0 * ridge_width^2)));

  // ===== Pitch dynamics (simplified spring-damper suspension) =====
  J_pitch * der(omega_pitch) = k_susp * (terrain_slope - theta_pitch) - c_susp * omega_pitch;
  der(theta_pitch) = omega_pitch;
  roll_angle = 0.0;

  // ===== Force computation =====
  F_gravity_long = m_chassis * g * Modelica.Math.sin(terrain_slope);
  F_normal = m_chassis * g * Modelica.Math.cos(terrain_slope);
  F_friction_max = if F_normal > 1.0 then mu * F_normal else 0.0;
  F_drag = 0.5 * rho_air * Cd * A_front * v * abs(v);

  // Controlled 150 N payload disturbance during middle third of simulation
  disturbance_active = (time >= T_sim / 3.0) and (time < 2.0 * T_sim / 3.0);
  F_disturbance = if disturbance_active then
    F_payload * Modelica.Math.sin(Modelica.Constants.pi * (time - T_sim / 3.0) / (T_sim / 3.0))
  else 0.0;

  // Independent actuator saturation: traction and steering bounded to 28 N.m / 0.52 rad
  tau_traction_sat = max(-tau_max, min(tau_max, tau_traction_cmd));
  delta_sat = max(-delta_max, min(delta_max, delta_cmd));

  F_traction = tau_traction_sat / r_wheel;
  F_brake = max(0.0, min(F_friction_max, F_brake_cmd));

  // ===== Longitudinal dynamics =====
  der(v) = (F_traction - F_gravity_long - F_disturbance - F_drag - F_brake) / m_chassis;
  der(x_pos) = v;

  // ===== Steering and lateral dynamics (Ackermann) =====
  der(delta_steer) = (delta_sat - delta_steer) / tau_steer;
  der(psi) = v / L_wheelbase * Modelica.Math.tan(delta_steer);
  der(y_pos) = v * Modelica.Math.sin(psi);

  // ===== Slip ratio dynamics =====
  der(slip_ratio) = (F_traction / (F_friction_max + v_eps) * 0.3 - slip_ratio) / tau_slip;

  // ===== Integral error with anti-windup =====
  der(integral_error) = if abs(tau_traction_sat) < tau_max * 0.99 then (v_ref - v) else 0.0;

  // ===== Edge distance =====
  edge_distance = x_edge - (x_pos + L_chassis / 2.0);

  // ===== Sensor outputs (encoders, IMU, depth sensor) =====
  v_meas = v;
  pitch_meas = theta_pitch;
  roll_meas = roll_angle;
  yaw_rate_meas = v / L_wheelbase * Modelica.Math.tan(delta_steer);
  edge_dist_meas = edge_distance;

  // ===== Constraint monitoring =====
  primary_tracking_error = if time >= t_convergence then abs(v_ref - v) else 0.0;
  slip_violation = abs(slip_ratio) > slip_limit;
  attitude_violation = (abs(roll_angle) > attitude_limit) or (abs(theta_pitch) > attitude_limit);

  // ===== Discrete slip-aware traction controller at 200 Hz =====
  when sample(0, dt_control) then
    // Mission phase: 0=approach, 1=climb, 2=traverse, 3=stopped
    if x_pos < x_ramp_start then
      phase_d = 0.0;
    elseif x_pos < x_plateau_start then
      phase_d = 1.0;
    elseif x_pos < x_stop then
      phase_d = 2.0;
    else
      phase_d = 3.0;
    end if;

    // Stop before descending edge or near end of simulation
    stop_cmd = (x_pos >= x_stop) or (time >= T_sim - 1.5);

    // Speed reference profile
    if stop_cmd then
      v_ref = 0.0;
    elseif phase_d < 1.0 then
      v_ref = v_climb * min(1.0, time);
    elseif phase_d < 2.0 then
      v_ref = v_climb;
    else
      v_ref = v_traverse;
    end if;

    // Speed tracking error
    v_error_d = v_ref - v;

    // PI traction controller
    tau_pi = kp_speed * v_error_d + ki_speed * integral_error;

    // Slip-aware traction limiting
    slip_ratio_d = slip_ratio;
    if abs(slip_ratio_d) > slip_target then
      tau_traction_cmd = tau_pi * (slip_target / (abs(slip_ratio_d) + v_eps));
    else
      tau_traction_cmd = tau_pi;
    end if;

    // Bounded braking when stopping
    if stop_cmd and v > 0.02 then
      F_brake_cmd = m_chassis * v / 0.5;
    else
      F_brake_cmd = 0.0;
    end if;

    // Steering controller: hold heading and lateral position
    delta_cmd = kp_steer * (0.0 - y_pos) - kp_heading * psi;
  end when;

  annotation(
    Documentation(info = "Ackermann rover ascending 12 deg ramp, traversing 2 m plateau, stopping before descending edge. Two 0.05 m ridges, friction 0.76, 150 N disturbance in middle third. Slip-aware traction control at 200 Hz."),
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005));
end AckermannRoverClimbD;