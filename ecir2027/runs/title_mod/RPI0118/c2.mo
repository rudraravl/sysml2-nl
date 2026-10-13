model CoaxLiftTouchD "Instrumented coaxial free-base aerial robot with position-to-impedance contact control"

  // Physical constants
  constant Real g(unit="m/s2") = 9.81;
  constant Real eps(unit="1") = 1.0e-6;
  constant Real eps_norm(unit="1") = 1.0e-6;

  // Platform and payload parameters
  parameter Real m_platform(unit="kg") = 4.4 "cargo platform mass";
  parameter Real m_payload(unit="kg") = 1.2 "payload mass";
  parameter Real L_cable(unit="m") = 0.70 "massless cable length";
  parameter Real m_total(unit="kg") = m_platform + m_payload;

  // Initial conditions
  parameter Real x0(unit="m") = 1.5 "initial platform x";
  parameter Real z0(unit="m") = 1.0 "initial platform z";

  // Rotor parameters
  parameter Integer N_rotors = 8 "number of rotor thrust channels";
  parameter Real Tmax(unit="N") = 10.0 "per-rotor thrust limit";
  parameter Real T_total_max(unit="N") = 0.95*N_rotors*Tmax "commanded total thrust limit";

  // Geometry placeholders; not specified by requirement
  parameter Real R_arm(unit="m") = 0.20 "arm radius placeholder";
  parameter Real a_arm(unit="m") = R_arm/sqrt(2.0) "arm x/y component";
  parameter Real prop_radius(unit="m") = 0.06 "propeller radius placeholder";
  parameter Real L_probe(unit="m") = 0.30 "probe length placeholder";
  parameter Real x_contact(unit="m") = L_probe "platform x at probe-wall contact";
  parameter Real desired_standoff_offset(unit="m") = 0.03 "standoff target offset";
  parameter Real x_standoff_target(unit="m") = L_probe + desired_standoff_offset;

  // Inertia and actuator placeholders; not specified by requirement
  parameter Real Jx(unit="kg.m2") = 0.05;
  parameter Real Jy(unit="kg.m2") = 0.05;
  parameter Real Jz(unit="kg.m2") = 0.07;
  parameter Real c_yaw(unit="m") = 0.02 "yaw torque coefficient placeholder";
  parameter Real tau_rotor(unit="s") = 0.02 "rotor thrust time constant";

  // Wall box
  parameter Real wall_x(unit="m") = 0.0 "vertical wall surface plane";
  parameter Real wall_y_min(unit="m") = -2.0;
  parameter Real wall_y_max(unit="m") = 2.0;
  parameter Real wall_z_min(unit="m") = 0.0;
  parameter Real wall_z_max(unit="m") = 3.0;
  parameter Real mu_wall(unit="1") = 0.55 "wall friction coefficient";
  parameter Real k_wall(unit="N/m") = 3000.0 "wall normal stiffness placeholder";
  parameter Real d_wall(unit="N.s/m") = 40.0 "wall normal damping placeholder";

  // Mission timing
  parameter Real Ts(unit="s") = 0.005 "200 Hz control period";
  parameter Real t_end(unit="s") = 14.0 "run duration";
  parameter Real t_wind_start(unit="s") = t_end/3.0 "middle third start";
  parameter Real t_wind_end(unit="s") = 2.0*t_end/3.0 "middle third end";
  parameter Real t_last_quarter(unit="s") = 3.0*t_end/4.0;
  parameter Real t_contact_phase(unit="s") = t_last_quarter - 0.3 "impedance phase start";
  parameter Real t_standoff_check(unit="s") = 9.1;

  // Disturbance and force targets
  parameter Real F_wind(unit="N") = 3.0 "tangential wind disturbance";
  parameter Real F_contact_sp(unit="N") = 8.0 "desired normal probe force";
  parameter Real F_contact_min(unit="N") = 5.0;
  parameter Real F_contact_max(unit="N") = 14.0;
  parameter Real Vapproach(unit="m/s") = 0.18 "approach speed limit placeholder";

  // Controller limits and gains; numeric bounds not specified except contact force window
  parameter Real attCmdLimit(unit="rad") = 0.35;
  parameter Real axLimit(unit="m/s2") = 3.5;
  parameter Real ayLimit(unit="m/s2") = 3.5;
  parameter Real azLimit(unit="m/s2") = 3.0;

  parameter Real Kp_pos = 20.0;
  parameter Real Kd_pos = 10.0;
  parameter Real Kp_lat = 40.0;
  parameter Real Kd_lat = 15.0;
  parameter Real Kp_vert = 40.0;
  parameter Real Kd_vert = 15.0;
  parameter Real Kforce = 0.6;
  parameter Real Kd_contact = 2.0;
  parameter Real Kp_contact = 1.0;
  parameter Real Kp_att = 100.0;
  parameter Real Kd_att = 20.0;

  parameter Real f_hover(unit="N") = m_total*g/N_rotors "hover thrust per rotor";

  // Arm yaw signs
  constant Real s1 = 1.0;
  constant Real s2 = -1.0;
  constant Real s3 = 1.0;
  constant Real s4 = -1.0;

  // Continuous states
  Real x(start=x0, fixed=true, unit="m") "platform x, wall-normal";
  Real y(start=0.0, fixed=true, unit="m") "platform y, tangential";
  Real z(start=z0, fixed=true, unit="m") "platform z, vertical";
  Real vx(start=0.0, fixed=true, unit="m/s");
  Real vy(start=0.0, fixed=true, unit="m/s");
  Real vz(start=0.0, fixed=true, unit="m/s");

  Real phi(start=0.0, fixed=true, unit="rad") "roll";
  Real theta(start=0.0, fixed=true, unit="rad") "pitch";
  Real psi(start=0.0, fixed=true, unit="rad") "yaw";
  Real p(start=0.0, fixed=true, unit="rad/s");
  Real q(start=0.0, fixed=true, unit="rad/s");
  Real r(start=0.0, fixed=true, unit="rad/s");

  Real alpha(start=0.0, fixed=true, unit="rad") "cable angle from vertical";
  Real alpha_dot(start=0.0, fixed=true, unit="rad/s");

  Real f1(start=f_hover, fixed=true, unit="N") "rotor 1 thrust";
  Real f2(start=f_hover, fixed=true, unit="N") "rotor 2 thrust";
  Real f3(start=f_hover, fixed=true, unit="N") "rotor 3 thrust";
  Real f4(start=f_hover, fixed=true, unit="N") "rotor 4 thrust";
  Real f5(start=f_hover, fixed=true, unit="N") "rotor 5 thrust";
  Real f6(start=f_hover, fixed=true, unit="N") "rotor 6 thrust";
  Real f7(start=f_hover, fixed=true, unit="N") "rotor 7 thrust";
  Real f8(start=f_hover, fixed=true, unit="N") "rotor 8 thrust";

  // Discrete command traces
  discrete Real mode(start=0.0) "0 position mode, 1 impedance/contact mode";
  discrete Real x_des(start=x0, unit="m");
  discrete Real vx_des(start=0.0, unit="m/s");
  discrete Real y_des(start=0.0, unit="m");
  discrete Real z_des(start=z0, unit="m");
  discrete Real ax_des_raw(start=0.0, unit="m/s2");
  discrete Real ay_des_raw(start=0.0, unit="m/s2");
  discrete Real az_des_raw(start=0.0, unit="m/s2");
  discrete Real ax_des(start=0.0, unit="m/s2");
  discrete Real ay_des(start=0.0, unit="m/s2");
  discrete Real az_des(start=0.0, unit="m/s2");

  discrete Real T_cmd_raw(start=0.0, unit="N");
  discrete Real T_cmd(start=0.0, unit="N") "total thrust command";
  discrete Real phi_cmd_raw(start=0.0, unit="rad");
  discrete Real theta_cmd_raw(start=0.0, unit="rad");
  discrete Real phi_cmd(start=0.0, unit="rad");
  discrete Real theta_cmd(start=0.0, unit="rad");
  discrete Real psi_cmd(start=0.0, unit="rad");
  discrete Real p_dot_cmd(start=0.0, unit="rad/s2");
  discrete Real q_dot_cmd(start=0.0, unit="rad/s2");
  discrete Real r_dot_cmd(start=0.0, unit="rad/s2");
  discrete Real Mx_cmd(start=0.0, unit="N.m");
  discrete Real My_cmd(start=0.0, unit="N.m");
  discrete Real Mz_cmd(start=0.0, unit="N.m");

  discrete Real F1_cmd(start=0.0, unit="N") "arm 1 total thrust command";
  discrete Real F2_cmd(start=0.0, unit="N") "arm 2 total thrust command";
  discrete Real F3_cmd(start=0.0, unit="N") "arm 3 total thrust command";
  discrete Real F4_cmd(start=0.0, unit="N") "arm 4 total thrust command";

  discrete Real f1_cmd(start=0.0, unit="N");
  discrete Real f2_cmd(start=0.0, unit="N");
  discrete Real f3_cmd(start=0.0, unit="N");
  discrete Real f4_cmd(start=0.0, unit="N");
  discrete Real f5_cmd(start=0.0, unit="N");
  discrete Real f6_cmd(start=0.0, unit="N");
  discrete Real f7_cmd(start=0.0, unit="N");
  discrete Real f8_cmd(start=0.0, unit="N");

  // Intermediate continuous variables
  Real ax(unit="m/s2");
  Real ay(unit="m/s2");
  Real az(unit="m/s2");
  Real alpha_ddot(unit="rad/s2");

  Real C(unit="1");
  Real S(unit="1");
  Real A11(unit="kg");
  Real A12(unit="kg");
  Real A21(unit="kg");
  Real A22(unit="kg");
  Real det(unit="kg2");
  Real Bx(unit="N");
  Real Bz(unit="N");
  Real F_ext_x(unit="N");
  Real F_ext_y(unit="N");
  Real F_ext_z(unit="N");

  Real T_act(unit="N") "actual total thrust";
  Real thrust_x(unit="N");
  Real thrust_y(unit="N");
  Real thrust_z(unit="N");

  Real F1_act(unit="N");
  Real F2_act(unit="N");
  Real F3_act(unit="N");
  Real F4_act(unit="N");
  Real Mx_act(unit="N.m");
  Real My_act(unit="N.m");
  Real Mz_act(unit="N.m");

  // Contact and wind
  Real wallActive(unit="1");
  Real penetration(unit="m");
  Real F_normal_contact(unit="N");
  Real F_wall_x(unit="N");
  Real F_wall_y(unit="N");
  Real F_wall_z(unit="N");
  Real vt2(unit="(m/s)2");
  Real vtn(unit="m/s");
  Real F_friction_mag(unit="N");
  Real windY(unit="N");
  Real wind_active_r(unit="1");
  Boolean contact_flag;

  // Sensor traces
  Real imu_acc_x(unit="m/s2");
  Real imu_acc_y(unit="m/s2");
  Real imu_acc_z(unit="m/s2");
  Real imu_gyro_p(unit="rad/s");
  Real imu_gyro_q(unit="rad/s");
  Real imu_gyro_r(unit="rad/s");
  Real lidar_range(unit="m");
  Real flow_vy(unit="m/s");
  Real flow_vz(unit="m/s");
  Real flow_quality(unit="1");
  Real probe_force_normal(unit="N");
  Real probe_force_tangent_y(unit="N");
  Real probe_force_tangent_z(unit="N");
  Real probe_force_tangent_mag(unit="N");
  Boolean probe_contact;

  // Estimator traces
  Real est_x(unit="m");
  Real est_y(unit="m");
  Real est_z(unit="m");
  Real est_phi(unit="rad");
  Real est_theta(unit="rad");
  Real est_psi(unit="rad");
  Real est_vx(unit="m/s");
  Real est_vy(unit="m/s");
  Real est_vz(unit="m/s");
  Real est_p(unit="rad/s");
  Real est_q(unit="rad/s");
  Real est_r(unit="rad/s");
  Boolean est_contact;
  Real est_F_normal(unit="N");

  // Requirement traces
  Real rotor_thrust_max_obs(unit="N");
  Real attitude_max_obs(unit="rad");
  Real abs_phi(unit="rad");
  Real abs_theta(unit="rad");
  Real abs_psi(unit="rad");
  Real max_f12(unit="N");
  Real max_f34(unit="N");
  Real max_f56(unit="N");
  Real max_f78(unit="N");
  Real max_f1234(unit="N");
  Real max_f5678(unit="N");
  Boolean thrust_bound_ok;
  Boolean attitude_bound_ok;
  Boolean contact_force_ok;
  Boolean no_fan_collision;
  Boolean last_quarter_contact_ok;
  Real primary_tracking_error(unit="m");
  Real standoff_error(unit="m");
  Real approach_speed(unit="m/s");
  Boolean standoff_check_active;
  Boolean contact_hold_active;
  Real min_rotor_clearance(unit="m");

equation
  // -------- Wall contact and tangential wind --------
  wallActive = if (y >= wall_y_min and y <= wall_y_max and z >= wall_z_min and z <= wall_z_max) then 1.0 else 0.0;
  penetration = max(0.0, L_probe - x);
  F_normal_contact = wallActive*(k_wall*penetration + d_wall*max(0.0, -vx));
  F_wall_x = F_normal_contact;

  vt2 = vy*vy + vz*vz + eps_norm;
  vtn = sqrt(vt2);
  F_friction_mag = mu_wall*F_normal_contact;
  F_wall_y = if vtn > 1.0e-6 then -F_friction_mag*vy/vtn else 0.0;
  F_wall_z = if vtn > 1.0e-6 then -F_friction_mag*vz/vtn else 0.0;

  wind_active_r = if (time >= t_wind_start and time <= t_wind_end) then 1.0 else 0.0;
  windY = wind_active_r * F_wind;

  contact_flag = F_normal_contact > 1.0e-3;

  // -------- External forces on platform --------
  F_ext_x = thrust_x + F_wall_x;
  F_ext_y = thrust_y + F_wall_y + windY;
  F_ext_z = thrust_z + F_wall_z;

  // -------- Payload-coupled translational dynamics --------
  C = cos(alpha);
  S = sin(alpha);
  A11 = m_total - m_payload*C*C;
  A12 = -m_payload*S*C;
  A21 = -m_payload*S*C;
  A22 = m_total - m_payload*S*S;
  det = m_total*m_platform;
  Bx = F_ext_x + m_payload*g*S*C + m_payload*L_cable*S*alpha_dot*alpha_dot;
  Bz = F_ext_z - m_total*g - m_payload*g*S*S - m_payload*L_cable*C*alpha_dot*alpha_dot;

  ax = (Bx*A22 - Bz*A12)/det;
  az = (A11*Bz - A21*Bx)/det;
  ay = F_ext_y/m_total;

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  alpha_ddot = -(ax*C + az*S + g*S)/L_cable;
  der(alpha) = alpha_dot;
  der(alpha_dot) = alpha_ddot;

  // -------- Attitude dynamics --------
  der(phi) = p;
  der(theta) = q;
  der(psi) = r;
  der(p) = Mx_act/Jx;
  der(q) = My_act/Jy;
  der(r) = Mz_act/Jz;

  // -------- Rotor thrust actuator dynamics --------
  der(f1) = (f1_cmd - f1)/tau_rotor;
  der(f2) = (f2_cmd - f2)/tau_rotor;
  der(f3) = (f3_cmd - f3)/tau_rotor;
  der(f4) = (f4_cmd - f4)/tau_rotor;
  der(f5) = (f5_cmd - f5)/tau_rotor;
  der(f6) = (f6_cmd - f6)/tau_rotor;
  der(f7) = (f7_cmd - f7)/tau_rotor;
  der(f8) = (f8_cmd - f8)/tau_rotor;

  // -------- Actual thrust and moments --------
  F1_act = f1 + f2;
  F2_act = f3 + f4;
  F3_act = f5 + f6;
  F4_act = f7 + f8;
  T_act = F1_act + F2_act + F3_act + F4_act;

  Mx_act = a_arm*(F1_act + F2_act - F3_act - F4_act);
  My_act = -a_arm*(F1_act - F2_act - F3_act + F4_act);
  Mz_act = c_yaw*(s1*(f1 - f2) + s2*(f3 - f4) + s3*(f5 - f6) + s4*(f7 - f8));

  // Thrust vector in world frame
  thrust_x = T_act*(cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi));
  thrust_y = T_act*(sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi));
  thrust_z = T_act*cos(theta)*cos(phi);

  // -------- Sensors --------
  imu_acc_x = ax;
  imu_acc_y = ay;
  imu_acc_z = az;
  imu_gyro_p = p;
  imu_gyro_q = q;
  imu_gyro_r = r;
  lidar_range = max(0.0, x - L_probe);
  flow_vy = vy;
  flow_vz = vz;
  flow_quality = if lidar_range > 0.01 then 1.0 else 0.0;
  probe_force_normal = F_normal_contact;
  probe_force_tangent_y = F_wall_y;
  probe_force_tangent_z = F_wall_z;
  probe_force_tangent_mag = sqrt(F_wall_y*F_wall_y + F_wall_z*F_wall_z + eps_norm);
  probe_contact = contact_flag;

  // -------- Ideal estimator; no unknown noise models introduced --------
  est_x = lidar_range + L_probe;
  est_y = y;
  est_z = z;
  est_phi = phi;
  est_theta = theta;
  est_psi = psi;
  est_vx = vx;
  est_vy = flow_vy;
  est_vz = flow_vz;
  est_p = p;
  est_q = q;
  est_r = r;
  est_contact = contact_flag;
  est_F_normal = probe_force_normal;

  // -------- Requirement traces --------
  abs_phi = abs(phi);
  abs_theta = abs(theta);
  abs_psi = abs(psi);
  max_f12 = max(f1, f2);
  max_f34 = max(f3, f4);
  max_f56 = max(f5, f6);
  max_f78 = max(f7, f8);
  max_f1234 = max(max_f12, max_f34);
  max_f5678 = max(max_f56, max_f78);
  rotor_thrust_max_obs = max(max_f1234, max_f5678);
  attitude_max_obs = max(abs_phi, max(abs_theta, abs_psi));
  thrust_bound_ok = rotor_thrust_max_obs <= Tmax + 1.0e-6;
  attitude_bound_ok = attitude_max_obs <= attCmdLimit + 1.0e-6;

  contact_hold_active = time >= t_last_quarter;
  standoff_check_active = time >= t_standoff_check;
  contact_force_ok = if time >= t_last_quarter then
      (probe_force_normal >= F_contact_min - 1.0e-6 and probe_force_normal <= F_contact_max + 1.0e-6)
    else
      true;
  last_quarter_contact_ok = if time >= t_last_quarter then contact_flag else true;

  min_rotor_clearance = x - R_arm - prop_radius;
  no_fan_collision = min_rotor_clearance > 0.0;

  primary_tracking_error = abs(x - x_standoff_target);
  standoff_error = abs(lidar_range - desired_standoff_offset);
  approach_speed = abs(vx);

  // -------- 200 Hz position-to-impedance hybrid controller --------
  when sample(0, Ts) then
    mode = if time >= t_contact_phase then 1.0 else 0.0;
    x_des = if (x0 - Vapproach*time) > x_standoff_target then
            x0 - Vapproach*time else x_standoff_target;
    vx_des = if (x0 - Vapproach*time) > x_standoff_target then -Vapproach else 0.0;
    y_des = 0.0;
    z_des = z0;

    if time >= t_contact_phase then
      ax_des_raw = Kforce*(est_F_normal - F_contact_sp)/m_total - Kd_contact*est_vx - Kp_contact*(est_x - x_contact);
      ay_des_raw = Kp_lat*(y_des - est_y) + Kd_lat*(0.0 - est_vy);
      az_des_raw = Kp_vert*(z_des - est_z) + Kd_vert*(0.0 - est_vz);
    else
      ax_des_raw = Kp_pos*(x_des - est_x) + Kd_pos*(vx_des - est_vx);
      ay_des_raw = Kp_lat*(y_des - est_y) + Kd_lat*(0.0 - est_vy);
      az_des_raw = Kp_vert*(z_des - est_z) + Kd_vert*(0.0 - est_vz);
    end if;

    ax_des = max(-axLimit, min(axLimit, ax_des_raw));
    ay_des = max(-ayLimit, min(ayLimit, ay_des_raw));
    az_des = max(-azLimit, min(azLimit, az_des_raw));

    T_cmd_raw = m_total*sqrt(ax_des*ax_des + ay_des*ay_des + (az_des + g)*(az_des + g));
    T_cmd = max(0.0, min(T_total_max, T_cmd_raw));

    theta_cmd_raw = asin(max(-1.0, min(1.0, m_total*ax_des/max(T_cmd, eps))));
    phi_cmd_raw = asin(max(-1.0, min(1.0, -m_total*ay_des/max(T_cmd, eps))));
    psi_cmd = 0.0;

    theta_cmd = max(-attCmdLimit, min(attCmdLimit, theta_cmd_raw));
    phi_cmd = max(-attCmdLimit, min(attCmdLimit, phi_cmd_raw));

    p_dot_cmd = Kp_att*(phi_cmd - est_phi) - Kd_att*est_p;
    q_dot_cmd = Kp_att*(theta_cmd - est_theta) - Kd_att*est_q;
    r_dot_cmd = Kp_att*(psi_cmd - est_psi) - Kd_att*est_r;

    Mx_cmd = Jx*p_dot_cmd;
    My_cmd = Jy*q_dot_cmd;
    Mz_cmd = Jz*r_dot_cmd;

    F1_cmd = T_cmd/4.0 + (Mx_cmd - My_cmd)/(4.0*a_arm);
    F2_cmd = T_cmd/4.0 + (Mx_cmd + My_cmd)/(4.0*a_arm);
    F3_cmd = T_cmd/4.0 - (Mx_cmd - My_cmd)/(4.0*a_arm);
    F4_cmd = T_cmd/4.0 - (Mx_cmd + My_cmd)/(4.0*a_arm);

    f1_cmd = max(0.0, min(Tmax, F1_cmd/2.0 + s1*Mz_cmd/(8.0*c_yaw)));
    f2_cmd = max(0.0, min(Tmax, F1_cmd/2.0 - s1*Mz_cmd/(8.0*c_yaw)));
    f3_cmd = max(0.0, min(Tmax, F2_cmd/2.0 + s2*Mz_cmd/(8.0*c_yaw)));
    f4_cmd = max(0.0, min(Tmax, F2_cmd/2.0 - s2*Mz_cmd/(8.0*c_yaw)));
    f5_cmd = max(0.0, min(Tmax, F3_cmd/2.0 + s3*Mz_cmd/(8.0*c_yaw)));
    f6_cmd = max(0.0, min(Tmax, F3_cmd/2.0 - s3*Mz_cmd/(8.0*c_yaw)));
    f7_cmd = max(0.0, min(Tmax, F4_cmd/2.0 + s4*Mz_cmd/(8.0*c_yaw)));
    f8_cmd = max(0.0, min(Tmax, F4_cmd/2.0 - s4*Mz_cmd/(8.0*c_yaw)));
  end when;

  annotation(experiment(StartTime=0, StopTime=14.0, Interval=0.005, Tolerance=1.0e-4));
end CoaxLiftTouchD;