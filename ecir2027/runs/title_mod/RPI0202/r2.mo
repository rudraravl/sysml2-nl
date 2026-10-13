model RailArmTraceD "Instrumented fixed-base articulated manipulator with cubic trajectory tracking"
  // ---- Plant embodiment parameters (SI units) ----
  parameter Real L1 = 0.46 "link 1 length [m]";
  parameter Real L2 = 0.31 "link 2 length [m]";
  parameter Real mC = 18.0 "carriage mass [kg]";
  parameter Real mL1 = 2.0 "link 1 lumped mass [kg] (assumption: not stated)";
  parameter Real mL2 = 1.0 "link 2 lumped mass [kg] (assumption: not stated)";
  parameter Real railLen = 1.4 "rail length [m]";
  parameter Real qMax = 1.5 "joint limit magnitude [rad]";
  parameter Real Fmax = 800.0 "linear actuator force limit [N]";
  parameter Real tauMax = 85.0 "rotary actuator torque limit [N.m]";
  parameter Real b_x = 20.0 "carriage viscous friction [N.s/m]";
  parameter Real b_q = 1.5 "joint viscous friction [N.m.s/rad]";

  // ---- Run / control rate ----
  parameter Real freq = 200.0 "controller sample rate [Hz]";
  parameter Real Tend = 14.0 "run duration [s]";
  parameter Real dt = 1.0 / freq "sample period [s]";

  // ---- Trajectory waypoints (three reachable states) ----
  parameter Real t_seg1 = 4.6666667 "end of segment 1 (middle-third start) [s]";
  parameter Real t_seg2 = 9.3333333 "end of segment 2 (middle-third end) [s]";
  parameter Real x0 = 0.2  "state 1 carriage x [m]";
  parameter Real q10 = 0.3 "state 1 joint 1 [rad]";
  parameter Real q20 = 0.2 "state 1 joint 2 [rad]";
  parameter Real x1 = 0.7  "state 2 carriage x [m]";
  parameter Real q11 = 0.7 "state 2 joint 1 [rad]";
  parameter Real q21 = 0.4 "state 2 joint 2 [rad]";
  parameter Real x2 = 1.2  "state 3 carriage x [m]";
  parameter Real q12 = 1.0 "state 3 joint 1 [rad]";
  parameter Real q22 = 0.5 "state 3 joint 2 [rad]";

  // ---- Obstacle (cylindrical keep-out, beside nominal path) ----
  parameter Real obsX = 0.5  "obstacle center x [m]";
  parameter Real obsY = -0.40 "obstacle center y [m]";
  parameter Real obsR = 0.08 "obstacle radius [m]";

  // ---- PID + velocity-feedforward gains ----
  parameter Real Kp_x = 525.0;
  parameter Real Ki_x = 100.0;
  parameter Real Kd_x = 210.0;
  parameter Real Kvff_x = 20.0 "velocity feedforward gain x [N.s/m]";
  parameter Real Kp_q1 = 64.0;
  parameter Real Ki_q1 = 30.0;
  parameter Real Kd_q1 = 16.0;
  parameter Real Kvff_q1 = 1.5 "velocity feedforward q1 [N.m.s/rad]";
  parameter Real Kp_q2 = 10.0;
  parameter Real Ki_q2 = 4.0;
  parameter Real Kd_q2 = 2.0;
  parameter Real Kvff_q2 = 1.5 "velocity feedforward q2 [N.m.s/rad]";

  parameter Real Fdist = 10.0 "lateral disturbance magnitude [N]";

  // ---- Continuous plant states ----
  Real x(start=x0, fixed=true) "carriage position on rail [m]";
  Real vx(start=0.0, fixed=true) "carriage velocity [m/s]";
  Real q1(start=q10, fixed=true) "joint 1 angle [rad]";
  Real w1(start=0.0, fixed=true) "joint 1 velocity [rad/s]";
  Real q2(start=q20, fixed=true) "joint 2 angle [rad]";
  Real w2(start=0.0, fixed=true) "joint 2 velocity [rad/s]";

  // ---- Reference trajectory (continuous, for monitoring) ----
  Real x_ref "reference x [m]";
  Real vx_ref "reference vx [m/s]";
  Real q1_ref "reference q1 [rad]";
  Real w1_ref "reference w1 [rad/s]";
  Real q2_ref "reference q2 [rad]";
  Real w2_ref "reference w2 [rad/s]";

  // ---- Commands ----
  Real F_cmd "raw force command [N]";
  Real tau1_cmd "raw joint 1 torque command [N.m]";
  Real tau2_cmd "raw joint 2 torque command [N.m]";
  Real F_sat "applied saturated force [N]";
  Real tau1_sat "applied saturated joint 1 torque [N.m]";
  Real tau2_sat "applied saturated joint 2 torque [N.m]";

  // ---- Disturbance ----
  Real F_dist "applied lateral disturbance force [N]";
  Real tau_d1 "disturbance generalized torque on q1 [N.m]";
  Real tau_d2 "disturbance generalized torque on q2 [N.m]";

  // ---- Forward kinematics ----
  Real ex "end-effector x [m]";
  Real ey "end-effector y [m]";
  Real obs_clear "obstacle clearance (signed) [m]";

  // ---- Effective inertias ----
  Real Ix "effective carriage inertia [kg]";
  Real Iq1 "effective joint 1 inertia [kg.m^2]";
  Real Iq2 "effective joint 2 inertia [kg.m^2]";

  // ---- Synchronized encoder samples (discrete) ----
  discrete Real x_s(start=x0) "sampled carriage position [m]";
  discrete Real vx_s(start=0.0) "sampled carriage velocity [m/s]";
  discrete Real q1_s(start=q10) "sampled joint 1 position [rad]";
  discrete Real w1_s(start=0.0) "sampled joint 1 velocity [rad/s]";
  discrete Real q2_s(start=q20) "sampled joint 2 position [rad]";
  discrete Real w2_s(start=0.0) "sampled joint 2 velocity [rad/s]";

  // Encoder-equivalent observables
  Real x_meas "encoder carriage position [m]" = x_s;
  Real vx_meas "encoder carriage velocity [m/s]" = vx_s;
  Real q1_meas "encoder joint 1 position [rad]" = q1_s;
  Real w1_meas "encoder joint 1 velocity [rad/s]" = w1_s;
  Real q2_meas "encoder joint 2 position [rad]" = q2_s;
  Real w2_meas "encoder joint 2 velocity [rad/s]" = w2_s;

  // ---- Discrete controller state ----
  discrete Real ie_x(start=0.0);
  discrete Real ie_q1(start=0.0);
  discrete Real ie_q2(start=0.0);
  discrete Real prev_e_x(start=0.0);
  discrete Real prev_e_q1(start=0.0);
  discrete Real prev_e_q2(start=0.0);
  discrete Real F_held(start=0.0) "held force command between samples [N]";
  discrete Real tau1_held(start=0.0) "held torque 1 command between samples [N.m]";
  discrete Real tau2_held(start=0.0) "held torque 2 command between samples [N.m]";
  discrete Real x_ref_s(start=x0) "sampled reference x [m]";
  discrete Real vx_ref_s(start=0.0) "sampled reference vx [m/s]";
  discrete Real q1_ref_s(start=q10) "sampled reference q1 [rad]";
  discrete Real w1_ref_s(start=0.0) "sampled reference w1 [rad/s]";
  discrete Real q2_ref_s(start=q20) "sampled reference q2 [rad]";
  discrete Real w2_ref_s(start=0.0) "sampled reference w2 [rad/s]";

  // ---- Performance trace variables ----
  discrete Real min_clear(start=1.0e9) "minimum obstacle clearance observed [m]";
  discrete Real max_abs_q1(start=0.0) "maximum |q1| observed [rad]";
  discrete Real max_abs_q2(start=0.0) "maximum |q2| observed [rad]";
  Real e_x "x tracking error [m]";
  Real e_q1 "q1 tracking error [rad]";
  Real e_q2 "q2 tracking error [rad]";
  Real de_x "x error derivative [m/s]";
  Real de_q1 "q1 error derivative [rad/s]";
  Real de_q2 "q2 error derivative [rad/s]";
  Real err_x_post "primary x tracking error after 9.1 s [m]";
  Real err_q1_post "primary q1 tracking error after 9.1 s [rad]";
  Real err_q2_post "primary q2 tracking error after 9.1 s [rad]";
algorithm
  when sample(0, dt) then
    // Synchronized encoder sampling
    x_s := x;
    vx_s := vx;
    q1_s := q1;
    w1_s := w1;
    q2_s := q2;
    w2_s := w2;

    // Time-indexed cubic trajectory reference at sample instant
    if time <= t_seg1 then
      (x_ref_s, vx_ref_s) := cubicSeg(time, 0.0, t_seg1, x0, x1);
      (q1_ref_s, w1_ref_s) := cubicSeg(time, 0.0, t_seg1, q10, q11);
      (q2_ref_s, w2_ref_s) := cubicSeg(time, 0.0, t_seg1, q20, q21);
    elseif time <= t_seg2 then
      (x_ref_s, vx_ref_s) := cubicSeg(time, t_seg1, t_seg2, x1, x2);
      (q1_ref_s, w1_ref_s) := cubicSeg(time, t_seg1, t_seg2, q11, q12);
      (q2_ref_s, w2_ref_s) := cubicSeg(time, t_seg1, t_seg2, q21, q22);
    else
      x_ref_s := x2;  vx_ref_s := 0.0;
      q1_ref_s := q12; w1_ref_s := 0.0;
      q2_ref_s := q22; w2_ref_s := 0.0;
    end if;

    // Tracking errors
    e_x := x_ref_s - x_s;
    e_q1 := q1_ref_s - q1_s;
    e_q2 := q2_ref_s - q2_s;

    // Discrete derivatives of error
    de_x := (e_x - pre(prev_e_x)) / dt;
    de_q1 := (e_q1 - pre(prev_e_q1)) / dt;
    de_q2 := (e_q2 - pre(prev_e_q2)) / dt;
    prev_e_x := e_x;
    prev_e_q1 := e_q1;
    prev_e_q2 := e_q2;

    // Integral terms with anti-windup clamping
    ie_x := pre(ie_x) + e_x * dt;
    ie_q1 := pre(ie_q1) + e_q1 * dt;
    ie_q2 := pre(ie_q2) + e_q2 * dt;
    if ie_x > 50.0 then ie_x := 50.0; elseif ie_x < -50.0 then ie_x := -50.0; end if;
    if ie_q1 > 20.0 then ie_q1 := 20.0; elseif ie_q1 < -20.0 then ie_q1 := -20.0; end if;
    if ie_q2 > 10.0 then ie_q2 := 10.0; elseif ie_q2 < -10.0 then ie_q2 := -10.0; end if;

    // PID plus velocity-feedforward commands
    F_cmd := Kp_x * e_x + Ki_x * ie_x + Kd_x * de_x + Kvff_x * vx_ref_s;
    tau1_cmd := Kp_q1 * e_q1 + Ki_q1 * ie_q1 + Kd_q1 * de_q1 + Kvff_q1 * w1_ref_s;
    tau2_cmd := Kp_q2 * e_q2 + Ki_q2 * ie_q2 + Kd_q2 * de_q2 + Kvff_q2 * w2_ref_s;

    // Actuator saturation
    if F_cmd > Fmax then
      F_held := Fmax;
    elseif F_cmd < -Fmax then
      F_held := -Fmax;
    else
      F_held := F_cmd;
    end if;
    if tau1_cmd > tauMax then
      tau1_held := tauMax;
    elseif tau1_cmd < -tauMax then
      tau1_held := -tauMax;
    else
      tau1_held := tau1_cmd;
    end if;
    if tau2_cmd > tauMax then
      tau2_held := tauMax;
    elseif tau2_cmd < -tauMax then
      tau2_held := -tauMax;
    else
      tau2_held := tau2_cmd;
    end if;

    // Performance trace updates
    if (sqrt((ex - obsX) * (ex - obsX) + (ey - obsY) * (ey - obsY)) - obsR) < pre(min_clear) then
      min_clear := sqrt((ex - obsX) * (ex - obsX) + (ey - obsY) * (ey - obsY)) - obsR;
    end if;
    if abs(q1) > pre(max_abs_q1) then
      max_abs_q1 := abs(q1);
    end if;
    if abs(q2) > pre(max_abs_q2) then
      max_abs_q2 := abs(q2);
    end if;
  end when;
equation
  // Effective inertias (lumped-mass approximation)
  Ix = mC + mL1 + mL2;
  Iq1 = mL1 * L1 * L1 + mL2 * (L1 + L2) * (L1 + L2);
  Iq2 = mL2 * L2 * L2;

  // Planar forward kinematics (arm in vertical x-y plane)
  ex = x + L1 * cos(q1) + L2 * cos(q1 + q2);
  ey = L1 * sin(q1) + L2 * sin(q1 + q2);
  obs_clear = sqrt((ex - obsX) * (ex - obsX) + (ey - obsY) * (ey - obsY)) - obsR;

  // Lateral (y-direction) disturbance during middle third of run
  F_dist = if (time >= t_seg1 and time <= t_seg2) then Fdist else 0.0;
  tau_d1 = F_dist * (L1 * cos(q1) + L2 * cos(q1 + q2));
  tau_d2 = F_dist * (L2 * cos(q1 + q2));

  // Held (zero-order) actuator commands drive the plant
  F_sat = F_held;
  tau1_sat = tau1_held;
  tau2_sat = tau2_held;

  // Plant dynamics
  der(x) = vx;
  der(q1) = w1;
  der(q2) = w2;
  Ix * der(vx) = F_sat - b_x * vx;
  Iq1 * der(w1) = tau1_sat - b_q * w1 + tau_d1;
  Iq2 * der(w2) = tau2_sat - b_q * w2 + tau_d2;

  // Continuous reference trajectory (event-generating at segment boundaries)
  if time <= t_seg1 then
    (x_ref, vx_ref) = cubicSeg(time, 0.0, t_seg1, x0, x1);
    (q1_ref, w1_ref) = cubicSeg(time, 0.0, t_seg1, q10, q11);
    (q2_ref, w2_ref) = cubicSeg(time, 0.0, t_seg1, q20, q21);
  elseif time <= t_seg2 then
    (x_ref, vx_ref) = cubicSeg(time, t_seg1, t_seg2, x1, x2);
    (q1_ref, w1_ref) = cubicSeg(time, t_seg1, t_seg2, q11, q12);
    (q2_ref, w2_ref) = cubicSeg(time, t_seg1, t_seg2, q21, q22);
  else
    x_ref = x2;  vx_ref = 0.0;
    q1_ref = q12; w1_ref = 0.0;
    q2_ref = q22; w2_ref = 0.0;
  end if;

  // Primary tracking error observables after settling time 9.1 s
  err_x_post = if time >= 9.1 then x_ref - x else 0.0;
  err_q1_post = if time >= 9.1 then q1_ref - q1 else 0.0;
  err_q2_post = if time >= 9.1 then q2_ref - q2 else 0.0;

  // Requirement assertions (continuous monitoring)
  assert(q1 >= -qMax and q1 <= qMax, "Joint 1 limit violated");
  assert(q2 >= -qMax and q2 <= qMax, "Joint 2 limit violated");
  assert(obs_clear > 0.05, "Obstacle clearance below 0.05 m");
  assert(x >= 0.0 and x <= railLen, "Carriage off rail");
  assert(abs(err_x_post) < 0.05 or time < 9.1, "Primary x tracking error exceeded after 9.1 s");
  assert(abs(err_q1_post) < 0.05 or time < 9.1, "Primary q1 tracking error exceeded after 9.1 s");
  assert(abs(err_q2_post) < 0.05 or time < 9.1, "Primary q2 tracking error exceeded after 9.1 s");

  annotation(experiment(StopTime=14.0, Tolerance=1e-6));
end RailArmTraceD;

function cubicSeg "Cubic Hermite trajectory segment with zero endpoint velocities"
  input Real t "current time [s]";
  input Real t0 "segment start time [s]";
  input Real t1 "segment end time [s]";
  input Real p0 "start position";
  input Real p1 "end position";
  output Real p "position at t";
  output Real v "velocity at t";
protected
  Real tau "normalized time";
algorithm
  if t <= t0 then
    p := p0;
    v := 0.0;
  elseif t >= t1 then
    p := p1;
    v := 0.0;
  else
    tau := (t - t0) / (t1 - t0);
    p := p0 + (p1 - p0) * (3.0 * tau * tau - 2.0 * tau * tau * tau);
    v := (p1 - p0) * (6.0 * tau - 6.0 * tau * tau) / (t1 - t0);
  end if;
end cubicSeg;