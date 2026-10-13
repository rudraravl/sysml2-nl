model MixedTeamCoordinateA
  // ---------------- Parameters ----------------
  parameter Real m_g = 24.0 "ground robot mass [kg]";
  parameter Real m_q = 2.1 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real r_w = 0.1 "assumed drive wheel radius [m]";
  parameter Real u_max = 10.1 "command magnitude limit [N.m or N]";
  parameter Real kpv = 12.0 "ground velocity tracking gain";
  parameter Real kqv = 6.0 "quad velocity tracking gain";
  parameter Real v_ref_g = 2.0 "ground nominal speed [m/s]";
  parameter Real v_ref_q = 2.5 "quad nominal speed [m/s]";
  parameter Real brake_dist = 1.2 "braking distance [m]";
  parameter Real x_g_start = -5.0 "ground start x [m]";
  parameter Real x_g_end = 5.0 "ground end x [m]";
  parameter Real y_q_start = -5.0 "quad start y [m]";
  parameter Real y_q_end = 5.0 "quad end y [m]";
  parameter Real corridor_half = 0.6 "corridor half width [m]";
  parameter Real intersect_half = 0.8 "intersection half extent [m]";
  parameter Real d_safe = 0.6 "minimum distance / no-collision threshold [m]";
  parameter Real sep_req = 0.878 "primary separation requirement [m]";
  parameter Real t_final = 8.0 "scenario duration [s]";
  parameter Real delay_t_start = 2.667 "middle third start [s]";
  parameter Real delay_t_end = 5.333 "middle third end [s]";
  parameter Real msg_delay = 0.06 "message delay disturbance [s]";
  parameter Real eps = 1e-6;
  parameter Real pi = 3.141592653589793;
  parameter Real T_hover = m_q*g/4.0 "per-rotor hover thrust [N]";

  // ---------------- Ground robot states ----------------
  Real x_g(start=x_g_start, fixed=true) "ground x position [m]";
  Real vx_g(start=0.0, fixed=true) "ground x velocity [m/s]";
  Real tau_g_cmd "wheel torque command [N.m]";
  Real tau_g "saturated wheel torque [N.m]";

  // ---------------- Quadrotor states ----------------
  Real y_q(start=y_q_start, fixed=true) "quad y position [m]";
  Real vy_q(start=0.0, fixed=true) "quad y velocity [m/s]";
  Real F_y_cmd "horizontal force command [N]";
  Real F_y_cmd_sat "command-limited horizontal force [N]";
  Real F_y_real "realized differential thrust [N]";
  Real T1 "rotor 1 thrust [N]";
  Real T2 "rotor 2 thrust [N]";
  Real T3 "rotor 3 thrust [N]";
  Real T4 "rotor 4 thrust [N]";

  // ---------------- Peer (delayed) messages ----------------
  Real x_g_delayed "always-delayed ground x pose [m]";
  Real y_q_delayed "always-delayed quad y pose [m]";
  Real x_g_peer "effective delayed ground x pose [m]";
  Real y_q_peer "effective delayed quad y pose [m]";
  Boolean in_delay_window;

  // ---------------- Reservation / exclusion ----------------
  Boolean ground_in_intersection;
  Boolean q_in_intersection;
  Boolean mutual_exclusion_ok;
  Boolean q_safe_to_enter;
  Boolean q_waiting;

  // ---------------- Safety ----------------
  Real dist "2D separation [m]";
  Real dist_safe "separation with zero-guard [m]";
  Boolean no_collision;

  // ---------------- Tracking ----------------
  Real v_cmd_g "ground velocity command [m/s]";
  Real v_cmd_q "quad velocity command [m/s]";
  Real x_ref_g "ground reference x [m]";
  Real track_err_g "ground position tracking error [m]";
  Real primary_track_err "primary tracking error [m]";

  // ---------------- Sensors ----------------
  Real lidar_range "ground lidar forward range [m]";
  Real cam_y "quad camera measured y [m]";

  // ---------------- Route completion ----------------
  Boolean ground_done, q_done, route_done;

  // ---------------- Waiting time ----------------
  Real wait_time(start=0.0, fixed=true) "quad accumulated waiting time [s]";

  // ---------------- Validity ----------------
  Boolean finite_ok;

  // ---------------- Synchronized 80 Hz trace buffers ----------------
  Real x_g_log(start=x_g_start);
  Real y_q_log(start=y_q_start);
  Real tau_g_log(start=0.0);
  Real F_y_log(start=0.0);
  Real dist_log(start=7.0710678);
  Integer tick(start=0);

protected
  parameter Real t_sample = 1.0/80.0 "sample period [s]";
equation
  // ---- Always-delayed peer messages (constant-delay delay operator) ----
  x_g_delayed = delay(x_g, msg_delay, msg_delay + 1e-9);
  y_q_delayed = delay(y_q, msg_delay, msg_delay + 1e-9);

  // ---- Effective peer message: delayed only during middle third ----
  in_delay_window = (time >= delay_t_start) and (time <= delay_t_end);
  x_g_peer = if in_delay_window then x_g_delayed else x_g;
  y_q_peer = if in_delay_window then y_q_delayed else y_q;

  // ---- Ground reference trajectory ----
  x_ref_g = if (x_g_start + v_ref_g*time) < x_g_end then (x_g_start + v_ref_g*time) else x_g_end;

  // ---- Ground velocity command with end braking ----
  v_cmd_g = if x_g < (x_g_end - brake_dist) then v_ref_g
            else (if v_ref_g*(x_g_end - x_g)/brake_dist > 0.0 then v_ref_g*(x_g_end - x_g)/brake_dist else 0.0);
  tau_g_cmd = kpv*(v_cmd_g - vx_g);
  tau_g = if tau_g_cmd > u_max then u_max else (if tau_g_cmd < (-u_max) then (-u_max) else tau_g_cmd);

  // ---- Ground dynamics (two wheels, each torque tau_g) ----
  m_g*der(vx_g) = 2.0*tau_g/r_w;
  der(x_g) = vx_g;

  // ---- Ground lidar (deterministic bounded forward range sensor) ----
  lidar_range = if (10.0 + 0.05*sin(2.0*pi*1.3*time)) > 0.1 then (10.0 + 0.05*sin(2.0*pi*1.3*time)) else 0.1;

  // ---- Quad reservation: decentralized, waits until ground clears intersection ----
  q_safe_to_enter = (x_g_peer > intersect_half + 0.3);
  q_waiting = (not q_safe_to_enter) and (y_q < y_q_end - brake_dist);

  // ---- Quad velocity command: wait, cruise, brake at end ----
  v_cmd_q = if y_q > (y_q_end - brake_dist) then
              (if v_ref_q*(y_q_end - y_q)/brake_dist > 0.0 then v_ref_q*(y_q_end - y_q)/brake_dist else 0.0)
            else (if q_waiting then 0.0 else v_ref_q);
  F_y_cmd = kqv*(v_cmd_q - vy_q);
  F_y_cmd_sat = if F_y_cmd > u_max then u_max else (if F_y_cmd < (-u_max) then (-u_max) else F_y_cmd);

  // ---- Rotor thrust allocation (hover + differential), each independently bounded ----
  T1 = if T_hover > u_max then u_max else (if T_hover < 0.0 then 0.0 else T_hover);
  T3 = if T_hover > u_max then u_max else (if T_hover < 0.0 then 0.0 else T_hover);
  T2 = if (T_hover + F_y_cmd_sat/2.0) > u_max then u_max
       else (if (T_hover + F_y_cmd_sat/2.0) < 0.0 then 0.0 else (T_hover + F_y_cmd_sat/2.0));
  T4 = if (T_hover - F_y_cmd_sat/2.0) > u_max then u_max
       else (if (T_hover - F_y_cmd_sat/2.0) < 0.0 then 0.0 else (T_hover - F_y_cmd_sat/2.0));
  F_y_real = T2 - T4;

  // ---- Quad horizontal dynamics ----
  m_q*der(vy_q) = F_y_real;
  der(y_q) = vy_q;

  // ---- Quad camera pose sensor ----
  cam_y = y_q + 0.02*sin(2.0*pi*0.7*time);

  // ---- Distance and collision / exclusion checks ----
  dist = sqrt(x_g*x_g + y_q*y_q);
  dist_safe = if dist > eps then dist else eps;
  ground_in_intersection = (abs(x_g) < intersect_half);
  q_in_intersection = (abs(y_q) < intersect_half);
  mutual_exclusion_ok = not (ground_in_intersection and q_in_intersection);
  no_collision = dist >= d_safe;

  // ---- Tracking error (primary = ground robot) ----
  track_err_g = abs(x_ref_g - x_g);
  primary_track_err = track_err_g;

  // ---- Route completion ----
  ground_done = (x_g >= x_g_end - 0.05) and (abs(vx_g) < 0.05);
  q_done = (y_q >= y_q_end - 0.05) and (abs(vy_q) < 0.05);
  route_done = ground_done and q_done;

  // ---- Waiting time accumulator ----
  der(wait_time) = if q_waiting then 1.0 else 0.0;

  // ---- Finiteness / validity check (NaN self-inequality test) ----
  finite_ok = (x_g == x_g) and (vx_g == vx_g) and (y_q == y_q) and (vy_q == vy_q) and
              (x_g > -1e6) and (x_g < 1e6) and
              (vx_g > -1e6) and (vx_g < 1e6) and
              (y_q > -1e6) and (y_q < 1e6) and
              (vy_q > -1e6) and (vy_q < 1e6) and
              (T1 >= 0.0) and (T1 <= u_max + 1e-6) and
              (T2 >= 0.0) and (T2 <= u_max + 1e-6) and
              (T3 >= 0.0) and (T3 <= u_max + 1e-6) and
              (T4 >= 0.0) and (T4 <= u_max + 1e-6) and
              (tau_g >= -u_max - 1e-6) and (tau_g <= u_max + 1e-6);

  // ---- Synchronized 80 Hz trace capture ----
  when sample(0, t_sample) then
    tick = pre(tick) + 1;
    x_g_log = x_g;
    y_q_log = y_q;
    tau_g_log = tau_g;
    F_y_log = F_y_real;
    dist_log = dist_safe;
  end when;

  // ---- Requirement assertions ----
  assert(tau_g >= -u_max - 1e-6 and tau_g <= u_max + 1e-6, "actuator bound: ground torque violated");
  assert(T1 >= -1e-6 and T1 <= u_max + 1e-6, "actuator bound: T1 violated");
  assert(T2 >= -1e-6 and T2 <= u_max + 1e-6, "actuator bound: T2 violated");
  assert(T3 >= -1e-6 and T3 <= u_max + 1e-6, "actuator bound: T3 violated");
  assert(T4 >= -1e-6 and T4 <= u_max + 1e-6, "actuator bound: T4 violated");
  assert(no_collision, "minimum distance / no-collision violated");
  assert(mutual_exclusion_ok, "mutual exclusion at intersection violated");
  assert(finite_ok, "NaN or non-finite value detected");
  assert(not (time >= 5.2) or (primary_track_err < sep_req),
         "primary tracking error below 0.878 m after 5.2 s violated");
end MixedTeamCoordinateA;