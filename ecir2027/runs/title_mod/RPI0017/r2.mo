model QuadScoutDeliverE
  "Free-base quadrotor with suspended payload, input-shaped position control, cable swing damping, and fail-closed acceptance."

  // Physical parameters
  parameter Real m_body = 1.8 "kg, box fuselage mass";
  parameter Real m_payload = 0.6 "kg, suspended payload mass; not specified, nominal executable value";
  parameter Real m_total = m_body + m_payload "kg";
  parameter Real L_arm = 0.22 "m, rotor arm length";
  parameter Real L_cable = 0.8 "m, cable length; not specified, nominal executable value";
  parameter Real Tmax = 13.2 "N per rotor, command/thrust bound";
  parameter Real g = 9.81 "m/s2";
  parameter Real Ixx = 0.02 "kg.m2, fuselage inertia; not specified, nominal executable value";
  parameter Real Iyy = 0.02 "kg.m2, fuselage inertia; not specified, nominal executable value";
  parameter Real Izz = 0.04 "kg.m2, fuselage inertia; not specified, nominal executable value";
  parameter Real kYaw = 0.10 "m, signed yaw moment per rotor thrust coefficient; not specified, nominal executable value";
  parameter Real kD_body = 0.08 "kg/m, quadrotor drag coefficient; not specified, nominal executable value";
  parameter Real kD_payload = 0.02 "kg/m, payload drag coefficient; not specified, nominal executable value";

  // Mission parameters
  parameter Real Ts = 0.004 "s, 250 Hz controller sample period";
  parameter Real x_target = 5.0 "m, horizontal translation target";
  parameter Real targetRadius = 0.8 "m, target-zone radius";
  parameter Real targetZ = 0.1 "m, target-zone payload height; not specified, nominal executable value";
  parameter Real z_start = 1.0 "m, initial quadrotor height";
  parameter Real z_cruise = 2.0 "m, cruise height";
  parameter Real z_final_quad = 0.9 "m, final hover height over target";
  parameter Real T_lift = 2.0 "s";
  parameter Real T_hold1 = 1.0 "s";
  parameter Real T_trans = 6.0 "s";
  parameter Real T_lower = 2.0 "s";
  parameter Real T_hold2 = 5.0 "s";
  parameter Real T_gust_start = 16.0/3.0 "s, middle-third start";
  parameter Real T_gust_end = 32.0/3.0 "s, middle-third end";
  parameter Real GustForce = 9.6 "N, controlled lateral gust";
  parameter Real tensionLimit = m_payload*((4.0*Tmax - m_total*g)/m_total + g) "N, derived max cable tension under full thrust";
  parameter Real eps = 1e-6 "tolerance";
  parameter Real a_arm = L_arm/sqrt(2.0) "m, X-arm projection";

  // Control gains; not specified, nominal executable values
  parameter Real Kp_pos = 15.0;
  parameter Real Kd_pos = 7.0;
  parameter Real Kp_att = 4.0;
  parameter Real Kd_att = 1.5;
  parameter Real Kp_yaw = 6.0;
  parameter Real Kd_yaw = 2.0;
  parameter Real K_swing = 2.0;

  // Quadrotor states
  Real x_b(start=0.0, fixed=true) "m";
  Real y_b(start=0.0, fixed=true) "m";
  Real z_b(start=z_start, fixed=true) "m";
  Real vx_b(start=0.0, fixed=true) "m/s";
  Real vy_b(start=0.0, fixed=true) "m/s";
  Real vz_b(start=0.0, fixed=true) "m/s";
  Real phi(start=0.0, fixed=true) "rad";
  Real theta(start=0.0, fixed=true) "rad";
  Real psi(start=0.0, fixed=true) "rad";
  Real p(start=0.0, fixed=true) "rad/s";
  Real q(start=0.0, fixed=true) "rad/s";
  Real r(start=0.0, fixed=true) "rad/s";

  // Payload states
  Real x_p(start=0.0, fixed=true) "m";
  Real y_p(start=0.0, fixed=true) "m";
  Real z_p(start=z_start - L_cable, fixed=true) "m";
  Real vx_p(start=0.0, fixed=true) "m/s";
  Real vy_p(start=0.0, fixed=true) "m/s";
  Real vz_p(start=0.0, fixed=true) "m/s";

  // Rotor commands and actual thrusts
  Real Tcmd1(start=m_total*g/4.0, fixed=true) "N";
  Real Tcmd2(start=m_total*g/4.0, fixed=true) "N";
  Real Tcmd3(start=m_total*g/4.0, fixed=true) "N";
  Real Tcmd4(start=m_total*g/4.0, fixed=true) "N";
  Real TcmdRaw1(start=m_total*g/4.0, fixed=true) "N";
  Real TcmdRaw2(start=m_total*g/4.0, fixed=true) "N";
  Real TcmdRaw3(start=m_total*g/4.0, fixed=true) "N";
  Real TcmdRaw4(start=m_total*g/4.0, fixed=true) "N";
  Real T1 "N";
  Real T2 "N";
  Real T3 "N";
  Real T4 "N";
  Real Tsum "N";

  // Discrete controller variables
  Real Fw_x(start=0.0, fixed=true) "N";
  Real Fw_y(start=0.0, fixed=true) "N";
  Real Fw_z(start=m_total*g, fixed=true) "N";
  Real Fw_norm(start=m_total*g, fixed=true) "N";
  Real phi_d(start=0.0, fixed=true) "rad";
  Real theta_d(start=0.0, fixed=true) "rad";
  Real psi_d(start=0.0, fixed=true) "rad";
  Real Mx_d(start=0.0, fixed=true) "N.m";
  Real My_d(start=0.0, fixed=true) "N.m";
  Real Mz_d(start=0.0, fixed=true) "N.m";
  Real Tsum_d(start=m_total*g, fixed=true) "N";
  Real aSwingX(start=0.0, fixed=true) "m/s2";
  Real aSwingY(start=0.0, fixed=true) "m/s2";
  Real cableAngleRateX(start=0.0, fixed=true) "rad/s";
  Real cableAngleRateY(start=0.0, fixed=true) "rad/s";
  Real cableAngleXPrev(start=0.0, fixed=true) "rad";
  Real cableAngleYPrev(start=0.0, fixed=true) "rad";
  Real gustFFx(start=0.0, fixed=true) "N";
  Real maxTrackingErrorAfter(start=0.0, fixed=true) "m";

  // Acceptance latches
  Boolean thrustViolation(start=false, fixed=true);
  Boolean commandViolation(start=false, fixed=true);
  Boolean tensionViolation(start=false, fixed=true);
  Boolean swingViolation(start=false, fixed=true);
  Boolean groundStrikeViolation(start=false, fixed=true);
  Boolean trackingViolation(start=false, fixed=true);
  Boolean numericViolation(start=false, fixed=true);

  // Continuous desired trajectory
  Real s "1";
  Real tau "s";
  Real shape "1";
  Real dshape "1";
  Real ddshape "1";
  Real rd_x "m";
  Real rd_y "m";
  Real rd_z "m";
  Real vd_x "m/s";
  Real vd_y "m/s";
  Real vd_z "m/s";
  Real ad_x "m/s2";
  Real ad_y "m/s2";
  Real ad_z "m/s2";

  // Gravity vector
  parameter Real g_w_x = 0.0 "m/s2";
  parameter Real g_w_y = 0.0 "m/s2";
  parameter Real g_w_z = -g "m/s2";

  // Rotation matrix elements
  Real cphi "1";
  Real sphi "1";
  Real ctheta "1";
  Real stheta "1";
  Real cpsi "1";
  Real spsi "1";
  Real R11 "1"; Real R12 "1"; Real R13 "1";
  Real R21 "1"; Real R22 "1"; Real R23 "1";
  Real R31 "1"; Real R32 "1"; Real R33 "1";
  Real cosThetaS "1";
  Real tanTheta "1";

  // Forces and accelerations
  Real Frot_x "N";
  Real Frot_y "N";
  Real Frot_z "N";
  Real Fdrag_b_x "N";
  Real Fdrag_b_y "N";
  Real Fdrag_b_z "N";
  Real Fdrag_p_x "N";
  Real Fdrag_p_y "N";
  Real Fdrag_p_z "N";
  Real gustForceX "N";
  Real vbnorm "m/s";
  Real vpn "m/s";
  Real dx_c "m";
  Real dy_c "m";
  Real dz_c "m";
  Real dist "m";
  Real distS "m";
  Real nx "1";
  Real ny "1";
  Real nz "1";
  Real vrelx "m/s";
  Real vrely "m/s";
  Real vrelz "m/s";
  Real vrel2 "(m/s)2";
  Real T_raw "N";
  Real tension "N";
  Real a_b_noT_x "m/s2";
  Real a_b_noT_y "m/s2";
  Real a_b_noT_z "m/s2";
  Real a_p_noT_x "m/s2";
  Real a_p_noT_y "m/s2";
  Real a_p_noT_z "m/s2";
  Real a_b_x "m/s2";
  Real a_b_y "m/s2";
  Real a_b_z "m/s2";
  Real a_p_x "m/s2";
  Real a_p_y "m/s2";
  Real a_p_z "m/s2";

  // Body moments
  Real Mx_body "N.m";
  Real My_body "N.m";
  Real Mz_body "N.m";

  // Sensors
  Real gps_x "m";
  Real gps_y "m";
  Real gps_z "m";
  Real gps_vx "m/s";
  Real gps_vy "m/s";
  Real gps_vz "m/s";
  Real imu_ax_body "m/s2";
  Real imu_ay_body "m/s2";
  Real imu_az_body "m/s2";
  Real imu_phi "rad";
  Real imu_theta "rad";
  Real imu_psi "rad";
  Real imu_p "rad/s";
  Real imu_q "rad/s";
  Real imu_r "rad/s";
  Real cableAngleX "rad";
  Real cableAngleY "rad";
  Real cableAngle "rad";
  Real tension_meas "N";

  // Estimator pass-through variables (GPS/IMU/cable fusion details not specified)
  Real est_x "m";
  Real est_y "m";
  Real est_z "m";
  Real est_vx "m/s";
  Real est_vy "m/s";
  Real est_vz "m/s";
  Real est_phi "rad";
  Real est_theta "rad";
  Real est_psi "rad";

  // Acceptance status
  Real trackingErrorNow "m";
  Boolean ThrustBoundOK;
  Boolean CommandBoundOK;
  Boolean TensionBoundOK;
  Boolean SwingBoundOK;
  Boolean NoGroundStrikeOK;
  Boolean TrackingErrorOK;
  Boolean NumericOK;
  Boolean TargetZoneOK;
  Boolean Accept;

equation
  // Input-shaped trajectory: lift, hold, translate 5 m, lower, hold
  if time < T_lift then
    s = time/T_lift;
    tau = 0.0;
    shape = 10.0*s^3 - 15.0*s^4 + 6.0*s^5;
    dshape = 30.0*s^2 - 60.0*s^3 + 30.0*s^4;
    ddshape = 60.0*s - 180.0*s^2 + 120.0*s^3;
    rd_x = 0.0;
    rd_y = 0.0;
    rd_z = z_start + (z_cruise - z_start)*shape;
    vd_x = 0.0;
    vd_y = 0.0;
    vd_z = (z_cruise - z_start)*dshape/T_lift;
    ad_x = 0.0;
    ad_y = 0.0;
    ad_z = (z_cruise - z_start)*ddshape/T_lift^2;
  elseif time < T_lift + T_hold1 then
    s = 1.0;
    tau = 0.0;
    shape = 1.0;
    dshape = 0.0;
    ddshape = 0.0;
    rd_x = 0.0;
    rd_y = 0.0;
    rd_z = z_cruise;
    vd_x = 0.0;
    vd_y = 0.0;
    vd_z = 0.0;
    ad_x = 0.0;
    ad_y = 0.0;
    ad_z = 0.0;
  elseif time < T_lift + T_hold1 + T_trans then
    tau = time - (T_lift + T_hold1);
    s = tau/T_trans;
    shape = 10.0*s^3 - 15.0*s^4 + 6.0*s^5;
    dshape = 30.0*s^2 - 60.0*s^3 + 30.0*s^4;
    ddshape = 60.0*s - 180.0*s^2 + 120.0*s^3;
    rd_x = x_target*shape;
    rd_y = 0.0;
    rd_z = z_cruise;
    vd_x = x_target*dshape/T_trans;
    vd_y = 0.0;
    vd_z = 0.0;
    ad_x = x_target*ddshape/T_trans^2;
    ad_y = 0.0;
    ad_z = 0.0;
  elseif time < T_lift + T_hold1 + T_trans + T_lower then
    tau = time - (T_lift + T_hold1 + T_trans);
    s = tau/T_lower;
    shape = 10.0*s^3 - 15.0*s^4 + 6.0*s^5;
    dshape = 30.0*s^2 - 60.0*s^3 + 30.0*s^4;
    ddshape = 60.0*s - 180.0*s^2 + 120.0*s^3;
    rd_x = x_target;
    rd_y = 0.0;
    rd_z = z_cruise + (z_final_quad - z_cruise)*shape;
    vd_x = 0.0;
    vd_y = 0.0;
    vd_z = (z_final_quad - z_cruise)*dshape/T_lower;
    ad_x = 0.0;
    ad_y = 0.0;
    ad_z = (z_final_quad - z_cruise)*ddshape/T_lower^2;
  else
    s = 1.0;
    tau = 0.0;
    shape = 1.0;
    dshape = 0.0;
    ddshape = 0.0;
    rd_x = x_target;
    rd_y = 0.0;
    rd_z = z_final_quad;
    vd_x = 0.0;
    vd_y = 0.0;
    vd_z = 0.0;
    ad_x = 0.0;
    ad_y = 0.0;
    ad_z = 0.0;
  end if;

  // Gust disturbance
  gustForceX = if time >= T_gust_start and time <= T_gust_end then GustForce else 0.0;

  // Rotation matrix (body to world), Rz(yaw)*Ry(pitch)*Rx(roll)
  cphi = cos(phi);
  sphi = sin(phi);
  ctheta = cos(theta);
  stheta = sin(theta);
  cpsi = cos(psi);
  spsi = sin(psi);
  R11 = cpsi*ctheta;
  R12 = cpsi*stheta*sphi - spsi*cphi;
  R13 = cpsi*stheta*cphi + spsi*sphi;
  R21 = spsi*ctheta;
  R22 = spsi*stheta*sphi + cpsi*cphi;
  R23 = spsi*stheta*cphi - cpsi*sphi;
  R31 = -stheta;
  R32 = ctheta*sphi;
  R33 = ctheta*cphi;
  cosThetaS = if ctheta > 1e-6 then ctheta elseif ctheta < -1e-6 then ctheta else 1e-6;
  tanTheta = stheta/cosThetaS;

  // Rotor thrust and moments
  T1 = Tcmd1;
  T2 = Tcmd2;
  T3 = Tcmd3;
  T4 = Tcmd4;
  Tsum = T1 + T2 + T3 + T4;
  Mx_body = a_arm*(T1 + T2 - T3 - T4);
  My_body = a_arm*(-T1 + T2 + T3 - T4);
  Mz_body = kYaw*(T1 - T2 + T3 - T4);

  // World rotor force
  Frot_x = R13*Tsum;
  Frot_y = R23*Tsum;
  Frot_z = R33*Tsum;

  // Aerodynamic drag
  vbnorm = sqrt(vx_b*vx_b + vy_b*vy_b + vz_b*vz_b);
  Fdrag_b_x = -kD_body*vbnorm*vx_b;
  Fdrag_b_y = -kD_body*vbnorm*vy_b;
  Fdrag_b_z = -kD_body*vbnorm*vz_b;
  vpn = sqrt(vx_p*vx_p + vy_p*vy_p + vz_p*vz_p);
  Fdrag_p_x = -kD_payload*vpn*vx_p;
  Fdrag_p_y = -kD_payload*vpn*vy_p;
  Fdrag_p_z = -kD_payload*vpn*vz_p;

  // Cable kinematics and tension
  dx_c = x_b - x_p;
  dy_c = y_b - y_p;
  dz_c = z_b - z_p;
  dist = sqrt(dx_c*dx_c + dy_c*dy_c + dz_c*dz_c);
  distS = max(dist, 1e-9);
  nx = dx_c/distS;
  ny = dy_c/distS;
  nz = dz_c/distS;
  vrelx = vx_b - vx_p;
  vrely = vy_b - vy_p;
  vrelz = vz_b - vz_p;
  vrel2 = vrelx*vrelx + vrely*vrely + vrelz*vrelz;

  a_b_noT_x = (Frot_x + m_body*g_w_x + Fdrag_b_x + gustForceX)/m_body;
  a_b_noT_y = (Frot_y + m_body*g_w_y + Fdrag_b_y)/m_body;
  a_b_noT_z = (Frot_z + m_body*g_w_z + Fdrag_b_z)/m_body;
  a_p_noT_x = (m_payload*g_w_x + Fdrag_p_x)/m_payload;
  a_p_noT_y = (m_payload*g_w_y + Fdrag_p_y)/m_payload;
  a_p_noT_z = (m_payload*g_w_z + Fdrag_p_z)/m_payload;

  T_raw = (nx*(a_b_noT_x - a_p_noT_x) + ny*(a_b_noT_y - a_p_noT_y) + nz*(a_b_noT_z - a_p_noT_z) + vrel2/L_cable)/(1.0/m_body + 1.0/m_payload);
  tension = if T_raw > 0.0 then T_raw else 0.0;

  a_b_x = a_b_noT_x - tension*nx/m_body;
  a_b_y = a_b_noT_y - tension*ny/m_body;
  a_b_z = a_b_noT_z - tension*nz/m_body;
  a_p_x = a_p_noT_x + tension*nx/m_payload;
  a_p_y = a_p_noT_y + tension*ny/m_payload;
  a_p_z = a_p_noT_z + tension*nz/m_payload;

  // Quadrotor translation
  der(x_b) = vx_b;
  der(y_b) = vy_b;
  der(z_b) = vz_b;
  der(vx_b) = a_b_x;
  der(vy_b) = a_b_y;
  der(vz_b) = a_b_z;

  // Payload translation
  der(x_p) = vx_p;
  der(y_p) = vy_p;
  der(z_p) = vz_p;
  der(vx_p) = a_p_x;
  der(vy_p) = a_p_y;
  der(vz_p) = a_p_z;

  // Attitude kinematics and dynamics
  der(phi) = p + q*sphi*tanTheta + r*cphi*tanTheta;
  der(theta) = q*cphi - r*sphi;
  der(psi) = (q*sphi + r*cphi)/cosThetaS;
  der(p) = (Mx_body - (Izz - Iyy)*q*r)/Ixx;
  der(q) = (My_body - (Ixx - Izz)*r*p)/Iyy;
  der(r) = (Mz_body - (Iyy - Ixx)*p*q)/Izz;

  // GPS sensors
  gps_x = x_b;
  gps_y = y_b;
  gps_z = z_b;
  gps_vx = vx_b;
  gps_vy = vy_b;
  gps_vz = vz_b;

  // IMU sensors (attitude solution and gyro; AHRS details not specified)
  imu_phi = phi;
  imu_theta = theta;
  imu_psi = psi;
  imu_p = p;
  imu_q = q;
  imu_r = r;
  imu_ax_body = R11*a_b_x + R21*a_b_y + R31*(a_b_z - g_w_z);
  imu_ay_body = R12*a_b_x + R22*a_b_y + R32*(a_b_z - g_w_z);
  imu_az_body = R13*a_b_x + R23*a_b_y + R33*(a_b_z - g_w_z);

  // Cable sensors
  cableAngleX = atan2(x_p - x_b, max(z_b - z_p, 1e-6));
  cableAngleY = atan2(y_p - y_b, max(z_b - z_p, 1e-6));
  cableAngle = sqrt(cableAngleX*cableAngleX + cableAngleY*cableAngleY);
  tension_meas = tension;

  // Estimator pass-through
  est_x = gps_x;
  est_y = gps_y;
  est_z = gps_z;
  est_vx = gps_vx;
  est_vy = gps_vy;
  est_vz = gps_vz;
  est_phi = imu_phi;
  est_theta = imu_theta;
  est_psi = imu_psi;

  // Acceptance computations
  trackingErrorNow = sqrt((x_b - rd_x)^2 + (y_b - rd_y)^2 + (z_b - rd_z)^2);
  TargetZoneOK = time >= 15.5 and sqrt((x_p - x_target)^2 + y_p*y_p) <= targetRadius + eps and z_p <= targetZ + 0.15 and z_p >= 0.0;
  ThrustBoundOK = not thrustViolation;
  CommandBoundOK = not commandViolation;
  TensionBoundOK = not tensionViolation;
  SwingBoundOK = not swingViolation;
  NoGroundStrikeOK = not groundStrikeViolation;
  TrackingErrorOK = not trackingViolation and time >= 15.5;
  NumericOK = not numericViolation;
  Accept = time >= 15.5 and ThrustBoundOK and CommandBoundOK and TensionBoundOK and SwingBoundOK and NoGroundStrikeOK and TrackingErrorOK and NumericOK and TargetZoneOK;

  // 250 Hz controller and acceptance latch update
  when sample(0, Ts) then
    // Cable-angle rate estimate for swing damping
    cableAngleRateX = (cableAngleX - pre(cableAngleXPrev))/Ts;
    cableAngleRateY = (cableAngleY - pre(cableAngleYPrev))/Ts;
    cableAngleXPrev = cableAngleX;
    cableAngleYPrev = cableAngleY;

    aSwingX = max(-2.0, min(2.0, K_swing*L_cable*cableAngleRateX));
    aSwingY = max(-2.0, min(2.0, K_swing*L_cable*cableAngleRateY));

    gustFFx = if time >= T_gust_start and time <= T_gust_end then GustForce else 0.0;

    // Position controller with input shaping, cable swing damping, gust feedforward, and tension feedback
    Fw_x = m_total*(ad_x + Kp_pos*(rd_x - est_x) + Kd_pos*(vd_x - est_vx) + aSwingX) + gustFFx;
    Fw_y = m_total*(ad_y + Kp_pos*(rd_y - est_y) + Kd_pos*(vd_y - est_vy) + aSwingY);
    Fw_z = m_body*(ad_z + Kp_pos*(rd_z - est_z) + Kd_pos*(vd_z - est_vz)) + m_body*g + tension_meas;

    Fw_norm = max(sqrt(Fw_x*Fw_x + Fw_y*Fw_y + Fw_z*Fw_z), 1e-6);
    phi_d = asin(max(-1.0, min(1.0, -Fw_y/Fw_norm)));
    theta_d = atan2(Fw_x/Fw_norm, Fw_z/Fw_norm);
    psi_d = 0.0;

    Mx_d = max(-3.0, min(3.0, Kp_att*(phi_d - est_phi) + Kd_att*(0.0 - imu_p)));
    My_d = max(-3.0, min(3.0, Kp_att*(theta_d - est_theta) + Kd_att*(0.0 - imu_q)));
    Mz_d = max(-2.0, min(2.0, Kp_yaw*(psi_d - est_psi) + Kd_yaw*(0.0 - imu_r)));

    Tsum_d = Fw_norm;
    TcmdRaw1 = Tsum_d/4.0 + Mx_d/(4.0*a_arm) - My_d/(4.0*a_arm) + Mz_d/(4.0*kYaw);
    TcmdRaw2 = Tsum_d/4.0 + Mx_d/(4.0*a_arm) + My_d/(4.0*a_arm) - Mz_d/(4.0*kYaw);
    TcmdRaw3 = Tsum_d/4.0 - Mx_d/(4.0*a_arm) + My_d/(4.0*a_arm) + Mz_d/(4.0*kYaw);
    TcmdRaw4 = Tsum_d/4.0 - Mx_d/(4.0*a_arm) - My_d/(4.0*a_arm) - Mz_d/(4.0*kYaw);

    Tcmd1 = max(0.0, min(Tmax, TcmdRaw1));
    Tcmd2 = max(0.0, min(Tmax, TcmdRaw2));
    Tcmd3 = max(0.0, min(Tmax, TcmdRaw3));
    Tcmd4 = max(0.0, min(Tmax, TcmdRaw4));

    // Fail-closed acceptance latches
    thrustViolation = pre(thrustViolation) or (Tcmd1 > Tmax + eps or Tcmd1 < -eps or
                                               Tcmd2 > Tmax + eps or Tcmd2 < -eps or
                                               Tcmd3 > Tmax + eps or Tcmd3 < -eps or
                                               Tcmd4 > Tmax + eps or Tcmd4 < -eps);
    commandViolation = pre(commandViolation) or (Tcmd1 > Tmax + eps or Tcmd1 < -eps or
                                                 Tcmd2 > Tmax + eps or Tcmd2 < -eps or
                                                 Tcmd3 > Tmax + eps or Tcmd3 < -eps or
                                                 Tcmd4 > Tmax + eps or Tcmd4 < -eps);
    tensionViolation = pre(tensionViolation) or (tension < -eps or tension > tensionLimit + eps);
    swingViolation = pre(swingViolation) or (cableAngle > 0.45 + eps);
    groundStrikeViolation = pre(groundStrikeViolation) or (z_b <= 0.25 or z_p < -eps);
    trackingViolation = pre(trackingViolation) or (time >= 10.4 and trackingErrorNow > 0.27 + eps);

    maxTrackingErrorAfter = if time >= 10.4 then max(pre(maxTrackingErrorAfter), trackingErrorNow) else 0.0;

    numericViolation = pre(numericViolation) or not (
      abs(x_b) <= 1e30 and abs(y_b) <= 1e30 and abs(z_b) <= 1e30 and
      abs(vx_b) <= 1e30 and abs(vy_b) <= 1e30 and abs(vz_b) <= 1e30 and
      abs(phi) <= 1e30 and abs(theta) <= 1e30 and abs(psi) <= 1e30 and
      abs(p) <= 1e30 and abs(q) <= 1e30 and abs(r) <= 1e30 and
      abs(x_p) <= 1e30 and abs(y_p) <= 1e30 and abs(z_p) <= 1e30 and
      abs(vx_p) <= 1e30 and abs(vy_p) <= 1e30 and abs(vz_p) <= 1e30 and
      abs(tension) <= 1e30 and abs(T1) <= 1e30 and abs(T2) <= 1e30 and abs(T3) <= 1e30 and abs(T4) <= 1e30 and
      abs(Frot_x) <= 1e30 and abs(Frot_y) <= 1e30 and abs(Frot_z) <= 1e30 and
      abs(Mx_body) <= 1e30 and abs(My_body) <= 1e30 and abs(Mz_body) <= 1e30 and
      abs(a_b_x) <= 1e30 and abs(a_b_y) <= 1e30 and abs(a_b_z) <= 1e30 and
      abs(a_p_x) <= 1e30 and abs(a_p_y) <= 1e30 and abs(a_p_z) <= 1e30 and
      abs(Tcmd1) <= 1e30 and abs(Tcmd2) <= 1e30 and abs(Tcmd3) <= 1e30 and abs(Tcmd4) <= 1e30 and
      abs(TcmdRaw1) <= 1e30 and abs(TcmdRaw2) <= 1e30 and abs(TcmdRaw3) <= 1e30 and abs(TcmdRaw4) <= 1e30 and
      abs(Fw_x) <= 1e30 and abs(Fw_y) <= 1e30 and abs(Fw_z) <= 1e30 and abs(Fw_norm) <= 1e30 and
      abs(phi_d) <= 1e30 and abs(theta_d) <= 1e30 and abs(psi_d) <= 1e30 and
      abs(Mx_d) <= 1e30 and abs(My_d) <= 1e30 and abs(Mz_d) <= 1e30 and
      abs(aSwingX) <= 1e30 and abs(aSwingY) <= 1e30 and
      abs(cableAngleRateX) <= 1e30 and abs(cableAngleRateY) <= 1e30 and
      abs(gps_x) <= 1e30 and abs(gps_y) <= 1e30 and abs(gps_z) <= 1e30 and
      abs(gps_vx) <= 1e30 and abs(gps_vy) <= 1e30 and abs(gps_vz) <= 1e30 and
      abs(imu_ax_body) <= 1e30 and abs(imu_ay_body) <= 1e30 and abs(imu_az_body) <= 1e30 and
      abs(imu_phi) <= 1e30 and abs(imu_theta) <= 1e30 and abs(imu_psi) <= 1e30 and
      abs(imu_p) <= 1e30 and abs(imu_q) <= 1e30 and abs(imu_r) <= 1e30 and
      abs(cableAngleX) <= 1e30 and abs(cableAngleY) <= 1e30 and abs(cableAngle) <= 1e30 and
      abs(tension_meas) <= 1e30 and
      abs(est_x) <= 1e30 and abs(est_y) <= 1e30 and abs(est_z) <= 1e30 and
      abs(est_vx) <= 1e30 and abs(est_vy) <= 1e30 and abs(est_vz) <= 1e30 and
      abs(est_phi) <= 1e30 and abs(est_theta) <= 1e30 and abs(est_psi) <= 1e30 and
      abs(maxTrackingErrorAfter) <= 1e30);
  end when;

  annotation (experiment(StopTime=16.0, Interval=0.004, Tolerance=1e-6));
end QuadScoutDeliverE;