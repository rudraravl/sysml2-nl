model QuadScoutTouchD
  /* QuadScoutTouchD: instrumented free-base aerial robot for contact inspection.
     1.8 kg box fuselage, 4 rotors at 0.22 m arm length, thrust along body Z
     with signed yaw moment, each rotor limited to 12 N.
     Wall: fixed collidable box, friction coefficient 0.55.
     Mission: approach vertical wall, establish bounded probe contact (5-14 N),
     hold contact for last quarter of 14 s run.
     Hybrid position-to-impedance control at 200 Hz.
     3 N tangential wind disturbance during middle third.
     Sensors: IMU, lidar, optical flow, probe force. */

  // ---------- Physical parameters ----------
  parameter Real m = 1.8 "fuselage mass [kg]";
  parameter Real L_arm = 0.22 "rotor arm length [m]";
  parameter Real T_max = 12.0 "max thrust per rotor [N]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real Ixx = 0.015 "roll inertia [kg.m2]";
  parameter Real Iyy = 0.015 "pitch inertia [kg.m2]";
  parameter Real Izz = 0.027 "yaw inertia [kg.m2]";
  parameter Real k_yaw = 0.05 "yaw torque per thrust [N.m/N]";
  parameter Real L_probe = 0.30 "probe length [m]";
  parameter Real k_contact = 1000.0 "contact stiffness [N/m]";
  parameter Real c_contact = 50.0 "contact damping [N.s/m]";
  parameter Real mu_wall = 0.55 "wall friction coefficient";
  parameter Real wall_x = 0.0 "wall plane x position [m]";

  // ---------- Mission parameters ----------
  parameter Real x_start = 2.0 "start x [m]";
  parameter Real z_start = 1.0 "start z [m]";
  parameter Real x_standoff = 0.30 "stand-off x (probe tip at wall) [m]";
  parameter Real F_contact_des = 7.0 "desired probe normal force [N]";
  parameter Real v_approach = 0.25 "approach speed [m/s]";
  parameter Real t_approach_end = 7.0 "approach phase end [s]";
  parameter Real t_contact_start = 9.0 "contact/impedance phase start [s]";
  parameter Real K_imp = 300.0 "impedance compliance gain [N/m]";
  parameter Real t_run = 14.0 "run duration [s]";

  // ---------- Control gains ----------
  parameter Real Kp_pos = 2.0 "position gain";
  parameter Real Kp_v = 4.0 "velocity-loop gain";
  parameter Real v_max = 1.0 "horizontal velocity bound [m/s]";
  parameter Real v_max_z = 1.0 "vertical velocity bound [m/s]";
  parameter Real amax = 5.0 "acceleration bound [m/s2]";
  parameter Real Kp_att = 30.0 "attitude proportional gain";
  parameter Real Kd_att = 10.0 "attitude derivative gain";
  parameter Real Kp_yaw = 8.0 "yaw proportional gain";
  parameter Real Kd_yaw = 3.0 "yaw derivative gain";
  parameter Real att_max = 0.50 "attitude bound [rad]";
  parameter Real M_max = 2.5 "body-moment bound [N.m]";

  // ---------- Continuous states ----------
  Real x_pos(start = x_start, fixed = true) "world x [m]";
  Real y_pos(start = 0.0, fixed = true) "world y [m]";
  Real z_pos(start = z_start, fixed = true) "world z [m]";
  Real vx(start = 0.0, fixed = true) "world x velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "world y velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "world z velocity [m/s]";
  Real phi(start = 0.0, fixed = true) "roll [rad]";
  Real theta(start = 0.0, fixed = true) "pitch [rad]";
  Real psi(start = 0.0, fixed = true) "yaw [rad]";
  Real p(start = 0.0, fixed = true) "body rate x [rad/s]";
  Real q(start = 0.0, fixed = true) "body rate y [rad/s]";
  Real r(start = 0.0, fixed = true) "body rate z [rad/s]";

  // ---------- Discrete controller outputs (assigned in when block) ----------
  Real T1_cmd(start = 0.0) "rotor 1 thrust command [N]";
  Real T2_cmd(start = 0.0) "rotor 2 thrust command [N]";
  Real T3_cmd(start = 0.0) "rotor 3 thrust command [N]";
  Real T4_cmd(start = 0.0) "rotor 4 thrust command [N]";

  // ---------- Saturated thrusts and aggregate ----------
  Real T1_sat "saturated rotor 1 thrust [N]";
  Real T2_sat "saturated rotor 2 thrust [N]";
  Real T3_sat "saturated rotor 3 thrust [N]";
  Real T4_sat "saturated rotor 4 thrust [N]";
  Real T_total "total thrust [N]";
  Real Mx "body roll moment [N.m]";
  Real My "body pitch moment [N.m]";
  Real Mz "body yaw moment [N.m]";

  // ---------- Sensors ----------
  Real lidar_range "lidar range to wall [m]";
  Real flow_vx "optical flow x velocity [m/s]";
  Real flow_vy "optical flow y velocity [m/s]";
  Real F_probe_n "probe normal force [N]";
  Real F_probe_t "probe tangential force [N]";
  Real imu_ax "imu specific force x body [m/s2]";
  Real imu_ay "imu specific force y body [m/s2]";
  Real imu_az "imu specific force z body [m/s2]";

  // ---------- Environment forces ----------
  Real F_wind_x "wind force x [N]";
  Real F_wind_y "wind force y [N]";
  Real F_contact_x "contact force x [N]";
  Real F_contact_y "contact force y [N]";
  Real Fx_nograv "non-gravity force x world [N]";
  Real Fy_nograv "non-gravity force y world [N]";
  Real Fz_nograv "non-gravity force z world [N]";
  Real F_tan_raw "raw tangential force before friction clamp [N]";

  // ---------- Rotation helpers ----------
  Real R11, R12, R13, R21, R22, R23, R31, R32, R33;
  Real cphi, sphi, ctheta, stheta, cpsi, spsi, ttheta, ctheta_safe;

  // ---------- Controller internals (discrete) ----------
  Real ref_x(start = x_start);
  Real ref_y(start = 0.0);
  Real ref_z(start = z_start);
  Real ref_vx(start = 0.0);
  Real in_contact(start = 0.0);
  Real ex(start = 0.0);
  Real ey(start = 0.0);
  Real ez(start = 0.0);
  Real vd_x(start = 0.0);
  Real vd_y(start = 0.0);
  Real vd_z(start = 0.0);
  Real ax_des(start = 0.0);
  Real ay_des(start = 0.0);
  Real az_des(start = 0.0);
  Real T_cmd_raw(start = 0.0);
  Real T_cmd_clamped(start = 0.0);
  Real sin_theta_des(start = 0.0);
  Real sin_phi_des(start = 0.0);
  Real theta_des(start = 0.0);
  Real phi_des(start = 0.0);
  Real psi_des(start = 0.0);
  Real Mx_cmd(start = 0.0);
  Real My_cmd(start = 0.0);
  Real Mz_cmd(start = 0.0);
  Real a_mix(start = 0.0);
  Real b_mix(start = 0.0);
  Real c_mix(start = 0.0);
  Real d_mix(start = 0.0);

  // Stand-off tracking error (continuous, for monitoring)
  Real track_err_standoff "stand-off tracking error [m]";

equation
  // Trigonometric helpers
  cphi = cos(phi);
  sphi = sin(phi);
  ctheta = cos(theta);
  stheta = sin(theta);
  cpsi = cos(psi);
  spsi = sin(psi);
  ctheta_safe = if ctheta > 0.5 then ctheta else 0.5;
  ttheta = stheta / ctheta_safe;

  // Body-to-world rotation (ZYX: yaw-pitch-roll)
  R11 = cpsi * ctheta;
  R12 = cpsi * stheta * sphi - spsi * cphi;
  R13 = cpsi * stheta * cphi + spsi * sphi;
  R21 = spsi * ctheta;
  R22 = spsi * stheta * sphi + cpsi * cphi;
  R23 = spsi * stheta * cphi - cpsi * sphi;
  R31 = -stheta;
  R32 = ctheta * sphi;
  R33 = ctheta * cphi;

  // Per-rotor thrust saturation (independent, [0, T_max])
  T1_sat = if T1_cmd < 0.0 then 0.0 elseif T1_cmd > T_max then T_max else T1_cmd;
  T2_sat = if T2_cmd < 0.0 then 0.0 elseif T2_cmd > T_max then T_max else T2_cmd;
  T3_sat = if T3_cmd < 0.0 then 0.0 elseif T3_cmd > T_max then T_max else T3_cmd;
  T4_sat = if T4_cmd < 0.0 then 0.0 elseif T4_cmd > T_max then T_max else T4_cmd;

  // Aggregate thrust and body moments (plus configuration)
  T_total = T1_sat + T2_sat + T3_sat + T4_sat;
  Mx = L_arm * (T1_sat - T3_sat);
  My = L_arm * (T4_sat - T2_sat);
  Mz = k_yaw * (T1_sat - T2_sat + T3_sat - T4_sat);

  // Wind disturbance: 3 N tangential (+y) during the middle third of the run
  F_wind_x = 0.0;
  F_wind_y = if time >= t_run / 3.0 and time <= 2.0 * t_run / 3.0 then 3.0 else 0.0;

  // Probe contact: tip at x = x_pos - L_probe; wall at wall_x.
  // Penetration delta = (L_probe + wall_x) - x_pos, positive when penetrating.
  F_probe_n = if x_pos < L_probe + wall_x then
      k_contact * ((L_probe + wall_x) - x_pos) + c_contact * (if -vx > 0.0 then -vx else 0.0)
    else
      0.0;
  F_contact_x = F_probe_n;

  // Regularized Coulomb friction (tangential, opposes vy)
  F_tan_raw = -c_contact * 0.5 * vy;
  F_probe_t = if F_probe_n > 0.0 then
      (if F_tan_raw > mu_wall * F_probe_n then mu_wall * F_probe_n
       elseif F_tan_raw < -mu_wall * F_probe_n then -mu_wall * F_probe_n
       else F_tan_raw)
    else
      0.0;
  F_contact_y = F_probe_t;

  // Non-gravity forces in world frame
  Fx_nograv = T_total * R13 + F_contact_x + F_wind_x;
  Fy_nograv = T_total * R23 + F_contact_y + F_wind_y;
  Fz_nograv = T_total * R33;

  // Translational dynamics
  der(x_pos) = vx;
  der(y_pos) = vy;
  der(z_pos) = vz;
  m * der(vx) = Fx_nograv;
  m * der(vy) = Fy_nograv;
  m * der(vz) = Fz_nograv - m * g;

  // Rotational kinematics (Euler ZYX)
  der(phi) = p + sphi * ttheta * q + cphi * ttheta * r;
  der(theta) = cphi * q - sphi * r;
  der(psi) = (sphi / ctheta_safe) * q + (cphi / ctheta_safe) * r;
  // Rotational dynamics
  Ixx * der(p) = (Iyy - Izz) * q * r + Mx;
  Iyy * der(q) = (Izz - Ixx) * p * r + My;
  Izz * der(r) = (Ixx - Iyy) * p * q + Mz;

  // IMU specific force in body frame (non-gravity accel transformed by R^T)
  imu_ax = (R11 * Fx_nograv + R21 * Fy_nograv + R31 * Fz_nograv) / m;
  imu_ay = (R12 * Fx_nograv + R22 * Fy_nograv + R32 * Fz_nograv) / m;
  imu_az = (R13 * Fx_nograv + R23 * Fy_nograv + R33 * Fz_nograv) / m;

  // Lidar range (robot center to wall along x)
  lidar_range = if x_pos > wall_x then x_pos - wall_x else 0.0;
  // Optical flow (ground-relative horizontal velocity)
  flow_vx = vx;
  flow_vy = vy;
  // Stand-off tracking error (for requirement monitoring)
  track_err_standoff = abs(x_pos - x_standoff);

algorithm
  when sample(0, 0.005) then
    // ---- Hybrid position-to-impedance reference generation ----
    if time < t_approach_end then
      // Approach phase: bounded approach speed
      ref_x := if x_standoff + 0.005 > x_start - v_approach * time then
                 x_standoff + 0.005
               else
                 x_start - v_approach * time;
      ref_vx := -v_approach;
      in_contact := 0.0;
    elseif time < t_contact_start then
      // Hover at stand-off
      ref_x := x_standoff;
      ref_vx := 0.0;
      in_contact := if F_probe_n > 0.5 then 1.0 else 0.0;
    else
      // Contact/impedance: position setpoint adjusted by force error
      ref_x := x_standoff - F_contact_des / k_contact - (F_probe_n - F_contact_des) / K_imp;
      ref_vx := 0.0;
      in_contact := 1.0;
    end if;
    ref_y := 0.0;
    ref_z := z_start;

    // ---- Outer position -> velocity reference ----
    ex := ref_x - x_pos;
    ey := ref_y - y_pos;
    ez := ref_z - z_pos;

    vd_x := if ref_vx + Kp_pos * ex > v_max then v_max
            elseif ref_vx + Kp_pos * ex < -v_max then -v_max
            else ref_vx + Kp_pos * ex;
    vd_y := if Kp_pos * ey > v_max then v_max
            elseif Kp_pos * ey < -v_max then -v_max
            else Kp_pos * ey;
    vd_z := if Kp_pos * ez > v_max_z then v_max_z
            elseif Kp_pos * ez < -v_max_z then -v_max_z
            else Kp_pos * ez;

    // ---- Velocity -> desired acceleration (PD) ----
    ax_des := if Kp_v * (vd_x - vx) > amax then amax
              elseif Kp_v * (vd_x - vx) < -amax then -amax
              else Kp_v * (vd_x - vx);
    ay_des := if Kp_v * (vd_y - vy) > amax then amax
              elseif Kp_v * (vd_y - vy) < -amax then -amax
              else Kp_v * (vd_y - vy);
    az_des := if Kp_v * (vd_z - vz) > amax then amax
              elseif Kp_v * (vd_z - vz) < -amax then -amax
              else Kp_v * (vd_z - vz);

    // ---- Resolve thrust and desired attitude (yaw held at 0) ----
    T_cmd_raw := m * (az_des + g) / (if ctheta * cphi > 0.25 then ctheta * cphi else 0.25);
    T_cmd_clamped := if T_cmd_raw > 4.0 * T_max - 0.01 then 4.0 * T_max - 0.01
                     elseif T_cmd_raw < 0.5 * m * g then 0.5 * m * g
                     else T_cmd_raw;

    sin_theta_des := ax_des * m / T_cmd_clamped;
    sin_phi_des := -ay_des * m / T_cmd_clamped;
    theta_des := asin(if sin_theta_des > att_max then att_max
                      elseif sin_theta_des < -att_max then -att_max
                      else sin_theta_des);
    phi_des := asin(if sin_phi_des > att_max then att_max
                    elseif sin_phi_des < -att_max then -att_max
                    else sin_phi_des);
    psi_des := 0.0;

    // ---- Attitude inner loop -> body moments ----
    Mx_cmd := if Kp_att * (phi_des - phi) + Kd_att * (0.0 - p) > M_max then M_max
              elseif Kp_att * (phi_des - phi) + Kd_att * (0.0 - p) < -M_max then -M_max
              else Kp_att * (phi_des - phi) + Kd_att * (0.0 - p);
    My_cmd := if Kp_att * (theta_des - theta) + Kd_att * (0.0 - q) > M_max then M_max
              elseif Kp_att * (theta_des - theta) + Kd_att * (0.0 - q) < -M_max then -M_max
              else Kp_att * (theta_des - theta) + Kd_att * (0.0 - q);
    Mz_cmd := if Kp_yaw * (psi_des - psi) + Kd_yaw * (0.0 - r) > M_max then M_max
              elseif Kp_yaw * (psi_des - psi) + Kd_yaw * (0.0 - r) < -M_max then -M_max
              else Kp_yaw * (psi_des - psi) + Kd_yaw * (0.0 - r);

    // ---- Mixer (plus configuration) ----
    a_mix := (T_cmd_clamped + Mz_cmd / k_yaw) / 2.0;
    b_mix := (T_cmd_clamped - Mz_cmd / k_yaw) / 2.0;
    c_mix := Mx_cmd / L_arm;
    d_mix := My_cmd / L_arm;

    T1_cmd := if (a_mix + c_mix) / 2.0 > T_max then T_max
              elseif (a_mix + c_mix) / 2.0 < 0.0 then 0.0
              else (a_mix + c_mix) / 2.0;
    T2_cmd := if (b_mix - d_mix) / 2.0 > T_max then T_max
              elseif (b_mix - d_mix) / 2.0 < 0.0 then 0.0
              else (b_mix - d_mix) / 2.0;
    T3_cmd := if (a_mix - c_mix) / 2.0 > T_max then T_max
              elseif (a_mix - c_mix) / 2.0 < 0.0 then 0.0
              else (a_mix - c_mix) / 2.0;
    T4_cmd := if (b_mix + d_mix) / 2.0 > T_max then T_max
              elseif (b_mix + d_mix) / 2.0 < 0.0 then 0.0
              else (b_mix + d_mix) / 2.0;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "QuadScoutTouchD: instrumented free-base aerial robot for contact inspection."));
end QuadScoutTouchD;