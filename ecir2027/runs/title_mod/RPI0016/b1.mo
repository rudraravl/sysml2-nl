model QuadScoutDeliverD
  "Instrumented free-base aerial robot with suspended payload delivery";

  // ---------------- Physical parameters ----------------
  parameter Real m_q = 1.8 "fuselage mass [kg]";
  parameter Real m_p = 0.5 "payload mass [kg] (assumed nominal; requirement did not specify)";
  parameter Real L   = 1.0 "cable length [m] (assumed nominal; requirement did not specify)";
  parameter Real arm = 0.22 "rotor arm length [m]";
  parameter Real k_yaw = 0.10 "yaw-moment coefficient [N.m per N of yaw differential]";
  parameter Real I_pitch = 0.05 "pitch inertia [kg.m2] (assumed nominal; requirement did not specify)";
  parameter Real I_yaw   = 0.05 "yaw inertia [kg.m2] (assumed nominal; requirement did not specify)";
  parameter Real c_pitch = 0.2 "pitch rotational damping [N.m.s]";
  parameter Real c_yaw   = 0.2 "yaw rotational damping [N.m.s]";
  parameter Real cd_x = 0.15 "horizontal drag coefficient [N.s2/m2]";
  parameter Real cd_z = 0.15 "vertical drag coefficient [N.s2/m2]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real Tmax = 12.0 "per-rotor thrust limit [N]";
  parameter Real F_gust = 8.0 "gust force amplitude [N]";
  parameter Real t_g0 = 14.0/3.0 "gust start [s] (middle third of 14 s run)";
  parameter Real t_g1 = 28.0/3.0 "gust end [s]";

  // ---------------- Target ----------------
  parameter Real x_target = 5.0 "horizontal translation target [m]";
  parameter Real z_target = 0.0 "payload target height [m]";
  parameter Real R_target = 0.8 "target-zone radius [m]";

  // ---------------- Control gains ----------------
  parameter Real Kp_x = 3.0;
  parameter Real Kd_x = 3.5;
  parameter Real Ki_x = 1.5;
  parameter Real Kp_z = 6.0;
  parameter Real Kd_z = 4.0;
  parameter Real Ki_z = 2.0;
  parameter Real Kd_swing = 1.5;
  parameter Real Kp_phi = 12.0;
  parameter Real Kd_phi = 3.0;
  parameter Real Kp_psi = 8.0;
  parameter Real Kd_psi = 3.0;
  parameter Real phi_lim = 0.40 "pitch command limit [rad]";
  parameter Real i_lim = 5.0 "integrator anti-windup limit";
  parameter Real eps = 1.0e-6 "zero-error branch constant for divisors/sqrt";

  // ---------------- Continuous states ----------------
  Real x(start=0.0, fixed=true) "quad x [m]";
  Real z(start=2.0, fixed=true) "quad z [m]";
  Real vx(start=0.0, fixed=true) "quad x-velocity [m/s]";
  Real vz(start=0.0, fixed=true) "quad z-velocity [m/s]";
  Real phi(start=0.0, fixed=true) "pitch angle [rad]";
  Real phidot(start=0.0, fixed=true) "pitch rate [rad/s]";
  Real psi(start=0.0, fixed=true) "yaw angle [rad]";
  Real psidot(start=0.0, fixed=true) "yaw rate [rad/s]";
  Real theta(start=0.0, fixed=true) "cable angle from vertical [rad]";
  Real thetadot(start=0.0, fixed=true) "cable angular rate [rad/s]";
  Real ix(start=0.0, fixed=true) "x-position integral state";
  Real iz(start=0.0, fixed=true) "z-position integral state";

  // ---------------- Actuators ----------------
  Real u1,u2,u3,u4 "rotor thrust commands [N]";
  Real u1c,u2c,u3c,u4c "clamped rotor thrusts [N]";
  Real F_T "total realized thrust [N]";
  Real M_pitch "realized pitch moment [N.m]";
  Real M_yaw "realized yaw moment [N.m]";
  Real F_T_des, phi_des_c, ax_cmd, az_cmd, M_pitch_des, M_yaw_des;

  // ---------------- Forces / motion ----------------
  Real Fx_thrust, Fz_thrust;
  Real F_drag_x, F_drag_z;
  Real F_gust_x, gust_pulse;
  Real vmag_x, vmag_z;
  Real A_x, A_z "quad acceleration excluding cable [m/s2]";
  Real ax, az "quad acceleration [m/s2]";
  Real T_raw, T_tension "cable tension [N]";
  Real px, pz "payload position [m]";

  // ---------------- Trajectory ----------------
  Real x_des, z_des, vx_des, vz_des;

  // ---------------- Metrics ----------------
  Real err_track "quad position tracking error [m]";
  Real err_payload "payload distance to target centre [m]";
  Real swing "absolute cable swing [rad]";
  Real thrust_max_used "max realized rotor thrust [N]";

  // ---------------- Sensors (continuous) ----------------
  Real gps_x, gps_z;
  Real imu_ax, imu_az;
  Real gyro_p, gyro_y;
  Real sens_theta, sens_T;

  // ---------------- 200 Hz synchronized traces ----------------
  discrete Real log_t(start=0.0);
  discrete Real log_x(start=0.0);
  discrete Real log_z(start=2.0);
  discrete Real log_vx(start=0.0);
  discrete Real log_vz(start=0.0);
  discrete Real log_phi(start=0.0);
  discrete Real log_psi(start=0.0);
  discrete Real log_theta(start=0.0);
  discrete Real log_T(start=0.0);
  discrete Real log_u1(start=0.0);
  discrete Real log_u2(start=0.0);
  discrete Real log_u3(start=0.0);
  discrete Real log_u4(start=0.0);
  discrete Real log_px(start=0.0);
  discrete Real log_pz(start=1.0);
  discrete Real log_err(start=0.0);
  discrete Real log_errp(start=0.0);

protected

  function smoothstep
    "Smoothly interpolates from 0 to 1 over [t0, t1]"
    input Real t;
    input Real t0;
    input Real t1;
    output Real y;
  protected
    Real dt;
  algorithm
    dt := t1 - t0;
    if dt <= 0.0 then
      y := if t >= t1 then 1.0 else 0.0;
    elseif t <= t0 then
      y := 0.0;
    elseif t >= t1 then
      y := 1.0;
    else
      y := 0.5*(1.0 - cos(3.141592653589793*(t - t0)/dt));
    end if;
  end smoothstep;

  function smoothstep_der
    "Time derivative of smoothstep"
    input Real t;
    input Real t0;
    input Real t1;
    output Real y;
  protected
    Real dt;
  algorithm
    dt := t1 - t0;
    if dt <= 0.0 then
      y := 0.0;
    elseif t <= t0 then
      y := 0.0;
    elseif t >= t1 then
      y := 0.0;
    else
      y := (3.141592653589793/(2.0*dt))*sin(3.141592653589793*(t - t0)/dt);
    end if;
  end smoothstep_der;

  function clamp
    "Limit v to [lo, hi]"
    input Real v;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if v < lo then lo elseif v > hi then hi else v;
  end clamp;

equation

  // ---- Input-shaped position trajectory ----
  x_des  = x_target*smoothstep(time, 2.0, 10.0);
  z_des  = 2.0 + 1.0*smoothstep(time, 0.5, 2.0) - 2.0*smoothstep(time, 10.0, 13.0);
  vx_des = x_target*smoothstep_der(time, 2.0, 10.0);
  vz_des = 1.0*smoothstep_der(time, 0.5, 2.0) - 2.0*smoothstep_der(time, 10.0, 13.0);

  // ---- Integrators with anti-windup clamp ----
  der(ix) = if (ix >  i_lim and (x_des - x) > 0.0) then 0.0
       else if (ix < -i_lim and (x_des - x) < 0.0) then 0.0
       else (x_des - x);
  der(iz) = if (iz >  i_lim and (z_des - z) > 0.0) then 0.0
       else if (iz < -i_lim and (z_des - z) < 0.0) then 0.0
       else (z_des - z);

  // ---- Position control with cable-swing damping ----
  ax_cmd = Kp_x*(x_des - x) + Kd_x*(vx_des - vx) + Ki_x*clamp(ix, -i_lim, i_lim) - Kd_swing*thetadot;
  az_cmd = Kp_z*(z_des - z) + Kd_z*(vz_des - vz) + Ki_z*clamp(iz, -i_lim, i_lim);

  F_T_des   = m_q*sqrt((g + az_cmd)*(g + az_cmd) + ax_cmd*ax_cmd + eps);
  phi_des_c = clamp(atan2(ax_cmd, g + az_cmd), -phi_lim, phi_lim);

  // ---- Attitude (pitch/yaw) commands ----
  M_pitch_des = Kp_phi*(phi_des_c - phi) - Kd_phi*phidot;
  M_yaw_des   = -Kp_psi*psi - Kd_psi*psidot;

  // ---- Rotor mixer (thrust + pitch moment + yaw moment, roll=0) ----
  u1 = F_T_des/4.0 + M_pitch_des/(4.0*arm) + M_yaw_des/(4.0*k_yaw);
  u2 = F_T_des/4.0 + M_pitch_des/(4.0*arm) - M_yaw_des/(4.0*k_yaw);
  u3 = F_T_des/4.0 - M_pitch_des/(4.0*arm) + M_yaw_des/(4.0*k_yaw);
  u4 = F_T_des/4.0 - M_pitch_des/(4.0*arm) - M_yaw_des/(4.0*k_yaw);

  u1c = clamp(u1, 0.0, Tmax);
  u2c = clamp(u2, 0.0, Tmax);
  u3c = clamp(u3, 0.0, Tmax);
  u4c = clamp(u4, 0.0, Tmax);

  F_T     = u1c + u2c + u3c + u4c;
  M_pitch = arm*((u1c + u2c) - (u3c + u4c));
  M_yaw   = k_yaw*((u1c - u2c) + (u3c - u4c));

  // ---- Thrust vectoring (thrust along body Z, tilt by pitch) ----
  Fx_thrust = F_T*sin(phi);
  Fz_thrust = F_T*cos(phi);

  // ---- Aerodynamic drag (smooth |v| with zero-error branch) ----
  vmag_x = sqrt(vx*vx + eps);
  vmag_z = sqrt(vz*vz + eps);
  F_drag_x = -cd_x*vx*vmag_x;
  F_drag_z = -cd_z*vz*vmag_z;

  // ---- Gust disturbance during middle third of the run ----
  gust_pulse = smoothstep(time, t_g0, t_g0 + 0.3) - smoothstep(time, t_g1 - 0.3, t_g1);
  F_gust_x = F_gust*gust_pulse;

  // ---- Quad acceleration excluding cable contribution ----
  A_x = (Fx_thrust + F_drag_x + F_gust_x)/m_q;
  A_z = (Fz_thrust + F_drag_z - m_q*g)/m_q;

  // ---- Cable tension (explicit, no algebraic loop) ----
  T_raw = (m_p*m_q/(m_q + m_p))*(
            g*cos(theta)
          - A_x*sin(theta)
          + A_z*cos(theta)
          + L*thetadot*thetadot);
  T_tension = 0.5*(T_raw + sqrt(T_raw*T_raw + eps));

  // ---- Quad acceleration including cable reaction ----
  ax = A_x + (T_tension*sin(theta))/m_q;
  az = A_z - (T_tension*cos(theta))/m_q;

  // ---- Dynamics ----
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax;
  der(vz) = az;
  der(phi) = phidot;
  der(phidot) = (M_pitch - c_pitch*phidot)/I_pitch;
  der(psi) = psidot;
  der(psidot) = (M_yaw - c_yaw*psidot)/I_yaw;
  der(theta) = thetadot;
  der(thetadot) = (-g*sin(theta) - ax*cos(theta) - az*sin(theta))/L;

  // ---- Payload kinematics ----
  px = x + L*sin(theta);
  pz = z - L*cos(theta);

  // ---- Sensors ----
  gps_x = x;
  gps_z = z;
  imu_ax = ax;
  imu_az = az;
  gyro_p = phidot;
  gyro_y = psidot;
  sens_theta = theta;
  sens_T = T_tension;

  // ---- Requirement metrics ----
  err_track   = sqrt((x_des - x)*(x_des - x) + (z_des - z)*(z_des - z) + eps);
  err_payload = sqrt((px - x_target)*(px - x_target) + (pz - z_target)*(pz - z_target) + eps);
  swing       = sqrt(theta*theta + eps);

  // ---- Thrust bound (scalar explicit max) ----
  thrust_max_used = if (u1c >= u2c and u1c >= u3c and u1c >= u4c) then u1c
                    else if (u2c >= u3c and u2c >= u4c) then u2c
                    else if (u3c >= u4c) then u3c
                    else u4c;

  // ---- 200 Hz synchronized state/command/sensor traces ----
  when sample(0.0, 0.005) then
    log_t = time;
    log_x = x;
    log_z = z;
    log_vx = vx;
    log_vz = vz;
    log_phi = phi;
    log_psi = psi;
    log_theta = theta;
    log_T = T_tension;
    log_u1 = u1c;
    log_u2 = u2c;
    log_u3 = u3c;
    log_u4 = u4c;
    log_px = px;
    log_pz = pz;
    log_err = err_track;
    log_errp = err_payload;
  end when;

  // ---- Requirement enforcement (no NaN/infinite guaranteed by eps guards) ----
  assert(abs(theta) < 0.45, "Swing exceeds 0.45 rad bound");
  assert(pz >= -1.0e-6, "Ground strike: payload below ground plane");
  assert(z  >= -1.0e-6, "Ground strike: quad below ground plane");
  assert(T_tension >= -1.0e-6, "Tension bound violated (negative tension)");
  assert(thrust_max_used <= Tmax + 1.0e-6, "Per-rotor thrust bound violated");
  assert(time <= 9.1 or err_track < 0.3, "Primary tracking error above 0.3 m after 9.1 s");
  assert(time <= 13.5 or err_payload < R_target, "Target-zone placement not satisfied");

  annotation (
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "Free-base quadrotor (QuadScoutDeliverD) lifting, translating 5 m, and lowering a suspended payload into a 0.8 m target zone. Control rate 200 Hz. 8 N lateral gust applied over the middle third [4.667,9.333] s. Quantities not specified in the requirement (payload mass, cable length, inertias) are assigned assumed nominals and labelled in their parameter comments."));
end QuadScoutDeliverD;