model MarineNavBridgeB
  parameter Real dt = 0.01 "estimator/control rate 100 Hz";
  parameter Real F_max = 86.1 "N per thruster";
  parameter Real m = 60.0 "vehicle mass kg";
  parameter Real I_z = 10.0 "yaw inertia kg m^2";
  parameter Real L_arm = 0.5 "thruster moment arm m";
  parameter Real drag_lin = 25.0 "linear drag N s/m";
  parameter Real drag_ang = 4.0 "angular drag N m s";
  parameter Real t_drop_start = 2.2 "acoustic dropout start s";
  parameter Real t_drop_end = 7.8 "acoustic dropout end s (5.6 s duration)";
  parameter Real gate_chi2 = 9.488 "innovation gating threshold chi2 2 dof";
  parameter Real Q_pos = 5e-4 "process noise pos m^2/step";
  parameter Real Q_vel = 2e-3 "process noise vel (m/s)^2/step";
  parameter Real Q_theta = 5e-4 "process noise heading rad^2/step";
  parameter Real Q_omega = 2e-3 "process noise yaw rate (rad/s)^2/step";
  parameter Real R_acoustic = 0.04 "acoustic pos meas var m^2";
  parameter Real R_doppler = 0.0025 "doppler vel meas var (m/s)^2";
  parameter Real R_pressure = 0.0025 "pressure depth var m^2";
  parameter Real R_compass = 0.0025 "compass var rad^2";

  // Vehicle continuous states
  Real x(start=1.5) "x m";
  Real y(start=0.0) "y m";
  Real z(start=0.0) "depth m";
  Real vx(start=0.0) "vx m/s";
  Real vy(start=0.9) "vy m/s";
  Real vz(start=0.0) "vz m/s";
  Real theta(start=0.0) "yaw rad";
  Real omega(start=0.6) "yaw rate rad/s";

  // Reference trajectory
  Real x_ref, y_ref, z_ref, theta_ref;
  Real vx_ref, vy_ref, vz_ref, omega_ref;

  // Control commands and saturated thruster forces
  Real Fx_cmd, Fy_cmd, Fz_cmd, Mz_cmd;
  Real T1, T2, T3, T4, T1s, T2s, T3s, T4s;
  Real Fx_act, Fy_act, Fz_act, Mz_act;

  // Sensors (continuous signals, sampled by estimator)
  Real imu_ax, imu_ay, imu_az, gyro_z;
  Real depth_meas, dvx_meas, dvy_meas, dvz_meas, compass_meas;
  Real acoust_x, acoust_y;
  Boolean acoustic_valid;

  // Estimator discrete states (multi-rate EKF with diagonal covariance)
  Real x_hat(start=1.5);
  Real y_hat(start=0.0);
  Real z_hat(start=0.0);
  Real vx_hat(start=0.0);
  Real vy_hat(start=0.9);
  Real vz_hat(start=0.0);
  Real theta_hat(start=0.0);
  Real omega_hat(start=0.6);
  Real P_x(start=0.01);
  Real P_y(start=0.01);
  Real P_z(start=0.01);
  Real P_vx(start=0.01);
  Real P_vy(start=0.01);
  Real P_vz(start=0.01);
  Real P_theta(start=0.01);
  Real P_omega(start=0.01);
  Real innov_x(start=0.0);
  Real innov_y(start=0.0);
  Real innov_chi2(start=0.0);
  Boolean gate_pass(start=false);
  Integer step_cnt(start=0);
  Real t_stamp(start=0.0) "synchronized estimator timestamp s";

  // Observables
  Real est_err_x, est_err_y, est_err_z, est_err_theta;
  Real track_err;
  Real cov_trace;
equation
  // Reference trajectory with translation and rotation so drift is observable
  x_ref = 1.5*cos(0.6*time);
  y_ref = 1.5*sin(0.6*time);
  z_ref = 0.4*sin(0.5*time);
  theta_ref = 0.6*time;
  vx_ref = -1.5*0.6*sin(0.6*time);
  vy_ref = 1.5*0.6*cos(0.6*time);
  vz_ref = 0.4*0.5*cos(0.5*time);
  omega_ref = 0.6;

  // Vehicle dynamics: world-frame 2D horizontal + heave, neutrally buoyant
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(theta) = omega;
  der(vx) = (Fx_act - drag_lin*vx)/m;
  der(vy) = (Fy_act - drag_lin*vy)/m;
  der(vz) = (Fz_act - drag_lin*vz)/m;
  der(omega) = (Mz_act - drag_ang*omega)/I_z;

  // PD control from estimator state
  Fx_cmd = m*(2.5*(x_ref - x_hat) + 3.0*(vx_ref - vx_hat));
  Fy_cmd = m*(2.5*(y_ref - y_hat) + 3.0*(vy_ref - vy_hat));
  Fz_cmd = m*(2.5*(z_ref - z_hat) + 3.0*(vz_ref - vz_hat));
  Mz_cmd = I_z*(3.5*(theta_ref - theta_hat) + 2.0*(omega_ref - omega_hat));

  // Thruster allocation and per-thruster saturation (4 thrusters, 86.1 N each)
  T1 = 0.5*Fx_cmd + 0.5*Fz_cmd;
  T2 = 0.5*Fx_cmd - 0.5*Fz_cmd;
  T3 = 0.5*Fy_cmd + 0.5*Mz_cmd/L_arm;
  T4 = 0.5*Fy_cmd - 0.5*Mz_cmd/L_arm;
  T1s = if T1 > F_max then F_max elseif T1 < -F_max then -F_max else T1;
  T2s = if T2 > F_max then F_max elseif T2 < -F_max then -F_max else T2;
  T3s = if T3 > F_max then F_max elseif T3 < -F_max then -F_max else T3;
  T4s = if T4 > F_max then F_max elseif T4 < -F_max then -F_max else T4;
  Fx_act = T1s + T2s;
  Fy_act = T3s + T4s;
  Fz_act = T1s - T2s;
  Mz_act = (T3s - T4s)*L_arm;

  // Sensor models (extrinsics treated as identity; facts not stated left unknown)
  imu_ax = (Fx_act - drag_lin*vx)/m;
  imu_ay = (Fy_act - drag_lin*vy)/m;
  imu_az = (Fz_act - drag_lin*vz)/m;
  gyro_z = omega;
  depth_meas = z;
  dvx_meas = vx;
  dvy_meas = vy;
  dvz_meas = vz;
  compass_meas = theta;
  acoust_x = x;
  acoust_y = y;
  acoustic_valid = (time < t_drop_start) or (time > t_drop_end);

  // Observable error and covariance traces
  est_err_x = x - x_hat;
  est_err_y = y - y_hat;
  est_err_z = z - z_hat;
  est_err_theta = theta - theta_hat;
  track_err = sqrt(est_err_x*est_err_x + est_err_y*est_err_y + est_err_z*est_err_z + est_err_theta*est_err_theta + 1e-12);
  cov_trace = P_x + P_y + P_z + P_vx + P_vy + P_vz + P_theta + P_omega;
algorithm
  when sample(0, dt) then
    // Synchronized timestamp (monotonic with simulation time)
    t_stamp := time;
    step_cnt := pre(step_cnt) + 1;

    // PREDICT: inertial/proprioceptive propagation via IMU (continues during dropout)
    vx_hat := pre(vx_hat) + dt*imu_ax;
    vy_hat := pre(vy_hat) + dt*imu_ay;
    vz_hat := pre(vz_hat) + dt*imu_az;
    x_hat := pre(x_hat) + dt*pre(vx_hat);
    y_hat := pre(y_hat) + dt*pre(vy_hat);
    z_hat := pre(z_hat) + dt*pre(vz_hat);
    theta_hat := pre(theta_hat) + dt*pre(omega_hat);
    omega_hat := gyro_z;

    // Covariance growth (process noise injection)
    P_x := pre(P_x) + Q_pos*dt;
    P_y := pre(P_y) + Q_pos*dt;
    P_z := pre(P_z) + Q_pos*dt;
    P_vx := pre(P_vx) + Q_vel*dt;
    P_vy := pre(P_vy) + Q_vel*dt;
    P_vz := pre(P_vz) + Q_vel*dt;
    P_theta := pre(P_theta) + Q_theta*dt;
    P_omega := pre(P_omega) + Q_omega*dt;

    // UPDATE: Doppler velocity (proprioceptive, continues during dropout)
    vx_hat := vx_hat + (P_vx/(P_vx + R_doppler))*(dvx_meas - vx_hat);
    P_vx := P_vx*R_doppler/(P_vx + R_doppler);
    vy_hat := vy_hat + (P_vy/(P_vy + R_doppler))*(dvy_meas - vy_hat);
    P_vy := P_vy*R_doppler/(P_vy + R_doppler);
    vz_hat := vz_hat + (P_vz/(P_vz + R_doppler))*(dvz_meas - vz_hat);
    P_vz := P_vz*R_doppler/(P_vz + R_doppler);

    // UPDATE: compass heading
    theta_hat := theta_hat + (P_theta/(P_theta + R_compass))*(compass_meas - theta_hat);
    P_theta := P_theta*R_compass/(P_theta + R_compass);

    // UPDATE: pressure depth
    z_hat := z_hat + (P_z/(P_z + R_pressure))*(depth_meas - z_hat);
    P_z := P_z*R_pressure/(P_z + R_pressure);

    // UPDATE: acoustic absolute position at 1 Hz with innovation gating
    // Drops out during [t_drop_start, t_drop_end]; covariance grows in that window
    if (mod(pre(step_cnt), 100) == 0) and acoustic_valid then
      innov_x := acoust_x - x_hat;
      innov_y := acoust_y - y_hat;
      innov_chi2 := (innov_x*innov_x)/(P_x + R_acoustic) + (innov_y*innov_y)/(P_y + R_acoustic);
      if innov_chi2 < gate_chi2 then
        gate_pass := true;
        x_hat := x_hat + (P_x/(P_x + R_acoustic))*innov_x;
        y_hat := y_hat + (P_y/(P_y + R_acoustic))*innov_y;
        P_x := P_x*R_acoustic/(P_x + R_acoustic);
        P_y := P_y*R_acoustic/(P_y + R_acoustic);
      else
        gate_pass := false;
      end if;
    else
      innov_x := 0.0;
      innov_y := 0.0;
      innov_chi2 := 0.0;
      gate_pass := false;
    end if;
  end when;
  annotation(experiment(StopTime=10.0, Tolerance=1e-6));
end MarineNavBridgeB;