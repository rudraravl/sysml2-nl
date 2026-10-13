model HydBoomTrackB
  // ============ Geometry and payload ============
  parameter Real L1 = 2.0 "Boom length [m]";
  parameter Real L2 = 1.4 "Stick length [m]";
  parameter Real m_payload = 300.0 "Payload mass [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ============ Boom cylinder parameters ============
  parameter Real A_A1 = 0.002 "Boom piston-side area [m2]";
  parameter Real A_B1 = 0.001 "Boom rod-side area [m2]";
  parameter Real r1 = 0.5 "Boom cylinder moment arm [m]";
  parameter Real J1 = 1500.0 "Boom + reflected payload inertia [kg.m2]";
  parameter Real b1 = 5000.0 "Boom viscous friction coefficient [N.s/m]";
  parameter Real cleak1 = 1.0e-12 "Boom internal leakage coefficient [m3/(s.Pa)]";
  parameter Real V_A01 = 5.0e-4 "Boom A-side dead volume [m3]";
  parameter Real V_B01 = 5.0e-4 "Boom B-side dead volume [m3]";
  parameter Real x1_max = 1.0 "Boom cylinder stroke limit [m]";

  // ============ Stick cylinder parameters ============
  parameter Real A_A2 = 0.0015 "Stick piston-side area [m2]";
  parameter Real A_B2 = 0.0008 "Stick rod-side area [m2]";
  parameter Real r2 = 0.4 "Stick cylinder moment arm [m]";
  parameter Real J2 = 700.0 "Stick + reflected payload inertia [kg.m2]";
  parameter Real b2 = 2000.0 "Stick viscous friction coefficient [N.s/m]";
  parameter Real cleak2 = 5.0e-13 "Stick internal leakage coefficient [m3/(s.Pa)]";
  parameter Real V_A02 = 3.0e-4 "Stick A-side dead volume [m3]";
  parameter Real V_B02 = 3.0e-4 "Stick B-side dead volume [m3]";
  parameter Real x2_max = 0.7 "Stick cylinder stroke limit [m]";

  // ============ Hydraulic supply parameters ============
  parameter Real beta = 1.5e9 "Effective bulk modulus [Pa]";
  parameter Real Kv_max = 0.003 "Max valve flow per unit command [m3/s]";
  parameter Real P_relief = 30.0e6 "Relief valve cracking pressure [Pa]";
  parameter Real P_tank = 1.0e5 "Tank / return pressure [Pa]";
  parameter Real dP_ls = 2.0e6 "Load-sensing pressure margin [Pa]";
  parameter Real tau_pump = 0.05 "Load-sensing pump time constant [s]";
  parameter Real K_relief = 1.0e-7 "Relief valve conductance [m3/(s.Pa)]";

  // ============ Controller gains ============
  parameter Real Kp_pos1 = 8.0 "Boom position feedback gain [1/m]";
  parameter Real Kd_pos1 = 2.0 "Boom velocity feedback gain [s/m]";
  parameter Real Kp_pres1 = 1.0e-7 "Boom pressure feedback gain [1/Pa]";
  parameter Real Kp_pos2 = 8.0 "Stick position feedback gain [1/m]";
  parameter Real Kd_pos2 = 2.0 "Stick velocity feedback gain [s/m]";
  parameter Real Kp_pres2 = 1.0e-7 "Stick pressure feedback gain [1/Pa]";

  // ============ Disturbance parameters ============
  parameter Real F_dist_mag = 154.0 "Payload disturbance magnitude [N]";
  parameter Real t_dist_start = 10.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 20.0 / 3.0 "Disturbance end time [s]";

  // ============ Derived constants ============
  Real m_eff1 = J1 / r1^2 "Boom effective mass [kg]";
  Real m_eff2 = J2 / r2^2 "Stick effective mass [kg]";

  // ============ Boom dynamic states ============
  Real x1(start = 0.1, fixed = true) "Boom cylinder position [m]";
  Real x1_dot(start = 0.0, fixed = true) "Boom cylinder velocity [m/s]";
  Real P_A1(start = 5.825e6, fixed = true) "Boom A-chamber pressure [Pa]";
  Real P_B1(start = 1.0e5, fixed = true) "Boom B-chamber pressure [Pa]";

  // ============ Stick dynamic states ============
  Real x2(start = 0.05, fixed = true) "Stick cylinder position [m]";
  Real x2_dot(start = 0.0, fixed = true) "Stick cylinder velocity [m/s]";
  Real P_A2(start = 6.555e6, fixed = true) "Stick A-chamber pressure [Pa]";
  Real P_B2(start = 1.0e5, fixed = true) "Stick B-chamber pressure [Pa]";

  // ============ Pump/supply state ============
  Real P_s(start = 8.555e6, fixed = true) "Supply pressure [Pa]";

  // ============ Command signals ============
  Real u1 "Boom valve command (unsaturated) [-]";
  Real u2 "Stick valve command (unsaturated) [-]";
  Real u1_sat "Saturated boom valve command [-]";
  Real u2_sat "Saturated stick valve command [-]";
  Real u_ff1 "Boom feedforward command [-]";
  Real u_ff2 "Stick feedforward command [-]";

  // ============ Flow signals ============
  Real Q_A1 "Boom A-side valve flow [m3/s]";
  Real Q_B1 "Boom B-side valve flow [m3/s]";
  Real Q_A2 "Stick A-side valve flow [m3/s]";
  Real Q_B2 "Stick B-side valve flow [m3/s]";
  Real Q_leak1 "Boom leakage flow [m3/s]";
  Real Q_leak2 "Stick leakage flow [m3/s]";
  Real Q_s "Total supply (pump) flow [m3/s]";
  Real Q_relief "Relief valve flow [m3/s]";

  // ============ Force / torque signals ============
  Real F_cyl1 "Boom net cylinder force [N]";
  Real F_cyl2 "Stick net cylinder force [N]";
  Real F_grav1 "Boom gravity load force [N]";
  Real F_grav2 "Stick gravity load force [N]";
  Real F_dist1 "Disturbance force on boom [N]";
  Real x1_ddot "Boom acceleration [m/s2]";
  Real x2_ddot "Stick acceleration [m/s2]";

  // ============ Volume signals ============
  Real V_A1 "Boom A-chamber volume [m3]";
  Real V_B1 "Boom B-chamber volume [m3]";
  Real V_A2 "Stick A-chamber volume [m3]";
  Real V_B2 "Stick B-chamber volume [m3]";

  // ============ Trajectory references ============
  Real x1_ref "Boom reference position [m]";
  Real x1_ref_dot "Boom reference velocity [m/s]";
  Real x1_ref_ddot "Boom reference acceleration [m/s2]";
  Real x2_ref "Stick reference position [m]";
  Real x2_ref_dot "Stick reference velocity [m/s]";
  Real x2_ref_ddot "Stick reference acceleration [m/s2]";

  // ============ Tracking errors ============
  Real e_pos1 "Boom position tracking error [m]";
  Real e_pos2 "Stick position tracking error [m]";
  Real e_pos1_abs "Abs boom tracking error [m]";

  // ============ Joint kinematics ============
  Real theta1 "Boom joint angle [rad]";
  Real theta2 "Stick joint angle [rad]";

  // ============ Load sensing ============
  Real P_load "Highest load pressure [Pa]";

  // ============ Reference pressure differentials ============
  Real dP_ref1 "Boom reference pressure difference [Pa]";
  Real dP_ref2 "Stick reference pressure difference [Pa]";

equation
  // ---- Joint kinematics ----
  theta1 = x1 / r1;
  theta2 = x2 / r2;

  // ---- Gravity load forces ----
  F_grav1 = m_payload * g * L1 * cos(theta1) / r1;
  F_grav2 = m_payload * g * L2 * cos(theta1 + theta2) / r2;

  // ---- Disturbance: 154 N step during middle third of 10 s ----
  if time >= t_dist_start and time <= t_dist_end then
    F_dist1 = F_dist_mag;
  else
    F_dist1 = 0.0;
  end if;

  // ---- Cylinder forces ----
  F_cyl1 = P_A1 * A_A1 - P_B1 * A_B1;
  F_cyl2 = P_A2 * A_A2 - P_B2 * A_B2;

  // ---- Equations of motion ----
  m_eff1 * x1_ddot = F_cyl1 - b1 * x1_dot - F_grav1 - F_dist1;
  m_eff2 * x2_ddot = F_cyl2 - b2 * x2_dot - F_grav2;

  // ---- State derivatives ----
  der(x1) = x1_dot;
  der(x1_dot) = x1_ddot;
  der(x2) = x2_dot;
  der(x2_dot) = x2_ddot;

  // ---- Chamber volumes ----
  V_A1 = V_A01 + A_A1 * x1;
  V_B1 = max(V_B01 - A_B1 * x1, 1.0e-6);
  V_A2 = V_A02 + A_A2 * x2;
  V_B2 = max(V_B02 - A_B2 * x2, 1.0e-6);

  // ---- Leakage flows ----
  Q_leak1 = cleak1 * (P_A1 - P_B1);
  Q_leak2 = cleak2 * (P_A2 - P_B2);

  // ---- Valve flows (linear, from supply / to tank) ----
  Q_A1 = Kv_max * u1_sat;
  Q_B1 = Kv_max * u1_sat;
  Q_A2 = Kv_max * u2_sat;
  Q_B2 = Kv_max * u2_sat;

  // ---- Chamber pressure dynamics ----
  der(P_A1) = (beta / max(V_A1, 1.0e-6)) * (Q_A1 - A_A1 * x1_dot - Q_leak1);
  der(P_B1) = (beta / max(V_B1, 1.0e-6)) * (-Q_B1 + A_B1 * x1_dot + Q_leak1);
  der(P_A2) = (beta / max(V_A2, 1.0e-6)) * (Q_A2 - A_A2 * x2_dot - Q_leak2);
  der(P_B2) = (beta / max(V_B2, 1.0e-6)) * (-Q_B2 + A_B2 * x2_dot + Q_leak2);

  // ---- Load-sensing: highest load pressure ----
  P_load = max(P_A1, max(P_A2, P_tank));

  // ---- Pump supply dynamics: first-order tracking of load + margin ----
  der(P_s) = ((P_load + dP_ls) - P_s) / tau_pump;

  // ---- Relief valve flow ----
  if P_s > P_relief then
    Q_relief = K_relief * (P_s - P_relief);
  else
    Q_relief = 0.0;
  end if;

  // ---- Total supply (pump) flow ----
  Q_s = abs(Q_A1) + abs(Q_A2) + Q_relief;

  // ---- Trajectory: two-segment smooth profile ----
  // Segment 1: t in [0, 5] -> boom extends 0.1 -> 0.8 m (cosine blend)
  // Segment 2: t in [5, 10] -> stick extends 0.05 -> 0.5 m (cosine blend)
  if time <= 5.0 then
    x1_ref = 0.1 + 0.7 * (1.0 - cos(Modelica.Constants.pi * time / 5.0)) / 2.0;
    x1_ref_dot = 0.7 * Modelica.Constants.pi / 5.0 * sin(Modelica.Constants.pi * time / 5.0) / 2.0;
    x1_ref_ddot = 0.7 * (Modelica.Constants.pi / 5.0)^2 * cos(Modelica.Constants.pi * time / 5.0) / 2.0;
    x2_ref = 0.05;
    x2_ref_dot = 0.0;
    x2_ref_ddot = 0.0;
  else
    x1_ref = 0.8;
    x1_ref_dot = 0.0;
    x1_ref_ddot = 0.0;
    x2_ref = 0.05 + 0.45 * (1.0 - cos(Modelica.Constants.pi * (time - 5.0) / 5.0)) / 2.0;
    x2_ref_dot = 0.45 * Modelica.Constants.pi / 5.0 * sin(Modelica.Constants.pi * (time - 5.0) / 5.0) / 2.0;
    x2_ref_ddot = 0.45 * (Modelica.Constants.pi / 5.0)^2 * cos(Modelica.Constants.pi * (time - 5.0) / 5.0) / 2.0;
  end if;

  // ---- Reference pressure differentials (from gravity estimates) ----
  dP_ref1 = (m_payload * g * L1 * cos(theta1) / r1) / A_A1;
  dP_ref2 = (m_payload * g * L2 * cos(theta1 + theta2) / r2) / A_A2;

  // ---- Feedforward flow commands ----
  u_ff1 = (A_A1 * x1_ref_dot) / Kv_max;
  u_ff2 = (A_A2 * x2_ref_dot) / Kv_max;

  // ---- Control law: feedforward + position + velocity + pressure feedback ----
  u1 = u_ff1
       + Kp_pos1 * (x1_ref - x1)
       + Kd_pos1 * (x1_ref_dot - x1_dot)
       + Kp_pres1 * (dP_ref1 - (P_A1 - P_B1));
  u2 = u_ff2
       + Kp_pos2 * (x2_ref - x2)
       + Kd_pos2 * (x2_ref_dot - x2_dot)
       + Kp_pres2 * (dP_ref2 - (P_A2 - P_B2));

  // ---- Command saturation to +/- 1 (max flow 0.003 m3/s) ----
  u1_sat = if u1 > 1.0 then 1.0 else if u1 < -1.0 then -1.0 else u1;
  u2_sat = if u2 > 1.0 then 1.0 else if u2 < -1.0 then -1.0 else u2;

  // ---- Tracking errors ----
  e_pos1 = x1_ref - x1;
  e_pos2 = x2_ref - x2;
  e_pos1_abs = if e_pos1 >= 0.0 then e_pos1 else -e_pos1;

  // ---- Bounds assertions ----
  assert(x1 >= -0.01 and x1 <= x1_max + 0.01, "Boom travel bound violated");
  assert(x2 >= -0.01 and x2 <= x2_max + 0.01, "Stick travel bound violated");
  assert(P_A1 >= 0.0 and P_A1 <= P_relief + 1.0e6, "Boom A pressure bound violated");
  assert(P_B1 >= 0.0 and P_B1 <= P_relief + 1.0e6, "Boom B pressure bound violated");
  assert(P_A2 >= 0.0 and P_A2 <= P_relief + 1.0e6, "Stick A pressure bound violated");
  assert(P_B2 >= 0.0 and P_B2 <= P_relief + 1.0e6, "Stick B pressure bound violated");
  assert(P_s >= 0.0 and P_s <= P_relief + 2.0e6, "Supply pressure bound violated");
  assert(Q_s >= 0.0 and Q_s <= Kv_max * 3.0 + 1.0e-4, "Supply flow bound violated");
  assert(abs(x1_ddot) <= 20.0, "Boom acceleration bound violated");
  assert(abs(x2_ddot) <= 20.0, "Stick acceleration bound violated");
  assert(e_pos1_abs <= 0.5, "Boom trajectory error bound violated");
  assert(abs(e_pos2) <= 0.5, "Stick trajectory error bound violated");
  // Primary tracking error requirement: < 0.022 m after 6.5 s
  assert(time < 6.5 or e_pos1_abs <= 0.022, "Primary tracking error > 0.022 m after 6.5 s");

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "HydBoomTrackB: Two-segment trajectory tracking for a hydraulic boom-stick
      robotic actuator with 300 kg payload. Load-sensing pump with relief valve (30 MPa).
      Feedforward flow control with pressure-position feedback. 154 N payload step disturbance
      injected during the middle third (3.33-6.67 s). Runs at 100 Hz for 10 s.
      Records position, velocity, chamber pressures, supply flow, and valve commands."),
    Diagram(coordinateSystem(preserveAspectRatio = false, extent = {{-100, -100}, {100, 100}}))
  );
end HydBoomTrackB;