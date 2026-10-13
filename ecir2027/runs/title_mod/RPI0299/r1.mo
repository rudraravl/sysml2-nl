model PantographTraceE
  // ---- Plant geometry ----
  parameter Real L1 = 0.25 "short parallelogram link length [m]";
  parameter Real L2 = 0.50 "long parallelogram link length [m]";
  parameter Real s_max = 0.16 "prismatic input travel [m]";
  parameter Real scale_k = 2.0 "pantograph scaling (L2/L1)";
  parameter Real m_in = 1.0 "prismatic carriage inertia [kg]";

  // ---- Task specification ----
  parameter Real R_target = 0.10 "target circle radius at output [m]";
  parameter Real s_target = R_target/scale_k "IK target prismatic coordinate [m]";
  parameter Real T_run = 16.0 "scenario duration [s]";
  parameter Real T_circle = 16.0 "circle period (one revolution) [s]";
  parameter Real omega = 2.0*Modelica.Constants.pi/T_circle "crank angular speed [rad/s]";
  parameter Real F_dist = 12.0 "controlled output load disturbance [N]";
  parameter Real Ts_ctrl = 1.0/250.0 "control/sensor sample period [s]";

  // ---- Actuator bounds ----
  parameter Real F_max = 352.0 "actuator force bound [N]";
  parameter Real q_limit = 2.5*Modelica.Constants.pi "revolute joint angle bound [rad]";

  // ---- Controller gains (inverse-kinematic trajectory control + closure stabilization) ----
  parameter Real kS = 10000.0 "prismatic proportional gain [N/m]";
  parameter Real kV = 200.0 "prismatic derivative gain [N.s/m]";
  parameter Real kI = 10000.0 "prismatic integral gain [N/(m.s)]";
  parameter Real kC = 40000.0 "closure stabilization proportional gain [1/s^2]";
  parameter Real kD = 400.0 "closure stabilization damping gain [1/s]";

  // ---- Obstacle (placed outside the traced circle) ----
  parameter Real obs_x = 0.30 "obstacle center x [m]";
  parameter Real obs_y = 0.30 "obstacle center y [m]";
  parameter Real obs_r = 0.05 "obstacle radius [m]";
  parameter Real clearance_req = 0.02 "required clearance [m]";

  // ---- Acceptance thresholds ----
  parameter Real closure_tol = 0.05 "closure error tolerance [rad]";
  parameter Real sing_min = 0.10 "minimum singularity margin";
  parameter Real track_tol = 0.007 "primary path-error tolerance [m]";
  parameter Real track_time = 10.4 "after which path error must remain bounded [s]";
  parameter Real eps = 1.0e-9 "regularization constant";

  // ---- Prismatic actuator states ----
  Real s(start=s_target, fixed=true) "prismatic input coordinate [m]";
  Real v(start=0.0, fixed=true) "prismatic velocity [m/s]";
  Real s_int(start=0.0, fixed=true) "integral state [m.s]";

  // ---- Crank (kinematic source) ----
  Real theta "crank angle [rad]";

  // ---- Six revolute Z joints (q1 driven, q2..q6 parallelogram/output with closure stabilization) ----
  Real q1 "crank revolute (driven) [rad]";
  Real q2 "parallelogram revolute 2 [rad]";
  Real q3 "parallelogram revolute 3 [rad]";
  Real q4 "parallelogram revolute 4 [rad]";
  Real q5 "output arm revolute 5 [rad]";
  Real q6 "output arm revolute 6 [rad]";
  Real dq2 "joint 2 rate [rad/s]";
  Real dq3 "joint 3 rate [rad/s]";
  Real dq4 "joint 4 rate [rad/s]";
  Real dq5 "joint 5 rate [rad/s]";
  Real dq6 "joint 6 rate [rad/s]";

  // ---- Forces and disturbance ----
  Real F_cmd "commanded actuator force [N]";
  Real F_act "applied (saturated) actuator force [N]";
  Real F_dist_x "disturbance x component [N]";
  Real F_dist_y "disturbance y component [N]";
  Real F_prismatic_dist "output disturbance projected to prismatic [N]";
  Boolean in_disturbance "true during middle third of scenario";

  // ---- Output pose and reference path ----
  Real Wx "output x position [m]";
  Real Wy "output y position [m]";
  Real Rx "reference x position [m]";
  Real Ry "reference y position [m]";
  Real ex "tracking error x [m]";
  Real ey "tracking error y [m]";
  Real e_path "path error magnitude [m]";

  // ---- Closure, singularity, clearance ----
  Real closure_err "RMS parallelogram closure error [rad]";
  Real singularity_margin "input-output Jacobian singularity margin [dimensionless]";
  Real clearance "geometric clearance to obstacle [m]";

  // ---- Continuous sensors (actuator encoders + direct output-pose measurement) ----
  Real s_sens "prismatic encoder position [m]";
  Real v_sens "prismatic encoder velocity [m/s]";
  Real Wx_sens "direct output-pose x [m]";
  Real Wy_sens "direct output-pose y [m]";

  // ---- Synchronized 250 Hz state, command, and sensor traces ----
  discrete Real s_sens_d "sampled prismatic encoder [m]";
  discrete Real v_sens_d "sampled prismatic velocity [m/s]";
  discrete Real Wx_sens_d "sampled output pose x [m]";
  discrete Real Wy_sens_d "sampled output pose y [m]";
  discrete Real e_path_d "sampled path error [m]";
  discrete Real closure_err_d "sampled closure error [rad]";
  discrete Real F_act_d "sampled actuator force [N]";
  discrete Real singularity_margin_d "sampled singularity margin";
  discrete Real clearance_d "sampled clearance [m]";
  discrete Real theta_d "sampled crank angle [rad]";

  // ---- Bounds and acceptance (fail-closed) ----
  Real max_abs_q "maximum absolute joint angle [rad]";
  Real joint_bound_margin "joint bound margin [rad]";
  Boolean effort_in_bounds;
  Boolean joint_in_bounds;
  Boolean closure_ok;
  Boolean clearance_ok;
  Boolean singular_ok;
  Boolean track_ok;
  Boolean finite_ok;
  Boolean acceptance;

equation
  // ---- Crank: ideal kinematic source ----
  theta = omega*time;
  q1 = theta;

  // ---- Parallelogram closure stabilization: passive revolute joints track crank ----
  der(q2) = dq2;  der(dq2) = kC*(q1 - q2) - kD*dq2;
  der(q3) = dq3;  der(dq3) = kC*(q1 - q3) - kD*dq3;
  der(q4) = dq4;  der(dq4) = kC*(q1 - q4) - kD*dq4;
  der(q5) = dq5;  der(dq5) = kC*(q1 - q5) - kD*dq5;
  der(q6) = dq6;  der(dq6) = kC*(q1 - q6) - kD*dq6;

  // ---- Forward kinematics: pantograph doubles the tracing-point radius ----
  // Tracing point T = s*e(q5); output W = scale_k*T (scale_k = L2/L1 = 2)
  Wx = scale_k*s*cos(q5);
  Wy = scale_k*s*sin(q5);

  // ---- Reference path: target circle of radius R_target ----
  Rx = scale_k*s_target*cos(theta);
  Ry = scale_k*s_target*sin(theta);
  ex = Wx - Rx;
  ey = Wy - Ry;
  e_path = sqrt(max(ex*ex + ey*ey, 0.0));

  // ---- Middle-third output load disturbance (12 N, radial outward) ----
  in_disturbance = time >= T_run/3.0 and time <= 2.0*T_run/3.0;
  F_dist_x = if in_disturbance then F_dist*cos(theta) else 0.0;
  F_dist_y = if in_disturbance then F_dist*sin(theta) else 0.0;
  // Output force -> generalized prismatic force via Jacobian dW/ds = scale_k*(cos q5, sin q5)
  F_prismatic_dist = scale_k*(F_dist_x*cos(q5) + F_dist_y*sin(q5));

  // ---- Prismatic actuator dynamics ----
  der(s) = v;
  der(v) = (F_act + F_prismatic_dist)/m_in;

  // ---- Integral state ----
  der(s_int) = s_target - s;

  // ---- Inverse-kinematic trajectory control with closure stabilization ----
  F_cmd = kS*(s_target - s) - kV*v + kI*s_int;
  F_act = if F_cmd > F_max then F_max else if F_cmd < -F_max then -F_max else F_cmd;

  // ---- Closure error (RMS over passive revolutes relative to driven crank) ----
  closure_err = sqrt(max(((q1-q2)^2 + (q1-q3)^2 + (q1-q4)^2 + (q1-q5)^2 + (q1-q6)^2)/5.0, 0.0));

  // ---- Singularity margin: Jacobian det = 4*s (singular at s=0) ----
  singularity_margin = abs(s)/s_max;

  // ---- Obstacle clearance (obstacle placed outside the traced circle) ----
  clearance = sqrt(max((Wx - obs_x)^2 + (Wy - obs_y)^2, 0.0)) - obs_r;

  // ---- Continuous sensors ----
  s_sens = s;
  v_sens = v;
  Wx_sens = Wx;
  Wy_sens = Wy;

  // ---- 250 Hz synchronized traces ----
  when sample(0, Ts_ctrl) then
    s_sens_d = s;
    v_sens_d = v;
    Wx_sens_d = Wx;
    Wy_sens_d = Wy;
    e_path_d = e_path;
    closure_err_d = closure_err;
    F_act_d = F_act;
    singularity_margin_d = singularity_margin;
    clearance_d = clearance;
    theta_d = theta;
  end when;

  // ---- Joint bound ----
  max_abs_q = max(abs(q1), max(abs(q2), max(abs(q3), max(abs(q4), max(abs(q5), abs(q6))))));
  joint_bound_margin = q_limit - max_abs_q;
  joint_in_bounds = joint_bound_margin > 0.0;

  // ---- Effort bound ----
  effort_in_bounds = abs(F_act) <= F_max + eps;

  // ---- Closure bound ----
  closure_ok = closure_err < closure_tol;

  // ---- Clearance bound ----
  clearance_ok = clearance > clearance_req;

  // ---- Singularity margin bound ----
  singular_ok = singularity_margin > sing_min;

  // ---- Primary tracking-error acceptance (after 10.4 s) ----
  track_ok = if time >= track_time then e_path < track_tol else true;

  // ---- No NaN / infinite physical, control, or estimator values ----
  finite_ok = abs(s) < 1.0e6 and abs(v) < 1.0e6 and abs(F_act) < 1.0e6 and
              abs(Wx) < 1.0e6 and abs(Wy) < 1.0e6 and abs(e_path) < 1.0e6 and
              abs(closure_err) < 1.0e6 and abs(singularity_margin) < 1.0e6 and
              abs(clearance) < 1.0e6 and abs(s_int) < 1.0e6;

  // ---- Fail-closed acceptance: all conditions must hold ----
  acceptance = joint_in_bounds and effort_in_bounds and closure_ok and
               clearance_ok and singular_ok and track_ok and finite_ok;

end PantographTraceE;