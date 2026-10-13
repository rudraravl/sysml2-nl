model TiltWingDeliverE
  "Free-base tilt-wing aerial robot delivering a suspended payload into a 0.8 m target zone";

  // ===== Physical constants =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Plant structure (stated facts) =====
  parameter Real m = 6.2 "Fuselage mass [kg] (wing/rotor masses not specified; assumed folded into m)";
  parameter Real rotorArm = 0.62 "Rotor distance from center [m] (structural; planar model assumes regulated attitude)";
  parameter Real wingSpan = 1.8 "Wing span [m] (structural)";
  parameter Real gamma_min = 0.0 "Min rotor tilt [rad]";
  parameter Real gamma_max = 1.57 "Max rotor tilt [rad]";
  parameter Real thrust_max = 57.2 "Per-rotor thrust magnitude bound [N]";

  // ===== Payload / cable (NOT specified in request; assumed values, labeled) =====
  parameter Real m_p = 2.0 "Payload mass [kg] (assumed)";
  parameter Real L = 1.0 "Cable length [m] (assumed)";

  // ===== Aerodynamics (NOT specified; assumed) =====
  parameter Real cd_drone = 2.0 "Drone quadratic drag coeff [kg/m] (assumed)";
  parameter Real cd_payload = 0.5 "Payload tangential drag coeff [kg/m] (assumed)";

  // ===== Gust: controlled 9.6 N, middle third, applied as headwind (-x) =====
  parameter Real gustForce = 9.6 "Gust magnitude [N]";
  parameter Real t_gust_a = 16.0/3.0 "Gust window start [s] (middle third)";
  parameter Real t_gust_b = 32.0/3.0 "Gust window end [s] (middle third)";

  // ===== Controller (assumed gains) =====
  parameter Real Kp_x = 4.0 "Horizontal position gain";
  parameter Real Kd_x = 8.0 "Horizontal velocity gain";
  parameter Real Kp_z = 10.0 "Vertical position gain";
  parameter Real Kd_z = 6.0 "Vertical velocity gain";
  parameter Real k_swing = 1.5 "Cable-swing damping gain [N*s/rad]";

  // ===== Actuators (assumed first-order dynamics) =====
  parameter Real tau_thrust = 0.02 "Thrust actuator time constant [s]";
  parameter Real tau_tilt = 0.10 "Tilt actuator time constant [s]";

  // ===== Control rate =====
  parameter Real Ts = 1.0/250.0 "Control sample period [s]";

  // ===== Mission =====
  parameter Real x_target = 5.0 "Horizontal translation target [m]";
  parameter Real z_start = 2.0 "Initial altitude [m] (assumed)";
  parameter Real z_cruise = 3.0 "Cruise altitude [m] (assumed)";
  parameter Real z_lower = 1.1 "Lowering altitude [m] (assumed; payload just above ground)";
  parameter Real zoneRadius = 0.8 "Target-zone radius [m]";
  parameter Real t_settle = 10.4 "Tracking-error threshold time [s]";
  parameter Real track_tol = 0.27 "Primary tracking tolerance [m]";
  parameter Real swing_max = 0.45 "Max cable swing [rad]";
  parameter Real tension_max = 60.0 "Cable tension upper bound [N] (assumed)";

  // ===== Continuous states =====
  Real x(start=0.0, fixed=true) "Drone x position [m]";
  Real z(start=z_start, fixed=true) "Drone z position [m]";
  Real vx(start=0.0, fixed=true) "Drone x velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Drone z velocity [m/s]";
  Real theta(start=0.0, fixed=true) "Cable angle from vertical [rad]";
  Real omega(start=0.0, fixed=true) "Cable angular rate [rad/s]";
  Real T1(start=m*g/2.0) "Rotor 1 thrust [N]";
  Real T2(start=m*g/2.0) "Rotor 2 thrust [N]";
  Real gamma1(start=0.0) "Rotor 1 tilt [rad]";
  Real gamma2(start=0.0) "Rotor 2 tilt [rad]";

  // ===== Sampled commands (discrete) =====
  discrete Real T1_cmd(start=m*g/2.0) "Rotor 1 thrust command [N]";
  discrete Real T2_cmd(start=m*g/2.0) "Rotor 2 thrust command [N]";
  discrete Real gamma1_cmd(start=0.0) "Rotor 1 tilt command [rad]";
  discrete Real gamma2_cmd(start=0.0) "Rotor 2 tilt command [rad]";

  // ===== References (input-shaped) =====
  Real x_ref, z_ref, vx_ref, vz_ref;

  // ===== Forces / sensors =====
  Real F_gust "Applied gust force in x [N] (negative = headwind)";
  Real Fx_thrust, Fz_thrust;
  Real drag_x, drag_z;
  Real T_cable "Cable tension [N]";
  Real ax, az "Drone acceleration [m/s2]";
  Real xp, zp "Payload position [m]";
  // IMU + GPS + cable-angle + tension sensor traces
  Real gps_x, gps_z;
  Real imu_ax, imu_az;
  Real sensor_theta, sensor_tension;

  // ===== Acceptance flags =====
  Boolean ok_thrust, ok_tension, ok_swing, ok_ground, ok_track, ok_target, ok_finite;
  Real track_err, place_err;

protected
  Real st, ct, od2;
  Real Acoef, Bcoef, Dcoef, det;
  Real rhs_x, rhs_z;
  Real v_tan, drag_tan;
  Real alpha;

  function smoothstep "Cubic smoothstep 0..1 on [a,b]"
    input Real t;
    input Real a;
    input Real b;
    output Real s;
  protected
    Real u;
  algorithm
    if t <= a then
      s := 0.0;
    elseif t >= b then
      s := 1.0;
    else
      u := (t - a)/(b - a);
      s := 3.0*u*u - 2.0*u*u*u;
    end if;
  end smoothstep;

  function dsmoothstep "Derivative of smoothstep"
    input Real t;
    input Real a;
    input Real b;
    output Real ds;
  protected
    Real u;
  algorithm
    if (t <= a) or (t >= b) then
      ds := 0.0;
    else
      u := (t - a)/(b - a);
      ds := 6.0*u*(1.0 - u)/(b - a);
    end if;
  end dsmoothstep;

  function isFin "Finite check (rejects NaN and Inf)"
    input Real x;
    output Boolean b;
  algorithm
    b := (x == x) and (abs(x) < 1.0e30);
  end isFin;

  function ctrl "Sampled position controller with cable-swing damping"
    input Real x, z, vx, vz, theta, omega;
    input Real x_ref, z_ref, vx_ref, vz_ref;
    input Real Kp_x, Kd_x, Kp_z, Kd_z, k_swing;
    input Real m_total, g_acc;
    input Real gamma_min_p, gamma_max_p, thrust_max_p;
    output Real T1_cmd_o, T2_cmd_o, gamma1_cmd_o, gamma2_cmd_o;
  protected
    Real Fx_des, Fz_des, gamma_des, T_total_des, cg, sg;
  algorithm
    Fx_des := Kp_x*(x_ref - x) + Kd_x*(vx_ref - vx) + k_swing*omega;
    Fz_des := Kp_z*(z_ref - z) + Kd_z*(vz_ref - vz) + m_total*g_acc;
    // Plant authority: thrust >=0, tilt in [0,1.57] => only +x / +z force quadrant
    if Fx_des < 0.0 then
      Fx_des := 0.0;
    end if;
    if Fz_des < 0.1 then
      Fz_des := 0.1;
    end if;
    gamma_des := atan2(Fx_des, Fz_des);
    if gamma_des > gamma_max_p then
      gamma_des := gamma_max_p;
    elseif gamma_des < gamma_min_p then
      gamma_des := gamma_min_p;
    end if;
    sg := sin(gamma_des);
    cg := cos(gamma_des);
    if sg > 1.0e-3 then
      T_total_des := Fx_des/sg;
    else
      T_total_des := Fz_des/max(cg, 1.0e-3);
    end if;
    T1_cmd_o := T_total_des/2.0;
    T2_cmd_o := T_total_des/2.0;
    if T1_cmd_o > thrust_max_p then
      T1_cmd_o := thrust_max_p;
    elseif T1_cmd_o < 0.0 then
      T1_cmd_o := 0.0;
    end if;
    if T2_cmd_o > thrust_max_p then
      T2_cmd_o := thrust_max_p;
    elseif T2_cmd_o < 0.0 then
      T2_cmd_o := 0.0;
    end if;
    gamma1_cmd_o := gamma_des;
    gamma2_cmd_o := gamma_des;
  end ctrl;

equation
  // ===== Input-shaped reference profiles =====
  x_ref  = x_target * smoothstep(time, 2.0, 9.0);
  z_ref  = z_start + (z_cruise - z_start)*smoothstep(time, 0.0, 2.0) - (z_cruise - z_lower)*smoothstep(time, 10.0, 14.0);
  vx_ref = x_target * dsmoothstep(time, 2.0, 9.0);
  vz_ref = (z_cruise - z_start)*dsmoothstep(time, 0.0, 2.0) - (z_cruise - z_lower)*dsmoothstep(time, 10.0, 14.0);

  // ===== Gust: 9.6 N headwind over middle third, smoothed ramps =====
  F_gust = -gustForce * smoothstep(time, t_gust_a, t_gust_a + 0.5) * (1.0 - smoothstep(time, t_gust_b - 0.5, t_gust_b));

  // ===== Rotor forces =====
  Fx_thrust = T1*sin(gamma1) + T2*sin(gamma2);
  Fz_thrust = T1*cos(gamma1) + T2*cos(gamma2);

  // ===== Aerodynamic drag (quadratic) =====
  drag_x = cd_drone * vx*abs(vx);
  drag_z = cd_drone * vz*abs(vz);

  // ===== Payload tangential drag =====
  v_tan = vx*cos(theta) + vz*sin(theta) + L*omega;
  drag_tan = cd_payload * v_tan*abs(v_tan);

  // ===== Coupled drone-payload 2x2 linear solve (rigid cable) =====
  st = sin(theta);
  ct = cos(theta);
  od2 = omega*omega;
  Acoef = m - m_p*st*st;
  Bcoef = m_p*st*ct;
  Dcoef = m + m_p*ct*ct;
  det = max(Acoef*Dcoef + Bcoef*Bcoef, 1.0e-6);
  rhs_x = (Fx_thrust - drag_x + F_gust) - m_p*g*st*ct - m_p*L*st*od2;
  rhs_z = (Fz_thrust - drag_z) - m*g - m_p*g*ct*ct - m_p*L*ct*od2;
  ax = (Dcoef*rhs_x - Bcoef*rhs_z)/det;
  az = (Bcoef*rhs_x + Acoef*rhs_z)/det;

  // ===== Pendulum angular acceleration =====
  alpha = (-ax*ct - az*st - g*st + drag_tan/m_p)/L;

  // ===== Cable tension (sensor) =====
  T_cable = m_p*(g*ct - ax*st + az*ct + L*od2);

  // ===== State derivatives =====
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax;
  der(vz) = az;
  der(theta) = omega;
  der(omega) = alpha;
  der(T1) = (T1_cmd - T1)/tau_thrust;
  der(T2) = (T2_cmd - T2)/tau_thrust;
  der(gamma1) = (gamma1_cmd - gamma1)/tau_tilt;
  der(gamma2) = (gamma2_cmd - gamma2)/tau_tilt;

  // ===== Payload kinematics =====
  xp = x + L*sin(theta);
  zp = z - L*cos(theta);

  // ===== Sensors (synchronized traces) =====
  gps_x = x;
  gps_z = z;
  imu_ax = ax;
  imu_az = az;
  sensor_theta = theta;
  sensor_tension = T_cable;

  // ===== Sampled controller at 250 Hz =====
  when sample(0, Ts) then
    (T1_cmd, T2_cmd, gamma1_cmd, gamma2_cmd) =
      ctrl(x, z, vx, vz, theta, omega,
           x_ref, z_ref, vx_ref, vz_ref,
           Kp_x, Kd_x, Kp_z, Kd_z, k_swing,
           m + m_p, g, gamma_min, gamma_max, thrust_max);
  end when;

  // ===== Acceptance metrics =====
  track_err = sqrt((x - x_ref)*(x - x_ref) + (z - z_ref)*(z - z_ref));
  place_err = sqrt((xp - x_target)*(xp - x_target) + zp*zp);

  ok_thrust  = (T1 >= -1.0e-6) and (T1 <= thrust_max + 1.0e-6) and
               (T2 >= -1.0e-6) and (T2 <= thrust_max + 1.0e-6);
  ok_tension = (T_cable >= -1.0e-3) and (T_cable <= tension_max + 1.0e-3);
  ok_swing   = abs(theta) <= swing_max + 1.0e-6;
  ok_ground  = (z >= 0.2) and (zp >= -1.0e-3);
  ok_track   = (time < t_settle) or (track_err <= track_tol + 1.0e-6);
  ok_target  = (time < 14.0) or (place_err <= zoneRadius + 1.0e-6);
  ok_finite  = isFin(x) and isFin(z) and isFin(vx) and isFin(vz) and
               isFin(theta) and isFin(omega) and isFin(T1) and isFin(T2) and
               isFin(gamma1) and isFin(gamma2) and isFin(T_cable) and
               isFin(ax) and isFin(az) and isFin(T1_cmd) and isFin(T2_cmd) and
               isFin(gamma1_cmd) and isFin(gamma2_cmd);

  // ===== Fail-closed acceptance =====
  assert(ok_thrust,  "Acceptance FAILED: thrust bound violated",                       AssertionLevel.error);
  assert(ok_tension, "Acceptance FAILED: tension bound violated",                      AssertionLevel.error);
  assert(ok_swing,   "Acceptance FAILED: cable swing exceeded 0.45 rad",               AssertionLevel.error);
  assert(ok_ground,  "Acceptance FAILED: ground strike",                               AssertionLevel.error);
  assert(ok_track,   "Acceptance FAILED: primary tracking error after 10.4 s",         AssertionLevel.error);
  assert(ok_target,  "Acceptance FAILED: target-zone placement",                       AssertionLevel.error);
  assert(ok_finite,  "Acceptance FAILED: NaN or infinite value detected",              AssertionLevel.error);

  annotation(
    experiment(StartTime=0.0, StopTime=16.0, Tolerance=1.0e-6, Interval=0.004),
    Documentation(info="Tilt-wing delivery drone (TiltWingDeliverE) with suspended payload. "
      "Plant: 6.2 kg fuselage, two tilting rotors at 0.62 m, 1.8 m wing, tilt joints [0,1.57] rad, "
      "thrust <=57.2 N per rotor. Planar dynamics (x-z) with rigid cable pendulum. "
      "Payload mass, cable length, drag coefficients, controller gains, actuator time constants, "
      "altitudes and tension bound are NOT specified in the request and are assumed (labeled). "
      "Pitch/roll/yaw assumed regulated by an inner loop not modeled here; rotorArm and wingSpan "
      "are retained as structural parameters. Controller sampled at 250 Hz with input-shaped position "
      "references and cable-swing damping. A controlled 9.6 N headwind gust acts over the middle third. "
      "Acceptance is fail-closed via assertions: thrust/tension bounds, swing <0.45 rad, target-zone "
      "placement within 0.8 m, no ground strike, primary tracking error <0.27 m after 10.4 s, "
      "and no NaN/infinite values."));
end TiltWingDeliverE;