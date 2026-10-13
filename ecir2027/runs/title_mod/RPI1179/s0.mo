model MarinePairFormC
  "MarinePairFormC: Two-AUV distributed formation control with bounded local commands";

  // === Physical parameters ===
  parameter Real m_auv = 80.0 "AUV mass [kg]";
  parameter Real F_max = 96.6 "Maximum command magnitude per thruster [N]";
  parameter Real drag_coeff = 50.0 "Linear hydrodynamic drag [N*s/m]";

  // === Control gains ===
  parameter Real Kp = 50.0 "Proportional gain [N/m]";
  parameter Real Kd = 60.0 "Derivative gain [N*s/m]";
  parameter Real Kf = 3.0 "Formation correction gain [N/m]";

  // === Communication ===
  parameter Real delay_dist = 0.072 "Message delay disturbance [s]";

  // === Formation offsets and separation ===
  parameter Real dx1 = 0.0 "AUV1 x offset from leader [m]";
  parameter Real dz1 = -1.0 "AUV1 z offset from leader [m]";
  parameter Real dx2 = 0.0 "AUV2 x offset from leader [m]";
  parameter Real dz2 = 1.0 "AUV2 z offset from leader [m]";
  parameter Real min_sep = 1.5 "Minimum pairwise separation [m]";
  parameter Real des_sep = 2.0 "Desired separation [m]";

  // === Leader trajectory ===
  parameter Real leader_speed = 0.5 "Leader surge speed [m/s]";
  // Leader depth profile, curvature not specified; assumed constant-depth straight line

  // === Obstacles (outside nominal formation path) ===
  parameter Real obs1_x = -10.0 "Obstacle 1 x [m]";
  parameter Real obs1_z = 10.0 "Obstacle 1 z [m]";
  parameter Real obs2_x = 20.0 "Obstacle 2 x [m]";
  parameter Real obs2_z = -10.0 "Obstacle 2 z [m]";
  parameter Real obs_r = 1.0 "Obstacle radius [m]";

  // === Leader state ===
  Real leader_x "Leader x position [m]";
  Real leader_z "Leader z position [m]";
  Real leader_vx "Leader surge velocity [m/s]";
  Real leader_vz "Leader heave velocity [m/s]";

  // === AUV1 plant state ===
  Real x1(start = 0.0, fixed = true) "AUV1 x position [m]";
  Real z1(start = -1.0, fixed = true) "AUV1 z position [m]";
  Real vx1(start = 0.0, fixed = true) "AUV1 surge velocity [m/s]";
  Real vz1(start = 0.0, fixed = true) "AUV1 heave velocity [m/s]";

  // === AUV2 plant state ===
  Real x2(start = 0.0, fixed = true) "AUV2 x position [m]";
  Real z2(start = 1.0, fixed = true) "AUV2 z position [m]";
  Real vx2(start = 0.0, fixed = true) "AUV2 surge velocity [m/s]";
  Real vz2(start = 0.0, fixed = true) "AUV2 heave velocity [m/s]";

  // === Eight bidirectional thruster channels ===
  Real ch1_s1 "AUV1 surge channel 1 [N]";
  Real ch1_s2 "AUV1 surge channel 2 [N]";
  Real ch1_h1 "AUV1 heave channel 1 [N]";
  Real ch1_h2 "AUV1 heave channel 2 [N]";
  Real ch2_s1 "AUV2 surge channel 1 [N]";
  Real ch2_s2 "AUV2 surge channel 2 [N]";
  Real ch2_h1 "AUV2 heave channel 1 [N]";
  Real ch2_h2 "AUV2 heave channel 2 [N]";

  // === Net forces ===
  Real F1_surge "AUV1 net surge force [N]";
  Real F1_heave "AUV1 net heave force [N]";
  Real F2_surge "AUV2 net surge force [N]";
  Real F2_heave "AUV2 net heave force [N]";

  // === Controller commands (pre-saturation) ===
  Real F1_surge_cmd "AUV1 surge command [N]";
  Real F1_heave_cmd "AUV1 heave command [N]";
  Real F2_surge_cmd "AUV2 surge command [N]";
  Real F2_heave_cmd "AUV2 heave command [N]";

  // === Sensors ===
  Real imu1_ax "AUV1 IMU surge acceleration [m/s2]";
  Real imu1_az "AUV1 IMU heave acceleration [m/s2]";
  Real imu2_ax "AUV2 IMU surge acceleration [m/s2]";
  Real imu2_az "AUV2 IMU heave acceleration [m/s2]";
  Real depth1 "AUV1 pressure depth [m]";
  Real depth2 "AUV2 pressure depth [m]";
  Real dvl1_vx "AUV1 DVL surge velocity [m/s]";
  Real dvl1_vz "AUV1 DVL heave velocity [m/s]";
  Real dvl2_vx "AUV2 DVL surge velocity [m/s]";
  Real dvl2_vz "AUV2 DVL heave velocity [m/s]";
  Real rel_range "Peer-relative range [m]";

  // === Communication ===
  Boolean in_middle "True during middle third (4-8 s)";
  Real comm_age "Communication age [s]";
  Real delayed_x2_to1 "Delayed AUV2 x received at AUV1 [m]";
  Real delayed_z2_to1 "Delayed AUV2 z received at AUV1 [m]";
  Real delayed_x1_to2 "Delayed AUV1 x received at AUV2 [m]";
  Real delayed_z1_to2 "Delayed AUV1 z received at AUV2 [m]";
  Real recv_x2_to1 "Received AUV2 x at AUV1 [m]";
  Real recv_z2_to1 "Received AUV2 z at AUV1 [m]";
  Real recv_x1_to2 "Received AUV1 x at AUV2 [m]";
  Real recv_z1_to2 "Received AUV1 z at AUV2 [m]";

  // === Performance metrics ===
  Real track_err1 "AUV1 primary tracking error [m]";
  Real track_err2 "AUV2 tracking error [m]";
  Real separation "Pairwise separation [m]";
  Real form_err "Formation error [m]";
  Real d1o1 "Distance AUV1 to obstacle 1 [m]";
  Real d1o2 "Distance AUV1 to obstacle 2 [m]";
  Real d2o1 "Distance AUV2 to obstacle 1 [m]";
  Real d2o2 "Distance AUV2 to obstacle 2 [m]";

equation
  // === Leader trajectory ===
  leader_x = leader_speed * time;
  leader_z = 0.0;
  leader_vx = leader_speed;
  leader_vz = 0.0;

  // === Delay disturbance: active during middle third (4-8 s of 12 s) ===
  in_middle = time >= 4.0 and time <= 8.0;
  comm_age = if in_middle then delay_dist else 0.0;

  // Delayed acoustic modem messages (always computed via delay builtin)
  delayed_x2_to1 = delay(x2, delay_dist, 0.2);
  delayed_z2_to1 = delay(z2, delay_dist, 0.2);
  delayed_x1_to2 = delay(x1, delay_dist, 0.2);
  delayed_z1_to2 = delay(z1, delay_dist, 0.2);

  // Received messages: delayed during middle third, otherwise direct
  recv_x2_to1 = if in_middle then delayed_x2_to1 else x2;
  recv_z2_to1 = if in_middle then delayed_z2_to1 else z2;
  recv_x1_to2 = if in_middle then delayed_x1_to2 else x1;
  recv_z1_to2 = if in_middle then delayed_z1_to2 else z1;

  // === AUV1 dynamics ===
  m_auv * der(vx1) = F1_surge - drag_coeff * vx1;
  m_auv * der(vz1) = F1_heave - drag_coeff * vz1;
  der(x1) = vx1;
  der(z1) = vz1;

  // === AUV2 dynamics ===
  m_auv * der(vx2) = F2_surge - drag_coeff * vx2;
  m_auv * der(vz2) = F2_heave - drag_coeff * vz2;
  der(x2) = vx2;
  der(z2) = vz2;

  // === Controller AUV1: PD tracking + feedforward + formation correction ===
  F1_surge_cmd = Kp * (leader_x + dx1 - x1) + Kd * (leader_vx - vx1)
    + drag_coeff * leader_vx
    + Kf * ((recv_x2_to1 - x1) - (dx2 - dx1));
  F1_heave_cmd = Kp * (leader_z + dz1 - z1) + Kd * (leader_vz - vz1)
    + drag_coeff * leader_vz
    + Kf * ((recv_z2_to1 - z1) - (dz2 - dz1));

  // === Controller AUV2: PD tracking + feedforward + formation correction ===
  F2_surge_cmd = Kp * (leader_x + dx2 - x2) + Kd * (leader_vx - vx2)
    + drag_coeff * leader_vx
    + Kf * ((recv_x1_to2 - x2) - (dx1 - dx2));
  F2_heave_cmd = Kp * (leader_z + dz2 - z2) + Kd * (leader_vz - vz2)
    + drag_coeff * leader_vz
    + Kf * ((recv_z1_to2 - z2) - (dz1 - dz2));

  // === Saturation: 8 bidirectional channels, each bounded to [-F_max, F_max] ===
  ch1_s1 = max(-F_max, min(F_max, F1_surge_cmd / 2.0));
  ch1_s2 = max(-F_max, min(F_max, F1_surge_cmd / 2.0));
  ch1_h1 = max(-F_max, min(F_max, F1_heave_cmd / 2.0));
  ch1_h2 = max(-F_max, min(F_max, F1_heave_cmd / 2.0));
  ch2_s1 = max(-F_max, min(F_max, F2_surge_cmd / 2.0));
  ch2_s2 = max(-F_max, min(F_max, F2_surge_cmd / 2.0));
  ch2_h1 = max(-F_max, min(F_max, F2_heave_cmd / 2.0));
  ch2_h2 = max(-F_max, min(F_max, F2_heave_cmd / 2.0));

  // Net forces from paired channels
  F1_surge = ch1_s1 + ch1_s2;
  F1_heave = ch1_h1 + ch1_h2;
  F2_surge = ch2_s1 + ch2_s2;
  F2_heave = ch2_h1 + ch2_h2;

  // === Sensors ===
  // IMU accelerometers (computed from force balance)
  imu1_ax = (F1_surge - drag_coeff * vx1) / m_auv;
  imu1_az = (F1_heave - drag_coeff * vz1) / m_auv;
  imu2_ax = (F2_surge - drag_coeff * vx2) / m_auv;
  imu2_az = (F2_heave - drag_coeff * vz2) / m_auv;

  // Pressure depth sensors
  depth1 = z1;
  depth2 = z2;

  // DVL velocity sensors
  dvl1_vx = vx1;
  dvl1_vz = vz1;
  dvl2_vx = vx2;
  dvl2_vz = vz2;

  // Peer-relative range (zero-safe norm)
  rel_range = sqrt((x1 - x2)^2 + (z1 - z2)^2 + 1e-12);

  // === Obstacle distances (zero-safe) ===
  d1o1 = sqrt((x1 - obs1_x)^2 + (z1 - obs1_z)^2 + 1e-12);
  d1o2 = sqrt((x1 - obs2_x)^2 + (z1 - obs2_z)^2 + 1e-12);
  d2o1 = sqrt((x2 - obs1_x)^2 + (z2 - obs1_z)^2 + 1e-12);
  d2o2 = sqrt((x2 - obs2_x)^2 + (z2 - obs2_z)^2 + 1e-12);

  // === Performance metrics ===
  track_err1 = sqrt((x1 - (leader_x + dx1))^2 + (z1 - (leader_z + dz1))^2 + 1e-12);
  track_err2 = sqrt((x2 - (leader_x + dx2))^2 + (z2 - (leader_z + dz2))^2 + 1e-12);
  separation = rel_range;
  form_err = abs(separation - des_sep);

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "MarinePairFormC: Two 80 kg AUVs with distributed formation control.
      Eight bidirectional thruster channels bounded at 96.6 N per thruster.
      0.072 s message delay injected during middle third (4-8 s).
      Run at 125 Hz (Interval=0.008 s) for 12 s.
      Primary tracking error requirement: below 0.315 m after 7.8 s.
      Obstacles placed outside nominal formation path.
      Leader depth profile and curvature not specified; assumed constant-depth straight-line motion.")
  );
end MarinePairFormC;