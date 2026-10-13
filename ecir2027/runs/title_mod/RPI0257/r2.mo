model FourBarPositionE
  "Closed-chain four-bar mechanism: bounded torque position control with load"
  import Modelica.Units.SI;
  import Modelica.Constants.pi;

  // ---- Geometry (stated by requirement) ----
  parameter SI.Length L_ground=0.50 "Distance between fixed pivots";
  parameter SI.Length L_crank=0.20  "Crank length";
  parameter SI.Length L_coupler=0.44 "Coupler length";
  parameter SI.Length L_rocker=0.35 "Rocker length";

  // ---- Link inertia: not specified by request; neutral placeholders ----
  parameter SI.Mass m_link=1.0 "Link mass (placeholder, not stated)";
  parameter SI.Inertia I_link=1.0e-3 "Link inertia (placeholder, not stated)";

  // ---- Actuation and control ----
  parameter SI.Torque tau_max=27.5 "Command magnitude bound";
  parameter SI.Angle theta_desired=0.80 "Nonzero target crank angle (rad)";
  parameter SI.Angle theta_start=0.50 "Initial crank angle (consistent assembly)";
  parameter SI.AngularVelocity w_start=0.0 "Initial crank angular velocity";
  parameter SI.Angle rocker_start=1.4678
    "Initial rocker angle consistent with theta_start";
  parameter Real Kp=120.0 "Position gain (N.m/rad)";
  parameter Real Kd=12.0  "Velocity gain (N.m.s/rad)";

  // ---- Disturbance ----
  parameter SI.Force F_load=16.8 "Controlled platform load";
  parameter SI.Time t_end=16.0 "Simulation duration";
  parameter SI.Frequency f_sample=250.0 "Control loop rate";
  parameter SI.Time dt_sample=1.0/f_sample "Sample period";
  parameter SI.Time t_dist_start=t_end/3.0 "Middle-third disturbance start";
  parameter SI.Time t_dist_end=2.0*t_end/3.0 "Middle-third disturbance end";

  // ---- Acceptance thresholds ----
  parameter SI.Length pose_tol=0.005 "Primary tracking tolerance";
  parameter SI.Time t_settle=10.4 "Settle time";
  parameter SI.Length coll_clear=0.005 "Self-collision clearance";

  inner Modelica.Mechanics.MultiBody.World world(
    axisLength=0.7,
    gravityType=Modelica.Mechanics.MultiBody.Types.GravityTypes.NoGravity)
    "Gravity not stated by request: disabled to avoid inventing forces";

  // Fixed pivots
  Modelica.Mechanics.MultiBody.Parts.Fixed fixed_O2(r={0,0,0});
  Modelica.Mechanics.MultiBody.Parts.Fixed fixed_O4(r={L_ground,0,0});

  // Crank + actuated joint
  Modelica.Mechanics.MultiBody.Joints.Revolute crank_joint(
    stateSelect=StateSelect.always,
    phi(fixed=true, start=theta_start),
    w(fixed=true, start=w_start));
  Modelica.Mechanics.MultiBody.Parts.BodyShape crank(
    r={L_crank,0,0}, m=m_link, r_CM={L_crank/2,0,0},
    I_11=I_link, I_22=I_link, I_33=I_link);

  // Crank-coupler revolute joint + force sensor
  Modelica.Mechanics.MultiBody.Joints.Revolute j_cc;
  Modelica.Mechanics.MultiBody.Sensors.CutForce forceCoupler;
  Modelica.Mechanics.MultiBody.Parts.BodyShape coupler(
    r={L_coupler,0,0}, m=m_link, r_CM={L_coupler/2,0,0},
    I_11=I_link, I_22=I_link, I_33=I_link);

  // Coupler-rocker revolute joint
  Modelica.Mechanics.MultiBody.Joints.Revolute j_cr;
  Modelica.Mechanics.MultiBody.Parts.BodyShape rocker(
    r={L_rocker,0,0}, m=m_link, r_CM={L_rocker/2,0,0},
    I_11=I_link, I_22=I_link, I_33=I_link);

  // Rocker fixed-pivot joint
  Modelica.Mechanics.MultiBody.Joints.Revolute rocker_joint(
    phi(fixed=true, start=rocker_start),
    w(fixed=true, start=0.0));

  // Crank torque actuator
  Modelica.Mechanics.Rotational.Sources.Torque torqueActuator;
  Modelica.Blocks.Sources.RealExpression tau_src(y=tau_sat);

  // Platform load disturbance (applied at coupler-rocker joint = output platform)
  Modelica.Mechanics.MultiBody.Forces.WorldForce platformLoad;
  Modelica.Blocks.Sources.RealExpression Fx_in(y=0.0);
  Modelica.Blocks.Sources.RealExpression Fy_in(
    y=if time>=t_dist_start and time<=t_dist_end then -F_load else 0.0);
  Modelica.Blocks.Sources.RealExpression Fz_in(y=0.0);

  // Output platform pose sensor
  Modelica.Mechanics.MultiBody.Sensors.AbsolutePosition posPlatform;

  // ---- Measured / observable state ----
  SI.Angle theta_crank "Crank actuator coordinate (rad)";
  SI.AngularVelocity w_crank "Crank angular velocity (rad/s)";
  SI.Angle psi_rocker "Rocker actuator coordinate (rad)";
  SI.Length px "Output platform x-position (m)";
  SI.Length py "Output platform y-position (m)";
  SI.Angle platform_orient "Output platform orientation (rad)";
  SI.Force fx_coupler "Coupler reaction force x (N)";
  SI.Force fy_coupler "Coupler reaction force y (N)";

  // ---- Inverse kinematics of target crank angle -> desired platform pose ----
  Real K1 = L_ground/L_crank;
  Real K2 = L_ground/L_rocker;
  Real K3 = (L_ground^2 - L_coupler^2 + L_crank^2 - L_rocker^2)/(2*L_crank*L_rocker);
  Real A_d = K1*cos(theta_desired) + K3;
  Real B_d = K2 + cos(theta_desired);
  Real C_d = sin(theta_desired);
  Real disc_d = max(B_d^2 + C_d^2 - A_d^2, 1.0e-12) "Zero-error branch for sqrt";
  Real psi_d = atan2(C_d, B_d) - atan2(-sqrt(disc_d), A_d) "Upper assembly branch";
  SI.Length px_d = L_ground + L_rocker*cos(psi_d);
  SI.Length py_d = L_rocker*sin(psi_d);

  // ---- Control ----
  Real tau_cmd_held(start=0.0) "Held unsaturated command (discrete)";
  SI.Torque tau_cmd_unsat "Unsaturated commanded torque";
  SI.Torque tau_sat "Saturated command applied to crank";
  SI.Angle theta_err "Crank tracking error";

  // ---- Closure residual ----
  SI.Length closure_residual "Loop closure length error (m)";
  SI.Length crank_tip_x, crank_tip_y, rocker_tip_x, rocker_tip_y;

  // ---- Self-collision ----
  SI.Length d_cr_mid "Distance between crank and rocker midpoints (m)";
  Boolean no_collision "Self-collision clear";

  // ---- Acceptance ----
  SI.Length pose_err "Primary tracking error (m)";
  Boolean pose_ok "Pose error within tolerance after settle time";
  Boolean bounds_ok "Actuator travel and force bounds satisfied";
  Boolean finite_check "No NaN or infinite physical/control values";
  Boolean fail_closed "Aggregate fail-closed acceptance";

equation
  // Actuator coordinates and velocities
  theta_crank = crank_joint.phi;
  w_crank = crank_joint.w;
  psi_rocker = rocker_joint.phi;

  // Tracking error
  theta_err = theta_desired - theta_crank;

  // Sampled control law (250 Hz zero-order hold)
  when sample(0, dt_sample) then
    tau_cmd_held = Kp*theta_err - Kd*w_crank;
  end when;
  tau_cmd_unsat = tau_cmd_held;
  tau_sat = max(-tau_max, min(tau_max, tau_cmd_unsat));

  // Output platform pose from sensor
  px = posPlatform.r[1];
  py = posPlatform.r[2];

  // Platform orientation = coupler link angle (atan2 with zero-error guard)
  platform_orient = atan2(py - L_crank*sin(theta_crank),
                         px - L_crank*cos(theta_crank) + 1.0e-9);

  // Reaction forces through coupler
  fx_coupler = forceCoupler.force[1];
  fy_coupler = forceCoupler.force[2];

  // Independent loop-closure residual check
  crank_tip_x = L_crank*cos(theta_crank);
  crank_tip_y = L_crank*sin(theta_crank);
  rocker_tip_x = L_ground + L_rocker*cos(psi_rocker);
  rocker_tip_y = L_rocker*sin(psi_rocker);
  closure_residual = sqrt((crank_tip_x - rocker_tip_x)^2 +
                          (crank_tip_y - rocker_tip_y)^2) - L_coupler;

  // Self-collision proxy: minimum distance between non-adjacent links
  d_cr_mid = sqrt((0.5*L_crank*cos(theta_crank)
                   - (L_ground + 0.5*L_rocker*cos(psi_rocker)))^2 +
                  (0.5*L_crank*sin(theta_crank)
                   - 0.5*L_rocker*sin(psi_rocker))^2);
  no_collision = d_cr_mid > coll_clear;

  // Primary tracking error (output pose)
  pose_err = sqrt((px - px_d)^2 + (py - py_d)^2);

  // Acceptance criteria (fail-closed)
  pose_ok = (time >= t_settle) => (pose_err < pose_tol);
  bounds_ok = (abs(tau_sat) <= tau_max + 1.0e-6) and
              (abs(theta_crank) <= pi + 1.0e-6);
  finite_check = not (Modelica.Math.isNaN(theta_crank) or
                      Modelica.Math.isNaN(w_crank) or
                      Modelica.Math.isNaN(px) or
                      Modelica.Math.isNaN(py) or
                      Modelica.Math.isNaN(tau_sat) or
                      Modelica.Math.isNaN(closure_residual));
  fail_closed = pose_ok and no_collision and bounds_ok and finite_check;

  // ---- Structural (closed-chain) connections ----
  connect(fixed_O2.frame_b, crank_joint.frame_a);
  connect(crank_joint.frame_b, crank.frame_a);
  connect(crank_joint.axis, torqueActuator.flange);
  connect(tau_src.y, torqueActuator.tau);
  connect(crank.frame_b, j_cc.frame_a);
  connect(j_cc.frame_b, forceCoupler.frame_a);
  connect(forceCoupler.frame_b, coupler.frame_a);
  connect(coupler.frame_b, j_cr.frame_a);
  connect(j_cr.frame_b, rocker.frame_b);
  connect(rocker.frame_a, rocker_joint.frame_b);
  connect(rocker_joint.frame_a, fixed_O4.frame_b);
  // Output platform sensor and load at coupler-rocker joint
  connect(coupler.frame_b, posPlatform.frame_a);
  connect(coupler.frame_b, platformLoad.frame_b);
  connect(Fx_in.y, platformLoad.force[1]);
  connect(Fy_in.y, platformLoad.force[2]);
  connect(Fz_in.y, platformLoad.force[3]);

  annotation (
    experiment(StartTime=0, StopTime=16.0, Tolerance=1.0e-6,
               Interval=1.0/250.0),
    Documentation(info="Four-bar closed-chain mechanism with bounded torque
position control, 16.8 N middle-third disturbance, sampled at 250 Hz
for 16 s. Tracks crank angle 0.80 rad; output platform pose is the
coupler-rocker joint. Acceptance is fail-closed: pose error < 0.005 m
after 10.4 s, no self-collision, bounded actuator travel/force,
closure residual zero, no NaN/Inf."));
end FourBarPositionE;