model HydCylinderConserveB
  // Cylinder geometry (from requirement)
  parameter Modelica.Units.SI.Area A_p = 0.0040 "Piston (cap-side) area";
  parameter Modelica.Units.SI.Area A_r = 0.0032 "Rod area";
  parameter Modelica.Units.SI.Length L = 0.50 "Stroke";
  parameter Modelica.Units.SI.Mass m = 110 "Moving mass";

  // Fluid / supply (realistic values not pinned by requirement; conservative defaults)
  parameter Modelica.Units.SI.Pressure Ps = 7.0e6 "Supply pressure";
  parameter Modelica.Units.SI.Pressure Pt = 5.0e5 "Return pressure";
  parameter Modelica.Units.SI.Pressure beta_e = 1.6e9 "Effective bulk modulus (compressibility)";
  parameter Modelica.Units.SI.Volume V_dead = 1.0e-3 "Dead (line) volume each chamber";
  parameter Modelica.Units.SI.Pressure p_a0 = 1.0e6 "Initial cap-side pressure";
  parameter Modelica.Units.SI.Pressure p_b0 = 5.0e6 "Initial rod-side pressure (force-balanced)";
  // Viscous friction is a realistic effect required by the scenario; coefficient not pinned by requirement.
  parameter Modelica.Units.SI.TranslationalDampingConstant b_vis = 400.0 "Viscous friction coefficient";

  // Valve (from requirement: command magnitude 0.001 m3/s)
  parameter Modelica.Units.SI.VolumeFlowRate Q_max = 0.001 "Allowed command magnitude";

  // Mission
  parameter Real f_cycle = 1.0 "Actuation cycle frequency (Hz)";
  parameter Modelica.Units.SI.Length x_center = 0.25 "Cycle center";
  parameter Modelica.Units.SI.Length x_amp = 0.20 "Cycle amplitude";
  parameter Modelica.Units.SI.Time t_end = 10.0 "Mission duration";
  parameter Modelica.Units.SI.Force F_dist = 126 "Injected load variation";
  // Energy cap value not stated in requirement; a declared placeholder is used.
  parameter Modelica.Units.SI.Energy E_cap = 15000 "Declared energy-use cap (placeholder; not specified by request)";

  // Controller gains (tuned for bounded tracking; not pinned by requirement)
  parameter Real kp = 350.0 "Position gain";
  parameter Real kd = 45.0 "Velocity gain";
  parameter Real e_min_factor = 0.3 "Floor of energy-aware degradation factor";

  // States
  Modelica.Units.SI.Length x "Piston position (actuator state)";
  Modelica.Units.SI.Velocity v "Piston velocity (actuator state)";
  Modelica.Units.SI.Pressure p_a "Cap-side chamber pressure";
  Modelica.Units.SI.Pressure p_b "Rod-side chamber pressure";
  Modelica.Units.SI.VolumeFlowRate Q_a "Flow into cap-side chamber";
  Modelica.Units.SI.VolumeFlowRate Q_b "Flow into rod-side chamber";
  Modelica.Units.SI.VolumeFlowRate Q_supply "Supply flow (measured)";
  Modelica.Units.SI.Force F_cyl "Net cylinder force";
  Modelica.Units.SI.Force F_disturbance "Disturbance load";
  Modelica.Units.SI.Energy E_acc "Accumulated supply energy";

  // Reference / control / sensors
  Modelica.Units.SI.Length x_ref "Reference position";
  Modelica.Units.SI.Length e_track "Primary tracking error (x_ref - x)";
  Modelica.Units.SI.VolumeFlowRate u_cmd "Unsaturated valve command";
  Modelica.Units.SI.VolumeFlowRate u_sat "Saturated valve command";
  Real energy_factor "Energy-aware command scaling in [e_min_factor, 1]";
  Real track_err_norm "Tracking error norm (zero-error branch protected)";
  Real cycle_progress "Fractional mission progress 0..1";
  Boolean cycle_complete "Terminal cycle completion flag";
  Boolean tracking_ok "Primary tracking bound satisfied after 6.5 s";
  Boolean energy_ok "Declared energy cap respected";

initial equation
  x = x_center;
  v = 0;
  p_a = p_a0;
  p_b = p_b0;
  E_acc = 0;

equation
  // Repeated actuation cycle reference
  x_ref = x_center + x_amp*Modelica.Math.sin(2*Modelica.Constants.pi*f_cycle*time);

  // Chamber volumes (compressibility)
  // V_a = V_dead + A_p*x ;  V_b = V_dead + (A_p - A_r)*(L - x)
  der(p_a) = beta_e/(V_dead + A_p*x) * (Q_a - A_p*v);
  der(p_b) = beta_e/(V_dead + (A_p - A_r)*(L - x)) * (Q_b + (A_p - A_r)*v);

  // Cylinder force and rigid-body motion
  F_cyl = p_a*A_p - p_b*(A_p - A_r);

  // Controlled disturbance injected during the middle third of the mission
  F_disturbance = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then F_dist else 0.0;

  m*der(v) = F_cyl - F_disturbance - b_vis*v;
  der(x) = v;

  // Energy-aware motion control with bounded performance degradation:
  // scale command smoothly toward e_min_factor as E_acc approaches E_cap.
  energy_factor = e_min_factor + (1.0 - e_min_factor)*max(0.0, min(1.0, (E_cap - E_acc)/E_cap));

  e_track = x_ref - x;
  u_cmd = energy_factor*(kp*e_track - kd*v);

  // Valve saturation (magnitude bound) plus supply/return directionality
  u_sat = max(-Q_max, min(Q_max, u_cmd));

  // Four-way valve: positive command meters supply->A and B->tank; negative reverses.
  Q_a = u_sat;
  Q_b = -u_sat;

  // Measured supply flow (drawn from supply rail in either direction)
  Q_supply = max(0.0, Q_a) + max(0.0, Q_b);

  // Accumulated hydraulic energy drawn from supply
  der(E_acc) = Ps*Q_supply;

  // Tracking error norm with well-defined zero-error branch
  track_err_norm = sqrt(e_track*e_track + 1.0e-12);

  // Mission instrumentation flags
  cycle_progress = max(0.0, min(1.0, time/t_end));
  cycle_complete = time >= t_end;
  tracking_ok = (time < 6.5) or (abs(e_track) < 0.024);
  energy_ok = E_acc <= E_cap;

  annotation (
    Icon(coordinateSystem(preserveAspectRatio=false), graphics={Rectangle(extent={{-100,-100},{100,100}},lineColor={0,0,127})}),
    Diagram(coordinateSystem(preserveAspectRatio=false)),
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01));
end HydCylinderConserveB;