model HydCylinderPositionE
  // Verifiable hydraulic robotic actuator: move to 70% stroke and hold.
  // Values not stated in the requirement are declared parameters with
  // clearly labeled engineering assumptions (no values copied from examples).

  // --- Cylinder geometry / load ---
  parameter Real A_p        = 0.0040 "Piston (cap-end) area [m2]";
  parameter Real A_a        = 0.0032 "Rod-side effective (annular) area [m2] (assumed: 'rod area' = rod-side effective area)";
  parameter Real L_stroke   = 0.50   "Stroke [m]";
  parameter Real m_load     = 110.0  "Moving mass [kg]";
  parameter Real Vd         = 1.0e-4 "Dead volume per chamber [m3] (assumed)";

  // --- Fluid / supply ---
  parameter Real Ps    = 10.0e6 "Supply pressure [Pa] (declared, value assumed)";
  parameter Real Pt    = 1.0e5  "Return/tank pressure [Pa] (declared, value assumed)";
  parameter Real Beta  = 1.6e9  "Fluid bulk modulus [Pa] (declared, value assumed)";
  parameter Real C_leak= 1.0e-12 "Internal leakage coefficient [m3/(s.Pa)] (declared, value assumed)";

  // --- Valve ---
  parameter Real Q_max = 0.001 "Valve command magnitude bound [m3/s]";

  // --- Mechanical extras ---
  parameter Real k_stop = 1.0e7 "End-stop stiffness [N/m] (assumed)";
  parameter Real c_stop = 1.0e4 "End-stop damping [N.s/m] (assumed)";
  parameter Real b_visc = 500.0 "Viscous friction [N.s/m] (assumed)";
  parameter Real F_coul = 20.0  "Coulomb friction [N] (assumed)";

  // --- Control / scenario ---
  parameter Real Ts           = 1.0/250.0 "Controller sample period [s]";
  parameter Real T_sim         = 16.0     "Scenario duration [s]";
  parameter Real x_ref         = 0.70*L_stroke "Target = 70% travel [m]";
  parameter Real T_dist_start  = T_sim/3.0     "Disturbance window start [s]";
  parameter Real T_dist_end    = 2.0*T_sim/3.0 "Disturbance window end [s]";
  parameter Real F_dist        = 120.0   "External disturbance load [N]";
  parameter Real Kp = 0.0020  "Proportional gain [(m3/s)/m] (assumed)";
  parameter Real Ki = 0.020   "Integral gain [(m3/s)/(m.s)] (assumed)";
  parameter Real Kd = 0.00050 "Derivative gain [(m3/s)/(m/s)] (assumed)";

  // --- Continuous states ---
  Real x(start=0.0, fixed=true)  "Piston position [m]";
  Real v(start=0.0, fixed=true)  "Piston velocity [m/s]";
  Real P1(start=1.0e6, fixed=true) "Cap-end chamber pressure [Pa]";
  Real P2(start=1.0e6, fixed=true) "Rod-end chamber pressure [Pa]";

  // --- Derived quantities ---
  Real V1 "Cap-end volume [m3]";
  Real V2 "Rod-end volume [m3]";
  Real Q1 "Flow into cap end [m3/s]";
  Real Q2 "Flow into rod end [m3/s]";
  Real F_hydraulic "Net hydraulic force [N]";
  Real F_endstop   "End-stop force [N]";
  Real F_ext       "External load [N]";
  Real F_fric      "Friction force [N]";
  Real e           "Position error (ref - x) [m]";
  Real e_track     "|tracking error| [m]";

  // --- Discrete controller states ---
  discrete Real valve_cmd(start=0.0) "Valve command [m3/s], bounded by Q_max";
  discrete Real xi(start=0.0)         "Integral state";
  discrete Real e_prev(start=0.0)    "Previous sample error [m]";

  // --- Sensor traces (synchronized) ---
  Real x_sensor            "Measured position [m]";
  Real v_sensor            "Measured velocity [m/s]";
  Real P1_sensor           "Measured cap-end pressure [Pa]";
  Real P2_sensor           "Measured rod-end pressure [Pa]";
  Real valve_cmd_sensor    "Measured valve command [m3/s]";

protected
  Real dP_ref    = Ps - Pt;
  Real sqrtRef   = sqrt(max(dP_ref, 1.0));
  Real sqrtPsP1  = sqrt(max(Ps - P1, 0.0));
  Real sqrtP1Pt  = sqrt(max(P1 - Pt, 0.0));
  Real sqrtP2Pt  = sqrt(max(P2 - Pt, 0.0));
  Real sqrtPsP2  = sqrt(max(Ps - P2, 0.0));
  Real sgn_v     = if v > 0.001 then 1.0 else (if v < -0.001 then -1.0 else v/0.001);

equation
  // Chamber volumes
  V1 = Vd + A_p * x;
  V2 = Vd + A_a * (L_stroke - x);

  // Pressure-aware four-way proportional valve (orifice flow normalized to
  // Q_max at the reference pressure drop dP_ref = Ps - Pt).
  // Extending (valve_cmd > 0): cap end fed from supply, rod end to tank.
  // Retracting (valve_cmd < 0): cap end to tank, rod end fed from supply.
  Q1 = if valve_cmd >= 0.0 then
         valve_cmd * (sqrtPsP1 / sqrtRef)
       else
        -abs(valve_cmd) * (sqrtP1Pt / sqrtRef);
  Q2 = if valve_cmd >= 0.0 then
        -abs(valve_cmd) * (sqrtP2Pt / sqrtRef)
       else
         abs(valve_cmd) * (sqrtPsP2 / sqrtRef);

  // Compressible chamber dynamics with internal leakage
  der(P1) = (Beta / V1) * (Q1 - A_p * v - C_leak * (P1 - P2));
  der(P2) = (Beta / V2) * (Q2 + A_a * v + C_leak * (P1 - P2));

  // Hydraulic force
  F_hydraulic = A_p * P1 - A_a * P2;

  // External disturbance in middle third of run, opposing positive motion
  F_ext = if (time >= T_dist_start and time <= T_dist_end) then F_dist else 0.0;

  // Friction (viscous + smoothed Coulomb)
  F_fric = b_visc * v + F_coul * sgn_v;

  // Mechanical end stops
  F_endstop = (if x < 0.0       then k_stop * (0.0 - x)     else 0.0)
           - (if x > L_stroke  then k_stop * (x - L_stroke) else 0.0)
           - (if x < 0.0 or x > L_stroke then c_stop * v else 0.0);

  // Mechanics
  der(x) = v;
  m_load * der(v) = F_hydraulic - F_fric - F_ext + F_endstop;

  // Position error
  e = x_ref - x;
  e_track = abs(e);

  // Discrete PID at 250 Hz with anti-windup
  when sample(0, Ts) loop
    if abs(pre(valve_cmd)) >= 0.999 * Q_max then
      xi = pre(xi);
    else
      xi = pre(xi) + Ts * e;
    end if;
    valve_cmd = max(-Q_max, min(Q_max,
                     Kp * e + Ki * xi + Kd * (e - pre(e_prev)) / Ts));
    e_prev = e;
  end when;

  // Synchronized sensor traces
  x_sensor         = x;
  v_sensor         = v;
  P1_sensor        = P1;
  P2_sensor        = P2;
  valve_cmd_sensor = valve_cmd;

  // ----- Fail-closed acceptance bounds -----
  assert(x >= -1.0e-4 and x <= L_stroke + 1.0e-4, "travel bound violated");
  assert(abs(v) <= 5.0, "velocity bound violated");
  assert(P1 > 0.0 and P1 < 2.0 * Ps, "P1 pressure bound violated");
  assert(P2 > 0.0 and P2 < 2.0 * Ps, "P2 pressure bound violated");
  assert(abs(valve_cmd) <= Q_max + 1.0e-9, "valve command bound violated");
  assert(time < 10.4 or abs(x - x_ref) < 0.011,
         "primary tracking error bound (>0.011 m after 10.4 s) violated");
  assert(x == x and v == v and P1 == P1 and P2 == P2
         and valve_cmd == valve_cmd and e == e,
         "NaN detected in physical, control, or estimator value");
  assert(P1 < 1.0e9 and P2 < 1.0e9, "infinite pressure detected");

end HydCylinderPositionE;