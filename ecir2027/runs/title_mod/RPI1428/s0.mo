model ElectroSoftGraspF
  "Soft robotic grasp scenario: dielectric-elastomer membrane conforms around
   a fragile object, regulates total normal grasp force with contact-force
   redistribution. Tangential disturbance applied during middle third."

  // ==================== Timing ====================
  parameter Real tEnd = 20.0 "Mission duration [s]";
  parameter Real fSample = 500.0 "Sampling frequency [Hz]";

  // ==================== Membrane geometry (from requirement) ====================
  parameter Real L0 = 0.20 "Membrane length [m]";
  parameter Real W0 = 0.05 "Membrane width [m]";
  parameter Real h0 = 0.8e-3 "Membrane thickness [m]";
  parameter Real A0 = L0 * W0 "Membrane area [m2]";

  // ==================== DE material (estimated; not specified by requirement) ====================
  parameter Real eps_r = 3.0 "Relative permittivity [-] (estimated)";
  parameter Real eps_0 = 8.8541878128e-12 "Vacuum permittivity [F/m]";
  parameter Real E_young = 5.0e4 "Young's modulus [Pa] (estimated)";
  parameter Real eta_ve = 2.5e4 "Viscoelastic damping coefficient [Pa.s] (estimated)";
  parameter Real tau_ve = 0.5 "Viscoelastic relaxation time [s] (estimated)";
  parameter Real R_leak = 1.0e12 "Leakage resistance [Ohm] (estimated)";
  parameter Real C_th = 0.01 "Thermal capacitance [J/K] (estimated)";
  parameter Real G_cool = 0.01 "Cooling conductance [W/K] (estimated)";
  parameter Real T_amb = 293.15 "Ambient temperature [K] (estimated)";

  // ==================== Actuator limits ====================
  parameter Real V_max = 6100.0 "Maximum voltage [V] (from requirement: 6.1 kV)";
  parameter Real slewRate = 2000.0 "Max voltage slew rate [V/s] (estimated)";

  // ==================== Contact and friction ====================
  parameter Real mu = 0.70 "Friction coefficient [-] (from requirement)";
  parameter Real k_contact = 500.0 "Contact stiffness [N] (estimated)";
  parameter Real F_per_contact_max = 4.0 "Max per-contact normal force [N] (estimated)";
  parameter Real K_redist = 1.0 "Redistribution gain [-] (estimated)";

  // ==================== Disturbance ====================
  parameter Real F_dist = 5.8 "Tangential disturbance [N] (from requirement)";

  // ==================== Object (estimated) ====================
  parameter Real m_obj = 0.5 "Object mass [kg] (estimated)";
  parameter Real v_small = 1.0e-4 "Friction regularization velocity [m/s] (estimated)";
  parameter Real k_tangent = 2000.0 "Membrane tangential stiffness [N/m] (estimated)";
  parameter Real c_tangent = 5.0 "Membrane tangential damping [N.s/m] (estimated)";
  parameter Real k_normal = 10000.0 "Membrane normal stiffness [N/m] (estimated)";
  parameter Real c_normal = 10.0 "Membrane normal damping [N.s/m] (estimated)";

  // ==================== Control (estimated) ====================
  parameter Real F_total_ref = 10.0 "Target total normal force [N] (estimated)";
  parameter Real Ki_v = 500.0 "Voltage integrator gain [V/(N.s)] (estimated)";
  parameter Real err_thresh = 0.012 "Tracking error threshold [m] (from requirement)";

  // ==================== Actuator states ====================
  Real V_cmd(start = 0.0) "Voltage command [V]";
  Real V_cmd_clamped(start = 0.0) "Clamped voltage command [V]";
  Real V_act(start = 0.0) "Actuated voltage (slew-limited) [V]";
  Real V_int(start = 0.0) "Voltage integrator state [V]";

  // ==================== DE states ====================
  Real p_de(start = 0.0) "Maxwell pressure [Pa]";
  Real lambda(start = 1.0) "Stretch ratio [-]";
  Real sigma_v(start = 0.0) "Viscoelastic stress [Pa]";
  Real I_leak(start = 0.0) "Leakage current [A]";
  Real T_mem(start = 293.15) "Membrane temperature [K]";
  Real P_joule(start = 0.0) "Joule heating power [W]";

  // ==================== Contact forces ====================
  Real F_total_raw(start = 0.0) "Raw total force from stretch [N]";
  Real F_contact1(start = 0.0) "Contact node 1 normal force [N]";
  Real F_contact2(start = 0.0) "Contact node 2 normal force [N]";
  Real F_contact3(start = 0.0) "Contact node 3 normal force [N]";
  Real F_total(start = 0.0) "Total normal grasp force [N]";
  Real F_friction(start = 0.0) "Friction force [N]";

  // ==================== Object pose ====================
  Real x_obj(start = 0.0) "Object tangential position [m]";
  Real vx_obj(start = 0.0) "Object tangential velocity [m/s]";
  Real y_obj(start = 0.0) "Object normal position [m]";
  Real vy_obj(start = 0.0) "Object normal velocity [m/s]";

  // ==================== Disturbance ====================
  Real F_tan(start = 0.0) "Tangential disturbance force [N]";

  // ==================== Tracking error ====================
  Real err_track(start = 0.0) "Primary tracking error [m]";

  // ==================== Sensor outputs ====================
  Real V_sensed(start = 0.0) "Sensed actuator voltage [V]";
  Real F_total_sensed(start = 0.0) "Sensed total normal force [N]";
  Real F_contact1_sensed(start = 0.0) "Sensed contact 1 force [N]";
  Real F_contact2_sensed(start = 0.0) "Sensed contact 2 force [N]";
  Real F_contact3_sensed(start = 0.0) "Sensed contact 3 force [N]";
  Real x_sensed(start = 0.0) "Sensed object tangential position [m]";
  Real y_sensed(start = 0.0) "Sensed object normal position [m]";
  Real T_sensed(start = 293.15) "Sensed membrane temperature [K]";

  // ==================== Verification flags ====================
  Boolean b_voltage_ok "Voltage within 6.1 kV bound";
  Boolean b_stretch_ok "Stretch within deformation bound";
  Boolean b_force_total_ok "Total force within band";
  Boolean b_force_contact_ok "Per-contact force within band";
  Boolean b_err_ok "Tracking error below 0.012 m after 13 s";
  Boolean b_no_loss "No contact loss after grasp established";
  Boolean b_no_nan "No NaN or infinite values";

equation
  // --- Disturbance: middle third of mission [tEnd/3, 2*tEnd/3] ---
  F_tan = if (time >= tEnd / 3.0 and time <= 2.0 * tEnd / 3.0) then F_dist else 0.0;

  // --- DE Maxwell pressure ---
  p_de = eps_r * eps_0 * (V_act / h0) * (V_act / h0);

  // --- Stretch dynamics: pressure vs elastic restoring + viscoelastic ---
  der(lambda) = (p_de - E_young * (lambda - 1.0) - sigma_v) / eta_ve;

  // --- Viscoelastic stress relaxation (Maxwell element, derivative substituted) ---
  der(sigma_v) = (E_young * (p_de - E_young * (lambda - 1.0) - sigma_v) / eta_ve - sigma_v) / tau_ve;

  // --- Leakage current and Joule heating ---
  I_leak = V_act / R_leak;
  P_joule = V_act * I_leak;

  // --- Thermal state ---
  C_th * der(T_mem) = P_joule - G_cool * (T_mem - T_amb);

  // --- Raw total contact force from membrane stretch ---
  F_total_raw = k_contact * (lambda - 1.0);

  // --- Contact-force redistribution: cap each contact at F_per_contact_max ---
  F_contact1 = F_total_raw / 3.0 - K_redist * max(0.0, F_total_raw / 3.0 - F_per_contact_max);
  F_contact2 = F_total_raw / 3.0 - K_redist * max(0.0, F_total_raw / 3.0 - F_per_contact_max);
  F_contact3 = F_total_raw / 3.0 - K_redist * max(0.0, F_total_raw / 3.0 - F_per_contact_max);

  // --- Total normal grasp force ---
  F_total = F_contact1 + F_contact2 + F_contact3;

  // --- Friction force (regularized Coulomb on rigid support) ---
  F_friction = mu * F_total * tanh(vx_obj / v_small);

  // --- Object dynamics: tangential direction ---
  m_obj * der(vx_obj) = F_tan - F_friction - k_tangent * x_obj - c_tangent * vx_obj;
  der(x_obj) = vx_obj;

  // --- Object dynamics: normal direction ---
  m_obj * der(vy_obj) = -k_normal * y_obj - c_normal * vy_obj;
  der(y_obj) = vy_obj;

  // --- Primary tracking error ---
  err_track = sqrt(x_obj * x_obj + y_obj * y_obj + 1.0e-12);

  // --- Control: integral voltage control to regulate total normal force ---
  der(V_int) = Ki_v * (F_total_ref - F_total_sensed);
  V_cmd = V_int;
  V_cmd_clamped = max(0.0, min(V_max, V_cmd));

  // --- Slew-limited actuation (smooth saturation) ---
  der(V_act) = slewRate * tanh((V_cmd_clamped - V_act) / (slewRate * 0.01));

  // --- Sensor outputs (actuator, distributed contact, object pose) ---
  V_sensed = V_act;
  F_total_sensed = F_total;
  F_contact1_sensed = F_contact1;
  F_contact2_sensed = F_contact2;
  F_contact3_sensed = F_contact3;
  x_sensed = x_obj;
  y_sensed = y_obj;
  T_sensed = T_mem;

  // --- Verification criteria ---
  b_voltage_ok = V_act >= 0.0 and V_act <= V_max + 1.0;
  b_stretch_ok = lambda >= 0.9 and lambda <= 2.0;
  b_force_total_ok = F_total >= 0.0 and F_total <= 20.0;
  b_force_contact_ok = F_contact1 <= F_per_contact_max + 0.01 and
                       F_contact2 <= F_per_contact_max + 0.01 and
                       F_contact3 <= F_per_contact_max + 0.01;
  b_err_ok = if time >= 13.0 then err_track < err_thresh else true;
  b_no_loss = if time >= 2.0 then
                (F_contact1 > 0.0 and F_contact2 > 0.0 and F_contact3 > 0.0)
              else true;
  b_no_nan = (V_act == V_act) and (lambda == lambda) and (sigma_v == sigma_v) and
             (F_total == F_total) and (x_obj == x_obj) and (y_obj == y_obj) and
             (T_mem == T_mem) and (V_int == V_int);

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Soft robotic grasp scenario ElectroSoftGraspF.
      Dielectric-elastomer membrane (0.20 m x 0.05 m x 0.8 mm) conforms around
      a fragile object on a rigid support with friction coefficient 0.70.
      Slew-limited HV actuation (max 6.1 kV) controls membrane elongation.
      Contact-force redistribution caps per-contact normal force.
      Tangential disturbance 5.8 N applied during middle third [6.67, 13.33] s.
      Runs at 500 Hz for 20 s. Material parameters not specified by the
      requirement are estimated and labeled as such.")
  );
end ElectroSoftGraspF;