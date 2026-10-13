model PneuGripForceC
  // Physical and system parameters
  parameter Modelica.Units.SI.Area A_piston = 0.0012 "Piston area";
  parameter Modelica.Units.SI.Length stroke = 0.035 "Cylinder travel";
  parameter Modelica.Units.SI.Mass m_finger = 0.8 "Gripper finger mass";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_spring = 3000 "Return spring (fixed support)";
  parameter Modelica.Units.SI.TranslationalDampingConstant d_finger = 60 "Finger damping";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_contact = 100000 "Contact stiffness";
  parameter Modelica.Units.SI.TranslationalDampingConstant d_contact = 400 "Contact damping";
  parameter Modelica.Units.SI.Length g0 = 0.05 "Initial gap between fingers";
  parameter Modelica.Units.SI.Volume V_dead = 1.0e-5 "Chamber dead volume";
  parameter Modelica.Units.SI.SpecificHeatCapacity R_air = 287 "Ideal gas constant";
  parameter Modelica.Units.SI.Temperature T_air = 293.15 "Chamber temperature (isothermal)";
  parameter Modelica.Units.SI.Pressure p_supply = 700000 "Supply pressure (absolute)";
  parameter Modelica.Units.SI.Pressure p_atm = 101325 "Atmospheric / exhaust pressure";
  parameter Modelica.Units.SI.Pressure p_relief = 850000 "Relief threshold (absolute)";
  parameter Modelica.Units.SI.MassFlowRate m_dot_max = 0.001 "Proportional valve command limit";
  parameter Modelica.Units.SI.Force F_cmd = 60 "Commanded grip force";
  parameter Modelica.Units.SI.Force F_dist = 135 "Disturbance load change";
  parameter Real Kp_force(unit="1") = 0.5 "Outer force loop proportional gain";
  parameter Real Kp_pres(unit="kg/(s.Pa)") = 8.0e-9 "Inner pressure loop P gain";
  parameter Real Ki_pres(unit="kg/(s.Pa.s)") = 5.0e-9 "Inner pressure loop I gain";
  parameter Real sample_dt(unit="s") = 0.008 "Controller sample period (125 Hz)";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_stop = 2.0e6 "End-stop stiffness";
  parameter Modelica.Units.SI.TranslationalDampingConstant d_stop = 4000 "End-stop damping";
  parameter Real relief_gain(unit="kg/(s.Pa)") = 1.0e-7 "Relief valve conductance";
  parameter Real ie_clamp(unit="Pa.s") = 5.0e4 "Integrator anti-windup clamp";

  // Plant continuous states
  Modelica.Units.SI.Length x1(start=0.0) "Finger 1 position (toward contact)";
  Modelica.Units.SI.Length x2(start=0.0) "Finger 2 position (toward contact)";
  Modelica.Units.SI.Velocity v1(start=0.0) "Finger 1 velocity";
  Modelica.Units.SI.Velocity v2(start=0.0) "Finger 2 velocity";
  Modelica.Units.SI.Pressure p1(start=p_atm) "Chamber 1 absolute pressure";
  Modelica.Units.SI.Pressure p2(start=p_atm) "Chamber 2 absolute pressure";

  // Plant intermediates
  Modelica.Units.SI.Volume V1 "Chamber 1 volume";
  Modelica.Units.SI.Volume V2 "Chamber 2 volume";
  Modelica.Units.SI.Force F_contact "Measured contact force";
  Modelica.Units.SI.Force F_dist_applied "Disturbance load applied to fingers";
  Modelica.Units.SI.Force F_stop1 "End-stop force on finger 1";
  Modelica.Units.SI.Force F_stop2 "End-stop force on finger 2";
  Modelica.Units.SI.MassFlowRate mdot1 "Actual mass flow into chamber 1";
  Modelica.Units.SI.MassFlowRate mdot2 "Actual mass flow into chamber 2";
  Modelica.Units.SI.MassFlowRate mdot1_cmd_sat "Saturated command 1 minus relief";
  Modelica.Units.SI.MassFlowRate mdot2_cmd_sat "Saturated command 2 minus relief";
  Modelica.Units.SI.MassFlowRate relief1 "Relief vent flow 1";
  Modelica.Units.SI.MassFlowRate relief2 "Relief vent flow 2";
  Real delta12 "Finger overlap (contact penetration)";

  // Controller discrete variables
  discrete Modelica.Units.SI.Pressure p1_ref(start=p_atm) "Chamber 1 pressure reference";
  discrete Modelica.Units.SI.Pressure p2_ref(start=p_atm) "Chamber 2 pressure reference";
  discrete Modelica.Units.SI.MassFlowRate mdot1_cmd(start=0.0) "Raw valve command 1";
  discrete Modelica.Units.SI.MassFlowRate mdot2_cmd(start=0.0) "Raw valve command 2";
  discrete Real ie1(start=0.0) "Pressure integral 1";
  discrete Real ie2(start=0.0) "Pressure integral 2";
  discrete Modelica.Units.SI.Force F_meas_d(start=0.0) "Sampled contact force";
  discrete Modelica.Units.SI.Force F_err_d(start=F_cmd) "Sampled force error";
  discrete Modelica.Units.SI.Length x1_d(start=0.0) "Sampled finger 1 position";
  discrete Modelica.Units.SI.Length x2_d(start=0.0) "Sampled finger 2 position";
  discrete Modelica.Units.SI.Pressure p1_d(start=p_atm) "Sampled chamber 1 pressure";
  discrete Modelica.Units.SI.Pressure p2_d(start=p_atm) "Sampled chamber 2 pressure";

  // Tracked output signals (synchronized state/command/sensor traces)
  Modelica.Units.SI.Force F_err_tracked "Continuous force tracking error";
  Modelica.Units.SI.Pressure p1_gauge_tracked "Chamber 1 gauge pressure sensor";
  Modelica.Units.SI.Pressure p2_gauge_tracked "Chamber 2 gauge pressure sensor";
  Real mdot1_tracked(unit="kg/s") "Commanded mass flow 1 trace";
  Real mdot2_tracked(unit="kg/s") "Commanded mass flow 2 trace";

equation
  // Chamber volumes
  V1 = V_dead + A_piston*x1;
  V2 = V_dead + A_piston*x2;

  // Chamber pressure dynamics (isothermal ideal gas, compressible)
  der(p1) = (R_air*T_air/V1)*mdot1 - (p1/V1)*A_piston*v1;
  der(p2) = (R_air*T_air/V2)*mdot2 - (p2/V2)*A_piston*v2;

  // Relief protection (passive venting above relief threshold)
  relief1 = if p1 > p_relief then relief_gain*(p1 - p_relief) else 0.0;
  relief2 = if p2 > p_relief then relief_gain*(p2 - p_relief) else 0.0;

  // Saturated valve command with flow bound, minus relief flow
  mdot1_cmd_sat = max(-m_dot_max, min(m_dot_max, mdot1_cmd)) - relief1;
  mdot2_cmd_sat = max(-m_dot_max, min(m_dot_max, mdot2_cmd)) - relief2;

  // Supply limitation: cannot charge above supply, cannot exhaust below atmosphere
  mdot1 = if (p1 >= p_supply) and (mdot1_cmd_sat > 0.0) then 0.0
          elseif (p1 <= p_atm) and (mdot1_cmd_sat < 0.0) then 0.0
          else mdot1_cmd_sat;
  mdot2 = if (p2 >= p_supply) and (mdot2_cmd_sat > 0.0) then 0.0
          elseif (p2 <= p_atm) and (mdot2_cmd_sat < 0.0) then 0.0
          else mdot2_cmd_sat;

  // Compliant unilateral contact
  delta12 = x1 + x2 - g0;
  F_contact = if delta12 > 0.0 then
                max(0.0, k_contact*delta12 + d_contact*(v1 + v2))
              else 0.0;

  // Disturbance: 135 N load change applied during middle third (4 s to 8 s)
  F_dist_applied = if (time >= 4.0 and time <= 8.0) then F_dist else 0.0;

  // End-stop soft stops (prevent hard impact within [0, stroke])
  F_stop1 = if x1 > stroke then -k_stop*(x1 - stroke) - d_stop*v1
            elseif x1 < 0.0 then -k_stop*x1 - d_stop*v1
            else 0.0;
  F_stop2 = if x2 > stroke then -k_stop*(x2 - stroke) - d_stop*v2
            elseif x2 < 0.0 then -k_stop*x2 - d_stop*v2
            else 0.0;

  // Finger dynamics (fixed support via return spring, contact, disturbance)
  der(x1) = v1;
  der(x2) = v2;
  m_finger*der(v1) = p1*A_piston - k_spring*x1 - d_finger*v1
                     - F_contact - F_dist_applied + F_stop1;
  m_finger*der(v2) = p2*A_piston - k_spring*x2 - d_finger*v2
                     - F_contact - F_dist_applied + F_stop2;

  // Continuous trace signals
  F_err_tracked = F_cmd - F_contact;
  p1_gauge_tracked = p1 - p_atm;
  p2_gauge_tracked = p2 - p_atm;
  mdot1_tracked = mdot1;
  mdot2_tracked = mdot2;

  // Sampled cascaded controller: outer force loop -> pressure reference -> inner PI pressure loop -> valve command
  when sample(0.0, sample_dt) then
    // Sampled instrumentation: chamber pressures, actuator state, contact force
    x1_d = x1;
    x2_d = x2;
    p1_d = p1;
    p2_d = p2;
    F_meas_d = F_contact;
    F_err_d = F_cmd - F_meas_d;

    // Outer force loop with spring feed-forward generates chamber pressure references
    p1_ref = p_atm + (F_cmd + Kp_force*F_err_d + k_spring*x1_d)/A_piston;
    p2_ref = p_atm + (F_cmd + Kp_force*F_err_d + k_spring*x2_d)/A_piston;

    // Inner pressure loop (PI) with clamped anti-windup integrator
    ie1 = max(-ie_clamp, min(ie_clamp, pre(ie1) + (p1_ref - p1_d)*sample_dt));
    ie2 = max(-ie_clamp, min(ie_clamp, pre(ie2) + (p2_ref - p2_d)*sample_dt));
    mdot1_cmd = Kp_pres*(p1_ref - p1_d) + Ki_pres*ie1;
    mdot2_cmd = Kp_pres*(p2_ref - p2_d) + Ki_pres*ie2;
  end when;

  // Safety assertions: pressure/flow bounds, contact-force band, end-stop, no NaN/Inf
  assert(p1 > 0.0 and p1 < p_relief + 1.0e5, "Chamber 1 pressure out of bounds");
  assert(p2 > 0.0 and p2 < p_relief + 1.0e5, "Chamber 2 pressure out of bounds");
  assert(abs(mdot1) <= m_dot_max*1.5, "Mass flow 1 exceeds flow bound");
  assert(abs(mdot2) <= m_dot_max*1.5, "Mass flow 2 exceeds flow bound");
  assert(x1 >= -1.0e-4 and x1 <= stroke + 1.0e-4, "Finger 1 end-stop violation");
  assert(x2 >= -1.0e-4 and x2 <= stroke + 1.0e-4, "Finger 2 end-stop violation");
  assert(F_contact >= 0.0, "Contact force must remain non-negative (unilateral)");

annotation (
  experiment(StartTime=0.0, StopTime=12.0, Tolerance=1.0e-6, Interval=0.008),
  Documentation(info="PneuGripForceC: cascaded pressure/force regulation of two opposing pneumatic gripper fingers driving a compliant load. Plant: compressible chambers (isothermal ideal gas), proportional supply-limited valves with relief protection, mass-spring-damper fingers on fixed supports, unilateral compliant contact. Outer force loop and inner PI pressure loop sampled at 125 Hz. Disturbance 135 N applied during middle third (4-8 s). Primary tracking error required below 21 N after 7.8 s."));
end PneuGripForceC;