model HydBoomTrackB
  "Hydraulic boom/stick tracking with payload disturbance and load-sensing pump"

  // Geometry (stated facts)
  parameter Real Lboom = 2.0 "Boom length [m]";
  parameter Real Lstick = 1.4 "Stick length [m]";
  parameter Real mpay = 300.0 "Payload mass [kg]";
  parameter Real cmdmax = 0.003 "Allowed pump command magnitude [m3/s]";

  // Two-segment smooth trajectory for boom joint
  parameter Real t1_end = 3.33 "End of first segment [s]";
  parameter Real q1_target = 0.6 "Target boom angle segment 1 [rad]";
  parameter Real q2_target = 1.0 "Target boom angle segment 2 [rad]";

  // Hydraulic parameters (structural, not copied from examples)
  parameter Real Aa = 3.0e-3 "Cylinder cap area [m2]";
  parameter Real Ab = 2.0e-3 "Cylinder rod area [m2]";
  parameter Real Lcyl = 1.2 "Cylinder stroke [m]";
  parameter Real Vline = 2.0e-4 "Line volume [m3]";
  parameter Real Bf = 1.2e9 "Fluid bulk modulus [Pa]";
  parameter Real Kv = 4.0e-7 "Valve conductance [m3/(s Pa^0.5)]";
  parameter Real Cleak = 1.0e-11 "Leakage coefficient [m3/(s Pa)]";
  parameter Real Bv = 4.0e3 "Viscous friction coeff [N s/m]";

  // Relief valve
  parameter Real prelief = 2.8e7 "Relief valve setting [Pa]";
  parameter Real Crew = 8.0e-8 "Relief relief conductance [m3/(s Pa)]";

  // Load-sensing pump with relief
  parameter Real psupply_nom = 2.5e7 "Nominal supply pressure [Pa]";
  parameter Real Cpump = 1.0e-11 "Pump leakage [m3/(s Pa)]";

  // Payload disturbance (middle third)
  parameter Real Fdist = 154.0 "Payload step disturbance magnitude [N]";
  parameter Real td_start = 10.0/3.0 "Disturbance start [s]";
  parameter Real td_end = 2.0*10.0/3.0 "Disturbance end [s]";

  // Control gains
  parameter Real Kff = 1.0 "Feedforward gain";
  parameter Real Kp = 2.0e-4 "Pressure-position feedback proportional [m3/(s Pa)]";
  parameter Real Kq = 8.0e-3 "Position feedback gain [m3/(s m)]";
  parameter Real Kqd = 1.0e-3 "Velocity feedforward gain [m3/(s m)]";

  // Sample rate
  parameter Real Ts = 0.01 "Sample period [s]";

  // Dynamic states
  Real q1(start=0.0) "Boom angle [rad]";
  Real q1d(start=0.0) "Boom angular velocity [rad/s]";
  Real q1dd "Boom angular acceleration [rad/s2]";
  Real x1(start=0.0) "Boom cylinder position [m]";
  Real v1(start=0.0) "Boom cylinder velocity [m/s]";
  Real pa1(start=1.0e5) "Boom cylinder cap pressure [Pa]";
  Real pb1(start=1.0e5) "Boom cylinder rod pressure [Pa]";
  Real psupply(start=1.0e5) "Supply pressure [Pa]";

  // Trajectory
  Real q1_ref "Reference boom angle [rad]";
  Real q1d_ref "Reference boom angular velocity [rad/s]";
  Real q1dd_ref "Reference boom angular acceleration [rad/s2]";
  Real x1_ref "Reference cylinder position [m]";
  Real v1_ref "Reference cylinder velocity [m/s]";

  // Disturbance
  Real Fdist_act "Active disturbance force [N]";

  // Control command
  Real cmd "Pump command [m3/s]";

  // Forces and flows
  Real Fcyl1 "Cylinder force [N]";
  Real Fload1 "Boom payload load [N]";
  Real Fa1 "Valve flow to cap side [m3/s]";
  Real Fb1 "Valve flow from rod side [m3/s]";
  Real Fpump "Pump output flow [m3/s]";
  Real Frelief "Relief valve flow [m3/s]";
  Real Fload1_leak "Leakage flow [m3/s]";

  // Errors
  Real err_pos "Position error [m]";
  Real err_q "Angle error [rad]";

  // Bounds monitors
  Real travel "Total travel [m]";
  Real acc1 "Cylinder acceleration [m/s2]";

  // Sampled state traces (100 Hz)
  Real x1_sampled(start=0.0);
  Real v1_sampled(start=0.0);
  Real pa1_sampled(start=1.0e5);
  Real psupply_sampled(start=1.0e5);
  Real cmd_sampled(start=0.0);
  Real q1_sampled(start=0.0);
  Real t_sampled(start=0.0);
  Integer tick(start=0);

equation
  // Smooth two-segment trajectory using quintic blends
  // Segment 1: 0 -> q1_target over [0, t1_end]
  // Segment 2: q1_target -> q2_target over [t1_end, 10]
  if time <= 0 then
    q1_ref = 0.0;
    q1d_ref = 0.0;
    q1dd_ref = 0.0;
  elseif time <= t1_end then
    // Smooth quintic from 0 to q1_target
    q1_ref = q1_target*(10*(time/t1_end)^3 - 15*(time/t1_end)^4 + 6*(time/t1_end)^5);
    q1d_ref = q1_target/t1_end*(30*(time/t1_end)^2 - 60*(time/t1_end)^3 + 30*(time/t1_end)^4);
    q1dd_ref = q1_target/t1_end^2*(60*(time/t1_end) - 180*(time/t1_end)^2 + 120*(time/t1_end)^3);
  elseif time <= 10.0 then
    // Smooth quintic from q1_target to q2_target over [t1_end, 10]
    q1_ref = q1_target + (q2_target-q1_target)*(10*((time-t1_end)/(10.0-t1_end))^3 - 15*((time-t1_end)/(10.0-t1_end))^4 + 6*((time-t1_end)/(10.0-t1_end))^5);
    q1d_ref = (q2_target-q1_target)/(10.0-t1_end)*(30*((time-t1_end)/(10.0-t1_end))^2 - 60*((time-t1_end)/(10.0-t1_end))^3 + 30*((time-t1_end)/(10.0-t1_end))^4);
    q1dd_ref = (q2_target-q1_target)/(10.0-t1_end)^2*(60*((time-t1_end)/(10.0-t1_end)) - 180*((time-t1_end)/(10.0-t1_end))^2 + 120*((time-t1_end)/(10.0-t1_end))^3);
  else
    q1_ref = q2_target;
    q1d_ref = 0.0;
    q1dd_ref = 0.0;
  end if;

  // Map boom angle to cylinder position via simple cosine geometry
  // Treat unknown geometry by linearized mapping; treat kinematic constant as unknown -> use placeholder
  x1_ref = Lboom * sin(q1_ref);
  v1_ref = Lboom * cos(q1_ref) * q1d_ref;

  // Boom dynamics (lumped single-DOF approximation)
  // Load force from payload at end of boom/stick + disturbance
  Fload1 = mpay*9.81*(Lboom*cos(q1) + Lstick) + Fdist_act;

  // Cylinder force
  Fcyl1 = pa1*Aa - pb1*Ab;

  // Angular acceleration definition
  q1dd = der(q1d);

  // Equation of motion (boom inertia approximated as mpay*Lboom^2)
  mpay*Lboom^2 * q1dd = Fcyl1*Lboom*cos(q1) - Fload1*Lboom*cos(q1) - Bv*v1*Lboom*cos(q1);
  der(q1) = q1d;

  // Cylinder position kinematics
  x1 = Lboom*sin(q1);
  v1 = Lboom*cos(q1)*q1d;
  acc1 = Lboom*cos(q1)*q1dd - Lboom*sin(q1)*q1d^2;

  // Payload step disturbance in middle third
  Fdist_act = if (time >= td_start and time <= td_end) then Fdist else 0.0;

  // Control: feedforward flow with pressure-position feedback
  err_pos = x1_ref - x1;
  err_q = q1_ref - q1;
  cmd = Kff*v1_ref*Aa + Kq*err_pos*Aa + Kqd*q1d_ref*Aa + Kp*(pa1 - psupply_nom);

  // Saturate command
  cmd = if (cmd > cmdmax) then cmdmax else (if (cmd < -cmdmax) then -cmdmax else cmd);

  // Pump output flow with leakage and load-sensing
  Fpump = cmd - Cpump*(psupply - psupply_nom);

  // Relief valve
  Frelief = if (psupply > prelief) then Crew*(psupply - prelief) else 0.0;

  // Supply pressure dynamics (lumped volume)
  der(psupply) = (Bf/(Vline + 1.0e-6)) * (Fpump - Fa1 - Frelief - Fload1_leak);
  Fload1_leak = Cleak*(psupply - pa1);

  // Cylinder chamber pressures
  der(pa1) = (Bf/(Aa*x1 + Vline + 1.0e-6)) * (Fa1 - Aa*v1 - Cleak*(pa1-pb1));
  der(pb1) = (Bf/(Ab*(Lcyl-x1) + Vline + 1.0e-6)) * (Ab*v1 - Fb1 + Cleak*(pa1-pb1));

  // Valve flows (simplified linearized)
  // Note: detailed valve orifice dynamics unknown; use linear conductance model
  Fa1 = Kv*(psupply - pa1);
  Fb1 = Kv*(pb1 - 1.0e5);

  // Sampled traces at 100 Hz
  when sample(0, Ts) then
    tick = pre(tick) + 1;
    t_sampled = time;
    x1_sampled = x1;
    v1_sampled = v1;
    pa1_sampled = pa1;
    psupply_sampled = psupply;
    cmd_sampled = cmd;
    q1_sampled = q1;
  end when;

  // Travel bound monitor
  travel = x1;

end HydBoomTrackB;