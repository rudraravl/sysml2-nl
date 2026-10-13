model BipedTwoRecoverE
  /* Plant and acceptance model for a floating-base biped.
     Unknown facts not stated in the requirement are marked below.
     Pelvis inertia, leg masses/inertias, foot dimensions, and stance width
     are not specified; placeholder constants are marked as unknown but
     are given finite non-singular values required for code generation. */

  // Stated plant parameters
  parameter Real m_p(unit="kg") = 36.0 "Pelvis mass";
  parameter Real L_t(unit="m") = 0.42 "Thigh length";
  parameter Real L_s(unit="m") = 0.40 "Shank length";
  parameter Real mu(unit="1") = 0.90 "Ground friction coefficient";
  parameter Real tau_max(unit="N.m") = 138.0 "Per-joint torque bound";
  parameter Real F_push_amp(unit="N") = 168.0 "Controlled lateral push amplitude";
  parameter Real Ts(unit="s") = 0.004 "Control and sensor sample period, 250 Hz";
  parameter Real T_end(unit="s") = 16.0 "Scenario duration";
  parameter Real T_push_start(unit="s") = T_end/3.0 "Middle-third push start";
  parameter Real T_push_end(unit="s") = 2.0*T_end/3.0 "Middle-third push end";
  parameter Real error_tol(unit="rad") = 0.108 "Primary tracking error limit after 10.4 s";
  parameter Real t_check(unit="s") = 10.4 "Acceptance check time";
  parameter Real slip_max(unit="m") = 0.03 "Maximum allowed foot slip";

  // Placeholder parameters for facts not stated (marked unknown)
  parameter Real I_p(unit="kg.m2") = 4.0 "Pelvis roll inertia, not stated; finite placeholder";
  parameter Real J_joint(unit="kg.m2") = 1.0 "Joint inertia, not stated; finite placeholder";
  parameter Real c_joint(unit="N.m.s/rad") = 20.0 "Joint damping, not stated; finite placeholder";
  parameter Real k_joint(unit="N.m/rad") = 100.0 "Joint restoring gain, not stated; finite placeholder";
  parameter Real k_z(unit="N/m") = 1.0e5 "Vertical contact stiffness, not stated; finite placeholder";
  parameter Real d_z(unit="N.s/m") = 2.0e3 "Vertical contact damping, not stated; finite placeholder";
  parameter Real k_y(unit="N/m") = 3.0e4 "Lateral contact stiffness, not stated; finite placeholder";
  parameter Real d_y(unit="N.s/m") = 1.0e3 "Lateral contact damping, not stated; finite placeholder";

  // Control/initial configuration (not stated; finite non-singular values)
  parameter Real q_h0L(unit="rad") = 0.15 "Initial left hip abduction, control choice";
  parameter Real q_h0R(unit="rad") = -0.15 "Initial right hip abduction, control choice";
  parameter Real q_k0(unit="rad") = 0.10 "Initial knee flexion, control choice";
  parameter Real g(unit="m/s2") = 9.81 "Gravity";

  parameter Real z0(unit="m") = L_t*cos(q_h0L) + L_s*cos(q_h0L + q_k0) "Nominal pelvis height";
  parameter Real y_contactL(unit="m") = L_t*sin(q_h0L) + L_s*sin(q_h0L + q_k0) "Left ground contact point";
  parameter Real y_contactR(unit="m") = -y_contactL "Right ground contact point";
  parameter Real z_b_start(unit="m") = z0 - m_p*g/(2.0*k_z) "Initial pelvis height for static load";

  // Floating-base states
  Real y_b(unit="m", start=0.0) "Pelvis lateral position";
  Real yd_b(unit="m/s", start=0.0) "Pelvis lateral velocity";
  Real z_b(unit="m", start=z_b_start) "Pelvis height";
  Real zd_b(unit="m/s", start=0.0) "Pelvis vertical velocity";
  Real theta(unit="rad", start=0.0) "Pelvis roll attitude";
  Real thd(unit="rad/s", start=0.0) "Pelvis roll rate";

  // Left leg joint states (spherical hip: 3 axes, revolute knee, two-axis ankle)
  Real q_hL1(unit="rad", start=q_h0L) "Left hip roll";
  Real qd_hL1(unit="rad/s", start=0.0);
  Real q_hL2(unit="rad", start=0.0) "Left hip pitch";
  Real qd_hL2(unit="rad/s", start=0.0);
  Real q_hL3(unit="rad", start=0.0) "Left hip yaw";
  Real qd_hL3(unit="rad/s", start=0.0);
  Real q_kL(unit="rad", start=q_k0) "Left knee flexion";
  Real qd_kL(unit="rad/s", start=0.0);
  Real q_aL1(unit="rad", start=0.0) "Left ankle roll";
  Real qd_aL1(unit="rad/s", start=0.0);
  Real q_aL2(unit="rad", start=0.0) "Left ankle pitch";
  Real qd_aL2(unit="rad/s", start=0.0);

  // Right leg joint states
  Real q_hR1(unit="rad", start=q_h0R) "Right hip roll";
  Real qd_hR1(unit="rad/s", start=0.0);
  Real q_hR2(unit="rad", start=0.0) "Right hip pitch";
  Real qd_hR2(unit="rad/s", start=0.0);
  Real q_hR3(unit="rad", start=0.0) "Right hip yaw";
  Real qd_hR3(unit="rad/s", start=0.0);
  Real q_kR(unit="rad", start=q_k0) "Right knee flexion";
  Real qd_kR(unit="rad/s", start=0.0);
  Real q_aR1(unit="rad", start=0.0) "Right ankle roll";
  Real qd_aR1(unit="rad/s", start=0.0);
  Real q_aR2(unit="rad", start=0.0) "Right ankle pitch";
  Real qd_aR2(unit="rad/s", start=0.0);

  // Kinematics
  Real a1L(unit="rad") "Left thigh absolute angle";
  Real a2L(unit="rad") "Left shank absolute angle";
  Real a3L(unit="rad") "Left foot absolute angle";
  Real a1R(unit="rad") "Right thigh absolute angle";
  Real a2R(unit="rad") "Right shank absolute angle";
  Real a3R(unit="rad") "Right foot absolute angle";
  Real y_fL(unit="m") "Left foot lateral position";
  Real z_fL(unit="m") "Left foot height";
  Real vy_fL(unit="m/s") "Left foot lateral velocity";
  Real vz_fL(unit="m/s") "Left foot vertical velocity";
  Real y_fR(unit="m") "Right foot lateral position";
  Real z_fR(unit="m") "Right foot height";
  Real vy_fR(unit="m/s") "Right foot lateral velocity";
  Real vz_fR(unit="m/s") "Right foot vertical velocity";

  // Contacts and disturbance
  Real FzL(unit="N") "Left vertical ground reaction";
  Real FyL_des(unit="N") "Left desired lateral friction force";
  Real FyL(unit="N") "Left lateral ground reaction";
  Real FzR(unit="N") "Right vertical ground reaction";
  Real FyR_des(unit="N") "Right desired lateral friction force";
  Real FyR(unit="N") "Right lateral ground reaction";
  Real F_push(unit="N") "Applied lateral body impulse force";

  // Estimator outputs
  discrete Real base_y_est(unit="m", start=0.0) "Estimated base lateral position";
  discrete Real base_z_est(unit="m", start=z_b_start) "Estimated base height";
  discrete Real base_theta_est(unit="rad", start=0.0) "Estimated base attitude";
  discrete Boolean contactQualifiedL(start=true) "Left force-qualified stance contact";
  discrete Boolean contactQualifiedR(start=true) "Right force-qualified stance contact";
  discrete Boolean stance_L(start=true) "Left stance flag";
  discrete Boolean stance_R(start=true) "Right stance flag";

  // Commanded joint torques (bounded)
  discrete Real tau_hL1(unit="N.m", start=0.0);
  discrete Real tau_hL2(unit="N.m", start=0.0);
  discrete Real tau_hL3(unit="N.m", start=0.0);
  discrete Real tau_kL(unit="N.m", start=0.0);
  discrete Real tau_aL1(unit="N.m", start=0.0);
  discrete Real tau_aL2(unit="N.m", start=0.0);
  discrete Real tau_hR1(unit="N.m", start=0.0);
  discrete Real tau_hR2(unit="N.m", start=0.0);
  discrete Real tau_hR3(unit="N.m", start=0.0);
  discrete Real tau_kR(unit="N.m", start=0.0);
  discrete Real tau_aR1(unit="N.m", start=0.0);
  discrete Real tau_aR2(unit="N.m", start=0.0);

  // Acceptance variables
  Real slipL(unit="m") "Left foot slip displacement";
  Real slipR(unit="m") "Right foot slip displacement";
  Real tracking_error(unit="rad") "Primary attitude tracking error";
  Boolean torque_ok;
  Boolean slip_ok;
  Boolean height_ok;
  Boolean attitude_ok;
  Boolean finite_ok;
  Boolean Accept(start=true) "Fail-closed acceptance flag";

equation
  // Left leg kinematics
  a1L = theta + q_hL1;
  a2L = a1L + q_kL;
  a3L = a2L + q_aL1;
  y_fL = y_b + L_t*sin(a1L) + L_s*sin(a2L);
  z_fL = z_b - L_t*cos(a1L) - L_s*cos(a2L);
  vy_fL = yd_b + L_t*cos(a1L)*(thd + qd_hL1) + L_s*cos(a2L)*(thd + qd_hL1 + qd_kL);
  vz_fL = zd_b + L_t*sin(a1L)*(thd + qd_hL1) + L_s*sin(a2L)*(thd + qd_hL1 + qd_kL);

  // Right leg kinematics
  a1R = theta + q_hR1;
  a2R = a1R + q_kR;
  a3R = a2R + q_aR1;
  y_fR = y_b + L_t*sin(a1R) + L_s*sin(a2R);
  z_fR = z_b - L_t*cos(a1R) - L_s*cos(a2R);
  vy_fR = yd_b + L_t*cos(a1R)*(thd + qd_hR1) + L_s*cos(a2R)*(thd + qd_hR1 + qd_kR);
  vz_fR = zd_b + L_t*sin(a1R)*(thd + qd_hR1) + L_s*sin(a2R)*(thd + qd_hR1 + qd_kR);

  // Contact forces
  FzL = if z_fL < 0.0 then max(0.0, -k_z*z_fL - d_z*vz_fL) else 0.0;
  FyL_des = -k_y*(y_fL - y_contactL) - d_y*vy_fL;
  FyL = if FzL > 0.0 then max(-mu*FzL, min(mu*FzL, FyL_des)) else 0.0;

  FzR = if z_fR < 0.0 then max(0.0, -k_z*z_fR - d_z*vz_fR) else 0.0;
  FyR_des = -k_y*(y_fR - y_contactR) - d_y*vy_fR;
  FyR = if FzR > 0.0 then max(-mu*FzR, min(mu*FzR, FyR_des)) else 0.0;

  // Disturbance
  F_push = if time >= T_push_start and time <= T_push_end then F_push_amp else 0.0;

  // Floating-base dynamics
  der(y_b) = yd_b;
  der(yd_b) = (FyL + FyR + F_push)/m_p;
  der(z_b) = zd_b;
  der(zd_b) = (FzL + FzR - m_p*g)/m_p;
  der(theta) = thd;
  der(thd) = ((y_fL - y_b)*FzL + (z_fL - z_b)*FyL + (y_fR - y_b)*FzR + (z_fR - z_b)*FyR)/I_p;

  // Left joint dynamics
  der(q_hL1) = qd_hL1;
  der(qd_hL1) = (tau_hL1 - c_joint*qd_hL1 - k_joint*(q_hL1 - q_h0L))/J_joint;
  der(q_hL2) = qd_hL2;
  der(qd_hL2) = (tau_hL2 - c_joint*qd_hL2 - k_joint*q_hL2)/J_joint;
  der(q_hL3) = qd_hL3;
  der(qd_hL3) = (tau_hL3 - c_joint*qd_hL3 - k_joint*q_hL3)/J_joint;
  der(q_kL) = qd_kL;
  der(qd_kL) = (tau_kL - c_joint*qd_kL - k_joint*(q_kL - q_k0))/J_joint;
  der(q_aL1) = qd_aL1;
  der(qd_aL1) = (tau_aL1 - c_joint*qd_aL1 - k_joint*q_aL1)/J_joint;
  der(q_aL2) = qd_aL2;
  der(qd_aL2) = (tau_aL2 - c_joint*qd_aL2 - k_joint*q_aL2)/J_joint;

  // Right joint dynamics
  der(q_hR1) = qd_hR1;
  der(qd_hR1) = (tau_hR1 - c_joint*qd_hR1 - k_joint*(q_hR1 - q_h0R))/J_joint;
  der(q_hR2) = qd_hR2;
  der(qd_hR2) = (tau_hR2 - c_joint*qd_hR2 - k_joint*q_hR2)/J_joint;
  der(q_hR3) = qd_hR3;
  der(qd_hR3) = (tau_hR3 - c_joint*qd_hR3 - k_joint*q_hR3)/J_joint;
  der(q_kR) = qd_kR;
  der(qd_kR) = (tau_kR - c_joint*qd_kR - k_joint*(q_kR - q_k0))/J_joint;
  der(q_aR1) = qd_aR1;
  der(qd_aR1) = (tau_aR1 - c_joint*qd_aR1 - k_joint*q_aR1)/J_joint;
  der(q_aR2) = qd_aR2;
  der(qd_aR2) = (tau_aR2 - c_joint*qd_aR2 - k_joint*q_aR2)/J_joint;

  // Whole-body balance controller and estimator at 250 Hz
  when sample(0.0, Ts) then
    // Contact qualification from force threshold
    stance_L := FzL > 10.0;
    stance_R := FzR > 10.0;
    contactQualifiedL := stance_L;
    contactQualifiedR := stance_R;

    // Base pose estimator from IMU, kinematics, and qualified contacts
    base_y_est := if stance_L and stance_R then (y_fL + y_fR)/2.0
                  elseif stance_L then y_fL
                  elseif stance_R then y_fR
                  else y_b;
    base_z_est := z_b;
    base_theta_est := theta;

    // Desired hip roll includes balance feedback for lateral and attitude recovery
    tau_hL1 := max(-tau_max, min(tau_max,
      300.0*(q_h0L - 0.5*y_b - 1.0*theta - q_hL1) - 30.0*qd_hL1));
    tau_hR1 := max(-tau_max, min(tau_max,
      300.0*(q_h0R - 0.5*y_b - 1.0*theta - q_hR1) - 30.0*qd_hR1));

    // Non-active hip axes regulated to zero
    tau_hL2 := max(-tau_max, min(tau_max, 100.0*(0.0 - q_hL2) - 10.0*qd_hL2));
    tau_hL3 := max(-tau_max, min(tau_max, 100.0*(0.0 - q_hL3) - 10.0*qd_hL3));
    tau_hR2 := max(-tau_max, min(tau_max, 100.0*(0.0 - q_hR2) - 10.0*qd_hR2));
    tau_hR3 := max(-tau_max, min(tau_max, 100.0*(0.0 - q_hR3) - 10.0*qd_hR3));

    // Knee control with height regulation
    tau_kL := max(-tau_max, min(tau_max,
      300.0*(q_k0 - q_kL) - 30.0*qd_kL + 50.0*(z0 - z_b)));
    tau_kR := max(-tau_max, min(tau_max,
      300.0*(q_k0 - q_kR) - 30.0*qd_kR + 50.0*(z0 - z_b)));

    // Ankle roll contributes to attitude recovery
    tau_aL1 := max(-tau_max, min(tau_max, 200.0*(0.0 - q_aL1) - 20.0*qd_aL1 - 100.0*theta));
    tau_aR1 := max(-tau_max, min(tau_max, 200.0*(0.0 - q_aR1) - 20.0*qd_aR1 - 100.0*theta));

    // Ankle pitch regulated to zero
    tau_aL2 := max(-tau_max, min(tau_max, 100.0*(0.0 - q_aL2) - 10.0*qd_aL2));
    tau_aR2 := max(-tau_max, min(tau_max, 100.0*(0.0 - q_aR2) - 10.0*qd_aR2));
  end when;

  // Acceptance checks
  slipL = y_fL - y_contactL;
  slipR = y_fR - y_contactR;
  tracking_error = abs(theta);

  torque_ok = abs(tau_hL1) <= tau_max + 1.0e-6 and
              abs(tau_hL2) <= tau_max + 1.0e-6 and
              abs(tau_hL3) <= tau_max + 1.0e-6 and
              abs(tau_kL) <= tau_max + 1.0e-6 and
              abs(tau_aL1) <= tau_max + 1.0e-6 and
              abs(tau_aL2) <= tau_max + 1.0e-6 and
              abs(tau_hR1) <= tau_max + 1.0e-6 and
              abs(tau_hR2) <= tau_max + 1.0e-6 and
              abs(tau_hR3) <= tau_max + 1.0e-6 and
              abs(tau_kR) <= tau_max + 1.0e-6 and
              abs(tau_aR1) <= tau_max + 1.0e-6 and
              abs(tau_aR2) <= tau_max + 1.0e-6;

  slip_ok = abs(slipL) <= slip_max and abs(slipR) <= slip_max;
  height_ok = z_b > 0.0;
  attitude_ok = if time >= t_check then tracking_error < error_tol else true;

  finite_ok = abs(y_b) < 1.0e300 and abs(yd_b) < 1.0e300 and
              abs(z_b) < 1.0e300 and abs(zd_b) < 1.0e300 and
              abs(theta) < 1.0e300 and abs(thd) < 1.0e300 and
              abs(FzL) < 1.0e300 and abs(FyL) < 1.0e300 and
              abs(FzR) < 1.0e300 and abs(FyR) < 1.0e300 and
              abs(tau_hL1) < 1.0e300 and abs(tau_hL2) < 1.0e300 and
              abs(tau_hL3) < 1.0e300 and abs(tau_kL) < 1.0e300 and
              abs(tau_aL1) < 1.0e300 and abs(tau_aL2) < 1.0e300 and
              abs(tau_hR1) < 1.0e300 and abs(tau_hR2) < 1.0e300 and
              abs(tau_hR3) < 1.0e300 and abs(tau_kR) < 1.0e300 and
              abs(tau_aR1) < 1.0e300 and abs(tau_aR2) < 1.0e300 and
              abs(base_y_est) < 1.0e300 and abs(base_z_est) < 1.0e300 and
              abs(base_theta_est) < 1.0e300;

  when {not torque_ok, not slip_ok, not height_ok,
        time >= t_check and not attitude_ok, not finite_ok} then
    Accept = false;
  end when;

  annotation(
    experiment(StopTime=16.0, Tolerance=1.0e-6),
    Documentation(info="BipedTwoRecoverE: floating-base biped plant with bounded torque actuators, contact switching, base estimator, and fail-closed acceptance checks.")
  );
end BipedTwoRecoverE;