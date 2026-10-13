model ForkArmTraceD
  // ---------- Physical embodiment ----------
  parameter Real m_pedestal = 24.0 "kg, fixed-base pedestal mass";
  parameter Real m_mast     = 7.0  "kg, moving revolute-Z mast body";
  parameter Real m_boom     = 3.0  "kg, moving revolute-X camera boom body";
  parameter Real m_slide    = 2.0  "kg, moving prismatic-Y tool slide body";

  // Effective inertias / masses of the three moving branches about their joints
  parameter Real J1 = 0.80 "kg.m2, mast inertia about Z";
  parameter Real J2 = 0.15 "kg.m2, boom inertia about X";
  parameter Real J3 = m_slide "kg, slide translational mass";
  parameter Real b1 = 0.50 "N.m.s/rad, mast viscous damping";
  parameter Real b2 = 0.20 "N.m.s/rad, boom viscous damping";
  parameter Real b3 = 5.00 "N.s/m, slide viscous damping";
  parameter Real L_boom = 0.80 "m, boom radial offset from mast axis";
  parameter Real h_ped   = 1.20 "m, pedestal height";

  // ---------- Actuator effort limits ----------
  parameter Real tau_rev_max  = 80.0  "N.m, revolute actuator limit";
  parameter Real f_pris_max   = 700.0 "N, prismatic actuator limit";

  // ---------- Cylindrical keep-out obstacle (beside nominal path) ----------
  parameter Real obs_x = 0.60 "m, cylinder center x";
  parameter Real obs_y = 0.80 "m, cylinder center y";
  parameter Real obs_r = 0.10 "m, cylinder radius";

  // ---------- Trajectory: three reachable states, stop at last ----------
  parameter Real q1_wp[3] = {0.00, 0.50, 1.00} "rad, mast waypoints";
  parameter Real q2_wp[3] = {0.00, 0.30, 0.50} "rad, boom waypoints";
  parameter Real q3_wp[3] = {0.20, 0.50, 0.80} "m, slide waypoints";
  parameter Real T_seg = 14.0/3.0 "s, per-segment duration (two segments, then hold)";
  parameter Real T_end = 14.0 "s, simulation horizon";

  // ---------- 200 Hz synchronized sampling ----------
  parameter Real Ts = 1.0/200.0 "s, sample period";

  // ---------- PID + velocity-feedforward gains ----------
  parameter Real Kp1=120.0, Ki1=15.0, Kd1=6.0, Kvff1=0.80;
  parameter Real Kp2=40.0,  Ki2=6.0,  Kd2=2.5, Kvff2=0.25;
  parameter Real Kp3=180.0, Ki3=40.0, Kd3=12.0, Kvff3=2.00;

  // ---------- Joint limits ----------
  parameter Real q1_lo=-1.50, q1_hi=1.50 "rad";
  parameter Real q2_lo=-1.20, q2_hi=1.20 "rad";
  parameter Real q3_lo= 0.00, q3_hi=1.00 "m";
  parameter Real obs_clear_min = 0.05 "m, required clearance";
  parameter Real overshoot_max = 0.12 "fraction";
  parameter Real err_thresh   = 0.05 "rad-or-m, primary tracking after 9.1 s";

  // ---------- States ----------
  Real q1(start=q1_wp[1], fixed=true) "rad, mast angle";
  Real qd1(start=0.0, fixed=true) "rad/s, mast velocity";
  Real q2(start=q2_wp[1], fixed=true) "rad, boom angle";
  Real qd2(start=0.0, fixed=true) "rad/s, boom velocity";
  Real q3(start=q3_wp[1], fixed=true) "m, slide position";
  Real qd3(start=0.0, fixed=true) "m/s, slide velocity";

  // ---------- Control outputs (saturated effort) ----------
  Real tau1 "N.m, mast torque";
  Real tau2 "N.m, boom torque";
  Real tau3 "N, slide force";
  Real tau1_raw "N.m, unsaturated mast command";
  Real tau2_raw "N.m, unsaturated boom command";
  Real tau3_raw "N, unsaturated slide command";

  // ---------- Disturbance ----------
  Real disturbance "N, lateral disturbance on slide (middle third)";

  // ---------- Reference trajectory ----------
  Real q1_ref, qd1_ref "rad, rad/s";
  Real q2_ref, qd2_ref "rad, rad/s";
  Real q3_ref, qd3_ref "m, m/s";

  // ---------- Tracking errors ----------
  Real e1, e2, e3;

  // ---------- PID integrators ----------
  Real ie1(start=0.0, fixed=true);
  Real ie2(start=0.0, fixed=true);
  Real ie3(start=0.0, fixed=true);

  // ---------- Encoders (synchronized samples, zero latency) ----------
  Real enc_q1, enc_qd1;
  Real enc_q2, enc_qd2;
  Real enc_q3, enc_qd3;
  Integer sample_tick(start=0) "count of synchronized 200 Hz samples";

  // ---------- Forward kinematics and obstacle ----------
  Real px "m, tool x";
  Real py "m, tool y";
  Real pz "m, tool z";
  Real obs_clear "m, clearance to keep-out cylinder";

  // ---------- Observable performance traces ----------
  Real e1_abs, e2_abs, e3_abs;
  Real overshoot1, overshoot2, overshoot3;
  Real final_err1, final_err2, final_err3;

equation
  // Synchronized 200 Hz sample tick (for trace synchronization)
  when sample(0, Ts) then
    sample_tick = pre(sample_tick) + 1;
  end when;

  // Ideal synchronized encoder samples (same time base, no transport delay)
  enc_q1 = q1;  enc_qd1 = qd1;
  enc_q2 = q2;  enc_qd2 = qd2;
  enc_q3 = q3;  enc_qd3 = qd3;

  // ---------- Cubic Hermite reference trajectory (zero endpoint velocities) ----------
  q1_ref = if time < T_seg then
              q1_wp[1] + (q1_wp[2] - q1_wp[1])*(3*(time/T_seg)^2 - 2*(time/T_seg)^3)
           elseif time < 2.0*T_seg then
              q1_wp[2] + (q1_wp[3] - q1_wp[2])*(3*((time - T_seg)/T_seg)^2 - 2*((time - T_seg)/T_seg)^3)
           else
              q1_wp[3];
  qd1_ref = if time < T_seg then
              (q1_wp[2] - q1_wp[1])/T_seg*(6.0*(time/T_seg) - 6.0*(time/T_seg)^2)
            elseif time < 2.0*T_seg then
              (q1_wp[3] - q1_wp[2])/T_seg*(6.0*((time - T_seg)/T_seg) - 6.0*((time - T_seg)/T_seg)^2)
            else 0.0;

  q2_ref = if time < T_seg then
              q2_wp[1] + (q2_wp[2] - q2_wp[1])*(3*(time/T_seg)^2 - 2*(time/T_seg)^3)
           elseif time < 2.0*T_seg then
              q2_wp[2] + (q2_wp[3] - q2_wp[2])*(3*((time - T_seg)/T_seg)^2 - 2*((time - T_seg)/T_seg)^3)
           else
              q2_wp[3];
  qd2_ref = if time < T_seg then
              (q2_wp[2] - q2_wp[1])/T_seg*(6.0*(time/T_seg) - 6.0*(time/T_seg)^2)
            elseif time < 2.0*T_seg then
              (q2_wp[3] - q2_wp[2])/T_seg*(6.0*((time - T_seg)/T_seg) - 6.0*((time - T_seg)/T_seg)^2)
            else 0.0;

  q3_ref = if time < T_seg then
              q3_wp[1] + (q3_wp[2] - q3_wp[1])*(3*(time/T_seg)^2 - 2*(time/T_seg)^3)
           elseif time < 2.0*T_seg then
              q3_wp[2] + (q3_wp[3] - q3_wp[2])*(3*((time - T_seg)/T_seg)^2 - 2*((time - T_seg)/T_seg)^3)
           else
              q3_wp[3];
  qd3_ref = if time < T_seg then
              (q3_wp[2] - q3_wp[1])/T_seg*(6.0*(time/T_seg) - 6.0*(time/T_seg)^2)
            elseif time < 2.0*T_seg then
              (q3_wp[3] - q3_wp[2])/T_seg*(6.0*((time - T_seg)/T_seg) - 6.0*((time - T_seg)/T_seg)^2)
            else 0.0;

  // ---------- Tracking errors ----------
  e1 = q1_ref - enc_q1;
  e2 = q2_ref - enc_q2;
  e3 = q3_ref - enc_q3;
  e1_abs = abs(e1);
  e2_abs = abs(e2);
  e3_abs = abs(e3);

  // ---------- PID + velocity-feedforward control (unsaturated) ----------
  tau1_raw = Kp1*e1 + Ki1*ie1 + Kd1*(qd1_ref - enc_qd1) + Kvff1*qd1_ref;
  tau2_raw = Kp2*e2 + Ki2*ie2 + Kd2*(qd2_ref - enc_qd2) + Kvff2*qd2_ref;
  tau3_raw = Kp3*e3 + Ki3*ie3 + Kd3*(qd3_ref - enc_qd3) + Kvff3*qd3_ref;

  // ---------- Saturated effort actuators ----------
  tau1 = if tau1_raw >  tau_rev_max then  tau_rev_max
         elseif tau1_raw < -tau_rev_max then -tau_rev_max
         else tau1_raw;
  tau2 = if tau2_raw >  tau_rev_max then  tau_rev_max
         elseif tau2_raw < -tau_rev_max then -tau_rev_max
         else tau2_raw;
  tau3 = if tau3_raw >  f_pris_max then  f_pris_max
         elseif tau3_raw < -f_pris_max then -f_pris_max
         else tau3_raw;

  // ---------- Integrator anti-windup ----------
  der(ie1) = if ((tau1_raw >  tau_rev_max and e1 > 0.0) or
                 (tau1_raw < -tau_rev_max and e1 < 0.0)) then 0.0 else e1;
  der(ie2) = if ((tau2_raw >  tau_rev_max and e2 > 0.0) or
                 (tau2_raw < -tau_rev_max and e2 < 0.0)) then 0.0 else e2;
  der(ie3) = if ((tau3_raw >  f_pris_max and e3 > 0.0) or
                 (tau3_raw < -f_pris_max and e3 < 0.0)) then 0.0 else e3;

  // ---------- Plant dynamics ----------
  J1*der(qd1) = tau1 - b1*qd1;
  der(q1) = qd1;
  J2*der(qd2) = tau2 - b2*qd2;
  der(q2) = qd2;
  J3*der(qd3) = tau3 - b3*qd3 + disturbance;
  der(q3) = qd3;

  // ---------- Controlled 10 N lateral disturbance during middle third ----------
  disturbance = if (time >= T_seg and time <= 2.0*T_seg) then 10.0 else 0.0;

  // ---------- Forward kinematics (tool point) ----------
  px = (L_boom + q3)*cos(q2)*cos(q1);
  py = (L_boom + q3)*cos(q2)*sin(q1);
  pz = h_ped  + (L_boom + q3)*sin(q2);

  // ---------- Obstacle clearance (radial distance minus cylinder radius) ----------
  // sqrt guarded against zero-division via max(...) floor
  obs_clear = sqrt(max((px - obs_x)^2 + (py - obs_y)^2, 1.0e-9)) - obs_r;

  // ---------- Per-joint overshoot relative to last-segment travel ----------
  overshoot1 = max(0.0, (q1 - q1_wp[3]))/(abs(q1_wp[3] - q1_wp[1]) + 1.0e-9);
  overshoot2 = max(0.0, (q2 - q2_wp[3]))/(abs(q2_wp[3] - q2_wp[1]) + 1.0e-9);
  overshoot3 = max(0.0, (q3 - q3_wp[3]))/(abs(q3_wp[3] - q3_wp[1]) + 1.0e-9);

  // ---------- Terminal settling traces (computed continuously; valid near T_end) ----------
  final_err1 = if time >= 9.1 then abs(q1 - q1_wp[3]) else 0.0;
  final_err2 = if time >= 9.1 then abs(q2 - q2_wp[3]) else 0.0;
  final_err3 = if time >= 9.1 then abs(q3 - q3_wp[3]) else 0.0;

  // ---------- Requirement assertions ----------
  assert(q1 >= q1_lo and q1 <= q1_hi, "mast joint limit violated");
  assert(q2 >= q2_lo and q2 <= q2_hi, "boom joint limit violated");
  assert(q3 >= q3_lo and q3 <= q3_hi, "slide joint limit violated");
  assert(obs_clear >= obs_clear_min, "obstacle clearance below 0.05 m");
  assert(overshoot1 <= overshoot_max and
         overshoot2 <= overshoot_max and
         overshoot3 <= overshoot_max, "overshoot exceeds 12 percent");
  assert(time < 9.1 or
         (final_err1 <= err_thresh and
          final_err2 <= err_thresh and
          final_err3 <= err_thresh),
         "primary tracking error exceeds 0.05 rad-or-m after 9.1 s");

  annotation (
    experiment(StartTime=0.0, StopTime=14.0, Tolerance=1.0e-6,
               Interval=1.0/200.0),
    Documentation(info="ForkArmTraceD: instrumented fixed-base articulated manipulator
      (revolute-Z mast, revolute-X camera boom, prismatic-Y tool slide).
      PID plus velocity-feedforward trajectory control follows a time-indexed
      cubic Hermite joint trajectory through three reachable states and holds
      the last state. A 10 N lateral disturbance is applied during the middle
      third. Synchronized 200 Hz encoder samples of joint position and velocity,
      command effort, and state traces are retained. A fixed cylindrical
      keep-out obstacle is placed beside (not on) the nominal motion path."));
end ForkArmTraceD;