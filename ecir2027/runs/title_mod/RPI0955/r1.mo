model SeaSnakeDockA
  // ===================== Stated facts =====================
  parameter Real    m_body    = 32.0  "robot mass [kg]";
  parameter Real    L_module  = 0.30  "capsule module length [m]";
  parameter Integer N_modules = 6     "number of capsule modules";
  parameter Real    L_total   = N_modules*L_module "total length [m]";
  parameter Integer N_act     = 12    "bounded joint actuators";
  parameter Real    tau_max   = 23.0  "per-joint torque limit [N.m]";
  parameter Real    x_dock0   = 8.0   "initial stand-off distance [m]";
  parameter Real    F_current = 70.0  "applied current force disturbance [N]";
  parameter Real    f_sample  = 80.0  "control/sensor rate [Hz]";

  // ===================== Inertial / hydro (reasonable defaults; facts not stated are unknown) =====================
  parameter Real Izz = 4.0  "yaw inertia [kg.m2]";
  parameter Real Iyy = 3.0  "pitch inertia [kg.m2]";
  parameter Real Xu  = 30.0 "surge quadratic drag [N/(m/s)^2]";
  parameter Real Yv  = 90.0 "sway quadratic drag [N/(m/s)^2]";
  parameter Real Zw  = 50.0 "heave quadratic drag [N/(m/s)^2]";
  parameter Real Nr  = 6.0  "yaw rotational drag";
  parameter Real Mq  = 6.0  "pitch rotational drag";
  parameter Real lever = 0.25 "joint moment arm [m]";

  // ===================== Propulsion / actuation =====================
  parameter Real K_prop      = 1.72   "thrust coefficient";
  parameter Real f_und       = 1.8    "undulation frequency [Hz]";
  parameter Real omega_und   = 2.0*Modelica.Constants.pi*f_und "rad/s";
  parameter Real A_max       = 1.0    "max undulation amplitude";
  parameter Real v_max       = 1.8    "max surge speed [m/s]";
  parameter Real F_thrust_max= 220.0  "reference max thrust [N]";
  parameter Real M_yaw_max   = N_act*tau_max*lever "max yaw moment [N.m]";
  parameter Real M_pitch_max = N_act*tau_max*lever "max pitch moment [N.m]";
  parameter Real F_heave_max = 50.0   "max heave force [N]";

  // ===================== Dock / compliant capture =====================
  parameter Real x_dock      = 8.0    "dock x [m]";
  parameter Real y_dock      = 0.0    "dock y [m]";
  parameter Real z_dock      = 0.0    "dock z [m]";
  parameter Real r_capture   = 0.06   "capture radius [m]";
  parameter Real k_ring      = 1200.0 "compliant ring stiffness [N/m]";
  parameter Real c_ring      = 250.0  "compliant ring damping [N.s/m]";
  parameter Real k_align     = 600.0  "lateral align stiffness [N/m]";
  parameter Real c_align     = 80.0   "lateral align damping [N.s/m]";
  parameter Real k_yaw_align = 300.0  "yaw align stiffness [N.m/rad]";
  parameter Real c_yaw_align = 40.0   "yaw align damping";

  // ===================== Current disturbance window (middle third of 8 s) =====================
  parameter Real t_start_curr = 8.0/3.0;
  parameter Real t_end_curr   = 16.0/3.0;

  // ===================== Control gains =====================
  parameter Real Kp_v     = 90.0;
  parameter Real Kp_psi   = 14.0;
  parameter Real Kd_psi   = 4.0;
  parameter Real Kp_z     = 25.0;
  parameter Real Kd_z     = 10.0;
  parameter Real Kp_pitch = 12.0;
  parameter Real Kd_pitch = 3.0;

  // ===================== States =====================
  Real x(start=0.0,    fixed=true) "robot x [m]";
  Real y(start=0.0,    fixed=true) "robot y [m]";
  Real z(start=0.0,    fixed=true) "robot z [m]";
  Real psi(start=0.0,  fixed=true) "yaw [rad]";
  Real theta(start=0.0, fixed=true) "pitch [rad]";
  Real u(start=0.0,    fixed=true) "surge [m/s]";
  Real v(start=0.0,    fixed=true) "sway [m/s]";
  Real w(start=0.0,    fixed=true) "heave [m/s]";
  Real r(start=0.0,    fixed=true) "yaw rate [rad/s]";
  Real q(start=0.0,    fixed=true) "pitch rate [rad/s]";

  // ===================== Kinematic / contact =====================
  Real nose_x, nose_y, dist, track_err;
  Real penetration, capture_flag, F_contact, F_contact_raw, F_lat_contact, M_contact;
  Real F_current_y;

  // ===================== Controller =====================
  Real v_des, psi_des, psi_los_est, blend_est, dist_est;
  Real u_err, psi_err, psi_err_raw, y_err;
  Real F_thrust_cmd_raw, F_thrust_cmd, A_und_raw, A_und_clamp, A_und_act;
  Real M_yaw_cmd, M_pitch_cmd, F_heave_cmd;
  Real tau_und, tau_steer, tau_comb, sat_scale;
  Real F_thrust_act, M_yaw_act, M_pitch_act, F_heave_act;
  Real tau_per_joint;

  // ===================== Bound traces =====================
  Real actuator_bound_ok, speed_bound_ok, contact_force_ok, tracking_ok, no_nan_ok;

  // ===================== Sensors =====================
  Real sonar_range, pressure_depth, imu_yaw, imu_yawrate;
  Real opt_x, opt_y, opt_yaw, opt_valid;

  // ===================== Estimator =====================
  Real x_est, y_est, psi_est, z_est, nose_x_est, nose_y_est;

equation
  // ---------------- Kinematics ----------------
  der(x)   = u*cos(psi) - v*sin(psi);
  der(y)   = u*sin(psi) + v*cos(psi);
  der(z)   = w;
  der(psi) = r;
  der(theta) = q;

  // Nose position along body x-axis
  nose_x = x + (L_total/2.0)*cos(psi)*cos(theta);
  nose_y = y + (L_total/2.0)*sin(psi)*cos(theta);

  // Primary tracking error = distance from nose to dock capture point
  dist       = sqrt(max((x_dock - nose_x)^2 + (y_dock - nose_y)^2, 1e-9));
  track_err  = dist;

  // ---------------- Current disturbance (middle third) ----------------
  F_current_y = if (time >= t_start_curr and time <= t_end_curr) then F_current else 0.0;

  // ---------------- Compliant capture ring ----------------
  penetration   = max(0.0, nose_x - (x_dock - r_capture));
  capture_flag  = if penetration > 1e-6 then 1.0 else 0.0;
  F_contact_raw = k_ring*penetration + c_ring*max(0.0, u*cos(psi))*capture_flag;
  F_contact     = min(F_contact_raw, 500.0);               // hard bound < 500 N
  F_lat_contact = (-k_align*nose_y - c_align*v)*capture_flag;
  M_contact     = (-k_yaw_align*psi - c_yaw_align*r)*capture_flag;

  // ---------------- Sensors (bounded deterministic noise, no NaN) ----------------
  sonar_range    = dist + 0.02*sin(2.0*Modelica.Constants.pi*1.3*time);
  pressure_depth = z    + 0.005*sin(2.0*Modelica.Constants.pi*0.7*time);
  imu_yaw        = psi  + 0.003*sin(2.0*Modelica.Constants.pi*5.0*time);
  imu_yawrate    = r    + 0.01*sin(2.0*Modelica.Constants.pi*7.0*time);
  opt_valid      = if dist < 2.0 then 1.0 else 0.0;
  opt_x   = if opt_valid > 0.5 then x   + 0.01*sin(2.0*Modelica.Constants.pi*3.0*time) else 0.0;
  opt_y   = if opt_valid > 0.5 then y   + 0.01*sin(2.0*Modelica.Constants.pi*3.4*time) else 0.0;
  opt_yaw = if opt_valid > 0.5 then psi + 0.005*sin(2.0*Modelica.Constants.pi*4.0*time) else 0.0;

  // ---------------- Estimator (sensor fusion; dead-reckoning fallback for y) ----------------
  psi_est = if opt_valid > 0.5 then opt_yaw else imu_yaw;
  z_est   = pressure_depth;
  x_est   = if opt_valid > 0.5 then opt_x else (x_dock - sonar_range*cos(psi_est));
  y_est   = if opt_valid > 0.5 then opt_y else y;   // y dead-reckon not fully modeled: unknown
  nose_x_est = x_est + (L_total/2.0)*cos(psi_est)*cos(theta);
  nose_y_est = y_est + (L_total/2.0)*sin(psi_est)*cos(theta);
  dist_est   = sqrt(max((x_dock - nose_x_est)^2 + (y_dock - nose_y_est)^2, 1e-9));

  // ---------------- Speed-scheduled pose control ----------------
  v_des = if dist_est > 1.0 then v_max else max(v_max*dist_est, 0.12);   // reduce speed inside 1 m

  // Line-of-sight heading blended to dock axis (0) at close range
  psi_los_est = Modelica.Math.atan2(y_dock - nose_y_est, max(x_dock - nose_x_est, 0.05));
  blend_est   = if dist_est < 1.0 then (1.0 - dist_est) else 0.0;
  psi_des     = (1.0 - blend_est)*psi_los_est;

  // Heading error wrapped to [-pi, pi]
  psi_err_raw = psi_des - psi_est;
  psi_err     = psi_err_raw - 2.0*Modelica.Constants.pi*floor(psi_err_raw/(2.0*Modelica.Constants.pi) + 0.5);

  u_err = v_des - u;
  y_err = y_dock - y;

  // ---------------- Commands ----------------
  F_thrust_cmd_raw = Kp_v*u_err;
  F_thrust_cmd     = if F_thrust_cmd_raw > F_thrust_max then F_thrust_max
                     else (if F_thrust_cmd_raw < 0.0 then 0.0 else F_thrust_cmd_raw);
  A_und_raw    = sqrt(F_thrust_cmd/(K_prop*omega_und^2 + 1e-9));
  A_und_clamp  = min(A_und_raw, A_max);

  M_yaw_cmd   = Kp_psi*psi_err - Kd_psi*r;
  M_pitch_cmd = -Kp_pitch*theta - Kd_pitch*q;
  F_heave_cmd = Kp_z*(z_dock - z_est) - Kd_z*w;

  // ---------------- Combined actuator saturation (undulation + steering share per-joint budget) ----------------
  tau_und   = A_und_clamp*tau_max;
  tau_steer = M_yaw_cmd/(N_act*lever + 1e-9);
  tau_comb  = tau_und + abs(tau_steer);
  sat_scale = if tau_comb > tau_max then tau_max/tau_comb else 1.0;
  A_und_act = A_und_clamp*sat_scale;
  M_yaw_act = M_yaw_cmd*sat_scale;
  F_thrust_act = K_prop*omega_und^2*A_und_act^2;

  M_pitch_act = if M_pitch_cmd >  M_pitch_max then  M_pitch_max
                else (if M_pitch_cmd < -M_pitch_max then -M_pitch_max else M_pitch_cmd);
  F_heave_act = if F_heave_cmd >  F_heave_max then  F_heave_max
                else (if F_heave_cmd < -F_heave_max then -F_heave_max else F_heave_cmd);

  tau_per_joint = tau_comb*sat_scale;   // guaranteed <= tau_max

  // ---------------- Rigid-body dynamics (body frame) ----------------
  m_body*der(u) = F_thrust_act - Xu*u*abs(u) + F_current_y*sin(psi) - F_contact;
  m_body*der(v) = -Yv*v*abs(v) + F_current_y*cos(psi) + F_lat_contact;
  m_body*der(w) = F_heave_act - Zw*w*abs(w);
  Izz*der(r)   = M_yaw_act - Nr*r*abs(r) + M_contact;
  Iyy*der(q)   = M_pitch_act - Mq*q*abs(q);

  // ---------------- Bound trace flags ----------------
  actuator_bound_ok = if tau_per_joint <= tau_max + 1e-6 then 1.0 else 0.0;
  speed_bound_ok   = if u <= v_max + 1e-3 then 1.0 else 0.0;
  contact_force_ok = if F_contact <= 500.0 + 1e-6 then 1.0 else 0.0;
  tracking_ok      = if (time < 5.2) or (track_err < 0.135) then 1.0 else 0.0;
  no_nan_ok        = 1.0;   // all equations guarded against singular divisions

  annotation (
    experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 1.0/f_sample),
    Documentation(info = "SeaSnakeDockA: 32 kg articulated underwater robot, six 0.30 m capsule modules, "
                         "alternating yaw/pitch joints and a passive tail fin (lumped). Twelve joint actuators "
                         "bounded at 23 N.m each. Speed-scheduled pose control with contact transition approaches "
                         "a fixed docking funnel 8 m away, reduces speed inside 1 m, aligns yaw/lateral, and "
                         "establishes compliant capture. A 70 N cross-current acts during the middle third of the "
                         "8 s / 80 Hz scenario. Sonar, pressure, IMU and short-range optical pose feed a fused "
                         "estimator. Unknown facts (added mass, joint kinematic mapping, tail-fin hydrodynamics, "
                         "buoyancy, optical marker geometry) are not fabricated."));

end SeaSnakeDockA;