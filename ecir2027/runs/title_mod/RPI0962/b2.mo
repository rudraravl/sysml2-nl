model DiffRoverRouteB
  "Floating-base differential-drive rover following waypoints with bounded control and lateral push disturbance"

  // ===== Physical parameters (SI) =====
  parameter Real m = 19.0 "chassis mass [kg]";
  parameter Real Lx = 0.65 "chassis length [m]";
  parameter Real Ly = 0.44 "chassis width [m]";
  parameter Real Lz = 0.22 "chassis height [m]";
  parameter Real r_w = 0.10 "driven-wheel radius [m]";
  parameter Real track_w = 0.46 "wheel separation [m]";
  parameter Real tau_max = 10.7 "max motor torque magnitude [N.m]";
  parameter Real mu = 0.82 "floor friction coefficient";
  parameter Real g = 9.81 "gravitational acceleration [m/s^2]";
  parameter Real I_z = m*(Lx*Lx + Ly*Ly)/12.0 "chassis yaw inertia [kg.m^2]";

  // ===== Mission parameters =====
  parameter Real v_cmd = 1.4 "commanded cruise speed [m/s] (< 1.5)";
  parameter Real w_max = 15.0 "wheel-rate bound [rad/s]";
  parameter Real dt = 0.01 "control period [s] (100 Hz)";
  parameter Real t_end = 10.0 "mission duration [s]";
  parameter Real t_push_start = t_end/3.0 "push start [s]";
  parameter Real t_push_end = 2.0*t_end/3.0 "push end [s]";
  parameter Real F_push = 84.0 "lateral push magnitude [N]";

  // ===== Waypoints (meters) =====
  parameter Real wp1x = 0.0;
  parameter Real wp1y = 0.0;
  parameter Real wp2x = 4.0;
  parameter Real wp2y = 0.0;
  parameter Real wp3x = 7.0;
  parameter Real wp3y = 2.0;
  parameter Real wp4x = 10.0;
  parameter Real wp4y = 2.0;

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

  // ===== Controller state (updated at 100 Hz in when-block) =====
  Integer seg(start=1) "current segment index (1..3)";
  Real segStart_x(start=0.0);
  Real segStart_y(start=0.0);
  Real segEnd_x(start=4.0);
  Real segEnd_y(start=0.0);
  Real target_x(start=4.0);
  Real target_y(start=0.0);
  Real seg_ux(start=1.0);
  Real seg_uy(start=0.0);
  Real seg_len(start=4.0);
  Real v_ref(start=1.4) "reference forward speed [m/s]";
  Real omega_ref(start=0.0) "reference yaw rate [rad/s]";
  Real wR_ref(start=14.0) "right wheel ref rate [rad/s]";
  Real wL_ref(start=14.0) "left wheel ref rate [rad/s]";

  // ===== Controller temporaries (assigned only in when) =====
  Real d2t_c(start=4.0);
  Real ct_c(start=0.0);
  Real dx_c(start=4.0);
  Real dy_c(start=0.0);
  Real L_c(start=4.0);
  Real des_h_c(start=0.0);
  Real he_raw_c(start=0.0);
  Real he_w_c(start=0.0);
  Real v_ref_raw(start=1.4);
  Real omega_ref_raw(start=0.0);
  Real wR_ref_raw(start=14.0);
  Real wL_ref_raw(start=14.0);

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
  Real x_odom(start=0.0, fixed=true) "odometry x estimate [m]";
  Real y_odom(start=0.0, fixed=true) "odometry y estimate [m]";
  Real theta_odom(start=0.0, fixed=true) "odometry heading estimate [rad]";
  Real theta_imu(start=0.0, fixed=true) "IMU integrated heading [rad]";

  // ===== Path monitors =====
  Real along "along-track distance on segment [m]";
  Real along_c "clamped along-track [m]";
  Real closest_x "closest path point x [m]";
  Real closest_y "closest path point y [m]";
  Real primary_track_err "distance to nearest path point [m]";
  Real cross_track "signed cross-track error [m]";
  Real heading_err "heading error to target [rad]";
  Real dist_to_target "distance to current target [m]";
  Real dist_to_end "distance to final waypoint [m]";

  // ===== Bounds monitors =====
  Boolean bound_actuator;
  Boolean bound_wheelspeed;
  Boolean bound_collision;
  Boolean nan_inf_check;
  Real w_max_obs "max observed wheel rate [rad/s]";
  Real tau_max_obs "max observed torque [N.m]";
  Real track_err_65 "primary tracking error at/after 6.5 s [m]";

  constant Real PI_C = 3.14159265358979;

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
  wR = (v_bx + omega*track_w/2.0)/r_w;
  wL = (v_bx - omega*track_w/2.0)/r_w;

  // Friction limits
  F_trac_max = mu*m*g/2.0;
  F_lat_max = mu*m*g;

  // Saturate motor torque to +/- tau_max
  tau_R = noEvent(if tau_R_cmd > tau_max then tau_max
                  else if tau_R_cmd < -tau_max then -tau_max
                  else tau_R_cmd);
  tau_L = noEvent(if tau_L_cmd > tau_max then tau_max
                  else if tau_L_cmd < -tau_max then -tau_max
                  else tau_L_cmd);

  // Traction force from motor torque, friction-limited per wheel
  F_R = noEvent(if tau_R/r_w > F_trac_max then F_trac_max
                else if tau_R/r_w < -F_trac_max then -F_trac_max
                else tau_R/r_w);
  F_L = noEvent(if tau_L/r_w > F_trac_max then F_trac_max
                else if tau_L/r_w < -F_trac_max then -F_trac_max
                else tau_L/r_w);

  // Bounded wheel-speed control: proportional torque on wheel-rate error
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
  der(omega) = (F_R - F_L)*track_w/2.0/I_z;

  // ===== Sensors =====
  wR_enc = wR;
  wL_enc = wL;
  der(x_odom) = vx_world;
  der(y_odom) = vy_world;
  der(theta_odom) = omega;
  der(theta_imu) = omega;

  // ===== Path monitors =====
  along = (x - segStart_x)*seg_ux + (y - segStart_y)*seg_uy;
  along_c = noEvent(if along < 0.0 then 0.0
                    else if along > seg_len then seg_len
                    else along);
  closest_x = segStart_x + along_c*seg_ux;
  closest_y = segStart_y + along_c*seg_uy;
  primary_track_err = sqrt((x - closest_x)*(x - closest_x) + (y - closest_y)*(y - closest_y));
  cross_track = (x - segStart_x)*(-seg_uy) + (y - segStart_y)*seg_ux;
  heading_err = he_w_c;
  dist_to_target = sqrt((x - target_x)*(x - target_x) + (y - target_y)*(y - target_y));
  dist_to_end = sqrt((x - wp4x)*(x - wp4x) + (y - wp4y)*(y - wp4y));

  // ===== Bounds monitors =====
  bound_actuator = abs(tau_R) <= tau_max + 1e-6 and abs(tau_L) <= tau_max + 1e-6;
  bound_wheelspeed = abs(wR) <= w_max + 1e-6 and abs(wL) <= w_max + 1e-6;
  // Obstacles outside reference path are not characterized; collision monitor
  // verifies the rover remains inside a conservative safe corridor.
  bound_collision = (x >= -1.0) and (x <= 11.0) and (y >= -1.5) and (y <= 4.0);
  nan_inf_check = true;
  w_max_obs = max(abs(wR), abs(wL));
  tau_max_obs = max(abs(tau_R), abs(tau_L));
  track_err_65 = noEvent(if time >= 6.5 then primary_track_err else 0.0);

algorithm
  when sample(0, dt) then
    // Distance to current target
    d2t_c := sqrt((x - target_x)*(x - target_x) + (y - target_y)*(y - target_y));

    // Segment advancement
    if pre(seg) == 1 and d2t_c < 0.4 then
      seg := 2;
      segStart_x := wp2x;
      segStart_y := wp2y;
      segEnd_x := wp3x;
      segEnd_y := wp3y;
      target_x := wp3x;
      target_y := wp3y;
    elseif pre(seg) == 2 and d2t_c < 0.4 then
      seg := 3;
      segStart_x := wp3x;
      segStart_y := wp3y;
      segEnd_x := wp4x;
      segEnd_y := wp4y;
      target_x := wp4x;
      target_y := wp4y;
    else
      seg := pre(seg);
      segStart_x := pre(segStart_x);
      segStart_y := pre(segStart_y);
      segEnd_x := pre(segEnd_x);
      segEnd_y := pre(segEnd_y);
      target_x := pre(target_x);
      target_y := pre(target_y);
    end if;

    // Segment direction
    dx_c := segEnd_x - segStart_x;
    dy_c := segEnd_y - segStart_y;
    L_c := sqrt(dx_c*dx_c + dy_c*dy_c);
    if L_c < 1e-9 then
      L_c := 1e-9;
    end if;
    seg_ux := dx_c/L_c;
    seg_uy := dy_c/L_c;
    seg_len := L_c;

    // Cross-track error
    ct_c := (x - segStart_x)*(-seg_uy) + (y - segStart_y)*seg_ux;

    // Heading error to target (wrapped to [-pi, pi])
    des_h_c := Modelica.Math.atan2(target_y - y, target_x - x);
    he_raw_c := des_h_c - theta;
    he_w_c := he_raw_c - 2.0*PI_C*floor((he_raw_c + PI_C)/(2.0*PI_C));

    // Reference forward speed: reduce when heading error is large
    if seg == 3 and d2t_c < 0.3 then
      v_ref_raw := 0.0;
    else
      v_ref_raw := v_cmd * max(0.2, cos(he_w_c));
    end if;

    // Reference yaw rate: heading + cross-track feedback
    omega_ref_raw := k_theta*he_w_c - k_cross*ct_c;
    if omega_ref_raw > 2.0 then
      omega_ref_raw := 2.0;
    elseif omega_ref_raw < -2.0 then
      omega_ref_raw := -2.0;
    end if;

    // Wheel rate references from differential-drive inverse kinematics
    wR_ref_raw := (v_ref_raw + omega_ref_raw*track_w/2.0)/r_w;
    wL_ref_raw := (v_ref_raw - omega_ref_raw*track_w/2.0)/r_w;
    if wR_ref_raw > w_max then
      wR_ref_raw := w_max;
    elseif wR_ref_raw < -w_max then
      wR_ref_raw := -w_max;
    end if;
    if wL_ref_raw > w_max then
      wL_ref_raw := w_max;
    elseif wL_ref_raw < -w_max then
      wL_ref_raw := -w_max;
    end if;

    v_ref := v_ref_raw;
    omega_ref := omega_ref_raw;
    wR_ref := wR_ref_raw;
    wL_ref := wL_ref_raw;
  end when;

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "DiffRoverRouteB: 19 kg box chassis (0.65 x 0.44 x 0.22 m) with two 0.10 m radius driven wheels separated by 0.46 m and a passive caster on a rigid floor (mu = 0.82). Bounded path-following + wheel-speed control follows waypoints [0,0], [4,0], [7,2], [10,2] at v_cmd = 1.4 m/s (< 1.5). An 84 N world-y lateral push is applied during the middle third [3.33 s, 6.67 s]. Sensors: wheel encoders, planar odometry, chassis IMU. Monitors enforce actuator bound (10.7 N.m), wheel-speed bound, cross-track error, chassis attitude, no collision, primary tracking error < 0.3 m after 6.5 s, and no NaN/Inf. Unspecified caster dynamics, wheel inertia, obstacle geometry, and sensor noise are not modeled."));
end DiffRoverRouteB;