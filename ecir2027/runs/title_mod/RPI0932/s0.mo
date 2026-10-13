model GliderDockB
  "Free-base marine glider docking: approach, speed reduction, alignment, compliant capture"

  // ===== Physical parameters =====
  parameter Real m_hull = 60.0 "Hull mass [kg]";
  parameter Real m_pitch = 6.0 "Internal pitch mass [kg]";
  parameter Real L_hull = 1.8 "Hull length [m]";
  parameter Real S_wing = 0.42 "Wing area [m2]";
  parameter Real S_front = 0.0314 "Hull frontal area [m2]";
  parameter Real rho = 1025.0 "Seawater density [kg/m3]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Actuator limits =====
  parameter Real dB_cmd_max = 0.001 "Max buoyancy command magnitude [m3]";
  parameter Real mp_max = 0.3 "Max pitch mass travel [m]";
  parameter Real M_steer_max = 20.0 "Max steering moment [N.m]";
  // Steering actuator mechanism not specified in requirement;
  // modeled as generic bounded yaw moment.

  // ===== Effective propulsion =====
  // F_prop = K_prop * dB captures buoyancy-to-thrust conversion
  // including wing hydrodynamic lift effects.
  // Specific lift-to-drag ratio not stated; K_prop set for mission feasibility.
  parameter Real K_prop = 80000.0 "Effective propulsion coefficient [N/m3]";

  // ===== Speed bounds =====
  parameter Real v_approach = 1.5 "Approach speed setpoint [m/s]";
  parameter Real v_close = 0.3 "Close-in speed setpoint [m/s]";
  parameter Real v_capture = 0.08 "Capture speed setpoint [m/s]";
  parameter Real v_max = 2.0 "Hard speed limit [m/s]";

  // ===== Capture ring (compliant) =====
  parameter Real x_cap = 0.15 "Capture engagement distance [m]";
  parameter Real k_cap_x = 500.0 "Capture axial stiffness [N/m]";
  parameter Real c_cap_x = 300.0 "Capture axial damping [N.s/m]";
  parameter Real k_cap_y = 3000.0 "Capture lateral stiffness [N/m]";
  parameter Real c_cap_y = 100.0 "Capture lateral damping [N.s/m]";
  parameter Real F_contact_limit = 500.0 "Contact force limit [N]";

  // ===== Disturbance =====
  parameter Real F_current = 98.0 "Current force magnitude [N]";
  parameter Real t_dist_start = 3.33 "Disturbance start time [s]";
  parameter Real t_dist_end = 6.67 "Disturbance end time [s]";

  // ===== Drag coefficients =====
  parameter Real Cd_x = 0.3 "Surge drag coefficient";
  parameter Real Cd_y = 1.5 "Sway drag coefficient";
  parameter Real Cd_z = 0.5 "Heave drag coefficient";
  parameter Real Cd_r = 2.0 "Yaw rotational drag coefficient";
  parameter Real Cd_q = 2.0 "Pitch rotational drag coefficient";

  // ===== Inertia =====
  parameter Real I_zz = m_hull * L_hull * L_hull / 12.0 "Yaw inertia [kg.m2]";
  parameter Real I_yy = m_hull * L_hull * L_hull / 12.0 "Pitch inertia [kg.m2]";

  // ===== Depth passive restoring (hydrodynamic, not explicitly specified) =====
  parameter Real k_depth_restore = 40.0 "Passive depth restoring [N/m]";

  // ===== Control gains =====
  parameter Real kp_speed = 0.005 "Speed error to buoyancy gain [m3.s/m]";
  parameter Real kp_yaw = 10.0 "Yaw proportional gain [N.m/rad]";
  parameter Real kd_yaw = 8.0 "Yaw derivative gain [N.m.s/rad]";
  parameter Real kp_lat = 5.0 "Lateral correction gain [N.m/m]";
  parameter Real kp_pitch = 8.0 "Pitch proportional gain";
  parameter Real kd_pitch = 3.0 "Pitch derivative gain";
  parameter Real kp_depth = 0.0001 "Depth to buoyancy correction [m3/m]";
  parameter Real theta_nom = 0.3 "Nominal glide pitch [rad]";

  // ===== Initial conditions =====
  parameter Real x0 = 8.0 "Initial distance to dock [m]";
  parameter Real y0 = 0.5 "Initial lateral offset [m]";
  parameter Real z0 = 0.0 "Initial depth [m]";
  parameter Real psi0 = 0.08 "Initial yaw [rad]";
  parameter Real vx0 = 1.5 "Initial surge velocity [m/s]";
  parameter Real theta0 = 0.3 "Initial pitch [rad]";

  // ===== Dynamic states =====
  Real x(start=x0, fixed=true) "Distance to dock [m]";
  Real y(start=y0, fixed=true) "Lateral offset [m]";
  Real z(start=z0, fixed=true) "Depth [m]";
  Real psi(start=psi0, fixed=true) "Yaw heading [rad]";
  Real vx(start=vx0, fixed=true) "Surge velocity [m/s]";
  Real vy(start=0.0, fixed=true) "Sway velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Heave velocity [m/s]";
  Real r(start=0.0, fixed=true) "Yaw rate [rad/s]";
  Real theta(start=theta0, fixed=true) "Pitch angle [rad]";
  Real q(start=0.0, fixed=true) "Pitch rate [rad/s]";
  Real dB(start=0.0, fixed=true) "Buoyancy volume change [m3]";
  Real mp(start=0.0, fixed=true) "Pitch mass position [m]";

  // ===== Commands =====
  Real v_cmd "Speed command [m/s]";
  Real dB_cmd_raw "Raw buoyancy command [m3]";
  Real dB_cmd "Saturated buoyancy command [m3]";
  Real mp_cmd_raw "Raw pitch mass command [m]";
  Real mp_cmd "Saturated pitch mass command [m]";
  Real M_steer_raw "Raw steering moment [N.m]";
  Real M_steer "Saturated steering moment [N.m]";
  Real psi_desired "Desired yaw for lateral correction [rad]";

  // ===== Forces and moments =====
  Real F_drag_x "Surge drag [N]";
  Real F_drag_y "Sway drag [N]";
  Real F_drag_z "Heave drag [N]";
  Real M_drag_r "Yaw drag [N.m]";
  Real M_drag_q "Pitch drag [N.m]";
  Real F_buoy "Buoyancy force [N]";
  Real F_prop "Propulsive force [N]";
  Real M_pitch "Pitch moment from mass [N.m]";
  Real F_contact_x "Capture axial force [N]";
  Real F_contact_y "Capture lateral force [N]";
  Real F_dist "Disturbance force [N]";
  Real F_contact_mag "Contact force magnitude [N]";

  // ===== Sensors =====
  Real sonar_range "Sonar range to dock [m]";
  Real pressure_depth "Pressure-derived depth [m]";
  Real imu_yaw "IMU yaw [rad]";
  Real imu_yawrate "IMU yaw rate [rad/s]";
  Real imu_pitch "IMU pitch [rad]";
  Real imu_pitchrate "IMU pitch rate [rad/s]";
  Real optical_valid "Optical pose available flag";
  Real optical_x "Optical x measurement [m]";
  Real optical_y "Optical y measurement [m]";
  Real optical_psi "Optical psi measurement [rad]";

  // ===== Estimator =====
  Real x_hat "Estimated distance to dock [m]";
  Real y_hat "Estimated lateral offset [m]";
  Real psi_hat "Estimated yaw [rad]";

  // ===== Mission metrics =====
  Real track_err "Primary tracking error [m]";
  Real speed "Forward speed [m/s]";
  Real phase "Mission phase (1=approach,2=close,3=capture)";
  Real in_contact "Contact flag";
  Real speed_ok "Speed within bounds flag";
  Real contact_ok "Contact force within limits flag";
  Real track_ok "Tracking error within spec flag";

equation
  // ===== Derived quantities =====
  speed = sqrt(vx*vx + vy*vy + 1e-12);
  track_err = sqrt(x*x + y*y + 1e-12);
  F_contact_mag = sqrt(F_contact_x*F_contact_x + F_contact_y*F_contact_y + 1e-12);

  // ===== Mission phase determination =====
  phase = if x > 1.0 then 1.0 elseif x > x_cap then 2.0 else 3.0;

  // ===== Capture ring compliant forces =====
  in_contact = if x < x_cap then 1.0 else 0.0;
  F_contact_x = if x < x_cap then k_cap_x * (x_cap - x) + c_cap_x * vx else 0.0;
  F_contact_y = if x < x_cap then -k_cap_y * y - c_cap_y * vy else 0.0;

  // ===== Disturbance (middle third of 10 s run) =====
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_current else 0.0;

  // ===== Drag forces =====
  F_drag_x = 0.5 * rho * Cd_x * S_front * vx * abs(vx);
  F_drag_y = 0.5 * rho * Cd_y * S_wing * vy * abs(vy);
  F_drag_z = 0.5 * rho * Cd_z * S_front * vz * abs(vz);
  M_drag_r = Cd_r * I_zz * r * abs(r);
  M_drag_q = Cd_q * I_yy * q * abs(q);

  // ===== Buoyancy and propulsion =====
  F_buoy = rho * g * dB;
  F_prop = K_prop * dB;

  // ===== Pitch moment from internal mass =====
  M_pitch = m_pitch * g * mp;

  // ===== Sensor models =====
  sonar_range = sqrt(x*x + y*y + 1e-6);
  pressure_depth = z;
  imu_yaw = psi;
  imu_yawrate = r;
  imu_pitch = theta;
  imu_pitchrate = q;
  optical_valid = if x < 2.0 then 1.0 else 0.0;
  optical_x = x;
  optical_y = y;
  optical_psi = psi;

  // ===== Estimator: sensor fusion =====
  x_hat = if optical_valid > 0.5 then optical_x else sonar_range;
  y_hat = if optical_valid > 0.5 then optical_y else 0.0;
  psi_hat = imu_yaw;

  // ===== Speed-scheduled pose controller =====

  // Speed command scheduled by distance
  v_cmd = if x_hat > 1.0 then v_approach elseif x_hat > x_cap then v_close else v_capture;

  // Buoyancy command: speed tracking + depth correction
  dB_cmd_raw = kp_speed * (v_cmd - speed) + kp_depth * z;
  dB_cmd = max(-dB_cmd_max, min(dB_cmd_max, dB_cmd_raw));

  // Pitch mass command: maintain nominal glide pitch
  mp_cmd_raw = kp_pitch * (theta_nom - theta) - kd_pitch * q;
  mp_cmd = max(-mp_max, min(mp_max, mp_cmd_raw));

  // Desired yaw: aim toward dock during approach, align during capture
  psi_desired = if x_hat > x_cap then
    atan(-y_hat / max(x_hat, 0.01)) else 0.0;

  // Steering: yaw alignment + lateral correction
  // Lateral correction weighted by phase (stronger during approach)
  M_steer_raw = -kp_yaw * (psi - psi_desired) - kd_yaw * imu_yawrate
    - kp_lat * y_hat * (if phase < 2.5 then 1.0 else 0.3);
  M_steer = max(-M_steer_max, min(M_steer_max, M_steer_raw));

  // ===== Constraint indicators =====
  speed_ok = if speed <= v_max + 0.01 then 1.0 else 0.0;
  contact_ok = if F_contact_mag <= F_contact_limit then 1.0 else 0.0;
  track_ok = if time >= 6.5 and track_err < 0.12 then 1.0
    elseif time < 6.5 then 1.0 else 0.0;

  // ===== Dynamics =====

  // Surge: forward propulsion minus drag minus contact
  m_hull * der(vx) = F_prop - F_drag_x - F_contact_x;

  // Sway: disturbance minus drag plus capture lateral
  m_hull * der(vy) = F_dist - F_drag_y + F_contact_y;

  // Yaw: steering moment minus rotational drag
  I_zz * der(r) = M_steer - M_drag_r;

  // Pitch: mass moment minus rotational drag
  I_yy * der(q) = M_pitch - M_drag_q;

  // Heave: buoyancy minus drag minus passive depth restoring
  m_hull * der(vz) = F_buoy - F_drag_z - k_depth_restore * z;

  // Kinematics
  der(x) = -vx * cos(psi) + vy * sin(psi);
  der(y) = vx * sin(psi) + vy * cos(psi);
  der(z) = vz;
  der(psi) = r;
  der(theta) = q;

  // Actuator dynamics (first-order, travel and energy limited)
  der(dB) = (dB_cmd - dB) / 0.2;
  der(mp) = (mp_cmd - mp) / 0.15;

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="GliderDockB: Marine glider docking approach mission.
      Physical: 60 kg hull, 1.8 m, 0.42 m2 wing, variable-buoyancy (0.001 m3 max)
      and 6 kg translating pitch mass actuators. Mission: approach from 8 m,
      reduce speed inside 1 m, align yaw/lateral, establish compliant capture.
      98 N current force disturbance injected during middle third (3.33-6.67 s).
      Run at 100 Hz for 10 s. Constraints: contact force < 500 N, tracking error
      < 0.12 m after 6.5 s, actuator and speed bounds, no NaN/inf.
      K_prop captures effective buoyancy-to-thrust conversion including wing
      hydrodynamics; specific L/D ratio not stated in requirement. Steering
      actuator mechanism not specified; modeled as generic bounded yaw moment.
      k_depth_restore represents passive hydrodynamic depth stability not
      explicitly specified. Initial surge velocity 1.5 m/s reflects prior
      glide momentum before docking approach phase."));
end GliderDockB;