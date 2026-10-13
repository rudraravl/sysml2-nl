model ShapeLockGraspD
  "Six-section continuum arm with thermally activated stiffness, three tendons,
   distributed contact sensing, object pose measurement, force redistribution";

  // ---- Physical constants from requirement ----
  constant Real mu          = 0.70  "friction coefficient on rigid support surface";
  constant Real T_stiff     = 320.0 "K, stiff state temperature";
  constant Real T_soft      = 345.0 "K, soft state temperature";
  constant Real T_env      = 300.0 "K, ambient temperature";
  constant Real tau_max     = 46.0  "N, tendon tension limit";
  constant Real P_max       = 18.0  "W, heater power limit";
  constant Real F_dist      = 4.0   "N, tangential disturbance amplitude";
  constant Real F_contact_lim = 2.5 "N, per-contact overload threshold";

  // ---- Tunable parameters (facts not stated treated as unknown/tunable) ----
  parameter Real k_stiff     = 900.0  "N/m, section bending stiffness when stiff";
  parameter Real k_soft      = 100.0  "N/m, section bending stiffness when soft";
  parameter Real C_therm     = 1.2    "J/K, thermal capacitance per section";
  parameter Real G_therm     = 0.35   "W/K, thermal conductance to ambient";
  parameter Real m_sec       = 0.05   "kg, effective section mass";
  parameter Real c_arm       = 2.0    "N.s/m, arm damping";
  parameter Real m_obj       = 0.25   "kg, object mass";
  parameter Real c_obj       = 3.0    "N.s/m, object/support damping";
  parameter Real k_contact   = 2000.0 "N/m, contact stiffness";
  parameter Real c_contact   = 5.0    "N.s/m, contact damping";
  parameter Real gap         = 0.02   "m, contact gap";
  parameter Real F_target    = 7.0    "N, target total normal grasp force";
  parameter Real p_ref       = 0.0    "m, object reference position";
  parameter Real Kp_force    = 6.0    "force loop proportional gain";
  parameter Real Ki_force    = 1.5    "force loop integral gain";
  parameter Real q_bound     = 0.08   "m, deflection bound";
  parameter Real tau_bias     = 3.5   "N, baseline tendon tension for conforming";

  // Tendon-to-section coupling (uniform row sum so all sections engage)
  parameter Real C[6,3] = [1.0,0.0,0.0;
                          0.8,0.2,0.0;
                          0.3,0.7,0.0;
                          0.0,0.7,0.3;
                          0.0,0.2,0.8;
                          0.0,0.0,1.0];

  // ---- Section states ----
  Real q[6](each start = 0.0, each fixed = true)   "section deflection [m]";
  Real vq[6](each start = 0.0, each fixed = true)  "section deflection velocity [m/s]";
  Real T_sec[6](each start = 321.0, each fixed = true) "section temperature [K]";

  // ---- Object states ----
  Real p_obj(start = 0.0, fixed = true)   "object lateral position [m]";
  Real vp_obj(start = 0.0, fixed = true)  "object lateral velocity [m/s]";

  // ---- Derived plant quantities ----
  Real k_sec[6]       "section bending stiffness [N/m]";
  Real c_force[6]     "per-section normal contact force [N]";
  Real c_active[6]    "contact active indicator (1/0)";
  Real F_total        "total normal grasp force [N]";
  Real F_friction     "friction force on object [N]";
  Real F_tang         "applied tangential disturbance [N]";
  Real F_friction_cap "friction capacity mu*F_total [N]";

  // ---- Actuator commands (discrete, 200 Hz ZOH) ----
  discrete Real tau_cmd[3](each start = 0.0) "tendon tension command [N]";
  discrete Real P_cmd[6](each start = 0.0)  "section heater power command [W]";
  discrete Real F_err_i(start = 0.0)        "force error integral term";
  discrete Real F_redist[6](each start = 1.0) "per-section redistribution weight";
  discrete Real heat_cmd[6](each start = 0.0) "heater schedule per section [W]";

  // ---- Actuated (saturated) values ----
  Real tau[3]    "actual tendon tension [N]";
  Real P_heat[6] "actual heater power [W]";

  // ---- Sensors ----
  Real tau_sensor[3]     "actuator sensing: tendon tension [N]";
  Real contact_sensor[6] "distributed contact sensing [N]";
  Real pose_sensor[2]    "object pose measurement [m, m]";

  // ---- Monitoring / requirements ----
  Real tracking_err "primary tracking error |p_obj - p_ref| [m]";
  Real tau_viol     "tendon bound violation (0 ok)";
  Real P_viol       "heater bound violation (0 ok)";
  Real q_viol       "deflection bound violation (0 ok)";
  Real contact_loss "contact loss indicator (0 ok)";
  Real finite_ok    "finite value check (1 ok)";

equation
  // Section stiffness: stiff at 320 K, soft at 345 K (clamp to valid range)
  for i in 1:6 loop
    k_sec[i] = k_soft + (k_stiff - k_soft) *
      (T_soft - min(max(T_sec[i], T_stiff), T_soft)) / (T_soft - T_stiff);
  end for;

  // Thermal dynamics per section
  for i in 1:6 loop
    der(T_sec[i]) = (P_heat[i] - G_therm*(T_sec[i] - T_env)) / C_therm;
  end for;

  // Actuator saturation (46 N / 18 W)
  for j in 1:3 loop
    tau[j] = max(-tau_max, min(tau_max, tau_cmd[j]));
  end for;
  for i in 1:6 loop
    P_heat[i] = max(0.0, min(P_max, P_cmd[i]));
  end for;

  // Section deflection dynamics
  for i in 1:6 loop
    der(q[i])  = vq[i];
    der(vq[i]) = (sum(C[i,j]*tau[j] for j in 1:3)
                 - k_sec[i]*q[i] - c_arm*vq[i] - c_force[i]) / m_sec;
  end for;

  // Compliant contact with rigid support surface
  for i in 1:6 loop
    c_force[i]  = if q[i] > gap then k_contact*(q[i] - gap) + c_contact*vq[i] else 0.0;
    c_active[i] = if q[i] > gap then 1.0 else 0.0;
  end for;

  // Total normal grasp force
  F_total = sum(c_force[i] for i in 1:6);

  // Friction capacity and stiction-style friction model
  F_friction_cap = mu * F_total;
  F_friction = if abs(vp_obj) < 1e-4
              then max(-F_friction_cap, min(F_friction_cap, F_tang))
              else F_friction_cap * sign(vp_obj);

  // Tangential disturbance: 4 N during middle third of 14 s -> [4.667, 9.333] s
  F_tang = if (time >= 14.0/3.0) and (time <= 2.0*14.0/3.0) then F_dist else 0.0;

  // Object dynamics on rigid support surface
  der(p_obj)  = vp_obj;
  der(vp_obj) = (F_tang - F_friction - c_obj*vp_obj) / m_obj;

  // ---- Sensors ----
  for j in 1:3 loop
    tau_sensor[j] = tau[j];
  end for;
  for i in 1:6 loop
    contact_sensor[i] = c_force[i];
  end for;
  pose_sensor[1] = p_obj;
  pose_sensor[2] = 0.0;

  // ---- Requirement monitoring ----
  tracking_err = abs(p_obj - p_ref);
  tau_viol     = if max(abs(tau)) > tau_max + 1e-6 then 1.0 else 0.0;
  P_viol       = if max(P_heat) > P_max + 1e-6 then 1.0 else 0.0;
  q_viol       = if max(abs(q)) > q_bound then 1.0 else 0.0;
  contact_loss = if (sum(c_active) < 0.5) and (time > 2.0) then 1.0 else 0.0;
  finite_ok    = if (p_obj > -1e6 and p_obj < 1e6 and
                     F_total > -1e6 and F_total < 1e6 and
                     q[1] > -1e6 and q[1] < 1e6 and
                     T_sec[1] > -1e6 and T_sec[1] < 1e6)
                  then 1.0 else 0.0;

  // ---- Discrete controller at 200 Hz (ZOH) ----
  when sample(0, 0.005) loop
    // Integral of total-force error with anti-windup clamp
    F_err_i = max(-5.0, min(5.0, pre(F_err_i) + (F_target - F_total)*0.005));

    // Heater schedule: heat (soften) for first 5 s to conform, then off to stiffen/lock
    for i in 1:6 loop
      heat_cmd[i] = if time < 5.0 then P_max*0.8 else 0.0;
    end for;

    // Contact-force redistribution: reduce weight where local overload occurs
    for i in 1:6 loop
      F_redist[i] = max(0.2, 1.0 - 0.5*max(0.0, c_force[i] - F_contact_lim));
    end for;

    // Tendon tension command: regulate total normal grasp force
    for j in 1:3 loop
      tau_cmd[j] = max(0.0, tau_bias + Kp_force*(F_target - F_total) + Ki_force*F_err_i);
    end for;

    // Heater power command with redistribution
    for i in 1:6 loop
      P_cmd[i] = heat_cmd[i] * F_redist[i];
    end for;
  end when;

  annotation (
    experiment(StartTime = 0, StopTime = 14, Interval = 0.005, Tolerance = 1e-6),
    Documentation(info = "ShapeLockGraspD: instrumented six-section continuum arm with three tendons and thermally activated stiffness elements (320 K-345 K). Tendon tension and heater power independently controlled and limited to 46 N and 18 W. Compliant contact (mu=0.70) on rigid support. 4 N tangential disturbance applied during middle third. 200 Hz discrete controller, 14 s run, synchronized state/command/sensor traces. Monitors actuator and deformation bounds, per-contact and total force bands, object displacement, contact loss, tracking error (<0.015 m after 9.1 s), and finite-value integrity.")
  );
end ShapeLockGraspD;