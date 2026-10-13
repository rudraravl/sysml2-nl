model CartesianToolPolishD
  /* Contact-rich polishing system: 3 orthogonal prismatic axes (X,Y,Z) move a
     single 2.5 kg tool carriage over a fixed curved workpiece. Tangential
     trajectory tracking + normal-force admittance regulation. Controller runs
     at 200 Hz; plant/contact continuous.
     Notes on unknowns (not invented):
       - Gravity direction/compensation not stated; gravity omitted (Z treated as
         a generalized prismatic coordinate, not necessarily vertical).
       - Exact arc-length parametrization of the 0.50 m path is approximated by a
         path coordinate s in [0, 0.50]; the geometric curve fits within the
         declared stroke limits. */

  // ----- Physical parameters -----
  parameter Real m_tool(unit="kg")      = 2.5    "tool carriage mass";
  parameter Real F_axis_max(unit="N")   = 350.0 "per-axis actuator force limit";
  parameter Real pos_lim_x(unit="m")    = 0.10  "X stroke (half-range)";
  parameter Real pos_lim_y(unit="m")    = 0.10  "Y stroke (half-range)";
  parameter Real pos_lim_z(unit="m")    = 0.30  "Z stroke (half-range)";
  parameter Real mu_fric(unit="1")      = 0.50  "workpiece friction coefficient";
  parameter Real k_contact(unit="N/m")  = 2000.0 "normal contact stiffness";
  parameter Real d_contact(unit="N.s/m")= 100.0  "normal contact damping";

  // ----- Control / task parameters -----
  parameter Real F_n_des(unit="N")      = 20.0  "desired normal force (mid of 12-30)";
  parameter Real F_n_min(unit="N")      = 12.0  "min allowed normal force";
  parameter Real F_n_max(unit="N")      = 30.0  "max allowed normal force";
  parameter Real Kp_pos(unit="N/m")      = 3000.0 "position proportional gain";
  parameter Real Kd_pos(unit="N.s/m")    = 120.0  "position derivative gain";
  parameter Real m_adm(unit="kg")        = 2.5    "admittance virtual mass";
  parameter Real b_adm(unit="N.s/m")     = 120.0  "admittance damping";
  parameter Real v_small(unit="m/s")     = 0.01   "friction velocity smoothing";
  parameter Real T_sim(unit="s")         = 14.0   "task duration";
  parameter Real T_sample(unit="s")      = 0.005  "control sample period (200 Hz)";
  parameter Real F_dist(unit="N")        = 7.0    "surface-force disturbance magnitude";
  parameter Real path_len(unit="m")      = 0.50   "surface path length";
  parameter Real curve_amp_y(unit="m")   = 0.10   "Y curve amplitude";
  parameter Real z_start(unit="m")       = -0.25  "curve start Z";
  parameter Real track_tol(unit="m")     = 0.02   "tracking tolerance after 9.1 s";
  constant  Real PI = 3.141592653589793;

  // ----- Plant states (tool-tip pose + velocity) -----
  Real x(unit="m"),  y(unit="m"),  z(unit="m");
  Real vx(unit="m/s"), vy(unit="m/s"), vz(unit="m/s");

  // ----- Reference trajectory (continuous) -----
  Real u_ref, s_ref(unit="m"), s_ref_dot(unit="m/s");
  Real yr(unit="m"), zr(unit="m"), dyr, dzr, nrm;
  Real t_y, t_z, n_y, n_z;
  Real yr_dot(unit="m/s"), zr_dot(unit="m/s");

  // ----- Contact (continuous) -----
  Real gap(unit="m"), pen(unit="m"), pen_dot(unit="m/s");
  Real F_n(unit="N"), v_tan(unit="m/s");
  Real F_fric_y(unit="N"), F_fric_z(unit="N");
  Real Fc_x(unit="N"), Fc_y(unit="N"), Fc_z(unit="N");
  Real dist_active, Fdist_y(unit="N"), Fdist_z(unit="N");

  // ----- Controller (sampled, 200 Hz, zero-order hold) -----
  discrete Real delta_n(unit="m", start=0.01);
  discrete Real delta_n_dot(unit="m/s", start=0.0);
  discrete Real Fx_cmd(unit="N", start=0.0);
  discrete Real Fy_cmd(unit="N", start=0.0);
  discrete Real Fz_cmd(unit="N", start=0.0);

  // ----- Sensor traces -----
  Real joint_enc_x(unit="m"), joint_enc_y(unit="m"), joint_enc_z(unit="m");
  Real wrench_Fy(unit="N"), wrench_Fz(unit="N"), wrench_Fn(unit="N");
  Real pose_x(unit="m"), pose_y(unit="m"), pose_z(unit="m");
  Real track_err(unit="m")  "primary tracking error vs commanded pose";
  Real e_tan(unit="m"), e_norm(unit="m");

  // ----- Verification metrics / bound flags -----
  discrete Real F_n_min_log(unit="N", start=1e9);
  discrete Real F_n_max_log(unit="N", start=0.0);
  discrete Real track_err_max91(unit="m", start=0.0);
  Boolean bound_joint_ok, bound_effort_ok, bound_force_ok;
  Boolean contact_ok, track_ok, no_nan_ok;

equation
  // ===== Reference path: smoothstep over [0, T_sim], s in [0, path_len] =====
  u_ref = max(0.0, min(1.0, time / T_sim));
  s_ref = path_len * (3*u_ref*u_ref - 2*u_ref*u_ref*u_ref);
  s_ref_dot = (path_len / T_sim) * (6*u_ref - 6*u_ref*u_ref);

  // ===== Curved workpiece curve in Y-Z (extruded along X), s as path coord =====
  yr  = curve_amp_y * sin(PI * s_ref / path_len);
  zr  = z_start + s_ref;
  dyr = curve_amp_y * (PI / path_len) * cos(PI * s_ref / path_len);
  dzr = 1.0;
  nrm = sqrt(dyr*dyr + dzr*dzr);   // always >= 1, well-defined
  t_y = dyr / nrm;
  t_z = dzr / nrm;
  n_y = dzr / nrm;                 // unit normal (no X component)
  n_z = -dyr / nrm;
  yr_dot = s_ref_dot * t_y;
  zr_dot = s_ref_dot * t_z;

  // ===== Compliant normal contact + Coulomb friction (continuous) =====
  gap     = (y - yr) * n_y + (z - zr) * n_z;     // >0: outside, <0: penetrating
  pen     = max(0.0, -gap);
  pen_dot = -(vy * n_y + vz * n_z);
  F_n     = if pen > 0.0 then max(0.0, k_contact*pen + d_contact*pen_dot) else 0.0;
  v_tan   = vy * t_y + vz * t_z;
  F_fric_y = -mu_fric * F_n * tanh(v_tan / v_small) * t_y;
  F_fric_z = -mu_fric * F_n * tanh(v_tan / v_small) * t_z;
  Fc_x = 0.0;
  Fc_y = F_n * n_y + F_fric_y;
  Fc_z = F_n * n_z + F_fric_z;

  // ===== 7 N surface-force disturbance during middle third of task =====
  dist_active = if (time >= T_sim/3.0 and time <= 2.0*T_sim/3.0) then 1.0 else 0.0;
  Fdist_y = F_dist * t_y * dist_active;
  Fdist_z = F_dist * t_z * dist_active;

  // ===== Plant dynamics (single 2.5 kg carriage, 3 Cartesian DOF) =====
  der(x)  = vx;
  der(y)  = vy;
  der(z)  = vz;
  der(vx) = (Fx_cmd + Fc_x) / m_tool;
  der(vy) = (Fy_cmd + Fc_y + Fdist_y) / m_tool;
  der(vz) = (Fz_cmd + Fc_z + Fdist_z) / m_tool;

  // ===== Sensors =====
  joint_enc_x = x; joint_enc_y = y; joint_enc_z = z;
  wrench_Fy  = Fc_y; wrench_Fz = Fc_z; wrench_Fn = F_n;
  pose_x = x; pose_y = y; pose_z = z;

  // ===== Errors / metrics (continuous) =====
  e_tan   = (y - yr) * t_y + (z - zr) * t_z;
  e_norm  = gap;
  track_err = sqrt(x*x + (y - yr + delta_n*n_y)*(y - yr + delta_n*n_y)
                          + (z - zr + delta_n*n_z)*(z - zr + delta_n*n_z));

  // ===== Bound checks (soft, observable) =====
  bound_joint_ok  = abs(x) <= pos_lim_x and abs(y) <= pos_lim_y and abs(z) <= pos_lim_z;
  bound_effort_ok = abs(Fx_cmd) <= F_axis_max + 1e-6 and
                    abs(Fy_cmd) <= F_axis_max + 1e-6 and
                    abs(Fz_cmd) <= F_axis_max + 1e-6;
  bound_force_ok  = F_n >= F_n_min and F_n <= F_n_max;
  contact_ok      = pen > 0.0;
  track_ok        = if time >= 9.1 then track_err < track_tol else true;
  no_nan_ok       = (x == x) and (y == y) and (z == z) and
                    (vx == vx) and (vy == vy) and (vz == vz) and
                    (F_n == F_n) and (delta_n == delta_n);

  // ===== Sampled controller (200 Hz) =====
  when sample(0, T_sample) then
    // Normal-force admittance: m_adm*ddot(delta_n) + b_adm*dot(delta_n) = F_n_des - F_n
    delta_n_dot = pre(delta_n_dot) + (T_sample / m_adm) *
                  ((F_n_des - F_n) - b_adm * pre(delta_n_dot));
    delta_n     = pre(delta_n) + T_sample * delta_n_dot;

    // Cartesian PD with actuator saturation (effort bounds, 350 N/axis)
    Fx_cmd = max(-F_axis_max, min(F_axis_max,
                Kp_pos*(0.0 - x) + Kd_pos*(0.0 - vx)));
    Fy_cmd = max(-F_axis_max, min(F_axis_max,
                Kp_pos*((yr - delta_n*n_y) - y) +
                Kd_pos*((yr_dot - delta_n_dot*n_y) - vy)));
    Fz_cmd = max(-F_axis_max, min(F_axis_max,
                Kp_pos*((zr - delta_n*n_z) - z) +
                Kd_pos*((zr_dot - delta_n_dot*n_z) - vz)));

    // Recorded extremes
    F_n_min_log = min(pre(F_n_min_log), F_n);
    F_n_max_log = max(pre(F_n_max_log), F_n);
    if time >= 9.1 then
      track_err_max91 = max(pre(track_err_max91), track_err);
    else
      track_err_max91 = pre(track_err_max91);
    end if;
  end when;

  annotation (
    experiment(StartTime=0, StopTime=14, Tolerance=1e-6, Interval=0.005),
    Documentation(info="CartesianToolPolishD: 3-axis prismatic polishing plant with "
      "curved compliant workpiece, tangential tracking + normal-force admittance "
      "regulation, 200 Hz sampled controller, 7 N mid-third surface disturbance."));
end CartesianToolPolishD;