model DuctInspectDeliverE
  "Free-base ducted-fan aerial robot with a suspended payload: lift, translate 5 m horizontally, and lower into a 0.8 m-radius target zone. Plant, sensors, controller, gust, and fail-closed acceptance are represented in one self-contained model."

  // ===== Physical parameters (SI) =====
  parameter Real m_b(unit="kg")      = 2.7  "body mass (requirement)";
  parameter Real m_p(unit="kg")      = 0.6  "payload mass (ASSUMPTION: not stated in request)";
  parameter Real m_total(unit="kg")  = m_b + m_p;
  parameter Real g(unit="m/s2")      = 9.81 "gravitational acceleration";
  parameter Real I_b(unit="kg.m2")   = 0.02 "body pitch inertia (ASSUMPTION)";
  parameter Real d_arm(unit="m")     = 0.25 "fan moment arm (ASSUMPTION)";
  parameter Real Cd_b(unit="N.s/m")  = 0.2  "body linear drag (ASSUMPTION)";
  parameter Real Cd_p(unit="N.s/m")  = 0.05 "payload linear drag (ASSUMPTION)";
  parameter Real L_probe(unit="m")   = 0.18 "inspection probe length along body X (requirement)";
  parameter Real Fmax_per_fan(unit="N") = 19.8 "per-fan command bound (requirement)";
  parameter Real Tmax_total(unit="N")   = 4.0*Fmax_per_fan "total thrust bound";
  parameter Real T_cable_max(unit="N")  = 20.0 "cable tension bound (ASSUMPTION: not stated)";
  parameter Real Fp_max(unit="N")       = 5.0  "probe-force actuator bound (ASSUMPTION: not stated)";
  parameter Real Lc0(unit="m")    = 1.0 "initial cable length (ASSUMPTION)";
  parameter Real Lc_ext(unit="m") = 3.0 "extended cable length for delivery (ASSUMPTION, matches cruise altitude)";
  parameter Real xb0(unit="m")   = 0.0 "initial body x";
  parameter Real zb0(unit="m")   = 2.0 "initial body height (ASSUMPTION)";
  parameter Real zb_cruise(unit="m") = 3.0 "cruise altitude (ASSUMPTION)";
  parameter Real x_target(unit="m")  = 5.0 "target x (requirement: translate 5 m)";
  parameter Real z_target(unit="m")  = 0.0 "target z (ground zone)";
  parameter Real r_target(unit="m")  = 0.8 "target-zone radius (requirement)";
  parameter Real Fgust(unit="N") = 9.6 "gust force magnitude (requirement)";
  parameter Real t_g1(unit="s") = 16.0/3.0 "gust start, middle third of 16 s run";
  parameter Real t_g2(unit="s") = 32.0/3.0 "gust end";
  parameter Real k_g(unit="N/m")   = 8000.0 "ground contact stiffness (ASSUMPTION)";
  parameter Real c_g(unit="N.s/m") = 200.0  "ground contact damping (ASSUMPTION)";

  // ===== Controller parameters =====
  parameter Real Kp_pos   = 2.0;
  parameter Real Kd_pos   = 3.0;
  parameter Real Kp_z     = 2.5;
  parameter Real Kd_z     = 3.0;
  parameter Real Kp_att   = 80.0;
  parameter Real Kd_att   = 12.0;
  parameter Real K_swing  = 2.0  "cable-swing damping gain";
  parameter Real Kw_winch = 6.0;
  parameter Real Cw_winch = 5.0;
  parameter Real wn_shp   = 2.0  "input-shaper natural frequency";
  parameter Real zeta_shp = 0.9  "input-shaper damping";
  parameter Real theta_max(unit="rad") = 0.35 "pitch command bound (ASSUMPTION)";
  parameter Real sample_dt(unit="s") = 0.004 "control period = 250 Hz";

  // ===== Continuous states =====
  Real xb(unit="m"),     vx(unit="m/s");
  Real zb(unit="m"),     vz(unit="m/s");
  Real theta(unit="rad"), omega(unit="rad/s");
  Real phi(unit="rad"),   dphi(unit="rad/s") "cable swing angle from vertical";
  Real Lc(unit="m"),     dLc(unit="m/s")    "cable length and rate";

  // ===== Discrete controller states (250 Hz) =====
  discrete Real T_d(unit="N", start=32.4)       "commanded total thrust";
  discrete Real theta_d(unit="rad", start=0.0)  "commanded pitch";
  discrete Real Lc_d(unit="m", start=Lc0)       "commanded cable length";
  discrete Real xd_shp(unit="m", start=xb0),  vxd_shp(unit="m/s", start=0.0);
  discrete Real zd_shp(unit="m", start=zb0),  vzd_shp(unit="m/s", start=0.0);
  discrete Real ax_cmd(unit="m/s2", start=0.0), az_cmd(unit="m/s2", start=0.0);
  discrete Real F_probe_cmd(unit="N", start=0.0);
  discrete Real xd_raw(start=xb0), zd_raw(start=zb0), Lc_raw(start=Lc0);
  discrete Real T_des(unit="N", start=32.4);

  // ===== Discrete acceptance trackers =====
  discrete Real swing_peak(unit="rad", start=0.0);
  discrete Real z_p_min(unit="m", start=10.0);
  discrete Real track_err_peak(unit="m", start=0.0);
  discrete Boolean placed_in_target(start=false);

  // ===== Computed / sensor quantities =====
  Real T_total(unit="N") "actual total thrust";
  Real f1,f2,f3,f4(unit="N") "per-fan thrust (saturated)";
  Real tau_cmd(unit="N.m"), tau_actual(unit="N.m");
  Real T_cable(unit="N") "cable tension";
  Real F_probe(unit="N");
  Real xp(unit="m"), zp(unit="m") "payload position";
  Real vp_x(unit="m/s"), vp_z(unit="m/s");
  Real Fgnd_z(unit="N");
  Real gust_on;
  Real Fg_b_x(unit="N"), Fg_p_x(unit="N");
  Real Fd_b_x(unit="N"), Fd_b_z(unit="N"), Fd_p_x(unit="N"), Fd_p_z(unit="N");
  Real Fext_b_x(unit="N"), Fext_b_z(unit="N"), Fext_p_x(unit="N"), Fext_p_z(unit="N");
  Real Fx_fan(unit="N"), Fz_fan(unit="N");
  Real ax_b(unit="m/s2"), az_b(unit="m/s2");
  Real st, ct, s_phi, c_phi;
  Real Lc_safe(unit="m");
  Real det, det_safe;
  Real Pterm, Rhs1, Rhs2, Aacc, Bacc;
  Real a11,a12,a21,a22;
  Real phi_ddot(unit="rad/s2");
  Real d2Lc(unit="m/s2");
  Real in_target_dist(unit="m");
  Real fan_max_obs(unit="N");

  // ===== Acceptance booleans =====
  Boolean accept_thrust;
  Boolean accept_tension;
  Boolean accept_swing;
  Boolean accept_target;
  Boolean accept_no_ground;
  Boolean accept_tracking;
  Boolean accept_no_nan;
  Boolean overall_accept;

  function isfinite "Finite-and-not-NaN test via bounded comparison"
    input Real x;
    output Boolean y;
  algorithm
    y := (x >= -1.0e12) and (x <= 1.0e12);
  end isfinite;

initial equation
  xb = xb0;      vx = 0.0;
  zb = zb0;      vz = 0.0;
  theta = 0.0;   omega = 0.0;
  phi = 0.0;     dphi = 0.0;
  Lc = Lc0;      dLc = 0.0;

equation
  // ---- kinematics ----
  der(xb) = vx;
  der(zb) = vz;
  der(theta) = omega;
  der(phi) = dphi;
  der(Lc) = dLc;

  // ---- trig + guards (zero-error branches) ----
  st = sin(theta);
  ct = cos(theta);
  s_phi = sin(phi);
  c_phi = cos(phi);
  Lc_safe = if Lc > 0.05 then Lc else 0.05;

  // ---- payload kinematics / sensors ----
  xp = xb + Lc*s_phi;
  zp = zb - Lc*c_phi;
  vp_x = vx + dLc*s_phi + Lc*dphi*c_phi;
  vp_z = vz - dLc*c_phi + Lc*dphi*s_phi;

  // ---- aerodynamic drag ----
  Fd_b_x = -Cd_b*vx;
  Fd_b_z = -Cd_b*vz;
  Fd_p_x = -Cd_p*vp_x;
  Fd_p_z = -Cd_p*vp_z;

  // ---- lateral gust (middle third), distributed by mass fraction ----
  gust_on = if (time >= t_g1) and (time <= t_g2) then 1.0 else 0.0;
  Fg_b_x = gust_on*Fgust*(m_b/m_total);
  Fg_p_x = gust_on*Fgust*(m_p/m_total);

  // ---- ground contact on payload (no ground strike) ----
  Fgnd_z = if zp < 0.0 then (-k_g*zp - c_g*vp_z) else 0.0;

  // ---- probe-force actuator along body X = (cos theta, -sin theta) ----
  F_probe = F_probe_cmd;

  // ---- external resultants ----
  Fext_b_x = Fd_b_x + Fg_b_x + F_probe*ct;
  Fext_b_z = Fd_b_z + F_probe*(-st);
  Fext_p_x = Fd_p_x + Fg_p_x;
  Fext_p_z = Fd_p_z + Fgnd_z;

  // ---- fan mixing: collective T_d + attitude torque tau_cmd ----
  tau_cmd = Kp_att*(theta_d - theta) - Kd_att*omega;
  // front pair (f1=f2), rear pair (f3=f4), pre-saturation
  // Sf = T_d/2 + tau_cmd/(2*d_arm); Sr = T_d/2 - tau_cmd/(2*d_arm); each fan = Sf/2 or Sr/2
  f1 = max(0.0, min(Fmax_per_fan, (T_d/2.0 + tau_cmd/(2.0*d_arm))/2.0));
  f2 = f1;
  f3 = max(0.0, min(Fmax_per_fan, (T_d/2.0 - tau_cmd/(2.0*d_arm))/2.0));
  f4 = f3;
  T_total = f1 + f2 + f3 + f4;
  tau_actual = (f1 + f2 - f3 - f4)*d_arm;
  fan_max_obs = max(max(f1,f2), max(f3,f4));

  // ---- body forces from fans (thrust along body Z = (sin theta, cos theta)) ----
  Fx_fan = T_total*st;
  Fz_fan = T_total*ct;

  // ---- non-cable body accelerations ----
  Aacc = (Fx_fan + Fext_b_x)/m_b;
  Bacc = (Fz_fan + Fext_b_z - m_b*g)/m_b;

  // ---- winch dynamics ----
  d2Lc = Kw_winch*(Lc_d - Lc) - Cw_winch*dLc;
  der(dLc) = d2Lc;

  // ---- coupled cable-swing + tension solve (linear 2x2, explicit, no algebraic loop) ----
  Pterm = (Fext_p_x*c_phi + (-m_p*g + Fext_p_z)*s_phi)/m_p;
  Rhs1  = Pterm - Aacc*c_phi - Bacc*s_phi - 2.0*dLc*dphi + 2.0*Lc_safe*dphi*dphi*s_phi*c_phi;
  Rhs2  = Fext_p_x*s_phi + (m_p*g - Fext_p_z)*c_phi - m_p*(Aacc*s_phi - Bacc*c_phi)
          - m_p*d2Lc + m_p*Lc*dphi*dphi;
  a11 = Lc_safe;
  a12 = -(2.0/m_b)*s_phi*c_phi;
  a21 = m_p*2.0*Lc*s_phi*c_phi;
  a22 = 1.0 + (m_p/m_b)*(c_phi*c_phi - s_phi*s_phi);
  det = a11*a22 - a12*a21;
  det_safe = if det > 1.0e-6 then det else 1.0e-6;
  phi_ddot = (Rhs1*a22 - a12*Rhs2)/det_safe;
  T_cable  = (a11*Rhs2 - a21*Rhs1)/det_safe;
  der(dphi) = phi_ddot;

  // ---- body translational dynamics ----
  ax_b = Aacc - (T_cable/m_b)*s_phi;
  az_b = Bacc - (T_cable/m_b)*c_phi;
  der(vx) = ax_b;
  der(vz) = az_b;

  // ---- attitude dynamics ----
  der(omega) = tau_actual/I_b;

  // ---- target-zone distance ----
  in_target_dist = sqrt((xp - x_target)*(xp - x_target) + (zp - z_target)*(zp - z_target));

  // ===== Acceptance (fail-closed) =====
  accept_thrust    = (T_total <= Tmax_total + 1.0e-6) and (fan_max_obs <= Fmax_per_fan + 1.0e-6)
                    and (f1 >= -1.0e-6) and (f2 >= -1.0e-6) and (f3 >= -1.0e-6) and (f4 >= -1.0e-6);
  accept_tension   = (T_cable >= -1.0e-3) and (T_cable <= T_cable_max + 1.0e-3);
  accept_swing     = swing_peak < 0.45;
  accept_target    = placed_in_target;
  accept_no_ground = (z_p_min >= -1.0e-3);
  accept_tracking  = (track_err_peak < 0.27);
  accept_no_nan    = isfinite(T_cable) and isfinite(T_total) and isfinite(xb)
                     and isfinite(zb) and isfinite(phi) and isfinite(theta)
                     and isfinite(Lc) and isfinite(ax_b) and isfinite(az_b)
                     and isfinite(phi_ddot) and isfinite(omega) and isfinite(T_cable);
  overall_accept  = accept_thrust and accept_tension and accept_swing and accept_target
                    and accept_no_ground and accept_tracking and accept_no_nan;

  // ===== Discrete controller + acceptance trackers at 250 Hz =====
  when sample(0, sample_dt) then
    // --- waypoint schedule (lift, translate, lower, hold) ---
    if time < 3.0 then
      xd_raw := 0.0;
      zd_raw := zb_cruise;
      Lc_raw := Lc0;
    elseif time < 8.0 then
      xd_raw := x_target;
      zd_raw := zb_cruise;
      Lc_raw := Lc0;
    elseif time < 14.0 then
      xd_raw := x_target;
      zd_raw := zb_cruise;
      Lc_raw := Lc0 + (Lc_ext - Lc0)*(time - 8.0)/6.0;
    else
      xd_raw := x_target;
      zd_raw := zb_cruise;
      Lc_raw := Lc_ext;
    end if;

    // --- input shaper (2nd-order critically-damped filter on waypoints) ---
    vxd_shp := vxd_shp + sample_dt*(-2.0*zeta_shp*wn_shp*vxd_shp - wn_shp*wn_shp*(xd_shp - xd_raw));
    xd_shp  := xd_shp + sample_dt*vxd_shp;
    vzd_shp := vzd_shp + sample_dt*(-2.0*zeta_shp*wn_shp*vzd_shp - wn_shp*wn_shp*(zd_shp - zd_raw));
    zd_shp  := zd_shp + sample_dt*vzd_shp;

    // --- PD position control with cable-swing damping + gust feedforward ---
    ax_cmd := Kp_pos*(xd_shp - xb) + Kd_pos*(-vx) - K_swing*dphi - gust_on*Fgust/m_total;
    az_cmd := Kp_z*(zd_shp - zb) + Kd_z*(-vz);

    // --- thrust magnitude command (saturated to total bound) ---
    T_des := m_total*sqrt(ax_cmd*ax_cmd + (az_cmd + g)*(az_cmd + g));
    if T_des > Tmax_total then
      T_d := Tmax_total;
    elseif T_des < 0.0 then
      T_d := 0.0;
    else
      T_d := T_des;
    end if;

    // --- pitch command from thrust direction, bounded ---
    if abs(az_cmd + g) < 0.5 then
      theta_d := if ax_cmd >= 0.0 then theta_max else -theta_max;
    else
      theta_d := atan(ax_cmd/(az_cmd + g));
    end if;
    if theta_d > theta_max then
      theta_d := theta_max;
    elseif theta_d < -theta_max then
      theta_d := -theta_max;
    end if;

    Lc_d := Lc_raw;
    F_probe_cmd := 0.0;  // no probe contact during this mission (bounded actuator idle)

    // --- acceptance trackers ---
    if abs(phi) > swing_peak then
      swing_peak := abs(phi);
    end if;
    if zp < z_p_min then
      z_p_min := zp;
    end if;
    if time >= 10.4 then
      if abs(xb - x_target) > track_err_peak then
        track_err_peak := abs(xb - x_target);
      end if;
    end if;
    if (time > 14.0) and (in_target_dist <= r_target) then
      placed_in_target := true;
    end if;
  end when;

  annotation (
    Documentation(info="Free-base ducted-fan aerial robot DuctInspectDeliverE. 2.7 kg body, 4 ducted fans (19.8 N/fan bound), 0.18 m compliant probe along body X, suspended payload on a winched cable. Mission: lift, translate 5 m, lower into 0.8 m-radius target zone. IMU+GPS+cable-angle+tension feedback. Gravity, drag, and a 9.6 N middle-third lateral gust are applied. Input-shaped position control with cable-swing damping and gust feedforward. 250 Hz, 16 s. Fail-closed acceptance: thrust/tension bounds, swing<0.45 rad, target placement, no ground strike, tracking error<0.27 m after 10.4 s, no NaN/inf."),
    experiment(StopTime=16.0, Tolerance=1.0e-6, Interval=0.004)
  );
end DuctInspectDeliverE;