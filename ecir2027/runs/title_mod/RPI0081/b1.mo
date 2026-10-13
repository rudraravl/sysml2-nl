model DuctInspectSurveyC
  // Physical constants
  parameter Real m = 2.7 "kg";
  parameter Real g = 9.81 "m/s2";

  // Survey timing and waypoints
  parameter Real Ts = 1/125 "s controller and sensor period";
  parameter Real t0 = 0.0 "s";
  parameter Real t1 = 4.0 "s declared deadline for waypoint 2";
  parameter Real t2 = 8.0 "s declared deadline for waypoint 3";
  parameter Real t3 = 12.0 "s declared deadline for waypoint 4";
  parameter Real dt01 = t1 - t0 "s";
  parameter Real dt12 = t2 - t1 "s";
  parameter Real dt23 = t3 - t2 "s";

  parameter Real wx0 = 0.0 "m";
  parameter Real wy0 = 0.0 "m";
  parameter Real wz0 = 1.5 "m";
  parameter Real wx1 = 4.0 "m";
  parameter Real wy1 = 0.0 "m";
  parameter Real wz1 = 2.5 "m";
  parameter Real wx2 = 4.0 "m";
  parameter Real wy2 = 3.0 "m";
  parameter Real wz2 = 2.5 "m";
  parameter Real wx3 = 1.0 "m";
  parameter Real wy3 = 4.0 "m";
  parameter Real wz3 = 2.0 "m";

  // Actuator bounds
  parameter Real Fmax = 16.6 "N per fan";
  // Probe-force bound was not specified in request; placeholder used
  parameter Real Fprobe_max = 10.0 "N placeholder bound";

  // Body and fan geometry: unspecified by request; placeholder SI values used
  parameter Real r_body = 0.15 "m";
  parameter Real h_body = 0.30 "m";
  parameter Real d_fan = 0.25 "m fan arm radius";
  parameter Real kappa_fan = 0.10 "N.m/N yaw torque coefficient";
  parameter Real Ixx = m*(3*r_body*r_body + h_body*h_body)/12 "kg.m2";
  parameter Real Iyy = Ixx "kg.m2";
  parameter Real Izz = m*r_body*r_body/2 "kg.m2";

  // Probe compliance: unspecified by request; placeholder SI values used
  parameter Real L_probe = 0.18 "m";
  parameter Real k_probe = 200.0 "N/m";
  parameter Real tau_probe = 0.05 "s actuator time constant";

  // Control gains
  parameter Real Kp_pos = 10.0 "1/s2";
  parameter Real Kd_pos = 7.0 "1/s";
  parameter Real Kphi = 15.0 "N.m/rad";
  parameter Real Ktheta = 15.0 "N.m/rad";
  parameter Real Kp_ang = 3.0 "N.m.s/rad";
  parameter Real Kpsi = 5.0 "N.m/rad";
  parameter Real Kr_ang = 2.5 "N.m.s/rad";
  parameter Real phi_max = 0.35 "rad placeholder attitude bound";
  parameter Real theta_max = 0.35 "rad placeholder attitude bound";
  parameter Real psi_max = 0.35 "rad placeholder attitude bound";

  // Estimator gain
  parameter Real Kf = 0.7;

  // Obstacles: fixed cylinders placed outside the reference polyline
  parameter Real obs1_x = 6.0 "m";
  parameter Real obs1_y = 1.0 "m";
  parameter Real obs1_r = 0.5 "m";
  parameter Real obs1_z0 = 0.0 "m";
  parameter Real obs1_z1 = 3.0 "m";
  parameter Real obs2_x = 2.0 "m";
  parameter Real obs2_y = -1.0 "m";
  parameter Real obs2_r = 0.5 "m";
  parameter Real obs2_z0 = 0.0 "m";
  parameter Real obs2_z1 = 3.0 "m";
  parameter Real obs3_x = -1.0 "m";
  parameter Real obs3_y = 3.0 "m";
  parameter Real obs3_r = 0.5 "m";
  parameter Real obs3_z0 = 0.0 "m";
  parameter Real obs3_z1 = 3.0 "m";

  parameter Real eps = 1e-9;

  // Continuous states (also outputs)
  Real x(start=0.0, fixed=true) "m";
  Real y(start=0.0, fixed=true) "m";
  Real z(start=1.5, fixed=true) "m";
  Real vx(start=0.0, fixed=true) "m/s";
  Real vy(start=0.0, fixed=true) "m/s";
  Real vz(start=0.0, fixed=true) "m/s";
  Real phi(start=0.0, fixed=true) "rad roll";
  Real theta(start=0.0, fixed=true) "rad pitch";
  Real psi(start=0.0, fixed=true) "rad yaw";
  Real p_rate(start=0.0, fixed=true) "rad/s";
  Real q_rate(start=0.0, fixed=true) "rad/s";
  Real r_rate(start=0.0, fixed=true) "rad/s";
  Real Fp(start=0.0, fixed=true) "N probe force state";

  // Discrete controller and sensor variables
  discrete Real u1(start=m*g/4.0, fixed=true) "N";
  discrete Real u2(start=m*g/4.0, fixed=true) "N";
  discrete Real u3(start=m*g/4.0, fixed=true) "N";
  discrete Real u4(start=m*g/4.0, fixed=true) "N";
  discrete Real Fp_cmd(start=0.0, fixed=true) "N";
  discrete Real T_cmd(start=m*g, fixed=true) "N";
  discrete Real phi_cmd(start=0.0, fixed=true) "rad";
  discrete Real theta_cmd(start=0.0, fixed=true) "rad";
  discrete Real psi_cmd(start=0.0, fixed=true) "rad";

  // Raw sensor discrete variables
  discrete Real t_imu(start=0.0, fixed=true) "s";
  discrete Real t_gps(start=0.0, fixed=true) "s";
  discrete Real t_alt(start=0.0, fixed=true) "s";
  discrete Real t_camera(start=0.0, fixed=true) "s";
  discrete Real gps_x(start=0.0, fixed=true) "m";
  discrete Real gps_y(start=0.0, fixed=true) "m";
  discrete Real gps_z(start=1.5, fixed=true) "m";
  discrete Real alt_z(start=1.5, fixed=true) "m";
  discrete Real camera_x(start=0.0, fixed=true) "m";
  discrete Real camera_y(start=0.0, fixed=true) "m";
  discrete Real camera_z(start=1.5, fixed=true) "m";
  discrete Real imu_ax(start=0.0, fixed=true) "m/s2";
  discrete Real imu_ay(start=0.0, fixed=true) "m/s2";
  discrete Real imu_az(start=0.0, fixed=true) "m/s2";

  // Fused estimates
  discrete Real x_hat(start=0.0, fixed=true) "m";
  discrete Real y_hat(start=0.0, fixed=true) "m";
  discrete Real z_hat(start=1.5, fixed=true) "m";
  discrete Real vx_hat(start=0.0, fixed=true) "m/s";
  discrete Real vy_hat(start=0.0, fixed=true) "m/s";
  discrete Real vz_hat(start=0.0, fixed=true) "m/s";

  // Output variables
  output Real out_x = x "m";
  output Real out_y = y "m";
  output Real out_z = z "m";
  output Real out_vx = vx "m/s";
  output Real out_vy = vy "m/s";
  output Real out_vz = vz "m/s";
  output Real out_phi = phi "rad";
  output Real out_theta = theta "rad";
  output Real out_psi = psi "rad";
  output Real refX "m";
  output Real refY "m";
  output Real refZ "m";
  output Real refVx "m/s";
  output Real refVy "m/s";
  output Real refVz "m/s";
  output Real refAx "m/s2";
  output Real refAy "m/s2";
  output Real refAz "m/s2";
  output Real estX = x_hat "m";
  output Real estY = y_hat "m";
  output Real estZ = z_hat "m";
  output Real estVx = vx_hat "m/s";
  output Real estVy = vy_hat "m/s";
  output Real estVz = vz_hat "m/s";
  output Real fan1Thrust = u1 "N";
  output Real fan2Thrust = u2 "N";
  output Real fan3Thrust = u3 "N";
  output Real fan4Thrust = u4 "N";
  output Real probeForceCmd = Fp_cmd "N";
  output Real probeForce = Fp "N";
  output Real totalThrust "N";
  output Real commandThrust = T_cmd "N";
  output Real commandRoll = phi_cmd "rad";
  output Real commandPitch = theta_cmd "rad";
  output Real commandYaw = psi_cmd "rad";
  output Real crosswindDisturbance "N";
  output Real probeTipX "m";
  output Real probeTipY "m";
  output Real probeTipZ "m";
  output Real imuTime = t_imu "s";
  output Real gpsTime = t_gps "s";
  output Real altTime = t_alt "s";
  output Real cameraTime = t_camera "s";
  output Real imuAccX = imu_ax "m/s2";
  output Real imuAccY = imu_ay "m/s2";
  output Real imuAccZ = imu_az "m/s2";
  output Real gpsX = gps_x "m";
  output Real gpsY = gps_y "m";
  output Real gpsZ = gps_z "m";
  output Real altZ = alt_z "m";
  output Real primaryError "m";
  output Real noCollisionFlag;
  output Real thrustBoundOk;
  output Real attitudeBoundOk;
  output Real probeBoundOk;
  output Real boundsOk;
  output Real physicalFinite;
  output Real controlFinite;
  output Real estimatorFinite;
  output Real allFinite;
  output Real trackingOk;
  output Real sensorSynchronized;

protected
  Real cphi, sphi, ctheta, stheta, cpsi, spsi;
  Real body_z_x, body_z_y, body_z_z, body_x_x, body_x_y, body_x_z;
  Real T, Fdist_x, ax, ay, az;
  Real tau_x, tau_y, tau_z;
  Real rx, ry, rz, vrx, vry, vrz, arx, ary, arz;
  Real alpha01, alpha12, alpha23, s01, s12, s23, sd01, sd12, sd23, sdd01, sdd12, sdd23;
  Real tip_x, tip_y, tip_z;
  Real e_probe;
  Real collision1, collision2, collision3;
  Real physical_finite, control_finite, estimator_finite;
  Real thrust_bound_ok, attitude_bound_ok, probe_bound_ok;

  discrete Real u1_raw(start=m*g/4.0, fixed=true) "N";
  discrete Real u2_raw(start=m*g/4.0, fixed=true) "N";
  discrete Real u3_raw(start=m*g/4.0, fixed=true) "N";
  discrete Real u4_raw(start=m*g/4.0, fixed=true) "N";
  discrete Real Fdes_x(start=0.0, fixed=true) "N";
  discrete Real Fdes_y(start=0.0, fixed=true) "N";
  discrete Real Fdes_z(start=0.0, fixed=true) "N";
  discrete Real Tnorm(start=m*g, fixed=true) "N";
  discrete Real zx_cmd(start=0.0, fixed=true);
  discrete Real zy_cmd(start=0.0, fixed=true);
  discrete Real zz_cmd(start=1.0, fixed=true);
  discrete Real A_cmd(start=0.0, fixed=true);
  discrete Real sphi_cmd(start=0.0, fixed=true);
  discrete Real theta_cmd_raw(start=0.0, fixed=true) "rad";
  discrete Real phi_cmd_raw(start=0.0, fixed=true) "rad";
  discrete Real tau_x_cmd(start=0.0, fixed=true) "N.m";
  discrete Real tau_y_cmd(start=0.0, fixed=true) "N.m";
  discrete Real tau_z_cmd(start=0.0, fixed=true) "N.m";
  discrete Real vx_gps(start=0.0, fixed=true) "m/s";
  discrete Real vy_gps(start=0.0, fixed=true) "m/s";
  discrete Real vz_gps(start=0.0, fixed=true) "m/s";
  discrete Real vx_pred(start=0.0, fixed=true) "m/s";
  discrete Real vy_pred(start=0.0, fixed=true) "m/s";
  discrete Real vz_pred(start=0.0, fixed=true) "m/s";

equation
  // Rigid-body translational dynamics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  // Simplified attitude kinematics for small tilts
  der(phi) = p_rate;
  der(theta) = q_rate;
  der(psi) = r_rate;
  der(p_rate) = tau_x/Ixx;
  der(q_rate) = tau_y/Iyy;
  der(r_rate) = tau_z/Izz;

  // Probe force first-order actuator dynamics
  der(Fp) = (Fp_cmd - Fp)/tau_probe;
  e_probe = Fp/k_probe;

  // Body-frame axes
  cphi = cos(phi);
  sphi = sin(phi);
  ctheta = cos(theta);
  stheta = sin(theta);
  cpsi = cos(psi);
  spsi = sin(psi);
  body_z_x = cpsi*stheta*cphi + spsi*sphi;
  body_z_y = spsi*stheta*cphi - cpsi*sphi;
  body_z_z = ctheta*cphi;
  body_x_x = cpsi*ctheta;
  body_x_y = spsi*ctheta;
  body_x_z = -stheta;

  // Fan thrust summation and torque mixing
  T = u1 + u2 + u3 + u4;
  tau_x = d_fan*(u1 + u2 - u3 - u4);
  tau_y = d_fan*(-u1 + u2 + u3 - u4);
  tau_z = kappa_fan*(-u1 + u2 - u3 + u4);

  // Probe tip position
  tip_x = x + (L_probe + e_probe)*body_x_x;
  tip_y = y + (L_probe + e_probe)*body_x_y;
  tip_z = z + (L_probe + e_probe)*body_x_z;

  // Disturbance: 5.4 N crosswind during middle third of 12 s run
  Fdist_x = if time >= t1 and time < t2 then 5.4 else 0.0;
  crosswindDisturbance = Fdist_x;

  // Acceleration
  ax = T/m*body_z_x + Fdist_x/m + Fp*body_x_x;
  ay = T/m*body_z_y + Fp*body_x_y;
  az = T/m*body_z_z - g + Fp*body_x_z;

  // Quintic waypoint schedule with feedforward acceleration
  alpha01 = if time < t1 then time/dt01 else 1.0;
  alpha12 = if time >= t1 and time < t2 then (time - t1)/dt12 elseif time >= t2 then 1.0 else 0.0;
  alpha23 = if time >= t2 and time < t3 then (time - t2)/dt23 elseif time >= t3 then 1.0 else 0.0;

  s01 = 10.0*alpha01*alpha01*alpha01 - 15.0*alpha01^4 + 6.0*alpha01^5;
  s12 = 10.0*alpha12*alpha12*alpha12 - 15.0*alpha12^4 + 6.0*alpha12^5;
  s23 = 10.0*alpha23*alpha23*alpha23 - 15.0*alpha23^4 + 6.0*alpha23^5;

  sd01 = (30.0*alpha01*alpha01 - 60.0*alpha01^3 + 30.0*alpha01^4)/dt01;
  sd12 = (30.0*alpha12*alpha12 - 60.0*alpha12^3 + 30.0*alpha12^4)/dt12;
  sd23 = (30.0*alpha23*alpha23 - 60.0*alpha23^3 + 30.0*alpha23^4)/dt23;

  sdd01 = (60.0*alpha01 - 180.0*alpha01*alpha01 + 120.0*alpha01^3)/(dt01*dt01);
  sdd12 = (60.0*alpha12 - 180.0*alpha12*alpha12 + 120.0*alpha12^3)/(dt12*dt12);
  sdd23 = (60.0*alpha23 - 180.0*alpha23*alpha23 + 120.0*alpha23^3)/(dt23*dt23);

  rx = if time < t1 then wx0 + s01*(wx1 - wx0) elseif time < t2 then wx1 + s12*(wx2 - wx1) elseif time < t3 then wx2 + s23*(wx3 - wx2) else wx3;
  ry = if time < t1 then wy0 + s01*(wy1 - wy0) elseif time < t2 then wy1 + s12*(wy2 - wy1) elseif time < t3 then wy2 + s23*(wy3 - wy2) else wy3;
  rz = if time < t1 then wz0 + s01*(wz1 - wz0) elseif time < t2 then wz1 + s12*(wz2 - wz1) elseif time < t3 then wz2 + s23*(wz3 - wz2) else wz3;

  vrx = if time < t1 then sd01*(wx1 - wx0) elseif time < t2 then sd12*(wx2 - wx1) elseif time < t3 then sd23*(wx3 - wx2) else 0.0;
  vry = if time < t1 then sd01*(wy1 - wy0) elseif time < t2 then sd12*(wy2 - wy1) elseif time < t3 then sd23*(wy3 - wy2) else 0.0;
  vrz = if time < t1 then sd01*(wz1 - wz0) elseif time < t2 then sd12*(wz2 - wz1) elseif time < t3 then sd23*(wz3 - wz2) else 0.0;

  arx = if time < t1 then sdd01*(wx1 - wx0) elseif time < t2 then sdd12*(wx2 - wx1) elseif time < t3 then sdd23*(wx3 - wx2) else 0.0;
  ary = if time < t1 then sdd01*(wy1 - wy0) elseif time < t2 then sdd12*(wy2 - wy1) elseif time < t3 then sdd23*(wy3 - wy2) else 0.0;
  arz = if time < t1 then sdd01*(wz1 - wz0) elseif time < t2 then sdd12*(wz2 - wz1) elseif time < t3 then sdd23*(wz3 - wz2) else 0.0;

  refX = rx;
  refY = ry;
  refZ = rz;
  refVx = vrx;
  refVy = vry;
  refVz = vrz;
  refAx = arx;
  refAy = ary;
  refAz = arz;

  totalThrust = T;
  probeTipX = tip_x;
  probeTipY = tip_y;
  probeTipZ = tip_z;

  // Primary tracking error
  primaryError = sqrt(max(0.0, (x-rx)*(x-rx) + (y-ry)*(y-ry) + (z-rz)*(z-rz)));

  // Collision checks against fixed cylinders
  collision1 = if (z + h_body/2 > obs1_z0 and z - h_body/2 < obs1_z1 and (x - obs1_x)*(x - obs1_x) + (y - obs1_y)*(y - obs1_y) < (obs1_r + r_body)*(obs1_r + r_body)) then 1.0 else 0.0;
  collision2 = if (z + h_body/2 > obs2_z0 and z - h_body/2 < obs2_z1 and (x - obs2_x)*(x - obs2_x) + (y - obs2_y)*(y - obs2_y) < (obs2_r + r_body)*(obs2_r + r_body)) then 1.0 else 0.0;
  collision3 = if (z + h_body/2 > obs3_z0 and z - h_body/2 < obs3_z1 and (x - obs3_x)*(x - obs3_x) + (y - obs3_y)*(y - obs3_y) < (obs3_r + r_body)*(obs3_r + r_body)) then 1.0 else 0.0;

  noCollisionFlag = if (collision1 + collision2 + collision3) < 0.5 then 1.0 else 0.0;

  // Runtime finite/bound checks
  physical_finite = if (abs(x) < 1e9 and abs(y) < 1e9 and abs(z) < 1e9 and abs(vx) < 1e9 and abs(vy) < 1e9 and abs(vz) < 1e9 and abs(phi) < 1e9 and abs(theta) < 1e9 and abs(psi) < 1e9 and abs(p_rate) < 1e9 and abs(q_rate) < 1e9 and abs(r_rate) < 1e9 and abs(Fp) < 1e9 and abs(T) < 1e9) then 1.0 else 0.0;
  control_finite = if (abs(u1) <= Fmax + 1e-6 and abs(u2) <= Fmax + 1e-6 and abs(u3) <= Fmax + 1e-6 and abs(u4) <= Fmax + 1e-6 and abs(Fp_cmd) <= Fprobe_max + 1e-6 and abs(T_cmd) <= 4.0*Fmax + 1e-6 and abs(phi_cmd) <= phi_max + 1e-6 and abs(theta_cmd) <= theta_max + 1e-6) then 1.0 else 0.0;
  estimator_finite = if (abs(x_hat) < 1e9 and abs(y_hat) < 1e9 and abs(z_hat) < 1e9 and abs(vx_hat) < 1e9 and abs(vy_hat) < 1e9 and abs(vz_hat) < 1e9) then 1.0 else 0.0;

  thrust_bound_ok = if T >= 0.0 and T <= 4.0*Fmax + 1e-6 then 1.0 else 0.0;
  attitude_bound_ok = if (abs(phi) <= phi_max + 1e-6 and abs(theta) <= theta_max + 1e-6 and abs(psi) <= psi_max + 1e-6) then 1.0 else 0.0;
  probe_bound_ok = if abs(Fp) <= Fprobe_max + 1e-6 then 1.0 else 0.0;

  thrustBoundOk = thrust_bound_ok;
  attitudeBoundOk = attitude_bound_ok;
  probeBoundOk = probe_bound_ok;
  boundsOk = if (thrust_bound_ok > 0.5 and attitude_bound_ok > 0.5 and probe_bound_ok > 0.5) then 1.0 else 0.0;
  physicalFinite = physical_finite;
  controlFinite = control_finite;
  estimatorFinite = estimator_finite;
  allFinite = if (physical_finite > 0.5 and control_finite > 0.5 and estimator_finite > 0.5) then 1.0 else 0.0;
  trackingOk = if time >= 7.8 then (if primaryError < 0.367 then 1.0 else 0.0) else 1.0;
  sensorSynchronized = if (abs(t_imu - t_gps) < 1e-6 and abs(t_gps - t_alt) < 1e-6 and abs(t_alt - t_camera) < 1e-6) then 1.0 else 0.0;

algorithm
  when sample(0, Ts) then
    // Raw sensor sampling with synchronized timestamps
    t_imu := time;
    t_gps := time;
    t_alt := time;
    t_camera := time;
    gps_x := x;
    gps_y := y;
    gps_z := z;
    alt_z := z;
    camera_x := x;
    camera_y := y;
    camera_z := z;
    imu_ax := ax;
    imu_ay := ay;
    imu_az := az;

    // Pose fusion from GPS, altimeter, and camera
    x_hat := 0.5*(gps_x + camera_x);
    y_hat := 0.5*(gps_y + camera_y);
    z_hat := 0.5*(alt_z + camera_z);

    // Velocity fusion: GPS derivative corrected by integrated IMU
    vx_gps := (gps_x - pre(gps_x))/Ts;
    vy_gps := (gps_y - pre(gps_y))/Ts;
    vz_gps := (gps_z - pre(gps_z))/Ts;
    vx_pred := pre(vx_hat) + Ts*imu_ax;
    vy_pred := pre(vy_hat) + Ts*imu_ay;
    vz_pred := pre(vz_hat) + Ts*imu_az;
    vx_hat := vx_pred + Kf*(vx_gps - vx_pred);
    vy_hat := vy_pred + Kf*(vy_gps - vy_pred);
    vz_hat := vz_pred + Kf*(vz_gps - vz_pred);

    // Bounded waypoint tracking with feedforward acceleration
    Fdes_x := m*(arx + Kp_pos*(rx - x_hat) + Kd_pos*(vrx - vx_hat));
    Fdes_y := m*(ary + Kp_pos*(ry - y_hat) + Kd_pos*(vry - vy_hat));
    Fdes_z := m*(arz + Kp_pos*(rz - z_hat) + Kd_pos*(vrz - vz_hat) + g);
    Tnorm := sqrt(Fdes_x*Fdes_x + Fdes_y*Fdes_y + Fdes_z*Fdes_z + eps);
    T_cmd := max(0.0, min(4.0*Fmax, Tnorm));

    if Tnorm > eps then
      zx_cmd := Fdes_x/Tnorm;
      zy_cmd := Fdes_y/Tnorm;
      zz_cmd := Fdes_z/Tnorm;
    else
      zx_cmd := 0.0;
      zy_cmd := 0.0;
      zz_cmd := 1.0;
    end if;

    psi_cmd := 0.0;
    A_cmd := zx_cmd*cos(psi_cmd) + zy_cmd*sin(psi_cmd);
    sphi_cmd := zx_cmd*sin(psi_cmd) - zy_cmd*cos(psi_cmd);
    theta_cmd_raw := atan2(A_cmd, zz_cmd);
    phi_cmd_raw := asin(max(-0.999, min(0.999, sphi_cmd)));
    phi_cmd := max(-phi_max, min(phi_max, phi_cmd_raw));
    theta_cmd := max(-theta_max, min(theta_max, theta_cmd_raw));

    // Attitude torque commands
    tau_x_cmd := Kphi*(phi_cmd - phi) - Kp_ang*p_rate;
    tau_y_cmd := Ktheta*(theta_cmd - theta) - Kp_ang*q_rate;
    tau_z_cmd := Kpsi*(psi_cmd - psi) - Kr_ang*r_rate;

    // Fan mixing and saturation
    u1_raw := T_cmd/4.0 + tau_x_cmd/(4.0*d_fan) - tau_y_cmd/(4.0*d_fan) - tau_z_cmd/(4.0*kappa_fan);
    u2_raw := T_cmd/4.0 + tau_x_cmd/(4.0*d_fan) + tau_y_cmd/(4.0*d_fan) + tau_z_cmd/(4.0*kappa_fan);
    u3_raw := T_cmd/4.0 - tau_x_cmd/(4.0*d_fan) + tau_y_cmd/(4.0*d_fan) - tau_z_cmd/(4.0*kappa_fan);
    u4_raw := T_cmd/4.0 - tau_x_cmd/(4.0*d_fan) - tau_y_cmd/(4.0*d_fan) + tau_z_cmd/(4.0*kappa_fan);
    u1 := max(0.0, min(Fmax, u1_raw));
    u2 := max(0.0, min(Fmax, u2_raw));
    u3 := max(0.0, min(Fmax, u3_raw));
    u4 := max(0.0, min(Fmax, u4_raw));

    // Probe-force actuator: bounded; no inspection contact specified, so command is zero
    Fp_cmd := 0.0;
  end when;

  annotation (experiment(StopTime=12, Interval=0.008));
end DuctInspectSurveyC;