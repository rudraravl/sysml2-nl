model SoftGripGraspC
  // ===== Dimensions and limits =====
  parameter Real L_finger = 0.13 "Finger length [m]";
  parameter Integer N_sec = 4 "Bending sections per finger";
  parameter Real L_sec = L_finger / N_sec "Section length [m]";
  parameter Real P_max = 87400.0 "Max command pressure [Pa-gauge]";
  parameter Real F_tan_dist = 3.6 "Tangential disturbance load [N]";
  parameter Real mu = 0.70 "Friction coefficient at finger-object contact";
  parameter Real dt_sample = 0.008 "Controller sample time (125 Hz) [s]";
  parameter Real T_sim = 12.0 "Simulation duration [s]";

  // ===== Finger mechanics =====
  parameter Real k_bend = 3.5 "Section bending stiffness [Nm/rad]";
  parameter Real c_bend = 0.03 "Section bending damping [Nms/rad]";
  parameter Real J_sec = 1.0e-4 "Section inertia [kg.m^2]";
  parameter Real A_chamber = 7.0e-4 "Chamber cross-section [m^2]";
  parameter Real r_moment = 0.02 "Pressure moment arm [m]";
  parameter Real tau_act = 0.01 "Actuator time constant [s]";

  // ===== Contact =====
  parameter Real k_contact = 1900.0 "Contact stiffness [N/m]";
  parameter Real d_contact = 5.0 "Contact damping [Ns/m]";
  parameter Real gap_init = 0.001 "Initial gap between finger tip and object [m]";
  parameter Real F_local_max = 4.5 "Per-contact overload threshold [N]";
  parameter Real F_total_target = 9.0 "Target total normal grasp force [N]";
  parameter Real F_total_min = 6.0 "Total force band min [N]";
  parameter Real F_total_max = 12.0 "Total force band max [N]";
  parameter Real deform_max = 0.02 "Deformation bound [m]";

  // ===== Object =====
  parameter Real m_obj = 0.12 "Object mass [kg]";
  parameter Real g = 9.81 "Gravity [m/s^2]";

  // ===== Controller =====
  parameter Real Kp_force = 2000.0 "Force proportional gain";
  parameter Real Ki_force = 300.0 "Force integral gain";
  parameter Real K_redist = 500.0 "Contact force redistribution gain";
  parameter Real v_thresh = 1.0e-4 "Friction regularization threshold [m/s]";

  // ===== Continuous states =====
  Real theta[3,4] "Section bend angles [rad]";
  Real omega[3,4] "Section angular velocities [rad/s]";
  Real P_meas[3] "Measured chamber pressure (actuator sensing) [Pa]";
  Real x_obj "Object lateral position [m]";
  Real vx_obj "Object lateral velocity [m/s]";

  // ===== Kinematics and contact =====
  Real theta_total[3] "Total finger bending [rad]";
  Real disp_tip[3] "Tip displacement toward object [m]";
  Real v_tip[3] "Tip velocity [m/s]";
  Real penetration[3] "Contact penetration [m]";
  Real F_normal[3] "Normal contact force per finger (contact sensing) [N]";
  Real F_friction[3] "Friction force per finger [N]";
  Real F_total "Total normal grasp force [N]";
  Real F_dist "Tangential disturbance force [N]";
  Real N_support "Support normal force from rigid surface [N]";

  // ===== Sensor outputs =====
  Real P_sensor[3] "Actuator pressure sensor reading [Pa]";
  Real F_contact_sensor[3] "Distributed contact force sensor reading [N]";
  Real x_obj_sensor "Object pose sensor reading [m]";

  // ===== Discrete controller =====
  discrete Real P_cmd[3](each start = 0.0) "Chamber pressure command [Pa]";
  discrete Real P_raw[3](each start = 0.0) "Raw pressure before saturation [Pa]";
  discrete Real P_base(start = 0.0) "Base pressure from PI law [Pa]";
  discrete Real correction[3](each start = 0.0) "Per-finger redistribution correction [Pa]";
  discrete Real force_integral(start = 0.0) "Force integral term [Pa.s]";
  discrete Real force_err(start = 0.0) "Force tracking error [N]";

  // ===== Tracking and diagnostics =====
  Real track_error "Primary tracking error [m]";
  Real max_deform "Maximum deformation [m]";
  Boolean actuator_ok "Actuator bounds satisfied";
  Boolean deformation_ok "Deformation bounds satisfied";
  Boolean force_bands_ok "Per-contact and total force bands satisfied";
  Boolean no_contact_loss "No contact loss after engagement";
  Boolean tracking_ok "Tracking error below 0.016 m after 7.8 s";

initial equation
  theta[1,1] = 0.0; theta[1,2] = 0.0; theta[1,3] = 0.0; theta[1,4] = 0.0;
  theta[2,1] = 0.0; theta[2,2] = 0.0; theta[2,3] = 0.0; theta[2,4] = 0.0;
  theta[3,1] = 0.0; theta[3,2] = 0.0; theta[3,3] = 0.0; theta[3,4] = 0.0;
  omega[1,1] = 0.0; omega[1,2] = 0.0; omega[1,3] = 0.0; omega[1,4] = 0.0;
  omega[2,1] = 0.0; omega[2,2] = 0.0; omega[2,3] = 0.0; omega[2,4] = 0.0;
  omega[3,1] = 0.0; omega[3,2] = 0.0; omega[3,3] = 0.0; omega[3,4] = 0.0;
  P_meas[1] = 0.0; P_meas[2] = 0.0; P_meas[3] = 0.0;
  x_obj = 0.0;
  vx_obj = 0.0;

equation
  // ===== Tangential disturbance: active during middle third (4 to 8 s) =====
  if time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0 then
    F_dist = F_tan_dist;
  else
    F_dist = 0.0;
  end if;

  // ===== Finger kinematics and contact =====
  for i in 1:3 loop
    theta_total[i] = theta[i,1] + theta[i,2] + theta[i,3] + theta[i,4];
    disp_tip[i] = L_finger * (1.0 - cos(theta_total[i]));
    v_tip[i] = L_finger * sin(theta_total[i]) * (omega[i,1] + omega[i,2] + omega[i,3] + omega[i,4]);

    // Smooth penetration: max(disp_tip - gap_init, 0) without events
    penetration[i] = (disp_tip[i] - gap_init + sqrt((disp_tip[i] - gap_init)*(disp_tip[i] - gap_init) + 1.0e-12)) / 2.0;

    // Compliant contact force: spring-damper with smooth activation
    F_normal[i] = k_contact * penetration[i]
      + d_contact * v_tip[i] * penetration[i] / sqrt(penetration[i]*penetration[i] + 1.0e-12);

    // Regularized Coulomb friction (mu = 0.70)
    F_friction[i] = mu * F_normal[i] * vx_obj / sqrt(vx_obj*vx_obj + v_thresh*v_thresh);
  end for;

  // Total grasp force
  F_total = F_normal[1] + F_normal[2] + F_normal[3];

  // ===== Finger section dynamics (4 bending sections per finger) =====
  for i in 1:3 loop
    for j in 1:N_sec loop
      der(theta[i,j]) = omega[i,j];
      J_sec * der(omega[i,j]) = -k_bend * theta[i,j] - c_bend * omega[i,j]
        + P_meas[i] * A_chamber * r_moment
        - F_normal[i] * L_sec;
    end for;
  end for;

  // ===== Actuator dynamics (first-order lag on pressure command) =====
  der(P_meas[1]) = (P_cmd[1] - P_meas[1]) / tau_act;
  der(P_meas[2]) = (P_cmd[2] - P_meas[2]) / tau_act;
  der(P_meas[3]) = (P_cmd[3] - P_meas[3]) / tau_act;

  // ===== Object dynamics on rigid support surface =====
  // Lateral: disturbance vs. contact friction; Vertical: rigid support balances gravity
  der(x_obj) = vx_obj;
  m_obj * der(vx_obj) = F_dist - (F_friction[1] + F_friction[2] + F_friction[3]);
  N_support = m_obj * g;

  // ===== Sensor outputs (ideal sensing) =====
  P_sensor[1] = P_meas[1];
  P_sensor[2] = P_meas[2];
  P_sensor[3] = P_meas[3];
  F_contact_sensor[1] = F_normal[1];
  F_contact_sensor[2] = F_normal[2];
  F_contact_sensor[3] = F_normal[3];
  x_obj_sensor = x_obj;

  // ===== Tracking error =====
  track_error = abs(x_obj);

  // ===== Diagnostics =====
  max_deform = max(disp_tip[1], max(disp_tip[2], disp_tip[3]));
  actuator_ok = (P_cmd[1] >= 0.0 and P_cmd[1] <= P_max)
    and (P_cmd[2] >= 0.0 and P_cmd[2] <= P_max)
    and (P_cmd[3] >= 0.0 and P_cmd[3] <= P_max);
  deformation_ok = max_deform <= deform_max;
  force_bands_ok = if time > 3.0 then
    (F_normal[1] <= F_local_max and F_normal[2] <= F_local_max and F_normal[3] <= F_local_max
     and F_total >= F_total_min and F_total <= F_total_max) else true;
  no_contact_loss = if time > 2.0 then
    (penetration[1] > 1.0e-5 and penetration[2] > 1.0e-5 and penetration[3] > 1.0e-5) else true;
  tracking_ok = if time >= 7.8 then track_error < 0.016 else true;

  // ===== Sampled force controller at 125 Hz =====
  when sample(0, dt_sample) then
    // Force tracking error
    force_err = F_total_target - F_total;

    // Integral with anti-windup clipping
    force_integral = max(-P_max / Ki_force, min(pre(force_integral) + force_err * dt_sample, P_max / Ki_force));

    // Base pressure from PI law
    P_base = Kp_force * force_err + Ki_force * force_integral;

    // Per-finger redistribution to prevent local overload
    if F_normal[1] > F_local_max then
      correction[1] = -K_redist * (F_normal[1] - F_local_max);
    else
      correction[1] = 0.0;
    end if;
    if F_normal[2] > F_local_max then
      correction[2] = -K_redist * (F_normal[2] - F_local_max);
    else
      correction[2] = 0.0;
    end if;
    if F_normal[3] > F_local_max then
      correction[3] = -K_redist * (F_normal[3] - F_local_max);
    else
      correction[3] = 0.0;
    end if;

    // Raw and saturated pressure commands
    P_raw[1] = P_base + correction[1];
    P_raw[2] = P_base + correction[2];
    P_raw[3] = P_base + correction[3];
    P_cmd[1] = max(0.0, min(P_raw[1], P_max));
    P_cmd[2] = max(0.0, min(P_raw[2], P_max));
    P_cmd[3] = max(0.0, min(P_raw[3], P_max));
  end when;

  annotation (
    experiment(StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "SoftGripGraspC: Three-finger soft robotic gripper with pressure control and contact-force redistribution. Three silicone fingers (0.13 m, 4 bending sections each) surround a rigid palm. Compliant contact with friction mu=0.70 on rigid support surface. Controller at 125 Hz regulates total normal grasp force and prevents local overload. Tangential disturbance of 3.6 N injected during middle third (4-8 s). Max command 87.4 kPa-gauge.")
  );
end SoftGripGraspC;