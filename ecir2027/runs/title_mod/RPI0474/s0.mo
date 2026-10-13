model VacuumToolPushF
  "Contact-rich manipulation scenario: a vertical-prismatic carriage carrying a
   compliant suction cup regulates normal pushing force while a linear actuator
   moves a rigid box along a two-segment planar reference on a rigid table.
   Hybrid position-force control is used. An 8.7 N friction-change disturbance
   is applied during the middle third of the 20 s mission."

  // ---- Timing ----
  parameter Real f_sample = 500 "Operating/control sample rate Hz";
  parameter Real T_end = 20 "Mission duration s";

  // ---- Embodiment: suction cup ----
  parameter Real m_cup = 0.8 "Suction cup mass kg";
  parameter Real r_cup = 0.038 "Suction cup radius m";
  parameter Real A_cup = Modelica.Constants.pi * r_cup * r_cup "Cup area m^2";
  // Cup compliance is unspecified by the requirement; values assumed for simulation.
  parameter Real k_cup = 2000 "Cup axial stiffness N/m (assumed)";
  parameter Real b_cup = 40 "Cup axial damping Ns/m (assumed)";

  // ---- Box (mass/inertia/geometry unspecified; assumed for simulation) ----
  parameter Real m_box = 0.8 "Box mass kg (assumed)";
  parameter Real I_box = 0.010 "Box yaw inertia kg.m^2 (assumed)";
  parameter Real e_offset = 0.008 "Tool contact yaw-arm offset m (assumed)";
  parameter Real c_yaw = 0.05 "Box yaw viscous damping N.m.s/rad (assumed)";

  // ---- Environment / friction ----
  parameter Real mu_table_box = 0.42 "Box-table friction coefficient";
  parameter Real mu_tool_box = 0.65 "Tool-box friction coefficient";
  parameter Real g = 9.81 "Gravity m/s^2";
  parameter Real v_thresh = 0.01 "Friction velocity smoothing threshold m/s";

  // ---- Actuator bounds ----
  parameter Real F_lin_max = 390 "Linear actuator force bound N";
  parameter Real P_min = -70000 "Vacuum lower bound Pa gauge";
  parameter Real P_max = 0 "Vacuum upper bound Pa gauge";

  // ---- Two-segment planar reference (positions/times assumed) ----
  parameter Real x_seg1 = 0.30 "End of segment 1 x m";
  parameter Real x_seg2 = 0.60 "End of segment 2 x m";
  parameter Real t_seg1 = 6.67 "End of segment 1 s";
  parameter Real t_seg2 = 13.33 "End of segment 2 s";

  // ---- Control target ----
  parameter Real N_ref = 22.0 "Desired normal contact force N";

  // ---- Disturbance: 8.7 N friction change during middle third ----
  parameter Real F_dist = 8.7 "Friction-change disturbance magnitude N";
  parameter Real t_dist_start = T_end / 3 "Disturbance start s";
  parameter Real t_dist_end = 2 * T_end / 3 "Disturbance end s";

  // ---- Controller gains (assumed) ----
  parameter Real Kp_pos = 700.0 "Position-loop proportional gain";
  parameter Real Kd_pos = 70.0 "Position-loop derivative gain";
  parameter Real Kp_force = 400.0 "Force-loop proportional gain";
  parameter Real Ki_force = 30.0 "Force-loop integral gain";
  parameter Real P_bias = N_ref / A_cup "Nominal vacuum magnitude for N_ref Pa";

  // ---- Dynamic states ----
  Real x_box(start = 0.0) "Box x position m (object planar pose)";
  Real v_box(start = 0.0) "Box x velocity m/s";
  Real theta(start = 0.0) "Box yaw rad (object planar pose)";
  Real omega(start = 0.0) "Box yaw rate rad/s";
  Real z_cup(start = N_ref / k_cup) "Cup axial compression m";
  Real v_cup(start = 0.0) "Cup compression rate m/s";
  Real p_int(start = 0.0) "Force-loop integrator state";

  // ---- Actuator commands and applied values ----
  Real F_lin_cmd "Linear actuator command N";
  Real F_lin "Applied linear actuator force N (bounded)";
  Real P_cmd "Vacuum pressure command Pa gauge";
  Real P_app "Applied vacuum pressure Pa gauge (bounded)";

  // ---- Internal forces / sensor channels ----
  Real N_contact "Normal contact force N (sensor)";
  Real F_vacuum "Vacuum-generated force on cup N";
  Real F_push_limit "Friction-limited push magnitude N";
  Real F_push "Tool-to-box push force N (friction-limited)";
  Real F_friction "Box-table Coulomb friction N";
  Real F_disturb "Disturbance friction N";
  Real tau_push "Yaw torque on box N.m";

  // ---- Reference trajectory ----
  Real x_ref "Reference planar position m";
  Real v_ref "Reference planar velocity m/s";

  // ---- Verification observables ----
  Real tracking_error "Position tracking error m";
  Boolean actuator_saturated "True if linear actuator at bound";
  Boolean force_in_band "True if 5 N <= N_contact <= 25 N";
  Boolean tracking_ok "True if |tracking_error| < 0.032 m for t >= 13 s";

equation
  // ---- Two-segment planar reference (continuous ramp, then hold) ----
  if time <= t_seg1 then
    x_ref = x_seg1 * time / t_seg1;
    v_ref = x_seg1 / t_seg1;
  elseif time <= t_seg2 then
    x_ref = x_seg1 + (x_seg2 - x_seg1) * (time - t_seg1) / (t_seg2 - t_seg1);
    v_ref = (x_seg2 - x_seg1) / (t_seg2 - t_seg1);
  else
    x_ref = x_seg2;
    v_ref = 0.0;
  end if;

  // ---- Cup axial dynamics (vertical, force channel) ----
  // Smooth positive-part of spring+damper force; the +0.04 term gives a
  // well-defined, non-singular zero branch so N_contact is always finite.
  N_contact = 0.5 * ((k_cup * z_cup + b_cup * v_cup) +
                     sqrt((k_cup * z_cup + b_cup * v_cup) ^ 2 + 0.04));
  F_vacuum = -P_app * A_cup;
  der(z_cup) = v_cup;
  m_cup * der(v_cup) = F_vacuum - N_contact;

  // ---- Force control: regulate N_contact to N_ref via vacuum pressure ----
  der(p_int) = N_ref - N_contact;
  P_cmd = -(P_bias + Kp_force * (N_ref - N_contact) + Ki_force * p_int);
  P_app = max(P_min, min(P_max, P_cmd));

  // ---- Position control: linear actuator tracks x_ref ----
  tracking_error = x_ref - x_box;
  F_lin_cmd = Kp_pos * tracking_error + Kd_pos * (v_ref - v_box);
  F_lin = max(-F_lin_max, min(F_lin_max, F_lin_cmd));

  // ---- Tool-to-box push transmission (Coulomb friction limited) ----
  F_push_limit = mu_tool_box * N_contact;
  F_push = max(-F_push_limit, min(F_push_limit, F_lin));

  // ---- Box-table friction (smooth Coulomb) ----
  F_friction = mu_table_box * m_box * g * tanh(v_box / v_thresh);

  // ---- Disturbance: 8.7 N friction change opposing motion in middle third ----
  if time > t_dist_start and time < t_dist_end then
    F_disturb = F_dist * tanh(v_box / v_thresh);
  else
    F_disturb = 0.0;
  end if;

  // ---- Box planar dynamics ----
  der(x_box) = v_box;
  m_box * der(v_box) = F_push - F_friction - F_disturb;

  // ---- Box yaw dynamics (push at small offset yields yaw torque) ----
  tau_push = F_push * e_offset;
  der(theta) = omega;
  I_box * der(omega) = tau_push - c_yaw * omega;

  // ---- Verification flags ----
  actuator_saturated = abs(F_lin) >= F_lin_max - 1.0;
  force_in_band = (N_contact >= 5.0) and (N_contact <= 25.0);
  tracking_ok = if time >= 13.0 then abs(tracking_error) < 0.032 else true;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-4, Interval = 0.002),
    Documentation(info = "State (x_box,v_box,theta,omega,z_cup,v_cup), command (F_lin,P_app), and sensor (N_contact,F_push,F_friction,F_disturb,tracking_error) traces are retained and synchronized at 500 Hz (Interval = 0.002 s). No NaN/Inf expected: all divisors (A_cup, v_thresh) are non-zero and the normal-force positive-part uses a regularized sqrt branch."));
end VacuumToolPushF;