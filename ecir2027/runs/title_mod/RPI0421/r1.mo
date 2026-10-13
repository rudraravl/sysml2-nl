model PlanarPusherPushA
  "Contact-rich planar pushing: 2-link capsule arm with rounded tool pushes a rigid box
   on a table along a two-segment reference using hybrid position-force control.
   NOTE: Capsule-link geometry and rounded-tool curvature are abstracted as point
   kinematic links with a spring-damper contact; facts not stated in the request
   (link radii, tool radius, link masses, exact box dimensions) are treated as unknown."
  import Modelica.Math;

  // ---- Physical parameters (SI) ----
  parameter Real L1      = 0.46  "link 1 length [m]";
  parameter Real L2      = 0.35  "link 2 length [m]";
  parameter Real J1      = 0.5   "joint 1 inertia [kg.m2]";
  parameter Real J2      = 0.3   "joint 2 inertia [kg.m2]";
  parameter Real b1      = 4.0   "joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2      = 3.0   "joint 2 viscous damping [N.m.s/rad]";
  parameter Real tau_max = 36.0  "joint torque command magnitude limit [N.m]";
  parameter Real m_box   = 1.2   "box mass [kg]";
  parameter Real I_box   = 0.02  "box yaw inertia [kg.m2]";
  parameter Real box_half= 0.05  "box half-length along forward axis [m]";
  parameter Real g       = 9.81  "gravity [m/s2]";
  parameter Real mu_bt   = 0.42  "box-table friction coefficient";
  parameter Real mu_tb   = 0.65  "tool-box friction coefficient";
  parameter Real k_c     = 6000.0 "contact stiffness [N/m]";
  parameter Real d_c     = 30.0   "contact damping [N.s/m]";

  // ---- Control parameters ----
  parameter Real Fn_set  = 15.0  "nominal target normal force [N]";
  parameter Real Fn_min  = 5.0   "minimum allowable normal force [N]";
  parameter Real Fn_max  = 25.0  "maximum allowable normal force [N]";
  parameter Real kp_q    = 300.0 "joint PD proportional [N.m/rad]";
  parameter Real kd_q    = 30.0  "joint PD derivative [N.m.s/rad]";
  parameter Real kp_pos  = 30.0  "hybrid position gain [N/m]";
  parameter Real kd_pos  = 15.0  "hybrid velocity gain [N.s/m]";
  parameter Real kff     = 1.0e-5 "force-loop proportional gain [m/N]";
  parameter Real kfi     = 5.0e-5 "force-loop integral gain [m/(N.s)]";
  parameter Real v_eps   = 0.02  "friction regularization velocity [m/s]";
  parameter Real T_sample= 0.0125 "control/sensor sample period (80 Hz) [s]";

  // ---- Reference path (two-segment planar) ----
  parameter Real x0 = 0.50 "start x [m]";
  parameter Real y0 = 0.00 "start y [m]";
  parameter Real x1 = 0.80 "end of segment 1 x [m]";
  parameter Real y1 = 0.10 "end of segment 1 y [m]";
  parameter Real x2 = 0.60 "end of segment 2 x [m]";
  parameter Real y2 = 0.30 "end of segment 2 y [m]";
  parameter Real T1 = 4.0  "segment 1 duration [s]";
  parameter Real T2 = 4.0  "segment 2 duration [s]";

  // ---- Dynamic states ----
  Real q1(start=0.8)    "joint 1 angle [rad]";
  Real q2(start=-2.0)   "joint 2 angle [rad]";
  Real dq1(start=0)     "joint 1 angular velocity [rad/s]";
  Real dq2(start=0)     "joint 2 angular velocity [rad/s]";
  Real bx(start=x0)     "box x position [m]";
  Real by(start=y0)     "box y position [m]";
  Real vbx(start=0)     "box x velocity [m/s]";
  Real vby(start=0)     "box y velocity [m/s]";
  Real yaw(start=0)     "box yaw angle [rad]";
  Real wyaw(start=0)    "box yaw rate [rad/s]";
  Real d_off_int(start=0) "force-loop integral state [m]";

  // ---- Algebraic / sensor variables ----
  Real Fn(start=10)       "normal contact force [N]";
  Real pen                "tool penetration along box forward axis [m]";
  Real d_off              "tool normal offset (force loop output) [m]";
  Real Fn_ref             "force reference from hybrid position loop [N]";
  Real tau1_cmd           "joint 1 commanded torque [N.m]";
  Real tau2_cmd           "joint 2 commanded torque [N.m]";
  Real tau1_sat           "joint 1 saturated torque [N.m]";
  Real tau2_sat           "joint 2 saturated torque [N.m]";
  Real ref_x              "reference x [m]";
  Real ref_y              "reference y [m]";
  Real ref_yaw            "reference yaw [rad]";
  Real ref_vx             "reference x velocity [m/s]";
  Real ref_vy             "reference y velocity [m/s]";
  Real track_err          "primary planar tracking error [m]";
  Real dist_force         "applied friction-change disturbance magnitude [N]";
  Real pe_x               "end-effector x [m]";
  Real pe_y               "end-effector y [m]";
  Real q1_des             "desired joint 1 angle [rad]";
  Real q2_des             "desired joint 2 angle [rad]";
  Real des_tool_x         "desired tool x [m]";
  Real des_tool_y         "desired tool y [m]";
  Real box_face_x         "box rear contact face x [m]";
  Real box_face_y         "box rear contact face y [m]";
  Real cx                 "box forward axis x component";
  Real cy                 "box forward axis y component";
  Real r2                 "IK reach squared [m2]";
  Real c2_arg             "IK cos(q2) argument";
  Real pos_err_t          "position error along tangent [m]";
  Real vel_err_t          "velocity error along tangent [m/s]";
  Real F_table_x          "table friction force x [N]";
  Real F_table_y          "table friction force y [N]";
  Real F_dist_x           "disturbance force x [N]";
  Real F_dist_y           "disturbance force y [N]";
  Real box_speed          "box planar speed [m/s]";
  Real v_forward          "box forward-axis velocity [m/s]";

  // ---- Synchronized 80 Hz output traces ----
  output Real o_q1        "sampled joint 1 angle [rad]";
  output Real o_q2        "sampled joint 2 angle [rad]";
  output Real o_dq1       "sampled joint 1 velocity [rad/s]";
  output Real o_dq2       "sampled joint 2 velocity [rad/s]";
  output Real o_bx        "sampled box x [m]";
  output Real o_by        "sampled box y [m]";
  output Real o_yaw       "sampled box yaw [rad]";
  output Real o_Fn        "sampled contact normal force [N]";
  output Real o_tau1      "sampled saturated joint 1 torque [N.m]";
  output Real o_tau2      "sampled saturated joint 2 torque [N.m]";
  output Real o_track_err "sampled tracking error [m]";
  output Real o_ref_x     "sampled reference x [m]";
  output Real o_ref_y     "sampled reference y [m]";

algorithm
  // ---- Two-segment planar reference trajectory ----
  if time <= T1 then
    ref_x   := x0 + (x1 - x0)*time/T1;
    ref_y   := y0 + (y1 - y0)*time/T1;
    ref_yaw := atan2(y1 - y0, x1 - x0);
    ref_vx  := (x1 - x0)/T1;
    ref_vy  := (y1 - y0)/T1;
  else
    ref_x   := x1 + (x2 - x1)*(time - T1)/T2;
    ref_y   := y1 + (y2 - y1)*(time - T1)/T2;
    ref_yaw := atan2(y2 - y1, x2 - x1);
    ref_vx  := (x2 - x1)/T2;
    ref_vy  := (y2 - y1)/T2;
  end if;

  // ---- Primary tracking error (Euclidean planar) ----
  track_err := sqrt((bx - ref_x)*(bx - ref_x) + (by - ref_y)*(by - ref_y));

  // ---- Controlled 3 N friction-change disturbance during middle third ----
  if time >= 8.0/3.0 and time <= 16.0/3.0 then
    dist_force := 3.0;
  else
    dist_force := 0.0;
  end if;

  // ---- Per-joint actuator magnitude saturation (36 N.m) ----
  if tau1_cmd > tau_max then
    tau1_sat := tau_max;
  elseif tau1_cmd < -tau_max then
    tau1_sat := -tau_max;
  else
    tau1_sat := tau1_cmd;
  end if;
  if tau2_cmd > tau_max then
    tau2_sat := tau_max;
  elseif tau2_cmd < -tau_max then
    tau2_sat := -tau_max;
  else
    tau2_sat := tau2_cmd;
  end if;

equation
  // ---- Box forward axis from yaw ----
  cx = cos(yaw);
  cy = sin(yaw);

  // ---- Box rear contact face (tool pushes from behind) ----
  box_face_x = bx - box_half*cx;
  box_face_y = by - box_half*cy;

  // ---- Desired tool position: behind box face by force-loop offset ----
  des_tool_x = box_face_x - d_off*cx;
  des_tool_y = box_face_y - d_off*cy;

  // ---- Inverse kinematics (elbow config with q2 negative) ----
  r2     = des_tool_x*des_tool_x + des_tool_y*des_tool_y;
  c2_arg = (r2 - L1*L1 - L2*L2)/(2.0*L1*L2);
  q2_des = -acos(max(-0.999, min(0.999, c2_arg)));
  q1_des = atan2(des_tool_y, des_tool_x)
           - atan2(L2*sin(q2_des), L1 + L2*cos(q2_des));

  // ---- Forward kinematics (end-effector / rounded tool center) ----
  pe_x = L1*cos(q1) + L2*cos(q1 + q2);
  pe_y = L1*sin(q1) + L2*sin(q1 + q2);

  // ---- Contact penetration along box forward axis ----
  pen = (box_face_x - pe_x)*cx + (box_face_y - pe_y)*cy;
  v_forward = vbx*cx + vby*cy;

  // ---- Spring-damper contact normal force (one-sided) ----
  Fn = if pen > 0.0 then k_c*pen + d_c*v_forward else 0.0;

  // ---- Hybrid position-force control ----
  // Position loop along path tangent -> force reference, bounded to [Fn_min, Fn_max]
  pos_err_t = (ref_x - bx)*cx + (ref_y - by)*cy;
  vel_err_t = (ref_vx - vbx)*cx + (ref_vy - vby)*cy;
  Fn_ref = max(Fn_min,
               min(Fn_max,
                   mu_bt*m_box*g + kp_pos*pos_err_t + kd_pos*vel_err_t));
  // Force loop -> tool normal offset (regulate penetration depth)
  der(d_off_int) = kfi*(Fn_ref - Fn);
  d_off = 0.001 + kff*(Fn_ref - Fn) + d_off_int;

  // ---- Joint torque commands (PD position control on IK targets) ----
  tau1_cmd = kp_q*(q1_des - q1) + kd_q*(0.0 - dq1);
  tau2_cmd = kp_q*(q2_des - q2) + kd_q*(0.0 - dq2);

  // ---- Robot joint dynamics ----
  der(q1) = dq1;
  der(q2) = dq2;
  J1*der(dq1) = tau1_sat - b1*dq1;
  J2*der(dq2) = tau2_sat - b2*dq2;

  // ---- Box planar dynamics ----
  der(bx)  = vbx;
  der(by)  = vby;
  der(yaw) = wyaw;

  // Box-table friction (regularized Coulomb; well-defined at zero velocity)
  box_speed = sqrt(vbx*vbx + vby*vby);
  F_table_x = mu_bt*m_box*g*tanh(vbx/v_eps);
  F_table_y = mu_bt*m_box*g*tanh(vby/v_eps);

  // Disturbance friction change opposes forward motion
  F_dist_x = dist_force*cx*tanh(v_forward/v_eps);
  F_dist_y = dist_force*cy*tanh(v_forward/v_eps);

  // Force balance: contact push minus table friction minus disturbance
  m_box*der(vbx) = Fn*cx - F_table_x - F_dist_x;
  m_box*der(vby) = Fn*cy - F_table_y - F_dist_y;

  // Yaw regulation toward reference heading (object planar pose)
  I_box*der(wyaw) = -1.5*(yaw - ref_yaw) - 0.8*wyaw;

  // ---- Synchronized 80 Hz state/command/sensor traces ----
  when sample(0.0, T_sample) then
    o_q1        = q1;
    o_q2        = q2;
    o_dq1       = dq1;
    o_dq2       = dq2;
    o_bx        = bx;
    o_by        = by;
    o_yaw       = yaw;
    o_Fn        = Fn;
    o_tau1      = tau1_sat;
    o_tau2      = tau2_sat;
    o_track_err = track_err;
    o_ref_x     = ref_x;
    o_ref_y     = ref_y;
  end when;

  annotation (
    experiment(StopTime=8.0, Tolerance=1e-6),
    Documentation(info="PlanarPusherPushA: 2-DOF planar pusher with hybrid position-force
      control pushes a rigid box on a frictional table along a two-segment reference.
      Capsule-link and rounded-tool geometry are abstracted as point kinematics with
      spring-damper contact. Joint torques are bounded to +/-36 N.m. Contact force is
      regulated to [5,25] N. A controlled 3 N friction change is applied during the
      middle third (8/3 s to 16/3 s). State, command, and sensor traces are sampled
      and synchronized at 80 Hz over an 8 s scenario."));
end PlanarPusherPushA;