model HexaWalkRecoverC
  extends Modelica.Icons.Example;
  import Modelica.Constants.pi;

  // ---------- Stated requirement parameters ----------
  parameter Real m_body(unit="kg") = 15.0 "capsule body mass";
  parameter Real L_coxa(unit="m")  = 0.12 "coxa link length";
  parameter Real L_femur(unit="m") = 0.22 "femur link length";
  parameter Real L_tibia(unit="m")  = 0.26 "tibia link length";
  parameter Real mu_ground          = 0.90 "ground friction coefficient";
  parameter Real tau_max(unit="N.m")= 18.4 "max command magnitude per joint";
  parameter Real F_push(unit="N")  = 126.0 "lateral push disturbance magnitude";
  parameter Real Ts(unit="s")      = 1.0/125.0 "control / estimator update rate";

  // ---------- Assumed / unspecified-but-required values (labeled) ----------
  parameter Real r_hip(unit="m")    = 0.10 "hip mount radius (assumed; not stated)";
  parameter Real Ixx(unit="kg.m2") = 0.20 "body inertia (assumed; not stated)";
  parameter Real Iyy(unit="kg.m2") = 0.20 "body inertia (assumed; not stated)";
  parameter Real Izz(unit="kg.m2") = 0.30 "body inertia (assumed; not stated)";
  parameter Real Jq(unit="kg.m2")  = 0.10 "effective joint inertia (assumed; not stated)";
  parameter Real h_des(unit="m")   = 0.30 "nominal standing body height (assumed; not stated)";
  parameter Real k_c(unit="N/m")   = 2.0e4 "contact normal stiffness (assumed)";
  parameter Real d_c(unit="N.s/m") = 500.0 "contact normal damping (assumed)";
  parameter Real d_t(unit="N.s/m") = 800.0 "contact tangential damping (assumed)";
  parameter Real Kp_joint(unit="N.m/rad") = 110.0 "joint PD proportional gain (assumed)";
  parameter Real Kd_joint(unit="N.m.s/rad")= 4.0 "joint PD derivative gain (assumed)";
  parameter Real T_gait(unit="s")  = 2.0 "gait cycle period (assumed)";
  parameter Real q2_nom(unit="rad") = -1.0 "nominal femur angle (assumed)";
  parameter Real q3_nom(unit="rad") = 0.5 "nominal tibia angle (assumed)";
  parameter Real est_tau(unit="s") = 0.02 "estimator lag time constant (assumed)";
  parameter Real K_att_p(unit="1") = 0.6 "attitude feedback to joints (assumed)";
  parameter Real K_h(unit="rad/m") = 0.8 "height feedback to joints (assumed)";
  parameter Real K_yaw_p(unit="1") = 0.3 "yaw feedback to coxa (assumed)";
  parameter Real swing_lift(unit="rad")    = 0.5 "swing leg lift (assumed)";
  parameter Real swing_q1_amp(unit="rad") = 0.3 "swing coxa shuffle amplitude (assumed)";
  parameter Real kn                     = 5.0 "quaternion norm restoring gain (assumed)";
  parameter Real push_start(unit="s") = 5.90 "push pulse start (middle third of 12 s; assumed)";
  parameter Real push_stop(unit="s")  = 6.10 "push pulse stop (assumed)";

  parameter Real alpha[6] = {0, pi/3, 2*pi/3, pi, 4*pi/3, 5*pi/3} "leg mounting yaw angles";

  // ---------- Base states ----------
  Real x(unit="m"), y(unit="m"), z(unit="m");
  Real vx(unit="m/s"), vy(unit="m/s"), vz(unit="m/s");
  Real qw, qx, qy, qz "body orientation quaternion (world<-body)";
  Real wx(unit="rad/s"), wy(unit="rad/s"), wz(unit="rad/s") "body angular velocity (body frame)";

  // ---------- Joint states ----------
  Real q[6,3](each unit="rad") "joint angles [coxa,femur,tibia] per leg";
  Real qd[6,3](each unit="rad/s");

  // ---------- Actuator torques ----------
  Real tau_act[6,3](each unit="N.m") "saturated applied joint torques";

  // ---------- Estimator (IMU + kinematics + contact-qualified) ----------
  Real est_x(unit="m"), est_y(unit="m"), est_z(unit="m");
  Real est_qw, est_qx, est_qy, est_qz;
  Real est_vx(unit="m/s"), est_vy(unit="m/s"), est_vz(unit="m/s");
  Real est_roll(unit="rad"), est_pitch(unit="rad"), est_yaw(unit="rad");

  // ---------- Discrete controller variables ----------
  discrete Real q1_des[6](each unit="rad");
  discrete Real q2_des[6](each unit="rad");
  discrete Real q3_des[6](each unit="rad");
  discrete Real stance[6] "1 stance command, 0 swing";
  discrete Real phase_disp "gait phase trace";

  // ---------- Contact / sensor variables ----------
  Real foot_wx[6](each unit="m"), foot_wy[6](each unit="m"), foot_wz[6](each unit="m");
  Real foot_vwx[6](each unit="m/s"), foot_vwy[6](each unit="m/s"), foot_vwz[6](each unit="m/s");
  Real Fx[6](each unit="N"), Fy[6](each unit="N"), Fz[6](each unit="N");
  Real N[6](each unit="N") "normal force";
  Real contact_flag[6] "qualified stance contact (1/0)";
  Real slip_acc[6](each unit="m") "accumulated tangential slip";
  Real v_tan[6](each unit="m/s") "tangential foot speed";

  // ---------- Monitors ----------
  Real roll(unit="rad"), pitch(unit="rad"), yaw(unit="rad");
  Real primary_tracking_error(unit="rad");
  Real body_height(unit="m");
  Real max_slip(unit="m");
  Real push_active;
  Real Fdist_x(unit="N");

  // ---------- Intermediate variables ----------
  Real R11,R12,R13,R21,R22,R23,R31,R32,R33;
  Real qnorm2;
  Real a_leg[6], c1[6], s1[6], c2[6], s2[6], c23[6], s23[6], reach[6], hx[6], hy[6];
  Real fb_x[6], fb_y[6], fb_z[6];
  Real Jv1x[6],Jv1y[6],Jv1z[6];
  Real Jv2x[6],Jv2y[6],Jv2z[6];
  Real Jv3x[6],Jv3y[6],Jv3z[6];
  Real fbx_dot[6], fby_dot[6], fbz_dot[6];
  Real oxb[6], oyb[6], ozb[6];
  Real Fbx[6], Fby[6], Fbz[6];
  Real rwx[6], rwy[6], rwz[6];
  Real twx[6], twy[6], twz[6];
  Real tau_c[6,3](each unit="N.m");
  Real sumFx(unit="N"), sumFy(unit="N"), sumFz(unit="N");
  Real tauwx(unit="N.m"), tauwy(unit="N.m"), tauwz(unit="N.m");
  Real taubx(unit="N.m"), tauby(unit="N.m"), taubz(unit="N.m");

initial equation
  x = 0; y = 0; z = h_des;
  vx = 0; vy = 0; vz = 0;
  qw = 1; qx = 0; qy = 0; qz = 0;
  wx = 0; wy = 0; wz = 0;
  for i in 1:6 loop
    q[i,1] = 0.0;
    q[i,2] = q2_nom;
    q[i,3] = q3_nom;
    qd[i,1] = 0; qd[i,2] = 0; qd[i,3] = 0;
    slip_acc[i] = 0;
  end for;
  est_x = 0; est_y = 0; est_z = h_des;
  est_qw = 1; est_qx = 0; est_qy = 0; est_qz = 0;
  est_vx = 0; est_vy = 0; est_vz = 0;

equation
  // ---- Disturbance: brief 126 N lateral push within the middle third of 12 s ----
  if time >= push_start and time <= push_stop then
    Fdist_x = F_push;
    push_active = 1.0;
  else
    Fdist_x = 0.0;
    push_active = 0.0;
  end if;

  // ---- Rotation matrix (world <- body) ----
  R11 = 1 - 2*(qy*qy + qz*qz);
  R12 = 2*(qx*qy - qz*qw);
  R13 = 2*(qx*qz + qy*qw);
  R21 = 2*(qx*qy + qz*qw);
  R22 = 1 - 2*(qx*qx + qz*qz);
  R23 = 2*(qy*qz - qx*qw);
  R31 = 2*(qx*qz - qy*qw);
  R32 = 2*(qy*qz + qx*qw);
  R33 = 1 - 2*(qx*qx + qy*qy);
  qnorm2 = qw*qw + qx*qx + qy*qy + qz*qz;

  // ---- Attitude monitors ----
  roll  = atan2(2*(qw*qx + qy*qz), 1 - 2*(qx*qx + qy*qy));
  pitch = asin(max(-0.999, min(0.999, 2*(qw*qy - qz*qx))));
  yaw   = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));
  body_height = z;
  primary_tracking_error = sqrt(roll*roll + pitch*pitch);
  max_slip = max(slip_acc);

  // ---- Base translational dynamics ----
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  m_body*der(vx) = sumFx + Fdist_x;
  m_body*der(vy) = sumFy;
  m_body*der(vz) = sumFz - m_body*9.81;

  // ---- Base rotational dynamics (Euler equations, body frame) ----
  Ixx*der(wx) = (Iyy - Izz)*wy*wz + taubx;
  Iyy*der(wy) = (Izz - Ixx)*wz*wx + tauby;
  Izz*der(wz) = (Ixx - Iyy)*wx*wy + taubz;

  // ---- Quaternion kinematics with weak norm restoration ----
  der(qw) = 0.5*(-qx*wx - qy*wy - qz*wz) - kn*(qnorm2 - 1)*qw;
  der(qx) = 0.5*( qw*wx + qz*wy - qy*wz) - kn*(qnorm2 - 1)*qx;
  der(qy) = 0.5*( qw*wy - qz*wx + qx*wz) - kn*(qnorm2 - 1)*qy;
  der(qz) = 0.5*( qw*wz + qy*wx - qx*wy) - kn*(qnorm2 - 1)*qz;

  // ---- Estimator (first-order lag of IMU/kinematics states) ----
  der(est_x) = (x - est_x)/est_tau;
  der(est_y) = (y - est_y)/est_tau;
  der(est_z) = (z - est_z)/est_tau;
  der(est_qw) = (qw - est_qw)/est_tau;
  der(est_qx) = (qx - est_qx)/est_tau;
  der(est_qy) = (qy - est_qy)/est_tau;
  der(est_qz) = (qz - est_qz)/est_tau;
  der(est_vx) = (vx - est_vx)/est_tau;
  der(est_vy) = (vy - est_vy)/est_tau;
  der(est_vz) = (vz - est_vz)/est_tau;
  est_roll  = atan2(2*(est_qw*est_qx + est_qy*est_qz), 1 - 2*(est_qx*est_qx + est_qy*est_qy));
  est_pitch = asin(max(-0.999, min(0.999, 2*(est_qw*est_qy - est_qz*est_qx))));
  est_yaw   = atan2(2*(est_qw*est_qz + est_qx*est_qy), 1 - 2*(est_qy*est_qy + est_qz*est_qz));

  // ---- Joint dynamics ----
  for i in 1:6 loop
    for j in 1:3 loop
      der(q[i,j]) = qd[i,j];
      Jq*der(qd[i,j]) = tau_act[i,j] - tau_c[i,j];
    end for;
  end for;

  // ---- Saturated actuator torques (PD to discrete desired, zero desired vel) ----
  for i in 1:6 loop
    tau_act[i,1] = max(-tau_max, min(tau_max, Kp_joint*(q1_des[i] - q[i,1]) - Kd_joint*qd[i,1]));
    tau_act[i,2] = max(-tau_max, min(tau_max, Kp_joint*(q2_des[i] - q[i,2]) - Kd_joint*qd[i,2]));
    tau_act[i,3] = max(-tau_max, min(tau_max, Kp_joint*(q3_des[i] - q[i,3]) - Kd_joint*qd[i,3]));
  end for;

  // ---- Per-leg kinematics, Jacobians, foot world positions/velocities ----
  for i in 1:6 loop
    a_leg[i] = alpha[i] + q[i,1];
    c1[i]  = cos(a_leg[i]);
    s1[i]  = sin(a_leg[i]);
    c2[i]  = cos(q[i,2]);
    s2[i]  = sin(q[i,2]);
    c23[i] = cos(q[i,2] + q[i,3]);
    s23[i] = sin(q[i,2] + q[i,3]);
    reach[i] = L_coxa + L_femur*c2[i] + L_tibia*c23[i];
    hx[i] = r_hip*cos(alpha[i]);
    hy[i] = r_hip*sin(alpha[i]);
    fb_x[i] = hx[i] + c1[i]*reach[i];
    fb_y[i] = hy[i] + s1[i]*reach[i];
    fb_z[i] = L_femur*s2[i] + L_tibia*s23[i];
    // Jacobian columns (body frame)
    Jv1x[i] = -s1[i]*reach[i];
    Jv1y[i] =  c1[i]*reach[i];
    Jv1z[i] =  0.0;
    Jv2x[i] = -c1[i]*(L_femur*s2[i] + L_tibia*s23[i]);
    Jv2y[i] = -s1[i]*(L_femur*s2[i] + L_tibia*s23[i]);
    Jv2z[i] =  L_femur*c2[i] + L_tibia*c23[i];
    Jv3x[i] = -c1[i]*L_tibia*s23[i];
    Jv3y[i] = -s1[i]*L_tibia*s23[i];
    Jv3z[i] =  L_tibia*c23[i];
    // body-frame foot velocity from joints
    fbx_dot[i] = Jv1x[i]*qd[i,1] + Jv2x[i]*qd[i,2] + Jv3x[i]*qd[i,3];
    fby_dot[i] = Jv1y[i]*qd[i,1] + Jv2y[i]*qd[i,2] + Jv3y[i]*qd[i,3];
    fbz_dot[i] = Jv1z[i]*qd[i,1] + Jv2z[i]*qd[i,2] + Jv3z[i]*qd[i,3];
    // omega x fb (body frame)
    oxb[i] = wy*fb_z[i] - wz*fb_y[i];
    oyb[i] = wz*fb_x[i] - wx*fb_z[i];
    ozb[i] = wx*fb_y[i] - wy*fb_x[i];
    // world foot position
    foot_wx[i] = x + R11*fb_x[i] + R12*fb_y[i] + R13*fb_z[i];
    foot_wy[i] = y + R21*fb_x[i] + R22*fb_y[i] + R23*fb_z[i];
    foot_wz[i] = z + R31*fb_x[i] + R32*fb_y[i] + R33*fb_z[i];
    // world foot velocity
    foot_vwx[i] = vx + R11*(oxb[i] + fbx_dot[i]) + R12*(oyb[i] + fby_dot[i]) + R13*(ozb[i] + fbz_dot[i]);
    foot_vwy[i] = vy + R21*(oxb[i] + fbx_dot[i]) + R22*(oyb[i] + fby_dot[i]) + R23*(ozb[i] + fbz_dot[i]);
    foot_vwz[i] = vz + R31*(oxb[i] + fbx_dot[i]) + R32*(oyb[i] + fby_dot[i]) + R33*(ozb[i] + fbz_dot[i]);
  end for;

  // ---- Contact forces (compliant normal, capped viscous friction) ----
  for i in 1:6 loop
    N[i] = if foot_wz[i] < 0.0 then max(0.0, k_c*(-foot_wz[i]) - d_c*foot_vwz[i]) else 0.0;
    contact_flag[i] = if (foot_wz[i] < 0.005) and (N[i] > 1.0) then 1.0 else 0.0;
    v_tan[i] = sqrt(foot_vwx[i]*foot_vwx[i] + foot_vwy[i]*foot_vwy[i]) + 1e-9;
    Fx[i] = -min(mu_ground*N[i], d_t*v_tan[i]) * foot_vwx[i]/v_tan[i];
    Fy[i] = -min(mu_ground*N[i], d_t*v_tan[i]) * foot_vwy[i]/v_tan[i];
    Fz[i] = N[i];
    der(slip_acc[i]) = if contact_flag[i] > 0.5 then sqrt(foot_vwx[i]*foot_vwx[i] + foot_vwy[i]*foot_vwy[i]) else 0.0;
  end for;

  // ---- Body-frame foot force and joint contact torque (J^T Fb) ----
  for i in 1:6 loop
    Fbx[i] = R11*Fx[i] + R21*Fy[i] + R31*Fz[i];
    Fby[i] = R12*Fx[i] + R22*Fy[i] + R32*Fz[i];
    Fbz[i] = R13*Fx[i] + R23*Fy[i] + R33*Fz[i];
    tau_c[i,1] = Jv1x[i]*Fbx[i] + Jv1y[i]*Fby[i] + Jv1z[i]*Fbz[i];
    tau_c[i,2] = Jv2x[i]*Fbx[i] + Jv2y[i]*Fby[i] + Jv2z[i]*Fbz[i];
    tau_c[i,3] = Jv3x[i]*Fbx[i] + Jv3y[i]*Fby[i] + Jv3z[i]*Fbz[i];
  end for;

  // ---- Net force/torque on base ----
  sumFx = Fx[1]+Fx[2]+Fx[3]+Fx[4]+Fx[5]+Fx[6];
  sumFy = Fy[1]+Fy[2]+Fy[3]+Fy[4]+Fy[5]+Fy[6];
  sumFz = Fz[1]+Fz[2]+Fz[3]+Fz[4]+Fz[5]+Fz[6];
  for i in 1:6 loop
    rwx[i] = foot_wx[i] - x;
    rwy[i] = foot_wy[i] - y;
    rwz[i] = foot_wz[i] - z;
    twx[i] = rwy[i]*Fz[i] - rwz[i]*Fy[i];
    twy[i] = rwz[i]*Fx[i] - rwx[i]*Fz[i];
    twz[i] = rwx[i]*Fy[i] - rwy[i]*Fx[i];
  end for;
  tauwx = twx[1]+twx[2]+twx[3]+twx[4]+twx[5]+twx[6];
  tauwy = twy[1]+twy[2]+twy[3]+twy[4]+twy[5]+twy[6];
  tauwz = twz[1]+twz[2]+twz[3]+twz[4]+twz[5]+twz[6];
  taubx = R11*tauwx + R21*tauwy + R31*tauwz;
  tauby = R12*tauwx + R22*tauwy + R32*tauwz;
  taubz = R13*tauwx + R23*tauwy + R33*tauwz;

algorithm
  // ---- Discrete controller at 125 Hz: tripod gait with balance correction ----
  when sample(0, Ts) then
    phase_disp := mod(time, T_gait)/T_gait;
    for i in 1:6 loop
      // Tripod gait: odd legs stance in first half, even in second half
      if phase_disp < 0.5 then
        stance[i] := if mod(i,2) == 1 then 1.0 else 0.0;
      else
        stance[i] := if mod(i,2) == 0 then 1.0 else 0.0;
      end if;

      // Balance corrections from estimator
      q1_des[i] := K_yaw_p * (-est_yaw) / 6.0;
      q2_des[i] := q2_nom + K_att_p * est_roll * cos(alpha[i])
                          + K_h * (h_des - est_z);
      q3_des[i] := q3_nom + K_att_p * est_pitch * sin(alpha[i]);

      // Swing leg lift
      if stance[i] < 0.5 then
        q1_des[i] := q1_des[i] + swing_q1_amp * sin(2*pi*phase_disp);
        q2_des[i] := q2_des[i] - swing_lift;
        q3_des[i] := q3_des[i] + swing_lift;
      end if;
    end for;
  end when;

  annotation (experiment(StopTime=12.0, Tolerance=1e-4));
end HexaWalkRecoverC;