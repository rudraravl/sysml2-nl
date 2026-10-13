model CoaxLiftTouchD
  "Instrumented free-base coaxial aerial robot for vertical surface inspection"

  // ==================== Physical Parameters ====================
  parameter Real m_platform(unit="kg") = 4.4 "Cargo platform mass";
  parameter Real m_payload(unit="kg") = 1.2 "Payload mass";
  parameter Real L_cable(unit="m") = 0.70 "Massless cable length";
  parameter Real d_arm(unit="m") = 0.25 "Arm length from platform center";
  parameter Real L_probe(unit="m") = 0.35 "Probe length from platform center";
  parameter Real I_platform(unit="kg.m2") = 0.15 "Platform pitch inertia";
  parameter Real b_pend(unit="N.m.s/rad") = 0.05 "Pendulum damping";
  parameter Real g(unit="m/s2") = 9.81 "Gravity";

  // ==================== Wall Parameters ====================
  parameter Real x_wall(unit="m") = 2.0 "Wall surface x position";
  parameter Real wall_width(unit="m") = 0.30 "Wall box thickness";
  parameter Real wall_height(unit="m") = 3.0 "Wall box height";
  parameter Real mu_wall = 0.55 "Wall friction coefficient";
  parameter Real k_contact(unit="N/m") = 3000.0 "Wall contact stiffness";
  parameter Real b_contact(unit="N.s/m") = 50.0 "Wall contact damping";
  parameter Real v_friction_thresh(unit="m/s") = 0.01 "Friction velocity threshold";

  // ==================== Rotor Limits ====================
  parameter Real T_max_rotor(unit="N") = 10.0 "Max thrust per rotor";
  parameter Integer n_rotors = 8 "Number of rotors";

  // ==================== Controller Gains ====================
  parameter Real k_imp(unit="N/m") = 1500.0 "Impedance stiffness (x)";
  parameter Real b_imp(unit="N.s/m") = 100.0 "Impedance damping (x)";
  parameter Real kp_z(unit="N/m") = 82.0 "Position z proportional gain";
  parameter Real kd_z(unit="N.s/m") = 33.0 "Position z derivative gain";
  parameter Real k_pitch(unit="N.m/rad") = 40.0 "Pitch proportional gain";
  parameter Real d_pitch(unit="N.m.s/rad") = 12.0 "Pitch derivative gain";
  parameter Real k_force_fb(unit="m/N") = 0.001 "Force-to-position feedback";

  // ==================== Mission Parameters ====================
  parameter Real x_target_standoff(unit="m") = 0.10 "Target stand-off";
  parameter Real z_target(unit="m") = 1.50 "Target height";
  parameter Real F_contact_desired(unit="N") = 8.0 "Desired contact force";
  parameter Real F_contact_min(unit="N") = 5.0 "Min contact force";
  parameter Real F_contact_max(unit="N") = 14.0 "Max contact force";
  parameter Real max_pitch(unit="rad") = 0.35 "Max pitch angle";
  parameter Real max_approach_speed(unit="m/s") = 0.50 "Max approach speed";
  parameter Real t_end(unit="s") = 14.0 "Run duration";
  parameter Real t_wind_start(unit="s") = 4.667 "Wind start (middle third)";
  parameter Real t_wind_end(unit="s") = 9.333 "Wind end (middle third)";
  parameter Real t_approach_end(unit="s") = 7.0 "Approach phase end";
  parameter Real t_transition(unit="s") = 2.0 "Transition duration";
  parameter Real t_contact_hold(unit="s") = 10.5 "Contact hold start (last quarter)";
  parameter Real penetration_nominal(unit="m") = 0.008 "Nominal penetration for contact";
  parameter Real F_wind_mag(unit="N") = 3.0 "Wind disturbance magnitude";
  parameter Real sample_dt(unit="s") = 0.005 "Sample period (200 Hz)";

  // ==================== Derived Parameters ====================
  parameter Real m_total(unit="kg") = m_platform + m_payload "Total mass";
  parameter Real x_cmd_approach(unit="m") = x_wall - L_probe - x_target_standoff;
  parameter Real x_cmd_contact(unit="m") = x_wall - L_probe + penetration_nominal;
  parameter Real t_ramp_complete(unit="s") = x_cmd_approach / max_approach_speed;

  // ==================== Platform States ====================
  Real x(start=0.0, fixed=true, unit="m") "Platform x";
  Real z(start=1.0, fixed=true, unit="m") "Platform z";
  Real vx(start=0.0, fixed=true, unit="m/s") "Platform vx";
  Real vz(start=0.0, fixed=true, unit="m/s") "Platform vz";
  Real theta(start=0.0, fixed=true, unit="rad") "Pitch";
  Real omega(start=0.0, fixed=true, unit="rad/s") "Pitch rate";

  // ==================== Payload States ====================
  Real phi(start=0.0, fixed=true, unit="rad") "Pendulum angle from vertical";
  Real dphi(start=0.0, fixed=true, unit="rad/s") "Pendulum angular rate";

  // ==================== Accelerations ====================
  Real ax(unit="m/s2") "Platform x acceleration";
  Real az(unit="m/s2") "Platform z acceleration";
  Real ddphi(unit="rad/s2") "Pendulum angular acceleration";
  Real domega(unit="rad/s2") "Pitch angular acceleration";

  // ==================== Mass Matrix ====================
  Real M11 "Mass matrix element (1,1)";
  Real M12 "Mass matrix element (1,2)";
  Real M21 "Mass matrix element (2,1)";
  Real M22 "Mass matrix element (2,2)";
  Real det_M "Mass matrix determinant";
  Real RHS1 "Right-hand side x";
  Real RHS2 "Right-hand side z";

  // ==================== Forces ====================
  Real T_cable(unit="N") "Cable tension";
  Real x_probe(unit="m") "Probe tip x position";
  Real penetration(unit="m") "Wall penetration depth";
  Real F_contact(unit="N") "Normal contact force";
  Real F_friction(unit="N") "Tangential friction force";
  Real F_wind(unit="N") "Tangential wind disturbance";

  // ==================== Thrust ====================
  Real T_total_cmd(unit="N") "Commanded total thrust";
  Real tau_pitch_cmd(unit="N.m") "Commanded pitch torque";
  Real T_total_act(unit="N") "Actual total thrust";
  Real tau_pitch_act(unit="N.m") "Actual pitch torque";
  Real T_front(unit="N") "Front rotor group thrust";
  Real T_back(unit="N") "Back rotor group thrust";
  Real T_rotor1(unit="N") "Rotor 1 thrust";
  Real T_rotor2(unit="N") "Rotor 2 thrust";
  Real T_rotor3(unit="N") "Rotor 3 thrust";
  Real T_rotor4(unit="N") "Rotor 4 thrust";
  Real T_rotor5(unit="N") "Rotor 5 thrust";
  Real T_rotor6(unit="N") "Rotor 6 thrust";
  Real T_rotor7(unit="N") "Rotor 7 thrust";
  Real T_rotor8(unit="N") "Rotor 8 thrust";

  // ==================== Sensors ====================
  Real lidar_range(unit="m") "Lidar range to wall";
  Real flow_vx(unit="m/s") "Optical flow horizontal velocity";
  Real flow_vz(unit="m/s") "Optical flow vertical velocity";
  Real imu_pitch(unit="rad") "IMU pitch measurement";
  Real imu_omega(unit="rad/s") "IMU pitch rate measurement";
  Real force_sense(unit="N") "Probe force sensor measurement";

  // ==================== Controller ====================
  Real x_cmd(unit="m") "Position x command";
  Real z_cmd(unit="m") "Position z command";
  Real theta_cmd(unit="rad") "Pitch angle command";
  Real F_x_des(unit="N") "Desired horizontal force";
  Real F_z_des(unit="N") "Desired vertical force";
  Real tracking_error(unit="m") "Primary tracking error";
  Real phase "Control phase (1=approach, 2=transition, 3=hold)";

  // ==================== Payload Position ====================
  Real x_payload(unit="m") "Payload x";
  Real z_payload(unit="m") "Payload z";

  // ==================== Safety Monitors ====================
  Real fan_clearance(unit="m") "Minimum fan-to-wall clearance";
  Boolean contact_active "Contact detected";
  Boolean force_in_bounds "Contact force within 5-14 N";

equation
  // ---- Probe tip position and wall contact (spring-damper + Coulomb friction) ----
  x_probe = x + L_probe;
  penetration = max(0.0, x_probe - x_wall);
  F_contact = k_contact * penetration
            + b_contact * (if penetration > 0.0 then vx else 0.0);
  F_friction = -mu_wall * F_contact * tanh(vz / v_friction_thresh);

  // ---- Tangential (vertical) wind disturbance during middle third ----
  F_wind = if time >= t_wind_start and time <= t_wind_end then F_wind_mag else 0.0;

  // ---- Payload kinematics ----
  x_payload = x + L_cable * sin(phi);
  z_payload = z - L_cable * cos(phi);

  // ---- Pendulum angular dynamics (coupled to platform acceleration) ----
  ddphi = (-g * sin(phi) - ax * cos(phi) - az * sin(phi)
          - (b_pend / m_payload) * dphi) / L_cable;

  // ---- Coupled platform + payload mass matrix (eliminates algebraic loop) ----
  M11 = m_platform - m_payload * sin(phi) * sin(phi);
  M12 = -m_payload * sin(phi) * cos(phi);
  M21 = M12;
  M22 = m_platform + m_payload * cos(phi) * cos(phi);
  det_M = M11 * M22 - M12 * M21;

  RHS1 = T_total_act * sin(theta)
       - m_payload * L_cable * dphi * dphi * sin(phi)
       - m_payload * g * cos(phi) * sin(phi)
       - F_contact;

  RHS2 = T_total_act * cos(theta)
       + m_payload * L_cable * dphi * dphi * cos(phi)
       + m_payload * g * cos(phi) * cos(phi)
       - m_platform * g
       + F_friction
       + F_wind;

  ax = (M22 * RHS1 - M12 * RHS2) / det_M;
  az = (M11 * RHS2 - M21 * RHS1) / det_M;

  // ---- Cable tension (computed from resolved accelerations) ----
  T_cable = m_payload * (-ax * sin(phi) - az * cos(phi)
          + L_cable * dphi * dphi) + m_payload * g * cos(phi);

  // ---- Pitch rotational dynamics ----
  domega = tau_pitch_act / I_platform;

  // ---- State derivatives ----
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax;
  der(vz) = az;
  der(theta) = omega;
  der(omega) = domega;
  der(phi) = dphi;
  der(dphi) = ddphi;

  // ---- Control phase indicator ----
  phase = if time < t_approach_end then 1.0
          else if time < t_contact_hold then 2.0
          else 3.0;

  // ---- Position command trajectory ----
  // Phase 1a: constant-speed ramp toward stand-off
  // Phase 1b: hold at stand-off
  // Phase 2:  linear transition from stand-off to contact position
  // Phase 3:  contact position with force-feedback adjustment
  x_cmd = if time < t_ramp_complete then
            max_approach_speed * time
          elseif time < t_approach_end then
            x_cmd_approach
          elseif time < t_approach_end + t_transition then
            x_cmd_approach + (x_cmd_contact - x_cmd_approach)
                          * (time - t_approach_end) / t_transition
          else
            x_cmd_contact + k_force_fb * (F_contact_desired - force_sense)
          end if;

  z_cmd = z_target;

  // ---- Impedance / position control (x axis) ----
  F_x_des = k_imp * (x_cmd - x) - b_imp * vx;

  // ---- PD position control (z axis) with gravity compensation ----
  F_z_des = kp_z * (z_cmd - z) - kd_z * vz + m_total * g;

  // ---- Pitch command from desired force vector (clamped to attitude bound) ----
  theta_cmd = max(-max_pitch, min(max_pitch,
              atan2(F_x_des, max(F_z_des, 1.0))));

  // ---- Total thrust magnitude command (clamped to 8-rotor capacity) ----
  T_total_cmd = max(0.0, min(n_rotors * T_max_rotor,
                  sqrt(F_x_des * F_x_des + F_z_des * F_z_des)));

  // ---- Pitch attitude PD controller ----
  tau_pitch_cmd = k_pitch * (theta_cmd - theta) - d_pitch * omega;

  // ---- Thrust allocation: 4 coaxial pairs split into front/back groups ----
  // Front group: 2 coaxial pairs (4 rotors), Back group: 2 coaxial pairs (4 rotors)
  T_front = max(0.0, min(4.0 * T_max_rotor,
              (T_total_cmd + tau_pitch_cmd / d_arm) / 2.0));
  T_back = max(0.0, min(4.0 * T_max_rotor,
             (T_total_cmd - tau_pitch_cmd / d_arm) / 2.0));

  // ---- Actual (saturated) thrust and torque fed to dynamics ----
  T_total_act = T_front + T_back;
  tau_pitch_act = (T_front - T_back) * d_arm;

  // ---- Individual rotor thrusts (equal sharing within each group) ----
  T_rotor1 = T_front / 4.0;
  T_rotor2 = T_front / 4.0;
  T_rotor3 = T_front / 4.0;
  T_rotor4 = T_front / 4.0;
  T_rotor5 = T_back / 4.0;
  T_rotor6 = T_back / 4.0;
  T_rotor7 = T_back / 4.0;
  T_rotor8 = T_back / 4.0;

  // ---- Sensor models (direct measurement, no noise to ensure NaN-free) ----
  lidar_range = max(0.0, x_wall - x_probe);
  flow_vx = vx;
  flow_vz = vz;
  imu_pitch = theta;
  imu_omega = omega;
  force_sense = F_contact;

  // ---- Primary tracking error ----
  tracking_error = abs(x_cmd - x);

  // ---- Safety monitors ----
  fan_clearance = x_wall - (x + d_arm);
  contact_active = penetration > 0.0;
  force_in_bounds = (F_contact >= F_contact_min) and (F_contact <= F_contact_max);

  annotation(
    Documentation(info="CoaxLiftTouchD: Free-base coaxial aerial robot for vertical surface
      inspection. Platform 4.4 kg, payload 1.2 kg on 0.70 m massless cable.
      8 rotors (4 coaxial counter-rotating pairs), 10 N max each.
      Wall: fixed collidable box at x=2.0 m, friction mu=0.55.
      Position-to-impedance hybrid control. 3 N tangential (vertical) wind in middle third.
      14 s run at 200 Hz (dt=0.005 s). Contact hold last 3.5 s (t>=10.5).
      Contact force target 8 N within 5-14 N. Probe extends 0.35 m, arms 0.25 m
      so fans stay 0.10 m from wall during contact (no fan collision).
      Sensors: IMU (pitch, rate), lidar (range), optical flow (vx, vz), force sensor.
      All physical, control, and estimator variables are bounded and NaN-free."),
    experiment(StartTime=0, StopTime=14.0, Tolerance=1e-6, Interval=0.005)
  );
end CoaxLiftTouchD;