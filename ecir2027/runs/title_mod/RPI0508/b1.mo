model BLDCWheelPositionD
  "Instrumented 48V three-phase PM motor, 9:1 gearbox, 0.12m wheel, cascaded position/current control with anti-windup, 8N load in middle third, 200Hz control for 14s."

  // Requirement-derived constants
  parameter Real V_oc(unit="V") = 48.0 "battery open-circuit voltage";
  parameter Integer p = 4 "motor pole pairs";
  parameter Real d_wheel(unit="m") = 0.12 "wheel diameter";
  parameter Real r_wheel(unit="m") = d_wheel/2 "wheel radius";
  parameter Real n_gear = 9.0 "gearbox ratio motor:wheel";
  parameter Real Ts(unit="s") = 0.005 "control period 200 Hz";
  parameter Real F_load_amp(unit="N") = 8.0 "output load disturbance amplitude";
  parameter Real t_load_start(unit="s") = 14.0/3.0 "middle third start";
  parameter Real t_load_stop(unit="s") = 28.0/3.0 "middle third stop";
  parameter Real x_target(unit="m") = 1.0 "nonzero output target";
  parameter Real t_ramp(unit="s") = 3.0 "command ramp time";
  parameter Real t_error_check(unit="s") = 9.1 "tracking-error check start";
  parameter Real e_bound(unit="m") = 0.03 "primary and final error bound";

  // Plant parameters (representative; requirement does not specify)
  parameter Real R_w(unit="Ohm") = 0.2 "per-phase winding resistance";
  parameter Real L_q(unit="H") = 0.005 "q-axis inductance";
  parameter Real psi_m(unit="Wb") = 0.05 "magnet flux linkage";
  parameter Real R_batt(unit="Ohm") = 0.05 "battery internal resistance";
  parameter Real m_carriage(unit="kg") = 5.0 "driven rigid body mass";
  parameter Real b_track(unit="N.s/m") = 0.1 "track viscous damping";
  parameter Real x_min(unit="m") = 0.0 "travel lower limit";
  parameter Real x_max(unit="m") = 2.0 "travel upper limit";
  parameter Real k_stop(unit="N/m") = 1.0e4 "collision stiffness";
  parameter Real d_stop(unit="N.s/m") = 1.0e2 "collision damping";
  parameter Real T_amb(unit="K") = 293.15 "ambient temperature";
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

  constant Real PI_c = 3.141592653589793;

  // Continuous states
  Real x(start=0.0, unit="m") "carriage output position";
  Real v(start=0.0, unit="m/s") "carriage output velocity";
  Real i_q(start=0.0, unit="A") "q-axis current";
  Real T_w(start=T_amb, unit="K") "winding temperature";
  Real theta_e(start=0.0, unit="rad") "electrical angle";

  // Discrete control states
  discrete Real posInt(start=0.0, unit="m.s") "position integral";
  discrete Real curInt(start=0.0, unit="A.s") "current integral";
  discrete Real i_ref_unsat(start=0.0, unit="A") "unclamped current command";
  discrete Real i_ref_sat(start=0.0, unit="A") "clamped current command";
  discrete Real v_cmd_unsat(start=0.0, unit="V") "unclamped voltage command";
  discrete Real v_cmd(start=0.0, unit="V") "clamped voltage command";

  // Observable continuous variables
  Real x_ref(unit="m") "position command trace";
  Real e_pos(unit="m") "position error";
  Real e_track(unit="m") "primary tracking error";
  Real final_error(unit="m") "final error vs target";
  Real theta_wheel(unit="rad") "wheel angle";
  Real omega_wheel(unit="rad/s") "wheel angular velocity";
  Real theta_motor(unit="rad") "motor angle";
  Real omega_motor(unit="rad/s") "motor angular velocity";
  Real omega_e(unit="rad/s") "electrical angular velocity";
  Real torque_motor(unit="N.m") "motor torque";
  Real F_drive(unit="N") "drive force at wheel";
  Real F_track(unit="N") "track damping force";
  Real F_load(unit="N") "applied load disturbance";
  Real F_stop(unit="N") "collision/limit force";
  Real V_bus(unit="V") "DC bus voltage";
  Real V_lim(unit="V") "available voltage limit";
  Real i_dc(unit="A") "approximated DC bus current";
  Real i_d(unit="A") = 0.0 "d-axis current (held zero by FOC)";
  Real i_a(unit="A") "phase a current";
  Real i_b(unit="A") "phase b current";
  Real i_c(unit="A") "phase c current";
  Real i_meas(unit="A") "measured peak phase current";
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
  // Smooth position command with hold
  x_ref = if time <= t_ramp then 0.5*x_target*(1.0 - cos(PI_c*time/t_ramp)) else x_target;
  e_pos = x_ref - x;
  e_track = e_pos;
  final_error = x_target - x;

  // Sensor traces
  x_meas = x;
  v_meas = v;
  T_meas = T_w;

  // Kinematic relations
  theta_wheel = x/r_wheel;
  omega_wheel = v/r_wheel;
  theta_motor = n_gear*theta_wheel;
  omega_motor = n_gear*omega_wheel;
  omega_e = p*omega_motor;

  // Motor torque and drive force
  torque_motor = p*psi_m*i_q;
  F_drive = torque_motor*n_gear/r_wheel;
  F_track = b_track*v;

  // Battery with internal resistance
  i_dc = abs(i_q);
  V_bus = V_oc - R_batt*i_dc;
  V_lim = max(0.0, V_bus);

  // Load disturbance during middle third
  F_load = if time >= t_load_start and time < t_load_stop then F_load_amp else 0.0;

  // Collision and physical travel limits
  F_stop = noEvent(if x < x_min then k_stop*(x_min - x) + d_stop*max(0.0, -v)
                   elseif x > x_max then -k_stop*(x - x_max) - d_stop*max(0.0, v)
                   else 0.0);

  // Mechanical rigid body dynamics
  der(x) = v;
  m_carriage*der(v) = F_drive - F_load - F_track - F_stop;

  // FOC q-axis electrical dynamics
  L_q*der(i_q) = v_cmd - R_w*i_q - psi_m*omega_e;
  der(theta_e) = omega_e;

  // Winding thermal dynamics
  C_th*der(T_w) = R_w*i_q*i_q - (T_w - T_amb)/R_th;

  // Representative three-phase currents
  i_a = i_q*cos(theta_e);
  i_b = i_q*cos(theta_e - 2.0*PI_c/3.0);
  i_c = i_q*cos(theta_e + 2.0*PI_c/3.0);
  i_meas = max(abs(i_a), max(abs(i_b), abs(i_c)));

  // Bound indicators
  voltage_ok = if abs(v_cmd) <= V_oc + 1e-6 then 1.0 else 0.0;
  current_ok = if i_meas <= I_bound + 1e-6 then 1.0 else 0.0;
  travel_ok = if x >= x_min - 1e-6 and x <= x_max + 1e-6 then 1.0 else 0.0;
  temperature_ok = if T_w <= T_max + 1e-6 then 1.0 else 0.0;
  tracking_ok = if time >= t_error_check then (if abs(e_track) <= e_bound then 1.0 else 0.0) else 1.0;
  final_error_ok = if abs(final_error) <= e_bound then 1.0 else 0.0;

  // Requirement bounds
  assert(noEvent(abs(v_cmd) <= V_oc + 1e-6), "voltage bound exceeded");
  assert(noEvent(i_meas <= I_bound + 1e-6), "current bound exceeded");
  assert(noEvent(x >= x_min - 1e-6), "travel lower bound exceeded");
  assert(noEvent(x <= x_max + 1e-6), "travel upper bound exceeded");
  assert(noEvent(T_w <= T_max + 1e-6), "temperature bound exceeded");
  assert(noEvent(time < t_error_check or abs(e_track) <= e_bound), "primary tracking error after 9.1s exceeded");

  when terminal() then
    assert(abs(final_error) <= e_bound, "final error bound exceeded");
  end when;

  // Cascaded position and current control at 200 Hz with clamping anti-windup
  when sample(0, Ts) then
    // Outer position loop -> current command
    i_ref_unsat = Kp_pos*e_pos + Ki_pos*pre(posInt) - Kd_pos*v;
    i_ref_sat = max(-I_limit, min(I_limit, i_ref_unsat));
    posInt = if abs(i_ref_unsat) > I_limit and e_pos*i_ref_unsat > 0.0 then pre(posInt) else pre(posInt) + Ts*e_pos;

    // Inner current loop -> voltage command, limited by DC bus
    v_cmd_unsat = psi_m*omega_e + Kp_i*(i_ref_sat - i_q) + Ki_i*pre(curInt);
    v_cmd = max(-V_lim, min(V_lim, v_cmd_unsat));
    curInt = if abs(v_cmd_unsat) > V_lim and (i_ref_sat - i_q)*v_cmd_unsat > 0.0 then pre(curInt) else pre(curInt) + Ts*(i_ref_sat - i_q);
  end when;

  annotation(experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6));
end BLDCWheelPositionD;