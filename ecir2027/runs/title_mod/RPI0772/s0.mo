model HexaWalkWalkD
  // Embodiment and physical constants
  parameter Real m_body = 15.0 "Body mass (kg)";
  parameter Real L_coxa = 0.12 "Coxa link length (m)";
  parameter Real L_femur = 0.22 "Femur link length (m)";
  parameter Real L_tibia = 0.26 "Tibia link length (m)";
  parameter Real g = 9.81 "Gravity (m/s2)";
  parameter Real mu = 0.85 "Rigid plane friction coefficient";

  // Actuator and joint bounds
  parameter Real tau_max = 20.0 "Per-joint saturated torque limit (N.m)";
  parameter Real q_min = -1.2 "Joint travel lower bound (rad); exact travel not specified, finite placeholder";
  parameter Real q_max = 1.2 "Joint travel upper bound (rad); exact travel not specified, finite placeholder";

  // Mission and timing
  parameter Real v_ref = 0.4 "Forward gait reference speed (m/s)";
  parameter Real T_end = 14.0 "Simulation duration (s)";
  parameter Real Ts = 0.005 "200 Hz trace and control sample period (s)";
  parameter Real T_push_start = T_end/3.0 "Start of middle third body push (s)";
  parameter Real T_push_end = 2.0*T_end/3.0 "End of middle third body push (s)";
  parameter Real F_push_magnitude = 70.0 "Body push disturbance magnitude (N)";

  // Placeholder embodiment details not stated in the request
  parameter Real h_ref = 0.30 "Nominal body height (m); exact nominal height not specified, finite placeholder";
  parameter Real I_body = 0.20 "Body pitch inertia (kg.m2); exact capsule inertia not specified, finite placeholder";
  parameter Real T_cycle = 1.0 "Gait cycle period (s); exact period not specified, finite placeholder";
  parameter Real duty = 0.5 "Tripod support duty factor; exact gait duty not specified, finite placeholder";

  // Joint impedance and body control gains
  parameter Real J_joint = 0.01 "Equivalent joint inertia (kg.m2); exact actuator inertia not specified, finite placeholder";
  parameter Real b_joint = 0.10 "Joint viscous friction (N.m.s/rad); exact friction not specified, finite placeholder";
  parameter Real Kp_j = 50.0 "Joint impedance stiffness (N.m/rad)";
  parameter Real Kd_j = 0.5 "Joint impedance damping (N.m.s/rad)";
  parameter Real Klim = 1000.0 "Joint soft-limit stiffness (N.m/rad)";
  parameter Real Dlim = 10.0 "Joint soft-limit damping (N.m.s/rad)";

  parameter Real Kp_h = 1000.0 "Body height proportional gain (N/m)";
  parameter Real Kd_h = 200.0 "Body height derivative gain (N.s/m)";

  parameter Real Kp_v = 1000.0 "Forward velocity proportional gain (N.s/m)";
  parameter Real Ki_v = 200.0 "Forward velocity integral gain (N/m)";
  parameter Real v_int_max = 10.0 "Velocity integrator clamp (s)";
  parameter Real tau_est = 0.03 "Disturbance estimator time constant (s)";
  parameter Real F_ext_max = 150.0 "Disturbance estimate clamp (N)";

  parameter Real Kp_pitch = 500.0 "Body attitude proportional gain (N.m/rad)";
  parameter Real Kd_pitch = 80.0 "Body attitude derivative gain (N.m.s/rad)";
  parameter Real tau_pitch_max = 60.0 "Collective pitch torque limit (N.m); exact limit not specified, finite placeholder";

  constant Real pi = 3.141592653589793;

  // Placeholder joint nominal angles, amplitudes, and phases; exact gait kinematics not specified
  parameter Real q_nom[18] = {
    -0.8,-0.4,1.0, -0.8,-0.4,1.0, -0.8,-0.4,1.0,
    -0.8,-0.4,1.0, -0.8,-0.4,1.0, -0.8,-0.4,1.0};
  parameter Real q_amp[18] = {
    0.10,0.20,0.20, 0.10,0.20,0.20, 0.10,0.20,0.20,
    0.10,0.20,0.20, 0.10,0.20,0.20, 0.10,0.20,0.20};
  parameter Real q_phase[18] = {
    0.0,0.0,0.0, pi,pi,pi, 0.0,0.0,0.0, pi,pi,pi,
    0.0,0.0,0.0, pi,pi,pi};
  parameter Real contact_offset[6] = {0.0,0.5,0.0,0.5,0.0,0.5};

  // Floating-base states
  Real x_pos(start=0.0) "Forward progress (m)";
  Real vx(start=v_ref) "Forward speed (m/s)";
  Real z_pos(start=h_ref) "Body height (m)";
  Real vz(start=0.0) "Vertical speed (m/s)";
  Real pitch(start=0.0) "Body pitch attitude (rad)";
  Real omega(start=0.0) "Body pitch rate (rad/s)";

  // Joint states
  Real q[18](start=q_nom) "Joint encoder states (rad)";
  Real qd[18](start=fill(0.0,18)) "Joint velocities (rad/s)";

  // Estimator states
  Real vx_est(start=v_ref) "IMU-integrated forward speed estimate (m/s)";
  Real pitch_est(start=0.0) "IMU-integrated pitch estimate (rad)";
  Real v_integral(start=0.0) "Velocity controller integral state";
  Real F_ext_est_raw(start=0.0) "Unclamped external push estimate (N)";

  // Sensors
  Real q_enc[18] "Joint encoder measurements (rad)";
  Real imu_pitch "Torso IMU pitch (rad)";
  Real imu_omega "Torso IMU pitch rate (rad/s)";
  Real imu_ax "Torso IMU forward acceleration (m/s2)";
  Real imu_az "Torso IMU vertical specific force (m/s2)";
  Real foot_force[6] "Foot contact normal-force sensors (N)";
  Real foot_force_mag[6] "Foot contact-force magnitudes (N)";
  Real foot_rel_x[6] "Foot x-position relative to hip (m)";
  Real foot_rel_z[6] "Foot z-position relative to hip (m)";
  Real foot_height[6] "Foot height above rigid plane (m)";

  // Contact and commands
  Real phase "Gait phase in [0,1)";
  Real contact[6] "Contact indicator per leg, 1 supporting else 0";
  Real n_support "Supporting-contact count";
  Real n_support_safe "Protected contact count used as divisor";
  Real F_z_total "Commanded vertical support force (N)";
  Real Fz[6] "Per-leg vertical contact force (N)";
  Real Fx[6] "Per-leg horizontal contact force (N)";
  Real Fx_sat[6] "Friction-limited per-leg horizontal force (N)";
  Real Fx_total "Total horizontal support force (N)";
  Real Fz_total_actual "Total measured vertical support force (N)";
  Real F_push_disturbance "Applied body push disturbance (N)";
  Real tau_push_disturbance "Pitch disturbance torque from push (N.m)";

  Real q_cmd_raw[18] "Unclamped phase-based joint commands (rad)";
  Real q_cmd[18] "Bounded phase-based joint commands (rad)";
  Real tau_limit[18] "Joint soft-limit torque (N.m)";
  Real tau_cmd[18] "Joint impedance torque before saturation (N.m)";
  Real tau_sat[18] "Saturated joint actuator torque (N.m)";

  Real F_drive_raw "Unclamped forward drive force (N)";
  Real F_drive "Friction-limited forward drive force (N)";
  Real F_friction_max "Available friction force (N)";
  Real F_ext_est "Clamped external push estimate (N)";

  Real tau_pitch_cmd_raw "Unclamped attitude-control torque (N.m)";
  Real tau_pitch_cmd "Bounded attitude-control torque (N.m)";

  Real tracking_error "Primary forward tracking error (m/s)";
  Real tracking_error_est "Estimated forward tracking error (m/s)";

  // Aggregated bound-check variables
  Real tau_max_abs "Maximum absolute joint torque (N.m)";
  Real q_range_max "Maximum joint angle (rad)";
  Real q_range_min "Minimum joint angle (rad)";
  Real foot_force_max "Maximum foot contact-force magnitude (N)";

  // Synchronized 200 Hz traces
  discrete Real trace_time;
  discrete Real trace_x;
  discrete Real trace_vx;
  discrete Real trace_z;
  discrete Real trace_pitch;
  discrete Real trace_omega;
  discrete Real trace_contact_count;
  discrete Real trace_tracking_error;
  discrete Real trace_F_drive;
  discrete Real trace_F_push;
  discrete Real trace_tau_max;
  discrete Real trace_foot_force_max;
  discrete Real trace_imu_pitch;
  discrete Real trace_imu_ax;
  discrete Real trace_q[18];
  discrete Real trace_q_cmd[18];
  discrete Real trace_tau[18];
  discrete Real trace_foot_force[6];

  // Top-level outputs
  output Real y_forward_position = x_pos;
  output Real y_forward_speed = vx;
  output Real y_primary_tracking_error = tracking_error;
  output Real y_tracking_error_after_9p1 = if time >= 9.1 then tracking_error else 0.0;
  output Real y_body_height = z_pos;
  output Real y_body_pitch = pitch;
  output Real y_contact_count = n_support;
  output Real y_torque_max = tau_max_abs;
  output Real y_torque_bound_violation = max(0.0, tau_max_abs - tau_max);
  output Real y_joint_bound_violation = max(0.0, q_range_max - q_max) + max(0.0, q_min - q_range_min);
  output Real y_foot_force_max = foot_force_max;
  output Real y_push_force = F_push_disturbance;
  output Real y_drive_force = F_drive;

equation
  // Gait phase and disturbance
  phase = mod(time/T_cycle, 1.0);
  F_push_disturbance = if time >= T_push_start and time <= T_push_end then F_push_magnitude else 0.0;
  tau_push_disturbance = F_push_disturbance*h_ref;

  // Body dynamics
  der(x_pos) = vx;
  der(vx) = (Fx_total + F_push_disturbance)/m_body;
  der(z_pos) = vz;
  der(vz) = (Fz_total_actual - m_body*g)/m_body;
  der(pitch) = omega;
  der(omega) = (tau_pitch_cmd + tau_push_disturbance)/I_body;

  // IMU and encoder sensors
  imu_pitch = pitch;
  imu_omega = omega;
  imu_ax = der(vx);
  imu_az = der(vz) + g;

  // Estimators
  der(vx_est) = imu_ax;
  der(pitch_est) = imu_omega;
  F_ext_est = max(-F_ext_max, min(F_ext_max, F_ext_est_raw));
  der(F_ext_est_raw) = (m_body*imu_ax - Fx_total - F_ext_est_raw)/tau_est;

  // Height control
  F_z_total = max(0.0, m_body*g + Kp_h*(h_ref - z_pos) - Kd_h*vz);

  // Forward velocity control with disturbance estimate feedforward
  F_friction_max = mu*max(F_z_total, 0.0);
  F_drive_raw = Kp_v*(v_ref - vx_est) + Ki_v*v_integral - F_ext_est;
  F_drive = max(-F_friction_max, min(F_friction_max, F_drive_raw));
  der(v_integral) =
    if (v_integral > v_int_max and (v_ref - vx_est) > 0.0) or
       (v_integral < -v_int_max and (v_ref - vx_est) < 0.0) or
       abs(F_drive_raw - F_drive) > 1e-6 then
      0.0
    else
      (v_ref - vx_est);

  // Attitude control
  tau_pitch_cmd_raw = Kp_pitch*(0.0 - pitch_est) - Kd_pitch*omega;
  tau_pitch_cmd = max(-tau_pitch_max, min(tau_pitch_max, tau_pitch_cmd_raw));

  // Contact schedule and per-leg forces
  for i in 1:6 loop
    contact[i] = if mod(phase + contact_offset[i], 1.0) < duty then 1.0 else 0.0;
    Fz[i] = if contact[i] > 0.5 then F_z_total/n_support_safe else 0.0;
    Fx[i] = if contact[i] > 0.5 then F_drive/n_support_safe else 0.0;
    Fx_sat[i] = max(-mu*Fz[i], min(mu*Fz[i], Fx[i]));
    foot_force[i] = Fz[i];
    foot_force_mag[i] = sqrt(max(0.0, Fx_sat[i]*Fx_sat[i] + Fz[i]*Fz[i]));
  end for;

  n_support = contact[1]+contact[2]+contact[3]+contact[4]+contact[5]+contact[6];
  n_support_safe = max(n_support, 1.0);

  Fx_total = Fx_sat[1]+Fx_sat[2]+Fx_sat[3]+Fx_sat[4]+Fx_sat[5]+Fx_sat[6];
  Fz_total_actual = Fz[1]+Fz[2]+Fz[3]+Fz[4]+Fz[5]+Fz[6];

  // Joint kinematics, impedance, bounds, and encoders
  for i in 1:18 loop
    q_cmd_raw[i] = q_nom[i] + q_amp[i]*sin(2.0*pi*phase + q_phase[i]);
    q_cmd[i] = max(q_min, min(q_max, q_cmd_raw[i]));
    q_enc[i] = q[i];

    tau_limit[i] =
      if q[i] > q_max then
        -Klim*(q[i] - q_max) - Dlim*qd[i]
      elseif q[i] < q_min then
        -Klim*(q_min - q[i]) - Dlim*qd[i]
      else
        0.0;

    tau_cmd[i] = Kp_j*(q_cmd[i] - q[i]) - Kd_j*qd[i] + tau_limit[i];
    tau_sat[i] = max(-tau_max, min(tau_max, tau_cmd[i]));

    der(q[i]) =
      if (q[i] > q_max and qd[i] > 0.0) or (q[i] < q_min and qd[i] < 0.0) then
        0.0
      else
        qd[i];

    J_joint*der(qd[i]) = tau_sat[i] - b_joint*qd[i];
  end for;

  // Foot kinematics from encoder states for sensor traces
  for i in 1:6 loop
    foot_rel_x[i] =
      L_coxa*cos(q[3*i-2]) +
      L_femur*cos(q[3*i-2]+q[3*i-1]) +
      L_tibia*cos(q[3*i-2]+q[3*i-1]+q[3*i]);
    foot_rel_z[i] =
      L_coxa*sin(q[3*i-2]) +
      L_femur*sin(q[3*i-2]+q[3*i-1]) +
      L_tibia*sin(q[3*i-2]+q[3*i-1]+q[3*i]);
    foot_height[i] = z_pos + foot_rel_z[i];
  end for;

  tracking_error = abs(vx - v_ref);
  tracking_error_est = abs(vx_est - v_ref);

  // Synchronized 200 Hz state, command, and sensor trace snapshots
  when sample(0, Ts) then
    trace_time = time;
    trace_x = x_pos;
    trace_vx = vx;
    trace_z = z_pos;
    trace_pitch = pitch;
    trace_omega = omega;
    trace_contact_count = n_support;
    trace_tracking_error = tracking_error;
    trace_F_drive = F_drive;
    trace_F_push = F_push_disturbance;
    trace_tau_max = tau_max_abs;
    trace_foot_force_max = foot_force_max;
    trace_imu_pitch = imu_pitch;
    trace_imu_ax = imu_ax;
    for i in 1:18 loop
      trace_q[i] = q[i];
      trace_q_cmd[i] = q_cmd[i];
      trace_tau[i] = tau_sat[i];
    end for;
    for i in 1:6 loop
      trace_foot_force[i] = foot_force[i];
    end for;
  end when;

algorithm
  tau_max_abs := 0.0;
  q_range_max := -1.0e9;
  q_range_min := 1.0e9;
  for i in 1:18 loop
    if abs(tau_sat[i]) > tau_max_abs then
      tau_max_abs := abs(tau_sat[i]);
    end if;
    if q[i] > q_range_max then
      q_range_max := q[i];
    end if;
    if q[i] < q_range_min then
      q_range_min := q[i];
    end if;
  end for;

  foot_force_max := 0.0;
  for i in 1:6 loop
    if foot_force_mag[i] > foot_force_max then
      foot_force_max := foot_force_mag[i];
    end if;
  end for;

annotation(
  experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
  Documentation(info = "Instrumented floating-base hexapod HexaWalkWalkD: 15 kg body, six 3-revolute-joint legs, 18 saturated joint actuators, phase-based impedance and attitude control, 70 N push during the middle third, 200 Hz synchronized traces."));
end HexaWalkWalkD;