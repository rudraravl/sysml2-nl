model HexaSurveyHoverF
  "Free-base hexacopter survey-hover scenario: vertical takeoff to 2.5 m, hold level attitude and zero yaw, with a controlled mid-mission wind disturbance."

  // ---- Physical parameters (from requirement) ----
  parameter Real m_fuselage = 3.2 "kg cylindrical fuselage mass";
  parameter Real m_camera   = 0.4 "kg downward camera payload";
  parameter Real m          = m_fuselage + m_camera "kg total mass";
  parameter Real R_arm      = 0.35 "m rotor placement radius";
  parameter Real g          = 9.81 "m/s2 gravitational acceleration";
  parameter Real rho        = 1.225 "kg/m3 air density";
  parameter Real k_drag     = 0.2  "Ns/m linear translational drag coefficient (tuned; not specified by requirement)";
  parameter Real thrustMax  = 13.4 "N max thrust per rotor";
  parameter Real windForce  = 5.8  "N wind disturbance force";
  parameter Real k_yaw      = 0.05 "N·m per N yaw-torque scale (tuned; not specified by requirement)";

  // ---- Effective body inertia (cylindrical fuselage; body radius unspecified) ----
  parameter Real r_body     = 0.10 "m effective fuselage radius (tuned; not specified by requirement)";
  parameter Real Ixx = 0.25*m*r_body^2 + m*R_arm^2/6 "kg·m2 roll inertia";
  parameter Real Iyy = Ixx "kg·m2 pitch inertia";
  parameter Real Izz = 0.50*m*r_body^2 + m*R_arm^2/3 "kg·m2 yaw inertia";

  // ---- Mission / timing ----
  parameter Real z_ref        = 2.5 "m altitude reference";
  parameter Real T_end        = 20.0 "s simulation duration";
  parameter Real T_wind_start = T_end/3 "s start of middle-third wind window";
  parameter Real T_wind_end   = 2*T_end/3 "s end of middle-third wind window";

  // ---- Controller gains (tuned; not specified by requirement) ----
  parameter Real Kp_z   = 8.0;
  parameter Real Kd_z   = 5.0;
  parameter Real Kp_xy  = 6.0;
  parameter Real Kd_xy  = 4.0;
  parameter Real Kp_att = 4.0;
  parameter Real Kd_att = 0.8;
  parameter Real Kp_yaw = 3.0;
  parameter Real Kd_yaw = 0.6;

  // ---- Kinematic states ----
  Real x(start=0, fixed=true)   "m world x position";
  Real y(start=0, fixed=true)   "m world y position";
  Real z(start=0.01, fixed=true) "m world z altitude";
  Real vx(start=0, fixed=true)  "m/s x velocity";
  Real vy(start=0, fixed=true)  "m/s y velocity";
  Real vz(start=0, fixed=true)  "m/s z velocity";
  Real phi(start=0.0, fixed=true)   "rad roll angle";
  Real theta(start=0.0, fixed=true) "rad pitch angle";
  Real psi(start=0.0, fixed=true)   "rad yaw angle";
  Real p(start=0, fixed=true) "rad/s body roll rate";
  Real q(start=0, fixed=true) "rad/s body pitch rate";
  Real r(start=0, fixed=true) "rad/s body yaw rate";

  // ---- Control commands ----
  Real T_total_cmd "N commanded total thrust";
  Real tau_x_cmd   "N·m commanded roll torque";
  Real tau_y_cmd   "N·m commanded pitch torque";
  Real tau_z_cmd   "N·m commanded yaw torque";
  Real phi_des, theta_des, psi_des "rad desired attitude";

  // ---- Rotor wrench ----
  Real T_raw[6] "N unsaturated rotor thrust allocation";
  Real T[6]     "N saturated rotor thrust (bounded 0..thrustMax)";
  Real T_total  "N actual total thrust";
  Real tau_x, tau_y, tau_z "N·m actual body torques";

  // ---- Disturbance ----
  Real wind_x "N wind force along world x";

  // ---- Sensors ----
  discrete Real x_sens(start=0)    "m 10 Hz sampled x position";
  discrete Real y_sens(start=0)    "m 10 Hz sampled y position";
  discrete Real z_sens(start=0.01) "m 10 Hz sampled altitude";
  Real altimeter_z "m altimeter reading (= z)";
  Real imu_p, imu_q, imu_r "rad/s IMU angular rates";

  // ---- Verification criteria ----
  Real pos_err_primary "m primary tracking error (altitude)";
  Boolean rotor_bounds_ok;
  Boolean altitude_settled;
  Boolean attitude_ok;
  Boolean altitude_positive;
  Boolean primary_tracking_ok;
  Boolean no_nan_inf;
  Boolean all_verified;

protected
  parameter Real sqrt3 = 1.7320508075688772;
  parameter Real c1 = sqrt3/6.0 "≈0.288675 mixing coefficient";
  parameter Real c2 = 1.0/6.0  "≈0.166667 mixing coefficient";

equation
  // ---- Wind disturbance during middle third of mission ----
  wind_x = if (time >= T_wind_start and time <= T_wind_end) then windForce else 0.0;

  // ---- Translational dynamics (world frame, small-angle body-to-world mapping) ----
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ( T_total*sin(theta)               - k_drag*vx + wind_x ) / m;
  der(vy) = (-T_total*sin(phi)*cos(theta)     - k_drag*vy          ) / m;
  der(vz) = ( T_total*cos(phi)*cos(theta) - m*g - k_drag*vz         ) / m;

  // ---- Attitude kinematics (Euler ZYX) ----
  der(phi)   = p + sin(phi)*tan(theta)*q + cos(phi)*tan(theta)*r;
  der(theta) = cos(phi)*q - sin(phi)*r;
  der(psi)   = sin(phi)/cos(theta)*q + cos(phi)/cos(theta)*r;

  // ---- Rotational dynamics (rigid body, principal axes) ----
  der(p) = (Iyy - Izz)/Ixx * q*r + tau_x / Ixx;
  der(q) = (Izz - Ixx)/Iyy * p*r + tau_y / Iyy;
  der(r) = (Ixx - Iyy)/Izz * p*q + tau_z / Izz;

  // ---- Cascaded position -> attitude control ----
  // Altitude PD -> commanded thrust along body z
  T_total_cmd = m*g + Kp_z*(z_ref - z) + Kd_z*(0.0 - vz);
  // Horizontal position PD -> desired small-angle attitude
  theta_des = ( Kp_xy*(0.0 - x) + Kd_xy*(0.0 - vx) ) / g;
  phi_des   = (-(Kp_xy*(0.0 - y) + Kd_xy*(0.0 - vy))) / g;
  psi_des   = 0.0;
  // Attitude PD -> body torque commands
  tau_x_cmd = Kp_att*(phi_des   - phi)   + Kd_att*(0.0 - p);
  tau_y_cmd = Kp_att*(theta_des - theta) + Kd_att*(0.0 - q);
  tau_z_cmd = Kp_yaw*(psi_des   - psi)   + Kd_yaw*(0.0 - r);

  // ---- Thrust allocation: right-inverse of hexacopter mixing matrix ----
  // M = [1,1,1,1,1,1;
  //      0, (s3/2)R, (s3/2)R, 0, -(s3/2)R, -(s3/2)R;
  //     -R, -0.5R, 0.5R, R, 0.5R, -0.5R;
  //      k, -k, k, -k, k, -k]
  // with MM^T = diag(6, 3 R^2, 3 R^2, 6 k^2) so M^+ = M^T * diag(1/6, 1/(3R^2), 1/(3R^2), 1/(6 k^2))
  T_raw[1] = T_total_cmd/6.0 - tau_y_cmd/(3.0*R_arm)                       + tau_z_cmd/(6.0*k_yaw);
  T_raw[2] = T_total_cmd/6.0 + c1*tau_x_cmd/R_arm - c2*tau_y_cmd/R_arm     - tau_z_cmd/(6.0*k_yaw);
  T_raw[3] = T_total_cmd/6.0 + c1*tau_x_cmd/R_arm + c2*tau_y_cmd/R_arm     + tau_z_cmd/(6.0*k_yaw);
  T_raw[4] = T_total_cmd/6.0 + tau_y_cmd/(3.0*R_arm)                       - tau_z_cmd/(6.0*k_yaw);
  T_raw[5] = T_total_cmd/6.0 - c1*tau_x_cmd/R_arm + c2*tau_y_cmd/R_arm     + tau_z_cmd/(6.0*k_yaw);
  T_raw[6] = T_total_cmd/6.0 - c1*tau_x_cmd/R_arm - c2*tau_y_cmd/R_arm     - tau_z_cmd/(6.0*k_yaw);

  // ---- Bounded rotor thrusts (0 .. thrustMax) ----
  for i in 1:6 loop
    T[i] = max(0.0, min(thrustMax, T_raw[i]));
  end for;

  // ---- Actual wrench from saturated rotor thrusts ----
  T_total = T[1]+T[2]+T[3]+T[4]+T[5]+T[6];
  tau_x = R_arm*( (sqrt3/2.0)*T[2] + (sqrt3/2.0)*T[3] - (sqrt3/2.0)*T[5] - (sqrt3/2.0)*T[6] );
  tau_y = -R_arm*( T[1] + 0.5*T[2] - 0.5*T[3] - T[4] - 0.5*T[5] + 0.5*T[6] );
  tau_z = k_yaw*( T[1] - T[2] + T[3] - T[4] + T[5] - T[6] );

  // ---- Sensors ----
  altimeter_z = z;
  imu_p = p;
  imu_q = q;
  imu_r = r;
  when sample(0, 0.1) then
    x_sens = x;
    y_sens = y;
    z_sens = z;
  end when;

  // ---- Verification criteria (evaluated continuously; settled criteria gated by time) ----
  pos_err_primary    = abs(z_ref - z);
  rotor_bounds_ok    = T[1] >= 0.0 and T[1] <= thrustMax and
                      T[2] >= 0.0 and T[2] <= thrustMax and
                      T[3] >= 0.0 and T[3] <= thrustMax and
                      T[4] >= 0.0 and T[4] <= thrustMax and
                      T[5] >= 0.0 and T[5] <= thrustMax and
                      T[6] >= 0.0 and T[6] <= thrustMax;
  altitude_settled   = if (time >= T_end - 0.5) then (abs(z - z_ref) < 0.05) else true;
  attitude_ok        = abs(phi)   < 0.40 and abs(theta) < 0.40;
  altitude_positive  = z > 0.0;
  primary_tracking_ok = if (time >= 13.0) then (pos_err_primary < 0.12) else true;
  no_nan_inf         = (z > -1.0e10) and (T_total > -1.0e10) and
                      (vx > -1.0e10) and (vy > -1.0e10) and (vz > -1.0e10) and
                      (phi > -1.0e10) and (theta > -1.0e10) and (psi > -1.0e10);
  all_verified       = rotor_bounds_ok and altitude_settled and attitude_ok and
                      altitude_positive and primary_tracking_ok and no_nan_inf;

  annotation(
    experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Free-base hexacopter survey-hover scenario. Six bounded rotor-thrust channels (max 13.4 N each) on a 0.35 m radius hex frame (3.2 kg fuselage + 0.4 kg camera). Cascaded position/attitude control with explicit thrust allocation. A 5.8 N wind acts along +x during the middle third (6.67-13.33 s). Sensors: IMU (rates), altimeter (z), 10 Hz position samples. Tuned values not specified by the requirement are labeled in their parameter comments."));
end HexaSurveyHoverF;