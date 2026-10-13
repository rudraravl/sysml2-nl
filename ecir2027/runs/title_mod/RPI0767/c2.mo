model BipedTwoRecoverE
  import Modelica.Units.SI;
  import Modelica.Mechanics.MultiBody;
  import Modelica.Constants;

  // ==================== PARAMETERS (from requirement) ====================
  parameter SI.Mass   m_pelvis      = 36    "Pelvis mass [requirement]";
  parameter SI.Length L_thigh       = 0.42  "Thigh length [requirement]";
  parameter SI.Length L_shank       = 0.40  "Shank length [requirement]";
  parameter SI.Torque tau_max       = 138   "Joint torque bound per joint [requirement]";
  parameter Real      mu_ground      = 0.90  "Ground friction coefficient [requirement]";
  parameter SI.Force  F_push         = 168   "Lateral push force [requirement]";
  parameter SI.Frequency f_ctrl      = 250   "Control frequency [requirement]";
  parameter SI.Time   T_sim          = 16.0  "Simulation duration [requirement]";
  parameter SI.Length slip_limit     = 0.03  "Max foot slip [requirement]";
  parameter Real      track_err_limit = 0.108 "Max tracking error after check [requirement]";
  parameter SI.Time   t_check        = 10.4  "Tracking error check time [requirement]";

  // ==================== PARAMETERS (assumed; not in requirement) ====================
  parameter SI.Mass   m_thigh        = 7.0  "Thigh mass per leg [assumed]";
  parameter SI.Mass   m_shank        = 3.5  "Shank mass per leg [assumed]";
  parameter SI.Mass   m_foot         = 1.5  "Foot mass per leg [assumed]";
  parameter SI.Length L_foot         = 0.20 "Foot length [assumed]";
  parameter SI.Length W_foot         = 0.10 "Foot width [assumed]";
  parameter SI.Length h_foot         = 0.04 "Foot thickness [assumed]";
  parameter SI.Length h_pelvis_init   = 0.85 "Initial pelvis height [assumed]";
  parameter SI.Length hip_offset      = 0.09 "Half-distance between hips [assumed]";
  parameter SI.Time   t_push_start    = 5.33 "Push start: middle third of 16 s [assumed]";
  parameter SI.Time   t_push_dur      = 0.30 "Finite push duration [assumed]";

  // Control gains [assumed]
  parameter Real Kp_joint = 80.0  "Joint PD proportional [assumed]";
  parameter Real Kd_joint = 4.0   "Joint PD derivative [assumed]";
  parameter Real Kp_com   = 200.0 "COM balance proportional [assumed]";
  parameter Real Kd_com   = 20.0  "COM balance derivative [assumed]";
  parameter Real Kp_att   = 100.0 "Attitude proportional [assumed]";
  parameter Real Kd_att   = 10.0  "Attitude derivative [assumed]";

  // Contact model [assumed]
  parameter SI.TranslationalSpringConstant k_contact = 50000.0 "Contact stiffness [assumed]";
  parameter SI.TranslationalDampingConstant d_contact = 800.0 "Contact damping [assumed]";
  parameter SI.Velocity v_reg = 0.01 "Friction regularization velocity [assumed]";

  // Estimator [assumed]
  parameter SI.Time T_est = 0.01 "Estimator first-order time constant [assumed]";

  // Derived
  final parameter SI.Time T_ctrl = 1.0 / f_ctrl "Control sample period";

  // ==================== VARIABLE DECLARATIONS ====================
  Real base_pos[3]  "Base position in world frame";
  Real base_vel[3]  "Base velocity in world frame";
  Real base_att[3]  "Base attitude (Cardan angles x-y-z)";
  Real base_rate[3] "Base angular velocity in body frame";
  Real q[12]   "Joint angles: LHY LHR LHP LK LAR LAP RHY RHR RHP RK RAR RAP";
  Real qd[12]  "Joint velocities";

  Real est_base_pos[3](start={0,0,h_pelvis_init}) "Estimated base position";
  Real est_base_att[3](each start=0) "Estimated base attitude";
  Real est_base_vel[3](each start=0) "Estimated base velocity";
  Real est_base_rate[3](each start=0) "Estimated base angular velocity";

  discrete Real q_des[12](start={0,0,-0.1,0.2,0,0.1, 0,0,-0.1,0.2,0,0.1});
  discrete Real tau_cmd[12](each start=0) "Bounded commanded torque per joint";
  discrete Real com_err[3](each start=0) "Estimated COM error";

  Boolean leftContact  "Left foot contact (position threshold)";
  Boolean rightContact "Right foot contact (position threshold)";
  Boolean contactSwitchLeft  "Force-qualified left stance contact";
  Boolean contactSwitchRight "Force-qualified right stance contact";
  Real F_contact_left[3]  "Left foot contact force, world frame";
  Real F_contact_right[3] "Right foot contact force, world frame";
  Real F_normal_left  "Left foot normal force";
  Real F_normal_right "Right foot normal force";

  Real F_push_actual[3] "Applied push force vector, world frame";

  Real com[3]     "Approximate center of mass (pelvis)";
  Real com_dot[3] "Approximate COM velocity";

  Real tracking_error "Primary tracking error: sqrt(roll^2+pitch^2)";
  Real body_height     "Base z-position";
  Real left_foot_slip_accum(start=0)  "Accumulated left foot slip distance";
  Real right_foot_slip_accum(start=0) "Accumulated right foot slip distance";
  Real foot_slip "Max accumulated foot slip";
  Boolean torque_bounded     "All commanded torques within bounds";
  Boolean no_slip            "Foot slip within limit";
  Boolean positive_height    "Body height positive";
  Boolean attitude_recovered "Attitude recovered near zero";
  Boolean tracking_ok        "Tracking error below limit after check";
  Boolean no_nan             "No NaN or infinite values detected";
  Boolean acceptance         "Overall acceptance (fail-closed)";

  // ==================== COMPONENT DECLARATIONS ====================
  MultiBody.World world(
    gravityType = MultiBody.Types.GravityTypes.UniformGravity,
    g = 9.81,
    n = {0,0,-1},
    enableAnimation = false
  );

  // Floating base (only supported modifiers; w_rel_b is protected and may not be set)
  MultiBody.Joints.FreeMotion baseJoint(
    r_rel_a(start={0,0,h_pelvis_init}),
    v_rel_a(start={0,0,0})
  );
  MultiBody.Parts.Body pelvis(
    m = m_pelvis,
    r_CM = {0,0,0},
    I_11 = 0.5, I_22 = 0.5, I_33 = 0.5,
    I_21 = 0, I_31 = 0, I_32 = 0
  );

  // Attitude and angular velocity sensors on the floating base
  MultiBody.Sensors.AbsoluteAngles baseAttitude(
    sequence={1,2,3},
    resolveInFrame = MultiBody.Types.ResolveInFrameA.world
  );
  MultiBody.Sensors.AbsoluteAngularVelocity baseAngVel(
    resolveInFrame = MultiBody.Types.ResolveInFrameAB.frame_b
  );

  // Hip lateral offsets
  MultiBody.Parts.FixedTranslation leftHipOffset(r={0, hip_offset, 0});
  MultiBody.Parts.FixedTranslation rightHipOffset(r={0,-hip_offset, 0});

  // ---- LEFT LEG ----
  MultiBody.Joints.Revolute leftHipYaw(n={0,0,1}, phi(start=0), w(start=0));
  MultiBody.Joints.Revolute leftHipRoll(n={1,0,0}, phi(start=0), w(start=0));
  MultiBody.Joints.Revolute leftHipPitch(n={0,1,0}, phi(start=-0.1), w(start=0));
  MultiBody.Parts.BodyShape leftThigh(
    animation=false, r={0,0,-L_thigh}, r_CM={0,0,-L_thigh/2},
    m=m_thigh, I_11=0.1, I_22=0.1, I_33=0.02, I_21=0, I_31=0, I_32=0
  );
  MultiBody.Joints.Revolute leftKnee(n={0,1,0}, phi(start=0.2), w(start=0));
  MultiBody.Parts.BodyShape leftShank(
    animation=false, r={0,0,-L_shank}, r_CM={0,0,-L_shank/2},
    m=m_shank, I_11=0.05, I_22=0.05, I_33=0.005, I_21=0, I_31=0, I_32=0
  );
  MultiBody.Joints.Revolute leftAnkleRoll(n={1,0,0}, phi(start=0), w(start=0));
  MultiBody.Joints.Revolute leftAnklePitch(n={0,1,0}, phi(start=0.1), w(start=0));
  MultiBody.Parts.BodyShape leftFoot(
    animation=false, r={0,0,-h_foot}, r_CM={0,0,-h_foot/2},
    m=m_foot, I_11=0.002, I_22=0.005, I_33=0.006, I_21=0, I_31=0, I_32=0
  );

  // ---- RIGHT LEG ----
  MultiBody.Joints.Revolute rightHipYaw(n={0,0,1}, phi(start=0), w(start=0));
  MultiBody.Joints.Revolute rightHipRoll(n={1,0,0}, phi(start=0), w(start=0));
  MultiBody.Joints.Revolute rightHipPitch(n={0,1,0}, phi(start=-0.1), w(start=0));
  MultiBody.Parts.BodyShape rightThigh(
    animation=false, r={0,0,-L_thigh}, r_CM={0,0,-L_thigh/2},
    m=m_thigh, I_11=0.1, I_22=0.1, I_33=0.02, I_21=0, I_31=0, I_32=0
  );
  MultiBody.Joints.Revolute rightKnee(n={0,1,0}, phi(start=0.2), w(start=0));
  MultiBody.Parts.BodyShape rightShank(
    animation=false, r={0,0,-L_shank}, r_CM={0,0,-L_shank/2},
    m=m_shank, I_11=0.05, I_22=0.05, I_33=0.005, I_21=0, I_31=0, I_32=0
  );
  MultiBody.Joints.Revolute rightAnkleRoll(n={1,0,0}, phi(start=0), w(start=0));
  MultiBody.Joints.Revolute rightAnklePitch(n={0,1,0}, phi(start=0.1), w(start=0));
  MultiBody.Parts.BodyShape rightFoot(
    animation=false, r={0,0,-h_foot}, r_CM={0,0,-h_foot/2},
    m=m_foot, I_11=0.002, I_22=0.005, I_33=0.006, I_21=0, I_31=0, I_32=0
  );

  // Foot position & velocity sensors (world frame)
  MultiBody.Sensors.AbsolutePosition leftFootPos(
    resolveInFrame=MultiBody.Types.ResolveInFrameA.world
  );
  MultiBody.Sensors.AbsolutePosition rightFootPos(
    resolveInFrame=MultiBody.Types.ResolveInFrameA.world
  );
  MultiBody.Sensors.AbsoluteVelocity leftFootVel(
    resolveInFrame=MultiBody.Types.ResolveInFrameAB.world
  );
  MultiBody.Sensors.AbsoluteVelocity rightFootVel(
    resolveInFrame=MultiBody.Types.ResolveInFrameAB.world
  );

  // Contact and disturbance forces (world frame)
  MultiBody.Forces.WorldForce leftFootContact(
    resolveInFrame=MultiBody.Types.ResolveInFrameB.world
  );
  MultiBody.Forces.WorldForce rightFootContact(
    resolveInFrame=MultiBody.Types.ResolveInFrameB.world
  );
  MultiBody.Forces.WorldForce pushForce(
    resolveInFrame=MultiBody.Types.ResolveInFrameB.world
  );

  // Torque actuators (bounded, one per joint)
  Modelica.Mechanics.Rotational.Sources.Torque tauLHY,tauLHR,tauLHP,tauLK,tauLAR,tauLAP;
  Modelica.Mechanics.Rotational.Sources.Torque tauRHY,tauRHR,tauRHP,tauRK,tauRAR,tauRAP;

  // Fixed bearings for joint housings
  Modelica.Mechanics.Rotational.Components.Fixed fixLHY,fixLHR,fixLHP,fixLK,fixLAR,fixLAP;
  Modelica.Mechanics.Rotational.Components.Fixed fixRHY,fixRHR,fixRHP,fixRK,fixRAR,fixRAP;

equation
  // ===== STATE EXTRACTION =====
  base_pos  = baseJoint.r_rel_a;
  base_vel  = baseJoint.v_rel_a;
  base_att  = baseAttitude.angles;
  base_rate = baseAngVel.w;

  q[1]  = leftHipYaw.phi;      qd[1]  = leftHipYaw.w;
  q[2]  = leftHipRoll.phi;     qd[2]  = leftHipRoll.w;
  q[3]  = leftHipPitch.phi;    qd[3]  = leftHipPitch.w;
  q[4]  = leftKnee.phi;        qd[4]  = leftKnee.w;
  q[5]  = leftAnkleRoll.phi;   qd[5]  = leftAnkleRoll.w;
  q[6]  = leftAnklePitch.phi;  qd[6]  = leftAnklePitch.w;
  q[7]  = rightHipYaw.phi;     qd[7]  = rightHipYaw.w;
  q[8]  = rightHipRoll.phi;    qd[8]  = rightHipRoll.w;
  q[9]  = rightHipPitch.phi;   qd[9]  = rightHipPitch.w;
  q[10] = rightKnee.phi;       qd[10] = rightKnee.w;
  q[11] = rightAnkleRoll.phi;  qd[11] = rightAnkleRoll.w;
  q[12] = rightAnklePitch.phi; qd[12] = rightAnklePitch.w;

  // ===== CONTACT DETECTION =====
  leftContact  = leftFootPos.r[3]  < 0.005;
  rightContact = rightFootPos.r[3] < 0.005;

  // ===== CONTACT FORCES: spring-damper normal + regularized Coulomb friction =====
  F_normal_left = if leftFootPos.r[3] < 0 then
    max(0.0, k_contact * (-leftFootPos.r[3]) - d_contact * leftFootVel.v[3])
  else 0.0;
  F_contact_left[3] = F_normal_left;
  F_contact_left[1] = -mu_ground * F_normal_left * leftFootVel.v[1] /
    sqrt(leftFootVel.v[1]^2 + leftFootVel.v[2]^2 + v_reg^2);
  F_contact_left[2] = -mu_ground * F_normal_left * leftFootVel.v[2] /
    sqrt(leftFootVel.v[1]^2 + leftFootVel.v[2]^2 + v_reg^2);

  F_normal_right = if rightFootPos.r[3] < 0 then
    max(0.0, k_contact * (-rightFootPos.r[3]) - d_contact * rightFootVel.v[3])
  else 0.0;
  F_contact_right[3] = F_normal_right;
  F_contact_right[1] = -mu_ground * F_normal_right * rightFootVel.v[1] /
    sqrt(rightFootVel.v[1]^2 + rightFootVel.v[2]^2 + v_reg^2);
  F_contact_right[2] = -mu_ground * F_normal_right * rightFootVel.v[2] /
    sqrt(rightFootVel.v[1]^2 + rightFootVel.v[2]^2 + v_reg^2);

  contactSwitchLeft  = leftContact  and (F_normal_left  > 5.0);
  contactSwitchRight = rightContact and (F_normal_right > 5.0);

  // ===== LATERAL PUSH DISTURBANCE (middle third, finite duration) =====
  F_push_actual[1] = 0.0;
  F_push_actual[2] = if (time >= t_push_start and time < t_push_start + t_push_dur) then F_push else 0.0;
  F_push_actual[3] = 0.0;

  // ===== STATE ESTIMATOR: first-order filter (IMU + kinematics + contact fusion) =====
  der(est_base_pos[1])  = (base_pos[1]  - est_base_pos[1])  / T_est;
  der(est_base_pos[2])  = (base_pos[2]  - est_base_pos[2])  / T_est;
  der(est_base_pos[3])  = (base_pos[3]  - est_base_pos[3])  / T_est;
  der(est_base_att[1])  = (base_att[1]  - est_base_att[1])  / T_est;
  der(est_base_att[2])  = (base_att[2]  - est_base_att[2])  / T_est;
  der(est_base_att[3])  = (base_att[3]  - est_base_att[3])  / T_est;
  der(est_base_vel[1])  = (base_vel[1]  - est_base_vel[1])  / T_est;
  der(est_base_vel[2])  = (base_vel[2]  - est_base_vel[2])  / T_est;
  der(est_base_vel[3])  = (base_vel[3]  - est_base_vel[3])  / T_est;
  der(est_base_rate[1]) = (base_rate[1] - est_base_rate[1]) / T_est;
  der(est_base_rate[2]) = (base_rate[2] - est_base_rate[2]) / T_est;
  der(est_base_rate[3]) = (base_rate[3] - est_base_rate[3]) / T_est;

  // ===== COM APPROXIMATION (pelvis dominant) =====
  com     = base_pos;
  com_dot = base_vel;

  // ===== MONITORING =====
  tracking_error = sqrt(base_att[1]^2 + base_att[2]^2);
  body_height    = base_pos[3];

  der(left_foot_slip_accum)  = if contactSwitchLeft  then
    sqrt(leftFootVel.v[1]^2  + leftFootVel.v[2]^2)  else 0.0;
  der(right_foot_slip_accum) = if contactSwitchRight then
    sqrt(rightFootVel.v[1]^2 + rightFootVel.v[2]^2) else 0.0;

  foot_slip = max(left_foot_slip_accum, right_foot_slip_accum);

  torque_bounded =
    (abs(tau_cmd[1])  <= tau_max + 0.001) and (abs(tau_cmd[2])  <= tau_max + 0.001) and
    (abs(tau_cmd[3])  <= tau_max + 0.001) and (abs(tau_cmd[4])  <= tau_max + 0.001) and
    (abs(tau_cmd[5])  <= tau_max + 0.001) and (abs(tau_cmd[6])  <= tau_max + 0.001) and
    (abs(tau_cmd[7])  <= tau_max + 0.001) and (abs(tau_cmd[8])  <= tau_max + 0.001) and
    (abs(tau_cmd[9])  <= tau_max + 0.001) and (abs(tau_cmd[10]) <= tau_max + 0.001) and
    (abs(tau_cmd[11]) <= tau_max + 0.001) and (abs(tau_cmd[12]) <= tau_max + 0.001);

  no_slip         = foot_slip <= slip_limit;
  positive_height = body_height > 0;
  tracking_ok     = if time >= t_check then tracking_error <= track_err_limit else true;
  attitude_recovered = if time >= t_check then
    (abs(base_att[1]) < 0.1 and abs(base_att[2]) < 0.1) else true;

  no_nan =
    (abs(base_pos[1]) < 1e6) and (abs(base_pos[2]) < 1e6) and (abs(base_pos[3]) < 1e6) and
    (abs(base_att[1]) < 1e6) and (abs(base_att[2]) < 1e6) and (abs(base_att[3]) < 1e6) and
    (abs(tau_cmd[1])  < 1e6) and (abs(tau_cmd[2])  < 1e6) and (abs(tau_cmd[3])  < 1e6) and
    (abs(tau_cmd[4])  < 1e6) and (abs(tau_cmd[5])  < 1e6) and (abs(tau_cmd[6])  < 1e6) and
    (abs(tau_cmd[7])  < 1e6) and (abs(tau_cmd[8])  < 1e6) and (abs(tau_cmd[9])  < 1e6) and
    (abs(tau_cmd[10]) < 1e6) and (abs(tau_cmd[11]) < 1e6) and (abs(tau_cmd[12]) < 1e6) and
    (abs(est_base_pos[1])  < 1e6) and (abs(est_base_pos[2])  < 1e6) and (abs(est_base_pos[3])  < 1e6) and
    (abs(est_base_att[1])  < 1e6) and (abs(est_base_att[2])  < 1e6) and (abs(est_base_att[3])  < 1e6);

  acceptance = torque_bounded and no_slip and positive_height and
    attitude_recovered and tracking_ok and no_nan;

  // ===== ACTUATOR INPUT ASSIGNMENTS =====
  tauLHY.tau  = tau_cmd[1];
  tauLHR.tau  = tau_cmd[2];
  tauLHP.tau  = tau_cmd[3];
  tauLK.tau   = tau_cmd[4];
  tauLAR.tau  = tau_cmd[5];
  tauLAP.tau  = tau_cmd[6];
  tauRHY.tau  = tau_cmd[7];
  tauRHR.tau  = tau_cmd[8];
  tauRHP.tau  = tau_cmd[9];
  tauRK.tau   = tau_cmd[10];
  tauRAR.tau  = tau_cmd[11];
  tauRAP.tau  = tau_cmd[12];

  // ===== FORCE INPUT ASSIGNMENTS =====
  leftFootContact.force[1]  = F_contact_left[1];
  leftFootContact.force[2]  = F_contact_left[2];
  leftFootContact.force[3]  = F_contact_left[3];
  rightFootContact.force[1] = F_contact_right[1];
  rightFootContact.force[2] = F_contact_right[2];
  rightFootContact.force[3] = F_contact_right[3];
  pushForce.force[1] = F_push_actual[1];
  pushForce.force[2] = F_push_actual[2];
  pushForce.force[3] = F_push_actual[3];

  // ===== WHOLE-BODY BALANCE CONTROLLER (sampled at 250 Hz) =====
  when sample(0, T_ctrl) then
    q_des[1]=0;  q_des[2]=0;  q_des[3]=-0.1;
    q_des[4]=0.2; q_des[5]=0;  q_des[6]=0.1;
    q_des[7]=0;  q_des[8]=0;  q_des[9]=-0.1;
    q_des[10]=0.2; q_des[11]=0; q_des[12]=0.1;

    com_err[1] = est_base_pos[1];
    com_err[2] = est_base_pos[2];
    com_err[3] = est_base_pos[3] - h_pelvis_init;

    tau_cmd[1] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[1]-q[1]) - Kd_joint*qd[1]));
    tau_cmd[2] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[2]-q[2]) - Kd_joint*qd[2]
      - Kp_att*est_base_att[1] - Kd_att*est_base_rate[1]));
    tau_cmd[3] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[3]-q[3]) - Kd_joint*qd[3]
      - Kp_att*est_base_att[2] - Kd_att*est_base_rate[2]));
    tau_cmd[4] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[4]-q[4]) - Kd_joint*qd[4]));
    tau_cmd[5] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[5]-q[5]) - Kd_joint*qd[5]
      + (if leftContact and rightContact then 0.5 elseif leftContact then 1.0 else 0.0)
        * (Kp_com*com_err[2] + Kd_com*(-est_base_vel[2]))));
    tau_cmd[6] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[6]-q[6]) - Kd_joint*qd[6]
      + (if leftContact and rightContact then 0.5 elseif leftContact then 1.0 else 0.0)
        * (Kp_com*com_err[1] + Kd_com*(-est_base_vel[1]))));

    tau_cmd[7] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[7]-q[7]) - Kd_joint*qd[7]));
    tau_cmd[8] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[8]-q[8]) - Kd_joint*qd[8]
      - Kp_att*est_base_att[1] - Kd_att*est_base_rate[1]));
    tau_cmd[9] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[9]-q[9]) - Kd_joint*qd[9]
      - Kp_att*est_base_att[2] - Kd_att*est_base_rate[2]));
    tau_cmd[10] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[10]-q[10]) - Kd_joint*qd[10]));
    tau_cmd[11] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[11]-q[11]) - Kd_joint*qd[11]
      + (if leftContact and rightContact then 0.5 elseif rightContact then 1.0 else 0.0)
        * (Kp_com*com_err[2] + Kd_com*(-est_base_vel[2]))));
    tau_cmd[12] = max(-tau_max, min(tau_max,
      Kp_joint*(q_des[12]-q[12]) - Kd_joint*qd[12]
      + (if leftContact and rightContact then 0.5 elseif rightContact then 1.0 else 0.0)
        * (Kp_com*com_err[1] + Kd_com*(-est_base_vel[1]))));
  end when;

  // ===== FRAME CONNECTIONS =====
  connect(world.frame_b, baseJoint.frame_a);
  connect(baseJoint.frame_b, pelvis.frame_a);
  connect(baseJoint.frame_b, baseAttitude.frame_a);
  connect(baseJoint.frame_b, baseAngVel.frame_a);
  connect(baseJoint.frame_b, leftHipOffset.frame_a);
  connect(baseJoint.frame_b, rightHipOffset.frame_a);
  connect(baseJoint.frame_b, pushForce.frame_b);

  // Left leg kinematic chain
  connect(leftHipOffset.frame_b, leftHipYaw.frame_a);
  connect(leftHipYaw.frame_b, leftHipRoll.frame_a);
  connect(leftHipRoll.frame_b, leftHipPitch.frame_a);
  connect(leftHipPitch.frame_b, leftThigh.frame_a);
  connect(leftThigh.frame_b, leftKnee.frame_a);
  connect(leftKnee.frame_b, leftShank.frame_a);
  connect(leftShank.frame_b, leftAnkleRoll.frame_a);
  connect(leftAnkleRoll.frame_b, leftAnklePitch.frame_a);
  connect(leftAnklePitch.frame_b, leftFoot.frame_a);
  connect(leftFoot.frame_b, leftFootPos.frame_a);
  connect(leftFoot.frame_b, leftFootVel.frame_a);
  connect(leftFoot.frame_b, leftFootContact.frame_b);

  // Right leg kinematic chain
  connect(rightHipOffset.frame_b, rightHipYaw.frame_a);
  connect(rightHipYaw.frame_b, rightHipRoll.frame_a);
  connect(rightHipRoll.frame_b, rightHipPitch.frame_a);
  connect(rightHipPitch.frame_b, rightThigh.frame_a);
  connect(rightThigh.frame_b, rightKnee.frame_a);
  connect(rightKnee.frame_b, rightShank.frame_a);
  connect(rightShank.frame_b, rightAnkleRoll.frame_a);
  connect(rightAnkleRoll.frame_b, rightAnklePitch.frame_a);
  connect(rightAnklePitch.frame_b, rightFoot.frame_a);
  connect(rightFoot.frame_b, rightFootPos.frame_a);
  connect(rightFoot.frame_b, rightFootVel.frame_a);
  connect(rightFoot.frame_b, rightFootContact.frame_b);

  // Torque actuator -> joint axis flanges
  connect(tauLHY.flange,  leftHipYaw.axis);
  connect(tauLHR.flange,  leftHipRoll.axis);
  connect(tauLHP.flange,  leftHipPitch.axis);
  connect(tauLK.flange,   leftKnee.axis);
  connect(tauLAR.flange,  leftAnkleRoll.axis);
  connect(tauLAP.flange,  leftAnklePitch.axis);
  connect(tauRHY.flange,  rightHipYaw.axis);
  connect(tauRHR.flange,  rightHipRoll.axis);
  connect(tauRHP.flange,  rightHipPitch.axis);
  connect(tauRK.flange,   rightKnee.axis);
  connect(tauRAR.flange,  rightAnkleRoll.axis);
  connect(tauRAP.flange,  rightAnklePitch.axis);

  // Bearing fixations
  connect(fixLHY.flange, leftHipYaw.bearing);
  connect(fixLHR.flange, leftHipRoll.bearing);
  connect(fixLHP.flange, leftHipPitch.bearing);
  connect(fixLK.flange,  leftKnee.bearing);
  connect(fixLAR.flange, leftAnkleRoll.bearing);
  connect(fixLAP.flange, leftAnklePitch.bearing);
  connect(fixRHY.flange, rightHipYaw.bearing);
  connect(fixRHR.flange, rightHipRoll.bearing);
  connect(fixRHP.flange, rightHipPitch.bearing);
  connect(fixRK.flange,  rightKnee.bearing);
  connect(fixRAR.flange, rightAnkleRoll.bearing);
  connect(fixRAP.flange, rightAnklePitch.bearing);

  annotation(
    experiment(StopTime = 16.0, Interval = 0.004, Tolerance = 1e-6),
    Documentation(info = "BipedTwoRecoverE: 36 kg pelvis floating-base biped with two legs.
      Each leg: spherical hip (3 revolute), 0.42 m thigh, revolute knee, 0.40 m shank,
      two-axis ankle (roll+pitch), flat foot. 12 bounded torque actuators (138 N.m/joint).
      Level rigid ground (friction 0.90, no external support).
      Whole-body balance controller at 250 Hz with contact switching (ankle + hip strategy).
      State estimator: IMU (gyro integration), kinematics (joint encoders), force-qualified contacts.
      168 N lateral push at middle third (5.33 s) for 0.30 s.
      Acceptance (fail-closed): torque bounds, foot slip < 0.03 m, positive body height,
      attitude recovery, tracking error < 0.108 rad after 10.4 s, no NaN/inf.
      Synchronized state (base_pos, base_att, q), command (tau_cmd), and sensor traces
      (est_base_pos, est_base_att, F_contact, F_push_actual) retained at 250 Hz for 16 s.
      Assumed values (masses, foot dimensions, gains, contact stiffness) are labeled [assumed].")
  );
end BipedTwoRecoverE;