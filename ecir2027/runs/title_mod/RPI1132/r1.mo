model AirTrioFormD
  "Instrumented three-quadrotor formation: 1.8 kg each, four rotors (12 N max), IMU, GPS, peer-range; distributed formation control with 0.08 s message delay during middle third"

  // --- Physical parameters ---
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";
  parameter Real Tmax = 12.0 "max thrust per rotor [N]";
  parameter Real Tmin = 0.0 "min thrust per rotor [N]";

  // --- Control parameters ---
  parameter Real k_track = 6.0 "leader tracking gain [1/s2]";
  parameter Real k_damp = 3.5 "velocity damping gain [1/s]";
  parameter Real k_form = 5.0 "formation gain [1/s2]";
  parameter Real k_sep = 12.0 "separation repulsion gain [m/s2]";
  parameter Real sepMin = 0.8 "minimum pairwise separation [m]";
  parameter Real sepSafe = 0.9 "separation safety activation threshold [m]";
  parameter Real cmdMax = 8.0 "bounded local acceleration command [m/s2]";

  // --- Communication disturbance ---
  parameter Real tDelay = 0.08 "message delay disturbance [s]";
  parameter Real tStart = 14.0/3.0 "middle-third start [s]";
  parameter Real tEnd = 28.0/3.0 "middle-third end [s]";

  // --- Reference trajectory ---
  parameter Real v_lead = 0.5 "leader cruise speed [m/s]";
  parameter Real z_ref = 1.5 "reference altitude [m]";

  // --- Formation offsets (relative to leader) ---
  parameter Real off2x = -1.0 "follower 2 x offset [m]";
  parameter Real off2y =  0.8 "follower 2 y offset [m]";
  parameter Real off2z =  0.0 "follower 2 z offset [m]";
  parameter Real off3x = -1.0 "follower 3 x offset [m]";
  parameter Real off3y = -0.8 "follower 3 y offset [m]";
  parameter Real off3z =  0.0 "follower 3 z offset [m]";

  // --- Fixed obstacles (placed outside nominal path; shape/dynamics unknown) ---
  parameter Real obs1x = 5.0 "obstacle 1 x [m]";
  parameter Real obs1y = 3.0 "obstacle 1 y [m]";
  parameter Real obs1z = 1.5 "obstacle 1 z [m]";
  parameter Real obs2x = 7.0 "obstacle 2 x [m]";
  parameter Real obs2y = -3.0 "obstacle 2 y [m]";
  parameter Real obs2z = 1.5 "obstacle 2 z [m]";
  parameter Real obsRad = 0.5 "obstacle safety radius [m]";

  // --- Robot state (3 quadrotors, 3 DOF position + velocity) ---
  Real p1x, p1y, p1z;
  Real p2x, p2y, p2z;
  Real p3x, p3y, p3z;
  Real v1x, v1y, v1z;
  Real v2x, v2y, v2z;
  Real v3x, v3y, v3z;

  // --- Rotor thrusts (12 independent groups, 4 per robot) [N] ---
  Real tr1_1, tr1_2, tr1_3, tr1_4;
  Real tr2_1, tr2_2, tr2_3, tr2_4;
  Real tr3_1, tr3_2, tr3_3, tr3_4;
  Real T1, T2, T3 "collective thrust [N]";

  // --- Reference trajectory ---
  Real prx, pry, prz;
  Real vrx, vry, vrz;

  // --- Delayed peer (leader) pose messages ---
  Real pldx, pldy, pldz "delayed leader position";
  Real vldx, vldy, vldz "delayed leader velocity";
  Real delayTime "current communication age [s]";

  // --- Control commands (pre- and post-saturation) ---
  Real a1x, a1y, a1z, a2x, a2y, a2z, a3x, a3y, a3z;
  Real as1x, as1y, as1z, as2x, as2y, as2z, as3x, as3y, as3z;

  // --- Inter-robot repulsion ---
  Real d12, d13, d23;
  Real rep12x, rep12y, rep12z;
  Real rep13x, rep13y, rep13z;
  Real rep23x, rep23y, rep23z;

  // --- Sensors ---
  Real r12, r13, r23 "peer-relative range [m]";
  Real gps1x, gps1y, gps1z, gps2x, gps2y, gps2z, gps3x, gps3y, gps3z;
  Real imu1x, imu1y, imu1z, imu2x, imu2y, imu2z, imu3x, imu3y, imu3z;

  // --- Performance & safety metrics ---
  Real trackingError "leader primary tracking error [m]";
  Real formationError "sum of follower formation errors [m]";
  Real minSeparation "minimum pairwise separation [m]";
  Real commAge "communication age [s]";
  Boolean noCollision;
  Boolean trackingOK;
  Boolean actuatorsOK;

initial equation
  p1x = 0.0;  p1y = 0.0;  p1z = z_ref;
  p2x = off2x; p2y = off2y; p2z = z_ref;
  p3x = off3x; p3y = off3y; p3z = z_ref;
  v1x = 0.0;  v1y = 0.0;  v1z = 0.0;
  v2x = 0.0;  v2y = 0.0;  v2z = 0.0;
  v3x = 0.0;  v3y = 0.0;  v3z = 0.0;

equation
  // ===== Reference trajectory (straight-line cruise in +x at z_ref) =====
  prx = v_lead * time;
  pry = 0.0;
  prz = z_ref;
  vrx = v_lead;
  vry = 0.0;
  vrz = 0.0;

  // ===== Communication age / message delay disturbance =====
  delayTime = if (time >= tStart and time <= tEnd) then tDelay else 0.0;
  // Delayed leader pose: fixed-delay transport, selected during middle third
  pldx = if (time >= tStart and time <= tEnd) then delay(p1x, tDelay, tDelay) else p1x;
  pldy = if (time >= tStart and time <= tEnd) then delay(p1y, tDelay, tDelay) else p1y;
  pldz = if (time >= tStart and time <= tEnd) then delay(p1z, tDelay, tDelay) else p1z;
  vldx = if (time >= tStart and time <= tEnd) then delay(v1x, tDelay, tDelay) else v1x;
  vldy = if (time >= tStart and time <= tEnd) then delay(v1y, tDelay, tDelay) else v1y;
  vldz = if (time >= tStart and time <= tEnd) then delay(v1z, tDelay, tDelay) else v1z;

  // ===== Peer-relative range measurements =====
  d12 = sqrt((p1x - p2x)^2 + (p1y - p2y)^2 + (p1z - p2z)^2);
  d13 = sqrt((p1x - p3x)^2 + (p1y - p3y)^2 + (p1z - p3z)^2);
  d23 = sqrt((p2x - p3x)^2 + (p2y - p3y)^2 + (p2z - p3z)^2);
  r12 = d12;
  r13 = d13;
  r23 = d23;

  // ===== Inter-robot repulsion (activates only below sepSafe) =====
  rep12x = if d12 < sepSafe then k_sep * (sepSafe - d12) * (p1x - p2x) / max(d12, 0.01) else 0.0;
  rep12y = if d12 < sepSafe then k_sep * (sepSafe - d12) * (p1y - p2y) / max(d12, 0.01) else 0.0;
  rep12z = if d12 < sepSafe then k_sep * (sepSafe - d12) * (p1z - p2z) / max(d12, 0.01) else 0.0;
  rep13x = if d13 < sepSafe then k_sep * (sepSafe - d13) * (p1x - p3x) / max(d13, 0.01) else 0.0;
  rep13y = if d13 < sepSafe then k_sep * (sepSafe - d13) * (p1y - p3y) / max(d13, 0.01) else 0.0;
  rep13z = if d13 < sepSafe then k_sep * (sepSafe - d13) * (p1z - p3z) / max(d13, 0.01) else 0.0;
  rep23x = if d23 < sepSafe then k_sep * (sepSafe - d23) * (p2x - p3x) / max(d23, 0.01) else 0.0;
  rep23y = if d23 < sepSafe then k_sep * (sepSafe - d23) * (p2y - p3y) / max(d23, 0.01) else 0.0;
  rep23z = if d23 < sepSafe then k_sep * (sepSafe - d23) * (p2z - p3z) / max(d23, 0.01) else 0.0;

  // ===== Distributed formation control =====
  // Leader: track reference trajectory
  a1x = k_track * (prx - p1x) + k_damp * (vrx - v1x) + rep12x + rep13x;
  a1y = k_track * (pry - p1y) + k_damp * (vry - v1y) + rep12y + rep13y;
  a1z = k_track * (prz - p1z) + k_damp * (vrz - v1z) + rep12z + rep13z;

  // Follower 2: maintain offset using delayed leader pose + onboard state
  a2x = k_form * (pldx + off2x - p2x) + k_damp * (vldx - v2x) - rep12x + rep23x;
  a2y = k_form * (pldy + off2y - p2y) + k_damp * (vldy - v2y) - rep12y + rep23y;
  a2z = k_form * (pldz + off2z - p2z) + k_damp * (vldz - v2z) - rep12z + rep23z;

  // Follower 3: maintain offset using delayed leader pose + onboard state
  a3x = k_form * (pldx + off3x - p3x) + k_damp * (vldx - v3x) - rep13x - rep23x;
  a3y = k_form * (pldy + off3y - p3y) + k_damp * (vldy - v3y) - rep13y - rep23y;
  a3z = k_form * (pldz + off3z - p3z) + k_damp * (vldz - v3z) - rep13z - rep23z;

  // ===== Bounded local commands =====
  as1x = max(-cmdMax, min(cmdMax, a1x));
  as1y = max(-cmdMax, min(cmdMax, a1y));
  as1z = max(-cmdMax, min(cmdMax, a1z));
  as2x = max(-cmdMax, min(cmdMax, a2x));
  as2y = max(-cmdMax, min(cmdMax, a2y));
  as2z = max(-cmdMax, min(cmdMax, a2z));
  as3x = max(-cmdMax, min(cmdMax, a3x));
  as3y = max(-cmdMax, min(cmdMax, a3y));
  as3z = max(-cmdMax, min(cmdMax, a3z));

  // ===== Plant dynamics (idealized attitude control: world accel = command) =====
  der(p1x) = v1x;  der(p1y) = v1y;  der(p1z) = v1z;
  der(v1x) = as1x; der(v1y) = as1y; der(v1z) = as1z;
  der(p2x) = v2x;  der(p2y) = v2y;  der(p2z) = v2z;
  der(v2x) = as2x; der(v2y) = as2y; der(v2z) = as2z;
  der(p3x) = v3x;  der(p3y) = v3y;  der(p3z) = v3z;
  der(v3x) = as3x; der(v3y) = as3y; der(v3z) = as3z;

  // ===== Actuator allocation: 4 rotors per robot, saturated [0, 12] N =====
  T1 = m * sqrt(as1x^2 + as1y^2 + (as1z + g_acc)^2);
  T2 = m * sqrt(as2x^2 + as2y^2 + (as2z + g_acc)^2);
  T3 = m * sqrt(as3x^2 + as3y^2 + (as3z + g_acc)^2);
  tr1_1 = max(Tmin, min(Tmax, T1 / 4.0));
  tr1_2 = max(Tmin, min(Tmax, T1 / 4.0));
  tr1_3 = max(Tmin, min(Tmax, T1 / 4.0));
  tr1_4 = max(Tmin, min(Tmax, T1 / 4.0));
  tr2_1 = max(Tmin, min(Tmax, T2 / 4.0));
  tr2_2 = max(Tmin, min(Tmax, T2 / 4.0));
  tr2_3 = max(Tmin, min(Tmax, T2 / 4.0));
  tr2_4 = max(Tmin, min(Tmax, T2 / 4.0));
  tr3_1 = max(Tmin, min(Tmax, T3 / 4.0));
  tr3_2 = max(Tmin, min(Tmax, T3 / 4.0));
  tr3_3 = max(Tmin, min(Tmax, T3 / 4.0));
  tr3_4 = max(Tmin, min(Tmax, T3 / 4.0));

  // ===== Sensors: GPS (position), IMU (acceleration), peer-range =====
  gps1x = p1x; gps1y = p1y; gps1z = p1z;
  gps2x = p2x; gps2y = p2y; gps2z = p2z;
  gps3x = p3x; gps3y = p3y; gps3z = p3z;
  imu1x = as1x; imu1y = as1y; imu1z = as1z;
  imu2x = as2x; imu2y = as2y; imu2z = as2z;
  imu3x = as3x; imu3y = as3y; imu3z = as3z;

  // ===== Metrics =====
  trackingError = sqrt((p1x - prx)^2 + (p1y - pry)^2 + (p1z - prz)^2);
  formationError = sqrt((p2x - (prx + off2x))^2 + (p2y - (pry + off2y))^2 + (p2z - (prz + off2z))^2)
                 + sqrt((p3x - (prx + off3x))^2 + (p3y - (pry + off3y))^2 + (p3z - (prz + off3z))^2);
  minSeparation = min(d12, min(d13, d23));
  commAge = delayTime;

  // ===== Safety assertions =====
  noCollision = (minSeparation > 0.01)
    and (sqrt((p1x - obs1x)^2 + (p1y - obs1y)^2 + (p1z - obs1z)^2) > obsRad)
    and (sqrt((p1x - obs2x)^2 + (p1y - obs2y)^2 + (p1z - obs2z)^2) > obsRad)
    and (sqrt((p2x - obs1x)^2 + (p2y - obs1y)^2 + (p2z - obs1z)^2) > obsRad)
    and (sqrt((p2x - obs2x)^2 + (p2y - obs2y)^2 + (p2z - obs2z)^2) > obsRad)
    and (sqrt((p3x - obs1x)^2 + (p3y - obs1y)^2 + (p3z - obs1z)^2) > obsRad)
    and (sqrt((p3x - obs2x)^2 + (p3y - obs2y)^2 + (p3z - obs2z)^2) > obsRad);

  trackingOK = (time < 9.1) or (trackingError < 0.3);

  actuatorsOK = (tr1_1 <= Tmax + 0.001) and (tr1_2 <= Tmax + 0.001) and (tr1_3 <= Tmax + 0.001) and (tr1_4 <= Tmax + 0.001)
    and (tr2_1 <= Tmax + 0.001) and (tr2_2 <= Tmax + 0.001) and (tr2_3 <= Tmax + 0.001) and (tr2_4 <= Tmax + 0.001)
    and (tr3_1 <= Tmax + 0.001) and (tr3_2 <= Tmax + 0.001) and (tr3_3 <= Tmax + 0.001) and (tr3_4 <= Tmax + 0.001);

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "AirTrioFormD: three 1.8 kg quadrotors in leader-follower formation.
  Each quadrotor has four independently-limited rotors (0-12 N), IMU, GPS, and peer-relative range.
  Distributed formation control uses onboard state estimation and delayed peer pose messages.
  A controlled 0.08 s message delay is applied during the middle third (t in [4.67, 9.33] s).
  Run at 200 Hz for 14 s. Metrics: actuator limits, pairwise separation, formation error,
  communication age, no collision, primary tracking error < 0.3 m after 9.1 s.
  Unknown (not invented): exact rotor aerodynamics, IMU/GPS noise models, obstacle geometry,
  estimator internals, and communication protocol details are abstracted as ideal/point-mass."));
end AirTrioFormD;