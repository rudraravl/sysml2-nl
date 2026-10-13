model GroundPairHandoffF
  // ===== Specified parameters =====
  parameter Real m_robot  = 14.0  "robot mass [kg]";
  parameter Real r_wheel   = 0.09  "wheel radius [m]";
  parameter Real tau_max   = 12.2  "per-wheel torque bound [N.m]";
  parameter Real f_sim     = 500.0 "run rate [Hz]";
  parameter Real t_end     = 20.0  "mission duration [s]";
  parameter Real comm_dist = 0.145 "communication delay disturbance [s]";

  // ===== Representative (not specified) parameters =====
  parameter Real L_wb       = 0.20 "wheelbase [m] (representative)";
  parameter Real I_body      = 0.10 "body yaw inertia [kg.m^2] (representative)";
  parameter Real b_lin       = 0.8  "linear viscous drag [N.s/m] (representative)";
  parameter Real b_rot       = 0.6  "rotational viscous drag [N.m.s/rad] (representative)";
  parameter Real v_max       = 0.8  "commanded speed cap [m/s] (representative)";
  parameter Real Kpv         = 2.0  "velocity tracking gain (representative)";
  parameter Real Kpw         = 0.5  "yaw-rate tracking gain (representative)";
  parameter Real Kh          = 2.0  "heading gain (representative)";
  parameter Real Kv          = 0.2  "speed gain on range error (representative)";
  parameter Real sep_min     = 0.40 "no-collision separation [m] (representative)";
  parameter Real send_period = 0.5  "comm resend period [s] (representative)";
  parameter Real zone1x = 6.0 "inspection zone 1 x [m] (representative)";
  parameter Real zone1y = 1.0 "inspection zone 1 y [m] (representative)";
  parameter Real zone2x = 1.0 "inspection zone 2 x [m] (representative)";
  parameter Real zone2y = 4.0 "inspection zone 2 y [m] (representative)";
  parameter Real wall_x  = 8.0 "world wall feature x [m] (representative)";
  parameter Real wall_y  = 8.0 "world wall feature y [m] (representative)";
  parameter Real marker_x = 3.0 "survey marker x [m] (representative, replan target)";
  parameter Real marker_y = 3.0 "survey marker y [m] (representative, replan target)";
  parameter Real pA0x  = 0.0 "A initial x [m]";
  parameter Real pA0y  = 0.0 "A initial y [m]";
  parameter Real pA0th = 0.0 "A initial heading [rad]";
  parameter Real pB0x  = 0.0 "B initial x [m]";
  parameter Real pB0y  = 2.0 "B initial y [m]";
  parameter Real pB0th = 0.0 "B initial heading [rad]";

  // ===== Robot A continuous states =====
  Real xA(start=pA0x,  fixed=true);
  Real yA(start=pA0y,  fixed=true);
  Real thetaA(start=pA0th, fixed=true);
  Real vA(start=0.0,   fixed=true);
  Real omegaA(start=0.0,fixed=true);

  // ===== Robot B continuous states =====
  Real xB(start=pB0x,  fixed=true);
  Real yB(start=pB0y,  fixed=true);
  Real thetaB(start=pB0th, fixed=true);
  Real vB(start=0.0,   fixed=true);
  Real omegaB(start=0.0,fixed=true);

  // ===== Actuation: four wheel-torque channels =====
  Real tauAL_cmd, tauAR_cmd, tauBL_cmd, tauBR_cmd;
  Real tauAL, tauAR, tauBL, tauBR;

  // ===== Communication =====
  Real result_send(start=-1.0, fixed=true) "payload sent from A";
  Real result_recv "payload received by B";
  Real ts_send(start=0.0, fixed=true) "send timestamp [s]";
  Real ts_recv      "receive timestamp [s]";
  Real data_age     "age of last received data [s]";
  Real comm_delay   "current effective delay [s]";
  Boolean in_middle_third;

  // ===== Handoff / task state =====
  Integer handoff_state(start=0, fixed=true)
    "0=inspecting,1=A done & sending,2=B received & replanned,3=complete";
  Boolean handoff_success;
  Boolean task_complete;

  // ===== Targets and errors =====
  Real targetAx, targetAy, targetBx, targetBy;
  Real errA "A tracking error [m]";
  Real errB "B tracking error [m]";
  Real errB_primary "primary tracking error [m]";
  Real dAB "pair separation [m]";

  // ===== Sensors (local) =====
  Real encAL, encAR, encBL, encBR;
  Real imuA_yawrate, imuB_yawrate;
  Real lidarA, lidarB;
  Real inspect_valA "inspection result scalar (encoded)";

  // ===== Desired kinematics for control =====
  Real theta_des_A, head_err_A, v_des_A, omega_des_A;
  Real theta_des_B, head_err_B, v_des_B, omega_des_B;

  // ===== 500 Hz synchronized traces =====
  Real tr_xA, tr_yA, tr_thetaA, tr_vA, tr_tauAL, tr_tauAR, tr_lidarA;
  Real tr_xB, tr_yB, tr_thetaB, tr_vB, tr_tauBL, tr_tauBR, tr_lidarB;
  Real tr_data_age, tr_handoff;

  // ===== Verification flags =====
  Boolean actuator_bound_ok;
  Boolean separation_ok;
  Boolean data_age_ok;
  Boolean tracking_ok;

equation
  // ===== Differential-drive dynamics: Robot A =====
  der(xA)     = vA*cos(thetaA);
  der(yA)     = vA*sin(thetaA);
  der(thetaA) = omegaA;
  m_robot*der(vA)     = (tauAL + tauAR)/r_wheel - b_lin*vA;
  I_body*der(omegaA)  = (tauAR - tauAL)*L_wb/(2*r_wheel) - b_rot*omegaA;

  // ===== Differential-drive dynamics: Robot B =====
  der(xB)     = vB*cos(thetaB);
  der(yB)     = vB*sin(thetaB);
  der(thetaB) = omegaB;
  m_robot*der(vB)     = (tauBL + tauBR)/r_wheel - b_lin*vB;
  I_body*der(omegaB)  = (tauBR - tauBL)*L_wb/(2*r_wheel) - b_rot*omegaB;

  // ===== Task allocation: A inspects zone1, B inspects zone2 then replans =====
  targetAx = zone1x;
  targetAy = zone1y;
  targetBx = if handoff_state >= 2 then marker_x else zone2x;
  targetBy = if handoff_state >= 2 then marker_y else zone2y;

  // ===== Tracking errors =====
  errA = sqrt((xA - targetAx)^2 + (yA - targetAy)^2);
  errB = sqrt((xB - targetBx)^2 + (yB - targetBy)^2);
  errB_primary = errB;

  // ===== Local motion control: Robot A =====
  theta_des_A = atan2(targetAy - yA, targetAx - xA);
  head_err_A  = atan2(sin(theta_des_A - thetaA), cos(theta_des_A - thetaA));
  v_des_A     = max(-v_max, min(v_max, Kv*errA));
  omega_des_A = Kh*head_err_A;
  tauAL_cmd   = Kpv*(v_des_A - vA) - Kpw*(omega_des_A - omegaA);
  tauAR_cmd   = Kpv*(v_des_A - vA) + Kpw*(omega_des_A - omegaA);
  tauAL       = max(-tau_max, min(tau_max, tauAL_cmd));
  tauAR       = max(-tau_max, min(tau_max, tauAR_cmd));

  // ===== Local motion control: Robot B =====
  theta_des_B = atan2(targetBy - yB, targetBx - xB);
  head_err_B  = atan2(sin(theta_des_B - thetaB), cos(theta_des_B - thetaB));
  v_des_B     = max(-v_max, min(v_max, Kv*errB));
  omega_des_B = Kh*head_err_B;
  tauBL_cmd   = Kpv*(v_des_B - vB) - Kpw*(omega_des_B - omegaB);
  tauBR_cmd   = Kpv*(v_des_B - vB) + Kpw*(omega_des_B - omegaB);
  tauBL       = max(-tau_max, min(tau_max, tauBL_cmd));
  tauBR       = max(-tau_max, min(tau_max, tauBR_cmd));

  // ===== Local sensors: encoders, IMU, lidar =====
  encAL = vA/r_wheel - omegaA*L_wb/(2*r_wheel);
  encAR = vA/r_wheel + omegaA*L_wb/(2*r_wheel);
  encBL = vB/r_wheel - omegaB*L_wb/(2*r_wheel);
  encBR = vB/r_wheel + omegaB*L_wb/(2*r_wheel);
  imuA_yawrate = omegaA;
  imuB_yawrate = omegaB;
  lidarA = sqrt((wall_x - xA)^2 + (wall_y - yA)^2);
  lidarB = sqrt((wall_x - xB)^2 + (wall_y - xB)^2);
  inspect_valA = 1.0;

  // ===== Pair separation (common world frame) =====
  dAB = sqrt((xA - xB)^2 + (yA - yB)^2);

  // ===== Communication channel with middle-third delay disturbance =====
  in_middle_third = (time >= t_end/3.0) and (time <= 2.0*t_end/3.0);
  comm_delay      = if in_middle_third then comm_dist else 0.0;
  result_recv     = delay(result_send, comm_delay, comm_dist + 0.01);
  ts_recv         = delay(ts_send,     comm_delay, comm_dist + 0.01);
  data_age        = if handoff_state >= 2 then (time - ts_recv) else 0.0;

  // ===== Explicit handoff state machine =====
  // A completes inspection at zone1 -> first send
  when handoff_state == 0 and errA <= 0.15 then
    handoff_state := 1;
    result_send   := inspect_valA;
    ts_send       := time;
  end when;
  // Periodic re-send after first inspection to keep data age bounded
  when handoff_state >= 1 and handoff_state < 3 and sample(0.0, send_period) then
    result_send := inspect_valA;
    ts_send     := time;
  end when;
  // B receives timestamped result -> replan to marker
  when handoff_state == 1 and result_recv > 0.0 then
    handoff_state := 2;
  end when;
  // Mission complete once B reaches replanned target after 13 s
  when handoff_state == 2 and errB <= 0.20 and time > 13.0 then
    handoff_state := 3;
  end when;

  handoff_success = handoff_state >= 2;
  task_complete   = handoff_state >= 3;

  // ===== Verification criteria =====
  actuator_bound_ok = abs(tauAL) <= tau_max + 1e-6 and abs(tauAR) <= tau_max + 1e-6
                      and abs(tauBL) <= tau_max + 1e-6 and abs(tauBR) <= tau_max + 1e-6;
  separation_ok     = dAB >= sep_min;
  data_age_ok       = (if handoff_state >= 2 then data_age else 0.0)
                      <= (comm_dist + send_period + 0.1);
  tracking_ok       = if time >= 13.0 then errB_primary <= 0.32 else true;

  // ===== 500 Hz synchronized state/command/sensor traces =====
  when sample(0, 1.0/f_sim) then
    tr_xA     := xA;
    tr_yA     := yA;
    tr_thetaA := thetaA;
    tr_vA     := vA;
    tr_tauAL  := tauAL;
    tr_tauAR  := tauAR;
    tr_lidarA := lidarA;
    tr_xB     := xB;
    tr_yB     := yB;
    tr_thetaB := thetaB;
    tr_vB     := vB;
    tr_tauBL  := tauBL;
    tr_tauBR  := tauBR;
    tr_lidarB := lidarB;
    tr_data_age := data_age;
    tr_handoff  := handoff_state;
  end when;

  // ===== No NaN / infinite physical, control, or estimator values =====
  assert(noEvent(abs(xA)      < 1e6), "NaN/inf in physical state");
  assert(noEvent(abs(xB)      < 1e6), "NaN/inf in physical state");
  assert(noEvent(abs(tauAL)   < 1e6), "NaN/inf in control");
  assert(noEvent(abs(tauBR)   < 1e6), "NaN/inf in control");
  assert(noEvent(abs(data_age) < 1e6), "NaN/inf in estimator/comm");

  annotation (experiment(StopTime=20.0, Tolerance=1e-6, Interval=0.002));
end GroundPairHandoffF;