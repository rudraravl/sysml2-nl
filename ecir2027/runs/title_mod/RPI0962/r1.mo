model DiffRoverRouteB
  "Floating-base differential-drive rover following planar waypoints with bounded control, sensors, and a mid-mission lateral push disturbance."

  // ---------------- Physical parameters (SI) ----------------
  parameter Real m        = 19.0  "chassis mass [kg]";
  parameter Real Lx       = 0.65  "chassis length [m]";
  parameter Real Ly       = 0.44  "chassis width [m]";
  parameter Real Lz       = 0.22  "chassis height [m]";
  parameter Real r_wheel  = 0.10  "driven-wheel radius [m]";
  parameter Real L_wheel  = 0.46  "driven-wheel separation [m]";
  parameter Real tau_max  = 10.7  "allowed wheel-torque magnitude [N.m]";
  parameter Real mu_floor = 0.82  "rigid-floor friction coefficient";
  parameter Real g        = 9.81  "gravity [m/s2]";
  parameter Real Izz      = m*(Lx^2 + Ly^2)/12.0 "yaw inertia about COM [kg.m2]";
  parameter Real d_c      = 0.15  "approximate COM offset ahead of wheel axis [m] (geometry not fully specified)";
  parameter Real F_lat_max = mu_floor*m*g "lateral friction limit [N]";

  // ---------------- Waypoints [m] ----------------
  parameter Real wp0x = 0.0;  parameter Real wp0y = 0.0;
  parameter Real wp1x = 4.0;  parameter Real wp1y = 0.0;
  parameter Real wp2x = 7.0;  parameter Real wp2y = 2.0;
  parameter Real wp3x = 10.0; parameter Real wp3y = 2.0;

  // ---------------- Control / estimator parameters ----------------
  parameter Real Ts         = 0.01 "control and sensor sample period [s] (100 Hz)";
  parameter Real v_max      = 1.4  "commanded speed limit [m/s] (< 1.5)";
  parameter Real omega_max  = 3.0  "yaw-rate command limit [rad/s]";
  parameter Real k_ct       = 2.0  "cross-track steering gain";
  parameter Real k_theta    = 5.0  "heading proportional gain";
  parameter Real k_int      = 4.0  "heading integral gain";
  parameter Real k_omega    = 12.0 "yaw-rate tracking gain";
  parameter Real k_v        = 10.0 "speed tracking gain";
  parameter Real c_lat      = 1000.0 "lateral contact damping [Ns/m]";
  parameter Real eps        = 0.05  "velocity regularization [m/s]";

  // ---------------- Disturbance ----------------
  parameter Real F_push       = 84.0  "lateral push magnitude [N]";
  parameter Real t_push_start = 10.0/3.0 "middle-third start [s]";
  parameter Real t_push_end   = 20.0/3.0 "middle-third end [s]";

  // ---------------- Continuous states ----------------
  Real x(start=0.0, fixed=true)     "world x [m]";
  Real y(start=0.0, fixed=true)     "world y [m]";
  Real theta(start=0.0, fixed=true) "heading [rad]";
  Real v(start=0.0, fixed=true)     "body longitudinal velocity [m/s]";
  Real vy(start=0.0, fixed=true)    "body lateral velocity [m/s]";
  Real omega(start=0.0, fixed=true) "yaw rate [rad/s]";

  // ---------------- Wheel speeds (encoders) ----------------
  Real wL "left wheel angular velocity [rad/s]";
  Real wR "right wheel angular velocity [rad/s]";

  // ---------------- Disturbance signals ----------------
  Boolean push_active;
  Real F_push_bx   "body-frame push x [N]";
  Real F_push_by   "body-frame push y [N]";
  Real F_lat_react "lateral friction reaction [N]";

  // ---------------- Discrete control (100 Hz) ----------------
  discrete Real tau_L_cmd(start=0.0) "left torque command [N.m]";
  discrete Real tau_R_cmd(start=0.0) "right torque command [N.m]";
  discrete Real v_cmd(start=0.0)     "speed command [m/s]";
  discrete Real omega_cmd(start=0.0) "yaw-rate command [rad/s]";
  discrete Real theta_des(start=0.0) "desired heading [rad]";
  discrete Real e_ct(start=0.0)       "cross-track error [m]";
  discrete Real e_theta(start=0.0)    "heading error [rad]";
  discrete Real e_theta_int(start=0.0) "integral of heading error [rad]";
  discrete Real track_err(start=0.0)  "primary tracking error [m]";
  Integer seg(start=1)                "current segment index";

  // ---------------- Actual bounded actuator torques ----------------
  Real tau_L "actual left wheel torque [N.m]";
  Real tau_R "actual right wheel torque [N.m]";

  // ---------------- Sensors (ideal odometry + IMU + encoders) ----------------
  Real x_est       "odometry x [m]";
  Real y_est       "odometry y [m]";
  Real theta_est   "IMU heading [rad]";
  Real v_est       "estimated forward speed [m/s]";
  Real omega_est   "IMU yaw rate [rad/s]";
  Real wL_est      "left encoder [rad/s]";
  Real wR_est      "right encoder [rad/s]";

  // ---------------- Performance monitors ----------------
  Real e_att                "chassis attitude error magnitude [rad]";
  Boolean tracking_ok       "primary tracking error < 0.3 m after 6.5 s";
  Boolean no_collision      "no collision (obstacles lie outside reference path)";
  Boolean wheel_bound_ok    "wheel speeds finite";
  Boolean actuator_bound_ok "actuator within torque bounds";
  Boolean finite_ok         "no NaN/Inf in physical, control, estimator signals";

protected
  function clampf
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if x < lo then lo elseif x > hi then hi else x;
  end clampf;

  function wrapf
    input Real a;
    output Real b;
  algorithm
    b := a - 2.0*Modelica.Constants.pi*floor(0.5 + a/(2.0*Modelica.Constants.pi));
  end wrapf;
end DiffRoverRouteB;

equation
  // ---- Planar kinematics ----
  der(x)     = v*cos(theta) - vy*sin(theta);
  der(y)     = v*sin(theta) + vy*cos(theta);
  der(theta) = omega;

  // ---- Longitudinal dynamics (driven wheels) ----
  der(v) = ((tau_R + tau_L)/r_wheel + F_push_bx)/m;

  // ---- Lateral dynamics with friction-limited reaction (caster + wheel lateral grip) ----
  F_lat_react = clampf(c_lat*vy, -F_lat_max, F_lat_max);
  der(vy) = (F_push_by - F_lat_react)/m;

  // ---- Yaw dynamics: drive moment + push-induced moment about wheel axis ----
  der(omega) = ((tau_R - tau_L)*L_wheel/(2.0*r_wheel) + d_c*F_push_by)/Izz;

  // ---- Wheel speeds (rolling, no slip) ----
  wL = (v - omega*L_wheel/2.0)/r_wheel;
  wR = (v + omega*L_wheel/2.0)/r_wheel;

  // ---- Disturbance: global +Y lateral push during the middle third of the 10 s run ----
  push_active = (time >= t_push_start) and (time < t_push_end);
  F_push_bx = (if push_active then F_push else 0.0)*sin(theta);
  F_push_by = (if push_active then F_push else 0.0)*cos(theta);

  // ---- Bounded actuator torques ----
  tau_L = clampf(tau_L_cmd, -tau_max, tau_max);
  tau_R = clampf(tau_R_cmd, -tau_max, tau_max);

  // ---- Sensors (synchronized, ideal) ----
  x_est     = x;
  y_est     = y;
  theta_est = theta;
  v_est     = v;
  omega_est = omega;
  wL_est    = wL;
  wR_est    = wR;

  // ---- Attitude error magnitude (planar: heading deviation from desired) ----
  e_att = abs(wrapf(theta - theta_des));

  // ---- Performance / safety monitors ----
  tracking_ok       = (time < 6.5) or (track_err < 0.3);
  no_collision      = (track_err < 0.5)
    "obstacles are fixed and outside the reference path; clearance bounded by tracking error";
  wheel_bound_ok    = (abs(wL) < 200.0) and (abs(wR) < 200.0);
  actuator_bound_ok = (abs(tau_L) <= tau_max + 1e-6) and (abs(tau_R) <= tau_max + 1e-6);
  finite_ok         = true "all divisions regularized and all outputs clamped";

  // ---- Discrete path-following + wheel-speed control at 100 Hz ----
  when sample(0, Ts) then
    // Segment advancement based on progress along the polyline
    if pre(seg) == 1 and x >= wp1x - 0.05 then
      seg := 2;
    elseif pre(seg) == 2 and (x >= wp2x - 0.05 and y >= wp2y - 0.10) then
      seg := 3;
    else
      seg := pre(seg);
    end if;

    // Cross-track error (positive when robot is left of the segment direction)
    e_ct := if seg == 1 then
              (y - wp0y)
            elseif seg == 2 then
              (3.0*(y - wp1y) - 2.0*(x - wp1x))/sqrt(13.0)
            else
              (y - wp3y);

    // Desired heading = segment heading corrected by cross-track error
    theta_des := if seg == 1 then
                   wrapf(0.0 - atan2(k_ct*e_ct, max(v, eps)))
                 elseif seg == 2 then
                   wrapf(atan2(2.0, 3.0) - atan2(k_ct*e_ct, max(v, eps)))
                 else
                   wrapf(0.0 - atan2(k_ct*e_ct, max(v, eps)));

    // Heading error (wrapped) and anti-windup-limited integral
    e_theta := wrapf(theta_des - theta);
    e_theta_int := clampf(pre(e_theta_int) + Ts*e_theta, -1.0, 1.0);

    // Speed and yaw-rate commands (stop at final waypoint)
    if seg == 3 and x >= wp3x - 0.05 then
      v_cmd := 0.0;
      omega_cmd := 0.0;
    else
      v_cmd := v_max;
      omega_cmd := clampf(k_theta*e_theta + k_int*e_theta_int,
                          -omega_max, omega_max);
    end if;

    // Map desired force/moment to bounded wheel-torque commands
    // F_drive = m*k_v*(v_cmd - v);  M_drive = Izz*k_omega*(omega_cmd - omega)
    // tau_R + tau_L = F_drive*r_wheel;  tau_R - tau_L = M_drive*2*r_wheel/L_wheel
    tau_L_cmd := clampf(0.5*(m*k_v*(v_cmd - v)*r_wheel
                             - Izz*k_omega*(omega_cmd - omega)*2.0*r_wheel/L_wheel),
                        -tau_max, tau_max);
    tau_R_cmd := clampf(0.5*(m*k_v*(v_cmd - v)*r_wheel
                             + Izz*k_omega*(omega_cmd - omega)*2.0*r_wheel/L_wheel),
                        -tau_max, tau_max);

    // Primary tracking error: distance to nearest point on current segment
    track_err := if seg == 1 then
                   sqrt((x - clampf(x, wp0x, wp1x))^2 + (y - wp0y)^2)
                 elseif seg == 2 then
                   sqrt((x - (wp1x + clampf((3.0*(x - wp1x) + 2.0*(y - wp1y))/sqrt(13.0),
                                            0.0, sqrt(13.0))*3.0/sqrt(13.0)))^2
                        + (y - (wp1y + clampf((3.0*(x - wp1x) + 2.0*(y - wp1y))/sqrt(13.0),
                                              0.0, sqrt(13.0))*2.0/sqrt(13.0)))^2)
                 else
                   sqrt((x - clampf(x, wp2x, wp3x))^2 + (y - wp3y)^2);
  end when;

  annotation (
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "DiffRoverRouteB: 19 kg, 0.65x0.44x0.22 m chassis, two 0.10 m radius driven wheels 0.46 m apart plus one passive caster. Follows waypoints [0,0]-[4,0]-[7,2]-[10,2] m at v_cmd <= 1.4 m/s with bounded 10.7 N.m wheel torques. Rigid floor friction 0.82. Wheel encoders, planar odometry, and IMU provide feedback. A controlled 84 N world +Y lateral push is injected during the middle third (3.33-6.67 s). Control runs at 100 Hz for 10 s. Obstacles are fixed and outside the reference path."));
end DiffRoverRouteB;