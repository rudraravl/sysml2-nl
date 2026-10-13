model QuadScoutHoverD
  // ===== Stated physical parameters =====
  parameter Real m = 1.8 "Fuselage mass [kg]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real rho_air = 1.225 "Air density [kg/m3] (stated; linear drag uses assumed coefficient)";
  parameter Real L_arm = 0.22 "Rotor arm length [m]";
  parameter Real Tmax = 12.0 "Per-rotor thrust limit [N]";
  parameter Real z_target = 2.5 "Settling altitude [m]";
  parameter Real F_wind = 4.0 "Wind disturbance force magnitude [N]";
  parameter Real T_sim = 14.0 "Run duration [s]";
  parameter Real fs_ctrl = 200.0 "Control loop rate [Hz]";
  parameter Real Ts_ctrl = 1.0/fs_ctrl "Control period [s]";
  parameter Real fs_pos = 10.0 "Position sensor rate [Hz]";
  parameter Real Ts_pos = 1.0/fs_pos "Position sensor period [s]";

  // ===== Assumed parameters (not stated in request; labeled) =====
  parameter Real cd = 0.8 "Linear translational drag coefficient [N.s/m] (ASSUMED)";
  parameter Real Ixx = 0.018 "Roll inertia [kg.m2] (ASSUMED box fuselage)";
  parameter Real Iyy = 0.018 "Pitch inertia [kg.m2] (ASSUMED)";
  parameter Real Izz = 0.036 "Yaw inertia [kg.m2] (ASSUMED)";
  parameter Real km = 0.012 "Yaw moment per rotor thrust coefficient [N.m/N] (ASSUMED)";
  parameter Real windDirX = 1.0 "Wind direction unit x (ASSUMED +x)";
  parameter Real windDirY = 0.0 "Wind direction unit y (ASSUMED)";

  // ===== Controller gains (ASSUMED, tuned for hover settling) =====
  parameter Real Kp_z = 6.0;
  parameter Real Kd_z = 4.5;
  parameter Real Kp_xy = 18.0;
  parameter Real Kd_xy = 6.0;
  parameter Real Kp_att = 60.0;
  parameter Real Kd_att = 10.0;
  parameter Real Kp_psi = 6.0;
  parameter Real Kd_psi = 2.5;

  // ===== Continuous plant states =====
  Real x(start=0.0) "World x [m]";
  Real y(start=0.0) "World y [m]";
  Real z(start=0.001) "World z, altitude [m]";
  Real vx(start=0.0) "World x velocity [m/s]";
  Real vy(start=0.0) "World y velocity [m/s]";
  Real vz(start=0.0) "World z velocity [m/s]";
  Real phi(start=0.0) "Roll [rad]";
  Real theta(start=0.0) "Pitch [rad]";
  Real psi(start=0.0) "Yaw [rad]";
  Real p(start=0.0) "Body roll rate [rad/s]";
  Real q(start=0.0) "Body pitch rate [rad/s]";
  Real r(start=0.0) "Body yaw rate [rad/s]";

  // ===== Sensors =====
  Real altZ "Altimeter altitude [m]";
  Real imuRoll "IMU roll [rad]";
  Real imuPitch "IMU pitch [rad]";
  Real imuYaw "IMU yaw [rad]";
  Real imuP "IMU roll rate [rad/s]";
  Real imuQ "IMU pitch rate [rad/s]";
  Real imuR "IMU yaw rate [rad/s]";
  discrete Real posSensorX(start=0.0) "10 Hz position sensor x [m]";
  discrete Real posSensorY(start=0.0) "10 Hz position sensor y [m]";
  discrete Real posSensorX_prev(start=0.0);
  discrete Real posSensorY_prev(start=0.0);
  discrete Real vx_est(start=0.0) "Estimated x velocity from 10 Hz position [m/s]";
  discrete Real vy_est(start=0.0) "Estimated y velocity from 10 Hz position [m/s]";
  discrete Real vz_est(start=0.0) "Estimated z velocity from altimeter [m/s]";
  discrete Real altZ_prev(start=0.001);

  // ===== Controller discrete outputs =====
  discrete Real ax_des(start=0.0) "Desired world x acceleration [m/s2]";
  discrete Real ay_des(start=0.0) "Desired world y acceleration [m/s2]";
  discrete Real az_des(start=0.0) "Desired world z acceleration [m/s2]";
  discrete Real T_tot_cmd(start=0.0) "Commanded total thrust [N]";
  discrete Real phi_des(start=0.0) "Desired roll [rad]";
  discrete Real theta_des(start=0.0) "Desired pitch [rad]";
  discrete Real Mroll_cmd(start=0.0) "Desired roll moment [N.m]";
  discrete Real Mpitch_cmd(start=0.0) "Desired pitch moment [N.m]";
  discrete Real Myaw_cmd(start=0.0) "Desired yaw moment [N.m]";
  discrete Real T1_cmd(start=0.0) "Rotor 1 thrust command [N]";
  discrete Real T2_cmd(start=0.0) "Rotor 2 thrust command [N]";
  discrete Real T3_cmd(start=0.0) "Rotor 3 thrust command [N]";
  discrete Real T4_cmd(start=0.0) "Rotor 4 thrust command [N]";

  // ===== Actuator (saturated) =====
  Real T1 "Rotor 1 thrust [N]";
  Real T2 "Rotor 2 thrust [N]";
  Real T3 "Rotor 3 thrust [N]";
  Real T4 "Rotor 4 thrust [N]";
  Real T_total "Total thrust [N]";
  Real Mroll "Actual roll moment [N.m]";
  Real Mpitch "Actual pitch moment [N.m]";
  Real Myaw "Actual yaw moment [N.m]";

  // ===== Disturbance =====
  Real Fwind_x "Wind force x component [N]";
  Real Fwind_y "Wind force y component [N]";

  // ===== Helpers / observables =====
  Real cphi, sphi, ctheta, stheta, cpsi, spsi;
  Real b3x, b3y, b3z;
  Real cosPhiTheta;
  Real trackErr "Primary tracking error [m]";

equation
  // Trigonometric helpers
  cphi = cos(phi); sphi = sin(phi);
  ctheta = cos(theta); stheta = sin(theta);
  cpsi = cos(psi); spsi = sin(psi);

  // Body z-axis expressed in world frame (ZYX yaw-pitch-roll)
  b3x = -stheta*cpsi + ctheta*sphi*spsi;
  b3y = stheta*spsi + ctheta*sphi*cpsi;
  b3z = ctheta*cphi;
  cosPhiTheta = max(b3z, 0.5);

  // Continuous high-rate sensors (IMU, altimeter) - ideal
  altZ = z;
  imuRoll = phi; imuPitch = theta; imuYaw = psi;
  imuP = p; imuQ = q; imuR = r;

  // Wind disturbance: 4 N during middle third of the run
  Fwind_x = if (time >= T_sim/3.0 and time <= 2.0*T_sim/3.0) then F_wind*windDirX else 0.0;
  Fwind_y = if (time >= T_sim/3.0 and time <= 2.0*T_sim/3.0) then F_wind*windDirY else 0.0;

  // Translational dynamics in world frame with linear drag
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  m*der(vx) = T_total*b3x - cd*vx + Fwind_x;
  m*der(vy) = T_total*b3y - cd*vy + Fwind_y;
  m*der(vz) = T_total*b3z - cd*vz - m*g;

  // Attitude kinematics (ZYX Euler)
  der(phi) = p + (sphi*q + cphi*r)*stheta/ctheta;
  der(theta) = cphi*q - sphi*r;
  der(psi) = (sphi*q + cphi*r)/ctheta;

  // Rotational dynamics (gyroscopic rotor coupling neglected)
  Ixx*der(p) = Mroll + (Iyy - Izz)*q*r;
  Iyy*der(q) = Mpitch + (Izz - Ixx)*p*r;
  Izz*der(r) = Myaw + (Ixx - Iyy)*p*q;

  // Saturated actuator outputs (rotor bounds 0..12 N)
  T1 = max(0.0, min(Tmax, T1_cmd));
  T2 = max(0.0, min(Tmax, T2_cmd));
  T3 = max(0.0, min(Tmax, T3_cmd));
  T4 = max(0.0, min(Tmax, T4_cmd));

  // Total thrust and body moments produced by rotors
  T_total = T1 + T2 + T3 + T4;
  Mroll = L_arm*(T2 - T4);
  Mpitch = L_arm*(T3 - T1);
  Myaw = km*(T1 - T2 + T3 - T4);

  // Primary tracking error (3D position error w.r.t. hover setpoint)
  trackErr = sqrt(x*x + y*y + (z - z_target)*(z - z_target));

  // ===== Cascaded position + attitude controller at 200 Hz =====
  when sample(0.0, Ts_ctrl) then
    // Vertical velocity estimate from altimeter differentiation
    vz_est = (altZ - pre(altZ_prev))/Ts_ctrl;
    altZ_prev = altZ;

    // Outer position loop -> desired world acceleration
    az_des = Kp_z*(z_target - altZ) + Kd_z*(0.0 - vz_est);
    ax_des = Kp_xy*(0.0 - posSensorX) + Kd_xy*(0.0 - vx_est);
    ay_des = Kp_xy*(0.0 - posSensorY) + Kd_xy*(0.0 - vy_est);

    // Total thrust command (gravity compensation, attitude-corrected)
    T_tot_cmd = m*(az_des + g)/max(b3z, 0.5);

    // Desired attitude from desired horizontal acceleration (yaw hold = 0)
    theta_des = -asin(max(-0.95, min(0.95, ax_des*m/max(T_tot_cmd, 1e-3))));
    phi_des = asin(max(-0.95, min(0.95, ay_des*m/max(T_tot_cmd, 1e-3))));

    // Inner attitude loop -> desired body moments
    Mroll_cmd = Kp_att*(phi_des - imuRoll) + Kd_att*(0.0 - imuP);
    Mpitch_cmd = Kp_att*(theta_des - imuPitch) + Kd_att*(0.0 - imuQ);
    Myaw_cmd = Kp_psi*(0.0 - imuYaw) + Kd_psi*(0.0 - imuR);

    // Thrust allocation (inverse: total thrust + moments -> rotor thrusts)
    T1_cmd = T_tot_cmd/4.0 - Mpitch_cmd/(2.0*L_arm) + Myaw_cmd/(4.0*km);
    T2_cmd = T_tot_cmd/4.0 + Mroll_cmd/(2.0*L_arm) - Myaw_cmd/(4.0*km);
    T3_cmd = T_tot_cmd/4.0 + Mpitch_cmd/(2.0*L_arm) + Myaw_cmd/(4.0*km);
    T4_cmd = T_tot_cmd/4.0 - Mroll_cmd/(2.0*L_arm) - Myaw_cmd/(4.0*km);
  end when;

  // ===== 10 Hz position sensor with velocity estimation =====
  when sample(0.0, Ts_pos) then
    posSensorX = x;
    posSensorY = y;
    vx_est = (x - pre(posSensorX_prev))/Ts_pos;
    vy_est = (y - pre(posSensorY_prev))/Ts_pos;
    posSensorX_prev = x;
    posSensorY_prev = y;
  end when;

  annotation (
    experiment(StopTime=14.0, Tolerance=1e-6, Interval=0.005),
    Documentation(info="QuadScoutHoverD: instrumented 1.8 kg quadrotor (1.8 kg box fuselage, 4 rotors at 0.22 m). Each rotor produces thrust along body Z and a signed yaw moment. Cascaded position/attitude control with thrust allocation, per-rotor saturation 0..12 N, linear translational drag, 4 N wind force during middle third of a 14 s run at 200 Hz. Sensors: IMU (continuous roll/pitch/yaw and rates), altimeter (continuous altitude), 10 Hz position sensor. Assumed parameters (drag coefficient, inertias, yaw moment coefficient, wind direction, controller gains) are labeled in comments."));
end QuadScoutHoverD;