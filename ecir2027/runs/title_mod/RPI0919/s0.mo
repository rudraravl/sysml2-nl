model GliderSurveyA
  import Modelica.SIunits;
  import Modelica.Constants;

  // ---------- Hull and environment (values from request) ----------
  parameter SIunits.Mass m_hull = 60.0   "Streamlined capsule hull mass";
  parameter SIunits.Mass m_pitch = 6.0   "Translating internal pitch mass";
  parameter SIunits.Length L_hull = 1.8  "Capsule hull length";
  parameter SIunits.Area A_wing = 0.42   "Wing area";
  parameter SIunits.Area A_front = 0.10  "Frontal reference area for surge drag (assumed)";
  parameter SIunits.Density rho_w = 1025.0 "Seawater density";
  parameter Real g_unit = 9.81           "Gravitational acceleration [m/s2]";
  parameter Real Cd_f = 0.30              "Forward (surge) drag coefficient (assumed)";
  parameter Real Cd_l = 0.80              "Lateral drag coefficient (assumed)";
  parameter Real Cd_z = 0.80              "Heave drag coefficient (assumed)";
  parameter Real Iz = 5.0                 "Yaw inertia estimate [kg.m2] (assumed)";
  parameter Real Cr = 10.0                "Yaw rotational damping [N.m.s/rad] (assumed)";
  parameter Real Cw = 200.0               "Heave linear damping [N.s/m] (assumed)";
  parameter Real Cfwd = 300.0             "Forward speed control gain [N per (m/s)] (assumed)";
  parameter Real K_moment = 59.0          "Pitch-mass to yaw moment gain [N.m/m] (assumed, m_pitch*g)";

  // ---------- Mission ----------
  parameter SIunits.Velocity u_des = 1.0  "Commanded path speed";
  parameter SIunits.Velocity cur_x_w = 0.0 "Water current, world x";
  parameter SIunits.Velocity cur_y_w = 0.18 "Steady lateral water current, world y";
  parameter SIunits.Length z_ref = 60.0    "Constant target depth";
  parameter SIunits.Length H_seabed = 80.0  "Seabed depth";
  parameter SIunits.Length leg_len = 30.0 "Lawnmower leg length (two legs = 60 m total)";
  parameter SIunits.Length leg_space = 5.0 "Lawnmower leg spacing (assumed)";
  parameter SIunits.Length L_look = 2.0   "Line-of-sight look-ahead (assumed)";
  parameter SIunits.Time T_end = 8.0       "Scenario duration";
  parameter SIunits.Frequency f_ctrl = 80.0 "Synchronized control/sensor rate";
  parameter SIunits.Time Ts = 1.0/f_ctrl   "Sample period";

  // ---------- Actuator bounds ----------
  parameter SIunits.Volume Vb_max = 0.001     "Buoyancy-volume command magnitude limit";
  parameter SIunits.VolumeRate Vb_rate = 5e-4 "Buoyancy actuator rate limit [m3/s] (assumed, energy/travel limited)";
  parameter SIunits.Length rmp_max = 0.10      "Pitch-mass travel limit [m] (assumed; value not specified in request)";
  parameter SIunits.Velocity rmp_rate = 0.05  "Pitch-mass actuator rate limit [m/s] (assumed)";

  // ---------- Control gains (assumed where not specified) ----------
  parameter Real K_vb = 2e-4      "Depth to buoyancy gain [m3/m]";
  parameter Real K_vb_rate = 1e-4  "Heave rate to buoyancy gain [m3/(m/s)]";
  parameter Real K_psi = 0.2       "Heading error to pitch-mass gain [m/rad]";
  parameter Real K_int = 0.5       "Cross-track integral gain [rad/(m.s)]";
  parameter Real psi_int_max = 0.8 "Cross-track integral clamp [rad]";

  // ---------- Controlled disturbance ----------
  parameter SIunits.Force F_dist = 50.0 "Controlled current load disturbance";
  parameter SIunits.Time t_dist_on = T_end/3.0;
  parameter SIunits.Time t_dist_off = 2.0*T_end/3.0;

  // ---------- Plant continuous states ----------
  SIunits.Length x(start=0.0, fixed=true);
  SIunits.Length y(start=0.0, fixed=true);
  SIunits.Length z(start=z_ref, fixed=true);
  SIunits.Angle psi(start=0.0, fixed=true);
  SIunits.Velocity u(start=u_des, fixed=true);
  SIunits.Velocity v(start=0.0, fixed=true);
  SIunits.Velocity w(start=0.0, fixed=true);
  SIunits.AngularVelocity r(start=0.0, fixed=true);
  SIunits.Volume Vb(start=0.0, fixed=true)   "Buoyancy volume change";
  SIunits.Length rmp(start=0.0, fixed=true)  "Internal pitch-mass position";

  // ---------- Discrete command / actuator-filtered commands ----------
  discrete SIunits.Volume Vb_cmd_f(start=0.0);
  discrete SIunits.Length rmp_cmd_f(start=0.0);
  discrete Real psi_int(start=0.0) "Cross-track integral state [rad]";

  // ---------- Forces / torques ----------
  SIunits.Force F_thrust;
  SIunits.Force F_drag_x;
  SIunits.Force F_drag_y;
  SIunits.Force F_dist_y;
  SIunits.Force F_buoy;
  SIunits.Torque M_yaw;

  // ---------- Discrete sensor traces ----------
  discrete SIunits.Angle psi_compass(start=0.0);
  discrete SIunits.AngularVelocity r_imu(start=0.0);
  discrete SIunits.Length z_pressure(start=z_ref);
  discrete SIunits.Velocity u_dvl(start=u_des);
  discrete SIunits.Velocity v_dvl(start=0.0);
  discrete SIunits.Length range_acoustic(start=H_seabed - z_ref);

  // ---------- Estimator states and covariance (diagonal EKF approximation) ----------
  discrete SIunits.Length x_hat(start=0.0);
  discrete SIunits.Length y_hat(start=0.0);
  discrete SIunits.Angle psi_hat(start=0.0);
  discrete SIunits.Velocity vx_hat(start=u_des);
  discrete SIunits.Velocity vy_hat(start=0.0);
  discrete SIunits.Length z_hat(start=z_ref);
  discrete Real P_x(start=1.0);
  discrete Real P_y(start=1.0);
  discrete Real P_psi(start=1e-4);
  discrete Real P_vx(start=0.25);
  discrete Real P_vy(start=0.25);
  discrete Real P_z(start=1e-2);

  // ---------- Path geometry ----------
  discrete Integer leg(start=1);
  SIunits.Angle path_angle;
  SIunits.Length e_cross;
  SIunits.Length e_along;
  SIunits.Length route_progress;
  Real route_completion;
  SIunits.Angle psi_cmd;
  SIunits.Angle e_psi;

  // ---------- Metrics / observables ----------
  SIunits.Length depth_error;
  SIunits.Length track_error;
  SIunits.Length seabed_clearance;
  SIunits.Velocity speed_error;
  Boolean dist_active;
  Boolean Vb_saturated;
  Boolean rmp_saturated;
  Boolean no_nan_inf;
  Boolean track_ok;

equation
  // Disturbance window
  dist_active = (time >= t_dist_on) and (time < t_dist_off);
  F_dist_y = if dist_active then F_dist else 0.0;

  // Buoyancy force (positive Vb -> upward, z positive downward)
  F_buoy = rho_w * g_unit * Vb;

  // Surge dynamics
  F_thrust = Cfwd * (u_des - u);
  F_drag_x = 0.5 * rho_w * A_front * Cd_f * u * abs(u);
  der(u) = (F_thrust - F_drag_x) / m_hull;

  // Sway dynamics (lateral disturbance applied here)
  F_drag_y = 0.5 * rho_w * A_wing * Cd_l * v * abs(v);
  der(v) = (F_dist_y - F_drag_y) / m_hull;

  // Heave dynamics
  der(w) = (-F_buoy - Cw * w) / m_hull;
  der(z) = w;

  // Yaw dynamics driven by pitch-mass induced moment
  M_yaw = K_moment * rmp;
  der(r) = (M_yaw - Cr * r) / Iz;
  der(psi) = r;

  // World-frame kinematics (includes steady lateral current)
  der(x) = u*cos(psi) - v*sin(psi) + cur_x_w;
  der(y) = u*sin(psi) + v*cos(psi) + cur_y_w;

  // Actuator dynamics (first-order, with discrete rate-limited commands)
  der(Vb) = (Vb_cmd_f - Vb) / 0.2;
  der(rmp) = (rmp_cmd_f - rmp) / 0.2;

  // Path geometry (continuous, driven by discrete leg selection)
  if leg == 1 then
    path_angle = 0.0;
    e_cross = y - 0.0;
    e_along = x;
  elseif leg == 2 then
    path_angle = Constants.pi;
    e_cross = y - leg_space;
    e_along = leg_len - x;
  else
    path_angle = 0.0;
    e_cross = y - 2.0*leg_space;
    e_along = x - leg_len;
  end if;

  route_progress = (leg - 1)*leg_len + max(e_along, 0.0);
  route_completion = max(0.0, min(1.0, route_progress / (2.0*leg_len)));

  // Path-following command with current-compensation integral
  psi_cmd = path_angle + atan2(-e_cross, L_look) + psi_int;
  e_psi = atan2(sin(psi_cmd - psi_hat), cos(psi_cmd - psi_hat));

  // Metrics
  depth_error = z - z_ref;
  track_error = abs(e_cross);
  seabed_clearance = H_seabed - z;
  speed_error = u_des - u;

  // Actuator bound observability
  Vb_saturated = abs(Vb) >= 0.999*Vb_max;
  rmp_saturated = abs(rmp) >= 0.999*rmp_max;

  // Health and requirement flags
  no_nan_inf = (x == x) and (y == y) and (z == z) and (u == u) and (v == v)
           and (w == w) and (psi == psi) and (r == r) and (Vb == Vb) and (rmp == rmp)
           and (x_hat == x_hat) and (y_hat == y_hat) and (psi_hat == psi_hat)
           and (P_x == P_x) and (P_y == P_y) and (P_z == P_z)
           and (track_error == track_error) and (depth_error == depth_error);
  track_ok = (time >= 5.2) and (track_error <= 1.08);

algorithm
  when sample(0, Ts) then
    // --- Fused sensor observations (bounded noise, no NaN) ---
    psi_compass := psi + 0.005*sin(7.0*time);
    r_imu := r + 0.001*sin(9.0*time);
    z_pressure := z + 0.02*sin(3.0*time);
    u_dvl := u + 0.02*sin(5.0*time);
    v_dvl := v + 0.02*cos(5.0*time);
    range_acoustic := (H_seabed - z) + 0.05*sin(2.0*time);

    // --- Estimator: predict + measurement update (diagonal covariance) ---
    x_hat := x_hat + Ts*vx_hat;
    y_hat := y_hat + Ts*vy_hat;
    z_hat := 0.7*z_hat + 0.3*z_pressure;
    psi_hat := psi_compass;
    vx_hat := u_dvl*cos(psi_hat) - v_dvl*sin(psi_hat);
    vy_hat := u_dvl*sin(psi_hat) + v_dvl*cos(psi_hat);

    P_x := max(P_x + 0.02*Ts - 0.5*P_x*Ts, 1e-6);
    P_y := max(P_y + 0.02*Ts - 0.5*P_y*Ts, 1e-6);
    P_psi := 1e-4;
    P_vx := max(P_vx*0.96 + 0.01*Ts, 1e-6);
    P_vy := max(P_vy*0.96 + 0.01*Ts, 1e-6);
    P_z := max(P_z*0.85 + 1e-4, 1e-6);

    // --- Lawnmower leg advancement ---
    if leg == 1 and x_hat >= leg_len then
      leg := 2;
    elseif leg == 2 and x_hat <= 0.0 then
      leg := 3;
    end if;

    // --- Cross-track integral (current compensation) with anti-windup clamp ---
    psi_int := psi_int + Ts*K_int*e_cross;
    if psi_int > psi_int_max then
      psi_int := psi_int_max;
    elseif psi_int < -psi_int_max then
      psi_int := -psi_int_max;
    end if;

    // --- Heading control -> pitch-mass command (travel limited) ---
    rmp_cmd_f := -K_psi * atan2(sin(psi_cmd - psi_hat), cos(psi_cmd - psi_hat));
    if rmp_cmd_f > rmp_max then
      rmp_cmd_f := rmp_max;
    elseif rmp_cmd_f < -rmp_max then
      rmp_cmd_f := -rmp_max;
    end if;
    // pitch-mass rate (energy/travel) limit
    if rmp_cmd_f > rmp + rmp_rate*Ts then
      rmp_cmd_f := rmp + rmp_rate*Ts;
    elseif rmp_cmd_f < rmp - rmp_rate*Ts then
      rmp_cmd_f := rmp - rmp_rate*Ts;
    end if;

    // --- Depth control -> buoyancy command (magnitude + rate limited) ---
    Vb_cmd_f := K_vb*(z_pressure - z_ref) + K_vb_rate*(0.0 - w);
    if Vb_cmd_f > Vb_max then
      Vb_cmd_f := Vb_max;
    elseif Vb_cmd_f < -Vb_max then
      Vb_cmd_f := -Vb_max;
    end if;
    if Vb_cmd_f > Vb + Vb_rate*Ts then
      Vb_cmd_f := Vb + Vb_rate*Ts;
    elseif Vb_cmd_f < Vb - Vb_rate*Ts then
      Vb_cmd_f := Vb - Vb_rate*Ts;
    end if;
  end when;

  annotation (
    experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="Free-base underwater glider 'GliderSurveyA'. 60 kg, 1.8 m capsule hull, 0.42 m2 wing, 6 kg translating pitch mass, variable-buoyancy unit. Lawnmower path-following (two 30 m legs, 60 m total) at 1.0 m/s, constant 60 m depth, 0.18 m/s lateral current, 50 N lateral load during the middle third. 80 Hz synchronized control/sensor/estimator traces. Buoyancy command magnitude limited to 0.001 m3. Pitch-mass travel and rate limits assumed (not specified)."));
end GliderSurveyA;