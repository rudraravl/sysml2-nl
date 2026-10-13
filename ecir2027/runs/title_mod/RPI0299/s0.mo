model PantographTraceE
  "Closed-chain pantograph mechanism tracing a 0.10 m radius circle"

  // ===== Mechanism parameters =====
  parameter Real L = 0.50 "Long parallelogram link length [m]";
  parameter Real S = 0.25 "Short parallelogram link length [m]";
  parameter Real R_circle = 0.10 "Desired output circle radius [m]";
  parameter Real Q_travel = 0.16 "Prismatic input travel [m]";
  parameter Real delta = 0.5235987755982989 "Parallelogram half-angle offset [rad], pi/6";
  parameter Real r_lever = Q_travel / (2.0 * 3.141592653589793)
    "Prismatic-to-angle lever ratio [m/rad]";

  // ===== Actuator parameters =====
  parameter Real F_max = 352.0 "Actuator force bound [N]";
  parameter Real m_eq = 2.0 "Equivalent reflected mass at prismatic joint [kg]";
  parameter Real b_damp = 5.0 "Prismatic joint damping [N.s/m]";

  // ===== Controller parameters =====
  parameter Real Kp = 8000.0 "Position gain [N/m]";
  parameter Real Kd = 180.0 "Velocity gain [N.s/m]";
  parameter Real K_closure = 5000.0 "Closure stabilization stiffness [N/m]";
  parameter Real C_closure = 50.0 "Closure damping [N.s/m]";
  parameter Real m_closure = 0.5 "Closure effective mass [kg]";

  // ===== Trajectory and disturbance parameters =====
  parameter Real omega = 0.39269908169872414
    "Circle angular speed [rad/s], 1 revolution per 16 s";
  parameter Real t_sim = 16.0 "Simulation duration [s]";
  parameter Real t_dist_start = 5.333333
    "Disturbance start [s], one-third of 16 s";
  parameter Real t_dist_end = 10.666667
    "Disturbance end [s], two-thirds of 16 s";
  parameter Real F_disturb = 12.0 "Output load disturbance magnitude [N]";

  // ===== Obstacle parameters =====
  parameter Real obs_x = 0.20 "Obstacle center x [m], outside 0.10 m circle";
  parameter Real obs_y = 0.0 "Obstacle center y [m]";
  parameter Real obs_r = 0.03 "Obstacle radius [m]";

  // ===== Sampling =====
  parameter Real sample_dt = 0.004 "Sample period [s], 250 Hz";

  // ===== Derived kinematic constants =====
  Real v_x = (L + S) * cos(delta) "Parallelogram basis x [m]";
  Real v_y = (L - S) * sin(delta) "Parallelogram basis y [m]";
  Real v_mag = sqrt(v_x * v_x + v_y * v_y) "Parallelogram basis magnitude [m]";
  Real v_angle = atan2(v_y, v_x) "Parallelogram basis angle [rad]";
  Real k_scale = R_circle / v_mag "Pantograph output scale factor";

  // ===== Dynamic states =====
  Real q(start = 0.0, fixed = true) "Prismatic input position [m]";
  Real qd(start = 0.0, fixed = true) "Prismatic input velocity [m/s]";
  Real e_closure(start = 0.0, fixed = true)
    "Parallelogram closure error [m]";
  Real ed_closure(start = 0.0, fixed = true) "Closure error rate [m/s]";

  // ===== Mechanism kinematics: 6 revolute Z joints + 1 prismatic =====
  Real phi "Mechanism angle from prismatic input [rad]";
  Real theta1 "Long-link absolute angle (joints R1,R3,R5) [rad]";
  Real theta2 "Short-link absolute angle (joints R2,R4,R6) [rad]";

  // Joint positions (R1,R2 at ground origin; R3 at A; R4 at C; R5 at B; R6 at output)
  Real R3_x "R3 joint at A, x [m]";
  Real R3_y "R3 joint at A, y [m]";
  Real R4_x "R4 joint at C, x [m]";
  Real R4_y "R4 joint at C, y [m]";
  Real R5_x "R5 joint at B, x [m]";
  Real R5_y "R5 joint at B, y [m]";
  Real R6_x "R6 output joint, x [m]";
  Real R6_y "R6 output joint, y [m]";

  // Parallelogram vertex coordinates
  Real Ax "Point A x [m]";
  Real Ay "Point A y [m]";
  Real Cx "Point C x [m]";
  Real Cy "Point C y [m]";
  Real Bx "Point B x [m]";
  Real By "Point B y [m]";

  // Output pose
  Real Px "Output x [m]";
  Real Py "Output y [m]";

  // ===== Reference trajectory =====
  Real Px_des "Desired output x [m]";
  Real Py_des "Desired output y [m]";
  Real q_des "Desired prismatic position [m]";
  Real qd_des "Desired prismatic velocity [m/s]";

  // ===== Jacobian =====
  Real J11 "dPx/dq [m/m]";
  Real J21 "dPy/dq [m/m]";

  // ===== Control and disturbance =====
  Real F_cmd "Commanded force before saturation [N]";
  Real F_act "Actuated force after saturation and fail-closed [N]";
  Real F_reflected "Reflected disturbance force at prismatic joint [N]";
  Real F_load_x "Output load x-component [N]";
  Real F_load_y "Output load y-component [N]";
  Real dist_active "Disturbance active flag (0 or 1)";

  // ===== Sensors =====
  Real q_encoder "Prismatic encoder reading [m]";
  Real Px_sensor "Output x direct measurement [m]";
  Real Py_sensor "Output y direct measurement [m]";

  // ===== Acceptance checks =====
  Real path_error "Primary path tracking error [m]";
  Real closure_error "Closure error magnitude [m]";
  Real singularity_margin "Singularity margin = sin(theta1-theta2) [1]";
  Real clearance "Obstacle clearance [m]";
  Real effort_ok "Effort within bound (1=ok, 0=violation)";
  Real joint_ok "Joint within travel (1=ok, 0=violation)";
  Real value_ok "No NaN/Inf in physical, control, or estimator (1=ok, 0=violation)";
  Real converged "Tracking converged after 10.4 s (1=yes, 0=no)";
  discrete Real fail_closed(start = 0.0)
    "Fail-closed latched flag (0=ok, 1=fail)";

  // ===== Synchronized traces at 250 Hz =====
  discrete Real t_trace(start = 0.0) "Trace timestamp [s]";
  discrete Real q_trace(start = 0.0) "Sampled prismatic position [m]";
  discrete Real F_trace(start = 0.0) "Sampled actuator force [N]";
  discrete Real Px_trace(start = 0.0) "Sampled output x [m]";
  discrete Real Py_trace(start = 0.0) "Sampled output y [m]";
  discrete Real path_err_trace(start = 0.0) "Sampled path error [m]";

equation
  // ===== Mechanism forward kinematics =====
  // Prismatic input q maps to mechanism angle phi via lever ratio
  phi = q / r_lever;

  // Six revolute Z joints define parallelogram O-A-B-C:
  //   R1 at O (ground-to-OA), R2 at O (ground-to-OC),
  //   R3 at A (OA-to-AB),     R4 at C (OC-to-CB),
  //   R5 at B (AB-to-CB),     R6 at output extension
  theta1 = phi + delta;
  theta2 = phi - delta;

  // Link endpoint positions from revolute angles
  Ax = L * cos(theta1);
  Ay = L * sin(theta1);
  Cx = S * cos(theta2);
  Cy = S * sin(theta2);

  // Parallelogram closure: B = A + C, so |AB|=S and |CB|=L
  Bx = Ax + Cx;
  By = Ay + Cy;

  // Joint positions for observability
  R3_x = Ax;  R3_y = Ay;
  R4_x = Cx;  R4_y = Cy;
  R5_x = Bx;  R5_y = By;

  // Output: pantograph-scaled B with closure-error perturbation
  Px = k_scale * (Bx + e_closure * cos(phi));
  Py = k_scale * (By + e_closure * sin(phi));
  R6_x = Px;  R6_y = Py;

  // ===== Jacobian dP/dq =====
  J11 = k_scale * (-L * sin(theta1) - S * sin(theta2)) / r_lever;
  J21 = k_scale * (L * cos(theta1) + S * cos(theta2)) / r_lever;

  // ===== Reference trajectory: circle of radius R_circle =====
  Px_des = R_circle * cos(omega * time + v_angle);
  Py_des = R_circle * sin(omega * time + v_angle);
  q_des = r_lever * omega * time;
  qd_des = r_lever * omega;

  // ===== Disturbance: 12 N radial load during middle third =====
  dist_active = if (time >= t_dist_start and time <= t_dist_end)
                then 1.0 else 0.0;
  F_load_x = dist_active * F_disturb * cos(phi);
  F_load_y = dist_active * F_disturb * sin(phi);
  F_reflected = J11 * F_load_x + J21 * F_load_y;

  // ===== Inverse-kinematic trajectory control with effort bound =====
  F_cmd = Kp * (q_des - q) + Kd * (qd_des - qd);
  F_act = if (fail_closed > 0.5) then 0.0
          elseif (F_cmd > F_max) then F_max
          elseif (F_cmd < -F_max) then -F_max
          else F_cmd;

  // ===== Plant dynamics at prismatic joint =====
  m_eq * der(qd) = F_act + F_reflected - b_damp * qd;
  der(q) = qd;

  // ===== Closure stabilization dynamics =====
  m_closure * der(ed_closure) =
    -K_closure * e_closure - C_closure * ed_closure
    + 0.001 * (F_load_x * cos(phi) + F_load_y * sin(phi));
  der(e_closure) = ed_closure;

  // ===== Sensors =====
  q_encoder = q;
  Px_sensor = Px;
  Py_sensor = Py;

  // ===== Acceptance metrics =====
  path_error = sqrt((Px - Px_des)^2 + (Py - Py_des)^2);
  closure_error = abs(e_closure);
  singularity_margin = sin(theta1 - theta2);
  clearance = sqrt((Px - obs_x)^2 + (Py - obs_y)^2) - obs_r;

  effort_ok = if (abs(F_act) <= F_max + 0.001) then 1.0 else 0.0;
  joint_ok = if (q >= -0.005 and q <= Q_travel + 0.005) then 1.0 else 0.0;
  value_ok = if (q <> q or qd <> qd or Px <> Px or Py <> Py or
                 F_act <> F_act or e_closure <> e_closure or
                 abs(q) > 1e30 or abs(qd) > 1e30 or
                 abs(Px) > 1e30 or abs(Py) > 1e30 or
                 abs(F_act) > 1e30) then 0.0 else 1.0;
  converged = if (time > 10.4) then
                (if (path_error < 0.007) then 1.0 else 0.0)
              else 1.0;

  // ===== Synchronized 250 Hz traces and fail-closed latching =====
  when sample(0, sample_dt) then
    t_trace = time;
    q_trace = q;
    F_trace = F_act;
    Px_trace = Px;
    Py_trace = Py;
    path_err_trace = path_error;
    if (effort_ok < 0.5 or joint_ok < 0.5 or value_ok < 0.5 or
        clearance < 0.0 or singularity_margin < 0.01 or
        (time > 10.4 and path_error > 0.007)) then
      fail_closed = 1.0;
    end if;
  end when;

end PantographTraceE;