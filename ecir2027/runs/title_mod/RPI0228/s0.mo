model AssemblyArmTraceF
  // ===== Timing =====
  parameter Real Ts = 0.002 "Control loop period (500 Hz)";
  parameter Real Tend = 20.0 "Mission duration (s)";
  parameter Real tA = 0.0 "s";
  parameter Real tB = 10.0 "s";
  parameter Real tC = 20.0 "s";

  // ===== Embodiment: fixed-base 4-DoF (Z,Y,Y,X) articulated manipulator =====
  parameter Real L1 = 0.50 "m";
  parameter Real L2 = 0.40 "m";
  parameter Real L3 = 0.28 "m";
  parameter Real L4 = 0.16 "m";
  parameter Real m1 = 7.0 "kg";
  parameter Real m2 = 5.0 "kg";
  parameter Real m3 = 3.0 "kg";
  parameter Real m4 = 1.0 "kg";
  // Inertias and damping not specified in requirement; chosen for stable, well-posed dynamics
  parameter Real J1 = 0.60 "kg.m2";
  parameter Real J2 = 0.40 "kg.m2";
  parameter Real J3 = 0.15 "kg.m2";
  parameter Real J4 = 0.03 "kg.m2";
  parameter Real b1 = 0.60 "N.m.s/rad";
  parameter Real b2 = 0.50 "N.m.s/rad";
  parameter Real b3 = 0.40 "N.m.s/rad";
  parameter Real b4 = 0.30 "N.m.s/rad";

  // ===== Actuation: saturated effort drives =====
  parameter Real tauMax = 134.0 "N.m";

  // ===== Joint limits =====
  parameter Real q1min = -3.14 "rad"; parameter Real q1max = 3.14 "rad";
  parameter Real q2min = -1.57 "rad"; parameter Real q2max = 1.57 "rad";
  parameter Real q3min = -1.57 "rad"; parameter Real q3max = 1.57 "rad";
  parameter Real q4min = -3.14 "rad"; parameter Real q4max = 3.14 "rad";

  // ===== Waypoints: three reachable states =====
  parameter Real qw1_1 = 0.0; parameter Real qw1_2 = 0.0; parameter Real qw1_3 = 0.0; parameter Real qw1_4 = 0.0;
  parameter Real qw2_1 = 0.5; parameter Real qw2_2 = 0.3; parameter Real qw2_3 = -0.2; parameter Real qw2_4 = 0.4;
  parameter Real qw3_1 = 0.8; parameter Real qw3_2 = 0.6; parameter Real qw3_3 = -0.4; parameter Real qw3_4 = 0.7;

  // ===== Control gains: PID + velocity-feedforward =====
  parameter Real Kp1 = 300.0; parameter Real Ki1 = 30.0; parameter Real Kd1 = 24.0; parameter Real Kvff1 = 0.6;
  parameter Real Kp2 = 100.0; parameter Real Ki2 = 8.0;  parameter Real Kd2 = 11.0; parameter Real Kvff2 = 0.5;
  parameter Real Kp3 = 40.0;  parameter Real Ki3 = 3.0;  parameter Real Kd3 = 4.0;  parameter Real Kvff3 = 0.4;
  parameter Real Kp4 = 15.0;  parameter Real Ki4 = 1.0;  parameter Real Kd4 = 0.9;  parameter Real Kvff4 = 0.3;
  parameter Real intMax = 2.0 "Integrator clamp magnitude (basic anti-windup)";

  // ===== Cylindrical keep-out obstacle placed beside (not on) nominal path =====
  parameter Real ox = 0.60 "m";
  parameter Real oy = 0.00 "m";
  parameter Real oz = 0.40 "m";
  parameter Real oR = 0.10 "m";
  parameter Real clearanceMin = 0.05 "m";

  // ===== Lateral disturbance =====
  parameter Real Fdist = 14.5 "N";

  // ===== Joint state variables =====
  Real q1(start=0.0), q2(start=0.0), q3(start=0.0), q4(start=0.0);
  Real qd1(start=0.0), qd2(start=0.0), qd3(start=0.0), qd4(start=0.0);
  Real qdd1, qdd2, qdd3, qdd4;

  // ===== Trajectory (cubic Hermite through three waypoints) =====
  Real s1c, s2c;
  Real qdes1, qdes2, qdes3, qdes4;
  Real qddes1, qddes2, qddes3, qddes4;

  // ===== Continuous tracking error (monitoring) =====
  Real err1, err2, err3, err4;
  Real errNorm;

  // ===== Discrete controller (500 Hz) =====
  Real e1, e2, e3, e4;
  Real int_e1(start=0.0), int_e2(start=0.0), int_e3(start=0.0), int_e4(start=0.0);
  Real tau1_raw, tau2_raw, tau3_raw, tau4_raw;
  Real tau1(start=0.0), tau2(start=0.0), tau3(start=0.0), tau4(start=0.0);

  // ===== Synchronized encoder observations =====
  Real q1_enc, q2_enc, q3_enc, q4_enc;
  Real qd1_enc, qd2_enc, qd3_enc, qd4_enc;

  // ===== Forward kinematics =====
  Real r_arm, z_ee, x_ee, y_ee;
  Real dist_obs, clearance;

  // ===== Disturbance =====
  Real distActive, tau_d1;

  // ===== Verification observables =====
  Real q1limOK, q2limOK, q3limOK, q4limOK;
  Real clearanceOK, errOK;
  Real peakB1(start=0.0), peakB2(start=0.0), peakB3(start=0.0), peakB4(start=0.0);
  Real overshoot1, overshoot2, overshoot3, overshoot4;
  Real os12, os123, os1234, overshootOK;

equation
  // ----- Cubic Hermite trajectory through three waypoints (zero endpoint velocities) -----
  s1c = max(0.0, min(1.0, (time - tA)/(tB - tA)));
  s2c = max(0.0, min(1.0, (time - tB)/(tC - tB)));

  qdes1 = if time < tB then (2*s1c^3 - 3*s1c^2 + 1)*qw1_1 + (-2*s1c^3 + 3*s1c^2)*qw2_1
                          else (2*s2c^3 - 3*s2c^2 + 1)*qw2_1 + (-2*s2c^3 + 3*s2c^2)*qw3_1;
  qdes2 = if time < tB then (2*s1c^3 - 3*s1c^2 + 1)*qw1_2 + (-2*s1c^3 + 3*s1c^2)*qw2_2
                          else (2*s2c^3 - 3*s2c^2 + 1)*qw2_2 + (-2*s2c^3 + 3*s2c^2)*qw3_2;
  qdes3 = if time < tB then (2*s1c^3 - 3*s1c^2 + 1)*qw1_3 + (-2*s1c^3 + 3*s1c^2)*qw2_3
                          else (2*s2c^3 - 3*s2c^2 + 1)*qw2_3 + (-2*s2c^3 + 3*s2c^2)*qw3_3;
  qdes4 = if time < tB then (2*s1c^3 - 3*s1c^2 + 1)*qw1_4 + (-2*s1c^3 + 3*s1c^2)*qw2_4
                          else (2*s2c^3 - 3*s2c^2 + 1)*qw2_4 + (-2*s2c^3 + 3*s2c^2)*qw3_4;

  qddes1 = if time < tB then (6*s1c*(1-s1c)/(tB-tA))*(qw2_1 - qw1_1)
                       else (6*s2c*(1-s2c)/(tC-tB))*(qw3_1 - qw2_1);
  qddes2 = if time < tB then (6*s1c*(1-s1c)/(tB-tA))*(qw2_2 - qw1_2)
                       else (6*s2c*(1-s2c)/(tC-tB))*(qw3_2 - qw2_2);
  qddes3 = if time < tB then (6*s1c*(1-s1c)/(tB-tA))*(qw2_3 - qw1_3)
                       else (6*s2c*(1-s2c)/(tC-tB))*(qw3_3 - qw2_3);
  qddes4 = if time < tB then (6*s1c*(1-s1c)/(tB-tA))*(qw2_4 - qw1_4)
                       else (6*s2c*(1-s2c)/(tC-tB))*(qw3_4 - qw2_4);

  // ----- Continuous tracking error (state trace) -----
  err1 = qdes1 - q1;
  err2 = qdes2 - q2;
  err3 = qdes3 - q3;
  err4 = qdes4 - q4;
  errNorm = sqrt(err1*err1 + err2*err2 + err3*err3 + err4*err4 + 1e-12);

  // ----- Discrete PID + velocity-feedforward controller at 500 Hz (command trace) -----
  when sample(0, Ts) then
    e1 = qdes1 - q1;
    e2 = qdes2 - q2;
    e3 = qdes3 - q3;
    e4 = qdes4 - q4;

    int_e1 = max(-intMax, min(intMax, pre(int_e1) + Ts*e1));
    int_e2 = max(-intMax, min(intMax, pre(int_e2) + Ts*e2));
    int_e3 = max(-intMax, min(intMax, pre(int_e3) + Ts*e3));
    int_e4 = max(-intMax, min(intMax, pre(int_e4) + Ts*e4));

    tau1_raw = Kp1*e1 + Ki1*int_e1 + Kd1*(qddes1 - qd1) + Kvff1*qddes1;
    tau2_raw = Kp2*e2 + Ki2*int_e2 + Kd2*(qddes2 - qd2) + Kvff2*qddes2;
    tau3_raw = Kp3*e3 + Ki3*int_e3 + Kd3*(qddes3 - qd3) + Kvff3*qddes3;
    tau4_raw = Kp4*e4 + Ki4*int_e4 + Kd4*(qddes4 - qd4) + Kvff4*qddes4;

    tau1 = max(-tauMax, min(tauMax, tau1_raw));
    tau2 = max(-tauMax, min(tauMax, tau2_raw));
    tau3 = max(-tauMax, min(tauMax, tau3_raw));
    tau4 = max(-tauMax, min(tauMax, tau4_raw));

    // Peak tracking during second transition (segment B), proxy for overshoot
    peakB1 = if time >= tB then max(pre(peakB1), abs(e1)) else 0.0;
    peakB2 = if time >= tB then max(pre(peakB2), abs(e2)) else 0.0;
    peakB3 = if time >= tB then max(pre(peakB3), abs(e3)) else 0.0;
    peakB4 = if time >= tB then max(pre(peakB4), abs(e4)) else 0.0;
  end when;

  // ----- Plant dynamics (per-joint inertia with viscous damping) -----
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  der(q4) = qd4;
  der(qd1) = qdd1;
  der(qd2) = qdd2;
  der(qd3) = qdd3;
  der(qd4) = qdd4;
  J1*qdd1 = tau1 - b1*qd1 + tau_d1;
  J2*qdd2 = tau2 - b2*qd2;
  J3*qdd3 = tau3 - b3*qd3;
  J4*qdd4 = tau4 - b4*qd4;

  // ----- Forward kinematics (Z-Y-Y-X chain; wrist roll does not translate tip) -----
  r_arm = L2*cos(q2) + (L3 + L4)*cos(q2 + q3);
  z_ee = L1 + L2*sin(q2) + (L3 + L4)*sin(q2 + q3);
  x_ee = r_arm*cos(q1);
  y_ee = r_arm*sin(q1);

  // ----- Obstacle clearance (cylindrical keep-out) -----
  dist_obs = sqrt((x_ee - ox)*(x_ee - ox) + (y_ee - oy)*(y_ee - oy) + (z_ee - oz)*(z_ee - oz) + 1e-12);
  clearance = dist_obs - oR;

  // ----- Lateral disturbance (force in +y => moment about Z = x_ee*F) during middle third -----
  distActive = if time >= Tend/3.0 and time <= 2.0*Tend/3.0 then 1.0 else 0.0;
  tau_d1 = x_ee * Fdist * distActive;

  // ----- Encoder observations (ideal, synchronized with control loop) -----
  q1_enc = q1;  q2_enc = q2;  q3_enc = q3;  q4_enc = q4;
  qd1_enc = qd1; qd2_enc = qd2; qd3_enc = qd3; qd4_enc = qd4;

  // ----- Verification observables -----
  q1limOK = if q1 >= q1min and q1 <= q1max then 1.0 else 0.0;
  q2limOK = if q2 >= q2min and q2 <= q2max then 1.0 else 0.0;
  q3limOK = if q3 >= q3min and q3 <= q3max then 1.0 else 0.0;
  q4limOK = if q4 >= q4min and q4 <= q4max then 1.0 else 0.0;
  clearanceOK = if clearance > clearanceMin then 1.0 else 0.0;
  errOK = if time < 13.0 or errNorm < 0.04 then 1.0 else 0.0;

  overshoot1 = peakB1 / max(abs(qw3_1 - qw2_1), 0.01);
  overshoot2 = peakB2 / max(abs(qw3_2 - qw2_2), 0.01);
  overshoot3 = peakB3 / max(abs(qw3_3 - qw2_3), 0.01);
  overshoot4 = peakB4 / max(abs(qw3_4 - qw2_4), 0.01);
  os12 = if overshoot1 > overshoot2 then overshoot1 else overshoot2;
  os123 = if os12 > overshoot3 then os12 else overshoot3;
  os1234 = if os123 > overshoot4 then os123 else overshoot4;
  overshootOK = if os1234 < 0.12 then 1.0 else 0.0;

  // ----- Verification assertions -----
  assert(q1 >= q1min and q1 <= q1max, "Joint 1 limit violated");
  assert(q2 >= q2min and q2 <= q2max, "Joint 2 limit violated");
  assert(q3 >= q3min and q3 <= q3max, "Joint 3 limit violated");
  assert(q4 >= q4min and q4 <= q4max, "Joint 4 limit violated");
  assert(clearance > clearanceMin, "Obstacle clearance below 0.05 m");
  assert(time < 13.0 or errNorm < 0.04, "Primary tracking error exceeds 0.04 rad-or-m after 13 s");
  assert(time < tC - 0.01 or overshootOK > 0.5, "Overshoot exceeds 12 percent");
  // NaN/Infinity: dynamics are well-posed with bounded inputs and finite non-singular
  // initial conditions; finite-valued physical, control, and estimator variables are
  // assumed. No explicit isnan/isinf intrinsic is portable across OpenModelica targets.

  annotation(
    experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "AssemblyArmTraceF: fixed-base 4-DoF (Z,Y,Y,X) articulated manipulator following a cubic Hermite joint trajectory through three reachable states with saturated PID + velocity-feedforward control, synchronized encoder observation, a 14.5 N lateral disturbance during the middle third, and verification of joint limits, obstacle clearance (>0.05 m), overshoot (<12 percent), and terminal tracking error (<0.04 rad-or-m after 13 s) at 500 Hz over 20 s."));
end AssemblyArmTraceF;