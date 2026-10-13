model PneuGripTrackA
  // ===== Physical Parameters =====
  parameter Modelica.Units.SI.Length L = 0.035 "Cylinder stroke (travel)";
  parameter Modelica.Units.SI.Area A = 0.0012 "Piston area";
  parameter Modelica.Units.SI.Mass m_finger = 0.8 "Mass per gripper finger";
  parameter Modelica.Units.SI.Mass m_total = 2.0*m_finger "Total effective moving mass";
  parameter Modelica.Units.SI.Pressure Ps = 7.0e5 "Supply pressure (absolute)";
  parameter Modelica.Units.SI.Pressure Pe = 1.0e5 "Exhaust / atmospheric pressure";
  parameter Modelica.Units.SI.Pressure P_bias = 4.0e5 "Nominal chamber bias pressure";
  parameter Modelica.Units.SI.Pressure P_relief = 8.0e5 "Relief-valve pressure bound";
  parameter Modelica.Units.SI.Volume V_dead = A*L*0.1 "Dead volume per chamber";
  parameter Real R_air(unit="J/(kg.K)") = 287.0 "Specific gas constant of air";
  parameter Modelica.Units.SI.Temperature T_gas = 293.15 "Gas temperature (isothermal)";
  parameter Modelica.Units.SI.Pressure P0 = P_bias "Initial chamber pressure";
  parameter Modelica.Units.SI.Length x_init = 0.005 "Initial gripper position";
  parameter Modelica.Units.SI.Length x_mid = 0.020 "Mid-trajectory position";
  parameter Modelica.Units.SI.Length x_final = 0.032 "Final trajectory position";
  parameter Modelica.Units.SI.Velocity v0 = 0.0 "Initial velocity";
  parameter Real b_vis(unit="N.s/m") = 50.0 "Viscous friction coefficient";
  parameter Real k_leak(unit="kg/(s.Pa)") = 5.0e-10 "Leakage conductance";
  parameter Real k_relief(unit="kg/(s.Pa)") = 5.0e-8 "Relief-valve conductance";
  parameter Modelica.Units.SI.Force F_payload = 110.0 "Payload disturbance magnitude";
  parameter Modelica.Units.SI.Time t_dist_start = 8.0/3.0 "Disturbance start (middle third)";
  parameter Modelica.Units.SI.Time t_dist_end = 16.0/3.0 "Disturbance end (middle third)";
  parameter Modelica.Units.SI.Time t_seg1_end = 3.0 "End of trajectory segment 1";
  parameter Modelica.Units.SI.Time t_seg2_end = 6.0 "End of trajectory segment 2";
  parameter Modelica.Units.SI.MassFlowRate mdot_max = 0.001 "Command magnitude limit";
  parameter Real fs(unit="Hz") = 80.0 "Control and sampling frequency";
  parameter Real Kp_pos(unit="N/m") = 12000.0 "Position feedback gain";
  parameter Real Kd_pos(unit="N.s/m") = 400.0 "Velocity feedback gain";
  parameter Real Kp_press_flow(unit="kg/(s.Pa)") = 1.0e-8 "Pressure-error to flow gain";
  parameter Real a_bound(unit="m/s2") = 150.0 "Acceleration bound";
  parameter Modelica.Units.SI.Length tracking_bound = 0.024 "Tracking error bound after 5.2 s";
  parameter Modelica.Units.SI.Time t_track_check = 5.2 "Tracking error check start time";

  // ===== Continuous States =====
  Modelica.Units.SI.Length x(start=x_init, fixed=true) "Gripper position";
  Modelica.Units.SI.Velocity v(start=v0, fixed=true) "Gripper velocity";
  Modelica.Units.SI.Pressure P1(start=P0, fixed=true) "Chamber 1 pressure";
  Modelica.Units.SI.Pressure P2(start=P0, fixed=true) "Chamber 2 pressure";

  // ===== Continuous Derived Variables =====
  Modelica.Units.SI.Volume V1 "Chamber 1 volume";
  Modelica.Units.SI.Volume V2 "Chamber 2 volume";
  Modelica.Units.SI.Force F_net "Net pneumatic force";
  Modelica.Units.SI.Force F_friction "Viscous friction force";
  Modelica.Units.SI.Force F_dist "Payload disturbance force";
  Modelica.Units.SI.Acceleration a_actual "Actual acceleration";
  Modelica.Units.SI.MassFlowRate mdot1_net "Net mass flow into chamber 1";
  Modelica.Units.SI.MassFlowRate mdot2_net "Net mass flow into chamber 2";
  Modelica.Units.SI.MassFlowRate mdot_relief1 "Relief-valve 1 outflow";
  Modelica.Units.SI.MassFlowRate mdot_relief2 "Relief-valve 2 outflow";
  Modelica.Units.SI.Length x_ref "Reference position";
  Modelica.Units.SI.Velocity v_ref "Reference velocity";
  Modelica.Units.SI.Acceleration a_ref "Reference acceleration";
  Modelica.Units.SI.Length tracking_err "Primary tracking error |x_ref - x|";

  // ===== Discrete Controller Variables (80 Hz ZOH) =====
  discrete Modelica.Units.SI.Force F_des(start=0.0) "Desired net force";
  discrete Modelica.Units.SI.Pressure dP_des(start=0.0) "Desired pressure differential";
  discrete Modelica.Units.SI.Pressure P1_des(start=P0) "Desired chamber 1 pressure";
  discrete Modelica.Units.SI.Pressure P2_des(start=P0) "Desired chamber 2 pressure";
  discrete Modelica.Units.SI.MassFlowRate mdot1_ff(start=0.0) "Feedforward flow chamber 1";
  discrete Modelica.Units.SI.MassFlowRate mdot2_ff(start=0.0) "Feedforward flow chamber 2";
  discrete Modelica.Units.SI.MassFlowRate mdot1_fb(start=0.0) "Feedback flow chamber 1";
  discrete Modelica.Units.SI.MassFlowRate mdot2_fb(start=0.0) "Feedback flow chamber 2";
  discrete Modelica.Units.SI.MassFlowRate cmd1_raw(start=0.0) "Unsaturated command valve 1";
  discrete Modelica.Units.SI.MassFlowRate cmd2_raw(start=0.0) "Unsaturated command valve 2";
  discrete Modelica.Units.SI.MassFlowRate cmd1(start=0.0) "Saturated command valve 1";
  discrete Modelica.Units.SI.MassFlowRate cmd2(start=0.0) "Saturated command valve 2";
  discrete Modelica.Units.SI.MassFlowRate mdot_supply(start=0.0) "Total supply mass flow";

  // ===== Synchronized Sampled Traces (80 Hz) =====
  discrete Modelica.Units.SI.Length x_s(start=x_init) "Sampled position";
  discrete Modelica.Units.SI.Velocity v_s(start=0.0) "Sampled velocity";
  discrete Modelica.Units.SI.Pressure P1_s(start=P0) "Sampled chamber 1 pressure";
  discrete Modelica.Units.SI.Pressure P2_s(start=P0) "Sampled chamber 2 pressure";
  discrete Modelica.Units.SI.MassFlowRate mdot_supply_s(start=0.0) "Sampled supply flow";
  discrete Modelica.Units.SI.MassFlowRate cmd1_s(start=0.0) "Sampled command 1";
  discrete Modelica.Units.SI.MassFlowRate cmd2_s(start=0.0) "Sampled command 2";
  discrete Modelica.Units.SI.Length tracking_err_s(start=0.0) "Sampled tracking error";
  discrete Modelica.Units.SI.Force F_dist_s(start=0.0) "Sampled disturbance force";
  Integer tick(start=0) "Sample counter";

protected
  constant Real pi = 3.141592653589793;
  parameter Modelica.Units.SI.Time Ts = 1.0/fs "Sample period";
  parameter Modelica.Units.SI.Time dt1 = t_seg1_end "Duration segment 1";
  parameter Modelica.Units.SI.Time dt2 = t_seg2_end - t_seg1_end "Duration segment 2";
  Real s1 "Segment 1 smooth blend 0 to 1";
  Real s1d "Segment 1 blend first derivative";
  Real s1dd "Segment 1 blend second derivative";
  Real s2 "Segment 2 smooth blend 0 to 1";
  Real s2d "Segment 2 blend first derivative";
  Real s2dd "Segment 2 blend second derivative";

equation
  // ===== Two-segment smooth trajectory =====
  s1 = if time <= 0.0 then 0.0
       elseif time >= t_seg1_end then 1.0
       else 0.5*(1.0 - cos(pi*time/dt1));
  s1d = if time <= 0.0 or time >= t_seg1_end then 0.0
        else 0.5*pi/dt1*sin(pi*time/dt1);
  s1dd = if time <= 0.0 or time >= t_seg1_end then 0.0
         else 0.5*pi*pi/(dt1*dt1)*cos(pi*time/dt1);

  s2 = if time <= t_seg1_end then 0.0
       elseif time >= t_seg2_end then 1.0
       else 0.5*(1.0 - cos(pi*(time - t_seg1_end)/dt2));
  s2d = if time <= t_seg1_end or time >= t_seg2_end then 0.0
        else 0.5*pi/dt2*sin(pi*(time - t_seg1_end)/dt2);
  s2dd = if time <= t_seg1_end or time >= t_seg2_end then 0.0
         else 0.5*pi*pi/(dt2*dt2)*cos(pi*(time - t_seg1_end)/dt2);

  x_ref = x_init + (x_mid - x_init)*s1 + (x_final - x_mid)*s2;
  v_ref = (x_mid - x_init)*s1d + (x_final - x_mid)*s2d;
  a_ref = (x_mid - x_init)*s1dd + (x_final - x_mid)*s2dd;

  tracking_err = abs(x_ref - x);

  // ===== Payload disturbance: 110 N step during middle third =====
  F_dist = if time < t_dist_start then 0.0
           elseif time > t_dist_end then 0.0
           else F_payload;

  // ===== Chamber volumes =====
  V1 = V_dead + A*x;
  V2 = V_dead + A*(L - x);

  // ===== Relief-valve outflows =====
  mdot_relief1 = k_relief*max(P1 - P_relief, 0.0);
  mdot_relief2 = k_relief*max(P2 - P_relief, 0.0);

  // ===== Net chamber mass flows =====
  mdot1_net = cmd1 - k_leak*max(P1 - Pe, 0.0) - mdot_relief1;
  mdot2_net = cmd2 - k_leak*max(P2 - Pe, 0.0) - mdot_relief2;

  // ===== Pressure dynamics (isothermal ideal gas) =====
  der(P1) = (R_air*T_gas*mdot1_net - P1*A*v) / V1;
  der(P2) = (R_air*T_gas*mdot2_net + P2*A*v) / V2;

  // ===== Mechanical dynamics =====
  F_net = A*(P1 - P2);
  F_friction = b_vis*v;
  a_actual = (F_net - F_friction - F_dist) / m_total;
  der(x) = v;
  der(v) = a_actual;

  // ===== Discrete controller and synchronized traces at 80 Hz =====
  when sample(0, Ts) then
    // Feedforward + pressure-position feedback
    F_des = m_total*a_ref + b_vis*v_ref
          + Kp_pos*(x_ref - x) + Kd_pos*(v_ref - v);
    dP_des = F_des / A;
    P1_des = P_bias + dP_des/2.0;
    P2_des = P_bias - dP_des/2.0;

    mdot1_ff = (P1_des*A*v_ref) / (R_air*T_gas);
    mdot2_ff = (-P2_des*A*v_ref) / (R_air*T_gas);
    mdot1_fb = Kp_press_flow*(P1_des - P1);
    mdot2_fb = Kp_press_flow*(P2_des - P2);

    cmd1_raw = mdot1_ff + mdot1_fb;
    cmd2_raw = mdot2_ff + mdot2_fb;
    cmd1 = max(-mdot_max, min(mdot_max, cmd1_raw));
    cmd2 = max(-mdot_max, min(mdot_max, cmd2_raw));
    mdot_supply = max(cmd1, 0.0) + max(cmd2, 0.0);

    // Synchronized sensor traces
    x_s = x;
    v_s = v;
    P1_s = P1;
    P2_s = P2;
    mdot_supply_s = mdot_supply;
    cmd1_s = cmd1;
    cmd2_s = cmd2;
    tracking_err_s = tracking_err;
    F_dist_s = F_dist;
    tick = pre(tick) + 1;
  end when;

  // ===== Bounds and Requirements =====
  // Supply pressure sanity
  assert(Ps > P_bias, "Supply pressure must exceed bias pressure");
  // Travel bound
  assert(x >= -1.0e-4 and x <= L + 1.0e-4, "Position out of travel bounds");
  // Relief-valve pressure bound
  assert(P1 <= P_relief + 5.0e3 and P2 <= P_relief + 5.0e3,
         "Chamber pressure exceeds relief-valve bound");
  assert(P1 >= 5.0e3 and P2 >= 5.0e3,
         "Chamber pressure below minimum bound");
  // Flow/command bound
  assert(abs(cmd1) <= mdot_max + 1.0e-12 and abs(cmd2) <= mdot_max + 1.0e-12,
         "Command exceeds flow bound");
  // Acceleration bound
  assert(abs(a_actual) <= a_bound, "Acceleration exceeds bound");
  // Trajectory-error bound: tracking error below 0.024 m after 5.2 s
  assert(tracking_err <= tracking_bound or time <= t_track_check,
         "Primary tracking error exceeds 0.024 m after 5.2 s");

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Pneumatic gripper actuator PneuGripTrackA: two pneumatic chambers (one per cylinder) driven by proportional air valves with feedforward flow control and pressure-position feedback. 110 N payload step during middle third [2.667, 5.333] s. 80 Hz discrete control and synchronized traces over 8 s."));
end PneuGripTrackA;