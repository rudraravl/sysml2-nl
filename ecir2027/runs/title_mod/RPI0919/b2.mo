model GliderSurveyA
  // Hull and environment
  parameter Real m_hull = 60.0 "Hull mass [kg]";
  parameter Real m_pitch = 6.0 "Pitch mass [kg]";
  parameter Real L_hull = 1.8 "Hull length [m]";
  parameter Real A_wing = 0.42 "Wing area [m2]";
  parameter Real A_front = 0.10 "Frontal reference area [m2]";
  parameter Real rho_w = 1025.0 "Seawater density [kg/m3]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real Cd_f = 0.30 "Forward drag coefficient";
  parameter Real Cd_l = 0.80 "Lateral drag coefficient";
  parameter Real Cw = 200.0 "Heave damping [N.s/m]";
  parameter Real Cr = 10.0 "Yaw damping [N.m.s/rad]";
  parameter Real Iz = 5.0 "Yaw inertia [kg.m2]";
  parameter Real Cfwd = 300.0 "Forward speed gain [N/(m/s)]";
  parameter Real K_moment = 58.86 "Pitch-mass to yaw moment gain [N.m/m]";

  // Mission
  parameter Real u_des = 1.0 "Commanded speed [m/s]";
  parameter Real cur_y = 0.18 "Lateral current [m/s]";
  parameter Real z_ref = 60.0 "Target depth [m]";
  parameter Real H_seabed = 80.0 "Seabed depth [m]";
  parameter Real leg_len = 30.0 "Lawnmower leg length [m]";
  parameter Real leg_space = 5.0 "Leg spacing [m]";
  parameter Real L_look = 2.0 "LOS look-ahead [m]";
  parameter Real T_end = 8.0 "Scenario duration [s]";
  parameter Real f_ctrl = 80.0 "Control/sensor rate [Hz]";
  parameter Real Ts = 1.0 / f_ctrl "Sample period [s]";

  // Actuator limits
  parameter Real Vb_max = 0.001 "Buoyancy command magnitude limit [m3]";
  parameter Real Vb_rate = 5e-4 "Buoyancy rate limit [m3/s]";
  parameter Real rmp_max = 0.10 "Pitch-mass travel limit [m]";
  parameter Real rmp_rate = 0.05 "Pitch-mass rate limit [m/s]";

  // Control gains
  parameter Real K_vb = 2e-4 "Depth to buoyancy gain [m3/m]";
  parameter Real K_vb_rate = 1e-4 "Heave rate to buoyancy gain [m3/(m/s)]";
  parameter Real K_psi = 0.8 "Heading to pitch-mass gain [m/rad]";
  parameter Real K_int = 2.0 "Cross-track integral gain [rad/(m.s)]";
  parameter Real psi_int_max = 1.0 "Integral clamp [rad]";

  // Disturbance
  parameter Real F_dist = 50.0 "Current load disturbance [N]";
  parameter Real t_dist_on = T_end / 3.0;
  parameter Real t_dist_off = 2.0 * T_end / 3.0;

  // Continuous plant states
  Real x(start=0.0, fixed=true) "East position [m]";
  Real y(start=0.0, fixed=true) "North position [m]";
  Real z(start=60.0, fixed=true) "Depth [m]";
  Real psi(start=0.0, fixed=true) "Heading [rad]";
  Real u(start=1.0, fixed=true) "Surge speed [m/s]";
  Real v(start=0.0, fixed=true) "Sway speed [m/s]";
  Real w(start=0.0, fixed=true) "Heave speed [m/s]";
  Real r(start=0.0, fixed=true) "Yaw rate [rad/s]";
  Real Vb(start=0.0, fixed=true) "Buoyancy volume change [m3]";
  Real rmp(start=0.0, fixed=true) "Pitch-mass position [m]";

  // Discrete controller/estimator states
  Real Vb_cmd_f(start=0.0, fixed=true) "Filtered buoyancy command [m3]";
  Real rmp_cmd_f(start=0.0, fixed=true) "Filtered pitch-mass command [m]";
  Real psi_int(start=0.0, fixed=true) "Cross-track integral [rad]";
  Real leg(start=1.0, fixed=true) "Current lawnmower leg";

  // Estimator
  Real x_hat(start=0.0, fixed=true);
  Real y_hat(start=0.0, fixed=true);
  Real z_hat(start=60.0, fixed=true);
  Real psi_hat(start=0.0, fixed=true);
  Real vx_hat(start=1.0, fixed=true);
  Real vy_hat(start=0.0, fixed=true);
  Real P_x(start=1.0, fixed=true);
  Real P_y(start=1.0, fixed=true);
  Real P_psi(start=1e-4, fixed=true);
  Real P_vx(start=0.25, fixed=true);
  Real P_vy(start=0.25, fixed=true);
  Real P_z(start=1e-2, fixed=true);

  // Sensor traces
  Real psi_compass(start=0.0, fixed=true);
  Real r_imu(start=0.0, fixed=true);
  Real z_pressure(start=60.0, fixed=true);
  Real u_dvl(start=1.0, fixed=true);
  Real v_dvl(start=0.0, fixed=true);
  Real range_acoustic(start=20.0, fixed=true);

  // Forces/torques
  Real F_thrust;
  Real F_drag_x;
  Real F_drag_y;
  Real F_dist_y;
  Real F_buoy;
  Real M_yaw;

  // Path/control observables (assigned in algorithm)
  Real path_angle(start=0.0, fixed=true);
  Real e_cross(start=0.0, fixed=true);
  Real e_along(start=0.0, fixed=true);
  Real route_progress(start=0.0, fixed=true);
  Real route_completion(start=0.0, fixed=true);
  Real psi_cmd(start=0.0, fixed=true);
  Real e_psi(start=0.0, fixed=true);
  Real track_error(start=0.0, fixed=true);

  // Continuous metrics
  Real depth_error;
  Real seabed_clearance;
  Real speed_error;
  Boolean dist_active;
  Boolean Vb_saturated;
  Boolean rmp_saturated;
  Boolean no_nan_inf;
  Boolean track_ok;

equation
  // Disturbance window
  dist_active = (time >= t_dist_on) and (time < t_dist_off);
  F_dist_y = if dist_active then F_dist else 0.0;

  // Forces
  F_buoy = rho_w * g * Vb;
  F_thrust = Cfwd * (u_des - u);
  F_drag_x = 0.5 * rho_w * A_front * Cd_f * u * abs(u);
  F_drag_y = 0.5 * rho_w * A_wing * Cd_l * v * abs(v);
  M_yaw = K_moment * rmp;

  // Plant dynamics
  der(u) = (F_thrust - F_drag_x) / m_hull;
  der(v) = (F_dist_y - F_drag_y) / m_hull;
  der(w) = (-F_buoy - Cw * w) / m_hull;
  der(z) = w;
  der(r) = (M_yaw - Cr * r) / Iz;
  der(psi) = r;
  der(x) = u * cos(psi) - v * sin(psi);
  der(y) = u * sin(psi) + v * cos(psi) + cur_y;

  // Actuator first-order dynamics
  der(Vb) = (Vb_cmd_f - Vb) / 0.2;
  der(rmp) = (rmp_cmd_f - rmp) / 0.2;

  // Continuous metrics
  depth_error = z - z_ref;
  seabed_clearance = H_seabed - z;
  speed_error = u_des - u;

  // Saturation flags
  Vb_saturated = abs(Vb) >= 0.999 * Vb_max;
  rmp_saturated = abs(rmp) >= 0.999 * rmp_max;

  // Health flag
  no_nan_inf = abs(x) < 1e9 and abs(y) < 1e9 and abs(z) < 1e9 and
               abs(u) < 1e9 and abs(v) < 1e9 and abs(w) < 1e9 and
               abs(psi) < 1e9 and abs(r) < 1e9 and abs(Vb) < 1e9 and
               abs(rmp) < 1e9 and abs(x_hat) < 1e9 and abs(y_hat) < 1e9 and
               abs(psi_hat) < 1e9 and abs(P_x) < 1e9 and abs(P_y) < 1e9 and
               abs(P_z) < 1e9 and abs(track_error) < 1e9 and abs(depth_error) < 1e9;
  track_ok = (time >= 5.2) and (track_error <= 1.08);

algorithm
  when sample(0, Ts) then
    // Path geometry based on current leg
    path_angle := if leg < 1.5 then 0.0 elseif leg < 2.5 then Modelica.Constants.pi else 0.0;
    e_cross := if leg < 1.5 then y elseif leg < 2.5 then y - leg_space else y - 2.0 * leg_space;
    e_along := if leg < 1.5 then x elseif leg < 2.5 then leg_len - x else x - leg_len;
    route_progress := (leg - 1.0) * leg_len + max(e_along, 0.0);
    route_completion := max(0.0, min(1.0, route_progress / (2.0 * leg_len)));
    track_error := abs(e_cross);

    // Fused sensor observations
    psi_compass := psi + 0.005 * sin(7.0 * time);
    r_imu := r + 0.001 * sin(9.0 * time);
    z_pressure := z + 0.02 * sin(3.0 * time);
    u_dvl := u + 0.02 * sin(5.0 * time);
    v_dvl := v + 0.02 * cos(5.0 * time);
    range_acoustic := (H_seabed - z) + 0.05 * sin(2.0 * time);

    // Estimator predict + measurement update (diagonal covariance)
    x_hat := x_hat + Ts * vx_hat;
    y_hat := y_hat + Ts * vy_hat;
    z_hat := 0.7 * z_hat + 0.3 * z_pressure;
    psi_hat := psi_compass;
    vx_hat := u_dvl * cos(psi_hat) - v_dvl * sin(psi_hat);
    vy_hat := u_dvl * sin(psi_hat) + v_dvl * cos(psi_hat);

    P_x := max(P_x + 0.02 * Ts - 0.5 * P_x * Ts, 1e-6);
    P_y := max(P_y + 0.02 * Ts - 0.5 * P_y * Ts, 1e-6);
    P_psi := 1e-4;
    P_vx := max(P_vx * 0.96 + 0.01 * Ts, 1e-6);
    P_vy := max(P_vy * 0.96 + 0.01 * Ts, 1e-6);
    P_z := max(P_z * 0.85 + 1e-4, 1e-6);

    // Lawnmower leg advancement
    if leg < 1.5 and x_hat >= leg_len then
      leg := 2.0;
    elseif leg < 2.5 and x_hat <= 0.0 then
      leg := 3.0;
    end if;

    // Cross-track integral with anti-windup clamp
    psi_int := psi_int + Ts * K_int * e_cross;
    if psi_int > psi_int_max then
      psi_int := psi_int_max;
    elseif psi_int < -psi_int_max then
      psi_int := -psi_int_max;
    end if;

    // Path-following heading command with current compensation
    psi_cmd := path_angle + Modelica.Math.atan2(-e_cross, L_look) + psi_int;
    e_psi := Modelica.Math.atan2(sin(psi_cmd - psi_hat), cos(psi_cmd - psi_hat));

    // Heading control to pitch-mass command (travel limited)
    rmp_cmd_f := -K_psi * e_psi;
    if rmp_cmd_f > rmp_max then
      rmp_cmd_f := rmp_max;
    elseif rmp_cmd_f < -rmp_max then
      rmp_cmd_f := -rmp_max;
    end if;
    // Pitch-mass rate (energy/travel) limit
    if rmp_cmd_f > rmp + rmp_rate * Ts then
      rmp_cmd_f := rmp + rmp_rate * Ts;
    elseif rmp_cmd_f < rmp - rmp_rate * Ts then
      rmp_cmd_f := rmp - rmp_rate * Ts;
    end if;

    // Depth control to buoyancy command (magnitude + rate limited)
    Vb_cmd_f := K_vb * (z_pressure - z_ref) + K_vb_rate * (0.0 - w);
    if Vb_cmd_f > Vb_max then
      Vb_cmd_f := Vb_max;
    elseif Vb_cmd_f < -Vb_max then
      Vb_cmd_f := -Vb_max;
    end if;
    if Vb_cmd_f > Vb + Vb_rate * Ts then
      Vb_cmd_f := Vb + Vb_rate * Ts;
    elseif Vb_cmd_f < Vb - Vb_rate * Ts then
      Vb_cmd_f := Vb - Vb_rate * Ts;
    end if;
  end when;

  annotation (
    experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="Free-base underwater glider GliderSurveyA. 60 kg, 1.8 m capsule hull, 0.42 m2 wing, 6 kg translating pitch mass, variable-buoyancy unit. Lawnmower path (two 30 m legs, 60 m total) at 1.0 m/s, constant 60 m depth, 0.18 m/s lateral current, 50 N lateral load during middle third. 80 Hz synchronized control/sensor/estimator traces. Buoyancy command magnitude limited to 0.001 m3. Pitch-mass travel and rate limits assumed (not specified in request)."));
end GliderSurveyA;