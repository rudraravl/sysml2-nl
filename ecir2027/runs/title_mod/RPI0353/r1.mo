model DeltaPositionE
  "Delta robot closed-chain mechanism with position control, 250 Hz, 16 s"

  // --- Physical parameters ---
  parameter Real L1 = 0.32 "Upper arm length [m]";
  parameter Real L2 = 0.60 "Forearm length [m]";
  parameter Real m_platform = 3.0 "Moving platform mass [kg]";
  parameter Real Rb = 0.15 "Base joint radius [m]";
  parameter Real Rp = 0.05 "Platform joint radius [m]";
  parameter Real tau_max = 49.5 "Max actuator torque magnitude [N.m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_load_mag = 16.8 "Disturbance load magnitude [N]";

  // --- Control parameters ---
  parameter Real Kp = 500.0 "Proportional gain [N.m/rad]";
  parameter Real Kd = 20.0  "Derivative gain [N.m.s/rad]";
  parameter Real Ts = 0.004  "Control sample period [s], 250 Hz";

  // --- Scenario parameters ---
  parameter Real T_sim = 16.0 "Total simulation time [s]";
  parameter Real T_ramp = 2.0 "Reference ramp duration [s]";
  parameter Real theta_min = -0.5 "Minimum actuator angle [rad]";
  parameter Real theta_max_b = 1.2 "Maximum actuator angle [rad]";
  parameter Real coll_thresh = 0.01 "Self-collision distance threshold [m]";

  // --- Base joint angular positions (120 deg spacing) ---
  parameter Real phi1 = 0.0                       "Base joint 1 angle [rad]";
  parameter Real phi2 = 2.0*Modelica.Constants.pi/3.0 "Base joint 2 angle [rad]";
  parameter Real phi3 = 4.0*Modelica.Constants.pi/3.0 "Base joint 3 angle [rad]";

  // --- Home and target poses ---
  parameter Real px_home = 0.0   "Home x [m]";
  parameter Real py_home = 0.0   "Home y [m]";
  parameter Real pz_home = -0.50  "Home z [m]";
  parameter Real px_target = 0.02 "Target x [m]";
  parameter Real py_target = 0.01 "Target y [m]";
  parameter Real pz_target = -0.48 "Target z [m]";

  // --- Platform state ---
  Real px(start=px_home, fixed=true) "Platform x [m]";
  Real py(start=py_home, fixed=true) "Platform y [m]";
  Real pz(start=pz_home, fixed=true) "Platform z [m]";
  Real vx(start=0.0, fixed=true) "Platform vx [m/s]";
  Real vy(start=0.0, fixed=true) "Platform vy [m/s]";
  Real vz(start=0.0, fixed=true) "Platform vz [m/s]";

  // --- Actuator torque commands (discrete ZOH) ---
  discrete Real tau1(start=0.0) "Actuator 1 torque [N.m]";
  discrete Real tau2(start=0.0) "Actuator 2 torque [N.m]";
  discrete Real tau3(start=0.0) "Actuator 3 torque [N.m]";

  // --- Actuator coordinates (IK) ---
  Real theta1 "Actuator 1 angle [rad]";
  Real theta2 "Actuator 2 angle [rad]";
  Real theta3 "Actuator 3 angle [rad]";

  // --- Actuator angular velocities (Jacobian) ---
  Real omega1 "Actuator 1 angular velocity [rad/s]";
  Real omega2 "Actuator 2 angular velocity [rad/s]";
  Real omega3 "Actuator 3 angular velocity [rad/s]";

  // --- Desired actuator angles (reference IK) ---
  Real theta_des1 "Desired angle 1 [rad]";
  Real theta_des2 "Desired angle 2 [rad]";
  Real theta_des3 "Desired angle 3 [rad]";

  // --- Reference position ---
  Real ref_px "Reference x [m]";
  Real ref_py "Reference y [m]";
  Real ref_pz "Reference z [m]";

  // --- Closure residuals ---
  Real res1 "Chain 1 closure residual [m]";
  Real res2 "Chain 2 closure residual [m]";
  Real res3 "Chain 3 closure residual [m]";

  // --- Reaction forces (forearm axial) ---
  Real F_react1 "Chain 1 forearm force [N]";
  Real F_react2 "Chain 2 forearm force [N]";
  Real F_react3 "Chain 3 forearm force [N]";

  // --- Per-chain platform forces ---
  Real Fx1 "Chain 1 force x [N]";
  Real Fy1 "Chain 1 force y [N]";
  Real Fz1 "Chain 1 force z [N]";
  Real Fx2 "Chain 2 force x [N]";
  Real Fy2 "Chain 2 force y [N]";
  Real Fz2 "Chain 2 force z [N]";
  Real Fx3 "Chain 3 force x [N]";
  Real Fy3 "Chain 3 force y [N]";
  Real Fz3 "Chain 3 force z [N]";

  // --- Load ---
  Real F_load_x "Load force x [N]";
  Real F_load_y "Load force y [N]";
  Real F_load_z "Load force z [N]";
  Boolean load_active "Load active flag";

  // --- Tracking error ---
  Real err_x "Position error x [m]";
  Real err_y "Position error y [m]";
  Real err_z "Position error z [m]";
  Real err_norm "Position error norm [m]";

  // --- Collision ---
  Real min_dist "Minimum forearm midpoint distance [m]";
  Boolean no_collision "No self-collision flag";

  // --- Acceptance checks ---
  Boolean torque_bound_ok  "Torque within bounds";
  Boolean travel_bound_ok  "Angles within travel bounds";
  Boolean closure_ok       "Closure residuals small";
  Boolean tracking_ok      "Tracking error below 0.005 m after 10.4 s";
  Boolean no_nan_inf       "No NaN or infinite values";
  Boolean all_checks_pass  "All acceptance checks pass (fail-closed)";

  // --- Intermediate geometry ---
  Real U1x,U1y,U1z "Upper arm 1 tip [m]";
  Real U2x,U2y,U2z "Upper arm 2 tip [m]";
  Real U3x,U3y,U3z "Upper arm 3 tip [m]";
  Real P1x,P1y,P1z "Platform joint 1 [m]";
  Real P2x,P2y,P2z "Platform joint 2 [m]";
  Real P3x,P3y,P3z "Platform joint 3 [m]";
  Real L_a1 "Actual forearm 1 length [m]";
  Real L_a2 "Actual forearm 2 length [m]";
  Real L_a3 "Actual forearm 3 length [m]";
  Real n1x,n1y,n1z "Forearm 1 unit vector";
  Real n2x,n2y,n2z "Forearm 2 unit vector";
  Real n3x,n3y,n3z "Forearm 3 unit vector";
  Real eth1x,eth1y,eth1z "Arm 1 tangent direction";
  Real eth2x,eth2y,eth2z "Arm 2 tangent direction";
  Real eth3x,eth3y,eth3z "Arm 3 tangent direction";
  Real denom1,denom2,denom3 "Jacobian denominators";
  Real mid1x,mid1y,mid1z "Forearm 1 midpoint [m]";
  Real mid2x,mid2y,mid2z "Forearm 2 midpoint [m]";
  Real mid3x,mid3y,mid3z "Forearm 3 midpoint [m]";
  Real dist12 "Distance forearm 1-2 midpoints [m]";
  Real dist13 "Distance forearm 1-3 midpoints [m]";
  Real dist23 "Distance forearm 2-3 midpoints [m]";
  Real s_ref "Reference ramp parameter";

  function invKin
    "Constrained inverse kinematics for a single Delta chain"
    input Real p_x;
    input Real p_y;
    input Real p_z;
    input Real a_L1;
    input Real a_L2;
    input Real a_Rb;
    input Real a_Rp;
    input Real a_phi;
    output Real theta;
  protected
    Real A "Radial projection of chain vector";
    Real C "IK constant term";
    Real R "IK norm (zero-error branch: max(R,1e-10))";
    Real acos_arg "Clipped acos argument";
  algorithm
    A := p_x*cos(a_phi) + p_y*sin(a_phi) + (a_Rp - a_Rb);
    R := sqrt(A*A + p_z*p_z);
    C := (p_x*p_x + p_y*p_y + p_z*p_z
          + 2.0*(a_Rp - a_Rb)*(p_x*cos(a_phi) + p_y*sin(a_phi))
          + (a_Rp - a_Rb)*(a_Rp - a_Rb)
          + a_L1*a_L1 - a_L2*a_L2) / (2.0*a_L1);
    acos_arg := max(-1.0, min(1.0, C / max(R, 1e-10)));
    theta := atan2(-p_z, A) - acos(acos_arg);
  end invKin;

equation
  // ===== Reference trajectory: smooth cosine ramp =====
  s_ref = 0.5*(1.0 - cos(Modelica.Constants.pi*min(time/T_ramp, 1.0)));
  ref_px = px_home + (px_target - px_home)*s_ref;
  ref_py = py_home + (py_target - py_home)*s_ref;
  ref_pz = pz_home + (pz_target - pz_home)*s_ref;

  // ===== Inverse kinematics: current platform pose -> actuator angles =====
  theta1 = invKin(px, py, pz, L1, L2, Rb, Rp, phi1);
  theta2 = invKin(px, py, pz, L1, L2, Rb, Rp, phi2);
  theta3 = invKin(px, py, pz, L1, L2, Rb, Rp, phi3);

  // ===== Inverse kinematics: reference pose -> desired actuator angles =====
  theta_des1 = invKin(ref_px, ref_py, ref_pz, L1, L2, Rb, Rp, phi1);
  theta_des2 = invKin(ref_px, ref_py, ref_pz, L1, L2, Rb, Rp, phi2);
  theta_des3 = invKin(ref_px, ref_py, ref_pz, L1, L2, Rb, Rp, phi3);

  // ===== Upper arm tip positions =====
  U1x = (Rb + L1*cos(theta1))*cos(phi1);
  U1y = (Rb + L1*cos(theta1))*sin(phi1);
  U1z = -L1*sin(theta1);
  U2x = (Rb + L1*cos(theta2))*cos(phi2);
  U2y = (Rb + L1*cos(theta2))*sin(phi2);
  U2z = -L1*sin(theta2);
  U3x = (Rb + L1*cos(theta3))*cos(phi3);
  U3y = (Rb + L1*cos(theta3))*sin(phi3);
  U3z = -L1*sin(theta3);

  // ===== Platform joint positions =====
  P1x = px + Rp*cos(phi1);
  P1y = py + Rp*sin(phi1);
  P1z = pz;
  P2x = px + Rp*cos(phi2);
  P2y = py + Rp*sin(phi2);
  P2z = pz;
  P3x = px + Rp*cos(phi3);
  P3y = py + Rp*sin(phi3);
  P3z = pz;

  // ===== Forearm lengths and closure residuals =====
  L_a1 = sqrt((P1x-U1x)*(P1x-U1x) + (P1y-U1y)*(P1y-U1y) + (P1z-U1z)*(P1z-U1z));
  L_a2 = sqrt((P2x-U2x)*(P2x-U2x) + (P2y-U2y)*(P2y-U2y) + (P2z-U2z)*(P2z-U2z));
  L_a3 = sqrt((P3x-U3x)*(P3x-U3x) + (P3y-U3y)*(P3y-U3y) + (P3z-U3z)*(P3z-U3z));
  res1 = L_a1 - L2;
  res2 = L_a2 - L2;
  res3 = L_a3 - L2;

  // ===== Forearm unit vectors (zero-error branch on length) =====
  n1x = (P1x - U1x) / max(L_a1, 1e-10);
  n1y = (P1y - U1y) / max(L_a1, 1e-10);
  n1z = (P1z - U1z) / max(L_a1, 1e-10);
  n2x = (P2x - U2x) / max(L_a2, 1e-10);
  n2y = (P2y - U2y) / max(L_a2, 1e-10);
  n2z = (P2z - U2z) / max(L_a2, 1e-10);
  n3x = (P3x - U3x) / max(L_a3, 1e-10);
  n3y = (P3y - U3y) / max(L_a3, 1e-10);
  n3z = (P3z - U3z) / max(L_a3, 1e-10);

  // ===== Upper arm tangent directions (d/dtheta of arm vector) =====
  eth1x = -sin(theta1)*cos(phi1);
  eth1y = -sin(theta1)*sin(phi1);
  eth1z = -cos(theta1);
  eth2x = -sin(theta2)*cos(phi2);
  eth2y = -sin(theta2)*sin(phi2);
  eth2z = -cos(theta2);
  eth3x = -sin(theta3)*cos(phi3);
  eth3y = -sin(theta3)*sin(phi3);
  eth3z = -cos(theta3);

  // ===== Jacobian denominators (zero-error branch) =====
  denom1 = L1*(eth1x*n1x + eth1y*n1y + eth1z*n1z);
  denom2 = L1*(eth2x*n2x + eth2y*n2y + eth2z*n2z);
  denom3 = L1*(eth3x*n3x + eth3y*n3y + eth3z*n3z);

  // ===== Actuator angular velocities from velocity Jacobian =====
  omega1 = (n1x*vx + n1y*vy + n1z*vz) / max(denom1, 1e-10);
  omega2 = (n2x*vx + n2y*vy + n2z*vz) / max(denom2, 1e-10);
  omega3 = (n3x*vx + n3y*vy + n3z*vz) / max(denom3, 1e-10);

  // ===== Forces on platform from each chain (virtual work / Jacobian transpose) =====
  Fx1 = tau1 * n1x / max(denom1, 1e-10);
  Fy1 = tau1 * n1y / max(denom1, 1e-10);
  Fz1 = tau1 * n1z / max(denom1, 1e-10);
  Fx2 = tau2 * n2x / max(denom2, 1e-10);
  Fy2 = tau2 * n2y / max(denom2, 1e-10);
  Fz2 = tau2 * n2z / max(denom2, 1e-10);
  Fx3 = tau3 * n3x / max(denom3, 1e-10);
  Fy3 = tau3 * n3y / max(denom3, 1e-10);
  Fz3 = tau3 * n3z / max(denom3, 1e-10);

  // ===== Forearm reaction forces (axial) =====
  F_react1 = tau1 / max(denom1, 1e-10);
  F_react2 = tau2 / max(denom2, 1e-10);
  F_react3 = tau3 / max(denom3, 1e-10);

  // ===== Load disturbance: middle third of 16 s =====
  load_active = (time >= T_sim/3.0) and (time <= 2.0*T_sim/3.0);
  F_load_x = 0.0;
  F_load_y = 0.0;
  F_load_z = if load_active then -F_load_mag else 0.0;

  // ===== Platform dynamics (3-DOF translation) =====
  der(px) = vx;
  der(py) = vy;
  der(pz) = vz;
  der(vx) = (Fx1 + Fx2 + Fx3 + F_load_x) / m_platform;
  der(vy) = (Fy1 + Fy2 + Fy3 + F_load_y) / m_platform;
  der(vz) = (Fz1 + Fz2 + Fz3 + F_load_z - m_platform*g) / m_platform;

  // ===== Position error =====
  err_x = px - ref_px;
  err_y = py - ref_py;
  err_z = pz - ref_pz;
  err_norm = sqrt(err_x*err_x + err_y*err_y + err_z*err_z);

  // ===== Self-collision check: forearm midpoint distances =====
  mid1x = (U1x + P1x)/2.0;
  mid1y = (U1y + P1y)/2.0;
  mid1z = (U1z + P1z)/2.0;
  mid2x = (U2x + P2x)/2.0;
  mid2y = (U2y + P2y)/2.0;
  mid2z = (U2z + P2z)/2.0;
  mid3x = (U3x + P3x)/2.0;
  mid3y = (U3y + P3y)/2.0;
  mid3z = (U3z + P3z)/2.0;
  dist12 = sqrt((mid1x-mid2x)*(mid1x-mid2x) + (mid1y-mid2y)*(mid1y-mid2y) + (mid1z-mid2z)*(mid1z-mid2z));
  dist13 = sqrt((mid1x-mid3x)*(mid1x-mid3x) + (mid1y-mid3y)*(mid1y-mid3y) + (mid1z-mid3z)*(mid1z-mid3z));
  dist23 = sqrt((mid2x-mid3x)*(mid2x-mid3x) + (mid2y-mid3y)*(mid2y-mid3y) + (mid2z-mid3z)*(mid2z-mid3z));
  min_dist = min(dist12, min(dist13, dist23));
  no_collision = min_dist > coll_thresh;

  // ===== Acceptance checks (fail-closed) =====
  torque_bound_ok = (abs(tau1) <= tau_max + 1e-6)
                    and (abs(tau2) <= tau_max + 1e-6)
                    and (abs(tau3) <= tau_max + 1e-6);

  travel_bound_ok = (theta1 >= theta_min) and (theta1 <= theta_max_b)
                   and (theta2 >= theta_min) and (theta2 <= theta_max_b)
                   and (theta3 >= theta_min) and (theta3 <= theta_max_b);

  closure_ok = (abs(res1) < 1e-6) and (abs(res2) < 1e-6) and (abs(res3) < 1e-6);

  tracking_ok = (time < 10.4) or (err_norm < 0.005);

  no_nan_inf = (px > -1e10) and (px < 1e10)
              and (py > -1e10) and (py < 1e10)
              and (pz > -1e10) and (pz < 1e10)
              and (vx > -1e10) and (vx < 1e10)
              and (vy > -1e10) and (vy < 1e10)
              and (vz > -1e10) and (vz < 1e10)
              and (tau1 > -1e10) and (tau1 < 1e10)
              and (tau2 > -1e10) and (tau2 < 1e10)
              and (tau3 > -1e10) and (tau3 < 1e10)
              and (err_norm >= 0.0) and (err_norm < 1e10)
              and (theta1 > -1e10) and (theta1 < 1e10)
              and (theta2 > -1e10) and (theta2 < 1e10)
              and (theta3 > -1e10) and (theta3 < 1e10)
              and (F_react1 > -1e10) and (F_react1 < 1e10)
              and (F_react2 > -1e10) and (F_react2 < 1e10)
              and (F_react3 > -1e10) and (F_react3 < 1e10);

  all_checks_pass = torque_bound_ok and travel_bound_ok and closure_ok
                    and tracking_ok and no_collision and no_nan_inf;

  // ===== Discrete PD control at 250 Hz with torque saturation =====
  when sample(0, Ts) then
    tau1 = max(-tau_max, min(tau_max, Kp*(theta_des1 - theta1) - Kd*omega1));
    tau2 = max(-tau_max, min(tau_max, Kp*(theta_des2 - theta2) - Kd*omega2));
    tau3 = max(-tau_max, min(tau_max, Kp*(theta_des3 - theta3) - Kd*omega3));
  end when;

  annotation(
    experiment(StartTime=0, StopTime=16.0, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Delta robot: 3-chain parallel mechanism with 0.32 m upper arms,
0.60 m forearms, 3 kg platform. Base-joint torque actuators bounded at 49.5 N.m.
PD control via constrained inverse kinematics at 250 Hz. 16.8 N middle-third load
disturbance. Tracks a smooth ramp to a nonzero pose. Verifies closure residuals,
torque/force bounds, travel bounds, self-collision, tracking error < 0.005 m after
10.4 s, and absence of NaN/infinite values."));

end DeltaPositionE;