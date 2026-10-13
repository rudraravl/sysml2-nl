model HydBoomTrackB
  "Hydraulic boom/stick tracking with payload disturbance and load-sensing pump";

  // Geometry (stated facts)
  parameter Real Lboom = 2.0 "Boom length [m]";
  parameter Real Lstick = 1.4 "Stick length [m]";
  parameter Real mpay = 300.0 "Payload mass [kg]";
  parameter Real cmdmax = 0.003 "Allowed pump command magnitude [m3/s]";

  // Two-segment smooth trajectory for boom joint
  parameter Real t1_end = 3.33 "End of first segment [s]";
  parameter Real q1_target = 0.6 "Target boom angle segment 1 [rad]";
  parameter Real q2_target = 1.0 "Target boom angle segment 2 [rad]";
  parameter Real t_end = 10.0 "Mission duration [s]";

  // Hydraulic parameters (structural placeholders for unknown facts)
  parameter Real Aa = 3.0e-3 "Cylinder cap area [m2]";
  parameter Real Ab = 2.0e-3 "Cylinder rod area [m2]";
  parameter Real Lcyl = 3.0 "Cylinder stroke [m]";
  parameter Real Vline = 5.0e-4 "Line volume [m3]";
  parameter Real Vmin = 1.0e-4 "Minimum chamber volume guard [m3]";
  parameter Real Bf = 3.0e8 "Effective fluid bulk modulus [Pa]";
  parameter Real Kv = 6.0e-7 "Valve conductance [m3/(s Pa)]";
  parameter Real Cleak = 1.0e-12 "Leakage coefficient [m3/(s Pa)]";
  parameter Real Bv = 2.0e3 "Viscous friction coeff [N s/m]";

  // Relief valve
  parameter Real prelief = 2.8e7 "Relief valve setting [Pa]";
  parameter Real Crew = 8.0e-8 "Relief conductance [m3/(s Pa)]";

  // Load-sensing pump with relief
  parameter Real psupply_nom = 2.5e7 "Nominal supply pressure [Pa]";
  parameter Real Cpump = 1.0e-12 "Pump leakage [m3/(s Pa)]";

  // Payload disturbance (middle third)
  parameter Real Fdist = 154.0 "Payload step disturbance magnitude [N]";
  parameter Real td_start = 10.0/3.0 "Disturbance start [s]";
  parameter Real td_end = 2.0*10.0/3.0 "Disturbance end [s]";

  // Control gains
  parameter Real Kff = 1.0 "Feedforward gain";
  parameter Real Kq = 6.0e-3 "Position feedback gain [m3/(s m)]";
  parameter Real Kqd = 1.5e-3 "Velocity feedforward gain [m3/(s m)]";
  parameter Real Kp = 5.0e-10 "Pressure feedback gain [m3/(s Pa)]";

  // Sample rate
  parameter Real Ts = 0.01 "Sample period [s]";

  // Dynamic states
  Real q1(start=0.0) "Boom angle [rad]";
  Real q1d(start=0.0) "Boom angular velocity [rad/s]";
  Real pa1(start=1.0e6) "Boom cylinder cap pressure [Pa]";
  Real pb1(start=1.0e6) "Boom cylinder rod pressure [Pa]";
  Real psupply(start=5.0e6) "Supply pressure [Pa]";

  // Algebraic variables
  Real q1dd "Boom angular acceleration [rad/s2]";
  Real x1 "Boom cylinder position [m]";
  Real v1 "Boom cylinder velocity [m/s]";
  Real acc1 "Cylinder acceleration [m/s2]";

  // Trajectory references
  Real q1_ref "Reference boom angle [rad]";
  Real q1d_ref "Reference boom angular velocity [rad/s]";
  Real q1dd_ref "Reference boom angular acceleration [rad/s2]";
  Real x1_ref "Reference cylinder position [m]";
  Real v1_ref "Reference cylinder velocity [m/s]";

  // Disturbance
  Real Fdist_act "Active disturbance force [N]";

  // Control command
  Real cmd_raw "Unsaturated pump command [m3/s]";
  Real cmd "Saturated pump command [m3/s]";

  // Forces and flows
  Real Fcyl1 "Cylinder force [N]";
  Real Fload1 "Boom payload load [N]";
  Real Qa1 "Valve flow to cap side [m3/s]";
  Real Qb1 "Valve flow from rod side [m3/s]";
  Real Qpump "Pump output flow [m3/s]";
  Real Qrelief "Relief valve flow [m3/s]";
  Real Qleak_ps "Pump-to-cap leakage flow [m3/s]";
  Real Qleak_ch "Inter-chamber leakage flow [m3/s]";

  // Chamber volumes (guarded)
  Real Va1 "Cap-side chamber volume [m3]";
  Real Vb1 "Rod-side chamber volume [m3]";

  // Errors
  Real err_pos "Position error [m]";
  Real err_q "Angle error [rad]";

  // Bounds monitors
  Real travel "Total cylinder travel magnitude [m]";

  // Sampled state traces (100 Hz)
  discrete Real x1_sampled(start=0.0);
  discrete Real v1_sampled(start=0.0);
  discrete Real pa1_sampled(start=1.0e6);
  discrete Real pb1_sampled(start=1.0e6);
  discrete Real psupply_sampled(start=5.0e6);
  discrete Real cmd_sampled(start=0.0);
  discrete Real q1_sampled(start=0.0);
  discrete Real t_sampled(start=0.0);

equation
  // ---- Smooth two-segment quintic trajectory ----
  if time <= 0.0 then
    q1_ref = 0.0;
    q1d_ref = 0.0;
    q1dd_ref = 0.0;
  elseif time <= t1_end then
    q1_ref = q1_target*(10.0*(time/t1_end)^3 - 15.0*(time/t1_end)^4 + 6.0*(time/t1_end)^5);
    q1d_ref = q1_target/t1_end*(30.0*(time/t1_end)^2 - 60.0*(time/t1_end)^3 + 30.0*(time/t1_end)^4);
    q1dd_ref = q1_target/(t1_end*t1_end)*(60.0*(time/t1_end) - 180.0*(time/t1_end)^2 + 120.0*(time/t1_end)^3);
  elseif time <= t_end then
    q1_ref = q1_target + (q2_target - q1_target)*(10.0*((time - t1_end)/(t_end - t1_end))^3 - 15.0*((time - t1_end)/(t_end - t1_end))^4 + 6.0*((time - t1_end)/(t_end - t1_end))^5);
    q1d_ref = (q2_target - q1_target)/(t_end - t1_end)*(30.0*((time - t1_end)/(t_end - t1_end))^2 - 60.0*((time - t1_end)/(t_end - t1_end))^3 + 30.0*((time - t1_end)/(t_end - t1_end))^4);
    q1dd_ref = (q2_target - q1_target)/((t_end - t1_end)*(t_end - t1_end))*(60.0*((time - t1_end)/(t_end - t1_end)) - 180.0*((time - t1_end)/(t_end - t1_end))^2 + 120.0*((time - t1_end)/(t_end - t1_end))^3);
  else
    q1_ref = q2_target;
    q1d_ref = 0.0;
    q1dd_ref = 0.0;
  end if;

  // ---- Kinematic mapping (boom angle to cylinder position) ----
  // Geometry of cylinder attachment unknown; use bounded linearized sine mapping.
  x1_ref = Lboom*sin(q1_ref);
  v1_ref = Lboom*cos(q1_ref)*q1d_ref;
  x1 = Lboom*sin(q1);
  v1 = Lboom*cos(q1)*q1d;
  acc1 = Lboom*cos(q1)*q1dd - Lboom*sin(q1)*q1d*q1d;

  // ---- Payload disturbance (middle third) ----
  Fdist_act = if (time >= td_start and time <= td_end) then Fdist else 0.0;

  // ---- Boom dynamics (single-DOF lumped approximation) ----
  Fload1 = mpay*9.81*(Lboom*cos(q1) + Lstick) + Fdist_act;
  Fcyl1 = pa1*Aa - pb1*Ab;
  der(q1) = q1d;
  der(q1d) = q1dd;
  q1dd = (Fcyl1*Lboom*cos(q1) - Fload1*Lboom*cos(q1) - Bv*v1*Lboom*cos(q1))
          /(mpay*Lboom*Lboom + 1.0e-3);

  // ---- Control: feedforward flow with pressure-position feedback ----
  err_pos = x1_ref - x1;
  err_q = q1_ref - q1;
  cmd_raw = Kff*v1_ref*Aa + Kq*err_pos*Aa + Kqd*q1d_ref*Aa + Kp*(pa1 - psupply);
  cmd = if (cmd_raw > cmdmax) then cmdmax else (if (cmd_raw < -cmdmax) then -cmdmax else cmd_raw);

  // ---- Pump, relief, and supply pressure dynamics ----
  Qpump = cmd - Cpump*(psupply - psupply_nom);
  Qrelief = if (psupply > prelief) then Crew*(psupply - prelief) else 0.0;
  Qleak_ps = Cleak*(psupply - pa1);
  der(psupply) = (Bf/(Vline + Vmin))*(Qpump - Qa1 - Qrelief - Qleak_ps);

  // ---- Valve flows (linearized conductance model) ----
  Qa1 = Kv*(psupply - pa1);
  Qb1 = Kv*(pb1 - 1.0e5);

  // ---- Chamber volumes (guarded against singularity) ----
  Va1 = max(Aa*x1 + Vline, Vmin);
  Vb1 = max(Ab*(Lcyl - x1) + Vline, Vmin);

  // ---- Cylinder chamber pressure dynamics ----
  Qleak_ch = Cleak*(pa1 - pb1);
  der(pa1) = (Bf/Va1)*(Qa1 - Aa*v1 - Qleak_ch);
  der(pb1) = (Bf/Vb1)*(Ab*v1 - Qb1 + Qleak_ch);

  // ---- Travel monitor ----
  travel = abs(x1);

  // ---- Synchronized sampled traces at 100 Hz ----
  when sample(0, Ts) then
    t_sampled = time;
    x1_sampled = x1;
    v1_sampled = v1;
    pa1_sampled = pa1;
    pb1_sampled = pb1;
    psupply_sampled = psupply;
    cmd_sampled = cmd;
    q1_sampled = q1;
  end when;

end HydBoomTrackB;