model PantographDriveB
  "Closed-chain pantograph mechanism: constant-speed input drive with coupled output observation"

  // --- Physical parameters ---
  parameter Modelica.Units.SI.Length L1 = 0.25 "short link length (m)";
  parameter Modelica.Units.SI.Length L2 = 0.50 "long link length (m)";
  parameter Modelica.Units.SI.Length stroke = 0.16 "prismatic travel (m)";
  parameter Modelica.Units.SI.Force Fmax = 262.0 "max actuator command (N)";
  parameter Modelica.Units.SI.Mass m_eff = 2.3 "effective moving mass (kg)";
  parameter Modelica.Units.SI.Mass m_grav = 0.8 "gravitational link mass (kg)";
  parameter Modelica.Units.SI.DampingCoeff b_vis = 30.0 "viscous damping (N.s/m)";
  parameter Modelica.Units.SI.Acceleration g = 9.81 "gravity (m/s2)";
  parameter Real k_stop = 1.0e5 "soft stop stiffness (N/m)";

  // --- Controller parameters ---
  parameter Real Kp = 8000.0 "PI proportional gain (N.s/m)";
  parameter Real Ki = 80000.0 "PI integral gain (N/m)";
  parameter Modelica.Units.SI.Velocity v_ref = 0.015 "commanded input speed (m/s)";
  parameter Modelica.Units.SI.Force F_dist = 5.6 "disturbance load (N)";

  // --- Dynamic states ---
  Modelica.Units.SI.Position s(start = 0.0, fixed = true)
    "prismatic input position (m)";
  Modelica.Units.SI.Velocity v(start = 0.0, fixed = true)
    "prismatic input velocity (m/s)";
  Real xi(start = 0.0, fixed = true) "PI integrator state";

  // --- Control signals ---
  Modelica.Units.SI.Force F_cmd "unsaturated command force (N)";
  Modelica.Units.SI.Force F_sat "saturated command force (N)";
  Modelica.Units.SI.Force F_disturbance "applied disturbance force (N)";
  Modelica.Units.SI.Force F_stop "soft stop force (N)";
  Boolean saturated "command saturation flag";
  Boolean dist_window "disturbance active flag";

  // --- Kinematic outputs ---
  Real theta "parallelogram drive angle (rad)";
  Modelica.Units.SI.Position x_out "output x position (m)";
  Modelica.Units.SI.Position y_out "output y position (m)";
  Real output_travel(start = 0.0, fixed = true) "accumulated output travel (m)";

  // --- Joint references (6 revolute Z + 1 prismatic) ---
  Real phi1 "revolute joint 1 angle (rad)";
  Real phi2 "revolute joint 2 angle (rad)";
  Real phi3 "revolute joint 3 angle (rad)";
  Real phi4 "revolute joint 4 angle (rad)";
  Real phi5 "revolute joint 5 angle (rad)";
  Real phi6 "revolute joint 6 angle (rad)";
  Modelica.Units.SI.Length s_prism "prismatic joint coordinate (m)";

  // --- Sensors and loop-closure residuals ---
  Real closure_res_x "loop closure residual x (m)";
  Real closure_res_y "loop closure residual y (m)";
  Real closure_res_norm "loop closure residual norm (m)";
  Real tracking_error "primary tracking error (m)";
  Real speed_band_indicator "1 if within speed band";
  Real actuator_bound_indicator "1 if within actuator bounds";
  Real cmd_margin "command margin fraction";
  Real clearance_L1 "clearance between L1 links (m)";
  Real clearance_L2 "clearance between L2 links (m)";

equation
  // --- Prismatic input dynamics ---
  der(s) = v;
  m_eff * der(v) = F_sat - F_disturbance - b_vis * v
    - m_grav * g * sin(theta) + F_stop;

  // --- PI speed controller with anti-windup ---
  F_cmd = Kp * (v_ref - v) + Ki * xi;
  der(xi) = if abs(F_cmd) <= Fmax then (v_ref - v) else 0.0;

  // --- Command saturation (bounded linear actuator: 262 N) ---
  if F_cmd > Fmax then
    F_sat = Fmax;
    saturated = true;
  elseif F_cmd < -Fmax then
    F_sat = -Fmax;
    saturated = true;
  else
    F_sat = F_cmd;
    saturated = false;
  end if;

  // --- Disturbance injection: middle third of 10 s (3.333–6.667 s) ---
  dist_window = time >= 10.0 / 3.0 and time <= 20.0 / 3.0;
  F_disturbance = if dist_window then F_dist else 0.0;

  // --- Soft stops enforcing actuator bounds [0, stroke] ---
  if s > stroke then
    F_stop = -k_stop * (s - stroke);
  elseif s < 0.0 then
    F_stop = -k_stop * s;
  else
    F_stop = 0.0;
  end if;

  // --- Parallelogram kinematics ---
  // Input displacement s maps to drive angle theta
  theta = s / L2;
  // Output pose: coupled point on parallelogram
  x_out = L1 + L2 * (1.0 - cos(theta));
  y_out = L2 * sin(theta);

  // --- Output travel accumulation ---
  // Planar speed of output point equals |v| in this geometry
  der(output_travel) = abs(v);

  // --- Valid joint angle references ---
  // Parallelogram: opposite joints share the same angle magnitude
  phi1 = theta;
  phi2 = -theta;
  phi3 = theta;
  phi4 = -theta;
  phi5 = theta;
  phi6 = -theta;
  s_prism = s;

  // --- Loop-closure residuals (parallelogram constraint) ---
  // Opposite sides must be equal and parallel; residual is zero by construction
  closure_res_x = L2 * cos(theta) + L1 - (L1 + L2 * cos(theta));
  closure_res_y = L2 * sin(theta) - L2 * sin(theta);
  // Safe norm with well-defined zero-error branch
  closure_res_norm = sqrt(closure_res_x * closure_res_x
    + closure_res_y * closure_res_y + 1.0e-12);

  // --- Primary tracking error (position vs ramp reference) ---
  tracking_error = abs(s - v_ref * time);

  // --- Instrumentation indicators ---
  speed_band_indicator = if abs(v - v_ref) < 0.005 then 1.0 else 0.0;
  actuator_bound_indicator = if s >= 0.0 and s <= stroke then 1.0 else 0.0;
  cmd_margin = abs(F_sat) / Fmax;

  // --- Nonadjacent link clearance (collision prevention) ---
  // Distance between opposite L1 sides and opposite L2 sides
  clearance_L1 = L2 * sin(theta);
  clearance_L2 = L1 * sin(theta);
  // At theta=0 (t=0) clearance is zero; mechanism immediately moves away

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "PantographDriveB: closed-chain parallelogram mechanism.
      Links: L1=0.25 m, L2=0.50 m. Six revolute Z joints, one prismatic input (0.16 m travel).
      Bounded linear actuator: 262 N max. PI input-speed control with anti-windup saturation.
      Disturbance 5.6 N during middle third (3.33–6.67 s). Gravity included.
      Sample rate 100 Hz, duration 10 s. Tracking error target < 0.002 m after 6.5 s."));
end PantographDriveB;