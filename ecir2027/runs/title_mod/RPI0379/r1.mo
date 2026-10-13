model ParallelGripPolishA
  "Contact-rich parallel-grip polishing system with 80 Hz sampled control and traces.
   Unspecified compliance, curvature, damping, and controller gains are placeholder
   design values; they are labeled below. No separate estimator is specified by the
   requirement, so feedback uses direct sensor variables."

  // Scenario timing and sample rate
  parameter Real sample_rate = 80.0 "Hz";
  parameter Real sample_dt = 1.0/sample_rate "s";
  parameter Real run_time = 8.0 "s";

  // Requirement-stated physical parameters
  parameter Real m_palm = 6.0 "kg";
  parameter Real m_finger = 0.5 "kg";
  parameter Real joint_travel = 0.05 "m";
  parameter Real actuator_limit = 32.4 "N";
  parameter Real mu = 0.50;
  parameter Real path_length = 0.50 "m";
  parameter Real F_disturbance = 3.5 "N";
  parameter Real force_min = 12.0 "N";
  parameter Real force_max = 30.0 "N";
  parameter Real primary_error_limit = 0.027 "m";
  parameter Real primary_error_time = 5.2 "s";

  // Placeholder design values for facts not stated in the requirement
  parameter Real F_normal_target = 20.0 "N, chosen within required 12-30 N band";
  parameter Real k_pad = 1000.0 "N/m, placeholder normal contact/pad stiffness";
  parameter Real c_pad = 20.0 "N.s/m, placeholder normal contact/pad damping";
  parameter Real b_joint = 2.0 "N.s/m, placeholder prismatic joint damping";
  parameter Real k_end = 1.0e5 "N/m, placeholder joint end-stop stiffness";
  parameter Real c_end = 100.0 "N.s/m, placeholder joint end-stop damping";
  parameter Real R_curve = 1.0 "m, placeholder fixed curved-workpiece radius";
  parameter Real b_path = 2.0 "N.s/m, placeholder tangential surface drag";
  parameter Real v_tol = 1.0e-3 "m/s, friction regularization velocity";
  parameter Real q_tol = 1.0e-4 "m, contact indicator regularization length";
  parameter Real kp_q = 2000.0 "N/m, placeholder closure position gain";
  parameter Real kd_q = 100.0 "N.s/m, placeholder closure velocity gain";
  parameter Real k_force = 0.0002 "m/N, placeholder normal-force-to-closure gain";
  parameter Real kp_s = 200.0 "1/s^2, placeholder tangential path gain";
  parameter Real kd_s = 60.0 "1/s, placeholder tangential velocity gain";

  // Derived constants
  parameter Real m_eff = m_palm + 2.0*m_finger "kg";
  parameter Real v_path = path_length/run_time "m/s";
  parameter Real q0 = F_normal_target/k_pad "m, nominal closure for target normal force";

  // Continuous states
  Real q1(start=q0) "finger 1 closure/pad compression";
  Real v1(start=0) "finger 1 closure velocity";
  Real q2(start=q0) "finger 2 closure/pad compression";
  Real v2(start=0) "finger 2 closure velocity";
  Real s(start=0) "surface arc-length coordinate";
  Real vs(start=v_path) "tangential surface velocity";

  // Discrete control variables
  discrete Real sample_index(start=0);
  discrete Real q_ref(start=q0) "m, commanded closure";
  discrete Real u1_cmd(start=F_normal_target) "N, finger 1 effort command";
  discrete Real u2_cmd(start=F_normal_target) "N, finger 2 effort command";
  discrete Real F_t_cmd(start=b_path*v_path + mu*2.0*F_normal_target) "N, tangential wrist command";
  discrete Real s_ref_sampled(start=0) "m";
  discrete Real v_ref_sampled(start=v_path) "m/s";

  // Synchronized 80 Hz traces
  discrete Real trace_time(start=0);
  discrete Real trace_s(start=0);
  discrete Real trace_v(start=v_path);
  discrete Real trace_s_ref(start=0);
  discrete Real trace_path_error(start=0);
  discrete Real trace_primary_error(start=0);
  discrete Real trace_q1(start=q0);
  discrete Real trace_q2(start=q0);
  discrete Real trace_q_ref(start=q0);
  discrete Real trace_u1(start=F_normal_target);
  discrete Real trace_u2(start=F_normal_target);
  discrete Real trace_F_t(start=b_path*v_path + mu*2.0*F_normal_target);
  discrete Real trace_F_dist(start=0.0);
  discrete Real trace_F_normal(start=F_normal_target);
  discrete Real trace_wrist_t(start=b_path*v_path + mu*2.0*F_normal_target);
  discrete Real trace_wrist_n(start=F_normal_target);
  discrete Real trace_pose_x(start=0);
  discrete Real trace_pose_y(start=0);
  discrete Real trace_pose_theta(start=0);
  discrete Real trace_contact(start=1.0);

  // Continuous variables
  Real u1, u2, F_t;
  Real Fp1, Fp2, F_normal_total, normal_force, F_friction, F_dist, Fend1, Fend2;
  Real s_ref_c, v_ref_c, path_error_c, primary_tracking_error;
  Real theta, pose_x, pose_y, pose_theta;
  Real sensor_q1, sensor_q2, sensor_v1, sensor_v2;
  Real sensor_s, sensor_vs, sensor_normal_force, sensor_path_error;
  Real sensor_wrist_t, sensor_wrist_n, sensor_wrist_z;
  Real sensor_pose_x, sensor_pose_y, sensor_pose_theta;
  Real continuous_contact;
  Real joint1_bounded, joint2_bounded, effort1_bounded, effort2_bounded, normal_force_bounded;
  Real primary_error_after, primary_error_requirement_met;

equation
  // Reference path along fixed curved workpiece
  s_ref_c = path_length*min(max(time/run_time, 0.0), 1.0);
  v_ref_c = if time < run_time then v_path else 0.0;

  // Controlled surface-force disturbance during middle third of scenario
  F_dist = if time >= run_time/3.0 and time <= 2.0*run_time/3.0 then -F_disturbance else 0.0;

  // Compliant normal contact at opposing pads
  Fp1 = max(k_pad*q1 + c_pad*v1, 0.0);
  Fp2 = max(k_pad*q2 + c_pad*v2, 0.0);
  F_normal_total = Fp1 + Fp2;
  normal_force = 0.5*F_normal_total;

  // Tangential Coulomb-like friction with fixed workpiece
  F_friction = mu*F_normal_total*tanh(vs/v_tol);

  // Joint end-stop forces enforcing 0..joint_travel bounds
  Fend1 = if q1 > joint_travel then k_end*(q1 - joint_travel) + c_end*v1
          elseif q1 < 0.0 then k_end*q1 - c_end*v1
          else 0.0;
  Fend2 = if q2 > joint_travel then k_end*(q2 - joint_travel) + c_end*v2
          elseif q2 < 0.0 then k_end*q2 - c_end*v2
          else 0.0;

  // Held actuator commands
  u1 = u1_cmd;
  u2 = u2_cmd;
  F_t = F_t_cmd;

  // Finger closure dynamics
  der(q1) = v1;
  m_finger*der(v1) = u1 - Fp1 - b_joint*v1 - Fend1;
  der(q2) = v2;
  m_finger*der(v2) = u2 - Fp2 - b_joint*v2 - Fend2;

  // Tangential path dynamics
  der(s) = vs;
  m_eff*der(vs) = F_t + F_dist - F_friction - b_path*vs;

  // Tool-tip pose on fixed circular arc
  theta = s/R_curve;
  pose_x = R_curve*sin(theta);
  pose_y = R_curve*(1.0 - cos(theta));
  pose_theta = theta;

  // Sensors
  sensor_q1 = q1;
  sensor_q2 = q2;
  sensor_v1 = v1;
  sensor_v2 = v2;
  sensor_s = s;
  sensor_vs = vs;
  sensor_normal_force = normal_force;
  sensor_path_error = path_error_c;
  sensor_wrist_t = F_t + F_dist;
  sensor_wrist_n = normal_force;
  sensor_wrist_z = 0.0;
  sensor_pose_x = pose_x;
  sensor_pose_y = pose_y;
  sensor_pose_theta = pose_theta;

  // Error and requirement indicators
  path_error_c = s_ref_c - s;
  primary_tracking_error = abs(path_error_c);
  continuous_contact = 0.5*(tanh(q1/q_tol) + tanh(q2/q_tol));
  joint1_bounded = if q1 >= 0.0 and q1 <= joint_travel then 1.0 else 0.0;
  joint2_bounded = if q2 >= 0.0 and q2 <= joint_travel then 1.0 else 0.0;
  effort1_bounded = if abs(u1) <= actuator_limit then 1.0 else 0.0;
  effort2_bounded = if abs(u2) <= actuator_limit then 1.0 else 0.0;
  normal_force_bounded = if normal_force >= force_min and normal_force <= force_max then 1.0 else 0.0;
  primary_error_after = if time >= primary_error_time then primary_tracking_error else 0.0;
  primary_error_requirement_met =
    if time >= primary_error_time and primary_tracking_error <= primary_error_limit then 1.0 else 0.0;

  // Sampled control and synchronized traces at 80 Hz
  when sample(0, sample_dt) then
    sample_index = pre(sample_index) + 1.0;
    s_ref_sampled = path_length*min(max(time/run_time, 0.0), 1.0);
    v_ref_sampled = if time < run_time then v_path else 0.0;

    // Normal-force regulation via bounded closure commands
    q_ref = max(0.0, min(joint_travel, q0 + k_force*(F_normal_target - normal_force)));
    u1_cmd = max(-actuator_limit, min(actuator_limit, kp_q*(q_ref - q1) - kd_q*v1 + Fp1));
    u2_cmd = max(-actuator_limit, min(actuator_limit, kp_q*(q_ref - q2) - kd_q*v2 + Fp2));

    // Tangential trajectory control with friction feedforward
    F_t_cmd = m_eff*(kp_s*(s_ref_sampled - s) + kd_s*(v_ref_sampled - vs)) + b_path*v_ref_sampled + F_friction;

    trace_time = time;
    trace_s = sensor_s;
    trace_v = sensor_vs;
    trace_s_ref = s_ref_sampled;
    trace_path_error = s_ref_sampled - s;
    trace_primary_error = abs(s_ref_sampled - s);
    trace_q1 = sensor_q1;
    trace_q2 = sensor_q2;
    trace_q_ref = q_ref;
    trace_u1 = u1_cmd;
    trace_u2 = u2_cmd;
    trace_F_t = F_t_cmd;
    trace_F_dist = F_dist;
    trace_F_normal = sensor_normal_force;
    trace_wrist_t = sensor_wrist_t;
    trace_wrist_n = sensor_wrist_n;
    trace_pose_x = sensor_pose_x;
    trace_pose_y = sensor_pose_y;
    trace_pose_theta = sensor_pose_theta;
    trace_contact = continuous_contact;
  end when;

  annotation(experiment(StopTime=8.0, Tolerance=1e-4));
end ParallelGripPolishA;