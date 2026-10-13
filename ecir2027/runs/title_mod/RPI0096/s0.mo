model DuctInspectTouchF
  "Free-base aerial robot: ducted-fan inspection with compliant probe contact"

  // ===== Physical parameters =====
  parameter Modelica.Units.SI.Mass m = 2.7 "Body mass";
  parameter Modelica.Units.SI.Length L0 = 0.18 "Probe rest length along body X";
  parameter Modelica.Units.SI.Acceleration g = 9.81 "Gravitational acceleration";
  parameter Modelica.Units.SI.MomentOfInertia Iyy = 0.02 "Pitch moment of inertia";
  parameter Modelica.Units.SI.Length fan_arm = 0.15 "Fan moment arm from center";
  parameter Modelica.Units.SI.Force F_fan_max = 22.0 "Max thrust per fan";
  parameter Modelica.Units.SI.Force F_act_max = 20.0 "Max probe-force actuator";
  parameter Modelica.Units.SI.CoefficientOfFriction mu_wall = 0.55 "Wall friction coefficient";
  parameter Modelica.Units.SI.Length x_wall = 3.0 "Wall x-position";
  parameter Modelica.Units.SI.Length z_setpoint = 1.0 "Desired hover height";
  parameter Modelica.Units.SI.Length standoff = 0.01 "Pre-contact standoff distance";
  parameter Modelica.Units.SI.Force F_contact_des = 8.0 "Desired contact force (5-14 N)";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_contact = 2000.0 "Contact/probe stiffness";
  parameter Modelica.Units.SI.TranslationalDampingConstant d_contact = 30.0 "Contact/probe damping";
  parameter Modelica.Units.SI.Force F_wind = 4.35 "Tangential wind disturbance";
  parameter Modelica.Units.SI.Length x_init = 0.5 "Initial x position";
  parameter Modelica.Units.SI.Length z_init = 1.0 "Initial z position";
  parameter Modelica.Units.SI.Velocity v_approach_max = 0.5 "Max approach speed";

  // ===== Control gains =====
  parameter Real Kp_vel = 2.0 "X velocity loop proportional gain";
  parameter Real Kp_z = 10.0 "Z position proportional gain";
  parameter Real Kd_z = 8.0 "Z velocity derivative gain";
  parameter Real Kp_att = 40.0 "Attitude proportional gain";
  parameter Real Kd_att = 10.0 "Attitude derivative gain";
  parameter Real Kp_force = 0.5 "Force loop proportional gain";
  parameter Real Kd_force = 0.1 "Force loop derivative gain";

  // ===== Timing =====
  parameter Modelica.Units.SI.Time t_contact_start = 15.0 "Contact phase start (last quarter of 20 s)";
  parameter Modelica.Units.SI.Time t_wind_start = 6.6667 "Wind start (middle third)";
  parameter Modelica.Units.SI.Time t_wind_end = 13.3333 "Wind end (middle third)";

  // ===== Numerical safeguard =====
  parameter Real eps = 1.0e-6 "Small constant for zero-error branch protection";

  // ===== Dynamic states =====
  Modelica.Units.SI.Length x "Body center x-position";
  Modelica.Units.SI.Length z "Body center z-position";
  Modelica.Units.SI.Velocity vx "Body x-velocity";
  Modelica.Units.SI.Velocity vz "Body z-velocity";
  Modelica.Units.SI.Angle theta "Pitch angle";
  Modelica.Units.SI.AngularVelocity omega "Pitch angular velocity";

  // ===== Probe tip kinematics =====
  Modelica.Units.SI.Length x_tip "Probe tip x-position";
  Modelica.Units.SI.Length z_tip "Probe tip z-position";
  Modelica.Units.SI.Velocity vx_tip "Probe tip x-velocity";
  Modelica.Units.SI.Velocity vz_tip "Probe tip z-velocity";
  Modelica.Units.SI.Length penetration "Wall penetration by probe tip";
  Boolean in_contact "Contact flag";

  // ===== Contact forces =====
  Modelica.Units.SI.Force F_normal "Normal contact force on probe";
  Modelica.Units.SI.Force F_friction "Tangential friction force";
  Modelica.Units.SI.Torque M_contact "Moment from contact about body center";

  // ===== Probe-force actuator =====
  Modelica.Units.SI.Force F_act "Probe-force actuator command";
  Modelica.Units.SI.Force F_act_sat "Saturated probe-force actuator";

  // ===== Wind disturbance =====
  Boolean wind_active "Wind disturbance active flag";
  Modelica.Units.SI.Force F_wind_z "Wind force in z-direction (tangential to wall)";

  // ===== Fan thrust =====
  Modelica.Units.SI.Force T1 "Fan 1 thrust (front)";
  Modelica.Units.SI.Force T2 "Fan 2 thrust (front)";
  Modelica.Units.SI.Force T3 "Fan 3 thrust (rear)";
  Modelica.Units.SI.Force T4 "Fan 4 thrust (rear)";
  Modelica.Units.SI.Force T_total "Total collective thrust";
  Modelica.Units.SI.Torque M_pitch "Net pitch moment from fans";
  Modelica.Units.SI.Force Fx_thrust "Thrust x-component in world frame";
  Modelica.Units.SI.Force Fz_thrust "Thrust z-component in world frame";
  Modelica.Units.SI.Force max_fan_thrust "Maximum fan thrust among four channels";

  // ===== Control variables =====
  Real phase "Control phase: 0=approach, 1=contact";
  Modelica.Units.SI.Velocity vx_des "Desired x-velocity (approach)";
  Modelica.Units.SI.Acceleration ax_cmd "Commanded x-acceleration";
  Modelica.Units.SI.Acceleration az_cmd "Commanded z-acceleration";
  Modelica.Units.SI.Angle theta_des "Desired pitch angle";
  Modelica.Units.SI.Force F_total_cmd "Commanded total thrust";
  Modelica.Units.SI.Torque M_cmd "Commanded pitch moment";
  Modelica.Units.SI.Force T_front_cmd "Front pair commanded thrust";
  Modelica.Units.SI.Force T_rear_cmd "Rear pair commanded thrust";
  Modelica.Units.SI.Force T_front_sat "Front pair saturated thrust";
  Modelica.Units.SI.Force T_rear_sat "Rear pair saturated thrust";
  Modelica.Units.SI.Length x_target "Target x stand-off position";

  // ===== Sensors =====
  Modelica.Units.SI.Length x_est "Estimated x (IMU integrated)";
  Modelica.Units.SI.Length z_est "Estimated z (IMU integrated)";
  Modelica.Units.SI.Velocity vx_est "Estimated vx (optical flow)";
  Modelica.Units.SI.Velocity vz_est "Estimated vz (optical flow)";
  Modelica.Units.SI.Angle theta_est "Estimated pitch (IMU)";
  Modelica.Units.SI.AngularVelocity omega_est "Estimated pitch rate (IMU)";
  Modelica.Units.SI.Force F_probe_sensed "Sensed probe normal force";
  Modelica.Units.SI.Length range_lidar "Lidar range to wall";

  // ===== Verification observables =====
  Modelica.Units.SI.Length tracking_error "Primary tracking error (stand-off)";
  Modelica.Units.SI.Angle abs_theta "Absolute pitch angle";
  Modelica.Units.SI.Velocity approach_speed "Current speed magnitude";
  Boolean fan_bound_ok "Fan thrust within 22 N bound";
  Boolean attitude_ok "Attitude within 45 deg bound";
  Boolean contact_force_ok "Contact force in [5, 14] N";
  Boolean tracking_ok "Tracking error below 0.032 m after 13 s";
  Boolean no_fan_collision "No fan collision with wall";

equation
  // ===== Probe tip kinematics =====
  x_tip = x + L0 * cos(theta);
  z_tip = z - L0 * sin(theta);
  vx_tip = vx - L0 * sin(theta) * omega;
  vz_tip = vz - L0 * cos(theta) * omega;

  // ===== Contact model (wall is fixed collidable box at x = x_wall) =====
  penetration = x_tip - x_wall;
  in_contact = penetration > 0.0;

  // Normal contact force (compliant spring-damper when penetrating)
  F_normal = if penetration > 0.0 then
    k_contact * penetration + d_contact * vx_tip
  else
    0.0;

  // Regularized Coulomb friction (tangential to wall, along z)
  // Zero-error branch: when vz_tip = 0, friction = 0 (no stiction modeled)
  F_friction = if in_contact and F_normal > eps then
    -mu_wall * F_normal * vz_tip / (abs(vz_tip) + 0.01)
  else
    0.0;

  // Moment from contact force about body center
  M_contact = L0 * cos(theta) * F_friction - L0 * sin(theta) * F_normal;

  // ===== Wind disturbance (tangential, middle third of run) =====
  wind_active = (time >= t_wind_start) and (time <= t_wind_end);
  F_wind_z = if wind_active then F_wind else 0.0;

  // ===== Probe-force actuator (bounded) =====
  F_act = if phase > 0.5 then
    F_contact_des + Kp_force * (F_contact_des - F_normal) - Kd_force * m * vx
  else
    0.0;
  F_act_sat = max(0.0, min(F_act_max, F_act));

  // ===== Thrust in world frame =====
  Fx_thrust = T_total * sin(theta);
  Fz_thrust = T_total * cos(theta);

  // ===== Equations of motion =====
  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;
  der(vx) = (Fx_thrust + F_act_sat * cos(theta) - F_normal) / m;
  der(vz) = (Fz_thrust - m * g - F_act_sat * sin(theta) + F_friction + F_wind_z) / m;
  der(omega) = (M_pitch + M_contact) / Iyy;

  // ===== Position-to-impedance hybrid control =====
  phase = if time >= t_contact_start then 1.0 else 0.0;
  x_target = x_wall - L0 - standoff;

  // Approach phase: velocity-limited position control via fans
  vx_des = max(-v_approach_max, min(v_approach_max, 2.0 * (x_target - x)));
  ax_cmd = Kp_vel * (vx_des - vx);
  az_cmd = Kp_z * (z_setpoint - z) - Kd_z * vz;

  // Desired pitch from desired acceleration (tilt to translate)
  theta_des = atan2(ax_cmd, az_cmd + g);

  // Thrust magnitude with safe norm (zero-error branch protected)
  F_total_cmd = m * sqrt(max(eps * eps, ax_cmd * ax_cmd + (az_cmd + g) * (az_cmd + g)));

  // Attitude controller (PD)
  M_cmd = Kp_att * (theta_des - theta) - Kd_att * omega;

  // ===== Fan allocation (4 channels, bounded per fan) =====
  // M_pitch = fan_arm * ((T3+T4) - (T1+T2)); rear-up = nose-up
  T_front_cmd = (F_total_cmd - M_cmd / fan_arm) / 2.0;
  T_rear_cmd = (F_total_cmd + M_cmd / fan_arm) / 2.0;
  T_front_sat = max(0.0, min(2.0 * F_fan_max, T_front_cmd));
  T_rear_sat = max(0.0, min(2.0 * F_fan_max, T_rear_cmd));
  T1 = T_front_sat / 2.0;
  T2 = T_front_sat / 2.0;
  T3 = T_rear_sat / 2.0;
  T4 = T_rear_sat / 2.0;
  T_total = T1 + T2 + T3 + T4;
  M_pitch = fan_arm * ((T3 + T4) - (T1 + T2));

  // ===== Sensors (ideal estimates for state, command, and sensor traces) =====
  x_est = x;
  z_est = z;
  vx_est = vx;
  vz_est = vz;
  theta_est = theta;
  omega_est = omega;
  F_probe_sensed = F_normal;
  range_lidar = max(0.0, x_wall - x);

  // ===== Verification observables =====
  tracking_error = abs(x - x_target);
  abs_theta = abs(theta);
  approach_speed = sqrt(max(eps * eps, vx * vx + vz * vz));
  max_fan_thrust = max(max(T1, T2), max(T3, T4));
  fan_bound_ok = max_fan_thrust <= F_fan_max + eps;
  attitude_ok = abs_theta <= 0.785398163397 "45 deg bound";
  contact_force_ok = (not in_contact) or (F_normal >= 5.0 and F_normal <= 14.0);
  tracking_ok = (time < 13.0) or (tracking_error < 0.032);
  no_fan_collision = (x + fan_arm) < x_wall "Front fans remain clear of wall";

initial equation
  x = x_init;
  z = z_init;
  vx = 0.0;
  vz = 0.0;
  theta = 0.0;
  omega = 0.0;

annotation(
  experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
  Documentation(info = "Free-base aerial robot (2.7 kg cylindrical body, 4 ducted fans max 22 N each) with 0.18 m compliant probe along body X. Mission: approach vertical wall (friction 0.55), establish bounded normal probe force (5-14 N) via probe-force actuator, hold contact for last quarter (15-20 s). Position-to-impedance hybrid control: fans provide position/attitude control, probe actuator provides force control. 4.35 N tangential wind disturbance during middle third (6.67-13.33 s). 500 Hz, 20 s run. Verification: thrust and attitude bounds, approach speed, contact force 5-14 N, no fan collision, tracking error < 0.032 m after 13 s, no NaN/infinite values."));
end DuctInspectTouchF;