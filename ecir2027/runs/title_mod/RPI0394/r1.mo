model CartesianToolInsertD
  "Instrumented contact-rich peg-in-hole insertion with Cartesian impedance control"

  // ===== Physical parameters =====
  parameter Real m_tool(unit = "kg") = 2.5 "Tool carriage mass";
  parameter Real x_travel(unit = "m") = 0.10 "X travel half-range";
  parameter Real y_travel(unit = "m") = 0.10 "Y travel half-range";
  parameter Real z_travel(unit = "m") = 0.30 "Z travel range";
  parameter Real F_act_max(unit = "N") = 350.0 "Per-axis actuator force limit";
  parameter Real clearance_radial(unit = "m") = 0.001 "Hole radial clearance (1 mm)";
  parameter Real insert_target(unit = "m") = 0.06 "Required insertion depth";
  parameter Real mu_contact = 0.35 "Contact friction coefficient";
  parameter Real k_contact(unit = "N/m") = 3.0e6 "Rigid contact stiffness";
  parameter Real d_contact(unit = "N.s/m") = 3000.0 "Rigid contact damping";
  parameter Real peg_length(unit = "m") = 0.08 "Peg length for tilt estimation";
  parameter Real k_stop(unit = "N/m") = 1.0e7 "Travel-limit stop stiffness";
  parameter Real d_stop(unit = "N.s/m") = 5000.0 "Travel-limit stop damping";

  // ===== Control parameters =====
  parameter Real K_imp(unit = "N/m") = 8000.0 "Impedance stiffness";
  parameter Real D_imp(unit = "N.s/m") = 120.0 "Impedance damping";
  parameter Real v_insert_max(unit = "m/s") = 0.015 "Bounded insertion speed";
  parameter Real F_lateral_limit(unit = "N") = 50.0 "Lateral force soft limit";
  parameter Real F_axial_limit(unit = "N") = 100.0 "Axial force soft limit";
  parameter Real tilt_limit(unit = "rad") = 0.05 "Peg tilt soft limit";

  // ===== Timing and disturbance =====
  parameter Real T_total(unit = "s") = 14.0 "Total run time";
  parameter Real T_align(unit = "s") = 3.0 "Alignment phase duration";
  parameter Real T_dist_start(unit = "s") = T_total / 3.0 "Disturbance start (middle third)";
  parameter Real T_dist_end(unit = "s") = 2.0 * T_total / 3.0 "Disturbance end (middle third)";
  parameter Real F_disturbance(unit = "N") = 10.0 "Lateral fixture load disturbance";
  parameter Real dt_ctrl(unit = "s") = 0.005 "Control sample period (200 Hz)";

  // ===== Dynamic states =====
  Real x(start = 0.05, unit = "m") "Carriage X position";
  Real y(start = 0.03, unit = "m") "Carriage Y position";
  Real z(start = 0.0, unit = "m") "Carriage Z position (negative = inserted)";
  Real vx(start = 0.0, unit = "m/s") "X velocity";
  Real vy(start = 0.0, unit = "m/s") "Y velocity";
  Real vz(start = 0.0, unit = "m/s") "Z velocity";

  // ===== Reference commands =====
  Real x_cmd(unit = "m") "X position command";
  Real y_cmd(unit = "m") "Y position command";
  Real z_cmd(unit = "m") "Z position command";
  Real vx_cmd(unit = "m/s") "X velocity command";
  Real vy_cmd(unit = "m/s") "Y velocity command";
  Real vz_cmd(unit = "m/s") "Z velocity command";

  // ===== Control forces =====
  Real Fx_raw(unit = "N") "Unsaturated impedance force X";
  Real Fy_raw(unit = "N") "Unsaturated impedance force Y";
  Real Fz_raw(unit = "N") "Unsaturated impedance force Z";
  Real Fx_act(unit = "N") "Saturated actuator force X";
  Real Fy_act(unit = "N") "Saturated actuator force Y";
  Real Fz_act(unit = "N") "Saturated actuator force Z";

  // ===== Contact model =====
  Real r_lateral(unit = "m") "Lateral radial distance from hole center";
  Real penetration(unit = "m") "Radial penetration into hole wall";
  Real penetration_rate(unit = "m/s") "Radial penetration rate";
  Real in_contact "Contact indicator (0 or 1)";
  Real F_contact_mag(unit = "N") "Normal contact force magnitude";
  Real Fc_x(unit = "N") "Contact force X";
  Real Fc_y(unit = "N") "Contact force Y";
  Real Fc_z(unit = "N") "Contact force Z (friction + bottom stop)";
  Real F_bottom(unit = "N") "Bottom-of-hole contact force";
  Real F_stop_x(unit = "N") "X travel-limit stop force";
  Real F_stop_y(unit = "N") "Y travel-limit stop force";
  Real F_stop_z(unit = "N") "Z travel-limit stop force";
  Real F_dist(unit = "N") "Lateral disturbance force";

  // ===== Six-axis wrench measurement =====
  Real wrench_fx(unit = "N") "Measured force X";
  Real wrench_fy(unit = "N") "Measured force Y";
  Real wrench_fz(unit = "N") "Measured force Z";
  Real wrench_tx(unit = "N.m") "Measured torque about X";
  Real wrench_ty(unit = "N.m") "Measured torque about Y";
  Real wrench_tz(unit = "N.m") "Measured torque about Z";

  // ===== Metrics and diagnostics =====
  Real phase "Phase indicator (0=align, 1=insert, 2=hold)";
  Real alignment_error(unit = "m") "Lateral alignment error";
  Real insertion_depth(unit = "m") "Current insertion depth";
  Real peg_tilt(unit = "rad") "Estimated peg tilt angle";
  Real F_lateral_mag(unit = "N") "Lateral force magnitude";
  Real F_axial_mag(unit = "N") "Axial force magnitude";
  Real tracking_error(unit = "m") "Primary tracking error";
  Real alignment_satisfied "1 if alignment error below 0.002 m after 9.1 s";

equation

  // ===== Phase determination =====
  phase = if time < T_align then 0.0
          else if time < T_align + insert_target / v_insert_max then 1.0
          else 2.0;

  // ===== Reference trajectory =====
  // Lateral: smooth ramp from initial offset to hole center (0,0)
  x_cmd = if time < T_align then 0.05 * (1.0 - time / T_align) else 0.0;
  y_cmd = if time < T_align then 0.03 * (1.0 - time / T_align) else 0.0;
  vx_cmd = if time < T_align then -0.05 / T_align else 0.0;
  vy_cmd = if time < T_align then -0.03 / T_align else 0.0;

  // Axial: bounded-speed insertion after alignment phase
  z_cmd = if time < T_align then 0.0
          else if time < T_align + insert_target / v_insert_max then
            -v_insert_max * (time - T_align)
          else -insert_target;
  vz_cmd = if time >= T_align and time < T_align + insert_target / v_insert_max
           then -v_insert_max else 0.0;

  // ===== Disturbance (middle third of total run) =====
  F_dist = if time >= T_dist_start and time <= T_dist_end then F_disturbance else 0.0;

  // ===== Cartesian impedance control =====
  Fx_raw = K_imp * (x_cmd - x) + D_imp * (vx_cmd - vx);
  Fy_raw = K_imp * (y_cmd - y) + D_imp * (vy_cmd - vy);
  Fz_raw = K_imp * (z_cmd - z) + D_imp * (vz_cmd - vz);

  // Actuator force saturation (per-axis limit)
  Fx_act = max(-F_act_max, min(F_act_max, Fx_raw));
  Fy_act = max(-F_act_max, min(F_act_max, Fy_raw));
  Fz_act = max(-F_act_max, min(F_act_max, Fz_raw));

  // ===== Contact model (rigid collision with compliance) =====
  r_lateral = sqrt(x * x + y * y);
  penetration = max(0.0, r_lateral - clearance_radial);
  penetration_rate = if r_lateral > 1.0e-6 then (x * vx + y * vy) / r_lateral else 0.0;

  // Contact active when peg is below surface and penetrating wall
  in_contact = if z < 0.0 and penetration > 0.0 then 1.0 else 0.0;

  // Normal contact force (Hunt-Crossley, non-negative)
  F_contact_mag = in_contact * max(0.0, k_contact * penetration + d_contact * penetration_rate);

  // Contact force directed toward hole center
  Fc_x = if r_lateral > 1.0e-6 then -F_contact_mag * x / r_lateral else 0.0;
  Fc_y = if r_lateral > 1.0e-6 then -F_contact_mag * y / r_lateral else 0.0;

  // Friction along insertion axis (opposes vz, smooth tanh to avoid discontinuity)
  Fc_z = -mu_contact * F_contact_mag * tanh(vz / 0.001);

  // Bottom-of-hole contact (hole depth exceeds insert_target, safety only)
  F_bottom = if z < -(insert_target + 0.02) then
               k_stop * (-(insert_target + 0.02) - z) - d_stop * min(0.0, vz)
             else 0.0;
  Fc_z = Fc_z + F_bottom;

  // ===== Travel-limit stop forces =====
  // X limits at +/- x_travel
  F_stop_x = if x > x_travel then
               -k_stop * (x - x_travel) - d_stop * max(0.0, vx)
             else if x < -x_travel then
               -k_stop * (x + x_travel) - d_stop * min(0.0, vx)
             else 0.0;

  // Y limits at +/- y_travel
  F_stop_y = if y > y_travel then
               -k_stop * (y - y_travel) - d_stop * max(0.0, vy)
             else if y < -y_travel then
               -k_stop * (y + y_travel) - d_stop * min(0.0, vy)
             else 0.0;

  // Z limits at 0 (top) and -z_travel (bottom)
  F_stop_z = if z > 0.0 then
               -k_stop * z - d_stop * max(0.0, vz)
             else if z < -z_travel then
               -k_stop * (z + z_travel) - d_stop * min(0.0, vz)
             else 0.0;

  // ===== Plant dynamics (Newton's second law) =====
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (Fx_act + Fc_x + F_dist + F_stop_x) / m_tool;
  der(vy) = (Fy_act + Fc_y + F_stop_y) / m_tool;
  der(vz) = (Fz_act + Fc_z + F_stop_z) / m_tool;

  // ===== Six-axis contact wrench measurement =====
  wrench_fx = Fc_x + F_dist;
  wrench_fy = Fc_y;
  wrench_fz = Fc_z;
  wrench_tx = -wrench_fz * peg_length * 0.5;
  wrench_ty = wrench_fz * peg_length * 0.5;
  wrench_tz = (x * wrench_fy - y * wrench_fx) * 0.5;

  // ===== Metrics =====
  alignment_error = r_lateral;
  insertion_depth = max(0.0, -z);
  F_lateral_mag = sqrt(wrench_fx * wrench_fx + wrench_fy * wrench_fy);
  F_axial_mag = abs(wrench_fz);
  peg_tilt = atan2(r_lateral, max(peg_length, 1.0e-6));
  tracking_error = sqrt((x_cmd - x) * (x_cmd - x) + (y_cmd - y) * (y_cmd - y) + (z_cmd - z) * (z_cmd - z));

  // Requirement check: alignment error below 0.002 m after 9.1 s
  alignment_satisfied = if time >= 9.1 then
                          if alignment_error < 0.002 then 1.0 else 0.0
                        else 1.0;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "CartesianToolInsertD: Three-axis prismatic peg-in-hole insertion.
      Parameters: m_tool=2.5 kg, travel +/-0.10 m (X,Y), 0.30 m (Z), F_act=350 N/axis,
      clearance=1 mm, insert target=0.06 m, friction=0.35, disturbance=10 N lateral,
      middle third [4.667, 9.333] s, 200 Hz, 14 s total.
      Peg length, hole depth beyond insert target, and chamfer geometry are unknown
      and not modeled."));
end CartesianToolInsertD;