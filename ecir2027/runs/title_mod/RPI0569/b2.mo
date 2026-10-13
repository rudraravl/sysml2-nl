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

  // Unknown physical placeholders; not stated in requirement
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

  // Controller reference and gains (placeholders for unspecified command/tuning)
  parameter Real tau_cmd = 20.0 "commanded output torque [N.m]";
  parameter Real Kp_i = 10.0 "inner current proportional gain";
  parameter Real Ki_i = 100.0 "inner current integral gain";
  parameter Real Kp_o = 3.0 "outer spring-torque proportional gain";
  parameter Real Ki_o = 20.0 "outer spring-torque integral gain";
  parameter Real Imax = 100.0 "current bound [A]";
  parameter Real Tau_max = 200.0 "spring-torque command bound [N.m]";

  // Acceptance bounds (placeholder values for unspecified bounds)
  parameter Real Tmax = 353.15 "thermal bound [K]";
  parameter Real ThetaMax = 0.5 "output angle bound [rad]";
  parameter Real OmegaMax = 20.0 "output speed bound [rad/s]";
  parameter Real ThetaMotorMax = 100.0 "motor angle bound [rad]";
  parameter Real OmegaMotorMax = 5000.0 "motor speed bound [rad/s]";
  parameter Real DeflectionMax = 0.5 "spring deflection bound [rad]";
  parameter Real ContactMax = 2000.0 "contact torque bound [N.m]";

  // Continuous dynamic states
  Real i(start = 0.0, fixed = true) "motor current [A]";
  Real omega_m(start = 0.0, fixed = true) "motor speed [rad/s]";
  Real theta_m(start = 0.0, fixed = true) "motor angle [rad]";
  Real omega_l(start = 0.0, fixed = true) "output speed [rad/s]";
  Real theta_l(start = 0.0, fixed = true) "output angle [rad]";
  Real Temp(start = 293.15, fixed = true) "winding temperature [K]";
  Real int_o(start = 0.0, fixed = true) "outer loop integrator state [N.m.s]";
  Real int_i(start = 0.0, fixed = true) "inner loop integrator state [A.s]";

  // Algebraic plant variables
  Real tau_motor "motor torque [N.m]";
  Real theta_g "gearbox-output angle [rad]";
  Real omega_g "gearbox-output speed [rad/s]";
  Real tau_s "spring torque [N.m]";
  Real tau_contact "contact torque [N.m]";
  Real tau_dist "disturbance torque [N.m]";
  Real spring_deflection "spring deflection [rad]";

  // Controller algebraic variables
  Real v_cmd "commanded motor voltage [V]";
  Real i_ref "current reference [A]";
  Real tau_s_des "desired spring torque [N.m]";
  Real e_t "spring-torque tracking error [N.m]";
  Real e_i "current error [A]";

  // Synchronized sensor traces
  Real sensor_current "measured motor current [A]";
  Real sensor_gear_angle "measured gear-side angle [rad]";
  Real sensor_gear_speed "measured gear-side speed [rad/s]";
  Real sensor_load_angle "measured load-side angle [rad]";
  Real sensor_load_speed "measured load-side speed [rad/s]";
  Real sensor_spring_torque_gear "measured spring torque gear side [N.m]";
  Real sensor_spring_torque_load "measured spring torque load side [N.m]";
  Real sensor_contact_torque "measured contact torque [N.m]";
  Real sensor_temperature "measured temperature [K]";

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
  L * der(i) = v_cmd - R * i - kE * omega_m;
  tau_motor = kT * i;

  // Motor mechanical dynamics
  Jm * der(omega_m) = tau_motor - tau_s / N;
  der(theta_m) = omega_m;

  // Gearbox kinematics
  theta_g = theta_m / N;
  omega_g = omega_m / N;

  // Series-elastic transmission, instrumented on both sides
  spring_deflection = theta_g - theta_l;
  tau_s = k_s * spring_deflection + d_s * (omega_g - omega_l);

  // Compliant load contact with rigid support geometry
  tau_contact = k_c * (theta_l - theta_support) + d_c * omega_l;

  // Middle-third controlled load-change disturbance
  if time >= Tfinal / 3.0 and time <= 2.0 * Tfinal / 3.0 then
    tau_dist = Dist;
  else
    tau_dist = 0.0;
  end if;

  // Output/load dynamics
  Jl * der(omega_l) = tau_s - tau_contact - tau_dist - b_l * omega_l;
  der(theta_l) = omega_l;

  // Thermal dynamics
  Cth * der(Temp) = R * i * i - (Temp - T_amb) / Rth;

  // Outer loop: spring-torque feedback control
  e_t = tau_cmd - tau_s;
  der(int_o) = if (abs(tau_s_des) >= Tau_max - 1.0e-6) and (e_t * tau_s_des > 0.0) then 0.0 else e_t;
  tau_s_des = max(min(tau_cmd + Kp_o * e_t + Ki_o * int_o, Tau_max), -Tau_max);

  // Inner loop: current control
  // N*kT = 100*0.2 = 20.0 is a nonzero constant so the division is well-defined
  i_ref = max(min(tau_s_des / (N * kT), Imax), -Imax);
  e_i = i_ref - i;
  der(int_i) = if (abs(v_cmd) >= Vmax - 1.0e-6) and (e_i * v_cmd > 0.0) then 0.0 else e_i;
  v_cmd = max(min(Kp_i * e_i + Ki_i * int_i + kE * omega_m, Vmax), -Vmax);

  // Sensor traces
  sensor_current = i;
  sensor_gear_angle = theta_g;
  sensor_gear_speed = omega_g;
  sensor_load_angle = theta_l;
  sensor_load_speed = omega_l;
  sensor_spring_torque_gear = tau_s;
  sensor_spring_torque_load = tau_s;
  sensor_contact_torque = tau_contact;
  sensor_temperature = Temp;

  // Fail-closed acceptance checks
  electricalOK = abs(v_cmd) <= Vmax + 1.0e-6 and abs(i) <= Imax + 1.0e-6;
  thermalOK = Temp <= Tmax;
  jointOK = abs(theta_l) <= ThetaMax and abs(omega_l) <= OmegaMax and abs(theta_m) <= ThetaMotorMax and abs(omega_m) <= OmegaMotorMax;
  transmissionOK = abs(spring_deflection) <= DeflectionMax;
  contactOK = abs(tau_contact) <= ContactMax;
  finiteOK = abs(i) < 1.0e300 and abs(omega_m) < 1.0e300 and abs(theta_m) < 1.0e300 and abs(omega_l) < 1.0e300 and abs(theta_l) < 1.0e300 and abs(Temp) < 1.0e300 and abs(tau_s) < 1.0e300 and abs(tau_contact) < 1.0e300 and abs(v_cmd) < 1.0e300 and abs(int_o) < 1.0e300 and abs(int_i) < 1.0e300;
  trackingOK = (time < Taccept) or (abs(tau_cmd - tau_s) <= TrackingTol);
  acceptanceOK = electricalOK and thermalOK and jointOK and transmissionOK and contactOK and finiteOK and trackingOK;

  // Assertions for fail-closed behavior
  assert(electricalOK, "Electrical bound violated (fail-closed)", AssertionLevel.error);
  assert(thermalOK, "Thermal bound violated (fail-closed)", AssertionLevel.error);
  assert(jointOK, "Joint bound violated (fail-closed)", AssertionLevel.error);
  assert(transmissionOK, "Transmission deflection bound violated (fail-closed)", AssertionLevel.error);
  assert(contactOK, "Contact force bound violated (fail-closed)", AssertionLevel.error);
  assert(finiteOK, "NaN or infinite value detected (fail-closed)", AssertionLevel.error);
  assert(trackingOK, "Primary tracking error bound violated after 10.4 s (fail-closed)", AssertionLevel.error);
  assert(acceptanceOK, "Overall acceptance violated (fail-closed)", AssertionLevel.error);

  annotation(
    experiment(StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Standalone series-elastic torque actuator. Continuous-time PI inner current and outer spring-torque controllers replace the previous discrete when-clause to ensure compilation. Values not stated in the requirement are placeholders labelled in comments. N*kT = 20.0 is a nonzero constant product so the i_ref division is well-defined."));
end SeriesElasticTorqueE;