model TiltWingDeliverC
  "Free-base tilt-wing aerial robot TiltWingDeliverC: input-shaped position control
   with cable-swing damping, suspended payload, 5 m horizontal translation, 0.8 m
   target-zone placement, gust during middle third, IMU/GPS/cable sensing."

  // ===== Parameters specified in requirement =====
  parameter Real m_fuselage(unit="kg") = 6.2 "capsule fuselage mass";
  parameter Real rotor_arm(unit="m") = 0.62 "rotor distance from center";
  parameter Real wing_span(unit="m") = 1.8 "wing span";
  parameter Real F_max(unit="N") = 47.8 "maximum command magnitude per rotor";
  parameter Real tilt_min(unit="rad") = 0.0 "rotor tilt joint lower bound";
  parameter Real tilt_max(unit="rad") = 1.57 "rotor tilt joint upper bound";
  parameter Real F_gust(unit="N") = 7.2 "gust disturbance force";
  parameter Real swing_limit(unit="rad") = 0.45 "max cable swing";
  parameter Real target_radius(unit="m") = 0.8 "target zone radius";
  parameter Real track_err_limit(unit="m") = 0.315 "tracking error limit after 7.8 s";
  parameter Real t_sim(unit="s") = 12.0 "simulation duration";
  parameter Real t_track_check(unit="s") = 7.8 "tracking error check time";
  parameter Real f_ctrl(unit="Hz") = 125.0 "control and sensor sampling rate";
  parameter Real g_accel(unit="m/s2") = 9.81 "gravitational acceleration";

  // ===== Assumed parameters (not specified in requirement) =====
  parameter Real m_payload(unit="kg") = 1.0 "payload mass — assumed";
  parameter Real cable_len(unit="m") = 1.0 "cable length — assumed";
  parameter Real chord_assumed(unit="m") = 0.12 "wing chord — assumed";
  parameter Real Cd_drag = 0.04 "drag coefficient — assumed";
  parameter Real rho_air(unit="kg/m3") = 1.225 "air density — assumed";
  parameter Real I_fus(unit="kg.m2") = 0.5 "fuselage pitch inertia — assumed";
  parameter Real tau_tilt(unit="s") = 0.15 "tilt actuator time constant — assumed";
  parameter Real c_cable(unit="1/s") = 0.3 "intrinsic cable damping — assumed";
  parameter Real z_start(unit="m") = 1.5 "initial hover altitude — assumed";
  parameter Real z_cruise(unit="m") = 3.0 "cruise altitude — assumed";
  parameter Real z_lower(unit="m") = 1.1 "payload lowering altitude — assumed";

  // ===== Control gains (assumed) =====
  parameter Real Kp_x(unit="1/s2") = 6.0 "horizontal position gain — assumed";
  parameter Real Kd_x(unit="1/s") = 4.0 "horizontal velocity gain — assumed";
  parameter Real Kp_z(unit="1/s2") = 6.0 "vertical position gain — assumed";
  parameter Real Kd_z(unit="1/s") = 4.0 "vertical velocity gain — assumed";
  parameter Real Kp_theta(unit="1/s2") = 20.0 "pitch angle gain — assumed";
  parameter Real Kd_theta(unit="1/s") = 6.0 "pitch rate gain — assumed";
  parameter Real K_swing(unit="1/s") = 1.5 "cable-swing damping gain — assumed";

  // ===== Trajectory timing =====
  parameter Real t_lift_start(unit="s") = 0.5;
  parameter Real t_lift_end(unit="s") = 3.0;
  parameter Real t_trans_start(unit="s") = 3.5;
  parameter Real t_trans_end(unit="s") = 7.5;
  parameter Real t_lower_start(unit="s") = 8.5;
  parameter Real t_lower_end(unit="s") = 11.5;
  parameter Real x_goal(unit="m") = 5.0 "horizontal translation distance";

  // ===== Continuous states =====
  Real x(start=0.0, fixed=true) "fuselage horizontal position [m]";
  Real z(start=1.5, fixed=true) "fuselage vertical position [m]";
  Real vx(start=0.0, fixed=true) "fuselage horizontal velocity [m/s]";
  Real vz(start=0.0, fixed=true) "fuselage vertical velocity [m/s]";
  Real theta(start=0.0, fixed=true) "fuselage pitch angle [rad]";
  Real q_pitch(start=0.0, fixed=true) "fuselage pitch rate [rad/s]";
  Real tilt(start=0.0, fixed=true) "actual rotor tilt angle [rad]";
  Real phi(start=0.0, fixed=true) "cable angle from vertical [rad]";
  Real phi_dot(start=0.0, fixed=true) "cable angular rate [rad/s]";

  // ===== Discrete controller outputs (sampled at 125 Hz) =====
  discrete Real T_mag_d(start=70.6) "total thrust magnitude command [N]";
  discrete Real tilt_cmd_d(start=0.0) "commanded rotor tilt [rad]";
  discrete Real theta_cmd_d(start=0.0) "commanded fuselage pitch [rad]";
  discrete Real pitch_diff_d(start=0.0) "differential thrust (F_R - F_L) command [N]";

  // ===== Actual rotor thrust (saturated) =====
  Real F_L "left rotor thrust [N]";
  Real F_R "right rotor thrust [N]";

  // ===== Cable and payload =====
  Real tension "cable tension [N]";
  Real x_payload "payload horizontal position [m]";
  Real z_payload "payload vertical position [m]";

  // ===== Reference trajectory =====
  Real x_ref "horizontal position reference [m]";
  Real z_ref "vertical position reference [m]";
  Real vx_ref "horizontal velocity reference [m/s]";
  Real vz_ref "vertical velocity reference [m/s]";

  // ===== Aerodynamics =====
  Real drag_area "drag reference area [m2]";
  Real v_rel_x "relative horizontal velocity [m/s]";
  Real v_rel_z "relative vertical velocity [m/s]";
  Real speed_rel "relative speed [m/s]";
  Real F_drag_x "horizontal aerodynamic drag [N]";
  Real F_drag_z "vertical aerodynamic drag [N]";

  // ===== Gust =====
  Real F_gust_applied "applied lateral gust force [N]";

  // ===== Fuselage accelerations =====
  Real ax_fus "fuselage horizontal acceleration [m/s2]";
  Real az_fus "fuselage vertical acceleration [m/s2]";

  // ===== Sensors =====
  Real gps_x "GPS horizontal position [m]";
  Real gps_z "GPS vertical position [m]";
  Real gps_vx "GPS horizontal velocity [m/s]";
  Real gps_vz "GPS vertical velocity [m/s]";
  Real imu_ax "IMU horizontal acceleration [m/s2]";
  Real imu_az "IMU vertical acceleration [m/s2]";
  Real imu_theta "IMU pitch angle [rad]";
  Real imu_q "IMU pitch rate [rad/s]";
  Real sensor_phi "cable angle sensor [rad]";
  Real sensor_phi_dot "cable angular rate sensor [rad/s]";
  Real sensor_tension "cable tension sensor [N]";

  // ===== Performance monitors =====
  Real m_total "total mass (fuselage + payload) [kg]";
  Real track_err "primary tracking error [m]";
  Real placement_err "payload distance from target center [m]";
  Real abs_swing "absolute cable swing [rad]";

  // ===== Requirement compliance monitors =====
  Boolean thrust_ok "thrust within [0, F_max]";
  Boolean tension_ok "tension non-negative";
  Boolean swing_ok "cable swing below 0.45 rad";
  Boolean placement_ok "payload within target zone";
  Boolean no_ground_strike "payload above ground";
  Boolean track_ok "tracking error below 0.315 m after 7.8 s";

  annotation (
    experiment(StartTime=0, StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="Free-base tilt-wing aerial robot with cable-suspended payload.
      Input-shaped position control with cable-swing damping.
      Lift, translate 5 m, lower into 0.8 m target zone.
      7.2 N gust during middle third. 125 Hz control rate. 12 s duration.")
  );

protected
  function clamp01 "Clamp to [0,1]"
    input Real x;
    output Real y;
  algorithm
    y := if x <= 0.0 then 0.0 elseif x >= 1.0 then 1.0 else x;
  end clamp01;

  function smoothstep_f "Cubic smoothstep 3s^2 - 2s^3"
    input Real s;
    output Real y;
  algorithm
    y := if s <= 0.0 then 0.0 elseif s >= 1.0 then 1.0 else 3.0*s*s - 2.0*s*s*s;
  end smoothstep_f;

  function smoothstep_dot_f "Derivative of smoothstep: 6s(1-s)"
    input Real s;
    output Real y;
  algorithm
    y := if s <= 0.0 then 0.0 elseif s >= 1.0 then 0.0 else 6.0*s*(1.0 - s);
  end smoothstep_dot_f;

  function clamp_val "Clamp x to [lo, hi]"
    input Real lo;
    input Real hi;
    input Real x;
    output Real y;
  algorithm
    y := if x < lo then lo elseif x > hi then hi else x;
  end clamp_val;

  function ctrl_step
    "Sampled position controller with cable-swing damping and tilt/pitch allocation"
    input Real x_ref_in, z_ref_in, vx_ref_in, vz_ref_in;
    input Real gps_x_in, gps_z_in, gps_vx_in, gps_vz_in;
    input Real imu_theta_in, imu_q_in;
    input Real sensor_phi_dot_in;
    input Real m_total_in, g_in;
    input Real Kp_x_in, Kd_x_in, Kp_z_in, Kd_z_in;
    input Real Kp_theta_in, Kd_theta_in, K_swing_in;
    input Real rotor_arm_in, tilt_min_in, tilt_max_in;
    output Real T_mag_out, tilt_cmd_out, theta_cmd_out, pitch_diff_out;
  protected
    Real ex, ez, evx, evz;
    Real Fx_des, Fz_des, alpha_des, M_pitch_des;
  algorithm
    ex := x_ref_in - gps_x_in;
    ez := z_ref_in - gps_z_in;
    evx := vx_ref_in - gps_vx_in;
    evz := vz_ref_in - gps_vz_in;
    Fx_des := m_total_in*(Kp_x_in*ex + Kd_x_in*evx - K_swing_in*sensor_phi_dot_in);
    Fz_des := m_total_in*g_in + m_total_in*(Kp_z_in*ez + Kd_z_in*evz);
    T_mag_out := sqrt(Fx_des*Fx_des + Fz_des*Fz_des);
    alpha_des := atan(Fx_des / (abs(Fz_des) + 1.0e-6));
    if Fz_des < 0.0 then
      alpha_des := if Fx_des >= 0.0 then 1.5707963 else -1.5707963;
    end if;
    tilt_cmd_out := if alpha_des < tilt_min_in then tilt_min_in
                   elseif alpha_des > tilt_max_in then tilt_max_in
                   else alpha_des;
    theta_cmd_out := tilt_cmd_out - alpha_des;
    M_pitch_des := Kp_theta_in*(theta_cmd_out - imu_theta_in) - Kd_theta_in*imu_q_in;
    pitch_diff_out := M_pitch_des / (rotor_arm_in*cos(tilt_cmd_out) + 1.0e-3);
  end ctrl_step;

equation
  m_total = m_fuselage + m_payload;
  drag_area = wing_span * chord_assumed;

  // ===== Input-shaped reference trajectory =====
  z_ref = z_start
        + (z_cruise - z_start)*smoothstep_f(clamp01((time - t_lift_start)/(t_lift_end - t_lift_start)))
        - (z_cruise - z_lower)*smoothstep_f(clamp01((time - t_lower_start)/(t_lower_end - t_lower_start)));
  x_ref = x_goal * smoothstep_f(clamp01((time - t_trans_start)/(t_trans_end - t_trans_start)));
  vz_ref = (z_cruise - z_start)*smoothstep_dot_f(clamp01((time - t_lift_start)/(t_lift_end - t_lift_start)))/(t_lift_end - t_lift_start)
         - (z_cruise - z_lower)*smoothstep_dot_f(clamp01((time - t_lower_start)/(t_lower_end - t_lower_start)))/(t_lower_end - t_lower_start);
  vx_ref = x_goal*smoothstep_dot_f(clamp01((time - t_trans_start)/(t_trans_end - t_trans_start)))/(t_trans_end - t_trans_start);

  // ===== Gust disturbance (middle third of simulation) =====
  F_gust_applied = if (time >= t_sim/3.0 and time <= 2.0*t_sim/3.0) then F_gust else 0.0;

  // ===== Aerodynamic drag =====
  v_rel_x = vx;
  v_rel_z = vz;
  speed_rel = sqrt(v_rel_x*v_rel_x + v_rel_z*v_rel_z + 1.0e-6);
  F_drag_x = -0.5*rho_air*Cd_drag*drag_area*speed_rel*v_rel_x;
  F_drag_z = -0.5*rho_air*Cd_drag*drag_area*speed_rel*v_rel_z;

  // ===== Cable tension (radial force balance, clamped non-negative) =====
  tension = if m_payload*(cable_len*phi_dot*phi_dot + g_accel*cos(phi)) > 0.0
            then m_payload*(cable_len*phi_dot*phi_dot + g_accel*cos(phi))
            else 0.0;

  // ===== Fuselage force balance =====
  ax_fus = ((F_L + F_R)*sin(tilt - theta) + F_drag_x + F_gust_applied + tension*sin(phi)) / m_fuselage;
  az_fus = ((F_L + F_R)*cos(tilt - theta) + F_drag_z - m_fuselage*g_accel - tension*cos(phi)) / m_fuselage;

  // ===== Fuselage translational dynamics =====
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax_fus;
  der(vz) = az_fus;

  // ===== Fuselage pitch dynamics =====
  der(theta) = q_pitch;
  I_fus*der(q_pitch) = rotor_arm*cos(tilt)*(F_R - F_L);

  // ===== Rotor tilt actuator (first-order) =====
  der(tilt) = (tilt_cmd_d - tilt) / tau_tilt;

  // ===== Pendulum (cable + payload) dynamics =====
  der(phi) = phi_dot;
  der(phi_dot) = -(g_accel + az_fus)/cable_len*sin(phi) - ax_fus/cable_len*cos(phi) - c_cable*phi_dot;

  // ===== Payload position =====
  x_payload = x + cable_len*sin(phi);
  z_payload = z - cable_len*cos(phi);

  // ===== Thrust saturation (per-rotor bounds [0, F_max]) =====
  F_L = clamp_val(0.0, F_max, T_mag_d/2.0 - pitch_diff_d/2.0);
  F_R = clamp_val(0.0, F_max, T_mag_d/2.0 + pitch_diff_d/2.0);

  // ===== Sensors (ideal: directly measure physical states) =====
  gps_x = x;
  gps_z = z;
  gps_vx = vx;
  gps_vz = vz;
  imu_ax = ax_fus;
  imu_az = az_fus;
  imu_theta = theta;
  imu_q = q_pitch;
  sensor_phi = phi;
  sensor_phi_dot = phi_dot;
  sensor_tension = tension;

  // ===== Performance monitors =====
  track_err = sqrt((x - x_ref)*(x - x_ref) + (z - z_ref)*(z - z_ref) + 1.0e-12);
  placement_err = sqrt((x_payload - x_goal)*(x_payload - x_goal) + z_payload*z_payload + 1.0e-12);
  abs_swing = abs(phi);

  // ===== Requirement compliance =====
  thrust_ok = (F_L >= 0.0 and F_L <= F_max and F_R >= 0.0 and F_R <= F_max);
  tension_ok = (tension >= 0.0);
  swing_ok = (abs_swing < swing_limit);
  placement_ok = (placement_err <= target_radius);
  no_ground_strike = (z_payload > 0.0);
  track_ok = (time < t_track_check) or (track_err < track_err_limit);

  // ===== Safety assertions =====
  assert(F_L >= -1.0e-6 and F_L <= F_max + 1.0e-6, "Thrust F_L out of bounds");
  assert(F_R >= -1.0e-6 and F_R <= F_max + 1.0e-6, "Thrust F_R out of bounds");
  assert(tension >= -1.0e-6, "Cable tension negative");
  assert(z_payload > 0.0, "Ground strike: payload below ground plane");
  assert(abs_swing < swing_limit, "Cable swing exceeds 0.45 rad limit");
  assert(track_ok, "Primary tracking error exceeds 0.315 m after 7.8 s");
  assert(abs(x) < 1.0e10, "NaN or Inf detected in x");
  assert(abs(z) < 1.0e10, "NaN or Inf detected in z");
  assert(abs(phi) < 1.0e10, "NaN or Inf detected in phi");
  assert(abs(F_L) < 1.0e10, "NaN or Inf detected in F_L");
  assert(abs(F_R) < 1.0e10, "NaN or Inf detected in F_R");
  assert(abs(tension) < 1.0e10, "NaN or Inf detected in tension");

algorithm
  when sample(0.0, 1.0/f_ctrl) then
    (T_mag_d, tilt_cmd_d, theta_cmd_d, pitch_diff_d) := ctrl_step(
      x_ref, z_ref, vx_ref, vz_ref,
      gps_x, gps_z, gps_vx, gps_vz,
      imu_theta, imu_q,
      sensor_phi_dot,
      m_total, g_accel,
      Kp_x, Kd_x, Kp_z, Kd_z,
      Kp_theta, Kd_theta, K_swing,
      rotor_arm, tilt_min, tilt_max
    );
  end when;

end TiltWingDeliverC;