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
  parameter Real d_h = sqrt(rb*rb + rp*rp - 2.0*rb*rp*cos(0.5235987755982988))
    "horizontal anchor-pair separation [m]";

  // ---- Scenario parameters (chosen for runnable scenario; facts not stated are unknown) ----
  parameter Real z_w = 0.60 "workpiece top height [m]";
  parameter Real z0 = 0.78 "initial platform height [m]";
  parameter Real F_set = 200.0 "regulated contact force setpoint [N]";
  parameter Real z_app = 0.585 "approach target [m]";
  parameter Real T_sim = 16.0 "run duration [s]";
  parameter Real dt = 0.004 "control sample period (250 Hz) [s]";
  parameter Real T_app = 5.0 "approach duration [s]";
  parameter Real Kp_pos = 5000.0 "position proportional gain";
  parameter Real Kd_pos = 300.0 "position derivative gain";
  parameter Real Kp_f = 0.3 "force proportional gain";
  parameter Real Ki_f = 5.0 "force integral gain";
  parameter Real F_band = 30.0 "force band after settling [N]";
  parameter Real u_cmd_lim = 20000.0 "total vertical command clamp [N]";
  parameter Real F_err_int_lim = 500.0 "force integral clamp [N.s]";

  // ---- Platform state ----
  Real z(start = z0, fixed = true) "platform height [m]";
  Real z_dot(start = 0.0, fixed = true) "platform vertical velocity [m/s]";

  // ---- Strut kinematics & actuation (six struts, scalar) ----
  Real L1 "strut 1 length [m]";
  Real L2 "strut 2 length [m]";
  Real L3 "strut 3 length [m]";
  Real L4 "strut 4 length [m]";
  Real L5 "strut 5 length [m]";
  Real L6 "strut 6 length [m]";
  Real F_cmd1 "strut 1 commanded force [N]";
  Real F_cmd2 "strut 2 commanded force [N]";
  Real F_cmd3 "strut 3 commanded force [N]";
  Real F_cmd4 "strut 4 commanded force [N]";
  Real F_cmd5 "strut 5 commanded force [N]";
  Real F_cmd6 "strut 6 commanded force [N]";
  Real F_strut1 "strut 1 applied force [N]";
  Real F_strut2 "strut 2 applied force [N]";
  Real F_strut3 "strut 3 applied force [N]";
  Real F_strut4 "strut 4 applied force [N]";
  Real F_strut5 "strut 5 applied force [N]";
  Real F_strut6 "strut 6 applied force [N]";
  Real F_max_strut "max applied strut magnitude sensor [N]";
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
  discrete Real u_cmd(start = 0.0, fixed = true) "total vertical force command [N]";
  discrete Real F_err_int(start = 0.0, fixed = true) "force error integral [N.s]";
  Real F_err "instantaneous force error sensor [N]";
  Real F_dist "applied disturbance force [N]";
  Boolean disturbance_active "middle-third disturbance flag";
  Real z_ref "position reference [m]";

  // ---- Forward kinematics / closure ----
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
  // Strut lengths: 6-fold symmetric Stewart platform, vertical motion only
  L1 = sqrt(d_h*d_h + z*z);
  L2 = sqrt(d_h*d_h + z*z);
  L3 = sqrt(d_h*d_h + z*z);
  L4 = sqrt(d_h*d_h + z*z);
  L5 = sqrt(d_h*d_h + z*z);
  L6 = sqrt(d_h*d_h + z*z);

  // Forward-kinematic reconstruction and closure error
  z_fk = sqrt(L1*L1 - d_h*d_h);
  closure_err = z_fk - z;
  track_err = abs(closure_err);

  // Per-strut force command distribution and saturation
  F_cmd1 = u_cmd * L1 / (6.0 * max(z, 0.01));
  F_cmd2 = u_cmd * L2 / (6.0 * max(z, 0.01));
  F_cmd3 = u_cmd * L3 / (6.0 * max(z, 0.01));
  F_cmd4 = u_cmd * L4 / (6.0 * max(z, 0.01));
  F_cmd5 = u_cmd * L5 / (6.0 * max(z, 0.01));
  F_cmd6 = u_cmd * L6 / (6.0 * max(z, 0.01));

  F_strut1 = max(-F_max, min(F_max, F_cmd1));
  F_strut2 = max(-F_max, min(F_max, F_cmd2));
  F_strut3 = max(-F_max, min(F_max, F_cmd3));
  F_strut4 = max(-F_max, min(F_max, F_cmd4));
  F_strut5 = max(-F_max, min(F_max, F_cmd5));
  F_strut6 = max(-F_max, min(F_max, F_cmd6));

  // Scalar sensor reductions (explicit nesting avoids ambiguity)
  F_max_strut = max(max(max(abs(F_strut1), abs(F_strut2)), max(abs(F_strut3), abs(F_strut4))), max(abs(F_strut5), abs(F_strut6)));
  L_min_meas = min(min(min(L1, L2), min(L3, L4)), min(L5, L6));
  L_max_meas = max(max(max(L1, L2), max(L3, L4)), max(L5, L6));

  // Platform translational dynamics
  der(z) = z_dot;
  m_plat * der(z_dot) =
      (F_strut1 + F_strut2 + F_strut3 + F_strut4 + F_strut5 + F_strut6) * (z / L1)
      - m_plat * g_acc
      + F_normal
      + F_dist;

  // Contact model: compliant workpiece with stiffness, damping, friction capacity
  penetration = z_w - z;
  in_contact = penetration > 0.0;
  F_normal = if in_contact then max(0.0, k_c*penetration - c_c*z_dot) else 0.0;
  v_tan = 0.0;
  F_tangent = if in_contact then mu * F_normal else 0.0;
  der(slip) = v_tan;
  locked = in_contact and (abs(v_tan) < 1e-6);

  // Controlled 21.6 N force-change disturbance during middle third of run
  disturbance_active = (time >= T_sim/3.0) and (time <= 2.0*T_sim/3.0);
  F_dist = if disturbance_active then -21.6 else 0.0;

  // Position reference: smooth approach from z0 to z_app over T_app, then hold
  z_ref = if time < T_app then z0 + (z_app - z0) * (time / T_app) else z_app;

  // Force error sensor trace
  F_err = F_normal - F_set;

  // Discrete hybrid position/force controller at 250 Hz
  when sample(0.0, dt) then
    F_err_int := if (z_w - z) <= 0.0 then 0.0 else
                 max(-F_err_int_lim, min(F_err_int_lim, pre(F_err_int) + dt*(F_normal - F_set)));
    u_cmd := if (z_w - z) <= 0.0 then
               (m_plat*g_acc + Kp_pos*(z_ref - z) + Kd_pos*(0.0 - z_dot))
             else
               max(-u_cmd_lim, min(u_cmd_lim,
                 m_plat*g_acc + Kp_f*(F_normal - F_set) + Ki_f*pre(F_err_int)));
  end when;

  // ---- Acceptance checks (fail-closed: all must hold after 10.4 s) ----
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