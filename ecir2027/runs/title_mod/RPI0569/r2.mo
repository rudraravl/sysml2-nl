model SeriesElasticTorqueE
  // --- Electrical parameters ---
  parameter Real Vmax = 52.8 "Voltage command bound (V)";
  parameter Real Vsupply = 48.0 "Bus voltage (V)";
  parameter Real R = 0.5 "Motor resistance (Ohm)";
  parameter Real L = 0.5e-3 "Motor inductance (H)";
  parameter Real Kt = 0.1 "Torque constant (N.m/A)";
  parameter Real Ke = 0.1 "Back-EMF constant (V.s/rad)";
  parameter Real Jm = 1.0e-5 "Motor inertia (kg.m2)";
  parameter Real N = 100.0 "Gear ratio";

  // --- Transmission ---
  parameter Real k_spring = 850.0 "Series torsional stiffness (N.m/rad)";
  parameter Real b_spring = 5.0 "Series torsional damping (N.m.s/rad)";

  // --- Load and contact ---
  parameter Real Jl = 0.05 "Output inertia (kg.m2)";
  parameter Real k_contact = 50000.0 "Contact stiffness (N.m/rad)";
  parameter Real b_contact = 50.0 "Contact damping (N.m.s/rad)";
  parameter Real theta_support = 0.0 "Rigid support angle (rad)";

  // --- Thermal ---
  parameter Real C_th = 100.0 "Thermal capacitance (J/K)";
  parameter Real R_th = 1.0 "Thermal resistance (K/W)";
  parameter Real T_amb = 25.0 "Ambient temperature (degC)";

  // --- Controller gains ---
  parameter Real Kp_i = 20.0 "Inner current proportional gain";
  parameter Real Ki_i = 200.0 "Inner current integral gain";
  parameter Real Kp_tau = 5.0 "Outer torque proportional gain";
  parameter Real Ki_tau = 20.0 "Outer torque integral gain";
  parameter Real i_int_max = 2.0 "Inner integrator clamp (A.s)";
  parameter Real tau_int_max = 5.0 "Outer integrator clamp (N.m.s)";

  // --- Command and disturbance ---
  parameter Real tau_ref_cmd = 10.0 "Spring torque reference (N.m)";
  parameter Real t_dist_start = 16.0/3.0 "Disturbance start (s)";
  parameter Real t_dist_end = 2.0*16.0/3.0 "Disturbance end (s)";
  parameter Real dist_amp = 18.0 "Disturbance amplitude (N.m)";

  // --- Acceptance bounds (fail-closed) ---
  parameter Real i_max_bound = 80.0 "Current bound (A)";
  parameter Real T_max_bound = 120.0 "Thermal bound (degC)";
  parameter Real theta_l_max = 1.0 "Joint angle bound (rad)";
  parameter Real defl_max = 0.5 "Transmission deflection bound (rad)";
  parameter Real tau_contact_max = 500.0 "Contact force bound (N.m)";
  parameter Real track_err_max = 1.8 "Tracking error bound (N.m)";
  parameter Real t_track_check = 10.4 "Tracking check time (s)";

  // --- Continuous states ---
  Real i_motor(start=0, fixed=true) "Motor current (A)";
  Real theta_m(start=0, fixed=true) "Motor angle (rad)";
  Real omega_m(start=0, fixed=true) "Motor speed (rad/s)";
  Real theta_l(start=0, fixed=true) "Output angle (rad)";
  Real omega_l(start=0, fixed=true) "Output speed (rad/s)";
  Real T_motor(start=T_amb, fixed=true) "Motor temperature (degC)";

  // --- Derived and instrumented signals ---
  Real theta_g "Gear-output angle (rad)";
  Real omega_g "Gear-output speed (rad/s)";
  Real tau_spring "Spring torque, both sides (N.m)";
  Real tau_contact "Contact force/torque (N.m)";
  Real tau_dist "Load disturbance (N.m)";
  Real u_cmd "Unsaturated voltage command (V)";
  Real u_sat "Saturated voltage command (V)";
  Real i_ref "Current reference (A)";
  Real tau_ref "Torque reference (N.m)";
  Real i_err "Current error (A)";
  Real tau_err "Torque error (N.m)";
  Real i_err_int(start=0, fixed=true) "Current integrator (A.s)";
  Real tau_err_int(start=0, fixed=true) "Torque integrator (N.m.s)";
  Real tracking_error "Primary tracking error (N.m)";
  Real theta_g_meas "Gear-side spring angle (rad)";
  Real theta_l_meas "Load-side spring angle (rad)";
  Real omega_l_meas "Output speed measurement (rad/s)";
  Real tau_spring_meas "Spring torque measurement (N.m)";
  Real tau_contact_meas "Contact force measurement (N.m)";
  Real i_meas "Current measurement (A)";
  Real T_meas "Temperature measurement (degC)";
  Real u_cmd_meas "Command trace (V)";
equation
  // Motor electrical dynamics
  L*der(i_motor) = u_sat - R*i_motor - Ke*omega_m;
  // Motor mechanical dynamics with gear reaction
  Jm*der(omega_m) = Kt*i_motor - tau_spring/N;
  der(theta_m) = omega_m;
  // Ideal rigid gearbox
  theta_g = theta_m/N;
  omega_g = omega_m/N;
  // Series elastic element instrumented on both sides
  tau_spring = k_spring*(theta_g - theta_l) + b_spring*(omega_g - omega_l);
  // Output load dynamics
  Jl*der(omega_l) = tau_spring - tau_contact - tau_dist;
  der(theta_l) = omega_l;
  // Rigid support with explicit compliant contact
  tau_contact = k_contact*(theta_l - theta_support) + b_contact*omega_l;
  // Middle-third load disturbance
  tau_dist = if (time >= t_dist_start and time <= t_dist_end) then dist_amp else 0.0;
  // Thermal model
  C_th*der(T_motor) = R*i_motor*i_motor - (T_motor - T_amb)/R_th;
  // Reference
  tau_ref = tau_ref_cmd;
  // Tracking error (primary)
  tracking_error = tau_ref - tau_spring;
  // Measurements / instrumented traces
  theta_g_meas = theta_g;
  theta_l_meas = theta_l;
  omega_l_meas = omega_l;
  tau_spring_meas = tau_spring;
  tau_contact_meas = tau_contact;
  i_meas = i_motor;
  T_meas = T_motor;
  u_cmd_meas = u_cmd;
  // Voltage saturation (command magnitude bounded by 52.8 V)
  u_sat = if u_cmd > Vmax then Vmax else if u_cmd < -Vmax then -Vmax else u_cmd;

  // Discrete inner/outer controller at 250 Hz
  when sample(0, 1.0/250.0) then
    tau_err = tau_ref - tau_spring;
    tau_err_int = max(-tau_int_max, min(tau_int_max, pre(tau_err_int) + tau_err/250.0));
    i_ref = Kp_tau*tau_err + Ki_tau*tau_err_int;
    i_err = i_ref - i_motor;
    i_err_int = max(-i_int_max, min(i_int_max, pre(i_err_int) + i_err/250.0));
    u_cmd = Kp_i*i_err + Ki_i*i_err_int;
  end when;

  // --- Fail-closed acceptance bounds ---
  assert(abs(u_sat) <= Vmax + 1.0e-3, "Electrical voltage bound violated");
  assert(abs(i_motor) <= i_max_bound, "Electrical current bound violated");
  assert(T_motor <= T_max_bound, "Thermal bound violated");
  assert(abs(theta_l) <= theta_l_max, "Joint bound violated");
  assert(abs(theta_g - theta_l) <= defl_max, "Transmission deflection bound violated");
  assert(abs(tau_contact) <= tau_contact_max, "Contact force bound violated");
  assert(time < t_track_check or abs(tracking_error) < track_err_max,
         "Primary tracking error exceeded 1.8 N.m after 10.4 s");
  // NaN/infinite guards
  assert(i_motor == i_motor, "NaN in motor current");
  assert(u_sat == u_sat, "NaN in voltage command");
  assert(tau_spring == tau_spring, "NaN in spring torque");
  assert(tau_contact == tau_contact, "NaN in contact torque");
  assert(theta_l == theta_l, "NaN in output angle");
  assert(omega_l == omega_l, "NaN in output speed");
  assert(T_motor == T_motor, "NaN in temperature");
  assert(u_cmd == u_cmd, "NaN in unsaturated command");
  assert(tau_ref == tau_ref, "NaN in reference");
end SeriesElasticTorqueE;