model AirStageTrackF
  import Modelica.Constants.pi;

  // Carriage and stroke
  parameter Real m_carriage = 42.0 "Carriage mass [kg]";
  parameter Real L_stroke = 0.70 "Travel [m]";

  // Cylinder geometry (assumed, not stated)
  parameter Real A_A = 0.0050 "Cap-side piston area [m2]";
  parameter Real A_B = 0.0035 "Rod-side piston area [m2]";
  parameter Real V_A0 = 0.00050 "Cap-side dead volume [m3]";
  parameter Real V_B0 = 0.00040 "Rod-side dead volume [m3]";

  // Pneumatic parameters (assumed)
  parameter Real p_supply = 7.0e5 "Supply pressure [Pa]";
  parameter Real p_atm = 1.01325e5 "Atmospheric pressure [Pa]";
  parameter Real p_relief = 8.5e5 "Relief valve threshold [Pa]";
  parameter Real T0 = 293.15 "Gas temperature [K]";
  parameter Real R_air = 287.0 "Specific gas constant air [J/(kg.K)]";
  parameter Real b_visc = 800.0 "Viscous friction [N.s/m]";
  parameter Real leak_coeff = 1.0e-9 "Inter-chamber leakage [kg/(s.Pa)]";
  parameter Real leak_relief = 5.0e-7 "Relief valve coefficient [kg/(s.Pa)]";
  parameter Real m_dot_max = 0.018 "Max valve mass flow [kg/s]";

  // Payload
  parameter Real F_payload = 319.0 "Payload step magnitude [N]";
  parameter Real g = 9.81 "Gravity [m/s2]";

  // Trajectory segment timing (assumed)
  parameter Real t1a = 1.0 "Segment 1 start [s]";
  parameter Real t1b = 7.0 "Segment 1 end [s]";
  parameter Real dx1 = 0.35 "Segment 1 travel [m]";
  parameter Real t2a = 9.0 "Segment 2 start [s]";
  parameter Real t2b = 16.0 "Segment 2 end [s]";
  parameter Real dx2 = 0.35 "Segment 2 travel [m]";

  // Control gains (engineered)
  parameter Real Kp_pos = 8000.0 "Position gain [N/m]";
  parameter Real Kd_pos = 800.0 "Velocity gain [N.s/m]";
  parameter Real Ki_pos = 1500.0 "Integral gain [N/m]";
  parameter Real Kp_pres = 1.5e-6 "Valve command per N force error";

  // Dynamic states
  Real x(start=0.0, fixed=true) "Carriage position [m]";
  Real v(start=0.0, fixed=true) "Carriage velocity [m/s]";
  Real p_A(start=4.5e5) "Cap-side chamber pressure [Pa]";
  Real p_B(start=5.0e5) "Rod-side chamber pressure [Pa]";
  Real int_err(start=0.0) "Integral of position error [m]";

  // Volumes
  Real V_A "Cap-side volume [m3]";
  Real V_B "Rod-side volume [m3]";

  // Valve commands (0..1)
  Real cmd_A_fill;
  Real cmd_A_exh;
  Real cmd_B_fill;
  Real cmd_B_exh;
  Real command "Aggregated observed command";

  // Mass flows [kg/s]
  Real m_dot_A_fill;
  Real m_dot_A_exh;
  Real m_dot_B_fill;
  Real m_dot_B_exh;
  Real m_dot_leak;
  Real m_dot_supply "Observed supply flow [kg/s]";

  // Trajectory references
  Real x_des "Desired position [m]";
  Real v_des "Desired velocity [m/s]";
  Real a_des "Desired acceleration [m/s2]";
  Real x_err "Position error [m]";

  // Payload disturbance
  Real payload_active;
  Real F_dist "Disturbance force [N]";
  Real F_ff "Feedforward force [N]";
  Real F_cmd "Command force [N]";
  Real F_meas "Measured force [N]";
  Real e_force "Force error [N]";
  Real a "Acceleration [m/s2]";

  // Verification signals
  Boolean within_travel;
  Boolean within_pressure;
  Boolean within_flow;
  Boolean within_accel;
  Boolean within_traj_err;
  Boolean primary_tracking_ok;
  Boolean no_nan;
  Boolean verified;

protected
  Real s1, s1d, s1dd;
  Real s2, s2d, s2dd;
  Real int_err_clamped;
  Real fill_scale_A, exh_scale_A, fill_scale_B, exh_scale_B;
  Real dpa, dpb;

equation
  // Chamber volumes
  V_A = V_A0 + A_A * x;
  V_B = V_B0 + A_B * (L_stroke - x);

  // Smooth two-segment cosine trajectory (segment 1)
  s1 = if time < t1a then 0.0 elseif time < t1b then 0.5*(1.0 - Modelica.Math.cos(pi*(time - t1a)/(t1b - t1a))) else 1.0;
  s1d = if time < t1a then 0.0 elseif time < t1b then 0.5*Modelica.Math.sin(pi*(time - t1a)/(t1b - t1a))*pi/(t1b - t1a) else 0.0;
  s1dd = if time < t1a then 0.0 elseif time < t1b then 0.5*Modelica.Math.cos(pi*(time - t1a)/(t1b - t1a))*(pi/(t1b - t1a))*(pi/(t1b - t1a)) else 0.0;

  // Smooth two-segment cosine trajectory (segment 2)
  s2 = if time < t2a then 0.0 elseif time < t2b then 0.5*(1.0 - Modelica.Math.cos(pi*(time - t2a)/(t2b - t2a))) else 1.0;
  s2d = if time < t2a then 0.0 elseif time < t2b then 0.5*Modelica.Math.sin(pi*(time - t2a)/(t2b - t2a))*pi/(t2b - t2a) else 0.0;
  s2dd = if time < t2a then 0.0 elseif time < t2b then 0.5*Modelica.Math.cos(pi*(time - t2a)/(t2b - t2a))*(pi/(t2b - t2a))*(pi/(t2b - t2a)) else 0.0;

  x_des = dx1*s1 + dx2*s2;
  v_des = dx1*s1d + dx2*s2d;
  a_des = dx1*s1dd + dx2*s2dd;
  x_err = x_des - x;

  // Finite-duration payload step disturbance over middle third of 20 s run
  payload_active = if time >= 6.6667 and time <= 13.3333 then 1.0 else 0.0;
  F_dist = payload_active * F_payload;

  // Feedforward force (gravity + known payload + inertia + viscous)
  F_ff = m_carriage*a_des + b_visc*v_des + m_carriage*g + F_dist;

  // Integral with simple anti-windup (continuous, no events)
  der(int_err) = x_err * noEvent(smooth(0, if int_err > 0.02 then 0.0 elseif int_err < -0.02 then 0.0 else 1.0));
  int_err_clamped = max(-0.02, min(0.02, int_err));

  // Pressure-position feedback command force
  F_cmd = F_ff + Kp_pos*x_err + Kd_pos*(v_des - v) + Ki_pos*int_err_clamped;
  F_meas = p_A*A_A - p_B*A_B;
  e_force = F_cmd - F_meas;

  // Independent fill/exhaust proportional valve commands per chamber
  cmd_A_fill = max(0.0, min(1.0,  Kp_pres*e_force));
  cmd_A_exh  = max(0.0, min(1.0, -Kp_pres*e_force));
  cmd_B_fill = max(0.0, min(1.0, -Kp_pres*e_force));
  cmd_B_exh  = max(0.0, min(1.0,  Kp_pres*e_force));
  command = (cmd_A_fill - cmd_A_exh) - (cmd_B_fill - cmd_B_exh);

  // Pressure-dependent valve flow scaling (avoids negative pressures / backflow)
  dpa = (p_supply - p_A)/1.0e5;
  dpb = (p_supply - p_B)/1.0e5;
  fill_scale_A = max(0.0, min(1.0, dpa));
  exh_scale_A  = max(0.0, min(1.0, (p_A - p_atm)/1.0e5));
  fill_scale_B = max(0.0, min(1.0, dpb));
  exh_scale_B  = max(0.0, min(1.0, (p_B - p_atm)/1.0e5));

  m_dot_A_fill = cmd_A_fill * m_dot_max * fill_scale_A;
  m_dot_A_exh  = cmd_A_exh  * m_dot_max * exh_scale_A + max(0.0, (p_A - p_relief))*leak_relief;
  m_dot_B_fill = cmd_B_fill * m_dot_max * fill_scale_B;
  m_dot_B_exh  = cmd_B_exh  * m_dot_max * exh_scale_B + max(0.0, (p_B - p_relief))*leak_relief;
  m_dot_leak = leak_coeff * (p_A - p_B);
  m_dot_supply = m_dot_A_fill + m_dot_B_fill;

  // Isothermal ideal-gas chamber pressure dynamics
  der(p_A) = ((m_dot_A_fill - m_dot_A_exh - m_dot_leak)*R_air*T0 - p_A*A_A*v)/V_A;
  der(p_B) = ((m_dot_B_fill - m_dot_B_exh + m_dot_leak)*R_air*T0 + p_B*A_B*v)/V_B;

  // Vertical carriage mechanical dynamics
  der(x) = v;
  m_carriage*der(v) = p_A*A_A - p_B*A_B - m_carriage*g - b_visc*v - F_dist;
  a = (p_A*A_A - p_B*A_B - m_carriage*g - b_visc*v - F_dist)/m_carriage;

  // Verification criteria
  within_travel = x >= -0.01 and x <= L_stroke + 0.01;
  within_pressure = p_A > 0.0 and p_A < 1.0e6 and p_B > 0.0 and p_B < 1.0e6;
  within_flow = m_dot_supply >= 0.0 and m_dot_supply <= m_dot_max + 1.0e-4;
  within_accel = abs(a) < 50.0;
  within_traj_err = abs(x_err) < 0.05;
  primary_tracking_ok = if time > 13.0 then abs(x_err) < 0.014 else true;
  no_nan = abs(x) < 1.0e6 and abs(v) < 1.0e6 and abs(p_A) < 1.0e9 and abs(p_B) < 1.0e9 and abs(m_dot_supply) < 1.0e6 and abs(x_err) < 1.0e6 and abs(a) < 1.0e6;
  verified = within_travel and within_pressure and within_flow and within_accel and within_traj_err and primary_tracking_ok and no_nan;

  annotation (experiment(StopTime=20.0, Tolerance=1e-6, Interval=0.002));
end AirStageTrackF;