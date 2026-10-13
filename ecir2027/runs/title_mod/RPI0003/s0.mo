model QuadScoutHoverC
  // ===== Parameters (SI units) =====
  parameter Real m = 1.8 "fuselage mass [kg]";
  parameter Real L = 0.22 "rotor arm length [m]";
  parameter Real d = L/sqrt(2.0) "rotor in-plane offset [m]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real rho = 1.225 "air density [kg/m3]";
  parameter Real k_drag = 0.6 "linear translational drag coefficient [N.s/m]";
  parameter Real k_yaw = 0.05 "rotor yaw torque coefficient [N.m per N] (physical value unspecified; assumed)";
  parameter Real Tmax = 11.0 "max rotor thrust command per rotor [N]";
  // Box fuselage dimensions unspecified; assumed diagonal inertia
  parameter Real Ixx = 0.025 "roll inertia [kg.m2] (box dims unspecified; assumed)";
  parameter Real Iyy = 0.025 "pitch inertia [kg.m2] (assumed)";
  parameter Real Izz = 0.045 "yaw inertia [kg.m2] (assumed)";
  // Setpoint
  parameter Real z_des = 2.5 "target hover altitude [m]";
  // Controller gains
  parameter Real Kp_z = 6.0 "altitude proportional gain [1/s2]";
  parameter Real Kd_z = 4.0 "altitude derivative gain [1/s]";
  parameter Real Kp_xy = 14.0 "horizontal position proportional gain [1/s2]";
  parameter Real Kd_xy = 5.0 "horizontal position derivative gain [1/s]";
  parameter Real Kp_att = 2.5 "attitude proportional gain [N.m/rad]";
  parameter Real Kd_att = 0.4 "attitude rate derivative gain [N.m.s/rad]";
  parameter Real Kp_yaw = 2.0 "yaw proportional gain [N.m/rad]";
  parameter Real Kd_yaw = 0.4 "yaw rate derivative gain [N.m.s/rad]";
  // Disturbance
  parameter Real F_wind = 3.6 "wind force magnitude [N]";
  // Timing
  parameter Real Ts_ctrl = 1.0/125.0 "control loop period [s]";
  parameter Real Ts_pos = 0.1 "position sensor period [s]";
  parameter Real t_wind_on = 4.0 "wind disturbance start [s]";
  parameter Real t_wind_off = 8.0 "wind disturbance stop [s]";

  // ===== Continuous plant states =====
  Real x(start=0.0) "world x position [m]";
  Real y(start=0.0) "world y position [m]";
  Real z(start=0.0) "world z position [m]";
  Real vx(start=0.0) "world x velocity [m/s]";
  Real vy(start=0.0) "world y velocity [m/s]";
  Real vz(start=0.0) "world z velocity [m/s]";
  Real phi(start=0.0) "roll angle [rad]";
  Real theta(start=0.0) "pitch angle [rad]";
  Real psi(start=0.0) "yaw angle [rad]";
  Real p(start=0.0) "body roll rate [rad/s]";
  Real q(start=0.0) "body pitch rate [rad/s]";
  Real r(start=0.0) "body yaw rate [rad/s]";

  // ===== Rotor commands (discrete, clamped) =====
  discrete Real T1(start=4.41) "rotor 1 thrust command [N]";
  discrete Real T2(start=4.41) "rotor 2 thrust command [N]";
  discrete Real T3(start=4.41) "rotor 3 thrust command [N]";
  discrete Real T4(start=4.41) "rotor 4 thrust command [N]";
  discrete Real T1_raw, T2_raw, T3_raw, T4_raw "unclamped rotor commands [N]";

  // ===== Applied forces/moments (from clamped commands) =====
  Real U1_act "total thrust along body z [N]";
  Real Mx_act "roll moment [N.m]";
  Real My_act "pitch moment [N.m]";
  Real Mz_act "yaw moment [N.m]";

  // ===== Controller internals (discrete) =====
  discrete Real U1_cmd "commanded total thrust [N]";
  discrete Real Mx_cmd "commanded roll moment [N.m]";
  discrete Real My_cmd "commanded pitch moment [N.m]";
  discrete Real Mz_cmd "commanded yaw moment [N.m]";
  discrete Real phi_d "commanded roll [rad]";
  discrete Real theta_d "commanded pitch [rad]";
  discrete Real Fx_des "desired world x force [N]";
  discrete Real Fy_des "desired world y force [N]";
  discrete Real Fz_des "desired world z force [N]";
  discrete Real U1_mag "desired thrust magnitude [N]";

  // ===== Sensors =====
  Real z_alt "altimeter altitude [m]";
  Real imu_phi "IMU roll [rad]";
  Real imu_theta "IMU pitch [rad]";
  Real imu_psi "IMU yaw [rad]";
  Real imu_p "IMU roll rate [rad/s]";
  Real imu_q "IMU pitch rate [rad/s]";
  Real imu_r "IMU yaw rate [rad/s]";
  discrete Real x_meas(start=0.0) "10 Hz position sensor x [m]";
  discrete Real y_meas(start=0.0) "10 Hz position sensor y [m]";
  discrete Real z_meas_pos(start=0.0) "10 Hz position sensor z [m]";
  discrete Real vx_est(start=0.0) "x velocity estimate from 10 Hz position [m/s]";
  discrete Real vy_est(start=0.0) "y velocity estimate from 10 Hz position [m/s]";
  discrete Real vz_est(start=0.0) "z velocity estimate from altimeter [m/s]";
  discrete Real x_prev(start=0.0) "previous x sample [m]";
  discrete Real y_prev(start=0.0) "previous y sample [m]";
  discrete Real z_prev(start=0.0) "previous z altimeter sample [m]";

  // ===== Wind =====
  Real Wind_x "wind force x [N]";
  Real Wind_y "wind force y [N]";
  Real Wind_z "wind force z [N]";

  // ===== Kinematics helpers =====
  Real cphi, sphi, ctheta, stheta, cpsi, spsi, ctheta_safe;
  Real R03, R13, R23;
  Real Fx_thrust, Fy_thrust, Fz_thrust;

  // ===== Monitors / traces =====
  Real err_z "altitude tracking error (signed) [m]";
  Real err_xy "horizontal position error norm [m]";
  Real monitor_Tmax "maximum rotor command [N]";
  Real monitor_Tmin "minimum rotor command [N]";
  Boolean rotor_bound_ok;
  Boolean attitude_ok;
  Boolean altitude_positive_ok;
  Boolean tracking_ok_after_7p8;

equation
  // Trigonometric helpers
  cphi = cos(phi);
  sphi = sin(phi);
  ctheta = cos(theta);
  stheta = sin(theta);
  cpsi = cos(psi);
  spsi = sin(psi);
  ctheta_safe = if ctheta > 0.01 then ctheta else 0.01;

  // Body-to-world rotation: third column (thrust direction)
  R03 = cpsi*stheta*cphi + spsi*sphi;
  R13 = spsi*stheta*cphi - cpsi*sphi;
  R23 = ctheta*cphi;

  // Thrust expressed in world frame
  Fx_thrust = U1_act * R03;
  Fy_thrust = U1_act * R13;
  Fz_thrust = U1_act * R23;

  // Wind disturbance injected during the middle third of the 12 s run
  Wind_x = if (time >= t_wind_on and time <= t_wind_off) then F_wind else 0.0;
  Wind_y = 0.0;
  Wind_z = 0.0;

  // Translational dynamics (world-frame velocities, linear drag)
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  m*der(vx) = Fx_thrust + Wind_x - k_drag*vx;
  m*der(vy) = Fy_thrust + Wind_y - k_drag*vy;
  m*der(vz) = Fz_thrust - m*g + Wind_z - k_drag*vz;

  // Attitude kinematics (ZYX Euler convention)
  der(phi)   = p + (q*sphi + r*cphi)*tan(theta);
  der(theta) = q*cphi - r*sphi;
  der(psi)   = (q*sphi + r*cphi)/ctheta_safe;

  // Rotational dynamics (rigid body, body frame)
  Ixx*der(p) = (Iyy - Izz)*q*r + Mx_act;
  Iyy*der(q) = (Izz - Ixx)*p*r + My_act;
  Izz*der(r) = (Ixx - Iyy)*p*q + Mz_act;

  // Rotor mixing from clamped commands (X-config)
  U1_act = T1 + T2 + T3 + T4;
  Mx_act = d*(T1 + T2 - T3 - T4);
  My_act = d*(-T1 + T2 + T3 - T4);
  Mz_act = k_yaw*(T1 - T2 + T3 - T4);

  // Ideal instrumentation (continuous) -- estimator treated as ideal
  z_alt = z;
  imu_phi = phi;
  imu_theta = theta;
  imu_psi = psi;
  imu_p = p;
  imu_q = q;
  imu_r = r;

  // Monitors and requirement checks
  err_z = z - z_des;
  err_xy = sqrt(x*x + y*y);
  monitor_Tmax = max({T1, T2, T3, T4});
  monitor_Tmin = min({T1, T2, T3, T4});
  rotor_bound_ok = (monitor_Tmin >= 0.0) and (monitor_Tmax <= Tmax + 1e-6);
  attitude_ok = (abs(phi) < 0.40) and (abs(theta) < 0.40);
  altitude_positive_ok = z > 0.0;
  tracking_ok_after_7p8 = (time >= 7.8) and (abs(err_z) < 0.158);

algorithm
  // 10 Hz position sensor with finite-difference velocity estimate
  when sample(0, Ts_pos) then
    x_meas := x;
    y_meas := y;
    z_meas_pos := z;
    vx_est := (x - x_prev)/Ts_pos;
    vy_est := (y - y_prev)/Ts_pos;
    x_prev := x;
    y_prev := y;
  end when;

  // 125 Hz cascaded position + attitude controller with thrust allocation
  when sample(0, Ts_ctrl) then
    // Outer loop: desired world forces (altimeter for z, 10 Hz position for x/y)
    Fz_des := m*(Kp_z*(z_des - z_alt) - Kd_z*vz_est + g);
    Fx_des := m*(Kp_xy*(0.0 - x_meas) - Kd_xy*vx_est);
    Fy_des := m*(Kp_xy*(0.0 - y_meas) - Kd_xy*vy_est);
    // Thrust magnitude (guarded against zero)
    U1_mag := sqrt(Fx_des*Fx_des + Fy_des*Fy_des + Fz_des*Fz_des);
    U1_cmd := if U1_mag < 0.1 then 0.1 else U1_mag;
    // Desired attitude from desired thrust direction (yaw setpoint = 0)
    phi_d := -asin(if (Fy_des/U1_cmd) > 1.0 then 1.0 elseif (Fy_des/U1_cmd) < -1.0 then -1.0 else (Fy_des/U1_cmd));
    theta_d := atan2(Fx_des, Fz_des);
    // Inner loop: attitude controller -> desired body moments
    Mx_cmd := Kp_att*(phi_d - imu_phi) + Kd_att*(0.0 - imu_p);
    My_cmd := Kp_att*(theta_d - imu_theta) + Kd_att*(0.0 - imu_q);
    Mz_cmd := Kp_yaw*(0.0 - imu_psi) + Kd_yaw*(0.0 - imu_r);
    // Thrust allocation: inverse mixing to individual rotor commands
    T1_raw := (U1_cmd + Mx_cmd/d - My_cmd/d + Mz_cmd/k_yaw)/4.0;
    T2_raw := (U1_cmd + Mx_cmd/d + My_cmd/d - Mz_cmd/k_yaw)/4.0;
    T3_raw := (U1_cmd - Mx_cmd/d + My_cmd/d + Mz_cmd/k_yaw)/4.0;
    T4_raw := (U1_cmd - Mx_cmd/d - My_cmd/d - Mz_cmd/k_yaw)/4.0;
    // Rotor command saturation to [0, Tmax] N
    T1 := if T1_raw < 0.0 then 0.0 elseif T1_raw > Tmax then Tmax else T1_raw;
    T2 := if T2_raw < 0.0 then 0.0 elseif T2_raw > Tmax then Tmax else T2_raw;
    T3 := if T3_raw < 0.0 then 0.0 elseif T3_raw > Tmax then Tmax else T3_raw;
    T4 := if T4_raw < 0.0 then 0.0 elseif T4_raw > Tmax then Tmax else T4_raw;
    // Altimeter-derived vertical velocity estimate at control rate
    vz_est := (z_alt - z_prev)*125.0;
    z_prev := z_alt;
  end when;

  annotation(experiment(StopTime=12.0, NumberOfIntervals=1500, Tolerance=1e-6));
end QuadScoutHoverC;