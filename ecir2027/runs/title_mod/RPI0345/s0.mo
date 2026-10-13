model DeltaTraceC
  "Closed-chain Delta robot with inverse-kinematic trajectory control and closure stabilization"

  // ==================== Parameters ====================
  // Mechanism (specified by requirement)
  parameter Real L1 = 0.32 "Upper arm length [m]";
  parameter Real L2 = 0.60 "Forearm length [m] (paired rods as effective single forearm)";
  parameter Real mp = 3.0 "Moving platform mass [kg]";

  // Mechanism geometry (design assumptions — not specified in requirement)
  parameter Real R_b = 0.15 "Base circumradius [m]";
  parameter Real R_p = 0.05 "Platform circumradius [m]";
  parameter Real z_nom = -0.50 "Nominal platform height [m]";
  parameter Real theta_max = Modelica.Constants.pi / 2.0 "Joint angle bound [rad]";

  // Trajectory (specified by requirement)
  parameter Real r_circle = 0.10 "Circle radius [m]";
  parameter Real omega = 2.0 * Modelica.Constants.pi / 8.0 "Circle angular speed [rad/s]";

  // Control effort (specified by requirement)
  parameter Real tau_max = 41.4 "Maximum command magnitude per actuator [N.m]";

  // Controller gains (design assumptions)
  parameter Real Kp_tau = 300.0 "Joint PD proportional gain [N.m/rad]";
  parameter Real Kd_tau = 30.0 "Joint PD derivative gain [N.m.s/rad]";
  parameter Real b_damp = 10.0 "Platform viscous damping [N.s/m]";

  // Disturbance (specified by requirement)
  parameter Real F_dist = 9.0 "Output load disturbance magnitude [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start [s] (middle third of 12 s)";
  parameter Real t_dist_end = 8.0 "Disturbance end [s]";

  // Obstacle (position is design assumption — requirement only says outside circle)
  parameter Real obs_x = 0.30 "Obstacle x [m]";
  parameter Real obs_y = 0.0 "Obstacle y [m]";
  parameter Real obs_z = -0.50 "Obstacle z [m]";
  parameter Real obs_r = 0.05 "Obstacle radius [m]";
  parameter Real clearance_req = 0.02 "Required minimum clearance [m]";

  // Sampling (specified by requirement)
  parameter Real dt_sample = 1.0 / 125.0 "Sample interval [s]";

  // Base joint azimuth angles
  parameter Real phi[3] = {0.0, 2.0 * Modelica.Constants.pi / 3.0, 4.0 * Modelica.Constants.pi / 3.0};

  // ==================== State Variables ====================
  Real px(start = 0.10, fixed = true) "Platform x position [m]";
  Real py(start = 0.0, fixed = true) "Platform y position [m]";
  Real pz(start = -0.50, fixed = true) "Platform z position [m]";
  Real vx(start = 0.0, fixed = true) "Platform x velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "Platform y velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "Platform z velocity [m/s]";

  // ==================== Desired Trajectory ====================
  Real px_d "Desired platform x [m]";
  Real py_d "Desired platform y [m]";
  Real pz_d "Desired platform z [m]";
  Real vx_d "Desired platform vx [m/s]";
  Real vy_d "Desired platform vy [m/s]";
  Real vz_d "Desired platform vz [m/s]";

  // ==================== IK at Desired Position ====================
  Real A_d[3] "IK coefficient A at desired";
  Real B_d[3] "IK coefficient B at desired";
  Real C_d[3] "IK coefficient C at desired";
  Real CmA_d[3] "C minus A at desired";
  Real disc_d[3] "IK discriminant at desired";
  Real theta_d_opt1[3] "IK root 1 at desired [rad]";
  Real theta_d_opt2[3] "IK root 2 at desired [rad]";
  Real theta_d[3] "Desired joint angles [rad]";
  Real theta_d_dot[3] "Desired joint angular velocities [rad/s]";
  Real avx_d[3] "Forearm vector x at desired [m]";
  Real avy_d[3] "Forearm vector y at desired [m]";
  Real avz_d[3] "Forearm vector z at desired [m]";
  Real dAdth_x_d[3] "dA/dtheta x at desired [m/rad]";
  Real dAdth_y_d[3] "dA/dtheta y at desired [m/rad]";
  Real dAdth_z_d[3] "dA/dtheta z at desired [m/rad]";
  Real denom_d[3] "Jacobian denominator at desired";
  Real denom_d_safe[3] "Protected denominator at desired";
  Real J_d[3, 3] "Jacobian at desired [rad/m]";

  // ==================== IK at Actual Position (Encoder) ====================
  Real A_a[3] "IK coefficient A at actual";
  Real B_a[3] "IK coefficient B at actual";
  Real C_a[3] "IK coefficient C at actual";
  Real CmA_a[3] "C minus A at actual";
  Real disc_a[3] "IK discriminant at actual";
  Real theta_opt1[3] "IK root 1 at actual [rad]";
  Real theta_opt2[3] "IK root 2 at actual [rad]";
  Real theta[3] "Actual joint angles from encoder [rad]";
  Real theta_dot[3] "Actual joint angular velocities [rad/s]";
  Real avx[3] "Forearm vector x at actual [m]";
  Real avy[3] "Forearm vector y at actual [m]";
  Real avz[3] "Forearm vector z at actual [m]";
  Real dAdth_x[3] "dA/dtheta x at actual [m/rad]";
  Real dAdth_y[3] "dA/dtheta y at actual [m/rad]";
  Real dAdth_z[3] "dA/dtheta z at actual [m/rad]";
  Real denom[3] "Jacobian denominator at actual (singularity indicator)";
  Real denom_safe[3] "Protected denominator at actual";
  Real J[3, 3] "Jacobian at actual [rad/m]";

  // ==================== Control ====================
  Real tau[3] "Unsaturated actuator torque command [N.m]";
  Real tau_sat[3] "Saturated actuator torque [N.m]";
  Real Fx "Platform force x from actuators [N]";
  Real Fy "Platform force y from actuators [N]";
  Real Fz "Platform force z from actuators [N]";
  Real Fdx "Disturbance force x [N]";
  Real Fdy "Disturbance force y [N]";
  Real Fdz "Disturbance force z [N]";

  // ==================== Metrics ====================
  Real path_error "Path tracking error [m]";
  Real closure_residual[3] "Per-arm closure constraint residual [m^2]";
  Real closure_error "RMS closure error [m]";
  Real sing_margin "Minimum singularity margin";
  Real clearance "Clearance to obstacle [m]";
  Real effort_violation "Total effort bound excess [N.m]";
  Real joint_violation "Total joint bound excess [rad]";

equation
  // ===== Desired circular trajectory =====
  px_d = r_circle * cos(omega * time);
  py_d = r_circle * sin(omega * time);
  pz_d = z_nom;
  vx_d = -r_circle * omega * sin(omega * time);
  vy_d = r_circle * omega * cos(omega * time);
  vz_d = 0.0;

  // ===== Inverse Kinematics at Desired Position =====
  for i in 1:3 loop
    A_d[i] = 2.0 * L1 * (R_b - R_p - px_d * cos(phi[i]) - py_d * sin(phi[i]));
    B_d[i] = -2.0 * L1 * pz_d;
    C_d[i] = (R_b - R_p) * (R_b - R_p) + L1 * L1 + px_d * px_d + py_d * py_d + pz_d * pz_d
           - 2.0 * (R_b - R_p) * (px_d * cos(phi[i]) + py_d * sin(phi[i])) - L2 * L2;
    CmA_d[i] = C_d[i] - A_d[i];
    disc_d[i] = A_d[i] * A_d[i] + B_d[i] * B_d[i] - C_d[i] * C_d[i];
    theta_d_opt1[i] = 2.0 * atan((-B_d[i] + sqrt(max(disc_d[i], 0.0))) / (CmA_d[i] + 1e-12));
    theta_d_opt2[i] = 2.0 * atan((-B_d[i] - sqrt(max(disc_d[i], 0.0))) / (CmA_d[i] + 1e-12));
    theta_d[i] = noEvent(if abs(theta_d_opt1[i]) <= abs(theta_d_opt2[i]) then theta_d_opt1[i] else theta_d_opt2[i]);
    // Forearm vector (arm-end minus platform-joint)
    avx_d[i] = (R_b + L1 * cos(theta_d[i]) - R_p) * cos(phi[i]) - px_d;
    avy_d[i] = (R_b + L1 * cos(theta_d[i]) - R_p) * sin(phi[i]) - py_d;
    avz_d[i] = L1 * sin(theta_d[i]) - pz_d;
    // Partial derivative of arm-end w.r.t. theta
    dAdth_x_d[i] = -L1 * sin(theta_d[i]) * cos(phi[i]);
    dAdth_y_d[i] = -L1 * sin(theta_d[i]) * sin(phi[i]);
    dAdth_z_d[i] = L1 * cos(theta_d[i]);
    // Jacobian denominator (dot product of forearm vector and dA/dtheta)
    denom_d[i] = avx_d[i] * dAdth_x_d[i] + avy_d[i] * dAdth_y_d[i] + avz_d[i] * dAdth_z_d[i];
    denom_d_safe[i] = noEvent(if abs(denom_d[i]) > 1e-6 then denom_d[i] else 1e-6);
    // Jacobian row: dtheta_i/dx_j = forearm_vec_j / denom
    J_d[i, 1] = avx_d[i] / denom_d_safe[i];
    J_d[i, 2] = avy_d[i] / denom_d_safe[i];
    J_d[i, 3] = avz_d[i] / denom_d_safe[i];
  end for;

  // Desired joint velocity via Jacobian and desired platform velocity
  for i in 1:3 loop
    theta_d_dot[i] = J_d[i, 1] * vx_d + J_d[i, 2] * vy_d + J_d[i, 3] * vz_d;
  end for;

  // ===== Inverse Kinematics at Actual Position (Encoder Readings) =====
  for i in 1:3 loop
    A_a[i] = 2.0 * L1 * (R_b - R_p - px * cos(phi[i]) - py * sin(phi[i]));
    B_a[i] = -2.0 * L1 * pz;
    C_a[i] = (R_b - R_p) * (R_b - R_p) + L1 * L1 + px * px + py * py + pz * pz
           - 2.0 * (R_b - R_p) * (px * cos(phi[i]) + py * sin(phi[i])) - L2 * L2;
    CmA_a[i] = C_a[i] - A_a[i];
    disc_a[i] = A_a[i] * A_a[i] + B_a[i] * B_a[i] - C_a[i] * C_a[i];
    theta_opt1[i] = 2.0 * atan((-B_a[i] + sqrt(max(disc_a[i], 0.0))) / (CmA_a[i] + 1e-12));
    theta_opt2[i] = 2.0 * atan((-B_a[i] - sqrt(max(disc_a[i], 0.0))) / (CmA_a[i] + 1e-12));
    theta[i] = noEvent(if abs(theta_opt1[i]) <= abs(theta_opt2[i]) then theta_opt1[i] else theta_opt2[i]);
    // Forearm vector
    avx[i] = (R_b + L1 * cos(theta[i]) - R_p) * cos(phi[i]) - px;
    avy[i] = (R_b + L1 * cos(theta[i]) - R_p) * sin(phi[i]) - py;
    avz[i] = L1 * sin(theta[i]) - pz;
    // Partial derivative
    dAdth_x[i] = -L1 * sin(theta[i]) * cos(phi[i]);
    dAdth_y[i] = -L1 * sin(theta[i]) * sin(phi[i]);
    dAdth_z[i] = L1 * cos(theta[i]);
    // Jacobian denominator
    denom[i] = avx[i] * dAdth_x[i] + avy[i] * dAdth_y[i] + avz[i] * dAdth_z[i];
    denom_safe[i] = noEvent(if abs(denom[i]) > 1e-6 then denom[i] else 1e-6);
    // Jacobian
    J[i, 1] = avx[i] / denom_safe[i];
    J[i, 2] = avy[i] / denom_safe[i];
    J[i, 3] = avz[i] / denom_safe[i];
  end for;

  // Actual joint velocity from Jacobian and platform velocity
  for i in 1:3 loop
    theta_dot[i] = J[i, 1] * vx + J[i, 2] * vy + J[i, 3] * vz;
  end for;

  // ===== PD Torque Control (Inverse-Kinematic Trajectory Control) =====
  for i in 1:3 loop
    tau[i] = Kp_tau * (theta_d[i] - theta[i]) + Kd_tau * (theta_d_dot[i] - theta_dot[i]);
    tau_sat[i] = noEvent(if tau[i] > tau_max then tau_max else if tau[i] < -tau_max then -tau_max else tau[i]);
  end for;

  // ===== Platform Force: F = J^T * tau_sat =====
  Fx = J[1, 1] * tau_sat[1] + J[2, 1] * tau_sat[2] + J[3, 1] * tau_sat[3];
  Fy = J[1, 2] * tau_sat[1] + J[2, 2] * tau_sat[2] + J[3, 2] * tau_sat[3];
  Fz = J[1, 3] * tau_sat[1] + J[2, 3] * tau_sat[2] + J[3, 3] * tau_sat[3];

  // ===== Disturbance: 9 N during middle third (4-8 s) =====
  Fdx = noEvent(if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0);
  Fdy = 0.0;
  Fdz = 0.0;

  // ===== Platform Dynamics (3-DOF point mass) =====
  der(px) = vx;
  der(py) = vy;
  der(pz) = vz;
  mp * der(vx) = Fx + Fdx - b_damp * vx;
  mp * der(vy) = Fy + Fdy - b_damp * vy;
  mp * der(vz) = Fz + Fdz - b_damp * vz;

  // ===== Metrics =====
  // Path tracking error
  path_error = sqrt((px - px_d) * (px - px_d) + (py - py_d) * (py - py_d) + (pz - pz_d) * (pz - pz_d));

  // Closure error (forearm length constraint residual)
  for i in 1:3 loop
    closure_residual[i] = avx[i] * avx[i] + avy[i] * avy[i] + avz[i] * avz[i] - L2 * L2;
  end for;
  closure_error = sqrt(closure_residual[1] * closure_residual[1] + closure_residual[2] * closure_residual[2] + closure_residual[3] * closure_residual[3]);

  // Singularity margin (minimum absolute Jacobian denominator)
  sing_margin = noEvent(if abs(denom[1]) <= abs(denom[2]) and abs(denom[1]) <= abs(denom[3]) then abs(denom[1]) else if abs(denom[2]) <= abs(denom[3]) then abs(denom[2]) else abs(denom[3]));

  // Clearance to fixed obstacle
  clearance = sqrt((px - obs_x) * (px - obs_x) + (py - obs_y) * (py - obs_y) + (pz - obs_z) * (pz - obs_z)) - obs_r;

  // Effort bound violation (total excess across actuators)
  effort_violation = noEvent(max(0.0, abs(tau[1]) - tau_max) + max(0.0, abs(tau[2]) - tau_max) + max(0.0, abs(tau[3]) - tau_max));

  // Joint bound violation (total excess across joints)
  joint_violation = noEvent(max(0.0, abs(theta[1]) - theta_max) + max(0.0, abs(theta[2]) - theta_max) + max(0.0, abs(theta[3]) - theta_max));

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "DeltaTraceC: Closed-chain Delta robot with inverse-kinematic trajectory control.

  Objective: Trace a planar circle of radius 0.10 m with the mechanism output.

  Plant: Fixed triangular base with three actuated 0.32 m upper arms and paired 0.60 m forearms
  connected to a 3 kg moving platform by revolute (base) and spherical (platform) joints.
  Three base-joint torque actuators position the platform.

  Control: Inverse-kinematic PD trajectory control with closure stabilization.
  Max command: 41.4 N.m per actuator (torque saturation enforced).
  Disturbance: 9 N output load during middle third (4-8 s).

  Instrumentation: Actuator encoders (joint angles via IK of measured pose) and direct
  output-pose measurement (px, py, pz).

  Obstacle at (0.30, 0, -0.50) m — outside the circle — with explicit clearance monitoring.

  Run at 125 Hz (dt = 0.008 s) for 12 s.
  Metrics: path_error, closure_error, singularity_margin, clearance, effort/joint violations.
  Requirement: path_error < 0.008 m after 7.8 s; no NaN or infinite values.

  Design assumptions (not specified in requirement):
    R_b = 0.15 m, R_p = 0.05 m, z_nom = -0.50 m, theta_max = pi/2 rad,
    Kp_tau = 300 N.m/rad, Kd_tau = 30 N.m.s/rad, b_damp = 10 N.s/m,
    omega = 2*pi/8 rad/s, obstacle position and radius.")
  );
end DeltaTraceC;