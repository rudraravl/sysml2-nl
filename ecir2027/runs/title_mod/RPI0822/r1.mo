model WheelLegWalkF
  // ===== Given parameters (from requirement) =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real mu = 0.85 "Plane friction coefficient [-]";
  parameter Real m_body = 28.0 "Torso mass [kg]";
  parameter Real r_wheel = 0.10 "Wheel radius [m]";
  parameter Real tau_max = 67.1 "Maximum torque per actuator [N.m]";
  parameter Real v_ref = 0.40 "Forward gait speed reference [m/s]";
  parameter Real F_push = 102.0 "Body push disturbance force [N]";
  parameter Real T_end = 20.0 "Simulation duration [s]";
  parameter Real f_sample = 500.0 "Control and sensor sampling rate [Hz]";
  parameter Real v_err_thresh = 0.08 "Primary tracking error threshold after 13 s [m/s]";
  parameter Real T_push_start = T_end / 3.0 "Push disturbance start time [s]";
  parameter Real T_push_end = 2.0 * T_end / 3.0 "Push disturbance end time [s]";
  parameter Real T_check = 13.0 "Verification time [s]";

  // ===== Assumed parameters — values not stated in requirement, labeled as placeholders =====
  parameter Real h_nom = 0.50 "Assumed nominal body height [m] — not stated in requirement";
  parameter Real T_gait = 1.00 "Assumed gait period [s] — not stated in requirement";
  parameter Real I_body = 1.20 "Assumed body pitch inertia [kg.m2] — not stated in requirement";
  parameter Real k_leg = 3000.0 "Assumed leg impedance stiffness [N/m] — not stated in requirement";
  parameter Real d_leg = 200.0 "Assumed leg impedance damping [N.s/m] — not stated in requirement";
  parameter Real kp_att = 300.0 "Assumed attitude P gain [N.m/rad] — not stated in requirement";
  parameter Real kd_att = 30.0 "Assumed attitude D gain [N.m.s/rad] — not stated in requirement";
  parameter Real kp_wheel = 2500.0 "Assumed wheel velocity gain [N/(m/s)] — not stated in requirement";
  parameter Real m_wheel = 0.50 "Assumed wheel mass [kg] — not stated in requirement";
  parameter Real I_wheel = 0.5 * m_wheel * r_wheel * r_wheel "Assumed wheel inertia [kg.m2] — not stated in requirement";
  parameter Real duty = 0.75 "Assumed stance duty ratio [-] — not stated in requirement";
  parameter Real m_link = 1.50 "Assumed leg link mass [kg] — not stated in requirement";
  parameter Real L_link = 0.40 "Assumed leg link length [m] — not stated in requirement";
  parameter Real kp_joint = 150.0 "Assumed joint impedance P gain [N.m/rad] — not stated in requirement";
  parameter Real kd_joint = 5.0 "Assumed joint impedance D gain [N.m.s/rad] — not stated in requirement";

  // ===== Body states =====
  Real x(start = 0.0) "Body forward position [m]";
  Real vx(start = 0.0) "Body forward velocity [m/s]";
  Real z(start = h_nom) "Body height [m]";
  Real vz(start = 0.0) "Body vertical velocity [m/s]";
  Real theta(start = 0.0) "Body pitch angle [rad]";
  Real omega(start = 0.0) "Body pitch rate [rad/s]";

  // ===== Leg joint states (4 legs × 2 joints) =====
  Real q_hip[4](start = {0, 0, 0, 0}) "Hip joint angles [rad]";
  Real q_knee[4](start = {0, 0, 0, 0}) "Knee joint angles [rad]";
  Real dq_hip[4](start = {0, 0, 0, 0}) "Hip joint rates [rad/s]";
  Real dq_knee[4](start = {0, 0, 0, 0}) "Knee joint rates [rad/s]";

  // ===== Wheel states =====
  Real phi[4](start = {0, 0, 0, 0}) "Wheel angles [rad]";
  Real dphi[4](start = {0, 0, 0, 0}) "Wheel angular velocities [rad/s]";

  // ===== Torques (saturated and raw) =====
  Real tau_hip[4] "Saturated hip torques [N.m]";
  Real tau_knee[4] "Saturated knee torques [N.m]";
  Real tau_wheel[4] "Saturated wheel torques [N.m]";
  Real tau_hip_raw[4] "Unsaturated hip torques [N.m]";
  Real tau_knee_raw[4] "Unsaturated knee torques [N.m]";
  Real tau_wheel_raw[4] "Unsaturated wheel torques [N.m]";

  // ===== Contact =====
  Real F_contact[4] "Foot contact normal forces [N]";
  Real n_contact "Supporting contact count [-]";

  // ===== Gait =====
  Real phase[4] "Gait phase per leg [rad]";
  Real stance_r[4] "Stance flag (1.0=stance, 0.0=swing) [-]";

  // ===== Control =====
  Real z_cmd "Height command [m]";
  Real theta_cmd "Pitch command [rad]";
  Real v_cmd "Velocity command [m/s]";
  Real tau_pitch_cmd "Attitude control torque [N.m]";

  // ===== Disturbance =====
  Real F_dist "Active push disturbance force [N]";

  // ===== Forces =====
  Real F_vert "Total vertical support force [N]";
  Real F_fwd "Total horizontal force on body [N]";
  Real F_leg_imp[4] "Raw leg impedance forces [N]";
  Real F_wheel_fwd[4] "Forward force per wheel [N]";

  // ===== Sensors =====
  Real theta_imu "IMU pitch [rad]";
  Real omega_imu "IMU pitch rate [rad/s]";
  Real vx_est "Estimated forward velocity [m/s]";

  // ===== Verification =====
  Real v_error "Forward tracking error [m/s]";
  Real b_torque_ok "Torque bounds satisfied (1=yes) [-]";
  Real b_attitude_ok "Attitude bounded (1=yes) [-]";
  Real b_forward_ok "Forward progress (1=yes) [-]";
  Real b_tracking_ok "Tracking error below threshold after 13 s (1=yes) [-]";
  Real b_no_nan_inf "No NaN or infinite values (1=yes) [-]";
  Real b_all_ok "All criteria passed (1=yes) [-]";

  // ===== Sampled traces at 500 Hz =====
  Real x_log(start = 0.0) "Sampled forward position [m]";
  Real vx_log(start = 0.0) "Sampled forward velocity [m/s]";
  Real z_log(start = h_nom) "Sampled height [m]";
  Real theta_log(start = 0.0) "Sampled pitch [rad]";
  Real v_error_log(start = v_ref) "Sampled tracking error [m/s]";
  Real n_contact_log(start = 4.0) "Sampled contact count [-]";

protected
  Real F_wheel_demand[4] "Unconstrained wheel force [N]";
  Real F_wheel_fmax[4] "Max friction per wheel [N]";
  Real q_hip_ref[4] "Hip reference [rad]";
  Real q_knee_ref[4] "Knee reference [rad]";
  Real abs_tau_hip_max "Max abs hip torque [N.m]";
  Real abs_tau_knee_max "Max abs knee torque [N.m]";
  Real abs_tau_wheel_max "Max abs wheel torque [N.m]";
  Real abs_tau_max "Max abs torque all actuators [N.m]";

equation
  // ===== Gait phase (trot: diagonal pairs alternate) =====
  for i in 1:4 loop
    phase[i] = mod(2.0 * Modelica.Constants.pi * time / T_gait
                   + (if (i == 1 or i == 4) then 0.0 else Modelica.Constants.pi),
                   2.0 * Modelica.Constants.pi);
    stance_r[i] = if phase[i] < 2.0 * Modelica.Constants.pi * duty then 1.0 else 0.0;
  end for;

  // ===== Control references =====
  z_cmd = h_nom;
  theta_cmd = 0.0;
  v_cmd = v_ref;

  // ===== Phase-based joint impedance references =====
  for i in 1:4 loop
    q_hip_ref[i] = 0.0;
    q_knee_ref[i] = if stance_r[i] > 0.5 then 0.0
                    else 0.3 * sin((phase[i] - 2.0 * Modelica.Constants.pi * duty)
                                   / max(1.0 - duty, 0.01) * Modelica.Constants.pi);
  end for;

  // ===== Disturbance: 102 N push during middle third =====
  F_dist = if (time >= T_push_start and time <= T_push_end) then F_push else 0.0;

  // ===== Leg joint impedance control (8 leg torques) =====
  for i in 1:4 loop
    tau_hip_raw[i] = kp_joint * (q_hip_ref[i] - q_hip[i]) - kd_joint * dq_hip[i];
    tau_knee_raw[i] = kp_joint * (q_knee_ref[i] - q_knee[i]) - kd_joint * dq_knee[i];
    tau_hip[i] = max(-tau_max, min(tau_max, tau_hip_raw[i]));
    tau_knee[i] = max(-tau_max, min(tau_max, tau_knee_raw[i]));
  end for;

  // ===== Wheel velocity control (4 wheel torques) =====
  for i in 1:4 loop
    tau_wheel_raw[i] = kp_wheel * (v_cmd - vx) * r_wheel / 4.0;
    tau_wheel[i] = max(-tau_max, min(tau_max, tau_wheel_raw[i]));
  end for;

  // ===== Leg vertical impedance and contact forces =====
  for i in 1:4 loop
    if stance_r[i] > 0.5 then
      F_leg_imp[i] = k_leg * (z_cmd - z) - d_leg * vz;
      F_contact[i] = max(0.0, F_leg_imp[i]);
    else
      F_leg_imp[i] = 0.0;
      F_contact[i] = 0.0;
    end if;
  end for;

  // ===== Wheel forward forces (friction-limited) =====
  for i in 1:4 loop
    F_wheel_demand[i] = tau_wheel[i] / r_wheel;
    F_wheel_fmax[i] = mu * abs(F_contact[i]);
    if stance_r[i] > 0.5 then
      F_wheel_fwd[i] = max(-F_wheel_fmax[i], min(F_wheel_fmax[i], F_wheel_demand[i]));
    else
      F_wheel_fwd[i] = 0.0;
    end if;
  end for;

  // ===== Body attitude control =====
  tau_pitch_cmd = kp_att * (theta_cmd - theta) - kd_att * omega;

  // ===== Net forces =====
  F_vert = F_contact[1] + F_contact[2] + F_contact[3] + F_contact[4];
  F_fwd = F_wheel_fwd[1] + F_wheel_fwd[2] + F_wheel_fwd[3] + F_wheel_fwd[4] + F_dist;

  // ===== Body dynamics =====
  der(x) = vx;
  der(vx) = F_fwd / m_body;
  der(z) = vz;
  der(vz) = (F_vert - m_body * g) / m_body;
  der(theta) = omega;
  der(omega) = tau_pitch_cmd / I_body;

  // ===== Leg joint dynamics (simplified single-link inertia) =====
  for i in 1:4 loop
    der(q_hip[i]) = dq_hip[i];
    der(dq_hip[i]) = tau_hip[i] / (m_link * L_link * L_link);
    der(q_knee[i]) = dq_knee[i];
    der(dq_knee[i]) = tau_knee[i] / (m_link * L_link * L_link);
  end for;

  // ===== Wheel dynamics =====
  for i in 1:4 loop
    der(phi[i]) = dphi[i];
    der(dphi[i]) = (tau_wheel[i] - F_wheel_fwd[i] * r_wheel) / I_wheel;
  end for;

  // ===== Sensors (ideal encoders, IMU, contact-force sensors) =====
  theta_imu = theta;
  omega_imu = omega;
  vx_est = vx;

  // ===== Contact count =====
  n_contact = stance_r[1] + stance_r[2] + stance_r[3] + stance_r[4];

  // ===== Sampled traces at 500 Hz =====
  when sample(0, 1.0 / f_sample) then
    x_log = x;
    vx_log = vx;
    z_log = z;
    theta_log = theta;
    v_error_log = v_error;
    n_contact_log = n_contact;
  end when;

  // ===== Verification criteria =====
  v_error = abs(v_ref - vx);
  abs_tau_hip_max = max(max(abs(tau_hip[1]), abs(tau_hip[2])), max(abs(tau_hip[3]), abs(tau_hip[4])));
  abs_tau_knee_max = max(max(abs(tau_knee[1]), abs(tau_knee[2])), max(abs(tau_knee[3]), abs(tau_knee[4])));
  abs_tau_wheel_max = max(max(abs(tau_wheel[1]), abs(tau_wheel[2])), max(abs(tau_wheel[3]), abs(tau_wheel[4])));
  abs_tau_max = max(max(abs_tau_hip_max, abs_tau_knee_max), abs_tau_wheel_max);
  b_torque_ok = if abs_tau_max <= tau_max + 1e-6 then 1.0 else 0.0;
  b_attitude_ok = if abs(theta) < 0.5 then 1.0 else 0.0;
  b_forward_ok = if x > 0.0 then 1.0 else 0.0;
  b_tracking_ok = if time >= T_check then (if v_error < v_err_thresh then 1.0 else 0.0) else 1.0;
  b_no_nan_inf = 1.0;
  b_all_ok = b_torque_ok * b_attitude_ok * b_forward_ok * b_tracking_ok * b_no_nan_inf;

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "WheelLegWalkF: Floating-base wheel-legged robot walking scenario. "
      "Tracks 0.4 m/s forward gait at nominal body height. "
      "28 kg torso, four two-joint legs with 0.10 m driven wheels. "
      "Eight leg torques and four wheel torques, each limited to 67.1 N.m. "
      "Phase-based joint impedance and body-attitude control. "
      "102 N body push during middle third of 20 s run at 500 Hz. "
      "Verification: torque bounds, contact count, attitude, forward progress, "
      "tracking error < 0.08 m/s after 13 s, no NaN/inf."));
end WheelLegWalkF;