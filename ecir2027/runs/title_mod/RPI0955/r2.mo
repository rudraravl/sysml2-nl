model SeaSnakeDockA
  "Free-base articulated underwater robot (32 kg, six 0.30 m capsules, alternating yaw/pitch joints, passive tail fin) approaching a fixed docking funnel with speed-scheduled pose control, contact transition, and a mid-scenario 70 N cross-current.";

  // ===== Physical parameters =====
  parameter Real m = 32.0 "robot mass [kg]";
  parameter Real Izz = 8.0 "yaw inertia about head [kg.m2]";
  parameter Real L_module = 0.30 "capsule module length [m]";
  parameter Integer nModules = 6 "number of capsule modules";
  parameter Real Xu = 8.0 "surge linear drag [N.s/m]";
  parameter Real Xuu = 6.0 "surge quadratic drag [N.s2/m2]";
  parameter Real Yv = 60.0 "sway linear drag [N.s/m]";
  parameter Real Nr = 16.0 "yaw rotational drag [N.m.s/rad]";

  // ===== Actuator / joint parameters =====
  parameter Real tau_max = 23.0 "per-joint actuator torque limit [N.m]";
  parameter Integer nAct = 12 "number of bounded joint actuators";
  parameter Real J_joint = 0.02 "joint inertia [kg.m2]";
  parameter Real b_joint = 0.05 "joint damping [N.m.s/rad]";
  parameter Real k_track = 5.0 "joint tracking gain [N.m/rad]";
  parameter Real c_track = 0.10 "joint tracking damping [N.m.s/rad]";
  parameter Real k_prop = 2000.0 "propulsion scaling [N]";
  parameter Real undulation_freq = 1.5 "CPG frequency [Hz]";
  parameter Real amp_max = 0.45 "max undulation amplitude [rad]";

  // ===== Speed / controller parameters =====
  parameter Real v_max = 2.5 "max surge speed [m/s]";
  parameter Real v_approach = 2.0 "approach speed [m/s]";
  parameter Real v_dock = 0.08 "docking creep speed [m/s]";
  parameter Real Ku = 100.0 "speed control gain [N.s/m]";
  parameter Real Kff = 20.0 "speed feedforward gain [N.s/m]";
  parameter Real Tmax = 120.0 "max propulsion thrust [N]";
  parameter Real k_yaw = 4.0 "heading-to-yawrate gain [1/s]";
  parameter Real r_cmd_max = 2.0 "max yaw-rate command [rad/s]";
  parameter Real K_r = 30.0 "yaw-rate gain [N.m.s/rad]";
  parameter Real M_yaw_max = 25.0 "max yaw moment [N.m]";
  parameter Real Kp_lat = 1200.0 "lateral position gain [N/m]";
  parameter Real Kd_lat = 330.0 "lateral velocity gain [N.s/m]";
  parameter Real Fy_max = 150.0 "max lateral control force [N]";

  // ===== Dock / capture geometry =====
  parameter Real dock_x = 0.0 "dock center x [m]";
  parameter Real dock_y = 0.0 "dock center y [m]";
  parameter Real capture_radius = 0.08 "compliant capture ring radius [m]";
  parameter Real capture_stiffness = 4000.0 "capture axial stiffness [N/m]";
  parameter Real capture_damping = 400.0 "capture axial damping [N.s/m]";
  parameter Real capture_stiffness_lat = 2500.0 "capture lateral stiffness [N/m]";
  parameter Real capture_damping_lat = 150.0 "capture lateral damping [N.s/m]";

  // ===== Disturbance =====
  parameter Real current_force = 70.0 "cross-current lateral disturbance [N]";
  parameter Real t_current_start = 8.0/3.0 "current onset [s] (middle third)";
  parameter Real t_current_end = 16.0/3.0 "current offset [s] (middle third)";

  // ===== Timing =====
  parameter Real Ts = 1.0/80.0 "sample period [s]";
  parameter Real t_final = 8.0 "scenario duration [s]";

  // ===== Robot rigid-body states =====
  Real x(start=-8.0, fixed=true) "head x position [m]";
  Real y(start=0.0, fixed=true) "head y position [m]";
  Real psi(start=0.0, fixed=true) "yaw heading [rad]";
  Real u(start=0.0, fixed=true) "surge speed (body x) [m/s]";
  Real v(start=0.0, fixed=true) "sway speed (body y) [m/s]";
  Real r(start=0.0, fixed=true) "yaw rate [rad/s]";

  // ===== Articulated joint states (6 alternating yaw/pitch joints) =====
  Real q[6](each start=0.0, each fixed=true) "joint angles [rad]";
  Real qd[6](each start=0.0, each fixed=true) "joint angular rates [rad/s]";

  // ===== Actuators (12 bounded: 2 antagonistic per joint) =====
  Real tau_cmd[12] "commanded joint torques [N.m]";
  Real tau_sat[12] "saturated joint torques [N.m]";
  Real q_des[6] "CPG desired joint angles [rad]";
  Real amp "undulation amplitude [rad]";
  Real undulation_phase(start=0.0, fixed=true) "CPG phase [rad]";

  // ===== Controller intermediates =====
  Real range_to_dock "range to dock center [m]";
  Real u_des "desired surge speed [m/s]";
  Real desired_psi "desired heading [rad]";
  Real yaw_err "wrapped heading error [rad]";
  Real r_cmd "yaw-rate command [rad/s]";
  Real thrust_demand "unbounded thrust demand [N]";
  Real thrust "applied propulsion thrust [N]";
  Real M_yaw_raw "unbounded yaw moment [N.m]";
  Real M_yaw "applied yaw moment [N.m]";
  Real vy_inert "inertial lateral velocity [m/s]";
  Real Fy_ctrl "lateral control force (inertial) [N]";
  Real Fy_ctrl_sat "saturated lateral control force [N]";
  Real in_zone "centering-zone indicator";
  Real in_contact "axial-contact indicator";
  Boolean captured "capture established";
  Real primary_tracking_error "primary tracking error [m]";

  // ===== Contact =====
  Real pen_x "axial penetration into capture ring [m]";
  Real Fc_x "axial contact force (inertial) [N]";
  Real Fc_y "lateral contact force (inertial) [N]";
  Real contact_force "contact force magnitude [N]";

  // ===== Disturbance =====
  Real current_Fy "applied current lateral force [N]";

  // ===== External force helpers =====
  Real Fext_x "external inertial force x [N]";
  Real Fext_y "external inertial force y [N]";
  Real Fbx "external force in body x [N]";
  Real Fby "external force in body y [N]";

  // ===== Sensors =====
  Real sonar_range "sonar range to dock [m]";
  Real pressure_depth "pressure-derived depth [m]";
  Real imu_yaw "IMU yaw [rad]";
  Real imu_yawrate "IMU yaw rate [rad/s]";
  Real optical_x "short-range optical relative pose x [m]";
  Real optical_y "short-range optical relative pose y [m]";
  Real optical_yaw "short-range optical relative pose yaw [rad]";
  Real optical_active "optical sensor availability flag";

  // ===== Constants =====
  constant Real pi = 3.14159265358979;
  constant Real eps = 1.0e-6;

equation
  // ===== CPG undulation =====
  der(undulation_phase) = 2.0*pi*undulation_freq;
  amp = sqrt(max(eps, abs(thrust))/k_prop);
  for i in 1:6 loop
    q_des[i] = amp * sin(undulation_phase - (i - 1)*2.0*pi/6.0);
  end for;

  // ===== Twelve bounded actuators: antagonistic pairs per joint =====
  for i in 1:6 loop
    tau_cmd[2*i - 1] = k_track*(q_des[i] - q[i]) - c_track*qd[i];
    tau_cmd[2*i]     = -(k_track*(q_des[i] - q[i]) - c_track*qd[i]);
    tau_sat[2*i - 1] = if tau_cmd[2*i - 1] >  tau_max then  tau_max
                       else if tau_cmd[2*i - 1] < -tau_max then -tau_max
                       else tau_cmd[2*i - 1];
    tau_sat[2*i]     = if tau_cmd[2*i]     >  tau_max then  tau_max
                       else if tau_cmd[2*i]     < -tau_max then -tau_max
                       else tau_cmd[2*i];
    der(q[i]) = qd[i];
    J_joint*der(qd[i]) = (tau_sat[2*i - 1] - tau_sat[2*i]) - b_joint*qd[i];
  end for;

  // ===== Guidance: range and heading =====
  range_to_dock = sqrt(max(eps, (x - dock_x)*(x - dock_x) + (y - dock_y)*(y - dock_y)));
  if in_zone > 0.5 then
    desired_psi = 0.0;
  else
    desired_psi = atan2(dock_y - y, dock_x - x);
  end if;
  yaw_err = atan2(sin(desired_psi - psi), cos(desired_psi - psi));

  // ===== Zones =====
  in_zone    = if x > (dock_x - capture_radius) then 1.0 else 0.0;
  in_contact = if x >  dock_x                  then 1.0 else 0.0;

  // ===== Speed-scheduled desired surge speed =====
  if in_contact > 0.5 then
    u_des = 0.0;
  else
    u_des = v_dock + (v_approach - v_dock)*min(1.0, range_to_dock);
  end if;

  // ===== Thrust (bounded), with feedforward compensating cruise drag =====
  thrust_demand = Ku*(u_des - u) + Kff*u_des;
  thrust = if thrust_demand >  Tmax then  Tmax
           else if thrust_demand < -Tmax then -Tmax
           else thrust_demand;

  // ===== Yaw-rate command and bounded yaw moment =====
  r_cmd = if k_yaw*yaw_err >  r_cmd_max then  r_cmd_max
          else if k_yaw*yaw_err < -r_cmd_max then -r_cmd_max
          else k_yaw*yaw_err;
  M_yaw_raw = K_r*(r_cmd - r);
  M_yaw = if M_yaw_raw >  M_yaw_max then  M_yaw_max
          else if M_yaw_raw < -M_yaw_max then -M_yaw_max
          else M_yaw_raw;

  // ===== Lateral alignment control (disturbance rejection) =====
  vy_inert = -u*sin(psi) + v*cos(psi);
  Fy_ctrl = -Kp_lat*(y - dock_y) - Kd_lat*vy_inert;
  Fy_ctrl_sat = if Fy_ctrl >  Fy_max then  Fy_max
                else if Fy_ctrl < -Fy_max then -Fy_max
                else Fy_ctrl;

  // ===== Cross-current disturbance (middle third of scenario) =====
  current_Fy = if time >= t_current_start and time <= t_current_end then current_force else 0.0;

  // ===== Compliant capture contact =====
  pen_x = if x > dock_x then (x - dock_x) else 0.0;
  if in_zone > 0.5 then
    Fc_x = -capture_stiffness*pen_x - capture_damping*max(0.0, u);
    Fc_y = -capture_stiffness_lat*(y - dock_y) - capture_damping_lat*vy_inert;
  else
    Fc_x = 0.0;
    Fc_y = 0.0;
  end if;
  contact_force = sqrt(max(eps, Fc_x*Fc_x + Fc_y*Fc_y));

  // ===== Capture flag =====
  captured = (in_zone > 0.5) and (abs(y - dock_y) < capture_radius) and (abs(yaw_err) < 0.5) and (abs(u) < 0.6);

  // ===== External forces and body-frame transform =====
  Fext_x = Fc_x;
  Fext_y = current_Fy + Fy_ctrl_sat + Fc_y;
  Fbx = Fext_x*cos(psi) + Fext_y*sin(psi);
  Fby = -Fext_x*sin(psi) + Fext_y*cos(psi);

  // ===== Rigid-body kinematics and dynamics (3-DOF planar) =====
  der(x) = u*cos(psi) - v*sin(psi);
  der(y) = u*sin(psi) + v*cos(psi);
  der(psi) = r;
  m*der(u) = m*v*r + thrust - Xu*u - Xuu*u*abs(u) + Fbx;
  m*der(v) = -m*u*r - Yv*v + Fby;
  Izz*der(r) = M_yaw - Nr*r;

  // ===== Primary tracking error =====
  primary_tracking_error = range_to_dock;

  // ===== Sensors =====
  sonar_range = range_to_dock;
  pressure_depth = 0.5 "nominal horizontal-plane operating depth [m]";
  imu_yaw = psi;
  imu_yawrate = r;
  optical_active = if sonar_range < 2.0 then 1.0 else 0.0;
  optical_x = if optical_active > 0.5 then (x - dock_x) else 0.0;
  optical_y = if optical_active > 0.5 then (y - dock_y) else 0.0;
  optical_yaw = if optical_active > 0.5 then psi else 0.0;

  annotation(
    experiment(StartTime=0.0, StopTime=8.0, Tolerance=1.0e-4, Interval=0.0125),
    Documentation(info="SeaSnakeDockA: six-module articulated underwater robot docking demonstration. 80 Hz output interval over 8 s. Speed-scheduled pose control with contact transition; 70 N cross-current applied during the middle third. All actuator torques bounded to +-23 N.m; thrust, yaw moment, lateral force, and speed are bounded. Contact force limited by compliant capture ring; capture established when aligned and within the ring."));
end SeaSnakeDockA;