model CoaxLiftTouchA
  // Platform and payload facts
  parameter Real M_platform = 4.4 "cargo platform mass [kg]";
  parameter Real m_payload = 1.2 "payload mass [kg]";
  parameter Real L_cable = 0.70 "massless cable length [m]";
  parameter Real g = 9.81 "standard gravity [m/s2]";
  parameter Real F_rotor_max = 7.2 "per-rotor command magnitude limit [N]";
  parameter Real T_total_max = 8.0 * F_rotor_max "total thrust limit [N]";
  parameter Real mu_wall = 0.55 "wall friction coefficient";
  parameter Real F_wind = 1.5 "tangential wind disturbance [N]";
  parameter Real T_run = 8.0 "scenario duration [s]";
  parameter Real T_contact_start = 6.0 "start of last quarter contact hold [s]";
  parameter Real f_ctrl = 80.0 "control and sensor rate [Hz]";
  parameter Real dt = 0.0125 "80 Hz sample period [s]";
  parameter Real x_min = 0.054 "primary tracking/stand-off bound [m]";

  // Initial conditions and control setpoints
  parameter Real x0 = 1.19 "initial normal stand-off [m]";
  parameter Real z0 = 1.00 "initial vertical position [m]";
  parameter Real v_approach = 0.18 "approach speed [m/s]";
  parameter Real x_safe = 0.11 "pre-contact stand-off [m]";
  parameter Real L_probe = 0.10 "compliant probe rest length [m]";
  parameter Real k_probe = 200.0 "probe contact stiffness [N/m]";
  parameter Real d_probe = 15.0 "probe contact damping [N.s/m]";
  parameter Real F_contact_initial = 5.5 "initial contact force command [N]";
  parameter Real F_contact_nom = 9.0 "nominal contact force command [N]";
  parameter Real T_ramp = 0.30 "contact force ramp time [s]";
  parameter Real pitch_limit = 0.25 "attitude command bound [rad]";
  parameter Real v_eps = 0.01 "friction velocity smoothing [m/s]";
  parameter Real T_hover = (M_platform + m_payload) * g "hover thrust [N]";
  parameter Real Fz_eps = 1.0 "force epsilon for atan division [N]";

  // Control gains
  parameter Real Kp_x = 60.0 "normal position gain [N/m]";
  parameter Real Kd_x = 20.0 "normal velocity gain [Ns/m]";
  parameter Real Kp_z = 50.0 "vertical position gain [N/m]";
  parameter Real Kd_z = 30.0 "vertical velocity gain [Ns/m]";
  parameter Real Kp_att = 400.0 "attitude proportional gain [1/s2]";
  parameter Real Kd_att = 40.0 "attitude damping gain [1/s]";
  parameter Real Kdiff = 4.0 "rotor differential thrust gain [N/rad]";
  parameter Real Kdiff_q = 0.5 "rotor differential thrust damping gain [Ns/rad]";

  // Continuous physical states
  Real x(start = x0) "normal stand-off from wall [m]";
  Real vx(start = 0) "normal velocity [m/s]";
  Real z(start = z0) "vertical position along wall [m]";
  Real vz(start = 0) "vertical velocity [m/s]";
  Real theta(start = 0) "platform pitch [rad]";
  Real q(start = 0) "platform pitch rate [rad/s]";
  Real beta(start = 0) "payload cable angle [rad]";
  Real omega(start = 0) "payload cable angular rate [rad/s]";

  // Continuous algebraic physical variables
  Real ax "platform normal acceleration [m/s2]";
  Real az "platform vertical acceleration [m/s2]";
  Real theta_dd "pitch angular acceleration [rad/s2]";
  Real betadd "cable angular acceleration [rad/s2]";
  Real Ttot_actual "actual total rotor thrust [N]";
  Real Fx_thrust "normal thrust component [N]";
  Real Fz_thrust "vertical thrust component [N]";
  Real pen "probe penetration [m]";
  Real F_wall_x "wall normal contact force [N]";
  Real F_wall_z "wall friction force [N]";
  Real F_wind_z "tangential wind disturbance [N]";
  Real F_platform_x "platform normal force excluding cable tension [N]";
  Real F_platform_z "platform vertical force excluding cable tension [N]";
  Real s "sin(beta)";
  Real c "cos(beta)";
  Real Fe "platform force along cable [N]";
  Real Fn "platform force normal to cable [N]";
  Real a_e "platform acceleration along cable [m/s2]";
  Real a_n "platform acceleration normal to cable [m/s2]";
  Real T_cable "cable tension [N]";
  Real primaryTrackingError "abs(x - x_cmd) [m]";

  // Discrete controller and command traces
  Integer mode(start = 0) "0 position, 1 impedance contact";
  discrete Real x_pre(start = x0) "pre-contact position command [m]";
  discrete Real F_contact_des(start = 0) "desired contact force [N]";
  discrete Real x_cmd(start = x0) "normal position command [m]";
  discrete Real vx_cmd(start = 0) "normal velocity command [m/s]";
  discrete Real Fx_des(start = 0) "desired normal force [N]";
  discrete Real Fz_des(start = T_hover) "desired vertical force [N]";
  discrete Real Ttot_cmd_raw(start = T_hover) "unlimited total thrust command [N]";
  discrete Real Ttot_cmd(start = T_hover) "limited total thrust command [N]";
  discrete Real theta_cmd_raw(start = 0) "unlimited pitch command [rad]";
  discrete Real theta_cmd(start = 0) "limited pitch command [rad]";
  discrete Real base_cmd(start = T_hover / 8.0) "equal rotor thrust command [N]";
  discrete Real dmax(start = 0) "differential thrust margin [N]";
  discrete Real d_raw(start = 0) "unlimited differential thrust [N]";
  discrete Real d_cmd(start = 0) "limited differential thrust [N]";
  discrete Real u1_cmd(start = T_hover / 8.0) "rotor 1 command [N]";
  discrete Real u2_cmd(start = T_hover / 8.0) "rotor 2 command [N]";
  discrete Real u3_cmd(start = T_hover / 8.0) "rotor 3 command [N]";
  discrete Real u4_cmd(start = T_hover / 8.0) "rotor 4 command [N]";
  discrete Real u5_cmd(start = T_hover / 8.0) "rotor 5 command [N]";
  discrete Real u6_cmd(start = T_hover / 8.0) "rotor 6 command [N]";
  discrete Real u7_cmd(start = T_hover / 8.0) "rotor 7 command [N]";
  discrete Real u8_cmd(start = T_hover / 8.0) "rotor 8 command [N]";

  // Synchronized sensor/estimator traces at 80 Hz
  discrete Real lidar_range(start = x0) "lidar range to wall [m]";
  discrete Real optical_flow_vz(start = 0) "optical flow tangential velocity [m/s]";
  discrete Real probe_force(start = 0) "probe force sensor [N]";
  discrete Real imu_ax(start = 0) "IMU normal acceleration [m/s2]";
  discrete Real imu_az(start = 0) "IMU vertical acceleration [m/s2]";
  discrete Real imu_q(start = 0) "IMU pitch rate [rad/s]";
  discrete Real x_est(start = x0) "estimated normal position [m]";
  discrete Real z_est(start = z0) "estimated vertical position [m]";
  discrete Real vx_est(start = 0) "estimated normal velocity [m/s]";
  discrete Real vz_est(start = 0) "estimated vertical velocity [m/s]";
  discrete Real theta_est(start = 0) "estimated pitch [rad]";
  discrete Real beta_est(start = 0) "estimated payload angle [rad]";
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
  F_wall_x = if pen > 0.0 then max(0.0, k_probe * pen - d_probe * vx) else 0.0;
  F_wall_z = if F_wall_x > 0.0 then -mu_wall * (vz / sqrt(vz * vz + v_eps * v_eps)) * F_wall_x else 0.0;

  // Tangential wind during the middle third of the run
  F_wind_z = if time >= T_run / 3.0 and time <= 2.0 * T_run / 3.0 then -F_wind else 0.0;

  // Rotor thrust vector; positive pitch tilts thrust toward the wall (-x)
  Ttot_actual = u1_cmd + u2_cmd + u3_cmd + u4_cmd + u5_cmd + u6_cmd + u7_cmd + u8_cmd;
  Fx_thrust = -Ttot_actual * sin(theta);
  Fz_thrust = Ttot_actual * cos(theta);

  // Platform force excluding cable tension
  F_platform_x = Fx_thrust + F_wall_x;
  F_platform_z = Fz_thrust - M_platform * g + F_wall_z + F_wind_z;

  // Cable-constrained payload eliminated to scalar ODE form
  s = sin(beta);
  c = cos(beta);
  Fe = F_platform_x * s - F_platform_z * c;
  Fn = F_platform_x * c + F_platform_z * s;
  a_e = (Fe + m_payload * (g * c + L_cable * omega * omega)) / (M_platform + m_payload);
  a_n = Fn / M_platform;
  ax = a_e * s + a_n * c;
  az = -a_e * c + a_n * s;
  betadd = (-g * s - a_n) / L_cable;
  T_cable = m_payload * (g * c - a_e + L_cable * omega * omega);

  // Attitude response to bounded pitch command
  theta_dd = Kp_att * (theta_cmd - theta) - Kd_att * q;

  primaryTrackingError = abs(x - x_cmd);

  // 80 Hz synchronized controller and sensor update
  when sample(0.0, dt) then
    // Hybrid mode: position-to-impedance; contact hold in last quarter
    mode = if time >= T_contact_start then 1 else 0;

    // Position trajectory and impedance setpoint
    x_pre = max(x_safe, x0 - v_approach * time);
    F_contact_des = if time < T_contact_start then 0.0
      elseif time < T_contact_start + T_ramp then
        F_contact_initial + (F_contact_nom - F_contact_initial) * (time - T_contact_start) / T_ramp
      else F_contact_nom;
    x_cmd = if mode == 0 then x_pre else L_probe - F_contact_des / k_probe;
    vx_cmd = if mode == 1 then 0.0 elseif x_pre > x_safe then -v_approach else 0.0;

    // Position/impedance control
    Fx_des = Kp_x * (x_cmd - x) + Kd_x * (vx_cmd - vx) - F_contact_des;
    Fz_des = T_hover + Kp_z * (z0 - z) + Kd_z * (0.0 - vz);

    // Thrust and attitude command with bounds
    Ttot_cmd_raw = sqrt(max(0.0, Fx_des * Fx_des + Fz_des * Fz_des));
    Ttot_cmd = max(0.0, min(T_total_max, Ttot_cmd_raw));
    theta_cmd_raw = atan(-Fx_des / max(abs(Fz_des), Fz_eps));
    theta_cmd = max(-pitch_limit, min(pitch_limit, theta_cmd_raw));

    // Control allocation to eight rotor channels
    base_cmd = max(0.0, min(F_rotor_max, Ttot_cmd / 8.0));
    dmax = min(base_cmd, F_rotor_max - base_cmd);
    d_raw = Kdiff * (theta_cmd - theta) + Kdiff_q * q;
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