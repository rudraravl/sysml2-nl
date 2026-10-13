model SeaSnakeDiveC
  "Free-base 32 kg articulated underwater robot: 6 capsule modules (0.30 m), 12 bounded joints (alternating yaw/pitch), passive tail fin. Cascaded depth/attitude control with bounded allocation. Mission: dive to 8 m, hold, return to 3 m. 72 N current disturbance in middle third. Sensors: pressure depth, IMU, Doppler velocity. Physics: gravity, buoyancy (rho=1025), quadratic drag."

  constant Real pi = 3.14159265358979;

  // ===== Stated parameters =====
  parameter Real m_robot = 32.0   "Robot mass [kg]";
  parameter Real L_module = 0.30   "Module length [m]";
  parameter Integer N_modules = 6  "Number of capsule modules";
  parameter Integer N_joints = 12  "Number of actuated joints";
  parameter Real rho_water = 1025.0 "Seawater density [kg/m3]";
  parameter Real g = 9.81          "Gravitational acceleration [m/s2]";
  parameter Real tau_max = 29.4     "Maximum joint command magnitude [N.m]";
  parameter Real F_dist_mag = 72.0  "Current disturbance force [N]";
  parameter Real T_sim = 12.0       "Total simulation time [s]";
  parameter Real f_sample = 125.0   "Sample rate [Hz]";

  // ===== Mission trajectory =====
  parameter Real depth_dive = 8.0   "Dive target depth [m]";
  parameter Real depth_return = 3.0 "Return target depth [m]";
  parameter Real t_dive_end = 4.5   "End of dive phase [s]";
  parameter Real t_hold_end = 8.0   "End of hold phase [s]";
  parameter Real t_dist_start = 4.0 "Disturbance start [s] (middle third)";
  parameter Real t_dist_end = 8.0   "Disturbance end [s] (middle third)";

  // ===== Derived geometry (neutral-buoyancy volume from stated mass and density) =====
  parameter Real V_displaced = m_robot / rho_water
    "Displaced volume for neutral buoyancy [m3]";
  parameter Real r_equiv = sqrt(V_displaced / (pi * N_modules * L_module))
    "Equivalent capsule radius [m]";
  parameter Real L_total = N_modules * L_module "Total body length [m]";
  parameter Real A_front = pi * r_equiv * r_equiv "Frontal area [m2]";
  parameter Real A_tail = 0.008 "Passive tail fin area [m2] (estimated)";
  parameter Real A_side = 2.0 * r_equiv * L_total + A_tail
    "Lateral profile area including tail fin [m2]";

  // ===== Inertia (estimated from uniform slender body) =====
  parameter Real m_added = 0.15 * m_robot "Added mass [kg] (estimated)";
  parameter Real m_eff = m_robot + m_added "Effective mass [kg]";
  parameter Real Ixx = m_robot * r_equiv * r_equiv / 2.0
    "Roll inertia [kg.m2] (estimated)";
  parameter Real Iyy = m_robot * L_total * L_total / 12.0
    "Pitch inertia [kg.m2] (estimated)";
  parameter Real Izz = m_robot * L_total * L_total / 12.0
    "Yaw inertia [kg.m2] (estimated)";

  // ===== Gravity and buoyancy =====
  parameter Real W = m_robot * g "Weight [N]";
  parameter Real B = rho_water * V_displaced * g "Buoyancy force [N]";
  parameter Real delta_B = 1.0
    "Residual buoyancy, positive = net upward [N] (estimated)";

  // ===== Drag coefficients (estimated) =====
  parameter Real Cd_axial = 0.8  "Axial drag coefficient";
  parameter Real Cd_lateral = 1.2 "Lateral drag coefficient";
  parameter Real Cd_rot = 0.5    "Rotational drag coefficient [N.m.s2/rad2]";

  // ===== Propulsion model (estimated) =====
  parameter Real k_prop = 4.0   "Thrust scale [N/(N.m)] (estimated)";
  parameter Real k_moment = 0.5 "Body moment scale (estimated)";
  parameter Real k_rest = 2.0   "Restoring moment coefficient [N.m/rad]";
  parameter Real gait_freq = 1.2 "Undulatory gait frequency [Hz]";
  parameter Real gait_amp = 0.5  "Gait amplitude (fraction of tau_max)";

  // ===== Controller gains =====
  parameter Real Kp_depth = 2.0  "Depth proportional gain";
  parameter Real Kd_depth = 1.5   "Depth derivative gain";
  parameter Real Kp_pitch = 40.0  "Pitch proportional gain";
  parameter Real Kd_pitch = 8.0  "Pitch derivative gain";
  parameter Real Kp_yaw = 25.0    "Yaw proportional gain";
  parameter Real Kd_yaw = 4.0     "Yaw derivative gain";
  parameter Real Kp_roll = 40.0   "Roll proportional gain";
  parameter Real Kd_roll = 8.0    "Roll derivative gain";
  parameter Real pitch_limit = 0.30 "Pitch command limit [rad]";

  // ===== Kinematic states =====
  Real z(start=0.0, fixed=true)     "Depth [m], positive downward";
  Real vz(start=0.0, fixed=true)    "Vertical velocity [m/s]";
  Real x(start=0.0, fixed=true)     "Forward position [m]";
  Real vx(start=0.0, fixed=true)    "Forward velocity [m/s]";
  Real y(start=0.0, fixed=true)     "Lateral position [m]";
  Real vy(start=0.0, fixed=true)    "Lateral velocity [m/s]";
  Real phi(start=0.001, fixed=true) "Roll angle [rad]";
  Real p(start=0.0, fixed=true)     "Roll rate [rad/s]";
  Real theta(start=0.001, fixed=true) "Pitch angle [rad]";
  Real q(start=0.0, fixed=true)     "Pitch rate [rad/s]";
  Real psi(start=0.0, fixed=true)   "Heading (yaw) [rad]";
  Real r_rate(start=0.0, fixed=true) "Yaw rate [rad/s]";

  // ===== Joint actuators (12 joints, alternating yaw/pitch) =====
  Real tau_cmd[12] "Joint torque commands [N.m]";
  Real tau_sat[12] "Saturated joint torques [N.m]";
  Real gait_phase  "Undulatory gait phase [rad]";

  // ===== Propulsion outputs =====
  Real F_thrust_body  "Body-axis thrust [N]";
  Real F_prop_x       "Surge propulsion force (world) [N]";
  Real F_prop_z       "Vertical propulsion force (world) [N]";
  Real M_prop_pitch   "Propulsion pitch moment [N.m]";
  Real M_prop_yaw     "Propulsion yaw moment [N.m]";
  Real M_prop_roll    "Propulsion roll moment [N.m]";

  // ===== Disturbance and drag =====
  Real F_dist_x      "Current disturbance force [N]";
  Real F_drag_z      "Vertical quadratic drag [N]";
  Real F_drag_x      "Surge quadratic drag [N]";
  Real F_drag_y      "Sway quadratic drag [N]";
  Real M_drag_pitch  "Pitch rotational drag [N.m]";
  Real M_drag_roll   "Roll rotational drag [N.m]";
  Real M_drag_yaw    "Yaw rotational drag [N.m]";
  Real M_rest_pitch  "Pitch restoring moment [N.m]";
  Real M_rest_roll   "Roll restoring moment [N.m]";

  // ===== Controller signals =====
  Real depth_ref    "Depth reference trajectory [m]";
  Real depth_err    "Depth tracking error [m]";
  Real pitch_cmd    "Commanded pitch [rad]";
  Real pitch_err    "Pitch error [rad]";
  Real yaw_err      "Heading error [rad]";
  Real roll_err     "Roll error [rad]";
  Real M_pitch_cmd  "Commanded pitch moment [N.m]";
  Real M_yaw_cmd    "Commanded yaw moment [N.m]";
  Real M_roll_cmd   "Commanded roll moment [N.m]";
  Real tracking_err "Primary tracking error (absolute) [m]";

  // ===== Sensor outputs =====
  Real z_meas     "Pressure depth measurement [m]";
  Real phi_meas   "IMU roll [rad]";
  Real theta_meas "IMU pitch [rad]";
  Real psi_meas   "IMU heading [rad]";
  Real vx_meas    "Doppler surge velocity [m/s]";
  Real vy_meas    "Doppler sway velocity [m/s]";
  Real vz_meas    "Doppler vertical velocity [m/s]";

  // ===== Observability metrics =====
  Real max_tau_sat "Maximum |saturated torque| across 12 joints [N.m]";
  Real max_tau_cmd "Maximum |commanded torque| across 12 joints [N.m]";

equation
  // ===== Depth reference trajectory (smooth cosine blend) =====
  if time < t_dive_end then
    depth_ref = depth_dive * (1.0 - cos(pi * time / t_dive_end)) / 2.0;
  elseif time < t_hold_end then
    depth_ref = depth_dive;
  else
    depth_ref = depth_dive + (depth_return - depth_dive)
      * (1.0 - cos(pi * (time - t_hold_end) / (T_sim - t_hold_end))) / 2.0;
  end if;

  tracking_err = abs(z - depth_ref);

  // ===== Current disturbance (middle third of 12 s) =====
  if time >= t_dist_start and time <= t_dist_end then
    F_dist_x = F_dist_mag;
  else
    F_dist_x = 0.0;
  end if;

  // ===== Gait phase for undulatory propulsion =====
  gait_phase = 2.0 * pi * gait_freq * time;

  // ===== Sensors (ideal) =====
  z_meas = z;
  phi_meas = phi;
  theta_meas = theta;
  psi_meas = psi;
  vx_meas = vx;
  vy_meas = vy;
  vz_meas = vz;

  // ===== Cascaded controller =====
  // Outer loop: depth error -> commanded pitch (bounded)
  depth_err = depth_ref - z_meas;
  pitch_cmd = max(-pitch_limit, min(pitch_limit,
    Kp_depth * depth_err - Kd_depth * vz_meas));

  // Hold zero heading and zero roll
  yaw_err = 0.0 - psi_meas;
  roll_err = 0.0 - phi_meas;
  pitch_err = pitch_cmd - theta_meas;

  // Inner loop: attitude errors -> body moment commands
  M_pitch_cmd = Kp_pitch * pitch_err - Kd_pitch * q;
  M_yaw_cmd = Kp_yaw * yaw_err - Kd_yaw * r_rate;
  M_roll_cmd = Kp_roll * roll_err - Kd_roll * p;

  // ===== Bounded allocation: 12 joints, alternating yaw (odd) / pitch (even) =====
  // Each joint receives a control component plus a gait traveling-wave component
  tau_cmd[1]  = M_yaw_cmd/6.0   + gait_amp*tau_max*sin(gait_phase);
  tau_cmd[2]  = M_pitch_cmd/6.0 + gait_amp*tau_max*sin(gait_phase + pi/6.0);
  tau_cmd[3]  = M_yaw_cmd/6.0   + gait_amp*tau_max*sin(gait_phase + pi/3.0);
  tau_cmd[4]  = M_pitch_cmd/6.0 + gait_amp*tau_max*sin(gait_phase + pi/2.0);
  tau_cmd[5]  = M_yaw_cmd/6.0   + gait_amp*tau_max*sin(gait_phase + 2.0*pi/3.0);
  tau_cmd[6]  = M_pitch_cmd/6.0 + gait_amp*tau_max*sin(gait_phase + 5.0*pi/6.0);
  tau_cmd[7]  = M_yaw_cmd/6.0   + gait_amp*tau_max*sin(gait_phase + pi);
  tau_cmd[8]  = M_pitch_cmd/6.0 + gait_amp*tau_max*sin(gait_phase + 7.0*pi/6.0);
  tau_cmd[9]  = M_yaw_cmd/6.0   + gait_amp*tau_max*sin(gait_phase + 4.0*pi/3.0);
  tau_cmd[10] = M_pitch_cmd/6.0 + gait_amp*tau_max*sin(gait_phase + 3.0*pi/2.0);
  tau_cmd[11] = M_yaw_cmd/6.0   + gait_amp*tau_max*sin(gait_phase + 5.0*pi/3.0);
  tau_cmd[12] = M_pitch_cmd/6.0 + gait_amp*tau_max*sin(gait_phase + 11.0*pi/6.0);

  // Actuator saturation (bounded allocation)
  tau_sat[1]  = max(-tau_max, min(tau_max, tau_cmd[1]));
  tau_sat[2]  = max(-tau_max, min(tau_max, tau_cmd[2]));
  tau_sat[3]  = max(-tau_max, min(tau_max, tau_cmd[3]));
  tau_sat[4]  = max(-tau_max, min(tau_max, tau_cmd[4]));
  tau_sat[5]  = max(-tau_max, min(tau_max, tau_cmd[5]));
  tau_sat[6]  = max(-tau_max, min(tau_max, tau_cmd[6]));
  tau_sat[7]  = max(-tau_max, min(tau_max, tau_cmd[7]));
  tau_sat[8]  = max(-tau_max, min(tau_max, tau_cmd[8]));
  tau_sat[9]  = max(-tau_max, min(tau_max, tau_cmd[9]));
  tau_sat[10] = max(-tau_max, min(tau_max, tau_cmd[10]));
  tau_sat[11] = max(-tau_max, min(tau_max, tau_cmd[11]));
  tau_sat[12] = max(-tau_max, min(tau_max, tau_cmd[12]));

  // ===== Propulsion from saturated joint torques =====
  // Undulatory thrust (sum of absolute joint torques)
  F_thrust_body = k_prop * (
    abs(tau_sat[1])  + abs(tau_sat[2])  + abs(tau_sat[3])  + abs(tau_sat[4]) +
    abs(tau_sat[5])  + abs(tau_sat[6])  + abs(tau_sat[7])  + abs(tau_sat[8]) +
    abs(tau_sat[9])  + abs(tau_sat[10]) + abs(tau_sat[11]) + abs(tau_sat[12]));

  // Thrust projection to world frame via body pitch
  F_prop_x = F_thrust_body * cos(theta);
  F_prop_z = F_thrust_body * sin(theta);

  // Body moments from cascaded controller (idealized allocation)
  M_prop_pitch = k_moment * M_pitch_cmd;
  M_prop_yaw   = k_moment * M_yaw_cmd;
  M_prop_roll  = k_moment * M_roll_cmd;

  // ===== Quadratic drag =====
  F_drag_z = -0.5 * rho_water * Cd_axial * A_front * vz * abs(vz);
  F_drag_x = -0.5 * rho_water * Cd_lateral * A_side * vx * abs(vx);
  F_drag_y = -0.5 * rho_water * Cd_lateral * A_side * vy * abs(vy);
  M_drag_pitch = -Cd_rot * q * abs(q);
  M_drag_roll  = -Cd_rot * p * abs(p);
  M_drag_yaw   = -Cd_rot * r_rate * abs(r_rate);

  // ===== Restoring moments (gravity–buoyancy metacentric effect) =====
  M_rest_pitch = -k_rest * sin(theta);
  M_rest_roll  = -k_rest * sin(phi);

  // ===== Equations of motion =====
  // Translation
  der(z) = vz;
  m_eff * der(vz) = -delta_B + F_prop_z + F_drag_z;

  der(x) = vx;
  m_eff * der(vx) = F_prop_x + F_drag_x;

  der(y) = vy;
  m_eff * der(vy) = F_dist_x + F_drag_y;

  // Rotation
  der(phi) = p;
  Ixx * der(p) = M_prop_roll + M_rest_roll + M_drag_roll;

  der(theta) = q;
  Iyy * der(q) = M_prop_pitch + M_rest_pitch + M_drag_pitch;

  der(psi) = r_rate;
  Izz * der(r_rate) = M_prop_yaw + M_drag_yaw;

  // ===== Actuator bound observability =====
  max_tau_cmd = max(max(max(max(max(max(max(max(max(max(max(
    abs(tau_cmd[1]),abs(tau_cmd[2])),abs(tau_cmd[3])),abs(tau_cmd[4])),
    abs(tau_cmd[5])),abs(tau_cmd[6])),abs(tau_cmd[7])),abs(tau_cmd[8])),
    abs(tau_cmd[9])),abs(tau_cmd[10])),abs(tau_cmd[11])),abs(tau_cmd[12]));

  max_tau_sat = max(max(max(max(max(max(max(max(max(max(max(
    abs(tau_sat[1]),abs(tau_sat[2])),abs(tau_sat[3])),abs(tau_sat[4])),
    abs(tau_sat[5])),abs(tau_sat[6])),abs(tau_sat[7])),abs(tau_sat[8])),
    abs(tau_sat[9])),abs(tau_sat[10])),abs(tau_sat[11])),abs(tau_sat[12]));

  annotation (
    Documentation(info="SeaSnakeDiveC: Free-base 32 kg articulated underwater robot. Six 0.30 m capsule modules connected by 12 alternating yaw/pitch joints (odd=yaw, even=pitch) plus a passive tail fin. Twelve bounded joint actuators (max 29.4 N.m) generate undulatory propulsion. Cascaded depth/attitude control with bounded allocation: outer depth loop commands pitch, inner attitude loop commands body moments, allocation distributes to joints with actuator saturation. Mission: dive to 8 m, hold at 8 m with zero heading, return to 3 m. 72 N lateral current disturbance injected during middle third (4-8 s). Feedback: pressure depth, IMU (roll/pitch/yaw), Doppler velocity log. Physics: gravity, buoyancy (seawater 1025 kg/m3), quadratic drag. Volume derived from stated mass and density for neutral buoyancy; residual buoyancy, added mass, drag coefficients, propulsion scale, and inertias are estimated and labeled. Run at 125 Hz (interval 0.008 s) for 12 s."),
    experiment(StopTime=12.0, StartTime=0.0, Tolerance=1e-6, Interval=0.008)
  );
end SeaSnakeDiveC;