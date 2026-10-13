model TendonSoftGraspE
  // ============================================================
  // Requirements-derived parameters
  // ============================================================
  parameter Real L = 0.55 "Cylindrical continuum body length [m]";
  parameter Real Ls = L / 6.0 "Constant-curvature section length [m]";
  parameter Real mu = 0.70 "Friction coefficient on rigid support [-]";
  parameter Real Tmax = 46.2 "Per-tendon command magnitude bound [N]";
  parameter Real Fdist = 4.8 "Controlled tangential disturbance load [N]";
  parameter Real Ts = 0.004 "Controller sample period [s] (250 Hz)";
  parameter Real Tend = 16.0 "Total run duration [s]";
  parameter Real settle_time = 10.4 "Tracking-error evaluation onset [s]";
  parameter Real err_thresh = 0.013 "Primary tracking error threshold [m]";

  // ============================================================
  // Physical parameters (assumed for simulation; not stated in requirement)
  // ============================================================
  parameter Real J_sect = 5.0e-5 "Section bending inertia [kg*m^2]";
  parameter Real c_sect = 1.0e-2 "Section damping [N*m*s/rad]";
  parameter Real k_sect = 3.0e-2 "Section elastic stiffness [N*m/rad]";
  parameter Real r_tendon = 2.0e-2 "Tendon offset radius [m]";
  parameter Real tau_act = 2.0e-2 "Actuator first-order time constant [s]";
  parameter Real k_contact = 3000.0 "Compliant contact stiffness [N/m]";
  parameter Real c_contact = 15.0 "Compliant contact damping [N*s/m]";
  parameter Real gap_init = 2.0e-3 "Initial gap to support surface [m]";
  parameter Real m_obj = 5.0e-2 "Object mass [kg]";
  parameter Real c_obj = 0.5 "Object viscous damping [N*s/m]";
  parameter Real friction_gain = 500.0 "Smooth-Coulomb transition steepness";

  // Controller parameters
  parameter Real N_ref = 12.0 "Reference total normal grasp force [N]";
  parameter Real N_per_max = 5.0 "Per-contact normal force upper band [N]";
  parameter Real N_total_max = 30.0 "Total normal force upper band [N]";
  parameter Real N_total_min = 1.0 "Total normal force lower band after grasp [N]";
  parameter Real kp_force = 5.0 "Force-regulation proportional gain";
  parameter Real ki_force = 1.0 "Force-regulation integral gain";
  parameter Real kappa_max = 30.0 "Deformation (curvature) bound [rad/m]";
  parameter Real int_max = 10.0 "Integral anti-windup clamp magnitude [N*s]";
  parameter Real settle_grace = 3.0 "Contact-establishment grace period [s]";

  // ============================================================
  // Continuous state variables (six sections, three tendons, object)
  // ============================================================
  Real kappa1 "Section 1 curvature [rad/m]";
  Real kappa2 "Section 2 curvature [rad/m]";
  Real kappa3 "Section 3 curvature [rad/m]";
  Real kappa4 "Section 4 curvature [rad/m]";
  Real kappa5 "Section 5 curvature [rad/m]";
  Real kappa6 "Section 6 curvature [rad/m]";
  Real kdot1 "Section 1 curvature rate [rad/s]";
  Real kdot2 "Section 2 curvature rate [rad/s]";
  Real kdot3 "Section 3 curvature rate [rad/s]";
  Real kdot4 "Section 4 curvature rate [rad/s]";
  Real kdot5 "Section 5 curvature rate [rad/s]";
  Real kdot6 "Section 6 curvature rate [rad/s]";
  Real T_meas1 "Measured tendon 1 tension [N]";
  Real T_meas2 "Measured tendon 2 tension [N]";
  Real T_meas3 "Measured tendon 3 tension [N]";
  Real x_obj "Object tangential position [m]";
  Real v_obj "Object tangential velocity [m/s]";

  // ============================================================
  // Contact and force variables
  // ============================================================
  Real def1 "Deflection section 1 [m]";
  Real def2 "Deflection section 2 [m]";
  Real def3 "Deflection section 3 [m]";
  Real def4 "Deflection section 4 [m]";
  Real def5 "Deflection section 5 [m]";
  Real def6 "Deflection section 6 [m]";
  Real N1 "Normal contact force section 1 [N]";
  Real N2 "Normal contact force section 2 [N]";
  Real N3 "Normal contact force section 3 [N]";
  Real N4 "Normal contact force section 4 [N]";
  Real N5 "Normal contact force section 5 [N]";
  Real N6 "Normal contact force section 6 [N]";
  Real N_total "Total normal grasp force [N]";
  Real f1 "Friction force section 1 [N]";
  Real f2 "Friction force section 2 [N]";
  Real f3 "Friction force section 3 [N]";
  Real f4 "Friction force section 4 [N]";
  Real f5 "Friction force section 5 [N]";
  Real f6 "Friction force section 6 [N]";
  Real f_total "Total friction force [N]";
  Real tau_moment "Bending moment from tendons [N*m]";
  Real T_sum "Sum of measured tendon tensions [N]";

  // ============================================================
  // Disturbance
  // ============================================================
  Boolean disturbance_active "Disturbance active flag";
  Real F_dist "Applied disturbance load [N]";

  // ============================================================
  // Commands
  // ============================================================
  Real T_cmd1 "Tendon 1 command [N]";
  Real T_cmd2 "Tendon 2 command [N]";
  Real T_cmd3 "Tendon 3 command [N]";

  // ============================================================
  // Sensors (actuator sensing, distributed contact sensing, pose)
  // ============================================================
  Real N_total_meas "Measured total normal force [N]";
  Real x_obj_meas "Measured object position [m]";
  Real T_sense1 "Sensed tendon 1 tension [N]";
  Real T_sense2 "Sensed tendon 2 tension [N]";
  Real T_sense3 "Sensed tendon 3 tension [N]";
  Real N_sense1 "Sensed contact 1 normal force [N]";
  Real N_sense2 "Sensed contact 2 normal force [N]";
  Real N_sense3 "Sensed contact 3 normal force [N]";
  Real N_sense4 "Sensed contact 4 normal force [N]";
  Real N_sense5 "Sensed contact 5 normal force [N]";
  Real N_sense6 "Sensed contact 6 normal force [N]";

  // ============================================================
  // Tracking and acceptance
  // ============================================================
  Real tracking_error "Object tracking error [m]";
  Boolean actuator_ok;
  Boolean deformation_ok;
  Boolean force_band_ok;
  Boolean per_contact_ok;
  Boolean no_contact_loss;
  Boolean tracking_ok;
  Boolean no_nan;
  Boolean all_ok;
  Boolean fail_closed;

  // ============================================================
  // Discrete controller variables (250 Hz)
  // ============================================================
  discrete Real T_cmd_disc1(start = 0.0) "Discrete tendon 1 command [N]";
  discrete Real T_cmd_disc2(start = 0.0) "Discrete tendon 2 command [N]";
  discrete Real T_cmd_disc3(start = 0.0) "Discrete tendon 3 command [N]";
  discrete Real N_err_int_disc(start = 0.0) "Discrete force-error integral [N*s]";
  Boolean fail_latched(start = false) "Fail-closed latch (safety-critical)";

initial equation
  kappa1 = 0.0;
  kappa2 = 0.0;
  kappa3 = 0.0;
  kappa4 = 0.0;
  kappa5 = 0.0;
  kappa6 = 0.0;
  kdot1 = 0.0;
  kdot2 = 0.0;
  kdot3 = 0.0;
  kdot4 = 0.0;
  kdot5 = 0.0;
  kdot6 = 0.0;
  T_meas1 = 0.0;
  T_meas2 = 0.0;
  T_meas3 = 0.0;
  x_obj = 0.0;
  v_obj = 0.0;

equation
  // === Disturbance profile: middle third of 16 s run ===
  disturbance_active = (time >= Tend / 3.0) and (time <= 2.0 * Tend / 3.0);
  F_dist = if disturbance_active then Fdist else 0.0;

  // === Tendon moment (three tendons at 120 deg, simplified equal projection) ===
  T_sum = T_meas1 + T_meas2 + T_meas3;
  tau_moment = r_tendon * T_sum / 3.0;

  // === Actuator dynamics (first-order lag sensing) ===
  der(T_meas1) = (T_cmd1 - T_meas1) / tau_act;
  der(T_meas2) = (T_cmd2 - T_meas2) / tau_act;
  der(T_meas3) = (T_cmd3 - T_meas3) / tau_act;

  // === Commands with fail-closed override ===
  T_cmd1 = if fail_latched then 0.0 else T_cmd_disc1;
  T_cmd2 = if fail_latched then 0.0 else T_cmd_disc2;
  T_cmd3 = if fail_latched then 0.0 else T_cmd_disc3;

  // === Six constant-curvature section dynamics ===
  J_sect * der(kdot1) = tau_moment - c_sect * kdot1 - k_sect * kappa1 - N1 * Ls;
  J_sect * der(kdot2) = tau_moment - c_sect * kdot2 - k_sect * kappa2 - N2 * Ls;
  J_sect * der(kdot3) = tau_moment - c_sect * kdot3 - k_sect * kappa3 - N3 * Ls;
  J_sect * der(kdot4) = tau_moment - c_sect * kdot4 - k_sect * kappa4 - N4 * Ls;
  J_sect * der(kdot5) = tau_moment - c_sect * kdot5 - k_sect * kappa5 - N5 * Ls;
  J_sect * der(kdot6) = tau_moment - c_sect * kdot6 - k_sect * kappa6 - N6 * Ls;
  der(kappa1) = kdot1;
  der(kappa2) = kdot2;
  der(kappa3) = kdot3;
  der(kappa4) = kdot4;
  der(kappa5) = kdot5;
  der(kappa6) = kdot6;

  // === Compliant contact (deflection from curvature minus gap) ===
  def1 = kappa1 * Ls * Ls / 2.0 - gap_init;
  def2 = kappa2 * Ls * Ls / 2.0 - gap_init;
  def3 = kappa3 * Ls * Ls / 2.0 - gap_init;
  def4 = kappa4 * Ls * Ls / 2.0 - gap_init;
  def5 = kappa5 * Ls * Ls / 2.0 - gap_init;
  def6 = kappa6 * Ls * Ls / 2.0 - gap_init;

  N1 = if def1 > 0.0 then max(0.0, k_contact * def1 + c_contact * kdot1 * Ls * Ls / 2.0) else 0.0;
  N2 = if def2 > 0.0 then max(0.0, k_contact * def2 + c_contact * kdot2 * Ls * Ls / 2.0) else 0.0;
  N3 = if def3 > 0.0 then max(0.0, k_contact * def3 + c_contact * kdot3 * Ls * Ls / 2.0) else 0.0;
  N4 = if def4 > 0.0 then max(0.0, k_contact * def4 + c_contact * kdot4 * Ls * Ls / 2.0) else 0.0;
  N5 = if def5 > 0.0 then max(0.0, k_contact * def5 + c_contact * kdot5 * Ls * Ls / 2.0) else 0.0;
  N6 = if def6 > 0.0 then max(0.0, k_contact * def6 + c_contact * kdot6 * Ls * Ls / 2.0) else 0.0;

  // === Friction (smooth Coulomb, opposes object velocity) ===
  f1 = mu * N1 * tanh(friction_gain * v_obj);
  f2 = mu * N2 * tanh(friction_gain * v_obj);
  f3 = mu * N3 * tanh(friction_gain * v_obj);
  f4 = mu * N4 * tanh(friction_gain * v_obj);
  f5 = mu * N5 * tanh(friction_gain * v_obj);
  f6 = mu * N6 * tanh(friction_gain * v_obj);

  // === Force totals ===
  N_total = N1 + N2 + N3 + N4 + N5 + N6;
  f_total = f1 + f2 + f3 + f4 + f5 + f6;

  // === Object dynamics on rigid support ===
  m_obj * der(v_obj) = F_dist - f_total - c_obj * v_obj;
  der(x_obj) = v_obj;

  // === Sensors ===
  N_total_meas = N_total;
  x_obj_meas = x_obj;
  T_sense1 = T_meas1;
  T_sense2 = T_meas2;
  T_sense3 = T_meas3;
  N_sense1 = N1;
  N_sense2 = N2;
  N_sense3 = N3;
  N_sense4 = N4;
  N_sense5 = N5;
  N_sense6 = N6;

  // === Tracking error (object displacement from zero reference) ===
  tracking_error = x_obj;

  // ============================================================
  // Acceptance criteria
  // ============================================================
  actuator_ok = (abs(T_cmd1) <= Tmax + 1.0e-6) and
               (abs(T_cmd2) <= Tmax + 1.0e-6) and
               (abs(T_cmd3) <= Tmax + 1.0e-6);

  deformation_ok = (abs(kappa1) <= kappa_max) and (abs(kappa2) <= kappa_max) and
                   (abs(kappa3) <= kappa_max) and (abs(kappa4) <= kappa_max) and
                   (abs(kappa5) <= kappa_max) and (abs(kappa6) <= kappa_max);

  force_band_ok = (N_total >= 0.0) and (N_total <= N_total_max);

  per_contact_ok = (N1 <= N_per_max + 0.1) and (N2 <= N_per_max + 0.1) and
                   (N3 <= N_per_max + 0.1) and (N4 <= N_per_max + 0.1) and
                   (N5 <= N_per_max + 0.1) and (N6 <= N_per_max + 0.1);

  no_contact_loss = (N_total > N_total_min) or (time < settle_grace);

  tracking_ok = if time >= settle_time then abs(tracking_error) < err_thresh else true;

  no_nan = (abs(kappa1) < 1.0e6) and (abs(kappa2) < 1.0e6) and
           (abs(kappa3) < 1.0e6) and (abs(kappa4) < 1.0e6) and
           (abs(kappa5) < 1.0e6) and (abs(kappa6) < 1.0e6) and
           (abs(x_obj) < 1.0e6) and (abs(v_obj) < 1.0e6) and
           (abs(N_total) < 1.0e6) and (abs(T_meas1) < 1.0e6) and
           (abs(T_meas2) < 1.0e6) and (abs(T_meas3) < 1.0e6);

  all_ok = actuator_ok and deformation_ok and force_band_ok and
           per_contact_ok and no_contact_loss and tracking_ok and no_nan;
  fail_closed = not all_ok;

  // ============================================================
  // Discrete controller at 250 Hz — force regulation with redistribution
  // ============================================================
  when sample(0, Ts) then
    // Fail-closed latch on safety-criteria violation
    fail_latched = pre(fail_latched) or
                  (not actuator_ok) or (not deformation_ok) or
                  (not force_band_ok) or (not per_contact_ok) or
                  (not no_nan);

    // Integral with anti-windup clamp
    N_err_int_disc = if not fail_latched then
      max(-int_max, min(int_max, pre(N_err_int_disc) + (N_ref - N_total_meas) * Ts))
    else 0.0;

    // PI force controller distributed equally across three tendons
    // Tendon commands bounded to [0, Tmax] (pull only, magnitude-bounded)
    T_cmd_disc1 = if not fail_latched then
      max(0.0, min(Tmax, (kp_force * (N_ref - N_total_meas) +
                          ki_force * pre(N_err_int_disc)) / 3.0))
    else 0.0;
    T_cmd_disc2 = if not fail_latched then
      max(0.0, min(Tmax, (kp_force * (N_ref - N_total_meas) +
                          ki_force * pre(N_err_int_disc)) / 3.0))
    else 0.0;
    T_cmd_disc3 = if not fail_latched then
      max(0.0, min(Tmax, (kp_force * (N_ref - N_total_meas) +
                          ki_force * pre(N_err_int_disc)) / 3.0))
    else 0.0;
  end when;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info = "TendonSoftGraspE: Six-section constant-curvature continuum grasper (L=0.55 m) with three tendons at 120 deg spacing, compliant contact (mu=0.70) on rigid support, total normal-force regulation, 4.8 N tangential disturbance during middle third, 250 Hz discrete controller, 16 s run, fail-closed acceptance."));
end TendonSoftGraspE;