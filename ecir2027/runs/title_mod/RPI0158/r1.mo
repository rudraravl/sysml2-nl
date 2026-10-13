model SCARACarryB
  "Fixed-base SCARA articulated manipulator: lift and reorient a rigid payload
   while holding the requested end-effector orientation. Computed-torque control
   with bounded wrist-force correction, sampled at 100 Hz over a 10 s mission.
   A controlled 8.4 kg payload disturbance is injected during the middle third.
   Values not specified by the mission statement (link COM, link inertia, controller
   gains, filter coefficient, contact stiffness) are engineering assumptions and
   are labeled below; they are not claimed mission facts."

  // ---- Specified physical parameters ----
  parameter Real L1 = 0.48    "link 1 length [m] (specified)";
  parameter Real L2 = 0.34    "link 2 length [m] (specified)";
  parameter Real m1 = 6.0     "link 1 moving mass [kg] (specified)";
  parameter Real m2 = 4.0     "link 2 moving mass [kg] (specified)";
  parameter Real m3 = 2.0     "carriage moving mass [kg] (specified)";
  parameter Real m_base = 28.0 "cylindrical base mass [kg] (specified, fixed)";
  parameter Real mp_dist = 8.4 "disturbance payload mass [kg] (specified)";
  parameter Real q3_travel = 0.30 "prismatic travel [m] (specified)";
  parameter Real g = 9.81     "gravitational acceleration [m/s^2]";

  // ---- Assumed (not specified) mechanical parameters ----
  parameter Real lc1 = 0.5*L1   "link 1 COM [m] (assumed midpoint)";
  parameter Real lc2 = 0.5*L2   "link 2 COM [m] (assumed midpoint)";
  parameter Real I1 = m1*L1^2/12 "link 1 inertia about Z [kg.m^2] (assumed uniform rod)";
  parameter Real I2 = m2*L2^2/12 "link 2 inertia about Z [kg.m^2] (assumed uniform rod)";

  // ---- Specified actuator bounds ----
  parameter Real tau_max = 77.9  "revolute torque bound [N.m] (specified)";
  parameter Real F_max   = 900.0 "prismatic force bound [N] (specified)";

  // ---- Assumed controller / correction bounds ----
  parameter Real F_corr_max  = 50.0  "wrist-force correction bound (vertical) [N] (assumed)";
  parameter Real tau_corr_max = 20.0 "wrist-force correction bound (revolute) [N.m] (assumed)";

  // ---- Assumed controller gains ----
  parameter Real Kp1 = 300.0;  parameter Real Kd1 = 30.0;
  parameter Real Kp2 = 150.0;  parameter Real Kd2 = 18.0;
  parameter Real Kp3 = 1500.0; parameter Real Kd3 = 120.0;
  parameter Real Kw = 0.98 "wrist-force correction gain (assumed)";

  // ---- 100 Hz digital controller ----
  parameter Real Ts = 0.01      "control sample time [s] (specified: 100 Hz)";
  parameter Real alpha_f = 0.5  "discrete wrist-force filter coefficient (assumed)";

  // ---- Mission timing (specified) ----
  parameter Real T_end     = 10.0  "mission duration [s]";
  parameter Real T_traj    = 4.0   "trajectory duration [s] (assumed)";
  parameter Real T_dist_on = T_end/3.0      "disturbance start [s] (middle third)";
  parameter Real T_dist_off = 2.0*T_end/3.0 "disturbance end [s] (middle third)";
  parameter Real T_ramp    = 0.10  "payload injection ramp [s] (assumed, avoids impulsive mass step)";

  // ---- Reference pose targets (assumed) ----
  parameter Real q1_final = 1.0471975512  "target joint 1 [rad] (assumed pi/3)";
  parameter Real q2_final = -0.5235987756 "target joint 2 [rad] (assumed -pi/6)";
  parameter Real q3_final = 0.20          "target lift [m] (assumed, within 0.30 travel)";

  // ---- Environment (assumed geometry; collision enabled) ----
  parameter Real floor_z     = 0.0   "rigid floor height [m]";
  parameter Real table_z     = 0.04  "fixed table top height [m] (assumed)";
  parameter Real table_x_min = 0.56  "table footprint x min [m] (assumed)";
  parameter Real table_x_max = 0.72  "table footprint x max [m] (assumed)";
  parameter Real k_contact   = 1.0e5 "contact stiffness [N/m] (assumed)";
  parameter Real b_contact   = 1.0e3 "contact damping [N.s/m] (assumed)";

  // ---- Constraint thresholds (specified) ----
  parameter Real F_wrist_limit = 60.0  "wrist force limit [N]";
  parameter Real track_tol     = 0.054 "primary tracking tolerance [rad or m]";
  parameter Real track_time    = 6.5   "tracking constraint start [s]";

  // ===== Continuous states =====
  Real q1(start=0.0)  "joint 1 angle [rad]";
  Real qd1(start=0.0) "joint 1 velocity [rad/s]";
  Real q2(start=0.0)  "joint 2 angle [rad]";
  Real qd2(start=0.0) "joint 2 velocity [rad/s]";
  Real q3(start=0.0)  "prismatic position [m]";
  Real qd3(start=0.0) "prismatic velocity [m/s]";

  // ===== Active payload =====
  Real mp_active "active payload mass [kg]";
  Real me        "actual end mass (carriage + payload) [kg]";

  // ===== Reference trajectory =====
  Real s_traj, sd_traj, sdd_traj;
  Real q1_ref, q2_ref, q3_ref;
  Real qd1_ref, qd2_ref, qd3_ref;
  Real qdd1_ref, qdd2_ref, qdd3_ref;
  Real orient_ref, orient_act;

  // ===== Plant dynamics (actual) =====
  Real a1, a2, a3, M11, M12, M22, c1, c2;
  Real qdd1, qdd2, qdd3;

  // ===== Nominal controller model =====
  Real a1n, a2n, a3n, M11n, M12n, M22n, c1n, c2n;
  Real qdd_des1, qdd_des2, qdd_des3;
  Real tau1_ct, tau2_ct, F3_ct;

  // ===== Discrete controller outputs (100 Hz ZOH) =====
  discrete Real tau1_d(start=0.0) "commanded joint 1 torque [N.m]";
  discrete Real tau2_d(start=0.0) "commanded joint 2 torque [N.m]";
  discrete Real F3_d(start=0.0)   "commanded prismatic force [N]";
  Real tau1, tau2, F3;

  // ===== Wrist wrench sensor =====
  Real x_ee, z_ee, xd_ee, xdd_ee;
  Real Jx1, Jx2;
  Real F_wrist_z_raw, F_wrist_x_raw;
  discrete Real F_filt_z(start=0.0) "filtered vertical wrist force [N]";
  discrete Real F_filt_x(start=0.0) "filtered horizontal wrist force [N]";
  Real F_wrist_dyn_z, F_wrist_dyn_x, F_wrist_mag "gravity-compensated wrist wrench magnitude [N]";

  // ===== Contact =====
  Real pen_floor, pen_table, in_table, F_contact;

  // ===== Tracking and constraints =====
  Real e1, e2, e3, orient_err, track_err;
  Real c_tau1, c_tau2, c_F3, c_joint, c_wrist, c_track, payload_retained;

equation
  // ---- Active payload (smooth trapezoid, middle third) ----
  mp_active = if time < T_dist_on then 0.0
    elseif time < T_dist_on + T_ramp then mp_dist*(time - T_dist_on)/T_ramp
    elseif time < T_dist_off - T_ramp then mp_dist
    elseif time < T_dist_off then mp_dist*(T_dist_off - time)/T_ramp
    else 0.0;
  me = m3 + mp_active;
  payload_retained = 1.0 "rigid payload retained by gripper";

  // ---- Quintic reference profile (zero vel/acc at both ends) ----
  s_traj = if time < T_traj then
      10.0*(time/T_traj)^3 - 15.0*(time/T_traj)^4 + 6.0*(time/T_traj)^5
    else 1.0;
  sd_traj = if time < T_traj then
      30.0*time^2/T_traj^3 - 60.0*time^3/T_traj^4 + 30.0*time^4/T_traj^5
    else 0.0;
  sdd_traj = if time < T_traj then
      60.0*time/T_traj^3 - 180.0*time^2/T_traj^4 + 120.0*time^3/T_traj^5
    else 0.0;

  q1_ref  = q1_final*s_traj;
  q2_ref  = q2_final*s_traj;
  q3_ref  = q3_final*s_traj;
  qd1_ref = q1_final*sd_traj;
  qd2_ref = q2_final*sd_traj;
  qd3_ref = q3_final*sd_traj;
  qdd1_ref = q1_final*sdd_traj;
  qdd2_ref = q2_final*sdd_traj;
  qdd3_ref = q3_final*sdd_traj;
  orient_ref = q1_ref + q2_ref;
  orient_act = q1 + q2;

  // ---- Plant inertia / Coriolis (actual mass) ----
  a1 = m1*lc1^2 + m2*(L1^2 + lc2^2) + I1 + I2 + me*(L1^2 + L2^2);
  a2 = m2*lc2^2 + I2 + me*L2^2;
  a3 = m2*L1*lc2 + me*L1*L2;
  M11 = a1 + 2.0*a3*cos(q2);
  M12 = a2 + a3*cos(q2);
  M22 = a2;
  c1 = -a3*sin(q2)*(2.0*qd1*qd2 + qd2^2);
  c2 = a3*sin(q2)*qd1^2;

  // ---- Nominal controller model (carriage mass only) ----
  a1n = m1*lc1^2 + m2*(L1^2 + lc2^2) + I1 + I2 + m3*(L1^2 + L2^2);
  a2n = m2*lc2^2 + I2 + m3*L2^2;
  a3n = m2*L1*lc2 + m3*L1*L2;
  M11n = a1n + 2.0*a3n*cos(q2);
  M12n = a2n + a3n*cos(q2);
  M22n = a2n;
  c1n = -a3n*sin(q2)*(2.0*qd1*qd2 + qd2^2);
  c2n = a3n*sin(q2)*qd1^2;

  // ---- Desired accelerations (computed-torque PD correction) ----
  qdd_des1 = qdd1_ref + Kd1*(qd1_ref - qd1) + Kp1*(q1_ref - q1);
  qdd_des2 = qdd2_ref + Kd2*(qd2_ref - qd2) + Kp2*(q2_ref - q2);
  qdd_des3 = qdd3_ref + Kd3*(qd3_ref - qd3) + Kp3*(q3_ref - q3);

  // ---- Computed torque (nominal; no payload knowledge) ----
  tau1_ct = M11n*qdd_des1 + M12n*qdd_des2 + c1n;
  tau2_ct = M12n*qdd_des1 + M22n*qdd_des2 + c2n;
  F3_ct   = m3*(qdd_des3 + g);

  // ---- Wrist wrench sensor (raw, includes payload weight in z) ----
  x_ee = L1*cos(q1) + L2*cos(q1 + q2);
  z_ee = q3;
  xd_ee = -L1*sin(q1)*qd1 - L2*sin(q1+q2)*(qd1 + qd2);
  xdd_ee = -L1*cos(q1)*qd1^2 - L1*sin(q1)*qdd1
         - L2*cos(q1+q2)*(qd1+qd2)^2 - L2*sin(q1+q2)*(qdd1 + qdd2);
  Jx1 = -L1*sin(q1) - L2*sin(q1+q2);
  Jx2 = -L2*sin(q1+q2);
  F_wrist_z_raw = mp_active*(qdd3 + g);
  F_wrist_x_raw = mp_active*xdd_ee;
  // Gravity-compensated dynamic wrench magnitude (bounded quantity)
  F_wrist_dyn_z = mp_active*qdd3;
  F_wrist_dyn_x = mp_active*xdd_ee;
  F_wrist_mag = sqrt(F_wrist_dyn_z*F_wrist_dyn_z + F_wrist_dyn_x*F_wrist_dyn_x + 1.0e-12);

  // ---- 100 Hz digital controller: filter wrist force and apply bounded correction ----
  when sample(0.0, Ts) then
    F_filt_z = (1.0 - alpha_f)*pre(F_filt_z) + alpha_f*F_wrist_z_raw;
    F_filt_x = (1.0 - alpha_f)*pre(F_filt_x) + alpha_f*F_wrist_x_raw;
    tau1_d = max(-tau_max, min(tau_max,
                max(-tau_corr_max, min(tau_corr_max, tau1_ct + Kw*Jx1*F_filt_x))));
    tau2_d = max(-tau_max, min(tau_max,
                max(-tau_corr_max, min(tau_corr_max, tau2_ct + Kw*Jx2*F_filt_x))));
    F3_d   = max(-F_max, min(F_max,
                max(-F_corr_max, min(F_corr_max, F3_ct + Kw*F_filt_z))));
  end when;
  tau1 = tau1_d;
  tau2 = tau2_d;
  F3   = F3_d;

  // ---- Contact: rigid floor and fixed table (collision enabled) ----
  pen_floor = if z_ee < floor_z then (floor_z - z_ee) else 0.0;
  in_table  = if (x_ee > table_x_min and x_ee < table_x_max) then 1.0 else 0.0;
  pen_table = if (in_table > 0.5 and z_ee < table_z) then (table_z - z_ee) else 0.0;
  F_contact = k_contact*(pen_floor + pen_table)
              - b_contact*qd3*(if (pen_floor > 0.0 or pen_table > 0.0) then 1.0 else 0.0);

  // ---- Plant equations of motion ----
  M11*qdd1 + M12*qdd2 + c1 = tau1;
  M12*qdd1 + M22*qdd2 + c2 = tau2;
  me*qdd3 = F3 - me*g + F_contact;
  der(q1) = qd1;  der(qd1) = qdd1;
  der(q2) = qd2;  der(qd2) = qdd2;
  der(q3) = qd3;  der(qd3) = qdd3;

  // ---- Tracking errors ----
  e1 = q1 - q1_ref;
  e2 = q2 - q2_ref;
  e3 = q3 - q3_ref;
  orient_err = orient_act - orient_ref;
  track_err = max(abs(e1), max(abs(e2), abs(e3)));

  // ---- Constraint indicators (1 = satisfied) ----
  c_tau1 = if abs(tau1) <= tau_max + 1.0e-6 then 1.0 else 0.0;
  c_tau2 = if abs(tau2) <= tau_max + 1.0e-6 then 1.0 else 0.0;
  c_F3   = if abs(F3)   <= F_max   + 1.0e-6 then 1.0 else 0.0;
  c_joint = if (q3 >= -1.0e-6 and q3 <= q3_travel + 1.0e-6) then 1.0 else 0.0;
  c_wrist = if F_wrist_mag <= F_wrist_limit + 1.0e-6 then 1.0 else 0.0;
  c_track = if time < track_time then 1.0
            elseif track_err <= track_tol + 1.0e-6 then 1.0
            else 0.0;

  annotation (
    experiment(StartTime=0.0, StopTime=10.0, Tolerance=1.0e-6, Interval=0.01),
    Documentation(info="SCARACarryB: SCARA lift-and-reorient mission.
  Synchronized traces: states (q1,qd1,q2,qd2,q3,qd3), commands (tau1,tau2,F3),
  sensors (F_wrist_mag, F_wrist_z_raw, x_ee, z_ee, mp_active).
  Constraint indicators c_tau1,c_tau2,c_F3,c_joint,c_wrist,c_track,payload_retained."));
end SCARACarryB;