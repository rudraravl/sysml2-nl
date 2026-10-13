model VacuumToolGraspE
  "Vacuum tool grasp system with contact-rich manipulation, impedance and force regulation"
  
  // Parameters specified in requirement
  parameter Real m_cup = 0.8 "Compliant suction cup mass [kg]";
  parameter Real r_cup = 0.038 "Cup radius [m]";
  parameter Real p_vac_max = 70000 "Max vacuum pressure magnitude [Pa] (0 to -70 kPa gauge)";
  parameter Real F_max = 352 "Linear actuator command magnitude bound [N]";
  parameter Real mu = 0.78 "Friction coefficient";
  parameter Real e = 0.03 "Restitution coefficient";
  parameter Real f_load = 9.6 "Tangential disturbance load [N]";
  parameter Real t_end = 16 "Simulation duration [s]";
  parameter Real dt = 1/250 "Sample rate [s] (250 Hz)";

  // Unspecified parameters (nominal values used to enable standalone simulation)
  parameter Real m_obj = 1.0 "Object mass [kg] (not specified in requirement, nominal value used for simulation)";
  parameter Real m_tip = 1e-3 "Cup tip mass [kg] (not specified, small nominal value used)";
  parameter Real h_obj = 0.02 "Object height [m] (not specified, nominal value used)";
  parameter Real k_contact = 1e5 "Contact stiffness [N/m] (not specified, nominal value used)";
  parameter Real d_contact = 100 "Contact damping [N.s/m] (not specified, nominal value used)";
  parameter Real k_table = 1e5 "Table stiffness [N/m] (not specified, nominal value used)";
  parameter Real d_table = 100 "Table damping [N.s/m] (not specified, nominal value used)";
  parameter Real k_cup = 1e4 "Cup compliance stiffness [N/m] (not specified, nominal value used)";
  parameter Real d_cup = 50 "Cup compliance damping [N.s/m] (not specified, nominal value used)";
  parameter Real K_imp = 1000 "Impedance proportional gain [N/m] (not specified, nominal value used)";
  parameter Real D_imp = 50 "Impedance derivative gain [N.s/m] (not specified, nominal value used)";
  parameter Real y_ref_start = 0.1 "Initial reference position [m] (not specified, nominal value used)";
  parameter Real y_ref_end = 0.02 "Final reference position [m] (not specified, nominal value used)";
  parameter Real t_contact = 4.0 "Time to establish contact [s] (not specified, nominal value used)";

  // Constants
  constant Real g = 9.81 "Gravity [m/s^2]";
  constant Real pi = 3.141592653589793;
  parameter Real Area = pi * r_cup * r_cup "Cup area [m^2]";

  // Physical States
  Real y_cup(start=0.1) "Cup vertical position [m]";
  Real v_cup(start=0) "Cup vertical velocity [m/s]";
  Real y_tip(start=0.1) "Cup tip vertical position [m]";
  Real v_tip(start=0) "Cup tip vertical velocity [m/s]";
  Real y_obj(start=0.02) "Object vertical position [m]";
  Real v_obj(start=0) "Object vertical velocity [m/s]";
  Real x_obj(start=0) "Object horizontal position [m]";
  Real vx_obj(start=0) "Object horizontal velocity [m/s]";

  // Controller and Actuator Variables
  discrete Real y_ref(start=0.1) "Reference position [m]";
  discrete Real v_ref(start=0) "Reference velocity [m/s]";
  discrete Real p_vac_cmd(start=0) "Vacuum pressure command [Pa]";
  Real F_lin_cmd "Linear actuator command [N]";
  Real F_lin_act "Linear actuator actual force [N]";
  Real p_vac "Actual vacuum pressure [Pa]";

  // Forces
  Real F_spring_cup "Cup compliance spring force [N]";
  Real F_c "Contact spring force [N]";
  Real F_v "Vacuum attractive force [N]";
  Real F_t "Table normal force [N]";
  Real N "Normal force between cup and object [N]";
  Real F_fric "Friction force [N]";
  Real F_load "Tangential load [N]";

  // Acceptance Criteria
  Boolean travel_ok "Travel bounds satisfied";
  Boolean effort_ok "Effort bounds satisfied";
  Boolean contact_ok "Stable contact established";
  Boolean disp_ok "Bounded object displacement";
  Boolean grasp_ok "No grasp loss";
  Boolean error_ok "Primary tracking error below 0.013 m after 10.4 s";
  Boolean fail_closed "Fail-closed acceptance";
  Real err_track "Primary tracking error [m]";

equation
  // Vertical dynamics of cup and tip
  der(y_cup) = v_cup;
  der(v_cup) = (F_lin_act - m_cup * g - F_spring_cup) / m_cup;
  der(y_tip) = v_tip;
  der(v_tip) = (F_spring_cup + F_c - F_v) / m_tip;

  // Object vertical dynamics
  der(y_obj) = v_obj;
  der(v_obj) = (F_v - F_c - m_obj * g + F_t) / m_obj;

  // Object horizontal dynamics
  der(x_obj) = vx_obj;
  der(vx_obj) = (F_load - F_fric) / m_obj;

  // Cup compliance force
  F_spring_cup = k_cup * (y_cup - y_tip) + d_cup * (v_cup - v_tip);

  // Contact between cup tip and object
  F_c = if (y_obj - y_tip) > 0 then k_contact * (y_obj - y_tip) + d_contact * (v_obj - v_tip) else 0;

  // Vacuum force (attractive, p_vac is negative gauge pressure)
  F_v = -p_vac * Area;

  // Table contact force (rigid support table)
  F_t = if (h_obj - y_obj) > 0 then k_table * (h_obj - y_obj) - d_table * v_obj else 0;

  // Normal force and friction
  N = F_c + F_v;
  F_fric = mu * N * tanh(vx_obj / 0.01);

  // Tangential load disturbance (middle third of 16 s)
  F_load = if (time >= t_end/3 and time <= 2*t_end/3) then f_load else 0;

  // Discrete controller at 250 Hz
  when sample(0, dt) then
    // Impedance motion phase
    if time < t_contact then
      y_ref := y_ref_start + (y_ref_end - y_ref_start) * time / t_contact;
      v_ref := (y_ref_end - y_ref_start) / t_contact;
    else
      y_ref := y_ref_end;
      v_ref := 0;
    end if;

    // Force regulation phase (vacuum command)
    if time > t_contact then
      p_vac_cmd := -p_vac_max * min(1.0, (time - t_contact) / 1.0);
    else
      p_vac_cmd := 0;
    end if;
  end when;

  // Impedance control law with gravity feedforward
  F_lin_cmd = K_imp * (y_ref - y_cup) + D_imp * (v_ref - v_cup) + m_cup * g;

  // Bounded actuators
  F_lin_act = max(-F_max, min(F_max, F_lin_cmd));
  p_vac = max(-p_vac_max, min(0, p_vac_cmd));

  // Acceptance criteria
  err_track = abs(y_ref - y_cup);
  travel_ok = y_cup >= 0 and y_cup <= 0.2;
  effort_ok = abs(F_lin_act) <= F_max;
  contact_ok = F_c > 0 or time < t_contact;
  disp_ok = abs(x_obj) <= 0.013;
  grasp_ok = F_v > 0 or time < t_contact;
  error_ok = err_track < 0.013 or time < 10.4;
  fail_closed = travel_ok and effort_ok and contact_ok and disp_ok and grasp_ok and error_ok;

  // NaN and infinite checks
  assert(not Modelica.Math.isNaN(y_cup) and not Modelica.Math.isNaN(y_obj) and not Modelica.Math.isNaN(x_obj), "NaN detected in physical states");
  assert(abs(y_cup) < 1e6 and abs(y_obj) < 1e6 and abs(x_obj) < 1e6, "Infinite values detected in physical states");

end VacuumToolGraspE;