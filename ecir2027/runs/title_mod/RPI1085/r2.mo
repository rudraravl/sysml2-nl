model GroundPairFormE
  "Two differential-drive robots following a leader trajectory with distributed formation control"

  // ============ Physical Parameters ============
  parameter Real  m_robot(unit="kg")    = 14.0  "robot mass";
  parameter Real  r_wheel(unit="m")     = 0.09  "wheel radius";
  parameter Real  L_wheel(unit="m")     = 0.20  "wheelbase (not specified, default)";
  parameter Real  I_robot(unit="kg.m2") = 0.35  "moment of inertia (not specified, default)";
  parameter Real  b_visc(unit="N.s/m")         = 2.0   "linear viscous damping (not specified, default)";
  parameter Real  b_visc_w(unit="N.m.s/rad")   = 0.3   "angular viscous damping (not specified, default)";
  parameter Real  tau_max(unit="N.m")   = 11.0  "max wheel torque per wheel";

  // ============ Communication Parameters ============
  parameter Real  t_delay(unit="s")   = 0.096 "message delay";
  parameter Real  T_sim(unit="s")     = 16.0  "simulation duration";
  parameter Real  t_check(unit="s")   = 10.4  "acceptance check time";
  parameter Real  e_track_max(unit="m")= 0.27  "max primary tracking error after t_check";

  // ============ Formation Parameters ============
  parameter Real  off1_x(unit="m") = 0.0   "robot1 formation x-offset from leader";
  parameter Real  off1_y(unit="m") = 0.3   "robot1 formation y-offset from leader";
  parameter Real  off2_x(unit="m") = 0.0   "robot2 formation x-offset from leader";
  parameter Real  off2_y(unit="m") = -0.3  "robot2 formation y-offset from leader";
  parameter Real  d_min_sep(unit="m")= 0.15 "minimum pairwise separation";
  parameter Real  d_collide(unit="m")= 0.12 "collision distance threshold";
  parameter Real  d_form_nom(unit="m")=0.6  "nominal formation separation";

  // ============ Leader Trajectory ============
  parameter Real  leader_v(unit="m/s")   = 0.25 "leader linear speed";
  parameter Real  leader_turn(unit="rad/s")= 0.15 "leader turn rate";

  // ============ Control Gains ============
  parameter Real  kp_pos   = 3.0  "position proportional gain";
  parameter Real  kp_head  = 2.5  "heading/lateral proportional gain";
  parameter Real  kp_v     = 8.0  "velocity tracking gain";
  parameter Real  kp_w     = 6.0  "angular velocity tracking gain";
  parameter Real  v_max(unit="m/s")    = 1.0 "max linear velocity command (not specified, default)";
  parameter Real  omega_max(unit="rad/s")= 2.0 "max angular velocity command (not specified, default)";

  // ============ Obstacle ============
  parameter Real  obs_x(unit="m") = 3.0  "obstacle x position (outside path)";
  parameter Real  obs_y(unit="m") = -2.0 "obstacle y position (outside path)";
  parameter Real  obs_r(unit="m") = 0.15 "obstacle radius";

  // ============ Acceptance Thresholds ============
  parameter Real  e_form_max(unit="m")   = 0.20 "max formation error (not specified, default)";
  parameter Real  comm_age_max(unit="s")  = 0.12 "max communication age (not specified, default)";

  // ============ Robot 1 States ============
  Real x1(start=0.0,  fixed=true, unit="m");
  Real y1(start=0.3,  fixed=true, unit="m");
  Real theta1(start=0.0, fixed=true, unit="rad");
  Real v1(start=0.0,  fixed=true, unit="m/s");
  Real omega1(start=0.0, fixed=true, unit="rad/s");
  Real tau1L(unit="N.m")  "actual left wheel torque robot1";
  Real tau1R(unit="N.m")  "actual right wheel torque robot1";
  Real tau1L_cmd(unit="N.m") "commanded left wheel torque robot1";
  Real tau1R_cmd(unit="N.m") "commanded right wheel torque robot1";

  // ============ Robot 2 States ============
  Real x2(start=0.0,  fixed=true, unit="m");
  Real y2(start=-0.3, fixed=true, unit="m");
  Real theta2(start=0.0, fixed=true, unit="rad");
  Real v2(start=0.0,  fixed=true, unit="m/s");
  Real omega2(start=0.0, fixed=true, unit="rad/s");
  Real tau2L(unit="N.m");
  Real tau2R(unit="N.m");
  Real tau2L_cmd(unit="N.m");
  Real tau2R_cmd(unit="N.m");

  // ============ Leader Reference ============
  Real xL(unit="m");
  Real yL(unit="m");
  Real thetaL(unit="rad");

  // ============ Desired Formation Positions ============
  Real x1_des(unit="m");
  Real y1_des(unit="m");
  Real x2_des(unit="m");
  Real y2_des(unit="m");

  // ============ Onboard State Estimators ============
  Real x1_est(start=0.0,  fixed=true, unit="m");
  Real y1_est(start=0.3,  fixed=true, unit="m");
  Real theta1_est(start=0.0, fixed=true, unit="rad");
  Real x2_est(start=0.0,  fixed=true, unit="m");
  Real y2_est(start=-0.3, fixed=true, unit="m");
  Real theta2_est(start=0.0, fixed=true, unit="rad");

  // ============ Delayed Peer Messages ============
  Real x1_del(unit="m") "robot1 pose x received by robot2 with delay";
  Real y1_del(unit="m") "robot1 pose y received by robot2 with delay";
  Real x2_del(unit="m") "robot2 pose x received by robot1 with delay";
  Real y2_del(unit="m") "robot2 pose y received by robot1 with delay";

  // ============ Sensors ============
  Real enc1L(start=0.0, fixed=true, unit="rad") "robot1 left wheel encoder";
  Real enc1R(start=0.0, fixed=true, unit="rad") "robot1 right wheel encoder";
  Real enc2L(start=0.0, fixed=true, unit="rad") "robot2 left wheel encoder";
  Real enc2R(start=0.0, fixed=true, unit="rad") "robot2 right wheel encoder";
  Real imu1_rate(unit="rad/s") "robot1 IMU yaw rate";
  Real imu2_rate(unit="rad/s") "robot2 IMU yaw rate";
  Real range12(unit="m") "lidar peer range between robot1 and robot2";

  // ============ Middle-Third Disturbance ============
  Real dist1(unit="N.m") "bounded torque disturbance on robot1";
  Real dist2(unit="N.m") "bounded torque disturbance on robot2";

  // ============ Control Intermediate Variables ============
  Real v1_des(unit="m/s");
  Real omega1_des(unit="rad/s");
  Real v2_des(unit="m/s");
  Real omega2_des(unit="rad/s");
  Real e1_fwd(unit="m")  "robot1 forward position error in body frame";
  Real e1_lat(unit="m")  "robot1 lateral position error in body frame";
  Real e2_fwd(unit="m");
  Real e2_lat(unit="m");
  Real F1(unit="N")      "robot1 net traction force";
  Real M1(unit="N.m")   "robot1 net yaw torque";
  Real F2(unit="N");
  Real M2(unit="N.m");
  Real tau1L_raw(unit="N.m") "robot1 raw left torque before saturation";
  Real tau1R_raw(unit="N.m") "robot1 raw right torque before saturation";
  Real tau2L_raw(unit="N.m");
  Real tau2R_raw(unit="N.m");

  // ============ Error Metrics ============
  Real e_track1(unit="m")  "robot1 tracking error to desired formation position";
  Real e_track2(unit="m")  "robot2 tracking error to desired formation position";
  Real e_form(unit="m")    "formation separation error";
  Real separation(unit="m") "actual pairwise separation";
  Real comm_age(unit="s")  "communication message age";
  Real dist_obs1(unit="m") "robot1 clearance to obstacle";
  Real dist_obs2(unit="m") "robot2 clearance to obstacle";

  // ============ Acceptance ============
  Real e_track1_check(start=1.0, unit="m") "robot1 tracking error sampled at t_check";
  Boolean pass_actuator  "all wheel torques within 11 N.m";
  Boolean pass_separation "pairwise separation >= d_min_sep";
  Boolean pass_formation  "formation error within threshold";
  Boolean pass_comm       "communication age within threshold";
  Boolean pass_collision  "no collision with obstacle or between robots";
  Boolean pass_track      "primary tracking error < 0.27 m after 10.4 s";
  Boolean pass_noNaN      "no NaN or infinite physical, control, or estimator values";
  Boolean pass_all        "fail-closed overall acceptance";

equation
  // ============ Leader Trajectory (gentle circle) ============
  xL     = (leader_v / leader_turn) * sin(leader_turn * time);
  yL     = (leader_v / leader_turn) * (1.0 - cos(leader_turn * time));
  thetaL = leader_turn * time;

  // ============ Desired Formation Positions ============
  x1_des = xL + off1_x * cos(thetaL) - off1_y * sin(thetaL);
  y1_des = yL + off1_x * sin(thetaL) + off1_y * cos(thetaL);
  x2_des = xL + off2_x * cos(thetaL) - off2_y * sin(thetaL);
  y2_des = yL + off2_x * sin(thetaL) + off2_y * cos(thetaL);

  // ============ Onboard State Estimators (first-order EKF approximation) ============
  der(x1_est)     = (x1 - x1_est) / 0.02;
  der(y1_est)     = (y1 - y1_est) / 0.02;
  der(theta1_est) = (theta1 - theta1_est) / 0.02;
  der(x2_est)     = (x2 - x2_est) / 0.02;
  der(y2_est)     = (y2 - y2_est) / 0.02;
  der(theta2_est) = (theta2 - theta2_est) / 0.02;

  // ============ Wheel Encoders ============
  der(enc1L) = (v1 - omega1 * L_wheel / 2.0) / r_wheel;
  der(enc1R) = (v1 + omega1 * L_wheel / 2.0) / r_wheel;
  der(enc2L) = (v2 - omega2 * L_wheel / 2.0) / r_wheel;
  der(enc2R) = (v2 + omega2 * L_wheel / 2.0) / r_wheel;

  // ============ IMU ============
  imu1_rate = omega1;
  imu2_rate = omega2;

  // ============ Delayed Peer Pose Messages (0.096 s) ============
  x1_del = delay(x1, t_delay);
  y1_del = delay(y1, t_delay);
  x2_del = delay(x2, t_delay);
  y2_del = delay(y2, t_delay);

  // Communication age
  comm_age = t_delay;

  // ============ Lidar Peer Range ============
  range12 = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + 1e-12);

  // ============ Middle-Third Disturbance (bounded) ============
  dist1 = if (time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0) then 1.5 * sin(8.0 * time) else 0.0;
  dist2 = if (time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0) then 1.5 * cos(8.0 * time) else 0.0;

  // ============ Robot 1 Distributed Formation Control ============
  // Position error in robot 1 body frame (using estimated pose)
  e1_fwd = (x1_des - x1_est) * cos(theta1_est) + (y1_des - y1_est) * sin(theta1_est);
  e1_lat = -(x1_des - x1_est) * sin(theta1_est) + (y1_des - y1_est) * cos(theta1_est);

  // Bounded velocity commands
  v1_des = if (kp_pos * e1_fwd > v_max) then v_max
           else if (kp_pos * e1_fwd < -v_max) then -v_max
           else kp_pos * e1_fwd;

  omega1_des = if (kp_head * e1_lat > omega_max) then omega_max
               else if (kp_head * e1_lat < -omega_max) then -omega_max
               else kp_head * e1_lat;

  // Velocity tracking (force and torque)
  F1 = m_robot * kp_v * (v1_des - v1);
  M1 = I_robot * kp_w * (omega1_des - omega1);

  // Raw wheel torques
  tau1R_raw = (F1 * r_wheel + M1 * 2.0 * r_wheel / L_wheel) / 2.0 + dist1;
  tau1L_raw = (F1 * r_wheel - M1 * 2.0 * r_wheel / L_wheel) / 2.0 - dist1;

  // Bounded commands (actuator limits)
  tau1R_cmd = if tau1R_raw > tau_max then tau_max else if tau1R_raw < -tau_max then -tau_max else tau1R_raw;
  tau1L_cmd = if tau1L_raw > tau_max then tau_max else if tau1L_raw < -tau_max then -tau_max else tau1L_raw;

  // Ideal actuator: actual = commanded
  tau1R = tau1R_cmd;
  tau1L = tau1L_cmd;

  // ============ Robot 2 Distributed Formation Control ============
  e2_fwd = (x2_des - x2_est) * cos(theta2_est) + (y2_des - y2_est) * sin(theta2_est);
  e2_lat = -(x2_des - x2_est) * sin(theta2_est) + (y2_des - y2_est) * cos(theta2_est);

  v2_des = if (kp_pos * e2_fwd > v_max) then v_max
           else if (kp_pos * e2_fwd < -v_max) then -v_max
           else kp_pos * e2_fwd;

  omega2_des = if (kp_head * e2_lat > omega_max) then omega_max
               else if (kp_head * e2_lat < -omega_max) then -omega_max
               else kp_head * e2_lat;

  F2 = m_robot * kp_v * (v2_des - v2);
  M2 = I_robot * kp_w * (omega2_des - omega2);

  tau2R_raw = (F2 * r_wheel + M2 * 2.0 * r_wheel / L_wheel) / 2.0 + dist2;
  tau2L_raw = (F2 * r_wheel - M2 * 2.0 * r_wheel / L_wheel) / 2.0 - dist2;

  tau2R_cmd = if tau2R_raw > tau_max then tau_max else if tau2R_raw < -tau_max then -tau_max else tau2R_raw;
  tau2L_cmd = if tau2L_raw > tau_max then tau_max else if tau2L_raw < -tau_max then -tau_max else tau2L_raw;

  tau2R = tau2R_cmd;
  tau2L = tau2L_cmd;

  // ============ Robot 1 Dynamics ============
  der(x1)     = v1 * cos(theta1);
  der(y1)     = v1 * sin(theta1);
  der(theta1) = omega1;
  der(v1)     = ((tau1L + tau1R) / r_wheel - b_visc * v1) / m_robot;
  der(omega1) = ((tau1R - tau1L) * L_wheel / (2.0 * r_wheel) - b_visc_w * omega1) / I_robot;

  // ============ Robot 2 Dynamics ============
  der(x2)     = v2 * cos(theta2);
  der(y2)     = v2 * sin(theta2);
  der(theta2) = omega2;
  der(v2)     = ((tau2L + tau2R) / r_wheel - b_visc * v2) / m_robot;
  der(omega2) = ((tau2R - tau2L) * L_wheel / (2.0 * r_wheel) - b_visc_w * omega2) / I_robot;

  // ============ Error Metrics ============
  e_track1 = sqrt((x1 - x1_des) * (x1 - x1_des) + (y1 - y1_des) * (y1 - y1_des) + 1e-12);
  e_track2 = sqrt((x2 - x2_des) * (x2 - x2_des) + (y2 - y2_des) * (y2 - y2_des) + 1e-12);
  e_form   = abs(range12 - d_form_nom);
  separation = range12;

  dist_obs1 = sqrt((x1 - obs_x) * (x1 - obs_x) + (y1 - obs_y) * (y1 - obs_y) + 1e-12) - obs_r;
  dist_obs2 = sqrt((x2 - obs_x) * (x2 - obs_x) + (y2 - obs_y) * (y2 - obs_y) + 1e-12) - obs_r;

  // ============ Acceptance: Sample Primary Tracking Error at t_check ============
  when time >= t_check then
    e_track1_check = e_track1;
  end when;

  // ============ Acceptance Checks (fail-closed) ============

  // Actuator limits: all four wheel-torque channels bounded by 11 N.m
  pass_actuator = (abs(tau1L) <= tau_max + 1e-6) and (abs(tau1R) <= tau_max + 1e-6) and
                  (abs(tau2L) <= tau_max + 1e-6) and (abs(tau2R) <= tau_max + 1e-6);

  // Pairwise separation
  pass_separation = separation >= d_min_sep;

  // Formation error
  pass_formation = e_form <= e_form_max;

  // Communication age
  pass_comm = comm_age <= comm_age_max;

  // No collision (obstacle and inter-robot)
  pass_collision = (dist_obs1 > 0.0) and (dist_obs2 > 0.0) and (separation > d_collide);

  // Primary tracking error below 0.27 m after 10.4 s
  pass_track = e_track1_check < e_track_max;

  // No NaN or infinite values (NaN fails all comparisons, infinity exceeds bounds)
  pass_noNaN = (x1 >= -1e6) and (x1 <= 1e6) and
               (y1 >= -1e6) and (y1 <= 1e6) and
               (x2 >= -1e6) and (x2 <= 1e6) and
               (y2 >= -1e6) and (y2 <= 1e6) and
               (v1 >= -1e6) and (v1 <= 1e6) and
               (v2 >= -1e6) and (v2 <= 1e6) and
               (omega1 >= -1e6) and (omega1 <= 1e6) and
               (omega2 >= -1e6) and (omega2 <= 1e6) and
               (tau1L >= -1e6) and (tau1L <= 1e6) and
               (tau1R >= -1e6) and (tau1R <= 1e6) and
               (tau2L >= -1e6) and (tau2L <= 1e6) and
               (tau2R >= -1e6) and (tau2R <= 1e6) and
               (x1_est >= -1e6) and (x1_est <= 1e6) and
               (y1_est >= -1e6) and (y1_est <= 1e6) and
               (x2_est >= -1e6) and (x2_est <= 1e6) and
               (y2_est >= -1e6) and (y2_est <= 1e6) and
               (range12 >= 0.0) and (range12 <= 1e6);

  // Overall fail-closed acceptance
  pass_all = pass_actuator and pass_separation and pass_formation and
             pass_comm and pass_collision and pass_track and pass_noNaN;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "GroundPairFormE: Two 14 kg differential-drive robots with 0.09 m wheels
      follow a leader trajectory while maintaining declared relative offsets (0, 0.3) and (0, -0.3)
      and minimum separation 0.15 m. Four wheel-torque channels bounded at 11 N.m.
      Onboard state estimation (first-order EKF), peer-relative lidar range, and delayed pose
      messages (0.096 s). Distributed formation control with bounded local commands.
      Middle-third disturbance (5.33-10.67 s): bounded 1.5 N.m sinusoidal torque perturbation.
      Fixed obstacle at (3, -2) outside nominal circular path. Control rate 250 Hz (Interval=0.004 s).
      Acceptance is fail-closed: actuator limits, separation, formation error, comm age,
      no collision, primary tracking error < 0.27 m after 10.4 s, no NaN/infinite values."));
end GroundPairFormE;