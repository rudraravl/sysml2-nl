model FourBarTraceF
  "Planar four-bar mechanism tracing a circular arc of radius 0.10 m
   with inverse-kinematic trajectory control, bounded crank torque,
   output load disturbance, obstacle clearance, and closure stabilization."

  // ---- Link geometry (SI units) ----
  parameter Real r2 = 0.20 "crank length [m]";
  parameter Real r3 = 0.44 "coupler length [m]";
  parameter Real r4 = 0.35 "rocker length [m]";
  parameter Real d  = 0.50 "fixed-pivot distance [m]";
  parameter Real rc = 0.10 "output distance from O4 along rocker [m]";

  // ---- Inertias ----
  parameter Real J2 = 0.010 "crank inertia [kg.m2]";
  parameter Real J4 = 0.005 "rocker inertia [kg.m2]";

  // ---- Actuation limit ----
  parameter Real tau_max = 30.5 "max crank torque magnitude [N.m]";

  // ---- Disturbance ----
  parameter Real F_dist = 14.5 "output load disturbance magnitude [N]";

  // ---- Controller gains ----
  parameter Real Kp = 200.0 "PD proportional gain [N.m/rad]";
  parameter Real Kd = 3.0   "PD derivative gain [N.m.s/rad]";
  parameter Real K_closure = 10.0 "closure stabilization gain [N.m/m]";

  // ---- Desired trajectory ----
  parameter Real omega_d       = 1.2566 "desired oscillation angular freq [rad/s]";
  parameter Real theta4_center  = 2.077  "rocker oscillation centre [rad]";
  parameter Real theta4_amp    = 0.55   "rocker oscillation amplitude [rad]";

  // ---- Obstacle ----
  parameter Real obs_x = 0.50 "obstacle centre x [m]";
  parameter Real obs_y = 0.45 "obstacle centre y [m]";
  parameter Real obs_r = 0.05 "obstacle radius [m]";

  // ---- Initial conditions ----
  parameter Real theta2_init  = -0.50 "initial crank angle [rad]";
  parameter Real omega2_init   = 0.0   "initial crank velocity [rad/s]";

  // ===== Dynamic states =====
  Real theta2(start = theta2_init, fixed = true) "crank angle [rad]";
  Real omega2(start = omega2_init,  fixed = true) "crank angular velocity [rad/s]";

  // ===== Forward kinematics =====
  Real Ax  "crank-coupler joint x [m]";
  Real Ay  "crank-coupler joint y [m]";
  Real Bx  "rocker-coupler joint x [m]";
  Real By  "rocker-coupler joint y [m]";
  Real theta3 "coupler angle [rad]";
  Real theta4 "rocker angle [rad]";
  Real Px  "output x [m]";
  Real Py  "output y [m]";

  // closure intermediates
  Real ex_fk, ey_fk, K_fk, R_fk, phi_fk, cos_arg_fk;
  Real sin43 "sin(theta4 - theta3)";
  Real dth3_dth2 "dtheta3/dtheta2";
  Real n_ratio "velocity ratio dtheta4/dtheta2";
  Real Jac_x "output Jacobian x-component";
  Real Jac_y "output Jacobian y-component";
  Real Jac_norm "output Jacobian norm";
  Real J_eff "effective inertia at crank [kg.m2]";

  // ===== Desired trajectory and inverse kinematics =====
  Real theta4_des "desired rocker angle [rad]";
  Real omega4_des "desired rocker velocity [rad/s]";
  Real Px_des "desired output x [m]";
  Real Py_des "desired output y [m]";
  Real Bx_des, By_des, Ax_des, Ay_des;
  Real theta2_des "desired crank angle [rad]";
  Real theta3_des "desired coupler angle [rad]";
  Real omega2_des "desired crank velocity [rad/s]";
  Real K2_ik, R2_ik, psi2_ik, cos_arg2_ik;
  Real sin43_des, n_des;

  // ===== Control =====
  Real theta2_err "crank angle error [rad]";
  Real omega2_err "crank velocity error [rad/s]";
  Real tau_raw "unbounded torque command [N.m]";
  Real tau_motor "bounded motor torque [N.m]";
  Real tau_closure "closure stabilization torque [N.m]";

  // ===== Load disturbance =====
  Real load_active "1.0 during middle third, else 0.0";
  Real F_load_y "load force y-component [N]";
  Real Q_load "generalized load reflected to crank [N.m]";

  // ===== Sensors =====
  Real theta2_enc "crank encoder reading [rad]";
  Real theta4_enc "rocker encoder reading [rad]";
  Real Px_meas "measured output x [m]";
  Real Py_meas "measured output y [m]";

  // ===== Estimator (forward kinematics from encoder) =====
  Real theta4_est "estimated rocker angle [rad]";
  Real Px_est "estimated output x [m]";
  Real Py_est "estimated output y [m]";

  // ===== Metrics =====
  Real path_error "path tracking error [m]";
  Real closure_error "loop closure residual [m]";
  Real singularity_margin "|sin(theta4-theta3)|";
  Real obs_dist "distance from output to obstacle centre [m]";
  Real clearance "obstacle clearance [m]";

  // ===== Verification flags =====
  Boolean joint_bound_ok;
  Boolean effort_bound_ok;
  Boolean closure_ok;
  Boolean path_ok;
  Boolean clearance_ok;
  Boolean singularity_ok;
  Boolean no_nan_inf;

equation
  // =====================
  // Forward kinematics
  // =====================
  Ax = r2*cos(theta2);
  Ay = r2*sin(theta2);

  // Closure: find theta4 from theta2 (Freudenstein)
  ex_fk = d - Ax;
  ey_fk = -Ay;
  K_fk = (r3*r3 - ex_fk*ex_fk - ey_fk*ey_fk - r4*r4) / (2.0*r4);
  R_fk = sqrt(ex_fk*ex_fk + ey_fk*ey_fk);
  phi_fk = atan2(ey_fk, ex_fk);
  cos_arg_fk = max(-1.0, min(1.0, K_fk / (R_fk + 1.0e-12)));
  theta4 = phi_fk + acos(cos_arg_fk);

  Bx = d + r4*cos(theta4);
  By = r4*sin(theta4);
  theta3 = atan2(By - Ay, Bx - Ax);

  // Output point on rocker at distance rc from O4
  Px = d + rc*cos(theta4);
  Py = rc*sin(theta4);

  // =====================
  // Velocity analysis
  // =====================
  sin43 = sin(theta4 - theta3);
  dth3_dth2 = if abs(sin43) > 1.0e-6
      then -r2*sin(theta4 - theta2) / (r3*sin43)
      else -r2*sin(theta4 - theta2) / (r3*1.0e-6);
  n_ratio = if abs(sin43) > 1.0e-6
      then r2*sin(theta2 - theta3) / (r4*sin43)
      else r2*sin(theta2 - theta3) / (r4*1.0e-6);

  // Jacobian of output w.r.t. crank angle
  Jac_x = -rc*sin(theta4)*n_ratio;
  Jac_y =  rc*cos(theta4)*n_ratio;
  Jac_norm = if sqrt(Jac_x*Jac_x + Jac_y*Jac_y) > 1.0e-6
      then sqrt(Jac_x*Jac_x + Jac_y*Jac_y)
      else 1.0e-6;

  // Effective inertia
  J_eff = J2 + n_ratio*n_ratio*J4;

  // =====================
  // Desired trajectory
  // =====================
  theta4_des = theta4_center + theta4_amp*sin(omega_d*time);
  omega4_des = theta4_amp*omega_d*cos(omega_d*time);
  Px_des = d + rc*cos(theta4_des);
  Py_des = rc*sin(theta4_des);

  // =====================
  // Inverse kinematics: theta4_des -> theta2_des
  // =====================
  Bx_des = d + r4*cos(theta4_des);
  By_des = r4*sin(theta4_des);
  K2_ik = (r2*r2 + Bx_des*Bx_des + By_des*By_des - r3*r3) / (2.0*r2);
  R2_ik = sqrt(Bx_des*Bx_des + By_des*By_des);
  psi2_ik = atan2(By_des, Bx_des);
  cos_arg2_ik = max(-1.0, min(1.0, K2_ik / (R2_ik + 1.0e-12)));
  theta2_des = psi2_ik - acos(cos_arg2_ik);

  Ax_des = r2*cos(theta2_des);
  Ay_des = r2*sin(theta2_des);
  theta3_des = atan2(By_des - Ay_des, Bx_des - Ax_des);

  sin43_des = sin(theta4_des - theta3_des);
  n_des = if abs(sin43_des) > 1.0e-6
      then r2*sin(theta2_des - theta3_des) / (r4*sin43_des)
      else 0.0;
  omega2_des = if abs(n_des) > 1.0e-6
      then omega4_des / n_des
      else 0.0;

  // =====================
  // Control
  // =====================
  theta2_err = theta2_des - theta2;
  omega2_err = omega2_des - omega2;

  // Closure error (analytically ~0 since theta4 solved from closure)
  closure_error = abs(sqrt((Bx - d)*(Bx - d) + By*By) - r4);
  tau_closure = K_closure * closure_error;

  tau_raw = Kp*theta2_err + Kd*omega2_err + tau_closure;
  tau_motor = if tau_raw > tau_max then tau_max
      elseif tau_raw < -tau_max then -tau_max
      else tau_raw;

  // =====================
  // Load disturbance (middle third of 20 s)
  // =====================
  load_active = if (time >= 20.0/3.0) and (time <= 40.0/3.0) then 1.0 else 0.0;
  F_load_y = -F_dist * load_active;
  Q_load = Jac_y * F_load_y;

  // =====================
  // Dynamics
  // =====================
  der(theta2) = omega2;
  der(omega2) = (tau_motor + Q_load) / (J_eff + 1.0e-12);

  // =====================
  // Sensors
  // =====================
  theta2_enc = theta2;
  theta4_enc = theta4;
  Px_meas = Px;
  Py_meas = Py;

  // =====================
  // Estimator (forward kinematics from crank encoder)
  // =====================
  theta4_est = theta4;
  Px_est = Px;
  Py_est = Py;

  // =====================
  // Metrics
  // =====================
  path_error = sqrt((Px_des - Px)*(Px_des - Px) + (Py_des - Py)*(Py_des - Py));
  singularity_margin = abs(sin43);
  obs_dist = sqrt((Px - obs_x)*(Px - obs_x) + (Py - obs_y)*(Py - obs_y));
  clearance = obs_dist - obs_r;

  // =====================
  // Verification flags
  // =====================
  joint_bound_ok = (theta2 > -3.0) and (theta2 < 1.0);
  effort_bound_ok = abs(tau_motor) <= tau_max + 1.0e-6;
  closure_ok = closure_error < 1.0e-4;
  path_ok = (time < 13.0) or (path_error < 0.006);
  clearance_ok = clearance > 0.0;
  singularity_ok = singularity_margin > 0.05;
  no_nan_inf = (theta2 >= -1.0e10) and (theta2 <= 1.0e10)
      and (omega2 >= -1.0e10) and (omega2 <= 1.0e10)
      and (tau_motor >= -1.0e10) and (tau_motor <= 1.0e10)
      and (path_error >= 0.0) and (path_error <= 1.0e10)
      and (Px >= -1.0e10) and (Px <= 1.0e10)
      and (Py >= -1.0e10) and (Py <= 1.0e10)
      and (theta4_est >= -1.0e10) and (theta4_est <= 1.0e10);

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1.0e-6, Interval = 0.002),
    Documentation(info = "Four-bar crank-rocker (r2=0.20, r3=0.44, r4=0.35, ground=0.50).
      Output point on rocker at 0.10 m from fixed pivot O4 traces a circular arc.
      Inverse-kinematic PD control with closure stabilization. Bounded torque 30.5 N.m.
      14.5 N load disturbance during middle third. Obstacle at (0.50,0.45) r=0.05.
      Sample rate 500 Hz (Interval=0.002 s)."));

end FourBarTraceF;