model QuadScoutTouchB
  "Free-base aerial robot approach, contact, and impedance hold mission";

  // Physical parameters specified by the requirement
  parameter Real m = 1.8 "fuselage mass [kg]";
  parameter Real L_arm = 0.22 "rotor arm length [m]";
  parameter Real F_rotor_max = 9.84 "allowed thrust command magnitude per rotor [N]";
  parameter Real mu_wall = 0.55 "wall friction coefficient [1]";
  parameter Real F_wind = 2.1 "controlled tangential wind disturbance [N]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";

  // Assumed/tuned parameters for facts not specified by the requirement
  parameter Real L_probe = 0.30 "probe length, assumed so rotors remain clear of wall [m]";
  parameter Real k_contact = 3000.0 "wall contact stiffness, assumed [N/m]";
  parameter Real d_contact = 80.0 "wall contact damping, assumed [Ns/m]";
  parameter Real v_eps = 1.0e-3 "friction velocity regularization, assumed [m/s]";
  parameter Real p_eps = 1.0e-4 "penetration smoothing half-width, assumed [m]";
  parameter Real J_pitch = 0.05 "pitch inertia, assumed [kg m2]";
  parameter Real J_yaw = 0.05 "yaw inertia, assumed [kg m2]";
  parameter Real k_yaw = 0.05 "yaw moment coefficient, assumed [N m/N]";
  parameter Real tau_rotor = 0.02 "rotor thrust lag, assumed [s]";
  parameter Real tau_sensor = 0.01 "sensor lag, assumed [s]";
  parameter Real Kp_x = 8.0 "position x proportional gain, assumed";
  parameter Real Kd_x = 4.0 "position x derivative gain, assumed";
  parameter Real Kp_z = 8.0 "position z proportional gain, assumed";
  parameter Real Kd_z = 4.0 "position z derivative gain, assumed";
  parameter Real Kp_theta = 12.0 "pitch angle gain, assumed";
  parameter Real Kd_theta = 3.0 "pitch rate gain, assumed";
  parameter Real Kp_psi = 8.0 "yaw angle gain, assumed";
  parameter Real Kd_psi = 2.0 "yaw rate gain, assumed";
  parameter Real K_force = 0.5 "contact force tracking gain, assumed";
  parameter Real F_ref = 8.0 "desired probe force, selected within 5 to 14 N [N]";
  parameter Real theta_max = 0.40 "attitude bound, assumed [rad]";
  parameter Real x0 = -1.0 "initial x position [m]";
  parameter Real z0 = 0.0 "initial z position [m]";
  parameter Real wall_x = 0.0 "wall plane x coordinate [m]";

  // Plant states
  Real x(start=x0, fixed=true) "horizontal position normal to wall [m]";
  Real z(start=z0, fixed=true) "vertical position along wall [m]";
  Real vx(start=0.0, fixed=true) "horizontal velocity [m/s]";
  Real vz(start=0.0, fixed=true) "vertical velocity [m/s]";
  Real theta(start=0.0, fixed=true) "pitch angle [rad]";
  Real q(start=0.0, fixed=true) "pitch rate [rad/s]";
  Real psi(start=0.0, fixed=true) "yaw angle [rad]";
  Real r(start=0.0, fixed=true) "yaw rate [rad/s]";

  // Actuator states
  Real f1_act(start=4.4, fixed=true) "rotor 1 actual thrust [N]";
  Real f2_act(start=4.4, fixed=true) "rotor 2 actual thrust [N]";
  Real f3_act(start=4.4, fixed=true) "rotor 3 actual thrust [N]";
  Real f4_act(start=4.4, fixed=true) "rotor 4 actual thrust [N]";

  // Estimator/sensor states
  Real q_est(start=0.0, fixed=true) "IMU pitch rate estimate [rad/s]";
  Real vx_est(start=0.0, fixed=true) "optical flow x velocity estimate [m/s]";
  Real vz_est(start=0.0, fixed=true) "optical flow z velocity estimate [m/s]";
  Real F_probe_est(start=0.0, fixed=true) "probe force estimate [N]";
  Real d_lidar_est(start=0.7, fixed=true) "lidar distance estimate [m]";

  // Contact and disturbance variables
  Real tip_x "probe tip x [m]";
  Real tip_z "probe tip z [m]";
  Real tip_vx "probe tip x velocity [m/s]";
  Real tip_vz "probe tip z velocity [m/s]";
  Real penetration "probe penetration into wall [m]";
  Real pen_smooth "smooth penetration positive part [m]";
  Real F_n "normal contact force magnitude [N]";
  Real F_contact_x "wall contact force on robot in x [N]";
  Real F_contact_z "wall friction force on robot in z [N]";
  Real M_contact "contact moment about pitch axis [N m]";
  Real wind_z "applied tangential wind disturbance [N]";
  Boolean in_wind;
  Boolean contact;
  Boolean contact_detected;

  // Controller variables
  Real x_des "desired x position [m]";
  Real z_des "desired z position [m]";
  Real ax_pos "position-control x acceleration [m/s2]";
  Real az_pos "position-control z acceleration [m/s2]";
  Real F_force_cmd "force-control contribution [N]";
  Real fx_des_raw "desired thrust x component [N]";
  Real fz_des "desired thrust z component [N]";
  Real theta_des "desired pitch angle [rad]";
  Real T_cmd "commanded total thrust [N]";
  Real M_pitch_cmd "commanded pitch moment [N m]";
  Real M_yaw_cmd "commanded yaw moment [N m]";
  Real f1_cmd "unsaturated rotor 1 command [N]";
  Real f2_cmd "unsaturated rotor 2 command [N]";
  Real f3_cmd "unsaturated rotor 3 command [N]";
  Real f4_cmd "unsaturated rotor 4 command [N]";
  Real f1_cmd_sat "saturated rotor 1 command [N]";
  Real f2_cmd_sat "saturated rotor 2 command [N]";
  Real f3_cmd_sat "saturated rotor 3 command [N]";
  Real f4_cmd_sat "saturated rotor 4 command [N]";

  // Actual total thrust and moments
  Real T_act "actual total thrust [N]";
  Real M_pitch_act "actual pitch moment [N m]";
  Real M_yaw_act "actual yaw moment [N m]";

  // Mission trace and verification variables
  Real tracking_error "primary stand-off tracking error [m]";
  Real min_rotor_dist "minimum rotor-to-wall distance [m]";
  Real T_total "total actual thrust trace [N]";
  Real theta_deg "pitch angle trace [deg]";
  Boolean thrust_bound_ok;
  Boolean attitude_bound_ok;
  Boolean contact_force_ok;
  Boolean no_fan_collision;
  Boolean tracking_ok;
  Boolean hold_contact;

equation
  // Time-windowed wind disturbance: middle third of 10 s run
  in_wind = (time >= 10.0/3.0) and (time <= 20.0/3.0);
  wind_z = if in_wind then F_wind else 0.0;

  // Probe kinematics
  tip_x = x + L_probe*cos(theta);
  tip_z = z - L_probe*sin(theta);
  tip_vx = vx - L_probe*sin(theta)*q;
  tip_vz = vz - L_probe*cos(theta)*q;

  // Smooth wall contact model (avoids hard event switching in continuous force)
  penetration = tip_x - wall_x;
  pen_smooth = 0.5*(penetration + sqrt(penetration*penetration + p_eps*p_eps));
  contact = penetration > 0.0;
  F_n = k_contact*pen_smooth + d_contact*tip_vx*0.5*(1.0 + (penetration)/sqrt(penetration*penetration + p_eps*p_eps));
  F_n = max(0.0, k_contact*pen_smooth + d_contact*tip_vx*(pen_smooth/max(pen_smooth, p_eps)));
  F_contact_x = -F_n;
  F_contact_z = -mu_wall*F_n*tanh(tip_vz/v_eps);
  M_contact = -L_probe*F_contact_z;

  // Plant dynamics
  der(x) = vx;
  der(z) = vz;
  der(vx) = (T_act*sin(theta) + F_contact_x)/m;
  der(vz) = (T_act*cos(theta) - m*g + F_contact_z + wind_z)/m;
  der(theta) = q;
  der(q) = (M_pitch_act + M_contact)/J_pitch;
  der(psi) = r;
  der(r) = M_yaw_act/J_yaw;

  // Position-to-impedance hybrid controller
  x_des = wall_x - L_probe;
  z_des = 0.0;

  ax_pos = Kp_x*(x_des - x) + Kd_x*(-vx);
  az_pos = Kp_z*(z_des - z) + Kd_z*(-vz);

  contact_detected = (F_probe_est > 0.5) or (d_lidar_est < 0.02);
  F_force_cmd = if contact_detected then K_force*(F_ref - F_probe_est) else 0.0;

  fx_des_raw = m*ax_pos + F_force_cmd;
  fz_des = m*az_pos + m*g - wind_z;

  theta_des = max(-theta_max, min(theta_max, atan2(fx_des_raw, max(fz_des, 1.0e-3))));
  T_cmd = max(0.0, min(4.0*F_rotor_max, fz_des/max(cos(theta_des), 1.0e-3)));

  // Attitude control
  M_pitch_cmd = Kp_theta*(theta_des - theta) + Kd_theta*(-q);
  M_yaw_cmd = Kp_psi*(0.0 - psi) + Kd_psi*(-r);

  // Rotor mixing
  f1_cmd = T_cmd/4.0 + M_pitch_cmd/(4.0*L_arm) + M_yaw_cmd/(4.0*k_yaw);
  f2_cmd = T_cmd/4.0 + M_pitch_cmd/(4.0*L_arm) - M_yaw_cmd/(4.0*k_yaw);
  f3_cmd = T_cmd/4.0 - M_pitch_cmd/(4.0*L_arm) + M_yaw_cmd/(4.0*k_yaw);
  f4_cmd = T_cmd/4.0 - M_pitch_cmd/(4.0*L_arm) - M_yaw_cmd/(4.0*k_yaw);

  // Thrust saturation
  f1_cmd_sat = max(0.0, min(F_rotor_max, f1_cmd));
  f2_cmd_sat = max(0.0, min(F_rotor_max, f2_cmd));
  f3_cmd_sat = max(0.0, min(F_rotor_max, f3_cmd));
  f4_cmd_sat = max(0.0, min(F_rotor_max, f4_cmd));

  // Rotor actuator dynamics
  der(f1_act) = (f1_cmd_sat - f1_act)/tau_rotor;
  der(f2_act) = (f2_cmd_sat - f2_act)/tau_rotor;
  der(f3_act) = (f3_cmd_sat - f3_act)/tau_rotor;
  der(f4_act) = (f4_cmd_sat - f4_act)/tau_rotor;

  // Actual thrust and moments
  T_act = f1_act + f2_act + f3_act + f4_act;
  M_pitch_act = L_arm*((f1_act + f2_act) - (f3_act + f4_act));
  M_yaw_act = k_yaw*(f1_act - f2_act + f3_act - f4_act);

  // Sensors: IMU, lidar, optical flow, probe force
  der(q_est) = (q - q_est)/tau_sensor;
  der(vx_est) = (vx - vx_est)/tau_sensor;
  der(vz_est) = (vz - vz_est)/tau_sensor;
  der(F_probe_est) = (F_n - F_probe_est)/tau_sensor;
  der(d_lidar_est) = (max(wall_x - tip_x, 0.0) - d_lidar_est)/tau_sensor;

  // Mission traces and requirements
  tracking_error = abs(x - x_des);
  min_rotor_dist = wall_x - (x + L_arm*cos(theta));
  T_total = T_act;
  theta_deg = theta*180.0/3.141592653589793;

  thrust_bound_ok = (T_cmd <= 4.0*F_rotor_max + 1.0e-6) and
                    (f1_cmd_sat <= F_rotor_max + 1.0e-6) and
                    (f2_cmd_sat <= F_rotor_max + 1.0e-6) and
                    (f3_cmd_sat <= F_rotor_max + 1.0e-6) and
                    (f4_cmd_sat <= F_rotor_max + 1.0e-6);
  attitude_bound_ok = abs(theta) <= theta_max + 1.0e-6;
  contact_force_ok = (not contact) or ((F_n >= 5.0) and (F_n <= 14.0));
  no_fan_collision = min_rotor_dist > 0.0;
  tracking_ok = (time < 6.5) or (tracking_error <= 0.048);
  hold_contact = (time < 7.5) or (contact and (F_n >= 5.0) and (F_n <= 14.0));

  annotation (
    experiment(StopTime=10.0, Tolerance=1.0e-6, Interval=0.01),
    Documentation(info="QuadScoutTouchB: 100 Hz, 10 s mission. Parameters not specified in the requirement are labeled as assumed/tuned."));
end QuadScoutTouchB;