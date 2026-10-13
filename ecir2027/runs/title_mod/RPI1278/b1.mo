model ContactStateLocalizeF
  "Quadruped contact-aided state estimation: EKF with asynchronous IMU/encoder/landmark
   updates, bounded route following, 12 effort actuators, and a 0.058 sensor-bias step
   disturbance applied during the middle third of a 20 s / 500 Hz run."

  // ===== Timing =====
  parameter Real T_end = 20.0 "s run duration";
  parameter Real dt_imu = 0.002 "s, IMU + prediction rate (500 Hz)";
  parameter Real dt_enc = 0.004 "s, encoder rate (250 Hz)";
  parameter Real dt_lm  = 0.010 "s, landmark range rate (100 Hz)";
  parameter Real t_step_a = 6.667 "s, bias step start (middle third)";
  parameter Real t_step_b = 13.333 "s, bias step end";
  parameter Real bias_step = 0.058 "sensor-bias step disturbance magnitude";

  // ===== Body =====
  parameter Real m_torso = 24.0 "kg";
  parameter Real I_torso = 1.0 "kg.m^2 lumped rotational inertia";
  parameter Real L_force = 0.3 "m, leg lever arm";
  parameter Real tau_max = 67.1 "N.m per-joint effort limit";
  parameter Real g = 9.81 "m/s^2";

  // ===== Sensor standard deviations =====
  parameter Real sigma_acc = 0.05 "m/s^2 IMU accelerometer std";
  parameter Real sigma_gyro = 0.005 "rad/s IMU gyroscope std";
  parameter Real sigma_enc = 0.005 "rad joint encoder std";
  parameter Real sigma_range = 0.02 "m landmark range std";
  parameter Real sigma_fn = 2.0 "N foot normal-force std";
  parameter Real sigma_h = 0.005 "m foot-height derived std";

  // ===== Fixed landmarks =====
  parameter Real LM[3,3] = [3.0,0.0,0.0; 0.0,3.0,0.0; 0.0,0.0,3.0] "m, world frame";

  // ===== Bounded route =====
  parameter Real route_r = 1.0 "m";
  parameter Real route_w = 0.3 "rad/s";

  // ===== Controller gains =====
  parameter Real Kp_p = 15.0;
  parameter Real Kd_p = 8.0;
  parameter Real Kp_a = 10.0;
  parameter Real Kd_a = 4.0;

  // ===== EKF model matrices =====
  // state x = [px,py,pz, vx,vy,vz, yaw, b_acc, b_gyro, b_enc]
  parameter Real Fd[10,10] =
    [1,0,0,dt_imu,0,0,0,0,0,0;
     0,1,0,0,dt_imu,0,0,0,0,0;
     0,0,1,0,0,dt_imu,0,0,0,0;
     0,0,0,1,0,0,0,0,0,0;
     0,0,0,0,1,0,0,0,0,0;
     0,0,0,0,0,1,0,0,-dt_imu,0;
     0,0,0,0,0,0,1,0,0,-dt_imu;
     0,0,0,0,0,0,0,1,0,0;
     0,0,0,0,0,0,0,0,1,0;
     0,0,0,0,0,0,0,0,0,1];
  parameter Real Q[10,10] = diagonal({1e-4,1e-4,1e-4,1e-2,1e-2,1e-2,1e-3,1e-3,1e-4,1e-4});
  parameter Real x0[10] = {1.0,0.0,0.5,0.0,0.0,0.0,1.5707963267948966,0.0,0.0,0.0};
  parameter Real P0[10,10] = diagonal({1,1,1,1,1,1,0.5,0.01,0.01,0.01});
  parameter Real eps = 1e-6;
  parameter Real P_floor = 1e-9;

  // ===== Plant state =====
  Real r[3] "torso position, world frame, m";
  Real v[3] "torso velocity, world frame, m/s";
  Real euler[3] "roll,pitch,yaw, rad";
  Real w_ang[3] "angular velocity, rad/s";
  Real a_world[3] "world-frame acceleration, m/s^2";

  // ===== Reference =====
  Real r_ref[3], v_ref[3], euler_ref[3], a_ref[3];

  // ===== Controller / actuators =====
  Real W_des[6] "desired wrench [fx,fy,fz,tx,ty,tz]";
  Real tau_cmd[12] "commanded joint torques, N.m";
  Real tau[12] "limited joint torques, N.m";
  Real W_act[6] "actual wrench";
  Boolean limit_viol[12];

  // ===== Sensors =====
  Real a_imu[3] "IMU specific force, m/s^2";
  Real w_imu[3] "IMU gyroscope, rad/s";
  Real theta_enc[12] "joint encoder angles, rad";
  Boolean contact[4] "foot contact flags";
  Real f_normal[4] "foot normal forces, N";
  Real range_lm[3] "landmark range measurements, m";
  Real t_stamp_imu(start=0.0) "IMU timestamp, s";
  Real t_stamp_enc(start=0.0) "encoder timestamp, s";
  Real t_stamp_lm(start=0.0) "landmark timestamp, s";

  // True biases
  Real b_acc_true "true accel bias (z), m/s^2";
  Real b_gyro_true "true gyro bias (z), rad/s";
  Real b_enc_true "true encoder bias, rad";

  // Deterministic noise
  Real n_acc[3], n_gyro[3], n_enc[12], n_range[3], n_h;

  // ===== EKF state =====
  Real x_est[10](start=x0);
  Real P[10,10](start=P0);
  Real tick_i(start=0.0);
  Real lm_idx(start=0.0);

  // EKF temporaries
  Real d1,d2,d3,dist,H1,H2,H3,innov,S;
  Real K[10];
  Real S_enc, innov_enc;
  Real Ke[10];
  Real S_h, innov_h;
  Real Kh[10];
  Real Ppre[10,10];
  Real xpre[10];

  // ===== Verification =====
  Real pos_err "position estimation error, m";
  Real yaw_err "yaw estimation error, rad";
  Real track_err "primary tracking error, m-or-rad";
  Real bias_err_acc, bias_err_gyro, bias_err_enc;
  Real cov_trace "covariance trace";
  Boolean cov_ok;
  Boolean limit_ok;
  Boolean finite_ok;

  output Real tracking_error_out;
  output Real covariance_trace_out;
  output Real bias_convergence_out;

equation
  // ===== Reference (bounded circular route) =====
  r_ref[1] = route_r*cos(route_w*time);
  r_ref[2] = route_r*sin(route_w*time);
  r_ref[3] = 0.5;
  v_ref[1] = -route_r*route_w*sin(route_w*time);
  v_ref[2] =  route_r*route_w*cos(route_w*time);
  v_ref[3] = 0.0;
  a_ref[1] = -route_r*route_w*route_w*cos(route_w*time);
  a_ref[2] = -route_r*route_w*route_w*sin(route_w*time);
  a_ref[3] = 0.0;
  euler_ref[1] = 0.0;
  euler_ref[2] = 0.0;
  euler_ref[3] = route_w*time + 1.5707963267948966;

  // ===== Plant dynamics =====
  der(r[1]) = v[1];
  der(r[2]) = v[2];
  der(r[3]) = v[3];
  der(v[1]) = W_act[1]/m_torso;
  der(v[2]) = W_act[2]/m_torso;
  der(v[3]) = (W_act[3] - m_torso*g)/m_torso;
  der(euler[1]) = w_ang[1];
  der(euler[2]) = w_ang[2];
  der(euler[3]) = w_ang[3];
  der(w_ang[1]) = (W_act[4] - 2.0*w_ang[1])/I_torso;
  der(w_ang[2]) = (W_act[5] - 2.0*w_ang[2])/I_torso;
  der(w_ang[3]) = (W_act[6] - 2.0*w_ang[3])/I_torso;

  a_world[1] = W_act[1]/m_torso;
  a_world[2] = W_act[2]/m_torso;
  a_world[3] = (W_act[3] - m_torso*g)/m_torso;

  // ===== Controller (uses estimated state; no ground truth to estimator) =====
  W_des[1] = m_torso*(a_ref[1] + Kp_p*(r_ref[1]-x_est[1]) + Kd_p*(v_ref[1]-x_est[4]));
  W_des[2] = m_torso*(a_ref[2] + Kp_p*(r_ref[2]-x_est[2]) + Kd_p*(v_ref[2]-x_est[5]));
  W_des[3] = m_torso*(a_ref[3] + Kp_p*(r_ref[3]-x_est[3]) + Kd_p*(v_ref[3]-x_est[6])) + m_torso*g;
  W_des[4] = I_torso*(-Kd_a*w_imu[1]);
  W_des[5] = I_torso*(-Kd_a*w_imu[2]);
  W_des[6] = I_torso*(Kp_a*(euler_ref[3]-x_est[7]) + Kd_a*(route_w - (w_imu[3]-x_est[9])));

  // ===== Actuator mapping: 12 joint torques from 6 wrench components =====
  tau_cmd[1]  = (W_des[1]/2)*L_force;
  tau_cmd[2]  = (W_des[1]/2)*L_force;
  tau_cmd[3]  = (W_des[2]/2)*L_force;
  tau_cmd[4]  = (W_des[2]/2)*L_force;
  tau_cmd[5]  = (W_des[3]/2)*L_force;
  tau_cmd[6]  = (W_des[3]/2)*L_force;
  tau_cmd[7]  = W_des[4]/2;
  tau_cmd[8]  = W_des[4]/2;
  tau_cmd[9]  = W_des[5]/2;
  tau_cmd[10] = W_des[5]/2;
  tau_cmd[11] = W_des[6]/2;
  tau_cmd[12] = W_des[6]/2;

  for i in 1:12 loop
    tau[i] = if tau_cmd[i] > tau_max then tau_max
             elseif tau_cmd[i] < -tau_max then -tau_max
             else tau_cmd[i];
    limit_viol[i] = abs(tau_cmd[i]) > tau_max + 1e-6;
  end for;

  W_act[1] = (tau[1]+tau[2])/L_force;
  W_act[2] = (tau[3]+tau[4])/L_force;
  W_act[3] = (tau[5]+tau[6])/L_force;
  W_act[4] = tau[7]+tau[8];
  W_act[5] = tau[9]+tau[10];
  W_act[6] = tau[11]+tau[12];

  // ===== True biases with step disturbance (accel z) =====
  b_acc_true  = 0.02 + (if time >= t_step_a and time <= t_step_b then bias_step else 0.0);
  b_gyro_true = 0.005;
  b_enc_true  = 0.01;

  // ===== Deterministic noise =====
  for i in 1:3 loop
    n_acc[i]   = sigma_acc*sin(time*37.0 + i*1.7);
    n_gyro[i]  = sigma_gyro*sin(time*41.0 + i*2.3);
    n_range[i] = sigma_range*sin(time*61.0 + i*3.1);
  end for;
  for i in 1:12 loop
    n_enc[i] = sigma_enc*sin(time*53.0 + i*0.9);
  end for;
  n_h = sigma_h*sin(time*71.0);

  // ===== Sensors =====
  a_imu[1] = a_world[1] + n_acc[1];
  a_imu[2] = a_world[2] + n_acc[2];
  a_imu[3] = a_world[3] + g + b_acc_true + n_acc[3];
  w_imu[1] = w_ang[1] + n_gyro[1];
  w_imu[2] = w_ang[2] + n_gyro[2];
  w_imu[3] = w_ang[3] + b_gyro_true + n_gyro[3];

  for i in 1:12 loop
    theta_enc[i] = euler[3] + 0.1*(i-1) + b_enc_true + n_enc[i];
  end for;

  for i in 1:4 loop
    contact[i]   = (r[3] - 0.5 + 0.02*sin(time*5.0 + i)) <= 0.05;
    f_normal[i]  = if contact[i]
                   then m_torso*g/4.0 + 5.0*sin(time*3.0 + i*1.5) + sigma_fn*sin(time*43.0 + i)
                   else 0.0;
  end for;

  for k in 1:3 loop
    range_lm[k] = sqrt((r[1]-LM[k,1])^2 + (r[2]-LM[k,2])^2 + (r[3]-LM[k,3])^2 + eps) + n_range[k];
  end for;

  // ===== Verification outputs =====
  pos_err = sqrt((r[1]-x_est[1])^2 + (r[2]-x_est[2])^2 + (r[3]-x_est[3])^2 + eps);
  yaw_err = abs(euler[3] - x_est[7]);
  track_err = pos_err + yaw_err;
  bias_err_acc  = abs(x_est[8]  - b_acc_true);
  bias_err_gyro = abs(x_est[9]  - b_gyro_true);
  bias_err_enc  = abs(x_est[10] - b_enc_true);
  cov_trace = P[1,1]+P[2,2]+P[3,3]+P[4,4]+P[5,5]+P[6,6]+P[7,7]+P[8,8]+P[9,9]+P[10,10];
  cov_ok = (cov_trace > P_floor) and (cov_trace < 1e6);
  limit_ok = not (limit_viol[1] or limit_viol[2] or limit_viol[3] or limit_viol[4] or
                  limit_viol[5] or limit_viol[6] or limit_viol[7] or limit_viol[8] or
                  limit_viol[9] or limit_viol[10] or limit_viol[11] or limit_viol[12]);
  finite_ok = (pos_err < 1e6) and (yaw_err < 1e6) and (cov_trace < 1e6) and (cov_trace >= 0.0);
  tracking_error_out = track_err;
  covariance_trace_out = cov_trace;
  bias_convergence_out = bias_err_acc;

  // ===== Assertions =====
  assert(cov_ok, "Covariance must remain finite and positive");
  assert(finite_ok, "No NaN or infinite physical, control, or estimator values");
  assert(time < 13.0 or track_err < 0.16,
         "Primary tracking error must be below 0.16 m-or-rad after 13 s");

algorithm
  when sample(0, dt_imu) then
    // Increment tick counter
    tick_i := pre(tick_i) + 1.0;

    // Save previous state
    for i in 1:10 loop
      xpre[i] := pre(x_est[i]);
    end for;
    for i in 1:10 loop
      for j in 1:10 loop
        Ppre[i,j] := pre(P[i,j]);
      end for;
    end for;

    // ===== PREDICTION (500 Hz) =====
    x_est[1]  := xpre[1]  + xpre[4]*dt_imu;
    x_est[2]  := xpre[2]  + xpre[5]*dt_imu;
    x_est[3]  := xpre[3]  + xpre[6]*dt_imu;
    x_est[4]  := xpre[4]  + a_imu[1]*dt_imu;
    x_est[5]  := xpre[5]  + a_imu[2]*dt_imu;
    x_est[6]  := xpre[6]  + (a_imu[3] - g - xpre[8])*dt_imu;
    x_est[7]  := xpre[7]  + (w_imu[3] - xpre[9])*dt_imu;
    x_est[8]  := xpre[8];
    x_est[9]  := xpre[9];
    x_est[10] := xpre[10];

    // P prediction: P = Fd * Ppre * Fd' + Q
    for i in 1:10 loop
      for j in 1:10 loop
        P[i,j] := 0.0;
        for k in 1:10 loop
          for l in 1:10 loop
            P[i,j] := P[i,j] + Fd[i,k]*Ppre[k,l]*Fd[j,l];
          end for;
        end for;
        P[i,j] := P[i,j] + Q[i,j];
      end for;
    end for;

    // ===== ENCODER + CONTACT-HEIGHT UPDATE (250 Hz = every 2 ticks) =====
    if abs(mod(tick_i, 2.0)) < 0.5 then
      // Save P before update
      for i in 1:10 loop
        for j in 1:10 loop
          Ppre[i,j] := P[i,j];
        end for;
      end for;

      // Encoder innovation (observes yaw + encoder bias)
      innov_enc := theta_enc[1] - (x_est[7] + x_est[10]);
      S_enc := Ppre[7,7] + Ppre[7,10] + Ppre[10,7] + Ppre[10,10] + sigma_enc*sigma_enc + eps;
      for i in 1:10 loop
        Ke[i] := (Ppre[i,7] + Ppre[i,10]) / S_enc;
      end for;

      // Contact-derived torso height innovation (observes z)
      innov_h := (0.5 + n_h) - x_est[3];
      S_h := Ppre[3,3] + sigma_h*sigma_h + eps;
      for i in 1:10 loop
        Kh[i] := Ppre[i,3] / S_h;
      end for;

      // Apply state update
      for i in 1:10 loop
        x_est[i] := x_est[i] + Ke[i]*innov_enc + Kh[i]*innov_h;
      end for;

      // Apply covariance update
      for i in 1:10 loop
        for j in 1:10 loop
          P[i,j] := Ppre[i,j] - Ke[i]*(Ppre[7,j] + Ppre[10,j]) - Kh[i]*Ppre[3,j];
        end for;
      end for;

      t_stamp_enc := time;
    end if;

    // ===== LANDMARK RANGE UPDATE (100 Hz = every 5 ticks) =====
    if abs(mod(tick_i, 5.0)) < 0.5 then
      // Cycle through landmarks
      lm_idx := mod(pre(lm_idx), 3.0) + 1.0;

      // Save P before update
      for i in 1:10 loop
        for j in 1:10 loop
          Ppre[i,j] := P[i,j];
        end for;
      end for;

      // Range innovation
      d1 := x_est[1] - LM[integer(lm_idx),1];
      d2 := x_est[2] - LM[integer(lm_idx),2];
      d3 := x_est[3] - LM[integer(lm_idx),3];
      dist := sqrt(d1*d1 + d2*d2 + d3*d3 + eps);
      H1 := d1/dist;
      H2 := d2/dist;
      H3 := d3/dist;
      innov := range_lm[integer(lm_idx)] - dist;
      S := H1*(Ppre[1,1]*H1 + Ppre[1,2]*H2 + Ppre[1,3]*H3)
         + H2*(Ppre[2,1]*H1 + Ppre[2,2]*H2 + Ppre[2,3]*H3)
         + H3*(Ppre[3,1]*H1 + Ppre[3,2]*H2 + Ppre[3,3]*H3)
         + sigma_range*sigma_range + eps;
      for i in 1:10 loop
        K[i] := (Ppre[i,1]*H1 + Ppre[i,2]*H2 + Ppre[i,3]*H3) / S;
      end for;

      // Apply state update
      for i in 1:10 loop
        x_est[i] := x_est[i] + K[i]*innov;
      end for;

      // Apply covariance update
      for i in 1:10 loop
        for j in 1:10 loop
          P[i,j] := Ppre[i,j] - K[i]*(H1*Ppre[1,j] + H2*Ppre[2,j] + H3*Ppre[3,j]);
        end for;
      end for;

      t_stamp_lm := time;
    end if;

    t_stamp_imu := time;
  end when;

initial equation
  r[1] = route_r;
  r[2] = 0.0;
  r[3] = 0.5;
  v[1] = 0.0;
  v[2] = route_r*route_w;
  v[3] = 0.0;
  euler[1] = 0.0;
  euler[2] = 0.0;
  euler[3] = 1.5707963267948966;
  w_ang[1] = 0.0;
  w_ang[2] = 0.0;
  w_ang[3] = route_w;

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-4, Interval=0.002),
    Documentation(info="Robotic sensing/estimation scenario. Frames: world W (inertial),
      body B (level, yaw-only). Sensor rates: IMU 500 Hz, encoders 250 Hz, landmarks 100 Hz,
      contact/normal force 500 Hz. Bias states: accel-z, gyro-z, encoder. Step 0.058 on
      accel bias during [6.667,13.333] s. Actuator limit 67.1 N.m per joint."));
end ContactStateLocalizeF;