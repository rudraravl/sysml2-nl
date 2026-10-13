model WheelLegWalkA
  // ===== Physical parameters =====
  parameter Real m_body(unit="kg") = 28.0 "torso mass";
  parameter Real I_body(unit="kg.m2") = 1.6 "torso pitch inertia";
  parameter Real g(unit="m/s2") = 9.81 "gravity";
  parameter Real mu = 0.85 "ground friction coefficient";
  parameter Real L_thigh(unit="m") = 0.25 "thigh length";
  parameter Real L_shank(unit="m") = 0.25 "shank length";
  parameter Real r_wheel(unit="m") = 0.10 "driven wheel radius";
  parameter Real I_joint(unit="kg.m2") = 0.05 "reflected joint inertia";
  parameter Real b_joint(unit="N.m.s/rad") = 0.30 "joint viscous friction";
  parameter Real k_gr(unit="N/m") = 20000.0 "rigid-plane vertical stiffness";
  parameter Real d_gr(unit="N.s/m") = 400.0 "rigid-plane vertical damping";

  // ===== Gait / control parameters =====
  parameter Real z_ref(unit="m") = 0.45 "nominal body height";
  parameter Real vx_ref(unit="m/s") = 0.40 "forward gait speed";
  parameter Real tau_max(unit="N.m") = 39.6 "per-joint command magnitude limit";
  parameter Real F_push(unit="N") = 35.0 "body push disturbance";
  parameter Real T_gait(unit="s") = 1.20 "gait period";
  parameter Real A_gait(unit="rad") = 0.12 "hip gait amplitude";
  parameter Real B_gait(unit="rad") = -0.18 "knee gait amplitude";
  parameter Real q1_nom(unit="rad") = 0.50 "nominal hip angle";
  parameter Real q2_nom(unit="rad") = -0.90 "nominal knee angle";
  parameter Real k_imp(unit="N.m/rad") = 80.0 "joint impedance stiffness";
  parameter Real d_imp(unit="N.m.s/rad") = 2.0 "joint impedance damping";
  parameter Real k_vert(unit="N/m") = 1200.0 "body-height stiffness";
  parameter Real d_vert(unit="N.s/m") = 80.0 "body-height damping";
  parameter Real k_att(unit="N.m/rad") = 300.0 "body-attitude stiffness";
  parameter Real d_att(unit="N.m.s/rad") = 25.0 "body-attitude damping";
  parameter Real K_w(unit="N.s/m") = 100.0 "wheel tractive gain on speed error";
  parameter Real F_contact_thresh(unit="N") = 2.0 "contact detection threshold";
  
  parameter Real hip_x1(unit="m") = -0.22 "hip 1 x offset";
  parameter Real hip_x2(unit="m") = -0.07 "hip 2 x offset";
  parameter Real hip_x3(unit="m") = 0.07 "hip 3 x offset";
  parameter Real hip_x4(unit="m") = 0.22 "hip 4 x offset";
  
  parameter Real phase_off1(unit="rad") = 0.0 "leg 1 phase offset";
  parameter Real phase_off2(unit="rad") = 1.5708 "leg 2 phase offset";
  parameter Real phase_off3(unit="rad") = 3.1416 "leg 3 phase offset";
  parameter Real phase_off4(unit="rad") = 4.7124 "leg 4 phase offset";

  // ===== Floating-base states =====
  Real x(unit="m", start=0.0, fixed=true) "forward position";
  Real vx(unit="m/s", start=0.0, fixed=true) "forward velocity";
  Real z(unit="m", start=z_ref, fixed=true) "body height";
  Real vz(unit="m/s", start=0.0, fixed=true) "vertical velocity";
  Real theta(unit="rad", start=0.0, fixed=true) "pitch";
  Real omega(unit="rad/s", start=0.0, fixed=true) "pitch rate";

  // ===== Leg 1 states and vars =====
  Real q1_1(unit="rad", start=q1_nom, fixed=true);
  Real q2_1(unit="rad", start=q2_nom, fixed=true);
  Real dq1_1(unit="rad/s", start=0.0, fixed=true);
  Real dq2_1(unit="rad/s", start=0.0, fixed=true);
  Real ph_w1(unit="rad", start=0.0, fixed=true);
  Real dw1(unit="rad/s");
  Real foot_x1(unit="m");
  Real foot_z1(unit="m");
  Real vz_foot1(unit="m/s");
  Real Fz_leg1(unit="N");
  Real Fx_leg1(unit="N");
  Real F_contact1(unit="N");
  Integer cflag1;
  Real phase1(unit="rad");
  Real q1_ref1(unit="rad");
  Real q2_ref1(unit="rad");
  Real Fz_target1(unit="N");
  Real Jz1_1;
  Real Jz2_1;
  Real tau1_cmd1(unit="N.m");
  Real tau2_cmd1(unit="N.m");
  Real tau1_1(unit="N.m");
  Real tau2_1(unit="N.m");
  Real tau_wheel_cmd1(unit="N.m");
  Real tau_wheel1(unit="N.m");
  Real enc1_1(unit="rad");
  Real enc2_1(unit="rad");
  Real encw1(unit="rad");

  // ===== Leg 2 states and vars =====
  Real q1_2(unit="rad", start=q1_nom, fixed=true);
  Real q2_2(unit="rad", start=q2_nom, fixed=true);
  Real dq1_2(unit="rad/s", start=0.0, fixed=true);
  Real dq2_2(unit="rad/s", start=0.0, fixed=true);
  Real ph_w2(unit="rad", start=0.0, fixed=true);
  Real dw2(unit="rad/s");
  Real foot_x2(unit="m");
  Real foot_z2(unit="m");
  Real vz_foot2(unit="m/s");
  Real Fz_leg2(unit="N");
  Real Fx_leg2(unit="N");
  Real F_contact2(unit="N");
  Integer cflag2;
  Real phase2(unit="rad");
  Real q1_ref2(unit="rad");
  Real q2_ref2(unit="rad");
  Real Fz_target2(unit="N");
  Real Jz1_2;
  Real Jz2_2;
  Real tau1_cmd2(unit="N.m");
  Real tau2_cmd2(unit="N.m");
  Real tau1_2(unit="N.m");
  Real tau2_2(unit="N.m");
  Real tau_wheel_cmd2(unit="N.m");
  Real tau_wheel2(unit="N.m");
  Real enc1_2(unit="rad");
  Real enc2_2(unit="rad");
  Real encw2(unit="rad");

  // ===== Leg 3 states and vars =====
  Real q1_3(unit="rad", start=q1_nom, fixed=true);
  Real q2_3(unit="rad", start=q2_nom, fixed=true);
  Real dq1_3(unit="rad/s", start=0.0, fixed=true);
  Real dq2_3(unit="rad/s", start=0.0, fixed=true);
  Real ph_w3(unit="rad", start=0.0, fixed=true);
  Real dw3(unit="rad/s");
  Real foot_x3(unit="m");
  Real foot_z3(unit="m");
  Real vz_foot3(unit="m/s");
  Real Fz_leg3(unit="N");
  Real Fx_leg3(unit="N");
  Real F_contact3(unit="N");
  Integer cflag3;
  Real phase3(unit="rad");
  Real q1_ref3(unit="rad");
  Real q2_ref3(unit="rad");
  Real Fz_target3(unit="N");
  Real Jz1_3;
  Real Jz2_3;
  Real tau1_cmd3(unit="N.m");
  Real tau2_cmd3(unit="N.m");
  Real tau1_3(unit="N.m");
  Real tau2_3(unit="N.m");
  Real tau_wheel_cmd3(unit="N.m");
  Real tau_wheel3(unit="N.m");
  Real enc1_3(unit="rad");
  Real enc2_3(unit="rad");
  Real encw3(unit="rad");

  // ===== Leg 4 states and vars =====
  Real q1_4(unit="rad", start=q1_nom, fixed=true);
  Real q2_4(unit="rad", start=q2_nom, fixed=true);
  Real dq1_4(unit="rad/s", start=0.0, fixed=true);
  Real dq2_4(unit="rad/s", start=0.0, fixed=true);
  Real ph_w4(unit="rad", start=0.0, fixed=true);
  Real dw4(unit="rad/s");
  Real foot_x4(unit="m");
  Real foot_z4(unit="m");
  Real vz_foot4(unit="m/s");
  Real Fz_leg4(unit="N");
  Real Fx_leg4(unit="N");
  Real F_contact4(unit="N");
  Integer cflag4;
  Real phase4(unit="rad");
  Real q1_ref4(unit="rad");
  Real q2_ref4(unit="rad");
  Real Fz_target4(unit="N");
  Real Jz1_4;
  Real Jz2_4;
  Real tau1_cmd4(unit="N.m");
  Real tau2_cmd4(unit="N.m");
  Real tau1_4(unit="N.m");
  Real tau2_4(unit="N.m");
  Real tau_wheel_cmd4(unit="N.m");
  Real tau_wheel4(unit="N.m");
  Real enc1_4(unit="rad");
  Real enc2_4(unit="rad");
  Real encw4(unit="rad");

  // ===== Aggregates and sensors =====
  Real tau_leg1(unit="N.m");
  Real tau_leg2(unit="N.m");
  Real tau_leg3(unit="N.m");
  Real tau_leg4(unit="N.m");
  Real tau_leg5(unit="N.m");
  Real tau_leg6(unit="N.m");
  Real tau_leg7(unit="N.m");
  Real tau_leg8(unit="N.m");
  
  Real push_force(unit="N");
  Real height_err(unit="m");
  Real pitch_err(unit="rad");
  Real tracking_error(unit="m/s");
  Boolean valid;
  Real sum_Fz(unit="N");
  Real sum_Fx(unit="N");
  Real sum_Mpitch(unit="N.m");
  Real N_contact;
  Real IMU_pitch(unit="rad");
  Real IMU_pitch_rate(unit="rad/s");

equation
  // ---- Floating-base kinematics ----
  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;

  // ---- Leg 1 ----
  foot_x1 = x + hip_x1 + L_thigh*sin(q1_1) + L_shank*sin(q1_1 + q2_1);
  foot_z1 = z - L_thigh*cos(q1_1) - L_shank*cos(q1_1 + q2_1);
  vz_foot1 = vz + L_thigh*sin(q1_1)*dq1_1 + L_shank*sin(q1_1+q2_1)*(dq1_1+dq2_1);
  Fz_leg1 = if foot_z1 < 0.0 then (k_gr*(-foot_z1) + d_gr*(-vz_foot1)) else 0.0;
  phase1 = 2.0*Modelica.Constants.pi/T_gait*time + phase_off1;
  q1_ref1 = q1_nom + A_gait*sin(phase1);
  q2_ref1 = q2_nom + B_gait*sin(phase1);
  Jz1_1 = L_thigh*sin(q1_1) + L_shank*sin(q1_1+q2_1);
  Jz2_1 = L_shank*sin(q1_1+q2_1);
  Fz_target1 = (m_body*g)/4.0 + k_vert*(z_ref - z)/4.0 + d_vert*(-vz)/4.0 + k_att*theta*hip_x1 + d_att*omega*hip_x1;
  tau1_cmd1 = Fz_target1*Jz1_1 + k_imp*(q1_ref1 - q1_1) + d_imp*(-dq1_1);
  tau2_cmd1 = Fz_target1*Jz2_1 + k_imp*(q2_ref1 - q2_1) + d_imp*(-dq2_1);
  tau1_1 = if tau1_cmd1 > tau_max then tau_max else if tau1_cmd1 < -tau_max then -tau_max else tau1_cmd1;
  tau2_1 = if tau2_cmd1 > tau_max then tau_max else if tau2_cmd1 < -tau_max then -tau_max else tau2_cmd1;
  tau_wheel_cmd1 = K_w*(vx_ref - vx)*r_wheel;
  tau_wheel1 = if tau_wheel_cmd1 > tau_max then tau_max else if tau_wheel_cmd1 < -tau_max then -tau_max else tau_wheel_cmd1;
  Fx_leg1 = if foot_z1 < 0.0 then (if tau_wheel1/r_wheel > mu*Fz_leg1 then mu*Fz_leg1 else if tau_wheel1/r_wheel < -mu*Fz_leg1 then -mu*Fz_leg1 else tau_wheel1/r_wheel) else 0.0;
  F_contact1 = Fz_leg1;
  cflag1 = if Fz_leg1 > F_contact_thresh then 1 else 0;
  der(q1_1) = dq1_1;
  der(q2_1) = dq2_1;
  I_joint*der(dq1_1) = tau1_1 - b_joint*dq1_1;
  I_joint*der(dq2_1) = tau2_1 - b_joint*dq2_1;
  dw1 = vx / r_wheel;
  der(ph_w1) = dw1;
  enc1_1 = q1_1;
  enc2_1 = q2_1;
  encw1 = ph_w1;

  // ---- Leg 2 ----
  foot_x2 = x + hip_x2 + L_thigh*sin(q1_2) + L_shank*sin(q1_2 + q2_2);
  foot_z2 = z - L_thigh*cos(q1_2) - L_shank*cos(q1_2 + q2_2);
  vz_foot2 = vz + L_thigh*sin(q1_2)*dq1_2 + L_shank*sin(q1_2+q2_2)*(dq1_2+dq2_2);
  Fz_leg2 = if foot_z2 < 0.0 then (k_gr*(-foot_z2) + d_gr*(-vz_foot2)) else 0.0;
  phase2 = 2.0*Modelica.Constants.pi/T_gait*time + phase_off2;
  q1_ref2 = q1_nom + A_gait*sin(phase2);
  q2_ref2 = q2_nom + B_gait*sin(phase2);
  Jz1_2 = L_thigh*sin(q1_2) + L_shank*sin(q1_2+q2_2);
  Jz2_2 = L_shank*sin(q1_2+q2_2);
  Fz_target2 = (m_body*g)/4.0 + k_vert*(z_ref - z)/4.0 + d_vert*(-vz)/4.0 + k_att*theta*hip_x2 + d_att*omega*hip_x2;
  tau1_cmd2 = Fz_target2*Jz1_2 + k_imp*(q1_ref2 - q1_2) + d_imp*(-dq1_2);
  tau2_cmd2 = Fz_target2*Jz2_2 + k_imp*(q2_ref2 - q2_2) + d_imp*(-dq2_2);
  tau1_2 = if tau1_cmd2 > tau_max then tau_max else if tau1_cmd2 < -tau_max then -tau_max else tau1_cmd2;
  tau2_2 = if tau2_cmd2 > tau_max then tau_max else if tau2_cmd2 < -tau_max then -tau_max else tau2_cmd2;
  tau_wheel_cmd2 = K_w*(vx_ref - vx)*r_wheel;
  tau_wheel2 = if tau_wheel_cmd2 > tau_max then tau_max else if tau_wheel_cmd2 < -tau_max then -tau_max else tau_wheel_cmd2;
  Fx_leg2 = if foot_z2 < 0.0 then (if tau_wheel2/r_wheel > mu*Fz_leg2 then mu*Fz_leg2 else if tau_wheel2/r_wheel < -mu*Fz_leg2 then -mu*Fz_leg2 else tau_wheel2/r_wheel) else 0.0;
  F_contact2 = Fz_leg2;
  cflag2 = if Fz_leg2 > F_contact_thresh then 1 else 0;
  der(q1_2) = dq1_2;
  der(q2_2) = dq2_2;
  I_joint*der(dq1_2) = tau1_2 - b_joint*dq1_2;
  I_joint*der(dq2_2) = tau2_2 - b_joint*dq2_2;
  dw2 = vx / r_wheel;
  der(ph_w2) = dw2;
  enc1_2 = q1_2;
  enc2_2 = q2_2;
  encw2 = ph_w2;

  // ---- Leg 3 ----
  foot_x3 = x + hip_x3 + L_thigh*sin(q1_3) + L_shank*sin(q1_3 + q2_3);
  foot_z3 = z - L_thigh*cos(q1_3) - L_shank*cos(q1_3 + q2_3);
  vz_foot3 = vz + L_thigh*sin(q1_3)*dq1_3 + L_shank*sin(q1_3+q2_3)*(dq1_3+dq2_3);
  Fz_leg3 = if foot_z3 < 0.0 then (k_gr*(-foot_z3) + d_gr*(-vz_foot3)) else 0.0;
  phase3 = 2.0*Modelica.Constants.pi/T_gait*time + phase_off3;
  q1_ref3 = q1_nom + A_gait*sin(phase3);
  q2_ref3 = q2_nom + B_gait*sin(phase3);
  Jz1_3 = L_thigh*sin(q1_3) + L_shank*sin(q1_3+q2_3);
  Jz2_3 = L_shank*sin(q1_3+q2_3);
  Fz_target3 = (m_body*g)/4.0 + k_vert*(z_ref - z)/4.0 + d_vert*(-vz)/4.0 + k_att*theta*hip_x3 + d_att*omega*hip_x3;
  tau1_cmd3 = Fz_target3*Jz1_3 + k_imp*(q1_ref3 - q1_3) + d_imp*(-dq1_3);
  tau2_cmd3 = Fz_target3*Jz2_3 + k_imp*(q2_ref3 - q2_3) + d_imp*(-dq2_3);
  tau1_3 = if tau1_cmd3 > tau_max then tau_max else if tau1_cmd3 < -tau_max then -tau_max else tau1_cmd3;
  tau2_3 = if tau2_cmd3 > tau_max then tau_max else if tau2_cmd3 < -tau_max then -tau_max else tau2_cmd3;
  tau_wheel_cmd3 = K_w*(vx_ref - vx)*r_wheel;
  tau_wheel3 = if tau_wheel_cmd3 > tau_max then tau_max else if tau_wheel_cmd3 < -tau_max then -tau_max else tau_wheel_cmd3;
  Fx_leg3 = if foot_z3 < 0.0 then (if tau_wheel3/r_wheel > mu*Fz_leg3 then mu*Fz_leg3 else if tau_wheel3/r_wheel < -mu*Fz_leg3 then -mu*Fz_leg3 else tau_wheel3/r_wheel) else 0.0;
  F_contact3 = Fz_leg3;
  cflag3 = if Fz_leg3 > F_contact_thresh then 1 else 0;
  der(q1_3) = dq1_3;
  der(q2_3) = dq2_3;
  I_joint*der(dq1_3) = tau1_3 - b_joint*dq1_3;
  I_joint*der(dq2_3) = tau2_3 - b_joint*dq2_3;
  dw3 = vx / r_wheel;
  der(ph_w3) = dw3;
  enc1_3 = q1_3;
  enc2_3 = q2_3;
  encw3 = ph_w3;

  // ---- Leg 4 ----
  foot_x4 = x + hip_x4 + L_thigh*sin(q1_4) + L_shank*sin(q1_4 + q2_4);
  foot_z4 = z - L_thigh*cos(q1_4) - L_shank*cos(q1_4 + q2_4);
  vz_foot4 = vz + L_thigh*sin(q1_4)*dq1_4 + L_shank*sin(q1_4+q2_4)*(dq1_4+dq2_4);
  Fz_leg4 = if foot_z4 < 0.0 then (k_gr*(-foot_z4) + d_gr*(-vz_foot4)) else 0.0;
  phase4 = 2.0*Modelica.Constants.pi/T_gait*time + phase_off4;
  q1_ref4 = q1_nom + A_gait*sin(phase4);
  q2_ref4 = q2_nom + B_gait*sin(phase4);
  Jz1_4 = L_thigh*sin(q1_4) + L_shank*sin(q1_4+q2_4);
  Jz2_4 = L_shank*sin(q1_4+q2_4);
  Fz_target4 = (m_body*g)/4.0 + k_vert*(z_ref - z)/4.0 + d_vert*(-vz)/4.0 + k_att*theta*hip_x4 + d_att*omega*hip_x4;
  tau1_cmd4 = Fz_target4*Jz1_4 + k_imp*(q1_ref4 - q1_4) + d_imp*(-dq1_4);
  tau2_cmd4 = Fz_target4*Jz2_4 + k_imp*(q2_ref4 - q2_4) + d_imp*(-dq2_4);
  tau1_4 = if tau1_cmd4 > tau_max then tau_max else if tau1_cmd4 < -tau_max then -tau_max else tau1_cmd4;
  tau2_4 = if tau2_cmd4 > tau_max then tau_max else if tau2_cmd4 < -tau_max then -tau_max else tau2_cmd4;
  tau_wheel_cmd4 = K_w*(vx_ref - vx)*r_wheel;
  tau_wheel4 = if tau_wheel_cmd4 > tau_max then tau_max else if tau_wheel_cmd4 < -tau_max then -tau_max else tau_wheel_cmd4;
  Fx_leg4 = if foot_z4 < 0.0 then (if tau_wheel4/r_wheel > mu*Fz_leg4 then mu*Fz_leg4 else if tau_wheel4/r_wheel < -mu*Fz_leg4 then -mu*Fz_leg4 else tau_wheel4/r_wheel) else 0.0;
  F_contact4 = Fz_leg4;
  cflag4 = if Fz_leg4 > F_contact_thresh then 1 else 0;
  der(q1_4) = dq1_4;
  der(q2_4) = dq2_4;
  I_joint*der(dq1_4) = tau1_4 - b_joint*dq1_4;
  I_joint*der(dq2_4) = tau2_4 - b_joint*dq2_4;
  dw4 = vx / r_wheel;
  der(ph_w4) = dw4;
  enc1_4 = q1_4;
  enc2_4 = q2_4;
  encw4 = ph_w4;

  // ---- Aggregates ----
  tau_leg1 = tau1_1;
  tau_leg2 = tau2_1;
  tau_leg3 = tau1_2;
  tau_leg4 = tau2_2;
  tau_leg5 = tau1_3;
  tau_leg6 = tau2_3;
  tau_leg7 = tau1_4;
  tau_leg8 = tau2_4;

  sum_Fz = Fz_leg1 + Fz_leg2 + Fz_leg3 + Fz_leg4;
  sum_Fx = Fx_leg1 + Fx_leg2 + Fx_leg3 + Fx_leg4;
  sum_Mpitch = -(hip_x1*Fz_leg1 + hip_x2*Fz_leg2 + hip_x3*Fz_leg3 + hip_x4*Fz_leg4) - z*(Fx_leg1 + Fx_leg2 + Fx_leg3 + Fx_leg4);

  der(vx) = (sum_Fx + push_force) / m_body;
  der(vz) = (sum_Fz - m_body*g) / m_body;
  der(omega) = sum_Mpitch / I_body;

  push_force = if time > 8.0/3.0 and time < 16.0/3.0 then F_push else 0.0;

  IMU_pitch = theta;
  IMU_pitch_rate = omega;

  N_contact = Real(cflag1 + cflag2 + cflag3 + cflag4);

  height_err = z_ref - z;
  pitch_err = -theta;
  tracking_error = abs(vx - vx_ref);

  valid = (abs(x) < 1.0e4) and (abs(vx) < 1.0e3) and (abs(z) < 1.0e2) and (abs(vz) < 1.0e3)
          and (abs(theta) < 10.0) and (abs(omega) < 1.0e3)
          and (abs(sum_Fz) < 1.0e5) and (abs(sum_Fx) < 1.0e5)
          and (abs(tau1_1) <= tau_max) and (abs(tau2_1) <= tau_max)
          and (abs(tau1_2) <= tau_max) and (abs(tau2_2) <= tau_max)
          and (abs(tau1_3) <= tau_max) and (abs(tau2_3) <= tau_max)
          and (abs(tau1_4) <= tau_max) and (abs(tau2_4) <= tau_max)
          and (abs(tau_wheel1) <= tau_max) and (abs(tau_wheel2) <= tau_max)
          and (abs(tau_wheel3) <= tau_max) and (abs(tau_wheel4) <= tau_max);

  assert(abs(tau1_1) <= tau_max + 1e-6, "hip1 torque bound violated");
  assert(abs(tau2_1) <= tau_max + 1e-6, "knee1 torque bound violated");
  assert(abs(tau1_2) <= tau_max + 1e-6, "hip2 torque bound violated");
  assert(abs(tau2_2) <= tau_max + 1e-6, "knee2 torque bound violated");
  assert(abs(tau1_3) <= tau_max + 1e-6, "hip3 torque bound violated");
  assert(abs(tau2_3) <= tau_max + 1e-6, "knee3 torque bound violated");
  assert(abs(tau1_4) <= tau_max + 1e-6, "hip4 torque bound violated");
  assert(abs(tau2_4) <= tau_max + 1e-6, "knee4 torque bound violated");
  assert(abs(tau_wheel1) <= tau_max + 1e-6, "wheel1 torque bound violated");
  assert(abs(tau_wheel2) <= tau_max + 1e-6, "wheel2 torque bound violated");
  assert(abs(tau_wheel3) <= tau_max + 1e-6, "wheel3 torque bound violated");
  assert(abs(tau_wheel4) <= tau_max + 1e-6, "wheel4 torque bound violated");
  assert(valid, "physical, control, or estimator values out of finite range");
  assert(time <= 5.2 or tracking_error < 0.135, "Primary tracking error exceeded after 5.2s");

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-5, Interval=0.0125),
    Documentation(info="WheelLegWalkA: floating-base 28 kg wheeled-leg quadruped. "
      "Four 2-joint legs ending in 0.10 m driven wheels; phase-based joint impedance and "
      "body-attitude control; 35 N body push during middle third (2.667-5.333 s); "
      "80 Hz output for 8 s; friction 0.85, gravity 9.81 m/s2. "
      "Tracks 0.4 m/s forward gait at nominal height. "
      "Synchronized state/command/sensor traces retained."));
end WheelLegWalkA;