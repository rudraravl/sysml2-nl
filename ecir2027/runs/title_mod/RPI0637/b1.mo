model HydMotorTrackA
  "Bidirectional hydraulic motor driving a rotary table through a 12:1 gearbox,
   pressure-compensated proportional valve, feedforward flow control with
   pressure-position feedback, two-segment smooth trajectory, payload step
   disturbance during the middle third of an 8 s run at 80 Hz."

  // ---- Motor ----
  parameter Real D_m      = 48.0e-6 "Motor displacement per revolution [m3/rev]";
  parameter Real d_m      = D_m/(2.0*Modelica.Constants.pi) "Displacement per radian [m3/rad]";
  parameter Real eta_v    = 0.92    "Volumetric efficiency [-]";
  parameter Real eta_mech = 1.0     "Mechanical efficiency [-] (assumed, not specified)";

  // ---- Mechanical load ----
  parameter Real m_table  = 130.0   "Rotary table mass [kg]";
  parameter Real R_table  = 0.30    "Table radius used to map angle to rim travel [m] (assumed geometry)";
  parameter Real J_table  = 0.5*m_table*R_table^2 "Table inertia as a uniform disk [kg.m2] (assumed geometry)";
  parameter Real J_motor  = 0.010   "Motor rotor inertia [kg.m2] (assumed)";
  parameter Real gear     = 12.0    "Gearbox reduction ratio [-]";
  parameter Real b_motor  = 0.05    "Motor viscous friction [N.m.s/rad] (assumed)";
  parameter Real b_table  = 5.0     "Table viscous friction [N.m.s/rad] (assumed)";

  // ---- Hydraulics ----
  parameter Real beta      = 1.2e9  "Effective oil bulk modulus [Pa] (assumed)";
  parameter Real V_ch      = 1.0e-4 "Motor chamber volume [m3] (assumed)";
  parameter Real k_leak    = 1.0e-12 "Internal leakage coefficient [m3/(s.Pa)] (assumed)";
  parameter Real p_supply  = 10.0e6 "Supply pressure [Pa] (assumed)";
  parameter Real p_tank    = 1.0e5  "Tank/return pressure [Pa] (assumed)";
  parameter Real p_relief  = 12.0e6 "Relief valve cracking pressure [Pa] (assumed)";
  parameter Real k_relief  = 1.0e-8 "Relief valve conductance [m3/(s.Pa)] (assumed)";
  parameter Real Q_lim     = 0.001  "Valve command magnitude limit [m3/s]";

  // ---- Disturbance ----
  parameter Real F_dist_mag = 110.0 "Payload disturbance force magnitude [N]";
  parameter Real t_dist_on  = 8.0/3.0  "Disturbance onset [s] (middle third start)";
  parameter Real t_dist_off = 16.0/3.0 "Disturbance end [s] (middle third end)";
  parameter Real t_ramp     = 0.10    "Disturbance ramp time [s] (assumed)";

  // ---- Control gains (assumed tuning) ----
  parameter Real Kp_x = 0.020 "Position feedback gain [m3/s per m]";
  parameter Real Kd_x = 0.0020 "Velocity feedback gain [m3/s per (m/s)]";
  parameter Real Kp_p = 1.0e-11 "Pressure feedback (damping) gain [m3/s per Pa]";

  // ---- Bounds ----
  parameter Real bound_travel_max = 0.60 "Travel bound [m]";
  parameter Real bound_accel_max  = 5.0  "Acceleration bound [m/s2]";
  parameter Real bound_traj_max   = 0.024 "Tracking error bound after 5.2 s [m]";
  parameter Real bound_p_max     = 12.0e6 "Pressure upper bound [Pa]";

  // ---- Dynamic states ----
  Real theta_m(start=0.0) "Motor angle [rad]";
  Real omega_m(start=0.0) "Motor angular speed [rad/s]";
  Real p_a(start=1.0e5)   "Chamber A pressure [Pa]";
  Real p_b(start=1.0e5)   "Chamber B pressure [Pa]";

  // ---- Kinematic outputs ----
  Real theta_t "Table angle [rad]";
  Real omega_t "Table angular speed [rad/s]";
  Real x       "Linear position at table rim [m]";
  Real v       "Linear velocity at table rim [m/s]";
  Real a       "Linear acceleration at table rim [m/s2]";
  Real alpha_m "Motor angular acceleration [rad/s2]";

  // ---- Reference trajectory ----
  Real x_ref "Reference position [m]";
  Real v_ref "Reference velocity [m/s]";
  Real a_ref "Reference acceleration [m/s2]";

  // ---- Control ----
  Real e_x       "Tracking error (x_ref - x) [m]";
  Real Q_ff      "Feedforward flow [m3/s]";
  Real Q_pos     "Position/velocity feedback flow [m3/s]";
  Real Q_p       "Pressure feedback flow [m3/s]";
  Real Q_cmd_raw "Unlimited valve command [m3/s]";
  Real Q_cmd     "Limited valve command [m3/s]";
  Real Q_supply  "Supply/pump flow magnitude [m3/s]";

  // ---- Hydraulic internals ----
  Real dp          "Differential pressure p_a - p_b [Pa]";
  Real Q_leak      "Internal leakage flow [m3/s]";
  Real tau_m       "Motor torque [N.m]";
  Real Q_relief_a  "Relief flow from chamber A [m3/s]";
  Real Q_relief_b  "Relief flow from chamber B [m3/s]";

  // ---- Disturbance ----
  Real F_dist    "Active disturbance force opposing motion [N]";
  Real tau_dist  "Disturbance torque referred to motor shaft [N.m]";

  // ---- Equivalent parameters ----
  Real J_eq "Inertia referred to motor shaft [kg.m2]";
  Real b_eq "Viscous friction referred to motor shaft [N.m.s/rad]";

  // ---- Bound indicators ----
  Real bound_travel   "1.0 within travel bound";
  Real bound_pressure "1.0 within pressure (relief) bound";
  Real bound_flow     "1.0 within flow bound";
  Real bound_accel    "1.0 within acceleration bound";
  Real bound_traj     "1.0 within tracking-error bound after 5.2 s";
  Real bound_relief   "1.0 if relief valves inactive";

equation
  // ===== Two-segment smooth position trajectory =====
  // Segment 1 (0..4 s): 0 -> 0.5 m with cosine blend.
  // Segment 2 (4..8 s): 0.5 -> 0.2 m with cosine blend (C1 at t=4 s).
  x_ref = if time < 4.0 then
            0.25*(1.0 - Modelica.Math.cos(Modelica.Constants.pi*time/4.0))
          else
            0.50 - 0.15*(1.0 - Modelica.Math.cos(Modelica.Constants.pi*(time - 4.0)/4.0));
  v_ref = if time < 4.0 then
            0.25*(Modelica.Constants.pi/4.0)*Modelica.Math.sin(Modelica.Constants.pi*time/4.0)
          else
            -0.15*(Modelica.Constants.pi/4.0)*Modelica.Math.sin(Modelica.Constants.pi*(time - 4.0)/4.0);
  a_ref = if time < 4.0 then
            0.25*(Modelica.Constants.pi/4.0)^2*Modelica.Math.cos(Modelica.Constants.pi*time/4.0)
          else
            -0.15*(Modelica.Constants.pi/4.0)^2*Modelica.Math.cos(Modelica.Constants.pi*(time - 4.0)/4.0);

  // ===== Kinematics =====
  theta_t = theta_m / gear;
  omega_t = omega_m / gear;
  x = R_table * theta_t;
  v = R_table * omega_t;

  // ===== Equivalent inertia/friction at motor shaft =====
  J_eq = J_motor + J_table/(gear*gear);
  b_eq = b_motor + b_table/(gear*gear);

  // ===== Payload disturbance: smooth pulse over middle third, opposes motion =====
  F_dist = F_dist_mag
           * 0.5*(Modelica.Math.tanh((time - t_dist_on)/t_ramp)
                  - Modelica.Math.tanh((time - t_dist_off)/t_ramp))
           * Modelica.Math.tanh(omega_m/0.5);
  tau_dist = (F_dist * R_table) / gear;

  // ===== Motor hydraulics =====
  dp = p_a - p_b;
  Q_leak = k_leak * dp;
  tau_m = d_m * dp * eta_mech;

  // Smooth relief valve (positive-part with smoothing to avoid singularity)
  Q_relief_a = k_relief * 0.5*((p_a - p_relief)
                + Modelica.Math.sqrt((p_a - p_relief)*(p_a - p_relief) + 1.0));
  Q_relief_b = k_relief * 0.5*((p_b - p_relief)
                + Modelica.Math.sqrt((p_b - p_relief)*(p_b - p_relief) + 1.0));

  // Chamber pressure dynamics
  der(p_a) = (beta/V_ch)*(Q_cmd - d_m*omega_m - Q_leak - Q_relief_a);
  der(p_b) = (beta/V_ch)*(d_m*omega_m + Q_leak - Q_cmd - Q_relief_b);

  // Motor mechanical dynamics (compute acceleration algebraically, then integrate)
  alpha_m = (tau_m - b_eq*omega_m - tau_dist) / J_eq;
  a = R_table * alpha_m / gear;
  der(omega_m) = alpha_m;
  der(theta_m) = omega_m;

  // Supply flow magnitude tracks valve command (pressure-compensated valve)
  Q_supply = abs(Q_cmd);

  // ===== Control law: feedforward flow + pressure-position feedback =====
  Q_ff  = d_m * (gear/R_table) * v_ref / eta_v;
  e_x   = x_ref - x;
  Q_pos = Kp_x*e_x + Kd_x*(v_ref - v);
  Q_p   = -Kp_p * dp;
  Q_cmd_raw = Q_ff + Q_pos + Q_p;
  Q_cmd = max(-Q_lim, min(Q_lim, Q_cmd_raw));

  // ===== Bound indicators =====
  bound_travel   = if abs(x) <= bound_travel_max then 1.0 else 0.0;
  bound_pressure = if (p_a <= bound_p_max and p_b <= bound_p_max) then 1.0 else 0.0;
  bound_flow     = if abs(Q_cmd) <= Q_lim + 1.0e-12 then 1.0 else 0.0;
  bound_accel    = if abs(a) <= bound_accel_max then 1.0 else 0.0;
  bound_traj     = if time < 5.2 then 1.0 elseif abs(e_x) <= bound_traj_max then 1.0 else 0.0;
  bound_relief   = if (Q_relief_a < 1.0e-9 and Q_relief_b < 1.0e-9) then 1.0 else 0.0;

  annotation (
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="HydMotorTrackA: 80 Hz output (Interval=0.0125 s) over 8 s. Assumed (not specified): table radius R_table, motor inertia J_motor, viscous friction coefficients, oil bulk modulus, chamber volume, leakage coefficient, supply/tank/relief pressures, relief conductance, control gains, and mechanical efficiency eta_mech=1.0."));
end HydMotorTrackA;