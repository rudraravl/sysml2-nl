model HydBoomTrackC
  "Fluid-power robotic actuator with feedforward flow control and pressure-position feedback"

  // ===== Geometry and mass parameters =====
  parameter Real L_boom = 2.0 "Boom length [m]";
  parameter Real L_stick = 1.4 "Stick length [m]";
  parameter Real m_payload = 300.0 "Payload mass [kg]";
  parameter Real m_boom = 150.0 "Boom structural mass [kg]";
  parameter Real m_stick = 80.0 "Stick structural mass [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Boom cylinder parameters =====
  parameter Real A_A_boom = 0.005 "Boom cylinder cap-end area [m2]";
  parameter Real A_B_boom = 0.003 "Boom cylinder rod-end area [m2]";
  parameter Real V_A0_boom = 0.0005 "Boom cylinder cap-side dead volume [m3]";
  parameter Real V_B0_boom = 0.0005 "Boom cylinder rod-side dead volume [m3]";
  parameter Real r_boom = 0.5 "Boom cylinder moment arm [m/rad]";
  parameter Real xp0_boom = 0.5 "Boom cylinder initial piston position [m]";
  parameter Real b_boom = 10000.0 "Boom joint viscous friction [N.m.s/rad]";
  parameter Real leak_boom = 1.0e-12 "Boom cylinder internal leakage coeff [m3/(s.Pa)]";

  // ===== Stick cylinder parameters =====
  parameter Real A_A_stick = 0.003 "Stick cylinder cap-end area [m2]";
  parameter Real A_B_stick = 0.002 "Stick cylinder rod-end area [m2]";
  parameter Real V_A0_stick = 0.0003 "Stick cylinder cap-side dead volume [m3]";
  parameter Real V_B0_stick = 0.0003 "Stick cylinder rod-side dead volume [m3]";
  parameter Real r_stick = 0.4 "Stick cylinder moment arm [m/rad]";
  parameter Real xp0_stick = 0.4 "Stick cylinder initial piston position [m]";
  parameter Real b_stick = 5000.0 "Stick joint viscous friction [N.m.s/rad]";
  parameter Real leak_stick = 1.0e-12 "Stick cylinder internal leakage coeff [m3/(s.Pa)]";

  // ===== Hydraulic fluid =====
  parameter Real beta = 1.6e9 "Effective bulk modulus [Pa]";

  // ===== Inertias =====
  parameter Real J_boom = m_boom * L_boom * L_boom / 3.0 + (m_stick + m_payload) * L_boom * L_boom
    "Boom rotational inertia about base pivot [kg.m2]";
  parameter Real J_stick = m_stick * L_stick * L_stick / 3.0 + m_payload * L_stick * L_stick
    "Stick rotational inertia about stick pivot [kg.m2]";

  // ===== Pump and relief =====
  parameter Real p_relief = 30.0e6 "Relief valve cracking pressure [Pa]";
  parameter Real p_margin = 1.0e6 "Load-sensing pressure margin [Pa]";
  parameter Real tau_pump = 0.05 "Pump pressure regulator time constant [s]";
  parameter Real Kv_relief = 1.0e-6 "Relief valve linear conductance [m3/(s.Pa)]";

  // ===== Valve dynamics =====
  parameter Real tau_valve = 0.01 "Valve first-order time constant [s]";

  // ===== Controller gains =====
  parameter Real Kff_boom = 1.0 "Boom feedforward gain [dimensionless]";
  parameter Real Kff_stick = 1.0 "Stick feedforward gain [dimensionless]";
  parameter Real Kp_pos_boom = 0.1 "Boom position feedback gain [m2/s]";
  parameter Real Kp_pos_stick = 0.1 "Stick position feedback gain [m2/s]";
  parameter Real Kp_pres_boom = 5.0e-11 "Boom pressure feedback gain [m3/(s.Pa)]";
  parameter Real Kp_pres_stick = 5.0e-11 "Stick pressure feedback gain [m3/(s.Pa)]";
  parameter Real p_nom_boom = 2.9e6 "Nominal boom load pressure for pressure feedback [Pa]";
  parameter Real p_nom_stick = 2.4e6 "Nominal stick load pressure for pressure feedback [Pa]";
  parameter Real cmd_max = 0.003 "Maximum flow command magnitude [m3/s]";

  // ===== Trajectory parameters =====
  parameter Real theta1_start = 0.3 "Boom initial angle [rad]";
  parameter Real theta1_mid = 0.8 "Boom mid-segment angle [rad]";
  parameter Real theta1_end = 0.5 "Boom final angle [rad]";
  parameter Real theta2_start = 0.5 "Stick initial angle [rad]";
  parameter Real theta2_mid = 0.9 "Stick mid-segment angle [rad]";
  parameter Real theta2_end = 0.6 "Stick final angle [rad]";
  parameter Real t_seg1_end = 6.0 "End of first trajectory segment [s]";
  parameter Real t_seg2_end = 12.0 "End of second trajectory segment [s]";

  // ===== Payload disturbance =====
  parameter Real F_disturbance = 198.0 "Payload step disturbance force [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 8.0 "Disturbance end time [s]";

  // ===== Dynamic states: Boom mechanical =====
  Real theta1(start = theta1_start) "Boom joint angle [rad]";
  Real omega1(start = 0.0) "Boom joint angular velocity [rad/s]";

  // ===== Dynamic states: Boom hydraulic =====
  Real pA_boom(start = 4.0e6) "Boom cylinder cap-side pressure [Pa]";
  Real pB_boom(start = 1.0e6) "Boom cylinder rod-side pressure [Pa]";
  Real Qv_boom(start = 0.0) "Boom valve flow [m3/s]";

  // ===== Dynamic states: Stick mechanical =====
  Real theta2(start = theta2_start) "Stick joint angle [rad]";
  Real omega2(start = 0.0) "Stick joint angular velocity [rad/s]";

  // ===== Dynamic states: Stick hydraulic =====
  Real pA_stick(start = 3.4e6) "Stick cylinder cap-side pressure [Pa]";
  Real pB_stick(start = 1.0e6) "Stick cylinder rod-side pressure [Pa]";
  Real Qv_stick(start = 0.0) "Stick valve flow [m3/s]";

  // ===== Dynamic states: Pump =====
  Real p_supply(start = 5.0e6) "Pump supply pressure [Pa]";

  // ===== Algebraic: accelerations =====
  Real alpha1 "Boom joint angular acceleration [rad/s2]";
  Real alpha2 "Stick joint angular acceleration [rad/s2]";

  // ===== Algebraic: commands =====
  Real cmd_boom "Boom limited flow command [m3/s]";
  Real cmd_stick "Stick limited flow command [m3/s]";
  Real cmd_boom_raw "Boom raw (unlimited) flow command [m3/s]";
  Real cmd_stick_raw "Stick raw (unlimited) flow command [m3/s]";

  // ===== Algebraic: pump and flow =====
  Real Q_pump "Pump output flow [m3/s]";
  Real Q_relief "Relief valve flow [m3/s]";
  Real Q_demand "Total flow demanded by valves [m3/s]";
  Real Q_supply "Supply flow sensor reading [m3/s]";

  // ===== Algebraic: cylinder kinematics =====
  Real xp_boom "Boom cylinder piston position [m]";
  Real xp_stick "Stick cylinder piston position [m]";
  Real vp_boom "Boom cylinder piston velocity [m/s]";
  Real vp_stick "Stick cylinder piston velocity [m/s]";
  Real xp_boom_des "Boom desired cylinder position [m]";
  Real xp_stick_des "Stick desired cylinder position [m]";
  Real vp_boom_des "Boom desired cylinder velocity [m/s]";
  Real vp_stick_des "Stick desired cylinder velocity [m/s]";

  // ===== Algebraic: cylinder force and volume =====
  Real F_boom "Boom cylinder net force [N]";
  Real F_stick "Stick cylinder net force [N]";
  Real VA_boom "Boom cap-side volume [m3]";
  Real VB_boom "Boom rod-side volume [m3]";
  Real VA_stick "Stick cap-side volume [m3]";
  Real VB_stick "Stick rod-side volume [m3]";

  // ===== Algebraic: load sensing =====
  Real p_load_boom "Boom load-sensing pressure [Pa]";
  Real p_load_stick "Stick load-sensing pressure [Pa]";
  Real p_load_max "Maximum load pressure for pump sensing [Pa]";

  // ===== Algebraic: trajectory =====
  Real theta1_des "Desired boom angle [rad]";
  Real omega1_des "Desired boom angular velocity [rad/s]";
  Real theta2_des "Desired stick angle [rad]";
  Real omega2_des "Desired stick angular velocity [rad/s]";
  Real ss1 "Smoothstep for segment 1";
  Real ss2 "Smoothstep for segment 2";
  Real s1_arg "Clamped normalized time for segment 1";
  Real s2_arg "Clamped normalized time for segment 2";

  // ===== Algebraic: tracking error =====
  Real err_boom "Boom cylinder position tracking error [m]";
  Real err_stick "Stick cylinder position tracking error [m]";
  Real err_primary "Primary tracking error [m]";

  // ===== Algebraic: end effector =====
  Real x_ee "End-effector x position [m]";
  Real y_ee "End-effector y position [m]";

  // ===== Algebraic: disturbance and gravity =====
  Real F_dist "Active disturbance force [N]";
  Real tau_dist "Disturbance torque on boom [N.m]";
  Real tau_grav_boom "Gravity torque on boom [N.m]";
  Real tau_grav_stick "Gravity torque on stick [N.m]";

  // ===== Algebraic: torques =====
  Real tau_cyl_boom "Cylinder torque on boom [N.m]";
  Real tau_cyl_stick "Cylinder torque on stick [N.m]";

  // ===== Bounds checking =====
  Boolean travel_ok "Travel within joint limits";
  Boolean pressure_ok "All pressures within safe limits";
  Boolean flow_ok "Pump flow within limit";
  Boolean accel_ok "Accelerations within limit";
  Boolean error_ok "Primary tracking error within bound after 7.8 s";
  Boolean relief_ok "Relief valve not over-venting";

equation
  // ===== Smooth two-segment trajectory generation =====
  s1_arg = min(max(time / t_seg1_end, 0.0), 1.0);
  s2_arg = min(max((time - t_seg1_end) / (t_seg2_end - t_seg1_end), 0.0), 1.0);
  ss1 = 0.5 * (1.0 - Modelica.Math.cos(Modelica.Constants.pi * s1_arg));
  ss2 = 0.5 * (1.0 - Modelica.Math.cos(Modelica.Constants.pi * s2_arg));
  theta1_des = theta1_start + (theta1_mid - theta1_start) * ss1 + (theta1_end - theta1_mid) * ss2;
  theta2_des = theta2_start + (theta2_mid - theta2_start) * ss1 + (theta2_end - theta2_mid) * ss2;

  // Analytical derivatives of smoothstep: d/dt[0.5*(1-cos(pi*s))] = (pi/(2*T))*sin(pi*s)
  omega1_des = (theta1_mid - theta1_start) * (Modelica.Constants.pi / (2.0 * t_seg1_end)) * Modelica.Math.sin(Modelica.Constants.pi * s1_arg)
             + (theta1_end - theta1_mid) * (Modelica.Constants.pi / (2.0 * (t_seg2_end - t_seg1_end))) * Modelica.Math.sin(Modelica.Constants.pi * s2_arg);
  omega2_des = (theta2_mid - theta2_start) * (Modelica.Constants.pi / (2.0 * t_seg1_end)) * Modelica.Math.sin(Modelica.Constants.pi * s1_arg)
             + (theta2_end - theta2_mid) * (Modelica.Constants.pi / (2.0 * (t_seg2_end - t_seg1_end))) * Modelica.Math.sin(Modelica.Constants.pi * s2_arg);

  // ===== Cylinder kinematics (linearized mapping) =====
  xp_boom = xp0_boom + r_boom * (theta1 - theta1_start);
  xp_stick = xp0_stick + r_stick * (theta2 - theta2_start);
  xp_boom_des = xp0_boom + r_boom * (theta1_des - theta1_start);
  xp_stick_des = xp0_stick + r_stick * (theta2_des - theta2_start);
  vp_boom = r_boom * omega1;
  vp_stick = r_stick * omega2;
  vp_boom_des = r_boom * omega1_des;
  vp_stick_des = r_stick * omega2_des;

  // ===== End-effector forward kinematics =====
  x_ee = L_boom * Modelica.Math.cos(theta1) + L_stick * Modelica.Math.cos(theta1 + theta2);
  y_ee = L_boom * Modelica.Math.sin(theta1) + L_stick * Modelica.Math.sin(theta1 + theta2);

  // ===== Finite-duration payload disturbance =====
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_disturbance else 0.0;
  tau_dist = F_dist * L_boom * Modelica.Math.cos(theta1);

  // ===== Gravity torques =====
  tau_grav_boom = (m_boom * g * L_boom / 2.0 + (m_stick + m_payload) * g * L_boom) * Modelica.Math.cos(theta1);
  tau_grav_stick = (m_stick * g * L_stick / 2.0 + m_payload * g * L_stick) * Modelica.Math.cos(theta1 + theta2);

  // ===== Cylinder forces =====
  F_boom = pA_boom * A_A_boom - pB_boom * A_B_boom;
  F_stick = pA_stick * A_A_stick - pB_stick * A_B_stick;
  tau_cyl_boom = F_boom * r_boom;
  tau_cyl_stick = F_stick * r_stick;

  // ===== Chamber volumes =====
  VA_boom = V_A0_boom + A_A_boom * xp_boom;
  VB_boom = V_B0_boom - A_B_boom * xp_boom;
  VA_stick = V_A0_stick + A_A_stick * xp_stick;
  VB_stick = V_B0_stick - A_B_stick * xp_stick;

  // ===== Load-sensing pressures =====
  p_load_boom = (pA_boom * A_A_boom + pB_boom * A_B_boom) / (A_A_boom + A_B_boom);
  p_load_stick = (pA_stick * A_A_stick + pB_stick * A_B_stick) / (A_A_stick + A_B_stick);
  p_load_max = max(p_load_boom, p_load_stick);

  // ===== Controller: feedforward flow + position feedback + pressure feedback =====
  // Feedforward: desired flow = cap-end area * desired piston velocity
  // Position feedback: proportional correction on cylinder position error
  // Pressure feedback: load pressure compensation around nominal
  cmd_boom_raw = Kff_boom * A_A_boom * vp_boom_des
               + Kp_pos_boom * (xp_boom_des - xp_boom)
               + Kp_pres_boom * (p_load_boom - p_nom_boom);
  cmd_stick_raw = Kff_stick * A_A_stick * vp_stick_des
                + Kp_pos_stick * (xp_stick_des - xp_stick)
                + Kp_pres_stick * (p_load_stick - p_nom_stick);

  // Command saturation
  cmd_boom = max(-cmd_max, min(cmd_max, cmd_boom_raw));
  cmd_stick = max(-cmd_max, min(cmd_max, cmd_stick_raw));

  // ===== Valve dynamics (first-order lag) =====
  der(Qv_boom) = (cmd_boom - Qv_boom) / tau_valve;
  der(Qv_stick) = (cmd_stick - Qv_stick) / tau_valve;

  // ===== Cylinder pressure dynamics (fluid compressibility + internal leakage) =====
  // Cap side: inflow from valve, outflow from piston motion and leakage
  der(pA_boom) = (beta / VA_boom) * (Qv_boom - A_A_boom * vp_boom - leak_boom * (pA_boom - pB_boom));
  der(pB_boom) = (beta / VB_boom) * (-Qv_boom + A_B_boom * vp_boom + leak_boom * (pA_boom - pB_boom));
  der(pA_stick) = (beta / VA_stick) * (Qv_stick - A_A_stick * vp_stick - leak_stick * (pA_stick - pB_stick));
  der(pB_stick) = (beta / VB_stick) * (-Qv_stick + A_B_stick * vp_stick + leak_stick * (pA_stick - pB_stick));

  // ===== Mechanical dynamics =====
  // Boom: cylinder torque vs gravity, friction, and disturbance
  alpha1 = (tau_cyl_boom - tau_grav_boom - b_boom * omega1 - tau_dist) / J_boom;
  der(theta1) = omega1;
  der(omega1) = alpha1;

  // Stick: cylinder torque vs gravity and friction
  alpha2 = (tau_cyl_stick - tau_grav_stick - b_stick * omega2) / J_stick;
  der(theta2) = omega2;
  der(omega2) = alpha2;

  // ===== Load-sensing pump with relief valve =====
  // Pump supply pressure tracks max load pressure + margin, capped by relief
  der(p_supply) = (min(p_load_max + p_margin, p_relief) - p_supply) / tau_pump;

  // Relief valve opens when supply exceeds relief setting
  Q_relief = max(0.0, (p_supply - p_relief) * Kv_relief);

  // Total pump flow = flow demanded by valves + relief flow
  Q_demand = abs(Qv_boom) + abs(Qv_stick);
  Q_pump = Q_demand + Q_relief;
  Q_supply = Q_pump;

  // ===== Tracking errors =====
  err_boom = abs(xp_boom - xp_boom_des);
  err_stick = abs(xp_stick - xp_stick_des);
  err_primary = err_boom;

  // ===== Bounds verification =====
  travel_ok = abs(theta1) < 2.5 and abs(theta2) < 2.5;
  pressure_ok = p_supply <= p_relief + 1.0e6 and pA_boom < 35.0e6 and pB_boom < 35.0e6 and pA_stick < 35.0e6 and pB_stick < 35.0e6 and pA_boom > 0.0 and pB_boom > 0.0 and pA_stick > 0.0 and pB_stick > 0.0 and p_supply > 0.0;
  flow_ok = Q_pump <= 0.01;
  accel_ok = abs(alpha1) < 200.0 and abs(alpha2) < 200.0;
  error_ok = if time > 7.8 then err_primary < 0.019 else true;
  relief_ok = p_supply < p_relief + 0.5e6;

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "<html>
<p>HydBoomTrackC: Fluid-power robotic actuator system with feedforward flow control
and pressure-position feedback for a two-segment boom-stick position trajectory
under a finite-duration payload disturbance.</p>
<p>Plant: fixed base with 2.0 m boom and 1.4 m stick, two double-acting hydraulic
cylinders, 300 kg payload, load-sensing pump with relief valve, two valve sections.</p>
<p>Control: feedforward flow (desired velocity * cap-end area) + position feedback
(proportional on cylinder position error) + pressure feedback (load pressure
compensation around nominal).</p>
<p>Disturbance: 198 N payload step during middle third (4-8 s).</p>
<p>Sampling: 125 Hz (dt = 0.008 s), Duration: 12 s.</p>
<p>Primary tracking error bound: 0.019 m after 7.8 s.</p>
<p>Instrumentation: position (theta1, theta2, xp_boom, xp_stick, x_ee, y_ee),
velocity (omega1, omega2, vp_boom, vp_stick), chamber pressure (pA_boom, pB_boom,
pA_stick, pB_stick), pump/supply flow (Q_pump, Q_supply, Q_demand, Q_relief),
command (cmd_boom, cmd_stick, cmd_boom_raw, cmd_stick_raw).</p>
</html>")
  );
end HydBoomTrackC;