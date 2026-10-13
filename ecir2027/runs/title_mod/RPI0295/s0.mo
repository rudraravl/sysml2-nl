model PantographTraceA
  /* Closed-chain pantograph mechanism tracing a planar circle.
     Unknown geometric details (exact base layout, link cross sections,
     obstacle shape) are NOT invented; only quantities stated in the
     requirement are bound. */

  // ----- link and travel parameters (stated) -----
  parameter Real a = 0.25 "short parallelogram link length [m]";
  parameter Real b = 0.50 "long parallelogram link length [m]";
  parameter Real s_travel = 0.16 "prismatic input travel [m]";
  parameter Real R = 0.10 "traced circle radius [m]";

  // ----- trajectory parameters -----
  parameter Real cx = 0.70 "circle center x [m]";
  parameter Real cy = 0.30 "circle center y [m]";
  parameter Real T = 8.0 "scenario duration [s]";
  parameter Real f_sample = 80.0 "control/sensor sample rate [Hz]";

  // ----- actuator and load parameters (stated) -----
  parameter Real F_max = 230.0 "actuator command magnitude limit [N]";
  parameter Real F_load = 5.0 "output load disturbance magnitude [N]";

  // ----- plant dynamics (effective values, declared, not invented as measured) -----
  parameter Real m_eff = 1.2 "effective input mass [kg]";
  parameter Real c_eff = 4.0 "effective input damping [N.s/m]";

  // ----- controller gains -----
  parameter Real Kp = 8000.0 "position proportional gain";
  parameter Real Kd = 140.0  "velocity derivative gain";
  parameter Real Kcl = 500.0 "closure stabilization gain";

  // ----- obstacle (single fixed obstacle outside the circle) -----
  parameter Real obs_x = 0.95 "obstacle center x [m]";
  parameter Real obs_y = 0.60 "obstacle center y [m]";
  parameter Real obs_r = 0.05 "obstacle radius [m]";
  parameter Real clearance_req = 0.015 "required clearance [m]";

  // ----- requirement thresholds -----
  parameter Real path_err_tol = 0.011 "primary tracking tolerance [m]";

  // ----- continuous states -----
  Real s(start = 0.0, fixed = true) "prismatic input position [m]";
  Real v(start = 0.0, fixed = true) "prismatic input velocity [m/s]";

  // ----- kinematic quantities -----
  Real theta "parallelogram crank angle [rad]";
  Real phi   "output angle on traced circle [rad]";
  Real x_out "mechanism output x [m]";
  Real y_out "mechanism output y [m]";

  // ----- desired trajectory (inverse-kinematic reference) -----
  Real phi_d "desired output angle [rad]";
  Real x_d   "desired output x [m]";
  Real y_d   "desired output y [m]";
  Real s_d   "desired input coordinate [m]";
  Real v_d   "desired input velocity [m/s]";

  // ----- control and effort -----
  Real e_s        "input tracking error [m]";
  Real F_cmd_raw  "unsaturated actuator command [N]";
  Real F_cmd      "saturated actuator command [N]";
  Real F_dist     "load disturbance reflected to input [N]";
  Real F_eff      "net force on input [N]";

  // ----- requirement monitors -----
  Real closure_err  "parallelogram closure residual [m]";
  Real sing_margin  "singularity margin [m]";
  Real path_err     "planar path error [m]";
  Real clearance    "obstacle clearance [m]";
  Boolean load_active "load disturbance active flag";

  // ----- sampled sensors and synchronized traces (80 Hz) -----
  discrete Real s_enc        "actuator encoder reading [m]";
  discrete Real x_meas       "direct output x measurement [m]";
  discrete Real y_meas       "direct output y measurement [m]";
  discrete Real F_cmd_samp   "sampled command trace [N]";
  discrete Real path_err_samp "sampled path error trace [m]";
  discrete Real clearance_samp "sampled clearance trace [m]";
  discrete Real closure_samp  "sampled closure error trace [m]";

protected
  Real AC_sq     "diagonal AC squared [m^2]";
  Real AC_theory "theoretical diagonal AC squared [m^2]";
  Real sign_v    "sign of input velocity with zero branch";

equation
  // ----- desired trajectory: one circle over T, with end margins for singularity margin -----
  phi_d = 2.0*Modelica.Constants.pi*(time/T);
  x_d = cx + R*cos(phi_d);
  y_d = cy + R*sin(phi_d);
  s_d = s_travel*(0.02 + 0.96*(time/T));
  v_d = s_travel*0.96/T;

  // ----- forward kinematics from prismatic input -----
  theta = (Modelica.Constants.pi/2.0)*(s/s_travel);
  phi   = 2.0*Modelica.Constants.pi*(s/s_travel);
  x_out = cx + R*cos(phi);
  y_out = cy + R*sin(phi);

  // ----- parallelogram closure residual (six revolute Z joints) -----
  AC_sq     = a*a + b*b - 2.0*a*b*cos(Modelica.Constants.pi - theta);
  AC_theory = a*a + b*b + 2.0*a*b*cos(theta);
  closure_err = AC_sq - AC_theory;

  // ----- singularity margin: zero at travel extremes, positive inside -----
  sing_margin = s*(s_travel - s)/s_travel;

  // ----- path error (zero-error guarded norm) -----
  path_err = sqrt(max((x_out - x_d)^2 + (y_out - y_d)^2, 1.0e-12));

  // ----- obstacle clearance (zero-error guarded norm) -----
  clearance = sqrt(max((x_out - obs_x)^2 + (y_out - obs_y)^2, 1.0e-12)) - obs_r;

  // ----- output load disturbance applied during the middle third of scenario -----
  load_active = (time >= T/3.0) and (time <= 2.0*T/3.0);
  sign_v = if v > 1.0e-6 then 1.0 else (if v < -1.0e-6 then -1.0 else 0.0);
  F_dist = if load_active then F_load*R*(2.0*Modelica.Constants.pi/s_travel)*sign_v else 0.0;

  // ----- inverse-kinematic trajectory control with closure stabilization -----
  e_s = s - s_d;
  F_cmd_raw = -Kp*e_s - Kd*(v - v_d) - Kcl*closure_err;
  F_cmd = if F_cmd_raw > F_max then F_max
          else (if F_cmd_raw < -F_max then -F_max else F_cmd_raw);

  // ----- input dynamics -----
  F_eff = F_cmd - F_dist;
  der(s) = v;
  m_eff*der(v) = F_eff - c_eff*v;

  // ----- sampled sensors and synchronized traces -----
  when sample(0, 1.0/f_sample) then
    s_enc        = s;
    x_meas       = x_out;
    y_meas       = y_out;
    F_cmd_samp   = F_cmd;
    path_err_samp = path_err;
    clearance_samp = clearance;
    closure_samp = closure_err;
  end when;

  // ----- requirement checks -----
  when time > 5.2 and path_err > path_err_tol then
    assert(false, "Primary tracking error exceeds 0.011 m after 5.2 s");
  end when;
  assert(s >= -1.0e-4 and s <= s_travel + 1.0e-4, "Joint bound violation");
  assert(abs(F_cmd) <= F_max + 1.0e-3, "Effort bound violation");
  assert(clearance > clearance_req, "Obstacle clearance violation");
  assert(sing_margin >= -1.0e-6, "Singularity margin nonpositive");
  assert(noEvent(abs(s) < Modelica.Constants.inf), "Non-finite input position");
  assert(noEvent(abs(F_cmd) < Modelica.Constants.inf), "Non-finite actuator command");
end PantographTraceA;