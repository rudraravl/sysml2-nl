model ROVDockF
  "Free-base marine robot docking approach with speed-scheduled pose control and contact transition"

  // --- Physical parameters (SI units) ---
  parameter Real m = 115.0 "ROV mass [kg]";
  parameter Real Lx = 1.1 "Frame length [m]";
  parameter Real Ly = 0.78 "Frame width [m]";
  parameter Real Lz = 0.58 "Frame height [m]";
  parameter Real Vol = Lx*Ly*Lz "Displaced volume [m3]";
  parameter Real rho = 1025.0 "Seawater density [kg/m3]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real dFb = 6.0 "Small positive net buoyancy force [N]";
  parameter Real m_add_x = 35.0 "Added mass in surge [kg]";
  parameter Real m_add_y = 55.0 "Added mass in sway [kg]";
  parameter Real Izz = m*(Lx^2 + Ly^2)/12.0 "Rigid-body yaw inertia [kg.m2]";
  parameter Real Izz_add = 25.0 "Added yaw inertia [kg.m2]";
  parameter Real Dx_lin = 50.0 "Linear surge drag [N/(m/s)]";
  parameter Real Dy_lin = 70.0 "Linear sway drag [N/(m/s)]";
  parameter Real Dr_lin = 40.0 "Linear yaw drag [N.m/(rad/s)]";
  parameter Real Dx_quad = 120.0 "Quadratic surge drag [N/(m/s)^2]";
  parameter Real Dy_quad = 160.0 "Quadratic sway drag [N/(m/s)^2]";
  parameter Real Dr_quad = 30.0 "Quadratic yaw drag [N.m/(rad/s)^2]";
  parameter Real Fthr_max = 201.0 "Max force per thruster [N]";
  parameter Integer nthr = 6 "Number of thrusters";
  parameter Real Fx_max = 4.0*Fthr_max "Surge force envelope [N]";
  parameter Real Fy_max = 2.0*Fthr_max "Sway force envelope [N]";
  parameter Real Mz_max = 2.0*Fthr_max*0.5 "Yaw moment envelope [N.m]";

  // --- Control gains ---
  parameter Real Kp_x_far = 25.0 "Far-range surge position gain";
  parameter Real Kd_x_far = 30.0 "Far-range surge velocity gain";
  parameter Real Kp_x_near = 8.0 "Near-range surge position gain";
  parameter Real Kd_x_near = 22.0 "Near-range surge velocity gain";
  parameter Real Kp_y = 40.0 "Sway position gain";
  parameter Real Kd_y = 38.0 "Sway velocity gain";
  parameter Real Kp_psi = 18.0 "Yaw angle gain";
  parameter Real Kd_psi = 16.0 "Yaw rate gain";
  parameter Real v_approach_far = 0.6 "Approach speed far [m/s]";
  parameter Real v_approach_near = 0.12 "Approach speed near [m/s]";
  parameter Real d_switch = 1.0 "Speed scheduling threshold [m]";

  // --- Mission / station geometry ---
  parameter Real x_dock = 0.0 "Dock funnel x position [m]";
  parameter Real y_dock = 0.0 "Dock funnel y position [m]";
  parameter Real psi_dock = 0.0 "Dock alignment yaw [rad]";
  parameter Real x_start = -8.0 "Initial ROV x [m]";
  parameter Real y_start = 0.0 "Initial ROV y [m]";
  parameter Real capture_radius = 0.18 "Compliant capture engagement radius [m]";
  parameter Real k_capture = 600.0 "Capture ring stiffness [N/m]";
  parameter Real c_capture = 60.0 "Capture ring damping [N/(m/s)]";

  // --- Disturbance ---
  parameter Real F_current = 203.0 "Cross-current force amplitude [N]";
  parameter Real t_start_dist = 20.0/3.0 "Disturbance start [s]";
  parameter Real t_end_dist = 40.0/3.0 "Disturbance end [s]";

  // --- Initial conditions ---
  parameter Real x0 = x_start "Initial x [m]";
  parameter Real y0 = y_start "Initial y [m]";
  parameter Real psi0 = 0.0 "Initial yaw [rad]";
  parameter Real u0 = 0.0 "Initial surge velocity [m/s]";
  parameter Real v0 = 0.0 "Initial sway velocity [m/s]";
  parameter Real r0 = 0.0 "Initial yaw rate [rad/s]";

  // --- Dynamic states ---
  Real x(start=x0, fixed=true) "ROV x position in world frame [m]";
  Real y(start=y0, fixed=true) "ROV y position in world frame [m]";
  Real psi(start=psi0, fixed=true) "ROV yaw heading [rad]";
  Real u(start=u0, fixed=true) "Surge velocity body x [m/s]";
  Real v(start=v0, fixed=true) "Sway velocity body y [m/s]";
  Real r(start=r0, fixed=true) "Yaw rate [rad/s]";

  // --- Observable / sensor traces ---
  Real d_range "Range to dock center [m]";
  Real e_x "Surge tracking error [m]";
  Real e_y "Sway tracking error [m]";
  Real e_psi "Yaw tracking error [rad]";
  Real u_meas "Surge velocity sensor [m/s]";
  Real v_meas "Sway velocity sensor [m/s]";
  Real r_meas "Yaw rate sensor [rad/s]";
  Real depth_meas "Depth (pressure-derived) [m]";
  Real psi_meas "Heading sensor [rad]";
  Real sonar_range "Sonar range to dock [m]";
  Real optical_pose_valid "Short-range optical pose available [1/0]";

  // --- Control signals ---
  Real Fx_cmd "Commanded surge force [N]";
  Real Fy_cmd "Commanded sway force [N]";
  Real Mz_cmd "Commanded yaw moment [N.m]";
  Real Fx_sat "Saturated surge force [N]";
  Real Fy_sat "Saturated sway force [N]";
  Real Mz_sat "Saturated yaw moment [N.m]";
  Real v_ref "Speed-scheduled approach reference [m/s]";
  Real schedule "Speed schedule factor";

  // --- Actuator envelope observables ---
  Real thruster_util "Fractional thruster utilization";

  // --- Contact / capture ---
  Real F_contact "Capture contact force magnitude [N]";
  Real Fc_x "Capture force x [N]";
  Real Fc_y "Capture force y [N]";
  Real penetration "Capture ring penetration [m]";
  Real in_contact "Contact established [1/0]";

  // --- Disturbance ---
  Real F_dist_y "Cross-current lateral disturbance [N]";

  // --- Diagnostics ---
  Real primary_track_err "Primary tracking error metric [m]";
  Real norm_err "Normalized error for divisor safety [m]";
  Boolean bounds_ok "Actuator/speed bounds satisfied";
  Boolean finite_ok "All physical/control/estimator finite";
  Boolean captured "Capture established flag";

  // --- Per-thruster force (mapped scalarly) ---
  Real F_thr_max_obs "Per-thruster force cap observed [N]";
  Real F_thr_envelope "Total thruster force envelope [N]";
  Real F_thr_used "Estimated total thruster force used [N]";
  Boolean per_thruster_ok "Per-thruster limit satisfied";

protected
  function sat "Scalar saturation with well-defined finite bounds"
    input Real x_in;
    input Real x_max;
    output Real y_out;
  algorithm
    if x_in > x_max then
      y_out := x_max;
    elseif x_in < -x_max then
      y_out := -x_max;
    else
      y_out := x_in;
    end if;
  end sat;

  function wrapAngle "Wrap angle to [-pi, pi]"
    input Real a;
    output Real w;
  algorithm
    w := a - 2.0*Modelica.Constants.pi*floor(0.5*(a + Modelica.Constants.pi)/Modelica.Constants.pi);
  end wrapAngle;

  function isFin "Proxy finiteness check avoiding Modelica.Math.isFinite"
    input Real z;
    output Boolean q;
  algorithm
    q := (abs(z) < 1.0e20);
  end isFin;

equation
  // --- Speed scheduling based on range ---
  d_range = sqrt((x - x_dock)^2 + (y - y_dock)^2);
  norm_err = max(d_range, 1e-6);
  schedule = sat(d_switch/max(norm_err,1e-6), 1.0);
  v_ref = schedule*v_approach_near + (1.0 - schedule)*v_approach_far;

  // --- Tracking errors (world frame, dock at origin aligned to +x approach) ---
  e_x = (x - x_dock) + 1.0;
  e_y = y - y_dock;
  e_psi = wrapAngle(psi - psi_dock);
  primary_track_err = sqrt((x - x_dock)^2 + (y - y_dock)^2);

  // --- Speed-scheduled pose controller ---
  Fx_cmd = Kp_x_far*schedule*(-e_x) + Kp_x_near*(1.0-schedule)*(-e_x)
           - Kd_x_far*schedule*u - Kd_x_near*(1.0-schedule)*u;
  Fy_cmd = -Kp_y*e_y - Kd_y*v;
  Mz_cmd = -Kp_psi*e_psi - Kd_psi*r;

  // --- Saturation (actuator and speed bounds) ---
  Fx_sat = sat(Fx_cmd, Fx_max);
  Fy_sat = sat(Fy_cmd, Fy_max);
  Mz_sat = sat(Mz_cmd, Mz_max);

  // --- Per-thruster envelope check (scalar proxy) ---
  F_thr_envelope = nthr*Fthr_max;
  F_thr_used = abs(Fx_sat) + abs(Fy_sat) + abs(Mz_sat)/0.5;
  F_thr_max_obs = Fthr_max;
  per_thruster_ok = F_thr_used <= F_thr_envelope + 1e-6;
  thruster_util = F_thr_used / max(F_thr_envelope, 1e-6);

  // --- Cross-current disturbance (middle third) ---
  if time >= t_start_dist and time <= t_end_dist then
    F_dist_y = F_current;
  else
    F_dist_y = 0.0;
  end if;

  // --- Compliant capture contact ---
  penetration = max(capture_radius - d_range, 0.0);
  in_contact = if penetration > 0.0 then 1.0 else 0.0;
  F_contact = k_capture*penetration + c_capture*(if in_contact > 0.5 then (-((x-x_dock)*u + (y-y_dock)*v)/max(norm_err,1e-6)) else 0.0);
  Fc_x = if in_contact > 0.5 then -F_contact*(x - x_dock)/max(norm_err,1e-6) else 0.0;
  Fc_y = if in_contact > 0.5 then -F_contact*(y - y_dock)/max(norm_err,1e-6) else 0.0;
  captured = (d_range <= capture_radius) and (abs(e_psi) < 0.1) and (time > 13.0);

  // --- Rigid-body dynamics (3-DOF horizontal plane) ---
  (m + m_add_x)*der(u) = Fx_sat - Dx_lin*u - Dx_quad*u*abs(u) + Fc_x;
  (m + m_add_y)*der(v) = Fy_sat - Dy_lin*v - Dy_quad*v*abs(v) + Fc_y + F_dist_y;
  (Izz + Izz_add)*der(r) = Mz_sat - Dr_lin*r - Dr_quad*r*abs(r);

  // Kinematics
  der(x) = u*cos(psi) - v*sin(psi);
  der(y) = u*sin(psi) + v*cos(psi);
  der(psi) = r;

  // --- Sensor traces (ideal, finite) ---
  u_meas = u;
  v_meas = v;
  r_meas = r;
  depth_meas = 0.0;
  psi_meas = wrapAngle(psi);
  sonar_range = max(d_range, 0.0);
  optical_pose_valid = if d_range <= 1.0 then 1.0 else 0.0;

  // --- Bounds verification ---
  bounds_ok = abs(Fx_sat) <= Fx_max + 1e-6 and abs(Fy_sat) <= Fy_max + 1e-6
              and abs(Mz_sat) <= Mz_max + 1e-6 and per_thruster_ok
              and abs(u) <= v_approach_far + 0.05 and F_contact <= 500.0;

  // --- Finite-value verification (proxy, no Modelica.Math.isFinite) ---
  finite_ok = isFin(x) and isFin(y) and isFin(psi) and isFin(u)
              and isFin(v) and isFin(r) and isFin(Fx_sat) and isFin(Fy_sat)
              and isFin(Mz_sat) and isFin(F_contact) and isFin(primary_track_err);

  annotation (
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="ROV free-base docking scenario. 500 Hz for 20 s. Speed-scheduled pose control with compliant capture contact transition and 203 N cross-current disturbance in the middle third of the run. Verification: actuator/speed bounds, lateral/yaw alignment, contact force < 500 N, primary tracking error < 0.08 m after 13 s, no NaN/infinite values.")
  );
end ROVDockF;