model TrackCrawlerClimbA
  /* Floating-base tracked crawler climbing a ramp with plateau, ridges,
     slip-aware traction control, bounded braking, payload disturbance.
     Planar longitudinal + skid-steer yaw model. Unspecified geometric and
     control details (inertias, creep stiffness, ridge width, controller
     gains) are chosen as reasonable engineering values; nothing here is
     copied from any other source. */

  // ---- Physical parameters (stated) ----
  parameter Real m = 52.0          "kg, hull mass";
  parameter Real L_hull = 1.1      "m, hull length";
  parameter Real r_sprocket = 0.14  "m, effective sprocket radius";
  parameter Real B_track = 0.50     "m, track separation";
  parameter Real tau_max = 30.2     "N.m, per-drive command magnitude limit";
  parameter Real mu = 0.76         "friction coefficient";
  parameter Real ridge_h = 0.05    "m, surface ridge height";
  parameter Real ramp_deg = 12.0    "deg, ramp inclination";
  parameter Real plateau_len = 2.0 "m, plateau length (stated)";
  parameter Real F_payload = 75.0  "N, payload disturbance force";
  parameter Real Hz_ctrl = 80.0    "Hz, control rate";
  parameter Real T_run = 8.0       "s, scenario duration";

  // ---- Derived / chosen parameters ----
  parameter Real g = 9.81          "m/s^2";
  parameter Real ramp_angle = ramp_deg*Modelica.Constants.pi/180.0;
  parameter Real dt = 1.0/Hz_ctrl  "s, control period";
  parameter Real x_ramp_start = 0.2  "m";
  parameter Real ramp_len = 0.7      "m, chosen ramp horizontal length";
  parameter Real x_ramp_end = x_ramp_start + ramp_len;
  parameter Real h_plateau = ramp_len*Modelica.Math.tan(ramp_angle);
  parameter Real x_edge = x_ramp_end + plateau_len;  // descending edge
  parameter Real w_ridge = 0.20     "m, ridge half-width (chosen, unspecified)";
  parameter Real v_cruise = 0.50   "m/s, cruise speed (chosen)";
  parameter Real brake_start_depth = 0.70 "m, begin braking distance";
  parameter Real stop_margin = 0.15 "m, required stopping margin";
  parameter Real slip_soft = 0.20   "slip below which no traction cut";
  parameter Real slip_limit = 0.35  "slip hard limit (stated)";
  parameter Real Kp_speed = 18.0   "N.m per (m/s), speed gain (chosen)";
  parameter Real Kd_speed = 6.0    "N.m.s/m, speed damping (chosen)";
  parameter Real J_track = 0.40     "kg.m^2, per-track reflected inertia (chosen)";
  parameter Real K_creep = 6000.0   "N per (m/s) creep stiffness (chosen)";
  parameter Real J_yaw = 2.0        "kg.m^2, yaw inertia (chosen)";
  parameter Real c_yaw = 6.0        "N.m.s/rad, yaw damping (chosen)";
  parameter Real tau_pitch = 0.15   "s, pitch lag (chosen)";
  parameter Real vx_eps = 0.05      "m/s, slip divisor floor";

  // ---- Continuous states ----
  Real x(start=0.0, fixed=true)      "m, longitudinal position";
  Real vx(start=0.0, fixed=true)     "m/s, longitudinal speed";
  Real theta(start=0.0, fixed=true)  "rad, pitch angle";
  Real omegaL(start=0.0, fixed=true) "rad/s, left track angular velocity";
  Real omegaR(start=0.0, fixed=true) "rad/s, right track angular velocity";
  Real yaw(start=0.0, fixed=true)    "rad, heading";
  Real yawrate(start=0.0, fixed=true) "rad/s, yaw rate";

  // ---- Discrete control states ----
  discrete Real tauL_cmd(start=0.0) "N.m, left commanded torque";
  discrete Real tauR_cmd(start=0.0) "N.m, right commanded torque";
  discrete Real vref(start=0.0)     "m/s, speed reference";
  discrete Real vx_prev(start=0.0) "m/s, previous sampled speed";
  discrete Real depth_meas(start=0.0) "m, depth sensor reading";

  // ---- Applied torques (after slip-aware traction control) ----
  Real slipL, slipR, slipGainL, slipGainR;
  Real tauL_app, tauR_app;

  // ---- Contact forces & loads ----
  Real NL, NR, FcontactL, FcontactR;
  Real Fgrav, Fpayload;

  // ---- Terrain ----
  Real h_terrain, slope_terrain;
  Real ridge1, ridge2, dridge1, dridge2;

  // ---- Sensors (observable) ----
  Real enc_speed       "m/s, encoder-measured speed";
  Real imu_pitch       "rad, IMU pitch";
  Real imu_roll        "rad, IMU roll (planar model -> 0)";
  Real imu_yaw         "rad, IMU yaw";
  Real depth_sensor    "m, forward distance to descending edge";

  // ---- Performance / constraint monitors (observable) ----
  Real tracking_error  "m/s, |vx - vref|";
  Real slip_max        "max |slip| over tracks";
  Real stop_margin_meas "m, x_edge - x";
  Boolean cmd_saturatedL, cmd_saturatedR;
  Boolean slip_ok, pitch_ok, roll_ok, tracking_ok, margin_ok;

equation
  // ---------- Terrain profile ----------
  ridge1  = ridge_h * Modelica.Math.exp(-((x - 2.0)/w_ridge)^2);
  ridge2  = ridge_h * Modelica.Math.exp(-((x - 3.0)/w_ridge)^2);
  dridge1 = ridge_h * (-2.0*(x - 2.0)/w_ridge^2) * Modelica.Math.exp(-((x - 2.0)/w_ridge)^2);
  dridge2 = ridge_h * (-2.0*(x - 3.0)/w_ridge^2) * Modelica.Math.exp(-((x - 3.0)/w_ridge)^2);

  h_terrain = if x < x_ramp_start then 0.0
    else if x < x_ramp_end then (x - x_ramp_start)*Modelica.Math.tan(ramp_angle)
    else h_plateau + ridge1 + ridge2;

  slope_terrain = if x < x_ramp_start then 0.0
    else if x < x_ramp_end then Modelica.Math.tan(ramp_angle)
    else dridge1 + dridge2;

  // ---------- Pitch dynamics (quasi-static follow of terrain slope) ----------
  der(theta) = (slope_terrain - theta)/tau_pitch;

  // ---------- Normal loads ----------
  NL = m*g*Modelica.Math.cos(theta)/2.0;
  NR = m*g*Modelica.Math.cos(theta)/2.0;

  // ---------- Track creep contact forces (linear creep, friction capped) ----------
  FcontactL = Modelica.Math.StringsAdvanced.max? 
equation
  FcontactL = max(-mu*NL, min(mu*NL, K_creep*(r_sprocket*omegaL - vx)));
  FcontactR = max(-mu*NR, min(mu*NR, K_creep*(r_sprocket*omegaR - vx)));

  // ---------- Slip ratios (divisor with zero-error branch) ----------
  slipL = (r_sprocket*omegaL - vx)/max(abs(vx), vx_eps);
  slipR = (r_sprocket*omegaR - vx)/max(abs(vx), vx_eps);

  // ---------- Slip-aware traction control (bounded braking retained via cmd clamp) ----------
  slipGainL = max(0.0, 1.0 - 3.0*max(abs(slipL) - slip_soft, 0.0));
  slipGainR = max(0.0, 1.0 - 3.0*max(abs(slipR) - slip_soft, 0.0));
  tauL_app = tauL_cmd*slipGainL;
  tauR_app = tauR_cmd*slipGainR;

  // ---------- Longitudinal & yaw dynamics ----------
  Fgrav = m*g*Modelica.Math.sin(theta);
  Fpayload = if (time > T_run/3.0) and (time < 2.0*T_run/3.0) then F_payload else 0.0;

  der(x) = vx;
  m*der(vx) = FcontactL + FcontactR - Fgrav - Fpayload;

  J_track*der(omegaL) = tauL_app - r_sprocket*FcontactL;
  J_track*der(omegaR) = tauR_app - r_sprocket*FcontactR;

  der(yaw) = yawrate;
  J_yaw*der(yawrate) = (FcontactR - FcontactL)*(B_track/2.0) - c_yaw*yawrate;

  // ---------- Sensors ----------
  enc_speed    = vx;
  imu_pitch    = theta;
  imu_roll     = 0.0;            // planar straight-line model: roll identically zero
  imu_yaw      = yaw;
  depth_sensor = max(x_edge - x, 0.0);

  // ---------- Monitors ----------
  tracking_error   = abs(vx - vref);
  slip_max         = max(abs(slipL), abs(slipR));
  stop_margin_meas = x_edge - x;
  cmd_saturatedL   = abs(tauL_cmd) >= tau_max - 1e-6;
  cmd_saturatedR   = abs(tauR_cmd) >= tau_max - 1e-6;
  slip_ok    = slip_max < slip_limit;
  pitch_ok   = abs(theta) < 0.40;
  roll_ok    = abs(imu_roll) < 0.40;
  tracking_ok= (time < 5.2) or (tracking_error < 0.243);
  margin_ok  = stop_margin_meas >= 0.0;

  // ---------- Discrete controller at 80 Hz ----------
  when sample(0, dt) then
    vx_prev    = pre(vx);
    depth_meas = max(x_edge - x, 0.0);

    // Speed reference: cruise, brake ramp, stop with margin
    if depth_meas > brake_start_depth then
      vref = v_cruise;
    elseif depth_meas > stop_margin then
      vref = v_cruise * (depth_meas - stop_margin)/(brake_start_depth - stop_margin);
    else
      vref = 0.0;
    end if;

    // PD speed control with bounded command (skid-steer: equal torque, straight)
    tauL_cmd = max(-tau_max, min(tau_max,
                   Kp_speed*(vref - vx) + Kd_speed*((vref - vx) - (pre(vref) - pre(vx_prev)))/dt));
    tauR_cmd = tauL_cmd;
  end when;

  annotation (
    Documentation(info="TrackCrawlerClimbA: 52 kg tracked crawler ascending a 12 deg ramp onto a 2 m plateau with two 0.05 m ridges, slip-aware traction control, bounded braking, and a 75 N payload disturbance during the middle third. Runs 8 s at 80 Hz."),
    experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125)
  );
end TrackCrawlerClimbA;