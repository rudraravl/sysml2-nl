model AUVDockA
  // Hull and environment
  parameter Real m = 85.0 "AUV mass [kg]";
  parameter Real L_hull = 1.5 "hull length [m]";
  parameter Real V_disp = 0.083 "displaced volume [m3]";
  parameter Real rho_sw = 1025.0 "seawater density [kg/m3]";
  parameter Real g_acc = 9.81 "gravity [m/s2]";
  parameter Real Iz = 18.0 "yaw inertia [kg.m2]";

  // Actuators
  parameter Real Fmax = 79.2 "per-thruster command magnitude limit [N]";
  parameter Real thr_arm = 0.6 "surge-thruster yaw moment arm [m]";

  // Hydrodynamic linear drag
  parameter Real Xu = 12.0 "surge drag [N.s/m]";
  parameter Real Yv = 500.0 "lateral drag [N.s/m]";
  parameter Real Nr = 18.0 "yaw drag [N.m.s/rad]";
  parameter Real Zw = 40.0 "heave drag [N.s/m]";

  // Docking station geometry
  parameter Real x_dock = 8.0 "dock x [m]";
  parameter Real y_dock = 0.0 "dock y [m]";
  parameter Real z_d = 2.0 "commanded depth [m]";
  parameter Real funnel_reach = 0.6 "funnel mouth reach [m]";
  parameter Real throat_margin = 0.10 "throat compliance margin [m]";

  // Compliant capture ring
  parameter Real k_ring = 1500.0 "capture ring stiffness [N/m]";
  parameter Real c_ring = 250.0 "capture ring damping [N.s/m]";

  // Disturbance
  parameter Real F_current = 70.0 "cross-current force [N]";
  parameter Real t_end = 8.0 "scenario duration [s]";

  // Speed schedule and control gains
  parameter Real v_approach = 2.5 "approach speed [m/s]";
  parameter Real v_capture = 0.3 "reduced capture speed [m/s]";
  parameter Real kp_yaw = 50.0 "heading proportional gain [N.m/rad]";
  parameter Real kd_yaw = 15.0 "heading derivative gain [N.m.s/rad]";
  parameter Real kp_x = 200.0 "surge velocity gain [N.s/m]";
  parameter Real kp_z = 30.0 "depth proportional gain [N/m]";
  parameter Real kd_z = 20.0 "depth derivative gain [N.s/m]";

  // Numerical guard
  parameter Real eps = 1e-9;

  // States
  Real x(start=0.0, fixed=true) "AUV x position [m]";
  Real y(start=0.05, fixed=true) "AUV y position [m]";
  Real z(start=2.0, fixed=true) "AUV depth [m]";
  Real psi(start=0.0, fixed=true) "AUV heading [rad]";
  Real vx(start=0.0, fixed=true) "world x velocity [m/s]";
  Real vy(start=0.0, fixed=true) "world y velocity [m/s]";
  Real vz(start=0.0, fixed=true) "heave velocity [m/s]";
  Real r(start=0.0, fixed=true) "yaw rate [rad/s]";

  // Commands and actuated forces
  Real Fx1_cmd "surge thruster 1 command [N]";
  Real Fx2_cmd "surge thruster 2 command [N]";
  Real Fz1_cmd "heave thruster 1 command [N]";
  Real Fz2_cmd "heave thruster 2 command [N]";
  Real Fx1 "surge thruster 1 force [N]";
  Real Fx2 "surge thruster 2 force [N]";
  Real Fz1 "heave thruster 1 force [N]";
  Real Fz2 "heave thruster 2 force [N]";
  Real Fx_total "total surge command [N]";
  Real tau_yaw "yaw torque command [N.m]";
  Real Fz_total "total heave command [N]";

  // Controller and estimator signals
  Real psi_des "desired heading [rad]";
  Real psi_err "wrapped heading error [rad]";
  Real u_body "body-frame surge speed [m/s]";
  Real u_cmd "surge speed command [m/s]";
  Real dist "range to dock center [m]";

  // Contact and capture
  Real F_funnel_y "funnel lateral centering force [N]";
  Real F_throat_x "throat axial contact force [N]";
  Real pen_x "throat penetration [m]";
  Real F_contact_mag "contact force magnitude [N]";
  Boolean funnel_engaged "funnel centering active";
  Boolean throat_contact "throat contact active";
  Boolean in_contact "any contact active";
  Boolean captured "compliant capture established";

  // Disturbance
  Real F_curr_y "applied cross-current force [N]";

  // Buoyancy
  Real W "weight [N]";
  Real B "buoyancy [N]";

  // Synchronized sensor traces
  Real sonar_range "sonar range to dock [m]";
  Real pressure_depth "pressure-derived depth [m]";
  Real imu_u "IMU surge velocity [m/s]";
  Real imu_r "IMU yaw rate [rad/s]";
  Real optical_x "optical pose x [m]";
  Real optical_y "optical pose y [m]";
  Real optical_psi "optical pose heading [rad]";
  Boolean optical_valid "short-range optical pose valid";

  // Requirement metrics
  Real err_primary "primary tracking error [m]";

equation
  // Weight and buoyancy
  W = m*g_acc;
  B = rho_sw*g_acc*V_disp;

  // Range to dock center (zero-guarded)
  dist = sqrt((x_dock - x)^2 + (y_dock - y)^2 + eps^2) - eps;

  // Body-frame surge speed
  u_body = vx*cos(psi) + vy*sin(psi);

  // Speed-scheduled surge command: full approach speed outside 1 m,
  // reduced capture speed inside 1 m
  u_cmd = if dist >= 1.0 then v_approach else v_capture;

  // Pose control: point at dock in far field, align to approach axis near field
  psi_des = if dist > 0.5 then atan2(y_dock - y, x_dock - x) else 0.0;
  psi_err = atan2(sin(psi_des - psi), cos(psi_des - psi));
  tau_yaw = kp_yaw*psi_err - kd_yaw*r;

  // Surge velocity servo with drag feedforward
  Fx_total = kp_x*(u_cmd - u_body) + Xu*u_cmd;

  // Depth (heave) control
  Fz_total = kp_z*(z_d - z) - kd_z*vz;

  // Thruster allocation: two surge thrusters differential for yaw, two heave thrusters
  Fx1_cmd = Fx_total/2 + tau_yaw/(2*thr_arm);
  Fx2_cmd = Fx_total/2 - tau_yaw/(2*thr_arm);
  Fz1_cmd = Fz_total/2;
  Fz2_cmd = Fz_total/2;

  // Actuator magnitude bounds (bidirectional, per thruster)
  Fx1 = max(-Fmax, min(Fmax, Fx1_cmd));
  Fx2 = max(-Fmax, min(Fmax, Fx2_cmd));
  Fz1 = max(-Fmax, min(Fmax, Fz1_cmd));
  Fz2 = max(-Fmax, min(Fmax, Fz2_cmd));

  // Controlled cross-current disturbance during middle third of scenario
  F_curr_y = if time >= t_end/3 and time <= 2*t_end/3 then F_current else 0.0;

  // Rigid station geometry with compliant capture ring
  funnel_engaged = (x_dock - x) < funnel_reach;
  throat_contact = x > (x_dock - throat_margin);
  in_contact = funnel_engaged;
  pen_x = if throat_contact then (x - (x_dock - throat_margin)) else 0.0;
  F_funnel_y = if funnel_engaged then (-k_ring*(y - y_dock) - c_ring*vy) else 0.0;
  F_throat_x = if throat_contact then (-k_ring*pen_x - c_ring*vx) else 0.0;
  F_contact_mag = sqrt(F_throat_x^2 + F_funnel_y^2 + eps^2);

  // Contact-transition capture condition
  captured = throat_contact and abs(vx) < 0.2 and abs(psi) < 0.15;

  // Translational dynamics (world frame)
  m*der(vx) = (Fx1 + Fx2)*cos(psi) - Xu*vx + F_throat_x;
  m*der(vy) = (Fx1 + Fx2)*sin(psi) - Yv*vy + F_funnel_y + F_curr_y;
  der(x) = vx;
  der(y) = vy;

  // Yaw dynamics
  Iz*der(r) = (Fx1 - Fx2)*thr_arm - Nr*r;
  der(psi) = r;

  // Heave dynamics (near-neutrally buoyant: B - W is small)
  m*der(vz) = Fz1 + Fz2 + (W - B) - Zw*vz;
  der(z) = vz;

  // Synchronized sensor traces
  sonar_range = dist;
  pressure_depth = z;
  imu_u = u_body;
  imu_r = r;
  optical_valid = dist < 2.0;
  optical_x = if optical_valid then x else 0.0;
  optical_y = if optical_valid then y else 0.0;
  optical_psi = if optical_valid then psi else 0.0;

  // Primary tracking error
  err_primary = dist;

  // Requirement enforcement
  assert(F_contact_mag < 500.0, "Contact force exceeded 500 N");
  assert(not (time > 5.2) or (err_primary < 0.135), "Primary tracking error > 0.135 m after 5.2 s");
  assert(abs(Fx1) <= Fmax + 1e-6 and abs(Fx2) <= Fmax + 1e-6, "Surge thruster bound violated");
  assert(abs(Fz1) <= Fmax + 1e-6 and abs(Fz2) <= Fmax + 1e-6, "Heave thruster bound violated");
  assert(abs(u_body) <= 1.2*v_approach, "Speed bound violated");

  annotation(experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125));
end AUVDockA;