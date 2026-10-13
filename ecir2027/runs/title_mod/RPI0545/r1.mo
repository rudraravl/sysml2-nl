model BallScrewTorqueE
  "Electromechanical ball-screw actuator with cascaded current/force control,
   backlash, Coulomb friction, compliant contact and thermal model.
   Values not stated in the requirement are engineering assumptions (labeled)."

  // ============ Electrical (assumed) ============
  parameter Real V_supply = 24.0  "Nominal supply voltage [V]";
  parameter Real V_max    = 26.4  "Command voltage bound [V]";
  parameter Real R  = 1.2         "Winding resistance [Ohm] (assumed)";
  parameter Real L  = 0.8e-3      "Winding inductance [H] (assumed)";
  parameter Real Ke = 0.05        "Back-EMF constant [V.s/rad] (assumed)";
  parameter Real Kt = 0.05        "Torque constant [N.m/A] (assumed)";
  parameter Real Jm = 1.0e-5      "Motor inertia [kg.m2] (assumed)";
  parameter Real bm = 1.0e-6      "Motor viscous friction [N.m.s/rad] (assumed)";

  // ============ Transmission (partly stated) ============
  parameter Real N     = 2.0      "Belt reduction motor:screw (assumed)";
  parameter Real pitch = 5.0e-3   "Ball-screw pitch [m/rev]";
  parameter Real k_t   = 5.0e5    "Transmission stiffness [N/m] (assumed)";
  parameter Real c_t   = 200.0    "Transmission damping [N.s/m] (assumed)";
  parameter Real b_back= 0.5e-3   "Backlash (linear) [m] (assumed)";

  // ============ Carriage / load ============
  parameter Real m_c    = 18.0    "Carriage mass [kg]";
  parameter Real F_c    = 1.0     "Coulomb friction force [N] (assumed)";
  parameter Real b_c    = 0.5     "Viscous friction [N.s/m] (assumed)";
  parameter Real travel = 0.65    "Travel [m]";
  parameter Real x_wall = 0.60    "Compliant load contact position [m] (assumed)";

  // ============ Contact (assumed) ============
  parameter Real k_contact   = 1.0e5  "Contact stiffness [N/m] (assumed)";
  parameter Real c_contact   = 50.0   "Contact damping [N.s/m] (assumed)";
  parameter Real F_cmd        = 50.0  "Force command [N] (assumed)";

  // ============ Thermal (assumed) ============
  parameter Real C_th  = 50.0   "Thermal capacitance [J/K] (assumed)";
  parameter Real R_th  = 2.0    "Thermal resistance [K/W] (assumed)";
  parameter Real T_amb = 25.0   "Ambient temperature [degC] (assumed)";
  parameter Real T_max = 80.0   "Thermal limit [degC] (assumed)";

  // ============ Control gains (assumed) ============
  parameter Real Kp_i = 20.0   "Current proportional [V/A]";
  parameter Real Ki_i = 500.0  "Current integral [V/(A.s)]";
  parameter Real Kp_f = 0.5    "Force proportional [A/N]";
  parameter Real Ki_f = 5.0    "Force integral [A/(N.s)]";

  // ============ Disturbance ============
  parameter Real F_dist        = 18.0 "Middle-third load change magnitude [N]";
  parameter Real t_start_dist  = 16.0/3.0 "Disturbance start [s]";
  parameter Real t_end_dist    = 32.0/3.0 "Disturbance end [s]";

  // ============ Sampling ============
  parameter Real Ts = 1.0/250.0 "Sample period [s]";

  // ============ Continuous states ============
  Real i       "Motor current [A]";
  Real omega_m "Motor angular velocity [rad/s]";
  Real theta_m "Motor angle [rad]";
  Real x_l     "Carriage position [m]";
  Real v_l     "Carriage velocity [m/s]";
  Real T_w     "Winding temperature [degC]";
  Real integ_i "Current-loop integrator";
  Real integ_f "Force-loop integrator";

  // ============ Derived signals ============
  Real V       "Applied motor voltage [V]";
  Real V_cmd   "Unsaturated command voltage [V]";
  Real tau_m   "Motor torque [N.m]";
  Real x_m     "Motor-side linear position [m]";
  Real v_m     "Motor-side linear velocity [m/s]";
  Real delta   "Transmission deflection [m]";
  Real delta_eff "Effective deflection after backlash [m]";
  Real F_trans "Transmission force [N]";
  Real F_contact "Contact force (compression>=0) [N]";
  Real F_friction "Carriage friction force [N]";
  Real F_disturbance "Active disturbance force [N]";
  Real i_cmd   "Current command [A]";
  Real err_i   "Current error [A]";
  Real err_f   "Force error [N]";
  Real tracking_err "Primary tracking error magnitude [N]";

  // ============ Acceptance flags (fail-closed) ============
  Boolean electrical_ok;
  Boolean thermal_ok;
  Boolean joint_ok;
  Boolean deflection_ok;
  Boolean contact_ok;
  Boolean tracking_ok;
  Boolean all_ok;

  // ============ Sampled traces (250 Hz) ============
  discrete Integer tick;
  discrete Real i_s, V_s, x_l_s, x_m_s, F_contact_s, F_trans_s, T_w_s, V_cmd_s, tracking_err_s;

initial equation
  i = 0.0;
  omega_m = 0.0;
  theta_m = 0.0;
  x_l = 0.0;
  v_l = 0.0;
  T_w = T_amb;
  integ_i = 0.0;
  integ_f = 0.0;
  tick = 0;

equation
  // ---- Electrical dynamics ----
  L * der(i) = V - R * i - Ke * omega_m;
  der(theta_m) = omega_m;

  // ---- Motor mechanical dynamics ----
  // Reaction torque from transmission load (ideal screw, belt reduction).
  tau_m = Kt * i;
  Jm * der(omega_m) = tau_m - bm * omega_m - F_trans * (pitch/(2.0*Modelica.Constants.pi)) / N;

  // ---- Motor-side linear kinematics ----
  x_m = theta_m / N * (pitch/(2.0*Modelica.Constants.pi));
  v_m = omega_m / N * (pitch/(2.0*Modelica.Constants.pi));

  // ---- Transmission deflection and backlash ----
  delta = x_m - x_l;
  delta_eff = if noEvent(delta > b_back/2.0)  then (delta - b_back/2.0)
         else if noEvent(delta < -b_back/2.0) then (delta + b_back/2.0)
         else 0.0;
  F_trans = k_t * delta_eff + c_t * (v_m - v_l);

  // ---- Contact with compliant load (rigid support geometry, explicit stiffness/damping) ----
  F_contact = if noEvent(x_l > x_wall)
              then k_contact*(x_l - x_wall) + c_contact*v_l
              else 0.0;

  // ---- Coulomb + viscous friction (smoothed) ----
  F_friction = b_c * v_l + F_c * Modelica.Math.tanh(v_l/1.0e-3);

  // ---- Disturbance: middle third of 16 s, opposes contact direction ----
  F_disturbance = if noEvent(time >= t_start_dist and time <= t_end_dist)
                  then F_dist else 0.0;

  // ---- Carriage dynamics ----
  m_c * der(v_l) = F_trans - F_contact - F_friction - F_disturbance;
  der(x_l) = v_l;

  // ---- Thermal model of winding ----
  C_th * der(T_w) = i*i*R - (T_w - T_amb)/R_th;

  // ---- Outer force loop ----
  err_f = F_cmd - F_contact;
  // Anti-windup: hold integrator when current command saturates
  der(integ_f) = if noEvent((i_cmd >  25.0 and err_f > 0.0) or
                            (i_cmd < -25.0 and err_f < 0.0))
                 then 0.0 else Ki_f * err_f;
  i_cmd = Kp_f * err_f + integ_f;

  // ---- Inner current loop ----
  err_i = i_cmd - i;
  // Anti-windup: hold when voltage saturates
  der(integ_i) = if noEvent((V_cmd >  V_max and err_i > 0.0) or
                            (V_cmd < -V_max and err_i < 0.0))
                 then 0.0 else Ki_i * err_i;
  V_cmd = Kp_i * err_i + integ_i;

  // ---- Voltage saturation (command bounded by 26.4 V) ----
  V = if noEvent(V_cmd >  V_max) then  V_max
      else if noEvent(V_cmd < -V_max) then -V_max
      else V_cmd;

  // ---- Primary tracking error ----
  tracking_err = abs(F_contact - F_cmd);

  // ---- Acceptance bounds (fail-closed: NaN/Inf comparisons yield false) ----
  electrical_ok   = abs(i) <= 25.0 and abs(V) <= V_max + 1.0e-6;
  thermal_ok      = T_w <= T_max;
  joint_ok        = x_l >= -1.0e-3 and x_l <= travel + 1.0e-3;
  deflection_ok   = abs(delta) <= 5.0e-3;
  contact_ok      = F_contact >= -1.0 and F_contact <= 500.0;
  tracking_ok     = (time < 10.4) or (tracking_err < 1.8);
  all_ok          = electrical_ok and thermal_ok and joint_ok and
                    deflection_ok and contact_ok and tracking_ok;

  // ---- Synchronized 250 Hz sampled traces ----
  when sample(0, Ts) then
    tick = pre(tick) + 1;
    i_s           = i;
    V_s           = V;
    V_cmd_s       = V_cmd;
    x_l_s         = x_l;
    x_m_s         = x_m;
    F_contact_s   = F_contact;
    F_trans_s     = F_trans;
    T_w_s         = T_w;
    tracking_err_s= tracking_err;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=16.0, Tolerance=1.0e-6, Interval=Ts),
    Documentation(info="BallScrewTorqueE: verifiable electromechanical actuator.
      24 V motor -> belt reduction (assumed N=2) -> 5 mm-pitch ball screw -> 18 kg carriage,
      0.65 m travel, backlash, Coulomb friction, compliant transmission and contact.
      Cascaded control: outer force loop (spring/contact feedback) -> current command;
      inner current loop -> motor voltage bounded to +/-26.4 V. Middle-third 18 N disturbance.
      Synchronized 250 Hz state/command/sensor traces. Acceptance flags fail-closed.
      Assumed parameters are labeled; values not stated in the request are unknowns."));
end BallScrewTorqueE;