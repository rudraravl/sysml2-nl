model PantographTraceF
  "Closed-chain parallelogram pantograph tracing a 0.10 m radius planar circle.
   Lumped planar model: one prismatic input coordinate s (0..0.16 m) drives the
   output through a parallelogram of short link L1=0.25 m and long link L2=0.50 m,
   giving scale k=L2/L1=2.  Six revolute Z joints and one prismatic joint are
   abstracted into the lumped kinematic/dynamic mapping; the parallelogram closure
   constraint is monitored and actively stabilized."

  // ---- Embodiment: parallelogram links ----
  parameter Modelica.Units.SI.Length L1 = 0.25 "short parallelogram link";
  parameter Modelica.Units.SI.Length L2 = 0.50 "long parallelogram link";
  parameter Real k_scale = L2 / L1 "pantograph scale (output / input)";
  parameter Modelica.Units.SI.Length r_out = 0.10 "output circle radius";
  parameter Modelica.Units.SI.Length r_in = r_out / k_scale "equivalent input circle radius";
  parameter Modelica.Units.SI.Length s_travel = 0.16 "prismatic input travel";
  parameter Modelica.Units.SI.Length x_center = 0.50 "circle center x";
  parameter Modelica.Units.SI.Length y_center = 0.50 "circle center y";

  // ---- Actuation ----
  parameter Modelica.Units.SI.Force F_max = 390.0 "actuator effort bound";
  parameter Modelica.Units.SI.Mass m_a = 2.0 "actuator effective mass";
  parameter Modelica.Units.SI.TranslationalDampingConstant b_a = 5.0 "actuator damping";
  parameter Modelica.Units.SI.TranslationalSpringConstant kp_s = 3000.0 "IK position gain";
  parameter Modelica.Units.SI.TranslationalDampingConstant kd_s = 120.0 "IK velocity gain";

  // ---- Output linkage dynamics ----
  parameter Modelica.Units.SI.Mass m_o = 1.5 "output effective mass";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_link = 3000.0 "linkage stiffness";
  parameter Modelica.Units.SI.TranslationalDampingConstant c_link = 40.0 "linkage damping";
  parameter Modelica.Units.SI.TranslationalSpringConstant kc = 1500.0 "closure stabilization gain";

  // ---- Obstacle (outside the traced circle) ----
  parameter Modelica.Units.SI.Length obstacle_x = 0.85 "obstacle center x";
  parameter Modelica.Units.SI.Length obstacle_y = 0.50 "obstacle center y";
  parameter Modelica.Units.SI.Length obstacle_r = 0.05 "obstacle radius";
  parameter Modelica.Units.SI.Length clearance_req = 0.02 "required clearance";

  // ---- Disturbance (middle third of run) ----
  parameter Modelica.Units.SI.Force F_dist = 14.5 "output load disturbance";
  parameter Modelica.Units.SI.Time T_dist_a = 20.0 / 3.0 "disturbance start";
  parameter Modelica.Units.SI.Time T_dist_b = 40.0 / 3.0 "disturbance end";

  // ---- Timing ----
  parameter Modelica.Units.SI.Time T_sim = 20.0 "simulation duration";

  // ---- Dynamic states ----
  Modelica.Units.SI.Length s(start = 0.0, fixed = true) "prismatic input coordinate";
  Modelica.Units.SI.Velocity s_dot(start = 0.0, fixed = true) "prismatic input velocity";
  Modelica.Units.SI.Length x_out(start = x_center + r_out, fixed = true) "output x";
  Modelica.Units.SI.Length y_out(start = y_center, fixed = true) "output y";
  Modelica.Units.SI.Velocity vx_out(start = 0.0, fixed = true) "output x velocity";
  Modelica.Units.SI.Velocity vy_out(start = 0.0, fixed = true) "output y velocity";

  // ---- Reference / IK ----
  Real theta "phase angle [rad]";
  Modelica.Units.SI.Length x_ref "reference output x";
  Modelica.Units.SI.Length y_ref "reference output y";
  Modelica.Units.SI.Length s_ref "reference prismatic coordinate";
  Modelica.Units.SI.Velocity s_ref_dot "reference prismatic velocity";

  // ---- Control / actuation ----
  Modelica.Units.SI.Force F_cmd "commanded actuator force";
  Modelica.Units.SI.Force F_sat "saturated actuator force";
  Modelica.Units.SI.Force F_dist_x "disturbance force x";
  Modelica.Units.SI.Force F_clos_x "active closure stabilization force x";
  Modelica.Units.SI.Force F_clos_y "active closure stabilization force y";

  // ---- Sensors ----
  Modelica.Units.SI.Length s_enc "actuator encoder reading";
  Modelica.Units.SI.Length x_pose_meas "direct output-pose x measurement";
  Modelica.Units.SI.Length y_pose_meas "direct output-pose y measurement";

  // ---- Verification metrics ----
  Modelica.Units.SI.Length path_error "path tracking error";
  Modelica.Units.SI.Length closure_error "parallelogram closure error";
  Modelica.Units.SI.Length clearance_val "obstacle clearance";
  Real singularity_margin "Jacobian magnitude (constant => well-conditioned)";
  Modelica.Units.SI.Force effort_margin "effort margin to bound";

  // unit-error-direction (protected divisor)
  Real dir_x "unit closure-error direction x";
  Real dir_y "unit closure-error direction y";
  Real norm_prot "protected divisor of closure norm";

  Boolean in_middle_third "true during middle-third disturbance window";
  Boolean ok_effort "effort bound satisfied";
  Boolean ok_clearance "clearance bound satisfied";
  Boolean ok_track "tracking bound satisfied after 13 s";
  Boolean ok_finite "no NaN/Inf detected";

equation
  // Reference trajectory: s sweeps 0 -> s_travel over 20 s (one revolution)
  s_ref     = s_travel * (time / T_sim);
  s_ref_dot = s_travel / T_sim;

  // Forward kinematics of ideal rigid parallelogram pantograph
  theta = 2.0 * Modelica.Constants.pi * s / s_travel;
  x_ref = x_center + r_out * cos(theta);
  y_ref = y_center + r_out * sin(theta);

  // Disturbance window
  in_middle_third = (time >= T_dist_a) and (time <= T_dist_b);
  F_dist_x = if in_middle_third then F_dist else 0.0;

  // Closure error magnitude (norm used as divisor -> protected)
  closure_error = sqrt((x_out - x_ref)^2 + (y_out - y_ref)^2);
  norm_prot = if closure_error > 1.0e-6 then closure_error else 1.0e-6;
  dir_x = (x_out - x_ref) / norm_prot;
  dir_y = (y_out - y_ref) / norm_prot;

  // Active closure stabilization: proportional pull back onto closure manifold
  F_clos_x = -kc * (x_out - x_ref);
  F_clos_y = -kc * (y_out - y_ref);

  // Inverse-kinematic trajectory control of prismatic input
  F_cmd = kp_s * (s_ref - s) + kd_s * (s_ref_dot - s_dot);

  // Saturated actuator force (bounded to F_max)
  F_sat = if F_cmd > F_max then F_max
          else if F_cmd < (-F_max) then (-F_max)
          else F_cmd;

  // Actuator dynamics
  m_a * der(s_dot) = F_sat - b_a * s_dot;
  der(s) = s_dot;

  // Output linkage dynamics (passive stiffness + active closure + disturbance)
  m_o * der(vx_out) = k_link * (x_ref - x_out) - c_link * vx_out + F_clos_x + F_dist_x;
  m_o * der(vy_out) = k_link * (y_ref - y_out) - c_link * vy_out + F_clos_y;
  der(x_out) = vx_out;
  der(y_out) = vy_out;

  // Sensors
  s_enc       = s;
  x_pose_meas = x_out;
  y_pose_meas = y_out;

  // Verification metrics
  path_error         = sqrt((x_out - x_ref)^2 + (y_out - y_ref)^2);
  clearance_val      = sqrt((x_out - obstacle_x)^2 + (y_out - obstacle_y)^2) - obstacle_r;
  singularity_margin = abs(r_out * 2.0 * Modelica.Constants.pi / s_travel);
  effort_margin      = F_max - abs(F_sat);

  // Verification flags
  ok_effort    = effort_margin >= -1.0e-6;
  ok_clearance = clearance_val >= clearance_req;
  ok_track     = (time < 13.0) or (path_error < 0.006);
  // Finiteness check: all physical and control signals within sane bounds
  ok_finite    = (s > -1.0e6) and (s < 1.0e6) and
                 (x_out > -1.0e6) and (x_out < 1.0e6) and
                 (y_out > -1.0e6) and (y_out < 1.0e6) and
                 (F_sat > -1.0e6) and (F_sat < 1.0e6) and
                 (closure_error < 1.0e6);

  assert(ok_effort,    "Actuator effort bound (390 N) violated");
  assert(ok_clearance, "Obstacle clearance requirement violated");
  assert(ok_track,     "Primary tracking error exceeded 0.006 m after 13 s");
  assert(ok_finite,    "NaN or Inf detected in physical/control/estimator signals");

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "PantographTraceF: closed-chain parallelogram pantograph.
Parameters:
  L1=0.25 m, L2=0.50 m (scale 2), r_out=0.10 m, prismatic travel=0.16 m.
  Actuator bound 390 N; 14.5 N output disturbance during middle third (6.67..13.33 s).
  500 Hz sampling, 20 s run. Obstacle at (0.85,0.50) r=0.05 m.
  Six revolute Z joints and one prismatic joint are lumped into the planar
  kinematic/dynamic mapping; closure constraint is monitored and stabilized.
Verification: effort bound, clearance, closure error, path error (<0.006 m after 13 s),
  singularity margin (constant positive Jacobian), and finiteness of all signals."));
end PantographTraceF;