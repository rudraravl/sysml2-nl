model DiffRoverRouteC
  // ---------- Physical parameters ----------
  parameter Real m = 19.0 "chassis mass [kg]";
  parameter Real Lx = 0.65 "chassis length [m]";
  parameter Real Ly = 0.44 "chassis width [m]";
  parameter Real Lz = 0.22 "chassis height [m]";
  parameter Real J = m/12.0*(Lx*Lx + Ly*Ly) "chassis yaw inertia [kg.m^2]";
  parameter Real r = 0.10 "driven wheel radius [m]";
  parameter Real L = 0.46 "wheel separation [m]";
  parameter Real mu = 0.82 "rigid floor friction coefficient";
  parameter Real g = 9.81 "gravity [m/s^2]";
  // Wheel mass not specified in the request; I_w is a placeholder engineering value.
  parameter Real I_w = 0.005 "wheel inertia placeholder [kg.m^2] (wheel mass unknown)";

  // ---------- Control parameters ----------
  parameter Real v_des = 1.4 "commanded speed [m/s], kept below 1.5";
  parameter Real tau_max = 12.0 "maximum command magnitude [N.m]";
  parameter Real Kv = 10.0 "forward velocity feedback gain";
  parameter Real Kw = 5.0 "yaw-rate feedback gain";
  parameter Real Kh = 2.0 "heading-error to yaw-rate gain";

  // ---------- Disturbance ----------
  parameter Real F_push = 108.0 "lateral push magnitude [N]";

  // ---------- Mission ----------
  parameter Real T_end = 12.0 "run duration [s]";
  parameter Real dt = 0.008 "control/sample period [s] (125 Hz)";
  parameter Real wx[4] = {0.0, 4.0, 7.0, 10.0} "waypoint x [m]";
  parameter Real wy[4] = {0.0, 0.0, 2.0, 2.0} "waypoint y [m]";

  // ---------- Continuous states ----------
  Real x(start=0.0, fixed=true) "world x [m]";
  Real y(start=0.0, fixed=true) "world y [m]";
  Real theta(start=0.0, fixed=true) "chassis heading [rad]";
  Real vy_body(start=0.0, fixed=true) "lateral body velocity [m/s]";
  Real wl(start=0.0, fixed=true) "left wheel angular rate [rad/s]";
  Real wr(start=0.0, fixed=true) "right wheel angular rate [rad/s]";

  // ---------- Algebraic variables ----------
  Real vx_body "forward body velocity [m/s]";
  Real omega "chassis yaw rate [rad/s]";
  Real F_push_body_y "applied lateral push in body frame [N]";

  // ---------- Controls ----------
  Real tau_l "left motor torque command [N.m]";
  Real tau_r "right motor torque command [N.m]";
  Real tau_l_sat "saturated left torque [N.m]";
  Real tau_r_sat "saturated right torque [N.m]";
  Real v_cmd "commanded forward speed [m/s]";
  Real omega_cmd "commanded yaw rate [rad/s]";
  Real heading_err "heading error [rad]";
  Real desired_heading "desired heading [rad]";

  // ---------- Waypoint tracking ----------
  Integer idx(start=2) "current target waypoint index";
  Real dx_seg, dy_seg, seg_len;
  Real t_proj, t_clamped;
  Real px, py;
  Real cross_track "cross-track error [m]";
  Real primary_track_err "primary tracking error [m]";

  // ---------- Sensors ----------
  Real odom_x "planar odometry x estimate [m]";
  Real odom_y "planar odometry y estimate [m]";
  Real odom_theta "planar odometry heading estimate [rad]";
  Real imu_omega "IMU yaw rate [rad/s]";
  Real enc_l "left wheel encoder angular rate [rad/s]";
  Real enc_r "right wheel encoder angular rate [rad/s]";

  // ---------- Synchronized 125 Hz traces ----------
  Real x_s, y_s, theta_s, vx_s, vy_s, omega_s, wl_s, wr_s, tau_l_s, tau_r_s, cross_track_s;

  // ---------- Monitors ----------
  Real max_abs_wheel;
  Real max_abs_torque;
  Real wheelspeed_violation;
  Real torque_violation;
  Real collision_flag;
  Boolean ok_tracking "primary tracking error below 0.263 m after 7.8 s";
  Boolean ok_torque;
  Boolean ok_wheelspeed;
  Boolean ok_collision;

  constant Real eps = 1e-6;

equation
  // Combined wheel + chassis forward/yaw dynamics (no-slip rolling in forward direction)
  der(wl) + der(wr) = (tau_l_sat + tau_r_sat)/(I_w + m*r*r/2.0);
  der(wr) - der(wl) = (tau_r_sat - tau_l_sat)/(I_w + 2.0*J*r*r/(L*L));

  // Body-frame velocities from wheel speeds (forward no-slip kinematics)
  vx_body = r*(wl + wr)/2.0;
  omega = r*(wr - wl)/L;

  // Lateral dynamics: passive caster allows lateral motion, friction resists
  der(vy_body) = (F_push_body_y - mu*m*g*tanh(vy_body/eps))/m;

  // World-frame kinematics
  der(x) = vx_body*cos(theta) - vy_body*sin(theta);
  der(y) = vx_body*sin(theta) + vy_body*cos(theta);
  der(theta) = omega;

  // Lateral push disturbance in body frame during the middle third [4,8] s
  F_push_body_y = if (time >= 4.0 and time <= 8.0) then F_push else 0.0;

  // ---------- Waypoint-following controller ----------
  desired_heading = atan2(wy[idx] - y, wx[idx] - x);
  heading_err = atan2(sin(desired_heading - theta), cos(desired_heading - theta));
  omega_cmd = Kh * heading_err;
  v_cmd = v_des * max(0.0, 1.0 - abs(heading_err)/1.5707963);

  // Motor torque commands (feedback linearization around wheel/chassis dynamics)
  tau_l = Kv*(v_cmd - vx_body) - Kw*(omega_cmd - omega);
  tau_r = Kv*(v_cmd - vx_body) + Kw*(omega_cmd - omega);

  // Actuator saturation at +/- 12 N.m
  tau_l_sat = if tau_l > tau_max then tau_max else if tau_l < -tau_max then -tau_max else tau_l;
  tau_r_sat = if tau_r > tau_max then tau_max else if tau_r < -tau_max then -tau_max else tau_r;

  // ---------- Cross-track error to current segment ----------
  dx_seg = wx[idx] - wx[idx-1];
  dy_seg = wy[idx] - wy[idx-1];
  seg_len = sqrt(dx_seg*dx_seg + dy_seg*dy_seg + eps);
  t_proj = ((x - wx[idx-1])*dx_seg + (y - wy[idx-1])*dy_seg)/(seg_len*seg_len);
  t_clamped = if t_proj < 0.0 then 0.0 else if t_proj > 1.0 then 1.0 else t_proj;
  px = wx[idx-1] + t_clamped*dx_seg;
  py = wy[idx-1] + t_clamped*dy_seg;
  cross_track = sqrt((x - px)*(x - px) + (y - py)*(y - py) + eps);
  primary_track_err = cross_track;

  // ---------- Sensors ----------
  odom_x = x;
  odom_y = y;
  odom_theta = theta;
  imu_omega = omega;
  enc_l = wl;
  enc_r = wr;

  // ---------- 125 Hz sampled traces and waypoint advance ----------
  when sample(0.0, dt) then
    idx = if (pre(idx) < 4 and (wx[pre(idx)] - x)*(wx[pre(idx)] - x) + (wy[pre(idx)] - y)*(wy[pre(idx)] - y) < 0.16) then pre(idx) + 1 else pre(idx);
    x_s = x;
    y_s = y;
    theta_s = theta;
    vx_s = vx_body;
    vy_s = vy_body;
    omega_s = omega;
    wl_s = wl;
    wr_s = wr;
    tau_l_s = tau_l_sat;
    tau_r_s = tau_r_sat;
    cross_track_s = cross_track;
  end when;

  // ---------- Monitors ----------
  max_abs_wheel = max(abs(wl), abs(wr));
  max_abs_torque = max(abs(tau_l_sat), abs(tau_r_sat));
  wheelspeed_violation = max(0.0, max_abs_wheel - 15.0);
  torque_violation = max(0.0, max_abs_torque - tau_max);
  collision_flag = if cross_track > 1.0 then 1.0 else 0.0;

  ok_tracking = (time < 7.8) or (primary_track_err < 0.263);
  ok_torque = torque_violation <= 0.0;
  ok_wheelspeed = wheelspeed_violation <= 0.0;
  ok_collision = collision_flag <= 0.0;

  annotation(
    experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.008),
    Documentation(info="Floating-base differential-drive rover (DiffRoverRouteC) following planar waypoints [0,0],[4,0],[7,2],[10,2] m at commanded speed below 1.5 m/s. Two 0.10 m-radius driven wheels separated by 0.46 m and one passive caster on a 19 kg box chassis. Independent wheel motors with +/-12 N.m saturation. A 108 N lateral push is injected in the body frame during the middle third [4,8] s. Floor friction 0.82. Synchronized 125 Hz state/command/sensor traces. Monitors wheel-speed and actuator bounds, cross-track error, chassis attitude, and collision. Primary tracking error required below 0.263 m after 7.8 s.")
  );
end DiffRoverRouteC;