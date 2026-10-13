model CartesianToolInsertD
  "Contact-rich peg-in-hole insertion with Cartesian impedance control"
  import Modelica.Constants.pi;

  // ===== Physical parameters (from requirement) =====
  parameter Real m_carriage = 2.5 "Tool carriage mass [kg]";
  parameter Real F_max = 350.0 "Per-axis actuator force limit [N]";
  parameter Real x_range = 0.10 "X travel half-range [m]";
  parameter Real y_range = 0.10 "Y travel half-range [m]";
  parameter Real z_range = 0.30 "Z travel half-range [m]";
  parameter Real clearance = 0.001 "Radial clearance peg-to-hole [m]";
  parameter Real mu_contact = 0.35 "Contact friction coefficient";
  parameter Real insertion_target = 0.06 "Required insertion depth [m]";

  // ===== Controller parameters =====
  parameter Real K_imp = 10000.0 "Impedance stiffness [N/m]";
  parameter Real D_imp = 120.0 "Impedance damping [N.s/m]";
  parameter Real v_insert_max = 0.01 "Bounded insertion speed [m/s]";
  parameter Real F_disturb = 10.0 "Lateral disturbance amplitude [N]";
  parameter Real f_control = 200.0 "Control rate [Hz]";

  // ===== Contact and compliant-wrist parameters (design assumptions — not stated in requirement) =====
  parameter Real k_contact = 5.0e5 "Contact stiffness for rigid-collision penalty [N/m]";
  parameter Real k_tilt = 50.0 "Wrist torsional stiffness [N.m/rad]";
  parameter Real d_tilt = 0.5 "Wrist torsional damping [N.m.s/rad]";
  parameter Real I_peg = 0.005 "Peg rotational inertia about wrist [kg.m2]";
  parameter Real L_peg = 0.05 "Peg length from wrist to tip [m]";
  parameter Real z_smooth = 0.001 "Hole-entry transition width [m]";
  parameter Real v_reg = 0.001 "Friction velocity regularization [m/s]";

  // ===== Carriage translational states =====
  Real x(start=0.03, fixed=true) "Carriage X position [m]";
  Real y(start=0.02, fixed=true) "Carriage Y position [m]";
  Real z(start=0.08, fixed=true) "Carriage Z position [m]";
  Real vx(start=0, fixed=true) "Carriage X velocity [m/s]";
  Real vy(start=0, fixed=true) "Carriage Y velocity [m/s]";
  Real vz(start=0, fixed=true) "Carriage Z velocity [m/s]";

  // ===== Peg tilt states (compliant wrist) =====
  Real theta_x(start=0, fixed=true) "Peg tilt about X [rad]";
  Real theta_y(start=0, fixed=true) "Peg tilt about Y [rad]";
  Real omega_x(start=0, fixed=true) "Peg angular velocity X [rad/s]";
  Real omega_y(start=0, fixed=true) "Peg angular velocity Y [rad/s]";

  // ===== Continuous trajectory references =====
  Real x_des "Desired X [m]";
  Real y_des "Desired Y [m]";
  Real z_des "Desired Z [m]";
  Real vx_des "Desired X velocity [m/s]";
  Real vy_des "Desired Y velocity [m/s]";
  Real vz_des "Desired Z velocity [m/s]";

  // ===== Discrete controller references (200 Hz sampling) =====
  discrete Real x_d(start=0.03) "Sampled desired X [m]";
  discrete Real y_d(start=0.02) "Sampled desired Y [m]";
  discrete Real z_d(start=0.08) "Sampled desired Z [m]";
  discrete Real vx_d(start=0) "Sampled desired vx [m/s]";
  discrete Real vy_d(start=0) "Sampled desired vy [m/s]";
  discrete Real vz_d(start=0) "Sampled desired vz [m/s]";

  // ===== Controller outputs and actuator forces =====
  Real Fx_cmd "Unsaturated X force command [N]";
  Real Fy_cmd "Unsaturated Y force command [N]";
  Real Fz_cmd "Unsaturated Z force command [N]";
  Real Fx_act "Saturated X actuator force [N]";
  Real Fy_act "Saturated Y actuator force [N]";
  Real Fz_act "Saturated Z actuator force [N]";

  // ===== Contact wrench (six-axis) =====
  Real F_cx "Contact force X [N]";
  Real F_cy "Contact force Y [N]";
  Real F_cz "Contact force Z [N]";
  Real M_cx "Contact moment about X [N.m]";
  Real M_cy "Contact moment about Y [N.m]";
  Real M_cz "Contact moment about Z [N.m]";

  // ===== Six-axis wrench sensor =====
  Real Fx_sense "Sensed force X [N]";
  Real Fy_sense "Sensed force Y [N]";
  Real Fz_sense "Sensed force Z [N]";
  Real Mx_sense "Sensed moment X [N.m]";
  Real My_sense "Sensed moment Y [N.m]";
  Real Mz_sense "Sensed moment Z [N.m]";

  // ===== Disturbance =====
  Real F_dist_x "Lateral fixture load disturbance X [N]";

  // ===== Contact model intermediate variables =====
  Real r "Radial distance from hole center [m]";
  Real penetration "Lateral wall penetration [m]";
  Real F_normal "Normal contact force magnitude [N]";
  Real F_fric_z "Axial friction force [N]";
  Real r_hat_x "Unit vector X toward hole center";
  Real r_hat_y "Unit vector Y toward hole center";
  Real hole_factor "Hole-entry gating factor [0,1]";

  // ===== Diagnostics =====
  Real radial_pos "Radial position [m]";
  Real insertion_depth "Current insertion depth [m]";
  Real tracking_error "X-Y alignment error [m]";
  Real peg_tilt_mag "Peg tilt magnitude [rad]";
  Real F_lateral "Lateral contact force magnitude [N]";
  Real F_axial "Axial contact force magnitude [N]";

protected
  parameter Real dt_sample = 1.0 / f_control "Control sample period [s]";
  parameter Real t_dist_start = 14.0 / 3.0 "Disturbance start — middle third [s]";
  parameter Real t_dist_end = 2.0 * 14.0 / 3.0 "Disturbance end — middle third [s]";

equation
  // ===== Trajectory generation =====
  // Phase 1 (0–4 s): Smooth approach via cosine blend from initial offset to alignment (0,0,0)
  // Phase 2 (4–10 s): Insertion at bounded speed v_insert_max
  // Phase 3 (10–14 s): Hold at final insertion depth
  if time < 4.0 then
    x_des = 0.03 * 0.5 * (1.0 + cos(pi * time / 4.0));
    y_des = 0.02 * 0.5 * (1.0 + cos(pi * time / 4.0));
    z_des = 0.08 * 0.5 * (1.0 + cos(pi * time / 4.0));
    vx_des = -0.03 * 0.5 * (pi / 4.0) * sin(pi * time / 4.0);
    vy_des = -0.02 * 0.5 * (pi / 4.0) * sin(pi * time / 4.0);
    vz_des = -0.08 * 0.5 * (pi / 4.0) * sin(pi * time / 4.0);
  elseif time < 10.0 then
    x_des = 0.0;
    y_des = 0.0;
    z_des = -v_insert_max * (time - 4.0);
    vx_des = 0.0;
    vy_des = 0.0;
    vz_des = -v_insert_max;
  else
    x_des = 0.0;
    y_des = 0.0;
    z_des = -insertion_target;
    vx_des = 0.0;
    vy_des = 0.0;
    vz_des = 0.0;
  end if;

  // ===== 200 Hz discrete controller sampling =====
  when sample(0, dt_sample) then
    x_d = x_des;
    y_d = y_des;
    z_d = z_des;
    vx_d = vx_des;
    vy_d = vy_des;
    vz_d = vz_des;
  end when;

  // ===== Cartesian impedance control law =====
  Fx_cmd = K_imp * (x_d - x) + D_imp * (vx_d - vx);
  Fy_cmd = K_imp * (y_d - y) + D_imp * (vy_d - vy);
  Fz_cmd = K_imp * (z_d - z) + D_imp * (vz_d - vz);

  // ===== Actuator force saturation (350 N per axis) =====
  Fx_act = max(-F_max, min(F_max, Fx_cmd));
  Fy_act = max(-F_max, min(F_max, Fy_cmd));
  Fz_act = max(-F_max, min(F_max, Fz_cmd));

  // ===== Contact model: rigid collision penalty =====
  // Hole center at (0,0), hole top at z=0; peg enters when z<0
  r = sqrt(x * x + y * y + 1e-12);
  r_hat_x = -x / r;
  r_hat_y = -y / r;

  // Smooth hole-entry gating (avoids discontinuity at z=0)
  hole_factor = 0.5 * (1.0 - tanh(z / z_smooth));

  // Smooth penetration = max(0, r - clearance) * hole_factor (regularized)
  penetration = 0.5 * ((r - clearance) + sqrt((r - clearance) * (r - clearance) + 1e-10)) * hole_factor;

  // Normal contact force (penalty stiffness represents rigid collision)
  F_normal = k_contact * penetration;

  // Lateral contact forces directed toward hole center
  F_cx = F_normal * r_hat_x;
  F_cy = F_normal * r_hat_y;

  // Axial Coulomb friction (regularized via tanh to avoid discontinuity)
  F_fric_z = -mu_contact * F_normal * tanh(vz / v_reg);
  F_cz = F_fric_z;

  // Contact moments: force at peg tip, moment about wrist pivot at carriage
  M_cx = F_cy * L_peg;
  M_cy = -F_cx * L_peg;
  M_cz = 0.0;

  // ===== Disturbance: 10 N lateral load during middle third of 14 s =====
  F_dist_x = if time >= t_dist_start and time <= t_dist_end then F_disturb else 0.0;

  // ===== Six-axis wrench sensor (measured at tool flange) =====
  Fx_sense = F_cx;
  Fy_sense = F_cy;
  Fz_sense = F_cz;
  Mx_sense = M_cx;
  My_sense = M_cy;
  Mz_sense = M_cz;

  // ===== Carriage translational dynamics =====
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  m_carriage * der(vx) = Fx_act + F_cx + F_dist_x;
  m_carriage * der(vy) = Fy_act + F_cy;
  m_carriage * der(vz) = Fz_act + F_cz;

  // ===== Peg tilt dynamics (compliant wrist) =====
  der(theta_x) = omega_x;
  der(theta_y) = omega_y;
  I_peg * der(omega_x) = M_cx - k_tilt * theta_x - d_tilt * omega_x;
  I_peg * der(omega_y) = M_cy - k_tilt * theta_y - d_tilt * omega_y;

  // ===== Diagnostics =====
  radial_pos = r;
  insertion_depth = max(0.0, -z);
  tracking_error = sqrt((x_des - x) * (x_des - x) + (y_des - y) * (y_des - y) + 1e-12);
  peg_tilt_mag = sqrt(theta_x * theta_x + theta_y * theta_y + 1e-12);
  F_lateral = sqrt(F_cx * F_cx + F_cy * F_cy + 1e-12);
  F_axial = abs(F_cz);

  // ===== Requirement assertions =====
  // Actuator bounds
  assert(abs(Fx_act) <= F_max + 1e-6, "X actuator bound exceeded");
  assert(abs(Fy_act) <= F_max + 1e-6, "Y actuator bound exceeded");
  assert(abs(Fz_act) <= F_max + 1e-6, "Z actuator bound exceeded");

  // Travel bounds
  assert(abs(x) <= x_range + 1e-6, "X travel exceeded");
  assert(abs(y) <= y_range + 1e-6, "Y travel exceeded");
  assert(abs(z) <= z_range + 1e-6, "Z travel exceeded");

  // Lateral and axial force limits
  assert(F_lateral <= F_max, "Lateral contact force exceeds actuator limit");
  assert(F_axial <= F_max, "Axial contact force exceeds actuator limit");

  // Peg tilt bound
  assert(peg_tilt_mag < 0.1, "Peg tilt exceeds 0.1 rad");

  // Insertion depth requirement (checked near end of run)
  when time > 13.5 then
    assert(insertion_depth >= insertion_target, "Insertion depth target not achieved");
  end when;

  // Primary tracking error below 0.002 m alignment after 9.1 s
  when time > 9.1 then
    assert(tracking_error < 0.002, "Alignment error exceeds 0.002 m after 9.1 s");
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "CartesianToolInsertD: Contact-rich peg-in-hole insertion system.

  Embodiment: Three orthogonal prismatic axes move a 2.5 kg tool carriage over
  +/-0.10 m in X and Y and +/-0.30 m in Z. Three force-limited linear actuators
  (350 N per axis) provide Cartesian motion.

  Task: Align a cylindrical peg with a hole (1 mm radial clearance) and insert
  at least 0.06 m without jamming. Contact friction 0.35, rigid collision
  (penalty contact) for peg and fixture.

  Control: Cartesian impedance control with bounded insertion speed (0.01 m/s),
  200 Hz discrete sampling, 14 s run.

  Disturbance: 10 N lateral fixture load during middle third [4.67, 9.33] s.

  Sensing: Carriage position/velocity plus six-axis contact wrench at tool flange.

  Requirements enforced via assertions: actuator bounds, lateral/axial force
  limits, peg tilt, insertion depth >= 0.06 m, and X-Y tracking error < 0.002 m
  after 9.1 s. No NaN or infinite values expected from bounded, well-conditioned
  dynamics.

  Note: Peg length, wrist stiffness/damping, peg inertia, and contact stiffness
  are design assumptions — not specified in the requirement — chosen to produce
  well-conditioned, non-singular dynamics."));
end CartesianToolInsertD;