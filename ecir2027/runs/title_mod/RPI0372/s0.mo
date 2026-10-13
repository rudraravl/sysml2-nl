model ParallelGripInsertF
  "Parallel grip peg-in-hole insertion with Cartesian impedance control and bounded actuators"

  // ===== Palm (fixed base of gripper assembly) =====
  parameter Real m_palm = 6.0 "Palm mass [kg]";

  // ===== Fingers =====
  parameter Real m_finger = 0.5 "Each finger mass [kg]";
  parameter Real finger_travel = 0.05 "Prismatic joint travel [m]";
  parameter Real pad_k = 8000.0 "Compliant pad stiffness [N/m] (assumption)";
  parameter Real pad_c = 30.0 "Compliant pad damping [N.s/m] (assumption)";

  // ===== Peg and hole =====
  parameter Real m_peg = 0.15 "Peg mass [kg] (assumption, not stated)";
  parameter Real peg_radius = 0.01 "Peg radius [m] (assumption, not stated)";
  parameter Real clearance = 0.001 "Hole radial clearance [m]";
  parameter Real I_peg = 1.0e-4 "Peg moment of inertia [kg.m2] (assumption)";
  parameter Real hole_k = 12000.0 "Hole wall stiffness [N/m] (assumption)";
  parameter Real hole_c = 60.0 "Hole wall damping [N.s/m] (assumption)";

  // ===== Actuation =====
  parameter Real F_max = 54.9 "Max actuator force per finger [N]";

  // ===== Contact =====
  parameter Real mu = 0.35 "Contact friction coefficient";

  // ===== Disturbance =====
  parameter Real F_dist = 14.5 "Lateral fixture load disturbance [N]";

  // ===== Impedance control gains (assumptions) =====
  parameter Real K_imp_z = 600.0 "Axial impedance stiffness [N/m]";
  parameter Real D_imp_z = 30.0 "Axial impedance damping [N.s/m]";
  parameter Real K_imp_y = 300.0 "Lateral impedance stiffness [N/m]";
  parameter Real D_imp_y = 15.0 "Lateral impedance damping [N.s/m]";
  parameter Real v_insert_max = 0.008 "Bounded insertion speed [m/s]";

  // ===== Targets =====
  parameter Real z_target = 0.06 "Target insertion depth [m]";
  parameter Real grip_half_gap = 0.0105 "Commanded half-gap between fingers [m] (assumption)";

  // ===== Force limits (assumptions where not stated) =====
  parameter Real F_lateral_limit = 20.0 "Lateral force limit [N] (assumption)";
  parameter Real F_axial_limit = 54.9 "Axial force limit [N]";
  parameter Real tilt_limit = 0.05 "Peg tilt limit [rad] (assumption)";

  // ===== Simulation =====
  parameter Real f_sample = 500.0 "Control/sample frequency [Hz]";
  parameter Real dt = 1.0 / f_sample "Control timestep [s]";
  parameter Real t_end = 20.0 "Total simulation time [s]";

  // ===== States: finger closure =====
  Real x_f1(start = -0.02) "Left finger position [m]";
  Real x_f2(start = 0.02) "Right finger position [m]";
  Real v_f1(start = 0.0) "Left finger velocity [m/s]";
  Real v_f2(start = 0.0) "Right finger velocity [m/s]";

  // ===== States: peg pose =====
  Real z(start = 0.0) "Peg insertion depth [m]";
  Real y(start = 0.0) "Peg lateral offset [m]";
  Real vz(start = 0.0) "Peg axial velocity [m/s]";
  Real vy(start = 0.0) "Peg lateral velocity [m/s]";
  Real theta(start = 0.0) "Peg tilt [rad]";
  Real omega(start = 0.0) "Peg angular velocity [rad/s]";

  // ===== Actuator commands (bounded) =====
  Real F_act1 "Actuator force on finger 1 [N]";
  Real F_act2 "Actuator force on finger 2 [N]";

  // ===== Contact and wrench =====
  Real F_pad1 "Pad normal force finger 1 [N]";
  Real F_pad2 "Pad normal force finger 2 [N]";
  Real F_grip "Total grip normal force [N]";
  Real F_friction_z "Friction-driven axial force on peg [N]";
  Real F_hole_y "Hole wall lateral contact force [N]";
  Real F_hole_z "Hole bottom axial contact force [N]";
  Real F_imp_z "Impedance axial command force [N]";
  Real F_imp_y "Impedance lateral command force [N]";
  Real F_lateral "Applied lateral disturbance [N]";

  // ===== Six-axis wrench (simplified projection) =====
  Real W_x "Grip-axis wrench [N]";
  Real W_y "Lateral wrench [N]";
  Real W_z "Axial wrench [N]";

  // ===== Commands =====
  Real z_cmd "Commanded insertion depth [m]";
  Real y_cmd "Commanded lateral position [m]";

  // ===== Verification =====
  Real tracking_error "Primary alignment tracking error [m]";
  Boolean actuator_bound_ok;
  Boolean lateral_force_ok;
  Boolean axial_force_ok;
  Boolean tilt_ok;
  Boolean insertion_depth_ok;
  Boolean tracking_ok;
  Boolean no_nan_ok;
  Boolean all_checks_pass;

equation
  // --- Disturbance: 14.5 N during middle third of run ---
  F_lateral = if (time > t_end / 3.0 and time < 2.0 * t_end / 3.0) then F_dist else 0.0;

  // --- Commanded trajectory: bounded-speed ramp to 0.06 m ---
  z_cmd = if (v_insert_max * time < z_target) then v_insert_max * time else z_target;
  y_cmd = 0.0;

  // --- Impedance control commands ---
  F_imp_z = K_imp_z * (z_cmd - z) - D_imp_z * vz;
  F_imp_y = K_imp_y * (y_cmd - y) - D_imp_y * vy;

  // --- Finger pad contact forces (compliant) ---
  // Finger 1 closes from left; contact when gap closes to peg radius
  F_pad1 = if (x_f1 + peg_radius + y > 0.0) then
             pad_k * (x_f1 + peg_radius + y) + pad_c * (v_f1 + vy)
           else 0.0;
  // Finger 2 closes from right
  F_pad2 = if (peg_radius - x_f2 - y > 0.0) then
             pad_k * (peg_radius - x_f2 - y) - pad_c * (v_f2 - vy)
           else 0.0;

  F_grip = F_pad1 + F_pad2;

  // --- Friction-limited axial insertion force ---
  // Friction can push peg down; limited by mu * normal force
  F_friction_z = mu * F_grip;

  // --- Hole wall contact (lateral bounds at +/- clearance) ---
  F_hole_y = if (y > clearance) then
               -hole_k * (y - clearance) - hole_c * vy
             elseif (y < -clearance) then
               -hole_k * (y + clearance) - hole_c * vy
             else 0.0;

  // --- Hole bottom contact (axial stop at z_target) ---
  F_hole_z = if (z > z_target) then
               -hole_k * (z - z_target) - hole_c * vz
             else 0.0;

  // --- Actuator forces: closure control, bounded to F_max ---
  // Drive fingers toward commanded half-gap
  F_act1 = if (pad_k * (grip_half_gap + x_f1) - D_imp_y * v_f1 > F_max) then F_max
           elseif (pad_k * (grip_half_gap + x_f1) - D_imp_y * v_f1 < -F_max) then -F_max
           else pad_k * (grip_half_gap + x_f1) - D_imp_y * v_f1;

  F_act2 = if (pad_k * (grip_half_gap - x_f2) - D_imp_y * v_f2 > F_max) then F_max
           elseif (pad_k * (grip_half_gap - x_f2) - D_imp_y * v_f2 < -F_max) then -F_max
           else pad_k * (grip_half_gap - x_f2) - D_imp_y * v_f2;

  // --- Finger dynamics ---
  m_finger * der(v_f1) = F_act1 - F_pad1;
  m_finger * der(v_f2) = -F_act2 + F_pad2;
  der(x_f1) = v_f1;
  der(x_f2) = v_f2;

  // --- Peg axial dynamics ---
  // Impedance force drives insertion, friction transmits through grip,
  // limited by available friction
  m_peg * der(vz) = min(F_imp_z, F_friction_z) + F_hole_z;
  der(z) = vz;

  // --- Peg lateral dynamics ---
  m_peg * der(vy) = F_lateral + F_hole_y + F_imp_y;
  der(y) = vy;

  // --- Peg tilt dynamics (simplified: disturbance-induced) ---
  I_peg * der(omega) = 0.5 * (F_pad2 - F_pad1) * peg_radius - 0.5 * F_hole_y * peg_radius;
  der(theta) = omega;

  // --- Wrench measurements ---
  W_x = F_grip;
  W_y = F_lateral + F_hole_y;
  W_z = min(F_imp_z, F_friction_z) + F_hole_z;

  // --- Tracking error ---
  tracking_error = abs(y_cmd - y);

  // --- Verification criteria ---
  actuator_bound_ok = (abs(F_act1) <= F_max + 1.0) and (abs(F_act2) <= F_max + 1.0);
  lateral_force_ok = abs(W_y) <= F_lateral_limit;
  axial_force_ok = abs(W_z) <= F_axial_limit;
  tilt_ok = abs(theta) <= tilt_limit;
  insertion_depth_ok = (z >= 0.06 - 0.0005);
  tracking_ok = if (time > 13.0) then (tracking_error < 0.002) else true;
  no_nan_ok = (abs(z) < 1.0e5) and (abs(y) < 1.0e5) and (abs(vz) < 1.0e5)
              and (abs(vy) < 1.0e5) and (abs(theta) < 1.0e5)
              and (abs(F_act1) < 1.0e5) and (abs(F_act2) < 1.0e5)
              and (abs(W_x) < 1.0e5) and (abs(W_y) < 1.0e5) and (abs(W_z) < 1.0e5);
  all_checks_pass = actuator_bound_ok and lateral_force_ok and axial_force_ok
                    and tilt_ok and insertion_depth_ok and tracking_ok and no_nan_ok;

  // --- Finger travel guards (soft stop) ---
  // Enforce travel limits via additional reaction when exceeded
  when (x_f1 < -finger_travel / 2.0) then
    reinit(x_f1, -finger_travel / 2.0);
    reinit(v_f1, 0.0);
  end when;
  when (x_f1 > finger_travel / 2.0) then
    reinit(x_f1, finger_travel / 2.0);
    reinit(v_f1, 0.0);
  end when;
  when (x_f2 < -finger_travel / 2.0) then
    reinit(x_f2, -finger_travel / 2.0);
    reinit(v_f2, 0.0);
  end when;
  when (x_f2 > finger_travel / 2.0) then
    reinit(x_f2, finger_travel / 2.0);
    reinit(v_f2, 0.0);
  end when;

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1.0e-6, Interval = 0.002),
    Documentation(info = "Parallel grip peg-in-hole insertion. Peg: 1 mm radial clearance, target 0.06 m depth. Palm 6 kg fixed, two 0.5 kg fingers on 0.05 m prismatic joints with compliant pads. Actuators bounded at 54.9 N/finger. Friction 0.35. 14.5 N lateral disturbance during middle third. Cartesian impedance with bounded insertion speed. 500 Hz, 20 s. Parameters not stated in the requirement are labeled as assumptions."),
    Diagram(coordinateSystem(extent = {{-100, -100}, {100, 100}}))
  );
end ParallelGripInsertF;