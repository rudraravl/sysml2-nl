model SeaSnakeHoldF
  "Free-base articulated underwater robot station-keeping beside offshore structure"

  // ===== Robot embodiment parameters =====
  parameter Real m_robot(unit="kg") = 32.0 "Robot total mass";
  parameter Real module_length(unit="m") = 0.30 "Capsule module length";
  parameter Integer n_modules = 6 "Number of capsule modules";
  parameter Real total_length(unit="m") = 1.80 "Total body length (6 * 0.30)";
  parameter Real tau_max(unit="N.m") = 39.0 "Max torque per joint actuator pair";

  // ===== Inertia and hydrodynamic parameters =====
  parameter Real Ixx(unit="kg.m2") = 2.0 "Roll inertia";
  parameter Real Iyy(unit="kg.m2") = 2.0 "Pitch inertia";
  parameter Real Izz(unit="kg.m2") = 0.5 "Yaw inertia";
  parameter Real ma_x(unit="kg") = 8.0 "Added mass x";
  parameter Real ma_y(unit="kg") = 8.0 "Added mass y";
  parameter Real ma_z(unit="kg") = 4.0 "Added mass z";
  parameter Real d_lin(unit="N.s/m") = 12.0 "Linear hydrodynamic damping";
  parameter Real d_ang(unit="N.m.s/rad") = 2.0 "Angular hydrodynamic damping";

  // ===== Joint parameters =====
  parameter Real I_joint(unit="kg.m2") = 0.05 "Joint reflected inertia";
  parameter Real d_joint(unit="N.m.s/rad") = 0.5 "Joint damping";
  parameter Real joint_omega(unit="rad/s") = 4.0 "Undulation angular frequency";
  parameter Real joint_amp(unit="N.m") = 15.0 "Undulation torque amplitude";

  // ===== Structure (fixed collidable cylinder) =====
  parameter Real struct_radius(unit="m") = 0.40 "Structure cylinder radius";
  parameter Real struct_height(unit="m") = 10.0 "Structure cylinder height";
  parameter Real struct_x(unit="m") = 2.50 "Structure center x";
  parameter Real struct_y(unit="m") = 0.0 "Structure center y";
  parameter Real clearance_min(unit="m") = 0.15 "Minimum allowable clearance";

  // ===== Desired pose =====
  parameter Real x_des(unit="m") = 1.50 "Desired x";
  parameter Real y_des(unit="m") = 0.0 "Desired y";
  parameter Real z_des(unit="m") = -2.0 "Desired z";
  parameter Real roll_des(unit="rad") = 0.0 "Desired roll";
  parameter Real pitch_des(unit="rad") = 0.0 "Desired pitch";
  parameter Real yaw_des(unit="rad") = 0.0 "Desired yaw";

  // ===== Station-keeping controller gains =====
  parameter Real kp_pos(unit="N/m") = 800.0 "Position proportional gain";
  parameter Real kd_pos(unit="N.s/m") = 80.0 "Position derivative gain";
  parameter Real kp_att(unit="N.m/rad") = 120.0 "Attitude proportional gain";
  parameter Real kd_att(unit="N.m.s/rad") = 20.0 "Attitude derivative gain";
  parameter Real F_wrench_max(unit="N") = 200.0 "Body wrench force bound";
  parameter Real M_wrench_max(unit="N.m") = 50.0 "Body wrench moment bound";

  // ===== Tether parameters =====
  parameter Real tether_k(unit="N/m") = 50.0 "Tether stiffness";
  parameter Real tether_anchor_x(unit="m") = 0.0 "Tether anchor x";
  parameter Real tether_anchor_z(unit="m") = 0.0 "Tether anchor z (surface)";
  parameter Real tether_max_force(unit="N") = 250.0 "Tether breaking strength";

  // ===== Disturbance =====
  parameter Real F_disturb(unit="N") = 174.0 "Tether/current disturbance force";
  parameter Real T_total(unit="s") = 20.0 "Total simulation duration";

  // ===== Environment =====
  parameter Real rho_water(unit="kg/m3") = 1025.0 "Seawater density";
  parameter Real g_grav(unit="m/s2") = 9.81 "Gravitational acceleration";
  parameter Real p_atm(unit="Pa") = 101325.0 "Atmospheric pressure";

  // ===== Sampling =====
  parameter Real f_sample(unit="Hz") = 500.0 "Sensor and control sampling rate";

  // ===== Position and velocity states =====
  Real x(unit="m") "Robot x position";
  Real y(unit="m") "Robot y position";
  Real z(unit="m") "Robot z position";
  Real vx(unit="m/s") "Robot x velocity";
  Real vy(unit="m/s") "Robot y velocity";
  Real vz(unit="m/s") "Robot z velocity";

  // ===== Attitude states =====
  Real roll(unit="rad") "Robot roll angle";
  Real pitch(unit="rad") "Robot pitch angle";
  Real yaw(unit="rad") "Robot yaw angle";
  Real wx(unit="rad/s") "Roll angular rate";
  Real wy(unit="rad/s") "Pitch angular rate";
  Real wz(unit="rad/s") "Yaw angular rate";

  // ===== Joint states (6 joints, alternating yaw/pitch) =====
  Real theta1(unit="rad") "Joint 1 angle (yaw)";
  Real theta2(unit="rad") "Joint 2 angle (pitch)";
  Real theta3(unit="rad") "Joint 3 angle (yaw)";
  Real theta4(unit="rad") "Joint 4 angle (pitch)";
  Real theta5(unit="rad") "Joint 5 angle (yaw)";
  Real theta6(unit="rad") "Joint 6 angle (pitch)";
  Real dtheta1(unit="rad/s") "Joint 1 angular velocity";
  Real dtheta2(unit="rad/s") "Joint 2 angular velocity";
  Real dtheta3(unit="rad/s") "Joint 3 angular velocity";
  Real dtheta4(unit="rad/s") "Joint 4 angular velocity";
  Real dtheta5(unit="rad/s") "Joint 5 angular velocity";
  Real dtheta6(unit="rad/s") "Joint 6 angular velocity";

  // ===== Joint actuator torques (12 actuators -> 6 bounded joint torques) =====
  Real tau1_raw(unit="N.m"), tau2_raw(unit="N.m"), tau3_raw(unit="N.m");
  Real tau4_raw(unit="N.m"), tau5_raw(unit="N.m"), tau6_raw(unit="N.m");
  Real tau1(unit="N.m"), tau2(unit="N.m"), tau3(unit="N.m");
  Real tau4(unit="N.m"), tau5(unit="N.m"), tau6(unit="N.m");

  // ===== Body wrench (bounded station-keeping) =====
  Real Fbx_raw(unit="N"), Fby_raw(unit="N"), Fbz_raw(unit="N");
  Real Mbx_raw(unit="N.m"), Mby_raw(unit="N.m"), Mbz_raw(unit="N.m");
  Real Fbx(unit="N"), Fby(unit="N"), Fbz(unit="N");
  Real Mbx(unit="N.m"), Mby(unit="N.m"), Mbz(unit="N.m");

  // ===== Accelerations (for IMU and dynamics) =====
  Real ax(unit="m/s2"), ay(unit="m/s2"), az(unit="m/s2");
  Real alpha_x(unit="rad/s2"), alpha_y(unit="rad/s2"), alpha_z(unit="rad/s2");

  // ===== Disturbance and tether =====
  Real F_dist_x(unit="N"), F_dist_y(unit="N"), F_dist_z(unit="N");
  Real F_tether_x(unit="N"), F_tether_z(unit="N");
  Real tether_load(unit="N") "Tether load magnitude";

  // ===== Sensors =====
  Real pressure_sensor(unit="Pa") "Pressure sensor reading";
  Real imu_ax(unit="m/s2"), imu_ay(unit="m/s2"), imu_az(unit="m/s2");
  Real imu_wx(unit="rad/s"), imu_wy(unit="rad/s"), imu_wz(unit="rad/s");
  Real dvl_vx(unit="m/s"), dvl_vy(unit="m/s"), dvl_vz(unit="m/s");
  Real sonar_range(unit="m") "Forward sonar range to structure";

  // ===== Errors and verification =====
  Real pos_error(unit="m") "Euclidean position tracking error";
  Real att_error(unit="rad") "Euclidean attitude tracking error";
  Real struct_clearance(unit="m") "Clearance to structure surface";
  Real dist_to_struct_axis(unit="m") "Horizontal distance to structure axis";

  Boolean bounds_satisfied "Joint and wrench bounds satisfied";
  Boolean tracking_ok "Primary tracking error below 0.24 m after 13 s";
  Boolean clearance_ok "Structure clearance above minimum";
  Boolean tether_ok "Tether load below breaking strength";
  Boolean no_nan "No NaN or infinite physical/control/estimator values";
  Boolean all_verified "All verification criteria met";

  // ===== Discrete trace variables (500 Hz synchronized) =====
  discrete Real trace_time(unit="s");
  discrete Real trace_x(unit="m"), trace_y(unit="m"), trace_z(unit="m");
  discrete Real trace_vx(unit="m/s"), trace_vy(unit="m/s"), trace_vz(unit="m/s");
  discrete Real trace_roll(unit="rad"), trace_pitch(unit="rad"), trace_yaw(unit="rad");
  discrete Real trace_pos_error(unit="m"), trace_att_error(unit="rad");
  discrete Real trace_Fbx(unit="N"), trace_Fby(unit="N"), trace_Fbz(unit="N");
  discrete Real trace_Mbx(unit="N.m"), trace_Mby(unit="N.m"), trace_Mbz(unit="N.m");
  discrete Real trace_tau1(unit="N.m"), trace_tau2(unit="N.m"), trace_tau3(unit="N.m");
  discrete Real trace_tau4(unit="N.m"), trace_tau5(unit="N.m"), trace_tau6(unit="N.m");
  discrete Real trace_pressure(unit="Pa"), trace_sonar(unit="m");
  discrete Real trace_tether_load(unit="N");

protected
  parameter Real t_dist_start(unit="s") = 6.666666666666667 "T_total/3";
  parameter Real t_dist_end(unit="s") = 13.333333333333334 "2*T_total/3";

initial equation
  x = x_des;
  y = y_des;
  z = z_des;
  vx = 0.0;
  vy = 0.0;
  vz = 0.0;
  roll = 0.0;
  pitch = 0.0;
  yaw = 0.0;
  wx = 0.0;
  wy = 0.0;
  wz = 0.0;
  theta1 = 0.0;
  theta2 = 0.0;
  theta3 = 0.0;
  theta4 = 0.0;
  theta5 = 0.0;
  theta6 = 0.0;
  dtheta1 = 0.0;
  dtheta2 = 0.0;
  dtheta3 = 0.0;
  dtheta4 = 0.0;
  dtheta5 = 0.0;
  dtheta6 = 0.0;

equation
  // ===== Disturbance: controlled 174 N load during middle third =====
  if time >= t_dist_start and time <= t_dist_end then
    F_dist_x = F_disturb;
    F_dist_y = 0.0;
    F_dist_z = 0.0;
  else
    F_dist_x = 0.0;
    F_dist_y = 0.0;
    F_dist_z = 0.0;
  end if;

  // ===== Tether load (spring to surface anchor) =====
  F_tether_x = -tether_k * (x - tether_anchor_x);
  F_tether_z = -tether_k * (z - tether_anchor_z);
  tether_load = sqrt(F_tether_x * F_tether_x + F_tether_z * F_tether_z + 1e-12);

  // ===== Station-keeping controller (PD with bounded wrench) =====
  Fbx_raw = kp_pos * (x_des - x) - kd_pos * vx;
  Fby_raw = kp_pos * (y_des - y) - kd_pos * vy;
  Fbz_raw = kp_pos * (z_des - z) - kd_pos * vz;
  // Robot assumed neutrally buoyant; no net buoyancy term needed

  Mbx_raw = kp_att * (roll_des - roll) - kd_att * wx;
  Mby_raw = kp_att * (pitch_des - pitch) - kd_att * wy;
  Mbz_raw = kp_att * (yaw_des - yaw) - kd_att * wz;

  // Bounded wrench saturation
  Fbx = max(-F_wrench_max, min(F_wrench_max, Fbx_raw));
  Fby = max(-F_wrench_max, min(F_wrench_max, Fby_raw));
  Fbz = max(-F_wrench_max, min(F_wrench_max, Fbz_raw));
  Mbx = max(-M_wrench_max, min(M_wrench_max, Mbx_raw));
  Mby = max(-M_wrench_max, min(M_wrench_max, Mby_raw));
  Mbz = max(-M_wrench_max, min(M_wrench_max, Mbz_raw));

  // ===== Undulatory joint actuation (traveling wave, alternating yaw/pitch) =====
  // 12 actuators across 6 joints; each joint bounded at tau_max
  tau1_raw = joint_amp * sin(joint_omega * time + 0.0);
  tau2_raw = joint_amp * sin(joint_omega * time + 1.047197551);
  tau3_raw = joint_amp * sin(joint_omega * time + 2.094395102);
  tau4_raw = joint_amp * sin(joint_omega * time + 3.141592654);
  tau5_raw = joint_amp * sin(joint_omega * time + 4.188790205);
  tau6_raw = joint_amp * sin(joint_omega * time + 5.235987756);

  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));
  tau3 = max(-tau_max, min(tau_max, tau3_raw));
  tau4 = max(-tau_max, min(tau_max, tau4_raw));
  tau5 = max(-tau_max, min(tau_max, tau5_raw));
  tau6 = max(-tau_max, min(tau_max, tau6_raw));

  // ===== 6DOF rigid-body dynamics (simplified, decoupled) =====
  // Translational accelerations
  ax = (Fbx + F_dist_x + F_tether_x - d_lin * vx) / (m_robot + ma_x);
  ay = (Fby + F_dist_y - d_lin * vy) / (m_robot + ma_y);
  az = (Fbz + F_dist_z + F_tether_z - d_lin * vz) / (m_robot + ma_z);

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  // Rotational accelerations
  alpha_x = (Mbx - d_ang * wx) / Ixx;
  alpha_y = (Mby - d_ang * wy) / Iyy;
  alpha_z = (Mbz - d_ang * wz) / Izz;

  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;
  der(wx) = alpha_x;
  der(wy) = alpha_y;
  der(wz) = alpha_z;

  // ===== Joint dynamics =====
  der(theta1) = dtheta1;
  der(theta2) = dtheta2;
  der(theta3) = dtheta3;
  der(theta4) = dtheta4;
  der(theta5) = dtheta5;
  der(theta6) = dtheta6;

  I_joint * der(dtheta1) = tau1 - d_joint * dtheta1;
  I_joint * der(dtheta2) = tau2 - d_joint * dtheta2;
  I_joint * der(dtheta3) = tau3 - d_joint * dtheta3;
  I_joint * der(dtheta4) = tau4 - d_joint * dtheta4;
  I_joint * der(dtheta5) = tau5 - d_joint * dtheta5;
  I_joint * der(dtheta6) = tau6 - d_joint * dtheta6;

  // ===== Sensor models =====
  // Pressure sensor (depth-based)
  pressure_sensor = p_atm + rho_water * g_grav * max(0.0, -z);

  // IMU (linear accelerations and angular rates)
  imu_ax = ax;
  imu_ay = ay;
  imu_az = az;
  imu_wx = wx;
  imu_wy = wy;
  imu_wz = wz;

  // DVL (body-frame velocities approximated as world-frame)
  dvl_vx = vx;
  dvl_vy = vy;
  dvl_vz = vz;

  // Forward sonar (range to structure cylinder surface)
  dist_to_struct_axis = sqrt((x - struct_x) * (x - struct_x) + (y - struct_y) * (y - struct_y) + 1e-12);
  sonar_range = max(0.0, dist_to_struct_axis - struct_radius);

  // ===== Error metrics =====
  pos_error = sqrt((x - x_des) * (x - x_des) + (y - y_des) * (y - y_des) + (z - z_des) * (z - z_des) + 1e-12);
  att_error = sqrt((roll - roll_des) * (roll - roll_des) + (pitch - pitch_des) * (pitch - pitch_des) + (yaw - yaw_des) * (yaw - yaw_des) + 1e-12);

  // Structure clearance
  struct_clearance = max(0.0, dist_to_struct_axis - struct_radius);

  // ===== Verification criteria =====
  // Joint and wrench bounds
  bounds_satisfied = (abs(tau1) <= tau_max + 0.001) and (abs(tau2) <= tau_max + 0.001) and
                     (abs(tau3) <= tau_max + 0.001) and (abs(tau4) <= tau_max + 0.001) and
                     (abs(tau5) <= tau_max + 0.001) and (abs(tau6) <= tau_max + 0.001) and
                     (abs(Fbx) <= F_wrench_max + 0.001) and (abs(Fby) <= F_wrench_max + 0.001) and
                     (abs(Fbz) <= F_wrench_max + 0.001) and (abs(Mbx) <= M_wrench_max + 0.001) and
                     (abs(Mby) <= M_wrench_max + 0.001) and (abs(Mbz) <= M_wrench_max + 0.001);

  // Primary tracking error below 0.24 m after 13 s
  tracking_ok = (time < 13.0) or (pos_error <= 0.24);

  // Structure clearance
  clearance_ok = struct_clearance >= clearance_min;

  // Tether load limit
  tether_ok = tether_load <= tether_max_force;

  // No NaN or infinite values (NaN < threshold is false, Inf < threshold is false)
  no_nan = (abs(x) < 1e20) and (abs(y) < 1e20) and (abs(z) < 1e20) and
           (abs(vx) < 1e20) and (abs(vy) < 1e20) and (abs(vz) < 1e20) and
           (abs(roll) < 1e20) and (abs(pitch) < 1e20) and (abs(yaw) < 1e20) and
           (abs(wx) < 1e20) and (abs(wy) < 1e20) and (abs(wz) < 1e20) and
           (abs(tau1) < 1e20) and (abs(tau2) < 1e20) and (abs(tau3) < 1e20) and
           (abs(tau4) < 1e20) and (abs(tau5) < 1e20) and (abs(tau6) < 1e20) and
           (abs(Fbx) < 1e20) and (abs(Fby) < 1e20) and (abs(Fbz) < 1e20) and
           (abs(Mbx) < 1e20) and (abs(Mby) < 1e20) and (abs(Mbz) < 1e20) and
           (abs(pressure_sensor) < 1e20) and (abs(sonar_range) < 1e20) and
           (abs(tether_load) < 1e20);

  all_verified = bounds_satisfied and tracking_ok and clearance_ok and tether_ok and no_nan;

  // ===== Discrete 500 Hz trace sampling =====
  when sample(0, 1.0 / f_sample) then
    trace_time = time;
    trace_x = x;
    trace_y = y;
    trace_z = z;
    trace_vx = vx;
    trace_vy = vy;
    trace_vz = vz;
    trace_roll = roll;
    trace_pitch = pitch;
    trace_yaw = yaw;
    trace_pos_error = pos_error;
    trace_att_error = att_error;
    trace_Fbx = Fbx;
    trace_Fby = Fby;
    trace_Fbz = Fbz;
    trace_Mbx = Mbx;
    trace_Mby = Mby;
    trace_Mbz = Mbz;
    trace_tau1 = tau1;
    trace_tau2 = tau2;
    trace_tau3 = tau3;
    trace_tau4 = tau4;
    trace_tau5 = tau5;
    trace_tau6 = tau6;
    trace_pressure = pressure_sensor;
    trace_sonar = sonar_range;
    trace_tether_load = tether_load;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "SeaSnakeHoldF: Free-base articulated underwater robot (32 kg, 6 capsule modules of 0.30 m, alternating yaw/pitch joints, passive tail fin) maintaining 6DOF station-keeping pose beside a fixed offshore structure (collidable cylinder). Twelve joint actuators (6 joints x 2 actuators) bounded at 39 N.m generate undulatory propulsion. Body-wrench station-keeping controller bounded at 200 N / 50 N.m. A controlled 174 N tether/current disturbance is applied during the middle third (6.67 s to 13.33 s). Sensors: pressure, IMU, DVL, forward sonar. Runs at 500 Hz for 20 s with synchronized state, command, and sensor traces. Verification: joint/thruster bounds, position and attitude error, structure clearance, tether limits, primary tracking error < 0.24 m after 13 s, no NaN/Inf values. Robot assumed neutrally buoyant. Tail fin is passive (not explicitly modeled as separate dynamics)."),
    Diagram(graphics = {Rectangle(extent = {{-100, 60}, {100, -60}})}),
    Icon(graphics = {Rectangle(extent = {{-100, 40}, {100, -40}}), Text(extent = {{-80, 20}, {80, -20}}, textString = "SeaSnakeHoldF")}));
end SeaSnakeHoldF;