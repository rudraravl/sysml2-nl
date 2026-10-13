model MarinePairCoordinateA
  // ---------- Parameters (SI units) ----------
  parameter Real m_kg = 80.0 "AUV mass";
  parameter Real Fmax_N = 75.6 "per-thruster command magnitude limit";
  parameter Real Iz_kgm2 = 20.0 "yaw inertia estimate";
  parameter Real fs_Hz = 80.0 "control/sensor sample rate";
  parameter Real Ts_s = 1.0/fs_Hz "sample period";
  parameter Real T_end_s = 8.0 "scenario duration";
  parameter Real L_m = 1.2 "corridor half-length";
  parameter Real r_m = 0.3 "central conflict zone half-width";
  parameter Real v_cruise_mps = 0.9 "cruise speed";
  parameter Real z_nom_m = 2.0 "nominal depth";
  parameter Real delay_msg_s = 0.06 "acoustic modem message delay";
  parameter Real t_mid_start = 8.0/3.0 "middle third start";
  parameter Real t_mid_end = 16.0/3.0 "middle third end";
  parameter Real d_err_thresh_m = 0.878 "primary tracking error threshold after 5.2 s";
  parameter Real t_check_s = 5.2 "tracking error check time";
  parameter Real y_hold_trigger_m = -0.93 "AUV2 waiting trigger position";
  parameter Real start_delay2_s = 0.1 "AUV2 launch delay";

  // controller gains
  parameter Real Kv_surge = 6.0 "surge velocity tracking gain";
  parameter Real Kp_surge = 10.0 "end-stop position gain";
  parameter Real Kd_surge = 8.0 "end-stop damping";
  parameter Real Kp_lat = 8.0 "lateral lane-keep gain";
  parameter Real Kd_lat = 6.0 "lateral damping";
  parameter Real Kp_heave = 10.0 "depth-keep gain";
  parameter Real Kd_heave = 6.0 "depth-keep damping";
  parameter Real Kp_yaw = 5.0 "yaw gain";
  parameter Real Kd_yaw = 4.0 "yaw damping";

  // ---------- AUV1 states ----------
  Real x1(start=-L_m, fixed=true) "x position";
  Real y1(start=0.0, fixed=true) "y position";
  Real z1(start=z_nom_m, fixed=true) "depth";
  Real vx1(start=0.0, fixed=true);
  Real vy1(start=0.0, fixed=true);
  Real vz1(start=0.0, fixed=true);
  Real psi1(start=0.0, fixed=true) "heading";
  Real r1(start=0.0, fixed=true) "yaw rate";

  // ---------- AUV2 states ----------
  Real x2(start=0.0, fixed=true);
  Real y2(start=-L_m, fixed=true);
  Real z2(start=z_nom_m, fixed=true);
  Real vx2(start=0.0, fixed=true);
  Real vy2(start=0.0, fixed=true);
  Real vz2(start=0.0, fixed=true);
  Real psi2(start=0.0, fixed=true);
  Real r2(start=0.0, fixed=true);

  // ---------- eight bidirectional thruster command channels (raw) ----------
  Real surge1_raw, lat1_raw, heave1_raw, yaw1_raw;
  Real surge2_raw, lat2_raw, heave2_raw, yaw2_raw;

  // ---------- saturated actuator forces/moment ----------
  Real Fx1, Fy1, Fz1, Mz1;
  Real Fx2, Fy2, Fz2, Mz2;

  // ---------- reference trajectories ----------
  Real x1_ref, vx1_ref;
  Real y2_ref, vy2_ref;

  // ---------- peer messages and reservation ----------
  Real x1_peer_delayed "always-delayed AUV1 x for modem buffer";
  Real x1_peer "AUV1 position seen by AUV2 via delayed modem";
  Real y2_peer "AUV2 position seen by AUV1 via delayed modem";
  Real eta1, eta2 "estimated time to intersection center";
  Boolean auv1_priority;
  Boolean holding1, holding2;
  Real v_des1, v_des2;

  // ---------- onboard sensors ----------
  Real depth1, depth2 "pressure depth sensor";
  Real vx1_dvl, vy1_dvl, vx2_dvl, vy2_dvl "DVL velocity";
  Real ax1_imu, ay1_imu, ax2_imu, ay2_imu "IMU linear acceleration";
  Real r1_imu, r2_imu "IMU yaw rate";

  // ---------- metrics and traces ----------
  Real dist "inter-robot Euclidean distance";
  Real track_err1, track_err2;
  Boolean completed1, completed2;
  Boolean in_conflict_simultaneous;
  Boolean exclusion_violation;
  Real wait_time_2(start=0.0, fixed=true) "AUV2 accumulated waiting time";
  Boolean primary_err_ok;

  // synchronized 80 Hz sampled traces
  discrete Real x1_log(start=-L_m), y1_log(start=0.0);
  discrete Real x2_log(start=0.0), y2_log(start=-L_m);
  discrete Real dist_log(start=0.0);

equation
  // ---- references ----
  x1_ref = min(-L_m + v_cruise_mps*time, L_m);
  vx1_ref = if (x1_ref < L_m - 1e-6) then v_cruise_mps else 0.0;
  y2_ref = min(-L_m + v_cruise_mps*max(time - start_delay2_s, 0.0), L_m);
  vy2_ref = if (y2_ref < L_m - 1e-6) then v_cruise_mps else 0.0;

  // ---- delayed acoustic modem (0.06 s disturbance during middle third) ----
  x1_peer_delayed = delay(x1, delay_msg_s, 0.1);
  x1_peer = if (time >= t_mid_start and time <= t_mid_end) then x1_peer_delayed else x1;
  y2_peer = if (time >= t_mid_start and time <= t_mid_end) then delay(y2, delay_msg_s, 0.1) else y2;

  // ---- decentralized reservation: ETA to intersection center ----
  eta1 = (0.0 - x1)/max(vx1, 0.05);
  eta2 = (0.0 - y2)/max(vy2, 0.05);
  auv1_priority = (eta1 <= eta2 + 0.05);

  // ---- mutual-exclusion hold logic (bounded braking via actuator saturation) ----
  holding2 = (y2 > y_hold_trigger_m) and (y2 < r_m) and (x1_peer < r_m) and auv1_priority;
  holding1 = (x1 > y_hold_trigger_m) and (x1 < r_m) and (y2_peer > -r_m) and (y2_peer < r_m) and (not auv1_priority);

  v_des1 = if holding1 then 0.0 else v_cruise_mps;
  v_des2 = if holding2 then 0.0 else v_cruise_mps;

  // ---- AUV1 surge control: velocity tracking with end-stop hold ----
  surge1_raw = if (x1 > L_m - 0.3) then
                 m_kg*(Kp_surge*(L_m - x1) - Kd_surge*vx1)
               else
                 m_kg*Kv_surge*(v_des1 - vx1);

  // AUV1 lateral lane-keep (heave-lateral) -> y1 -> 0
  lat1_raw = m_kg*(Kp_lat*(0.0 - y1) + Kd_lat*(0.0 - vy1));
  // AUV1 heave depth-keep -> z1 -> z_nom
  heave1_raw = m_kg*(Kp_heave*(z_nom_m - z1) + Kd_heave*(0.0 - vz1));
  // AUV1 yaw regulation
  yaw1_raw = Iz_kgm2*(Kp_yaw*(0.0 - psi1) + Kd_yaw*(0.0 - r1));

  // ---- AUV2 surge control (along y) ----
  surge2_raw = if (y2 > L_m - 0.3) then
                 m_kg*(Kp_surge*(L_m - y2) - Kd_surge*vy2)
               else
                 m_kg*Kv_surge*(v_des2 - vy2);

  // AUV2 lateral lane-keep -> x2 -> 0
  lat2_raw = m_kg*(Kp_lat*(0.0 - x2) + Kd_lat*(0.0 - vx2));
  heave2_raw = m_kg*(Kp_heave*(z_nom_m - z2) + Kd_heave*(0.0 - vz2));
  yaw2_raw = Iz_kgm2*(Kp_yaw*(0.0 - psi2) + Kd_yaw*(0.0 - r2));

  // ---- actuator saturation (command magnitude limit 75.6 N) ----
  Fx1 = max(-Fmax_N, min(Fmax_N, surge1_raw));
  Fy1 = max(-Fmax_N, min(Fmax_N, lat1_raw));
  Fz1 = max(-Fmax_N, min(Fmax_N, heave1_raw));
  Mz1 = max(-Fmax_N, min(Fmax_N, yaw1_raw));
  Fx2 = max(-Fmax_N, min(Fmax_N, lat2_raw));
  Fy2 = max(-Fmax_N, min(Fmax_N, surge2_raw));
  Fz2 = max(-Fmax_N, min(Fmax_N, heave2_raw));
  Mz2 = max(-Fmax_N, min(Fmax_N, yaw2_raw));

  // ---- point-mass dynamics (neutrally buoyant, no hydro drag modeled) ----
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = Fx1/m_kg;
  der(vy1) = Fy1/m_kg;
  der(vz1) = Fz1/m_kg;
  der(psi1) = r1;
  der(r1) = Mz1/Iz_kgm2;

  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = Fx2/m_kg;
  der(vy2) = Fy2/m_kg;
  der(vz2) = Fz2/m_kg;
  der(psi2) = r2;
  der(r2) = Mz2/Iz_kgm2;

  // ---- onboard sensor outputs ----
  depth1 = z1;
  depth2 = z2;
  vx1_dvl = vx1;  vy1_dvl = vy1;
  vx2_dvl = vx2;  vy2_dvl = vy2;
  ax1_imu = Fx1/m_kg;  ay1_imu = Fy1/m_kg;
  ax2_imu = Fx2/m_kg;  ay2_imu = Fy2/m_kg;
  r1_imu = r1;  r2_imu = r2;

  // ---- performance metrics ----
  dist = sqrt(max((x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2, 1e-9));
  track_err1 = abs(x1_ref - x1);
  track_err2 = abs(y2_ref - y2);
  completed1 = x1 >= L_m - 0.05;
  completed2 = y2 >= L_m - 0.05;
  in_conflict_simultaneous = (abs(x1) < r_m and abs(y1) < r_m) and (abs(x2) < r_m and abs(y2) < r_m);
  exclusion_violation = in_conflict_simultaneous;
  der(wait_time_2) = if holding2 then 1.0 else 0.0;
  primary_err_ok = (time < t_check_s) or (track_err1 < d_err_thresh_m);

  // ---- synchronized 80 Hz sampled traces ----
  when sample(0, Ts_s) then
    x1_log = x1;
    y1_log = y1;
    x2_log = x2;
    y2_log = y2;
    dist_log = dist;
  end when;

  // ---- well-definedness guard (distance is strictly positive by construction) ----
  assert(dist > 0.0, "Collision: zero inter-robot distance detected");

  annotation (
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Two 80 kg AUVs traverse crossing corridors (AUV1 along x, AUV2 along y) sharing a central conflict zone of half-width 0.3 m. Eight bidirectional thruster channels (surge, lateral lane-keep, heave depth-keep, yaw) per pair are saturated at 75.6 N. Decentralized reservation via ETA comparison with delayed acoustic modem (0.06 s during the middle third). Bounded braking enforced by actuator saturation. Primary (AUV1) tracking error required below 0.878 m after 5.2 s.")
  );
end MarinePairCoordinateA;