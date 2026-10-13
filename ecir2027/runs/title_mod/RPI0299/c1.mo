model PantographTraceE
  "Closed-chain pantograph mechanism tracing a 0.10 m radius circle"

  // ===== Mechanism parameters =====
  parameter Real L = 0.50 "Long parallelogram link length [m]";
  parameter Real S = 0.25 "Short parallelogram link length [m]";
  parameter Real R_circle = 0.10 "Desired output circle radius [m]";
  parameter Real Q_travel = 0.16 "Prismatic input travel [m]";
  parameter Real delta = 0.5235987755982989 "Parallelogram half-angle offset [rad]";
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
    "Circle angular speed [rad/s]";
  parameter Real t_dist_start = 5.333333 "Disturbance start [s]";
  parameter Real t_dist_end = 10.666667 "Disturbance end [s]";
  parameter Real F_disturb = 12.0 "Output load disturbance magnitude [N]";

  // ===== Obstacle parameters =====
  parameter Real obs_x = 0.20 "Obstacle center x [m]";
  parameter Real obs_y = 0.0 "Obstacle center y [m]";
  parameter Real obs_r = 0.03 "Obstacle radius [m]";

  // ===== Sampling =====
  parameter Real sample_dt = 0.004 "Sample period [s], 250 Hz";

  // ===== Derived kinematic parameters =====
  parameter Real v_x = (L + S) * cos(delta) "Parallelogram basis x [m]";
  parameter Real v_y = (L - S) * sin(delta) "Parallelogram basis y [m]";
  parameter Real v_mag = sqrt(v_x * v_x + v_y * v_y)
    "Parallelogram basis magnitude [m]";
  parameter Real k_scale = R_circle / v_mag
    "Pantograph output scale factor";

  // ===== Dynamic states =====
  Real q(start = 0.0, fixed = true) "Prismatic input position [m]";
  Real qd(start = 0.0, fixed = true) "Prismatic input velocity [m/s]";
  Real e_closure(start = 0.0, fixed = true)
    "Parallelogram closure error [m]";
  Real ed_closure(start = 0.0, fixed = true)
    "Closure error rate [m/s]";

  // ===== Mechanism kinematics =====
  Real phi "Mechanism angle from prismatic input [rad]";
  Real theta1 "Long-link absolute angle [rad]";
  Real theta2 "Short-link absolute angle [rad]";
  Real Ax "Point A x [m]";
  Real Ay "Point A y [m]";
  Real Cx "Point C x [m]";
  Real Cy "Point C y [m]";
  Real Bx "Point B x [m]";
  Real By "Point B y [m]";
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
  Real F_act "Actuated force after saturation [N]";
  Real F_reflected "Reflected disturbance force [N]";
  Real F_load_x "Output load x-component [N]";
  Real F_load_y "Output load y-component [N]";
  Real dist_active "Disturbance active flag";

  // ===== Sensors =====
  Real q_encoder "Prismatic encoder reading [m]";
  Real Px_sensor "Output x direct measurement [m]";
  Real Py_sensor "Output y direct measurement [m]";

  // ===== Acceptance checks =====
  Real path_error "Primary path tracking error [m]";
  Real closure_error "Closure error magnitude [m]";
  Real singularity_margin "Singularity margin [1]";
  Real clearance "Obstacle clearance [m]";
  Real effort_ok "Effort within bound (1=ok)";
  Real joint_ok "Joint within travel (1=ok)";
  Real converged "Tracking converged after 10.4 s (1=yes)";

  // ===== Discrete traces and latch =====
  discrete Real fail_closed(start = 0.0)
    "Fail-closed latched flag (0=ok, 1=fail)";
  discrete Real t_trace(start = 0.0) "Trace timestamp [s]";
  discrete Real q_trace(start = 0.0) "Sampled prismatic position [m]";
  discrete Real F_trace(start = 0.0) "Sampled actuator force [N]";
  discrete Real Px_trace(start = 0.0) "Sampled output x [m]";
  discrete Real Py_trace(start = 0.0) "Sampled output y [m]";
  discrete Real path_err_trace(start = 0.0) "Sampled path error [m]";

protected
  parameter Real v_angle = 2.0 * atan(v_y / (v_x + sqrt(v_x * v_x + v_y * v_y)))
    "Parallelogram basis angle [rad]";

equation
  // ===== Forward kinematics: 6 revolute Z joints + 1 prismatic input =====
  phi = q / r_lever;
  theta1 = phi + delta;
  theta2 = phi - delta;

  // Parallelogram O-A-B-C: OA=L (R1,R3), OC=S (R2,R4), AB=S (R3,R5), CB=L (R4,R5)
  Ax = L * cos(theta1);
  Ay = L * sin(theta1);
  Cx = S * cos(theta2);
  Cy = S * sin(theta2);
  Bx = Ax + Cx;
  By = Ay + Cy;

  // Pantograph output (R6 at scaled B)
  Px = k_scale * Bx;
  Py = k_scale * By;

  // ===== Jacobian =====
  J11 = k_scale * (-L * sin(theta1) - S * sin(theta2)) / r_lever;
  J21 = k_scale * (L * cos(theta1) + S * cos(theta2)) / r_lever;

  // ===== Reference trajectory: circle of radius R_circle =====
  Px_des = R_circle * cos(omega * time + v_angle);
  Py_des = R_circle * sin(omega * time + v_angle);
  q_des = r_lever * omega * time;
  qd_des = r_lever * omega;

  // ===== Disturbance: 12 N load during middle third =====
  dist_active = if (time >= t_dist_start and time <= t_dist_end) then 1.0 else 0.0;
  F_load_x = dist_active * F_disturb * cos(phi);
  F_load_y = dist_active * F_disturb * sin(phi);
  F_reflected = J11 * F_load_x + J21 * F_load_y;

  // ===== Inverse-kinematic trajectory control with effort bound =====
  F_cmd = Kp * (q_des - q) + Kd * (qd_des - qd);
  F_act = if (fail_closed > 0.5) then 0.0
          elseif (F_cmd > F_max) then F_max
          elseif (F_cmd < -F_max) then -F_max
          else F_cmd;

  // ===== Plant dynamics =====
  der(q) = qd;
  m_eq * der(qd) = F_act + F_reflected - b_damp * qd;

  // ===== Closure stabilization dynamics =====
  der(e_closure) = ed_closure;
  m_closure * der(ed_closure) =
    -K_closure * e_closure - C_closure * ed_closure
    + 0.001 * (F_load_x * cos(phi) + F_load_y * sin(phi));

  // ===== Sensors =====
  q_encoder = q;
  Px_sensor = Px;
  Py_sensor = Py;

  // ===== Acceptance metrics =====
  path_error = sqrt(max(0.0, (Px - Px_des) * (Px - Px_des) + (Py - Py_des) * (Py - Py_des)));
  closure_error = abs(e_closure);
  singularity_margin = sin(theta1 - theta2);
  clearance = sqrt(max(0.0, (Px - obs_x) * (Px - obs_x) + (Py - obs_y) * (Py - obs_y))) - obs_r;

  effort_ok = if (abs(F_act) <= F_max + 0.001) then 1.0 else 0.0;
  joint_ok = if (q >= -0.005 and q <= Q_travel + 0.005) then 1.0 else 0.0;
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
    fail_closed = if (pre(fail_closed) > 0.5 or
                     effort_ok < 0.5 or
                     joint_ok < 0.5 or
                     clearance < 0.0 or
                     singularity_margin < 0.01 or
                     (time > 10.4 and path_error > 0.007)) then 1.0 else 0.0;
  end when;

end PantographTraceE;