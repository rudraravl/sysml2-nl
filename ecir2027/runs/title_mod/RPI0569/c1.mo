model SeriesElasticTorqueE
  "Series elastic torque actuator with inner current and outer spring torque control";

  // Requirement-stated parameters
  parameter Real V_supply = 48.0 "rated DC bus voltage V";
  parameter Real Vmax = 52.8 "commanded voltage bound V";
  parameter Real N = 100.0 "gearbox ratio";
  parameter Real k_s = 850.0 "torsional spring stiffness N.m/rad";
  parameter Real Dist = 18.0 "controlled load change magnitude N.m";
  parameter Real Ts = 0.004 "control period s at 250 Hz";
  parameter Real Tfinal = 16.0 "scenario duration s";
  parameter Real Taccept = 10.4 "tracking acceptance time s";
  parameter Real TrackingTol = 1.8 "primary tracking tolerance N.m";

  // Placeholder physical parameters not stated in requirement
  parameter Real R_motor = 0.5 "motor winding resistance Ohm";
  parameter Real L_motor = 0.005 "motor inductance H";
  parameter Real kT = 0.2 "motor torque constant N.m/A";
  parameter Real kE = 0.2 "back EMF constant V.s/rad";
  parameter Real Jm = 1.0e-4 "motor inertia kg.m2";
  parameter Real Jl = 5.0 "load inertia kg.m2";
  parameter Real b_l = 5.0 "load viscous damping N.m.s/rad";
  parameter Real d_s = 50.0 "spring damping N.m.s/rad";
  parameter Real k_c = 5000.0 "contact stiffness N.m/rad";
  parameter Real d_c = 100.0 "contact damping N.m.s/rad";
  parameter Real theta_support = 0.0 "rigid support angle rad";
  parameter Real T_amb = 293.15 "ambient temperature K";
  parameter Real Cth = 200.0 "thermal capacitance J/K";
  parameter Real Rth = 2.0 "thermal resistance K/W";

  // Controller reference and gains placeholders
  parameter Real tau_cmd = 20.0 "commanded output torque N.m test reference";
  parameter Real Kp_i = 10.0 "inner current proportional gain";
  parameter Real Ki_i = 100.0 "inner current integral gain";
  parameter Real Kp_o = 3.0 "outer spring torque proportional gain";
  parameter Real Ki_o = 20.0 "outer spring torque integral gain";
  parameter Real Imax = 100.0 "current bound A placeholder";
  parameter Real Tau_max = 200.0 "commanded spring torque bound N.m placeholder";

  // Acceptance bounds placeholders
  parameter Real Tmax_bound = 353.15 "thermal bound K";
  parameter Real ThetaMax = 0.5 "output angle bound rad";
  parameter Real OmegaMax = 20.0 "output speed bound rad/s";
  parameter Real ThetaMotorMax = 100.0 "motor angle bound rad";
  parameter Real OmegaMotorMax = 5000.0 "motor speed bound rad/s";
  parameter Real DeflectionMax = 0.5 "spring deflection bound rad";
  parameter Real ContactMax = 2000.0 "contact torque bound N.m";

  // Continuous states
  Real i_motor(start = 0.0, unit = "A") "motor current";
  Real omega_m(start = 0.0, unit = "rad/s") "motor speed";
  Real theta_m(start = 0.0, unit = "rad") "motor angle";
  Real omega_l(start = 0.0, unit = "rad/s") "output speed";
  Real theta_l(start = 0.0, unit = "rad") "output angle";
  Real T_winding(start = 293.15, unit = "K") "winding temperature";

  // Discrete control states
  discrete Real v_cmd(start = 0.0) "commanded motor voltage V";
  discrete Real i_ref(start = 0.0) "current reference A";
  discrete Real tau_s_des(start = 0.0) "desired spring torque N.m";
  discrete Real int_i(start = 0.0) "current integral state A.s";
  discrete Real int_o(start = 0.0) "torque integral state N.m.s";
  discrete Real e_t(start = 0.0) "spring torque tracking error N.m";
  discrete Real e_i(start = 0.0) "current error A";
  discrete Real v_cmd_raw(start = 0.0) "unclamped voltage command V";

  // Plant variables
  Real tau_motor "motor torque N.m";
  Real theta_g "gearbox output angle rad";
  Real omega_g "gearbox output speed rad/s";
  Real tau_s "spring torque N.m";
  Real tau_contact "contact torque N.m";
  Real tau_dist "disturbance torque N.m";
  Real spring_deflection "spring deflection rad";

  // Synchronized sensor traces
  Real sensor_current "measured motor current A";
  Real sensor_gear_angle "gear side angle rad";
  Real sensor_gear_speed "gear side speed rad/s";
  Real sensor_load_angle "load side angle rad";
  Real sensor_load_speed "load side speed rad/s";
  Real sensor_spring_torque_gear "spring torque gear side N.m";
  Real sensor_spring_torque_load "spring torque load side N.m";
  Real sensor_contact_torque "contact torque N.m";
  Real sensor_temperature "winding temperature K";

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
  der(i_motor) = (v_cmd - R_motor * i_motor - kE * omega_m) / L_motor;
  tau_motor = kT * i_motor;

  // Motor mechanical dynamics
  der(omega_m) = (tau_motor - tau_s / N) / Jm;
  der(theta_m) = omega_m;

  // Gearbox
  theta_g = theta_m / N;
  omega_g = omega_m / N;

  // Series elastic transmission instrumented on both sides
  spring_deflection = theta_g - theta_l;
  tau_s = k_s * spring_deflection + d_s * (omega_g - omega_l);

  // Compliant load contact with rigid support
  tau_contact = k_c * (theta_l - theta_support) + d_c * omega_l;

  // Middle third controlled load change disturbance
  tau_dist = if (time >= 16.0 / 3.0) and (time <= 32.0 / 3.0) then Dist else 0.0;

  // Output load dynamics
  der(omega_l) = (tau_s - tau_contact - tau_dist - b_l * omega_l) / Jl;
  der(theta_l) = omega_l;

  // Thermal dynamics
  der(T_winding) = (R_motor * i_motor * i_motor - (T_winding - T_amb) / Rth) / Cth;

  // Sensor traces
  sensor_current = i_motor;
  sensor_gear_angle = theta_g;
  sensor_gear_speed = omega_g;
  sensor_load_angle = theta_l;
  sensor_load_speed = omega_l;
  sensor_spring_torque_gear = tau_s;
  sensor_spring_torque_load = tau_s;
  sensor_contact_torque = tau_contact;
  sensor_temperature = T_winding;

  // Discrete controller at 250 Hz
  when sample(0, Ts) then
    e_t = tau_cmd - tau_s;
    int_o = if (abs(pre(tau_s_des)) >= Tau_max) and (e_t * pre(tau_s_des) > 0.0) then pre(int_o) else pre(int_o) + Ts * e_t;
    tau_s_des = max(min(tau_cmd + Kp_o * e_t + Ki_o * int_o, Tau_max), -Tau_max);
    i_ref = max(min(tau_s_des / (N * kT), Imax), -Imax);
    e_i = i_ref - i_motor;
    int_i = if (abs(pre(v_cmd)) >= Vmax) and (e_i * pre(v_cmd) > 0.0) then pre(int_i) else pre(int_i) + Ts * e_i;
    v_cmd_raw = Kp_i * e_i + Ki_i * int_i + kE * omega_m;
    v_cmd = max(min(v_cmd_raw, Vmax), -Vmax);
  end when;

  // Fail closed acceptance checks
  electricalOK = abs(v_cmd) <= Vmax + 1.0e-6 and abs(i_motor) <= Imax;
  thermalOK = T_winding <= Tmax_bound;
  jointOK = abs(theta_l) <= ThetaMax and abs(omega_l) <= OmegaMax and abs(theta_m) <= ThetaMotorMax and abs(omega_m) <= OmegaMotorMax;
  transmissionOK = abs(spring_deflection) <= DeflectionMax;
  contactOK = abs(tau_contact) <= ContactMax;
  finiteOK = noEvent(abs(i_motor) < 1.0e300 and abs(omega_m) < 1.0e300 and abs(theta_m) < 1.0e300 and abs(omega_l) < 1.0e300 and abs(theta_l) < 1.0e300 and abs(T_winding) < 1.0e300 and abs(tau_s) < 1.0e300 and abs(tau_contact) < 1.0e300 and abs(v_cmd) < 1.0e300 and abs(i_ref) < 1.0e300 and abs(tau_s_des) < 1.0e300);
  trackingOK = if time >= Taccept then abs(tau_cmd - tau_s) <= TrackingTol else true;
  acceptanceOK = electricalOK and thermalOK and jointOK and transmissionOK and contactOK and finiteOK and trackingOK;

  assert(electricalOK, "Electrical bound violated fail closed", AssertionLevel.error);
  assert(thermalOK, "Thermal bound violated fail closed", AssertionLevel.error);
  assert(jointOK, "Joint bound violated fail closed", AssertionLevel.error);
  assert(transmissionOK, "Transmission deflection bound violated fail closed", AssertionLevel.error);
  assert(contactOK, "Contact force bound violated fail closed", AssertionLevel.error);
  assert(finiteOK, "NaN or infinite value detected fail closed", AssertionLevel.error);
  assert(trackingOK, "Primary tracking error bound violated after 10.4 s fail closed", AssertionLevel.error);
  assert(acceptanceOK, "Overall acceptance violated fail closed", AssertionLevel.error);

  annotation(experiment(StopTime = 16, Tolerance = 1e-6, Interval = 0.004));
end SeriesElasticTorqueE;