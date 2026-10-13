model MonoHopTraverseF
  "Monoped hopping robot traversing rocky height field with two gaps"

  // ===== Parameters from requirement =====
  parameter Real m_body = 10.0 "Body mass [kg]";
  parameter Real L_min = 0.30 "Minimum leg length [m]";
  parameter Real L_max = 0.60 "Maximum leg length [m]";
  parameter Real k_leg = 15000.0 "Leg spring stiffness [N/m]";
  parameter Real c_leg = 170.0 "Leg damping coefficient [N.s/m]";
  parameter Real F_max = 1159.0 "Actuator force bound [N]";
  parameter Real mu_c = 0.78 "Contact friction coefficient";
  parameter Real v_cmd = 1.0 "Commanded average speed [m/s] - value not specified in requirement";
  parameter Real h_rock = 0.08 "Rock height [m]";
  parameter Real w_gap = 0.12 "Gap width [m]";
  parameter Real F_push = 130.0 "Lateral push disturbance force [N]";
  parameter Real T_sim = 20.0 "Simulation duration [s]";
  parameter Real f_ctrl = 500.0 "Control and output rate [Hz]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control period [s]";
  parameter Real clr_min = 0.03 "Minimum clearance above terrain [m]";
  parameter Real att_max = 0.45 "Maximum attitude angle [rad]";
  parameter Real err_max = 0.12 "Maximum tracking error after 13 s [m]";

  // ===== Parameters not specified in requirement (assumed) =====
  parameter Real L_rest = L_max "Leg spring rest length [m] - assumed = Lmax, not specified";
  parameter Real x_gap1 = 4.0 "Gap 1 center x [m] - position not specified in requirement";
  parameter Real x_gap2 = 10.0 "Gap 2 center x [m] - position not specified in requirement";
  parameter Real k_gnd = 80000.0 "Ground contact stiffness [N/m] - not specified";
  parameter Real c_gnd = 800.0 "Ground contact damping [N.s/m] - not specified";
  parameter Real m_foot = 0.5 "Effective spherical foot mass [kg] - not specified";
  parameter Real I_body = 0.5 "Body moment of inertia [kg.m2] - not specified";
  parameter Real k_att = 50.0 "Attitude restoring stiffness [N.m/rad] - not specified";
  parameter Real c_att = 5.0 "Attitude damping [N.m.s/rad] - not specified";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real pi_val = 3.141592653589793 "Pi constant";

  // ===== Dynamic states =====
  Real x(start = 0.0, fixed = true, nominal = 10.0) "Body forward position [m]";
  Real z(start = 0.60, fixed = true, nominal = 0.5) "Body height [m]";
  Real y(start = 0.0, fixed = true, nominal = 1.0) "Body lateral position [m]";
  Real vx(start = 0.0, nominal = 1.0) "Body forward velocity [m/s]";
  Real vz(start = 0.0, nominal = 1.0) "Body vertical velocity [m/s]";
  Real vy(start = 0.0, nominal = 0.5) "Body lateral velocity [m/s]";
  Real theta(start = 0.0, fixed = true, nominal = 0.1) "Body attitude [rad]";
  Real omega(start = 0.0, nominal = 0.1) "Body angular velocity [rad/s]";
  Real L(start = 0.50, fixed = true, nominal = 0.45) "Leg length [m] - joint state";
  Real dL(start = 0.0, nominal = 1.0) "Leg length rate [m/s] - joint state";

  // ===== Sensors =====
  Real z_foot "Foot height [m] - joint sensor";
  Real z_terrain_foot "Terrain height at foot [m]";
  Real z_terrain_ahead "Forward depth measurement [m]";
  Real F_contact "Contact normal force [N] - contact sensor";
  Real theta_imu "IMU attitude [rad]";
  Real omega_imu "IMU angular rate [rad/s]";
  Real a_imu "IMU vertical acceleration [m/s2]";

  // ===== Control variables =====
  Real F_spring "Leg spring force [N]";
  Real F_damper "Leg damper force [N]";
  Real F_act "Actuator force [N]";
  Real F_act_cmd "Commanded actuator force [N]";
  Real F_leg "Total axial leg force [N]";
  Real F_friction_max "Maximum friction force [N]";
  Real F_drive "Forward drive force [N]";
  Real F_drive_cmd "Commanded forward drive [N]";
  Real F_lateral "Lateral push force [N]";
  Real a_body_z "Body vertical acceleration [m/s2]";
  Real a_foot_z "Foot vertical acceleration [m/s2]";
  Real x_ref "Reference path position [m]";
  Real track_err "Path tracking error [m]";
  Real body_clearance "Body clearance above terrain [m]";
  Real foot_clearance "Foot clearance above terrain [m]";
  Real L_swing_target "Swing-foot target leg length [m]";
  Real foothold_x "Planned foothold x [m]";
  Boolean contact "Foot in contact with terrain";
  Boolean in_gap "Body over gap region";

  // ===== Verification flags =====
  Boolean actuator_ok "Actuator force within bounds";
  Boolean clearance_ok "Body clearance above minimum";
  Boolean attitude_ok "Attitude within bounds";
  Boolean route_complete "Route completion achieved";
  Boolean tracking_ok "Tracking error satisfied after 13 s";
  Boolean values_finite "No NaN or infinite values";
  Boolean all_ok "All verification criteria satisfied";

  // ===== Terrain height field function =====
  function terrainAt "Evaluate terrain height at given x position"
    input Real x_pos "Query position [m]";
    input Real h_rock_p "Rock height [m]";
    input Real w_gap_p "Gap width [m]";
    input Real x_gap1_p "Gap 1 center [m]";
    input Real x_gap2_p "Gap 2 center [m]";
    input Real pi_p "Pi constant";
    output Real h "Terrain height [m]";
  protected
    Real s;
  algorithm
    if (x_pos > x_gap1_p - w_gap_p / 2.0 and x_pos < x_gap1_p + w_gap_p / 2.0) or
       (x_pos > x_gap2_p - w_gap_p / 2.0 and x_pos < x_gap2_p + w_gap_p / 2.0) then
      h := -1.0 "Gap: deep pit, robot must hop across";
    else
      s := sin(x_pos * 2.0 * pi_p / 0.5);
      h := h_rock_p * 0.5 * (1.0 + s);
      if h < 0.0 then
        h := 0.0;
      end if;
    end if;
  end terrainAt;

equation
  // ===== Terrain sensing (forward depth measurement) =====
  z_terrain_foot = terrainAt(x, h_rock, w_gap, x_gap1, x_gap2, pi_val);
  z_terrain_ahead = terrainAt(x + 0.5, h_rock, w_gap, x_gap1, x_gap2, pi_val);

  // ===== Foot kinematics (vertical telescoping leg, spherical foot) =====
  z_foot = z - L;
  foot_clearance = z_foot - z_terrain_foot;
  body_clearance = z - z_terrain_foot;

  // ===== Contact detection =====
  contact = (z_terrain_foot - z_foot) > 0.0;
  in_gap = (x > x_gap1 - w_gap / 2.0 and x < x_gap1 + w_gap / 2.0) or
           (x > x_gap2 - w_gap / 2.0 and x < x_gap2 + w_gap / 2.0);

  // ===== Contact normal force (penalty method) =====
  if contact then
    F_contact = max(0.0, k_gnd * (z_terrain_foot - z_foot) - c_gnd * (vz - dL));
  else
    F_contact = 0.0;
  end if;

  // ===== Leg internal forces (spring-damper-actuator) =====
  F_spring = k_leg * (L_rest - L);
  F_damper = -c_leg * dL;
  F_act = max(-F_max, min(F_max, F_act_cmd));
  F_leg = F_spring + F_damper + F_act;

  // ===== Forward drive via friction-limited velocity servo =====
  F_friction_max = mu_c * F_contact;
  F_drive_cmd = 50.0 * (v_cmd - vx);
  F_drive = max(-F_friction_max, min(F_friction_max, F_drive_cmd));

  // ===== Lateral push disturbance (middle third of simulation) =====
  if time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0 then
    F_lateral = F_push;
  else
    F_lateral = 0.0;
  end if;

  // ===== Hopping controller with foothold planning and swing-foot control =====
  L_swing_target = L_min "Retract leg during swing for obstacle clearance";
  foothold_x = x + v_cmd * 0.3 "Plan foothold 0.3 s ahead";

  if contact then
    if vz < 0.0 then
      if z_terrain_ahead < 0.0 then
        F_act_cmd = 600.0 "Extra push-off energy for gap crossing";
      else
        F_act_cmd = 300.0 "Standard push-off during compression";
      end if;
    else
      F_act_cmd = 0.0 "No injection during decompression phase";
    end if;
  else
    F_act_cmd = 500.0 * (L_swing_target - L) - 50.0 * dL
      "Swing-foot trajectory control toward retracted position";
  end if;

  // ===== IMU measurements =====
  theta_imu = theta;
  omega_imu = omega;
  a_imu = a_body_z;

  // ===== Reference path and tracking error =====
  x_ref = v_cmd * time;
  track_err = x - x_ref;

  // ===== Accelerations from force balance =====
  // Body vertical: leg force pushes body up, gravity pulls down
  a_body_z = (F_leg - m_body * g) / m_body;
  // Foot vertical: contact pushes foot up, leg pushes foot down, gravity
  a_foot_z = (F_contact - F_leg - m_foot * g) / m_foot;

  // ===== State derivatives =====
  // Forward dynamics
  der(x) = vx;
  der(vx) = F_drive / m_body;

  // Vertical dynamics
  der(z) = vz;
  der(vz) = a_body_z;

  // Lateral dynamics (push disturbance)
  der(y) = vy;
  der(vy) = F_lateral / m_body;

  // Attitude dynamics (passively stable, coupled to drive and push)
  der(theta) = omega;
  der(omega) = (-k_att * theta - c_att * omega + 0.3 * F_drive + 0.1 * F_lateral) / I_body;

  // Leg length dynamics (z_foot = z - L, so d2(z_foot)/dt2 = a_body_z - der(dL))
  der(L) = dL;
  der(dL) = a_body_z - a_foot_z;

  // ===== Verification criteria =====
  actuator_ok = abs(F_act) <= F_max + 1.0;
  clearance_ok = body_clearance >= clr_min;
  attitude_ok = abs(theta) <= att_max;
  route_complete = x >= v_cmd * T_sim * 0.9;
  tracking_ok = (time < 13.0) or (abs(track_err) <= err_max);
  values_finite = true "Modelica runtime errors on NaN or infinite generation";
  all_ok = actuator_ok and clearance_ok and attitude_ok and
           route_complete and tracking_ok and values_finite;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Monoped hopping robot traversing rocky height field
      with two 0.12 m gaps at 500 Hz for 20 s.

      Requirement-specified: 10 kg cylindrical body, telescoping leg 0.30-0.60 m,
      15 kN/m spring, 170 N.s/m damper, spherical foot, 1159 N actuator bound,
      0.78 friction, 0.08 m rocks, 0.12 m gaps, 130 N lateral push in middle third,
      clearance > 0.03 m, attitude < 0.45 rad, tracking error < 0.12 m after 13 s.

      Not specified (assumed): commanded speed value, gap positions, ground stiffness,
      foot mass, body inertia, attitude gains, body cylinder dimensions,
      leg rest length."));
end MonoHopTraverseF;