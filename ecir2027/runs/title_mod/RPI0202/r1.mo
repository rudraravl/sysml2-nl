model RailArmTraceD
  "Instrumented fixed-base articulated manipulator: rail + 2-DOF planar arm with cubic trajectory tracking";

  // ======================== Physical Parameters ========================
  parameter Real L_rail = 1.4 "Rail length [m]";
  parameter Real m_carriage = 18.0 "Carriage mass [kg]";
  parameter Real L1 = 0.46 "Link 1 length [m]";
  parameter Real L2 = 0.31 "Link 2 length [m]";
  parameter Real m_link1 = 3.5 "Link 1 mass [kg] (assumed — not specified in requirement)";
  parameter Real m_link2 = 2.5 "Link 2 mass [kg] (assumed — not specified in requirement)";
  parameter Real q_limit = 1.5 "Joint limit magnitude [rad]";
  parameter Real F_max = 800.0 "Linear actuator force limit [N]";
  parameter Real tau_max = 85.0 "Rotary actuator torque limit [N.m]";
  parameter Real b_rail = 8.0 "Rail viscous damping [N.s/m]";
  parameter Real b_j1 = 0.8 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real b_j2 = 0.5 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real I1_eff = m_link1*(L1/2)^2 + m_link2*(L1 + L2/2)^2
    "Joint 1 effective inertia [kg.m^2]";
  parameter Real I2_eff = m_link2*(L2/2)^2
    "Joint 2 effective inertia [kg.m^2]";

  // Joint limit soft enforcement
  parameter Real K_limit = 1000.0 "Joint limit spring stiffness [N.m/rad]";
  parameter Real D_limit = 20.0 "Joint limit damping [N.m.s/rad]";
  parameter Real q_limit_margin = 0.1 "Soft limit activation margin [rad]";

  // ======================== Obstacle ========================
  parameter Real obs_x = 0.80 "Obstacle center X [m]";
  parameter Real obs_y = 0.30 "Obstacle center Y [m]";
  parameter Real obs_r = 0.06 "Obstacle radius [m]";
  parameter Real clearance_req = 0.05 "Required clearance [m]";

  // ======================== Trajectory Waypoints ========================
  parameter Real wp0_x = 0.30 "Waypoint 0 rail position [m]";
  parameter Real wp0_q1 = 0.20 "Waypoint 0 joint 1 [rad]";
  parameter Real wp0_q2 = 0.30 "Waypoint 0 joint 2 [rad]";
  parameter Real wp1_x = 0.70 "Waypoint 1 rail position [m]";
  parameter Real wp1_q1 = -0.50 "Waypoint 1 joint 1 [rad]";
  parameter Real wp1_q2 = 0.80 "Waypoint 1 joint 2 [rad]";
  parameter Real wp2_x = 0.40 "Waypoint 2 rail position [m]";
  parameter Real wp2_q1 = 0.60 "Waypoint 2 joint 1 [rad]";
  parameter Real wp2_q2 = -0.40 "Waypoint 2 joint 2 [rad]";
  parameter Real t_seg1 = 4.67 "Segment 1 duration [s]";
  parameter Real t_seg2 = 4.66 "Segment 2 duration [s]";

  // ======================== Disturbance ========================
  parameter Real F_dist = 10.0 "Lateral disturbance force magnitude [N]";

  // ======================== Control Gains (PID + velocity feedforward) ========================
  parameter Real Kp_x = 300.0 "Proportional gain, carriage";
  parameter Real Ki_x = 50.0 "Integral gain, carriage";
  parameter Real Kd_x = 90.0 "Derivative gain, carriage";
  parameter Real Kp_q1 = 50.0 "Proportional gain, joint 1";
  parameter Real Ki_q1 = 10.0 "Integral gain, joint 1";
  parameter Real Kd_q1 = 10.0 "Derivative gain, joint 1";
  parameter Real Kp_q2 = 20.0 "Proportional gain, joint 2";
  parameter Real Ki_q2 = 5.0 "Integral gain, joint 2";
  parameter Real Kd_q2 = 2.0 "Derivative gain, joint 2";

  // ======================== Sampling ========================
  parameter Real f_sample = 200.0 "Encoder sample rate [Hz]";
  parameter Real T_sample = 1.0/f_sample "Sample period [s]";
  parameter Real T_end = 14.0 "Total simulation duration [s]";

  // ======================== Continuous States ========================
  Real x(start=wp0_x, fixed=true) "Carriage position on rail [m]";
  Real v_x(start=0.0, fixed=true) "Carriage velocity [m/s]";
  Real q1(start=wp0_q1, fixed=true) "Joint 1 angle [rad]";
  Real w1(start=0.0, fixed=true) "Joint 1 angular velocity [rad/s]";
  Real q2(start=wp0_q2, fixed=true) "Joint 2 angle [rad]";
  Real w2(start=0.0, fixed=true) "Joint 2 angular velocity [rad/s]";

  // ======================== Continuous Trajectory References ========================
  Real x_ref "Reference carriage position [m]";
  Real v_x_ref "Reference carriage velocity [m/s]";
  Real q1_ref "Reference joint 1 angle [rad]";
  Real w1_ref "Reference joint 1 velocity [rad/s]";
  Real q2_ref "Reference joint 2 angle [rad]";
  Real w2_ref "Reference joint 2 velocity [rad/s]";
  Real tau_seg "Normalized segment time [0..1]";

  // ======================== Discrete States ========================
  discrete Integer seg(start=0) "Active trajectory segment";

  // Synchronized encoder samples
  discrete Real x_enc(start=wp0_x) "Sampled carriage position [m]";
  discrete Real v_x_enc(start=0.0) "Sampled carriage velocity [m/s]";
  discrete Real q1_enc(start=wp0_q1) "Sampled joint 1 position [rad]";
  discrete Real w1_enc(start=0.0) "Sampled joint 1 velocity [rad/s]";
  discrete Real q2_enc(start=wp0_q2) "Sampled joint 2 position [rad]";
  discrete Real w2_enc(start=0.0) "Sampled joint 2 velocity [rad/s]";
  discrete Real t_enc(start=0.0) "Sample time stamp [s]";

  // PID integrators
  discrete Real integ_x(start=0.0);
  discrete Real integ_q1(start=0.0);
  discrete Real integ_q2(start=0.0);

  // Discrete tracking errors
  discrete Real e_x_d(start=0.0) "Sampled position error x [m]";
  discrete Real e_q1_d(start=0.0) "Sampled position error q1 [rad]";
  discrete Real e_q2_d(start=0.0) "Sampled position error q2 [rad]";

  // Commands (discrete, synchronized)
  discrete Real F_cmd_raw(start=0.0) "Unsaturated force command [N]";
  discrete Real tau1_cmd_raw(start=0.0) "Unsaturated torque 1 command [N.m]";
  discrete Real tau2_cmd_raw(start=0.0) "Unsaturated torque 2 command [N.m]";
  discrete Real F_cmd(start=0.0) "Saturated force command [N]";
  discrete Real tau1_cmd(start=0.0) "Saturated torque 1 command [N.m]";
  discrete Real tau2_cmd(start=0.0) "Saturated torque 2 command [N.m]";

  // ======================== Continuous Algebraic ========================
  Real x_elbow "Elbow X position [m]";
  Real y_elbow "Elbow Y position [m]";
  Real x_ee "End-effector X position [m]";
  Real y_ee "End-effector Y position [m]";

  Real F_dist_applied "Applied lateral disturbance force [N]";
  Real tau_dist1 "Disturbance torque on joint 1 [N.m]";
  Real tau_dist2 "Disturbance torque on joint 2 [N.m]";

  Real tau_limit1 "Soft-limit restoring torque joint 1 [N.m]";
  Real tau_limit2 "Soft-limit restoring torque joint 2 [N.m]";

  // Obstacle clearance intermediates
  Real t1_proj "Projection parameter link 1";
  Real t2_proj "Projection parameter link 2";
  Real t1_clamp "Clamped projection link 1";
  Real t2_clamp "Clamped projection link 2";
  Real cx1 "Closest point X on link 1 [m]";
  Real cy1 "Closest point Y on link 1 [m]";
  Real cx2 "Closest point X on link 2 [m]";
  Real cy2 "Closest point Y on link 2 [m]";
  Real d_seg1 "Clearance to link 1 segment [m]";
  Real d_seg2 "Clearance to link 2 segment [m]";
  Real d_obs_ee "Clearance to end effector [m]";
  Real d_obs_elbow "Clearance to elbow [m]";
  Real d_obs_min "Minimum obstacle clearance [m]";

  // Continuous tracking errors
  Real e_x "Continuous tracking error x [m]";
  Real e_q1 "Continuous tracking error q1 [rad]";
  Real e_q2 "Continuous tracking error q2 [rad]";
  Real e_max "Maximum tracking error [m or rad]";

equation

  // ======================== Trajectory Segment Selection ========================
  when time >= t_seg1 and pre(seg) == 0 then
    seg = 1;
  end when;
  when time >= t_seg1 + t_seg2 and pre(seg) == 1 then
    seg = 2;
  end when;

  // ======================== Cubic Trajectory (smoothstep) ========================
  // s(tau) = 3*tau^2 - 2*tau^3,  ds/dtau = 6*tau - 6*tau^2
  // Zero velocity at every waypoint; hold at final state.
  if seg == 0 then
    tau_seg = time / t_seg1;
    x_ref = wp0_x + (wp1_x - wp0_x)*(3.0*tau_seg*tau_seg - 2.0*tau_seg*tau_seg*tau_seg);
    v_x_ref = (wp1_x - wp0_x)*(6.0*tau_seg - 6.0*tau_seg*tau_seg)/t_seg1;
    q1_ref = wp0_q1 + (wp1_q1 - wp0_q1)*(3.0*tau_seg*tau_seg - 2.0*tau_seg*tau_seg*tau_seg);
    w1_ref = (wp1_q1 - wp0_q1)*(6.0*tau_seg - 6.0*tau_seg*tau_seg)/t_seg1;
    q2_ref = wp0_q2 + (wp1_q2 - wp0_q2)*(3.0*tau_seg*tau_seg - 2.0*tau_seg*tau_seg*tau_seg);
    w2_ref = (wp1_q2 - wp0_q2)*(6.0*tau_seg - 6.0*tau_seg*tau_seg)/t_seg1;
  elseif seg == 1 then
    tau_seg = (time - t_seg1)/t_seg2;
    x_ref = wp1_x + (wp2_x - wp1_x)*(3.0*tau_seg*tau_seg - 2.0*tau_seg*tau_seg*tau_seg);
    v_x_ref = (wp2_x - wp1_x)*(6.0*tau_seg - 6.0*tau_seg*tau_seg)/t_seg2;
    q1_ref = wp1_q1 + (wp2_q1 - wp1_q1)*(3.0*tau_seg*tau_seg - 2.0*tau_seg*tau_seg*tau_seg);
    w1_ref = (wp2_q1 - wp1_q1)*(6.0*tau_seg - 6.0*tau_seg*tau_seg)/t_seg2;
    q2_ref = wp1_q2 + (wp2_q2 - wp1_q2)*(3.0*tau_seg*tau_seg - 2.0*tau_seg*tau_seg*tau_seg);
    w2_ref = (wp2_q2 - wp1_q2)*(6.0*tau_seg - 6.0*tau_seg*tau_seg)/t_seg2;
  else
    // Hold at final waypoint
    tau_seg = 1.0;
    x_ref = wp2_x;
    v_x_ref = 0.0;
    q1_ref = wp2_q1;
    w1_ref = 0.0;
    q2_ref = wp2_q2;
    w2_ref = 0.0;
  end if;

  // ======================== Digital Control Loop at 200 Hz ========================
  when sample(0, T_sample) then
    // --- Synchronized encoder samples ---
    x_enc = x;
    v_x_enc = v_x;
    q1_enc = q1;
    w1_enc = w1;
    q2_enc = q2;
    w2_enc = w2;
    t_enc = time;

    // --- Tracking errors ---
    e_x_d = x_ref - x_enc;
    e_q1_d = q1_ref - q1_enc;
    e_q2_d = q2_ref - q2_enc;

    // --- PID integrators with anti-windup clamping ---
    integ_x = max(-F_max/max(1e-6, Ki_x),
                  min(F_max/max(1e-6, Ki_x), pre(integ_x) + T_sample*e_x_d));
    integ_q1 = max(-tau_max/max(1e-6, Ki_q1),
                   min(tau_max/max(1e-6, Ki_q1), pre(integ_q1) + T_sample*e_q1_d));
    integ_q2 = max(-tau_max/max(1e-6, Ki_q2),
                   min(tau_max/max(1e-6, Ki_q2), pre(integ_q2) + T_sample*e_q2_d));

    // --- PID + velocity feedforward (friction compensation) ---
    F_cmd_raw = Kp_x*e_x_d + Ki_x*integ_x + Kd_x*(v_x_ref - v_x_enc) + b_rail*v_x_ref;
    tau1_cmd_raw = Kp_q1*e_q1_d + Ki_q1*integ_q1 + Kd_q1*(w1_ref - w1_enc) + b_j1*w1_ref;
    tau2_cmd_raw = Kp_q2*e_q2_d + Ki_q2*integ_q2 + Kd_q2*(w2_ref - w2_enc) + b_j2*w2_ref;

    // --- Actuator saturation ---
    F_cmd = max(-F_max, min(F_max, F_cmd_raw));
    tau1_cmd = max(-tau_max, min(tau_max, tau1_cmd_raw));
    tau2_cmd = max(-tau_max, min(tau_max, tau2_cmd_raw));
  end when;

  // ======================== Disturbance: middle third of 14 s ========================
  // Active during [t_seg1, t_seg1 + t_seg2] = [4.67, 9.33] s
  if time >= t_seg1 and time <= t_seg1 + t_seg2 then
    F_dist_applied = F_dist;
  else
    F_dist_applied = 0.0;
  end if;

  // Lateral (Y-direction) force at end-effector maps to joint torques via Jacobian transpose
  tau_dist1 = -(L1*sin(q1) + L2*sin(q1 + q2)) * F_dist_applied;
  tau_dist2 = -L2*sin(q1 + q2) * F_dist_applied;

  // ======================== Soft Joint Limits ========================
  if q1 > q_limit - q_limit_margin then
    tau_limit1 = -K_limit*(q1 - (q_limit - q_limit_margin)) - D_limit*w1;
  elseif q1 < -(q_limit - q_limit_margin) then
    tau_limit1 = -K_limit*(q1 + (q_limit - q_limit_margin)) - D_limit*w1;
  else
    tau_limit1 = 0.0;
  end if;

  if q2 > q_limit - q_limit_margin then
    tau_limit2 = -K_limit*(q2 - (q_limit - q_limit_margin)) - D_limit*w2;
  elseif q2 < -(q_limit - q_limit_margin) then
    tau_limit2 = -K_limit*(q2 + (q_limit - q_limit_margin)) - D_limit*w2;
  else
    tau_limit2 = 0.0;
  end if;

  // ======================== Plant Dynamics ========================
  // Carriage (linear DOF along rail)
  m_carriage * der(v_x) = F_cmd - b_rail*v_x;
  der(x) = v_x;

  // Joint 1 (rotary)
  I1_eff * der(w1) = tau1_cmd + tau_dist1 + tau_limit1 - b_j1*w1;
  der(q1) = w1;

  // Joint 2 (rotary)
  I2_eff * der(w2) = tau2_cmd + tau_dist2 + tau_limit2 - b_j2*w2;
  der(q2) = w2;

  // ======================== Forward Kinematics ========================
  // Arm in vertical plane: X horizontal (rail), Y vertical (up)
  // q1 measured from vertical (Y axis)
  x_elbow = x + L1*sin(q1);
  y_elbow = L1*cos(q1);
  x_ee = x_elbow + L2*sin(q1 + q2);
  y_ee = y_elbow + L2*cos(q1 + q2);

  // ======================== Obstacle Clearance ========================
  // Point-to-segment distance for each link vs cylindrical obstacle

  // Link 1: carriage (x, 0) to elbow (x_elbow, y_elbow)
  t1_proj = ((obs_x - x)*(x_elbow - x) + obs_y*y_elbow) /
            max(1e-9, (x_elbow - x)*(x_elbow - x) + y_elbow*y_elbow);
  t1_clamp = max(0.0, min(1.0, t1_proj));
  cx1 = x + t1_clamp*(x_elbow - x);
  cy1 = t1_clamp*y_elbow;
  d_seg1 = sqrt(max(1e-9, (obs_x - cx1)*(obs_x - cx1) + (obs_y - cy1)*(obs_y - cy1))) - obs_r;

  // Link 2: elbow (x_elbow, y_elbow) to end-effector (x_ee, y_ee)
  t2_proj = ((obs_x - x_elbow)*(x_ee - x_elbow) + (obs_y - y_elbow)*(y_ee - y_elbow)) /
            max(1e-9, (x_ee - x_elbow)*(x_ee - x_elbow) + (y_ee - y_elbow)*(y_ee - y_elbow));
  t2_clamp = max(0.0, min(1.0, t2_proj));
  cx2 = x_elbow + t2_clamp*(x_ee - x_elbow);
  cy2 = y_elbow + t2_clamp*(y_ee - y_elbow);
  d_seg2 = sqrt(max(1e-9, (obs_x - cx2)*(obs_x - cx2) + (obs_y - cy2)*(obs_y - cy2))) - obs_r;

  // Point distances
  d_obs_ee = sqrt(max(1e-9, (x_ee - obs_x)*(x_ee - obs_x) + (y_ee - obs_y)*(y_ee - obs_y))) - obs_r;
  d_obs_elbow = sqrt(max(1e-9, (x_elbow - obs_x)*(x_elbow - obs_x) + (y_elbow - obs_y)*(y_elbow - obs_y))) - obs_r;

  // Overall minimum clearance
  d_obs_min = min(d_seg1, min(d_seg2, min(d_obs_ee, d_obs_elbow)));

  // ======================== Continuous Tracking Errors ========================
  e_x = x_ref - x;
  e_q1 = q1_ref - q1;
  e_q2 = q2_ref - q2;
  e_max = max(abs(e_x), max(abs(e_q1), abs(e_q2)));

  // ======================== Requirement Assertions ========================
  assert(abs(q1) <= q_limit, "Joint 1 limit exceeded");
  assert(abs(q2) <= q_limit, "Joint 2 limit exceeded");
  assert(d_obs_min > clearance_req, "Obstacle clearance below 0.05 m");
  assert(x >= -0.01 and x <= L_rail + 0.01, "Carriage outside rail bounds");

  annotation (
    Documentation(info="RailArmTraceD: 1.4 m rail, 18 kg carriage, 2-DOF planar arm (0.46 m, 0.31 m links).
      Cubic trajectory through 3 waypoints with PID + velocity-feedforward at 200 Hz.
      10 N lateral disturbance during middle third. Joint limits +/-1.5 rad. Obstacle keep-out.
      Link masses are assumed (not specified in requirement)."),
    experiment(StartTime=0, StopTime=14.0, Tolerance=1e-6, Interval=0.005)
  );

end RailArmTraceD;