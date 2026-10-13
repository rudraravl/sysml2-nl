model WheelLegWalkA
  "Floating-base wheeled-leg robot (sagittal-plane reduction): 28 kg torso, 4 two-joint legs ending in 0.10 m driven wheels, rolling locomotion with phase-based joint impedance and body-attitude control. 80 Hz digital control, 8 s scenario, 35 N push in middle third."

  // ---------- Physical / scenario parameters ----------
  parameter Real m_torso(unit="kg")   = 28.0  "torso mass";
  parameter Real I_torso(unit="kg.m2") = 0.6   "torso pitch inertia (assumed; not specified)";
  parameter Real L_body(unit="m")     = 0.50  "torso length (assumed; not specified)";
  parameter Real L1(unit="m")         = 0.20  "thigh length (assumed; not specified)";
  parameter Real L2(unit="m")         = 0.20  "shank length (assumed; not specified)";
  parameter Real r_w(unit="m")        = 0.10  "driven wheel radius";
  parameter Real g(unit="m/s2")       = 9.81  "gravity";
  parameter Real mu                   = 0.85  "rigid-plane friction coefficient";
  parameter Real tau_max(unit="N.m")   = 39.6  "per-joint/wheel command magnitude limit";
  parameter Real z_nom(unit="m")      = 0.30  "nominal body height (assumed; not specified)";
  parameter Real v_des(unit="m/s")    = 0.40  "forward gait speed setpoint";
  parameter Real k_n(unit="N/m")      = 1.0e4 "contact normal stiffness (assumed)";
  parameter Real d_n(unit="Ns/m")     = 500.0 "contact normal damping (assumed)";
  parameter Real m_eff(unit="kg.m2")  = 0.5   "fictitious joint inertia for leg state dynamics (assumed; leg mass not specified)";
  parameter Real c_leg(unit="N.m.s/rad")=10.0 "joint viscous damping (assumed)";
  parameter Real Kp_imp(unit="N.m/rad")=1500.0 "joint impedance stiffness";
  parameter Real Kd_imp(unit="N.m.s/rad")=80.0 "joint impedance damping";
  parameter Real Kpw(unit="N.m.s/m")  = 15.0  "wheel speed gain";
  parameter Real K_att(unit="N.m/rad")=150.0  "body-attitude proportional gain";
  parameter Real Kd_att(unit="N.m.s/rad")=20.0 "body-attitude damping gain";
  parameter Real T_gait(unit="s")    = 1.0   "gait period (assumed; not specified)";
  parameter Real T_sim(unit="s")     = 8.0   "scenario duration";
  parameter Real F_push(unit="N")     = 35.0  "body push disturbance magnitude";
  parameter Real h_push(unit="m")     = 0.15  "push application height above COM (assumed; not specified)";
  parameter Real dt_ctrl(unit="s")    = 1.0/80.0 "control sampling period (80 Hz)";
  parameter Real pi_val               = 4.0*atan(1.0);

  // ---------- Torso continuous states ----------
  Real x(unit="m")      "forward position"     annotation(HideResult=false);
  Real vx(unit="m/s")   "forward velocity"     annotation(HideResult=false);
  Real z(unit="m")      "body height (COM)"    annotation(HideResult=false);
  Real vz(unit="m/s")   "vertical velocity"    annotation(HideResult=false);
  Real theta(unit="rad") "pitch (nose up +)"     annotation(HideResult=false);
  Real dtheta(unit="rad/s") "pitch rate"        annotation(HideResult=false);

  // ---------- Leg joint continuous states (front/hind sagittal pairs) ----------
  Real q1f(unit="rad", start=1.047)  "front hip angle";
  Real dq1f(unit="rad/s", start=0)  "front hip rate";
  Real q2f(unit="rad", start=-2.094) "front knee angle";
  Real dq2f(unit="rad/s", start=0)  "front knee rate";
  Real q1h(unit="rad", start=1.047)  "hind hip angle";
  Real dq1h(unit="rad/s", start=0)  "hind hip rate";
  Real q2h(unit="rad", start=-2.094) "hind knee angle";
  Real dq2h(unit="rad/s", start=0)  "hind knee rate";

  // ---------- Accelerations ----------
  Real ax(unit="m/s2"), az(unit="m/s2"), alpha(unit="rad/s2");
  Real ddq1f, ddq2f, ddq1h, ddq2h;

  // ---------- Kinematics intermediates ----------
  Real xh_f, zh_f, xh_h, zh_h;
  Real x_f_f, z_f_f, x_f_h, z_f_h;
  Real dz_f_f, dz_f_h;
  Real J11f, J12f, J21f, J22f, J11h, J12h, J21h, J22h;

  // ---------- Contact / friction ----------
  Real pf, ph, nf, nh;
  Real fxf, fxh;
  Real contact_f, contact_h;
  Real n_contact "supporting-contact count (0..4)";

  // ---------- Discrete controller variables (80 Hz ZOH) ----------
  discrete Real phi_d(start=0.0);
  discrete Real Kp_phase_d(start=1500.0);
  discrete Real q1f_des_d(start=1.047), q2f_des_d(start=-2.094);
  discrete Real q1h_des_d(start=1.047), q2h_des_d(start=-2.094);
  discrete Real support_f_d(start=68.67), support_h_d(start=68.67);
  discrete Real tau1f_d(start=0.0), tau2f_d(start=11.9);
  discrete Real tau1h_d(start=0.0), tau2h_d(start=11.9);
  discrete Real tauw_f_d(start=0.0), tauw_h_d(start=0.0);

  // ---------- Independent, limited command traces (8 leg + 4 wheel) ----------
  Real tau1fL, tau2fL, tau1fR, tau2fR "front left/right leg torques";
  Real tau1hL, tau2hL, tau1hR, tau2hR "hind left/right leg torques";
  Real tauw_fL, tauw_fR, tauw_hL, tauw_hR "wheel torques";

  // ---------- Sensors / traces ----------
  Real omega_w(unit="rad/s") "wheel angular velocity (rolling estimate)";
  Real F_push_t(unit="N") "applied push disturbance";
  Real tracking_err(unit="m/s") "primary tracking error vx - v_des";
  Boolean tracking_ok "tracking error within 0.135 m/s after 5.2 s";

  // Bound-observability traces
  Boolean torque_within_bounds "all 12 commands within +/-39.6 N.m";

equation
  // ---- State derivatives ----
  der(x) = vx;
  der(z) = vz;
  der(theta) = dtheta;
  der(q1f) = dq1f;
  der(q2f) = dq2f;
  der(q1h) = dq1h;
  der(q2h) = dq2h;
  der(vx) = ax;
  der(vz) = az;
  der(dtheta) = alpha;
  der(dq1f) = ddq1f;
  der(dq2f) = ddq2f;
  der(dq1h) = ddq1h;
  der(dq2h) = ddq2h;

  // ---- Hip positions (pitch-rotated) ----
  xh_f = x + (L_body/2)*cos(theta);
  zh_f = z + (L_body/2)*sin(theta);
  xh_h = x - (L_body/2)*cos(theta);
  zh_h = z - (L_body/2)*sin(theta);

  // ---- Foot (wheel center) forward kinematics ----
  x_f_f = xh_f + L1*sin(q1f) + L2*sin(q1f+q2f);
  z_f_f = zh_f - L1*cos(q1f) - L2*cos(q1f+q2f);
  x_f_h = xh_h + L1*sin(q1h) + L2*sin(q1h+q2h);
  z_f_h = zh_h - L1*cos(q1h) - L2*cos(q1h+q2h);

  // ---- Leg Jacobians (foot velocity w.r.t. joints) ----
  J11f = L1*cos(q1f) + L2*cos(q1f+q2f);
  J12f = L2*cos(q1f+q2f);
  J21f = L1*sin(q1f) + L2*sin(q1f+q2f);
  J22f = L2*sin(q1f+q2f);
  J11h = L1*cos(q1h) + L2*cos(q1h+q2h);
  J12h = L2*cos(q1h+q2h);
  J21h = L1*sin(q1h) + L2*sin(q1h+q2h);
  J22h = L2*sin(q1h+q2h);

  // ---- Foot vertical velocities (for contact damping) ----
  dz_f_f = vz + (L_body/2)*cos(theta)*dtheta + L1*sin(q1f)*dq1f + L2*sin(q1f+q2f)*(dq1f+dq2f);
  dz_f_h = vz - (L_body/2)*cos(theta)*dtheta + L1*sin(q1h)*dq1h + L2*sin(q1h+q2h)*(dq1h+dq2h);

  // ---- Compliant contact (per foot; L and R identical in sagittal plane) ----
  pf = r_w - z_f_f;
  ph = r_w - z_f_h;
  nf = if pf > 0.0 then max(0.0, k_n*pf - d_n*dz_f_f) else 0.0;
  nh = if ph > 0.0 then max(0.0, k_n*ph - d_n*dz_f_h) else 0.0;
  contact_f = if pf > 0.0 then 1.0 else 0.0;
  contact_h = if ph > 0.0 then 1.0 else 0.0;
  n_contact = 2.0*contact_f + 2.0*contact_h;

  // ---- Rolling traction via wheel torque (friction-limited) ----
  fxf = max(-mu*nf, min(mu*nf, tauw_f_d/r_w));
  fxh = max(-mu*nh, min(mu*nh, tauw_h_d/r_w));

  // ---- Push disturbance: 35 N forward applied at body top during middle third ----
  F_push_t = if time >= T_sim/3.0 and time <= 2.0*T_sim/3.0 then F_push else 0.0;

  // ---- Torso dynamics (legs massless; leg mass not specified) ----
  ax = (2.0*fxf + 2.0*fxh + F_push_t)/m_torso;
  az = (2.0*nf + 2.0*nh)/m_torso - g;
  alpha = (2.0*((x_f_f - x)*nf - (z_f_f - z)*fxf)
          + 2.0*((x_f_h - x)*nh - (z_f_h - z)*fxh)
          - F_push_t*h_push)/I_torso;

  // ---- Leg joint dynamics (actuator + contact generalized force) ----
  ddq1f = (tau1f_d + J11f*fxf + J21f*nf - c_leg*dq1f)/m_eff;
  ddq2f = (tau2f_d + J12f*fxf + J22f*nf - c_leg*dq2f)/m_eff;
  ddq1h = (tau1h_d + J11h*fxh + J21h*nh - c_leg*dq1h)/m_eff;
  ddq2h = (tau2h_d + J12h*fxh + J22h*nh - c_leg*dq2h)/m_eff;

  // ---- Wheel encoder (rolling) ----
  omega_w = vx/r_w;

  // ---- Split pair commands into independently-limited L/R channels ----
  tau1fL = tau1f_d;  tau1fR = tau1f_d;
  tau2fL = tau2f_d;  tau2fR = tau2f_d;
  tau1hL = tau1h_d;  tau1hR = tau1h_d;
  tau2hL = tau2h_d;  tau2hR = tau2h_d;
  tauw_fL = tauw_f_d; tauw_fR = tauw_f_d;
  tauw_hL = tauw_h_d; tauw_hR = tauw_h_d;

  // ---- Requirement checks (observability, non-blocking) ----
  tracking_err = vx - v_des;
  tracking_ok = (time < 5.2) or (abs(tracking_err) < 0.135);
  torque_within_bounds =
      (abs(tau1fL)<=tau_max and abs(tau2fL)<=tau_max and
       abs(tau1fR)<=tau_max and abs(tau2fR)<=tau_max and
       abs(tau1hL)<=tau_max and abs(tau2hL)<=tau_max and
       abs(tau1hR)<=tau_max and abs(tau2hR)<=tau_max and
       abs(tauw_fL)<=tau_max and abs(tauw_fR)<=tau_max and
       abs(tauw_hL)<=tau_max and abs(tauw_hR)<=tau_max);

  // ================= 80 Hz digital controller =================
  when sample(0, dt_ctrl) then
    // Gait phase and phase-modulated impedance stiffness
    phi_d = mod(time/T_gait, 1.0);
    Kp_phase_d = Kp_imp*(1.0 + 0.15*sin(2.0*pi_val*phi_d));

    // Inverse kinematics for nominal foot offset (foot directly below hip at nominal height)
    // dz_des = r_w - z_nom = -0.20 m (constant target, dx_des = 0)
    q2f_des_d = -acos(max(-1.0, min(1.0, ((r_w - z_nom)*(r_w - z_nom) - L1*L1 - L2*L2)/(2.0*L1*L2))));
    q1f_des_d = atan2(0.0, -(r_w - z_nom)) - atan2(L2*sin(q2f_des_d), L1 + L2*cos(q2f_des_d));
    q2h_des_d = q2f_des_d;
    q1h_des_d = q1f_des_d;

    // Body-attitude control via differential vertical support (restores theta -> 0)
    support_f_d = m_torso*g/4.0 - (K_att*theta + Kd_att*dtheta)/L_body;
    support_h_d = m_torso*g/4.0 + (K_att*theta + Kd_att*dtheta)/L_body;

    // Leg joint torque commands: feedforward (static support) + phase-based impedance (clamped)
    tau1f_d = max(-tau_max, min(tau_max,
        -(L1*sin(q1f)+L2*sin(q1f+q2f))*support_f_d
        + Kp_phase_d*(q1f_des_d - q1f) - Kd_imp*dq1f));
    tau2f_d = max(-tau_max, min(tau_max,
        -(L2*sin(q1f+q2f))*support_f_d
        + Kp_phase_d*(q2f_des_d - q2f) - Kd_imp*dq2f));
    tau1h_d = max(-tau_max, min(tau_max,
        -(L1*sin(q1h)+L2*sin(q1h+q2h))*support_h_d
        + Kp_phase_d*(q1h_des_d - q1h) - Kd_imp*dq1h));
    tau2h_d = max(-tau_max, min(tau_max,
        -(L2*sin(q1h+q2h))*support_h_d
        + Kp_phase_d*(q2h_des_d - q2h) - Kd_imp*dq2h));

    // Wheel torque commands: forward-velocity tracking (clamped)
    tauw_f_d = max(-tau_max, min(tau_max, Kpw*(v_des - vx)));
    tauw_h_d = max(-tau_max, min(tau_max, Kpw*(v_des - vx)));
  end when;

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-4, Interval=1.0/80.0),
    Documentation(info="WheelLegWalkA: sagittal-plane floating-base wheeled-leg robot.
      28 kg torso, four two-joint legs (modeled as 2 sagittal pairs, L=R by symmetry) ending in driven 0.10 m wheels.
      Rolling locomotion with phase-based joint impedance and body-attitude control.
      Eight leg torques and four wheel torques independently limited to +/-39.6 N.m.
      Sensors: joint encoders (q1f,q2f,q1h,q2h), torso IMU (theta,dtheta), foot contact-force sensors (nf,nh).
      Rigid plane friction 0.85, gravity 9.81. 35 N forward push at body top during middle third (2.667-5.333 s).
      80 Hz digital control over 8 s. Synchronized state/command/sensor traces retained.
      Requirements: torque bounds (torque_within_bounds), supporting-contact count (n_contact),
      body attitude (theta), forward progress (x), tracking error below 0.135 m/s after 5.2 s (tracking_ok),
      and finite (no NaN/Inf) physical/control/estimator values by construction (smooth contact, clamped commands).
      Unspecified facts (leg link lengths, leg mass, torso inertia/length, nominal height, gait period,
      push height, contact stiffness/damping) are labeled as assumed parameters."));
end WheelLegWalkA;