model PantographPressC
  "Closed-chain pantograph press with hybrid position-to-force control under loop constraints"

  // ===== Parameters from requirement =====
  parameter Modelica.Units.SI.Length L_short = 0.25 "Short parallelogram link [m]";
  parameter Modelica.Units.SI.Length L_long  = 0.50 "Long parallelogram link [m]";
  parameter Modelica.Units.SI.Length q_max_travel = 0.16 "Prismatic input travel [m]";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_contact = 200e3 "Contact stiffness [N/m]";
  parameter Modelica.Units.SI.TranslationalDampingConstant c_contact = 2000 "Contact damping [N.s/m]";
  parameter Real mu = 0.70 "Friction coefficient";
  parameter Modelica.Units.SI.Force F_max = 294 "Maximum command magnitude [N]";
  parameter Modelica.Units.SI.Force F_dist = 16.2 "Disturbance force change [N]";
  parameter Modelica.Units.SI.Frequency f_sample = 125 "Control loop frequency [Hz]";
  parameter Modelica.Units.SI.Duration t_end = 12.0 "Total run duration [s]";

  // ===== Assumed parameters (not stated; labelled for transparency) =====
  parameter Modelica.Units.SI.Mass m_act = 2.5 "Actuator reflected mass [kg] -- assumed";
  parameter Modelica.Units.SI.Mass m_lat = 0.8 "Lateral output mass [kg] -- assumed";
  parameter Modelica.Units.SI.Length x_workpiece = 0.06 "Workpiece surface position [m] -- assumed";
  parameter Modelica.Units.SI.Force F_ref = 200.0 "Target normal contact force [N] -- assumed";
  parameter Real Kp_pos = 8000.0 "Position P gain -- assumed";
  parameter Real Kd_pos = 150.0  "Position D gain -- assumed";
  parameter Real Kp_force = 3.0   "Force P gain -- assumed";
  parameter Real Ki_force = 15.0  "Force I gain -- assumed";
  parameter Modelica.Units.SI.Force F_lateral = 5.0 "Lateral disturbing force [N] -- assumed";
  parameter Modelica.Units.SI.Length eps_contact = 1e-5 "Contact smoothing [m] -- assumed";
  parameter Real eps_friction = 0.005 "Friction velocity smoothing [m/s] -- assumed";
  parameter Real eps_locked = 1e-3 "Locked velocity threshold [m/s] -- assumed";
  parameter Real eps_norm = 1e-9 "Norm zero-branch epsilon -- assumed";
  parameter Modelica.Units.SI.Duration t_approach = 2.0 "Position ramp duration [s] -- assumed";
  parameter Modelica.Units.SI.Force F_contact_band_half = 20.0 "Contact force band half-width [N] -- assumed";

  // ===== Derived constants =====
  parameter Real n = L_short / L_long "Output/input displacement ratio (pantograph)";
  parameter Modelica.Units.SI.Time Ts = 1.0 / f_sample "Sample period [s]";
  parameter Modelica.Units.SI.Length x_out_target = x_workpiece + F_ref / k_contact "Target output position [m]";
  parameter Modelica.Units.SI.Length q_target = x_out_target / n "Target input position [m]";
  parameter Modelica.Units.SI.Duration t_dist_start = t_end / 3.0 "Disturbance window start [s]";
  parameter Modelica.Units.SI.Duration t_dist_end = 2.0 * t_end / 3.0 "Disturbance window end [s]";

  // ===== Continuous states =====
  Real q(start = 0.0, fixed = true) "Prismatic input coordinate [m]";
  Real q_dot(start = 0.0, fixed = true) "Prismatic input velocity [m/s]";
  Real y_lat(start = 0.0, fixed = true) "Lateral (tangential) output displacement [m]";
  Real y_lat_dot(start = 0.0, fixed = true) "Lateral output velocity [m/s]";
  Real tangential_slip(start = 0.0, fixed = true) "Accumulated tangential slip [m]";

  // ===== Discrete (sampled) states =====
  discrete Real F_command_zoh(start = 0.0) "ZOH actuator command [N]";
  discrete Real force_err_int_d(start = 0.0) "Discrete force-error integral [N.s]";
  discrete Real q_ref_d(start = 0.0) "Discrete reference position [m]";
  discrete Integer control_mode_d(start = 0) "0 = position, 1 = force";

  // ===== Continuous variables =====
  Real x_out "Output normal position [m]";
  Real x_out_dot "Output normal velocity [m/s]";
  Real x_out_ref "Reference output position [m]";
  Real penetration "Contact penetration [m]";
  Real penetration_dot "Contact penetration rate [m/s]";
  Real contact_active "Smoothed contact indicator (0..1)";
  Real F_contact "Normal contact force [N]";
  Real F_disturbance "Injected disturbance force [N]";
  Real F_command "Unsaturated command [N]";
  Real F_command_sat "Saturated command [N]";
  Real F_reflected "Reflected force from output to input [N]";
  Real F_contact_mag "Contact force magnitude [N]";
  Real F_friction_val "Friction force [N]";
  Real F_friction_limit_val "Friction limit [N]";
  Real y_lat_abs "Smoothed abs lateral velocity [m/s]";
  Real pos_err "Position tracking error [m]";
  Real force_err "Force tracking error [N]";
  Real tracking_err "Primary tracking error [m]";
  Real closure_err "Loop closure error [m]";
  Real locked_contact "Locked contact indicator (1=locked, 0=slip)";
  Real actuator_saturated "Actuator saturation indicator (1=saturated)";
  Real in_force_band "Contact force within band (1=yes)";
  Real q_cmd_mag "Command magnitude [N]";

  // ===== Sensors =====
  Real q_sensor "Actuator position sensor [m]";
  Real q_dot_sensor "Actuator velocity sensor [m/s]";
  Real F_actuator_sensor "Actuator force sensor [N]";
  Real x_out_sensor "Output pose sensor [m]";
  Real F_contact_sensor "Normal contact force sensor [N]";

equation
  // === Parallelogram kinematics ===
  // Six revolute Z joints form the parallelogram (4 corners + 2 output links).
  // One prismatic input drives the short side; output scales by n = L_short/L_long.
  // Loop closure constraint: x_out = n * q (always satisfied in this 1D projection).
  x_out = n * q;
  x_out_dot = n * q_dot;
  closure_err = x_out - n * q;

  // === Compliant contact model ===
  penetration = x_out - x_workpiece;
  penetration_dot = x_out_dot;
  contact_active = 0.5 * (1.0 + Modelica.Math.tanh(penetration / eps_contact));
  F_contact = contact_active * (k_contact * penetration + c_contact * penetration_dot);

  // === Disturbance: 16.2 N during middle third (4 s to 8 s) ===
  F_disturbance = F_dist * 0.25
    * (1.0 + Modelica.Math.tanh((time - t_dist_start) / 0.05))
    * (1.0 + Modelica.Math.tanh((t_dist_end - time) / 0.05));

  // === Force reflection (virtual work conservation) ===
  F_reflected = n * (F_contact + F_disturbance);

  // === Actuator dynamics ===
  der(q) = q_dot;
  m_act * der(q_dot) = F_command_sat - F_reflected;

  // === Command saturation (bounded linear actuator, max 294 N) ===
  F_command = F_command_zoh;
  F_command_sat = max(-F_max, min(F_max, F_command));
  q_cmd_mag = sqrt(F_command * F_command + eps_norm * eps_norm);
  actuator_saturated = 0.5 * (1.0 + Modelica.Math.tanh((q_cmd_mag - F_max) / 1.0));

  // === Lateral dynamics with Coulomb friction ===
  y_lat_abs = sqrt(y_lat_dot * y_lat_dot + eps_norm * eps_norm);
  F_contact_mag = sqrt(F_contact * F_contact + eps_norm * eps_norm);
  F_friction_limit_val = mu * F_contact_mag;
  F_friction_val = F_friction_limit_val * Modelica.Math.tanh(y_lat_dot / eps_friction);
  der(y_lat) = y_lat_dot;
  m_lat * der(y_lat_dot) = F_lateral - F_friction_val;

  // === Tangential slip accumulation (only when slipping) ===
  der(tangential_slip) = y_lat_abs
    * (1.0 - 0.5 * (1.0 + Modelica.Math.tanh((eps_locked - y_lat_abs) / (eps_locked * 0.1))));

  // === Locked contact indicator ===
  locked_contact = 0.5 * (1.0 + Modelica.Math.tanh((eps_locked - y_lat_abs) / (eps_locked * 0.1)))
    * contact_active;

  // === Contact force band indicator ===
  in_force_band = 0.5 * (1.0 + Modelica.Math.tanh(
    (F_contact_band_half - sqrt((F_contact - F_ref) * (F_contact - F_ref) + eps_norm * eps_norm)) / 1.0));

  // === Reference and errors ===
  x_out_ref = n * q_ref_d;
  pos_err = q_ref_d - q;
  force_err = F_ref - F_contact;
  tracking_err = sqrt((x_out_ref - x_out) * (x_out_ref - x_out) + eps_norm * eps_norm) - eps_norm;

  // === Sensors ===
  q_sensor = q;
  q_dot_sensor = q_dot;
  F_actuator_sensor = F_command_sat;
  x_out_sensor = x_out;
  F_contact_sensor = F_contact;

  // === Sampled hybrid controller at 125 Hz ===
  when sample(0, Ts) then
    // Reference ramp to target, then hold
    q_ref_d = if time < t_approach then q_target * time / t_approach else q_target;

    // Mode: force control once contact detected
    control_mode_d = if F_contact > 1.0 then 1 else 0;

    // Discrete integral with reset when not in force mode
    force_err_int_d = if control_mode_d == 1 then
      pre(force_err_int_d) + Ts * (F_ref - F_contact)
    else 0.0;

    // Hybrid command: PD position or PI force with feedforward
    F_command_zoh = if control_mode_d == 0 then
      Kp_pos * (q_ref_d - q) - Kd_pos * q_dot
    else
      n * F_ref + Kp_force * (F_ref - F_contact) + Ki_force * force_err_int_d;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.001),
    Documentation(info = "PantographPressC: closed-chain parallelogram press mechanism.

Plant structure (six revolute Z joints + one prismatic input):
  - Parallelogram: L_short = 0.25 m, L_long = 0.50 m (4 corner revolutes)
  - Two additional revolute Z joints connect output link to parallelogram
  - One prismatic input actuates the short side (0.16 m travel)
  - Transmission ratio n = L_short/L_long = 0.5

Contact (fixed compliant workpiece):
  - Stiffness 200 kN/m, damping 2 kN.s/m, friction coefficient 0.70

Control (125 Hz sampled, hybrid position-to-force):
  - Phase 1 (position): PD to approach workpiece
  - Phase 2 (force): PI with feedforward, max command 294 N
  - Disturbance: 16.2 N force change during middle third (4-8 s)

Sensors: actuator position, velocity, force; output pose; normal contact force.
Monitors: actuator bounds, closure error, contact force band, tangential slip,
locked contact, primary tracking error (< 0.001 m after 7.8 s).

Assumed parameters (not in requirement): m_act, m_lat, x_workpiece, F_ref,
control gains, F_lateral, smoothing epsilons, t_approach, F_contact_band_half."));
end PantographPressC;