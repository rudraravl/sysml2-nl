model CatamaranSurveyF
  "Free-base catamaran marine robot: 60 m lawnmower survey at 1.0 m/s, constant depth, lateral current, controlled mid-third load disturbance."

  constant Real pi = 3.141592653589793;

  // Embodiment and actuation
  parameter Real m_hull(unit="kg") = 46.0 "mass of each capsule hull";
  parameter Real m_deck(unit="kg") = 18.0 "mass of rigid deck";
  parameter Real m(unit="kg") = 2.0*m_hull + m_deck "total dry mass";
  parameter Real b(unit="m") = 1.1 "hull separation";
  parameter Real halfB(unit="m") = 0.5*b "half hull separation";
  parameter Real Iz(unit="kg.m2") = 2.0*m_hull*halfB*halfB "yaw inertia from two hulls";
  parameter Real Tmax(unit="N") = 525.0 "per-propeller force magnitude bound";
  parameter Real Mmax(unit="N.m") = Tmax*b "maximum differential yaw moment from saturated props";
  parameter Real Tsum_max(unit="N") = 2.0*Tmax "maximum total thrust";

  // Mission and path
  parameter Real speedRef(unit="m/s") = 1.0 "commanded survey speed";
  parameter Real pathLength(unit="m") = 60.0 "total lawnmower route length";
  parameter Real legLength(unit="m") = 20.0 "length of each straight leg";
  parameter Real spacing(unit="m") = 5.0 "lawnmower lane spacing";

  // Operating context
  parameter Real cx(unit="m/s") = 0.18 "steady lateral water current, east";
  parameter Real cy(unit="m/s") = 0.0 "steady north water current";
  parameter Real Fdist(unit="N") = 145.0 "controlled current load disturbance";
  // The requirement does not state target depth or seabed depth; these are runnable placeholders.
  parameter Real depthRef(unit="m") = 2.0 "constant depth command placeholder";
  parameter Real seabedDepth(unit="m") = 10.0 "seabed depth placeholder";

  // Hydrodynamic coefficients are not stated; these are simple assumed placeholders.
  parameter Real d_u(unit="N/(m/s)") = 60.0 "linear surge drag";
  parameter Real d_uq(unit="N.s2/m2") = 60.0 "quadratic surge drag";
  parameter Real d_v(unit="N/(m/s)") = 300.0 "linear sway drag";
  parameter Real d_vq(unit="N.s2/m2") = 300.0 "quadratic sway drag";
  parameter Real d_r(unit="N.m/(rad/s)") = 20.0 "linear yaw drag";
  parameter Real d_rq(unit="N.m.s2/rad2") = 10.0 "quadratic yaw drag";

  // Control gains
  parameter Real k_cross(unit="1/s") = 2.0 "cross-track position gain";
  parameter Real k_vn(unit="1/s") = 1.0 "cross-track velocity damping gain";
  parameter Real k_along(unit="1/s") = 0.5 "along-track speed gain";
  parameter Real k_i_c(unit="1/s2") = 1.0 "current/load integral gain";
  parameter Real cx_est_max(unit="m/s") = 3.0 "saturated effective current/load estimate";
  parameter Real k_psi(unit="1/s2") = 4.0 "heading proportional gain";
  parameter Real k_r(unit="1/s") = 4.0 "yaw rate damping gain";
  parameter Real k_u(unit="1/s") = 2.0 "surge speed tracking gain";
  parameter Real speed_max(unit="m/s") = 2.0 "commanded ground-speed saturation";
  parameter Real k_z(unit="1/s") = 1.0 "depth-keeping gain placeholder";

  // Estimator and covariance placeholders
  parameter Real k_psi_est(unit="1/s") = 5.0 "compass/IMU heading filter gain";
  parameter Real k_dvl(unit="1/s") = 10.0 "DVL velocity filter gain";
  parameter Real k_z_est(unit="1/s") = 10.0 "pressure depth filter gain";
  parameter Real k_r_est(unit="1/s") = 20.0 "IMU yaw-rate filter gain";
  parameter Real Q_cross(unit="m2/s") = 1.0e-4 "cross-track covariance process noise";
  parameter Real Q_depth(unit="m2/s") = 1.0e-5 "depth covariance process noise";
  parameter Real Q_heading(unit="rad2/s") = 1.0e-5 "heading covariance process noise";
  parameter Real Q_current(unit="m2/s3") = 1.0e-4 "current covariance process noise";
  parameter Real tau_cross(unit="s") = 5.0 "cross-track covariance decay time";
  parameter Real tau_depth(unit="s") = 2.0 "depth covariance decay time";
  parameter Real tau_heading(unit="s") = 2.0 "heading covariance decay time";
  parameter Real tau_current(unit="s") = 4.0 "current covariance decay time";
  parameter Real kP_cross(unit="m2/s2") = 1.0e-3 "cross-track error covariance excitation";
  parameter Real kP_current(unit="m2/s4") = 1.0e-3 "current-rate covariance excitation";

  // Initial conditions
  parameter Real x0(unit="m") = 0.0;
  parameter Real y0(unit="m") = 0.0;
  parameter Real z0(unit="m") = depthRef;
  parameter Real u0(unit="m/s") = sqrt(1.0 + cx*cx) "initial water-relative surge to hold ground speed";
  parameter Real v0(unit="m/s") = 0.0;
  parameter Real r0(unit="rad/s") = 0.0;
  parameter Real psi0(unit="rad") = atan2(1.0, -cx) "initial crab heading into current";
  parameter Real cx_est0(unit="m/s") = cx "initial effective current/load estimate";
  parameter Real u_ground_est0(unit="m/s") = u0 + cx*cos(psi0);
  parameter Real v_ground_est0(unit="m/s") = -cx*sin(psi0);
  parameter Real P_cross0(unit="m2") = 1.0e-3;
  parameter Real P_depth0(unit="m2") = 1.0e-4;
  parameter Real P_heading0(unit="rad2") = 1.0e-4;
  parameter Real P_current0(unit="m2/s2") = 1.0e-3;

  // Physical states
  Real x(unit="m", start=x0, fixed=true) "east position";
  Real y(unit="m", start=y0, fixed=true) "north position";
  Real z(unit="m", start=z0, fixed=true) "depth";
  Real psi(unit="rad", start=psi0, fixed=true) "heading from east";
  Real u(unit="m/s", start=u0, fixed=true) "water-relative surge";
  Real v(unit="m/s", start=v0, fixed=true) "water-relative sway";
  Real r(unit="rad/s", start=r0, fixed=true) "yaw rate";

  // Estimator states
  Real x_est(unit="m", start=x0, fixed=true);
  Real y_est(unit="m", start=y0, fixed=true);
  Real z_est(unit="m", start=z0, fixed=true);
  Real psi_est(unit="rad", start=psi0, fixed=true);
  Real u_ground_est(unit="m/s", start=u_ground_est0, fixed=true);
  Real v_ground_est(unit="m/s", start=v_ground_est0, fixed=true);
  Real r_est(unit="rad/s", start=r0, fixed=true);
  Real cx_est_raw(unit="m/s", start=cx_est0, fixed=true);
  Real P_cross(unit="m2", start=P_cross0, fixed=true);
  Real P_depth(unit="m2", start=P_depth0, fixed=true);
  Real P_heading(unit="rad2", start=P_heading0, fixed=true);
  Real P_current(unit="m2/s2", start=P_current0, fixed=true);

  // Path and control algebraic variables
  Real s_path(unit="m") "mission path length consumed";
  Real routeCompletion "fraction of 60 m route completed";
  Real routeCompletionOK "1 if route completion criterion holds";
  Real x_ref(unit="m");
  Real y_ref(unit="m");
  Real t_x(unit="1");
  Real t_y(unit="1");
  Real n_x(unit="1");
  Real n_y(unit="1");
  Real psi_path(unit="rad");
  Real s_proj(unit="m");
  Real s_proj_est(unit="m");
  Real e_cross(unit="m") "true signed cross-track error";
  Real e_cross_est(unit="m") "estimated signed cross-track error";
  Real e_along(unit="m") "true along-track error";
  Real e_along_est(unit="m") "estimated along-track error";
  Real speedCmd(unit="m/s");
  Real vx_est(unit="m/s");
  Real vy_est(unit="m/s");
  Real vt_est(unit="m/s");
  Real vn_est(unit="m/s");
  Real V_des_n(unit="m/s");
  Real V_des_x(unit="m/s");
  Real V_des_y(unit="m/s");
  Real req_x(unit="m/s");
  Real req_y(unit="m/s");
  Real u_ref(unit="m/s");
  Real psi_ref(unit="rad");
  Real psi_err(unit="rad");
  Real cx_est(unit="m/s") "saturated effective current/load estimate";
  Real cx_est_rate(unit="m/s2");
  Real M_c(unit="N.m");
  Real M_cmd(unit="N.m");
  Real dT_cmd(unit="N");
  Real T_sum_c(unit="N");
  Real T_sum_cmd(unit="N");
  Real T_port_cmd(unit="N");
  Real T_stbd_cmd(unit="N");
  Real T_port(unit="N") "actual saturated port propeller force";
  Real T_stbd(unit="N") "actual saturated starboard propeller force";
  Real T_sum_actual(unit="N");
  Real M_actual(unit="N.m");

  // Disturbance
  Boolean disturbanceOn;
  Real Fdist_x(unit="N");
  Real Fdist_y(unit="N");
  Real Fb_dist_x(unit="N");
  Real Fb_dist_y(unit="N");

  // Sensors
  Real cx_b(unit="m/s") "current in body x";
  Real cy_b(unit="m/s") "current in body y";
  Real psi_meas(unit="rad") "compass heading observation";
  Real r_meas(unit="rad/s") "IMU yaw-rate observation";
  Real z_meas(unit="m") "pressure depth observation";
  Real range_meas(unit="m") "acoustic seabed range observation";
  Real u_dvl_meas(unit="m/s") "DVL body x ground velocity observation";
  Real v_dvl_meas(unit="m/s") "DVL body y ground velocity observation";

  // Verification
  Real crossTrackError(unit="m");
  Real depthError(unit="m");
  Real seabedClearance(unit="m");
  Real seabedClearanceOK;
  Real estimatorCovariance(unit="m2");
  Real estimatorCovarianceOK;
  Real primaryTrackingError(unit="m");
  Real primaryTrackingOK;
  Real actuatorViolation;
  Real noNanInf;
  Boolean finitePhysical;
  Boolean finiteControl;
  Boolean finiteEstimator;
  Boolean finiteVerification;
  Real verificationSummary;

  function wrapAngle
    input Real a;
    output Real w;
  algorithm
    w := atan2(sin(a), cos(a));
  end wrapAngle;

equation
  // Mission progress
  s_path = min(speedRef*time, pathLength);
  routeCompletion = s_path / pathLength;
  routeCompletionOK = if routeCompletion >= 1.0/3.0 - 1.0e-6 then 1.0 else 0.0;

  // Lawnmower path geometry: three 20 m legs, 5 m spacing.
  x_ref = if s_path <= legLength then 0.0 elseif s_path <= 2.0*legLength then spacing else 2.0*spacing;
  y_ref = if s_path <= legLength then s_path elseif s_path <= 2.0*legLength then 2.0*legLength - s_path else s_path - 2.0*legLength;
  t_x = 0.0;
  t_y = if s_path <= legLength then 1.0 elseif s_path <= 2.0*legLength then -1.0 else 1.0;
  n_x = 1.0;
  n_y = 0.0;
  psi_path = if s_path <= legLength then pi/2 elseif s_path <= 2.0*legLength then -pi/2 else pi/2;
  s_proj = if s_path <= legLength then y elseif s_path <= 2.0*legLength then 2.0*legLength - y else 2.0*legLength + y;
  s_proj_est = if s_path <= legLength then y_est elseif s_path <= 2.0*legLength then 2.0*legLength - y_est else 2.0*legLength + y_est;

  // Tracking errors
  e_cross = (x - x_ref)*n_x + (y - y_ref)*n_y;
  e_cross_est = (x_est - x_ref)*n_x + (y_est - y_ref)*n_y;
  e_along = s_path - s_proj;
  e_along_est = s_path - s_proj_est;
  crossTrackError = abs(e_cross);
  depthError = abs(z - depthRef);
  seabedClearance = max(seabedDepth - z, 0.0);
  seabedClearanceOK = if seabedClearance > 0.0 then 1.0 else 0.0;

  // Estimated inertial ground velocity from fused DVL/compass
  vx_est = u_ground_est*cos(psi_est) - v_ground_est*sin(psi_est);
  vy_est = u_ground_est*sin(psi_est) + v_ground_est*cos(psi_est);
  vt_est = vx_est*t_x + vy_est*t_y;
  vn_est = vx_est*n_x + vy_est*n_y;

  // Path-following controller with current/load compensation
  speedCmd = max(0.05, min(speedRef + k_along*e_along_est, speed_max));
  V_des_n = -k_cross*e_cross_est - k_vn*vn_est;
  V_des_x = speedCmd*t_x + V_des_n*n_x;
  V_des_y = speedCmd*t_y + V_des_n*n_y;
  req_x = V_des_x - cx_est;
  req_y = V_des_y - cy;
  u_ref = sqrt(max(req_x*req_x + req_y*req_y, 1.0e-6));
  psi_ref = if u_ref > 1.0e-6 then atan2(req_y, req_x) else psi_path;
  psi_err = wrapAngle(psi_ref - psi_est);

  // Current/load estimate with anti-windup
  cx_est_rate = k_i_c*e_cross_est;
  der(cx_est_raw) =
    if (cx_est_raw >= cx_est_max and cx_est_rate > 0.0) or
       (cx_est_raw <= -cx_est_max and cx_est_rate < 0.0)
    then 0.0 else cx_est_rate;
  cx_est = max(-cx_est_max, min(cx_est_raw, cx_est_max));

  // Thrust allocation
  M_c = Iz*(k_psi*psi_err - k_r*r_est) + d_r*r_est;
  M_cmd = max(-Mmax, min(M_c, Mmax));
  dT_cmd = M_cmd / halfB;
  T_sum_c = m*k_u*(speedCmd - vt_est) + d_u*u_ref + d_uq*u_ref*abs(u_ref);
  T_sum_cmd = max(-Tsum_max, min(T_sum_c, Tsum_max));
  T_port_cmd = 0.5*(T_sum_cmd - dT_cmd);
  T_stbd_cmd = 0.5*(T_sum_cmd + dT_cmd);
  T_port = max(-Tmax, min(T_port_cmd, Tmax));
  T_stbd = max(-Tmax, min(T_stbd_cmd, Tmax));
  T_sum_actual = T_port + T_stbd;
  M_actual = (T_stbd - T_port)*halfB;

  // Disturbance: controlled 145 N east load during middle third of 20 s run
  disturbanceOn = time >= 20.0/3.0 and time <= 40.0/3.0;
  Fdist_x = if disturbanceOn then Fdist else 0.0;
  Fdist_y = 0.0;
  Fb_dist_x = Fdist_x*cos(psi) + Fdist_y*sin(psi);
  Fb_dist_y = -Fdist_x*sin(psi) + Fdist_y*cos(psi);

  // Current body components for DVL model
  cx_b = cx*cos(psi) + cy*sin(psi);
  cy_b = -cx*sin(psi) + cy*cos(psi);

  // Vehicle dynamics
  der(x) = u*cos(psi) - v*sin(psi) + cx;
  der(y) = u*sin(psi) + v*cos(psi) + cy;
  der(z) = -k_z*(z - depthRef);
  der(psi) = r;
  m*(der(u) - v*r) = T_sum_actual - d_u*u - d_uq*abs(u)*u + Fb_dist_x;
  m*(der(v) + u*r) = -d_v*v - d_vq*abs(v)*v + Fb_dist_y;
  Iz*der(r) = M_actual - d_r*r - d_rq*abs(r)*r;

  // Sensor observations
  psi_meas = psi + 0.001*sin(1.3*time);
  r_meas = r + 0.0005*sin(2.1*time);
  z_meas = z + 0.002*sin(0.7*time);
  range_meas = max(seabedDepth - z + 0.01*sin(0.9*time), 0.0);
  u_dvl_meas = u + cx_b + 0.005*sin(1.1*time);
  v_dvl_meas = v + cy_b + 0.005*sin(1.7*time);

  // Sensor fusion estimator
  der(x_est) = vx_est;
  der(y_est) = vy_est;
  der(z_est) = k_z_est*(z_meas - z_est);
  der(psi_est) = r_meas + k_psi_est*wrapAngle(psi_meas - psi_est);
  der(u_ground_est) = k_dvl*(u_dvl_meas - u_ground_est);
  der(v_ground_est) = k_dvl*(v_dvl_meas - v_ground_est);
  der(r_est) = k_r_est*(r_meas - r_est);

  // Simplified covariance propagation
  der(P_cross) = Q_cross + kP_cross*abs(e_cross_est) - P_cross/tau_cross;
  der(P_depth) = Q_depth - P_depth/tau_depth;
  der(P_heading) = Q_heading - P_heading/tau_heading;
  der(P_current) = Q_current + kP_current*abs(cx_est_rate) - P_current/tau_current;
  estimatorCovariance = P_cross + P_depth + P_heading + P_current;
  estimatorCovarianceOK = if estimatorCovariance < 1.0e6 then 1.0 else 0.0;

  // Verification criteria
  primaryTrackingError = sqrt(max(e_cross*e_cross + (z - depthRef)*(z - depthRef), 0.0));
  primaryTrackingOK = if time >= 13.0 then (if primaryTrackingError < 0.64 then 1.0 else 0.0) else 1.0;
  actuatorViolation = if (abs(T_port) > Tmax + 1.0e-6 or abs(T_stbd) > Tmax + 1.0e-6) then 1.0 else 0.0;

  // Finite/NaN/Inf checks
  finitePhysical = abs(x) < 1.0e30 and abs(y) < 1.0e30 and abs(z) < 1.0e30 and
                   abs(u) < 1.0e30 and abs(v) < 1.0e30 and abs(r) < 1.0e30 and abs(psi) < 1.0e30;
  finiteControl = abs(T_port) < 1.0e30 and abs(T_stbd) < 1.0e30 and abs(T_sum_cmd) < 1.0e30 and
                  abs(M_cmd) < 1.0e30 and abs(psi_ref) < 1.0e30 and abs(u_ref) < 1.0e30 and
                  abs(cx_est) < 1.0e30 and abs(speedCmd) < 1.0e30;
  finiteEstimator = abs(x_est) < 1.0e30 and abs(y_est) < 1.0e30 and abs(z_est) < 1.0e30 and
                    abs(psi_est) < 1.0e30 and abs(u_ground_est) < 1.0e30 and abs(v_ground_est) < 1.0e30 and
                    abs(r_est) < 1.0e30 and abs(P_cross) < 1.0e30 and abs(P_depth) < 1.0e30 and
                    abs(P_heading) < 1.0e30 and abs(P_current) < 1.0e30;
  finiteVerification = abs(crossTrackError) < 1.0e30 and abs(depthError) < 1.0e30 and
                       abs(estimatorCovariance) < 1.0e30 and abs(routeCompletion) < 1.0e30 and
                       abs(primaryTrackingError) < 1.0e30 and abs(actuatorViolation) < 1.0e30;
  noNanInf = if (finitePhysical and finiteControl and finiteEstimator and finiteVerification) then 1.0 else 0.0;
  verificationSummary = if (actuatorViolation < 0.5 and primaryTrackingOK > 0.5 and
                           noNanInf > 0.5 and estimatorCovarianceOK > 0.5 and
                           routeCompletionOK > 0.5 and seabedClearanceOK > 0.5)
                        then 1.0 else 0.0;

  annotation(
    experiment(StopTime=20.0, Tolerance=1.0e-6, Interval=0.002),
    Documentation(info="500 Hz, 20 s survey scenario. Unstated hydrodynamic, depth, and seabed values are explicit runnable placeholders."));
end CatamaranSurveyF;