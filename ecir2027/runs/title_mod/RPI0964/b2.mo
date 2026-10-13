model DiffRoverRouteD
  "Instrumented floating-base differential-drive rover following planar waypoints"

  // ---- Physical embodiment (values from request) ----
  parameter Real m_chassis(unit="kg") = 19.0 "chassis mass";
  parameter Real Lx(unit="m") = 0.65 "chassis length";
  parameter Real Ly_dim(unit="m") = 0.44 "chassis width";
  parameter Real Lz(unit="m") = 0.22 "chassis height";
  parameter Real r_wheel(unit="m") = 0.10 "driven wheel radius";
  parameter Real L_wheel(unit="m") = 0.46 "wheel separation";
  parameter Real I_z(unit="kg.m2") = m_chassis/12.0*(Lx^2 + Ly_dim^2)
    "yaw inertia of box chassis";
  parameter Real mu = 0.82 "rigid floor friction coefficient";
  parameter Real g(unit="m/s2") = 9.81 "gravity";
  parameter Real N_wheel(unit="N") = m_chassis*g/2.0
    "normal load per driven wheel (caster load unknown)";
  parameter Real F_traction_max(unit="N") = mu*N_wheel
    "max traction force per wheel";
  parameter Real tau_max(unit="N.m") = 13.0 "max wheel motor torque";
  parameter Real v_max(unit="m/s") = 1.5 "speed bound";
  parameter Real v_thresh(unit="m/s") = 0.05 "lateral slip threshold";

  // ---- Mission ----
  parameter Real v_ref(unit="m/s") = 1.2 "commanded cruise speed (below 1.5)";
  parameter Real t_total(unit="s") = 14.0 "mission duration";
  parameter Real dt_ctrl(unit="s") = 0.005 "control period (200 Hz)";
  parameter Real F_push(unit="N") = 120.0 "lateral push magnitude";
  parameter Real t_push_on(unit="s") = t_total/3.0 "push start (middle third)";
  parameter Real t_push_off(unit="s") = 2.0*t_total/3.0 "push end (middle third)";

  // Waypoints [0,0],[4,0],[7,2],[10,2]
  parameter Real wx[4](unit="m") = {0.0, 4.0, 7.0, 10.0};
  parameter Real wy[4](unit="m") = {0.0, 0.0, 2.0, 2.0};

  // ---- Controller gains ----
  parameter Real Kv(unit="N.m/(m/s)") = 90.0 "forward speed gain";
  parameter Real Kw(unit="N.m/(rad/s)") = 18.0 "yaw rate gain";
  parameter Real K_heading(unit="1/s") = 2.2 "heading-to-target P gain";
  parameter Real K_cross(unit="1/s") = 0.8 "cross-track P gain";
  parameter Real omega_cmd_max(unit="rad/s") = 2.0 "yaw rate command bound";

  // ---- Continuous plant states ----
  Real x(start=0.0, fixed=true, unit="m") "world frame x";
  Real y(start=0.0, fixed=true, unit="m") "world frame y";
  Real theta(start=0.0, fixed=true, unit="rad") "heading";
  Real v(start=0.0, fixed=true, unit="m/s") "forward speed (body x)";
  Real vy(start=0.0, fixed=true, unit="m/s") "lateral speed (body y)";
  Real omega(start=0.0, fixed=true, unit="rad/s") "yaw rate";

  // ---- Actuator and contact ----
  Real tau_L(unit="N.m") "left wheel torque command (bounded)";
  Real tau_R(unit="N.m") "right wheel torque command (bounded)";
  Real F_L(unit="N") "left wheel traction force";
  Real F_R(unit="N") "right wheel traction force";
  Real omega_L(unit="rad/s") "left wheel angular speed (encoder)";
  Real omega_R(unit="rad/s") "right wheel angular speed (encoder)";

  // ---- Push disturbance ----
  Real F_push_y(unit="N") "world-y push disturbance";

  // ---- Discrete controller states (200 Hz) ----
  Integer i_target(start=2) "current target waypoint index (2..4)";
  discrete Real x_target(start=4.0, unit="m") "target x";
  discrete Real y_target(start=0.0, unit="m") "target y";
  discrete Real x_seg_start(start=0.0, unit="m") "current segment start x";
  discrete Real y_seg_start(start=0.0, unit="m") "current segment start y";
  discrete Real v_cmd(start=0.0, unit="m/s") "commanded forward speed";
  discrete Real omega_cmd(start=0.0, unit="rad/s") "commanded yaw rate";
  discrete Real heading_err(start=0.0, unit="rad") "heading error to target";
  discrete Real cross_track_err(start=0.0, unit="m") "cross-track error";
  discrete Real dist_to_target(start=0.0, unit="m") "distance to target";

  // ---- Sensors ----
  Real x_odom(unit="m") "planar odometry x";
  Real y_odom(unit="m") "planar odometry y";
  Real theta_imu(unit="rad") "chassis IMU heading";
  Real omega_imu(unit="rad/s") "chassis IMU yaw rate";

  // ---- Performance trace ----
  Real primary_track_err(unit="m") "primary tracking error to target";

equation
  // Push disturbance (controlled lateral push, middle third)
  F_push_y = if (time >= t_push_on and time <= t_push_off) then F_push else 0.0;

  // Contact forces: torque/radius, bounded by friction capacity
  F_L = sat(tau_L/r_wheel, -F_traction_max, F_traction_max);
  F_R = sat(tau_R/r_wheel, -F_traction_max, F_traction_max);

  // Planar kinematics (body -> world)
  der(x) = v*cos(theta) - vy*sin(theta);
  der(y) = v*sin(theta) + vy*cos(theta);
  der(theta) = omega;

  // Body-frame dynamics
  // Push decomposed into body frame; smooth lateral friction (passive caster)
  // Caster geometry/offset unknown -- not modeled
  der(v) = (F_L + F_R + F_push_y*sin(theta))/m_chassis + omega*vy;
  der(vy) = (F_push_y*cos(theta) - mu*m_chassis*g*tanh(vy/v_thresh))/m_chassis - omega*v;
  der(omega) = (F_R - F_L)*L_wheel/(2.0*I_z);

  // Wheel angular velocities (wheel-encoder signals)
  omega_L = (v - omega*L_wheel/2.0)/r_wheel;
  omega_R = (v + omega*L_wheel/2.0)/r_wheel;

  // Sensors (ideal instrumentation)
  x_odom = x;
  y_odom = y;
  theta_imu = theta;
  omega_imu = omega;

  // Performance trace
  primary_track_err = safeHypot(x - x_target, y - y_target);

  // Continuous actuator command: bounded wheel-speed control (torque limited)
  tau_L = sat(Kv*(v_cmd - v) - Kw*(omega_cmd - omega), -tau_max, tau_max);
  tau_R = sat(Kv*(v_cmd - v) + Kw*(omega_cmd - omega), -tau_max, tau_max);

algorithm
  // Discrete controller at 200 Hz
  when sample(0, dt_ctrl) then
    // Distance to current target
    dist_to_target := safeHypot(x - x_target, y - y_target);

    // Advance target when close enough and not at final waypoint
    if i_target < 4 and dist_to_target < 0.45 then
      i_target := i_target + 1;
      x_seg_start := x_target;
      y_seg_start := y_target;
    else
      i_target := i_target;
      x_seg_start := x_seg_start;
      y_seg_start := y_seg_start;
    end if;

    // Update target coordinates from new index
    x_target := if i_target == 2 then wx[2] elseif i_target == 3 then wx[3] else wx[4];
    y_target := if i_target == 2 then wy[2] elseif i_target == 3 then wy[3] else wy[4];

    // Heading error toward current target
    heading_err := wrapAngle(atan2(y_target - y, x_target - x) - theta);

    // Cross-track error: signed perpendicular distance to current segment
    cross_track_err := ((x - x_seg_start)*(y_target - y_seg_start)
                       - (y - y_seg_start)*(x_target - x_seg_start))
                       / safeHypot(x_target - x_seg_start, y_target - y_seg_start);

    // Bounded path-following commands; stop at final waypoint
    if i_target >= 4 and dist_to_target < 0.45 then
      v_cmd := 0.0;
      omega_cmd := 0.0;
    else
      v_cmd := v_ref * sat(cos(heading_err), 0.0, 1.0);
      omega_cmd := sat(K_heading*heading_err - K_cross*cross_track_err,
                       -omega_cmd_max, omega_cmd_max);
    end if;
  end when;

  annotation(
    experiment(StopTime=14.0, Tolerance=1e-6, Interval=0.005),
    uses(Modelica(version="4.0.0"))
  );
end DiffRoverRouteD;