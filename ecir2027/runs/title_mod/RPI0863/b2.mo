model AUVDockE "Free-base AUV docking scenario with compliant capture";

  // ===== Physical Constants =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real rho_sw = 1025.0 "Seawater density [kg/m3]";

  // ===== Vehicle Parameters =====
  parameter Real m_hull = 85.0 "Hull mass [kg]";
  parameter Real L_hull = 1.5 "Hull length [m]";
  parameter Real V_disp = 0.083 "Displaced volume [m3]";
  parameter Real Izz = m_hull * L_hull * L_hull / 12.0 "Yaw inertia [kg.m2]";
  parameter Real W_hull = m_hull * g "Weight [N]";
  parameter Real Buoy = rho_sw * g * V_disp "Buoyancy [N]";
  parameter Real d_thruster = 0.4 "Surge thruster lateral spacing [m]";
  parameter Real Fmax = 121.0 "Max thruster force per unit [N]";

  // ===== Hydrodynamic Drag =====
  parameter Real Xu = 80.0 "Surge linear drag [N.s/m]";
  parameter Real Yv = 400.0 "Sway linear drag [N.s/m]";
  parameter Real Zw = 80.0 "Heave linear drag [N.s/m]";
  parameter Real Nr = 15.0 "Yaw rotational drag [N.m.s/rad]";

  // ===== Dock Geometry =====
  parameter Real x_dock = 8.0 "Dock centerline x-position [m]";
  parameter Real x_funnel = 7.0 "Funnel entry x-position [m]";
  parameter Real R_capture = 0.08 "Capture radius [m]";
  parameter Real funnel_len = x_dock - x_funnel "Funnel length [m]";

  // ===== Compliant Capture Ring =====
  parameter Real k_contact = 5000.0 "Contact stiffness [N/m]";
  parameter Real b_contact = 120.0 "Contact damping [N.s/m]";

  // ===== Cross-Current Disturbance =====
  parameter Real F_current = 168.0 "Current force magnitude [N]";
  parameter Real t_curr_start = 16.0 / 3.0 "Current start time [s]";
  parameter Real t_curr_end = 2.0 * 16.0 / 3.0 "Current end time [s]";

  // ===== Control Parameters =====
  parameter Real v_max_far = 1.5 "Far-zone speed limit [m/s]";
  parameter Real v_max_near = 0.5 "Near-zone speed limit [m/s]";
  parameter Real near_thresh = 1.0 "Near-zone range threshold [m]";
  parameter Real k_speed = 80.0 "Speed feedback gain [N.s/m]";
  parameter Real k_yaw = 40.0 "Yaw position gain [N.m/rad]";
  parameter Real k_yawk = 8.0 "Yaw rate gain [N.m.s/rad]";
  parameter Real k_lat = 0.5 "Near-zone lateral gain [rad/m]";
  parameter Real k_heave = 60.0 "Heave position gain [N/m]";
  parameter Real k_heave_d = 25.0 "Heave velocity gain [N.s/m]";

  // ===== Acceptance Parameters =====
  parameter Real t_track_check = 10.4 "Tracking-error check start [s]";
  parameter Real track_err_limit = 0.09 "Max tracking error [m]";
  parameter Real F_contact_limit = 500.0 "Max contact force [N]";
  parameter Real yaw_align_limit = 0.15 "Yaw alignment limit [rad]";
  parameter Real lat_align_limit = 0.1 "Lateral alignment limit [m]";
  parameter Real v_capture_max = 0.05 "Capture speed threshold [m/s]";

  // ===== Dynamic States =====
  Real x(start = 0.0, fixed = true) "World x-position [m]";
  Real y(start = 0.15, fixed = true) "World y-position [m]";
  Real z(start = 0.0, fixed = true) "World z-position [m]";
  Real psi(start = 0.0, fixed = true) "Yaw angle [rad]";
  Real u(start = 0.0, fixed = true) "Surge velocity body [m/s]";
  Real v(start = 0.0, fixed = true) "Sway velocity body [m/s]";
  Real w(start = 0.0, fixed = true) "Heave velocity body [m/s]";
  Real r(start = 0.0, fixed = true) "Yaw rate [rad/s]";

  // ===== Thruster Forces =====
  Real F_port "Port surge thruster force [N]";
  Real F_stbd "Starboard surge thruster force [N]";
  Real F_fwd "Forward heave thruster force [N]";
  Real F_aft "Aft heave thruster force [N]";

  // ===== Control Variables =====
  Real range_to_dock "Range to dock [m]";
  Real near_zone "Near-zone flag (0.0 or 1.0)";
  Real v_max "Scheduled speed limit [m/s]";
  Real v_desired "Desired surge speed [m/s]";
  Real F_surge_cmd "Surge force command [N]";
  Real M_yaw_cmd "Yaw moment command [N.m]";
  Real yaw_desired "Desired yaw angle [rad]";
  Real F_heave_cmd "Heave force command [N]";

  // ===== External Forces =====
  Real F_current_y "Current force world-y [N]";
  Real F_contact_y "Contact force world-y [N]";
  Real F_contact_z "Contact force world-z [N]";
  Real F_contact_mag "Contact force magnitude [N]";
  Real funnel_factor "Funnel penetration factor [0..1]";
  Real in_funnel "1.0 if inside funnel, 0.0 otherwise";

  // ===== Sensors =====
  Real sonar_range "Sonar range to dock [m]";
  Real pressure_depth "Pressure-derived depth [m]";
  Real imu_yaw "IMU yaw measurement [rad]";
  Real imu_yawrate "IMU yaw rate [rad/s]";
  Real optical_y "Optical lateral pose [m]";
  Real optical_z "Optical vertical pose [m]";
  Real optical_valid "Optical measurement valid (0.0 or 1.0)";

  // ===== Tracking and Capture =====
  Real track_error "Primary tracking error [m]";
  Real captured "1.0 if captured, 0.0 otherwise";

  // ===== Acceptance (continuous) =====
  Real bound_ok "1.0 if bounds satisfied, 0.0 otherwise";
  Real nan_ok "1.0 if all finite, 0.0 otherwise";

  // ===== Acceptance (latched, discrete) =====
  discrete Real bound_ok_latched(start = 1.0, fixed = true);
  discrete Real contact_ok_latched(start = 1.0, fixed = true);
  discrete Real nan_ok_latched(start = 1.0, fixed = true);
  discrete Real track_ok_latched(start = 1.0, fixed = true);
  discrete Real capture_latched(start = 0.0, fixed = true);
  discrete Real align_latched(start = 0.0, fixed = true);
  Real acceptance "Overall fail-closed acceptance [0.0 or 1.0]";

equation
  // ===== Cross-Current Disturbance (middle third of run) =====
  F_current_y = if time >= t_curr_start then
                  (if time <= t_curr_end then F_current else 0.0)
                else 0.0;

  // ===== Range and Zone Determination =====
  range_to_dock = x_dock - x;
  near_zone = if range_to_dock > near_thresh then 0.0 else 1.0;
  v_max = v_max_far * (1.0 - near_zone) + v_max_near * near_zone;

  // ===== Sensors =====
  sonar_range = max(range_to_dock, 0.0);
  pressure_depth = z;
  imu_yaw = psi;
  imu_yawrate = r;
  optical_valid = if range_to_dock < 2.0 then 1.0 else 0.0;
  optical_y = if range_to_dock < 2.0 then y else 0.0;
  optical_z = if range_to_dock < 2.0 then z else 0.0;

  // ===== Speed-Scheduled Pose Control =====
  v_desired = max(0.0, min(v_max, range_to_dock * 0.5));

  // Surge force command: feedforward drag + speed feedback
  F_surge_cmd = Xu * v_desired + k_speed * (v_desired - u);

  // Yaw command: LOS guidance far, optical correction near
  yaw_desired = if near_zone > 0.5 then
                  (if optical_valid > 0.5 then -k_lat * optical_y else 0.0)
                else
                  atan2(-y, max(range_to_dock, 0.01));

  // Yaw moment: PD control
  M_yaw_cmd = k_yaw * (yaw_desired - psi) - k_yawk * r;

  // Heave: position/velocity PD with buoyancy feedforward
  F_heave_cmd = -k_heave * z - k_heave_d * w - (Buoy - W_hull);

  // ===== Control Allocation =====
  F_port = max(-Fmax, min(Fmax, F_surge_cmd / 2.0 - M_yaw_cmd / d_thruster));
  F_stbd = max(-Fmax, min(Fmax, F_surge_cmd / 2.0 + M_yaw_cmd / d_thruster));
  F_fwd = max(-Fmax, min(Fmax, F_heave_cmd / 2.0));
  F_aft = max(-Fmax, min(Fmax, F_heave_cmd / 2.0));

  // ===== Compliant Capture Ring =====
  in_funnel = if x >= x_funnel then 1.0 else 0.0;
  funnel_factor = if in_funnel > 0.5 then
                    max(0.0, min(1.0, (x - x_funnel) / funnel_len))
                  else 0.0;
  F_contact_y = if in_funnel > 0.5 then
                  -k_contact * funnel_factor * y - b_contact * funnel_factor * v
                else 0.0;
  F_contact_z = if in_funnel > 0.5 then
                  -k_contact * funnel_factor * z - b_contact * funnel_factor * w
                else 0.0;
  F_contact_mag = sqrt(F_contact_y * F_contact_y + F_contact_z * F_contact_z);

  // ===== Vehicle Dynamics (body-frame forces, world-frame kinematics) =====
  m_hull * der(u) = (F_port + F_stbd) + (F_current_y + F_contact_y) * sin(psi) - Xu * u;
  m_hull * der(v) = (F_current_y + F_contact_y) * cos(psi) - Yv * v;
  m_hull * der(w) = (F_fwd + F_aft) + (Buoy - W_hull) + F_contact_z - Zw * w;
  Izz * der(r) = (F_stbd - F_port) * d_thruster / 2.0 - Nr * r;

  // Kinematics
  der(x) = u * cos(psi) - v * sin(psi);
  der(y) = u * sin(psi) + v * cos(psi);
  der(z) = w;
  der(psi) = r;

  // ===== Tracking Error =====
  track_error = sqrt(y * y + z * z);

  // ===== Capture Condition =====
  captured = in_funnel
             * (if abs(y) < R_capture then 1.0 else 0.0)
             * (if abs(z) < R_capture then 1.0 else 0.0)
             * (if abs(u) < v_capture_max then 1.0 else 0.0)
             * (if abs(v) < v_capture_max then 1.0 else 0.0);

  // ===== Continuous Acceptance Checks =====
  bound_ok = (if abs(F_port) <= Fmax + 0.001 then 1.0 else 0.0)
             * (if abs(F_stbd) <= Fmax + 0.001 then 1.0 else 0.0)
             * (if abs(F_fwd) <= Fmax + 0.001 then 1.0 else 0.0)
             * (if abs(F_aft) <= Fmax + 0.001 then 1.0 else 0.0)
             * (if abs(u) <= v_max_far + 0.1 then 1.0 else 0.0);

  nan_ok = (if abs(x) < 1e6 then 1.0 else 0.0)
           * (if abs(y) < 1e6 then 1.0 else 0.0)
           * (if abs(z) < 1e6 then 1.0 else 0.0)
           * (if abs(u) < 1e6 then 1.0 else 0.0)
           * (if abs(v) < 1e6 then 1.0 else 0.0)
           * (if abs(w) < 1e6 then 1.0 else 0.0)
           * (if abs(psi) < 1e6 then 1.0 else 0.0)
           * (if abs(r) < 1e6 then 1.0 else 0.0)
           * (if abs(F_port) < 1e6 then 1.0 else 0.0)
           * (if abs(F_stbd) < 1e6 then 1.0 else 0.0)
           * (if abs(F_fwd) < 1e6 then 1.0 else 0.0)
           * (if abs(F_aft) < 1e6 then 1.0 else 0.0)
           * (if abs(track_error) < 1e6 then 1.0 else 0.0)
           * (if abs(F_contact_mag) < 1e6 then 1.0 else 0.0);

  // ===== Latched Acceptance at 250 Hz =====
  when sample(0, 1.0 / 250.0) then
    bound_ok_latched = pre(bound_ok_latched) * bound_ok;
    contact_ok_latched = pre(contact_ok_latched) * (if F_contact_mag < F_contact_limit then 1.0 else 0.0);
    nan_ok_latched = pre(nan_ok_latched) * nan_ok;
    track_ok_latched = pre(track_ok_latched) * (if time < t_track_check then 1.0 else (if track_error < track_err_limit then 1.0 else 0.0));
    capture_latched = max(pre(capture_latched), captured);
    align_latched = max(pre(align_latched),
                        captured
                        * (if abs(y) < lat_align_limit then 1.0 else 0.0)
                        * (if abs(z) < lat_align_limit then 1.0 else 0.0)
                        * (if abs(psi) < yaw_align_limit then 1.0 else 0.0));
  end when;

  // ===== Overall Fail-Closed Acceptance =====
  acceptance = bound_ok_latched * contact_ok_latched * capture_latched
               * align_latched * track_ok_latched * nan_ok_latched;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "AUVDockE: AUV docking scenario with compliant capture. Plant: 85 kg capsule hull, 1.5 m long, 0.083 m3 displacement in seawater. Four bidirectional thrusters (2 surge, 2 heave), 121 N max per thruster. Sensors: sonar range, pressure depth, IMU yaw/rate, short-range optical pose. Dock: rigid station at x=8 m with compliant capture funnel (x=7..8 m). Cross-current: 168 N lateral force applied during middle third (t=5.33..10.67 s). Control: speed-scheduled pose control with contact transition. Far zone (>1 m): LOS guidance, v_max=1.5 m/s. Near zone (<=1 m): optical pose alignment, v_max=0.5 m/s. Contact: compliant spring-damper capture ring (k=5000 N/m, b=120 N.s/m). Run: 250 Hz (Interval=0.004 s), 16 s duration. Acceptance (fail-closed): actuator/speed bounds, lateral/yaw alignment, contact force < 500 N, capture achieved, tracking error < 0.09 m after 10.4 s, no NaN/Inf in any physical, control, or estimator value.")
  );
end AUVDockE;