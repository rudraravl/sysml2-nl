model CartesianToolPushC
  "Hybrid position-force control for contact-rich box pushing along a two-segment planar reference"

  // ==================== Parameters: Tool / Robot (specified) ====================
  parameter Real m_tool = 2.5 "Tool carriage mass [kg]";
  parameter Real F_max = 322.0 "Max actuator command per axis [N]";
  parameter Real X_lim = 0.10 "X travel limit [m]";
  parameter Real Y_lim = 0.10 "Y travel limit [m]";
  parameter Real Z_lim = 0.30 "Z travel limit [m]";
  parameter Real g = 9.81 "Gravity [m/s^2]";

  // ==================== Parameters: Box (mass/size not specified — assumed) ====================
  parameter Real m_box = 1.5 "Box mass [kg] — not specified in requirement, assumed for plant dynamics";
  parameter Real box_half = 0.03 "Box half-size [m] — not specified, assumed";

  // ==================== Parameters: Friction (specified) ====================
  parameter Real mu_box_table = 0.42 "Box-table friction coefficient";
  parameter Real mu_tool_box = 0.65 "Tool-box friction coefficient";
  parameter Real v_eps = 0.002 "Friction regularization velocity [m/s]";

  // ==================== Parameters: Contact model (assumed) ====================
  parameter Real k_contact = 5000.0 "Contact stiffness [N/m]";
  parameter Real d_contact = 300.0 "Contact damping [N.s/m]";

  // ==================== Parameters: Control (specified: 125 Hz, 12 s) ====================
  parameter Real Ts = 1.0/125.0 "Control sampling period [s]";
  parameter Real T_end = 12.0 "Total simulation time [s]";
  parameter Real T_seg1 = 6.0 "Segment 1 end time [s]";

  // ==================== Parameters: Force control (specified: 5–25 N) ====================
  parameter Real F_target = 20.0 "Target normal pushing force [N]";
  parameter Real F_contact_min = 5.0 "Min contact force [N]";
  parameter Real F_contact_max = 25.0 "Max contact force [N]";
  parameter Real kp_force = 0.1 "Force P gain [1]";
  parameter Real ki_force = 3.0 "Force I gain [1/s]";
  parameter Real F_int_max = 30.0 "Force integral limit [N]";

  // ==================== Parameters: Position control (assumed gains) ====================
  parameter Real kp_pos = 1000.0 "Position P gain [N/m]";
  parameter Real kd_pos = 80.0 "Position D gain [N.s/m]";
  parameter Real kp_z = 500.0 "Z position P gain [N/m]";
  parameter Real kd_z = 40.0 "Z position D gain [N.s/m]";

  // ==================== Parameters: Reference (segment distances not specified — assumed) ====================
  parameter Real x_ref_end1 = 0.08 "Segment 1 end X [m] — assumed";
  parameter Real y_ref_end2 = 0.05 "Segment 2 end Y [m] — assumed";
  parameter Real z_contact = 0.02 "Tool contact height [m] — assumed";

  // ==================== Parameters: Disturbance (specified: 5.4 N, middle third) ====================
  parameter Real T_dist_start = 4.0 "Disturbance start time [s]";
  parameter Real T_dist_end = 8.0 "Disturbance end time [s]";
  parameter Real F_dist = 5.4 "Friction change disturbance magnitude [N]";

  // ==================== Parameters: Validation (specified) ====================
  parameter Real e_thresh = 0.042 "Tracking error threshold [m]";
  parameter Real T_check = 7.8 "Tracking check time [s]";
  parameter Real k_limit = 1.0e4 "Travel limit stop stiffness [N/m]";

  // ==================== Tool state ====================
  Real x_t(start=-0.03) "Tool X position [m]";
  Real y_t(start=-0.03) "Tool Y position [m]";
  Real z_t(start=0.05) "Tool Z position [m]";
  Real vx_t(start=0.0) "Tool X velocity [m/s]";
  Real vy_t(start=0.0) "Tool Y velocity [m/s]";
  Real vz_t(start=0.0) "Tool Z velocity [m/s]";

  // ==================== Box state ====================
  Real s_b(start=0.0) "Box position along path [m]";
  Real v_s_b(start=0.0) "Box velocity along path [m/s]";
  Real x_b "Box X position [m]";
  Real y_b "Box Y position [m]";
  Real psi_b(start=0.0) "Box yaw [rad]";

  // ==================== Contact / direction variables ====================
  Real nx "Normal direction X component";
  Real ny "Normal direction Y component";
  Real tx "Tangent direction X component";
  Real ty "Tangent direction Y component";
  Real pen "Contact penetration [m]";
  Real pen_pos "Positive penetration [m]";
  Real v_rel_n "Relative normal velocity [m/s]";
  Real v_rel_t "Relative tangential velocity [m/s]";
  Real F_n "Normal contact force [N]";
  Real F_fric_t "Tangential tool-box friction force [N]";

  // ==================== Table friction / disturbance ====================
  Real F_table "Table friction force on box [N]";
  Real F_dist_force "Disturbance friction force [N]";

  // ==================== Reference ====================
  Real x_ref "Reference box X [m]";
  Real y_ref "Reference box Y [m]";
  Real s_ref "Reference path parameter [m]";
  Real v_ref "Reference path velocity [m/s]";
  Real vx_ref "Reference X velocity [m/s]";
  Real vy_ref "Reference Y velocity [m/s]";

  // ==================== Controller (discrete, 125 Hz) ====================
  discrete Real F_int(start=0.0) "Force integral term [N]";
  discrete Real F_force_ctrl(start=0.0) "Force controller output [N]";
  discrete Real F_cmd_x_s(start=0.0) "Sampled X force command [N]";
  discrete Real F_cmd_y_s(start=0.0) "Sampled Y force command [N]";
  discrete Real F_cmd_z_s(start=0.0) "Sampled Z force command [N]";

  // ==================== Actuator limits / travel stops ====================
  Real F_cmd_x_l "Limited X command [N]";
  Real F_cmd_y_l "Limited Y command [N]";
  Real F_cmd_z_l "Limited Z command [N]";
  Real F_lim_x "X travel limit force [N]";
  Real F_lim_y "Y travel limit force [N]";
  Real F_lim_z "Z travel limit force [N]";

  // ==================== Sensors ====================
  Real x_meas "Measured tool X [m]";
  Real y_meas "Measured tool Y [m]";
  Real z_meas "Measured tool Z [m]";
  Real vx_meas "Measured tool X velocity [m/s]";
  Real vy_meas "Measured tool Y velocity [m/s]";
  Real vz_meas "Measured tool Z velocity [m/s]";
  Real F_meas "Measured contact force [N]";
  Real x_b_meas "Measured box X [m]";
  Real y_b_meas "Measured box Y [m]";
  Real psi_b_meas "Measured box yaw [rad]";

  // ==================== Validation ====================
  Real e_pos "Primary tracking error [m]";
  Boolean contact_ok "Contact force within [5,25] N when in contact";
  Boolean tracking_ok "Tracking error below threshold after 7.8 s";
  Boolean bounds_ok "Actuator and travel bounds satisfied";
  Real final_x "Final box X [m]";
  Real final_y "Final box Y [m]";

equation
  // ==================== Reference trajectory (two-segment planar) ====================
  if time < T_seg1 then
    s_ref = x_ref_end1 * (time / T_seg1);
    v_ref = x_ref_end1 / T_seg1;
    x_ref = s_ref;
    y_ref = 0.0;
    vx_ref = v_ref;
    vy_ref = 0.0;
    nx = 0.0;
    ny = 1.0;
    tx = 1.0;
    ty = 0.0;
  else
    s_ref = x_ref_end1 + y_ref_end2 * ((time - T_seg1) / (T_end - T_seg1));
    v_ref = y_ref_end2 / (T_end - T_seg1);
    x_ref = x_ref_end1;
    y_ref = s_ref - x_ref_end1;
    vx_ref = 0.0;
    vy_ref = v_ref;
    nx = 1.0;
    ny = 0.0;
    tx = 0.0;
    ty = 1.0;
  end if;

  // ==================== Box kinematics (constrained to planar path) ====================
  if s_b < x_ref_end1 then
    x_b = s_b;
    y_b = 0.0;
  else
    x_b = x_ref_end1;
    y_b = s_b - x_ref_end1;
  end if;
  der(psi_b) = 0.0;

  // ==================== Contact model (spring-damper along normal) ====================
  pen = nx*(x_t - x_b) + ny*(y_t - y_b) + box_half;
  pen_pos = max(pen, 0.0);
  v_rel_n = nx*vx_t + ny*vy_t;
  F_n = max(k_contact * pen_pos + d_contact * (if pen > 0.0 then v_rel_n else 0.0), 0.0);

  // ==================== Tool-box tangential friction ====================
  v_rel_t = tx*vx_t + ty*vy_t - v_s_b;
  F_fric_t = mu_tool_box * F_n * tanh(v_rel_t / v_eps);

  // ==================== Table friction and disturbance ====================
  F_table = mu_box_table * m_box * g * tanh(v_s_b / v_eps);
  if time >= T_dist_start and time < T_dist_end then
    F_dist_force = F_dist * tanh(v_s_b / v_eps);
  else
    F_dist_force = 0.0;
  end if;

  // ==================== Box dynamics along path ====================
  m_box * der(v_s_b) = F_fric_t - F_table - F_dist_force;
  der(s_b) = v_s_b;

  // ==================== Actuator force limits (±322 N per axis) ====================
  F_cmd_x_l = max(-F_max, min(F_max, F_cmd_x_s));
  F_cmd_y_l = max(-F_max, min(F_max, F_cmd_y_s));
  F_cmd_z_l = max(-F_max, min(F_max, F_cmd_z_s));

  // ==================== Travel limit stops ====================
  F_lim_x = (if x_t > X_lim then -k_limit*(x_t - X_lim) elseif x_t < -X_lim then -k_limit*(x_t + X_lim) else 0.0);
  F_lim_y = (if y_t > Y_lim then -k_limit*(y_t - Y_lim) elseif y_t < -Y_lim then -k_limit*(y_t + Y_lim) else 0.0);
  F_lim_z = (if z_t > Z_lim then -k_limit*(z_t - Z_lim) elseif z_t < -Z_lim then -k_limit*(z_t + Z_lim) else 0.0);

  // ==================== Tool dynamics (3 prismatic axes) ====================
  m_tool * der(vx_t) = F_cmd_x_l + (-F_n*nx - F_fric_t*tx) + F_lim_x;
  m_tool * der(vy_t) = F_cmd_y_l + (-F_n*ny - F_fric_t*ty) + F_lim_y;
  m_tool * der(vz_t) = F_cmd_z_l - m_tool*g + F_lim_z;
  der(x_t) = vx_t;
  der(y_t) = vy_t;
  der(z_t) = vz_t;

  // ==================== Sensors ====================
  x_meas = x_t;
  y_meas = y_t;
  z_meas = z_t;
  vx_meas = vx_t;
  vy_meas = vy_t;
  vz_meas = vz_t;
  F_meas = F_n;
  x_b_meas = x_b;
  y_b_meas = y_b;
  psi_b_meas = psi_b;

  // ==================== Hybrid position-force controller (sampled at 125 Hz) ====================
  when sample(0, Ts) then
    // Force integral with anti-windup (integrate only when in contact)
    F_int = max(-F_int_max, min(F_int_max,
      pre(F_int) + (if pen > 0.0 then ki_force * (F_target - F_n) * Ts else 0.0)));
    // Force controller: feedforward + PI on normal force error
    F_force_ctrl = F_target + kp_force * (F_target - F_n) + F_int;
    // Position controller in tangent + force controller in normal + Z position with gravity comp
    F_cmd_x_s = kp_pos * (x_ref - nx*box_half - x_t) + kd_pos * (vx_ref - vx_t) + nx * F_force_ctrl;
    F_cmd_y_s = kp_pos * (y_ref - ny*box_half - y_t) + kd_pos * (vy_ref - vy_t) + ny * F_force_ctrl;
    F_cmd_z_s = kp_z * (z_contact - z_t) - kd_z * vz_t + m_tool * g;
  end when;

  // ==================== Validation ====================
  e_pos = sqrt((x_b - x_ref)*(x_b - x_ref) + (y_b - y_ref)*(y_b - y_ref) + 1.0e-12);
  contact_ok = (pen <= 0.0) or ((F_n >= F_contact_min) and (F_n <= F_contact_max));
  tracking_ok = (time < T_check) or (e_pos < e_thresh);
  bounds_ok = (abs(F_cmd_x_l) <= F_max + 1.0e-6) and (abs(F_cmd_y_l) <= F_max + 1.0e-6)
    and (abs(F_cmd_z_l) <= F_max + 1.0e-6) and (abs(x_t) <= X_lim + 1.0e-6)
    and (abs(y_t) <= Y_lim + 1.0e-6) and (abs(z_t) <= Z_lim + 1.0e-6);
  final_x = x_b;
  final_y = y_b;

  annotation(experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008));
end CartesianToolPushC;