model TiltWingHoverC
  "Free-base tilt-wing aerial robot: vertical takeoff to 2.5 m, level hover, cascaded position/attitude control with thrust allocation"

  // ==================== Physical Parameters ====================
  parameter Real m = 6.2 "Fuselage mass [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real rho_air = 1.225 "Air density [kg/m3]";
  parameter Real l_rotor = 0.62 "Rotor arm length from center [m]";
  parameter Real span = 1.8 "Wing span [m]";
  parameter Real T_max = 47.8 "Maximum thrust per rotor [N]";
  parameter Real alpha_min = 0.0 "Minimum rotor tilt angle [rad]";
  parameter Real alpha_max = 1.57 "Maximum rotor tilt angle [rad]";
  // h_rotor: vertical offset of rotor plane above CG — assumed geometry
  parameter Real h_rotor = 0.15 "Rotor plane height above CG [m]";
  // Inertias estimated from mass and wing geometry
  parameter Real Ixx = 1.5 "Roll inertia [kg.m2]";
  parameter Real Iyy = 1.2 "Pitch inertia [kg.m2]";
  parameter Real Izz = 2.0 "Yaw inertia [kg.m2]";
  // Linear translational drag
  parameter Real k_drag = 0.8 "Linear drag coefficient [N.s/m]";
  // Pitch aerodynamic restoring stiffness — assumed aero model
  parameter Real k_pitch_stiff = 5.0 "Pitch stiffness [N.m/rad]";
  // Rotational damping — assumed aero model
  parameter Real k_pitch_damp = 1.0 "Pitch damping [N.m.s/rad]";
  parameter Real k_roll_damp = 0.5 "Roll damping [N.m.s/rad]";
  parameter Real k_yaw_damp = 0.5 "Yaw damping [N.m.s/rad]";

  // ==================== Controller Gains ====================
  parameter Real Kp_z = 4.0  "Altitude P gain";
  parameter Real Kd_z = 5.0  "Altitude D gain";
  parameter Real Kp_x = 1.5  "X-position P gain";
  parameter Real Kd_x = 2.5  "X-position D gain";
  parameter Real Kp_y = 1.5  "Y-position P gain";
  parameter Real Kd_y = 2.5  "Y-position D gain";
  parameter Real Kp_phi   = 15.0 "Roll attitude P gain";
  parameter Real Kd_phi   = 5.0  "Roll attitude D gain";
  parameter Real Kp_theta = 15.0 "Pitch attitude P gain";
  parameter Real Kd_theta = 5.0  "Pitch attitude D gain";
  parameter Real Kp_psi   = 10.0 "Yaw attitude P gain";
  parameter Real Kd_psi   = 4.0  "Yaw attitude D gain";

  // ==================== Targets and Disturbance ====================
  parameter Real z_target   = 2.5 "Target altitude [m]";
  parameter Real x_target   = 0.0 "Target X [m]";
  parameter Real y_target   = 0.0 "Target Y [m]";
  parameter Real wind_force = 3.6 "Wind disturbance magnitude [N]";
  parameter Real t_wind_start = 4.0 "Wind start time [s] (middle third of 12 s)";
  parameter Real t_wind_end   = 8.0 "Wind end time [s]";

  // ==================== Dynamic States ====================
  Real x(start=0, fixed=true) "X position [m]";
  Real y(start=0, fixed=true) "Y position [m]";
  Real z(start=0, fixed=true) "Z altitude [m]";
  Real vx(start=0, fixed=true) "X velocity [m/s]";
  Real vy(start=0, fixed=true) "Y velocity [m/s]";
  Real vz(start=0, fixed=true) "Z velocity [m/s]";
  Real phi(start=0, fixed=true)   "Roll angle [rad]";
  Real theta(start=0, fixed=true) "Pitch angle [rad]";
  Real psi(start=0, fixed=true)   "Yaw angle [rad]";
  Real pp(start=0, fixed=true)  "Body roll rate [rad/s]";
  Real qq(start=0, fixed=true)  "Body pitch rate [rad/s]";
  Real rr(start=0, fixed=true)  "Body yaw rate [rad/s]";

  // ==================== Sensors ====================
  Real x_meas(start=0) "10 Hz sampled X position [m]";
  Real y_meas(start=0) "10 Hz sampled Y position [m]";
  Real z_alt "Altimeter altitude [m] (continuous)";
  Real phi_imu "IMU roll [rad]";
  Real theta_imu "IMU pitch [rad]";
  Real psi_imu "IMU yaw [rad]";
  Real p_imu "IMU roll rate [rad/s]";
  Real q_imu "IMU pitch rate [rad/s]";
  Real r_imu "IMU yaw rate [rad/s]";

  // ==================== Controller Outputs ====================
  Real T_total_cmd "Total thrust command [N]";
  Real phi_des "Desired roll [rad]";
  Real theta_des "Desired pitch [rad]";
  Real tau_roll_des "Desired body roll torque [N.m]";
  Real tau_pitch_des "Desired body pitch torque [N.m]";
  Real tau_yaw_des "Desired body yaw torque [N.m]";

  // ==================== Allocation ====================
  Real F1v_des "Desired vertical force rotor 1 [N]";
  Real F2v_des "Desired vertical force rotor 2 [N]";
  Real F1h_des "Desired horizontal force rotor 1 [N]";
  Real F2h_des "Desired horizontal force rotor 2 [N]";
  Real S_h "Sum of desired horizontal forces [N]";
  Real D_h "Diff of desired horizontal forces [N]";
  Real T1_cmd "Commanded thrust rotor 1 [N]";
  Real T2_cmd "Commanded thrust rotor 2 [N]";
  Real alpha1_cmd "Commanded tilt rotor 1 [rad]";
  Real alpha2_cmd "Commanded tilt rotor 2 [rad]";
  Real T1_act "Actual thrust rotor 1 [N]";
  Real T2_act "Actual thrust rotor 2 [N]";
  Real alpha1_act "Actual tilt rotor 1 [rad]";
  Real alpha2_act "Actual tilt rotor 2 [rad]";

  // ==================== Actual Forces and Torques ====================
  Real F1v_act "Actual vertical force rotor 1 [N]";
  Real F2v_act "Actual vertical force rotor 2 [N]";
  Real F1h_act "Actual horizontal force rotor 1 [N]";
  Real F2h_act "Actual horizontal force rotor 2 [N]";
  Real Tv "Total vertical thrust [N]";
  Real Th "Total horizontal thrust [N]";
  Real tau_roll_act "Actual body roll torque [N.m]";
  Real tau_pitch_act "Actual body pitch torque [N.m]";
  Real tau_yaw_act "Actual body yaw torque [N.m]";

  // ==================== Inertial Forces ====================
  Real Fx_i "Inertial X force [N]";
  Real Fy_i "Inertial Y force [N]";
  Real Fz_i "Inertial Z force [N]";
  Real wind_x "Wind disturbance force in X [N]";

  // ==================== Rotation Matrix ====================
  Real cpsi, spsi, ctheta, stheta, cphi, sphi;
  Real r11, r12, r13, r21, r22, r23, r31, r32, r33;

  // ==================== Tracking Error ====================
  Real z_error "Primary altitude tracking error [m]";

equation
  // ==================== 10 Hz Position Sensor ====================
  when sample(0, 0.1) then
    x_meas = x;
    y_meas = y;
  end when;

  // Altimeter (continuous) and IMU (continuous)
  z_alt = z;
  phi_imu = phi;
  theta_imu = theta;
  psi_imu = psi;
  p_imu = pp;
  q_imu = qq;
  r_imu = rr;

  // ==================== Wind Disturbance (middle third: 4-8 s) ====================
  if time >= t_wind_start and time <= t_wind_end then
    wind_x = -wind_force;
  else
    wind_x = 0.0;
  end if;

  // ==================== Position Controller (Outer Loop) ====================
  // Altitude -> total thrust command
  T_total_cmd = m * (g + Kp_z * (z_target - z_alt) + Kd_z * (0.0 - vz));

  // X position -> desired pitch (nose-down gives forward force)
  // theta_des < 0 when robot is behind target -> nose-down -> forward
  theta_des = Kp_x * (x_meas - x_target) + Kd_x * vx;

  // Y position -> desired roll (left-wing-down gives leftward force)
  // phi_des < 0 when robot is right of target -> left roll -> leftward
  phi_des = -(Kp_y * (y_meas - y_target) + Kd_y * vy);

  // ==================== Attitude Controller (Inner Loop) ====================
  // Euler convention: phi>0 = right-wing-down, theta>0 = nose-up, psi>0 = nose-right
  // Body rates: pp rotates right-wing-up, qq rotates nose-down, rr rotates nose-right
  // der(phi) = -pp, der(theta) = -qq, der(psi) = rr
  // Controller commands body torques with sign-corrected gains
  tau_roll_des  = -Ixx * (Kp_phi   * (phi_des   - phi_imu)   + Kd_phi   * p_imu);
  tau_pitch_des = -Iyy * (Kp_theta * (theta_des - theta_imu) + Kd_theta * q_imu);
  tau_yaw_des  =  Izz * (-Kp_psi  * psi_imu                    - Kd_psi  * r_imu);

  // ==================== Thrust Allocation ====================
  // Vertical: total thrust + roll differential
  F1v_des = (T_total_cmd - tau_roll_des / l_rotor) / 2.0;
  F2v_des = (T_total_cmd + tau_roll_des / l_rotor) / 2.0;

  // Horizontal: pitch collective + yaw differential
  // Plant: tau_pitch_body = h_rotor * Th,  tau_yaw_body = -l_rotor * (F2h - F1h)
  S_h = tau_pitch_des / h_rotor;
  D_h = -tau_yaw_des / l_rotor;
  F1h_des = (S_h - D_h) / 2.0;
  F2h_des = (S_h + D_h) / 2.0;

  // Thrust magnitude and tilt angle per rotor
  T1_cmd = sqrt(F1v_des * F1v_des + F1h_des * F1h_des);
  T2_cmd = sqrt(F2v_des * F2v_des + F2h_des * F2h_des);

  alpha1_cmd = if F1v_des > 0.001 then atan(F1h_des / F1v_des)
               else if F1h_des > 0.0 then alpha_max else 0.0;
  alpha2_cmd = if F2v_des > 0.001 then atan(F2h_des / F2v_des)
               else if F2h_des > 0.0 then alpha_max else 0.0;

  // ==================== Rotor Bounds (Saturation) ====================
  T1_act = if T1_cmd > T_max then T_max else if T1_cmd < 0.0 then 0.0 else T1_cmd;
  T2_act = if T2_cmd > T_max then T_max else if T2_cmd < 0.0 then 0.0 else T2_cmd;
  alpha1_act = if alpha1_cmd > alpha_max then alpha_max
               else if alpha1_cmd < alpha_min then alpha_min else alpha1_cmd;
  alpha2_act = if alpha2_cmd > alpha_max then alpha_max
               else if alpha2_cmd < alpha_min then alpha_min else alpha2_cmd;

  // ==================== Actual Rotor Forces ====================
  F1v_act = T1_act * cos(alpha1_act);
  F2v_act = T2_act * cos(alpha2_act);
  F1h_act = T1_act * sin(alpha1_act);
  F2h_act = T2_act * sin(alpha2_act);

  Tv = F1v_act + F2v_act;
  Th = F1h_act + F2h_act;

  // ==================== Actual Body Torques ====================
  tau_roll_act  = l_rotor * (F2v_act - F1v_act);
  tau_pitch_act = h_rotor * Th;
  tau_yaw_act  = -l_rotor * (F2h_act - F1h_act);

  // ==================== Rotation Matrix (Body -> Inertial) ====================
  // ZYX Euler: psi (yaw, +right), theta (pitch, +nose-up), phi (roll, +right-wing-down)
  cpsi = cos(psi);     spsi = sin(psi);
  ctheta = cos(theta); stheta = sin(theta);
  cphi = cos(phi);     sphi = sin(phi);

  r11 = cpsi * ctheta;
  r12 = -spsi * cphi + cpsi * stheta * sphi;
  r13 = -spsi * sphi - cpsi * stheta * cphi;
  r21 = spsi * ctheta;
  r22 = cpsi * cphi + spsi * stheta * sphi;
  r23 = cpsi * sphi - spsi * stheta * cphi;
  r31 = stheta;
  r32 = -ctheta * sphi;
  r33 = ctheta * cphi;

  // Body force vector = (Th, 0, Tv)
  Fx_i = r11 * Th + r13 * Tv;
  Fy_i = r21 * Th + r23 * Tv;
  Fz_i = r31 * Th + r33 * Tv;

  // ==================== Translational Dynamics ====================
  der(x)  = vx;
  der(y)  = vy;
  der(z)  = vz;
  der(vx) = (Fx_i + wind_x - k_drag * vx) / m;
  der(vy) = (Fy_i - k_drag * vy) / m;
  der(vz) = (Fz_i - m * g - k_drag * vz) / m;

  // ==================== Rotational Dynamics ====================
  // der(phi) = -pp, der(theta) = -qq, der(psi) = rr
  der(phi)   = -pp;
  der(theta) = -qq;
  der(psi)   = rr;
  der(pp) = (tau_roll_act - k_roll_damp * pp) / Ixx;
  der(qq) = (tau_pitch_act + k_pitch_stiff * theta - k_pitch_damp * qq) / Iyy;
  der(rr) = (tau_yaw_act - k_yaw_damp * rr) / Izz;

  // ==================== Tracking Error ====================
  z_error = abs(z - z_target);

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "TiltWingHoverC: 6.2 kg tilt-wing aerial robot with two tilting rotors at 0.62 m from center.
      Cascaded position -> attitude -> thrust allocation control.
      Vertical takeoff to 2.5 m altitude, level attitude, zero yaw.
      Headwind disturbance 3.6 N during middle third (4-8 s).
      125 Hz execution, 12 s simulation, 10 Hz position sensor, continuous altimeter and IMU.
      Rotor thrust bounded [0, 47.8 N], tilt bounded [0, 1.57 rad].")
  );
end TiltWingHoverC;