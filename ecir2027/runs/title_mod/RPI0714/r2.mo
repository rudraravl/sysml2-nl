model AirStageTrackF
  // ===== Physical parameters =====
  parameter Real m_carriage = 42.0 "carriage mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real L = 0.70 "cylinder stroke [m]";
  parameter Real A1 = 0.0050 "cap-side piston area [m2]";
  parameter Real A2 = 0.0030 "rod-side piston area [m2]";
  parameter Real V1dead = 0.0005 "cap-side dead volume [m3]";
  parameter Real V2dead = 0.0005 "rod-side dead volume [m3]";
  parameter Real b_visc = 500.0 "viscous friction coefficient [N.s/m]";
  parameter Real R_air = 287.0 "specific gas constant [J/(kg.K)]";
  parameter Real T_air = 293.0 "air temperature [K]";
  parameter Real n_poly = 1.2 "polytropic index [-]";
  parameter Real p_supply = 7.0e5 "supply pressure [Pa]";
  parameter Real p_atm = 1.013e5 "atmospheric pressure [Pa]";
  parameter Real mdot_max = 0.018 "max valve mass flow [kg/s]";
  parameter Real k_leak = 1.0e-10 "leakage conductance [kg/(s.Pa)]";
  parameter Real p1_nom = 3.0e5 "nominal cap pressure [Pa]";
  parameter Real p2_nom = (p1_nom*A1 - m_carriage*g)/A2 "nominal rod pressure [Pa]";

  // ===== Controller gains =====
  parameter Real Kp_x = 30000.0 "position feedback gain [N/m]";
  parameter Real Kd_x = 2000.0 "velocity feedback gain [N.s/m]";
  parameter Real tau_p = 0.03 "pressure tracking time constant [s]";

  // ===== States =====
  Real x(start=0.0, fixed=true) "carriage position [m]";
  Real v(start=0.0, fixed=true) "carriage velocity [m/s]";
  Real p1(start=p1_nom) "cap-side pressure [Pa]";
  Real p2(start=p2_nom) "rod-side pressure [Pa]";

  // ===== Trajectory =====
  Real x_des "desired position [m]";
  Real v_des "desired velocity [m/s]";
  Real a_des "desired acceleration [m/s2]";

  // ===== Disturbance =====
  Real F_payload "payload disturbance force [N]";

  // ===== Chamber volumes =====
  Real V1 "cap-side volume [m3]";
  Real V2 "rod-side volume [m3]";

  // ===== Leakage =====
  Real mdot_leak "leakage from chamber1 to chamber2 [kg/s]";

  // ===== Control / valve commands =====
  Real F_des "desired incremental force [N]";
  Real p1_cmd "cap pressure command [Pa]";
  Real p2_cmd "rod pressure command [Pa]";
  Real mdot1_raw "raw commanded flow into chamber1 [kg/s]";
  Real mdot2_raw "raw commanded flow into chamber2 [kg/s]";
  Real u1_fill "fill valve cmd chamber1 [0..1]";
  Real u1_exh  "exhaust valve cmd chamber1 [0..1]";
  Real u2_fill "fill valve cmd chamber2 [0..1]";
  Real u2_exh  "exhaust valve cmd chamber2 [0..1]";
  Real mdot1_valve "net valve flow chamber1 [kg/s]";
  Real mdot2_valve "net valve flow chamber2 [kg/s]";
  Real mdot1 "net mass flow into chamber1 [kg/s]";
  Real mdot2 "net mass flow into chamber2 [kg/s]";
  Real mdot_supply "total supply flow [kg/s]";
  Real command "aggregate valve command [-]";

  // ===== Observation =====
  Real a "actual acceleration [m/s2]";
  Real e_track "tracking error [m]";

  // ===== Trajectory helpers =====
  Real s1, s2;

  function smoothstep
    input Real t;
    input Real t0;
    input Real t1;
    output Real s;
  algorithm
    if t <= t0 then
      s := 0.0;
    elseif t >= t1 then
      s := 1.0;
    else
      s := 0.5*(1.0 - Modelica.Math.cos(Modelica.Constants.pi*(t - t0)/(t1 - t0)));
    end if;
  end smoothstep;

  function smoothstep_d
    input Real t;
    input Real t0;
    input Real t1;
    output Real ds;
  algorithm
    if t <= t0 or t >= t1 then
      ds := 0.0;
    else
      ds := 0.5*Modelica.Constants.pi/(t1 - t0)*Modelica.Math.sin(Modelica.Constants.pi*(t - t0)/(t1 - t0));
    end if;
  end smoothstep_d;

  function smoothstep_dd
    input Real t;
    input Real t0;
    input Real t1;
    output Real dds;
  algorithm
    if t <= t0 or t >= t1 then
      dds := 0.0;
    else
      dds := 0.5*Modelica.Constants.pi*Modelica.Constants.pi/((t1 - t0)*(t1 - t0))*Modelica.Math.cos(Modelica.Constants.pi*(t - t0)/(t1 - t0));
    end if;
  end smoothstep_dd;

  function clamp01
    input Real x;
    output Real y;
  algorithm
    if x < 0.0 then
      y := 0.0;
    elseif x > 1.0 then
      y := 1.0;
    else
      y := x;
    end if;
  end clamp01;

equation
  // ===== Two-segment smooth trajectory =====
  // Segment 1: 0 -> 0.35 m during [1, 8] s
  // Segment 2: 0.35 -> 0.70 m during [10, 18] s
  s1 = smoothstep(time, 1.0, 8.0);
  s2 = smoothstep(time, 10.0, 18.0);
  x_des = 0.35*s1 + 0.35*s2;
  v_des = 0.35*smoothstep_d(time, 1.0, 8.0) + 0.35*smoothstep_d(time, 10.0, 18.0);
  a_des = 0.35*smoothstep_dd(time, 1.0, 8.0) + 0.35*smoothstep_dd(time, 10.0, 18.0);

  // ===== Payload disturbance: 319 N during middle third of 20 s =====
  if time >= 20.0/3.0 and time <= 40.0/3.0 then
    F_payload = 319.0;
  else
    F_payload = 0.0;
  end if;

  // ===== Chamber volumes =====
  V1 = V1dead + A1*x;
  V2 = V2dead + A2*(L - x);

  // ===== Leakage between chambers =====
  mdot_leak = k_leak*(p1 - p2);

  // ===== Force / pressure commands (nominal pressures carry gravity) =====
  F_des = m_carriage*a_des + b_visc*v_des
          + Kp_x*(x_des - x) + Kd_x*(v_des - v);
  p1_cmd = p1_nom + F_des/(2.0*A1);
  p2_cmd = p2_nom - F_des/(2.0*A2);

  // ===== Feedforward + pressure feedback flow commands =====
  mdot1_raw = (p1/(n_poly*R_air*T_air))*A1*v_des
            + (V1/(n_poly*R_air*T_air))*(p1_cmd - p1)/tau_p;
  mdot2_raw = -(p2/(n_poly*R_air*T_air))*A2*v_des
            + (V2/(n_poly*R_air*T_air))*(p2_cmd - p2)/tau_p;

  // ===== Split into fill/exhaust valve commands =====
  u1_fill = clamp01(mdot1_raw/mdot_max);
  u1_exh  = clamp01(-mdot1_raw/mdot_max);
  u2_fill = clamp01(mdot2_raw/mdot_max);
  u2_exh  = clamp01(-mdot2_raw/mdot_max);

  // ===== Valve flows (pressure-gated, supply/atm relief behavior) =====
  mdot1_valve = u1_fill*mdot_max*(if p1 < p_supply then 1.0 else 0.0)
              - u1_exh*mdot_max*(if p1 > p_atm then 1.0 else 0.0);
  mdot2_valve = u2_fill*mdot_max*(if p2 < p_supply then 1.0 else 0.0)
              - u2_exh*mdot_max*(if p2 > p_atm then 1.0 else 0.0);

  mdot1 = mdot1_valve - mdot_leak;
  mdot2 = mdot2_valve + mdot_leak;

  // Supply flow = sum of all fill flows
  mdot_supply = u1_fill*mdot_max*(if p1 < p_supply then 1.0 else 0.0)
              + u2_fill*mdot_max*(if p2 < p_supply then 1.0 else 0.0);

  command = u1_fill + u1_exh + u2_fill + u2_exh;

  // ===== Pressure dynamics (polytropic) =====
  der(p1) = (n_poly*R_air*T_air/V1)*mdot1 - (n_poly*p1/V1)*A1*v;
  der(p2) = (n_poly*R_air*T_air/V2)*mdot2 + (n_poly*p2/V2)*A2*v;

  // ===== Mechanical dynamics =====
  a = (p1*A1 - p2*A2 - m_carriage*g - b_visc*v - F_payload)/m_carriage;
  der(x) = v;
  der(v) = a;

  e_track = x_des - x;

  // ===== Verification bounds =====
  assert(x >= -0.01 and x <= L + 0.01, "travel bound violated");
  assert(p1 >= 0.0 and p1 <= p_supply + 1.0e5, "cap pressure bound violated");
  assert(p2 >= 0.0 and p2 <= p_supply + 1.0e5, "rod pressure bound violated");
  assert(abs(mdot_supply) <= 2.0*mdot_max + 1.0e-9, "supply flow bound violated");
  assert(abs(a) <= 50.0, "acceleration bound violated");
  assert(abs(e_track) <= 0.10, "trajectory error bound violated");
  // Primary tracking error after 13 s
  if time >= 13.0 then
    assert(abs(e_track) <= 0.014, "primary tracking error > 0.014 m after 13 s");
  end if;
  // Finite-state guard (no NaN / infinite physical, control, or estimator values)
  assert(p1 > -1.0e8 and p1 < 1.0e8, "non-finite cap pressure");
  assert(p2 > -1.0e8 and p2 < 1.0e8, "non-finite rod pressure");
  assert(x > -1.0e6 and x < 1.0e6, "non-finite position");
  assert(v > -1.0e6 and v < 1.0e6, "non-finite velocity");

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="AirStageTrackF: vertical pneumatic carriage (42 kg, 0.70 m stroke) tracking a two-segment smooth trajectory under a 319 N payload step applied during the middle third of the 20 s mission. Feedforward flow control with pressure-position feedback; viscous friction, inter-chamber leakage, unequal chamber areas and explicit dead volumes modeled. Sampled at 500 Hz."));
end AirStageTrackF;