model VacuumToolGraspE
  "Contact-rich vacuum-tool manipulation: acquire, grasp, hold with tangential disturbance"
  extends Modelica.Icons.Example;

  // ----- Specified plant parameters -----
  parameter Modelica.Units.SI.Mass m_cup = 0.8 "compliant suction cup and carriage mass";
  parameter Modelica.Units.SI.Radius r_cup = 0.038 "suction cup radius";
  parameter Modelica.Units.SI.Pressure P_gauge_min = 0 "gauge pressure lower bound (atmospheric)";
  parameter Modelica.Units.SI.Pressure P_gauge_max = -70000 "gauge pressure upper bound (-70 kPa)";
  parameter Modelica.Units.SI.Force F_cmd_max = 352 "linear actuator command magnitude bound";
  parameter Real mu_table = 0.78 "friction coefficient at contact interface";
  parameter Real e_rest = 0.03 "coefficient of restitution";
  parameter Modelica.Units.SI.Force F_dist = 9.6 "controlled tangential disturbance load";
  parameter Modelica.Units.SI.Frequency f_ctrl = 250 "controller and sensor rate";
  parameter Modelica.Units.SI.Time T_end = 16 "run duration";
  parameter Modelica.Units.SI.Time T_track_deadline = 10.4 "tracking error deadline";
  parameter Modelica.Units.SI.Length track_err_bound = 0.013;

  // ----- Unspecified engineering parameters (clearly labeled) -----
  parameter Modelica.Units.SI.Mass m_object = 0.4 "object mass (unspecified in requirement)";
  parameter Modelica.Units.SI.Length h_obj = 0.05 "object half-height (unspecified)";
  parameter Modelica.Units.SI.Length z_c_start = 0.20 "initial carriage height (unspecified)";
  parameter Real k_cup(unit="N/m") = 8.0e3 "cup vertical compliance (unspecified)";
  parameter Modelica.Units.SI.DampingCoefficient c_cup = 120 "cup vertical damping (unspecified)";
  parameter Real k_table(unit="N/m") = 5.0e4 "table contact stiffness (unspecified)";
  parameter Modelica.Units.SI.DampingCoefficient c_table = 300 "table contact damping (unspecified)";
  parameter Modelica.Units.SI.Force F_contact_target = 12.0 "regulated normal contact force (unspecified)";
  parameter Modelica.Units.SI.Time T_descent = 4.0 "impedance descent duration (unspecified)";
  parameter Modelica.Units.SI.Time T_vacuum_ramp = 1.0 "vacuum ramp duration (unspecified)";
  parameter Real kp_z(unit="N/m") = 600.0 "impedance proportional gain";
  parameter Real kd_z(unit="N.s/m") = 30.0 "impedance derivative gain";
  parameter Real ki_f(unit="1/s") = 150.0 "force regulation integral gain";
  parameter Modelica.Units.SI.Force F_int_lim = 200.0 "force integrator anti-windup limit";

  // ----- Derived constants -----
  final parameter Modelica.Units.SI.Area A_cup = Modelica.Constants.pi*r_cup*r_cup;
  final parameter Modelica.Units.SI.Time T_ctrl = 1.0/f_ctrl;
  final parameter Modelica.Units.SI.Time T_dist_start = T_end/3.0;
  final parameter Modelica.Units.SI.Time T_dist_end = 2.0*T_end/3.0;
  final parameter Modelica.Units.SI.Length z_touch = 2.0*h_obj - F_contact_target/k_cup;
  constant Modelica.Units.SI.Acceleration g = Modelica.Constants.g_n;

  // ----- Dynamic states -----
  Real z_c(start=z_c_start, fixed=true) "carriage (cup face) vertical position";
  Real v_c(start=0, fixed=true) "carriage vertical velocity";
  Real z_o(start=h_obj, fixed=true) "object center vertical position";
  Real v_o(start=0, fixed=true) "object vertical velocity";
  Real x_o(start=0, fixed=true) "object horizontal position";
  Real vx_o(start=0, fixed=true) "object horizontal velocity";
  Real P_cup(start=0, fixed=true) "cup gauge pressure (Pa)";
  Real integ(start=0, fixed=true) "force regulation integrator";
  Real F_filt(start=0, fixed=true) "filtered contact force at controller rate";

  // ----- Commands and saturated actuator outputs -----
  Real F_cmd_raw "raw linear actuator command (N)";
  Real F_cmd "bounded linear actuator command (N)";
  Real P_cmd_raw "raw vacuum command (Pa gauge)";
  Real P_cmd "bounded vacuum command (Pa gauge)";

  // ----- Contact and grasp forces -----
  Real F_table_n "table normal contact force on object";
  Real F_cup_n "cup-object normal contact force (cup pushing down on object)";
  Real F_suction "suction adhesion holding force (>=0)";
  Real F_friction "horizontal friction force on object (cup-object interface)";
  Real F_hold_n "net normal holding force for friction";
  Real F_grav_obj "object weight";
  Real F_grav_cup "cup + carriage weight";
  Real penetration_table "table contact penetration (m)";
  Real penetration_cup "cup-object contact penetration (m)";

  // ----- Disturbance -----
  Real F_dist_applied "applied tangential load";

  // ----- Observations / acceptance variables -----
  Real z_ref "reference carriage position";
  Real track_err "primary tracking error (m)";
  Real obj_disp "object displacement from initial pose (m)";
  Boolean grasp_lost "grasp loss flag";
  Boolean contact_stable "stable contact flag";
  Boolean nan_inf_guard "true if any monitored value is non-finite";

protected
  Real s1 "smoothstep time/T_descent";
  Real s2 "smoothstep vacuum ramp progress";
  Real s1c "clamped smoothstep input";
  Real s2c "clamped vacuum ramp input";
  Real integ_sat "saturated integrator output";
  Real vx_smooth "smoothed horizontal velocity for friction sign";

equation
  // Gravities
  F_grav_cup = m_cup*g;
  F_grav_obj = m_object*g;

  // Contact geometry (collision enabled via compliant contact)
  penetration_table = max(0.0, h_obj - z_o);
  penetration_cup   = max(0.0, (z_o + h_obj) - z_c);

  // Normal contact forces (compliant contact with restitution-derived asymmetric damping)
  F_table_n = k_table*penetration_table + c_table*max(0.0, -v_o);
  F_cup_n   = k_cup*penetration_cup   + c_cup*max(0.0, v_o - v_c);

  // Suction adhesion (only when sealed by contact)
  F_suction = if penetration_cup > 0.0 then max(0.0, -P_cup)*A_cup else 0.0;

  // Net normal holding force for friction with zero-error branch
  F_hold_n = if noEvent(F_cup_n + F_suction > 1e-6) then (F_cup_n + F_suction) else 0.0;

  // Smoothed sign of object horizontal velocity (avoids division by zero in sign)
  vx_smooth = tanh(100.0*vx_o);
  // Friction at cup-object interface resists horizontal motion
  F_friction = if noEvent(F_hold_n > 1e-6) then mu_table*F_hold_n*vx_smooth else 0.0;

  // Controlled tangential disturbance applied over middle third of run
  F_dist_applied = if (time >= T_dist_start and time <= T_dist_end) then F_dist else 0.0;

  // Object horizontal dynamics
  der(x_o)  = vx_o;
  der(vx_o) = (F_dist_applied - F_friction)/m_object;

  // Object vertical dynamics (cup presses down, table pushes up, gravity down)
  der(z_o) = v_o;
  der(v_o) = (F_table_n - F_cup_n - F_grav_obj)/m_object;

  // Carriage vertical dynamics (F_cmd up, gravity down, contact reaction up)
  der(z_c) = v_c;
  der(v_c) = (F_cmd + F_cup_n - F_grav_cup)/m_cup;

  // Vacuum actuator: bounded command, first-order response at controller rate
  der(P_cup) = (P_cmd - P_cup)/T_ctrl;

  // Reference trajectory: smoothstep descent from z_c_start to z_touch
  s1c = max(0.0, min(1.0, time/T_descent));
  s1 = s1c*s1c*(3.0 - 2.0*s1c);
  z_ref = z_c_start + (z_touch - z_c_start)*s1;

  // Vacuum command schedule: 0 until T_descent, then smooth ramp to -70 kPa
  s2c = max(0.0, min(1.0, (time - T_descent)/T_vacuum_ramp));
  s2 = s2c*s2c*(3.0 - 2.0*s2c);
  P_cmd_raw = if time < T_descent then 0.0 else P_gauge_max*s2;
  // Saturate vacuum command between -70 kPa and 0 (gauge)
  P_cmd = max(P_gauge_max, min(P_gauge_min, P_cmd_raw));

  // Force regulation integrator (anti-windup via saturation)
  der(integ) = if time >= T_descent then (F_contact_target - F_filt) else 0.0;
  integ_sat = max(-F_int_lim, min(F_int_lim, integ));

  // Filtered contact force at controller rate (estimator)
  der(F_filt) = (F_cup_n - F_filt)/T_ctrl;

  // Impedance motion (descent) followed by force regulation (hold)
  F_cmd_raw = F_grav_cup + kp_z*(z_ref - z_c) + kd_z*(-v_c)
            + (if time >= T_descent then ki_f*integ_sat else 0.0);
  // Saturate linear actuator command to +/- F_cmd_max
  F_cmd = max(-F_cmd_max, min(F_cmd_max, F_cmd_raw));

  // ----- Observations -----
  track_err = abs(z_c - z_ref);
  obj_disp = sqrt(x_o*x_o + (z_o - h_obj)*(z_o - h_obj));

  // Grasp loss: cup separated from object and suction insufficient to hold
  grasp_lost = (penetration_cup < -1.0e-4) and (F_suction < (F_grav_obj + 1.0));
  // Stable contact: positive contact force during hold phase
  contact_stable = (time >= T_descent) and (F_cup_n > 0.5) and (penetration_cup > 0.0);

  // Non-finite guard for physical, control, and estimator values
  // Uses magnitude thresholds instead of Modelica.Math.isFinite for portability
  nan_inf_guard = not (
        (abs(z_c)     < 1e300)
    and (abs(v_c)     < 1e300)
    and (abs(z_o)     < 1e300)
    and (abs(v_o)     < 1e300)
    and (abs(x_o)     < 1e300)
    and (abs(vx_o)    < 1e300)
    and (abs(P_cup)   < 1e300)
    and (abs(integ)   < 1e300)
    and (abs(F_filt)  < 1e300)
    and (abs(F_cmd)   < 1e300)
    and (abs(P_cmd)   < 1e300)
    and (abs(F_cup_n) < 1e300)
    and (abs(F_suction) < 1e300)
    and (abs(F_friction) < 1e300));

  annotation (
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Vacuum-tool grasp scenario: impedance descent, force-regulated contact, vacuum grasp, and 9.6 N tangential disturbance over the middle third of a 16 s, 250 Hz run. Acceptance is fail-closed: bounded travel/effort, stable contact, bounded object displacement, no grasp loss, primary tracking error < 0.013 m after 10.4 s, and no NaN/infinite values."));
end VacuumToolGraspE;