model MarinePairFormE
  parameter Real m_auv = 80.0;
  parameter Real v_lead = 1.0;
  parameter Real dx_offset = 2.0;
  parameter Real dz_offset = 0.0;
  parameter Real min_sep = 1.0; // Assumed minimum separation, not specified in request
  parameter Real F_thr_max = 116.0;
  parameter Real delay_time = 0.096;
  parameter Real Kp = 20.0;
  parameter Real Kd = 30.0;
  parameter Real obs1_x = -5.0;
  parameter Real obs1_z = 3.0;
  parameter Real obs2_x = 10.0;
  parameter Real obs2_z = -3.0;
  parameter Real obs_radius = 0.5;

  Real x1, z1, vx1, vz1;
  Real x2, z2, vx2, vz2;
  Real ax1, az1, ax2, az2;

  Real T1_surge1, T1_surge2, T1_heave1, T1_heave2;
  Real T2_surge1, T2_surge2, T2_heave1, T2_heave2;
  Real Ta1_surge1, Ta1_surge2, Ta1_heave1, Ta1_heave2;
  Real Ta2_surge1, Ta2_surge2, Ta2_heave1, Ta2_heave2;

  Real F1x, F1z, F2x, F2z;
  Real F_dist;

  Real x1_delayed, z1_delayed, x2_delayed, z2_delayed;
  Real range;

  Real imu1_ax, imu1_az, imu1_vx, imu1_vz;
  Real pressure1_z;
  Real dvl1_vx, dvl1_vz;

  Real imu2_ax, imu2_az, imu2_vx, imu2_vz;
  Real pressure2_z;
  Real dvl2_vx, dvl2_vz;

  Real est1_x, est1_z, est1_vx, est1_vz;
  Real est2_x, est2_z, est2_vx, est2_vz;

  Real track_err, form_err, sep_err;
  Real d_obs1_1, d_obs2_1, d_obs1_2, d_obs2_2;

equation
  F_dist = if time > 16.0/3.0 and time < 32.0/3.0 then 50.0 else 0.0;

  der(x1) = vx1;
  der(z1) = vz1;
  der(vx1) = ax1;
  der(vz1) = az1;

  der(x2) = vx2;
  der(z2) = vz2;
  der(vx2) = ax2;
  der(vz2) = az2;

  ax1 = (F1x + F_dist) / m_auv;
  az1 = (F1z) / m_auv;
  ax2 = (F2x - F_dist) / m_auv;
  az2 = (F2z) / m_auv;

  T1_surge1 = (Kp*(v_lead*time - est1_x) - Kd*est1_vx) / 2;
  T1_surge2 = (Kp*(v_lead*time - est1_x) - Kd*est1_vx) / 2;
  T1_heave1 = (Kp*(0.0 - est1_z) - Kd*est1_vz) / 2;
  T1_heave2 = (Kp*(0.0 - est1_z) - Kd*est1_vz) / 2;

  T2_surge1 = (Kp*(x1_delayed - dx_offset - est2_x) - Kd*est2_vx) / 2;
  T2_surge2 = (Kp*(x1_delayed - dx_offset - est2_x) - Kd*est2_vx) / 2;
  T2_heave1 = (Kp*(z1_delayed - dz_offset - est2_z) - Kd*est2_vz) / 2;
  T2_heave2 = (Kp*(z1_delayed - dz_offset - est2_z) - Kd*est2_vz) / 2;

  Ta1_surge1 = max(-F_thr_max, min(F_thr_max, T1_surge1));
  Ta1_surge2 = max(-F_thr_max, min(F_thr_max, T1_surge2));
  Ta1_heave1 = max(-F_thr_max, min(F_thr_max, T1_heave1));
  Ta1_heave2 = max(-F_thr_max, min(F_thr_max, T1_heave2));

  Ta2_surge1 = max(-F_thr_max, min(F_thr_max, T2_surge1));
  Ta2_surge2 = max(-F_thr_max, min(F_thr_max, T2_surge2));
  Ta2_heave1 = max(-F_thr_max, min(F_thr_max, T2_heave1));
  Ta2_heave2 = max(-F_thr_max, min(F_thr_max, T2_heave2));

  F1x = Ta1_surge1 + Ta1_surge2;
  F1z = Ta1_heave1 + Ta1_heave2;
  F2x = Ta2_surge1 + Ta2_surge2;
  F2z = Ta2_heave1 + Ta2_heave2;

  x1_delayed = delay(x1, delay_time);
  z1_delayed = delay(z1, delay_time);
  x2_delayed = delay(x2, delay_time);
  z2_delayed = delay(z2, delay_time);

  range = sqrt((x1 - x2)^2 + (z1 - z2)^2 + 0.001);

  imu1_ax = ax1;
  imu1_az = az1;
  imu1_vx = vx1;
  imu1_vz = vz1;
  pressure1_z = z1;
  dvl1_vx = vx1;
  dvl1_vz = vz1;

  imu2_ax = ax2;
  imu2_az = az2;
  imu2_vx = vx2;
  imu2_vz = vz2;
  pressure2_z = z2;
  dvl2_vx = vx2;
  dvl2_vz = vz2;

  est1_x = x1;
  est1_z = pressure1_z;
  est1_vx = dvl1_vx;
  est1_vz = dvl1_vz;

  est2_x = x2;
  est2_z = pressure2_z;
  est2_vx = dvl2_vx;
  est2_vz = dvl2_vz;

  track_err = sqrt((x1 - v_lead*time)^2 + (z1 - 0.0)^2 + 0.001);
  form_err = sqrt((x2 - (x1 - dx_offset))^2 + (z2 - (z1 - dz_offset))^2 + 0.001);
  sep_err = range;

  d_obs1_1 = sqrt((x1 - obs1_x)^2 + (z1 - obs1_z)^2);
  d_obs2_1 = sqrt((x1 - obs2_x)^2 + (z1 - obs2_z)^2);
  d_obs1_2 = sqrt((x2 - obs1_x)^2 + (z2 - obs1_z)^2);
  d_obs2_2 = sqrt((x2 - obs2_x)^2 + (z2 - obs2_z)^2);

  assert(abs(Ta1_surge1) <= F_thr_max + 0.001, "AUV1 Surge1 limit violated");
  assert(abs(Ta1_surge2) <= F_thr_max + 0.001, "AUV1 Surge2 limit violated");
  assert(abs(Ta1_heave1) <= F_thr_max + 0.001, "AUV1 Heave1 limit violated");
  assert(abs(Ta1_heave2) <= F_thr_max + 0.001, "AUV1 Heave2 limit violated");
  assert(abs(Ta2_surge1) <= F_thr_max + 0.001, "AUV2 Surge1 limit violated");
  assert(abs(Ta2_surge2) <= F_thr_max + 0.001, "AUV2 Surge2 limit violated");
  assert(abs(Ta2_heave1) <= F_thr_max + 0.001, "AUV2 Heave1 limit violated");
  assert(abs(Ta2_heave2) <= F_thr_max + 0.001, "AUV2 Heave2 limit violated");

  assert(sep_err >= min_sep, "Minimum separation violated");
  assert(time < 10.4 or form_err < 0.27, "Formation error failed after 10.4s");
  assert(delay_time <= 0.096, "Communication age limit violated");
  assert(d_obs1_1 > obs_radius, "Collision with obs1 by AUV1");
  assert(d_obs2_1 > obs_radius, "Collision with obs2 by AUV1");
  assert(d_obs1_2 > obs_radius, "Collision with obs1 by AUV2");
  assert(d_obs2_2 > obs_radius, "Collision with obs2 by AUV2");
  assert(time < 10.4 or track_err < 0.27, "Primary tracking error failed after 10.4s");

  assert(abs(x1) < 1e6 and abs(x2) < 1e6 and abs(z1) < 1e6 and abs(z2) < 1e6, "NaN/Inf check failed");

initial equation
  x1 = 0.0; z1 = 0.0; vx1 = 0.0; vz1 = 0.0;
  x2 = -2.0; z2 = 0.0; vx2 = 0.0; vz2 = 0.0;

annotation(
  experiment(StopTime=16.0, Interval=0.004),
  __OpenModelica_simulationFlags(dt=0.004)
);
end MarinePairFormE;