model WheelLegClimbA
  "Floating-base wheeled-legged robot climbing four stairs with impedance control"

  // ====================== PHYSICAL PARAMETERS ======================
  parameter Real m_torso = 28.0 "Torso mass [kg]";
  parameter Real I_torso = 2.5 "Torso pitch inertia [kg.m2]";
  parameter Real L_thigh = 0.22 "Thigh length [m]";
  parameter Real L_shin = 0.22 "Shin length [m]";
  parameter Real r_wheel = 0.10 "Wheel radius [m]";
  parameter Real g_acc = 9.81 "Gravity [m/s2]";
  parameter Real I_hip = 0.04 "Hip inertia [kg.m2]";
  parameter Real I_knee = 0.02 "Knee inertia [kg.m2]";
  parameter Real I_wheel = 0.012 "Wheel inertia [kg.m2]";
  parameter Real D_joint = 0.3 "Joint viscous damping [N.m.s/rad]";
  parameter Real D_wheel_d = 0.02 "Wheel viscous damping [N.m.s/rad]";

  // ====================== CONTROL PARAMETERS ======================
  parameter Real tau_max = 39.6 "Per-joint torque limit [N.m]";
  parameter Real K_imp = 300.0 "Impedance stiffness [N.m/rad]";
  parameter Real D_imp = 15.0 "Impedance damping [N.m.s/rad]";
  parameter Real K_height = 2000.0 "Height control gain [N/m]";
  parameter Real D_height = 150.0 "Height damping [N.s/m]";
  parameter Real K_pitch_c = 400.0 "Pitch control gain [N.m/rad]";
  parameter Real D_pitch_c = 25.0 "Pitch damping [N.m.s/rad]";
  parameter Real K_vx = 30.0 "Forward velocity gain [N.s/m]";
  parameter Real v_ref = 0.30 "Reference forward velocity [m/s]";
  parameter Real h_ref = 0.42 "Reference body clearance above terrain [m]";
  parameter Real dt_ctrl = 0.0125 "Control period [s] (80 Hz)";

  // ====================== CONTACT PARAMETERS ======================
  parameter Real k_contact = 20000.0 "Contact stiffness [N/m]";
  parameter Real d_contact = 500.0 "Contact damping [N.s/m]";
  parameter Real mu_fric = 0.88 "Friction coefficient";

  // ====================== STAIR PARAMETERS ======================
  parameter Real stair_rise = 0.16 "Stair rise [m]";
  parameter Real stair_tread = 0.30 "Stair tread [m]";
  parameter Real stair_start = 0.50 "Stair start x [m]";
  parameter Integer n_stairs = 4 "Number of stairs";

  // ====================== SCENARIO PARAMETERS ======================
  parameter Real T_sim = 8.0 "Simulation duration [s]";
  parameter Real F_payload = 50.0 "Payload disturbance [N]";
  parameter Real T_dist_start = 8.0/3.0 "Disturbance start [s]";
  parameter Real T_dist_end = 16.0/3.0 "Disturbance end [s]";

  // ====================== LEG OFFSETS ======================
  parameter Real lx_front = 0.18 "Front leg x offset [m]";
  parameter Real lx_rear = -0.18 "Rear leg x offset [m]";
  parameter Real lz_attach = -0.05 "Leg attachment z offset [m]";
  parameter Real d_min = 0.06 "Min leg reach [m]";
  parameter Real d_max = 0.42 "Max leg reach [m]";
  parameter Real cos_max = 0.99 "acos clamp bound";

  // ====================== TORSO STATES ======================
  Real x_t(start=0.0) "Torso x position [m]";
  Real z_t(start=0.42) "Torso z position [m]";
  Real th_t(start=0.0) "Torso pitch [rad]";
  Real vx_t(start=0.05) "Torso x velocity [m/s]";
  Real vz_t(start=0.0) "Torso z velocity [m/s]";
  Real w_t(start=0.0) "Torso pitch rate [rad/s]";

  // ====================== LEG JOINT STATES (4 legs x 2 joints) ======================
  Real q_h1(start=-0.91) "FL hip angle [rad]";
  Real q_k1(start=1.82)  "FL knee angle [rad]";
  Real q_h2(start=-0.91) "FR hip angle [rad]";
  Real q_k2(start=1.82)  "FR knee angle [rad]";
  Real q_h3(start=-0.91) "RL hip angle [rad]";
  Real q_k3(start=1.82)  "RL knee angle [rad]";
  Real q_h4(start=-0.91) "RR hip angle [rad]";
  Real q_k4(start=1.82)  "RR knee angle [rad]";
  Real dq_h1(start=0) "FL hip velocity [rad/s]";
  Real dq_k1(start=0) "FL knee velocity [rad/s]";
  Real dq_h2(start=0) "FR hip velocity [rad/s]";
  Real dq_k2(start=0) "FR knee velocity [rad/s]";
  Real dq_h3(start=0) "RL hip velocity [rad/s]";
  Real dq_k3(start=0) "RL knee velocity [rad/s]";
  Real dq_h4(start=0) "RR hip velocity [rad/s]";
  Real dq_k4(start=0) "RR knee velocity [rad/s]";

  // ====================== WHEEL STATES (4 wheels) ======================
  Real q_w1(start=0) "FL wheel angle [rad]";
  Real q_w2(start=0) "FR wheel angle [rad]";
  Real q_w3(start=0) "RL wheel angle [rad]";
  Real q_w4(start=0) "RR wheel angle [rad]";
  Real dq_w1(start=0) "FL wheel rate [rad/s]";
  Real dq_w2(start=0) "FR wheel rate [rad/s]";
  Real dq_w3(start=0) "RL wheel rate [rad/s]";
  Real dq_w4(start=0) "RR wheel rate [rad/s]";

  // ====================== COMMAND TORQUES ======================
  Real tau_h1 "FL hip torque [N.m]";
  Real tau_h2 "FR hip torque [N.m]";
  Real tau_h3 "RL hip torque [N.m]";
  Real tau_h4 "RR hip torque [N.m]";
  Real tau_k1 "FL knee torque [N.m]";
  Real tau_k2 "FR knee torque [N.m]";
  Real tau_k3 "RL knee torque [N.m]";
  Real tau_k4 "RR knee torque [N.m]";
  Real tau_w1 "FL wheel torque [N.m]";
  Real tau_w2 "FR wheel torque [N.m]";
  Real tau_w3 "RL wheel torque [N.m]";
  Real tau_w4 "RR wheel torque [N.m]";

  // ====================== SAMPLED DESIRED ANGLES (80 Hz ZOH) ======================
  discrete Real q_h1_des(start=-0.91) "FL desired hip [rad]";
  discrete Real q_k1_des(start=1.82)  "FL desired knee [rad]";
  discrete Real q_h2_des(start=-0.91) "FR desired hip [rad]";
  discrete Real q_k2_des(start=1.82)  "FR desired knee [rad]";
  discrete Real q_h3_des(start=-0.91) "RL desired hip [rad]";
  discrete Real q_k3_des(start=1.82)  "RL desired knee [rad]";
  discrete Real q_h4_des(start=-0.91) "RR desired hip [rad]";
  discrete Real q_k4_des(start=1.82)  "RR desired knee [rad]";

  // ====================== KINEMATIC VARIABLES ======================
  Real hx1,hz1,hx2,hz2,hx3,hz3,hx4,hz4 "Hip joint positions [m]";
  Real wx1,wz1,wx2,wz2,wx3,wz3,wx4,wz4 "Wheel center positions [m]";
  Real cx1,cz1,cx2,cz2,cx3,cz3,cx4,cz4 "Contact points [m]";
  Real vcx1,vcz1,vcx2,vcz2,vcx3,vcz3,vcx4,vcz4 "Contact velocities [m/s]";
  Real jxh1,jxk1,jzh1,jzk1 "FL Jacobian elements";
  Real jxh2,jxk2,jzh2,jzk2 "FR Jacobian elements";
  Real jxh3,jxk3,jzh3,jzk3 "RL Jacobian elements";
  Real jxh4,jxk4,jzh4,jzk4 "RR Jacobian elements";

  // ====================== CONTACT VARIABLES ======================
  Real terrain1,terrain2,terrain3,terrain4 "Terrain height at each foot [m]";
  Real terrain_t "Terrain height at torso center [m]";
  Real delta1,delta2,delta3,delta4 "Contact penetration [m]";
  Real Fn1,Fn2,Fn3,Fn4 "Normal contact forces [N]";
  Real Ft1,Ft2,Ft3,Ft4 "Tangential friction forces [N]";

  // ====================== NET FORCES ON TORSO ======================
  Real Fx_total "Net horizontal force [N]";
  Real Fz_total "Net vertical force [N]";
  Real M_total  "Net pitch moment [N.m]";
  Real F_dist   "Payload disturbance force [N]";

  // ====================== IK INTERMEDIATE VARIABLES ======================
  Real dfx1,dfz1,dfx2,dfz2,dfx3,dfz3,dfx4,dfz4 "Desired foot pos rel hip [m]";
  Real d1,d2,d3,d4 "Desired leg lengths [m]";
  Real dc1,dc2,dc3,dc4 "Clamped leg lengths [m]";
  Real cqk1,cqk2,cqk3,cqk4 "cos(q_knee) from IK";
  Real qk1_ik,qk2_ik,qk3_ik,qk4_ik "IK knee angles [rad]";
  Real qh1_ik,qh2_ik,qh3_ik,qh4_ik "IK hip angles [rad]";
  Real h_corr "Shared height correction [m]";
  Real p_corr_f "Front pitch correction [m]";
  Real p_corr_r "Rear pitch correction [m]";

  // ====================== SENSORS ======================
  Real depth_clearance "Depth camera: distance to next stair edge [m]";
  Real next_edge "Next stair edge x [m]";
  Real imu_pitch "IMU pitch measurement [rad]";
  Real imu_pitch_rate "IMU pitch rate [rad/s]";
  Real enc_h1,enc_h2,enc_h3,enc_h4 "Hip encoder readings [rad]";
  Real enc_k1,enc_k2,enc_k3,enc_k4 "Knee encoder readings [rad]";
  Real enc_w1,enc_w2,enc_w3,enc_w4 "Wheel encoder readings [rad]";
  Real ff1,ff2,ff3,ff4 "Foot force sensor readings [N]";

  // ====================== METRICS ======================
  Real err_x1,err_z1,err_x3,err_z3 "Foot-space tracking errors [m]";
  Real tracking_error "Primary foothold tracking error [m]";
  Real height_error "Body height error [m]";
  Real n_support "Number of support contacts";
  Boolean completed "Scenario completion flag";

equation
  // ======================== FORWARD KINEMATICS ========================
  hx1 = x_t + lx_front*cos(th_t) - lz_attach*sin(th_t);
  hz1 = z_t + lx_front*sin(th_t) + lz_attach*cos(th_t);
  hx2 = x_t + lx_front*cos(th_t) - lz_attach*sin(th_t);
  hz2 = z_t + lx_front*sin(th_t) + lz_attach*cos(th_t);
  hx3 = x_t + lx_rear*cos(th_t) - lz_attach*sin(th_t);
  hz3 = z_t + lx_rear*sin(th_t) + lz_attach*cos(th_t);
  hx4 = x_t + lx_rear*cos(th_t) - lz_attach*sin(th_t);
  hz4 = z_t + lx_rear*sin(th_t) + lz_attach*cos(th_t);

  wx1 = hx1 + L_thigh*sin(q_h1) + L_shin*sin(q_h1+q_k1);
  wz1 = hz1 - L_thigh*cos(q_h1) - L_shin*cos(q_h1+q_k1);
  wx2 = hx2 + L_thigh*sin(q_h2) + L_shin*sin(q_h2+q_k2);
  wz2 = hz2 - L_thigh*cos(q_h2) - L_shin*cos(q_h2+q_k2);
  wx3 = hx3 + L_thigh*sin(q_h3) + L_shin*sin(q_h3+q_k3);
  wz3 = hz3 - L_thigh*cos(q_h3) - L_shin*cos(q_h3+q_k3);
  wx4 = hx4 + L_thigh*sin(q_h4) + L_shin*sin(q_h4+q_k4);
  wz4 = hz4 - L_thigh*cos(q_h4) - L_shin*cos(q_h4+q_k4);

  cx1 = wx1;  cz1 = wz1 - r_wheel;
  cx2 = wx2;  cz2 = wz2 - r_wheel;
  cx3 = wx3;  cz3 = wz3 - r_wheel;
  cx4 = wx4;  cz4 = wz4 - r_wheel;

  // ======================== JACOBIANS ========================
  jxh1 = L_thigh*cos(q_h1) + L_shin*cos(q_h1+q_k1);
  jxk1 = L_shin*cos(q_h1+q_k1);
  jzh1 = L_thigh*sin(q_h1) + L_shin*sin(q_h1+q_k1);
  jzk1 = L_shin*sin(q_h1+q_k1);
  jxh2 = L_thigh*cos(q_h2) + L_shin*cos(q_h2+q_k2);
  jxk2 = L_shin*cos(q_h2+q_k2);
  jzh2 = L_thigh*sin(q_h2) + L_shin*sin(q_h2+q_k2);
  jzk2 = L_shin*sin(q_h2+q_k2);
  jxh3 = L_thigh*cos(q_h3) + L_shin*cos(q_h3+q_k3);
  jxk3 = L_shin*cos(q_h3+q_k3);
  jzh3 = L_thigh*sin(q_h3) + L_shin*sin(q_h3+q_k3);
  jzk3 = L_shin*sin(q_h3+q_k3);
  jxh4 = L_thigh*cos(q_h4) + L_shin*cos(q_h4+q_k4);
  jxk4 = L_shin*cos(q_h4+q_k4);
  jzh4 = L_thigh*sin(q_h4) + L_shin*sin(q_h4+q_k4);
  jzk4 = L_shin*sin(q_h4+q_k4);

  // ======================== CONTACT VELOCITIES ========================
  vcx1 = vx_t + w_t*(-lx_front*sin(th_t) - lz_attach*cos(th_t)) + jxh1*dq_h1 + jxk1*dq_k1;
  vcz1 = vz_t + w_t*(lx_front*cos(th_t) - lz_attach*sin(th_t)) + jzh1*dq_h1 + jzk1*dq_k1;
  vcx2 = vx_t + w_t*(-lx_front*sin(th_t) - lz_attach*cos(th_t)) + jxh2*dq_h2 + jxk2*dq_k2;
  vcz2 = vz_t + w_t*(lx_front*cos(th_t) - lz_attach*sin(th_t)) + jzh2*dq_h2 + jzk2*dq_k2;
  vcx3 = vx_t + w_t*(-lx_rear*sin(th_t) - lz_attach*cos(th_t)) + jxh3*dq_h3 + jxk3*dq_k3;
  vcz3 = vz_t + w_t*(lx_rear*cos(th_t) - lz_attach*sin(th_t)) + jzh3*dq_h3 + jzk3*dq_k3;
  vcx4 = vx_t + w_t*(-lx_rear*sin(th_t) - lz_attach*cos(th_t)) + jxh4*dq_h4 + jxk4*dq_k4;
  vcz4 = vz_t + w_t*(lx_rear*cos(th_t) - lz_attach*sin(th_t)) + jzh4*dq_h4 + jzk4*dq_k4;

  // ======================== TERRAIN HEIGHT (inline stair function) ========================
  terrain1 = if cx1 < stair_start then 0.0
    else if cx1 >= stair_start + n_stairs*stair_tread then n_stairs*stair_rise
    else floor((cx1 - stair_start)/stair_tread)*stair_rise;
  terrain2 = if cx2 < stair_start then 0.0
    else if cx2 >= stair_start + n_stairs*stair_tread then n_stairs*stair_rise
    else floor((cx2 - stair_start)/stair_tread)*stair_rise;
  terrain3 = if cx3 < stair_start then 0.0
    else if cx3 >= stair_start + n_stairs*stair_tread then n_stairs*stair_rise
    else floor((cx3 - stair_start)/stair_tread)*stair_rise;
  terrain4 = if cx4 < stair_start then 0.0
    else if cx4 >= stair_start + n_stairs*stair_tread then n_stairs*stair_rise
    else floor((cx4 - stair_start)/stair_tread)*stair_rise;
  terrain_t = if x_t < stair_start then 0.0
    else if x_t >= stair_start + n_stairs*stair_tread then n_stairs*stair_rise
    else floor((x_t - stair_start)/stair_tread)*stair_rise;

  // ======================== CONTACT MODEL (rigid stair collision) ========================
  delta1 = terrain1 - cz1;
  delta2 = terrain2 - cz2;
  delta3 = terrain3 - cz3;
  delta4 = terrain4 - cz4;

  Fn1 = if delta1 > 0.0 then max(0.0, k_contact*delta1 - d_contact*vcz1) else 0.0;
  Fn2 = if delta2 > 0.0 then max(0.0, k_contact*delta2 - d_contact*vcz2) else 0.0;
  Fn3 = if delta3 > 0.0 then max(0.0, k_contact*delta3 - d_contact*vcz3) else 0.0;
  Fn4 = if delta4 > 0.0 then max(0.0, k_contact*delta4 - d_contact*vcz4) else 0.0;

  // ======================== WHEEL TORQUE COMMANDS (independently limited) ========================
  tau_w1 = max(-tau_max, min(tau_max, K_vx*(v_ref - vx_t)));
  tau_w2 = max(-tau_max, min(tau_max, K_vx*(v_ref - vx_t)));
  tau_w3 = max(-tau_max, min(tau_max, K_vx*(v_ref - vx_t)));
  tau_w4 = max(-tau_max, min(tau_max, K_vx*(v_ref - vx_t)));

  // ======================== FRICTION (Coulomb cone limited) ========================
  Ft1 = if delta1 > 0.0 then max(-mu_fric*Fn1, min(mu_fric*Fn1, tau_w1/r_wheel)) else 0.0;
  Ft2 = if delta2 > 0.0 then max(-mu_fric*Fn2, min(mu_fric*Fn2, tau_w2/r_wheel)) else 0.0;
  Ft3 = if delta3 > 0.0 then max(-mu_fric*Fn3, min(mu_fric*Fn3, tau_w3/r_wheel)) else 0.0;
  Ft4 = if delta4 > 0.0 then max(-mu_fric*Fn4, min(mu_fric*Fn4, tau_w4/r_wheel)) else 0.0;

  // ======================== DISTURBANCE (50 N middle third) ========================
  F_dist = if time >= T_dist_start and time <= T_dist_end then F_payload else 0.0;

  // ======================== NET FORCES ON TORSO ========================
  Fx_total = Ft1 + Ft2 + Ft3 + Ft4;
  Fz_total = Fn1 + Fn2 + Fn3 + Fn4 - m_torso*g_acc - F_dist;
  M_total = (hx1-x_t)*Fn1 - (hz1-z_t)*Ft1
          + (hx2-x_t)*Fn2 - (hz2-z_t)*Ft2
          + (hx3-x_t)*Fn3 - (hz3-z_t)*Ft3
          + (hx4-x_t)*Fn4 - (hz4-z_t)*Ft4;

  // ======================== TORSO DYNAMICS (floating base) ========================
  der(x_t) = vx_t;
  der(z_t) = vz_t;
  der(th_t) = w_t;
  der(vx_t) = Fx_total / m_torso;
  der(vz_t) = Fz_total / m_torso;
  der(w_t) = M_total / I_torso;

  // ======================== TERRAIN-AWARE HEIGHT & PITCH CORRECTIONS ========================
  h_corr = (K_height*(terrain_t + h_ref - z_t) - D_height*vz_t) / 4.0;
  p_corr_f = (K_pitch_c*th_t + D_pitch_c*w_t) / 2.0;
  p_corr_r = -(K_pitch_c*th_t + D_pitch_c*w_t) / 2.0;

  // ======================== DESIRED FOOT POSITIONS (relative to hip) ========================
  dfx1 = 0.0;
  dfz1 = -(hz1 - (terrain1 + r_wheel)) - h_corr - p_corr_f;
  dfx2 = 0.0;
  dfz2 = -(hz2 - (terrain2 + r_wheel)) - h_corr - p_corr_f;
  dfx3 = 0.0;
  dfz3 = -(hz3 - (terrain3 + r_wheel)) - h_corr - p_corr_r;
  dfx4 = 0.0;
  dfz4 = -(hz4 - (terrain4 + r_wheel)) - h_corr - p_corr_r;

  // ======================== INVERSE KINEMATICS ========================
  d1 = sqrt(dfx1*dfx1 + dfz1*dfz1);
  d2 = sqrt(dfx2*dfx2 + dfz2*dfz2);
  d3 = sqrt(dfx3*dfx3 + dfz3*dfz3);
  d4 = sqrt(dfx4*dfx4 + dfz4*dfz4);

  dc1 = max(d_min, min(d_max, d1));
  dc2 = max(d_min, min(d_max, d2));
  dc3 = max(d_min, min(d_max, d3));
  dc4 = max(d_min, min(d_max, d4));

  cqk1 = (dc1*dc1 - L_thigh*L_thigh - L_shin*L_shin) / (2.0*L_thigh*L_shin);
  cqk2 = (dc2*dc2 - L_thigh*L_thigh - L_shin*L_shin) / (2.0*L_thigh*L_shin);
  cqk3 = (dc3*dc3 - L_thigh*L_thigh - L_shin*L_shin) / (2.0*L_thigh*L_shin);
  cqk4 = (dc4*dc4 - L_thigh*L_thigh - L_shin*L_shin) / (2.0*L_thigh*L_shin);

  qk1_ik = acos(max(-cos_max, min(cos_max, cqk1)));
  qk2_ik = acos(max(-cos_max, min(cos_max, cqk2)));
  qk3_ik = acos(max(-cos_max, min(cos_max, cqk3)));
  qk4_ik = acos(max(-cos_max, min(cos_max, cqk4)));

  qh1_ik = atan2(dfx1, -dfz1) - atan2(L_shin*sin(qk1_ik), L_thigh + L_shin*cos(qk1_ik));
  qh2_ik = atan2(dfx2, -dfz2) - atan2(L_shin*sin(qk2_ik), L_thigh + L_shin*cos(qk2_ik));
  qh3_ik = atan2(dfx3, -dfz3) - atan2(L_shin*sin(qk3_ik), L_thigh + L_shin*cos(qk3_ik));
  qh4_ik = atan2(dfx4, -dfz4) - atan2(L_shin*sin(qk4_ik), L_thigh + L_shin*cos(qk4_ik));

  // ======================== SAMPLED CONTROL (80 Hz zero-order hold) ========================
  when sample(0, dt_ctrl) then
    q_h1_des = qh1_ik;
    q_k1_des = qk1_ik;
    q_h2_des = qh2_ik;
    q_k2_des = qk2_ik;
    q_h3_des = qh3_ik;
    q_k3_des = qk3_ik;
    q_h4_des = qh4_ik;
    q_k4_des = qk4_ik;
  end when;

  // ======================== JOINT-SPACE IMPEDANCE CONTROL (independently limited) ========================
  tau_h1 = max(-tau_max, min(tau_max, K_imp*(q_h1_des - q_h1) - D_imp*dq_h1));
  tau_k1 = max(-tau_max, min(tau_max, K_imp*(q_k1_des - q_k1) - D_imp*dq_k1));
  tau_h2 = max(-tau_max, min(tau_max, K_imp*(q_h2_des - q_h2) - D_imp*dq_h2));
  tau_k2 = max(-tau_max, min(tau_max, K_imp*(q_k2_des - q_k2) - D_imp*dq_k2));
  tau_h3 = max(-tau_max, min(tau_max, K_imp*(q_h3_des - q_h3) - D_imp*dq_h3));
  tau_k3 = max(-tau_max, min(tau_max, K_imp*(q_k3_des - q_k3) - D_imp*dq_k3));
  tau_h4 = max(-tau_max, min(tau_max, K_imp*(q_h4_des - q_h4) - D_imp*dq_h4));
  tau_k4 = max(-tau_max, min(tau_max, K_imp*(q_k4_des - q_k4) - D_imp*dq_k4));

  // ======================== LEG DYNAMICS (8 joints) ========================
  der(q_h1) = dq_h1;
  der(q_k1) = dq_k1;
  I_hip*der(dq_h1) = tau_h1 - (jxh1*Ft1 + jzh1*Fn1) - D_joint*dq_h1;
  I_knee*der(dq_k1) = tau_k1 - (jxk1*Ft1 + jzk1*Fn1) - D_joint*dq_k1;

  der(q_h2) = dq_h2;
  der(q_k2) = dq_k2;
  I_hip*der(dq_h2) = tau_h2 - (jxh2*Ft2 + jzh2*Fn2) - D_joint*dq_h2;
  I_knee*der(dq_k2) = tau_k2 - (jxk2*Ft2 + jzk2*Fn2) - D_joint*dq_k2;

  der(q_h3) = dq_h3;
  der(q_k3) = dq_k3;
  I_hip*der(dq_h3) = tau_h3 - (jxh3*Ft3 + jzh3*Fn3) - D_joint*dq_h3;
  I_knee*der(dq_k3) = tau_k3 - (jxk3*Ft3 + jzk3*Fn3) - D_joint*dq_k3;

  der(q_h4) = dq_h4;
  der(q_k4) = dq_k4;
  I_hip*der(dq_h4) = tau_h4 - (jxh4*Ft4 + jzh4*Fn4) - D_joint*dq_h4;
  I_knee*der(dq_k4) = tau_k4 - (jxk4*Ft4 + jzk4*Fn4) - D_joint*dq_k4;

  // ======================== WHEEL DYNAMICS (4 wheels) ========================
  der(q_w1) = dq_w1;
  der(q_w2) = dq_w2;
  der(q_w3) = dq_w3;
  der(q_w4) = dq_w4;
  I_wheel*der(dq_w1) = tau_w1 - Ft1*r_wheel - D_wheel_d*dq_w1;
  I_wheel*der(dq_w2) = tau_w2 - Ft2*r_wheel - D_wheel_d*dq_w2;
  I_wheel*der(dq_w3) = tau_w3 - Ft3*r_wheel - D_wheel_d*dq_w3;
  I_wheel*der(dq_w4) = tau_w4 - Ft4*r_wheel - D_wheel_d*dq_w4;

  // ======================== SENSORS ========================
  next_edge = if x_t < stair_start then stair_start
    else if x_t >= stair_start + n_stairs*stair_tread then stair_start + n_stairs*stair_tread
    else stair_start + (floor((x_t - stair_start)/stair_tread) + 1.0)*stair_tread;
  depth_clearance = max(0.0, next_edge - x_t);
  imu_pitch = th_t;
  imu_pitch_rate = w_t;
  enc_h1 = q_h1; enc_h2 = q_h2; enc_h3 = q_h3; enc_h4 = q_h4;
  enc_k1 = q_k1; enc_k2 = q_k2; enc_k3 = q_k3; enc_k4 = q_k4;
  enc_w1 = q_w1; enc_w2 = q_w2; enc_w3 = q_w3; enc_w4 = q_w4;
  ff1 = sqrt(Fn1*Fn1 + Ft1*Ft1);
  ff2 = sqrt(Fn2*Fn2 + Ft2*Ft2);
  ff3 = sqrt(Fn3*Fn3 + Ft3*Ft3);
  ff4 = sqrt(Fn4*Fn4 + Ft4*Ft4);

  // ======================== METRICS ========================
  err_x1 = jxh1*(q_h1 - q_h1_des) + jxk1*(q_k1 - q_k1_des);
  err_z1 = jzh1*(q_h1 - q_h1_des) + jzk1*(q_k1 - q_k1_des);
  err_x3 = jxh3*(q_h3 - q_h3_des) + jxk3*(q_k3 - q_k3_des);
  err_z3 = jzh3*(q_h3 - q_h3_des) + jzk3*(q_k3 - q_k3_des);
  tracking_error = sqrt(err_x1*err_x1 + err_z1*err_z1 + err_x3*err_x3 + err_z3*err_z3) / 2.0;
  height_error = abs(terrain_t + h_ref - z_t);
  n_support = (if delta1 > 0.0 then 1.0 else 0.0)
            + (if delta2 > 0.0 then 1.0 else 0.0)
            + (if delta3 > 0.0 then 1.0 else 0.0)
            + (if delta4 > 0.0 then 1.0 else 0.0);
  completed = time >= T_sim and x_t >= stair_start + n_stairs*stair_tread - 0.05;

  annotation(
    Documentation(info="WheelLegClimbA: 28 kg floating-base torso with 4 two-joint legs ending in driven 0.10 m wheels. Climbs 4 stairs (0.16 m rise, 0.30 m tread) while maintaining body height via terrain-aware foothold planning and joint-space impedance at 80 Hz. All 12 torques independently limited to 39.6 N.m. Rigid stair collision with friction 0.88. 50 N payload disturbance during middle third. Sensors: depth camera (stair edge clearance), IMU (pitch, rate), encoders (8 joints + 4 wheels), foot-force sensors. State, command, and sensor traces are synchronized as continuous outputs."),
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-4, Interval=0.002)
  );
end WheelLegClimbA;