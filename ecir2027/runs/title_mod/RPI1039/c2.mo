model TrackCrawlerClimbA
  "Floating-base tracked crawler ascending a ramp, traversing a plateau and stopping before the descending edge, with slip-aware traction control, bounded braking, ridge perturbations and a payload disturbance.";

  // ===== Parameters stated in the requirement =====
  parameter Real m_hull          = 52.0  "hull mass [kg]";
  parameter Real L_hull          = 1.1   "hull length [m]";
  parameter Real r_sprocket      = 0.14  "effective sprocket radius [m]";
  parameter Real track_sep       = 0.50  "track separation [m]";
  parameter Real tau_limit       = 30.2  "per-drive command torque magnitude limit [N.m]";
  parameter Real mu              = 0.76  "friction coefficient [-]";
  parameter Real ramp_deg        = 12.0  "ramp inclination [deg]";
  parameter Real plateau_len     = 2.0   "plateau length [m]";
  parameter Real ridge_height    = 0.05  "surface ridge height [m]";
  parameter Real F_dist          = 75.0  "payload disturbance force [N]";
  parameter Real f_rate          = 80.0  "control and sensor sampling rate [Hz]";
  parameter Real T_sim           = 8.0   "scenario duration [s]";
  parameter Real slip_limit      = 0.35  "required slip ratio upper bound [-]";
  parameter Real angle_limit     = 0.40  "required roll/pitch upper bound [rad]";
  parameter Real track_err_limit = 0.243 "required tracking error bound after 5.2 s [m/s]";
  parameter Real T_settle        = 5.2   "tracking-error settling time [s]";

  // ===== Assumed values (NOT specified in requirement) =====
  parameter Real ramp_len        = 2.0   "assumed ramp length [m] (not specified)";
  parameter Real v_cruise        = 0.65  "assumed cruise speed [m/s] (not specified)";
  parameter Real ridge_x1        = 2.4   "assumed ridge 1 position on plateau [m] (not specified)";
  parameter Real ridge_x2        = 3.4   "assumed ridge 2 position on plateau [m] (not specified)";
  parameter Real ridge_w         = 0.15  "assumed ridge half-width [m] (not specified)";
  parameter Real stop_margin     = 0.40  "assumed stopping margin before edge [m] (not specified)";
  parameter Real tau_pitch       = 0.15  "assumed pitch-following lag [s] (not specified)";
  parameter Real m_track_eff     = 5.0   "assumed effective track mass in linear terms [kg] (not specified)";
  parameter Real Kp_v            = 120.0 "assumed velocity proportional gain [N.m/(m/s)] (not specified)";
  parameter Real Ki_v            = 40.0  "assumed velocity integral gain [N.m/(m/s)/s] (not specified)";
  parameter Real v_eps           = 0.05  "slip normalization epsilon [m/s]";
  parameter Real v_slip_ref      = 0.30  "slip-velocity to friction saturation reference [m/s]";
  parameter Real C_drag          = 8.0   "assumed linear rolling resistance coefficient [N/(m/s)] (not specified)";
  parameter Real int_e_clamp     = 5.0   "integral anti-windup clamp [m]";
  parameter Real slip_reduce_on   = 0.20  "slip onset for traction reduction [-]";
  parameter Real slip_reduce_w   = 0.15  "slip reduction window width [-]";

  // ===== Derived constants =====
  constant Real pi = 3.141592653589793238;
  parameter Real ramp_angle    = ramp_deg * pi / 180.0;
  parameter Real g             = 9.81;
  parameter Real edge_x        = ramp_len + plateau_len;
  parameter Real T_dist_start  = T_sim / 3.0;
  parameter Real T_dist_end    = 2.0 * T_sim / 3.0;
  parameter Real dt_sample     = 1.0 / f_rate;

  // ===== Continuous states =====
  Real x_pos(start = 0.0)   "position along ground [m]";
  Real v(start = 0.0)       "forward hull speed [m/s]";
  Real theta(start = 0.0)  "pitch angle [rad]";
  Real roll(start = 0.0)   "roll angle [rad]";
  Real v_track(start = 0.0) "track surface speed [m/s]";

  // ===== Discrete controller / sensor variables =====
  discrete Real v_ref_d(start = 0.0)       "sampled velocity reference [m/s]";
  discrete Real tau_cmd_d(start = 0.0)     "sampled total torque command [N.m]";
  discrete Real tau_L_d(start = 0.0)       "sampled left drive torque [N.m]";
  discrete Real tau_R_d(start = 0.0)       "sampled right drive torque [N.m]";
  discrete Real int_e_d(start = 0.0)       "discrete integral of velocity error [m]";
  discrete Real slip_d(start = 0.0)        "sampled slip ratio [-]";
  discrete Real v_sensor(start = 0.0)      "sampled speed sensor [m/s]";
  discrete Real pitch_sensor(start = 0.0)  "sampled pitch sensor [rad]";
  discrete Real roll_sensor(start = 0.0)   "sampled roll sensor [rad]";
  discrete Real edge_dist_sensor(start = 2.0) "sampled forward depth / edge distance [m]";
  discrete Real x_sensor(start = 0.0)      "sampled position sensor [m]";

  // ===== Terrain, force and observable variables =====
  Real h_base        "base terrain height [m]";
  Real h_ridge1      "ridge 1 height contribution [m]";
  Real h_ridge2      "ridge 2 height contribution [m]";
  Real dhdx_base     "base terrain slope [m/m]";
  Real dhdx_ridge    "ridge slope contribution [m/m]";
  Real dhdx          "total terrain slope [m/m]";
  Real alpha_terrain "terrain slope angle [rad]";
  Real N             "normal force [N]";
  Real slip_ratio    "continuous slip ratio [-]";
  Real F_traction    "total traction force [N]";
  Real F_grav        "gravity along slope [N]";
  Real F_disturb     "payload disturbance force [N]";
  Real F_drag        "rolling resistance [N]";
  Real v_ref_cont    "continuous velocity reference [m/s]";
  Real track_err     "tracking error |v_ref - v| [m/s]";
  Real stop_margin_actual "remaining distance to descending edge [m]";
  Real slip_factor   "slip-aware traction reduction factor [-]";

  // ===== Constraint observables =====
  Real slip_ratio_obs "abs slip ratio for constraint [-]";
  Real roll_obs       "abs roll for constraint [rad]";
  Real pitch_obs      "abs pitch for constraint [rad]";
  Real track_err_obs  "tracking error for constraint [m/s]";
  Real tau_L_obs      "left torque magnitude for constraint [N.m]";
  Real tau_R_obs      "right torque magnitude for constraint [N.m]";

equation

  // --- Terrain geometry ---
  dhdx_base = if (x_pos < ramp_len) then Modelica.Math.tan(ramp_angle) else 0.0;
  h_ridge1  = ridge_height * Modelica.Math.exp(-((x_pos - ridge_x1)*(x_pos - ridge_x1)/(ridge_w*ridge_w)));
  h_ridge2  = ridge_height * Modelica.Math.exp(-((x_pos - ridge_x2)*(x_pos - ridge_x2)/(ridge_w*ridge_w)));
  dhdx_ridge = h_ridge1 * (-2.0*(x_pos - ridge_x1)/(ridge_w*ridge_w))
             + h_ridge2 * (-2.0*(x_pos - ridge_x2)/(ridge_w*ridge_w));
  dhdx = dhdx_base + dhdx_ridge;
  alpha_terrain = Modelica.Math.atan(dhdx);
  h_base = if (x_pos < ramp_len) then x_pos*Modelica.Math.tan(ramp_angle) else ramp_len*Modelica.Math.tan(ramp_angle);

  // --- Attitude dynamics (pitch follows terrain with first-order lag; planar => roll trivial) ---
  der(theta) = (alpha_terrain - theta) / tau_pitch;
  der(roll)  = 0.0;

  // --- Normal force ---
  N = m_hull * g * Modelica.Math.cos(theta);

  // --- Slip ratio (zero-safe denominator) ---
  slip_ratio = (v_track - v) / (abs(v_track) + v_eps);

  // --- Traction force (friction-limited, bounded via tanh) ---
  F_traction = mu * N * Modelica.Math.tanh((v_track - v) / v_slip_ref);

  // --- Forces on hull ---
  F_grav    = m_hull * g * Modelica.Math.sin(theta);
  F_disturb = if (time >= T_dist_start) and (time <= T_dist_end) then F_dist else 0.0;
  F_drag    = C_drag * v;

  // --- Hull longitudinal dynamics ---
  m_hull * der(v) = F_traction - F_grav - F_disturb - F_drag;
  der(x_pos) = v;

  // --- Track drive dynamics (lumped, reflected to linear track speed) ---
  der(v_track) = ((tau_L_d + tau_R_d) / r_sprocket - F_traction) / m_track_eff;

  // --- Slip-aware traction reduction factor (continuous, bounded braking) ---
  slip_factor = max(0.0, 1.0 - max(0.0, (abs(slip_ratio) - slip_reduce_on)/slip_reduce_w));

  // --- Continuous reference and tracking error ---
  v_ref_cont = if (edge_x - x_pos) < stop_margin then 0.0 else v_cruise;
  track_err  = abs(v_ref_cont - v);
  stop_margin_actual = edge_x - x_pos;

  // --- Constraint observables ---
  slip_ratio_obs = abs(slip_ratio);
  roll_obs       = abs(roll);
  pitch_obs      = abs(theta);
  track_err_obs  = track_err;
  tau_L_obs      = abs(tau_L_d);
  tau_R_obs      = abs(tau_R_d);

  // --- Discrete controller and sensors at 80 Hz ---
  when sample(0, dt_sample) then
    // Sensor sampling
    v_sensor         = v;
    pitch_sensor     = theta;
    roll_sensor      = roll;
    x_sensor         = x_pos;
    edge_dist_sensor = edge_x - x_pos;
    slip_d           = slip_ratio;

    // Velocity reference: cruise, then stop before descending edge
    v_ref_d = if (edge_x - x_pos) < stop_margin then 0.0 else v_cruise;

    // PI velocity error integral with anti-windup
    int_e_d = max(-int_e_clamp, min(int_e_clamp, int_e_d + (v_ref_d - v_sensor) * dt_sample));

    // Total torque command: PI with slip-aware reduction, bounded to +/- 2*tau_limit
    tau_cmd_d = max(-2.0*tau_limit, min(2.0*tau_limit,
                  (Kp_v*(v_ref_d - v_sensor) + Ki_v*int_e_d) * slip_factor));

    // Split equally to two drives, each bounded to +/- tau_limit
    tau_L_d = max(-tau_limit, min(tau_limit, tau_cmd_d/2.0));
    tau_R_d = max(-tau_limit, min(tau_limit, tau_cmd_d/2.0));
  end when;

  // --- Soft constraint warnings (non-blocking so traces are retained) ---
  assert(tau_L_obs <= tau_limit + 1e-6, "Left actuator limit exceeded", AssertionLevel.warning);
  assert(tau_R_obs <= tau_limit + 1e-6, "Right actuator limit exceeded", AssertionLevel.warning);
  assert(slip_ratio_obs < slip_limit,   "Slip ratio limit exceeded", AssertionLevel.warning);
  assert(roll_obs  < angle_limit,       "Roll limit exceeded", AssertionLevel.warning);
  assert(pitch_obs < angle_limit,       "Pitch limit exceeded", AssertionLevel.warning);
  assert(stop_margin_actual > 0.0,      "Stopping margin violated: reached descending edge", AssertionLevel.warning);
  assert(track_err_obs < track_err_limit or time < T_settle, "Tracking error limit exceeded after settling time", AssertionLevel.warning);

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "TrackCrawlerClimbA: planar floating-base tracked mobile robot. "
      "Ramp length, cruise speed, ridge positions, pitch lag, track inertia, drag and control gains are assumed "
      "because they are not stated in the requirement. Roll is trivial in this planar model and satisfies the "
      "0.40 rad bound. The 75 N payload disturbance is applied during the middle third of the 8 s scenario. "
      "All numeric facts are taken solely from the requirement."));
end TrackCrawlerClimbA;