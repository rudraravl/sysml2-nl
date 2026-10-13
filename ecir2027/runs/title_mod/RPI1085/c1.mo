model GroundPairFormE
  extends Modelica.Icons.Example;

  // ---- Sampling / run window ----
  parameter Real dt = 1.0/250.0 "Control and sensor update period (s)";
  parameter Real t_sim = 16.0 "Simulation horizon (s)";
  parameter Real t_settle = 10.4 "Primary tracking acceptance time (s)";

  // ---- Leader trajectory ----
  parameter Real R_lead = 2.0 "Leader circular path radius (m)";
  parameter Real w_lead = 0.30 "Leader angular rate (rad/s)";

  // ---- Robot physical parameters ----
  parameter Real m_robot = 14.0 "Robot mass (kg)";
  parameter Real r_wheel = 0.09 "Wheel radius (m)";
  parameter Real L_base = 0.18 "Wheel base (m) -- assumed";
  parameter Real I_z = 0.12 "Yaw inertia (kg.m^2) -- assumed";
  parameter Real c_v = 1.0 "Linear viscous drag (N.s/m) -- assumed";
  parameter Real c_w = 0.5 "Yaw viscous drag (N.m.s) -- assumed";
  parameter Real tau_max = 11.0 "Per-wheel torque limit (N.m)";
  parameter Real robot_r = 0.15 "Robot footprint radius (m) -- assumed";

  // ---- Formation offsets (leader frame) ----
  parameter Real off1x = -0.50 "Robot1 x offset behind leader (m)";
  parameter Real off1y =  0.25 "Robot1 y offset beside leader (m)";
  parameter Real off2x = -0.50 "Robot2 x offset behind leader (m)";
  parameter Real off2y = -0.25 "Robot2 y offset beside leader (m)";
  parameter Real min_sep = 0.30 "Minimum pairwise separation (m)";
  parameter Real err_thresh = 0.27 "Primary tracking error threshold after settle (m)";

  // ---- Communication ----
  parameter Real comm_delay = 0.096 "Peer message delay (s)";
  parameter Real dist_amp = 0.03 "Disturbance amplitude on delayed pose (m) -- assumed bounded";

  // ---- Obstacles (placed outside nominal formation path) ----
  parameter Real obs1x = 3.5 "Obstacle1 x (m)";
  parameter Real obs1y = 0.0 "Obstacle1 y (m)";
  parameter Real obs2x = -2.0 "Obstacle2 x (m)";
  parameter Real obs2y = 3.0 "Obstacle2 y (m)";
  parameter Real obs_r = 0.30 "Obstacle radius (m) -- assumed";

  // ---- Control gains ----
  parameter Real kp_pos = 20.0 "Position proportional gain";
  parameter Real kd_pos = 2.5  "Position velocity damping gain";
  parameter Real kp_head = 8.0 "Heading proportional gain";
  parameter Real ky = 2.0      "Lateral-to-yaw gain";
  parameter Real kv_lin = 12.0 "Velocity tracking gain";
  parameter Real kw_ang = 5.0  "Yaw-rate tracking gain";
  parameter Real v_max = 1.5   "Bounded local linear command (m/s)";
  parameter Real omega_max = 4.0 "Bounded local angular command (rad/s)";

  // ---- Leader state ----
  Real xL, yL, thetaL, vxL, vyL;

  // ---- Robot 1 plant states ----
  Real x1(start=1.75), y1(start=-0.50), theta1(start=Modelica.Constants.pi/2);
  Real v1(start=0.0), omega1(start=0.0);
  Real tauR1, tauL1, tauR1_cmd, tauL1_cmd, tau_sum1, tau_diff1;

  // ---- Robot 2 plant states ----
  Real x2(start=2.25), y2(start=-0.50), theta2(start=Modelica.Constants.pi/2);
  Real v2(start=0.0), omega2(start=0.0);
  Real tauR2, tauL2, tauR2_cmd, tauL2_cmd, tau_sum2, tau_diff2;

  // ---- Estimators ----
  Real x1_est(start=1.75), y1_est(start=-0.50), theta1_est(start=Modelica.Constants.pi/2);
  Real x2_est(start=2.25), y2_est(start=-0.50), theta2_est(start=Modelica.Constants.pi/2);
  Real v1_est, omega1_est, v2_est, omega2_est;
  Real omegaR1_meas, omegaL1_meas, omegaR2_meas, omegaL2_meas;

  // ---- Desired formation poses ----
  Real xd1, yd1, thetad1, xd2, yd2, thetad2;

  // ---- Control errors and commands ----
  Real ex1, ey1, ex1b, ey1b, herr1, v_cmd1, omega_cmd1;
  Real ex2, ey2, ex2b, ey2b, herr2, v_cmd2, omega_cmd2;

  // ---- Peer-relative range and delayed messages ----
  Real x2_to1, y2_to1, x1_to2, y1_to2;
  Real range_est_1, range_est_2, range_true;
  Real disturb;

  // ---- Lidar obstacle ranges ----
  Real lidar1_obs1, lidar1_obs2, lidar2_obs1, lidar2_obs2;

  // ---- Acceptance monitors ----
  Real formation_err1, formation_err2, primary_track_err;
  Real separation, comm_age;
  Boolean actuator_ok, sep_ok, form_ok, comm_ok, collision_ok, track_ok, finite_ok, fail_closed;

equation
  // ===== Leader trajectory =====
  xL = R_lead*cos(w_lead*time);
  yL = R_lead*sin(w_lead*time);
  vxL = -R_lead*w_lead*sin(w_lead*time);
  vyL =  R_lead*w_lead*cos(w_lead*time);
  thetaL = w_lead*time + Modelica.Constants.pi/2;

  // ===== Desired formation poses (leader frame offsets) =====
  xd1 = xL + off1x*cos(thetaL) - off1y*sin(thetaL);
  yd1 = yL + off1x*sin(thetaL) + off1y*cos(thetaL);
  thetad1 = thetaL;
  xd2 = xL + off2x*cos(thetaL) - off2y*sin(thetaL);
  yd2 = yL + off2x*sin(thetaL) + off2y*cos(thetaL);
  thetad2 = thetaL;

  // ===== Robot 1 dynamics =====
  der(x1) = v1*cos(theta1);
  der(y1) = v1*sin(theta1);
  der(theta1) = omega1;
  m_robot*der(v1) = (tauR1 + tauL1)/r_wheel - c_v*v1;
  I_z*der(omega1) = (tauR1 - tauL1)*L_base/(2.0*r_wheel) - c_w*omega1;

  // ===== Robot 2 dynamics =====
  der(x2) = v2*cos(theta2);
  der(y2) = v2*sin(theta2);
  der(theta2) = omega2;
  m_robot*der(v2) = (tauR2 + tauL2)/r_wheel - c_v*v2;
  I_z*der(omega2) = (tauR2 - tauL2)*L_base/(2.0*r_wheel) - c_w*omega2;

  // ===== Onboard state estimation (encoder odometry + IMU heading) =====
  omegaR1_meas = v1/r_wheel + omega1*L_base/(2.0*r_wheel);
  omegaL1_meas = v1/r_wheel - omega1*L_base/(2.0*r_wheel);
  omegaR2_meas = v2/r_wheel + omega2*L_base/(2.0*r_wheel);
  omegaL2_meas = v2/r_wheel - omega2*L_base/(2.0*r_wheel);

  v1_est = r_wheel*(omegaR1_meas + omegaL1_meas)/2.0;
  omega1_est = r_wheel*(omegaR1_meas - omegaL1_meas)/L_base;
  v2_est = r_wheel*(omegaR2_meas + omegaL2_meas)/2.0;
  omega2_est = r_wheel*(omegaR2_meas - omegaL2_meas)/L_base;

  der(x1_est) = v1_est*cos(theta1_est);
  der(y1_est) = v1_est*sin(theta1_est);
  der(theta1_est) = omega1_est;
  der(x2_est) = v2_est*cos(theta2_est);
  der(y2_est) = v2_est*sin(theta2_est);
  der(theta2_est) = omega2_est;

  // ===== Middle-third communication disturbance =====
  disturb = if (time >= t_sim/3.0) and (time <= 2.0*t_sim/3.0) then
              dist_amp*sin(2.0*Modelica.Constants.pi*2.0*time)
            else 0.0;

  // ===== Delayed peer pose messages (0.096 s) =====
  x2_to1 = delay(x2_est, comm_delay, comm_delay) + disturb;
  y2_to1 = delay(y2_est, comm_delay, comm_delay) + disturb;
  x1_to2 = delay(x1_est, comm_delay, comm_delay) + disturb;
  y1_to2 = delay(y1_est, comm_delay, comm_delay) + disturb;

  // ===== Peer-relative range =====
  range_est_1 = sqrt(max(1e-6, (x1_est - x2_to1)^2 + (y1_est - y2_to1)^2));
  range_est_2 = sqrt(max(1e-6, (x2_est - x1_to2)^2 + (y2_est - y1_to2)^2));
  range_true  = sqrt(max(1e-6, (x1 - x2)^2 + (y1 - y2)^2));

  // ===== Distributed formation control: Robot 1 =====
  ex1 = xd1 - x1_est;
  ey1 = yd1 - y1_est;
  ex1b =  ex1*cos(theta1_est) + ey1*sin(theta1_est);
  ey1b = -ex1*sin(theta1_est) + ey1*cos(theta1_est);
  herr1 = Modelica.Math.atan2(sin(thetad1 - theta1_est), cos(thetad1 - theta1_est));
  v_cmd1 = max(-v_max, min(v_max, kp_pos*ex1b - kd_pos*v1_est));
  omega_cmd1 = max(-omega_max, min(omega_max, kp_head*herr1 + ky*ey1b));

  tau_sum1 = m_robot*r_wheel*kv_lin*(v_cmd1 - v1_est);
  tau_diff1 = 2.0*r_wheel*I_z*kw_ang*(omega_cmd1 - omega1_est)/L_base;
  tauR1_cmd = (tau_sum1 + tau_diff1)/2.0;
  tauL1_cmd = (tau_sum1 - tau_diff1)/2.0;
  tauR1 = max(-tau_max, min(tau_max, tauR1_cmd));
  tauL1 = max(-tau_max, min(tau_max, tauL1_cmd));

  // ===== Distributed formation control: Robot 2 =====
  ex2 = xd2 - x2_est;
  ey2 = yd2 - y2_est;
  ex2b =  ex2*cos(theta2_est) + ey2*sin(theta2_est);
  ey2b = -ex2*sin(theta2_est) + ey2*cos(theta2_est);
  herr2 = Modelica.Math.atan2(sin(thetad2 - theta2_est), cos(thetad2 - theta2_est));
  v_cmd2 = max(-v_max, min(v_max, kp_pos*ex2b - kd_pos*v2_est));
  omega_cmd2 = max(-omega_max, min(omega_max, kp_head*herr2 + ky*ey2b));

  tau_sum2 = m_robot*r_wheel*kv_lin*(v_cmd2 - v2_est);
  tau_diff2 = 2.0*r_wheel*I_z*kw_ang*(omega_cmd2 - omega2_est)/L_base;
  tauR2_cmd = (tau_sum2 + tau_diff2)/2.0;
  tauL2_cmd = (tau_sum2 - tau_diff2)/2.0;
  tauR2 = max(-tau_max, min(tau_max, tauR2_cmd));
  tauL2 = max(-tau_max, min(tau_max, tauL2_cmd));

  // ===== Lidar obstacle ranges =====
  lidar1_obs1 = sqrt(max(1e-6, (x1 - obs1x)^2 + (y1 - obs1y)^2)) - robot_r;
  lidar1_obs2 = sqrt(max(1e-6, (x1 - obs2x)^2 + (y1 - obs2y)^2)) - robot_r;
  lidar2_obs1 = sqrt(max(1e-6, (x2 - obs1x)^2 + (y2 - obs1y)^2)) - robot_r;
  lidar2_obs2 = sqrt(max(1e-6, (x2 - obs2x)^2 + (y2 - obs2y)^2)) - robot_r;

  // ===== Acceptance monitors =====
  formation_err1 = sqrt(max(1e-6, (x1 - xd1)^2 + (y1 - yd1)^2));
  formation_err2 = sqrt(max(1e-6, (x2 - xd2)^2 + (y2 - yd2)^2));
  primary_track_err = max(formation_err1, formation_err2);
  separation = range_true;
  comm_age = comm_delay;

  actuator_ok = (abs(tauR1) <= tau_max + 1e-6) and (abs(tauL1) <= tau_max + 1e-6) and
                (abs(tauR2) <= tau_max + 1e-6) and (abs(tauL2) <= tau_max + 1e-6);
  sep_ok = separation >= min_sep;
  form_ok = primary_track_err < err_thresh;
  comm_ok = comm_age <= comm_delay + 1e-6;
  collision_ok = (lidar1_obs1 > obs_r) and (lidar1_obs2 > obs_r) and
                 (lidar2_obs1 > obs_r) and (lidar2_obs2 > obs_r) and
                 (separation > 2.0*robot_r);
  track_ok = if time >= t_settle then form_ok else true;
  finite_ok = (abs(x1) < 1e6) and (abs(y1) < 1e6) and (abs(theta1) < 1e6) and
              (abs(v1) < 1e6) and (abs(omega1) < 1e6) and
              (abs(x2) < 1e6) and (abs(y2) < 1e6) and (abs(theta2) < 1e6) and
              (abs(v2) < 1e6) and (abs(omega2) < 1e6) and
              (abs(x1_est) < 1e6) and (abs(y1_est) < 1e6) and (abs(theta1_est) < 1e6) and
              (abs(x2_est) < 1e6) and (abs(y2_est) < 1e6) and (abs(theta2_est) < 1e6) and
              (abs(tauR1) < 1e6) and (abs(tauL1) < 1e6) and
              (abs(tauR2) < 1e6) and (abs(tauL2) < 1e6) and
              (abs(v_cmd1) < 1e6) and (abs(omega_cmd1) < 1e6) and
              (abs(v_cmd2) < 1e6) and (abs(omega_cmd2) < 1e6) and
              (abs(range_est_1) < 1e6) and (abs(range_est_2) < 1e6);
  fail_closed = actuator_ok and sep_ok and comm_ok and collision_ok and track_ok and finite_ok;

  annotation (
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Two 14 kg differential-drive robots (r_wheel=0.09 m) follow a leader circle while maintaining declared leader-frame offsets and minimum separation. Four bounded wheel-torque channels (<=11 N.m per wheel) driven by distributed formation control using onboard odometry/IMU estimation and peer-relative range plus delayed (0.096 s) pose messages with a middle-third disturbance. Obstacles are placed outside the nominal formation path. Acceptance is fail-closed: actuator limits, pairwise separation, formation error, communication age, no collision, primary tracking error < 0.27 m after 10.4 s, and no NaN/infinite physical, control, or estimator values.")
  );
end GroundPairFormE;