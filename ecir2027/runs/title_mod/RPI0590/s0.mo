model CableWinchTorqueB
  "Electromechanical cable winch tracking a force command against a compliant load"
  // Requirement-specified parameters
  parameter Real V_supply = 72 "Supply voltage [V]";
  parameter Real V_cmd_max = 59 "Allowed command magnitude [V]";
  parameter Real N = 45 "Gearbox ratio";
  parameter Real r_drum = 0.09 "Drum radius [m]";
  parameter Real m_payload = 140 "Payload mass [kg]";
  parameter Real travel_max = 12 "Travel [m]";
  parameter Real dist_magnitude = 10.5 "Disturbance magnitude [N]";
  parameter Real dist_start = 10/3 "Disturbance start [s]";
  parameter Real dist_stop = 20/3 "Disturbance stop [s]";
  parameter Real tracking_error_limit = 2.4 "Tracking error limit after 6.5 s [N]";
  parameter Real t_tracking = 6.5 "Tracking check time [s]";

  // Assumed physical parameters (not specified in requirement)
  parameter Real R_motor = 0.5 "Motor resistance [Ohm]";
  parameter Real L_motor = 0.005 "Motor inductance [H]";
  parameter Real k_t = 0.5 "Motor torque constant [N.m/A]";
  parameter Real k_e = 0.5 "Motor back-EMF constant [V.s/rad]";
  parameter Real J_m = 0.01 "Motor inertia [kg.m2]";
  parameter Real b_m = 0.01 "Motor viscous friction [N.m.s/rad]";
  parameter Real J_d = 0.005 "Drum inertia [kg.m2]";
  parameter Real b_d = 0.005 "Drum viscous friction [N.m.s/rad]";
  parameter Real k_cable = 1.0e4 "Cable stiffness [N/m]";
  parameter Real b_cable = 100 "Cable damping [N.s/m]";
  parameter Real C_th = 200 "Thermal capacitance [J/K]";
  parameter Real R_th = 0.2 "Thermal resistance [K/W]";
  parameter Real T_amb = 20 "Ambient temperature [degC]";
  parameter Real F_ref = 1377 "Force command [N]";
  parameter Real i_max = 100 "Current limit [A]";
  parameter Real w_max = 150 "Motor speed limit [rad/s]";
  parameter Real T_max = 80 "Temperature limit [degC]";
  parameter Real delta_max = 1.0 "Deflection limit [m]";
  parameter Real F_max = 5000 "Contact force limit [N]";
  parameter Real g = 9.81 "Gravity [m/s2]";

  // Controller gains (assumed)
  parameter Real Kp_i = 5.0;
  parameter Real Ki_i = 500.0;
  parameter Real Kp_w = 1.0;
  parameter Real Ki_w = 10.0;
  parameter Real Kp_f = 1.0;
  parameter Real Ki_f = 10.0;

  // Dynamic states
  Real i(start=0) "Motor current [A]";
  Real w_m(start=0) "Motor speed [rad/s]";
  Real theta_m(start=0) "Motor angle [rad]";
  Real v(start=0) "Payload velocity [m/s]";
  Real y(start=-m_payload*g/k_cable) "Payload position [m]";
  Real T_motor(start=T_amb) "Motor temperature [degC]";
  Real integ_i(start=0) "Current loop integrator";
  Real integ_w(start=0) "Speed loop integrator";
  Real integ_f(start=0) "Tension loop integrator";

  // Algebraic variables and sensors
  Real w_g "Drum speed [rad/s]";
  Real theta_g "Drum angle [rad]";
  Real F "Cable tension / contact force [N]";
  Real delta "Cable extension [m]";
  Real F_dist "Disturbance force [N]";
  Real V_cmd "Voltage command [V]";
  Real i_ref "Current reference [A]";
  Real w_m_ref "Motor speed reference [rad/s]";
  Real T_drum_side "Torque on drum side of compliant transmission [N.m]";
  Real F_payload_side "Force on payload side of compliant transmission [N]";

  // Bounds
  Boolean electrical_ok;
  Boolean thermal_ok;
  Boolean joint_ok;
  Boolean deflection_ok;
  Boolean contact_ok;
  Boolean tracking_ok;

equation
  // Disturbance injection (middle third of 10 s run)
  F_dist = if time >= dist_start and time <= dist_stop then dist_magnitude else 0.0;

  // Motor electrical dynamics
  L_motor*der(i) = V_cmd - R_motor*i - k_e*w_m;

  // Motor and drum mechanical dynamics (reflected to motor side)
  (J_m + J_d/(N^2))*der(w_m) = k_t*i - (b_m + b_d/(N^2))*w_m - F*r_drum/N;
  der(theta_m) = w_m;

  // Drum kinematics (rigid support)
  w_g = w_m / N;
  theta_g = theta_m / N;

  // Compliant transmission (cable) with explicit contact stiffness and damping
  delta = r_drum*theta_g - y;
  F = k_cable*delta + b_cable*(r_drum*w_g - v);

  // Instrumentation: both sides of compliant transmission
  T_drum_side = F * r_drum;
  F_payload_side = F;

  // Payload dynamics
  m_payload*der(v) = F - m_payload*g - F_dist;
  der(y) = v;

  // Thermal model
  der(T_motor) = (i^2*R_motor - (T_motor - T_amb)/R_th)/C_th;

  // Cascaded control: tension -> speed -> current
  // Outer tension (force) loop
  der(integ_f) = F_ref - F;
  w_m_ref = max(min(Kp_f*(F_ref - F) + Ki_f*integ_f, w_max), -w_max);

  // Middle speed loop
  der(integ_w) = w_m_ref - w_m;
  i_ref = max(min(Kp_w*(w_m_ref - w_m) + Ki_w*integ_w, i_max), -i_max);

  // Inner current loop
  der(integ_i) = i_ref - i;
  V_cmd = max(min(Kp_i*(i_ref - i) + Ki_i*integ_i, V_cmd_max), -V_cmd_max);

  // Bounds checking
  electrical_ok = abs(V_cmd) <= V_cmd_max + 1e-6 and abs(i) <= i_max + 1e-6;
  thermal_ok = T_motor <= T_max + 1e-6;
  joint_ok = abs(w_m) <= w_max + 1e-6;
  deflection_ok = abs(delta) <= delta_max + 1e-6;
  contact_ok = abs(F) <= F_max + 1e-6;
  tracking_ok = if time >= t_tracking then abs(F_ref - F) < tracking_error_limit else true;

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="100 Hz synchronized traces over 10 s. Parameters not given in the requirement are marked as assumed and must be validated against hardware data.")
  );
end CableWinchTorqueB;