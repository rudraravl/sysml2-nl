model CatamaranDockA
  // ===== Physical parameters =====
  parameter Real m_hull(unit="kg") = 46.0 "mass of each capsule hull";
  parameter Real m_deck(unit="kg") = 18.0 "mass of rigid deck";
  parameter Real m_total(unit="kg") = 2.0*m_hull + m_deck "total dry mass";
  parameter Real sep(unit="m") = 1.1 "hull separation (port to starboard)";
  parameter Real Izz(unit="kg.m2") = (2.0*m_hull + m_deck)*(sep/2.0)^2 "yaw inertia estimate";
  parameter Real Fmax(unit="N") = 310.0 "per-propeller command magnitude limit";
  parameter Real dist0(unit="m") = 8.0 "distance from robot origin to docking funnel";
  // Hydrodynamic linear drag (assumed values; not specified by request)
  parameter Real Xu(unit="N.s/m") = 200.0 "surge linear drag";
  parameter Real Yv(unit="N.s/m") = 200.0 "sway linear drag";
  parameter Real Nr(unit="N.m.s/rad") = 40.0 "yaw linear drag";
  // Cross-current disturbance (middle third of 8 s scenario)
  parameter Real Fcurrent(unit="N") = 70.0 "current force magnitude";
  parameter Real t1(unit="s") = 8.0/3.0 "current onset";
  parameter Real t2(unit="s") = 16.0/3.0 "current cessation";
  // Compliant capture ring
  parameter Real k_cap(unit="N/m") = 600.0 "capture ring stiffness";
  parameter Real c_cap(unit="N.s/m") = 120.0 "capture ring damping";
  parameter Real captureR(unit="m") = 0.35 "capture engagement radius";
  // Controller
  parameter Real Ts(unit="s") = 1.0/80.0 "controller sample period (80 Hz)";
  parameter Real vmax(unit="m/s") = 2.5 "speed bound / cruise approach speed";
  parameter Real vclose(unit="m/s") = 0.15 "close-range speed inside 1 m";
  parameter Real kpv(unit="N.s/m") = 200.0 "surge velocity gain";
  parameter Real kpyaw(unit="N.m/rad") = 80.0 "heading proportional gain";
  parameter Real kdyaw(unit="N.m.s/rad") = 50.0 "yaw-rate damping gain";

  // ===== Continuous plant states =====
  Real x(start=0.0, unit="m") "world x position (toward dock)";
  Real y(start=0.0, unit="m") "world y position (lateral)";
  Real psi(start=0.0, unit="rad") "heading";
  Real vwx(start=0.0, unit="m/s") "world x velocity";
  Real vwy(start=0.0, unit="m/s") "world y velocity";
  Real r_psi(start=0.0, unit="rad/s") "yaw rate";

  // ===== Forces and moments =====
  Real F_port(unit="N") "port propeller realized force";
  Real F_stbd(unit="N") "starboard propeller realized force";
  Real F_surge(unit="N") "realized surge force";
  Real M_yaw(unit="N.m") "realized yaw moment";
  Real F_current_y(unit="N") "applied current force";
  Real F_contact_x(unit="N") "capture contact force, x";
  Real F_contact_y(unit="N") "capture contact force, y";
  Real F_contact_mag(unit="N") "contact force magnitude";
  Boolean engaged "capture engagement flag";

  // ===== Discrete controller (sampled) =====
  discrete Real x_est(start=0.0, unit="m");
  discrete Real y_est(start=0.0, unit="m");
  discrete Real psi_est(start=0.0, unit="rad");
  discrete Real vwx_est(start=0.0, unit="m/s");
  discrete Real r_est(start=8.0, unit="m");
  discrete Real vdes_raw(start=0.0, unit="m/s");
  discrete Real vdes(start=0.0, unit="m/s");
  discrete Real psi_des(start=0.0, unit="rad");
  discrete Real F_surge_cmd(start=0.0, unit="N");
  discrete Real M_cmd(start=0.0, unit="N.m");
  discrete Real F_port_cmd(start=0.0, unit="N");
  discrete Real F_stbd_cmd(start=0.0, unit="N");

  // ===== Sensors =====
  Real sonar_range(unit="m") "sonar range to funnel";
  Real pressure_depth(unit="m") "pressure-derived depth (planar, constant)";
  Real imu_yaw_rate(unit="rad/s") "IMU yaw-rate measurement";
  Real optical_x(unit="m") "short-range optical pose x";
  Real optical_y(unit="m") "short-range optical pose y";
  Boolean optical_valid "optical pose available flag";

  // ===== Verification traces =====
  Real track_err(unit="m") "primary tracking error (to dock center)";
  Real speed(unit="m/s") "speed magnitude";
  Boolean captured;
  Boolean speed_ok;
  Boolean actuator_ok;
  Boolean lateral_ok;
  Boolean yaw_ok;
  Boolean force_ok;
  Boolean track_ok;
  Boolean finite_ok;

equation
  // ===== Kinematics in world frame =====
  der(x) = vwx;
  der(y) = vwy;
  der(psi) = r_psi;

  // ===== Rigid-body dynamics (3-DOF horizontal plane) =====
  m_total*der(vwx) = (F_port + F_stbd)*cos(psi) - Xu*vwx + F_contact_x;
  m_total*der(vwy) = (F_port + F_stbd)*sin(psi) - Yv*vwy + F_current_y + F_contact_y;
  Izz*der(r_psi) = (F_stbd - F_port)*(sep/2.0) - Nr*r_psi;

  // ===== Propeller allocation with per-propeller saturation =====
  F_port = clamp(F_port_cmd, -Fmax, Fmax);
  F_stbd = clamp(F_stbd_cmd, -Fmax, Fmax);
  F_surge = F_port + F_stbd;
  M_yaw = (F_stbd - F_port)*(sep/2.0);

  // ===== Cross-current disturbance (middle third of scenario) =====
  F_current_y = if (time >= t1 and time <= t2) then Fcurrent else 0.0;

  // ===== Compliant capture ring =====
  engaged = (x > dist0 - captureR) and (abs(y) < captureR);
  F_contact_x = if engaged then (-k_cap*(x - dist0) - c_cap*vwx) else 0.0;
  F_contact_y = if engaged then (-k_cap*y - c_cap*vwy) else 0.0;
  F_contact_mag = sqrt(F_contact_x*F_contact_x + F_contact_y*F_contact_y);

  // ===== Sensors (with bounded, finite perturbations) =====
  sonar_range = max(dist0 - x, 0.0) + 0.005*sin(6.2831853*2.0*time);
  pressure_depth = 0.30;
  imu_yaw_rate = r_psi + 0.002*sin(6.2831853*1.5*time);
  optical_valid = (dist0 - x) < 1.0;
  optical_x = if optical_valid then x else 0.0;
  optical_y = if optical_valid then y else 0.0;

  // ===== Verification traces =====
  track_err = sqrt((dist0 - x)*(dist0 - x) + y*y);
  speed = sqrt(vwx*vwx + vwy*vwy);
  captured = engaged and (abs(dist0 - x) < 0.05) and (abs(y) < 0.05);
  speed_ok = speed <= vmax + 0.05;
  actuator_ok = (abs(F_port) <= Fmax + 0.5) and (abs(F_stbd) <= Fmax + 0.5);
  lateral_ok = (time > 5.5) implies (abs(y) < 0.05);
  yaw_ok = (time > 5.5) implies (abs(psi) < 0.1);
  force_ok = F_contact_mag < 500.0;
  track_ok = (time > 5.2) implies (track_err < 0.135);
  finite_ok = (abs(x) < 1.0e6) and (abs(y) < 1.0e6) and (abs(psi) < 1.0e6)
           and (abs(vwx) < 1.0e6) and (abs(vwy) < 1.0e6) and (abs(r_psi) < 1.0e6);

  // ===== Speed-scheduled pose controller at 80 Hz =====
  when sample(0, Ts) then
    // Sensor fusion: use short-range optical pose when in close range
    x_est = if optical_valid then optical_x else x;
    y_est = if optical_valid then optical_y else y;
    psi_est = psi;
    vwx_est = vwx;
    r_est = max(dist0 - x_est, 0.0);
    // Speed schedule: full cruise, reduce inside 1 m, stop at dock center
    vdes_raw = if r_est > 1.0 then vmax
               elseif r_est > 0.05 then vclose + (vmax - vclose)*(r_est - 0.05)/0.95
               else 0.0;
    // Halt thrust once capture is engaged
    vdes = if (x > dist0 - captureR and abs(y) < captureR) then 0.0 else vdes_raw;
    // Heading schedule: line-of-sight toward dock blended to zero alignment as r -> 0
    psi_des = (if r_est > 0.3 then 1.0 else r_est/0.3) * atan2(-y_est, max(r_est, 0.3));
    // Surge command with drag feedforward on desired speed
    F_surge_cmd = kpv*(vdes - vwx_est) + Xu*vdes;
    // Yaw moment command using IMU yaw-rate damping
    M_cmd = kpyaw*(psi_des - psi_est) - kdyaw*imu_yaw_rate;
    // Differential allocation across port/starboard propellers
    F_port_cmd = (F_surge_cmd - M_cmd/(sep/2.0))/2.0;
    F_stbd_cmd = (F_surge_cmd + M_cmd/(sep/2.0))/2.0;
  end when;

  annotation(experiment(StopTime=8.0, Tolerance=1.0e-4));
end CatamaranDockA;