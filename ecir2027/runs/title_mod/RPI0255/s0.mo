model FourBarPositionC
  "Closed-chain four-bar mechanism with position control via constrained inverse kinematics"

  // --- Plant geometry ---
  parameter Modelica.SIunits.Length L_crank = 0.20 "Crank length (m)";
  parameter Modelica.SIunits.Length L_coupler = 0.44 "Coupler length (m)";
  parameter Modelica.SIunits.Length L_rocker = 0.35 "Rocker length (m)";
  parameter Modelica.SIunits.Length L_base = 0.50 "Fixed pivot separation (m)";

  // --- Actuator limits ---
  parameter Modelica.SIunits.Torque tau_max = 23.0 "Maximum crank torque (N.m)";
  parameter Modelica.SIunits.Force F_dist = 12.6 "Platform disturbance load (N)";

  // --- Link properties ---
  parameter Modelica.SIunits.Mass m_link = 0.5 "Link mass (kg)";
  parameter Modelica.SIunits.Inertia I_diag = 0.005 "Link inertia diagonal (kg.m^2)";

  // --- Controller parameters ---
  parameter Modelica.SIunits.Angle theta_target = 1.0471975511966
    "Target crank angle ~60 deg (rad)";
  parameter Real kp = 120.0 "Proportional gain";
  parameter Real kd = 12.0 "Derivative gain";
  parameter Modelica.SIunits.Time Ts = 1.0 / 125.0 "Controller sample period (s)";

  // --- Target output pose from forward kinematics at theta_target ---
  protected
  parameter Real Bx_t = L_crank * cos(theta_target);
  parameter Real By_t = L_crank * sin(theta_target);
  parameter Real BD_t = sqrt(max(1e-10, (Bx_t - L_base)^2 + By_t^2));
  parameter Real cos_alpha_t = max(-1.0, min(1.0, (BD_t^2 + L_rocker^2 - L_coupler^2) / (2 * BD_t * L_rocker)));
  parameter Real alpha_t = acos(cos_alpha_t);
  parameter Real angle_DB_t = atan2(By_t, Bx_t - L_base);
  parameter Real angle_DC_t = angle_DB_t - alpha_t;
  parameter Real Cx_t = L_base + L_rocker * cos(angle_DC_t);
  parameter Real Cy_t = L_rocker * sin(angle_DC_t);

  public
  parameter Modelica.SIunits.Position x_target = (Bx_t + Cx_t) / 2;
  parameter Modelica.SIunits.Position y_target = (By_t + Cy_t) / 2;

  // --- Actuator coordinates (measured) ---
  Modelica.SIunits.Angle theta_crank "Crank angle (rad)";
  Modelica.SIunits.Angle theta_rocker "Rocker angle (rad)";

  // --- Controller signals ---
  Modelica.SIunits.Torque tau_cmd "Unsaturated command (N.m)";
  Modelica.SIunits.Torque tau_sat "Saturated command (N.m)";
  Real err_sampled(start = 0) "Sampled angle error (rad)";
  Real w_sampled(start = 0) "Sampled angular velocity (rad/s)";

  // --- Disturbance ---
  Modelica.SIunits.Force Fx_dist "Disturbance x-component (N)";
  Modelica.SIunits.Force Fy_dist "Disturbance y-component (N)";

  // --- Output pose ---
  Modelica.SIunits.Position x_out "Output platform x (m)";
  Modelica.SIunits.Position y_out "Output platform y (m)";
  Modelica.SIunits.Length pose_error "Pose tracking error (m)";

  // --- Reaction forces ---
  Modelica.SIunits.Force F_react_x "Reaction force x at crank pivot (N)";
  Modelica.SIunits.Force F_react_y "Reaction force y at crank pivot (N)";

  // --- Safety / monitoring ---
  Real closure_residual "Loop closure residual (m)";
  Real min_link_distance "Min crank-rocker midpoint distance (m)";
  Boolean self_collision "Self-collision flag";
  Boolean no_nan_inf "No NaN/Inf flag";
  Boolean tracking_ok "Tracking error within spec";
  Boolean tau_in_bounds "Torque within bounds";
  Boolean force_in_bounds "Disturbance within bounds";

  // --- MultiBody world ---
  inner Modelica.Mechanics.MultiBody.World world(enableAnimation = false);

  // --- Fixed pivots ---
  Modelica.Mechanics.MultiBody.Components.Fixed fixedA(r = {0, 0, 0});
  Modelica.Mechanics.MultiBody.Components.Fixed fixedD(r = {L_base, 0, 0});

  // --- Cut force sensor at crank pivot ---
  Modelica.Mechanics.MultiBody.Sensors.CutForce crankPivotForce(
    resolveInFrame = Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world);

  // --- Four revolute Z joints ---
  Modelica.Mechanics.MultiBody.Joints.Revolute revA(
    useAxisFlange = true,
    n = {0, 0, 1},
    phi(fixed = true, start = 0.1),
    w(fixed = true, start = 0));
  Modelica.Mechanics.MultiBody.Joints.Revolute revB(
    n = {0, 0, 1},
    phi(start = 0.7),
    w(start = 0));
  Modelica.Mechanics.MultiBody.Joints.RevolutePlanarLoop revC(
    n = {0, 0, 1},
    phi_start = 0.75);
  Modelica.Mechanics.MultiBody.Joints.Revolute revD(
    n = {0, 0, 1},
    phi(start = 1.6),
    w(start = 0));

  // --- Links (rigid bodies) ---
  Modelica.Mechanics.MultiBody.Parts.BodyShape crank(
    r = {L_crank, 0, 0},
    r_CM = {L_crank / 2, 0, 0},
    m = m_link,
    I_11 = I_diag, I_22 = I_diag, I_33 = I_diag);
  Modelica.Mechanics.MultiBody.Parts.BodyShape coupler(
    r = {L_coupler, 0, 0},
    r_CM = {L_coupler / 2, 0, 0},
    m = m_link,
    I_11 = I_diag, I_22 = I_diag, I_33 = I_diag);
  Modelica.Mechanics.MultiBody.Parts.BodyShape rocker(
    r = {L_rocker, 0, 0},
    r_CM = {L_rocker / 2, 0, 0},
    m = m_link,
    I_11 = I_diag, I_22 = I_diag, I_33 = I_diag);

  // --- Fixed translation to coupler midpoint (output platform) ---
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation couplerMid(r = {L_coupler / 2, 0, 0});

  // --- Torque actuator ---
  Modelica.Mechanics.Rotational.Sources.Torque torqueSrc;

  // --- Disturbance force ---
  Modelica.Mechanics.MultiBody.Forces.WorldForce distForce;

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

  // --- Pose tracking error against target from inverse kinematics ---
  pose_error = sqrt((x_out - x_target)^2 + (y_out - y_target)^2);

  // --- Loop closure residual: |BC| should equal L_coupler ---
  closure_residual = abs(
    sqrt((crankTipPos.r[1] - rockerTipPos.r[1])^2 +
         (crankTipPos.r[2] - rockerTipPos.r[2])^2) - L_coupler);

  // --- Self-collision check: crank-rocker midpoint distance ---
  min_link_distance = sqrt(
    ((crankTipPos.r[1] / 2) - ((L_base + rockerTipPos.r[1]) / 2))^2 +
    ((crankTipPos.r[2] / 2) - (rockerTipPos.r[2] / 2))^2);
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
  // Crank path: fixedA -> cutForce -> revA -> crank -> revB -> coupler -> revC
  connect(fixedA.frame, crankPivotForce.frame_a);
  connect(crankPivotForce.frame_b, revA.frame_a);
  connect(revA.frame_b, crank.frame_a);
  connect(crank.frame_b, revB.frame_a);
  connect(revB.frame_b, coupler.frame_a);
  connect(revB.frame_b, couplerMid.frame_a);
  connect(coupler.frame_b, revC.frame_a);
  // Rocker path: fixedD -> revD -> rocker -> revC (closes loop)
  connect(revC.frame_b, rocker.frame_b);
  connect(rocker.frame_a, revD.frame_b);
  connect(revD.frame_a, fixedD.frame);
  // Actuator torque on crank
  connect(torqueSrc.flange, revA.flange_b);
  // Sensors and disturbance at coupler midpoint
  connect(couplerMid.frame_b, midPos.frame_a);
  connect(couplerMid.frame_b, distForce.frame_b);
  // Tip position sensors for closure and collision checks
  connect(crank.frame_b, crankTipPos.frame_a);
  connect(rocker.frame_b, rockerTipPos.frame_a);

  annotation(
    Documentation(info = "<html>
<p>Closed-chain four-bar mechanism with position control.</p>
<p>Geometry: base=0.50 m, crank=0.20 m, coupler=0.44 m, rocker=0.35 m.</p>
<p>Controller: PD on crank angle, sampled at 125 Hz, torque limited to 23 N.m.</p>
<p>Disturbance: 12.6 N downward on coupler midpoint during t=4..8 s.</p>
<p>Target: tracking error below 0.006 m after 7.8 s.</p>
</html>"),
    experiment(StopTime = 12.0, Tolerance = 1e-6));
end FourBarPositionC;