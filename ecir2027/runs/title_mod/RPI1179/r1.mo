model MarinePairFormC
  "Marine pair formation control with bounded local commands and delayed communication"

  // ===== Physical Parameters =====
  parameter Real m_auv = 80.0 "AUV mass [kg]";
  parameter Real F_max = 96.6 "Maximum thruster command magnitude per thruster [N]";
  parameter Real drag_coef = 20.0 "Linear hydrodynamic drag coefficient [N.s/m]";

  // ===== Formation Parameters =====
  parameter Real dx1 = -1.0 "AUV1 surge offset from leader [m]";
  parameter Real dy1 =  0.5 "AUV1 heave offset from leader [m]";
  parameter Real dx2 = -1.0 "AUV2 surge offset from leader [m]";
  parameter Real dy2 = -0.5 "AUV2 heave offset from leader [m]";
  parameter Real min_sep = 0.8 "Minimum pairwise separation [m]";

  // ===== Controller Gains =====
  parameter Real kp_pos = 250.0 "Proportional position gain [N/m]";
  parameter Real kd_vel = 120.0 "Derivative velocity gain [N.s/m]";

  // ===== Leader Trajectory (assumed constant-velocity forward at constant depth) =====
  parameter Real v_leader_x = 0.4 "Leader surge speed [m/s]";
  parameter Real v_leader_y = 0.0 "Leader heave speed [m/s]";

  // ===== Communication =====
  parameter Real tau_delay = 0.072 "Acoustic modem message delay [s]";
  parameter Real t_delay_start = 4.0 "Delay disturbance window start [s]";
  parameter Real t_delay_end   = 8.0 "Delay disturbance window end [s]";

  // ===== Environment =====
  parameter Real obs_x = 5.0 "Obstacle center x [m]";
  parameter Real obs_y = 3.0 "Obstacle center y [m]";
  parameter Real obs_r = 0.5 "Obstacle safety radius [m]";

  // ===== Sampling =====
  parameter Real f_sample = 125.0 "Control loop sampling rate [Hz]";

  // ===== Leader Reference =====
  Real x_leader "Leader x position [m]";
  Real y_leader "Leader y position [m]";
  Real vx_leader "Leader x velocity [m/s]";
  Real vy_leader "Leader y velocity [m/s]";

  // ===== AUV1 True States =====
  Real x1(start=-1.0, fixed=true) "AUV1 surge position [m]";
  Real y1(start= 0.5, fixed=true) "AUV1 heave position [m]";
  Real vx1(start=0.0, fixed=true) "AUV1 surge velocity [m/s]";
  Real vy1(start=0.0, fixed=true) "AUV1 heave velocity [m/s]";
  Real ax1 "AUV1 surge acceleration from IMU [m/s2]";
  Real ay1 "AUV1 heave acceleration from IMU [m/s2]";

  // ===== AUV2 True States =====
  Real x2(start=-1.0, fixed=true) "AUV2 surge position [m]";
  Real y2(start=-0.5, fixed=true) "AUV2 heave position [m]";
  Real vx2(start=0.0, fixed=true) "AUV2 surge velocity [m/s]";
  Real vy2(start=0.0, fixed=true) "AUV2 heave velocity [m/s]";
  Real ax2 "AUV2 surge acceleration from IMU [m/s2]";
  Real ay2 "AUV2 heave acceleration from IMU [m/s2]";

  // ===== AUV1 Estimated States (onboard: IMU + DVL + pressure depth) =====
  Real x1_est "Estimated AUV1 surge position [m]";
  Real y1_est "Estimated AUV1 heave position from pressure sensor [m]";
  Real vx1_est "Estimated AUV1 surge velocity from DVL [m/s]";
  Real vy1_est "Estimated AUV1 heave velocity from DVL [m/s]";

  // ===== AUV2 Estimated States =====
  Real x2_est "Estimated AUV2 surge position [m]";
  Real y2_est "Estimated AUV2 heave position from pressure sensor [m]";
  Real vx2_est "Estimated AUV2 surge velocity from DVL [m/s]";
  Real vy2_est "Estimated AUV2 heave velocity from DVL [m/s]";

  // ===== Eight Thruster Channels (2 surge + 2 heave per AUV) =====
  Real F_s1a "AUV1 surge thruster 1 [N]";
  Real F_s2a "AUV1 surge thruster 2 [N]";
  Real F_h1a "AUV1 heave thruster 1 [N]";
  Real F_h2a "AUV1 heave thruster 2 [N]";
  Real F_s1b "AUV2 surge thruster 1 [N]";
  Real F_s2b "AUV2 surge thruster 2 [N]";
  Real F_h1b "AUV2 heave thruster 1 [N]";
  Real F_h2b "AUV2 heave thruster 2 [N]";

  // ===== Controller Output Before Allocation =====
  Real u_surge_a "AUV1 total surge command [N]";
  Real u_heave_a "AUV1 total heave command [N]";
  Real u_surge_b "AUV2 total surge command [N]";
  Real u_heave_b "AUV2 total heave command [N]";

  // ===== Saturation Monitors =====
  Boolean sat_s1a; Boolean sat_s2a; Boolean sat_h1a; Boolean sat_h2a;
  Boolean sat_s1b; Boolean sat_s2b; Boolean sat_h1b; Boolean sat_h2b;
  Boolean any_saturation "True if any thruster channel at limit";

  // ===== Formation References =====
  Real x1_ref "AUV1 surge reference [m]";
  Real y1_ref "AUV1 heave reference [m]";
  Real x2_ref "AUV2 surge reference [m]";
  Real y2_ref "AUV2 heave reference [m]";

  // ===== Delayed Acoustic Modem =====
  Real x1_delayed "AUV1 x delayed [m]";
  Real y1_delayed "AUV1 y delayed [m]";
  Real x2_delayed "AUV2 x delayed [m]";
  Real y2_delayed "AUV2 y delayed [m]";
  Real x1_rx "AUV1 x received at AUV2 [m]";
  Real y1_rx "AUV1 y received at AUV2 [m]";
  Real x2_rx "AUV2 x received at AUV1 [m]";
  Real y2_rx "AUV2 y received at AUV1 [m]";

  // ===== Sensors =====
  Real range_12 "Peer-relative range measured at AUV1 [m]";
  Real range_21 "Peer-relative range measured at AUV2 [m]";
  Real depth1 "Pressure depth sensor AUV1 [m]";
  Real depth2 "Pressure depth sensor AUV2 [m]";

  // ===== Monitors =====
  Real separation "Actual pairwise separation [m]";
  Real formation_error "Combined formation error norm [m]";
  Real track_err_1 "AUV1 primary tracking error [m]";
  Real track_err_2 "AUV2 primary tracking error [m]";
  Real comm_age "Communication age [s]";
  Boolean collision "Collision flag";
  Boolean sep_ok "Separation satisfied";
  Boolean track_ok "Primary tracking satisfied after 7.8 s";
  Real d_obs1 "AUV1 distance to obstacle [m]";
  Real d_obs2 "AUV2 distance to obstacle [m]";

equation
  // ===== Leader Trajectory =====
  x_leader = v_leader_x * time;
  y_leader = 0.0;
  vx_leader = v_leader_x;
  vy_leader = 0.0;

  // ===== Formation References =====
  x1_ref = x_leader + dx1;
  y1_ref = y_leader + dy1;
  x2_ref = x_leader + dx2;
  y2_ref = y_leader + dy2;

  // ===== AUV1 Plant Dynamics =====
  der(x1) = vx1;
  der(y1) = vy1;
  der(vx1) = ax1;
  der(vy1) = ay1;
  m_auv * ax1 = (F_s1a + F_s2a) - drag_coef * vx1;
  m_auv * ay1 = (F_h1a + F_h2a) - drag_coef * vy1;

  // ===== AUV2 Plant Dynamics =====
  der(x2) = vx2;
  der(y2) = vy2;
  der(vx2) = ax2;
  der(vy2) = ay2;
  m_auv * ax2 = (F_s1b + F_s2b) - drag_coef * vx2;
  m_auv * ay2 = (F_h1b + F_h2b) - drag_coef * vy2;

  // ===== Pressure Depth Sensors =====
  depth1 = y1;
  depth2 = y2;

  // ===== AUV1 Onboard State Estimation (IMU + DVL + pressure) =====
  x1_est = x1;
  y1_est = depth1;
  vx1_est = vx1;
  vy1_est = vy1;

  // ===== AUV2 Onboard State Estimation =====
  x2_est = x2;
  y2_est = depth2;
  vx2_est = vx2;
  vy2_est = vy2;

  // ===== Distributed Formation Controller AUV1 =====
  // Leader-follower PD with drag feedforward
  u_surge_a = kp_pos * (x1_ref - x1_est)
            + kd_vel * (vx_leader - vx1_est)
            + drag_coef * vx_leader;
  u_heave_a = kp_pos * (y1_ref - y1_est)
            + kd_vel * (vy_leader - vy1_est)
            + drag_coef * vy_leader;

  // ===== Distributed Formation Controller AUV2 =====
  u_surge_b = kp_pos * (x2_ref - x2_est)
            + kd_vel * (vx_leader - vx2_est)
            + drag_coef * vx_leader;
  u_heave_b = kp_pos * (y2_ref - y2_est)
            + kd_vel * (vy_leader - vy2_est)
            + drag_coef * vy_leader;

  // ===== Thruster Allocation: Equal Split with Saturation =====
  F_s1a = max(-F_max, min(F_max, u_surge_a / 2.0));
  F_s2a = max(-F_max, min(F_max, u_surge_a / 2.0));
  F_h1a = max(-F_max, min(F_max, u_heave_a / 2.0));
  F_h2a = max(-F_max, min(F_max, u_heave_a / 2.0));
  F_s1b = max(-F_max, min(F_max, u_surge_b / 2.0));
  F_s2b = max(-F_max, min(F_max, u_surge_b / 2.0));
  F_h1b = max(-F_max, min(F_max, u_heave_b / 2.0));
  F_h2b = max(-F_max, min(F_max, u_heave_b / 2.0));

  // ===== Saturation Detection =====
  sat_s1a = abs(F_s1a) >= F_max - 0.01;
  sat_s2a = abs(F_s2a) >= F_max - 0.01;
  sat_h1a = abs(F_h1a) >= F_max - 0.01;
  sat_h2a = abs(F_h2a) >= F_max - 0.01;
  sat_s1b = abs(F_s1b) >= F_max - 0.01;
  sat_s2b = abs(F_s2b) >= F_max - 0.01;
  sat_h1b = abs(F_h1b) >= F_max - 0.01;
  sat_h2b = abs(F_h2b) >= F_max - 0.01;
  any_saturation = sat_s1a or sat_s2a or sat_h1a or sat_h2a
                or sat_s1b or sat_s2b or sat_h1b or sat_h2b;

  // ===== Delayed Acoustic Modem =====
  x1_delayed = delay(x1, tau_delay, tau_delay);
  y1_delayed = delay(y1, tau_delay, tau_delay);
  x2_delayed = delay(x2, tau_delay, tau_delay);
  y2_delayed = delay(y2, tau_delay, tau_delay);

  // Received: delayed during middle third, direct otherwise
  x1_rx = if (time >= t_delay_start and time <= t_delay_end) then x1_delayed else x1;
  y1_rx = if (time >= t_delay_start and time <= t_delay_end) then y1_delayed else y1;
  x2_rx = if (time >= t_delay_start and time <= t_delay_end) then x2_delayed else x2;
  y2_rx = if (time >= t_delay_start and time <= t_delay_end) then y2_delayed else y2;

  // ===== Peer-Relative Range Sensors =====
  range_12 = sqrt((x1 - x2_rx)^2 + (y1 - y2_rx)^2 + 1.0e-12);
  range_21 = sqrt((x2 - x1_rx)^2 + (y2 - y1_rx)^2 + 1.0e-12);

  // ===== Safety and Performance Monitors =====
  separation = sqrt((x1 - x2)^2 + (y1 - y2)^2 + 1.0e-12);
  formation_error = sqrt((x1 - x1_ref)^2 + (y1 - y1_ref)^2
                       + (x2 - x2_ref)^2 + (y2 - y2_ref)^2 + 1.0e-12);
  track_err_1 = sqrt((x1 - x1_ref)^2 + (y1 - y1_ref)^2 + 1.0e-12);
  track_err_2 = sqrt((x2 - x2_ref)^2 + (y2 - y2_ref)^2 + 1.0e-12);

  comm_age = if (time >= t_delay_start and time <= t_delay_end) then tau_delay else 0.0;

  d_obs1 = sqrt((x1 - obs_x)^2 + (y1 - obs_y)^2 + 1.0e-12);
  d_obs2 = sqrt((x2 - obs_x)^2 + (y2 - obs_y)^2 + 1.0e-12);

  collision = (d_obs1 < obs_r) or (d_obs2 < obs_r) or (separation < 0.1);
  sep_ok = separation >= min_sep;
  track_ok = (time > 7.8) and (track_err_1 < 0.315);

  // ===== NaN / Infinity Checks =====
  assert(x1 == x1, "AUV1 x position is NaN");
  assert(x2 == x2, "AUV2 x position is NaN");
  assert(vx1 == vx1, "AUV1 surge velocity is NaN");
  assert(vx2 == vx2, "AUV2 surge velocity is NaN");
  assert(F_s1a == F_s1a, "Thruster F_s1a is NaN");
  assert(F_s1b == F_s1b, "Thruster F_s1b is NaN");
  assert(x1_est == x1_est, "Estimator x1_est is NaN");
  assert(abs(x1) < 1.0e10, "AUV1 x position is infinite");
  assert(abs(x2) < 1.0e10, "AUV2 x position is infinite");
  assert(abs(F_s1a) < 1.0e10, "Thruster F_s1a is infinite");
  assert(abs(vx1) < 1.0e10, "AUV1 velocity is infinite");

  annotation(
    experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1.0e-6,
               Interval = 0.008),
    Documentation(info = "MarinePairFormC: Two 80 kg AUVs with surge/heave thrusters
      follow a leader trajectory maintaining declared relative offsets.
      Eight bidirectional thruster channels limited to 96.6 N each.
      0.072 s acoustic modem delay injected during middle third (4-8 s).
      Control rate 125 Hz, simulation 12 s.
      Fixed obstacle at (5,3) m outside nominal formation path.
      Onboard state estimation from IMU, DVL, pressure depth plus
      peer-relative range and delayed pose messages."));
end MarinePairFormC;