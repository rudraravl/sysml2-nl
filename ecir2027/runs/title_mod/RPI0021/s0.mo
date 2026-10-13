model QuadScoutTouchC
  // ===================== Physical parameters =====================
  parameter Real m = 1.8 "fuselage mass [kg]";
  parameter Real d_arm = 0.22 "rotor arm length [m]";
  parameter Real Iyy = 0.030 "pitch inertia about body y [kg.m2]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real L_probe = 0.35 "probe length forward of fuselage center [m]";

  // ===================== Environment / wall =====================
  parameter Real x_wall = 5.0 "wall x position [m]";
  parameter Real z_ref = 1.5 "reference altitude [m]";
  parameter Real k_wall = 800.0 "wall normal stiffness [N/m]";
  parameter Real b_wall = 30.0 "wall normal damping [N.s/m]";
  parameter Real mu_wall = 0.55 "wall Coulomb friction coefficient";

  // ===================== Disturbance =====================
  parameter Real F_wind = 2.7 "tangential wind disturbance [N]";
  parameter Real t_wind_on = 4.0 "wind start [s]";
  parameter Real t_wind_off = 8.0 "wind stop [s]";

  // ===================== Mission =====================
  parameter Real t_run = 12.0 "run duration [s]";
  parameter Real t_hold = 9.0 "contact hold start (last quarter) [s]";
  parameter Real t_switch = 7.8 "trajectory switch time [s]";
  parameter Real stand_off = 0.20 "approach stand-off [m]";
  parameter Real F_contact_ref = 8.0 "reference normal contact force [N]";
  parameter Real v_approach = 0.65 "fast approach speed [m/s]";
  parameter Real v_slow = 0.25 "slow contact-approach speed [m/s]";

  // ===================== Control gains =====================
  parameter Real k_d = 8.0 "x impedance stiffness [N/m]";
  parameter Real b_d = 6.0 "x impedance damping [N.s/m]";
  parameter Real Kd_f = 30.0 "in-contact extra velocity damping [N.s/m]";
  parameter Real Kp_z = 20.0 "altitude position gain [N/m]";
  parameter Real Kd_z = 7.0 "altitude velocity gain [N.s/m]";
  parameter Real Kp_th = 6.0 "pitch attitude gain [N.m/rad]";
  parameter Real Kd_th = 1.0 "pitch rate gain [N.m.s/rad]";

  // ===================== Limits =====================
  parameter Real T_max = 11.0 "max thrust per rotor [N]";
  parameter Real theta_max = 0.50 "max pitch [rad]";

  // ===================== States =====================
  Real x(start=0.0, fixed=true) "fuselage x position [m]";
  Real vx(start=0.0, fixed=true) "fuselage x velocity [m/s]";
  Real z(start=1.5, fixed=true) "fuselage z position [m]";
  Real vz(start=0.0, fixed=true) "fuselage z velocity [m/s]";
  Real theta(start=0.0, fixed=true) "pitch angle [rad]";
  Real q(start=0.0, fixed=true) "pitch rate [rad/s]";

  // ===================== Rotor commands =====================
  Real T1 "front-right thrust command [N]";
  Real T2 "front-left thrust command [N]";
  Real T3 "rear-right thrust command [N]";
  Real T4 "rear-left thrust command [N]";
  Real T1s "saturated front-right thrust [N]";
  Real T2s "saturated front-left thrust [N]";
  Real T3s "saturated rear-right thrust [N]";
  Real T4s "saturated rear-left thrust [N]";
  Real T_tot_cmd "commanded total thrust [N]";
  Real T_tot_act "actual total thrust [N]";
  Real tau_pitch "commanded pitch torque [N.m]";
  // Each rotor also admits a signed yaw moment; yaw is stabilized to zero
  // and no yaw command is applied in this planar inspection task, so
  // front/rear rotor pairs are commanded identically within each pair.

  // ===================== Trajectory / control =====================
  Real x_cmd "commanded x [m]";
  Real x_cmd_dot "commanded x velocity [m/s]";
  Real z_cmd "commanded z [m]";
  Real F_x_des "desired horizontal thrust [N]";
  Real F_z_des "desired vertical thrust [N]";
  Real theta_cmd "commanded pitch [rad]";
  Real theta_cmd_sat "saturated pitch [rad]";
  Real x_target_approach "approach target [m]";
  Real x_contact_target "contact target [m]";
  Real pen_ref "reference penetration [m]";

  // ===================== Contact =====================
  Real probe_tip_x "probe tip world x [m]";
  Real penetration "wall penetration [m]";
  Real F_normal "wall normal force [N]";
  Real F_friction "wall friction force [N]";
  Boolean in_contact;

  // ===================== Disturbance =====================
  Real F_wind_t "active tangential wind [N]";

  // ===================== Sensors =====================
  Real lidar_range "lidar distance to wall [m]";
  Real F_probe_meas "probe force sensor reading [N]";
  Real theta_imu "IMU pitch estimate [rad]";
  Real vx_flow "optical-flow x velocity estimate [m/s]";

  // ===================== Validation =====================
  Real err_track "primary tracking error |x - x_cmd| [m]";
  Boolean thrust_ok "thrust within [0, T_max] for all rotors";
  Boolean attitude_ok "|theta| within theta_max";
  Boolean force_in_range "contact force in [5,14] N during hold";
  Boolean no_collision "no rotor (at +d_arm) reaches wall";
  Boolean nan_ok "no NaN/infinite physical, control, or estimator values";

protected
  Real T_front "combined front rotor thrust [N]";
  Real T_rear "combined rear rotor thrust [N]";
  Real abs_vz, sign_vz;

equation
  // Reference penetration where F_normal = F_contact_ref
  pen_ref = F_contact_ref / k_wall;
  x_target_approach = x_wall - L_probe - stand_off;
  x_contact_target = x_wall - L_probe + pen_ref;

  // Commanded x trajectory: fast approach to stand-off, then slow ramp into contact
  x_cmd = if time < t_switch then
            (if v_approach * time < x_target_approach then v_approach * time else x_target_approach)
          else
            (if x_target_approach + v_slow * (time - t_switch) < x_contact_target then
               x_target_approach + v_slow * (time - t_switch)
             else x_contact_target);

  x_cmd_dot = if time < t_switch then
                (if v_approach * time < x_target_approach then v_approach else 0.0)
              else
                (if x_target_approach + v_slow * (time - t_switch) < x_contact_target then v_slow else 0.0);

  z_cmd = z_ref;

  // Probe tip and contact
  probe_tip_x = x + L_probe;
  penetration = max(0.0, probe_tip_x - x_wall);
  in_contact = penetration > 1e-4;
  F_normal = if in_contact then (k_wall * penetration + b_wall * max(0.0, vx)) else 0.0;

  // Wall friction along z (smoothed sign to avoid discontinuity at vz=0)
  abs_vz = abs(vz);
  sign_vz = if abs_vz > 1e-3 then (vz / abs_vz) else 0.0;
  F_friction = if in_contact then (-mu_wall * F_normal * sign_vz) else 0.0;

  // Tangential wind (along wall, z direction) active in middle third
  F_wind_t = if (time >= t_wind_on and time <= t_wind_off) then F_wind else 0.0;

  // Hybrid position-to-impedance controller on x
  // Free flight: PD position with velocity feedforward
  // In contact: adds force feedforward and extra velocity damping (impedance)
  F_x_des = k_d * (x_cmd - x) + b_d * (x_cmd_dot - vx) +
            (if in_contact then (F_contact_ref - Kd_f * vx) else 0.0);
  F_z_des = m * g + Kp_z * (z_cmd - z) - Kd_z * vz;

  // Tilt and total thrust from desired force vector
  theta_cmd = atan2(F_x_des, F_z_des);
  theta_cmd_sat = if theta_cmd > theta_max then theta_max
                  else (if theta_cmd < -theta_max then -theta_max else theta_cmd);
  T_tot_cmd = F_z_des / cos(theta_cmd_sat);

  // Pitch attitude PD
  tau_pitch = Kp_th * (theta_cmd_sat - theta) - Kd_th * q;

  // Distribute thrust to rotor pairs (front +x, rear -x)
  T_front = (T_tot_cmd - tau_pitch / d_arm) / 2.0;
  T_rear = (T_tot_cmd + tau_pitch / d_arm) / 2.0;
  T1 = T_front / 2.0;
  T2 = T_front / 2.0;
  T3 = T_rear / 2.0;
  T4 = T_rear / 2.0;

  // Saturate each rotor command to [0, T_max]
  T1s = if T1 > T_max then T_max else (if T1 < 0.0 then 0.0 else T1);
  T2s = if T2 > T_max then T_max else (if T2 < 0.0 then 0.0 else T2);
  T3s = if T3 > T_max then T_max else (if T3 < 0.0 then 0.0 else T3);
  T4s = if T4 > T_max then T_max else (if T4 < 0.0 then 0.0 else T4);
  T_tot_act = T1s + T2s + T3s + T4s;

  // Rigid-body dynamics (planar: x-z translation + pitch)
  der(x) = vx;
  der(z) = vz;
  der(theta) = q;
  m * der(vx) = T_tot_act * sin(theta) - F_normal;
  m * der(vz) = T_tot_act * cos(theta) - m * g + F_friction + F_wind_t;
  Iyy * der(q) = d_arm * ((T3s + T4s) - (T1s + T2s));

  // Sensors
  lidar_range = max(0.0, x_wall - probe_tip_x);
  F_probe_meas = F_normal;
  theta_imu = theta;
  vx_flow = vx;

  // Primary tracking error
  err_track = abs(x - x_cmd);

  // Validation flags
  thrust_ok = (T1s >= -1e-6 and T1s <= T_max + 1e-6) and
              (T2s >= -1e-6 and T2s <= T_max + 1e-6) and
              (T3s >= -1e-6 and T3s <= T_max + 1e-6) and
              (T4s >= -1e-6 and T4s <= T_max + 1e-6);
  attitude_ok = abs(theta) <= theta_max + 1e-3;
  force_in_range = (time < t_hold) or (F_normal >= 5.0 and F_normal <= 14.0);
  no_collision = (x + d_arm) < x_wall;
  nan_ok = (x == x) and (z == z) and (theta == theta) and (vx == vx) and
           (F_normal == F_normal) and (T1s == T1s) and
           (abs(x) < 1e6) and (abs(z) < 1e6) and (abs(theta) < 1e6) and
           (abs(vx) < 1e6) and (abs(F_normal) < 1e6) and (abs(T1s) < 1e6);

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "QuadScoutTouchC: free-base aerial robot (1.8 kg box fuselage, 0.22 m arm length) using hybrid position-to-impedance control to approach a vertical inspection wall (friction 0.55), establish 5-14 N normal probe force, and hold contact over the last quarter of a 12 s run at 125 Hz. A 2.7 N tangential wind acts during the middle third. Thrust and attitude are bounded; approach speed is rate-limited. Yaw moments are admitted per rotor but yaw is stabilized to zero, so planar pitch/translation dynamics suffice."));
end QuadScoutTouchC;