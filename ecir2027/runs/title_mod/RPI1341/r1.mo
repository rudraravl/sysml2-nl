model TendonSoftAvoidC
  "Tendon-driven soft robot with contact-aware shape control and bounded stiffness scheduling"

  // ===== Physical parameters =====
  parameter Real L_body = 0.55 "Total body length [m]";
  parameter Real l_sec = L_body / 6 "Section length [m]";
  parameter Real r_arm = 0.01 "Tendon moment arm [m]";
  parameter Real EI_body = 0.015 "Flexural rigidity [N.m^2]";
  parameter Real tau_sec = 0.02 "Section response time constant [s]";
  parameter Real tau_act = 0.012 "Actuator time constant [s]";
  parameter Real r_body = 0.012 "Body radius [m]";

  // ===== Control and disturbance parameters =====
  parameter Real F_max = 38.6 "Maximum command magnitude per tendon [N]";
  parameter Real F_dist = 7.2 "Lateral tip disturbance [N]";
  parameter Real mu_obs = 0.55 "Obstacle friction coefficient [-]";
  parameter Real Kp_tip = 5.0 "Tip tracking proportional gain";
  parameter Real K_obs = 2.5 "Obstacle avoidance gain";
  parameter Real T_bias_min = 3.0 "Minimum bias tension [N]";
  parameter Real T_bias_max = 15.0 "Maximum bias tension [N]";

  // ===== Obstacle and target =====
  parameter Real x_obs = 0.025 "Obstacle center x [m]";
  parameter Real z_obs = 0.22 "Obstacle center z [m]";
  parameter Real r_obs = 0.025 "Obstacle radius [m]";
  parameter Real x_tgt = 0.07 "Target x [m]";
  parameter Real z_tgt = 0.46 "Target z [m]";

  // ===== Contact model =====
  parameter Real k_contact = 8000.0 "Contact stiffness [N/m]";

  // ===== Thermal model =====
  parameter Real T_ambient = 293.15 "Ambient temperature [K]";
  parameter Real R_thermal = 5.0 "Thermal resistance [K/W]";
  parameter Real C_thermal = 2.0 "Thermal capacitance [J/K]";
  parameter Real heat_coeff = 0.002 "Tendon heating coefficient [W/N^2]";

  // ===== Bounds =====
  parameter Real kappa_max = 15.0 "Maximum curvature bound [1/m]";
  parameter Real F_contact_max = 25.0 "Maximum contact force bound [N]";
  parameter Real temp_max = 343.15 "Maximum temperature bound [K]";
  parameter Real clearance_min = -0.002 "Minimum clearance bound [m]";
  parameter Real tip_error_thresh = 0.042 "Primary tracking error threshold [m]";

  // ===== Dynamic states =====
  Real kappa[6](each start = 0.0, each fixed = true) "Section curvatures [1/m]";
  Real T_act[3](each start = 3.0, each fixed = true) "Actual tendon tensions [N]";
  Real temp(start = T_ambient, fixed = true) "Actuator temperature [K]";

  // ===== Algebraic variables =====
  Real kappa_des[6] "Desired curvatures [1/m]";
  Real T_cmd[3] "Commanded tensions [N]";
  Real x_node[7] "Node x positions [m]";
  Real z_node[7] "Node z positions [m]";
  Real alpha_node[7] "Node tangent angles [rad]";
  Real x_tip "Tip x position [m]";
  Real z_tip "Tip z position [m]";
  Real alpha_tip "Tip angle [rad]";
  Real dist_obs[7] "Distance from nodes to obstacle center [m]";
  Real clearance "Minimum obstacle clearance [m]";
  Real F_contact "Total contact force magnitude [N]";
  Real F_friction "Friction force at contact [N]";
  Real F_dist_x "Active lateral disturbance [N]";
  Real tip_error "Tip tracking error [m]";
  Real x_ref "Reference tip x [m]";
  Real z_ref "Reference tip z [m]";
  Real stiff_factor "Stiffness scheduling factor";
  Real T_bias "Base tension for stiffness [N]";
  Real dT "Differential tension for bending [N]";
  Real kappa_ref "Reference curvature [1/m]";

  // ===== Sensor traces =====
  Real sensor_tension[3] "Measured tendon tensions [N]";
  Real sensor_curvature[6] "Measured section curvatures [1/m]";
  Real sensor_contact "Measured contact force [N]";
  Real sensor_tip_x "Measured tip x [m]";
  Real sensor_tip_z "Measured tip z [m]";
  Real sensor_tip_alpha "Measured tip angle [rad]";

  // ===== Bound monitors =====
  Boolean actuator_ok "True if all commands within F_max";
  Boolean deformation_ok "True if all curvatures within bound";
  Boolean contact_ok "True if contact force within bound";
  Boolean temp_ok "True if temperature within bound";
  Boolean clearance_ok "True if clearance above minimum";
  Boolean tracking_ok "True if tip error below threshold after 7.8 s";

  // ===== Local function: smooth sinc =====
  function sinc_fn
    "Numerically stable sinc function for constant-curvature kinematics"
    input Real x;
    output Real y;
  algorithm
    if abs(x) < 1e-10 then
      y := 1.0;
    else
      y := sin(x) / x;
    end if;
  end sinc_fn;

equation
  // ===== Forward kinematics (constant-curvature chain) =====
  x_node[1] = 0.0;
  z_node[1] = 0.0;
  alpha_node[1] = 0.0;

  for i in 1:6 loop
    alpha_node[i+1] = alpha_node[i] + kappa[i] * l_sec;
    x_node[i+1] = x_node[i] + l_sec * sinc_fn(kappa[i] * l_sec / 2.0)
      * sin(alpha_node[i] + kappa[i] * l_sec / 2.0);
    z_node[i+1] = z_node[i] + l_sec * sinc_fn(kappa[i] * l_sec / 2.0)
      * cos(alpha_node[i] + kappa[i] * l_sec / 2.0);
  end for;

  x_tip = x_node[7];
  z_tip = z_node[7];
  alpha_tip = alpha_node[7];

  // ===== Obstacle distance and clearance =====
  for i in 1:7 loop
    dist_obs[i] = sqrt((x_node[i] - x_obs)^2 + (z_node[i] - z_obs)^2 + 1e-12);
  end for;
  clearance = min(dist_obs) - r_obs - r_body;

  // ===== Contact force (spring model with collision enabled) =====
  F_contact = k_contact * max(0.0, -clearance);
  F_friction = mu_obs * F_contact;

  // ===== Disturbance: 7.2 N lateral tip load during middle third (4-8 s) =====
  if time >= 4.0 and time <= 8.0 then
    F_dist_x = F_dist;
  else
    F_dist_x = 0.0;
  end if;

  // ===== Reference trajectory (smooth approach to target) =====
  x_ref = x_tgt * (1.0 - exp(-time / 1.5));
  z_ref = z_tgt + (L_body - z_tgt) * exp(-time / 1.5);

  // ===== Tip tracking error =====
  tip_error = sqrt((x_tip - x_ref)^2 + (z_tip - z_ref)^2 + 1e-12);

  // ===== Stiffness scheduling (smooth increase after 7.8 s and on contact) =====
  stiff_factor = 0.3 + 0.4 / (1.0 + exp(-(time - 7.8) / 0.3))
    + 0.3 * F_contact / (F_contact + 1.0);
  T_bias = T_bias_min + stiff_factor * (T_bias_max - T_bias_min);

  // ===== Shape controller: reference curvature =====
  kappa_ref = Kp_tip * (x_ref - x_tip) + K_obs * max(0.0, 0.005 - clearance);

  // ===== Desired curvature distribution (parabolic across sections) =====
  kappa_des[1] = 0.2 * kappa_ref;
  kappa_des[2] = 0.5 * kappa_ref;
  kappa_des[3] = 1.0 * kappa_ref;
  kappa_des[4] = 1.0 * kappa_ref;
  kappa_des[5] = 0.5 * kappa_ref;
  kappa_des[6] = 0.2 * kappa_ref;

  // ===== Section dynamics (distal sections receive disturbance) =====
  der(kappa[1]) = (kappa_des[1] - kappa[1]) / tau_sec;
  der(kappa[2]) = (kappa_des[2] - kappa[2]) / tau_sec;
  der(kappa[3]) = (kappa_des[3] - kappa[3]) / tau_sec;
  der(kappa[4]) = (kappa_des[4] - kappa[4]) / tau_sec;
  der(kappa[5]) = (kappa_des[5] - kappa[5] + 0.5 * F_dist_x * l_sec / EI_body) / tau_sec;
  der(kappa[6]) = (kappa_des[6] - kappa[6] + F_dist_x * l_sec / EI_body) / tau_sec;

  // ===== Inverse statics: desired curvatures to tendon commands =====
  dT = (kappa_des[1] + kappa_des[2] + kappa_des[3] + kappa_des[4]
      + kappa_des[5] + kappa_des[6]) * l_sec * EI_body / (1.5 * r_arm);
  T_cmd[1] = max(0.0, min(F_max, T_bias + dT));
  T_cmd[2] = max(0.0, min(F_max, T_bias - 0.5 * dT));
  T_cmd[3] = max(0.0, min(F_max, T_bias - 0.5 * dT));

  // ===== Actuator dynamics (measured tendon tensions) =====
  der(T_act[1]) = (T_cmd[1] - T_act[1]) / tau_act;
  der(T_act[2]) = (T_cmd[2] - T_act[2]) / tau_act;
  der(T_act[3]) = (T_cmd[3] - T_act[3]) / tau_act;

  // ===== Temperature model ( Joule-like heating from tendon loads ) =====
  der(temp) = ((T_act[1]^2 + T_act[2]^2 + T_act[3]^2) * heat_coeff
    - (temp - T_ambient) / R_thermal) / C_thermal;

  // ===== Sensor traces (synchronized state, command, and sensor outputs) =====
  sensor_tension[1] = T_act[1];
  sensor_tension[2] = T_act[2];
  sensor_tension[3] = T_act[3];
  sensor_curvature[1] = kappa[1];
  sensor_curvature[2] = kappa[2];
  sensor_curvature[3] = kappa[3];
  sensor_curvature[4] = kappa[4];
  sensor_curvature[5] = kappa[5];
  sensor_curvature[6] = kappa[6];
  sensor_contact = F_contact;
  sensor_tip_x = x_tip;
  sensor_tip_z = z_tip;
  sensor_tip_alpha = alpha_tip;

  // ===== Bound monitors =====
  actuator_ok = T_cmd[1] <= F_max and T_cmd[2] <= F_max and T_cmd[3] <= F_max
    and T_cmd[1] >= 0.0 and T_cmd[2] >= 0.0 and T_cmd[3] >= 0.0;
  deformation_ok = abs(kappa[1]) <= kappa_max and abs(kappa[2]) <= kappa_max
    and abs(kappa[3]) <= kappa_max and abs(kappa[4]) <= kappa_max
    and abs(kappa[5]) <= kappa_max and abs(kappa[6]) <= kappa_max;
  contact_ok = F_contact <= F_contact_max;
  temp_ok = temp <= temp_max;
  clearance_ok = clearance >= clearance_min;
  tracking_ok = time < 7.8 or tip_error <= tip_error_thresh;

  annotation(
    Documentation(info = "TendonSoftAvoidC: Tendon-driven soft robotic system with contact-aware shape control and bounded stiffness scheduling. Plant: 0.55 m cylindrical continuum body, 6 constant-curvature sections, 3 tendons at 120 deg spacing. Obstacle: fixed cylinder with friction coefficient 0.55 and collision enabled. Control: max command 38.6 N/tendon, 7.2 N lateral tip disturbance during middle third (4-8 s). Objective: reach target around obstacle with bounded incidental contact, then stiffen/hold shape. Tracking error below 0.042 m after 7.8 s. Run at 125 Hz for 12 s."),
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008)
  );
end TendonSoftAvoidC;