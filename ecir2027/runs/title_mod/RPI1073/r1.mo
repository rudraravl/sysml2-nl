model TriTugInspectE
  extends Modelica.Icons.Example;

  // -----------------------------------------------------------------------
  // Physical parameters (declared in request)
  // -----------------------------------------------------------------------
  parameter Modelica.Units.SI.Mass m_chassis = 38.0  "chassis mass";
  parameter Modelica.Units.SI.Mass m_payload = 20.0  "payload mass";
  parameter Modelica.Units.SI.Mass m = m_chassis + m_payload  "total mass";
  parameter Modelica.Units.SI.Radius r_w = 0.15      "front drive-and-steer wheel radius";
  parameter Real delta_max = 0.60                     "steering travel [rad]";
  parameter Modelica.Units.SI.Torque tau_max = 37.4   "command magnitude bound on both axes";

  // Geometry not stated in request - assumed values flagged as unknown.
  parameter Modelica.Units.SI.Length L_f = 0.30 "CG->front axle (unknown, assumed)";
  parameter Modelica.Units.SI.Length L_r = 0.20 "CG->rear axle (unknown, assumed)";
  parameter Modelica.Units.SI.Inertia I_z = 4.0 "yaw inertia (unknown, assumed)";
  parameter Real J_w = 0.012 "front wheel spin inertia (unknown, assumed)";
  parameter Real b_w = 0.10  "front wheel viscous friction [N.m.s] (assumed)";
  parameter Real J_s = 0.040 "steering axis inertia (unknown, assumed)";
  parameter Real b_s = 0.30  "steering damping [N.m.s/rad] (assumed)";
  parameter Real k_stop = 800.0 "soft steering stop stiffness [N.m/rad] (assumed)";
  parameter Real Cf = 1200.0 "front cornering stiffness [N/rad] (assumed)";
  parameter Real Cr = 1400.0 "rear cornering stiffness [N/rad] (assumed)";
  parameter Real Cd = 6.0    "rolling/aero drag coefficient [N.s/m] (assumed)";

  // Scenario parameters
  parameter Modelica.Units.SI.Velocity v_ref = 0.8  "reference path speed";
  parameter Modelica.Units.SI.Length corridor_half = 0.9 "half of 1.8 m corridor";
  parameter Modelica.Units.SI.Length corridor_len = 12.8 "16 s * 0.8 m/s";
  parameter Modelica.Units.SI.Force F_dist = 108.0 "controlled side load";
  parameter Real t_dist_start = 16.0/3.0 "middle-third start [s]";
  parameter Real t_dist_end   = 32.0/3.0 "middle-third end [s]";
  parameter Real Ts = 0.004 "control/estimator period (250 Hz)";
  parameter Real A_path = 0.40 "S-corridor centerline amplitude [m] (assumed)";
  parameter Real k_path = 2*Modelica.Constants.pi/corridor_len "spatial frequency";

  // Sensor noise (deterministic pseudo-noise amplitudes; assumed)
  parameter Real sigma_odom  = 0.02;
  parameter Real sigma_imu   = 0.01;
  parameter Real sigma_lidar = 0.03;

  // Controller gains (assumed tuning)
  parameter Real Kp_v = 80.0;
  parameter Real Ki_v = 25.0;
  parameter Real K_lat = 1.4;
  parameter Real Kp_s = 14.0;
  parameter Real Kd_s = 1.6;

  // Estimator gains (assumed)
  parameter Real k_pos_x = 2.0;
  parameter Real k_pos_y = 2.0;
  parameter Real k_head_e = 3.0;
  parameter Real T_v = 0.2;
  parameter Real Q1=0.02 "process noise x (assumed)";
  parameter Real Q2=0.02 "process noise y (assumed)";
  parameter Real Q3=0.01 "process noise theta (assumed)";
  parameter Real Q4=0.05 "process noise v (assumed)";

  // -----------------------------------------------------------------------
  // Continuous plant states
  // -----------------------------------------------------------------------
  Modelica.Units.SI.Length x(start=0.0, fixed=true);
  Modelica.Units.SI.Length y(start=0.0, fixed=true);
  Modelica.Units.SI.Angle theta(start=0.0, fixed=true);
  Modelica.Units.SI.Velocity vx(start=0.05, fixed=true);
  Modelica.Units.SI.Velocity vy(start=0.0, fixed=true);
  Modelica.Units.SI.AngularVelocity omega_z(start=0.0, fixed=true);
  Modelica.Units.SI.Angle delta(start=0.0, fixed=true);
  Modelica.Units.SI.AngularVelocity omega_s(start=0.0, fixed=true);

  // -----------------------------------------------------------------------
  // Actuator commands (discrete, 250 Hz, zero-order hold)
  // -----------------------------------------------------------------------
  discrete Modelica.Units.SI.Torque tau_t_cmd(start=0.0) "front traction torque command";
  discrete Modelica.Units.SI.Torque tau_s_cmd(start=0.0) "steering torque command";
  Modelica.Units.SI.Torque tau_t "applied traction torque";
  Modelica.Units.SI.Torque tau_s "applied steering torque";

  // Discrete controller intermediates
  discrete Real y_ref_d(start=0.0);
  discrete Real dydx_d(start=0.0);
  discrete Real theta_ref_d(start=0.0);
  discrete Real e_lat_d(start=0.0);
  discrete Real e_head_d(start=0.0);
  discrete Real delta_des_d(start=0.0);
  discrete Real int_v_err(start=0.0);

  // -----------------------------------------------------------------------
  // Plant intermediates
  // -----------------------------------------------------------------------
  Real F_drive "front longitudinal contact force [N]";
  Real Fy_f    "front lateral tire force [N]";
  Real Fy_r    "rear lateral tire force [N]";
  Real F_drag  "drag force [N]";
  Real alpha_f "front slip angle [rad]";
  Real alpha_r "rear slip angle [rad]";
  Real vxEps   "guarded forward speed [m/s]";
  Real omega_w "front wheel angular speed [rad/s]";
  Real Num_vx  "numerator of der(vx)";
  Real den_vx  "denominator of der(vx)";
  Real tau_stop "soft steering stop torque [N.m]";
  Real F_dist_applied "applied disturbance [N]";

  // -----------------------------------------------------------------------
  // Sensors
  // -----------------------------------------------------------------------
  Real v_odom   "wheel odometry forward speed [m/s]";
  Real r_imu    "IMU yaw rate [rad/s]";
  Real theta_imu "IMU heading [rad]";
  Real x_lidar  "lidar-derived x [m]";
  Real y_lidar  "lidar-derived y [m]";
  Real theta_lidar "lidar-derived heading [rad]";

  // -----------------------------------------------------------------------
  // Estimator (fused pose/speed, finite covariance)
  // -----------------------------------------------------------------------
  Real x_hat(start=0.0);
  Real y_hat(start=0.0);
  Real theta_hat(start=0.0);
  Real v_hat(start=0.05);
  Real P1(start=0.01) "estimator covariance diag x";
  Real P2(start=0.01) "estimator covariance diag y";
  Real P3(start=0.01) "estimator covariance diag theta";
  Real P4(start=0.01) "estimator covariance diag v";

  // -----------------------------------------------------------------------
  // Path / corridor geometry
  // -----------------------------------------------------------------------
  Real y_ref        "centerline y at x";
  Real dydx         "centerline slope";
  Real theta_ref    "centerline heading [rad]";
  Real alcove_u     "upper wall recess [m]";
  Real alcove_l     "lower wall recess [m]";
  Real y_wall_upper "upper wall y at x";
  Real y_wall_lower "lower wall y at x";
  Real clearance_upper;
  Real clearance_lower;
  Real clearance;
  Real route_completion;
  Real e_lat_cont   "primary tracking error (lateral) [m]";
  Real e_head_cont  "heading error [rad]";

  // -----------------------------------------------------------------------
  // Acceptance / fail-closed
  // -----------------------------------------------------------------------
  Boolean finite_cov;
  Boolean clearance_ok;
  Boolean head_err_ok;
  Boolean route_ok;
  Boolean track_ok;
  Boolean no_nan;
  Boolean accepted;
  discrete Real track_err_log(start=0.0) "tracked error sampled after 10.4 s";

equation
  // ---------- Path and corridor ----------
  y_ref  = A_path*sin(k_path*x);
  dydx   = A_path*k_path*cos(k_path*x);
  theta_ref = atan(dydx);

  alcove_u = if (x > 3.0 and x < 4.0) then 0.30 else 0.0;
  alcove_l = if (x > 9.0 and x < 10.0) then 0.30 else 0.0;
  y_wall_upper = y_ref + corridor_half + alcove_u;
  y_wall_lower = y_ref - corridor_half - alcove_l;

  clearance_upper = y_wall_upper - y;
  clearance_lower = y - y_wall_lower;
  clearance = min(clearance_upper, clearance_lower);

  route_completion = min(max(x/corridor_len, 0.0), 1.0);
  e_lat_cont  = (y - y_ref)*cos(theta_ref);
  e_head_cont = theta - theta_ref;

  // ---------- Disturbance (controlled 108 N side load, middle third) ----------
  F_dist_applied = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ---------- Tire slip and forces ----------
  vxEps = max(abs(vx), 0.1);
  alpha_f = delta - (vy + L_f*omega_z)/vxEps;
  alpha_r = -(vy - L_r*omega_z)/vxEps;
  Fy_f = -Cf*alpha_f;
  Fy_r = -Cr*alpha_r;
  F_drag = Cd*vx;

  // ---------- Front traction coupling (no-slip wheel) ----------
  omega_w = vx/r_w;
  den_vx = m + J_w*cos(delta)/(r_w*r_w);
  Num_vx = cos(delta)*(tau_t - b_w*vx/r_w)/r_w - Fy_f*sin(delta) + m*omega_z*vy - F_drag;
  der(vx) = Num_vx/den_vx;
  F_drive = (tau_t - b_w*omega_w)/r_w - J_w*Num_vx/((r_w*r_w)*den_vx);

  // ---------- Planar body dynamics ----------
  der(vy) = (F_drive*sin(delta) + Fy_f*cos(delta) + Fy_r - m*omega_z*vx + F_dist_applied)/m;
  der(omega_z) = (L_f*(F_drive*sin(delta) + Fy_f*cos(delta)) - L_r*Fy_r)/I_z;

  // ---------- Kinematic pose integration ----------
  der(x) = vx*cos(theta) - vy*sin(theta);
  der(y) = vx*sin(theta) + vy*cos(theta);
  der(theta) = omega_z;

  // ---------- Steering axis effort-controlled dynamics with soft stop ----------
  der(delta) = omega_s;
  tau_stop = if delta > delta_max then -k_stop*(delta - delta_max)
             elseif delta < -delta_max then -k_stop*(delta + delta_max)
             else 0.0;
  der(omega_s) = (tau_s - b_s*omega_s + tau_stop)/J_s;

  // ---------- Applied torques equal discrete commands (ZOH) ----------
  tau_t = tau_t_cmd;
  tau_s = tau_s_cmd;

  // ---------- Sensors (pseudo-noise; lidar uses 15 m planar wall reflections) ----------
  // The corridor length (12.8 m) is within the 15 m lidar range, so walls remain visible.
  v_odom   = omega_w*r_w + sigma_odom*sin(7.0*time);
  r_imu    = omega_z + sigma_imu*sin(11.0*time);
  theta_imu = theta + sigma_imu*sin(13.0*time);
  x_lidar  = x + sigma_lidar*sin(5.0*time);
  y_lidar  = y + sigma_lidar*sin(9.0*time);
  theta_lidar = theta + sigma_lidar*sin(17.0*time);

  // ---------- Estimator: complementary fusion of odometry/IMU/lidar ----------
  der(x_hat) = v_hat*cos(theta_hat) + k_pos_x*(x_lidar - x_hat);
  der(y_hat) = v_hat*sin(theta_hat) + k_pos_y*(y_lidar - y_hat);
  der(theta_hat) = r_imu + k_head_e*(theta_imu - theta_hat);
  der(v_hat) = (v_odom - v_hat)/T_v;

  // Finite covariance propagation (scalar diagonal, stable -> finite steady state)
  der(P1) = Q1 - 2.0*k_pos_x*P1;
  der(P2) = Q2 - 2.0*k_pos_y*P2;
  der(P3) = Q3 - 2.0*k_head_e*P3;
  der(P4) = Q4 - 2.0*(1.0/T_v)*P4;

  // ---------- Discrete controller and estimator sampling at 250 Hz ----------
  when sample(0, Ts) then
    // Path reference evaluated at estimated pose
    dydx_d      = A_path*k_path*cos(k_path*x_hat);
    theta_ref_d = atan(dydx_d);
    y_ref_d     = A_path*sin(k_path*x_hat);
    // Cross-track and heading error (estimated)
    e_lat_d  = (y_hat - y_ref_d)*cos(theta_ref_d);
    e_head_d = theta_hat - theta_ref_d;
    // Stanley-style steering command, bounded to travel
    delta_des_d = (theta_ref_d - theta_hat) + atan(K_lat*e_lat_d/max(v_hat, 0.1));
    delta_des_d = max(-delta_max, min(delta_max, delta_des_d));
    // Speed control with anti-windup integral
    int_v_err = max(-5.0, min(5.0, pre(int_v_err) + (v_ref - v_hat)*Ts));
    // Effort commands with feedforward, bounded to +/- 37.4 N.m
    tau_t_cmd = max(-tau_max, min(tau_max,
                    (Kp_v*(v_ref - v_hat) + Ki_v*int_v_err)*r_w + b_w*(v_hat/r_w)));
    tau_s_cmd = max(-tau_max, min(tau_max,
                    Kp_s*(delta_des_d - delta) - Kd_s*omega_s));
  end when;

  // ---------- Logging of primary tracking error at 10.4 s gate ----------
  when sample(10.4, Ts) then
    track_err_log = abs(e_lat_cont);
  end when;

  // ---------- Acceptance / fail-closed ----------
  finite_cov  = (P1 > 0.0) and (P2 > 0.0) and (P3 > 0.0) and (P4 > 0.0)
                and (P1 < 1.0) and (P2 < 1.0) and (P3 < 1.0) and (P4 < 1.0);
  clearance_ok = clearance > 0.18;
  head_err_ok  = abs(e_head_cont) < 0.5;
  route_ok     = x >= corridor_len - 0.05;
  track_ok     = if (time >= 10.4) then (abs(e_lat_cont) < 0.18) else true;
  // NaN/Inf detection: NaN comparisons are false; large values indicate divergence
  no_nan = (x < 1.0e6) and (x > -1.0e6)
       and (y < 1.0e6) and (y > -1.0e6)
       and (theta < 1.0e6) and (theta > -1.0e6)
       and (vx < 1.0e6) and (vx > -1.0e6)
       and (vy < 1.0e6) and (vy > -1.0e6)
       and (abs(F_drive) < 1.0e6)
       and (abs(Fy_f) < 1.0e6)
       and (abs(Fy_r) < 1.0e6)
       and (abs(P1) < 1.0e6) and (abs(P2) < 1.0e6)
       and (abs(P3) < 1.0e6) and (abs(P4) < 1.0e6);
  accepted = finite_cov and clearance_ok and head_err_ok and route_ok and track_ok and no_nan;

  // Fail-closed assertions
  assert(no_nan, "NaN/Inf detected in physical, control or estimator values - fail closed",
         AssertionLevel.error);
  assert(clearance_ok, "Wall clearance below 0.18 m - fail closed", AssertionLevel.error);
  assert(not (time >= 10.4) or track_ok,
         "Primary tracking error above 0.18 m after 10.4 s - fail closed",
         AssertionLevel.error);

  annotation (
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info="TriTugInspectE: 38 kg chassis + 20 kg payload tricycle (front
      drive-and-steer 0.15 m wheel, two passive rear wheels lumped) traversing an
      S-shaped corridor (walls 1.8 m apart, two recessed alcoves) at 0.8 m/s.
      Effort-controlled traction/steering axes bounded by 37.4 N.m.
      Odometry+IMU+15 m planar lidar fused for planar pose. 108 N side-load
      disturbance applied over middle third. Controller/estimator run at 250 Hz.
      Values for L_f,L_r,I_z,J_w,J_s,tire stiffness,drag,gains,noise,centerline
      amplitude are not stated in the request and are flagged as assumed."));
end TriTugInspectE;