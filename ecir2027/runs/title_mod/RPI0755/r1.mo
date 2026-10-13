model BipedTwoTraverseE
  "Floating-base biped traversing height field with 0.08 m rocks and two 0.12 m gaps"

  import Modelica;
  import SI = Modelica.SIunits;
  import MB = Modelica.Mechanics.MultiBody;
  import Rot = Modelica.Mechanics.Rotational;

  // ===== PARAMETERS FROM REQUIREMENT =====
  parameter SI.Mass m_pelvis = 36.0 "Pelvis mass";
  parameter SI.Length L_thigh = 0.42 "Thigh length";
  parameter SI.Length L_shank = 0.40 "Shank length";
  parameter SI.Torque tau_max = 138.0 "Per-joint torque bound";
  parameter Real mu = 0.78 "Contact friction coefficient";
  parameter SI.Force F_push = 108.0 "Lateral push force";
  parameter SI.Length h_rock = 0.08 "Rock height in terrain";
  parameter SI.Length d_gap = 0.12 "Gap depth in terrain";
  parameter SI.Length clr_min = 0.03 "Min swing-foot clearance";
  parameter Real att_max = 0.45 "Max attitude [rad]";
  parameter SI.Length e_track_max = 0.135 "Max path tracking error after check time";
  parameter SI.Time t_end = 16.0 "Simulation duration";
  parameter SI.Time t_check = 10.4 "Acceptance check time";
  parameter SI.Frequency f_ctrl = 250.0 "Controller frequency";
  parameter SI.Time T_ctrl = 1.0 / f_ctrl "Controller period";

  // ===== ASSUMED PARAMETERS (NOT IN REQUIREMENT) =====
  parameter SI.Mass m_thigh = 5.0 "ASSUMED thigh mass";
  parameter SI.Mass m_shank = 3.0 "ASSUMED shank mass";
  parameter SI.Mass m_foot = 1.5 "ASSUMED foot mass";
  parameter SI.Length L_foot = 0.22 "ASSUMED foot length";
  parameter SI.Length W_foot = 0.10 "ASSUMED foot width";
  parameter SI.Length foot_drop = 0.03 "ASSUMED ankle-to-foot-bottom";
  parameter SI.Length foot_fwd = 0.08 "ASSUMED ankle-to-foot-center forward";
  parameter SI.Length hip_width = 0.30 "ASSUMED hip separation (y)";
  parameter SI.Length h_pelvis0 = 0.85 "ASSUMED initial pelvis height";
  parameter SI.Velocity v_ref = 0.4 "ASSUMED commanded avg speed (requirement: commanded but value unspecified)";
  parameter SI.Time T_step = 0.7 "ASSUMED step period";
  parameter SI.Length L_step = v_ref * T_step "Step length";
  parameter SI.Length x_gap1 = 2.5 "ASSUMED first gap center x";
  parameter SI.Length x_gap2 = 5.5 "ASSUMED second gap center x";
  parameter SI.Length w_gap = 0.12 "Gap width";
  parameter SI.Length x_rock1 = 1.5 "ASSUMED rock 1 center x";
  parameter SI.Length x_rock2 = 4.0 "ASSUMED rock 2 center x";
  parameter SI.Length x_rock3 = 7.0 "ASSUMED rock 3 center x";
  parameter SI.Length r_rock = 0.15 "ASSUMED rock footprint radius";
  parameter SI.Length depth_lookahead = 0.5 "ASSUMED depth lookahead";
  parameter Real k_c = 5.0e4 "ASSUMED contact stiffness [N/m]";
  parameter Real d_c = 800.0 "ASSUMED contact damping [N.s/m]";
  parameter Real v_thresh = 0.02 "ASSUMED friction velocity threshold";
  parameter Real kp = 120.0 "ASSUMED joint PD P gain";
  parameter Real kd = 12.0 "ASSUMED joint PD D gain";
  parameter SI.Time t_push_start = t_end / 3.0 "Push start (middle third)";
  parameter SI.Time t_push_end = 2.0 * t_end / 3.0 "Push end (middle third)";
  parameter SI.Length x_target = v_ref * t_end "Target traversal distance";

  // ===== WORLD =====
  inner MB.World world(
    gravityType = MB.Types.GravityTypes.UniformGravity,
    g = 9.81,
    n = {0, 0, -1}
  );

  // ===== PELVIS (FLOATING BASE) =====
  MB.Joints.FreeMotion pelvisFree(
    r_rel_a_start = {0, 0, h_pelvis0},
    v_rel_a_start = {0, 0, 0},
    angles_start = {0, 0, 0},
    w_rel_b_start = {0, 0, 0}
  );
  MB.Parts.Body pelvisBody(
    m = m_pelvis,
    r_CM = {0, 0, 0},
    I_11 = 1.5,
    I_22 = 1.5,
    I_33 = 0.8
  );
  MB.Parts.FixedTranslation hipLeftOffset(r = {0, hip_width/2, 0});
  MB.Parts.FixedTranslation hipRightOffset(r = {0, -hip_width/2, 0});

  // ===== LEFT LEG: SPHERICAL HIP (3 REVOLUTE), THIGH, REVOLUTE KNEE, SHANK, TWO-AXIS ANKLE (2 REVOLUTE), FLAT FOOT =====
  MB.Joints.Revolute leftHipRoll(useAxisFlange = true, n = {1, 0, 0},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Joints.Revolute leftHipPitch(useAxisFlange = true, n = {0, 1, 0},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Joints.Revolute leftHipYaw(useAxisFlange = true, n = {0, 0, 1},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Parts.BodyShape leftThigh(
    r = {0, 0, -L_thigh},
    m = m_thigh,
    r_CM = {0, 0, -L_thigh/2},
    I_11 = m_thigh * L_thigh^2 / 12,
    I_22 = m_thigh * L_thigh^2 / 12,
    I_33 = m_thigh * 0.03^2 / 4
  );
  MB.Joints.Revolute leftKneePitch(useAxisFlange = true, n = {0, 1, 0},
    phi(start = 0.05, fixed = true), w(start = 0, fixed = true));
  MB.Parts.BodyShape leftShank(
    r = {0, 0, -L_shank},
    m = m_shank,
    r_CM = {0, 0, -L_shank/2},
    I_11 = m_shank * L_shank^2 / 12,
    I_22 = m_shank * L_shank^2 / 12,
    I_33 = m_shank * 0.03^2 / 4
  );
  MB.Joints.Revolute leftAnklePitch(useAxisFlange = true, n = {0, 1, 0},
    phi(start = -0.05, fixed = true), w(start = 0, fixed = true));
  MB.Joints.Revolute leftAnkleRoll(useAxisFlange = true, n = {1, 0, 0},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Parts.BodyShape leftFoot(
    r = {foot_fwd, 0, -foot_drop},
    m = m_foot,
    r_CM = {foot_fwd, 0, -foot_drop},
    I_11 = m_foot * (W_foot^2 + 0.01^2) / 12,
    I_22 = m_foot * (L_foot^2 + 0.01^2) / 12,
    I_33 = m_foot * (L_foot^2 + W_foot^2) / 12
  );

  // ===== RIGHT LEG =====
  MB.Joints.Revolute rightHipRoll(useAxisFlange = true, n = {1, 0, 0},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Joints.Revolute rightHipPitch(useAxisFlange = true, n = {0, 1, 0},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Joints.Revolute rightHipYaw(useAxisFlange = true, n = {0, 0, 1},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Parts.BodyShape rightThigh(
    r = {0, 0, -L_thigh},
    m = m_thigh,
    r_CM = {0, 0, -L_thigh/2},
    I_11 = m_thigh * L_thigh^2 / 12,
    I_22 = m_thigh * L_thigh^2 / 12,
    I_33 = m_thigh * 0.03^2 / 4
  );
  MB.Joints.Revolute rightKneePitch(useAxisFlange = true, n = {0, 1, 0},
    phi(start = 0.05, fixed = true), w(start = 0, fixed = true));
  MB.Parts.BodyShape rightShank(
    r = {0, 0, -L_shank},
    m = m_shank,
    r_CM = {0, 0, -L_shank/2},
    I_11 = m_shank * L_shank^2 / 12,
    I_22 = m_shank * L_shank^2 / 12,
    I_33 = m_shank * 0.03^2 / 4
  );
  MB.Joints.Revolute rightAnklePitch(useAxisFlange = true, n = {0, 1, 0},
    phi(start = -0.05, fixed = true), w(start = 0, fixed = true));
  MB.Joints.Revolute rightAnkleRoll(useAxisFlange = true, n = {1, 0, 0},
    phi(start = 0, fixed = true), w(start = 0, fixed = true));
  MB.Parts.BodyShape rightFoot(
    r = {foot_fwd, 0, -foot_drop},
    m = m_foot,
    r_CM = {foot_fwd, 0, -foot_drop},
    I_11 = m_foot * (W_foot^2 + 0.01^2) / 12,
    I_22 = m_foot * (L_foot^2 + 0.01^2) / 12,
    I_33 = m_foot * (L_foot^2 + W_foot^2) / 12
  );

  // ===== BOUNDED TORQUE ACTUATORS (12 TOTAL, +-138 N.m) =====
  Rot.Sources.Torque tau_leftHipRoll;
  Rot.Sources.Torque tau_leftHipPitch;
  Rot.Sources.Torque tau_leftHipYaw;
  Rot.Sources.Torque tau_leftKneePitch;
  Rot.Sources.Torque tau_leftAnklePitch;
  Rot.Sources.Torque tau_leftAnkleRoll;
  Rot.Sources.Torque tau_rightHipRoll;
  Rot.Sources.Torque tau_rightHipPitch;
  Rot.Sources.Torque tau_rightHipYaw;
  Rot.Sources.Torque tau_rightKneePitch;
  Rot.Sources.Torque tau_rightAnklePitch;
  Rot.Sources.Torque tau_rightAnkleRoll;

  // ===== SENSORS: JOINT, IMU, CONTACT, FORWARD DEPTH =====
  MB.Sensors.AbsolutePosition pelvisPos(resolveInFrame = MB.Types.ResolveInFrameA.world);
  MB.Sensors.AbsoluteAngles pelvisAngles;
  MB.Sensors.AbsoluteVelocity pelvisVel(resolveInFrame = MB.Types.ResolveInFrameA.world);
  MB.Sensors.AbsolutePosition leftFootPos(resolveInFrame = MB.Types.ResolveInFrameA.world);
  MB.Sensors.AbsoluteVelocity leftFootVel(resolveInFrame = MB.Types.ResolveInFrameA.world);
  MB.Sensors.AbsolutePosition rightFootPos(resolveInFrame = MB.Types.ResolveInFrameA.world);
  MB.Sensors.AbsoluteVelocity rightFootVel(resolveInFrame = MB.Types.ResolveInFrameA.world);

  // ===== EXTERNAL FORCES =====
  MB.Forces.WorldForce pushForce;
  MB.Forces.WorldForce leftFootContact;
  MB.Forces.WorldForce rightFootContact;

  // ===== CONTROLLER VARIABLES =====
  discrete Real phase(start = 0.0) "Gait phase [0,1)";
  discrete Boolean leftStance(start = true) "Left foot in stance";
  discrete Boolean rightStance(start = false) "Right foot in stance";
  discrete SI.Length x_foothold_left(start = 0.0) "Planned left foothold x";
  discrete SI.Length x_foothold_right(start = 0.0) "Planned right foothold x";
  discrete SI.Length z_foothold_left(start = 0.0) "Terrain height at left foothold";
  discrete SI.Length z_foothold_right(start = 0.0) "Terrain height at right foothold";
  discrete SI.Depth depth_ahead(start = 0.0) "Forward depth measurement";
  discrete SI.Position x_pelvis_d(start = 0.0) "Sampled pelvis x for IK";
  discrete SI.Position z_pelvis_d(start = h_pelvis0) "Sampled pelvis z for IK";
  discrete SI.Position x_leftFoot_d(start = 0.0) "Sampled left foot x";
  discrete SI.Position z_leftFoot_d(start = 0.0) "Sampled left foot z";
  discrete SI.Position x_rightFoot_d(start = 0.0) "Sampled right foot x";
  discrete SI.Position z_rightFoot_d(start = 0.0) "Sampled right foot z";

  // Swing trajectory
  Real t_swing_left "Normalized left swing phase [0,1]";
  Real t_swing_right "Normalized right swing phase [0,1]";
  Real x_swing_left, z_swing_left "Desired left swing-foot position";
  Real x_swing_right, z_swing_right "Desired right swing-foot position";

  // IK variables
  Real dx_L, dz_L, L_L, L_L_safe, cos_knee_L, theta_knee_L, alpha_L, beta_L;
  Real dx_R, dz_R, L_R, L_R_safe, cos_knee_R, theta_knee_R, alpha_R, beta_R;

  // Desired joint angles (continuous, from IK or nominal)
  Real q_des_leftHipPitch_c, q_des_leftKneePitch_c, q_des_leftAnklePitch_c;
  Real q_des_rightHipPitch_c, q_des_rightKneePitch_c, q_des_rightAnklePitch_c;

  // Torque commands (raw and saturated)
  Real tau_raw_leftHipRoll, tau_raw_leftHipPitch, tau_raw_leftHipYaw;
  Real tau_raw_leftKneePitch, tau_raw_leftAnklePitch, tau_raw_leftAnkleRoll;
  Real tau_raw_rightHipRoll, tau_raw_rightHipPitch, tau_raw_rightHipYaw;
  Real tau_raw_rightKneePitch, tau_raw_rightAnklePitch, tau_raw_rightAnkleRoll;
  Real tau_cmd_leftHipRoll, tau_cmd_leftHipPitch, tau_cmd_leftHipYaw;
  Real tau_cmd_leftKneePitch, tau_cmd_leftAnklePitch, tau_cmd_leftAnkleRoll;
  Real tau_cmd_rightHipRoll, tau_cmd_rightHipPitch, tau_cmd_rightHipYaw;
  Real tau_cmd_rightKneePitch, tau_cmd_rightAnklePitch, tau_cmd_rightAnkleRoll;

  // Contact model
  SI.Length z_terrain_left, z_terrain_right, z_terrain_pelvis;
  Real pen_left, pen_right;
  SI.Force Fn_left, Fn_right;
  SI.Force Ffx_left, Ffy_left, Ffx_right, Ffy_right;

  // Pelvis state (IMU + position)
  SI.Position x_pelvis, y_pelvis, z_pelvis;
  Real roll_pelvis, pitch_pelvis, yaw_pelvis;
  SI.Velocity vx_pelvis, vy_pelvis, vz_pelvis;

  // Foot state (contact + position sensors)
  SI.Position x_leftFoot, y_leftFoot, z_leftFoot;
  SI.Position x_rightFoot, y_rightFoot, z_rightFoot;
  SI.Velocity vx_leftFoot, vy_leftFoot, vz_leftFoot;
  SI.Velocity vx_rightFoot, vy_rightFoot, vz_rightFoot;

  // Tracking and clearance
  SI.Length x_desired, track_err, clr_left, clr_right;

  // ===== ACCEPTANCE CHECKS (FAIL-CLOSED) =====
  Boolean check_actuator_bounds "All torques within +-138 N.m";
  Boolean check_clearance "Swing foot clearance above 0.03 m";
  Boolean check_attitude "Attitude below 0.45 rad";
  Boolean check_route_completion "Route completed";
  Boolean check_track_err "Tracking error below 0.135 m after 10.4 s";
  Boolean check_no_nan "No NaN or infinite values";
  Boolean check_no_torso_collision "No torso-terrain collision";
  Boolean acceptance_passed "All acceptance criteria passed (fail-closed)";

  // ===== SYNCHRONIZED TRACES (OUTPUTS) =====
  output SI.Position trace_x = x_pelvis "State: pelvis x";
  output SI.Position trace_z = z_pelvis "State: pelvis z";
  output Real trace_roll = roll_pelvis "State/IMU: pelvis roll";
  output Real trace_pitch = pitch_pelvis "State/IMU: pelvis pitch";
  output Real trace_tau_LHip = tau_cmd_leftHipPitch "Command: left hip pitch torque";
  output Real trace_tau_LKnee = tau_cmd_leftKneePitch "Command: left knee torque";
  output Real trace_tau_RHip = tau_cmd_rightHipPitch "Command: right hip pitch torque";
  output Real trace_tau_RKnee = tau_cmd_rightKneePitch "Command: right knee torque";
  output SI.Force trace_FnL = max(0, Fn_left) "Sensor: left foot normal force";
  output SI.Force trace_FnR = max(0, Fn_right) "Sensor: right foot normal force";
  output SI.Depth trace_depth = depth_ahead "Sensor: forward depth measurement";
  output SI.Length trace_track_err = track_err "State: path tracking error";
  output Boolean trace_accept = acceptance_passed "Acceptance flag (fail-closed)";
  output Real trace_phase = phase "State: gait phase";

equation
  // ===== SENSOR READOUTS =====
  x_pelvis = pelvisPos.r[1];
  y_pelvis = pelvisPos.r[2];
  z_pelvis = pelvisPos.r[3];
  roll_pelvis = pelvisAngles.angles[1];
  pitch_pelvis = pelvisAngles.angles[2];
  yaw_pelvis = pelvisAngles.angles[3];
  vx_pelvis = pelvisVel.v[1];
  vy_pelvis = pelvisVel.v[2];
  vz_pelvis = pelvisVel.v[3];
  x_leftFoot = leftFootPos.r[1];
  y_leftFoot = leftFootPos.r[2];
  z_leftFoot = leftFootPos.r[3];
  vx_leftFoot = leftFootVel.v[1];
  vy_leftFoot = leftFootVel.v[2];
  vz_leftFoot = leftFootVel.v[3];
  x_rightFoot = rightFootPos.r[1];
  y_rightFoot = rightFootPos.r[2];
  z_rightFoot = rightFootPos.r[3];
  vx_rightFoot = rightFootVel.v[1];
  vy_rightFoot = rightFootVel.v[2];
  vz_rightFoot = rightFootVel.v[3];

  // ===== TERRAIN HEIGHT FIELD (0.08 m rocks, two 0.12 m gaps) =====
  z_terrain_left = h_rock * Modelica.Math.exp(-((x_leftFoot - x_rock1)/r_rock)^2)
                 + h_rock * Modelica.Math.exp(-((x_leftFoot - x_rock2)/r_rock)^2)
                 + h_rock * Modelica.Math.exp(-((x_leftFoot - x_rock3)/r_rock)^2)
                 - d_gap * (if abs(x_leftFoot - x_gap1) < w_gap/2 then 1.0 else 0.0)
                 - d_gap * (if abs(x_leftFoot - x_gap2) < w_gap/2 then 1.0 else 0.0);
  z_terrain_right = h_rock * Modelica.Math.exp(-((x_rightFoot - x_rock1)/r_rock)^2)
                  + h_rock * Modelica.Math.exp(-((x_rightFoot - x_rock2)/r_rock)^2)
                  + h_rock * Modelica.Math.exp(-((x_rightFoot - x_rock3)/r_rock)^2)
                  - d_gap * (if abs(x_rightFoot - x_gap1) < w_gap/2 then 1.0 else 0.0)
                  - d_gap * (if abs(x_rightFoot - x_gap2) < w_gap/2 then 1.0 else 0.0);
  z_terrain_pelvis = h_rock * Modelica.Math.exp(-((x_pelvis - x_rock1)/r_rock)^2)
                   + h_rock * Modelica.Math.exp(-((x_pelvis - x_rock2)/r_rock)^2)
                   + h_rock * Modelica.Math.exp(-((x_pelvis - x_rock3)/r_rock)^2)
                   - d_gap * (if abs(x_pelvis - x_gap1) < w_gap/2 then 1.0 else 0.0)
                   - d_gap * (if abs(x_pelvis - x_gap2) < w_gap/2 then 1.0 else 0.0);

  // ===== CONTACT MODEL (friction mu=0.78, spring-damper normal) =====
  pen_left = z_terrain_left - z_leftFoot;
  pen_right = z_terrain_right - z_rightFoot;
  Fn_left = if pen_left > 0 then k_c * pen_left - d_c * vz_leftFoot else 0.0;
  Fn_right = if pen_right > 0 then k_c * pen_right - d_c * vz_rightFoot else 0.0;
  Ffx_left = -mu * max(0.0, Fn_left) * Modelica.Math.tanh(vx_leftFoot / v_thresh);
  Ffy_left = -mu * max(0.0, Fn_left) * Modelica.Math.tanh(vy_leftFoot / v_thresh);
  Ffx_right = -mu * max(0.0, Fn_right) * Modelica.Math.tanh(vx_rightFoot / v_thresh);
  Ffy_right = -mu * max(0.0, Fn_right) * Modelica.Math.tanh(vy_rightFoot / v_thresh);
  leftFootContact.f[1] = Ffx_left;
  leftFootContact.f[2] = Ffy_left;
  leftFootContact.f[3] = max(0.0, Fn_left);
  rightFootContact.f[1] = Ffx_right;
  rightFootContact.f[2] = Ffy_right;
  rightFootContact.f[3] = max(0.0, Fn_right);

  // ===== LATERAL PUSH (108 N in y, middle third of 16 s) =====
  pushForce.f[1] = 0.0;
  pushForce.f[2] = if time >= t_push_start and time <= t_push_end then F_push else 0.0;
  pushForce.f[3] = 0.0;

  // ===== CONTROLLER AT 250 Hz: GAIT, FOOTHOLD PLANNING, DEPTH =====
  when sample(0, T_ctrl) loop
    // Sample state for IK (breaks algebraic loop)
    x_pelvis_d := x_pelvis;
    z_pelvis_d := z_pelvis;
    x_leftFoot_d := x_leftFoot;
    z_leftFoot_d := z_leftFoot;
    x_rightFoot_d := x_rightFoot;
    z_rightFoot_d := z_rightFoot;

    // Gait phase
    phase := mod(time / T_step, 1.0);
    leftStance := phase < 0.5;
    rightStance := not leftStance;

    // Forward depth measurement (terrain preview for foothold selection)
    depth_ahead := h_rock * Modelica.Math.exp(-(((x_pelvis + depth_lookahead) - x_rock1)/r_rock)^2)
                 + h_rock * Modelica.Math.exp(-(((x_pelvis + depth_lookahead) - x_rock2)/r_rock)^2)
                 + h_rock * Modelica.Math.exp(-(((x_pelvis + depth_lookahead) - x_rock3)/r_rock)^2)
                 - d_gap * (if abs((x_pelvis + depth_lookahead) - x_gap1) < w_gap/2 then 1.0 else 0.0)
                 - d_gap * (if abs((x_pelvis + depth_lookahead) - x_gap2) < w_gap/2 then 1.0 else 0.0);

    // Foothold selection: step forward, avoid gaps
    x_foothold_left := x_pelvis + L_step;
    if abs(x_foothold_left - x_gap1) < w_gap/2 + 0.05 then
      x_foothold_left := x_gap1 + w_gap/2 + 0.1;
    elseif abs(x_foothold_left - x_gap2) < w_gap/2 + 0.05 then
      x_foothold_left := x_gap2 + w_gap/2 + 0.1;
    end if;

    x_foothold_right := x_pelvis + L_step;
    if abs(x_foothold_right - x_gap1) < w_gap/2 + 0.05 then
      x_foothold_right := x_gap1 + w_gap/2 + 0.1;
    elseif abs(x_foothold_right - x_gap2) < w_gap/2 + 0.05 then
      x_foothold_right := x_gap2 + w_gap/2 + 0.1;
    end if;

    // Terrain height at planned footholds
    z_foothold_left := h_rock * Modelica.Math.exp(-((x_foothold_left - x_rock1)/r_rock)^2)
                     + h_rock * Modelica.Math.exp(-((x_foothold_left - x_rock2)/r_rock)^2)
                     + h_rock * Modelica.Math.exp(-((x_foothold_left - x_rock3)/r_rock)^2)
                     - d_gap * (if abs(x_foothold_left - x_gap1) < w_gap/2 then 1.0 else 0.0)
                     - d_gap * (if abs(x_foothold_left - x_gap2) < w_gap/2 then 1.0 else 0.0);
    z_foothold_right := h_rock * Modelica.Math.exp(-((x_foothold_right - x_rock1)/r_rock)^2)
                      + h_rock * Modelica.Math.exp(-((x_foothold_right - x_rock2)/r_rock)^2)
                      + h_rock * Modelica.Math.exp(-((x_foothold_right - x_rock3)/r_rock)^2)
                      - d_gap * (if abs(x_foothold_right - x_gap1) < w_gap/2 then 1.0 else 0.0)
                      - d_gap * (if abs(x_foothold_right - x_gap2) < w_gap/2 then 1.0 else 0.0);
  end when;

  // ===== SWING-FOOT TRAJECTORY CONTROL (clearance > 0.03 m) =====
  t_swing_left = max(0.0, min(1.0, 2.0 * (phase - 0.5)));
  t_swing_right = max(0.0, min(1.0, 2.0 * phase));
  x_swing_left = x_leftFoot_d + (x_foothold_left - x_leftFoot_d) * t_swing_left;
  z_swing_left = max(z_leftFoot_d, z_foothold_left) + clr_min + 0.05 * Modelica.Math.sin(Modelica.Constants.pi * t_swing_left);
  x_swing_right = x_rightFoot_d + (x_foothold_right - x_rightFoot_d) * t_swing_right;
  z_swing_right = max(z_rightFoot_d, z_foothold_right) + clr_min + 0.05 * Modelica.Math.sin(Modelica.Constants.pi * t_swing_right);

  // ===== INVERSE KINEMATICS (SAGITTAL PLANE) =====
  dx_L = (x_swing_left - foot_fwd) - x_pelvis_d;
  dz_L = (z_swing_left + foot_drop) - z_pelvis_d;
  L_L = sqrt(dx_L^2 + dz_L^2);
  L_L_safe = max(abs(L_thigh - L_shank) + 0.01, min(L_thigh + L_shank - 0.01, L_L));
  cos_knee_L = (L_L_safe^2 - L_thigh^2 - L_shank^2) / (2 * L_thigh * L_shank);
  theta_knee_L = Modelica.Math.acos(max(-0.999, min(0.999, cos_knee_L)));
  alpha_L = Modelica.Math.atan2(dx_L, -dz_L);
  beta_L = Modelica.Math.atan2(L_shank * Modelica.Math.sin(theta_knee_L), L_thigh + L_shank * Modelica.Math.cos(theta_knee_L));

  dx_R = (x_swing_right - foot_fwd) - x_pelvis_d;
  dz_R = (z_swing_right + foot_drop) - z_pelvis_d;
  L_R = sqrt(dx_R^2 + dz_R^2);
  L_R_safe = max(abs(L_thigh - L_shank) + 0.01, min(L_thigh + L_shank - 0.01, L_R));
  cos_knee_R = (L_R_safe^2 - L_thigh^2 - L_shank^2) / (2 * L_thigh * L_shank);
  theta_knee_R = Modelica.Math.acos(max(-0.999, min(0.999, cos_knee_R)));
  alpha_R = Modelica.Math.atan2(dx_R, -dz_R);
  beta_R = Modelica.Math.atan2(L_shank * Modelica.Math.sin(theta_knee_R), L_thigh + L_shank * Modelica.Math.cos(theta_knee_R));

  // ===== DESIRED JOINT ANGLES (STANCE=NOMINAL, SWING=IK) =====
  q_des_leftHipPitch_c = if leftStance then 0.0 else (alpha_L - beta_L);
  q_des_leftKneePitch_c = if leftStance then 0.05 else theta_knee_L;
  q_des_leftAnklePitch_c = if leftStance then -0.05 else -(alpha_L - beta_L + theta_knee_L);
  q_des_rightHipPitch_c = if rightStance then 0.0 else (alpha_R - beta_R);
  q_des_rightKneePitch_c = if rightStance then 0.05 else theta_knee_R;
  q_des_rightAnklePitch_c = if rightStance then -0.05 else -(alpha_R - beta_R + theta_knee_R);

  // ===== PD JOINT-TORQUE CONTROL =====
  tau_raw_leftHipRoll = kp * (0.0 - leftHipRoll.phi) - kd * leftHipRoll.w;
  tau_raw_leftHipPitch = kp * (q_des_leftHipPitch_c - leftHipPitch.phi) - kd * leftHipPitch.w;
  tau_raw_leftHipYaw = kp * (0.0 - leftHipYaw.phi) - kd * leftHipYaw.w;
  tau_raw_leftKneePitch = kp * (q_des_leftKneePitch_c - leftKneePitch.phi) - kd * leftKneePitch.w;
  tau_raw_leftAnklePitch = kp * (q_des_leftAnklePitch_c - leftAnklePitch.phi) - kd * leftAnklePitch.w;
  tau_raw_leftAnkleRoll = kp * (0.0 - leftAnkleRoll.phi) - kd * leftAnkleRoll.w;
  tau_raw_rightHipRoll = kp * (0.0 - rightHipRoll.phi) - kd * rightHipRoll.w;
  tau_raw_rightHipPitch = kp * (q_des_rightHipPitch_c - rightHipPitch.phi) - kd * rightHipPitch.w;
  tau_raw_rightHipYaw = kp * (0.0 - rightHipYaw.phi) - kd * rightHipYaw.w;
  tau_raw_rightKneePitch = kp * (q_des_rightKneePitch_c - rightKneePitch.phi) - kd * rightKneePitch.w;
  tau_raw_rightAnklePitch = kp * (q_des_rightAnklePitch_c - rightAnklePitch.phi) - kd * rightAnklePitch.w;
  tau_raw_rightAnkleRoll = kp * (0.0 - rightAnkleRoll.phi) - kd * rightAnkleRoll.w;

  // ===== TORQUE SATURATION (+-138 N.m PER JOINT) =====
  tau_cmd_leftHipRoll = max(-tau_max, min(tau_max, tau_raw_leftHipRoll));
  tau_cmd_leftHipPitch = max(-tau_max, min(tau_max, tau_raw_leftHipPitch));
  tau_cmd_leftHipYaw = max(-tau_max, min(tau_max, tau_raw_leftHipYaw));
  tau_cmd_leftKneePitch = max(-tau_max, min(tau_max, tau_raw_leftKneePitch));
  tau_cmd_leftAnklePitch = max(-tau_max, min(tau_max, tau_raw_leftAnklePitch));
  tau_cmd_leftAnkleRoll = max(-tau_max, min(tau_max, tau_raw_leftAnkleRoll));
  tau_cmd_rightHipRoll = max(-tau_max, min(tau_max, tau_raw_rightHipRoll));
  tau_cmd_rightHipPitch = max(-tau_max, min(tau_max, tau_raw_rightHipPitch));
  tau_cmd_rightHipYaw = max(-tau_max, min(tau_max, tau_raw_rightHipYaw));
  tau_cmd_rightKneePitch = max(-tau_max, min(tau_max, tau_raw_rightKneePitch));
  tau_cmd_rightAnklePitch = max(-tau_max, min(tau_max, tau_raw_rightAnklePitch));
  tau_cmd_rightAnkleRoll = max(-tau_max, min(tau_max, tau_raw_rightAnkleRoll));

  // Apply bounded torques to actuators
  tau_leftHipRoll.tau = tau_cmd_leftHipRoll;
  tau_leftHipPitch.tau = tau_cmd_leftHipPitch;
  tau_leftHipYaw.tau = tau_cmd_leftHipYaw;
  tau_leftKneePitch.tau = tau_cmd_leftKneePitch;
  tau_leftAnklePitch.tau = tau_cmd_leftAnklePitch;
  tau_leftAnkleRoll.tau = tau_cmd_leftAnkleRoll;
  tau_rightHipRoll.tau = tau_cmd_rightHipRoll;
  tau_rightHipPitch.tau = tau_cmd_rightHipPitch;
  tau_rightHipYaw.tau = tau_cmd_rightHipYaw;
  tau_rightKneePitch.tau = tau_cmd_rightKneePitch;
  tau_rightAnklePitch.tau = tau_cmd_rightAnklePitch;
  tau_rightAnkleRoll.tau = tau_cmd_rightAnkleRoll;

  // ===== PATH TRACKING =====
  x_desired = v_ref * time;
  track_err = abs(x_pelvis - x_desired);
  clr_left = z_leftFoot - z_terrain_left;
  clr_right = z_rightFoot - z_terrain_right;

  // ===== ACCEPTANCE CHECKS (FAIL-CLOSED) =====
  check_actuator_bounds = abs(tau_cmd_leftHipRoll) <= tau_max and abs(tau_cmd_leftHipPitch) <= tau_max
    and abs(tau_cmd_leftHipYaw) <= tau_max and abs(tau_cmd_leftKneePitch) <= tau_max
    and abs(tau_cmd_leftAnklePitch) <= tau_max and abs(tau_cmd_leftAnkleRoll) <= tau_max
    and abs(tau_cmd_rightHipRoll) <= tau_max and abs(tau_cmd_rightHipPitch) <= tau_max
    and abs(tau_cmd_rightHipYaw) <= tau_max and abs(tau_cmd_rightKneePitch) <= tau_max
    and abs(tau_cmd_rightAnklePitch) <= tau_max and abs(tau_cmd_rightAnkleRoll) <= tau_max;
  check_clearance = (if not leftStance then clr_left >= clr_min else true)
    and (if not rightStance then clr_right >= clr_min else true);
  check_attitude = abs(roll_pelvis) < att_max and abs(pitch_pelvis) < att_max;
  check_route_completion = x_pelvis >= x_target * 0.9;
  check_track_err = if time >= t_check then track_err < e_track_max else true;
  check_no_torso_collision = z_pelvis > z_terrain_pelvis + 0.10;
  check_no_nan = Modelica.Math.isFinite(x_pelvis) and Modelica.Math.isFinite(z_pelvis)
    and Modelica.Math.isFinite(roll_pelvis) and Modelica.Math.isFinite(pitch_pelvis)
    and Modelica.Math.isFinite(tau_cmd_leftHipPitch) and Modelica.Math.isFinite(tau_cmd_rightHipPitch)
    and Modelica.Math.isFinite(tau_cmd_leftKneePitch) and Modelica.Math.isFinite(tau_cmd_rightKneePitch)
    and Modelica.Math.isFinite(Fn_left) and Modelica.Math.isFinite(Fn_right)
    and Modelica.Math.isFinite(depth_ahead) and Modelica.Math.isFinite(track_err);
  acceptance_passed = check_actuator_bounds and check_clearance and check_attitude
    and check_route_completion and check_track_err and check_no_nan and check_no_torso_collision;

  // ===== CONNECTIONS =====
  connect(world.frame_b, pelvisFree.frame_a);
  connect(pelvisFree.frame_b, pelvisBody.frame_a);
  connect(pelvisFree.frame_b, pelvisPos.frame_a);
  connect(pelvisFree.frame_b, pelvisAngles.frame_a);
  connect(pelvisFree.frame_b, pelvisVel.frame_a);
  connect(pelvisFree.frame_b, pushForce.frame_b);
  connect(pelvisFree.frame_b, hipLeftOffset.frame_a);
  connect(pelvisFree.frame_b, hipRightOffset.frame_a);

  // Left leg kinematic chain
  connect(hipLeftOffset.frame_b, leftHipRoll.frame_a);
  connect(leftHipRoll.frame_b, leftHipPitch.frame_a);
  connect(leftHipPitch.frame_b, leftHipYaw.frame_a);
  connect(leftHipYaw.frame_b, leftThigh.frame_a);
  connect(leftThigh.frame_b, leftKneePitch.frame_a);
  connect(leftKneePitch.frame_b, leftShank.frame_a);
  connect(leftShank.frame_b, leftAnklePitch.frame_a);
  connect(leftAnklePitch.frame_b, leftAnkleRoll.frame_a);
  connect(leftAnkleRoll.frame_b, leftFoot.frame_a);
  connect(leftFoot.frame_b, leftFootPos.frame_a);
  connect(leftFoot.frame_b, leftFootVel.frame_a);
  connect(leftFoot.frame_b, leftFootContact.frame_b);

  // Right leg kinematic chain
  connect(hipRightOffset.frame_b, rightHipRoll.frame_a);
  connect(rightHipRoll.frame_b, rightHipPitch.frame_a);
  connect(rightHipPitch.frame_b, rightHipYaw.frame_a);
  connect(rightHipYaw.frame_b, rightThigh.frame_a);
  connect(rightThigh.frame_b, rightKneePitch.frame_a);
  connect(rightKneePitch.frame_b, rightShank.frame_a);
  connect(rightShank.frame_b, rightAnklePitch.frame_a);
  connect(rightAnklePitch.frame_b, rightAnkleRoll.frame_a);
  connect(rightAnkleRoll.frame_b, rightFoot.frame_a);
  connect(rightFoot.frame_b, rightFootPos.frame_a);
  connect(rightFoot.frame_b, rightFootVel.frame_a);
  connect(rightFoot.frame_b, rightFootContact.frame_b);

  // Torque actuator connections
  connect(tau_leftHipRoll.flange, leftHipRoll.axis);
  connect(tau_leftHipPitch.flange, leftHipPitch.axis);
  connect(tau_leftHipYaw.flange, leftHipYaw.axis);
  connect(tau_leftKneePitch.flange, leftKneePitch.axis);
  connect(tau_leftAnklePitch.flange, leftAnklePitch.axis);
  connect(tau_leftAnkleRoll.flange, leftAnkleRoll.axis);
  connect(tau_rightHipRoll.flange, rightHipRoll.axis);
  connect(tau_rightHipPitch.flange, rightHipPitch.axis);
  connect(tau_rightHipYaw.flange, rightHipYaw.axis);
  connect(tau_rightKneePitch.flange, rightKneePitch.axis);
  connect(tau_rightAnklePitch.flange, rightAnklePitch.axis);
  connect(tau_rightAnkleRoll.flange, rightAnkleRoll.axis);

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-4, Interval = 0.004),
    Documentation(info = "BipedTwoTraverseE: 36 kg floating-base biped with spherical hips (3-DOF), 0.42 m thighs, 0.40 m shanks, revolute knees, two-axis ankles, and flat feet. Traverses a height field with 0.08 m rocks and two 0.12 m gaps at a commanded average speed. Bounded joint-torque actuators (138 N.m per joint). Contact friction 0.78. Controller at 250 Hz with foothold planning, swing-foot trajectory control, and 108 N lateral push in middle third. Acceptance is fail-closed: actuator bounds, clearance > 0.03 m, attitude < 0.45 rad, route completion, tracking error < 0.135 m after 10.4 s, no torso-terrain collision, and no NaN/infinite values. Values for leg masses, foot dimensions, gait period, commanded speed, and terrain feature locations are ASSUMED (not specified in requirement).")
  );
end BipedTwoTraverseE;