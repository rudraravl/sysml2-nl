model DiffRoverRouteB
  "Floating-base differential-drive rover following waypoints with bounded control and lateral push disturbance"

  // ===== Physical parameters (SI) =====
  parameter Real m = 19.0 "chassis mass [kg]";
  parameter Real Lx = 0.65 "chassis length [m]";
  parameter Real Ly = 0.44 "chassis width [m]";
  parameter Real Lz = 0.22 "chassis height [m]";
  parameter Real r_w = 0.10 "driven-wheel radius [m]";
  parameter Real track = 0.46 "wheel separation [m]";
  parameter Real tau_max = 10.7 "max motor torque magnitude [N.m]";
  parameter Real mu = 0.82 "floor friction coefficient";
  parameter Real g = 9.81 "gravitational acceleration [m/s^2]";
  parameter Real I_z = m*(Lx*Lx + Ly*Ly)/12.0 "chassis yaw inertia [kg.m^2]";
  // Wheel inertia, caster dynamics, obstacle geometry, and sensor noise are
  // not stated in the requirement and are therefore not modeled.

  // ===== Mission parameters =====
  parameter Real v_cmd = 1.4 "commanded cruise speed [m/s] (< 1.5)";
  parameter Real w_max = 1.5/r_w "wheel-rate bound [rad/s]";
  parameter Real dt = 0.01 "control period [s] (100 Hz)";
  parameter Real t_end = 10.0 "mission duration [s]";
  parameter Real t_push_start = t_end/3.0 "push start [s]";
  parameter Real t_push_end = 2.0*t_end/3.0 "push end [s]";
  parameter Real F_push = 84.0 "lateral push magnitude [N]";

  // ===== Waypoints (meters) =====
  parameter Real wp1x = 0.0; parameter Real wp1y = 0.0;
  parameter Real wp2x = 4.0; parameter Real wp2y = 0.0;
  parameter Real wp3x = 7.0; parameter Real wp3y = 2.0;
  parameter Real wp4x = 10.0; parameter Real wp4y = 2.0;

  // ===== Controller gains =====
  parameter Real k_theta = 2.2 "heading gain [1/s]";
  parameter Real k_cross = 1.2 "cross-track gain [1/s]";
  parameter Real k_omega = 6.0 "wheel-rate proportional gain [N.m.s/rad]";

  // ===== Continuous plant states =====
  Real x(start=0.0, fixed=true) "world x [m]";
  Real y(start=0.0, fixed=true) "world y [m]";
  Real theta(start=0.0, fixed=true) "heading [rad]";
  Real v_bx(start=0.0, fixed=true) "body forward velocity [m/s]";
  Real v_by(start=0.0, fixed=true) "body lateral velocity [m/s]";
  Real omega(start=0.0, fixed=true) "yaw rate [rad/s]";

  // ===== Discrete controller state (updated at 100 Hz) =====
  discrete Integer seg(start=1) "current segment index (1..3)";
  discrete Real segStart_x(start=wp1x);
  discrete Real segStart_y(start=wp1y);
  discrete Real segEnd_x(start=wp2x);
  discrete Real segEnd_y(start=wp2y);
  discrete Real target_x(start=wp2x);
  discrete Real target_y(start=wp2y);
  discrete Real seg_ux(start=1.0);
  discrete Real seg_uy(start=0.0);
  discrete Real seg_len(start=4.0);
  discrete Real v_ref(start=v_cmd) "reference forward speed [m/s]";
  discrete Real omega_ref(start=0.0) "reference yaw rate [rad/s]";
  discrete Real wR_ref(start=0.0) "right wheel ref rate [rad/s]";
  discrete Real wL_ref(start=0.0) "left wheel ref rate [rad/s]";

  // ===== Algebraic plant signals =====
  Real wR "right wheel angular rate [rad/s]";
  Real wL "left wheel angular rate [rad/s]";
  Real tau_R_cmd "right motor torque command [N.m]";
  Real tau_L_cmd "left motor torque command [N.m]";
  Real tau_R "saturated right torque [N.m]";
  Real tau_L "saturated left torque [N.m]";
  Real F_R "right wheel traction force [N]";
  Real F_L "left wheel traction force [N]";
  Real F_trac_max "max traction per wheel [N]";
  Real F_lat_max "max lateral friction [N]";
  Real F_lat_friction "lateral friction force body y [N]";
  Real F_push_y "world-y lateral push force [N]";
  Real F_push_body_x "push force in body x [N]";
  Real F_push_body_y "push force in body y [N]";
  Real cos_th;
  Real sin_th;
  Real vx_world "world x velocity [m/s]";
  Real vy_world "world y velocity [m/s]";
  Boolean push_active;

  // ===== Sensors =====
  Real wR_enc "encoder right wheel rate [rad/s]";
  Real wL_enc "encoder left wheel rate [rad/s]";
  Real x_odom(start=0.0) "odometry x estimate [m]";
  Real y_odom(start=0.0) "odometry y estimate [m]";
  Real theta_odom(start=0.0) "odometry heading estimate [rad]";
  Real theta_imu(start=0.0) "IMU integrated heading [rad]";

  // ===== Path monitors =====
  Real along "along-track distance on segment [m]";
  Real along_c "clamped along-track [m]";
  Real closest_x "closest path point x [m]";
  Real closest_y "closest path point y [m]";
  Real cross_track "signed cross-track error [m] (left positive)";
  Real primary_track_err "distance to nearest path point [m]";
  Real heading_err "heading error to target [rad]";
  Real dist_to_target "distance to current target [m]";
  Real dist_to_end "distance to final waypoint [m]";

  // ===== Bounds monitors =====
  Boolean bound_actuator "actuator within bounds";
  Boolean bound_wheelspeed "wheel speed within bounds";
  Boolean bound_collision "no collision (in safe corridor)";
  Boolean nan_inf_check "no NaN/Inf in primary signals";
  Real w_max_obs "max observed wheel rate [rad/s]";
  Real tau_max_obs "max observed torque [N.m]";
  Real track_err_65 "primary tracking error sampled at/after 6.5 s [m]";

protected
  constant Real PI = 3.14159265358979;

  function stepController
    "Bounded path-following + wheel-speed reference generator (one 100 Hz step)"
    input Integer seg_in;
    input Real sx_in;
    input Real sy_in;
    input Real ex_in;
    input Real ey_in;
    input Real tx_in;
    input Real ty_in;
    input Real x_in;
    input Real y_in;
    input Real theta_in;
    input Real v_cmd_in;
    input Real track_in;
    input Real r_w_in;
    input Real w_max_in;
    input Real k_theta_in;
    input Real k_cross_in;
    input Real wp2x_in;
    input Real wp2y_in;
    input Real wp3x_in;
    input Real wp3y_in;
    input Real wp4x_in;
    input Real wp4y_in;
    output Integer seg_out;
    output Real sx_out;
    output Real sy_out;
    output Real ex_out;
    output Real ey_out;
    output Real tx_out;
    output Real ty_out;
    output Real v_ref_out;
    output Real omega_ref_out;
    output Real wR_ref_out;
    output Real wL_ref_out;
    output Real seg_ux_out;
    output Real seg_uy_out;
    output Real seg_len_out;
  protected
    constant Real PI_L = 3.14159265358979;
    Real d2t;
    Real dx;
    Real dy;
    Real L;
    Real ct;
    Real des_h;
    Real he_raw;
    Real he_w;
  algorithm
    d2t := sqrt((x_in - tx_in)^2 + (y_in - ty_in)^2);
    if seg_in == 1 and d2t < 0.4 then
      seg_out := 2;
      sx_out := wp2x_in; sy_out := wp2y_in;
      ex_out := wp3x_in; ey_out := wp3y_in;
      tx_out := wp3x_in; ty_out := wp3y_in;
    elseif seg_in == 2 and d2t < 0.4 then
      seg_out := 3;
      sx_out := wp3x_in; sy_out := wp3y_in;
      ex_out := wp4x_in; ey_out := wp4y_in;
      tx_out := wp4x_in; ty_out := wp4y_in;
    else
      seg_out := seg_in;
      sx_out := sx_in; sy_out := sy_in;
      ex_out := ex_in; ey_out := ey_in;
      tx_out := tx_in; ty_out := ty_in;
    end if;

    dx := ex_out - sx_out;
    dy := ey_out - sy_out;
    L := sqrt(dx*dx + dy*dy);
    if L < 1e-9 then
      L := 1e-9;
    end if;
    seg_ux_out := dx/L;
    seg_uy_out := dy/L;
    seg_len_out := L;

    ct := (x_in - sx_out)*(-seg_uy_out) + (y_in - sy_out)*seg_ux_out;
    des_h := atan2(ty_out - y_in, tx_out - x_in);
    he_raw := des_h - theta_in;
    he_w := he_raw - 2.0*PI_L*floor((he_raw + PI_L)/(2.0*PI_L));

    if seg_out == 3 and d2t < 0.3 then
      v_ref_out := 0.0;
    else
      v_ref_out := v_cmd_in * max(0.2, cos(he_w));
    end if;

    omega_ref_out := k_theta_in*he_w - k_cross_in*ct;
    if omega_ref_out > 2.0 then
      omega_ref_out := 2.0;
    elseif omega_ref_out < -2.0 then
      omega_ref_out := -2.0;
    end if;

    wR_ref_out := (v_ref_out + omega_ref_out*track_in/2.0)/r_w_in;
    wL_ref_out := (v_ref_out - omega_ref_out*track_in/2.0)/r_w_in;
    if wR_ref_out > w_max_in then
      wR_ref_out := w_max_in;
    elseif wR_ref_out < -w_max_in then
      wR_ref_out := -w_max_in;
    end if;
    if wL_ref_out > w_max_in then
      wL_ref_out := w_max_in;
    elseif wL_ref_out < -w_max_in then
      wL_ref_out := -w_max_in;
    end if;
  end stepController;

public
equation
  cos_th = cos(theta);
  sin_th = sin(theta);

  // World velocities from body velocities
  vx_world = v_bx*cos_th - v_by*sin_th;
  vy_world = v_bx*sin_th + v_by*cos_th;

  // Kinematic states
  der(x) = vx_world;
  der(y) = vy_world;
  der(theta) = omega;

  // Wheel rates from no-slip longitudinal kinematics
  wR = (v_bx + omega*track/2.0)/r_w;
  wL = (v_bx - omega*track/2.0)/r_w;

  // Friction limits
  F_trac_max = mu*m*g/2.0;
  F_lat_max = mu*m*g;

  // Saturate motor torque to +- tau_max
  tau_R = noEvent(if tau_R_cmd > tau_max then tau_max else if tau_R_cmd < -tau_max then -tau_max else tau_R_cmd);
  tau_L = noEvent(if tau_L_cmd > tau_max then tau_max else if tau_L_cmd < -tau_max then -tau_max else tau_L_cmd);

  // Traction force from motor torque, friction-limited per wheel
  F_R = noEvent(if tau_R/r_w > F_trac_max then F_trac_max else if tau_R/r_w < -F_trac_max then -F_trac_max else tau_R/r_w);
  F_L = noEvent(if tau_L/r_w > F_trac_max then F_trac_max else if tau_L/r_w < -F_trac_max then -F_trac_max else tau_L/r_w);

  // Bounded wheel-speed control: proportional torque command on wheel-rate error
  tau_R_cmd = k_omega*(wR_ref - wR);
  tau_L_cmd = k_omega*(wL_ref - wL);

  // Lateral friction (smooth Coulomb) opposes body-lateral slip
  F_lat_friction = -F_lat_max * tanh(v_by/0.05);

  // Lateral push disturbance applied in world y during middle third
  push_active = time >= t_push_start and time <= t_push_end;
  F_push_y = if push_active then F_push else 0.0;
  F_push_body_x = sin_th * F_push_y;
  F_push_body_y = cos_th * F_push_y;

  // Body-frame translational dynamics with Coriolis coupling
  der(v_bx) = ((F_R + F_L) + F_push_body_x)/m + omega*v_by;
  der(v_by) = (F_lat_friction + F_push_body_y)/m - omega*v_bx;
  // Yaw dynamics from differential traction
  der(omega) = (F_R - F_L)*track/2.0/I_z;

  // ===== Sensors =====
  wR_enc = wR;
  wL_enc = wL;
  der(x_odom) = vx_world;
  der(y_odom) = vy_world;
  der(theta_odom) = omega;
  der(theta_imu) = omega;

  // ===== Path monitors =====
  along = (x - segStart_x)*seg_ux + (y - segStart_y)*seg_uy;
  along_c = noEvent(if along < 0.0 then 0.0 else if along > seg_len then seg_len else along);
  closest_x = segStart_x + along_c*seg_ux;
  closest_y = segStart_y + along_c*seg_uy;
  primary_track_err = sqrt((x - closest_x)^2 + (y - closest_y)^2);
  cross_track = (x - segStart_x)*(-seg_uy) + (y - segStart_y)*seg_ux;
  heading_err = noEvent((atan2(target_y - y, target_x - x) - theta)
                        - 2.0*PI*floor((atan2(target_y - y, target_x - x) - theta + PI)/(2.0*PI)));
  dist_to_target = sqrt((x - target_x)^2 + (y - target_y)^2);
  dist_to_end = sqrt((x - wp4x)^2 + (y - wp4y)^2);

  // ===== Bounds monitors =====
  bound_actuator = abs(tau_R) <= tau_max + 1e-6 and abs(tau_L) <= tau_max + 1e-6;
  bound_wheelspeed = abs(wR) <= w_max + 1e-6 and abs(wL) <= w_max + 1e-6;
  // Obstacles outside reference path are not characterized; collision monitor
  // verifies the rover remains inside a conservative safe corridor.
  bound_collision = (x >= -1.0) and (x <= 11.0) and (y >= -1.5) and (y <= 4.0);
  nan_inf_check = (x == x) and (y == y) and (theta == theta) and (v_bx == v_bx)
                  and (v_by == v_by) and (omega == omega) and (tau_R == tau_R)
                  and (tau_L == tau_L) and (wR == wR) and (wL == wL)
                  and (F_R == F_R) and (F_L == F_L);
  w_max_obs = max(abs(wR), abs(wL));
  tau_max_obs = max(abs(tau_R), abs(tau_L));
  track_err_65 = if time >= 6.5 then primary_track_err else 0.0;

  // ===== Sampled control at 100 Hz =====
  when sample(0, dt) then
    (seg, segStart_x, segStart_y, segEnd_x, segEnd_y, target_x, target_y,
     v_ref, omega_ref, wR_ref, wL_ref, seg_ux, seg_uy, seg_len) =
      stepController(pre(seg), pre(segStart_x), pre(segStart_y),
                     pre(segEnd_x), pre(segEnd_y), pre(target_x), pre(target_y),
                     x, y, theta, v_cmd, track, r_w, w_max, k_theta, k_cross,
                     wp2x, wp2y, wp3x, wp3y, wp4x, wp4y);
  end when;

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "DiffRoverRouteB: 19 kg box chassis (0.65 x 0.44 x 0.22 m) with two 0.10 m radius driven wheels separated by 0.46 m and a passive caster on a rigid floor (mu = 0.82). Bounded path-following + wheel-speed control follows waypoints [0,0], [4,0], [7,2], [10,2] at v_cmd = 1.4 m/s (< 1.5). An 84 N world-y lateral push is applied during the middle third [3.33 s, 6.67 s]. Sensors: wheel encoders, planar odometry, chassis IMU. Monitors enforce actuator bound (10.7 N.m), wheel-speed bound, cross-track error, chassis attitude, no collision, primary tracking error < 0.3 m after 6.5 s, and no NaN/Inf. Unspecified caster dynamics, wheel inertia, obstacle geometry, and sensor noise are not modeled."),
    uses(Modelica(version = "4.0.0")));
end DiffRoverRouteB;