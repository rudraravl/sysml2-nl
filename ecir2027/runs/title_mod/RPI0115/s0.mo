model CoaxLiftTouchA
  import SI = Modelica.SIunits;

  // Platform and payload facts from the requirement
  parameter SI.Mass M_platform = 4.4 "cargo platform mass";
  parameter SI.Mass m_payload = 1.2 "payload mass";
  parameter SI.Length L_cable = 0.70 "massless cable length";
  parameter SI.Acceleration g = 9.81 "standard gravity";
  parameter SI.Force F_rotor_max = 7.2 "per-rotor command magnitude limit";
  parameter SI.Force T_total_max = 8.0*F_rotor_max "total thrust limit";
  parameter Real mu_wall = 0.55 "wall friction coefficient";
  parameter SI.Force F_wind = 1.5 "tangential wind disturbance";
  parameter SI.Time T_run = 8.0 "scenario duration";
  parameter SI.Time T_contact_start = 6.0 "start of last quarter contact hold";
  parameter SI.Frequency f_ctrl = 80.0 "control and sensor rate";
  parameter SI.Time dt = 0.0125 "80 Hz sample period";
  parameter SI.Length x_min = 0.054 "primary tracking/stand-off bound";

  // Initial conditions and control setpoints not specified by the request;
  // chosen only to make the run well-posed and to satisfy stated bounds.
  parameter SI.Length x0 = 1.19 "initial normal stand-off";
  parameter SI.Length z0 = 1.00 "initial vertical position";
  parameter SI.Velocity v_approach = 0.18 "approach speed";
  parameter SI.Length x_safe = 0.11 "pre-contact stand-off";
  parameter SI.Length L_probe = 0.10 "compliant probe rest length";
  parameter SI.TranslationalSpringConstant k_probe = 200.0 "probe contact stiffness";
  parameter SI.TranslationalDampingConstant d_probe = 15.0 "probe contact damping";
  parameter SI.Force F_contact_initial = 5.5 "initial contact force command";
  parameter SI.Force F_contact_nom = 9.0 "nominal contact force command";
  parameter SI.Time T_ramp = 0.30 "contact force ramp time";
  parameter SI.Angle pitch_limit = 0.25 "attitude command bound";
  parameter SI.Velocity v_eps = 0.01 "friction velocity smoothing";
  parameter SI.Force T_hover = (M_platform + m_payload)*g "hover thrust";

  // Control gains
  parameter Real Kp_x = 60.0 "normal position gain N/m";
  parameter Real Kd_x = 20.0 "normal velocity gain Ns/m";
  parameter Real Kp_z = 50.0 "vertical position gain N/m";
  parameter Real Kd_z = 30.0 "vertical velocity gain Ns/m";
  parameter Real Kp_att = 400.0 "attitude proportional gain 1/s^2";
  parameter Real Kd_att = 40.0 "attitude damping gain 1/s";
  parameter Real Kdiff = 4.0 "rotor differential thrust gain N/rad";
  parameter Real Kdiff_q = 0.5 "rotor differential thrust damping gain Ns/rad";

  // Continuous physical states
  SI.Length x(start = x0) "normal stand-off from wall";
  SI.Velocity vx(start = 0) "normal velocity";
  SI.Length z(start = z0) "vertical position along wall";
  SI.Velocity vz(start = 0) "vertical velocity";
  SI.Angle theta(start = 0) "platform pitch, positive toward wall";
  SI.AngularVelocity q(start = 0) "platform pitch rate";
  SI.Angle beta(start = 0) "payload cable angle from downward vertical";
  SI.AngularVelocity omega(start = 0) "payload cable angular rate";

  // Continuous algebraic physical variables
  SI.Acceleration ax "platform normal acceleration";
  SI.Acceleration az "platform vertical acceleration";
  SI.AngularAcceleration theta_dd "pitch angular acceleration";
  SI.AngularAcceleration betadd "cable angular acceleration";
  SI.Force Ttot_actual "actual total rotor thrust";
  SI.Force Fx_thrust "normal thrust component";
  SI.Force Fz_thrust "vertical thrust component";
  SI.Length pen "probe penetration";
  SI.Force F_wall_x "wall normal contact force";
  SI.Force F_wall_z "wall friction force";
  SI.Force F_wind_z "tangential wind disturbance";
  SI.Force F_platform_x "platform normal force excluding cable tension";
  SI.Force F_platform_z "platform vertical force excluding cable tension";
  Real s "sin(beta)";
  Real c "cos(beta)";
  SI.Force Fe "platform force along cable";
  SI.Force Fn "platform force normal to cable";
  SI.Acceleration a_e "platform acceleration along cable";
  SI.Acceleration a_n "platform acceleration normal to cable";
  SI.Force T_cable "cable tension";
  SI.Length primaryTrackingError "abs(x - x_cmd)";

  // Discrete controller and command traces
  Integer mode(start = 0) "0 position, 1 impedance contact";
  SI.Length x_pre(start = x0) "pre-contact position command";
  SI.Force F_contact_des(start = 0) "desired contact force";
  SI.Length x_cmd(start = x0) "normal position command";
  SI.Velocity vx_cmd(start = 0) "normal velocity command";
  SI.Force Fx_des(start = 0) "desired normal force";
  SI.Force Fz_des(start = T_hover) "desired vertical force";
  SI.Force Ttot_cmd_raw(start = T_hover) "unlimited total thrust command";
  SI.Force Ttot_cmd(start = T_hover) "limited total thrust command";
  SI.Angle theta_cmd_raw(start = 0) "unlimited pitch command";
  SI.Angle theta_cmd(start = 0) "limited pitch command";
  SI.Force base_cmd(start = T_hover/8.0) "equal rotor thrust command";
  SI.Force dmax(start = 0) "differential thrust margin";
  SI.Force d_raw(start = 0) "unlimited differential thrust";
  SI.Force d_cmd(start = 0) "limited differential thrust";
  SI.Force u1_cmd(start = T_hover/8.0) "rotor 1 command, front coax pair A upper";
  SI.Force u2_cmd(start = T_hover/8.0) "rotor 2 command, front coax pair A lower";
  SI.Force u3_cmd(start = T_hover/8.0) "rotor 3 command, front coax pair B upper";
  SI.Force u4_cmd(start = T_hover/8.0) "rotor 4 command, front coax pair B lower";
  SI.Force u5_cmd(start = T_hover/8.0) "rotor 5 command, rear coax pair C upper";
  SI.Force u6_cmd(start = T_hover/8.0) "rotor 6 command, rear coax pair C lower";
  SI.Force u7_cmd(start = T_hover/8.0) "rotor 7 command, rear coax pair D upper";
  SI.Force u8_cmd(start = T_hover/8.0) "rotor 8 command, rear coax pair D lower";

  // Synchronized sensor/estimator traces at 80 Hz
  SI.Length lidar_range(start = x0) "lidar range to wall";
  SI.Velocity optical_flow_vz(start = 0) "optical flow tangential velocity";
  SI.Force probe_force(start = 0) "probe force sensor";
  SI.Acceleration imu_ax(start = 0) "IMU normal acceleration";
  SI.Acceleration imu_az(start = 0) "IMU vertical acceleration";
  SI.AngularVelocity imu_q(start = 0) "IMU pitch rate";
  SI.Length x_est(start = x0) "estimated normal position";
  SI.Length z_est(start = z0) "estimated vertical position";
  SI.Velocity vx_est(start = 0) "estimated normal velocity";
  SI.Velocity vz_est(start = 0) "estimated vertical velocity";
  SI.Angle theta_est(start = 0) "estimated pitch";
  SI.Angle beta_est(start = 0) "estimated payload angle";
  Boolean contact_estimated(start = false) "estimated contact";

equation
  // Platform and payload dynamics
  der(x) = vx;
  der(vx) = ax;
  der(z) = vz;
  der(vz) = az;
  der(theta) = q;
  der(q) = theta_dd;
  der(beta) = omega;
  der(omega) = betadd;

  // Wall contact: fixed collidable vertical box at x=0 with friction
  pen = L_probe - x;
  F_wall_x = if pen > 0.0 then max(0.0, k_probe*pen - d_probe*vx) else 0.0;
  F_wall_z = if F_wall_x > 0.0 then -mu_wall*(vz/sqrt(vz*vz + v_eps*v_eps))*F_wall_x else 0.0;

  // Tangential wind during the middle third of the run
  F_wind_z = if time >= T_run/3.0 and time <= 2.0*T_run/3.0 then -F_wind else 0.0;

  // Rotor thrust vector; positive pitch tilts thrust toward the wall (-x)
  Ttot_actual = u1_cmd + u2_cmd + u3_cmd + u4_cmd + u5_cmd + u6_cmd + u7_cmd + u8_cmd;
  Fx_thrust = -Ttot_actual*sin(theta);
  Fz_thrust = Ttot_actual*cos(theta);

  // Platform force excluding cable tension
  F_platform_x = Fx_thrust + F_wall_x;
  F_platform_z = Fz_thrust - M_platform*g + F_wall_z + F_wind_z;

  // Cable-constrained payload eliminated to scalar ODE form
  s = sin(beta);
  c = cos(beta);
  Fe = F_platform_x*s - F_platform_z*c;
  Fn = F_platform_x*c + F_platform_z*s;
  a_e = (Fe + m_payload*(g*c + L_cable*omega*omega))/(M_platform + m_payload);
  a_n = Fn/M_platform;
  ax = a_e*s + a_n*c;
  az = -a_e*c + a_n*s;
  betadd = (-g*s - a_n)/L_cable;
  T_cable = m_payload*(g*c - a_e + L_cable*omega*omega);

  // Attitude response to bounded pitch command
  theta_dd = Kp_att*(theta_cmd - theta) - Kd_att*q;

  primaryTrackingError = abs(x - x_cmd);

  // 80 Hz synchronized controller and sensor update
  when sample(0.0, dt) then
    // Hybrid mode: position-to-impedance; contact hold in last quarter
    mode = if time >= T_contact_start then 1 else 0;

    // Position trajectory and impedance setpoint
    x_pre = max(x_safe, x0 - v_approach*time);
    F_contact_des = if time < T_contact_start then 0.0
                    elseif time < T_contact_start + T_ramp then
                      F_contact_initial + (F_contact_nom - F_contact_initial)*(time - T_contact_start)/T_ramp
                    else F_contact_nom;
    x_cmd = if mode == 0 then x_pre else L_probe - F_contact_des/k_probe;
    vx_cmd = if mode == 1 then 0.0 elseif x_pre > x_safe then -v_approach else 0.0;

    // Position/impedance control
    Fx_des = Kp_x*(x_cmd - x) + Kd_x*(vx_cmd - vx) - F_contact_des;
    Fz_des = (M_platform + m_payload)*g + Kp_z*(z0 - z) + Kd_z*(0.0 - vz);

    // Thrust and attitude command with bounds
    Ttot_cmd_raw = sqrt(max(0.0, Fx_des*Fx_des + Fz_des*Fz_des));
    Ttot_cmd = max(0.0, min(T_total_max, Ttot_cmd_raw));
    theta_cmd_raw = atan2(-Fx_des, max(Fz_des, 0.0));
    theta_cmd = max(-pitch_limit, min(pitch_limit, theta_cmd_raw));

    // Control allocation to eight rotor channels
    base_cmd = max(0.0, min(F_rotor_max, Ttot_cmd/8.0));
    dmax = min(base_cmd, F_rotor_max - base_cmd);
    d_raw = Kdiff*(theta_cmd - theta) + Kdiff_q*q;
    d_cmd = max(-dmax, min(dmax, d_raw));

    u1_cmd = base_cmd + d_cmd;
    u2_cmd = base_cmd + d_cmd;
    u3_cmd = base_cmd + d_cmd;
    u4_cmd = base_cmd + d_cmd;
    u5_cmd = base_cmd - d_cmd;
    u6_cmd = base_cmd - d_cmd;
    u7_cmd = base_cmd - d_cmd;
    u8_cmd = base_cmd - d_cmd;

    // Sensor and estimator traces
    lidar_range = x;
    optical_flow_vz = vz;
    probe_force = F_wall_x;
    imu_ax = ax;
    imu_az = az;
    imu_q = q;
    x_est = x;
    z_est = z;
    vx_est = vx;
    vz_est = vz;
    theta_est = theta;
    beta_est = beta;
    contact_estimated = F_wall_x > 0.5;
  end when;

  // Requirement checks
  assert(u1_cmd >= -1e-9 and u1_cmd <= F_rotor_max + 1e-9, "rotor 1 command limit");
  assert(u2_cmd >= -1e-9 and u2_cmd <= F_rotor_max + 1e-9, "rotor 2 command limit");
  assert(u3_cmd >= -1e-9 and u3_cmd <= F_rotor_max + 1e-9, "rotor 3 command limit");
  assert(u4_cmd >= -1e-9 and u4_cmd <= F_rotor_max + 1e-9, "rotor 4 command limit");
  assert(u5_cmd >= -1e-9 and u5_cmd <= F_rotor_max + 1e-9, "rotor 5 command limit");
  assert(u6_cmd >= -1e-9 and u6_cmd <= F_rotor_max + 1e-9, "rotor 6 command limit");
  assert(u7_cmd >= -1e-9 and u7_cmd <= F_rotor_max + 1e-9, "rotor 7 command limit");
  assert(u8_cmd >= -1e-9 and u8_cmd <= F_rotor_max + 1e-9, "rotor 8 command limit");
  assert(abs(theta) <= pitch_limit + 0.02, "attitude bound");
  assert(x >= 0.0, "no wall collision");
  assert(time < 5.2 or primaryTrackingError <= x_min + 1e-6, "primary tracking error after 5.2 s");
  assert(time < 5.2 or x >= x_min, "stand-off/no fan collision bound after 5.2 s");
  assert(time < T_contact_start + T_ramp + 0.05 or time >= T_run or
         (F_wall_x >= 5.0 and F_wall_x <= 14.0), "contact force bounds during hold");
  assert(abs(x) < 1e6 and abs(z) < 1e6 and abs(vx) < 1e6 and abs(vz) < 1e6 and
         abs(theta) < 1e6 and abs(q) < 1e6 and abs(beta) < 1e6 and abs(omega) < 1e6,
         "finite physical state");
  assert(abs(Ttot_cmd) < 1e6 and abs(theta_cmd) < 1e6 and abs(x_est) < 1e6 and abs(z_est) < 1e6,
         "finite control/estimator values");

  annotation(experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125));
end CoaxLiftTouchA;