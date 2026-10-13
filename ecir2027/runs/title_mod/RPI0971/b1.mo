model DiffRoverClimbE
  extends Modelica.Icons.Example;

  // ---------- Physical and structural parameters ----------
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real m_chassis = 19.0 "Chassis mass [kg]";
  parameter Real Lx = 0.65 "Chassis length [m]";
  parameter Real Ly = 0.44 "Chassis width [m]";
  parameter Real Lz = 0.22 "Chassis height [m]";
  parameter Real r_w = 0.10 "Wheel radius [m]";
  parameter Real L_track = 0.46 "Wheel separation [m]";
  parameter Real Iw = 0.02 "Wheel inertia [kg.m2]";
  parameter Real f_driven = 1.0 "Driven-wheel load fraction";
  parameter Real tau_max = 14.3 "Per-motor torque limit [N.m]";
  parameter Real mu = 0.76 "Friction coefficient";
  parameter Real theta_r = 12.0*Modelica.Constants.pi/180.0 "Ramp angle [rad]";
  parameter Real L_ramp = 2.0 "Ramp horizontal length [m]";
  parameter Real L_plateau = 2.0 "Plateau length [m]";
  parameter Real h_plateau = L_ramp*Modelica.Math.tan(theta_r) "Plateau height [m]";
  parameter Real x_edge = L_ramp + L_plateau "Descending edge x [m]";
  parameter Real x_stop = x_edge - 0.20 "Stop target with margin [m]";
  parameter Real ridge_h = 0.05 "Ridge height [m]";
  parameter Real ridge_w = 0.40 "Ridge width [m]";
  parameter Real x_ridge1 = 2.40 "First ridge center [m]";
  parameter Real x_ridge2 = 3.40 "Second ridge center [m]";
  parameter Real F_payload = 180.0 "Payload force magnitude [N]";
  parameter Real t_pl_start = 16.0/3.0 "Payload start [s]";
  parameter Real t_pl_end = 2.0*16.0/3.0 "Payload end [s]";
  parameter Real Ts = 1.0/250.0 "Control period [s]";
  parameter Real v_cruise = 0.50 "Cruise speed [m/s]";
  parameter Real a_brake = 1.0 "Brake deceleration [m/s2]";
  parameter Real d_brake = 0.50 "Braking zone distance [m]";
  parameter Real Kp = 30.0 "Speed error gain [N.m/(m/s)]";
  parameter Real C_roll = 2.0 "Rolling resistance coefficient [N/(m/s)]";
  parameter Real Cs = 50.0 "Tire slip relaxation stiffness";
  parameter Real s_thresh = 0.30 "Traction control slip threshold";

  // ---------- Continuous plant states ----------
  Real x_pos(start=0.0, fixed=true) "Forward position along terrain [m]";
  Real vx(start=0.0, fixed=true) "Forward velocity [m/s]";
  Real wL(start=0.0, fixed=true) "Left wheel angular velocity [rad/s]";
  Real wR(start=0.0, fixed=true) "Right wheel angular velocity [rad/s]";

  // ---------- Terrain and attitude ----------
  Real z_terrain "Terrain height under chassis [m]";
  Real dz_dx "Terrain slope derivative [1]";
  Real pitch "Chassis pitch [rad]";
  Real roll "Chassis roll [rad]";

  // ---------- Forces and loads ----------
  Real F_pl "Active payload force [N]";
  Real W_eff "Effective weight [N]";
  Real N_total "Total normal force [N]";
  Real N_pw "Normal force per driven wheel [N]";
  Real sL "Left wheel slip ratio";
  Real sR "Right wheel slip ratio";
  Real F_L "Left traction force [N]";
  Real F_R "Right traction force [N]";
  Real F_brake "Braking force [N]";

  // ---------- Actuation ----------
  Real tauL "Left motor torque [N.m]";
  Real tauR "Right motor torque [N.m]";
  Real kL "Left traction-control scale";
  Real kR "Right traction-control scale";

  // ---------- Sensors ----------
  Real v_enc "Encoder-measured speed [m/s]";
  Real pitch_imu "IMU pitch [rad]";
  Real roll_imu "IMU roll [rad]";
  Real edge_dist "Depth sensor distance to descending edge [m]";

  // ---------- Discrete controller (250 Hz ZOH) ----------
  discrete Real v_ref_d(start=0.0) "Held speed reference [m/s]";
  discrete Real tau_cmd_d(start=0.0) "Held total torque command [N.m]";
  discrete Real v_enc_s(start=0.0) "Sampled encoder speed [m/s]";
  discrete Real x_s(start=0.0) "Sampled position [m]";
  discrete Real pitch_s(start=0.0) "Sampled pitch [rad]";
  discrete Real sL_s(start=0.0) "Sampled left slip";
  discrete Real sR_s(start=0.0) "Sampled right slip";
  discrete Real track_err_d(start=0.0) "Sampled tracking error [m/s]";

  // ---------- Acceptance (fail-closed) ----------
  Boolean ok_slip;
  Boolean ok_pitch;
  Boolean ok_roll;
  Boolean ok_margin;
  Boolean ok_track;
  Boolean ok_finite;
  Boolean ok_all;

  // ---------- Terrain profile function ----------
  function terrainProfile
    "Returns height and derivative for ramp + plateau + two ridges"
    input Real x;
    input Real theta_r_in;
    input Real L_ramp_in;
    input Real L_plateau_in;
    input Real h_plat_in;
    input Real x_r1;
    input Real x_r2;
    input Real r_h;
    input Real rw_in;
    output Real z;
    output Real dz_dx_out;
  protected
    Real b1, b2, db1, db2, base_z, base_dz;
  algorithm
    if x < L_ramp_in then
      base_z := x*Modelica.Math.tan(theta_r_in);
      base_dz := Modelica.Math.tan(theta_r_in);
    elseif x < L_ramp_in + L_plateau_in then
      base_z := h_plat_in;
      base_dz := 0.0;
    else
      base_z := h_plat_in;
      base_dz := 0.0;
    end if;

    b1 := 0.0;
    db1 := 0.0;
    b2 := 0.0;
    db2 := 0.0;

    if abs(x - x_r1) < rw_in/2.0 then
      b1 := 0.5*r_h*(1.0 + Modelica.Math.cos(2.0*Modelica.Constants.pi*(x - x_r1)/rw_in));
      db1 := -0.5*r_h*(2.0*Modelica.Constants.pi/rw_in)*Modelica.Math.sin(2.0*Modelica.Constants.pi*(x - x_r1)/rw_in);
    end if;

    if abs(x - x_r2) < rw_in/2.0 then
      b2 := 0.5*r_h*(1.0 + Modelica.Math.cos(2.0*Modelica.Constants.pi*(x - x_r2)/rw_in));
      db2 := -0.5*r_h*(2.0*Modelica.Constants.pi/rw_in)*Modelica.Math.sin(2.0*Modelica.Constants.pi*(x - x_r2)/rw_in);
    end if;

    z := base_z + b1 + b2;
    dz_dx_out := base_dz + db1 + db2;
  end terrainProfile;

equation
  // Terrain and attitude
  (z_terrain, dz_dx) = terrainProfile(x_pos, theta_r, L_ramp, L_plateau, h_plateau,
                                       x_ridge1, x_ridge2, ridge_h, ridge_w);
  pitch = Modelica.Math.atan(dz_dx);
  roll = 0.0 "Planar scenario; no lateral slope";

  // Payload disturbance (middle third of 16 s run)
  F_pl = if (time >= t_pl_start) and (time <= t_pl_end) then F_payload else 0.0;
  W_eff = m_chassis*g + F_pl;
  N_total = W_eff*Modelica.Math.cos(pitch);
  N_pw = f_driven*N_total/2.0;

  // Slip ratios with protected denominator
  sL = (r_w*wL - vx)/max(max(abs(r_w*wL), abs(vx)), 0.01);
  sR = (r_w*wR - vx)/max(max(abs(r_w*wR), abs(vx)), 0.01);

  // Tire force: friction-limited via tanh relaxation
  F_L = mu*N_pw*Modelica.Math.tanh(sL*Cs);
  F_R = mu*N_pw*Modelica.Math.tanh(sR*Cs);

  // Longitudinal dynamics
  der(x_pos) = vx;
  m_chassis*der(vx) = F_L + F_R - W_eff*Modelica.Math.sin(pitch) - C_roll*vx - F_brake;

  // Wheel dynamics
  Iw*der(wL) = tauL - F_L*r_w;
  Iw*der(wR) = tauR - F_R*r_w;

  // Slip-aware traction control (sampled slip avoids chatter)
  kL = if abs(sL_s) > s_thresh then s_thresh/max(abs(sL_s), 1.0e-6) else 1.0;
  kR = if abs(sR_s) > s_thresh then s_thresh/max(abs(sR_s), 1.0e-6) else 1.0;
  tauL = max(-tau_max, min(tau_max, tau_cmd_d*0.5*kL));
  tauR = max(-tau_max, min(tau_max, tau_cmd_d*0.5*kR));

  // Controlled bounded braking (linear ramp within braking zone)
  F_brake = if (x_pos > x_stop - d_brake) and (vx > 0.001)
            then m_chassis*a_brake*min(1.0, (x_pos - (x_stop - d_brake))/d_brake)
            else 0.0;

  // Sensors
  v_enc = 0.5*r_w*(wL + wR);
  pitch_imu = pitch;
  roll_imu = roll;
  edge_dist = x_edge - x_pos;

  // ---------- Discrete controller at 250 Hz ----------
  when sample(0, Ts) then
    v_enc_s = 0.5*r_w*(wL + wR);
    x_s = x_pos;
    pitch_s = pitch;
    sL_s = sL;
    sR_s = sR;

    // Speed reference: ramp-up, cruise, then position-based deceleration
    if x_s >= x_stop - 1.0e-6 then
      v_ref_d = 0.0;
    elseif x_s > x_stop - d_brake then
      v_ref_d = (if time < 1.0 then v_cruise*time else v_cruise) * (x_stop - x_s)/d_brake;
    else
      v_ref_d = if time < 1.0 then v_cruise*time else v_cruise;
    end if;

    // Torque command: speed feedback + gravity feedforward, bounded
    tau_cmd_d = max(-2.0*tau_max, min(2.0*tau_max,
                   Kp*(v_ref_d - v_enc_s) + W_eff*Modelica.Math.sin(pitch_s)*r_w));
    track_err_d = abs(v_enc_s - v_ref_d);
  end when;

  // ---------- Acceptance predicates ----------
  ok_slip   = (abs(sL) < 0.35) and (abs(sR) < 0.35);
  ok_pitch  = abs(pitch) < 0.40;
  ok_roll   = abs(roll) < 0.40;
  ok_margin = x_pos < x_edge - 0.05;
  ok_track  = (time < 10.4) or (abs(vx - v_ref_d) < 0.162);
  ok_finite = (abs(x_pos) < 1.0e6) and (abs(vx) < 1.0e6) and (abs(wL) < 1.0e6)
              and (abs(wR) < 1.0e6) and (abs(sL) < 1.0e6) and (abs(sR) < 1.0e6)
              and (abs(pitch) < 1.0e6) and (abs(v_ref_d) < 1.0e6);
  ok_all = ok_slip and ok_pitch and ok_roll and ok_margin and ok_track and ok_finite;

  // Fail-closed assertion
  assert(ok_all, "FAIL-CLOSED: DiffRoverClimbE acceptance violated");

  annotation (
    experiment(StopTime=16.0, Tolerance=1e-4, Interval=1.0/250.0),
    Documentation(info="Differential-drive rover ascending a 12 deg ramp, traversing a 2 m plateau with two 0.05 m ridges, and stopping before the descending edge. Slip-aware traction control, bounded braking, IMU/encoder/depth sensors, 250 Hz control, 16 s run, fail-closed acceptance."));
end DiffRoverClimbE;