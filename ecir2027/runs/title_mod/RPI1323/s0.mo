model TendonSoftShapeC
  import Modelica.Constants.pi;

  // ==================== Physical Parameters ====================
  parameter Real L_body = 0.55 "Body length [m]";
  parameter Real Ls = L_body / 6.0 "Section length [m]";
  parameter Real r_tendon = 0.05 "Tendon routing radius [m] (design assumption)";
  parameter Real EI_body = 0.5 "Bending stiffness [N.m^2] (design assumption)";
  parameter Real rho_l = 0.15 "Linear mass density [kg/m] (design assumption)";
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real tau_act = 0.06 "Actuator time constant [s] (design assumption)";
  parameter Real kC = r_tendon / EI_body "Curvature gain [1/(N.m)]";

  // ==================== Command & Disturbance ====================
  parameter Real T_max = 38.6 "Maximum tendon command magnitude [N]";
  parameter Real F_dist = 5.4 "Tip disturbance load [N]";
  parameter Real Ts = 1.0 / 125.0 "Sample period [s]";

  // ==================== Controller ====================
  parameter Real T_pre = 20.0 "Pretension [N] (design assumption)";
  parameter Real k_target = 1.5 "Target curvature [1/m] (design assumption)";
  parameter Real Kp_tip = 10.0 "Tip feedback gain (design assumption)";

  // ==================== Thermal ====================
  parameter Real C_thermal = 80.0 "Thermal capacity [J/K] (design assumption)";
  parameter Real R_thermal = 3.0 "Thermal resistance [K/W] (design assumption)";
  parameter Real alpha_heat = 0.005 "Joule heating coefficient [W/N^2] (design assumption)";
  parameter Real T_ambient = 25.0 "Ambient temperature [degC]";

  // ==================== Tendon Geometry (120 deg spacing) ====================
  parameter Real phi1 = 0.0 "Tendon 1 angle [rad]";
  parameter Real phi2 = 2.0 * pi / 3.0 "Tendon 2 angle [rad]";
  parameter Real phi3 = 4.0 * pi / 3.0 "Tendon 3 angle [rad]";
  parameter Real w1 = 1.0 "Tendon 1 moment arm x-projection (cos(0))";
  parameter Real w2 = -0.5 "Tendon 2 moment arm x-projection (cos(120 deg))";
  parameter Real w3 = -0.5 "Tendon 3 moment arm x-projection (cos(240 deg))";

  // ==================== Dynamic States ====================
  Real k1(start = 0.0) "Section 1 curvature [1/m]";
  Real k2(start = 0.0) "Section 2 curvature [1/m]";
  Real k3(start = 0.0) "Section 3 curvature [1/m]";
  Real k4(start = 0.0) "Section 4 curvature [1/m]";
  Real k5(start = 0.0) "Section 5 curvature [1/m]";
  Real k6(start = 0.0) "Section 6 curvature [1/m]";
  Real T_sensor(start = 25.0) "Temperature sensor [degC]";

  // ==================== Tendon Commands ====================
  Real T_cmd1 "Tendon 1 command [N]";
  Real T_cmd2 "Tendon 2 command [N]";
  Real T_cmd3 "Tendon 3 command [N]";
  Real T_sat1 "Tendon 1 saturated command [N]";
  Real T_sat2 "Tendon 2 saturated command [N]";
  Real T_sat3 "Tendon 3 saturated command [N]";

  // ==================== Controller Variables ====================
  Real k_des "Desired curvature from controller [1/m]";
  Real k_fb "Feedback curvature correction [1/m]";
  Real k_grav "Gravity-induced curvature [1/m]";
  Real k_dist "Disturbance-induced curvature [1/m]";
  Real dist_force "Disturbance force [N]";
  Real T_net "Net tendon moment term [N]";

  // ==================== Forward Kinematics ====================
  Real x1 "Section 1 tip x [m]";
  Real z1 "Section 1 tip z [m]";
  Real psi1 "Section 1 exit tangent angle [rad]";
  Real x2 "Section 2 tip x [m]";
  Real z2 "Section 2 tip z [m]";
  Real psi2 "Section 2 exit tangent angle [rad]";
  Real x3 "Section 3 tip x [m]";
  Real z3 "Section 3 tip z [m]";
  Real psi3 "Section 3 exit tangent angle [rad]";
  Real x4 "Section 4 tip x [m]";
  Real z4 "Section 4 tip z [m]";
  Real psi4 "Section 4 exit tangent angle [rad]";
  Real x5 "Section 5 tip x [m]";
  Real z5 "Section 5 tip z [m]";
  Real psi5 "Section 5 exit tangent angle [rad]";
  Real x6 "Section 6 tip x [m]";
  Real z6 "Section 6 tip z [m]";
  Real tip_x "Tip x position [m]";
  Real tip_z "Tip z position [m]";
  Real tip_undeformed_x "Undeformed tip x [m]";
  Real tip_undeformed_z "Undeformed tip z [m]";
  Real tip_target_x "Target tip x [m]";
  Real tip_target_z "Target tip z [m]";
  Real track_error "Primary tracking error [m]";
  Real shape_error "Shape curvature error norm [1/m]";

  // ==================== Finite State Machine ====================
  Integer fsm(start = 0) "FSM: 0=init, 1=track, 2=disturbance, 3=hold";

  // ==================== Sensor Traces ====================
  Real F_sensor1 "Tendon 1 force sensor [N]";
  Real F_sensor2 "Tendon 2 force sensor [N]";
  Real F_sensor3 "Tendon 3 force sensor [N]";
  Real k_sensor1 "Section 1 curvature sensor [1/m]";
  Real k_sensor2 "Section 2 curvature sensor [1/m]";
  Real k_sensor3 "Section 3 curvature sensor [1/m]";
  Real k_sensor4 "Section 4 curvature sensor [1/m]";
  Real k_sensor5 "Section 5 curvature sensor [1/m]";
  Real k_sensor6 "Section 6 curvature sensor [1/m]";
  Real temp_sensor "Temperature sensor [degC]";

  // ==================== Bound Variables ====================
  Real actuator_margin "Actuator bound margin [N]";
  Real curvature_norm "Curvature norm [1/m]";
  Real max_tension "Maximum tension across tendons [N]";

  // ==================== Sampled Traces ====================
  Real sampled_track_error(start = 0.0) "125 Hz sampled tracking error [m]";
  Real sampled_tip_x(start = 0.0) "125 Hz sampled tip x [m]";
  Real sampled_tip_z(start = 0.0) "125 Hz sampled tip z [m]";
  Real sampled_T1(start = 0.0) "125 Hz sampled tendon 1 [N]";
  Real sampled_T2(start = 0.0) "125 Hz sampled tendon 2 [N]";
  Real sampled_T3(start = 0.0) "125 Hz sampled tendon 3 [N]";
  Real error_at_78(start = 0.0) "Tracking error captured at 7.8 s [m]";

  // ==================== Constants ====================
  constant Real eps = 1e-9;

equation
  // ==================== Finite State Machine ====================
  fsm = if time < 0.1 then 0 else if time < 4.0 then 1 else if time < 8.0 then 2 else 3;

  // ==================== Disturbance (middle third: 4-8 s) ====================
  dist_force = if time >= 4.0 and time < 8.0 then F_dist else 0.0;
  k_dist = -(dist_force * L_body) / (2.0 * EI_body);

  // ==================== Gravity-Induced Curvature ====================
  k_grav = -(rho_l * g * L_body * L_body) / (8.0 * EI_body);

  // ==================== Target Tip Position (undeformed frame) ====================
  tip_target_x = if abs(k_target) < eps then 0.0 else (1.0 - cos(k_target * L_body)) / k_target;
  tip_target_z = if abs(k_target) < eps then L_body else sin(k_target * L_body) / k_target;
  tip_undeformed_x = 0.0;
  tip_undeformed_z = L_body;

  // ==================== Primary Tracking Error ====================
  track_error = sqrt((tip_x - tip_target_x) * (tip_x - tip_target_x) + (tip_z - tip_target_z) * (tip_z - tip_target_z) + eps);

  // ==================== Controller ====================
  // Feedback correction from tip position error
  k_fb = Kp_tip * (tip_target_x - tip_x);

  // Feedforward + feedback desired curvature
  k_des = k_target + k_fb - k_grav - k_dist;

  // Inverse tendon mapping: symmetric (T2=T3), pretension constraint
  // T1 + 2*T2 = T_pre, T1 - T2 = k_des / kC
  T_cmd1 = (T_pre + 2.0 * k_des / kC) / 3.0;
  T_cmd2 = (T_pre - k_des / kC) / 3.0;
  T_cmd3 = (T_pre - k_des / kC) / 3.0;

  // ==================== Tendon Saturation [0, T_max] ====================
  T_sat1 = if T_cmd1 > T_max then T_max elseif T_cmd1 < 0.0 then 0.0 else T_cmd1;
  T_sat2 = if T_cmd2 > T_max then T_max elseif T_cmd2 < 0.0 then 0.0 else T_cmd2;
  T_sat3 = if T_cmd3 > T_max then T_max elseif T_cmd3 < 0.0 then 0.0 else T_cmd3;

  // ==================== Net Tendon Moment ====================
  T_net = w1 * T_sat1 + w2 * T_sat2 + w3 * T_sat3;

  // ==================== Plant: Section Curvature Dynamics ====================
  // First-order actuator dynamics: der(k) = (k_cmd - k) / tau
  // k_cmd = kC * T_net + k_grav + k_dist
  der(k1) = (kC * T_net + k_grav + k_dist - k1) / tau_act;
  der(k2) = (kC * T_net + k_grav + k_dist - k2) / tau_act;
  der(k3) = (kC * T_net + k_grav + k_dist - k3) / tau_act;
  der(k4) = (kC * T_net + k_grav + k_dist - k4) / tau_act;
  der(k5) = (kC * T_net + k_grav + k_dist - k5) / tau_act;
  der(k6) = (kC * T_net + k_grav + k_dist - k6) / tau_act;

  // ==================== Forward Kinematics (Constant Curvature) ====================
  // Section 1: base at origin, tangent along +z
  x1 = if abs(k1) < eps then 0.0 else (1.0 - cos(k1 * Ls)) / k1;
  z1 = if abs(k1) < eps then Ls else sin(k1 * Ls) / k1;
  psi1 = k1 * Ls;

  // Section 2
  x2 = x1 + (if abs(k2) < eps then Ls * sin(psi1) else (cos(psi1) - cos(psi1 + k2 * Ls)) / k2);
  z2 = z1 + (if abs(k2) < eps then Ls * cos(psi1) else (sin(psi1 + k2 * Ls) - sin(psi1)) / k2);
  psi2 = psi1 + k2 * Ls;

  // Section 3
  x3 = x2 + (if abs(k3) < eps then Ls * sin(psi2) else (cos(psi2) - cos(psi2 + k3 * Ls)) / k3);
  z3 = z2 + (if abs(k3) < eps then Ls * cos(psi2) else (sin(psi2 + k3 * Ls) - sin(psi2)) / k3);
  psi3 = psi2 + k3 * Ls;

  // Section 4
  x4 = x3 + (if abs(k4) < eps then Ls * sin(psi3) else (cos(psi3) - cos(psi3 + k4 * Ls)) / k4);
  z4 = z3 + (if abs(k4) < eps then Ls * cos(psi3) else (sin(psi3 + k4 * Ls) - sin(psi3)) / k4);
  psi4 = psi3 + k4 * Ls;

  // Section 5
  x5 = x4 + (if abs(k5) < eps then Ls * sin(psi4) else (cos(psi4) - cos(psi4 + k5 * Ls)) / k5);
  z5 = z4 + (if abs(k5) < eps then Ls * cos(psi4) else (sin(psi4 + k5 * Ls) - sin(psi4)) / k5);
  psi5 = psi4 + k5 * Ls;

  // Section 6
  x6 = x5 + (if abs(k6) < eps then Ls * sin(psi5) else (cos(psi5) - cos(psi5 + k6 * Ls)) / k6);
  z6 = z5 + (if abs(k6) < eps then Ls * cos(psi5) else (sin(psi5 + k6 * Ls) - sin(psi5)) / k6);

  // Tip position
  tip_x = x6;
  tip_z = z6;

  // ==================== Shape Error ====================
  shape_error = sqrt(
    (k1 - k_target) * (k1 - k_target) +
    (k2 - k_target) * (k2 - k_target) +
    (k3 - k_target) * (k3 - k_target) +
    (k4 - k_target) * (k4 - k_target) +
    (k5 - k_target) * (k5 - k_target) +
    (k6 - k_target) * (k6 - k_target) +
    eps
  );

  // ==================== Thermal Model ====================
  der(T_sensor) = (alpha_heat * (T_sat1 * T_sat1 + T_sat2 * T_sat2 + T_sat3 * T_sat3)
    - (T_sensor - T_ambient) / R_thermal) / C_thermal;

  // ==================== Sensor Outputs ====================
  F_sensor1 = T_sat1;
  F_sensor2 = T_sat2;
  F_sensor3 = T_sat3;
  k_sensor1 = k1;
  k_sensor2 = k2;
  k_sensor3 = k3;
  k_sensor4 = k4;
  k_sensor5 = k5;
  k_sensor6 = k6;
  temp_sensor = T_sensor;

  // ==================== Bound Checks ====================
  max_tension = if T_sat1 >= T_sat2 then (if T_sat1 >= T_sat3 then T_sat1 else T_sat3)
    else (if T_sat2 >= T_sat3 then T_sat2 else T_sat3);
  actuator_margin = T_max - max_tension;
  curvature_norm = sqrt(k1 * k1 + k2 * k2 + k3 * k3 + k4 * k4 + k5 * k5 + k6 * k6 + eps);

  // ==================== 125 Hz Sampled Traces ====================
  when sample(0, Ts) then
    sampled_track_error = track_error;
    sampled_tip_x = tip_x;
    sampled_tip_z = tip_z;
    sampled_T1 = T_sat1;
    sampled_T2 = T_sat2;
    sampled_T3 = T_sat3;
  end when;

  // Capture tracking error at 7.8 s for bound verification
  when time >= 7.8 then
    error_at_78 = track_error;
  end when;

  // ==================== Assertions ====================
  assert(T_sat1 >= 0.0 and T_sat1 <= T_max + eps, "Tendon 1 force out of bounds");
  assert(T_sat2 >= 0.0 and T_sat2 <= T_max + eps, "Tendon 2 force out of bounds");
  assert(T_sat3 >= 0.0 and T_sat3 <= T_max + eps, "Tendon 3 force out of bounds");
  assert(track_error >= 0.0, "Tracking error must be non-negative");
  assert(T_sensor > -1000.0 and T_sensor < 1000.0, "Temperature out of physical range");
  assert(time < 7.81 or error_at_78 < 0.047, "Primary tracking error at 7.8 s exceeds 0.047 m bound");

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "TendonSoftShapeC: 6-section constant-curvature soft robotic body (0.55 m) with 3 tendons at 120 deg spacing. Reduced-order deformation model with shape feedback. 5.4 N tip disturbance during middle third (4-8 s). 125 Hz, 12 s. Design assumptions noted in parameter comments.")
  );
end TendonSoftShapeC;