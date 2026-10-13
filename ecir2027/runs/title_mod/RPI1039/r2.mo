model TrackCrawlerClimbA
  // ===== Hull and track parameters =====
  parameter Real m_hull = 52.0 "Hull mass [kg]";
  parameter Real L_hull = 1.1 "Hull length [m]";
  parameter Real r_sprocket = 0.14 "Effective sprocket radius [m]";
  parameter Real track_sep = 0.50 "Track separation [m]";
  parameter Real tau_max = 30.2 "Track command magnitude limit [N.m]";
  parameter Real mu = 0.76 "Friction coefficient [-]";
  parameter Real J_track = 0.10 "Track rotational inertia per side [kg.m2]";
  parameter Real J_pitch = 8.0 "Pitch inertia [kg.m2]";
  parameter Real k_pitch = 200.0 "Pitch tracking gain [N.m/rad]";
  parameter Real c_pitch = 30.0 "Pitch damping [N.m.s/rad]";
  parameter Real tau_roll = 0.4 "Roll time constant [s]";
  parameter Real k_roll = 0.02 "Roll coupling [rad/(N.m.s)]";
  parameter Real tau_act_tau = 0.06 "Actuator torque filter time constant [s]";

  // ===== Scenario geometry =====
  parameter Real ramp_angle_deg = 12.0 "Ramp inclination [deg]";
  parameter Real s_ramp_start = 0.50 "Ramp start position [m]";
  parameter Real s_plateau_start = 1.20 "Plateau start position [m]";
  parameter Real s_edge = 3.20 "Descending edge position [m]";
  parameter Real ridge_height = 0.05 "Surface ridge height [m]";
  parameter Real s_ridge1 = 0.85 "First ridge location [m]";
  parameter Real s_ridge2 = 2.00 "Second ridge location [m]";

  // ===== Payload disturbance =====
  parameter Real F_payload = 75.0 "Payload disturbance force magnitude [N]";
  parameter Real t_payload_start = 2.6666667 "Payload start time [s] (middle third begin)";
  parameter Real t_payload_end = 5.3333333 "Payload end time [s] (middle third end)";

  // ===== Controller =====
  parameter Real v_ref_climb = 0.50 "Climb speed reference [m/s]";
  parameter Real stop_margin = 0.20 "Stopping margin before descending edge [m]";
  parameter Real brake_distance = 0.60 "Controlled braking distance [m]";
  parameter Real Kp = 150.0 "Speed proportional gain";
  parameter Real Ki = 80.0 "Speed integral gain";
  parameter Real Kslip = 80.0 "Slip correction gain";
  parameter Real slip_thresh = 0.28 "Slip correction activation threshold [-]";
  parameter Real dt_ctrl = 0.0125 "Control period [s] (80 Hz)";
  parameter Real v_eps = 0.10 "Slip normalization epsilon [m/s]";
  parameter Real slip_ref = 0.15 "Traction tanh reference slip [-]";

  // ===== Derived constants =====
  parameter Real ramp_angle = ramp_angle_deg * Modelica.Constants.pi / 180.0;
  parameter Real s_brake_start = s_edge - stop_margin - brake_distance;
  parameter Real g = Modelica.Constants.g_n;

  // ===== Continuous states =====
  Real s(start=0.0, fixed=true) "Path position along ground [m]";
  Real v(start=0.0, fixed=true) "Longitudinal body speed [m/s]";
  Real theta(start=0.0, fixed=true) "Pitch angle [rad]";
  Real omega(start=0.0, fixed=true) "Pitch rate [rad/s]";
  Real phi(start=0.0, fixed=true) "Roll angle [rad]";
  Real omega_L(start=0.0, fixed=true) "Left track angular speed [rad/s]";
  Real omega_R(start=0.0, fixed=true) "Right track angular speed [rad/s]";
  Real tau_filt(start=0.0, fixed=true) "Filtered torque command per side [N.m]";

  // ===== Discrete controller states =====
  Real integ_d(start=0.0) "Integral accumulator";
  Real v_ref_d(start=v_ref_climb) "Discrete speed reference [m/s]";
  Real tau_demand_d(start=0.0) "Discrete torque demand per side [N.m]";

  // ===== Computed and sensor variables =====
  Real terrain_slope "Terrain slope [rad]";
  Real ridge_pert "Ridge-induced pitch perturbation [rad]";
  Real terrain_slope_eff "Effective terrain slope with ridges [rad]";
  Real v_track_L "Left track surface speed [m/s]";
  Real v_track_R "Right track surface speed [m/s]";
  Real slip_L "Left slip ratio [-]";
  Real slip_R "Right slip ratio [-]";
  Real slip_avg "Average slip ratio [-]";
  Real N_L "Left normal load [N]";
  Real N_R "Right normal load [N]";
  Real F_L "Left traction force [N]";
  Real F_R "Right traction force [N]";
  Real tau_L_limited "Bounded left torque [N.m]";
  Real tau_R_limited "Bounded right torque [N.m]";
  Real F_payload_applied "Applied payload force [N]";
  Real edge_dist "Forward distance to descending edge [m]";
  Real encoder_speed "Encoder speed measurement [m/s]";
  Real imu_pitch "IMU pitch [rad]";
  Real imu_roll "IMU roll [rad]";
  Real depth_sensor "Forward depth sensor reading [m]";
  Real tracking_error "Speed tracking error [m/s]";

  // ===== Requirement monitors =====
  Boolean slip_ok;
  Boolean attitude_ok;
  Boolean tracking_ok;
  Boolean finite_ok;
  Boolean stopped_before_edge;

protected
  Real e_v_d;
  Real slip_corr_c;
  Real tau_raw_c;
  Real edge_dist_c;
  Real v_ref_c;

equation
  // === Terrain profile (12 deg ramp, 2 m plateau, two ridges) ===
  terrain_slope = if s < s_ramp_start then 0.0
                  else if s < s_plateau_start then ramp_angle
                  else if s < s_edge then 0.0
                  else -ramp_angle;
  ridge_pert = 0.12 * (Modelica.Math.exp(-((s - s_ridge1) / 0.05) ^ 2) +
                       Modelica.Math.exp(-((s - s_ridge2) / 0.05) ^ 2));
  terrain_slope_eff = terrain_slope + ridge_pert;

  // === Track kinematics and slip ===
  v_track_L = omega_L * r_sprocket;
  v_track_R = omega_R * r_sprocket;
  slip_L = (v_track_L - v) / max(abs(v_track_L), v_eps);
  slip_R = (v_track_R - v) / max(abs(v_track_R), v_eps);
  slip_avg = 0.5 * (slip_L + slip_R);

  // === Normal load per track ===
  N_L = 0.5 * m_hull * g * cos(terrain_slope);
  N_R = N_L;

  // === Slip-aware traction (friction-limited, bounded by mu*N) ===
  F_L = mu * N_L * Modelica.Math.tanh(slip_L / slip_ref);
  F_R = mu * N_R * Modelica.Math.tanh(slip_R / slip_ref);

  // === Actuator: filtered and bounded torque (skid-steer, symmetric straight command) ===
  der(tau_filt) = (tau_demand_d - tau_filt) / tau_act_tau;
  tau_L_limited = max(-tau_max, min(tau_max, tau_filt));
  tau_R_limited = tau_L_limited;

  // === Payload disturbance (opposing motion during middle third) ===
  F_payload_applied = if (time >= t_payload_start and time <= t_payload_end) then F_payload else 0.0;

  // === Longitudinal dynamics ===
  der(s) = v;
  m_hull * der(v) = (F_L + F_R) - m_hull * g * sin(terrain_slope) - F_payload_applied;

  // === Pitch dynamics (chassis follows terrain slope with ridges) ===
  J_pitch * der(omega) = k_pitch * (terrain_slope_eff - theta) - c_pitch * omega;
  der(theta) = omega;

  // === Roll dynamics (skid-steer torque differential coupling, near zero for straight motion) ===
  der(phi) = -phi / tau_roll + k_roll * (tau_L_limited - tau_R_limited);

  // === Track rotational dynamics ===
  J_track * der(omega_L) = tau_L_limited - F_L * r_sprocket;
  J_track * der(omega_R) = tau_R_limited - F_R * r_sprocket;

  // === Sensors ===
  encoder_speed = 0.5 * (v_track_L + v_track_R);
  imu_pitch = theta;
  imu_roll = phi;
  edge_dist = max(s_edge - s, 0.0);
  depth_sensor = edge_dist;
  tracking_error = v - v_ref_d;

  // === Requirement monitors ===
  slip_ok = (v < 0.20) or (abs(slip_L) < 0.35 and abs(slip_R) < 0.35);
  attitude_ok = abs(theta) < 0.40 and abs(phi) < 0.40;
  tracking_ok = (time < 5.2) or (abs(tracking_error) < 0.243);
  stopped_before_edge = (s + stop_margin) < s_edge;
  finite_ok = Modelica.Math.isFinite(s) and Modelica.Math.isFinite(v) and
              Modelica.Math.isFinite(theta) and Modelica.Math.isFinite(phi) and
              Modelica.Math.isFinite(slip_L) and Modelica.Math.isFinite(slip_R) and
              Modelica.Math.isFinite(tau_demand_d) and Modelica.Math.isFinite(integ_d) and
              Modelica.Math.isFinite(edge_dist);

  // === Discrete slip-aware traction controller (80 Hz) ===
  when sample(0, dt_ctrl) then
    edge_dist_c = max(s_edge - s, 0.0);
    if s < s_brake_start then
      v_ref_c = v_ref_climb;
    elseif edge_dist_c > stop_margin then
      v_ref_c = max(0.0, v_ref_climb * (edge_dist_c - stop_margin) / brake_distance);
    else
      v_ref_c = 0.0;
    end if;
    v_ref_d = v_ref_c;
    e_v_d = v_ref_c - v;
    if abs(slip_avg) > slip_thresh then
      slip_corr_c = -Kslip * (abs(slip_avg) - slip_thresh) * sign(slip_avg);
    else
      slip_corr_c = 0.0;
    end if;
    tau_raw_c = Kp * e_v_d + Ki * pre(integ_d) + slip_corr_c;
    if abs(tau_raw_c) < tau_max then
      integ_d = pre(integ_d) + e_v_d * dt_ctrl;
    else
      integ_d = pre(integ_d);
    end if;
    tau_demand_d = max(-tau_max, min(tau_max, tau_raw_c));
  end when;

  // === Hard requirement: no NaN / infinite values ===
  assert(finite_ok, "TrackCrawlerClimbA: non-finite physical, control, or estimator value detected");

  annotation(
    experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="TrackCrawlerClimbA: 52 kg, 1.1 m capsule-hull tracked crawler with two continuous tracks (r_sprocket=0.14 m, separation=0.50 m). Skid-steer bounded track drives (|tau|<=30.2 N.m). Climbs a 12 deg ramp, traverses a 2 m plateau, and stops before the descending edge. Two 0.05 m surface ridges, mu=0.76, slip-aware traction control with bounded braking, 75 N payload disturbance over the middle third of the 8 s scenario, 80 Hz control loop. Synchronized state, command, and sensor traces retained.")
  );
end TrackCrawlerClimbA;