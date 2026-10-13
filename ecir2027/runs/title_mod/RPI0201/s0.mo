model RailArmTraceC
  "Fixed-base articulated manipulator: PID + velocity-feedforward trajectory control following a cubic joint trajectory through three states"

  // ======================== Geometry and masses ========================
  parameter Real L1 = 0.46 "Link 1 length [m]";
  parameter Real L2 = 0.31 "Link 2 length [m]";
  parameter Real mc = 18.0 "Carriage mass [kg]";
  // Link masses are not stated in the requirement; assumed for dynamics:
  parameter Real m1 = 2.0 "Link 1 mass (modeling assumption) [kg]";
  parameter Real m2 = 1.5 "Link 2 mass (modeling assumption) [kg]";
  // Effective inertias (not fully specified; estimated from assumed masses):
  parameter Real J1 = 0.30 "Joint 1 effective inertia (assumption) [kg.m2]";
  parameter Real J2 = 0.05 "Joint 2 effective inertia (assumption) [kg.m2]";

  // ======================== Friction ========================
  parameter Real bx = 5.0 "Carriage viscous friction [N.s/m]";
  parameter Real b1 = 0.05 "Joint 1 viscous friction [N.m.s/rad]";
  parameter Real b2 = 0.01 "Joint 2 viscous friction [N.m.s/rad]";

  // ======================== Limits and saturation ========================
  parameter Real x_min = 0.0 "Rail start [m]";
  parameter Real x_max = 1.4 "Rail length (X rail) [m]";
  parameter Real q_lim = 1.5 "Joint limit magnitude [rad]";
  parameter Real F_max = 800.0 "Max carriage force command [N]";
  parameter Real tau_max = 78.2 "Max joint torque command [N.m]";

  // ======================== Disturbance ========================
  parameter Real F_dist = 9.0 "Lateral disturbance magnitude [N]";
  parameter Real t_wp1 = 4.0 "First waypoint time [s]";
  parameter Real t_wp2 = 8.0 "Second waypoint time [s]";
  parameter Real T_end = 12.0 "Total run time [s]";

  // ======================== Sampling ========================
  parameter Real Ts = 1.0/125.0 "Encoder sample period [s]";

  // ======================== Obstacle ========================
  parameter Real x_obs = 1.55 "Obstacle center x [m]";
  parameter Real y_obs = 0.10 "Obstacle center y [m]";
  parameter Real r_obs = 0.06 "Obstacle radius [m]";
  parameter Real clearance_req = 0.05 "Required obstacle clearance [m]";

  // ======================== Controller gains ========================
  // Carriage (m = 18 kg, target wn ~ 4 Hz, zeta ~ 1)
  parameter Real Kp_x  = 11250.0 "Carriage proportional gain [N/m]";
  parameter Real Kd_x  = 900.0   "Carriage derivative gain [N.s/m]";
  parameter Real Ki_x  = 1125.0  "Carriage integral gain [N/(m.s)]";
  parameter Real Kvff_x = 5.0    "Carriage velocity feedforward gain [N.s/m]";
  // Joint 1
  parameter Real Kp1  = 426.0  "Joint 1 proportional gain [N.m/rad]";
  parameter Real Kd1  = 22.6   "Joint 1 derivative gain [N.m.s/rad]";
  parameter Real Ki1  = 42.6   "Joint 1 integral gain [N.m/(rad.s)]";
  parameter Real Kvff1 = 0.05   "Joint 1 velocity feedforward gain [N.m.s/rad]";
  // Joint 2
  parameter Real Kp2  = 71.0   "Joint 2 proportional gain [N.m/rad]";
  parameter Real Kd2  = 3.77   "Joint 2 derivative gain [N.m.s/rad]";
  parameter Real Ki2  = 7.1    "Joint 2 integral gain [N.m/(rad.s)]";
  parameter Real Kvff2 = 0.01   "Joint 2 velocity feedforward gain [N.m.s/rad]";

  // ======================== Waypoints (three reachable states) ========================
  parameter Real x0_wp  = 0.20;  parameter Real x1_wp  = 0.70;  parameter Real x2_wp  = 1.20;
  parameter Real q10_wp = 0.0;   parameter Real q11_wp = 0.6;   parameter Real q12_wp = 1.0;
  parameter Real q20_wp = 0.0;   parameter Real q21_wp = 0.4;   parameter Real q22_wp = 0.8;

  // ======================== Dynamic states ========================
  Real x(start = x0_wp, fixed = true)    "Carriage position [m]";
  Real xdot(start = 0.0, fixed = true)  "Carriage velocity [m/s]";
  Real q1(start = q10_wp, fixed = true) "Joint 1 angle [rad]";
  Real q1dot(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real q2(start = q20_wp, fixed = true) "Joint 2 angle [rad]";
  Real q2dot(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";

  // ======================== Integral (anti-windup) states ========================
  Real ei_x(start = 0.0);
  Real ei1(start = 0.0);
  Real ei2(start = 0.0);

  // ======================== Reference trajectory ========================
  Real x_ref      "Reference carriage position [m]";
  Real x_ref_dot  "Reference carriage velocity [m/s]";
  Real q1_ref     "Reference joint 1 angle [rad]";
  Real q1_ref_dot "Reference joint 1 velocity [rad/s]";
  Real q2_ref     "Reference joint 2 angle [rad]";
  Real q2_ref_dot "Reference joint 2 velocity [rad/s]";

  // ======================== Errors ========================
  Real e_x, e1, e2;

  // ======================== Commands ========================
  Real F_cmd    "Unsaturated carriage force [N]";
  Real tau1_cmd "Unsaturated joint 1 torque [N.m]";
  Real tau2_cmd "Unsaturated joint 2 torque [N.m]";
  Real F_sat    "Saturated carriage force [N]";
  Real tau1_sat "Saturated joint 1 torque [N.m]";
  Real tau2_sat "Saturated joint 2 torque [N.m]";

  // ======================== Disturbance ========================
  Real F_dist_y "Active lateral disturbance on end-effector [N]";
  Real Qd1      "Disturbance generalized torque on joint 1 [N.m]";
  Real Qd2      "Disturbance generalized torque on joint 2 [N.m]";

  // ======================== Joint limit penalty ========================
  Real q1_pen "Joint 1 limit penalty torque [N.m]";
  Real q2_pen "Joint 2 limit penalty torque [N.m]";

  // ======================== Forward kinematics ========================
  Real x_ee "End-effector x [m]";
  Real y_ee "End-effector y [m]";
  Real dist_ee_obs "Distance from EE to obstacle center [m]";
  Real clearance   "Obstacle clearance [m]";

  // ======================== Performance metrics ========================
  Real track_err_x "Tracking error, carriage [m]";
  Real track_err1  "Tracking error, joint 1 [rad]";
  Real track_err2  "Tracking error, joint 2 [rad]";
  Real primary_err "Primary tracking error (max axis) [rad or m]";
  Real overshoot_x "Overshoot fraction, carriage [-]";
  Real overshoot1  "Overshoot fraction, joint 1 [-]";
  Real overshoot2  "Overshoot fraction, joint 2 [-]";
  Real terminal_vel "Max terminal velocity magnitude [m/s or rad/s]";

  // ======================== Requirement check flags ========================
  Boolean joint_limit_ok;
  Boolean clearance_ok;
  Boolean overshoot_ok;
  Boolean tracking_ok;
  Boolean settled_ok;
  Boolean no_nan_inf;

  // ======================== Sampled sensor traces (125 Hz) ========================
  discrete Real x_sens      "Sampled carriage position [m]";
  discrete Real xdot_sens   "Sampled carriage velocity [m/s]";
  discrete Real q1_sens     "Sampled joint 1 position [rad]";
  discrete Real q1dot_sens  "Sampled joint 1 velocity [rad/s]";
  discrete Real q2_sens     "Sampled joint 2 position [rad]";
  discrete Real q2dot_sens  "Sampled joint 2 velocity [rad/s]";
  discrete Real F_sens      "Sampled force command [N]";
  discrete Real tau1_sens   "Sampled torque 1 command [N.m]";
  discrete Real tau2_sens   "Sampled torque 2 command [N.m]";
  discrete Real min_clearance(start = 1.0e9) "Minimum observed clearance [m]";

equation
  // ====== Cubic Hermite trajectory (zero endpoint velocities at each waypoint) ======
  // Carriage x
  x_ref = if time <= t_wp1 then
            x0_wp + (x1_wp - x0_wp)*(3*(time/t_wp1)^2 - 2*(time/t_wp1)^3)
          elseif time <= t_wp2 then
            x1_wp + (x2_wp - x1_wp)*(3*((time - t_wp1)/(t_wp2 - t_wp1))^2 - 2*((time - t_wp1)/(t_wp2 - t_wp1))^3)
          else
            x2_wp;

  x_ref_dot = if time <= t_wp1 then
                (x1_wp - x0_wp)*(6*(time/t_wp1) - 6*(time/t_wp1)^2)/t_wp1
              elseif time <= t_wp2 then
                (x2_wp - x1_wp)*(6*((time - t_wp1)/(t_wp2 - t_wp1)) - 6*((time - t_wp1)/(t_wp2 - t_wp1))^2)/(t_wp2 - t_wp1)
              else
                0.0;

  // Joint 1
  q1_ref = if time <= t_wp1 then
             q10_wp + (q11_wp - q10_wp)*(3*(time/t_wp1)^2 - 2*(time/t_wp1)^3)
           elseif time <= t_wp2 then
             q11_wp + (q12_wp - q11_wp)*(3*((time - t_wp1)/(t_wp2 - t_wp1))^2 - 2*((time - t_wp1)/(t_wp2 - t_wp1))^3)
           else
             q12_wp;

  q1_ref_dot = if time <= t_wp1 then
                 (q11_wp - q10_wp)*(6*(time/t_wp1) - 6*(time/t_wp1)^2)/t_wp1
               elseif time <= t_wp2 then
                 (q12_wp - q11_wp)*(6*((time - t_wp1)/(t_wp2 - t_wp1)) - 6*((time - t_wp1)/(t_wp2 - t_wp1))^2)/(t_wp2 - t_wp1)
               else
                 0.0;

  // Joint 2
  q2_ref = if time <= t_wp1 then
             q20_wp + (q21_wp - q20_wp)*(3*(time/t_wp1)^2 - 2*(time/t_wp1)^3)
           elseif time <= t_wp2 then
             q21_wp + (q22_wp - q21_wp)*(3*((time - t_wp1)/(t_wp2 - t_wp1))^2 - 2*((time - t_wp1)/(t_wp2 - t_wp1))^3)
           else
             q22_wp;

  q2_ref_dot = if time <= t_wp1 then
                 (q21_wp - q20_wp)*(6*(time/t_wp1) - 6*(time/t_wp1)^2)/t_wp1
               elseif time <= t_wp2 then
                 (q22_wp - q21_wp)*(6*((time - t_wp1)/(t_wp2 - t_wp1)) - 6*((time - t_wp1)/(t_wp2 - t_wp1))^2)/(t_wp2 - t_wp1)
               else
                 0.0;

  // ====== Errors ======
  e_x = x_ref  - x;
  e1  = q1_ref - q1;
  e2  = q2_ref - q2;

  // ====== PID + velocity feedforward (with conditional integration anti-windup) ======
  der(ei_x) = if abs(F_cmd)    > F_max    then 0.0 else e_x;
  der(ei1)  = if abs(tau1_cmd) > tau_max  then 0.0 else e1;
  der(ei2)  = if abs(tau2_cmd) > tau_max  then 0.0 else e2;

  F_cmd    = Kp_x*e_x  + Ki_x*ei_x  + Kd_x*(x_ref_dot  - xdot)  + Kvff_x*x_ref_dot;
  tau1_cmd = Kp1*e1     + Ki1*ei1    + Kd1*(q1_ref_dot - q1dot) + Kvff1*q1_ref_dot;
  tau2_cmd = Kp2*e2     + Ki2*ei2    + Kd2*(q2_ref_dot - q2dot) + Kvff2*q2_ref_dot;

  // Saturation to actuator limits
  F_sat    = max(-F_max,    min(F_max,    F_cmd));
  tau1_sat = max(-tau_max,  min(tau_max,  tau1_cmd));
  tau2_sat = max(-tau_max,  min(tau_max,  tau2_cmd));

  // ====== Lateral disturbance (9 N on end-effector during middle third) ======
  F_dist_y = if (time >= t_wp1 and time <= t_wp2) then F_dist else 0.0;
  // Jacobian mapping: d(y_ee)/d(q1) = L1*cos(q1)+L2*cos(q1+q2), d(y_ee)/d(q2) = L2*cos(q1+q2)
  Qd1 = F_dist_y * (L1*cos(q1) + L2*cos(q1 + q2));
  Qd2 = F_dist_y * L2*cos(q1 + q2);

  // ====== Joint limit enforcement (soft spring-damper stop) ======
  q1_pen = if q1 > q_lim then -500.0*(q1 - q_lim) - 20.0*q1dot
           elseif q1 < -q_lim then -500.0*(q1 + q_lim) - 20.0*q1dot
           else 0.0;
  q2_pen = if q2 > q_lim then -500.0*(q2 - q_lim) - 20.0*q2dot
           elseif q2 < -q_lim then -500.0*(q2 + q_lim) - 20.0*q2dot
           else 0.0;

  // ====== Plant dynamics (explicit ODEs) ======
  der(x) = xdot;
  mc*der(xdot) = F_sat - bx*xdot;

  der(q1) = q1dot;
  J1*der(q1dot) = tau1_sat - b1*q1dot + Qd1 + q1_pen;

  der(q2) = q2dot;
  J2*der(q2dot) = tau2_sat - b2*q2dot + Qd2 + q2_pen;

  // ====== Forward kinematics ======
  x_ee = x + L1*cos(q1) + L2*cos(q1 + q2);
  y_ee = L1*sin(q1) + L2*sin(q1 + q2);
  dist_ee_obs = sqrt(max(1e-9, (x_ee - x_obs)^2 + (y_ee - y_obs)^2));
  clearance   = dist_ee_obs - r_obs;

  // ====== Performance metrics ======
  track_err_x = abs(x_ref  - x);
  track_err1  = abs(q1_ref - q1);
  track_err2  = abs(q2_ref - q2);
  primary_err = max(track_err_x, max(track_err1, track_err2));

  // Overshoot relative to total segment travel, evaluated after final waypoint
  overshoot_x = if time > t_wp2 then max(0.0, abs(x  - x2_wp))  / max(1e-9, abs(x2_wp  - x0_wp))  else 0.0;
  overshoot1  = if time > t_wp2 then max(0.0, abs(q1 - q12_wp)) / max(1e-9, abs(q12_wp - q10_wp)) else 0.0;
  overshoot2  = if time > t_wp2 then max(0.0, abs(q2 - q22_wp)) / max(1e-9, abs(q22_wp - q20_wp)) else 0.0;

  // Terminal velocity (settling indicator)
  terminal_vel = max(abs(xdot), max(abs(q1dot), abs(q2dot)));

  // ====== Requirement check flags ======
  joint_limit_ok = (abs(q1) <= q_lim + 1e-6) and (abs(q2) <= q_lim + 1e-6);
  clearance_ok   = clearance > clearance_req;
  overshoot_ok   = (overshoot_x < 0.12) and (overshoot1 < 0.12) and (overshoot2 < 0.12);
  tracking_ok    = (time < 7.8) or (primary_err < 0.053);
  settled_ok     = (time < T_end - 0.5) or (terminal_vel < 0.05);
  no_nan_inf     = (abs(x) < 1e20) and (abs(q1) < 1e20) and (abs(q2) < 1e20) and
                   (abs(xdot) < 1e20) and (abs(q1dot) < 1e20) and (abs(q2dot) < 1e20) and
                   (abs(F_cmd) < 1e20) and (abs(tau1_cmd) < 1e20) and (abs(tau2_cmd) < 1e20);

  // ====== Sampled sensor and command traces at 125 Hz ======
  when sample(0, Ts) then
    x_sens     = x;
    xdot_sens  = xdot;
    q1_sens    = q1;
    q1dot_sens = q1dot;
    q2_sens    = q2;
    q2dot_sens = q2dot;
    F_sens     = F_sat;
    tau1_sens  = tau1_sat;
    tau2_sens  = tau2_sat;
    min_clearance = if clearance < pre(min_clearance) then clearance else pre(min_clearance);
  end when;

  annotation(
    Documentation(info = "RailArmTraceC: fixed-base articulated manipulator (1.4 m X rail, 18 kg carriage, two-revolute planar arm with 0.46 m and 0.31 m links). PID + velocity-feedforward trajectory control follows a cubic Hermite joint trajectory through three reachable states (t=0,4,8 s) and holds at the last state. A 9 N lateral disturbance is applied to the end-effector during the middle third (4-8 s). Link masses and effective inertias are modeling assumptions (not stated in requirement). Cylindrical keep-out obstacle at (1.55, 0.10) m, radius 0.06 m, placed beside the nominal path. Sampled at 125 Hz for 12 s."),
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008)
  );
end RailArmTraceC;