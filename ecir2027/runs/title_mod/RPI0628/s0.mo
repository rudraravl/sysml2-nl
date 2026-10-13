model HydMotorPositionD
  "Instrumented fluid-power robotic actuator system"

  // ===== Motor and mechanical parameters =====
  parameter Real D_m = 48e-6 "Motor displacement [m3/rev]";
  parameter Real eta_v = 0.92 "Volumetric efficiency [-]";
  parameter Real gear_ratio = 12.0 "Gearbox ratio [-]";
  parameter Real m_table = 130.0 "Table mass [kg]";
  parameter Real Q_max = 0.002 "Max valve flow [m3/s]";

  // ===== Assumed parameters (not specified in requirement) =====
  parameter Real p_supply = 20.0e6 "Supply pressure [Pa], assumed";
  parameter Real p_return = 0.5e6 "Return pressure [Pa], assumed";
  parameter Real beta_fluid = 1.6e9 "Fluid bulk modulus [Pa], assumed";
  parameter Real V_line = 0.001 "Line volume per chamber [m3], assumed";
  parameter Real r_pinion = 0.1 "Pinion radius for linear conversion [m], assumed";
  parameter Real travel_max = 1.0 "Available travel [m], assumed";
  parameter Real b_vis = 500.0 "Viscous damping [N.s/m], assumed";
  parameter Real k_endstop = 1.0e7 "End stop stiffness [N/m], assumed";
  parameter Real c_endstop = 1.0e4 "End stop damping [N.s/m], assumed";

  // ===== Controller parameters =====
  parameter Real Kp = 8.0 "PID proportional gain";
  parameter Real Ki = 3.0 "PID integral gain";
  parameter Real Kd = 2.0 "PID derivative gain";
  parameter Real Ts = 0.005 "Controller sample period [s] (200 Hz)";
  parameter Real x_target = 0.7 * travel_max "Target position [m]";
  parameter Real K_press = 0.1 "Pressure feedback gain for pressure-aware control";

  // ===== Initial conditions =====
  parameter Real x0 = 0.0 "Initial position [m]";
  parameter Real v0 = 0.0 "Initial velocity [m/s]";
  parameter Real p_a0 = 0.5 * (p_supply + p_return) "Initial chamber A pressure [Pa]";
  parameter Real p_b0 = 0.5 * (p_supply + p_return) "Initial chamber B pressure [Pa]";
  parameter Real err_prev0 = x_target - x0 "Initial position error [m]";

  // ===== Continuous states =====
  Real x(start = x0, fixed = true) "Actuator position [m]";
  Real v(start = v0, fixed = true) "Actuator velocity [m/s]";
  Real p_a(start = p_a0, fixed = true) "Chamber A pressure [Pa]";
  Real p_b(start = p_b0, fixed = true) "Chamber B pressure [Pa]";

  // ===== Discrete controller states =====
  discrete Real u_cmd(start = 0.0) "Valve command [-]";
  discrete Real u_pid(start = 0.0) "Raw PID output before saturation [-]";
  discrete Real integ(start = 0.0) "Integral accumulator";
  discrete Real err_prev(start = err_prev0) "Previous position error [m]";

  // ===== Measurements (synchronized sensor traces) =====
  Real x_meas "Measured actuator position [m]";
  Real v_meas "Measured actuator velocity [m/s]";
  Real p_a_meas "Measured chamber A pressure [Pa]";
  Real p_b_meas "Measured chamber B pressure [Pa]";
  Real u_meas "Measured valve command [-]";

  // ===== Internal variables =====
  Real omega_m "Motor angular speed [rad/s]";
  Real T_motor "Motor torque [N.m]";
  Real F_motor "Linear motor force at table [N]";
  Real Q_a "Valve flow to chamber A [m3/s]";
  Real Q_b "Valve flow from chamber B [m3/s]";
  Real Q_leak "Internal leakage flow A to B [m3/s]";
  Real C_leak "Leakage coefficient [m3/(s.Pa)]";
  Real F_endstop "End stop reaction force [N]";
  Real F_external "External disturbance force [N]";
  Real pos_err "Position error [m]";
  Real dp "Pressure differential p_a - p_b [Pa]";
  Real tracking_err "Absolute tracking error [m]";

protected
  constant Real two_pi = 6.28318530717959;

equation
  // ===== Measurements =====
  x_meas = x;
  v_meas = v;
  p_a_meas = p_a;
  p_b_meas = p_b;
  u_meas = u_cmd;

  // ===== Position error and tracking =====
  pos_err = x_target - x;
  tracking_err = abs(pos_err);

  // ===== Pressure differential =====
  dp = p_a - p_b;

  // ===== Leakage from volumetric efficiency =====
  // Derived: at rated dp = p_supply - p_return, leakage = (1 - eta_v) * ideal flow
  C_leak = (1.0 - eta_v) * D_m / two_pi / (p_supply - p_return);
  Q_leak = C_leak * dp;

  // ===== Motor kinematics =====
  // Linear velocity v = (omega_m / gear_ratio) * r_pinion
  omega_m = v * gear_ratio / r_pinion;

  // ===== Motor torque and force =====
  T_motor = D_m / two_pi * dp;
  F_motor = T_motor * gear_ratio / r_pinion;

  // ===== Mechanical end stops (spring-damper) =====
  F_endstop = if x < 0.0 then (-k_endstop * x - c_endstop * v)
    else if x > travel_max then (-k_endstop * (x - travel_max) - c_endstop * v)
    else 0.0;

  // ===== External disturbance: 100 N during middle third of 14 s =====
  F_external = if (time >= 14.0 / 3.0 and time <= 2.0 * 14.0 / 3.0) then 100.0 else 0.0;

  // ===== Equation of motion =====
  m_table * der(v) = F_motor - b_vis * v + F_endstop - F_external;
  der(x) = v;

  // ===== Valve flow (pressure-compensated proportional) =====
  Q_a = u_cmd * Q_max;
  Q_b = -u_cmd * Q_max;

  // ===== Chamber pressure dynamics (fluid compressibility) =====
  // Chamber A: inflow from valve, outflow consumed by motor + leakage
  der(p_a) = beta_fluid / V_line * (Q_a - D_m * omega_m / two_pi - Q_leak);
  // Chamber B: outflow to return, inflow from motor + leakage
  der(p_b) = beta_fluid / V_line * (Q_b + D_m * omega_m / two_pi + Q_leak);

  // ===== Bounds assertions =====
  assert(x >= -0.05 and x <= travel_max + 0.05, "Position out of travel bounds");
  assert(p_a > 0.0 and p_a < p_supply * 1.5, "Chamber A pressure out of bounds");
  assert(p_b > 0.0 and p_b < p_supply * 1.5, "Chamber B pressure out of bounds");
  assert(abs(v) <= 5.0, "Velocity out of bounds");
  assert(tracking_err < 0.012 or time < 9.1, "Tracking error exceeds 0.012 m after 9.1 s");

algorithm
  // ===== Pressure-aware discrete PID controller at 200 Hz =====
  when sample(0, Ts) then
    // Anti-windup: hold integral when command is saturated
    if u_cmd >= 1.0 and pos_err > 0.0 then
      integ := integ;
    elseif u_cmd <= -1.0 and pos_err < 0.0 then
      integ := integ;
    else
      integ := integ + Ts * pos_err;
    end if;

    // PID output with pressure-differential feedback (pressure-aware)
    u_pid := Kp * pos_err + Ki * integ + Kd * (pos_err - err_prev) / Ts
             - K_press * dp / (p_supply - p_return);

    // Saturate valve command to [-1, 1]
    u_cmd := max(-1.0, min(1.0, u_pid));

    err_prev := pos_err;
  end when;

  annotation(
    experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "HydMotorPositionD: Hydraulic motor position control system.
      Motor: 48 cm3/rev, eta_v=0.92, 12:1 gearbox, 130 kg rotary table.
      Valve: pressure-compensated proportional, max flow 0.002 m3/s.
      Control: pressure-aware PID at 200 Hz with anti-windup.
      Target: 70% of available travel. Disturbance: 100 N during middle third of 14 s.
      Assumed parameters (not stated in requirement): p_supply=200 bar, p_return=5 bar,
      beta=1.6 GPa, V_line=1 L, r_pinion=0.1 m, travel_max=1.0 m, b_vis=500 N.s/m,
      k_endstop=1e7 N/m, c_endstop=1e4 N.s/m.")
  );
end HydMotorPositionD;