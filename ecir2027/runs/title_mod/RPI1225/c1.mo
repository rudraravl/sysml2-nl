model MapRigLocalizeA
  import Modelica.Constants.pi;

  // Requirement facts
  parameter Real m_base = 22.0 "mobile base mass (kg)";
  parameter Real LidarRange = 20.0 "planar lidar maximum range (m)";
  parameter Real tauMax = 8.64 "per-wheel torque command magnitude limit (N.m)";
  parameter Real biasStep = 0.02 "controlled sensor-bias step disturbance magnitude";
  parameter Real tEnd = 8.0 "scenario duration (s)";
  parameter Real tReq = 5.2 "tracking-error requirement time (s)";
  parameter Real trackLimit = 0.27 "primary tracking error limit (m-or-rad)";
  parameter Real T_base = 1.0/80.0 "base estimator and IMU sample period (s)";

  // Mechanical and route parameters (assumptions labeled)
  parameter Real wheelRadius = 0.05 "wheel radius (m) assumption";
  parameter Real wheelBase = 0.40 "wheel separation (m) assumption";
  parameter Real J_base = m_base*wheelBase^2/12.0 "planar yaw inertia (kg.m^2) assumption";
  parameter Real d_v = 2.0 "linear velocity damping (N.s/m) assumption";
  parameter Real d_omega = 2.0 "yaw damping (N.m.s/rad) assumption";
  parameter Real routeRadius = 1.2 "bounded circular route radius (m) assumption";
  parameter Real routeOmega = 0.5 "bounded route angular rate (rad/s) assumption";

  // Sensor rates (explicitly different)
  parameter Real f_imu = 80.0 "IMU rate (Hz)";
  parameter Real f_enc = 40.0 "wheel encoder rate (Hz)";
  parameter Real f_lidar = 20.0 "lidar rate (Hz)";
  parameter Real f_rgbd = 10.0 "RGB-D camera rate (Hz)";
  parameter Real T_imu = 1.0/f_imu "IMU sample period (s)";
  parameter Real T_enc = 1.0/f_enc "encoder sample period (s)";
  parameter Real T_lidar = 1.0/f_lidar "lidar sample period (s)";
  parameter Real T_rgbd = 1.0/f_rgbd "RGB-D sample period (s)";

  // Bias disturbance window (middle third)
  parameter Real tBiasStart = tEnd/3.0;
  parameter Real tBiasEnd = 2.0*tEnd/3.0;

  // Sensor frame transforms (m, rad) relative to base frame B
  parameter Real imu_x = 0.0 "IMU frame translation x (m)";
  parameter Real imu_y = 0.0 "IMU frame translation y (m)";
  parameter Real imu_theta = 0.0 "IMU frame rotation (rad)";
  parameter Real lidar_x = 0.15 "lidar frame L translation x (m) assumption";
  parameter Real lidar_y = 0.0 "lidar frame L translation y (m) assumption";
  parameter Real lidar_theta = 0.0 "lidar frame L rotation (rad) assumption";
  parameter Real cam_x = 0.10 "forward RGB-D frame C translation x (m) assumption";
  parameter Real cam_y = 0.0 "forward RGB-D frame C translation y (m) assumption";
  parameter Real cam_theta = 0.0 "forward RGB-D frame C rotation (rad) assumption";
  parameter Real camDepth = 5.0 "RGB-D depth limit (m) assumption";
  parameter Real camFOV = 1.0 "RGB-D half field of view (rad) assumption";

  // Sensor standard deviations
  parameter Real sigma_imu_gyro = 0.01 "IMU gyro std (rad/s)";
  parameter Real sigma_imu_accel = 0.05 "IMU accel std (m/s^2)";
  parameter Real sigma_enc_v = 0.03 "encoder linear velocity std (m/s)";
  parameter Real sigma_enc_omega = 0.02 "encoder angular velocity std (rad/s)";
  parameter Real sigma_lidar_range = 0.05 "lidar range std (m)";
  parameter Real sigma_lidar_bearing = 0.02 "lidar bearing std (rad)";
  parameter Real sigma_rgbd_x = 0.08 "RGB-D forward coordinate std (m)";
  parameter Real sigma_rgbd_y = 0.06 "RGB-D lateral coordinate std (m)";

  // True sensor bias baselines
  parameter Real b_gyro_base = 0.0 "true IMU gyro bias baseline (rad/s)";
  parameter Real b_accel_true = 0.0 "true IMU accel bias (m/s^2)";
  parameter Real b_enc_true = 0.0 "true encoder additive bias (m/s)";

  // Fixed external landmarks (map known to estimator, not ground-truth pose)
  parameter Real LM_x[3] = {1.2, -1.2, -1.2} "landmark x positions (m) assumption";
  parameter Real LM_y[3] = {1.2, 1.2, -1.2} "landmark y positions (m) assumption";

  // EKF covariance initialization and process noise
  parameter Real P0diag[8] = {0.04, 0.04, 0.01, 0.04, 0.01, 1.0e-4, 1.0e-4, 1.0e-4};
  parameter Real Qdiag[8] = {1.0e-5, 1.0e-5, 1.0e-5, 1.0e-4, 1.0e-4, 1.0e-5, 1.0e-5, 1.0e-5};

  final parameter Real Pstart[8,8] = {
    {P0diag[1],0.0,0.0,0.0,0.0,0.0,0.0,0.0},
    {0.0,P0diag[2],0.0,0.0,0.0,0.0,0.0,0.0},
    {0.0,0.0,P0diag[3],0.0,0.0,0.0,0.0,0.0},
    {0.0,0.0,0.0,P0diag[4],0.0,0.0,0.0,0.0},
    {0.0,0.0,0.0,0.0,P0diag[5],0.0,0.0,0.0},
    {0.0,0.0,0.0,0.0,0.0,P0diag[6],0.0,0.0},
    {0.0,0.0,0.0,0.0,0.0,0.0,P0diag[7],0.0},
    {0.0,0.0,0.0,0.0,0.0,0.0,0.0,P0diag[8]}
  } "initial covariance diagonal";

  // True plant state
  Real x(start=1.2) "true world x (m)";
  Real y(start=0.0) "true world y (m)";
  Real theta(start=pi/2) "true heading (rad)";
  Real v(start=0.0) "true forward speed (m/s)";
  Real omega(start=0.0) "true yaw rate (rad/s)";
  Real a_true "true forward acceleration (m/s^2)";
  Real F_drive "total drive force (N)";
  Real M_drive "drive yaw moment (N.m)";

  // Controller references and commands
  Real x_ref "route x reference (m)";
  Real y_ref "route y reference (m)";
  Real theta_ref "route heading reference (rad)";
  Real v_ref "route speed reference (m/s)";
  Real omega_ref "route yaw rate reference (rad/s)";
  Real e_theta "heading tracking error (rad)";
  Real e_forward "forward tracking error (m)";
  Real e_lateral "lateral tracking error (m)";
  Real v_cmd "commanded forward speed (m/s)";
  Real omega_cmd "commanded yaw rate (rad/s)";
  Real F_cmd "commanded drive force (N)";
  Real M_cmd "commanded yaw moment (N.m)";
  output Real tauR "right wheel torque (N.m)";
  output Real tauL "left wheel torque (N.m)";

  // True bias disturbance
  Real b_gyro_true "true IMU gyro bias including step (rad/s)";

  // Estimator state (discrete 8-state EKF: x, y, theta, v, omega, b_gyro, b_accel, b_enc)
  output Real xh(start=1.2) "estimated x (m)";
  output Real yh(start=0.0) "estimated y (m)";
  output Real thetah(start=pi/2) "estimated heading (rad)";
  output Real vh(start=0.0) "estimated forward speed (m/s)";
  output Real omegah(start=0.0) "estimated yaw rate (rad/s)";
  output Real b_gyro_h(start=0.0) "estimated gyro bias (rad/s)";
  discrete Real b_accel_h(start=0.0) "estimated accel bias (m/s^2)";
  discrete Real b_enc_h(start=0.0) "estimated encoder bias (m/s)";
  discrete Real P[8,8](start=Pstart) "estimator covariance";

  // Sensor measurements and timestamps (asynchronous, with frames)
  discrete Real z_gyro(start=0.0) "IMU gyro measurement (rad/s)";
  discrete Real z_ax(start=0.0) "IMU forward accel measurement (m/s^2)";
  discrete Real t_imu(start=0.0) "last IMU timestamp (s)";
  discrete Real z_enc_v(start=0.0) "encoder linear velocity measurement (m/s)";
  discrete Real z_enc_omega(start=0.0) "encoder angular velocity measurement (rad/s)";
  discrete Real t_enc(start=0.0) "last encoder timestamp (s)";
  discrete Real z_lidar_range[3](start={0.0,0.0,0.0}) "lidar range measurements (m)";
  discrete Real z_lidar_bearing[3](start={0.0,0.0,0.0}) "lidar bearing measurements (rad)";
  discrete Real t_lidar(start=0.0) "last lidar timestamp (s)";
  discrete Real z_rgbd_x(start=0.0) "RGB-D forward coordinate measurement (m)";
  discrete Real z_rgbd_y(start=0.0) "RGB-D lateral coordinate measurement (m)";
  discrete Real t_rgbd(start=0.0) "last RGB-D timestamp (s)";

  // Error metrics and bands
  output Real trackErr "primary tracking error (m+rad)";
  Real posErrEst "estimator position error (m)";
  Real attErrEst "estimator attitude error (rad)";
  output Real posErrBand(start=0.0) "3-sigma position error band (m)";
  output Real attErrBand(start=0.0) "3-sigma attitude error band (rad)";
  output Real biasErr(start=0.0) "gyro bias estimation error (rad/s)";

  // Discrete temporaries for EKF computation
  discrete Real Ppre[8,8];
  discrete Real Pp[8,8];
  discrete Real Fm[8,8];
  discrete Real xv[8];
  discrete Real xold[8];
  discrete Real H[8];
  discrete Real innov;
  discrete Real Rmes;
  discrete Real dt;
  discrete Real dt_enc;
  discrete Real a_enc;
  discrete Real dx;
  discrete Real dy;
  discrete Real r;
  discrete Real phi;
  discrete Real xs;
  discrete Real ys;
  discrete Real ths;
  discrete Real dx_h;
  discrete Real dy_h;
  discrete Real r_h;
  discrete Real phi_h;
  discrete Real rSafe_h;
  discrete Real hx;
  discrete Real hy;
  discrete Real hx_true;
  discrete Real hy_true;
  discrete Real r_cam;
  discrete Boolean encUpdate;
  discrete Boolean lidarUpdate;
  discrete Boolean rgbdUpdate;
  discrete Integer k(start=0);

  function ekfScalarUpdate
    "Scalar Kalman update for one measurement; returns updated state and covariance"
    input Real x_in[8];
    input Real P_in[8,8];
    input Real H_in[8];
    input Real innov_in;
    input Real R_in;
    output Real x_out[8];
    output Real P_out[8,8];
  protected
    Real S;
    Real Kvec[8];
    Real PHt[8];
    Real HP[8];
  algorithm
    S := R_in;
    for i in 1:8 loop
      for j in 1:8 loop
        S := S + H_in[i]*P_in[i,j]*H_in[j];
      end for;
    end for;
    S := max(S, 1.0e-12);
    for i in 1:8 loop
      PHt[i] := 0.0;
      for j in 1:8 loop
        PHt[i] := PHt[i] + P_in[i,j]*H_in[j];
      end for;
      Kvec[i] := PHt[i]/S;
    end for;
    for i in 1:8 loop
      x_out[i] := x_in[i] + Kvec[i]*innov_in;
    end for;
    for j in 1:8 loop
      HP[j] := 0.0;
      for i in 1:8 loop
        HP[j] := HP[j] + H_in[i]*P_in[i,j];
      end for;
    end for;
    for i in 1:8 loop
      for j in 1:8 loop
        P_out[i,j] := P_in[i,j] - Kvec[i]*HP[j];
      end for;
    end for;
    for i in 1:8 loop
      for j in 1:8 loop
        P_out[i,j] := 0.5*(P_out[i,j] + P_out[j,i]);
      end for;
    end for;
    for i in 1:8 loop
      P_out[i,i] := max(P_out[i,i], 1.0e-9);
    end for;
  end ekfScalarUpdate;

equation
  // Bounded mapping route (circular)
  x_ref = routeRadius*cos(routeOmega*time);
  y_ref = routeRadius*sin(routeOmega*time);
  theta_ref = routeOmega*time + pi/2;
  v_ref = routeRadius*routeOmega;
  omega_ref = routeOmega;

  // True planar dynamics
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  a_true = (F_drive - d_v*v)/m_base;
  der(v) = a_true;
  der(omega) = (M_drive - d_omega*omega)/J_base;
  F_drive = (tauR + tauL)/wheelRadius;
  M_drive = (tauR - tauL)*wheelBase/(2.0*wheelRadius);

  // Trajectory tracking controller using estimator state only
  e_theta = atan2(sin(theta_ref - thetah), cos(theta_ref - thetah));
  e_forward = cos(thetah)*(x_ref - xh) + sin(thetah)*(y_ref - yh);
  e_lateral = -sin(thetah)*(x_ref - xh) + cos(thetah)*(y_ref - yh);
  v_cmd = v_ref + 2.0*e_forward;
  omega_cmd = omega_ref + 1.0*e_lateral/max(v_ref, 0.1) + 2.0*e_theta;
  F_cmd = 20.0*(v_cmd - vh) + d_v*v_cmd;
  M_cmd = 10.0*(omega_cmd - omegah) + d_omega*omega_cmd;
  tauR = max(-tauMax, min(tauMax, 0.5*F_cmd*wheelRadius + M_cmd*wheelRadius/wheelBase));
  tauL = max(-tauMax, min(tauMax, 0.5*F_cmd*wheelRadius - M_cmd*wheelRadius/wheelBase));

  // Controlled gyro bias step during middle third of scenario
  b_gyro_true = if time >= tBiasStart and time < tBiasEnd then biasStep else 0.0;

  // Verification metrics
  trackErr = sqrt((x_ref - x)^2 + (y_ref - y)^2) + abs(atan2(sin(theta_ref - theta), cos(theta_ref - theta)));
  posErrEst = sqrt((x - xh)^2 + (y - yh)^2);
  attErrEst = abs(atan2(sin(theta - thetah), cos(theta - thetah)));

algorithm
  when sample(0, T_base) then
    k := pre(k) + 1;
    dt := max(time - pre(t_imu), 1.0e-6);

    // IMU at 80 Hz, base frame B (imu_x, imu_y, imu_theta = 0)
    z_gyro := omega + b_gyro_true + sigma_imu_gyro*sqrt(2.0)*sin(2.0*pi*13.0*time + 0.1);
    z_ax := a_true + b_accel_true + sigma_imu_accel*sqrt(2.0)*sin(2.0*pi*17.0*time + 0.2);
    t_imu := time;

    // Load previous estimator state and covariance
    xold[1] := pre(xh);
    xold[2] := pre(yh);
    xold[3] := pre(thetah);
    xold[4] := pre(vh);
    xold[5] := pre(omegah);
    xold[6] := pre(b_gyro_h);
    xold[7] := pre(b_accel_h);
    xold[8] := pre(b_enc_h);
    for i in 1:8 loop
      for j in 1:8 loop
        Ppre[i,j] := pre(P[i,j]);
      end for;
    end for;

    // EKF state-transition Jacobian F
    for i in 1:8 loop
      for j in 1:8 loop
        Fm[i,j] := 0.0;
      end for;
      Fm[i,i] := 1.0;
    end for;
    Fm[1,3] := -xold[4]*sin(xold[3])*dt;
    Fm[1,4] := cos(xold[3])*dt;
    Fm[2,3] := xold[4]*cos(xold[3])*dt;
    Fm[2,4] := sin(xold[3])*dt;
    Fm[3,6] := -dt;
    Fm[4,7] := -dt;
    Fm[5,5] := 0.0;
    Fm[5,6] := -1.0;

    // Covariance prediction: Pp = F * Ppre * F^T + Q
    for i in 1:8 loop
      for j in 1:8 loop
        Pp[i,j] := if i == j then Qdiag[i] else 0.0;
        for kk in 1:8 loop
          for ll in 1:8 loop
            Pp[i,j] := Pp[i,j] + Fm[i,kk]*Ppre[kk,ll]*Fm[j,ll];
          end for;
        end for;
      end for;
    end for;

    // State prediction using IMU (z_gyro, z_ax)
    xv[1] := xold[1] + xold[4]*cos(xold[3])*dt;
    xv[2] := xold[2] + xold[4]*sin(xold[3])*dt;
    xv[3] := xold[3] + (z_gyro - xold[6])*dt;
    xv[4] := xold[4] + (z_ax - xold[7])*dt;
    xv[5] := z_gyro - xold[6];
    xv[6] := xold[6];
    xv[7] := xold[7];
    xv[8] := xold[8];

    // Asynchronous wheel encoder update at 40 Hz
    encUpdate := mod(k, 2) == 0;
    if encUpdate then
      dt_enc := max(time - pre(t_enc), 1.0e-6);
      z_enc_v := v + b_enc_true + sigma_enc_v*sqrt(2.0)*sin(2.0*pi*23.0*time + 0.3);
      z_enc_omega := omega + sigma_enc_omega*sqrt(2.0)*sin(2.0*pi*29.0*time + 0.4);
      t_enc := time;

      // Linear velocity + encoder bias update
      H[1] := 0.0; H[2] := 0.0; H[3] := 0.0; H[4] := 1.0;
      H[5] := 0.0; H[6] := 0.0; H[7] := 0.0; H[8] := 1.0;
      innov := z_enc_v - (xv[4] + xv[8]);
      Rmes := sigma_enc_v*sigma_enc_v;
      (xv, Pp) := ekfScalarUpdate(xv, Pp, H, innov, Rmes);

      // Angular velocity update
      H[1] := 0.0; H[2] := 0.0; H[3] := 0.0; H[4] := 0.0;
      H[5] := 1.0; H[6] := 0.0; H[7] := 0.0; H[8] := 0.0;
      innov := z_enc_omega - xv[5];
      Rmes := sigma_enc_omega*sigma_enc_omega;
      (xv, Pp) := ekfScalarUpdate(xv, Pp, H, innov, Rmes);

      // Accelerometer bias update from encoder-derived acceleration
      if pre(t_enc) > 0.0 then
        a_enc := (z_enc_v - pre(z_enc_v))/dt_enc;
        H[1] := 0.0; H[2] := 0.0; H[3] := 0.0; H[4] := 0.0;
        H[5] := 0.0; H[6] := 0.0; H[7] := 1.0; H[8] := 0.0;
        innov := a_enc - (z_ax - xv[7]);
        Rmes := 0.1;
        (xv, Pp) := ekfScalarUpdate(xv, Pp, H, innov, Rmes);
      end if;
    end if;

    // Asynchronous lidar update at 20 Hz, frame L (lidar_x, lidar_y, lidar_theta)
    lidarUpdate := mod(k, 4) == 0;
    if lidarUpdate then
      for i in 1:3 loop
        // True lidar measurement from frame L
        xs := x + lidar_x*cos(theta) - lidar_y*sin(theta);
        ys := y + lidar_x*sin(theta) + lidar_y*cos(theta);
        ths := theta + lidar_theta;
        dx := LM_x[i] - xs;
        dy := LM_y[i] - ys;
        r := sqrt(dx*dx + dy*dy);
        phi := atan2(dy, dx) - ths;
        z_lidar_range[i] := r + sigma_lidar_range*sqrt(2.0)*sin(2.0*pi*31.0*time + i);
        z_lidar_bearing[i] := phi + sigma_lidar_bearing*sqrt(2.0)*sin(2.0*pi*37.0*time + i);

        // Estimated lidar prediction from frame L
        xs := xv[1] + lidar_x*cos(xv[3]) - lidar_y*sin(xv[3]);
        ys := xv[2] + lidar_x*sin(xv[3]) + lidar_y*cos(xv[3]);
        ths := xv[3] + lidar_theta;
        dx_h := LM_x[i] - xs;
        dy_h := LM_y[i] - ys;
        r_h := sqrt(dx_h*dx_h + dy_h*dy_h);
        rSafe_h := max(r_h, 0.1);
        phi_h := atan2(dy_h, dx_h) - ths;

        if r <= LidarRange then
          // Range update
          H[1] := -dx_h/rSafe_h;
          H[2] := -dy_h/rSafe_h;
          H[3] := lidar_x*(dx_h*sin(xv[3]) - dy_h*cos(xv[3]))/rSafe_h;
          H[4] := 0.0; H[5] := 0.0; H[6] := 0.0; H[7] := 0.0; H[8] := 0.0;
          innov := z_lidar_range[i] - r_h;
          Rmes := sigma_lidar_range*sigma_lidar_range;
          (xv, Pp) := ekfScalarUpdate(xv, Pp, H, innov, Rmes);

          // Bearing update
          H[1] := dy_h/(rSafe_h*rSafe_h);
          H[2] := -dx_h/(rSafe_h*rSafe_h);
          H[3] := -1.0 - lidar_x*(dy_h*sin(xv[3]) + dx_h*cos(xv[3]))/(rSafe_h*rSafe_h);
          H[4] := 0.0; H[5] := 0.0; H[6] := 0.0; H[7] := 0.0; H[8] := 0.0;
          innov := atan2(sin(z_lidar_bearing[i] - phi_h), cos(z_lidar_bearing[i] - phi_h));
          Rmes := sigma_lidar_bearing*sigma_lidar_bearing;
          (xv, Pp) := ekfScalarUpdate(xv, Pp, H, innov, Rmes);
        end if;
      end for;
      t_lidar := time;
    end if;

    // Asynchronous RGB-D update at 10 Hz, forward frame C (cam_x, cam_y, cam_theta)
    rgbdUpdate := mod(k, 8) == 0;
    if rgbdUpdate then
      for i in 1:3 loop
        xs := x + cam_x*cos(theta) - cam_y*sin(theta);
        ys := y + cam_x*sin(theta) + cam_y*cos(theta);
        ths := theta + cam_theta;
        dx := LM_x[i] - xs;
        dy := LM_y[i] - ys;
        hx_true := cos(ths)*dx + sin(ths)*dy;
        hy_true := -sin(ths)*dx + cos(ths)*dy;
        r_cam := sqrt(hx_true*hx_true + hy_true*hy_true);

        if hx_true > 0.1 and abs(atan2(hy_true, hx_true)) < camFOV and r_cam <= camDepth then
          z_rgbd_x := hx_true + sigma_rgbd_x*sqrt(2.0)*sin(2.0*pi*41.0*time + i);
          z_rgbd_y := hy_true + sigma_rgbd_y*sqrt(2.0)*sin(2.0*pi*43.0*time + i);
          t_rgbd := time;

          xs := xv[1] + cam_x*cos(xv[3]) - cam_y*sin(xv[3]);
          ys := xv[2] + cam_x*sin(xv[3]) + cam_y*cos(xv[3]);
          ths := xv[3] + cam_theta;
          dx_h := LM_x[i] - xs;
          dy_h := LM_y[i] - ys;
          hx := cos(ths)*dx_h + sin(ths)*dy_h;
          hy := -sin(ths)*dx_h + cos(ths)*dy_h;

          // Forward coordinate update
          H[1] := -cos(ths);
          H[2] := -sin(ths);
          H[3] := hy;
          H[4] := 0.0; H[5] := 0.0; H[6] := 0.0; H[7] := 0.0; H[8] := 0.0;
          innov := z_rgbd_x - hx;
          Rmes := sigma_rgbd_x*sigma_rgbd_x;
          (xv, Pp) := ekfScalarUpdate(xv, Pp, H, innov, Rmes);

          // Lateral coordinate update
          H[1] := sin(ths);
          H[2] := -cos(ths);
          H[3] := -hx - cam_x;
          H[4] := 0.0; H[5] := 0.0; H[6] := 0.0; H[7] := 0.0; H[8] := 0.0;
          innov := z_rgbd_y - hy;
          Rmes := sigma_rgbd_y*sigma_rgbd_y;
          (xv, Pp) := ekfScalarUpdate(xv, Pp, H, innov, Rmes);
        end if;
      end for;
    end if;

    // Bound bias estimates for numerical safety
    xv[6] := max(-0.1, min(0.1, xv[6]));
    xv[7] := max(-1.0, min(1.0, xv[7]));
    xv[8] := max(-0.5, min(0.5, xv[8]));

    // Commit estimator state and covariance
    xh := xv[1];
    yh := xv[2];
    thetah := xv[3];
    vh := xv[4];
    omegah := xv[5];
    b_gyro_h := xv[6];
    b_accel_h := xv[7];
    b_enc_h := xv[8];
    P := Pp;

    // Finite positive covariance bands and bias convergence metric
    posErrBand := 3.0*sqrt(max(P[1,1] + P[2,2], 1.0e-9));
    attErrBand := 3.0*sqrt(max(P[3,3], 1.0e-9));
    biasErr := abs(b_gyro_true - b_gyro_h);

  end when;

  annotation(experiment(StopTime=8, Interval=0.0125));
end MapRigLocalizeA;