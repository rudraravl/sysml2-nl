model DCServoPositionC
  "DC servo position control: cascaded current and position PI with anti-windup"

  // --- Motor electrical parameters (48 V PMDC motor) ---
  parameter Real R = 2.5 "Winding resistance (Ohm)";
  parameter Real L = 0.01 "Winding inductance (H)";
  parameter Real Kt = 0.05 "Torque constant (N.m/A)";
  parameter Real Ke = 0.05 "Back-EMF constant (V.s/rad)";

  // --- Motor mechanical parameters ---
  parameter Real J_motor = 1.0e-4 "Rotor inertia (kg.m2)";
  parameter Real b_motor = 1.0e-3 "Rotor viscous friction (N.m.s/rad)";

  // --- Gearbox ---
  parameter Real gearRatio = 100.0 "Gearbox ratio";

  // --- Link / driven rigid body ---
  parameter Real J_link = 0.1 "Link inertia at output (kg.m2)";
  parameter Real b_link = 0.01 "Link viscous friction (N.m.s/rad)";
  parameter Real gravityCoeff = 2.0 "Gravity torque coefficient (N.m)";
  parameter Real theta_limit = 3.14159 "Mechanical travel limit (rad)";
  parameter Real k_collision = 1.0e4 "Collision stiffness (N.m/rad)";
  parameter Real d_collision = 10.0 "Collision damping (N.m.s/rad)";

  // --- Thermal state ---
  parameter Real C_th = 50.0 "Thermal capacitance (J/K)";
  parameter Real R_th = 2.0 "Thermal resistance (K/W)";
  parameter Real T_amb = 25.0 "Ambient temperature (degC)";

  // --- Control parameters ---
  parameter Real V_max = 44.2 "Maximum voltage command magnitude (V)";
  parameter Real I_max = 15.0 "Maximum current command magnitude (A)";
  parameter Real Kp_pos = 20.0 "Position loop proportional gain";
  parameter Real Ki_pos = 50.0 "Position loop integral gain";
  parameter Real Kp_vel = 0.1 "Velocity damping gain in position loop";
  parameter Real Kp_cur = 3.0 "Current loop proportional gain";
  parameter Real Ki_cur = 200.0 "Current loop integral gain";
  parameter Real aw_gain = 1.0 "Anti-windup back-calculation gain";

  // --- Reference and disturbance ---
  parameter Real theta_ref = 1.0 "Target output position (rad)";
  parameter Real tau_dist = 7.2 "Load disturbance magnitude (N.m)";
  parameter Real t_dist_start = 4.0 "Disturbance start time (s)";
  parameter Real t_dist_end = 8.0 "Disturbance end time (s)";
  parameter Real Ts = 0.008 "Sample period for 125 Hz operation (s)";
  parameter Real t_sim = 12.0 "Simulation duration (s)";
  parameter Real T_limit = 100.0 "Temperature bound (degC)";
  parameter Real e_bound = 0.032 "Tracking error bound after 7.8 s (rad)";

  // --- Effective reflected parameters (motor side) ---
  Real J_eff = J_motor + J_link / (gearRatio * gearRatio)
    "Effective inertia at motor (kg.m2)";
  Real b_eff = b_motor + b_link / (gearRatio * gearRatio)
    "Effective friction at motor (N.m.s/rad)";

  // --- Physical states ---
  Real i(start = 0.0, fixed = true) "Motor current (A)";
  Real omega_motor(start = 0.0, fixed = true) "Motor angular velocity (rad/s)";
  Real theta_motor(start = 0.0, fixed = true) "Motor angle (rad)";
  Real T_winding(start = T_amb, fixed = true) "Winding temperature (degC)";

  // --- Controller integrator states ---
  Real pos_int(start = 0.0, fixed = true) "Position loop integrator";
  Real cur_int(start = 0.0, fixed = true) "Current loop integrator";

  // --- Derived mechanical quantities ---
  Real omega_out "Output angular velocity (rad/s)";
  Real theta_out "Output position (rad)";
  Real tau_motor "Motor electromagnetic torque (N.m)";
  Real tau_gravity "Gravity torque at output (N.m)";
  Real tau_load "Load disturbance at output (N.m)";
  Real tau_collision "Collision torque at output (N.m)";
  Real back_emf "Back-EMF voltage (V)";
  Real tau_net_out "Net torque at output side (N.m)";

  // --- Controller signals ---
  Real e_pos "Position error (rad)";
  Real i_cmd_unsat "Unsaturated current command (A)";
  Real i_cmd "Saturated current command (A)";
  Real e_cur "Current error (A)";
  Real V_cmd_unsat "Unsaturated voltage command (V)";
  Real V_cmd "Saturated voltage command (V)";
  Real aw_pos "Anti-windup correction (position loop) (A)";
  Real aw_cur "Anti-windup correction (current loop) (V)";

  // --- Monitoring / evidence ---
  Real tracking_error "Absolute position tracking error (rad)";
  Boolean voltage_ok "Voltage within bound";
  Boolean current_ok "Current within bound";
  Boolean travel_ok "Travel within limit";
  Boolean temperature_ok "Temperature within bound";
  Boolean tracking_ok "Tracking error below threshold after 7.8 s";

equation
  // --- Electrical dynamics ---
  L * der(i) = V_cmd - R * i - back_emf;
  back_emf = Ke * omega_motor;

  // --- Mechanical dynamics (combined, reflected to motor side) ---
  J_eff * der(omega_motor) = tau_motor - b_eff * omega_motor
    - (tau_gravity + tau_load + tau_collision) / gearRatio;
  der(theta_motor) = omega_motor;

  // --- Output kinematics ---
  omega_out = omega_motor / gearRatio;
  theta_out = theta_motor / gearRatio;

  // --- Torques ---
  tau_motor = Kt * i;
  tau_gravity = gravityCoeff * Modelica.Math.cos(theta_out);

  // --- Load disturbance: 7.2 N.m during middle third (4 s to 8 s) ---
  if time >= t_dist_start and time <= t_dist_end then
    tau_load = tau_dist;
  else
    tau_load = 0.0;
  end if;

  // --- Collision / physical limits (spring-damper at travel bounds) ---
  tau_collision = k_collision * (max(0.0, theta_out - theta_limit)
    - max(0.0, -theta_limit - theta_out))
    + d_collision * (max(0.0, omega_out) * max(0.0, theta_out - theta_limit) / (abs(theta_out - theta_limit) + 1.0e-6)
    - max(0.0, -omega_out) * max(0.0, -theta_limit - theta_out) / (abs(theta_out + theta_limit) + 1.0e-6));

  // --- Thermal model ---
  C_th * der(T_winding) = R * i * i - (T_winding - T_amb) / R_th;

  // ===============================
  // Cascaded position controller (outer loop)
  // ===============================
  e_pos = theta_ref - theta_out;
  i_cmd_unsat = Kp_pos * e_pos - Kp_vel * omega_out + pos_int;
  i_cmd = max(-I_max, min(I_max, i_cmd_unsat));
  aw_pos = i_cmd_unsat - i_cmd;
  der(pos_int) = Ki_pos * e_pos - aw_gain * Ki_pos * aw_pos;

  // ===============================
  // Cascaded current controller (inner loop)
  // ===============================
  e_cur = i_cmd - i;
  V_cmd_unsat = Kp_cur * e_cur + cur_int;
  V_cmd = max(-V_max, min(V_max, V_cmd_unsat));
  aw_cur = V_cmd_unsat - V_cmd;
  der(cur_int) = Ki_cur * e_cur - aw_gain * Ki_cur * aw_cur;

  // --- Net output torque for observation ---
  tau_net_out = tau_motor * gearRatio - tau_gravity - tau_load - tau_collision
    - b_link * omega_out;

  // --- Monitoring / bounds ---
  tracking_error = abs(theta_ref - theta_out);
  voltage_ok = abs(V_cmd) <= V_max + 1e-6;
  current_ok = abs(i) <= I_max + 0.1;
  travel_ok = abs(theta_out) <= theta_limit + 1e-3;
  temperature_ok = T_winding <= T_limit;
  tracking_ok = if time >= 7.8 then tracking_error < e_bound else true;

end DCServoPositionC;