model BallScrewTorqueF
  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1e-4, Interval=0.002),
    Documentation(info="Electromechanical robotic actuator: 24 V motor driving an 18 kg carriage through a 5 mm-pitch ball screw with belt reduction, backlash, Coulomb friction. Cascaded current (inner) and force (outer) control. Compliant contact load. Disturbance of 21.8 N applied during the middle third of the 20 s run at 500 Hz. Values not specified by the requirement are marked (assumed); they are not stated facts.")
  );

  // --- Supply and limits ---
  parameter Real V_supply = 24.0 "V motor supply";
  parameter Real V_max = 29.3 "V voltage command limit";
  parameter Real I_max = 10.0 "A current command limit (assumed)";

  // --- Geometry / mechanical ---
  parameter Real m_carriage = 18.0 "kg";
  parameter Real pitch = 0.005 "m ball screw pitch";
  parameter Real travel = 0.65 "m carriage travel";
  parameter Real r_belt = 2.0 "belt reduction ratio (assumed, unknown per spec)";
  parameter Real eta_screw = 0.9 "ball screw efficiency (assumed)";
  parameter Real J_motor = 1e-5 "kg.m2 motor inertia (assumed)";
  parameter Real b_motor = 1e-6 "N.m.s motor viscous friction (assumed)";
  parameter Real k_trans = 1e6 "N/m transmission stiffness (assumed)";
  parameter Real c_trans = 200.0 "N.s/m transmission damping (assumed)";
  parameter Real backlash_b = 1e-3 "m backlash half-width (assumed)";
  parameter Real mu_c = 0.1 "Coulomb friction coefficient (assumed)";
  parameter Real g = 9.81 "m/s2";
  parameter Real F_coulomb = mu_c*m_carriage*g "N Coulomb friction magnitude";
  parameter Real k_contact = 5e4 "N/m contact stiffness (assumed)";
  parameter Real c_contact = 200.0 "N.s/m contact damping (assumed)";
  parameter Real x_contact = 0.30 "m load contact position (assumed)";
  parameter Real k_stop = 1e7 "N/m soft-stop stiffness (assumed)";
  parameter Real c_stop = 1e4 "N.s/m soft-stop damping (assumed)";

  // --- Electrical / thermal ---
  parameter Real R = 0.5 "ohm motor resistance (assumed)";
  parameter Real L = 5e-4 "H motor inductance (assumed)";
  parameter Real Kt = 0.05 "N.m/A torque constant (assumed)";
  parameter Real Ke = 0.05 "V.s/rad back-EMF constant (assumed)";
  parameter Real C_th = 300.0 "J/K thermal capacitance (assumed)";
  parameter Real R_th = 0.5 "K/W thermal resistance (assumed)";
  parameter Real T_amb = 25.0 "degC ambient (assumed)";

  // --- Control gains ---
  parameter Real Kp_i = 2.0 "current proportional gain (assumed)";
  parameter Real Ki_i = 20.0 "current integral gain (assumed)";
  parameter Real Kp_f = 0.2 "force proportional gain (assumed)";
  parameter Real Ki_f = 3.0 "force integral gain (assumed)";

  // --- Force command profile ---
  parameter Real F_bias = 30.0 "N force command bias (assumed)";
  parameter Real F_amp = 20.0 "N force command amplitude (assumed)";
  parameter Real f_cmd = 0.2 "Hz force command frequency (assumed)";

  // --- Disturbance ---
  parameter Real F_dist = 21.8 "N load change disturbance";
  parameter Real t1 = 6.667 "s middle-third start (20/3)";
  parameter Real t2 = 13.333 "s middle-third end (40/3)";

  // --- Dynamic states ---
  Real i(start=0.0) "A motor current";
  Real omega(start=0.0) "rad/s motor speed";
  Real theta(start=0.0) "rad motor angle";
  Real x(start=0.0) "m carriage position";
  Real v(start=0.0) "m/s carriage velocity";
  Real T_temp(start=T_amb) "degC motor winding temperature";
  Real z_i(start=0.0) "current-loop integrator state";
  Real z_f(start=0.0) "force-loop integrator state";

  // --- Observations / sensors ---
  Real V_motor "V applied motor voltage";
  Real V_cmd "V pre-limit commanded voltage";
  Real F_cmd "N commanded contact force";
  Real F_contact "N measured contact force";
  Real F_screw "N screw-side transmission force";
  Real F_load "N load-side transmission force";
  Real x_a "m motor-side linear equivalent position";
  Real v_a "m/s motor-side linear equivalent velocity";
  Real defl "m raw transmission deflection";
  Real defl_eff "m effective deflection after backlash";
  Real contact_active "1.0 if backlash closed, 0.0 if open";
  Real T_motor "N.m motor torque";
  Real T_screw "N.m screw torque";
  Real F_stop "N soft-stop force";
  Real F_dist_eff "N effective applied disturbance";
  Real i_cmd "A current command";
  Real i_cmd_raw "A pre-limit current command";
  Real e_i "A current error";
  Real e_f "N force error";
  Real track_err "N primary tracking error";

  // --- Verification flags ---
  Boolean bounds_ok "electrical/thermal/joint/transmission/contact bounds";
  Boolean tracking_ok "primary tracking error < 1.6 N after 13 s";
  Boolean finite_ok "no NaN or infinite physical/control/estimator values";

  constant Real pi = 3.14159265358979;

equation
  // --- Force command and disturbance ---
  F_cmd = F_bias + F_amp*sin(2*pi*f_cmd*time);
  F_dist_eff = if (time >= t1 and time <= t2) then F_dist else 0.0;

  // --- Outer force loop (force -> current command) ---
  e_f = F_cmd - F_contact;
  der(z_f) = e_f;
  i_cmd_raw = Kp_f*e_f + Ki_f*z_f;
  i_cmd = max(-I_max, min(I_max, i_cmd_raw));

  // --- Inner current loop (current -> voltage) with anti-windup ---
  e_i = i_cmd - i;
  V_cmd = Kp_i*e_i + Ki_i*z_i;
  der(z_i) = if (abs(V_cmd) <= V_max) then e_i else 0.0;
  V_motor = max(-V_max, min(V_max, V_cmd));

  // --- Motor electrical ---
  L*der(i) = V_motor - R*i - Ke*omega;
  T_motor = Kt*i;

  // --- Motor mechanical with belt reduction and ball screw ---
  T_screw = F_screw * pitch / (2*pi*eta_screw);
  J_motor*der(omega) = T_motor - b_motor*omega - T_screw/r_belt;
  der(theta) = omega;

  // --- Motor-side linear equivalent (both sides of compliance measured) ---
  x_a = theta * pitch / (2*pi*r_belt);
  v_a = omega * pitch / (2*pi*r_belt);

  // --- Transmission compliance with backlash ---
  defl = x_a - x;
  defl_eff = if defl > backlash_b then defl - backlash_b
             elseif defl < -backlash_b then defl + backlash_b
             else 0.0;
  contact_active = if (defl > backlash_b or defl < -backlash_b) then 1.0 else 0.0;
  F_screw = k_trans*defl_eff + c_trans*contact_active*(v_a - v);
  F_load = F_screw;

  // --- Carriage dynamics with Coulomb friction, contact, soft stops ---
  F_stop = if x < 0.0 then k_stop*(0.0 - x) - c_stop*v
           elseif x > travel then k_stop*(travel - x) - c_stop*v
           else 0.0;
  F_contact = if x > x_contact then k_contact*(x - x_contact) + c_contact*max(0.0, v) else 0.0;
  m_carriage*der(v) = F_load - F_coulomb*tanh(v/0.01) - F_contact - F_dist_eff + F_stop;
  der(x) = v;

  // --- Thermal model (joule heating) ---
  C_th*der(T_temp) = i*i*R - (T_temp - T_amb)/R_th;

  // --- Primary tracking error ---
  track_err = F_cmd - F_contact;

  // --- Verification criteria ---
  bounds_ok = (T_temp < 100.0) and
              (x >= -1e-3) and (x <= travel + 1e-3) and
              (abs(i) <= I_max + 1e-3) and
              (abs(V_motor) <= V_max + 1e-3) and
              (abs(defl_eff) <= 5e-3) and
              (F_contact >= -1e-3);
  tracking_ok = if time > 13.0 then abs(track_err) < 1.6 else true;
  finite_ok = (i == i) and (omega == omega) and (theta == theta) and
              (x == x) and (v == v) and (T_temp == T_temp) and
              (abs(i) < 1e6) and (abs(omega) < 1e6) and
              (abs(x) < 1e6) and (abs(T_temp) < 1e6);

end BallScrewTorqueF;