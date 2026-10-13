model DuctInspectSurveyC
  // Physical constants
  parameter Real m = 2.7 "kg body mass";
  parameter Real g = 9.81 "m/s2 gravity";
  parameter Real Ts = 0.008 "s 125 Hz sample period";

  // Waypoint deadlines
  parameter Real t1 = 4.0 "s deadline waypoint 2";
  parameter Real t2 = 8.0 "s deadline waypoint 3";
  parameter Real t3 = 12.0 "s deadline waypoint 4";
  parameter Real dt_seg = 4.0 "s segment duration";

  // Waypoints [m]
  parameter Real wx0 = 0.0, wy0 = 0.0, wz0 = 1.5;
  parameter Real wx1 = 4.0, wy1 = 0.0, wz1 = 2.5;
  parameter Real wx2 = 4.0, wy2 = 3.0, wz2 = 2.5;
  parameter Real wx3 = 1.0, wy3 = 4.0, wz3 = 2.0;

  // Actuator bounds
  parameter Real Fmax = 16.6 "N max command magnitude per fan";
  parameter Real Fprobe_max = 10.0 "N probe force bound placeholder";

  // Geometry (placeholder values for unspecified details)
  parameter Real d_fan = 0.25 "m fan arm length";
  parameter Real kappa_fan = 0.10 "N.m/N yaw torque coefficient";
  parameter Real Ixx = 0.02 "kg.m2 roll inertia";
  parameter Real Iyy = 0.02 "kg.m2 pitch inertia";
  parameter Real Izz = 0.03 "kg.m2 yaw inertia";
  parameter Real r_body = 0.15 "m body radius";
  parameter Real h_body = 0.30 "m body height";

  // Probe
  parameter Real L_probe = 0.18 "m probe length along body X";
  parameter Real k_probe = 200.0 "N/m probe stiffness placeholder";
  parameter Real c_probe = 20.0 "N.s/m probe damping placeholder";

  // Control gains
  parameter Real Kp_pos = 10.0 "1/s2";
  parameter Real Kd_pos = 7.0 "1/s";
  parameter Real Kphi = 15.0 "N.m/rad";
  parameter Real Ktheta = 15.0 "N.m/rad";
  parameter Real Kp_ang = 3.0 "N.m.s/rad";
  parameter Real Kpsi = 5.0 "N.m/rad";
  parameter Real Kr_ang = 2.5 "N.m.s/rad";
  parameter Real phi_max = 0.35 "rad attitude bound placeholder";
  parameter Real theta_max = 0.35 "rad attitude bound placeholder";
  parameter Real psi_max = 0.35 "rad attitude bound placeholder";

  // Estimator gain
  parameter Real Kf = 0.7;

  // Obstacles (fixed cylinders outside reference polyline)
  parameter Real obs1_x = 6.0 "m", obs1_y = 1.0 "m", obs1_r = 0.5 "m";
  parameter Real obs2_x = 2.0 "m", obs2_y = -1.0 "m", obs2_r = 0.5 "m";
  parameter Real obs3_x = -1.0 "m", obs3_y = 3.0 "m", obs3_r = 0.5 "m";

  parameter Real eps = 1e-9;

  // Continuous states
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
  Real e_probe(start=0.0, fixed=true) "m probe extension";

  // Continuous algebraic variables
  Real ax, ay, az "m/s2 acceleration";
  Real T "N total thrust";
  Real tau_x, tau_y, tau_z "N.m torques";
  Real rx, ry, rz "m reference position";
  Real refVx, refVy, refVz "m/s reference velocity";
  Real refAx, refAy, refAz "m/s2 reference acceleration";
  Real bz_x, bz_y, bz_z "body Z axis components";
  Real bx_x, bx_y, bx_z "body X axis components";
  Real Fdist "N crosswind disturbance";
  Real Fp "N probe force";
  Real a1, a2, a3 "normalized segment progress";
  Real s1, s2, s3 "quintic position blend";
  Real sd1, sd2, sd3 "quintic velocity blend";
  Real sdd1, sdd2, sdd3 "quintic acceleration blend";
  Real primaryError "m tracking error";
  Real coll1, coll2, coll3 "collision flags";
  Real noCollisionFlag;
  Real thrustBoundOk, attitudeBoundOk, probeBoundOk, boundsOk;
  Real allFinite;
  Real trackingOk;
  Real sensorSyncOk;

  // Discrete control commands
  discrete Real u1(start=6.6, fixed=true) "N fan 1 thrust";
  discrete Real u2(start=6.6, fixed=true) "N fan 2 thrust";
  discrete Real u3(start=6.6, fixed=true) "N fan 3 thrust";
  discrete Real u4(start=6.6, fixed=true) "N fan 4 thrust";
  discrete Real Fp_cmd(start=0.0, fixed=true) "N probe force command";

  // Discrete estimates
  discrete Real x_hat(start=0.0, fixed=true) "m";
  discrete Real y_hat(start=0.0, fixed=true) "m";
  discrete Real z_hat(start=1.5, fixed=true) "m";
  discrete Real vx_hat(start=0.0, fixed=true) "m/s";
  discrete Real vy_hat(start=0.0, fixed=true) "m/s";
  discrete Real vz_hat(start=0.0, fixed=true) "m/s";

  // Discrete previous values for estimation
  discrete Real prev_gx(start=0.0, fixed=true) "m";
  discrete Real prev_gy(start=0.0, fixed=true) "m";
  discrete Real prev_gz(start=1.5, fixed=true) "m";
  discrete Real prev_vxh(start=0.0, fixed=true) "m/s";
  discrete Real prev_vyh(start=0.0, fixed=true) "m/s";
  discrete Real prev_vzh(start=0.0, fixed=true) "m/s";

  // Discrete sensor timestamps
  discrete Real t_imu(start=0.0, fixed=true) "s";
  discrete Real t_gps(start=0.0, fixed=true) "s";
  discrete Real t_alt(start=0.0, fixed=true) "s";
  discrete Real t_cam(start=0.0, fixed=true) "s";

  // Discrete control intermediates
  discrete Real Fdes_x(start=0.0, fixed=true) "N";
  discrete Real Fdes_y(start=0.0, fixed=true) "N";
  discrete Real Fdes_z(start=26.5, fixed=true) "N";
  discrete Real Tnorm(start=26.5, fixed=true) "N";
  discrete Real T_cmd(start=26.5, fixed=true) "N";
  discrete Real phi_cmd(start=0.0, fixed=true) "rad";
  discrete Real theta_cmd(start=0.0, fixed=true) "rad";
  discrete Real tau_x_cmd(start=0.0, fixed=true) "N.m";
  discrete Real tau_y_cmd(start=0.0, fixed=true) "N.m";
  discrete Real tau_z_cmd(start=0.0, fixed=true) "N.m";
  discrete Real vx_gps(start=0.0, fixed=true) "m/s";
  discrete Real vy_gps(start=0.0, fixed=true) "m/s";
  discrete Real vz_gps(start=0.0, fixed=true) "m/s";

  // Outputs
  output Real posX "m";
  output Real posY "m";
  output Real posZ "m";
  output Real estX "m";
  output Real estY "m";
  output Real estZ "m";
  output Real estVx "m/s";
  output Real estVy "m/s";
  output Real estVz "m/s";
  output Real refPosX "m";
  output Real refPosY "m";
  output Real refPosZ "m";
  output Real fan1Thrust "N";
  output Real fan2Thrust "N";
  output Real fan3Thrust "N";
  output Real fan4Thrust "N";
  output Real probeForce "N";
  output Real totalThrustOut "N";
  output Real crosswind "N";
  output Real primaryErrorOut "m";
  output Real noCollisionOut;
  output Real boundsOkOut;
  output Real allFiniteOut;
  output Real trackingOkOut;
  output Real sensorSyncOut;
  output Real imuTimeOut "s";
  output Real gpsTimeOut "s";
  output Real altTimeOut "s";
  output Real camTimeOut "s";

equation
  // Translational dynamics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  // Attitude dynamics (simplified for small tilts)
  der(phi) = p_rate;
  der(theta) = q_rate;
  der(psi) = r_rate;
  der(p_rate) = tau_x / Ixx;
  der(q_rate) = tau_y / Iyy;
  der(r_rate) = tau_z / Izz;

  // Probe compliance dynamics
  der(e_probe) = (Fp - k_probe * e_probe) / c_probe;
  Fp = Fp_cmd;

  // Body-frame Z axis (thrust direction)
  bz_x = cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
  bz_y = sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
  bz_z = cos(theta)*cos(phi);

  // Body-frame X axis (probe direction)
  bx_x = cos(psi)*cos(theta);
  bx_y = sin(psi)*cos(theta);
  bx_z = -sin(theta);

  // Fan thrust and torque mixing
  T = u1 + u2 + u3 + u4;
  tau_x = d_fan * (u1 + u2 - u3 - u4);
  tau_y = d_fan * (-u1 + u2 + u3 - u4);
  tau_z = kappa_fan * (-u1 + u2 - u3 + u4);

  // Crosswind disturbance: 5.4 N during middle third [t1, t2)
  Fdist = if time >= t1 and time < t2 then 5.4 else 0.0;

  // Translational acceleration
  ax = T/m * bz_x + Fdist/m + Fp/m * bx_x;
  ay = T/m * bz_y + Fp/m * bx_y;
  az = T/m * bz_z - g + Fp/m * bx_z;

  // Quintic trajectory: normalized segment progress
  a1 = if time < t1 then time/dt_seg else 1.0;
  a2 = if time < t1 then 0.0 elseif time < t2 then (time - t1)/dt_seg else 1.0;
  a3 = if time < t2 then 0.0 elseif time < t3 then (time - t2)/dt_seg else 1.0;

  // Quintic position blend s(alpha) = 10*a^3 - 15*a^4 + 6*a^5
  s1 = 10.0*a1*a1*a1 - 15.0*a1*a1*a1*a1 + 6.0*a1*a1*a1*a1*a1;
  s2 = 10.0*a2*a2*a2 - 15.0*a2*a2*a2*a2 + 6.0*a2*a2*a2*a2*a2;
  s3 = 10.0*a3*a3*a3 - 15.0*a3*a3*a3*a3 + 6.0*a3*a3*a3*a3*a3;

  // Quintic velocity blend ds/dt
  sd1 = (30.0*a1*a1 - 60.0*a1*a1*a1 + 30.0*a1*a1*a1*a1) / dt_seg;
  sd2 = (30.0*a2*a2 - 60.0*a2*a2*a2 + 30.0*a2*a2*a2*a2) / dt_seg;
  sd3 = (30.0*a3*a3 - 60.0*a3*a3*a3 + 30.0*a3*a3*a3*a3) / dt_seg;

  // Quintic acceleration blend d2s/dt2
  sdd1 = (60.0*a1 - 180.0*a1*a1 + 120.0*a1*a1*a1) / (dt_seg*dt_seg);
  sdd2 = (60.0*a2 - 180.0*a2*a2 + 120.0*a2*a2*a2) / (dt_seg*dt_seg);
  sdd3 = (60.0*a3 - 180.0*a3*a3 + 120.0*a3*a3*a3) / (dt_seg*dt_seg);

  // Reference position
  rx = if time < t1 then wx0 + s1*(wx1 - wx0)
       elseif time < t2 then wx1 + s2*(wx2 - wx1)
       elseif time < t3 then wx2 + s3*(wx3 - wx2)
       else wx3;
  ry = if time < t1 then wy0 + s1*(wy1 - wy0)
       elseif time < t2 then wy1 + s2*(wy2 - wy1)
       elseif time < t3 then wy2 + s3*(wy3 - wy2)
       else wy3;
  rz = if time < t1 then wz0 + s1*(wz1 - wz0)
       elseif time < t2 then wz1 + s2*(wz2 - wz1)
       elseif time < t3 then wz2 + s3*(wz3 - wz2)
       else wz3;

  // Reference velocity (feedforward)
  refVx = if time < t1 then sd1*(wx1 - wx0)
          elseif time < t2 then sd2*(wx2 - wx1)
          elseif time < t3 then sd3*(wx3 - wx2)
          else 0.0;
  refVy = if time < t1 then sd1*(wy1 - wy0)
          elseif time < t2 then sd2*(wy2 - wy1)
          elseif time < t3 then sd3*(wy3 - wy2)
          else 0.0;
  refVz = if time < t1 then sd1*(wz1 - wz0)
          elseif time < t2 then sd2*(wz2 - wz1)
          elseif time < t3 then sd3*(wz3 - wz2)
          else 0.0;

  // Reference acceleration (feedforward)
  refAx = if time < t1 then sdd1*(wx1 - wx0)
          elseif time < t2 then sdd2*(wx2 - wx1)
          elseif time < t3 then sdd3*(wx3 - wx2)
          else 0.0;
  refAy = if time < t1 then sdd1*(wy1 - wy0)
          elseif time < t2 then sdd2*(wy2 - wy1)
          elseif time < t3 then sdd3*(wy3 - wy2)
          else 0.0;
  refAz = if time < t1 then sdd1*(wz1 - wz0)
          elseif time < t2 then sdd2*(wz2 - wz1)
          elseif time < t3 then sdd3*(wz3 - wz2)
          else 0.0;

  // Primary tracking error with zero-safe sqrt
  primaryError = sqrt(max(eps, (x-rx)*(x-rx) + (y-ry)*(y-ry) + (z-rz)*(z-rz)));

  // Collision checks against fixed cylindrical obstacles
  coll1 = if (z + h_body/2.0 > 0.0 and z - h_body/2.0 < 3.0 and
              (x-obs1_x)*(x-obs1_x) + (y-obs1_y)*(y-obs1_y) < (obs1_r + r_body)*(obs1_r + r_body))
          then 1.0 else 0.0;
  coll2 = if (z + h_body/2.0 > 0.0 and z - h_body/2.0 < 3.0 and
              (x-obs2_x)*(x-obs2_x) + (y-obs2_y)*(y-obs2_y) < (obs2_r + r_body)*(obs2_r + r_body))
          then 1.0 else 0.0;
  coll3 = if (z + h_body/2.0 > 0.0 and z - h_body/2.0 < 3.0 and
              (x-obs3_x)*(x-obs3_x) + (y-obs3_y)*(y-obs3_y) < (obs3_r + r_body)*(obs3_r + r_body))
          then 1.0 else 0.0;
  noCollisionFlag = if (coll1 + coll2 + coll3) < 0.5 then 1.0 else 0.0;

  // Bound checks
  thrustBoundOk = if T >= 0.0 and T <= 4.0*Fmax + 1e-6 then 1.0 else 0.0;
  attitudeBoundOk = if abs(phi) <= phi_max + 1e-6 and abs(theta) <= theta_max + 1e-6 and abs(psi) <= psi_max + 1e-6 then 1.0 else 0.0;
  probeBoundOk = if abs(Fp) <= Fprobe_max + 1e-6 then 1.0 else 0.0;
  boundsOk = if thrustBoundOk > 0.5 and attitudeBoundOk > 0.5 and probeBoundOk > 0.5 then 1.0 else 0.0;

  // Finiteness check for physical, control, and estimator values
  allFinite = if (x < 1e9 and x > -1e9 and
                  y < 1e9 and y > -1e9 and
                  z < 1e9 and z > -1e9 and
                  vx < 1e9 and vx > -1e9 and
                  vy < 1e9 and vy > -1e9 and
                  vz < 1e9 and vz > -1e9 and
                  u1 < 1e9 and u1 > -1e9 and
                  u2 < 1e9 and u2 > -1e9 and
                  u3 < 1e9 and u3 > -1e9 and
                  u4 < 1e9 and u4 > -1e9 and
                  x_hat < 1e9 and x_hat > -1e9 and
                  y_hat < 1e9 and y_hat > -1e9 and
                  z_hat < 1e9 and z_hat > -1e9 and
                  vx_hat < 1e9 and vx_hat > -1e9 and
                  vy_hat < 1e9 and vy_hat > -1e9 and
                  vz_hat < 1e9 and vz_hat > -1e9)
              then 1.0 else 0.0;

  // Tracking requirement: error below 0.367 m after 7.8 s
  trackingOk = if time >= 7.8 then (if primaryError < 0.367 then 1.0 else 0.0) else 1.0;

  // Sensor synchronization check
  sensorSyncOk = if abs(t_imu - t_gps) < 1e-6 and abs(t_gps - t_alt) < 1e-6 and abs(t_alt - t_cam) < 1e-6 then 1.0 else 0.0;

  // Output bindings
  posX = x;
  posY = y;
  posZ = z;
  estX = x_hat;
  estY = y_hat;
  estZ = z_hat;
  estVx = vx_hat;
  estVy = vy_hat;
  estVz = vz_hat;
  refPosX = rx;
  refPosY = ry;
  refPosZ = rz;
  fan1Thrust = u1;
  fan2Thrust = u2;
  fan3Thrust = u3;
  fan4Thrust = u4;
  probeForce = Fp;
  totalThrustOut = T;
  crosswind = Fdist;
  primaryErrorOut = primaryError;
  noCollisionOut = noCollisionFlag;
  boundsOkOut = boundsOk;
  allFiniteOut = allFinite;
  trackingOkOut = trackingOk;
  sensorSyncOut = sensorSyncOk;
  imuTimeOut = t_imu;
  gpsTimeOut = t_gps;
  altTimeOut = t_alt;
  camTimeOut = t_cam;

algorithm
  when sample(0, Ts) then
    // Synchronized sensor timestamps from IMU, GPS, altimeter, camera
    t_imu := time;
    t_gps := time;
    t_alt := time;
    t_cam := time;

    // Pose fusion: GPS provides x,y; altimeter provides z; camera provides x,y,z
    // All sensors read true state (no noise model specified)
    x_hat := x;
    y_hat := y;
    z_hat := z;

    // Velocity estimation: GPS derivative fused with IMU-integrated prediction
    vx_gps := (x - prev_gx) / Ts;
    vy_gps := (y - prev_gy) / Ts;
    vz_gps := (z - prev_gz) / Ts;
    // Complementary filter: (1-Kf)*IMU_prediction + Kf*GPS_derivative
    vx_hat := (1.0 - Kf) * (prev_vxh + Ts * ax) + Kf * vx_gps;
    vy_hat := (1.0 - Kf) * (prev_vyh + Ts * ay) + Kf * vy_gps;
    vz_hat := (1.0 - Kf) * (prev_vzh + Ts * az) + Kf * vz_gps;

    // Bounded waypoint tracking with feedforward acceleration
    Fdes_x := m * (refAx + Kp_pos * (rx - x_hat) + Kd_pos * (refVx - vx_hat));
    Fdes_y := m * (refAy + Kp_pos * (ry - y_hat) + Kd_pos * (refVy - vy_hat));
    Fdes_z := m * (refAz + Kp_pos * (rz - z_hat) + Kd_pos * (refVz - vz_hat) + g);
    Tnorm := sqrt(max(eps, Fdes_x*Fdes_x + Fdes_y*Fdes_y + Fdes_z*Fdes_z));
    T_cmd := max(0.0, min(4.0*Fmax, Tnorm));

    // Attitude commands from desired thrust direction (yaw = 0)
    if Tnorm > eps then
      theta_cmd := atan2(Fdes_x, Fdes_z);
      phi_cmd := atan2(-Fdes_y, sqrt(max(eps, Fdes_x*Fdes_x + Fdes_z*Fdes_z)));
    else
      theta_cmd := 0.0;
      phi_cmd := 0.0;
    end if;
    phi_cmd := max(-phi_max, min(phi_max, phi_cmd));
    theta_cmd := max(-theta_max, min(theta_max, theta_cmd));

    // Attitude torque commands
    tau_x_cmd := Kphi * (phi_cmd - phi) - Kp_ang * p_rate;
    tau_y_cmd := Ktheta * (theta_cmd - theta) - Kp_ang * q_rate;
    tau_z_cmd := Kpsi * (0.0 - psi) - Kr_ang * r_rate;

    // Fan thrust mixing with saturation to Fmax per channel
    u1 := max(0.0, min(Fmax, T_cmd/4.0 + tau_x_cmd/(4.0*d_fan) - tau_y_cmd/(4.0*d_fan) - tau_z_cmd/(4.0*kappa_fan)));
    u2 := max(0.0, min(Fmax, T_cmd/4.0 + tau_x_cmd/(4.0*d_fan) + tau_y_cmd/(4.0*d_fan) + tau_z_cmd/(4.0*kappa_fan)));
    u3 := max(0.0, min(Fmax, T_cmd/4.0 - tau_x_cmd/(4.0*d_fan) + tau_y_cmd/(4.0*d_fan) - tau_z_cmd/(4.0*kappa_fan)));
    u4 := max(0.0, min(Fmax, T_cmd/4.0 - tau_x_cmd/(4.0*d_fan) - tau_y_cmd/(4.0*d_fan) + tau_z_cmd/(4.0*kappa_fan)));

    // Probe force: no inspection contact specified, command zero
    Fp_cmd := 0.0;

    // Update previous values for next sample
    prev_gx := x;
    prev_gy := y;
    prev_gz := z;
    prev_vxh := vx_hat;
    prev_vyh := vy_hat;
    prev_vzh := vz_hat;
  end when;

  annotation (experiment(StopTime=12, Interval=0.008));
end DuctInspectSurveyC;