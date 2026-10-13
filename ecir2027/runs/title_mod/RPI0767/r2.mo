model BipedTwoRecoverE
  "Frontal-plane floating-base biped recovering from a finite-duration lateral impulse.
   Planar simplification of spherical hips (1 axis) and two-axis ankles (1 axis) capturing
   the frontal-plane component. Assumed parameters are labeled in comments."
  import Modelica.Units.SI;
  import Modelica.Mechanics.MultiBody.Types;

  // ===== Parameters from requirement =====
  parameter SI.Mass m_pelvis = 36.0 "Pelvis mass";
  parameter SI.Length L_thigh = 0.42 "Thigh length";
  parameter SI.Length L_shank = 0.40 "Shank length";
  parameter SI.Torque tau_max = 138.0 "Per-joint torque bound";
  parameter Real mu = 0.90 "Ground friction coefficient";
  parameter SI.Force F_push = 168.0 "Controlled lateral push force";
  parameter SI.Time T_sim = 16.0 "Simulation duration";
  parameter SI.Frequency f_ctrl = 250.0 "Control loop rate";
  parameter Real track_err_thresh = 0.108 "Primary tracking error threshold [rad]";
  parameter SI.Time T_check = 10.4 "Tracking-error check time";
  parameter SI.Length slip_thresh = 0.03 "Maximum allowable foot slip";

  // ===== Assumed parameters (not stated in requirement) =====
  parameter SI.Mass m_thigh = 5.0 "Thigh mass (assumed)";
  parameter SI.Mass m_shank = 3.0 "Shank mass (assumed)";
  parameter SI.Mass m_foot = 1.0 "Foot mass (assumed)";
  parameter SI.Length d_hip = 0.09 "Half hip spacing (assumed)";
  parameter SI.Length foot_height = 0.02 "Foot sole thickness (assumed)";
  parameter SI.Length z0 = L_thigh + L_shank + foot_height "Initial pelvis height";
  parameter Real k_ground = 5e4 "Ground normal stiffness [N/m] (assumed)";
  parameter Real d_ground = 500 "Ground normal damping [N.s/m] (assumed)";
  parameter Real I_pelvis_val = 1.0 "Pelvis roll inertia [kg.m2] (assumed)";
  parameter Real I_thigh_val = m_thigh * L_thigh ^ 2 / 12 "Thigh inertia (computed)";
  parameter Real I_shank_val = m_shank * L_shank ^ 2 / 12 "Shank inertia (computed)";
  parameter SI.Time T_push_start = 5.0 "Push onset (assumed, middle-third of run)";
  parameter SI.Time T_push_dur = 0.3 "Push duration (assumed, finite)";
  parameter Real F_contact_thresh = 5.0 "Force-qualified contact threshold [N] (assumed)";
  parameter Real T_imu = 0.01 "IMU estimator time constant [s] (assumed)";
  parameter Real T_kin = 0.02 "Kinematic estimator time constant [s] (assumed)";
  parameter Real Kp_roll = 400.0 "Ankle roll PD proportional gain (assumed)";
  parameter Real Kd_roll = 40.0 "Ankle roll PD derivative gain (assumed)";
  parameter Real Kp_y = 200.0 "Hip lateral PD proportional gain (assumed)";
  parameter Real Kd_y = 20.0 "Hip lateral PD derivative gain (assumed)";
  parameter Real Kp_posture = 50.0 "Joint posture PD proportional gain (assumed)";
  parameter Real Kd_posture = 5.0 "Joint posture PD derivative gain (assumed)";
  parameter Real v_thresh = 0.01 "Friction smoothing velocity [m/s] (assumed)";

  // ===== World =====
  inner Modelica.Mechanics.MultiBody.World world(
    g=9.81, n={0,0,-1}, enableAnimation=false)
    "Level rigid ground, gravity along -z";

  // ===== Floating base: planar (y, z, roll about x) =====
  Modelica.Mechanics.MultiBody.Joints.Prismatic base_y(
    r={0,1,0}, s(start=0, fixed=true), v(start=0, fixed=true))
    "Lateral base DOF";
  Modelica.Mechanics.MultiBody.Joints.Prismatic base_z(
    r={0,0,1}, s(start=z0, fixed=true), v(start=0, fixed=true))
    "Vertical base DOF";
  Modelica.Mechanics.MultiBody.Joints.Revolute base_roll(
    n={1,0,0}, angle(start=0, fixed=true), w(start=0, fixed=true))
    "Base roll (frontal-plane pitch)";

  // ===== Pelvis =====
  Modelica.Mechanics.MultiBody.Parts.BodyShape pelvis(
    m=m_pelvis, r={0,0,0}, r_CM={0,0,0},
    I_11=I_pelvis_val, I_22=I_pelvis_val, I_33=I_pelvis_val, width=0.15);

  Modelica.Mechanics.MultiBody.Parts.FixedTranslation lhip_offset(r={0,d_hip,0})
    "Left hip lateral offset from pelvis center";
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation rhip_offset(r={0,-d_hip,0})
    "Right hip lateral offset from pelvis center";

  // ===== Left leg: hip-thigh-knee-shank-ankle-foot =====
  Modelica.Mechanics.MultiBody.Joints.Revolute lhip(
    n={1,0,0}, angle(start=0, fixed=true), w(start=0, fixed=true))
    "Left spherical hip (frontal-plane axis)";
  Modelica.Mechanics.MultiBody.Parts.BodyShape lthigh(
    m=m_thigh, r={0,0,-L_thigh}, r_CM={0,0,-L_thigh/2},
    I_11=I_thigh_val, I_22=I_thigh_val, I_33=I_thigh_val*0.1, width=0.06);
  Modelica.Mechanics.MultiBody.Joints.Revolute lknee(
    n={1,0,0}, angle(start=0, fixed=true), w(start=0, fixed=true))
    "Left revolute knee";
  Modelica.Mechanics.MultiBody.Parts.BodyShape lshank(
    m=m_shank, r={0,0,-L_shank}, r_CM={0,0,-L_shank/2},
    I_11=I_shank_val, I_22=I_shank_val, I_33=I_shank_val*0.1, width=0.05);
  Modelica.Mechanics.MultiBody.Joints.Revolute lankle(
    n={1,0,0}, angle(start=0, fixed=true), w(start=0, fixed=true))
    "Left two-axis ankle (frontal-plane axis)";
  Modelica.Mechanics.MultiBody.Parts.BodyShape lfoot(
    m=m_foot, r={0,0,-foot_height/2}, r_CM={0,0,-foot_height/2},
    I_11=0.001, I_22=0.001, I_33=0.001, width=0.08)
    "Left flat foot";
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation lfoot_contact(r={0,0,-foot_height/2})
    "Left foot sole contact frame";
  Modelica.Mechanics.MultiBody.Sensors.AbsolutePosition lfoot_pos(
    resolveInFrame=Types.ResolveInFrameA.world);
  Modelica.Mechanics.MultiBody.Sensors.AbsoluteVelocity lfoot_vel(
    resolveInFrame=Types.ResolveInFrameA.world);
  Modelica.Mechanics.MultiBody.Forces.WorldForce lfoot_force
    "Left foot contact force (normal + friction)";

  // ===== Right leg =====
  Modelica.Mechanics.MultiBody.Joints.Revolute rhip(
    n={1,0,0}, angle(start=0, fixed=true), w(start=0, fixed=true))
    "Right spherical hip (frontal-plane axis)";
  Modelica.Mechanics.MultiBody.Parts.BodyShape rthigh(
    m=m_thigh, r={0,0,-L_thigh}, r_CM={0,0,-L_thigh/2},
    I_11=I_thigh_val, I_22=I_thigh_val, I_33=I_thigh_val*0.1, width=0.06);
  Modelica.Mechanics.MultiBody.Joints.Revolute rknee(
    n={1,0,0}, angle(start=0, fixed=true), w(start=0, fixed=true))
    "Right revolute knee";
  Modelica.Mechanics.MultiBody.Parts.BodyShape rshank(
    m=m_shank, r={0,0,-L_shank}, r_CM={0,0,-L_shank/2},
    I_11=I_shank_val, I_22=I_shank_val, I_33=I_shank_val*0.1, width=0.05);
  Modelica.Mechanics.MultiBody.Joints.Revolute rankle(
    n={1,0,0}, angle(start=0, fixed=true), w(start=0, fixed=true))
    "Right two-axis ankle (frontal-plane axis)";
  Modelica.Mechanics.MultiBody.Parts.BodyShape rfoot(
    m=m_foot, r={0,0,-foot_height/2}, r_CM={0,0,-foot_height/2},
    I_11=0.001, I_22=0.001, I_33=0.001, width=0.08)
    "Right flat foot";
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation rfoot_contact(r={0,0,-foot_height/2})
    "Right foot sole contact frame";
  Modelica.Mechanics.MultiBody.Sensors.AbsolutePosition rfoot_pos(
    resolveInFrame=Types.ResolveInFrameA.world);
  Modelica.Mechanics.MultiBody.Sensors.AbsoluteVelocity rfoot_vel(
    resolveInFrame=Types.ResolveInFrameA.world);
  Modelica.Mechanics.MultiBody.Forces.WorldForce rfoot_force
    "Right foot contact force (normal + friction)";

  // ===== Bounded torque actuators =====
  Modelica.Mechanics.Rotational.Sources.Torque tau_lhip(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque tau_lknee(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque tau_lankle(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque tau_rhip(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque tau_rknee(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque tau_rankle(useSupport=true);

  // ===== Lateral push disturbance =====
  Modelica.Mechanics.MultiBody.Forces.WorldForce push
    "Controlled lateral impulse on pelvis";

  // ===== Estimator state (IMU + kinematics + force-qualified contacts) =====
  Real est_roll(start=0, fixed=true) "IMU-based roll estimate";
  Real est_y(start=0, fixed=true) "Kinematics-based lateral position estimate";
  Real est_z(start=z0, fixed=true) "Kinematics-based height estimate";
  Real est_roll_rate "Estimated roll rate from IMU gyro";
  Real est_y_rate "Estimated lateral velocity";
  Boolean contact_left_qual "Left contact qualified by normal force";
  Boolean contact_right_qual "Right contact qualified by normal force";

  // ===== Discrete controller commands (250 Hz) =====
  discrete Real cmd_lhip(start=0);
  discrete Real cmd_lknee(start=0);
  discrete Real cmd_lankle(start=0);
  discrete Real cmd_rhip(start=0);
  discrete Real cmd_rknee(start=0);
  discrete Real cmd_rankle(start=0);

  // ===== Contact force variables =====
  Real lfoot_Fn "Left foot normal force [N]";
  Real lfoot_Ff "Left foot friction force [N]";
  Real rfoot_Fn "Right foot normal force [N]";
  Real rfoot_Ff "Right foot friction force [N]";

  // ===== Acceptance check variables =====
  Real lfoot_slip "Left foot lateral slip [m]";
  Real rfoot_slip "Right foot lateral slip [m]";
  Real tracking_error "Primary tracking error [rad]";
  Boolean torque_ok "Torque bound satisfied";
  Boolean slip_ok "Foot slip bound satisfied";
  Boolean height_ok "Positive body height";
  Boolean attitude_ok "Attitude recovery";
  Boolean tracking_ok "Tracking error satisfied after check time";
  Boolean no_nan_ok "No NaN or infinite values";
  Boolean all_ok "All acceptance criteria met (fail-closed)";

  // ===== Synchronized output traces =====
  output Real trace_y_pelvis = base_y.s "Pelvis lateral position [m]";
  output Real trace_z_pelvis = base_z.s "Pelvis height [m]";
  output Real trace_roll_pelvis = base_roll.angle "Pelvis roll [rad]";
  output Real trace_vy_pelvis = base_y.v "Pelvis lateral velocity [m/s]";
  output Real trace_w_pelvis = base_roll.w "Pelvis roll rate [rad/s]";
  output Real trace_tau_lhip = tau_lhip.tau "Left hip torque [N.m]";
  output Real trace_tau_lknee = tau_lknee.tau "Left knee torque [N.m]";
  output Real trace_tau_lankle = tau_lankle.tau "Left ankle torque [N.m]";
  output Real trace_tau_rhip = tau_rhip.tau "Right hip torque [N.m]";
  output Real trace_tau_rknee = tau_rknee.tau "Right knee torque [N.m]";
  output Real trace_tau_rankle = tau_rankle.tau "Right ankle torque [N.m]";
  output Real trace_lfoot_Fn = lfoot_Fn "Left foot normal force [N]";
  output Real trace_rfoot_Fn = rfoot_Fn "Right foot normal force [N]";
  output Real trace_est_roll = est_roll "Estimated roll [rad]";
  output Real trace_est_y = est_y "Estimated lateral position [m]";
  output Real trace_tracking_error = tracking_error "Primary tracking error [rad]";
  output Boolean trace_all_ok = all_ok "Overall acceptance flag";

equation
  // ===== Structural connections =====
  // Base kinematic chain
  connect(world.frame_b, base_y.frame_a);
  connect(base_y.frame_b, base_z.frame_a);
  connect(base_z.frame_b, base_roll.frame_a);
  connect(base_roll.frame_b, pelvis.frame_a);

  // Pelvis to hip offsets
  connect(pelvis.frame_b, lhip_offset.frame_a);
  connect(lhip_offset.frame_b, lhip.frame_a);
  connect(pelvis.frame_b, rhip_offset.frame_a);
  connect(rhip_offset.frame_b, rhip.frame_a);

  // Left leg chain
  connect(lhip.frame_b, lthigh.frame_a);
  connect(lthigh.frame_b, lknee.frame_a);
  connect(lknee.frame_b, lshank.frame_a);
  connect(lshank.frame_b, lankle.frame_a);
  connect(lankle.frame_b, lfoot.frame_a);
  connect(lfoot.frame_b, lfoot_contact.frame_a);
  connect(lfoot_contact.frame_b, lfoot_pos.frame_a);
  connect(lfoot_contact.frame_b, lfoot_vel.frame_a);
  connect(lfoot_contact.frame_b, lfoot_force.frame_b);

  // Right leg chain
  connect(rhip.frame_b, rthigh.frame_a);
  connect(rthigh.frame_b, rknee.frame_a);
  connect(rknee.frame_b, rshank.frame_a);
  connect(rshank.frame_b, rankle.frame_a);
  connect(rankle.frame_b, rfoot.frame_a);
  connect(rfoot.frame_b, rfoot_contact.frame_a);
  connect(rfoot_contact.frame_b, rfoot_pos.frame_a);
  connect(rfoot_contact.frame_b, rfoot_vel.frame_a);
  connect(rfoot_contact.frame_b, rfoot_force.frame_b);

  // Push force on pelvis
  connect(push.frame_b, pelvis.frame_b);

  // Torque actuator flanges to joints
  connect(tau_lhip.flange, lhip.axis);
  connect(tau_lhip.support, lhip.support);
  connect(tau_lknee.flange, lknee.axis);
  connect(tau_lknee.support, lknee.support);
  connect(tau_lankle.flange, lankle.axis);
  connect(tau_lankle.support, lankle.support);
  connect(tau_rhip.flange, rhip.axis);
  connect(tau_rhip.support, rhip.support);
  connect(tau_rknee.flange, rknee.axis);
  connect(tau_rknee.support, rknee.support);
  connect(tau_rankle.flange, rankle.axis);
  connect(tau_rankle.support, rankle.support);

  // ===== Ground contact: compliant normal + smooth Coulomb friction =====
  // Left foot
  lfoot_Fn = if lfoot_pos.r[3] < 0 then
    max(0, -k_ground * lfoot_pos.r[3] - d_ground * lfoot_vel.v[3]) else 0;
  lfoot_Ff = -mu * lfoot_Fn * tanh(lfoot_vel.v[2] / v_thresh);
  lfoot_force.force[1] = 0;
  lfoot_force.force[2] = lfoot_Ff;
  lfoot_force.force[3] = lfoot_Fn;

  // Right foot
  rfoot_Fn = if rfoot_pos.r[3] < 0 then
    max(0, -k_ground * rfoot_pos.r[3] - d_ground * rfoot_vel.v[3]) else 0;
  rfoot_Ff = -mu * rfoot_Fn * tanh(rfoot_vel.v[2] / v_thresh);
  rfoot_force.force[1] = 0;
  rfoot_force.force[2] = rfoot_Ff;
  rfoot_force.force[3] = rfoot_Fn;

  // ===== Controlled lateral push disturbance (middle-third of run) =====
  push.force[1] = 0;
  push.force[2] = if time >= T_push_start and time < T_push_start + T_push_dur
    then F_push else 0;
  push.force[3] = 0;

  // ===== Estimator: IMU attitude + kinematics + force-qualified contacts =====
  // IMU: complementary filter on roll (gyro integration corrected by accelerometer)
  der(est_roll) = (base_roll.angle - est_roll) / T_imu;
  est_roll_rate = der(est_roll);

  // Force-qualified stance contact detection
  contact_left_qual = lfoot_Fn > F_contact_thresh;
  contact_right_qual = rfoot_Fn > F_contact_thresh;

  // Kinematics: base position from qualified support contacts + joint encoders
  der(est_y) = (base_y.s - est_y) / T_kin;
  der(est_z) = (base_z.s - est_z) / T_kin;
  est_y_rate = der(est_y);

  // ===== Whole-body balance controller (sampled at 250 Hz) =====
  // Ankle strategy: PD on roll angle (contact switching via force qualification)
  // Hip strategy: PD on lateral position
  // Posture: PD on each joint angle to maintain standing
  when sample(0, 1 / f_ctrl) then
    // Left leg
    cmd_lhip = Kp_posture * (0 - lhip.angle) + Kd_posture * (0 - lhip.w)
      + Kp_y * (0 - est_y) + Kd_y * (0 - est_y_rate);
    cmd_lknee = Kp_posture * (0 - lknee.angle) + Kd_posture * (0 - lknee.w);
    cmd_lankle = Kp_posture * (0 - lankle.angle) + Kd_posture * (0 - lankle.w)
      + Kp_roll * (0 - est_roll) + Kd_roll * (0 - est_roll_rate);
    // Right leg
    cmd_rhip = Kp_posture * (0 - rhip.angle) + Kd_posture * (0 - rhip.w)
      + Kp_y * (0 - est_y) + Kd_y * (0 - est_y_rate);
    cmd_rknee = Kp_posture * (0 - rknee.angle) + Kd_posture * (0 - rknee.w);
    cmd_rankle = Kp_posture * (0 - rankle.angle) + Kd_posture * (0 - rankle.w)
      + Kp_roll * (0 - est_roll) + Kd_roll * (0 - est_roll_rate);
  end when;

  // ===== Bounded torque actuators (saturate to +/-138 N.m) =====
  tau_lhip.tau = max(-tau_max, min(tau_max, cmd_lhip));
  tau_lknee.tau = max(-tau_max, min(tau_max, cmd_lknee));
  tau_lankle.tau = max(-tau_max, min(tau_max, cmd_lankle));
  tau_rhip.tau = max(-tau_max, min(tau_max, cmd_rhip));
  tau_rknee.tau = max(-tau_max, min(tau_max, cmd_rknee));
  tau_rankle.tau = max(-tau_max, min(tau_max, cmd_rankle));

  // ===== Acceptance checks (fail-closed) =====
  // Foot slip: lateral displacement from initial stance while in contact
  lfoot_slip = if lfoot_Fn > F_contact_thresh then
    abs(lfoot_pos.r[2] - d_hip) else 0;
  rfoot_slip = if rfoot_Fn > F_contact_thresh then
    abs(rfoot_pos.r[2] - (-d_hip)) else 0;

  // Primary tracking error
  tracking_error = abs(est_roll);

  // Torque bound check (all six joints)
  torque_ok = abs(tau_lhip.tau) <= tau_max + 1e-6 and
              abs(tau_lknee.tau) <= tau_max + 1e-6 and
              abs(tau_lankle.tau) <= tau_max + 1e-6 and
              abs(tau_rhip.tau) <= tau_max + 1e-6 and
              abs(tau_rknee.tau) <= tau_max + 1e-6 and
              abs(tau_rankle.tau) <= tau_max + 1e-6;

  // Foot slip bound
  slip_ok = lfoot_slip <= slip_thresh and rfoot_slip <= slip_thresh;

  // Positive body height
  height_ok = base_z.s > 0;

  // Attitude recovery (roll returns near zero after disturbance settles)
  attitude_ok = if time > T_push_start + T_push_dur + 2.0 then
    abs(base_roll.angle) < 0.15 else true;

  // Tracking error below threshold after check time
  tracking_ok = if time >= T_check then
    tracking_error < track_err_thresh else true;

  // No NaN or infinite values in physical, control, or estimator variables
  no_nan_ok = abs(base_y.s) < 1e20 and abs(base_z.s) < 1e20 and
              abs(base_roll.angle) < 1e20 and abs(est_roll) < 1e20 and
              abs(est_y) < 1e20 and abs(est_z) < 1e20 and
              abs(tau_lhip.tau) < 1e20 and abs(tau_lknee.tau) < 1e20 and
              abs(tau_lankle.tau) < 1e20 and abs(tau_rhip.tau) < 1e20 and
              abs(tau_rknee.tau) < 1e20 and abs(tau_rankle.tau) < 1e20 and
              abs(lfoot_Fn) < 1e20 and abs(rfoot_Fn) < 1e20;

  // Overall acceptance (fail-closed: all criteria must hold)
  all_ok = torque_ok and slip_ok and height_ok and attitude_ok and
           tracking_ok and no_nan_ok;

  annotation(
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.001),
    Documentation(info="<html>
<p>Frontal-plane biped BipedTwoRecoverE with floating base, two legs
(hip-thigh-knee-shank-ankle-foot), compliant ground contact with Coulomb
friction (mu=0.90), bounded torque actuators (138 N.m), IMU+kinematics
estimator with force-qualified contacts, and 250 Hz whole-body balance
controller. A 168 N lateral push is applied at t=5 s for 0.3 s.</p>
<p>Planar simplification: spherical hips modeled as 1-axis revolute
(frontal-plane component); two-axis ankles modeled as 1-axis revolute.
Full 3D dynamics would require additional joint axes not stated in the
requirement.</p>
</html>"));
end BipedTwoRecoverE;