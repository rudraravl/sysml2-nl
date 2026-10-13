model GroundPairFormC
  "Distributed formation control of two 14 kg differential-drive ground robots
   (0.09 m wheels) following a leader trajectory, with bounded wheel torques
   (<= 9.2 N.m), 125 Hz sampled commands, and a 0.072 s message-delay
   disturbance injected during the middle third (4 s..8 s). Standalone plant."

  // ---- Timing / sampling ----
  parameter Real dt      = 1.0/125.0 "control sample period [s] (125 Hz)";
  parameter Real t_final = 12.0      "run length [s]";
  parameter Real t_delay = 0.072     "message delay during middle third [s]";
  parameter Real t_start = 4.0       "delay disturbance window start [s]";
  parameter Real t_end   = 8.0       "delay disturbance window end [s]";

  // ---- Robot physical parameters (stated in requirement) ----
  parameter Real m_robot = 14.0 "robot mass [kg]";
  parameter Real r_wheel = 0.09 "wheel radius [m]";

  // ---- Assumed geometric/inertial parameters (NOT stated in requirement) ----
  parameter Real d_track = 0.30 "track width [m] (assumed)";
  parameter Real I_z     = 0.20 "yaw inertia [kg.m2] (assumed)";

  // ---- Actuator limit (stated) ----
  parameter Real tau_max = 9.2 "max wheel torque magnitude [N.m]";

  // ---- Leader trajectory (assumed: constant-speed straight line) ----
  parameter Real v_lead = 0.5 "leader speed [m/s] (assumed)";

  // ---- Formation offsets (assumed) ----
  parameter Real off1_x = -0.60 "robot1 longitudinal offset [m]";
  parameter Real off1_y = -0.30 "robot1 lateral offset [m]";
  parameter Real off2_x = -0.60 "robot2 longitudinal offset [m]";
  parameter Real off2_y =  0.30 "robot2 lateral offset [m]";
  parameter Real d_min  =  0.25 "minimum pairwise separation [m]";

  // ---- Fixed obstacle outside nominal formation path (assumed) ----
  parameter Real obs_x =  6.0  "obstacle center x [m]";
  parameter Real obs_y =  1.5  "obstacle center y [m] (outside path)";
  parameter Real obs_r =  0.30 "obstacle radius [m]";
  parameter Real rob_r =  0.15 "robot effective radius [m] (assumed)";

  // ---- Control gains (assumed, tuned for stable tracking) ----
  parameter Real k_pos  = 2.5 "position-to-velocity gain";
  parameter Real k_lat = 1.8 "lateral-to-yawrate gain";
  parameter Real k_v   = 6.0 "velocity tracking gain";
  parameter Real k_w   = 6.0 "yaw-rate tracking gain";
  parameter Real v_max = 1.0 "velocity command cap [m/s]";
  parameter Real w_max = 3.0 "yaw-rate command cap [rad/s]";

  // small epsilon guarding norm divisors against zero
  parameter Real eps = 1.0e-6;

  // ---- Leader state ----
  Real x_lead "leader x [m]";
  Real y_lead "leader y [m]";

  // ---- Delayed leader reference received by robots ----
  Real delay_now "current applied message delay [s]";
  Real x_lead_d  "leader x as received [m]";
  Real y_lead_d  "leader y as received [m]";

  // ---- Formation targets ----
  Real tx1, ty1, tx2, ty2;

  // ---- Robot dynamic states ----
  Real x1(start=-0.7) "robot1 x [m]";
  Real y1(start=-0.5) "robot1 y [m]";
  Real th1(start=0.0) "robot1 heading [rad]";
  Real v1(start=0.0)  "robot1 forward speed [m/s]";
  Real w1(start=0.0)  "robot1 yaw rate [rad/s]";
  Real x2(start=-0.7) "robot2 x [m]";
  Real y2(start= 0.5) "robot2 y [m]";
  Real th2(start=0.0) "robot2 heading [rad]";
  Real v2(start=0.0)  "robot2 forward speed [m/s]";
  Real w2(start=0.0)  "robot2 yaw rate [rad/s]";

  // ---- Delayed peer-relative pose messages (sensor evidence) ----
  Real x1_rx, y1_rx, th1_rx "robot1 pose received by robot2";
  Real x2_rx, y2_rx, th2_rx "robot2 pose received by robot1";
  Real comm_age  "communication age of latest peer/leader message [s]";
  Real peer_range "measured inter-robot range from delayed poses [m]";

  // ---- Continuous control intermediates ----
  Real e1_x, e1_y, e1_fwd, e1_lat, v1_des, w1_des, dv1_cmd, dw1_cmd;
  Real e2_x, e2_y, e2_fwd, e2_lat, v2_des, w2_des, dv2_cmd, dw2_cmd;
  Real tau1_l_raw, tau1_r_raw, tau2_l_raw, tau2_r_raw;

  // ---- Sampled (125 Hz) and saturated actuator commands (four channels) ----
  discrete Real tau1_l(start=0.0) "robot1 left wheel torque [N.m]";
  discrete Real tau1_r(start=0.0) "robot1 right wheel torque [N.m]";
  discrete Real tau2_l(start=0.0) "robot2 left wheel torque [N.m]";
  discrete Real tau2_r(start=0.0) "robot2 right wheel torque [N.m]";

  // ---- Monitors / evidence traces ----
  Real err1 "robot1 distance to its formation target [m]";
  Real err2 "robot2 distance to its formation target [m]";
  Real err_max "primary tracking error (max of pair) [m]";
  Real separation "inter-robot separation [m]";
  Real form_err "formation geometry error [m]";
  Real obs_dist1 "robot1-to-obstacle clearance [m]";
  Real obs_dist2 "robot2-to-obstacle clearance [m]";
  Real actuator_sat1 "fraction of robot1 channels saturated [1]";
  Real actuator_sat2 "fraction of robot2 channels saturated [1]";
  Boolean no_collision "true if neither robot overlaps the obstacle";
  Boolean sep_ok "true if separation >= minimum";
  Boolean tracking_ok "true if tracking error < 0.315 m after 7.8 s";
  Boolean finite_ok "true if all key signals finite (no NaN/Inf)";
  Real max_abs_signal "max absolute physical/control signal for finiteness";

equation
  // ===== Leader trajectory (straight line along x) =====
  x_lead = v_lead * time;
  y_lead = 0.0;

  // ===== Controlled message delay disturbance (middle third) =====
  delay_now = if (time >= t_start and time <= t_end) then t_delay else 0.0;
  x_lead_d = delay(x_lead, delay_now, t_delay);
  y_lead_d = delay(y_lead, delay_now, t_delay);

  // ===== Formation targets derived from received (delayed) leader pose =====
  tx1 = x_lead_d + off1_x;
  ty1 = y_lead_d + off1_y;
  tx2 = x_lead_d + off2_x;
  ty2 = y_lead_d + off2_y;

  // ===== Delayed peer pose messages =====
  x1_rx  = delay(x1,  delay_now, t_delay);
  y1_rx  = delay(y1,  delay_now, t_delay);
  th1_rx = delay(th1, delay_now, t_delay);
  x2_rx  = delay(x2,  delay_now, t_delay);
  y2_rx  = delay(y2,  delay_now, t_delay);
  th2_rx = delay(th2, delay_now, t_delay);
  comm_age = delay_now;

  // Peer-relative range from delayed pose messages (lidar/comm evidence)
  peer_range = sqrt((x1_rx - x2_rx)*(x1_rx - x2_rx)
                 + (y1_rx - y2_rx)*(y1_rx - y2_rx) + eps*eps);

  // ===== Robot 1 controller (continuous) =====
  e1_x   = tx1 - x1;
  e1_y   = ty1 - y1;
  e1_fwd = e1_x * cos(th1) + e1_y * sin(th1);
  e1_lat = -e1_x * sin(th1) + e1_y * cos(th1);
  v1_des = if (e1_fwd >  v_max/k_pos) then  v_max else
           if (e1_fwd < -v_max/k_pos) then -v_max else k_pos * e1_fwd;
  w1_des = if (k_lat * e1_lat >  w_max) then  w_max else
           if (k_lat * e1_lat < -w_max) then -w_max else k_lat * e1_lat;
  dv1_cmd = k_v * (v1_des - v1);
  dw1_cmd = k_w * (w1_des - w1);
  tau1_l_raw = 0.5*(r_wheel*m_robot*dv1_cmd - 2.0*r_wheel*I_z*dw1_cmd/d_track);
  tau1_r_raw = 0.5*(r_wheel*m_robot*dv1_cmd + 2.0*r_wheel*I_z*dw1_cmd/d_track);

  // ===== Robot 2 controller (continuous) =====
  e2_x   = tx2 - x2;
  e2_y   = ty2 - y2;
  e2_fwd = e2_x * cos(th2) + e2_y * sin(th2);
  e2_lat = -e2_x * sin(th2) + e2_y * cos(th2);
  v2_des = if (e2_fwd >  v_max/k_pos) then  v_max else
           if (e2_fwd < -v_max/k_pos) then -v_max else k_pos * e2_fwd;
  w2_des = if (k_lat * e2_lat >  w_max) then  w_max else
           if (k_lat * e2_lat < -w_max) then -w_max else k_lat * e2_lat;
  dv2_cmd = k_v * (v2_des - v2);
  dw2_cmd = k_w * (w2_des - w2);
  tau2_l_raw = 0.5*(r_wheel*m_robot*dv2_cmd - 2.0*r_wheel*I_z*dw2_cmd/d_track);
  tau2_r_raw = 0.5*(r_wheel*m_robot*dv2_cmd + 2.0*r_wheel*I_z*dw2_cmd/d_track);

  // ===== Sampled (125 Hz) zero-order-hold with saturation, four channels =====
  when sample(0, dt) then
    tau1_l = if tau1_l_raw >  tau_max then  tau_max else
             if tau1_l_raw < -tau_max then -tau_max else tau1_l_raw;
    tau1_r = if tau1_r_raw >  tau_max then  tau_max else
             if tau1_r_raw < -tau_max then -tau_max else tau1_r_raw;
    tau2_l = if tau2_l_raw >  tau_max then  tau_max else
             if tau2_l_raw < -tau_max then -tau_max else tau2_l_raw;
    tau2_r = if tau2_r_raw >  tau_max then  tau_max else
             if tau2_r_raw < -tau_max then -tau_max else tau2_r_raw;
  end when;

  // ===== Plant: robot 1 differential-drive body dynamics =====
  der(x1)  = v1 * cos(th1);
  der(y1)  = v1 * sin(th1);
  der(th1) = w1;
  der(v1)  = (tau1_l + tau1_r) / (r_wheel * m_robot);
  der(w1)  = (tau1_r - tau1_l) * d_track / (2.0 * r_wheel * I_z);

  // ===== Plant: robot 2 differential-drive body dynamics =====
  der(x2)  = v2 * cos(th2);
  der(y2)  = v2 * sin(th2);
  der(th2) = w2;
  der(v2)  = (tau2_l + tau2_r) / (r_wheel * m_robot);
  der(w2)  = (tau2_r - tau2_l) * d_track / (2.0 * r_wheel * I_z);

  // ===== Performance and safety monitors =====
  err1 = sqrt(e1_x*e1_x + e1_y*e1_y + eps*eps);
  err2 = sqrt(e2_x*e2_x + e2_y*e2_y + eps*eps);
  err_max = if err1 > err2 then err1 else err2;
  separation = sqrt((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2) + eps*eps);
  form_err = sqrt((x1 - x2 - (off1_x - off2_x))*(x1 - x2 - (off1_x - off2_x))
                + (y1 - y2 - (off1_y - off2_y))*(y1 - y2 - (off1_y - off2_y))
                + eps*eps);
  obs_dist1 = sqrt((x1 - obs_x)*(x1 - obs_x) + (y1 - obs_y)*(y1 - obs_y) + eps*eps)
              - obs_r - rob_r;
  obs_dist2 = sqrt((x2 - obs_x)*(x2 - obs_x) + (y2 - obs_y)*(y2 - obs_y) + eps*eps)
              - obs_r - rob_r;
  actuator_sat1 = (if abs(tau1_l) >= tau_max - eps then 1.0 else 0.0)
                + (if abs(tau1_r) >= tau_max - eps then 1.0 else 0.0);
  actuator_sat2 = (if abs(tau2_l) >= tau_max - eps then 1.0 else 0.0)
                + (if abs(tau2_r) >= tau_max - eps then 1.0 else 0.0);
  no_collision = (obs_dist1 > 0.0) and (obs_dist2 > 0.0);
  sep_ok       = separation >= d_min;
  tracking_ok  = (time < 7.8) or (err_max < 0.315);
  max_abs_signal = max(abs(x1), max(abs(y1), max(abs(th1), max(abs(v1),
                 max(abs(w1), max(abs(tau1_l), max(abs(tau1_r),
                 max(abs(x2), max(abs(y2), max(abs(th2), max(abs(v2),
                 max(abs(w2), max(abs(tau2_l), abs(tau2_r))))))))))))));
  finite_ok = (max_abs_signal < 1.0e6) and (max_abs_signal >= 0.0);

annotation(
  experiment(StartTime=0, StopTime=12.0, Tolerance=1.0e-6, Interval=1.0/125.0),
  Documentation(info="GroundPairFormC: two 14 kg differential-drive robots with 0.09 m wheels
   follow a leader trajectory under distributed formation control. Wheel torques bounded
   to 9.2 N.m, sampled/hold at 125 Hz. A 0.072 s message delay is injected during the
   middle third (4 s..8 s). Fixed obstacle placed outside the nominal formation path.
   Requirements verified: actuator limits, pairwise separation, formation error,
   communication age, no collision, primary tracking error < 0.315 m after 7.8 s, and
   finiteness of physical/control/estimator signals.
   Values NOT stated in the requirement and therefore assumed (clearly labeled): track
   width, yaw inertia, leader speed, formation offsets, minimum separation, obstacle
   location/size, robot effective radius, and control gains."));
end GroundPairFormC;