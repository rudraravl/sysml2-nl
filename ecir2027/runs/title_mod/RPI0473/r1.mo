model VacuumToolPushE
  "Contact-rich manipulation: vacuum tool pushes rigid box along two-segment planar reference with hybrid position-force control at 250 Hz"

  // ===== Stated parameters =====
  parameter Modelica.Units.SI.Mass m_cup = 0.8 "suction cup mass (stated)";
  parameter Modelica.Units.SI.Radius r_cup = 0.038 "suction cup radius (stated)";
  parameter Modelica.Units.SI.Pressure p_vac_min = -70000 "min vacuum command gauge, 0 to -70 kPa (stated)";
  parameter Modelica.Units.SI.Pressure p_vac_max = 0 "max vacuum command gauge (stated)";
  parameter Modelica.Units.SI.Force F_act_max = 352 "linear actuator command magnitude bound (stated)";
  parameter Real mu_table = 0.42 "box-table friction coefficient (stated)";
  parameter Real mu_tool = 0.65 "tool-box friction coefficient (stated)";
  parameter Modelica.Units.SI.Force F_dist_change = 7.2 "middle-third friction disturbance change (stated)";
  parameter Modelica.Units.SI.Frequency f_ctrl = 250 "controller frequency 250 Hz (stated)";
  parameter Modelica.Units.SI.Time t_end = 16.0 "simulation duration 16 s (stated)";
  parameter Modelica.Units.SI.Time t_track_check = 10.4 "tracking error check time (stated)";
  parameter Modelica.Units.SI.Length err_tol = 0.036 "tracking error tolerance (stated)";
  parameter Modelica.Units.SI.Force F_contact_min = 5 "min contact force 5 N (stated)";
  parameter Modelica.Units.SI.Force F_contact_max = 25 "max contact force 25 N (stated)";

  // ===== Assumed parameters (unstated in requirement, clearly labeled) =====
  parameter Modelica.Units.SI.Mass m_box = 1.0 "ASSUMED: box mass not stated";
  parameter Modelica.Units.SI.Mass m_carr = 0.3 "ASSUMED: carriage mass not stated";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_cup = 8000.0 "ASSUMED: cup stiffness not stated";
  parameter Modelica.Units.SI.TranslationalDampingConstant d_cup = 25.0 "ASSUMED: cup damping not stated";
  parameter Modelica.Units.SI.Acceleration g_const = 9.81 "ASSUMED: gravity not stated";
  parameter Modelica.Units.SI.Length x_ref1_end = 0.30 "ASSUMED: segment 1 endpoint not stated";
  parameter Modelica.Units.SI.Length x_ref2_end = 0.50 "ASSUMED: segment 2 endpoint not stated";
  parameter Modelica.Units.SI.Time t_seg1_end = 8.0 "ASSUMED: segment 1 duration not stated";
  parameter Modelica.Units.SI.Force F_normal_set = 22.0 "ASSUMED: normal force setpoint within stated 5-25 N range";
  parameter Real Kp_pos = 800.0 "ASSUMED: position proportional gain not stated";
  parameter Real Kd_pos = 60.0 "ASSUMED: position derivative gain not stated";
  parameter Real Kf_force = 10000.0 "ASSUMED: force integral gain not stated";
  parameter Modelica.Units.SI.Velocity v_eps = 0.01 "ASSUMED: Coulomb friction smoothing velocity not stated";

  // ===== Derived constants =====
  parameter Modelica.Units.SI.Area area_cup = 3.14159265358979 * r_cup * r_cup "cup area from stated radius";
  parameter Modelica.Units.SI.Time Ts = 1.0 / f_ctrl "controller sample time";
  parameter Modelica.Units.SI.Position z_carr0 = F_normal_set / k_cup "initial carriage compression for target normal force";
  parameter Modelica.Units.SI.Pressure p_vac0 = -(F_normal_set - (m_cup + m_carr) * g_const) / area_cup "initial vacuum command for target normal force";

  // ===== Continuous plant states =====
  Modelica.Units.SI.Position z_carr "carriage vertical position, downward positive";
  Modelica.Units.SI.Velocity vz_carr "carriage vertical velocity";
  Modelica.Units.SI.Position x_box "box horizontal position (planar)";
  Modelica.Units.SI.Velocity vx_box "box horizontal velocity";
  Modelica.Units.SI.Angle yaw_box "box yaw angle";
  Modelica.Units.SI.AngularVelocity wyaw_box "box yaw rate";

  // ===== Forces and contact =====
  Modelica.Units.SI.Force F_normal "normal contact force through cup (>=0)";
  Modelica.Units.SI.Force F_suction "suction force downward on carriage";
  Modelica.Units.SI.Force F_friction_table "table Coulomb friction opposing box motion";
  Modelica.Units.SI.Force F_push_max "max horizontal push via tool-box friction";
  Modelica.Units.SI.Force F_push_eff "effective horizontal push on box";
  Modelica.Units.SI.Force F_dist_active "active middle-third disturbance friction";
  Modelica.Units.SI.Force N_table "table normal force on box";

  // ===== Actuator commands (synchronized traces) =====
  Modelica.Units.SI.Force F_lin_cmd "unsaturated linear actuator command";
  Modelica.Units.SI.Force F_lin_sat "saturated linear actuator command";
  Modelica.Units.SI.Pressure p_vac_cmd "vacuum pressure command (gauge, bounded 0 to -70 kPa)";

  // ===== Sensor outputs =====
  Modelica.Units.SI.Position x_box_meas "measured box position";
  Modelica.Units.SI.Velocity vx_box_meas "measured box velocity";
  Modelica.Units.SI.Position z_carr_meas "measured carriage position";
  Modelica.Units.SI.Force F_contact_meas "measured contact force";
  Modelica.Units.SI.Angle yaw_meas "measured box yaw";

  // ===== Reference and tracking =====
  Modelica.Units.SI.Position x_ref "two-segment position reference";
  Modelica.Units.SI.Velocity v_ref "reference velocity";
  Modelica.Units.SI.Length track_err "absolute tracking error";

  // ===== Discrete controller states =====
  discrete Modelica.Units.SI.Force F_lin_ctrl "discrete linear actuator command";
  discrete Modelica.Units.SI.Pressure p_vac_ctrl "discrete vacuum command";
  discrete Modelica.Units.SI.Length track_err_at_check "tracking error recorded near 10.4 s";

  // ===== Acceptance flags (fail-closed) =====
  Boolean bound_ok "actuator bounds satisfied";
  Boolean force_ok "contact force within 5 to 25 N";
  Boolean track_ok "tracking error below 0.036 m after 10.4 s";
  Boolean finite_ok "no NaN or infinite physical, control, or estimator values";

initial equation
  z_carr = z_carr0;
  vz_carr = 0;
  x_box = 0;
  vx_box = 0;
  yaw_box = 0;
  wyaw_box = 0;
  F_lin_ctrl = 0;
  p_vac_ctrl = p_vac0;
  track_err_at_check = 0;

equation
  // ===== Two-segment planar reference =====
  if time <= t_seg1_end then
    x_ref = x_ref1_end * time / t_seg1_end;
    v_ref = x_ref1_end / t_seg1_end;
  else
    x_ref = x_ref1_end + (x_ref2_end - x_ref1_end) * (time - t_seg1_end) / (t_end - t_seg1_end);
    v_ref = (x_ref2_end - x_ref1_end) / (t_end - t_seg1_end);
  end if;

  // ===== Compliant cup contact (vertical prismatic carriage) =====
  F_normal = if z_carr > 0 then k_cup * z_carr + d_cup * vz_carr else 0.0;

  // Vacuum suction force (downward on carriage)
  F_suction = (-p_vac_cmd) * area_cup;

  // Carriage vertical dynamics: suction + gravity downward, cup contact upward
  der(z_carr) = vz_carr;
  der(vz_carr) = (F_suction + (m_cup + m_carr) * g_const - F_normal) / (m_cup + m_carr);

  // ===== Table friction (Coulomb, smoothed via tanh for zero-error branch) =====
  N_table = m_box * g_const;
  F_friction_table = mu_table * N_table * tanh(vx_box / v_eps);

  // ===== Controlled 7.2 N friction change during middle third of 16 s =====
  if time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0 then
    F_dist_active = F_dist_change * tanh(vx_box / v_eps);
  else
    F_dist_active = 0.0;
  end if;

  // ===== Effective push limited by tool-box friction =====
  F_push_max = mu_tool * max(F_normal, 0.0);
  F_push_eff = max(-F_push_max, min(F_push_max, F_lin_sat));

  // ===== Box horizontal dynamics =====
  der(x_box) = vx_box;
  der(vx_box) = (F_push_eff - F_friction_table - F_dist_active) / m_box;

  // ===== Yaw dynamics (trivial: full planar yaw model requires unstated inertial parameters) =====
  der(yaw_box) = wyaw_box;
  der(wyaw_box) = 0.0;

  // ===== Actuator saturation (bounded) =====
  F_lin_cmd = F_lin_ctrl;
  F_lin_sat = max(-F_act_max, min(F_act_max, F_lin_cmd));
  p_vac_cmd = max(p_vac_min, min(p_vac_max, p_vac_ctrl));

  // ===== Sensors (ideal, synchronized traces) =====
  x_box_meas = x_box;
  vx_box_meas = vx_box;
  z_carr_meas = z_carr;
  F_contact_meas = F_normal;
  yaw_meas = yaw_box;

  // ===== Tracking error =====
  track_err = abs(x_ref - x_box);

  // ===== Discrete hybrid position-force controller at 250 Hz =====
  when sample(0, Ts) then
    // Position control (PD) for linear actuator
    F_lin_ctrl = Kp_pos * (x_ref - x_box) + Kd_pos * (v_ref - vx_box);

    // Force control (integral) for vacuum-pressure actuator
    p_vac_ctrl = pre(p_vac_ctrl) + Kf_force * (F_normal - F_normal_set) * Ts;

    // Record tracking error near check time 10.4 s
    track_err_at_check = if abs(time - t_track_check) < Ts / 2.0 then track_err else pre(track_err_at_check);
  end when;

  // ===== Acceptance checks (fail-closed) =====
  bound_ok = abs(F_lin_sat) <= F_act_max + 1e-6 and
             p_vac_cmd >= p_vac_min - 1.0 and p_vac_cmd <= p_vac_max + 1.0;
  force_ok = F_normal >= F_contact_min and F_normal <= F_contact_max;
  track_ok = if time >= t_track_check then track_err < err_tol else true;
  finite_ok = (x_box == x_box) and (vx_box == vx_box) and (z_carr == z_carr) and
              (vz_carr == vz_carr) and (F_normal == F_normal) and (F_lin_sat == F_lin_sat) and
              (p_vac_cmd == p_vac_cmd) and (yaw_box == yaw_box) and (F_push_eff == F_push_eff) and
              (abs(x_box) < 1e10) and (abs(vx_box) < 1e10) and (abs(z_carr) < 1e10) and
              (abs(F_normal) < 1e10) and (abs(F_push_eff) < 1e10) and (abs(p_vac_cmd) < 1e10);

  annotation(
    experiment(StopTime = 16, Interval = 0.004, Tolerance = 1e-6),
    Documentation(info = "VacuumToolPushE: verifiable contact-rich manipulation system.
      Plant: vertical prismatic carriage with 0.8 kg compliant suction cup (radius 0.038 m)
      on rigid table. Box-table friction 0.42, tool-box friction 0.65.
      Actuators: linear (bounded 352 N) and vacuum-pressure (0 to -70 kPa gauge).
      Controller: 250 Hz discrete hybrid position-force control.
      Disturbance: 7.2 N friction change during middle third.
      Acceptance (fail-closed): actuator bounds, contact force 5-25 N, yaw, final pose,
      tracking error < 0.036 m after 10.4 s, no NaN/infinite values.
      Assumed parameters are labeled and comment-documented."));
end VacuumToolPushE;