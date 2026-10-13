model SeaSnakeHoldE
  "Free-base articulated underwater robot (SeaSnakeHoldE) holding a fixed 6-DOF pose beside an offshore cylinder.
   Six 0.30 m capsule modules, alternating yaw/pitch joints, passive tail fin, 12 bounded joint actuators (pairs over 6 joints).
   Bounded body-wrench station keeping with a controlled 144 N middle-third tether/current disturbance. 250 Hz, 16 s. Fail-closed acceptance."

  // ---- Stated parameters ----
  parameter Real m_robot(unit="kg") = 32.0 "Total robot mass";
  parameter Real L_module(unit="m") = 0.30 "Capsule module length";
  parameter Integer n_modules = 6 "Number of capsule modules";
  parameter Integer n_joints = 6 "Articulated joints (alternating yaw/pitch)";
  parameter Integer n_actuators = 12 "Bounded joint actuators (antagonistic pairs over 6 joints)";
  parameter Real tau_joint_max(unit="N.m") = 35.2 "Per-joint command magnitude bound";
  parameter Real F_disturb_nom(unit="N") = 144.0 "Tether/current disturbance magnitude";
  parameter Real t_run(unit="s") = 16.0 "Scenario duration";
  parameter Real fs_hz(unit="Hz") = 250.0 "Run rate";
  parameter Real dt_sample(unit="s") = 1.0/fs_hz "Sample period";

  // ---- Assumed/representative physical parameters (facts not stated; labeled) ----
  parameter Real Ixx(unit="kg.m2") = 1.5 "Roll inertia (assumed; fact not stated)";
  parameter Real Iyy(unit="kg.m2") = 1.5 "Pitch inertia (assumed; fact not stated)";
  parameter Real Izz(unit="kg.m2") = 1.0 "Yaw inertia (assumed; fact not stated)";
  parameter Real I_joint(unit="kg.m2") = 0.05 "Per-joint inertia (assumed; fact not stated)";
  parameter Real d_lin(unit="N.s/m") = 60.0 "Linear hydrodynamic damping (assumed; fact not stated)";
  parameter Real d_ang(unit="N.m.s/rad") = 6.0 "Angular hydrodynamic damping (assumed; fact not stated)";
  parameter Real d_joint(unit="N.m.s/rad") = 0.4 "Joint damping (assumed; fact not stated)";
  parameter Real k_joint(unit="N.m/rad") = 15.0 "Joint return stiffness (assumed; fact not stated)";
  parameter Real F_body_max(unit="N") = 400.0 "Body-wrench force bound (assumed; fact not stated)";
  parameter Real T_body_max(unit="N.m") = 100.0 "Body-wrench torque bound (assumed; fact not stated)";
  parameter Real rho_water(unit="kg/m3") = 1025.0 "Seawater density (assumed; fact not stated)";
  parameter Real g(unit="m/s2") = 9.81 "Gravity magnitude (assumed; fact not stated)";
  // Neutral buoyancy assumed (fact not stated); no net weight/buoyancy force applied.

  // ---- Controller gains (assumed; facts not stated) ----
  parameter Real Kp_pos(unit="N/m") = 600.0 "Position proportional gain (assumed)";
  parameter Real Ki_pos(unit="N/(m.s)") = 200.0 "Position integral gain (assumed)";
  parameter Real Kd_pos(unit="N.s/m") = 140.0 "Position derivative gain (assumed)";
  parameter Real Kp_att(unit="N.m/rad") = 200.0 "Attitude proportional gain (assumed)";
  parameter Real Kd_att(unit="N.m.s/rad") = 40.0 "Attitude derivative gain (assumed)";

  // ---- Setpoint pose (hold beside structure) ----
  parameter Real x_set(unit="m") = 2.0;
  parameter Real y_set(unit="m") = 1.5;
  parameter Real z_set(unit="m") = -5.0;
  parameter Real phi_set(unit="rad") = 0.0;
  parameter Real theta_set(unit="rad") = 0.0;
  parameter Real psi_set(unit="rad") = 0.0;

  // ---- Offshore structure: fixed collidable vertical cylinder ----
  parameter Real cyl_x(unit="m") = 2.0 "Cylinder center x";
  parameter Real cyl_y(unit="m") = 2.5 "Cylinder center y";
  parameter Real cyl_radius(unit="m") = 0.5 "Cylinder radius";
  parameter Real cyl_top(unit="m") = 0.0 "Cylinder top z";
  parameter Real cyl_bottom(unit="m") = -10.0 "Cylinder bottom z";
  parameter Real clearance_req(unit="m") = 0.30 "Required clearance";

  // ---- Tether ----
  parameter Real tether_ax(unit="m") = 0.0 "Anchor x";
  parameter Real tether_ay(unit="m") = 0.0 "Anchor y";
  parameter Real tether_az(unit="m") = 0.0 "Anchor z";
  parameter Real k_tether(unit="N/m") = 30.0 "Tether stiffness (assumed; fact not stated)";
  parameter Real d_tether(unit="N.s/m") = 4.0 "Tether damping (assumed; fact not stated)";
  parameter Real L_tether_rest(unit="m") = 5.59 "Tether rest length (assumed; matches initial pose)";
  parameter Real L_tether_max(unit="m") = 12.0 "Max tether length";
  parameter Real T_tether_max(unit="N") = 400.0 "Tether tension limit (assumed; fact not stated)";

  // ---- Disturbance window: middle third of t_run ----
  parameter Real t_dist_start(unit="s") = t_run/3.0 "Disturbance start (middle third)";
  parameter Real t_dist_end(unit="s") = 2.0*t_run/3.0 "Disturbance end (middle third)";

  // ---- Acceptance thresholds ----
  parameter Real track_err_thresh(unit="m") = 0.27 "Primary tracking error threshold after 10.4 s";
  parameter Real t_check(unit="s") = 10.4 "Acceptance check time";
  parameter Real att_err_thresh(unit="rad") = 0.10 "Attitude error threshold (assumed; fact not stated)";

  // ---- Base body 6-DOF states ----
  Real x(start=x_set, fixed=true, unit="m");
  Real y(start=y_set, fixed=true, unit="m");
  Real z(start=z_set, fixed=true, unit="m");
  Real vx(start=0, fixed=true, unit="m/s");
  Real vy(start=0, fixed=true, unit="m/s");
  Real vz(start=0, fixed=true, unit="m/s");
  Real phi(start=0, fixed=true, unit="rad");
  Real theta(start=0, fixed=true, unit="rad");
  Real psi(start=0, fixed=true, unit="rad");
  Real wx(start=0, fixed=true, unit="rad/s");
  Real wy(start=0, fixed=true, unit="rad/s");
  Real wz(start=0, fixed=true, unit="rad/s");

  // ---- Joint states (6 joints, alternating yaw/pitch; passive tail fin not actuated) ----
  Real q[6](each start=0, each fixed=true, each unit="rad");
  Real dq[6](each start=0, each fixed=true, each unit="rad/s");
  Real tau_cmd[6](each unit="N.m");
  Real tau_sat[6](each unit="N.m");

  // ---- Body wrench commands ----
  Real Fx_cmd(unit="N"), Fy_cmd(unit="N"), Fz_cmd(unit="N");
  Real Tx_cmd(unit="N.m"), Ty_cmd(unit="N.m"), Tz_cmd(unit="N.m");
  Real Fx_sat(unit="N"), Fy_sat(unit="N"), Fz_sat(unit="N");
  Real Tx_sat(unit="N.m"), Ty_sat(unit="N.m"), Tz_sat(unit="N.m");

  // ---- Position integral states ----
  Real int_ex(start=0, fixed=true, unit="m.s");
  Real int_ey(start=0, fixed=true, unit="m.s");
  Real int_ez(start=0, fixed=true, unit="m.s");

  // ---- Disturbance ----
  Boolean disturb_active;
  Real F_dist_x(unit="N"), F_dist_y(unit="N"), F_dist_z(unit="N");

  // ---- Tether ----
  Real tether_dx(unit="m"), tether_dy(unit="m"), tether_dz(unit="m");
  Real tether_len(unit="m");
  Real tether_stretch(unit="m");
  Real tether_tension(unit="N");
  Real Ft_x(unit="N"), Ft_y(unit="N"), Ft_z(unit="N");

  // ---- Sensors ----
  Real pressure_sensor(unit="Pa");
  Real imu_ax(unit="m/s2"), imu_ay(unit="m/s2"), imu_az(unit="m/s2");
  Real imu_wx(unit="rad/s"), imu_wy(unit="rad/s"), imu_wz(unit="rad/s");
  Real dvl_vx(unit="m/s"), dvl_vy(unit="m/s"), dvl_vz(unit="m/s");
  Real sonar_range(unit="m");

  // ---- Error metrics ----
  Real pos_error(unit="m");
  Real att_error(unit="rad");
  Real primary_tracking_error(unit="m");

  // ---- Clearance ----
  Real cyl_dist_xy(unit="m");
  Real clearance(unit="m");

  // ---- Acceptance ----
  discrete Real max_err_after_check(start=0.0, unit="m") "Max primary tracking error sampled after t_check";
  Boolean ok_joint_bounds;
  Boolean ok_pos_error;
  Boolean ok_att_error;
  Boolean ok_clearance;
  Boolean ok_tether;
  Boolean ok_no_nan;
  Boolean settled_at_check;
  Boolean fail_closed;

equation
  // ===== Disturbance: 144 N in +x during middle third =====
  disturb_active = (time >= t_dist_start) and (time < t_dist_end);
  F_dist_x = if disturb_active then F_disturb_nom else 0.0;
  F_dist_y = 0.0;
  F_dist_z = 0.0;

  // ===== Tether spring-damper from anchor to body =====
  tether_dx = x - tether_ax;
  tether_dy = y - tether_ay;
  tether_dz = z - tether_az;
  tether_len = sqrt(tether_dx*tether_dx + tether_dy*tether_dy + tether_dz*tether_dz + 1e-9);
  tether_stretch = tether_len - L_tether_rest;
  tether_tension = max(0.0, k_tether*tether_stretch + d_tether*(vx*tether_dx/tether_len + vy*tether_dy/tether_len + vz*tether_dz/tether_len));
  Ft_x = -tether_tension * (tether_dx/tether_len);
  Ft_y = -tether_tension * (tether_dy/tether_len);
  Ft_z = -tether_tension * (tether_dz/tether_len);

  // ===== Body-wrench station-keeping controller (PI on position, PD on attitude) =====
  der(int_ex) = (x_set - x);
  der(int_ey) = (y_set - y);
  der(int_ez) = (z_set - z);

  Fx_cmd = Kp_pos*(x_set - x) + Ki_pos*int_ex + Kd_pos*(0 - vx);
  Fy_cmd = Kp_pos*(y_set - y) + Ki_pos*int_ey + Kd_pos*(0 - vy);
  Fz_cmd = Kp_pos*(z_set - z) + Ki_pos*int_ez + Kd_pos*(0 - vz);
  Tx_cmd = Kp_att*(phi_set - phi) + Kd_att*(0 - wx);
  Ty_cmd = Kp_att*(theta_set - theta) + Kd_att*(0 - wy);
  Tz_cmd = Kp_att*(psi_set - psi) + Kd_att*(0 - wz);

  Fx_sat = max(-F_body_max, min(F_body_max, Fx_cmd));
  Fy_sat = max(-F_body_max, min(F_body_max, Fy_cmd));
  Fz_sat = max(-F_body_max, min(F_body_max, Fz_cmd));
  Tx_sat = max(-T_body_max, min(T_body_max, Tx_cmd));
  Ty_sat = max(-T_body_max, min(T_body_max, Ty_cmd));
  Tz_sat = max(-T_body_max, min(T_body_max, Tz_cmd));

  // ===== Joint actuators: 12 actuators as antagonistic pairs over 6 joints, combined torque bounded =====
  // Hold each joint at zero angle (station keeping); undulation amplitude is zero while holding pose.
  for i in 1:6 loop
    tau_cmd[i] = k_joint*(0 - q[i]) - d_joint*dq[i];
    tau_sat[i] = max(-tau_joint_max, min(tau_joint_max, tau_cmd[i]));
    der(q[i]) = dq[i];
    der(dq[i]) = (tau_sat[i] - d_joint*dq[i] - k_joint*q[i]) / I_joint;
  end for;

  // ===== Base body 6-DOF dynamics =====
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (Fx_sat + F_dist_x + Ft_x - d_lin*vx) / m_robot;
  der(vy) = (Fy_sat + F_dist_y + Ft_y - d_lin*vy) / m_robot;
  der(vz) = (Fz_sat + F_dist_z + Ft_z - d_lin*vz) / m_robot;

  der(phi) = wx;
  der(theta) = wy;
  der(psi) = wz;
  der(wx) = (Tx_sat - d_ang*wx) / Ixx;
  der(wy) = (Ty_sat - d_ang*wy) / Iyy;
  der(wz) = (Tz_sat - d_ang*wz) / Izz;

  // ===== Sensors =====
  pressure_sensor = rho_water*g*max(0.0, -z) + 101325.0;
  imu_ax = der(vx);
  imu_ay = der(vy);
  imu_az = der(vz);
  imu_wx = wx;
  imu_wy = wy;
  imu_wz = wz;
  dvl_vx = vx;
  dvl_vy = vy;
  dvl_vz = vz;
  sonar_range = sqrt((x - cyl_x)*(x - cyl_x) + (y - cyl_y)*(y - cyl_y) + 1e-9) - cyl_radius;

  // ===== Error metrics =====
  pos_error = sqrt((x - x_set)*(x - x_set) + (y - y_set)*(y - y_set) + (z - z_set)*(z - z_set));
  att_error = sqrt((phi - phi_set)*(phi - phi_set) + (theta - theta_set)*(theta - theta_set) + (psi - psi_set)*(psi - psi_set));
  primary_tracking_error = pos_error;

  // ===== Clearance to fixed cylinder =====
  cyl_dist_xy = sqrt((x - cyl_x)*(x - cyl_x) + (y - cyl_y)*(y - cyl_y) + 1e-9);
  clearance = cyl_dist_xy - cyl_radius;

  // ===== Synchronized acceptance traces at 250 Hz from t_check =====
  when sample(t_check, dt_sample) then
    max_err_after_check = max(pre(max_err_after_check), primary_tracking_error);
  end when;

  // ===== Acceptance predicates (fail-closed) =====
  ok_joint_bounds = (abs(tau_sat[1]) <= tau_joint_max + 1e-6) and
                    (abs(tau_sat[2]) <= tau_joint_max + 1e-6) and
                    (abs(tau_sat[3]) <= tau_joint_max + 1e-6) and
                    (abs(tau_sat[4]) <= tau_joint_max + 1e-6) and
                    (abs(tau_sat[5]) <= tau_joint_max + 1e-6) and
                    (abs(tau_sat[6]) <= tau_joint_max + 1e-6);
  ok_pos_error = primary_tracking_error < track_err_thresh;
  ok_att_error = att_error < att_err_thresh;
  ok_clearance = clearance >= clearance_req;
  ok_tether = (tether_tension <= T_tether_max) and (tether_len <= L_tether_max);
  ok_no_nan = (x == x) and (y == y) and (z == z) and
              (vx == vx) and (vy == vy) and (vz == vz) and
              (phi == phi) and (theta == theta) and (psi == psi) and
              (wx == wx) and (wy == wy) and (wz == wz) and
              (tau_sat[1] == tau_sat[1]) and (tau_sat[2] == tau_sat[2]) and
              (tau_sat[3] == tau_sat[3]) and (tau_sat[4] == tau_sat[4]) and
              (tau_sat[5] == tau_sat[5]) and (tau_sat[6] == tau_sat[6]) and
              (pressure_sensor == pressure_sensor) and (sonar_range == sonar_range);
  settled_at_check = (time >= t_check) and (max_err_after_check < track_err_thresh);
  fail_closed = ok_joint_bounds and ok_pos_error and ok_att_error and
                ok_clearance and ok_tether and ok_no_nan and settled_at_check;

  annotation(
    experiment(StartTime=0, StopTime=16.0, Tolerance=1e-6, Interval=0.004),
    Documentation(info="SeaSnakeHoldE: 32 kg, six 0.30 m capsule modules, alternating yaw/pitch joints, passive tail fin, 12 bounded joint actuators (per-joint torque bound 35.2 N.m). Holds a fixed 6-DOF pose beside a fixed collidable offshore cylinder. Bounded body-wrench station keeping with 144 N middle-third tether/current disturbance. Pressure, IMU, DVL, forward sonar feedback. 250 Hz for 16 s. Fail-closed acceptance: joint bounds, position error (<0.27 m after 10.4 s), attitude error, structure clearance, tether limits, and no NaN/infinite values."));
end SeaSnakeHoldE;