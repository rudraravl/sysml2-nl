model MonoHopRecoverE
  "Verifiable floating-base single-leg hopper: stand/step in place, recover from finite lateral impulse";

  // ===== Physical parameters (from requirement where stated) =====
  parameter Real m_b = 10.0 "body mass [kg]";
  parameter Real m_l = 1.5 "leg/foot lumped mass [kg] (assumed; leg mass not specified)";
  parameter Real I_b = 0.12 "body pitch inertia [kg.m2] (assumed; cylinder radius/height not specified)";
  parameter Real h_body = 0.30 "body height [m] (assumed; cylinder dimensions not specified)";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real k_leg = 15000.0 "leg spring stiffness [N/m]";
  parameter Real c_leg = 170.0 "leg damper coefficient [N.s/m]";
  parameter Real L_min = 0.30 "minimum leg length [m]";
  parameter Real L_max = 0.60 "maximum leg length [m]";
  parameter Real L0 = 0.50 "leg rest length [m] (assumed; chosen within stroke, not specified)";
  parameter Real F_act_max = 1045.0 "leg actuator force bound [N]";
  parameter Real mu = 0.90 "ground friction coefficient";
  parameter Real k_g = 2.0e5 "ground penalty stiffness [N/m] (assumed)";
  parameter Real c_g = 2.0e3 "ground penalty damping [N.s/m] (assumed)";
  parameter Real v_eps = 0.01 "friction regularization velocity [m/s] (assumed)";
  parameter Real k_lim = 2.0e5 "leg stroke limit stiffness [N/m] (assumed)";

  // ===== Controller / estimator parameters (assumed; not specified) =====
  parameter Real Ts = 0.004 "control sample time [s] (250 Hz)";
  parameter Real Kp_theta = 150.0 "attitude proportional gain (assumed)";
  parameter Real Kd_theta = 10.0 "attitude derivative gain (assumed)";
  parameter Real K_thrust = 10000.0 "stance hopping thrust gain (assumed)";
  parameter Real K_slip = 20.0 "anti-slip downforce gain (assumed)";
  parameter Real K_hold = 2000.0 "flight leg-hold position gain (assumed)";
  parameter Real C_hold = 200.0 "flight leg-hold damping gain (assumed)";
  parameter Real N_thresh = 20.0 "stance contact force threshold [N] (assumed)";
  parameter Real alpha_est = 0.05 "estimator complementary correction gain (assumed)";
  parameter Real tau_max = 120.0 "hip torque bound [N.m] (assumed; specific bound not specified)";

  // ===== Disturbance (168 N, finite duration, within middle third of run) =====
  parameter Real F_push = 168.0 "lateral push force magnitude [N]";
  parameter Real t_push_start = 8.0 "push start time [s] (assumed; within middle third [5.33,10.67] s of 16 s run)";
  parameter Real t_push_dur = 0.30 "push duration [s] (assumed finite)";

  // ===== Body states =====
  Real x_b(start=0.0) "body lateral position [m]";
  Real z_b(start=0.4935) "body height [m]";
  Real theta_b(start=0.0) "body pitch [rad]";
  Real x_b_dot(start=0.0) "body lateral velocity [m/s]";
  Real z_b_dot(start=0.0) "body vertical velocity [m/s]";
  Real theta_b_dot(start=0.0) "body pitch rate [rad/s]";

  // ===== Foot states =====
  Real x_f(start=0.0) "foot lateral position [m]";
  Real z_f(start=0.0) "foot vertical position [m]";
  Real x_f_dot(start=0.0) "foot lateral velocity [m/s]";
  Real z_f_dot(start=0.0) "foot vertical velocity [m/s]";

  // ===== Derived kinematics =====
  Real L "leg length [m]";
  Real L_dot "leg length rate [m/s]";
  Real phi "leg angle from vertical [rad]";
  Real sinphi "sine of leg angle from vertical";
  Real cosphi "cosine of leg angle from vertical";

  // ===== Forces / torques =====
  Real F_spring "leg spring force [N]";
  Real F_damp "leg damper force [N]";
  Real F_limit "leg stroke limit force [N]";
  Real F_act "leg actuator force [N]";
  Real F_leg "total axial leg force [N]";
  Real N "ground normal force [N]";
  Real Ff "ground friction force [N]";
  Real tau "applied hip torque [N.m]";
  Real F_dist "disturbance force [N]";

  // ===== Controller =====
  discrete Real F_act_cmd(start=0.0) "actuator command [N]";
  discrete Real tau_cmd(start=0.0) "torque command [N.m]";
  Real theta_b_des "desired body pitch [rad]";
  Real track_err "primary attitude tracking error [rad]";
  discrete Boolean in_stance(start=false) "force-qualified stance flag";

  // ===== Estimator (IMU + kinematics + force-qualified contacts) =====
  Real theta_hat(start=0.0) "estimated body pitch [rad]";
  Real theta_b_dot_hat(start=0.0) "estimated body pitch rate [rad/s]";
  Real z_b_hat(start=0.4935) "estimated body height [m]";
  Real x_b_hat(start=0.0) "estimated body lateral position [m]";

  // ===== Slip bookkeeping =====
  discrete Boolean was_stance(start=false);
  discrete Real x_f_td(start=0.0) "foot lateral position at touchdown [m]";
  discrete Real max_slip(start=0.0) "maximum per-stance foot slip [m]";
  Real stance_slip "current stance foot slip [m]";

  // ===== Acceptance monitors (fail-closed) =====
  Boolean height_ok "positive body height";
  Boolean attitude_recovered "attitude within recovery tolerance";
  Boolean tracking_ok "primary tracking error below 0.108 rad after 10.4 s";
  Boolean bounds_ok "torque and actuator within bounds";
  Boolean finite_ok "no NaN/infinite physical, control, or estimator values";
  Boolean slip_ok "foot slip below 0.03 m";

equation
  // ----- Leg geometry (foot relative to body) -----
  L = sqrt((x_f - x_b)^2 + (z_f - z_b)^2);
  L_dot = ((x_f - x_b)*(x_f_dot - x_b_dot) + (z_f - z_b)*(z_f_dot - z_b_dot)) / max(L, 1e-6);
  sinphi = (x_f - x_b) / max(L, 1e-6);
  cosphi = (z_b - z_f) / max(L, 1e-6);
  phi = Modelica.Math.atan2(x_f - x_b, z_b - z_f);

  // ----- Leg axial force: spring + damper + bounded actuator + stroke limits -----
  F_spring = k_leg*(L0 - L);
  F_damp = -c_leg*L_dot;
  F_limit = if L < L_min then k_lim*(L_min - L) elseif L > L_max then -k_lim*(L - L_max) else 0.0;
  F_act = F_act_cmd;
  F_leg = F_spring + F_damp + F_act + F_limit;

  // ----- Ground contact: penalty normal + regularized Coulomb friction -----
  N = if z_f < 0.0 then max(0.0, k_g*(-z_f) - c_g*z_f_dot) else 0.0;
  Ff = -mu * N * tanh(x_f_dot / v_eps);

  // ----- Disturbance: finite-duration lateral body push -----
  F_dist = if (time >= t_push_start and time < t_push_start + t_push_dur) then F_push else 0.0;

  // ----- Body dynamics -----
  der(x_b) = x_b_dot;
  der(z_b) = z_b_dot;
  der(theta_b) = theta_b_dot;
  m_b*der(x_b_dot) = -F_leg*sinphi - (tau/max(L,1e-6))*cosphi + F_dist;
  m_b*der(z_b_dot) = -m_b*g + F_leg*cosphi - (tau/max(L,1e-6))*sinphi;
  I_b*der(theta_b_dot) = tau - F_dist*(h_body/2);

  // ----- Foot (spherical foot) dynamics -----
  der(x_f) = x_f_dot;
  der(z_f) = z_f_dot;
  m_l*der(x_f_dot) = F_leg*sinphi + (tau/max(L,1e-6))*cosphi + Ff;
  m_l*der(z_f_dot) = -m_l*g - F_leg*cosphi + (tau/max(L,1e-6))*sinphi + N;

  // ----- Controller references -----
  theta_b_des = 0.0;
  track_err = abs(theta_b - theta_b_des);

  // ----- Sampled whole-body balance control + contact switching + slip bookkeeping (250 Hz) -----
  when sample(0, Ts) then
    in_stance = N > N_thresh;
    F_act_cmd = if in_stance then
                  max(-F_act_max, min(F_act_max, K_thrust*(L0 - L) + K_slip*abs(x_b_dot)))
                else
                  max(-F_act_max, min(F_act_max, K_hold*(L0 - L) - C_hold*L_dot));
    tau_cmd = Kp_theta*(theta_b_des - theta_hat) - Kd_theta*theta_b_dot_hat;
    if in_stance and not pre(was_stance) then
      was_stance = true;
      x_f_td = x_f;
      max_slip = pre(max_slip);
    elseif not in_stance and pre(was_stance) then
      was_stance = false;
      x_f_td = pre(x_f_td);
      max_slip = max(pre(max_slip), abs(x_f - pre(x_f_td)));
    else
      was_stance = pre(was_stance);
      x_f_td = pre(x_f_td);
      max_slip = pre(max_slip);
    end if;
  end when;

  // ----- Bounded hip torque -----
  tau = max(-tau_max, min(tau_max, tau_cmd));

  // ----- Estimator: gyro integration with stance-gated kinematic correction -----
  der(theta_hat) = theta_b_dot + (if in_stance then alpha_est*(theta_b - theta_hat) else 0.0);
  der(theta_b_dot_hat) = (theta_b_dot - theta_b_dot_hat)/0.02;
  der(z_b_hat) = z_b_dot + (if in_stance then alpha_est*(z_b - z_b_hat) else 0.0);
  der(x_b_hat) = x_b_dot + (if in_stance then alpha_est*(x_b - x_b_hat) else 0.0);

  // ----- Slip monitor (algebraic) -----
  stance_slip = if in_stance then abs(x_f - x_f_td) else 0.0;

  // ----- Acceptance monitors (fail-closed) -----
  height_ok = z_b > 0.0;
  attitude_recovered = abs(theta_b) < 0.25;
  tracking_ok = if time >= 10.4 then track_err < 0.108 else true;
  bounds_ok = (abs(tau) <= tau_max + 1e-6) and (abs(F_act) <= F_act_max + 1e-6);
  finite_ok = (abs(x_b) < 1e8) and (abs(z_b) < 1e8) and (abs(theta_b) < 1e8)
              and (abs(theta_b_dot) < 1e8) and (abs(tau) < 1e8) and (abs(F_act) < 1e8)
              and (abs(N) < 1e8) and (abs(theta_hat) < 1e8) and (abs(F_leg) < 1e8);
  slip_ok = max_slip < 0.03;

  annotation(
    experiment(StopTime=16, Tolerance=1e-4, Interval=0.004),
    Documentation(info="Floating-base single-leg hopper MonoHopRecoverE.
      Scenario: stand/step in place and recover from a finite-duration lateral body impulse.
      Acceptance is fail-closed: positive body height, attitude recovery, primary tracking
      error below 0.108 rad after 10.4 s, no foot slip above 0.03 m, torque and actuator
      bounds, no NaN/infinite physical/control/estimator values.
      Values not stated in the requirement (body inertia and dimensions, leg mass, rest
      length, controller/estimator gains, ground stiffness, disturbance timing/duration,
      torque bound magnitude) are marked as assumed and must not be treated as fact."));
end MonoHopRecoverE;