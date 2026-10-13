model CartesianToolPushE
  // ---------- Physical parameters ----------
  parameter Real m_t = 2.5 "tool carriage mass [kg]";
  parameter Real m_b = 2.0 "box mass [kg] (assumed; not specified by requirement)";
  parameter Real I_b = 0.002 "box yaw inertia [kg.m2] (assumed; not specified)";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real mu_bt = 0.42 "box-table friction coefficient";
  parameter Real mu_tb = 0.65 "tool-box friction coefficient";
  parameter Real F_max = 385.0 "actuator command bound per axis [N]";
  parameter Real a_b = 0.08 "box side length [m] (assumed)";
  parameter Real box_h = 0.06 "box height [m] (assumed)";
  parameter Real z_table = 0.0 "table surface height [m]";
  parameter Real c_yaw = 0.05 "box yaw viscous damping [N.m.s] (assumed)";

  // ---------- Contact model ----------
  parameter Real k_c = 3000.0 "normal contact stiffness [N/m] (assumed)";
  parameter Real d_c = 25.0 "normal contact damping [N.s/m] (assumed)";
  parameter Real delta_ref = 0.007 "commanded normal penetration [m] (assumed)";

  // ---------- Control ----------
  parameter Real Kp = 1200.0 "planar position proportional gain";
  parameter Real Kd = 60.0 "planar position derivative gain";
  parameter Real Kp_z = 800.0 "z position proportional gain";
  parameter Real Kd_z = 40.0 "z position derivative gain";

  // ---------- Reference trajectory ----------
  parameter Real seg1 = 0.09 "segment 1 planar length [m]";
  parameter Real v_ref = 0.01125 "reference speed [m/s]";
  parameter Real t_corner0 = 7.0 "corner blend start [s]";
  parameter Real t_corner1 = 9.0 "corner blend end [s]";
  parameter Real T_run = 16.0 "total run time [s]";

  // ---------- Disturbance ----------
  parameter Real F_dist = 7.2 "middle-third friction change [N]";

  // ---------- Smoothing ----------
  parameter Real eps_v = 0.02 "velocity smoothing [m/s]";
  parameter Real eps_c = 5.0e-4 "contact activation smoothing [m]";
  parameter Real eps_n = 1.0e-9 "normalization guard [m/s]";

  // ---------- Tool state ----------
  Real x_t(start = 0.0, fixed = true) "tool x position [m]";
  Real y_t(start = 0.0, fixed = true) "tool y position [m]";
  Real z_t(start = 0.03, fixed = true) "tool z position [m]";
  Real vx_t(start = 0.0, fixed = true) "tool x velocity [m/s]";
  Real vy_t(start = 0.0, fixed = true) "tool y velocity [m/s]";
  Real vz_t(start = 0.0, fixed = true) "tool z velocity [m/s]";

  // ---------- Box state (object planar pose) ----------
  Real x_b(start = 0.0, fixed = true) "box x position [m]";
  Real y_b(start = 0.0, fixed = true) "box y position [m]";
  Real vx_b(start = 0.0, fixed = true) "box x velocity [m/s]";
  Real vy_b(start = 0.0, fixed = true) "box y velocity [m/s]";
  Real theta_b(start = 0.0, fixed = true) "box yaw [rad]";
  Real wz_b(start = 0.0, fixed = true) "box yaw rate [rad/s]";

  // ---------- Reference and direction ----------
  Real u_blend "corner blend parameter";
  Real blend "smoothstep blend";
  Real corner_int "integral of blend";
  Real x_ref "reference x [m]";
  Real y_ref "reference y [m]";
  Real vx_ref "reference x velocity [m/s]";
  Real vy_ref "reference y velocity [m/s]";
  Real v_ref_mag "reference speed magnitude [m/s]";
  Real n_x "push direction x component";
  Real n_y "push direction y component";

  // ---------- Tool reference and commands ----------
  Real x_t_ref;
  Real y_t_ref;
  Real z_t_ref;
  Real Fx_cmd_raw;
  Real Fy_cmd_raw;
  Real Fz_cmd_raw;
  Real Fx_act;
  Real Fy_act;
  Real Fz_act;

  // ---------- Contact ----------
  Real s_t;
  Real s_back;
  Real delta;
  Real v_rel_n;
  Real alpha_c;
  Real F_n;
  Real v_lat;
  Real F_lat;
  Real tau_contact;

  // ---------- Friction / disturbance ----------
  Real v_b_mag;
  Real fr_mag;
  Real dist_mag;
  Real gate_dist;
  Real F_fr_x;
  Real F_fr_y;
  Real F_dist_x;
  Real F_dist_y;

  // ---------- Metrics ----------
  Real track_err "primary tracking error [m]";

  // ---------- Synchronized 250 Hz traces ----------
  Real x_b_s(start = 0.0);
  Real y_b_s(start = 0.0);
  Real theta_b_s(start = 0.0);
  Real x_t_s(start = 0.0);
  Real y_t_s(start = 0.0);
  Real z_t_s(start = 0.03);
  Real vx_b_s(start = 0.0);
  Real vy_b_s(start = 0.0);
  Real wz_b_s(start = 0.0);
  Real F_n_s(start = 0.0);
  Real Fx_act_s(start = 0.0);
  Real Fy_act_s(start = 0.0);
  Real Fz_act_s(start = 0.0);
  Real track_err_s(start = 0.0);
  Real t_s(start = 0.0);
  Real F_n_min(start = 100.0);
  Real F_n_max(start = 0.0);
  Boolean first_tick(start = true);

equation
  // ----- Smooth corner blend (two-segment planar reference) -----
  u_blend = (time - t_corner0) / (t_corner1 - t_corner0);
  blend = if time < t_corner0 then 0.0 elseif time > t_corner1 then 1.0 else 3.0 * u_blend * u_blend - 2.0 * u_blend * u_blend * u_blend;
  corner_int = if time < t_corner0 then 0.0 elseif time > t_corner1 then 1.0 + (time - t_corner1) else 2.0 * u_blend * u_blend * u_blend - u_blend * u_blend * u_blend * u_blend;

  x_ref = v_ref * (time - corner_int);
  y_ref = v_ref * corner_int;
  vx_ref = v_ref * (1.0 - blend);
  vy_ref = v_ref * blend;

  v_ref_mag = sqrt(vx_ref * vx_ref + vy_ref * vy_ref);
  n_x = vx_ref / (v_ref_mag + eps_n);
  n_y = vy_ref / (v_ref_mag + eps_n);

  // ----- Tool reference (approach box from -n side with commanded penetration) -----
  x_t_ref = x_ref + (delta_ref - a_b / 2) * n_x;
  y_t_ref = y_ref + (delta_ref - a_b / 2) * n_y;
  z_t_ref = z_table + box_h / 2;

  // ----- Hybrid position-force control: PD position + compliant normal force -----
  Fx_cmd_raw = Kp * (x_t_ref - x_t) + Kd * (vx_ref - vx_t);
  Fy_cmd_raw = Kp * (y_t_ref - y_t) + Kd * (vy_ref - vy_t);
  Fz_cmd_raw = Kp_z * (z_t_ref - z_t) + Kd_z * (0.0 - vz_t);

  // ----- Actuator saturation (per-axis magnitude bound) -----
  Fx_act = max(-F_max, min(F_max, Fx_cmd_raw));
  Fy_act = max(-F_max, min(F_max, Fy_cmd_raw));
  Fz_act = max(-F_max, min(F_max, Fz_cmd_raw));

  // ----- Contact kinematics along push direction -----
  s_t = x_t * n_x + y_t * n_y;
  s_back = x_b * n_x + y_b * n_y - a_b / 2;
  delta = s_t - s_back;
  v_rel_n = (vx_t - vx_b) * n_x + (vy_t - vy_b) * n_y;

  // ----- Compliant normal contact force -----
  alpha_c = 0.5 * (1.0 + Modelica.Math.tanh(delta / eps_c));
  F_n = max(0.0, alpha_c * (k_c * delta + d_c * v_rel_n));

  // ----- Tool-box tangential (lateral) friction -----
  v_lat = (vx_t - vx_b) * (-n_y) + (vy_t - vy_b) * n_x;
  F_lat = -mu_tb * F_n * Modelica.Math.tanh(v_lat / eps_v);

  // ----- Yaw torque from lateral friction applied at box back face -----
  tau_contact = -(a_b / 2) * F_lat;

  // ----- Box-table Coulomb friction (opposes box velocity) -----
  v_b_mag = sqrt(vx_b * vx_b + vy_b * vy_b);
  fr_mag = mu_bt * m_b * g * Modelica.Math.tanh(v_b_mag / eps_v);
  F_fr_x = -fr_mag * vx_b / (v_b_mag + eps_n);
  F_fr_y = -fr_mag * vy_b / (v_b_mag + eps_n);

  // ----- Middle-third friction disturbance -----
  gate_dist = 0.5 * (Modelica.Math.tanh((time - T_run / 3.0) / 0.2) - Modelica.Math.tanh((time - 2.0 * T_run / 3.0) / 0.2));
  dist_mag = F_dist * Modelica.Math.tanh(v_b_mag / eps_v) * gate_dist;
  F_dist_x = -dist_mag * vx_b / (v_b_mag + eps_n);
  F_dist_y = -dist_mag * vy_b / (v_b_mag + eps_n);

  // ----- Tool dynamics -----
  der(x_t) = vx_t;
  der(y_t) = vy_t;
  der(z_t) = vz_t;
  m_t * der(vx_t) = Fx_act - F_n * n_x + F_lat * n_y;
  m_t * der(vy_t) = Fy_act - F_n * n_y - F_lat * n_x;
  m_t * der(vz_t) = Fz_act;

  // ----- Box dynamics -----
  der(x_b) = vx_b;
  der(y_b) = vy_b;
  m_b * der(vx_b) = F_n * n_x + F_lat * (-n_y) + F_fr_x + F_dist_x;
  m_b * der(vy_b) = F_n * n_y + F_lat * n_x + F_fr_y + F_dist_y;

  // ----- Yaw dynamics -----
  der(theta_b) = wz_b;
  I_b * der(wz_b) = tau_contact - c_yaw * wz_b;

  // ----- Primary tracking error -----
  track_err = sqrt((x_b - x_ref) * (x_b - x_ref) + (y_b - y_ref) * (y_b - y_ref));

  // ----- Continuous fail-closed acceptance assertions -----
  assert(F_n >= 5.0 and F_n <= 25.0, "Contact force outside 5..25 N band (fail-closed)");
  assert(abs(Fx_act) <= F_max + 1.0e-6 and abs(Fy_act) <= F_max + 1.0e-6 and abs(Fz_act) <= F_max + 1.0e-6, "Actuator bound violated (fail-closed)");
  assert(abs(x_t) <= 0.10 + 1.0e-4 and abs(y_t) <= 0.10 + 1.0e-4 and abs(z_t) <= 0.30 + 1.0e-4, "Tool travel outside declared prismatic range (fail-closed)");
  assert(time <= 10.4 or track_err < 0.036, "Primary tracking error above 0.036 m after 10.4 s (fail-closed)");

  // ----- Synchronized 250 Hz state/command/sensor traces (equation-based when) -----
  when sample(0, 0.004) then
    t_s = time;
    x_b_s = x_b;
    y_b_s = y_b;
    theta_b_s = theta_b;
    vx_b_s = vx_b;
    vy_b_s = vy_b;
    wz_b_s = wz_b;
    x_t_s = x_t;
    y_t_s = y_t;
    z_t_s = z_t;
    F_n_s = F_n;
    Fx_act_s = Fx_act;
    Fy_act_s = Fy_act;
    Fz_act_s = Fz_act;
    track_err_s = track_err;
    if first_tick then
      F_n_min = F_n;
      F_n_max = F_n;
      first_tick = false;
    else
      F_n_min = min(pre(F_n_min), F_n);
      F_n_max = max(pre(F_n_max), F_n);
    end if;
  end when;

  // ----- Final-pose acceptance (fail-closed) -----
  when terminal() then
    assert(abs(x_b - seg1) < 0.05, "Final box x pose out of tolerance (fail-closed)");
    assert(abs(y_b - seg1) < 0.05, "Final box y pose out of tolerance (fail-closed)");
    assert(abs(theta_b) < 1.0, "Final box yaw out of tolerance (fail-closed)");
    assert(pre(F_n_min) >= 5.0 and pre(F_n_max) <= 25.0, "Contact force band violated over run (fail-closed)");
  end when;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info = "CartesianToolPushE: three-axis prismatic tool (2.5 kg) pushes a rigid box along a two-segment planar reference with compliant normal-force regulation. Box-table friction 0.42, tool-box friction 0.65, per-axis actuator bound 385 N, 7.2 N middle-third friction disturbance. Box mass, inertia, dimensions, contact stiffness/damping, and yaw damping are assumed (not specified by requirement) and bound explicitly here. Runs at 250 Hz for 16 s."));
end CartesianToolPushE;