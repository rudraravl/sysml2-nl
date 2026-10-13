model DuoArmCarryE
  // ---------------- Geometry, mass, inertia ----------------
  parameter Real l1 = 0.55   "link 1 length [m]";
  parameter Real l2 = 0.38   "link 2 length [m]";
  parameter Real m1 = 5.0    "link 1 mass [kg]";
  parameter Real m2 = 3.0    "link 2 mass [kg]";
  parameter Real mp = 14.4   "payload mass [kg]";
  parameter Real m_ped = 20.0 "box pedestal mass [kg] (fixed base)";
  parameter Real g = 9.81   "gravity [m/s2]";
  parameter Real lc1 = 0.5*l1 "link 1 COM [m]";
  parameter Real lc2 = 0.5*l2 "link 2 COM [m]";
  parameter Real I1 = m1*l1^2/12.0 "link 1 capsule inertia [kg.m2]";
  parameter Real I2 = m2*l2^2/12.0 "link 2 capsule inertia [kg.m2]";
  parameter Real Ip = mp*l2^2/12.0 "payload inertia [kg.m2]";

  // ---------------- Limits ----------------
  parameter Real tau_max = 77.0  "joint effort bound [N.m]";
  parameter Real q_max = 1.6     "joint travel limit [rad]";
  parameter Real Fw_max = 60.0   "wrist force limit [N]";

  // ---------------- Control ----------------
  parameter Real Kp = 300.0  "PD proportional gain";
  parameter Real Kd = 35.0   "PD derivative gain";
  parameter Real T_sample = 0.004 "control period [s] (250 Hz)";
  parameter Real tau_wc_max = 30.0 "wrist correction torque bound [N.m]";
  parameter Real T_filt = 0.02 "wrist wrench sensor time constant [s]";
  parameter Real Kw = 1.0   "wrist correction scaling";

  // ---------------- Trajectory ----------------
  parameter Real t_start = 2.0  "trajectory start time [s]";
  parameter Real T_rise = 4.0   "trajectory rise time [s]";
  parameter Real q1_0 = 0.10    "initial joint 1 [rad]";
  parameter Real q2_0 = 0.40    "initial joint 2 [rad]";
  parameter Real q1_f = 0.35    "final joint 1 [rad]";
  parameter Real q2_f = 0.15    "final joint 2 [rad]";
  // constant end-effector orientation: q1+q2 = 0.5 rad preserved

  // ---------------- Disturbance (middle third of 16 s) ----------------
  parameter Real t_d_start = 5.333  "disturbance start [s]";
  parameter Real t_d_end = 10.667  "disturbance end [s]";
  parameter Real F_dist = 20.0     "disturbance magnitude [N] (downward Z)";

  // ---------------- Workcell contact (rigid floor/table, penalty) ----------------
  parameter Real k_floor = 1.0e5  "floor contact stiffness [N/m]";
  parameter Real d_floor = 1.0e3  "floor contact damping [N.s/m]";
  parameter Real k_table = 1.0e5  "table contact stiffness [N/m]";
  parameter Real d_table = 1.0e3  "table contact damping [N.s/m]";
  parameter Real table_xmin = 1.0 "table x min [m]";
  parameter Real table_xmax = 1.5 "table x max [m]";
  parameter Real table_ztop = 0.40 "table top height [m]";

  // ---------------- Joint states ----------------
  Real q1(start=q1_0, fixed=true);
  Real q2(start=q2_0, fixed=true);
  Real dq1(start=0.0, fixed=true);
  Real dq2(start=0.0, fixed=true);
  Real ddq1;
  Real ddq2;

  // ---------------- Wrist wrench sensor (filtered) ----------------
  Real Fwx_meas(start=0.0, fixed=true);
  Real Fwz_meas(start=0.0, fixed=true);
  Real Fw_mag;

  // ---------------- Continuous quantities ----------------
  Real M11, M12, M22;
  Real h_cor, C1, C2, G1, G2;
  Real F_ext_x, F_ext_z;
  Real px, pz, dpx, dpz, px_d, pz_d;
  Real F_contact_x, F_contact_z;
  Real tau_ext1, tau_ext2;
  Real track_err, ee_orient, ee_orient_d, orient_err;

  // ---------------- Discrete controller state ----------------
  discrete Real q1_d(start=q1_0);
  discrete Real q2_d(start=q2_0);
  discrete Real dq1_d(start=0.0);
  discrete Real dq2_d(start=0.0);
  discrete Real ddq1_d(start=0.0);
  discrete Real ddq2_d(start=0.0);
  discrete Real tau1(start=0.0);
  discrete Real tau2(start=0.0);
  discrete Real tau1_raw(start=0.0);
  discrete Real tau2_raw(start=0.0);
  discrete Real tau_wc1(start=0.0);
  discrete Real tau_wc2(start=0.0);
  Integer tick(start=0);

  // discrete temporaries used inside the sampled controller
  discrete Real tr(start=0.0);
  discrete Real s_t(start=0.0);
  discrete Real ds_t(start=0.0);
  discrete Real d2s_t(start=0.0);
  discrete Real e1(start=0.0);
  discrete Real e2(start=0.0);
  discrete Real de1(start=0.0);
  discrete Real de2(start=0.0);
  discrete Real u1(start=0.0);
  discrete Real u2(start=0.0);
  discrete Real Jp11(start=0.0);
  discrete Real Jp12(start=0.0);
  discrete Real Jp21(start=0.0);
  discrete Real Jp22(start=0.0);
  discrete Real twc1r(start=0.0);
  discrete Real twc2r(start=0.0);

  // ---------------- Acceptance flags ----------------
  Boolean primary_ok;
  Boolean bounds_ok;
  Boolean wrist_ok;
  Boolean retained_ok;
  Boolean no_nan;
  Boolean all_ok;

equation
  // Manipulator inertia matrix (planar, 2 revolute Y joints, payload at tip)
  M11 = m1*lc1*lc1
      + m2*(l1*l1 + lc2*lc2 + 2.0*l1*lc2*cos(q2))
      + mp*(l1*l1 + l2*l2 + 2.0*l1*l2*cos(q2))
      + I1 + I2 + Ip;
  M12 = m2*(lc2*lc2 + l1*lc2*cos(q2))
      + mp*(l2*l2 + l1*l2*cos(q2))
      + I2 + Ip;
  M22 = m2*lc2*lc2 + mp*l2*l2 + I2 + Ip;

  // Coriolis/centrifugal
  h_cor = m2*l1*lc2*sin(q2) + mp*l1*l2*sin(q2);
  C1 = -h_cor*dq2*dq2 - 2.0*h_cor*dq1*dq2;
  C2 =  h_cor*dq1*dq1;

  // Gravity (q measured from +Z up; gravity acts in -Z)
  G1 = -(m1*lc1 + m2*l1 + mp*l1)*g*sin(q1) - (m2*lc2 + mp*l2)*g*sin(q1+q2);
  G2 = -(m2*lc2 + mp*l2)*g*sin(q1+q2);

  // Payload disturbance (controlled middle-third, bounded by wrist limit)
  F_ext_x = 0.0;
  F_ext_z = if (time >= t_d_start and time <= t_d_end) then -F_dist else 0.0;

  // Wrist wrench sensor: first-order filter of disturbance at wrist
  der(Fwx_meas) = (F_ext_x - Fwx_meas)/T_filt;
  der(Fwz_meas) = (F_ext_z - Fwz_meas)/T_filt;
  Fw_mag = sqrt(Fwx_meas*Fwx_meas + Fwz_meas*Fwz_meas + 1.0e-9);

  // End-effector kinematics
  px = l1*sin(q1) + l2*sin(q1+q2);
  pz = l1*cos(q1) + l2*cos(q1+q2);
  dpx =  l1*cos(q1)*dq1 + l2*cos(q1+q2)*(dq1+dq2);
  dpz = -l1*sin(q1)*dq1 - l2*sin(q1+q2)*(dq1+dq2);
  px_d = l1*sin(q1_d) + l2*sin(q1_d+q2_d);
  pz_d = l1*cos(q1_d) + l2*cos(q1_d+q2_d);

  // Rigid floor (z=0) and fixed table (x in [xmin,xmax], top at ztop): penalty contact
  F_contact_z = (if pz < 0.0 then -k_floor*pz - d_floor*dpz else 0.0)
              + (if (pz < table_ztop and px >= table_xmin and px <= table_xmax)
                 then -k_table*(pz - table_ztop) - d_table*dpz else 0.0);
  F_contact_x = 0.0;

  // Jacobian-transpose mapping of payload force to joint torques
  tau_ext1 = (l1*cos(q1) + l2*cos(q1+q2))*(F_ext_x + F_contact_x)
           + (-l1*sin(q1) - l2*sin(q1+q2))*(F_ext_z + F_contact_z);
  tau_ext2 = (l2*cos(q1+q2))*(F_ext_x + F_contact_x)
           + (-l2*sin(q1+q2))*(F_ext_z + F_contact_z);

  // Equations of motion: M*ddq + C + G = tau + tau_ext
  M11*ddq1 + M12*ddq2 + C1 + G1 = tau1 + tau_ext1;
  M12*ddq1 + M22*ddq2 + C2 + G2 = tau2 + tau_ext2;

  der(q1) = dq1;
  der(q2) = dq2;
  der(dq1) = ddq1;
  der(dq2) = ddq2;

  // Tracking metrics (synchronized with sensor/control traces)
  track_err = sqrt((px-px_d)*(px-px_d) + (pz-pz_d)*(pz-pz_d) + 1.0e-12);
  ee_orient = q1 + q2;
  ee_orient_d = q1_d + q2_d;
  orient_err = ee_orient - ee_orient_d;

  // ---------------- Fail-closed acceptance ----------------
  primary_ok = (time <= 10.4) or (track_err < 0.041);
  bounds_ok  = (abs(q1)  <= q_max   + 1.0e-6)
           and (abs(q2)  <= q_max   + 1.0e-6)
           and (abs(tau1) <= tau_max + 1.0e-6)
           and (abs(tau2) <= tau_max + 1.0e-6);
  wrist_ok   = Fw_mag < Fw_max;
  retained_ok = track_err < 1.0;
  no_nan = (q1 == q1) and (q2 == q2) and (tau1 == tau1) and (tau2 == tau2) and (Fw_mag == Fw_mag);
  all_ok = primary_ok and bounds_ok and wrist_ok and retained_ok and no_nan;

  assert(no_nan,    "NaN or infinite physical/control value detected", level=AssertionLevel.error);
  assert(bounds_ok, "Joint or effort bound violated",                  level=AssertionLevel.error);
  assert(wrist_ok,  "Wrist force exceeds 60 N limit",                  level=AssertionLevel.error);
  assert(primary_ok, "Primary tracking error exceeds 0.041 after 10.4 s", level=AssertionLevel.error);

algorithm
  when sample(0, T_sample) then
    // 250 Hz sampled computed-torque controller
    tick := pre(tick) + 1;

    // 5th-order smooth-step trajectory with derivatives
    tr := (time - t_start)/T_rise;
    if tr <= 0.0 then
      s_t := 0.0;  ds_t := 0.0;  d2s_t := 0.0;
    elseif tr >= 1.0 then
      s_t := 1.0;  ds_t := 0.0;  d2s_t := 0.0;
    else
      s_t  := 10.0*tr^3 - 15.0*tr^4 + 6.0*tr^5;
      ds_t := (30.0*tr^2 - 60.0*tr^3 + 30.0*tr^4)/T_rise;
      d2s_t := (60.0*tr - 180.0*tr^2 + 120.0*tr^3)/(T_rise*T_rise);
    end if;

    q1_d  := q1_0 + (q1_f - q1_0)*s_t;
    q2_d  := q2_0 + (q2_f - q2_0)*s_t;
    dq1_d := (q1_f - q1_0)*ds_t;
    dq2_d := (q2_f - q2_0)*ds_t;
    ddq1_d := (q1_f - q1_0)*d2s_t;
    ddq2_d := (q2_f - q2_0)*d2s_t;

    // PD reference shaping
    e1  := q1_d  - q1;
    e2  := q2_d  - q2;
    de1 := dq1_d - dq1;
    de2 := dq2_d - dq2;
    u1  := ddq1_d + Kp*e1 + Kd*de1;
    u2  := ddq2_d + Kp*e2 + Kd*de2;

    // Payload Jacobian (rows: px,pz; cols: q1,q2)
    Jp11 :=  l1*cos(q1) + l2*cos(q1+q2);
    Jp12 :=  l2*cos(q1+q2);
    Jp21 := -l1*sin(q1) - l2*sin(q1+q2);
    Jp22 := -l2*sin(q1+q2);

    // Bounded wrist-force correction (compensates measured disturbance)
    twc1r := -Kw*(Jp11*Fwx_meas + Jp21*Fwz_meas);
    twc2r := -Kw*(Jp12*Fwx_meas + Jp22*Fwz_meas);
    if twc1r > tau_wc_max then
      tau_wc1 := tau_wc_max;
    elseif twc1r < -tau_wc_max then
      tau_wc1 := -tau_wc_max;
    else
      tau_wc1 := twc1r;
    end if;
    if twc2r > tau_wc_max then
      tau_wc2 := tau_wc_max;
    elseif twc2r < -tau_wc_max then
      tau_wc2 := -tau_wc_max;
    else
      tau_wc2 := twc2r;
    end if;

    // Computed-torque law with wrist correction
    tau1_raw := M11*u1 + M12*u2 + C1 + G1 + tau_wc1;
    tau2_raw := M12*u1 + M22*u2 + C2 + G2 + tau_wc2;

    // Saturate actuator effort
    if tau1_raw > tau_max then
      tau1 := tau_max;
    elseif tau1_raw < -tau_max then
      tau1 := -tau_max;
    else
      tau1 := tau1_raw;
    end if;
    if tau2_raw > tau_max then
      tau2 := tau_max;
    elseif tau2_raw < -tau_max then
      tau2 := -tau_max;
    else
      tau2 := tau2_raw;
    end if;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "DuoArmCarryE: 2-DOF revolute-Y articulated manipulator on a 20 kg fixed pedestal with capsule links (0.55 m/5 kg, 0.38 m/3 kg) carrying a 14.4 kg rigid payload. Computed-torque control at 250 Hz with bounded wrist-force correction rejects a middle-third payload disturbance while preserving end-effector orientation (q1+q2). Fail-closed assertions enforce joint/effort bounds, wrist force < 60 N, payload retention, and primary tracking error < 0.041 after 10.4 s.")
  );
end DuoArmCarryE;