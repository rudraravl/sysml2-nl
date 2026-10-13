model DiffRoverRouteF
  "Floating-base differential-drive rover: 4-waypoint planar route, bounded
   path-following and wheel-speed control, 174 N lateral push robustness case
   during the middle third of a 20 s / 500 Hz run."

  // ===== Physical parameters (SI) =====
  parameter Real m      = 19.0  "chassis mass [kg]";
  parameter Real Lx     = 0.65  "chassis length [m]";
  parameter Real Ly     = 0.44  "chassis width [m]";
  parameter Real Lz     = 0.22  "chassis height [m]";
  parameter Real r_w    = 0.10  "driven wheel radius [m]";
  parameter Real L_w    = 0.46  "wheel separation (track) [m]";
  parameter Real mu     = 0.82  "floor friction coefficient [1]";
  parameter Real g      = 9.81  "gravity [m/s2]";
  parameter Real I_z    = m/12.0*(Lx*Lx + Ly*Ly) "yaw inertia [kg.m2]";
  parameter Real tau_max= 15.9  "per-wheel torque limit [N.m]";
  parameter Real v_cmd  = 1.00  "commanded forward speed [m/s] (<1.5)";
  parameter Real F_push = 174.0 "lateral push disturbance magnitude [N]";

  // Parameters not specified by the requirement (labeled, tuned for scenario):
  parameter Real c_lat      = 800.0 "lateral tire damping [N.s/m]";
  parameter Real K_heading  = 3.0   "heading control gain [1/s]";
  parameter Real K_cross    = 4.0   "cross-track control gain [1/s]";
  parameter Real Kp_w       = 25.0  "wheel-speed proportional gain [N.m.s/rad]";
  parameter Real corridor   = 1.0   "collision corridor half-width [m] (obstacle layout unknown)";
  parameter Real track_tol  = 0.2   "primary tracking tolerance [m]";

  // ===== Waypoints (planar, monotonic in x) =====
  parameter Real wx[4] = {0.0, 4.0, 7.0, 10.0} "waypoint x [m]";
  parameter Real wy[4] = {0.0, 0.0, 2.0,  2.0}  "waypoint y [m]";

  // ===== Dynamic states =====
  Real x      (start=0.0, fixed=true) "world-frame x [m]";
  Real y      (start=0.0, fixed=true) "world-frame y [m]";
  Real theta  (start=0.0, fixed=true) "chassis heading [rad]";
  Real v      (start=0.0, fixed=true) "forward speed [m/s]";
  Real v_lat  (start=0.0, fixed=true) "lateral (body-y) speed [m/s]";
  Real omega  (start=0.0, fixed=true) "yaw rate [rad/s]";

  // ===== Control / actuation =====
  Real v_ref      "reference forward speed [m/s]";
  Real omega_ref "reference yaw rate [rad/s]";
  Real w_r_ref    "right wheel reference angular speed [rad/s]";
  Real w_l_ref    "left wheel reference angular speed [rad/s]";
  Real w_r        "right wheel angular speed (encoder) [rad/s]";
  Real w_l        "left wheel angular speed (encoder) [rad/s]";
  Real tau_r_raw  "raw right wheel torque [N.m]";
  Real tau_l_raw  "raw left wheel torque [N.m]";
  Real tau_r_lim  "torque-limited right wheel torque [N.m]";
  Real tau_l_lim  "torque-limited left wheel torque [N.m]";
  Real tau_r      "final right wheel torque (after friction saturation) [N.m]";
  Real tau_l      "final left wheel torque (after friction saturation) [N.m]";
  Real F_drive    "total drive force [N]";
  Real F_max      "friction-limited drive force [N]";
  Real f_scale    "friction saturation scale factor [1]";

  // ===== Path geometry =====
  Real theta_path "active segment heading [rad]";
  Real e_cross     "signed cross-track error [m]";

  // ===== Disturbance =====
  Real F_push_active "active lateral push force [N]";

  // ===== Sensors sampled at 500 Hz =====
  discrete Real x_sensor      "odometry x [m]";
  discrete Real y_sensor      "odometry y [m]";
  discrete Real theta_sensor  "IMU heading [rad]";
  discrete Real v_sensor      "odometry forward speed [m/s]";
  discrete Real omega_sensor  "IMU yaw rate [rad/s]";
  discrete Real w_r_sensor    "right wheel encoder [rad/s]";
  discrete Real w_l_sensor    "left wheel encoder [rad/s]";
  discrete Real accel_sensor  "IMU forward acceleration [m/s2]";

  // ===== Verification observables =====
  Real tracking_error    "primary cross-track error magnitude [m]";
  Real wheel_speed_bound "max |wheel speed| [rad/s]";
  Real torque_bound      "max |wheel torque| [N.m]";
  Real attitude_error    "heading error magnitude [rad]";
  Real collision_flag    "1 if outside corridor";
  Real nan_flag          "1 if any NaN/Inf detected";
  Real track_ok_after13  "1 if tracking_error < 0.2 m for t >= 13 s";
  Real wheel_speed_ok    "1 if wheel_speed_bound within nominal limit";
  Real torque_ok         "1 if torque_bound within limit";
  Real attitude_ok       "1 if attitude_error within limit";

  Real e_cross_mag;
  Real e_head_mag;
  Real nan_x, nan_y, nan_theta, nan_v, nan_omega, nan_vlat;

equation
  // --- Path segment selection (x is monotonic along the waypoints) ---
  if x < wx[2] then
    theta_path = 0.0;
    e_cross    = y - wy[1];
  elseif x < wx[3] then
    theta_path = atan2(wy[3]-wy[2], wx[3]-wx[2]);
    e_cross    = (-(wx[3]-wx[2])*(x-wx[2]) + (wy[3]-wy[2])*(y-wy[2]))
                 / sqrt((wx[3]-wx[2])^2 + (wy[3]-wy[2])^2);
  else
    theta_path = 0.0;
    e_cross    = y - wy[3];
  end if;

  // --- Reference speed (constant; rover traverses all waypoints within run) ---
  v_ref = v_cmd;

  // --- Bounded path-following controller (Stanley-like) ---
  omega_ref = K_heading*(theta_path - theta) - K_cross*e_cross;
  w_r_ref   = (v_ref + omega_ref*(L_w/2.0))/r_w;
  w_l_ref   = (v_ref - omega_ref*(L_w/2.0))/r_w;

  // --- Wheel-speed observation (encoders / planar odometry) ---
  w_r = (v + omega*(L_w/2.0))/r_w;
  w_l = (v - omega*(L_w/2.0))/r_w;

  // --- Wheel-speed feedback control ---
  tau_r_raw = Kp_w*(w_r_ref - w_r);
  tau_l_raw = Kp_w*(w_l_ref - w_l);

  // --- Actuator torque saturation (<= 15.9 N.m) ---
  tau_r_lim = if tau_r_raw >  tau_max then  tau_max
              else if tau_r_raw < -tau_max then -tau_max
              else tau_r_raw;
  tau_l_lim = if tau_l_raw >  tau_max then  tau_max
              else if tau_l_raw < -tau_max then -tau_max
              else tau_l_raw;

  // --- Friction (traction) saturation on total drive force ---
  F_max   = mu*m*g;
  F_drive = (tau_r_lim + tau_l_lim)/r_w;
  f_scale = if F_drive >  F_max then  F_max/F_drive
            else if F_drive < -F_max then -F_max/F_drive
            else 1.0;
  tau_r = tau_r_lim*f_scale;
  tau_l = tau_l_lim*f_scale;

  // --- Lateral push disturbance: middle third of 20 s run, [6.667, 13.333] s ---
  F_push_active = if (time >= 20.0/3.0) and (time <= 40.0/3.0) then F_push else 0.0;

  // --- Chassis dynamics (planar floating base) ---
  m*der(v)     = (tau_r + tau_l)/r_w;
  I_z*der(omega) = (tau_r - tau_l)*(L_w/2.0)/r_w;
  m*der(v_lat) = F_push_active - c_lat*v_lat;

  // --- Kinematic integration ---
  der(x)     = v*cos(theta) - v_lat*sin(theta);
  der(y)     = v*sin(theta) + v_lat*cos(theta);
  der(theta) = omega;

  // --- Synchronized sensor traces at 500 Hz ---
  when sample(0, 1.0/500.0) then
    x_sensor     = x;
    y_sensor     = y;
    theta_sensor = theta;
    v_sensor     = v;
    omega_sensor = omega;
    w_r_sensor   = w_r;
    w_l_sensor   = w_l;
    accel_sensor = (tau_r + tau_l)/(m*r_w);
  end when;

  // --- Verification observables ---
  e_cross_mag      = abs(e_cross);
  e_head_mag       = abs(theta_path - theta);
  tracking_error   = e_cross_mag;
  wheel_speed_bound= max(abs(w_r), abs(w_l));
  torque_bound     = max(abs(tau_r), abs(tau_l));
  attitude_error   = e_head_mag;
  collision_flag   = if e_cross_mag > corridor then 1.0 else 0.0;

  // NaN/Inf detection (a==a is false for NaN; finite check via large bound)
  nan_x      = if (x == x)      and (x < 1.0e12)      then 0.0 else 1.0;
  nan_y      = if (y == y)      and (y < 1.0e12)      then 0.0 else 1.0;
  nan_theta  = if (theta == theta) and (theta < 1.0e12) then 0.0 else 1.0;
  nan_v      = if (v == v)      and (v < 1.0e12)      then 0.0 else 1.0;
  nan_omega  = if (omega == omega) and (omega < 1.0e12) then 0.0 else 1.0;
  nan_vlat   = if (v_lat == v_lat) and (v_lat < 1.0e12) then 0.0 else 1.0;
  nan_flag   = nan_x + nan_y + nan_theta + nan_v + nan_omega + nan_vlat;

  track_ok_after13 = if (time >= 13.0) and (e_cross_mag < track_tol) then 1.0 else 0.0;
  wheel_speed_ok   = if wheel_speed_bound <= 25.0 then 1.0 else 0.0;
  torque_ok        = if torque_bound    <= tau_max + 1.0e-6 then 1.0 else 0.0;
  attitude_ok      = if attitude_error  <= 0.5 then 1.0 else 0.0;

  annotation (
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002),
    Documentation(info="
  Mission: follow planar waypoints [0,0],[4,0],[7,2],[10,2] m at v_cmd = 1.0 m/s (<1.5).
  Embodiment: 19 kg box 0.65 x 0.44 x 0.22 m, two 0.10 m driven wheels, track 0.46 m,
  one passive caster (supports chassis, no active dynamics modeled).
  Actuation: independent wheel motors, torque bounded at 15.9 N.m; traction bounded by
  mu*m*g = 0.82*19*9.81 N.
  Observation: wheel encoders, planar odometry, chassis IMU sampled at 500 Hz.
  Operating context: rigid floor, friction 0.82; fixed obstacles outside reference path
  (layout not specified -> collision proxied by corridor half-width = 1.0 m).
  Control: bounded Stanley-like path following + proportional wheel-speed control.
  Robustness case: 174 N lateral push active during middle third, t in [6.667,13.333] s.
  Timing: 20 s, 500 Hz synchronized state/command/sensor traces.
  Verification: wheel-speed and actuator bounds, cross-track error, chassis attitude,
  no-collision, primary tracking error < 0.2 m after 13 s, no NaN/Inf.
  Unknown physical quantities not stated in the request (lateral tire damping c_lat,
  controller gains, wheel inertia) are labeled/tuned here rather than fabricated:
  wheel inertia is neglected and encoder speeds are taken as the kinematic relation."));
end DiffRoverRouteF;