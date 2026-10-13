model FourBarPositionC
  "Closed-chain four-bar mechanism with position control via constrained inverse kinematics"

  // --- Plant geometry ---
  parameter Modelica.SIunits.Length L_crank = 0.20 "Crank length";
  parameter Modelica.SIunits.Length L_coupler = 0.44 "Coupler length";
  parameter Modelica.SIunits.Length L_rocker = 0.35 "Rocker length";
  parameter Modelica.SIunits.Length L_base = 0.50 "Fixed pivot separation";

  // --- Actuator limits ---
  parameter Modelica.SIunits.Torque tau_max = 23.0 "Maximum crank torque";
  parameter Modelica.SIunits.Force F_dist = 12.6 "Platform disturbance load";

  // --- Link properties ---
  parameter Modelica.SIunits.Mass m_link = 0.5 "Link mass";
  parameter Modelica.SIunits.Inertia I_link = 0.005 "Link inertia diagonal";

  // --- Controller parameters ---
  parameter Modelica.SIunits.Angle theta_target = 1.0471975511966
    "Target crank angle (rad, approx 60 deg)";
  parameter Real kp = 120.0 "Proportional gain";
  parameter Real kd = 12.0 "Derivative gain";
  parameter Modelica.SIunits.Time Ts = 0.008 "Controller sample period (1/125 s)";

  // --- Initial joint angles (consistent four-bar assembly) ---
  parameter Modelica.SIunits.Angle theta0 = 0.1 "Initial crank angle";
  parameter Modelica.SIunits.Angle phi_B0 = 0.7478 "Initial coupler-crank relative angle";
  parameter Modelica.SIunits.Angle phi_D0 = 1.5987 "Initial rocker angle";
  parameter Modelica.SIunits.Angle phi_C0 = 0.7509 "Initial loop joint relative angle";

  // --- Target output pose from forward kinematics at theta_target ---
protected
  parameter Real Bx_t = L_crank * cos(theta_target);
  parameter Real By_t = L_crank * sin(theta_target);
  parameter Real BD_t = sqrt(max(1e-10, (Bx_t - L_base)*(Bx_t - L_base) + By_t*By_t));
  parameter Real cos_alpha_t = max(-1.0, min(1.0,
    (BD_t*BD_t + L_rocker*L_rocker - L_coupler*L_coupler) /
    (2.0 * BD_t * L_rocker)));
  parameter Real alpha_t = acos(cos_alpha_t);
  parameter Real angle_DB_t = atan2(By_t, Bx_t - L_base);
  parameter Real angle_DC_t = angle_DB_t - alpha_t;
  parameter Real Cx_t = L_base + L_rocker * cos(angle_DC_t);
  parameter Real Cy_t = L_rocker * sin(angle_DC_t);

public
  parameter Modelica.SIunits.Position x_target = (Bx_t + Cx_t) / 2.0;
  parameter Modelica.SIunits.Position y_target = (By_t + Cy_t) / 2.0;

  // --- Actuator coordinates (measured) ---
  Modelica.SIunits.Angle theta_crank "Crank angle";
  Modelica.SIunits.Angle theta_rocker "Rocker angle";

  // --- Controller signals ---
  Modelica.SIunits.Torque tau_cmd "Unsaturated command";
  Modelica.SIunits.Torque tau_sat "Saturated command";
  discrete Real err_sampled(start = 0.0) "Sampled angle error";
  discrete Real w_sampled(start = 0.0) "Sampled angular velocity";

  // --- Disturbance ---
  Modelica.SIunits.Force Fx_dist "Disturbance x-component";
  Modelica.SIunits.Force Fy_dist "Disturbance y-component";

  // --- Output pose ---
  Modelica.SIunits.Position x_out "Output platform x";
  Modelica.SIunits.Position y_out "Output platform y";
  Modelica.SIunits.Length pose_error "Pose tracking error";

  // --- Reaction forces ---
  Modelica.SIunits.Force F_react_x "Reaction force x at crank pivot";
  Modelica.SIunits.Force F_react_y "Reaction force y at crank pivot";

  // --- Safety / monitoring ---
  Real closure_residual "Loop closure residual (m)";
  Real min_link_distance "Min crank-rocker midpoint distance (m)";
  Boolean self_collision "Self-collision flag";
  Boolean no_nan_inf "No NaN/Inf flag";
  Boolean tracking_ok "Tracking error within spec";
  Boolean tau_in_bounds "Torque within bounds";
  Boolean force_in_bounds "Disturbance within bounds";

  // --- MultiBody world ---
  inner Modelica.Mechanics.MultiBody.World world(
    enableAnimation = false,
    gravityType = Modelica.Mechanics.MultiBody.Types.GravityTypes.NoGravity);

  // --- Fixed pivots ---
  Modelica.Mechanics.MultiBody.Parts.Fixed fixedA(r = {0, 0, 0});
  Modelica.Mechanics.MultiBody.Parts.Fixed fixedD(r = {L_base, 0, 0});

  // --- Cut force sensor at crank pivot ---
  Modelica.Mechanics.MultiBody.Sensors.CutForce crankPivotForce(
    animation = false,
    resolveInFrame = Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world);

  // --- Four revolute Z joints ---
  // revA: actuated crank pivot; revB: crank-coupler; revC: planar loop joint; revD: rocker pivot
  Modelica.Mechanics.MultiBody.Joints.Revolute revA(
    useAxisFlange = true,
    n = {0, 0, 1},
    stateSelect = StateSelect.always,
    phi(fixed = true, start = theta0),
    w(fixed = true, start = 0.0));

  Modelica.Mechanics.MultiBody.Joints.Revolute revB(
    n = {0, 0, 1},
    stateSelect = StateSelect.avoid,
    phi(start = phi_B0),
    w(start = 0.0));

  Modelica.Mechanics.MultiBody.Joints.RevolutePlanarLoop revC(
    animation = false,
    n = {0, 0, 1});

  Modelica.Mechanics.MultiBody.Joints.Revolute revD(
    n = {0, 0, 1},
    stateSelect = StateSelect.avoid,
    phi(start = phi_D0),
    w(start = 0.0));

  // --- Links (rigid bodies) ---
  Modelica.Mechanics.MultiBody.Parts.BodyShape crank(
    animation = false,
    r = {L_crank, 0, 0},
    r_CM = {L_crank / 2.0, 0, 0},
    m = m_link,
    I_11 = I_link,
    I_22 = I_link,
    I_33 = I_link);

  Modelica.Mechanics.MultiBody.Parts.BodyShape coupler(
    animation = false,
    r = {L_coupler, 0, 0},
    r_CM = {L_coupler / 2.0, 0, 0},
    m = m_link,
    I_11 = I_link,
    I_22 = I_link,
    I_33 = I_link);

  Modelica.Mechanics.MultiBody.Parts.BodyShape rocker(
    animation = false,
    r = {L_rocker, 0, 0},
    r_CM = {L_rocker / 2.0, 0, 0},
    m = m_link,
    I_11 = I_link,
    I_22 = I_link,
    I_33 = I_link);

  // --- Fixed translation to coupler midpoint (output platform) ---
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation couplerMid(
    animation = false,
    r = {L_coupler / 2.0, 0, 0});

  // --- Torque actuator ---
  Modelica.Mechanics.Rotational.Sources.Torque torqueSrc;

  // --- Disturbance force ---
  Modelica.Mechanics.MultiBody.Forces.WorldForce distForce(
    animation = false);

  // --- Position sensors ---
  Modelica.Mechanics.MultiBody.Sensors.AbsolutePosition midPos(
    resolveInFrame = Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world);
  Modelica.Mechanics.MultiBody.Sensors.AbsolutePosition crankTipPos(
    resolveInFrame = Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world);
  Modelica.Mechanics.MultiBody.Sensors.AbsolutePosition rockerTipPos(
    resolveInFrame = Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world);

equation
  // --- Sampled controller at 125 Hz ---
  when sample(0, Ts) then
    err_sampled = theta_target - revA.phi;
    w_sampled = revA.w;
  end when;

  tau_cmd = kp * err_sampled - kd * w_sampled;
  tau_sat = max(-tau_max, min(tau_max, tau_cmd));
  torqueSrc.tau = tau_sat;

  // --- Disturbance force: 12.6 N downward during middle third (4-8 s of 12 s) ---
  if time >= 4.0 and time <= 8.0 then
    Fx_dist = 0.0;
    Fy_dist = -F_dist;
  else
    Fx_dist = 0.0;
    Fy_dist = 0.0;
  end if;
  distForce.force = {Fx_dist, Fy_dist, 0.0};

  // --- Measured actuator coordinates ---
  theta_crank = revA.phi;
  theta_rocker = revD.phi;

  // --- Output pose from sensor ---
  x_out = midPos.r[1];
  y_out = midPos.r[2];

  // --- Pose tracking error against target ---
  pose_error = sqrt(max(0.0,
    (x_out - x_target)*(x_out - x_target) +
    (y_out - y_target)*(y_out - y_target)));

  // --- Loop closure residual: |BC| should equal L_coupler ---
  closure_residual = abs(
    sqrt(max(0.0,
      (crankTipPos.r[1] - rockerTipPos.r[1])*(crankTipPos.r[1] - rockerTipPos.r[1]) +
      (crankTipPos.r[2] - rockerTipPos.r[2])*(crankTipPos.r[2] - rockerTipPos.r[2])))
    - L_coupler);

  // --- Self-collision check: crank-rocker midpoint distance ---
  min_link_distance = sqrt(max(0.0,
    ((crankTipPos.r[1] / 2.0) - ((L_base + rockerTipPos.r[1]) / 2.0)) *
    ((crankTipPos.r[1] / 2.0) - ((L_base + rockerTipPos.r[1]) / 2.0)) +
    ((crankTipPos.r[2] / 2.0) - (rockerTipPos.r[2] / 2.0)) *
    ((crankTipPos.r[2] / 2.0) - (rockerTipPos.r[2] / 2.0))));
  self_collision = min_link_distance < 0.02;

  // --- Reaction forces at crank pivot ---
  F_react_x = crankPivotForce.force[1];
  F_react_y = crankPivotForce.force[2];

  // --- Safety checks ---
  tau_in_bounds = abs(tau_sat) <= tau_max + 1e-6;
  force_in_bounds = abs(Fy_dist) <= F_dist + 1e-6;
  tracking_ok = if time >= 7.8 then pose_error < 0.006 else true;
  no_nan_inf = (abs(x_out) < 1e6) and (abs(y_out) < 1e6) and
               (abs(tau_sat) < 1e6) and (abs(pose_error) < 1e6) and
               (abs(theta_crank) < 1e6) and (abs(theta_rocker) < 1e6) and
               (abs(F_react_x) < 1e6) and (abs(F_react_y) < 1e6);

  // --- Structural connections: closed chain A-B-C-D ---
  // Path: fixedA -> CutForce -> revA -> crank -> revB -> coupler -> revC -> rocker -> revD -> fixedD
  connect(fixedA.frame_b, crankPivotForce.frame_a);
  connect(crankPivotForce.frame_b, revA.frame_a);
  connect(revA.frame_b, crank.frame_a);
  connect(crank.frame_b, revB.frame_a);
  connect(revB.frame_b, coupler.frame_a);
  connect(coupler.frame_b, revC.frame_a);
  connect(revC.frame_b, rocker.frame_b);
  connect(rocker.frame_a, revD.frame_b);
  connect(revD.frame_a, fixedD.frame_b);

  // Actuator torque on crank
  connect(torqueSrc.flange, revA.flange_b);

  // Coupler midpoint: output platform, sensor, and disturbance
  connect(coupler.frame_a, couplerMid.frame_a);
  connect(couplerMid.frame_b, midPos.frame_a);
  connect(couplerMid.frame_b, distForce.frame_b);

  // Tip position sensors for closure and collision checks
  connect(crank.frame_b, crankTipPos.frame_a);
  connect(rocker.frame_b, rockerTipPos.frame_a);

  annotation(
    Documentation(info = "<html>
<p>Closed-chain four-bar mechanism with position control via constrained inverse kinematics.</p>
<p>Geometry: base=0.50 m, crank=0.20 m, coupler=0.44 m, rocker=0.35 m.</p>
<p>Controller: PD on crank angle, sampled at 125 Hz, torque limited to 23 N.m.</p>
<p>Disturbance: 12.6 N downward on coupler midpoint during t=4..8 s.</p>
<p>Target: tracking error below 0.006 m after 7.8 s.</p>
<p>Topology: fixedA-revA-crank-revB-coupler-revC(RevolutePlanarLoop)-rocker-revD-fixedD.</p>
</html>"),
    experiment(StopTime = 12.0, Tolerance = 1e-6));
end FourBarPositionC;