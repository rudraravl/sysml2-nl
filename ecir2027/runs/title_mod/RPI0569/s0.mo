model SeriesElasticTorqueE
  "Series elastic torque actuator with inner current and outer spring-torque control";

  // Requirement facts
  parameter Real V_supply = 48.0 "rated DC bus voltage [V]";
  parameter Real Vmax = 52.8 "commanded voltage bound [V]";
  parameter Real N = 100.0 "gearbox ratio";
  parameter Real k_s = 850.0 "torsional spring stiffness [N.m/rad]";
  parameter Real Dist = 18.0 "controlled load-change magnitude [N.m]";
  parameter Real Ts = 0.004 "control period [s], 250 Hz";
  parameter Real Tfinal = 16.0 "scenario duration [s]";
  parameter Real Taccept = 10.4 "tracking acceptance time [s]";
  parameter Real TrackingTol = 1.8 "primary tracking tolerance [N.m]";

  // Unknown physical placeholders; not stated in requirement, chosen only for simulation
  parameter Real R = 0.5 "motor winding resistance [Ohm]";
  parameter Real L = 0.005 "motor inductance [H]";
  parameter Real kT = 0.2 "motor torque constant [N.m/A]";
  parameter Real kE = 0.2 "back-EMF constant [V/(rad/s)]";
  parameter Real Jm = 1.0e-4 "motor inertia [kg.m2]";
  parameter Real Jl = 5.0 "load inertia [kg.m2]";
  parameter Real b_l = 5.0 "load viscous damping [N.m.s/rad]";
  parameter Real d_s = 50.0 "spring damping [N.m.s/rad]";
  parameter Real k_c = 5000.0 "contact stiffness [N.m/rad]";
  parameter Real d_c = 100.0 "contact damping [N.m.s/rad]";
  parameter Real theta_support = 0.0 "rigid support angle [rad]";
  parameter Real T_amb = 293.15 "ambient temperature [K]";
  parameter Real Cth = 200.0 "thermal capacitance [J/K]";
  parameter Real Rth = 2.0 "thermal resistance [K/W]";

  // Controller reference and gains (placeholders for unspecified command profile/tuning)
  parameter Real tau_cmd = 20.0 "commanded output torque [N.m], test reference";
  parameter Real Kp_i = 10.0 "inner current proportional gain";
  parameter Real Ki_i = 100.0 "inner current integral gain";
  parameter Real Kp_o = 3.0 "outer spring-torque proportional gain";
  parameter Real Ki_o = 20.0 "outer spring-torque integral gain";
  parameter Real Imax = 100.0 "current bound [A], placeholder";
  parameter Real Tau_max = 200.0 "commanded spring-torque bound [N.m], placeholder";

  // Acceptance bounds (placeholder values for bounds not specified by requirement)
  parameter Real Tmax = 353.15 "thermal bound [K]";
  parameter Real ThetaMax = 0.5 "output angle bound [rad]";
  parameter Real OmegaMax = 20.0 "output speed bound [rad/s]";
  parameter Real ThetaMotorMax = 100.0 "motor angle bound [rad]";
  parameter Real OmegaMotorMax = 5000.0 "motor speed bound [rad/s]";
  parameter Real DeflectionMax = 0.5 "spring deflection bound [rad]";
  parameter Real ContactMax = 2000.0 "contact torque bound [N.m]";

  // Continuous states
  Real i(start=0, unit="A") "motor current";
  Real omega_m(start=0, unit="rad/s") "motor speed";
  Real theta_m(start=0, unit="rad") "motor angle";
  Real omega_l(start=0, unit="rad/s") "output speed";
  Real theta_l(start=0, unit="rad") "output angle";
  Real T(start=293.15, unit="K") "winding temperature";

  // Discrete control states
  discrete Real v_cmd(start=0, unit="V") "commanded motor voltage";
  discrete Real i_ref(start=0, unit="A") "current reference";
  discrete Real tau_s_des(start=0, unit="N.m") "desired spring torque";
  discrete Real int_i(start=0, unit="A.s") "current integral state";
  discrete Real int_o(start=0, unit="N.m.s") "torque integral state";
  discrete Real e_t(start=0, unit="N.m") "spring-torque tracking error";
  discrete Real e_i(start=0, unit="A") "current error";
  discrete Real v_cmd_raw(start=0, unit="V") "unclamped voltage command";

  // Plant variables
  Real tau_motor(unit="N.m") "motor torque";
  Real theta_g(unit="rad") "gearbox-output angle";
  Real omega_g(unit="rad/s") "gearbox-output speed";
  Real tau_s(unit="N.m") "spring torque";
  Real tau_contact(unit="N.m") "contact torque";
  Real tau_dist(unit="N.m") "disturbance torque";
  Real alpha_m(unit="rad/s2") "motor acceleration";
  Real alpha_l(unit="rad/s2") "output acceleration";
  Real spring_deflection(unit="rad") "spring deflection";

  // Synchronized sensor traces
  Real sensor_current(unit="A") = i;
  Real sensor_gear_angle(unit="rad") = theta_g;
  Real sensor_gear_speed(unit="rad/s") = omega_g;
  Real sensor_load_angle(unit="rad") = theta_l;
  Real sensor_load_speed(unit="rad/s") = omega_l;
  Real sensor_spring_torque_gear(unit="N.m") = tau_s;
  Real sensor_spring_torque_load(unit="N.m") = tau_s;
  Real sensor_contact_torque(unit="N.m") = tau_contact;
  Real sensor_temperature(unit="K") = T;

  // Acceptance flags
  Boolean electricalOK;
  Boolean thermalOK;
  Boolean jointOK;
  Boolean transmissionOK;
  Boolean contactOK;
  Boolean finiteOK;
  Boolean trackingOK;
  Boolean acceptanceOK;

equation
  // Electrical dynamics
  der(i) = (v_cmd - R*i - kE*omega_m)/L;
  tau_motor = kT*i;

  // Motor mechanical dynamics
  alpha_m = (tau_motor - tau_s/N)/Jm;
  der(omega_m) = alpha_m;
  der(theta_m) = omega_m;

  // Gearbox
  theta_g = theta_m/N;
  omega_g = omega_m/N;

  // Series-elastic transmission, instrumented on both sides
  spring_deflection = theta_g - theta_l;
  tau_s = k_s*spring_deflection + d_s*(omega_g - omega_l);

  // Compliant load contact with rigid support
  tau_contact = k_c*(theta_l - theta_support) + d_c*omega_l;

  // Middle-third controlled load-change disturbance
  tau_dist = if (time >= 16.0/3.0) and (time <= 32.0/3.0) then Dist else 0.0;

  // Output/load dynamics
  alpha_l = (tau_s - tau_contact - tau_dist - b_l*omega_l)/Jl;
  der(omega_l) = alpha_l;
  der(theta_l) = omega_l;

  // Thermal dynamics
  der(T) = (R*i*i - (T - T_amb)/Rth)/Cth;

  // Discrete controller at 250 Hz
  when sample(0, Ts) then
    e_t = tau_cmd - tau_s;
    int_o = if abs(pre(tau_s_des)) >= Tau_max and e_t*pre(tau_s_des) > 0.0 then pre(int_o) else pre(int_o) + Ts*e_t;
    tau_s_des = max(min(tau_cmd + Kp_o*e_t + Ki_o*int_o, Tau_max), -Tau_max);
    i_ref = max(min(tau_s_des/(N*kT), Imax), -Imax);
    e_i = i_ref - i;
    int_i = if abs(pre(v_cmd)) >= Vmax and e_i*pre(v_cmd) > 0.0 then pre(int_i) else pre(int_i) + Ts*e_i;
    v_cmd_raw = Kp_i*e_i + Ki_i*int_i + kE*omega_m;
    v_cmd = max(min(v_cmd_raw, Vmax), -Vmax);
  end when;

  // Fail-closed acceptance checks
  electricalOK = abs(v_cmd) <= Vmax + 1.0e-6 and abs(i) <= Imax;
  thermalOK = T <= Tmax;
  jointOK = abs(theta_l) <= ThetaMax and abs(omega_l) <= OmegaMax and abs(theta_m) <= ThetaMotorMax and abs(omega_m) <= OmegaMotorMax;
  transmissionOK = abs(spring_deflection) <= DeflectionMax;
  contactOK = abs(tau_contact) <= ContactMax;
  finiteOK = noEvent(abs(i) <= 1.0e300 and abs(omega_m) <= 1.0e300 and abs(theta_m) <= 1.0e300 and abs(omega_l) <= 1.0e300 and abs(theta_l) <= 1.0e300 and abs(T) <= 1.0e300 and abs(tau_s) <= 1.0e300 and abs(tau_contact) <= 1.0e300 and abs(v_cmd) <= 1.0e300 and abs(i_ref) <= 1.0e300 and abs(tau_s_des) <= 1.0e300);
  trackingOK = if time >= Taccept then abs(tau_cmd - tau_s) <= TrackingTol else true;
  acceptanceOK = electricalOK and thermalOK and jointOK and transmissionOK and contactOK and finiteOK and trackingOK;

  assert(electricalOK, "Electrical bound violated (fail-closed)", AssertionLevel.error);
  assert(thermalOK, "Thermal bound violated (fail-closed)", AssertionLevel.error);
  assert(jointOK, "Joint bound violated (fail-closed)", AssertionLevel.error);
  assert(transmissionOK, "Transmission deflection bound violated (fail-closed)", AssertionLevel.error);
  assert(contactOK, "Contact force bound violated (fail-closed)", AssertionLevel.error);
  assert(finiteOK, "NaN or infinite physical, control, or estimator value detected (fail-closed)", AssertionLevel.error);
  assert(trackingOK, "Primary tracking error bound violated after 10.4 s (fail-closed)", AssertionLevel.error);
  assert(acceptanceOK, "Overall acceptance violated (fail-closed)", AssertionLevel.error);

  annotation (
    experiment(StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Standalone series-elastic torque actuator. Values not stated in the requirement are placeholders labelled in comments."));
end SeriesElasticTorqueE;