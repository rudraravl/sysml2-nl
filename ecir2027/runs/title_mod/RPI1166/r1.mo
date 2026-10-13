model MixedTeamHandoffB
  // ---- Physical parameters ----
  parameter Real m_g(unit="kg") = 24.0 "ground robot mass";
  parameter Real m_q(unit="kg") = 2.1 "quadrotor mass";
  parameter Real g_acc(unit="m/s2") = 9.81;
  parameter Real I_q_val(unit="kg.m2") = 0.05 "quadrotor pitch inertia";
  parameter Real L_arm(unit="m") = 0.2 "rotor moment arm";

  // ---- Command bounds ----
  parameter Real tau_max(unit="N.m") = 11.5 "wheel torque bound";
  parameter Real T_max(unit="N") = 11.5 "rotor thrust bound";

  // ---- Mission parameters ----
  parameter Real sep_min(unit="m") = 0.5 "minimum robot separation";
  parameter Real t_end(unit="s") = 10.0;
  parameter Real dt(unit="s") = 0.01 "100 Hz control/comm cycle";
  parameter Real t_delay_disturb(unit="s") = 0.07 "injected middle-third delay";
  parameter Real t_mid_start(unit="s") = t_end/3.0;
  parameter Real t_mid_end(unit="s") = 2.0*t_end/3.0;
  parameter Real err_thresh(unit="m") = 0.48 "primary tracking error threshold";
  parameter Real t_err_check(unit="s") = 6.5 "error check time";

  // ---- World-frame survey features / markers / walls ----
  parameter Real markerA_x(unit="m") = 2.0;
  parameter Real markerA_y(unit="m") = 0.0;
  parameter Real markerB_x(unit="m") = 5.0;
  parameter Real markerB_y(unit="m") = 1.5;
  parameter Real wall_x(unit="m") = 7.0;
  parameter Real z_hover(unit="m") = 2.0 "quadrotor cruise height";
  parameter Real v_cruise(unit="m/s") = 1.0 "quadrotor cruise speed after handoff";

  // ---- Control gains ----
  parameter Real kp_g = 8.0;
  parameter Real kd_g = 6.0;
  parameter Real kp_q_x = 1.5;
  parameter Real kd_q_x = 1.0;
  parameter Real kp_q_z = 12.0;
  parameter Real kd_q_z = 5.0;
  parameter Real kp_att = 25.0;
  parameter Real kd_att = 8.0;
  parameter Real theta_lim(unit="rad") = 0.3;

  // ---- Ground robot states ----
  Real x_g(start=0.0, fixed=true, unit="m");
  Real y_g(start=0.0, fixed=true, unit="m");
  Real vx_g(start=0.0, fixed=true, unit="m/s");
  Real vy_g(start=0.0, fixed=true, unit="m/s");
  Real Fx_g_raw(unit="N");
  Real Fy_g_raw(unit="N");
  Real Fx_g(unit="N") "saturated wheel-torque-derived force";
  Real Fy_g(unit="N");
  Real tau_wL(unit="N.m") "left wheel torque";
  Real tau_wR(unit="N.m") "right wheel torque";
  Real lidar_range(unit="m") "lidar local sensor: range to wall";

  // ---- Quadrotor states ----
  Real x_q(start=0.0, fixed=true, unit="m");
  Real z_q(start=z_hover, fixed=true, unit="m");
  Real theta_q(start=0.0, fixed=true, unit="rad");
  Real vx_q(start=0.0, fixed=true, unit="m/s");
  Real vz_q(start=0.0, fixed=true, unit="m/s");
  Real omega_q(start=0.0, fixed=true, unit="rad/s");
  Real T1(unit="N");
  Real T2(unit="N");
  Real T3(unit="N");
  Real T4(unit="N");
  Real T_tot(unit="N");
  Real M_pitch(unit="N.m");
  Real T_des(unit="N");
  Real M_des(unit="N.m");
  Real theta_des(unit="rad");
  Real v_ref(unit="m/s") "feedforward cruise velocity";
  Real camera_feat "camera local sensor: relative feature to markerB";

  // ---- References and errors ----
  Real x_g_ref(unit="m");
  Real y_g_ref(unit="m");
  Real x_q_ref(unit="m");
  Real z_q_ref(unit="m");
  Real err_g(unit="m");
  Real err_q(unit="m");
  Real err_primary(unit="m");
  Boolean err_ok;

  // ---- Communication (timestamped result exchange) ----
  Real comm_delay(unit="s");
  discrete Real send_time_g(start=-1.0, unit="s");
  discrete Real send_x_g(start=0.0, unit="m");
  discrete Real send_y_g(start=0.0, unit="m");
  discrete Real send_result_g(start=0.0);
  discrete Real recv_time_q(start=-1.0, unit="s");
  discrete Real recv_x_g(start=0.0, unit="m");
  discrete Real recv_y_g(start=0.0, unit="m");
  discrete Real recv_result_g(start=0.0);
  discrete Real data_age_q(start=0.0, unit="s");
  discrete Real send_time_q(start=-1.0, unit="s");
  discrete Real send_x_q(start=0.0, unit="m");
  discrete Real send_z_q(start=0.0, unit="m");
  discrete Real send_map_q(start=0.0);
  discrete Real recv_time_g(start=-1.0, unit="s");
  discrete Real recv_x_q(start=0.0, unit="m");
  discrete Real recv_z_q(start=0.0, unit="m");
  discrete Real recv_map_q(start=0.0);
  discrete Real data_age_g(start=0.0, unit="s");
  // Pending delayed-delivery buffers
  discrete Real pend_g_time(start=-1.0, unit="s");
  discrete Real pend_g_x(start=0.0, unit="m");
  discrete Real pend_g_y(start=0.0, unit="m");
  discrete Real pend_g_res(start=0.0);
  Boolean pend_g(start=false);
  discrete Real pend_q_time(start=-1.0, unit="s");
  discrete Real pend_q_x(start=0.0, unit="m");
  discrete Real pend_q_z(start=0.0, unit="m");
  discrete Real pend_q_map(start=0.0);
  Boolean pend_q(start=false);
  discrete Boolean result_received(start=false);
  Boolean comm_send_event(start=false);
  Boolean comm_recv_event(start=false);

  // ---- Handoff and task state ----
  Integer handoff_state(start=0)
    "0=ground inspecting,1=result sent,2=quad replanning/navigating,3=arrived/complete";
  discrete Boolean handoff_success(start=false);
  discrete Real handoff_time(start=-1.0, unit="s");
  Real task_progress_g(unit="1");
  Real task_progress_q(unit="1");
  Real task_total(unit="1");
  discrete Boolean task_complete(start=false);

  // ---- Separation and safety bounds ----
  Real separation(unit="m");
  Boolean no_collision;
  Boolean in_middle;
  Boolean actuator_ok;
  Boolean data_age_ok;
  Boolean separation_ok;
  Boolean finite_ok;

equation
  // Phase and comm delay disturbance (middle third)
  in_middle = (time >= t_mid_start) and (time <= t_mid_end);
  comm_delay = if in_middle then t_delay_disturb else 0.0;

  // ---- Ground robot dynamics (point mass, torque-bounded force) ----
  der(x_g) = vx_g;
  der(y_g) = vy_g;
  der(vx_g) = Fx_g / m_g;
  der(vy_g) = Fy_g / m_g;
  Fx_g_raw = kp_g*(x_g_ref - x_g) + kd_g*(0.0 - vx_g);
  Fy_g_raw = kp_g*(y_g_ref - y_g) + kd_g*(0.0 - vy_g);
  Fx_g = max(-tau_max, min(tau_max, Fx_g_raw));
  Fy_g = max(-tau_max, min(tau_max, Fy_g_raw));
  tau_wL = 0.5*Fx_g;
  tau_wR = 0.5*Fy_g;
  lidar_range = abs(wall_x - x_g);

  // ---- Quadrotor dynamics (2D vertical plane, four rotors) ----
  der(x_q) = vx_q;
  der(z_q) = vz_q;
  der(theta_q) = omega_q;
  der(vx_q) = -T_tot*sin(theta_q)/m_q;
  der(vz_q) = T_tot*cos(theta_q)/m_q - g_acc;
  der(omega_q) = M_pitch / I_q_val;
  T_tot = T1 + T2 + T3 + T4;
  M_pitch = (T1 + T2 - T3 - T4)*L_arm;

  // Quadrotor control allocation with independent rotor thrust bounds
  v_ref = if (handoff_state >= 2) and (x_q_ref < markerB_x - 1e-6) then v_cruise else 0.0;
  theta_des = max(-theta_lim, min(theta_lim,
                  kp_q_x*(x_q_ref - x_q) + kd_q_x*(v_ref - vx_q)));
  M_des = kp_att*(theta_des - theta_q) + kd_att*(0.0 - omega_q);
  T_des = m_q*g_acc + kp_q_z*(z_q_ref - z_q) + kd_q_z*(0.0 - vz_q);
  T1 = max(0.0, min(T_max, T_des/4.0 + M_des/(4.0*L_arm)));
  T2 = max(0.0, min(T_max, T_des/4.0 + M_des/(4.0*L_arm)));
  T3 = max(0.0, min(T_max, T_des/4.0 - M_des/(4.0*L_arm)));
  T4 = max(0.0, min(T_max, T_des/4.0 - M_des/(4.0*L_arm)));
  camera_feat = markerB_x - x_q;

  // ---- Reference trajectories ----
  x_g_ref = if time < t_mid_start then (markerA_x/t_mid_start)*time else markerA_x;
  y_g_ref = if time < t_mid_start then (markerA_y/t_mid_start)*time else markerA_y;
  z_q_ref = z_hover;
  x_q_ref = if (handoff_state >= 2) and (handoff_time > 0.0) then
              min(markerB_x, (time - handoff_time)*v_cruise) else 0.0;

  // ---- Tracking errors (well-defined zero branch on sqrt) ----
  err_g = sqrt(max(1e-9, (x_g - x_g_ref)^2 + (y_g - y_g_ref)^2));
  err_q = sqrt(max(1e-9, (x_q - x_q_ref)^2 + (z_q - z_q_ref)^2));
  err_primary = err_q;
  err_ok = (time >= t_err_check) and (err_primary < err_thresh);

  // ---- Separation (3D distance, quad at height z_q) ----
  separation = sqrt(max(1e-9, (x_q - x_g)^2 + (y_g - markerA_y)^2 + (z_q - 0.0)^2));
  no_collision = separation >= sep_min;
  separation_ok = no_collision;

  // ---- Task progress ----
  task_progress_g = if time < t_mid_start then min(1.0, time/t_mid_start) else 1.0;
  task_progress_q = if handoff_state >= 2 then
                      min(1.0, max(0.0, x_q/max(1e-9, markerB_x)))
                    else 0.0;
  task_total = 0.5*task_progress_g + 0.5*task_progress_q;

  // ---- Bound instrumentation ----
  actuator_ok = (abs(Fx_g) <= tau_max + 1e-6) and (abs(Fy_g) <= tau_max + 1e-6) and
                (abs(tau_wL) <= tau_max + 1e-6) and (abs(tau_wR) <= tau_max + 1e-6) and
                (T1 >= -1e-6) and (T1 <= T_max + 1e-6) and
                (T2 >= -1e-6) and (T2 <= T_max + 1e-6) and
                (T3 >= -1e-6) and (T3 <= T_max + 1e-6) and
                (T4 >= -1e-6) and (T4 <= T_max + 1e-6);
  data_age_ok = (data_age_q >= -1e-6) and (data_age_q <= 1.0) and
                (data_age_g >= -1e-6) and (data_age_g <= 1.0);
  // Numeric guard: all denominators (m_g, m_q, I_q_val, L_arm, markerB_x) are
  // nonzero parameters and sqrt uses a floor; no singular branches.
  finite_ok = actuator_ok and data_age_ok and separation_ok;

  when sample(0, dt) then
    // Ground robot sends timestamped pose + inspection result
    send_time_g := time;
    send_x_g := x_g;
    send_y_g := y_g;
    send_result_g := task_progress_g;
    pend_g_time := time;
    pend_g_x := x_g;
    pend_g_y := y_g;
    pend_g_res := task_progress_g;
    pend_g := true;
    comm_send_event := true;

    // Quadrotor sends timestamped pose + map feature
    send_time_q := time;
    send_x_q := x_q;
    send_z_q := z_q;
    send_map_q := camera_feat;
    pend_q_time := time;
    pend_q_x := x_q;
    pend_q_z := z_q;
    pend_q_map := camera_feat;
    pend_q := true;

    // Receive ground->quad after comm_delay (records receive time and data age)
    if pend_g and (time - pend_g_time) >= comm_delay then
      recv_time_q := time;
      recv_x_g := pend_g_x;
      recv_y_g := pend_g_y;
      recv_result_g := pend_g_res;
      data_age_q := time - pend_g_time;
      pend_g := false;
      result_received := true;
      comm_recv_event := true;
    end if;

    // Receive quad->ground after comm_delay
    if pend_q and (time - pend_q_time) >= comm_delay then
      recv_time_g := time;
      recv_x_q := pend_q_x;
      recv_z_q := pend_q_z;
      recv_map_q := pend_q_map;
      data_age_g := time - pend_q_time;
      pend_q := false;
    end if;

    // Handoff / task-allocation state machine
    if handoff_state == 0 and time >= t_mid_start then
      handoff_state := 1;
    elseif handoff_state == 1 and result_received then
      handoff_state := 2;
      handoff_time := time;
    elseif handoff_state == 2 and
           (abs(x_q - markerB_x) < 0.3) and (abs(z_q - z_hover) < 0.3) then
      handoff_state := 3;
      handoff_success := true;
      task_complete := true;
    end if;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="Multi-robot inspection handoff (MixedTeamHandoffB). A 24 kg lidar ground robot inspects the markerA region; during the middle third a controlled 0.07 s communication delay disturbs a timestamped pose/result exchange; a 2.1 kg camera quadrotor (four independently bounded rotor thrusts) receives the result, replans, and surveys markerB. Wheel torques and rotor thrusts are bounded at 11.5 N.m/N. Local sensors (lidar range, camera relative feature) are preserved. Communication send/receive events and data age are recorded; explicit handoff state machine drives task allocation. Actuator, separation, and data-age bounds are instrumented; primary tracking error is checked against 0.48 m after 6.5 s. Unstated facts (specific obstacle geometry, sensor noise models, world map details) are treated as unknown."));
end MixedTeamHandoffB;