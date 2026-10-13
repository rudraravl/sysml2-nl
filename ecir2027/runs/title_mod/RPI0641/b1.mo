model HydMotorTrackE
  extends Modelica.Icons.Example;

  // ===== Motor parameters =====
  parameter Real Dm_rev(unit="m3/rev") = 48.0e-6 "Motor displacement per revolution (48 cm3/rev)";
  parameter Real Dm(unit="m3/rad") = Dm_rev/(2.0*Modelica.Constants.pi) "Motor displacement per rad";
  parameter Real eta_v = 0.92 "Volumetric efficiency";
  parameter Real GearRatio = 12.0 "Gearbox reduction ratio (motor:load = 12:1)";

  // ===== Load parameters =====
  parameter Real m_table = 130.0 "Table mass [kg]";
  // NOTE: Effective table radius is not stated in the requirement; placeholder used to enable simulation.
  parameter Real r_eff = 1.0 "Effective table radius [m] (unknown per requirement; placeholder)";
  parameter Real J_load(unit="kg.m2") = m_table*r_eff*r_eff "Table inertia";
  parameter Real b_visc(unit="N.m.s/rad") = 5.0 "Viscous friction coefficient at load (unknown; placeholder)";

  // ===== Hydraulics parameters =====
  // NOTE: Supply/relief pressure is not stated in the requirement; placeholder used.
  parameter Real p_supply(unit="Pa") = 20.0e6 "Supply/relief pressure (unknown; placeholder)";
  parameter Real V_ch(unit="m3") = 0.002 "Lumped chamber volume (unknown; placeholder)";
  parameter Real bulk_mod(unit="Pa") = 1.4e9 "Effective bulk modulus (unknown; placeholder)";
  parameter Real k_leak(unit="m3/(s.Pa)") = 5.0e-13 "Leakage coefficient (unknown; placeholder)";
  parameter Real k_relief(unit="m3/(s.Pa)") = 1.0e-6 "Relief valve conductance (unknown; placeholder)";
  parameter Real Q_max(unit="m3/s") = 0.002 "Command magnitude bound";

  // ===== Controller gains (unknown per requirement; placeholders) =====
  parameter Real Kp_pos(unit="m3/(s.m)") = 0.02 "Position proportional gain";
  parameter Real Kd_pos(unit="m3/(s.(m/s))") = 0.001 "Position derivative gain";
  parameter Real Ki_pos(unit="m3/(s.m.s)") = 0.1 "Position integral gain";
  parameter Real Kp_pres(unit="m3/(s.Pa)") = 1.0e-12 "Pressure feedback gain";
  parameter Real Ts(unit="s") = 1.0/250.0 "Control sample time";

  // ===== Trajectory parameters =====
  parameter Real x1 = 1.0 "End of segment 1 [m]";
  parameter Real x2 = 0.3 "End of segment 2 [m]";
  parameter Real t_a(unit="s") = 1.0 "Segment 1 start";
  parameter Real t_b(unit="s") = 7.0 "Segment 1 end";
  parameter Real t_c(unit="s") = 9.0 "Segment 2 start";
  parameter Real t_d(unit="s") = 15.0 "Segment 2 end";

  // ===== Disturbance =====
  parameter Real F_dist(unit="N") = 264.0 "Payload disturbance force";
  parameter Real t_dist_on(unit="s") = 16.0/3.0 "Disturbance start (middle third of 16 s run)";
  parameter Real t_dist_off(unit="s") = 32.0/3.0 "Disturbance end (middle third of 16 s run)";

  // ===== Dynamic states =====
  Real theta_load(unit="rad", start=0.0, fixed=true) "Table angle";
  Real omega_load(unit="rad/s", start=0.0, fixed=true) "Table angular velocity";
  Real dp(unit="Pa", start=0.0, fixed=true) "Chamber pressure difference pA - pB";
  Real e_pos_int(unit="m.s", start=0.0, fixed=true) "Integral of position error";

  // ===== Recorded outputs =====
  Real pA(unit="Pa") "Chamber A pressure";
  Real pB(unit="Pa") "Chamber B pressure";
  Real x(unit="m") "Linear-equivalent track position";
  Real v(unit="m/s") "Linear-equivalent track velocity";
  Real a_lin(unit="m/s2") "Linear-equivalent acceleration";
  Real Q_supply(unit="m3/s") "Supply flow";
  Real Q_cmd(unit="m3/s") "Applied command flow";
  Real Q_leak(unit="m3/s") "Leakage flow";
  Real Q_relief(unit="m3/s") "Cross-port relief flow";
  Real T_motor(unit="N.m") "Motor torque";
  Real T_dist(unit="N.m") "Disturbance torque";
  Real omega_motor(unit="rad/s") "Motor angular velocity";
  Real x_des(unit="m") "Desired position";
  Real v_des(unit="m/s") "Desired velocity";
  Real a_des(unit="m/s2") "Desired acceleration";
  Real e_pos(unit="m") "Position error";

  // ===== Discrete controller signal =====
  discrete Real Q_cmd_held(unit="m3/s", start=0.0, fixed=true) "Held command flow";
  Real Q_ff(unit="m3/s") "Feedforward flow";

  // ===== Acceptance flags (fail-closed) =====
  Boolean b_travel "Travel bound";
  Boolean b_pressure "Pressure bound";
  Boolean b_flow "Flow bound";
  Boolean b_accel "Acceleration bound";
  Boolean b_track "Trajectory-error bound";
  Boolean b_relief "Relief-valve bound";
  Boolean b_nan "No NaN/infinite values";
  Boolean accept "Overall acceptance (fail-closed)";

protected
  function s5 "Quintic smooth step, C2-continuous in [0,1]"
    input Real tau;
    output Real y;
  algorithm
    if tau <= 0.0 then
      y := 0.0;
    elseif tau >= 1.0 then
      y := 1.0;
    else
      y := 10.0*tau^3 - 15.0*tau^4 + 6.0*tau^5;
    end if;
  end s5;

  function ds5 "First derivative of s5 w.r.t. tau"
    input Real tau;
    output Real y;
  algorithm
    if tau <= 0.0 then
      y := 0.0;
    elseif tau >= 1.0 then
      y := 0.0;
    else
      y := 30.0*tau^2 - 60.0*tau^3 + 30.0*tau^4;
    end if;
  end ds5;

  function dds5 "Second derivative of s5 w.r.t. tau"
    input Real tau;
    output Real y;
  algorithm
    if tau <= 0.0 then
      y := 0.0;
    elseif tau >= 1.0 then
      y := 0.0;
    else
      y := 60.0*tau - 180.0*tau^2 + 120.0*tau^3;
    end if;
  end dds5;

  function fin "Finiteness check (false for NaN or infinite)"
    input Real x;
    output Boolean y;
  algorithm
    y := (abs(x) < 1.0e30);
  end fin;

equation
  // ---- Two-segment smooth quintic position trajectory ----
  if time < t_a then
    x_des = 0.0;
    v_des = 0.0;
    a_des = 0.0;
  elseif time < t_b then
    x_des = x1*s5((time - t_a)/(t_b - t_a));
    v_des = (x1/(t_b - t_a))*ds5((time - t_a)/(t_b - t_a));
    a_des = (x1/(t_b - t_a)^2)*dds5((time - t_a)/(t_b - t_a));
  elseif time < t_c then
    x_des = x1;
    v_des = 0.0;
    a_des = 0.0;
  elseif time < t_d then
    x_des = x1 + (x2 - x1)*s5((time - t_c)/(t_d - t_c));
    v_des = ((x2 - x1)/(t_d - t_c))*ds5((time - t_c)/(t_d - t_c));
    a_des = ((x2 - x1)/(t_d - t_c)^2)*dds5((time - t_c)/(t_d - t_c));
  else
    x_des = x2;
    v_des = 0.0;
    a_des = 0.0;
  end if;

  // ---- Kinematic relations ----
  der(theta_load) = omega_load;
  x = r_eff * theta_load;
  v = r_eff * omega_load;
  omega_motor = GearRatio * omega_load;

  // ---- Hydraulic motor: chamber pressures, leakage, relief ----
  pA = p_supply/2.0 + dp/2.0;
  pB = p_supply/2.0 - dp/2.0;
  Q_leak = k_leak * dp;
  if dp > 0.9*p_supply then
    Q_relief = k_relief*(dp - 0.9*p_supply);
  elseif dp < -0.9*p_supply then
    Q_relief = k_relief*(dp + 0.9*p_supply);
  else
    Q_relief = 0.0;
  end if;
  (V_ch/(2.0*bulk_mod)) * der(dp) = Q_cmd - Dm*omega_motor - Q_leak - Q_relief;

  // ---- Motor torque and load dynamics with viscous friction ----
  T_motor = Dm * dp;
  if (time >= t_dist_on) and (time < t_dist_off) then
    T_dist = F_dist*r_eff;
  else
    T_dist = 0.0;
  end if;
  J_load * der(omega_load) = T_motor*GearRatio - b_visc*omega_load - T_dist;
  a_lin = r_eff * der(omega_load);

  // ---- Position error and integral ----
  e_pos = x_des - x;
  der(e_pos_int) = e_pos;

  // ---- Feedforward flow (theoretical motor flow divided by volumetric efficiency) ----
  Q_ff = Dm*(GearRatio*v_des/r_eff)/eta_v;

  // ---- Discrete controller at 250 Hz: feedforward + pressure-position feedback ----
  when sample(0.0, Ts) then
    Q_cmd_held = max(-Q_max, min(Q_max,
      Q_ff + Kp_pos*e_pos + Kd_pos*(v_des - v) + Ki_pos*e_pos_int - Kp_pres*dp));
  end when;
  Q_cmd = Q_cmd_held;
  if Q_cmd >= 0.0 then
    Q_supply = Q_cmd;
  else
    Q_supply = -Q_cmd;
  end if;

  // ---- Acceptance bounds (fail-closed AND of all checks) ----
  b_travel  = abs(x) <= 2.0;
  b_pressure = (pA <= p_supply*1.1) and (pB <= p_supply*1.1) and (pA >= 0.0) and (pB >= 0.0);
  b_flow    = abs(Q_supply) <= Q_max + 1.0e-9;
  b_accel   = abs(a_lin) <= 50.0;
  if time >= 10.4 then
    b_track = (abs(e_pos) <= 0.016);
  else
    b_track = true;
  end if;
  b_relief  = abs(Q_relief) <= 1.0e-4;
  b_nan     = fin(x) and fin(v) and fin(a_lin) and fin(dp) and fin(pA) and fin(pB)
              and fin(Q_cmd) and fin(Q_supply) and fin(T_motor) and fin(e_pos)
              and fin(e_pos_int) and fin(x_des) and fin(v_des) and fin(a_des);
  accept = b_travel and b_pressure and b_flow and b_accel and b_track and b_relief and b_nan;

  annotation (
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "HydMotorTrackE: verifiable fluid-power robotic actuator system. A bidirectional 48 cm3/rev hydraulic motor (volumetric efficiency 0.92) drives a 130 kg rotary table through a 12:1 gearbox. A pressure-compensated proportional valve commands motor flow with |command| bounded by 0.002 m3/s. The plant includes viscous friction, leakage, and a finite-duration 264 N payload step disturbance applied over the middle third of a 16 s run. Control uses feedforward flow plus pressure-position feedback sampled at 250 Hz. Records position, velocity, chamber pressures, supply flow, and command. Acceptance is fail-closed and combines travel, pressure, flow, acceleration, trajectory-error, relief-valve, and finiteness bounds, with primary tracking error required below 0.016 m after 10.4 s. Quantities not stated in the requirement (effective table radius, supply/relief pressure, chamber volume, bulk modulus, leakage and friction coefficients, controller gains) are labeled placeholders."));
end HydMotorTrackE;