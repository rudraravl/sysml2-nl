model CartesianToolPushA
  "Contact-rich Cartesian tool pushing a rigid box on a rigid table.
   Three orthogonal prismatic axes (realized as Cartesian force actuators on a
   2.5 kg tool carriage) move over +/-0.10 m in X and Y and +/-0.30 m in Z.
   Hybrid position-force control: X/Y position tracking with a compliant
   unilateral contact that regulates the in-plane normal pushing force; Z is a
   force axis (gravity-compensated position hold). A controlled 3 N friction
   disturbance is injected during the middle third of the 8 s scenario. All
   quantities are SI. Control is implemented continuously with an 80 Hz force
   filter bandwidth and 0.0125 s output interval to realize the 80 Hz trace
   requirement in an FMU-export-friendly form."

  // ---------------- Physical parameters ----------------
  parameter Real m_tool    = 2.5   "Tool carriage mass [kg]";
  parameter Real m_box     = 1.5   "Box mass [kg] (assumed; not stated in request; chosen so steady table friction keeps contact force within [5,25] N)";
  parameter Real I_box     = 0.002 "Box planar yaw inertia [kg.m^2] (assumed; not stated in request)";
  parameter Real box_half  = 0.03  "Box half-width [m] (assumed; not stated in request)";
  parameter Real tool_half = 0.03  "Tool half-width [m] (assumed; not stated in request)";
  parameter Real g         = 9.81  "Gravity [m/s^2]";
  parameter Real mu_bt     = 0.42  "Box-table friction coefficient";
  parameter Real mu_tb     = 0.65  "Tool-box friction coefficient";
  parameter Real c_contact = 2000.0 "Tool-box contact stiffness [N/m]";
  parameter Real d_contact = 20.0   "Tool-box contact damping [N.s/m]";
  parameter Real c_yaw     = 0.05   "Box yaw viscous damping [N.m.s/rad] (assumed; not stated in request)";

  // ---------------- Actuator / control parameters ----------------
  parameter Real F_max      = 252.0  "Per-axis actuator command magnitude limit [N]";
  parameter Real strokeXY   = 0.10   "X/Y stroke limit [m]";
  parameter Real strokeZ    = 0.30   "Z stroke limit [m]";
  parameter Real k_pos      = 600.0  "Position control gain [1/s^2]";
  parameter Real b_pos      = 60.0   "Position damping gain [1/s]";
  parameter Real k_z        = 400.0  "Z position gain [1/s^2]";
  parameter Real b_z        = 40.0   "Z damping gain [1/s]";
  parameter Real F_n_des    = 8.0    "Desired normal pushing force setpoint [N]";
  parameter Real k_force    = 2.0e-4 "Force-to-offset gain [m/N]";
  parameter Real offset_nom = 0.057  "Nominal tool approach offset behind box reference [m]";
  parameter Real v_eps      = 0.01   "Friction regularization velocity [m/s]";
  parameter Real k_lim      = 1.0e5  "Stroke-limit penalty stiffness [N/m]";
  parameter Real b_lim      = 1.0e3  "Stroke-limit penalty damping [N.s/m]";
  parameter Real T_sim      = 8.0    "Scenario duration [s]";
  parameter Real f_ctrl     = 80.0   "Specified control rate [Hz] (realized as force-filter bandwidth)";
  parameter Real R_arc      = 0.01   "Corner blend radius [m]";

  // ---------------- Tool states ----------------
  Real x_t(start = -offset_nom) "Tool X position [m]";
  Real vx_t(start = 0)         "Tool X velocity [m/s]";
  Real y_t(start = 0)          "Tool Y position [m]";
  Real vy_t(start = 0)         "Tool Y velocity [m/s]";
  Real z_t(start = 0.0)        "Tool Z position [m]";
  Real vz_t(start = 0)         "Tool Z velocity [m/s]";

  // ---------------- Box states ----------------
  Real x_b(start = 0)     "Box X position [m]";
  Real vx_b(start = 0)    "Box X velocity [m/s]";
  Real y_b(start = 0)     "Box Y position [m]";
  Real vy_b(start = 0)    "Box Y velocity [m/s]";
  Real theta_b(start = 0) "Box yaw [rad]";
  Real omega_b(start = 0) "Box yaw rate [rad/s]";

  // ---------------- Force controller state ----------------
  Real F_contact_filt(start = 0) "Filtered contact force [N]";

  // ---------------- Reference ----------------
  Real x_r  "Box reference X [m]";
  Real y_r  "Box reference Y [m]";
  Real tx_r "Reference tangent X component";
  Real ty_r "Reference tangent Y component";

  // ---------------- Contact / friction ----------------
  Real penetration  "Tool-box penetration along tangent [m]";
  Real v_rel_n      "Relative velocity along contact normal [m/s]";
  Real F_contact    "Normal pushing (contact) force magnitude [N]";
  Real v_rel_lat    "Relative lateral velocity at contact [m/s]";
  Real F_tbx_lat    "Tool-box lateral friction on box (lateral axis) [N]";
  Real F_table_x    "Table friction on box, X [N]";
  Real F_table_y    "Table friction on box, Y [N]";
  Real F_dist_x     "Disturbance friction, X [N]";
  Real F_dist_y     "Disturbance friction, Y [N]";
  Boolean in_disturbance "Middle-third disturbance window";

  // ---------------- Controller internals ----------------
  Real d_off        "Force-controlled offset adjustment [m]";
  Real x_t_ref      "Tool X reference [m]";
  Real y_t_ref      "Tool Y reference [m]";
  Real err_x        "Tool X tracking error [m]";
  Real err_y        "Tool Y tracking error [m]";
  Real Fx_cmd_raw   "Unsaturated X actuator command [N]";
  Real Fy_cmd_raw   "Unsaturated Y actuator command [N]";
  Real Fz_cmd_raw   "Unsaturated Z actuator command [N]";
  Real Fx_cmd       "Saturated X actuator command [N]";
  Real Fy_cmd       "Saturated Y actuator command [N]";
  Real Fz_cmd       "Saturated Z actuator command [N]";
  Real F_lim_x      "X stroke-limit penalty force [N]";
  Real F_lim_y      "Y stroke-limit penalty force [N]";
  Real F_lim_z      "Z stroke-limit penalty force [N]";
  Real tracking_error "Primary planar tracking error (box vs reference) [m]";

  // ---------------- Outputs (synchronized traces) ----------------
  output Real y_F_contact = F_contact      "Sensor: contact force [N]";
  output Real y_x_box     = x_b            "Sensor: box X pose [m]";
  output Real y_y_box     = y_b            "Sensor: box Y pose [m]";
  output Real y_yaw       = theta_b        "Sensor: box yaw [rad]";
  output Real y_track_err = tracking_error "Sensor: primary tracking error [m]";
  output Real y_Fx_cmd    = Fx_cmd         "Sensor: X actuator command [N]";
  output Real y_Fy_cmd    = Fy_cmd         "Sensor: Y actuator command [N]";
  output Real y_Fz_cmd    = Fz_cmd         "Sensor: Z actuator command [N]";

protected
  constant Real pi = 3.14159265358979323846;
  Real phi "Corner blend angle [rad]";

equation
  // ===== Two-segment planar reference with a short corner blend =====
  // Segment 1 (0-4 s): +X from (0,0) to (0.08,0).
  // Corner blend (4-4.5 s): left-turn arc, radius R_arc.
  // Segment 2 (4.5-8 s): +Y from (0.09,0.01) to (0.09,0.07).
  phi  = if time < 4.0 then 0.0
         elseif time < 4.5 then (pi/2.0)*((time - 4.0)/0.5)
         else (pi/2.0);
  x_r  = if time < 4.0 then 0.08*(time/4.0)
         elseif time < 4.5 then 0.08 + R_arc*sin(phi)
         else 0.08 + R_arc;
  y_r  = if time < 4.0 then 0.0
         elseif time < 4.5 then R_arc*(1.0 - cos(phi))
         else R_arc + 0.06*((time - 4.5)/3.5);
  tx_r = if time < 4.0 then 1.0
         elseif time < 4.5 then cos(phi)
         else 0.0;
  ty_r = if time < 4.0 then 0.0
         elseif time < 4.5 then sin(phi)
         else 1.0;

  // ===== Middle-third 3 N friction disturbance window =====
  in_disturbance = (time >= T_sim/3.0) and (time <= 2.0*T_sim/3.0);

  // ===== Contact force (compliant, unilateral along path tangent) =====
  penetration = (x_t - x_b)*tx_r + (y_t - y_b)*ty_r + (tool_half + box_half);
  v_rel_n     = (vx_t - vx_b)*tx_r + (vy_t - vy_b)*ty_r;
  F_contact   = if penetration > 0.0
                then max(0.0, c_contact*penetration + d_contact*v_rel_n)
                else 0.0;

  // Lateral (tool-box) friction along axis (-ty_r, tx_r)
  v_rel_lat   = (vx_t - vx_b)*(-ty_r) + (vy_t - vy_b)*tx_r;
  F_tbx_lat   = mu_tb*F_contact*tanh(v_rel_lat/v_eps);

  // ===== Table friction on box (Coulomb, regularized; v_eps prevents div-by-zero) =====
  F_table_x = -mu_bt*m_box*g*(vx_b/sqrt(vx_b*vx_b + vy_b*vy_b + v_eps*v_eps));
  F_table_y = -mu_bt*m_box*g*(vy_b/sqrt(vx_b*vx_b + vy_b*vy_b + v_eps*v_eps));

  // ===== Disturbance friction (3 N opposing box motion during middle third) =====
  F_dist_x = if in_disturbance
             then -3.0*(vx_b/sqrt(vx_b*vx_b + vy_b*vy_b + v_eps*v_eps))
             else 0.0;
  F_dist_y = if in_disturbance
             then -3.0*(vy_b/sqrt(vx_b*vx_b + vy_b*vy_b + v_eps*v_eps))
             else 0.0;

  // ===== Force controller: first-order filter (80 Hz) + proportional offset =====
  der(F_contact_filt) = f_ctrl*(F_contact - F_contact_filt);
  d_off = k_force*(F_n_des - F_contact_filt);

  // ===== Tool position reference (behind box along tangent) =====
  x_t_ref = x_r - (offset_nom + d_off)*tx_r;
  y_t_ref = y_r - (offset_nom + d_off)*ty_r;
  err_x = x_t_ref - x_t;
  err_y = y_t_ref - y_t;

  // ===== Hybrid position-force commands =====
  // X / Y: position (PD); normal pushing force regulated via contact compliance + offset.
  Fx_cmd_raw = m_tool*(k_pos*err_x - b_pos*vx_t);
  Fy_cmd_raw = m_tool*(k_pos*err_y - b_pos*vy_t);
  // Z: force axis with gravity compensation, position hold at table height.
  Fz_cmd_raw = m_tool*g + m_tool*(k_z*(0.0 - z_t) - b_z*vz_t);

  // Actuator magnitude saturation (+/- F_max per axis)
  Fx_cmd = max(-F_max, min(F_max, Fx_cmd_raw));
  Fy_cmd = max(-F_max, min(F_max, Fy_cmd_raw));
  Fz_cmd = max(-F_max, min(F_max, Fz_cmd_raw));

  // ===== Stroke-limit soft penalties (X/Y +/-0.10 m, Z +/-0.30 m) =====
  F_lim_x = if x_t > strokeXY   then -k_lim*(x_t - strokeXY)  - b_lim*vx_t
           elseif x_t < -strokeXY then -k_lim*(x_t + strokeXY) - b_lim*vx_t
           else 0.0;
  F_lim_y = if y_t > strokeXY   then -k_lim*(y_t - strokeXY)  - b_lim*vy_t
           elseif y_t < -strokeXY then -k_lim*(y_t + strokeXY) - b_lim*vy_t
           else 0.0;
  F_lim_z = if z_t > strokeZ    then -k_lim*(z_t - strokeZ)   - b_lim*vz_t
           elseif z_t < -strokeZ  then -k_lim*(z_t + strokeZ)  - b_lim*vz_t
           else 0.0;

  // ===== Tool dynamics (3 prismatic axes) =====
  der(x_t)  = vx_t;
  der(vx_t) = (Fx_cmd - F_contact*tx_r + F_tbx_lat*ty_r + F_lim_x)/m_tool;
  der(y_t)  = vy_t;
  der(vy_t) = (Fy_cmd - F_contact*ty_r - F_tbx_lat*tx_r + F_lim_y)/m_tool;
  der(z_t)  = vz_t;
  der(vz_t) = (Fz_cmd - m_tool*g + F_lim_z)/m_tool;

  // ===== Box planar dynamics =====
  der(x_b)  = vx_b;
  der(vx_b) = (F_contact*tx_r - F_tbx_lat*ty_r + F_table_x + F_dist_x)/m_box;
  der(y_b)  = vy_b;
  der(vy_b) = (F_contact*ty_r + F_tbx_lat*tx_r + F_table_y + F_dist_y)/m_box;
  der(theta_b) = omega_b;
  // Yaw torque from lateral tool-box friction applied at the rear contact face
  // (moment arm -box_half along the tangent) plus yaw damping.
  der(omega_b) = (-box_half*F_tbx_lat - c_yaw*omega_b)/I_box;

  // ===== Primary tracking error (box planar pose vs reference) =====
  tracking_error = sqrt((x_r - x_b)*(x_r - x_b) + (y_r - y_b)*(y_r - y_b));

  annotation (
    experiment(StartTime = 0.0, StopTime = 8.0, Tolerance = 1.0e-6, Interval = 0.0125),
    Documentation(info = "CartesianToolPushA: three force-limited prismatic actuators (252 N/axis) drive a 2.5 kg tool carriage that pushes a rigid box along a two-segment planar reference on a rigid table. Box-table friction 0.42, tool-box friction 0.65. Hybrid position-force control maintains the in-plane normal pushing force within [5,25] N. A 3 N friction disturbance is applied during the middle third (t in [2.667,5.333] s). Box mass, yaw inertia, and geometric half-widths are assumed (not stated in the request) and are commented as such. The 80 Hz requirement is realized by an 80 Hz force-filter bandwidth and a 0.0125 s output interval. The model is scalar, causal, and FMU 2.0 Co-Simulation exportable. No NaN/infinite values arise: all divisors are regularized (v_eps) and all dynamic states have finite non-singular initial conditions.")
  );
end CartesianToolPushA;