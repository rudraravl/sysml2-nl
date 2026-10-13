model BallScrewSpeedE
  // ===================== Plant parameters =====================
  parameter Real Vmax = 26.4        "Voltage command bound [V]";
  parameter Real Vnom = 24.0        "Nominal DC bus voltage [V]";
  parameter Real Ra = 1.2           "Armature resistance [Ohm]";
  parameter Real La = 0.5e-3         "Armature inductance [H]";
  parameter Real Ke = 0.05           "Back-EMF constant [V.s/rad]";
  parameter Real Kt = 0.05           "Torque constant [N.m/A]";
  parameter Real Jm = 1.0e-6         "Rotor + coupling inertia [kg.m2]";
  parameter Real N = 2.0             "Belt reduction ratio [-]";
  parameter Real lead = 0.005       "Ball screw lead [m/rev]";
  parameter Real m_carriage = 18.0   "Carriage mass [kg]";
  parameter Real eta_gb = 0.90       "Gearbox (belt+screw) efficiency [-]";
  parameter Real Fc = 5.0            "Coulomb friction force [N]";
  parameter Real b_vis = 2.0         "Viscous friction coefficient [N.s/m]";
  parameter Real backlash = 0.2e-3   "Mechanical backlash [m]";
  parameter Real k_spring = 5.0e5    "Coupling stiffness [N/m]";
  parameter Real c_spring = 2.0e3    "Coupling damping [N.s/m]";
  parameter Real stroke = 0.65      "Carriage travel [m]";
  parameter Real Ts = 0.004         "Control sample period (250 Hz) [s]";
  parameter Real I_max = 12.0        "Current limit [A]";
  parameter Real v_decl = 0.04       "Declared output (carriage) speed [m/s]";
  parameter Real t_acc = 4.0         "Acceleration duration [s]";
  parameter Real t_dec_start = 12.0  "Deceleration start time [s]";
  parameter Real t_end = 16.0        "Scenario duration [s]";
  parameter Real Rbat = 0.15        "Battery internal resistance [Ohm]";
  parameter Real C_Ah = 5.0          "Battery capacity [Ah]";
  parameter Real SoC0 = 0.95         "Initial state of charge [-]";
  parameter Real Rth = 2.0           "Winding thermal resistance [K/W]";
  parameter Real Cth = 50.0          "Winding thermal capacitance [J/K]";
  parameter Real T_amb = 25.0        "Ambient temperature [degC]";
  parameter Real Kp_pos = 5.0        "Position loop gain [1/s]";
  parameter Real Kp_spd = 40.0       "Speed loop proportional gain [A/(m/s)]";
  parameter Real Ki_spd = 120.0      "Speed loop integral gain [A/(m/s)/s]";
  parameter Real Kp_cur = 8.0        "Current loop proportional gain [V/A]";
  parameter Real Ki_cur = 200.0      "Current loop integral gain [V/A/s]";
  parameter Real F_load_amp = 14.4   "Middle-third disturbance force [N]";
  parameter Real v_thresh = 1.0e-4   "Coulomb friction velocity threshold [m/s]";

  // ===================== Continuous states =====================
  Real i_arm(start=0.0)        "Armature (phase) current [A]";
  Real v_eq(start=0.0)         "Motor-side equivalent linear velocity [m/s]";
  Real x_eq(start=0.0)         "Motor-side equivalent linear position [m]";
  Real v(start=0.0)            "Carriage (output) velocity [m/s]";
  Real x(start=0.0)            "Carriage position [m]";
  Real SoC(start=SoC0)         "Battery state of charge [-]";
  Real T_w(start=T_amb)        "Winding temperature [degC]";

  // ===================== Continuous derived ====================
  Real omega_m       "Motor angular velocity [rad/s]";
  Real Tm            "Motor electromagnetic torque [N.m]";
  Real F_motor       "Motor force at linear equivalent [N]";
  Real F_spring      "Backlash spring force [N]";
  Real F_coupling    "Coupling force through backlash [N]";
  Real F_friction    "Carriage friction force [N]";
  Real F_load        "Disturbance force [N]";
  Real v_bus         "DC bus voltage [V]";
  Real v_motor       "Applied motor terminal voltage [V]";
  Real P_loss        "Dissipated power [W]";
  Real a_out         "Output acceleration [m/s2]";
  Real v_ref_profile "Speed reference profile [m/s]";
  Real x_ref(start=0.0) "Position reference [m]";
  Real e_track       "Primary tracking error [m/s]";
  Real Jm_lin        "Rotor inertia reflected to linear [kg]";
  Real ratio         "Lead transmission ratio [1/m]";
  Real delta         "Coupling deflection [m]";

  // ===================== Discrete controller ===================
  discrete Real v_ref_pos(start=0.0) "Position-loop speed command [m/s]";
  discrete Real e_spd(start=0.0)     "Speed error [m/s]";
  discrete Real int_spd(start=0.0)   "Speed loop integrator state [A]";
  discrete Real i_ref(start=0.0)     "Current reference [A]";
  discrete Real e_cur(start=0.0)      "Current error [A]";
  discrete Real int_cur(start=0.0)   "Current loop integrator state [V]";
  discrete Real v_cmd_raw(start=0.0) "Unbounded voltage command [V]";
  discrete Real v_cmd(start=0.0)     "Bounded voltage command [V]";

  // ===================== Sensors / observables =================
  output Real v_out       = v            "Output speed sensor [m/s]";
  output Real i_meas      = i_arm        "Armature current sensor [A]";
  output Real theta_m_out                "Rotor position sensor [rad]";
  output Real v_bus_out   = v_bus        "DC-bus voltage sensor [V]";
  output Real SoC_out     = SoC          "State-of-charge sensor [-]";
  output Real T_w_out     = T_w          "Thermal sensor [degC]";
  output Real v_cmd_out   = v_cmd        "Voltage command trace [V]";
  output Real i_ref_out   = i_ref        "Current command trace [A]";
  output Real v_ref_out   = v_ref_profile "Speed reference trace [m/s]";
  output Real e_track_out = e_track      "Tracking error trace [m/s]";
  output Real fault                      "Fail-closed fault signal (1=fault) [-]";

  // ===================== Acceptance bounds =====================
  Real v_cmd_ok   "Voltage bound check [-]";
  Real i_ok       "Current bound check [-]";
  Real v_out_ok   "Speed bound check [-]";
  Real acc_ok     "Acceleration bound check [-]";
  Real soc_ok     "SOC bound check [-]";
  Real thermal_ok "Thermal bound check [-]";
  Real track_ok   "Tracking bound check [-]";
  Real finite_ok  "Finite-values check [-]";
  Real fault_active "Continuous fault latch [-]";

protected
  constant Real pi = 3.141592653589793;

equation
  // Transmission ratio and reflected inertia
  ratio   = 2.0*pi*N/lead;
  Jm_lin  = Jm * ratio^2;

  // ===== Speed/position reference profile: accel, hold, decel =====
  if time < t_acc then
    v_ref_profile = v_decl * (time / t_acc);
  elseif time < t_dec_start then
    v_ref_profile = v_decl;
  elseif time < t_end then
    v_ref_profile = v_decl * (1.0 - (time - t_dec_start)/(t_end - t_dec_start));
  else
    v_ref_profile = 0.0;
  end if;
  der(x_ref) = v_ref_profile;

  // ===== Motor electrical dynamics =====
  omega_m  = v_eq * ratio;
  Tm       = Kt * i_arm;
  F_motor  = Tm * ratio * eta_gb;
  der(i_arm) = (v_motor - Ra*i_arm - Ke*omega_m) / La;

  // ===== Motor-side inertia and backlash coupling =====
  der(v_eq) = (F_motor - F_coupling) / Jm_lin;
  der(x_eq) = v_eq;

  delta    = x_eq - x;
  F_spring = if delta > backlash/2.0 then
               k_spring*(delta - backlash/2.0)
             elseif delta < -backlash/2.0 then
               k_spring*(delta + backlash/2.0)
             else
               0.0;
  F_coupling = F_spring + c_spring*(v_eq - v);

  // ===== Carriage dynamics with Coulomb + viscous friction =====
  F_friction = Fc * tanh(v / v_thresh) + b_vis * v;
  F_load     = F_load_amp * (if time >= t_end/3.0 and time <= 2.0*t_end/3.0 then 1.0 else 0.0);
  der(v)     = (F_coupling - F_friction - F_load) / m_carriage;
  der(x)     = v;
  a_out      = (F_coupling - F_friction - F_load) / m_carriage;

  // ===== Battery droop and state-of-charge =====
  v_bus    = Vnom - Rbat * i_arm;
  der(SoC) = -i_arm / (3600.0 * C_Ah);

  // ===== Thermal (lumped winding) =====
  P_loss   = Ra * i_arm^2 + Fc * abs(v);
  der(T_w) = (P_loss - (T_w - T_amb) / Rth) / Cth;

  // ===== Cascaded current/position controller at 250 Hz =====
  when sample(0, Ts) then
    // Position loop generates speed reference (feedforward + trim)
    v_ref_pos = v_ref_profile + Kp_pos * (x_ref - x);
    // Speed loop (current-limited speed regulation)
    e_spd     = v_ref_pos - v;
    int_spd   = pre(int_spd) + e_spd * Ts;
    i_ref     = max(-I_max, min(I_max, Kp_spd*e_spd + Ki_spd*int_spd));
    // Current (inner) loop commands voltage
    e_cur     = i_ref - i_arm;
    int_cur   = pre(int_cur) + e_cur * Ts;
    v_cmd_raw = Kp_cur*e_cur + Ki_cur*int_cur;
    v_cmd     = max(-Vmax, min(Vmax, v_cmd_raw));
  end when;

  // ===== Sensor: rotor position =====
  theta_m_out = x_eq * ratio;

  // ===== Primary tracking error (output speed) =====
  e_track = v_ref_profile - v;

  // ===== Acceptance / fail-closed logic =====
  v_cmd_ok   = if abs(v_cmd) <= Vmax + 1.0e-6 then 1.0 else 0.0;
  i_ok       = if abs(i_arm) <= I_max + 0.5 then 1.0 else 0.0;
  v_out_ok   = if abs(v) <= 1.0 then 1.0 else 0.0;
  acc_ok     = if abs(a_out) <= 20.0 then 1.0 else 0.0;
  soc_ok     = if SoC >= 0.0 and SoC <= 1.0 then 1.0 else 0.0;
  thermal_ok = if T_w <= 85.0 then 1.0 else 0.0;
  track_ok   = if time > 10.4 then (if abs(e_track) <= 0.225 then 1.0 else 0.0) else 1.0;
  finite_ok  = if (abs(i_arm) < 1.0e6) and (abs(v) < 1.0e6) and
                   (abs(v_cmd) < 1.0e6) and (abs(T_w) < 1.0e6) and
                   (abs(SoC) < 1.0e6) and (abs(x) < 1.0e6) then 1.0 else 0.0;

  fault_active = if (v_cmd_ok > 0.5 and i_ok > 0.5 and v_out_ok > 0.5 and
                     acc_ok > 0.5 and soc_ok > 0.5 and thermal_ok > 0.5 and
                     track_ok > 0.5 and finite_ok > 0.5) then 0.0 else 1.0;
  fault = fault_active;

  // ===== Fail-closed: cut motor terminal voltage on any bound violation =====
  v_motor = if fault_active > 0.5 then 0.0 else v_cmd;

  annotation (
    Documentation(info="Electromechanical robotic ball-screw actuator.
  24 V (26.4 V bounded) motor drives 18 kg carriage through 5 mm-pitch ball
  screw with belt reduction N=2, backlash, Coulomb friction, eta=0.90, 0.65 m
  stroke. Cascaded position->speed->current loops at 250 Hz over 16 s.
  Middle-third (5.333-10.667 s) disturbance 14.4 N applied as linear force on
  the carriage (request ambiguous N vs N.m). Fail-closed acceptance on
  voltage, current, speed, acceleration, SOC, thermal, tracking (<0.225 m/s
  after 10.4 s) and finite values."));

end BallScrewSpeedE;