model FiveBarPositionB
  // ==================== Geometry Parameters ====================
  parameter Real A1x = -0.25 "Base pivot 1 x (m)";
  parameter Real A1y = 0.0 "Base pivot 1 y (m)";
  parameter Real A2x = 0.25 "Base pivot 2 x (m)";
  parameter Real A2y = 0.0 "Base pivot 2 y (m)";
  parameter Real L_act = 0.30 "Actuated link length (m)";
  parameter Real L_pas = 0.42 "Passive link length (m)";
  parameter Real tau_max = 31.2 "Max torque per actuator (N.m)";

  // ==================== Dynamic Parameters ====================
  parameter Real I_eff = 0.04 "Effective joint inertia (kg.m^2)";
  parameter Real b_damp = 0.2 "Joint damping (N.m.s/rad)";
  parameter Real m_link = 0.5 "Link mass (kg)";
  parameter Real m_payload = 0.5 "Payload mass (kg)";
  parameter Real g = 9.81 "Gravity (m/s^2)";

  // ==================== Control Parameters ====================
  parameter Real Kp = 300.0 "Joint position gain (N.m/rad)";
  parameter Real Kd = 25.0 "Joint velocity gain (N.m.s/rad)";
  parameter Real dt_ctrl = 0.01 "Control period (s) — 100 Hz";
  parameter Real q_min = 0.05 "Min joint angle (rad)";
  parameter Real q_max = 3.09 "Max joint angle (rad)";

  // ==================== Mission Parameters ====================
  parameter Real T_sim = 10.0 "Total simulation time (s)";
  parameter Real F_dist_mag = 9.8 "Disturbance force magnitude (N)";
  parameter Real Pdx = 0.05 "Desired end x (m)";
  parameter Real Pdy = 0.50 "Desired end y (m)";
  parameter Real pose_thresh = 0.007 "Pose error threshold (m)";
  parameter Real t_thresh = 6.5 "Convergence time threshold (s)";

  // ==================== Dynamic States ====================
  Real q1(start=0.2, fixed=true) "Actuated joint 1 angle (rad)";
  Real q2(start=2.0, fixed=true) "Actuated joint 2 angle (rad)";
  Real dq1(start=0.0, fixed=true) "Joint 1 velocity (rad/s)";
  Real dq2(start=0.0, fixed=true) "Joint 2 velocity (rad/s)";

  // ==================== Forward Kinematics ====================
  Real B1x "Elbow 1 x (m)";
  Real B1y "Elbow 1 y (m)";
  Real B2x "Elbow 2 x (m)";
  Real B2y "Elbow 2 y (m)";
  Real Px "End point x (m)";
  Real Py "End point y (m)";
  Real d_elbows "Distance between elbows (m)";
  Real h_int "Circle intersection height (m)";
  Real Mx "Elbow midpoint x (m)";
  Real My "Elbow midpoint y (m)";
  Real ey_x "Perpendicular unit x";
  Real ey_y "Perpendicular unit y";
  Real P1y_cand "Candidate y 1 (m)";
  Real P2y_cand "Candidate y 2 (m)";
  Real sgn_h "Sign for upper solution";
  Real phi1 "Passive joint 1 angle (rad)";
  Real phi2 "Passive joint 2 angle (rad)";
  Real closure_res1 "Closure residual 1 (m)";
  Real closure_res2 "Closure residual 2 (m)";

  // ==================== Jacobian ====================
  Real sin_phi_diff "sin(phi1-phi2)";
  Real sin_pd "Protected sin(phi1-phi2)";
  Real J11 "Jacobian (1,1)";
  Real J12 "Jacobian (1,2)";
  Real J21 "Jacobian (2,1)";
  Real J22 "Jacobian (2,2)";

  // ==================== Inverse Kinematics ====================
  Real d1_ik "IK distance 1 (m)";
  Real d2_ik "IK distance 2 (m)";
  Real cos_beta1 "IK cos beta 1";
  Real cos_beta2 "IK cos beta 2";
  Real beta1_ik "IK elbow angle 1 (rad)";
  Real beta2_ik "IK elbow angle 2 (rad)";
  Real q1_des "Desired q1 (rad)";
  Real q2_des "Desired q2 (rad)";

  // ==================== Controller ====================
  discrete Real tau1_cmd(start=0.0) "Torque 1 command (N.m)";
  discrete Real tau2_cmd(start=0.0) "Torque 2 command (N.m)";
  Real tau1_sat "Saturated torque 1 (N.m)";
  Real tau2_sat "Saturated torque 2 (N.m)";
  Real q1_err "Joint 1 tracking error (rad)";
  Real q2_err "Joint 2 tracking error (rad)";

  // ==================== Forces ====================
  Real F_end_x "End force x (N)";
  Real F_end_y "End force y (N)";
  Real F_dist_x "Disturbance x (N)";
  Real F_dist_y "Disturbance y (N)";
  Real tau_load1 "Load torque 1 (N.m)";
  Real tau_load2 "Load torque 2 (N.m)";
  Real ddq1 "Joint 1 acceleration (rad/s^2)";
  Real ddq2 "Joint 2 acceleration (rad/s^2)";

  // ==================== Reaction Forces ====================
  Real sin_pq1 "sin(phi1-q1)";
  Real sin_pq1_safe "Protected sin(phi1-q1)";
  Real sin_pq2 "sin(phi2-q2)";
  Real sin_pq2_safe "Protected sin(phi2-q2)";
  Real F_pas1 "Passive link 1 force (N)";
  Real F_pas2 "Passive link 2 force (N)";
  Real R1x "Base 1 reaction x (N)";
  Real R1y "Base 1 reaction y (N)";
  Real R2x "Base 2 reaction x (N)";
  Real R2y "Base 2 reaction y (N)";
  Real a_cm1x "Link 1 CM accel x (m/s^2)";
  Real a_cm1y "Link 1 CM accel y (m/s^2)";
  Real a_cm2x "Link 2 CM accel x (m/s^2)";
  Real a_cm2y "Link 2 CM accel y (m/s^2)";

  // ==================== Error Metrics ====================
  Real pose_err "Pose tracking error (m)";

  // ==================== Collision ====================
  Real cr_a1 "Cross product a1";
  Real cr_a2 "Cross product a2";
  Real cr_a3 "Cross product a3";
  Real cr_a4 "Cross product a4";
  Real cr_b1 "Cross product b1";
  Real cr_b2 "Cross product b2";
  Real cr_b3 "Cross product b3";
  Real cr_b4 "Cross product b4";
  Real cr_c1 "Cross product c1";
  Real cr_c2 "Cross product c2";
  Real cr_c3 "Cross product c3";
  Real cr_c4 "Cross product c4";
  Boolean coll_a "Actuated links intersect";
  Boolean coll_b "Left-act right-pas intersect";
  Boolean coll_c "Right-act left-pas intersect";
  Boolean collision "Self-collision flag";

  // ==================== Bounds ====================
  Boolean travel_ok "Travel within bounds";
  Boolean force_ok "Force within bounds";
  Boolean pose_ok "Pose error OK after threshold";
  Boolean no_nan_inf "No NaN or infinity";
  Boolean all_ok "All constraints satisfied";

equation
  // === Disturbance (middle third: T/3 to 2T/3) ===
  F_dist_x = 0.0;
  if time >= T_sim/3.0 and time <= 2.0*T_sim/3.0 then
    F_dist_y = -F_dist_mag;
  else
    F_dist_y = 0.0;
  end if;

  // === Forward Kinematics ===
  B1x = A1x + L_act*cos(q1);
  B1y = A1y + L_act*sin(q1);
  B2x = A2x + L_act*cos(q2);
  B2y = A2y + L_act*sin(q2);

  d_elbows = sqrt((B2x - B1x)^2 + (B2y - B1y)^2);

  Mx = (B1x + B2x) / 2.0;
  My = (B1y + B2y) / 2.0;
  ey_x = -(B2y - B1y) / max(d_elbows, 1e-9);
  ey_y = (B2x - B1x) / max(d_elbows, 1e-9);
  h_int = sqrt(max(L_pas^2 - (d_elbows/2.0)^2, 1e-12));

  // Select upper intersection (larger Py)
  P1y_cand = My + h_int * ey_y;
  P2y_cand = My - h_int * ey_y;
  sgn_h = if noEvent(P1y_cand >= P2y_cand) then 1.0 else -1.0;
  Px = Mx + sgn_h * h_int * ey_x;
  Py = My + sgn_h * h_int * ey_y;

  // Passive joint angles
  phi1 = atan2(Py - B1y, Px - B1x);
  phi2 = atan2(Py - B2y, Px - B2x);

  // Closure residuals (should be ~0 by construction)
  closure_res1 = sqrt((Px - B1x)^2 + (Py - B1y)^2) - L_pas;
  closure_res2 = sqrt((Px - B2x)^2 + (Py - B2y)^2) - L_pas;

  // === Jacobian (analytic, from velocity loop closure) ===
  sin_phi_diff = sin(phi1 - phi2);
  sin_pd = if noEvent(sin_phi_diff > 0) then max(sin_phi_diff, 1e-6)
           else min(sin_phi_diff, -1e-6);

  J11 = -L_act*sin(q1) - L_act*sin(phi1)*sin(q2 - phi2)/sin_pd;
  J12 = -L_act*sin(phi1)*sin(phi2 - q1)/sin_pd;
  J21 =  L_act*cos(q1) + L_act*cos(phi1)*sin(q2 - phi2)/sin_pd;
  J22 =  L_act*cos(phi1)*sin(phi2 - q1)/sin_pd;

  // === Inverse Kinematics (constrained, elbow-down config) ===
  d1_ik = sqrt((Pdx - A1x)^2 + (Pdy - A1y)^2);
  d2_ik = sqrt((Pdx - A2x)^2 + (Pdy - A2y)^2);

  cos_beta1 = max(-1.0, min(1.0, (d1_ik^2 - L_act^2 - L_pas^2) / (2.0*L_act*L_pas)));
  cos_beta2 = max(-1.0, min(1.0, (d2_ik^2 - L_act^2 - L_pas^2) / (2.0*L_act*L_pas)));

  // Left chain: positive relative elbow angle; right chain: mirrored negative
  beta1_ik = acos(cos_beta1);
  beta2_ik = -acos(cos_beta2);

  // Clip to joint travel limits
  q1_des = max(q_min, min(q_max,
             atan2(Pdy - A1y, Pdx - A1x)
             - atan2(L_pas*sin(beta1_ik), L_act + L_pas*cos(beta1_ik))));
  q2_des = max(q_min, min(q_max,
             atan2(Pdy - A2y, Pdx - A2x)
             - atan2(L_pas*sin(beta2_ik), L_act + L_pas*cos(beta2_ik))));

  // === Sampled Controller (100 Hz zero-order hold) ===
  // PD with gravity compensation (payload + link weight)
  when sample(0, dt_ctrl) then
    tau1_cmd = Kp*(q1_des - q1) - Kd*dq1
               - J21*m_payload*g + m_link*g*(L_act/2.0)*cos(q1);
    tau2_cmd = Kp*(q2_des - q2) - Kd*dq2
               - J22*m_payload*g + m_link*g*(L_act/2.0)*cos(q2);
  end when;

  // Torque saturation (actuator force bound)
  tau1_sat = if tau1_cmd > tau_max then tau_max
             else if tau1_cmd < -tau_max then -tau_max
             else tau1_cmd;
  tau2_sat = if tau2_cmd > tau_max then tau_max
             else if tau2_cmd < -tau_max then -tau_max
             else tau2_cmd;

  // === End-point Force ===
  F_end_x = F_dist_x;
  F_end_y = -m_payload*g + F_dist_y;

  // Reflected load torques via Jacobian transpose
  tau_load1 = J11*F_end_x + J21*F_end_y;
  tau_load2 = J12*F_end_x + J22*F_end_y;

  // === Dynamics ===
  der(q1) = dq1;
  der(q2) = dq2;
  der(dq1) = (tau1_sat - b_damp*dq1 - tau_load1
              - m_link*g*(L_act/2.0)*cos(q1)) / I_eff;
  der(dq2) = (tau2_sat - b_damp*dq2 - tau_load2
              - m_link*g*(L_act/2.0)*cos(q2)) / I_eff;
  ddq1 = der(dq1);
  ddq2 = der(dq2);

  // === Joint Tracking Errors ===
  q1_err = q1_des - q1;
  q2_err = q2_des - q2;

  // === Reaction Forces at Base Pivots ===
  sin_pq1 = sin(phi1 - q1);
  sin_pq1_safe = if noEvent(sin_pq1 > 0) then max(sin_pq1, 1e-3)
                 else min(sin_pq1, -1e-3);
  sin_pq2 = sin(phi2 - q2);
  sin_pq2_safe = if noEvent(sin_pq2 > 0) then max(sin_pq2, 1e-3)
                 else min(sin_pq2, -1e-3);

  // Passive-link axial force from actuated-link torque equilibrium
  F_pas1 = tau_load1 / (L_act * sin_pq1_safe);
  F_pas2 = tau_load2 / (L_act * sin_pq2_safe);

  // Link center-of-mass accelerations
  a_cm1x = -(L_act/2.0)*(ddq1*sin(q1) + dq1^2*cos(q1));
  a_cm1y =  (L_act/2.0)*(ddq1*cos(q1) - dq1^2*sin(q1));
  a_cm2x = -(L_act/2.0)*(ddq2*sin(q2) + dq2^2*cos(q2));
  a_cm2y =  (L_act/2.0)*(ddq2*cos(q2) - dq2^2*sin(q2));

  // Newton's second law on each actuated link
  R1x = m_link*a_cm1x - F_pas1*cos(phi1);
  R1y = m_link*a_cm1y - F_pas1*sin(phi1) + m_link*g;
  R2x = m_link*a_cm2x - F_pas2*cos(phi2);
  R2y = m_link*a_cm2y - F_pas2*sin(phi2) + m_link*g;

  // === Pose Error ===
  pose_err = sqrt((Px - Pdx)^2 + (Py - Pdy)^2);

  // === Self-Collision Checks (segment intersection tests) ===
  // Pair 1: left actuated (A1-B1) vs right actuated (A2-B2)
  cr_a1 = (B1x-A1x)*(A2y-A1y) - (B1y-A1y)*(A2x-A1x);
  cr_a2 = (B1x-A1x)*(B2y-A1y) - (B1y-A1y)*(B2x-A1x);
  cr_a3 = (B2x-A2x)*(A1y-A2y) - (B2y-A2y)*(A1x-A2x);
  cr_a4 = (B2x-A2x)*(B1y-A2y) - (B2y-A2y)*(B1x-A2x);
  coll_a = (cr_a1*cr_a2 < 0) and (cr_a3*cr_a4 < 0);

  // Pair 2: left actuated (A1-B1) vs right passive (B2-P)
  cr_b1 = (B1x-A1x)*(B2y-A1y) - (B1y-A1y)*(B2x-A1x);
  cr_b2 = (B1x-A1x)*(Py -A1y) - (B1y-A1y)*(Px -A1x);
  cr_b3 = (Px -B2x)*(A1y-B2y) - (Py -B2y)*(A1x-B2x);
  cr_b4 = (Px -B2x)*(B1y-B2y) - (Py -B2y)*(B1x-B2x);
  coll_b = (cr_b1*cr_b2 < 0) and (cr_b3*cr_b4 < 0);

  // Pair 3: right actuated (A2-B2) vs left passive (B1-P)
  cr_c1 = (B2x-A2x)*(B1y-A2y) - (B2y-A2y)*(B1x-A2x);
  cr_c2 = (B2x-A2x)*(Py -A2y) - (B2y-A2y)*(Px -A2x);
  cr_c3 = (Px -B1x)*(A2y-B1y) - (Py -B1y)*(A2x-B1x);
  cr_c4 = (Px -B1x)*(B2y-B1y) - (Py -B1y)*(B2x-B1x);
  coll_c = (cr_c1*cr_c2 < 0) and (cr_c3*cr_c4 < 0);

  collision = coll_a or coll_b or coll_c;

  // === Bounds and Requirement Checks ===
  travel_ok = (q1 >= q_min) and (q1 <= q_max)
              and (q2 >= q_min) and (q2 <= q_max);
  force_ok  = (abs(tau1_sat) <= tau_max + 1e-6)
              and (abs(tau2_sat) <= tau_max + 1e-6);
  pose_ok   = if time >= t_thresh then (pose_err < pose_thresh) else true;
  no_nan_inf = noEvent(abs(q1) < 1e10) and noEvent(abs(q2) < 1e10)
               and noEvent(abs(Px) < 1e10) and noEvent(abs(Py) < 1e10)
               and noEvent(abs(tau1_sat) < 1e10) and noEvent(abs(tau2_sat) < 1e10)
               and noEvent(abs(dq1) < 1e10) and noEvent(abs(dq2) < 1e10);
  all_ok = travel_ok and force_ok and pose_ok and no_nan_inf and (not collision);

end FiveBarPositionB;