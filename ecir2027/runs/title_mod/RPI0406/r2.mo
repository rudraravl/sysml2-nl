model CartesianToolPolishD
  "Instrumented contact-rich manipulation: 3-axis Cartesian tool polishing a curved workpiece"
  // Embodiment: three orthogonal prismatic axes, 2.5 kg tool carriage,
  // travel +/-0.10 m (X,Y) and +/-0.30 m (Z), force-limited to 350 N/axis.
  // Behavior: follow 0.50 m curved surface path, regulate normal force,
  // 7 N tangential disturbance during middle third, 200 Hz control, 14 s mission.

  // ===== Parameters stated in requirement =====
  parameter Real m = 2.5 "Tool carriage mass [kg]";
  parameter Real F_max = 350.0 "Per-axis force limit [N]";
  parameter Real x_min = -0.10 "X travel lower bound [m]";
  parameter Real x_max = 0.10 "X travel upper bound [m]";
  parameter Real y_min = -0.10 "Y travel lower bound [m]";
  parameter Real y_max = 0.10 "Y travel upper bound [m]";
  parameter Real z_min = -0.30 "Z travel lower bound [m]";
  parameter Real z_max = 0.30 "Z travel upper bound [m]";
  parameter Real path_length = 0.50 "Surface path length [m]";
  parameter Real mu_f = 0.50 "Friction coefficient [1]";
  parameter Real F_disturb = 7.0 "Disturbance force magnitude [N]";
  parameter Real T_sim = 14.0 "Mission duration [s]";
  parameter Real f_ctrl = 200.0 "Controller frequency [Hz]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Controller sample period [s]";

  // ===== Design-choice parameters (not specified in requirement) =====
  parameter Real F_target = 20.0 "Target normal force [N], within 12..30 N band";
  parameter Real k_n = 5000.0 "Normal contact stiffness [N/m]";
  parameter Real d_n = 80.0 "Normal contact damping [N.s/m]";
  parameter Real k_px = 1000.0 "X proportional gain [N/m]";
  parameter Real k_dx = 70.0 "X derivative gain [N.s/m]";
  parameter Real k_dy = 15.0 "Y velocity damping gain [N.s/m]";
  parameter Real k_pz = 2000.0 "Z proportional gain [N/m]";
  parameter Real k_dz = 100.0 "Z derivative gain [N.s/m]";
  parameter Real v_eps = 0.01 "Friction smoothing velocity [m/s]";
  parameter Real z_start = -0.25 "Path start Z [m]";
  parameter Real z_end = 0.25 "Path end Z [m]";
  parameter Real curve_amp = 0.02 "Surface curve X amplitude [m]";
  parameter Real curve_period = 0.50 "Surface curve spatial period [m]";

  // ===== Continuous plant states =====
  Real x "Tool X position [m] — joint encoder";
  Real y "Tool Y position [m] — joint encoder";
  Real z "Tool Z position [m] — joint encoder";
  Real vx "Tool X velocity [m/s]";
  Real vy "Tool Y velocity [m/s]";
  Real vz "Tool Z velocity [m/s]";

  // ===== Contact and surface =====
  Real x_surface "Surface X at current Z [m]";
  Real dxs_dz "Surface tangent slope dX/dZ [1]";
  Real t_x "Path tangent unit vector X [1]";
  Real t_z "Path tangent unit vector Z [1]";
  Real v_tangent "Tangential velocity along path [m/s]";
  Real penetration "Normal penetration depth [m]";
  Real F_contact_y "Normal contact force in Y [N]";
  Real F_normal "Normal force magnitude [N]";
  Real F_friction_x "Friction force X [N]";
  Real F_friction_z "Friction force Z [N]";
  Real s_traj "Normalized trajectory parameter [1]";

  // ===== Disturbance =====
  Boolean disturbance_active "True during middle third of mission";
  Real F_dist_z "Disturbance force in Z [N]";

  // ===== Sampled controller (200 Hz zero-order hold) =====
  Real z_ref "Reference Z [m]";
  Real x_ref "Reference X [m]";
  Real F_x_cmd "X force command [N]";
  Real F_y_cmd "Y force command [N]";
  Real F_z_cmd "Z force command [N]";
  Real F_x_sat "Saturated X actuator force [N]";
  Real F_y_sat "Saturated Y actuator force [N]";
  Real F_z_sat "Saturated Z actuator force [N]";

  // ===== Sensors =====
  Real F_wrist_x "Wrist wrench X [N]";
  Real F_wrist_y "Wrist wrench Y [N]";
  Real F_wrist_z "Wrist wrench Z [N]";
  Real tool_x "Tool-tip pose X [m]";
  Real tool_y "Tool-tip pose Y [m]";
  Real tool_z "Tool-tip pose Z [m]";

  // ===== Performance monitors =====
  Real path_error "Tangential path tracking error [m]";
  Real force_error "Normal force error [N]";
  Real joint_effort "Actuator effort norm [N]";
  Boolean contact_ok "Continuous contact maintained";
  Boolean force_ok "Normal force within 12..30 N";
  Boolean path_ok "Path error below 0.02 m";
  Boolean x_in_bounds "X within joint bounds";
  Boolean y_in_bounds "Y within joint bounds";
  Boolean z_in_bounds "Z within joint bounds";
  Boolean effort_ok "All efforts within 350 N";

equation
  // ---- Fixed curved workpiece profile: x_s(z) = A*sin(2*pi*z/T) ----
  x_surface = curve_amp * Modelica.Math.sin(2.0 * Modelica.Constants.pi * z / curve_period);
  dxs_dz = curve_amp * (2.0 * Modelica.Constants.pi / curve_period)
           * Modelica.Math.cos(2.0 * Modelica.Constants.pi * z / curve_period);

  // ---- Path tangent unit vector (well-defined: denominator >= 1) ----
  t_x = dxs_dz / Modelica.Math.sqrt(dxs_dz * dxs_dz + 1.0);
  t_z = 1.0 / Modelica.Math.sqrt(dxs_dz * dxs_dz + 1.0);

  // ---- Tangential velocity projection ----
  v_tangent = vx * t_x + vz * t_z;

  // ---- Compliant normal contact (surface at y=0, tool from +Y) ----
  penetration = max(0.0, -y);
  F_contact_y = if y < 0.0 then (-k_n * y - d_n * vy) else 0.0;
  F_normal = max(0.0, F_contact_y);

  // ---- Coulomb friction (smoothed tanh), opposes tangential motion ----
  F_friction_x = -mu_f * F_normal * t_x * Modelica.Math.tanh(v_tangent / v_eps);
  F_friction_z = -mu_f * F_normal * t_z * Modelica.Math.tanh(v_tangent / v_eps);

  // ---- Disturbance: 7 N opposing motion during middle third ----
  disturbance_active = (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0);
  F_dist_z = if disturbance_active then -F_disturb else 0.0;

  // ---- Continuous trajectory parameter (smoothstep clamped to [0,1]) ----
  s_traj = min(1.0, max(0.0, time / T_sim));

  // ---- Plant dynamics: three orthogonal prismatic axes ----
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (F_x_sat + F_friction_x) / m;
  der(vy) = (F_y_sat + F_contact_y) / m;
  der(vz) = (F_z_sat + F_friction_z + F_dist_z) / m;

  // ---- Sampled controller at 200 Hz (zero-order hold) ----
  when sample(0.0, dt_ctrl) then
    // Smoothstep reference: z goes from z_start to z_end over T_sim
    z_ref = z_start + (z_end - z_start) * s_traj * s_traj * (3.0 - 2.0 * s_traj);
    x_ref = curve_amp * Modelica.Math.sin(2.0 * Modelica.Constants.pi * z_ref / curve_period);
    // Tangential PD position control
    F_x_cmd = k_px * (x_ref - x) - k_dx * vx;
    F_z_cmd = k_pz * (z_ref - z) - k_dz * vz;
    // Normal force regulation: constant target push + velocity damping
    F_y_cmd = -F_target - k_dy * vy;
  end when;

  // ---- Effort saturation (force-limited linear actuators) ----
  F_x_sat = max(-F_max, min(F_max, F_x_cmd));
  F_y_sat = max(-F_max, min(F_max, F_y_cmd));
  F_z_sat = max(-F_max, min(F_max, F_z_cmd));

  // ---- Wrist wrench sensor (contact forces at tool flange) ----
  F_wrist_x = F_friction_x;
  F_wrist_y = F_contact_y;
  F_wrist_z = F_friction_z + F_dist_z;

  // ---- Tool-tip pose (Cartesian tool: pose = joint positions) ----
  tool_x = x;
  tool_y = y;
  tool_z = z;

  // ---- Performance monitors ----
  path_error = Modelica.Math.sqrt((x - x_ref) * (x - x_ref) + (z - z_ref) * (z - z_ref));
  force_error = F_normal - F_target;
  joint_effort = Modelica.Math.sqrt(F_x_sat * F_x_sat + F_y_sat * F_y_sat + F_z_sat * F_z_sat);
  contact_ok = penetration > 0.0;
  force_ok = (F_normal >= 12.0) and (F_normal <= 30.0);
  path_ok = path_error < 0.02;
  x_in_bounds = (x >= x_min) and (x <= x_max);
  y_in_bounds = (y >= y_min) and (y <= y_max);
  z_in_bounds = (z >= z_min) and (z <= z_max);
  effort_ok = (abs(F_x_sat) <= F_max) and (abs(F_y_sat) <= F_max) and (abs(F_z_sat) <= F_max);

initial equation
  x = 0.0;
  y = -F_target / k_n;
  z = z_start;
  vx = 0.0;
  vy = 0.0;
  vz = 0.0;
  z_ref = z_start;
  x_ref = 0.0;
  F_x_cmd = 0.0;
  F_y_cmd = -F_target;
  F_z_cmd = 0.0;

end CartesianToolPolishD;