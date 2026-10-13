model MapRigLocalizeA
  "Robotic sensing and estimation: differential-drive base, multi-rate sensors,
   diagonal-covariance EKF with asynchronous updates, bounded wheel torques."

  // ---- Physical constants (specified) ----
  parameter Real mass = 22.0 "kg mobile base";
  parameter Real tau_max = 8.64 "N.m command magnitude limit per wheel";
  parameter Real max_lidar_range = 20.0 "m planar lidar limit";

  // ---- Assumed mechanical parameters (not specified in request) ----
  parameter Real I_base = 1.0 "kg.m^2, assumed planar yaw inertia";
  parameter Real r_wheel = 0.1 "m, assumed wheel radius";
  parameter Real wheelbase = 0.4 "m, assumed axle distance";

  // ---- Timing and scenario ----
  parameter Real dt = 0.0125 "s, 80 Hz master clock";
  parameter Real t_step_start = 8.0/3.0 "s, middle third start";
  parameter Real t_step_end = 16.0/3.0 "s, middle third end";
  parameter Real b_step = 0.02 "sensor-bias step disturbance magnitude";

  // ---- Sensor rates, frames, standard deviations (preserved) ----
  parameter Real f_imu = 80.0 "Hz";
  parameter Real f_enc = 40.0 "Hz";
  parameter Real f_rgb = 20.0 "Hz";
  parameter Real f_lidar = 10.0 "Hz";
  parameter String frame_world = "world";
  parameter String frame_base = "base";
  parameter String frame_lidar = "lidar";
  parameter String frame_rgb = "rgb";
  parameter Real lidar_x = 0.15 "m, assumed forward lidar offset";
  parameter Real lidar_theta = 0.0 "rad";
  parameter Real rgb_x = 0.20 "m, assumed forward RGB-D offset";
  parameter Real rgb_theta = 0.0 "rad";
  parameter Real std_imu_gyro = 0.01 "rad/s";
  parameter Real std_enc = 0.05 "m/s";
  parameter Real std_lidar_range = 0.05 "m";
  parameter Real std_lidar_bearing = 0.02 "rad";
  parameter Real std_rgb_range = 0.05 "m";
  parameter Real std_rgb_bearing = 0.03 "rad";

  // ---- EKF dimensions and tuning ----
  constant Integer n = 8;
  constant Integer nLand = 3;
  parameter Real Q_pos = 0.001;
  parameter Real Q_theta = 0.001;
  parameter Real Q_v = 0.01;
  parameter Real Q_omega = 0.01;
  parameter Real Q_b_gyro = 1e-6;
  parameter Real Q_b_enc = 1e-6;
  parameter Real Pmin = 1e-6 "finite positive covariance floor";

  // ---- Reference route (assumed sinusoidal lateral offset) ----
  parameter Real ref_speed = 0.5 "m/s forward speed";
  parameter Real ref_amp = 0.2 "m lateral amplitude";
  parameter Real ref_omega = 0.5 "rad/s route frequency";

  // ---- Controller gains (assumed) ----
  parameter Real Kp_pos = 1.5;
  parameter Real Kp_lat = 2.0;
  parameter Real Kp_th = 3.0;
  parameter Real Kp_v = 10.0;
  parameter Real Kp_o = 10.0;

  // ---- Landmarks (fixed external references, no ground truth to estimator) ----
  parameter Real LandX[nLand] = {5.0, 5.0, 0.0};
  parameter Real LandY[nLand] = {0.0, 5.0, 5.0};

  // ---- Plant continuous states ----
  output Real x(start=0.0, fixed=true) "m";
  output Real y(start=0.0, fixed=true) "m";
  output Real theta(start=atan2(ref_amp*ref_omega, ref_speed), fixed=true) "rad";
  output Real v(start=sqrt(ref_speed^2 + (ref_amp*ref_omega)^2), fixed=true) "m/s";
  output Real omega(start=0.0, fixed=true) "rad/s";
  output Real tau_L "N.m left wheel command";
  output Real tau_R "N.m right wheel command";

  // ---- True sensor bias (step disturbance) ----
  Real b_gyro_true = if time >= t_step_start and time <= t_step_end then b_step else 0.0;

  // ---- Reference and errors ----
  Real x_ref = ref_speed*time;
  Real y_ref = ref_amp*sin(ref_omega*time);
  Real x_ref_dot = ref_speed;
  Real y_ref_dot = ref_amp*ref_omega*cos(ref_omega*time);
  Real v_ref = sqrt(x_ref_dot^2 + y_ref_dot^2);
  Real theta_ref = atan2(y_ref_dot, x_ref_dot);
  Real x_ref_ddot = 0.0;
  Real y_ref_ddot = -ref_amp*ref_omega^2*sin(ref_omega*time);
  Real omega_ref = (x_ref_dot*y_ref_ddot - y_ref_dot*x_ref_ddot)/max(v_ref^2, 1e-6);
  Real e_x = x_ref - x;
  Real e_y = y_ref - y;
  Real e_theta_raw = theta_ref - theta;
  Real e_theta = atan2(sin(e_theta_raw), cos(e_theta_raw));

  // ---- Controller ----
  Real v_des = v_ref + Kp_pos*(e_x*cos(theta) + e_y*sin(theta));
  Real omega_des = omega_ref + Kp_th*e_theta + Kp_lat*(-e_x*sin(theta) + e_y*cos(theta));
  Real a_cmd = Kp_v*(v_des - v);
  Real alpha_cmd = Kp_o*(omega_des - omega);
  Real F_cmd = mass*a_cmd;
  Real M_cmd = I_base*alpha_cmd;
  Real tau_L_raw = r_wheel*(F_cmd/2 - M_cmd/wheelbase);
  Real tau_R_raw = r_wheel*(F_cmd/2 + M_cmd/wheelbase);

  // ---- Actuator saturation ----
equation
  tau_L = max(-tau_max, min(tau_max, tau_L_raw));
  tau_R = max(-tau_max, min(tau_max, tau_R_raw));

  // ---- Plant dynamics ----
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(v) = (tau_L + tau_R)/r_wheel/mass;
  der(omega) = (tau_R - tau_L)*wheelbase/(2*r_wheel)/I_base;

  // ---- EKF discrete state (diagonal covariance) ----
  discrete Real xEst[n];
  discrete Real P[n];
  discrete Integer tick(start=0);

  // ---- EKF temporaries ----
  Real H[n];
  Real S;
  Real K[n];
  Real y_innov;
  Real h_meas;
  Real range_est;
  Real bearing_est;
  Real dx_est;
  Real dy_est;
  Real sx_est;
  Real sy_est;
  Real head_est;
  Real range_meas;
  Real bearing_meas;
  Real wL_true;
  Real wR_true;

  // ---- Sensor traces ----
  discrete Real t_imu(start=0.0);
  discrete Real t_enc(start=0.0);
  discrete Real t_rgb(start=0.0);
  discrete Real t_lidar(start=0.0);
  discrete Real z_imu(start=0.0);
  discrete Real z_encL(start=0.0);
  discrete Real z_encR(start=0.0);
  discrete Real z_lidar_range(start=0.0);
  discrete Real z_lidar_bearing(start=0.0);
  discrete Real z_rgb_range(start=0.0);
  discrete Real z_rgb_bearing(start=0.0);

  // ---- Estimator outputs ----
  output Real x_est = xEst[1];
  output Real y_est = xEst[2];
  output Real theta_est = xEst[3];
  output Real v_est = xEst[4];
  output Real omega_est = xEst[5];
  output Real b_gyro_est = xEst[6];
  output Real b_encL_est = xEst[7];
  output Real b_encR_est = xEst[8];
  output Real pos_err_band = 3.0*sqrt(max(P[1],Pmin) + max(P[2],Pmin));
  output Real att_err_band = 3.0*sqrt(max(P[3],Pmin));
  output Real tracking_error = max(sqrt((x-x_ref)^2 + (y-y_ref)^2), abs(e_theta));

initial equation
  xEst = {x.start, y.start, theta.start, v.start, 0.0, 0.0, 0.0, 0.0};
  P = {0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1};

algorithm
  when sample(dt, dt) then
    tick := tick + 1;
    H := zeros(n);
    K := zeros(n);

    // ---- Prediction (diagonal covariance) ----
    P[1] := P[1] + (cos(xEst[3])*dt)^2 * P[4] + (xEst[4]*sin(xEst[3])*dt)^2 * P[3] + Q_pos*dt;
    P[2] := P[2] + (sin(xEst[3])*dt)^2 * P[4] + (xEst[4]*cos(xEst[3])*dt)^2 * P[3] + Q_pos*dt;
    P[3] := P[3] + (dt)^2 * P[5] + Q_theta*dt;
    P[4] := P[4] + Q_v*dt;
    P[5] := P[5] + Q_omega*dt;
    P[6] := P[6] + Q_b_gyro*dt;
    P[7] := P[7] + Q_b_enc*dt;
    P[8] := P[8] + Q_b_enc*dt;
    xEst[1] := xEst[1] + xEst[4]*cos(xEst[3])*dt;
    xEst[2] := xEst[2] + xEst[4]*sin(xEst[3])*dt;
    xEst[3] := xEst[3] + xEst[5]*dt;

    // ---- IMU update (80 Hz) ----
    t_imu := time;
    z_imu := omega + b_gyro_true;
    h_meas := xEst[5] + xEst[6];
    y_innov := z_imu - h_meas;
    S := max(P[5] + P[6] + std_imu_gyro^2, 1e-9);
    K[5] := P[5]/S;
    K[6] := P[6]/S;
    xEst[5] := xEst[5] + K[5]*y_innov;
    xEst[6] := xEst[6] + K[6]*y_innov;
    P[5] := max(Pmin, P[5]*(1 - K[5]));
    P[6] := max(Pmin, P[6]*(1 - K[6]));

    // ---- Wheel encoder update (40 Hz) ----
    if mod(tick,2) == 0 then
      t_enc := time;
      wL_true := (v - omega*wheelbase/2)/r_wheel;
      wR_true := (v + omega*wheelbase/2)/r_wheel;
      z_encL := wL_true;
      z_encR := wR_true;
      // left wheel
      h_meas := (xEst[4] - xEst[5]*wheelbase/2)/r_wheel + xEst[7];
      y_innov := z_encL - h_meas;
      H[4] := 1/r_wheel;
      H[5] := -wheelbase/(2*r_wheel);
      H[7] := 1.0;
      S := max(H[4]^2*P[4] + H[5]^2*P[5] + H[7]^2*P[7] + std_enc^2, 1e-9);
      K[4] := P[4]*H[4]/S;
      K[5] := P[5]*H[5]/S;
      K[7] := P[7]*H[7]/S;
      xEst[4] := xEst[4] + K[4]*y_innov;
      xEst[5] := xEst[5] + K[5]*y_innov;
      xEst[7] := xEst[7] + K[7]*y_innov;
      P[4] := max(Pmin, P[4]*(1 - K[4]*H[4]));
      P[5] := max(Pmin, P[5]*(1 - K[5]*H[5]));
      P[7] := max(Pmin, P[7]*(1 - K[7]*H[7]));
      // right wheel
      h_meas := (xEst[4] + xEst[5]*wheelbase/2)/r_wheel + xEst[8];
      y_innov := z_encR - h_meas;
      H[4] := 1/r_wheel;
      H[5] := wheelbase/(2*r_wheel);
      H[8] := 1.0;
      S := max(H[4]^2*P[4] + H[5]^2*P[5] + H[8]^2*P[8] + std_enc^2, 1e-9);
      K[4] := P[4]*H[4]/S;
      K[5] := P[5]*H[5]/S;
      K[8] := P[8]*H[8]/S;
      xEst[4] := xEst[4] + K[4]*y_innov;
      xEst[5] := xEst[5] + K[5]*y_innov;
      xEst[8] := xEst[8] + K[8]*y_innov;
      P[4] := max(Pmin, P[4]*(1 - K[4]*H[4]));
      P[5] := max(Pmin, P[5]*(1 - K[5]*H[5]));
      P[8] := max(Pmin, P[8]*(1 - K[8]*H[8]));
    end if;

    // ---- RGB-D update (20 Hz) ----
    if mod(tick,4) == 0 then
      t_rgb := time;
      for j in 1:nLand loop
        sx_est := x + rgb_x*cos(theta);
        sy_est := y + rgb_x*sin(theta);
        head_est := theta + rgb_theta;
        dx_est := LandX[j] - sx_est;
        dy_est := LandY[j] - sy_est;
        range_meas := sqrt(dx_est*dx_est + dy_est*dy_est);
        bearing_meas := atan2(dy_est, dx_est) - head_est;
        if range_meas <= max_lidar_range and range_meas > 1e-3 then
          z_rgb_range := range_meas;
          z_rgb_bearing := bearing_meas;
          sx_est := xEst[1] + rgb_x*cos(xEst[3]);
          sy_est := xEst[2] + rgb_x*sin(xEst[3]);
          head_est := xEst[3] + rgb_theta;
          dx_est := LandX[j] - sx_est;
          dy_est := LandY[j] - sy_est;
          range_est := sqrt(dx_est*dx_est + dy_est*dy_est);
          bearing_est := atan2(dy_est, dx_est) - head_est;
          range_est := max(range_est, 1e-3);
          // range update
          y_innov := range_meas - range_est;
          H := zeros(n);
          H[1] := -dx_est/range_est;
          H[2] := -dy_est/range_est;
          H[3] := (dx_est*rgb_x*sin(xEst[3]) - dy_est*rgb_x*cos(xEst[3]))/range_est;
          S := max(H[1]^2*P[1] + H[2]^2*P[2] + H[3]^2*P[3] + std_rgb_range^2, 1e-9);
          K[1] := P[1]*H[1]/S;
          K[2] := P[2]*H[2]/S;
          K[3] := P[3]*H[3]/S;
          xEst[1] := xEst[1] + K[1]*y_innov;
          xEst[2] := xEst[2] + K[2]*y_innov;
          xEst[3] := xEst[3] + K[3]*y_innov;
          P[1] := max(Pmin, P[1]*(1 - K[1]*H[1]));
          P[2] := max(Pmin, P[2]*(1 - K[2]*H[2]));
          P[3] := max(Pmin, P[3]*(1 - K[3]*H[3]));
          // bearing update
          y_innov := bearing_meas - bearing_est;
          y_innov := atan2(sin(y_innov), cos(y_innov));
          H := zeros(n);
          H[1] := -dy_est/(range_est^2);
          H[2] := dx_est/(range_est^2);
          H[3] := (-dx_est*rgb_x*cos(xEst[3]) - dy_est*rgb_x*sin(xEst[3]))/(range_est^2) - 1.0;
          S := max(H[1]^2*P[1] + H[2]^2*P[2] + H[3]^2*P[3] + std_rgb_bearing^2, 1e-9);
          K[1] := P[1]*H[1]/S;
          K[2] := P[2]*H[2]/S;
          K[3] := P[3]*H[3]/S;
          xEst[1] := xEst[1] + K[1]*y_innov;
          xEst[2] := xEst[2] + K[2]*y_innov;
          xEst[3] := xEst[3] + K[3]*y_innov;
          P[1] := max(Pmin, P[1]*(1 - K[1]*H[1]));
          P[2] := max(Pmin, P[2]*(1 - K[2]*H[2]));
          P[3] := max(Pmin, P[3]*(1 - K[3]*H[3]));
        end if;
      end for;
    end if;

    // ---- Lidar update (10 Hz) ----
    if mod(tick,8) == 0 then
      t_lidar := time;
      for j in 1:nLand loop
        sx_est := x + lidar_x*cos(theta);
        sy_est := y + lidar_x*sin(theta);
        head_est := theta + lidar_theta;
        dx_est := LandX[j] - sx_est;
        dy_est := LandY[j] - sy_est;
        range_meas := sqrt(dx_est*dx_est + dy_est*dy_est);
        bearing_meas := atan2(dy_est, dx_est) - head_est;
        if range_meas <= max_lidar_range and range_meas > 1e-3 then
          z_lidar_range := range_meas;
          z_lidar_bearing := bearing_meas;
          sx_est := xEst[1] + lidar_x*cos(xEst[3]);
          sy_est := xEst[2] + lidar_x*sin(xEst[3]);
          head_est := xEst[3] + lidar_theta;
          dx_est := LandX[j] - sx_est;
          dy_est := LandY[j] - sy_est;
          range_est := sqrt(dx_est*dx_est + dy_est*dy_est);
          bearing_est := atan2(dy_est, dx_est) - head_est;
          range_est := max(range_est, 1e-3);
          // range update
          y_innov := range_meas - range_est;
          H := zeros(n);
          H[1] := -dx_est/range_est;
          H[2] := -dy_est/range_est;
          H[3] := (dx_est*lidar_x*sin(xEst[3]) - dy_est*lidar_x*cos(xEst[3]))/range_est;
          S := max(H[1]^2*P[1] + H[2]^2*P[2] + H[3]^2*P[3] + std_lidar_range^2, 1e-9);
          K[1] := P[1]*H[1]/S;
          K[2] := P[2]*H[2]/S;
          K[3] := P[3]*H[3]/S;
          xEst[1] := xEst[1] + K[1]*y_innov;
          xEst[2] := xEst[2] + K[2]*y_innov;
          xEst[3] := xEst[3] + K[3]*y_innov;
          P[1] := max(Pmin, P[1]*(1 - K[1]*H[1]));
          P[2] := max(Pmin, P[2]*(1 - K[2]*H[2]));
          P[3] := max(Pmin, P[3]*(1 - K[3]*H[3]));
          // bearing update
          y_innov := bearing_meas - bearing_est;
          y_innov := atan2(sin(y_innov), cos(y_innov));
          H := zeros(n);
          H[1] := -dy_est/(range_est^2);
          H[2] := dx_est/(range_est^2);
          H[3] := (-dx_est*lidar_x*cos(xEst[3]) - dy_est*lidar_x*sin(xEst[3]))/(range_est^2) - 1.0;
          S := max(H[1]^2*P[1] + H[2]^2*P[2] + H[3]^2*P[3] + std_lidar_bearing^2, 1e-9);
          K[1] := P[1]*H[1]/S;
          K[2] := P[2]*H[2]/S;
          K[3] := P[3]*H[3]/S;
          xEst[1] := xEst[1] + K[1]*y_innov;
          xEst[2] := xEst[2] + K[2]*y_innov;
          xEst[3] := xEst[3] + K[3]*y_innov;
          P[1] := max(Pmin, P[1]*(1 - K[1]*H[1]));
          P[2] := max(Pmin, P[2]*(1 - K[2]*H[2]));
          P[3] := max(Pmin, P[3]*(1 - K[3]*H[3]));
        end if;
      end for;
    end if;
  end when;

  annotation (
    Documentation(info="MapRigLocalizeA: 22 kg mobile base with 20 m lidar, RGB-D, encoders, IMU.
      Rates: IMU 80 Hz, encoders 40 Hz, RGB-D 20 Hz, lidar 10 Hz.
      Diagonal-covariance EKF with asynchronous sequential updates.
      Wheel torque limited to 8.64 N.m per wheel.
      0.02 rad/s gyro-bias step applied during middle third (2.667-5.333 s).
      Unspecified mechanical parameters (I_base, r_wheel, wheelbase, sensor offsets, route shape,
      controller gains) are assumed for simulation and are commented; only request facts are authoritative."),
    experiment(StopTime=8.0, Tolerance=1e-6)
  );
end MapRigLocalizeA;