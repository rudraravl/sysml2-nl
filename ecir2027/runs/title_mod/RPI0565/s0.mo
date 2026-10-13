model SeriesElasticTorqueA
  // Electrical
  parameter Real V_supply=48.0 "V, brushless motor bus voltage";
  parameter Real V_limit=34.6 "V, command magnitude limit";
  parameter Real R=0.40 "ohm, motor phase resistance";
  parameter Real L=1.0e-3 "H, motor phase inductance";
  parameter Real Kt=0.05 "N.m/A, motor torque constant";
  parameter Real Ke=0.05 "V/(rad/s), motor back-EMF constant";

  // Mechanical / transmission
  parameter Real N=100.0 "gearbox ratio";
  parameter Real k_s=850.0 "N.m/rad, series torsional spring stiffness";
  parameter Real J_m=1.0e-4 "kg.m2, motor inertia";
  parameter Real b_m=1.0e-4 "N.m.s/rad, motor viscous friction";
  parameter Real J_o=0.5 "kg.m2, output inertia";
  parameter Real b_o=0.01 "N.m.s/rad, output viscous friction";

  // Contact load (rigid support geometry, explicit stiffness and damping)
  parameter Real k_c=5000.0 "N.m/rad, contact stiffness";
  parameter Real b_c=20.0 "N.m.s/rad, contact damping";
  parameter Real theta_wall=0.0 "rad, rigid support angle";

  // Thermal
  parameter Real T_amb=25.0 "degC, ambient temperature";
  parameter Real R_th=1.5 "K/W, thermal resistance";
  parameter Real C_th=200.0 "J/K, thermal capacitance";

  // Scenario
  parameter Real Ts=1.0/80.0 "s, 80 Hz control/sensor sample time";
  parameter Real tau_ref_val=20.0 "N.m, output torque command";
  parameter Real tau_dist_val=7.5 "N.m, applied load-change disturbance";
  parameter Real t_start=8.0/3.0 "s, start of middle-third disturbance";
  parameter Real t_end=16.0/3.0 "s, end of middle-third disturbance";

  // Controller gains (inner current, outer spring-torque)
  parameter Real Kp_i=15.0 "V/A";
  parameter Real Ki_i=800.0 "V/(A.s)";
  parameter Real Kp_t=3.0 "A/N.m";
  parameter Real Ki_t=25.0 "A/(N.m.s)";

  // Bounds
  parameter Real I_bound=50.0 "A";
  parameter Real T_bound=90.0 "degC";
  parameter Real defl_bound=0.2 "rad";
  parameter Real contact_bound=100.0 "N.m";
  parameter Real track_bound=2.7 "N.m";
  parameter Real track_time=5.2 "s";

  // Continuous states
  Real i(start=0.0) "A, motor current";
  Real omega_m(start=0.0) "rad/s, motor speed";
  Real theta_m(start=0.0) "rad, motor angle";
  Real omega_o(start=0.0) "rad/s, output speed";
  Real theta_o(start=0.0) "rad, output angle";
  Real T(start=T_amb) "degC, actuator temperature";

  // Continuous algebraic quantities
  Real tau_m "N.m, motor torque";
  Real theta_g "rad, gearbox-output angle";
  Real defl "rad, spring deflection";
  Real tau_s "N.m, spring torque";
  Real tau_contact "N.m, contact torque";
  Real tau_dist "N.m, disturbance torque";
  Real tracking_err "N.m, primary tracking error";

  // Discrete controller and synchronized sensor traces (80 Hz)
  discrete Real V_cmd(start=0.0) "V, unconstrained voltage command";
  discrete Real V(start=0.0) "V, applied motor voltage";
  discrete Real i_ref(start=0.0) "A, current reference from outer loop";
  discrete Real integ_i(start=0.0) "A.s, current integrator";
  discrete Real integ_t(start=0.0) "N.m.s, torque integrator";
  discrete Real tau_err_d(start=0.0) "N.m, sampled torque error";
  discrete Real i_err_d(start=0.0) "A, sampled current error";
  discrete Real theta_motor_side(start=0.0) "rad, spring motor-side angle";
  discrete Real theta_load_side(start=0.0) "rad, spring load-side angle";
  discrete Real tau_s_meas(start=0.0) "N.m, sampled spring torque";
  discrete Real i_meas(start=0.0) "A, sampled motor current";
  discrete Real contact_meas(start=0.0) "N.m, sampled contact torque";
  discrete Real T_meas(start=T_amb) "degC, sampled temperature";
  discrete Real theta_o_meas(start=0.0) "rad, sampled output angle";
  discrete Real omega_o_meas(start=0.0) "rad/s, sampled output speed";

equation
  // Motor electrical dynamics
  der(i) = (V - R*i - Ke*omega_m)/L;
  der(theta_m) = omega_m;
  tau_m = Kt*i;
  // Motor mechanical: spring torque reflected through gearbox
  der(omega_m) = (tau_m - b_m*omega_m - tau_s/N)/J_m;

  // Transmission: gearbox output and series elastic element
  theta_g = theta_m/N;
  defl = theta_g - theta_o;
  tau_s = k_s*defl;

  // Output joint dynamics against compliant contact load
  der(theta_o) = omega_o;
  der(omega_o) = (tau_s - b_o*omega_o - tau_contact - tau_dist)/J_o;
  tau_contact = k_c*(theta_o - theta_wall) + b_c*omega_o;

  // Controlled load-change disturbance during middle third of 8 s scenario
  tau_dist = if time >= t_start and time <= t_end then tau_dist_val else 0.0;

  // Lumped thermal model driven by Joule loss
  der(T) = (i*i*R - (T - T_amb)/R_th)/C_th;

  // Primary tracking error (spring-torque tracking)
  tracking_err = tau_ref_val - tau_s;

  // Synchronized 80 Hz sensing and control
  when sample(0, Ts) then
    // Sensor traces
    theta_motor_side = theta_g;
    theta_load_side = theta_o;
    tau_s_meas = tau_s;
    i_meas = i;
    contact_meas = tau_contact;
    T_meas = T;
    theta_o_meas = theta_o;
    omega_o_meas = omega_o;

    // Outer spring-torque control -> current reference
    tau_err_d = tau_ref_val - tau_s;
    integ_t = max(-5.0, min(5.0, pre(integ_t) + tau_err_d*Ts));
    i_ref = Kp_t*tau_err_d + Ki_t*integ_t;

    // Inner current control -> voltage command with magnitude limit
    i_err_d = i_ref - i;
    integ_i = max(-20.0, min(20.0, pre(integ_i) + i_err_d*Ts));
    V_cmd = Kp_i*i_err_d + Ki_i*integ_i;
    V = max(-V_limit, min(V_limit, V_cmd));
  end when;

  // Physical, control, and estimator bounds
  assert(abs(V) <= V_supply + 1.0e-6, "Electrical voltage bound exceeded");
  assert(abs(i) <= I_bound, "Electrical current bound exceeded");
  assert(T <= T_bound, "Thermal bound exceeded");
  assert(abs(defl) <= defl_bound, "Transmission deflection bound exceeded");
  assert(abs(tau_contact) <= contact_bound, "Contact force bound exceeded");
  assert(time < track_time or abs(tracking_err) < track_bound,
         "Primary tracking error bound exceeded after 5.2 s");

  annotation (experiment(StartTime=0, StopTime=8, Tolerance=1.0e-6, Interval=0.0125));
end SeriesElasticTorqueA;