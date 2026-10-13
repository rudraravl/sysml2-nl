model ParallelGripPolishB
  "Contact-rich parallel-grip polishing: follow 0.50 m curved surface path with constant normal force";

  // ===== Physical parameters =====
  parameter Real m_palm = 6.0 "Palm mass [kg]";
  parameter Real m_finger = 0.5 "Each finger mass [kg]";
  parameter Real joint_travel = 0.05 "Prismatic joint travel [m]";
  parameter Real mu = 0.50 "Friction coefficient [1]";
  parameter Real F_max = 36.9 "Max finger actuator force magnitude per finger [N]";
  parameter Real N_set = 21.0 "Normal force setpoint (midpoint of 12-30 N) [N]";
  parameter Real N_lo = 12.0 "Minimum normal force [N]";
  parameter Real N_hi = 30.0 "Maximum normal force [N]";
  parameter Real path_length = 0.50 "Surface path length [m]";
  parameter Real T_sim = 10.0 "Mission duration [s]";
  parameter Real sample_dt = 0.01 "Control sample period (100 Hz) [s]";
  // Pad compliance - representative values (actual stiffness/damping not specified)
  parameter Real k_pad = 10000.0 "Pad stiffness [N/m]";
  parameter Real c_pad = 50.0 "Pad damping [N.s/m]";
  parameter Real q_surf = 0.015 "Finger position at first contact [m]";
  // Joint hard-stop parameters
  parameter Real k_limit = 1000000.0 "Joint limit stiffness [N/m]";
  parameter Real c_limit = 1000.0 "Joint limit damping [N.s/m]";
  // Controller gains
  parameter Real Kp_t = 500.0 "Tangential proportional gain [N/m]";
  parameter Real Kd_t = 80.0 "Tangential derivative gain [N.s/m]";
  parameter Real Ki_t = 300.0 "Tangential integral gain [N/(m.s)]";
  parameter Real Kp_n = 5.0 "Normal-force proportional gain [1]";
  parameter Real Ki_n = 10.0 "Normal-force integral gain [1/s]";
  // Numerical smoothing
  parameter Real eps2 = 1.0e-12 "Smoothing epsilon squared [m^2]";
  parameter Real v_eps = 0.001 "Friction smoothing velocity [m/s]";
  parameter Real eps_pen = 1.0e-6 "Penetration smoothing epsilon [m]";

  // ===== Continuous states =====
  Real x_palm(start=0.0, fixed=true) "Palm tangential position along surface path [m]";
  Real v_palm(start=0.0, fixed=true) "Palm tangential velocity [m/s]";
  Real q1(start=0.01605, fixed=true) "Finger 1 joint position [m]";
  Real v1(start=0.0, fixed=true) "Finger 1 velocity [m/s]";
  Real q2(start=0.01605, fixed=true) "Finger 2 joint position [m]";
  Real v2(start=0.0, fixed=true) "Finger 2 velocity [m/s]";

  // ===== Discrete control states (sampled at 100 Hz) =====
  discrete Real F1_cmd(start=10.5, fixed=true) "Bounded finger 1 commanded force [N]";
  discrete Real F2_cmd(start=10.5, fixed=true) "Bounded finger 2 commanded force [N]";
  discrete Real F_tang_cmd(start=0.0, fixed=true) "Tangential wrist control force command [N]";
  discrete Real int_t(start=0.0, fixed=true) "Tangential integral [m.s]";
  discrete Real int_n(start=0.0, fixed=true) "Normal-force integral [N.s]";

  // ===== Contact (algebraic) =====
  Real pad_pen1 "Finger 1 pad penetration [m]";
  Real pad_pen2 "Finger 2 pad penetration [m]";
  Real F_pad1 "Finger 1 pad force [N]";
  Real F_pad2 "Finger 2 pad force [N]";
  Real N_contact "Total normal contact force [N]";
  Real F_friction "Tangential friction force [N]";
  Real contact_indicator "Contact indicator (1=in contact) [1]";

  // ===== Disturbance and reference =====
  Real F_dist "Surface-force disturbance [N]";
  Real s_ref "Reference path position [m]";
  Real s_ref_dot "Reference path velocity [m/s]";

  // ===== Errors =====
  Real tracking_error "Primary tracking error |s_ref - x_palm| [m]";
  Real path_error "Path error [m]";

  // ===== Sensors =====
  Real q1_meas "Joint 1 encoder [m]";
  Real q2_meas "Joint 2 encoder [m]";
  Real wrist_wrench_t "Wrist wrench tangential [N]";
  Real wrist_wrench_n "Wrist wrench normal [N]";
  Real tool_tip_x "Tool-tip tangential pose [m]";
  Real tool_tip_n "Tool-tip normal pose [m]";

  // ===== Joint limit forces =====
  Real F_limit1 "Finger 1 joint limit force [N]";
  Real F_limit2 "Finger 2 joint limit force [N]";

  // ===== Synchronized traces =====
  Real trace_time "Synchronized time [s]";
  Real trace_state_x "State: palm position [m]";
  Real trace_state_v "State: palm velocity [m/s]";
  Real trace_state_q1 "State: finger 1 position [m]";
  Real trace_state_q2 "State: finger 2 position [m]";
  Real trace_cmd_F1 "Command: finger 1 force [N]";
  Real trace_cmd_F2 "Command: finger 2 force [N]";
  Real trace_cmd_Ft "Command: tangential force [N]";
  Real trace_sensor_N "Sensor: normal force [N]";
  Real trace_sensor_wt "Sensor: wrist wrench tangential [N]";
  Real trace_sensor_wn "Sensor: wrist wrench normal [N]";

equation
  // ===== Reference trajectory: smoothstep 0 to path_length over T_sim =====
  s_ref = path_length * (3.0 * (time/T_sim)^2 - 2.0 * (time/T_sim)^3);
  s_ref_dot = path_length * (6.0 * (time/T_sim) - 6.0 * (time/T_sim)^2) / T_sim;

  // ===== Disturbance: 4.9 N during middle third [T_sim/3, 2*T_sim/3] =====
  F_dist = if (time >= T_sim/3.0 and time <= 2.0*T_sim/3.0) then 4.9 else 0.0;

  // ===== Pad penetration: smooth max(0, q - q_surf) =====
  pad_pen1 = 0.5 * ((q1 - q_surf) + sqrt((q1 - q_surf)^2 + eps2));
  pad_pen2 = 0.5 * ((q2 - q_surf) + sqrt((q2 - q_surf)^2 + eps2));

  // ===== Pad forces: compliant normal contact with velocity damping =====
  F_pad1 = k_pad * pad_pen1 + c_pad * v1 * pad_pen1 / (pad_pen1 + eps_pen);
  F_pad2 = k_pad * pad_pen2 + c_pad * v2 * pad_pen2 / (pad_pen2 + eps_pen);

  // ===== Total normal contact force (grip / tool force) =====
  N_contact = F_pad1 + F_pad2;

  // ===== Contact indicator =====
  contact_indicator = if N_contact > 0.1 then 1.0 else 0.0;

  // ===== Friction: smooth Coulomb opposing palm tangential motion =====
  F_friction = mu * N_contact * tanh(v_palm / v_eps);

  // ===== Joint limit forces: hard stops at q=0 and q=joint_travel =====
  F_limit1 = if q1 < 0.0 then (-k_limit * q1 - c_limit * v1)
             else if q1 > joint_travel then (-k_limit * (q1 - joint_travel) - c_limit * v1)
             else 0.0;
  F_limit2 = if q2 < 0.0 then (-k_limit * q2 - c_limit * v2)
             else if q2 > joint_travel then (-k_limit * (q2 - joint_travel) - c_limit * v2)
             else 0.0;

  // ===== Continuous dynamics =====
  // Palm: tangential motion driven by wrist force, opposed by friction, perturbed by disturbance
  der(x_palm) = v_palm;
  m_palm * der(v_palm) = F_tang_cmd - F_friction + F_dist;

  // Finger 1: prismatic joint, actuated inward, pad force outward, hard-stop limit
  der(q1) = v1;
  m_finger * der(v1) = F1_cmd - F_pad1 + F_limit1;

  // Finger 2: prismatic joint, actuated inward, pad force outward, hard-stop limit
  der(q2) = v2;
  m_finger * der(v2) = F2_cmd - F_pad2 + F_limit2;

  // ===== Sensors =====
  q1_meas = q1;
  q2_meas = q2;
  wrist_wrench_t = F_tang_cmd;
  wrist_wrench_n = N_contact;
  tool_tip_x = x_palm;
  tool_tip_n = 0.0;

  // ===== Error metrics =====
  tracking_error = abs(s_ref - x_palm);
  path_error = tracking_error;

  // ===== Synchronized traces (state, command, sensor) =====
  trace_time = time;
  trace_state_x = x_palm;
  trace_state_v = v_palm;
  trace_state_q1 = q1;
  trace_state_q2 = q2;
  trace_cmd_F1 = F1_cmd;
  trace_cmd_F2 = F2_cmd;
  trace_cmd_Ft = F_tang_cmd;
  trace_sensor_N = N_contact;
  trace_sensor_wt = wrist_wrench_t;
  trace_sensor_wn = wrist_wrench_n;

  // ===== Sampled control at 100 Hz: tangential PID + normal-force PI with saturation =====
  when sample(0, sample_dt) then
    // Tangential trajectory control (PID)
    int_t = pre(int_t) + (s_ref - x_palm) * sample_dt;
    F_tang_cmd = Kp_t * (s_ref - x_palm) + Kd_t * (s_ref_dot - v_palm) + Ki_t * int_t;

    // Normal-force regulation (PI, symmetric on both fingers)
    int_n = pre(int_n) + (N_set - N_contact) * sample_dt;

    // Saturated finger commands (effort bounds: 0 to F_max per finger)
    F1_cmd = if (N_set/2.0 + Kp_n * (N_set - N_contact) + Ki_n * int_n) > F_max then F_max
             else if (N_set/2.0 + Kp_n * (N_set - N_contact) + Ki_n * int_n) < 0.0 then 0.0
             else (N_set/2.0 + Kp_n * (N_set - N_contact) + Ki_n * int_n);

    F2_cmd = if (N_set/2.0 + Kp_n * (N_set - N_contact) + Ki_n * int_n) > F_max then F_max
             else if (N_set/2.0 + Kp_n * (N_set - N_contact) + Ki_n * int_n) < 0.0 then 0.0
             else (N_set/2.0 + Kp_n * (N_set - N_contact) + Ki_n * int_n);
  end when;

  // ===== Constraint assertions =====
  assert(q1 >= -0.001 and q1 <= joint_travel + 0.001, "Finger 1 joint bound violated");
  assert(q2 >= -0.001 and q2 <= joint_travel + 0.001, "Finger 2 joint bound violated");
  assert(F1_cmd >= 0.0 and F1_cmd <= F_max + 0.001, "Finger 1 effort bound violated");
  assert(F2_cmd >= 0.0 and F2_cmd <= F_max + 0.001, "Finger 2 effort bound violated");
  assert(N_contact >= 0.0, "Normal contact force must be non-negative");
  assert(abs(x_palm) < 1e6, "Palm position must remain finite");
  assert(abs(N_contact) < 1e6, "Normal force must remain finite");

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "Parallel-grip polishing mission. Curved workpiece modeled as 1D tangential path of 0.50 m. Palm (6 kg) translates tangentially; two 0.5 kg fingers on prismatic joints (0.05 m travel) provide compliant normal grip. Finger actuators bounded at 36.9 N. Friction coeff 0.50. Normal force regulated to 21 N within 12-30 N band. Disturbance 4.9 N injected during middle third. Control at 100 Hz for 10 s."));

end ParallelGripPolishB;