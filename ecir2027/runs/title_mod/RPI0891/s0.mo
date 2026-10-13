model CatamaranDiveC
  "Free-base marine robot: catamaran with cascaded depth and attitude control and bounded allocation"

  // ==================== Physical Parameters ====================
  parameter Real m_hull = 46.0 "Mass of each capsule hull [kg]";
  parameter Real m_deck = 18.0 "Mass of rigid deck [kg]";
  parameter Real m_total = 2.0 * m_hull + m_deck "Total vehicle mass [kg]";
  parameter Real d_hull = 1.1 "Hull separation [m]";
  parameter Real rho_water = 1025.0 "Seawater density [kg/m3]";
  parameter Real g_acc = 9.81 "Gravity [m/s2]";
  parameter Real V_disp = m_total / rho_water "Displaced volume [m3], neutral buoyancy";
  parameter Real F_max = 396.0 "Max command per propeller [N]";
  parameter Real F_dist = 72.0 "Current disturbance force [N]";

  // Quadratic drag coefficients (F = k * v * |v|)
  parameter Real k_drag_surge = 80.0 "Surge drag [N.s2/m2]";
  parameter Real k_drag_sway = 60.0 "Sway drag [N.s2/m2]";
  parameter Real k_drag_heave = 100.0 "Heave drag [N.s2/m2]";
  parameter Real k_drag_roll = 15.0 "Roll drag [N.m.s2/rad2]";
  parameter Real k_drag_pitch = 12.0 "Pitch drag [N.m.s2/rad2]";
  parameter Real k_drag_yaw = 15.0 "Yaw drag [N.m.s2/rad2]";

  // Metacentric restoring stiffness
  parameter Real k_roll_restore = 300.0 "Roll restoring [N.m/rad]";
  parameter Real k_pitch_restore = 150.0 "Pitch restoring [N.m/rad]";

  // Inertias
  parameter Real I_roll = 30.0 "Roll inertia [kg.m2]";
  parameter Real I_pitch = 10.0 "Pitch inertia [kg.m2]";
  parameter Real I_yaw = 33.0 "Yaw inertia [kg.m2]";

  // ==================== Controller Gains ====================
  // Cascaded depth: outer (position) -> inner (velocity) -> force
  parameter Real Kp_z = 1.5 "Depth outer loop gain [1/s]";
  parameter Real Kp_vz = 120.0 "Heave velocity inner loop gain [N.s/m]";
  // Cascaded heading: outer (angle) -> inner (rate) -> torque
  parameter Real Kp_psi = 2.0 "Heading outer loop gain [1/s]";
  parameter Real Kp_r = 60.0 "Yaw rate inner loop gain [N.m.s/rad]";
  // Cascaded roll: outer (angle) -> inner (rate) -> torque
  parameter Real Kp_phi = 3.0 "Roll outer loop gain [1/s]";
  parameter Real Kp_p = 50.0 "Roll rate inner loop gain [N.m.s/rad]";
  // Surge station-keeping (PD)
  parameter Real Kp_x = 10.0 "Surge position gain [N/m]";
  parameter Real Kd_x = 40.0 "Surge velocity gain [N.s/m]";

  // ==================== State Variables ====================
  Real x(start = 0.0, fixed = true) "Surge position [m]";
  Real y(start = 0.0, fixed = true) "Sway position [m]";
  Real z(start = 0.0, fixed = true) "Depth [m], positive downward";
  Real vx(start = 0.0, fixed = true) "Surge velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "Sway velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "Heave velocity [m/s], positive downward";
  Real phi(start = 0.0, fixed = true) "Roll angle [rad]";
  Real theta(start = 0.0, fixed = true) "Pitch angle [rad]";
  Real psi(start = 0.0, fixed = true) "Heading angle [rad]";
  Real p_rate(start = 0.0, fixed = true) "Roll rate [rad/s]";
  Real q_rate(start = 0.0, fixed = true) "Pitch rate [rad/s]";
  Real r_rate(start = 0.0, fixed = true) "Yaw rate [rad/s]";

  // ==================== Control Variables ====================
  Real z_target "Target depth [m]";
  Real psi_target "Target heading [rad]";
  Real vz_ref "Heave velocity reference from outer loop [m/s]";
  Real F_heave_cmd "Heave force command from inner loop [N]";
  Real r_ref "Yaw rate reference from outer loop [rad/s]";
  Real tau_yaw_cmd "Yaw torque command from inner loop [N.m]";
  Real p_ref "Roll rate reference from outer loop [rad/s]";
  Real tau_roll_cmd "Roll torque command from inner loop [N.m]";
  Real F_surge_cmd "Surge force command [N]";

  // ==================== Allocation Variables ====================
  Real Fp_h_raw "Port propeller horizontal force raw [N]";
  Real Fs_h_raw "Starboard propeller horizontal force raw [N]";
  Real Fp_v_raw "Port propeller vertical force raw [N]";
  Real Fs_v_raw "Starboard propeller vertical force raw [N]";
  Real Fp_h "Port propeller horizontal force saturated [N]";
  Real Fs_h "Starboard propeller horizontal force saturated [N]";
  Real Fp_v "Port propeller vertical force saturated [N]";
  Real Fs_v "Starboard propeller vertical force saturated [N]";
  Real Fp_mag "Port propeller force magnitude [N]";
  Real Fs_mag "Starboard propeller force magnitude [N]";

  // ==================== Body Forces and Torques ====================
  Real F_surge "Total surge force from propellers [N]";
  Real F_heave "Total heave force from propellers [N]";
  Real F_buoyancy_net "Net buoyancy force, positive upward [N]";
  Real F_current "Current disturbance force [N]";
  Real tau_roll "Total roll torque [N.m]";
  Real tau_yaw "Total yaw torque [N.m]";

  // ==================== Sensor Outputs ====================
  Real z_pressure "Pressure depth sensor [m]";
  Real phi_imu "IMU roll [rad]";
  Real theta_imu "IMU pitch [rad]";
  Real psi_imu "IMU heading [rad]";
  Real p_imu "IMU roll rate [rad/s]";
  Real q_imu "IMU pitch rate [rad/s]";
  Real r_imu "IMU yaw rate [rad/s]";
  Real vx_doppler "Doppler surge velocity [m/s]";
  Real vy_doppler "Doppler sway velocity [m/s]";
  Real vz_doppler "Doppler heave velocity [m/s]";

  // ==================== Performance Metrics ====================
  Real z_error "Primary tracking error |z - z_target| [m]";

equation
  // ============ Target Trajectory ============
  // Descend to 8 m and hold (0-8 s), then return to 3 m (8-12 s)
  if time < 8.0 then
    z_target = 8.0;
  else
    z_target = 3.0;
  end if;
  psi_target = 0.0;

  // ============ Current Disturbance ============
  // 72 N force during middle third (4-8 s)
  if time >= 4.0 and time < 8.0 then
    F_current = F_dist;
  else
    F_current = 0.0;
  end if;

  // ============ Sensor Models ============
  // Unknown: sensor noise, bias, latency — modeled as direct measurements
  z_pressure = z;
  phi_imu = phi;
  theta_imu = theta;
  psi_imu = psi;
  p_imu = p_rate;
  q_imu = q_rate;
  r_imu = r_rate;
  vx_doppler = vx;
  vy_doppler = vy;
  vz_doppler = vz;

  // ============ Cascaded Depth Control ============
  // Outer loop: depth error -> velocity reference
  vz_ref = Kp_z * (z_target - z_pressure);
  // Inner loop: velocity error -> force command
  F_heave_cmd = Kp_vz * (vz_ref - vz_doppler);

  // ============ Cascaded Heading Control ============
  // Outer loop: heading error -> rate reference
  r_ref = Kp_psi * (psi_target - psi_imu);
  // Inner loop: rate error -> torque command
  tau_yaw_cmd = Kp_r * (r_ref - r_imu);

  // ============ Cascaded Roll Control ============
  // Outer loop: roll error -> rate reference
  p_ref = Kp_phi * (0.0 - phi_imu);
  // Inner loop: rate error -> torque command
  tau_roll_cmd = Kp_p * (p_ref - p_imu);

  // ============ Surge Station-Keeping ============
  F_surge_cmd = -Kp_x * x - Kd_x * vx_doppler;

  // ============ Control Allocation ============
  // Differential horizontal thrust controls surge and yaw
  // Differential vertical thrust controls heave and roll
  Fp_h_raw = F_surge_cmd / 2.0 - tau_yaw_cmd / d_hull;
  Fs_h_raw = F_surge_cmd / 2.0 + tau_yaw_cmd / d_hull;
  Fp_v_raw = F_heave_cmd / 2.0 - tau_roll_cmd / d_hull;
  Fs_v_raw = F_heave_cmd / 2.0 + tau_roll_cmd / d_hull;

  // Propeller force magnitudes
  Fp_mag = sqrt(Fp_h_raw * Fp_h_raw + Fp_v_raw * Fp_v_raw);
  Fs_mag = sqrt(Fs_h_raw * Fs_h_raw + Fs_v_raw * Fs_v_raw);

  // Bounded allocation: saturate each propeller to F_max
  // Division by Fp_mag/Fs_mag only occurs when magnitude > F_max > 0
  Fp_h = if Fp_mag > F_max then Fp_h_raw * F_max / Fp_mag else Fp_h_raw;
  Fp_v = if Fp_mag > F_max then Fp_v_raw * F_max / Fp_mag else Fp_v_raw;
  Fs_h = if Fs_mag > F_max then Fs_h_raw * F_max / Fs_mag else Fs_h_raw;
  Fs_v = if Fs_mag > F_max then Fs_v_raw * F_max / Fs_mag else Fs_v_raw;

  // ============ Resultant Forces and Torques ============
  F_surge = Fp_h + Fs_h;
  F_heave = Fp_v + Fs_v;
  F_buoyancy_net = rho_water * V_disp * g_acc - m_total * g_acc;
  tau_roll = (Fs_v - Fp_v) * (d_hull / 2.0);
  tau_yaw = (Fs_h - Fp_h) * (d_hull / 2.0);

  // ============ Translational Dynamics ============
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  m_total * der(vx) = F_surge + F_current - k_drag_surge * vx * abs(vx);
  m_total * der(vy) = -k_drag_sway * vy * abs(vy);
  m_total * der(vz) = F_heave - F_buoyancy_net - k_drag_heave * vz * abs(vz);

  // ============ Rotational Dynamics ============
  der(phi) = p_rate;
  der(theta) = q_rate;
  der(psi) = r_rate;

  I_roll * der(p_rate) = tau_roll - k_roll_restore * phi - k_drag_roll * p_rate * abs(p_rate);
  // Pitch is passively stabilized: no dedicated pitch actuator available
  // with only two propellers (surge/yaw and heave/roll allocation fully constrained)
  I_pitch * der(q_rate) = -k_pitch_restore * theta - k_drag_pitch * q_rate * abs(q_rate);
  I_yaw * der(r_rate) = tau_yaw - k_drag_yaw * r_rate * abs(r_rate);

  // ============ Performance Metrics ============
  z_error = abs(z - z_target);

  annotation(
    experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "CatamaranDiveC: Free-base marine robot with cascaded depth and attitude control.
      Two 46 kg capsule hulls separated by 1.1 m support an 18 kg rigid deck.
      Port and starboard propellers with differential thrust for surge/heading and heave/roll.
      Neutral buoyancy in 1025 kg/m3 seawater. Quadratic drag in all DOFs.
      Bounded allocation at 396 N per propeller.
      72 N current disturbance during middle third (4-8 s).
      125 Hz sampling (Interval=0.008 s), 12 s simulation.
      Target: descend to 8 m, hold, return to 3 m at t=8 s.
      Cascaded control: depth->velocity->force, heading->rate->torque, roll->rate->torque.
      Pitch is passively stabilized (no dedicated pitch actuator).
      Unknowns not modeled: hull geometry details, propeller dynamics, sensor noise,
      current direction (assumed surge).")
  );
end CatamaranDiveC;