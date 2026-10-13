model PneuGripTrackF
  "Pneumatic gripper position tracking under payload disturbance"

  // Physical parameters
  parameter Real L = 0.035 "Cylinder travel [m]";
  parameter Real A = 0.0012 "Piston area [m2]";
  parameter Real m = 0.8 "Gripper finger mass [kg]";
  parameter Real b_fric = 100.0 "Viscous friction coefficient [N.s/m]";
  parameter Real V0 = 4.0e-6 "Dead volume per chamber [m3]";
  parameter Real p_atm = 101325.0 "Atmospheric pressure [Pa]";
  parameter Real p_supply = 6.0e5 "Supply pressure [Pa]";
  parameter Real R_air = 287.05 "Specific gas constant air [J/(kg.K)]";
  parameter Real T_air = 293.15 "Gas temperature [K]";
  parameter Real m_dot_max = 0.001 "Max valve mass flow [kg/s]";
  parameter Real k_leak = 5.0e-10 "Leakage conductance [kg/(s.Pa)]";
  parameter Real p_nom = 3.0e5 "Nominal chamber pressure [Pa]";
  parameter Real p_relief = 7.5e5 "Relief valve threshold [Pa]";

  // Control parameters
  parameter Real tau_v = 0.005 "Valve time constant [s]";
  parameter Real Kp_pos = 25000.0 "Position error gain [N/m]";
  parameter Real Kd_pos = 200.0 "Velocity error gain [N.s/m]";
  parameter Real Kp_pres = 3.0e-5 "Pressure feedback gain [kg/(s.Pa)]";
  parameter Real Kff = 1.0 "Feedforward gain";

  // Mission parameters
  parameter Real F_payload = 319.0 "Payload step disturbance [N]";
  parameter Real T1_seg = 4.0 "Segment 1 end time [s]";
  parameter Real T2_seg = 8.0 "Segment 2 end time [s]";
  parameter Real T_start_dist = 20.0/3.0 "Disturbance start time [s]";
  parameter Real T_end_dist = 40.0/3.0 "Disturbance end time [s]";
  parameter Real dt = 0.002 "Sample period 500 Hz [s]";

  // Dynamic states
  Real x(start=0.0, fixed=true) "Finger position [m]";
  Real v(start=0.0, fixed=true) "Finger velocity [m/s]";
  Real p1(start=3.0e5, fixed=true) "Chamber 1 pressure [Pa]";
  Real p2(start=3.0e5, fixed=true) "Chamber 2 pressure [Pa]";
  Real m_dot_v1(start=0.0, fixed=true) "Valve 1 actual mass flow [kg/s]";
  Real m_dot_v2(start=0.0, fixed=true) "Valve 2 actual mass flow [kg/s]";

  // Computed quantities
  Real V1 "Chamber 1 volume [m3]";
  Real V2 "Chamber 2 volume [m3]";
  Real m_dot_leak1 "Leakage flow chamber 1 [kg/s]";
  Real m_dot_leak2 "Leakage flow chamber 2 [kg/s]";
  Real m_dot_supply "Total supply flow [kg/s]";
  Real F_pneu "Pneumatic force [N]";
  Real F_dist "Disturbance force [N]";
  Real a_act "Actual acceleration [m/s2]";

  // Trajectory
  Real x_ref "Reference position [m]";
  Real v_ref "Reference velocity [m/s]";
  Real a_ref "Reference acceleration [m/s2]";
  Real err_pos "Position error [m]";
  Real track_err "Tracking error magnitude [m]";

  // Control signals
  Real F_des "Desired net force [N]";
  Real p1_cmd "Chamber 1 pressure command [Pa]";
  Real p2_cmd "Chamber 2 pressure command [Pa]";
  Real m_dot_ff1 "Feedforward flow 1 [kg/s]";
  Real m_dot_ff2 "Feedforward flow 2 [kg/s]";
  Real m_dot_cmd1_sat "Saturated command 1 [kg/s]";
  Real m_dot_cmd2_sat "Saturated command 2 [kg/s]";

  // Relief indicators
  Real relief1 "Relief valve 1 active flag";
  Real relief2 "Relief valve 2 active flag";

  // Sampled traces at 500 Hz
  discrete Real x_s(start=0.0) "Sampled position [m]";
  discrete Real v_s(start=0.0) "Sampled velocity [m/s]";
  discrete Real p1_s(start=3.0e5) "Sampled pressure 1 [Pa]";
  discrete Real p2_s(start=3.0e5) "Sampled pressure 2 [Pa]";
  discrete Real m_dot_supply_s(start=0.0) "Sampled supply flow [kg/s]";
  discrete Real cmd1_s(start=0.0) "Sampled command 1 [kg/s]";
  discrete Real cmd2_s(start=0.0) "Sampled command 2 [kg/s]";
  discrete Real track_err_s(start=0.0) "Sampled tracking error [m]";

protected
  Real s1 "Segment 1 normalized time [dimensionless]";
  Real s2 "Segment 2 normalized time [dimensionless]";

equation
  // Chamber volumes (compressible)
  V1 = V0 + A * x;
  V2 = V0 + A * (L - x);

  // Leakage flows to atmosphere
  m_dot_leak1 = k_leak * (p1 - p_atm);
  m_dot_leak2 = k_leak * (p2 - p_atm);

  // Chamber pressure dynamics: ideal gas, isothermal
  der(p1) = (R_air * T_air / V1) * (m_dot_v1 - m_dot_leak1) - (p1 * A / V1) * v;
  der(p2) = (R_air * T_air / V2) * (m_dot_v2 - m_dot_leak2) + (p2 * A / V2) * v;

  // Relief valve monitoring
  relief1 = if p1 > p_relief then 1.0 else 0.0;
  relief2 = if p2 > p_relief then 1.0 else 0.0;

  // Mechanical dynamics
  F_pneu = A * (p1 - p2);
  F_dist = if (time >= T_start_dist and time <= T_end_dist) then F_payload else 0.0;
  a_act = (F_pneu - b_fric * v - F_dist) / m;
  der(x) = v;
  der(v) = a_act;

  // Smooth two-segment trajectory (cubic Hermite: 3s^2 - 2s^3)
  s1 = time / T1_seg;
  s2 = (time - T1_seg) / (T2_seg - T1_seg);

  if time < T1_seg then
    x_ref = (3.0 * s1 * s1 - 2.0 * s1 * s1 * s1) * (L * 0.5);
    v_ref = (6.0 * s1 - 6.0 * s1 * s1) * (L * 0.5) / T1_seg;
    a_ref = (6.0 - 12.0 * s1) * (L * 0.5) / (T1_seg * T1_seg);
  elseif time < T2_seg then
    x_ref = L * 0.5 + (3.0 * s2 * s2 - 2.0 * s2 * s2 * s2) * (L * 0.5);
    v_ref = (6.0 * s2 - 6.0 * s2 * s2) * (L * 0.5) / (T2_seg - T1_seg);
    a_ref = (6.0 - 12.0 * s2) * (L * 0.5) / ((T2_seg - T1_seg) * (T2_seg - T1_seg));
  else
    x_ref = L;
    v_ref = 0.0;
    a_ref = 0.0;
  end if;

  // Tracking error
  err_pos = x_ref - x;
  track_err = abs(err_pos);

  // Control: feedforward flow + pressure-position feedback
  F_des = m * a_ref + b_fric * v_ref + Kp_pos * err_pos + Kd_pos * (v_ref - v);

  // Pressure commands bounded to physical supply range
  p1_cmd = max(p_atm + 1.0e4, min(p_supply - 1.0e4, p_nom + F_des / (2.0 * A)));
  p2_cmd = max(p_atm + 1.0e4, min(p_supply - 1.0e4, p_nom - F_des / (2.0 * A)));

  // Feedforward: compensates volume change rate due to reference velocity
  m_dot_ff1 = Kff * (p1 / (R_air * T_air)) * A * v_ref;
  m_dot_ff2 = -Kff * (p2 / (R_air * T_air)) * A * v_ref;

  // Saturated valve commands: feedforward + pressure feedback
  m_dot_cmd1_sat = max(-m_dot_max, min(m_dot_max, m_dot_ff1 + Kp_pres * (p1_cmd - p1)));
  m_dot_cmd2_sat = max(-m_dot_max, min(m_dot_max, m_dot_ff2 + Kp_pres * (p2_cmd - p2)));

  // Valve dynamics: first-order lag
  der(m_dot_v1) = (m_dot_cmd1_sat - m_dot_v1) / tau_v;
  der(m_dot_v2) = (m_dot_cmd2_sat - m_dot_v2) / tau_v;

  // Supply flow: positive valve flows plus leakage consumption
  m_dot_supply = max(0.0, m_dot_v1) + max(0.0, m_dot_v2) + m_dot_leak1 + m_dot_leak2;

  // Synchronized sampled traces at 500 Hz
  when sample(0, dt) then
    x_s = x;
    v_s = v;
    p1_s = p1;
    p2_s = p2;
    m_dot_supply_s = m_dot_supply;
    cmd1_s = m_dot_v1;
    cmd2_s = m_dot_v2;
    track_err_s = track_err;
  end when;

  // Verification criteria bounds
  assert(x >= -1.0e-3 and x <= L + 1.0e-3, "Travel bound violated");
  assert(p1 > 0.0 and p1 < p_relief, "Pressure 1 bound or relief violated");
  assert(p2 > 0.0 and p2 < p_relief, "Pressure 2 bound or relief violated");
  assert(abs(m_dot_v1) <= m_dot_max + 1.0e-6, "Valve 1 flow bound violated");
  assert(abs(m_dot_v2) <= m_dot_max + 1.0e-6, "Valve 2 flow bound violated");
  assert(abs(a_act) < 5000.0, "Acceleration bound violated");
  assert(time < 13.0 or track_err < 0.014, "Primary tracking error exceeded after 13 s");

  annotation(
    experiment(StartTime = 0, StopTime = 20, Interval = 0.002, Tolerance = 1.0e-6),
    Documentation(info = "Pneumatic gripper position tracking: two-segment smooth trajectory with 319 N payload step disturbance during middle third. Feedforward flow control with pressure-position feedback. Sampling at 500 Hz for 20 s with synchronized state, command, and sensor traces.")
  );
end PneuGripTrackF;