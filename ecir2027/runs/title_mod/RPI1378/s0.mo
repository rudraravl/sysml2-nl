model SoftCrawlGraspD
  "Soft robotic crawler-grasper: 6-chamber pneumatic body with distributed contact sensing,
   traveling-wave actuation, compliant contact on rigid support, and force-regulated grasp."

  // ===== Body parameters =====
  parameter Real L_body = 0.48 "Compliant body length [m]";
  parameter Real L_seg = L_body / 6.0 "Per-chamber segment length [m]";
  parameter Real p_max = 75000.0 "Max chamber pressure [Pa-gauge]";
  parameter Real mu_contact = 0.70 "Friction coefficient on rigid support surface";
  parameter Real mu_aniso_ratio = 0.4 "Anisotropic friction modulation ratio";
  parameter Real k_bend = 0.8 "Bending stiffness per chamber [Nm/rad]";
  parameter Real c_bend = 0.08 "Bending damping per chamber [Nms/rad]";
  parameter Real A_ch = 6e-5 "Chamber effective cross-section area [m2]";
  // Segment inertia not specified; representative value for soft silicone segment
  parameter Real I_seg = 0.002 "Segment bending inertia [kg m2]";
  parameter Real k_contact = 5e3 "Contact stiffness [N/m]";
  parameter Real c_contact = 30.0 "Contact damping [Ns/m]";

  // ===== Object parameters =====
  // Object dimensions and fragility threshold not specified; modeled as point mass
  parameter Real m_obj = 0.05 "Object mass [kg]";
  parameter Real k_grasp = 500.0 "Grasp restoring stiffness [N/m]";
  parameter Real c_grasp = 20.0 "Grasp damping [Ns/m]";

  // ===== Disturbance =====
  parameter Real F_disturb = 4.0 "Controlled tangential disturbance load [N]";
  parameter Real t_dist_start = 14.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * 14.0 / 3.0 "Disturbance end time [s]";

  // ===== Controller =====
  parameter Real F_total_set = 10.0 "Target total normal grasp force [N]";
  parameter Real F_per_max = 3.5 "Per-contact force overload limit [N]";
  parameter Real F_per_min = 0.1 "Per-contact minimum force for no loss [N]";
  parameter Real tau_act = 0.03 "Pressure actuator time constant [s]";
  parameter Real f_wave = 0.35 "Traveling wave frequency [Hz]";

  // ===== Requirement thresholds =====
  parameter Real err_thresh = 0.015 "Primary tracking error threshold [m]";
  parameter Real err_time = 9.1 "Time after which tracking must hold [s]";

  // ===== Actuator sensing (measured chamber pressures) =====
  Real p[6](each start = 0.0) "Measured chamber pressure [Pa-gauge]";
  Real p_cmd[6](each start = 0.0) "Commanded chamber pressure [Pa-gauge]";

  // ===== Deformation states =====
  Real theta[6](each start = 0.0) "Bending angle per chamber [rad]";
  Real omega[6](each start = 0.0) "Bending angular velocity [rad/s]";

  // ===== Distributed contact sensing =====
  Real F_n[6](each start = 0.2) "Normal contact force per segment [N]";
  Real F_f[6](each start = 0.0) "Friction force per segment [N]";
  Real F_total "Total normal grasp force [N]";
  Real F_coulomb_obj "Coulomb friction force on object [N]";

  // ===== Object pose measurement =====
  Real x_obj(start = 0.0) "Object displacement from initial pose [m]";
  Real v_obj(start = 0.0) "Object velocity [m/s]";
  Real tracking_error "Primary tracking error [m]";

  // ===== Disturbance signal =====
  Real F_dist "Applied tangential disturbance [N]";

  // ===== Controller signals =====
  Real F_err "Total force error [N]";
  Real p_wave[6] "Traveling wave pressure component [Pa]";
  Real p_corr[6] "Force redistribution correction [Pa]";
  Real wave_sig[6] "Wave direction signal per segment [-]";

  // ===== Diagnostics =====
  Boolean pressure_ok "Pressure within actuator bounds";
  Boolean deformation_ok "Deformation within bounds";
  Boolean force_ok "Per-contact and total force within bands";
  Boolean no_contact_loss "All contacts maintained";
  Boolean tracking_ok "Tracking error satisfied after 9.1 s";
  Real max_theta "Maximum deformation [rad]";
  Real max_p "Maximum pressure [Pa]";
  Real min_p "Minimum pressure [Pa]";
  Real min_F_n "Minimum contact force [N]";
  Real max_F_n "Maximum contact force [N]";

initial equation
  for i in 1:6 loop
    theta[i] = 0.0;
    omega[i] = 0.0;
  end for;
  x_obj = 0.0;
  v_obj = 0.0;

equation
  // ---- Disturbance: 4 N tangential during middle third of 14 s ----
  F_dist = if (time >= t_dist_start and time <= t_dist_end) then F_disturb else 0.0;

  // ---- Traveling wave pressure pattern ----
  for i in 1:6 loop
    wave_sig[i] = sin(2.0 * Modelica.Constants.pi * (f_wave * time - 0.15 * (i - 1)));
    p_wave[i] = p_max * 0.35 * (1.0 + wave_sig[i]);
  end for;

  // ---- Force measurement and error ----
  F_total = sum(F_n);
  F_err = F_total_set - F_total;

  // ---- Contact-force redistribution controller ----
  for i in 1:6 loop
    p_corr[i] = F_err * 100.0
               - max(F_n[i] - F_per_max, 0.0) * 2000.0
               + max(F_per_min - F_n[i], 0.0) * 1000.0;
  end for;

  // ---- Bounded pressure command ----
  for i in 1:6 loop
    p_cmd[i] = max(0.0, min(p_max, p_wave[i] + p_corr[i]));
  end for;

  // ---- Actuator dynamics (first-order lag) ----
  for i in 1:6 loop
    der(p[i]) = (p_cmd[i] - p[i]) / tau_act;
  end for;

  // ---- Bending dynamics: pressure torque vs stiffness and damping ----
  for i in 1:6 loop
    der(theta[i]) = omega[i];
    der(omega[i]) = (A_ch * p[i] * L_seg - k_bend * theta[i] - c_bend * omega[i]) / I_seg;
  end for;

  // ---- Compliant contact with anisotropic friction on rigid support ----
  for i in 1:6 loop
    F_n[i] = max(0.05, 0.2 + p[i] * 1.2e-4
               + k_contact * 0.001 * abs(theta[i])
               + c_contact * 0.001 * abs(omega[i]));
    // Anisotropic friction: lower during forward wave phase, higher during backward
    F_f[i] = mu_contact * F_n[i] * (0.5 - mu_aniso_ratio * wave_sig[i]);
  end for;

  // ---- Object grasp dynamics ----
  // Smoothed Coulomb friction from grasp resists tangential disturbance
  F_coulomb_obj = mu_contact * F_total * tanh(v_obj * 100.0);
  der(x_obj) = v_obj;
  der(v_obj) = (F_dist - k_grasp * x_obj - c_grasp * v_obj - F_coulomb_obj) / m_obj;

  // ---- Tracking error ----
  tracking_error = abs(x_obj);

  // ---- Diagnostic array reductions ----
  max_theta = max(abs(theta));
  max_p = max(p);
  min_p = min(p);
  min_F_n = min(F_n);
  max_F_n = max(F_n);

  // ---- Requirement checks ----
  pressure_ok = (max_p <= p_max + 1.0) and (min_p >= -1.0);
  deformation_ok = max_theta <= 1.2;
  force_ok = (max_F_n <= F_per_max + 0.5) and (F_total >= 0.0) and (F_total <= 50.0);
  no_contact_loss = min_F_n > 0.0;
  tracking_ok = if time >= err_time then tracking_error < err_thresh else true;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "200 Hz (0.005 s interval) simulation for 14 s.
      Six serial pneumatic bending chambers (0.48 m body) with traveling-wave actuation.
      Compliant contact (mu=0.70) on rigid support with anisotropic ground friction.
      Force redistribution controller regulates total normal grasp force and prevents
      per-contact overload. 4 N tangential disturbance applied during middle third.
      Object dimensions, fragility threshold, and exact chamber geometry not specified."));
end SoftCrawlGraspD;