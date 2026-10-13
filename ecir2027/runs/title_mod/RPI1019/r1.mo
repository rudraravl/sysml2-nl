model OmniCartClimbE
  // ================================================================
  // OmniCartClimbE — Floating-base mecanum mobile robot
  // Ascends 12 deg ramp, traverses 2 m plateau, stops before edge
  // ================================================================

  // ---- Physical parameters ----
  parameter Real m_body = 25.0     "Platform mass [kg]";
  parameter Real m_wheel = 2.0      "Wheel mass [kg]";
  parameter Real r_w = 0.095        "Wheel radius [m]";
  parameter Real J_w = 0.5*m_wheel*r_w^2 "Wheel inertia [kg.m2]";
  parameter Real L = 0.58           "Footprint length [m]";
  parameter Real W_fp = 0.46        "Footprint width [m]";
  parameter Real gamma_deg = 45.0    "Mecanum roller angle [deg]";
  parameter Real mu = 0.76          "Friction coefficient [1]";
  parameter Real tau_max = 13.2     "Max wheel torque [N.m]";
  parameter Real g = 9.81           "Gravitational acceleration [m/s2]";
  parameter Real c_roll = 0.01      "Rolling resistance coefficient [1]";

  // ---- Terrain parameters ----
  parameter Real ramp_angle_rad = 12.0*3.14159265358979/180 "Ramp angle [rad]";
  parameter Real ramp_tan_val  = tan(ramp_angle_rad)        "Ramp tangent [1]";
  parameter Real x_ramp_start  = 1.0  "Ramp start x [m]";
  parameter Real x_ramp_end    = 2.0  "Ramp end / plateau start x [m]";
  parameter Real x_plateau_end = 4.0  "Plateau end / descending edge x [m]";
  parameter Real x_ridge1      = 2.5  "First ridge center x [m]";
  parameter Real x_ridge2      = 3.5  "Second ridge center x [m]";
  parameter Real ridge_height  = 0.05 "Ridge height [m]";
  parameter Real ridge_half_w  = 0.05 "Ridge half-width [m]";
  parameter Real plateau_len   = 2.0  "Plateau length [m]";

  // ---- Control parameters ----
  parameter Real dt_ctrl    = 1.0/250.0 "Control sample time [s]";
  parameter Real F_payload   = 180.0     "Payload disturbance force [N]";
  parameter Real v_cruise    = 0.45      "Cruise velocity reference [m/s]";
  parameter Real stop_margin = 0.40      "Stopping margin before edge [m]";
  parameter Real ramp_time   = 0.5       "Velocity reference ramp time [s]";
  parameter Real Kp_f        = 70.0      "Velocity proportional gain [N.s/m]";
  parameter Real Kp_w        = 0.3       "Wheel speed proportional gain [N.m.s/rad]";
  parameter Real slip_limit  = 0.35      "Slip ratio limit [1]";
  parameter Real slip_warn   = 0.15      "Slip warning threshold [1]";
  parameter Real pitch_limit = 0.40      "Pitch limit [rad]";
  parameter Real roll_limit  = 0.40      "Roll limit [rad]";
  parameter Real track_limit = 0.162     "Tracking error limit [m/s]";
  parameter Real T_sim       = 16.0      "Simulation duration [s]";

  // ---- Body states ----
  Real x_pos(start=0.0)    "Body x position [m]";
  Real vx(start=0.0)       "Body longitudinal velocity [m/s]";
  Real z_pos(start=r_w)    "Body z position [m]";
  Real y_pos(start=0.0)    "Body lateral position [m]";
  Real vy(start=0.0)       "Body lateral velocity [m/s]";
  Real yaw(start=0.0)      "Body yaw angle [rad]";
  Real yaw_rate(start=0.0) "Body yaw rate [rad/s]";
  Real pitch(start=0.0)    "Body pitch angle [rad]";
  Real roll(start=0.0)      "Body roll angle [rad]";

  // ---- Wheel states ----
  Real w1(start=0.0) "FL wheel angular velocity [rad/s]";
  Real w2(start=0.0) "FR wheel angular velocity [rad/s]";
  Real w3(start=0.0) "RL wheel angular velocity [rad/s]";
  Real w4(start=0.0) "RR wheel angular velocity [rad/s]";

  // ---- Terrain ----
  Real terrain_h   "Terrain height at body x [m]";
  Real terrain_s   "Terrain slope at body x [rad]";
  Real ridge_local "Local ridge height contribution [m]";

  // ---- Forces ----
  Real F_payload_active "Active payload weight [N]";
  Real m_eff           "Effective mass incl payload [kg]";
  Real F_grav_long     "Gravity longitudinal component [N]";
  Real F_roll_res      "Rolling resistance force [N]";
  Real N_total         "Total normal force [N]";
  Real N1, N2, N3, N4  "Per-wheel normal forces [N]";
  Real F1, F2, F3, F4  "Per-wheel traction forces [N]";

  // ---- Slip ----
  Real s1, s2, s3, s4      "Wheel slip ratios [1]";
  Real vw1, vw2, vw3, vw4 "Wheel contact velocities [m/s]";
  Real sd1, sd2, sd3, sd4 "Slip denominators [m/s]";

  // ---- Sensors ----
  Real v_enc     "Encoder-measured forward speed [m/s]";
  Real v_lat_enc "Encoder-measured lateral speed [m/s]";
  Real pitch_imu "IMU-measured pitch [rad]";
  Real roll_imu  "IMU-measured roll [rad]";
  Real edge_dist "Depth sensor edge distance [m]";

  // ---- Continuous control ----
  Real v_ref   "Reference velocity [m/s]";
  Real v_err   "Velocity tracking error [m/s]";
  Real grav_comp "Gravity compensation force [N]";
  Real F_des   "Desired total traction force [N]";
  Real rt1, rt2, rt3, rt4 "Unsaturated torque commands [N.m]";
  Real sf1, sf2, sf3, sf4 "Slip-aware reduction factors [1]";

  // ---- Discrete control (250 Hz) ----
  discrete Real v_ref_d(start=0.0) "Discrete ref velocity [m/s]";
  discrete Real tc1(start=0.0)     "Discrete torque cmd w1 [N.m]";
  discrete Real tc2(start=0.0)     "Discrete torque cmd w2 [N.m]";
  discrete Real tc3(start=0.0)     "Discrete torque cmd w3 [N.m]";
  discrete Real tc4(start=0.0)     "Discrete torque cmd w4 [N.m]";
  discrete Integer ctrl_step(start=0) "Control step counter [1]";

  // ---- Acceptance monitoring ----
  Boolean actuator_ok(start=true) "Actuator limits satisfied";
  Boolean slip_ok(start=true)     "Slip below 0.35";
  Boolean attitude_ok(start=true) "Roll/pitch below 0.40 rad";
  Boolean stop_ok(start=true)     "Stopped before descending edge";
  Boolean track_ok(start=true)   "Tracking error below 0.162 after 10.4 s";
  Boolean no_nan(start=true)     "No NaN or infinite values";
  Boolean fail_closed(start=false) "Fail-closed aggregate flag";
  Real slip_max_obs  "Max slip magnitude across wheels [1]";
  Real track_err_obs "Current tracking error magnitude [m/s]";

equation
  // ===================== Terrain profile =====================
  if x_pos < x_ramp_start then
    terrain_h = 0.0;
    terrain_s = 0.0;
  elseif x_pos < x_ramp_end then
    terrain_h = (x_pos - x_ramp_start) * ramp_tan_val;
    terrain_s = ramp_angle_rad;
  else
    terrain_h = ramp_tan_val;
    terrain_s = 0.0;
  end if;

  // Ridge bumps (triangular, width = 2*ridge_half_w)
  if abs(x_pos - x_ridge1) < ridge_half_w then
    ridge_local = ridge_height * (1.0 - abs(x_pos - x_ridge1)/ridge_half_w);
  elseif abs(x_pos - x_ridge2) < ridge_half_w then
    ridge_local = ridge_height * (1.0 - abs(x_pos - x_ridge2)/ridge_half_w);
  else
    ridge_local = 0.0;
  end if;

  // Body height follows terrain
  z_pos = terrain_h + ridge_local + r_w;

  // ===================== Attitude dynamics =====================
  // Pitch tracks terrain slope with first-order lag
  der(pitch) = 6.0 * (terrain_s - pitch);
  // Roll: damped, stays near zero on symmetric terrain
  der(roll) = -5.0 * roll;

  // ===================== Payload =====================
  // 180 N downward payload during middle third of 16 s: [5.333, 10.667] s
  if time >= 5.333 and time <= 10.667 then
    F_payload_active = F_payload;
  else
    F_payload_active = 0.0;
  end if;
  m_eff = m_body + F_payload_active / g;

  // ===================== Forces =====================
  F_grav_long = m_eff * g * sin(pitch);
  N_total     = m_eff * g * cos(pitch) + 4.0*m_wheel*g;
  F_roll_res  = c_roll * N_total * vx / sqrt(vx*vx + 0.0001);
  N1 = N_total/4.0;
  N2 = N_total/4.0;
  N3 = N_total/4.0;
  N4 = N_total/4.0;

  // ===================== Slip & traction =====================
  vw1 = w1 * r_w;
  vw2 = w2 * r_w;
  vw3 = w3 * r_w;
  vw4 = w4 * r_w;

  // Smooth, non-singular slip denominators
  sd1 = max(max(abs(vw1), abs(vx)), 0.05);
  sd2 = max(max(abs(vw2), abs(vx)), 0.05);
  sd3 = max(max(abs(vw3), abs(vx)), 0.05);
  sd4 = max(max(abs(vw4), abs(vx)), 0.05);

  s1 = (vw1 - vx) / sd1;
  s2 = (vw2 - vx) / sd2;
  s3 = (vw3 - vx) / sd3;
  s4 = (vw4 - vx) / sd4;

  // Saturating friction model
  F1 = if s1 > slip_limit then mu*N1 elseif s1 < -slip_limit then -mu*N1 else mu*N1*s1/slip_limit;
  F2 = if s2 > slip_limit then mu*N2 elseif s2 < -slip_limit then -mu*N2 else mu*N2*s2/slip_limit;
  F3 = if s3 > slip_limit then mu*N3 elseif s3 < -slip_limit then -mu*N3 else mu*N3*s3/slip_limit;
  F4 = if s4 > slip_limit then mu*N4 elseif s4 < -slip_limit then -mu*N4 else mu*N4*s4/slip_limit;

  // ===================== Wheel dynamics =====================
  J_w * der(w1) = tc1 - F1*r_w;
  J_w * der(w2) = tc2 - F2*r_w;
  J_w * der(w3) = tc3 - F3*r_w;
  J_w * der(w4) = tc4 - F4*r_w;

  // ===================== Body dynamics =====================
  der(x_pos) = vx;
  der(vx)    = (F1 + F2 + F3 + F4 - F_grav_long - F_roll_res) / m_body;
  der(y_pos) = vy;
  der(vy)    = -3.0 * vy;
  der(yaw)   = yaw_rate;
  der(yaw_rate) = -4.0 * yaw_rate;

  // ===================== Sensors =====================
  // Mecanum forward kinematics from encoders
  v_enc     = r_w*(w1 + w2 + w3 + w4)/4.0;
  v_lat_enc = r_w*(-w1 + w2 + w3 - w4)/4.0;
  pitch_imu = pitch;
  roll_imu  = roll;
  edge_dist = x_plateau_end - x_pos;

  // ===================== Continuous control computation =====================
  v_ref     = v_ref_d;
  v_err     = v_ref - v_enc;
  grav_comp = m_eff * g * sin(pitch);
  F_des     = Kp_f * v_err + grav_comp;

  // Per-wheel torque: equal share for forward motion + wheel speed regulation
  rt1 = F_des*r_w/4.0 + Kp_w*(v_ref/r_w - w1);
  rt2 = F_des*r_w/4.0 + Kp_w*(v_ref/r_w - w2);
  rt3 = F_des*r_w/4.0 + Kp_w*(v_ref/r_w - w3);
  rt4 = F_des*r_w/4.0 + Kp_w*(v_ref/r_w - w4);

  // Slip-aware reduction factors (reduce torque as slip approaches limit)
  sf1 = if abs(s1) > slip_warn then max(0.0, 1.0 - (abs(s1)-slip_warn)/(slip_limit-slip_warn)) else 1.0;
  sf2 = if abs(s2) > slip_warn then max(0.0, 1.0 - (abs(s2)-slip_warn)/(slip_limit-slip_warn)) else 1.0;
  sf3 = if abs(s3) > slip_warn then max(0.0, 1.0 - (abs(s3)-slip_warn)/(slip_limit-slip_warn)) else 1.0;
  sf4 = if abs(s4) > slip_warn then max(0.0, 1.0 - (abs(s4)-slip_warn)/(slip_limit-slip_warn)) else 1.0;

  // ===================== Discrete control at 250 Hz =====================
  when sample(0, dt_ctrl) then
    ctrl_step = pre(ctrl_step) + 1;

    // Reference velocity with bounded ramp-up / ramp-down (bounded braking)
    if x_pos < x_plateau_end - stop_margin then
      v_ref_d = min(v_cruise, pre(v_ref_d) + v_cruise*dt_ctrl/ramp_time);
    else
      v_ref_d = max(0.0, pre(v_ref_d) - v_cruise*dt_ctrl/ramp_time);
    end if;

    // Saturated, slip-aware torque commands (actuator limit enforcement)
    tc1 = if rt1*sf1 > tau_max then tau_max elseif rt1*sf1 < -tau_max then -tau_max else rt1*sf1;
    tc2 = if rt2*sf2 > tau_max then tau_max elseif rt2*sf2 < -tau_max then -tau_max else rt2*sf2;
    tc3 = if rt3*sf3 > tau_max then tau_max elseif rt3*sf3 < -tau_max then -tau_max else rt3*sf3;
    tc4 = if rt4*sf4 > tau_max then tau_max elseif rt4*sf4 < -tau_max then -tau_max else rt4*sf4;
  end when;

  // ===================== Acceptance monitoring =====================
  // Actuator limits
  actuator_ok = abs(tc1) <= tau_max + 0.001 and abs(tc2) <= tau_max + 0.001
              and abs(tc3) <= tau_max + 0.001 and abs(tc4) <= tau_max + 0.001;

  // Slip ratio
  slip_max_obs = max(max(abs(s1), abs(s2)), max(abs(s3), abs(s4)));
  slip_ok      = slip_max_obs < slip_limit;

  // Attitude
  attitude_ok = abs(pitch) < pitch_limit and abs(roll) < roll_limit;

  // Stopping margin (must remain before descending edge)
  stop_ok = x_pos < x_plateau_end - 0.01;

  // Tracking error after 10.4 s
  track_err_obs = abs(v_err);
  track_ok      = if time >= 10.4 then track_err_obs < track_limit else true;

  // NaN / infinity guard on key physical, control, and estimator values
  no_nan = x_pos > -1000.0 and x_pos < 1000.0
         and vx > -100.0 and vx < 100.0
         and pitch > -10.0 and pitch < 10.0
         and roll > -10.0 and roll < 10.0
         and w1 > -1000.0 and w1 < 1000.0
         and w2 > -1000.0 and w2 < 1000.0
         and w3 > -1000.0 and w3 < 1000.0
         and w4 > -1000.0 and w4 < 1000.0
         and tc1 > -1000.0 and tc1 < 1000.0
         and v_enc > -100.0 and v_enc < 100.0
         and edge_dist > -100.0 and edge_dist < 100.0;

  // Fail-closed: any acceptance violation triggers
  fail_closed = not actuator_ok or not slip_ok or not attitude_ok
              or not stop_ok or not track_ok or not no_nan;

  annotation(
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="OmniCartClimbE: 25 kg mecanum platform (0.58 x 0.46 m footprint, four 0.095 m radius wheels at 45 deg roller angle) ascending 12 deg ramp, traversing 2 m plateau with two 0.05 m ridges, stopping before descending edge. Slip-aware traction control at 250 Hz with 13.2 N.m torque limit. 180 N payload disturbance in middle third. Friction 0.76. Acceptance: actuator limits, slip < 0.35, roll/pitch < 0.40 rad, stop margin, tracking error < 0.162 m/s after 10.4 s, no NaN/infinite, fail-closed.")
  );
end OmniCartClimbE;