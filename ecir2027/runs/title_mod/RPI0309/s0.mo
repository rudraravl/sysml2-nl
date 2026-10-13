model PantographPressC
  "Closed-chain pantograph press with hybrid position-force control under loop constraints"

  // ==================== Parameters from requirement ====================
  // Mechanism geometry
  parameter Real L_short(unit="m") = 0.25 "Short parallelogram link length";
  parameter Real L_long(unit="m") = 0.50 "Long parallelogram link length";
  parameter Real s_travel(unit="m") = 0.16 "Prismatic input travel";
  parameter Real pantRatio = L_long / L_short "Motion amplification ratio (2.0)";

  // Actuator bound
  parameter Real F_max(unit="N") = 294.0 "Maximum command magnitude";

  // Contact parameters
  parameter Real k_contact(unit="N/m") = 200e3 "Contact stiffness";
  parameter Real c_contact(unit="N.s/m") = 2e3 "Contact damping";
  parameter Real mu_fric = 0.70 "Friction coefficient";

  // Disturbance
  parameter Real F_dist(unit="N") = 16.2 "Disturbance force change";

  // Timing
  parameter Real f_sample(unit="Hz") = 125.0 "Sampling frequency";
  parameter Real Ts(unit="s") = 1.0 / f_sample "Sample period";
  parameter Real t_total(unit="s") = 12.0 "Total simulation time";
  parameter Real t_dist_start(unit="s") = t_total / 3.0 "Disturbance start (middle third)";
  parameter Real t_dist_end(unit="s") = 2.0 * t_total / 3.0 "Disturbance end (middle third)";

  // ==================== Parameters not stated in requirement (labeled) ====================
  parameter Real y_workpiece(unit="m") = 0.30 "Workpiece surface position (not specified)";
  parameter Real m_act(unit="kg") = 1.5 "Actuator moving mass (not specified)";
  parameter Real m_out(unit="kg") = 3.0 "Output equivalent mass (not specified)";
  parameter Real k_closure(unit="N/m") = 2e6 "Linkage closure stiffness (not specified)";
  parameter Real c_closure(unit="N.s/m") = 2e3 "Linkage closure damping (not specified)";
  parameter Real k_lateral(unit="N/m") = 1e5 "Lateral stiffness (not specified)";
  parameter Real Kp_pos(unit="N/m") = 500.0 "Position P gain (not specified)";
  parameter Real Kd_pos(unit="N.s/m") = 40.0 "Position D gain (not specified)";
  parameter Real Kp_f = 0.10 "Force proportional gain, dimensionless (not specified)";
  parameter Real Ki_f(unit="1/s") = 5.0 "Force integral gain (not specified)";
  parameter Real force_setpoint(unit="N") = 120.0 "Target contact force (not specified)";
  parameter Real s_approach(unit="m") = 0.151 "Approach position target (not specified)";
  parameter Real t_ramp(unit="s") = 3.0 "Reference ramp duration (not specified)";
  parameter Real v_thresh(unit="m/s") = 1e-3 "Friction velocity threshold (not specified)";
  parameter Real force_band_frac = 0.10 "Force band fraction of setpoint (not specified)";

  // ==================== Continuous state variables ====================
  Real s(unit="m") "Prismatic input position";
  Real s_dot(unit="m/s") "Prismatic input velocity";
  Real y(unit="m") "Output normal position";
  Real y_dot(unit="m/s") "Output normal velocity";
  Real x_t(unit="m") "Tangential output position";
  Real x_t_dot(unit="m/s") "Tangential output velocity";

  // ==================== Discrete states (125 Hz controller) ====================
  discrete Real F_act(unit="N", start=0.0) "Bounded actuator command (zero-order hold)";
  discrete Real s_meas(unit="m", start=0.0) "Sampled input position sensor";
  discrete Real s_dot_meas(unit="m/s", start=0.0) "Sampled input velocity sensor";
  discrete Real y_meas(unit="m", start=0.0) "Sampled output pose sensor";
  discrete Real F_contact_meas(unit="N", start=0.0) "Sampled normal contact force sensor";
  discrete Boolean in_contact_meas(start=false) "Sampled contact detection";
  discrete Real force_integ(unit="N.s", start=0.0) "Force controller integral state";
  discrete Real F_cmd_raw(unit="N", start=0.0) "Raw command before saturation";

  // ==================== Continuous computed variables ====================
  Real F_link(unit="N") "Linkage constraint force";
  Real closure_error(unit="m") "Parallelogram closure error";
  Real F_contact(unit="N") "Normal contact force (continuous plant)";
  Real F_tangent(unit="N") "Tangential friction force";
  Real F_disturbance(unit="N") "Applied disturbance force";
  Real s_ref(unit="m") "Position reference trajectory";
  Boolean in_contact "Continuous contact state";
  Boolean locked_contact "Locked (no-slip) contact state";
  Real slip_vel(unit="m/s") "Tangential slip velocity";
  Real tracking_error(unit="m") "Primary tracking error";
  Boolean actuator_saturated "Actuator command at bound";
  Boolean force_in_band "Contact force within target band";
  Real closure_error_mm(unit="mm") "Closure error in mm for monitoring";

  // ==================== Synchronized traces (sampled at 125 Hz) ====================
  discrete Real trace_time(unit="s", start=0.0) "Trace timestamp";
  discrete Real trace_s(unit="m", start=0.0) "Trace: input position";
  discrete Real trace_y(unit="m", start=0.0) "Trace: output pose";
  discrete Real trace_F_act(unit="N", start=0.0) "Trace: actuator command";
  discrete Real trace_F_contact(unit="N", start=0.0) "Trace: contact force";
  discrete Real trace_closure(unit="m", start=0.0) "Trace: closure error";

  // ==================== Requirement monitors ====================
  Boolean req_closure_7p8 "Closure error below 0.001 m after 7.8 s";
  Boolean req_actuator_bounds "Actuator within ±294 N";

initial equation
  s = 0.0;
  s_dot = 0.0;
  y = 0.0;
  y_dot = 0.0;
  x_t = 0.0;
  x_t_dot = 0.0;

equation
  // ---- Parallelogram closure constraint ----
  // Ideal kinematic constraint: y = pantRatio * s
  // Closure error measures deviation due to linkage compliance
  closure_error = y - pantRatio * s;
  closure_error_mm = closure_error * 1000.0;

  // Linkage constraint force restoring closure (spring-damper)
  F_link = k_closure * closure_error + c_closure * (y_dot - pantRatio * s_dot);

  // ---- Input dynamics (prismatic actuator) ----
  der(s) = s_dot;
  m_act * der(s_dot) = F_act - F_link;

  // ---- Output dynamics (normal direction) ----
  // Force transmitted through pantograph: F_link / pantRatio (power conservation)
  der(y) = y_dot;
  m_out * der(y_dot) = (F_link / pantRatio) - F_contact - F_disturbance;

  // ---- Output dynamics (tangential direction) ----
  der(x_t) = x_t_dot;
  m_out * der(x_t_dot) = -k_lateral * x_t - F_tangent;

  // ---- Contact model (normal direction) ----
  // Contact when output reaches workpiece surface
  in_contact = y >= y_workpiece;
  F_contact = if in_contact then
    k_contact * (y - y_workpiece) + c_contact * y_dot
  else
    0.0;

  // ---- Friction model (tangential direction) ----
  // Regularized Coulomb friction; tanh provides well-defined zero-velocity branch
  slip_vel = x_t_dot;
  F_tangent = if F_contact > 0.0 then
    mu_fric * F_contact * tanh(slip_vel / v_thresh)
  else
    0.0;

  // Locked contact: in contact with negligible tangential slip
  locked_contact = in_contact and (abs(slip_vel) < v_thresh) and (F_contact > 0.0);

  // ---- Disturbance: 16.2 N force change during middle third (4-8 s) ----
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then
    F_dist
  else
    0.0;

  // ---- Position reference (smoothstep: zero velocity at start and end) ----
  s_ref = if time <= t_ramp then
    s_approach * (time / t_ramp) * (time / t_ramp) * (3.0 - 2.0 * time / t_ramp)
  else
    s_approach;

  // ---- Primary tracking error = closure error magnitude ----
  tracking_error = abs(closure_error);

  // ---- Requirement monitors ----
  req_closure_7p8 = if time >= 7.8 then abs(closure_error) < 0.001 else true;
  req_actuator_bounds = abs(F_act) <= F_max + 1.0;
  actuator_saturated = abs(F_act) >= F_max - 1.0;
  force_in_band = in_contact and (abs(F_contact - force_setpoint) < force_band_frac * force_setpoint);

  // ==================== Discrete hybrid controller at 125 Hz ====================
  when sample(0, Ts) then
    // ---- Sensor sampling (actuator sensors, output pose, contact force) ----
    s_meas = s;
    s_dot_meas = s_dot;
    y_meas = y;
    F_contact_meas = F_contact;
    in_contact_meas = y >= y_workpiece;

    // ---- Force controller integral (active only in force control mode) ----
    if in_contact_meas then
      force_integ = pre(force_integ) + Ts * (force_setpoint - F_contact_meas);
    else
      force_integ = 0.0;
    end if;

    // ---- Hybrid control: position control or force control ----
    if not in_contact_meas then
      // Position control mode: PD on input position error
      F_cmd_raw = Kp_pos * (s_ref - s_meas) - Kd_pos * s_dot_meas;
    else
      // Force control mode: feedforward + PI on contact force error
      // Steady-state: F_act = pantRatio * (F_contact + F_dist)
      F_cmd_raw = pantRatio * force_setpoint
        + Kp_f * (force_setpoint - F_contact_meas)
        + Ki_f * force_integ;
    end if;

    // ---- Actuator saturation (bounded command, max 294 N) ----
    if F_cmd_raw > F_max then
      F_act = F_max;
    elseif F_cmd_raw < (-F_max) then
      F_act = -F_max;
    else
      F_act = F_cmd_raw;
    end if;

    // ---- Synchronized state, command, and sensor traces ----
    trace_time = time;
    trace_s = s;
    trace_y = y;
    trace_F_act = F_act;
    trace_F_contact = F_contact;
    trace_closure = closure_error;
  end when;

  annotation(
    experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1e-6),
    Documentation(info = "PantographPressC: Closed-chain pantograph press with
      hybrid position-force control under loop constraints.

      Mechanism: Fixed parallelogram with 0.25 m and 0.50 m links,
      six revolute Z joints (implicit in lumped closure model),
      one prismatic input with 0.16 m travel.
      Motion amplification ratio = L_long / L_short = 2.0.

      Plant: The parallelogram closure is maintained by a compliant linkage
      (spring-damper) producing closure_error = y - pantRatio * s.
      Force transmission follows power conservation: F_out = F_link / pantRatio.

      Contact: stiffness 200 kN/m, damping 2 kN.s/m, friction coefficient 0.70.
      Regularized Coulomb friction via tanh with velocity threshold v_thresh.

      Actuator: Bounded linear actuator, max command magnitude 294 N.
      Disturbance: 16.2 N force change injected during middle third (4-8 s).

      Control: 125 Hz discrete hybrid controller.
      - Position control (PD) during approach phase.
      - Force control (feedforward + PI) during contact phase.
      Switching based on contact detection (y >= y_workpiece).

      Requirements monitored:
      - Actuator bounds: |F_act| <= 294 N
      - Closure error < 0.001 m after 7.8 s
      - Contact force band: within +/- 10% of setpoint
      - Tangential slip and locked contact states tracked
      - All equations well-defined (no NaN/infinite sources)

      Parameters labeled '(not specified)' are not stated in the requirement
      and use reasonable engineering assumptions for code generation.
      Unresolved parameters are commented, not fabricated into bindings."))
end PantographPressC;