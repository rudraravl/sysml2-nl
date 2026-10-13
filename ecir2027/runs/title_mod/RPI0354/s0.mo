model DeltaPositionF
  "Delta parallel robot: position control with bounded load disturbance"

  // === Geometry ===
  parameter Real L1 = 0.32 "Upper arm length [m]";
  parameter Real L2 = 0.60 "Forearm length [m]";
  parameter Real Rb = 0.12 "Base circle radius [m]";
  parameter Real Rp = 0.04 "Platform circle radius [m]";
  parameter Real mp = 3.0 "Moving platform mass [kg]";
  parameter Real Ja = 0.01 "Actuator rotor inertia [kg.m2]";
  parameter Real b_vis = 0.05 "Actuator viscous damping [N.m.s/rad]";
  parameter Real Tmax = 54.9 "Maximum actuator torque [N.m]";
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s2]";

  // === Trig constants for 120-degree-spaced base joints ===
  parameter Real c1 = 1.0 "cos(theta1)";
  parameter Real s1 = 0.0 "sin(theta1)";
  parameter Real c2 = -0.5 "cos(theta2)";
  parameter Real s2 = 0.8660254037844386 "sin(theta2)";
  parameter Real c3 = -0.5 "cos(theta3)";
  parameter Real s3 = -0.8660254037844386 "sin(theta3)";

  // === Target pose ===
  parameter Real px_ref = 0.0 "Target platform x [m]";
  parameter Real py_ref = 0.0 "Target platform y [m]";
  parameter Real pz_ref = -0.50 "Target platform z [m]";

  // === Initial configuration ===
  parameter Real q_init = 0.80 "Initial actuator angle [rad]";
  parameter Real pz_init = -0.7475 "Initial platform z position [m]";

  // === Control ===
  parameter Real Kp = 600.0 "Joint PD proportional gain [N.m/rad]";
  parameter Real Kd = 15.0 "Joint PD derivative gain [N.m.s/rad]";
  parameter Real t_ramp = 4.0 "Trajectory ramp duration [s]";

  // === Disturbance ===
  parameter Real Fload = 20.3 "Platform load disturbance [N]";
  parameter Real t_load_on = 6.667 "Load activation time [s]";
  parameter Real t_load_off = 13.333 "Load deactivation time [s]";

  // === Timing ===
  parameter Real Ts = 0.002 "Controller sample period [s] (500 Hz)";
  parameter Real t_end = 20.0 "Simulation duration [s]";

  // === Internal constant ===
  constant Real pi_c = 3.1415926535897932;

  // === State variables ===
  Real q1(start = q_init, fixed = true) "Actuator 1 angle [rad]";
  Real q2(start = q_init, fixed = true) "Actuator 2 angle [rad]";
  Real q3(start = q_init, fixed = true) "Actuator 3 angle [rad]";
  Real dq1(start = 0.0, fixed = true) "Actuator 1 angular velocity [rad/s]";
  Real dq2(start = 0.0, fixed = true) "Actuator 2 angular velocity [rad/s]";
  Real dq3(start = 0.0, fixed = true) "Actuator 3 angular velocity [rad/s]";

  // === Platform position ===
  Real px "Platform x [m]";
  Real py "Platform y [m]";
  Real pz "Platform z [m]";

  // === Forward kinematics intermediates ===
  Real K1, K2, K3;
  Real Ax1, Ay1, Az1, Ax2, Ay2, Az2, Ax3, Ay3, Az3;
  Real a11, a12, a13, a21, a22, a23, rb1, rb2;
  Real det_lin, det_lin_s;
  Real px0, px_pz, py0, py_pz;
  Real alpha_q, beta_q, gamma_q, delta_q, epsilon_q;
  Real A_quad, B_quad, C_quad, disc_q;

  // === Forearm vectors ===
  Real ux1, uy1, uz1, ux2, uy2, uz2, ux3, uy3, uz3;
  Real Lf1, Lf2, Lf3;

  // === Jacobian ===
  Real dg1, dg2, dg3;
  Real det_M, det_M_s;
  Real J31, J32, J33;

  // === Trajectory ===
  Real ramp;
  Real px_d, py_d, pz_d;

  // === Inverse kinematics ===
  Real ex1_ik, ey1_ik, ex2_ik, ey2_ik, ex3_ik, ey3_ik;
  Real P1_ik, P2_ik, P3_ik, Q1_ik, Q2_ik, Q3_ik, R1_ik, R2_ik, R3_ik;
  Real rho1, rho2, rho3;
  Real phi1, phi2, phi3;
  Real cos_arg1, cos_arg2, cos_arg3;
  Real q1_d, q2_d, q3_d;

  // === Control ===
  Real tau1_raw, tau2_raw, tau3_raw;
  Real tau1, tau2, tau3;
  Real Fdist;

  // === Reaction forces ===
  Real n1x, n1y, n1z, n2x, n2y, n2z, n3x, n3y, n3z;
  Real det_N, det_N_s;
  Real F_total;
  Real F1, F2, F3;

  // === Collision ===
  Real Jx1, Jy1, Jz1, Jx2, Jy2, Jz2, Jx3, Jy3, Jz3;
  Real d12, d23, d13;
  Real min_dist;
  Real collision_flag;

  // === Verification ===
  Real res1, res2, res3;
  Real pos_err;
  Real actuator_travel;

equation
  // === State derivatives ===
  der(q1) = dq1;
  der(q2) = dq2;
  der(q3) = dq3;

  // === Forward kinematics (analytical) ===
  K1 = Rp - Rb - L1*cos(q1);
  K2 = Rp - Rb - L1*cos(q2);
  K3 = Rp - Rb - L1*cos(q3);

  Ax1 = c1*K1;  Ay1 = s1*K1;  Az1 = L1*sin(q1);
  Ax2 = c2*K2;  Ay2 = s2*K2;  Az2 = L1*sin(q2);
  Ax3 = c3*K3;  Ay3 = s3*K3;  Az3 = L1*sin(q3);

  // Linear system from subtracting closure equations
  a11 = 2.0*(Ax2 - Ax1);
  a12 = 2.0*(Ay2 - Ay1);
  a13 = 2.0*(Az2 - Az1);
  a21 = 2.0*(Ax3 - Ax1);
  a22 = 2.0*(Ay3 - Ay1);
  a23 = 2.0*(Az3 - Az1);
  rb1 = (Ax1*Ax1 + Ay1*Ay1 + Az1*Az1) - (Ax2*Ax2 + Ay2*Ay2 + Az2*Az2);
  rb2 = (Ax1*Ax1 + Ay1*Ay1 + Az1*Az1) - (Ax3*Ax3 + Ay3*Ay3 + Az3*Az3);

  det_lin = a11*a22 - a12*a21;
  det_lin_s = noEvent(if abs(det_lin) > 1e-10 then det_lin else 1e-10);

  px0 = (a22*rb1 - a12*rb2) / det_lin_s;
  px_pz = (a12*a23 - a22*a13) / det_lin_s;
  py0 = (a11*rb2 - a21*rb1) / det_lin_s;
  py_pz = (a21*a13 - a11*a23) / det_lin_s;

  // Quadratic for pz (negative root: platform below base)
  alpha_q = px0 + Ax1;
  beta_q = px_pz;
  gamma_q = py0 + Ay1;
  delta_q = py_pz;
  epsilon_q = Az1;

  A_quad = beta_q*beta_q + delta_q*delta_q + 1.0;
  B_quad = 2.0*(alpha_q*beta_q + gamma_q*delta_q + epsilon_q);
  C_quad = alpha_q*alpha_q + gamma_q*gamma_q + epsilon_q*epsilon_q - L2*L2;

  disc_q = B_quad*B_quad - 4.0*A_quad*C_quad;
  pz = (-B_quad - sqrt(noEvent(max(disc_q, 0.0)))) / (2.0*A_quad);
  px = px0 + px_pz * pz;
  py = py0 + py_pz * pz;

  // === Forearm vectors (from upper arm tip to platform attachment) ===
  ux1 = px + Ax1;  uy1 = py + Ay1;  uz1 = pz + Az1;
  ux2 = px + Ax2;  uy2 = py + Ay2;  uz2 = pz + Az2;
  ux3 = px + Ax3;  uy3 = py + Ay3;  uz3 = pz + Az3;

  Lf1 = sqrt(ux1*ux1 + uy1*uy1 + uz1*uz1);
  Lf2 = sqrt(ux2*ux2 + uy2*uy2 + uz2*uz2);
  Lf3 = sqrt(ux3*ux3 + uy3*uy3 + uz3*uz3);

  // === Closure residuals ===
  res1 = Lf1 - L2;
  res2 = Lf2 - L2;
  res3 = Lf3 - L2;

  // === Jacobian z-components (constraint-based) ===
  dg1 = 2.0*L1*(ux1*c1 + uy1*s1)*sin(q1) + 2.0*L1*uz1*cos(q1);
  dg2 = 2.0*L1*(ux2*c2 + uy2*s2)*sin(q2) + 2.0*L1*uz2*cos(q2);
  dg3 = 2.0*L1*(ux3*c3 + uy3*s3)*sin(q3) + 2.0*L1*uz3*cos(q3);

  det_M = ux1*(uy2*uz3 - uy3*uz2) - uy1*(ux2*uz3 - ux3*uz2) + uz1*(ux2*uy3 - ux3*uy2);
  det_M_s = noEvent(if abs(det_M) > 1e-10 then det_M else 1e-10);

  J31 = -0.5 * (ux2*uy3 - uy2*ux3) / det_M_s * dg1;
  J32 = -0.5 * (uy1*ux3 - ux1*uy3) / det_M_s * dg2;
  J33 = -0.5 * (ux1*uy2 - uy1*ux2) / det_M_s * dg3;

  // === Disturbance force (middle third of simulation) ===
  Fdist = if time >= t_load_on and time <= t_load_off then Fload else 0.0;

  // === Actuator dynamics (diagonal reflected inertia, no cross-coupling) ===
  (Ja + mp*J31*J31) * der(dq1) = tau1 - b_vis*dq1 - (mp*g_grav + Fdist)*J31;
  (Ja + mp*J32*J32) * der(dq2) = tau2 - b_vis*dq2 - (mp*g_grav + Fdist)*J32;
  (Ja + mp*J33*J33) * der(dq3) = tau3 - b_vis*dq3 - (mp*g_grav + Fdist)*J33;

  // === Trajectory generation (smooth cosine ramp) ===
  ramp = if time < t_ramp then 0.5*(1.0 - cos(pi_c*time/t_ramp)) else 1.0;
  px_d = ramp * px_ref;
  py_d = ramp * py_ref;
  pz_d = (1.0 - ramp) * pz_init + ramp * pz_ref;

  // === Inverse kinematics (per-arm, constrained) ===
  ex1_ik = px_d + c1*(Rp - Rb);
  ey1_ik = py_d + s1*(Rp - Rb);
  ex2_ik = px_d + c2*(Rp - Rb);
  ey2_ik = py_d + s2*(Rp - Rb);
  ex3_ik = px_d + c3*(Rp - Rb);
  ey3_ik = py_d + s3*(Rp - Rb);

  P1_ik = ex1_ik*ex1_ik + ey1_ik*ey1_ik + pz_d*pz_d + L1*L1 - L2*L2;
  P2_ik = ex2_ik*ex2_ik + ey2_ik*ey2_ik + pz_d*pz_d + L1*L1 - L2*L2;
  P3_ik = ex3_ik*ex3_ik + ey3_ik*ey3_ik + pz_d*pz_d + L1*L1 - L2*L2;

  Q1_ik = -2.0*L1*(ex1_ik*c1 + ey1_ik*s1);
  Q2_ik = -2.0*L1*(ex2_ik*c2 + ey2_ik*s2);
  Q3_ik = -2.0*L1*(ex3_ik*c3 + ey3_ik*s3);

  R1_ik = 2.0*pz_d*L1;
  R2_ik = 2.0*pz_d*L1;
  R3_ik = 2.0*pz_d*L1;

  rho1 = sqrt(Q1_ik*Q1_ik + R1_ik*R1_ik);
  rho2 = sqrt(Q2_ik*Q2_ik + R2_ik*R2_ik);
  rho3 = sqrt(Q3_ik*Q3_ik + R3_ik*R3_ik);

  phi1 = atan2(R1_ik, Q1_ik);
  phi2 = atan2(R2_ik, Q2_ik);
  phi3 = atan2(R3_ik, Q3_ik);

  cos_arg1 = noEvent(max(-1.0, min(1.0, -P1_ik / noEvent(max(rho1, 1e-10)))));
  cos_arg2 = noEvent(max(-1.0, min(1.0, -P2_ik / noEvent(max(rho2, 1e-10)))));
  cos_arg3 = noEvent(max(-1.0, min(1.0, -P3_ik / noEvent(max(rho3, 1e-10)))));

  q1_d = phi1 + acos(cos_arg1);
  q2_d = phi2 + acos(cos_arg2);
  q3_d = phi3 + acos(cos_arg3);

  // === PD control with torque saturation ===
  tau1_raw = Kp*(q1_d - q1) + Kd*(0.0 - dq1);
  tau2_raw = Kp*(q2_d - q2) + Kd*(0.0 - dq2);
  tau3_raw = Kp*(q3_d - q3) + Kd*(0.0 - dq3);

  tau1 = max(-Tmax, min(Tmax, tau1_raw));
  tau2 = max(-Tmax, min(Tmax, tau2_raw));
  tau3 = max(-Tmax, min(Tmax, tau3_raw));

  // === Reaction forces (quasi-static platform balance) ===
  // Unit vectors along forearms (from platform point toward upper arm tip)
  n1x = -ux1 / noEvent(max(Lf1, 1e-10));
  n1y = -uy1 / noEvent(max(Lf1, 1e-10));
  n1z = -uz1 / noEvent(max(Lf1, 1e-10));
  n2x = -ux2 / noEvent(max(Lf2, 1e-10));
  n2y = -uy2 / noEvent(max(Lf2, 1e-10));
  n2z = -uz2 / noEvent(max(Lf2, 1e-10));
  n3x = -ux3 / noEvent(max(Lf3, 1e-10));
  n3y = -uy3 / noEvent(max(Lf3, 1e-10));
  n3z = -uz3 / noEvent(max(Lf3, 1e-10));

  det_N = n1x*(n2y*n3z - n3y*n2z) - n2x*(n1y*n3z - n3y*n1z) + n3x*(n1y*n2z - n2y*n1z);
  det_N_s = noEvent(if abs(det_N) > 1e-10 then det_N else 1e-10);

  F_total = mp*g_grav + Fdist;

  F1 = F_total * (n2x*n3y - n3x*n2y) / det_N_s;
  F2 = -F_total * (n1x*n3y - n3x*n1y) / det_N_s;
  F3 = F_total * (n1x*n2y - n2x*n1y) / det_N_s;

  // === Upper arm tip positions ===
  Jx1 = Rb*c1 + L1*c1*cos(q1);
  Jy1 = Rb*s1 + L1*s1*cos(q1);
  Jz1 = -L1*sin(q1);
  Jx2 = Rb*c2 + L1*c2*cos(q2);
  Jy2 = Rb*s2 + L1*s2*cos(q2);
  Jz2 = -L1*sin(q2);
  Jx3 = Rb*c3 + L1*c3*cos(q3);
  Jy3 = Rb*s3 + L1*s3*cos(q3);
  Jz3 = -L1*sin(q3);

  // === Self-collision check (distance between forearm midpoints) ===
  d12 = 0.5 * sqrt((Jx1 - Jx2 + Rp*(c1-c2))*(Jx1 - Jx2 + Rp*(c1-c2))
                  + (Jy1 - Jy2 + Rp*(s1-s2))*(Jy1 - Jy2 + Rp*(s1-s2))
                  + (Jz1 - Jz2)*(Jz1 - Jz2));
  d23 = 0.5 * sqrt((Jx2 - Jx3 + Rp*(c2-c3))*(Jx2 - Jx3 + Rp*(c2-c3))
                  + (Jy2 - Jy3 + Rp*(s2-s3))*(Jy2 - Jy3 + Rp*(s2-s3))
                  + (Jz2 - Jz3)*(Jz2 - Jz3));
  d13 = 0.5 * sqrt((Jx1 - Jx3 + Rp*(c1-c3))*(Jx1 - Jx3 + Rp*(c1-c3))
                  + (Jy1 - Jy3 + Rp*(s1-s3))*(Jy1 - Jy3 + Rp*(s1-s3))
                  + (Jz1 - Jz3)*(Jz1 - Jz3));

  min_dist = min(d12, min(d23, d13));
  collision_flag = if min_dist < 0.02 then 1.0 else 0.0;

  // === Verification metrics ===
  actuator_travel = abs(q1 - q_init) + abs(q2 - q_init) + abs(q3 - q_init);
  pos_err = sqrt((px - px_ref)*(px - px_ref) + (py - py_ref)*(py - py_ref) + (pz - pz_ref)*(pz - pz_ref));

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Delta parallel robot position control scenario.
      Mission: Move output platform to nonzero pose and hold against bounded load.
      Embodiment: Fixed triangular base, three 0.32 m upper arms, 0.60 m forearms, 3 kg platform.
      Actuation: Three base-joint torque actuators, max 54.9 N.m.
      Control: Pose feedback through constrained inverse kinematics with PD joint control.
      Disturbance: 20.3 N load during middle third (6.667-13.333 s).
      Verification: Actuator/force bounds, closure residuals, pose error, self-collision check.
      Tracking: pos_err < 0.005 m after 13 s. No NaN or infinite values.
      Geometry Rb, Rp, Ja, b_vis are reasonable estimates not specified in the requirement.")
  );
end DeltaPositionF;