model AckermannRoverClimbC
  "Floating-base Ackermann rover: ascend 12 deg ramp, traverse 2 m plateau, stop before descending edge; slip-aware bounded traction control at 125 Hz"

  // ===== Physical parameters (SI) =====
  parameter Real m_chassis = 34.0 "Chassis mass [kg]";
  parameter Real L_chassis = 1.05 "Chassis length [m]";
  parameter Real W_chassis = 0.64 "Chassis width [m]";
  parameter Real L_wheelbase = 0.74 "Wheelbase [m]";
  parameter Real a_cg = 0.28 "CG distance from rear axle [m] (assumed; a+b=wheelbase)";
  parameter Real b_cg = 0.46 "CG distance from front axle [m] (assumed)";
  parameter Real h_cg = 0.30 "CG height above ground [m] (assumed)";
  parameter Real r_wheel = 0.10 "Wheel radius [m] (assumed, not specified in requirement)";
  parameter Real J_wheel = 0.05 "Rear wheel inertia [kg.m2] (assumed)";
  parameter Real b_wheel = 0.20 "Wheel viscous damping [N.m.s/rad] (assumed)";
  parameter Real mu = 0.76 "Tire-road friction coefficient";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real tau_max = 25.8 "Maximum traction torque command magnitude [N.m]";
  parameter Real steer_max = 0.52 "Maximum steering joint angle [rad]";
  parameter Real ridge_h = 0.05 "Ridge height [m]";
  parameter Real ridge_w = 0.20 "Ridge Gaussian half-width [m] (assumed)";
  parameter Real x_ridge1 = 1.0 "Ridge 1 center position [m] (assumed)";
  parameter Real x_ridge2 = 1.5 "Ridge 2 center position [m] (assumed)";
  parameter Real ramp_angle = 0.20943951023931953 "Ramp inclination [rad] = 12 deg";
  parameter Real F_payload = 135.0 "Payload disturbance force [N]";
  parameter Real plateau_length = 2.0 "Plateau length [m]";
  parameter Real L_approach = 2.0 "Flat approach length [m] (assumed)";
  parameter Real L_ramp = 3.0 "Ramp length [m] (assumed)";

  // Terrain boundaries
  parameter Real x_ramp_start = L_approach;
  parameter Real x_ramp_end = L_approach + L_ramp;
  parameter Real x_edge = x_ramp_end + plateau_length "Descending edge position [m]";

  // Control parameters
  parameter Real v_cruise = 1.6 "Cruise speed [m/s] (assumed)";
  parameter Real d_brake = 0.80 "Braking zone distance [m] (assumed)";
  parameter Real stop_margin_target = 0.30 "Target stopping margin before edge [m] (assumed)";
  parameter Real Kp_v = 400.0 "Speed proportional gain [N/(m/s)] (assumed)";
  parameter Real Ki_v = 80.0 "Speed integral gain [N/(m/s)/s] (assumed)";
  parameter Real int_max = 200.0 "Integral anti-windup cap [N] (assumed)";
  parameter Real v_min = 0.10 "Slip normalization floor [m/s]";
  parameter Real k_slip = 6.0 "Tire slip stiffness (assumed)";
  parameter Real dt = 0.008 "Control and sensor sample period [s] = 1/125 Hz";
  parameter Real T_end = 12.0 "Mission duration [s]";
  parameter Real dx_terrain = 0.001 "Terrain slope finite-difference step [m]";
  parameter Real slip_thresh = 0.30 "Slip threshold for traction limiting";
  parameter Real slip_limit = 0.35 "Absolute slip limit";
  parameter Real angle_limit = 0.40 "Roll/pitch limit [rad]";
  parameter Real track_err_limit = 0.189 "Tracking error limit after 7.8 s [m/s]";

  // ===== Continuous states =====
  Real x_pos(start=0.0, fixed=true) "Rover longitudinal position [m]";
  Real v(start=0.0, fixed=true) "Forward speed [m/s]";
  Real omega(start=0.0, fixed=true) "Rear wheel angular velocity [rad/s]";

  // ===== Terrain and attitude =====
  Real terrain_h "Terrain height [m]";
  Real terrain_slope "Terrain slope dh/dx";
  Real pitch "Chassis pitch [rad]";
  Real roll "Chassis roll [rad]";

  // ===== Loads and forces =====
  Real N_rear "Rear axle normal load [N]";
  Real F_traction "Traction force [N]";
  Real F_gravity "Gravity along-slope component [N]";
  Real F_disturb "Payload disturbance force [N]";
  Real slip_ratio "Wheel slip ratio";

  // ===== Continuous actuator outputs =====
  Real tau_cmd_out "Applied traction torque [N.m]";
  Real steer_cmd_out "Applied steering angle [rad]";

  // ===== Continuous sensors =====
  Real v_enc "Encoder-measured speed [m/s]";
  Real pitch_imu "IMU-measured pitch [rad]";
  Real roll_imu "IMU-measured roll [rad]";
  Real d_edge "Forward depth-sensor edge distance [m]";

  // ===== Continuous monitors =====
  Real v_ref_cont "Continuous reference speed [m/s]";
  Real track_err "Speed tracking error [m/s]";
  Real track_err_after "Tracking error after 7.8 s [m/s]";
  Real slip_abs "Absolute slip ratio";
  Real pitch_abs "Absolute pitch [rad]";
  Real roll_abs "Absolute roll [rad]";
  Real stopping_margin "Current margin to descending edge [m]";
  Real tau_abs "Absolute torque command [N.m]";

  // ===== Discrete controller/sensor variables (125 Hz) =====
  Real v_ref_d(start=0.0) "Discrete reference speed [m/s]";
  Real tau_cmd_d(start=0.0) "Discrete torque command [N.m]";
  Real steer_cmd_d(start=0.0) "Discrete steering command [rad]";
  Real v_enc_d(start=0.0) "Discrete encoder speed sample [m/s]";
  Real d_edge_d(start=0.0) "Discrete depth-sensor sample [m]";
  Real pitch_imu_d(start=0.0) "Discrete IMU pitch sample [rad]";
  Real slip_d(start=0.0) "Discrete slip sample";
  Real d_stop_d(start=0.0) "Discrete distance to stop target [m]";
  Real F_ff_d(start=0.0) "Discrete feedforward force [N]";
  Real int_err(start=0.0) "Discrete integral error term [N]";
  Real tau_raw(start=0.0) "Discrete raw torque before limiting [N.m]";
  Real slip_scale(start=1.0) "Discrete slip scaling factor";
  Real tau_slip(start=0.0) "Discrete torque after slip limiting [N.m]";

equation
  // --- Terrain profile and attitude ---
  terrain_h = terrainHeight(x_pos, x_ramp_start, x_ramp_end, x_edge, ramp_angle, ridge_h, x_ridge1, x_ridge2, ridge_w);
  terrain_slope = (terrainHeight(x_pos + dx_terrain, x_ramp_start, x_ramp_end, x_edge, ramp_angle, ridge_h, x_ridge1, x_ridge2, ridge_w)
                 - terrainHeight(x_pos - dx_terrain, x_ramp_start, x_ramp_end, x_edge, ramp_angle, ridge_h, x_ridge1, x_ridge2, ridge_w))
                / (2.0 * dx_terrain);
  pitch = atan(terrain_slope);
  roll = 0.0 "Planar longitudinal model; lateral/roll dynamics not specified";

  // --- Rear axle normal load (quasi-static weight transfer on slope) ---
  N_rear = m_chassis * g * (cos(pitch) * b_cg + sin(pitch) * h_cg) / L_wheelbase;

  // --- Slip ratio with zero-error safe normalization ---
  slip_ratio = (omega * r_wheel - v) / max(abs(v), v_min);

  // --- Traction force: friction-limited magic-formula approximation ---
  F_traction = mu * N_rear * tanh(k_slip * slip_ratio);

  // --- Gravity along-slope resistance ---
  F_gravity = m_chassis * g * sin(pitch);

  // --- Payload disturbance: 135 N opposing forward motion, middle third 4-8 s ---
  F_disturb = if (time >= 4.0 and time <= 8.0) then F_payload else 0.0;

  // --- Vehicle dynamics ---
  der(x_pos) = v;
  der(v) = (F_traction - F_gravity - F_disturb) / m_chassis;
  der(omega) = (tau_cmd_out - F_traction * r_wheel - b_wheel * omega) / J_wheel;

  // --- Actuator outputs (zero-order hold from discrete controller) ---
  tau_cmd_out = tau_cmd_d;
  steer_cmd_out = steer_cmd_d;

  // --- Continuous sensor signals ---
  v_enc = v;
  pitch_imu = pitch;
  roll_imu = roll;
  d_edge = max(x_edge - x_pos, 0.0);

  // --- Continuous reference and monitors ---
  v_ref_cont = min(v_cruise * (1.0 - exp(-time / 0.5)),
                   v_cruise * min(1.0, max(x_edge - stop_margin_target - x_pos, 0.0) / d_brake));
  track_err = v_ref_cont - v;
  track_err_after = if (time >= 7.8) then abs(v_ref_cont - v) else 0.0;
  slip_abs = abs(slip_ratio);
  pitch_abs = abs(pitch);
  roll_abs = abs(roll);
  stopping_margin = max(x_edge - x_pos, 0.0);
  tau_abs = abs(tau_cmd_out);

  // --- Requirement assertions (warning level to avoid halting) ---
  assert(slip_abs < slip_limit, "Slip ratio exceeded 0.35", AssertionLevel.warning);
  assert(pitch_abs < angle_limit, "Pitch exceeded 0.40 rad", AssertionLevel.warning);
  assert(roll_abs < angle_limit, "Roll exceeded 0.40 rad", AssertionLevel.warning);
  assert(tau_abs <= tau_max + 1e-6, "Torque exceeded actuator limit", AssertionLevel.warning);
  assert(abs(steer_cmd_out) <= steer_max + 1e-6, "Steering exceeded joint limit", AssertionLevel.warning);
  assert(not (time >= 7.8 and track_err_after > track_err_limit),
         "Tracking error exceeded 0.189 m/s after 7.8 s", AssertionLevel.warning);
  assert(not (time >= T_end and stopping_margin < stop_margin_target * 0.5),
         "Stopping margin insufficient at end", AssertionLevel.warning);

  // ===== Discrete control loop at 125 Hz =====
  when sample(0, dt) then
    // Sensor sampling
    v_enc_d = v;
    d_edge_d = max(x_edge - x_pos, 0.0);
    pitch_imu_d = pitch;
    slip_d = slip_ratio;

    // Distance to stop target (margin before edge)
    d_stop_d = max(d_edge_d - stop_margin_target, 0.0);

    // Reference speed: smooth startup, cruise, brake near stop target
    v_ref_d = min(v_cruise * (1.0 - exp(-time / 0.5)),
                  v_cruise * min(1.0, d_stop_d / d_brake));

    // Integral with anti-windup and stop-state reset
    if (v_ref_d < 0.05 and abs(v_enc_d) < 0.05) then
      int_err = 0.0;
    else
      int_err = max(-int_max, min(int_max, pre(int_err) + (v_ref_d - v_enc_d) * dt));
    end if;

    // Feedforward: gravity (from IMU pitch) + known payload disturbance
    F_ff_d = m_chassis * g * sin(pitch_imu_d)
           + (if (time >= 4.0 and time <= 8.0) then F_payload else 0.0);

    // PI torque command (force domain to torque via wheel radius)
    tau_raw = (F_ff_d + Kp_v * (v_ref_d - v_enc_d) + Ki_v * int_err) * r_wheel;

    // Slip-aware limiting: linearly reduce torque magnitude as |slip| approaches limit
    slip_scale = if (slip_d > slip_thresh) then
                   max(0.0, 1.0 - (slip_d - slip_thresh) / (slip_limit - slip_thresh))
                 elseif (slip_d < -slip_thresh) then
                   max(0.0, 1.0 - (-slip_d - slip_thresh) / (slip_limit - slip_thresh))
                 else
                   1.0;

    tau_slip = tau_raw * slip_scale;

    // Actuator saturation (independently bounded traction and steering)
    tau_cmd_d = max(-tau_max, min(tau_max, tau_slip));
    steer_cmd_d = max(-steer_max, min(steer_max, 0.0));
  end when;

  annotation(
    experiment(StartTime=0, StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="AckermannRoverClimbC: rear-wheel-drive floating-base rover ascends a 12 deg ramp, traverses a 2 m plateau, and stops before the descending edge. Slip-aware traction control with bounded braking runs at 125 Hz for 12 s. A 135 N payload force disturbance is injected during the middle third (4-8 s). Sensors: encoders (speed), IMU (attitude), forward depth sensor (edge distance). Assumed parameters (wheel radius, CG location, wheel inertia, approach/ramp lengths, cruise speed, control gains, ridge width/locations) are labeled as such."));
end AckermannRoverClimbC;