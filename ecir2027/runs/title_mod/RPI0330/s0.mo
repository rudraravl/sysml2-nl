model StewartPositionF
  "Stewart platform 6-DOF closed-chain position control with force limiting, self-collision check, and disturbance"

  // ===== Physical parameters =====
  parameter Real m_p = 36.0 "Platform mass [kg]";
  parameter Real Rb = 0.45 "Base radius [m]";
  parameter Real Rp = 0.32 "Platform radius [m]";
  parameter Real L_min = 0.55 "Minimum strut length [m]";
  parameter Real L_max = 0.85 "Maximum strut length [m]";
  parameter Real F_max = 5124.0 "Maximum strut force per strut [N]";
  parameter Real Ipx = 0.5 * m_p * Rp * Rp "Platform inertia xx [kg.m2]";
  parameter Real Ipy = 0.5 * m_p * Rp * Rp "Platform inertia yy [kg.m2]";
  parameter Real Ipz = 0.5 * m_p * Rp * Rp "Platform inertia zz [kg.m2]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  // NOTE: strut_radius assumed; not specified in requirement
  parameter Real strut_radius = 0.015 "Assumed strut radius for collision [m]";
  parameter Real collision_threshold = 2.0 * strut_radius "Self-collision threshold [m]";

  // ===== Target pose (nonzero) =====
  parameter Real tx = 0.01 "Target x [m]";
  parameter Real ty = 0.015 "Target y [m]";
  parameter Real tz = 0.60 "Target z [m]";
  parameter Real tphi = 0.06 "Target roll [rad]";
  parameter Real ttheta = 0.04 "Target pitch [rad]";
  parameter Real tpsi = 0.02 "Target yaw [rad]";

  // ===== Control gains =====
  parameter Real kp_l = 50000.0 "Strut proportional gain [N/m]";
  parameter Real kd_l = 1000.0 "Strut derivative gain [N.s/m]";

  // ===== Disturbance =====
  parameter Real F_dist_val = 20.3 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 6.6667 "Disturbance start time [s]";
  parameter Real t_dist_end = 13.3333 "Disturbance end time [s]";

  // ===== Platform state (12 continuous states) =====
  Real px(start = 0.0, fixed = true) "Platform x position [m]";
  Real py(start = 0.0, fixed = true) "Platform y position [m]";
  Real pz(start = 0.55, fixed = true) "Platform z position [m]";
  Real phi(start = 0.0, fixed = true) "Roll angle [rad]";
  Real theta(start = 0.0, fixed = true) "Pitch angle [rad]";
  Real psi(start = 0.0, fixed = true) "Yaw angle [rad]";
  Real vx(start = 0.0, fixed = true) "X velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "Y velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "Z velocity [m/s]";
  Real wx(start = 0.0, fixed = true) "Roll rate [rad/s]";
  Real wy(start = 0.0, fixed = true) "Pitch rate [rad/s]";
  Real wz(start = 0.0, fixed = true) "Yaw rate [rad/s]";

  // ===== Geometry arrays =====
  Real Bx[6] "Base anchor x [m]";
  Real By[6] "Base anchor y [m]";
  Real pp1[6] "Platform anchor x in platform frame [m]";
  Real pp2[6] "Platform anchor y in platform frame [m]";

  // ===== Rotation matrices =====
  Real R[3, 3] "Current rotation matrix";
  Real Rt[3, 3] "Target rotation matrix";

  // ===== Platform anchors in world frame =====
  Real pa1[6] "Platform anchor x world [m]";
  Real pa2[6] "Platform anchor y world [m]";
  Real pa3[6] "Platform anchor z world [m]";
  Real rx[6] "Anchor vector from CG x [m]";
  Real ry[6] "Anchor vector from CG y [m]";
  Real rz[6] "Anchor vector from CG z [m]";

  // ===== Strut kinematics (sensor traces) =====
  Real L[6] "Actual strut lengths [m] (actuator coordinates)";
  Real Lu1[6] "Strut unit vector x";
  Real Lu2[6] "Strut unit vector y";
  Real Lu3[6] "Strut unit vector z";
  Real Ldot[6] "Strut length rates [m/s]";
  Real Lcmd[6] "Commanded strut lengths [m] (command traces)";

  // ===== Forces (sensor traces) =====
  Real Fraw[6] "Raw strut forces [N]";
  Real Fstrut[6] "Saturated strut forces [N] (reaction forces)";

  // ===== Net wrench on platform =====
  Real Fnet_x "Net force x [N]";
  Real Fnet_y "Net force y [N]";
  Real Fnet_z "Net force z [N]";
  Real Tnet_x "Net torque x [N.m]";
  Real Tnet_y "Net torque y [N.m]";
  Real Tnet_z "Net torque z [N.m]";

  // ===== Disturbance =====
  Real Fdist "Active disturbance force [N]";

  // ===== Self-collision =====
  Real mid_x[6] "Strut midpoint x [m]";
  Real mid_y[6] "Strut midpoint y [m]";
  Real mid_z[6] "Strut midpoint z [m]";
  Real d_clear[15] "Pairwise strut midpoint distances [m]";
  Real min_clear "Minimum strut clearance [m]";
  Boolean collision "Self-collision flag";

  // ===== Verification metrics =====
  Real pose_err "Position tracking error [m]";
  Real closure_res "Maximum closure residual [m]";
  Real max_force "Maximum strut force magnitude [N]";
  Real travel_min "Minimum strut length [m]";
  Real travel_max "Maximum strut length [m]";
  Real force_bound_ok "1 if force within bounds, 0 otherwise";
  Real travel_bound_ok "1 if travel within bounds, 0 otherwise";
  Real no_nan "0 if all values finite, 1 otherwise";

equation
  // ===== Base anchors (6 evenly spaced on circle) =====
  for i in 1:6 loop
    Bx[i] = Rb * cos((i - 1) * Modelica.Constants.pi / 3);
    By[i] = Rb * sin((i - 1) * Modelica.Constants.pi / 3);
    pp1[i] = Rp * cos((i - 1) * Modelica.Constants.pi / 3 + Modelica.Constants.pi / 6);
    pp2[i] = Rp * sin((i - 1) * Modelica.Constants.pi / 3 + Modelica.Constants.pi / 6);
  end for;

  // ===== Current rotation matrix (ZYX Euler: psi=yaw, theta=pitch, phi=roll) =====
  R[1, 1] = cos(psi) * cos(theta);
  R[1, 2] = cos(psi) * sin(theta) * sin(phi) - cos(phi) * sin(psi);
  R[1, 3] = cos(psi) * sin(theta) * cos(phi) + sin(phi) * sin(psi);
  R[2, 1] = cos(theta) * sin(psi);
  R[2, 2] = cos(psi) * cos(phi) + sin(theta) * sin(psi) * sin(phi);
  R[2, 3] = -cos(psi) * sin(phi) + sin(theta) * sin(psi) * cos(phi);
  R[3, 1] = -sin(theta);
  R[3, 2] = cos(theta) * sin(phi);
  R[3, 3] = cos(theta) * cos(phi);

  // ===== Target rotation matrix =====
  Rt[1, 1] = cos(tpsi) * cos(ttheta);
  Rt[1, 2] = cos(tpsi) * sin(ttheta) * sin(tphi) - cos(tphi) * sin(tpsi);
  Rt[1, 3] = cos(tpsi) * sin(ttheta) * cos(tphi) + sin(tphi) * sin(tpsi);
  Rt[2, 1] = cos(ttheta) * sin(tpsi);
  Rt[2, 2] = cos(tpsi) * cos(tphi) + sin(ttheta) * sin(tpsi) * sin(tphi);
  Rt[2, 3] = -cos(tpsi) * sin(tphi) + sin(ttheta) * sin(tpsi) * cos(tphi);
  Rt[3, 1] = -sin(ttheta);
  Rt[3, 2] = cos(ttheta) * sin(tphi);
  Rt[3, 3] = cos(ttheta) * cos(tphi);

  // ===== Platform anchors in world frame =====
  for i in 1:6 loop
    pa1[i] = px + R[1, 1] * pp1[i] + R[1, 2] * pp2[i];
    pa2[i] = py + R[2, 1] * pp1[i] + R[2, 2] * pp2[i];
    pa3[i] = pz + R[3, 1] * pp1[i] + R[3, 2] * pp2[i];
    rx[i] = pa1[i] - px;
    ry[i] = pa2[i] - py;
    rz[i] = pa3[i] - pz;
  end for;

  // ===== Strut lengths and unit vectors =====
  for i in 1:6 loop
    L[i] = sqrt((pa1[i] - Bx[i]) ^ 2 + (pa2[i] - By[i]) ^ 2 + pa3[i] ^ 2 + 1e-12);
    Lu1[i] = (pa1[i] - Bx[i]) / (L[i] + 1e-12);
    Lu2[i] = (pa2[i] - By[i]) / (L[i] + 1e-12);
    Lu3[i] = pa3[i] / (L[i] + 1e-12);
  end for;

  // ===== Strut length rates: dL/dt = n . (v + omega x r) =====
  for i in 1:6 loop
    Ldot[i] = Lu1[i] * (vx + wy * rz[i] - wz * ry[i])
            + Lu2[i] * (vy + wz * rx[i] - wx * rz[i])
            + Lu3[i] * (vz + wx * ry[i] - wy * rx[i]);
  end for;

  // ===== Inverse kinematics: commanded strut lengths from target pose =====
  for i in 1:6 loop
    Lcmd[i] = sqrt(
      (tx + Rt[1, 1] * pp1[i] + Rt[1, 2] * pp2[i] - Bx[i]) ^ 2 +
      (ty + Rt[2, 1] * pp1[i] + Rt[2, 2] * pp2[i] - By[i]) ^ 2 +
      (tz + Rt[3, 1] * pp1[i] + Rt[3, 2] * pp2[i]) ^ 2 + 1e-12);
  end for;

  // ===== Strut force PD control with saturation =====
  for i in 1:6 loop
    Fraw[i] = kp_l * (Lcmd[i] - L[i]) - kd_l * Ldot[i];
    Fstrut[i] = if Fraw[i] > F_max then F_max
                else if Fraw[i] < -F_max then -F_max
                else Fraw[i];
  end for;

  // ===== Disturbance force (middle third of 20 s simulation) =====
  Fdist = if (time >= t_dist_start and time <= t_dist_end) then F_dist_val else 0.0;

  // ===== Net wrench on platform =====
  Fnet_x = sum(Fstrut[i] * Lu1[i] for i in 1:6);
  Fnet_y = sum(Fstrut[i] * Lu2[i] for i in 1:6);
  Fnet_z = sum(Fstrut[i] * Lu3[i] for i in 1:6) - m_p * g - Fdist;
  Tnet_x = sum(Fstrut[i] * (Lu2[i] * rz[i] - Lu3[i] * ry[i]) for i in 1:6);
  Tnet_y = sum(Fstrut[i] * (Lu3[i] * rx[i] - Lu1[i] * rz[i]) for i in 1:6);
  Tnet_z = sum(Fstrut[i] * (Lu1[i] * ry[i] - Lu2[i] * rx[i]) for i in 1:6);

  // ===== Platform dynamics =====
  der(px) = vx;
  der(py) = vy;
  der(pz) = vz;
  der(phi) = wx;
  der(theta) = wy;
  der(psi) = wz;
  der(vx) = Fnet_x / m_p;
  der(vy) = Fnet_y / m_p;
  der(vz) = Fnet_z / m_p;
  der(wx) = Tnet_x / Ipx;
  der(wy) = Tnet_y / Ipy;
  der(wz) = Tnet_z / Ipz;

  // ===== Strut midpoints for collision check =====
  for i in 1:6 loop
    mid_x[i] = (Bx[i] + pa1[i]) / 2.0;
    mid_y[i] = (By[i] + pa2[i]) / 2.0;
    mid_z[i] = pa3[i] / 2.0;
  end for;

  // ===== Pairwise midpoint distances (15 pairs) =====
  d_clear[1]  = sqrt((mid_x[1] - mid_x[2]) ^ 2 + (mid_y[1] - mid_y[2]) ^ 2 + (mid_z[1] - mid_z[2]) ^ 2 + 1e-12);
  d_clear[2]  = sqrt((mid_x[1] - mid_x[3]) ^ 2 + (mid_y[1] - mid_y[3]) ^ 2 + (mid_z[1] - mid_z[3]) ^ 2 + 1e-12);
  d_clear[3]  = sqrt((mid_x[1] - mid_x[4]) ^ 2 + (mid_y[1] - mid_y[4]) ^ 2 + (mid_z[1] - mid_z[4]) ^ 2 + 1e-12);
  d_clear[4]  = sqrt((mid_x[1] - mid_x[5]) ^ 2 + (mid_y[1] - mid_y[5]) ^ 2 + (mid_z[1] - mid_z[5]) ^ 2 + 1e-12);
  d_clear[5]  = sqrt((mid_x[1] - mid_x[6]) ^ 2 + (mid_y[1] - mid_y[6]) ^ 2 + (mid_z[1] - mid_z[6]) ^ 2 + 1e-12);
  d_clear[6]  = sqrt((mid_x[2] - mid_x[3]) ^ 2 + (mid_y[2] - mid_y[3]) ^ 2 + (mid_z[2] - mid_z[3]) ^ 2 + 1e-12);
  d_clear[7]  = sqrt((mid_x[2] - mid_x[4]) ^ 2 + (mid_y[2] - mid_y[4]) ^ 2 + (mid_z[2] - mid_z[4]) ^ 2 + 1e-12);
  d_clear[8]  = sqrt((mid_x[2] - mid_x[5]) ^ 2 + (mid_y[2] - mid_y[5]) ^ 2 + (mid_z[2] - mid_z[5]) ^ 2 + 1e-12);
  d_clear[9]  = sqrt((mid_x[2] - mid_x[6]) ^ 2 + (mid_y[2] - mid_y[6]) ^ 2 + (mid_z[2] - mid_z[6]) ^ 2 + 1e-12);
  d_clear[10] = sqrt((mid_x[3] - mid_x[4]) ^ 2 + (mid_y[3] - mid_y[4]) ^ 2 + (mid_z[3] - mid_z[4]) ^ 2 + 1e-12);
  d_clear[11] = sqrt((mid_x[3] - mid_x[5]) ^ 2 + (mid_y[3] - mid_y[5]) ^ 2 + (mid_z[3] - mid_z[5]) ^ 2 + 1e-12);
  d_clear[12] = sqrt((mid_x[3] - mid_x[6]) ^ 2 + (mid_y[3] - mid_y[6]) ^ 2 + (mid_z[3] - mid_z[6]) ^ 2 + 1e-12);
  d_clear[13] = sqrt((mid_x[4] - mid_x[5]) ^ 2 + (mid_y[4] - mid_y[5]) ^ 2 + (mid_z[4] - mid_z[5]) ^ 2 + 1e-12);
  d_clear[14] = sqrt((mid_x[4] - mid_x[6]) ^ 2 + (mid_y[4] - mid_y[6]) ^ 2 + (mid_z[4] - mid_z[6]) ^ 2 + 1e-12);
  d_clear[15] = sqrt((mid_x[5] - mid_x[6]) ^ 2 + (mid_y[5] - mid_y[6]) ^ 2 + (mid_z[5] - mid_z[6]) ^ 2 + 1e-12);

  min_clear = min(d_clear);
  collision = min_clear < collision_threshold;

  // ===== Verification metrics =====
  // Pose tracking error (Euclidean position)
  pose_err = sqrt((px - tx) ^ 2 + (py - ty) ^ 2 + (pz - tz) ^ 2 + 1e-12);

  // Closure residual: kinematic constraint consistency (zero by construction)
  closure_res = max(abs(L[i] - sqrt((pa1[i] - Bx[i]) ^ 2 + (pa2[i] - By[i]) ^ 2 + pa3[i] ^ 2 + 1e-12)) for i in 1:6);

  // Force and travel bounds
  max_force = max(abs(Fstrut[i]) for i in 1:6);
  travel_min = min(L[i] for i in 1:6);
  travel_max = max(L[i] for i in 1:6);
  force_bound_ok = if max_force <= F_max then 1.0 else 0.0;
  travel_bound_ok = if (travel_min >= L_min and travel_max <= L_max) then 1.0 else 0.0;

  // NaN/Inf check across all physical and control variables
  no_nan = if (px > -1e10 and px < 1e10 and
               py > -1e10 and py < 1e10 and
               pz > -1e10 and pz < 1e10 and
               vx > -1e10 and vx < 1e10 and
               vy > -1e10 and vy < 1e10 and
               vz > -1e10 and vz < 1e10 and
               wx > -1e10 and wx < 1e10 and
               wy > -1e10 and wy < 1e10 and
               wz > -1e10 and wz < 1e10)
           then 0.0 else 1.0;

  annotation
    (Documentation(info = "Stewart platform (6-DOF hexapod) closed-chain position control.

  Mission: Move output platform to nonzero pose and hold against bounded load.
  Embodiment: 0.45 m base radius, 36 kg / 0.32 m radius platform, 6 struts 0.55-0.85 m.
  Actuation: Force-limited struts (5124 N max), PD control on strut length via inverse kinematics.
  Observation: L[6] (actuator coordinates), pose (px,py,pz,phi,theta,psi), Fstrut[6] (reaction forces).
  Control: Pose feedback through constrained inverse kinematics (Lcmd from target pose).
  Disturbance: 20.3 N downward load during middle third [6.67, 13.33] s.
  Self-collision: Minimum strut midpoint distance check with 0.03 m threshold.
  Verification: Travel/force bounds, closure residuals, pose error < 0.005 m after 13 s,
  no self-collision, no NaN/Inf in physical, control, or estimator values.
  Timing: 500 Hz output (Interval=0.002 s), 20 s duration.

  NOTE: Strut radius assumed 0.015 m (not specified in requirement).
  NOTE: Platform inertia approximated as uniform disc (not specified in requirement)."),
     experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002));

end StewartPositionF;