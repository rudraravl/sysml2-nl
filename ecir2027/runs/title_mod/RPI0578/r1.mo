model CableWinchPositionB
  // ===== Requirement-derived parameters =====
  parameter Real V_supply = 72 "V, motor supply";
  parameter Real V_max = 59 "V, allowed voltage command magnitude";
  parameter Real N_gear = 45 "gearbox ratio";
  parameter Real r_drum = 0.09 "m, drum radius";
  parameter Real m_payload = 140 "kg, payload mass";
  parameter Real L_travel = 12 "m, cable travel";
  parameter Real F_dist_amp = 5.6 "N, output load disturbance amplitude";
  parameter Real t_end = 10 "s, simulation duration";
  parameter Real t_settle = 6.5 "s, settling-time threshold";
  parameter Real err_thresh = 0.036 "m, tracking error bound after t_settle";
  parameter Real fs = 100 "Hz, control/sensor sample rate";
  parameter Real x_target = L_travel "m, target output position";
  parameter Real g = 9.81 "m/s^2";
  parameter Real x0 = 0.01 "m, initial payload position inside travel limits";

  // ===== Assumed motor/thermal parameters (UNSPECIFIED in requirement) =====
  parameter Real R = 0.3 "Ohm, armature resistance (assumed)";
  parameter Real L_arm = 1.0e-3 "H, armature inductance (assumed)";
  parameter Real Ke = 0.03 "V*s/rad, back-EMF constant (assumed)";
  parameter Real Kt = 0.05 "N*m/A, torque constant (assumed)";
  parameter Real J_motor = 1.0e-4 "kg*m^2, motor inertia (assumed)";
  parameter Real J_drum = 2.0e-2 "kg*m^2, drum inertia (assumed)";
  parameter Real b_motor = 1.0e-5 "N*m*s/rad, motor viscous friction (assumed)";
  parameter Real Kc = 1.0e5 "N/m, travel-limit contact stiffness (assumed)";
  parameter Real Dc = 1.0e3 "N*s/m, travel-limit contact damping (assumed)";
  parameter Real C_th = 200 "J/K, winding thermal capacitance (assumed)";
  parameter Real R_th = 0.5 "K/W, winding thermal resistance (assumed)";
  parameter Real T_amb = 293.15 "K, ambient temperature (assumed)";

  // ===== Bound placeholders (UNSPECIFIED in requirement) =====
  parameter Real I_max_bound = 1.0e6 "A, current bound - UNSPECIFIED, placeholder";
  parameter Real T_max_bound = 1.0e6 "K, temperature bound - UNSPECIFIED, placeholder";

  // ===== Control gains (assumed) =====
  parameter Real Kp_pos = 8.0 "position proportional gain";
  parameter Real Ki_pos = 4.0 "position integral gain";
  parameter Real Kp_curr = 4.0 "current proportional gain";
  parameter Real Ki_curr = 800.0 "current integral gain";

  // ===== Dynamic states =====
  Real i_motor(start=0, fixed=true) "A, motor armature current";
  Real omega_motor(start=0, fixed=true) "rad/s, motor shaft speed";
  Real theta_motor(start=x0*N_gear/r_drum, fixed=true) "rad, motor shaft angle";
  Real Temp_w(start=T_amb, fixed=true) "K, winding temperature";
  Real int_pos(start=0, fixed=true) "position-loop integrator";
  Real int_curr(start=0, fixed=true) "current-loop integrator";

  // ===== Kinematic / physical observables =====
  Real theta_drum "rad, drum angle";
  Real omega_drum "rad/s, drum speed";
  Real x_payload "m, payload position";
  Real v_payload "m/s, payload velocity";
  Real T_motor "N*m, motor electromagnetic torque";
  Real F_cable "N, cable tension";
  Real F_contact "N, travel-limit contact force on payload";
  Real F_dist "N, injected disturbance force on payload";

  // ===== Sensors (synchronized, sampled at 100 Hz via experiment interval) =====
  Real i_meas "A, measured current";
  Real x_meas "m, measured output position";
  Real v_meas "m/s, measured output velocity";
  Real temp_meas "K, measured winding temperature";

  // ===== Control signals =====
  Real err_pos "m, position error";
  Real i_command "A, current command from position loop";
  Real i_raw "A, raw current command";
  Real err_curr "A, current loop error";
  Real V_raw "V, raw voltage command before saturation";
  Real V_command "V, applied (saturated) voltage command";
  Real gravity_ff "A, gravity feedforward current";
  Boolean sat_pos "true when V_raw exceeds +V_max";
  Boolean sat_neg "true when V_raw below -V_max";
  Boolean frozen_pos "true when position integrator frozen by anti-windup";
  Boolean frozen_curr "true when current integrator frozen by anti-windup";

  // ===== Bound tracking =====
  Real i_abs "A, absolute measured current";
  Real final_err "m, final tracking error";

  // ===== Target drum angle =====
  Real theta_target = x_target / r_drum "rad, target drum angle";

equation
  // Kinematic relations through gearbox and drum
  theta_drum = theta_motor / N_gear;
  omega_drum = omega_motor / N_gear;
  x_payload = r_drum * theta_drum;
  v_payload = r_drum * omega_drum;
  der(theta_motor) = omega_motor;

  // Contact force at physical travel limits (collision modeled as stiff spring-damper)
  F_contact = if x_payload < 0.0 then -Kc*x_payload - Dc*v_payload
              elseif x_payload > L_travel then -Kc*(x_payload - L_travel) - Dc*v_payload
              else 0.0;

  // Disturbance injection during middle third of run
  F_dist = if (time > t_end/3.0) and (time < 2.0*t_end/3.0) then F_dist_amp else 0.0;

  // Cable tension consistent with payload force balance (massless cable, taut)
  F_cable = m_payload*g + F_dist - F_contact + m_payload*(r_drum/N_gear)*der(omega_motor);

  // Lumped drivetrain dynamics reflected to motor shaft
  (J_motor + J_drum/(N_gear^2) + m_payload*(r_drum^2)/(N_gear^2))*der(omega_motor)
    = T_motor - b_motor*omega_motor - (m_payload*g + F_dist - F_contact)*(r_drum/N_gear);

  // Motor electromechanical equations
  T_motor = Kt*i_motor;
  L_arm*der(i_motor) = V_command - R*i_motor - Ke*omega_motor;

  // Lumped winding thermal model
  C_th*der(Temp_w) = i_motor^2 * R - (Temp_w - T_amb)/R_th;

  // Sensors (ideal, no noise)
  i_meas = i_motor;
  x_meas = x_payload;
  v_meas = v_payload;
  temp_meas = Temp_w;

  // Gravity feedforward (tension feedforward cast to current)
  gravity_ff = (m_payload*g*r_drum/N_gear)/Kt;

  // ===== Outer position control loop (PI with anti-windup) =====
  err_pos = x_target - x_meas;
  i_raw = Kp_pos*err_pos + Ki_pos*int_pos + gravity_ff;
  i_command = i_raw; // current loop tracks this; no explicit current limit specified

  // ===== Inner current control loop (PI with anti-windup) =====
  err_curr = i_command - i_meas;
  V_raw = Kp_curr*err_curr + Ki_curr*int_curr + Ke*omega_motor; // back-EMF feedforward
  V_command = max(-V_max, min(V_max, V_raw));

  // Anti-windup: clamping integrators when voltage saturates in the error direction
  sat_pos = V_raw > V_max;
  sat_neg = V_raw < -V_max;
  frozen_curr = (sat_pos and err_curr > 0.0) or (sat_neg and err_curr < 0.0);
  frozen_pos = (sat_pos and err_pos > 0.0) or (sat_neg and err_pos < 0.0);

  der(int_curr) = if frozen_curr then 0.0 else err_curr;
  der(int_pos) = if frozen_pos then 0.0 else err_pos;

  // Bound-tracking observables
  i_abs = abs(i_meas);
  final_err = x_target - x_meas;

  // ===== Bounds =====
  assert(abs(V_command) <= V_max + 1.0e-6, "Voltage command bound violated");
  assert(i_abs <= I_max_bound, "Current bound violated (UNSPECIFIED bound placeholder)");
  assert(x_meas >= -1.0e-3 and x_meas <= L_travel + 1.0e-3, "Travel bound violated");
  assert(temp_meas <= T_max_bound, "Temperature bound violated (UNSPECIFIED bound placeholder)");
  assert((time < t_settle) or (abs(final_err) <= err_thresh), "Tracking error bound violated after settling");

  annotation (
    experiment(StartTime=0, StopTime=10, Tolerance=1.0e-6, Interval=0.01),
    Documentation(info="CableWinchPositionB: electromechanical cable-winch position control. A 72 V motor through a 45:1 gearbox and 0.09 m drum lifts a 140 kg payload over 12 m travel. Cascaded current (inner) and position (outer) PI control with clamping anti-windup and gravity feedforward commands voltage limited to 59 V. Travel limits and collision are represented as stiff spring-damper contacts. A 5.6 N downward load disturbance is injected during the middle third of the 10 s run. Voltage, current, travel, final-error, and temperature bounds are asserted; primary tracking error must fall below 0.036 m after 6.5 s. Motor, drum, contact, and thermal parameters not stated in the requirement are labeled (assumed)."),
    Diagram(graphics={Rectangle(extent={{-100,-100},{100,100}})}));
end CableWinchPositionB;