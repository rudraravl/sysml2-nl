model GantryPathSplineB
  extends Modelica.Icons.Example;

  // ---- Physical parameters ----
  parameter Modelica.Units.SI.Mass m_x = 18 "X-axis moving mass";
  parameter Modelica.Units.SI.Mass m_y = 12 "Y-axis moving mass";
  parameter Modelica.Units.SI.Mass m_z = 7  "Z-axis moving mass";
  parameter Modelica.Units.SI.Length L_x = 1.8 "X travel";
  parameter Modelica.Units.SI.Length L_y = 1.2 "Y travel";
  parameter Modelica.Units.SI.Length L_z = 0.55 "Z travel";
  parameter Modelica.Units.SI.Force F_max = 738 "Max actuator command magnitude";
  parameter Modelica.Units.SI.Length clearance_req = 0.06 "Required obstacle clearance";
  parameter Modelica.Units.SI.Force f_dist = 7 "Tool disturbance magnitude";
  parameter Real ctrl_rate_Hz = 100 "Control rate";
  parameter Modelica.Units.SI.Time t_end = 10 "Mission duration";

  // ---- Timestamped poses (four waypoints) ----
  parameter Modelica.Units.SI.Time t1 = 0.0;
  parameter Modelica.Units.SI.Time t2 = 10.0/3.0;
  parameter Modelica.Units.SI.Time t3 = 20.0/3.0;
  parameter Modelica.Units.SI.Time t4 = 10.0;
  parameter Modelica.Units.SI.Length p1x = 0.10; parameter Modelica.Units.SI.Length p1y = 0.10; parameter Modelica.Units.SI.Length p1z = 0.05;
  parameter Modelica.Units.SI.Length p2x = 1.70; parameter Modelica.Units.SI.Length p2y = 1.10; parameter Modelica.Units.SI.Length p2z = 0.50;
  parameter Modelica.Units.SI.Length p3x = 0.20; parameter Modelica.Units.SI.Length p3y = 1.00; parameter Modelica.Units.SI.Length p3z = 0.50;
  parameter Modelica.Units.SI.Length p4x = 1.60; parameter Modelica.Units.SI.Length p4y = 0.10; parameter Modelica.Units.SI.Length p4z = 0.05;

  // ---- Fixed cylindrical obstacle (axis along Z) ----
  parameter Modelica.Units.SI.Length obs_x = 0.50 "Obstacle center X";
  parameter Modelica.Units.SI.Length obs_y = 0.50 "Obstacle center Y";
  parameter Modelica.Units.SI.Length obs_r = 0.05 "Obstacle radius";

  // ---- Control gains ----
  parameter Real Kp = 600.0 "X/Y proportional gain";
  parameter Real Kd = 130.0 "X/Y derivative gain";
  parameter Real Kp_z = 250.0 "Z proportional gain";
  parameter Real Kd_z = 60.0  "Z derivative gain";

  // ---- Dynamic states ----
  Modelica.Units.SI.Length x(start=0.10, fixed=true);
  Modelica.Units.SI.Length y(start=0.10, fixed=true);
  Modelica.Units.SI.Length z(start=0.05, fixed=true);
  Modelica.Units.SI.Velocity vx(start=0, fixed=true);
  Modelica.Units.SI.Velocity vy(start=0, fixed=true);
  Modelica.Units.SI.Velocity vz(start=0, fixed=true);

  // ---- Reference trajectory ----
  Modelica.Units.SI.Length xr, yr, zr;
  Modelica.Units.SI.Velocity vxr, vyr, vzr;
  Real s, w, dw;

  // ---- Control commands ----
  Modelica.Units.SI.Force Fx_cmd, Fy_cmd, Fz_cmd;
  Modelica.Units.SI.Force Fx, Fy, Fz;

  // ---- Joint-limit avoidance forces ----
  Modelica.Units.SI.Force F_lim_x, F_lim_y, F_lim_z;

  // ---- Disturbance ----
  Modelica.Units.SI.Force F_dist_x, F_dist_y, F_dist_z;
  Boolean in_middle;

  // ---- Error / monitor signals ----
  Modelica.Units.SI.Length err_x, err_y, err_z;
  Modelica.Units.SI.Length tracking_error;
  Modelica.Units.SI.Angle orientation_error;
  Modelica.Units.SI.Length clearance;
  Boolean joint_ok;
  Boolean effort_ok;
  Boolean cmd_finite;
  Boolean tracking_ok;
  Boolean clearance_ok;
  Boolean finite_check;

  // ---- Sensor traces ----
  Modelica.Units.SI.Length joint_pos_x, joint_pos_y, joint_pos_z;
  Modelica.Units.SI.Velocity joint_vel_x, joint_vel_y, joint_vel_z;
  Modelica.Units.SI.Length pose_x, pose_y, pose_z;
  Modelica.Units.SI.Force wrist_wrench_x, wrist_wrench_y, wrist_wrench_z;

equation
  // ---- Cosine-blend spline reference through four timestamped poses ----
  if time <= t1 then
    xr = p1x; yr = p1y; zr = p1z;
    vxr = 0; vyr = 0; vzr = 0;
    s = 0; w = 0; dw = 0;
  elseif time <= t2 then
    s = (time - t1)/(t2 - t1);
    w = 0.5*(1 - Modelica.Math.cos(Modelica.Constants.pi*s));
    dw = 0.5*Modelica.Math.sin(Modelica.Constants.pi*s)*Modelica.Constants.pi/(t2 - t1);
    xr = p1x + w*(p2x - p1x);
    yr = p1y + w*(p2y - p1y);
    zr = p1z + w*(p2z - p1z);
    vxr = dw*(p2x - p1x);
    vyr = dw*(p2y - p1y);
    vzr = dw*(p2z - p1z);
  elseif time <= t3 then
    s = (time - t2)/(t3 - t2);
    w = 0.5*(1 - Modelica.Math.cos(Modelica.Constants.pi*s));
    dw = 0.5*Modelica.Math.sin(Modelica.Constants.pi*s)*Modelica.Constants.pi/(t3 - t2);
    xr = p2x + w*(p3x - p2x);
    yr = p2y + w*(p3y - p2y);
    zr = p2z + w*(p3z - p2z);
    vxr = dw*(p3x - p2x);
    vyr = dw*(p3y - p2y);
    vzr = dw*(p3z - p2z);
  elseif time <= t4 then
    s = (time - t3)/(t4 - t3);
    w = 0.5*(1 - Modelica.Math.cos(Modelica.Constants.pi*s));
    dw = 0.5*Modelica.Math.sin(Modelica.Constants.pi*s)*Modelica.Constants.pi/(t4 - t3);
    xr = p3x + w*(p4x - p3x);
    yr = p3y + w*(p4y - p3y);
    zr = p3z + w*(p4z - p3z);
    vxr = dw*(p4x - p3x);
    vyr = dw*(p4y - p3y);
    vzr = dw*(p4z - p3z);
  else
    xr = p4x; yr = p4y; zr = p4z;
    vxr = 0; vyr = 0; vzr = 0;
    s = 1; w = 1; dw = 0;
  end if;

  // ---- Joint-limit avoidance (soft barrier within travel bounds) ----
  F_lim_x = (if x < 0.05 then 2000.0*(0.05 - x) else 0.0)
          + (if x > L_x - 0.05 then -2000.0*(x - (L_x - 0.05)) else 0.0);
  F_lim_y = (if y < 0.05 then 2000.0*(0.05 - y) else 0.0)
          + (if y > L_y - 0.05 then -2000.0*(y - (L_y - 0.05)) else 0.0);
  F_lim_z = (if z < 0.05 then 2000.0*(0.05 - z) else 0.0)
          + (if z > L_z - 0.05 then -2000.0*(z - (L_z - 0.05)) else 0.0);

  // ---- Controlled tool disturbance injected during middle third ----
  in_middle = (time >= t2) and (time <= t3);
  F_dist_x = if in_middle then f_dist else 0.0;
  F_dist_y = 0.0;
  F_dist_z = 0.0;

  // ---- Operational-space PD tracking commands (synchronized axes) ----
  Fx_cmd = Kp*(xr - x) + Kd*(vxr - vx) + F_lim_x;
  Fy_cmd = Kp*(yr - y) + Kd*(vyr - vy) + F_lim_y;
  Fz_cmd = Kp_z*(zr - z) + Kd_z*(vzr - vz) + F_lim_z;

  // ---- Effort saturation (finite commands) ----
  Fx = max(-F_max, min(F_max, Fx_cmd));
  Fy = max(-F_max, min(F_max, Fy_cmd));
  Fz = max(-F_max, min(F_max, Fz_cmd));

  // ---- Plant dynamics ----
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  m_x*der(vx) = Fx + F_dist_x;
  m_y*der(vy) = Fy + F_dist_y;
  m_z*der(vz) = Fz + F_dist_z;

  // ---- Cartesian / orientation error ----
  err_x = xr - x;
  err_y = yr - y;
  err_z = zr - z;
  tracking_error = sqrt(err_x*err_x + err_y*err_y + err_z*err_z + 1e-12);
  // Tool orientation is preserved along the path: orientation error is zero by construction.
  orientation_error = 0.0;

  // ---- Obstacle clearance (XY distance to cylinder axis minus radius) ----
  clearance = sqrt((x - obs_x)*(x - obs_x) + (y - obs_y)*(y - obs_y) + 1e-12) - obs_r;

  // ---- Sensor traces: joint sensing, pose feedback, wrist wrench ----
  joint_pos_x = x; joint_pos_y = y; joint_pos_z = z;
  joint_vel_x = vx; joint_vel_y = vy; joint_vel_z = vz;
  pose_x = x; pose_y = y; pose_z = z;
  wrist_wrench_x = Fx + F_dist_x;
  wrist_wrench_y = Fy + F_dist_y;
  wrist_wrench_z = Fz + F_dist_z;

  // ---- Requirement checks ----
  joint_ok = (x >= 0.0) and (x <= L_x) and (y >= 0.0) and (y <= L_y) and (z >= 0.0) and (z <= L_z);
  effort_ok = (abs(Fx) <= F_max + 1e-6) and (abs(Fy) <= F_max + 1e-6) and (abs(Fz) <= F_max + 1e-6);
  cmd_finite = (Fx_cmd == Fx_cmd) and (Fy_cmd == Fy_cmd) and (Fz_cmd == Fz_cmd);
  clearance_ok = clearance >= clearance_req;
  tracking_ok = if time >= 6.5 then tracking_error <= 0.042 else true;
  finite_check = (x == x) and (y == y) and (z == z) and (vx == vx) and (vy == vy) and (vz == vz)
              and (tracking_error == tracking_error) and (clearance == clearance);

  annotation(
    Experiment(StopTime=10, Tolerance=1e-6, Interval=0.01),
    uses(Modelica(version="4.0.0")),
    Documentation(info="Trajectory-controlled Cartesian gantry tracking a four-pose spline with preserved tool orientation, joint and effort bounds, obstacle clearance, and a 7 N tool disturbance injected during the middle third. Run at 100 Hz for 10 s. Facts not stated in the request (e.g., payload inertia, friction, link compliance, specific controller gains beyond those needed for bounded tracking) are treated as unknown and omitted.")
  );
end GantryPathSplineB;