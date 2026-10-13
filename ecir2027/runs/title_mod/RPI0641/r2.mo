model HydMotorTrackE
  "Verifiable hydraulic-motor rotary-table trajectory-tracking scenario with feedforward flow and pressure-position feedback"

  // ---- Facts stated in the requirement ----
  parameter Modelica.Units.SI.Volume D_m_rev = 48e-6
    "bidirectional hydraulic motor displacement, 48 cm3/rev";
  parameter Real eta_v(min=0, max=1) = 0.92
    "motor volumetric efficiency";
  parameter Modelica.Units.SI.Mass m_load = 130
    "rotary table mass, used as equivalent linear mass at unity radius";
  parameter Real n_gear = 12
    "gearbox ratio motor to table";
  parameter Modelica.Units.SI.VolumeFlowRate q_max = 0.002
    "valve command magnitude bound";
  parameter Modelica.Units.SI.Force F_payload = 264
    "controlled payload step force";
  parameter Modelica.Units.SI.Time Ts = 0.004
    "250 Hz control and trace sample period";
  parameter Modelica.Units.SI.Time t_sim = 16.0
    "run duration";
  parameter Modelica.Units.SI.Time t_primary = 10.4
    "primary tracking-error check time";
  parameter Modelica.Units.SI.Length e_primary = 0.016
    "primary tracking-error bound after t_primary";

  // ---- Values not stated in the requirement are marked as selected ----
  parameter Modelica.Units.SI.Length r_track = 1.0
    "unspecified rotary-table radius; unity normalization only, not a plant fact";
  parameter Modelica.Units.SI.Pressure p_supply = 20e6
    "unspecified supply pressure; finite bound selected for verification";
  parameter Modelica.Units.SI.Pressure p_relief = p_supply
    "unspecified relief pressure; finite bound selected for verification";
  parameter Real b_load(unit="N.s/m") = 300
    "unspecified viscous friction coefficient";
  parameter Real C_h(unit="m3/Pa") = 1e-11
    "unspecified hydraulic capacitance";
  parameter Real k_relief(unit="m3/(s*Pa)") = 1e-10
    "unspecified relief-valve conductance";
  parameter Real k_pos(unit="m3/(s*m)") = 0.002
    "unspecified position-feedback gain";
  parameter Real k_pres(unit="m3/(s*Pa)") = 5e-10
    "unspecified pressure-feedback gain";

  // Smooth two-segment reference; segment times/amplitudes not specified
  parameter Modelica.Units.SI.Length A1 = 0.5
    "first segment travel amplitude";
  parameter Modelica.Units.SI.Length A2 = -1.0
    "second segment travel amplitude";
  parameter Modelica.Units.SI.Time t1_start = 0.5;
  parameter Modelica.Units.SI.Time t1_end = 4.5;
  parameter Modelica.Units.SI.Time t2_start = 5.5;
  parameter Modelica.Units.SI.Time t2_end = 9.5;
  final parameter Modelica.Units.SI.Time T1 = t1_end - t1_start;
  final parameter Modelica.Units.SI.Time T2 = t2_end - t2_start;

  // Acceptance bounds not otherwise specified
  parameter Modelica.Units.SI.Length x_bound = 1.0
    "travel bound";
  parameter Modelica.Units.SI.Acceleration a_bound = 5.0
    "acceleration bound";
  parameter Modelica.Units.SI.Length e_bound_general = 0.05
    "general trajectory-error bound";

  // Motor displacement per radian
  final parameter Real D(unit="m3/rad") = D_m_rev/(2*Modelica.Constants.pi);
  final parameter Real beta_flow(unit="m2") = D*n_gear/(r_track*eta_v)
    "motor flow per table speed";
  final parameter Real alpha_force(unit="m2") = n_gear*D/r_track
    "table force per differential pressure";

  // ---- Observable outputs ----
  output Modelica.Units.SI.Position x(start=0)
    "table linear position";
  output Modelica.Units.SI.Velocity v(start=0)
    "table linear velocity";
  output Modelica.Units.SI.Angle theta_m
    "motor angular position";
  output Modelica.Units.SI.Pressure pA
    "motor chamber A pressure";
  output Modelica.Units.SI.Pressure pB
    "motor chamber B pressure";
  output Modelica.Units.SI.VolumeFlowRate q_supply
    "pump/supply flow magnitude";
  output Modelica.Units.SI.VolumeFlowRate q_cmd(start=0)
    "bounded valve command";
  output Modelica.Units.SI.Length e_traj
    "trajectory tracking error";

  // ---- Plant and control variables ----
  Modelica.Units.SI.AngularVelocity omega_m;
  Modelica.Units.SI.Acceleration a;
  Modelica.Units.SI.Pressure dp(start=0)
    "differential pressure pA - pB";
  Modelica.Units.SI.VolumeFlowRate q_motor;
  Modelica.Units.SI.VolumeFlowRate q_leak;
  Modelica.Units.SI.VolumeFlowRate q_relief;
  Modelica.Units.SI.Force F_h;
  Modelica.Units.SI.Force F_dist;
  Modelica.Units.SI.Force F_ref;
  Modelica.Units.SI.Pressure p_ref;
  Modelica.Units.SI.Length x_ref;
  Modelica.Units.SI.Velocity v_ref;
  Modelica.Units.SI.Acceleration a_ref;
  Modelica.Units.SI.VolumeFlowRate q_ff;

  Real u1;
  Real u2;
  Real s1;
  Real s1d;
  Real s1dd;
  Real s2;
  Real s2d;
  Real s2dd;

  // ---- Controller and synchronized traces ----
  discrete Modelica.Units.SI.VolumeFlowRate q_cmd_unsat;
  discrete Modelica.Units.SI.Time t_sampled;
  discrete Modelica.Units.SI.Position x_sampled;
  discrete Modelica.Units.SI.Velocity v_sampled;
  discrete Modelica.Units.SI.Pressure dp_sampled;
  discrete Modelica.Units.SI.Acceleration a_sampled;
  discrete Modelica.Units.SI.Pressure pA_sampled;
  discrete Modelica.Units.SI.Pressure pB_sampled;
  discrete Modelica.Units.SI.VolumeFlowRate q_supply_sampled;
  discrete Modelica.Units.SI.VolumeFlowRate q_cmd_sampled;
  discrete Modelica.Units.SI.VolumeFlowRate q_cmd_unsat_sampled;
  discrete Modelica.Units.SI.Length e_sampled;
  discrete Modelica.Units.SI.Length x_ref_sampled;
  discrete Modelica.Units.SI.Velocity v_ref_sampled;
  discrete Modelica.Units.SI.Acceleration a_ref_sampled;
  discrete Modelica.Units.SI.Force F_dist_sampled;
  discrete Modelica.Units.SI.Pressure p_ref_sampled;
  discrete Modelica.Units.SI.VolumeFlowRate q_ff_sampled;
  discrete Modelica.Units.SI.VolumeFlowRate q_motor_sampled;
  discrete Modelica.Units.SI.VolumeFlowRate q_leak_sampled;
  discrete Modelica.Units.SI.VolumeFlowRate q_relief_sampled;

equation
  // Smooth quintic two-segment position trajectory
  u1 = noEvent(min(1.0, max(0.0, (time - t1_start)/T1)));
  u2 = noEvent(min(1.0, max(0.0, (time - t2_start)/T2)));

  s1 = 10*u1^3 - 15*u1^4 + 6*u1^5;
  s1d = 30*u1^2*(1 - u1)^2;
  s1dd = 60*u1*(1 - u1)*(1 - 2*u1);

  s2 = 10*u2^3 - 15*u2^4 + 6*u2^5;
  s2d = 30*u2^2*(1 - u2)^2;
  s2dd = 60*u2*(1 - u2)*(1 - 2*u2);

  x_ref = A1*s1 + A2*s2;
  v_ref = A1/T1*s1d + A2/T2*s2d;
  a_ref = A1/(T1*T1)*s1dd + A2/(T2*T2)*s2dd;

  // Finite-duration middle-third payload disturbance
  F_dist = if time >= 16.0/3.0 and time <= 2.0*16.0/3.0 then F_payload else 0.0;

  // Hydraulic motor and gearbox kinematics
  omega_m = n_gear*v/r_track;
  theta_m = n_gear*x/r_track;

  // Motor flow includes volumetric efficiency as speed-dependent leakage
  q_motor = D*omega_m/eta_v;
  q_leak = (1.0/eta_v - 1.0)*D*omega_m;

  // Relief valve across motor chambers; bounds differential pressure
  q_relief = if dp > p_relief then k_relief*(dp - p_relief)
             else if dp < -p_relief then -k_relief*(-dp - p_relief)
             else 0.0;

  // Pressure-compensated proportional valve: commanded flow is bounded and
  // treated as independent of load pressure within relief bounds
  C_h*der(dp) = q_cmd - q_motor - q_relief;

  // Chamber pressures from differential pressure
  pA = p_supply/2.0 + dp/2.0;
  pB = p_supply/2.0 - dp/2.0;

  // Rotary-table equivalent linear dynamics through gearbox
  F_h = alpha_force*dp;
  m_load*der(v) = F_h - b_load*v - F_dist;
  der(x) = v;
  a = der(v);

  // Supply/pump flow magnitude
  q_supply = abs(q_cmd) + abs(q_relief);

  // Tracking error
  e_traj = x_ref - x;

  // Feedforward flow and pressure-position feedback reference
  q_ff = beta_flow*v_ref;
  F_ref = m_load*a_ref + b_load*v_ref + F_dist;
  p_ref = F_ref*r_track/(n_gear*D);

  // 250 Hz sampled controller and synchronized trace retention
  when sample(0, Ts) then
    q_cmd_unsat = q_ff + k_pos*(x_ref - x) + k_pres*(p_ref - dp);
    q_cmd = if q_cmd_unsat > q_max then q_max
            else if q_cmd_unsat < -q_max then -q_max
            else q_cmd_unsat;

    t_sampled = time;
    x_sampled = x;
    v_sampled = v;
    dp_sampled = dp;
    a_sampled = a;
    pA_sampled = pA;
    pB_sampled = pB;
    q_supply_sampled = q_supply;
    q_cmd_sampled = q_cmd;
    q_cmd_unsat_sampled = q_cmd_unsat;
    e_sampled = e_traj;
    x_ref_sampled = x_ref;
    v_ref_sampled = v_ref;
    a_ref_sampled = a_ref;
    F_dist_sampled = F_dist;
    p_ref_sampled = p_ref;
    q_ff_sampled = q_ff;
    q_motor_sampled = q_motor;
    q_leak_sampled = q_leak;
    q_relief_sampled = q_relief;
  end when;

  // Fail-closed acceptance bounds
  assert(abs(x) <= x_bound, "travel bound violated", AssertionLevel.error);
  assert(pA >= 0.0 and pA <= p_relief + 1.0, "pressure A bound violated", AssertionLevel.error);
  assert(pB >= 0.0 and pB <= p_relief + 1.0, "pressure B bound violated", AssertionLevel.error);
  assert(abs(dp) <= p_relief + 1.0, "relief differential pressure bound violated", AssertionLevel.error);
  assert(abs(q_cmd) <= q_max + 1e-9, "command flow bound violated", AssertionLevel.error);
  assert(q_supply <= 2.0*q_max + 1e-9, "supply flow bound violated", AssertionLevel.error);
  assert(abs(q_relief) <= q_max + 1e-9, "relief flow bound violated", AssertionLevel.error);
  assert(abs(a) <= a_bound, "acceleration bound violated", AssertionLevel.error);
  assert(abs(e_traj) <= e_bound_general, "trajectory error bound violated", AssertionLevel.error);
  assert(noEvent(time < t_primary) or abs(e_traj) <= e_primary,
         "primary tracking error bound violated after 10.4 s",
         AssertionLevel.error);

  // No estimator was specified; no estimator states are introduced.
  assert(abs(x) < 1e20 and abs(v) < 1e20 and abs(dp) < 1e20 and
         abs(pA) < 1e20 and abs(pB) < 1e20 and abs(a) < 1e20 and
         abs(q_cmd) < 1e20 and abs(q_cmd_unsat) < 1e20 and
         abs(q_ff) < 1e20 and abs(p_ref) < 1e20 and abs(e_traj) < 1e20 and
         abs(q_relief) < 1e20 and abs(q_supply) < 1e20 and
         abs(F_dist) < 1e20 and abs(x_ref) < 1e20 and
         abs(v_ref) < 1e20 and abs(a_ref) < 1e20 and
         abs(omega_m) < 1e20 and abs(theta_m) < 1e20 and
         abs(q_motor) < 1e20 and abs(q_leak) < 1e20,
         "NaN or infinite physical/control value detected",
         AssertionLevel.error);

  annotation(experiment(StopTime=16, Interval=0.004, Tolerance=1e-6));
end HydMotorTrackE;