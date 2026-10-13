model GroundTrioResilientD
  "Instrumented 3-robot differential-drive fleet with dropout-resilient distributed control."

  // ---------- Physical parameters (SI) ----------
  parameter Real m_robot       = 18.0  "robot mass [kg]";
  parameter Real J_robot        = 2.0   "robot yaw inertia [kg.m2]";
  parameter Real r_wheel        = 0.10  "wheel radius [m]";
  parameter Real L_wheel        = 0.40  "wheel separation [m]";
  parameter Real b_drag         = 1.5   "linear drag [N.s/m]";
  parameter Real b_yaw          = 0.8   "yaw drag [N.m.s/rad]";
  parameter Real tau_max        = 12.0  "per-wheel torque limit [N.m]";
  parameter Real robot_radius   = 0.30  "footprint radius [m]";
  parameter Real safe_dist      = 0.80  "collision avoidance distance [m]";

  // ---------- Control / estimation parameters ----------
  parameter Real Kp_track = 80.0;
  parameter Real Kd_track = 45.0;
  parameter Real Kp_form  = 20.0;
  parameter Real Kd_form  = 8.0;
  parameter Real Kp_yaw   = 12.0;
  parameter Real Kd_yaw   = 6.0;
  parameter Real K_rep    = 60.0;
  parameter Real d_comm   = 0.05  "communication delay [s]";

  // ---------- Scenario parameters ----------
  parameter Real T_end         = 14.0 "total run time [s]";
  parameter Real t_drop_start = 6.0  "dropout start (middle third) [s]";
  parameter Real t_drop_end   = 7.0  "dropout end [s]";
  parameter Real dist_amp     = 25.0 "shared disturbance force amplitude [N]";
  parameter Real route_len     = 8.0  "route length [m]";
  parameter Real form_a       = 1.3  "formation x-offset [m]";
  parameter Real form_b       = 0.75 "formation y-offset [m]";
  parameter Real eps          = 1.0e-6 "division guard";

  // ---------- Robot states ----------
  Real x[3];
  Real y[3];
  Real th[3];
  Real v[3]  "forward speed [m/s]";
  Real w[3]  "yaw rate [rad/s]";
  Real vx[3] "world-frame x velocity [m/s]";
  Real vy[3] "world-frame y velocity [m/s]";

  // ---------- Actuator commands ----------
  Real tau_cmd[3,2] "commanded wheel torques [N.m]";
  Real tau[3,2]     "applied (bounded) wheel torques [N.m]";

  // ---------- Desired trajectory ----------
  Real s_route;
  Real route_x;
  Real route_v;
  Real xd[3];
  Real yd[3];
  Real vd_x[3];
  Real vd_y[3];

  // ---------- Peer communication / prediction ----------
  Boolean comm_ok;
  Boolean drop_active;
  Real peer_live_x[3,3];
  Real peer_live_y[3,3];
  Real peer_live_vx[3,3];
  Real peer_live_vy[3,3];
  Real peer_x[3,3];
  Real peer_y[3,3];
  Real peer_vx[3,3];
  Real peer_vy[3,3];
  Real peer_ts[3,3];
  Real peer_age[3,3];
  Real last_x[3,3](each start=0.0);
  Real last_y[3,3](each start=0.0);
  Real last_vx[3,3](each start=0.0);
  Real last_vy[3,3](each start=0.0);
  Real last_ts[3,3](each start=0.0);

  // ---------- Sensors ----------
  Real lidar_dist[3,3] "lidar-derived pairwise center distance [m]";

  // ---------- Control forces / torques ----------
  Real Fx_track[3], Fy_track[3];
  Real Fx_form[3],  Fy_form[3];
  Real Fx_rep[3],   Fy_rep[3];
  Real Fx_dist[3],  Fy_dist[3];
  Real Fx[3], Fy[3];
  Real F_long[3];
  Real M_yaw[3];
  Real th_d[3];
  Real e_th[3];

  // ---------- Metrics ----------
  Real track_err[3];
  Real primary_track_err;
  Real form_err;
  Real route_progress;
  Boolean route_completed;

initial equation
  x[1] = 0.0;      y[1] = 0.0;
  x[2] = -form_a;   y[2] = form_b;
  x[3] = -form_a;   y[3] = -form_b;
  for i in 1:3 loop
    th[i] = 0.0;
    v[i]  = 0.0;
    w[i]  = 0.0;
  end for;

equation
  // ----- communication availability and dropout window -----
  comm_ok   = not (time >= t_drop_start and time < t_drop_end);
  drop_active = (time >= t_drop_start and time < t_drop_end);

  // ----- route reference (smoothstep, zero endpoint velocity) -----
  s_route = max(0.0, min(1.0, time / T_end));
  route_x = route_len * (3.0*s_route*s_route - 2.0*s_route*s_route*s_route);
  route_v = route_len * (6.0*s_route - 6.0*s_route*s_route) / T_end;

  // ----- desired rigid-formation positions -----
  xd[1] = route_x;           yd[1] = 0.0;
  xd[2] = route_x - form_a;  yd[2] = form_b;
  xd[3] = route_x - form_a;  yd[3] = -form_b;
  for i in 1:3 loop
    vd_x[i] = route_v;
    vd_y[i] = 0.0;
  end for;

  // ----- world-frame velocity from proprioception -----
  for i in 1:3 loop
    vx[i] = v[i]*cos(th[i]);
    vy[i] = v[i]*sin(th[i]);
  end for;

  // ----- peer live (delayed) signals -----
  for i in 1:3 loop
    for j in 1:3 loop
      peer_live_x[i,j]  = delay(x[j],  d_comm);
      peer_live_y[i,j]  = delay(y[j],  d_comm);
      peer_live_vx[i,j] = delay(vx[j], d_comm);
      peer_live_vy[i,j] = delay(vy[j], d_comm);
    end for;
  end for;

  // ----- peer state used by controller (with dropout prediction) -----
  for i in 1:3 loop
    for j in 1:3 loop
      if i == j then
        peer_x[i,j]  = x[i];
        peer_y[i,j]  = y[i];
        peer_vx[i,j] = vx[i];
        peer_vy[i,j] = vy[i];
        peer_ts[i,j] = time;
      else
        peer_x[i,j]  = if comm_ok then peer_live_x[i,j]
                      else (last_x[i,j]  + last_vx[i,j]*(time - last_ts[i,j]));
        peer_y[i,j]  = if comm_ok then peer_live_y[i,j]
                      else (last_y[i,j]  + last_vy[i,j]*(time - last_ts[i,j]));
        peer_vx[i,j] = if comm_ok then peer_live_vx[i,j] else last_vx[i,j];
        peer_vy[i,j] = if comm_ok then peer_live_vy[i,j] else last_vy[i,j];
        peer_ts[i,j] = if comm_ok then (time - d_comm) else last_ts[i,j];
      end if;
      peer_age[i,j] = time - peer_ts[i,j];
    end for;
  end for;

  // ----- capture last-received peer state at dropout onset -----
  when not comm_ok then
    for i in 1:3 loop
      for j in 1:3 loop
        last_x[i,j]  = peer_live_x[i,j];
        last_y[i,j]  = peer_live_y[i,j];
        last_vx[i,j] = peer_live_vx[i,j];
        last_vy[i,j] = peer_live_vy[i,j];
        last_ts[i,j] = time - d_comm;
      end for;
    end for;
  end when;

  // ----- exteroception: lidar pairwise distances -----
  for i in 1:3 loop
    for j in 1:3 loop
      lidar_dist[i,j] = if i == j then 0.0
                       else sqrt((x[i]-x[j])^2 + (y[i]-y[j])^2 + eps);
    end for;
  end for;

  // ----- tracking force (proprioception + route) -----
  for i in 1:3 loop
    Fx_track[i] = Kp_track*(xd[i] - x[i]) + Kd_track*(vd_x[i] - vx[i]);
    Fy_track[i] = Kp_track*(yd[i] - y[i]) + Kd_track*(vd_y[i] - vy[i]);
  end for;

  // ----- formation force (explicit, peer-state based) -----
  // robot 1 from peers 2,3
  Fx_form[1] = Kp_form*((xd[1]-xd[2])-(x[1]-peer_x[1,2])) + Kd_form*((vd_x[1]-vd_x[2])-(vx[1]-peer_vx[1,2]))
            + Kp_form*((xd[1]-xd[3])-(x[1]-peer_x[1,3])) + Kd_form*((vd_x[1]-vd_x[3])-(vx[1]-peer_vx[1,3]));
  Fy_form[1] = Kp_form*((yd[1]-yd[2])-(y[1]-peer_y[1,2])) + Kd_form*((vd_y[1]-vd_y[2])-(vy[1]-peer_vy[1,2]))
            + Kp_form*((yd[1]-yd[3])-(y[1]-peer_y[1,3])) + Kd_form*((vd_y[1]-vd_y[3])-(vy[1]-peer_vy[1,3]));
  // robot 2 from peers 1,3
  Fx_form[2] = Kp_form*((xd[2]-xd[1])-(x[2]-peer_x[2,1])) + Kd_form*((vd_x[2]-vd_x[1])-(vx[2]-peer_vx[2,1]))
            + Kp_form*((xd[2]-xd[3])-(x[2]-peer_x[2,3])) + Kd_form*((vd_x[2]-vd_x[3])-(vx[2]-peer_vx[2,3]));
  Fy_form[2] = Kp_form*((yd[2]-yd[1])-(y[2]-peer_y[2,1])) + Kd_form*((vd_y[2]-vd_y[1])-(vy[2]-peer_vy[2,1]))
            + Kp_form*((yd[2]-yd[3])-(y[2]-peer_y[2,3])) + Kd_form*((vd_y[2]-vd_y[3])-(vy[2]-peer_vy[2,3]));
  // robot 3 from peers 1,2
  Fx_form[3] = Kp_form*((xd[3]-xd[1])-(x[3]-peer_x[3,1])) + Kd_form*((vd_x[3]-vd_x[1])-(vx[3]-peer_vx[3,1]))
            + Kp_form*((xd[3]-xd[2])-(x[3]-peer_x[3,2])) + Kd_form*((vd_x[3]-vd_x[2])-(vx[3]-peer_vx[3,2]));
  Fy_form[3] = Kp_form*((yd[3]-yd[1])-(y[3]-peer_y[3,1])) + Kd_form*((vd_y[3]-vd_y[1])-(vy[3]-peer_vy[3,1]))
            + Kp_form*((yd[3]-yd[2])-(y[3]-peer_y[3,2])) + Kd_form*((vd_y[3]-vd_y[2])-(vy[3]-peer_vy[3,2]));

  // ----- collision avoidance (lidar-based repulsion, explicit) -----
  Fx_rep[1] = (if lidar_dist[1,2] < safe_dist
               then K_rep*(safe_dist-lidar_dist[1,2])*(x[1]-x[2])/lidar_dist[1,2] else 0.0)
            + (if lidar_dist[1,3] < safe_dist
               then K_rep*(safe_dist-lidar_dist[1,3])*(x[1]-x[3])/lidar_dist[1,3] else 0.0);
  Fy_rep[1] = (if lidar_dist[1,2] < safe_dist
               then K_rep*(safe_dist-lidar_dist[1,2])*(y[1]-y[2])/lidar_dist[1,2] else 0.0)
            + (if lidar_dist[1,3] < safe_dist
               then K_rep*(safe_dist-lidar_dist[1,3])*(y[1]-y[3])/lidar_dist[1,3] else 0.0);
  Fx_rep[2] = (if lidar_dist[2,1] < safe_dist
               then K_rep*(safe_dist-lidar_dist[2,1])*(x[2]-x[1])/lidar_dist[2,1] else 0.0)
            + (if lidar_dist[2,3] < safe_dist
               then K_rep*(safe_dist-lidar_dist[2,3])*(x[2]-x[3])/lidar_dist[2,3] else 0.0);
  Fy_rep[2] = (if lidar_dist[2,1] < safe_dist
               then K_rep*(safe_dist-lidar_dist[2,1])*(y[2]-y[1])/lidar_dist[2,1] else 0.0)
            + (if lidar_dist[2,3] < safe_dist
               then K_rep*(safe_dist-lidar_dist[2,3])*(y[2]-y[3])/lidar_dist[2,3] else 0.0);
  Fx_rep[3] = (if lidar_dist[3,1] < safe_dist
               then K_rep*(safe_dist-lidar_dist[3,1])*(x[3]-x[1])/lidar_dist[3,1] else 0.0)
            + (if lidar_dist[3,2] < safe_dist
               then K_rep*(safe_dist-lidar_dist[3,2])*(x[3]-x[2])/lidar_dist[3,2] else 0.0);
  Fy_rep[3] = (if lidar_dist[3,1] < safe_dist
               then K_rep*(safe_dist-lidar_dist[3,1])*(y[3]-y[1])/lidar_dist[3,1] else 0.0)
            + (if lidar_dist[3,2] < safe_dist
               then K_rep*(safe_dist-lidar_dist[3,2])*(y[3]-y[2])/lidar_dist[3,2] else 0.0);

  // ----- shared environmental disturbance during dropout -----
  for i in 1:3 loop
    Fx_dist[i] = 0.0;
    Fy_dist[i] = if drop_active then -dist_amp else 0.0;
  end for;

  // ----- total desired force, heading projection, yaw control -----
  for i in 1:3 loop
    Fx[i] = Fx_track[i] + Fx_form[i] + Fx_rep[i] + Fx_dist[i];
    Fy[i] = Fy_track[i] + Fy_form[i] + Fy_rep[i] + Fy_dist[i];
    F_long[i] = Fx[i]*cos(th[i]) + Fy[i]*sin(th[i]);
    th_d[i]   = atan2(Fy[i], max(Fx[i], eps));
    e_th[i]   = wrapAngle(th_d[i] - th[i]);
    M_yaw[i]  = Kp_yaw*e_th[i] - Kd_yaw*w[i];
  end for;

  // ----- wheel torque commands and saturation -----
  for i in 1:3 loop
    tau_cmd[i,1] = (F_long[i]/2.0 + M_yaw[i]/L_wheel) * r_wheel;
    tau_cmd[i,2] = (F_long[i]/2.0 - M_yaw[i]/L_wheel) * r_wheel;
    tau[i,1] = satLimit(tau_cmd[i,1], tau_max);
    tau[i,2] = satLimit(tau_cmd[i,2], tau_max);
  end for;

  // ----- differential-drive dynamics -----
  for i in 1:3 loop
    der(v[i])  = (tau[i,1] + tau[i,2])/r_wheel/m_robot - (b_drag/m_robot)*v[i];
    der(w[i])  = ((tau[i,1] - tau[i,2])/r_wheel)*L_wheel/2.0/J_robot - (b_yaw/J_robot)*w[i];
    der(x[i])  = v[i]*cos(th[i]);
    der(y[i])  = v[i]*sin(th[i]);
    der(th[i]) = w[i];
  end for;

  // ----- metrics / observables -----
  for i in 1:3 loop
    track_err[i] = sqrt((xd[i]-x[i])^2 + (yd[i]-y[i])^2 + eps);
  end for;
  primary_track_err = track_err[1];

  form_err = sqrt(
      ((x[1]-x[2]) - (xd[1]-xd[2]))^2 + ((y[1]-y[2]) - (yd[1]-yd[2]))^2
    + ((x[1]-x[3]) - (xd[1]-xd[3]))^2 + ((y[1]-y[3]) - (yd[1]-yd[3]))^2
    + ((x[2]-x[3]) - (xd[2]-xd[3]))^2 + ((y[2]-y[3]) - (yd[2]-yd[3]))^2
    ) / sqrt(6.0);

  route_progress  = route_x / (route_len + eps);
  route_completed = route_progress >= 0.99;

  annotation (
    experiment(StartTime = 0, StopTime = 14, Interval = 0.005, Tolerance = 1e-6),
    Documentation(info="GroundTrioResilientD: three 18 kg differential-drive warehouse robots,"
      " six bounded wheel drives (<=12 N.m each), odometry + lidar + delayed peer messages,"
      " distributed PD control with last-received-state prediction through a 1 s communication"
      " dropout (6-7 s) inside the middle third of a 14 s, 200 Hz run. A shared -y disturbance"
      " is applied during dropout. Actuator bounds, collision avoidance, degraded/recovered"
      " formation error, finite estimates, and route completion are retained as observables."
      " Facts not stated in the request (e.g., wheel inertia, friction curve, lidar noise model)"
      " are treated as unknown and not modeled."));
end GroundTrioResilientD;

function satLimit "Symmetric saturation"
  input  Real u;
  input  Real lim;
  output Real y;
algorithm
  y := if u > lim then lim else if u < -lim then -lim else u;
end satLimit;

function wrapAngle "Wrap angle to (-pi, pi]"
  input  Real a;
  output Real y;
algorithm
  y := mod(a + Modelica.Constants.PI, 2.0*Modelica.Constants.PI) - Modelica.Constants.PI;
end wrapAngle;