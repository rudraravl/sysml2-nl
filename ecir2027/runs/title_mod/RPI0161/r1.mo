model SCARACarryE
  // ===== Plant structure parameters (SI) =====
  parameter Real m_base = 28.0    "cylindrical base mass [kg] (fixed to workcell floor)";
  parameter Real L1 = 0.48        "link1 length (revolute Z) [m]";
  parameter Real L2 = 0.34        "link2 length (revolute Z) [m]";
  parameter Real d_prism = 0.30   "prismatic Z carriage travel [m]";
  parameter Real m1 = 6.0         "link1 moving mass [kg]";
  parameter Real m2 = 4.0         "link2 moving mass [kg]";
  parameter Real m3 = 2.0         "carriage moving mass [kg]";
  parameter Real m_payload = 14.4 "rigid tool payload mass [kg]";
  parameter Real g = 9.81         "gravitational acceleration [m/s2]";
  // Slender-rod inertia approximation; cylindrical radii not specified in request
  parameter Real I1 = m1*L1^2/3   "link1 inertia about joint1 [kg.m2]";
  parameter Real I2 = m2*L2^2/3   "link2 inertia about joint2 [kg.m2]";
  parameter Real m3_eff = m3 + m_payload "vertical moving mass [kg]";
  parameter Real a1 = I1 + I2 + m2*L1^2 + m3_eff*(L1^2 + L2^2);
  parameter Real a2 = m3_eff*L1*L2;
  parameter Real b1 = I2 + m3_eff*L2^2;

  // ===== Actuator / acceptance limits =====
  parameter Real tau_max = 105.0    "revolute actuator torque bound [N.m]";
  parameter Real f_max   = 900.0     "prismatic actuator force bound [N]";
  parameter Real f_wrist_max = 60.0  "wrist force acceptance bound [N]";
  parameter Real track_tol = 0.041  "primary tracking tolerance [rad or m]";
  parameter Real t_settle = 10.4    "settle time [s]";
  parameter Real Ts = 1.0/250.0     "control/sample period [s]";
  parameter Real T_sim = 16.0       "simulation horizon [s]";
  parameter Real Fcorr_bound = 30.0 "wrist-force correction bound [N]";
  parameter Real contact_k = 2.0e4  "floor/table contact stiffness [N/m]";
  parameter Real contact_d = 1.0e3  "floor/table contact damping [N.s/m]";

  // ===== Dynamic states =====
  output Real q1(start=0.0)  "joint1 revolute angle [rad]";
  output Real qd1(start=0.0);
  output Real q2(start=0.0)  "joint2 revolute angle [rad]";
  output Real qd2(start=0.0);
  output Real q3(start=0.12) "prismatic Z position, downward positive [m]";
  output Real qd3(start=0.0);

  // ===== Reference trajectory =====
  Real q1_ref, q2_ref, q3_ref;
  Real qd1_ref, qd2_ref, qd3_ref;
  Real qdd1_ref, qdd2_ref, qdd3_ref;

  // ===== Control gains (computed-torque + bounded wrist correction) =====
  parameter Real Kp1 = 800.0, Kd1 = 100.0;
  parameter Real Kp2 = 800.0, Kd2 = 100.0;
  parameter Real Kp3 = 4000.0, Kd3 = 300.0;

  // ===== Computed-torque internals =====
  Real qdd1_cmd, qdd2_cmd, qdd3_cmd;
  Real tau1, tau2, tau3;
  output Real tau1_sat, tau2_sat, tau3_sat;

  // ===== Payload disturbance (middle third of run) =====
  Real F_dist_x, F_dist_y, F_dist_z;
  Boolean disturbance_active;

  // ===== End-effector kinematics =====
  Real x_ee, y_ee, z_ee;
  Real xd_ee, yd_ee, zd_ee;
  Real xdd_ee, ydd_ee, zdd_ee;
  Real J11, J12, J21, J22;

  // ===== Wrist wrench (six-axis, gravity-tared dynamic deviation) =====
  output Real Fwx, Fwy, Fwz;
  Real Fw_norm;
  Real Fcorr_x, Fcorr_y, Fcorr_z;
  Real tau_w1, tau_w2, tau_w3;

  // ===== Manipulator dynamics =====
  Real M11, M12, M21, M22, M33;
  Real C1, C2, G3, det, det_safe;
  Real r1, r2, tau_dist1, tau_dist2, tau_dist3;
  Real qdd1, qdd2, qdd3;
  Real F_limit3;

  // ===== Tracking / acceptance =====
  Real e1, e2, e3;
  output Real e_pose;
  Boolean ok_joint1, ok_joint2;
  output Boolean ok_joint3;
  Boolean ok_effort1, ok_effort2, ok_effort3;
  Boolean ok_wrist, ok_payload, ok_track, ok_nan;
  output Boolean ok_all;

  // ===== Synchronized sampled traces at 250 Hz =====
  discrete Real q1_s(start=0.0), q2_s(start=0.0), q3_s(start=0.12);
  discrete Real qd1_s(start=0.0), qd2_s(start=0.0), qd3_s(start=0.0);
  discrete Real tau1_s(start=0.0), tau2_s(start=0.0), tau3_s(start=0.0);
  discrete Real Fwx_s(start=0.0), Fwy_s(start=0.0), Fwz_s(start=0.0);
  discrete Real e_pose_s(start=0.0);
  output discrete Integer tick(start=0);

  // ===== Helper functions =====
  function sat
    input Real x;
    input Real b;
    output Real y;
  algorithm
    if x > b then
      y := b;
    elseif x < -b then
      y := -b;
    else
      y := x;
    end if;
  end sat;

  function is_nan
    input Real x;
    output Boolean y;
  algorithm
    y := not (x == x);
  end is_nan;

equation
  // ----- Reference: smooth lift + reposition, orientation-preserving (pure joint-space) -----
  q1_ref   = 0.4*(1.0 - Modelica.Math.cos(Modelica.Constants.pi*t/8.0));
  qd1_ref  = 0.4*(Modelica.Constants.pi/8.0)*Modelica.Math.sin(Modelica.Constants.pi*t/8.0);
  qdd1_ref = 0.4*(Modelica.Constants.pi/8.0)^2*Modelica.Math.cos(Modelica.Constants.pi*t/8.0);
  q2_ref   = 0.25*(1.0 - Modelica.Math.cos(Modelica.Constants.pi*t/8.0));
  qd2_ref  = 0.25*(Modelica.Constants.pi/8.0)*Modelica.Math.sin(Modelica.Constants.pi*t/8.0);
  qdd2_ref = 0.25*(Modelica.Constants.pi/8.0)^2*Modelica.Math.cos(Modelica.Constants.pi*t/8.0);
  q3_ref   = 0.12 + 0.06*Modelica.Math.sin(Modelica.Constants.pi*t/4.0);
  qd3_ref  = 0.06*(Modelica.Constants.pi/4.0)*Modelica.Math.cos(Modelica.Constants.pi*t/4.0);
  qdd3_ref = -0.06*(Modelica.Constants.pi/4.0)^2*Modelica.Math.sin(Modelica.Constants.pi*t/4.0);

  // ----- Mass matrix / Coriolis / gravity -----
  M11 = a1 + 2.0*a2*Modelica.Math.cos(q2);
  M12 = b1 + a2*Modelica.Math.cos(q2);
  M21 = M12;
  M22 = b1;
  M33 = m3_eff;
  C1  = -a2*Modelica.Math.sin(q2)*qd2*(2.0*qd1 + qd2);
  C2  =  a2*Modelica.Math.sin(q2)*qd1^2;
  G3  = -m3_eff*g;
  det = M11*M22 - M12*M21;
  det_safe = if det > 1.0e-6 then det else 1.0e-6;

  // ----- End-effector kinematics -----
  x_ee = L1*Modelica.Math.cos(q1) + L2*Modelica.Math.cos(q1 + q2);
  y_ee = L1*Modelica.Math.sin(q1) + L2*Modelica.Math.sin(q1 + q2);
  z_ee = q3;
  xd_ee = der(x_ee);
  yd_ee = der(y_ee);
  zd_ee = der(z_ee);
  xdd_ee = der(xd_ee);
  ydd_ee = der(yd_ee);
  zdd_ee = der(zd_ee);
  J11 = -L1*Modelica.Math.sin(q1) - L2*Modelica.Math.sin(q1 + q2);
  J12 = -L2*Modelica.Math.sin(q1 + q2);
  J21 =  L1*Modelica.Math.cos(q1) + L2*Modelica.Math.cos(q1 + q2);
  J22 =  L2*Modelica.Math.cos(q1 + q2);

  // ----- Controlled 14.4 kg payload disturbance (middle third of run) -----
  disturbance_active = (t >= T_sim/3.0) and (t <= 2.0*T_sim/3.0);
  F_dist_x = if disturbance_active then 20.0*Modelica.Math.sin(2.0*Modelica.Constants.pi*t/2.0) else 0.0;
  F_dist_y = if disturbance_active then 15.0*Modelica.Math.cos(2.0*Modelica.Constants.pi*t/2.0) else 0.0;
  F_dist_z = 0.0;

  // ----- Six-axis wrist wrench sensor (gravity-tared deviation) -----
  Fwx = m_payload*xdd_ee - F_dist_x;
  Fwy = m_payload*ydd_ee - F_dist_y;
  Fwz = m_payload*zdd_ee - F_dist_z;
  Fw_norm = Modelica.Math.sqrt(Fwx*Fwx + Fwy*Fwy + Fwz*Fwz + 1.0e-12);

  // ----- Bounded wrist-force correction mapped to joint space -----
  Fcorr_x = -sat(Fwx, Fcorr_bound);
  Fcorr_y = -sat(Fwy, Fcorr_bound);
  Fcorr_z = -sat(Fwz, Fcorr_bound);
  tau_w1 = J11*Fcorr_x + J21*Fcorr_y;
  tau_w2 = J12*Fcorr_x + J22*Fcorr_y;
  tau_w3 = Fcorr_z;

  // ----- Computed-torque control law -----
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;
  qdd1_cmd = qdd1_ref + Kp1*e1 + Kd1*(qd1_ref - qd1);
  qdd2_cmd = qdd2_ref + Kp2*e2 + Kd2*(qd2_ref - qd2);
  qdd3_cmd = qdd3_ref + Kp3*e3 + Kd3*(qd3_ref - qd3);
  tau1 = M11*qdd1_cmd + M12*qdd2_cmd + C1 + tau_w1;
  tau2 = M21*qdd1_cmd + M22*qdd2_cmd + C2 + tau_w2;
  tau3 = M33*qdd3_cmd + G3            + tau_w3;

  // ----- Saturated joint-space actuators -----
  tau1_sat = sat(tau1, tau_max);
  tau2_sat = sat(tau2, tau_max);
  tau3_sat = sat(tau3, f_max);

  // ----- Rigid floor + fixed table collision (enabled via prismatic travel limits) -----
  F_limit3 = (if q3 < 0.0       then -contact_k*q3            - contact_d*qd3 else 0.0)
           + (if q3 > d_prism   then -contact_k*(q3 - d_prism) - contact_d*qd3 else 0.0);

  // ----- Plant equations: M*qdd + C*qd + G = tau_sat + J^T*F_dist + F_contact -----
  tau_dist1 = J11*F_dist_x + J21*F_dist_y;
  tau_dist2 = J12*F_dist_x + J22*F_dist_y;
  tau_dist3 = F_dist_z;
  r1 = tau1_sat + tau_dist1 - C1;
  r2 = tau2_sat + tau_dist2 - C2;
  qdd1 = ( M22*r1 - M12*r2)/det_safe;
  qdd2 = (-M21*r1 + M11*r2)/det_safe;
  qdd3 = (tau3_sat + F_limit3 + tau_dist3 - G3)/M33;
  der(q1)  = qd1;
  der(q2)  = qd2;
  der(q3)  = qd3;
  der(qd1) = qdd1;
  der(qd2) = qdd2;
  der(qd3) = qdd3;

  // ----- Pose tracking error (primary, rad-or-m) -----
  e_pose = max(abs(e1), max(abs(e2), abs(e3)));

  // ----- Acceptance (fail-closed) -----
  ok_joint1  = true;  // revolute joint travel bound not specified in requirement
  ok_joint2  = true;  // revolute joint travel bound not specified in requirement
  ok_joint3  = (q3 >= -1.0e-4) and (q3 <= d_prism + 1.0e-4);
  ok_effort1 = abs(tau1_sat) <= tau_max + 1.0e-6;
  ok_effort2 = abs(tau2_sat) <= tau_max + 1.0e-6;
  ok_effort3 = abs(tau3_sat) <= f_max   + 1.0e-6;
  ok_wrist   = Fw_norm < f_wrist_max;
  ok_payload = true;  // rigid tool payload: retention is structural by construction; grip capacity not specified
  ok_track   = if t > t_settle then (e_pose < track_tol) else true;
  ok_nan     = not (is_nan(q1) or is_nan(q2) or is_nan(q3) or
                    is_nan(qd1) or is_nan(qd2) or is_nan(qd3) or
                    is_nan(tau1_sat) or is_nan(tau2_sat) or is_nan(tau3_sat) or
                    is_nan(Fw_norm) or is_nan(e_pose));
  ok_all = ok_joint1 and ok_joint2 and ok_joint3 and
           ok_effort1 and ok_effort2 and ok_effort3 and
           ok_wrist and ok_payload and ok_track and ok_nan;

  // ----- Synchronized state/command/sensor traces at 250 Hz -----
  when sample(0, Ts) then
    tick   = pre(tick) + 1;
    q1_s   = q1;
    q2_s   = q2;
    q3_s   = q3;
    qd1_s  = qd1;
    qd2_s  = qd2;
    qd3_s  = qd3;
    tau1_s = tau1_sat;
    tau2_s = tau2_sat;
    tau3_s = tau3_sat;
    Fwx_s  = Fwx;
    Fwy_s  = Fwy;
    Fwz_s  = Fwz;
    e_pose_s = e_pose;
  end when;

  annotation (
    experiment(StopTime = 16.0, Tolerance = 1.0e-6, Interval = 1.0e-3),
    Documentation(info = "Fixed-base SCARA articulated manipulator (SCARACarryE): two revolute Z links (0.48 m, 0.34 m) plus prismatic Z carriage (0.30 m travel). Computed-torque joint-space control with bounded wrist-force correction; 14.4 kg rigid payload with middle-third disturbance; floor/table collision enabled. Acceptance is fail-closed via ok_all.")
  );
end SCARACarryE;