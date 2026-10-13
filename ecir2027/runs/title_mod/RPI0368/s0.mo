model ParallelGripInsertB
  "Parallel-gripper contact-rich peg-in-hole insertion with Cartesian impedance control."

  // ===== Parameters stated by requirement =====
  parameter Modelica.Units.SI.Mass m_palm = 6.0 "Fixed palm mass (supports fingers)";
  parameter Modelica.Units.SI.Mass m_finger = 0.5 "Mass of each opposing finger carriage";
  parameter Modelica.Units.SI.Length travel = 0.05 "Prismatic joint travel";
  parameter Modelica.Units.SI.Length c_clear = 0.001 "Hole radial clearance (1 mm)";
  parameter Modelica.Units.SI.Length z_target = 0.06 "Required minimum insertion depth";
  parameter Real F_max(unit="N") = 36.9 "Allowed finger actuator command magnitude per finger";
  parameter Real mu = 0.35 "Contact friction coefficient (pads and hole wall)";
  parameter Modelica.Units.SI.Force F_dist = 7.0 "Lateral fixture load disturbance amplitude";
  parameter Modelica.Units.SI.Time t_end = 10.0 "Mission duration";
  parameter Modelica.Units.SI.Frequency f_sample = 100.0 "Control/sensor trace rate";

  // ===== Nominal placeholder parameters (NOT specified by requirement) =====
  parameter Modelica.Units.SI.Mass m_peg = 0.2 "Peg mass (placeholder; unspecified)";
  parameter Modelica.Units.SI.Length r_peg = 0.01 "Peg radius (placeholder; unspecified)";
  parameter Modelica.Units.SI.Length d0 = 0.012 "Open half-gap (placeholder; unspecified)";
  parameter Real k_pad(unit="N/m") = 2.0e4 "Pad stiffness (placeholder)";
  parameter Real b_pad(unit="N.s/m") = 80.0 "Pad damping (placeholder)";
  parameter Real k_wall(unit="N/m") = 2.0e4 "Hole wall stiffness (placeholder)";
  parameter Real b_wall(unit="N.s/m") = 80.0 "Hole wall damping (placeholder)";
  parameter Modelica.Units.SI.Inertia I_peg = 1.0e-5 "Peg inertia about y (placeholder)";

  // Controller gains and limits (nominal)
  parameter Real kx(unit="N/m") = 5000.0 "Lateral impedance stiffness";
  parameter Real bx(unit="N.s/m") = 50.0 "Lateral impedance damping";
  parameter Real kz(unit="N/m") = 1000.0 "Axial impedance stiffness";
  parameter Real bz(unit="N.s/m") = 100.0 "Axial impedance damping";
  parameter Real kth(unit="N.m/rad") = 0.5 "Tilt impedance stiffness";
  parameter Real bth(unit="N.m.s/rad") = 0.05 "Tilt impedance damping";
  parameter Modelica.Units.SI.Velocity v_z_max = 0.01 "Bounded insertion speed (nominal)";
  parameter Modelica.Units.SI.Force F_grip_des = 25.0 "Desired grip force per finger";
  parameter Modelica.Units.SI.Force F_z_limit = 15.0 "Axial force limit";
  parameter Modelica.Units.SI.Force F_lat_limit = 12.0 "Lateral force limit";
  parameter Modelica.Units.SI.Torque M_limit = 0.2 "Tilt torque limit";
  parameter Modelica.Units.SI.Angle theta_limit = 0.02 "Peg tilt limit";
  parameter Real align_tol(unit="m") = 0.002 "Primary tracking alignment tolerance";
  parameter Modelica.Units.SI.Time t_align_check = 6.5 "Alignment check time";

  // ===== Dynamic states =====
  Real s1(start=0.0, fixed=true) "Left finger carriage position";
  Real vs1(start=0.0, fixed=true) "Left finger carriage velocity";
  Real s2(start=0.0, fixed=true) "Right finger carriage position";
  Real vs2(start=0.0, fixed=true) "Right finger carriage velocity";
  Real xpeg(start=0.0005, fixed=true) "Peg lateral position";
  Real vxpeg(start=0.0, fixed=true) "Peg lateral velocity";
  Real zpeg(start=0.0, fixed=true) "Peg insertion depth";
  Real vzpeg(start=0.0, fixed=true) "Peg axial velocity";
  Real theta(start=0.0, fixed=true) "Peg tilt about y";
  Real omega(start=0.0, fixed=true) "Peg angular velocity";

  // ===== Intermediate variables =====
  Real F_cmd1(unit="N") "Left finger commanded force";
  Real F_cmd2(unit="N") "Right finger commanded force";
  Real F_act1(unit="N") "Bounded left finger actuator force";
  Real F_act2(unit="N") "Bounded right finger actuator force";
  Real comp_L(unit="m") "Left pad compression";
  Real comp_R(unit="m") "Right pad compression";
  Real vel_L(unit="m/s") "Left pad compression rate";
  Real vel_R(unit="m/s") "Right pad compression rate";
  Real F_nL(unit="N") "Left pad normal force";
  Real F_nR(unit="N") "Right pad normal force";
  Real F_grip(unit="N") "Total clamp force";
  Real F_diff(unit="N") "Lateral differential command";
  Real F_z_cmd(unit="N") "Axial impedance command";
  Real F_z_friction(unit="N") "Total axial friction transmitted through pads";
  Real F_zL(unit="N") "Per-pad axial friction (left)";
  Real F_zR(unit="N") "Per-pad axial friction (right)";
  Real M_cmd(unit="N.m") "Tilt impedance command";
  Real M_act(unit="N.m") "Net moment on peg from pads";
  Real pen(unit="m") "Wall penetration";
  Real pen_rate(unit="m/s") "Wall penetration rate";
  Real F_wall_n(unit="N") "Wall normal magnitude (>=0)";
  Real F_wall_x(unit="N") "Wall lateral force on peg";
  Real F_wall_fric_z(unit="N") "Wall axial friction on peg";
  Real M_wall(unit="N.m") "Wall moment on peg from tilt";
  Real F_dist_active(unit="N") "Active disturbance force";
  Real v_z_des(unit="m/s") "Desired axial velocity";
  Real z_des(unit="m") "Desired axial position";
  Real sgx "Zero-safe sign of xpeg";
  Real sgvz "Zero-safe sign of vzpeg";
  Real sgth "Zero-safe sign of theta";

  // Six-axis contact wrench (peg-fixture), measured at peg center
  Real Fx_meas(unit="N");
  Real Fy_meas(unit="N");
  Real Fz_meas(unit="N");
  Real Mx_meas(unit="N.m");
  Real My_meas(unit="N.m");
  Real Mz_meas(unit="N.m");

  // Monitors
  Real tracking_error(unit="m") "abs(xpeg)";
  Boolean alignment_ok "Alignment within 0.002 m after 6.5 s";
  Boolean insertion_ok "Insertion depth >= 0.06 m";
  Boolean jammed "Peg jammed flag";
  Boolean bounds_ok "All actuator/force/tilt bounds respected";
  Boolean finite_ok "No NaN/infinite physical or control values";

  function sat "Symmetric saturation"
    input Real x;
    input Real lim;
    output Real y;
  algorithm
    y := if x > lim then lim else if x < -lim then -lim else x;
  end sat;

  function sgn "Zero-safe sign with deadzone epsilon"
    input Real x;
    input Real eps;
    output Real y;
  algorithm
    y := if x > eps then 1.0 else if x < -eps then -1.0 else 0.0;
  end sgn;

equation
  // Disturbance injected during middle third of mission
  F_dist_active = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then F_dist else 0.0;

  // Reference trajectory: bounded insertion speed
  v_z_des = v_z_max;
  z_des = if time*v_z_max <= z_target then time*v_z_max else z_target;

  // Cartesian impedance control with bounds
  F_diff = sat(kx*(0.0 - xpeg) + bx*(0.0 - vxpeg), F_lat_limit);
  F_z_cmd = sat(kz*(z_des - zpeg) + bz*(v_z_des - vzpeg), F_z_limit);
  M_cmd  = sat(kth*(0.0 - theta) + bth*(0.0 - omega), M_limit);

  // Finger actuator commands: common grip + lateral differential
  F_cmd1 = F_grip_des + F_diff;
  F_cmd2 = F_grip_des - F_diff;
  F_act1 = sat(F_cmd1, F_max);
  F_act2 = sat(F_cmd2, F_max);

  // Compliant pad contact (penalty-based rigid collision)
  comp_L = s1 - d0 - xpeg + r_peg;
  comp_R = s2 - d0 + xpeg + r_peg;
  vel_L  = vs1 - vxpeg;
  vel_R  = vs2 + vxpeg;
  F_nL = if comp_L > 0.0 then (k_pad*comp_L + b_pad*vel_L) else 0.0;
  F_nR = if comp_R > 0.0 then (k_pad*comp_R + b_pad*vel_R) else 0.0;
  F_grip = F_nL + F_nR;

  // Axial friction transmission (Coulomb-limited by mu*grip); split for tilt moment
  F_z_friction = sat(F_z_cmd, mu*F_grip);
  F_zL = sat(F_z_friction/2.0 - M_cmd/(2.0*r_peg), mu*F_nL);
  F_zR = sat(F_z_friction/2.0 + M_cmd/(2.0*r_peg), mu*F_nR);
  M_act = (F_zR - F_zL)*r_peg;

  // Finger carriage dynamics
  der(s1) = vs1;
  m_finger*der(vs1) = F_act1 - F_nL;
  der(s2) = vs2;
  m_finger*der(vs2) = F_act2 - F_nR;

  // Zero-safe signs (well-defined zero-error branches)
  sgx   = sgn(xpeg,   1.0e-9);
  sgvz  = sgn(vzpeg,  1.0e-6);
  sgth  = sgn(theta,  1.0e-9);

  // Hole wall contact (rigid collision via penalty); active only when inserted.
  // Tilt contributes additional effective penetration (jamming mechanism).
  pen = if (zpeg > 0.0 and (abs(xpeg) > c_clear or abs(theta)*zpeg*0.5 > 0.0))
        then max(0.0, abs(xpeg) - c_clear) + abs(theta)*zpeg*0.5
        else 0.0;
  pen_rate = if pen > 0.0 then (sgx*vxpeg) else 0.0;
  F_wall_n = if pen > 0.0 then max(0.0, k_wall*pen + b_wall*pen_rate) else 0.0;
  F_wall_x = -sgx * F_wall_n;
  F_wall_fric_z = -sgvz * mu * F_wall_n;
  M_wall = -F_wall_n * (zpeg*0.5) * sgth;

  // Peg dynamics (planar: lateral x, axial z, tilt about y)
  der(xpeg) = vxpeg;
  m_peg*der(vxpeg) = F_nL - F_nR + F_wall_x + F_dist_active;
  der(zpeg) = vzpeg;
  m_peg*der(vzpeg) = F_zL + F_zR + F_wall_fric_z;
  der(theta) = omega;
  I_peg*der(omega) = M_act + M_wall;

  // Six-axis contact wrench measurement (peg-fixture)
  Fx_meas = F_wall_x;
  Fy_meas = 0.0;
  Fz_meas = F_wall_fric_z;
  Mx_meas = 0.0;
  My_meas = M_wall;
  Mz_meas = 0.0;

  // Monitors and requirement checks
  tracking_error = abs(xpeg);
  alignment_ok = (time >= t_align_check) and (tracking_error < align_tol);
  insertion_ok = zpeg >= z_target - 1.0e-6;
  jammed = (F_wall_n > 1.0e-3) and (abs(vzpeg) < 1.0e-5) and (zpeg < z_target - 1.0e-4) and (F_z_cmd > 0.1);
  bounds_ok = (abs(F_act1) <= F_max + 1.0e-6) and (abs(F_act2) <= F_max + 1.0e-6)
              and (abs(F_diff) <= F_lat_limit + 1.0e-6) and (abs(F_z_cmd) <= F_z_limit + 1.0e-6)
              and (abs(M_cmd) <= M_limit + 1.0e-6) and (abs(theta) <= theta_limit + 1.0e-6)
              and (s1 >= -1.0e-6) and (s1 <= travel + 1.0e-6)
              and (s2 >= -1.0e-6) and (s2 <= travel + 1.0e-6);
  finite_ok = (xpeg == xpeg) and (zpeg == zpeg) and (theta == theta)
              and (F_act1 == F_act1) and (F_act2 == F_act2)
              and (vzpeg == vzpeg) and (omega == omega)
              and (abs(xpeg) < 1.0e6) and (abs(zpeg) < 1.0e6) and (abs(theta) < 1.0e6);

  annotation (
    Documentation(info="Contact-rich parallel-gripper peg-in-hole insertion.
Palm fixed (6 kg). Two 0.5 kg opposing fingers on prismatic joints (0.05 m travel)
with compliant pads and bounded linear actuators (36.9 N/finger). Friction 0.35.
1 mm radial clearance, target insertion 0.06 m. Cartesian impedance control with
bounded insertion speed. 7 N lateral fixture load disturbance injected during the
middle third of a 10 s mission at 100 Hz. Six-axis contact wrench and carriage
sensing are exposed. Synchronized state/command/sensor traces are available at
the declared 100 Hz rate via the simulation tool output sampling.
Unspecified physical parameters (peg mass/radius, pad/wall stiffness, gains) are
placeholder nominal values, not facts about the system."),
    experiment(StopTime=10.0, Interval=0.01));
end ParallelGripInsertB;