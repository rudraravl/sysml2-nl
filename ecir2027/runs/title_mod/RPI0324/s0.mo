model StewartTraceF
  "Stewart platform closed-chain mechanism: trace circle r=0.10m with IK control and closure stabilization"

  // ===== Physical Parameters =====
  parameter Modelica.Units.SI.Length Rb = 0.45 "Base anchor circle radius";
  parameter Modelica.Units.SI.Length Rp = 0.32 "Platform anchor circle radius";
  parameter Modelica.Units.SI.Mass m_plat = 36.0 "Moving platform mass";
  parameter Modelica.Units.SI.Inertia Ixx = 0.9216 "Platform inertia about x";
  parameter Modelica.Units.SI.Inertia Iyy = 0.9216 "Platform inertia about y";
  parameter Modelica.Units.SI.Inertia Izz = 1.8432 "Platform inertia about z";
  parameter Modelica.Units.SI.Length h0 = 0.68 "Nominal platform height above base plane";
  parameter Modelica.Units.SI.Length Lmin = 0.55 "Minimum strut length";
  parameter Modelica.Units.SI.Length Lmax = 0.85 "Maximum strut length";
  parameter Modelica.Units.SI.Force Fmax = 5124.0 "Maximum strut force magnitude per strut";
  parameter Modelica.Units.SI.Length rc = 0.10 "Circle trace radius";
  parameter Modelica.Units.SI.Length obstacle_x = 0.70 "Fixed obstacle center x-position";
  parameter Modelica.Units.SI.Length obstacle_y = 0.0 "Fixed obstacle center y-position";
  parameter Modelica.Units.SI.Length obstacle_r = 0.05 "Fixed obstacle radius";
  parameter Modelica.Units.SI.Length clearance_req = 0.02 "Required minimum clearance to obstacle";
  parameter Modelica.Units.SI.Force Fload = 14.5 "Output load disturbance magnitude";
  parameter Modelica.Units.SI.Time T_start_dist = 20.0/3.0 "Disturbance start time (middle third)";
  parameter Modelica.Units.SI.Time T_end_dist = 40.0/3.0 "Disturbance end time (middle third)";
  parameter Modelica.Units.SI.Acceleration g_acc = 9.81 "Gravitational acceleration";
  parameter Modelica.Units.SI.AngularVelocity omega_circ = 2.0*Modelica.Constants.pi/20.0 "Circle angular velocity";

  // Control gains
  parameter Real Kp_ik(unit="N/m") = 20000.0 "Inverse-kinematics proportional gain";
  parameter Real Kd_ik(unit="N.s/m") = 800.0 "Inverse-kinematics derivative gain";
  parameter Real Kp_closure(unit="N/m") = 3000.0 "Closure stabilization proportional gain";
  parameter Real Kd_closure(unit="N.s/m") = 200.0 "Closure stabilization derivative gain";

  // Anchor angular configuration (standard 6-6 Stewart platform)
  parameter Real ang_b[6] = {-15.0, 15.0, 105.0, 135.0, 225.0, 255.0} * Modelica.Constants.pi / 180.0 "Base anchor angles";
  parameter Real ang_p[6] = {30.0, 90.0, 150.0, 210.0, 270.0, 330.0} * Modelica.Constants.pi / 180.0 "Platform anchor angles";

  // Simulation settings
  parameter Modelica.Units.SI.Time dt = 0.002 "Control and sensor sample interval (500 Hz)";

  // ===== Platform State Variables =====
  Modelica.Units.SI.Length x(start=rc, fixed=true) "Platform center x-position";
  Modelica.Units.SI.Length y(start=0.0, fixed=true) "Platform center y-position";
  Modelica.Units.SI.Length z(start=h0, fixed=true) "Platform center z-position";
  Modelica.Units.SI.Velocity vx(start=0.0, fixed=true) "Platform x-velocity";
  Modelica.Units.SI.Velocity vy(start=0.0, fixed=true) "Platform y-velocity";
  Modelica.Units.SI.Velocity vz(start=0.0, fixed=true) "Platform z-velocity";
  Real phi(start=0.0, fixed=true, unit="rad") "Platform roll angle";
  Real theta(start=0.0, fixed=true, unit="rad") "Platform pitch angle";
  Real psi(start=0.0, fixed=true, unit="rad") "Platform yaw angle";
  Real wx(start=0.0, fixed=true, unit="rad/s") "Platform angular velocity x";
  Real wy(start=0.0, fixed=true, unit="rad/s") "Platform angular velocity y";
  Real wz(start=0.0, fixed=true, unit="rad/s") "Platform angular velocity z";

  // ===== Strut Variables (encoder and command traces) =====
  Modelica.Units.SI.Length L[6] "Actual strut lengths (encoder readings)";
  Modelica.Units.SI.Length Ld[6] "Desired strut lengths from inverse kinematics";
  Modelica.Units.SI.Velocity dL[6] "Actual strut length rates";
  Modelica.Units.SI.Velocity dLd[6] "Desired strut length rates";
  Modelica.Units.SI.Force Fc[6] "Commanded strut forces before limiting";
  Modelica.Units.SI.Force F[6] "Actual strut forces after limiting";

  // ===== Kinematic Variables =====
  Modelica.Units.SI.Length Bx[6] "Base anchor x-positions";
  Modelica.Units.SI.Length By[6] "Base anchor y-positions";
  Modelica.Units.SI.Length Pbx[6] "Platform anchor x-positions in body frame";
  Modelica.Units.SI.Length Pby[6] "Platform anchor y-positions in body frame";
  Modelica.Units.SI.Length Pwx[6] "Platform anchor x-positions in world frame";
  Modelica.Units.SI.Length Pwy[6] "Platform anchor y-positions in world frame";
  Modelica.Units.SI.Length Pwz[6] "Platform anchor z-positions in world frame";
  Modelica.Units.SI.Length rx[6] "Vector from platform center to anchor x-component";
  Modelica.Units.SI.Length ry[6] "Vector from platform center to anchor y-component";
  Modelica.Units.SI.Length rz[6] "Vector from platform center to anchor z-component";
  Real nx[6] "Strut unit vector x-component";
  Real ny[6] "Strut unit vector y-component";
  Real nz[6] "Strut unit vector z-component";
  Real R11 "Rotation matrix element (1,1)";
  Real R12 "Rotation matrix element (1,2)";
  Real R13 "Rotation matrix element (1,3)";
  Real R21 "Rotation matrix element (2,1)";
  Real R22 "Rotation matrix element (2,2)";
  Real R23 "Rotation matrix element (2,3)";
  Real R31 "Rotation matrix element (3,1)";
  Real R32 "Rotation matrix element (3,2)";
  Real R33 "Rotation matrix element (3,3)";

  // ===== Desired Trajectory =====
  Modelica.Units.SI.Length x_des "Desired platform x";
  Modelica.Units.SI.Length y_des "Desired platform y";
  Modelica.Units.SI.Length z_des "Desired platform z";

  // ===== Forces and Torques =====
  Modelica.Units.SI.Force Fx_tot "Total force on platform x";
  Modelica.Units.SI.Force Fy_tot "Total force on platform y";
  Modelica.Units.SI.Force Fz_tot "Total force on platform z";
  Modelica.Units.SI.Torque Tx_tot "Total torque on platform about x";
  Modelica.Units.SI.Torque Ty_tot "Total torque on platform about y";
  Modelica.Units.SI.Torque Tz_tot "Total torque on platform about z";
  Modelica.Units.SI.Force Fd_x "Disturbance force x-component";

  // ===== Metrics =====
  Modelica.Units.SI.Length path_error "Radial deviation from circle";
  Modelica.Units.SI.Length tracking_error "3D position tracking error";
  Modelica.Units.SI.Length closure_error "Joint-space closure error norm";
  Real singularity_margin "Minimum |nz| singularity proxy";
  Modelica.Units.SI.Length clearance "Minimum clearance to obstacle";

  // ===== Verification =====
  Boolean bounds_ok "Joint and effort bounds satisfied";
  Boolean tracking_ok "Tracking error below 0.006 m after 13 s";
  Boolean no_nan "No NaN or infinite values detected";
  Boolean clearance_ok "Clearance requirement satisfied";
  Real nan_check "Aggregated value for NaN/Inf detection";

equation
  // ===== Base and platform anchor positions =====
  for i in 1:6 loop
    Bx[i] = Rb * cos(ang_b[i]);
    By[i] = Rb * sin(ang_b[i]);
    Pbx[i] = Rp * cos(ang_p[i]);
    Pby[i] = Rp * sin(ang_p[i]);
  end for;

  // ===== Rotation matrix (small-angle ZYX Euler) =====
  R11 = 1.0;   R12 = -psi;   R13 = theta;
  R21 = psi;    R22 = 1.0;    R23 = -phi;
  R31 = -theta; R32 = phi;    R33 = 1.0;

  // ===== Platform anchors in world frame and strut kinematics =====
  for i in 1:6 loop
    Pwx[i] = x + R11*Pbx[i] + R12*Pby[i];
    Pwy[i] = y + R21*Pbx[i] + R22*Pby[i];
    Pwz[i] = z + R31*Pbx[i] + R32*Pby[i];
    rx[i] = Pwx[i] - x;
    ry[i] = Pwy[i] - y;
    rz[i] = Pwz[i] - z;
    L[i] = sqrt((Pwx[i] - Bx[i])^2 + (Pwy[i] - By[i])^2 + Pwz[i]^2);
    nx[i] = (Pwx[i] - Bx[i]) / L[i];
    ny[i] = (Pwy[i] - By[i]) / L[i];
    nz[i] = Pwz[i] / L[i];
  end for;

  // ===== Desired trajectory: circle in x-y plane at z = h0 =====
  x_des = rc * cos(omega_circ * time);
  y_des = rc * sin(omega_circ * time);
  z_des = h0;

  // ===== Inverse kinematics: desired strut lengths (desired rotation = identity) =====
  for i in 1:6 loop
    Ld[i] = sqrt((x_des + Pbx[i] - Bx[i])^2 + (y_des + Pby[i] - By[i])^2 + z_des^2);
  end for;

  // ===== Desired strut length rates =====
  for i in 1:6 loop
    dLd[i] = ((x_des + Pbx[i] - Bx[i]) * (-rc * omega_circ * sin(omega_circ * time))
            + (y_des + Pby[i] - By[i]) * (rc * omega_circ * cos(omega_circ * time))) / Ld[i];
  end for;

  // ===== Actual strut length rates (Jacobian: dL = n . (v + omega x r)) =====
  for i in 1:6 loop
    dL[i] = nx[i]*(vx + wy*rz[i] - wz*ry[i])
          + ny[i]*(vy + wz*rx[i] - wx*rz[i])
          + nz[i]*(vz + wx*ry[i] - wy*rx[i]);
  end for;

  // ===== Force control: gravity compensation + PD on strut length =====
  for i in 1:6 loop
    Fc[i] = m_plat * g_acc / 6.0 + Kp_ik * (Ld[i] - L[i]) + Kd_ik * (dLd[i] - dL[i]);
  end for;

  // ===== Force limiting (saturation to +/- Fmax) =====
  for i in 1:6 loop
    F[i] = if Fc[i] > Fmax then Fmax elseif Fc[i] < -Fmax then -Fmax else Fc[i];
  end for;

  // ===== Disturbance force (14.5 N in x during middle third) =====
  Fd_x = if time >= T_start_dist and time <= T_end_dist then Fload else 0.0;

  // ===== Total force on platform =====
  // Strut forces + disturbance + gravity + closure stabilization (PD on pose)
  Fx_tot = F[1]*nx[1] + F[2]*nx[2] + F[3]*nx[3] + F[4]*nx[4] + F[5]*nx[5] + F[6]*nx[6]
         + Fd_x + Kp_closure*(x_des - x) - Kd_closure*vx;
  Fy_tot = F[1]*ny[1] + F[2]*ny[2] + F[3]*ny[3] + F[4]*ny[4] + F[5]*ny[5] + F[6]*ny[6]
         + Kp_closure*(y_des - y) - Kd_closure*vy;
  Fz_tot = F[1]*nz[1] + F[2]*nz[2] + F[3]*nz[3] + F[4]*nz[4] + F[5]*nz[5] + F[6]*nz[6]
         - m_plat * g_acc + Kp_closure*(z_des - z) - Kd_closure*vz;

  // ===== Total torque on platform (about platform center) =====
  // T = sum(r[i] x (F[i]*n[i])) + closure stabilization torque
  Tx_tot = (ry[1]*nz[1] - rz[1]*ny[1])*F[1] + (ry[2]*nz[2] - rz[2]*ny[2])*F[2]
         + (ry[3]*nz[3] - rz[3]*ny[3])*F[3] + (ry[4]*nz[4] - rz[4]*ny[4])*F[4]
         + (ry[5]*nz[5] - rz[5]*ny[5])*F[5] + (ry[6]*nz[6] - rz[6]*ny[6])*F[6]
         - Kp_closure*phi - Kd_closure*wx;
  Ty_tot = (rz[1]*nx[1] - rx[1]*nz[1])*F[1] + (rz[2]*nx[2] - rx[2]*nz[2])*F[2]
         + (rz[3]*nx[3] - rx[3]*nz[3])*F[3] + (rz[4]*nx[4] - rx[4]*nz[4])*F[4]
         + (rz[5]*nx[5] - rx[5]*nz[5])*F[5] + (rz[6]*nx[6] - rx[6]*nz[6])*F[6]
         - Kp_closure*theta - Kd_closure*wy;
  Tz_tot = (rx[1]*ny[1] - ry[1]*nx[1])*F[1] + (rx[2]*ny[2] - ry[2]*nx[2])*F[2]
         + (rx[3]*ny[3] - ry[3]*nx[3])*F[3] + (rx[4]*ny[4] - ry[4]*nx[4])*F[4]
         + (rx[5]*ny[5] - ry[5]*nx[5])*F[5] + (rx[6]*ny[6] - ry[6]*nx[6])*F[6]
         - Kp_closure*psi - Kd_closure*wz;

  // ===== Platform dynamics (Newton-Euler, small-angle approximation) =====
  // Translational
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = Fx_tot / m_plat;
  der(vy) = Fy_tot / m_plat;
  der(vz) = Fz_tot / m_plat;
  // Rotational (small angle: omega approx Euler rates, Coriolis negligible)
  der(phi) = wx;
  der(theta) = wy;
  der(psi) = wz;
  der(wx) = Tx_tot / Ixx;
  der(wy) = Ty_tot / Iyy;
  der(wz) = Tz_tot / Izz;

  // ===== Metrics =====
  // Path error: radial deviation from circle of radius rc
  path_error = abs(sqrt(x*x + y*y) - rc);
  // Tracking error: 3D distance from desired position
  tracking_error = sqrt((x - x_des)^2 + (y - y_des)^2 + (z - z_des)^2);
  // Closure error: joint-space tracking error norm
  closure_error = sqrt((Ld[1]-L[1])^2 + (Ld[2]-L[2])^2 + (Ld[3]-L[3])^2
                     + (Ld[4]-L[4])^2 + (Ld[5]-L[5])^2 + (Ld[6]-L[6])^2);
  // Singularity margin: minimum |nz| (higher = struts more vertical = better force transmission)
  singularity_margin = min(abs(nz[1]), min(abs(nz[2]), min(abs(nz[3]),
                        min(abs(nz[4]), min(abs(nz[5]), abs(nz[6]))))));
  // Clearance: minimum distance from platform edge to obstacle edge
  clearance = sqrt((x - obstacle_x)^2 + (y - obstacle_y)^2) - Rp - obstacle_r;

  // ===== Verification =====
  // Joint and effort bounds
  bounds_ok = L[1] >= Lmin and L[1] <= Lmax and L[2] >= Lmin and L[2] <= Lmax
            and L[3] >= Lmin and L[3] <= Lmax and L[4] >= Lmin and L[4] <= Lmax
            and L[5] >= Lmin and L[5] <= Lmax and L[6] >= Lmin and L[6] <= Lmax
            and abs(F[1]) <= Fmax and abs(F[2]) <= Fmax and abs(F[3]) <= Fmax
            and abs(F[4]) <= Fmax and abs(F[5]) <= Fmax and abs(F[6]) <= Fmax;
  // Tracking: tracking error below 0.006 m after 13 s
  tracking_ok = if time >= 13.0 then tracking_error < 0.006 else true;
  // Clearance
  clearance_ok = clearance >= clearance_req;
  // NaN/Inf check: aggregated sum must be within finite bounds
  nan_check = x + y + z + vx + vy + vz + phi + theta + psi + wx + wy + wz
            + L[1] + L[2] + L[3] + L[4] + L[5] + L[6]
            + F[1] + F[2] + F[3] + F[4] + F[5] + F[6];
  no_nan = nan_check > -1e30 and nan_check < 1e30;

  annotation(
    Documentation(info="Stewart platform (6-UPS closed-chain) tracing a planar circle of radius 0.10 m.

      Embodiment: Fixed base radius 0.45 m, moving platform radius 0.32 m, mass 36 kg.
      Six variable-length struts (0.55-0.85 m), force limited to 5124 N per strut.

      Control: Inverse-kinematic trajectory control with PD gains on strut length error,
      plus closure stabilization (PD on platform pose). Gravity compensation feedforward.

      Disturbance: 14.5 N output load in x-direction during middle third (6.67-13.33 s).

      Obstacle: Fixed at (0.70, 0) m with radius 0.05 m, outside the trace circle.

      Verification: Joint/effort bounds, closure error, path error, singularity margin,
      clearance, tracking error < 0.006 m after 13 s, no NaN/Inf.

      Simulation: 500 Hz (dt=0.002 s), 20 s duration, synchronized state/command/sensor traces."),
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002));
end StewartTraceF;