model DuoArmCarryC
  // ---- Physical parameters ----
  parameter Real l1 = 0.55 "link 1 length [m]";
  parameter Real l2 = 0.38 "link 2 length [m]";
  parameter Real m1 = 5.0 "link 1 mass [kg]";
  parameter Real m2 = 3.0 "link 2 mass [kg]";
  parameter Real m_ped = 20.0 "pedestal (fixed base box) mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real mp_dist = 10.8 "disturbance payload mass [kg]";
  parameter Real q_lim = 1.6 "revolute Y joint limit [rad]";
  parameter Real tau_max = 64.4 "max command torque [N.m]";
  parameter Real f_wrist_max = 60.0 "wrist force limit [N]";
  // Uniform-capsule CoM/inertia assumption; exact capsule properties not specified
  parameter Real lc1 = 0.5*l1 "link 1 CoM [m]";
  parameter Real lc2 = 0.5*l2 "link 2 CoM [m]";
  parameter Real I1 = m1*l1^2/12.0 "link 1 inertia [kg.m2]";
  parameter Real I2 = m2*l2^2/12.0 "link 2 inertia [kg.m2]";
  // ---- Control / estimator ----
  parameter Real Kp = 400.0 "computed-torque PD proportional gain";
  parameter Real Kd = 40.0 "computed-torque PD derivative gain";
  parameter Real Kw = 0.3 "wrist-force correction gain";
  parameter Real tau_filt_mp = 0.05 "payload estimator filter time constant [s]";
  parameter Real tau_filt_wf = 0.04 "wrist-force filter time constant [s]";
  // ---- Trajectory ----
  parameter Real T_rise = 6.0 "trajectory rise time [s]";
  parameter Real q1_0 = 0.30 "initial joint 1 angle [rad]";
  parameter Real q2_0 = 0.30 "initial joint 2 angle [rad]";
  parameter Real q1_f = 1.20 "final joint 1 angle [rad]";
  parameter Real q2_f = 0.50 "final joint 2 angle [rad]";
  // ---- Workcell ----
  parameter Real floor_z = 0.0 "rigid workcell floor height [m]";
  parameter Real table_z = 0.05 "fixed table surface height [m]";

  // ---- Dynamic states ----
  Real q1(start=q1_0, fixed=true) "joint 1 angle [rad]";
  Real q2(start=q2_0, fixed=true) "joint 2 angle [rad]";
  Real qd1(start=0.0, fixed=true) "joint 1 velocity [rad/s]";
  Real qd2(start=0.0, fixed=true) "joint 2 velocity [rad/s]";
  Real mp_est_filt(start=0.0, fixed=true) "filtered payload mass estimate [kg]";
  Real f_wrist_filt(start=0.0, fixed=true) "filtered dynamic wrist force [N]";

  // ---- Algebraic / instrumentation / control ----
  Real mp_eff "actual active payload mass [kg]";
  Real mp_est "raw payload mass estimate [kg]";
  Real M11,M12,M21,M22, h, C1, C2, G1, G2;
  Real Mc11,Mc12,Mc21,Mc22, hc, Cc1, Cc2, Gc1, Gc2;
  Real s,sd,sdd;
  Real q1_des,q2_des,qd1_des,qd2_des,qdd1_des,qdd2_des;
  Real e1,e2,ed1,ed2;
  Real u1,u2;
  Real tau1_raw,tau2_raw,tau1,tau2;
  Real xdd_w, zdd_w, f_wrist_x, f_wrist_z, f_wrist_norm, f_wrist_meas;
  Real corr1, corr2;
  Real track_err "primary tracking error norm [rad]";
  Real x_ee, z_ee;
  Real F_base_z "base vertical reaction [N]";
  Boolean tbl_collision;
  Real contact1, contact2;

  // ---- Synchronized 125 Hz traces ----
  discrete Real t_s, q1_s, q2_s, qd1_s, qd2_s, tau1_s, tau2_s, f_wrist_s, track_err_s, mp_s;

equation
  // Payload disturbance: 10.8 kg during middle third of 12 s run => [4,8] s
  if time >= 4.0 and time <= 8.0 then
    mp_eff = mp_dist;
  else
    mp_eff = 0.0;
  end if;

  // ---- Plant: 2-link planar manipulator with revolute Y joints (gravity along -Z) ----
  M11 = I1 + I2 + m1*lc1^2 + m2*(l1^2 + lc2^2 + 2.0*l1*lc2*cos(q2)) + mp_eff*(l1^2 + l2^2 + 2.0*l1*l2*cos(q2));
  M12 = I2 + m2*(lc2^2 + l1*lc2*cos(q2)) + mp_eff*(l2^2 + l1*l2*cos(q2));
  M21 = M12;
  M22 = I2 + m2*lc2^2 + mp_eff*l2^2;
  h = -m2*l1*lc2*sin(q2) - mp_eff*l1*l2*sin(q2);
  C1 = h*qd2^2 + 2.0*h*qd1*qd2;
  C2 = -h*qd1^2;
  G1 = (m1*lc1 + m2*l1 + mp_eff*l1)*g*cos(q1) + (m2*lc2 + mp_eff*l2)*g*cos(q1+q2);
  G2 = (m2*lc2 + mp_eff*l2)*g*cos(q1+q2);

  // Equations of motion: M*qdd + C + G = tau + contact
  M11*der(qd1) + M12*der(qd2) + C1 + G1 = tau1 + contact1;
  M21*der(qd1) + M22*der(qd2) + C2 + G2 = tau2 + contact2;
  der(q1) = qd1;
  der(q2) = qd2;

  // Joint-limit soft contact (limits +/- q_lim)
  contact1 = if q1 < -q_lim then 1.0e4*(q1 + q_lim) - 1.0e2*qd1
             elseif q1 > q_lim then 1.0e4*(q1 - q_lim) - 1.0e2*qd1
             else 0.0;
  contact2 = if q2 < -q_lim then 1.0e4*(q2 + q_lim) - 1.0e2*qd2
             elseif q2 > q_lim then 1.0e4*(q2 - q_lim) - 1.0e2*qd2
             else 0.0;

  // ---- Smooth quintic reference trajectory (zero terminal vel/accel) ----
  if time <= 0.0 then
    s = 0.0; sd = 0.0; sdd = 0.0;
  elseif time >= T_rise then
    s = 1.0; sd = 0.0; sdd = 0.0;
  else
    s = 10.0*(time/T_rise)^3 - 15.0*(time/T_rise)^4 + 6.0*(time/T_rise)^5;
    sd = (30.0*(time/T_rise)^2 - 60.0*(time/T_rise)^3 + 30.0*(time/T_rise)^4)/T_rise;
    sdd = (60.0*(time/T_rise) - 180.0*(time/T_rise)^2 + 120.0*(time/T_rise)^3)/T_rise^2;
  end if;
  q1_des = q1_0 + (q1_f - q1_0)*s;
  q2_des = q2_0 + (q2_f - q2_0)*s;
  qd1_des = (q1_f - q1_0)*sd;
  qd2_des = (q2_f - q2_0)*sd;
  qdd1_des = (q1_f - q1_0)*sdd;
  qdd2_des = (q2_f - q2_0)*sdd;

  // ---- Wrist (joint 2 location) kinematic wrench (no angular-accel term; structural for FMU) ----
  xdd_w = -l1*cos(q1)*qd1^2;
  zdd_w = -l1*sin(q1)*qd1^2;
  f_wrist_x = (m2 + mp_eff)*xdd_w;
  f_wrist_z = (m2 + mp_eff)*(zdd_w + g);
  f_wrist_norm = sqrt(f_wrist_x^2 + f_wrist_z^2 + 1.0e-12);
  // gravity-compensated dynamic wrist force used for safety bound
  f_wrist_meas = sqrt(((m2 + mp_eff)*xdd_w)^2 + ((m2 + mp_eff)*zdd_w)^2 + 1.0e-12);
  der(f_wrist_filt) = (f_wrist_meas - f_wrist_filt)/tau_filt_wf;

  // ---- Payload estimator from wrist wrench (z-component) ----
  mp_est = max(0.0, f_wrist_z/max(0.5, zdd_w + g) - m2);
  der(mp_est_filt) = (mp_est - mp_est_filt)/tau_filt_mp;

  // ---- Computed-torque controller (uses estimated payload) ----
  Mc11 = I1 + I2 + m1*lc1^2 + m2*(l1^2 + lc2^2 + 2.0*l1*lc2*cos(q2)) + mp_est_filt*(l1^2 + l2^2 + 2.0*l1*l2*cos(q2));
  Mc12 = I2 + m2*(lc2^2 + l1*lc2*cos(q2)) + mp_est_filt*(l2^2 + l1*l2*cos(q2));
  Mc21 = Mc12;
  Mc22 = I2 + m2*lc2^2 + mp_est_filt*l2^2;
  hc = -m2*l1*lc2*sin(q2) - mp_est_filt*l1*l2*sin(q2);
  Cc1 = hc*qd2^2 + 2.0*hc*qd1*qd2;
  Cc2 = -hc*qd1^2;
  Gc1 = (m1*lc1 + m2*l1 + mp_est_filt*l1)*g*cos(q1) + (m2*lc2 + mp_est_filt*l2)*g*cos(q1+q2);
  Gc2 = (m2*lc2 + mp_est_filt*l2)*g*cos(q1+q2);

  e1 = q1_des - q1;
  e2 = q2_des - q2;
  ed1 = qd1_des - qd1;
  ed2 = qd2_des - qd2;
  u1 = qdd1_des + Kp*e1 + Kd*ed1;
  u2 = qdd2_des + Kp*e2 + Kd*ed2;

  // Bounded wrist-force correction (saturates before wrist force approaches limit)
  corr1 = max(-15.0, min(15.0, -Kw*(f_wrist_filt - 0.5*f_wrist_max)*cos(q1)));
  corr2 = max(-10.0, min(10.0, -Kw*(f_wrist_filt - 0.5*f_wrist_max)*cos(q1+q2)));

  tau1_raw = Mc11*u1 + Mc12*u2 + Cc1 + Gc1 + corr1;
  tau2_raw = Mc21*u1 + Mc22*u2 + Cc2 + Gc2 + corr2;

  // Effort saturation
  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));

  // ---- Evidence / observables ----
  track_err = sqrt(e1^2 + e2^2 + 1.0e-12);
  x_ee = l1*cos(q1) + l2*cos(q1+q2);
  z_ee = l1*sin(q1) + l2*sin(q1+q2);
  F_base_z = (m1 + m2 + m_ped + mp_eff)*g;
  tbl_collision = (z_ee < table_z) or (z_ee < floor_z);

  // ---- Synchronized 125 Hz state/command/sensor traces ----
  when sample(0.0, 0.008) then
    t_s = time;
    q1_s = q1;
    q2_s = q2;
    qd1_s = qd1;
    qd2_s = qd2;
    tau1_s = tau1;
    tau2_s = tau2;
    f_wrist_s = f_wrist_meas;
    track_err_s = track_err;
    mp_s = mp_eff;
  end when;

  annotation (experiment(StopTime=12.0, Tolerance=1e-6, Interval=0.008));
end DuoArmCarryC;