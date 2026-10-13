model GliderDiveD
  /* GliderDiveD: instrumented free-base marine glider.
     Plant: 60 kg streamlined capsule hull (1.8 m, 0.42 m2 wing),
     variable-buoyancy unit (bounded to 0.001 m3 change) and a
     translating 6 kg internal pitch mass (bounded travel).
     Mission: descend to 8 m, hold, return to 3 m.
     Seawater density 1025 kg/m3, gravity, quadratic drag.
     Cascaded depth/attitude control with bounded allocation.
     80 N current force disturbance applied during middle third of 14 s run.
     NOTE: The 0.001 m3 buoyancy bound yields ~10 N of vertical authority.
     L_hull and A_wing are stated embodiment dimensions preserved as parameters.
  */

  // ---------------- Physical parameters (SI) ----------------
  parameter Real m_tot    = 60.0   "kg, total vehicle mass";
  parameter Real m_pm     = 6.0    "kg, translating internal pitch mass";
  parameter Real L_hull   = 1.8    "m, hull length (preserved embodiment dimension)";
  parameter Real A_wing   = 0.42   "m2, wing area (preserved embodiment dimension)";
  parameter Real rho_sw   = 1025.0 "kg/m3, seawater density";
  parameter Real g        = 9.81   "m/s2, gravitational acceleration";
  parameter Real deltaV_max = 0.001 "m3, buoyancy-volume change bound";
  parameter Real r_max    = 0.30   "m, pitch-mass travel bound";
  parameter Real I_pitch  = 16.2   "kg.m2, pitch inertia";
  parameter Real kx       = 0.5    "N.s2/m2, horizontal quadratic drag coefficient";
  parameter Real kz       = 0.02   "N.s2/m2, vertical quadratic drag coefficient";
  parameter Real Dq_pitch = 10.0   "N.m.s/rad, pitch rotational damping";
  parameter Real h_off    = 0.10   "m, vertical lever arm of current force";
  parameter Real F_cur    = 80.0   "N, current force magnitude";
  parameter Real T_end    = 14.0   "s, mission duration";
  parameter Real t_d1     = T_end/3.0      "s, disturbance start";
  parameter Real t_d2     = 2.0*T_end/3.0  "s, disturbance end";

  // ---------------- Controller parameters ----------------
  parameter Real Kz_gain  = 1.0    "1/s, depth->vertical-velocity gain";
  parameter Real vz_max   = 3.0    "m/s, vertical-velocity command clamp";
  parameter Real Kvz_gain = 1.0e-3 "m3/(m/s), vertical-velocity->buoyancy gain";
  parameter Real Kth_gain = 4.0    "1/s, pitch-angle->pitch-rate gain";
  parameter Real q_max    = 0.5    "rad/s, pitch-rate command clamp";
  parameter Real Kq_gain  = 0.30   "m/(rad/s), pitch-rate->pitch-mass gain";
  parameter Real tau_b    = 0.15   "s, buoyancy actuator lag";
  parameter Real tau_r    = 0.12   "s, pitch-mass actuator lag";

  // ---------------- Dynamic states ----------------
  Real x(start=0.0)        "m, horizontal position";
  Real vx(start=0.0)       "m/s, horizontal velocity";
  Real z(start=0.0)        "m, depth (downward positive)";
  Real vz(start=0.0)       "m/s, vertical velocity (downward positive)";
  Real theta(start=0.0)    "rad, pitch (nose-down positive)";
  Real q_pitch(start=0.0)  "rad/s, pitch rate";
  Real phi(start=0.0)      "rad, roll";
  Real p_roll(start=0.0)   "rad/s, roll rate";
  Real psi(start=0.0)      "rad, heading (yaw)";
  Real r_yaw(start=0.0)    "rad/s, yaw rate";
  Real deltaV(start=0.0)   "m3, buoyancy volume change actuator state";
  Real r_pm(start=0.0)     "m, pitch-mass displacement actuator state";

  // ---------------- Commands ----------------
  Real z_cmd        "m, depth command";
  Real vz_cmd       "m/s, vertical-velocity command";
  Real deltaV_cmd   "m3, buoyancy command (bounded)";
  Real theta_cmd    "rad, pitch command";
  Real q_cmd        "rad/s, pitch-rate command";
  Real r_pm_cmd     "m, pitch-mass command (bounded)";

  // ---------------- Disturbance ----------------
  Real F_dist "N, horizontal current force";
  Real M_dist "N.m, pitch disturbance moment from offset current force";

  // ---------------- Sensor traces ----------------
  Real z_meas "m, pressure-depth measurement";
  Real vx_meas "m/s, Doppler horizontal velocity measurement";
  Real vz_meas "m/s, Doppler vertical velocity measurement";
  Real theta_meas "rad, IMU pitch measurement";
  Real phi_meas "rad, IMU roll measurement";
  Real psi_meas "rad, IMU heading measurement";
  Real q_meas "rad/s, IMU pitch-rate measurement";
  Real p_meas "rad/s, IMU roll-rate measurement";
  Real r_meas "rad/s, IMU yaw-rate measurement";

  // ---------------- Auxiliary ----------------
  Real V_tot           "m/s, total speed magnitude (zero-safe)";
  Real tracking_error  "m, primary depth tracking error (z - z_cmd)";
  Real deltaV_ff       "m3, buoyancy feedforward";
  Real vz_cmd_raw      "m/s, unsaturated vertical-velocity command";
  Real q_cmd_raw       "rad/s, unsaturated pitch-rate command";
  Real deltaV_sat      "m3, saturated buoyancy command";
  Real r_pm_sat        "m, saturated pitch-mass command";

equation
  // ===== Mission schedule: descend 8 m, hold, return to 3 m =====
  z_cmd = if (time < 6.0) then 8.0 elseif (time < 9.0) then 8.0 else 3.0;

  // ===== Disturbance: 80 N horizontal current over middle third =====
  F_dist = if (time >= t_d1) and (time <= t_d2) then F_cur else 0.0;
  M_dist = F_dist * h_off;

  // ===== Cascaded depth controller: depth -> vertical velocity -> buoyancy =====
  vz_cmd_raw = Kz_gain * (z_cmd - z);
  vz_cmd = if (vz_cmd_raw > vz_max) then vz_max elseif (vz_cmd_raw < -vz_max) then -vz_max else vz_cmd_raw;

  // Feedforward: steady buoyancy for commanded vz (downward vz needs positive deltaV-down)
  deltaV_ff = -kz * vz_cmd * vz_cmd * sign(vz_cmd) / (rho_sw * g);
  // Feedback adds downward force when vertical velocity lags command
  deltaV_sat = deltaV_ff - Kvz_gain * (vz_cmd - vz);
  deltaV_cmd = if (deltaV_sat > deltaV_max) then deltaV_max elseif (deltaV_sat < -deltaV_max) then -deltaV_max else deltaV_sat;

  // ===== Cascaded attitude controller: pitch -> pitch rate -> pitch mass =====
  theta_cmd = 0.0;   // hold zero pitch (level); heading held zero passively
  q_cmd_raw = Kth_gain * (theta_cmd - theta);
  q_cmd = if (q_cmd_raw > q_max) then q_max elseif (q_cmd_raw < -q_max) then -q_max else q_cmd_raw;
  r_pm_sat = Kq_gain * (q_cmd - q_pitch);
  r_pm_cmd = if (r_pm_sat > r_max) then r_max elseif (r_pm_sat < -r_max) then -r_max else r_pm_sat;

  // ===== Bounded actuator dynamics (first-order lag, bounded state) =====
  der(deltaV) = (deltaV_cmd - deltaV) / tau_b;
  der(r_pm)   = (r_pm_cmd - r_pm) / tau_r;

  // ===== Plant: translational dynamics with gravity, buoyancy, quadratic drag =====
  der(x) = vx;
  m_tot * der(vx) = F_dist - kx * vx * abs(vx);

  der(z) = vz;
  // Net vertical force: -rho*g*deltaV (upward for positive deltaV) minus quadratic drag
  m_tot * der(vz) = -rho_sw * g * deltaV - kz * vz * abs(vz);

  // ===== Pitch dynamics: pitch-mass gravity moment, damping, disturbance =====
  der(theta) = q_pitch;
  I_pitch * der(q_pitch) = m_pm * g * r_pm * cos(theta) - Dq_pitch * q_pitch + M_dist;

  // ===== Roll and yaw: passively damped, unactuated, initially zero =====
  der(phi) = p_roll;
  der(p_roll) = -2.0 * p_roll;
  der(psi) = r_yaw;
  der(r_yaw) = -2.0 * r_yaw;

  // ===== Sensors: pressure depth, Doppler velocity, IMU attitudes and rates =====
  z_meas     = z;
  vx_meas    = vx;
  vz_meas    = vz;
  theta_meas = theta;
  phi_meas   = phi;
  psi_meas   = psi;
  q_meas     = q_pitch;
  p_meas     = p_roll;
  r_meas     = r_yaw;

  // ===== Auxiliary: zero-safe speed norm and tracking error =====
  V_tot          = sqrt(vx*vx + vz*vz + 1.0e-12);
  tracking_error = z - z_cmd;

  annotation(
    experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6),
    Documentation(info = "GliderDiveD: 200 Hz (0.005 s step) 14 s mission. "
      "Buoyancy authority = rho*g*0.001 = 10.05 N limits depth settling; "
      "tracking bound after 9.1 s is a design target dependent on these stated limits."));
end GliderDiveD;