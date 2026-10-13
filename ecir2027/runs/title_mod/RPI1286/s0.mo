model ContactStateObserveB
  "Robotic sensing and estimation: estimate external force/torque during finite interval while holding commanded state"

  // ===== System Parameters =====
  parameter Real m_body = 24.0 "Quadruped torso mass [kg]";
  parameter Integer n_joints = 12 "Total joints (4 legs x 3 joints)";
  parameter Real tau_max = 45.1 "Allowed command magnitude per joint [N.m]";

  // ===== Joint Plant Parameters =====
  parameter Real J_joint = 0.5 "Joint inertia [kg.m2]";
  parameter Real b_joint = 0.5 "Joint viscous damping [N.m.s/rad]";

  // ===== Mission Parameters =====
  parameter Real T_sim = 10.0 "Mission duration [s]";
  parameter Real f_sample = 100.0 "Loop sample rate [Hz]";
  parameter Real dt = 1.0 / f_sample "Sample interval [s]";
  parameter Real d_ext = 9.8 "External load disturbance magnitude [N.m]";
  parameter Real t_load_on = T_sim / 3.0 "Load start (middle third) [s]";
  parameter Real t_load_off = 2.0 * T_sim / 3.0 "Load end (middle third) [s]";
  parameter Real q_hold = 0.5 "Commanded hold joint position [rad]";

  // Declared body location for disturbance application
  parameter Real loc_x = 0.15 "Disturbance application point x [m]";
  parameter Real loc_y = 0.0 "Disturbance application point y [m]";
  parameter Real loc_z = 0.0 "Disturbance application point z [m]";

  // ===== Controller Parameters =====
  parameter Real Kp = 200.0 "Position feedback gain [N.m/rad]";
  parameter Real Kd = 20.0 "Velocity feedback gain [N.m.s/rad]";

  // ===== Observer Parameters =====
  parameter Real J_nom = 0.5 "Nominal joint inertia [kg.m2]";
  parameter Real b_nom = 0.5 "Nominal joint damping [N.m.s/rad]";
  parameter Real L_obs = 80.0 "Observer gain [N.m.s/rad]";
  parameter Real tau_lp = 0.02 "Low-pass residual filter time constant [s]";

  // ===== Plant States =====
  Real q[12](each start = 0.5) "Joint positions [rad]";
  Real w[12](each start = 0.0) "Joint velocities [rad/s]";

  // ===== Actuator =====
  Real tau_cmd[12] "Unsaturated command [N.m]";
  Real tau_sat[12] "Saturated actuator torque [N.m]";
  Real i_act[12] "Actuator current proxy [A]";

  // ===== Disturbance =====
  Boolean load_active "True during disturbance interval";
  Real d_actual[12] "Actual per-joint disturbance [N.m]";
  Real d_body "Body-level disturbance [N.m]";

  // ===== Observer States =====
  Real w_hat[12](each start = 0.0) "Observer velocity estimate [rad/s]";
  Real d_hat[12](each start = 0.0) "Estimated disturbance (filtered) [N.m]";
  Real residual[12] "Observer velocity residual [rad/s]";

  // ===== Estimation Error and Tracking =====
  Real est_err[12] "Disturbance estimation error [N.m]";
  Real primary_err "Primary tracking error (joint 1) [N.m]";
  Boolean primary_ok "Primary error below 3 N.m";

  // ===== Sensors =====
  Real foot_force[4] "Foot normal force estimates [N]";
  Real imu_accel "Body acceleration from IMU [m/s2]";
  Real imu_rate "Body angular rate from IMU [rad/s]";
  Real est_wrench "Estimated external wrench [N.m]";

  // ===== Status Flags =====
  Boolean pre_load_ok "Pre-load residual bounded";
  Boolean in_load_ok "In-load estimation active";
  Boolean post_load_ok "Post-load recovery";

equation
  // --- Load scheduling ---
  load_active = (time >= t_load_on) and (time <= t_load_off);
  d_body = if load_active then d_ext else 0.0;

  // Disturbance applied at joint 1 (declared body location mapping)
  d_actual[1] = d_body;
  d_actual[2] = 0.0;
  d_actual[3] = 0.0;
  d_actual[4] = 0.0;
  d_actual[5] = 0.0;
  d_actual[6] = 0.0;
  d_actual[7] = 0.0;
  d_actual[8] = 0.0;
  d_actual[9] = 0.0;
  d_actual[10] = 0.0;
  d_actual[11] = 0.0;
  d_actual[12] = 0.0;

  // --- Plant dynamics ---
  for i in 1:12 loop
    der(q[i]) = w[i];
    J_joint * der(w[i]) = tau_sat[i] - b_joint * w[i] - d_actual[i];
  end for;

  // --- Controller: PD + disturbance compensation ---
  for i in 1:12 loop
    tau_cmd[i] = Kp * (q_hold - q[i]) - Kd * w[i] + d_hat[i];
  end for;

  // --- Actuator saturation ---
  for i in 1:12 loop
    tau_sat[i] = if (tau_cmd[i] > tau_max) then tau_max
                 else if (tau_cmd[i] < -tau_max) then -tau_max
                 else tau_cmd[i];
  end for;

  // --- Actuator current/pressure proxy ---
  for i in 1:12 loop
    i_act[i] = tau_sat[i];
  end for;

  // --- Disturbance observer with low-pass residual filtering ---
  for i in 1:12 loop
    der(w_hat[i]) = (1.0 / J_nom) * (tau_sat[i] - b_nom * w_hat[i] + L_obs * (w[i] - w_hat[i]));
    residual[i] = w[i] - w_hat[i];
    der(d_hat[i]) = (1.0 / tau_lp) * (-(b_nom + L_obs) * residual[i] - d_hat[i]);
  end for;

  // --- Estimation error ---
  for i in 1:12 loop
    est_err[i] = d_actual[i] - d_hat[i];
  end for;

  primary_err = abs(est_err[1]);
  primary_ok = primary_err < 3.0;

  // --- Foot contact normal force (static weight distribution) ---
  for i in 1:4 loop
    foot_force[i] = m_body * 9.81 / 4.0;
  end for;

  // --- Body IMU (simplified proxies) ---
  imu_accel = d_body / m_body;
  imu_rate = w[1];

  // --- Estimated external wrench ---
  est_wrench = d_hat[1];

  // --- Status flags ---
  pre_load_ok = (time < t_load_on) and (abs(d_hat[1]) < 1.0);
  in_load_ok = load_active and (abs(est_err[1]) < 3.0);
  post_load_ok = (time > t_load_off) and (abs(d_hat[1]) < 1.0);

end ContactStateObserveB;