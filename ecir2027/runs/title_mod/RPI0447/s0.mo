model ContactArmPushC
  "Hybrid position-force control of a fixed 6R (Z-Y-Y-X-Y-X) arm pushing a rigid
   box on a rigid table. Requirement-specified facts: max joint effort 110 N.m,
   5.4 N friction-change disturbance in the middle third, box-table friction 0.42,
   tool-box friction 0.65, 125 Hz control, 12 s run, contact force 5..25 N,
   primary tracking error < 0.042 m after 7.8 s, no NaN/Inf.
   All values not stated in the requirement are placeholder estimates (marked)."

  // ---- Requirement-specified parameters ----
  parameter Real tau_max    = 110.0  "Maximum joint effort magnitude (N.m)";
  parameter Real dF_friction= 5.4    "Controlled friction change disturbance (N)";
  parameter Real mu_table   = 0.42   "Box-table friction coefficient";
  parameter Real mu_tool    = 0.65   "Tool-box friction coefficient";
  parameter Real f_sample   = 125.0  "Control loop frequency (Hz)";
  parameter Real T_end      = 12.0   "Total run time (s)";
  parameter Real F_n_min    = 5.0    "Minimum contact force (N)";
  parameter Real F_n_max    = 25.0   "Maximum contact force (N)";
  parameter Real F_n_ref    = 15.0   "Desired normal pushing force (N), midpoint of [5,25]";
  parameter Real err_thresh = 0.042  "Primary tracking error threshold (m)";
  parameter Real t_check    = 7.8    "Tracking-error check time (s)";
  parameter Real Ts         = 1.0/f_sample "Sample period (s)";

  // ---- Path/scenario: segment split and lengths not specified -> placeholders ----
  parameter Real t_seg1     = 6.0    "End of reference segment 1 (s) [placeholder]";
  parameter Real seg1_dx     = 0.30  "Segment 1 displacement along x (m) [placeholder]";
  parameter Real seg2_dy     = 0.20  "Segment 2 displacement along y (m) [placeholder]";
  parameter Real x_box0      = 0.0   "Initial box x (m) [placeholder]";
  parameter Real y_box0      = 0.0   "Initial box y (m) [placeholder]";
  parameter Real pen_nominal = 0.003 "Nominal contact penetration for F_n_ref (m) [placeholder, =F_n_ref/k_contact]";

  // ---- Arm: 6R, axes Z-Y-Y-X-Y-X. Full multibody kinematics not specified -> lumped placeholder ----
  parameter String axes_seq = "Z-Y-Y-X-Y-X" "Joint axes sequence (documented)";
  parameter Real J6[6]  = {0.05,0.04,0.03,0.01,0.008,0.005} "Joint inertias (kg.m^2) [placeholder]";
  parameter Real b6[6]  = {0.20,0.15,0.12,0.08,0.06,0.05} "Joint damping (N.m.s/rad) [placeholder]";
  parameter Real cx[6] = {0.40,0.20,0.12,0.05,0.03,0.02} "FK weight to tool x (m/rad) [placeholder]";
  parameter Real cy[6] = {0.00,0.05,0.10,0.20,0.15,0.08} "FK weight to tool y (m/rad) [placeholder]";
  parameter Real jac[6]= {1.0,0.8,0.7,0.6,0.5,0.4}       "Jacobian weight torque<-cart force [placeholder]";
  parameter Real x_tip0 = 0.0 "Tool x offset at q=0 (m) [placeholder]";
  parameter Real y_tip0 = 0.0 "Tool y offset at q=0 (m) [placeholder]";

  // ---- Box / contact: not specified -> placeholders ----
  parameter Real m_box      = 2.0    "Box mass (kg) [placeholder]";
  parameter Real g_grav     = 9.81   "Gravity (m/s^2)";
  parameter Real I_box      = 0.02   "Box yaw inertia (kg.m^2) [placeholder]";
  parameter Real L_box     = 0.10   "Box side length (m) [placeholder]";
  parameter Real k_contact = 5000.0 "Contact stiffness (N/m) [placeholder, pen_nominal=F_n_ref/k]";
  parameter Real d_contact = 100.0  "Contact damping (N.s/m) [placeholder]";
  parameter Real pen_eps   = 1.0e-4 "Smooth penetration eps (m) [placeholder]";
  parameter Real v_eps2    = 1.0e-3 "Table friction speed norm eps (m/s) [placeholder]";

  // ---- Controller gains: not specified -> placeholders ----
  parameter Real Kp_pos  = 600.0  "Position P gain (N/m) [placeholder]";
  parameter Real Kd_pos  = 40.0   "Position D gain (N.s/m) [placeholder]";
  parameter Real Kf_adm  = 0.0002 "Force admittance gain (m/N) [placeholder]";
  parameter Real Kp_yaw  = 8.0    "Yaw regulation P gain (N/rad) [placeholder]";
  parameter Real Kd_yaw  = 1.5    "Yaw regulation D gain (N.s/rad) [placeholder]";

  parameter Real pi = 3.14159265358979 "pi";

  // ---- Continuous arm states (scalar) ----
  Real q1(start=0), q2(start=0), q3(start=0), q4(start=0), q5(start=0), q6(start=0) "Joint angles (rad)";
  Real dq1(start=0),dq2(start=0),dq3(start=0),dq4(start=0),dq5(start=0),dq6(start=0) "Joint velocities (rad/s)";

  // ---- Continuous box states ----
  Real x_box(start=x_box0) "Box x position (m)";
  Real y_box(start=y_box0) "Box y position (m)";
  Real vx(start=0) "Box x velocity (m/s)";
  Real vy(start=0) "Box y velocity (m/s)";
  Real psi(start=0) "Box yaw (rad)";
  Real dpsi(start=0) "Box yaw rate (rad/s)";

  // ---- Tool tip ----
  Real x_tip "Tool tip x (m)";
  Real y_tip "Tool tip y (m)";
  Real v_tip_x "Tool tip x velocity (m/s)";
  Real v_tip_y "Tool tip y velocity (m/s)";

  // ---- Contact / friction ----
  Real gap_n "Signed normal penetration (m)";
  Real pen_s "Smooth penetration (m)";
  Real F_n "Normal contact force (N)";
  Real F_dist "Active disturbance friction force (N)";
  Real F_table_x "Table friction force x (N)";
  Real F_table_y "Table friction force y (N)";
  Real F_lat "Lateral tool-box friction force (N)";
  Real speed "Box speed (m/s)";
  Real v_pen_rel "Relative normal velocity (m/s)";
  Real damp_gate "Smooth contact damping gate";

  // ---- Reference / direction ----
  Real x_ref "Reference box x (m)";
  Real y_ref "Reference box y (m)";
  Real d_x "Active pushing direction x component";
  Real d_y "Active pushing direction y component";

  // ---- Discrete controller (125 Hz) ----
  discrete Real tau_cmd1(start=0),tau_cmd2(start=0),tau_cmd3(start=0),tau_cmd4(start=0),tau_cmd5(start=0),tau_cmd6(start=0) "Unsaturated torque commands (N.m)";
  discrete Real tau_sat1(start=0),tau_sat2(start=0),tau_sat3(start=0),tau_sat4(start=0),tau_sat5(start=0),tau_sat6(start=0) "Saturated applied torques (N.m)";
  discrete Real x_cmd_h(start=0) "Held tool x command (m)";
  discrete Real y_cmd_h(start=0) "Held tool y command (m)";
  discrete Real F_n_meas_h(start=0) "Held measured contact force (N)";
  discrete Real e_track_h(start=0) "Held tracking error (m)";

  // ---- Six-axis wrist sensor ----
  Real wrist_fx "Wrist force x (N)";
  Real wrist_fy "Wrist force y (N)";
  Real wrist_fz "Wrist force z (N)";
  Real wrist_mx "Wrist moment x (N.m)";
  Real wrist_my "Wrist moment y (N.m)";
  Real wrist_mz "Wrist moment z (N.m)";

  // ---- Requirement-check observables ----
  Real e_track "Primary tracking error (m)";
  Boolean track_ok "Tracking requirement satisfied";
  Boolean F_n_ok "Contact force within [5,25] N";
  Boolean actuator_ok "Actuators within bounds (guaranteed by saturation)";
  Boolean no_nan_inf "No NaN/Infinite values flag";
  Real final_x_box "Final box x (m)";
  Real final_y_box "Final box y (m)";
  Real final_psi "Final box yaw (rad)";

equation
  // ---- Two-segment planar reference and active pushing direction ----
  if time <= t_seg1 then
    x_ref = x_box0 + seg1_dx*0.5*(1 - cos(pi*time/t_seg1));
    y_ref = y_box0;
    d_x = 1.0;
    d_y = 0.0;
  else
    x_ref = x_box0 + seg1_dx;
    y_ref = y_box0 + seg2_dy*0.5*(1 - cos(pi*(time - t_seg1)/(T_end - t_seg1)));
    d_x = 0.0;
    d_y = 1.0;
  end if;

  // ---- Disturbance: 5.4 N friction change during middle third ----
  F_dist = if (time >= T_end/3.0) and (time <= 2.0*T_end/3.0) then dF_friction else 0.0;

  // ---- Arm forward kinematics (expanded) ----
  x_tip = x_tip0 + cx[1]*q1 + cx[2]*q2 + cx[3]*q3 + cx[4]*q4 + cx[5]*q5 + cx[6]*q6;
  y_tip = y_tip0 + cy[1]*q1 + cy[2]*q2 + cy[3]*q3 + cy[4]*q4 + cy[5]*q5 + cy[6]*q6;
  v_tip_x = cx[1]*dq1 + cx[2]*dq2 + cx[3]*dq3 + cx[4]*dq4 + cx[5]*dq5 + cx[6]*dq6;
  v_tip_y = cy[1]*dq1 + cy[2]*dq2 + cy[3]*dq3 + cy[4]*dq4 + cy[5]*dq5 + cy[6]*dq6;

  // ---- Arm joint dynamics (saturated effort actuators) ----
  J6[1]*der(dq1) = tau_sat1 - b6[1]*dq1;  der(q1) = dq1;
  J6[2]*der(dq2) = tau_sat2 - b6[2]*dq2;  der(q2) = dq2;
  J6[3]*der(dq3) = tau_sat3 - b6[3]*dq3;  der(q3) = dq3;
  J6[4]*der(dq4) = tau_sat4 - b6[4]*dq4;  der(q4) = dq4;
  J6[5]*der(dq5) = tau_sat5 - b6[5]*dq5;  der(q5) = dq5;
  J6[6]*der(dq6) = tau_sat6 - b6[6]*dq6;  der(q6) = dq6;

  // ---- Smooth penalty contact force along active normal direction ----
  gap_n = (x_tip - x_box)*d_x + (y_tip - y_box)*d_y;
  pen_s = 0.5*(gap_n + sqrt(gap_n*gap_n + pen_eps*pen_eps));
  v_pen_rel = (v_tip_x - vx)*d_x + (v_tip_y - vy)*d_y;
  damp_gate = 0.5*(tanh(gap_n/pen_eps) + 1.0);
  F_n = k_contact*pen_s + d_contact*v_pen_rel*damp_gate;

  // ---- Regularized Coulomb table friction (zero-error branch via v_eps2) ----
  speed = sqrt(vx*vx + vy*vy + v_eps2*v_eps2);
  F_table_x = -mu_table*m_box*g_grav*vx/speed;
  F_table_y = -mu_table*m_box*g_grav*vy/speed;

  // ---- Box translational dynamics: pushed by F_n along d, resisted by table friction + disturbance ----
  m_box*der(vx) = F_n*d_x - F_dist*d_x + F_table_x;
  m_box*der(vy) = F_n*d_y - F_dist*d_y + F_table_y;
  der(x_box) = vx;
  der(y_box) = vy;

  // ---- Yaw dynamics: regulated by lateral friction bounded by mu_tool*F_n ----
  F_lat = max(-mu_tool*F_n, min(mu_tool*F_n, -Kp_yaw*psi - Kd_yaw*dpsi));
  I_box*der(dpsi) = F_lat*(L_box/2.0);
  der(psi) = dpsi;

  // ---- Six-axis wrist sensor (contact reaction at wrist) ----
  wrist_fx = F_n*d_x;
  wrist_fy = F_n*d_y;
  wrist_fz = 0.0;
  wrist_mx = 0.0;
  wrist_my = 0.0;
  wrist_mz = F_lat*(L_box/2.0);

  // ---- Primary tracking error ----
  e_track = sqrt((x_box - x_ref)*(x_box - x_ref) + (y_box - y_ref)*(y_box - y_ref));

  // ---- Requirement flags ----
  track_ok = (time < t_check) or (e_track <= err_thresh);
  F_n_ok = (F_n >= F_n_min) and (F_n <= F_n_max);
  actuator_ok = true; // saturation guarantees |tau_sat| <= tau_max
  no_nan_inf = (F_n == F_n) and (x_box == x_box) and (y_box == y_box) and (psi == psi)
               and (abs(F_n) < 1.0e9) and (abs(x_box) < 1.0e6) and (abs(y_box) < 1.0e6)
               and (abs(psi) < 1.0e6);
  final_x_box = x_box;
  final_y_box = y_box;
  final_psi = psi;

  // ---- Discrete hybrid position-force controller at 125 Hz (zero-order hold) ----
  when sample(0, Ts) then
    // Admittance: tool command = box reference + penetration lead adjusted by force error
    x_cmd_h = x_ref + d_x*(pen_nominal + Kf_adm*(F_n_ref - F_n));
    y_cmd_h = y_ref + d_y*(pen_nominal + Kf_adm*(F_n_ref - F_n));
    F_n_meas_h = F_n;
    e_track_h = sqrt((x_box - x_ref)*(x_box - x_ref) + (y_box - y_ref)*(y_box - y_ref));

    // Cartesian PD force command mapped to joint torques via Jacobian weights
    tau_cmd1 = jac[1]*(cx[1]*(Kp_pos*(x_cmd_h - x_tip) + Kd_pos*(0.0 - v_tip_x))
                      + cy[1]*(Kp_pos*(y_cmd_h - y_tip) + Kd_pos*(0.0 - v_tip_y)));
    tau_cmd2 = jac[2]*(cx[2]*(Kp_pos*(x_cmd_h - x_tip) + Kd_pos*(0.0 - v_tip_x))
                      + cy[2]*(Kp_pos*(y_cmd_h - y_tip) + Kd_pos*(0.0 - v_tip_y)));
    tau_cmd3 = jac[3]*(cx[3]*(Kp_pos*(x_cmd_h - x_tip) + Kd_pos*(0.0 - v_tip_x))
                      + cy[3]*(Kp_pos*(y_cmd_h - y_tip) + Kd_pos*(0.0 - v_tip_y)));
    tau_cmd4 = jac[4]*(cx[4]*(Kp_pos*(x_cmd_h - x_tip) + Kd_pos*(0.0 - v_tip_x))
                      + cy[4]*(Kp_pos*(y_cmd_h - y_tip) + Kd_pos*(0.0 - v_tip_y)));
    tau_cmd5 = jac[5]*(cx[5]*(Kp_pos*(x_cmd_h - x_tip) + Kd_pos*(0.0 - v_tip_x))
                      + cy[5]*(Kp_pos*(y_cmd_h - y_tip) + Kd_pos*(0.0 - v_tip_y)));
    tau_cmd6 = jac[6]*(cx[6]*(Kp_pos*(x_cmd_h - x_tip) + Kd_pos*(0.0 - v_tip_x))
                      + cy[6]*(Kp_pos*(y_cmd_h - y_tip) + Kd_pos*(0.0 - v_tip_y)));

    // Saturated joint effort actuators: |tau| <= 110 N.m
    tau_sat1 = max(-tau_max, min(tau_max, tau_cmd1));
    tau_sat2 = max(-tau_max, min(tau_max, tau_cmd2));
    tau_sat3 = max(-tau_max, min(tau_max, tau_cmd3));
    tau_sat4 = max(-tau_max, min(tau_max, tau_cmd4));
    tau_sat5 = max(-tau_max, min(tau_max, tau_cmd5));
    tau_sat6 = max(-tau_max, min(tau_max, tau_cmd6));
  end when;

  annotation (experiment(StopTime=12.0, Tolerance=1e-6),
              Documentation(info="Replaceable rigid tool and capsule link geometry are not
              specified by the requirement and are abstracted here as lumped planar
              kinematics; full 6R multibody, link capsule dimensions, and exact tool
              geometry are unknowns left as placeholders."));
end ContactArmPushC;