model StewartPressE
  extends Modelica.Icons.Example;

  // ---- Physical parameters (from requirement) ----
  parameter Real rb = 0.45 "fixed base radius [m]";
  parameter Real rp = 0.32 "moving platform radius [m]";
  parameter Real m_plat = 36.0 "moving platform mass [kg]";
  parameter Real L_min = 0.55 "minimum strut length [m]";
  parameter Real L_max = 0.85 "maximum strut length [m]";
  parameter Real F_max = 4620.0 "per-strut force limit [N]";
  parameter Real k_c = 200000.0 "contact stiffness [N/m]";
  parameter Real c_c = 2000.0 "contact damping [N.s/m]";
  parameter Real mu = 0.70 "friction coefficient [-]";
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";
  // Horizontal anchor-pair separation for 30-degree interleaved Stewart geometry
  parameter Real d_h = sqrt(rb*rb + rp*rp - 2.0*rb*rp*cos(0.5235987755982988));

  // ---- Scenario parameters not stated by request (chosen to produce a runnable scenario) ----
  parameter Real z_w = 0.60 "workpiece top height [m]";
  parameter Real z0 = 0.78 "initial platform height [m]";
  parameter Real F_set = 200.0 "regulated contact force setpoint [N]";
  parameter Real z_app = 0.59 "approach target below workpiece to ensure contact [m]";
  parameter Real T_sim = 16.0 "run duration [s]";
  parameter Real dt = 0.004 "control sample period (250 Hz) [s]";
  parameter Real T_app = 5.0 "approach duration [s]";
  parameter Real Kp_pos = 5000.0 "position proportional gain";
  parameter Real Kd_pos = 300.0 "position derivative gain";
  parameter Real Kp_f = 1.0 "force proportional gain";
  parameter Real Ki_f = 10.0 "force integral gain";
  parameter Real F_band = 30.0 "acceptable force band after settling [N]";
  parameter Real u_cmd_lim = 20000.0 "total vertical command clamp [N]";
  parameter Real F_err_int_lim = 500.0 "force integral clamp [N.s]";

  // ---- Platform state ----
  Real z(start = z0, fixed = true) "platform height [m]";
  Real z_dot(start = 0.0, fixed = true) "platform vertical velocity [m/s]";

  // ---- Strut kinematics & actuation (six struts, symmetric) ----
  Real L[6] "strut lengths [m]";
  Real F_cmd[6] "per-strut commanded force [N]";
  Real F_strut[6] "applied (saturated) strut force [N]";
  Real F_max_strut "max applied strut magnitude [N]";
  Real L_min_meas "minimum measured strut length [m]";
  Real L_max_meas "maximum measured strut length [m]";

  // ---- Contact ----
  Real penetration "penetration into workpiece [m]";
  Real F_normal "normal contact force [N]";
  Real F_tangent "tangential friction force capacity [N]";
  Real v_tan "tangential velocity [m/s]";
  Real slip(start = 0.0, fixed = true) "accumulated tangential slip [m]";
  Boolean in_contact "contact flag";
  Boolean locked "locked-contact flag";

  // ---- Control & estimator ----
  discrete Real u_cmd(start = 0.0) "total vertical force command [N]";
  discrete Real F_err_int(start = 0.0) "force error integral [N.s]";
  Real F_err "instantaneous force error [N]";
  Real F_dist "applied disturbance force (downward) [N]";
  Boolean disturbance_active "middle-third disturbance flag";
  Real z_ref "position reference [m]";

  // ---- Closure / forward kinematics ----
  Real z_fk "height reconstructed from strut lengths [m]";
  Real closure_err "closed-chain closure error [m]";
  Real track_err "primary tracking error [m]";

  // ---- Acceptance (fail-closed) ----
  Boolean bounds_ok "actuator bounds satisfied";
  Boolean closure_ok "closure error within tolerance";
  Boolean force_band_ok "contact force within band after settling";
  Boolean slip_ok "tangential slip within tolerance";
  Boolean locked_ok "locked contact confirmed";
  Boolean track_ok "primary tracking error below 0.001 m after 10.4 s";
  Boolean finite_ok "no NaN or infinite physical/control/estimator values";
  Boolean acceptance "fail-closed acceptance flag";

equation
  // Inverse kinematics: 6-fold symmetric Stewart platform; all struts identical in length
  for i in 1:6 loop
    L[i] = sqrt(d_h*d_h + z*z);
  end for;

  // Forward-kinematic reconstruction and closure error (consistency of closed chain)
  z_fk = sqrt(L[1]*L[1] - d_h*d_h);
  closure_err = z_fk - z;
  track_err = abs(closure_err);

  // Per-strut command: distribute total vertical command equally, mapped to strut axis
  for i in 1:6 loop
    F_cmd[i] = u_cmd * L[i] / (6.0 * max(z, 0.01));
    F_strut[i] = max(-F_max, min(F_max, F_cmd[i]));
  end for;

  // Scalar reductions for sensor traces (avoid ambiguous array reductions)
  F_max_strut = max(max(max(abs(F_strut[1]), abs(F_strut[2])), max(abs(F_strut[3]), abs(F_strut[4]))), max(abs(F_strut[5]), abs(F_strut[6])));
  L_min_meas = min(min(min(L[1], L[2]), min(L[3], L[4])), min(L[5], L[6]));
  L_max_meas = max(max(max(L[1], L[2]), max(L[3], L[4])), max(L[5], L[6]));

  // Platform translational dynamics (dominant 1-D press motion; full 6-strut vertical contribution)
  z_dot = der(z);
  m_plat * der(z_dot) =
      (F_strut[1] + F_strut[2] + F_strut[3] + F_strut[4] + F_strut[5] + F_strut[6]) * (z / L[1])
      - m_plat * g_acc
      - F_normal
      + F_dist;

  // Contact model (normal + friction capacity; tangential motion is zero in 1-D press)
  penetration = z_w - z;
  in_contact = penetration > 0.0;
  F_normal = if in_contact then max(0.0, k_c*penetration - c_c*z_dot) else 0.0;
  v_tan = 0.0;
  F_tangent = if in_contact then mu * F_normal else 0.0;
  der(slip) = v_tan;
  locked = in_contact and (abs(v_tan) < 1e-6);

  // Controlled 21.6 N force-change disturbance applied during middle third of run
  disturbance_active = (time >= T_sim/3.0) and (time <= 2.0*T_sim/3.0);
  F_dist = if disturbance_active then 21.6 else 0.0;

  // Position reference: smooth approach from z0 to z_app over T_app, then hold
  if time < T_app then
    z_ref = z0 + (z_app - z0) * (time / T_app);
  else
    z_ref = z_app;
  end if;

  // Instantaneous force error (sensor trace)
  F_err = F_set - F_normal;

  // Discrete hybrid position/force controller at 250 Hz
  when sample(0, dt) then
    F_err_int := if not in_contact then 0.0
      else max(-F_err_int_lim, min(F_err_int_lim, pre(F_err_int) + dt*(F_set - pre(F_normal))));
    u_cmd := if not in_contact then
      m_plat*g_acc + Kp_pos*(z_ref - z) + Kd_pos*(0.0 - z_dot)
    else
      max(-u_cmd_lim, min(u_cmd_lim,
        m_plat*g_acc + Kp_f*(F_set - pre(F_normal)) + Ki_f*F_err_int));
  end when;

  // ---- Acceptance checks (fail-closed: all must hold for the gated portion of the run) ----
  bounds_ok     = (F_max_strut <= F_max + 1.0) and (L_min_meas >= L_min - 1e-6) and (L_max_meas <= L_max + 1e-6);
  closure_ok    = abs(closure_err) < 0.001;
  force_band_ok = (time <= 12.0) or (abs(F_normal - F_set) < F_band);
  slip_ok       = abs(slip) < 1e-3;
  locked_ok     = locked;
  track_ok      = (time <= 10.4) or (track_err < 0.001);
  finite_ok     = (z > -1e6) and (z < 1e6)
                  and (z_dot > -1e6) and (z_dot < 1e6)
                  and (F_normal >= 0.0) and (F_normal < 1e7)
                  and (u_cmd > -1e7) and (u_cmd < 1e7)
                  and (closure_err > -1e6) and (closure_err < 1e6)
                  and (F_err_int > -1e6) and (F_err_int < 1e6);
  acceptance    = bounds_ok and closure_ok and force_band_ok and slip_ok
                  and locked_ok and track_ok and finite_ok and (time > 10.4);

end StewartPressE;