model QuadScoutTouchB
  // ---- Known physical parameters (from requirement) ----
  parameter Real m = 1.8 "fuselage mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real arm = 0.22 "rotor arm length [m]";
  parameter Real u_max = 9.84 "per-rotor max thrust command [N]";
  parameter Real mu_wall = 0.55 "wall Coulomb friction coefficient";
  parameter Real Ts = 0.01 "control/sensor update period [s] (100 Hz)";
  parameter Real T_end = 10.0 "mission duration [s]";

  // ---- Unknown design values (chosen, labeled as unknown) ----
  parameter Real L_probe = 0.30 "probe length [m] (unknown; set > arm to avoid fan collision)";
  parameter Real k_c = 2000.0 "contact normal stiffness [N/m] (unknown design)";
  parameter Real d_c = 60.0 "contact normal damping [N.s/m] (unknown design)";
  parameter Real k_tau = 0.01 "rotor yaw torque coefficient [N.m/N] (unknown)";
  parameter Real Iyy = 0.05 "pitch inertia [kg.m2] (unknown)";
  parameter Real Izz = 0.05 "yaw inertia [kg.m2] (unknown)";
  parameter Real b_rot = 0.02 "pitch damping [N.m.s/rad] (unknown)";
  parameter Real b_yaw = 0.02 "yaw damping [N.m.s/rad] (unknown)";
  parameter Real x_wall = 0.0 "wall surface x [m]";
  parameter Real x0 = -2.0 "initial x [m]";
  parameter Real y0 = 0.0 "initial y [m]";
  parameter Real z0 = 2.0 "initial z [m]";
  parameter Real F_wind = 2.1 "tangential wind disturbance [N]";
  parameter Real F_n_des = 9.5 "desired normal probe force [N] (within 5..14)";
  parameter Real v_approach_limit = 0.5 "approach speed limit [m/s] (unknown; chosen safe)";
  parameter Real t_approach = 5.5 "approach duration [s] (unknown; chosen to settle before 6.5 s)";
  parameter Real x_eq = x_wall - L_probe + F_n_des/k_c "contact equilibrium x [m]";

  // ---- Control gains (unknown design) ----
  parameter Real Kpx = 8.0;
  parameter Real Kdx = 5.0;
  parameter Real Kpz = 40.0;
  parameter Real Kdz = 12.0;
  parameter Real Kpf = 3.0 "normal-force feedback gain in contact phase";
  parameter Real Kp_th = 60.0;
  parameter Real Kd_th = 8.0;
  parameter Real Kp_psi = 20.0;
  parameter Real Kd_psi = 4.0;
  parameter Real theta_lim = 0.4 "pitch bound [rad] (unknown; chosen)";
  parameter Real eps_tanh = 0.05 "friction smoothing velocity [m/s]";

  // ---- Continuous states ----
  Real x(start=x0, fixed=true) "fuselage x [m]";
  Real y(start=y0, fixed=true) "fuselage y [m]";
  Real z(start=z0, fixed=true) "fuselage z [m]";
  Real vx(start=0, fixed=true) "vx [m/s]";
  Real vy(start=0, fixed=true) "vy [m/s]";
  Real vz(start=0, fixed=true) "vz [m/s]";
  Real theta(start=0, fixed=true) "pitch [rad]";
  Real q_theta(start=0, fixed=true) "pitch rate [rad/s]";
  Real psi(start=0, fixed=true) "yaw [rad]";
  Real r_psi(start=0, fixed=true) "yaw rate [rad/s]";

  // ---- Discrete rotor commands (100 Hz ZOH) ----
  discrete Real u1(start=m*g/4) "front rotor thrust [N]";
  discrete Real u2(start=m*g/4) "back rotor thrust [N]";
  discrete Real u3(start=m*g/4) "right rotor thrust [N]";
  discrete Real u4(start=m*g/4) "left rotor thrust [N]";

  // ---- Discrete command traces ----
  discrete Real T_des_d(start=m*g);
  discrete Real M_pitch_des_d(start=0);
  discrete Real M_yaw_des_d(start=0);
  discrete Real theta_des_d(start=0);

  // ---- Discrete controller intermediates ----
  discrete Real ex(start=0), ez(start=0);
  discrete Real ax_des(start=0), az_des(start=0);
  discrete Real theta_des_raw(start=0), T_des_raw(start=0);
  discrete Real e_theta(start=0), M_pitch_des(start=0), M_yaw_des(start=0);
  discrete Real u1d(start=m*g/4), u2d(start=m*g/4), u3d(start=m*g/4), u4d(start=m*g/4);

  // ---- Aggregated actuator outputs ----
  Real T_act "total thrust [N]";
  Real M_pitch_act "actual pitch moment [N.m]";
  Real M_yaw_act "actual yaw moment [N.m]";

  // ---- Contact / environment ----
  Real pen_raw "geometric penetration [m]";
  Real F_n "normal contact force [N] (>=0)";
  Real F_fric "tangential friction force [N]";
  Real F_wind_y "applied wind disturbance [N]";
  Boolean in_contact;

  // ---- Setpoints ----
  Real x_sp, y_sp, z_sp;

  // ---- Sensors ----
  Real d_lidar "lidar range to wall [m]";
  Real flow_meas "optical flow tangential velocity [m/s]";
  Real ax_imu, ay_imu, az_imu "IMU accelerations [m/s2]";
  Real F_n_sensor, F_t_sensor;

  // ---- Traces / metrics ----
  Real stand_off "probe tip stand-off from wall [m]";
  Real tracking_error "primary stand-off tracking error [m]";
  Real approach_speed "current approach speed magnitude [m/s]";
  Real v_approach_nom "nominal setpoint approach speed [m/s]";
equation
  // setpoint schedule: bounded approach ramp
  x_sp = x0 + (x_eq - x0)*min(1.0, max(0.0, time/t_approach));
  y_sp = 0.0;
  z_sp = z0;
  v_approach_nom = abs(x_eq - x0)/t_approach;

  // aggregated actuator from rotor commands
  T_act = u1 + u2 + u3 + u4;
  M_pitch_act = arm*(u1 - u2);
  M_yaw_act = k_tau*(u1 + u2 - u3 - u4);

  // translational dynamics (thrust along body Z, gravity, contact, wind)
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (T_act*cos(psi)*sin(theta) - F_n)/m;
  der(vy) = (T_act*sin(psi)*sin(theta) + F_fric + F_wind_y)/m;
  der(vz) = (T_act*cos(theta) - m*g)/m;

  // rotational dynamics
  der(theta) = q_theta;
  der(q_theta) = (M_pitch_act - b_rot*q_theta)/Iyy;
  der(psi) = r_psi;
  der(r_psi) = (M_yaw_act - b_yaw*r_psi)/Izz;

  // wall contact (fixed collidable box)
  pen_raw = x + L_probe - x_wall;
  in_contact = pen_raw > 0.0;
  F_n = if pen_raw > 0.0 then max(0.0, k_c*pen_raw + d_c*vx) else 0.0;
  F_fric = -mu_wall*F_n*tanh(vy/eps_tanh);

  // tangential wind disturbance during middle third
  F_wind_y = if (time >= T_end/3.0 and time <= 2.0*T_end/3.0) then F_wind else 0.0;

  // sensors
  d_lidar = max(0.0, x_wall - (x + L_probe));
  flow_meas = vy;
  ax_imu = (T_act*cos(psi)*sin(theta) - F_n)/m;
  ay_imu = (T_act*sin(psi)*sin(theta) + F_fric + F_wind_y)/m;
  az_imu = (T_act*cos(theta) - m*g)/m;
  F_n_sensor = F_n;
  F_t_sensor = F_fric;

  // metrics
  stand_off = x_wall - (x + L_probe);
  tracking_error = abs(x_sp - x);
  approach_speed = abs(vx);

algorithm
  // Position-to-impedance hybrid controller at 100 Hz
  when sample(0, Ts) then
    ex := x_sp - x;
    ez := z_sp - z;

    // Free-flight position control until last quarter; impedance/force hold thereafter
    if time >= 7.5 then
      ax_des := Kpf*(F_n_des - F_n) - Kdx*vx;
    else
      ax_des := Kpx*ex - Kdx*vx;
    end if;

    az_des := Kpz*ez - Kdz*vz;

    // Attitude and total-thrust commands (small-angle allocation)
    theta_des_raw := atan2(ax_des, g + az_des);
    theta_des_d := max(-theta_lim, min(theta_lim, theta_des_raw));
    T_des_raw := m*sqrt(ax_des*ax_des + (g + az_des)*(g + az_des));
    T_des_d := max(0.0, min(4.0*u_max, T_des_raw));

    // Attitude error to torque
    e_theta := theta_des_d - theta;
    M_pitch_des := Kp_th*e_theta - Kd_th*q_theta;
    M_yaw_des := Kp_psi*(0.0 - psi) - Kd_psi*r_psi;
    M_pitch_des_d := M_pitch_des;
    M_yaw_des_d := M_yaw_des;

    // Rotor mixing (front/back carry pitch; all four carry yaw reaction torque)
    u1d := T_des_d/4.0 + M_pitch_des/(2.0*arm) + M_yaw_des/(4.0*k_tau);
    u2d := T_des_d/4.0 - M_pitch_des/(2.0*arm) + M_yaw_des/(4.0*k_tau);
    u3d := T_des_d/4.0 - M_yaw_des/(4.0*k_tau);
    u4d := T_des_d/4.0 - M_yaw_des/(4.0*k_tau);

    // Per-rotor saturation: thrust bound and no fan collision enforced via L_probe > arm
    u1 := max(0.0, min(u_max, u1d));
    u2 := max(0.0, min(u_max, u2d));
    u3 := max(0.0, min(u_max, u3d));
    u4 := max(0.0, min(u_max, u4d));
  end when;

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="Free-base aerial robot QuadScoutTouchB. Approach a vertical wall, establish bounded normal probe force (5..14 N), and hold contact for the last quarter (t>=7.5 s). 2.1 N tangential wind injected during middle third. Unknown facts (inertia, contact stiffness/damping, gains, probe length, wall location) are design choices labeled in comments."));
end QuadScoutTouchB;