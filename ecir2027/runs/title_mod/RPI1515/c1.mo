model SevenPathMoveC
  "Seven-DOF revolute arm with alternating Z/Y axes, capsule links 0.34-0.12 m, 
   cubic interpolation trajectory, PID + velocity feedforward, operational-space 
   and null-space control, 4.5% payload disturbance during middle third, 125 Hz."

  parameter Real Ts = 1.0 / 125.0 "Controller sample period [s]";
  parameter Real t_phase1 = 4.0 "End of phase 1: zero to midpoint [s]";
  parameter Real t_phase2 = 8.0 "End of phase 2: midpoint to final [s]";
  parameter Real t_dist_start = 4.0 "Payload disturbance start [s]";
  parameter Real t_dist_end = 8.0 "Payload disturbance end [s]";

  parameter Real tau_max = 106.0 "Maximum command magnitude [N.m]";
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real pi_val = 3.14159265358979;

  parameter Real L1 = 0.34 "Link 1 length [m]";
  parameter Real L2 = 0.30333 "Link 2 length [m]";
  parameter Real L3 = 0.26667 "Link 3 length [m]";
  parameter Real L4 = 0.23000 "Link 4 length [m]";
  parameter Real L5 = 0.19333 "Link 5 length [m]";
  parameter Real L6 = 0.15667 "Link 6 length [m]";
  parameter Real L7 = 0.12 "Link 7 length [m]";
  parameter Real r_cap = 0.04 "Capsule radius [m]";
  parameter Real rho = 1000.0 "Link density [kg/m3]";

  parameter Real m_link1 = rho*(pi_val*r_cap^2*L1 + (4.0/3.0)*pi_val*r_cap^3);
  parameter Real m_link2 = rho*(pi_val*r_cap^2*L2 + (4.0/3.0)*pi_val*r_cap^3);
  parameter Real m_link3 = rho*(pi_val*r_cap^2*L3 + (4.0/3.0)*pi_val*r_cap^3);
  parameter Real m_link4 = rho*(pi_val*r_cap^2*L4 + (4.0/3.0)*pi_val*r_cap^3);
  parameter Real m_link5 = rho*(pi_val*r_cap^2*L5 + (4.0/3.0)*pi_val*r_cap^3);
  parameter Real m_link6 = rho*(pi_val*r_cap^2*L6 + (4.0/3.0)*pi_val*r_cap^3);
  parameter Real m_link7 = rho*(pi_val*r_cap^2*L7 + (4.0/3.0)*pi_val*r_cap^3);

  parameter Real m_payload_nom = 2.0 "Nominal payload mass [kg]";
  parameter Real payload_dist_frac = 0.045 "4.5 percent payload change";

  parameter Real m_above1 = m_link2+m_link3+m_link4+m_link5+m_link6+m_link7+m_payload_nom;
  parameter Real m_above2 = m_link3+m_link4+m_link5+m_link6+m_link7+m_payload_nom;
  parameter Real m_above3 = m_link4+m_link5+m_link6+m_link7+m_payload_nom;
  parameter Real m_above4 = m_link5+m_link6+m_link7+m_payload_nom;
  parameter Real m_above5 = m_link6+m_link7+m_payload_nom;
  parameter Real m_above6 = m_link7+m_payload_nom;
  parameter Real m_above7 = m_payload_nom;

  parameter Real J1 = m_link1*L1^2/3.0 + m_above1*L1^2;
  parameter Real J2 = m_link2*L2^2/3.0 + m_above2*L2^2;
  parameter Real J3 = m_link3*L3^2/3.0 + m_above3*L3^2;
  parameter Real J4 = m_link4*L4^2/3.0 + m_above4*L4^2;
  parameter Real J5 = m_link5*L5^2/3.0 + m_above5*L5^2;
  parameter Real J6 = m_link6*L6^2/3.0 + m_above6*L6^2;
  parameter Real J7 = m_link7*L7^2/3.0 + m_above7*L7^2;

  parameter Real b1 = 0.5 "Joint 1 damping [N.m.s/rad]";
  parameter Real b2 = 0.5 "Joint 2 damping [N.m.s/rad]";
  parameter Real b3 = 0.5 "Joint 3 damping [N.m.s/rad]";
  parameter Real b4 = 0.5 "Joint 4 damping [N.m.s/rad]";
  parameter Real b5 = 0.5 "Joint 5 damping [N.m.s/rad]";
  parameter Real b6 = 0.5 "Joint 6 damping [N.m.s/rad]";
  parameter Real b7 = 0.5 "Joint 7 damping [N.m.s/rad]";

  parameter Real c_g1 = 0.0;
  parameter Real c_g2 = g_grav*(m_link2*L2/2.0 + m_above2*L2);
  parameter Real c_g3 = 0.0;
  parameter Real c_g4 = g_grav*(m_link4*L4/2.0 + m_above4*L4);
  parameter Real c_g5 = 0.0;
  parameter Real c_g6 = g_grav*(m_link6*L6/2.0 + m_above6*L6);
  parameter Real c_g7 = 0.0;

  parameter Real d_g2 = payload_dist_frac*m_payload_nom*g_grav*(L2+L3+L4+L5+L6+L7);
  parameter Real d_g4 = payload_dist_frac*m_payload_nom*g_grav*(L4+L5+L6+L7);
  parameter Real d_g6 = payload_dist_frac*m_payload_nom*g_grav*(L6+L7);

  parameter Real wn_ctrl = 30.0 "Controller natural frequency [rad/s]";
  parameter Real Kp1 = wn_ctrl^2*J1;
  parameter Real Kp2 = wn_ctrl^2*J2;
  parameter Real Kp3 = wn_ctrl^2*J3;
  parameter Real Kp4 = wn_ctrl^2*J4;
  parameter Real Kp5 = wn_ctrl^2*J5;
  parameter Real Kp6 = wn_ctrl^2*J6;
  parameter Real Kp7 = wn_ctrl^2*J7;
  parameter Real Kd1 = 2.0*wn_ctrl*J1;
  parameter Real Kd2 = 2.0*wn_ctrl*J2;
  parameter Real Kd3 = 2.0*wn_ctrl*J3;
  parameter Real Kd4 = 2.0*wn_ctrl*J4;
  parameter Real Kd5 = 2.0*wn_ctrl*J5;
  parameter Real Kd6 = 2.0*wn_ctrl*J6;
  parameter Real Kd7 = 2.0*wn_ctrl*J7;
  parameter Real Ki1 = 0.1*Kp1;
  parameter Real Ki2 = 0.1*Kp2;
  parameter Real Ki3 = 0.1*Kp3;
  parameter Real Ki4 = 0.1*Kp4;
  parameter Real Ki5 = 0.1*Kp5;
  parameter Real Ki6 = 0.1*Kp6;
  parameter Real Ki7 = 0.1*Kp7;

  parameter Real int_lim1 = tau_max / max(Ki1, 1e-6);
  parameter Real int_lim2 = tau_max / max(Ki2, 1e-6);
  parameter Real int_lim3 = tau_max / max(Ki3, 1e-6);
  parameter Real int_lim4 = tau_max / max(Ki4, 1e-6);
  parameter Real int_lim5 = tau_max / max(Ki5, 1e-6);
  parameter Real int_lim6 = tau_max / max(Ki6, 1e-6);
  parameter Real int_lim7 = tau_max / max(Ki7, 1e-6);

  parameter Real Kn_null = 1.0 "Null-space posture gain";
  parameter Real Dn_null = 0.5 "Null-space damping gain";

  parameter Real q_mid1 = 0.5 "Midpoint joint 1 [rad]";
  parameter Real q_mid2 = 0.3 "Midpoint joint 2 [rad]";
  parameter Real q_mid3 = -0.3 "Midpoint joint 3 [rad]";
  parameter Real q_mid4 = 0.4 "Midpoint joint 4 [rad]";
  parameter Real q_mid5 = -0.2 "Midpoint joint 5 [rad]";
  parameter Real q_mid6 = 0.3 "Midpoint joint 6 [rad]";
  parameter Real q_mid7 = 0.1 "Midpoint joint 7 [rad]";
  parameter Real q_fin1 = 1.0 "Final joint 1 [rad]";
  parameter Real q_fin2 = 0.6 "Final joint 2 [rad]";
  parameter Real q_fin3 = -0.5 "Final joint 3 [rad]";
  parameter Real q_fin4 = 0.8 "Final joint 4 [rad]";
  parameter Real q_fin5 = -0.4 "Final joint 5 [rad]";
  parameter Real q_fin6 = 0.5 "Final joint 6 [rad]";
  parameter Real q_fin7 = 0.2 "Final joint 7 [rad]";

  parameter Real q_bound = pi_val "Position bound [rad]";
  parameter Real dq_bound = 10.0 "Velocity bound [rad/s]";
  parameter Real ddq_bound = 50.0 "Acceleration bound [rad/s2]";

  Real q1(start=0, fixed=true);
  Real q2(start=0, fixed=true);
  Real q3(start=0, fixed=true);
  Real q4(start=0, fixed=true);
  Real q5(start=0, fixed=true);
  Real q6(start=0, fixed=true);
  Real q7(start=0, fixed=true);
  Real dq1(start=0, fixed=true);
  Real dq2(start=0, fixed=true);
  Real dq3(start=0, fixed=true);
  Real dq4(start=0, fixed=true);
  Real dq5(start=0, fixed=true);
  Real dq6(start=0, fixed=true);
  Real dq7(start=0, fixed=true);
  Real ddq1, ddq2, ddq3, ddq4, ddq5, ddq6, ddq7;
  Real dist_factor(start=0, fixed=true);

  Real tau1, tau2, tau3, tau4, tau5, tau6, tau7;
  Real qr1, qr2, qr3, qr4, qr5, qr6, qr7;
  Real dqr1, dqr2, dqr3, dqr4, dqr5, dqr6, dqr7;
  Real ddqr1, ddqr2, ddqr3, ddqr4, ddqr5, ddqr6, ddqr7;
  Real tg1, tg2, tg3, tg4, tg5, tg6, tg7;
  Real td1, td2, td3, td4, td5, td6, td7;
  Real tgc1, tgc2, tgc3, tgc4, tgc5, tgc6, tgc7;
  Real tn1, tn2, tn3, tn4, tn5, tn6, tn7;
  Real tau_op1, tau_op2, tau_op3, tau_op4, tau_op5, tau_op6, tau_op7;
  Real e1, e2, e3, e4, e5, e6, e7;
  Real track_err_max;
  Real m_payload_t;
  Real s1, s2;
  Real cb_pos1, cb_vel1, cb_acc1;
  Real cb_pos2, cb_vel2, cb_acc2;
  Real q_v1, q_v2, q_v3, q_v4, q_v5, q_v6, q_v7;
  Real dq_v1, dq_v2, dq_v3, dq_v4, dq_v5, dq_v6, dq_v7;
  Real ddq_v1, ddq_v2, ddq_v3, ddq_v4, ddq_v5, ddq_v6, ddq_v7;
  Real tau_v1, tau_v2, tau_v3, tau_v4, tau_v5, tau_v6, tau_v7;
  Boolean settled;
  Real max_e12, max_e34, max_e56, max_e7;
  Real dist_target;

  discrete Real tau_cmd1(start=0, fixed=true);
  discrete Real tau_cmd2(start=0, fixed=true);
  discrete Real tau_cmd3(start=0, fixed=true);
  discrete Real tau_cmd4(start=0, fixed=true);
  discrete Real tau_cmd5(start=0, fixed=true);
  discrete Real tau_cmd6(start=0, fixed=true);
  discrete Real tau_cmd7(start=0, fixed=true);

  discrete Real tau_raw1(start=0, fixed=true);
  discrete Real tau_raw2(start=0, fixed=true);
  discrete Real tau_raw3(start=0, fixed=true);
  discrete Real tau_raw4(start=0, fixed=true);
  discrete Real tau_raw5(start=0, fixed=true);
  discrete Real tau_raw6(start=0, fixed=true);
  discrete Real tau_raw7(start=0, fixed=true);

  discrete Real integ1(start=0, fixed=true);
  discrete Real integ2(start=0, fixed=true);
  discrete Real integ3(start=0, fixed=true);
  discrete Real integ4(start=0, fixed=true);
  discrete Real integ5(start=0, fixed=true);
  discrete Real integ6(start=0, fixed=true);
  discrete Real integ7(start=0, fixed=true);

  discrete Real enc_q1(start=0, fixed=true);
  discrete Real enc_q2(start=0, fixed=true);
  discrete Real enc_q3(start=0, fixed=true);
  discrete Real enc_q4(start=0, fixed=true);
  discrete Real enc_q5(start=0, fixed=true);
  discrete Real enc_q6(start=0, fixed=true);
  discrete Real enc_q7(start=0, fixed=true);

  discrete Real enc_dq1(start=0, fixed=true);
  discrete Real enc_dq2(start=0, fixed=true);
  discrete Real enc_dq3(start=0, fixed=true);
  discrete Real enc_dq4(start=0, fixed=true);
  discrete Real enc_dq5(start=0, fixed=true);
  discrete Real enc_dq6(start=0, fixed=true);
  discrete Real enc_dq7(start=0, fixed=true);

equation
  s1 = max(0.0, min(1.0, time / t_phase1));
  s2 = max(0.0, min(1.0, (time - t_phase1) / (t_phase2 - t_phase1)));

  cb_pos1 = 3.0*s1^2 - 2.0*s1^3;
  cb_vel1 = (6.0*s1 - 6.0*s1^2) / t_phase1;
  cb_acc1 = (6.0 - 12.0*s1) / t_phase1^2;

  cb_pos2 = 3.0*s2^2 - 2.0*s2^3;
  cb_vel2 = (6.0*s2 - 6.0*s2^2) / (t_phase2 - t_phase1);
  cb_acc2 = (6.0 - 12.0*s2) / (t_phase2 - t_phase1)^2;

  qr1 = if time < t_phase1 then q_mid1 * cb_pos1 elseif time < t_phase2 then q_mid1 + (q_fin1 - q_mid1) * cb_pos2 else q_fin1;
  qr2 = if time < t_phase1 then q_mid2 * cb_pos1 elseif time < t_phase2 then q_mid2 + (q_fin2 - q_mid2) * cb_pos2 else q_fin2;
  qr3 = if time < t_phase1 then q_mid3 * cb_pos1 elseif time < t_phase2 then q_mid3 + (q_fin3 - q_mid3) * cb_pos2 else q_fin3;
  qr4 = if time < t_phase1 then q_mid4 * cb_pos1 elseif time < t_phase2 then q_mid4 + (q_fin4 - q_mid4) * cb_pos2 else q_fin4;
  qr5 = if time < t_phase1 then q_mid5 * cb_pos1 elseif time < t_phase2 then q_mid5 + (q_fin5 - q_mid5) * cb_pos2 else q_fin5;
  qr6 = if time < t_phase1 then q_mid6 * cb_pos1 elseif time < t_phase2 then q_mid6 + (q_fin6 - q_mid6) * cb_pos2 else q_fin6;
  qr7 = if time < t_phase1 then q_mid7 * cb_pos1 elseif time < t_phase2 then q_mid7 + (q_fin7 - q_mid7) * cb_pos2 else q_fin7;

  dqr1 = if time < t_phase1 then q_mid1 * cb_vel1 elseif time < t_phase2 then (q_fin1 - q_mid1) * cb_vel2 else 0.0;
  dqr2 = if time < t_phase1 then q_mid2 * cb_vel1 elseif time < t_phase2 then (q_fin2 - q_mid2) * cb_vel2 else 0.0;
  dqr3 = if time < t_phase1 then q_mid3 * cb_vel1 elseif time < t_phase2 then (q_fin3 - q_mid3) * cb_vel2 else 0.0;
  dqr4 = if time < t_phase1 then q_mid4 * cb_vel1 elseif time < t_phase2 then (q_fin4 - q_mid4) * cb_vel2 else 0.0;
  dqr5 = if time < t_phase1 then q_mid5 * cb_vel1 elseif time < t_phase2 then (q_fin5 - q_mid5) * cb_vel2 else 0.0;
  dqr6 = if time < t_phase1 then q_mid6 * cb_vel1 elseif time < t_phase2 then (q_fin6 - q_mid6) * cb_vel2 else 0.0;
  dqr7 = if time < t_phase1 then q_mid7 * cb_vel1 elseif time < t_phase2 then (q_fin7 - q_mid7) * cb_vel2 else 0.0;

  ddqr1 = if time < t_phase1 then q_mid1 * cb_acc1 elseif time < t_phase2 then (q_fin1 - q_mid1) * cb_acc2 else 0.0;
  ddqr2 = if time < t_phase1 then q_mid2 * cb_acc1 elseif time < t_phase2 then (q_fin2 - q_mid2) * cb_acc2 else 0.0;
  ddqr3 = if time < t_phase1 then q_mid3 * cb_acc1 elseif time < t_phase2 then (q_fin3 - q_mid3) * cb_acc2 else 0.0;
  ddqr4 = if time < t_phase1 then q_mid4 * cb_acc1 elseif time < t_phase2 then (q_fin4 - q_mid4) * cb_acc2 else 0.0;
  ddqr5 = if time < t_phase1 then q_mid5 * cb_acc1 elseif time < t_phase2 then (q_fin5 - q_mid5) * cb_acc2 else 0.0;
  ddqr6 = if time < t_phase1 then q_mid6 * cb_acc1 elseif time < t_phase2 then (q_fin6 - q_mid6) * cb_acc2 else 0.0;
  ddqr7 = if time < t_phase1 then q_mid7 * cb_acc1 elseif time < t_phase2 then (q_fin7 - q_mid7) * cb_acc2 else 0.0;

  dist_target = if time >= t_dist_start and time <= t_dist_end then 1.0 else 0.0;
  der(dist_factor) = (dist_target - dist_factor) / 0.05;
  m_payload_t = m_payload_nom * (1.0 + payload_dist_frac * dist_factor);

  J1 * ddq1 = tau1 - b1 * dq1 - tg1 - td1;
  der(q1) = dq1;
  der(dq1) = ddq1;

  J2 * ddq2 = tau2 - b2 * dq2 - tg2 - td2;
  der(q2) = dq2;
  der(dq2) = ddq2;

  J3 * ddq3 = tau3 - b3 * dq3 - tg3 - td3;
  der(q3) = dq3;
  der(dq3) = ddq3;

  J4 * ddq4 = tau4 - b4 * dq4 - tg4 - td4;
  der(q4) = dq4;
  der(dq4) = ddq4;

  J5 * ddq5 = tau5 - b5 * dq5 - tg5 - td5;
  der(q5) = dq5;
  der(dq5) = ddq5;

  J6 * ddq6 = tau6 - b6 * dq6 - tg6 - td6;
  der(q6) = dq6;
  der(dq6) = ddq6;

  J7 * ddq7 = tau7 - b7 * dq7 - tg7 - td7;
  der(q7) = dq7;
  der(dq7) = ddq7;

  tg1 = c_g1 * cos(q1);
  tg2 = c_g2 * cos(q2);
  tg3 = c_g3 * cos(q3);
  tg4 = c_g4 * cos(q4);
  tg5 = c_g5 * cos(q5);
  tg6 = c_g6 * cos(q6);
  tg7 = c_g7 * cos(q7);

  td1 = 0.0;
  td2 = d_g2 * dist_factor * cos(q2);
  td3 = 0.0;
  td4 = d_g4 * dist_factor * cos(q4);
  td5 = 0.0;
  td6 = d_g6 * dist_factor * cos(q6);
  td7 = 0.0;

  tau1 = tau_cmd1;
  tau2 = tau_cmd2;
  tau3 = tau_cmd3;
  tau4 = tau_cmd4;
  tau5 = tau_cmd5;
  tau6 = tau_cmd6;
  tau7 = tau_cmd7;

  tgc1 = c_g1 * cos(q1);
  tgc2 = c_g2 * cos(q2);
  tgc3 = c_g3 * cos(q3);
  tgc4 = c_g4 * cos(q4);
  tgc5 = c_g5 * cos(q5);
  tgc6 = c_g6 * cos(q6);
  tgc7 = c_g7 * cos(q7);

  tn1 = Kn_null * (0.0 - q1) - Dn_null * dq1;
  tn2 = Kn_null * (0.0 - q2) - Dn_null * dq2;
  tn3 = Kn_null * (0.0 - q3) - Dn_null * dq3;
  tn4 = Kn_null * (0.0 - q4) - Dn_null * dq4;
  tn5 = Kn_null * (0.0 - q5) - Dn_null * dq5;
  tn6 = Kn_null * (0.0 - q6) - Dn_null * dq6;
  tn7 = Kn_null * (0.0 - q7) - Dn_null * dq7;

  tau_op1 = Kp1 * (qr1 - q1) + Kd1 * (dqr1 - dq1) + Ki1 * integ1 + J1 * ddqr1 + b1 * dqr1 + tgc1;
  tau_op2 = Kp2 * (qr2 - q2) + Kd2 * (dqr2 - dq2) + Ki2 * integ2 + J2 * ddqr2 + b2 * dqr2 + tgc2;
  tau_op3 = Kp3 * (qr3 - q3) + Kd3 * (dqr3 - dq3) + Ki3 * integ3 + J3 * ddqr3 + b3 * dqr3 + tgc3;
  tau_op4 = Kp4 * (qr4 - q4) + Kd4 * (dqr4 - dq4) + Ki4 * integ4 + J4 * ddqr4 + b4 * dqr4 + tgc4;
  tau_op5 = Kp5 * (qr5 - q5) + Kd5 * (dqr5 - dq5) + Ki5 * integ5 + J5 * ddqr5 + b5 * dqr5 + tgc5;
  tau_op6 = Kp6 * (qr6 - q6) + Kd6 * (dqr6 - dq6) + Ki6 * integ6 + J6 * ddqr6 + b6 * dqr6 + tgc6;
  tau_op7 = Kp7 * (qr7 - q7) + Kd7 * (dqr7 - dq7) + Ki7 * integ7 + J7 * ddqr7 + b7 * dqr7 + tgc7;

  e1 = qr1 - q1;
  e2 = qr2 - q2;
  e3 = qr3 - q3;
  e4 = qr4 - q4;
  e5 = qr5 - q5;
  e6 = qr6 - q6;
  e7 = qr7 - q7;

  max_e12 = max(abs(e1), abs(e2));
  max_e34 = max(abs(e3), abs(e4));
  max_e56 = max(abs(e5), abs(e6));
  max_e7 = abs(e7);
  track_err_max = max(max_e12, max(max_e34, max(max_e56, max_e7)));

  q_v1 = max(0.0, abs(q1) - q_bound);
  q_v2 = max(0.0, abs(q2) - q_bound);
  q_v3 = max(0.0, abs(q3) - q_bound);
  q_v4 = max(0.0, abs(q4) - q_bound);
  q_v5 = max(0.0, abs(q5) - q_bound);
  q_v6 = max(0.0, abs(q6) - q_bound);
  q_v7 = max(0.0, abs(q7) - q_bound);

  dq_v1 = max(0.0, abs(dq1) - dq_bound);
  dq_v2 = max(0.0, abs(dq2) - dq_bound);
  dq_v3 = max(0.0, abs(dq3) - dq_bound);
  dq_v4 = max(0.0, abs(dq4) - dq_bound);
  dq_v5 = max(0.0, abs(dq5) - dq_bound);
  dq_v6 = max(0.0, abs(dq6) - dq_bound);
  dq_v7 = max(0.0, abs(dq7) - dq_bound);

  ddq_v1 = max(0.0, abs(ddq1) - ddq_bound);
  ddq_v2 = max(0.0, abs(ddq2) - ddq_bound);
  ddq_v3 = max(0.0, abs(ddq3) - ddq_bound);
  ddq_v4 = max(0.0, abs(ddq4) - ddq_bound);
  ddq_v5 = max(0.0, abs(ddq5) - ddq_bound);
  ddq_v6 = max(0.0, abs(ddq6) - ddq_bound);
  ddq_v7 = max(0.0, abs(ddq7) - ddq_bound);

  tau_v1 = max(0.0, abs(tau1) - tau_max);
  tau_v2 = max(0.0, abs(tau2) - tau_max);
  tau_v3 = max(0.0, abs(tau3) - tau_max);
  tau_v4 = max(0.0, abs(tau4) - tau_max);
  tau_v5 = max(0.0, abs(tau5) - tau_max);
  tau_v6 = max(0.0, abs(tau6) - tau_max);
  tau_v7 = max(0.0, abs(tau7) - tau_max);

  settled = (time >= 7.8) and (track_err_max < 0.032);

  when sample(0, Ts) then
    enc_q1 := q1;
    enc_q2 := q2;
    enc_q3 := q3;
    enc_q4 := q4;
    enc_q5 := q5;
    enc_q6 := q6;
    enc_q7 := q7;

    enc_dq1 := dq1;
    enc_dq2 := dq2;
    enc_dq3 := dq3;
    enc_dq4 := dq4;
    enc_dq5 := dq5;
    enc_dq6 := dq6;
    enc_dq7 := dq7;

    integ1 := max(-int_lim1, min(int_lim1, integ1 + Ts * (qr1 - q1)));
    integ2 := max(-int_lim2, min(int_lim2, integ2 + Ts * (qr2 - q2)));
    integ3 := max(-int_lim3, min(int_lim3, integ3 + Ts * (qr3 - q3)));
    integ4 := max(-int_lim4, min(int_lim4, integ4 + Ts * (qr4 - q4)));
    integ5 := max(-int_lim5, min(int_lim5, integ5 + Ts * (qr5 - q5)));
    integ6 := max(-int_lim6, min(int_lim6, integ6 + Ts * (qr6 - q6)));
    integ7 := max(-int_lim7, min(int_lim7, integ7 + Ts * (qr7 - q7)));

    tau_raw1 := Kp1 * (qr1 - q1) + Kd1 * (dqr1 - dq1) + Ki1 * integ1 + J1 * ddqr1 + b1 * dqr1 + tgc1 + Kn_null * (0.0 - q1) - Dn_null * dq1;
    tau_raw2 := Kp2 * (qr2 - q2) + Kd2 * (dqr2 - dq2) + Ki2 * integ2 + J2 * ddqr2 + b2 * dqr2 + tgc2 + Kn_null * (0.0 - q2) - Dn_null * dq2;
    tau_raw3 := Kp3 * (qr3 - q3) + Kd3 * (dqr3 - dq3) + Ki3 * integ3 + J3 * ddqr3 + b3 * dqr3 + tgc3 + Kn_null * (0.0 - q3) - Dn_null * dq3;
    tau_raw4 := Kp4 * (qr4 - q4) + Kd4 * (dqr4 - dq4) + Ki4 * integ4 + J4 * ddqr4 + b4 * dqr4 + tgc4 + Kn_null * (0.0 - q4) - Dn_null * dq4;
    tau_raw5 := Kp5 * (qr5 - q5) + Kd5 * (dqr5 - dq5) + Ki5 * integ5 + J5 * ddqr5 + b5 * dqr5 + tgc5 + Kn_null * (0.0 - q5) - Dn_null * dq5;
    tau_raw6 := Kp6 * (qr6 - q6) + Kd6 * (dqr6 - dq6) + Ki6 * integ6 + J6 * ddqr6 + b6 * dqr6 + tgc6 + Kn_null * (0.0 - q6) - Dn_null * dq6;
    tau_raw7 := Kp7 * (qr7 - q7) + Kd7 * (dqr7 - dq7) + Ki7 * integ7 + J7 * ddqr7 + b7 * dqr7 + tgc7 + Kn_null * (0.0 - q7) - Dn_null * dq7;

    tau_cmd1 := if tau_raw1 > tau_max then tau_max elseif tau_raw1 < -tau_max then -tau_max else tau_raw1;
    tau_cmd2 := if tau_raw2 > tau_max then tau_max elseif tau_raw2 < -tau_max then -tau_max else tau_raw2;
    tau_cmd3 := if tau_raw3 > tau_max then tau_max elseif tau_raw3 < -tau_max then -tau_max else tau_raw3;
    tau_cmd4 := if tau_raw4 > tau_max then tau_max elseif tau_raw4 < -tau_max then -tau_max else tau_raw4;
    tau_cmd5 := if tau_raw5 > tau_max then tau_max elseif tau_raw5 < -tau_max then -tau_max else tau_raw5;
    tau_cmd6 := if tau_raw6 > tau_max then tau_max elseif tau_raw6 < -tau_max then -tau_max else tau_raw6;
    tau_cmd7 := if tau_raw7 > tau_max then tau_max elseif tau_raw7 < -tau_max then -tau_max else tau_raw7;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008)
  );
end SevenPathMoveC;