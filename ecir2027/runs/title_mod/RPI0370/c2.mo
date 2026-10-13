model ParallelGripInsertD "Instrumented contact-rich parallel-gripper peg-in-hole insertion system"

  parameter Real m_palm = 6.0 "Palm mass [kg]";
  parameter Real m_finger = 0.5 "Each finger mass [kg]";
  parameter Real travel = 0.05 "Prismatic joint travel [m]";
  parameter Real F_act_max = 45.0 "Per-finger actuator force limit [N]";
  parameter Real clearance = 0.001 "Peg-hole radial clearance [m]";
  parameter Real depth_target = 0.06 "Required insertion depth [m]";
  parameter Real mu = 0.35 "Contact friction coefficient";
  parameter Real F_dist = 10.0 "Lateral disturbance force magnitude [N]";
  parameter Real f_ctrl = 200.0 "Controller update rate [Hz]";
  parameter Real T_sim = 14.0 "Total simulation duration [s]";
  parameter Real err_thresh = 0.002 "Alignment error threshold after settling [m]";
  parameter Real t_settle = 9.1 "Settling time requirement [s]";

  // Placeholder parameters not stated in requirement
  parameter Real peg_mass = 0.15 "Peg mass [kg], placeholder";
  parameter Real peg_length = 0.08 "Peg length [m], placeholder";
  parameter Real peg_radius = 0.012 "Peg radius [m], placeholder";
  parameter Real peg_inertia = peg_mass * peg_length * peg_length / 12.0 "Peg inertia [kg.m2]";
  parameter Real gap0 = 0.04 "Initial finger gap [m], placeholder";
  parameter Real pad_k = 8000.0 "Pad stiffness [N/m], placeholder";
  parameter Real pad_b = 60.0 "Pad damping [N.s/m], placeholder";
  parameter Real hole_k = 2.0e5 "Hole contact stiffness [N/m], placeholder";
  parameter Real hole_b = 200.0 "Hole contact damping [N.s/m], placeholder";
  parameter Real pad_preload = 0.0005 "Pad preload compression [m], placeholder";

  parameter Real Kp_ins = 300.0 "Insertion impedance position gain [N/m]";
  parameter Real Kd_ins = 25.0 "Insertion impedance damping [N.s/m]";
  parameter Real Kp_lat = 250.0 "Lateral impedance position gain [N/m]";
  parameter Real Kd_lat = 22.0 "Lateral impedance damping [N.s/m]";
  parameter Real Kp_tilt = 0.8 "Tilt impedance gain [N.m/rad]";
  parameter Real Kd_tilt = 0.08 "Tilt impedance damping [N.m.s/rad]";
  parameter Real F_ins_max = 30.0 "Axial insertion force limit [N], placeholder";
  parameter Real F_lat_max = 20.0 "Lateral force limit [N], placeholder";
  parameter Real tau_max = 1.0 "Tilt torque limit [N.m], placeholder";
  parameter Real vz_max = 0.015 "Bounded insertion speed [m/s], placeholder";
  parameter Real Kp_finger = 1200.0 "Finger position gain [N/m]";
  parameter Real Kd_finger = 50.0 "Finger velocity gain [N.s/m]";
  parameter Real eps_vel = 0.0005 "Velocity regularization for friction [m/s]";

  Real x_L(start = 0.0) "Left finger closure position [m]";
  Real v_L(start = 0.0) "Left finger velocity [m/s]";
  Real x_R(start = 0.0) "Right finger closure position [m]";
  Real v_R(start = 0.0) "Right finger velocity [m/s]";

  Real z_ins(start = 0.0) "Insertion depth [m]";
  Real vz_ins(start = 0.0) "Insertion velocity [m/s]";
  Real y_peg(start = 0.0008) "Peg lateral displacement [m]";
  Real vy_peg(start = 0.0) "Peg lateral velocity [m/s]";
  Real theta(start = 0.003) "Peg tilt angle [rad]";
  Real omega(start = 0.0) "Peg angular velocity [rad/s]";

  Real gap "Current finger gap [m]";
  Real grip_force "Total grip squeeze force [N]";
  Real F_pad_L "Left pad contact force [N]";
  Real F_pad_R "Right pad contact force [N]";
  Real compress_L "Left pad compression [m]";
  Real compress_R "Right pad compression [m]";
  Real F_hole_y "Hole wall contact force in y direction [N]";
  Real F_hole_n "Hole contact normal force magnitude [N]";
  Real F_hole_f "Hole friction force axial [N]";
  Real y_at_tip "Lateral displacement at peg tip [m]";

  Real Fx_sensor "Measured force x [N]";
  Real Fy_sensor "Measured force y [N]";
  Real Fz_sensor "Measured force z [N]";
  Real Tx_sensor "Measured torque x [N.m]";
  Real Ty_sensor "Measured torque y [N.m]";
  Real Tz_sensor "Measured torque z [N.m]";

  Real F_ins_raw "Raw commanded insertion force [N]";
  Real F_lat_raw "Raw commanded lateral force [N]";
  Real tau_raw "Raw commanded tilt torque [N.m]";
  Real F_ins_sat "Saturated insertion force [N]";
  Real F_lat_sat "Saturated lateral force [N]";
  Real tau_sat "Saturated tilt torque [N.m]";
  Real F_act_L_raw "Raw left actuator force [N]";
  Real F_act_R_raw "Raw right actuator force [N]";
  Real F_act_L "Bounded left actuator force [N]";
  Real F_act_R "Bounded right actuator force [N]";
  Real vz_cmd "Bounded insertion velocity command [m/s]";

  Real z_ref "Reference insertion depth [m]";
  Real x_L_ref "Left finger position reference [m]";
  Real x_R_ref "Right finger position reference [m]";

  Real F_disturbance "Active lateral fixture disturbance force [N]";

  Real tracking_error "Primary lateral alignment error [m]";
  Real insertion_depth "Current insertion depth [m]";
  Real peg_tilt "Current peg tilt magnitude [rad]";
  Real abs_F_act_L "Left actuator force magnitude [N]";
  Real abs_F_act_R "Right actuator force magnitude [N]";
  Real abs_F_ins "Insertion force magnitude [N]";
  Real abs_F_lat "Lateral force magnitude [N]";
  Boolean bounds_ok "All actuator and force bounds satisfied";
  Boolean tracking_ok "Tracking error below threshold after settling";
  Boolean depth_ok "Required insertion depth achieved";
  Boolean no_nan_inf "No NaN or infinite values";

equation

  gap = gap0 - x_L - x_R;

  compress_L = if x_L > (gap0 * 0.5 - peg_radius) then (x_L - (gap0 * 0.5 - peg_radius)) else 0.0;
  compress_R = if x_R > (gap0 * 0.5 - peg_radius) then (x_R - (gap0 * 0.5 - peg_radius)) else 0.0;

  F_pad_L = pad_k * compress_L + pad_b * v_L;
  F_pad_R = pad_k * compress_R + pad_b * v_R;

  grip_force = F_pad_L + F_pad_R;

  der(x_L) = v_L;
  der(x_R) = v_R;
  m_finger * der(v_L) = F_act_L - F_pad_L;
  m_finger * der(v_R) = F_act_R - F_pad_R;

  y_at_tip = y_peg + theta * peg_length * 0.5;

  F_hole_y = if y_at_tip > clearance then
      -hole_k * (y_at_tip - clearance) - hole_b * vy_peg
    elseif y_at_tip < -clearance then
      -hole_k * (y_at_tip + clearance) - hole_b * vy_peg
    else
      0.0;

  F_hole_n = if F_hole_y > 0.0 then F_hole_y else (-F_hole_y);

  F_hole_f = mu * F_hole_n * tanh(vz_ins / eps_vel);

  der(y_peg) = vy_peg;
  peg_mass * der(vy_peg) = F_lat_sat + F_disturbance + F_hole_y;

  der(z_ins) = vz_ins;
  peg_mass * der(vz_ins) = F_ins_sat - F_hole_f;

  der(theta) = omega;
  peg_inertia * der(omega) = tau_sat + F_hole_y * peg_length * 0.5;

  vz_cmd = if ((Kp_ins / Kd_ins) * (z_ref - z_ins)) > vz_max then vz_max
    elseif ((Kp_ins / Kd_ins) * (z_ref - z_ins)) < -vz_max then -vz_max
    else ((Kp_ins / Kd_ins) * (z_ref - z_ins));

  F_ins_raw = Kp_ins * (z_ref - z_ins) + Kd_ins * (vz_cmd - vz_ins);
  F_ins_sat = if F_ins_raw > F_ins_max then F_ins_max
    elseif F_ins_raw < -F_ins_max then -F_ins_max
    else F_ins_raw;

  F_lat_raw = Kp_lat * (0.0 - y_peg) + Kd_lat * (0.0 - vy_peg);
  F_lat_sat = if F_lat_raw > F_lat_max then F_lat_max
    elseif F_lat_raw < -F_lat_max then -F_lat_max
    else F_lat_raw;

  tau_raw = Kp_tilt * (0.0 - theta) + Kd_tilt * (0.0 - omega);
  tau_sat = if tau_raw > tau_max then tau_max
    elseif tau_raw < -tau_max then -tau_max
    else tau_raw;

  F_act_L_raw = Kp_finger * (x_L_ref - x_L) + Kd_finger * (0.0 - v_L);
  F_act_R_raw = Kp_finger * (x_R_ref - x_R) + Kd_finger * (0.0 - v_R);
  F_act_L = if F_act_L_raw > F_act_max then F_act_max
    elseif F_act_L_raw < -F_act_max then -F_act_max
    else F_act_L_raw;
  F_act_R = if F_act_R_raw > F_act_max then F_act_max
    elseif F_act_R_raw < -F_act_max then -F_act_max
    else F_act_R_raw;

  F_disturbance = if (time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0) then F_dist else 0.0;

  Fx_sensor = F_pad_R - F_pad_L;
  Fy_sensor = F_lat_sat + F_disturbance + F_hole_y;
  Fz_sensor = F_ins_sat - F_hole_f;
  Tx_sensor = tau_sat + F_hole_y * peg_length * 0.5;
  Ty_sensor = 0.0;
  Tz_sensor = 0.0;

  z_ref = if time < 4.0 then 0.0
    elseif time < 12.0 then
      (if (time - 4.0) * vz_max > depth_target then depth_target
       elseif (time - 4.0) * vz_max < 0.0 then 0.0
       else (time - 4.0) * vz_max)
    else depth_target;

  x_L_ref = gap0 * 0.5 - peg_radius + pad_preload;
  x_R_ref = gap0 * 0.5 - peg_radius + pad_preload;

  tracking_error = if y_peg > 0.0 then y_peg else (-y_peg);
  insertion_depth = z_ins;
  peg_tilt = if theta > 0.0 then theta else (-theta);
  abs_F_act_L = if F_act_L > 0.0 then F_act_L else (-F_act_L);
  abs_F_act_R = if F_act_R > 0.0 then F_act_R else (-F_act_R);
  abs_F_ins = if F_ins_sat > 0.0 then F_ins_sat else (-F_ins_sat);
  abs_F_lat = if F_lat_sat > 0.0 then F_lat_sat else (-F_lat_sat);

  bounds_ok = (abs_F_act_L <= F_act_max + 0.001) and (abs_F_act_R <= F_act_max + 0.001)
    and (abs_F_ins <= F_ins_max + 0.001) and (abs_F_lat <= F_lat_max + 0.001);
  tracking_ok = if time >= t_settle then tracking_error < err_thresh else true;
  depth_ok = z_ins >= depth_target;
  no_nan_inf = (x_L == x_L) and (x_R == x_R) and (z_ins == z_ins) and (y_peg == y_peg)
    and (theta == theta) and (vz_ins == vz_ins) and (vy_peg == vy_peg) and (omega == omega)
    and (F_ins_sat == F_ins_sat) and (F_lat_sat == F_lat_sat) and (F_hole_y == F_hole_y)
    and (tau_sat == tau_sat) and (grip_force == grip_force);

end ParallelGripInsertD;