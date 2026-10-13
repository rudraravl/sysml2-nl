model HydCylinderPositionB
  "Hydraulic cylinder position mission: move to 70 percent stroke and hold,
   with pressure-aware PID control, compressible chambers, leakage, end stops,
   and a 70 N disturbance load injected during the middle third of a 10 s run."

  // --- Physical parameters (SI units) ---
  parameter Real A_p      = 0.0040  "Piston (cap-side) area [m2]";
  parameter Real A_r      = 0.0032  "Rod-side area [m2]";
  parameter Real L_stroke = 0.50    "Cylinder stroke [m]";
  parameter Real m_load   = 110.0   "Moving mass [kg]";
  parameter Real Q_max    = 0.001   "Allowed valve command magnitude [m3/s]";
  parameter Real p_supply = 7.0e6   "Declared supply pressure [Pa]";
  parameter Real p_return = 1.0e5   "Declared return/tank pressure [Pa]";
  parameter Real beta     = 1.5e8   "Effective fluid bulk modulus [Pa]";
  parameter Real V_deadA  = 1.0e-4  "Chamber A dead volume [m3]";
  parameter Real V_deadB  = 1.0e-4  "Chamber B dead volume [m3]";
  parameter Real C_leak   = 1.0e-12 "Inter-chamber leakage conductance [m3/(s Pa)]";
  parameter Real b_visc   = 800.0   "Viscous friction coefficient [N s/m]";
  parameter Real k_stop   = 1.0e7   "End-stop stiffness [N/m]";
  parameter Real c_stop   = 5.0e3   "End-stop damping [N s/m]";
  parameter Real F_dist   = 70.0   "External disturbance load magnitude [N]";
  parameter Real x_target = 0.7*L_stroke "Mission target position [m]";

  // --- Controller parameters ---
  parameter Real Kp_pos   = 0.02   "Proportional gain [m3/s per m]";
  parameter Real Ki_pos   = 0.5    "Integral gain [m3/s per m.s]";
  parameter Real Kd_pos   = 0.003  "Derivative gain [m3/s per (m/s)]";
  parameter Real K_pfb    = 5.0e-8 "Pressure-force feedback gain [m3/s per N]";
  parameter Real Ts       = 0.01   "Controller sample period (100 Hz) [s]";

  // --- Continuous dynamic states ---
  Real x(start = 0.05, fixed = true)  "Actuator position [m]";
  Real v(start = 0.0,  fixed = true)  "Actuator velocity [m/s]";
  Real pA(start = 1.0e5, fixed = true) "Chamber A pressure [Pa]";
  Real pB(start = 1.0e5, fixed = true) "Chamber B pressure [Pa]";

  // --- Discrete controller states ---
  discrete Real errInt_d(start = 0.0, fixed = true) "Sampled integral error [m s]";
  discrete Real u_cmd(start   = 0.0, fixed = true)  "Saturated valve command [m3/s]";
  discrete Real e_t(start     = 0.0, fixed = true)  "Sampled position error [m]";
  discrete Real u_raw_d(start = 0.0, fixed = true) "Unsaturated sampled command [m3/s]";
  discrete Boolean sat_t(start = false, fixed = true) "Anti-windup saturation flag";

  // --- Computed physical quantities ---
  Real V_A     "Chamber A volume [m3]";
  Real V_B     "Chamber B volume [m3]";
  Real Q_A     "Flow into chamber A from valve [m3/s]";
  Real Q_B     "Flow into chamber B from valve [m3/s]";
  Real Q_leak  "Leakage flow A->B [m3/s]";
  Real F_act   "Actuator force [N]";
  Real F_stop  "Total end-stop force [N]";
  Real F_stop_lower "Lower end-stop force [N]";
  Real F_stop_upper "Upper end-stop force [N]";
  Real F_ext   "External disturbance load [N]";

  // --- Sensor / measurement traces ---
  Real e_pos   "Position error (target - actual) [m]";
  Real e_track "Tracking error magnitude [m]";
  Real x_meas  "Measured position [m]";
  Real v_meas  "Measured velocity [m/s]";
  Real pA_meas "Measured chamber A pressure [Pa]";
  Real pB_meas "Measured chamber B pressure [Pa]";
  Real u_meas  "Measured valve command [m3/s]";

equation
  // Compressible chamber volumes
  V_A = V_deadA + A_p*x;
  V_B = V_deadB + A_r*(L_stroke - x);

  // Four-way proportional valve: command meters flow into A and out of B
  // (positive command extends cylinder).
  Q_A = u_cmd;
  Q_B = -u_cmd;

  // Inter-chamber leakage from high to low pressure
  Q_leak = C_leak*(pA - pB);

  // Pressure dynamics via fluid compressibility (continuity)
  der(pA) = (beta/V_A) * (Q_A - A_p*v - Q_leak);
  der(pB) = (beta/V_B) * (Q_B + A_r*v + Q_leak);

  // Actuator force
  F_act = pA*A_p - pB*A_r;

  // End-stop forces: spring-damper active only outside [0, L_stroke]
  // Lower stop (x < 0): force pushes positive (away from stop)
  F_stop_lower = if x < 0.0 then (-k_stop*x - c_stop*min(v, 0.0)) else 0.0;
  // Upper stop (x > L_stroke): force pushes negative (away from stop)
  F_stop_upper = if x > L_stroke then (-k_stop*(x - L_stroke) - c_stop*max(v, 0.0)) else 0.0;
  F_stop = F_stop_lower + F_stop_upper;

  // External disturbance: 70 N opposing motion during middle third of 10 s mission
  F_ext = if (time >= 10.0/3.0 and time <= 20.0/3.0) then F_dist else 0.0;

  // Mechanical dynamics
  der(x) = v;
  m_load*der(v) = F_act - b_visc*v - F_stop - F_ext;

  // Position error and tracking error
  e_pos   = x_target - x;
  e_track = abs(e_pos);

  // Synchronized sensor traces (continuous)
  x_meas  = x;
  v_meas  = v;
  pA_meas = pA;
  pB_meas = pB;
  u_meas  = u_cmd;

  // --- Sampled pressure-aware PID position controller (100 Hz) ---
  when sample(0, Ts) then
    e_t = x_target - x;
    // Anti-windup: hold integral when command was saturating in error direction
    sat_t = (pre(u_cmd) >= Q_max and e_t > 0.0) or
            (pre(u_cmd) <= -Q_max and e_t < 0.0);
    errInt_d = if not sat_t then pre(errInt_d) + Ts*e_t else pre(errInt_d);
    // Pressure-aware PID: position terms plus load-pressure (force) feedback
    u_raw_d = Kp_pos*e_t + Ki_pos*errInt_d - Kd_pos*v - K_pfb*(pA*A_p - pB*A_r);
    // Saturation to allowed valve command magnitude
    u_cmd = if u_raw_d > Q_max then Q_max
            else if u_raw_d < -Q_max then -Q_max
            else u_raw_d;
  end when;

  // --- Bound requirements (asserted at runtime) ---
  assert(x >= -0.01 and x <= L_stroke + 0.01,
         "Actuator position exceeded travel bounds");
  assert(abs(u_cmd) <= Q_max + 1.0e-9,
         "Valve command exceeded allowed magnitude");
  assert(pA >= 0.0 and pA <= p_supply + 5.0e6,
         "Chamber A pressure out of bounds");
  assert(pB >= 0.0 and pB <= p_supply + 5.0e6,
         "Chamber B pressure out of bounds");
  assert(abs(v) <= 5.0,
         "Velocity exceeded bound");
  // Primary tracking error bound after 6.5 s
  if time >= 6.5 then
    assert(e_track <= 0.014,
           "Primary tracking error exceeded 0.014 m after 6.5 s");
  end if;

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info =
      "Mission HydCylinderPositionB: move from initial position to 70 percent
       of available travel (0.35 m) and hold. Double-acting cylinder with
       compressible chambers, four-way proportional valve, leakage, and
       mechanical end stops. Pressure-aware sampled PID position control at
       100 Hz. A 70 N external load is injected during the middle third of the
       10 s mission. Sensor traces of position, velocity, chamber pressures,
       and valve command are synchronized for export."));
end HydCylinderPositionB;