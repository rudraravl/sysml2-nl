model CartesianToolPushA
  "Contact-rich Cartesian tool pushing with hybrid position-force control.
   X and Y are position controlled along a two-segment planar reference;
   Z is force controlled to regulate a vertical normal pushing contact force.
   Stated facts only: tool mass, strokes, force limit, friction coefficients,
   3 N friction disturbance, 80 Hz/8 s scenario, force range, tracking threshold.
   Box inertial mass is not stated, so object motion is represented by a
   friction-limited kinematic coupling rather than an invented mass."

  // Stated physical parameters
  parameter Real m_tool(final unit="kg") = 2.5 "tool carriage mass";
  parameter Real F_lim(final unit="N") = 252.0 "per-axis actuator command magnitude limit";
  parameter Real x_min(final unit="m") = -0.10 "X stroke lower bound";
  parameter Real x_max(final unit="m") = 0.10 "X stroke upper bound";
  parameter Real y_min(final unit="m") = -0.10 "Y stroke lower bound";
  parameter Real y_max(final unit="m") = 0.10 "Y stroke upper bound";
  parameter Real z_min(final unit="m") = -0.30 "Z stroke lower bound";
  parameter Real z_max(final unit="m") = 0.30 "Z stroke upper bound";
  parameter Real mu_box_table = 0.42 "box-table friction coefficient";
  parameter Real mu_tool_box = 0.65 "tool-box friction coefficient";
  parameter Real F_disturbance(final unit="N") = 3.0 "controlled friction change disturbance";

  // Scenario timing
  parameter Real T(final unit="s") = 8.0 "scenario duration";
  parameter Real Ts(final unit="s") = 0.0125 "control and trace period, 80 Hz";
  parameter Integer N = 640 "number of synchronized trace samples";
  parameter Real T1(final unit="s") = T/2 "first reference segment duration";
  parameter Real T2(final unit="s") = T/2 "second reference segment duration";

  // Contact and control design constants
  // Reference waypoints are not stated; chosen within the stated X/Y stroke.
  parameter Real p1x(final unit="m") = 0.06 "first-segment X end, within stroke";
  parameter Real p2y(final unit="m") = 0.05 "second-segment Y end, within stroke";
  parameter Real Fc_ref(final unit="N") = 22.0 "normal contact force setpoint, within 5..25 N";
  parameter Real c_contact(final unit="N/m") = 10000.0 "vertical contact stiffness";
  parameter Real d_contact(final unit="N.s/m") = 200.0 "vertical contact damping";
  parameter Real Kp_pos(final unit="N/m") = 1500.0 "X/Y position gain";
  parameter Real Kd_pos(final unit="N.s/m") = 80.0 "X/Y velocity gain";
  parameter Real Kf(final unit="1") = 20.0 "Z normal force gain";
  parameter Real Kd_z(final unit="N.s/m") = 40.0 "Z velocity damping gain";
  parameter Real b_tool(final unit="N.s/m") = 2.0 "tool lateral damping";
  parameter Real b_tool_z(final unit="N.s/m") = 2.0 "tool vertical damping";
  parameter Real tau_obj(final unit="s") = 0.04 "object planar tracking time constant";
  parameter Real tau_yaw(final unit="s") = 0.10 "object yaw damping time constant";
  parameter Real tau_sensor(final unit="s") = 0.02 "contact force estimator time constant";
  constant Real g(final unit="m/s2") = 9.81 "standard gravity";

  // Robot state
  Real x_tool(start=0, unit="m") "tool X position";
  Real y_tool(start=0, unit="m") "tool Y position";
  Real z_tool(start=0.0022, unit="m") "tool Z position, positive downward from table surface";
  Real vx(start=0, unit="m/s") "tool X velocity";
  Real vy(start=0, unit="m/s") "tool Y velocity";
  Real vz(start=0, unit="m/s") "tool Z velocity, positive downward";

  // Object planar pose
  Real bx(start=0, unit="m") "object X position";
  Real by(start=0, unit="m") "object Y position";
  Real btheta(start=0, unit="rad") "object yaw angle";
  Real bvx(start=0, unit="m/s") "object X velocity";
  Real bvy(start=0, unit="m/s") "object Y velocity";
  Real bomega(start=0, unit="rad/s") "object yaw rate";

  // Contact and sensor
  Real Fc(unit="N") "measured vertical normal contact force";
  Real Fc_est(start=22, unit="N") "filtered contact force estimate";
  Real delta_z(unit="m") "tool-table contact penetration";

  // Actuator commands
  discrete Real Fx_cmd_raw(start=0, unit="N") "unsaturated X force command";
  discrete Real Fy_cmd_raw(start=0, unit="N") "unsaturated Y force command";
  discrete Real Fz_cmd_raw(start=-2.525, unit="N") "unsaturated Z force command";
  Real Fx_cmd(unit="N") "saturated X force command";
  Real Fy_cmd(unit="N") "saturated Y force command";
  Real Fz_cmd(unit="N") "saturated Z force command";
  Real Fx(unit="N") "applied X actuator force";
  Real Fy(unit="N") "applied Y actuator force";
  Real Fz(unit="N") "applied Z actuator force";

  // Reference and monitoring
  Real x_ref(unit="m") "planar reference X";
  Real y_ref(unit="m") "planar reference Y";
  Real v_ref_x(unit="m/s") "reference X velocity";
  Real v_ref_y(unit="m/s") "reference Y velocity";
  Real theta_ref(unit="rad") "reference yaw, not stated so zero";
  Real F_dist(unit="N") "active friction disturbance force";
  Real F_drive_max(unit="N") "maximum tool-box friction drive force";
  Real F_resist(unit="N") "box-table resistance force plus disturbance";
  Real motion_scale "friction-limited object motion scale, 0..1";
  Real v_obj_ref_x(unit="m/s") "friction-limited object X velocity reference";
  Real v_obj_ref_y(unit="m/s") "friction-limited object Y velocity reference";
  Real tracking_error(unit="m") "primary object planar tracking error";
  Real yaw_error(unit="rad") "object yaw error";

  // Final pose (observable at end of simulation)
  Real final_bx(unit="m") "final object X pose";
  Real final_by(unit="m") "final object Y pose";
  Real final_btheta(unit="rad") "final object yaw pose";

  // Synchronized traces at 80 Hz for 8 s
  Integer n(start=1) "trace write index";
  discrete Real trace_t[N](each start=0, each unit="s");
  discrete Real trace_x_tool[N](each start=0, each unit="m");
  discrete Real trace_y_tool[N](each start=0, each unit="m");
  discrete Real trace_z_tool[N](each start=0, each unit="m");
  discrete Real trace_vx[N](each start=0, each unit="m/s");
  discrete Real trace_vy[N](each start=0, each unit="m/s");
  discrete Real trace_vz[N](each start=0, each unit="m/s");
  discrete Real trace_bx[N](each start=0, each unit="m");
  discrete Real trace_by[N](each start=0, each unit="m");
  discrete Real trace_btheta[N](each start=0, each unit="rad");
  discrete Real trace_Fx_cmd[N](each start=0, each unit="N");
  discrete Real trace_Fy_cmd[N](each start=0, each unit="N");
  discrete Real trace_Fz_cmd[N](each start=0, each unit="N");
  discrete Real trace_Fc_meas[N](each start=0, each unit="N");
  discrete Real trace_Fc_est[N](each start=0, each unit="N");
  discrete Real trace_tracking_error[N](each start=0, each unit="m");
  discrete Real trace_F_dist[N](each start=0, each unit="N");

initial equation
  x_tool = 0.0;
  y_tool = 0.0;
  z_tool = 0.0022;
  vx = 0.0;
  vy = 0.0;
  vz = 0.0;
  bx = 0.0;
  by = 0.0;
  btheta = 0.0;
  bvx = 0.0;
  bvy = 0.0;
  bomega = 0.0;
  Fc_est = 22.0;

equation
  // Robot state dynamics
  der(x_tool) = vx;
  der(y_tool) = vy;
  der(z_tool) = vz;
  m_tool*der(vx) = Fx - b_tool*vx;
  m_tool*der(vy) = Fy - b_tool*vy;
  m_tool*der(vz) = Fz + m_tool*g - Fc - b_tool_z*vz;

  // Object planar kinematic tracking
  der(bx) = bvx;
  der(by) = bvy;
  der(btheta) = bomega;
  der(bvx) = (v_obj_ref_x - bvx)/tau_obj;
  der(bvy) = (v_obj_ref_y - bvy)/tau_obj;
  der(bomega) = (0.0 - bomega)/tau_yaw;

  // Two-segment planar reference
  x_ref = if time < T1 then p1x*time/T1 else p1x;
  y_ref = if time < T1 then 0.0 else p2y*(time - T1)/T2;
  v_ref_x = if time < T1 then p1x/T1 else 0.0;
  v_ref_y = if time < T1 then 0.0 else p2y/T2;
  theta_ref = 0.0;

  // Controlled friction disturbance during middle third of scenario
  F_dist = if time >= T/3 and time <= 2*T/3 then F_disturbance else 0.0;

  // Friction-limited object motion coupling
  F_drive_max = mu_tool_box*Fc;
  F_resist = mu_box_table*Fc + F_dist;
  motion_scale = if Fc <= 1.0e-6 then 0.0 elseif F_drive_max >= F_resist then 1.0 else F_drive_max/F_resist;
  v_obj_ref_x = motion_scale*v_ref_x;
  v_obj_ref_y = motion_scale*v_ref_y;

  // Vertical contact force model with rigid table at z=0
  delta_z = if z_tool > 0.0 then z_tool else 0.0;
  Fc = c_contact*delta_z + d_contact*(if z_tool > 0.0 then vz else 0.0);

  // Contact force estimator/sensor filter
  der(Fc_est) = (Fc - Fc_est)/tau_sensor;

  // Actuator saturation and application
  Fx_cmd = if Fx_cmd_raw > F_lim then F_lim elseif Fx_cmd_raw < -F_lim then -F_lim else Fx_cmd_raw;
  Fy_cmd = if Fy_cmd_raw > F_lim then F_lim elseif Fy_cmd_raw < -F_lim then -F_lim else Fy_cmd_raw;
  Fz_cmd = if Fz_cmd_raw > F_lim then F_lim elseif Fz_cmd_raw < -F_lim then -F_lim else Fz_cmd_raw;
  Fx = Fx_cmd;
  Fy = Fy_cmd;
  Fz = Fz_cmd;

  // Final pose (value at end of simulation)
  final_bx = bx;
  final_by = by;
  final_btheta = btheta;

  // Monitoring
  tracking_error = sqrt((x_ref - bx)^2 + (y_ref - by)^2);
  yaw_error = btheta - theta_ref;

  // Requirements enforcement
  assert(abs(x_tool) <= x_max + 1.0e-9, "X stroke bound violated");
  assert(abs(y_tool) <= y_max + 1.0e-9, "Y stroke bound violated");
  assert(abs(z_tool) <= z_max + 1.0e-9, "Z stroke bound violated");
  assert(abs(Fx_cmd) <= F_lim + 1.0e-6, "X actuator command bound violated");
  assert(abs(Fy_cmd) <= F_lim + 1.0e-6, "Y actuator command bound violated");
  assert(abs(Fz_cmd) <= F_lim + 1.0e-6, "Z actuator command bound violated");
  assert(Fc >= 5.0 - 1.0e-6 and Fc <= 25.0 + 1.0e-6, "Contact force outside 5..25 N");
  assert(time <= 5.2 or tracking_error < 0.054, "Primary tracking error exceeds 0.054 m after 5.2 s");

  // Discrete hybrid controller and synchronized trace storage at 80 Hz
  when sample(0, Ts) then
    // Hybrid position-force control:
    // X/Y position control along planar reference, Z normal force control.
    Fx_cmd_raw := Kp_pos*(x_ref - x_tool) + Kd_pos*(v_ref_x - vx);
    Fy_cmd_raw := Kp_pos*(y_ref - y_tool) + Kd_pos*(v_ref_y - vy);
    Fz_cmd_raw := (Fc_ref - m_tool*g) + Kf*(Fc_ref - Fc) - Kd_z*vz;

    trace_t[n] := time;
    trace_x_tool[n] := x_tool;
    trace_y_tool[n] := y_tool;
    trace_z_tool[n] := z_tool;
    trace_vx[n] := vx;
    trace_vy[n] := vy;
    trace_vz[n] := vz;
    trace_bx[n] := bx;
    trace_by[n] := by;
    trace_btheta[n] := btheta;
    trace_Fx_cmd[n] := Fx_cmd;
    trace_Fy_cmd[n] := Fy_cmd;
    trace_Fz_cmd[n] := Fz_cmd;
    trace_Fc_meas[n] := Fc;
    trace_Fc_est[n] := Fc_est;
    trace_tracking_error[n] := tracking_error;
    trace_F_dist[n] := F_dist;

    n := if n < N then n + 1 else N;
  end when;

  annotation(
    experiment(StopTime=8.0, Tolerance=1.0e-6, Interval=0.0125),
    Documentation(info="CartesianToolPushA: three prismatic axes, force-limited actuators,
 hybrid position-force control, friction-limited box pushing, 80 Hz synchronized traces."));
end CartesianToolPushA;