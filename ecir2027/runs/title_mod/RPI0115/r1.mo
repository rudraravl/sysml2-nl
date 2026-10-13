model CoaxLiftTouchA
  "Free-base coaxial aerial robot for vertical surface inspection with hybrid position-impedance control"

  // ===== Physical constants =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Robot parameters from requirement =====
  parameter Real m_platform = 4.4 "Cargo platform mass [kg]";
  parameter Real m_payload = 1.2 "Payload mass [kg]";
  parameter Real L_cable = 0.70 "Massless cable length [m]";
  parameter Real f_max_rotor = 7.2 "Command magnitude limit per rotor [N]";
  parameter Integer n_rotors = 8 "Number of rotor thrust channels";
  parameter Real mu_wall = 0.55 "Wall friction coefficient [1]";

  // ===== Assumed geometric and inertial parameters (not stated in requirement) =====
  parameter Real arm_len = 0.10 "Arm length center to rotor [m], assumed";
  parameter Real probe_len = 0.15 "Probe length center to tip [m], assumed";
  parameter Real I_pitch = 0.03 "Platform pitch inertia [kg.m2], assumed";
  parameter Real theta_max = 0.30 "Attitude command limit [rad], assumed";

  // ===== Contact model parameters (assumed) =====
  parameter Real k_contact = 1000.0 "Contact stiffness [N/m], assumed";
  parameter Real b_contact = 50.0 "Contact damping [N.s/m], assumed";
  parameter Real v_fric_thresh = 0.01 "Friction smoothing threshold [m/s], assumed";

  // ===== Trajectory parameters =====
  parameter Real x_start = 2.0 "Initial distance from wall [m]";
  parameter Real x_standoff = 0.14 "Stand-off distance for contact [m], assumed";
  parameter Real z_target = 1.0 "Target height [m]";
  parameter Real tau_traj = 1.0 "Approach time constant [s], assumed";

  // ===== Controller gains (assumed, tuned for stability) =====
  parameter Real Kp_x = 25.0 "Position x P gain [N/m]";
  parameter Real Kd_x = 10.0 "Position x D gain [N.s/m]";
  parameter Real Kp_z = 45.0 "Position z P gain [N/m]";
  parameter Real Kd_z = 16.0 "Position z D gain [N.s/m]";
  parameter Real Kp_att = 20.0 "Attitude P gain [N.m/rad]";
  parameter Real Kd_att = 5.0 "Attitude D gain [N.m.s/rad]";
  parameter Real F_contact_des = 9.5 "Desired contact force [N]";
  parameter Real K_imp = 60.0 "Impedance stiffness [N/m]";
  parameter Real B_imp = 12.0 "Impedance damping [N.s/m]";

  // ===== Disturbance =====
  parameter Real F_wind_mag = 1.5 "Tangential wind magnitude [N]";
  parameter Real t_wind_a = 2.6667 "Wind start: beginning of middle third [s]";
  parameter Real t_wind_b = 5.3333 "Wind end: end of middle third [s]";

  // ===== Derived constants =====
  Real m_total "Total mass [kg]";
  Real f_total_max "Max total thrust [N]";
  Real det_M "Mass matrix determinant [kg2]";

  // ===== Dynamic states =====
  Real x(start = x_start, fixed = true) "Distance from wall surface [m]";
  Real vx(start = 0.0, fixed = true) "Horizontal velocity, positive away [m/s]";
  Real z(start = z_target, fixed = true) "Height [m]";
  Real vz(start = 0.0, fixed = true) "Vertical velocity [m/s]";
  Real theta(start = 0.0, fixed = true) "Pitch angle, positive nose-down [rad]";
  Real omega(start = 0.0, fixed = true) "Pitch rate [rad/s]";
  Real phi(start = 0.0, fixed = true) "Pendulum angle from vertical [rad]";
  Real phid(start = 0.0, fixed = true) "Pendulum angular rate [rad/s]";

  // ===== Eight rotor thrust channels =====
  Real T1 "Rotor 1 front-upper [N]";
  Real T2 "Rotor 2 front-lower [N]";
  Real T3 "Rotor 3 rear-upper [N]";
  Real T4 "Rotor 4 rear-lower [N]";
  Real T5 "Rotor 5 rear-upper [N]";
  Real T6 "Rotor 6 rear-lower [N]";
  Real T7 "Rotor 7 front-upper [N]";
  Real T8 "Rotor 8 front-lower [N]";
  Real T_total "Total thrust [N]";
  Real T_front_sat "Saturated front per-rotor thrust [N]";
  Real T_rear_sat "Saturated rear per-rotor thrust [N]";

  // ===== Contact state =====
  Real pen "Probe penetration depth [m]";
  Real F_normal "Normal contact force [N]";
  Real F_fric "Friction force tangential [N]";
  Boolean in_contact "Contact flag";

  // ===== Wind disturbance =====
  Real F_wind "Wind disturbance force [N]";

  // ===== Controller variables =====
  Real x_ref "Reference x position [m]";
  Real z_ref "Reference z position [m]";
  Real blend "Controller blend 0=pos 1=imp [1]";
  Real F_x_pos "Position mode force [N]";
  Real F_x_imp "Impedance mode force [N]";
  Real F_x_cmd "Horizontal force command [N]";
  Real F_z_cmd "Vertical force command [N]";
  Real F_z_eff "Effective vertical command [N]";
  Real F_total_cmd "Total thrust command [N]";
  Real theta_cmd "Pitch command [rad]";
  Real theta_cmd_lim "Limited pitch command [rad]";
  Real tau_cmd "Torque command [N.m]";
  Real T_front_cmd "Front group command [N]";
  Real T_rear_cmd "Rear group command [N]";
  Real T_front_raw "Raw front per-rotor [N]";
  Real T_rear_raw "Raw rear per-rotor [N]";

  // ===== Sensors =====
  Real lidar_meas "Lidar range to wall [m]";
  Real imu_ax "IMU x acceleration [m/s2]";
  Real imu_az "IMU z acceleration [m/s2]";
  Real flow_vx "Optical flow vx [m/s]";
  Real flow_vz "Optical flow vz [m/s]";
  Real probe_force_meas "Probe force sensor [N]";

  // ===== Verification observables =====
  Real track_err "Primary tracking error from stand-off [m]";
  Real rotor_tip_clear "Rotor tip clearance from wall [m]";
  Real max_rotor_thrust "Maximum individual rotor thrust [N]";
  Real T_cable "Cable tension [N]";

  // ===== Internal acceleration and matrix variables =====
  Real ax "Platform x acceleration [m/s2]";
  Real az "Platform z acceleration [m/s2]";
  Real phidd "Pendulum angular acceleration [rad/s2]";
  Real omegad "Pitch angular acceleration [rad/s2]";
  Real M11 "Mass matrix element 11 [kg]";
  Real M12 "Mass matrix element 12 [kg]";
  Real M22 "Mass matrix element 22 [kg]";
  Real RHS1 "RHS x-equation [N]";
  Real RHS2 "RHS z-equation [N]";
  Real F_damp "Contact damping force [N]";
  Real max_T12 "Max of T1 T2 [N]";
  Real max_T34 "Max of T3 T4 [N]";
  Real max_T56 "Max of T5 T6 [N]";
  Real max_T78 "Max of T7 T8 [N]";
  Real max_T1234 "Max front group [N]";
  Real max_T5678 "Max rear group [N]";

equation
  // === Derived constants ===
  m_total = m_platform + m_payload;
  f_total_max = n_rotors * f_max_rotor;
  det_M = m_platform * (m_platform + m_payload);

  // === Reference trajectory: exponential approach to stand-off ===
  x_ref = x_standoff + (x_start - x_standoff) * exp(-time / tau_traj);
  z_ref = z_target;

  // === Wind disturbance (tangential/vertical, middle third of scenario) ===
  F_wind = if (time >= t_wind_a and time <= t_wind_b) then F_wind_mag else 0.0;

  // === Contact model: wall at x=0, probe extends toward wall ===
  pen = if (probe_len - x) > 0.0 then (probe_len - x) else 0.0;
  in_contact = pen > 0.0;
  F_damp = if vx < 0.0 then b_contact * (-vx) else 0.0;
  F_normal = if pen > 0.0 then k_contact * pen + F_damp else 0.0;
  F_fric = if pen > 0.0 then -mu_wall * F_normal * tanh(vz / v_fric_thresh) else 0.0;

  // === Probe force sensor ===
  probe_force_meas = F_normal;

  // === Smooth blend between position and impedance control ===
  blend = if x > probe_len + 0.4 then 0.0
          elseif x < probe_len - 0.4 then 1.0
          else 1.0 / (1.0 + exp((x - probe_len) / 0.02));

  // === Hybrid controller: position-to-impedance ===
  F_x_pos = Kp_x * (x_ref - x) - Kd_x * vx;
  F_x_imp = -(F_contact_des + K_imp * (x - x_ref) + B_imp * vx);
  F_x_cmd = blend * F_x_imp + (1.0 - blend) * F_x_pos;

  // Vertical force with gravity feedforward
  F_z_cmd = Kp_z * (z_ref - z) - Kd_z * vz + m_total * g;
  F_z_eff = if F_z_cmd > 0.0 then F_z_cmd else 0.0;

  // Total thrust and pitch commands
  F_total_cmd = sqrt(F_x_cmd * F_x_cmd + F_z_eff * F_z_eff);
  theta_cmd = if F_z_eff > 1.0 then atan(-F_x_cmd / F_z_eff) else atan(-F_x_cmd);
  theta_cmd_lim = if theta_cmd > theta_max then theta_max
                  elseif theta_cmd < -theta_max then -theta_max
                  else theta_cmd;

  // Attitude PD controller
  tau_cmd = Kp_att * (theta_cmd_lim - theta) - Kd_att * omega;

  // === Thrust allocation: 4 front + 4 rear rotors ===
  T_front_cmd = (F_total_cmd + tau_cmd / arm_len) / 2.0;
  T_rear_cmd = (F_total_cmd - tau_cmd / arm_len) / 2.0;
  T_front_raw = T_front_cmd / 4.0;
  T_rear_raw = T_rear_cmd / 4.0;

  // Saturate each rotor to [0, f_max_rotor]
  T_front_sat = if T_front_raw > f_max_rotor then f_max_rotor
                elseif T_front_raw < 0.0 then 0.0
                else T_front_raw;
  T_rear_sat = if T_rear_raw > f_max_rotor then f_max_rotor
               elseif T_rear_raw < 0.0 then 0.0
               else T_rear_raw;

  T1 = T_front_sat;
  T2 = T_front_sat;
  T7 = T_front_sat;
  T8 = T_front_sat;
  T3 = T_rear_sat;
  T4 = T_rear_sat;
  T5 = T_rear_sat;
  T6 = T_rear_sat;

  T_total = T1 + T2 + T3 + T4 + T5 + T6 + T7 + T8;

  // Max rotor thrust observable
  max_T12 = if T1 > T2 then T1 else T2;
  max_T34 = if T3 > T4 then T3 else T4;
  max_T56 = if T5 > T6 then T5 else T6;
  max_T78 = if T7 > T8 then T7 else T8;
  max_T1234 = if max_T12 > max_T34 then max_T12 else max_T34;
  max_T5678 = if max_T56 > max_T78 then max_T56 else max_T78;
  max_rotor_thrust = if max_T1234 > max_T5678 then max_T1234 else max_T5678;

  // === Pitch dynamics ===
  omegad = ((T1 + T2 + T7 + T8) - (T3 + T4 + T5 + T6)) * arm_len / I_pitch;

  // === Coupled platform-payload dynamics (cable tension eliminated) ===
  // Mass matrix for [ax; az] after substituting cable constraint
  M11 = m_platform + m_payload * sin(phi) * sin(phi);
  M12 = -m_payload * sin(phi) * cos(phi);
  M22 = m_platform + m_payload * cos(phi) * cos(phi);

  // Right-hand sides: thrust, contact, wind, gravity, pendulum centrifugal
  RHS1 = -T_total * sin(theta) + F_normal
         + m_payload * sin(phi) * (g * cos(phi) + L_cable * phid * phid);
  RHS2 = T_total * cos(theta) - m_platform * g + F_fric + F_wind
         - m_payload * cos(phi) * (g * cos(phi) + L_cable * phid * phid);

  // Solve 2x2 via Cramer's rule, det = m_platform*(m_platform+m_payload) > 0
  ax = (M22 * RHS1 - M12 * RHS2) / det_M;
  az = (-M12 * RHS1 + M11 * RHS2) / det_M;

  // Cable tension for observation
  T_cable = m_payload * (g * cos(phi) - sin(phi) * ax + cos(phi) * az
           + L_cable * phid * phid);

  // Pendulum angular acceleration
  phidd = (-cos(phi) * ax - sin(phi) * (az + g)) / L_cable;

  // === State derivatives ===
  der(x) = vx;
  der(vx) = ax;
  der(z) = vz;
  der(vz) = az;
  der(theta) = omega;
  der(omega) = omegad;
  der(phi) = phid;
  der(phid) = phidd;

  // === Sensors (ideal, no noise) ===
  lidar_meas = x;
  imu_ax = ax;
  imu_az = az;
  flow_vx = vx;
  flow_vz = vz;

  // === Verification observables ===
  track_err = abs(x - x_standoff);
  rotor_tip_clear = x - arm_len;

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "CoaxLiftTouchA: 4.4 kg platform with 1.2 kg payload on 0.70 m massless cable, 8 coaxial rotors (7.2 N max each). Hybrid position-impedance control for vertical wall inspection. Wall at x=0 with friction 0.55. Wind 1.5 N tangential during middle third. 80 Hz sample rate, 8 s duration. Assumed: arm_len, probe_len, I_pitch, contact stiffness/damping, controller gains, stand-off distance, trajectory time constant, attitude limit, sensor noise model."));
end CoaxLiftTouchA;