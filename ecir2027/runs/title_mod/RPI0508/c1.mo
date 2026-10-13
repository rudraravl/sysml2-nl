model BLDCWheelPositionD
  "Instrumented 48V three-phase PM motor, 9:1 gearbox, 0.12m wheel, cascaded position/current control with anti-windup, 8N load disturbance in middle third, 200Hz, 14s."

  // Requirement-derived constants
  parameter Real V_oc(unit="V") = 48.0 "open-circuit battery/bus voltage";
  parameter Integer p = 4 "motor pole pairs";
  parameter Real d_wheel(unit="m") = 0.12 "wheel diameter";
  parameter Real r_wheel(unit="m") = 0.06 "wheel radius = d_wheel/2";
  parameter Real n_gear = 9.0 "gearbox ratio motor:wheel";
  parameter Real Ts(unit="s") = 0.005 "control period, 200 Hz";
  parameter Real F_load_amp(unit="N") = 8.0 "output load disturbance amplitude";
  parameter Real t_load_start(unit="s") = 14.0/3.0 "middle third start";
  parameter Real t_load_stop(unit="s") = 28.0/3.0 "middle third stop";
  parameter Real x_target(unit="m") = 1.0 "nonzero output position command";
  parameter Real t_ramp(unit="s") = 3.0 "command ramp time";
  parameter Real t_error_check(unit="s") = 9.1 "tracking error check time";
  parameter Real e_bound(unit="m") = 0.03 "tracking and final error bound";

  // Plant parameters (representative; facts not stated in requirement are unknown)
  parameter Real R_w(unit="Ohm") = 0.2 "winding resistance per phase";
  parameter Real L_q(unit="H") = 0.005 "q-axis inductance";
  parameter Real psi_m(unit="Wb") = 0.05 "magnet flux linkage";
  parameter Real R_batt(unit="Ohm") = 0.05 "battery internal resistance";
  parameter Real m_carriage(unit="kg") = 5.0 "driven rigid carriage mass";
  parameter Real b_track(unit="N.s/m") = 0.1 "track damping";
  parameter Real x_min(unit="m") = 0.0 "travel lower limit";
  parameter Real x_max(unit="m") = 2.0 "travel upper limit";
  parameter Real k_stop(unit="N/m") = 1.0e4 "collision stiffness";
  parameter Real T_amb(unit="K") = 293.15 "ambient winding temperature";
  parameter Real C_th(unit="J/K") = 100.0 "winding thermal capacitance";
  parameter Real R_th(unit="K/W") = 2.0 "winding thermal resistance";
  parameter Real I_limit(unit="A") = 4.0 "controller current limit";
  parameter Real I_bound(unit="A") = 6.0 "current measurement bound";
  parameter Real T_max(unit="K") = 353.15 "temperature bound";

  // Controller gains
  parameter Real Kp_pos(unit="A/m") = 30.0 "position proportional gain";
  parameter Real Ki_pos(unit="A/(m.s)") = 48.0 "position integral gain";
  parameter Real Kd_pos(unit="A.s/m") = 4.0 "position derivative gain";
  parameter Real Kp_i(unit="V/A") = 0.5 "current proportional gain";
  parameter Real Ki_i(unit="V/(A.s)") = 40.0 "current integral gain";

  constant Real PI = 3.141592653589793;

  // Continuous states
  Real x(start=0.0, unit="m") "carriage output position";
  Real v(start=0.0, unit="m/s") "carriage output velocity";
  Real i_q(start=0.0, unit="A") "q-axis current";
  Real T_w(start=293.15, unit="K") "winding temperature";
  Real theta_e(start=0.0, unit="rad") "electrical angle";

  // Discrete control states
  discrete Real posInt(start=0.0) "position integral with anti-windup";
  discrete Real curInt(start=0.0) "current integral with anti-windup";
  discrete Real i_ref_unsat(start=0.0, unit="A") "unlimited current command";
  discrete Real i_ref_sat(start=0.0, unit="A") "limited current command";
  discrete Real v_cmd_unsat(start=0.0, unit="V") "unlimited voltage command";
  discrete Real v_cmd(start=0.0, unit="V") "limited voltage command";

  // Derived physical quantities
  Real theta_wheel(unit="rad") "wheel angle";
  Real omega_wheel(unit="rad/s") "wheel angular velocity";
  Real theta_motor(unit="rad") "motor angle";
  Real omega_motor(unit="rad/s") "motor angular velocity";
  Real omega_e(unit="rad/s") "electrical angular velocity";
  Real torque_motor(unit="N.m") "motor torque";
  Real F_drive(unit="N") "drive force at wheel";
  Real F_track(unit="N") "track damping force";
  Real i_dc(unit="A") "DC bus current";
  Real V_bus(unit="V") "DC bus voltage";
  Real F_load(unit="N") "load disturbance force";
  Real F_stop(unit="N") "collision/limit force";
  Real i_a(unit="A") "phase a current";
  Real i_b(unit="A") "phase b current";
  Real i_c(unit="A") "phase c current";

  // Commands, errors, sensors
  Real x_ref(unit="m") "position command";
  Real e_pos(unit="m") "position error";
  Real e_track(unit="m") "tracking error";
  Real final_error(unit="m") "final position error";
  Real i_meas(unit="A") "measured current";
  Real x_meas(unit="m") "measured position";
  Real v_meas(unit="m/s") "measured velocity";
  Real T_meas(unit="K") "measured winding temperature";

  // Bound indicators
  Real voltage_ok;
  Real current_ok;
  Real travel_ok;
  Real temperature_ok;
  Real tracking_ok;
  Real final_error_ok;

equation
  // Smooth nonzero position command and hold
  if time <= t_ramp then
    x_ref = 0.5*x_target*(1.0 - cos(PI*time/t_ramp));
  else
    x_ref = x_target;
  end if;

  e_pos = x_ref - x;
  e_track = e_pos;
  final_error = x_target - x;

  // Measurements
  x_meas = x;
  v_meas = v;
  T_meas = T_w;

  // Battery with internal resistance
  i_dc = abs(i_q);
  V_bus = V_oc - R_batt*i_dc;

  // Output load disturbance during middle third
  if time >= t_load_start and time < t_load_stop then
    F_load = F_load_amp;
  else
    F_load = 0.0;
  end if;

  // Collision and physical travel limits
  if x < x_min then
    F_stop = k_stop*(x_min - x);
  elseif x > x_max then
    F_stop = -k_stop*(x - x_max);
  else
    F_stop = 0.0;
  end if;

  // Mechanical rigid body
  der(x) = v;
  m_carriage*der(v) = F_drive - F_load - F_track - F_stop;

  // Kinematic relationships
  theta_wheel = x/r_wheel;
  omega_wheel = v/r_wheel;
  theta_motor = n_gear*theta_wheel;
  omega_motor = n_gear*omega_wheel;
  omega_e = p*omega_motor;
  torque_motor = p*psi_m*i_q;
  F_drive = torque_motor*n_gear/r_wheel;
  F_track = b_track*v;

  // FOC q-axis electrical dynamics with back-EMF
  L_q*der(i_q) = v_cmd - R_w*i_q - psi_m*omega_e;
  der(theta_e) = omega_e;

  // Winding temperature dynamics
  C_th*der(T_w) = R_w*i_q*i_q - (T_w - T_amb)/R_th;

  // Representative three-phase currents
  i_a = i_q*cos(theta_e);
  i_b = i_q*cos(theta_e - 2.0*PI/3.0);
  i_c = i_q*cos(theta_e + 2.0*PI/3.0);

  // Current measurement
  i_meas = max(abs(i_a), max(abs(i_b), abs(i_c)));

  // Bound indicators
  voltage_ok = if abs(v_cmd) <= V_oc + 1.0e-6 then 1.0 else 0.0;
  current_ok = if abs(i_meas) <= I_bound + 1.0e-6 then 1.0 else 0.0;
  travel_ok = if x >= x_min - 1.0e-6 and x <= x_max + 1.0e-6 then 1.0 else 0.0;
  temperature_ok = if T_w <= T_max + 1.0e-6 then 1.0 else 0.0;
  tracking_ok = if time >= t_error_check then (if abs(e_track) <= e_bound then 1.0 else 0.0) else 1.0;
  final_error_ok = if abs(final_error) <= e_bound then 1.0 else 0.0;

  // Requirement bounds
  assert(noEvent(abs(v_cmd) <= V_oc + 1.0e-6), "voltage bound exceeded");
  assert(noEvent(abs(i_meas) <= I_bound + 1.0e-6), "current bound exceeded");
  assert(noEvent(x >= x_min - 1.0e-6 and x <= x_max + 1.0e-6), "travel bound exceeded");
  assert(noEvent(T_w <= T_max + 1.0e-6), "temperature bound exceeded");
  assert(noEvent(time < t_error_check or abs(e_track) <= e_bound), "primary tracking error after 9.1 s exceeded");
  assert(noEvent(abs(x) < 1.0e6 and abs(v) < 1.0e6 and abs(i_q) < 1.0e6 and abs(T_w) < 1.0e6 and abs(theta_e) < 1.0e6 and abs(v_cmd) < 1.0e6), "finite value check failed");

algorithm
  // Cascaded position and current control at 200 Hz with clamping anti-windup
  when sample(0, Ts) then
    // Outer position loop -> current command
    i_ref_unsat := Kp_pos*e_pos + Ki_pos*pre(posInt) - Kd_pos*v;
    i_ref_sat := max(-I_limit, min(I_limit, i_ref_unsat));
    posInt := if (abs(i_ref_unsat) > I_limit and e_pos*i_ref_unsat > 0.0) then pre(posInt) else pre(posInt) + Ts*e_pos;

    // Inner current loop -> voltage command, limited to DC bus voltage
    v_cmd_unsat := psi_m*omega_e + Kp_i*(i_ref_sat - i_q) + Ki_i*pre(curInt);
    v_cmd := max(-V_oc, min(V_oc, v_cmd_unsat));
    curInt := if (abs(v_cmd_unsat) > V_oc and (i_ref_sat - i_q)*v_cmd_unsat > 0.0) then pre(curInt) else pre(curInt) + Ts*(i_ref_sat - i_q);
  end when;

  annotation(experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6));
end BLDCWheelPositionD;