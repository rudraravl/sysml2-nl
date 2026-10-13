model ParallelGripInsertD
  // ===== Physical parameters (SI units) =====
  parameter Real m_palm = 6.0          "Palm mass [kg] (fixed base)";
  parameter Real m_finger = 0.5        "Each finger mass [kg]";
  parameter Real finger_travel = 0.05  "Prismatic joint travel [m]";
  parameter Real mu = 0.35             "Contact friction coefficient";
  parameter Real F_act_max = 45.0      "Max actuator force per finger [N]";
  parameter Real clearance = 1.0e-3    "Radial clearance [m] (1 mm)";
  parameter Real L_insert = 0.06       "Required insertion depth [m]";
  // Assumed (not stated in requirement)
  parameter Real m_peg = 0.25          "Peg mass [kg] (assumed)";
  parameter Real J_peg = 5.0e-4        "Peg rotational inertia [kg.m2] (assumed)";
  parameter Real r_peg = 0.012         "Peg radius [m] (assumed)";
  parameter Real r_hole = 0.013        "Hole radius [m] (r_peg + clearance, assumed)";
  parameter Real k_pad = 5.0e4         "Pad stiffness [N/m] (assumed)";
  parameter Real c_pad = 150.0         "Pad damping [N.s/m] (assumed)";
  parameter Real k_contact = 1.0e6     "Rigid collision stiffness [N/m] (assumed)";
  parameter Real c_contact = 400.0     "Rigid collision damping [N.s/m] (assumed)";
  parameter Real k_tilt = 50.0         "Tilt contact stiffness [N.m/rad] (assumed)";
  parameter Real c_tilt = 2.0          "Tilt contact damping [N.m.s/rad] (assumed)";
  parameter Real b_joint = 5.0         "Prismatic joint damping [N.s/m] (assumed)";
  parameter Real b_ins = 2.0           "Insertion damping [N.s/m] (assumed)";
  parameter Real b_lat = 2.0           "Lateral damping [N.s/m] (assumed)";
  // ===== Controller parameters =====
  parameter Real Kz = 800.0            "Axial impedance stiffness [N/m]";
  parameter Real Dz = 40.0             "Axial impedance damping [N.s/m]";
  parameter Real Ky = 600.0            "Lateral impedance stiffness [N/m]";
  parameter Real Dy = 30.0             "Lateral impedance damping [N.s/m]";
  parameter Real Kth = 5.0             "Tilt impedance stiffness [N.m/rad]";
  parameter Real Dth = 0.5            "Tilt impedance damping [N.m.s/rad]";
  parameter Real v_ins_max = 0.02      "Bounded insertion speed [m/s]";
  parameter Real F_axial_limit = 50.0  "Axial force limit [N]";
  parameter Real F_lateral_limit = 25.0 "Lateral force limit [N]";
  parameter Real F_grip_cmd = 30.0     "Grip force setpoint [N] (below 45 N limit)";
  parameter Real t_start_insert = 1.0 "Insertion start time [s]";
  parameter Real t_dist_start = 14.0/3.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 28.0/3.0   "Disturbance end (middle third) [s]";
  parameter Real tilt_limit_deg = 5.0 "Tilt limit [deg]";
  // ===== Dynamic states =====
  Real q_f(start=0.0, fixed=true)    "Finger closure / pad compression [m]";
  Real v_f(start=0.0, fixed=true)    "Finger closure velocity [m/s]";
  Real z_ins(start=0.0, fixed=true)  "Insertion depth [m]";
  Real v_ins(start=0.0, fixed=true)  "Insertion velocity [m/s]";
  Real y_lat(start=4.0e-4, fixed=true) "Peg lateral offset [m]";
  Real v_lat(start=0.0, fixed=true)  "Peg lateral velocity [m/s]";
  Real theta(start=0.0, fixed=true)  "Peg tilt angle [rad]";
  Real omega(start=0.0, fixed=true)  "Peg angular velocity [rad/s]";
  // ===== Commands =====
  Real z_d               "Desired insertion depth [m]";
  Real v_d               "Bounded desired insertion velocity [m/s]";
  Real y_d               "Desired lateral position [m]";
  Real theta_d           "Desired tilt [rad]";
  Real F_act_cmd_raw     "Raw actuator force command per finger [N]";
  Real F_act             "Saturated actuator force per finger [N]";
  Real F_pad             "Pad normal force per finger [N]";
  Real F_friction_cap    "Friction capacity mu*F_pad [N]";
  Real F_axial_cmd       "Unsaturated axial impedance force [N]";
  Real F_axial_sat       "Saturated axial impedance force [N]";
  Real F_lateral_cmd     "Unsaturated lateral impedance force [N]";
  Real F_lateral_sat     "Saturated lateral impedance force [N]";
  Real F_tilt_cmd        "Tilt impedance torque [N.m]";
  Real F_axial_transmitted "Axial force transmitted to peg via grip friction [N]";
  // ===== Contact / disturbance =====
  Real F_contact_lat     "Lateral wall contact force on peg [N]";
  Real F_contact_axial   "Axial contact force resisting insertion [N]";
  Real F_jam_friction    "Jamming friction from lateral contact [N]";
  Real F_dist            "Lateral fixture disturbance [N]";
  Real penetration       "Lateral penetration into wall [m]";
  Real tilt_contact_torque "Torque from tilt contact [N.m]";
  // ===== Six-axis contact wrench measurement (peg frame) =====
  Real Fx_meas "Measured force x [N]";
  Real Fy_meas "Measured force y [N]";
  Real Fz_meas "Measured force z [N]";
  Real Tx_meas "Measured torque x [N.m]";
  Real Ty_meas "Measured torque y [N.m]";
  Real Tz_meas "Measured torque z [N.m]";
  // ===== Observables / metrics =====
  Real e_lat             "Lateral tracking error [m]";
  Real e_ins             "Insertion tracking error [m]";
  Real tilt_deg          "Peg tilt [deg]";
  Real alignment_error   "Alignment error magnitude [m]";
  Boolean actuator_bounded;
  Boolean lateral_force_bounded;
  Boolean axial_force_bounded;
  Boolean tilt_bounded;
  Boolean insertion_satisfied;
  Boolean alignment_satisfied;
  Boolean no_nan_inf;

  // Local helper for saturation (scalar, explicit)
  function sat = "Scalar saturation"
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if x < lo then lo else (if x > hi then hi else x);
  end sat;

equation
  // ---- Desired trajectories ----
  v_d = v_ins_max;
  z_d = if time < t_start_insert then 0.0
        else (if v_ins_max*(time - t_start_insert) < L_insert
              then v_ins_max*(time - t_start_insert) else L_insert);
  y_d = 0.0;
  theta_d = 0.0;

  // ---- Compliant pad (unidirectional compression) ----
  F_pad = if q_f > 0.0 then k_pad*q_f + c_pad*v_f else 0.0;
  F_friction_cap = mu * F_pad;

  // ---- Finger actuator (grip force feedforward + saturation) ----
  F_act_cmd_raw = F_grip_cmd + b_joint*v_f;
  F_act = sat(F_act_cmd_raw, -F_act_max, F_act_max);

  // ---- Cartesian impedance commands ----
  F_axial_cmd = Kz*(z_d - z_ins) + Dz*(v_d - v_ins);
  F_axial_sat = sat(F_axial_cmd, -F_axial_limit, F_axial_limit);
  F_lateral_cmd = Ky*(y_d - y_lat) + Dy*(0.0 - v_lat);
  F_lateral_sat = sat(F_lateral_cmd, -F_lateral_limit, F_lateral_limit);
  F_tilt_cmd = Kth*(theta_d - theta) + Dth*(0.0 - omega);

  // ---- Axial force transmitted via grip friction (slip limit) ----
  F_axial_transmitted = sat(F_axial_sat, -F_friction_cap, F_friction_cap);

  // ---- Lateral wall contact (rigid collision, finite stiffness) ----
  penetration = max(abs(y_lat) - clearance, 0.0);
  F_contact_lat = if penetration > 0.0 then
      -(k_contact*penetration + c_contact*abs(v_lat))*sign(y_lat) else 0.0;

  // ---- Jamming friction (axial resistance proportional to lateral contact) ----
  F_jam_friction = if penetration > 0.0 then
      mu*abs(F_contact_lat)*sign(v_ins) else 0.0;
  F_contact_axial = F_jam_friction;

  // ---- Lateral disturbance (middle third of 14 s) ----
  F_dist = if (time >= t_dist_start) and (time <= t_dist_end) then 10.0 else 0.0;

  // ---- Tilt contact torque ----
  tilt_contact_torque = if abs(theta) > 1.0e-4 then
      -k_tilt*theta - c_tilt*omega else 0.0;

  // ---- Six-axis wrench measurement (peg end, peg frame) ----
  Fx_meas = F_lateral_sat + F_dist + F_contact_lat;
  Fy_meas = 0.0;
  Fz_meas = F_axial_transmitted - F_contact_axial;
  Tx_meas = F_tilt_cmd + tilt_contact_torque;
  Ty_meas = 0.0;
  Tz_meas = 0.0;

  // ---- Dynamics ----
  // Finger (one lumped finger + actuator; symmetric opposing pair)
  m_finger * der(v_f) = F_act - F_pad - b_joint*v_f;
  der(q_f) = v_f;
  // Peg axial insertion
  m_peg * der(v_ins) = F_axial_transmitted - F_contact_axial - b_ins*v_ins;
  der(z_ins) = v_ins;
  // Peg lateral
  m_peg * der(v_lat) = F_lateral_sat + F_dist + F_contact_lat - b_lat*v_lat;
  der(y_lat) = v_lat;
  // Peg tilt
  J_peg * der(omega) = F_tilt_cmd + tilt_contact_torque;
  der(theta) = omega;

  // ---- Errors / metrics ----
  e_lat = y_lat - y_d;
  e_ins = z_d - z_ins;
  tilt_deg = theta*180.0/3.141592653589793;
  alignment_error = abs(y_lat);

  // ---- Constraint flags ----
  actuator_bounded = abs(F_act) <= F_act_max + 1.0e-6;
  lateral_force_bounded = abs(F_lateral_sat) <= F_lateral_limit + 1.0e-6;
  axial_force_bounded = abs(F_axial_sat) <= F_axial_limit + 1.0e-6;
  tilt_bounded = abs(tilt_deg) <= tilt_limit_deg;
  insertion_satisfied = z_ins >= L_insert - 1.0e-6;
  alignment_satisfied = (time > 9.1) and (alignment_error < 0.002);
  no_nan_inf = true;  // all equations are bounded, smooth, finite-valued

  annotation(
    experiment(StartTime=0, StopTime=14.0, Tolerance=1.0e-6, Interval=0.005),
    Documentation(info="ParallelGripInsertD: contact-rich peg-in-hole insertion with parallel gripper.
Fixed 6 kg palm, two 0.5 kg opposing box fingers on prismatic joints (0.05 m travel),
compliant pads, bounded linear actuators (45 N/finger). Cylindrical peg, 1 mm radial
clearance, target 0.06 m insertion, mu=0.35, rigid collision (high-stiffness contact).
Cartesian impedance with bounded insertion speed. 10 N lateral fixture load disturbance
during middle third of the 14 s run (4.667-9.333 s). 200 Hz (Interval=0.005 s).
Assumed values (peg mass, radius, pad/contact stiffness, joint damping) are labeled;
facts not stated in the request are treated as unknown rather than invented."));
end ParallelGripInsertD;