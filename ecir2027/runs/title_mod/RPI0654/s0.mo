model PneuGripPositionF
  "Pneumatic gripper position control: two cylinders, two opposing fingers, 500 Hz, 20 s"

  // ===== Geometry and mass (from requirement) =====
  parameter Real L = 0.035 "Cylinder travel [m]";
  parameter Real A_p = 0.0012 "Piston area [m2]";
  parameter Real m_finger = 0.8 "Gripper finger mass [kg]";

  // ===== Pneumatic operating context =====
  // P_supply and P_return are declared parameters; values are engineering
  // defaults since the requirement does not specify magnitudes.
  parameter Real P_supply = 500000.0 "Supply pressure, absolute [Pa]";
  parameter Real P_return = 101325.0 "Return pressure, absolute [Pa]";
  parameter Real R_air = 287.0 "Specific gas constant of air [J/(kg.K)]";
  parameter Real T_gas = 293.15 "Chamber gas temperature [K]";
  parameter Real V_dead = 5.0e-5 "Dead volume per chamber [m3] — assumed";
  parameter Real mdot_max = 0.001 "Maximum valve mass flow rate [kg/s]";
  parameter Real b_fric = 80.0 "Viscous friction coefficient [N.s/m] — assumed";
  parameter Real k_leak = 5.0e-11 "Inter-chamber leakage conductance [kg/(s.Pa)] — assumed";

  // ===== Mechanical end stops =====
  parameter Real k_stop = 1.0e7 "End stop stiffness [N/m] — assumed";
  parameter Real c_stop = 2.0e3 "End stop damping [N.s/m] — assumed";

  // ===== Disturbance (from requirement) =====
  parameter Real F_load = 145.0 "External load disturbance [N]";

  // ===== Mission (from requirement) =====
  parameter Real x_target = 0.7 * L "Target position, 70% of travel [m]";

  // ===== Control gains — pressure-aware cascade =====
  parameter Real Kp_f = 15000.0 "Outer position proportional gain [N/m] — assumed";
  parameter Real Kd_f = 800.0 "Outer position derivative gain [N.s/m] — assumed";
  parameter Real Ki_f = 3000.0 "Outer position integral gain [N/(m.s)] — assumed";
  parameter Real K_v = 2.0e-5 "Inner pressure-loop valve gain [1/Pa] — assumed";

  // ===== Dynamic states: cylinder 1 / finger 1 =====
  Real x1 "Finger 1 position [m]";
  Real v1 "Finger 1 velocity [m/s]";
  Real P1A "Cyl 1 chamber A pressure [Pa]";
  Real P1B "Cyl 1 chamber B pressure [Pa]";

  // ===== Dynamic states: cylinder 2 / finger 2 =====
  Real x2 "Finger 2 position [m]";
  Real v2 "Finger 2 velocity [m/s]";
  Real P2A "Cyl 2 chamber A pressure [Pa]";
  Real P2B "Cyl 2 chamber B pressure [Pa]";

  // ===== Control state =====
  Real err_int "Integral of tracking error [m.s]";

  // ===== Control and algebraic variables =====
  Real err "Tracking error [m]";
  Real err_der "Error derivative [m/s]";
  Real F_des "Desired pneumatic force per cylinder [N]";
  Real u1 "Cyl 1 valve command, bounded [-1, 1]";
  Real u2 "Cyl 2 valve command, bounded [-1, 1]";

  Real mdot1A "Cyl 1 chamber A mass flow [kg/s]";
  Real mdot1B "Cyl 1 chamber B mass flow [kg/s]";
  Real mdot2A "Cyl 2 chamber A mass flow [kg/s]";
  Real mdot2B "Cyl 2 chamber B mass flow [kg/s]";

  Real F1 "Cyl 1 pneumatic force [N]";
  Real F2 "Cyl 2 pneumatic force [N]";
  Real F_end1 "Cyl 1 end stop force [N]";
  Real F_end2 "Cyl 2 end stop force [N]";
  Real F_ext "External disturbance load [N]";

  // ===== Synchronized observations =====
  Real x_meas "Measured average actuator position [m]";
  Real v_meas "Measured average actuator velocity [m/s]";
  Real P_diff1 "Cyl 1 chamber pressure difference [Pa]";
  Real P_diff2 "Cyl 2 chamber pressure difference [Pa]";

  // ===== Verification flag =====
  Boolean err_ok "Primary tracking error below 0.01 m after 13 s";

  // Guarded volume expressions (ensure well-defined non-singular divisor)
  Real V1A "Cyl 1 chamber A volume [m3]";
  Real V1B "Cyl 1 chamber B volume [m3]";
  Real V2A "Cyl 2 chamber A volume [m3]";
  Real V2B "Cyl 2 chamber B volume [m3]";

initial equation
  x1 = 0.0;
  v1 = 0.0;
  x2 = 0.0;
  v2 = 0.0;
  P1A = P_return;
  P1B = P_return;
  P2A = P_return;
  P2B = P_return;
  err_int = 0.0;

equation
  // ---- Tracking error (based on finger 1, symmetric system) ----
  err = x_target - x1;
  err_der = -v1;
  der(err_int) = err;

  // ---- Pressure-aware cascade nonlinear position controller ----
  // Outer loop: desired force from position PD+I
  // Inner loop: valve command drives measured pressure difference toward
  //   the pressure difference needed for the desired force
  F_des = Kp_f * err + Kd_f * err_der + Ki_f * err_int;
  u1 = tanh(K_v * (F_des / A_p - P_diff1));
  u2 = tanh(K_v * (F_des / A_p - P_diff2));

  // ---- Proportional valve mass flow commands (never exceed mdot_max) ----
  mdot1A = u1 * mdot_max;
  mdot1B = -u1 * mdot_max;
  mdot2A = u2 * mdot_max;
  mdot2B = -u2 * mdot_max;

  // ---- Guarded chamber volumes ----
  V1A = max(V_dead + A_p * x1, 0.1 * V_dead);
  V1B = max(V_dead + A_p * (L - x1), 0.1 * V_dead);
  V2A = max(V_dead + A_p * x2, 0.1 * V_dead);
  V2B = max(V_dead + A_p * (L - x2), 0.1 * V_dead);

  // ---- Compressible chamber pressure dynamics (isothermal ideal gas) ----
  // P*V = m*R*T  =>  dP/dt = (R*T/V) * dm/dt - (P/V) * dV/dt
  // Leakage flows from high-pressure chamber to low-pressure chamber
  der(P1A) = (R_air * T_gas / V1A) * (mdot1A - k_leak * (P1A - P1B))
             - (P1A / V1A) * A_p * v1;
  der(P1B) = (R_air * T_gas / V1B) * (mdot1B + k_leak * (P1A - P1B))
             + (P1B / V1B) * A_p * v1;
  der(P2A) = (R_air * T_gas / V2A) * (mdot2A - k_leak * (P2A - P2B))
             - (P2A / V2A) * A_p * v2;
  der(P2B) = (R_air * T_gas / V2B) * (mdot2B + k_leak * (P2A - P2B))
             + (P2B / V2B) * A_p * v2;

  // ---- Pressure differences and pneumatic forces ----
  P_diff1 = P1A - P1B;
  P_diff2 = P2A - P2B;
  F1 = A_p * P_diff1;
  F2 = A_p * P_diff2;

  // ---- Mechanical end stops (spring-damper outside [0, L]) ----
  F_end1 = if x1 < 0.0 then -k_stop * x1 - c_stop * v1
           elseif x1 > L then k_stop * (x1 - L) + c_stop * v1
           else 0.0;
  F_end2 = if x2 < 0.0 then -k_stop * x2 - c_stop * v2
           elseif x2 > L then k_stop * (x2 - L) + c_stop * v2
           else 0.0;

  // ---- External disturbance: 145 N during middle third [6.667, 13.333] s ----
  F_ext = if time > 20.0 / 3.0 and time < 40.0 / 3.0 then F_load else 0.0;

  // ---- Newton's second law (each finger carries half the external load) ----
  m_finger * der(v1) = F1 - b_fric * v1 - F_end1 - F_ext / 2.0;
  m_finger * der(v2) = F2 - b_fric * v2 - F_end2 - F_ext / 2.0;
  der(x1) = v1;
  der(x2) = v2;

  // ---- Synchronized sensor traces ----
  x_meas = (x1 + x2) / 2.0;
  v_meas = (v1 + v2) / 2.0;

  // ---- Verification: primary tracking error < 0.01 m after 13 s ----
  err_ok = if time >= 13.0 then abs(err) < 0.01 else true;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Pneumatic gripper position control scenario PneuGripPositionF.
Two pneumatic cylinders (travel 0.035 m, piston area 0.0012 m2) drive opposing 0.8 kg
gripper fingers via proportional air valves (max 0.001 kg/s). Includes compressible
isothermal chamber dynamics, inter-chamber leakage, and mechanical end stops.
Pressure-aware cascade controller: outer position PD+I produces a desired force;
inner pressure loop commands the proportional valve to track the required pressure
difference. External 145 N load applied during the middle third [6.667, 13.333] s.
Mission: reach and hold 70% of travel (0.0245 m). Sampling 500 Hz, duration 20 s.
Verification flag err_ok asserts tracking error below 0.01 m after 13 s.
Assumed values (not specified by requirement): P_supply, P_return, V_dead, b_fric,
k_leak, k_stop, c_stop, and all control gains.")
  );
end PneuGripPositionF;