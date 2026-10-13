model TiltWingDeliverE
  "Free-base tilt-wing aerial robot delivering a suspended payload into a 0.8 m target zone";

  // ===== Physical constants =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Plant structure (stated facts) =====
  parameter Real m = 6.2 "Fuselage mass [kg]";
  parameter Real rotorArm = 0.62 "Rotor distance from center [m] (structural; planar model)";
  parameter Real wingSpan = 1.8 "Wing span [m] (structural)";
  parameter Real gamma_min = 0.0 "Min rotor tilt [rad]";
  parameter Real gamma_max = 1.57 "Max rotor tilt [rad]";
  parameter Real thrust_max = 57.2 "Per-rotor thrust magnitude bound [N]";

  // ===== Payload / cable (NOT specified; assumed, labeled) =====
  parameter Real m_p = 2.0 "Payload mass [kg] (assumed)";
  parameter Real L = 1.0 "Cable length [m] (assumed)";

  // ===== Aerodynamics (NOT specified; assumed) =====
  parameter Real cd_drone = 2.0 "Drone quadratic drag coeff [kg/m] (assumed)";
  parameter Real cd_payload = 0.5 "Payload tangential drag coeff [kg/m] (assumed)";

  // ===== Gust: controlled 9.6 N, middle third =====
  parameter Real gustForce = 9.6 "Gust magnitude [N]";
  parameter Real t_gust_a = 16.0/3.0 "Gust window start [s] (middle third)";
  parameter Real t_gust_b = 32.0/3.0 "Gust window end [s] (middle third)";

  // ===== Controller (assumed gains) =====
  parameter Real Kp_x = 50.0 "Horizontal position gain (assumed)";
  parameter Real Kd_x = 20.0 "Horizontal velocity gain (assumed)";
  parameter Real Kp_z = 10.0 "Vertical position gain (assumed)";
  parameter Real Kd_z = 6.0 "Vertical velocity gain (assumed)";
  parameter Real k_swing = 4.0 "Cable-swing damping gain [N*s/rad] (assumed)";

  // ===== Actuators (assumed first-order dynamics) =====
  parameter Real tau_thrust = 0.02 "Thrust actuator time constant [s] (assumed)";
  parameter Real tau_tilt = 0.10 "Tilt actuator time constant [s] (assumed)";

  // ===== Control rate =====
  parameter Real Ts = 1.0/250.0 "Control sample period [s]";

  // ===== Mission =====
  parameter Real x_target = 5.0 "Horizontal translation target [m]";
  parameter Real z_start = 2.0 "Initial altitude [m] (assumed)";
  parameter Real z_cruise = 3.0 "Cruise altitude [m] (assumed)";
  parameter Real z_lower = 1.0 "Lowering altitude [m] (assumed)";
  parameter Real zoneRadius = 0.8 "Target-zone radius [m]";
  parameter Real t_settle = 10.4 "Tracking-error threshold time [s]";
  parameter Real track_tol = 0.27 "Primary tracking tolerance [m]";
  parameter Real swing_max = 0.45 "Max cable swing [rad]";
  parameter Real tension_max = 60.0 "Cable tension upper bound [N] (assumed)";

  // ===== Derived hover thrust =====
  parameter Real T_hover = (m + m_p)*g/2.0 "Hover thrust per rotor [N]";

  // ===== Continuous states =====
  Real x(start=0.0, fixed=true) "Drone x position [m]";
  Real z(start=2.0, fixed=true) "Drone z position [m]";
  Real vx(start=0.0, fixed=true) "Drone x velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Drone z velocity [m/s]";
  Real theta(start=0.0, fixed=true) "Cable angle from vertical [rad]";
  Real omega(start=0.0, fixed=true) "Cable angular rate [rad/s]";
  Real T1(start=T_hover, fixed=true) "Rotor 1 thrust [N]";
  Real T2(start=T_hover, fixed=true) "Rotor 2 thrust [N]";
  Real gamma1(start=0.0, fixed=true) "Rotor 1 tilt [rad]";
  Real gamma2(start=0.0, fixed=true) "Rotor 2 tilt [rad]";

  // ===== Discrete commands =====
  discrete Real T1_cmd(start=T_hover) "Rotor 1 thrust command [N]";
  discrete Real T2_cmd(start=T_hover) "Rotor 2 thrust command [N]";
  discrete Real gamma1_cmd(start=0.0) "Rotor 1 tilt command [rad]";
  discrete Real gamma2_cmd(start=0.0) "Rotor 2 tilt command [rad]";

  // ===== References =====
  Real x_ref "Horizontal reference [m]";
  Real z_ref "Vertical reference [m]";
  Real vx_ref "Horizontal velocity reference [m/s]";
  Real vz_ref "Vertical velocity reference [m/s]";

  // ===== Sensors =====
  Real gps_x "GPS x [m]";
  Real gps_z "GPS z [m]";
  Real imu_ax "IMU x acceleration [m/s2]";
  Real imu_az "IMU z acceleration [m/s2]";
  Real sensor_theta "Cable angle sensor [rad]";
  Real sensor_tension "Cable tension sensor [N]";

protected
  // Smoothstep intermediates
  Real sx1, sx2, sx3, dsx1, dsx2, dsx3;
  Real sg1, sg2;

  // Controller intermediates (discrete)
  discrete Real dFx_des, dFz_des, dgamma_des, dT_total;

  // Physics intermediates
  Real F_gust, Fx_thrust, Fz_thrust, drag_x, drag_z;
  Real st, ct, od2, det;
  Real Acoef, Bcoef, Dcoef, rhs_x, rhs_z;
  Real v_tan, drag_tan;
  Real T_cable, ax, az, alpha;
  Real xp, zp;
  Real track_err, place_err;

equation
  // ===== Input-shaped reference profiles (cubic smoothstep) =====
  sx1 = if time <= 2.0 then 0.0 elseif time >= 9.0 then 1.0
        else 3.0*((time-2.0)/7.0)^2 - 2.0*((time-2.0)/7.0)^3;
  sx2 = if time <= 0.0 then 0.0 elseif time >= 2.0 then 1.0
        else 3.0*(time/2.0)^2 - 2.0*(time/2.0)^3;
  sx3 = if time <= 10.0 then 0.0 elseif time >= 14.0 then 1.0
        else 3.0*((time-10.0)/4.0)^2 - 2.0*((time-10.0)/4.0)^3;

  dsx1 = if time <= 2.0 or time >= 9.0 then 0.0
         else 6.0*((time-2.0)/7.0)*(1.0-(time-2.0)/7.0)/7.0;
  dsx2 = if time <= 0.0 or time >= 2.0 then 0.0
         else 6.0*(time/2.0)*(1.0-time/2.0)/2.0;
  dsx3 = if time <= 10.0 or time >= 14.0 then 0.0
         else 6.0*((time-10.0)/4.0)*(1.0-(time-10.0)/4.0)/4.0;

  x_ref = x_target * sx1;
  z_ref = z_start + (z_cruise - z_start)*sx2 - (z_cruise - z_lower)*sx3;
  vx_ref = x_target * dsx1;
  vz_ref = (z_cruise - z_start)*dsx2 - (z_cruise - z_lower)*dsx3;

  // ===== Gust: 9.6 N headwind over middle third, smoothed ramps =====
  sg1 = if time <= t_gust_a then 0.0 elseif time >= t_gust_a + 0.5 then 1.0
        else 3.0*((time-t_gust_a)/0.5)^2 - 2.0*((time-t_gust_a)/0.5)^3;
  sg2 = if time <= t_gust_b - 0.5 then 0.0 elseif time >= t_gust_b then 1.0
        else 3.0*((time-(t_gust_b-0.5))/0.5)^2 - 2.0*((time-(t_gust_b-0.5))/0.5)^3;
  F_gust = -gustForce * sg1 * (1.0 - sg2);

  // ===== Rotor forces =====
  Fx_thrust = T1*sin(gamma1) + T2*sin(gamma2);
  Fz_thrust = T1*cos(gamma1) + T2*cos(gamma2);

  // ===== Aerodynamic drag (quadratic) =====
  drag_x = cd_drone * vx*abs(vx);
  drag_z = cd_drone * vz*abs(vz);

  // ===== Payload tangential drag =====
  v_tan = vx*cos(theta) + vz*sin(theta) + L*omega;
  drag_tan = cd_payload * v_tan*abs(v_tan);

  // ===== Coupled drone-payload dynamics (rigid cable, 2x2 solve) =====
  st = sin(theta);
  ct = cos(theta);
  od2 = omega*omega;
  Acoef = m + m_p*st*st;
  Bcoef = m_p*st*ct;
  Dcoef = m + m_p*ct*ct;
  det = max(Acoef*Dcoef - Bcoef*Bcoef, 1.0e-6);
  rhs_x = (Fx_thrust - drag_x + F_gust) + m_p*g*st*ct + m_p*L*st*od2;
  rhs_z = (Fz_thrust - drag_z) - m*g - m_p*g*ct*ct - m_p*L*ct*od2;
  ax = (Dcoef*rhs_x - Bcoef*rhs_z)/det;
  az = (-Bcoef*rhs_x + Acoef*rhs_z)/det;

  // ===== Pendulum angular acceleration =====
  alpha = (-ax*ct - az*st - g*st - drag_tan/m_p)/L;

  // ===== Cable tension =====
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

  // ===== Acceptance metrics =====
  track_err = sqrt(max((x - x_ref)*(x - x_ref) + (z - z_ref)*(z - z_ref), 0.0));
  place_err = sqrt(max((xp - x_target)*(xp - x_target) + zp*zp, 0.0));

  // ===== Fail-closed acceptance =====
  assert(T1 >= -1.0e-6 and T1 <= thrust_max + 1.0e-6 and
         T2 >= -1.0e-6 and T2 <= thrust_max + 1.0e-6,
         "Acceptance FAILED: thrust bound violated", AssertionLevel.error);
  assert(T_cable >= -1.0e-3 and T_cable <= tension_max + 1.0e-3,
         "Acceptance FAILED: tension bound violated", AssertionLevel.error);
  assert(abs(theta) <= swing_max + 1.0e-6,
         "Acceptance FAILED: cable swing exceeded 0.45 rad", AssertionLevel.error);
  assert(z >= 0.2 and zp >= -1.0e-3,
         "Acceptance FAILED: ground strike", AssertionLevel.error);
  assert(time < t_settle or track_err <= track_tol + 1.0e-6,
         "Acceptance FAILED: primary tracking error after 10.4 s", AssertionLevel.error);
  assert(time < 14.0 or place_err <= zoneRadius + 1.0e-6,
         "Acceptance FAILED: target-zone placement", AssertionLevel.error);
  assert(abs(x) < 1.0e10 and abs(z) < 1.0e10 and abs(vx) < 1.0e10 and abs(vz) < 1.0e10 and
         abs(theta) < 1.0e10 and abs(omega) < 1.0e10 and abs(T1) < 1.0e10 and abs(T2) < 1.0e10 and
         abs(gamma1) < 1.0e10 and abs(gamma2) < 1.0e10 and abs(T_cable) < 1.0e10 and
         abs(ax) < 1.0e10 and abs(az) < 1.0e10,
         "Acceptance FAILED: NaN or infinite value detected", AssertionLevel.error);

algorithm
  // ===== Sampled controller at 250 Hz =====
  when sample(0, Ts) then
    dFx_des := max(Kp_x*(x_ref - x) + Kd_x*(vx_ref - vx) + k_swing*omega, 0.0);
    dFz_des := max(Kp_z*(z_ref - z) + Kd_z*(vz_ref - vz) + (m + m_p)*g, 0.1);
    dgamma_des := min(max(atan(dFx_des / dFz_des), gamma_min), gamma_max);
    if sin(dgamma_des) > 1.0e-3 then
      dT_total := dFx_des / sin(dgamma_des);
    else
      dT_total := dFz_des / max(cos(dgamma_des), 1.0e-3);
    end if;
    T1_cmd := min(max(dT_total/2.0, 0.0), thrust_max);
    T2_cmd := min(max(dT_total/2.0, 0.0), thrust_max);
    gamma1_cmd := dgamma_des;
    gamma2_cmd := dgamma_des;
  end when;

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