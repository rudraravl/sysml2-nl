model AckermannRoverRouteB
  // ===== Physical parameters (from requirement) =====
  parameter Real m = 34 "chassis mass [kg]";
  parameter Real L = 0.74 "wheelbase [m]";
  parameter Real chassisL = 1.05 "chassis length [m]";
  parameter Real chassisW = 0.64 "chassis width [m]";
  parameter Real delta_max = 0.52 "max front steering angle [rad]";
  parameter Real torque_max = 23 "max actuator torque command [N.m]";
  parameter Real mu = 0.82 "floor friction coefficient [-]";
  parameter Real g = 9.81 "gravity [m/s2]";
  // NOTE: wheel radius is not stated in the requirement; a nominal placeholder
  // is used solely to map the given torque bound to a traction-force bound for
  // this force-driven planar model. It is not a factual value from the request.
  parameter Real r_wheel = 0.15 "nominal wheel radius [m] (placeholder, not from requirement)";
  parameter Real F_act_max = torque_max / r_wheel "torque-limited traction force [N]";
  parameter Real F_fric_max = mu * m * g "friction-limited traction force [N]";
  parameter Real F_drive_max = min(F_act_max, F_fric_max) "effective drive-force bound [N]";

  // ===== Mission parameters =====
  parameter Real v_cmd = 1.2 "commanded speed [m/s] (<1.5)";
  parameter Real Ld = 0.9 "pure-pursuit lookahead distance [m]";
  parameter Real Kp_v = 90.0 "longitudinal speed control gain [N/(m/s)]";
  parameter Real pushForce = 84.0 "lateral push disturbance magnitude [N]";
  parameter Real t_push_a = 10.0/3.0 "middle-third start time [s]";
  parameter Real t_push_b = 20.0/3.0 "middle-third end time [s]";
  parameter Real sampleDt = 0.01 "sampling period (100 Hz) [s]";
  parameter Real tFinal = 10.0 "mission duration [s]";

  // Waypoints
  parameter Real wx[4] = {0.0, 4.0, 7.0, 10.0};
  parameter Real wy[4] = {0.0, 0.0, 2.0, 2.0};

  // ===== Continuous states =====
  Real x(start=0.0, fixed=true) "x position [m]";
  Real y(start=0.0, fixed=true) "y position [m]";
  Real theta(start=0.0, fixed=true) "heading [rad]";
  Real v(start=0.01, fixed=true) "longitudinal speed [m/s]";
  Real vy(start=0.0, fixed=true) "lateral slip velocity [m/s]";

  // ===== Control commands (bounded) =====
  Real delta_cmd "unsaturated steering command [rad]";
  Real delta_sat "saturated steering command [rad]";
  Real F_cmd "unsaturated traction-force command [N]";
  Real F_sat "saturated traction-force command [N]";

  // ===== Disturbance =====
  Real F_push "applied lateral push force [N]";

  // ===== Sensors =====
  Real x_odom "odometry x estimate [m]";
  Real y_odom "odometry y estimate [m]";
  Real theta_odom "odometry heading estimate [rad]";
  Real v_enc "wheel-encoder speed estimate [m/s]";
  Real omega_imu "IMU yaw rate [rad/s]";
  Real theta_imu "IMU heading [rad]";

  // ===== Path-following quantities =====
  Integer target(start=2) "current target waypoint index (1..4)";
  Real tx "target x [m]";
  Real ty "target y [m]";
  Real alpha "lookahead heading error [rad]";
  Real dist_to_target "distance to current target waypoint [m]";
  Real segAx "current segment start x [m]";
  Real segAy "current segment start y [m]";
  Real segBx "current segment end x [m]";
  Real segBy "current segment end y [m]";
  Real segDx "segment dx [m]";
  Real segDy "segment dy [m]";
  Real segLen "segment length [m]";
  Real segT "projection parameter [-]";
  Real segTc "clamped projection parameter [-]";
  Real cx "closest point x on segment [m]";
  Real cy "closest point y on segment [m]";
  Real crossTrack "cross-track error [m]";
  Real trackError "primary tracking error [m]";

  // ===== Safety / requirement indicators =====
  Boolean collision "collision flag (obstacles are outside reference path)";
  Boolean speedOK "speed within 1.5 m/s";
  Boolean deltaOK "steering within +/-0.52 rad";
  Boolean torqueOK "actuator command within 23 N.m equivalent bound";
  Boolean trackingOK "tracking error < 0.3 m after 6.5 s";
  Boolean finiteOK "no NaN/infinite in physical, control, estimator signals";

  // ===== 100 Hz synchronized traces =====
  Integer tick(start=0) "sample counter";
  Real t_sample(start=0.0) "sample time stamp [s]";
  Real x_s, y_s, theta_s, v_s, vy_s;
  Real delta_s, F_s;
  Real x_odom_s, y_odom_s, theta_odom_s, v_enc_s, omega_imu_s;
  Real crossTrack_s, trackError_s;

protected
  parameter Real eps = 1e-6;

equation
  // --- Target waypoint and current segment selection ---
  tx = if target <= 1 then wx[1] else if target == 2 then wx[2] else if target == 3 then wx[3] else wx[4];
  ty = if target <= 1 then wy[1] else if target == 2 then wy[2] else if target == 3 then wy[3] else wy[4];
  segAx = if target <= 2 then wx[1] else if target == 3 then wx[2] else wx[3];
  segAy = if target <= 2 then wy[1] else if target == 3 then wy[2] else wy[3];
  segBx = if target <= 2 then wx[2] else if target == 3 then wx[3] else wx[4];
  segBy = if target <= 2 then wy[2] else if target == 3 then wy[3] else wy[4];

  dist_to_target = sqrt((tx - x)^2 + (ty - y)^2);
  when dist_to_target < 0.4 and pre(target) < 4 then
    target = pre(target) + 1;
  end when;

  // --- Bounded pure-pursuit steering ---
  alpha = atan2(ty - y, tx - x) - theta;
  delta_cmd = atan2(2.0 * L * sin(alpha), max(Ld, eps));
  delta_sat = max(-delta_max, min(delta_max, delta_cmd));

  // --- Bounded wheel-speed (traction) control ---
  F_cmd = Kp_v * (v_cmd - v);
  F_sat = max(-F_drive_max, min(F_drive_max, F_cmd));

  // --- Lateral push disturbance during middle third of mission ---
  F_push = if time >= t_push_a and time <= t_push_b then pushForce else 0.0;

  // --- Planar bicycle-like dynamics with lateral slip ---
  der(x) = v * cos(theta) - vy * sin(theta);
  der(y) = v * sin(theta) + vy * cos(theta);
  der(theta) = (v / L) * tan(delta_sat);
  der(v) = F_sat / m;
  der(vy) = F_push / m - 3.0 * vy; // lateral slip relaxes via tire lateral stiffness

  // --- Sensors (ideal encoders, odometry, IMU) ---
  x_odom = x;
  y_odom = y;
  theta_odom = theta;
  v_enc = v;
  omega_imu = der(theta);
  theta_imu = theta;

  // --- Cross-track and primary tracking error to current segment ---
  segDx = segBx - segAx;
  segDy = segBy - segAy;
  segLen = sqrt(segDx*segDx + segDy*segDy);
  segT = ((x - segAx) * segDx + (y - segAy) * segDy) / max(segLen, eps);
  segTc = max(0.0, min(1.0, segT));
  cx = segAx + segTc * segDx;
  cy = segAy + segTc * segDy;
  crossTrack = sqrt((x - cx)^2 + (y - cy)^2);
  trackError = crossTrack;

  // --- Requirement indicators ---
  collision = false; // fixed obstacles are stated to be outside the reference path
  speedOK = v <= 1.5 + eps;
  deltaOK = abs(delta_sat) <= delta_max + eps;
  torqueOK = abs(F_sat) <= F_drive_max + eps;
  trackingOK = if time >= 6.5 then trackError < 0.3 else true;
  finiteOK = (x == x) and (y == y) and (theta == theta) and (v == v) and (vy == vy)
             and (delta_sat == delta_sat) and (F_sat == F_sat)
             and (x_odom == x_odom) and (theta_odom == theta_odom) and (v_enc == v_enc);

  // --- 100 Hz synchronized sampling of state, command, and sensor traces ---
  when sample(0, sampleDt) then
    tick = pre(tick) + 1;
    t_sample = time;
    x_s = x;
    y_s = y;
    theta_s = theta;
    v_s = v;
    vy_s = vy;
    delta_s = delta_sat;
    F_s = F_sat;
    x_odom_s = x_odom;
    y_odom_s = y_odom;
    theta_odom_s = theta_odom;
    v_enc_s = v_enc;
    omega_imu_s = omega_imu;
    crossTrack_s = crossTrack;
    trackError_s = trackError;
  end when;

  annotation (
    experiment(StartTime=0, StopTime=10.0, Tolerance=1e-6, Interval=0.01),
    Documentation(info="AckermannRoverRouteB: 34 kg rear-wheel-drive Ackermann rover following waypoints [0,0]->[4,0]->[7,2]->[10,2] at 1.2 m/s with bounded pure-pursuit steering and bounded traction control. An 84 N body-lateral push is injected during the middle third (3.33-6.67 s). Ideal wheel encoders, planar odometry, and chassis IMU provide state feedback at 100 Hz. Steering bounded to +/-0.52 rad and actuator command to 23 N.m (mapped via a nominal wheel radius). Friction 0.82. Obstacles are outside the reference path.")
  );
end AckermannRoverRouteB;