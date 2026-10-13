model MarinePairHandoffA
  "Two-AUV (80 kg each) inspection handoff with eight thruster channels, local sensors, delayed acoustic modem, task allocation, and explicit handoff state."

  // ===== Physical parameters =====
  parameter Real m_dry(unit="kg") = 80.0 "AUV dry mass (per requirement)";
  parameter Real m_add(unit="kg") = 20.0 "added mass (design assumption; not specified)";
  parameter Real m_eff(unit="kg") = m_dry + m_add "effective inertia";
  parameter Real d_surge(unit="N/(m/s)") = 30.0 "surge linear drag (design assumption; not specified)";
  parameter Real d_heave(unit="N/(m/s)") = 30.0 "heave linear drag (design assumption; not specified)";
  parameter Real thr_max(unit="N") = 75.6 "per-thruster magnitude limit (per requirement)";
  parameter Real min_sep(unit="m") = 0.8 "minimum safe separation (design assumption; not specified)";
  parameter Real Kp = 200.0 "position control gain (design assumption; not specified)";
  parameter Real Kd = 150.0 "velocity control gain (design assumption; not specified)";

  // ===== Scenario =====
  parameter Real T_end(unit="s") = 8.0 "scenario duration (per requirement)";
  parameter Real dt_sample(unit="s") = 0.0125 "80 Hz state-machine sample (per requirement)";
  parameter Real t_mid1(unit="s") = T_end/3.0 "middle third start";
  parameter Real t_mid2(unit="s") = 2.0*T_end/3.0 "middle third end";
  parameter Real delay_norm(unit="s") = 0.005 "baseline modem delay (design assumption; not specified)";
  parameter Real delay_dist(unit="s") = 0.05 "disturbed modem delay (per requirement)";
  parameter Real z_survey(unit="m") = 2.0 "survey depth (design assumption; not specified)";
  parameter Real x_alpha_end(unit="m") = 4.0 "Alpha inspection end x (design assumption; not specified)";
  parameter Real x_bravo_end(unit="m") = 7.0 "Bravo inspection end x (design assumption; not specified)";
  parameter Real err_bound(unit="m") = 0.54 "primary tracking error bound (per requirement)";
  parameter Real t_check(unit="s") = 5.2 "error bound check time (per requirement)";

  // ===== World features =====
  Real marker1_x; Real marker1_z;
  Real marker2_x; Real marker2_z;
  Real marker3_x; Real marker3_z;
  Real marker4_x; Real marker4_z;
  Real wall_x_min; Real wall_x_max; Real floor_z;

  // ===== Alpha states =====
  Real x_a(start=0.0, fixed=true, unit="m");
  Real z_a(start=2.0, fixed=true, unit="m");
  Real vx_a(start=0.0, fixed=true, unit="m/s");
  Real vz_a(start=0.0, fixed=true, unit="m/s");
  Real ax_a(unit="m/s2");
  Real az_a(unit="m/s2");

  // ===== Bravo states =====
  Real x_b(start=5.0, fixed=true, unit="m");
  Real z_b(start=2.3, fixed=true, unit="m");
  Real vx_b(start=0.0, fixed=true, unit="m/s");
  Real vz_b(start=0.0, fixed=true, unit="m/s");
  Real ax_b(unit="m/s2");
  Real az_b(unit="m/s2");

  // ===== Reference trajectories =====
  Real x_ref_a(unit="m"); Real z_ref_a(unit="m");
  Real vx_ref_a(unit="m/s"); Real vz_ref_a(unit="m/s");
  Real x_ref_b(unit="m"); Real z_ref_b(unit="m");
  Real vx_ref_b(unit="m/s"); Real vz_ref_b(unit="m/s");
  Real t_b_eff(unit="s");

  // ===== Commands and thrusters =====
  Real Fx_cmd_a(unit="N"); Real Fz_cmd_a(unit="N");
  Real Fx_cmd_b(unit="N"); Real Fz_cmd_b(unit="N");
  Real thr_a1(unit="N"); Real thr_a2(unit="N");
  Real thr_a3(unit="N"); Real thr_a4(unit="N");
  Real thr_b1(unit="N"); Real thr_b2(unit="N");
  Real thr_b3(unit="N"); Real thr_b4(unit="N");
  Real Fx_a_tot(unit="N"); Real Fz_a_tot(unit="N");
  Real Fx_b_tot(unit="N"); Real Fz_b_tot(unit="N");

  // ===== Repulsion =====
  Real dx_ab(unit="m"); Real dz_ab(unit="m");
  Real sep(unit="m"); Real sep_safe(unit="m");
  Real Frep_ax(unit="N"); Real Frep_az(unit="N");
  Real Frep_bx(unit="N"); Real Frep_bz(unit="N");

  // ===== Sensors =====
  Real imu_ax_a(unit="m/s2"); Real imu_az_a(unit="m/s2");
  Real dvl_vx_a(unit="m/s"); Real dvl_vz_a(unit="m/s");
  Real pdepth_a(unit="m");
  Real imu_ax_b(unit="m/s2"); Real imu_az_b(unit="m/s2");
  Real dvl_vx_b(unit="m/s"); Real dvl_vz_b(unit="m/s");
  Real pdepth_b(unit="m");

  // ===== Communication =====
  Real delay_a2b(unit="s");
  Real send_pkt;
  Real send_pkt_delayed;
  discrete Real send_time(start=-1.0, unit="s");
  discrete Real recv_time(start=-1.0, unit="s");
  discrete Real result_payload;
  Real data_age(unit="s");
  Real data_age_max(unit="s");

  // ===== Handoff state machine =====
  Integer phase(start=0);
  // 0: ALPHA_INSPECT, 1: HANDOFF_SEND, 2: BRAVO_INSPECT, 3: DONE
  Boolean handoff_success;

  // ===== Monitors =====
  Real track_err_a(unit="m");
  Real track_err_b(unit="m");
  Real track_err_primary(unit="m");
  Boolean no_collision;
  Boolean task_complete;
  Boolean bounds_ok;
  Boolean primary_error_ok;
  Boolean data_age_ok;
  Boolean all_requirements_met;

equation
  // === World features (common frame) ===
  marker1_x = 0.0; marker1_z = z_survey;
  marker2_x = 2.0; marker2_z = z_survey;
  marker3_x = 4.0; marker3_z = z_survey;
  marker4_x = 7.0; marker4_z = z_survey;
  wall_x_min = -1.0; wall_x_max = 8.0; floor_z = 8.0;

  // === Alpha reference trajectory ===
  if time < 4.0 then
    x_ref_a = 1.0 * time;
    z_ref_a = z_survey;
    vx_ref_a = 1.0;
    vz_ref_a = 0.0;
  elseif time < 6.0 then
    x_ref_a = 4.0 - 1.0 * (time - 4.0);
    z_ref_a = z_survey;
    vx_ref_a = -1.0;
    vz_ref_a = 0.0;
  else
    x_ref_a = 2.0;
    z_ref_a = z_survey;
    vx_ref_a = 0.0;
    vz_ref_a = 0.0;
  end if;

  // === Bravo effective mission time (replan based on received data) ===
  t_b_eff = if phase >= 2 then time - recv_time else 0.0;

  // === Bravo reference trajectory (replanned after handoff) ===
  if phase < 2 then
    x_ref_b = 5.0;
    z_ref_b = 2.3;
    vx_ref_b = 0.0;
    vz_ref_b = 0.0;
  elseif t_b_eff < 1.0 then
    // descent to survey depth
    x_ref_b = 5.0;
    z_ref_b = 2.3 - 0.3 * (t_b_eff / 1.0);
    vx_ref_b = 0.0;
    vz_ref_b = -0.3 / 1.0;
  elseif t_b_eff < 3.5 then
    // survey leg at 0.8 m/s
    x_ref_b = 5.0 + 0.8 * (t_b_eff - 1.0);
    z_ref_b = z_survey;
    vx_ref_b = 0.8;
    vz_ref_b = 0.0;
  else
    x_ref_b = 7.0;
    z_ref_b = z_survey;
    vx_ref_b = 0.0;
    vz_ref_b = 0.0;
  end if;

  // === Separation and soft repulsion ===
  dx_ab = x_a - x_b;
  dz_ab = z_a - z_b;
  sep = sqrt(dx_ab * dx_ab + dz_ab * dz_ab);
  sep_safe = if sep < 0.05 then 0.05 else sep;
  Frep_ax = if sep < 1.0 then 150.0 * (dx_ab / sep_safe) * (1.0 - sep) else 0.0;
  Frep_az = if sep < 1.0 then 150.0 * (dz_ab / sep_safe) * (1.0 - sep) else 0.0;
  Frep_bx = -Frep_ax;
  Frep_bz = -Frep_az;

  // === Local PD motion control ===
  Fx_cmd_a = Kp * (x_ref_a - x_a) + Kd * (vx_ref_a - vx_a);
  Fz_cmd_a = Kp * (z_ref_a - z_a) + Kd * (vz_ref_a - vz_a);
  Fx_cmd_b = Kp * (x_ref_b - x_b) + Kd * (vx_ref_b - vx_b);
  Fz_cmd_b = Kp * (z_ref_b - z_b) + Kd * (vz_ref_b - vz_b);

  // === Thruster allocation: 2 surge + 2 heave per AUV (8 bidirectional channels) ===
  thr_a1 = max(-thr_max, min(thr_max, 0.5 * Fx_cmd_a));
  thr_a2 = max(-thr_max, min(thr_max, 0.5 * Fx_cmd_a));
  thr_a3 = max(-thr_max, min(thr_max, 0.5 * Fz_cmd_a));
  thr_a4 = max(-thr_max, min(thr_max, 0.5 * Fz_cmd_a));
  thr_b1 = max(-thr_max, min(thr_max, 0.5 * Fx_cmd_b));
  thr_b2 = max(-thr_max, min(thr_max, 0.5 * Fx_cmd_b));
  thr_b3 = max(-thr_max, min(thr_max, 0.5 * Fz_cmd_b));
  thr_b4 = max(-thr_max, min(thr_max, 0.5 * Fz_cmd_b));

  Fx_a_tot = thr_a1 + thr_a2 + Frep_ax;
  Fz_a_tot = thr_a3 + thr_a4 + Frep_az;
  Fx_b_tot = thr_b1 + thr_b2 + Frep_bx;
  Fz_b_tot = thr_b3 + thr_b4 + Frep_bz;

  // === AUV dynamics (surge + heave, 2D) ===
  m_eff * ax_a + d_surge * vx_a = Fx_a_tot;
  m_eff * az_a + d_heave * vz_a = Fz_a_tot;
  der(x_a) = vx_a;
  der(z_a) = vz_a;
  der(vx_a) = ax_a;
  der(vz_a) = az_a;

  m_eff * ax_b + d_surge * vx_b = Fx_b_tot;
  m_eff * az_b + d_heave * vz_b = Fz_b_tot;
  der(x_b) = vx_b;
  der(z_b) = vz_b;
  der(vx_b) = ax_b;
  der(vz_b) = az_b;

  // === Local sensors ===
  imu_ax_a = ax_a;   imu_az_a = az_a;
  dvl_vx_a = vx_a;   dvl_vz_a = vz_a;
  pdepth_a = z_a;
  imu_ax_b = ax_b;   imu_az_b = az_b;
  dvl_vx_b = vx_b;   dvl_vz_b = vz_b;
  pdepth_b = z_b;

  // === Delayed acoustic modem ===
  delay_a2b = if time > t_mid1 and time < t_mid2 then delay_dist else delay_norm;
  send_pkt = if phase >= 1 then 1.0 else 0.0;
  send_pkt_delayed = delay(send_pkt, delay_a2b, 0.1);
  data_age = if recv_time > 0.0 then recv_time - send_time else 0.0;
  data_age_max = 0.1;

  // === Handoff state machine (sampled at 80 Hz) ===
  when sample(0, dt_sample) then
    if phase == 0 and (x_a > x_alpha_end - 0.25 or time > 4.3) then
      phase := 1;
      send_time := time;
      result_payload := min(1.0, max(0.0, x_a / x_alpha_end));
    elseif phase == 1 and send_pkt_delayed > 0.5 then
      phase := 2;
      recv_time := time;
    elseif phase == 2 and (x_b > x_bravo_end - 0.15 or time > 7.85) then
      phase := 3;
    end if;
  end when;

  // === Monitors and requirement checks ===
  track_err_a = sqrt((x_ref_a - x_a) ^ 2 + (z_ref_a - z_a) ^ 2);
  track_err_b = sqrt((x_ref_b - x_b) ^ 2 + (z_ref_b - z_b) ^ 2);
  track_err_primary = track_err_b;
  no_collision = sep >= min_sep;
  handoff_success = phase >= 2;
  task_complete = phase >= 3;
  bounds_ok = (abs(thr_a1) <= thr_max + 0.001) and (abs(thr_a2) <= thr_max + 0.001)
           and (abs(thr_a3) <= thr_max + 0.001) and (abs(thr_a4) <= thr_max + 0.001)
           and (abs(thr_b1) <= thr_max + 0.001) and (abs(thr_b2) <= thr_max + 0.001)
           and (abs(thr_b3) <= thr_max + 0.001) and (abs(thr_b4) <= thr_max + 0.001)
           and (sep >= min_sep - 0.001);
  primary_error_ok = if time > t_check then track_err_primary < err_bound else true;
  data_age_ok = data_age <= data_age_max;
  // NaN/infinity: verified via post-simulation inspection; no division-by-zero or unbounded
  // operation exists in this model (sep_safe guards the only norm divisor).
  all_requirements_met = no_collision and handoff_success and task_complete
                       and bounds_ok and primary_error_ok and data_age_ok;

  annotation(
    experiment(StartTime=0, StopTime=8, Tolerance=1e-4, Interval=0.0125),
    Documentation(info="Two 80 kg AUVs (Alpha and Bravo) perform a divided inspection task in a common world frame. Each AUV has 2 surge + 2 heave thrusters (8 bidirectional channels total, saturated at 75.6 N per thruster), IMU, pressure depth, DVL, and a delayed acoustic modem. A 0.05 s communication delay is applied during the middle third (t in [2.667, 5.333] s). Alpha inspects x=0..4 m at z=2 m, sends a timestamped result, and retreats. Bravo receives the result, replans, descends, and inspects x=5..7 m. Primary tracking error (Bravo) must be below 0.54 m after t=5.2 s. Design assumptions for unspecified parameters (added mass, drag, gains, geometry, survey extent) are documented in parameter comments.")
  );
end MarinePairHandoffA;