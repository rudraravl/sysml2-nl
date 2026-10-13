model CableWinchPositionB
  "Electromechanical cable-winch actuator: move output to nonzero target and hold against gravity and load"

  // ===== Physical parameters (facts from requirement) =====
  parameter Real V_supply = 72.0 "Nominal motor supply voltage [V]";
  parameter Real V_max = 59.0 "Allowed command voltage magnitude [V]";
  parameter Real N = 45.0 "Gearbox ratio";
  parameter Real r_drum = 0.09 "Drum radius [m]";
  parameter Real m_payload = 140.0 "Payload mass [kg]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real x_max = 12.0 "Cable travel limit [m]";

  // ===== Assumed motor and drum parameters (not stated; chosen for physically consistent 72 V drive) =====
  parameter Real eta_g = 0.9 "Gearbox efficiency";
  parameter Real Ra = 0.2 "Armature resistance [ohm]";
  parameter Real La = 0.008 "Armature inductance [H]";
  parameter Real Ke = 0.15 "Back-EMF constant [V.s/rad]";
  parameter Real Kt = 0.15 "Torque constant [N.m/A]";
  parameter Real J_motor = 0.0001 "Motor inertia [kg.m2]";
  parameter Real J_drum = 0.02 "Drum inertia [kg.m2]";
  parameter Real b_motor = 0.0001 "Motor viscous friction [N.m.s/rad]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real Rth = 0.7 "Winding thermal resistance [K/W]";
  parameter Real Cth = 250.0 "Winding thermal capacitance [J/K]";
  parameter Real k_stop = 1.0e6 "End-stop spring stiffness [N/m]";
  parameter Real c_stop = 1.0e4 "End-stop damping [N.s/m]";

  // ===== Derived parameters =====
  parameter Real Kc = Kt * N * eta_g / r_drum "Current-to-cable-force gain [N/A]";
  parameter Real m_eff = m_payload + (J_drum + J_motor * N * N) / (r_drum * r_drum) "Effective mass [kg]";
  parameter Real b_ref = b_motor * N * N / (r_drum * r_drum) "Reflected viscous damping [N.s/m]";
  parameter Real i_ff = m_payload * g / Kc "Gravity feedforward current [A]";

  // ===== Disturbance (middle third of 10 s mission) =====
  parameter Real t_dist_start = 10.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * 10.0 / 3.0 "Disturbance end time [s]";
  parameter Real F_dist = 5.6 "Controlled output load disturbance [N]";

  // ===== Target =====
  parameter Real x_target = 2.0 "Nonzero target position [m]";

  // ===== Controller (cascaded current, speed, position; 100 Hz) =====
  parameter Real Ts = 0.01 "Controller sample period [s]";
  parameter Real Kp_pos = 3.0 "Position-loop gain";
  parameter Real v_lim = 0.5 "Speed command limit [m/s]";
  parameter Real Kp_spd = 40.0 "Speed-loop proportional gain";
  parameter Real Ki_spd = 120.0 "Speed-loop integral gain";
  parameter Real I_max = 45.0 "Current command limit [A]";
  parameter Real Kp_cur = 4.0 "Current-loop proportional gain";
  parameter Real Ki_cur = 200.0 "Current-loop integral gain";

  // ===== Bounds =====
  parameter Real I_bound = 55.0 "Current physical bound [A]";
  parameter Real T_bound = 100.0 "Winding temperature bound [degC]";
  parameter Real err_bound = 0.036 "Tracking-error bound after 6.5 s [m]";

  // ===== Continuous states =====
  Real x(start = 0.0, fixed = true) "Cable / output position [m]";
  Real v(start = 0.0, fixed = true) "Cable / output velocity [m/s]";
  Real i(start = 0.0, fixed = true) "Motor armature current [A]";
  Real T_w(start = T_amb, fixed = true) "Winding temperature [degC]";

  // ===== Discrete controller states =====
  Real v_ref_d(start = 0.0) "Speed command [m/s]";
  Real i_ref_d(start = 0.0) "Current command [A]";
  Real v_cmd_d(start = 0.0) "Voltage command [V]";
  Real integ_spd(start = 0.0) "Speed-loop integrator";
  Real integ_cur(start = 0.0) "Current-loop integrator";

  // ===== Signals =====
  Real v_cmd "Applied motor voltage [V]";
  Real F_gravity "Gravity force [N]";
  Real F_disturb "Disturbance force [N]";
  Real F_collision "End-stop contact force [N]";

  // ===== Sensors and traces =====
  Real sensor_current "Current sensor trace [A]";
  Real sensor_position "Position sensor trace [m]";
  Real sensor_velocity "Velocity sensor trace [m/s]";
  Real sensor_temperature "Temperature sensor trace [degC]";
  Real tracking_error "Position tracking error [m]";
  Real final_error "Final position error [m]";

equation
  // Forces on payload (upward positive)
  F_gravity = m_payload * g;
  F_disturb = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;
  F_collision = if x < 0.0 then (-k_stop * x - c_stop * min(v, 0.0))
    else if x > x_max then (-k_stop * (x - x_max) - c_stop * max(v, 0.0))
    else 0.0;

  // Mechanical dynamics reflected to payload
  der(x) = v;
  m_eff * der(v) = Kc * i - F_gravity - F_disturb + F_collision - b_ref * v;

  // Electrical dynamics (DC motor armature)
  v_cmd = v_cmd_d;
  La * der(i) = v_cmd - Ra * i - Ke * N * v / r_drum;

  // Lumped winding thermal dynamics
  Cth * der(T_w) = i * i * Ra - (T_w - T_amb) / Rth;

  // Synchronized sensor, state, and command traces
  sensor_current = i;
  sensor_position = x;
  sensor_velocity = v;
  sensor_temperature = T_w;
  tracking_error = x_target - x;
  final_error = x_target - x;

  // Bounds checks
  assert(abs(v_cmd) <= V_max + 1.0e-6, "Voltage bound violated");
  assert(abs(i) <= I_bound, "Current bound violated");
  assert(x >= -1.0e-3 and x <= x_max + 1.0e-3, "Travel bound violated");
  assert(time < 6.5 or abs(tracking_error) < err_bound, "Tracking error bound violated after 6.5 s");
  assert(T_w < T_bound, "Temperature bound violated");

  // ===== Discrete cascaded controller at 100 Hz with anti-windup =====
  when sample(0, Ts) then
    // Outer loop: position -> saturated speed command
    v_ref_d = if Kp_pos * (x_target - x) > v_lim then v_lim
      else if Kp_pos * (x_target - x) < -v_lim then -v_lim
      else Kp_pos * (x_target - x);

    // Middle loop: speed -> current command (PI + gravity feedforward, conditional-integration anti-windup)
    integ_spd = if abs(Kp_spd * (v_ref_d - v) + pre(integ_spd) + i_ff) <= I_max
      then pre(integ_spd) + Ki_spd * (v_ref_d - v) * Ts
      else pre(integ_spd);

    i_ref_d = if Kp_spd * (v_ref_d - v) + integ_spd + i_ff > I_max then I_max
      else if Kp_spd * (v_ref_d - v) + integ_spd + i_ff < -I_max then -I_max
      else Kp_spd * (v_ref_d - v) + integ_spd + i_ff;

    // Inner loop: current -> voltage command (PI, conditional-integration anti-windup)
    integ_cur = if abs(Kp_cur * (i_ref_d - i) + pre(integ_cur)) <= V_max
      then pre(integ_cur) + Ki_cur * (i_ref_d - i) * Ts
      else pre(integ_cur);

    v_cmd_d = if Kp_cur * (i_ref_d - i) + integ_cur > V_max then V_max
      else if Kp_cur * (i_ref_d - i) + integ_cur < -V_max then -V_max
      else Kp_cur * (i_ref_d - i) + integ_cur;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1.0e-6, Interval = 0.01),
    Documentation(info = "CableWinchPositionB: cascaded current/speed/position control with anti-windup "
      "driving a 72 V DC motor through a 45:1 gearbox and 0.09 m drum lifting a 140 kg payload "
      "over a 12 m travel. A 5.6 N output load disturbance is injected during the middle third "
      "of the 10 s mission. Motor electrical and inertial parameters are assumed where not stated."));
end CableWinchPositionB;