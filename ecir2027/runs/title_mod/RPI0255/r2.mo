model FourBarPositionC
  "Closed-chain four-bar robotic mechanism with pose feedback through constrained
   inverse kinematics. Moves output platform to nonzero pose and holds against
   bounded load disturbance injected during the middle third of the run."

  // ===== Geometry (specified in requirement) =====
  parameter Real r1 = 0.50 "Ground pivot distance [m]";
  parameter Real r2 = 0.20 "Crank length [m]";
  parameter Real r3 = 0.44 "Coupler length [m]";
  parameter Real r4 = 0.35 "Rocker length [m]";

  // ===== Dynamic parameters (assumed — not stated in requirement) =====
  parameter Real m2 = 0.50 "Crank mass [kg] (assumed)";
  parameter Real m3 = 1.00 "Coupler mass [kg] (assumed)";
  parameter Real m4 = 0.80 "Rocker mass [kg] (assumed)";
  parameter Real J2_cm = 0.0010 "Crank MOI about cm [kg.m2] (assumed)";
  parameter Real J3_cm = 0.0050 "Coupler MOI about cm [kg.m2] (assumed)";
  parameter Real J4_cm = 0.0030 "Rocker MOI about cm [kg.m2] (assumed)";
  parameter Real J_eff = 0.020 "Effective generalized inertia at crank [kg.m2] (assumed)";
  parameter Real b_damp = 0.10 "Viscous damping at crank [N.m.s/rad] (assumed)";

  // ===== Control =====
  parameter Real Kp = 5000.0 "Position proportional gain [N/m]";
  parameter Real Kd = 500.0 "Position derivative gain [N.s/m]";
  parameter Real tau_max = 23.0 "Maximum command torque [N.m]";

  // ===== Disturbance =====
  parameter Real F_dist_mag = 12.6 "Platform load disturbance magnitude [N]";
  parameter Real t_dist_start = 4.0 "Disturbance start (middle third of 12 s) [s]";
  parameter Real t_dist_end   = 8.0 "Disturbance end (middle third of 12 s) [s]";

  // ===== Target pose (from constrained forward kinematics at theta2 = 0.5 rad) =====
  parameter Real theta2_target = 0.50 "Target crank angle [rad]";
  parameter Real x_target = 0.5370 "Target output x position [m]";
  parameter Real y_target = 0.3480 "Target output y position [m]";

  // ===== Simulation =====
  parameter Real Ts = 0.008 "Sample period (125 Hz) [s]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";
  parameter Real t_track = 7.8 "Tracking error convergence deadline [s]";
  parameter Real e_track_max = 0.006 "Max tracking error after deadline [m]";
  parameter Real pi_val = 3.14159265358979 "Pi constant [-]";

  // ===== Dynamic states =====
  Real theta2(start=0.10) "Crank angle (actuator coordinate) [rad]";
  Real omega2(start=0.0)   "Crank angular velocity [rad/s]";

  // ===== Kinematic algebraic variables =====
  Real theta3(start=0.80) "Coupler angle [rad]";
  Real theta4(start=1.50) "Rocker angle [rad]";
  Real k3 "Velocity coefficient dtheta3/dtheta2 [-]";
  Real k4 "Velocity coefficient dtheta4/dtheta2 [-]";
  Real omega3 "Coupler angular velocity [rad/s]";
  Real omega4 "Rocker angular velocity [rad/s]";
  Real alpha2 "Crank angular acceleration [rad/s2]";
  Real alpha3 "Coupler angular acceleration [rad/s2]";
  Real alpha4 "Rocker angular acceleration [rad/s2]";
  Real Jx "Jacobian dx_C/dtheta2 [m/rad]";
  Real Jy "Jacobian dy_C/dtheta2 [m/rad]";

  // ===== Positions and velocities =====
  Real x_B "Crank end B x [m]";
  Real y_B "Crank end B y [m]";
  Real x_C "Output point C x [m]";
  Real y_C "Output point C y [m]";
  Real vx_C "Output velocity x [m/s]";
  Real vy_C "Output velocity y [m/s]";

  // ===== Accelerations =====
  Real a_Bx "Acceleration of B x [m/s2]";
  Real a_By "Acceleration of B y [m/s2]";
  Real a_Cx "Acceleration of C x [m/s2]";
  Real a_Cy "Acceleration of C y [m/s2]";
  Real a_cm2x "Crank cm acceleration x [m/s2]";
  Real a_cm2y "Crank cm acceleration y [m/s2]";
  Real a_cm3x "Coupler cm acceleration x [m/s2]";
  Real a_cm3y "Coupler cm acceleration y [m/s2]";
  Real a_cm4x "Rocker cm acceleration x [m/s2]";
  Real a_cm4y "Rocker cm acceleration y [m/s2]";

  // ===== Control variables =====
  Real ex "Position error x [m]";
  Real ey "Position error y [m]";
  Real pos_error "Position error norm [m]";
  Real tau_cmd "Unsaturated command torque [N.m]";
  Real tau_sat "Saturated command torque [N.m]";

  // ===== Disturbance variables =====
  Real F_dist_x "Disturbance force x [N]";
  Real F_dist_y "Disturbance force y [N]";
  Real tau_dist "Generalized disturbance torque [N.m]";

  // ===== Joint internal forces =====
  Real F_Bx "Force at B on crank from coupler x [N]";
  Real F_By "Force at B on crank from coupler y [N]";
  Real F_Cx "Force at C on rocker from coupler x [N]";
  Real F_Cy "Force at C on rocker from coupler y [N]";

  // ===== Ground reaction forces (sensors) =====
  Real R_Ax "Ground reaction at pivot A x [N]";
  Real R_Ay "Ground reaction at pivot A y [N]";
  Real R_Dx "Ground reaction at pivot D x [N]";
  Real R_Dy "Ground reaction at pivot D y [N]";

  // ===== Moment intermediates =====
  Real J2_A "Crank MOI about pivot A [kg.m2]";
  Real J4_A "Rocker MOI about pivot D [kg.m2]";
  Real R4_mom "Rocker moment RHS for F_C solve";
  Real R3_mom "Coupler moment RHS for F_C solve";
  Real det_FC "Determinant of F_C linear system";
  Real det_FC_safe "Zero-guarded determinant";

  // ===== Monitoring =====
  Real closure_residual "Loop closure residual norm [m]";
  Real min_link_dist "Min distance between non-adjacent links [m]";
  Real collision_AB_CD "Crank-rocker collision flag (0=clear, 1=collision)";
  Real collision_BC_DA "Coupler-ground collision flag (0=clear, 1=collision)";
  Real no_collision "Overall no-collision flag (1=clear, 0=collision)";
  Boolean travel_ok "Actuator travel within bounds";
  Boolean force_ok "Actuator force within bounds";
  Boolean tracking_ok "Tracking error within bounds after deadline";
  Boolean no_nan "No NaN or infinite values";
  Boolean all_ok "All requirements satisfied";

  // ===== Collision cross-product helpers =====
  Real d1_ab "Cross product AB-CD test 1";
  Real d2_ab "Cross product AB-CD test 2";
  Real d3_ab "Cross product AB-CD test 3";
  Real d4_ab "Cross product AB-CD test 4";
  Real d1_bc "Cross product BC-DA test 1";
  Real d2_bc "Cross product BC-DA test 2";
  Real d3_bc "Cross product BC-DA test 3";
  Real d4_bc "Cross product BC-DA test 4";

equation
  // ===== Loop closure (constrained kinematics) =====
  r2*cos(theta2) + r3*cos(theta3) = r1 + r4*cos(theta4);
  r2*sin(theta2) + r3*sin(theta3) = r4*sin(theta4);

  // ===== Joint positions =====
  x_B = r2*cos(theta2);
  y_B = r2*sin(theta2);
  x_C = r1 + r4*cos(theta4);
  y_C = r4*sin(theta4);

  // ===== Velocity coefficients from differentiated loop closure =====
  r2*sin(theta2) + r3*sin(theta3)*k3 = r4*sin(theta4)*k4;
  r2*cos(theta2) + r3*cos(theta3)*k3 = r4*cos(theta4)*k4;

  // ===== Angular velocities =====
  omega3 = k3 * omega2;
  omega4 = k4 * omega2;

  // ===== Jacobian of output point C w.r.t. crank angle =====
  Jx = -r4*sin(theta4)*k4;
  Jy =  r4*cos(theta4)*k4;

  // ===== Output velocity =====
  vx_C = Jx * omega2;
  vy_C = Jy * omega2;

  // ===== Dynamics: effective single-DOF equation of motion =====
  alpha2 = (tau_sat + tau_dist - b_damp*omega2) / J_eff;
  der(theta2) = omega2;
  der(omega2) = alpha2;

  // ===== Acceleration loop (differentiated velocity closure) =====
  -r3*sin(theta3)*alpha3 + r4*sin(theta4)*alpha4 =
    r2*cos(theta2)*omega2^2 + r2*sin(theta2)*alpha2
    + r3*cos(theta3)*omega3^2 - r4*cos(theta4)*omega4^2;
  r3*cos(theta3)*alpha3 - r4*cos(theta4)*alpha4 =
    r2*sin(theta2)*omega2^2 - r2*cos(theta2)*alpha2
    + r3*sin(theta3)*omega3^2 - r4*sin(theta4)*omega4^2;

  // ===== Point accelerations =====
  a_Bx = -r2*cos(theta2)*omega2^2 - r2*sin(theta2)*alpha2;
  a_By = -r2*sin(theta2)*omega2^2 + r2*cos(theta2)*alpha2;
  a_Cx = -r4*cos(theta4)*omega4^2 - r4*sin(theta4)*alpha4;
  a_Cy = -r4*sin(theta4)*omega4^2 + r4*cos(theta4)*alpha4;
  a_cm2x = -r2/2*cos(theta2)*omega2^2 - r2/2*sin(theta2)*alpha2;
  a_cm2y = -r2/2*sin(theta2)*omega2^2 + r2/2*cos(theta2)*alpha2;
  a_cm3x = (a_Bx + a_Cx)/2;
  a_cm3y = (a_By + a_Cy)/2;
  a_cm4x = -r4/2*cos(theta4)*omega4^2 - r4/2*sin(theta4)*alpha4;
  a_cm4y = -r4/2*sin(theta4)*omega4^2 + r4/2*cos(theta4)*alpha4;

  // ===== Disturbance injection (middle third: 4 s to 8 s) =====
  F_dist_x = 0.0;
  F_dist_y = if time >= t_dist_start and time <= t_dist_end then -F_dist_mag else 0.0;
  tau_dist = Jx*F_dist_x + Jy*F_dist_y;

  // ===== Control: Jacobian-transpose PD with torque saturation =====
  ex = x_target - x_C;
  ey = y_target - y_C;
  pos_error = sqrt(ex*ex + ey*ey + 1e-12);
  tau_cmd = Jx*(Kp*ex - Kd*vx_C) + Jy*(Kp*ey - Kd*vy_C);
  tau_sat = if tau_cmd > tau_max then tau_max
            else if tau_cmd < -tau_max then -tau_max
            else tau_cmd;

  // ===== Moments of inertia about ground pivots =====
  J2_A = J2_cm + m2*(r2/2)^2;
  J4_A = J4_cm + m4*(r4/2)^2;

  // ===== Reaction force computation via Newton-Euler per link =====
  // Rocker moment about D gives one equation for F_C:
  //   J4_A*alpha4 = r4*(cos(theta4)*F_Cy - sin(theta4)*F_Cx)
  R4_mom = J4_A*alpha4/r4;

  // Coupler moment about cm3 combined with force balance gives second equation:
  //   cos(theta3)*F_Cy - sin(theta3)*F_Cx = R3_mom
  R3_mom = -J3_cm*alpha3/r3
           + cos(theta3)*F_dist_y - sin(theta3)*F_dist_x
           - m3/2*(cos(theta3)*a_cm3y - sin(theta3)*a_cm3x);

  // Solve 2x2 linear system for F_Cx, F_Cy
  det_FC = sin(theta4 - theta3);
  det_FC_safe = if abs(det_FC) < 1e-6 then 1e-6 else det_FC;
  F_Cy = (-sin(theta3)*R4_mom + sin(theta4)*R3_mom) / det_FC_safe;
  F_Cx = (cos(theta4)*R3_mom - cos(theta3)*R4_mom) / det_FC_safe;

  // Coupler force balance yields F_B
  F_Bx = F_dist_x - m3*a_cm3x - F_Cx;
  F_By = F_dist_y - m3*a_cm3y - F_Cy;

  // Ground reactions from link force balances
  R_Ax = m2*a_cm2x - F_Bx;
  R_Ay = m2*a_cm2y - F_By;
  R_Dx = m4*a_cm4x - F_Cx;
  R_Dy = m4*a_cm4y - F_Cy;

  // ===== Closure residual =====
  closure_residual = sqrt(
    (r2*cos(theta2) + r3*cos(theta3) - r1 - r4*cos(theta4))^2 +
    (r2*sin(theta2) + r3*sin(theta3) - r4*sin(theta4))^2
  );

  // ===== Self-collision: crank AB vs rocker CD =====
  // Segment AB: P1=(0,0), P2=(x_B,y_B); Segment CD: P3=(x_C,y_C), P4=(r1,0)
  d1_ab = (x_C - 0.0)*(y_B - 0.0) - (y_C - 0.0)*(x_B - 0.0);
  d2_ab = (r1  - 0.0)*(y_B - 0.0) - (0.0 - 0.0)*(x_B - 0.0);
  d3_ab = (0.0 - x_C)*(0.0 - y_C) - (0.0 - y_C)*(r1  - x_C);
  d4_ab = (x_B - x_C)*(0.0 - y_C) - (y_B - y_C)*(r1  - x_C);
  collision_AB_CD = if (((d1_ab > 0 and d2_ab < 0) or (d1_ab < 0 and d2_ab > 0)) and
                        ((d3_ab > 0 and d4_ab < 0) or (d3_ab < 0 and d4_ab > 0)))
                    then 1.0 else 0.0;

  // ===== Self-collision: coupler BC vs ground DA =====
  // Segment BC: P1=(x_B,y_B), P2=(x_C,y_C); Segment DA: P3=(r1,0), P4=(0,0)
  d1_bc = (r1  - x_B)*(y_C - y_B) - (0.0 - y_B)*(x_C - x_B);
  d2_bc = (0.0 - x_B)*(y_C - y_B) - (0.0 - y_B)*(x_C - x_B);
  d3_bc = (x_B - r1 )*(0.0 - 0.0) - (y_B - 0.0)*(0.0 - r1 );
  d4_bc = (x_C - r1 )*(0.0 - 0.0) - (y_C - 0.0)*(0.0 - r1 );
  collision_BC_DA = if (((d1_bc > 0 and d2_bc < 0) or (d1_bc < 0 and d2_bc > 0)) and
                        ((d3_bc > 0 and d4_bc < 0) or (d3_bc < 0 and d4_bc > 0)))
                    then 1.0 else 0.0;

  no_collision = if (collision_AB_CD > 0.5 or collision_BC_DA > 0.5) then 0.0 else 1.0;

  // ===== Minimum distance between non-adjacent links (crank mid vs rocker mid) =====
  min_link_dist = sqrt(
    (r2/2*cos(theta2) - (r1 + r4/2*cos(theta4)))^2 +
    (r2/2*sin(theta2) -  r4/2*sin(theta4))^2
  );

  // ===== Bounds and requirement checks =====
  travel_ok  = abs(theta2 - theta2_target) < pi_val;
  force_ok   = abs(tau_sat) <= tau_max + 0.001;
  tracking_ok = if time >= t_track then pos_error < e_track_max else true;
  no_nan = (abs(theta2) < 1e10) and (abs(omega2) < 1e10) and
           (abs(alpha2) < 1e10) and (abs(tau_cmd) < 1e10) and
           (abs(pos_error) < 1e10) and (abs(x_C) < 1e10) and (abs(y_C) < 1e10);
  all_ok = travel_ok and force_ok and tracking_ok and no_nan and (no_collision > 0.5);

  annotation(
    Documentation(info="Four-bar closed-chain mechanism with two fixed pivots
      0.50 m apart, crank 0.20 m, coupler 0.44 m, rocker 0.35 m, four revolute
      Z joints. Pose feedback via Jacobian-transpose PD through constrained
      inverse kinematics. Bounded crank torque at 23 N.m max. 12.6 N platform
      load disturbance during middle third (4-8 s of 12 s). Run at 125 Hz."),
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1e-6, Interval=0.008)
  );
end FourBarPositionC;