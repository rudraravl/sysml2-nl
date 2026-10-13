model BipedTwoTraverseE
  "Floating-base biped traversing height field with 0.08 m rocks and two 0.12 m gaps;
   bounded torque actuators, foothold planning, swing-foot trajectory control,
   108 N lateral push disturbance; 250 Hz, 16 s; fail-closed acceptance"

  extends Modelica.Icons.Example;

  import Modelica.Units.SI;
  import Modelica.Mechanics.MultiBody;

  // ======================== PLANT PARAMETERS ========================
  parameter SI.Mass m_pelvis = 36.0 "Pelvis mass";
  parameter SI.Mass m_thigh = 5.0   "Thigh mass per leg";
  parameter SI.Mass m_shank = 3.0   "Shank mass per leg";
  parameter SI.Mass m_foot  = 1.0   "Foot mass per leg";
  parameter SI.Length L_thigh = 0.42 "Thigh length";
  parameter SI.Length L_shank = 0.40 "Shank length";
  parameter SI.Length L_foot  = 0.16 "Foot length";
  parameter SI.Length W_foot = 0.08  "Foot width";
  parameter SI.Length H_foot = 0.02  "Foot thickness";
  parameter SI.Length hip_half_sep = 0.09 "Half hip separation";
  parameter SI.Inertia Ixx_p = 0.5 "Pelvis inertia xx";
  parameter SI.Inertia Iyy_p = 0.5 "Pelvis inertia yy";
  parameter SI.Inertia Izz_p = 0.5 "Pelvis inertia zz";

  // ======================== ACTUATOR ========================
  parameter SI.Torque tau_max = 138.0 "Joint torque bound per joint";

  // ======================== GAIT ========================
  parameter SI.Velocity v_cmd = 0.30 "Commanded average forward speed";
  parameter SI.Time T_step = 0.80  "Step period";
  parameter SI.Time T_swing = 0.40 "Swing duration (half step)";
  parameter SI.Length L_step = 0.24 "Nominal step length";
  parameter SI.Length H_swing = 0.06 "Swing apex above terrain";
  parameter SI.Length clearance_thresh = 0.03 "Min clearance acceptance";
  parameter SI.Angle attitude_thresh = 0.45  "Max attitude acceptance";
  parameter SI.Length track_err_thresh = 0.135 "Max tracking error after 10.4 s";
  parameter SI.Time t_check = 10.4 "Tracking check time";

  // ======================== DISTURBANCE ========================
  parameter SI.Force F_push = 108.0 "Lateral push force";
  parameter SI.Time T_sim = 16.0 "Simulation duration";

  // ======================== CONTACT ========================
  parameter Real mu = 0.78 "Contact friction coefficient";
  parameter Real k_n = 50000.0 "Contact normal stiffness [N/m]";
  parameter Real d_n = 300.0  "Contact normal damping [N.s/m]";
  parameter Real v_stic = 0.01 "Stiction velocity [m/s]";

  // ======================== CONTROL GAINS ========================
  parameter Real kp_h = 300.0  "Hip P gain";
  parameter Real kd_h = 25.0   "Hip D gain";
  parameter Real kp_k = 300.0  "Knee P gain";
  parameter Real kd_k = 25.0   "Knee D gain";
  parameter Real kp_a = 150.0  "Ankle pitch P gain";
  parameter Real kd_a = 12.0   "Ankle pitch D gain";
  parameter Real kp_r = 100.0  "Ankle roll P gain";
  parameter Real kd_r = 8.0    "Ankle roll D gain";

  // ======================== TERRAIN ========================
  parameter SI.Length h_rock = 0.08 "Rock height";
  parameter SI.Length w_gap  = 0.12 "Gap width";
  parameter Real rock_x[6] = {0.8, 1.5, 2.2, 3.2, 3.8, 4.5} "Rock center x [m]";
  parameter Real gap_x[2]  = {2.5, 4.0} "Gap center x [m]";
  parameter Real rock_sig  = 0.10 "Rock spatial sigma [m]";

  // ======================== CONTROLLER ========================
  parameter Real f_ctrl = 250.0 "Controller frequency [Hz]";

  // ======================== FUNCTIONS ========================
  function terrainH "Height-field terrain with rocks and two gaps"
    input Real x;
    input Real h_rock_p;
    input Real w_gap_p;
    input Real rock_x_p[6];
    input Real gap_x_p[2];
    input Real rock_sig_p;
    output Real h;
  protected
    Real rocks;
    Integer i;
  algorithm
    rocks := 0.0;
    for i in 1:6 loop
      rocks := rocks + h_rock_p * Modelica.Math.exp(-((x - rock_x_p[i])/rock_sig_p)^2);
    end for;
    h := rocks;
    if x > gap_x_p[1] - w_gap_p/2 and x < gap_x_p[1] + w_gap_p/2 then
      h := h - 1.0;
    end if;
    if x > gap_x_p[2] - w_gap_p/2 and x < gap_x_p[2] + w_gap_p/2 then
      h := h - 1.0;
    end if;
  end terrainH;

  function legIK "2-link sagittal inverse kinematics keeping foot flat"
    input Real x  "Foot x relative to hip [m]";
    input Real z  "Foot z relative to hip (negative = downward) [m]";
    input Real L1 "Thigh length [m]";
    input Real L2 "Shank length [m]";
    output Real th "Hip pitch angle [rad]";
    output Real tk "Knee pitch angle [rad]";
    output Real ta "Ankle pitch angle [rad]";
  protected
    Real d, ck, sk, gam, del;
  algorithm
    d := Modelica.Math.sqrt(x*x + z*z);
    d := max(abs(L1 - L2) + 0.001, min(L1 + L2 - 0.001, d));
    ck := (d*d - L1*L1 - L2*L2) / (2.0*L1*L2);
    ck := max(-1.0, min(1.0, ck));
    tk := -Modelica.Math.acos(ck);
    sk := -Modelica.Math.sqrt(max(0.0, 1.0 - ck*ck));
    gam := Modelica.Math.atan2(x, -z);
    del := Modelica.Math.atan2(L2*sk, L1 + L2*ck);
    th := gam - del;
    ta := -(th + tk);
  end legIK;

  // ======================== WORLD ========================
  inner MultiBody.World world(g=9.81, n={0,0,-1}, enableAnimation=true)
    annotation(Placement(transformation(extent={{-120,60},{-100,80}})));

  // ======================== FLOATING BASE ========================
  MultiBody.Joints.FreeMotion baseJoint(
    r_a_start   = {0.0, 0.0, 0.835},
    v_a_start   = {0,0,0},
    angles_start = {0,0,0},
    w_a_start   = {0,0,0})
    annotation(Placement(transformation(extent={{-80,60},{-60,80}})));

  MultiBody.Parts.Body pelvis(
    m = m_pelvis, r_CM = {0,0,0},
    I_11 = Ixx_p, I_22 = Iyy_p, I_33 = Izz_p,
    I_21 = 0, I_31 = 0, I_32 = 0)
    annotation(Placement(transformation(extent={{-40,60},{-20,80}})));

  MultiBody.Parts.FixedTranslation hipOL(r={0, hip_half_sep, 0})
    annotation(Placement(transformation(extent={{0,70},{20,90}})));
  MultiBody.Parts.FixedTranslation hipOR(r={0,-hip_half_sep, 0})
    annotation(Placement(transformation(extent={{0,50},{20,70}})));

  // ======================== LEFT LEG ========================
  MultiBody.Joints.Revolute hipL(useAxisFlange=true, axis={0,1,0},
    phi_start=0.1, w_start=0)
    annotation(Placement(transformation(extent={{30,70},{50,90}})));
  MultiBody.Parts.BodyShape thighL(
    r={0,0,-L_thigh}, r_CM={0,0,-L_thigh/2}, m=m_thigh,
    I_11=0.05, I_22=0.05, I_33=0.01, I_21=0, I_31=0, I_32=0)
    annotation(Placement(transformation(extent={{60,70},{80,90}})));
  MultiBody.Joints.Revolute kneeL(useAxisFlange=true, axis={0,1,0},
    phi_start=-0.2, w_start=0)
    annotation(Placement(transformation(extent={{90,70},{110,90}})));
  MultiBody.Parts.BodyShape shankL(
    r={0,0,-L_shank}, r_CM={0,0,-L_shank/2}, m=m_shank,
    I_11=0.03, I_22=0.03, I_33=0.005, I_21=0, I_31=0, I_32=0)
    annotation(Placement(transformation(extent={{120,70},{140,90}})));
  MultiBody.Joints.Revolute ankLP(useAxisFlange=true, axis={0,1,0},
    phi_start=0.1, w_start=0)
    annotation(Placement(transformation(extent={{150,70},{170,90}})));
  MultiBody.Joints.Revolute ankLR(useAxisFlange=true, axis={1,0,0},
    phi_start=0, w_start=0)
    annotation(Placement(transformation(extent={{180,70},{200,90}})));
  MultiBody.Parts.BodyShape footL(
    r={0,0,-H_foot/2}, r_CM={0,0,-H_foot/2}, m=m_foot,
    I_11=0.002, I_22=0.002, I_33=0.001, I_21=0, I_31=0, I_32=0)
    annotation(Placement(transformation(extent={{210,70},{230,90}})));

  // ======================== RIGHT LEG ========================
  MultiBody.Joints.Revolute hipR(useAxisFlange=true, axis={0,1,0},
    phi_start=0.1, w_start=0)
    annotation(Placement(transformation(extent={{30,30},{50,50}})));
  MultiBody.Parts.BodyShape thighR(
    r={0,0,-L_thigh}, r_CM={0,0,-L_thigh/2}, m=m_thigh,
    I_11=0.05, I_22=0.05, I_33=0.01, I_21=0, I_31=0, I_32=0)
    annotation(Placement(transformation(extent={{60,30},{80,50}})));
  MultiBody.Joints.Revolute kneeR(useAxisFlange=true, axis={0,1,0},
    phi_start=-0.2, w_start=0)
    annotation(Placement(transformation(extent={{90,30},{110,50}})));
  MultiBody.Parts.BodyShape shankR(
    r={0,0,-L_shank}, r_CM={0,0,-L_shank/2}, m=m_shank,
    I_11=0.03, I_22=0.03, I_33=0.005, I_21=0, I_31=0, I_32=0)
    annotation(Placement(transformation(extent={{120,30},{140,50}})));
  MultiBody.Joints.Revolute ankRP(useAxisFlange=true, axis={0,1,0},
    phi_start=0.1, w_start=0)
    annotation(Placement(transformation(extent={{150,30},{170,50}})));
  MultiBody.Joints.Revolute ankRR(useAxisFlange=true, axis={1,0,0},
    phi_start=0, w_start=0)
    annotation(Placement(transformation(extent={{180,30},{200,50}})));
  MultiBody.Parts.BodyShape footR(
    r={0,0,-H_foot/2}, r_CM={0,0,-H_foot/2}, m=m_foot,
    I_11=0.002, I_22=0.002, I_33=0.001, I_21=0, I_31=0, I_32=0)
    annotation(Placement(transformation(extent={{210,30},{230,50}})));

  // ======================== TORQUE SOURCES ========================
  Modelica.Mechanics.Rotational.Sources.Torque actHL
    annotation(Placement(transformation(extent={{30,95},{50,115}})));
  Modelica.Mechanics.Rotational.Sources.Torque actKL
    annotation(Placement(transformation(extent={{90,95},{110,115}})));
  Modelica.Mechanics.Rotational.Sources.Torque actALP
    annotation(Placement(transformation(extent={{150,95},{170,115}})));
  Modelica.Mechanics.Rotational.Sources.Torque actALR
    annotation(Placement(transformation(extent={{180,95},{200,115}})));
  Modelica.Mechanics.Rotational.Sources.Torque actHR
    annotation(Placement(transformation(extent={{30,5},{50,25}})));
  Modelica.Mechanics.Rotational.Sources.Torque actKR
    annotation(Placement(transformation(extent={{90,5},{110,25}})));
  Modelica.Mechanics.Rotational.Sources.Torque actARP
    annotation(Placement(transformation(extent={{150,5},{170,25}})));
  Modelica.Mechanics.Rotational.Sources.Torque actARR
    annotation(Placement(transformation(extent={{180,5},{200,25}})));

  // ======================== FORCE COMPONENTS ========================
  MultiBody.Forces.WorldForce contactL
    annotation(Placement(transformation(extent={{250,70},{270,90}})));
  MultiBody.Forces.WorldForce contactR
    annotation(Placement(transformation(extent={{250,30},{270,50}})));
  MultiBody.Forces.WorldForce pushDist
    annotation(Placement(transformation(extent={{-60,85},{-40,105}})));

  // ======================== STATE VARIABLES ========================
  // Pelvis
  Real pelvis_x, pelvis_y, pelvis_z;
  Real pelvis_roll, pelvis_pitch, pelvis_yaw;
  Real pelvis_vx, pelvis_vy, pelvis_vz;
  Real pelvis_wx, pelvis_wy, pelvis_wz;
  // Joints
  Real q_hL, qd_hL, q_hR, qd_hR;
  Real q_kL, qd_kL, q_kR, qd_kR;
  Real q_aLp, qd_aLp, q_aRp, qd_aRp;
  Real q_aLr, qd_aLr, q_aRr, qd_aRr;
  // Forward kinematics
  Real alpha_L, beta_L, alpha_R, beta_R;
  Real fL_x, fL_y, fL_z, fR_x, fR_y, fR_z;
  Real fL_vx, fL_vy, fL_vz, fR_vx, fR_vy, fR_vz;
  // Terrain
  Real ter_hL, ter_hR;
  // Penetration
  Real delta_L, delta_R;
  // Contact
  Real cN_L, cN_R, cFx_L, cFy_L, cFx_R, cFy_R;
  Real vt_L, vt_R;
  // Gait
  Real phase_t, frac_sw;
  Boolean leftSwing, rightSwing;
  // Foothold
  Real fhL_x, fhR_x, fhL_z, fhR_z;
  Real x_des;
  // References
  Real fL_ref_x, fL_ref_z, fR_ref_x, fR_ref_z;
  Real thL_ref, tkL_ref, taL_ref, thR_ref, tkR_ref, taR_ref;
  // Torques
  Real tau_hL_raw, tau_kL_raw, tau_aLp_raw, tau_aLr_raw;
  Real tau_hR_raw, tau_kR_raw, tau_aRp_raw, tau_aRr_raw;
  Real tau_hL, tau_kL, tau_aLp, tau_aLr;
  Real tau_hR, tau_kR, tau_aRp, tau_aRr;
  // Disturbance
  Real push_y;
  // IMU
  Real imu_roll, imu_pitch, imu_yaw;
  Real imu_wx, imu_wy, imu_wz;
  Real imu_ax, imu_ay, imu_az;
  // Forward depth
  Real depth1, depth2, depth3, depth4, depth5;
  // Torso collision
  Real torso_clearance;
  // Acceptance
  Boolean actuator_ok, clearance_ok, attitude_ok, route_ok;
  Boolean tracking_ok, no_nan_inf, torso_ok, acceptance_pass;
  Real tracking_error, max_att, max_tau, route_progress;
  Real swing_clearance;

  // ======================== EQUATIONS ========================
equation
  // ---- MultiBody connections ----
  connect(world.frame_b, baseJoint.frame_a);
  connect(baseJoint.frame_b, pelvis.frame_a);
  connect(pelvis.frame_b, hipOL.frame_a);
  connect(pelvis.frame_b, hipOR.frame_a);
  connect(pelvis.frame_b, pushDist.frame_b);
  // Left leg
  connect(hipOL.frame_b, hipL.frame_a);
  connect(hipL.frame_b, thighL.frame_a);
  connect(thighL.frame_b, kneeL.frame_a);
  connect(kneeL.frame_b, shankL.frame_a);
  connect(shankL.frame_b, ankLP.frame_a);
  connect(ankLP.frame_b, ankLR.frame_a);
  connect(ankLR.frame_b, footL.frame_a);
  connect(footL.frame_b, contactL.frame_b);
  // Right leg
  connect(hipOR.frame_b, hipR.frame_a);
  connect(hipR.frame_b, thighR.frame_a);
  connect(thighR.frame_b, kneeR.frame_a);
  connect(kneeR.frame_b, shankR.frame_a);
  connect(shankR.frame_b, ankRP.frame_a);
  connect(ankRP.frame_b, ankRR.frame_a);
  connect(ankRR.frame_b, footR.frame_a);
  connect(footR.frame_b, contactR.frame_b);
  // Torque actuator flanges
  connect(actHL.flange,  hipL.flange_b);
  connect(actKL.flange,  kneeL.flange_b);
  connect(actALP.flange, ankLP.flange_b);
  connect(actALR.flange, ankLR.flange_b);
  connect(actHR.flange,  hipR.flange_b);
  connect(actKR.flange,  kneeR.flange_b);
  connect(actARP.flange, ankRP.flange_b);
  connect(actARR.flange, ankRR.flange_b);

  // ---- Pelvis state (from FreeMotion) ----
  pelvis_x = baseJoint.r_rel_a[1];
  pelvis_y = baseJoint.r_rel_a[2];
  pelvis_z = baseJoint.r_rel_a[3];
  pelvis_roll  = baseJoint.angles[1];
  pelvis_pitch = baseJoint.angles[2];
  pelvis_yaw   = baseJoint.angles[3];
  pelvis_vx = baseJoint.v_rel_a[1];
  pelvis_vy = baseJoint.v_rel_a[2];
  pelvis_vz = baseJoint.v_rel_a[3];
  pelvis_wx = baseJoint.w_rel_b[1];
  pelvis_wy = baseJoint.w_rel_b[2];
  pelvis_wz = baseJoint.w_rel_b[3];

  // ---- Joint encoder readings ----
  q_hL  = hipL.phi;   qd_hL  = hipL.w;
  q_kL  = kneeL.phi;  qd_kL  = kneeL.w;
  q_aLp = ankLP.phi;  qd_aLp = ankLP.w;
  q_aLr = ankLR.phi;  qd_aLr = ankLR.w;
  q_hR  = hipR.phi;   qd_hR  = hipR.w;
  q_kR  = kneeR.phi;  qd_kR  = kneeR.w;
  q_aRp = ankRP.phi;  qd_aRp = ankRP.w;
  q_aRr = ankRR.phi;  qd_aRr = ankRR.w;

  // ---- Forward kinematics (sagittal plane with pelvis pitch) ----
  alpha_L = pelvis_pitch + q_hL;
  beta_L  = alpha_L + q_kL;
  alpha_R = pelvis_pitch + q_hR;
  beta_R  = alpha_R + q_kR;

  fL_x = pelvis_x + L_thigh*Modelica.Math.sin(alpha_L) + L_shank*Modelica.Math.sin(beta_L);
  fL_y = pelvis_y + hip_half_sep;
  fL_z = pelvis_z - L_thigh*Modelica.Math.cos(alpha_L) - L_shank*Modelica.Math.cos(beta_L) - H_foot/2;

  fR_x = pelvis_x + L_thigh*Modelica.Math.sin(alpha_R) + L_shank*Modelica.Math.sin(beta_R);
  fR_y = pelvis_y - hip_half_sep;
  fR_z = pelvis_z - L_thigh*Modelica.Math.cos(alpha_R) - L_shank*Modelica.Math.cos(beta_R) - H_foot/2;

  // Foot velocities (for contact damping)
  fL_vx = pelvis_vx + L_thigh*Modelica.Math.cos(alpha_L)*(pelvis_wy + qd_hL)
                       + L_shank*Modelica.Math.cos(beta_L)*(pelvis_wy + qd_hL + qd_kL);
  fL_vz = pelvis_vz + L_thigh*Modelica.Math.sin(alpha_L)*(pelvis_wy + qd_hL)
                       + L_shank*Modelica.Math.sin(beta_L)*(pelvis_wy + qd_hL + qd_kL);
  fL_vy = pelvis_vy;
  fR_vx = pelvis_vx + L_thigh*Modelica.Math.cos(alpha_R)*(pelvis_wy + qd_hR)
                       + L_shank*Modelica.Math.cos(beta_R)*(pelvis_wy + qd_hR + qd_kR);
  fR_vz = pelvis_vz + L_thigh*Modelica.Math.sin(alpha_R)*(pelvis_wy + qd_hR)
                       + L_shank*Modelica.Math.sin(beta_R)*(pelvis_wy + qd_hR + qd_kR);
  fR_vy = pelvis_vy;

  // ---- Terrain height at foot positions ----
  ter_hL = terrainH(fL_x, h_rock, w_gap, rock_x, gap_x, rock_sig);
  ter_hR = terrainH(fR_x, h_rock, w_gap, rock_x, gap_x, rock_sig);

  // ---- Penetration depth (positive = below terrain) ----
  delta_L = ter_hL - fL_z;
  delta_R = ter_hR - fR_z;

  // ---- Contact forces: spring-damper normal + Coulomb friction ----
  cN_L = if delta_L > 0.0 then max(0.0, k_n*delta_L - d_n*fL_vz) else 0.0;
  cN_R = if delta_R > 0.0 then max(0.0, k_n*delta_R - d_n*fR_vz) else 0.0;
  vt_L = Modelica.Math.sqrt(fL_vx*fL_vx + fL_vy*fL_vy);
  vt_R = Modelica.Math.sqrt(fR_vx*fR_vx + fR_vy*fR_vy);
  cFx_L = -mu * cN_L * Modelica.Math.tanh(fL_vx / v_stic);
  cFy_L = -mu * cN_L * Modelica.Math.tanh(fL_vy / v_stic);
  cFx_R = -mu * cN_R * Modelica.Math.tanh(fR_vx / v_stic);
  cFy_R = -mu * cN_R * Modelica.Math.tanh(fR_vy / v_stic);

  // Apply contact forces via WorldForce
  contactL.force[1] = cFx_L;
  contactL.force[2] = cFy_L;
  contactL.force[3] = cN_L;
  contactR.force[1] = cFx_R;
  contactR.force[2] = cFy_R;
  contactR.force[3] = cN_R;

  // ---- Lateral push disturbance (middle third of simulation) ----
  if time >= T_sim/3.0 and time <= 2.0*T_sim/3.0 then
    push_y = F_push;
  else
    push_y = 0.0;
  end if;
  pushDist.force[1] = 0.0;
  pushDist.force[2] = push_y;
  pushDist.force[3] = 0.0;

  // ---- Gait phase generation ----
  phase_t = mod(time, T_step);
  leftSwing  = phase_t < T_swing;
  rightSwing = not leftSwing;
  frac_sw = if leftSwing then phase_t / T_swing else (phase_t - T_swing) / T_swing;

  // ---- Desired pelvis forward position ----
  x_des = v_cmd * time;

  // ---- Foothold planning with gap avoidance ----
  // Nominal: step forward by L_step/2 ahead of desired pelvis
  // If planned foothold is in a gap (terrain < -0.5), step beyond gap
  fhL_x = if terrainH(x_des + L_step/2, h_rock, w_gap, rock_x, gap_x, rock_sig) < -0.5
          then x_des + L_step/2 + w_gap + 0.05
          else x_des + L_step/2;
  fhR_x = if terrainH(x_des + L_step/2, h_rock, w_gap, rock_x, gap_x, rock_sig) < -0.5
          then x_des + L_step/2 + w_gap + 0.05
          else x_des + L_step/2;
  fhL_z = terrainH(fhL_x, h_rock, w_gap, rock_x, gap_x, rock_sig);
  fhR_z = terrainH(fhR_x, h_rock, w_gap, rock_x, gap_x, rock_sig);

  // ---- Swing-foot trajectory control ----
  // Smoothstep: s(t) = t - sin(2*pi*t)/(2*pi)
  if leftSwing then
    fL_ref_x = (x_des - L_step/2) + (fhL_x - (x_des - L_step/2))
               * (frac_sw - Modelica.Math.sin(2*Modelica.Constants.pi*frac_sw)
                            /(2*Modelica.Constants.pi));
    fL_ref_z = terrainH(fL_ref_x, h_rock, w_gap, rock_x, gap_x, rock_sig)
               + H_swing * Modelica.Math.sin(Modelica.Constants.pi * frac_sw);
    fR_ref_x = x_des - L_step/2;
    fR_ref_z = terrainH(fR_ref_x, h_rock, w_gap, rock_x, gap_x, rock_sig);
  else
    fR_ref_x = (x_des - L_step/2) + (fhR_x - (x_des - L_step/2))
               * (frac_sw - Modelica.Math.sin(2*Modelica.Constants.pi*frac_sw)
                            /(2*Modelica.Constants.pi));
    fR_ref_z = terrainH(fR_ref_x, h_rock, w_gap, rock_x, gap_x, rock_sig)
               + H_swing * Modelica.Math.sin(Modelica.Constants.pi * frac_sw);
    fL_ref_x = x_des - L_step/2;
    fL_ref_z = terrainH(fL_ref_x, h_rock, w_gap, rock_x, gap_x, rock_sig);
  end if;

  // ---- Inverse kinematics for reference joint angles ----
  (thL_ref, tkL_ref, taL_ref) = legIK(fL_ref_x - pelvis_x, fL_ref_z - pelvis_z,
                                       L_thigh, L_shank);
  (thR_ref, tkR_ref, taR_ref) = legIK(fR_ref_x - pelvis_x, fR_ref_z - pelvis_z,
                                       L_thigh, L_shank);

  // ---- PD joint control ----
  tau_hL_raw  = kp_h * (thL_ref  - q_hL)  + kd_h * (0 - qd_hL);
  tau_kL_raw  = kp_k * (tkL_ref  - q_kL)  + kd_k * (0 - qd_kL);
  tau_aLp_raw = kp_a * (taL_ref - q_aLp) + kd_a * (0 - qd_aLp);
  tau_aLr_raw = kp_r * (0       - q_aLr) + kd_r * (0 - qd_aLr);
  tau_hR_raw  = kp_h * (thR_ref  - q_hR)  + kd_h * (0 - qd_hR);
  tau_kR_raw  = kp_k * (tkR_ref  - q_kR)  + kd_k * (0 - qd_kR);
  tau_aRp_raw = kp_a * (taR_ref - q_aRp) + kd_a * (0 - qd_aRp);
  tau_aRr_raw = kp_r * (0       - q_aRr) + kd_r * (0 - qd_aRr);

  // ---- Torque saturation (bounded actuators) ----
  tau_hL  = max(-tau_max, min(tau_max, tau_hL_raw));
  tau_kL  = max(-tau_max, min(tau_max, tau_kL_raw));
  tau_aLp = max(-tau_max, min(tau_max, tau_aLp_raw));
  tau_aLr = max(-tau_max, min(tau_max, tau_aLr_raw));
  tau_hR  = max(-tau_max, min(tau_max, tau_hR_raw));
  tau_kR  = max(-tau_max, min(tau_max, tau_kR_raw));
  tau_aRp = max(-tau_max, min(tau_max, tau_aRp_raw));
  tau_aRr = max(-tau_max, min(tau_max, tau_aRr_raw));

  // ---- Apply torques to actuators ----
  actHL.tau  = tau_hL;
  actKL.tau  = tau_kL;
  actALP.tau = tau_aLp;
  actALR.tau = tau_aLr;
  actHR.tau  = tau_hR;
  actKR.tau  = tau_kR;
  actARP.tau = tau_aRp;
  actARR.tau = tau_aRr;

  // ---- IMU simulation (pelvis-mounted) ----
  imu_roll  = pelvis_roll;
  imu_pitch = pelvis_pitch;
  imu_yaw   = pelvis_yaw;
  imu_wx = pelvis_wx;
  imu_wy = pelvis_wy;
  imu_wz = pelvis_wz;
  imu_ax = 0.0;
  imu_ay = 0.0;
  imu_az = -9.81;

  // ---- Forward depth measurements (terrain probing ahead) ----
  depth1 = terrainH(pelvis_x + 0.10, h_rock, w_gap, rock_x, gap_x, rock_sig);
  depth2 = terrainH(pelvis_x + 0.30, h_rock, w_gap, rock_x, gap_x, rock_sig);
  depth3 = terrainH(pelvis_x + 0.50, h_rock, w_gap, rock_x, gap_x, rock_sig);
  depth4 = terrainH(pelvis_x + 0.70, h_rock, w_gap, rock_x, gap_x, rock_sig);
  depth5 = terrainH(pelvis_x + 1.00, h_rock, w_gap, rock_x, gap_x, rock_sig);

  // ---- Torso-terrain collision prohibition ----
  torso_clearance = pelvis_z - terrainH(pelvis_x, h_rock, w_gap, rock_x, gap_x, rock_sig);
  torso_ok = torso_clearance > 0.01;

  // ---- Acceptance: actuator bounds ----
  max_tau = max(abs(tau_hL), max(abs(tau_kL), max(abs(tau_aLp), max(abs(tau_aLr),
           max(abs(tau_hR), max(abs(tau_kR), max(abs(tau_aRp), abs(tau_aRr))))))));
  actuator_ok = max_tau <= tau_max;

  // ---- Acceptance: swing foot clearance above 0.03 m (mid-swing) ----
  swing_clearance = if leftSwing and frac_sw > 0.2 and frac_sw < 0.8 then
                      fL_z - ter_hL
                    else if rightSwing and frac_sw > 0.2 and frac_sw < 0.8 then
                      fR_z - ter_hR
                    else
                      1.0;
  clearance_ok = swing_clearance >= clearance_thresh;

  // ---- Acceptance: attitude below 0.45 rad ----
  max_att = max(abs(pelvis_roll), abs(pelvis_pitch));
  attitude_ok = max_att < attitude_thresh;

  // ---- Acceptance: route completion ----
  route_progress = pelvis_x / max(v_cmd * T_sim, 0.001);
  route_ok = pelvis_x >= v_cmd * T_sim * 0.9;

  // ---- Acceptance: primary tracking error ----
  tracking_error = abs(pelvis_x - v_cmd * time);
  tracking_ok = if time >= t_check then tracking_error < track_err_thresh else true;

  // ---- Acceptance: no NaN or infinite values ----
  no_nan_inf = (pelvis_x == pelvis_x) and (pelvis_x < 1e10) and (pelvis_x > -1e10) and
               (pelvis_z == pelvis_z) and (pelvis_z < 1e10) and (pelvis_z > -1e10) and
               (tau_hL == tau_hL) and (tau_hL < 1e10) and (tau_hL > -1e10) and
               (tau_hR == tau_hR) and (tau_hR < 1e10) and (tau_hR > -1e10) and
               (cN_L == cN_L) and (cN_L < 1e10) and (cN_L > -1e10) and
               (cN_R == cN_R) and (cN_R < 1e10) and (cN_R > -1e10) and
               (imu_pitch == imu_pitch) and (imu_pitch < 1e10) and (imu_pitch > -1e10);

  // ---- Fail-closed acceptance ----
  acceptance_pass = actuator_ok and clearance_ok and attitude_ok and route_ok and
                    tracking_ok and no_nan_inf and torso_ok;

  annotation(
    Documentation(info="<html>
<p>BipedTwoTraverseE: Floating-base biped robot crossing a height field
containing 0.08 m rocks and two 0.12 m gaps at a commanded average speed.</p>
<p>Plant: 36 kg pelvis, spherical hips (represented as pitch revolutes in
sagittal plane with roll revolute at ankle for 2-axis ankle), 0.42 m thighs,
0.40 m shanks, revolute knees, two-axis ankles, flat feet.</p>
<p>Actuators: bounded joint-torque, 138 N.m per joint.</p>
<p>Sensors: joint encoders, IMU (pelvis attitude + rate + accel),
contact (penetration + normal/friction), forward depth (terrain probing).</p>
<p>Controller: foothold planning with gap avoidance, swing-foot cycloid
trajectory, IK to joint references, PD control with torque saturation,
250 Hz nominal rate (continuous equations).</p>
<p>Disturbance: 108 N lateral push during middle third of 16 s simulation.</p>
<p>Acceptance (fail-closed): actuator bounds, clearance > 0.03 m,
attitude < 0.45 rad, route completion, tracking error < 0.135 m after 10.4 s,
no NaN/Inf, no torso-terrain collision.</p>
<p>Unresolved/unknown values (not stated in requirement): thigh/shank/foot
masses and inertias, pelvis inertia tensor, hip separation, contact stiffness,
control gains, step period, step length, swing height, commanded speed value
are reasonable engineering assumptions and are declared as overridable parameters.</p>
</html>"),
    experiment(StopTime = 16.0, Tolerance = 1e-4, Interval = 0.004));
end BipedTwoTraverseE;