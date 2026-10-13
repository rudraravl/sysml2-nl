model DuoArmRejectD
  // ------------------------------------------------------------------
  // Physical parameters (SI units)
  // ------------------------------------------------------------------
  parameter Real m_ped = 20.0  "Pedestal mass [kg] (box, fixed base)";
  parameter Real L1 = 0.55    "Link 1 capsule length [m]";
  parameter Real L2 = 0.38    "Link 2 capsule length [m]";
  parameter Real m1 = 5.0     "Link 1 mass [kg]";
  parameter Real m2 = 3.0     "Link 2 mass [kg]";
  parameter Real lc1 = 0.5*L1 "Link 1 CoM offset [m]";
  parameter Real lc2 = 0.5*L2 "Link 2 CoM offset [m]";
  parameter Real I1 = m1*L1^2/12 "Link 1 inertia about CoM [kg.m2]";
  parameter Real I2 = m2*L2^2/12 "Link 2 inertia about CoM [kg.m2]";
  parameter Real g = 9.81    "Gravity magnitude [m/s2]";
  parameter Real q_lim = 1.6  "Joint travel limit [rad]";
  parameter Real tau_max = 70.0 "Joint effort saturation [N.m]";
  parameter Real F_dist = 18.0 "Disturbance load magnitude [N]";
  parameter Real T_sim = 14.0 "Total run time [s]";
  parameter Real Ts = 0.005   "Control / sensor sample period [s] (200 Hz)";

  // NOTE: pedestal geometry (box dimensions/height) is not specified in the
  // request. A compact pedestal height h_ped is assumed solely so that the
  // nonadjacent self-collision element (link2 tip vs pedestal) is well-posed;
  // it never engages during the nominal hold trajectory.
  parameter Real h_ped = 0.10 "Assumed pedestal height [m] (unknown from spec)";

  // Joint-limit soft stop (passive)
  parameter Real k_joint = 5.0e3 "Joint limit stiffness [N.m/rad]";
  parameter Real b_joint = 50.0  "Joint limit damping [N.m.s/rad]";
  parameter Real q_margin = 0.05 "Joint limit activation margin [rad]";

  // Self-collision (link2 tip vs pedestal top)
  parameter Real k_contact = 1.0e5 "Contact stiffness [N/m]";
  parameter Real b_contact = 1.0e3 "Contact damping [N.s/m]";
  parameter Real pen0 = 0.01 "Contact activation margin [m]";

  // ------------------------------------------------------------------
  // Control parameters: saturated state feedback + integral disturbance
  // rejection, with gravity feed-forward.
  // ------------------------------------------------------------------
  parameter Real q1_ref = 0.6 "Joint 1 nonzero target [rad]";
  parameter Real q2_ref = 0.4 "Joint 2 nonzero target [rad]";
  parameter Real Kp1 = 250.0;
  parameter Real Kd1 = 30.0;
  parameter Real Ki1 = 180.0;
  parameter Real Kp2 = 150.0;
  parameter Real Kd2 = 20.0;
  parameter Real Ki2 = 120.0;

  // ------------------------------------------------------------------
  // Continuous states
  // ------------------------------------------------------------------
  Real q1(start=q1_ref, fixed=true) "Joint 1 angle [rad]";
  Real q2(start=q2_ref, fixed=true) "Joint 2 angle [rad]";
  Real dq1(start=0.0, fixed=true) "Joint 1 velocity [rad/s]";
  Real dq2(start=0.0, fixed=true) "Joint 2 velocity [rad/s]";
  Real e_int1(start=0.0, fixed=true) "Integral tracking error 1 [rad.s]";
  Real e_int2(start=0.0, fixed=true) "Integral tracking error 2 [rad.s]";

  // ------------------------------------------------------------------
  // Discrete (sampled at 200 Hz) control and metric traces
  // ------------------------------------------------------------------
  discrete Real tau1_held(start=0.0) "Held joint 1 command [N.m]";
  discrete Real tau2_held(start=0.0) "Held joint 2 command [N.m]";
  discrete Real peak_dev(start=0.0) "Running peak deviation [rad]";

  // ------------------------------------------------------------------
  // Dynamics intermediates
  // ------------------------------------------------------------------
  Real M11, M12, M21, M22, detM, detM_safe;
  Real C1, C2, G1, G2;
  Real ddq1, ddq2;
  Real tau1, tau2;
  Real phi "q1+q2 [rad]";

  // Disturbance
  Boolean dist_active;
  Real Fx_dist "Disturbance force applied at tip in X [N]";
  Real tau_d1, tau_d2;

  // Self-collision
  Real x_tip, z_tip, v_tip_z;
  Real pen;
  Real F_contact_z;
  Real tau_c1, tau_c2;

  // Joint limits
  Real tau_lim1, tau_lim2;

  // Sensors (encoders + wrist wrench)
  Real q1_meas "Encoder joint 1 [rad]";
  Real q2_meas "Encoder joint 2 [rad]";
  Real dq1_meas "Encoder joint 1 velocity [rad/s]";
  Real dq2_meas "Encoder joint 2 velocity [rad/s]";
  Real ax_c2, az_c2;
  Real wrench_Fx "Wrist wrench force X (link1->link2) [N]";
  Real wrench_Fz "Wrist wrench force Z (link1->link2) [N]";
  Real wrench_Ty "Wrist wrench torque Y (actuator) [N.m]";

  // Tracking metrics
  Real e1, e2;

equation
  // Forward kinematics
  phi = q1 + q2;
  x_tip = L1*cos(q1) + L2*cos(phi);
  z_tip = L1*sin(q1) + L2*sin(phi);
  v_tip_z = L1*cos(q1)*dq1 + L2*cos(phi)*(dq1 + dq2);

  // Disturbance window: middle third of T_sim
  dist_active = (time >= T_sim/3.0) and (time < 2.0*T_sim/3.0);
  Fx_dist = if dist_active then F_dist else 0.0;

  // Disturbance joint torques (J^T * [Fx_dist; 0])
  tau_d1 = (-L1*sin(q1) - L2*sin(phi)) * Fx_dist;
  tau_d2 = (-L2*sin(phi)) * Fx_dist;

  // Self-collision (link2 tip vs pedestal): nonadjacent link pair
  pen = max(0.0, (h_ped + pen0) - z_tip);
  F_contact_z = if pen > 0.0 then (k_contact*pen + b_contact*max(0.0, -v_tip_z)) else 0.0;
  tau_c1 = (L1*cos(q1) + L2*cos(phi)) * F_contact_z;
  tau_c2 = (L2*cos(phi)) * F_contact_z;

  // Joint-limit soft stops (passive)
  tau_lim1 = if (q1 > (q_lim - q_margin)) then
               (-k_joint*(q1 - (q_lim - q_margin)) - b_joint*max(0.0, dq1))
             else if (q1 < (-q_lim + q_margin)) then
               (-k_joint*(q1 - (-q_lim + q_margin)) - b_joint*min(0.0, dq1))
             else 0.0;
  tau_lim2 = if (q2 > (q_lim - q_margin)) then
               (-k_joint*(q2 - (q_lim - q_margin)) - b_joint*max(0.0, dq2))
             else if (q2 < (-q_lim + q_margin)) then
               (-k_joint*(q2 - (-q_lim + q_margin)) - b_joint*min(0.0, dq2))
             else 0.0;

  // Inertia matrix
  M11 = I1 + I2 + m1*lc1^2 + m2*(L1^2 + lc2^2 + 2.0*L1*lc2*cos(q2));
  M12 = I2 + m2*(lc2^2 + L1*lc2*cos(q2));
  M21 = M12;
  M22 = I2 + m2*lc2^2;
  detM = M11*M22 - M12*M21;
  detM_safe = if abs(detM) < 1.0e-9 then 1.0e-9 else detM;

  // Coriolis/centrifugal terms
  C1 = -m2*L1*lc2*sin(q2)*(2.0*dq1*dq2 + dq2^2);
  C2 =  m2*L1*lc2*sin(q2)*dq1^2;

  // Gravity terms (gravity along -Z)
  G1 = (m1*lc1 + m2*L1)*g*cos(q1) + m2*lc2*g*cos(phi);
  G2 = m2*lc2*g*cos(phi);

  // Equations of motion: M ddq + C + G = tau + tau_d + tau_c + tau_lim
  ddq1 = ( M22*(tau1 + tau_d1 + tau_c1 + tau_lim1 - C1 - G1)
          - M12*(tau2 + tau_d2 + tau_c2 + tau_lim2 - C2 - G2) ) / detM_safe;
  ddq2 = ( -M21*(tau1 + tau_d1 + tau_c1 + tau_lim1 - C1 - G1)
          + M11*(tau2 + tau_d2 + tau_c2 + tau_lim2 - C2 - G2) ) / detM_safe;

  der(q1) = dq1;
  der(q2) = dq2;
  der(dq1) = ddq1;
  der(dq2) = ddq2;
  der(e_int1) = q1_ref - q1;
  der(e_int2) = q2_ref - q2;

  // Applied actuator torques equal held (sampled, saturated) commands
  tau1 = tau1_held;
  tau2 = tau2_held;

  // ------------------------------------------------------------------
  // Sampled controller at 200 Hz: saturated state feedback + integral
  // disturbance rejection with gravity feed-forward.
  // ------------------------------------------------------------------
  when sample(0, Ts) then
    tau1_held = if (G1 + Kp1*(q1_ref - q1) - Kd1*dq1 + Ki1*e_int1) > tau_max then tau_max
                else if (G1 + Kp1*(q1_ref - q1) - Kd1*dq1 + Ki1*e_int1) < -tau_max then -tau_max
                else (G1 + Kp1*(q1_ref - q1) - Kd1*dq1 + Ki1*e_int1);
    tau2_held = if (G2 + Kp2*(q2_ref - q2) - Kd2*dq2 + Ki2*e_int2) > tau_max then tau_max
                else if (G2 + Kp2*(q2_ref - q2) - Kd2*dq2 + Ki2*e_int2) < -tau_max then -tau_max
                else (G2 + Kp2*(q2_ref - q2) - Kd2*dq2 + Ki2*e_int2);
    peak_dev = max(pre(peak_dev), max(abs(q1 - q1_ref), abs(q2 - q2_ref)));
  end when;

  // ------------------------------------------------------------------
  // Sensor traces (synchronized with state)
  // ------------------------------------------------------------------
  q1_meas = q1;
  q2_meas = q2;
  dq1_meas = dq1;
  dq2_meas = dq2;

  // Link 2 CoM acceleration for wrist wrench reconstruction
  ax_c2 = -L1*cos(q1)*dq1^2 - L1*sin(q1)*ddq1
          - lc2*cos(phi)*(dq1+dq2)^2 - lc2*sin(phi)*(ddq1+ddq2);
  az_c2 = -L1*sin(q1)*dq1^2 + L1*cos(q1)*ddq1
          - lc2*sin(phi)*(dq1+dq2)^2 + lc2*cos(phi)*(ddq1+ddq2);

  // Wrench exerted by link1 on link2 at wrist joint
  wrench_Fx = m2*ax_c2 - Fx_dist;
  wrench_Fz = m2*az_c2 + m2*g - F_contact_z;
  wrench_Ty = tau2;

  // Primary tracking errors
  e1 = q1 - q1_ref;
  e2 = q2 - q2_ref;

  annotation (
    experiment(StartTime=0, StopTime=14.0, Tolerance=1e-6, Interval=0.005),
    Documentation(info="Instrumented fixed-base 2R articulated manipulator.
      Holds nonzero joint targets while rejecting a finite-duration 18 N
      lateral load applied at the distal link during the middle third.
      Saturated state-feedback control with integral disturbance rejection
      and gravity feed-forward, sampled at 200 Hz. Encoders and wrist wrench
      sensor traces are retained alongside state and command traces."));
end DuoArmRejectD;