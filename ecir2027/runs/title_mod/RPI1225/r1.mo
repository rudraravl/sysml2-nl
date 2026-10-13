model MapRigLocalizeA
  function wrapAngle "wrap angle to (-pi,pi]"
    input Real a;
    output Real w;
  algorithm
    w := mod(a, 2.0*Modelica.Constants.PI);
    if w > Modelica.Constants.PI then
      w := w - 2.0*Modelica.Constants.PI;
    end if;
  end wrapAngle;

  function limitSym "symmetric saturation"
    input Real x;
    input Real lim;
    output Real y;
  algorithm
    if x > lim then
      y := lim;
    elseif x < -lim then
      y := -lim;
    else
      y := x;
    end if;
  end limitSym;

  // Physical and route parameters
  parameter Real m_base=22.0 "kg, specified mobile base mass";
  parameter Real r_wheel=0.10 "m, nominal unstated wheel radius";
  parameter Real half_axle=0.20 "m, nominal unstated half axle";
  parameter Real Iz=1.5 "kg.m^2, nominal unstated yaw inertia";
  parameter Real c_v=8.0 "N.s/m, nominal unstated linear drag";
  parameter Real c_w=1.2 "N.m.s/rad, nominal unstated yaw drag";
  parameter Real tauMax=8.64 "N.m, specified per-wheel command magnitude limit";

  parameter Real routeSpeedX=0.8 "m/s";
  parameter Real routeAmpY=0.4 "m";
  parameter Real routeFreq=0.5 "rad/s";
  parameter Real theta0=atan2(routeAmpY*routeFreq, routeSpeedX) "rad";
  parameter Real v0=sqrt(routeSpeedX^2 + (routeAmpY*routeFreq)^2) "m/s";

  // Sensor rates, frames, transforms, standard deviations
  parameter Real rate_imu=200.0 "Hz";
  parameter Real rate_enc=100.0 "Hz";
  parameter Real rate_lidar=10.0 "Hz";
  parameter Real rate_cam=30.0 "Hz";
  parameter Real rate_sync=80.0 "Hz";
  parameter Real dt_imu=1.0/rate_imu "s";
  parameter Real dt_enc=1.0/rate_enc "s";
  parameter Real dt_lidar=1.0/rate_lidar "s";
  parameter Real dt_cam=1.0/rate_cam "s";
  parameter Real dt_sync=1.0/rate_sync "s";

  parameter String imuFrame="imu_link";
  parameter String lidarFrame="lidar_link";
  parameter String camFrame="camera_link";
  parameter String encFrameR="wheel_right";
  parameter String encFrameL="wheel_left";

  parameter Real imu_x=0.05 "m, nominal unstated IMU x transform";
  parameter Real imu_yaw=0.0 "rad, nominal unstated IMU yaw transform";
  parameter Real lidar_x=0.12 "m, nominal unstated lidar x transform";
  parameter Real lidar_yaw=0.0 "rad, nominal unstated lidar yaw transform";
  parameter Real cam_x=0.15 "m, nominal unstated camera x transform";
  parameter Real cam_yaw=0.0 "rad, nominal unstated camera yaw transform";
  parameter Real encR_y=0.20 "m, nominal unstated right encoder y transform";
  parameter Real encL_y=-0.20 "m, nominal unstated left encoder y transform";

  parameter Real lidarMaxRange=20.0 "m, specified planar lidar range";
  parameter Real cameraMaxRange=10.0 "m, nominal unstated RGB-D range";
  parameter Real cameraHalfFov=0.6 "rad, nominal unstated forward RGB-D half FOV";

  parameter Real sigma_gyro=0.002 "rad/s";
  parameter Real sigma_acc=0.02 "m/s^2";
  parameter Real sigma_enc=0.05 "rad/s";
  parameter Real sigma_lidar_range=0.02 "m";
  parameter Real sigma_lidar_bearing=0.01 "rad";
  parameter Real sigma_cam_range=0.05 "m";
  parameter Real sigma_cam_bearing=0.03 "rad";

  // Bias disturbance and verification bands
  parameter Real biasStep=0.02 "rad/s, specified sensor-bias step";
  parameter Real tBiasStart=8.0/3.0 "s, start of middle third";
  parameter Real tBiasEnd=16.0/3.0 "s, end of middle third";
  parameter Real tCheck=5.2 "s";
  parameter Real posBand=0.27 "m";
  parameter Real attBand=0.27 "rad";
  parameter Real trackingBand=0.27 "m or rad";

  // Fixed landmarks (known external references, not ground truth to estimator)
  parameter Real Lx1=2.0 "m";
  parameter Real Ly1=-0.8 "m";
  parameter Real Lx2=4.0 "m";
  parameter Real Ly2=0.8 "m";
  parameter Real Lx3=6.0 "m";
  parameter Real Ly3=-0.8 "m";

  // EKF covariance parameters
  parameter Real Pmin=1.0e-9;
  parameter Real Qx=1.0e-5;
  parameter Real Qy=1.0e-5;
  parameter Real Qtheta=2.0e-5;
  parameter Real Qv=1.0e-4;
  parameter Real Qw=2.0e-4;
  parameter Real Qbg=1.0e-6;
  parameter Real Qbe=1.0e-6;
  parameter Real Qbl=1.0e-6;
  parameter Real Qbc=1.0e-6;

  // Controller gains
  parameter Real Kp_v=40.0;
  parameter Real Kp_pos=25.0;
  parameter Real Kp_w=10.0;
  parameter Real Kp_lat=30.0;
  parameter Real Kp_th=15.0;

  // Plant state
  Real x(start=0.0, fixed=true) "m";
  Real y(start=0.0, fixed=true) "m";
  Real theta(start=theta0, fixed=true) "rad";
  Real v(start=v0, fixed=true) "m/s";
  Real omega(start=0.0, fixed=true) "rad/s";
  Real a_body "m/s^2";

  // Route reference
  Real x_ref "m";
  Real y_ref "m";
  Real theta_ref "rad";
  Real v_ref "m/s";
  Real omega_ref "rad/s";
  Real dx_ref "m/s";
  Real dy_ref "m/s";
  Real ddy_ref "m/s^2";

  // Control
  Real F_R "N";
  Real F_L "N";
  Real tau_R_raw "N.m";
  Real tau_L_raw "N.m";
  Real tau_R_sat "N.m";
  Real tau_L_sat "N.m";
  Real F_des "N";
  Real M_des "N.m";
  Real pos_err_x "m";
  Real pos_err_y "m";
  Real theta_err "rad";

  // Sensor traces
  Real b_gyro_true "rad/s";
  Real b_acc_true=0.0 "m/s^2";
  Real b_enc_true=0.0 "rad/s";
  Real b_lidar_true=0.0 "m";
  Real b_cam_true=0.0 "m";

  Real gyro_meas_z(start=0.0, fixed=true) "rad/s";
  Real accel_meas_z(start=0.0, fixed=true) "m/s^2";
  Real wR_meas(start=0.0, fixed=true) "rad/s";
  Real wL_meas(start=0.0, fixed=true) "rad/s";

  Real lidar_sel_range(start=0.0, fixed=true) "m";
  Real lidar_sel_bearing(start=0.0, fixed=true) "rad";
  Real lidar_sel_Lx(start=0.0, fixed=true) "m";
  Real lidar_sel_Ly(start=0.0, fixed=true) "m";
  Boolean lidar_valid(start=false, fixed=true);

  Real cam_sel_range(start=0.0, fixed=true) "m";
  Real cam_sel_bearing(start=0.0, fixed=true) "rad";
  Real cam_sel_Lx(start=0.0, fixed=true) "m";
  Real cam_sel_Ly(start=0.0, fixed=true) "m";
  Boolean cam_valid(start=false, fixed=true);

  Real t_imu_last(start=0.0, fixed=true) "s";
  Real t_enc_last(start=0.0, fixed=true) "s";
  Real t_lidar_last(start=0.0, fixed=true) "s";
  Real t_cam_last(start=0.0, fixed=true) "s";

  // Estimator state
  Real x_e(start=0.0, fixed=true) "m";
  Real y_e(start=0.0, fixed=true) "m";
  Real theta_e(start=theta0, fixed=true) "rad";
  Real v_e(start=v0, fixed=true) "m/s";
  Real omega_e(start=0.0, fixed=true) "rad/s";
  Real b_gyro_e(start=0.0, fixed=true) "rad/s";
  Real b_enc_e(start=0.0, fixed=true) "rad/s";
  Real b_lidar_e(start=0.0, fixed=true) "m";
  Real b_cam_e(start=0.0, fixed=true) "m";

  // Estimator covariance
  Real Pxx(start=0.01, fixed=true);
  Real Pyy(start=0.01, fixed=true);
  Real Ptt(start=0.005, fixed=true);
  Real Pvv(start=0.01, fixed=true);
  Real Pww(start=0.01, fixed=true);
  Real Pbg(start=0.001, fixed=true);
  Real Pbe(start=0.001, fixed=true);
  Real Pbl(start=0.001, fixed=true);
  Real Pbc(start=0.001, fixed=true);

  // Errors and bands
  Real route_pos_error "m";
  Real route_att_error "rad";
  Real primary_tracking_error "m or rad";
  Real estimator_pos_error "m";
  Real estimator_att_error "rad";
  Real bias_error "rad/s";
  Real trackingOK;
  Real posErrorOK;
  Real attErrorOK;

  // Synchronized 80 Hz traces
  Real t_sync(start=0.0, fixed=true) "s";
  Real x_sync(start=0.0, fixed=true) "m";
  Real y_sync(start=0.0, fixed=true) "m";
  Real theta_sync(start=0.0, fixed=true) "rad";
  Real v_sync(start=0.0, fixed=true) "m/s";
  Real omega_sync(start=0.0, fixed=true) "rad/s";
  Real x_est_sync(start=0.0, fixed=true) "m";
  Real y_est_sync(start=0.0, fixed=true) "m";
  Real theta_est_sync(start=0.0, fixed=true) "rad";
  Real v_est_sync(start=0.0, fixed=true) "m/s";
  Real omega_est_sync(start=0.0, fixed=true) "rad/s";
  Real tau_R_sync(start=0.0, fixed=true) "N.m";
  Real tau_L_sync(start=0.0, fixed=true) "N.m";
  Real gyro_sync(start=0.0, fixed=true) "rad/s";
  Real accel_sync(start=0.0, fixed=true) "m/s^2";
  Real wR_sync(start=0.0, fixed=true) "rad/s";
  Real wL_sync(start=0.0, fixed=true) "rad/s";
  Real lidar_range_sync(start=0.0, fixed=true) "m";
  Real lidar_bearing_sync(start=0.0, fixed=true) "rad";
  Real cam_range_sync(start=0.0, fixed=true) "m";
  Real cam_bearing_sync(start=0.0, fixed=true) "rad";
  Real b_gyro_sync(start=0.0, fixed=true) "rad/s";
  Real b_enc_sync(start=0.0, fixed=true) "rad/s";
  Real b_lidar_sync(start=0.0, fixed=true) "m";
  Real b_cam_sync(start=0.0, fixed=true) "m";
  Real primary_tracking_error_sync(start=0.0, fixed=true) "m or rad";
  Real estimator_pos_error_sync(start=0.0, fixed=true) "m";
  Real estimator_att_error_sync(start=0.0, fixed=true) "rad";

  // Scratch variables for asynchronous EKF updates
  Real dx1; Real dy1; Real blx1; Real bly1; Real r1; Real phi1; Boolean vis1;
  Real dx2; Real dy2; Real blx2; Real bly2; Real r2; Real phi2; Boolean vis2;
  Real dx3; Real dy3; Real blx3; Real bly3; Real r3; Real phi3; Boolean vis3;

  Real wR_obs; Real wL_obs; Real v_obs; Real omega_obs;
  Real innov_v; Real S_v; Real Kv; Real Kbe; Real R_v;
  Real innov_w; Real S_w; Real Kw; Real R_w;
  Real innov_bg; Real S_bg; Real Kbg; Real R_bg;

  Real dxe; Real dye; Real slx; Real sly; Real re; Real phie;
  Real innov_r; Real Hrx; Real Hry; Real S_r; Real Kx; Real Ky; Real Kbl;
  Real innov_phi; Real Hpx; Real Hpy; Real S_phi; Real Kpx; Real Kpy; Real Kt;
  Real x_new; Real y_new; Real theta_new; Real b_new;
  Real Pxx_new; Real Pyy_new; Real Ptt_new; Real Pbl_new; Real Pbc_new;

equation
  // Route reference
  dx_ref = routeSpeedX;
  dy_ref = routeAmpY*routeFreq*cos(routeFreq*time);
  ddy_ref = -routeAmpY*routeFreq^2*sin(routeFreq*time);
  x_ref = routeSpeedX*time;
  y_ref = routeAmpY*sin(routeFreq*time);
  v_ref = sqrt(dx_ref^2 + dy_ref^2);
  theta_ref = atan2(dy_ref, dx_ref);
  omega_ref = (dx_ref*ddy_ref - dy_ref*0.0)/(dx_ref^2 + dy_ref^2);

  // Plant dynamics
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(v) = (F_R + F_L - c_v*v)/m_base;
  der(omega) = ((F_R - F_L)*half_axle - c_w*omega)/Iz;
  a_body = (F_R + F_L - c_v*v)/m_base;
  F_R = tau_R_sat/r_wheel;
  F_L = tau_L_sat/r_wheel;

  // Controller using estimator state
  pos_err_x = (x_ref - x_e)*cos(theta_e) + (y_ref - y_e)*sin(theta_e);
  pos_err_y = -(x_ref - x_e)*sin(theta_e) + (y_ref - y_e)*cos(theta_e);
  theta_err = wrapAngle(theta_ref - theta_e);
  F_des = Kp_v*(v_ref - v_e) + Kp_pos*pos_err_x + c_v*v_e;
  M_des = Kp_w*(omega_ref - omega_e) + Kp_lat*pos_err_y + Kp_th*theta_err + c_w*omega_e;
  tau_R_raw = (0.5*F_des + 0.5*M_des/half_axle)*r_wheel;
  tau_L_raw = (0.5*F_des - 0.5*M_des/half_axle)*r_wheel;
  tau_R_sat = limitSym(tau_R_raw, tauMax);
  tau_L_sat = limitSym(tau_L_raw, tauMax);

  // Controlled gyro bias disturbance
  b_gyro_true = if time >= tBiasStart and time <= tBiasEnd then biasStep else 0.0;

  // EKF prediction
  der(x_e) = v_e*cos(theta_e);
  der(y_e) = v_e*sin(theta_e);
  der(theta_e) = gyro_meas_z - b_gyro_e;
  der(v_e) = accel_meas_z;
  der(b_gyro_e) = 0.0;
  der(b_enc_e) = 0.0;
  der(b_lidar_e) = 0.0;
  der(b_cam_e) = 0.0;

  // Covariance prediction
  der(Pxx) = Qx;
  der(Pyy) = Qy;
  der(Ptt) = Qtheta;
  der(Pvv) = Qv;
  der(Pww) = Qw;
  der(Pbg) = Qbg;
  der(Pbe) = Qbe;
  der(Pbl) = Qbl;
  der(Pbc) = Qbc;

  // Error metrics
  route_pos_error = sqrt(max((x_ref - x)^2 + (y_ref - y)^2, 1.0e-6));
  route_att_error = abs(wrapAngle(theta_ref - theta));
  primary_tracking_error = max(route_pos_error, route_att_error);
  estimator_pos_error = sqrt(max((x - x_e)^2 + (y - y_e)^2, 1.0e-6));
  estimator_att_error = abs(wrapAngle(theta - theta_e));
  bias_error = abs(b_gyro_true - b_gyro_e);

  trackingOK = if time >= tCheck then (if primary_tracking_error <= trackingBand then 1.0 else 0.0) else 1.0;
  posErrorOK = if estimator_pos_error <= posBand then 1.0 else 0.0;
  attErrorOK = if estimator_att_error <= attBand then 1.0 else 0.0;

algorithm
  // IMU at 200 Hz
  when sample(0.0, dt_imu) then
    gyro_meas_z := omega + b_gyro_true + sigma_gyro*sin(11.0*time);
    accel_meas_z := a_body + b_acc_true + sigma_acc*sin(13.0*time);
    omega_e := gyro_meas_z - b_gyro_e;
    t_imu_last := time;
  end when;

  // Wheel encoders at 100 Hz
  when sample(0.0, dt_enc) then
    wR_meas := (v + omega*half_axle)/r_wheel + b_enc_true + sigma_enc*sin(23.0*time);
    wL_meas := (v - omega*half_axle)/r_wheel + b_enc_true + sigma_enc*sin(29.0*time);
    v_obs := r_wheel*(wR_meas + wL_meas)/2.0;
    omega_obs := r_wheel*(wR_meas - wL_meas)/(2.0*half_axle);

    R_v := (r_wheel*sigma_enc)^2/2.0;
    innov_v := v_obs - (v_e + r_wheel*b_enc_e);
    S_v := max(Pvv + r_wheel^2*Pbe + R_v, Pmin);
    Kv := Pvv/S_v;
    Kbe := r_wheel*Pbe/S_v;
    v_e := v_e + Kv*innov_v;
    b_enc_e := b_enc_e + Kbe*innov_v;
    Pvv := max((1.0 - Kv)*Pvv, Pmin);
    Pbe := max((1.0 - Kbe*r_wheel)*Pbe, Pmin);

    R_w := (r_wheel*sigma_enc/half_axle)^2/2.0;
    innov_w := omega_obs - omega_e;
    S_w := max(Pww + R_w, Pmin);
    Kw := Pww/S_w;
    omega_e := omega_e + Kw*innov_w;
    Pww := max((1.0 - Kw)*Pww, Pmin);

    R_bg := sigma_gyro^2 + R_w;
    innov_bg := gyro_meas_z - omega_obs - b_gyro_e;
    S_bg := max(Pbg + R_bg, Pmin);
    Kbg := Pbg/S_bg;
    b_gyro_e := b_gyro_e + Kbg*innov_bg;
    Pbg := max((1.0 - Kbg)*Pbg, Pmin);

    t_enc_last := time;
  end when;

  // Planar lidar at 10 Hz
  when sample(0.0, dt_lidar) then
    dx1 := Lx1 - x;
    dy1 := Ly1 - y;
    blx1 := cos(theta + lidar_yaw)*dx1 + sin(theta + lidar_yaw)*dy1 - lidar_x;
    bly1 := -sin(theta + lidar_yaw)*dx1 + cos(theta + lidar_yaw)*dy1;
    r1 := sqrt(max(blx1^2 + bly1^2, 1.0e-6));
    phi1 := atan2(bly1, blx1);
    vis1 := r1 <= lidarMaxRange;

    dx2 := Lx2 - x;
    dy2 := Ly2 - y;
    blx2 := cos(theta + lidar_yaw)*dx2 + sin(theta + lidar_yaw)*dy2 - lidar_x;
    bly2 := -sin(theta + lidar_yaw)*dx2 + cos(theta + lidar_yaw)*dy2;
    r2 := sqrt(max(blx2^2 + bly2^2, 1.0e-6));
    phi2 := atan2(bly2, blx2);
    vis2 := r2 <= lidarMaxRange;

    dx3 := Lx3 - x;
    dy3 := Ly3 - y;
    blx3 := cos(theta + lidar_yaw)*dx3 + sin(theta + lidar_yaw)*dy3 - lidar_x;
    bly3 := -sin(theta + lidar_yaw)*dx3 + cos(theta + lidar_yaw)*dy3;
    r3 := sqrt(max(blx3^2 + bly3^2, 1.0e-6));
    phi3 := atan2(bly3, blx3);
    vis3 := r3 <= lidarMaxRange;

    if vis1 and (not vis2 or r1 <= r2) and (not vis3 or r1 <= r3) then
      lidar_valid := true;
      lidar_sel_range := r1 + b_lidar_true + sigma_lidar_range*sin(1.7*time);
      lidar_sel_bearing := phi1 + sigma_lidar_bearing*sin(2.3*time);
      lidar_sel_Lx := Lx1;
      lidar_sel_Ly := Ly1;
    elseif vis2 and (not vis3 or r2 <= r3) then
      lidar_valid := true;
      lidar_sel_range := r2 + b_lidar_true + sigma_lidar_range*sin(1.7*time);
      lidar_sel_bearing := phi2 + sigma_lidar_bearing*sin(2.3*time);
      lidar_sel_Lx := Lx2;
      lidar_sel_Ly := Ly2;
    elseif vis3 then
      lidar_valid := true;
      lidar_sel_range := r3 + b_lidar_true + sigma_lidar_range*sin(1.7*time);
      lidar_sel_bearing := phi3 + sigma_lidar_bearing*sin(2.3*time);
      lidar_sel_Lx := Lx3;
      lidar_sel_Ly := Ly3;
    else
      lidar_valid := false;
      lidar_sel_range := lidar_sel_range;
      lidar_sel_bearing := lidar_sel_bearing;
      lidar_sel_Lx := lidar_sel_Lx;
      lidar_sel_Ly := lidar_sel_Ly;
    end if;

    t_lidar_last := time;

    if lidar_valid then
      dxe := lidar_sel_Lx - x_e;
      dye := lidar_sel_Ly - y_e;
      slx := cos(theta_e + lidar_yaw)*dxe + sin(theta_e + lidar_yaw)*dye - lidar_x;
      sly := -sin(theta_e + lidar_yaw)*dxe + cos(theta_e + lidar_yaw)*dye;
      re := sqrt(max(slx^2 + sly^2, 1.0e-6));
      phie := atan2(sly, slx);

      innov_r := lidar_sel_range - (re + b_lidar_e);
      Hrx := (-slx*cos(theta_e + lidar_yaw) + sly*sin(theta_e + lidar_yaw))/re;
      Hry := (-slx*sin(theta_e + lidar_yaw) - sly*cos(theta_e + lidar_yaw))/re;
      S_r := max(Hrx^2*Pxx + Hry^2*Pyy + Pbl + sigma_lidar_range^2, Pmin);
      Kx := Pxx*Hrx/S_r;
      Ky := Pyy*Hry/S_r;
      Kbl := Pbl/S_r;
      x_new := x_e + Kx*innov_r;
      y_new := y_e + Ky*innov_r;
      b_new := b_lidar_e + Kbl*innov_r;
      Pxx_new := max((1.0 - Kx*Hrx)*Pxx, Pmin);
      Pyy_new := max((1.0 - Ky*Hry)*Pyy, Pmin);
      Pbl_new := max((1.0 - Kbl)*Pbl, Pmin);

      dxe := lidar_sel_Lx - x_new;
      dye := lidar_sel_Ly - y_new;
      slx := cos(theta_e + lidar_yaw)*dxe + sin(theta_e + lidar_yaw)*dye - lidar_x;
      sly := -sin(theta_e + lidar_yaw)*dxe + cos(theta_e + lidar_yaw)*dye;
      re := sqrt(max(slx^2 + sly^2, 1.0e-6));
      phie := atan2(sly, slx);
      innov_phi := wrapAngle(lidar_sel_bearing - phie);
      Hpx := (slx*sin(theta_e + lidar_yaw) + sly*cos(theta_e + lidar_yaw))/(re^2);
      Hpy := (-slx*cos(theta_e + lidar_yaw) + sly*sin(theta_e + lidar_yaw))/(re^2);
      S_phi := max(Hpx^2*Pxx_new + Hpy^2*Pyy_new + Ptt + sigma_lidar_bearing^2, Pmin);
      Kpx := Pxx_new*Hpx/S_phi;
      Kpy := Pyy_new*Hpy/S_phi;
      Kt := Ptt/S_phi;
      x_new := x_new + Kpx*innov_phi;
      y_new := y_new + Kpy*innov_phi;
      theta_new := theta_e - Kt*innov_phi;
      Pxx_new := max((1.0 - Kpx*Hpx)*Pxx_new, Pmin);
      Pyy_new := max((1.0 - Kpy*Hpy)*Pyy_new, Pmin);
      Ptt_new := max((1.0 - Kt)*Ptt, Pmin);

      x_e := x_new;
      y_e := y_new;
      theta_e := theta_new;
      b_lidar_e := b_new;
      Pxx := Pxx_new;
      Pyy := Pyy_new;
      Ptt := Ptt_new;
      Pbl := Pbl_new;
    end if;
  end when;

  // Forward RGB-D camera at 30 Hz
  when sample(0.0, dt_cam) then
    dx1 := Lx1 - x;
    dy1 := Ly1 - y;
    blx1 := cos(theta + cam_yaw)*dx1 + sin(theta + cam_yaw)*dy1 - cam_x;
    bly1 := -sin(theta + cam_yaw)*dx1 + cos(theta + cam_yaw)*dy1;
    r1 := sqrt(max(blx1^2 + bly1^2, 1.0e-6));
    phi1 := atan2(bly1, blx1);
    vis1 := r1 <= cameraMaxRange and abs(wrapAngle(phi1)) <= cameraHalfFov;

    dx2 := Lx2 - x;
    dy2 := Ly2 - y;
    blx2 := cos(theta + cam_yaw)*dx2 + sin(theta + cam_yaw)*dy2 - cam_x;
    bly2 := -sin(theta + cam_yaw)*dx2 + cos(theta + cam_yaw)*dy2;
    r2 := sqrt(max(blx2^2 + bly2^2, 1.0e-6));
    phi2 := atan2(bly2, blx2);
    vis2 := r2 <= cameraMaxRange and abs(wrapAngle(phi2)) <= cameraHalfFov;

    dx3 := Lx3 - x;
    dy3 := Ly3 - y;
    blx3 := cos(theta + cam_yaw)*dx3 + sin(theta + cam_yaw)*dy3 - cam_x;
    bly3 := -sin(theta + cam_yaw)*dx3 + cos(theta + cam_yaw)*dy3;
    r3 := sqrt(max(blx3^2 + bly3^2, 1.0e-6));
    phi3 := atan2(bly3, blx3);
    vis3 := r3 <= cameraMaxRange and abs(wrapAngle(phi3)) <= cameraHalfFov;

    if vis1 then
      cam_valid := true;
      cam_sel_range := r1 + b_cam_true + sigma_cam_range*sin(3.1*time);
      cam_sel_bearing := phi1 + sigma_cam_bearing*sin(4.1*time);
      cam_sel_Lx := Lx1;
      cam_sel_Ly := Ly1;
    elseif vis2 then
      cam_valid := true;
      cam_sel_range := r2 + b_cam_true + sigma_cam_range*sin(3.1*time);
      cam_sel_bearing := phi2 + sigma_cam_bearing*sin(4.1*time);
      cam_sel_Lx := Lx2;
      cam_sel_Ly := Ly2;
    elseif vis3 then
      cam_valid := true;
      cam_sel_range := r3 + b_cam_true + sigma_cam_range*sin(3.1*time);
      cam_sel_bearing := phi3 + sigma_cam_bearing*sin(4.1*time);
      cam_sel_Lx := Lx3;
      cam_sel_Ly := Ly3;
    else
      cam_valid := false;
      cam_sel_range := cam_sel_range;
      cam_sel_bearing := cam_sel_bearing;
      cam_sel_Lx := cam_sel_Lx;
      cam_sel_Ly := cam_sel_Ly;
    end if;

    t_cam_last := time;

    if cam_valid then
      dxe := cam_sel_Lx - x_e;
      dye := cam_sel_Ly - y_e;
      slx := cos(theta_e + cam_yaw)*dxe + sin(theta_e + cam_yaw)*dye - cam_x;
      sly := -sin(theta_e + cam_yaw)*dxe + cos(theta_e + cam_yaw)*dye;
      re := sqrt(max(slx^2 + sly^2, 1.0e-6));
      phie := atan2(sly, slx);

      innov_r := cam_sel_range - (re + b_cam_e);
      Hrx := (-slx*cos(theta_e + cam_yaw) + sly*sin(theta_e + cam_yaw))/re;
      Hry := (-slx*sin(theta_e + cam_yaw) - sly*cos(theta_e + cam_yaw))/re;
      S_r := max(Hrx^2*Pxx + Hry^2*Pyy + Pbc + sigma_cam_range^2, Pmin);
      Kx := Pxx*Hrx/S_r;
      Ky := Pyy*Hry/S_r;
      Kbl := Pbc/S_r;
      x_new := x_e + Kx*innov_r;
      y_new := y_e + Ky*innov_r;
      b_new := b_cam_e + Kbl*innov_r;
      Pxx_new := max((1.0 - Kx*Hrx)*Pxx, Pmin);
      Pyy_new := max((1.0 - Ky*Hry)*Pyy, Pmin);
      Pbc_new := max((1.0 - Kbl)*Pbc, Pmin);

      dxe := cam_sel_Lx - x_new;
      dye := cam_sel_Ly - y_new;
      slx := cos(theta_e + cam_yaw)*dxe + sin(theta_e + cam_yaw)*dye - cam_x;
      sly := -sin(theta_e + cam_yaw)*dxe + cos(theta_e + cam_yaw)*dye;
      re := sqrt(max(slx^2 + sly^2, 1.0e-6));
      phie := atan2(sly, slx);
      innov_phi := wrapAngle(cam_sel_bearing - phie);
      Hpx := (slx*sin(theta_e + cam_yaw) + sly*cos(theta_e + cam_yaw))/(re^2);
      Hpy := (-slx*cos(theta_e + cam_yaw) + sly*sin(theta_e + cam_yaw))/(re^2);
      S_phi := max(Hpx^2*Pxx_new + Hpy^2*Pyy_new + Ptt + sigma_cam_bearing^2, Pmin);
      Kpx := Pxx_new*Hpx/S_phi;
      Kpy := Pyy_new*Hpy/S_phi;
      Kt := Ptt/S_phi;
      x_new := x_new + Kpx*innov_phi;
      y_new := y_new + Kpy*innov_phi;
      theta_new := theta_e - Kt*innov_phi;
      Pxx_new := max((1.0 - Kpx*Hpx)*Pxx_new, Pmin);
      Pyy_new := max((1.0 - Kpy*Hpy)*Pyy_new, Pmin);
      Ptt_new := max((1.0 - Kt)*Ptt, Pmin);

      x_e := x_new;
      y_e := y_new;
      theta_e := theta_new;
      b_cam_e := b_new;
      Pxx := Pxx_new;
      Pyy := Pyy_new;
      Ptt := Ptt_new;
      Pbc := Pbc_new;
    end if;
  end when;

  // Synchronized 80 Hz trace retention
  when sample(0.0, dt_sync) then
    t_sync := time;
    x_sync := x;
    y_sync := y;
    theta_sync := theta;
    v_sync := v;
    omega_sync := omega;
    x_est_sync := x_e;
    y_est_sync := y_e;
    theta_est_sync := theta_e;
    v_est_sync := v_e;
    omega_est_sync := omega_e;
    tau_R_sync := tau_R_sat;
    tau_L_sync := tau_L_sat;
    gyro_sync := gyro_meas_z;
    accel_sync := accel_meas_z;
    wR_sync := wR_meas;
    wL_sync := wL_meas;
    lidar_range_sync := lidar_sel_range;
    lidar_bearing_sync := lidar_sel_bearing;
    cam_range_sync := cam_sel_range;
    cam_bearing_sync := cam_sel_bearing;
    b_gyro_sync := b_gyro_e;
    b_enc_sync := b_enc_e;
    b_lidar_sync := b_lidar_e;
    b_cam_sync := b_cam_e;
    primary_tracking_error_sync := primary_tracking_error;
    estimator_pos_error_sync := estimator_pos_error;
    estimator_att_error_sync := estimator_att_error;
  end when;

  annotation(experiment(StopTime=8.0, Tolerance=1.0e-6, Interval=0.0125));
end MapRigLocalizeA;