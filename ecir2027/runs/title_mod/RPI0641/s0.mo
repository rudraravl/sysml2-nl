model HydMotorTrackE
  extends Modelica.Icons.Example;

  // ===== Motor parameters =====
  parameter Modelica.Units.SI.Volume Dm_rev = 48.0e-6 "Motor displacement per revolution [m3/rev] (48 cm3/rev)";
  parameter Modelica.Units.SI.Volume Dm = Dm_rev/(2.0*Modelica.Constants.pi) "Motor displacement per rad [m3/rad]";
  parameter Real eta_v = 0.92 "Volumetric efficiency";
  parameter Real GearRatio = 12.0 "Gearbox reduction ratio (motor:load = 12:1)";

  // ===== Load parameters =====
  parameter Real m_table = 130.0 "Table mass [kg]";
  // NOTE: Effective table radius is not stated in the requirement; placeholder used to enable simulation.
  parameter Real r_eff = 1.0 "Effective table radius [m] (unknown per requirement; placeholder)";
  parameter Modelica.Units.SI.MomentOfInertia J_load = m_table*r_eff*r_eff "Table inertia [kg.m2]";
  parameter Real b_visc = 5.0 "Viscous friction coefficient at load [N.m.s/rad] (unknown; placeholder)";

  // ===== Hydraulics parameters =====
  // NOTE: Supply/relief pressure is not stated in the requirement; placeholder used.
  parameter Modelica.Units.SI.Pressure p_supply = 20.0e6 "Supply/relief pressure [Pa] (unknown; placeholder)";
  parameter Modelica.Units.SI.Volume V_ch = 0.002 "Lumped chamber volume [m3] (unknown; placeholder)";
  parameter Modelica.Units.SI.Pressure bulk_mod = 1.4e9 "Effective bulk modulus [Pa] (unknown; placeholder)";
  parameter Real k_leak = 5.0e-13 "Leakage coefficient [m3/(s.Pa)] (unknown; placeholder)";
  parameter Real k_relief = 1.0e-6 "Relief valve conductance [m3/(s.Pa)] (unknown; placeholder)";
  parameter Modelica.Units.SI.VolumeFlowRate Q_max = 0.002 "Command magnitude bound [m3/s]";

  // ===== Controller gains (unknown per requirement; placeholders) =====
  parameter Real Kp_pos = 0.02 "Position proportional gain [m3/(s.m)]";
  parameter Real Kd_pos = 0.001 "Position derivative gain [m3/(s.(m/s))]";
  parameter Real Ki_pos = 0.1 "Position integral gain [m3/(s.m.s)]";
  parameter Real Kp_pres = 1.0e-12 "Pressure feedback gain [m3/(s.Pa)]";
  parameter Modelica.Units.SI.Time Ts = 1.0/250.0 "Control sample time [s]";

  // ===== Trajectory parameters =====
  parameter Real x1 = 1.0 "End of segment 1 [m]";
  parameter Real x2 = 0.3 "End of segment 2 [m]";
  parameter Modelica.Units.SI.Time t_a = 1.0 "Segment 1 start [s]";
  parameter Modelica.Units.SI.Time t_b = 7.0 "Segment 1 end [s]";
  parameter Modelica.Units.SI.Time t_c = 9.0 "Segment 2 start [s]";
  parameter Modelica.Units.SI.Time t_d = 15.0 "Segment 2 end [s]";

  // ===== Disturbance =====
  parameter Real F_dist = 264.0 "Payload disturbance force [N]";
  parameter Modelica.Units.SI.Time t_dist_on = 16.0/3.0 "Disturbance start [s] (middle third of 16 s run)";
  parameter Modelica.Units.SI.Time t_dist_off = 32.0/3.0 "Disturbance end [s] (middle third of 16 s run)";

  // ===== Dynamic states =====
  Modelica.Units.SI.Angle theta_load(start=0.0, fixed=true) "Table angle [rad]";
  Modelica.Units.SI.AngularVelocity omega_load(start=0.0, fixed=true) "Table angular velocity [rad/s]";
  Modelica.Units.SI.Pressure dp(start=0.0, fixed=true) "Chamber pressure difference pA - pB [Pa]";
  Real e_pos_int(start=0.0, fixed=true) "Integral of position error [m.s]";

  // ===== Recorded outputs =====
  Modelica.Units.SI.Pressure pA "Chamber A pressure [Pa]";
  Modelica.Units.SI.Pressure pB "Chamber B pressure [Pa]";
  Real x "Linear-equivalent track position [m]";
  Real v "Linear-equivalent track velocity [m/s]";
  Real a_lin "Linear-equivalent acceleration [m/s2]";
  Modelica.Units.SI.VolumeFlowRate Q_supply "Supply flow [m3/s]";
  Modelica.Units.SI.VolumeFlowRate Q_cmd "Applied command flow [m3/s]";
  Modelica.Units.SI.VolumeFlowRate Q_leak "Leakage flow [m3/s]";
  Modelica.Units.SI.VolumeFlowRate Q_relief "Cross-port relief flow [m3/s]";
  Modelica.Units.SI.Torque T_motor "Motor torque [N.m]";
  Modelica.Units.SI.Torque T_dist "Disturbance torque [N.m]";
  Modelica.Units.SI.AngularVelocity omega_motor "Motor angular velocity [rad/s]";
  Real x_des "Desired position [m]";
  Real v_des "Desired velocity [m/s]";
  Real a_des "Desired acceleration [m/s2]";
  Real e_pos "Position error [m]";

  // ===== Discrete controller signal =====
  Modelica.Units.SI.VolumeFlowRate Q_cmd_held(start=0.0, fixed=true) "Held command flow [m3/s]";
  Modelica.Units.SI.VolumeFlowRate Q_ff "Feedforward flow [m3/s]";

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
    y := if tau <= 0.0 then 0.0
         elseif tau >= 1.0 then 1.0
         else 10.0*tau^3 - 15.0*tau^4 + 6.0*tau^5;
  end s5;

  function ds5 "First derivative of s5 w.r.t. tau"
    input Real tau;
    output Real y;
  algorithm
    y := if tau <= 0.0 then 0.0
         elseif tau >= 1.0 then 0.0
         else 30.0*tau^2 - 60.0*tau^3 + 30.0*tau^4;
  end ds5;

  function dds5 "Second derivative of s5 w.r.t. tau"
    input Real tau;
    output Real y;
  algorithm
    y := if tau <= 0.0 then 0.0
         elseif tau >= 1.0 then 0.0
         else 60.0*tau - 180.0*tau^2 + 120.0*tau^3;
  end dds5;

  function fin "Finiteness check (false for NaN or infinite)"
    input Real x;
    output Boolean y;
  algorithm
    y := (abs(x) < 1.0e30);
  end fin;

equation
  // ---- Two-segment smooth quintic position trajectory ----
  x_des = if time < t_a then 0.0
          elseif time < t_b then x1*s5((time - t_a)/(t_b - t_a))
          elseif time < t_c then x1
          elseif time < t_d then x1 + (x2 - x1)*s5((time - t_c)/(t_d - t_c))
          else x2;
  v_des = if time < t_a then 0.0
          elseif time < t_b then (x1/(t_b - t_a))*ds5((time - t_a)/(t_b - t_a))
          elseif time < t_c then 0.0
          elseif time < t_d then ((x2 - x1)/(t_d - t_c))*ds5((time - t_c)/(t_d - t_c))
          else 0.0;
  a_des = if time < t_a then 0.0
          elseif time < t_b then (x1/(t_b - t_a)^2)*dds5((time - t_a)/(t_b - t_a))
          elseif time < t_c then 0.0
          elseif time < t_d then ((x2 - x1)/(t_d - t_c)^2)*dds5((time - t_c)/(t_d - t_c))
          else 0.0;

  // ---- Kinematic relations ----
  der(theta_load) = omega_load;
  x = r_eff * theta_load;
  v = r_eff * omega_load;
  omega_motor = GearRatio * omega_load;

  // ---- Hydraulic motor: chamber pressures, leakage, relief ----
  pA = p_supply/2.0 + dp/2.0;
  pB = p_supply/2.0 - dp/2.0;
  Q_leak = k_leak * dp;
  Q_relief = noEvent(k_relief*
             (if dp > 0.9*p_supply then dp - 0.9*p_supply
              elseif dp < -0.9*p_supply then dp + 0.9*p_supply
              else 0.0));
  (V_ch/(2.0*bulk_mod)) * der(dp) = Q_cmd - Dm*omega_motor - Q_leak - Q_relief;

  // ---- Motor torque and load dynamics with viscous friction ----
  T_motor = Dm * dp;
  T_dist = if (time >= t_dist_on) and (time < t_dist_off) then F_dist*r_eff else 0.0;
  J_load * der(omega_load) = T_motor*GearRatio - b_visc*omega_load - T_dist;
  a_lin = r_eff * der(omega_load);

  // ---- Position error and integral ----
  e_pos = x_des - x;
  der(e_pos_int) = e_pos;

  // ---- Feedforward flow (theoretical motor flow divided by volumetric efficiency) ----
  Q_ff = Dm*(GearRatio*v_des/r_eff)/eta_v;

  // ---- Discrete controller at 250 Hz: feedforward + pressure-position feedback ----
  when sample(0.0, Ts) then
    Q_cmd_held = noEvent(max(-Q_max, min(Q_max,
      Q_ff + Kp_pos*e_pos + Kd_pos*(v_des - v) + Ki_pos*e_pos_int - Kp_pres*dp)));
  end when;
  Q_cmd = Q_cmd_held;
  Q_supply = noEvent(if Q_cmd >= 0.0 then Q_cmd else -Q_cmd);

  // ---- Acceptance bounds (fail-closed AND of all checks) ----
  b_travel  = abs(x) <= 2.0;
  b_pressure = (pA <= p_supply*1.1) and (pB <= p_supply*1.1) and (pA >= 0.0) and (pB >= 0.0);
  b_flow    = abs(Q_supply) <= Q_max + 1.0e-9;
  b_accel   = abs(a_lin) <= 50.0;
  b_track   = if time >= 10.4 then (abs(e_pos) <= 0.016) else true;
  b_relief  = abs(Q_relief) <= 1.0e-4;
  b_nan     = fin(x) and fin(v) and fin(a_lin) and fin(dp) and fin(pA) and fin(pB)
              and fin(Q_cmd) and fin(Q_supply) and fin(T_motor) and fin(e_pos)
              and fin(e_pos_int) and fin(x_des) and fin(v_des) and fin(a_des);
  accept = b_travel and b_pressure and b_flow and b_accel and b_track and b_relief and b_nan;

  annotation (
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "HydMotorTrackE: verifiable fluid-power robotic actuator system. A bidirectional 48 cm3/rev hydraulic motor (volumetric efficiency 0.92) drives a 130 kg rotary table through a 12:1 gearbox. A pressure-compensated proportional valve commands motor flow with |command| bounded by 0.002 m3/s. The plant includes viscous friction, leakage, and a finite-duration 264 N payload step disturbance applied over the middle third of a 16 s run. Control uses feedforward flow plus pressure-position feedback sampled at 250 Hz. Records position, velocity, chamber pressures, supply flow, and command. Acceptance is fail-closed and combines travel, pressure, flow, acceleration, trajectory-error, relief-valve, and finiteness bounds, with primary tracking error required below 0.016 m after 10.4 s. Quantities not stated in the requirement (effective table radius, supply/relief pressure, chamber volume, bulk modulus, leakage and friction coefficients, controller gains) are labeled placeholders."))
  );
end HydMotorTrackE;