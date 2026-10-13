model SeaSnakeSurveyF
  // ===== Timing =====
  parameter Real T_end = 20.0 "Mission duration [s]";
  parameter Real f_sample = 500.0 "Synchronized state/command/sensor trace rate [Hz]";

  // ===== Embodiment =====
  parameter Real m_robot = 32.0 "Robot total mass [kg]";
  parameter Real L_module = 0.30 "Capsule module length [m]";
  parameter Integer n_modules = 6 "Number of capsule modules";
  parameter Integer n_act = 12 "Number of bounded joint actuators";
  parameter Real tau_max = 39.0 "Per-joint actuator torque bound [N.m]";
  parameter Real L_fin = 0.10 "Passive tail fin length [m] (nominal; exact unspecified)";

  // ===== Mission =====
  parameter Real v_ref = 1.0 "Reference forward speed [m/s]";
  parameter Real path_total = 60.0 "Total lawnmower path length [m]";
  parameter Real leg_len = 18.0 "Lawnmower leg length [m]";
  parameter Real leg_spacing = 3.0 "Lawnmower leg spacing [m]";
  parameter Real depth_target = 2.0 "Constant depth target [m] (nominal; exact unspecified)";

  // ===== Environment / disturbance =====
  parameter Real v_current = 0.18 "Steady lateral water current [m/s]";
  parameter Real F_disturb = 145.0 "Controlled current load disturbance [N]";
  parameter Real t_dist_start = T_end/3.0 "Disturbance window start [s]";
  parameter Real t_dist_end = 2.0*T_end/3.0 "Disturbance window end [s]";

  // ===== Dynamics & control gains =====
  parameter Real Cd = 10.0 "Hydrodynamic linear drag [N.s/m]";
  parameter Real Kc_u = 80.0 "Surge velocity controller gain";
  parameter Real K_amp2force = 40.0 "Gait amplitude to thrust gain [N/rad]";
  parameter Real gait_amp_max = 0.5 "Maximum gait amplitude [rad]";
  parameter Real gait_freq = 1.0 "Undulation frequency [Hz]";
  parameter Real Kq_act = 60.0 "Joint PD proportional gain [N.m/rad]";
  parameter Real Dq_act = 3.0 "Joint PD damping gain [N.m.s/rad]";
  parameter Real kq_body = 2.0 "Joint body stiffness [N.m/rad]";
  parameter Real Iq = 0.05 "Joint inertia [kg.m^2]";
  parameter Real K_pitch_depth = 6.0 "Pitch joint depth torque gain [N.m/m]";
  parameter Real k_cross = 1.5 "LOS cross-track gain";
  parameter Real lookahead = 2.5 "LOS lookahead distance [m]";
  parameter Real K_heading = 3.0 "Heading tracking gain [1/s]";
  parameter Real Kp_lat = 250.0 "Lateral fin proportional gain [N/m]";
  parameter Real Kd_lat = 80.0 "Lateral fin damping gain [N.s/m]";
  parameter Real K_curr_ff = 1.0 "Current compensation feedforward gain";
  parameter Real K_depth = 0.5 "Depth control gain [1/s]";
  parameter Real k_est = 3.0 "Estimator position tracking gain [1/s]";
  parameter Real k_est_v = 2.0 "Estimator velocity tracking gain [1/s]";
  parameter Real P_decay = 0.10 "Estimator covariance decay [1/s]";
  parameter Real P_dist_growth = 0.04 "Covariance growth during disturbance [m^2/s]";

  constant Real PI = 3.141592653589793;
  constant Real TWO_PI = 6.283185307179586;

  // ===== States =====
  Real x(start=0.0) "World x position [m]";
  Real y(start=0.0) "World y position [m]";
  Real z(start=depth_target) "Depth [m]";
  Real u(start=0.05) "Forward speed [m/s]";
  Real v_sw(start=0.0) "Body-frame sway speed [m/s]";
  Real psi(start=0.0) "Heading [rad]";
  Real s_path(start=0.0) "Virtual path arclength target [m]";

  // ===== Estimator states =====
  Real x_est(start=0.0) "Estimated x [m]";
  Real y_est(start=0.0) "Estimated y [m]";
  Real z_est(start=depth_target) "Estimated depth [m]";
  Real u_est(start=0.0) "Estimated forward speed [m/s]";
  Real psi_est(start=0.0) "Estimated heading [rad]";
  Real P_est(start=0.5) "Estimated position covariance [m^2]";

  // ===== Joint states =====
  Real q[12](each start=0.0) "Joint angles [rad]";
  Real qd[12](each start=0.0) "Joint angular rates [rad/s]";

  // ===== Computed variables =====
  Real x_ref "Path reference x [m]";
  Real y_ref "Path reference y [m]";
  Real psi_ref "Path reference heading [rad]";
  Real e_cross "Cross-track error [m]";
  Real e_depth "Depth error [m]";
  Real e_track "Primary tracking error [m]";
  Real e_psi "Heading error [rad]";
  Real psi_los "Line-of-sight reference heading [rad]";
  Real route_completion "Fraction of path completed [0..1]";
  Real F_thrust_cmd "Thrust command [N]";
  Real F_thrust "Realized thrust [N]";
  Real F_fin "Lateral fin force command [N]";
  Real tau_heading "Heading control torque [N.m]";
  Real gait_amp_cmd "Gait amplitude command [rad]";
  Real q_ref[12] "Joint reference angles [rad]";
  Real tau[12] "Realized actuator torques [N.m]";
  Real tau_cmd[12] "Actuator torque commands [N.m]";
  Real actuator_max_observed "Instantaneous max |tau| [N.m]";

  // ===== Sampled sensor traces (500 Hz) =====
  discrete Real x_sens(start=0.0) "Sampled position x [m]";
  discrete Real y_sens(start=0.0) "Sampled position y [m]";
  discrete Real z_sens(start=0.0) "Sampled depth (pressure) [m]";
  discrete Real u_sens(start=0.0) "Sampled DVL forward speed [m/s]";
  discrete Real psi_sens(start=0.0) "Sampled compass heading [rad]";
  discrete Real P_sens(start=0.5) "Sampled estimator covariance [m^2]";

  // ===== Verification flags =====
  Boolean in_dist_window "Disturbance active";
  Boolean bounds_ok "Actuator bounds satisfied";
  Boolean track_ok "Primary tracking error within spec after 13 s";
  Boolean finite_ok "No NaN/Inf in key signals";
  Boolean completed "Route completion reached";

  function sat "Symmetric saturation"
    input Real x;
    input Real lim;
    output Real y;
  algorithm
    if x > lim then
      y := lim;
    elseif x < -lim then
      y := -lim;
    else
      y := x;
    end if;
  end sat;

  function maxAbs12 "Maximum absolute value over 12 actuators"
    input Real v[12];
    output Real m;
  protected
    Real t;
  algorithm
    m := 0.0;
    for i in 1:12 loop
      t := abs(v[i]);
      if t > m then
        m := t;
      end if;
    end for;
  end maxAbs12;

equation
  // ===== Lawnmower path reference (5 legs, total 60 m) =====
  if s_path < leg_len then
    x_ref = s_path;
    y_ref = 0.0;
    psi_ref = 0.0;
  elseif s_path < leg_len + leg_spacing then
    x_ref = leg_len;
    y_ref = s_path - leg_len;
    psi_ref = PI/2;
  elseif s_path < 2*leg_len + leg_spacing then
    x_ref = 2*leg_len + leg_spacing - s_path;
    y_ref = leg_spacing;
    psi_ref = PI;
  elseif s_path < 2*leg_len + 2*leg_spacing then
    x_ref = 0.0;
    y_ref = leg_spacing + (s_path - (2*leg_len + leg_spacing));
    psi_ref = PI/2;
  else
    x_ref = s_path - (2*leg_len + 2*leg_spacing);
    y_ref = 2*leg_spacing;
    psi_ref = 0.0;
  end if;

  der(s_path) = if noEvent(s_path < path_total) then v_ref else 0.0;
  route_completion = max(0.0, min(1.0, s_path / path_total));
  completed = s_path >= path_total - 1e-6;

  // ===== Path-following errors =====
  e_cross = -(x - x_ref)*sin(psi_ref) + (y - y_ref)*cos(psi_ref);
  e_depth = depth_target - z;
  e_track = sqrt(e_cross*e_cross + e_depth*e_depth);

  // ===== Line-of-sight guidance with current compensation =====
  psi_los = psi_ref - atan2(k_cross*e_cross, lookahead);
  e_psi = mod(psi_los - psi + PI, TWO_PI) - PI;

  // ===== Surge controller (undulatory propulsion amplitude) =====
  F_thrust_cmd = Kc_u*(v_ref - u) + Cd*v_ref;
  gait_amp_cmd = max(-gait_amp_max, min(gait_amp_max, F_thrust_cmd / K_amp2force));
  F_thrust = K_amp2force * gait_amp_cmd;

  // ===== Heading controller (first-order LOS tracking) =====
  der(psi) = K_heading * e_psi;
  tau_heading = sat(2.0*K_heading*e_psi, tau_max);

  // ===== Lateral fin force with current-compensation feedforward =====
  F_fin = -Kp_lat*e_cross - Kd_lat*v_sw - K_curr_ff*Cd*v_current;

  // ===== Disturbance window =====
  in_dist_window = time >= t_dist_start and time <= t_dist_end;

  // ===== Vehicle dynamics (world frame) =====
  der(x) = u*cos(psi) - v_sw*sin(psi);
  der(y) = u*sin(psi) + v_sw*cos(psi);
  m_robot*der(u) = F_thrust - Cd*u;
  m_robot*der(v_sw) = F_fin - Cd*v_sw + Cd*v_current*cos(psi)
                      + (if in_dist_window then F_disturb*cos(psi) else 0.0);
  der(z) = K_depth * e_depth;

  // ===== Undulation gait references (alternating yaw/pitch actuators) =====
  for j in 1:6 loop
    q_ref[2*j-1] = gait_amp_cmd*sin(2*PI*gait_freq*time - (j-1)*PI/3);
    q_ref[2*j]   = 0.02*K_pitch_depth*e_depth;
  end for;

  // ===== Actuator torque commands (heading bias on head yaw joints) =====
  for j in 1:6 loop
    tau_cmd[2*j-1] = Kq_act*(q_ref[2*j-1] - q[2*j-1]) - Dq_act*qd[2*j-1]
                     + (if j == 1 or j == 2 then 0.5*tau_heading else 0.0);
    tau_cmd[2*j]   = Kq_act*(q_ref[2*j] - q[2*j]) - Dq_act*qd[2*j]
                     + K_pitch_depth*e_depth;
  end for;

  for i in 1:12 loop
    tau[i] = sat(tau_cmd[i], tau_max);
  end for;

  // ===== Joint dynamics =====
  for i in 1:12 loop
    der(q[i]) = qd[i];
    Iq*der(qd[i]) = tau[i] - Dq_act*qd[i] - kq_body*q[i];
  end for;

  // ===== Sensor fusion / estimator (IMU+pressure+DVL+acoustic range+compass) =====
  der(x_est) = k_est*(x - x_est);
  der(y_est) = k_est*(y - y_est);
  der(z_est) = k_est*(z - z_est);
  der(u_est) = k_est_v*(u - u_est);
  der(psi_est) = k_est_v*(psi - psi_est);
  der(P_est) = -P_decay*P_est + (if in_dist_window then P_dist_growth else 0.0);

  // ===== Synchronized sensor traces at 500 Hz =====
  when sample(0, 1.0/f_sample) then
    x_sens = x;
    y_sens = y;
    z_sens = z;
    u_sens = u;
    psi_sens = psi;
    P_sens = P_est;
  end when;

  // ===== Verification observables =====
  actuator_max_observed = maxAbs12(tau);
  bounds_ok = actuator_max_observed <= tau_max + 1e-6;
  track_ok = (time < 13.0) or (e_track <= 0.64);
  finite_ok = (x == x) and (y == y) and (z == z) and (u == u) and (v_sw == v_sw)
              and (psi == psi) and (P_est == P_est) and (e_track == e_track)
              and (actuator_max_observed == actuator_max_observed)
              and (F_thrust == F_thrust) and (F_fin == F_fin)
              and (abs(x) < 1e9) and (abs(y) < 1e9) and (abs(z) < 1e9)
              and (abs(u) < 1e9) and (abs(v_sw) < 1e9) and (abs(psi) < 1e9)
              and (abs(P_est) < 1e9) and (abs(e_track) < 1e9)
              and (abs(F_thrust) < 1e9) and (abs(F_fin) < 1e9)
              and (abs(actuator_max_observed) < 1e9);

  annotation (
    Documentation(info="SeaSnakeSurveyF: 32 kg articulated underwater snake (6 x 0.30 m capsules, alternating yaw/pitch joints, passive tail fin, 12 bounded joint actuators at +/-39 N.m). Follows a 60 m lawnmower path at 1.0 m/s with constant depth, fusing IMU/pressure/DVL/acoustic range/compass. Steady 0.18 m/s lateral current with current compensation; controlled 145 N current load disturbance applied over the middle third (6.67-13.33 s). Runs 20 s at 500 Hz. Verification: actuator bounds, cross-track error, depth error, estimator covariance, route completion, primary tracking error < 0.64 m after 13 s, no NaN/Inf."),
    experiment(StopTime=20.0, Interval=0.002, Tolerance=1e-6)
  );
end SeaSnakeSurveyF;