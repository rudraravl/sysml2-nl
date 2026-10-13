model PneuGripConserveF
  annotation(
    experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Pneumatic gripper with energy-aware motion control.
  Two pneumatic cylinders drive opposing 0.8 kg fingers.
  Run at 500 Hz (Interval=0.002 s) for 20 s.
  261 N disturbance applied during middle third [6.667 s, 13.333 s].")
  );

  // ---- Physical parameters (SI units) ----
  parameter Real stroke = 0.035 "Cylinder travel (m)";
  parameter Real A_piston = 0.0012 "Piston area (m2)";
  parameter Real m_finger = 0.8 "Gripper finger mass (kg)";
  parameter Real m_dot_max = 0.001 "Max valve mass flow rate (kg/s)";
  parameter Real P_supply = 6.0e5 "Supply pressure (Pa)";
  parameter Real P_return = 1.0e5 "Return/exhaust pressure (Pa)";
  parameter Real T_ref = 293.15 "Reference temperature (K)";
  parameter Real R_air = 287.05 "Specific gas constant (J/(kg.K))";
  parameter Real cp_air = 1005.0 "Specific heat capacity (J/(kg.K))";
  parameter Real V_dead = 1.0e-6 "Dead volume (m3)";
  parameter Real k_poly = 1.2 "Polytropic exponent (thermal/compressibility)";
  parameter Real b_fric = 5.0 "Viscous friction coefficient (N.s/m)";
  parameter Real F_dist_amp = 261.0 "Load disturbance amplitude (N)";
  parameter Real k_stop = 1.0e5 "End-stop stiffness (N/m)";

  // ---- Control parameters ----
  parameter Real Kp = 800.0 "Position proportional gain";
  parameter Real Kd = 30.0 "Position derivative gain";
  parameter Real period = 4.0 "Actuation cycle period (s)";
  parameter Real u_scale = 28.0 "Command normalization scale (=Kp*stroke)";

  // ---- Caps and thresholds ----
  parameter Real E_cap = 150.0 "Declared energy use cap (J)";
  parameter Real m_air_cap = 0.02 "Declared air mass use cap (kg)";
  parameter Real err_thresh = 0.016 "Primary tracking error threshold after 13 s (m)";

  // ---- Dynamic state variables ----
  Real x1(start = 0.0, fixed = true) "Finger 1 position (m)";
  Real v1(start = 0.0, fixed = true) "Finger 1 velocity (m/s)";
  Real P1(start = P_return, fixed = true) "Chamber 1 pressure (Pa)";
  Real x2(start = 0.0, fixed = true) "Finger 2 position (m)";
  Real v2(start = 0.0, fixed = true) "Finger 2 velocity (m/s)";
  Real P2(start = P_return, fixed = true) "Chamber 2 pressure (Pa)";
  Real E_energy(start = 0.0, fixed = true) "Accumulated supply energy (J)";
  Real m_air_total(start = 0.0, fixed = true) "Total supply air mass consumed (kg)";

  // ---- Observable quantities ----
  Real V1 "Chamber 1 volume (m3)";
  Real V2 "Chamber 2 volume (m3)";
  Real u1_raw "Raw valve 1 command";
  Real u2_raw "Raw valve 2 command";
  Real u1 "Saturated valve 1 command [-1, 1]";
  Real u2 "Saturated valve 2 command [-1, 1]";
  Real m_dot_1 "Net mass flow into chamber 1 (kg/s)";
  Real m_dot_2 "Net mass flow into chamber 2 (kg/s)";
  Real m_dot_supply "Total supply mass flow (kg/s)";
  Real E_rate "Instantaneous supply energy rate (W)";
  Real F_drive1 "Pneumatic driving force finger 1 (N)";
  Real F_drive2 "Pneumatic driving force finger 2 (N)";
  Real F_stop1 "End-stop force finger 1 (N)";
  Real F_stop2 "End-stop force finger 2 (N)";
  Real F_dist "Disturbance force (N)";
  Real x_ref "Reference position (m)";
  Real err1 "Tracking error finger 1 (m)";
  Real err2 "Tracking error finger 2 (m)";
  Real err_primary "Primary (RMS) tracking error (m)";
  Real gamma "Energy-aware performance factor [0.7, 1.0]";
  Real cycle_count "Completed actuation cycles";

  // ---- Verification flags ----
  Boolean bounds_ok "Physical bounds satisfied";
  Boolean tracking_ok "Tracking error below 0.016 m after 13 s";
  Boolean energy_ok "Energy cap not exceeded";
  Boolean air_ok "Air mass cap not exceeded";
  Boolean no_nan_inf "No NaN or infinite values";

equation
  // Chamber volumes (V_dead guarantees positivity)
  V1 = V_dead + A_piston * x1;
  V2 = V_dead + A_piston * x2;

  // Polytropic pressure dynamics: compressibility + thermal effects
  // dP/dt = (k*R*T/V)*dm/dt - (k*P/V)*dV/dt
  der(P1) = (k_poly * R_air * T_ref / V1) * m_dot_1
          - (k_poly * P1 / V1) * A_piston * v1;
  der(P2) = (k_poly * R_air * T_ref / V2) * m_dot_2
          - (k_poly * P2 / V2) * A_piston * v2;

  // Valve command saturation [-1, 1]
  u1 = max(-1.0, min(1.0, u1_raw));
  u2 = max(-1.0, min(1.0, u2_raw));

  // Proportional valve mass flow with pressure-ratio dependence
  // Charging (u>0): flow from supply, limited by supply-chamber pressure ratio
  // Discharging (u<0): flow to exhaust, limited by chamber-return pressure ratio
  // Saturation at m_dot_max enforced by u in [-1, 1]
  m_dot_1 = if u1 >= 0.0 then
      u1 * m_dot_max * sqrt(max(1.0 - (P1 / P_supply) * (P1 / P_supply), 0.0))
    else
      u1 * m_dot_max * sqrt(max((P1 - P_return) / P_supply, 0.0));

  m_dot_2 = if u2 >= 0.0 then
      u2 * m_dot_max * sqrt(max(1.0 - (P2 / P_supply) * (P2 / P_supply), 0.0))
    else
      u2 * m_dot_max * sqrt(max((P2 - P_return) / P_supply, 0.0));

  // Supply mass flow (charging portions only, for energy accounting)
  m_dot_supply = (if m_dot_1 > 0.0 then m_dot_1 else 0.0)
               + (if m_dot_2 > 0.0 then m_dot_2 else 0.0);

  // Accumulated supply energy and air mass
  E_rate = m_dot_supply * cp_air * T_ref;
  der(E_energy) = E_rate;
  der(m_air_total) = m_dot_supply;

  // Pneumatic driving forces (chamber pressure vs return pressure)
  F_drive1 = (P1 - P_return) * A_piston;
  F_drive2 = (P2 - P_return) * A_piston;

  // End-stop forces (soft springs at stroke boundaries)
  F_stop1 = (if x1 < 0.0 then -k_stop * x1 else 0.0)
          + (if x1 > stroke then -k_stop * (x1 - stroke) else 0.0);
  F_stop2 = (if x2 < 0.0 then -k_stop * x2 else 0.0)
          + (if x2 > stroke then -k_stop * (x2 - stroke) else 0.0);

  // Disturbance: 261 N during middle third of 20 s [6.667 s, 13.333 s]
  F_dist = if (time >= 20.0 / 3.0 and time <= 40.0 / 3.0) then F_dist_amp else 0.0;

  // Newton's second law for each gripper finger
  m_finger * der(v1) = F_drive1 - b_fric * v1 + F_stop1 - F_dist;
  m_finger * der(v2) = F_drive2 - b_fric * v2 + F_stop2 - F_dist;
  der(x1) = v1;
  der(x2) = v2;

  // Reference trajectory: repeated grip/release cycle
  x_ref = stroke * 0.5 * (1.0 - cos(2.0 * 3.14159265358979 * time / period));

  // Tracking errors
  err1 = x_ref - x1;
  err2 = x_ref - x2;
  err_primary = sqrt(0.5 * (err1 * err1 + err2 * err2) + 1.0e-20);

  // Energy-aware performance degradation (bounded [0.7, 1.0])
  // Reduces control effort as accumulated energy approaches cap,
  // limiting performance to at most 30% degradation
  gamma = max(0.7, min(1.0, 1.0 - 0.3 * (E_energy / E_cap)));

  // PD position control with energy-aware gain modulation
  u1_raw = gamma * (Kp * err1 - Kd * v1) / u_scale;
  u2_raw = gamma * (Kp * err2 - Kd * v2) / u_scale;

  // Cycle completion counter
  cycle_count = floor(time / period);

  // Verification flags
  bounds_ok = (x1 >= -0.001 and x1 <= stroke + 0.001)
           and (x2 >= -0.001 and x2 <= stroke + 0.001)
           and (P1 >= 0.0 and P2 >= 0.0)
           and (P1 <= P_supply * 1.5 and P2 <= P_supply * 1.5);
  tracking_ok = if time >= 13.0 then (err_primary <= err_thresh) else true;
  energy_ok = (E_energy <= E_cap);
  air_ok = (m_air_total <= m_air_cap);
  no_nan_inf = (x1 == x1) and (x2 == x2) and (P1 == P1) and (P2 == P2)
            and (E_energy == E_energy) and (m_air_total == m_air_total)
            and (abs(x1) < 1.0e30) and (abs(x2) < 1.0e30)
            and (abs(P1) < 1.0e30) and (abs(P2) < 1.0e30)
            and (abs(E_energy) < 1.0e30) and (abs(m_air_total) < 1.0e30);

end PneuGripConserveF;