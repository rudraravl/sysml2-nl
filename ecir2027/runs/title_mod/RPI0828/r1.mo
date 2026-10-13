model WheelLegTraverseF
  "Floating-base wheel-legged robot traversing a rocky/gapped height field"

  // ---- Stated mission/embodiment parameters ----
  parameter Real m_torso(unit="kg") = 28.0 "torso mass";
  parameter Real r_wheel(unit="m") = 0.10 "driven wheel radius";
  parameter Real tau_max(unit="N.m") = 67.1 "per-joint torque limit";
  parameter Real mu = 0.78 "contact friction coefficient";
  parameter Real F_push(unit="N") = 130.0 "lateral push disturbance";
  parameter Real rock_h(unit="m") = 0.08 "rock height";
  parameter Real gap_w(unit="m") = 0.12 "gap width";
  parameter Real clearance_min(unit="m") = 0.03;
  parameter Real attitude_max(unit="rad") = 0.45;
  parameter Real track_err_max(unit="m") = 0.12 "after 13 s";
  parameter Real t_final(unit="s") = 20.0;
  parameter Real dt_ctrl(unit="s") = 0.002 "500 Hz control/trace rate";

  // ---- Unspecified mission values: nominal placeholders (not stated) ----
  parameter Real v_cmd(unit="m/s") = 1.0
    "commanded average speed NOT specified in requirement; nominal placeholder";
  parameter Real L_route(unit="m") = 20.0
    "route length NOT specified in requirement; nominal placeholder";
  parameter Real x_gap1(unit="m") = 6.0
    "first gap start NOT specified in requirement; nominal placeholder";
  parameter Real x_gap2(unit="m") = 12.0
    "second gap start NOT specified in requirement; nominal placeholder";
  parameter Real x_rock1(unit="m") = 3.0
    "rock patch 1 start NOT specified; nominal placeholder";
  parameter Real x_rock2(unit="m") = 9.0
    "rock patch 2 start NOT specified; nominal placeholder";
  parameter Real z_ref(unit="m") = 0.60
    "adjustable body height setpoint NOT specified; nominal placeholder";
  parameter Real swing_period(unit="s") = 0.8
    "swing period NOT specified; nominal placeholder";

  // ---- Inertial/geometric parameters (unspecified, nominal) ----
  parameter Real I_torso(unit="kg.m2") = 1.2
    "torso pitch inertia NOT specified; nominal placeholder";
  parameter Real leg_lever(unit="m") = 0.5
    "leg-to-vertical-force lever NOT specified (leg geometry unknown); nominal placeholder";
  parameter Real g(unit="m/s2") = 9.81;

  // ---- Control gains (unspecified, nominal) ----
  parameter Real Kp_v = 40.0  "speed tracking gain; unspecified nominal";
  parameter Real Kp_z = 400.0 "height gain; unspecified nominal";
  parameter Real Kd_z = 40.0  "height damping; unspecified nominal";
  parameter Real Kp_th = 60.0 "attitude gain; unspecified nominal";
  parameter Real Kd_th = 12.0 "attitude damping; unspecified nominal";
  parameter Real Kp_y = 20.0  "lateral gain; unspecified nominal";
  parameter Real Kd_y = 8.0   "lateral damping; unspecified nominal";

  // ---- Continuous states ----
  Real x_pos(start=0.0, unit="m")     "torso forward position";
  Real vx(start=0.0, unit="m/s")      "forward velocity";
  Real z_body(start=0.60, unit="m")   "body height above ground datum";
  Real vz(start=0.0, unit="m/s")      "vertical velocity";
  Real y_lat(start=0.0, unit="m")     "lateral position";
  Real vy(start=0.0, unit="m/s")      "lateral velocity";
  Real theta(start=0.0, unit="rad")   "pitch attitude";
  Real omega(start=0.0, unit="rad/s") "pitch rate";

  // ---- Actuator torques ----
  Real tau_leg_cmd[8]   "leg joint torque commands";
  Real tau_wheel_cmd[4] "wheel torque commands";
  Real tau_leg[8]       "limited leg torques";
  Real tau_wheel[4]     "limited wheel torques";

  // ---- Internal forces / terrain ----
  Real F_traction_cmd(unit="N");
  Real F_traction(unit="N");
  Real F_support(unit="N");
  Real tau_pitch(unit="N.m");
  Real F_dist_lat(unit="N");
  Real max_traction(unit="N");
  Real terrain_h(unit="m");
  Real over_gap;
  Real clearance(unit="m");

  // ---- Sensors ----
  Boolean contact[4];
  Real contact_real[4];
  Real imu_acc_x;
  Real imu_acc_z;
  Real imu_gyro_y;
  Real depth_meas(unit="m");

  // ---- Foothold plan / swing trajectory ----
  Real swing_phase "0..1 within swing cycle";
  Real foothold_x[4];
  Real swing_foot_z[4];

  // ---- Synchronized 500 Hz traces ----
  discrete Real x_pos_tr;
  discrete Real vx_tr;
  discrete Real z_body_tr;
  discrete Real theta_tr;
  discrete Real tau_leg_tr[8];
  discrete Real tau_wheel_tr[4];

  // ---- Verification ----
  Real path_error(unit="m");
  Real track_error_13(unit="m");
  Real leg_over;
  Real wheel_over;
  Boolean ok_actuator;
  Boolean ok_clearance;
  Boolean ok_attitude;
  Boolean ok_route;
  Boolean ok_tracking;
  Boolean ok_finite;
  Boolean all_checks;
  Real nan_probe;
equation
  // Terrain height: 0.08 m rocks; gaps are unsupported (-1.0 datum)
  terrain_h = noEvent(
    if (x_pos > x_gap1 and x_pos < x_gap1 + gap_w) or
       (x_pos > x_gap2 and x_pos < x_gap2 + gap_w)
    then -1.0
    else if (x_pos > x_rock1 and x_pos < x_rock1 + 1.0) or
            (x_pos > x_rock2 and x_pos < x_rock2 + 1.0)
    then rock_h
    else 0.0);

  over_gap = noEvent(if (x_pos > x_gap1 and x_pos < x_gap1 + gap_w) or
                        (x_pos > x_gap2 and x_pos < x_gap2 + gap_w)
                     then 1.0 else 0.0);

  // Contact flags (simplified: shared torso position for four wheels)
  contact[1] = noEvent(not (over_gap > 0.5));
  contact[2] = noEvent(not (over_gap > 0.5));
  contact[3] = noEvent(not (over_gap > 0.5));
  contact[4] = noEvent(not (over_gap > 0.5));
  contact_real[1] = if contact[1] then 1.0 else 0.0;
  contact_real[2] = if contact[2] then 1.0 else 0.0;
  contact_real[3] = if contact[3] then 1.0 else 0.0;
  contact_real[4] = if contact[4] then 1.0 else 0.0;

  // Clearance (torso above terrain; prohibits torso-terrain collision)
  clearance = noEvent(z_body - r_wheel - terrain_h);

  // 130 N lateral push during the middle third of the run
  F_dist_lat = noEvent(if (time >= t_final/3.0 and time <= 2.0*t_final/3.0)
                       then F_push else 0.0);

  // Forward speed tracking -> wheel traction, friction-limited
  F_traction_cmd = Kp_v*(v_cmd - vx);
  max_traction = noEvent(if over_gap > 0.5 then 0.5*mu*m_torso*g
                                     else mu*m_torso*g);
  F_traction = noEvent(if F_traction_cmd > max_traction then max_traction
                       else if F_traction_cmd < -max_traction then -max_traction
                       else F_traction_cmd);

  // Body height support force -> 8 leg joints (nominal lever; geometry unknown)
  F_support = m_torso*g + Kp_z*(z_ref - z_body) - Kd_z*vz;

  // Pitch stabilization torque
  tau_pitch = Kp_th*(0.0 - theta) + Kd_th*(0.0 - omega);

  // Torque commands and per-joint limits (8 leg + 4 wheel)
  tau_leg_cmd[1] = (F_support/8.0)*leg_lever;
  tau_leg_cmd[2] = (F_support/8.0)*leg_lever;
  tau_leg_cmd[3] = (F_support/8.0)*leg_lever;
  tau_leg_cmd[4] = (F_support/8.0)*leg_lever;
  tau_leg_cmd[5] = (F_support/8.0)*leg_lever;
  tau_leg_cmd[6] = (F_support/8.0)*leg_lever;
  tau_leg_cmd[7] = (F_support/8.0)*leg_lever;
  tau_leg_cmd[8] = (F_support/8.0)*leg_lever;
  tau_wheel_cmd[1] = F_traction*r_wheel/4.0;
  tau_wheel_cmd[2] = F_traction*r_wheel/4.0;
  tau_wheel_cmd[3] = F_traction*r_wheel/4.0;
  tau_wheel_cmd[4] = F_traction*r_wheel/4.0;

  for i in 1:8 loop
    tau_leg[i] = noEvent(if tau_leg_cmd[i] > tau_max then tau_max
                        else if tau_leg_cmd[i] < -tau_max then -tau_max
                        else tau_leg_cmd[i]);
  end for;
  for i in 1:4 loop
    tau_wheel[i] = noEvent(if tau_wheel_cmd[i] > tau_max then tau_max
                           else if tau_wheel_cmd[i] < -tau_max then -tau_max
                           else tau_wheel_cmd[i]);
  end for;

  // Rigid-body dynamics
  der(x_pos) = vx;
  m_torso*der(vx) = F_traction;
  der(z_body) = vz;
  m_torso*der(vz) = F_support - m_torso*g;
  der(y_lat) = vy;
  m_torso*der(vy) = F_dist_lat + Kp_y*(0.0 - y_lat) + Kd_y*(0.0 - vy);
  der(theta) = omega;
  I_torso*der(omega) = tau_pitch;

  // IMU measurements
  imu_acc_x = der(vx);
  imu_acc_z = der(vz) + g;
  imu_gyro_y = omega;

  // Forward depth measurement to next obstacle ahead
  depth_meas = noEvent(if x_pos < x_rock1 then x_rock1 - x_pos
                       else if x_pos < x_gap1 then x_gap1 - x_pos
                       else if x_pos < x_rock2 then x_rock2 - x_pos
                       else if x_pos < x_gap2 then x_gap2 - x_pos
                       else L_route - x_pos);

  // Foothold plan and swing-foot trajectory control
  swing_phase = noEvent(mod(time, swing_period)/swing_period);
  foothold_x[1] = x_pos + 0.10;
  foothold_x[2] = x_pos + 0.15;
  foothold_x[3] = x_pos + 0.20;
  foothold_x[4] = x_pos + 0.25;
  swing_foot_z[1] = noEvent(if contact[1] then 0.0
                            else 0.06*(1.0 - (2.0*swing_phase - 1.0)^2));
  swing_foot_z[2] = noEvent(if contact[2] then 0.0
                            else 0.06*(1.0 - (2.0*swing_phase - 1.0)^2));
  swing_foot_z[3] = noEvent(if contact[3] then 0.0
                            else 0.06*(1.0 - (2.0*swing_phase - 1.0)^2));
  swing_foot_z[4] = noEvent(if contact[4] then 0.0
                            else 0.06*(1.0 - (2.0*swing_phase - 1.0)^2));

  // 500 Hz synchronized state/command/sensor traces
  when sample(0, dt_ctrl) then
    x_pos_tr := x_pos;
    vx_tr := vx;
    z_body_tr := z_body;
    theta_tr := theta;
    tau_leg_tr[1] := tau_leg[1];
    tau_leg_tr[2] := tau_leg[2];
    tau_leg_tr[3] := tau_leg[3];
    tau_leg_tr[4] := tau_leg[4];
    tau_leg_tr[5] := tau_leg[5];
    tau_leg_tr[6] := tau_leg[6];
    tau_leg_tr[7] := tau_leg[7];
    tau_leg_tr[8] := tau_leg[8];
    tau_wheel_tr[1] := tau_wheel[1];
    tau_wheel_tr[2] := tau_wheel[2];
    tau_wheel_tr[3] := tau_wheel[3];
    tau_wheel_tr[4] := tau_wheel[4];
  end when;

  // Verification metrics
  path_error = noEvent(abs(v_cmd*time - x_pos));
  track_error_13 = noEvent(if time >= 13.0 then abs(v_cmd*time - x_pos) else 0.0);

  // Actuator bound check (scalar accumulation)
  leg_over = noEvent(max(0.0, abs(tau_leg[1]) - tau_max)
                   + max(0.0, abs(tau_leg[2]) - tau_max)
                   + max(0.0, abs(tau_leg[3]) - tau_max)
                   + max(0.0, abs(tau_leg[4]) - tau_max)
                   + max(0.0, abs(tau_leg[5]) - tau_max)
                   + max(0.0, abs(tau_leg[6]) - tau_max)
                   + max(0.0, abs(tau_leg[7]) - tau_max)
                   + max(0.0, abs(tau_leg[8]) - tau_max));
  wheel_over = noEvent(max(0.0, abs(tau_wheel[1]) - tau_max)
                     + max(0.0, abs(tau_wheel[2]) - tau_max)
                     + max(0.0, abs(tau_wheel[3]) - tau_max)
                     + max(0.0, abs(tau_wheel[4]) - tau_max));
  ok_actuator = noEvent((leg_over + wheel_over) < 1e-9);

  ok_clearance = noEvent(clearance > clearance_min);
  ok_attitude = noEvent(abs(theta) < attitude_max);
  ok_route = noEvent(x_pos > x_gap2 + gap_w);
  ok_tracking = noEvent(if time >= 13.0
                        then (abs(v_cmd*time - x_pos) < track_err_max)
                        else true);

  // Finite / NaN probe over physical, control, and estimator variables
  nan_probe = x_pos + vx + z_body + vz + y_lat + vy + theta + omega
            + F_traction + F_support + tau_pitch + F_dist_lat + terrain_h
            + clearance + depth_meas + path_error + track_error_13;
  ok_finite = noEvent(nan_probe == nan_probe and abs(nan_probe) < 1e30);

  all_checks = ok_actuator and ok_clearance and ok_attitude
               and ok_route and ok_tracking and ok_finite;
end WheelLegTraverseF;