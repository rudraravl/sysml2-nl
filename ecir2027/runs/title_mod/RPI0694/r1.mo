model HydBoomConserveD
  "Instrumented hydraulic boom-stick robotic actuator with energy-aware motion control";

  // ---------- Geometry ----------
  parameter Modelica.Units.SI.Length L_boom = 2.0  "Boom length";
  parameter Modelica.Units.SI.Length L_stick = 1.4   "Stick length";
  parameter Modelica.Units.SI.Length r_boom = 0.50  "Boom cylinder effective moment arm";
  parameter Modelica.Units.SI.Length r_stick = 0.40  "Stick cylinder effective moment arm";

  // ---------- Payload and inertia ----------
  parameter Modelica.Units.SI.Mass m_payload = 300 "Payload mass";
  parameter Modelica.Units.SI.Inertia J_boom = 1200  "Boom reflected inertia about base";
  parameter Modelica.Units.SI.Inertia J_stick = 200  "Stick reflected inertia about joint";
  parameter Modelica.Units.SI.Damping d_boom = 200.0;
  parameter Modelica.Units.SI.Damping d_stick = 100.0;

  // ---------- Hydraulics ----------
  parameter Modelica.Units.SI.VolumeFlowRate Q_pump_max = 0.004 "Pump capacity";
  parameter Modelica.Units.SI.Pressure p_supply = 20.0e6 "Load-sensing supply pressure";
  parameter Modelica.Units.SI.Pressure p_relief = 25.0e6 "Relief valve pressure";
  parameter Modelica.Units.SI.Pressure p_return = 0.5e6 "Tank/return pressure";
  parameter Modelica.Units.SI.BulkModulus beta0 = 1.6e9 "Oil bulk modulus at T_ref";
  parameter Modelica.Units.SI.Density rho_oil = 850 "Oil density";
  parameter Modelica.Units.SI.Area A_piston = 1.5e-3 "Cylinder piston (cap) area";
  parameter Modelica.Units.SI.Area A_rod = 7.0e-4    "Cylinder rod side area";
  parameter Modelica.Units.SI.Length x0 = 0.80 "Cylinder dead (neutral) length";
  parameter Modelica.Units.SI.Length x_stroke = 0.80 "Cylinder stroke";
  parameter Modelica.Units.SI.Volume V_min = 1.0e-5 "Minimum chamber volume guard";
  parameter Real Kv = 5.0e-11 "Valve conductance [m3/(s.Pa)]";
  parameter Real Kv_relief = 5.0e-12 "Relief conductance [m3/(s.Pa)]";

  // ---------- Thermal ----------
  parameter Modelica.Units.SI.Temperature T_ref = 303.15 "Reference oil temperature";
  parameter Modelica.Units.SI.Temperature T_amb = 293.15 "Ambient temperature";
  parameter Modelica.Units.SI.HeatCapacity C_oil = 8.0e4 "Oil thermal capacity";
  parameter Modelica.Units.SI.ThermalConductance G_th = 5.0 "Convection to ambient";
  parameter Real beta_Tcoef = -3.0e-3 "Bulk modulus temp coefficient [1/K]";

  // ---------- Control ----------
  parameter Real Kp1 = 30.0 "Boom proportional gain";
  parameter Real Kd1 = 10.0 "Boom derivative gain";
  parameter Real Kp2 = 25.0 "Stick proportional gain";
  parameter Real Kd2 =  8.0 "Stick derivative gain";
  parameter Modelica.Units.SI.Time Ts = 0.005 "Control sample period (200 Hz)";
  parameter Modelica.Units.SI.Energy E_cap = 500.0e3 "Declared energy-use cap";
  parameter Real E_thresh = 0.85 "Fraction of E_cap triggering degradation";
  parameter Real deg_min = 0.30 "Minimum retained controller gain (bounded degradation)";

  // ---------- Reference cycle ----------
  parameter Real theta1_0 = 1.00 "Boom nominal angle [rad]";
  parameter Real theta2_0 = 0.30 "Stick nominal angle [rad]";
  parameter Real amp1 = 0.20 "Boom cycle amplitude [rad]";
  parameter Real amp2 = 0.30 "Stick cycle amplitude [rad]";
  parameter Real T_cycle = 7.0  "Cycle period [s]";
  parameter Real T_end = 14.0   "Run duration [s]";

  // ---------- Disturbance ----------
  parameter Modelica.Units.SI.Force F_dist = 180.0 "Load variation [N]";

  // ---------- Gravity ----------
  parameter Modelica.Units.SI.Acceleration g = 9.81;

  // ---------- Dynamic states ----------
  Real theta1(start=theta1_0, fixed=true) "Boom angle [rad]";
  Real theta2(start=theta2_0, fixed=true) "Stick angle [rad]";
  Real omega1(start=0, fixed=true) "Boom angular velocity [rad/s]";
  Real omega2(start=0, fixed=true) "Stick angular velocity [rad/s]";
  Modelica.Units.SI.Pressure p_A1(start=5.5e6, fixed=true) "Boom cap-side pressure";
  Modelica.Units.SI.Pressure p_B1(start=1.0e6, fixed=true) "Boom rod-side pressure";
  Modelica.Units.SI.Pressure p_A2(start=1.4e6, fixed=true) "Stick cap-side pressure";
  Modelica.Units.SI.Pressure p_B2(start=1.0e6, fixed=true) "Stick rod-side pressure";
  Modelica.Units.SI.Energy E_accum(start=0, fixed=true) "Accumulated pump hydraulic energy";
  Modelica.Units.SI.Temperature T_oil(start=T_ref, fixed=true) "Oil temperature";

  // ---------- Discrete controller states ----------
  discrete Real u1_d(start=0) "Boom valve command (held)";
  discrete Real u2_d(start=0) "Stick valve command (held)";

  // ---------- Algebraic variables ----------
  Real u1, u2 "Raw valve commands";
  Real u1_sat, u2_sat "Saturated valve commands";
  Real u1_pos, u1_neg, u2_pos, u2_neg "Valve command decomposition";
  Modelica.Units.SI.VolumeFlowRate Q_A1, Q_B1, Q_A2, Q_B2 "Chamber flows";
  Modelica.Units.SI.VolumeFlowRate Q_relief_A1, Q_relief_A2 "Relief flows";
  Modelica.Units.SI.VolumeFlowRate Q_supply_raw "Unlimited supply draw";
  Modelica.Units.SI.VolumeFlowRate Q_supply "Pump-limited supply flow";
  Real scale_q "Pump saturation scaling";
  Modelica.Units.SI.Force F_cyl1 "Boom cylinder force";
  Modelica.Units.SI.Force F_cyl2 "Stick cylinder force";
  Modelica.Units.SI.Volume V_A1, V_B1, V_A2, V_B2 "Chamber volumes";
  Modelica.Units.SI.Length x1, x2 "Cylinder lengths";
  Modelica.Units.SI.Torque T_grav1, T_grav2 "Gravity torques";
  Modelica.Units.SI.Torque T_dist1, T_dist2 "Disturbance torques";
  Modelica.Units.SI.Force F_dist_act "Active disturbance force";
  Modelica.Units.SI.BulkModulus beta_eff "Temperature-corrected bulk modulus";

  // Reference and tracking
  Real theta1_ref, theta2_ref "Reference angles [rad]";
  Real e1, e2 "Angle tracking errors [rad]";
  Real e1_dot, e2_dot "Tracking error rates [rad/s]";
  Real tip_x, tip_y "Actual tip position [m]";
  Real tip_x_ref, tip_y_ref "Reference tip position [m]";
  Real tip_err "Primary tracking error [m]";
  Real e_deg "Energy-aware degradation factor";

  // ---------- Sensor traces ----------
  Modelica.Units.SI.Pressure p_supply_meas "Measured supply pressure";
  Modelica.Units.SI.VolumeFlowRate Q_supply_meas "Measured supply flow";
  Modelica.Units.SI.Energy E_meas "Measured accumulated energy";
  Real theta1_meas, theta2_meas "Measured joint angles";
  Real omega1_meas, omega2_meas "Measured joint rates";
  Modelica.Units.SI.Temperature T_oil_meas "Measured oil temperature";

  // ---------- Requirement checks ----------
  Boolean cycle_complete "Cycle completed flag";
  Boolean energy_ok "Energy within declared cap";
  Boolean tracking_ok "Primary tracking error within bound after 9.1 s";
  Boolean no_nan_inf "No NaN/infinite physical, control, or estimator values";
  Boolean bounds_ok "All physical bounds respected";

equation
  // ---- Cylinder geometry and chamber volumes ----
  x1 = x0 + r_boom * (theta1 - theta1_0);
  x2 = x0 + r_stick * (theta2 - theta2_0);
  V_A1 = max(A_piston * x1, V_min);
  V_B1 = max(A_rod * (x0 + x_stroke - x1), V_min);
  V_A2 = max(A_piston * x2, V_min);
  V_B2 = max(A_rod * (x0 + x_stroke - x2), V_min);

  // ---- Cylinder forces ----
  F_cyl1 = p_A1 * A_piston - p_B1 * A_rod;
  F_cyl2 = p_A2 * A_piston - p_B2 * A_rod;

  // ---- Temperature-dependent bulk modulus (compressibility + thermal effect) ----
  beta_eff = beta0 * (1.0 + beta_Tcoef * (T_oil - T_ref));

  // ---- Gravity torques (payload dominant) ----
  T_grav1 = m_payload * g * (L_boom * cos(theta1) + 0.5 * L_stick * cos(theta1 + theta2));
  T_grav2 = m_payload * g * 0.5 * L_stick * cos(theta1 + theta2);

  // ---- Disturbance: 180 N vertical load variation during middle third ----
  F_dist_act = if (time >= T_end/3.0 and time <= 2.0*T_end/3.0) then F_dist else 0.0;
  T_dist1 = F_dist_act * (L_boom * cos(theta1) + L_stick * cos(theta1 + theta2));
  T_dist2 = F_dist_act * L_stick * cos(theta1 + theta2);

  // ---- Reference trajectory (repeated cycle) ----
  theta1_ref = theta1_0 + amp1 * sin(2.0 * Modelica.Constants.pi * time / T_cycle);
  theta2_ref = theta2_0 + amp2 * sin(2.0 * Modelica.Constants.pi * time / T_cycle);

  // ---- Tracking errors ----
  e1 = theta1_ref - theta1;
  e2 = theta2_ref - theta2;
  e1_dot = der(theta1_ref) - omega1;
  e2_dot = der(theta2_ref) - omega2;

  // ---- Tip position and primary tracking error ----
  tip_x = L_boom * sin(theta1) + L_stick * sin(theta1 + theta2);
  tip_y = L_boom * cos(theta1) + L_stick * cos(theta1 + theta2);
  tip_x_ref = L_boom * sin(theta1_ref) + L_stick * sin(theta1_ref + theta2_ref);
  tip_y_ref = L_boom * cos(theta1_ref) + L_stick * cos(theta1_ref + theta2_ref);
  tip_err = sqrt(max((tip_x - tip_x_ref)^2 + (tip_y - tip_y_ref)^2, 0.0));

  // ---- Energy-aware bounded degradation ----
  e_deg = if E_accum > E_thresh * E_cap then
            max(1.0 - (E_accum - E_thresh * E_cap) / ((1.0 - E_thresh) * E_cap), deg_min)
          else 1.0;

  // ---- Discrete motion controller at 200 Hz ----
  when sample(0, Ts) then
    u1_d = max(-1.0, min(1.0, e_deg * (Kp1 * e1 + Kd1 * e1_dot)));
    u2_d = max(-1.0, min(1.0, e_deg * (Kp2 * e2 + Kd2 * e2_dot)));
  end when;

  u1 = u1_d;
  u2 = u2_d;
  u1_sat = max(-1.0, min(1.0, u1));
  u2_sat = max(-1.0, min(1.0, u2));
  u1_pos = max(u1_sat, 0.0);
  u1_neg = max(-u1_sat, 0.0);
  u2_pos = max(u2_sat, 0.0);
  u2_neg = max(-u2_sat, 0.0);

  // ---- 4/3 valve flows with supply and return paths ----
  Q_A1 = Kv * (u1_pos * (p_supply - p_A1) - u1_neg * (p_A1 - p_return));
  Q_B1 = Kv * (u1_pos * (p_B1 - p_return) - u1_neg * (p_supply - p_B1));
  Q_A2 = Kv * (u2_pos * (p_supply - p_A2) - u2_neg * (p_A2 - p_return));
  Q_B2 = Kv * (u2_pos * (p_B2 - p_return) - u2_neg * (p_supply - p_B2));

  // ---- Relief valves (pressure bound) ----
  Q_relief_A1 = max(p_A1 - p_relief, 0.0) * Kv_relief;
  Q_relief_A2 = max(p_A2 - p_relief, 0.0) * Kv_relief;

  // ---- Pump flow limiting ----
  Q_supply_raw = Kv * (u1_pos * (p_supply - p_A1) + u2_pos * (p_supply - p_A2)
                     + u1_neg * (p_supply - p_B1) + u2_neg * (p_supply - p_B2));
  scale_q = if Q_supply_raw > Q_pump_max then Q_pump_max / Q_supply_raw else 1.0;
  Q_supply = scale_q * Q_supply_raw;

  // ---- Pressure dynamics (compressibility) ----
  der(p_A1) = (beta_eff / V_A1) * (Q_A1 * scale_q - A_piston * r_boom * omega1 - Q_relief_A1);
  der(p_B1) = (beta_eff / V_B1) * (A_rod * r_boom * omega1 - Q_B1 * scale_q);
  der(p_A2) = (beta_eff / V_A2) * (Q_A2 * scale_q - A_piston * r_stick * omega2 - Q_relief_A2);
  der(p_B2) = (beta_eff / V_B2) * (A_rod * r_stick * omega2 - Q_B2 * scale_q);

  // ---- Mechanical dynamics ----
  der(theta1) = omega1;
  der(theta2) = omega2;
  J_boom * der(omega1) = F_cyl1 * r_boom - d_boom * omega1 - T_grav1 - T_dist1;
  J_stick * der(omega2) = F_cyl2 * r_stick - d_stick * omega2 - T_grav2 - T_dist2;

  // ---- Accumulated hydraulic energy ----
  der(E_accum) = p_supply * Q_supply;

  // ---- Simple thermal model (compressive heating + cooling) ----
  der(T_oil) = (p_supply * Q_supply - p_return * (Q_B1 + Q_B2 + Q_relief_A1 + Q_relief_A2))
               / C_oil - (T_oil - T_amb) * G_th / C_oil;

  // ---- Sensor traces ----
  p_supply_meas = p_supply;
  Q_supply_meas = Q_supply;
  E_meas = E_accum;
  theta1_meas = theta1;
  theta2_meas = theta2;
  omega1_meas = omega1;
  omega2_meas = omega2;
  T_oil_meas = T_oil;

  // ---- Requirement checks ----
  cycle_complete = time >= T_end - Ts;
  energy_ok = E_accum <= E_cap;
  tracking_ok = if time >= 9.1 then tip_err < 0.02 else true;
  bounds_ok = (p_A1 >= 0.0) and (p_B1 >= 0.0) and (p_A2 >= 0.0) and (p_B2 >= 0.0)
              and (Q_supply <= Q_pump_max + 1.0e-9)
              and (abs(u1_sat) <= 1.0) and (abs(u2_sat) <= 1.0)
              and (abs(omega1) < 1.0e3) and (abs(omega2) < 1.0e3);
  no_nan_inf = (abs(theta1) < 1.0e20) and (abs(theta2) < 1.0e20)
              and (abs(omega1) < 1.0e20) and (abs(omega2) < 1.0e20)
              and (abs(p_A1) < 1.0e20) and (abs(p_B1) < 1.0e20)
              and (abs(p_A2) < 1.0e20) and (abs(p_B2) < 1.0e20)
              and (abs(E_accum) < 1.0e20) and (abs(tip_err) < 1.0e20)
              and (abs(u1_d) < 1.0e20) and (abs(u2_d) < 1.0e20);

  annotation (
    Documentation(info="Instrumented 2-DOF hydraulic boom-stick actuator.
  Boom 2.0 m, stick 1.4 m, 300 kg payload. Two valve sections on a shared
  load-sensing pump (Q_max=0.004 m3/s) with relief (25 MPa) and 0.5 MPa return.
  Double-acting cylinders with oil compressibility (bulk modulus) and thermal
  heating. Energy-aware motion controller sampled at 200 Hz with bounded
  degradation. 180 N load disturbance applied during the middle third of the run.
  Run 14 s. Requirements: cycle completion, E_accum <= E_cap, tip_err < 0.02 m
  after 9.1 s, all physical bounds respected, no NaN/infinite values."),
    experiment(StopTime=14.0, Tolerance=1.0e-6, Interval=0.005),
    Diagram(coordinateSystem(extent={{-100,-100},{100,100}}))
  );
end HydBoomConserveD;