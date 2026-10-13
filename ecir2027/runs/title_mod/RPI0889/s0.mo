model CatamaranDiveA
  "Free-base catamaran marine robot: descend to 8 m, hold, return to 3 m with cascaded depth/attitude control, bounded allocation, current disturbance."

  /* ------------------------------------------------------------------
     Stated facts (from requirement):
       - Two 46 kg capsule hulls, 1.1 m separation
       - 18 kg rigid deck, port and starboard propellers
       - Differential propeller forces control surge and heading
       - Per-propeller command limit 310 N
       - Descend to 8 m, hold depth and zero heading, return to 3 m
       - Pressure depth, IMU, Doppler velocity feedback
       - Gravity, buoyancy, seawater density 1025 kg/m3, quadratic drag
       - Cascaded depth and attitude control with bounded allocation
       - 40 N current force during middle third of 8 s scenario
       - Run at 80 Hz, retain synchronized state/command/sensor traces
     Inferred design choices (not stated, labeled here):
       - Neutral buoyancy (displaced volume set from total mass), heave
         thruster added for depth actuation since only surge/heading
         propellers are specified.
       - Quadratic drag coefficients, roll/pitch restoring stiffness,
         inertia Iyy, controller gains, current vertical offset, and
         propeller pitch/roll couplings are design choices.
  ------------------------------------------------------------------ */

  // ---- Physical constants ----
  parameter Modelica.Units.SI.Acceleration g = 9.81 "Gravitational acceleration";
  parameter Modelica.Units.SI.Density rho_w = 1025 "Seawater density";

  // ---- Mass and geometry (stated) ----
  parameter Modelica.Units.SI.Mass m_hull = 46 "Mass of each capsule hull";
  parameter Modelica.Units.SI.Mass m_deck = 18 "Mass of rigid deck";
  parameter Modelica.Units.SI.Mass m = 2*m_hull + m_deck "Total rigid mass";
  parameter Modelica.Units.SI.Length d_hull = 1.1 "Hull separation";
  parameter Modelica.Units.SI.Length d_half = d_hull/2 "Half hull separation";
  parameter Modelica.Units.SI.Volume V_disp = m/rho_w
    "Displaced volume (inferred neutral buoyancy)";
  parameter Modelica.Units.SI.Force F_buoy = rho_w*V_disp*g "Buoyancy force";
  parameter Modelica.Units.SI.Force F_max = 310 "Per-propeller command limit";
  parameter Modelica.Units.SI.Force F_current = 40 "Current disturbance magnitude";

  // ---- Inertia (Izz/Ixx from hull point masses; Iyy inferred) ----
  parameter Modelica.Units.SI.Inertia Izz = 2*m_hull*d_half^2 "Yaw inertia";
  parameter Modelica.Units.SI.Inertia Ixx = 2*m_hull*d_half^2 "Roll inertia";
  parameter Modelica.Units.SI.Inertia Iyy = 18 "Pitch inertia (inferred)";

  // ---- Quadratic drag (inferred coefficients) ----
  parameter Real Cdx = 30 "Surge drag (N/(m/s)^2)";
  parameter Real Cdz = 30 "Heave drag (N/(m/s)^2)";
  parameter Real Cdr = 8 "Yaw drag (N.m/(rad/s)^2)";
  parameter Real Cdp = 8 "Roll drag (N.m/(rad/s)^2)";
  parameter Real Cdq = 8 "Pitch drag (N.m/(rad/s)^2)";

  // ---- Restoring and couplings (inferred) ----
  parameter Real Kroll = 250 "Roll restoring stiffness (N.m/rad)";
  parameter Real Kpitch = 250 "Pitch restoring stiffness (N.m/rad)";
  parameter Real h_current = 0.2 "Vertical offset of current force (m, inferred)";
  parameter Real k_pitch_couple = 0.05 "Pitch coupling from surge thrust (m, inferred)";
  parameter Real k_roll_couple = 0.03 "Roll coupling from diff thrust (m, inferred)";

  // ---- Controller gains (cascaded, inferred) ----
  parameter Real Kz_outer = 0.5 "Depth-to-vertical-velocity gain";
  parameter Real Kz_vmax = 2.0 "Max vertical velocity command (m/s)";
  parameter Real Kvz_inner = 2.0 "Vertical velocity loop gain (1/s)";
  parameter Real Kx_outer = 0.3 "Surge-position-to-velocity gain";
  parameter Real Kx_vmax = 1.5 "Max surge velocity command (m/s)";
  parameter Real Kvx_inner = 1.5 "Surge velocity loop gain (1/s)";
  parameter Real Kyaw_outer = 1.5 "Heading-to-yaw-rate gain";
  parameter Real Kr_max = 1.0 "Max yaw-rate command (rad/s)";
  parameter Real Kr_inner = 3.0 "Yaw-rate loop gain (1/s)";

  // ---- Timing ----
  parameter Real Ts = 0.0125 "Control/sensor sample period (1/80 s)";
  parameter Real T_end = 8.0 "Scenario duration (s)";
  parameter Real t1 = T_end/3 "Current disturbance start (s)";
  parameter Real t2 = 2*T_end/3 "Current disturbance end (s)";

  // ---- Continuous states ----
  Modelica.Units.SI.Length x "Surge position (m)";
  Modelica.Units.SI.Length z "Depth (m, positive downward)";
  Modelica.Units.SI.Angle yaw "Heading (rad)";
  Modelica.Units.SI.Angle roll "Roll angle (rad)";
  Modelica.Units.SI.Angle pitch "Pitch angle (rad)";
  Modelica.Units.SI.Velocity vx "Surge velocity (m/s)";
  Modelica.Units.SI.Velocity vz "Heave velocity (m/s, positive downward)";
  Modelica.Units.SI.AngularVelocity r "Yaw rate (rad/s)";
  Modelica.Units.SI.AngularVelocity p_ang "Roll rate (rad/s)";
  Modelica.Units.SI.AngularVelocity q "Pitch rate (rad/s)";

  // ---- Continuous auxiliary ----
  Modelica.Units.SI.Force F_current_on "Active current force (N)";
  Modelica.Units.SI.Torque M_pitch_dist "Pitch disturbance/curve moment (N.m)";
  Modelica.Units.SI.Torque M_roll_dist "Roll disturbance/curve moment (N.m)";

  // ---- Discrete controller & sensor variables (updated at 80 Hz) ----
  discrete Modelica.Units.SI.Length z_ref(start=0) "Depth reference";
  discrete Modelica.Units.SI.Velocity vz_ref_cmd(start=0) "Vertical velocity command";
  discrete Modelica.Units.SI.Velocity vx_ref_cmd(start=0) "Surge velocity command";
  discrete Modelica.Units.SI.AngularVelocity r_ref_cmd(start=0) "Yaw-rate command";
  discrete Modelica.Units.SI.Force F_heave_cmd(start=0) "Heave thruster raw command";
  discrete Modelica.Units.SI.Force F_surge_cmd(start=0) "Surge raw force command";
  discrete Modelica.Units.SI.Torque M_yaw_cmd(start=0) "Raw yaw moment command";
  discrete Modelica.Units.SI.Force Fp_raw(start=0) "Raw port propeller force";
  discrete Modelica.Units.SI.Force Fs_raw(start=0) "Raw starboard propeller force";
  discrete Modelica.Units.SI.Force Fp(start=0) "Bounded port propeller force";
  discrete Modelica.Units.SI.Force Fs(start=0) "Bounded starboard propeller force";
  discrete Modelica.Units.SI.Force F_heave(start=0) "Bounded heave thruster force";
  discrete Modelica.Units.SI.Force F_surge_act(start=0) "Actual surge force (allocated)";
  discrete Modelica.Units.SI.Torque M_yaw_act(start=0) "Actual yaw moment (allocated)";
  discrete Modelica.Units.SI.Length x_est(start=0) "Surge position from Doppler integration";

  // ---- Sensors (80 Hz sampled) ----
  discrete Real z_meas(start=0) "Pressure depth sensor (m)";
  discrete Real vx_meas(start=0) "Doppler surge velocity (m/s)";
  discrete Real vz_meas(start=0) "Doppler heave velocity (m/s)";
  discrete Real yaw_meas(start=0) "IMU heading (rad)";
  discrete Real roll_meas(start=0) "IMU roll (rad)";
  discrete Real pitch_meas(start=0) "IMU pitch (rad)";
  discrete Real p_meas(start=0) "IMU roll rate (rad/s)";
  discrete Real q_meas(start=0) "IMU pitch rate (rad/s)";
  discrete Real r_meas(start=0) "IMU yaw rate (rad/s)";

  // ---- Tracking error (for verification/logging) ----
  Real depth_track_err = z_ref - z "Primary tracking error (m)";

initial equation
  x = 0.0;
  z = 0.0;
  yaw = 0.0;
  roll = 0.0;
  pitch = 0.0;
  vx = 0.0;
  vz = 0.0;
  r = 0.0;
  p_ang = 0.0;
  q = 0.0;

equation
  // ===== Continuous plant kinematics =====
  der(x) = vx;
  der(z) = vz;
  der(yaw) = r;
  der(roll) = p_ang;
  der(pitch) = q;

  // Surge: thrust + current - quadratic drag; buoyancy/weight cancel horizontally
  der(vx) = (F_surge_act + F_current_on - Cdx*vx*abs(vx)) / m;

  // Heave: neutral buoyancy (F_buoy = m*g), heave thruster - quadratic drag
  der(vz) = (F_heave - Cdz*vz*abs(vz)) / m;

  // Yaw: allocated yaw moment - quadratic drag
  der(r) = (M_yaw_act - Cdr*r*abs(r)) / Izz;

  // Roll: coupling from differential thrust - restoring - quadratic drag
  der(p_ang) = (M_roll_dist - Kroll*roll - Cdp*p_ang*abs(p_ang)) / Ixx;

  // Pitch: current offset + surge coupling - restoring - quadratic drag
  der(q) = (M_pitch_dist - Kpitch*pitch - Cdq*q*abs(q)) / Iyy;

  // ===== Current disturbance (middle third of 8 s scenario) =====
  F_current_on = if (time >= t1) and (time <= t2) then F_current else 0.0;

  // ===== Disturbance/curve moments (continuous, use held allocated forces) =====
  M_pitch_dist = F_current_on*h_current + k_pitch_couple*F_surge_act;
  M_roll_dist = k_roll_couple*(Fs - Fp);

  // ===== Discrete controller and sensor sampling at 80 Hz =====
  when sample(0, Ts) then

    // --- Sensors (ideal plus small bounded deterministic noise) ---
    z_meas     = z + 0.01*Modelica.Math.sin(13.0*time);
    vx_meas    = vx + 0.02*Modelica.Math.sin(7.0*time);
    vz_meas    = vz + 0.02*Modelica.Math.cos(9.0*time);
    yaw_meas   = yaw + 0.005*Modelica.Math.sin(5.0*time);
    roll_meas  = roll + 0.005*Modelica.Math.cos(11.0*time);
    pitch_meas = pitch + 0.005*Modelica.Math.sin(17.0*time);
    p_meas     = p_ang + 0.01*Modelica.Math.sin(19.0*time);
    q_meas     = q + 0.01*Modelica.Math.cos(23.0*time);
    r_meas     = r + 0.01*Modelica.Math.sin(29.0*time);

    // --- Depth reference schedule: descend 0->8 m, hold, return to 3 m ---
    if time < 5.0 then
      z_ref = 1.6*time;                       // descend 0->8 m over 5 s
    elseif time < 6.0 then
      z_ref = 8.0;                            // hold 8 m
    else
      z_ref = 8.0 - 2.5*(time - 6.0);         // return 8->3 m over 2 s
    end if;

    // --- Cascaded depth control: depth -> vertical velocity -> heave force ---
    vz_ref_cmd = max(-Kz_vmax, min(Kz_vmax, Kz_outer*(z_ref - z_meas)));
    F_heave_cmd = m*(Kvz_inner*(vz_ref_cmd - vz_meas)) + Cdz*vz_meas*abs(vz_meas);
    F_heave = max(-F_max, min(F_max, F_heave_cmd));

    // --- Surge position estimate from Doppler velocity integration ---
    x_est = pre(x_est) + Ts*vx_meas;

    // --- Cascaded surge control: position -> velocity -> surge force ---
    vx_ref_cmd = max(-Kx_vmax, min(Kx_vmax, Kx_outer*(0.0 - x_est)));
    F_surge_cmd = m*(Kvx_inner*(vx_ref_cmd - vx_meas)) + Cdx*vx_meas*abs(vx_meas);

    // --- Cascaded heading control: heading -> yaw rate -> yaw moment ---
    r_ref_cmd = max(-Kr_max, min(Kr_max, Kyaw_outer*(0.0 - yaw_meas)));
    M_yaw_cmd = Izz*(Kr_inner*(r_ref_cmd - r_meas)) + Cdr*r_meas*abs(r_meas);

    // --- Bounded allocation: F_surge = Fp + Fs, M_yaw = (Fs - Fp)*d_half ---
    Fp_raw = (F_surge_cmd - M_yaw_cmd/d_half)/2.0;
    Fs_raw = (F_surge_cmd + M_yaw_cmd/d_half)/2.0;
    Fp = max(-F_max, min(F_max, Fp_raw));
    Fs = max(-F_max, min(F_max, Fs_raw));

    // --- Actual allocated forces fed back to plant ---
    F_surge_act = Fp + Fs;
    M_yaw_act = (Fs - Fp)*d_half;

  end when;

  annotation (
    experiment(StartTime=0, StopTime=8, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="CatamaranDiveA: 80 Hz cascaded depth/attitude control of a free-base catamaran. Heave thruster for depth is an inferred actuator (only surge/heading propellers were specified). Drag, restoring, inertia Iyy, offsets, and gains are inferred design choices."));
end CatamaranDiveA;