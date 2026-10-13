model BallScrewTorqueE
  "Electromechanical ball-screw actuator tracking a contact-force command against a compliant load."

  parameter Real V_supply = 24.0 "V motor supply";
  parameter Real V_max = 26.4 "V command magnitude bound";
  parameter Real m_c = 18.0 "kg carriage mass";
  parameter Real lead = 0.005 "m ball-screw lead";
  parameter Real travel = 0.65 "m carriage travel";
  parameter Real F_dist = 18.0 "N load disturbance magnitude";
  parameter Real Ts = 0.004 "s control period 250 Hz";
  parameter Real t_end = 16.0 "s run duration";
  parameter Real t_track = 10.4 "s tracking-error gate time";
  parameter Real e_track_max = 1.8 "N tracking-error bound after 10.4 s";

  parameter Real R = 1.5 "Ohm winding resistance";
  parameter Real Lw = 0.005 "H winding inductance";
  parameter Real Kt = 0.05 "N.m/A torque constant";
  parameter Real Ke = 0.05 "V.s/rad back-EMF constant";
  parameter Real Jm = 1.0e-4 "kg.m2 motor inertia";
  parameter Real bm = 1.0e-5 "N.m.s/rad motor viscous friction";
  parameter Real N = 2.0 "belt reduction ratio";
  parameter Real Js = 5.0e-4 "kg.m2 screw inertia";

  parameter Real k_s = 800.0 "N.m/rad transmission torsional stiffness";
  parameter Real d_s = 0.8 "N.m.s/rad transmission torsional damping";
  parameter Real bl = 0.015 "rad backlash half-width";

  parameter Real k_contact = 2.0e4 "N/m contact stiffness";
  parameter Real d_contact = 80.0 "N.s/m contact damping";
  parameter Real m_l = 6.0 "kg load mass";
  parameter Real k_load = 5.0e3 "N/m load-to-ground compliance";
  parameter Real d_load = 30.0 "N.s/m load-to-ground damping";

  parameter Real Fc = 2.5 "N Coulomb friction magnitude";
  parameter Real mus = 1.0e-3 "m/s Stribeck velocity smoothing";
  parameter Real bc = 1.0 "N.s/m carriage viscous friction";

  parameter Real R_th = 2.5 "K/W thermal resistance";
  parameter Real C_th = 120.0 "J/K thermal capacitance";
  parameter Real T_amb = 293.15 "K ambient temperature";
  parameter Real T_max = 353.15 "K thermal bound";

  parameter Real Kp_F = 1.0e-3 "m/N outer force proportional";
  parameter Real Ki_F = 5.0e-3 "m/(N.s) outer force integral";
  parameter Real Kp_x = 200.0 "A/m position proportional";
  parameter Real Ki_x = 800.0 "A/(m.s) position integral";
  parameter Real Kp_i = 4.0 "V/A current proportional";
  parameter Real Ki_i = 60.0 "V/(A.s) current integral";

  Real i(start=0.0) "A motor current";
  Real omega_m(start=0.0) "rad/s motor angular speed";
  Real theta_m(start=0.0) "rad motor angle";
  Real omega_s(start=0.0) "rad/s screw angular speed";
  Real theta_s(start=0.0) "rad screw angle";
  Real v_l(start=0.0) "m/s load velocity";
  Real x_l(start=0.0) "m load position";
  Real T_temp(start=293.15) "K motor winding temperature";

  Real integ_F(start=0.0) "N.s force-loop integrator";
  Real integ_x(start=0.0) "m.s position-loop integrator";
  Real integ_i(start=0.0) "A.s current-loop integrator";
  Real x_cmd(start=0.0) "m position command from outer loop";
  Real i_cmd(start=0.0) "A current command from position loop";
  Real V_cmd_raw(start=0.0) "V unsaturated voltage command";
  Real V_motor(start=0.0) "V applied motor voltage";

  Real x_a "m motor-side equivalent linear position";
  Real x_s "m screw output linear position";
  Real v_s "m/s screw output linear velocity";
  Real x_c "m carriage position";
  Real v_c "m/s carriage velocity";
  Real delta "rad angular deflection across transmission";
  Real delta_eff "rad effective deflection after backlash deadzone";
  Real T_spring "N.m transmission spring torque";
  Real F_friction "N carriage Coulomb plus viscous friction";
  Real F_contact "N contact force between carriage and load";
  Real F_disturbance "N applied load disturbance";
  Real P_loss "W motor copper loss";
  Real F_cmd "N force command";
  Real F_meas "N measured contact force";
  Real e_F "N primary tracking error";
  Real sgn_v "smooth sign of carriage velocity";

equation
  F_cmd = if time < 1.0 then 25.0 * time else 25.0;

  F_disturbance = if (time >= 16.0 / 3.0 and time <= 32.0 / 3.0) then F_dist else 0.0;

  Lw * der(i) = V_motor - R * i - Ke * omega_m;

  Jm * der(omega_m) = Kt * i - bm * omega_m - T_spring / N;
  der(theta_m) = omega_m;

  delta = theta_m / N - theta_s;
  delta_eff = if delta > bl then delta - bl else if delta < (-bl) then delta + bl else 0.0;
  T_spring = k_s * delta_eff + d_s * (omega_m / N - omega_s);

  x_c = theta_s * lead / (2.0 * Modelica.Constants.pi);
  v_c = omega_s * lead / (2.0 * Modelica.Constants.pi);
  x_s = x_c;
  v_s = v_c;
  x_a = (theta_m / N) * lead / (2.0 * Modelica.Constants.pi);

  sgn_v = v_c / (abs(v_c) + mus);
  F_friction = Fc * sgn_v + bc * v_c;

  F_contact = k_contact * (x_c - x_l) + d_contact * (v_c - v_l);

  (Js + m_c * (lead / (2.0 * Modelica.Constants.pi)) * (lead / (2.0 * Modelica.Constants.pi))) * der(omega_s) = T_spring - (F_contact + F_friction) * lead / (2.0 * Modelica.Constants.pi);
  der(theta_s) = omega_s;

  m_l * der(v_l) = F_contact + F_disturbance - k_load * x_l - d_load * v_l;
  der(x_l) = v_l;

  P_loss = i * i * R;
  C_th * der(T_temp) = P_loss - (T_temp - T_amb) / R_th;

  F_meas = F_contact;
  e_F = F_cmd - F_meas;

  when sample(0, Ts) then
    integ_F = pre(integ_F) + (F_cmd - F_contact) * Ts;
    x_cmd = Kp_F * (F_cmd - F_contact) + Ki_F * pre(integ_F) + Ki_F * (F_cmd - F_contact) * Ts;
    integ_x = pre(integ_x) + (x_cmd - x_c) * Ts;
    i_cmd = Kp_x * (x_cmd - x_c) + Ki_x * pre(integ_x) + Ki_x * (x_cmd - x_c) * Ts;
    integ_i = pre(integ_i) + (i_cmd - i) * Ts;
    V_cmd_raw = Kp_i * (i_cmd - i) + Ki_i * pre(integ_i) + Ki_i * (i_cmd - i) * Ts;
    V_motor = max(-V_max, min(V_max, V_cmd_raw));
  end when;

  assert(abs(V_motor) <= V_max + 1.0e-6, "Electrical voltage bound violated");
  assert(abs(i) <= 30.0, "Electrical current bound violated");
  assert(T_temp <= T_max, "Thermal bound violated");
  assert(x_c >= -0.01 and x_c <= travel + 0.01, "Joint travel bound violated");
  assert(abs(x_a - x_s) <= 0.02, "Transmission deflection bound violated");
  assert(abs(F_contact) <= 300.0, "Contact force bound violated");
  assert(time < t_track or abs(e_F) <= e_track_max, "Primary tracking error bound violated after 10.4 s");

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1.0e-5, Interval = 0.004),
    Documentation(info = "Ball-screw actuator tracking a contact-force command against a compliant load."));
end BallScrewTorqueE;