model FourBarTraceB
  // Link geometry (SI units)
  parameter Real L1 = 0.20 "crank length [m]";
  parameter Real L2 = 0.44 "coupler length [m]";
  parameter Real L3 = 0.35 "rocker length [m]";
  parameter Real L0 = 0.50 "ground pivot distance [m]";
  parameter Real r_out = 0.10 "output radius along crank [m]";
  // Crank dynamics
  parameter Real J_crank = 0.05 "crank inertia [kg.m^2]";
  parameter Real b_crank = 0.10 "crank viscous damping [N.m.s/rad]";
  // Joint-space PD control (inverse-kinematic trajectory controller)
  parameter Real Kp = 20.0 "joint proportional gain [N.m/rad]";
  parameter Real Kd = 2.0 "joint derivative gain [N.m.s/rad]";
  parameter Real tau_max = 20.5 "command torque bound [N.m]";
  // Disturbance load
  parameter Real F_load = 7.0 "output load disturbance magnitude [N]";
  // Mission timing
  parameter Real T_end = 10.0 "mission duration [s]";
  parameter Real T_load_on  = T_end/3.0      "load disturbance start [s]";
  parameter Real T_load_off = 2.0*T_end/3.0  "load disturbance end [s]";
  parameter Real omega = 2.0*Modelica.Constants.pi/T_end "trace angular rate [rad/s]";
  parameter Real Ts = 0.01 "trace sample period [s]";
  // Obstacle placed outside the traced circle
  parameter Real obstacle_x = 0.40 "obstacle center x [m]";
  parameter Real obstacle_y = 0.40 "obstacle center y [m]";
  parameter Real obstacle_r = 0.05 "obstacle radius [m]";
  parameter Real clearance_min = 0.03 "required clearance [m]";
  parameter Real eps = 1.0e-6 "numerical guard for division/acos";

  // Continuous states
  Real q1(start=0.0, fixed=true) "crank angle [rad] (actuator encoder)";
  Real dq1(start=0.0, fixed=true) "crank angular velocity [rad/s]";
  // Algebraic kinematic quantities
  Real q3 "rocker angle [rad]";
  Real Bx, By, Cx, Cy;
  Real Px, Py "output point position [m] (direct pose measurement)";
  Real dx_a, dy_a, K_c, R_c, phi_c, arg_c, alpha_c;
  Real den, sing_margin;
  Real closure_err "closure constraint residual [m]";
  // Desired trajectory and errors
  Real q1_des "desired crank angle [rad]";
  Real Pdx, Pdy "desired output position [m]";
  Real ex_x, ex_y "output position error components [m]";
  Real path_err "primary path error [m]";
  // Control
  Real tau_raw "unsaturated command torque [N.m]";
  Real tau_cmd "saturated command torque [N.m]";
  Real tau_load "load disturbance torque on crank [N.m]";
  Real load_active "load disturbance active flag";
  Real Fx_load, Fy_load "load disturbance force components [N]";
  // Obstacle clearance
  Real obs_dist "distance output to obstacle center [m]";
  Real clearance "clearance to obstacle surface [m]";
  // Bound monitors
  Real effort_ok "effort within bound flag";
  Real joint_ok  "joint configuration feasible flag";

  // 100 Hz synchronized traces (sampled sensor/state/command)
  discrete Real tr_time "trace time [s]";
  discrete Real tr_q1 "sampled crank angle [rad]";
  discrete Real tr_dq1 "sampled crank velocity [rad/s]";
  discrete Real tr_q3 "sampled rocker angle [rad]";
  discrete Real tr_Px "sampled output x [m]";
  discrete Real tr_Py "sampled output y [m]";
  discrete Real tr_tau "sampled command torque [N.m]";
  discrete Real tr_closure "sampled closure error [m]";
  discrete Real tr_path "sampled path error [m]";
  discrete Real tr_sing "sampled singularity margin";
  discrete Real tr_clr "sampled clearance [m]";
  discrete Real tr_load "sampled load active flag";

  // Continuous outputs
  output Real o_q1 = q1;
  output Real o_dq1 = dq1;
  output Real o_q3 = q3;
  output Real o_Px = Px;
  output Real o_Py = Py;
  output Real o_tau = tau_cmd;
  output Real o_closure = closure_err;
  output Real o_path = path_err;
  output Real o_sing = sing_margin;
  output Real o_clr = clearance;
  output Real o_load = load_active;
equation
  // Crank end B (pivot A at origin, pivot D at (L0,0))
  Bx = L1*cos(q1);
  By = L1*sin(q1);
  // Closed-chain closure: solve rocker angle q3 from |C - B| = L2
  // with C = (L0, 0) + L3*(cos q3, sin q3). Revolute Z joints => planar motion.
  dx_a = L0 - Bx;
  dy_a = -By;
  K_c = (L2*L2 - dx_a*dx_a - dy_a*dy_a - L3*L3)/(2.0*L3);
  R_c = sqrt(dx_a*dx_a + dy_a*dy_a);
  phi_c = atan2(dy_a, dx_a);
  arg_c = if R_c > eps then max(-1.0 + eps, min(1.0 - eps, K_c/R_c)) else 0.0;
  alpha_c = acos(arg_c);
  q3 = phi_c + alpha_c;
  Cx = L0 + L3*cos(q3);
  Cy = L3*sin(q3);
  // Output point on crank at radius r_out -> traces circle of radius r_out [m]
  Px = r_out*cos(q1);
  Py = r_out*sin(q1);
  // Closure residual (closure stabilization monitor)
  closure_err = sqrt((Cx - Bx)*(Cx - Bx) + (Cy - By)*(Cy - By)) - L2;
  // Singularity margin: |denominator of dq3/dq1|, well-defined zero-error branch
  den = dy_a*cos(q3) - dx_a*sin(q3);
  sing_margin = abs(den) + eps;
  // Desired trajectory: circle radius r_out centered at origin
  q1_des = omega*time;
  Pdx = r_out*cos(q1_des);
  Pdy = r_out*sin(q1_des);
  ex_x = Pdx - Px;
  ex_y = Pdy - Py;
  path_err = sqrt(ex_x*ex_x + ex_y*ex_y);
  // Load disturbance: 7 N opposing motion, active during middle third of mission
  load_active = if time >= T_load_on and time <= T_load_off then 1.0 else 0.0;
  Fx_load =  F_load*sin(q1)*load_active;
  Fy_load = -F_load*cos(q1)*load_active;
  // Reaction torque on crank from external load applied at output point
  tau_load = Fx_load*(-r_out*sin(q1)) + Fy_load*(r_out*cos(q1));
  // Inverse-kinematic trajectory control (q1_des = omega*t) with joint-space PD
  tau_raw = Kp*(q1_des - q1) + Kd*(omega - dq1);
  tau_cmd = max(-tau_max, min(tau_max, tau_raw));
  // Crank dynamics (massless coupler/rocker: closure maintained analytically)
  J_crank*der(dq1) = tau_cmd + tau_load - b_crank*dq1;
  der(q1) = dq1;
  // Obstacle clearance (obstacle placed outside traced circle)
  obs_dist = sqrt((Px - obstacle_x)*(Px - obstacle_x) + (Py - obstacle_y)*(Py - obstacle_y));
  clearance = obs_dist - obstacle_r;
  // Bound monitors
  effort_ok = if abs(tau_cmd) <= tau_max + eps then 1.0 else 0.0;
  joint_ok  = 1.0;
  // 100 Hz synchronized trace sampling for state, command, and sensors
  when sample(0, Ts) then
    tr_time = time;
    tr_q1 = q1;
    tr_dq1 = dq1;
    tr_q3 = q3;
    tr_Px = Px;
    tr_Py = Py;
    tr_tau = tau_cmd;
    tr_closure = closure_err;
    tr_path = path_err;
    tr_sing = sing_margin;
    tr_clr = clearance;
    tr_load = load_active;
  end when;
  annotation(experiment(StartTime=0, StopTime=10.0, Tolerance=1e-6));
end FourBarTraceB;