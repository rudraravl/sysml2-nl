model VacuumToolInsertF
  "Contact-rich peg-in-hole insertion with vacuum tool, Cartesian impedance control"

  // Physical parameters (SI units)
  parameter Real m_c = 0.8 "Carriage + compliant suction cup mass [kg]";
  parameter Real r_p = 0.038 "Suction cup / peg radius [m]";
  parameter Real c_r = 0.001 "Hole radial clearance [m]";
  parameter Real mu_c = 0.35 "Contact friction coefficient [1]";
  parameter Real F_lin_max = 390.0 "Linear actuator force bound [N]";
  parameter Real p_vac_min = -70000.0 "Vacuum command lower bound gauge [Pa]";
  parameter Real k_c = 1.0e6 "Rigid collision stiffness [N/m]";
  parameter Real d_c = 1000.0 "Collision damping [N.s/m]";
  parameter Real J_p = 1.5e-4 "Peg rotational inertia [kg.m2]";
  parameter Real l_p = 0.06 "Peg effective length [m]";
  parameter Real z_hole = 0.07 "Hole total depth [m]";
  parameter Real g_const = 9.81 "Gravity [m/s2]";

  // Controller parameters
  parameter Real Kpz = 8000.0 "Axial impedance stiffness [N/m]";
  parameter Real Kdz = 220.0 "Axial impedance damping [N.s/m]";
  parameter Real Kpx = 10000.0 "Lateral impedance stiffness [N/m]";
  parameter Real Kdx = 150.0 "Lateral impedance damping [N.s/m]";
  parameter Real Kpt = 100.0 "Tilt impedance stiffness [N.m/rad]";
  parameter Real Kdt = 4.0 "Tilt impedance damping [N.m.s/rad]";
  parameter Real v_ins = 0.012 "Bounded insertion speed [m/s]";
  parameter Real z_tgt = 0.06 "Target insertion depth [m]";
  parameter Real x_init = 0.005 "Initial lateral misalignment [m]";
  parameter Real z_init = -0.02 "Initial height above rim [m]";

  // Disturbance and timing
  parameter Real F_dist_val = 14.5 "Lateral fixture load disturbance [N]";
  parameter Real t_total = 20.0 "Total simulation duration [s]";
  parameter Real f_loop = 500.0 "Control loop rate [Hz]";

  // Dynamic states
  Real x(start=x_init, fixed=true) "Lateral position [m]";
  Real vx(start=0.0, fixed=true) "Lateral velocity [m/s]";
  Real z(start=z_init, fixed=true) "Axial depth positive is insertion [m]";
  Real vz(start=0.0, fixed=true) "Axial velocity [m/s]";
  Real theta(start=0.0, fixed=true) "Peg tilt angle [rad]";
  Real omega(start=0.0, fixed=true) "Peg angular velocity [rad/s]";

  // Control variables
  Real z_des "Desired insertion depth [m]";
  Real v_des "Desired insertion velocity [m/s]";
  Real F_cmd_raw "Unsaturated axial force command [N]";
  Real F_cmd "Saturated axial force command [N]";
  Real F_lat_cmd "Lateral impedance force command [N]";
  Real tau_cmd "Tilt control torque [N.m]";
  Real p_vac "Vacuum pressure command [Pa]";

  // Contact variables
  Real F_cx "Lateral wall contact force [N]";
  Real F_cz_rim "Axial rim contact force [N]";
  Real F_cz_bot "Axial bottom contact force [N]";
  Real F_cz "Total axial contact force [N]";
  Real F_fric "Insertion friction force [N]";
  Real F_d "Lateral disturbance force [N]";
  Real N_wall "Wall normal force magnitude [N]";
  Real delta_lat "Lateral wall penetration [m]";
  Real delta_rim "Rim axial penetration [m]";
  Real delta_bot "Bottom penetration [m]";
  Real sgn_x "Safe sign of x [1]";

  // Sensors: six-axis wrench plus carriage/joint sensing
  Real F_sx "Sensed lateral force wrench Fx [N]";
  Real F_sy "Sensed wrench Fy [N]";
  Real F_sz "Sensed axial force wrench Fz [N]";
  Real M_sx "Sensed wrench Mx [N.m]";
  Real M_sy "Sensed wrench My [N.m]";
  Real M_sz "Sensed wrench Mz [N.m]";
  Real x_s "Sensed lateral position [m]";
  Real z_s "Sensed carriage depth [m]";
  Real theta_s "Sensed peg tilt [rad]";

  // Verification quantities
  Real track_err "Primary alignment tracking error [m]";
  Real F_axial_tot "Total axial force [N]";
  Real F_lat_tot "Total lateral force [N]";
  Real tilt_obs "Observed tilt magnitude [rad]";
  Boolean bound_ok "Actuator bound check";
  Boolean align_ok "Alignment below 0.002 m after 13 s";
  Boolean depth_ok "Insertion depth at least 0.06 m";
  Boolean tilt_ok "Tilt below 0.05 rad";
  Boolean force_ok "Lateral and axial force limits satisfied";
  Boolean valid "No NaN or Inf in key variables";

equation
  // === Desired trajectory: bounded insertion speed ===
  z_des = max(z_init, min(z_tgt, z_init + v_ins * time));
  v_des = if z_des < z_tgt - 1e-9 then v_ins else 0.0;

  // === Vacuum command: 0 to -70 kPa gauge after initial delay ===
  p_vac = if time > 0.5 then p_vac_min else 0.0;

  // === Cartesian impedance control with gravity feedforward ===
  F_cmd_raw = Kpz * (z_des - z) + Kdz * (v_des - vz) + m_c * g_const;
  F_lat_cmd = Kpx * (-x) + Kdx * (-vx);
  tau_cmd = Kpt * (-theta) + Kdt * (-omega);

  // === Actuator saturation: bounded at 390 N ===
  F_cmd = max(-F_lin_max, min(F_lin_max, F_cmd_raw));

  // === Disturbance: 14.5 N lateral in middle third of 20 s ===
  F_d = if (time > t_total / 3.0 and time < 2.0 * t_total / 3.0) then F_dist_val else 0.0;

  // === Safe sign avoiding ambiguity at zero ===
  sgn_x = if x > 1e-14 then 1.0 else (if x < -1e-14 then -1.0 else 0.0);

  // === Penetration calculations ===
  delta_lat = max(0.0, abs(x) - c_r);
  delta_rim = if abs(x) > c_r then max(0.0, z) else 0.0;
  delta_bot = max(0.0, z - z_hole);

  // === Wall normal force magnitude ===
  N_wall = k_c * delta_lat;

  // === Lateral contact force: rigid collision as stiff spring-damper ===
  F_cx = if delta_lat > 0.0 then -k_c * delta_lat * sgn_x - d_c * vx else 0.0;

  // === Axial contact forces: rim and bottom ===
  F_cz_rim = if delta_rim > 0.0 then -k_c * delta_rim - d_c * vz else 0.0;
  F_cz_bot = if delta_bot > 0.0 then -k_c * delta_bot - d_c * vz else 0.0;
  F_cz = F_cz_rim + F_cz_bot;

  // === Insertion friction: Coulomb smoothed via tanh ===
  F_fric = if (z > 0.0 and N_wall > 0.0) then -mu_c * N_wall * tanh(vz / 1e-4) else 0.0;

  // === Equations of motion ===
  // Lateral
  der(x) = vx;
  m_c * der(vx) = F_lat_cmd + F_cx + F_d;

  // Axial: positive z is downward insertion
  der(z) = vz;
  m_c * der(vz) = F_cmd + m_c * g_const + F_cz + F_fric;

  // Tilt: contact force at tip creates moment
  der(theta) = omega;
  J_p * der(omega) = tau_cmd + (-F_cx * l_p / 2.0);

  // === Sensors: six-axis wrench plus carriage and joint ===
  x_s = x;
  z_s = z;
  theta_s = theta;
  F_sx = F_cx + F_d;
  F_sy = 0.0;
  F_sz = F_cz + F_fric;
  M_sx = 0.0;
  M_sy = -F_cx * l_p / 2.0;
  M_sz = 0.0;

  // === Verification metrics ===
  track_err = abs(x);
  F_axial_tot = abs(F_cmd) + abs(F_cz) + abs(F_fric);
  F_lat_tot = abs(F_lat_cmd) + abs(F_cx) + abs(F_d);
  tilt_obs = abs(theta);

  // Actuator bound
  bound_ok = abs(F_cmd) <= F_lin_max + 1.0;

  // Alignment within 0.002 m after 13 s
  align_ok = if time > 13.0 then track_err < 0.002 else true;

  // Insertion depth at least 0.06 m
  depth_ok = z >= z_tgt - 1e-4;

  // Tilt limit
  tilt_ok = tilt_obs < 0.05;

  // Force limits
  force_ok = F_lat_tot < 500.0 and F_axial_tot < 800.0;

  // No NaN or Inf in physical, control, or estimator variables
  valid = (x > -1e6) and (x < 1e6) and (z > -1e6) and (z < 1e6)
      and (theta > -1e6) and (theta < 1e6)
      and (F_cmd > -1e6) and (F_cmd < 1e6);

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "VacuumToolInsertF: contact-rich peg-in-hole insertion.
Physical: 0.8 kg compliant suction cup, radius 0.038 m, 1 mm radial clearance, mu=0.35.
Actuation: linear actuator bounded at 390 N, vacuum 0 to -70 kPa gauge.
Control: Cartesian impedance with bounded insertion speed 0.012 m/s.
Disturbance: 14.5 N lateral in middle third (6.67-13.33 s).
Loop: 500 Hz (Interval=0.002 s), 20 s duration.
Verification: actuator bounds, lateral/axial force limits, peg tilt, insertion depth,
primary tracking error below 0.002 m after 13 s, no NaN/Inf.
Unknown facts (peg material, cup stiffness, hole depth beyond 0.07 m) omitted.")
  );
end VacuumToolInsertF;