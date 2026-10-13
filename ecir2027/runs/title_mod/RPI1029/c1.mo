model OmniCartBrakeC
  "Floating-base mecanum mobile robot with speed control and deterministic emergency-stop state machine"

  // ============ Physical parameters ============
  parameter Real m_platform = 25.0 "Platform mass [kg]";
  parameter Real r_wheel = 0.095 "Wheel radius [m]";
  parameter Real gamma_deg = 45.0 "Mecanum roller angle [deg]";
  parameter Real Lx = 0.58 "Footprint length [m]";
  parameter Real Ly = 0.46 "Footprint width [m]";
  parameter Real mu_floor = 0.70 "Floor friction coefficient [-]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_trac_max = mu_floor * m_platform * g_acc "Maximum traction force [N]";

  // ============ Control / mission parameters ============
  parameter Real v_ref = 1.2 "Target cruise speed [m/s]";
  parameter Real tau_max = 11.0 "Maximum torque command magnitude per wheel [N.m]";
  parameter Real d_safety = 1.4 "Obstacle safety range [m]";
  parameter Real x_barrier = 7.0 "Fixed barrier position ahead of start [m]";
  parameter Real F_dist_mag = 162.0 "Payload disturbance magnitude [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start time (middle third) [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end time (middle third) [s]";
  parameter Real T_sim = 12.0 "Total simulation duration [s]";
  parameter Real f_control = 125.0 "Control loop frequency [Hz]";
  parameter Real f_camera = 30.0 "Depth camera frequency [Hz]";
  parameter Real Kp_speed = 10.0 "Speed controller proportional gain";
  parameter Real Ki_speed = 5.0 "Speed controller integral gain";
  parameter Real Kp_hold = 200.0 "Stopped-state holding proportional gain";
  parameter Real v_stop_thresh = 0.01 "Velocity threshold for stopped state [m/s]";

  // ============ Dynamic states ============
  Real x(start = 0.0, fixed = true) "Forward position [m]";
  Real v(start = 0.0, fixed = true) "Forward velocity [m/s]";
  Real theta1(start = 0.0, fixed = true) "Wheel 1 encoder angle [rad]";
  Real theta2(start = 0.0, fixed = true) "Wheel 2 encoder angle [rad]";
  Real theta3(start = 0.0, fixed = true) "Wheel 3 encoder angle [rad]";
  Real theta4(start = 0.0, fixed = true) "Wheel 4 encoder angle [rad]";
  Real integ_err(start = 0.0, fixed = true) "Speed error integral";

  // ============ State machine ============
  discrete Integer state(start = 0) "0=ACCEL_CRUISE, 1=BRAKE, 2=STOPPED";
  discrete Boolean obstacle_detected(start = false) "Obstacle within safety range";
  Real d_to_barrier "True distance to barrier [m]";

  // ============ Control variables ============
  Real tau_unsat "Unsaturated torque command per wheel [N.m]";
  Real tau_cmd "Saturated torque command per wheel [N.m]";
  Real tau1 "Wheel 1 torque [N.m]";
  Real tau2 "Wheel 2 torque [N.m]";
  Real tau3 "Wheel 3 torque [N.m]";
  Real tau4 "Wheel 4 torque [N.m]";
  Real F_wheel "Traction-limited wheel driving force [N]";
  Real F_disturbance "Payload disturbance force [N]";
  Real F_net "Net forward force [N]";
  Real a_body "Body acceleration [m/s2]";

  // ============ Sensors ============
  Real a_imu "IMU measured acceleration [m/s2]";
  Real omega1 "Wheel 1 angular velocity [rad/s]";
  Real omega2 "Wheel 2 angular velocity [rad/s]";
  Real omega3 "Wheel 3 angular velocity [rad/s]";
  Real omega4 "Wheel 4 angular velocity [rad/s]";
  Real d_camera "Depth camera distance reading [m]";
  discrete Real d_camera_sampled(start = 7.0) "30 Hz sampled camera distance [m]";

  // ============ Performance metrics ============
  Real v_residual "Residual speed magnitude [m/s]";
  Real tracking_error "Primary tracking error [m]";
  Real stopping_margin "Stopping margin to barrier [m]";
  discrete Real v_max_observed(start = 0.0) "Maximum speed observed [m/s]";

  // ============ Specification-derived quantities ============
  Real roller_angle_rad "Mecanum roller angle [rad]";
  Real footprint_area "Footprint area [m2]";

equation
  // --- Specification-derived quantities ---
  roller_angle_rad = gamma_deg * 3.14159265358979 / 180.0;
  footprint_area = Lx * Ly;

  // --- Distance to barrier ---
  d_to_barrier = x_barrier - x;

  // --- Payload disturbance (middle third: 4 to 8 s) ---
  F_disturbance = if (time >= t_dist_start and time < t_dist_end) then -F_dist_mag else 0.0;

  // --- 30 Hz depth camera sampling ---
  when sample(0, 1.0 / f_camera) then
    d_camera_sampled = d_to_barrier;
    obstacle_detected = d_to_barrier < d_safety;
  end when;
  d_camera = d_camera_sampled;

  // --- State machine and max-speed tracker at 125 Hz ---
  when sample(0, 1.0 / f_control) then
    state = if (pre(state) == 2) then 2
            elseif (pre(state) == 1 and v < v_stop_thresh) then 2
            elseif (pre(state) == 0 and d_to_barrier < d_safety) then 1
            else pre(state);
    v_max_observed = if v > pre(v_max_observed) then v else pre(v_max_observed);
  end when;

  // --- PI speed controller with anti-windup ---
  tau_unsat = Kp_speed * (v_ref - v) + Ki_speed * integ_err;
  der(integ_err) = if (state == 0 and tau_unsat > -tau_max and tau_unsat < tau_max) then (v_ref - v) else 0.0;

  // --- Torque command by state machine ---
  tau_cmd = if state == 0 then
      max(min(tau_unsat, tau_max), -tau_max)
    elseif state == 1 then
      -tau_max
    else
      max(min(-Kp_hold * v, tau_max), -tau_max);

  // --- Equal torque on all four wheels for pure forward holonomic motion ---
  tau1 = tau_cmd;
  tau2 = tau_cmd;
  tau3 = tau_cmd;
  tau4 = tau_cmd;

  // --- Wheel-to-body force (traction-limited) ---
  F_wheel = max(min(4.0 * tau_cmd / r_wheel, F_trac_max), -F_trac_max);

  // --- Equations of motion ---
  F_net = F_wheel + F_disturbance;
  a_body = F_net / m_platform;
  der(v) = a_body;
  der(x) = v;

  // --- Wheel encoder kinematics (rolling without slip) ---
  omega1 = v / r_wheel;
  omega2 = v / r_wheel;
  omega3 = v / r_wheel;
  omega4 = v / r_wheel;
  der(theta1) = omega1;
  der(theta2) = omega2;
  der(theta3) = omega3;
  der(theta4) = omega4;

  // --- IMU acceleration sensor ---
  a_imu = a_body;

  // --- Performance metrics ---
  v_residual = abs(v);
  stopping_margin = x_barrier - x;
  tracking_error = if state == 0 then abs(v_ref - v) else 0.0;

  // ============ Requirement assertions ============
  assert(abs(tau_cmd) <= tau_max + 1e-6, "Effort limit violated");
  assert(x < x_barrier, "Barrier collision detected");
  assert(v_max_observed <= v_ref + 0.1, "Speed limit violated");
  assert(time < 7.8 or stopping_margin > 0.231, "Stopping margin below 0.231 m after 7.8 s");
  assert(time < 8.1 or v_residual < 0.05, "Residual speed exceeds 0.05 m/s");

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "OmniCartBrakeC: 25 kg mecanum platform with four 0.095 m radius wheels at 45 deg roller angle on 0.58 x 0.46 m footprint. Speed control to 1.2 m/s with deterministic emergency-stop state machine triggered at 1.4 m safety range. 162 N payload disturbance during middle third (4-8 s). Fixed barrier at 7 m. Floor friction 0.70. Control at 125 Hz, 12 s simulation. Controller gains Kp=10, Ki=5, Kp_hold=200 are design assumptions not specified in requirements.")
  );
end OmniCartBrakeC;