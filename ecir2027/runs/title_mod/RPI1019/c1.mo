model OmniCartClimbE "Floating-base mecanum robot: ascend 12 deg ramp, traverse 2 m plateau, stop before edge"

  constant Real g = 9.81 "Gravitational acceleration [m/s2]";
  constant Real pi = 3.141592653589793 "pi constant";

  // Platform parameters (from requirement)
  parameter Real m = 25.0 "Platform mass [kg]";
  parameter Real Lx = 0.58 "Footprint length [m]";
  parameter Real Ly = 0.46 "Footprint width [m]";
  parameter Real r_w = 0.095 "Wheel radius [m]";
  parameter Real gamma_deg = 45.0 "Mecanum roller angle [deg]";
  parameter Real mu = 0.76 "Friction coefficient";
  parameter Real tau_max = 13.2 "Max wheel torque [N.m]";

  // Derived/assumed platform parameters
  parameter Real h_pl = 0.08 "Platform thickness [m] - assumed";
  parameter Real I_pitch = m * (Lx ^ 2 + 4.0 * h_pl ^ 2) / 12.0 "Pitch inertia [kg.m2] - assumed";
  parameter Real I_roll = m * (Ly ^ 2 + 4.0 * h_pl ^ 2) / 12.0 "Roll inertia [kg.m2] - assumed";
  parameter Real J_w = 0.015 "Wheel inertia [kg.m2] - assumed";
  parameter Real k_pitch = 800.0 "Pitch stiffness [N.m/rad] - assumed";
  parameter Real c_pitch = 30.0 "Pitch damping [N.m.s/rad] - assumed";
  parameter Real k_roll = 600.0 "Roll stiffness [N.m/rad] - assumed";
  parameter Real c_roll = 20.0 "Roll damping [N.m.s/rad] - assumed";
  parameter Real b_visc = 1.5 "Viscous drag [N.s/m] - assumed";
  parameter Real b_w = 0.002 "Wheel damping [N.m.s/rad] - assumed";
  parameter Real k_slip = 40.0 "Traction slip stiffness [1/(m/s)] - assumed";

  // Terrain parameters
  parameter Real ramp_angle_deg = 12.0 "Ramp angle [deg]";
  parameter Real ramp_angle = ramp_angle_deg * pi / 180.0 "Ramp angle [rad]";
  parameter Real x_ramp_start = 0.5 "Ramp start [m] - assumed";
  parameter Real ramp_length = 1.5 "Ramp length [m] - assumed";
  parameter Real plateau_length = 2.0 "Plateau length [m]";
  parameter Real h_ridge = 0.05 "Ridge height [m]";
  parameter Real x_ridge1 = 1.2 "First ridge position [m] - assumed";
  parameter Real x_ridge2 = 3.2 "Second ridge position [m] - assumed";
  parameter Real ridge_width = 0.04 "Ridge width [m] - assumed";
  parameter Real x_edge = x_ramp_start + ramp_length + plateau_length "Descending edge [m]";

  // Disturbance parameters
  parameter Real F_payload = 180.0 "Payload disturbance force [N]";
  parameter Real t_dist_start = 16.0 / 3.0 "Disturbance start [s] - middle third";
  parameter Real t_dist_end = 2.0 * 16.0 / 3.0 "Disturbance end [s] - middle third";
  parameter Real d_roll_offset = Ly / 6.0 "Payload lateral offset [m] - assumed";

  // Control parameters
  parameter Real Ts = 1.0 / 250.0 "Control sample period [s]";
  parameter Real v_approach = 0.3 "Approach speed [m/s] - assumed";
  parameter Real v_cruise = 0.4 "Cruise speed [m/s] - assumed";
  parameter Real x_stop = x_edge - 0.25 "Stop position with margin [m] - 0.25 m margin assumed";
  parameter Real stop_trigger_dist = 0.35 "Stop trigger distance [m] - assumed";
  parameter Real kp_v = 100.0 "Speed P gain - assumed";
  parameter Real ki_v = 20.0 "Speed I gain - assumed";
  parameter Real slip_thresh = 0.25 "Slip control threshold - assumed";
  parameter Real slip_limit = 0.35 "Slip limit (acceptance)";
  parameter Real roll_limit = 0.40 "Roll limit [rad] (acceptance)";
  parameter Real pitch_limit = 0.40 "Pitch limit [rad] (acceptance)";
  parameter Real track_err_limit = 0.162 "Tracking error limit after 10.4 s [m/s]";
  parameter Real t_track_check = 10.4 "Tracking error check time [s]";
  parameter Real eps_v = 0.01 "Velocity epsilon [m/s]";

  // Continuous states
  Real x_pos(start = 0.0, fixed = true) "Longitudinal position [m]";
  Real v_x(start = 0.0, fixed = true) "Longitudinal velocity [m/s]";
  Real pitch(start = 0.0, fixed = true) "Platform pitch [rad]";
  Real pitch_rate(start = 0.0, fixed = true) "Pitch rate [rad/s]";
  Real roll(start = 0.0, fixed = true) "Platform roll [rad]";
  Real roll_rate(start = 0.0, fixed = true) "Roll rate [rad/s]";
  Real omega1(start = 0.0, fixed = true) "Wheel 1 angular velocity [rad/s]";
  Real omega2(start = 0.0, fixed = true) "Wheel 2 angular velocity [rad/s]";
  Real omega3(start = 0.0, fixed = true) "Wheel 3 angular velocity [rad/s]";
  Real omega4(start = 0.0, fixed = true) "Wheel 4 angular velocity [rad/s]";

  // Discrete control states
  discrete Real err_int_d(start = 0.0) "Discrete error integral";
  discrete Real tau1_cmd_d(start = 0.0) "Wheel 1 torque command [N.m]";
  discrete Real tau2_cmd_d(start = 0.0) "Wheel 2 torque command [N.m]";
  discrete Real tau3_cmd_d(start = 0.0) "Wheel 3 torque command [N.m]";
  discrete Real tau4_cmd_d(start = 0.0) "Wheel 4 torque command [N.m]";
  discrete Real track_err_d(start = 0.0) "Discrete tracking error [m/s]";
  discrete Boolean fault_latch(start = false) "Latched fault flag";

  // Terrain outputs
  Real z_base "Base terrain height [m]";
  Real z_ridge1 "Ridge 1 contribution [m]";
  Real z_ridge2 "Ridge 2 contribution [m]";
  Real z_terrain "Total terrain height [m]";
  Real slope_terrain "Terrain slope [rad]";
  Real edge_dist "Distance to descending edge [m]";

  // Disturbance outputs
  Real F_dist "Payload disturbance force [N]";
  Real M_roll_dist "Roll moment from payload offset [N.m]";
  Real M_roll_ridge "Roll moment from ridge crossing [N.m]";

  // Reference and tracking
  Real v_ref "Reference speed [m/s]";
  Real track_err "Tracking error [m/s]";

  // Torque
  Real tau1_cmd "Wheel 1 commanded torque [N.m]";
  Real tau2_cmd "Wheel 2 commanded torque [N.m]";
  Real tau3_cmd "Wheel 3 commanded torque [N.m]";
  Real tau4_cmd "Wheel 4 commanded torque [N.m]";
  Real tau1_act "Wheel 1 actual torque [N.m]";
  Real tau2_act "Wheel 2 actual torque [N.m]";
  Real tau3_act "Wheel 3 actual torque [N.m]";
  Real tau4_act "Wheel 4 actual torque [N.m]";

  // Slip
  Real slip1 "Wheel 1 slip ratio";
  Real slip2 "Wheel 2 slip ratio";
  Real slip3 "Wheel 3 slip ratio";
  Real slip4 "Wheel 4 slip ratio";
  Real slip_max_val "Maximum slip ratio";

  // Forces
  Real F_tr1 "Wheel 1 traction force [N]";
  Real F_tr2 "Wheel 2 traction force [N]";
  Real F_tr3 "Wheel 3 traction force [N]";
  Real F_tr4 "Wheel 4 traction force [N]";
  Real F_tr_total "Total traction force [N]";
  Real F_grav "Gravity resistance force [N]";
  Real N_per_wheel "Normal force per wheel [N]";

  // Sensors
  Real v_enc "Encoder-measured speed [m/s]";
  Real roll_imu "IMU-measured roll [rad]";
  Real pitch_imu "IMU-measured pitch [rad]";
  Real depth_sens "Depth sensor reading [m]";

  // Fault flags
  Boolean fault_actuator "Actuator limit violated";
  Boolean fault_slip "Slip limit violated";
  Boolean fault_roll "Roll limit violated";
  Boolean fault_pitch "Pitch limit violated";
  Boolean fault_tracking "Tracking error violated";
  Boolean fault_stop "Stopping margin violated";
  Boolean fault_nan "NaN/Inf detected";
  Boolean fail_closed "Fail-closed active";

protected
  Real v_safe "Safe velocity for slip computation";
  discrete Real torque_raw_local(start = 0.0) "Raw torque before saturation";
  discrete Real slip_scale_local(start = 1.0) "Slip-based torque scaling";

equation
  // Terrain model
  z_base = if x_pos < x_ramp_start then 0.0
    elseif x_pos < x_ramp_start + ramp_length then (x_pos - x_ramp_start) * tan(ramp_angle)
    elseif x_pos < x_ramp_start + ramp_length + plateau_length then ramp_length * tan(ramp_angle)
    else ramp_length * tan(ramp_angle) - (x_pos - x_ramp_start - ramp_length - plateau_length) * tan(ramp_angle);

  z_ridge1 = if abs(x_pos - x_ridge1) < ridge_width / 2.0
    then h_ridge * (1.0 + cos(2.0 * pi * (x_pos - x_ridge1) / ridge_width)) / 2.0
    else 0.0;

  z_ridge2 = if abs(x_pos - x_ridge2) < ridge_width / 2.0
    then h_ridge * (1.0 + cos(2.0 * pi * (x_pos - x_ridge2) / ridge_width)) / 2.0
    else 0.0;

  z_terrain = z_base + z_ridge1 + z_ridge2;

  slope_terrain = if x_pos < x_ramp_start then 0.0
    elseif x_pos < x_ramp_start + ramp_length then ramp_angle
    elseif x_pos < x_ramp_start + ramp_length + plateau_length then 0.0
    else -ramp_angle;

  edge_dist = max(0.0, x_edge - x_pos);
  depth_sens = edge_dist;

  // Forces
  N_per_wheel = m * g * cos(pitch) / 4.0;
  F_grav = m * g * sin(pitch);

  // Disturbance
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_payload else 0.0;
  M_roll_dist = F_dist * d_roll_offset;
  M_roll_ridge = if abs(x_pos - x_ridge1) < ridge_width / 2.0 or abs(x_pos - x_ridge2) < ridge_width / 2.0
    then h_ridge * m * g * 0.02
    else 0.0;

  // Reference speed
  v_ref = if x_pos < x_ramp_start - 0.1 then v_approach
    elseif x_pos < x_stop - 0.4 then v_cruise
    elseif x_pos < x_stop then v_cruise * max(0.0, (x_stop - x_pos) / 0.4)
    else 0.0;

  track_err = v_ref - v_x;

  // Slip ratios
  v_safe = if abs(v_x) > eps_v then v_x else eps_v;
  slip1 = (omega1 * r_w - v_x) / max(abs(v_safe), 1e-6);
  slip2 = (omega2 * r_w - v_x) / max(abs(v_safe), 1e-6);
  slip3 = (omega3 * r_w - v_x) / max(abs(v_safe), 1e-6);
  slip4 = (omega4 * r_w - v_x) / max(abs(v_safe), 1e-6);
  slip_max_val = max(abs(slip1), max(abs(slip2), max(abs(slip3), abs(slip4))));

  // Traction forces (tanh friction model)
  F_tr1 = mu * N_per_wheel * tanh(k_slip * (omega1 * r_w - v_x));
  F_tr2 = mu * N_per_wheel * tanh(k_slip * (omega2 * r_w - v_x));
  F_tr3 = mu * N_per_wheel * tanh(k_slip * (omega3 * r_w - v_x));
  F_tr4 = mu * N_per_wheel * tanh(k_slip * (omega4 * r_w - v_x));
  F_tr_total = F_tr1 + F_tr2 + F_tr3 + F_tr4;

  // Wheel dynamics
  J_w * der(omega1) = tau1_act - F_tr1 * r_w - b_w * omega1;
  J_w * der(omega2) = tau2_act - F_tr2 * r_w - b_w * omega2;
  J_w * der(omega3) = tau3_act - F_tr3 * r_w - b_w * omega3;
  J_w * der(omega4) = tau4_act - F_tr4 * r_w - b_w * omega4;

  // Longitudinal dynamics
  m * der(v_x) = F_tr_total - F_grav - F_dist - b_visc * v_x;
  der(x_pos) = v_x;

  // Pitch dynamics (terrain following)
  I_pitch * der(pitch_rate) = k_pitch * (slope_terrain - pitch) - c_pitch * pitch_rate;
  der(pitch) = pitch_rate;

  // Roll dynamics (disturbed by payload offset and ridges)
  I_roll * der(roll_rate) = -k_roll * roll - c_roll * roll_rate + M_roll_dist + M_roll_ridge;
  der(roll) = roll_rate;

  // Sensors
  v_enc = (omega1 + omega2 + omega3 + omega4) * r_w / 4.0;
  roll_imu = roll;
  pitch_imu = pitch;

  // Discrete control at 250 Hz
  when sample(0, Ts) then
    // Tracking error
    track_err_d = v_ref - v_enc;

    // Integral with anti-windup
    err_int_d = max(-5.0, min(5.0, pre(err_int_d) + track_err_d * Ts));

    // Slip-aware torque scaling
    if slip_max_val > slip_thresh then
      slip_scale_local = max(0.3, 1.0 - (slip_max_val - slip_thresh) / (slip_limit - slip_thresh));
    else
      slip_scale_local = 1.0;
    end if;

    // Raw torque command
    torque_raw_local = kp_v * track_err_d + ki_v * err_int_d;

    // Fault detection and latch
    if (slip_max_val > slip_limit) or (abs(roll) > roll_limit) or (abs(pitch) > pitch_limit) or
       ((time > t_track_check) and (abs(track_err) > track_err_limit)) or
       ((x_pos > x_edge - 0.05) and (abs(v_x) > 0.05)) or
       not (x_pos > -1e6 and x_pos < 1e6 and v_x > -1e6 and v_x < 1e6 and
            roll > -1e2 and roll < 1e2 and pitch > -1e2 and pitch < 1e2) then
      fault_latch = true;
    else
      fault_latch = pre(fault_latch);
    end if;

    // Torque commands with fail-closed and bounded braking
    if fault_latch then
      tau1_cmd_d = 0.0;
      tau2_cmd_d = 0.0;
      tau3_cmd_d = 0.0;
      tau4_cmd_d = 0.0;
    elseif depth_sens < stop_trigger_dist then
      tau1_cmd_d = max(-tau_max, min(tau_max, (-kp_v * v_enc - ki_v * err_int_d) * slip_scale_local / 4.0));
      tau2_cmd_d = tau1_cmd_d;
      tau3_cmd_d = tau1_cmd_d;
      tau4_cmd_d = tau1_cmd_d;
    else
      tau1_cmd_d = max(-tau_max, min(tau_max, torque_raw_local * slip_scale_local / 4.0));
      tau2_cmd_d = tau1_cmd_d;
      tau3_cmd_d = tau1_cmd_d;
      tau4_cmd_d = tau1_cmd_d;
    end if;
  end when;

  // Torque application
  tau1_cmd = tau1_cmd_d;
  tau2_cmd = tau2_cmd_d;
  tau3_cmd = tau3_cmd_d;
  tau4_cmd = tau4_cmd_d;

  // Actuator saturation with fail-closed
  tau1_act = if fault_latch then 0.0 else max(-tau_max, min(tau_max, tau1_cmd));
  tau2_act = if fault_latch then 0.0 else max(-tau_max, min(tau_max, tau2_cmd));
  tau3_act = if fault_latch then 0.0 else max(-tau_max, min(tau_max, tau3_cmd));
  tau4_act = if fault_latch then 0.0 else max(-tau_max, min(tau_max, tau4_cmd));

  // Continuous fault detection
  fault_actuator = abs(tau1_cmd) > tau_max + 0.01 or abs(tau2_cmd) > tau_max + 0.01 or
                   abs(tau3_cmd) > tau_max + 0.01 or abs(tau4_cmd) > tau_max + 0.01;
  fault_slip = slip_max_val > slip_limit;
  fault_roll = abs(roll) > roll_limit;
  fault_pitch = abs(pitch) > pitch_limit;
  fault_tracking = time > t_track_check and abs(track_err) > track_err_limit;
  fault_stop = x_pos > x_edge - 0.05 and abs(v_x) > 0.05;
  fault_nan = not (x_pos > -1e6 and x_pos < 1e6 and v_x > -1e6 and v_x < 1e6 and
                   roll > -1e2 and roll < 1e2 and pitch > -1e2 and pitch < 1e2 and
                   tau1_act > -1e6 and tau1_act < 1e6 and slip_max_val >= 0.0 and slip_max_val < 1e6);
  fail_closed = fault_latch or fault_actuator or fault_slip or fault_roll or
                fault_pitch or fault_tracking or fault_stop or fault_nan;

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "OmniCartClimbE: 25 kg mecanum-wheeled platform (0.58x0.46 m footprint, four 0.095 m-radius wheels at 45 deg roller angle). Ascends 12 deg ramp, traverses 2 m plateau, stops before descending edge. Slip-aware traction control at 250 Hz with bounded braking. 180 N payload disturbance during middle third. Two 0.05 m ridges. Friction 0.76. Actuator limit 13.2 N.m. Fail-closed acceptance: slip < 0.35, roll/pitch < 0.40 rad, tracking error < 0.162 m/s after 10.4 s, stopping margin, no NaN/Inf.")
  );

end OmniCartClimbE;