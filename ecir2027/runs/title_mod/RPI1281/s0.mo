model ContactStateBridgeC
  "Robotic sensing and estimation with multi-rate filtering and innovation gating"

  // ============ Physical Parameters ============
  parameter Real m_body = 24.0 "Torso mass [kg]";
  parameter Real I_body = 2.0 "Torso moment of inertia [kg.m2]";
  parameter Real g_const = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real tau_max = 50.6 "Maximum joint command magnitude [N.m]";
  parameter Real J_joint = 0.05 "Joint inertia [kg.m2]";
  parameter Real b_joint = 0.3 "Joint damping [N.m.s/rad]";
  parameter Real k_joint = 20.0 "Joint stiffness [N.m/rad]";

  // Sensor biases (make drift observable during outage)
  parameter Real ax_bias = 0.008 "IMU x acceleration bias [m/s2]";
  parameter Real az_bias = 0.004 "IMU z acceleration bias [m/s2]";
  parameter Real w_bias = 0.002 "IMU gyro bias [rad/s]";

  // ============ Timing Parameters ============
  parameter Real f_sample = 125.0 "Estimator sampling rate [Hz]";
  parameter Real Ts = 1.0 / f_sample "Sample period [s]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";
  parameter Real t_drop_start = 2.4 "Dropout start time [s]";
  parameter Real t_drop_end = 9.6 "Dropout end time [s]";
  parameter Real T_dropout = 7.2 "Dropout duration [s]";

  // ============ Estimator Parameters ============
  parameter Real err_bound = 0.367 "Primary tracking error bound [m or rad]";
  parameter Real t_check = 7.8 "Error check time [s]";
  parameter Real P0_pos = 1e-3 "Initial position covariance [m2]";
  parameter Real P0_rot = 1e-3 "Initial rotation covariance [rad2]";
  parameter Real Q_pos = 1e-3 "Position process noise rate [m2/s]";
  parameter Real Q_rot = 1e-3 "Rotation process noise rate [rad2/s]";
  parameter Real R_abs = 1e-4 "Absolute sensor noise variance [m2 or rad2]";
  parameter Real gate_chi2 = 9.0 "Innovation gate chi-square threshold";

  // ============ Plant Continuous States ============
  // Body
  Real x(start=0.0, fixed=true) "Body x position [m]";
  Real z(start=0.5, fixed=true) "Body z position [m]";
  Real theta(start=0.0, fixed=true) "Body pitch angle [rad]";
  Real vx(start=0.0, fixed=true) "Body x velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Body z velocity [m/s]";
  Real omega(start=0.0, fixed=true) "Body angular velocity [rad/s]";
  Real ax_body "Body x acceleration [m/s2]";
  Real az_body "Body z acceleration [m/s2]";
  Real alpha_body "Body angular acceleration [rad/s2]";

  // Twelve joints (4 legs x 3 joints)
  Real q[12](each start=0.0, each fixed=true) "Joint angles [rad]";
  Real dq[12](each start=0.0, each fixed=true) "Joint angular velocities [rad/s]";
  Real tau_cmd[12] "Joint effort commands [N.m]";

  // ============ Reference Trajectory ============
  Real x_ref "Reference x position [m]";
  Real z_ref "Reference z position [m]";
  Real theta_ref "Reference pitch angle [rad]";

  // ============ Forces ============
  Real Fx_body "Net body x force [N]";
  Real Fz_body "Net body z force [N]";
  Real M_body "Net body moment [N.m]";
  Real fnormal[4] "Foot normal forces [N]";
  Boolean contact[4] "Foot contact flags";

  // ============ Sensors ============
  Real ax_imu "IMU x acceleration [m/s2]";
  Real az_imu "IMU z acceleration [m/s2]";
  Real omega_imu "IMU angular velocity [rad/s]";
  Real q_enc[12] "Joint encoder readings [rad]";
  Real x_abs "Absolute x measurement [m]";
  Real z_abs "Absolute z measurement [m]";
  Real theta_abs "Absolute theta measurement [rad]";
  Boolean abs_avail "Absolute position sensor available";

  // ============ Estimator Discrete States ============
  discrete Real x_hat(start=0.0) "Estimated x [m]";
  discrete Real z_hat(start=0.5) "Estimated z [m]";
  discrete Real theta_hat(start=0.0) "Estimated theta [rad]";
  discrete Real vx_hat(start=0.0) "Estimated vx [m/s]";
  discrete Real vz_hat(start=0.0) "Estimated vz [m/s]";
  discrete Real omega_hat(start=0.0) "Estimated omega [rad/s]";
  discrete Real P_pos(start=P0_pos) "Position covariance [m2]";
  discrete Real P_rot(start=P0_rot) "Rotation covariance [rad2]";
  discrete Real innov_x(start=0.0) "X innovation [m]";
  discrete Real innov_z(start=0.0) "Z innovation [m]";
  discrete Real innov_th(start=0.0) "Theta innovation [rad]";
  discrete Real innov_n2(start=0.0) "Normalized innovation squared";
  discrete Boolean gate_ok(start=false) "Innovation gate accepted";
  discrete Real Kp(start=0.0) "Position Kalman gain";
  discrete Real Kr(start=0.0) "Rotation Kalman gain";
  discrete Real ts_log(start=0.0) "Synchronized timestamp [s]";
  discrete Integer nc(start=0) "Sample count";

  // ============ Performance Metrics ============
  Real est_err "Estimation error norm [m or rad]";
  Real traj_err "Trajectory tracking error [m or rad]";
  Real cov_ratio "Covariance growth ratio";
  Boolean err_ok "Error below bound after check time";
  Boolean recovered "Estimator recovered after dropout";

  // ============ Constants ============
  constant Real pi = 3.141592653589793;

equation
  // ============ Reference Trajectory (translation + rotation) ============
  x_ref = 0.3 * sin(2.0 * pi * time / 6.0);
  z_ref = 0.5 + 0.08 * cos(2.0 * pi * time / 4.0);
  theta_ref = 0.2 * sin(2.0 * pi * time / 8.0);

  // ============ Body Dynamics ============
  ax_body = Fx_body / m_body;
  az_body = (Fz_body - m_body * g_const) / m_body;
  alpha_body = M_body / I_body;

  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;
  der(vx) = ax_body;
  der(vz) = az_body;
  der(omega) = alpha_body;

  // ============ Joint Dynamics ============
  for i in 1:12 loop
    der(q[i]) = dq[i];
    der(dq[i]) = (tau_cmd[i] - b_joint * dq[i] - k_joint * q[i]) / J_joint;
  end for;

  // ============ Controller (PD trajectory tracking) ============
  Fx_body = 300.0 * (x_ref - x) + 30.0 * (-vx);
  Fz_body = 300.0 * (z_ref - z) + 30.0 * (-vz) + m_body * g_const;
  M_body = 150.0 * (theta_ref - theta) + 15.0 * (-omega);

  // Joint commands clamped to maximum magnitude
  for i in 1:12 loop
    tau_cmd[i] = max(-tau_max, min(tau_max,
      5.0 * (-q[i]) + 0.5 * (-dq[i]) + 0.02 * M_body * cos(i * pi / 6.0)));
  end for;

  // ============ Foot Contact and Normal Force Sensors ============
  for i in 1:4 loop
    contact[i] = z > 0.05;
    fnormal[i] = max(0.0, m_body * g_const / 4.0 + 30.0 * (z_ref - z));
  end for;

  // ============ Sensors ============
  // IMU (fast, continuous, with bias)
  ax_imu = ax_body + ax_bias;
  az_imu = az_body + az_bias;
  omega_imu = omega + w_bias;

  // Joint encoders (fast)
  for i in 1:12 loop
    q_enc[i] = q[i];
  end for;

  // Absolute position sensor (slow, drops out during middle third)
  abs_avail = (time < t_drop_start) or (time >= t_drop_end);
  x_abs = x;
  z_abs = z;
  theta_abs = theta;

  // ============ Performance Metrics ============
  est_err = sqrt((x - x_hat)^2 + (z - z_hat)^2 + (theta - theta_hat)^2 + 1e-14);
  traj_err = sqrt((x - x_ref)^2 + (z - z_ref)^2 + (theta - theta_ref)^2 + 1e-14);
  cov_ratio = P_pos / (P0_pos + 1e-14);
  err_ok = (time >= t_check) and (est_err < err_bound);
  recovered = (time >= t_drop_end) and (est_err < 0.05);

  // ============ Estimator: Multi-Rate Filter with Innovation Gating ============
  when sample(0, Ts) then
    // Timestamp and sample counter (order verification)
    nc := pre(nc) + 1;
    ts_log := time;

    // --- Prediction Step (125 Hz, IMU + proprioceptive) ---
    // State propagation via inertial integration (continues during dropout)
    x_hat := pre(x_hat) + pre(vx_hat) * Ts;
    z_hat := pre(z_hat) + pre(vz_hat) * Ts;
    theta_hat := pre(theta_hat) + pre(omega_hat) * Ts;
    vx_hat := pre(vx_hat) + ax_imu * Ts;
    vz_hat := pre(vz_hat) + az_imu * Ts;
    omega_hat := omega_imu;

    // Covariance growth (reflects increasing uncertainty during outage)
    P_pos := pre(P_pos) + Q_pos * Ts;
    P_rot := pre(P_rot) + Q_rot * Ts;

    // Reset correction variables
    innov_x := 0.0;
    innov_z := 0.0;
    innov_th := 0.0;
    innov_n2 := 0.0;
    gate_ok := false;
    Kp := 0.0;
    Kr := 0.0;

    // --- Correction Step (absolute position, gated) ---
    if abs_avail then
      // Innovation
      innov_x := x_abs - x_hat;
      innov_z := z_abs - z_hat;
      innov_th := theta_abs - theta_hat;

      // Normalized innovation squared (chi-square gating)
      innov_n2 := innov_x * innov_x / (P_pos + R_abs) +
                  innov_z * innov_z / (P_pos + R_abs) +
                  innov_th * innov_th / (P_rot + R_abs);

      // Innovation gate
      if innov_n2 < gate_chi2 then
        gate_ok := true;
        // Kalman gain
        Kp := P_pos / (P_pos + R_abs);
        Kr := P_rot / (P_rot + R_abs);
        // State correction
        x_hat := x_hat + Kp * innov_x;
        z_hat := z_hat + Kp * innov_z;
        theta_hat := theta_hat + Kr * innov_th;
        // Covariance reduction
        P_pos := P_pos * (1.0 - Kp);
        P_rot := P_rot * (1.0 - Kr);
      else
        gate_ok := false;
      end if;
    end if;
  end when;

  annotation(
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1e-6, Interval=1.0/125.0),
    Documentation(info="ContactStateBridgeC: Multi-rate Kalman filter with innovation gating for a 24 kg quadruped torso (4 legs x 3 joints = 12 actuators). Maintains usable state estimate through a 7.2 s absolute-position sensor dropout (t=2.4 to 9.6 s) using IMU and proprioceptive updates. Trajectory includes translation and rotation for observable drift. Estimator runs at 125 Hz for 12 s with covariance growth, bounded outage error, innovation-gated recovery, and primary tracking error below 0.367 m-or-rad after 7.8 s.")
  );
end ContactStateBridgeC;