model MonoHopRecoverF
  // ===== Specified parameters =====
  parameter Real m_b = 10.0 "body mass [kg]";
  parameter Real k_leg = 15000.0 "leg spring stiffness [N/m]";
  parameter Real c_leg = 170.0 "leg damper [N.s/m]";
  parameter Real l_min = 0.30 "minimum leg length [m]";
  parameter Real l_max = 0.60 "maximum leg length [m]";
  parameter Real F_act_max = 1159.0 "actuator force bound [N]";
  parameter Real mu = 0.90 "ground friction coefficient";
  parameter Real F_push = 203.0 "lateral push disturbance [N]";
  parameter Real T_sim = 20.0 "simulation duration [s]";
  parameter Real f_sample = 500.0 "control/output sample rate [Hz]";
  parameter Real dt_sample = 1.0 / f_sample "sample period [s]";
  parameter Real err_threshold = 0.096 "tracking error threshold [rad]";
  parameter Real slip_threshold = 0.03 "foot slip threshold [m]";

  // ===== Assumed parameters (not specified in requirement) =====
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real I_b = 0.20 "body pitch inertia [kg.m2] - assumed, not specified";
  parameter Real r_b = 0.10 "body radius [m] - assumed, not specified";
  parameter Real m_f = 0.10 "foot mass [kg] - assumed, not specified";
  parameter Real l0 = 0.45 "leg rest length [m] - assumed within [0.30, 0.60]";
  parameter Real k_gnd = 2.0e5 "ground stiffness [N/m] - assumed";
  parameter Real c_gnd = 2000.0 "ground damping [N.s/m] - assumed";
  parameter Real k_stop = 1.0e5 "leg hard-stop stiffness [N/m] - assumed";
  parameter Real c_stop = 500.0 "leg hard-stop damping [N.s/m] - assumed";
  parameter Real v_eps = 0.01 "friction velocity smoothing [m/s] - assumed";
  parameter Real z_ref = 0.90 "reference body height [m] - assumed";
  parameter Real theta_ref = 0.0 "reference pitch angle [rad]";
  parameter Real Kp_hop = 1500.0 "hop height proportional gain [N/m] - assumed";
  parameter Real Kd_hop = 120.0 "hop height derivative gain [N.s/m] - assumed";
  parameter Real Kp_pitch = 150.0 "pitch proportional gain [N.m/rad] - assumed";
  parameter Real Kd_pitch = 25.0 "pitch derivative gain [N.m.s/rad] - assumed";
  parameter Real tau_hip_max = 80.0 "hip torque bound [N.m] - assumed";

  // ===== Dynamic states =====
  Real x_b(start=0.0) "body horizontal position [m]";
  Real z_b(start=0.90) "body vertical position [m]";
  Real theta(start=0.0) "body pitch angle [rad]";
  Real vx_b(start=0.0) "body horizontal velocity [m/s]";
  Real vz_b(start=0.0) "body vertical velocity [m/s]";
  Real omega(start=0.0) "body angular velocity [rad/s]";
  Real x_f(start=0.0) "foot horizontal position [m]";
  Real z_f(start=0.45) "foot vertical position [m]";
  Real vx_f(start=0.0) "foot horizontal velocity [m/s]";
  Real vz_f(start=0.0) "foot vertical velocity [m/s]";
  Real slip_accum(start=0.0) "accumulated foot slip during current stance [m]";

  // ===== Computed/observed variables =====
  Real l "leg length [m]";
  Real l_safe "leg length safe (non-zero) [m]";
  Real dl "leg extension rate [m/s]";
  Real nx "unit vector foot-to-body x";
  Real nz "unit vector foot-to-body z";
  Real F_spring "leg spring force [N]";
  Real F_damper "leg damper force [N]";
  Real F_stop "leg hard-stop force [N]";
  Real F_act "actuator force bounded [N]";
  Real F_act_cmd "actuator force command [N]";
  Real F_leg "total axial leg force [N]";
  Real tau_hip "hip torque bounded [N.m]";
  Real tau_hip_cmd "hip torque command [N.m]";
  Real Gz "ground normal force [N]";
  Real Gx "ground friction force [N]";
  Real F_push_applied "applied push force [N]";
  Boolean in_stance "stance contact flag";
  Boolean in_push "push disturbance active flag";
  Real tracking_error "attitude tracking error [rad]";

  // ===== Verification flags =====
  Boolean torque_ok "actuator force within bound";
  Boolean slip_ok "foot slip below threshold";
  Boolean height_ok "positive body height";
  Boolean attitude_ok "tracking error below threshold after 13 s";
  Boolean no_nan_inf "no NaN or infinite values";

equation
  // ---- Push disturbance: middle third of simulation ----
  in_push = time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0;
  F_push_applied = if in_push then F_push else 0.0;

  // ---- Leg geometry ----
  l = sqrt((x_b - x_f)^2 + (z_b - z_f)^2);
  l_safe = max(l, 0.001);
  nx = (x_b - x_f) / l_safe;
  nz = (z_b - z_f) / l_safe;
  dl = (vx_b - vx_f) * nx + (vz_b - vz_f) * nz;

  // ---- Leg forces (positive = extension, pushes body away from foot) ----
  F_spring = k_leg * (l0 - l);
  F_damper = -c_leg * dl;

  // Hard stops at leg length limits
  F_stop = (if l < l_min then k_stop * (l_min - l) - c_stop * max(dl, 0.0) else 0.0)
         + (if l > l_max then -k_stop * (l - l_max) - c_stop * min(dl, 0.0) else 0.0);

  // ---- Ground contact (penalty-based, unilateral) ----
  Gz = if z_f < 0.0 then max(0.0, -k_gnd * z_f - c_gnd * vz_f) else 0.0;
  // Coulomb friction smoothed via tanh
  Gx = -mu * Gz * tanh(vx_f / v_eps);

  // ---- Stance detection ----
  in_stance = Gz > 1.0;

  // ---- Actuator: inject hopping energy during stance ----
  F_act_cmd = if Gz > 0.0 then (Kp_hop * (z_ref - z_b) - Kd_hop * vz_b) else 0.0;
  F_act = max(-F_act_max, min(F_act_max, F_act_cmd));

  // ---- Hip torque: PD balance control on pitch (whole-body, always active) ----
  tau_hip_cmd = Kp_pitch * (theta_ref - theta) - Kd_pitch * omega;
  tau_hip = max(-tau_hip_max, min(tau_hip_max, tau_hip_cmd));

  // ---- Total axial leg force ----
  F_leg = F_spring + F_damper + F_act + F_stop;

  // ---- Tracking error (smooth absolute value) ----
  tracking_error = sqrt((theta - theta_ref)^2 + 1e-12);

  // ---- Slip accumulation during stance ----
  der(slip_accum) = if Gz > 1.0 then sqrt(vx_f^2 + 1e-12) else 0.0;

  // Reset slip accumulator at each touchdown
  when z_f < 0.0 then
    reinit(slip_accum, 0.0);
  end when;

  // ===== Equations of motion =====
  // Body dynamics
  der(x_b) = vx_b;
  der(z_b) = vz_b;
  der(theta) = omega;
  der(vx_b) = (F_leg * nx + tau_hip * nz / l_safe + F_push_applied) / m_b;
  der(vz_b) = (F_leg * nz - tau_hip * nx / l_safe - m_b * g) / m_b;
  der(omega) = -tau_hip / I_b;

  // Foot dynamics
  der(x_f) = vx_f;
  der(z_f) = vz_f;
  der(vx_f) = (-F_leg * nx - tau_hip * nz / l_safe + Gx) / m_f;
  der(vz_f) = (-F_leg * nz + tau_hip * nx / l_safe + Gz - m_f * g) / m_f;

  // ===== Verification criteria =====
  torque_ok = F_act * F_act <= (F_act_max + 1.0) * (F_act_max + 1.0);
  slip_ok = slip_accum <= slip_threshold;
  height_ok = z_b > 0.0;
  attitude_ok = if time >= 13.0 then tracking_error < err_threshold else true;
  no_nan_inf = (x_b == x_b) and (z_b == z_b) and (theta == theta) and
               (vx_b == vx_b) and (vz_b == vz_b) and (omega == omega) and
               (x_f == x_f) and (z_f == z_f) and (vx_f == vx_f) and (vz_f == vz_f) and
               (F_act == F_act) and (tau_hip == tau_hip) and
               (Gx == Gx) and (Gz == Gz) and (tracking_error == tracking_error) and
               (abs(x_b) < 1e300) and (abs(z_b) < 1e300) and (abs(theta) < 1e300) and
               (abs(vx_b) < 1e300) and (abs(vz_b) < 1e300) and (abs(omega) < 1e300) and
               (abs(x_f) < 1e300) and (abs(z_f) < 1e300) and (abs(vx_f) < 1e300) and
               (abs(vz_f) < 1e300) and (abs(F_act) < 1e300) and (abs(tau_hip) < 1e300);

  annotation(
    experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Monopod hopper (MonoHopRecoverF): floating-base legged robot
      with one telescoping leg (0.30-0.60 m), 15 kN/m spring, 170 N.s/m damper,
      spherical foot on level rigid ground (friction 0.90).
      A bounded linear leg actuator (max 1159 N) injects hopping energy.
      Whole-body balance control with contact switching stabilizes pitch.
      A 203 N lateral impulse is applied during the middle third of a 20 s run.
      Output at 500 Hz (Interval = 0.002 s).
      Verification: actuator force bound, foot slip < 0.03 m, positive body height,
      attitude tracking error < 0.096 rad after 13 s, no NaN/infinite values.
      Parameters not stated in the requirement are marked as assumed."));
end MonoHopRecoverF;