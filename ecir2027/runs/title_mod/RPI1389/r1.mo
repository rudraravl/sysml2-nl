model SoftCrawlAvoidC
  // ============================================================
  // SoftCrawlAvoidC
  // Contact-aware shape control with bounded stiffness scheduling
  // for a 6-chamber soft crawler around a fixed cylindrical
  // obstacle. All facts stated in the requirement are bound
  // explicitly; facts not stated (obstacle position/size, ground
  // friction values, wave frequency, segment dynamics, target
  // location) are documented design assumptions and are NOT
  // claimed as requirement facts.
  // ============================================================

  // --- Stated body parameters ---
  parameter Real L_body = 0.48 "m, compliant body length";
  parameter Real L_seg  = L_body/6 "m, per-chamber length";

  // --- Stated command bound ---
  parameter Real P_max = 69000 "Pa, 69 kPa gauge max command magnitude";

  // --- Stated obstacle: fixed cylinder, friction 0.55, collision enabled ---
  parameter Real mu_obs = 0.55 "cylinder friction coefficient (stated)";
  // Obstacle location/size not stated -> design assumptions:
  parameter Real x_obs = 0.70 "m, cylinder center x (assumed)";
  parameter Real y_obs = 0.03 "m, cylinder center y (assumed)";
  parameter Real r_obs = 0.05 "m, cylinder radius (assumed)";

  // --- Anisotropic ground friction (values not stated -> assumptions) ---
  parameter Real mu_fwd = 0.20 "forward ground friction (assumed)";
  parameter Real mu_bck = 0.55 "backward ground friction (assumed)";

  // --- Stated disturbance ---
  parameter Real F_disturb = 7.2 "N, lateral tip load";
  parameter Real t_dist0 = 4.0 "s, middle third start (12/3)";
  parameter Real t_dist1 = 8.0 "s, middle third end";

  // --- Target (location not stated -> assumption) ---
  parameter Real x_target = 0.90 "m, target x (assumed beyond obstacle)";
  parameter Real y_target = 0.00 "m, target y (assumed)";

  // --- Traveling-wave / segment dynamics (assumed) ---
  parameter Real f_wave   = 0.5 "Hz, traveling-wave frequency (assumed)";
  parameter Real wn       = 9.42477796 "rad/s, segment natural freq (assumed)";
  parameter Real zeta     = 0.6 "segment damping ratio (assumed)";
  parameter Real Kp_bend  = 0.8 "pressure-to-bending gain (assumed)";
  parameter Real k_crawl  = 0.40 "crawl speed gain (assumed)";

  // --- Lateral tip dynamics (assumed) ---
  parameter Real m_tip    = 2.0 "kg, tip effective mass (assumed)";
  parameter Real c_lat    = 10.0 "N.s/m, lateral damping (assumed)";
  parameter Real k_lat    = 50.0 "N/m, lateral restoring (assumed)";
  parameter Real K_lat_p  = 500.0 "lateral control proportional gain (assumed)";
  parameter Real K_lat_v  = 100.0 "lateral control derivative gain (assumed)";

  // --- Bounds (categories stated; numeric values assumed unless noted) ---
  parameter Real def_bound           = 0.30 "rad, section deformation bound (assumed)";
  parameter Real Fc_bound           = 5.0  "N, per-chamber contact force bound (assumed)";
  parameter Real T_bound             = 350.0 "K, temperature bound (assumed)";
  parameter Real tip_err_final_bound = 0.042 "m, final tip-error bound (stated)";

  // --- Dynamic states: segment bending angles and rates ---
  Real theta1, theta2, theta3, theta4, theta5, theta6;
  Real dtheta1, dtheta2, dtheta3, dtheta4, dtheta5, dtheta6;

  // --- Chamber pressure commands (actuator state) ---
  Real p1, p2, p3, p4, p5, p6;

  // --- Distributed contact force per chamber ---
  Real Fc1, Fc2, Fc3, Fc4, Fc5, Fc6;

  // --- Body / tip pose ---
  Real x_body "m, body base x";
  Real x_tip  "m, tip x (= base + L_body)";
  Real y_tip  "m, tip y";
  Real vy     "m/s, tip lateral velocity";

  // --- Stiffness schedule [0,1] ---
  Real s_sched;

  // --- Tracking error and obstacle clearance ---
  Real tip_err;
  Real clearance;

  // --- Lumped temperature ---
  Real T_body;

  // --- Disturbance signal ---
  Real disturb;

  // --- Traveling-wave references ---
  Real wave1, wave2, wave3, wave4, wave5, wave6;

  // --- Bounded pressure intermediates ---
  Real sat_p1, sat_p2, sat_p3, sat_p4, sat_p5, sat_p6;

  // --- Crawl kinematics ---
  Real v_fwd;
  Real theta_rms;
  Real dir_factor;

  // --- Obstacle contact (collision enabled) ---
  Real Fc_obs    "obstacle normal contact force";
  Real F_repel   "lateral repulsion from cylinder";
  Real F_friction_x "cylinder tangential friction opposing crawl";

  // --- Lateral control ---
  Real F_lat_ctrl;

  // --- Aggregates for bounds ---
  Real Fc_sum;

initial equation
  theta1 = 0; theta2 = 0; theta3 = 0; theta4 = 0; theta5 = 0; theta6 = 0;
  dtheta1 = 0; dtheta2 = 0; dtheta3 = 0; dtheta4 = 0; dtheta5 = 0; dtheta6 = 0;
  x_body = 0; y_tip = 0; vy = 0; T_body = 293.15;

equation
  // --- Traveling-wave references (six phase-shifted sine waves) ---
  wave1 = Modelica.Math.sin(2*Modelica.Constants.pi*f_wave*time);
  wave2 = Modelica.Math.sin(2*Modelica.Constants.pi*f_wave*time - Modelica.Constants.pi/3);
  wave3 = Modelica.Math.sin(2*Modelica.Constants.pi*f_wave*time - 2*Modelica.Constants.pi/3);
  wave4 = Modelica.Math.sin(2*Modelica.Constants.pi*f_wave*time - Modelica.Constants.pi);
  wave5 = Modelica.Math.sin(2*Modelica.Constants.pi*f_wave*time - 4*Modelica.Constants.pi/3);
  wave6 = Modelica.Math.sin(2*Modelica.Constants.pi*f_wave*time - 5*Modelica.Constants.pi/3);

  // --- Aggregate contact force ---
  Fc_sum = Fc1 + Fc2 + Fc3 + Fc4 + Fc5 + Fc6;

  // --- Tracking error ---
  tip_err = sqrt((x_tip - x_target)^2 + (y_tip - y_target)^2);

  // --- Bounded stiffness scheduling ---
  // Reduce stiffness (soft) when distributed contact is high;
  // increase stiffness (hold) when tracking error is small.
  s_sched = 0.5 + 0.5*Modelica.Math.tanh((0.5 - Fc_sum)/0.5)
                * Modelica.Math.tanh((0.042 - tip_err)/0.02);

  // --- Bounded chamber pressure commands (|p_i| <= P_max) ---
  sat_p1 = P_max*Modelica.Math.tanh((0.6 + 0.4*s_sched)*wave1);
  sat_p2 = P_max*Modelica.Math.tanh((0.6 + 0.4*s_sched)*wave2);
  sat_p3 = P_max*Modelica.Math.tanh((0.6 + 0.4*s_sched)*wave3);
  sat_p4 = P_max*Modelica.Math.tanh((0.6 + 0.4*s_sched)*wave4);
  sat_p5 = P_max*Modelica.Math.tanh((0.6 + 0.4*s_sched)*wave5);
  sat_p6 = P_max*Modelica.Math.tanh((0.6 + 0.4*s_sched)*wave6);

  p1 = max(-P_max, min(P_max, sat_p1));
  p2 = max(-P_max, min(P_max, sat_p2));
  p3 = max(-P_max, min(P_max, sat_p3));
  p4 = max(-P_max, min(P_max, sat_p4));
  p5 = max(-P_max, min(P_max, sat_p5));
  p6 = max(-P_max, min(P_max, sat_p6));

  // --- Section deformation dynamics (2nd order per chamber) ---
  der(theta1) = dtheta1;
  der(theta2) = dtheta2;
  der(theta3) = dtheta3;
  der(theta4) = dtheta4;
  der(theta5) = dtheta5;
  der(theta6) = dtheta6;

  der(dtheta1) = -2*zeta*wn*dtheta1 - wn*wn*theta1 + wn*wn*Kp_bend*p1/P_max;
  der(dtheta2) = -2*zeta*wn*dtheta2 - wn*wn*theta2 + wn*wn*Kp_bend*p2/P_max;
  der(dtheta3) = -2*zeta*wn*dtheta3 - wn*wn*theta3 + wn*wn*Kp_bend*p3/P_max;
  der(dtheta4) = -2*zeta*wn*dtheta4 - wn*wn*theta4 + wn*wn*Kp_bend*p4/P_max;
  der(dtheta5) = -2*zeta*wn*dtheta5 - wn*wn*theta5 + wn*wn*Kp_bend*p5/P_max;
  der(dtheta6) = -2*zeta*wn*dtheta6 - wn*wn*theta6 + wn*wn*Kp_bend*p6/P_max;

  // --- Distributed contact force per chamber (ground/obstacle) ---
  Fc1 = max(0, abs(theta1) - 0.05)*20;
  Fc2 = max(0, abs(theta2) - 0.05)*20;
  Fc3 = max(0, abs(theta3) - 0.05)*20;
  Fc4 = max(0, abs(theta4) - 0.05)*20;
  Fc5 = max(0, abs(theta5) - 0.05)*20;
  Fc6 = max(0, abs(theta6) - 0.05)*20;

  // --- RMS section deformation (drives crawl via friction asymmetry) ---
  theta_rms = sqrt((theta1*theta1 + theta2*theta2 + theta3*theta3 +
                    theta4*theta4 + theta5*theta5 + theta6*theta6)/6.0);

  // --- Forward crawl direction factor (stop when reaching target) ---
  dir_factor = max(0, Modelica.Math.tanh((x_target - x_tip)/0.05));

  // --- Obstacle clearance and contact ---
  clearance = sqrt((x_tip - x_obs)^2 + (y_tip - y_obs)^2) - r_obs;
  Fc_obs = max(0, (0.05 - clearance))*100.0;     // normal contact force
  F_repel = -Fc_obs*Modelica.Math.tanh(50.0*(y_tip - y_obs)); // lateral push away
  F_friction_x = -mu_obs*Fc_obs*Modelica.Math.tanh(v_fwd/0.01); // opposes crawl

  // --- Forward velocity from anisotropic friction + obstacle friction ---
  v_fwd = k_crawl*theta_rms*(mu_bck - mu_fwd)/max(mu_bck, 0.01)*dir_factor
          + F_friction_x/m_tip;

  der(x_body) = v_fwd;
  x_tip = x_body + L_body;

  // --- Lateral tip disturbance (middle third) ---
  disturb = if time >= t_dist0 and time <= t_dist1 then F_disturb else 0.0;

  // --- Lateral control: counteract disturbance, restore to path ---
  F_lat_ctrl = -K_lat_p*y_tip - K_lat_v*vy;

  der(y_tip) = vy;
  der(vy) = (F_repel + disturb + F_lat_ctrl - c_lat*vy - k_lat*y_tip)/m_tip;

  // --- Lumped temperature from actuation ---
  der(T_body) = 0.002*(abs(p1)+abs(p2)+abs(p3)+abs(p4)+abs(p5)+abs(p6))/P_max
                - 0.01*(T_body - 293.15);

  // --- Bound enforcement (no NaN/infinite tolerated) ---
  assert(abs(p1) <= P_max + 1.0, "actuator bound p1 violated");
  assert(abs(p2) <= P_max + 1.0, "actuator bound p2 violated");
  assert(abs(p3) <= P_max + 1.0, "actuator bound p3 violated");
  assert(abs(p4) <= P_max + 1.0, "actuator bound p4 violated");
  assert(abs(p5) <= P_max + 1.0, "actuator bound p5 violated");
  assert(abs(p6) <= P_max + 1.0, "actuator bound p6 violated");
  assert(abs(theta1) <= def_bound, "section deformation bound (chamber 1)");
  assert(abs(theta2) <= def_bound, "section deformation bound (chamber 2)");
  assert(abs(theta3) <= def_bound, "section deformation bound (chamber 3)");
  assert(abs(theta4) <= def_bound, "section deformation bound (chamber 4)");
  assert(abs(theta5) <= def_bound, "section deformation bound (chamber 5)");
  assert(abs(theta6) <= def_bound, "section deformation bound (chamber 6)");
  assert(Fc1 <= Fc_bound, "contact force bound (chamber 1)");
  assert(Fc2 <= Fc_bound, "contact force bound (chamber 2)");
  assert(Fc3 <= Fc_bound, "contact force bound (chamber 3)");
  assert(Fc4 <= Fc_bound, "contact force bound (chamber 4)");
  assert(Fc5 <= Fc_bound, "contact force bound (chamber 5)");
  assert(Fc6 <= Fc_bound, "contact force bound (chamber 6)");
  assert(Fc_obs <= Fc_bound, "obstacle contact force bound");
  assert(T_body <= T_bound, "temperature bound");
  assert(clearance >= -0.01, "obstacle penetration bound");
  assert(time < 7.8 or tip_err <= tip_err_final_bound,
         "primary tracking error bound after 7.8 s violated");

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "SoftCrawlAvoidC: contact-aware shape control of a "
      "0.48 m, 6-chamber soft crawler with bounded stiffness scheduling around "
      "a fixed cylindrical obstacle. Sampled at 125 Hz (Interval=0.008 s) for "
      "12 s. Stated facts: body length 0.48 m, 6 chambers, max command 69 kPa, "
      "7.2 N lateral tip disturbance during middle third (4-8 s), cylinder "
      "friction 0.55 with collision enabled, primary tracking error < 0.042 m "
      "after 7.8 s. Unspecified quantities (obstacle position/size, ground "
      "friction values, wave frequency, segment dynamics, target location, "
      "numeric bound values) are design assumptions, not requirement facts."));
end SoftCrawlAvoidC;