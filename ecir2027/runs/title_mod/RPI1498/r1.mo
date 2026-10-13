model GimbalPathSmoothD
  "Instrumented trajectory-controlled yaw-pitch-roll gimbal.
   Facts not stated in the requirement are marked as selected finite placeholders,
   not asserted facts. No estimator was requested, so none is included."

  constant Real pi = 3.141592653589793;

  // Run and controller timing
  parameter Real Ts(unit="s") = 0.005 "controller and sensor sample rate, 200 Hz";
  parameter Real tEnd(unit="s") = 14.0 "simulation duration";
  parameter Real T_move(unit="s") = 8.0 "selected move duration; not specified by requirement";

  // Camera and inertia placeholder
  parameter Real m_camera(unit="kg") = 4.0 "camera mass from requirement";
  parameter Real rgyr(unit="m") = 0.5 "placeholder radius of gyration; gimbal geometry not specified";
  parameter Real J_nom(unit="kg.m2") = m_camera*rgyr^2 "diagonal nominal inertia placeholder";
  parameter Real disturbanceFraction = 0.08 "controlled inertia-change disturbance";
  parameter Real rampT(unit="s") = 0.5 "smooth ramp for inertia disturbance";

  // Joint limits from requirement
  parameter Real yawMax(unit="rad") = 2.8;
  parameter Real yawMin(unit="rad") = -2.8;
  parameter Real pitchMax(unit="rad") = 1.0;
  parameter Real pitchMin(unit="rad") = -1.2;
  parameter Real rollMax(unit="rad") = 0.8;
  parameter Real rollMin(unit="rad") = -0.8;

  // Actuator bound from requirement
  parameter Real tauMax(unit="N.m") = 20.0;
  parameter Real fbMax(unit="N.m") = 20.0 "bounded feedback correction magnitude";

  // Selected trajectory endpoints, chosen within stated joint limits
  parameter Real q0_1(unit="rad") = 0.0 "selected yaw start";
  parameter Real q0_2(unit="rad") = 0.0 "selected pitch start";
  parameter Real q0_3(unit="rad") = 0.0 "selected roll start";
  parameter Real qf_1(unit="rad") = 1.0 "selected yaw terminal state";
  parameter Real qf_2(unit="rad") = -0.5 "selected pitch terminal state";
  parameter Real qf_3(unit="rad") = 0.3 "selected roll terminal state";
  parameter Real d1(unit="rad") = qf_1 - q0_1;
  parameter Real d2(unit="rad") = qf_2 - q0_2;
  parameter Real d3(unit="rad") = qf_3 - q0_3;

  // Controller gains
  parameter Real Kp(unit="N.m/rad") = 100.0;
  parameter Real Kd(unit="N.m.s/rad") = 20.0;

  // Middle third of the 14 s run
  parameter Real tMidStart(unit="s") = tEnd/3;
  parameter Real tMidEnd(unit="s") = 2*tEnd/3;

  // Fixed keep-out object, modeled as a configuration-space exclusion zone.
  // Object geometry is not specified; selected zone is outside the nominal path.
  parameter Real qko1(unit="rad") = -2.7;
  parameter Real qko2(unit="rad") = 1.0;
  parameter Real qko3(unit="rad") = -0.8;
  parameter Real keepoutRadius(unit="rad") = 0.3;

  // Plant state variables
  Real q1(unit="rad"), v1(unit="rad/s"), a1(unit="rad/s2");
  Real q2(unit="rad"), v2(unit="rad/s"), a2(unit="rad/s2");
  Real q3(unit="rad"), v3(unit="rad/s"), a3(unit="rad/s2");

  // Desired trajectory and jerk
  Real q_des1(unit="rad"), v_des1(unit="rad/s"), a_des1(unit="rad/s2"), jerk_des1(unit="rad/s3");
  Real q_des2(unit="rad"), v_des2(unit="rad/s"), a_des2(unit="rad/s2"), jerk_des2(unit="rad/s3");
  Real q_des3(unit="rad"), v_des3(unit="rad/s"), a_des3(unit="rad/s2"), jerk_des3(unit="rad/s3");

  // Inverse-dynamics feedforward, feedback correction, and commands
  Real e1(unit="rad"), ed1(unit="rad/s"), fb1(unit="N.m"), fb1_sat(unit="N.m"), tau1_ff(unit="N.m");
  Real e2(unit="rad"), ed2(unit="rad/s"), fb2(unit="N.m"), fb2_sat(unit="N.m"), tau2_ff(unit="N.m");
  Real e3(unit="rad"), ed3(unit="rad/s"), fb3(unit="N.m"), fb3_sat(unit="N.m"), tau3_ff(unit="N.m");
  discrete Real tau1_cmd(unit="N.m", start=0.0);
  discrete Real tau2_cmd(unit="N.m", start=0.0);
  discrete Real tau3_cmd(unit="N.m", start=0.0);
  Real tau1_act(unit="N.m");
  Real tau2_act(unit="N.m");
  Real tau3_act(unit="N.m");

  // Actual inertia with controlled 8 percent change during middle third
  Real wDist;
  Real J1_act(unit="kg.m2");
  Real J2_act(unit="kg.m2");
  Real J3_act(unit="kg.m2");

  // Controller-rate synchronized sensor and command traces
  discrete Real pos1_s(unit="rad", start=0.0);
  discrete Real pos2_s(unit="rad", start=0.0);
  discrete Real pos3_s(unit="rad", start=0.0);
  discrete Real vel1_s(unit="rad/s", start=0.0);
  discrete Real vel2_s(unit="rad/s", start=0.0);
  discrete Real vel3_s(unit="rad/s", start=0.0);
  discrete Real acc1_s(unit="rad/s2", start=0.0);
  discrete Real acc2_s(unit="rad/s2", start=0.0);
  discrete Real acc3_s(unit="rad/s2", start=0.0);
  discrete Real cmd1_s(unit="N.m", start=0.0);
  discrete Real cmd2_s(unit="N.m", start=0.0);
  discrete Real cmd3_s(unit="N.m", start=0.0);

  // Verification metrics
  discrete Real peakJerk(unit="rad/s3", start=0.0);
  discrete Real trackingErrorS(unit="rad", start=0.0);
  discrete Real overshootS(start=0.0);
  Real trackingError(unit="rad");
  Real overshoot1, overshoot2, overshoot3, overshoot;
  Real keepoutDistSq "squared configuration-space distance to keep-out zone, rad^2";
  Real keepoutDistSqDes "squared nominal-path distance to keep-out zone, rad^2";
  Real clearance(unit="rad");

initial equation
  q1 = q0_1;
  v1 = 0.0;
  q2 = q0_2;
  v2 = 0.0;
  q3 = q0_3;
  v3 = 0.0;

equation
  // Jerk-limited S-curve reference with sine acceleration profile and terminal hold
  q_des1 = if time < T_move then q0_1 + d1*(time/T_move - sin(2*pi*time/T_move)/(2*pi)) else qf_1;
  v_des1 = if time < T_move then d1/T_move*(1 - cos(2*pi*time/T_move)) else 0.0;
  a_des1 = if time < T_move then 2*pi*d1/T_move^2*sin(2*pi*time/T_move) else 0.0;
  jerk_des1 = if time < T_move then 4*pi*pi*d1/T_move^3*cos(2*pi*time/T_move) else 0.0;

  q_des2 = if time < T_move then q0_2 + d2*(time/T_move - sin(2*pi*time/T_move)/(2*pi)) else qf_2;
  v_des2 = if time < T_move then d2/T_move*(1 - cos(2*pi*time/T_move)) else 0.0;
  a_des2 = if time < T_move then 2*pi*d2/T_move^2*sin(2*pi*time/T_move) else 0.0;
  jerk_des2 = if time < T_move then 4*pi*pi*d2/T_move^3*cos(2*pi*time/T_move) else 0.0;

  q_des3 = if time < T_move then q0_3 + d3*(time/T_move - sin(2*pi*time/T_move)/(2*pi)) else qf_3;
  v_des3 = if time < T_move then d3/T_move*(1 - cos(2*pi*time/T_move)) else 0.0;
  a_des3 = if time < T_move then 2*pi*d3/T_move^2*sin(2*pi*time/T_move) else 0.0;
  jerk_des3 = if time < T_move then 4*pi*pi*d3/T_move^3*cos(2*pi*time/T_move) else 0.0;

  // Smooth 8 percent inertia-change window during middle third
  wDist = if time < tMidStart then 0.0
          elseif time > tMidEnd then 0.0
          elseif time < tMidStart + rampT then 0.5*(1 - cos(pi*(time - tMidStart)/rampT))
          elseif time > tMidEnd - rampT then 0.5*(1 + cos(pi*(time - (tMidEnd - rampT))/rampT))
          else 1.0;

  J1_act = J_nom*(1 + disturbanceFraction*wDist);
  J2_act = J_nom*(1 + disturbanceFraction*wDist);
  J3_act = J_nom*(1 + disturbanceFraction*wDist);

  // Decoupled gimbal dynamics with bounded torque actuation
  der(q1) = v1;
  der(v1) = a1;
  a1 = tau1_act/J1_act;

  der(q2) = v2;
  der(v2) = a2;
  a2 = tau2_act/J2_act;

  der(q3) = v3;
  der(v3) = a3;
  a3 = tau3_act/J3_act;

  tau1_act = tau1_cmd;
  tau2_act = tau2_cmd;
  tau3_act = tau3_cmd;

  // Feedforward inverse dynamics and bounded feedback correction
  e1 = q_des1 - q1;
  ed1 = v_des1 - v1;
  fb1 = Kp*e1 + Kd*ed1;
  fb1_sat = max(-fbMax, min(fbMax, fb1));
  tau1_ff = J_nom*a_des1;

  e2 = q_des2 - q2;
  ed2 = v_des2 - v2;
  fb2 = Kp*e2 + Kd*ed2;
  fb2_sat = max(-fbMax, min(fbMax, fb2));
  tau2_ff = J_nom*a_des2;

  e3 = q_des3 - q3;
  ed3 = v_des3 - v3;
  fb3 = Kp*e3 + Kd*ed3;
  fb3_sat = max(-fbMax, min(fbMax, fb3));
  tau3_ff = J_nom*a_des3;

  // Verification metrics
  trackingError = max(abs(q1 - q_des1), max(abs(q2 - q_des2), abs(q3 - q_des3)));
  overshoot1 = max(0.0, (q1 - qf_1)/max(abs(d1), 1e-9));
  overshoot2 = max(0.0, (qf_2 - q2)/max(abs(d2), 1e-9));
  overshoot3 = max(0.0, (q3 - qf_3)/max(abs(d3), 1e-9));
  overshoot = max(overshoot1, max(overshoot2, overshoot3));

  keepoutDistSq = (q1 - qko1)^2 + (q2 - qko2)^2 + (q3 - qko3)^2;
  keepoutDistSqDes = (q_des1 - qko1)^2 + (q_des2 - qko2)^2 + (q_des3 - qko3)^2;
  clearance = sqrt(max(keepoutDistSq, 0.0));

  // Requirement checks
  assert(q1 >= yawMin - 1e-9 and q1 <= yawMax + 1e-9, "yaw state bound violated");
  assert(q2 >= pitchMin - 1e-9 and q2 <= pitchMax + 1e-9, "pitch state bound violated");
  assert(q3 >= rollMin - 1e-9 and q3 <= rollMax + 1e-9, "roll state bound violated");
  assert(abs(tau1_act) <= tauMax + 1e-9, "yaw torque command bound violated");
  assert(abs(tau2_act) <= tauMax + 1e-9, "pitch torque command bound violated");
  assert(abs(tau3_act) <= tauMax + 1e-9, "roll torque command bound violated");
  assert(keepoutDistSq > keepoutRadius^2, "collision with keep-out object");
  assert(keepoutDistSqDes > keepoutRadius^2, "keep-out object not outside nominal path");
  assert(overshoot < 0.10, "overshoot above 10 percent");
  assert(time < 9.1 or trackingError < 0.025, "primary tracking error after 9.1 s too large");
  assert(abs(q1) < 1e9 and abs(v1) < 1e9 and abs(a1) < 1e9 and abs(tau1_cmd) < 1e9, "non-finite yaw values");
  assert(abs(q2) < 1e9 and abs(v2) < 1e9 and abs(a2) < 1e9 and abs(tau2_cmd) < 1e9, "non-finite pitch values");
  assert(abs(q3) < 1e9 and abs(v3) < 1e9 and abs(a3) < 1e9 and abs(tau3_cmd) < 1e9, "non-finite roll values");
  assert(abs(peakJerk) < 1e9, "non-finite peak jerk");

  when sample(0, Ts) then
    // Bounded torque command: feedforward plus saturated feedback, then torque saturation
    tau1_cmd = max(-tauMax, min(tauMax, tau1_ff + fb1_sat));
    tau2_cmd = max(-tauMax, min(tauMax, tau2_ff + fb2_sat));
    tau3_cmd = max(-tauMax, min(tauMax, tau3_ff + fb3_sat));

    // Synchronized state, command, and sensor traces at controller rate
    pos1_s = q1;
    pos2_s = q2;
    pos3_s = q3;
    vel1_s = v1;
    vel2_s = v2;
    vel3_s = v3;
    acc1_s = a1;
    acc2_s = a2;
    acc3_s = a3;
    cmd1_s = tau1_cmd;
    cmd2_s = tau2_cmd;
    cmd3_s = tau3_cmd;

    trackingErrorS = trackingError;
    overshootS = overshoot;
    peakJerk = max(pre(peakJerk), max(abs(jerk_des1), max(abs(jerk_des2), abs(jerk_des3))));
  end when;

  annotation(experiment(StopTime=14, Tolerance=1e-6, Interval=0.005));
end GimbalPathSmoothD;