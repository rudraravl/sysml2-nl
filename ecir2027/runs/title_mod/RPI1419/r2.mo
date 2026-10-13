model ElectroSoftShapeC
  // ========================
  // Stated requirements
  // ========================
  // Maximum command magnitude: 4.6 kV
  // Disturbance: 5.4 N during middle third (4 s to 8 s)
  // Run: 125 Hz for 12 s
  // Primary tracking error < 0.047 m after 7.8 s
  // Membrane: 0.20 m x 0.05 m, thickness 0.8 mm
  // Explicit permittivity, viscoelasticity, leakage, thermal state
  // Gravity included; undeformed and actuated geometry in shared frame

  // ========================
  // Geometry and material (assumed values are placeholders for facts not stated)
  // ========================
  parameter Real L0 = 0.20 "Undeformed membrane length (m)";
  parameter Real w = 0.05 "Membrane width (m)";
  parameter Real h = 0.0008 "Membrane thickness (m)";
  parameter Real A_mem = w * L0 "Electrode area (m2)";

  // Explicit permittivity (relative permittivity assumed, not stated)
  constant Real epsilon0 = 8.854187817e-12 "Vacuum permittivity (F/m)";
  parameter Real epsilon_r = 4.7 "Relative permittivity (assumed)";
  parameter Real epsilon = epsilon0 * epsilon_r "Absolute permittivity (F/m)";

  // Mass and gravity (density assumed, not stated)
  parameter Real rho = 1000.0 "Membrane density (kg/m3, assumed)";
  parameter Real m = rho * A_mem * h "Membrane mass (kg)";
  parameter Real g = 9.81 "Gravity (m/s2)";

  // Mechanical stiffness and damping (assumed for demonstration)
  parameter Real k1 = 200.0 "Elastic stiffness (N/m)";
  parameter Real k2 = 100.0 "Viscoelastic stiffness (N/m)";
  parameter Real c1 = 2.0 "Parallel damping (N.s/m)";
  parameter Real tau_v = 0.5 "Viscoelastic relaxation time (s, assumed)";
  parameter Real c2 = k2 * tau_v "Viscoelastic damping (N.s/m)";

  // Leakage (conductivity assumed, not stated)
  parameter Real sigma_leak = 1.0e-12 "Leakage conductivity (S/m, assumed)";
  parameter Real G_leak = sigma_leak * A_mem / h "Leakage conductance (S)";

  // Thermal state (convection and heat capacity assumed, not stated)
  parameter Real cp = 1500.0 "Specific heat (J/(kg.K), assumed)";
  parameter Real C_th = m * cp "Thermal capacity (J/K)";
  parameter Real h_conv = 10.0 "Convection coefficient (W/(m2.K), assumed)";
  parameter Real A_surf = 2.0 * (w * L0 + L0 * h + w * h) "Surface area (m2)";
  parameter Real T_amb = 293.15 "Ambient temperature (K)";

  // Actuator channel (slew limit assumed, not stated)
  parameter Real Vmax = 4600.0 "Maximum command magnitude (V)";
  parameter Real slew_limit = 5000.0 "Slew limit (V/s, assumed)";
  parameter Real tau_channel = 0.05 "Channel time constant (s, assumed)";

  // Controller (gains and target assumed, not stated)
  parameter Real target_elongation = 0.03 "Declared target elongation (m, assumed)";
  parameter Real Kp = 4000.0 "Proportional gain (V/m)";
  parameter Real Ki = 1500.0 "Integral gain (V/(m.s))";

  // ========================
  // Dynamic states
  // ========================
  Real x(start = 0.0) "Tip elongation (m)";
  Real v(start = 0.0) "Tip velocity (m/s)";
  Real z(start = 0.0) "Viscoelastic internal displacement (m)";
  Real T(start = T_amb) "Lumped temperature (K)";
  Real V_act(start = 0.0) "Actuated high voltage (V)";
  Real xi(start = 0.0) "Controller integrator state (V.s/m)";

  // ========================
  // Algebraic variables
  // ========================
  Real F_act "Dielectric actuation force (N)";
  Real F_vis "Viscoelastic branch force (N)";
  Real F_int "Total internal membrane force (N)";
  Real F_dist "Disturbance tip load (N)";
  Real P_leak "Leakage power (W)";
  Real P_visc "Viscous dissipation (W)";
  Real P_conv "Convective heat flow (W)";
  Real y_undeformed "Undeformed tip position in shared frame (m)";
  Real y_actuated "Actuated tip position in shared frame (m)";
  Real y_target "Declared target tip position (m)";
  Real e_shape "Primary shape tracking error (m)";
  Real V_unsat "Unsaturated controller command (V)";
  Real V_cmd "Saturated and slew-limited command (V)";
  Real rate "Unslewed voltage rate (V/s)";
  Integer state "Finite-state phase indicator";

  // ========================
  // Sensors and traces
  // ========================
  Real sensor_pressure "Maxwell pressure (Pa)";
  Real sensor_force "Membrane tensile force (N)";
  Real sensor_strain "Section strain (-)";
  Real sensor_tip_pose "Tip pose coordinate (m)";
  Real sensor_temp "Temperature (K)";
  Real sensor_voltage "Actuator voltage trace (V)";
  Real sensor_command "Command trace (V)";

  // ========================
  // Equations
  // ========================
equation
  // Geometry in shared vertical frame
  y_undeformed = L0;
  y_actuated = L0 + x;
  y_target = if time < 1.0 then L0 else L0 + target_elongation;

  // Primary tracking error
  e_shape = y_target - y_actuated;

  // Disturbance: 5.4 N during middle third of 12 s
  F_dist = if time >= 4.0 and time <= 8.0 then 5.4 else 0.0;

  // Dielectric-elastomer actuation force
  F_act = epsilon * A_mem * V_act * V_act / (h * h);

  // Viscoelastic Maxwell branch
  F_vis = k2 * (x - z);
  der(z) = F_vis / c2;

  // Total internal membrane force
  F_int = k1 * x + F_vis + c1 * v;

  // Mechanical dynamics with gravity
  m * der(v) = F_act + m * g + F_dist - F_int;
  der(x) = v;

  // Leakage and thermal state
  P_leak = G_leak * V_act * V_act;
  P_visc = c1 * v * v + F_vis * F_vis / c2;
  P_conv = h_conv * A_surf * (T - T_amb);
  C_th * der(T) = P_leak + P_visc - P_conv;

  // Slew-limited high-voltage channel
  rate = (V_cmd - V_act) / tau_channel;
  der(V_act) = if rate > slew_limit then slew_limit elseif rate < -slew_limit then -slew_limit else rate;

  // Shape-feedback controller with anti-windup
  der(xi) = if (V_cmd >= Vmax and e_shape > 0.0) or (V_cmd <= 0.0 and e_shape < 0.0) then 0.0 else e_shape;
  V_unsat = Kp * e_shape + Ki * xi;
  V_cmd = max(0.0, min(Vmax, V_unsat));

  // Finite-state phase indicator
  state = if time < 1.0 then 0 elseif time < 4.0 then 1 elseif time < 8.0 then 2 else 3;

  // Instrumentation
  sensor_pressure = epsilon * (V_act / h) * (V_act / h);
  sensor_force = F_int;
  sensor_strain = x / L0;
  sensor_tip_pose = y_actuated;
  sensor_temp = T;
  sensor_voltage = V_act;
  sensor_command = V_cmd;

  // ========================
  // Bounds and final error requirements
  // ========================
  assert(abs(V_act) <= Vmax + 1.0e-6, "Actuator bound exceeded: 4.6 kV");
  assert(abs(sensor_strain) <= 0.5, "Strain bound exceeded");
  assert(T >= 273.15 and T <= 373.15, "Temperature bound exceeded");
  assert(state >= 0 and state <= 3, "Finite-state invalid");
  assert(time <= 7.8 or abs(e_shape) < 0.047, "Primary tracking error exceeds 0.047 m after 7.8 s");

  annotation (
    experiment(StopTime = 12.0, Interval = 0.008, Tolerance = 1.0e-6),
    Documentation(info = "Soft robotic system ElectroSoftShapeC with reduced-order dielectric-elastomer membrane, shape feedback, disturbance injection, and bound enforcement.")
  );
end ElectroSoftShapeC;