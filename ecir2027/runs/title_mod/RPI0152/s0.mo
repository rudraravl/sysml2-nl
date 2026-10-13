model SCARATraceB
  // Physical parameters
  parameter Real m_base = 28.0 "kg fixed cylindrical base mass";
  parameter Real L1 = 0.48 "m first revolute Z link length";
  parameter Real L2 = 0.34 "m second revolute Z link length";
  parameter Real m1 = 6.0 "kg first link moving mass";
  parameter Real m2 = 4.0 "kg second link moving mass";
  parameter Real m3 = 2.0 "kg prismatic carriage mass";
  parameter Real travel = 0.30 "m prismatic Z travel";
  parameter Real g = 9.81 "m/s2 gravitational acceleration";

  // Actuator saturation limits
  parameter Real tau_max_rot = 77.9 "N.m max revolute actuator torque";
  parameter Real tau_max_pris = 900.0 "N max prismatic actuator force";

  // Effective joint inertias and viscous friction
  parameter Real J1 = 0.50 "kg.m2 effective inertia joint 1";
  parameter Real J2 = 0.15 "kg.m2 effective inertia joint 2";
  parameter Real b1 = 0.80 "N.m.s/rad viscous friction joint 1";
  parameter Real b2 = 0.50 "N.m.s/rad viscous friction joint 2";
  parameter Real b3 = 20.0 "N.s/m viscous friction joint 3";

  // Trajectory waypoints — three reachable states
  parameter Real q1_0 = 0.0 "rad initial joint 1";
  parameter Real q1_1 = 0.7853981633974483 "rad mid joint 1 (pi/4)";
  parameter Real q1_2 = 1.5707963267948966 "rad final joint 1 (pi/2)";
  parameter Real q2_0 = 0.0 "rad initial joint 2";
  parameter Real q2_1 = 0.7853981633974483 "rad mid joint 2 (pi/4)";
  parameter Real q2_2 = 0.0 "rad final joint 2";
  parameter Real q3_0 = 0.0 "m initial joint 3";
  parameter Real q3_1 = 0.15 "m mid joint 3";
  parameter Real q3_2 = 0.30 "m final joint 3";

  // Segment durations
  parameter Real T1 = 5.0 "s first segment duration";
  parameter Real T2 = 5.0 "s second segment duration";

  // Joint limits
  parameter Real q1_min = -3.141592653589793 "rad";
  parameter Real q1_max = 3.141592653589793 "rad";
  parameter Real q2_min = -2.0943951023931953 "rad";
  parameter Real q2_max = 2.0943951023931953 "rad";
  parameter Real q3_min = 0.0 "m";
  parameter Real q3_max = 0.30 "m";

  // Fixed cylindrical keep-out obstacle (beside, not on nominal path)
  parameter Real obs_x = 0.60 "m obstacle center x";
  parameter Real obs_y = -0.20 "m obstacle center y";
  parameter Real obs_r = 0.08 "m obstacle radius";
  parameter Real obs_clearance_min = 0.05 "m required clearance";

  // Lateral disturbance
  parameter Real F_dist = 7.0 "N disturbance magnitude";
  parameter Real t_dist_start = 10.0 / 3.0 "s disturbance start (middle third)";
  parameter Real t_dist_end = 20.0 / 3.0 "s disturbance end (middle third)";

  // PID + velocity feedforward gains — joint 1 (revolute)
  parameter Real Kp1 = 120.0;
  parameter Real Ki1 = 50.0;
  parameter Real Kd1 = 15.0;
  parameter Real ff1 = 0.80;
  parameter Real integ1_max = 2.0;

  // PID + velocity feedforward gains — joint 2 (revolute)
  parameter Real Kp2 = 60.0;
  parameter Real Ki2 = 30.0;
  parameter Real Kd2 = 15.0;
  parameter Real ff2 = 0.50;
  parameter Real integ2_max = 2.0;

  // PID + velocity feedforward gains — joint 3 (prismatic)
  parameter Real Kp3 = 400.0;
  parameter Real Ki3 = 200.0;
  parameter Real Kd3 = 40.0;
  parameter Real ff3 = 20.0;
  parameter Real integ3_max = 0.50;

  // Joint states
  Real q1(start = q1_0, fixed = true) "rad joint 1 position";
  Real q1d(start = 0.0, fixed = true) "rad/s joint 1 velocity";
  Real q2(start = q2_0, fixed = true) "rad joint 2 position";
  Real q2d(start = 0.0, fixed = true) "rad/s joint 2 velocity";
  Real q3(start = q3_0, fixed = true) "m joint 3 position";
  Real q3d(start = 0.0, fixed = true) "m/s joint 3 velocity";

  // Trajectory references
  Real q1_ref "rad reference joint 1";
  Real q2_ref "rad reference joint 2";
  Real q3_ref "m reference joint 3";
  Real q1d_ref "rad/s reference velocity joint 1";
  Real q2d_ref "rad/s reference velocity joint 2";
  Real q3d_ref "m/s reference velocity joint 3";

  // PID integrators with anti-windup
  Real integ1(start = 0.0);
  Real integ2(start = 0.0);
  Real integ3(start = 0.0);

  // Commands
  Real tau1_raw "N.m unsaturated command joint 1";
  Real tau2_raw "N.m unsaturated command joint 2";
  Real tau3_raw "N unsaturated command joint 3";
  Real tau1 "N.m saturated command joint 1";
  Real tau2 "N.m saturated command joint 2";
  Real tau3 "N saturated command joint 3";

  // Synchronized encoder sensors
  Real q1_sens "rad sensed joint 1 position";
  Real q2_sens "rad sensed joint 2 position";
  Real q3_sens "m sensed joint 3 position";
  Real q1d_sens "rad/s sensed joint 1 velocity";
  Real q2d_sens "rad/s sensed joint 2 velocity";
  Real q3d_sens "m/s sensed joint 3 velocity";

  // End-effector position and obstacle clearance
  Real ee_x "m end-effector x";
  Real ee_y "m end-effector y";
  Real r_ee "m end-effector radius from base";
  Real dist_obs "m distance to obstacle center";
  Real clearance "m net clearance to obstacle surface";

  // Tracking errors
  Real err1 "rad joint 1 tracking error";
  Real err2 "rad joint 2 tracking error";
  Real err3 "m joint 3 tracking error";

  // Disturbance
  Real dist_force "N lateral disturbance force";
  Real dist_torque "N.m disturbance torque on joint 1";
  Boolean dist_active;

  // Segment helper
  Real t_seg "normalized segment time [0,1]";

  // Requirement monitors
  Boolean clearance_ok;
  Boolean joints_in_limits;
  Boolean settling_ok;
  Boolean overshoot_ok;

equation
  // Segment time normalization [0,1]
  t_seg = if time < T1 then time / T1 else (time - T1) / T2;

  // Cubic trajectory with zero velocity at each waypoint
  // q(tau) = q_start + 3*dq*tau^2 - 2*dq*tau^3
  // q'(tau) = (6*dq*tau - 6*dq*tau^2) / T

  // Joint 1 reference
  q1_ref = if time < T1 then
    q1_0 + 3.0*(q1_1 - q1_0)*t_seg*t_seg - 2.0*(q1_1 - q1_0)*t_seg*t_seg*t_seg
  else
    q1_1 + 3.0*(q1_2 - q1_1)*t_seg*t_seg - 2.0*(q1_2 - q1_1)*t_seg*t_seg*t_seg;

  q1d_ref = if time < T1 then
    (6.0*(q1_1 - q1_0)*t_seg - 6.0*(q1_1 - q1_0)*t_seg*t_seg) / T1
  else
    (6.0*(q1_2 - q1_1)*t_seg - 6.0*(q1_2 - q1_1)*t_seg*t_seg) / T2;

  // Joint 2 reference
  q2_ref = if time < T1 then
    q2_0 + 3.0*(q2_1 - q2_0)*t_seg*t_seg - 2.0*(q2_1 - q2_0)*t_seg*t_seg*t_seg
  else
    q2_1 + 3.0*(q2_2 - q2_1)*t_seg*t_seg - 2.0*(q2_2 - q2_1)*t_seg*t_seg*t_seg;

  q2d_ref = if time < T1 then
    (6.0*(q2_1 - q2_0)*t_seg - 6.0*(q2_1 - q2_0)*t_seg*t_seg) / T1
  else
    (6.0*(q2_2 - q2_1)*t_seg - 6.0*(q2_2 - q2_1)*t_seg*t_seg) / T2;

  // Joint 3 reference
  q3_ref = if time < T1 then
    q3_0 + 3.0*(q3_1 - q3_0)*t_seg*t_seg - 2.0*(q3_1 - q3_0)*t_seg*t_seg*t_seg
  else
    q3_1 + 3.0*(q3_2 - q3_1)*t_seg*t_seg - 2.0*(q3_2 - q3_1)*t_seg*t_seg*t_seg;

  q3d_ref = if time < T1 then
    (6.0*(q3_1 - q3_0)*t_seg - 6.0*(q3_1 - q3_0)*t_seg*t_seg) / T1
  else
    (6.0*(q3_2 - q3_1)*t_seg - 6.0*(q3_2 - q3_1)*t_seg*t_seg) / T2;

  // Synchronized encoder sensors (ideal, sampled at 100 Hz via simulation interval)
  q1_sens = q1;
  q2_sens = q2;
  q3_sens = q3;
  q1d_sens = q1d;
  q2d_sens = q2d;
  q3d_sens = q3d;

  // Tracking errors
  err1 = q1_ref - q1_sens;
  err2 = q2_ref - q2_sens;
  err3 = q3_ref - q3_sens;

  // PID integrators with conditional-integration anti-windup
  der(integ1) = if (integ1 > integ1_max and err1 > 0.0) or (integ1 < -integ1_max and err1 < 0.0) then 0.0 else err1;
  der(integ2) = if (integ2 > integ2_max and err2 > 0.0) or (integ2 < -integ2_max and err2 < 0.0) then 0.0 else err2;
  der(integ3) = if (integ3 > integ3_max and err3 > 0.0) or (integ3 < -integ3_max and err3 < 0.0) then 0.0 else err3;

  // PID + velocity feedforward: der(err) = qd_ref - qd_sens
  tau1_raw = Kp1*err1 + Ki1*integ1 + Kd1*(q1d_ref - q1d_sens) + ff1*q1d_ref;
  tau2_raw = Kp2*err2 + Ki2*integ2 + Kd2*(q2d_ref - q2d_sens) + ff2*q2d_ref;
  tau3_raw = Kp3*err3 + Ki3*integ3 + Kd3*(q3d_ref - q3d_sens) + ff3*q3d_ref;

  // Saturated actuators
  tau1 = if tau1_raw > tau_max_rot then tau_max_rot elseif tau1_raw < -tau_max_rot then -tau_max_rot else tau1_raw;
  tau2 = if tau2_raw > tau_max_rot then tau_max_rot elseif tau2_raw < -tau_max_rot then -tau_max_rot else tau2_raw;
  tau3 = if tau3_raw > tau_max_pris then tau_max_pris elseif tau3_raw < -tau_max_pris then -tau_max_pris else tau3_raw;

  // End-effector position in horizontal plane
  ee_x = L1*cos(q1) + L2*cos(q1 + q2);
  ee_y = L1*sin(q1) + L2*sin(q1 + q2);
  r_ee = sqrt(ee_x*ee_x + ee_y*ee_y + 1.0e-12);

  // Obstacle clearance
  dist_obs = sqrt((ee_x - obs_x)*(ee_x - obs_x) + (ee_y - obs_y)*(ee_y - obs_y) + 1.0e-12);
  clearance = dist_obs - obs_r;

  // Controlled lateral disturbance: half-sine pulse during middle third
  dist_active = time >= t_dist_start and time <= t_dist_end;
  dist_force = if dist_active then
    F_dist * sin(3.141592653589793 * (time - t_dist_start) / (t_dist_end - t_dist_start))
  else 0.0;
  // Lateral force at end-effector creates torque on base joint: tau = F * r_ee
  dist_torque = dist_force * r_ee;

  // Plant dynamics — joint 1 (revolute Z)
  der(q1) = q1d;
  J1*der(q1d) = tau1 - b1*q1d + dist_torque;

  // Plant dynamics — joint 2 (revolute Z)
  der(q2) = q2d;
  J2*der(q2d) = tau2 - b2*q2d;

  // Plant dynamics — joint 3 (prismatic Z, gravity opposes upward motion)
  der(q3) = q3d;
  m3*der(q3d) = tau3 - b3*q3d - m3*g;

  // Requirement monitors
  clearance_ok = clearance >= obs_clearance_min;
  joints_in_limits = q1 >= q1_min and q1 <= q1_max and
                     q2 >= q2_min and q2 <= q2_max and
                     q3 >= q3_min and q3 <= q3_max;
  settling_ok = (time < 6.5) or (abs(err1) < 0.06 and abs(err2) < 0.06 and abs(err3) < 0.06);
  overshoot_ok = abs(q1 - q1_2) <= 0.12*abs(q1_2 - q1_0) + 0.001 and
                 abs(q2 - q2_2) <= 0.12*abs(q2_2 - q2_0) + 0.001 and
                 abs(q3 - q3_2) <= 0.12*abs(q3_2 - q3_0) + 0.001;

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1.0e-6, Interval = 0.01),
    Documentation(info = "SCARATraceB: Fixed-base SCARA manipulator following a cubic joint trajectory through three reachable states. Two revolute Z joints (0.48 m, 0.34 m links) and one prismatic Z joint (0.30 m travel). PID + velocity-feedforward control with saturated actuators (77.9 N.m revolute, 900 N prismatic). Controlled 7 N lateral disturbance injected during middle third. 100 Hz sampling for 10 s. Fixed cylindrical keep-out obstacle beside path. Monitors: joint limits, obstacle clearance > 0.05 m, overshoot < 12%, tracking error < 0.06 rad-or-m after 6.5 s.")
  );
end SCARATraceB;