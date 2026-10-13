model GimbalPathCycleC
  "Yaw-pitch-roll gimbal carrying a 4 kg camera performing a periodic
   pick-transfer-return cycle with bounded torque and payload variation."

  // ---- Physical payload / actuator limits ----
  parameter Real m_cam(unit="kg") = 4.0 "Camera payload mass";
  parameter Real tau_max(unit="N.m") = 18.4 "Maximum actuator command magnitude";
  parameter Real payload_var(unit="1") = 0.108 "Payload variation fraction (10.8 percent)";

  // ---- Geometric parameters (unknown kinematics approximated by arm length) ----
  parameter Real L_arm(unit="m") = 0.5 "Effective gimbal arm length";
  parameter Real h_base(unit="m") = 0.40 "Base height of gimbal pivot";
  parameter Real r_post(unit="m") = 0.05 "Station post radius";
  parameter Real r_ee(unit="m") = 0.03 "End-effector radius";
  parameter Real h_post(unit="m") = 0.30 "Station post height";
  parameter Real z_ground(unit="m") = 0.0 "Ground plane";
  parameter Real z_clear(unit="m") = 0.02 "Ground clearance";

  // ---- Joint inertias / damping ----
  parameter Real J_yaw(unit="kg.m2") = 0.08;
  parameter Real J_pitch(unit="kg.m2") = 0.05;
  parameter Real J_roll(unit="kg.m2") = 0.03;
  parameter Real d_yaw(unit="N.m.s/rad") = 0.6;
  parameter Real d_pitch(unit="N.m.s/rad") = 0.4;
  parameter Real d_roll(unit="N.m.s/rad") = 0.3;

  // ---- Joint limits ----
  parameter Real yaw_min(unit="rad") = -2.8;
  parameter Real yaw_max(unit="rad") =  2.8;
  parameter Real pitch_min(unit="rad") = -1.2;
  parameter Real pitch_max(unit="rad") =  1.0;
  parameter Real roll_min(unit="rad") = -0.8;
  parameter Real roll_max(unit="rad") =  0.8;

  // ---- Cycle / timing ----
  parameter Real T_cycle(unit="s") = 3.0 "Cycle period (12 s / 4 cycles)";
  parameter Integer N_cycles = 4 "Required complete cycles";
  parameter Real T_sim(unit="s") = 12.0 "Total simulation time";
  parameter Real fs(unit="Hz") = 125.0 "Sampling / run rate";

  // ---- Station poses ----
  parameter Real stationA_yaw(unit="rad") = 1.4 "Yaw to station A";
  parameter Real stationB_yaw(unit="rad") = -1.4 "Yaw to station B";
  parameter Real dip_pick(unit="rad") = -0.55 "Pitch dip magnitude at pick/place";

  // ---- Controller gains ----
  parameter Real Kp_yaw(unit="N.m/rad") = 60.0;
  parameter Real Kd_yaw(unit="N.m.s/rad") = 6.0;
  parameter Real Kp_pitch(unit="N.m/rad") = 50.0;
  parameter Real Kd_pitch(unit="N.m.s/rad") = 5.0;
  parameter Real Kp_roll(unit="N.m/rad") = 40.0;
  parameter Real Kd_roll(unit="N.m.s/rad") = 4.0;

  // ---- Dynamic states ----
  Real q_yaw(start=stationA_yaw, fixed=true) "Yaw angle";
  Real w_yaw(start=0.0, fixed=true) "Yaw rate";
  Real q_pitch(start=0.0, fixed=true) "Pitch angle";
  Real w_pitch(start=0.0, fixed=true) "Pitch rate";
  Real q_roll(start=0.0, fixed=true) "Roll angle";
  Real w_roll(start=0.0, fixed=true) "Roll rate";

  // ---- Trajectory targets ----
  Real target_yaw;
  Real target_pitch;
  Real target_roll;
  Real target_d_yaw;
  Real target_d_pitch;
  Real target_d_roll;

  // ---- Commands ----
  Real tau_yaw_raw;
  Real tau_pitch_raw;
  Real tau_roll_raw;
  Real tau_yaw;
  Real tau_pitch;
  Real tau_roll;

  // ---- Disturbance (payload variation in middle third) ----
  Boolean in_middle_third "True during middle third of total run";
  Real J_yaw_eff;
  Real J_pitch_eff;
  Real J_roll_eff;

  // ---- Phase / cycle evidence ----
  Real cycle_phase "Phase in [0,1) within current cycle";
  Integer cycle_index "Completed cycles count";
  Integer phase_index "1=pick, 2=transfer, 3=return";
  Real cycle_phase_rate "Nominal phase rate";

  // ---- End-effector pose and stations ----
  Real ee_x;
  Real ee_y;
  Real ee_z;
  Real stationA_x;
  Real stationA_y;
  Real stationB_x;
  Real stationB_y;
  Real dist_A;
  Real dist_B;

  // ---- Monitoring / evidence ----
  Real track_err_yaw;
  Real track_err_pitch;
  Real track_err_roll;
  Real track_err_primary "Primary tracking error (max of joint errors)";
  Real station_pose_err "Pose error at active station";
  Real cycle_time_err;
  Boolean collision;
  Boolean state_bound_ok;
  Boolean effort_bound_ok;
  Boolean tracking_ok;
  Boolean nan_inf_ok;
  Boolean requirements_ok;

  // ---- Trajectory helper variables ----
  Real phi "Cycle phase variable";
  Real S "Smooth blend 0->1 for yaw transfer";
  Real s_pick;
  Real s_place;
  Real dip_pick_bump;
  Real dip_place_bump;

protected
  function smoothstep
    "C1-continuous smooth blend on [0,1]."
    input Real t;
    output Real y;
  algorithm
    if t <= 0.0 then
      y := 0.0;
    elseif t >= 1.0 then
      y := 1.0;
    else
      y := 3.0*t*t - 2.0*t*t*t;
    end if;
  end smoothstep;

  function sat "Symmetric saturation."
    input Real x;
    input Real lim;
    output Real y;
  algorithm
    if x > lim then
      y := lim;
    elseif x < -lim then
      y := -lim;
    else
      y := x;
    end if;
  end sat;

  function isFiniteVal
    "Portable finite check: NaN fails x==x; infinity exceeds bounds."
    input Real x;
    output Boolean ok;
  algorithm
    ok := (x == x) and (x < 1.0e300) and (x > -1.0e300);
  end isFiniteVal;

equation
  // ---- Cycle phase ----
  phi = mod(time, T_cycle) / T_cycle;
  cycle_phase = phi;
  cycle_phase_rate = 1.0 / T_cycle;
  cycle_index = integer(time / T_cycle);

  // Phase index (1=pick [0,1/3), 2=transfer [1/3,2/3), 3=return [2/3,1))
  if phi < 1.0/3.0 then
    phase_index = 1;
  elseif phi < 2.0/3.0 then
    phase_index = 2;
  else
    phase_index = 3;
  end if;

  // ---- Middle third of total run: payload variation window ----
  in_middle_third = (time >= T_sim/3.0) and (time <= 2.0*T_sim/3.0);

  // ---- Smooth yaw blend A->B->A ----
  if phi <= 1.0/3.0 then
    S = 0.0;
  elseif phi <= 1.0/2.0 then
    S = smoothstep((phi - 1.0/3.0) / (1.0/2.0 - 1.0/3.0));
  elseif phi <= 2.0/3.0 then
    S = 1.0;
  else
    S = 1.0 - smoothstep((phi - 2.0/3.0) / (1.0 - 2.0/3.0));
  end if;

  // ---- Pitch dips (Gaussian-like bumps) for pick and place ----
  s_pick = (phi - 0.25) / 0.08;
  s_place = (phi - 0.60) / 0.08;
  dip_pick_bump = exp(-s_pick*s_pick);
  dip_place_bump = exp(-s_place*s_place);

  // ---- Targets ----
  target_yaw = stationA_yaw + (stationB_yaw - stationA_yaw) * S;
  target_pitch = dip_pick * (dip_pick_bump + dip_place_bump);
  target_roll = 0.0;

  // ---- Target derivatives via automatic differentiation ----
  target_d_yaw = der(target_yaw);
  target_d_pitch = der(target_pitch);
  target_d_roll = der(target_roll);

  // ---- Effective inertia with 10.8 percent payload variation ----
  J_yaw_eff = J_yaw * (1.0 + payload_var * (if in_middle_third then 1.0 else 0.0));
  J_pitch_eff = J_pitch * (1.0 + payload_var * (if in_middle_third then 1.0 else 0.0));
  J_roll_eff = J_roll * (1.0 + payload_var * (if in_middle_third then 1.0 else 0.0));

  // ---- PD control with bounded torque ----
  tau_yaw_raw = Kp_yaw*(target_yaw - q_yaw) + Kd_yaw*(target_d_yaw - w_yaw);
  tau_pitch_raw = Kp_pitch*(target_pitch - q_pitch) + Kd_pitch*(target_d_pitch - w_pitch);
  tau_roll_raw = Kp_roll*(target_roll - q_roll) + Kd_roll*(target_d_roll - w_roll);
  tau_yaw = sat(tau_yaw_raw, tau_max);
  tau_pitch = sat(tau_pitch_raw, tau_max);
  tau_roll = sat(tau_roll_raw, tau_max);

  // ---- Plant dynamics (second-order joints) ----
  der(q_yaw) = w_yaw;
  der(w_yaw) = (tau_yaw - d_yaw*w_yaw) / J_yaw_eff;
  der(q_pitch) = w_pitch;
  der(w_pitch) = (tau_pitch - d_pitch*w_pitch) / J_pitch_eff;
  der(q_roll) = w_roll;
  der(w_roll) = (tau_roll - d_roll*w_roll) / J_roll_eff;

  // ---- End-effector kinematics (yaw about z, pitch about y) ----
  ee_x = L_arm * cos(q_pitch) * cos(q_yaw);
  ee_y = L_arm * cos(q_pitch) * sin(q_yaw);
  ee_z = h_base + L_arm * sin(q_pitch);
  stationA_x = L_arm * cos(stationA_yaw);
  stationA_y = L_arm * sin(stationA_yaw);
  stationB_x = L_arm * cos(stationB_yaw);
  stationB_y = L_arm * sin(stationB_yaw);
  dist_A = sqrt(max((ee_x - stationA_x)^2 + (ee_y - stationA_y)^2, 1e-9));
  dist_B = sqrt(max((ee_x - stationB_x)^2 + (ee_y - stationB_y)^2, 1e-9));

  // ---- Collision detection (two stations, enabled) ----
  // Collision if ee hits ground OR enters a post envelope while not servicing it.
  collision = (ee_z < z_ground + z_clear)
           or (dist_A < (r_post + r_ee) and ee_z < h_post and not (phi < 1.0/3.0))
           or (dist_B < (r_post + r_ee) and ee_z < h_post and not (phi > 0.5 and phi < 0.7));

  // ---- Tracking errors ----
  track_err_yaw = abs(target_yaw - q_yaw);
  track_err_pitch = abs(target_pitch - q_pitch);
  track_err_roll = abs(target_roll - q_roll);
  track_err_primary = max(track_err_yaw, max(track_err_pitch, track_err_roll));

  // ---- Station pose error at active station ----
  if phi < 1.0/3.0 then
    station_pose_err = sqrt(max((ee_x - stationA_x)^2 + (ee_y - stationA_y)^2
                              + (ee_z - (h_base + L_arm*sin(dip_pick)))^2, 1e-9));
  elseif phi < 2.0/3.0 then
    station_pose_err = sqrt(max((ee_x - stationB_x)^2 + (ee_y - stationB_y)^2
                              + (ee_z - (h_base + L_arm*sin(dip_pick)))^2, 1e-9));
  else
    station_pose_err = sqrt(max((ee_x - stationA_x)^2 + (ee_y - stationA_y)^2
                              + (ee_z - (h_base + L_arm*sin(dip_pick)))^2, 1e-9));
  end if;

  // ---- Cycle-time error (deviation of phase rate from nominal) ----
  cycle_time_err = abs(der(phi) - cycle_phase_rate);

  // ---- Bounds checks ----
  state_bound_ok = (q_yaw >= yaw_min) and (q_yaw <= yaw_max)
               and (q_pitch >= pitch_min) and (q_pitch <= pitch_max)
               and (q_roll >= roll_min) and (q_roll <= roll_max);
  effort_bound_ok = (abs(tau_yaw) <= tau_max) and (abs(tau_pitch) <= tau_max)
                 and (abs(tau_roll) <= tau_max);

  // ---- Tracking requirement: primary error < 0.042 rad after 7.8 s ----
  tracking_ok = (time < 7.8) or (track_err_primary < 0.042);

  // ---- NaN / infinity checks on physical, control, and estimator values ----
  nan_inf_ok = isFiniteVal(q_yaw) and isFiniteVal(q_pitch) and isFiniteVal(q_roll)
            and isFiniteVal(w_yaw) and isFiniteVal(w_pitch) and isFiniteVal(w_roll)
            and isFiniteVal(tau_yaw) and isFiniteVal(tau_pitch) and isFiniteVal(tau_roll)
            and isFiniteVal(target_yaw) and isFiniteVal(target_pitch) and isFiniteVal(target_roll);

  // ---- Aggregate requirement ----
  requirements_ok = state_bound_ok and effort_bound_ok and tracking_ok
                 and (not collision) and (cycle_index >= N_cycles) and nan_inf_ok;

  annotation(
    experiment(StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="GimbalPathCycleC: yaw-pitch-roll gimbal carrying a 4 kg camera
      performing a phase-indexed pick-transfer-return cycle (4 cycles over 12 s at 125 Hz).
      Bounded torque actuators (18.4 N.m), 10.8 percent payload variation injected during
      the middle third of the run, two-station workcell with collision monitoring,
      state/effort bounds, cycle-time error, station pose error, primary tracking error
      (< 0.042 rad after 7.8 s), and finite-value checks. Facts not stated in the
      request (e.g. exact kinematic chain, gravity, friction model) are unknown and
      approximated here only with simple second-order joint dynamics."));
end GimbalPathCycleC;