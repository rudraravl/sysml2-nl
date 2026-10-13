model ROVHoldB
  // Physical parameters (SI units)
  parameter Real m = 115.0 "ROV mass [kg]";
  parameter Real Lx = 1.1 "frame length [m]";
  parameter Real Ly = 0.78 "frame width [m]";
  parameter Real Lz = 0.58 "frame height [m]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real rho_w = 1025.0 "seawater density [kg/m3]";
  parameter Real Vol = Lx * Ly * Lz "displaced volume [m3]";
  parameter Real W = m * g "weight [N]";
  parameter Real B = 1.02 * W "buoyancy, slightly positive [N]";
  parameter Real Fmax = 135.0 "per-thruster command bound [N]";

  // Added mass and inertia
  parameter Real ma_x = 0.20 * m;
  parameter Real ma_y = 0.50 * m;
  parameter Real ma_z = 0.30 * m;
  parameter Real Ixx = m / 12.0 * (Ly * Ly + Lz * Lz);
  parameter Real Iyy = m / 12.0 * (Lx * Lx + Lz * Lz);
  parameter Real Izz = m / 12.0 * (Lx * Lx + Ly * Ly);
  parameter Real Ja_x = 0.20 * Ixx;
  parameter Real Ja_y = 0.20 * Iyy;
  parameter Real Ja_z = 0.20 * Izz;

  // Hydrodynamic damping
  parameter Real d_lin = 60.0 "translational linear damping [Ns/m]";
  parameter Real d_rot = 6.0 "rotational linear damping [Nms/rad]";

  // Target pose (station-keeping setpoint)
  parameter Real xd = 5.0;
  parameter Real yd = 0.0;
  parameter Real zd = -10.0;
  parameter Real phid = 0.0;
  parameter Real thetad = 0.0;
  parameter Real psid = 0.0;

  // Offshore structure: fixed vertical collidable cylinder at origin
  parameter Real Rcyl = 1.5 "cylinder radius [m]";
  parameter Real Hcyl = 20.0 "cylinder height [m]";

  // Tether
  parameter Real L_tether_max = 30.0 "tether length limit [m]";
  parameter Real k_tether = 1000.0 "tether stiffness [N/m]";
  parameter Real L_tether0 = 12.0 "tether rest length [m]";

  // Controller gains (sampled PD body-wrench station keeping)
  parameter Real Kp_pos = 700.0;
  parameter Real Kd_pos = 400.0;
  parameter Real Kp_att = 40.0;
  parameter Real Kd_att = 16.0;

  // Discrete controller outputs (100 Hz)
  discrete Real Fx_cmd(start = 0.0);
  discrete Real Fy_cmd(start = 0.0);
  discrete Real Fz_cmd(start = 0.0);
  discrete Real Tx_cmd(start = 0.0);
  discrete Real Ty_cmd(start = 0.0);
  discrete Real Tz_cmd(start = 0.0);

  // Thruster commands (pre-saturation) and applied wrench (post-saturation)
  Real T1, T2, T3, T4, T5, T6;
  Real Fx, Fy, Fz, Tx, Ty, Tz;

  // Disturbance
  Real F_dist_window;
  Real F_dist;

  // Tether
  Real tether_length;
  Real tether_tension;

  // Dynamic states
  Real x(start = xd), y(start = yd), z(start = zd);
  Real phi(start = 0.0), theta(start = 0.0), psi(start = 0.0);
  Real vx(start = 0.0), vy(start = 0.0), vz(start = 0.0);
  Real wx(start = 0.0), wy(start = 0.0), wz(start = 0.0);

  // Accelerations
  Real ax, ay, az;

  // Sensors
  Real pressure_meas;
  Real accel_x_meas, accel_y_meas, accel_z_meas;
  Real wx_meas, wy_meas, wz_meas;
  Real vx_dvl, vy_dvl, vz_dvl;
  Real sonar_range;

  // Monitoring / requirements
  Real pos_error;
  Real att_error;
  Real clearance;
  Boolean thruster_ok;
  Boolean tether_ok;
  Boolean clearance_ok;
  Boolean tracking_ok;

initial equation
  x = xd; y = yd; z = zd;
  phi = 0.0; theta = 0.0; psi = 0.0;
  vx = 0.0; vy = 0.0; vz = 0.0;
  wx = 0.0; wy = 0.0; wz = 0.0;

equation
  // Controlled disturbance: middle third of 10 s mission -> [3.333, 6.667] s
  F_dist_window = if (time >= 10.0 / 3.0 and time <= 20.0 / 3.0) then 84.0 else 0.0;
  F_dist = F_dist_window;

  // Tether geometry and simple tension (slack-tolerant)
  tether_length = sqrt(x * x + y * y + z * z);
  tether_tension = max(0.0, k_tether * (tether_length - L_tether0));

  // Rigid-body dynamics (decoupled, small-angle, body~world frame)
  ax = (Fx + F_dist - d_lin * vx) / (m + ma_x);
  ay = (Fy - d_lin * vy) / (m + ma_y);
  az = (Fz + (B - W) - d_lin * vz) / (m + ma_z);

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  der(phi) = wx;
  der(theta) = wy;
  der(psi) = wz;
  der(wx) = (Tx - d_rot * wx) / (Ixx + Ja_x);
  der(wy) = (Ty - d_rot * wy) / (Iyy + Ja_y);
  der(wz) = (Tz - d_rot * wz) / (Izz + Ja_z);

  // Thruster allocation: B = identity (one thruster per body-wrench DOF)
  T1 = Fx_cmd;
  T2 = Fy_cmd;
  T3 = Fz_cmd;
  T4 = Tx_cmd;
  T5 = Ty_cmd;
  T6 = Tz_cmd;

  // Bounded applied wrench (per-thruster saturation)
  Fx = max(-Fmax, min(Fmax, T1));
  Fy = max(-Fmax, min(Fmax, T2));
  Fz = max(-Fmax, min(Fmax, T3));
  Tx = max(-Fmax, min(Fmax, T4));
  Ty = max(-Fmax, min(Fmax, T5));
  Tz = max(-Fmax, min(Fmax, T6));

  // Pressure sensor (depth from z, z upward positive)
  pressure_meas = 101325.0 + rho_w * g * (-z) + 0.5 * sin(6.28318 * 0.7 * time);

  // IMU: angular rates and linear accelerations with small deterministic noise
  wx_meas = wx + 0.005 * sin(6.28318 * 0.9 * time);
  wy_meas = wy + 0.005 * sin(6.28318 * 1.1 * time);
  wz_meas = wz + 0.005 * sin(6.28318 * 1.5 * time);
  accel_x_meas = ax + 0.01 * sin(6.28318 * 2.3 * time);
  accel_y_meas = ay + 0.01 * sin(6.28318 * 2.7 * time);
  accel_z_meas = az + 0.01 * sin(6.28318 * 3.1 * time);

  // DVL: body-frame velocities with small noise
  vx_dvl = vx + 0.02 * sin(6.28318 * 1.3 * time);
  vy_dvl = vy + 0.02 * sin(6.28318 * 1.7 * time);
  vz_dvl = vz + 0.02 * sin(6.28318 * 2.1 * time);

  // Forward sonar: range to cylinder surface (clamped to positive)
  sonar_range = max(0.1, sqrt(x * x + y * y) - Rcyl);

  // Requirement monitors
  pos_error = sqrt((x - xd) ^ 2 + (y - yd) ^ 2 + (z - zd) ^ 2);
  att_error = sqrt(phi * phi + theta * theta + psi * psi);
  clearance = sqrt(x * x + y * y) - Rcyl;
  thruster_ok = abs(T1) <= Fmax + 1.0 and abs(T2) <= Fmax + 1.0 and
                abs(T3) <= Fmax + 1.0 and abs(T4) <= Fmax + 1.0 and
                abs(T5) <= Fmax + 1.0 and abs(T6) <= Fmax + 1.0;
  tether_ok = tether_length <= L_tether_max;
  clearance_ok = clearance > 0.0;
  tracking_ok = (if time >= 6.5 then pos_error < 0.36 else true);

  // Discrete bounded body-wrench station-keeping controller at 100 Hz
  when sample(0, 0.01) then
    Fx_cmd = Kp_pos * (xd - x) - Kd_pos * vx;
    Fy_cmd = Kp_pos * (yd - y) - Kd_pos * vy;
    // Feed-forward buoyancy compensation: counter net upward buoyancy (B - W)
    Fz_cmd = Kp_pos * (zd - z) - Kd_pos * vz - (B - W);
    Tx_cmd = Kp_att * (phid - phi) - Kd_att * wx;
    Ty_cmd = Kp_att * (thetad - theta) - Kd_att * wy;
    Tz_cmd = Kp_att * (psid - psi) - Kd_att * wz;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "ROVHoldB: 6-DOF free-base marine robot station-keeping beside a fixed collidable cylinder. 115 kg slightly buoyant box frame with six bounded body-wrench thrusters (135 N each). Pressure/IMU/DVL/forward-sonar instrumentation. Controlled 84 N tether/current load disturbance injected during the middle third [3.33,6.67] s. 100 Hz discrete PD controller with per-thruster saturation. Monitors thruster bounds, position/attitude error, structure clearance, tether length, and tracking error < 0.36 m after 6.5 s."));
end ROVHoldB;