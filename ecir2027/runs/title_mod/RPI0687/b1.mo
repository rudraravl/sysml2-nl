model HydBoomTrackC
  extends Modelica.Icons.Example;

  // ===== Simulation =====
  parameter Real dt = 1.0/125.0 "Control sample rate [s]";

  // ===== Geometry and mass =====
  parameter Real Lb = 2.0 "Boom length [m]";
  parameter Real Ls = 1.4 "Stick length [m]";
  parameter Real mpay = 300.0 "Payload mass [kg]";
  parameter Real mb = 150.0 "Boom mass [kg] (assumed, not specified)";
  parameter Real ms = 80.0 "Stick mass [kg] (assumed, not specified)";
  parameter Real g = Modelica.Constants.g_n "Gravity [m/s2]";

  // ===== Boom cylinder (assumed parameters where unspecified) =====
  parameter Real Dp_b = 0.08 "Boom piston diameter [m] (assumed)";
  parameter Real Dr_b = 0.04 "Boom rod diameter [m] (assumed)";
  parameter Real stroke_b = 0.60 "Boom cylinder stroke [m] (assumed)";
  parameter Real rb = 0.50 "Boom effective moment arm [m] (assumed)";
  parameter Real x0_b = 0.30 "Boom cylinder initial stroke [m] (assumed)";
  parameter Real A_p_b = Modelica.Constants.pi*Dp_b*Dp_b/4 "Boom cap-side area [m2]";
  parameter Real A_r_b = Modelica.Constants.pi*(Dp_b*Dp_b - Dr_b*Dr_b)/4 "Boom rod-side area [m2]";
  parameter Real Va0_b = A_p_b*0.05 "Boom cap dead volume [m3] (assumed)";
  parameter Real Vb0_b = A_r_b*0.05 "Boom rod dead volume [m3] (assumed)";

  // ===== Stick cylinder =====
  parameter Real Dp_s = 0.06 "Stick piston diameter [m] (assumed)";
  parameter Real Dr_s = 0.03 "Stick rod diameter [m] (assumed)";
  parameter Real stroke_s = 0.50 "Stick cylinder stroke [m] (assumed)";
  parameter Real rs = 0.40 "Stick effective moment arm [m] (assumed)";
  parameter Real x0_s = 0.25 "Stick cylinder initial stroke [m] (assumed)";
  parameter Real A_p_s = Modelica.Constants.pi*Dp_s*Dp_s/4;
  parameter Real A_r_s = Modelica.Constants.pi*(Dp_s*Dp_s - Dr_s*Dr_s)/4;
  parameter Real Va0_s = A_p_s*0.04;
  parameter Real Vb0_s = A_r_s*0.04;

  // ===== Fluid, friction, leakage =====
  parameter Real beta = 1.2e9 "Oil bulk modulus [Pa] (assumed)";
  parameter Real Cleak_b = 1.0e-12 "Boom internal leakage coeff [m3/(s.Pa)] (assumed)";
  parameter Real Cleak_s = 0.8e-12 "Stick internal leakage coeff [m3/(s.Pa)] (assumed)";
  parameter Real bvisc_b = 5.0e3 "Boom viscous friction [N.s/m] (assumed)";
  parameter Real bvisc_s = 3.0e3 "Stick viscous friction [N.s/m] (assumed)";

  // ===== Supply, relief, load sensing =====
  parameter Real Vs_line = 2.0e-3 "Supply line volume [m3] (assumed)";
  parameter Real p_relief = 250.0e5 "Relief valve cracking pressure [Pa] (assumed)";
  parameter Real Krelief = 1.0e-7 "Relief valve conductance [m3/(s.Pa)] (assumed)";
  parameter Real Qleak_pump = 1.0e-6 "Pump case drain/bleed [m3/s] (assumed)";
  parameter Real pmargin = 10.0e5 "Load-sensing margin [Pa] (assumed)";
  parameter Real Kp_ls = 1.0e-9 "Load-sensing pressure gain [m3/(s.Pa)] (assumed)";

  // ===== Inertias =====
  parameter Real Jb = mb*Lb*Lb/3 + (ms+mpay)*Lb*Lb + ms*Ls*Ls/3 + mpay*Ls*Ls
    "Lumped boom-system inertia about base [kg.m2] (assumed)";
  parameter Real Js = ms*Ls*Ls/3 + mpay*Ls*Ls
    "Stick inertia about stick pivot [kg.m2] (assumed)";

  // ===== Trajectory =====
  parameter Real theta_b0 = 0.30 "Segment-1 start boom angle [rad] (assumed)";
  parameter Real theta_b1 = 0.60 "Segment-1 end / Segment-2 start [rad] (assumed)";
  parameter Real theta_b2 = 0.40 "Segment-2 end boom angle [rad] (assumed)";
  parameter Real theta_s_ref = 0.30 "Stick hold angle [rad] (assumed)";
  parameter Real T_seg1 = 6.0 "Segment 1 duration [s]";
  parameter Real T_seg2 = 6.0 "Segment 2 duration [s]";

  // ===== Controller gains (assumed, tuned for tracking) =====
  parameter Real Kp_pos = 0.010 "Boom position gain [m3/(s.rad)] (assumed)";
  parameter Real Kd_pos = 0.003 "Boom velocity gain [m3/rad] (assumed)";
  parameter Real Ki_pos = 0.003 "Boom integral gain [m3/(s.rad)/s] (assumed)";
  parameter Real Kp_pres = 1.0e-10 "Boom pressure feedback gain [m3/(s.Pa)] (assumed)";
  parameter Real integ_max = 0.50 "Integral clamp [rad.s] (assumed)";
  parameter Real Kp_s = 4.0e-3 "Stick position gain [m3/(s.rad)] (assumed)";
  parameter Real Kd_s = 1.0e-3 "Stick velocity gain [m3/rad] (assumed)";
  parameter Real Qmax = 0.003 "Max pump/valve command magnitude [m3/s]";
  parameter Real u_s_max = 1.0e-3 "Stick valve command limit [m3/s] (assumed)";

  // ===== Disturbance =====
  parameter Real Fdist_amp = 198.0 "Payload disturbance force [N]";
  parameter Real t_dist_on = 4.0 "Disturbance onset [s] (middle third)";
  parameter Real t_dist_off = 8.0 "Disturbance offset [s] (middle third)";
  parameter Real t_blend = 0.05 "Disturbance smooth transition [s] (assumed)";

  // ===== Bounds (assumed where unspecified) =====
  parameter Real alpha_max = 2.0 "Boom angular acceleration bound [rad/s2] (assumed)";

  // ===== Continuous states =====
  Real theta_b(start=theta_b0) "Boom angle [rad]";
  Real omega_b(start=0) "Boom angular velocity [rad/s]";
  Real theta_s(start=theta_s_ref) "Stick angle relative to boom [rad]";
  Real omega_s(start=0) "Stick angular velocity [rad/s]";
  Real pA_b(start=53.0e5) "Boom cap-side pressure [Pa]";
  Real pB_b(start=5.0e5) "Boom rod-side pressure [Pa]";
  Real pA_s(start=38.0e5) "Stick cap-side pressure [Pa]";
  Real pB_s(start=5.0e5) "Stick rod-side pressure [Pa]";
  Real ps(start=63.0e5) "Supply pressure [Pa]";
  Real integ_err(start=0) "Integral of boom angle error [rad.s]";

  // ===== Discrete controller outputs (sampled at 125 Hz) =====
  discrete Real u_b_d(start=0) "Boom valve command (sampled) [m3/s]";
  discrete Real u_s_d(start=0) "Stick valve command (sampled) [m3/s]";
  discrete Real Qpump_cmd_d(start=0) "Pump flow command (sampled) [m3/s]";

  // ===== Continuous ZOH commands =====
  Real u_b "Boom valve command [m3/s]";
  Real u_s "Stick valve command [m3/s]";
  Real Qpump_cmd "Pump flow command [m3/s]";

  // ===== References =====
  Real theta_b_ref "Reference boom angle [rad]";
  Real omega_b_ref "Reference boom angular velocity [rad/s]";
  Real alpha_b_ref "Reference boom angular acceleration [rad/s2]";

  // ===== Derived kinematics =====
  Real x_b "Boom cylinder stroke [m]";
  Real x_s "Stick cylinder stroke [m]";
  Real v_pist_b "Boom piston velocity [m/s]";
  Real v_pist_s "Stick piston velocity [m/s]";
  Real Va_b "Boom cap volume [m3]";
  Real Vb_b "Boom rod volume [m3]";
  Real Va_s "Stick cap volume [m3]";
  Real Vb_s "Stick rod volume [m3]";
  Real alpha_b "Boom angular acceleration [rad/s2]";

  // ===== Forces and torques =====
  Real F_b "Boom cylinder net force [N]";
  Real F_s "Stick cylinder net force [N]";
  Real tau_b "Boom actuator torque [N.m]";
  Real tau_s "Stick actuator torque [N.m]";
  Real tau_grav_b "Boom gravity torque magnitude [N.m]";
  Real tau_grav_s "Stick gravity torque magnitude [N.m]";
  Real tau_dist "Disturbance torque [N.m]";
  Real Qleak_b "Boom internal leakage [m3/s]";
  Real Qleak_s "Stick internal leakage [m3/s]";

  // ===== Control internal =====
  Real Qff_b "Boom feedforward flow [m3/s]";
  Real pload_b "Boom load pressure referred to cap side [Pa]";
  Real pload_ff_b "Boom feedforward load pressure [Pa]";
  Real Qdraw_b "Boom pump draw [m3/s]";
  Real Qdraw_s "Stick pump draw [m3/s]";
  Real pload_max "Maximum chamber pressure [Pa]";
  Real ps_target "Load-sensing target pressure [Pa]";
  Real Qrelief "Relief valve flow [m3/s]";

  // ===== Disturbance =====
  Real Fdist_actual "Active disturbance force [N]";

  // ===== Payload kinematics =====
  Real xp "Payload x-position [m]";
  Real yp "Payload y-position [m]";
  Real xp_ref "Payload reference x-position [m]";
  Real yp_ref "Payload reference y-position [m]";
  Real vp_x "Payload x-velocity [m/s]";
  Real vp_y "Payload y-velocity [m/s]";
  Real vp_mag "Payload speed [m/s]";
  Real ep "Payload tracking error [m]";

  // ===== Bound indicators (0 = OK, 1 = violated) =====
  Real b_travel_b;
  Real b_travel_s;
  Real b_pressure;
  Real b_flow;
  Real b_accel;
  Real b_traj_err;
  Real b_relief;
  Real b_no_nan;

  // ===== Synchronized sensor time =====
  Real sensor_time "Synchronized time [s]";

protected
  Real s_on "Disturbance onset smooth-step";
  Real s_off "Disturbance offset smooth-step";
  Real tau1 "Segment-1 normalized time";
  Real s1 "Segment-1 min-jerk position";
  Real ds1 "Segment-1 min-jerk velocity";
  Real dds1 "Segment-1 min-jerk acceleration";
  Real tau2 "Segment-2 normalized time";
  Real s2 "Segment-2 min-jerk position";
  Real ds2 "Segment-2 min-jerk velocity";
  Real dds2 "Segment-2 min-jerk acceleration";

equation
  // ===== Trajectory: minimum-jerk two segments =====
  tau1 = time / T_seg1;
  s1 = 10*tau1^3 - 15*tau1^4 + 6*tau1^5;
  ds1 = 30*tau1^2 - 60*tau1^3 + 30*tau1^4;
  dds1 = 60*tau1 - 180*tau1^2 + 120*tau1^3;

  tau2 = (time - T_seg1) / T_seg2;
  s2 = 10*tau2^3 - 15*tau2^4 + 6*tau2^5;
  ds2 = 30*tau2^2 - 60*tau2^3 + 30*tau2^4;
  dds2 = 60*tau2 - 180*tau2^2 + 120*tau2^3;

  theta_b_ref = if time <= T_seg1 then
      theta_b0 + (theta_b1 - theta_b0)*s1
    else
      theta_b1 + (theta_b2 - theta_b1)*s2;

  omega_b_ref = if time <= T_seg1 then
      (theta_b1 - theta_b0)/T_seg1 * ds1
    else
      (theta_b2 - theta_b1)/T_seg2 * ds2;

  alpha_b_ref = if time <= T_seg1 then
      (theta_b1 - theta_b0)/(T_seg1*T_seg1) * dds1
    else
      (theta_b2 - theta_b1)/(T_seg2*T_seg2) * dds2;

  // ===== Disturbance: smooth step over middle third =====
  s_on = 0.5*(1.0 + tanh((time - t_dist_on)/t_blend));
  s_off = 0.5*(1.0 + tanh((time - t_dist_off)/t_blend));
  Fdist_actual = Fdist_amp * (s_on - s_off);

  // ===== Cylinder stroke mapping =====
  x_b = x0_b + rb*(theta_b - theta_b0);
  x_s = x0_s + rs*(theta_s - theta_s_ref);
  v_pist_b = rb*omega_b;
  v_pist_s = rs*omega_s;

  // ===== Chamber volumes =====
  Va_b = Va0_b + A_p_b*x_b;
  Vb_b = Vb0_b + A_r_b*(stroke_b - x_b);
  Va_s = Va0_s + A_p_s*x_s;
  Vb_s = Vb0_s + A_r_s*(stroke_s - x_s);

  // ===== Internal leakage (piston-bypass) =====
  Qleak_b = Cleak_b*(pA_b - pB_b);
  Qleak_s = Cleak_s*(pA_s - pB_s);

  // ===== Chamber pressure dynamics (continuity) =====
  der(pA_b) = beta/Va_b * (u_b - A_p_b*v_pist_b - Qleak_b);
  der(pB_b) = beta/Vb_b * (-u_b*(A_r_b/A_p_b) + A_r_b*v_pist_b + Qleak_b);
  der(pA_s) = beta/Va_s * (u_s - A_p_s*v_pist_s - Qleak_s);
  der(pB_s) = beta/Vb_s * (-u_s*(A_r_s/A_p_s) + A_r_s*v_pist_s + Qleak_s);

  // ===== Cylinder forces =====
  F_b = pA_b*A_p_b - pB_b*A_r_b;
  F_s = pA_s*A_p_s - pB_s*A_r_s;

  // ===== Actuator torques (with viscous friction) =====
  tau_b = F_b*rb - bvisc_b*v_pist_b*rb;
  tau_s = F_s*rs - bvisc_s*v_pist_s*rs;

  // ===== Gravity torques =====
  tau_grav_b = (mb*g*Lb/2 + (ms+mpay)*g*Lb)*cos(theta_b)
             + (ms*g*Ls/2 + mpay*g*Ls)*cos(theta_b + theta_s);
  tau_grav_s = (ms*g*Ls/2 + mpay*g*Ls)*cos(theta_b + theta_s);

  // ===== Payload kinematics =====
  xp = Lb*cos(theta_b) + Ls*cos(theta_b + theta_s);
  yp = Lb*sin(theta_b) + Ls*sin(theta_b + theta_s);
  xp_ref = Lb*cos(theta_b_ref) + Ls*cos(theta_b_ref + theta_s_ref);
  yp_ref = Lb*sin(theta_b_ref) + Ls*sin(theta_b_ref + theta_s_ref);
  vp_x = -Lb*sin(theta_b)*omega_b - Ls*sin(theta_b + theta_s)*(omega_b + omega_s);
  vp_y =  Lb*cos(theta_b)*omega_b + Ls*cos(theta_b + theta_s)*(omega_b + omega_s);
  vp_mag = sqrt(vp_x*vp_x + vp_y*vp_y + 1.0e-12);

  // ===== Disturbance torque (vertical force at payload) =====
  tau_dist = Fdist_actual * xp;

  // ===== Mechanical dynamics =====
  der(theta_b) = omega_b;
  der(omega_b) = alpha_b;
  Jb*alpha_b = tau_b - tau_grav_b - tau_dist;

  der(theta_s) = omega_s;
  Js*der(omega_s) = tau_s - tau_grav_s;

  // ===== Integral with anti-windup clamp =====
  der(integ_err) = (theta_b_ref - theta_b) * (if abs(integ_err) < integ_max then 1.0 else 0.0);

  // ===== Feedforward and load pressure =====
  Qff_b = A_p_b*rb*omega_b_ref;
  pload_b = pA_b - pB_b*(A_r_b/A_p_b);
  pload_ff_b = (Jb*alpha_b_ref
               + (mb*g*Lb/2 + (ms+mpay)*g*Lb)*cos(theta_b_ref)
               + (ms*g*Ls/2 + mpay*g*Ls)*cos(theta_b_ref + theta_s_ref))
               / (A_p_b*rb);

  // ===== ZOH command propagation =====
  u_b = u_b_d;
  u_s = u_s_d;
  Qpump_cmd = Qpump_cmd_d;

  // ===== Pump draw (positive flow from supply) =====
  Qdraw_b = if u_b > 0.0 then u_b else -u_b*(A_r_b/A_p_b);
  Qdraw_s = if u_s > 0.0 then u_s else -u_s*(A_r_s/A_p_s);

  // ===== Load sensing and relief =====
  pload_max = max(pA_b, max(pB_b, max(pA_s, pB_s)));
  ps_target = min(pload_max + pmargin, p_relief);
  Qrelief = Krelief * max(0.0, ps - p_relief);
  der(ps) = beta/Vs_line * (Qpump_cmd - Qdraw_b - Qdraw_s - Qrelief - Qleak_pump);

  // ===== Sampled feedforward flow controller with pressure-position feedback =====
  when sample(0, dt) then
    u_b_d = max(-Qmax, min(Qmax,
      Qff_b
      + Kp_pos*(theta_b_ref - theta_b)
      + Kd_pos*(omega_b_ref - omega_b)
      + Ki_pos*integ_err
      + Kp_pres*(pload_b - pload_ff_b)));
    u_s_d = max(-u_s_max, min(u_s_max,
      Kp_s*(theta_s_ref - theta_s) - Kd_s*omega_s));
    Qpump_cmd_d = max(0.0, min(Qmax,
      (if u_b_d > 0.0 then u_b_d else -u_b_d*(A_r_b/A_p_b))
      + (if u_s_d > 0.0 then u_s_d else -u_s_d*(A_r_s/A_p_s))
      + Kp_ls*(ps_target - ps)));
  end when;

  // ===== Tracking error (Euclidean at payload, guarded) =====
  ep = sqrt(max((xp - xp_ref)*(xp - xp_ref) + (yp - yp_ref)*(yp - yp_ref), 1.0e-12));

  // ===== Synchronized sensor time =====
  sensor_time = time;

  // ===== Bounds (0 = satisfied, 1 = violated) =====
  b_travel_b = if (x_b < 0.0 or x_b > stroke_b) then 1.0 else 0.0;
  b_travel_s = if (x_s < 0.0 or x_s > stroke_s) then 1.0 else 0.0;
  b_pressure = if (ps > p_relief*1.05 or pA_b > p_relief or pB_b > p_relief
                   or pA_s > p_relief or pB_s > p_relief) then 1.0 else 0.0;
  b_flow = if abs(Qpump_cmd) > Qmax*1.01 then 1.0 else 0.0;
  b_accel = if abs(alpha_b) > alpha_max then 1.0 else 0.0;
  b_traj_err = if (time > 7.8 and ep > 0.019) then 1.0 else 0.0;
  b_relief = if Qrelief < -1.0e-9 then 1.0 else 0.0;
  b_no_nan = if (abs(ep) > 1.0e6 or abs(ps) > 1.0e12 or abs(theta_b) > 1.0e3 or abs(Qpump_cmd) > 1.0e3 or abs(u_b) > 1.0e3 or abs(pA_b) > 1.0e12 or abs(omega_b) > 1.0e3) then 1.0 else 0.0;

  // ===== Terminal assertions =====
  when terminal() then
    assert(ep <= 0.019, "Primary tracking error exceeds 0.019 m at final time");
    assert(b_no_nan < 0.5, "NaN or infinite value detected in physical/control/estimator traces");
    assert(b_pressure < 0.5, "Pressure bound violated");
    assert(b_travel_b < 0.5 and b_travel_s < 0.5, "Cylinder travel bound violated");
    assert(b_flow < 0.5, "Flow command bound violated");
    assert(b_relief < 0.5, "Relief valve bound violated");
  end when;

  annotation(
    experiment(StartTime=0, StopTime=12, Tolerance=1.0e-6, Interval=1.0/125.0),
    Documentation(info="HydBoomTrackC: feedforward flow control with pressure-position feedback for a two-cylinder hydraulic actuator on a shared load-sensing pump and relief valve."));
end HydBoomTrackC;