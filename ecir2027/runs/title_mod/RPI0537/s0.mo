model BallScrewSpeedC
  // Requirement-declared constants
  parameter Real V_bus_nominal(unit="V") = 24.0 "declared DC motor bus";
  parameter Real V_cmd_max(unit="V") = 22.1 "maximum command magnitude";
  parameter Real F_dist(unit="N") = 10.8 "declared load disturbance";
  parameter Real m_carriage(unit="kg") = 18.0 "declared carriage mass";
  parameter Real pitch(unit="m") = 0.005 "declared ball screw pitch";
  parameter Real lead(unit="m") = pitch "single-start screw assumed; pitch-to-lead relation not stated";
  parameter Real travel(unit="m") = 0.65 "declared travel";
  parameter Real Ts(unit="s") = 1/125 "125 Hz control/sample period";
  parameter Real T_end(unit="s") = 12.0 "run time";
  parameter Real T_check(unit="s") = 7.8 "tracking-error verification time";
  parameter Real err_bound(unit="m/s") = 0.263 "primary tracking-error bound";

  // Profile split assumed to satisfy accelerate/hold/decelerate; not specified by request
  parameter Real T_acc(unit="s") = 3.0;
  parameter Real T_hold_end(unit="s") = 9.0;
  parameter Real T_dec(unit="s") = T_end - T_hold_end;
  parameter Real T_mid_start(unit="s") = 4.0 "middle third start";
  parameter Real T_mid_end(unit="s") = 8.0 "middle third end";
  parameter Real v_hold(unit="m/s") = travel/((T_hold_end - T_acc) + (T_acc + T_dec)/2) "declared output speed";

  constant Real PI = 3.141592653589793;
  parameter Real r_lead(unit="m/rad") = lead/(2*PI);
  parameter Real omega_ref_hold(unit="rad/s") = v_hold/r_lead;

  // Unknown plant, battery, friction, thermal values are bound only for executable simulation
  parameter Real R(unit="Ohm") = 1.0 "assumed armature resistance";
  parameter Real L(unit="H") = 0.02 "assumed armature inductance";
  parameter Real K(unit="N.m/A") = 0.1 "assumed motor constant, Kt=Ke";
  parameter Real J_motor(unit="kg.m2") = 1e-4 "assumed rotating inertia";
  parameter Real J_screw(unit="kg.m2") = 1e-4 "assumed rotating inertia";
  parameter Real N(unit="1") = 2.0 "assumed belt ratio, motor speed / screw speed";
  parameter Real eta_gb(unit="1") = 0.90 "assumed gearbox efficiency";

  parameter Real b_backlash(unit="rad") = 1e-4 "assumed backlash";
  parameter Real k_belt(unit="N.m/rad") = 1.0 "assumed contact stiffness";
  parameter Real d_belt(unit="N.m.s/rad") = 0.2 "assumed contact damping";

  parameter Real F_coulomb_lin(unit="N") = 0.2 "assumed Coulomb friction";
  parameter Real c_visc_lin(unit="N.s/m") = 0.5 "assumed viscous friction";
  parameter Real tau_coulomb_motor(unit="N.m") = 0.001 "assumed Coulomb friction";
  parameter Real tau_coulomb_screw(unit="N.m") = 0.001 "assumed Coulomb friction";
  parameter Real b_motor(unit="N.m.s/rad") = 1e-5 "assumed viscous friction";
  parameter Real b_screw(unit="N.m.s/rad") = 1e-6 "assumed viscous friction";
  parameter Real v_eps(unit="m/s") = 1e-3 "friction smoothing threshold";
  parameter Real omega_eps(unit="rad/s") = 1e-2 "friction smoothing threshold";

  parameter Real R_bat(unit="Ohm") = 0.1 "assumed battery droop resistance";
  parameter Real C_bat_Ah(unit="A.h") = 1.0 "assumed battery capacity";
  parameter Real V_bus_min(unit="V") = 20.0 "assumed lower bus bound";
  parameter Real SoC0(unit="1") = 0.95 "assumed initial state-of-charge";

  parameter Real T_amb(unit="K") = 293.15 "assumed ambient temperature";
  parameter Real C_th(unit="J/K") = 100.0 "assumed thermal capacitance";
  parameter Real R_th(unit="K/W") = 1.0 "assumed thermal resistance";
  parameter Real Theta_max(unit="K") = 353.15 "assumed thermal bound";

  // Bounds
  parameter Real i_bound(unit="A") = V_cmd_max/R "current bound from command limit and assumed resistance";
  parameter Real v_bound(unit="m/s") = 0.263 "speed bound; only stated numeric bound reused";
  parameter Real a_bound(unit="m/s2") = 0.263 "acceleration bound; actual limit not stated";
  parameter Real SoC_min(unit="1") = 0.0;
  parameter Real SoC_max(unit="1") = 1.0;

  // Controller gains
  parameter Real Kp_pos(unit="1/s") = 0.5;
  parameter Real Kp_speed(unit="A.s/m") = 5.0;
  parameter Real Ki_speed(unit="A/m") = 10.0;
  parameter Real Kp_current(unit="V/A") = 5.0;
  parameter Real i_max(unit="A") = i_bound;

  // Dynamic states
  Real i(unit="A") "armature current";
  Real phi_motor(unit="rad") "rotor position";
  Real omega_motor(unit="rad/s") "rotor speed";
  Real phi_screw(unit="rad") "screw position";
  Real omega_screw(unit="rad/s") "screw speed";
  Real SoC(unit="1") "battery state-of-charge";
  Real Theta(unit="K") "motor temperature";

  // Plant variables
  Real phi_belt(unit="rad");
  Real omega_belt(unit="rad/s");
  Real delta(unit="rad");
  Real contact(unit="rad");
  Real dcontact(unit="rad/s");
  Real tau_belt(unit="N.m");
  Real tau_motor_load(unit="N.m");
  Real tau_friction_motor(unit="N.m");
  Real tau_friction_screw(unit="N.m");
  Real F_friction(unit="N");
  Real F_dist_active(unit="N");
  Real V_bus(unit="V");
  Real P_bat(unit="W");
  Real v_out(unit="m/s") "output speed";
  Real x(unit="m") "carriage position";
  Real a_out(unit="m/s2") "output acceleration";

  // Command traces
  Real v_ref(unit="m/s");
  Real x_ref(unit="m");
  Real i_ref(unit="A");
  Real v_cmd(unit="V");
  Real tracking_error(unit="m/s");

  // Sensor traces
  Real i_sensed(unit="A");
  Real phi_motor_sensed(unit="rad");
  Real v_out_sensed(unit="m/s");
  Real V_bus_sensed(unit="V");

  // Sampled controller variables
  discrete Real v_ref_d(start=0, unit="m/s");
  discrete Real x_ref_d(start=0, unit="m");
  discrete Real e_speed(start=0, unit="m/s");
  discrete Real integ_speed_d(start=0, unit="m");
  discrete Real i_ref_unsat(start=0, unit="A");
  discrete Real i_ref_d(start=0, unit="A");
  discrete Real e_current(start=0, unit="A");
  discrete Real v_unsat(start=0, unit="V");
  discrete Real v_cmd_d(start=0, unit="V");

initial equation
  i = 0.0;
  phi_motor = 0.0;
  omega_motor = 0.0;
  phi_screw = 0.0;
  omega_screw = 0.0;
  SoC = SoC0;
  Theta = T_amb;

equation
  // Kinematics and synchronized traces
  v_out = omega_screw * r_lead;
  x = phi_screw * r_lead;
  a_out = der(omega_screw) * r_lead;

  v_ref = v_ref_d;
  x_ref = x_ref_d;
  i_ref = i_ref_d;
  v_cmd = v_cmd_d;

  i_sensed = i;
  phi_motor_sensed = phi_motor;
  v_out_sensed = v_out;
  V_bus_sensed = V_bus;

  tracking_error = abs(v_ref - v_out);

  // Controlled disturbance during middle third
  F_dist_active = if time >= T_mid_start and time <= T_mid_end then F_dist else 0.0;

  // Mechanical friction
  F_friction = F_coulomb_lin*tanh(v_out/v_eps) + c_visc_lin*v_out;
  tau_friction_motor = tau_coulomb_motor*tanh(omega_motor/omega_eps) + b_motor*omega_motor;
  tau_friction_screw = tau_coulomb_screw*tanh(omega_screw/omega_eps) + b_screw*omega_screw;

  // Belt reduction with backlash
  phi_belt = phi_motor / N;
  omega_belt = omega_motor / N;
  delta = phi_belt - phi_screw;
  contact = delta - b_backlash*tanh(delta/b_backlash);
  dcontact = (omega_belt - omega_screw)*tanh(delta/b_backlash)^2;
  tau_belt = k_belt*contact + d_belt*dcontact;
  tau_motor_load = tau_belt/(eta_gb*N);

  // Motor electrical and rotational dynamics
  L*der(i) = v_cmd - R*i - K*omega_motor;
  J_motor*der(omega_motor) = K*i - tau_motor_load - tau_friction_motor;
  der(phi_motor) = omega_motor;

  // Screw and carriage dynamics
  (J_screw + m_carriage*r_lead^2)*der(omega_screw) = tau_belt - tau_friction_screw - (F_dist_active + F_friction)*r_lead;
  der(phi_screw) = omega_screw;

  // Battery droop, state-of-charge, and thermal model
  V_bus = max(V_bus_min, V_bus_nominal - R_bat*abs(i));
  P_bat = v_cmd*i;
  der(SoC) = -P_bat/(V_bus_nominal*3600*C_bat_Ah);
  der(Theta) = (i^2*R - (Theta - T_amb)/R_th)/C_th;

  // 125 Hz cascaded position-speed-current controller
  when sample(0, Ts) then
    v_ref_d = if time < T_acc then v_hold*time/T_acc
      elseif time < T_hold_end then v_hold
      elseif time < T_end then v_hold*(T_end - time)/(T_end - T_hold_end)
      else 0.0;

    x_ref_d = if time < T_acc then 0.5*v_hold*(time*time)/T_acc
      elseif time < T_hold_end then 0.5*v_hold*T_acc + v_hold*(time - T_acc)
      elseif time < T_end then 0.5*v_hold*T_acc + v_hold*(T_hold_end - T_acc) + v_hold*(time - T_hold_end) - 0.5*v_hold*(time - T_hold_end)*(time - T_hold_end)/(T_end - T_hold_end)
      else travel;

    e_speed = (v_ref_d + Kp_pos*(x_ref_d - x)) - v_out;
    integ_speed_d = pre(integ_speed_d) + Ts*e_speed;
    i_ref_unsat = Kp_speed*e_speed + Ki_speed*integ_speed_d;
    i_ref_d = if i_ref_unsat > i_max then i_max elseif i_ref_unsat < -i_max then -i_max else i_ref_unsat;

    e_current = i_ref_d - i;
    v_unsat = Kp_current*e_current + K*omega_motor;
    v_cmd_d = if v_unsat > V_cmd_max then V_cmd_max elseif v_unsat < -V_cmd_max then -V_cmd_max else v_unsat;
  end when;

  // Bounds and finite-value requirements
  assert(abs(v_cmd) <= V_cmd_max + 1e-9, "Voltage command bound exceeded");
  assert(V_bus >= V_bus_min - 1e-9, "DC bus lower bound exceeded");
  assert(V_bus <= V_bus_nominal + 1e-6, "DC bus upper bound exceeded");
  assert(abs(i) <= i_bound + 1e-9, "Current bound exceeded");
  assert(abs(v_out) <= v_bound + 1e-9, "Output speed bound exceeded");
  assert(abs(a_out) <= a_bound + 1e-9, "Acceleration bound exceeded");
  assert(SoC >= SoC_min - 1e-9 and SoC <= SoC_max + 1e-9, "State-of-charge bound exceeded");
  assert(Theta <= Theta_max + 1e-9, "Thermal bound exceeded");
  assert(x >= -1e-3 and x <= travel + 1e-3, "Travel bound exceeded");
  assert(time < T_check or tracking_error <= err_bound + 1e-9, "Primary tracking error bound exceeded after 7.8 s");
  assert(abs(i) < 1e12 and abs(omega_motor) < 1e12 and abs(omega_screw) < 1e12 and abs(v_out) < 1e12 and abs(x) < 1e12 and abs(SoC) < 1e12 and abs(Theta) < 1e12 and abs(v_cmd) < 1e12 and abs(i_ref) < 1e12 and abs(V_bus) < 1e12 and abs(tracking_error) < 1e12, "Finite-value check failed");

  annotation(experiment(StopTime=12, Interval=0.008, Tolerance=1e-6));
end BallScrewSpeedC;