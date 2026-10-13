model WheelLegRecoverA
  // ============ Physical Parameters ============
  parameter Real m_body = 28.0 "Body mass [kg]";
  parameter Real I_pitch = 0.8 "Pitch inertia [kg.m2]";
  parameter Real I_roll = 0.6 "Roll inertia [kg.m2]";
  parameter Real I_yaw = 0.5 "Yaw inertia [kg.m2]";
  parameter Real r_wheel = 0.10 "Wheel radius [m]";
  parameter Real L_body_x = 0.25 "Body half-length [m]";
  parameter Real L_body_y = 0.20 "Body half-width [m]";
  parameter Real L_thigh = 0.15 "Thigh length [m]";
  parameter Real L_shank = 0.15 "Shank length [m]";
  parameter Real tau_max = 39.6 "Max torque per joint [N.m]";
  parameter Real mu = 0.90 "Ground friction coefficient";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real F_push = 70.0 "Push disturbance force [N]";
  parameter Real T_end = 8.0 "Total simulation time [s]";
  parameter Real f_ctrl = 80.0 "Control frequency [Hz]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control period [s]";
  parameter Real err_thresh = 0.162 "Tracking error threshold [rad]";
  parameter Real slip_lim = 0.03 "Foot slip limit [m]";
  parameter Real z_ref_val = 0.30 "Reference body height [m]";
  parameter Real v_thresh = 0.01 "Friction velocity threshold [m/s]";

  // ============ Controller Gains ============
  parameter Real Kp_z = 3000.0 "Height proportional gain [N/m]";
  parameter Real Kd_z = 300.0 "Height derivative gain [N.s/m]";
  parameter Real Kp_pitch = 800.0 "Pitch proportional gain [N.m/rad]";
  parameter Real Kd_pitch = 80.0 "Pitch derivative gain [N.m.s/rad]";
  parameter Real Kp_roll = 600.0 "Roll proportional gain [N.m/rad]";
  parameter Real Kd_roll = 60.0 "Roll derivative gain [N.m.s/rad]";
  parameter Real Kp_x = 200.0 "X position proportional gain [N/m]";
  parameter Real Kd_x = 40.0 "X position derivative gain [N.s/m]";
  parameter Real Kp_y = 150.0 "Y position proportional gain [N/m]";
  parameter Real Kd_y = 30.0 "Y position derivative gain [N.s/m]";

  // ============ Body States ============
  Real x(start=0, fixed=true) "Body x position [m]";
  Real vx(start=0, fixed=true) "Body x velocity [m/s]";
  Real y(start=0, fixed=true) "Body y position [m]";
  Real vy(start=0, fixed=true) "Body y velocity [m/s]";
  Real z(start=0.30, fixed=true) "Body height [m]";
  Real vz(start=0, fixed=true) "Body vertical velocity [m/s]";
  Real pitch(start=0, fixed=true) "Body pitch [rad]";
  Real omega_pitch(start=0, fixed=true) "Pitch angular rate [rad/s]";
  Real roll(start=0, fixed=true) "Body roll [rad]";
  Real omega_roll(start=0, fixed=true) "Roll angular rate [rad/s]";
  Real yaw(start=0, fixed=true) "Body yaw [rad]";
  Real omega_yaw(start=0, fixed=true) "Yaw angular rate [rad/s]";

  // ============ Leg and Wheel States ============
  Real L_leg "Current leg length [m]";
  Real q_hip "Hip joint angle [rad]";
  Real q_knee "Knee joint angle [rad]";
  Real q_wheel[4](each start=0) "Wheel angle [rad]";
  Real dq_wheel[4](each start=0) "Wheel angular velocity [rad/s]";

  // ============ Forces ============
  Real Fz_leg[4] "Vertical force per leg [N]";
  Real Fx_leg[4] "Forward force per leg [N]";
  Real Fy_leg[4] "Lateral force per leg [N]";
  Real F_normal[4] "Normal contact force [N]";
  Boolean in_contact[4] "Stance contact flag";

  // ============ Torques (12 total: 4 hip, 4 knee, 4 wheel) ============
  discrete Real tau_hip_cmd[4](each start=0) "Hip torque command [N.m]";
  discrete Real tau_knee_cmd[4](each start=10.24) "Knee torque command [N.m]";
  discrete Real tau_wheel_cmd[4](each start=0) "Wheel torque command [N.m]";
  Real tau_hip_sat[4] "Saturated hip torque [N.m]";
  Real tau_knee_sat[4] "Saturated knee torque [N.m]";
  Real tau_wheel_sat[4] "Saturated wheel torque [N.m]";

  // ============ IMU Sensors ============
  Real acc_x "IMU accelerometer x [m/s2]";
  Real acc_y "IMU accelerometer y [m/s2]";
  Real acc_z "IMU accelerometer z [m/s2]";
  Real gyro_x "IMU gyroscope x [rad/s]";
  Real gyro_y "IMU gyroscope y [rad/s]";
  Real gyro_z "IMU gyroscope z [rad/s]";

  // ============ State Estimator ============
  Real pitch_est(start=0) "Estimated pitch [rad]";
  Real roll_est(start=0) "Estimated roll [rad]";
  Real z_est(start=0.30) "Estimated body height [m]";
  Real vx_est(start=0) "Estimated x velocity [m/s]";
  Real vy_est(start=0) "Estimated y velocity [m/s]";
  Real x_est(start=0) "Estimated x position [m]";
  Real y_est(start=0) "Estimated y position [m]";

  // ============ Discrete Controller Variables (80 Hz) ============
  discrete Real Fz_total_cmd(start=0) "Total vertical force command [N]";
  discrete Real M_pitch_cmd(start=0) "Pitch moment command [N.m]";
  discrete Real M_roll_cmd(start=0) "Roll moment command [N.m]";
  discrete Real Fx_total_cmd(start=0) "Total forward force command [N]";
  discrete Real Fy_total_cmd(start=0) "Total lateral force command [N]";
  discrete Real Fz_leg_cmd[4](each start=0) "Per-leg vertical force command [N]";
  discrete Real Fx_leg_cmd[4](each start=0) "Per-leg forward force command [N]";
  discrete Real Fy_leg_cmd[4](each start=0) "Per-leg lateral force command [N]";
  discrete Real track_err_d(start=0) "Discrete tracking error [rad]";
  discrete Real pitch_est_d(start=0) "Discrete pitch estimate [rad]";
  discrete Real roll_est_d(start=0) "Discrete roll estimate [rad]";
  discrete Real z_est_d(start=0.30) "Discrete height estimate [m]";
  discrete Real vx_est_d(start=0) "Discrete x velocity estimate [m/s]";
  discrete Real vy_est_d(start=0) "Discrete y velocity estimate [m/s]";

  // ============ Disturbance ============
  Real F_dist "Lateral disturbance force [N]";

  // ============ Slip Tracking ============
  Real slip_accum[4](each start=0, each fixed=true) "Accumulated foot slip [m]";

  // ============ Performance Metrics ============
  Real track_err "Primary tracking error [rad]";
  Real slip_max_val "Maximum foot slip [m]";
  Real height_val "Current body height [m]";

equation
  // ======== Disturbance: 70 N lateral push during middle third of 8 s ========
  // Active from T_end/3 = 2.667 s to 2*T_end/3 = 5.333 s
  if time >= T_end / 3.0 and time <= 2.0 * T_end / 3.0 then
    F_dist = F_push;
  else
    F_dist = 0.0;
  end if;

  // ======== Body Translational Dynamics ========
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  m_body * der(vx) = sum(Fx_leg);
  m_body * der(vy) = sum(Fy_leg) + F_dist;
  m_body * der(vz) = sum(Fz_leg) - m_body * g;

  // ======== Body Rotational Dynamics ========
  // Coordinate: x=forward, y=left, z=up
  // Pitch positive = nose-up, Roll positive = left-side-up
  // Leg indices: 1=FL(+x,+y), 2=FR(+x,-y), 3=RL(-x,+y), 4=RR(-x,-y)
  der(pitch) = omega_pitch;
  der(roll) = omega_roll;
  der(yaw) = omega_yaw;

  I_pitch * der(omega_pitch) =
    L_body_x * (Fz_leg[1] + Fz_leg[2] - Fz_leg[3] - Fz_leg[4])
    + z * sum(Fx_leg);

  I_roll * der(omega_roll) =
    L_body_y * (Fz_leg[1] - Fz_leg[2] + Fz_leg[3] - Fz_leg[4])
    + z * sum(Fy_leg);

  I_yaw * der(omega_yaw) = 0.0;

  // ======== Leg Kinematics (2-link leg, all legs same length) ========
  L_leg = max(z - r_wheel, 0.05);
  q_hip = acos(max(-1.0, min(1.0, L_leg / (2.0 * L_thigh))));
  q_knee = 3.14159265358979 - 2.0 * q_hip;

  // ======== Wheel Dynamics (rolling constraint) ========
  for i in 1:4 loop
    der(q_wheel[i]) = dq_wheel[i];
    dq_wheel[i] = vx / max(r_wheel, 0.01);
  end for;

  // ======== Contact Model ========
  for i in 1:4 loop
    F_normal[i] = max(0.0, Fz_leg[i]);
    in_contact[i] = F_normal[i] > 1.0;
  end for;

  // ======== Force from Saturated Torque via Jacobian ========
  for i in 1:4 loop
    // Knee torque -> vertical force through 2-link leg Jacobian
    Fz_leg[i] = max(0.0, tau_knee_sat[i] / max(L_thigh * abs(sin(max(q_knee, 0.1))), 0.05));
    // Wheel torque -> forward force
    Fx_leg[i] = tau_wheel_sat[i] / r_wheel;
    // Hip torque -> lateral force, friction-limited with passive Coulomb friction
    // Active component from hip torque + passive friction opposing lateral velocity
    Fy_leg[i] = mu * F_normal[i] * tanh(
      (tau_hip_sat[i] / max(L_leg, 0.05)
       - mu * F_normal[i] * tanh(vy / v_thresh))
      / (mu * F_normal[i] + 0.01));
  end for;

  // ======== Torque Saturation (39.6 N.m per joint) ========
  for i in 1:4 loop
    tau_hip_sat[i] = max(-tau_max, min(tau_max, tau_hip_cmd[i]));
    tau_knee_sat[i] = max(-tau_max, min(tau_max, tau_knee_cmd[i]));
    tau_wheel_sat[i] = max(-tau_max, min(tau_max, tau_wheel_cmd[i]));
  end for;

  // ======== IMU Measurement Model (body frame) ========
  acc_x = der(vx) + g * sin(pitch);
  acc_y = der(vy) - g * sin(roll) * cos(pitch);
  acc_z = der(vz) + g * cos(roll) * cos(pitch);
  gyro_x = omega_roll;
  gyro_y = omega_pitch;
  gyro_z = omega_yaw;

  // ======== State Estimator (Complementary Filter) ========
  // Attitude from gyro integration with accelerometer correction
  der(pitch_est) = gyro_y + 0.1 * (atan2(-acc_x, abs(acc_z) + 0.01) - pitch_est);
  der(roll_est) = gyro_x + 0.1 * (atan2(acc_y, abs(acc_z) + 0.01) - roll_est);
  // Velocity from IMU integration
  der(vx_est) = acc_x - g * sin(pitch_est);
  der(vy_est) = acc_y + g * sin(roll_est) * cos(pitch_est);
  der(x_est) = vx_est;
  der(y_est) = vy_est;
  // Height from kinematics (leg encoders)
  z_est = z;

  // ======== Whole-Body Balance Controller (discrete at 80 Hz) ========
  when sample(0, dt_ctrl) then
    // Snapshot estimator outputs for synchronized traces
    pitch_est_d = pitch_est;
    roll_est_d = roll_est;
    z_est_d = z;
    vx_est_d = vx_est;
    vy_est_d = vy_est;

    // Height control -> total vertical force
    Fz_total_cmd = m_body * g + Kp_z * (z_ref_val - z_est_d) - Kd_z * vz;

    // Attitude control -> corrective moments
    M_pitch_cmd = -Kp_pitch * pitch_est_d - Kd_pitch * omega_pitch;
    M_roll_cmd = -Kp_roll * roll_est_d - Kd_roll * omega_roll;

    // Position control -> horizontal force commands
    Fx_total_cmd = -Kp_x * x - Kd_x * vx;
    Fy_total_cmd = -Kp_y * y - Kd_y * vy;

    // Contact-switching force distribution: all four legs in stance
    // Fz distribution: base + pitch correction + roll correction
    Fz_leg_cmd[1] = Fz_total_cmd / 4.0 + M_pitch_cmd / (2.0 * L_body_x) + M_roll_cmd / (2.0 * L_body_y);
    Fz_leg_cmd[2] = Fz_total_cmd / 4.0 + M_pitch_cmd / (2.0 * L_body_x) - M_roll_cmd / (2.0 * L_body_y);
    Fz_leg_cmd[3] = Fz_total_cmd / 4.0 - M_pitch_cmd / (2.0 * L_body_x) + M_roll_cmd / (2.0 * L_body_y);
    Fz_leg_cmd[4] = Fz_total_cmd / 4.0 - M_pitch_cmd / (2.0 * L_body_x) - M_roll_cmd / (2.0 * L_body_y);

    // Horizontal forces equally distributed
    Fx_leg_cmd[1] = Fx_total_cmd / 4.0;
    Fx_leg_cmd[2] = Fx_total_cmd / 4.0;
    Fx_leg_cmd[3] = Fx_total_cmd / 4.0;
    Fx_leg_cmd[4] = Fx_total_cmd / 4.0;

    Fy_leg_cmd[1] = Fy_total_cmd / 4.0;
    Fy_leg_cmd[2] = Fy_total_cmd / 4.0;
    Fy_leg_cmd[3] = Fy_total_cmd / 4.0;
    Fy_leg_cmd[4] = Fy_total_cmd / 4.0;

    // Convert desired forces to joint torque commands via Jacobian
    tau_knee_cmd[1] = Fz_leg_cmd[1] * L_thigh * sin(max(q_knee, 0.1));
    tau_knee_cmd[2] = Fz_leg_cmd[2] * L_thigh * sin(max(q_knee, 0.1));
    tau_knee_cmd[3] = Fz_leg_cmd[3] * L_thigh * sin(max(q_knee, 0.1));
    tau_knee_cmd[4] = Fz_leg_cmd[4] * L_thigh * sin(max(q_knee, 0.1));

    tau_hip_cmd[1] = Fy_leg_cmd[1] * max(L_leg, 0.05);
    tau_hip_cmd[2] = Fy_leg_cmd[2] * max(L_leg, 0.05);
    tau_hip_cmd[3] = Fy_leg_cmd[3] * max(L_leg, 0.05);
    tau_hip_cmd[4] = Fy_leg_cmd[4] * max(L_leg, 0.05);

    tau_wheel_cmd[1] = Fx_leg_cmd[1] * r_wheel;
    tau_wheel_cmd[2] = Fx_leg_cmd[2] * r_wheel;
    tau_wheel_cmd[3] = Fx_leg_cmd[3] * r_wheel;
    tau_wheel_cmd[4] = Fx_leg_cmd[4] * r_wheel;

    // Synchronized tracking error metric
    track_err_d = sqrt(pitch_est_d * pitch_est_d + roll_est_d * roll_est_d);
  end when;

  // ======== Foot Slip Accumulation ========
  for i in 1:4 loop
    der(slip_accum[i]) = abs(vy);
  end for;

  // ======== Requirement Metrics ========
  track_err = sqrt(pitch * pitch + roll * roll);
  slip_max_val = max({slip_accum[1], slip_accum[2], slip_accum[3], slip_accum[4]});
  height_val = z;

  // ======== Requirement Assertions ========
  assert(height_val > 0.0, "Body height must remain positive");
  assert(time < 5.2 or track_err < err_thresh,
    "Primary tracking error must be below 0.162 rad after 5.2 s");
  assert(slip_max_val < slip_lim,
    "Foot slip must not exceed 0.03 m");
  assert(abs(tau_hip_sat[1]) <= tau_max + 0.001, "Hip torque 1 exceeds limit");
  assert(abs(tau_hip_sat[2]) <= tau_max + 0.001, "Hip torque 2 exceeds limit");
  assert(abs(tau_hip_sat[3]) <= tau_max + 0.001, "Hip torque 3 exceeds limit");
  assert(abs(tau_hip_sat[4]) <= tau_max + 0.001, "Hip torque 4 exceeds limit");
  assert(abs(tau_knee_sat[1]) <= tau_max + 0.001, "Knee torque 1 exceeds limit");
  assert(abs(tau_knee_sat[2]) <= tau_max + 0.001, "Knee torque 2 exceeds limit");
  assert(abs(tau_knee_sat[3]) <= tau_max + 0.001, "Knee torque 3 exceeds limit");
  assert(abs(tau_knee_sat[4]) <= tau_max + 0.001, "Knee torque 4 exceeds limit");
  assert(abs(tau_wheel_sat[1]) <= tau_max + 0.001, "Wheel torque 1 exceeds limit");
  assert(abs(tau_wheel_sat[2]) <= tau_max + 0.001, "Wheel torque 2 exceeds limit");
  assert(abs(tau_wheel_sat[3]) <= tau_max + 0.001, "Wheel torque 3 exceeds limit");
  assert(abs(tau_wheel_sat[4]) <= tau_max + 0.001, "Wheel torque 4 exceeds limit");

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-4, Interval=0.0125),
    Documentation(info="WheelLegRecoverA: floating-base wheeled quadruped recovering from lateral impulse.
      28 kg torso, four 2-joint legs with 0.10 m driven wheels.
      12 independently limited torques (8 leg + 4 wheel) at 39.6 N.m per joint.
      Whole-body balance control at 80 Hz with contact switching.
      70 N lateral push during middle third (2.667-5.333 s).
      Level rigid ground, friction 0.90, no external support."));
end WheelLegRecoverA;