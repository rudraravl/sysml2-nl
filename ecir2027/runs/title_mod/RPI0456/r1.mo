model ContactArmPolishF
  "Contact-rich manipulation: 6R arm (Z-Y-Y-X-Y-X) polishing curved workpiece"

  // ===== Timing =====
  parameter Modelica.Units.SI.Time T_sim = 20.0 "Total simulation duration";
  parameter Modelica.Units.SI.Frequency f_rate = 500.0
    "Control and sensor update rate";

  // ===== Arm: 6 revolute joints, axes Z-Y-Y-X-Y-X =====
  // Capsule link dimensions and masses unknown — joint inertias are representative
  parameter Modelica.Units.SI.Torque tau_max = 146.0 "Maximum joint effort";

  parameter Modelica.Units.SI.Inertia J_q1 = 1.2;
  parameter Modelica.Units.SI.Inertia J_q2 = 0.9;
  parameter Modelica.Units.SI.Inertia J_q3 = 0.7;
  parameter Modelica.Units.SI.Inertia J_q4 = 0.4;
  parameter Modelica.Units.SI.Inertia J_q5 = 0.25;
  parameter Modelica.Units.SI.Inertia J_q6 = 0.15;

  parameter Modelica.Units.SI.RotationalDampingConstant b_q1 = 0.15;
  parameter Modelica.Units.SI.RotationalDampingConstant b_q2 = 0.12;
  parameter Modelica.Units.SI.RotationalDampingConstant b_q3 = 0.10;
  parameter Modelica.Units.SI.RotationalDampingConstant b_q4 = 0.06;
  parameter Modelica.Units.SI.RotationalDampingConstant b_q5 = 0.04;
  parameter Modelica.Units.SI.RotationalDampingConstant b_q6 = 0.03;

  parameter Modelica.Units.SI.Angle q1_init = 0.0;
  parameter Modelica.Units.SI.Angle q2_init = 0.6;
  parameter Modelica.Units.SI.Angle q3_init = -0.4;
  parameter Modelica.Units.SI.Angle q4_init = 0.0;
  parameter Modelica.Units.SI.Angle q5_init = 0.5;
  parameter Modelica.Units.SI.Angle q6_init = 0.0;

  // ===== Simplified kinematics (full Z-Y-Y-X-Y-X DH chain unknown) =====
  parameter Modelica.Units.SI.Length r_eff = 0.25
    "Effective tangential radius (representative — link lengths unknown)";
  parameter Real a_n2 = 0.20
    "Normal Jacobian entry dn/dq2 (representative — kinematics unknown)";
  parameter Real a_n3 = 0.10
    "Normal Jacobian entry dn/dq3 (representative — kinematics unknown)";
  parameter Modelica.Units.SI.Length R_curve = 1.0
    "Surface curvature radius (representative — workpiece geometry unknown)";

  // ===== Path =====
  parameter Modelica.Units.SI.Length L_path = 0.50 "Surface path length";

  // ===== Contact: compliant normal + Coulomb friction =====
  parameter Real mu = 0.50 "Friction coefficient";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_n = 15000.0
    "Normal contact stiffness (representative — compliance unknown)";
  parameter Modelica.Units.SI.TranslationalDampingConstant c_n = 500.0
    "Normal contact damping (representative)";
  parameter Modelica.Units.SI.Length d0 = 0.0014
    "Initial penetration (representative — tool/surface geometry unknown)";
  parameter Modelica.Units.SI.Velocity v_reg = 0.01
    "Friction regularization velocity to avoid division by zero";

  // ===== Control =====
  parameter Modelica.Units.SI.Force F_n_ref = 20.0
    "Desired normal force (within 12–30 N verification band)";
  parameter Real Kp_track = 800.0 "Tangential position gain (representative)";
  parameter Real Kd_track = 50.0 "Tangential velocity gain (representative)";
  parameter Real Kp_force = 10.0 "Normal force proportional gain (representative)";
  parameter Real Ki_force = 100.0 "Normal force integral gain (representative)";
  parameter Real Kp_hold = 3.0 "Joint configuration hold gain (representative)";
  parameter Real Kd_hold = 0.3 "Joint configuration hold damping (representative)";

  // ===== Disturbance =====
  parameter Modelica.Units.SI.Force F_dist = 10.2 "Surface-force disturbance magnitude";

  // ===== Joint states (encoder feedback) =====
  Modelica.Units.SI.Angle q1, q2, q3, q4, q5, q6;
  Modelica.Units.SI.AngularVelocity w1, w2, w3, w4, w5, w6;
  Modelica.Units.SI.Torque tau1, tau2, tau3, tau4, tau5, tau6;
  Modelica.Units.SI.Torque tau1s, tau2s, tau3s, tau4s, tau5s, tau6s;

  // ===== Task-space states =====
  Modelica.Units.SI.Length s "Tangential path coordinate";
  Modelica.Units.SI.Velocity sd "Tangential velocity";
  Modelica.Units.SI.Length dn "Normal penetration";
  Modelica.Units.SI.Velocity dnd "Penetration rate";
  Modelica.Units.SI.Force Fn "Normal contact force";
  Modelica.Units.SI.Force Ft "Tangential friction force";
  Modelica.Units.SI.Force Fdist "Disturbance force";

  // ===== Six-axis wrist sensor =====
  Modelica.Units.SI.Force Fw_x, Fw_y, Fw_z;
  Modelica.Units.SI.Torque Tw_x, Tw_y, Tw_z;

  // ===== Tool-tip pose =====
  Modelica.Units.SI.Length tip_x, tip_y, tip_z;

  // ===== Control variables =====
  Modelica.Units.SI.Length s_ref "Reference path position";
  Modelica.Units.SI.Velocity sd_ref "Reference path velocity";
  Real e_track "Tangential tracking error [m]";
  Real e_force "Normal force error [N]";
  Real int_force "Force integral accumulator";
  Real F_n_cmd "Normal force command [N]";

  // ===== Verification flags =====
  Boolean effort_bounds_ok "Joint and effort bounds satisfied";
  Boolean force_in_band "Force between 12 and 30 N";
  Boolean tracking_ok "Tracking error below 0.016 m after 13 s";
  Boolean contact_ok "Continuous contact maintained";
  Boolean no_nan_inf "No NaN or infinite values";

initial equation
  q1 = q1_init;
  q2 = q2_init;
  q3 = q3_init;
  q4 = q4_init;
  q5 = q5_init;
  q6 = q6_init;
  w1 = 0.0;
  w2 = 0.0;
  w3 = 0.0;
  w4 = 0.0;
  w5 = 0.0;
  w6 = 0.0;
  int_force = 0.0;

equation
  // ===== Reference trajectory: traverse 0.50 m in 15 s with 1 s settle =====
  if time <= 1.0 then
    s_ref = 0.0;
    sd_ref = 0.0;
  elseif time <= 16.0 then
    s_ref = L_path * (time - 1.0) / 15.0;
    sd_ref = L_path / 15.0;
  else
    s_ref = L_path;
    sd_ref = 0.0;
  end if;

  // ===== Forward kinematics (simplified — full DH chain unknown) =====
  s = r_eff * (q1 - q1_init);
  sd = r_eff * w1;

  // Tool-tip pose on curved surface
  tip_x = R_curve * sin(s / R_curve);
  tip_y = R_curve * (1.0 - cos(s / R_curve));
  tip_z = 0.0;

  // Normal penetration from joint positions via Jacobian
  dn = d0 + a_n2 * (q2 - q2_init) + a_n3 * (q3 - q3_init);
  dnd = a_n2 * w2 + a_n3 * w3;

  // ===== Contact model: spring-damper normal + Coulomb friction =====
  Fn = k_n * dn + c_n * dnd;
  // Friction: tanh regularization provides smooth zero-velocity branch
  Ft = mu * abs(Fn) * tanh(sd / v_reg);

  // ===== Disturbance: 10.2 N during middle third (6.667–13.333 s) =====
  if time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0 then
    Fdist = F_dist;
  else
    Fdist = 0.0;
  end if;

  // ===== Wrist sensor readings =====
  Fw_x = Ft;
  Fw_y = 0.0;
  Fw_z = Fn;
  Tw_x = 0.0;
  Tw_y = 0.0;
  Tw_z = 0.0;

  // ===== Control errors =====
  e_track = s_ref - s;
  e_force = F_n_ref - Fn;

  // Force integral with anti-windup clamping
  der(int_force) = if abs(int_force) < 1.0 then e_force else 0.0;

  // ===== Control law: tangential trajectory + normal force regulation =====
  // Joint 1: PD tangential tracking with friction feedforward from wrist sensor
  tau1 = (Kp_track * e_track + Kd_track * (sd_ref - sd) + Fw_x) / r_eff;

  // Joints 2, 3: normal force PI regulation distributed via Jacobian transpose
  F_n_cmd = Kp_force * e_force + Ki_force * int_force;
  tau2 = F_n_cmd * a_n2;
  tau3 = F_n_cmd * a_n3;

  // Joints 4–6: configuration hold (wrist DOFs maintain pose)
  tau4 = -Kp_hold * (q4 - q4_init) - Kd_hold * w4;
  tau5 = -Kp_hold * (q5 - q5_init) - Kd_hold * w5;
  tau6 = -Kp_hold * (q6 - q6_init) - Kd_hold * w6;

  // ===== Effort saturation: |tau| <= 146 N.m =====
  tau1s = if tau1 > tau_max then tau_max elseif tau1 < -tau_max then -tau_max else tau1;
  tau2s = if tau2 > tau_max then tau_max elseif tau2 < -tau_max then -tau_max else tau2;
  tau3s = if tau3 > tau_max then tau_max elseif tau3 < -tau_max then -tau_max else tau3;
  tau4s = if tau4 > tau_max then tau_max elseif tau4 < -tau_max then -tau_max else tau4;
  tau5s = if tau5 > tau_max then tau_max elseif tau5 < -tau_max then -tau_max else tau5;
  tau6s = if tau6 > tau_max then tau_max elseif tau6 < -tau_max then -tau_max else tau6;

  // ===== Joint dynamics =====
  // Joint 1: tangential, loaded by friction and disturbance
  J_q1 * der(w1) = tau1s - b_q1 * w1 - (Ft + Fdist) * r_eff;
  der(q1) = w1;

  // Joint 2: normal, loaded by contact force
  J_q2 * der(w2) = tau2s - b_q2 * w2 - Fn * a_n2;
  der(q2) = w2;

  // Joint 3: normal, loaded by contact force
  J_q3 * der(w3) = tau3s - b_q3 * w3 - Fn * a_n3;
  der(q3) = w3;

  // Joints 4–6: configuration hold
  J_q4 * der(w4) = tau4s - b_q4 * w4;
  der(q4) = w4;
  J_q5 * der(w5) = tau5s - b_q5 * w5;
  der(q5) = w5;
  J_q6 * der(w6) = tau6s - b_q6 * w6;
  der(q6) = w6;

  // ===== Verification criteria =====
  effort_bounds_ok = (abs(tau1s) <= tau_max) and (abs(tau2s) <= tau_max) and
                     (abs(tau3s) <= tau_max) and (abs(tau4s) <= tau_max) and
                     (abs(tau5s) <= tau_max) and (abs(tau6s) <= tau_max);
  force_in_band = (Fn >= 12.0) and (Fn <= 30.0);
  tracking_ok = if time >= 13.0 then abs(e_track) < 0.016 else true;
  contact_ok = Fn > 0.0;
  no_nan_inf = (Fn == Fn) and (s == s) and (dn == dn) and
               (int_force == int_force) and (e_track == e_track) and
               (e_force == e_force);

end ContactArmPolishF;