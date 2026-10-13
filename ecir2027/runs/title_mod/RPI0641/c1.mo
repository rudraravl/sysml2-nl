model HydMotorTrackE
  extends Modelica.Icons.Example;

  // ===== Motor parameters =====
  parameter Real Dm_rev = 48.0e-6 "Motor displacement per revolution [m3/rev] (48 cm3/rev)";
  parameter Real Dm = Dm_rev/(2.0*Modelica.Constants.pi) "Motor displacement per rad [m3/rad]";
  parameter Real eta_v = 0.92 "Volumetric efficiency";
  parameter Real GearRatio = 12.0 "Gearbox reduction ratio (motor:load = 12:1)";

  // ===== Load parameters =====
  parameter Real m_table = 130.0 "Table mass [kg]";
  // NOTE: Effective table radius not stated; placeholder to enable simulation.
  parameter Real r_eff = 1.0 "Effective table radius [m] (unknown; placeholder)";
  parameter Real J_load = m_table*r_eff*r_eff "Table inertia [kg.m2]";
  parameter Real b_visc = 5.0 "Viscous friction coefficient [N.m.s/rad] (unknown; placeholder)";

  // ===== Hydraulics parameters =====
  parameter Real p_supply = 20.0e6 "Supply/relief pressure [Pa] (unknown; placeholder)";
  parameter Real V_ch = 0.002 "Lumped chamber volume [m3] (unknown; placeholder)";
  parameter Real bulk_mod = 1.4e9 "Effective bulk modulus [Pa] (unknown; placeholder)";
  parameter Real k_leak = 5.0e-13 "Leakage coefficient [m3/(s.Pa)] (unknown; placeholder)";
  parameter Real k_relief = 1.0e-6 "Relief valve conductance [m3/(s.Pa)] (unknown; placeholder)";
  parameter Real Q_max = 0.002 "Command magnitude bound [m3/s]";

  // ===== Controller gains (unknown per requirement; placeholders) =====
  parameter Real Kp_pos = 0.02 "Position proportional gain [m3/(s.m)]";
  parameter Real Kd_pos = 0.001 "Position derivative gain [m3/(s.(m/s))]";
  parameter Real Ki_pos = 0.1 "Position integral gain [m3/(s.m.s)]";
  parameter Real Kp_pres = 1.0e-12 "Pressure feedback gain [m3/(s.Pa)]";
  parameter Real Ts = 1.0/250.0 "Control sample time [s]";

  // ===== Trajectory parameters =====
  parameter Real x1 = 1.0 "End of segment 1 [m]";
  parameter Real x2 = 0.3 "End of segment 2 [m]";
  parameter Real t_a = 1.0 "Segment 1 start [s]";
  parameter Real t_b = 7.0 "Segment 1 end [s]";
  parameter Real t_c = 9.0 "Segment 2 start [s]";
  parameter Real t_d = 15.0 "Segment 2 end [s]";

  // ===== Disturbance =====
  parameter Real F_dist = 264.0 "Payload disturbance force [N]";
  parameter Real t_dist_on = 16.0/3.0 "Disturbance start [s]";
  parameter Real t_dist_off = 32.0/3.0 "Disturbance end [s]";

  // ===== Dynamic states =====
  Real theta_load(start=0.0, fixed=true) "Table angle [rad]";
  Real omega_load(start=0.0, fixed=true) "Table angular velocity [rad/s]";
  Real dp(start=1.0e5, fixed=true) "Chamber pressure difference [Pa]";
  Real e_pos_int(start=0.0, fixed=true) "Integral of position error [m.s]";

  // ===== Recorded outputs =====
  Real pA "Chamber A pressure [Pa]";
  Real pB "Chamber B pressure [Pa]";
  Real x "Linear-equivalent track position [m]";
  Real v "Linear-equivalent track velocity [m/s]";
  Real a_lin "Linear-equivalent acceleration [m/s2]";
  Real Q_supply "Supply flow [m3/s]";
  Real Q_cmd "Applied command flow [m3/s]";
  Real Q_leak "Leakage flow [m3/s]";
  Real Q_relief "Cross-port relief flow [m3/s]";
  Real T_motor "Motor torque [N.m]";
  Real T_dist "Disturbance torque [N.m]";
  Real omega_motor "Motor angular velocity [rad/s]";
  Real x_des "Desired position [m]";
  Real v_des "Desired velocity [m/s]";
  Real a_des "Desired acceleration [m/s2]";
  Real e_pos "Position error [m]";

  // ===== Discrete controller signal =====
  discrete Real Q_cmd_held(start=0.0, fixed=true) "Held command flow [m3/s]";
  Real Q_ff "Feedforward flow [m3/s]";

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
  function s5 "Quintic smooth step"
    input Real tau;
    output Real y;
  algorithm
    if tau <= 0.0 then
      y := 0.0;
    elseif tau >= 1.0 then
      y := 1.0;
    else
      y := 10.0*tau*tau*tau - 15.0*tau*tau*tau*tau + 6.0*tau*tau*tau*tau*tau;
    end if;
  end s5;

  function ds5 "First derivative of s5"
    input Real tau;
    output Real y;
  algorithm
    if tau <= 0.0 then
      y := 0.0;
    elseif tau >= 1.0 then
      y := 0.0;
    else
      y := 30.0*tau*tau - 60.0*tau*tau*tau + 30.0*tau*tau*tau*tau;
    end if;
  end ds5;

  function dds5 "Second derivative of s5"
    input Real tau;
    output Real y;
  algorithm
    if tau <= 0.0 then
      y := 0.0;
    elseif tau >= 1.0 then
      y := 0.0;
    else
      y := 60.0*tau - 180.0*tau*tau + 120.0*tau*tau*tau;
    end if;
  end dds5;

  function fin "Finiteness check"
    input Real val;
    output Boolean y;
  algorithm
    y := abs(val) < 1.0e30;
  end fin;

equation
  // ---- Two-segment smooth quintic position trajectory ----
  x_des = if time < t_a then 0.0
          else if time < t_b then x1*s5((time - t_a)/(t_b - t_a))
          else if time < t_c then x1
          else if time < t_d then x1 + (x2 - x1)*s5((time - t_c)/(t_d - t_c))
          else x2;

  v_des = if time < t_a then 0.0
          else if time < t_b then (x1/(t_b - t_a))*ds5((time - t_a)/(t_b - t_a))
          else if time < t_c then 0.0
          else if time < t_d then ((x2 - x1)/(t_d - t_c))*ds5((time - t_c)/(t_d - t_c))
          else 0.0;

  a_des = if time < t_a then 0.0
          else if time < t_b then (x1/(t_b - t_a)*(t_b - t_a))*dds5((time - t_a)/(t_b - t_a))
          else if time < t_c then 0.0
          else if time < t_d then ((x2 - x1)/(t_d - t_c)*(t_d - t_c))*dds5((time - t_c)/(t_d - t_c))
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
  Q_relief = k_relief*(if dp > 0.9*p_supply then dp - 0.9*p_supply else if dp < -0.9*p_supply then dp + 0.9*p_supply else 0.0);
  (V_ch/(2.0*bulk_mod)) * der(dp) = Q_cmd - Dm*omega_motor - Q_leak - Q_relief;

  // ---- Motor torque and load dynamics with viscous friction ----
  T_motor = Dm * dp;
  T_dist = if (time >= t_dist_on) and (time < t_dist_off) then F_dist*r_eff else 0.0;
  J_load * der(omega_load) = T_motor*GearRatio - b_visc*omega_load - T_dist;
  a_lin = r_eff * der(omega_load);

  // ---- Position error and integral ----
  e_pos = x_des - x;
  der(e_pos_int) = e_pos;

  // ---- Feedforward flow ----
  Q_ff = Dm*(GearRatio*v_des/r_eff)/eta_v;

  // ---- Discrete controller at 250 Hz ----
  when sample(0.0, Ts) then
    Q_cmd_held = max(-Q_max, min(Q_max, Q_ff + Kp_pos*e_pos + Kd_pos*(v_des - v) + Ki_pos*e_pos_int - Kp_pres*dp));
  end when;
  Q_cmd = Q_cmd_held;
  Q_supply = if Q_cmd >= 0.0 then Q_cmd else -Q_cmd;

  // ---- Acceptance bounds (fail-closed) ----
  b_travel = abs(x) <= 2.0;
  b_pressure = (pA <= p_supply*1.1) and (pB <= p_supply*1.1) and (pA >= 0.0) and (pB >= 0.0);
  b_flow = abs(Q_supply) <= Q_max + 1.0e-9;
  b_accel = abs(a_lin) <= 50.0;
  b_track = if time >= 10.4 then (abs(e_pos) <= 0.016) else true;
  b_relief = abs(Q_relief) <= 1.0e-4;
  b_nan = fin(x) and fin(v) and fin(a_lin) and fin(dp) and fin(pA) and fin(pB) and fin(Q_cmd) and fin(Q_supply) and fin(T_motor) and fin(e_pos) and fin(e_pos_int) and fin(x_des) and fin(v_des) and fin(a_des);
  accept = b_travel and b_pressure and b_flow and b_accel and b_track and b_relief and b_nan;

  annotation (
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "HydMotorTrackE: verifiable fluid-power robotic actuator system. A bidirectional 48 cm3/rev hydraulic motor (eta_v=0.92) drives a 130 kg rotary table through a 12:1 gearbox. Pressure-compensated proportional valve commands motor flow with |command| bounded by 0.002 m3/s. Plant includes viscous friction, leakage, and a finite-duration 264 N payload step disturbance over the middle third of a 16 s run. Control uses feedforward flow plus pressure-position feedback sampled at 250 Hz. Acceptance is fail-closed."));
end HydMotorTrackE;