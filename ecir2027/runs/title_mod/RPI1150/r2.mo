model AirTrioResilientD
  "Instrumented multi-robot system: three quadrotors with resilient distributed control through communication dropout"

  // ==================== Physical Parameters ====================
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";
  parameter Real Tmax = 12.0 "max thrust per rotor [N]";
  parameter Real att_tau = 0.08 "attitude time constant [s]";
  parameter Real k_alloc = 0.4 "rotor allocation gain for attitude [N/rad]";

  // ==================== Controller Gains ====================
  parameter Real Kp_track = 6.0 "tracking proportional gain [1/s2]";
  parameter Real Kd_track = 3.0 "tracking derivative gain [1/s]";
  parameter Real Kf_form = 2.0 "formation keeping gain [1/s2]";

  // ==================== Formation ====================
  parameter Real sep = 2.0 "formation separation [m]";
  parameter Real off1x = 0.0 "robot 1 x offset [m]";
  parameter Real off1y = 0.0 "robot 1 y offset [m]";
  parameter Real off2x = -2.0 "robot 2 x offset [m]";
  parameter Real off2y = 0.0 "robot 2 y offset [m]";
  parameter Real off3x = -1.0 "robot 3 x offset [m]";
  parameter Real off3y = 1.7320508 "robot 3 y offset [m]";
  parameter Real d12_des = 2.0 "desired distance 1-2 [m]";
  parameter Real d13_des = 2.0 "desired distance 1-3 [m]";
  parameter Real d23_des = 2.0 "desired distance 2-3 [m]";

  // ==================== Route ====================
  parameter Real route_speed = 10.0/14.0 "route speed [m/s]";
  parameter Real route_yamp = 0.5 "route y oscillation amplitude [m]";

  // ==================== Dropout ====================
  parameter Real t_drop_start = 4.6666667 "dropout start [s]";
  parameter Real t_drop_end = 5.6666667 "dropout end [s]";
  parameter Real dist_amp = 2.0 "shared disturbance amplitude [N]";

  // ==================== Collision Avoidance ====================
  parameter Real d_safe = 1.0 "safe distance [m]";
  parameter Real k_rep = 8.0 "repulsion gain [N]";

  // ==================== Robot 1 Physical States ====================
  Real x1(start=0.0, fixed=true) "robot 1 x [m]";
  Real y1(start=0.0, fixed=true) "robot 1 y [m]";
  Real z1(start=2.0, fixed=true) "robot 1 z [m]";
  Real vx1(start=0.0, fixed=true) "robot 1 vx [m/s]";
  Real vy1(start=0.0, fixed=true) "robot 1 vy [m/s]";
  Real vz1(start=0.0, fixed=true) "robot 1 vz [m/s]";
  Real roll1(start=0.0, fixed=true) "robot 1 roll [rad]";
  Real pitch1(start=0.0, fixed=true) "robot 1 pitch [rad]";

  // ==================== Robot 2 Physical States ====================
  Real x2(start=-2.0, fixed=true);
  Real y2(start=0.0, fixed=true);
  Real z2(start=2.0, fixed=true);
  Real vx2(start=0.0, fixed=true);
  Real vy2(start=0.0, fixed=true);
  Real vz2(start=0.0, fixed=true);
  Real roll2(start=0.0, fixed=true);
  Real pitch2(start=0.0, fixed=true);

  // ==================== Robot 3 Physical States ====================
  Real x3(start=-1.0, fixed=true);
  Real y3(start=1.7320508, fixed=true);
  Real z3(start=2.0, fixed=true);
  Real vx3(start=0.0, fixed=true);
  Real vy3(start=0.0, fixed=true);
  Real vz3(start=0.0, fixed=true);
  Real roll3(start=0.0, fixed=true);
  Real pitch3(start=0.0, fixed=true);

  // ==================== 12 Rotor Thrusts [N] bounded [0, 12] ====================
  Real Tr1_1, Tr1_2, Tr1_3, Tr1_4;
  Real Tr2_1, Tr2_2, Tr2_3, Tr2_4;
  Real Tr3_1, Tr3_2, Tr3_3, Tr3_4;

  // ==================== Total Thrusts ====================
  Real Ttot1_des, Ttot2_des, Ttot3_des;
  Real Ttot1, Ttot2, Ttot3;

  // ==================== Desired Accelerations [m/s2] ====================
  Real ax1_des, ay1_des, az1_des;
  Real ax2_des, ay2_des, az2_des;
  Real ax3_des, ay3_des, az3_des;

  // ==================== Desired Attitudes [rad] ====================
  Real roll1_des, pitch1_des;
  Real roll2_des, pitch2_des;
  Real roll3_des, pitch3_des;

  // ==================== Communication ====================
  Boolean comm_active "true when inter-robot communication is available";

  // ==================== Timestamps of Last Received Peer State ====================
  Real ts_r1f2(start=0.0, fixed=true) "robot 1 last recv time from robot 2 [s]";
  Real ts_r1f3(start=0.0, fixed=true) "robot 1 last recv time from robot 3 [s]";
  Real ts_r2f1(start=0.0, fixed=true);
  Real ts_r2f3(start=0.0, fixed=true);
  Real ts_r3f1(start=0.0, fixed=true);
  Real ts_r3f2(start=0.0, fixed=true);

  // ==================== Staleness of Peer Estimates ====================
  Real age_r1f2, age_r1f3, age_r2f1, age_r2f3, age_r3f1, age_r3f2;

  // ==================== Peer State Estimates (local proprioception + exteroception + prediction) ====================
  // Robot 1 estimates Robot 2
  Real x2e1(start=-2.0, fixed=true), y2e1(start=0.0, fixed=true), z2e1(start=2.0, fixed=true);
  Real vx2e1(start=0.0, fixed=true), vy2e1(start=0.0, fixed=true), vz2e1(start=0.0, fixed=true);
  // Robot 1 estimates Robot 3
  Real x3e1(start=-1.0, fixed=true), y3e1(start=1.7320508, fixed=true), z3e1(start=2.0, fixed=true);
  Real vx3e1(start=0.0, fixed=true), vy3e1(start=0.0, fixed=true), vz3e1(start=0.0, fixed=true);
  // Robot 2 estimates Robot 1
  Real x1e2(start=0.0, fixed=true), y1e2(start=0.0, fixed=true), z1e2(start=2.0, fixed=true);
  Real vx1e2(start=0.0, fixed=true), vy1e2(start=0.0, fixed=true), vz1e2(start=0.0, fixed=true);
  // Robot 2 estimates Robot 3
  Real x3e2(start=-1.0, fixed=true), y3e2(start=1.7320508, fixed=true), z3e2(start=2.0, fixed=true);
  Real vx3e2(start=0.0, fixed=true), vy3e2(start=0.0, fixed=true), vz3e2(start=0.0, fixed=true);
  // Robot 3 estimates Robot 1
  Real x1e3(start=0.0, fixed=true), y1e3(start=0.0, fixed=true), z1e3(start=2.0, fixed=true);
  Real vx1e3(start=0.0, fixed=true), vy1e3(start=0.0, fixed=true), vz1e3(start=0.0, fixed=true);
  // Robot 3 estimates Robot 2
  Real x2e3(start=-2.0, fixed=true), y2e3(start=0.0, fixed=true), z2e3(start=2.0, fixed=true);
  Real vx2e3(start=0.0, fixed=true), vy2e3(start=0.0, fixed=true), vz2e3(start=0.0, fixed=true);

  // ==================== Route Trajectory ====================
  Real route_x, route_y, route_z;
  Real route_vx, route_vy, route_vz;

  // ==================== Shared Environmental Disturbance ====================
  Real dist_fx, dist_fy, dist_fz;

  // ==================== Peer-Relative Range Sensing ====================
  Real range12, range13, range23;

  // ==================== Inter-Robot Distances ====================
  Real dist12, dist13, dist23;

  // ==================== Collision Avoidance Forces ====================
  Real ca12x, ca12y, ca13x, ca13y, ca23x, ca23y;
  Real ca1x, ca1y, ca2x, ca2y, ca3x, ca3y;

  // ==================== Error Metrics ====================
  Real form_err "instantaneous formation error [m]";
  discrete Real form_err_drop(start=0.0) "degraded formation error at dropout end [m]";
  discrete Real form_err_rec(start=0.0) "recovered formation error at 9.1 s [m]";
  Real track_err "primary tracking error of robot 1 [m]";

equation
  // ===================== Route Trajectory =====================
  route_x = route_speed * time;
  route_y = route_yamp * sin(0.5 * time);
  route_z = 2.0;
  route_vx = route_speed;
  route_vy = route_yamp * 0.5 * cos(0.5 * time);
  route_vz = 0.0;

  // ===================== Communication Availability =====================
  comm_active = (time < t_drop_start) or (time > t_drop_end);

  // ===================== Timestamps (track time when comm active, freeze during dropout) =====================
  der(ts_r1f2) = if comm_active then 1.0 else 0.0;
  der(ts_r1f3) = if comm_active then 1.0 else 0.0;
  der(ts_r2f1) = if comm_active then 1.0 else 0.0;
  der(ts_r2f3) = if comm_active then 1.0 else 0.0;
  der(ts_r3f1) = if comm_active then 1.0 else 0.0;
  der(ts_r3f2) = if comm_active then 1.0 else 0.0;

  age_r1f2 = time - ts_r1f2;
  age_r1f3 = time - ts_r1f3;
  age_r2f1 = time - ts_r2f1;
  age_r2f3 = time - ts_r2f3;
  age_r3f1 = time - ts_r3f1;
  age_r3f2 = time - ts_r3f2;

  // ===================== Shared Disturbance (only during dropout) =====================
  dist_fx = if (time >= t_drop_start and time <= t_drop_end) then dist_amp * sin(2.0 * time) else 0.0;
  dist_fy = if (time >= t_drop_start and time <= t_drop_end) then dist_amp * cos(2.0 * time) else 0.0;
  dist_fz = if (time >= t_drop_start and time <= t_drop_end) then dist_amp * 0.5 * sin(3.0 * time) else 0.0;

  // ===================== Peer State Estimation =====================
  // When comm active: fast tracking of true peer state (GPS/IMU fusion).
  // When comm dropped: constant-velocity dead-reckoning prediction.
  // Robot 1 <- Robot 2
  der(x2e1)  = if comm_active then 20.0*(x2 - x2e1)   else vx2e1;
  der(y2e1)  = if comm_active then 20.0*(y2 - y2e1)   else vy2e1;
  der(z2e1)  = if comm_active then 20.0*(z2 - z2e1)   else vz2e1;
  der(vx2e1) = if comm_active then 20.0*(vx2 - vx2e1) else 0.0;
  der(vy2e1) = if comm_active then 20.0*(vy2 - vy2e1) else 0.0;
  der(vz2e1) = if comm_active then 20.0*(vz2 - vz2e1) else 0.0;

  // Robot 1 <- Robot 3
  der(x3e1)  = if comm_active then 20.0*(x3 - x3e1)   else vx3e1;
  der(y3e1)  = if comm_active then 20.0*(y3 - y3e1)   else vy3e1;
  der(z3e1)  = if comm_active then 20.0*(z3 - z3e1)   else vz3e1;
  der(vx3e1) = if comm_active then 20.0*(vx3 - vx3e1) else 0.0;
  der(vy3e1) = if comm_active then 20.0*(vy3 - vy3e1) else 0.0;
  der(vz3e1) = if comm_active then 20.0*(vz3 - vz3e1) else 0.0;

  // Robot 2 <- Robot 1
  der(x1e2)  = if comm_active then 20.0*(x1 - x1e2)   else vx1e2;
  der(y1e2)  = if comm_active then 20.0*(y1 - y1e2)   else vy1e2;
  der(z1e2)  = if comm_active then 20.0*(z1 - z1e2)   else vz1e2;
  der(vx1e2) = if comm_active then 20.0*(vx1 - vx1e2) else 0.0;
  der(vy1e2) = if comm_active then 20.0*(vy1 - vy1e2) else 0.0;
  der(vz1e2) = if comm_active then 20.0*(vz1 - vz1e2) else 0.0;

  // Robot 2 <- Robot 3
  der(x3e2)  = if comm_active then 20.0*(x3 - x3e2)   else vx3e2;
  der(y3e2)  = if comm_active then 20.0*(y3 - y3e2)   else vy3e2;
  der(z3e2)  = if comm_active then 20.0*(z3 - z3e2)   else vz3e2;
  der(vx3e2) = if comm_active then 20.0*(vx3 - vx3e2) else 0.0;
  der(vy3e2) = if comm_active then 20.0*(vy3 - vy3e2) else 0.0;
  der(vz3e2) = if comm_active then 20.0*(vz3 - vz3e2) else 0.0;

  // Robot 3 <- Robot 1
  der(x1e3)  = if comm_active then 20.0*(x1 - x1e3)   else vx1e3;
  der(y1e3)  = if comm_active then 20.0*(y1 - y1e3)   else vy1e3;
  der(z1e3)  = if comm_active then 20.0*(z1 - z1e3)   else vz1e3;
  der(vx1e3) = if comm_active then 20.0*(vx1 - vx1e3) else 0.0;
  der(vy1e3) = if comm_active then 20.0*(vy1 - vy1e3) else 0.0;
  der(vz1e3) = if comm_active then 20.0*(vz1 - vz1e3) else 0.0;

  // Robot 3 <- Robot 2
  der(x2e3)  = if comm_active then 20.0*(x2 - x2e3)   else vx2e3;
  der(y2e3)  = if comm_active then 20.0*(y2 - y2e3)   else vy2e3;
  der(z2e3)  = if comm_active then 20.0*(z2 - z2e3)   else vz2e3;
  der(vx2e3) = if comm_active then 20.0*(vx2 - vx2e3) else 0.0;
  der(vy2e3) = if comm_active then 20.0*(vy2 - vy2e3) else 0.0;
  der(vz2e3) = if comm_active then 20.0*(vz2 - vz2e3) else 0.0;

  // ===================== Inter-Robot Distances =====================
  dist12 = sqrt(max(0.01, (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) + (z1-z2)*(z1-z2)));
  dist13 = sqrt(max(0.01, (x1-x3)*(x1-x3) + (y1-y3)*(y1-y3) + (z1-z3)*(z1-z3)));
  dist23 = sqrt(max(0.01, (x2-x3)*(x2-x3) + (y2-y3)*(y2-y3) + (z2-z3)*(z2-z3)));

  // ===================== Peer-Relative Range Sensor Measurements =====================
  range12 = dist12;
  range13 = dist13;
  range23 = dist23;

  // ===================== Collision Avoidance (repulsive) =====================
  ca12x = if dist12 < d_safe then k_rep*(x1-x2)/dist12*(d_safe-dist12)/d_safe else 0.0;
  ca12y = if dist12 < d_safe then k_rep*(y1-y2)/dist12*(d_safe-dist12)/d_safe else 0.0;
  ca13x = if dist13 < d_safe then k_rep*(x1-x3)/dist13*(d_safe-dist13)/d_safe else 0.0;
  ca13y = if dist13 < d_safe then k_rep*(y1-y3)/dist13*(d_safe-dist13)/d_safe else 0.0;
  ca23x = if dist23 < d_safe then k_rep*(x2-x3)/dist23*(d_safe-dist23)/d_safe else 0.0;
  ca23y = if dist23 < d_safe then k_rep*(y2-y3)/dist23*(d_safe-dist23)/d_safe else 0.0;

  ca1x = ca12x + ca13x;
  ca1y = ca12y + ca13y;
  ca2x = -ca12x + ca23x;
  ca2y = -ca12y + ca23y;
  ca3x = -ca13x - ca23x;
  ca3y = -ca13y - ca23y;

  // ===================== Distributed Control: Desired Accelerations =====================
  // Robot 1: route tracking + formation keeping (using peer estimates) + collision avoidance
  ax1_des = Kp_track*(route_x + off1x - x1) + Kd_track*(route_vx - vx1)
          + Kf_form*((x2e1 - x1) - (off2x - off1x))
          + Kf_form*((x3e1 - x1) - (off3x - off1x))
          + ca1x/m;
  ay1_des = Kp_track*(route_y + off1y - y1) + Kd_track*(route_vy - vy1)
          + Kf_form*((y2e1 - y1) - (off2y - off1y))
          + Kf_form*((y3e1 - y1) - (off3y - off1y))
          + ca1y/m;
  az1_des = Kp_track*(route_z - z1) + Kd_track*(route_vz - vz1)
          + Kf_form*(z2e1 - z1) + Kf_form*(z3e1 - z1);

  // Robot 2
  ax2_des = Kp_track*(route_x + off2x - x2) + Kd_track*(route_vx - vx2)
          + Kf_form*((x1e2 - x2) - (off1x - off2x))
          + Kf_form*((x3e2 - x2) - (off3x - off2x))
          + ca2x/m;
  ay2_des = Kp_track*(route_y + off2y - y2) + Kd_track*(route_vy - vy2)
          + Kf_form*((y1e2 - y2) - (off1y - off2y))
          + Kf_form*((y3e2 - y2) - (off3y - off2y))
          + ca2y/m;
  az2_des = Kp_track*(route_z - z2) + Kd_track*(route_vz - vz2)
          + Kf_form*(z1e2 - z2) + Kf_form*(z3e2 - z2);

  // Robot 3
  ax3_des = Kp_track*(route_x + off3x - x3) + Kd_track*(route_vx - vx3)
          + Kf_form*((x1e3 - x3) - (off1x - off3x))
          + Kf_form*((x2e3 - x3) - (off2x - off3x))
          + ca3x/m;
  ay3_des = Kp_track*(route_y + off3y - y3) + Kd_track*(route_vy - vy3)
          + Kf_form*((y1e3 - y3) - (off1y - off3y))
          + Kf_form*((y2e3 - y3) - (off2y - off3y))
          + ca3y/m;
  az3_des = Kp_track*(route_z - z3) + Kd_track*(route_vz - vz3)
          + Kf_form*(z1e3 - z3) + Kf_form*(z2e3 - z3);

  // ===================== Thrust & Attitude Commands =====================
  Ttot1_des = m * sqrt(max(0.01, ax1_des*ax1_des + ay1_des*ay1_des + (az1_des + g_acc)*(az1_des + g_acc)));
  pitch1_des = atan2(ax1_des, az1_des + g_acc + 0.01);
  roll1_des = atan2(-ay1_des, az1_des + g_acc + 0.01);

  Ttot2_des = m * sqrt(max(0.01, ax2_des*ax2_des + ay2_des*ay2_des + (az2_des + g_acc)*(az2_des + g_acc)));
  pitch2_des = atan2(ax2_des, az2_des + g_acc + 0.01);
  roll2_des = atan2(-ay2_des, az2_des + g_acc + 0.01);

  Ttot3_des = m * sqrt(max(0.01, ax3_des*ax3_des + ay3_des*ay3_des + (az3_des + g_acc)*(az3_des + g_acc)));
  pitch3_des = atan2(ax3_des, az3_des + g_acc + 0.01);
  roll3_des = atan2(-ay3_des, az3_des + g_acc + 0.01);

  // ===================== Bounded Rotor Thrust Allocation [0, 12] N =====================
  // Robot 1: four rotors (+ configuration)
  Tr1_1 = max(0.0, min(Tmax, Ttot1_des/4.0 + k_alloc*pitch1_des));
  Tr1_2 = max(0.0, min(Tmax, Ttot1_des/4.0 - k_alloc*roll1_des));
  Tr1_3 = max(0.0, min(Tmax, Ttot1_des/4.0 - k_alloc*pitch1_des));
  Tr1_4 = max(0.0, min(Tmax, Ttot1_des/4.0 + k_alloc*roll1_des));
  Ttot1 = Tr1_1 + Tr1_2 + Tr1_3 + Tr1_4;

  // Robot 2
  Tr2_1 = max(0.0, min(Tmax, Ttot2_des/4.0 + k_alloc*pitch2_des));
  Tr2_2 = max(0.0, min(Tmax, Ttot2_des/4.0 - k_alloc*roll2_des));
  Tr2_3 = max(0.0, min(Tmax, Ttot2_des/4.0 - k_alloc*pitch2_des));
  Tr2_4 = max(0.0, min(Tmax, Ttot2_des/4.0 + k_alloc*roll2_des));
  Ttot2 = Tr2_1 + Tr2_2 + Tr2_3 + Tr2_4;

  // Robot 3
  Tr3_1 = max(0.0, min(Tmax, Ttot3_des/4.0 + k_alloc*pitch3_des));
  Tr3_2 = max(0.0, min(Tmax, Ttot3_des/4.0 - k_alloc*roll3_des));
  Tr3_3 = max(0.0, min(Tmax, Ttot3_des/4.0 - k_alloc*pitch3_des));
  Tr3_4 = max(0.0, min(Tmax, Ttot3_des/4.0 + k_alloc*roll3_des));
  Ttot3 = Tr3_1 + Tr3_2 + Tr3_3 + Tr3_4;

  // ===================== Attitude Dynamics (first-order) =====================
  der(roll1)  = (roll1_des  - roll1)  / att_tau;
  der(pitch1) = (pitch1_des - pitch1) / att_tau;
  der(roll2)  = (roll2_des  - roll2)  / att_tau;
  der(pitch2) = (pitch2_des - pitch2) / att_tau;
  der(roll3)  = (roll3_des  - roll3)  / att_tau;
  der(pitch3) = (pitch3_des - pitch3) / att_tau;

  // ===================== Physical Dynamics =====================
  // Robot 1
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = Ttot1 * sin(pitch1) / m + dist_fx/m;
  der(vy1) = -Ttot1 * sin(roll1) / m + dist_fy/m;
  der(vz1) = Ttot1 * cos(roll1) * cos(pitch1) / m - g_acc + dist_fz/m;

  // Robot 2
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = Ttot2 * sin(pitch2) / m + dist_fx/m;
  der(vy2) = -Ttot2 * sin(roll2) / m + dist_fy/m;
  der(vz2) = Ttot2 * cos(roll2) * cos(pitch2) / m - g_acc + dist_fz/m;

  // Robot 3
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  der(vx3) = Ttot3 * sin(pitch3) / m + dist_fx/m;
  der(vy3) = -Ttot3 * sin(roll3) / m + dist_fy/m;
  der(vz3) = Ttot3 * cos(roll3) * cos(pitch3) / m - g_acc + dist_fz/m;

  // ===================== Error Metrics =====================
  form_err = sqrt(max(0.0, (dist12 - d12_des)*(dist12 - d12_des)
                         + (dist13 - d13_des)*(dist13 - d13_des)
                         + (dist23 - d23_des)*(dist23 - d23_des)));
  track_err = sqrt(max(0.0, (x1 - route_x)*(x1 - route_x)
                         + (y1 - route_y)*(y1 - route_y)
                         + (z1 - route_z)*(z1 - route_z)));

  when time > t_drop_end then
    form_err_drop = form_err;
  end when;

  when time > 9.1 then
    form_err_rec = form_err;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=14, Tolerance=1e-6, Interval=0.005),
    Documentation(info="AirTrioResilientD: Three 1.8 kg quadrotors, 12 independent rotor-thrust groups (max 12 N each). Distributed control with peer-state prediction through 1 s communication dropout (middle third of 14 s run at 200 Hz). Shared disturbance during dropout. Formation triangle maintained via predicted peer states. Primary tracking error target < 0.6 m after 9.1 s. All states, commands, and sensor traces retained.")
  );
end AirTrioResilientD;