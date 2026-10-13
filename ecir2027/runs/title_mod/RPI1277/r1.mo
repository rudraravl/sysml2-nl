model ContactStateLocalizeE
  "Robotic quadruped sensing and estimation: EKF pose/velocity/bias estimation with bounded route following"

  // ===== Constants =====
  constant Real pi_c = 3.141592653589793;

  // ===== Simulation parameters =====
  parameter Real T_sim = 16.0 "Total simulation time [s]";
  parameter Real f_rate = 250.0 "Sensor and control rate [Hz]";
  parameter Real dt = 1.0 / f_rate "Sample period [s]";

  // ===== Torso parameters =====
  parameter Real m_torso = 24.0 "Torso mass [kg]";
  parameter Real I_torso = 1.2 "Torso planar inertia [kg.m^2]";
  parameter Real h_torso = 0.50 "Torso height above ground [m]";
  parameter Real b_damp = 2.0 "Linear damping [N.s/m]";
  parameter Real b_damp_theta = 0.5 "Angular damping [N.m.s/rad]";

  // ===== Actuator parameters =====
  parameter Real tau_max = 60.5 "Max joint torque per joint [N.m]";
  parameter Integer n_actuators = 12 "Number of joint effort actuators";

  // ===== Leg parameters =====
  parameter Real L1 = 0.25 "Hip link length [m]";
  parameter Real L2 = 0.25 "Knee link length [m]";
  parameter Real L3 = 0.20 "Ankle link length [m]";
  parameter Real leg_offset_x[4] = {0.30, 0.30, -0.30, -0.30} "Hip x offset [m]";
  parameter Real leg_offset_y[4] = {0.20, -0.20, 0.20, -0.20} "Hip y offset [m]";
  parameter Real I_joint = 0.010 "Joint inertia [kg.m^2]";
  parameter Real b_joint = 0.10 "Joint damping [N.m.s/rad]";
  parameter Real q_nominal = 0.37 "Nominal joint angle [rad]";
  parameter Real k_contact = 500.0 "Contact stiffness [N/m]";
  parameter Real contact_thresh = 0.01 "Contact threshold [m]";

  // ===== Controller parameters =====
  parameter Real Kp_pos = 2000.0 "Position proportional gain";
  parameter Real Kd_pos = 1000.0 "Position derivative gain";
  parameter Real Kp_att = 500.0 "Attitude proportional gain";
  parameter Real Kd_att = 200.0 "Attitude derivative gain";
  parameter Real Kp_joint = 20.0 "Joint PD proportional gain";
  parameter Real Kd_joint = 2.0 "Joint PD derivative gain";
  parameter Real force_gain = 0.10 "Torque-to-force conversion gain";
  parameter Real torque_gain = 0.10 "Torque-to-torque conversion gain";

  // ===== Trajectory parameters =====
  parameter Real route_radius = 1.50 "Bounded route radius [m]";
  parameter Real route_freq = 0.10 "Route frequency [Hz]";
  parameter Real omega_route = 2.0 * pi_c * route_freq "Route angular frequency [rad/s]";

  // ===== Sensor parameters =====
  parameter Real f_imu = 250.0 "IMU sensor rate [Hz]";
  parameter Real f_enc = 250.0 "Joint encoder rate [Hz]";
  parameter Real f_foot = 250.0 "Foot contact/force sensor rate [Hz]";
  parameter Real f_lm = 83.33 "Landmark sensor rate [Hz] (asynchronous)";
  parameter Real sigma_imu_accel = 0.05 "IMU accelerometer std dev [m/s^2]";
  parameter Real sigma_imu_gyro = 0.001 "IMU gyroscope std dev [rad/s]";
  parameter Real sigma_enc = 0.001 "Joint encoder std dev [rad]";
  parameter Real sigma_foot_force = 1.0 "Foot force sensor std dev [N]";
  parameter Real sigma_lm_range = 0.02 "Landmark range std dev [m]";
  parameter Real sigma_lm_bearing = 0.01 "Landmark bearing std dev [rad]";

  // Sensor frame identifiers (preserved as structural metadata)
  parameter String frame_imu = "body" "IMU measurement frame";
  parameter String frame_enc = "joint" "Encoder measurement frame";
  parameter String frame_foot = "world_z" "Foot sensor frame";
  parameter String frame_lm = "world" "Landmark sensor frame";

  // ===== Landmark positions (fixed external references, no ground truth to estimator) =====
  parameter Real lm_x[3] = {5.0, -5.0, 0.0} "Landmark x positions [m]";
  parameter Real lm_y[3] = {0.0, 5.0, -5.0} "Landmark y positions [m]";

  // ===== EKF parameters =====
  parameter Real Q_pos = 1.0e-6 "Process noise position [m^2]";
  parameter Real Q_vel = 1.0e-4 "Process noise velocity [(m/s)^2]";
  parameter Real Q_att = 1.0e-6 "Process noise attitude [rad^2]";
  parameter Real Q_omega = 1.0e-4 "Process noise angular velocity [(rad/s)^2]";
  parameter Real Q_bias_a = 1.0e-8 "Process noise accel bias [(m/s^2)^2]";
  parameter Real Q_bias_g = 1.0e-8 "Process noise gyro bias [(rad/s)^2]";
  parameter Real R_lm_range = sigma_lm_range^2 "Measurement noise range [m^2]";
  parameter Real R_lm_bearing = sigma_lm_bearing^2 "Measurement noise bearing [rad^2]";
  parameter Real bias_corr_gain = 50.0 "Bias correction gain from position innovation";

  // ===== Bias disturbance parameters =====
  parameter Real bias_step = 0.048 "Controlled bias step magnitude [m/s^2]";
  parameter Real t_dist_start = T_sim / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * T_sim / 3.0 "Disturbance end time [s]";

  // ===== Acceptance parameters =====
  parameter Real err_band_pos = 0.18 "Position error band [m]";
  parameter Real err_band_att = 0.18 "Attitude error band [rad]";
  parameter Real cov_min = 1.0e-12 "Minimum covariance";
  parameter Real cov_max = 1.0e4 "Maximum covariance";
  parameter Real bias_conv_thresh = 0.02 "Bias convergence threshold";
  parameter Real t_accept_check = 10.4 "Tracking acceptance check time [s]";
  parameter Real t_bias_conv = 12.0 "Bias convergence check time [s]";

  // ===== Plant state =====
  Real px(start = 0.0) "Torso x position [m]";
  Real py(start = 0.0) "Torso y position [m]";
  Real theta(start = 1.57079632679490) "Torso heading [rad]";
  Real vx(start = 0.0) "Torso x velocity [m/s]";
  Real vy(start = 0.0) "Torso y velocity [m/s]";
  Real omega(start = 0.0) "Torso angular velocity [rad/s]";

  // ===== Reference trajectory =====
  Real px_ref "Reference x [m]";
  Real py_ref "Reference y [m]";
  Real theta_ref "Reference heading [rad]";
  Real vx_ref "Reference vx [m/s]";
  Real vy_ref "Reference vy [m/s]";
  Real omega_ref "Reference angular velocity [rad/s]";

  // ===== Joint state (4 legs x 3 joints = 12 DOF) =====
  Real q[4,3](each start = 0.37) "Joint angles [rad]";
  Real qd[4,3](each start = 0.0) "Joint velocities [rad/s]";
  Real tau_cmd[4,3] "Commanded joint torques [N.m]";
  Real tau_sat[4,3] "Saturated joint torques [N.m]";

  // ===== Foot state =====
  Real foot_z[4] "Foot height above ground [m]";
  Real foot_x[4] "Foot x position in world [m]";
  Real foot_y_world[4] "Foot y position in world [m]";
  Real foot_contact[4] "Contact indicator (0=no, 1=yes)";
  Real foot_force[4] "Foot normal force [N]";
  Real foot_force_meas[4] "Measured foot normal force with noise [N]";

  // ===== IMU =====
  Real b_ax_true "True x accel bias [m/s^2]";
  Real b_ay_true "True y accel bias [m/s^2]";
  Real b_gz_true "True z gyro bias [rad/s]";
  Real ax_true "True x acceleration [m/s^2]";
  Real ay_true "True y acceleration [m/s^2]";
  Real imu_ax "IMU accel x measurement [m/s^2]";
  Real imu_ay "IMU accel y measurement [m/s^2]";
  Real imu_gz "IMU gyro z measurement [rad/s]";

  // ===== Joint encoder readings =====
  Real enc_meas[4,3] "Joint encoder measurements [rad]";

  // ===== Landmark measurements =====
  Real lm_range_meas[3] "Measured range to landmarks [m]";
  Real lm_bearing_meas[3] "Measured bearing to landmarks [rad]";

  // ===== Net force/torque on torso =====
  Real Fx_net "Net force x [N]";
  Real Fy_net "Net force y [N]";
  Real Tz_net "Net torque z [N.m]";
  Real Fx_des "Desired force x [N]";
  Real Fy_des "Desired force y [N]";
  Real Tz_des "Desired torque z [N.m]";

  // ===== EKF discrete state =====
  discrete Real ekf_px(start = 0.0) "Estimated x [m]";
  discrete Real ekf_py(start = 0.0) "Estimated y [m]";
  discrete Real ekf_theta(start = 1.57079632679490) "Estimated heading [rad]";
  discrete Real ekf_vx(start = 0.0) "Estimated vx [m/s]";
  discrete Real ekf_vy(start = 0.0) "Estimated vy [m/s]";
  discrete Real ekf_omega(start = 0.0) "Estimated omega [rad/s]";
  discrete Real ekf_b_ax(start = 0.0) "Estimated accel x bias [m/s^2]";
  discrete Real ekf_b_ay(start = 0.0) "Estimated accel y bias [m/s^2]";
  discrete Real ekf_b_gz(start = 0.0) "Estimated gyro z bias [rad/s]";

  // ===== EKF discrete covariance (diagonal) =====
  discrete Real P_px(start = 1.0) "Covariance px [m^2]";
  discrete Real P_py(start = 1.0) "Covariance py [m^2]";
  discrete Real P_theta(start = 0.1) "Covariance theta [rad^2]";
  discrete Real P_vx(start = 0.1) "Covariance vx [(m/s)^2]";
  discrete Real P_vy(start = 0.1) "Covariance vy [(m/s)^2]";
  discrete Real P_omega(start = 0.01) "Covariance omega [(rad/s)^2]";
  discrete Real P_b_ax(start = 0.01) "Covariance b_ax [(m/s^2)^2]";
  discrete Real P_b_ay(start = 0.01) "Covariance b_ay [(m/s^2)^2]";
  discrete Real P_b_gz(start = 0.001) "Covariance b_gz [(rad/s)^2]";

  // ===== Timestamps and synchronized traces =====
  discrete Real tstamp_imu(start = 0.0) "IMU sample timestamp [s]";
  discrete Real tstamp_enc(start = 0.0) "Encoder sample timestamp [s]";
  discrete Real tstamp_foot(start = 0.0) "Foot sensor sample timestamp [s]";
  discrete Real tstamp_lm(start = 0.0) "Landmark sample timestamp [s]";
  discrete Real trace_time(start = 0.0) "Synchronized trace timestamp [s]";
  discrete Real trace_px(start = 0.0) "Trace: true torso px [m]";
  discrete Real trace_py(start = 0.0) "Trace: true torso py [m]";
  discrete Real trace_theta(start = 0.0) "Trace: true torso theta [rad]";
  discrete Real trace_ekf_px(start = 0.0) "Trace: EKF px [m]";
  discrete Real trace_ekf_py(start = 0.0) "Trace: EKF py [m]";
  discrete Real trace_ekf_theta(start = 0.0) "Trace: EKF theta [rad]";
  discrete Real trace_ekf_b_ax(start = 0.0) "Trace: EKF b_ax [m/s^2]";
  discrete Real trace_tau_cmd_11(start = 0.0) "Trace: commanded tau[1,1] [N.m]";
  discrete Real trace_tau_sat_11(start = 0.0) "Trace: saturated tau[1,1] [N.m]";
  discrete Real trace_foot_force_1(start = 0.0) "Trace: foot force leg 1 [N]";
  discrete Real trace_track_err(start = 0.0) "Trace: tracking error [m]";

  // ===== Step counter =====
  discrete Integer step_cnt(start = 0) "EKF step counter";

  // ===== Acceptance =====
  discrete Boolean accept(start = true) "Fail-closed acceptance flag";
  Real track_err "Primary tracking error [m-or-rad]";
  Real pos_est_err "Position estimation error [m]";
  Real att_est_err "Attitude estimation error [rad]";
  Real bias_est_err "Bias estimation error [m/s^2]";

  // ===== EKF function =====
  function ekf_step
    "Extended Kalman Filter step: predict + asynchronous landmark update + bias correction"
    input Real prev_px;
    input Real prev_py;
    input Real prev_th;
    input Real prev_vx;
    input Real prev_vy;
    input Real prev_om;
    input Real prev_bax;
    input Real prev_bay;
    input Real prev_bgz;
    input Real prev_Ppx;
    input Real prev_Ppy;
    input Real prev_Pth;
    input Real prev_Pvx;
    input Real prev_Pvy;
    input Real prev_Pom;
    input Real prev_Pbax;
    input Real prev_Pbay;
    input Real prev_Pbgz;
    input Real imu_ax_in;
    input Real imu_ay_in;
    input Real imu_gz_in;
    input Real lm_r1;
    input Real lm_r2;
    input Real lm_r3;
    input Real lm_b1;
    input Real lm_b2;
    input Real lm_b3;
    input Real lm_x1;
    input Real lm_x2;
    input Real lm_x3;
    input Real lm_y1;
    input Real lm_y2;
    input Real lm_y3;
    input Real dt_in;
    input Real Qp;
    input Real Qv;
    input Real Qa;
    input Real Qo;
    input Real Qba;
    input Real Qbg;
    input Real Rr;
    input Real Rb;
    input Real bgain;
    input Real covmin;
    input Boolean do_update;
    output Real new_px;
    output Real new_py;
    output Real new_th;
    output Real new_vx;
    output Real new_vy;
    output Real new_om;
    output Real new_bax;
    output Real new_bay;
    output Real new_bgz;
    output Real new_Ppx;
    output Real new_Ppy;
    output Real new_Pth;
    output Real new_Pvx;
    output Real new_Pvy;
    output Real new_Pom;
    output Real new_Pbax;
    output Real new_Pbay;
    output Real new_Pbgz;
  protected
    Real pred_px, pred_py, pred_th, pred_vx, pred_vy, pred_om;
    Real pred_bax, pred_bay, pred_bgz;
    Real Ppx_p, Ppy_p, Pth_p, Pvx_p, Pvy_p, Pom_p;
    Real Pbax_p, Pbay_p, Pbgz_p;
    Real dpx, dpy;
    Real dx_l, dy_l, dist_l;
    Real h_px, h_py, s_r, k_px, k_py, innov_r;
    Real h_pxb, h_pyb, s_b, k_pxb, k_pyb, k_thb, innov_b, innov_bn;
    Real lm_x_arr[3], lm_y_arr[3], lm_r_arr[3], lm_b_arr[3];
    Real pi_val;
    Integer i;
  algorithm
    pi_val := 3.141592653589793;
    lm_x_arr[1] := lm_x1; lm_x_arr[2] := lm_x2; lm_x_arr[3] := lm_x3;
    lm_y_arr[1] := lm_y1; lm_y_arr[2] := lm_y2; lm_y_arr[3] := lm_y3;
    lm_r_arr[1] := lm_r1; lm_r_arr[2] := lm_r2; lm_r_arr[3] := lm_r3;
    lm_b_arr[1] := lm_b1; lm_b_arr[2] := lm_b2; lm_b_arr[3] := lm_b3;

    // --- Prediction ---
    pred_px := prev_px + prev_vx * dt_in;
    pred_py := prev_py + prev_vy * dt_in;
    pred_th := prev_th + prev_om * dt_in;
    pred_vx := prev_vx + (imu_ax_in - prev_bax) * dt_in;
    pred_vy := prev_vy + (imu_ay_in - prev_bay) * dt_in;
    pred_om := prev_om + (imu_gz_in - prev_bgz) * dt_in;
    pred_bax := prev_bax;
    pred_bay := prev_bay;
    pred_bgz := prev_bgz;

    // --- Covariance prediction (diagonal) ---
    Ppx_p := prev_Ppx + Qp * dt_in + prev_Pvx * dt_in * dt_in;
    Ppy_p := prev_Ppy + Qp * dt_in + prev_Pvy * dt_in * dt_in;
    Pth_p := prev_Pth + Qa * dt_in + prev_Pom * dt_in * dt_in;
    Pvx_p := prev_Pvx + Qv * dt_in;
    Pvy_p := prev_Pvy + Qv * dt_in;
    Pom_p := prev_Pom + Qo * dt_in;
    Pbax_p := prev_Pbax + Qba * dt_in;
    Pbay_p := prev_Pbay + Qba * dt_in;
    Pbgz_p := prev_Pbgz + Qbg * dt_in;

    // --- Asynchronous landmark update ---
    if do_update then
      for i in 1:3 loop
        dx_l := lm_x_arr[i] - pred_px;
        dy_l := lm_y_arr[i] - pred_py;
        dist_l := sqrt(dx_l * dx_l + dy_l * dy_l + 1.0e-10);

        // Range update
        h_px := dx_l / dist_l;
        h_py := dy_l / dist_l;
        s_r := h_px * h_px * Ppx_p + h_py * h_py * Ppy_p + Rr;
        innov_r := lm_r_arr[i] - dist_l;
        k_px := Ppx_p * h_px / s_r;
        k_py := Ppy_p * h_py / s_r;
        pred_px := pred_px + k_px * innov_r;
        pred_py := pred_py + k_py * innov_r;
        Ppx_p := Ppx_p * (1.0 - k_px * h_px);
        Ppy_p := Ppy_p * (1.0 - k_py * h_py);
        if Ppx_p < covmin then Ppx_p := covmin; end if;
        if Ppy_p < covmin then Ppy_p := covmin; end if;

        // Bearing update
        h_pxb := -dy_l / (dist_l * dist_l + 1.0e-10);
        h_pyb := dx_l / (dist_l * dist_l + 1.0e-10);
        s_b := h_pxb * h_pxb * Ppx_p + h_pyb * h_pyb * Ppy_p + Pth_p + Rb;
        innov_b := lm_b_arr[i] - (atan2(dy_l, dx_l) - pred_th);
        innov_bn := innov_b - 2.0 * pi_val * floor(innov_b / (2.0 * pi_val) + 0.5);
        k_pxb := Ppx_p * h_pxb / s_b;
        k_pyb := Ppy_p * h_pyb / s_b;
        k_thb := Pth_p * (-1.0) / s_b;
        pred_px := pred_px + k_pxb * innov_bn;
        pred_py := pred_py + k_pyb * innov_bn;
        pred_th := pred_th + k_thb * innov_bn;
        Ppx_p := Ppx_p * (1.0 - k_pxb * h_pxb);
        Ppy_p := Ppy_p * (1.0 - k_pyb * h_pyb);
        Pth_p := Pth_p * (1.0 - k_thb * (-1.0));
        if Ppx_p < covmin then Ppx_p := covmin; end if;
        if Ppy_p < covmin then Ppy_p := covmin; end if;
        if Pth_p < covmin then Pth_p := covmin; end if;
      end for;
    end if;

    // --- Bias correction from position innovation ---
    dpx := pred_px - (prev_px + prev_vx * dt_in);
    dpy := pred_py - (prev_py + prev_vy * dt_in);
    pred_bax := pred_bax + bgain * dpx;
    pred_bay := pred_bay + bgain * dpy;

    // --- Outputs ---
    new_px := pred_px;
    new_py := pred_py;
    new_th := pred_th;
    new_vx := pred_vx;
    new_vy := pred_vy;
    new_om := pred_om;
    new_bax := pred_bax;
    new_bay := pred_bay;
    new_bgz := pred_bgz;
    new_Ppx := Ppx_p;
    new_Ppy := Ppy_p;
    new_Pth := Pth_p;
    new_Pvx := Pvx_p;
    new_Pvy := Pvy_p;
    new_Pom := Pom_p;
    new_Pbax := Pbax_p;
    new_Pbay := Pbay_p;
    new_Pbgz := Pbgz_p;
  end ekf_step;

equation
  // ===== Reference trajectory (bounded circular route) =====
  px_ref = route_radius * (1.0 - cos(omega_route * time));
  py_ref = route_radius * sin(omega_route * time);
  vx_ref = route_radius * omega_route * sin(omega_route * time);
  vy_ref = route_radius * omega_route * cos(omega_route * time);
  theta_ref = pi_c / 2.0 - omega_route * time;
  omega_ref = -omega_route;

  // ===== Bias disturbance (middle third, controlled 0.048 step) =====
  b_ax_true = if (time >= t_dist_start and time < t_dist_end) then bias_step else 0.0;
  b_ay_true = if (time >= t_dist_start and time < t_dist_end) then bias_step * 0.5 else 0.0;
  b_gz_true = if (time >= t_dist_start and time < t_dist_end) then bias_step * 0.1 else 0.0;

  // ===== Controller: desired force from tracking error =====
  Fx_des = Kp_pos * (px_ref - px) + Kd_pos * (vx_ref - vx);
  Fy_des = Kp_pos * (py_ref - py) + Kd_pos * (vy_ref - vy);
  Tz_des = Kp_att * (theta_ref - theta) + Kd_att * (omega_ref - omega);

  // ===== Joint torque commands (12 effort actuators) =====
  for leg in 1:4 loop
    tau_cmd[leg,1] = Fx_des / 4.0 + Kp_joint * (q_nominal - q[leg,1]) - Kd_joint * qd[leg,1];
    tau_cmd[leg,2] = Fy_des / 4.0 + Kp_joint * (q_nominal - q[leg,2]) - Kd_joint * qd[leg,2];
    tau_cmd[leg,3] = Tz_des / 4.0 + Kp_joint * (q_nominal - q[leg,3]) - Kd_joint * qd[leg,3];
  end for;

  // ===== Torque saturation (bounded by 60.5 N.m per joint) =====
  for leg in 1:4 loop
    for j in 1:3 loop
      tau_sat[leg,j] = if tau_cmd[leg,j] > tau_max then tau_max
                       else if tau_cmd[leg,j] < -tau_max then -tau_max
                       else tau_cmd[leg,j];
    end for;
  end for;

  // ===== Net force/torque from saturated joint torques =====
  Fx_net = (tau_sat[1,1] + tau_sat[2,1] + tau_sat[3,1] + tau_sat[4,1]) * force_gain;
  Fy_net = (tau_sat[1,2] + tau_sat[2,2] + tau_sat[3,2] + tau_sat[4,2]) * force_gain;
  Tz_net = (tau_sat[1,3] + tau_sat[2,3] + tau_sat[3,3] + tau_sat[4,3]) * torque_gain;

  // ===== Torso dynamics (24 kg rigid body, planar) =====
  der(vx) = (Fx_net - b_damp * vx) / m_torso;
  der(vy) = (Fy_net - b_damp * vy) / m_torso;
  der(omega) = (Tz_net - b_damp_theta * omega) / I_torso;
  der(px) = vx;
  der(py) = vy;
  der(theta) = omega;

  // ===== Joint dynamics (12 joints, each with inertia and damping) =====
  for leg in 1:4 loop
    der(q[leg,1]) = qd[leg,1];
    der(q[leg,2]) = qd[leg,2];
    der(q[leg,3]) = qd[leg,3];
    der(qd[leg,1]) = (tau_sat[leg,1] - b_joint * qd[leg,1]) / I_joint;
    der(qd[leg,2]) = (tau_sat[leg,2] - b_joint * qd[leg,2]) / I_joint;
    der(qd[leg,3]) = (tau_sat[leg,3] - b_joint * qd[leg,3]) / I_joint;
  end for;

  // ===== Foot kinematics and contact sensors =====
  for leg in 1:4 loop
    foot_z[leg] = h_torso
                  - L1 * cos(q[leg,1])
                  - L2 * cos(q[leg,1] + q[leg,2])
                  - L3 * cos(q[leg,1] + q[leg,2] + q[leg,3]);
    foot_x[leg] = px + leg_offset_x[leg]
                  + L1 * sin(q[leg,1])
                  + L2 * sin(q[leg,1] + q[leg,2])
                  + L3 * sin(q[leg,1] + q[leg,2] + q[leg,3]);
    foot_y_world[leg] = py + leg_offset_y[leg];
    foot_contact[leg] = if foot_z[leg] < contact_thresh then 1.0 else 0.0;
    foot_force[leg] = if foot_z[leg] < contact_thresh
                     then k_contact * (contact_thresh - foot_z[leg])
                     else 0.0;
    foot_force_meas[leg] = foot_force[leg]
                           + sigma_foot_force * sin(2.0 * pi_c * (90.0 + 13.0 * leg) * time + 0.3 * leg);
  end for;

  // ===== IMU model (body frame, simplified for planar motion) =====
  ax_true = (Fx_net - b_damp * vx) / m_torso;
  ay_true = (Fy_net - b_damp * vy) / m_torso;
  imu_ax = ax_true + b_ax_true + sigma_imu_accel * sin(2.0 * pi_c * 137.0 * time + 1.0);
  imu_ay = ay_true + b_ay_true + sigma_imu_accel * sin(2.0 * pi_c * 211.0 * time + 2.0);
  imu_gz = omega + b_gz_true + sigma_imu_gyro * sin(2.0 * pi_c * 173.0 * time + 3.0);

  // ===== Joint encoder model (12 encoders) =====
  for leg in 1:4 loop
    for j in 1:3 loop
      enc_meas[leg,j] = q[leg,j] + sigma_enc * sin(2.0 * pi_c * (100.0 + 7.0 * leg + 3.0 * j) * time + 0.5 * j);
    end for;
  end for;

  // ===== Landmark measurement model (fixed external references) =====
  for i in 1:3 loop
    lm_range_meas[i] = sqrt((lm_x[i] - px)^2 + (lm_y[i] - py)^2)
                       + sigma_lm_range * sin(2.0 * pi_c * (127.0 + 17.0 * i) * time + 1.5 * i);
    lm_bearing_meas[i] = atan2(lm_y[i] - py, lm_x[i] - px) - theta
                         + sigma_lm_bearing * sin(2.0 * pi_c * (97.0 + 11.0 * i) * time + 2.5 * i);
  end for;

  // ===== Tracking and estimation errors =====
  track_err = sqrt((px - px_ref)^2 + (py - py_ref)^2 + (theta - theta_ref)^2);
  pos_est_err = sqrt((ekf_px - px)^2 + (ekf_py - py)^2);
  att_est_err = abs(ekf_theta - theta);
  bias_est_err = abs(ekf_b_ax - b_ax_true);

  // ===== EKF discrete update at 250 Hz =====
  when sample(0, dt) then
    // EKF: predict + asynchronous landmark update (every 3rd step) + bias correction
    (ekf_px, ekf_py, ekf_theta, ekf_vx, ekf_vy, ekf_omega,
     ekf_b_ax, ekf_b_ay, ekf_b_gz,
     P_px, P_py, P_theta, P_vx, P_vy, P_omega,
     P_b_ax, P_b_ay, P_b_gz) = ekf_step(
      pre(ekf_px), pre(ekf_py), pre(ekf_theta),
      pre(ekf_vx), pre(ekf_vy), pre(ekf_omega),
      pre(ekf_b_ax), pre(ekf_b_ay), pre(ekf_b_gz),
      pre(P_px), pre(P_py), pre(P_theta),
      pre(P_vx), pre(P_vy), pre(P_omega),
      pre(P_b_ax), pre(P_b_ay), pre(P_b_gz),
      imu_ax, imu_ay, imu_gz,
      lm_range_meas[1], lm_range_meas[2], lm_range_meas[3],
      lm_bearing_meas[1], lm_bearing_meas[2], lm_bearing_meas[3],
      lm_x[1], lm_x[2], lm_x[3],
      lm_y[1], lm_y[2], lm_y[3],
      dt, Q_pos, Q_vel, Q_att, Q_omega, Q_bias_a, Q_bias_g,
      R_lm_range, R_lm_bearing, bias_corr_gain, cov_min,
      mod(pre(step_cnt), 3) == 2);

    // Step counter
    step_cnt = pre(step_cnt) + 1;

    // Synchronized timestamps and traces
    tstamp_imu = time;
    tstamp_enc = time;
    tstamp_foot = time;
    if mod(pre(step_cnt), 3) == 2 then
      tstamp_lm = time;
    else
      tstamp_lm = pre(tstamp_lm);
    end if;
    trace_time = time;
    trace_px = px;
    trace_py = py;
    trace_theta = theta;
    trace_ekf_px = ekf_px;
    trace_ekf_py = ekf_py;
    trace_ekf_theta = ekf_theta;
    trace_ekf_b_ax = ekf_b_ax;
    trace_tau_cmd_11 = tau_cmd[1,1];
    trace_tau_sat_11 = tau_sat[1,1];
    trace_foot_force_1 = foot_force_meas[1];
    trace_track_err = track_err;

    // Fail-closed acceptance: once false, stays false
    // Checks: NaN/infinite, finite positive covariance, tracking error,
    //         actuator limits, bias convergence (all using pre() for discrete)
    accept = if pre(accept) and
      (px == px) and (py == py) and (theta == theta) and
      (vx == vx) and (vy == vy) and (omega == omega) and
      (pre(ekf_px) == pre(ekf_px)) and (pre(ekf_py) == pre(ekf_py)) and
      (pre(ekf_theta) == pre(ekf_theta)) and
      (abs(px) < 1.0e100) and (abs(py) < 1.0e100) and (abs(theta) < 1.0e100) and
      (abs(vx) < 1.0e100) and (abs(vy) < 1.0e100) and (abs(omega) < 1.0e100) and
      (abs(pre(ekf_px)) < 1.0e100) and (abs(pre(ekf_py)) < 1.0e100) and
      (abs(pre(ekf_theta)) < 1.0e100) and
      (pre(P_px) > cov_min) and (pre(P_py) > cov_min) and (pre(P_theta) > cov_min) and
      (pre(P_vx) > cov_min) and (pre(P_vy) > cov_min) and (pre(P_omega) > cov_min) and
      (pre(P_b_ax) > cov_min) and (pre(P_b_ay) > cov_min) and (pre(P_b_gz) > cov_min) and
      (pre(P_px) < cov_max) and (pre(P_py) < cov_max) and (pre(P_theta) < cov_max) and
      (pre(P_vx) < cov_max) and (pre(P_vy) < cov_max) and (pre(P_omega) < cov_max) and
      (pre(P_b_ax) < cov_max) and (pre(P_b_ay) < cov_max) and (pre(P_b_gz) < cov_max) and
      (time < t_accept_check or track_err <= err_band_pos) and
      (abs(tau_sat[1,1]) <= tau_max + 0.001) and
      (abs(tau_sat[1,2]) <= tau_max + 0.001) and
      (abs(tau_sat[1,3]) <= tau_max + 0.001) and
      (abs(tau_sat[2,1]) <= tau_max + 0.001) and
      (abs(tau_sat[2,2]) <= tau_max + 0.001) and
      (abs(tau_sat[2,3]) <= tau_max + 0.001) and
      (abs(tau_sat[3,1]) <= tau_max + 0.001) and
      (abs(tau_sat[3,2]) <= tau_max + 0.001) and
      (abs(tau_sat[3,3]) <= tau_max + 0.001) and
      (abs(tau_sat[4,1]) <= tau_max + 0.001) and
      (abs(tau_sat[4,2]) <= tau_max + 0.001) and
      (abs(tau_sat[4,3]) <= tau_max + 0.001) and
      (time < t_bias_conv or abs(pre(ekf_b_ax) - b_ax_true) < bias_conv_thresh)
    then true else false;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info = "Quadruped torso (24 kg) with four 3-joint legs, 12 effort actuators
      bounded at 60.5 N.m, joint encoders, foot contact/force sensors, body IMU,
      and 3 fixed landmarks. EKF estimates pose, velocity, and IMU biases with
      asynchronous landmark updates at 83 Hz within a 250 Hz prediction loop.
      Controlled 0.048 bias-step disturbance during middle third (5.33-10.67 s)
      of a 16 s run. Fail-closed acceptance: finite positive covariance,
      tracking error < 0.18 m-or-rad after 10.4 s, bias convergence,
      actuator limits, no NaN/infinite values."));
end ContactStateLocalizeE;