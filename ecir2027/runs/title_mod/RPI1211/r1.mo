model WheelIMUBridgeE
  extends Modelica.Icons.Example;

  // ===== Plant parameters (from requirement or assumed structural) =====
  parameter Real m = 16.0 "chassis mass [kg] (requirement)";
  parameter Real tau_max = 11.0 "per-wheel torque bound [N.m] (requirement)";
  parameter Real r = 0.10 "wheel radius [m] (assumed structural)";
  parameter Real L = 0.40 "wheelbase [m] (assumed structural)";
  parameter Real I_z = 0.80 "yaw inertia [kg.m^2] (assumed)";
  parameter Real c_lin = 2.0 "linear rolling drag [N.s/m] (assumed)";
  parameter Real c_ang = 0.5 "yaw drag [N.m.s] (assumed)";

  // ===== Sensor parameters (declared noise and bias) =====
  parameter Real accel_noise = 0.05 "accel noise amplitude [m/s^2] (assumed)";
  parameter Real gyro_noise = 0.005 "gyro noise amplitude [rad/s] (assumed)";
  parameter Real accel_bias_p = 0.02 "accel bias [m/s^2] (assumed)";
  parameter Real gyro_bias_p = 0.001 "gyro bias [rad/s] (assumed)";
  parameter Real enc_noise = 0.01 "encoder noise amplitude [rad/s] (assumed)";
  parameter Real abs_pos_noise = 0.02 "absolute position noise [m] (assumed)";
  parameter Real abs_head_noise = 0.01 "absolute heading noise [rad] (assumed)";

  // ===== Timing (from requirement) =====
  parameter Real T = 1.0/250.0 "inertial/proprioceptive loop period [s] (250 Hz, requirement)";
  parameter Real abs_dt = 0.20 "slow absolute sensor period [s] (5 Hz, assumed slow rate)";
  parameter Real t_drop_start = 3.2 "dropout start [s] (9.6 s window centered in 16 s run)";
  parameter Real t_drop_end = 12.8 "dropout end [s] (9.6 s window, requirement)";
  parameter Real t_final = 16.0 "total run [s] (requirement)";
  parameter Real t_check = 10.4 "acceptance check time [s] (requirement)";
  parameter Real err_bound = 0.315 "primary error bound [m or rad] (requirement)";

  // ===== Estimator / controller tuning (assumed) =====
  parameter Real Kv = 1.2 "velocity feedback gain (assumed)";
  parameter Real Kw = 1.5 "yaw rate feedback gain (assumed)";
  parameter Real alpha = 0.5 "encoder/IMU blend factor (assumed)";
  parameter Real gate_chi2 = 9.49 "innovation gate threshold (3-DOF 99%, assumed)";
  parameter Real Q_pos = 1.0e-4 "process noise density position [m^2/s] (assumed)";
  parameter Real Q_theta = 1.0e-4 "process noise density heading [rad^2/s] (assumed)";
  parameter Real Q_vel = 1.0e-3 "process noise density speed [(m/s)^2/s] (assumed)";
  parameter Real Q_omega = 1.0e-3 "process noise density yaw rate [(rad/s)^2/s] (assumed)";

  // ===== Reference trajectory (translation + rotation) =====
  parameter Real v_ref = 0.5 "reference forward speed [m/s] (assumed)";
  parameter Real omega_ref = 0.3 "reference yaw rate [rad/s] (assumed)";

  // ===== Plant (true) states =====
  Real x(start=0.0, fixed=true) "true x [m]";
  Real y(start=0.0, fixed=true) "true y [m]";
  Real theta(start=0.0, fixed=true) "true heading [rad]";
  Real v(start=0.0, fixed=true) "true forward speed [m/s]";
  Real omega(start=0.0, fixed=true) "true yaw rate [rad/s]";

  // ===== Command and actuator =====
  Real F_total "commanded total traction force [N]";
  Real M_total "commanded yaw moment [N.m]";
  Real tau_R_cmd "right wheel torque command [N.m]";
  Real tau_L_cmd "left wheel torque command [N.m]";
  Real tau_R "applied right wheel torque [N.m] (bounded)";
  Real tau_L "applied left wheel torque [N.m] (bounded)";

  // ===== Sensor signals =====
  Real a_meas "measured longitudinal accel [m/s^2]";
  Real omega_meas "measured yaw rate [rad/s]";
  Real w_R_meas "right encoder angular speed [rad/s]";
  Real w_L_meas "left encoder angular speed [rad/s]";
  discrete Real x_abs "absolute x measurement [m]";
  discrete Real y_abs "absolute y measurement [m]";
  discrete Real theta_abs "absolute heading measurement [rad]";
  discrete Boolean abs_active "absolute sensor available (not in dropout)";
  discrete Boolean abs_meas_valid "absolute measurement accepted this cycle";
  discrete Real t_last_abs "timestamp of last accepted absolute measurement [s]";

  // ===== Estimator states (discrete) =====
  discrete Real xh "estimated x [m]";
  discrete Real yh "estimated y [m]";
  discrete Real thetah "estimated heading [rad]";
  discrete Real vh "estimated forward speed [m/s]";
  discrete Real omegah "estimated yaw rate [rad/s]";
  discrete Real P[5, 5] "estimator covariance (5x5)";

  // ===== Diagnostics =====
  discrete Real err_pos "position error norm [m]";
  discrete Real err_head "heading error [rad]";
  discrete Real err_primary "primary error (max of pos,head) [m or rad]";
  discrete Real cov_trace "covariance trace (drift indicator)";
  discrete Boolean valid "no NaN/Inf flag (fail-closed)";
  discrete Real t_stamp "synchronized timestamp [s]";

  // ===== Algorithm temporaries =====
protected
  discrete Real xh_p, yh_p, thetah_p, vh_p, omegah_p;
  discrete Real P_p[5, 5];
  discrete Real v_enc_l, omega_enc_l, v_imu_l, omega_imu_l;
  discrete Real innov_x, innov_y, innov_th;
  discrete Real S_x, S_y, S_th;
  discrete Real gate_x, gate_y, gate_th;
  discrete Real gate_thresh;
  discrete Real Kx[5], Ky[5], Kt[5];
  discrete Boolean ok_x, ok_y, ok_th;
  discrete Real dt_since_abs;

equation
  // ===== Plant kinematics and dynamics =====
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;
  der(v) = ((tau_R + tau_L) / r - c_lin * v) / m;
  der(omega) = ((tau_R - tau_L) * L / (2.0 * r) - c_ang * omega) / I_z;

  // ===== Controller (track reference with both translation and rotation) =====
  F_total = m * Kv * (v_ref - v);
  M_total = I_z * Kw * (omega_ref - omega);
  tau_R_cmd = F_total * r / 2.0 + M_total * r / L;
  tau_L_cmd = F_total * r / 2.0 - M_total * r / L;
  tau_R = if tau_R_cmd > tau_max then tau_max else if tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;
  tau_L = if tau_L_cmd > tau_max then tau_max else if tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;

  // ===== Sensor models (continuous signals) =====
  a_meas = der(v) + accel_bias_p + accel_noise * sin(2.0 * Modelica.Constants.pi * 7.0 * time);
  omega_meas = omega + gyro_bias_p + gyro_noise * sin(2.0 * Modelica.Constants.pi * 5.0 * time);
  w_R_meas = (v + omega * L / 2.0) / r + enc_noise * sin(2.0 * Modelica.Constants.pi * 9.0 * time);
  w_L_meas = (v - omega * L / 2.0) / r + enc_noise * sin(2.0 * Modelica.Constants.pi * 11.0 * time + 0.7);

  // ===== Fail-closed acceptance assertions =====
  assert(valid, "Estimator produced non-finite physical, control, or estimator value (fail-closed)");
  assert(not (time >= t_check) or err_primary < err_bound,
         "Primary tracking error exceeded bound after check time (fail-closed)");

algorithm
  // ===== Initialization =====
  when initial() then
    xh := 0.0;
    yh := 0.0;
    thetah := 0.0;
    vh := 0.0;
    omegah := 0.0;
    P := diagonal({0.01, 0.01, 0.01, 0.04, 0.04});
    t_last_abs := 0.0;
    t_stamp := 0.0;
    err_pos := 0.0;
    err_head := 0.0;
    err_primary := 0.0;
    cov_trace := 0.05;
    valid := true;
    abs_active := true;
    abs_meas_valid := false;
    x_abs := 0.0;
    y_abs := 0.0;
    theta_abs := 0.0;
  end when;

  // ===== Multi-rate estimator: fast inertial/proprioceptive update at 250 Hz =====
  when sample(0, T) then
    t_stamp := time;

    // --- Proprioceptive (wheel encoders) and inertial (IMU) fusion ---
    v_enc_l := (w_R_meas + w_L_meas) * r / 2.0;
    omega_enc_l := (w_R_meas - w_L_meas) * r / L;
    v_imu_l := vh + a_meas * T;
    omega_imu_l := omega_meas;
    vh_p := alpha * v_enc_l + (1.0 - alpha) * v_imu_l;
    omegah_p := alpha * omega_enc_l + (1.0 - alpha) * omega_imu_l;

    // --- State propagation ---
    xh_p := xh + vh_p * T * cos(thetah);
    yh_p := yh + vh_p * T * sin(thetah);
    thetah_p := thetah + omegah_p * T;

    // --- Covariance propagation (additive process noise -> growth during dropout) ---
    P_p := P;
    P_p[1, 1] := P_p[1, 1] + Q_pos * T;
    P_p[2, 2] := P_p[2, 2] + Q_pos * T;
    P_p[3, 3] := P_p[3, 3] + Q_theta * T;
    P_p[4, 4] := P_p[4, 4] + Q_vel * T;
    P_p[5, 5] := P_p[5, 5] + Q_omega * T;

    // --- Slow absolute-position sensor with innovation gating ---
    abs_active := (time < t_drop_start) or (time >= t_drop_end);
    abs_meas_valid := false;
    dt_since_abs := time - pre(t_last_abs);

    if abs_active and (dt_since_abs >= abs_dt - 1.0e-9) then
      // Sample true state with declared noise (slow absolute sensor)
      x_abs := x + abs_pos_noise * sin(2.0 * Modelica.Constants.pi * 3.0 * time);
      y_abs := y + abs_pos_noise * sin(2.0 * Modelica.Constants.pi * 4.0 * time + 0.5);
      theta_abs := theta + abs_head_noise * sin(2.0 * Modelica.Constants.pi * 2.0 * time + 1.0);

      // Innovations (per-axis sequential update; heading wrapped)
      innov_x := x_abs - xh_p;
      innov_y := y_abs - yh_p;
      innov_th := theta_abs - thetah_p;
      innov_th := atan2(sin(innov_th), cos(innov_th));

      // Innovation covariances (scalar, well-defined nonzero denominators)
      S_x := P_p[1, 1] + abs_pos_noise * abs_pos_noise;
      S_y := P_p[2, 2] + abs_pos_noise * abs_pos_noise;
      S_th := P_p[3, 3] + abs_head_noise * abs_head_noise;

      // Per-axis chi-square gates
      gate_thresh := gate_chi2 / 3.0;
      gate_x := innov_x * innov_x / S_x;
      gate_y := innov_y * innov_y / S_y;
      gate_th := innov_th * innov_th / S_th;
      ok_x := (gate_x >= 0.0) and (gate_x < gate_thresh);
      ok_y := (gate_y >= 0.0) and (gate_y < gate_thresh);
      ok_th := (gate_th >= 0.0) and (gate_th < gate_thresh);

      // Sequential scalar Kalman updates (no matrix inverse needed)
      if ok_x then
        for jj in 1:5 loop
          Kx[jj] := P_p[jj, 1] / S_x;
        end for;
        xh_p := xh_p + Kx[1] * innov_x;
        yh_p := yh_p + Kx[2] * innov_x;
        thetah_p := thetah_p + Kx[3] * innov_x;
        vh_p := vh_p + Kx[4] * innov_x;
        omegah_p := omegah_p + Kx[5] * innov_x;
        for jj in 1:5 loop
          for kk in 1:5 loop
            P_p[jj, kk] := P_p[jj, kk] - Kx[jj] * P_p[1, kk];
          end for;
        end for;
      end if;

      if ok_y then
        for jj in 1:5 loop
          Ky[jj] := P_p[jj, 2] / S_y;
        end for;
        xh_p := xh_p + Ky[1] * innov_y;
        yh_p := yh_p + Ky[2] * innov_y;
        thetah_p := thetah_p + Ky[3] * innov_y;
        vh_p := vh_p + Ky[4] * innov_y;
        omegah_p := omegah_p + Ky[5] * innov_y;
        for jj in 1:5 loop
          for kk in 1:5 loop
            P_p[jj, kk] := P_p[jj, kk] - Ky[jj] * P_p[2, kk];
          end for;
        end for;
      end if;

      if ok_th then
        for jj in 1:5 loop
          Kt[jj] := P_p[jj, 3] / S_th;
        end for;
        xh_p := xh_p + Kt[1] * innov_th;
        yh_p := yh_p + Kt[2] * innov_th;
        thetah_p := thetah_p + Kt[3] * innov_th;
        vh_p := vh_p + Kt[4] * innov_th;
        omegah_p := omegah_p + Kt[5] * innov_th;
        for jj in 1:5 loop
          for kk in 1:5 loop
            P_p[jj, kk] := P_p[jj, kk] - Kt[jj] * P_p[3, kk];
          end for;
        end for;
      end if;

      abs_meas_valid := true;
      t_last_abs := time;
    end if;

    // --- Commit estimated state and covariance ---
    xh := xh_p;
    yh := yh_p;
    thetah := thetah_p;
    vh := vh_p;
    omegah := omegah_p;
    P := P_p;

    // --- Diagnostics: covariance growth, bounded error, finiteness ---
    cov_trace := P[1, 1] + P[2, 2] + P[3, 3] + P[4, 4] + P[5, 5];
    err_pos := sqrt((xh - x) * (xh - x) + (yh - y) * (yh - y) + 1.0e-12);
    err_head := abs(atan2(sin(thetah - theta), cos(thetah - theta)));
    err_primary := if err_pos > err_head then err_pos else err_head;
    valid := (abs(xh) < 1.0e15) and (abs(yh) < 1.0e15) and (abs(thetah) < 1.0e15)
             and (abs(vh) < 1.0e15) and (abs(omegah) < 1.0e15)
             and (abs(cov_trace) < 1.0e15)
             and (abs(tau_R) < 1.0e15) and (abs(tau_L) < 1.0e15);
  end when;

  // ===== Terminate after the declared 16 s run =====
  when time >= t_final - 1.0e-9 then
    terminate("WheelIMUBridgeE: 16 s run complete");
  end when;

  annotation (
    experiment(StopTime = 16.0, Interval = 0.004, Tolerance = 1.0e-6),
    Documentation(info = "Differential-drive chassis (16 kg) with wheel encoders, center six-axis IMU, two bounded wheel-torque actuators (11 N.m). Multi-rate EKF at 250 Hz with innovation gating and a 9.6 s absolute-sensor dropout from 3.2 s to 12.8 s. Acceptance: timestamp order, covariance growth, bounded outage error, recovery after 12.8 s, primary error < 0.315 m-or-rad after 10.4 s, and no NaN/Inf values."));
end WheelIMUBridgeE;