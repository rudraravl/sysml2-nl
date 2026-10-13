model MarineNavLocalizeD
  "Instrumented underwater robotic sensing and estimation system.
   Extended Kalman filter with asynchronous updates, bounded thrusters,
   fixed acoustic landmarks, and a controlled sensor-bias step disturbance."

  // ===== Simulation parameters =====
  parameter Real dt    = 0.005  "Loop rate 200 Hz [s]";
  parameter Real T_end = 14.0   "Run duration [s]";
  parameter Real F_max = 105.0  "Thruster force limit per thruster [N]";

  // ===== Vehicle parameters =====
  parameter Real m       = 100.0 "Vehicle mass [kg]";
  parameter Real drag    = 40.0  "Linear drag [N*s/m]";
  parameter Real Iz      = 50.0  "Yaw inertia [kg*m^2]";
  parameter Real yaw_drag= 20.0  "Yaw rotational drag [N*m*s]";
  parameter Real thr_arm = 0.5   "Thruster yaw moment arm [m]";

  // ===== Fixed landmarks (external references; no ground truth to estimator) =====
  parameter Real LM[3,3] = [10.0, 0.0, -5.0;
                             0.0, 10.0, -5.0;
                            -10.0, 0.0, -5.0] "Landmark positions [m]";

  // ===== Bounded route =====
  parameter Real route_R = 4.0   "Route radius [m]";
  parameter Real route_w = 0.15  "Route angular rate [rad/s]";
  parameter Real route_z = -4.0  "Route depth [m]";

  // ===== Sensor noise standard deviations (declared, preserved) =====
  parameter Real accel_noise_std   = 0.05  "IMU accel std [m/s^2]";
  parameter Real gyro_noise_std    = 0.005 "IMU gyro std [rad/s]";
  parameter Real depth_noise_std   = 0.02  "Pressure depth std [m]";
  parameter Real doppler_noise_std = 0.03  "Doppler velocity std [m/s]";
  parameter Real compass_noise_std = 0.01  "Compass yaw std [rad]";
  parameter Real range_noise_std   = 0.10  "Acoustic range std [m]";
  // Sensor rates: IMU/pressure/Doppler/compass run at loop rate 200 Hz;
  // acoustic range runs at 1 Hz (every 200 samples). Only acoustic rate was
  // numerically specified in the requirement; remaining fast rates assumed.

  // ===== True bias base values and step disturbance =====
  parameter Real b_a_true_base      = 0.02;
  parameter Real b_g_true_base      = 0.005;
  parameter Real b_depth_true_base  = 0.01;
  parameter Real b_doppler_true_base= 0.02;
  parameter Real b_compass_true_base= 0.01;
  parameter Real step_dist          = 0.04 "Controlled bias step disturbance";

  // ===== Controller gains =====
  parameter Real Kp_cross = 0.5;
  parameter Real Kp_v     = 2.0;
  parameter Real Kp_z     = 2.0;
  parameter Real Kd_z     = 3.0;
  parameter Real Kp_yaw   = 5.0;
  parameter Real Kd_yaw   = 2.0;

  // ===== EKF noise =====
  parameter Real Q_diag[12]   = {0.001,0.001,0.001, 0.01,0.01,0.01, 0.001, 1e-4,1e-4,1e-4,1e-4,1e-4};
  parameter Real R_depth      = 0.02^2;
  parameter Real R_doppler[3] = {0.03^2,0.03^2,0.03^2};
  parameter Real R_compass    = 0.01^2;
  parameter Real R_range      = 0.10^2;
  parameter Real P0_diag[12]  = {1.0,1.0,1.0, 0.5,0.5,0.5, 0.5, 0.01,0.01,0.01,0.01,0.01};
  parameter Real x0[12]       = {4.0,0.0,-4.0, 0,0,0, 1.5707963, 0,0,0,0,0};

  // ===== Plant continuous states =====
  Real x_pos(start=4.0)    "World x [m]";
  Real y_pos(start=0.0)    "World y [m]";
  Real z_pos(start=-4.0)   "World z (depth) [m]";
  Real u_vel(start=0.0)    "Body forward velocity [m/s]";
  Real v_vel(start=0.0)    "Body lateral velocity [m/s]";
  Real w_vel(start=0.0)    "Body vertical velocity [m/s]";
  Real yaw(start=1.5707963)"Heading [rad]";
  Real yaw_rate(start=0.0) "Yaw rate [rad/s]";

  // ===== Thruster commands (bounded) =====
  Real f1, f2, f3, f4 "Saturated thruster forces [N]";
  Real Fx_body, Fz_body, Mz_body;
  Real Fx_cmd, Fz_cmd, Mz_cmd;
  Real Fx_cmd_sat, Fz_cmd_sat, Mz_cmd_sat;

  // ===== True bias with step disturbance (middle third of run) =====
  Real b_a_true, b_g_true, b_depth_true, b_doppler_true, b_compass_true;
  Boolean in_disturb;

  // ===== Plant true body acceleration =====
  Real a_true[3];

  // ===== Measurements =====
  Real accel_meas[3]  "IMU body-frame accel [m/s^2]";
  Real gyro_meas      "IMU yaw rate [rad/s]";
  Real depth_meas     "Pressure depth [m]";
  Real doppler_meas[3]"Doppler body velocity [m/s]";
  Real compass_meas   "Compass yaw [rad]";
  Real range_meas[3]  "Acoustic range to landmarks [m]";

  // ===== EKF discrete state =====
  discrete Real x_est[12];
  discrete Real P[12,12];

  // EKF intermediates (single-assignment stages)
  discrete Real x_p[12],  P_p[12,12];
  discrete Real x1[12],   P1[12,12];
  discrete Real x2[12],   P2[12,12];
  discrete Real x3[12],   P3[12,12];
  discrete Real x4[12],   P4[12,12];
  discrete Real x5[12],   P5[12,12];
  discrete Real x6[12],   P6[12,12];
  discrete Real x7[12],   P7[12,12];

  discrete Real H_depth[12], H_compass[12], H_du[12], H_dv[12], H_dw[12];
  discrete Real H_r1[12], H_r2[12], H_r3[12];
  discrete Real dx1,dy1,dz1,r1, dx2,dy2,dz2,r2, dx3,dy3,dz3,r3;

  discrete Boolean acousticUpdate;
  discrete Boolean firstSample(start=true);
  discrete Integer sampleCounter(start=0);

  // ===== Controller references =====
  Real x_ref, y_ref, z_ref, vx_ref, vy_ref, yaw_ref, speed_ref;

  // ===== Monitoring =====
  Real pos_err     "Position tracking error [m]";
  Real yaw_err     "Yaw tracking error [rad]";
  Real track_err   "Primary tracking error (max of pos and yaw) [m or rad]";
  Real pos_3sigma  "3-sigma position error band [m]";
  Real yaw_3sigma  "3-sigma yaw error band [rad]";
  Real b_a_err, b_g_err, b_depth_err, b_doppler_err, b_compass_err;

equation
  // ===== Reference route (bounded circular path) =====
  x_ref    = route_R*cos(route_w*time);
  y_ref    = route_R*sin(route_w*time);
  z_ref    = route_z;
  vx_ref   = -route_R*route_w*sin(route_w*time);
  vy_ref   =  route_R*route_w*cos(route_w*time);
  yaw_ref  =  atan2(vy_ref, vx_ref);
  speed_ref=  route_R*route_w;

  // ===== Step disturbance during middle third =====
  in_disturb      = (time >= T_end/3.0) and (time <= 2.0*T_end/3.0);
  b_a_true        = b_a_true_base       + (if in_disturb then step_dist else 0.0);
  b_g_true        = b_g_true_base       + (if in_disturb then step_dist else 0.0);
  b_depth_true    = b_depth_true_base   + (if in_disturb then step_dist else 0.0);
  b_doppler_true  = b_doppler_true_base + (if in_disturb then step_dist else 0.0);
  b_compass_true  = b_compass_true_base + (if in_disturb then step_dist else 0.0);

  // ===== Plant dynamics =====
  Fx_body = f1 + f2;
  Fz_body = f3 + f4;
  Mz_body = (f2 - f1) * thr_arm;

  a_true[1] = (Fx_body - drag*u_vel)/m;
  a_true[2] = (0.0    - drag*v_vel)/m;
  a_true[3] = (Fz_body - drag*w_vel)/m;

  der(x_pos) = cos(yaw)*u_vel - sin(yaw)*v_vel;
  der(y_pos) = sin(yaw)*u_vel + cos(yaw)*v_vel;
  der(z_pos) = w_vel;
  der(u_vel) = a_true[1];
  der(v_vel) = a_true[2];
  der(w_vel) = a_true[3];
  der(yaw)     = yaw_rate;
  der(yaw_rate)= (Mz_body - yaw_drag*yaw_rate)/Iz;

  // ===== Sensor models (with bias + deterministic bounded noise) =====
  accel_meas[1]  = a_true[1] + b_a_true + accel_noise_std*sin(13.7*time + 1.1);
  accel_meas[2]  = a_true[2] + b_a_true + accel_noise_std*sin(17.3*time + 2.3);
  accel_meas[3]  = a_true[3] + b_a_true + accel_noise_std*sin(11.9*time + 3.7);
  gyro_meas      = yaw_rate  + b_g_true + gyro_noise_std*sin(23.1*time + 0.5);
  depth_meas     = z_pos     + b_depth_true + depth_noise_std*sin(29.7*time + 1.9);
  doppler_meas[1]= u_vel     + b_doppler_true + doppler_noise_std*sin(31.3*time + 0.7);
  doppler_meas[2]= v_vel     + b_doppler_true + doppler_noise_std*sin(37.9*time + 2.1);
  doppler_meas[3]= w_vel     + b_doppler_true + doppler_noise_std*sin(41.1*time + 3.3);
  compass_meas   = yaw      + b_compass_true + compass_noise_std*sin(43.7*time + 1.4);
  range_meas[1]  = sqrt(max((x_pos-LM[1,1])^2 + (y_pos-LM[1,2])^2 + (z_pos-LM[1,3])^2, 1e-6)) + range_noise_std*sin(7.1*time+0.3);
  range_meas[2]  = sqrt(max((x_pos-LM[2,1])^2 + (y_pos-LM[2,2])^2 + (z_pos-LM[2,3])^2, 1e-6)) + range_noise_std*sin(9.3*time+2.8);
  range_meas[3]  = sqrt(max((x_pos-LM[3,1])^2 + (y_pos-LM[3,2])^2 + (z_pos-LM[3,3])^2, 1e-6)) + range_noise_std*sin(5.9*time+4.2);

  // ===== Controller (uses estimated state; follows bounded route) =====
  Fx_cmd = m*(Kp_v*((cos(x_est[7])*vx_ref + sin(x_est[7])*vy_ref + Kp_cross*(x_ref - x_est[1])*cos(x_est[7]) + Kp_cross*(y_ref - x_est[2])*sin(x_est[7])) - x_est[4])) + drag*x_est[4];
  Fz_cmd = m*(Kp_z*(z_ref - x_est[3]) - Kd_z*x_est[6]) + drag*x_est[6];
  Mz_cmd = Kp_yaw*atan2(sin(yaw_ref - x_est[7]), cos(yaw_ref - x_est[7])) + Kd_yaw*(0.0 - (gyro_meas - x_est[9]));

  // Saturate commands to achievable actuator limits
  Fx_cmd_sat = max(-2.0*F_max, min(2.0*F_max, Fx_cmd));
  Fz_cmd_sat = max(-2.0*F_max, min(2.0*F_max, Fz_cmd));
  Mz_cmd_sat = max(-F_max, min(F_max, Mz_cmd));

  // Allocation to four bounded thrusters
  f1 = max(-F_max, min(F_max, (Fx_cmd_sat - 2.0*Mz_cmd_sat/thr_arm)/2.0));
  f2 = max(-F_max, min(F_max, (Fx_cmd_sat + 2.0*Mz_cmd_sat/thr_arm)/2.0));
  f3 = max(-F_max, min(F_max,  Fz_cmd_sat/2.0));
  f4 = max(-F_max, min(F_max,  Fz_cmd_sat/2.0));

  // ===== Monitoring =====
  pos_err    = sqrt((x_ref - x_pos)^2 + (y_ref - y_pos)^2 + (z_ref - z_pos)^2);
  yaw_err    = atan2(sin(yaw - yaw_ref), cos(yaw - yaw_ref));
  track_err  = max(pos_err, abs(yaw_err));
  pos_3sigma = 3.0*sqrt(max(P[1,1] + P[2,2] + P[3,3], 1e-12));
  yaw_3sigma = 3.0*sqrt(max(P[7,7], 1e-12));
  b_a_err       = b_a_true       - x_est[8];
  b_g_err       = b_g_true       - x_est[9];
  b_depth_err   = b_depth_true   - x_est[10];
  b_doppler_err = b_doppler_true - x_est[11];
  b_compass_err = b_compass_true - x_est[12];

  // ===== EKF: asynchronous updates at 200 Hz; acoustic at 1 Hz =====
  when sample(0, dt) then
    sampleCounter := pre(sampleCounter) + 1;
    acousticUpdate := mod(pre(sampleCounter) + 1, 200) == 0;

    if pre(firstSample) then
      // Initialize estimator state and covariance
      for i in 1:12 loop
        x_est[i] := x0[i];
        for j in 1:12 loop
          P[i,j] := if i==j then P0_diag[i] else 0.0;
        end for;
      end for;
      firstSample := false;
    else
      // --- Prediction (IMU) ---
      (x_p, P_p) := ekfPredict(pre(x_est), pre(P), accel_meas, gyro_meas, dt, drag, m, Q_diag);

      // --- Depth update (pressure) ---
      H_depth := {0,0,1,0,0,0,0,0,0,1,0,0};
      (x1, P1) := kfScalarUpdate(x_p, P_p, H_depth, depth_meas, R_depth);

      // --- Compass update ---
      H_compass := {0,0,0,0,0,0,1,0,0,0,0,1};
      (x2, P2) := kfScalarUpdate(x1, P1, H_compass, compass_meas, R_compass);

      // --- Doppler velocity updates (3 sequential scalar updates) ---
      H_du := {0,0,0,1,0,0,0,0,0,0,1,0};
      (x3, P3) := kfScalarUpdate(x2, P2, H_du, doppler_meas[1], R_doppler[1]);
      H_dv := {0,0,0,0,1,0,0,0,0,0,1,0};
      (x4, P4) := kfScalarUpdate(x3, P3, H_dv, doppler_meas[2], R_doppler[2]);
      H_dw := {0,0,0,0,0,1,0,0,0,0,1,0};
      (x5, P5) := kfScalarUpdate(x4, P4, H_dw, doppler_meas[3], R_doppler[3]);

      // --- Acoustic range updates (1 Hz, all three landmarks) ---
      if acousticUpdate then
        dx1 := x5[1] - LM[1,1]; dy1 := x5[2] - LM[1,2]; dz1 := x5[3] - LM[1,3];
        r1  := sqrt(max(dx1*dx1 + dy1*dy1 + dz1*dz1, 1e-6));
        H_r1 := {dx1/r1, dy1/r1, dz1/r1, 0,0,0,0,0,0,0,0,0};
        dx2 := x5[1] - LM[2,1]; dy2 := x5[2] - LM[2,2]; dz2 := x5[3] - LM[2,3];
        r2  := sqrt(max(dx2*dx2 + dy2*dy2 + dz2*dz2, 1e-6));
        H_r2 := {dx2/r2, dy2/r2, dz2/r2, 0,0,0,0,0,0,0,0,0};
        dx3 := x5[1] - LM[3,1]; dy3 := x5[2] - LM[3,2]; dz3 := x5[3] - LM[3,3];
        r3  := sqrt(max(dx3*dx3 + dy3*dy3 + dz3*dz3, 1e-6));
        H_r3 := {dx3/r3, dy3/r3, dz3/r3, 0,0,0,0,0,0,0,0,0};
      else
        H_r1 := fill(0.0,12);
        H_r2 := fill(0.0,12);
        H_r3 := fill(0.0,12);
      end if;

      (x6, P6) := kfScalarUpdate(x5, P5, H_r1, range_meas[1], R_range);
      (x7, P7) := kfScalarUpdate(x6, P6, H_r2, range_meas[2], R_range);
      (x_est, P) := kfScalarUpdate(x7, P7, H_r3, range_meas[3], R_range);
      firstSample := false;
    end if;
  end when;

  // ===== Requirements checks =====
  assert(P[1,1] > 0.0,  "Covariance not positive (P[1,1])");
  assert(P[7,7] > 0.0,  "Covariance not positive (P[7,7])");
  assert(abs(x_pos) < 1e6 and abs(y_pos) < 1e6 and abs(z_pos) < 1e6, "Plant state diverged");
  assert(abs(u_vel) < 1e6 and abs(v_vel) < 1e6 and abs(w_vel) < 1e6, "Velocity diverged");
  assert(abs(yaw) < 1e6, "Attitude diverged");

  when time > 9.1 then
    assert(pos_err < 0.2, "Primary tracking error exceeds 0.2 m after 9.1 s");
  end when;

  annotation (
    experiment(StopTime = 14.0, Tolerance = 1e-4, Interval = 0.005),
    Documentation(info = "MarineNavLocalizeD: underwater vehicle EKF localization
      with IMU/pressure/Doppler/compass/acoustic-range sensors, four bounded
      105 N thrusters, fixed landmarks, 0.04 bias step disturbance in the middle
      third, 200 Hz loop, 14 s run. Asynchronous acoustic updates at 1 Hz.
      Estimates pose, velocity, and sensor biases."));
end MarineNavLocalizeD;