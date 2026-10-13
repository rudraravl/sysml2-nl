model TriTugClimbE
  "Floating-base mobile robot: ascend 12 deg ramp, traverse 2 m plateau, stop before descending edge";

  // ===== Physical constants =====
  constant Real g = 9.81 "Gravitational acceleration [m/s2]";
  constant Real pi_c = 3.14159265358979;

  // ===== Mass parameters =====
  parameter Real m_chassis = 38.0 "Chassis mass [kg]";
  parameter Real m_payload = 20.0 "Payload mass [kg]";
  parameter Real m_total = m_chassis + m_payload "Total mass [kg]";

  // ===== Geometry =====
  parameter Real r_wheel = 0.15 "Front wheel radius [m]";
  parameter Real steer_max = 0.60 "Steering travel [rad]";
  parameter Real tau_max = 37.4 "Actuator effort limit [N.m]";
  parameter Real mu = 0.76 "Friction coefficient";

  // ===== Structural geometry =====
  parameter Real L_wb = 0.60 "Wheelbase [m]";
  parameter Real h_cg = 0.20 "CG height above ground [m]";
  parameter Real w_track = 0.40 "Track width [m]";
  parameter Real b_cg = 0.30 "CG distance from rear axle [m]";

  // ===== Terrain =====
  parameter Real ramp_angle_deg = 12.0 "Ramp angle [deg]";
  parameter Real ramp_angle = ramp_angle_deg * pi_c / 180.0 "Ramp angle [rad]";
  parameter Real ramp_start_x = 1.0 "Ramp start position [m]";
  parameter Real ramp_length = 3.0 "Ramp horizontal length [m]";
  parameter Real plateau_length = 2.0 "Plateau length [m]";
  parameter Real ramp_end_x = ramp_start_x + ramp_length "Ramp end x [m]";
  parameter Real plateau_end_x = ramp_end_x + plateau_length "Plateau end x [m]";
  parameter Real ridge_height = 0.05 "Surface ridge height [m]";
  parameter Real ridge1_x = ramp_end_x + 0.5 "First ridge position [m]";
  parameter Real ridge2_x = ramp_end_x + 1.5 "Second ridge position [m]";

  // ===== Inertias =====
  parameter Real J_eff_wheel = 1.0 "Effective driveline inertia [kg.m2]";
  parameter Real J_pitch = m_total * (h_cg * h_cg / 3 + L_wb * L_wb / 12) "Pitch inertia [kg.m2]";
  parameter Real J_roll = m_total * (h_cg * h_cg + w_track * w_track / 12) "Roll inertia [kg.m2]";
  parameter Real k_pitch = 500.0 "Pitch stiffness [N.m/rad]";
  parameter Real c_pitch = 40.0 "Pitch damping [N.m.s/rad]";
  parameter Real k_roll = 600.0 "Roll stiffness [N.m/rad]";
  parameter Real c_roll = 30.0 "Roll damping [N.m.s/rad]";

  // ===== Tire slip model =====
  parameter Real k_slip = 0.70 "Slip gain";
  parameter Real T_slip = 0.01 "Slip dynamics time constant [s]";

  // ===== Control parameters =====
  parameter Real T_sample = 1.0 / 250.0 "Control sample period [s]";
  parameter Real Kp_speed = 12.0 "Speed proportional gain";
  parameter Real K_steer = 20.0 "Steering proportional gain";
  parameter Real v_ref_flat = 0.80 "Reference speed on flat [m/s]";
  parameter Real v_ref_ramp = 0.60 "Reference speed on ramp [m/s]";
  parameter Real v_ref_plateau = 0.35 "Reference speed on plateau [m/s]";
  parameter Real stop_margin = 0.35 "Stopping margin from edge [m]";
  parameter Real slip_thresh = 0.25 "Slip threshold for traction reduction";
  parameter Real slip_limit = 0.35 "Slip limit (acceptance)";
  parameter Real tau_filt_tc = 0.05 "Torque filter time constant [s]";
  parameter Real Crr = 0.02 "Rolling resistance coefficient";

  // ===== Disturbance =====
  parameter Real F_disturb = 180.0 "Payload disturbance force [N]";
  parameter Real t_dist_start = 16.0 / 3.0 "Disturbance start [s]";
  parameter Real t_dist_end = 32.0 / 3.0 "Disturbance end [s]";

  // ===== Dynamic states =====
  Real x(start = 0.0, fixed = true) "Longitudinal position [m]";
  Real v(start = 0.0, fixed = true) "Longitudinal velocity [m/s]";
  Real slip_ratio(start = 0.0, fixed = true) "Wheel slip ratio [-]";
  Real theta_pitch(start = 0.0, fixed = true) "Pitch angle [rad]";
  Real omega_pitch(start = 0.0, fixed = true) "Pitch angular velocity [rad/s]";
  Real phi_roll(start = 0.0, fixed = true) "Roll angle [rad]";
  Real omega_roll(start = 0.0, fixed = true) "Roll angular velocity [rad/s]";
  Real delta_steer(start = 0.0, fixed = true) "Steering angle [rad]";
  Real delta_steer_rate(start = 0.0, fixed = true) "Steering rate [rad/s]";
  Real tau_traction_filt(start = 0.0, fixed = true) "Filtered traction torque [N.m]";

  // ===== Discrete control variables =====
  discrete Real v_ref(start = 0.0) "Reference speed [m/s]";
  discrete Real tau_traction_cmd(start = 0.0) "Traction torque command [N.m]";
  discrete Real tau_steer_cmd(start = 0.0) "Steering torque command [N.m]";
  discrete Real tracking_error(start = 0.0) "Speed tracking error [m/s]";

  // ===== Sensed variables =====
  Real v_meas "Measured speed [m/s]";
  Real theta_meas "Measured pitch angle [rad]";
  Real phi_meas "Measured roll angle [rad]";
  Real d_edge "Forward edge distance [m]";

  // ===== Algebraic variables =====
  Real terrain_height "Terrain height at x [m]";
  Real terrain_slope "Terrain slope at x [rad]";
  Real ridge_pitch "Ridge-induced pitch disturbance [rad]";
  Real F_traction "Traction force at contact [N]";
  Real F_normal_front "Front wheel normal force [N]";
  Real F_gravity_long "Gravity longitudinal component [N]";
  Real F_roll_resist "Rolling resistance [N]";
  Real F_disturb_eff "Effective disturbance force [N]";
  Real omega_wheel "Front wheel angular velocity [rad/s]";
  Real tau_traction_eff "Effective traction torque [N.m]";
  Real tau_steer_eff "Effective steering torque [N.m]";
  Real tau_excess "Excess torque beyond friction limit [N.m]";
  Real slip_target "Steady-state slip target [-]";
  Real abs_slip "Absolute slip ratio [-]";
  Real tau_raw "Unsaturated traction torque [N.m]";
  Real slip_reduction "Slip reduction factor [-]";
  Real tanh_v "Smooth sign of velocity [-]";
  Real exp_ridge1 "Gaussian for ridge 1 [-]";
  Real exp_ridge2 "Gaussian for ridge 2 [-]";

  // ===== Acceptance flags =====
  Boolean actuator_ok "Actuator limits satisfied";
  Boolean slip_ok "Slip ratio below 0.35";
  Boolean attitude_ok "Roll and pitch below 0.40 rad";
  Boolean stopping_ok "Stopping margin and position satisfied";
  Boolean tracking_ok "Tracking error below 0.162 m/s after 10.4 s";
  Boolean no_nan_ok "No NaN or infinite values detected";
  Boolean all_acceptance_ok "All acceptance criteria satisfied (fail-closed)";

equation

  // ===== Terrain profile =====
  if x < ramp_start_x then
    terrain_height = 0.0;
    terrain_slope = 0.0;
  elseif x < ramp_end_x then
    terrain_height = (x - ramp_start_x) * sin(ramp_angle);
    terrain_slope = ramp_angle;
  else
    terrain_height = ramp_length * sin(ramp_angle);
    terrain_slope = 0.0;
  end if;

  // ===== Ridge pitch disturbance on plateau =====
  exp_ridge1 = Modelica.Math.exp(-((x - ridge1_x) * (x - ridge1_x)) / 0.02);
  exp_ridge2 = Modelica.Math.exp(-((x - ridge2_x) * (x - ridge2_x)) / 0.02);
  ridge_pitch = (ridge_height / L_wb) * (exp_ridge1 + exp_ridge2);

  // ===== Disturbance force =====
  if time >= t_dist_start and time <= t_dist_end then
    F_disturb_eff = F_disturb;
  else
    F_disturb_eff = 0.0;
  end if;

  // ===== Smooth velocity sign =====
  tanh_v = Modelica.Math.tanh(v / 0.01);

  // ===== Forces =====
  F_normal_front = m_total * g * (b_cg * cos(terrain_slope) - h_cg * sin(terrain_slope)) / L_wb;
  F_gravity_long = m_total * g * sin(terrain_slope);
  F_roll_resist = Crr * m_total * g * cos(terrain_slope) * tanh_v;

  // Traction force: gripping or sliding
  F_traction = max(-mu * F_normal_front, min(mu * F_normal_front, tau_traction_eff / r_wheel));

  // Excess torque beyond friction limit drives slip
  tau_excess = tau_traction_eff - F_traction * r_wheel;
  slip_target = k_slip * tau_excess / (mu * F_normal_front * r_wheel + 0.001);

  // Slip dynamics
  der(slip_ratio) = (slip_target - slip_ratio) / T_slip;
  abs_slip = abs(slip_ratio);

  // Wheel angular velocity
  omega_wheel = v / (r_wheel * (1.0 - slip_ratio) + 0.001);

  // ===== Longitudinal dynamics =====
  der(x) = v;
  m_total * der(v) = F_traction - F_gravity_long - F_roll_resist + F_disturb_eff;

  // ===== Pitch dynamics =====
  der(theta_pitch) = omega_pitch;
  J_pitch * der(omega_pitch) = k_pitch * (terrain_slope + ridge_pitch - theta_pitch) - c_pitch * omega_pitch;

  // ===== Roll dynamics =====
  der(phi_roll) = omega_roll;
  J_roll * der(omega_roll) = -k_roll * phi_roll - c_roll * omega_roll + F_disturb_eff * h_cg;

  // ===== Steering dynamics =====
  der(delta_steer) = delta_steer_rate;
  der(delta_steer_rate) = tau_steer_eff - 5.0 * delta_steer_rate - 50.0 * delta_steer;

  // ===== Torque filter and actuator saturation =====
  der(tau_traction_filt) = (tau_traction_cmd - tau_traction_filt) / tau_filt_tc;
  tau_traction_eff = max(-tau_max, min(tau_max, tau_traction_filt));
  tau_steer_eff = max(-tau_max, min(tau_max, tau_steer_cmd));

  // ===== Sensors =====
  v_meas = v;
  theta_meas = theta_pitch;
  phi_meas = phi_roll;
  d_edge = plateau_end_x - x;

  // ===== Controller (sampled at 250 Hz) =====
  when sample(0, T_sample) then
    // Phase selection
    if x < ramp_start_x then
      v_ref = v_ref_flat;
    elseif x < ramp_end_x then
      v_ref = v_ref_ramp;
    elseif x < plateau_end_x - stop_margin then
      v_ref = v_ref_plateau;
    else
      v_ref = 0.0;
    end if;

    // Tracking error
    tracking_error = v_ref - v_meas;

    // Slip reduction factor
    if abs_slip > slip_thresh then
      slip_reduction = max(0.0, 1.0 - (abs_slip - slip_thresh) / (slip_limit - slip_thresh + 0.001));
    else
      slip_reduction = 1.0;
    end if;

    // Raw torque command
    tau_raw = (Kp_speed * m_total * tracking_error
      + m_total * g * sin(terrain_slope) * r_wheel
      - F_disturb_eff * r_wheel) * slip_reduction;

    // Saturated traction torque
    tau_traction_cmd = max(-tau_max, min(tau_max, tau_raw));

    // Steering torque: maintain straight
    tau_steer_cmd = max(-tau_max, min(tau_max, -K_steer * delta_steer));
  end when;

  // ===== Acceptance criteria (fail-closed) =====
  actuator_ok = (abs(tau_traction_eff) <= tau_max + 1e-6)
    and (abs(tau_steer_eff) <= tau_max + 1e-6);

  slip_ok = abs_slip < 0.35;

  attitude_ok = (abs(theta_pitch) < 0.40) and (abs(phi_roll) < 0.40);

  stopping_ok = (x < plateau_end_x)
    and (if time > 15.0 then (v < 0.05 and x > ramp_end_x) else true);

  tracking_ok = if time < 10.4 then true else abs(tracking_error) < 0.162;

  no_nan_ok = (v == v) and (x == x)
    and (tau_traction_eff == tau_traction_eff)
    and (slip_ratio == slip_ratio)
    and (theta_pitch == theta_pitch)
    and (phi_roll == phi_roll);

  all_acceptance_ok = actuator_ok and slip_ok and attitude_ok
    and stopping_ok and tracking_ok and no_nan_ok;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 1.0 / 250.0),
    Documentation(info = "TriTugClimbE: 38 kg chassis + 20 kg payload, one 0.15 m front drive-and-steer wheel, two passive rear wheels. Ascends 12 deg ramp, traverses 2 m plateau with two 0.05 m ridges, stops before descending edge. Slip-aware traction control with bounded braking (37.4 N.m). 180 N payload disturbance in middle third of 16 s run. Friction 0.76. Control at 250 Hz.")
  );
end TriTugClimbE;