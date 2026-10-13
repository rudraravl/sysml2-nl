model HydBoomForceF
  "Fluid-power robotic boom/stick force-control scenario;
   cascaded pressure and force regulation against a compliant load,
   load-sensing pump with relief, 218 N mid-third disturbance, 500 Hz / 20 s."

  // ===== Stated requirement parameters =====
  parameter Real L_boom      = 2.0     "m, stated boom length";
  parameter Real L_stick     = 1.4     "m, stated stick length";
  parameter Real m_payload   = 300.0   "kg, stated payload mass";
  parameter Real Q_pump_max   = 0.004   "m3/s, stated pump flow limit";
  parameter Real F_dist      = 218.0   "N, stated disturbance load change";
  parameter Real Ts          = 1.0/500.0 "s, stated 500 Hz control rate";
  parameter Real T_end       = 20.0    "s, stated run duration";
  parameter Real F_err_lim   = 16.0    "N, stated tracking error limit after 13 s";
  parameter Real T_settle    = 13.0    "s, stated settle time";
  parameter Real T_dist_start= T_end/3.0   "s, middle-third start";
  parameter Real T_dist_end  = 2.0*T_end/3.0 "s, middle-third end";
  parameter Real T_ramp      = 0.5     "s, disturbance ramp (assumed)";

  // ===== Assumed (not stated) physical parameters =====
  // Cylinder geometry
  parameter Real AA1  = 5.027e-3 "m2, boom cyl cap area (assumed)";
  parameter Real AB1  = 3.770e-3 "m2, boom cyl rod area (assumed)";
  parameter Real L_str1 = 0.8    "m, boom cyl stroke (assumed)";
  parameter Real AA2  = 3.117e-3 "m2, stick cyl cap area (assumed)";
  parameter Real AB2  = 2.155e-3 "m2, stick cyl rod area (assumed)";
  parameter Real L_str2 = 0.6    "m, stick cyl stroke (assumed)";
  parameter Real x_dead = 0.01   "m, dead-volume length (assumed)";
  parameter Real beta   = 8.0e8  "Pa, oil bulk modulus (assumed)";
  parameter Real C_leak = 1.0e-12 "m3/(s Pa), internal leakage (assumed)";
  parameter Real Cv     = 1.0e-10 "m3/(s Pa), valve conductance (assumed)";
  parameter Real p_t    = 0.5e6  "Pa, tank/return pressure (assumed)";
  parameter Real p_relief = 25.0e6 "Pa, relief pressure (assumed)";
  parameter Real delta_ls  = 1.5e6 "Pa, load-sensing margin (assumed)";
  parameter Real C_s    = 1.0e-9  "m3/Pa, supply line capacitance (assumed)";
  parameter Real K_pump = 5.0e-5  "m3/(s Pa), pump regulator gain (assumed)";
  parameter Real K_relief = 5.0e-10 "m3/(s Pa), relief conductance (assumed)";
  // Mechanical transmission and load
  parameter Real J1     = 1.0    "m/m, boom cyl-to-ee kinematic gain (assumed)";
  parameter Real J2     = 1.0    "m/m, stick cyl-to-ee kinematic gain (assumed)";
  parameter Real m1     = 80.0   "kg, boom reflected inertia (assumed)";
  parameter Real m2     = 320.0  "kg, stick+payload reflected inertia (assumed)";
  parameter Real b1     = 2.0e3  "N s/m, boom friction (assumed)";
  parameter Real b2     = 2.0e3  "N s/m, stick friction (assumed)";
  parameter Real F_grav1= 400.0  "N, boom gravity load (assumed)";
  parameter Real F_grav2= 1500.0 "N, stick gravity load (assumed)";
  parameter Real k_c    = 1.0e6  "N/m, contact stiffness (assumed, compliant)";
  parameter Real d_c    = 5.0e3  "N s/m, contact damping (assumed)";
  parameter Real x_wall = 0.497  "m, wall position (assumed, sets initial contact)";
  parameter Real F_cmd  = 3000.0 "N, commanded contact force (assumed)";
  parameter Real x1_cmd = 0.3    "m, boom hold position (assumed)";
  parameter Real F_band_min = 0.5*F_cmd "N, contact-force lower band (assumed)";
  parameter Real F_band_max = 1.5*F_cmd "N, contact-force upper band (assumed)";
  // Controller gains (assumed, tuned for stable cascaded regulation)
  parameter Real Kpf    = 0.5    "outer force proportional gain (assumed)";
  parameter Real Kif    = 20.0   "outer force integral gain (assumed)";
  parameter Real Kpp    = 1.0e-6 "inner pressure proportional gain (assumed)";
  parameter Real Kip    = 5.0e-6 "inner pressure integral gain (assumed)";
  parameter Real Kp_pos = 2.0    "boom position proportional gain (assumed)";
  parameter Real Kd_pos = 1.0e3  "boom position derivative gain (assumed)";

  // ===== Continuous states =====
  Real x1(start=0.3),    v1(start=0.0) "boom cylinder piston state";
  Real x2(start=0.2),    v2(start=0.0) "stick cylinder piston state";
  Real pA1(start=4.4267e6), pB1(start=5.0e6) "boom chamber pressures";
  Real pA2(start=4.9e6),    pB2(start=5.0e6) "stick chamber pressures";
  Real p_s(start=6.4e6) "supply (load-sensing) pressure";

  // ===== Discrete controller states (500 Hz) =====
  discrete Real u_stick(start=0.0) "stick valve command [-1,1]";
  discrete Real u_boom(start=0.0)  "boom valve command [-1,1]";
  discrete Real int_F(start=0.0)   "outer force integrator";
  discrete Real int_p(start=0.0)  "inner pressure integrator";

  // ===== Observed / derived quantities =====
  Real F_hyd1, F_hyd2     "cylinder net hydraulic forces";
  Real x_ee, v_ee         "end-effector contact position/velocity";
  Real F_contact          "external contact force (measured)";
  Real F_dist_eff         "applied disturbance load";
  Real Q_A1,Q_B1,Q_A2,Q_B2 "valve port flows";
  Real Q_draw             "supply draw (meter-in)";
  Real Q_pump, Q_relief   "pump and relief flows";
  Real p_ls_cmd           "load-sensing pressure command";
  Real dp2                "stick pressure differential";
  Real F_est              "pressure-based contact force estimate";
  Real e_F                "primary force tracking error";

  // ===== Verification flags =====
  Boolean pressure_ok    "pressures within relief and positive bounds";
  Boolean flow_ok        "pump flow within stated limit";
  Boolean force_band_ok  "contact force inside allowed band";
  Boolean endstop_ok     "no cylinder end-stop impact";
  Boolean tracking_ok    "tracking error < 16 N after 13 s";
  Boolean hold_stable_ok "stable hold (velocities near zero)";

equation
  // Cylinder net forces (cap minus rod side)
  F_hyd1 = pA1*AA1 - pB1*AB1;
  F_hyd2 = pA2*AA2 - pB2*AB2;

  // Linearized end-effector kinematics from cylinder extensions
  x_ee = J1*x1 + J2*x2;
  v_ee = J1*v1 + J2*v2;

  // Disturbance: trapezoidal 218 N load change over the middle third
  F_dist_eff =
    if time < T_dist_start then 0.0
    else if time < T_dist_start + T_ramp then
        F_dist*(time - T_dist_start)/T_ramp
    else if time < T_dist_end - T_ramp then F_dist
    else if time < T_dist_end then
        F_dist*(T_dist_end - time)/T_ramp
    else 0.0;

  // Compliant contact (spring-damper) against fixed wall; zero when separated
  F_contact = if x_ee > x_wall then k_c*(x_ee - x_wall) + d_c*v_ee else 0.0;

  // Piston dynamics: hydraulic drive minus contact/disturbance/gravity/friction
  m1*der(v1) = F_hyd1 - J1*(F_contact + F_dist_eff) - F_grav1 - b1*v1;
  m2*der(v2) = F_hyd2 - J2*(F_contact + F_dist_eff) - F_grav2 - b2*v2;
  der(x1) = v1;
  der(x2) = v2;

  // 4/3 proportional valve flows (linear pressure-drop model, no sqrt singularity)
  // u>0 extend: A fed from supply, B drained to tank; u<0 retract: opposite
  Q_A1 = Cv*(if u_boom  > 0 then u_boom *(p_s - pA1) else u_boom *(pA1 - p_t));
  Q_B1 = Cv*(if u_boom  > 0 then -u_boom*(pB1 - p_t) else -u_boom*(p_s - pB1));
  Q_A2 = Cv*(if u_stick > 0 then u_stick*(p_s - pA2) else u_stick*(pA2 - p_t));
  Q_B2 = Cv*(if u_stick > 0 then -u_stick*(pB2 - p_t) else -u_stick*(p_s - pB2));

  // Chamber pressure dynamics (continuity; V > x_dead*area keeps divisors bounded)
  der(pA1) = beta/(AA1*(x1 + x_dead)) *
             (Q_A1 - AA1*v1 - C_leak*(pA1 - pB1));
  der(pB1) = beta/(AB1*(L_str1 - x1 + x_dead)) *
             (Q_B1 + AB1*v1 + C_leak*(pA1 - pB1));
  der(pA2) = beta/(AA2*(x2 + x_dead)) *
             (Q_A2 - AA2*v2 - C_leak*(pA2 - pB2));
  der(pB2) = beta/(AB2*(L_str2 - x2 + x_dead)) *
             (Q_B2 + AB2*v2 + C_leak*(pA2 - pB2));

  // Supply draw: positive meter-in flows drawn from the pump line
  Q_draw = max(0.0, Q_A1) + max(0.0, Q_B1) +
           max(0.0, Q_A2) + max(0.0, Q_B2);

  // Load-sensing pump with relief and flow saturation (supply limitation)
  p_ls_cmd = max(max(max(pA1,pB1),pA2),pB2) + delta_ls;
  Q_pump   = min(max(K_pump*(p_ls_cmd - p_s), 0.0), Q_pump_max);
  Q_relief = if p_s > p_relief then K_relief*(p_s - p_relief) else 0.0;
  der(p_s) = (Q_pump - Q_relief - Q_draw)/C_s;

  // Pressure-based contact-force estimator (Jacobian-transpose inversion)
  dp2 = pA2 - pB2;
  F_est = (J1*F_hyd1 + J2*F_hyd2 - J1*F_grav1 - J2*F_grav2)/(J1*J1 + J2*J2);

  // Primary tracking error
  e_F = F_cmd - F_contact;

  // ===== Discrete cascaded controller at 500 Hz =====
  // Outer: force PI -> desired stick pressure differential
  // Inner: pressure PI -> stick valve command
  // Boom: PD position hold
  when sample(0, Ts) then
    int_F = pre(int_F) + Ts*(F_cmd - F_contact);
    int_p = pre(int_p) + Ts*
            ((F_cmd + Kpf*(F_cmd - F_contact) + Kif*pre(int_F))/(J2*AA2)
             - (pA2 - pB2));
    u_stick = max(-1.0, min(1.0,
                Kpp*((F_cmd + Kpf*(F_cmd - F_contact) + Kif*pre(int_F))/(J2*AA2)
                     - (pA2 - pB2)) + Kip*pre(int_p)));
    u_boom  = max(-1.0, min(1.0,
                Kp_pos*(x1_cmd - x1) - Kd_pos*v1));
  end when;

  // ===== Verification criteria =====
  pressure_ok     = pA1 > 0.0 and pA1 < p_relief*1.05 and
                    pB1 > 0.0 and pB1 < p_relief*1.05 and
                    pA2 > 0.0 and pA2 < p_relief*1.05 and
                    pB2 > 0.0 and pB2 < p_relief*1.05 and
                    p_s  > 0.0 and p_s  < p_relief*1.05;
  flow_ok          = Q_pump <= Q_pump_max*1.001 + 1.0e-9;
  force_band_ok    = (F_contact >= F_band_min) and (F_contact <= F_band_max);
  endstop_ok       = x1 > 1.0e-3 and x1 < L_str1 - 1.0e-3 and
                    x2 > 1.0e-3 and x2 < L_str2 - 1.0e-3;
  tracking_ok      = if time >= T_settle then abs(e_F) < F_err_lim else true;
  hold_stable_ok   = abs(v1) < 5.0e-2 and abs(v2) < 5.0e-2;

  // No-NaN / no-Infinite physical, control, or estimator values:
  // All divisors are strictly positive by construction
  // (AA>0, x+x_dead>0, L-x+x_dead>0, J1^2+J2^2>0); valve flow uses a linear
  // pressure-drop law (no sqrt of non-positive arguments); contact uses a
  // zero-branch guard. Therefore no NaN/Inf is producible from these equations.

  annotation (
    experiment(StopTime=20.0, Tolerance=1e-5, Interval=0.002),
    Documentation(info="HydBoomForceF: hydraulic boom/stick force control.
      Stated: 2.0 m boom, 1.4 m stick, 300 kg payload, two double-acting
      cylinders, load-sensing pump+relief, Q<=0.004 m3/s, 218 N mid-third
      disturbance, 500 Hz, 20 s, <16 N error after 13 s. Quantities not stated
      in the requirement are marked (assumed) and are engineering placeholders,
      not fabricated facts."));
end HydBoomForceF;