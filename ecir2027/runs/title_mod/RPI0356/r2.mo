model DeltaPressB
  "Closed-chain Delta robot pressing compliant workpiece with hybrid position/force control"

  // ==================== GIVEN PARAMETERS (from requirement) ====================
  parameter Real Lu(final unit="m") = 0.32 "Upper arm length";
  parameter Real Lf(final unit="m") = 0.60 "Forearm length";
  parameter Real mp(final unit="kg") = 3.0 "Moving platform mass";
  parameter Real tau_max(final unit="N.m") = 36.9 "Allowed command magnitude per actuator";
  parameter Real kc(final unit="N/m") = 200e3 "Contact stiffness";
  parameter Real cc(final unit="N.s/m") = 2e3 "Contact damping";
  parameter Real mu = 0.70 "Friction coefficient";
  parameter Real F_dist_step(final unit="N") = 12.6 "Disturbance force change magnitude";
  parameter Real f_ctrl(final unit="Hz") = 100 "Control loop frequency";
  parameter Real t_end(final unit="s") = 10.0 "Mission duration";
  parameter Real g(final unit="m/s2") = 9.81 "Gravity acceleration";

  // ==================== ASSUMED PARAMETERS (not from requirement) ====================
  // These values are engineering assumptions required for a runnable model.
  // They are NOT stated in the requirement and should be validated.
  parameter Real Rb(final unit="m") = 0.15 "Base joint radius (assumed)";
  parameter Real Rp(final unit="m") = 0.08 "Platform joint radius (assumed)";
  parameter Real Ju(final unit="kg.m2") = 0.005 "Upper arm inertia about base joint (assumed)";
  parameter Real z_work(final unit="m") = -0.52 "Workpiece surface height (assumed)";
  parameter Real theta0(final unit="rad") = 0.05 "Initial upper arm angle (assumed)";
  parameter Real F_ref(final unit="N") = 20.0 "Desired regulated contact force (assumed)";
  parameter Real t_ramp(final unit="s") = 2.0 "Position ramp duration (assumed)";
  parameter Real Kp_pos(final unit="N/m") = 500.0 "Position proportional gain (assumed)";
  parameter Real Kd_pos(final unit="N.s/m") = 50.0 "Position derivative gain (assumed)";
  parameter Real Kp_force = 2.0 "Force proportional gain (assumed)";
  parameter Real Ki_force(final unit="1/s") = 20.0 "Force integral gain (assumed)";

  // ==================== DERIVED PARAMETERS ====================
  parameter Real Ts(final unit="s") = 1.0 / f_ctrl "Control sample period";
  parameter Real t_dist_start(final unit="s") = t_end / 3.0 "Disturbance injection start";
  parameter Real t_dist_end(final unit="s") = 2.0 * t_end / 3.0 "Disturbance injection end";
  parameter Real z_p0(final unit="m") =
    -Lu * sin(theta0) - sqrt(Lf^2 - (Rb + Lu * cos(theta0) - Rp)^2)
    "Initial platform height (derived from geometry)";
  parameter Real z_target(final unit="m") = z_work - 0.005 "Position target past workpiece surface";
  parameter Real vz_ramp(final unit="m/s") = (z_target - z_p0) / t_ramp "Ramp reference velocity";

  // ==================== CONTINUOUS STATES ====================
  Real theta(start=theta0, fixed=true, unit="rad") "Upper arm angle";
  Real omega(start=0, fixed=true, unit="rad/s") "Upper arm angular velocity";

  // ==================== KINEMATIC VARIABLES ====================
  Real h(unit="m") "Horizontal distance elbow to platform joint";
  Real s(unit="m") "Forearm vertical projection (guarded > 0)";
  Real z_p(unit="m") "Platform z-position (negative below base)";
  Real v_p(unit="m/s") "Platform z-velocity";
  Real a_p(unit="m/s2") "Platform z-acceleration (observable)";
  Real dzdth(unit="m/rad") "Jacobian dz_p/dtheta";
  Real d2zdth2(unit="m/rad2") "Second derivative d2z_p/dtheta2";

  // ==================== CONTACT ====================
  Real pen(unit="m") "Penetration depth into workpiece";
  Real F_contact(unit="N") "Normal contact force (upward positive)";
  Real F_normal(unit="N") "Normal force magnitude";
  Real v_lat(unit="m/s") "Lateral (tangential) velocity";
  Real slip(unit="m/s") "Tangential slip speed";
  Real F_fric_lat(unit="N") "Lateral friction force";
  Boolean locked "Contact locked (no tangential slip)";

  // ==================== ACTUATORS AND SENSORS ====================
  Real tau_cmd_raw[3](each unit="N.m") "Unsaturated commanded torques";
  Real tau_cmd[3](each unit="N.m") "Saturated actuator torques";
  Real tau_sensor[3](each unit="N.m") "Actuator torque sensor feedback";
  Real theta_sensor[3](each unit="rad") "Actuator angle sensor feedback";
  Real actuator_bounded "1.0 if all actuator torques within bounds";

  // ==================== DISTURBANCE ====================
  Boolean dist_active "Disturbance injection active (middle third)";
  Real F_dist(unit="N") "Disturbance force on platform (positive = downward)";

  // ==================== DISCRETE CONTROLLER (100 Hz) ====================
  discrete Real z_pd(start=z_p0, unit="m") "Sampled platform position";
  discrete Real v_pd(start=0, unit="m/s") "Sampled platform velocity";
  discrete Real F_contact_d(start=0, unit="N") "Sampled contact force";
  discrete Real mode_d(start=0) "Control mode: 0=position, 1=force";
  discrete Real F_int_d(start=0, unit="N") "Force integral term";
  discrete Real F_des_d(start=mp*g, unit="N") "Desired net actuator z-force";
  discrete Real z_ref_d(start=z_p0, unit="m") "Position reference";
  discrete Real vz_ref_d(start=vz_ramp, unit="m/s") "Reference velocity";

  // ==================== SYNCHRONIZED TRACES (100 Hz) ====================
  discrete Real trace_time(start=0, unit="s") "Trace timestamp";
  discrete Real trace_z_p(start=z_p0, unit="m") "Trace: platform position";
  discrete Real trace_theta(start=theta0, unit="rad") "Trace: arm angle";
  discrete Real trace_tau1(start=0, unit="N.m") "Trace: actuator 1 torque";
  discrete Real trace_tau2(start=0, unit="N.m") "Trace: actuator 2 torque";
  discrete Real trace_tau3(start=0, unit="N.m") "Trace: actuator 3 torque";
  discrete Real trace_F_contact(start=0, unit="N") "Trace: contact force";
  discrete Real trace_F_des(start=mp*g, unit="N") "Trace: desired force command";
  discrete Real trace_mode(start=0) "Trace: control mode";

  // ==================== DIAGNOSTICS ====================
  Real closure_err(unit="m") "Kinematic closure error (constraint residual)";
  Real track_err(unit="m") "Primary tracking error";
  Real force_band_err(unit="N") "Contact force deviation from reference band";

equation
  // ===== Kinematic closure constraint =====
  h = Rb + Lu * cos(theta) - Rp;
  s = sqrt(max(Lf^2 - h^2, 1e-6));
  z_p = -Lu * sin(theta) - s;
  v_p = dzdth * omega;
  a_p = dzdth * der(omega) + d2zdth2 * omega^2;

  // Jacobian: dz_p/dtheta
  dzdth = -Lu * cos(theta) - h * Lu * sin(theta) / s;

  // Second derivative: d2z_p/dtheta2
  d2zdth2 = Lu * sin(theta) -
    (((-Lu^2 * sin(theta)^2 + h * Lu * cos(theta)) * s^2
      - h^2 * Lu^2 * sin(theta)^2) / s^3);

  // ===== Contact model =====
  pen = max(z_work - z_p, 0.0);
  F_contact = if z_p < z_work then kc * (z_work - z_p) - cc * v_p else 0.0;
  F_normal = max(F_contact, 0.0);

  // Lateral friction: symmetric configuration has no lateral motion
  v_lat = 0.0;
  slip = abs(v_lat);
  F_fric_lat = 0.0;
  locked = F_normal > 0.0;

  // ===== Disturbance injection (middle third of mission) =====
  dist_active = (time >= t_dist_start) and (time < t_dist_end);
  F_dist = if dist_active then F_dist_step else 0.0;

  // ===== Platform dynamics in theta-space (Lagrangian form) =====
  // (mp * dzdth^2 + 3*Ju) * domega/dt + mp * dzdth * d2zdth2 * omega^2
  //   = sum(tau) + (F_contact - mp*g - F_dist) * dzdth
  (mp * dzdth^2 + 3 * Ju) * der(omega) + mp * dzdth * d2zdth2 * omega^2 =
    (tau_cmd[1] + tau_cmd[2] + tau_cmd[3]) + (F_contact - mp * g - F_dist) * dzdth;
  der(theta) = omega;

  // ===== Discrete hybrid controller at 100 Hz =====
  when sample(0, Ts) then
    // --- Sensor sampling ---
    z_pd = z_p;
    v_pd = v_p;
    F_contact_d = F_contact;

    // --- Ramped position reference ---
    if time < t_ramp then
      z_ref_d = z_p0 + (z_target - z_p0) * time / t_ramp;
      vz_ref_d = vz_ramp;
    else
      z_ref_d = z_target;
      vz_ref_d = 0.0;
    end if;

    // --- Mode latch: position -> force on first contact ---
    if F_contact_d > 0.5 or pre(mode_d) > 0.5 then
      mode_d = 1.0;
      F_int_d = pre(F_int_d) + (F_contact_d - F_ref) * Ts;
      F_des_d = mp * g - F_ref
              + Kp_force * (F_contact_d - F_ref)
              + Ki_force * (pre(F_int_d) + (F_contact_d - F_ref) * Ts);
    else
      mode_d = 0.0;
      F_int_d = 0.0;
      F_des_d = Kp_pos * (z_ref_d - z_pd) + Kd_pos * (vz_ref_d - v_pd) + mp * g;
    end if;

    // --- Synchronized traces ---
    trace_time = time;
    trace_z_p = z_p;
    trace_theta = theta;
    trace_tau1 = tau_cmd[1];
    trace_tau2 = tau_cmd[2];
    trace_tau3 = tau_cmd[3];
    trace_F_contact = F_contact;
    trace_F_des = F_des_d;
    trace_mode = mode_d;
  end when;

  // ===== Actuator torque mapping (symmetric: all three equal) =====
  tau_cmd_raw[1] = F_des_d * dzdth / 3.0;
  tau_cmd_raw[2] = tau_cmd_raw[1];
  tau_cmd_raw[3] = tau_cmd_raw[1];

  // ===== Torque saturation =====
  tau_cmd[1] = if tau_cmd_raw[1] > tau_max then tau_max
               elseif tau_cmd_raw[1] < -tau_max then -tau_max
               else tau_cmd_raw[1];
  tau_cmd[2] = if tau_cmd_raw[2] > tau_max then tau_max
               elseif tau_cmd_raw[2] < -tau_max then -tau_max
               else tau_cmd_raw[2];
  tau_cmd[3] = if tau_cmd_raw[3] > tau_max then tau_max
               elseif tau_cmd_raw[3] < -tau_max then -tau_max
               else tau_cmd_raw[3];

  // ===== Actuator sensor feedback =====
  tau_sensor[1] = tau_cmd[1];
  tau_sensor[2] = tau_cmd[2];
  tau_sensor[3] = tau_cmd[3];
  theta_sensor[1] = theta;
  theta_sensor[2] = theta;
  theta_sensor[3] = theta;

  actuator_bounded = if (abs(tau_cmd[1]) <= tau_max + 1e-9) and
                        (abs(tau_cmd[2]) <= tau_max + 1e-9) and
                        (abs(tau_cmd[3]) <= tau_max + 1e-9) then 1.0 else 0.0;

  // ===== Diagnostics =====
  // Closure error: residual of forearm length constraint (should be ~0)
  closure_err = abs(sqrt(h^2 + (z_p + Lu * sin(theta))^2) - Lf);

  // Tracking error: position error in position mode, force-equivalent in force mode
  track_err = if mode_d > 0.5
              then abs(F_contact - F_ref) / max(kc, 1.0)
              else abs(z_target - z_p);

  // Contact force band deviation
  force_band_err = abs(F_contact - F_ref);

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "DeltaPressB: Delta parallel robot pressing a compliant workpiece
      with hybrid position-to-force control at 100 Hz.

      Given parameters (from requirement):
        Lu = 0.32 m, Lf = 0.60 m, mp = 3 kg, tau_max = 36.9 N.m,
        kc = 200 kN/m, cc = 2 kN.s/m, mu = 0.70,
        F_dist_step = 12.6 N, f_ctrl = 100 Hz, t_end = 10 s.

      Assumed parameters (NOT from requirement, labeled for traceability):
        Rb, Rp (base/platform radii), Ju (arm inertia), z_work (workpiece height),
        theta0 (initial angle), F_ref (desired force), t_ramp, control gains.

      Symmetric reduction: all three chains identical (theta_1 = theta_2 = theta_3),
      giving pure z-axis pressing. Lateral slip is zero by symmetry (locked contact).

      Disturbance: 12.6 N downward force during middle third [3.33 s, 6.67 s].
      Requirement: tracking error < 0.001 m after 6.5 s, actuator bounds respected,
      no NaN/infinite values. All divisor terms are guarded with max() guards.")
  );
end DeltaPressB;