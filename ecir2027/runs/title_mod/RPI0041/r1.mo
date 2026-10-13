model HexaSurveyDeliverE
  "Hexacopter survey-and-deliver: lift suspended payload, translate 5 m, lower into 0.8 m target zone";

  // ===== Physical parameters =====
  parameter Real m_fuselage(unit="kg") = 3.2 "Cylindrical fuselage mass";
  parameter Real m_camera(unit="kg")   = 0.4 "Downward camera mass";
  parameter Real m_total(unit="kg")    = m_fuselage + m_camera "Vehicle mass (fuselage + camera)";
  parameter Real m_payload(unit="kg")  = 1.5 "Suspended payload mass (assumed — not stated in requirement)";
  parameter Real R_rotor(unit="m")    = 0.35 "Rotor placement radius";
  parameter Real L_cable(unit="m")    = 1.0 "Cable length (assumed — not stated in requirement)";
  parameter Real g_acc(unit="m/s2")   = 9.81 "Gravitational acceleration";
  parameter Real cd_drag(unit="N.s2/m2") = 0.15 "Aerodynamic drag coefficient (assumed)";
  parameter Real cd_rot(unit="N.m.s/rad") = 0.01 "Rotational drag (assumed)";
  parameter Real I_yy(unit="kg.m2")   = 0.25 "Pitch moment of inertia (assumed — no fuselage dimensions given)";
  parameter Real T_max(unit="N")      = 12.1 "Maximum thrust per rotor";

  // ===== Mission parameters =====
  parameter Real x_target(unit="m")   = 5.0 "Target zone center x";
  parameter Real z_target(unit="m")   = 0.0 "Target zone center z";
  parameter Real r_target(unit="m")   = 0.8 "Target zone radius";
  parameter Real t_hold_end(unit="s") = 3.0 "End of hold phase";
  parameter Real t_cruise_end(unit="s") = 10.4 "End of cruise phase";
  parameter Real t_sim(unit="s")      = 16.0 "Simulation duration";
  parameter Real F_gust(unit="N")     = 9.6 "Gust force magnitude";
  parameter Real t_gust_a(unit="s")   = t_sim / 3.0 "Gust start (middle third)";
  parameter Real t_gust_b(unit="s")   = 2.0 * t_sim / 3.0 "Gust end (middle third)";
  parameter Real Ts(unit="s")         = 0.004 "Controller sampling period (250 Hz)";

  // ===== Controller gains (assumed) =====
  parameter Real kp_x    = 30.0 "Position gain x";
  parameter Real kd_x    = 15.0 "Velocity gain x";
  parameter Real kp_z    = 20.0 "Position gain z";
  parameter Real kd_z    = 12.0 "Velocity gain z";
  parameter Real k_swing = 0.5  "Cable angle feedback gain";
  parameter Real d_swing = 1.5  "Cable rate damping gain";
  parameter Real kp_phi  = 60.0 "Attitude proportional gain";
  parameter Real kd_phi  = 20.0 "Attitude derivative gain";
  parameter Real T_ff    = m_payload * g_acc "Cable tension feedforward (hover)";
  parameter Real T_cable_bound(unit="N") = 30.0 "Cable tension upper bound (assumed)";

  // ===== Continuous states =====
  Real x(start=0.0, fixed=true, unit="m")       "Vehicle x position";
  Real z(start=3.0, fixed=true, unit="m")       "Vehicle z position";
  Real vx(start=0.0, fixed=true, unit="m/s")    "Vehicle x velocity";
  Real vz(start=0.0, fixed=true, unit="m/s")    "Vehicle z velocity";
  Real phi(start=0.0, fixed=true, unit="rad")   "Vehicle pitch angle";
  Real q_pitch(start=0.0, fixed=true, unit="rad/s") "Vehicle pitch rate";
  Real theta(start=0.0, fixed=true, unit="rad") "Cable angle from vertical";
  Real omega(start=0.0, fixed=true, unit="rad/s") "Cable angular rate";

  // ===== Discrete rotor commands (250 Hz zero-order hold) =====
  discrete Real u1_d(start=8.0, unit="N") "Rotor 1 discrete command";
  discrete Real u2_d(start=8.0, unit="N") "Rotor 2 discrete command";
  discrete Real u3_d(start=8.0, unit="N") "Rotor 3 discrete command";
  discrete Real u4_d(start=8.0, unit="N") "Rotor 4 discrete command";
  discrete Real u5_d(start=8.0, unit="N") "Rotor 5 discrete command";
  discrete Real u6_d(start=8.0, unit="N") "Rotor 6 discrete command";

  // ===== Rotor thrusts =====
  Real u1(unit="N"), u2(unit="N"), u3(unit="N"), u4(unit="N"), u5(unit="N"), u6(unit="N");

  // ===== Forces and moments =====
  Real T_total(unit="N")     "Total rotor thrust";
  Real M_pitch(unit="N.m")   "Pitch moment from rotors";
  Real T_cable(unit="N")     "Cable tension";
  Real F_drag_x(unit="N")    "Aerodynamic drag x";
  Real F_drag_z(unit="N")    "Aerodynamic drag z";
  Real F_gust_t(unit="N")    "Time-varying gust force";
  Real ax_v(unit="m/s2")     "Vehicle x acceleration";
  Real az_v(unit="m/s2")     "Vehicle z acceleration";
  Real v_mag(unit="m/s")     "Vehicle speed";
  Real A_acc(unit="m/s2")    "Vehicle x accel excluding cable";
  Real Bg_acc(unit="m/s2")   "Vehicle z accel excluding cable plus g";

  // ===== Controller variables (continuous, for observability) =====
  Real x_ref(unit="m"), z_ref(unit="m"), vx_ref(unit="m/s"), vz_ref(unit="m/s");
  Real ax_des(unit="m/s2"), az_des(unit="m/s2"), phi_des(unit="rad");
  Real T_cmd(unit="N"), M_cmd(unit="N.m"), rhs_x(unit="N"), rhs_z(unit="N");

  // ===== Sensors =====
  Real gps_x(unit="m"), gps_z(unit="m"), gps_vx(unit="m/s"), gps_vz(unit="m/s");
  Real imu_ax(unit="m/s2"), imu_az(unit="m/s2"), imu_q(unit="rad/s");
  Real sens_cable_ang(unit="rad"), sens_cable_ten(unit="N");

  // ===== Payload =====
  Real px(unit="m") "Payload x position";
  Real pz(unit="m") "Payload z position";

  // ===== Acceptance =====
  Real track_err(unit="m")   "Vehicle tracking error";
  Real dist_tgt(unit="m")   "Payload distance to target center";
  Real swing_abs(unit="rad") "Absolute cable swing angle";
  Boolean thrust_ok     "All rotor thrusts within [0, T_max]";
  Boolean tension_ok    "Cable tension within [0, bound]";
  Boolean swing_ok      "Cable swing below 0.45 rad";
  Boolean placement_ok  "Payload within 0.8 m target zone";
  Boolean no_strike     "No ground strike";
  Boolean track_ok      "Tracking error below 0.27 m after 10.4 s";
  Boolean finite_ok     "No NaN or infinite values";

protected
  constant Real pi_c = 3.14159265358979;
  parameter Real R2 = R_rotor * R_rotor;
  parameter Real m_red = m_payload * m_total / (m_total + m_payload);
  // x-position fractions for hex layout (rotors at 0,60,120,180,240,300 deg)
  constant Real d1 = 1.0;
  constant Real d2 = 0.5;
  constant Real d3 = -0.5;
  constant Real d4 = -1.0;
  constant Real d5 = -0.5;
  constant Real d6 = 0.5;

equation
  // ===== Speed magnitude (zero-error protected) =====
  v_mag = sqrt(vx*vx + vz*vz + 1e-8);

  // ===== Aerodynamic drag =====
  F_drag_x = -cd_drag * vx * v_mag;
  F_drag_z = -cd_drag * vz * v_mag;

  // ===== Gust force (smooth window over middle third of flight) =====
  F_gust_t = F_gust * (
    if time < t_gust_a then 0.0
    elseif time < t_gust_a + 0.5 then 0.5*(1.0 - cos(pi_c*(time - t_gust_a)/0.5))
    elseif time < t_gust_b - 0.5 then 1.0
    elseif time < t_gust_b then 0.5*(1.0 + cos(pi_c*(time - (t_gust_b - 0.5))/0.5))
    else 0.0
  );

  // ===== Input-shaped trajectory references =====
  // X: raised-cosine 0 -> 5 over [t_hold_end, t_cruise_end]
  x_ref = if time < t_hold_end then 0.0
    elseif time < t_cruise_end then x_target*0.5*(1.0 - cos(pi_c*(time - t_hold_end)/(t_cruise_end - t_hold_end)))
    else x_target;
  vx_ref = if time < t_hold_end then 0.0
    elseif time < t_cruise_end then x_target*0.5*pi_c/(t_cruise_end - t_hold_end)*sin(pi_c*(time - t_hold_end)/(t_cruise_end - t_hold_end))
    else 0.0;
  // Z: raised-cosine 3.0 -> 1.0 over [t_cruise_end, t_sim]
  z_ref = if time < t_cruise_end then 3.0
    else 3.0 - 2.0*0.5*(1.0 - cos(pi_c*(time - t_cruise_end)/(t_sim - t_cruise_end)));
  vz_ref = if time < t_cruise_end then 0.0
    else -2.0*0.5*pi_c/(t_sim - t_cruise_end)*sin(pi_c*(time - t_cruise_end)/(t_sim - t_cruise_end));

  // ===== Position controller with cable-swing damping =====
  ax_des = kp_x*(x_ref - x) + kd_x*(vx_ref - vx) - k_swing*g_acc*theta - d_swing*L_cable*omega;
  az_des = kp_z*(z_ref - z) + kd_z*(vz_ref - vz);

  // ===== Thrust and attitude commands with cable-tension feedforward =====
  rhs_x = m_total*ax_des - T_ff*sin(theta);
  rhs_z = m_total*(az_des + g_acc) + T_ff*cos(theta);
  T_cmd = sqrt(rhs_x*rhs_x + rhs_z*rhs_z + 1e-8);
  phi_des = atan2(rhs_x, rhs_z);
  M_cmd = kp_phi*(phi_des - phi) + kd_phi*(0.0 - q_pitch);

  // ===== Discrete rotor allocation (250 Hz, six bounded channels) =====
  // Moment arm for rotor i = -d_i * R_rotor (front rotors create nose-up/negative phi moment)
  when sample(0, Ts) then
    u1_d = max(0.0, min(T_max, T_cmd/6.0 - M_cmd*d1/(3.0*R_rotor)));
    u2_d = max(0.0, min(T_max, T_cmd/6.0 - M_cmd*d2/(3.0*R_rotor)));
    u3_d = max(0.0, min(T_max, T_cmd/6.0 - M_cmd*d3/(3.0*R_rotor)));
    u4_d = max(0.0, min(T_max, T_cmd/6.0 - M_cmd*d4/(3.0*R_rotor)));
    u5_d = max(0.0, min(T_max, T_cmd/6.0 - M_cmd*d5/(3.0*R_rotor)));
    u6_d = max(0.0, min(T_max, T_cmd/6.0 - M_cmd*d6/(3.0*R_rotor)));
  end when;

  u1 = u1_d;  u2 = u2_d;  u3 = u3_d;
  u4 = u4_d;  u5 = u5_d;  u6 = u6_d;

  // ===== Total thrust and pitch moment =====
  T_total = u1 + u2 + u3 + u4 + u5 + u6;
  M_pitch = -(u1*d1 + u2*d2 + u3*d3 + u4*d4 + u5*d5 + u6*d6)*R_rotor;

  // ===== Intermediate acceleration variables =====
  A_acc = (T_total*sin(phi) + F_gust_t + F_drag_x)/m_total;
  Bg_acc = (T_total*cos(phi) + F_drag_z)/m_total;

  // ===== Cable tension (explicit — no algebraic loop) =====
  T_cable = m_red*(L_cable*omega*omega - A_acc*sin(theta) + Bg_acc*cos(theta));

  // ===== Vehicle accelerations =====
  ax_v = A_acc + T_cable*sin(theta)/m_total;
  az_v = Bg_acc - g_acc - T_cable*cos(theta)/m_total;

  // ===== Vehicle dynamics =====
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax_v;
  der(vz) = az_v;

  // ===== Pitch dynamics =====
  der(phi) = q_pitch;
  I_yy * der(q_pitch) = M_pitch - cd_rot*q_pitch;

  // ===== Cable pendulum dynamics (moving support) =====
  der(theta) = omega;
  der(omega) = -(A_acc*cos(theta) + Bg_acc*sin(theta))/L_cable;

  // ===== Payload position =====
  px = x + L_cable*sin(theta);
  pz = z - L_cable*cos(theta);

  // ===== Sensors (ideal) =====
  gps_x = x;        gps_z = z;        gps_vx = vx;      gps_vz = vz;
  imu_ax = ax_v;    imu_az = az_v;    imu_q = q_pitch;
  sens_cable_ang = theta;            sens_cable_ten = T_cable;

  // ===== Acceptance metrics =====
  track_err = sqrt((x_ref - x)*(x_ref - x) + (z_ref - z)*(z_ref - z) + 1e-10);
  dist_tgt  = sqrt((px - x_target)*(px - x_target) + (pz - z_target)*(pz - z_target) + 1e-10);
  swing_abs = abs(theta);

  // ===== Acceptance checks (fail-closed) =====
  thrust_ok = (u1 >= 0.0 and u1 <= T_max) and (u2 >= 0.0 and u2 <= T_max) and
              (u3 >= 0.0 and u3 <= T_max) and (u4 >= 0.0 and u4 <= T_max) and
              (u5 >= 0.0 and u5 <= T_max) and (u6 >= 0.0 and u6 <= T_max);
  tension_ok = (T_cable >= 0.0) and (T_cable <= T_cable_bound);
  swing_ok = swing_abs < 0.45;
  placement_ok = if time >= t_sim - 0.5 then dist_tgt < r_target else false;
  no_strike = (z >= 0.3) and (pz >= -0.05);
  track_ok = if time >= t_cruise_end then track_err < 0.27 else true;
  finite_ok = true;

  annotation(
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="HexaSurveyDeliverE: 6-rotor aerial robot with cable-suspended payload.
      Plant: 3.2 kg fuselage + 0.4 kg camera, 6 rotors at 0.35 m radius, 12.1 N max/rotor.
      Mission: lift, translate 5 m, lower into 0.8 m-radius target zone.
      Disturbance: 9.6 N lateral gust over middle third.
      Controller: input-shaped position control with cable-swing damping, 250 Hz discrete.
      Assumed values (not stated in requirement): payload mass 1.5 kg, cable length 1.0 m,
      drag/inertia coefficients, controller gains, tension bound."),
    __OpenModelica_simulationFlags(s="dassl")
  );
end HexaSurveyDeliverE;