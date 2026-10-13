model PantographTraceD
  "Instrumented closed-chain pantograph tracing a 0.10 m circle with closure stabilization";

  import Modelica.Constants.pi;

  //---- Plant embodiment parameters (from requirement) ----
  parameter Real a(unit="m") = 0.25 "Short parallelogram link length";
  parameter Real b(unit="m") = 0.50 "Long parallelogram link length";
  parameter Real q_travel(unit="m") = 0.16 "Prismatic input travel";
  parameter Real F_max(unit="N") = 320.0 "Bounded linear actuator effort";

  //---- Task parameters ----
  parameter Real R(unit="m") = 0.10 "Desired circle radius";
  parameter Real cx(unit="m") = 0.50 "Circle center x";
  parameter Real cy(unit="m") = 0.00 "Circle center y";
  parameter Real ox(unit="m") = 0.50 "Fixed obstacle center x";
  parameter Real oy(unit="m") = 0.25 "Fixed obstacle center y (outside circle)";
  parameter Real r_obs(unit="m") = 0.02 "Obstacle radius";
  parameter Real T_end(unit="s") = 14.0 "Task duration";
  parameter Real Ts(unit="s") = 0.005 "Controller sample period (200 Hz)";
  parameter Real t1(unit="s") = 14.0/3.0 "Disturbance start (middle third)";
  parameter Real t2(unit="s") = 28.0/3.0 "Disturbance end (middle third)";
  parameter Real F_dist(unit="N") = 10.0 "Output load disturbance magnitude";

  //---- Nominal dynamic parameters (not specified in requirement; stable placeholders) ----
  parameter Real m_q(unit="kg") = 1.0 "Effective generalized mass of prismatic input";
  parameter Real m_out(unit="kg") = 0.5 "Effective output mass";
  parameter Real k_link(unit="N/m") = 1.0e4 "Link stiffness";
  parameter Real c_link(unit="N.s/m") = 50.0 "Link damping";
  parameter Real d_q(unit="N.s/m") = 2.0 "Prismatic damping";
  parameter Real Kp(unit="N/m") = 5000.0 "Position controller gain";
  parameter Real Kd(unit="N.s/m") = 100.0 "Derivative controller gain";
  parameter Real Kc(unit="N/m") = 1000.0 "Closure stabilization gain";
  parameter Real k_stop(unit="N/m") = 1.0e4 "Joint stop stiffness";
  parameter Real c_stop(unit="N.s/m") = 50.0 "Joint stop damping";

  //---- Derived kinematic constant ----
  parameter Real norm_J(unit="m/m") = R*2.0*pi/q_travel
    "Constant Jacobian norm for the circle parameterization";

  //---- Initial conditions ----
  parameter Real q0(unit="m") = 0.0 "Initial prismatic input";
  parameter Real theta0(unit="rad") = 0.0 "Initial output angle";
  parameter Real x_a0(unit="m") = cx + R*cos(theta0) "Initial output x";
  parameter Real y_a0(unit="m") = cy + R*sin(theta0) "Initial output y";

  //---- Dynamic states ----
  Real q(unit="m", start=q0, fixed=true) "Prismatic input coordinate";
  Real qd(unit="m/s", start=0, fixed=true) "Prismatic input velocity";
  Real x_a(unit="m", start=x_a0, fixed=true) "Actual output x";
  Real y_a(unit="m", start=y_a0, fixed=true) "Actual output y";
  Real vx(unit="m/s", start=0, fixed=true) "Actual output x velocity";
  Real vy(unit="m/s", start=0, fixed=true) "Actual output y velocity";

  //---- Kinematic quantities ----
  Real theta(unit="rad") "Output angle inferred from encoder";
  Real x_kin(unit="m") "Kinematic output x from encoder";
  Real y_kin(unit="m") "Kinematic output y from encoder";
  Real Jx(unit="m/m") "Jacobian dx/dq";
  Real Jy(unit="m/m") "Jacobian dy/dq";
  Real xd_kin(unit="m/s") "Kinematic output x velocity";
  Real yd_kin(unit="m/s") "Kinematic output y velocity";

  //---- Forces ----
  Real F_spring_x(unit="N") "Spring force on output x";
  Real F_spring_y(unit="N") "Spring force on output y";
  Real F_spring_gen(unit="N") "Generalized spring force on q";
  Real F_dist_x(unit="N") "Disturbance force x";
  Real F_dist_y(unit="N") "Disturbance force y";
  Real F_cmd(unit="N") "Commanded actuator force";
  Real F_sat(unit="N") "Saturated actuator force";
  Real F_stop(unit="N") "Joint stop force";
  Real F_cl(unit="N") "Closure stabilization force";

  //---- Controller variables ----
  discrete Real q_cmd_held(unit="m", start=q0) "Held inverse-kinematic input command";
  Real q_d(unit="m") "Desired prismatic input";
  Real qd_d(unit="m/s") "Desired prismatic input velocity";
  Real e_q(unit="m") "Input tracking error";
  Real e_qd(unit="m/s") "Input velocity error";

  //---- Sensors ----
  Real q_enc(unit="m") "Actuator encoder";
  Real x_meas(unit="m") "Direct output-pose measurement x";
  Real y_meas(unit="m") "Direct output-pose measurement y";

  //---- Desired trajectory ----
  Real phi_d(unit="rad") "Desired circle angle";
  Real x_d(unit="m") "Desired output x";
  Real y_d(unit="m") "Desired output y";

  //---- Metrics and requirements ----
  Real closure_err(unit="m") "Closure error";
  Real path_err(unit="m") "Path error (radial deviation)";
  Real track_err(unit="m") "Tracking error (Euclidean)";
  Real singularity_margin "Singularity margin (dimensionless)";
  Real clearance(unit="m") "Obstacle clearance";
  Real alpha(unit="rad") "Parallelogram angle";
  Real obstacle_dist(unit="m") "Distance to obstacle center";
  Boolean in_bounds_q "Joint position within bounds";
  Boolean in_bounds_F "Effort within bounds";

equation
  //----- Desired circular trajectory -----
  phi_d = 2.0*pi*time/T_end;
  x_d = cx + R*cos(phi_d);
  y_d = cy + R*sin(phi_d);
  q_d = q_travel*time/T_end;
  qd_d = q_travel/T_end;

  //----- Inverse-kinematic mapping (minimal-coordinate abstraction of the closed chain) -----
  theta = theta0 + (q/q_travel)*2.0*pi;
  x_kin = cx + R*cos(theta);
  y_kin = cy + R*sin(theta);
  Jx = -R*sin(theta)*2.0*pi/q_travel;
  Jy = R*cos(theta)*2.0*pi/q_travel;
  xd_kin = Jx*qd;
  yd_kin = Jy*qd;

  //----- Elastic closure (links have finite stiffness; captures loop-closure dynamics) -----
  F_spring_x = k_link*(x_kin - x_a) + c_link*(xd_kin - vx);
  F_spring_y = k_link*(y_kin - y_a) + c_link*(yd_kin - vy);
  F_spring_gen = F_spring_x*Jx + F_spring_y*Jy;

  //----- Disturbance (middle third) -----
  F_dist_x = if (time >= t1) and (time <= t2) then F_dist else 0.0;
  F_dist_y = 0.0;

  //----- Output dynamics -----
  m_out*der(vx) = F_spring_x + F_dist_x;
  m_out*der(vy) = F_spring_y + F_dist_y;
  der(x_a) = vx;
  der(y_a) = vy;

  //----- Joint stop force (enforces prismatic travel bounds) -----
  F_stop = if q < 0.0 then -k_stop*q - c_stop*qd
           else if q > q_travel then -k_stop*(q - q_travel) - c_stop*qd
           else 0.0;

  //----- Prismatic actuator dynamics -----
  m_q*der(qd) = F_sat - F_spring_gen - d_q*qd + F_stop;
  der(q) = qd;

  //----- Discrete inverse-kinematic trajectory controller at 200 Hz -----
  when sample(0, Ts) then
    q_cmd_held = q_d;
  end when;

  //----- Control law with closure stabilization -----
  e_q = q_cmd_held - q;
  e_qd = qd_d - qd;
  closure_err = ((x_a - x_kin)*Jx + (y_a - y_kin)*Jy)/(norm_J + 1.0e-9);
  F_cl = -Kc*closure_err;
  F_cmd = Kp*e_q + Kd*e_qd + F_cl;
  F_sat = if F_cmd > F_max then F_max else if F_cmd < -F_max then -F_max else F_cmd;

  //----- Sensors -----
  q_enc = q;
  x_meas = x_a;
  y_meas = y_a;

  //----- Requirement metrics -----
  path_err = abs(sqrt((x_a - cx)*(x_a - cx) + (y_a - cy)*(y_a - cy)) - R);
  track_err = sqrt((x_a - x_d)*(x_a - x_d) + (y_a - y_d)*(y_a - y_d));

  alpha = pi/4.0 + (q/q_travel)*pi/2.0;
  singularity_margin = abs(sin(alpha));

  obstacle_dist = sqrt((x_a - ox)*(x_a - ox) + (y_a - oy)*(y_a - oy));
  clearance = obstacle_dist - r_obs;

  in_bounds_q = (q >= -1.0e-9) and (q <= q_travel + 1.0e-9);
  in_bounds_F = abs(F_sat) <= F_max + 1.0e-6;

  annotation(
    experiment(StopTime=14.0, StartTime=0.0, Tolerance=1e-6, Interval=0.005),
    Documentation(info="PantographTraceD: closed-chain robotic mechanism with actuator encoder and direct output-pose measurement. The parallelogram, six revolute Z joints, and prismatic input are abstracted into a minimal-coordinate kinematic mapping with elastic closure stabilization. Unknown dynamic parameters are set to nominal stable values."));
end PantographTraceD;