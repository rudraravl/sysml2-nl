model TorqueObserverBridgeB
  // ===== Stated physical parameters =====
  parameter Real L = 0.58 "capsule link length [m]";
  parameter Real m = 8.0 "capsule link mass [kg]";
  parameter Real N = 70.0 "electric gearbox ratio";
  parameter Real tau_out_max = 61.5 "allowed output torque magnitude [N.m]";

  // ===== Derived mechanical quantities =====
  parameter Real I_link_cm = m*L^2/12 "link inertia about center [kg.m2]";
  parameter Real I_joint = I_link_cm + m*(L/2)^2 "joint inertia about base axis [kg.m2]";
  parameter Real b_joint = 0.2 "joint viscous damping [N.m.s/rad] (nominal, not stated)";

  // NOTE: Motor electrical parameters (R, Ke, Kt) are NOT stated in the request.
  // The voltage+current limit is enforced as the output torque saturation below.
  // Motor current instrumentation is represented by motor-side torque tau_m = tau_out/N,
  // which is proportional to current; conversion to amperes is omitted because Kt is unknown.

  // ===== Trajectory (single revolute joint; endpoint undergoes translation, link rotates) =====
  parameter Real A_des = 0.7853981634 "desired angle amplitude [rad] (pi/4)";
  parameter Real f_des = 0.15 "trajectory frequency [Hz]";
  parameter Real omega_des = 2.0*3.1415926535*f_des "trajectory angular freq [rad/s]";

  // ===== Outage window: 5.6 s centered in the 10 s run (covers middle third) =====
  parameter Real t_drop_start = 2.2 "absolute-sensor dropout start [s]";
  parameter Real t_drop_end = 7.8 "absolute-sensor dropout end [s] (5.6 s duration)";

  // ===== Controller gains =====
  parameter Real Kp_c = 60.0 "position gain [N.m/rad]";
  parameter Real Kd_c = 9.0  "velocity gain [N.m.s/rad]";

  // ===== Observer gains =====
  parameter Real Kp_o = 25.0 "encoder correction gain [1/s]";
  parameter Real Kd_o = 18.0 "gyro correction gain [1/s]";
  parameter Real Ka_o = 35.0 "absolute-sensor correction gain [1/s]";
  parameter Real gate_thresh = 0.15 "innovation gate threshold [rad]";

  // ===== Estimator covariance =====
  parameter Real Q_proc = 1.0e-3 "process noise rate [rad2/s]";
  parameter Real P0 = 1.0e-4 "initial covariance [rad2]";
  parameter Real P_floor = 1.0e-6 "covariance floor [rad2]";

  // ===== Sensor pseudo-noise (small deterministic; actual stochastic model not stated) =====
  parameter Real enc_amp = 2.0e-3 "encoder noise amplitude [rad]";
  parameter Real abs_amp = 1.0e-3 "absolute sensor noise amplitude [rad]";
  parameter Real gyro_amp = 3.0e-3 "gyro noise amplitude [rad/s]";

  // ===== Physical states =====
  Real theta(start=0.0) "joint angle [rad]";
  Real thetadot(start=0.0) "joint angular velocity [rad/s]";

  // ===== Drive quantities =====
  Real tau_cmd "commanded output torque [N.m]";
  Real tau_out "actual (saturated) output torque [N.m]";
  Real tau_m "motor-side torque [N.m], proportional to current (Kt unknown)";

  // ===== Sensor quantities =====
  Real theta_enc "joint encoder reading [rad] (proprioceptive, fast)";
  Real theta_abs "absolute position sensor reading [rad] (slow)";
  Real thetadot_gyro "gyro angular velocity reading [rad/s] (inertial)";
  Boolean dropout "absolute sensor dropout active";
  Boolean gate_ok "innovation gating passes";
  Real innovation "innovation of absolute sensor [rad]";

  // ===== Estimator states =====
  Real theta_est(start=0.0) "estimated angle [rad]";
  Real thetadot_est(start=0.0) "estimated angular velocity [rad/s]";
  Real P(start=P0) "estimated covariance of angle [rad2]";
  Boolean abs_available "absolute sensor accepted by estimator";

  // ===== Trajectory and tracking metrics =====
  Real theta_des "desired angle [rad]";
  Real thetades_dot "desired angular velocity [rad/s]";
  Real x_tip "endpoint x [m]";
  Real y_tip "endpoint y [m]";
  Real x_tip_des "endpoint desired x [m]";
  Real y_tip_des "endpoint desired y [m]";
  Real pos_err "endpoint position tracking error [m]";
  Real ang_err "angle tracking error [rad]";
  Real primary_err "primary tracking error [m-or-rad]";
  Boolean req_met_after_6p5 "primary error below 0.42 after 6.5 s";

  // ===== Synchronized 100 Hz traces =====
  Real t_stamp(start=0.0) "sample timestamp [s]";
  Integer step_cnt(start=0) "monotonic sample counter";

equation
  // Reference trajectory: rotation of link gives endpoint translation
  theta_des = A_des*sin(omega_des*time);
  thetades_dot = A_des*omega_des*cos(omega_des*time);

  // Plant dynamics (single rigid capsule link about base)
  der(theta) = thetadot;
  I_joint*der(thetadot) = tau_out - b_joint*thetadot;

  // Drive: voltage+current limit enforced via output torque saturation
  tau_cmd = Kp_c*(theta_des - theta_est) + Kd_c*(thetades_dot - thetadot_est);
  tau_out = max(-tau_out_max, min(tau_out_max, tau_cmd));
  tau_m = tau_out / N;

  // Sensors: proprioceptive + inertial always available; absolute sensor drops out
  theta_enc = theta + enc_amp*sin(11.0*time);
  thetadot_gyro = thetadot + gyro_amp*sin(7.0*time) + 1.0e-3*cos(13.0*time);
  theta_abs = theta + abs_amp*sin(5.0*time);

  // Dropout window (middle third of 10 s run, 5.6 s duration)
  dropout = (time >= t_drop_start) and (time <= t_drop_end);

  // Innovation gating (zero-error safe: no division)
  innovation = theta_abs - theta_est;
  gate_ok = abs(innovation) < gate_thresh;
  abs_available = (not dropout) and gate_ok;

  // Observer: multi-rate fusion with gating
  der(theta_est) = thetadot_est
                 + Kp_o*(theta_enc - theta_est)
                 + Ka_o*(theta_abs - theta_est)*(if abs_available then 1.0 else 0.0);
  der(thetadot_est) = (tau_out - b_joint*thetadot_est)/I_joint
                    + Kd_o*(thetadot_gyro - thetadot_est);

  // Covariance: grows during dropout (P_dot = Q), contracts when absolute sensor accepted
  der(P) = Q_proc - 2.0*Ka_o*(P - P_floor)*(if abs_available then 1.0 else 0.0);

  // Endpoint kinematics for tracking error
  x_tip = L*cos(theta);
  y_tip = L*sin(theta);
  x_tip_des = L*cos(theta_des);
  y_tip_des = L*sin(theta_des);
  pos_err = sqrt(max(1.0e-12, (x_tip - x_tip_des)^2 + (y_tip - y_tip_des)^2));
  ang_err = abs(theta - theta_des);
  primary_err = max(pos_err, ang_err);
  req_met_after_6p5 = (time > 6.5) and (primary_err < 0.42);

  // Synchronized 100 Hz trace timestamps (monotonic order)
  when sample(0.0, 0.01) then
    step_cnt = pre(step_cnt) + 1;
    t_stamp = time;
  end when;
end TorqueObserverBridgeB;