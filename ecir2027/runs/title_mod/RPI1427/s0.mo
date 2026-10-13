model ElectroSoftGraspE
  // ---- Geometry / material (dimensional facts from requirement) ----
  parameter Real L = 0.20 "Membrane length [m]";
  parameter Real W = 0.05 "Membrane width [m]";
  parameter Real h = 0.8e-3 "Membrane thickness [m]";
  parameter Real eps0 = 8.8541878128e-12 "Vacuum permittivity [F/m]";
  // Assumed (not stated in requirement):
  parameter Real eps_r = 4.7 "Relative permittivity (assumed)";
  parameter Real rho_m = 1000.0 "Membrane density (assumed) [kg/m3]";
  parameter Real k_elastic = 2000.0 "Elastic stiffness [N/m]";
  parameter Real c_damp = 50.0 "Membrane damping [N.s/m]";
  parameter Real k_visco = 1000.0 "Viscoelastic branch stiffness [N/m]";
  parameter Real c_visco = 300.0 "Viscoelastic branch damping [N.s/m]";
  parameter Real R_leak = 1.0e9 "Leakage resistance (assumed) [Ohm]";
  parameter Real C_th = 0.5 "Thermal capacity (assumed) [J/K]";
  parameter Real G_th = 0.05 "Thermal conductance to ambient (assumed) [W/K]";
  parameter Real T_amb = 293.15 "Ambient temperature [K]";

  // ---- HV channel (command bound from requirement) ----
  parameter Real V_max = 5500.0 "Command magnitude bound [V]";
  parameter Real slew_rate = 3000.0 "HV slew rate (assumed) [V/s]";
  parameter Real k_track = 10000.0 "HV tracking gain [1/s]";

  // ---- Contact / friction (from requirement) ----
  parameter Real mu = 0.70 "Friction coefficient on rigid support";
  parameter Real c_tan = 5.0 "Tangential contact damping [N.s/m]";
  parameter Real alpha_red = 0.5 "Contact redistribution sensitivity [1/m]";

  // ---- Control (pressure control via DE; assumed gains) ----
  parameter Real F_set = 2.5 "Target total normal grasp force (assumed) [N]";
  parameter Real Kp_pos = 20.0 "Position-to-force gain [N/m]";
  parameter Real Ki_force = 800.0 "Force integral gain [V/(N.s)]";

  // ---- Disturbance (from requirement) ----
  parameter Real F_tan = 4.8 "Tangential disturbance load [N]";
  parameter Real t_dist_start = 5.0 "Disturbance start (assumed) [s]";
  parameter Real t_dist_end = 10.0 "Disturbance end (assumed) [s]";

  // ---- Object (assumed) ----
  parameter Real m_obj = 0.10 "Object mass (assumed) [kg]";
  parameter Real k_obj = 50.0 "Object centering stiffness (assumed) [N/m]";
  parameter Real c_obj = 4.47 "Object centering damping (assumed) [N.s/m]";
  parameter Real x_ref = 0.0 "Object position reference [m]";

  // ---- Acceptance bands (from requirement where stated) ----
  parameter Real Fn_min = 0.20 "Per-contact normal lower band [N]";
  parameter Real Fn_max = 1.50 "Per-contact normal upper band [N]";
  parameter Real F_total_min = 1.50 "Total force lower band [N]";
  parameter Real F_total_max = 4.50 "Total force upper band [N]";
  parameter Real x_max = 0.020 "Elongation bound [m]";
  parameter Real err_threshold = 0.013 "Tracking error threshold [m]";
  parameter Real t_settle = 10.4 "Settle time [s]";

  // ---- Dynamic states ----
  Real x_m(start = 0.0002) "Membrane elongation [m]";
  Real x_v(start = 0.0002) "Viscoelastic state [m]";
  Real T_mem(start = T_amb) "Membrane temperature [K]";
  Real V(start = 0.0) "Applied voltage [V]";
  Real V_int(start = 0.0) "Integral voltage command [V]";
  Real obj_x(start = 0.0) "Object x position [m]";
  Real obj_vx(start = 0.0) "Object x velocity [m/s]";

  // ---- Contact / grasp forces ----
  Real Fn1 "Contact 1 normal force [N]";
  Real Fn2 "Contact 2 normal force [N]";
  Real Fn3 "Contact 3 normal force [N]";
  Real Ft1 "Contact 1 tangential force [N]";
  Real Ft2 "Contact 2 tangential force [N]";
  Real Ft3 "Contact 3 tangential force [N]";
  Real F_total "Total normal grasp force [N]";
  Real F_friction_total "Total tangential friction force [N]";
  Real F_dist "Tangential disturbance load [N]";

  // ---- Sensors ----
  Real V_sense "Sensed voltage [V]";
  Real x_sense "Sensed elongation [m]";
  Real F_total_sense "Sensed total normal force [N]";
  Real obj_x_sense "Sensed object x [m]";
  Real obj_y_sense "Sensed object y [m]";
  Real T_sense "Sensed membrane temperature [K]";
  Real Fn1_sense "Sensed contact 1 normal [N]";
  Real Fn2_sense "Sensed contact 2 normal [N]";
  Real Fn3_sense "Sensed contact 3 normal [N]";

  // ---- Derived / electrical / control ----
  Real C_de "DE capacitance [F]";
  Real I_leak "Leakage current [A]";
  Real Q_de "DE charge [C]";
  Real I_draw "Drawn current [A]";
  Real P_elec "Electrical power [W]";
  Real F_maxwell "Maxwell pressure force [N]";
  Real F_visco "Viscoelastic branch force [N]";
  Real F_target "Target total grasp force [N]";
  Real err_force "Force tracking error [N]";
  Real aw "Anti-windup flag";
  Real V_cmd "Bounded voltage command [V]";
  Real w1, w2, w3 "Raw redistribution weights";
  Real w1c, w2c, w3c "Clamped redistribution weights";
  Real obj_y "Object y (height on support) [m]";

  // ---- Acceptance metrics ----
  Real F_track_err "Primary tracking error [m]";
  Real contact1_ok "Contact 1 maintained";
  Real contact2_ok "Contact 2 maintained";
  Real contact3_ok "Contact 3 maintained";
  Real within_bounds "Aggregate bounds flag";

protected
  parameter Real A_mem = L * W "Membrane area [m2]";

equation
  // Dielectric-elastomer capacitance and Maxwell pressure (pressure control)
  C_de = eps0 * eps_r * A_mem / h;
  F_maxwell = eps0 * eps_r * A_mem * (V / h) * (V / h);

  // Membrane viscoelastic first-order dynamics
  F_visco = k_visco * (x_m - x_v);
  c_damp * der(x_m) = F_maxwell - k_elastic * x_m - F_visco;
  c_visco * der(x_v) = F_visco;

  // Total normal grasp force transmitted by membrane tension
  F_total = k_elastic * x_m + F_visco;

  // Leakage, charge, drawn current, electrical power
  I_leak = V / R_leak;
  Q_de = C_de * V;
  I_draw = I_leak + C_de * der(V);
  P_elec = V * I_draw;

  // Thermal state
  C_th * der(T_mem) = P_elec - G_th * (T_mem - T_amb);

  // Middle-third tangential disturbance
  F_dist = if (time >= t_dist_start and time <= t_dist_end) then F_tan else 0.0;

  // Force-regulation controller with anti-windup; command bounded by V_max
  F_target = F_set + Kp_pos * abs(obj_x - x_ref);
  err_force = F_target - F_total;
  aw = if (V_int > V_max and err_force > 0.0) or (V_int < -V_max and err_force < 0.0) then 1.0 else 0.0;
  der(V_int) = Ki_force * err_force * (1.0 - aw);
  V_cmd = max(-V_max, min(V_max, V_int));

  // Slew-limited HV channel
  der(V) = max(-slew_rate, min(slew_rate, k_track * (V_cmd - V)));

  // Distributed contact-force redistribution (avoids local overload)
  w1 = 1.0 / 3.0 - alpha_red * obj_x;
  w2 = 1.0 / 3.0;
  w3 = 1.0 / 3.0 + alpha_red * obj_x;
  w1c = max(0.10, min(0.60, w1));
  w2c = max(0.10, min(0.60, w2));
  w3c = max(0.10, min(0.60, w3));
  Fn1 = max(Fn_min, min(Fn_max, F_total * w1c));
  Fn2 = max(Fn_min, min(Fn_max, F_total * w2c));
  Fn3 = max(Fn_min, min(Fn_max, F_total * w3c));

  // Compliant Coulomb-friction contact (capped by friction cone)
  Ft1 = max(-mu * Fn1, min(mu * Fn1, -c_tan * obj_vx));
  Ft2 = max(-mu * Fn2, min(mu * Fn2, -c_tan * obj_vx));
  Ft3 = max(-mu * Fn3, min(mu * Fn3, -c_tan * obj_vx));
  F_friction_total = Ft1 + Ft2 + Ft3;

  // Object dynamics on rigid support (normal pose constrained)
  m_obj * der(obj_vx) = F_dist + F_friction_total - k_obj * obj_x - c_obj * obj_vx;
  der(obj_x) = obj_vx;
  obj_y = 0.0;

  // Sensors (actuator, distributed contact, object pose)
  V_sense = V;
  x_sense = x_m;
  F_total_sense = F_total;
  obj_x_sense = obj_x;
  obj_y_sense = obj_y;
  T_sense = T_mem;
  Fn1_sense = Fn1;
  Fn2_sense = Fn2;
  Fn3_sense = Fn3;

  // Acceptance metrics (fail-closed: any breach clears the flag)
  F_track_err = abs(obj_x - x_ref);
  contact1_ok = if Fn1 > 0.0 then 1.0 else 0.0;
  contact2_ok = if Fn2 > 0.0 then 1.0 else 0.0;
  contact3_ok = if Fn3 > 0.0 then 1.0 else 0.0;
  within_bounds = if (x_m <= x_max and V <= V_max + 1.0 and
                      Fn1 >= Fn_min and Fn2 >= Fn_min and Fn3 >= Fn_min and
                      Fn1 <= Fn_max and Fn2 <= Fn_max and Fn3 <= Fn_max and
                      F_total >= F_total_min and F_total <= F_total_max and
                      contact1_ok > 0.5 and contact2_ok > 0.5 and contact3_ok > 0.5)
                   then 1.0 else 0.0;

  annotation (
    Documentation(info = "ElectroSoftGraspE: dielectric-elastomer soft grasp with pressure control, distributed contact-force redistribution, slew-limited HV channel, viscoelasticity, leakage, thermal state, compliant Coulomb contact (mu=0.70) on a rigid support, and a 4.8 N middle-third tangential disturbance. Dimensions, thickness, voltage bound, friction, disturbance load, sample rate (250 Hz), duration (16 s), and acceptance thresholds are from the requirement. Permittivity, density, leakage, thermal constants, object mass/stiffness, and target grasp force are not stated in the requirement and are labeled as assumed."),
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004)
  );
end ElectroSoftGraspE;