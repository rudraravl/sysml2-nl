model CartesianToolGraspB
  "Contact-rich manipulation: acquire rigid object, establish stable grasp, hold."

  // === Parameters stated in requirement ===
  parameter Real m_tool(unit="kg")      = 2.5  "tool carriage mass";
  parameter Real F_max(unit="N")        = 287  "per-axis actuator force limit";
  parameter Real x_lim(unit="m")        = 0.10 "X travel bound";
  parameter Real y_lim(unit="m")        = 0.10 "Y travel bound";
  parameter Real z_lim(unit="m")        = 0.30 "Z travel bound";
  parameter Real mu                    = 0.78 "friction coefficient";
  parameter Real e_rest                = 0.03 "restitution coefficient";
  parameter Real f_dist(unit="N")       = 5.6  "tangential disturbance magnitude";
  parameter Real T(unit="s")            = 0.01 "control/sensor period (100 Hz)";
  parameter Real t_end(unit="s")        = 10.0 "mission duration";

  // === Parameters NOT stated in requirement (nominal tunable values) ===
  parameter Real m_obj(unit="kg")       = 1.0   "object mass (nominal; not specified)";
  parameter Real k_contact(unit="N/m")  = 2.0e5 "table contact stiffness (nominal)";
  parameter Real c_contact(unit="N.s/m")= 80.0  "table contact damping (nominal)";
  parameter Real Kp_imp(unit="N/m")     = 1200.0 "impedance proportional gain";
  parameter Real Kd_imp(unit="N.s/m")   = 60.0  "impedance derivative gain";
  parameter Real Kp_grasp(unit="N/m")   = 8000.0 "grasp coupling stiffness";
  parameter Real Kd_grasp(unit="N.s/m") = 200.0 "grasp coupling damping";
  parameter Real Kp_force(unit="1")     = 0.8   "force regulation gain";
  parameter Real F_grip_ref(unit="N")   = 25.0  "desired grip squeeze force (nominal)";
  parameter Real z_approach(unit="m")   = 0.04  "tool hover height above table (nominal)";
  parameter Real F_grip_min(unit="N")   = 5.0   "grasp-loss threshold (nominal)";

  // === Initial conditions ===
  parameter Real x_t0(unit="m") = 0.0  "initial tool x";
  parameter Real y_t0(unit="m") = 0.0  "initial tool y";
  parameter Real z_t0(unit="m") = 0.30 "initial tool z (top of travel)";
  parameter Real x_o0(unit="m") = 0.0  "initial object x";
  parameter Real y_o0(unit="m") = 0.0  "initial object y";
  parameter Real z_o0(unit="m") = 0.0  "initial object base on table";

  // === Tool carriage state (continuous) ===
  Real x_t(unit="m"), y_t(unit="m"), z_t(unit="m");
  Real vx_t(unit="m/s"), vy_t(unit="m/s"), vz_t(unit="m/s");
  Real fx_cmd(unit="N"), fy_cmd(unit="N"), fz_cmd(unit="N");
  Real fx_act(unit="N"), fy_act(unit="N"), fz_act(unit="N");

  // === Object state (continuous) ===
  Real x_o(unit="m"), y_o(unit="m"), z_o(unit="m");
  Real vx_o(unit="m/s"), vy_o(unit="m/s"), vz_o(unit="m/s");

  // === Contact / grasp forces ===
  Real F_table(unit="N")   "normal contact force from table on object";
  Real F_grip(unit="N")    "grip squeeze force magnitude (Y axis)";
  Real F_grasp_x(unit="N") "grasp coupling force on object (x)";
  Real F_grasp_z(unit="N") "grasp coupling force on object (z)";
  Real F_dist(unit="N")    "tangential disturbance load on object";

  // === Controller / mission variables ===
  Integer phase "1 = impedance approach, 2 = force-regulated grasp/hold";
  Real z_ref(unit="m")     "impedance reference for primary Z axis";
  Real track_err(unit="m") "primary axis tracking error (|z_t - z_ref|)";

  // === Discrete control commands (zero-order hold at 100 Hz) ===
  discrete Real fx_cmd_d(unit="N");
  discrete Real fy_cmd_d(unit="N");
  discrete Real fz_cmd_d(unit="N");

  // === Sampled sensors at 100 Hz (actuator state, contact, pose) ===
  discrete Real x_t_s(unit="m"),  y_t_s(unit="m"),  z_t_s(unit="m");
  discrete Real vx_t_s(unit="m/s"), vy_t_s(unit="m/s"), vz_t_s(unit="m/s");
  discrete Real fx_s(unit="N"), fy_s(unit="N"), fz_s(unit="N");
  discrete Real x_o_s(unit="m"), y_o_s(unit="m"), z_o_s(unit="m");
  discrete Real vx_o_s(unit="m/s"), vy_o_s(unit="m/s"), vz_o_s(unit="m/s");
  discrete Real F_normal_s(unit="N") "sampled normal contact (table) force";
  discrete Real F_grip_s(unit="N")   "sampled grip squeeze force";
  discrete Real track_err_s(unit="m");
  discrete Real phase_s;

  // === Verification / observability flags ===
  Real effort_violation(unit="N") "sum of |actuator|-F_max positive parts";
  Real travel_violation(unit="m") "positive travel beyond limits";
  Real track_after_65(unit="m")   "tracking error at/after 6.5 s";
  Real obj_disp(unit="m")         "object displacement magnitude from initial";
  Boolean grasp_lost;
  Boolean value_fault;

initial equation
  x_t  = x_t0;  y_t  = y_t0;  z_t  = z_t0;
  vx_t = 0;     vy_t = 0;     vz_t = 0;
  x_o  = x_o0;  y_o  = y_o0;  z_o  = z_o0;
  vx_o = 0;     vy_o = 0;     vz_o = 0;

equation
  // ----- Tool carriage kinematics/dynamics -----
  der(x_t) = vx_t;
  der(y_t) = vy_t;
  der(z_t) = vz_t;
  m_tool*der(vx_t) = fx_act - F_grasp_x;   // reaction from grasp on object
  m_tool*der(vy_t) = fy_act;
  m_tool*der(vz_t) = fz_act - F_grasp_z;

  // ----- Force-limited linear actuators (saturation) -----
  fx_act = max(-F_max, min(F_max, fx_cmd));
  fy_act = max(-F_max, min(F_max, fy_cmd));
  fz_act = max(-F_max, min(F_max, fz_cmd));

  // ----- Object kinematics -----
  der(x_o) = vx_o;
  der(y_o) = vy_o;
  der(z_o) = vz_o;

  // ----- Table contact (object base at z_o; table at z=0) -----
  // Collision enabled; restitution e_rest scales damping (near-plastic for e=0.03)
  F_table = if z_o <= 0.0 then
            max(0.0, k_contact*(-z_o) - c_contact*(1.0 - e_rest)*vz_o)
            else 0.0;

  // ----- Object dynamics: gravity + table normal + grasp coupling -----
  m_obj*der(vz_o) = -9.81*m_obj + F_table + F_grasp_z;
  m_obj*der(vx_o) = -mu*F_table*tanh(50.0*vx_o) + F_grasp_x + F_dist;
  m_obj*der(vy_o) = -mu*F_table*tanh(50.0*vy_o);

  // ----- Tangential disturbance during middle third of [0, t_end] -----
  F_dist = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then f_dist else 0.0;

  // ----- Grip squeeze force: commanded Y actuator clamped to >= 0 (squeeze) -----
  F_grip = max(0.0, fy_act);

  // ----- Grasp coupling: compliant, friction-limited (Coulomb cap = mu*F_grip) -----
  F_grasp_x = max(-mu*F_grip, min(mu*F_grip,
                  Kp_grasp*(x_t - x_o) + Kd_grasp*(vx_t - vx_o)));
  F_grasp_z = max(-mu*F_grip, min(mu*F_grip,
                  Kp_grasp*(z_t - z_o) + Kd_grasp*(vz_t - vz_o)));

  // ----- Mission phase logic: impedance approach (first 2 s), then force regulation -----
  phase  = if time < 2.0 then 1 else 2;
  z_ref  = if time < 2.0 then
           z_t0 - (z_t0 - z_approach)*time/2.0
           else z_approach;

  // ----- Continuous controller outputs (held via discrete ZOH at 100 Hz) -----
  fx_cmd = fx_cmd_d;
  fy_cmd = fy_cmd_d;
  fz_cmd = fz_cmd_d;

  // ----- Primary tracking error (Z axis) -----
  track_err = abs(z_t - z_ref);

  // ----- Discrete control update at 100 Hz (impedance + force regulation) -----
  when sample(0, T) then
    // Impedance motion on primary Z axis
    fz_cmd_d = Kp_imp*(z_ref - z_t) - Kd_imp*vz_t;
    // X axis hold (impedance to 0)
    fx_cmd_d = Kp_imp*(0.0 - x_t) - Kd_imp*vx_t;
    // Y grip force regulation active only in phase 2
    fy_cmd_d = if phase == 1 then 0.0
               else F_grip_ref + Kp_force*(F_grip_ref - F_grip);

    // Synchronized state, command, and sensor traces
    x_t_s  = x_t;   y_t_s  = y_t;   z_t_s  = z_t;
    vx_t_s = vx_t;  vy_t_s = vy_t;  vz_t_s = vz_t;
    fx_s   = fx_act; fy_s   = fy_act; fz_s   = fz_act;
    x_o_s  = x_o;   y_o_s  = y_o;   z_o_s  = z_o;
    vx_o_s = vx_o;  vy_o_s = vy_o;  vz_o_s = vz_o;
    F_normal_s = F_table;
    F_grip_s   = F_grip;
    track_err_s = track_err;
    phase_s    = phase;
  end when;

  // ----- Effort bound violation (should remain 0) -----
  effort_violation = max(0.0, abs(fx_act) - F_max)
                   + max(0.0, abs(fy_act) - F_max)
                   + max(0.0, abs(fz_act) - F_max);

  // ----- Travel bound violation (should remain 0) -----
  travel_violation = max(0.0, abs(x_t) - x_lim)
                   + max(0.0, abs(y_t) - y_lim)
                   + max(0.0, abs(z_t) - z_lim);

  // ----- Primary tracking error after 6.5 s (requirement: < 0.018 m) -----
  track_after_65 = if time >= 6.5 then track_err else 0.0;

  // ----- Bounded object displacement from initial pose -----
  obj_disp = sqrt((x_o - x_o0)^2 + (y_o - y_o0)^2 + (z_o - z_o0)^2);

  // ----- Grasp-loss detection during hold phase -----
  grasp_lost = (phase == 2) and (F_grip < F_grip_min);

  // ----- NaN / infinite physical, control, estimator value check -----
  value_fault = (abs(x_t)  > 1.0e6) or (abs(y_t)  > 1.0e6) or (abs(z_t)  > 1.0e6)
            or (abs(x_o)  > 1.0e6) or (abs(y_o)  > 1.0e6) or (abs(z_o)  > 1.0e6)
            or (abs(fx_act) > 1.0e6) or (abs(fy_act) > 1.0e6) or (abs(fz_act) > 1.0e6)
            or (abs(F_table) > 1.0e6) or (abs(F_grip) > 1.0e6);

  annotation (
    experiment(StartTime=0.0, StopTime=10.0, Tolerance=1e-6, Interval=0.01),
    Documentation(info="Mission: acquire rigid object, establish stable grasp, hold without excessive displacement.
Three orthogonal prismatic axes move a 2.5 kg tool carriage (limits +/-0.10 m X/Y, +/-0.30 m Z).
Force-limited linear actuators (287 N/axis). Rigid support table, mu=0.78, restitution=0.03, collision enabled.
Sensors: actuator state, normal contact force, object pose. Impedance motion then force regulation.
5.6 N tangential disturbance injected during middle third (3.33-6.67 s).
100 Hz control/sensing, 10 s duration. Tracking error < 0.018 m after 6.5 s.
Values not stated in the requirement (m_obj, stiffnesses, controller gains, hover height)
are nominal tunable parameters clearly labeled as not specified."));
end CartesianToolGraspB;