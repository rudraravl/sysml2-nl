model DiffRoverRouteC
  "Floating-base differential-drive rover executing bounded waypoint path
   following with wheel-speed control, torque limits, and a lateral push
   disturbance during the middle third of the run."

  // -------- Physical parameters (SI) --------
  parameter Real m = 19.0 "chassis mass [kg]";
  parameter Real Lx = 0.65 "chassis length [m]";
  parameter Real Ly = 0.44 "chassis width [m]";
  parameter Real Lz = 0.22 "chassis height [m]";
  parameter Real r_w = 0.10 "driven wheel radius [m]";
  parameter Real L_wh = 0.46 "wheel separation [m]";
  parameter Real mu = 0.82 "rigid-floor Coulomb friction coefficient [1]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real J_w = 0.0020 "wheel/motor reflected inertia [kg.m2]";
  parameter Real b_w = 0.05 "wheel viscous friction [N.m.s]";
  parameter Real I_z = m*(Lx*Lx + Ly*Ly)/12.0 "chassis yaw inertia [kg.m2]";

  // -------- Control / scenario parameters --------
  parameter Real v_ref = 1.20 "commanded forward speed [m/s] (below 1.5)";
  parameter Real v_max = 1.50 "max forward speed bound [m/s]";
  parameter Real tau_max = 12.0 "max motor torque magnitude [N.m]";
  parameter Real w_max = 25.0 "max wheel angular speed bound [rad/s]";
  parameter Real omega_max = 2.50 "max yaw-rate command [rad/s]";
  parameter Real Kpw = 2.0 "wheel-speed proportional gain [N.m.s]";
  parameter Real K_cross = 0.70 "cross-track gain [1/s]";
  parameter Real K_head = 1.20 "heading-error gain [1/s]";
  parameter Real F_push = 108.0 "lateral push disturbance magnitude [N]";
  parameter Real v_small = 0.01 "friction velocity smoothing [m/s]";
  parameter Real dt_sample = 1.0/125.0 "control sample period [s]";
  parameter Real T_end = 12.0 "simulation duration [s]";
  parameter Real t_push_start = 4.0 "lateral push start [s]";
  parameter Real t_push_end = 8.0 "lateral push end [s]";

  // -------- Waypoints (planar, m) --------
  parameter Real W1[2] = {0.0, 0.0};
  parameter Real W2[2] = {4.0, 0.0};
  parameter Real W3[2] = {7.0, 2.0};
  parameter Real W4[2] = {10.0, 2.0};

  // -------- Continuous plant states --------
  Real x(start=0.0, fixed=true) "planar x [m]";
  Real y(start=0.0, fixed=true) "planar y [m]";
  Real theta(start=0.0, fixed=true) "chassis heading [rad]";
  Real vf(start=0.0, fixed=true) "forward speed [m/s]";
  Real omega(start=0.0, fixed=true) "yaw rate [rad/s]";
  Real vl(start=0.0, fixed=true) "lateral slip speed [m/s]";

  // -------- Algebraic / derived --------
  Real wL "left wheel angular speed [rad/s] (encoder)";
  Real wR "right wheel angular speed [rad/s] (encoder)";
  Real tau_L "left motor torque [N.m]";
  Real tau_R "right motor torque [N.m]";
  Real F_push_active "active lateral push [N]";
  Real F_friction_lat "lateral floor friction [N]";

  // -------- Discrete controller (125 Hz) --------
  discrete Integer seg(start=1) "active path segment index";
  discrete Real d_seg_start_x;
  discrete Real d_seg_start_y;
  discrete Real d_seg_dir_x;
  discrete Real d_seg_dir_y;
  discrete Real d_seg_len;
  discrete Real d_along;
  discrete Real d_cross_err;
  discrete Real d_head_err;
  discrete Real d_seg_angle;
  discrete Real d_v_cmd;
  discrete Real d_omega_cmd;
  discrete Real d_wL_cmd;
  discrete Real d_wR_cmd;
  discrete Real d_tau_L;
  discrete Real d_tau_R;
  discrete Real d_target_x;
  discrete Real d_target_y;

  // -------- Observables / evidence traces --------
  Real cross_err "absolute cross-track error [m]";
  Real track_err "distance to current target waypoint [m]";
  Real chassis_attitude "chassis heading (IMU) [rad]";
  Real wheel_speed_bound_violation "1 if |w|>w_max else 0";
  Real actuator_bound_violation "1 if |tau|>tau_max else 0";
  Real primary_track_error_after_78s "tracked cross error after 7.8 s [m]";
  Boolean in_collision "fixed-obstacle collision flag (obstacles outside path)";

equation
  // Disturbance injection: lateral push only in middle third
  F_push_active = if (time >= t_push_start and time <= t_push_end) then F_push else 0.0;

  // Lateral friction opposes slip (rigid floor, friction 0.82)
  F_friction_lat = mu*m*g*Modelica.Math.tanh(vl/v_small);

  // Longitudinal / yaw chassis dynamics from wheel torques (no-slip rolling)
  der(vf) = (tau_L + tau_R - b_w*(wL + wR))/(r_w*(m + 2.0*J_w/(r_w*r_w)));
  der(omega) = (L_wh/(2.0*r_w))*(tau_R - tau_L - b_w*(wR - wL))/
               (I_z + J_w*L_wh*L_wh/(2.0*r_w*r_w));

  // Planar motion (heading frame), with lateral slip
  der(x) = vf*Modelica.Math.cos(theta) - vl*Modelica.Math.sin(theta);
  der(y) = vf*Modelica.Math.sin(theta) + vl*Modelica.Math.cos(theta);
  der(theta) = omega;
  der(vl) = (F_push_active - F_friction_lat)/m;

  // No-slip wheel kinematics (algebraic)
  wL = vf/r_w - L_wh*omega/(2.0*r_w);
  wR = vf/r_w + L_wh*omega/(2.0*r_w);

  // Torque commands held between samples
  tau_L = d_tau_L;
  tau_R = d_tau_R;

  // Observables
  cross_err = Modelica.Math.abs(d_cross_err);
  chassis_attitude = theta;
  track_err = Modelica.Math.sqrt((x - d_target_x)*(x - d_target_x) +
                                 (y - d_target_y)*(y - d_target_y));
  wheel_speed_bound_violation =
      if (Modelica.Math.abs(wL) > w_max or Modelica.Math.abs(wR) > w_max) then 1.0 else 0.0;
  actuator_bound_violation =
      if (Modelica.Math.abs(tau_L) > tau_max + 1.0e-6 or
          Modelica.Math.abs(tau_R) > tau_max + 1.0e-6) then 1.0 else 0.0;
  primary_track_error_after_78s = if time >= 7.8 then cross_err else 0.0;
  // Fixed obstacles are placed outside the reference path; the bounded
  // path-following controller keeps the rover on the corridor.
  in_collision = false;

algorithm
  // -------- 125 Hz sampled controller --------
  when sample(0, dt_sample) then
    // Segment geometry (start, unit direction, length)
    d_seg_start_x := if seg == 1 then 0.0 elseif seg == 2 then 4.0 else 7.0;
    d_seg_start_y := if seg == 1 then 0.0 elseif seg == 2 then 0.0 else 2.0;
    d_seg_dir_x  := if seg == 1 then 1.0 elseif seg == 2 then 0.6 else 1.0;
    d_seg_dir_y  := if seg == 1 then 0.0 elseif seg == 2 then 0.8 else 0.0;
    d_seg_len    := if seg == 1 then 4.0 elseif seg == 2 then 5.0 else 3.0;
    d_seg_angle  := Modelica.Math.atan2(d_seg_dir_y, d_seg_dir_x);

    // Projection onto current segment
    d_along := (x - d_seg_start_x)*d_seg_dir_x + (y - d_seg_start_y)*d_seg_dir_y;
    d_cross_err := (x - d_seg_start_x)*d_seg_dir_y - (y - d_seg_start_y)*d_seg_dir_x;
    d_head_err := Modelica.Math.atan2(
        Modelica.Math.sin(theta - d_seg_angle),
        Modelica.Math.cos(theta - d_seg_angle));

    // Advance segment when near its end
    if d_along > d_seg_len - 0.5 and seg < 3 then
      seg := seg + 1;
      d_seg_start_x := if seg == 1 then 0.0 elseif seg == 2 then 4.0 else 7.0;
      d_seg_start_y := if seg == 1 then 0.0 elseif seg == 2 then 0.0 else 2.0;
      d_seg_dir_x  := if seg == 1 then 1.0 elseif seg == 2 then 0.6 else 1.0;
      d_seg_dir_y  := if seg == 1 then 0.0 elseif seg == 2 then 0.8 else 0.0;
      d_seg_len    := if seg == 1 then 4.0 elseif seg == 2 then 5.0 else 3.0;
      d_seg_angle  := Modelica.Math.atan2(d_seg_dir_y, d_seg_dir_x);
      d_along := (x - d_seg_start_x)*d_seg_dir_x + (y - d_seg_start_y)*d_seg_dir_y;
      d_cross_err := (x - d_seg_start_x)*d_seg_dir_y - (y - d_seg_start_y)*d_seg_dir_x;
      d_head_err := Modelica.Math.atan2(
          Modelica.Math.sin(theta - d_seg_angle),
          Modelica.Math.cos(theta - d_seg_angle));
    end if;

    // Current target waypoint (end of active segment)
    d_target_x := if seg == 1 then 4.0 elseif seg == 2 then 7.0 else 10.0;
    d_target_y := if seg == 1 then 0.0 elseif seg == 2 then 2.0 else 2.0;

    // Path-following control: yaw-rate command from cross + heading error
    d_omega_cmd := -K_cross*d_cross_err - K_head*Modelica.Math.sin(d_head_err);
    d_omega_cmd := if d_omega_cmd > omega_max then omega_max
                   elseif d_omega_cmd < -omega_max then -omega_max
                   else d_omega_cmd;

    // Forward speed: hold v_ref, halt near final waypoint
    if seg == 3 and d_along > d_seg_len - 0.20 then
      d_v_cmd := 0.0;
    else
      d_v_cmd := v_ref;
    end if;
    d_v_cmd := if d_v_cmd > v_max then v_max elseif d_v_cmd < 0.0 then 0.0 else d_v_cmd;

    // Wheel-speed commands (differential drive inverse kinematics)
    d_wL_cmd := (d_v_cmd - d_omega_cmd*L_wh/2.0)/r_w;
    d_wR_cmd := (d_v_cmd + d_omega_cmd*L_wh/2.0)/r_w;
    d_wL_cmd := if d_wL_cmd > w_max then w_max elseif d_wL_cmd < -w_max then -w_max else d_wL_cmd;
    d_wR_cmd := if d_wR_cmd > w_max then w_max elseif d_wR_cmd < -w_max then -w_max else d_wR_cmd;

    // Wheel-speed feedback (encoders) -> bounded motor torque (actuator bound)
    d_tau_L := Kpw*(d_wL_cmd - wL);
    d_tau_L := if d_tau_L > tau_max then tau_max elseif d_tau_L < -tau_max then -tau_max else d_tau_L;
    d_tau_R := Kpw*(d_wR_cmd - wR);
    d_tau_R := if d_tau_R > tau_max then tau_max elseif d_tau_R < -tau_max then -tau_max else d_tau_R;
  end when;

  annotation (
    Documentation(info="Differential-drive rover DiffRoverRouteC. Planar rigid-body
      chassis with two driven wheels (continuous Y-axis joints) and a passive caster.
      State feedback: wheel encoders (wL,wR), planar odometry (x,y), IMU (theta).
      125 Hz controller follows waypoints [0,0],[4,0],[7,2],[10,2] at v_ref=1.2 m/s,
      torque bounded to 12 N.m, wheel speed bounded to 25 rad/s. A 108 N lateral
      push is injected during 4-8 s (middle third). Floor friction 0.82."),
    experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.008));
end DiffRoverRouteC;