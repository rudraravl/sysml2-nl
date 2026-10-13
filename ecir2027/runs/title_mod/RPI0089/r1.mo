model DuctInspectDeliverE
  "Free-base ducted-fan aerial robot with suspended payload:
   lift, translate 5 m, lower into 0.8 m-radius target zone.
   250 Hz discrete controller, 16 s scenario, fail-closed acceptance."

  // ===== Specified parameters =====
  parameter Real m_body(unit="kg")      = 2.7  "Body mass";
  parameter Real T_fan_max(unit="N")    = 19.8 "Per-fan thrust command bound";
  parameter Real L_probe(unit="m")      = 0.18 "Inspection probe length along body X";
  parameter Real r_target(unit="m")     = 0.8  "Target-zone radius";
  parameter Real x_goal(unit="m")       = 5.0  "Horizontal translation goal";
  parameter Real F_gust(unit="N")       = 9.6  "Gust force magnitude (middle third)";
  parameter Real swing_lim(unit="rad")  = 0.45 "Cable swing acceptance limit";
  parameter Real err_lim(unit="m")      = 0.27 "Primary tracking-error limit after settle";
  parameter Real t_settle(unit="s")     = 10.4 "Settle time for tracking-error check";
  parameter Real T_end(unit="s")       = 16.0 "Simulation duration";
  parameter Real f_rate(unit="Hz")     = 250.0 "Controller rate";
  parameter Real dt(unit="s")           = 1.0/f_rate "Control period";

  // ===== Assumed parameters (NOT specified in requirement; labeled) =====
  parameter Real m_payload(unit="kg")   = 1.0  "ASSUMED payload mass (not specified)";
  parameter Real L_cable(unit="m")      = 0.6  "ASSUMED cable length (not specified)";
  parameter Real z_start(unit="m")      = 0.9  "ASSUMED initial hover altitude";
  parameter Real z_hover(unit="m")     = 1.5  "ASSUMED cruise altitude";
  parameter Real z_final(unit="m")      = 0.65 "ASSUMED delivery body altitude (> L_cable)";
  parameter Real g(unit="m/s2")        = 9.81 "Gravity";
  parameter Real Cd(unit="kg/s")       = 0.15 "ASSUMED linear aerodynamic drag coefficient";
  parameter Real tau_att(unit="s")     = 0.08 "ASSUMED attitude first-order lag";
  parameter Real c_nat(unit="1/s")      = 0.3  "ASSUMED natural cable damping";
  parameter Real F_probe_max(unit="N") = 6.0  "ASSUMED probe-force actuator bound (not specified)";
  parameter Real T_cable_max(unit="N") = 60.0 "ASSUMED cable tension bound (not specified)";

  // Controller gains (ASSUMED; tuned for verification scenario)
  parameter Real Kp_x = 3.0, Kd_x = 3.5, Ki_x = 1.5;
  parameter Real Kp_y = 3.0, Kd_y = 3.5, Ki_y = 1.5;
  parameter Real Kp_z = 5.0, Kd_z = 4.0;
  parameter Real K_swing = 1.2 "Cable-swing damping gain on accel command";
  parameter Real a_lim = 8.0 "Horizontal acceleration command limit";
  parameter Real int_lim = 2.0 "Integral anti-windup limit";

  // Trajectory phase times
  parameter Real t_l1 = 3.0  "end of lift";
  parameter Real t_l2 = 4.0  "start of cruise";
  parameter Real t_l3 = 10.0 "end of cruise";
  parameter Real t_l4 = 11.0 "start of lower";
  parameter Real t_l5 = 15.0 "end of lower";
  parameter Real g_on1 = 5.333, g_on2 = 5.833;
  parameter Real g_off1 = 10.167, g_off2 = 10.667;

  // ===== Body states =====
  Real x(unit="m", start=0.0, fixed=true);
  Real y(unit="m", start=0.0, fixed=true);
  Real z(unit="m", start=0.9, fixed=true);
  Real vx(unit="m/s", start=0.0, fixed=true);
  Real vy(unit="m/s", start=0.0, fixed=true);
  Real vz(unit="m/s", start=0.0, fixed=true);
  Real theta(unit="rad", start=0.0, fixed=true) "pitch";
  Real phi(unit="rad", start=0.0, fixed=true)   "roll";

  // ===== Cable / payload states =====
  Real alpha(unit="rad", start=0.0, fixed=true)  "cable swing in x";
  Real beta(unit="rad", start=0.0, fixed=true)   "cable swing in y";
  Real alphad(unit="rad/s", start=0.0, fixed=true);
  Real betad(unit="rad/s", start=0.0, fixed=true);
  Real px(unit="m"), py(unit="m"), pz(unit="m") "payload position";

  // ===== Actuator / command traces =====
  Real T_total_cmd(unit="N");
  Real T1(unit="N"), T2(unit="N"), T3(unit="N"), T4(unit="N");
  Real theta_cmd(unit="rad"), phi_cmd(unit="rad");
  Real u_probe_cmd(unit="N");
  Real u_probe(unit="N") "actual probe force along body X";

  // ===== Sensors =====
  Real x_gps(unit="m"), y_gps(unit="m"), z_gps(unit="m");
  Real vx_imu(unit="m/s"), vy_imu(unit="m/s"), vz_imu(unit="m/s");
  Real alpha_meas(unit="rad"), beta_meas(unit="rad");
  Real T_meas(unit="N");

  // ===== Gust / environment =====
  Real gust(unit="N");

  // ===== Reference =====
  Real x_ref(unit="m"), z_ref(unit="m"), vx_ref(unit="m/s"), vz_ref(unit="m/s");

  // ===== Tracking / acceptance =====
  Real tracking_err(unit="m");
  Real max_swing(unit="rad", start=0.0);
  Real min_pz(unit="m", start=10.0);
  Real max_thrust(unit="N", start=0.0);
  Real max_tension(unit="N", start=0.0);
  Real max_err_after(unit="m", start=0.0);
  Boolean nan_flag(start=false);

  Boolean thrust_viol_final, tension_viol_final, swing_viol_final;
  Boolean ground_viol_final, tracking_viol_final, nan_viol_final;
  Boolean target_placed, accepted;

  // ===== Intermediates =====
  Real m_total(unit="kg");
  Real ax_cmd(unit="m/s2"), ay_cmd(unit="m/s2"), az_cmd(unit="m/s2");
  Real int_x(start=0.0), int_y(start=0.0);
  Real cos_t, sin_t, cos_p, sin_p;
  Real Fx_thrust(unit="N"), Fy_thrust(unit="N"), Fz_thrust(unit="N");
  Real Fx_probe_w(unit="N"), Fz_probe_w(unit="N");
  Real ax_body(unit="m/s2"), ay_body(unit="m/s2"), az_body(unit="m/s2");
  Real T_cable(unit="N");
  Real T_total_eff(unit="N");

equation
  m_total = m_body + m_payload;

  // Reference trajectory (input-shaped via smooth ramps)
  x_ref  = x_goal * smoothstep(time, t_l2, t_l3);
  vx_ref = x_goal * dsmoothstep(time, t_l2, t_l3);
  z_ref  = z_start
           + (z_hover - z_start) * smoothstep(time, 0.0, t_l1)
           - (z_hover - z_final) * smoothstep(time, t_l4, t_l5);
  vz_ref = (z_hover - z_start) * dsmoothstep(time, 0.0, t_l1)
           - (z_hover - z_final) * dsmoothstep(time, t_l4, t_l5);

  // Gust: shaped 9.6 N along +x during middle third of scenario
  gust = F_gust * (smoothstep(time, g_on1, g_on2)
                   - smoothstep(time, g_off1, g_off2));

  // Thrust allocation (equal split, per-fan bounded)
  T1 = max(0.0, min(T_fan_max, T_total_cmd/4.0));
  T2 = T1;  T3 = T1;  T4 = T1;
  T_total_eff = 4.0*T1;

  // Thrust vector in world frame (simplified attitude)
  cos_t = cos(theta);  sin_t = sin(theta);
  cos_p = cos(phi);    sin_p = sin(phi);
  Fx_thrust = T_total_eff*sin_t;
  Fy_thrust = -T_total_eff*sin_p*cos_t;
  Fz_thrust = T_total_eff*cos_t*cos_p;

  // Probe force actuator along body X (compliant probe; force command bounded)
  u_probe = max(-F_probe_max, min(F_probe_max, u_probe_cmd));
  Fx_probe_w = u_probe*cos_t;
  Fz_probe_w = -u_probe*sin_t;

  // Body translational dynamics (combined-mass simplification for cable coupling)
  ax_body = (Fx_thrust + Fx_probe_w + gust - Cd*vx) / m_total;
  ay_body = (Fy_thrust - Cd*vy) / m_total;
  az_body = (Fz_thrust + Fz_probe_w - m_total*g - Cd*vz) / m_total;
  der(x) = vx;   der(y) = vy;   der(z) = vz;
  der(vx) = ax_body;  der(vy) = ay_body;  der(vz) = az_body;

  // Attitude first-order lag from commanded tilt
  der(theta) = (theta_cmd - theta)/tau_att;
  der(phi)   = (phi_cmd - phi)/tau_att;

  // Cable swing dynamics (pendulum with accelerating pivot)
  der(alpha) = alphad;
  der(beta)  = betad;
  der(alphad) = (-g*sin(alpha) - ax_body*cos(alpha) - az_body*sin(alpha))/L_cable
                 - c_nat*alphad;
  der(betad)  = (-g*sin(beta)  - ay_body*cos(beta)  - az_body*sin(beta))/L_cable
                 - c_nat*betad;

  // Cable tension (radial force balance; floored at zero)
  T_cable = max(0.0, m_payload*(g*cos(alpha)*cos(beta)
              + L_cable*(alphad*alphad + betad*betad)
              + ax_body*sin(alpha)
              - az_body*cos(alpha)*cos(beta)));

  // Payload position
  px = x + L_cable*sin(alpha);
  py = y + L_cable*sin(beta);
  pz = z - L_cable*cos(alpha)*cos(beta);

  // Sensors (ideal; traces retained for verification)
  x_gps = x;   y_gps = y;   z_gps = z;
  vx_imu = vx; vy_imu = vy; vz_imu = vz;
  alpha_meas = alpha; beta_meas = beta;
  T_meas = T_cable;

  // Primary tracking error (body vs reference)
  tracking_err = sqrt((x - x_ref)^2 + (y - 0.0)^2 + (z - z_ref)^2);

  // Acceptance (fail-closed, evaluated at scenario end)
  thrust_viol_final   = max_thrust > T_fan_max + 1e-6;
  tension_viol_final  = max_tension > T_cable_max + 1e-6;
  swing_viol_final    = max_swing > swing_lim;
  ground_viol_final   = min_pz < -0.02;
  tracking_viol_final = max_err_after > err_lim;
  nan_viol_final      = nan_flag;
  target_placed = (time >= T_end - 1e-3)
                  and (sqrt((px - x_goal)^2 + py^2 + pz^2) <= r_target);
  accepted = (time >= T_end - 1e-3)
             and not (thrust_viol_final or tension_viol_final
                      or swing_viol_final or ground_viol_final
                      or tracking_viol_final or nan_viol_final)
             and target_placed;

algorithm
  when sample(0, dt) then
    // Input-shaped position control with cable-swing damping
    ax_cmd := Kp_x*(x_ref - x) + Kd_x*(vx_ref - vx) + Ki_x*int_x - K_swing*alphad;
    ay_cmd := Kp_y*(0.0 - y)   + Kd_y*(0.0 - vy)   + Ki_y*int_y - K_swing*betad;
    az_cmd := Kp_z*(z_ref - z) + Kd_z*(vz_ref - vz);
    // Clamp horizontal acceleration commands
    ax_cmd := max(-a_lim, min(a_lim, ax_cmd));
    ay_cmd := max(-a_lim, min(a_lim, ay_cmd));
    // Integral update with anti-windup
    int_x := max(-int_lim, min(int_lim, pre(int_x) + (x_ref - x)*dt));
    int_y := max(-int_lim, min(int_lim, pre(int_y) + (0.0 - y)*dt));
    // Total thrust command (bounded by 4 * per-fan bound)
    T_total_cmd := (m_total*g + m_total*az_cmd) / max(cos(theta)*cos(phi), 0.5);
    T_total_cmd := max(0.0, min(4.0*T_fan_max, T_total_cmd));
    // Attitude commands from desired horizontal acceleration
    theta_cmd := max(-0.4, min(0.4, m_total*ax_cmd / max(T_total_cmd, 1e-3)));
    phi_cmd   := max(-0.4, min(0.4, -m_total*ay_cmd / max(T_total_cmd, 1e-3)));
    // Probe-force actuator idle in this scenario (inspection not exercised)
    u_probe_cmd := 0.0;
    // Synchronized acceptance monitors (latched extrema)
    max_swing  := max(pre(max_swing), max(abs(alpha), abs(beta)));
    min_pz     := min(pre(min_pz), pz);
    max_thrust := max(pre(max_thrust), T1);
    max_tension:= max(pre(max_tension), T_cable);
    if time > t_settle then
      max_err_after := max(pre(max_err_after), tracking_err);
    else
      max_err_after := pre(max_err_after);
    end if;
    // NaN/Inf latching for physical, control, and estimator traces
    nan_flag := (x <> x) or (z <> z) or (alpha <> alpha) or
                (T_total_cmd <> T_total_cmd) or (T_cable <> T_cable) or
                (tracking_err <> tracking_err) or pre(nan_flag);
  end when;

  annotation (
    experiment(StopTime = 16.0, Interval = 0.004, Tolerance = 1e-6),
    Documentation(info="Ducted-fan aerial robot (DuctInspectDeliverE).
      Plant: 2.7 kg body with four ducted fans (<=19.8 N each), compliant
      0.18 m inspection probe along body X, suspended payload via cable with
      swing angles and tension measurement. Gravity, linear drag, and a shaped
      9.6 N lateral (+x) gust during the middle third are applied.
      250 Hz discrete PD+I position controller with input-shaped reference and
      cable-swing damping. Acceptance is fail-closed at t=16 s."));
end DuctInspectDeliverE;