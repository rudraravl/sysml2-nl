model StewartPositionB
  // ================================================================
  // StewartPositionB: Closed-chain Stewart platform mission
  // Move output platform to nonzero pose and hold against bounded load
  // ================================================================

  // --- Physical parameters ---
  parameter Real R_base(unit="m") = 0.45 "Base anchor circle radius";
  parameter Real R_plat(unit="m") = 0.32 "Platform anchor circle radius";
  parameter Real m_plat(unit="kg") = 36.0 "Platform mass";
  parameter Real L_min(unit="m") = 0.55 "Minimum strut length";
  parameter Real L_max(unit="m") = 0.85 "Maximum strut length";
  parameter Real F_max(unit="N") = 3444.0 "Maximum per-strut force command magnitude";
  parameter Real F_dist(unit="N") = 9.8 "Disturbance load magnitude";

  // --- Platform inertia (uniform disk approximation) ---
  parameter Real Ixx(unit="kg.m2") = 0.5 * m_plat * R_plat * R_plat;
  parameter Real Iyy(unit="kg.m2") = 0.5 * m_plat * R_plat * R_plat;
  parameter Real Izz(unit="kg.m2") = 0.5 * m_plat * R_plat * R_plat;

  // --- Mission timing ---
  parameter Real T_total(unit="s") = 10.0;
  parameter Real T_dist_start(unit="s") = T_total / 3.0;
  parameter Real T_dist_end(unit="s") = 2.0 * T_total / 3.0;

  // --- Target pose (nonzero) ---
  parameter Real x_d(unit="m") = 0.03 "Desired x position";
  parameter Real y_d(unit="m") = -0.02 "Desired y position";
  parameter Real z_d(unit="m") = 0.60 "Desired z position";
  parameter Real roll_d(unit="rad") = 0.0 "Desired roll";
  parameter Real pitch_d(unit="rad") = 0.0 "Desired pitch";
  parameter Real yaw_d(unit="rad") = 0.08 "Desired yaw";

  // --- Control gains ---
  parameter Real Kp_strut(unit="N/m") = 6000.0 "Strut length proportional gain";
  parameter Real Kd_strut(unit="N.s/m") = 350.0 "Strut length derivative gain";
  parameter Real c_trans(unit="N.s/m") = 80.0 "Translational damping coefficient";
  parameter Real c_rot(unit="N.m.s/rad") = 25.0 "Rotational damping coefficient";

  // --- Base anchor angles (rad) ---
  parameter Real theta_b[6] = {0.0,
                               Modelica.Constants.pi/3,
                               2.0*Modelica.Constants.pi/3,
                               Modelica.Constants.pi,
                               4.0*Modelica.Constants.pi/3,
                               5.0*Modelica.Constants.pi/3};

  // --- Platform anchor angles (rad, offset 30 deg) ---
  parameter Real phi_p[6] = {Modelica.Constants.pi/6,
                             Modelica.Constants.pi/2,
                             5.0*Modelica.Constants.pi/6,
                             7.0*Modelica.Constants.pi/6,
                             3.0*Modelica.Constants.pi/2,
                             11.0*Modelica.Constants.pi/6};

  // --- State variables (12 dynamic states) ---
  Real x(start=0.0, fixed=true, unit="m");
  Real y(start=0.0, fixed=true, unit="m");
  Real z(start=0.55, fixed=true, unit="m");
  Real vx(start=0.0, fixed=true, unit="m/s");
  Real vy(start=0.0, fixed=true, unit="m/s");
  Real vz(start=0.0, fixed=true, unit="m/s");
  Real roll(start=0.0, fixed=true, unit="rad");
  Real pitch(start=0.0, fixed=true, unit="rad");
  Real yaw(start=0.0, fixed=true, unit="rad");
  Real wx(start=0.0, fixed=true, unit="rad/s");
  Real wy(start=0.0, fixed=true, unit="rad/s");
  Real wz(start=0.0, fixed=true, unit="rad/s");

  // --- Base anchor positions (fixed in world) ---
  Real Bx[6], By[6], Bz[6];

  // --- Platform anchor local positions ---
  Real Pxl[6], Pyl[6], Pzl[6];

  // --- Rotation matrix elements (current) ---
  Real r11, r12, r13, r21, r22, r23, r31, r32, r33;

  // --- Rotation matrix elements (desired) ---
  Real rd11, rd12, rd13, rd21, rd22, rd23, rd31, rd32, rd33;

  // --- Platform anchor world positions (current) ---
  Real Px[6], Py[6], Pz[6];

  // --- Platform anchor world positions (desired) ---
  Real Pxd[6], Pyd[6], Pzd[6];

  // --- Strut geometry ---
  Real Sx[6], Sy[6], Sz[6] "Strut vector components";
  Real L[6] "Current strut lengths (actuator coordinates)";
  Real Lu[6], Lv[6], Lw[6] "Strut unit direction components";
  Real Ld[6] "Desired strut lengths (inverse kinematics)";

  // --- Anchor kinematics for dL/dt ---
  Real rx_a[6], ry_a[6], rz_a[6] "Anchor position relative to COM";
  Real vax[6], vay[6], vaz[6] "Anchor linear velocities";

  // --- Strut errors and force commands ---
  Real L_err[6] "Strut length errors";
  Real L_err_dot[6] "Strut length error rates";
  Real F_cmd[6] "Raw force commands";
  Real F_strut[6] "Saturated strut forces";

  // --- Platform wrench ---
  Real Fx_total, Fy_total, Fz_total;
  Real Tx_total, Ty_total, Tz_total;

  // --- Disturbance ---
  Real dist_active;
  Real F_dist_x, F_dist_y, F_dist_z;

  // --- Sensors ---
  Real pose_error(unit="m") "Position tracking error norm";
  Real pose_error_full(unit="m") "Full pose error (position + arc-equivalent orientation)";
  Real closure_residual[6] "Strut closure residuals";
  Real reaction_force[6] "Measured reaction force magnitudes";

  // --- Self-collision check ---
  Real Mx_mid[6], My_mid[6], Mz_mid[6] "Strut midpoints";
  Real d_adj[6] "Adjacent strut midpoint distances";
  Real min_clearance(unit="m") "Minimum inter-strut clearance";
  Boolean collision_flag "Self-collision flag";

  // --- Constraint checks ---
  Real force_violation "Count of struts exceeding force limit";
  Boolean force_in_bounds;
  Real travel_violation "Count of struts outside travel limits";
  Boolean travel_in_bounds;

  // --- Health metric ---
  Real state_norm "Aggregate state norm (NaN/Inf diagnostic)";

equation
  // ============ BASE GEOMETRY ============
  for i in 1:6 loop
    Bx[i] = R_base * cos(theta_b[i]);
    By[i] = R_base * sin(theta_b[i]);
    Bz[i] = 0.0;
  end for;

  // ============ PLATFORM LOCAL ANCHORS ============
  for i in 1:6 loop
    Pxl[i] = R_plat * cos(phi_p[i]);
    Pyl[i] = R_plat * sin(phi_p[i]);
    Pzl[i] = 0.0;
  end for;

  // ============ ROTATION MATRIX (ZYX: Rz*Ry*Rx) ============
  r11 = cos(yaw)*cos(pitch);
  r12 = cos(yaw)*sin(pitch)*sin(roll) - sin(yaw)*cos(roll);
  r13 = cos(yaw)*sin(pitch)*cos(roll) + sin(yaw)*sin(roll);
  r21 = sin(yaw)*cos(pitch);
  r22 = sin(yaw)*sin(pitch)*sin(roll) + cos(yaw)*cos(roll);
  r23 = sin(yaw)*sin(pitch)*cos(roll) - cos(yaw)*sin(roll);
  r31 = -sin(pitch);
  r32 = cos(pitch)*sin(roll);
  r33 = cos(pitch)*cos(roll);

  // ============ DESIRED ROTATION MATRIX ============
  rd11 = cos(yaw_d)*cos(pitch_d);
  rd12 = cos(yaw_d)*sin(pitch_d)*sin(roll_d) - sin(yaw_d)*cos(roll_d);
  rd13 = cos(yaw_d)*sin(pitch_d)*cos(roll_d) + sin(yaw_d)*sin(roll_d);
  rd21 = sin(yaw_d)*cos(pitch_d);
  rd22 = sin(yaw_d)*sin(pitch_d)*sin(roll_d) + cos(yaw_d)*cos(roll_d);
  rd23 = sin(yaw_d)*sin(pitch_d)*cos(roll_d) - cos(yaw_d)*sin(roll_d);
  rd31 = -sin(pitch_d);
  rd32 = cos(pitch_d)*sin(roll_d);
  rd33 = cos(pitch_d)*cos(roll_d);

  // ============ PLATFORM ANCHOR WORLD POSITIONS (CURRENT) ============
  for i in 1:6 loop
    Px[i] = x + r11*Pxl[i] + r12*Pyl[i] + r13*Pzl[i];
    Py[i] = y + r21*Pxl[i] + r22*Pyl[i] + r23*Pzl[i];
    Pz[i] = z + r31*Pxl[i] + r32*Pyl[i] + r33*Pzl[i];
  end for;

  // ============ PLATFORM ANCHOR WORLD POSITIONS (DESIRED) ============
  for i in 1:6 loop
    Pxd[i] = x_d + rd11*Pxl[i] + rd12*Pyl[i] + rd13*Pzl[i];
    Pyd[i] = y_d + rd21*Pxl[i] + rd22*Pyl[i] + rd23*Pzl[i];
    Pzd[i] = z_d + rd31*Pxl[i] + rd32*Pyl[i] + rd33*Pzl[i];
  end for;

  // ============ STRUT VECTORS, LENGTHS, UNIT VECTORS ============
  for i in 1:6 loop
    Sx[i] = Px[i] - Bx[i];
    Sy[i] = Py[i] - By[i];
    Sz[i] = Pz[i] - Bz[i];
    L[i] = sqrt(Sx[i]*Sx[i] + Sy[i]*Sy[i] + Sz[i]*Sz[i] + 1e-12);
    Lu[i] = Sx[i] / L[i];
    Lv[i] = Sy[i] / L[i];
    Lw[i] = Sz[i] / L[i];
  end for;

  // ============ DESIRED STRUT LENGTHS (INVERSE KINEMATICS) ============
  for i in 1:6 loop
    Ld[i] = sqrt((Pxd[i]-Bx[i])*(Pxd[i]-Bx[i]) +
                 (Pyd[i]-By[i])*(Pyd[i]-By[i]) +
                 (Pzd[i]-Bz[i])*(Pzd[i]-Bz[i]) + 1e-12);
  end for;

  // ============ ANCHOR RELATIVE POSITIONS ============
  for i in 1:6 loop
    rx_a[i] = Px[i] - x;
    ry_a[i] = Py[i] - y;
    rz_a[i] = Pz[i] - z;
  end for;

  // ============ ANCHOR VELOCITIES (v_com + omega x r) ============
  for i in 1:6 loop
    vax[i] = vx + wy*rz_a[i] - wz*ry_a[i];
    vay[i] = vy + wz*rx_a[i] - wx*rz_a[i];
    vaz[i] = vz + wx*ry_a[i] - wy*rx_a[i];
  end for;

  // ============ STRUT LENGTH ERRORS AND DERIVATIVES ============
  for i in 1:6 loop
    L_err[i] = Ld[i] - L[i];
    L_err_dot[i] = -(Lu[i]*vax[i] + Lv[i]*vay[i] + Lw[i]*vaz[i]);
  end for;

  // ============ FORCE COMMANDS (PD ON STRUT LENGTH) ============
  for i in 1:6 loop
    F_cmd[i] = Kp_strut * L_err[i] + Kd_strut * L_err_dot[i];
  end for;

  // ============ FORCE SATURATION (3444 N per strut) ============
  for i in 1:6 loop
    F_strut[i] = if F_cmd[i] > F_max then F_max
                 elseif F_cmd[i] < -F_max then -F_max
                 else F_cmd[i];
  end for;

  // ============ DISTURBANCE (MIDDLE THIRD: 3.33 - 6.67 s) ============
  dist_active = if time >= T_dist_start and time <= T_dist_end then 1.0 else 0.0;
  F_dist_x = 0.0;
  F_dist_y = 0.0;
  F_dist_z = -F_dist * dist_active;

  // ============ PLATFORM WRENCH FROM STRUT FORCES ============
  Fx_total = sum(F_strut[i] * Lu[i] for i in 1:6) + F_dist_x;
  Fy_total = sum(F_strut[i] * Lv[i] for i in 1:6) + F_dist_y;
  Fz_total = sum(F_strut[i] * Lw[i] for i in 1:6) + F_dist_z;

  // Torques: tau = sum(r_i x F_i) about COM
  Tx_total = sum((ry_a[i]*Lw[i] - rz_a[i]*Lv[i]) * F_strut[i] for i in 1:6);
  Ty_total = sum((rz_a[i]*Lu[i] - rx_a[i]*Lw[i]) * F_strut[i] for i in 1:6);
  Tz_total = sum((rx_a[i]*Lv[i] - ry_a[i]*Lu[i]) * F_strut[i] for i in 1:6);

  // ============ DYNAMICS (NEWTON-EULER) ============
  // Translational kinematics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  // Translational dynamics
  m_plat * der(vx) = Fx_total - c_trans * vx;
  m_plat * der(vy) = Fy_total - c_trans * vy;
  m_plat * der(vz) = Fz_total - c_trans * vz;

  // Rotational kinematics
  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;

  // Rotational dynamics (diagonal inertia, no gyroscopic coupling)
  Ixx * der(wx) = Tx_total - c_rot * wx;
  Iyy * der(wy) = Ty_total - c_rot * wy;
  Izz * der(wz) = Tz_total - c_rot * wz;

  // ============ SENSORS ============
  // Position tracking error norm
  pose_error = sqrt((x - x_d)*(x - x_d) + (y - y_d)*(y - y_d) +
                    (z - z_d)*(z - z_d) + 1e-12);

  // Full pose error (position + arc-equivalent orientation errors)
  pose_error_full = sqrt((x - x_d)*(x - x_d) + (y - y_d)*(y - y_d) +
                         (z - z_d)*(z - z_d) +
                         (R_plat*(roll - roll_d))*(R_plat*(roll - roll_d)) +
                         (R_plat*(pitch - pitch_d))*(R_plat*(pitch - pitch_d)) +
                         (R_plat*(yaw - yaw_d))*(R_plat*(yaw - yaw_d)) +
                         1e-12);

  // Closure residuals (geometric consistency, always ~0 by construction)
  for i in 1:6 loop
    closure_residual[i] = L[i] - sqrt((Px[i]-Bx[i])*(Px[i]-Bx[i]) +
                                     (Py[i]-By[i])*(Py[i]-By[i]) +
                                     (Pz[i]-Bz[i])*(Pz[i]-Bz[i]) + 1e-12);
  end for;

  // Reaction force magnitudes
  for i in 1:6 loop
    reaction_force[i] = abs(F_strut[i]);
  end for;

  // ============ SELF-COLLISION CHECK ============
  // Strut midpoints
  for i in 1:6 loop
    Mx_mid[i] = (Px[i] + Bx[i]) / 2.0;
    My_mid[i] = (Py[i] + By[i]) / 2.0;
    Mz_mid[i] = (Pz[i] + Bz[i]) / 2.0;
  end for;

  // Adjacent strut midpoint distances (6 adjacent pairs)
  d_adj[1] = sqrt((Mx_mid[1]-Mx_mid[2])*(Mx_mid[1]-Mx_mid[2]) +
                  (My_mid[1]-My_mid[2])*(My_mid[1]-My_mid[2]) +
                  (Mz_mid[1]-Mz_mid[2])*(Mz_mid[1]-Mz_mid[2]) + 1e-12);
  d_adj[2] = sqrt((Mx_mid[2]-Mx_mid[3])*(Mx_mid[2]-Mx_mid[3]) +
                  (My_mid[2]-My_mid[3])*(My_mid[2]-My_mid[3]) +
                  (Mz_mid[2]-Mz_mid[3])*(Mz_mid[2]-Mz_mid[3]) + 1e-12);
  d_adj[3] = sqrt((Mx_mid[3]-Mx_mid[4])*(Mx_mid[3]-Mx_mid[4]) +
                  (My_mid[3]-My_mid[4])*(My_mid[3]-My_mid[4]) +
                  (Mz_mid[3]-Mz_mid[4])*(Mz_mid[3]-Mz_mid[4]) + 1e-12);
  d_adj[4] = sqrt((Mx_mid[4]-Mx_mid[5])*(Mx_mid[4]-Mx_mid[5]) +
                  (My_mid[4]-My_mid[5])*(My_mid[4]-My_mid[5]) +
                  (Mz_mid[4]-Mz_mid[5])*(Mz_mid[4]-Mz_mid[5]) + 1e-12);
  d_adj[5] = sqrt((Mx_mid[5]-Mx_mid[6])*(Mx_mid[5]-Mx_mid[6]) +
                  (My_mid[5]-My_mid[6])*(My_mid[5]-My_mid[6]) +
                  (Mz_mid[5]-Mz_mid[6])*(Mz_mid[5]-Mz_mid[6]) + 1e-12);
  d_adj[6] = sqrt((Mx_mid[6]-Mx_mid[1])*(Mx_mid[6]-Mx_mid[1]) +
                  (My_mid[6]-My_mid[1])*(My_mid[6]-My_mid[1]) +
                  (Mz_mid[6]-Mz_mid[1])*(Mz_mid[6]-Mz_mid[1]) + 1e-12);

  min_clearance = min(d_adj);
  collision_flag = min_clearance < 0.02;

  // ============ CONSTRAINT CHECKS ============
  // Force bound check
  force_violation = sum((if abs(F_strut[i]) > F_max + 1.0 then 1.0 else 0.0) for i in 1:6);
  force_in_bounds = force_violation < 0.5;

  // Travel bound check
  travel_violation = sum((if (L[i] < L_min - 0.001 or L[i] > L_max + 0.001) then 1.0 else 0.0) for i in 1:6);
  travel_in_bounds = travel_violation < 0.5;

  // ============ HEALTH METRIC ============
  state_norm = sqrt(x*x + y*y + z*z + vx*vx + vy*vy + vz*vz +
                    roll*roll + pitch*pitch + yaw*yaw +
                    wx*wx + wy*wy + wz*wz + 1e-12);

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="StewartPositionB: 6-DOF Stewart platform closed-chain mission.
      Base radius 0.45 m, platform radius 0.32 m, mass 36 kg.
      Six variable-length struts (0.55-0.85 m), force-limited at 3444 N/strut.
      Control: pose feedback via constrained inverse kinematics (PD on strut length).
      Disturbance: 9.8 N downward during middle third (3.33-6.67 s).
      Output rate 100 Hz (Interval=0.01), duration 10 s.
      Requirement: tracking error < 0.007 m after 6.5 s, no self-collision,
      all forces and travel in bounds, no NaN/Inf.")
  );
end StewartPositionB;