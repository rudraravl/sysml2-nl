model ShapeLockShapeA
  "Six-section continuum arm with thermally activated stiffness and three tendons per section"

  // ===== Parameters =====
  parameter Integer n = 6 "number of sections";
  parameter Real L_s = 0.08 "section length [m]";
  parameter Real m_s = 0.02 "section mass [kg]";
  parameter Real J_s = 5e-5 "section effective rotational inertia [kg.m2]";
  parameter Real k_soft = 0.01 "bending stiffness when soft/hot [N.m]";
  parameter Real k_lock = 10.0 "bending stiffness when locked/cold [N.m]";
  parameter Real d_s = 0.005 "damping coefficient [N.m.s]";
  parameter Real T_low = 320.0 "lower activation temperature [K]";
  parameter Real T_high = 345.0 "upper activation temperature [K]";
  parameter Real C_th = 0.1 "thermal capacitance [J/K]";
  parameter Real R_th = 2.78 "thermal resistance [K/W]";
  parameter Real T_amb = 295.0 "ambient temperature [K]";
  parameter Real f_max = 33.1 "max tendon force [N]";
  parameter Real P_max = 18.0 "max heater power [W]";
  parameter Real r_tendon = 0.025 "tendon moment arm [m]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real F_dist = 3.0 "disturbance tip force [N]";
  parameter Real Kp = 15.0 "proportional gain [N/(1/m)]";
  parameter Real Kd = 0.5 "derivative gain [N.s/(1/m)]";
  parameter Real tau_lock = 0.1 "shape-lock tracking time constant [s]";
  parameter Real kappa_target[6] = {2.5, 2.5, 2.5, 2.5, 2.5, 2.5} "target curvature [1/m]";
  parameter Real t_dist_start = 2.67 "disturbance start time [s]";
  parameter Real t_dist_end = 5.33 "disturbance end time [s]";
  parameter Real tracking_bound = 0.061 "primary tracking error bound [m]";
  parameter Real tracking_time = 5.2 "time after which tracking bound applies [s]";
  parameter Real f_sample = 80.0 "sample rate [Hz]";
  parameter Real t_end = 8.0 "simulation duration [s]";

  // ===== States =====
  Real T[6](each start = 320.0) "section temperature [K]";
  Real kappa[6](each start = 0.0) "section curvature [1/m]";
  Real dkappa[6](each start = 0.0) "section curvature rate [1/m/s]";
  Real kappa_locked[6](each start = 0.0) "locked curvature (shape memory) [1/m]";
  Real kappa_est[6](each start = 0.0) "estimated curvature [1/m]";
  Real dkappa_est[6](each start = 0.0) "estimated curvature rate [1/m/s]";

  // ===== Phase =====
  Integer phase "1=heat&shape, 2=hold&disturb, 3=lock";

  // ===== Stiffness =====
  Real k_bend[6] "section bending stiffness [N.m]";
  Real alpha[6] "thermal softness fraction [0=stiff, 1=soft]";

  // ===== Kinematics (actual) =====
  Real x[7] "x positions [m]";
  Real y[7] "y positions [m]";
  Real theta[7] "cumulative tangent angle [rad]";
  Real tip_x "tip x position [m]";
  Real tip_y "tip y position [m]";

  // ===== Kinematics (target) =====
  Real tx[7] "target x positions [m]";
  Real ty[7] "target y positions [m]";
  Real tth[7] "target cumulative angle [rad]";
  Real target_tip_x "target tip x [m]";
  Real target_tip_y "target tip y [m]";

  // ===== Kinematics (estimator) =====
  Real est_x[7] "estimated x positions [m]";
  Real est_y[7] "estimated y positions [m]";
  Real est_theta[7] "estimated cumulative angle [rad]";
  Real tip_est_x "estimated tip x [m]";
  Real tip_est_y "estimated tip y [m]";

  // ===== Moments =====
  Real grav_moment[6] "gravity bending moment [N.m]";
  Real tendon_moment[6] "net tendon moment [N.m]";
  Real dist_moment[6] "disturbance moment [N.m]";
  Real dist_force "disturbance force [N]";
  Real grav_cum[7] "cumulative gravity helper [N.m]";

  // ===== Controls =====
  Real tendon_force[6,3] "tendon forces [N]";
  Real heater_power[6] "heater power [W]";
  Real tendon_cmd_net[6] "net commanded tendon force [N]";
  Real heater_cmd[6] "commanded heater power [W]";

  // ===== Sensors =====
  Real curvature_sensor[6] "measured curvature [1/m]";
  Real temperature_sensor[6] "measured temperature [K]";
  Real force_sensor[6,3] "measured tendon force [N]";
  Real tip_pose_x "measured tip x [m]";
  Real tip_pose_y "measured tip y [m]";

  // ===== Errors and bounds =====
  Real tip_error "tip position error [m]";
  Real tip_error_est "estimated tip error [m]";
  Boolean tracking_ok "tracking within bound after 5.2 s";
  Boolean no_nan "no NaN/Inf in key variables";
  Boolean actuator_ok "actuators within limits";
  Boolean temperature_ok "temperatures in valid range";
  Boolean shape_error_ok "final shape error within bound";
  Real max_curv_err "max curvature error [1/m]";
  Real max_F_sec[6] "max tendon force per section [N]";
  Real max_F_all "max tendon force overall [N]";
  Real max_T_all "max temperature [K]";
  Real min_T_all "min temperature [K]";

equation

  // ===== Phase: 1=heat&shape (0-2.67s), 2=hold&disturb (2.67-5.33s), 3=lock (5.33-8s) =====
  phase = if time < t_dist_start then 1 else if time < t_dist_end then 2 else 3;

  // ===== Disturbance: 3 N tip load during middle third =====
  dist_force = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Thermal softness and stiffness =====
  for i in 1:6 loop
    alpha[i] = max(0.0, min(1.0, (T[i] - T_low) / (T_high - T_low)));
    k_bend[i] = k_lock + (k_soft - k_lock) * alpha[i];
  end for;

  // ===== Temperature dynamics =====
  for i in 1:6 loop
    der(T[i]) = (heater_power[i] - (T[i] - T_amb) / R_th) / C_th;
  end for;

  // ===== Heater control: full power during phases 1-2, off during phase 3 =====
  for i in 1:6 loop
    heater_cmd[i] = if (phase == 1 or phase == 2) then P_max else 0.0;
    heater_power[i] = max(0.0, min(P_max, heater_cmd[i]));
  end for;

  // ===== Shape-lock dynamics: kappa_locked tracks kappa when hot, freezes when cold =====
  for i in 1:6 loop
    der(kappa_locked[i]) = (alpha[i] / tau_lock) * (kappa[i] - kappa_locked[i]);
  end for;

  // ===== Control law: PD with feedforward, active only when soft =====
  for i in 1:6 loop
    tendon_cmd_net[i] = alpha[i] * (Kp * (kappa_target[i] - kappa[i]) - Kd * dkappa[i]
                        + (k_soft * (kappa_target[i] - kappa_locked[i]) - grav_moment[i] - dist_moment[i]) / r_tendon);
  end for;

  // ===== Tendon force distribution (tendon 1=return, 2&3=pull, at 120 deg spacing) =====
  for i in 1:6 loop
    tendon_force[i,1] = if tendon_cmd_net[i] < 0.0 then min(f_max, max(0.0, -tendon_cmd_net[i])) else 0.0;
    tendon_force[i,2] = if tendon_cmd_net[i] > 0.0 then min(f_max, max(0.0, tendon_cmd_net[i] / 2.0)) else 0.0;
    tendon_force[i,3] = if tendon_cmd_net[i] > 0.0 then min(f_max, max(0.0, tendon_cmd_net[i] / 2.0)) else 0.0;
    tendon_moment[i] = r_tendon * (tendon_force[i,2] + tendon_force[i,3] - tendon_force[i,1]);
  end for;

  // ===== Target forward kinematics (constant, undeformed-to-target geometry) =====
  tx[1] = 0.0;
  ty[1] = 0.0;
  tth[1] = 0.0;
  for i in 1:6 loop
    tx[i+1] = tx[i] + sin(kappa_target[i]*L_s)/kappa_target[i]*cos(tth[i])
                     - (1.0 - cos(kappa_target[i]*L_s))/kappa_target[i]*sin(tth[i]);
    ty[i+1] = ty[i] + sin(kappa_target[i]*L_s)/kappa_target[i]*sin(tth[i])
                     + (1.0 - cos(kappa_target[i]*L_s))/kappa_target[i]*cos(tth[i]);
    tth[i+1] = tth[i] + kappa_target[i]*L_s;
  end for;
  target_tip_x = tx[7];
  target_tip_y = ty[7];

  // ===== Actual forward kinematics (arc-based, shared frame with target) =====
  x[1] = 0.0;
  y[1] = 0.0;
  theta[1] = 0.0;
  for i in 1:6 loop
    x[i+1] = x[i] + (if abs(kappa[i]) > 1e-6 then sin(kappa[i]*L_s)/kappa[i] else L_s) * cos(theta[i])
                   - (if abs(kappa[i]) > 1e-6 then (1.0 - cos(kappa[i]*L_s))/kappa[i] else 0.0) * sin(theta[i]);
    y[i+1] = y[i] + (if abs(kappa[i]) > 1e-6 then sin(kappa[i]*L_s)/kappa[i] else L_s) * sin(theta[i])
                   + (if abs(kappa[i]) > 1e-6 then (1.0 - cos(kappa[i]*L_s))/kappa[i] else 0.0) * cos(theta[i]);
    theta[i+1] = theta[i] + kappa[i]*L_s;
  end for;
  tip_x = x[7];
  tip_y = y[7];

  // ===== Estimator forward kinematics (reduced-order deformation model) =====
  est_x[1] = 0.0;
  est_y[1] = 0.0;
  est_theta[1] = 0.0;
  for i in 1:6 loop
    est_x[i+1] = est_x[i] + (if abs(kappa_est[i]) > 1e-6 then sin(kappa_est[i]*L_s)/kappa_est[i] else L_s) * cos(est_theta[i])
                           - (if abs(kappa_est[i]) > 1e-6 then (1.0 - cos(kappa_est[i]*L_s))/kappa_est[i] else 0.0) * sin(est_theta[i]);
    est_y[i+1] = est_y[i] + (if abs(kappa_est[i]) > 1e-6 then sin(kappa_est[i]*L_s)/kappa_est[i] else L_s) * sin(est_theta[i])
                           + (if abs(kappa_est[i]) > 1e-6 then (1.0 - cos(kappa_est[i]*L_s))/kappa_est[i] else 0.0) * cos(est_theta[i]);
    est_theta[i+1] = est_theta[i] + kappa_est[i]*L_s;
  end for;
  tip_est_x = est_x[7];
  tip_est_y = est_y[7];

  // ===== Gravity moment (cumulative from distal to proximal, -y direction) =====
  grav_cum[7] = 0.0;
  grav_cum[6] = m_s*g*(x[6] + (L_s/2)*cos(theta[6])) + grav_cum[7];
  grav_cum[5] = m_s*g*(x[5] + (L_s/2)*cos(theta[5])) + grav_cum[6];
  grav_cum[4] = m_s*g*(x[4] + (L_s/2)*cos(theta[4])) + grav_cum[5];
  grav_cum[3] = m_s*g*(x[3] + (L_s/2)*cos(theta[3])) + grav_cum[4];
  grav_cum[2] = m_s*g*(x[2] + (L_s/2)*cos(theta[2])) + grav_cum[3];
  grav_cum[1] = m_s*g*(x[1] + (L_s/2)*cos(theta[1])) + grav_cum[2];
  grav_moment[1] = -(grav_cum[1] - 6.0*m_s*g*x[1]);
  grav_moment[2] = -(grav_cum[2] - 5.0*m_s*g*x[2]);
  grav_moment[3] = -(grav_cum[3] - 4.0*m_s*g*x[3]);
  grav_moment[4] = -(grav_cum[4] - 3.0*m_s*g*x[4]);
  grav_moment[5] = -(grav_cum[5] - 2.0*m_s*g*x[5]);
  grav_moment[6] = -(grav_cum[6] - 1.0*m_s*g*x[6]);

  // ===== Disturbance moment (tip force in -y, moment about each section base) =====
  for i in 1:6 loop
    dist_moment[i] = -dist_force * (tip_x - x[i]);
  end for;

  // ===== Curvature dynamics (second-order per section) =====
  for i in 1:6 loop
    der(kappa[i]) = dkappa[i];
    J_s * der(dkappa[i]) = tendon_moment[i] - k_bend[i] * (kappa[i] - kappa_locked[i])
                           + grav_moment[i] + dist_moment[i] - d_s * dkappa[i];
  end for;

  // ===== Estimator dynamics (model-based observer using same applied moments) =====
  for i in 1:6 loop
    der(kappa_est[i]) = dkappa_est[i];
    J_s * der(dkappa_est[i]) = tendon_moment[i] - k_bend[i] * (kappa_est[i] - kappa_locked[i])
                                + grav_moment[i] + dist_moment[i] - d_s * dkappa_est[i];
  end for;

  // ===== Sensors =====
  tip_pose_x = tip_x;
  tip_pose_y = tip_y;
  for i in 1:6 loop
    curvature_sensor[i] = kappa[i];
    temperature_sensor[i] = T[i];
    force_sensor[i,1] = tendon_force[i,1];
    force_sensor[i,2] = tendon_force[i,2];
    force_sensor[i,3] = tendon_force[i,3];
  end for;

  // ===== Errors =====
  tip_error = sqrt((tip_x - target_tip_x)^2 + (tip_y - target_tip_y)^2 + 1e-12);
  tip_error_est = sqrt((tip_est_x - target_tip_x)^2 + (tip_est_y - target_tip_y)^2 + 1e-12);
  max_curv_err = max(abs(kappa[1] - kappa_target[1]), max(abs(kappa[2] - kappa_target[2]),
                max(abs(kappa[3] - kappa_target[3]), max(abs(kappa[4] - kappa_target[4]),
                max(abs(kappa[5] - kappa_target[5]), abs(kappa[6] - kappa_target[6]))))));

  // ===== Actuator bounds =====
  max_F_sec[1] = max(tendon_force[1,1], max(tendon_force[1,2], tendon_force[1,3]));
  max_F_sec[2] = max(tendon_force[2,1], max(tendon_force[2,2], tendon_force[2,3]));
  max_F_sec[3] = max(tendon_force[3,1], max(tendon_force[3,2], tendon_force[3,3]));
  max_F_sec[4] = max(tendon_force[4,1], max(tendon_force[4,2], tendon_force[4,3]));
  max_F_sec[5] = max(tendon_force[5,1], max(tendon_force[5,2], tendon_force[5,3]));
  max_F_sec[6] = max(tendon_force[6,1], max(tendon_force[6,2], tendon_force[6,3]));
  max_F_all = max(max_F_sec[1], max(max_F_sec[2], max(max_F_sec[3], max(max_F_sec[4], max(max_F_sec[5], max_F_sec[6])))));
  actuator_ok = max_F_all <= f_max + 0.1;

  // ===== Temperature bounds =====
  max_T_all = max(T[1], max(T[2], max(T[3], max(T[4], max(T[5], T[6])))));
  min_T_all = min(T[1], min(T[2], min(T[3], min(T[4], min(T[5], T[6])))));
  temperature_ok = (min_T_all >= 250.0 and max_T_all <= 400.0);

  // ===== Tracking bound: primary tracking error below 0.061 m after 5.2 s =====
  tracking_ok = if time >= tracking_time then tip_error < tracking_bound else true;

  // ===== Final shape-error bound =====
  shape_error_ok = tip_error < 0.05;

  // ===== NaN/Inf check on key physical, control, and estimator variables =====
  no_nan = (tip_x > -1e6 and tip_x < 1e6 and tip_y > -1e6 and tip_y < 1e6
            and tip_error > 0.0 and tip_error < 1e6
            and T[1] > 0.0 and T[1] < 1e4
            and kappa[1] > -1e4 and kappa[1] < 1e4
            and tip_est_x > -1e6 and tip_est_x < 1e6
            and tip_est_y > -1e6 and tip_est_y < 1e6
            and kappa_est[1] > -1e4 and kappa_est[1] < 1e4);

  annotation (
    Experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Six-section continuum arm (ShapeLockShapeA) with three tendons per section and thermally activated stiffness elements. Stiffness transitions between 320 K (stiff/locked) and 345 K (soft/shapeable). Tendon tension and heater power independently controlled with command limits 33.1 N and 18 W. Target shape held via shape-locking: heat to soften, apply tendon forces to reach target curvature, cool to lock. Reduced-order deformation model provides shape feedback via curvature-based forward kinematics. 3 N tip disturbance applied during middle third (2.67-5.33 s). Run at 80 Hz for 8 s.")
  );
end ShapeLockShapeA;