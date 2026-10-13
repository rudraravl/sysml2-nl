model VacuumToolGraspE
  // ===== Requirement-stated parameters =====
  parameter Real m_cup(unit="kg") = 0.8 "suction cup mass (requirement)";
  parameter Real r_cup(unit="m") = 0.038 "suction cup radius (requirement)";
  parameter Real mu = 0.78 "friction coefficient (requirement)";
  parameter Real e_rest = 0.03 "restitution (requirement); reflected via high contact damping";
  parameter Real F_max(unit="N") = 352.0 "linear actuator command magnitude bound (requirement, N-linear)";
  parameter Real p_min(unit="Pa") = -70000.0 "vacuum gauge lower bound (requirement: -70 kPa)";
  parameter Real p_max(unit="Pa") = 0.0 "vacuum gauge upper bound (requirement: 0 kPa)";
  parameter Real F_dist(unit="N") = 9.6 "tangential disturbance magnitude (requirement)";
  parameter Real f_sample(unit="Hz") = 250.0 "control/sensor rate (requirement)";
  parameter Real T_end(unit="s") = 16.0 "run duration (requirement)";
  parameter Real err_tol(unit="m") = 0.013 "primary tracking error tolerance after 10.4 s (requirement)";
  parameter Real t_err_check(unit="s") = 10.4 "tracking error check time (requirement)";

  // ===== Structural parameters NOT stated in requirement =====
  // Clearly labeled; they do not override any stated requirement value.
  parameter Real m_obj(unit="kg") = 1.0 "object mass // NOT STATED; representative for well-posed dynamics";
  parameter Real h_obj(unit="m") = 0.02 "object height // NOT STATED; representative";
  parameter Real z_start(unit="m") = 0.20 "initial cup height above table // NOT STATED; representative";
  parameter Real k_contact(unit="N/m") = 1.0e5 "cup-object contact stiffness (cup compliance) // NOT STATED; representative";
  parameter Real c_contact(unit="N.s/m") = 400.0 "cup-object contact damping // NOT STATED; representative (restitution 0.03 => highly damped)";
  parameter Real k_table(unit="N/m") = 2.0e5 "table contact stiffness // NOT STATED; rigid table approximated by high stiffness";
  parameter Real c_table(unit="N.s/m") = 100.0 "table contact damping // NOT STATED; representative";
  parameter Real N_setpoint(unit="N") = 15.0 "impedance-phase normal force setpoint // NOT STATED; representative";
  parameter Real tau_vac(unit="s") = 0.15 "vacuum actuator time constant // NOT STATED; representative";
  parameter Real tau_est(unit="s") = 0.04 "estimator filter time constant // NOT STATED; representative";
  parameter Real v_eps(unit="m/s") = 1.0e-3 "friction regularization velocity // NOT STATED; representative";
  parameter Real t_imp_start(unit="s") = 1.0 "impedance motion start // NOT STATED; representative";
  parameter Real t_imp_end(unit="s") = 3.0 "impedance motion end / force regulation start // NOT STATED; representative";
  parameter Real t_vac_start(unit="s") = 3.0 "vacuum engagement start (force-regulation onset) // NOT STATED; representative";
  parameter Real Kp_imp(unit="1/s2") = 400.0 "impedance proportional gain // NOT STATED; representative";
  parameter Real Kd_imp(unit="1/s") = 36.0 "impedance derivative gain // NOT STATED; representative";
  parameter Real Kp_hold = 300.0 "force-regulation position proportional gain // NOT STATED; representative";
  parameter Real Kd_hold(unit="1/s") = 30.0 "force-regulation position derivative gain // NOT STATED; representative";
  parameter Real g(unit="m/s2") = 9.81 "gravity magnitude // standard value";

  // ===== Derived constants =====
  parameter Real A_cup(unit="m2") = Modelica.Constants.pi*r_cup*r_cup "cup effective area";
  parameter Real Ts(unit="s") = 1.0/f_sample "sample period";
  parameter Real t_low(unit="s") = T_end/3.0 "disturbance window start (middle third)";
  parameter Real t_high(unit="s") = 2.0*T_end/3.0 "disturbance window end (middle third)";
  parameter Real z_target(unit="m") = h_obj - N_setpoint/k_contact "target cup position (contact + setpoint compression)";

  // ===== Continuous states =====
  Real z(unit="m", start=z_start) "cup vertical position, up positive, z=0 at table surface";
  Real v(unit="m/s", start=0) "cup vertical velocity, up positive";
  Real y_obj(unit="m", start=0) "object vertical position, up positive, 0 = resting on table";
  Real vy_obj(unit="m/s", start=0) "object vertical velocity, up positive";
  Real x_obj(unit="m", start=0) "object horizontal (tangential) position";
  Real vx_obj(unit="m/s", start=0) "object horizontal velocity";
  Real p_vac(unit="Pa", start=0) "vacuum chamber gauge pressure (0..p_min)";

  // ===== Continuous physical intermediates =====
  Real N_contact(unit="N") "normal contact force cup-object (>=0)";
  Real N_table(unit="N") "normal contact force table-object (>=0)";
  Real F_vac(unit="N") "vacuum holding force magnitude (>=0)";
  Real F_vac_eff(unit="N") "vacuum force effective (gated by contact)";
  Real F_friction_cup(unit="N") "friction from cup on object (opposes object motion)";
  Real F_friction_table(unit="N") "friction from table on object";
  Real F_disturbance(unit="N") "applied tangential disturbance";
  Real N_grip(unit="N") "total grip normal at cup-object interface";
  Real penetration_cup(unit="m") "cup-object penetration (>=0)";
  Real pen_table(unit="m") "object-table penetration (>=0)";
  Real in_contact "contact indicator (0..1, continuous/smoothed)";
  Real F_lin(unit="N") "bounded linear actuator force applied (up positive)";
  Real p_cmd(unit="Pa") "vacuum pressure command applied";

  // ===== Reference =====
  Real z_ref(unit="m") "reference cup position";
  Real v_ref(unit="m/s") "reference cup velocity";
  Real a_ref(unit="m/s2") "reference cup acceleration";
  Real alpha "motion blend 0..1";
  Real alpha_dot "d alpha/dt";
  Real alpha_ddot "d2 alpha/dt2";
  Real dist_win "disturbance window 0..1 (smooth)";
  Real tracking_error(unit="m") "primary tracking error (z - z_ref)";

  // ===== Discrete sampled controller / sensors / estimator / traces =====
  discrete Real F_lin_cmd_zoh(start=0) "sampled linear actuator command (ZOH)";
  discrete Real p_cmd_zoh(start=0) "sampled vacuum command (ZOH)";
  discrete Real z_sensor(start=z_start) "sampled cup position sensor";
  discrete Real v_sensor(start=0) "sampled cup velocity sensor";
  discrete Real N_sensor(start=0) "sampled normal contact force sensor";
  discrete Real x_sensor(start=0) "sampled object horizontal position sensor";
  discrete Real p_vac_sensor(start=0) "sampled vacuum pressure sensor";
  discrete Real N_est(start=0) "estimated normal contact force (filtered estimator state)";
  discrete Real z_est(start=z_start) "estimated cup position (filtered estimator state)";

  // Synchronized state/command/sensor traces at 250 Hz
  discrete Real t_trace(start=0) "trace timestamp";
  discrete Real z_trace(start=z_start);
  discrete Real v_trace(start=0);
  discrete Real F_lin_trace(start=0);
  discrete Real p_vac_trace(start=0);
  discrete Real N_contact_trace(start=0);
  discrete Real x_obj_trace(start=0);
  discrete Real y_obj_trace(start=0);
  discrete Boolean accept_trace(start=true);

  // ===== Acceptance / fail-closed =====
  discrete Boolean fail_closed(start=false) "latched fail-closed fault";
  Boolean bounds_ok "travel and effort bounds satisfied";
  Boolean stable_contact "stable contact flag";
  Boolean bounded_displacement "bounded object displacement flag";
  Boolean no_grasp_loss "no grasp loss flag";
  Boolean no_nan "no NaN/infinite physical, control, or estimator values flag";
  Boolean tracking_ok "primary tracking error within tolerance after 10.4 s";
  Boolean accept "overall acceptance (fail-closed)";

equation
  // ---- Reference trajectory (smooth cosine blend over impedance window) ----
  alpha = if time <= t_imp_start then 0.0
          elseif time >= t_imp_end then 1.0
          else 0.5*(1.0 - cos(Modelica.Constants.pi*(time - t_imp_start)/(t_imp_end - t_imp_start)));
  alpha_dot = if time <= t_imp_start then 0.0
              elseif time >= t_imp_end then 0.0
              else 0.5*Modelica.Constants.pi/(t_imp_end - t_imp_start)*sin(Modelica.Constants.pi*(time - t_imp_start)/(t_imp_end - t_imp_start));
  alpha_ddot = if time <= t_imp_start then 0.0
               elseif time >= t_imp_end then 0.0
               else 0.5*Modelica.Constants.pi*Modelica.Constants.pi/((t_imp_end - t_imp_start)*(t_imp_end - t_imp_start))*cos(Modelica.Constants.pi*(time - t_imp_start)/(t_imp_end - t_imp_start));
  z_ref = z_start + (z_target - z_start)*alpha;
  v_ref = (z_target - z_start)*alpha_dot;
  a_ref = (z_target - z_start)*alpha_ddot;

  // ---- Disturbance window (middle third, smooth 0.2 s edges) ----
  dist_win = if time <= t_low - 0.2 then 0.0
             elseif time <= t_low + 0.2 then 0.5*(1.0 - cos(Modelica.Constants.pi*(time - (t_low - 0.2))/0.4))
             elseif time <= t_high - 0.2 then 1.0
             elseif time <= t_high + 0.2 then 0.5*(1.0 + cos(Modelica.Constants.pi*(time - (t_high - 0.2))/0.4))
             else 0.0;

  // ---- Contact kinematics ----
  penetration_cup = max(0.0, (y_obj + h_obj) - z);
  pen_table = max(0.0, -y_obj);

  // ---- Normal forces (spring-damper; low restitution via high damping) ----
  N_contact = max(0.0, k_contact*penetration_cup + c_contact*max(0.0, vy_obj - v));
  N_table = max(0.0, k_table*pen_table + c_table*max(0.0, -vy_obj));

  // ---- Vacuum holding force (gated by contact, no division by zero) ----
  F_vac = (-p_vac)*A_cup;
  in_contact = tanh(max(0.0, penetration_cup)/1.0e-4);
  F_vac_eff = F_vac*in_contact;

  // ---- Cup vertical dynamics (up positive) ----
  // Forces: F_lin up, gravity down, N_contact up (object on cup), vacuum pulls cup down.
  der(z) = v;
  der(v) = (F_lin - m_cup*g + N_contact - F_vac_eff)/m_cup;

  // ---- Object vertical dynamics (up positive) ----
  // Forces: vacuum up, N_contact down, gravity down, table normal up.
  der(y_obj) = vy_obj;
  der(vy_obj) = (F_vac_eff - N_contact - m_obj*g + N_table)/m_obj;

  // ---- Object horizontal (tangential) dynamics ----
  N_grip = N_contact + F_vac_eff;
  F_friction_cup = mu*N_grip*tanh(vx_obj/v_eps);
  F_friction_table = mu*N_table*tanh(vx_obj/v_eps);
  F_disturbance = F_dist*dist_win;
  der(x_obj) = vx_obj;
  der(vx_obj) = (F_disturbance - F_friction_cup - F_friction_table)/m_obj;

  // ---- Vacuum actuator (first-order pressure dynamics) ----
  der(p_vac) = (p_cmd - p_vac)/tau_vac;

  // ---- Bounded commands applied to plant ----
  F_lin = max(-F_max, min(F_max, F_lin_cmd_zoh));
  p_cmd = p_cmd_zoh;

  // ---- Primary tracking error ----
  tracking_error = z - z_ref;

  // ---- Acceptance flags (fail-closed) ----
  bounds_ok = (z <= z_start + 0.01) and (z >= -0.05) and (abs(F_lin) <= F_max + 1.0e-3) and (abs(p_vac) <= abs(p_min) + 1.0);
  stable_contact = (time < t_imp_end) or (N_contact > 0.05);
  bounded_displacement = abs(x_obj) <= 0.05;
  no_grasp_loss = (time < t_vac_start + 1.0) or (F_vac_eff > 1.0 and N_grip > 0.0);
  tracking_ok = (time < t_err_check) or (abs(tracking_error) < err_tol);
  no_nan = (z == z) and (v == v) and (x_obj == x_obj) and (vx_obj == vx_obj) and (p_vac == p_vac) and (F_lin == F_lin) and (N_contact == N_contact) and (y_obj == y_obj) and (N_est == N_est);
  accept = bounds_ok and stable_contact and bounded_displacement and no_grasp_loss and tracking_ok and no_nan;

  // ---- Sampled controller, sensors, estimator, traces, fail-closed latch (250 Hz) ----
  when sample(0, Ts) then
    // Sensor sampling (synchronized)
    z_sensor := z;
    v_sensor := v;
    N_sensor := N_contact;
    x_sensor := x_obj;
    p_vac_sensor := p_vac;

    // Estimator (first-order filters)
    N_est := N_est + (Ts/tau_est)*(N_contact - N_est);
    z_est := z_est + (Ts/tau_est)*(z - z_est);

    // Fail-closed latch
    if not accept then
      fail_closed := true;
    end if;

    // Command generation: impedance motion then force regulation; bounded
    if fail_closed then
      // Fail-closed: zero linear command, release vacuum to 0 gauge
      F_lin_cmd_zoh := 0.0;
      p_cmd_zoh := p_max;
    elseif time < t_imp_end then
      // Impedance motion with gravity compensation
      F_lin_cmd_zoh := max(-F_max, min(F_max, m_cup*a_ref + Kd_imp*(v_ref - v_sensor) + Kp_imp*(z_ref - z_sensor) + m_cup*g));
      p_cmd_zoh := p_max;
    else
      // Force regulation: hold position with contact/vacuum feedforward
      F_lin_cmd_zoh := max(-F_max, min(F_max, m_cup*g + ((-p_vac_sensor)*A_cup*in_contact - N_sensor) + Kp_hold*(z_target - z_sensor) + Kd_hold*(0.0 - v_sensor)));
      // Vacuum engaged once in contact during force regulation
      if z_sensor <= h_obj + 0.005 then
        p_cmd_zoh := p_min;
      else
        p_cmd_zoh := p_max;
      end if;
    end if;

    // Synchronized traces (state, command, sensor)
    t_trace := time;
    z_trace := z;
    v_trace := v;
    F_lin_trace := F_lin;
    p_vac_trace := p_vac;
    N_contact_trace := N_contact;
    x_obj_trace := x_obj;
    y_obj_trace := y_obj;
    accept_trace := accept;
  end when;

  annotation (
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="VacuumToolGraspE: contact-rich vacuum grasp scenario. A vertical prismatic carriage carries a 0.8 kg compliant suction cup (r=0.038 m) with vacuum pressure command 0..-70 kPa gauge. Linear and vacuum actuators are bounded (352 N-linear). A rigid support table uses friction 0.78 and restitution 0.03 (collision enabled via spring-damper contact). Control applies impedance motion followed by force regulation; a 9.6 N tangential load disturbance is applied over the middle third. The 250 Hz sampled controller records synchronized state, command, and sensor traces for 16 s. Acceptance is fail-closed: travel and effort bounds, stable contact, bounded object displacement, no grasp loss, primary tracking error below 0.013 m after 10.4 s, and no NaN/infinite physical, control, or estimator values. Parameters not stated in the requirement are labeled NOT STATED and set to representative values for well-posed, compilable dynamics.")
  );
end VacuumToolGraspE;