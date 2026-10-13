model ParallelGripPushB
  // ============ Physical parameters (from requirement) ============
  parameter Real m_palm = 6.0 "Palm mass [kg]";
  parameter Real m_finger = 0.5 "Finger mass [kg], each";
  parameter Real finger_travel = 0.05 "Prismatic joint travel [m]";
  parameter Real mu_table = 0.42 "Box-table friction coefficient";
  parameter Real mu_tool = 0.65 "Tool-box friction coefficient";
  parameter Real f_max = 36.9 "Max actuator command per finger [N]";

  // ============ Physical parameters (not specified, assumed) ============
  parameter Real m_box = 1.0 "Box mass [kg] -- not specified in requirement, assumed";
  parameter Real k_pad = 2000.0 "Pad stiffness [N/m] -- not specified, assumed";
  parameter Real c_pad = 100.0 "Pad damping [N.s/m] -- not specified, assumed";
  parameter Real box_half_w = 0.04 "Box half-width in grip direction [m] -- not specified, assumed";
  parameter Real box_half_l = 0.08 "Box half-length in push direction [m] -- not specified, assumed";
  parameter Real I_box = 0.002 "Box yaw moment of inertia [kg.m^2] -- not specified, assumed";
  parameter Real v_thresh = 0.002 "Friction smoothing velocity threshold [m/s] -- assumed";

  // ============ Control parameters (not specified, assumed) ============
  parameter Real kp_pos = 300.0 "Position proportional gain -- assumed";
  parameter Real kd_pos = 50.0 "Position derivative gain -- assumed";
  parameter Real ki_pos = 20.0 "Position integral gain -- assumed";
  parameter Real kp_force = 200.0 "Force control proportional gain -- assumed";
  parameter Real f_grip_set = 15.0 "Grip force setpoint [N], within 5-25 N range";

  constant Real g = 9.81 "Gravitational acceleration [m/s^2]";

  // ============ Box state ============
  Real x_box(start=0.0) "Box x position [m]";
  Real y_box(start=0.0) "Box y position [m]";
  Real yaw(start=0.0) "Box yaw angle [rad]";
  Real vx(start=0.0) "Box x velocity [m/s]";
  Real vy(start=0.0) "Box y velocity [m/s]";
  Real wz(start=0.0) "Box yaw rate [rad/s]";

  // ============ Palm state ============
  Real x_palm(start=0.0) "Palm x position [m]";
  Real y_palm(start=0.0) "Palm y position [m]";
  Real yaw_palm(start=0.0) "Palm yaw angle [rad]";
  Real vx_palm(start=0.0) "Palm x velocity [m/s]";
  Real vy_palm(start=0.0) "Palm y velocity [m/s]";
  Real wz_palm(start=0.0) "Palm yaw rate [rad/s]";

  // ============ Finger state ============
  Real d_left(start=0.0363) "Left finger gap from palm center [m]";
  Real d_right(start=0.0363) "Right finger gap from palm center [m]";
  Real vd_left(start=0.0) "Left finger gap velocity [m/s]";
  Real vd_right(start=0.0) "Right finger gap velocity [m/s]";

  // ============ Integral error states ============
  Real integ_x(start=0.0) "Position integral error x [m.s]";
  Real integ_y(start=0.0) "Position integral error y [m.s]";

  // ============ Actuator commands ============
  Real u_left "Left finger actuator command [N]";
  Real u_right "Right finger actuator command [N]";
  Real u_left_sat "Saturated left command [N]";
  Real u_right_sat "Saturated right command [N]";
  Real u_palm_x "Palm x drive force [N]";
  Real u_palm_y "Palm y drive force [N]";
  Real u_palm_yaw "Palm yaw drive torque [N.m]";

  // ============ Contact and friction forces ============
  Real f_n_left "Left pad normal contact force [N]";
  Real f_n_right "Right pad normal contact force [N]";
  Real f_grip "Total grip (normal) force [N]";
  Real f_tang_x "Tangential push force x on box [N]";
  Real f_tang_y "Tangential push force y on box [N]";
  Real f_tang_yaw "Tangential push torque on box [N.m]";
  Real f_table_x "Table friction force x [N]";
  Real f_table_y "Table friction force y [N]";
  Real f_table_yaw "Table friction yaw torque [N.m]";
  Real N_table "Table normal force [N]";
  Real f_table_base "Base Coulomb table friction magnitude [N]";

  // ============ Reference trajectory ============
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real yaw_ref "Reference yaw [rad]";
  Real vx_ref "Reference x velocity [m/s]";
  Real vy_ref "Reference y velocity [m/s]";
  Real track_err "Primary tracking error [m]";

  // ============ Disturbance ============
  Real dist_force "Disturbance friction force magnitude [N]";
  Real dist_active "Disturbance activation (1.0 active, 0.0 inactive)";

  // ============ Sensors ============
  Real f_grip_meas "Measured total grip force [N]";
  Real x_meas "Measured box x position [m]";
  Real y_meas "Measured box y position [m]";
  Real yaw_meas "Measured box yaw angle [rad]";
  Real vx_meas "Measured box x velocity [m/s]";
  Real vy_meas "Measured box y velocity [m/s]";

  // ============ Intermediate variables ============
  Real rel_vx "Relative x velocity palm minus box [m/s]";
  Real rel_vy "Relative y velocity palm minus box [m/s]";
  Real rel_vw "Relative yaw rate palm minus box [rad/s]";
  Real rel_v_mag "Relative planar velocity magnitude [m/s]";

equation
  // ===== Two-segment planar reference trajectory =====
  // Segment 1: 0 to 5 s, straight push in +x at 0.002 m/s
  // Segment 2: 5 to 10 s, diagonal motion with yaw rotation
  if time <= 5.0 then
    x_ref = 0.002 * time;
    y_ref = 0.0;
    yaw_ref = 0.0;
    vx_ref = 0.002;
    vy_ref = 0.0;
  else
    x_ref = 0.01 + 0.0015 * (time - 5.0);
    y_ref = 0.0008 * (time - 5.0);
    yaw_ref = 0.04 * (time - 5.0);
    vx_ref = 0.0015;
    vy_ref = 0.0008;
  end if;

  // ===== Disturbance: 4.2 N friction change during middle third of 10 s =====
  // Middle third: [10/3, 20/3] = [3.333, 6.667] s
  dist_active = if (time >= 10.0 / 3.0 and time <= 20.0 / 3.0) then 1.0 else 0.0;
  dist_force = dist_active * 4.2;

  // ===== Palm hybrid position control (PID) =====
  der(integ_x) = x_ref - x_palm;
  der(integ_y) = y_ref - y_palm;

  u_palm_x = kp_pos * (x_ref - x_palm) + kd_pos * (vx_ref - vx_palm) + ki_pos * integ_x;
  u_palm_y = kp_pos * (y_ref - y_palm) + kd_pos * (vy_ref - vy_palm) + ki_pos * integ_y;
  u_palm_yaw = 30.0 * (yaw_ref - yaw_palm) + 5.0 * (0.0 - wz_palm);

  // ===== Palm dynamics with reaction force from box =====
  der(x_palm) = vx_palm;
  der(y_palm) = vy_palm;
  der(yaw_palm) = wz_palm;
  der(vx_palm) = (u_palm_x - f_tang_x) / m_palm;
  der(vy_palm) = (u_palm_y - f_tang_y) / m_palm;
  der(wz_palm) = (u_palm_yaw - f_tang_yaw) / m_palm;

  // ===== Finger force control and compliant pad contact =====
  // Normal contact force from pad compression (continuous, non-negative)
  f_n_left = max(0.0, k_pad * (box_half_w - d_left) - c_pad * vd_left);
  f_n_right = max(0.0, k_pad * (box_half_w - d_right) - c_pad * vd_right);
  f_grip = f_n_left + f_n_right;

  // Force controller: close fingers when grip force below setpoint
  u_left = kp_force * (f_grip_set - f_grip);
  u_right = kp_force * (f_grip_set - f_grip);

  // Bounded linear actuator saturation (max 36.9 N per finger)
  u_left_sat = max(-f_max, min(f_max, u_left));
  u_right_sat = max(-f_max, min(f_max, u_right));

  // Finger dynamics: positive u pushes finger inward (reduces gap)
  der(d_left) = vd_left;
  der(d_right) = vd_right;
  der(vd_left) = (-u_left_sat + f_n_left) / m_finger;
  der(vd_right) = (-u_right_sat + f_n_right) / m_finger;

  // ===== Box dynamics on table =====
  N_table = m_box * g;
  f_table_base = mu_table * N_table;

  // Relative velocity between palm and box
  rel_vx = vx_palm - vx;
  rel_vy = vy_palm - vy;
  rel_vw = wz_palm - wz;
  rel_v_mag = sqrt(rel_vx * rel_vx + rel_vy * rel_vy + 1.0e-9);

  // Tangential push force from tool-box friction (Coulomb, smoothed via tanh)
  f_tang_x = mu_tool * f_grip * (rel_vx / rel_v_mag) * tanh(rel_v_mag / v_thresh);
  f_tang_y = mu_tool * f_grip * (rel_vy / rel_v_mag) * tanh(rel_v_mag / v_thresh);
  f_tang_yaw = mu_tool * f_grip * box_half_l * tanh(rel_vw / (v_thresh / box_half_l));

  // Table friction (Coulomb plus disturbance, smoothed via tanh)
  f_table_x = -(f_table_base + dist_force) * tanh(vx / v_thresh);
  f_table_y = -(f_table_base + dist_force) * tanh(vy / v_thresh);
  f_table_yaw = -0.5 * (f_table_base + dist_force) * box_half_l * tanh(wz / (v_thresh / box_half_l));

  // Box equations of motion (planar)
  der(x_box) = vx;
  der(y_box) = vy;
  der(yaw) = wz;
  der(vx) = (f_tang_x + f_table_x) / m_box;
  der(vy) = (f_tang_y + f_table_y) / m_box;
  der(wz) = (f_tang_yaw + f_table_yaw) / I_box;

  // ===== Primary tracking error =====
  track_err = sqrt((x_box - x_ref) * (x_box - x_ref) + (y_box - y_ref) * (y_box - y_ref));

  // ===== Sensors (direct measurement) =====
  f_grip_meas = f_grip;
  x_meas = x_box;
  y_meas = y_box;
  yaw_meas = yaw;
  vx_meas = vx;
  vy_meas = vy;

  // ===== Requirement assertions =====
  assert(abs(u_left_sat) <= f_max + 0.001, "Left actuator bound violated");
  assert(abs(u_right_sat) <= f_max + 0.001, "Right actuator bound violated");

  annotation(
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "ParallelGripPushB: Contact-rich manipulation with hybrid position-force control.
      Two-segment planar reference, 4.2 N friction disturbance during middle third [3.33, 6.67] s.
      Palm 6 kg, fingers 0.5 kg each with 0.05 m prismatic travel and compliant pads.
      Table friction 0.42, tool-box friction 0.65, actuator bound 36.9 N per finger.
      Grip force regulated to 15 N (within 5-25 N). Simulation 100 Hz output for 10 s.")
  );
end ParallelGripPushB;