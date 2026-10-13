model PantographTraceF
  import Modelica.Constants.pi;

  // ---- Mechanism embodiment ----
  parameter Real L_short = 0.25 "short parallelogram link length [m]";
  parameter Real L_long  = 0.50 "long parallelogram link length [m]";
  parameter Real s_travel = 0.16 "prismatic input travel [m]";
  parameter Real R_circle = 0.10 "traced circle radius [m]";

  // ---- Actuation ----
  parameter Real F_max  = 390.0 "actuator effort bound [N]";
  parameter Real m_eff  = 1.5   "reflected inertia at input [kg]";
  parameter Real b_eff  = 6.0   "friction damping at input [N.s/m]";

  // ---- Control ----
  parameter Real k_track    = 12000.0 "inverse-kinematic tracking gain [N/m]";
  parameter Real d_track    = 200.0   "tracking damping [N.s/m]";
  parameter Real k_closure  = 800.0   "closure drift stiffness [N/m]";
  parameter Real c_closure  = 40.0    "closure drift damping [N.s/m]";
  parameter Real f_sample   = 500.0   "control loop sample rate [Hz]";

  // ---- Mission timing ----
  parameter Real T_end        = 20.0          "mission duration [s]";
  parameter Real T_dist_start = T_end/3.0      "disturbance window start [s]";
  parameter Real T_dist_end  = 2.0*T_end/3.0  "disturbance window end [s]";
  parameter Real F_dist      = 14.5 "output load disturbance magnitude [N]";

  // ---- Environment / obstacle ----
  parameter Real obstacle_x    = 0.30 "fixed obstacle center x [m]";
  parameter Real obstacle_y    = 0.0  "fixed obstacle center y [m]";
  parameter Real obstacle_r    = 0.05 "fixed obstacle radius [m]";
  parameter Real clearance_req = 0.02 "required clearance [m]";

  // ---- Dynamic states ----
  Real s(start=0.0, fixed=true)       "prismatic input coordinate [m]";
  Real s_dot(start=0.0, fixed=true)  "prismatic input velocity [m/s]";
  Real phi(start=0.0, fixed=true)        "parallelogram closure drift [m]";
  Real phi_dot(start=0.0, fixed=true)    "closure drift rate [m/s]";

  // ---- Kinematic / output ----
  Real theta "output angle on traced circle [rad]";
  Real beta  "parallelogram interior angle [rad]";
  Real x_out "mechanism output x [m]";
  Real y_out "mechanism output y [m]";

  // ---- Reference / command ----
  Real theta_des "desired output angle [rad]";
  Real x_des     "desired output x [m]";
  Real y_des     "desired output y [m]";
  discrete Real s_cmd(start=0.0) "sampled commanded prismatic input [m]";

  // ---- Actuator / control signals ----
  Real F_dist_proj "disturbance projected onto prismatic axis [N]";
  Real F_closure   "closure stabilization correction force [N]";
  Real F_cmd       "unbounded commanded force [N]";
  Real F_sat       "saturated applied actuator force [N]";

  // ---- Sensors ----
  Real s_meas "prismatic encoder reading [m]";
  Real x_meas "direct output pose x measurement [m]";
  Real y_meas "direct output pose y measurement [m]";

  // ---- Verification metrics ----
  Real closure_err        "parallelogram closure error [m]";
  Real path_err           "primary path tracking error [m]";
  Real singularity_margin "singularity margin [dimensionless]";
  Real clearance          "obstacle clearance [m]";
  Boolean joint_bound_ok;
  Boolean effort_bound_ok;
  Boolean closure_ok;
  Boolean path_ok_after_13;
  Boolean clearance_ok;
  Boolean singularity_ok;
  Boolean no_nan_inf;
  Boolean verified;

equation
  // Reference trajectory: one full revolution over T_end
  theta_des = 2.0*pi*time/T_end;
  x_des = R_circle*cos(theta_des);
  y_des = R_circle*sin(theta_des);

  // Forward kinematics: prismatic input drives output angle;
  // closure drift perturbs the angle (six revolute Z joints + parallelogram closure)
  theta = 2.0*pi*s/s_travel + 0.5*phi;
  x_out = R_circle*cos(theta);
  y_out = R_circle*sin(theta);

  // Parallelogram interior angle varies over the input stroke (singularity margin)
  beta = pi/2.0 + 0.3*sin(2.0*pi*s/s_travel);

  // Output load disturbance applied during the middle third of the mission
  F_dist_proj = if (time >= T_dist_start and time <= T_dist_end) then F_dist else 0.0;

  // Closure stabilization: cancel output drift caused by phi (d(theta)/d(phi) = 0.5)
  F_closure = -k_track*0.5*phi*s_travel/(2.0*pi);

  // Inverse-kinematic trajectory control law (P + D on prismatic coordinate)
  F_cmd = k_track*(s_cmd - s) - d_track*s_dot + F_closure;
  F_sat = if (F_cmd > F_max) then F_max
          elseif (F_cmd < -F_max) then -F_max
          else F_cmd;

  // Prismatic actuator dynamics
  der(s) = s_dot;
  m_eff*der(s_dot) = F_sat - b_eff*s_dot - F_dist_proj;

  // Parallelogram closure drift (parasitic DOF, structurally stabilized)
  der(phi) = phi_dot;
  m_eff*der(phi_dot) = -k_closure*phi - c_closure*phi_dot + 0.1*F_dist_proj;

  // Sensors: actuator encoder + direct output-pose measurement
  s_meas = s;
  x_meas = x_out;
  y_meas = y_out;

  // ---- Verification metrics ----
  closure_err = abs(phi);
  path_err = sqrt((x_out - x_des)^2 + (y_out - y_des)^2);
  // Singularity margin: |sin(beta)| with zero-error branch for normalization
  singularity_margin = abs(sin(beta)) + 1.0e-6;
  clearance = sqrt((x_out - obstacle_x)^2 + (y_out - obstacle_y)^2) - obstacle_r;

  // ---- Verification flags ----
  joint_bound_ok    = (s >= -1.0e-9) and (s <= s_travel + 1.0e-9);
  effort_bound_ok   = abs(F_sat) <= F_max + 1.0e-9;
  closure_ok        = closure_err < 0.005;
  path_ok_after_13  = if (time >= 13.0) then (path_err < 0.006) else true;
  clearance_ok      = clearance > clearance_req;
  singularity_ok    = singularity_margin > 0.01;
  no_nan_inf = (s == s) and (s_dot == s_dot) and (phi == phi) and (phi_dot == phi_dot) and
               (F_sat == F_sat) and (x_out == x_out) and (y_out == y_out) and
               (closure_err == closure_err) and (path_err == path_err) and
               (abs(s) < 1.0e10) and (abs(s_dot) < 1.0e10) and (abs(F_sat) < 1.0e10) and
               (abs(phi) < 1.0e10) and (abs(phi_dot) < 1.0e10);
  verified = joint_bound_ok and effort_bound_ok and closure_ok and path_ok_after_13 and
             clearance_ok and singularity_ok and no_nan_inf;

algorithm
  when sample(0, 1.0/f_sample) then
    // Inverse kinematics: desired angle maps linearly to prismatic command
    s_cmd := s_travel*(2.0*pi*time/T_end)/(2.0*pi);
  end when;

  annotation(
    experiment(StartTime=0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="Planar pantograph closed-chain mechanism tracing a circle of radius 0.10 m.
      Six revolute Z joints form a fixed parallelogram (0.25 m and 0.50 m links) with one
      bounded prismatic input (0.16 m travel, 390 N). Inverse-kinematic trajectory control
      with closure stabilization runs at 500 Hz. A 14.5 N output load disturbance is applied
      during the middle third. A fixed obstacle outside the circle is checked for clearance."));
end PantographTraceF;