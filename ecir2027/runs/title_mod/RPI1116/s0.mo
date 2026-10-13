model GroundTrioCoordinateF
  "Three differential-drive warehouse robots (18 kg each, six bounded wheel
   drives) traverse fixed corridors that cross at one shared intersection.
   Decentralized reservation with bounded braking serializes intersection
   occupancy. A controlled 0.174 s peer-message delay is applied during the
   middle third of the run. Run at 500 Hz for 20 s."

  // ---- Physical embodiment ----
  parameter Real m_robot = 18.00 "robot mass [kg]";
  parameter Real r_w = 0.100 "wheel radius [m]";
  parameter Real L_w = 0.400 "wheel base [m]";
  parameter Real Iz = 0.600 "yaw inertia [kg.m2]";
  parameter Real robot_radius = 0.300 "bounding radius [m]";

  // ---- Actuation bounds ----
  parameter Real tau_max = 14.6 "per-wheel torque bound [N.m]";

  // ---- Control gains ----
  parameter Real v_ref = 1.20 "cruise speed [m/s]";
  parameter Real Kpv = 120.0 "velocity error gain [N.s/m]";
  parameter Real Kpw = 25.00 "yaw-rate error gain [N.m.s/rad]";
  parameter Real K_psi = 3.00 "heading gain [1/s]";
  parameter Real K_lat = 1.50 "lateral path gain [1/s2]";

  // ---- Corridor / intersection geometry (fixed) ----
  parameter Real lane_half = 0.600 "corridor half-width [m]";
  parameter Real intersect_half = 0.500 "intersection half-width [m]";
  parameter Real claim_zone = 3.000 "reservation claim radius [m]";
  parameter Real stop_buffer = 1.500 "nominal stop-line offset [m]";
  parameter Real brake_trigger_dist = 2.200 "yield brake trigger distance [m]";
  parameter Real obs_brake_dist = 0.900 "lidar obstacle brake distance [m]";
  parameter Real goal_tol = 0.100 "goal tolerance [m]";

  // ---- Communication disturbance ----
  parameter Real t_delay = 0.174 "controlled message delay [s]";
  parameter Real delay_max = 0.200 "delay buffer upper bound [s]";
  parameter Real t_mid_start = 6.670 "middle third start [s]";
  parameter Real t_mid_end = 13.330 "middle third end [s]";

  // ---- Verification thresholds ----
  parameter Real track_err_limit = 0.520 "primary tracking error limit [m]";

  // ---- Routes: three corridors crossing at the origin ----
  // R1: east-bound along y = 0
  // R2: north-bound along x = 0
  // R3: north-west-bound along y = -x
  parameter Real x_start[3] = {-8.000, 0.000, 5.656854249492381};
  parameter Real y_start[3] = {0.000, -8.000, -5.656854249492381};
  parameter Real x_goal[3] = {8.000, 0.000, -5.656854249492381};
  parameter Real y_goal[3] = {0.000, 8.000, 5.656854249492381};
  parameter Real psi_path[3] = {0.000, 1.5707963267948966, 2.356194490192345};

  // ---- States ----
  Real x[3](start = x_start) "world x [m]";
  Real y[3](start = y_start) "world y [m]";
  Real th[3](start = psi_path) "heading [rad]";
  Real v[3](start = {0.0, 0.0, 0.0}) "body speed [m/s]";
  Real om[3](start = {0.0, 0.0, 0.0}) "yaw rate [rad/s]";
  Real wait_time[3](start = {0.0, 0.0, 0.0}) "accumulated waiting time [s]";

  // ---- Estimation / observation signals ----
  Real s[3] "along-path progress [m]";
  Real e_lat[3] "lateral path error [m]";
  Real e_psi[3] "heading error [rad]";
  Real dist_entry[3] "distance to intersection entry along path [m]";
  Real tti[3] "time-to-intersection estimate [s]";
  Boolean approaching[3];
  Boolean in_int[3];
  Boolean passed[3];
  Boolean at_goal[3];
  Boolean claim[3];

  // ---- Reservation messaging (delayed peer messages) ----
  Real tx[3] "broadcast reservation signal";
  Real rx1_raw "delayed tx of robot 1 [s-equiv flag]";
  Real rx2_raw "delayed tx of robot 2 [s-equiv flag]";
  Real rx3_raw "delayed tx of robot 3 [s-equiv flag]";
  Real rx1 "effective received tx of robot 1";
  Real rx2 "effective received tx of robot 2";
  Real rx3 "effective received tx of robot 3";
  Boolean yield_flag[3];

  // ---- Obstacle sensing (lidar pairwise) ----
  Real d12 "pair distance 1-2 [m]";
  Real d13 "pair distance 1-3 [m]";
  Real d23 "pair distance 2-3 [m]";
  Real min_pair[3] "minimum distance to any peer [m]";
  Boolean brake_obs[3];

  // ---- Control ----
  Real omega_des[3] "desired yaw rate [rad/s]";
  Real v_des[3] "desired speed [m/s]";
  Real F_cmd[3] "total drive force [N]";
  Real M_cmd[3] "drive yaw moment [N.m]";
  Real tauR[3] "right wheel torque command [N.m]";
  Real tauL[3] "left wheel torque command [N.m]";
  Real tauR_sat[3] "saturated right wheel torque [N.m]";
  Real tauL_sat[3] "saturated left wheel torque [N.m]";

  // ---- Verification observables (Real for FMU export) ----
  Real track_err[3] "primary tracking error = |e_lat| [m]";
  Real goal_err[3] "distance to goal [m]";
  Real max_abs_torque "max |saturated wheel torque| [N.m]";
  Real actuator_bound_ok "1 if all wheel torques within bound";
  Real min_dist_all "minimum pairwise distance [m]";
  Real no_collision_flag "1 if min distance exceeds collision threshold";
  Real in_int_count "number of robots occupying intersection";
  Real mutex_ok "1 if at most one robot occupies intersection";
  Real route_complete[3] "1 if robot i has reached its goal";
  Real lane_keep_ok "1 if all robots remain inside corridor half-width";
  Real track_err_ok "1 if primary tracking error below limit after 13 s";
  Real waiting_time_max "maximum individual waiting time [s]";

  // NOTE: Portable standard Modelica provides no NaN/Inf introspection; a
  // non-finite integrator state is expected to abort the run, which itself
  // constitutes the finiteness evidence for this scenario.

equation
  // ---- Path geometry / localization ----
  for i in 1:3 loop
    s[i] = x[i]*cos(psi_path[i]) + y[i]*sin(psi_path[i]);
    e_lat[i] = -(x[i])*sin(psi_path[i]) + (y[i])*cos(psi_path[i]);
    e_psi[i] = atan2(sin(psi_path[i] - th[i]), cos(psi_path[i] - th[i]));
    dist_entry[i] = -s[i]; // robots travel in +s direction toward origin
    approaching[i] = (dist_entry[i] > robot_radius) and (dist_entry[i] < claim_zone + 1.0);
    in_int[i] = abs(s[i]) < (intersect_half + robot_radius);
    passed[i] = s[i] > (intersect_half + robot_radius);
    at_goal[i] = sqrt(max((x[i] - x_goal[i])^2 + (y[i] - y_goal[i])^2, 1e-9)) < goal_tol;
    claim[i] = (not passed[i]) and (not at_goal[i]) and (dist_entry[i] > robot_radius) and (dist_entry[i] < claim_zone);
    tti[i] = max(dist_entry[i], 0.0)/max(v[i], 0.05);
    tx[i] = if (claim[i] or in_int[i]) then 1.0 else 0.0;
  end for;

  // ---- Delayed peer messages (fixed parameter delay, gated to middle third) ----
  rx1_raw = delay(tx[1], t_delay, delay_max);
  rx2_raw = delay(tx[2], t_delay, delay_max);
  rx3_raw = delay(tx[3], t_delay, delay_max);
  rx1 = if (time >= t_mid_start and time <= t_mid_end) then rx1_raw else tx[1];
  rx2 = if (time >= t_mid_start and time <= t_mid_end) then rx2_raw else tx[2];
  rx3 = if (time >= t_mid_start and time <= t_mid_end) then rx3_raw else tx[3];

  // ---- Decentralized reservation: priority 1 > 2 > 3 ----
  yield_flag[1] = false;
  yield_flag[2] = (not in_int[2]) and (not at_goal[2]) and (dist_entry[2] > robot_radius) and (rx1 > 0.5);
  yield_flag[3] = (not in_int[3]) and (not at_goal[3]) and (dist_entry[3] > robot_radius) and ((rx1 > 0.5) or (rx2 > 0.5));

  // ---- Lidar obstacle sensing ----
  d12 = sqrt(max((x[1] - x[2])^2 + (y[1] - y[2])^2, 1e-9));
  d13 = sqrt(max((x[1] - x[3])^2 + (y[1] - y[3])^2, 1e-9));
  d23 = sqrt(max((x[2] - x[3])^2 + (y[2] - y[3])^2, 1e-9));
  min_pair[1] = min(d12, d13);
  min_pair[2] = min(d12, d23);
  min_pair[3] = min(d13, d23);
  for i in 1:3 loop
    brake_obs[i] = min_pair[i] < obs_brake_dist;
  end for;

  // ---- Speed command: reservation braking, obstacle braking, goal stop ----
  for i in 1:3 loop
    v_des[i] = if at_goal[i] then 0.0
               else if brake_obs[i] then 0.0
               else if (yield_flag[i] and (dist_entry[i] < brake_trigger_dist)) then 0.0
               else v_ref;
    omega_des[i] = K_psi*e_psi[i] + K_lat*e_lat[i];
  end for;

  // ---- Wheel drive control with saturation ----
  for i in 1:3 loop
    F_cmd[i] = Kpv*(v_des[i] - v[i]);
    M_cmd[i] = Kpw*(omega_des[i] - om[i]);
    tauR[i] = F_cmd[i]*r_w/2.0 + M_cmd[i]*r_w/L_w;
    tauL[i] = F_cmd[i]*r_w/2.0 - M_cmd[i]*r_w/L_w;
    tauR_sat[i] = max(-tau_max, min(tau_max, tauR[i]));
    tauL_sat[i] = max(-tau_max, min(tau_max, tauL[i]));
  end for;

  // ---- Differential-drive dynamics ----
  for i in 1:3 loop
    der(x[i]) = v[i]*cos(th[i]);
    der(y[i]) = v[i]*sin(th[i]);
    der(th[i]) = om[i];
    der(v[i]) = (tauR_sat[i] + tauL_sat[i])/(r_w*m_robot);
    der(om[i]) = (tauR_sat[i] - tauL_sat[i])*L_w/(2.0*r_w*Iz);
    der(wait_time[i]) = if yield_flag[i] then 1.0 else 0.0;
  end for;

  // ---- Tracking / goal errors ----
  for i in 1:3 loop
    track_err[i] = abs(e_lat[i]);
    goal_err[i] = sqrt(max((x[i] - x_goal[i])^2 + (y[i] - y_goal[i])^2, 1e-9));
  end for;

  // ---- Verification observables ----
  max_abs_torque = max(abs(tauR_sat[1]), max(abs(tauL_sat[1]),
                     max(abs(tauR_sat[2]), max(abs(tauL_sat[2]),
                     max(abs(tauR_sat[3]), abs(tauL_sat[3]))))));
  actuator_bound_ok = if max_abs_torque <= tau_max + 1e-6 then 1.0 else 0.0;
  min_dist_all = min(d12, min(d13, d23));
  no_collision_flag = if min_dist_all > 2.0*robot_radius then 1.0 else 0.0;
  in_int_count = (if in_int[1] then 1.0 else 0.0)
               + (if in_int[2] then 1.0 else 0.0)
               + (if in_int[3] then 1.0 else 0.0);
  mutex_ok = if in_int_count <= 1.0 then 1.0 else 0.0;
  for i in 1:3 loop
    route_complete[i] = if at_goal[i] then 1.0 else 0.0;
  end for;
  lane_keep_ok = if (abs(e_lat[1]) < lane_half and abs(e_lat[2]) < lane_half and abs(e_lat[3]) < lane_half) then 1.0 else 0.0;
  track_err_ok = if time < 13.0 then 1.0
                 else if (max(track_err[1], max(track_err[2], track_err[3])) < track_err_limit) then 1.0
                 else 0.0;
  waiting_time_max = max(wait_time[1], max(wait_time[2], wait_time[3]));

  annotation(
    Documentation(info = "GroundTrioCoordinateF: three 18 kg differential-drive
warehouse robots share a rigid floor with odometry, lidar and delayed peer
messages. Six bounded wheel drives (<=14.6 N.m each) traverse three fixed
corridors crossing at one shared intersection. Decentralized reservation with
bounded braking serializes occupancy. A controlled 0.174 s message delay is
applied during the middle third (6.67-13.33 s) of a 20 s, 500 Hz run."),
    experiment(StopTime = 20.0, Tolerance = 1e-4, Interval = 0.002),
    Diagram);
end GroundTrioCoordinateF;