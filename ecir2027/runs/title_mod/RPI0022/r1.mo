model QuadScoutTouchD
  "Instrumented free-base quadrotor approaching and probing a vertical wall;
   position-to-impedance hybrid control with wind disturbance."

  // --- Physical parameters (from requirement) ---
  parameter Real m_fuselage = 1.8 "Fuselage mass [kg]";
  parameter Real arm_length = 0.22 "Rotor arm length [m]";
  parameter Real thrust_max  = 12.0 "Per-rotor thrust limit [N]";
  parameter Real g_acc       = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real wall_x       = 2.0  "Vertical wall x-position [m]";
  parameter Real mu_wall      = 0.55 "Wall friction coefficient [-]";
  parameter Real F_wind_dist  = 3.0  "Tangential wind disturbance magnitude [N]";
  parameter Real F_target     = 9.0  "Target normal probe force [N]";
  parameter Real F_min        = 5.0  "Minimum contact force during hold [N]";
  parameter Real F_max        = 14.0 "Maximum contact force during hold [N]";
  parameter Real Ts_ctrl      = 0.005 "Intended control period [s] (200 Hz)";

  // --- Assumed embodiment values (not specified; documented as assumptions) ---
  parameter Real d_probe   = 0.30 "Probe offset from fuselage center [m] (assumed; ensures rotor clearance)";
  parameter Real stand_off = 0.05 "Stand-off distance of probe tip from wall [m] (assumed)";
  parameter Real k_contact = 1000.0 "Contact spring stiffness [N/m] (assumed)";
  parameter Real d_contact = 80.0   "Contact damper [N.s/m] (assumed)";
  parameter Real Ixx_inertia = 0.025 "Roll inertia [kg.m2] (assumed)";
  parameter Real Iyy_inertia = 0.025 "Pitch inertia [kg.m2] (assumed)";
  parameter Real Izz_inertia = 0.045 "Yaw inertia [kg.m2] (assumed)";
  parameter Real c_tau_yaw   = 0.05 "Yaw torque per thrust unit (assumed)";

  // --- Control gains (assumed tunings) ---
  parameter Real Kp_pos  = 10.0 "Position proportional gain [1/s2]";
  parameter Real Kd_pos  = 5.0  "Position derivative gain [1/s]";
  parameter Real Kp_att  = 40.0 "Attitude proportional gain [1/s2]";
  parameter Real Kd_att  = 12.0 "Attitude derivative gain [1/s]";
  parameter Real Kff_frc = 3.0  "Force-tracking gain for impedance [1/(kg.s)]";
  parameter Real Kd_con  = 15.0 "Contact damping gain [1/s]";
  parameter Real v_lim   = 0.30 "Approach speed limit [m/s]";
  parameter Real att_lim = 0.40 "Attitude command limit [rad]";

  // --- Phase timing ---
  parameter Real t_contact = 9.0 "Start of contact phase [s]";
  parameter Real t_hold    = 10.5 "Start of hold (last quarter) [s]";

  // --- State: position and velocity ---
  Real x(start = 0.0)  "Fuselage x-position [m]";
  Real y(start = 0.0)  "Fuselage y-position [m]";
  Real z(start = 1.0)  "Fuselage z-position [m]";
  Real vx(start = 0.0) "World x-velocity [m/s]";
  Real vy(start = 0.0) "World y-velocity [m/s]";
  Real vz(start = 0.0) "World z-velocity [m/s]";

  // --- State: attitude and angular rates ---
  Real phi(start = 0.0)   "Roll angle [rad]";
  Real theta(start = 0.0) "Pitch angle [rad]";
  Real psi(start = 0.0)   "Yaw angle [rad]";
  Real p(start = 0.0)     "Body roll rate [rad/s]";
  Real q(start = 0.0)    "Body pitch rate [rad/s]";
  Real r(start = 0.0)    "Body yaw rate [rad/s]";

  // --- Rotation matrix (body-to-world) third column ---
  Real R13, R23, R33;

  // --- Contact model ---
  Real penetration "Probe penetration into wall [m]";
  Real F_contact   "Normal contact force magnitude [N]";
  Real F_cx_robot  "Contact force on robot, x-component [N]";
  Real F_cy_robot  "Friction force on robot, y-component [N]";
  Boolean in_contact;

  // --- Wind disturbance ---
  Real F_wind_y "Tangential wind force [N]";

  // --- Controller variables ---
  Boolean contact_phase;
  Real x_des, y_des, z_des;
  Real v_des_x, v_des_y, v_des_z;
  Real a_des_x, a_des_y, a_des_z;
  Real Fx_cmd, Fy_cmd, Fz_cmd;
  Real T_mag_cmd;
  Real phi_des_raw, theta_des_raw;
  Real phi_des_c, theta_des_c;
  Real Mx_cmd, My_cmd, Mz_cmd;

  // --- Rotor thrust commands (allocated, clamped) ---
  Real T1_raw, T2_raw, T3_raw, T4_raw;
  Real T1, T2, T3, T4;
  Real T_actual, Mx_actual, My_actual, Mz_actual;

  // --- Sensor outputs ---
  // IMU
  Real x_imu, y_imu, z_imu;
  Real phi_imu, theta_imu, psi_imu;
  Real p_imu, q_imu, r_imu;
  // Lidar
  Real lidar_range "Distance from probe tip to wall [m]";
  // Optical flow
  Real flow_x, flow_y;
  // Probe force
  Real F_probe "Measured normal probe force [N]";

  // --- Performance metrics ---
  Real track_error "Stand-off tracking error |x - x_so| [m]";
  Real force_error "|F_contact - F_target| [N]";

  // --- Derived constants ---
  Real x_so "Stand-off fuselage x-position [m]";

equation
  x_so = wall_x - d_probe - stand_off;

  // ===== Rotation matrix (ZYX Euler, body-to-world), third column =====
  R13 = cos(psi) * sin(theta) * cos(phi) + sin(psi) * sin(phi);
  R23 = sin(psi) * sin(theta) * cos(phi) - cos(psi) * sin(phi);
  R33 = cos(theta) * cos(phi);

  // ===== Contact model (fixed collidable box at wall_x) =====
  penetration = max(0.0, (x + d_probe) - wall_x);
  in_contact  = penetration > 1e-6;
  F_contact   = if penetration > 0.0
               then max(0.0, k_contact * penetration + d_contact * vx)
               else 0.0;
  F_cx_robot  = -F_contact;
  F_cy_robot  = if penetration > 0.0
               then -mu_wall * F_contact * tanh(vy / 0.05)
               else 0.0;

  // ===== Wind disturbance (middle third of 14 s: 4.667 .. 9.333 s) =====
  F_wind_y = if (time >= 14.0 / 3.0 and time <= 2.0 * 14.0 / 3.0)
             then F_wind_dist else 0.0;

  // ===== Phase logic =====
  contact_phase = time >= t_contact;

  // ===== Position-to-impedance hybrid controller =====
  y_des = 0.0;
  z_des = 1.0;
  x_des = if contact_phase
          then (wall_x - d_probe + F_target / k_contact)
          else x_so;

  // --- Velocity commands (approach speed limit in free flight) ---
  v_des_x = if contact_phase
            then (Kp_pos / Kd_pos) * (x_des - x)
            else max(-v_lim, min(v_lim, (Kp_pos / Kd_pos) * (x_des - x)));
  v_des_y = (Kp_pos / Kd_pos) * (y_des - y);
  v_des_z = (Kp_pos / Kd_pos) * (z_des - z);

  // --- Desired accelerations ---
  // Free space: cascaded velocity PD.
  // Contact: force-tracking impedance (push harder if force too low, back off if too high).
  a_des_x = if in_contact
            then Kff_frc * (F_target - F_contact) - Kd_con * vx
            else Kd_pos * (v_des_x - vx);
  a_des_y = Kd_pos * (v_des_y - vy);
  a_des_z = Kd_pos * (v_des_z - vz);

  // --- Desired world-frame force (gravity + contact feedforward) ---
  Fx_cmd = m_fuselage * a_des_x + F_contact;
  Fy_cmd = m_fuselage * a_des_y;
  Fz_cmd = m_fuselage * a_des_z + m_fuselage * g_acc;

  // --- Thrust magnitude ---
  T_mag_cmd = sqrt(Fx_cmd * Fx_cmd + Fy_cmd * Fy_cmd + Fz_cmd * Fz_cmd + 1.0e-6);

  // --- Desired attitude (align body-z with desired force; yaw = 0) ---
  phi_des_raw   = -asin(max(-0.99, min(0.99, Fy_cmd / T_mag_cmd)));
  theta_des_raw =  atan2(Fx_cmd, Fz_cmd);
  phi_des_c     = max(-att_lim, min(att_lim, phi_des_raw));
  theta_des_c   = max(-att_lim, min(att_lim, theta_des_raw));

  // --- Attitude PD controller ---
  Mx_cmd = Kp_att * (phi_des_c   - phi)   - Kd_att * p;
  My_cmd = Kp_att * (theta_des_c - theta) - Kd_att * q;
  Mz_cmd = -Kd_att * r;

  // ===== Thrust allocation (plus configuration) =====
  // Rotor 1: front (+x body), 2: left (+y body), 3: back (-x), 4: right (-y)
  // Yaw sign: rotors 1,3 CW; 2,4 CCW  =>  Mz = c_tau*(-T1 + T2 - T3 + T4)
  T1_raw = T_mag_cmd / 4.0 + My_cmd / (2.0 * arm_length) - Mz_cmd / (4.0 * c_tau_yaw);
  T2_raw = T_mag_cmd / 4.0 + Mx_cmd / (2.0 * arm_length) + Mz_cmd / (4.0 * c_tau_yaw);
  T3_raw = T_mag_cmd / 4.0 - My_cmd / (2.0 * arm_length) - Mz_cmd / (4.0 * c_tau_yaw);
  T4_raw = T_mag_cmd / 4.0 - Mx_cmd / (2.0 * arm_length) + Mz_cmd / (4.0 * c_tau_yaw);

  // Clamp individual rotor thrusts to [0, thrust_max]
  T1 = max(0.0, min(thrust_max, T1_raw));
  T2 = max(0.0, min(thrust_max, T2_raw));
  T3 = max(0.0, min(thrust_max, T3_raw));
  T4 = max(0.0, min(thrust_max, T4_raw));

  // Actual total thrust and moments from clamped rotor commands
  T_actual  = T1 + T2 + T3 + T4;
  Mx_actual = arm_length * (T2 - T4);
  My_actual = arm_length * (T1 - T3);
  Mz_actual = c_tau_yaw * (-T1 + T2 - T3 + T4);

  // ===== Plant dynamics — translational =====
  der(x)  = vx;
  der(y)  = vy;
  der(z)  = vz;
  m_fuselage * der(vx) = T_actual * R13 + F_cx_robot;
  m_fuselage * der(vy) = T_actual * R23 + F_cy_robot + F_wind_y;
  m_fuselage * der(vz) = T_actual * R33 - m_fuselage * g_acc;

  // ===== Plant dynamics — rotational (Euler kinematics + rigid body) =====
  der(phi)   = p + sin(phi) * tan(theta) * q + cos(phi) * tan(theta) * r;
  der(theta) = cos(phi) * q - sin(phi) * r;
  der(psi)   = (sin(phi) * q + cos(phi) * r) / max(cos(theta), 0.1);

  Ixx_inertia * der(p) = (Iyy_inertia - Izz_inertia) * q * r + Mx_actual;
  Iyy_inertia * der(q) = (Izz_inertia - Ixx_inertia) * p * r + My_actual;
  Izz_inertia * der(r) = (Ixx_inertia - Iyy_inertia) * p * q + Mz_actual;

  // ===== Sensors =====
  // IMU (pose + angular rates)
  x_imu = x;       y_imu = y;       z_imu = z;
  phi_imu = phi;   theta_imu = theta;   psi_imu = psi;
  p_imu = p;       q_imu = q;       r_imu = r;

  // Lidar (range from probe tip to wall surface)
  lidar_range = wall_x - (x + d_probe);

  // Optical flow (downward-facing, simplified: ground velocity / height)
  flow_x = vx / max(z, 0.1);
  flow_y = vy / max(z, 0.1);

  // Probe force sensor (normal direction)
  F_probe = F_contact;

  // ===== Performance metrics =====
  track_error = abs(x - x_so);
  force_error = abs(F_contact - F_target);

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "QuadScoutTouchD: 1.8 kg quadrotor with four independently commanded
      rotors at 0.22 m arm length, each limited to 12 N. Approaches a vertical wall,
      establishes 9 N normal probe force via position-to-impedance hybrid control,
      and holds contact for the last quarter (10.5-14 s). A 3 N tangential wind
      disturbance is applied during the middle third (4.67-9.33 s). Wall friction
      coefficient 0.55. Control intended at 200 Hz (Ts_ctrl = 0.005 s).
      Assumed values (not specified in requirement): probe offset 0.30 m, contact
      stiffness 1000 N/m, contact damping 80 Ns/m, inertia tensor, yaw torque
      coefficient, and control gains. Probe offset chosen so rotors (arm 0.22 m)
      clear the wall during contact."));
end QuadScoutTouchD;