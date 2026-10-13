model MonoHopRecoverA
  "Floating-base single-leg hopper: stand in place and recover from a lateral body impulse.
   Plant-only model, directly simulatable and exportable as FMI 2.0 Co-Simulation FMU."

  // ---- Given physical parameters ----
  parameter Real m_b = 10.0   "body mass [kg]";
  parameter Real k   = 15000.0 "leg spring stiffness [N/m]";
  parameter Real c   = 170.0  "leg damper [N.s/m]";
  parameter Real Lmin = 0.30  "minimum leg length [m]";
  parameter Real Lmax = 0.60  "maximum leg length [m]";
  parameter Real F_act_max = 684.0 "leg actuator command magnitude limit [N]";
  parameter Real mu  = 0.90   "ground friction coefficient [-]";
  parameter Real g   = 9.81   "gravitational acceleration [m/s2]";
  parameter Real F_push_mag = 70.0 "lateral push force magnitude [N]";
  parameter Real Ts  = 0.0125 "control/estimator sample period [s] (80 Hz)";

  // ---- Assumed parameters (not specified in requirement) ----
  parameter Real I_b = 0.12   "body pitch inertia [kg.m2] (unspecified, assumed)";
  parameter Real h   = 0.10   "hip offset from body COM [m] (unspecified, assumed)";
  parameter Real m_f = 0.30   "foot/leg mass [kg] (unspecified, assumed for regularity)";
  parameter Real r_f = 0.02   "spherical foot radius [m] (unspecified, assumed)";
  parameter Real L0  = 0.45   "leg rest length [m] (midpoint of 0.30-0.60)";
  parameter Real k_g = 5.0e4  "ground contact stiffness [N/m] (level rigid ground, penalty)";
  parameter Real c_g = 300.0 "ground contact damping [N.s/m] (assumed)";
  parameter Real v_eps = 0.01 "friction regularization velocity [m/s] (assumed)";
  parameter Real tau_max = 80.0 "hip torque bound [N.m] (unspecified, assumed)";
  parameter Real k_stop = 5.0e4 "leg end-stop stiffness [N/m] (assumed)";
  parameter Real c_stop = 200.0 "leg end-stop damping [N.s/m] (assumed)";
  parameter Real N_thresh = 2.0 "stance contact force threshold [N] (assumed)";

  // ---- Push disturbance timing (applied within the middle third of 8 s) ----
  parameter Real t_push_start = 2.80 "push start time [s] (inside 2.667-5.333 s)";
  parameter Real t_push_dur   = 0.20 "push duration [s] (unspecified, assumed finite)";

  // ---- Controller gains (assumed tuning) ----
  parameter Real z_des = 0.562 "desired body height [m] (assumed, near stance equilibrium)";
  parameter Real K_hop = 500.0;
  parameter Real K_hop_d = 100.0;
  parameter Real Kp_th = 50.0;
  parameter Real Kd_th = 6.0;
  parameter Real K_leg = 2000.0;
  parameter Real K_leg_d = 80.0;
  parameter Real K_phi = 30.0;
  parameter Real K_phi_d = 4.0;
  parameter Real K_step = 0.05;

  // ---- Estimator gains (assumed) ----
  parameter Real K_acc = 0.10;
  parameter Real K_pos = 0.5;
  parameter Real K_pos_z = 0.5;

  // ---- Continuous states ----
  Real x(start=0.0)    "body COM lateral position [m]";
  Real vx(start=0.0)   "body COM lateral velocity [m/s]";
  Real z(start=0.5614) "body COM height [m]";
  Real vz(start=0.0)   "body COM vertical velocity [m/s]";
  Real theta(start=0.0) "body pitch angle [rad]";
  Real omega(start=0.0) "body pitch rate [rad/s]";
  Real L(start=0.4435) "leg length [m]";
  Real Ld(start=0.0)   "leg length rate [m/s]";
  Real phi(start=0.0)  "leg angle from vertical [rad]";
  Real phid(start=0.0) "leg angle rate [rad/s]";

  // ---- Continuous intermediates ----
  Real s_theta, c_theta, s_phi, c_phi;
  Real foot_x, foot_z, foot_vx, foot_vz;
  Real d_pen, N, f_t, F_a, F_stop;
  Real F_push;
  Real xdd, zdd, thedd, RX, RZ, Ldd, phidd;
  Real ax_imu, az_imu, gyro;
  Real F_act "actuator force command [N]";
  Real tau   "hip torque command [N.m]";
  Real foot_slip_dist "current foot slip distance [m]";
  Real tracking_error "attitude tracking error [rad]";

protected
  Real L_safe "guarded leg length used as divisor [m]";

  // ---- Discrete (sampled) variables: control, estimation, monitors ----
  discrete Real F_act_d(start=0.0);
  discrete Real tau_d(start=0.0);
  discrete Real x_hat(start=0.0);
  discrete Real vx_hat(start=0.0);
  discrete Real z_hat(start=0.5614);
  discrete Real vz_hat(start=0.0);
  discrete Real theta_hat(start=0.0);
  discrete Real omega_hat(start=0.0);
  discrete Real xf_contact_est(start=0.0);
  discrete Boolean stance_prev_est(start=false);
  discrete Real theta_acc(start=0.0);
  discrete Real ax_w(start=0.0);
  discrete Real az_w(start=0.0);
  discrete Real x_kin(start=0.0);
  discrete Real z_kin(start=0.0);
  discrete Real F_act_raw(start=0.0);
  discrete Real tau_raw(start=0.0);
  discrete Real phi_des(start=0.0);
  discrete Boolean stance_now(start=false);
  discrete Real xf_contact_true(start=0.0);
  discrete Boolean stance_prev_true(start=false);
  discrete Real max_slip(start=0.0);
  discrete Real max_trk_err_52(start=0.0);

equation
  // trigonometry
  s_theta = sin(theta);
  c_theta = cos(theta);
  s_phi   = sin(phi);
  c_phi   = cos(phi);

  // foot kinematics (hip offset below body COM)
  foot_x  = x - h*s_theta + L*s_phi;
  foot_z  = z - h*c_theta - L*c_phi;
  foot_vx = vx - h*c_theta*omega + Ld*s_phi + L*c_phi*phid;
  foot_vz = vz + h*s_theta*omega - Ld*c_phi + L*s_phi*phid;

  // ground contact: unilateral normal (penalty) + regularized Coulomb friction
  d_pen = r_f - foot_z;
  N = if d_pen > 0.0 then
        (if (k_g*d_pen - c_g*foot_vz) > 0.0 then (k_g*d_pen - c_g*foot_vz) else 0.0)
      else 0.0;
  f_t = -mu * N * tanh(foot_vx / v_eps);

  // leg end-stops keep L within [Lmin, Lmax]
  F_stop = if L > Lmax then (k_stop*(Lmax - L) - c_stop*Ld)
           else if L < Lmin then (k_stop*(Lmin - L) - c_stop*Ld)
           else 0.0;

  // leg axial force (compression positive): spring + damper + actuator + end-stop
  F_a = k*(L0 - L) - c*Ld + F_act_d + F_stop;

  // actuator command aliases (zero-order-held discrete commands)
  F_act = F_act_d;
  tau   = tau_d;

  // push disturbance (lateral, finite duration, within middle third of scenario)
  F_push = if (time >= t_push_start and time < t_push_start + t_push_dur) then F_push_mag else 0.0;

  // guarded divisor (zero-error branch)
  L_safe = if L > 0.05 then L else 0.05;

  // body accelerations
  xdd  = (-F_a*s_phi + F_push)/m_b;
  zdd  = (F_a*c_phi - m_b*g)/m_b;
  thedd = (-tau - h*F_a*sin(theta + phi))/I_b;

  // foot force balance -> leg accelerations (solved in closed form)
  RX = F_a*s_phi + f_t
       - m_f*(xdd - h*c_theta*thedd + h*s_theta*omega^2 + 2.0*Ld*c_phi*phid - L*s_phi*phid^2);
  RZ = -F_a*c_phi - m_f*g + N
       - m_f*(zdd + h*s_theta*thedd + h*c_theta*omega^2 + 2.0*Ld*s_phi*phid + L*c_phi*phid^2);
  Ldd   = (s_phi*RX - c_phi*RZ)/m_f;
  phidd = (c_phi*RX + s_phi*RZ)/(m_f*L_safe);

  // state derivatives
  der(x) = vx;
  der(vx) = xdd;
  der(z) = vz;
  der(vz) = zdd;
  der(theta) = omega;
  der(omega) = thedd;
  der(L) = Ld;
  der(Ld) = Ldd;
  der(phi) = phid;
  der(phid) = phidd;

  // IMU sensors: specific force in body frame + gyro
  ax_imu = cos(theta)*xdd + sin(theta)*(zdd + g);
  az_imu = -sin(theta)*xdd + cos(theta)*(zdd + g);
  gyro = omega;

  // observables
  tracking_error = abs(theta);
  foot_slip_dist = if (N > N_thresh) then abs(foot_x - xf_contact_true) else 0.0;

  // ---- Discrete estimation, control, and monitoring at 80 Hz ----
  when sample(0, Ts) loop
    // record true contact foot x (for slip monitor)
    stance_now := N > N_thresh;
    if stance_now and not pre(stance_prev_true) then
      xf_contact_true := foot_x;
    end if;
    stance_prev_true := stance_now;

    // ---- Base-pose estimator: IMU + kinematics + force-qualified stance ----
    theta_acc := atan2(ax_imu, az_imu);
    theta_hat := theta_hat + Ts*(gyro + K_acc*(theta_acc - theta_hat));
    omega_hat := gyro;
    ax_w := cos(theta_hat)*ax_imu - sin(theta_hat)*az_imu;
    az_w := sin(theta_hat)*ax_imu + cos(theta_hat)*az_imu;
    vx_hat := vx_hat + Ts*ax_w;
    x_hat  := x_hat + Ts*vx_hat;
    vz_hat := vz_hat + Ts*(az_w - g);
    z_hat  := z_hat + Ts*vz_hat;

    x_kin := x_hat;
    z_kin := z_hat;
    if stance_now and not pre(stance_prev_est) then
      xf_contact_est := x_hat - h*sin(theta_hat) + L*sin(phi);
    end if;
    if stance_now then
      x_kin := xf_contact_est - L*sin(phi) + h*sin(theta_hat);
      z_kin := r_f + h*cos(theta_hat) + L*cos(phi);
      x_hat := x_hat + K_pos*(x_kin - x_hat);
      z_hat := z_hat + K_pos_z*(z_kin - z_hat);
    end if;
    stance_prev_est := stance_now;

    // ---- Whole-body balance control with contact switching ----
    phi_des := -K_step*vx_hat;
    if stance_now then
      // stance: inject hopping energy along leg + attitude recovery via hip torque
      F_act_raw := K_hop*(z_des - z_hat) - K_hop_d*vz_hat;
      tau_raw   := Kp_th*theta_hat + Kd_th*omega_hat;
    else
      // flight: servo leg to rest length + foot placement + hold attitude
      F_act_raw := K_leg*(L0 - L) - K_leg_d*Ld;
      tau_raw   := K_phi*(phi_des - phi) - K_phi_d*phid + Kp_th*theta_hat + Kd_th*omega_hat;
    end if;

    // bounded actuator and bounded torque
    F_act_d := if F_act_raw > F_act_max then F_act_max
               else if F_act_raw < -F_act_max then -F_act_max else F_act_raw;
    tau_d   := if tau_raw > tau_max then tau_max
               else if tau_raw < -tau_max then -tau_max else tau_raw;

    // ---- Requirement monitors ----
    if foot_slip_dist > pre(max_slip) then
      max_slip := foot_slip_dist;
    else
      max_slip := pre(max_slip);
    end if;
    if (time >= 5.2) and (abs(theta) > pre(max_trk_err_52)) then
      max_trk_err_52 := abs(theta);
    else
      max_trk_err_52 := pre(max_trk_err_52);
    end if;
  end when;

  annotation (
    experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "MonoHopRecoverA: 10 kg cylindrical body on one telescoping 0.30-0.60 m leg
      (15 kN/m spring, 170 N.s/m damper, spherical foot), bounded leg actuator (|F|<=684 N),
      bounded hip torque (|tau|<=tau_max). Whole-body balance control with contact switching,
      IMU+kinematics+force-qualified pose estimation, 80 Hz, 8 s. 70 N lateral push applied as a
      finite-duration impulse within the middle third. Tracks attitude recovery, foot slip, body
      height, and finite/non-NaN behavior. Unspecified physical constants (I_b, h, m_f, r_f, ground
      stiffness, tau_max, controller/estimator gains, push duration) are assumed and so labeled.")
  );
end MonoHopRecoverA;