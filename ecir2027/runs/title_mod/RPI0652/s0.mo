model PneuGripPositionD
  // ---- Physical embodiment parameters (declared, not invented) ----
  parameter Real stroke    = 0.035   "m gripper travel";
  parameter Real A_piston  = 0.0012  "m2 piston area (each cylinder)";
  parameter Real m_finger  = 0.8     "kg each gripper finger";
  parameter Real m_total   = 2.0*m_finger "kg total moving mass";
  parameter Real Ps        = 6.0e5   "Pa declared supply pressure";
  parameter Real Pr        = 1.0e5   "Pa declared return pressure";
  parameter Real m_max     = 0.001   "kg/s valve mass-flow limit";
  parameter Real gamma_air = 1.4     "specific heat ratio (air)";
  parameter Real R_air     = 287.0   "J/kg/K gas constant (air)";
  parameter Real T_air     = 293.15  "K chamber temperature";
  parameter Real V_dead   = 1.0e-6  "m3 dead volume each chamber";
  parameter Real b_visc   = 80.0    "N.s/m viscous damping";
  parameter Real k_leak   = 5.0e-12 "kg/s/Pa leakage conductance";
  parameter Real k_stop   = 5.0e5   "N/m end-stop stiffness";
  parameter Real c_stop   = 5.0e2   "N.s/m end-stop damping";
  parameter Real x_target = 0.7*stroke "m setpoint = 70% travel";

  // ---- Disturbance schedule (middle third of 14 s) ----
  parameter Real F_load       = 100.0     "N external load";
  parameter Real t_load_start = 14.0/3.0  "s middle-third start";
  parameter Real t_load_end   = 2.0*14.0/3.0 "s middle-third end";

  // ---- Controller tuning ----
  parameter Real dt  = 1.0/200.0 "s controller sample period (200 Hz)";
  parameter Real Kp  = 3.0e4 "N/m position proportional gain";
  parameter Real Ki  = 5.0e3 "N/(m.s) position integral gain";
  parameter Real Kd  = 300.0 "N.s/m position derivative gain";

  // ---- Continuous physical states ----
  Real x(start = 0.0, fixed = true) "gripper position m";
  Real v(start = 0.0, fixed = true) "gripper velocity m/s";
  Real P_a(start = Pr, fixed = true) "chamber A pressure Pa";
  Real P_b(start = Pr, fixed = true) "chamber B pressure Pa";

  // ---- Discrete controller / estimator states ----
  discrete Real integ(start = 0.0)        "integral accumulator";
  discrete Real last_err(start = x_target) "previous sampled error m";
  discrete Real u_cmd(start = 0.0)        "valve command [-1,1]";
  discrete Real err_d(start = 0.0)        "sampled position error m";
  discrete Real err_dot_d(start = 0.0)   "sampled error derivative m/s";
  discrete Real F_des(start = 0.0)        "desired actuator force N";
  discrete Real raw_u(start = 0.0)        "unsaturated valve command";

  // ---- Sensor / observable traces ----
  Real V_a, V_b            "chamber volumes m3";
  Real m_dot_a, m_dot_b    "chamber net mass flow kg/s";
  Real F_drive             "actuator force N";
  Real F_friction          "viscous friction force N";
  Real F_stop              "end-stop reaction force N";
  Real F_load_dist         "applied disturbance force N";
  Real P_diff              "chamber pressure differential Pa";
  Real tracking_error      "|x - x_target| m";
  Boolean in_load_zone     "true during middle-third load";

equation
  // Chamber volumes (compressibility via V in dP/dt)
  V_a = V_dead + A_piston * x;
  V_b = V_dead + A_piston * (stroke - x);

  // Pressure differential sensor
  P_diff = P_a - P_b;

  // Proportional valve flow with supply/return saturation guards + leakage
  m_dot_a = (if (u_cmd > 0.0 and P_a >= Ps - 1.0e3) then 0.0
             elseif (u_cmd < 0.0 and P_a <= Pr + 1.0e3) then 0.0
             else u_cmd * m_max)
            - k_leak * (P_a - Pr);
  m_dot_b = (if (u_cmd < 0.0 and P_b >= Ps - 1.0e3) then 0.0
             elseif (u_cmd > 0.0 and P_b <= Pr + 1.0e3) then 0.0
             else -u_cmd * m_max)
            - k_leak * (P_b - Pr);

  // Compressible (isentropic) chamber pressure dynamics
  der(P_a) = (gamma_air * R_air * T_air / V_a) * m_dot_a
             - (gamma_air * P_a / V_a) * A_piston * v;
  der(P_b) = (gamma_air * R_air * T_air / V_b) * m_dot_b
             + (gamma_air * P_b / V_b) * A_piston * v;

  // Disturbance (middle third of the 14 s run)
  in_load_zone = (time >= t_load_start) and (time <= t_load_end);
  F_load_dist = if in_load_zone then F_load else 0.0;

  // Mechanical end stops (with damping) at x=0 and x=stroke
  F_stop = (if x < 0.0 then k_stop * x - c_stop * v
            else if x > stroke then k_stop * (x - stroke) - c_stop * v
            else 0.0);

  F_drive    = A_piston * (P_a - P_b);
  F_friction = b_visc * v;

  // Mechanical equation of motion
  der(x) = v;
  m_total * der(v) = F_drive - F_friction - F_load_dist + F_stop;

  // Primary tracking error metric
  tracking_error = abs(x - x_target);

  // ---- Discrete pressure-aware PID at 200 Hz ----
  when sample(0, dt) then
    err_d     = x_target - x;
    err_dot_d = (err_d - pre(last_err)) / dt;
    last_err  = err_d;
    F_des     = Kp * err_d + Ki * pre(integ) + Kd * err_dot_d;
    // Pressure-aware: valve command from desired-vs-actual pressure diff,
    // normalized by maximum available pressure differential force.
    raw_u  = (F_des - A_piston * (P_a - P_b)) / (A_piston * (Ps - Pr));
    u_cmd  = max(-1.0, min(1.0, raw_u));
    // Conditional anti-windup: hold integral when saturating same direction
    integ  = if (raw_u > 1.0 and err_d > 0.0) or (raw_u < -1.0 and err_d < 0.0)
              then pre(integ)
              else pre(integ) + err_d * dt;
  end when;

  annotation(
    experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 1.0/200.0),
    Documentation(info = "PneuGripPositionD: instrumented two-cylinder pneumatic gripper position control. Two opposing 0.8 kg fingers (1.6 kg total) driven by chambers of 0.0012 m2 piston area over 0.035 m travel. Two proportional air valves (<=0.001 kg/s) with declared supply 6e5 Pa and return 1e5 Pa. Compressible isentropic chamber dynamics, leakage to return, mechanical end stops. Pressure-aware PID at 200 Hz commands motion to 70% travel (0.0245 m) and holds. 100 N external load applied during middle third (4.667-9.333 s). Sensor traces: position x, velocity v, chamber pressures P_a/P_b, valve command u_cmd."));
end PneuGripPositionD;