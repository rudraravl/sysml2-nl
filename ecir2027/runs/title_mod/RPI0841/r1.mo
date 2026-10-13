model AUVDiveA
  // ============= Requirement-specified parameters =============
  parameter Real m_hull = 85.0 "Hull mass [kg]";
  parameter Real L_hull = 1.5 "Hull length [m]";
  parameter Real V_disp = 0.083 "Displaced volume [m3]";
  parameter Real rho_sw = 1025.0 "Seawater density [kg/m3]";
  parameter Real g_const = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_thruster_max = 79.2 "Max thruster command magnitude [N]";
  parameter Real F_current = 40.0 "Current disturbance force [N]";
  parameter Real z_target_deep = 8.0 "Target dive depth [m]";
  parameter Real z_target_shallow = 3.0 "Return depth [m]";
  parameter Real t_sim = 8.0 "Total scenario duration [s]";
  parameter Real f_ctrl = 80.0 "Control and sensor loop frequency [Hz]";

  // ============= Derived constants =============
  parameter Real W = m_hull * g_const "Weight [N]";
  parameter Real B = rho_sw * V_disp * g_const "Buoyancy [N]";
  parameter Real t_third = t_sim / 3.0 "One-third scenario duration [s]";

  // ============= Assumed physical parameters (not specified in requirement) =============
  parameter Real k_drag_z = 12.0 "Assumed quadratic heave drag coefficient [N.s2/m2]";
  parameter Real k_drag_x = 12.0 "Assumed quadratic surge drag coefficient [N.s2/m2]";
  parameter Real k_drag_rot = 1.5 "Assumed quadratic rotational drag coefficient [N.m.s2/rad2]";
  parameter Real ma_z = 10.0 "Assumed added mass in heave [kg]";
  parameter Real ma_x = 10.0 "Assumed added mass in surge [kg]";
  parameter Real Ja_roll = 4.0 "Assumed total roll inertia [kg.m2]";
  parameter Real Ja_pitch = 6.0 "Assumed total pitch inertia [kg.m2]";
  parameter Real Ja_yaw = 6.0 "Assumed total yaw inertia [kg.m2]";
  parameter Real l_yaw = 0.15 "Assumed surge thruster lateral lever arm for yaw [m]";
  parameter Real l_pitch = 0.30 "Assumed heave thruster longitudinal lever arm for pitch [m]";

  // ============= Cascaded controller gains (assumed) =============
  parameter Real Kp_depth_outer = 0.5 "Depth outer loop P gain [1/s]";
  parameter Real v_depth_max = 3.0 "Max commanded heave velocity [m/s]";
  parameter Real Kp_depth_inner = 80.0 "Depth inner loop P gain [N.s/m]";
  parameter Real Kp_surge = 30.0 "Surge velocity P gain [N.s/m]";
  parameter Real Kp_roll_outer = 1.5 "Roll outer loop P gain [1/s]";
  parameter Real Kp_pitch_outer = 1.5 "Pitch outer loop P gain [1/s]";
  parameter Real Kp_yaw_outer = 1.5 "Yaw outer loop P gain [1/s]";
  parameter Real w_max = 1.0 "Max commanded angular rate [rad/s]";
  parameter Real Kp_roll_inner = 8.0 "Roll inner loop P gain [N.m.s/rad]";
  parameter Real Kp_pitch_inner = 8.0 "Pitch inner loop P gain [N.m.s/rad]";
  parameter Real Kp_yaw_inner = 8.0 "Yaw inner loop P gain [N.m.s/rad]";

  // ============= State variables =============
  Real z(start=0.0, fixed=true) "Depth [m]";
  Real z_dot(start=0.0, fixed=true) "Heave velocity [m/s]";
  Real x_pos(start=0.0, fixed=true) "Surge position [m]";
  Real x_dot(start=0.0, fixed=true) "Surge velocity [m/s]";
  Real roll(start=0.0, fixed=true) "Roll angle [rad]";
  Real roll_dot(start=0.0, fixed=true) "Roll rate [rad/s]";
  Real pitch(start=0.0, fixed=true) "Pitch angle [rad]";
  Real pitch_dot(start=0.0, fixed=true) "Pitch rate [rad/s]";
  Real yaw(start=0.0, fixed=true) "Heading [rad]";
  Real yaw_dot(start=0.0, fixed=true) "Yaw rate [rad/s]";

  // ============= Command references =============
  Real z_cmd "Depth command [m]";
  Real yaw_cmd "Heading command [rad]";

  // ============= Cascaded controller intermediates =============
  Real z_dot_ref "Desired heave velocity from outer loop [m/s]";
  Real roll_dot_ref "Desired roll rate from outer loop [rad/s]";
  Real pitch_dot_ref "Desired pitch rate from outer loop [rad/s]";
  Real yaw_dot_ref "Desired yaw rate from outer loop [rad/s]";

  // ============= Controller commands (pre-allocation) =============
  Real F_heave_cmd "Heave force command [N]";
  Real F_surge_cmd "Surge force command [N]";
  Real T_roll_cmd "Roll torque command [N.m]";
  Real T_pitch_cmd "Pitch torque command [N.m]";
  Real T_yaw_cmd "Yaw torque command [N.m]";

  // ============= Bounded individual thruster forces =============
  Real f_surge_p "Port surge thruster force [N]";
  Real f_surge_s "Starboard surge thruster force [N]";
  Real f_heave_f "Forward heave thruster force [N]";
  Real f_heave_a "Aft heave thruster force [N]";

  // ============= Net applied forces and torques =============
  Real F_surge_net "Net surge force [N]";
  Real F_heave_net "Net heave force [N]";
  Real T_roll_net "Net roll torque [N.m]";
  Real T_pitch_net "Net pitch torque [N.m]";
  Real T_yaw_net "Net yaw torque [N.m]";

  // ============= Disturbance =============
  Real F_dist "Current disturbance force [N]";

  // ============= Sensor outputs =============
  Real z_meas "Pressure depth measurement [m]";
  Real z_dot_meas "Doppler heave velocity [m/s]";
  Real x_dot_meas "Doppler surge velocity [m/s]";
  Real roll_meas "IMU roll [rad]";
  Real pitch_meas "IMU pitch [rad]";
  Real yaw_meas "IMU heading [rad]";
  Real roll_dot_meas "IMU roll rate [rad/s]";
  Real pitch_dot_meas "IMU pitch rate [rad/s]";
  Real yaw_dot_meas "IMU yaw rate [rad/s]";

  // ============= Performance metric =============
  Real tracking_error "Primary depth tracking error [m]";

equation

  // === Mission command profile ===
  // First two-thirds: descend to 8 m and hold; last third: return to 3 m
  if time < 2.0 * t_third then
    z_cmd = z_target_deep;
  else
    z_cmd = z_target_shallow;
  end if;
  yaw_cmd = 0.0;

  // === Current disturbance (middle third of scenario) ===
  if time >= t_third and time < 2.0 * t_third then
    F_dist = F_current;
  else
    F_dist = 0.0;
  end if;

  // === Sensor models (ideal, noise-free) ===
  z_meas = z;
  z_dot_meas = z_dot;
  x_dot_meas = x_dot;
  roll_meas = roll;
  pitch_meas = pitch;
  yaw_meas = yaw;
  roll_dot_meas = roll_dot;
  pitch_dot_meas = pitch_dot;
  yaw_dot_meas = yaw_dot;

  // === Cascaded depth controller ===
  // Outer loop: depth error -> bounded desired heave velocity
  z_dot_ref = max(-v_depth_max, min(v_depth_max, Kp_depth_outer * (z_cmd - z_meas)));
  // Inner loop: velocity error -> heave force command
  F_heave_cmd = Kp_depth_inner * (z_dot_ref - z_dot_meas);

  // === Surge velocity controller (station-keeping) ===
  F_surge_cmd = -Kp_surge * x_dot_meas;

  // === Cascaded attitude controllers ===
  // Roll: outer loop produces bounded rate reference, inner loop tracks it
  roll_dot_ref = max(-w_max, min(w_max, Kp_roll_outer * (0.0 - roll_meas)));
  T_roll_cmd = Kp_roll_inner * (roll_dot_ref - roll_dot_meas);

  // Pitch
  pitch_dot_ref = max(-w_max, min(w_max, Kp_pitch_outer * (0.0 - pitch_meas)));
  T_pitch_cmd = Kp_pitch_inner * (pitch_dot_ref - pitch_dot_meas);

  // Yaw (hold zero heading)
  yaw_dot_ref = max(-w_max, min(w_max, Kp_yaw_outer * (yaw_cmd - yaw_meas)));
  T_yaw_cmd = Kp_yaw_inner * (yaw_dot_ref - yaw_dot_meas);

  // === Bounded thruster allocation ===
  // Surge thrusters: total surge force + yaw torque differential
  f_surge_p = max(-F_thruster_max, min(F_thruster_max, F_surge_cmd / 2.0 + T_yaw_cmd / (2.0 * l_yaw)));
  f_surge_s = max(-F_thruster_max, min(F_thruster_max, F_surge_cmd / 2.0 - T_yaw_cmd / (2.0 * l_yaw)));
  // Heave thrusters: total heave force + pitch torque differential
  f_heave_f = max(-F_thruster_max, min(F_thruster_max, F_heave_cmd / 2.0 + T_pitch_cmd / (2.0 * l_pitch)));
  f_heave_a = max(-F_thruster_max, min(F_thruster_max, F_heave_cmd / 2.0 - T_pitch_cmd / (2.0 * l_pitch)));

  // === Net forces and torques from bounded thrusters ===
  F_surge_net = f_surge_p + f_surge_s;
  F_heave_net = f_heave_f + f_heave_a;
  T_yaw_net = (f_surge_p - f_surge_s) * l_yaw;
  T_pitch_net = (f_heave_f - f_heave_a) * l_pitch;
  // Roll has no dedicated actuator; passive damping maintains stability
  T_roll_net = 0.0;

  // === Rigid body dynamics ===
  // Heave (positive z = downward, depth increasing)
  (m_hull + ma_z) * der(z_dot) = F_heave_net + (W - B) - k_drag_z * z_dot * abs(z_dot);
  der(z) = z_dot;

  // Surge
  (m_hull + ma_x) * der(x_dot) = F_surge_net + F_dist - k_drag_x * x_dot * abs(x_dot);
  der(x_pos) = x_dot;

  // Roll (passive rotational dynamics)
  Ja_roll * der(roll_dot) = T_roll_net - k_drag_rot * roll_dot * abs(roll_dot);
  der(roll) = roll_dot;

  // Pitch
  Ja_pitch * der(pitch_dot) = T_pitch_net - k_drag_rot * pitch_dot * abs(pitch_dot);
  der(pitch) = pitch_dot;

  // Yaw
  Ja_yaw * der(yaw_dot) = T_yaw_net - k_drag_rot * yaw_dot * abs(yaw_dot);
  der(yaw) = yaw_dot;

  // === Performance metric ===
  tracking_error = abs(z - z_cmd);

end AUVDiveA;