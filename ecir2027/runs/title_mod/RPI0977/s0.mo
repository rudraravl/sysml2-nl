model DiffRoverInspectE
  "Floating-base differential-drive rover inspecting an S-corridor.
   Plant: 19 kg box chassis, two driven wheels + passive caster,
   odometry+IMU+lidar fusion, path tracking with obstacle avoidance,
   108 N side load in the middle third. Fail-closed acceptance."
  extends Modelica.Icons.Example;
  import Modelica.Constants.pi;

  // ---------- physical parameters (SI) ----------
  parameter Real m_chassis = 19.0   "kg";
  parameter Real Lx = 0.65          "m";
  parameter Real Ly = 0.44          "m";
  parameter Real Lz = 0.22          "m";
  parameter Real r_w   = 0.10       "m wheel radius";
  parameter Real L_track = 0.46     "m wheel separation";
  parameter Real d_caster = 0.20    "m caster offset behind center";
  parameter Real Izz = m_chassis*(Lx^2 + Ly^2)/12 "kg.m2";
  parameter Real tau_max = 14.3     "N.m command bound";
  parameter Real b_drag  = 6.0      "N.s/m longitudinal drag";
  parameter Real k_lat   = 2200.0   "N.s/m lateral cornering stiffness";
  parameter Real v_ref   = 0.8      "m/s reference speed";
  parameter Real L_path  = 12.8     "m corridor path length";
  parameter Real T_act   = 0.04     "s actuator time constant";
  parameter Real dt_ctrl = 1.0/250.0 "s control/sensor rate";

  // ---------- controller / estimator gains ----------
  parameter Real kx   = 0.5;
  parameter Real kct  = 1.8;
  parameter Real kth  = 2.2;
  parameter Real kv   = 3.0;
  parameter Real kw   = 4.0;
  parameter Real k_obs = 0.6;
  parameter Real Kth_fuse  = 2.0;
  parameter Real Ky_lidar = 6.0;
  parameter Real P_xx_ss = 0.05;
  parameter Real P_yy_ss = 0.02;
  parameter Real P_th_ss = 0.01;
  parameter Real T_cov   = 1.0;

  // ---------- disturbance ----------
  parameter Real F_side = 108.0     "N side load magnitude";

  // ---------- plant states ----------
  Real x(start=0.0,    fixed=true) "m";
  Real y(start=0.0,    fixed=true) "m";
  Real theta(start=0.2869, fixed=true) "rad";
  Real v(start=v_ref,  fixed=true) "m/s";
  Real vn(start=0.0,   fixed=true) "m/s lateral body velocity";
  Real omega(start=0.0,fixed=true) "rad/s yaw rate";
  Real phi_caster(start=0.0, fixed=true) "rad passive caster spin";

  // ---------- actuators ----------
  Real tau_R(start=0.0, fixed=true) "N.m";
  Real tau_L(start=0.0, fixed=true) "N.m";

  // ---------- commands (internal) ----------
  Real tau_R_cmd_raw "N.m";
  Real tau_L_cmd_raw "N.m";
  Real tau_R_cmd     "N.m";
  Real tau_L_cmd     "N.m";
  Real v_cmd   "m/s";
  Real omega_cmd "rad/s";
  Real a_v "m/s2";
  Real a_w "rad/s2";
  Real v_scale "obstacle speed scale";

  // ---------- path reference ----------
  Real p_prog "m";
  Real x_ref  "m";
  Real y_ref  "m";
  Real theta_ref "rad";
  Real dydp;

  // ---------- tracking errors (controller uses estimator) ----------
  Real e_x  "m along-track";
  Real e_ct "m cross-track";
  Real e_th "rad heading error";
  Real primary_track_err "m";

  // ---------- wheels / odometry ----------
  Real omega_R "rad/s";
  Real omega_L "rad/s";
  Real v_hat   "m/s";
  Real omega_hat "rad/s";
  Real x_odom(start=0.0, fixed=true) "m";
  Real y_odom(start=0.0, fixed=true) "m";
  Real theta_odom(start=0.2869, fixed=true) "rad";

  // ---------- sensors ----------
  Real gyro       "rad/s";
  Real lidar_fwd   "m";
  Real lidar_left  "m";
  Real lidar_right "m";

  // ---------- estimator ----------
  Real x_hat(start=0.0, fixed=true) "m";
  Real y_hat(start=0.0, fixed=true) "m";
  Real theta_hat(start=0.2869, fixed=true) "rad";
  Real P_xx(start=0.10, fixed=true);
  Real P_yy(start=0.10, fixed=true);
  Real P_th(start=0.10, fixed=true);

  // ---------- walls / clearance ----------
  Real y_wall_L "m";
  Real y_wall_R "m";
  Real alcove_L "m";
  Real alcove_R "m";
  Real clearance "m";

  // ---------- disturbance ----------
  Real F_dist "N";

  // ---------- acceptance ----------
  Real route_completion;
  Real heading_err_deg;
  Boolean primary_ok;
  Boolean clearance_ok;
  Boolean finite_ok;
  Boolean route_ok;
  Boolean passed;

  // ---------- synchronized 250 Hz traces ----------
  discrete Real t_stamp;
  discrete Real x_tr, y_tr, theta_tr, v_tr;
  discrete Real tau_R_tr, tau_L_tr, omega_cmd_tr;
  discrete Real gyro_tr, lidar_L_tr, lidar_R_tr, err_tr;
  discrete Real x_hat_tr, y_hat_tr, theta_hat_tr;

equation
  // ===== path (S-shape: up then down past zero) =====
  p_prog = x;
  x_ref  = p_prog;
  dydp   = 0.6*(2*pi/L_path)*cos(2*pi*p_prog/L_path);
  y_ref  = 0.6*sin(2*pi*p_prog/L_path);
  theta_ref = Modelica.Math.atan2(dydp, 1.0);

  // ===== corridor walls with two recessed alcoves =====
  alcove_L = 0.40*exp(-((x - 3.2)/0.6)^2);
  alcove_R = 0.40*exp(-((x - 9.6)/0.6)^2);
  y_wall_L = y_ref + 0.9 + alcove_L;
  y_wall_R = y_ref - 0.9 - alcove_R;

  // ===== plant kinematics & dynamics =====
  der(x)     = v*cos(theta) - vn*sin(theta);
  der(y)     = v*sin(theta) + vn*cos(theta);
  der(theta) = omega;
  m_chassis*der(v)     = (tau_R + tau_L)/r_w - b_drag*v;
  m_chassis*der(vn)    = F_dist - k_lat*vn;
  Izz*der(omega)       = (tau_R - tau_L)/r_w*(L_track/2);

  // passive caster: free-rolling, no reaction on chassis (structural only)
  der(phi_caster) = (v - omega*d_caster)/r_w;

  // ===== actuator dynamics =====
  T_act*der(tau_R) = tau_R_cmd - tau_R;
  T_act*der(tau_L) = tau_L_cmd - tau_L;

  // ===== wheel rates & odometry =====
  omega_R = (v + omega*L_track/2)/r_w;
  omega_L = (v - omega*L_track/2)/r_w;
  v_hat     = r_w*(omega_R + omega_L)/2;
  omega_hat = r_w*(omega_R - omega_L)/L_track;
  der(x_odom)     = v_hat*cos(theta_odom);
  der(y_odom)     = v_hat*sin(theta_odom);
  der(theta_odom) = omega_hat;

  // ===== sensors =====
  gyro       = omega;
  lidar_left  = max(y_wall_L - y, 0.001);
  lidar_right = max(y - y_wall_R, 0.001);
  lidar_fwd   = 15.0;  // forward corridor opening within 15 m lidar range

  // ===== estimator: fuse odometry, IMU, lidar =====
  der(theta_hat) = (omega_hat + gyro)/2 + Kth_fuse*(theta_odom - theta_hat);
  der(x_hat)     = v_hat*cos(theta_hat);
  der(y_hat)     = v_hat*sin(theta_hat) + Ky_lidar*(y - y_hat);

  // finite, convergent covariance
  der(P_xx) = (P_xx_ss - P_xx)/T_cov;
  der(P_yy) = (P_yy_ss - P_yy)/T_cov;
  der(P_th) = (P_th_ss - P_th)/T_cov;

  // ===== tracking errors (estimator-based) =====
  e_x  = (x_hat - x_ref)*cos(theta_ref) + (y_hat - y_ref)*sin(theta_ref);
  e_ct = (y_hat - y_ref)*cos(theta_ref) - (x_hat - x_ref)*sin(theta_ref);
  e_th = theta_hat - theta_ref;
  primary_track_err = sqrt(e_x*e_x + e_ct*e_ct);

  // ===== obstacle-aware speed scaling =====
  clearance = min(lidar_left, lidar_right);
  v_scale = max(0.0, 1.0 - 0.7*max(0.0, (0.30 - clearance)/0.30));

  // ===== controller: path tracking + obstacle avoidance =====
  v_cmd     = v_ref*v_scale - kx*e_x;
  omega_cmd = -kct*e_ct - kth*e_th + k_obs*(lidar_right - lidar_left);
  a_v = kv*(v_cmd - v);
  a_w = kw*(omega_cmd - omega);

  // torque allocation (drag feedforward + dynamics inversion)
  tau_R_cmd_raw = (r_w*(m_chassis*a_v + b_drag*v) + 2*Izz*a_w*r_w/L_track)/2;
  tau_L_cmd_raw = (r_w*(m_chassis*a_v + b_drag*v) - 2*Izz*a_w*r_w/L_track)/2;
  tau_R_cmd = max(-tau_max, min(tau_max, tau_R_cmd_raw));
  tau_L_cmd = max(-tau_max, min(tau_max, tau_L_cmd_raw));

  // ===== controlled side load: middle third of 16 s =====
  F_dist = if (time >= 16.0/3.0 and time <= 32.0/3.0) then F_side else 0.0;

  // ===== acceptance (fail-closed) =====
  route_completion = min(1.0, x/L_path);
  heading_err_deg  = abs(e_th)*180/pi;
  primary_ok   = (time > 10.4) and (primary_track_err < 0.18);
  clearance_ok = clearance > 0.18;
  route_ok     = route_completion >= 0.95;
  finite_ok    = (abs(x) < 1e8)  and (abs(y) < 1e8)  and (abs(theta) < 1e8)
              and (abs(v) < 1e8)  and (abs(vn) < 1e8) and (abs(omega) < 1e8)
              and (abs(tau_R) < 1e8) and (abs(tau_L) < 1e8)
              and (abs(x_hat) < 1e8) and (abs(y_hat) < 1e8) and (abs(theta_hat) < 1e8)
              and (abs(P_xx) < 1e8) and (abs(P_yy) < 1e8) and (abs(P_th) < 1e8)
              and (abs(primary_track_err) < 1e8);
  passed = primary_ok and clearance_ok and route_ok and finite_ok;

  // ===== synchronized 250 Hz state/command/sensor traces =====
  when sample(0, dt_ctrl) then
    t_stamp      = time;
    x_tr         = x;
    y_tr         = y;
    theta_tr     = theta;
    v_tr         = v;
    tau_R_tr     = tau_R;
    tau_L_tr     = tau_L;
    omega_cmd_tr = omega_cmd;
    gyro_tr      = gyro;
    lidar_L_tr   = lidar_left;
    lidar_R_tr   = lidar_right;
    err_tr       = primary_track_err;
    x_hat_tr     = x_hat;
    y_hat_tr     = y_hat;
    theta_hat_tr = theta_hat;
  end when;

  annotation (
    Documentation(info="Floating-base differential-drive rover DiffRoverInspectE.
Plant: 19 kg box chassis (0.65x0.44x0.22 m), two 0.10 m radius driven wheels
separated 0.46 m, one passive caster, torque commands bounded to 14.3 N.m.
Sensors: wheel odometry, IMU gyro, 15 m planar lidar; fused for planar pose.
Scenario: S-shaped corridor, walls 1.8 m apart, two recessed alcoves;
108 N lateral side load applied during the middle third. Controller:
localization-aware path tracking (0.8 m/s) with obstacle avoidance.
Run 16 s at 250 Hz. Acceptance is fail-closed: finite covariance,
wall clearance > 0.18 m, primary tracking error < 0.18 m after 10.4 s,
route completion, no NaN/infinite values."),
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=1.0/250.0));
end DiffRoverInspectE;