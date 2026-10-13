model HydMotorTrackE
  import SI = Modelica.SIunits;

  // Stated actuator and load parameters
  parameter SI.VolumeFlowRate Q_max = 0.002 "bounded valve command magnitude";
  parameter SI.Volume Dm_rev = 48e-6 "48 cm3/rev hydraulic motor displacement";
  parameter Real eta_vol = 0.92 "declared motor volumetric efficiency";
  parameter Real N = 12 "12:1 gearbox ratio, motor:table";
  parameter SI.Mass m_table = 130 "rotary table mass";

  // Assumed values for facts not stated; required only to make the model finite and executable.
  parameter SI.Radius R_lin = 0.05 "assumed table linear conversion radius; geometry unspecified";
  parameter SI.Pressure p_supply = 5.0e6 "assumed supply pressure; unspecified";
  final parameter SI.Pressure p_relief = p_supply + 1.0e6 "assumed cross-port relief setting";
  final parameter SI.Pressure p_init = p_supply/10 "assumed chamber preload";
  parameter SI.Pressure beta = 1.6e9 "assumed oil bulk modulus";
  parameter SI.Volume Vdead = 150.0e-6 "assumed trapped chamber volume";
  parameter Real C_leak(final unit="m3/(s.Pa)") = 1.0e-11 "assumed pressure-dependent leakage coefficient";
  parameter Real b_visc(final unit="N.s/m") = 50.0 "assumed viscous friction coefficient";
  parameter SI.Time tau_valve = 0.01 "assumed valve flow dynamics time constant";
  parameter Real G_relief(final unit="m3/(s.Pa)") = 2.0e-8 "assumed relief valve conductance";

  // Trajectory assumptions: smooth two-segment quintic motion; amplitudes not stated.
  parameter SI.Time T_total = 16.0;
  parameter SI.Time t_mid = 8.0;
  final parameter SI.Time t_dist_start = T_total/3.0 "middle-third start";
  final parameter SI.Time t_dist_end = 2.0*T_total/3.0 "middle-third end";
  parameter SI.Length x0 = 0.0;
  parameter SI.Length x1 = 0.5;
  parameter SI.Length x2 = 0.2;

  // Control gains
  parameter Real Kp_x(final unit="(m3/s)/m") = 15.0 "position feedback gain";
  parameter Real Kd_x(final unit="(m3/s)/(m/s)") = 0.80 "velocity damping feedback gain";
  final parameter Real Kp_p(final unit="m3/(s.Pa)") = C_leak "pressure feedback gain matched to leakage";

  // Acceptance bounds
  parameter SI.Length x_min = -0.1;
  parameter SI.Length x_max = 0.8;
  parameter SI.Velocity v_max = 0.5;
  parameter SI.Acceleration a_max = 10.0;
  parameter SI.Length e_max_all = 0.05;
  parameter SI.Length e_max_final = 0.016;
  parameter SI.Pressure pressure_margin = 1.0e5;
  parameter SI.VolumeFlowRate Q_margin = 1.0e-9;
  parameter SI.VolumeFlowRate Q_relief_max = 0.004;

  // Finite-value bounds for NaN/infinite checks
  final parameter SI.Length finite_L = 1.0e100;
  final parameter SI.Velocity finite_V = 1.0e100;
  final parameter SI.Pressure finite_P = 1.0e100;
  final parameter SI.VolumeFlowRate finite_Q = 1.0e100;
  final parameter SI.Acceleration finite_A = 1.0e100;
  final parameter SI.Force finite_F = 1.0e100;

  // Derived motor displacement
  final parameter Real Dm(final unit="m3/rad") = Dm_rev/(2.0*Modelica.Constants.pi);
  final parameter Real C_h(final unit="m3/Pa") = Vdead/beta;

  // Dynamic states
  SI.Length x(start=x0, fixed=true) "table linear position";
  SI.Velocity v(start=0.0, fixed=true) "table linear velocity";
  SI.Pressure pA(start=p_init, fixed=true) "motor chamber A pressure";
  SI.Pressure pB(start=p_init, fixed=true) "motor chamber B pressure";
  SI.VolumeFlowRate Q_valve(start=0.0, fixed=true) "actual pressure-compensated valve flow";

  // Trajectory and sensor traces
  SI.Length x_d "desired position";
  SI.Velocity v_d "desired velocity";
  SI.Acceleration a_d "desired acceleration";
  Real s "normalized segment time";
  SI.Length e "position tracking error";
  SI.Pressure dp "motor differential pressure";
  SI.Pressure dp_ref "feedforward pressure reference";
  SI.AngularVelocity omega_table "table angular velocity";
  SI.AngularVelocity omega_m "motor angular velocity";
  SI.VolumeFlowRate Q_etaLoss "volumetric-efficiency leakage";
  SI.VolumeFlowRate Q_crossLeak "pressure leakage";
  SI.VolumeFlowRate Q_leak "total leakage";
  SI.VolumeFlowRate Q_relief "relief valve flow";
  SI.Force F_hyd "hydraulic force at table";
  SI.Force F_visc "viscous friction force";
  SI.Force F_payload "finite-duration payload disturbance";
  SI.Acceleration a_table "table acceleration";
  SI.VolumeFlowRate Q_ff "feedforward flow";
  SI.VolumeFlowRate u_raw "unbounded controller output";
  SI.VolumeFlowRate command "bounded valve command";
  SI.VolumeFlowRate Q_supply "supply flow";
  SI.Pressure pSupply "recorded supply pressure";

  // Acceptance booleans
  Boolean travelOK;
  Boolean pressureOK;
  Boolean flowOK;
  Boolean accelOK;
  Boolean errorOK;
  Boolean reliefOK;
  Boolean finiteOK;
  Boolean primaryErrorOK;
  Boolean acceptanceOK;

equation
  // Smooth two-segment quintic trajectory with zero endpoint velocity and acceleration.
  s = if time <= t_mid then max(0.0, min(time/t_mid, 1.0)) else max(0.0, min((time - t_mid)/(T_total - t_mid), 1.0));
  x_d = if time <= t_mid then x0 + (x1 - x0)*(10.0*s^3 - 15.0*s^4 + 6.0*s^5) else x1 + (x2 - x1)*(10.0*s^3 - 15.0*s^4 + 6.0*s^5);
  v_d = if time <= t_mid then (x1 - x0)/t_mid*(30.0*s^2 - 60.0*s^3 + 30.0*s^4) else (x2 - x1)/(T_total - t_mid)*(30.0*s^2 - 60.0*s^3 + 30.0*s^4);
  a_d = if time <= t_mid then (x1 - x0)/t_mid^2*(60.0*s - 180.0*s^2 + 120.0*s^3) else (x2 - x1)/(T_total - t_mid)^2*(60.0*s - 180.0*s^2 + 120.0*s^3);

  // Mechanical representation: motor, 12:1 gearbox, rotary table as linear-equivalent mass.
  omega_table = v/R_lin;
  omega_m = N*omega_table;
  dp = pA - pB;

  // Motor flow balance with volumetric efficiency and pressure leakage.
  Q_etaLoss = Dm*omega_m*(1.0/eta_vol - 1.0);
  Q_crossLeak = C_leak*dp;
  Q_leak = Q_etaLoss + Q_crossLeak;

  // Cross-port relief valve; bounded and finite-duration behavior.
  Q_relief = if dp > p_relief then G_relief*(dp - p_relief) elseif dp < -p_relief then G_relief*(dp + p_relief) else 0.0;

  // Chamber pressure dynamics.
  C_h*der(pA) = Q_valve - Dm*omega_m - Q_leak - Q_relief;
  C_h*der(pB) = -Q_valve + Dm*omega_m + Q_leak + Q_relief;

  // Table dynamics with viscous friction and controlled 264 N middle-third payload step.
  F_hyd = N*Dm*dp/R_lin;
  F_visc = b_visc*v;
  F_payload = if time >= t_dist_start and time <= t_dist_end then 264.0 else 0.0;
  a_table = (F_hyd - F_visc - F_payload)/m_table;
  der(v) = a_table;
  der(x) = v;

  // Feedforward flow control with pressure-position feedback.
  dp_ref = (m_table*a_d + b_visc*v_d)*R_lin/(N*Dm);
  Q_ff = Dm*N*v_d/(R_lin*eta_vol) + C_leak*dp_ref;
  e = x_d - x;
  u_raw = Q_ff + Kp_x*e + Kd_x*(v_d - v) + Kp_p*(dp - dp_ref);
  command = max(-Q_max, min(Q_max, u_raw));
  der(Q_valve) = (command - Q_valve)/tau_valve;

  // Supply/sensor records.
  Q_supply = abs(Q_valve);
  pSupply = p_supply;

  // Fail-closed acceptance bounds.
  travelOK = x >= x_min and x <= x_max and abs(v) <= v_max;
  pressureOK = pA >= 0.0 and pA <= p_relief + pressure_margin and pB >= 0.0 and pB <= p_relief + pressure_margin;
  flowOK = abs(command) <= Q_max + Q_margin and abs(Q_supply) <= Q_max + Q_margin;
  accelOK = abs(a_table) <= a_max;
  errorOK = abs(e) <= e_max_all;
  reliefOK = abs(dp) <= p_relief + pressure_margin and abs(Q_relief) <= Q_relief_max;
  finiteOK = abs(x) < finite_L and abs(v) < finite_V and abs(pA) < finite_P and abs(pB) < finite_P and abs(dp) < finite_P and abs(Q_valve) < finite_Q and abs(command) < finite_Q and abs(Q_supply) < finite_Q and abs(Q_relief) < finite_Q and abs(e) < finite_L and abs(a_table) < finite_A and abs(u_raw) < finite_Q and abs(Q_ff) < finite_Q and abs(dp_ref) < finite_P and abs(x_d) < finite_L and abs(v_d) < finite_V and abs(F_hyd) < finite_F and abs(F_payload) < finite_F;
  primaryErrorOK = time < 10.4 or abs(e) <= e_max_final;
  acceptanceOK = travelOK and pressureOK and flowOK and accelOK and errorOK and reliefOK and finiteOK and primaryErrorOK;
  assert(acceptanceOK, "HydMotorTrackE fail-closed acceptance bound violated", AssertionLevel.error);

  annotation (experiment(StopTime=16.0, Interval=0.004, Tolerance=1.0e-6));
end HydMotorTrackE;