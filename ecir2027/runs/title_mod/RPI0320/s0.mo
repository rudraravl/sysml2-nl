model StewartTraceB
  constant Real pi = 3.141592653589793;
  constant Real phi1 = 0.0;
  constant Real phi2 = pi/3.0;
  constant Real phi3 = 2.0*pi/3.0;
  constant Real phi4 = pi;
  constant Real phi5 = 4.0*pi/3.0;
  constant Real phi6 = 5.0*pi/3.0;

  // Physical parameters stated in the request
  parameter Real Rb = 0.45 "fixed base radius [m]";
  parameter Real Rp = 0.32 "moving platform radius [m]";
  parameter Real c = Rb - Rp "base minus platform radial offset [m]";
  parameter Real h = 0.70 "nominal platform height [m] (assumed, not stated)";
  parameter Real Rpath = 0.10 "traced circle radius [m]";
  parameter Real Tfinal = 10.0 "mission duration [s]";
  parameter Real omega = 2.0*pi/Tfinal "one revolution in 10 s (assumed)";
  parameter Real m = 36.0 "moving platform mass [kg]";
  parameter Real Lmin = 0.55 "minimum strut length [m]";
  parameter Real Lmax = 0.85 "maximum strut length [m]";
  parameter Real Fmax = 3444.0 "per-strut force command magnitude limit [N]";
  parameter Real Ts = 0.01 "control and sensor sample period [s], 100 Hz";
  parameter Real Kp_l = 30000.0 "inverse-kinematic length tracking gain [N/m]";
  parameter Real Kd_l = 3000.0 "inverse-kinematic length damping gain [N*s/m]";
  parameter Real Kclosure = 5000.0 "closure stabilization gain [N/m]";
  parameter Real Fdist = 7.0 "controlled middle-third output load [N]";
  parameter Real obs_x = 0.80 "obstacle x position [m] (assumed, outside circle)";
  parameter Real obs_y = 0.0 "obstacle y position [m] (assumed)";

  parameter Real x0 = Rpath "initial output x [m]";
  parameter Real y0 = 0.0 "initial output y [m]";
  parameter Real z0 = h "initial output z [m]";

  parameter Real l1_init = sqrt((x0 - c*cos(phi1))^2 + (y0 - c*sin(phi1))^2 + z0^2);
  parameter Real l2_init = sqrt((x0 - c*cos(phi2))^2 + (y0 - c*sin(phi2))^2 + z0^2);
  parameter Real l3_init = sqrt((x0 - c*cos(phi3))^2 + (y0 - c*sin(phi3))^2 + z0^2);
  parameter Real l4_init = sqrt((x0 - c*cos(phi4))^2 + (y0 - c*sin(phi4))^2 + z0^2);
  parameter Real l5_init = sqrt((x0 - c*cos(phi5))^2 + (y0 - c*sin(phi5))^2 + z0^2);
  parameter Real l6_init = sqrt((x0 - c*cos(phi6))^2 + (y0 - c*sin(phi6))^2 + z0^2);

  // Continuous output-pose state
  Real x(start=x0, fixed=true) "output x [m]";
  Real y(start=y0, fixed=true) "output y [m]";
  Real z(start=z0, fixed=true) "output z [m]";
  Real vx(start=0.0, fixed=true) "output velocity x [m/s]";
  Real vy(start=0.0, fixed=true) "output velocity y [m/s]";
  Real vz(start=0.0, fixed=true) "output velocity z [m/s]";

  // Actual strut lengths and direction unit vectors from base to platform
  Real dx1, dy1, l1, l1_safe, u1x, u1y, u1z;
  Real dx2, dy2, l2, l2_safe, u2x, u2y, u2z;
  Real dx3, dy3, l3, l3_safe, u3x, u3y, u3z;
  Real dx4, dy4, l4, l4_safe, u4x, u4y, u4z;
  Real dx5, dy5, l5, l5_safe, u5x, u5y, u5z;
  Real dx6, dy6, l6, l6_safe, u6x, u6y, u6z;

  // Desired trajectory and error metrics
  Real xd "desired output x [m]";
  Real yd "desired output y [m]";
  Real zd "desired output z [m]";
  Real path_error "actual path tracking error [m]";
  Real primary_tracking_error "primary path error [m], required < 0.01 after 6.5 s";
  Real Fdist_x "controlled output load disturbance in x [N]";
  Real clearance "horizontal clearance from obstacle to platform surface [m]";

  // Bounds and margins
  Real length_min "minimum actual strut length [m]";
  Real length_max "maximum actual strut length [m]";
  Real joint_bound_margin "remaining joint length margin [m]";
  Real effort_max "maximum commanded strut force magnitude [N]";
  Real effort_bound_margin "remaining effort margin [N]";
  Real Mxx, Mxy, Mxz, Myy, Myz, Mzz, detM;
  Real singularity_margin "det(JJ^T)^(1/3), positive away from singularity";

  // Discrete command traces, updated at 100 Hz
  discrete Real f1_cmd(start=0.0) "commanded strut 1 force [N]";
  discrete Real f2_cmd(start=0.0) "commanded strut 2 force [N]";
  discrete Real f3_cmd(start=0.0) "commanded strut 3 force [N]";
  discrete Real f4_cmd(start=0.0) "commanded strut 4 force [N]";
  discrete Real f5_cmd(start=0.0) "commanded strut 5 force [N]";
  discrete Real f6_cmd(start=0.0) "commanded strut 6 force [N]";

  discrete Real ld1(start=l1_init) "commanded strut 1 length [m]";
  discrete Real ld2(start=l2_init) "commanded strut 2 length [m]";
  discrete Real ld3(start=l3_init) "commanded strut 3 length [m]";
  discrete Real ld4(start=l4_init) "commanded strut 4 length [m]";
  discrete Real ld5(start=l5_init) "commanded strut 5 length [m]";
  discrete Real ld6(start=l6_init) "commanded strut 6 length [m]";

  discrete Real ld1_vel(start=0.0) "commanded strut 1 length velocity [m/s]";
  discrete Real ld2_vel(start=0.0) "commanded strut 2 length velocity [m/s]";
  discrete Real ld3_vel(start=0.0) "commanded strut 3 length velocity [m/s]";
  discrete Real ld4_vel(start=0.0) "commanded strut 4 length velocity [m/s]";
  discrete Real ld5_vel(start=0.0) "commanded strut 5 length velocity [m/s]";
  discrete Real ld6_vel(start=0.0) "commanded strut 6 length velocity [m/s]";

  // Discrete sensor traces, updated at 100 Hz
  discrete Real sensorX(start=x0) "direct measured output x [m]";
  discrete Real sensorY(start=y0) "direct measured output y [m]";
  discrete Real sensorZ(start=z0) "direct measured output z [m]";

  discrete Real le1(start=l1_init) "encoder strut 1 length [m]";
  discrete Real le2(start=l2_init) "encoder strut 2 length [m]";
  discrete Real le3(start=l3_init) "encoder strut 3 length [m]";
  discrete Real le4(start=l4_init) "encoder strut 4 length [m]";
  discrete Real le5(start=l5_init) "encoder strut 5 length [m]";
  discrete Real le6(start=l6_init) "encoder strut 6 length [m]";

  discrete Real le1_vel(start=0.0) "encoder strut 1 length velocity [m/s]";
  discrete Real le2_vel(start=0.0) "encoder strut 2 length velocity [m/s]";
  discrete Real le3_vel(start=0.0) "encoder strut 3 length velocity [m/s]";
  discrete Real le4_vel(start=0.0) "encoder strut 4 length velocity [m/s]";
  discrete Real le5_vel(start=0.0) "encoder strut 5 length velocity [m/s]";
  discrete Real le6_vel(start=0.0) "encoder strut 6 length velocity [m/s]";

  // Encoder-based closure estimator
  discrete Real x_est(start=x0) "closure-estimated output x [m]";
  discrete Real y_est(start=y0) "closure-estimated output y [m]";
  discrete Real z_est(start=z0) "closure-estimated output z [m]";
  discrete Real closure_error(start=0.0) "redundant closure residual [m]";

protected
  discrete Real ld1_prev(start=l1_init);
  discrete Real ld2_prev(start=l2_init);
  discrete Real ld3_prev(start=l3_init);
  discrete Real ld4_prev(start=l4_init);
  discrete Real ld5_prev(start=l5_init);
  discrete Real ld6_prev(start=l6_init);

  discrete Real le1_prev(start=l1_init);
  discrete Real le2_prev(start=l2_init);
  discrete Real le3_prev(start=l3_init);
  discrete Real le4_prev(start=l4_init);
  discrete Real le5_prev(start=l5_init);
  discrete Real le6_prev(start=l6_init);

  discrete Real S_est;
  discrete Real z2_est;
  discrete Real lp2_sq, lp4_sq, lp6_sq;
  discrete Real lp2, lp4, lp6;
  discrete Real f1_unsat, f2_unsat, f3_unsat, f4_unsat, f5_unsat, f6_unsat;

equation
  // Desired circular trajectory
  xd = Rpath*cos(omega*time);
  yd = Rpath*sin(omega*time);
  zd = h;

  // Middle-third controlled disturbance, direction assumed +x
  Fdist_x = if time >= Tfinal/3.0 and time <= 2.0*Tfinal/3.0 then Fdist else 0.0;

  // Platform translational dynamics; orientation fixed in this reduced model
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  m*der(vx) = f1_cmd*u1x + f2_cmd*u2x + f3_cmd*u3x + f4_cmd*u4x + f5_cmd*u5x + f6_cmd*u6x + Fdist_x;
  m*der(vy) = f1_cmd*u1y + f2_cmd*u2y + f3_cmd*u3y + f4_cmd*u4y + f5_cmd*u5y + f6_cmd*u6y;
  m*der(vz) = f1_cmd*u1z + f2_cmd*u2z + f3_cmd*u3z + f4_cmd*u4z + f5_cmd*u5z + f6_cmd*u6z;

  // Strut 1 kinematics
  dx1 = x - c*cos(phi1);
  dy1 = y - c*sin(phi1);
  l1 = sqrt(dx1*dx1 + dy1*dy1 + z*z);
  l1_safe = max(l1, 1e-9);
  u1x = dx1/l1_safe;
  u1y = dy1/l1_safe;
  u1z = z/l1_safe;

  // Strut 2 kinematics
  dx2 = x - c*cos(phi2);
  dy2 = y - c*sin(phi2);
  l2 = sqrt(dx2*dx2 + dy2*dy2 + z*z);
  l2_safe = max(l2, 1e-9);
  u2x = dx2/l2_safe;
  u2y = dy2/l2_safe;
  u2z = z/l2_safe;

  // Strut 3 kinematics
  dx3 = x - c*cos(phi3);
  dy3 = y - c*sin(phi3);
  l3 = sqrt(dx3*dx3 + dy3*dy3 + z*z);
  l3_safe = max(l3, 1e-9);
  u3x = dx3/l3_safe;
  u3y = dy3/l3_safe;
  u3z = z/l3_safe;

  // Strut 4 kinematics
  dx4 = x - c*cos(phi4);
  dy4 = y - c*sin(phi4);
  l4 = sqrt(dx4*dx4 + dy4*dy4 + z*z);
  l4_safe = max(l4, 1e-9);
  u4x = dx4/l4_safe;
  u4y = dy4/l4_safe;
  u4z = z/l4_safe;

  // Strut 5 kinematics
  dx5 = x - c*cos(phi5);
  dy5 = y - c*sin(phi5);
  l5 = sqrt(dx5*dx5 + dy5*dy5 + z*z);
  l5_safe = max(l5, 1e-9);
  u5x = dx5/l5_safe;
  u5y = dy5/l5_safe;
  u5z = z/l5_safe;

  // Strut 6 kinematics
  dx6 = x - c*cos(phi6);
  dy6 = y - c*sin(phi6);
  l6 = sqrt(dx6*dx6 + dy6*dy6 + z*z);
  l6_safe = max(l6, 1e-9);
  u6x = dx6/l6_safe;
  u6y = dy6/l6_safe;
  u6z = z/l6_safe;

  // Tracking and clearance
  path_error = sqrt((x - xd)^2 + (y - yd)^2 + (z - zd)^2);
  primary_tracking_error = path_error;
  clearance = sqrt((x - obs_x)^2 + (y - obs_y)^2) - Rp;

  // Joint bounds
  length_min = min(l1, min(l2, min(l3, min(l4, min(l5, l6)))));
  length_max = max(l1, max(l2, max(l3, max(l4, max(l5, l6)))));
  joint_bound_margin = min(length_min - Lmin, Lmax - length_max);

  // Effort bounds
  effort_max = max(abs(f1_cmd), max(abs(f2_cmd), max(abs(f3_cmd), max(abs(f4_cmd), max(abs(f5_cmd), abs(f6_cmd))))));
  effort_bound_margin = Fmax - effort_max;

  // Singularity margin from strut direction matrix
  Mxx = u1x*u1x + u2x*u2x + u3x*u3x + u4x*u4x + u5x*u5x + u6x*u6x;
  Mxy = u1x*u1y + u2x*u2y + u3x*u3y + u4x*u4y + u5x*u5y + u6x*u6y;
  Mxz = u1x*u1z + u2x*u2z + u3x*u3z + u4x*u4z + u5x*u5z + u6x*u6z;
  Myy = u1y*u1y + u2y*u2y + u3y*u3y + u4y*u4y + u5y*u5y + u6y*u6y;
  Myz = u1y*u1z + u2y*u2z + u3y*u3z + u4y*u4z + u5y*u5z + u6y*u6z;
  Mzz = u1z*u1z + u2z*u2z + u3z*u3z + u4z*u4z + u5z*u5z + u6z*u6z;
  detM = Mxx*(Myy*Mzz - Myz*Myz) - Mxy*(Mxy*Mzz - Myz*Mxz) + Mxz*(Mxy*Myz - Myy*Mxz);
  singularity_margin = if abs(detM) < 1e-12 then 0.0 else abs(detM)^(1.0/3.0);

initial algorithm
  ld1_prev := l1_init;
  ld2_prev := l2_init;
  ld3_prev := l3_init;
  ld4_prev := l4_init;
  ld5_prev := l5_init;
  ld6_prev := l6_init;
  le1_prev := l1_init;
  le2_prev := l2_init;
  le3_prev := l3_init;
  le4_prev := l4_init;
  le5_prev := l5_init;
  le6_prev := l6_init;

algorithm
  when sample(0, Ts) then
    // Direct pose and actuator encoder measurements
    sensorX := x;
    sensorY := y;
    sensorZ := z;
    le1 := l1;
    le2 := l2;
    le3 := l3;
    le4 := l4;
    le5 := l5;
    le6 := l6;

    // Inverse kinematics: desired strut lengths from desired pose
    ld1 := max(Lmin, min(Lmax, sqrt((xd - c*cos(phi1))^2 + (yd - c*sin(phi1))^2 + zd^2)));
    ld2 := max(Lmin, min(Lmax, sqrt((xd - c*cos(phi2))^2 + (yd - c*sin(phi2))^2 + zd^2)));
    ld3 := max(Lmin, min(Lmax, sqrt((xd - c*cos(phi3))^2 + (yd - c*sin(phi3))^2 + zd^2)));
    ld4 := max(Lmin, min(Lmax, sqrt((xd - c*cos(phi4))^2 + (yd - c*sin(phi4))^2 + zd^2)));
    ld5 := max(Lmin, min(Lmax, sqrt((xd - c*cos(phi5))^2 + (yd - c*sin(phi5))^2 + zd^2)));
    ld6 := max(Lmin, min(Lmax, sqrt((xd - c*cos(phi6))^2 + (yd - c*sin(phi6))^2 + zd^2)));

    // Commanded length velocities by finite difference
    ld1_vel := (ld1 - ld1_prev)/Ts;
    ld2_vel := (ld2 - ld2_prev)/Ts;
    ld3_vel := (ld3 - ld3_prev)/Ts;
    ld4_vel := (ld4 - ld4_prev)/Ts;
    ld5_vel := (ld5 - ld5_prev)/Ts;
    ld6_vel := (ld6 - ld6_prev)/Ts;
    ld1_prev := ld1;
    ld2_prev := ld2;
    ld3_prev := ld3;
    ld4_prev := ld4;
    ld5_prev := ld5;
    ld6_prev := ld6;

    // Encoder length velocities by finite difference
    le1_vel := (le1 - le1_prev)/Ts;
    le2_vel := (le2 - le2_prev)/Ts;
    le3_vel := (le3 - le3_prev)/Ts;
    le4_vel := (le4 - le4_prev)/Ts;
    le5_vel := (le5 - le5_prev)/Ts;
    le6_vel := (le6 - le6_prev)/Ts;
    le1_prev := le1;
    le2_prev := le2;
    le3_prev := le3;
    le4_prev := le4;
    le5_prev := le5;
    le6_prev := le6;

    // Closure estimate from nonredundant struts 1,3,5
    S_est := (le1*le1 + le3*le3 + le5*le5)/3.0;
    x_est := (S_est - le1*le1)/(2.0*c);
    y_est := (le5*le5 - le3*le3)/(2.0*sqrt(3.0)*c);
    z2_est := S_est - x_est*x_est - y_est*y_est - c*c;
    z_est := if z2_est > 0.0 then sqrt(z2_est) else 0.0;

    // Redundant strut predictions for closure residual
    lp2_sq := S_est - 2.0*c*(x_est*cos(phi2) + y_est*sin(phi2));
    lp4_sq := S_est - 2.0*c*(x_est*cos(phi4) + y_est*sin(phi4));
    lp6_sq := S_est - 2.0*c*(x_est*cos(phi6) + y_est*sin(phi6));
    lp2 := if lp2_sq > 0.0 then sqrt(lp2_sq) else 0.0;
    lp4 := if lp4_sq > 0.0 then sqrt(lp4_sq) else 0.0;
    lp6 := if lp6_sq > 0.0 then sqrt(lp6_sq) else 0.0;
    closure_error := sqrt((le2 - lp2)^2 + (le4 - lp4)^2 + (le6 - lp6)^2);

    // Inverse-kinematic trajectory control with closure stabilization
    f1_unsat := Kp_l*(ld1 - le1) + Kd_l*(ld1_vel - le1_vel);
    f2_unsat := Kp_l*(ld2 - le2) + Kd_l*(ld2_vel - le2_vel) + Kclosure*(lp2 - le2);
    f3_unsat := Kp_l*(ld3 - le3) + Kd_l*(ld3_vel - le3_vel);
    f4_unsat := Kp_l*(ld4 - le4) + Kd_l*(ld4_vel - le4_vel) + Kclosure*(lp4 - le4);
    f5_unsat := Kp_l*(ld5 - le5) + Kd_l*(ld5_vel - le5_vel);
    f6_unsat := Kp_l*(ld6 - le6) + Kd_l*(ld6_vel - le6_vel) + Kclosure*(lp6 - le6);

    // Per-strut force limits
    f1_cmd := max(-Fmax, min(Fmax, f1_unsat));
    f2_cmd := max(-Fmax, min(Fmax, f2_unsat));
    f3_cmd := max(-Fmax, min(Fmax, f3_unsat));
    f4_cmd := max(-Fmax, min(Fmax, f4_unsat));
    f5_cmd := max(-Fmax, min(Fmax, f5_unsat));
    f6_cmd := max(-Fmax, min(Fmax, f6_unsat));
  end when;

  annotation(experiment(StopTime=10, Interval=0.01, Tolerance=1e-6));
end StewartTraceB;