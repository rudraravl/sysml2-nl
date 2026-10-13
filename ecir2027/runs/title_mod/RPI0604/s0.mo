model HydCylinderPositionD
  "Instrumented hydraulic cylinder position control system - move to 70% stroke and hold"

  // === Physical parameters ===
  parameter Modelica.Units.SI.Area A_p = 0.0040 "Piston (cap-side) area";
  parameter Modelica.Units.SI.Area A_r = 0.0032 "Rod area";
  parameter Modelica.Units.SI.Area A_a = A_p - A_r "Annular (rod-side) area";
  parameter Modelica.Units.SI.Length L = 0.50 "Cylinder stroke";
  parameter Modelica.Units.SI.Mass m_m = 110.0 "Moving mass";
  parameter Modelica.Units.SI.Pressure p_s = 20.0e5 "Declared supply pressure";
  parameter Modelica.Units.SI.Pressure p_t = 1.0e5 "Declared return/tank pressure";
  parameter Modelica.Units.SI.VolumeFlowRate Q_max = 0.001 "Valve max volumetric flow";
  parameter Modelica.Units.SI.Pressure beta_e = 1.0e8 "Effective fluid bulk modulus (compressibility)";
  parameter Real C_leak = 1.0e-13 "Internal leakage coefficient [m3/(s*Pa)]";
  parameter Real b_visc = 3000.0 "Viscous friction coefficient [N*s/m]";
  parameter Real F_Coulomb = 20.0 "Coulomb friction magnitude [N]";
  parameter Modelica.Units.SI.Volume V_dead = A_p * 0.01 "Dead volume per chamber";
  parameter Real k_stop = 1.0e6 "End-stop spring stiffness [N/m]";

  // === Target ===
  parameter Modelica.Units.SI.Length x_target = 0.70 * L "Target position: 70% of stroke";

  // === Controller parameters ===
  parameter Real Kp = 50.0 "PID proportional gain";
  parameter Real Ki = 400.0 "PID integral gain";
  parameter Real Kd = 5.0 "PID derivative gain";
  parameter Real K_pres = 5.0e-5 "Pressure-difference feedback gain (pressure-aware control)";
  parameter Modelica.Units.SI.Time Ts = 0.005 "Control sample period (200 Hz)";
  parameter Real u_sat = 1.0 "Valve command saturation limit";
  parameter Real int_limit = 0.5 "Integral anti-windup limit";

  // === Disturbance ===
  parameter Modelica.Units.SI.Force F_ext = 100.0 "External load disturbance magnitude";
  parameter Modelica.Units.SI.Time t_sim = 14.0 "Total simulation duration";
  parameter Modelica.Units.SI.Time t_dist_on = t_sim / 3.0 "Disturbance onset (middle third)";
  parameter Modelica.Units.SI.Time t_dist_off = 2.0 * t_sim / 3.0 "Disturbance end (middle third)";

  // === Continuous dynamic states ===
  Modelica.Units.SI.Length x(start = 0.0, fixed = true) "Piston position";
  Modelica.Units.SI.Velocity v(start = 0.0, fixed = true) "Piston velocity";
  Modelica.Units.SI.Pressure p_a(start = 3.0e5, fixed = true) "Cap-side chamber pressure";
  Modelica.Units.SI.Pressure p_b(start = 1.5e6, fixed = true) "Rod-side chamber pressure";

  // === Discrete control states ===
  Real error_int(start = 0.0, fixed = true) "Integrated position error (anti-windup)";
  Real e_prev(start = 0.0, fixed = true) "Previous sample position error";
  Real u_cmd(start = 0.0, fixed = true) "Valve command [-1, 1]";
  Real u_raw "Unsaturated valve command";
  Real e_rate "Discrete error rate";

  // === Computed quantities ===
  Modelica.Units.SI.Volume V_a "Cap-side chamber volume";
  Modelica.Units.SI.Volume V_b "Rod-side chamber volume";
  Modelica.Units.SI.VolumeFlowRate Q_a "Flow into cap side";
  Modelica.Units.SI.VolumeFlowRate Q_b "Flow from rod side";
  Modelica.Units.SI.VolumeFlowRate Q_leak "Internal leakage flow";
  Modelica.Units.SI.Force F_hyd "Net hydraulic force";
  Modelica.Units.SI.Force F_fric "Friction force";
  Modelica.Units.SI.Force F_dist "External disturbance force";
  Modelica.Units.SI.Force F_stop "End-stop reaction force";
  Real e_pos "Position error";

  // === Sensor measurements ===
  Modelica.Units.SI.Length y_position "Measured actuator position";
  Modelica.Units.SI.Velocity y_velocity "Measured actuator velocity";
  Modelica.Units.SI.Pressure y_pressure_a "Measured cap-side chamber pressure";
  Modelica.Units.SI.Pressure y_pressure_b "Measured rod-side chamber pressure";
  Real y_valve_command "Measured valve command";
  Real y_tracking_error "Tracking error magnitude";

equation
  // Chamber volumes with dead volume (prevents singular zero-volume at endpoints)
  V_a = A_p * x + V_dead;
  V_b = A_a * (L - x) + V_dead;

  // Internal leakage across piston seal (proportional to pressure difference)
  Q_leak = C_leak * (p_a - p_b);

  // Four-way proportional valve: linear metering
  // u > 0: supply -> cap, rod -> tank (extend); u < 0: reverse (retract)
  Q_a = u_cmd * Q_max;
  Q_b = u_cmd * Q_max;

  // Pressure dynamics with fluid compressibility (bulk modulus)
  der(p_a) = (beta_e / V_a) * (Q_a - A_p * v - Q_leak);
  der(p_b) = (beta_e / V_b) * (-Q_b + A_a * v + Q_leak);

  // Net hydraulic force on piston
  F_hyd = p_a * A_p - p_b * A_a;

  // Friction: viscous + smooth Coulomb (tanh avoids discontinuity at v=0)
  F_fric = b_visc * v + F_Coulomb * Modelica.Math.tanh(v / 0.01);

  // External disturbance: 100 N during middle third of simulation
  F_dist = if (time >= t_dist_on and time <= t_dist_off) then F_ext else 0.0;

  // Mechanical end stops: stiff spring beyond physical travel limits
  F_stop = if x < 0.0 then k_stop * (-x) elseif x > L then -k_stop * (x - L) else 0.0;

  // Mechanical dynamics (Newton's second law)
  m_m * der(v) = F_hyd - F_fric - F_dist - F_stop;
  der(x) = v;

  // Position error
  e_pos = x_target - x;

  // === Pressure-aware PID control at 200 Hz ===
  when sample(0, Ts) then
    // Integral with anti-windup clamp
    error_int = max(-int_limit, min(int_limit, pre(error_int) + e_pos * Ts));
    // Discrete derivative of error
    e_rate = (e_pos - pre(e_prev)) / Ts;
    // PID + pressure-difference feedback for active damping
    u_raw = Kp * e_pos + Ki * error_int + Kd * e_rate - K_pres * (p_a - p_b);
    // Saturate valve command
    u_cmd = if u_raw > u_sat then u_sat elseif u_raw < -u_sat then -u_sat else u_raw;
    // Store error for next sample
    e_prev = e_pos;
  end when;

  // === Sensor outputs ===
  y_position = x;
  y_velocity = v;
  y_pressure_a = p_a;
  y_pressure_b = p_b;
  y_valve_command = u_cmd;
  y_tracking_error = abs(e_pos);

  // === Bounds and assertions ===
  // Travel bounds
  assert(x >= -0.005 and x <= L + 0.005, "Position exceeds travel bounds");
  // Valve command bounds
  assert(abs(u_cmd) <= u_sat + 1.0e-6, "Valve command exceeds bounds");
  // Pressure bounds (referenced to declared supply and return)
  assert(p_a >= 0.0 and p_a <= 3.0 * p_s, "Cap-side pressure out of bounds");
  assert(p_b >= 0.0 and p_b <= 3.0 * p_s, "Rod-side pressure out of bounds");
  // Velocity bounds
  assert(abs(v) <= 1.0, "Velocity out of bounds");
  // Final-position / tracking bound: error below 0.012 m after 9.1 s
  assert(time < 9.1 or abs(e_pos) < 0.012, "Tracking error exceeds 0.012 m after 9.1 s");
  // NaN / Inf detection (NaN does not equal itself)
  assert(x == x, "NaN detected in position");
  assert(v == v, "NaN detected in velocity");
  assert(p_a == p_a, "NaN detected in cap pressure");
  assert(p_b == p_b, "NaN detected in rod pressure");
  assert(u_cmd == u_cmd, "NaN detected in valve command");

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-5, Interval = 0.005),
    uses(Modelica(version = "4.0.0"))
  );
end HydCylinderPositionD;