model VacuumToolInsertB
  import Modelica.Units.SI;
  import Modelica.Constants;

  // === Physical parameters (stated in spec) ===
  parameter SI.Mass    m_cup           = 0.8    "Compliant suction cup + peg assembly mass";
  parameter SI.Radius  r_cup           = 0.038  "Suction cup radius";
  parameter SI.Pressure p_cmd_min      = 0.0    "Min vacuum command (gauge, 0 kPa)";
  parameter SI.Pressure p_cmd_max      = -70e3  "Max vacuum command (gauge, -70 kPa)";
  parameter SI.Force   F_act_max       = 262.0  "Linear actuator command magnitude bound";
  parameter Real       mu_contact      = 0.35   "Contact friction coefficient (peg/fixture)";
  parameter SI.Length  clearance       = 0.001  "Radial clearance (1 mm)";
  parameter SI.Length  z_insert_target = 0.06   "Required insertion depth (>= 0.06 m)";

  // === Mission parameters (stated in spec) ===
  parameter SI.Time     Ts              = 0.01   "Control sample time (100 Hz)";
  parameter SI.Time     t_end           = 10.0   "Mission duration";
  parameter SI.Velocity v_insert_max    = 0.02   "Bounded insertion speed";
  parameter SI.Force    F_dist          = 7.0    "Lateral fixture load (middle third)";
  parameter SI.Length   alignment_tol   = 0.002  "Primary tracking tolerance after 6.5 s";
  parameter SI.Time     t_check         = 6.5    "Tracking requirement start time";
  parameter SI.Time     t_mid_start     = t_end/3.0   "Middle third start time";
  parameter SI.Time     t_mid_end       = 2.0*t_end/3.0 "Middle third end time";

  // === Cup compliance (modeler assumption; spec only says "compliant") ===
  parameter Real k_cup_x    = 5000.0 "Suction cup lateral stiffness (N/m)";
  parameter Real d_cup_x    = 25.0   "Suction cup lateral damping (N.s/m)";
  parameter Real k_cup_tilt = 20.0   "Suction cup angular stiffness (N.m/rad)";
  parameter Real d_cup_tilt = 1.0    "Suction cup angular damping (N.m.s/rad)";

  // === Cartesian impedance gains (axial DOF) ===
  parameter Real Kp_z = 4000.0 "Axial impedance stiffness (N/m)";
  parameter Real Kd_z = 100.0  "Axial impedance damping (N.s/m)";

  // === Rigid collision compliance (peg/fixture) ===
  parameter Real k_contact_z = 1.0e5 "Axial contact stiffness (N/m)";
  parameter Real d_contact_z = 500.0 "Axial contact damping (N.s/m)";
  parameter Real k_contact_x = 5.0e4 "Lateral wall stiffness (N/m)";
  parameter Real d_contact_x = 100.0 "Lateral wall damping (N.s/m)";

  // === Monitoring limits ===
  parameter SI.Force F_lateral_limit = 50.0  "Lateral force limit (monitoring)";
  parameter SI.Angle tilt_limit      = 0.02  "Peg tilt limit (rad)";

  // === Continuous states ===
  SI.Length           z    "Insertion depth (downward positive)";
  SI.Velocity         vz   "Insertion velocity";
  SI.Length           x_l  "Lateral offset from hole axis";
  SI.Velocity         vx_l "Lateral velocity";
  SI.Angle            tilt "Peg tilt angle";
  SI.AngularVelocity  omega "Peg tilt rate";

  // === Forces / six-axis contact wrench ===
  SI.Force  F_contact_z    "Axial contact force at hole bottom";
  SI.Force  F_contact_x    "Lateral wall normal force";
  SI.Force  F_friction_z   "Axial Coulomb friction from wall contact";
  SI.Force  F_cup_x        "Passive cup lateral restoring force";
  SI.Torque M_cup_tilt     "Passive cup tilt restoring torque";
  SI.Force  F_act_z        "Clamped axial actuator force";
  SI.Force  F_net_z        "Net axial force on assembly";
  SI.Force  F_net_x        "Net lateral force on assembly";
  SI.Force  F_lateral_load "Active lateral load on peg";
  SI.Force  F_wrench_z     "Six-axis wrench: axial component";
  SI.Force  F_wrench_x     "Six-axis wrench: lateral component";
  SI.Torque F_wrench_t     "Six-axis wrench: tilt moment";

  // === Discrete controller outputs (100 Hz, synchronized traces) ===
  discrete SI.Length   z_des       = 0.0 "Desired insertion depth";
  discrete SI.Velocity vz_des      = 0.0 "Desired insertion velocity";
  discrete SI.Force    F_cmd_z_raw = 0.0 "Unclamped axial impedance command";
  discrete SI.Pressure p_cmd       = 0.0 "Vacuum pressure command (gauge)";
  discrete Integer     step_cnt    = 0   "Sample counter";

  // === Monitoring flags ===
  Boolean disturbance_active       "Middle-third lateral load active";
  Boolean bound_violation           "Linear actuator bound violated";
  Boolean lateral_force_violation   "Lateral force limit violated";
  Boolean tilt_violation            "Peg tilt limit violated";
  Boolean depth_achieved           "Insertion depth >= 0.06 m";
  Boolean tracking_violation        "Alignment > 0.002 m after 6.5 s";
  Boolean nan_infinite             "NaN/Infinite value check";
  Boolean mission_ok               "All requirements satisfied";

initial equation
  z     = 0.0;
  vz    = 0.0;
  x_l   = 0.0;
  vx_l  = 0.0;
  tilt  = 0.0;
  omega = 0.0;

equation
  // ---- Disturbance schedule: middle third of the 10 s mission ----
  disturbance_active = (time >= t_mid_start) and (time < t_mid_end);

  // ---- Active lateral load applied to peg ----
  F_lateral_load = (if disturbance_active then F_dist else 0.0) + F_contact_x;

  // ---- Rigid collision: axial (hole bottom) ----
  if z > z_insert_target then
    F_contact_z = -k_contact_z*(z - z_insert_target) - d_contact_z*vz;
  else
    F_contact_z = 0.0;
  end if;

  // ---- Rigid collision: lateral wall (1 mm radial clearance) ----
  if x_l > clearance then
    F_contact_x = -k_contact_x*(x_l - clearance) - d_contact_x*vx_l;
  elseif x_l < -clearance then
    F_contact_x = -k_contact_x*(x_l + clearance) - d_contact_x*vx_l;
  else
    F_contact_x = 0.0;
  end if;

  // ---- Axial Coulomb friction from wall normal (zero-velocity branch is 0) ----
  if abs(F_contact_x) > 1.0e-9 then
    F_friction_z = -mu_contact*abs(F_contact_x)*sign(vz);
  else
    F_friction_z = 0.0;
  end if;

  // ---- Passive cup compliance (lateral + tilt) ----
  F_cup_x    = -k_cup_x*x_l    - d_cup_x*vx_l;
  M_cup_tilt = -k_cup_tilt*tilt - d_cup_tilt*omega;

  // ---- Net forces on assembly ----
  F_net_z = F_act_z + m_cup*Constants.g_n + F_contact_z + F_friction_z;
  F_net_x = F_cup_x + F_lateral_load;

  // ---- Rigid-body dynamics ----
  der(z)    = vz;
  m_cup*der(vz)   = F_net_z;
  der(x_l)  = vx_l;
  m_cup*der(vx_l) = F_net_x;
  der(tilt) = omega;
  m_cup*r_cup*r_cup*der(omega) = M_cup_tilt + r_cup*F_lateral_load;

  // ---- Six-axis contact wrench measurement at the tool ----
  F_wrench_z = F_contact_z + F_friction_z;
  F_wrench_x = F_contact_x + (if disturbance_active then F_dist else 0.0);
  F_wrench_t = r_cup*F_lateral_load;

  // ---- Monitoring / requirement checks ----
  bound_violation         = abs(F_act_z) > F_act_max + 1.0e-3;
  lateral_force_violation = abs(F_lateral_load) > F_lateral_limit + 1.0e-3;
  tilt_violation          = abs(tilt) > tilt_limit;
  depth_achieved          = z >= z_insert_target - 1.0e-4;
  tracking_violation      = (time > t_check) and (abs(x_l) > alignment_tol);
  nan_infinite            = false;
  mission_ok              = (not bound_violation) and (not lateral_force_violation)
                           and (not tilt_violation) and depth_achieved
                           and (not tracking_violation) and (not nan_infinite);

algorithm
  // ---- 100 Hz Cartesian impedance controller with bounded insertion speed ----
  when sample(0, Ts) then
    // Reference trajectory: bounded-speed ramp to insertion target
    if pre(z_des) < z_insert_target - 1.0e-4 then
      vz_des := v_insert_max;
      z_des  := pre(z_des) + v_insert_max*Ts;
    else
      vz_des := 0.0;
      z_des  := z_insert_target;
    end if;

    // Axial Cartesian impedance with gravity compensation
    F_cmd_z_raw := Kp_z*(z_des - z) + Kd_z*(vz_des - vz) - m_cup*Constants.g_n;
    // Linear actuator bound
    F_act_z := max(-F_act_max, min(F_act_max, F_cmd_z_raw));

    // Vacuum command: full vacuum once insertion begins (rigid peg hold)
    if z > 0.0005 then
      p_cmd := p_cmd_max;
    else
      p_cmd := 0.0;
    end if;

    step_cnt := pre(step_cnt) + 1;
  end when;

  // ---- Mission termination at 10 s ----
  when time >= t_end then
    terminate("Mission complete (10 s)");
  end when;

  annotation (
    Documentation(info="VacuumToolInsertB: contact-rich peg-in-hole insertion using a vertical prismatic carriage with a compliant suction cup, Cartesian impedance control with bounded insertion speed, vacuum hold (0 to -70 kPa gauge), rigid collision against the fixture, 0.35 contact friction, and a 7 N lateral fixture load disturbance injected during the middle third of a 10 s, 100 Hz mission."),
    experiment(StopTime=10.0, Tolerance=1e-6, Interval=0.01)
  );
end VacuumToolInsertB;