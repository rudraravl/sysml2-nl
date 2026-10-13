model CableWinchPositionC
  // Supply and limits
  parameter Real V_supply = 72.0 "Motor supply voltage (V)";
  parameter Real V_max = 66.2 "Maximum command magnitude (V)";

  // Mechanical plant
  parameter Real N_gear = 45.0 "Gearbox ratio";
  parameter Real r_drum = 0.09 "Drum radius (m)";
  parameter Real m_payload = 140.0 "Payload mass (kg)";
  parameter Real L_travel = 12.0 "Cable travel distance (m)";
  parameter Real g = 9.81 "Gravitational acceleration (m/s2)";

  // Motor electrical parameters (assumed; not stated in requirement)
  parameter Real R_motor = 1.2 "Motor winding resistance (Ohm)";
  parameter Real L_motor = 0.005 "Motor winding inductance (H)";
  parameter Real Kt = 0.25 "Motor torque constant (N.m/A)";
  parameter Real Ke = 0.25 "Motor back-EMF constant (V.s/rad)";
  parameter Real J_motor = 0.002 "Motor rotor inertia (kg.m2)";
  parameter Real J_drum = 0.05 "Drum inertia (kg.m2)";
  parameter Real eta_gear = 0.92 "Gearbox efficiency";

  // Collision and limits
  parameter Real k_collision = 1.0e5 "Collision spring stiffness at travel limits (N/m)";
  parameter Real b_collision = 1.0e3 "Collision damping coefficient (N.s/m2)";

  // Thermal model (assumed; not stated in requirement)
  parameter Real T_ambient = 20.0 "Ambient temperature (degC)";
  parameter Real C_th = 800.0 "Winding thermal capacitance (J/K)";
  parameter Real R_th = 0.04 "Thermal resistance (K/W)";

  // Controller gains
  parameter Real Kp_pos = 1.5 "Position controller gain (1/s)";
  parameter Real v_max = 3.0 "Maximum payload speed command (m/s)";
  parameter Real Kp_spd = 1.0 "Speed controller proportional gain (A.s/rad)";
  parameter Real Ki_spd = 10.0 "Speed controller integral gain (A/rad)";
  parameter Real Kp_cur = 10.0 "Current controller proportional gain (V/A)";
  parameter Real Ki_cur = 300.0 "Current controller integral gain (V/(A.s))";
  parameter Real Kaw = 1.0 "Anti-windup feedback gain";
  parameter Real i_max = 30.0 "Maximum current command (A)";

  // Setpoint and disturbance
  parameter Real x_target = 8.0 "Target position (m)";
  parameter Real T_dist = 7.2 "Output load disturbance (N.m at drum)";

  // Sampling
  parameter Real Ts = 1.0 / 125.0 "Controller sample time (s)";

  // Derived constants
  parameter Real J_eff = J_motor + J_drum / (N_gear ^ 2) + m_payload * r_drum ^ 2 / (N_gear ^ 2)
    "Effective inertia at motor shaft (kg.m2)";
  parameter Real omega_max = v_max * N_gear / r_drum
    "Maximum motor angular velocity (rad/s)";

  // Continuous plant states
  Real i_motor(start = 0.0) "Motor current (A)";
  Real omega_motor(start = 0.0) "Motor angular velocity (rad/s)";
  Real theta_motor(start = 0.0) "Motor angle (rad)";
  Real T_winding(start = T_ambient) "Winding temperature (degC)";

  // Discrete controller states
  discrete Real spd_int(start = 0.0) "Speed loop integrator (A)";
  discrete Real cur_int(start = 0.0) "Current loop integrator (V)";

  // Discrete controller signals
  discrete Real err_pos(start = 0.0) "Position error at sample (m)";
  discrete Real omega_ref_unsat(start = 0.0) "Unsaturated speed reference (rad/s)";
  discrete Real omega_ref(start = 0.0) "Saturated speed reference (rad/s)";
  discrete Real err_spd(start = 0.0) "Speed error at sample (rad/s)";
  discrete Real i_ref_unsat(start = 0.0) "Unsaturated current reference (A)";
  discrete Real i_ref(start = 0.0) "Saturated current reference (A)";
  discrete Real aw_cur(start = 0.0) "Current anti-windup signal (A)";
  discrete Real err_cur(start = 0.0) "Current error at sample (A)";
  discrete Real V_cmd(start = 0.0) "Unsaturated voltage command (V)";
  discrete Real V_sat_d(start = 0.0) "Saturated voltage command (V)";
  discrete Real aw_volt(start = 0.0) "Voltage anti-windup signal (V)";

  // Sensors
  Real x_meas "Measured output position (m)";
  Real v_meas "Measured output velocity (m/s)";
  Real i_meas "Measured current (A)";
  Real T_meas "Measured winding temperature (degC)";

  // Derived physical quantities
  Real V_sat "Continuous saturated voltage applied to motor (V)";
  Real T_motor "Motor torque (N.m)";
  Real T_cable "Cable tension (N)";
  Real T_dist_applied "Disturbance torque applied at drum (N.m)";
  Real F_collision "Collision force at travel limits (N)";
  Real T_collision_motor "Collision torque reflected to motor (N.m)";
  Real tracking_error "Position tracking error (m)";
  Real final_error "Absolute tracking error after 7.8 s (m)";

  // Bound variables
  Real V_bound "Voltage magnitude (V)";
  Real i_bound "Current magnitude (A)";
  Real x_bound "Payload travel (m)";
  Real T_bound "Winding temperature (degC)";

equation
  // Disturbance injection during middle third (4 s to 8 s)
  T_dist_applied = if (time >= 4.0 and time <= 8.0) then T_dist else 0.0;

  // Motor electrical dynamics
  L_motor * der(i_motor) = V_sat - R_motor * i_motor - Ke * omega_motor;
  T_motor = Kt * i_motor;

  // Collision force at travel limits (spring-damper, positive = upward)
  F_collision = k_collision * (max(0.0, -x_meas) - max(0.0, x_meas - L_travel))
              + b_collision * (max(0.0, -x_meas) * (-v_meas) - max(0.0, x_meas - L_travel) * v_meas);
  T_collision_motor = F_collision * r_drum / N_gear;

  // Lumped mechanical dynamics at motor shaft
  J_eff * der(omega_motor) = T_motor
    - m_payload * g * r_drum / N_gear
    - T_dist_applied / N_gear
    + T_collision_motor;
  der(theta_motor) = omega_motor;

  // Output kinematics
  x_meas = r_drum * theta_motor / N_gear;
  v_meas = r_drum * omega_motor / N_gear;

  // Sensors
  i_meas = i_motor;
  T_meas = T_winding;

  // Cable tension (proportional to motor torque through gearbox)
  T_cable = T_motor * N_gear * eta_gear / r_drum;

  // Winding thermal dynamics
  C_th * der(T_winding) = i_motor ^ 2 * R_motor - (T_winding - T_ambient) / R_th;

  // Tracking and error metrics
  tracking_error = x_target - x_meas;
  final_error = if time >= 7.8 then abs(tracking_error) else 0.0;

  // Bound observables
  V_bound = abs(V_sat);
  i_bound = abs(i_motor);
  x_bound = x_meas;
  T_bound = T_winding;

  // Hold discrete voltage between samples
  V_sat = V_sat_d;

  // Discrete cascaded controller at 125 Hz
  when sample(0, Ts) then
    // Outer: position controller (error -> motor speed reference)
    err_pos = x_target - x_meas;
    omega_ref_unsat = Kp_pos * err_pos * N_gear / r_drum;
    omega_ref = max(-omega_max, min(omega_max, omega_ref_unsat));

    // Middle: speed controller with current anti-windup
    err_spd = omega_ref - omega_motor;
    i_ref_unsat = Kp_spd * err_spd + pre(spd_int);
    i_ref = max(-i_max, min(i_max, i_ref_unsat));
    aw_cur = i_ref_unsat - i_ref;
    spd_int = pre(spd_int) + Ts * (Ki_spd * err_spd - Kaw * aw_cur);

    // Inner: current controller with voltage anti-windup
    err_cur = i_ref - i_motor;
    V_cmd = Kp_cur * err_cur + pre(cur_int);
    V_sat_d = max(-V_max, min(V_max, V_cmd));
    aw_volt = V_cmd - V_sat_d;
    cur_int = pre(cur_int) + Ts * (Ki_cur * err_cur - Kaw * aw_volt);
  end when;

  // Boundary checks
  assert(V_bound <= V_max + 0.5, "Voltage command bound exceeded");
  assert(i_bound <= i_max + 5.0, "Current bound exceeded");
  assert(x_bound >= -0.05 and x_bound <= L_travel + 0.05, "Travel bound exceeded");
  assert(T_bound <= 120.0, "Temperature bound exceeded");
  assert(final_error <= 0.032, "Final tracking error bound (0.032 m) exceeded after 7.8 s");

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 1.0 / 125.0),
    Documentation(info = "CableWinchPositionC: Cascaded current/position control of a cable winch lifting a 140 kg payload. Motor electrical and thermal parameters are assumed values not specified in the requirement."));
end CableWinchPositionC;