model MonoHopRecoverA
  "Floating-base monoped hopper with balance control, estimator, and push recovery"

  // === Physical parameters ===
  parameter Real m_body = 10.0 "Body mass [kg]";
  parameter Real I_body = 0.131 "Body moment of inertia about pitch axis [kg.m2]";
  parameter Real m_foot = 0.5 "Foot mass for numerical regularization [kg]";
  parameter Real r_foot = 0.02 "Spherical foot radius [m]";
  parameter Real leg_min = 0.30 "Minimum telescoping leg length [m]";
  parameter Real leg_max = 0.60 "Maximum telescoping leg length [m]";
  parameter Real r_rest = 0.50 "Leg spring rest length [m]";
  parameter Real k_spring = 15000.0 "Leg spring stiffness [N/m]";
  parameter Real c_damper = 170.0 "Leg damper coefficient [N.s/m]";
  parameter Real F_act_max = 684.0 "Leg actuator command magnitude limit [N]";
  parameter Real mu_ground = 0.90 "Ground friction coefficient";
  parameter Real k_ground = 5.0e4 "Ground normal stiffness [N/m]";
  parameter Real c_ground = 500.0 "Ground normal damping [N.s/m]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real tau_hip_max = 40.0 "Hip torque bound [N.m]";

  // === Controller parameters ===
  parameter Real f_ctrl = 80.0 "Control loop rate [Hz]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control period [s]";
  parameter Real K_hip_p = 100.0 "Hip attitude proportional gain";
  parameter Real K_hip_d = 10.0 "Hip attitude derivative gain";
  parameter Real K_thrust = 500.0 "Stance active stiffness gain [N/m]";
  parameter Real r_stance_target = 0.494 "Target stance leg length [m]";
  parameter Real theta_ref = 0.0 "Reference body pitch angle [rad]";
  parameter Real x_ref = 0.0 "Reference horizontal position [m]";

  // === Disturbance ===
  parameter Real F_push = 70.0 "Lateral push magnitude [N]";
  parameter Real t_push_start = 8.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_push_end = 16.0 / 3.0 "Disturbance end time [s]";

  // === Continuous state variables ===
  Real x_b(start = 0.0) "Body horizontal position [m]";
  Real y_b(start = 0.512) "Body vertical position [m]";
  Real vx_b(start = 0.0) "Body horizontal velocity [m/s]";
  Real vy_b(start = 0.0) "Body vertical velocity [m/s]";
  Real theta(start = 0.0) "Body pitch angle [rad]";
  Real omega(start = 0.0) "Body pitch angular velocity [rad/s]";
  Real x_f(start = 0.0) "Foot horizontal position [m]";
  Real y_f(start = 0.018) "Foot vertical position [m]";
  Real vx_f(start = 0.0) "Foot horizontal velocity [m/s]";
  Real vy_f(start = 0.0) "Foot vertical velocity [m/s]";

  // === Continuous derived quantities ===
  Real r "Leg length [m]";
  Real dr "Leg extension rate [m/s]";
  Real phi "Leg absolute angle from vertical [rad]";
  Real sin_phi "Sine of leg angle";
  Real cos_phi "Cosine of leg angle";

  // === Forces ===
  Real F_spring "Leg spring force [N]";
  Real F_damp "Leg damper force [N]";
  Real F_leg "Total axial leg force [N]";
  Real F_tan "Tangential leg force from hip torque [N]";
  Real F_gnd_y "Ground normal force [N]";
  Real F_gnd_x "Ground friction force [N]";
  Real F_dist "Disturbance force [N]";
  Real F_leg_limit "Leg hard-stop force [N]";
  Real F_gnd_y_filt "Filtered ground normal force for estimator [N]";

  // === Contact ===
  Boolean in_stance "Force-qualified stance flag";

  // === Discrete controller / estimator variables ===
  discrete Real F_act_cmd(start = 0.0) "Actuator command [N]";
  discrete Real F_act(start = 0.0) "Bounded actuator force [N]";
  discrete Real tau_hip_cmd(start = 0.0) "Hip torque command [N.m]";
  discrete Real tau_hip(start = 0.0) "Bounded hip torque [N.m]";
  discrete Real theta_est(start = 0.0) "Estimated body pitch [rad]";
  discrete Real omega_est(start = 0.0) "Estimated pitch rate [rad/s]";
  discrete Real x_b_est(start = 0.0) "Estimated body horizontal position [m]";
  discrete Real vx_b_est(start = 0.0) "Estimated body horizontal velocity [m/s]";
  discrete Real y_b_est(start = 0.512) "Estimated body height [m]";
  discrete Real x_f_est(start = 0.0) "Estimated foot horizontal position [m]";
  discrete Boolean in_stance_est(start = false) "Estimated stance flag";

  // === Monitoring variables ===
  discrete Real foot_stance_origin(start = 0.0) "Foot x at stance entry [m]";
  discrete Real max_slip(start = 0.0) "Maximum observed foot slip [m]";
  discrete Real current_slip(start = 0.0) "Current foot slip magnitude [m]";
  discrete Boolean prev_stance(start = false) "Previous sample stance flag";
  discrete Real tracking_error(start = 0.0) "Primary tracking error [rad]";

equation
  // === Disturbance: 70 N lateral push during middle third ===
  F_dist = if (time >= t_push_start and time <= t_push_end) then F_push else 0.0;

  // === Leg kinematics ===
  r = sqrt((x_b - x_f)^2 + (y_b - y_f)^2) + 1.0e-9;
  sin_phi = (x_b - x_f) / r;
  cos_phi = (y_b - y_f) / r;
  phi = atan2(x_b - x_f, y_b - y_f + 1.0e-9);
  dr = ((x_b - x_f) * (vx_b - vx_f) + (y_b - y_f) * (vy_b - vy_f)) / r;

  // === Leg internal forces ===
  F_spring = k_spring * (r_rest - r);
  F_damp = c_damper * dr;
  F_leg_limit = if r < leg_min then 1.0e5 * (leg_min - r)
                else if r > leg_max then 1.0e5 * (leg_max - r)
                else 0.0;
  F_leg = F_spring - F_damp + F_act + F_leg_limit;

  // === Hip torque to tangential force ===
  F_tan = tau_hip / (r + 1.0e-6);

  // === Ground contact (compliant normal + regularized Coulomb friction) ===
  F_gnd_y = if (y_f < r_foot) then
              max(0.0, k_ground * (r_foot - y_f) - c_ground * vy_f)
            else 0.0;
  F_gnd_x = -mu_ground * F_gnd_y * tanh(vx_f / 0.01);

  // === Force-qualified stance detection ===
  in_stance = F_gnd_y > 1.0;

  // === Estimator ground-force filter ===
  der(F_gnd_y_filt) = (F_gnd_y - F_gnd_y_filt) / 0.01;

  // === Body dynamics ===
  der(x_b) = vx_b;
  der(y_b) = vy_b;
  der(vx_b) = (F_leg * sin_phi + F_tan * cos_phi + F_dist) / m_body;
  der(vy_b) = (F_leg * cos_phi - F_tan * sin_phi - m_body * g_acc) / m_body;
  der(theta) = omega;
  der(omega) = tau_hip / I_body;

  // === Foot dynamics ===
  der(x_f) = vx_f;
  der(y_f) = vy_f;
  der(vx_f) = (-F_leg * sin_phi - F_tan * cos_phi + F_gnd_x) / m_foot;
  der(vy_f) = (-F_leg * cos_phi + F_tan * sin_phi + F_gnd_y - m_foot * g_acc) / m_foot;

  // === Sampled controller and estimator at 80 Hz ===
  when sample(0, dt_ctrl) then
    // --- IMU-based attitude estimation ---
    theta_est := theta;
    omega_est := omega;

    // --- Force-qualified stance detection for estimator ---
    in_stance_est := F_gnd_y_filt > 1.0;

    // --- Kinematics-based pose estimation ---
    if in_stance_est then
      x_f_est := x_f;
      x_b_est := x_f_est + r * sin_phi;
      y_b_est := y_f + r * cos_phi;
      vx_b_est := vx_b;
    else
      // Dead-reckoning during flight
      x_b_est := x_b_est + vx_b_est * dt_ctrl;
      y_b_est := y_b_est + vy_b * dt_ctrl;
      vx_b_est := vx_b;
    end if;

    // --- Tracking error ---
    tracking_error := abs(theta_est - theta_ref);

    // --- Foot slip monitoring ---
    if in_stance and not prev_stance then
      foot_stance_origin := x_f;
    end if;

    if in_stance then
      current_slip := abs(x_f - foot_stance_origin);
    else
      current_slip := 0.0;
    end if;

    if current_slip > max_slip then
      max_slip := current_slip;
    end if;

    prev_stance := in_stance;

    // --- Whole-body balance control with contact switching ---
    // Hip torque: PD attitude control (stance and flight)
    tau_hip_cmd := K_hip_p * (theta_ref - theta_est) - K_hip_d * omega_est;
    tau_hip := max(-tau_hip_max, min(tau_hip_max, tau_hip_cmd));

    // Leg actuator: hopping energy injection during stance only
    if in_stance_est then
      F_act_cmd := K_thrust * (r_stance_target - r);
    else
      F_act_cmd := 0.0;
    end if;
    F_act := max(-F_act_max, min(F_act_max, F_act_cmd));
  end when;

  // === Requirement assertions ===
  assert(y_b > 0.0, "Positive body height violated");
  assert(max_slip <= 0.03, "Foot slip exceeds 0.03 m");
  assert(time < 5.2 or tracking_error < 0.162,
         "Primary tracking error exceeds 0.162 rad after 5.2 s");

  annotation(
    Documentation(info = "MonoHopRecoverA: 10 kg cylindrical body on one telescoping leg
      (0.30-0.60 m, 15 kN/m spring, 170 N.s/m damper, spherical foot).
      Bounded linear leg actuator (684 N limit) injects hopping energy.
      Whole-body balance control with contact switching at 80 Hz.
      70 N lateral push applied during middle third of 8 s scenario.
      Level rigid ground with friction 0.90."),
    Experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125)
  );
end MonoHopRecoverA;