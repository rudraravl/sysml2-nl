model BLDCWheelPositionD
  "Instrumented 48 V three-phase PM motor, 9:1 gearbox, 0.12 m wheel, cascaded position/current control, 8 N load disturbance in the middle third, 200 Hz control/logging for 14 s."

  // Requirement-derived constants
  parameter Real V_oc(unit="V") = 48.0 "open-circuit battery/bus voltage";
  parameter Integer p = 4 "motor pole pairs";
  parameter Real d_wheel(unit="m") = 0.12 "wheel diameter";
  parameter Real r_wheel(unit="m") = d_wheel/2 "wheel radius";
  parameter Real n_gear = 9.0 "gearbox ratio motor:wheel";
  parameter Real Ts(unit="s") = 0.005 "control and logging period, 200 Hz";
  parameter Real StopTime(unit="s") = 14.0 "run duration";
  parameter Real F_load_amp(unit="N") = 8.0 "output load disturbance amplitude";
  parameter Real t_load_start(unit="s") = StopTime/3.0 "middle third start";
  parameter Real t_load_stop(unit="s") = 2.0*StopTime/3.0 "middle third stop";
  parameter Real x_target(unit="m") = 1.0 "nonzero output position command";
  parameter Real t_ramp(unit="s") = 3.0 "assumed smooth command ramp time";
  parameter Real t_error_check(unit="s") = 9.1 "time after which tracking error is bounded";
  parameter Real e_bound(unit="m") = 0.03 "primary and final error bound";

  // Assumed plant parameters; not specified by requirement, representative only
  parameter Real R_w(unit="Ohm") = 0.2 "winding resistance per phase";
  parameter Real L_q(unit="H") = 0.005 "q-axis inductance";
  parameter Real psi_m(unit="Wb") = 0.05 "magnet flux linkage";
  parameter Real R_batt(unit="Ohm") = 0.05 "battery internal resistance";
  parameter Real m_carriage(unit="kg") = 5.0 "driven rigid carriage mass";
  parameter Real b_track(unit="N.s/m") = 0.1 "track damping";
  parameter Real x_min(unit="m") = 0.0 "physical travel lower limit";
  parameter Real x_max(unit="m") = 2.0 "physical travel upper limit";
  parameter Real k_stop(unit="N/m") = 1.0e4 "collision stiffness";
  parameter Real d_stop(unit="N.s/m") = 1.0e2 "collision damping";
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
  Real x(unit="m", start=0.0) "carriage output position";
  Real v(unit="m/s", start=0.0) "carriage output velocity";
  Real i_q(unit="A", start=0.0) "q-axis current";
  Real T_w(unit="K", start=T_amb) "winding temperature";
  Real theta_e(unit="rad", start=0.0) "electrical angle";

  // Discrete control states
  discrete Real posInt(unit="m.s", start=0.0) "position integral";
  discrete Real curInt(unit="A.s", start=0.0) "current integral";
  discrete Real i_ref_unsat(unit="A", start=0.0) "unlimited position loop current command";
  discrete Real i_ref_sat(unit="A", start=0.0) "limited position loop current command";
  discrete Real v_cmd_unsat(unit="V", start=0.0) "unlimited current loop voltage command";
  discrete Real v_cmd(unit="V", start=0.0) "limited current loop voltage command";

  // Derived physical quantities
  Real theta_wheel(unit="rad") = x/r_wheel;
  Real omega_wheel(unit="rad/s") = v/r_wheel;
  Real theta_motor(unit="rad") = n_gear*theta_wheel;
  Real omega_motor(unit="rad/s") = n_gear*omega_wheel;
  Real omega_e(unit="rad/s") = p*omega_motor;
  Real torque_motor(unit="N.m") = p*psi_m*i_q;
  Real F_drive(unit="N") = torque_motor*n_gear/r_wheel;
  Real F_track(unit="N") = b_track*v;
  Real i_dc(unit="A") = abs(i_q) "approximated DC bus current, modulation not specified";
  Real V_bus(unit="V");
  Real V_lim(unit="V") = max(0.0, V_bus);
  Real F_load(unit="N");
  Real F_stop(unit="N");
  Real i_d(unit="A") = 0.0 "FOC d-axis current held zero";
  Real i_a(unit="A");
  Real i_b(unit="A");
  Real i_c(unit="A");

  // Commands, errors, sensors
  Real x_ref(unit="m");
  Real e_pos(unit="m");
  Real e_track(unit="m");
  Real final_error(unit="m") = x_target - x;
  Real i_meas(unit="A");
  Real x_meas(unit="m") = x;
  Real v_meas(unit="m/s") = v;
  Real T_meas(unit="K") = T_w;

  // Bound indicators
  Real voltage_ok;
  Real current_ok;
  Real travel_ok;
  Real temperature_ok;
  Real tracking_ok;
  Real final_error_ok;

  // Synchronized 200 Hz traces
  parameter Integer Nsamples = 2801 "14 s / 0.005 s plus t=0";
  Integer counter(start=0);
  discrete Real logTime[Nsamples](each start=0.0);
  discrete Real logX[Nsamples](each start=0.0);
  discrete Real logV[Nsamples](each start=0.0);
  discrete Real logI[Nsamples](each start=0.0);
  discrete Real logT[Nsamples](each start=0.0);
  discrete Real logXref[Nsamples](each start=0.0);
  discrete Real logIref[Nsamples](each start=0.0);
  discrete Real logVcmd[Nsamples](each start=0.0);
  discrete Real logErr[Nsamples](each start=0.0);

equation
  // Smooth nonzero position command and hold
  if time <= t_ramp then
    x_ref = 0.5*x_target*(1.0 - cos(PI*time/t_ramp));
  else
    x_ref = x_target;
  end if;

  e_pos = x_ref - x;
  e_track = e_pos;

  // Battery with internal resistance
  V_bus = V_oc - R_batt*i_dc;

  // Output load disturbance during middle third
  if time >= t_load_start and time < t_load_stop then
    F_load = F_load_amp;
  else
    F_load = 0.0;
  end if;

  // Collision and physical travel limits
  if x < x_min then
    F_stop = k_stop*(x_min - x) - d_stop*(if v < 0.0 then -v else 0.0);
  elseif x > x_max then
    F_stop = -k_stop*(x - x_max) - d_stop*(if v > 0.0 then v else 0.0);
  else
    F_stop = 0.0;
  end if;

  // Mechanical rigid body
  der(x) = v;
  m_carriage*der(v) = F_drive - F_load - F_track - F_stop;

  // FOC q-axis electrical dynamics with back-EMF feedforward in controller
  L_q*der(i_q) = v_cmd - R_w*i_q - psi_m*omega_e;
  der(theta_e) = omega_e;

  // Winding temperature
  C_th*der(T_w) = R_w*i_q*i_q - (T_w - T_amb)/R_th;

  // Representative three-phase currents
  i_a = i_q*cos(theta_e);
  i_b = i_q*cos(theta_e - 2.0*PI/3.0);
  i_c = i_q*cos(theta_e + 2.0*PI/3.0);

  // Current measurement
  i_meas = max(abs(i_a), max(abs(i_b), abs(i_c)));

  // Bound indicators
  voltage_ok = if abs(v_cmd) <= V_oc + 1e-6 then 1.0 else 0.0;
  current_ok = if abs(i_meas) <= I_bound + 1e-6 then 1.0 else 0.0;
  travel_ok = if x >= x_min - 1e-6 and x <= x_max + 1e-6 then 1.0 else 0.0;
  temperature_ok = if T_w <= T_max + 1e-6 then 1.0 else 0.0;
  tracking_ok = if time >= t_error_check then (if abs(e_track) <= e_bound then 1.0 else 0.0) else 1.0;
  final_error_ok = if abs(final_error) <= e_bound then 1.0 else 0.0;

  // Requirement bounds and finite-value checks
  assert(noEvent(abs(v_cmd) <= V_oc + 1e-6), "voltage bound exceeded");
  assert(noEvent(abs(i_meas) <= I_bound + 1e-6), "current bound exceeded");
  assert(noEvent(x >= x_min - 1e-6 and x <= x_max + 1e-6), "travel bound exceeded");
  assert(noEvent(T_w <= T_max + 1e-6), "temperature bound exceeded");
  assert(noEvent(time < t_error_check or abs(e_track) <= e_bound), "primary tracking error after 9.1 s exceeded");
  assert(noEvent(abs(x) < 1e6 and abs(v) < 1e6 and abs(i_q) < 1e6 and abs(T_w) < 1e6 and abs(theta_e) < 1e6 and abs(v_cmd) < 1e6 and abs(i_ref_sat) < 1e6 and abs(posInt) < 1e6 and abs(curInt) < 1e6), "finite value check failed");

  when terminal() then
    assert(abs(final_error) <= e_bound, "final error bound exceeded");
  end when;

  // Cascaded position and current control at 200 Hz with clamping anti-windup
  when sample(0, Ts) then
    counter = pre(counter) + 1;
    assert(counter <= Nsamples, "log index exceeded");

    // Outer position loop -> current command
    i_ref_unsat = Kp_pos*e_pos + Ki_pos*pre(posInt) - Kd_pos*v;
    i_ref_sat = max(-I_limit, min(I_limit, i_ref_unsat));
    posInt = if abs(i_ref_unsat) > I_limit and e_pos*i_ref_unsat > 0.0 then pre(posInt) else pre(posInt) + Ts*e_pos;

    // Inner current loop -> voltage command, limited by available DC bus
    v_cmd_unsat = psi_m*omega_e + Kp_i*(i_ref_sat - i_q) + Ki_i*pre(curInt);
    v_cmd = max(-V_lim, min(V_lim, v_cmd_unsat));
    curInt = if abs(v_cmd_unsat) > V_lim and (i_ref_sat - i_q)*v_cmd_unsat > 0.0 then pre(curInt) else pre(curInt) + Ts*(i_ref_sat - i_q);

    // Synchronized state, command, and sensor traces
    logTime[counter] = time;
    logX[counter] = x;
    logV[counter] = v;
    logI[counter] = i_q;
    logT[counter] = T_w;
    logXref[counter] = x_ref;
    logIref[counter] = i_ref_sat;
    logVcmd[counter] = v_cmd;
    logErr[counter] = e_track;
  end when;

  annotation(experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6));
end BLDCWheelPositionD;