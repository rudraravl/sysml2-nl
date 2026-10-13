model WheelLegTraverseC
  // ===== Stated parameters =====
  parameter Real m_torso = 28.0 "Torso mass [kg]";
  parameter Real r_wheel = 0.10 "Wheel radius [m]";
  parameter Real tau_max = 50.6 "Max joint torque magnitude [N.m]";
  parameter Real mu = 0.78 "Contact friction coefficient";
  parameter Real clearance_min = 0.03 "Minimum clearance [m]";
  parameter Real attitude_max = 0.45 "Max attitude [rad]";
  parameter Real path_err_max = 0.158 "Max body-path error after 7.8 s [m]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";
  parameter Integer f_ctrl = 125 "Control rate [Hz]";
  parameter Real dt_ctrl = 1.0/f_ctrl "Control period [s]";
  parameter Real F_push = 81.0 "Lateral push disturbance [N]";
  parameter Real h_rock = 0.08 "Rock height [m]";
  parameter Real d_gap = 0.12 "Gap depth [m]";
  parameter Real v_cmd = 0.0 "Commanded average speed [m/s] (unknown, placeholder)";
  parameter Real t_metric = 7.8 "Time for path error metric [s]";

  // ===== Unknown but necessary placeholder parameters (assumed, not stated) =====
  parameter Real g = 9.81 "Gravity [m/s^2]";
  parameter Real I_body = 1.0 "Body pitch inertia [kg.m^2] (unknown, assumed)";
  parameter Real I_wheel = 0.01 "Wheel inertia [kg.m^2] (unknown, assumed)";
  parameter Real L_leg = 0.3 "Nominal leg length [m] (unknown, assumed)";
  parameter Real r_lever = 0.3 "Torque-to-force lever [m] (unknown, assumed)";
  parameter Real track = 0.4 "Lateral track width [m] (unknown, assumed)";
  parameter Real wheelbase = 0.6 "Longitudinal wheelbase [m] (unknown, assumed)";
  parameter Real z_des_nom = 0.35 "Nominal body height [m] (unknown, assumed)";
  parameter Real lookahead = 0.5 "Depth lookahead [m] (unknown, assumed)";
  parameter Real body_half_h = 0.1 "Body half height [m] (unknown, assumed)";
  parameter Real route_length = 5.0 "Route length for completion [m] (unknown, assumed)";

  // ===== Continuous states =====
  Real x_body(start=0.0) "Horizontal position [m]";
  Real vx_body(start=0.0) "Horizontal velocity [m/s]";
  Real y_body(start=0.0) "Lateral position [m]";
  Real vy_body(start=0.0) "Lateral velocity [m/s]";
  Real z_body(start=0.4) "Body height [m]";
  Real vz_body(start=0.0) "Vertical velocity [m/s]";
  Real theta(start=0.0) "Pitch angle [rad]";
  Real theta_rate(start=0.0) "Pitch rate [rad/s]";
  Real wheel_angle_1(start=0.0) "Wheel 1 angle [rad]";
  Real wheel_omega_1(start=0.0) "Wheel 1 angular velocity [rad/s]";
  Real wheel_angle_2(start=0.0);
  Real wheel_omega_2(start=0.0);
  Real wheel_angle_3(start=0.0);
  Real wheel_omega_3(start=0.0);
  Real wheel_angle_4(start=0.0);
  Real wheel_omega_4(start=0.0);

  // ===== Discrete controller variables =====
  discrete Real z_des(start=0.35);
  discrete Real stance_1(start=1.0);
  discrete Real stance_2(start=1.0);
  discrete Real stance_3(start=1.0);
  discrete Real stance_4(start=1.0);
  discrete Real F_des_1(start=68.67);
  discrete Real F_des_2(start=68.67);
  discrete Real F_des_3(start=68.67);
  discrete Real F_des_4(start=68.67);
  discrete Real tau_leg_1a(start=0.0);
  discrete Real tau_leg_1b(start=0.0);
  discrete Real tau_leg_2a(start=0.0);
  discrete Real tau_leg_2b(start=0.0);
  discrete Real tau_leg_3a(start=0.0);
  discrete Real tau_leg_3b(start=0.0);
  discrete Real tau_leg_4a(start=0.0);
  discrete Real tau_leg_4b(start=0.0);
  discrete Real tau_wheel_1(start=0.0);
  discrete Real tau_wheel_2(start=0.0);
  discrete Real tau_wheel_3(start=0.0);
  discrete Real tau_wheel_4(start=0.0);
  discrete Real F_lat_ctrl(start=0.0);
  discrete Real rock_detected(start=0.0);
  discrete Real gap_detected(start=0.0);
  discrete Real path_error_at_78(start=0.0);

  // ===== Algebraic variables =====
  Real x_wheel_1, x_wheel_2, x_wheel_3, x_wheel_4;
  Real z_wheel_1, z_wheel_2, z_wheel_3, z_wheel_4;
  Real z_terr_1, z_terr_2, z_terr_3, z_terr_4;
  Real z_terr_ahead;
  Real leg_ext_1, leg_ext_2, leg_ext_3, leg_ext_4;
  Real F1, F2, F3, F4;
  Real N1, N2, N3, N4;
  Real Fx1, Fx2, Fx3, Fx4;
  Real Fx1_max, Fx2_max, Fx3_max, Fx4_max;
  Real M_pitch;
  Real ja_1a, ja_1b, ja_2a, ja_2b, ja_3a, ja_3b, ja_4a, ja_4b;
  Real cf_1, cf_2, cf_3, cf_4;
  Real pitch_meas, pitch_rate_meas, yaw_meas, roll_meas;
  Real path_error;
  Real route_complete;
  Real attitude_violation;
  Real clearance_violation;
  Real nan_check;

  // ===== Helper function: clamp =====
  function clampReal
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if x < lo then lo else if x > hi then hi else x;
  end clampReal;

  // ===== Terrain function =====
  function terrainHeight
    input Real x;
    input Real h_rock;
    input Real d_gap;
    output Real z;
  algorithm
    z := 0.0;
    if x >= 1.0 and x <= 1.2 then
      z := h_rock;
    elseif x >= 3.0 and x <= 3.2 then
      z := h_rock;
    elseif x >= 2.0 and x <= 2.3 then
      z := -d_gap;
    elseif x >= 4.0 and x <= 4.3 then
      z := -d_gap;
    end if;
  end terrainHeight;

equation
  // ===== Wheel positions =====
  x_wheel_1 = x_body + wheelbase/2;
  x_wheel_2 = x_body + wheelbase/2;
  x_wheel_3 = x_body - wheelbase/2;
  x_wheel_4 = x_body - wheelbase/2;

  z_wheel_1 = z_body + (wheelbase/2)*sin(theta) - leg_ext_1;
  z_wheel_2 = z_body + (wheelbase/2)*sin(theta) - leg_ext_2;
  z_wheel_3 = z_body - (wheelbase/2)*sin(theta) - leg_ext_3;
  z_wheel_4 = z_body - (wheelbase/2)*sin(theta) - leg_ext_4;

  // ===== Terrain =====
  z_terr_1 = terrainHeight(x_wheel_1, h_rock, d_gap);
  z_terr_2 = terrainHeight(x_wheel_2, h_rock, d_gap);
  z_terr_3 = terrainHeight(x_wheel_3, h_rock, d_gap);
  z_terr_4 = terrainHeight(x_wheel_4, h_rock, d_gap);
  z_terr_ahead = terrainHeight(x_body + lookahead, h_rock, d_gap);

  // ===== Leg extensions =====
  leg_ext_1 = if stance_1 > 0.5 then max(z_body - z_terr_1 - r_wheel, 0.0) else L_leg;
  leg_ext_2 = if stance_2 > 0.5 then max(z_body - z_terr_2 - r_wheel, 0.0) else L_leg;
  leg_ext_3 = if stance_3 > 0.5 then max(z_body - z_terr_3 - r_wheel, 0.0) else L_leg;
  leg_ext_4 = if stance_4 > 0.5 then max(z_body - z_terr_4 - r_wheel, 0.0) else L_leg;

  // ===== Joint angle sensors =====
  ja_1a = leg_ext_1 / max(L_leg, 1e-6);
  ja_1b = leg_ext_1 / max(L_leg, 1e-6);
  ja_2a = leg_ext_2 / max(L_leg, 1e-6);
  ja_2b = leg_ext_2 / max(L_leg, 1e-6);
  ja_3a = leg_ext_3 / max(L_leg, 1e-6);
  ja_3b = leg_ext_3 / max(L_leg, 1e-6);
  ja_4a = leg_ext_4 / max(L_leg, 1e-6);
  ja_4b = leg_ext_4 / max(L_leg, 1e-6);

  // ===== Leg torques to vertical force =====
  F1 = (tau_leg_1a + tau_leg_1b) / max(r_lever, 1e-6);
  F2 = (tau_leg_2a + tau_leg_2b) / max(r_lever, 1e-6);
  F3 = (tau_leg_3a + tau_leg_3b) / max(r_lever, 1e-6);
  F4 = (tau_leg_4a + tau_leg_4b) / max(r_lever, 1e-6);

  // ===== Normal forces =====
  N1 = if stance_1 > 0.5 and F1 > 0.0 then F1 else 0.0;
  N2 = if stance_2 > 0.5 and F2 > 0.0 then F2 else 0.0;
  N3 = if stance_3 > 0.5 and F3 > 0.0 then F3 else 0.0;
  N4 = if stance_4 > 0.5 and F4 > 0.0 then F4 else 0.0;

  cf_1 = N1;
  cf_2 = N2;
  cf_3 = N3;
  cf_4 = N4;

  // ===== Horizontal wheel forces (friction limited) =====
  Fx1_max = mu * max(N1, 0.0);
  Fx2_max = mu * max(N2, 0.0);
  Fx3_max = mu * max(N3, 0.0);
  Fx4_max = mu * max(N4, 0.0);
  Fx1 = if Fx1_max > 1e-6 then clampReal(tau_wheel_1 / r_wheel, -Fx1_max, Fx1_max) else 0.0;
  Fx2 = if Fx2_max > 1e-6 then clampReal(tau_wheel_2 / r_wheel, -Fx2_max, Fx2_max) else 0.0;
  Fx3 = if Fx3_max > 1e-6 then clampReal(tau_wheel_3 / r_wheel, -Fx3_max, Fx3_max) else 0.0;
  Fx4 = if Fx4_max > 1e-6 then clampReal(tau_wheel_4 / r_wheel, -Fx4_max, Fx4_max) else 0.0;

  // ===== Body dynamics =====
  der(x_body) = vx_body;
  der(vx_body) = (Fx1 + Fx2 + Fx3 + Fx4) / m_torso;
  der(y_body) = vy_body;
  der(vy_body) = (F_lat_ctrl + (if time >= T_sim/3.0 and time <= 2.0*T_sim/3.0 then F_push else 0.0)) / m_torso;
  der(z_body) = vz_body;
  der(vz_body) = (F1 + F2 + F3 + F4 - m_torso*g) / m_torso;
  der(theta) = theta_rate;
  M_pitch = (wheelbase/2)*(F1 + F2 - F3 - F4) - L_leg*(Fx1 + Fx2 + Fx3 + Fx4);
  der(theta_rate) = M_pitch / max(I_body, 1e-6);

  // ===== Wheel dynamics =====
  der(wheel_angle_1) = wheel_omega_1;
  der(wheel_omega_1) = (tau_wheel_1 - Fx1 * r_wheel) / max(I_wheel, 1e-6);
  der(wheel_angle_2) = wheel_omega_2;
  der(wheel_omega_2) = (tau_wheel_2 - Fx2 * r_wheel) / max(I_wheel, 1e-6);
  der(wheel_angle_3) = wheel_omega_3;
  der(wheel_omega_3) = (tau_wheel_3 - Fx3 * r_wheel) / max(I_wheel, 1e-6);
  der(wheel_angle_4) = wheel_omega_4;
  der(wheel_omega_4) = (tau_wheel_4 - Fx4 * r_wheel) / max(I_wheel, 1e-6);

  // ===== IMU sensors =====
  pitch_meas = theta;
  pitch_rate_meas = theta_rate;
  yaw_meas = 0.0;
  roll_meas = 0.0;

  // ===== Metrics =====
  path_error = abs(x_body - v_cmd * time);
  route_complete = if x_body >= route_length then 1.0 else 0.0;
  attitude_violation = if abs(theta) > attitude_max then 1.0 else 0.0;
  clearance_violation = if (z_body - body_half_h - terrainHeight(x_body, h_rock, d_gap)) < clearance_min then 1.0 else 0.0;
  nan_check = if (x_body > 1e100 or x_body < -1e100) or
                 (vx_body > 1e100 or vx_body < -1e100) or
                 (y_body > 1e100 or y_body < -1e100) or
                 (vy_body > 1e100 or vy_body < -1e100) or
                 (z_body > 1e100 or z_body < -1e100) or
                 (vz_body > 1e100 or vz_body < -1e100) or
                 (theta > 1e100 or theta < -1e100) or
                 (theta_rate > 1e100 or theta_rate < -1e100)
              then 1.0 else 0.0;

  // ===== Controller at 125 Hz =====
  when sample(0, dt_ctrl) then
    // Terrain detection from forward depth
    rock_detected = if z_terr_ahead > 0.05 then 1.0 else 0.0;
    gap_detected = if z_terr_ahead < -0.05 then 1.0 else 0.0;

    // Adjustable body height
    z_des = z_des_nom + (if rock_detected > 0.5 then 0.05 else 0.0) - (if gap_detected > 0.5 then 0.02 else 0.0);

    // Foothold planning: lift front legs over first gap
    stance_1 = if gap_detected > 0.5 and x_body > 1.8 and x_body < 2.2 then 0.0 else 1.0;
    stance_2 = stance_1;
    stance_3 = 1.0;
    stance_4 = 1.0;

    // Desired vertical forces: weight distribution + height/pitch feedback
    F_des_1 = m_torso*g/4.0 + 50.0*(z_des - z_body) - 10.0*vz_body + 2.0*(0.0 - theta) - 0.5*theta_rate;
    F_des_2 = m_torso*g/4.0 + 50.0*(z_des - z_body) - 10.0*vz_body + 2.0*(0.0 - theta) - 0.5*theta_rate;
    F_des_3 = m_torso*g/4.0 + 50.0*(z_des - z_body) - 10.0*vz_body - 2.0*(0.0 - theta) + 0.5*theta_rate;
    F_des_4 = m_torso*g/4.0 + 50.0*(z_des - z_body) - 10.0*vz_body - 2.0*(0.0 - theta) + 0.5*theta_rate;

    // Swing legs produce zero force
    F_des_1 = if stance_1 > 0.5 then F_des_1 else 0.0;
    F_des_2 = if stance_2 > 0.5 then F_des_2 else 0.0;
    F_des_3 = if stance_3 > 0.5 then F_des_3 else 0.0;
    F_des_4 = if stance_4 > 0.5 then F_des_4 else 0.0;

    // Map to two leg joint torques each, independently limited
    tau_leg_1a = clampReal(F_des_1 * r_lever / 2.0, -tau_max, tau_max);
    tau_leg_1b = clampReal(F_des_1 * r_lever / 2.0, -tau_max, tau_max);
    tau_leg_2a = clampReal(F_des_2 * r_lever / 2.0, -tau_max, tau_max);
    tau_leg_2b = clampReal(F_des_2 * r_lever / 2.0, -tau_max, tau_max);
    tau_leg_3a = clampReal(F_des_3 * r_lever / 2.0, -tau_max, tau_max);
    tau_leg_3b = clampReal(F_des_3 * r_lever / 2.0, -tau_max, tau_max);
    tau_leg_4a = clampReal(F_des_4 * r_lever / 2.0, -tau_max, tau_max);
    tau_leg_4b = clampReal(F_des_4 * r_lever / 2.0, -tau_max, tau_max);

    // Wheel torque commands for forward speed
    tau_wheel_1 = clampReal(2.0*(v_cmd - vx_body) * r_wheel, -tau_max, tau_max);
    tau_wheel_2 = clampReal(2.0*(v_cmd - vx_body) * r_wheel, -tau_max, tau_max);
    tau_wheel_3 = clampReal(2.0*(v_cmd - vx_body) * r_wheel, -tau_max, tau_max);
    tau_wheel_4 = clampReal(2.0*(v_cmd - vx_body) * r_wheel, -tau_max, tau_max);

    // Lateral stabilization
    F_lat_ctrl = -20.0*y_body - 10.0*vy_body;
  end when;

  // ===== Metric sampling =====
  when time >= t_metric then
    path_error_at_78 = path_error;
  end when;

  // ===== Assertions for requirements =====
  assert(attitude_violation < 0.5, "Attitude exceeded 0.45 rad");
  assert(clearance_violation < 0.5, "Torso-terrain clearance below 0.03 m");
  assert(nan_check < 0.5, "NaN or infinite value detected");
  assert(path_error_at_78 <= path_err_max + 1e-6, "Primary tracking error exceeded 0.158 m after 7.8 s");

initial equation
  // Let the discrete controller initialize at t=0
end WheelLegTraverseC;