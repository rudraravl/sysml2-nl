model AirTrioResilientB
  // Physical parameters
  constant Real m = 1.8 "Mass of quadrotor [kg]";
  constant Real T_max_rotor = 9.84 "Max thrust per rotor [N]";
  constant Real T_max_total = 4.0 * 9.84 "Max total thrust per quadrotor [N]";
  
  // Control parameters
  parameter Real Kp = 5.0 "Position gain";
  parameter Real Kd = 4.0 "Velocity gain";
  parameter Real K_form = 2.0 "Formation gain";
  parameter Real K_rep = 50.0 "Collision avoidance gain";
  parameter Real min_dist = 0.5 "Minimum safe distance [m]";
  
  // Environmental disturbance
  parameter Real F_dist_x = 3.0 "Disturbance force X [N]";
  parameter Real F_dist_y = 0.0 "Disturbance force Y [N]";
  
  // Time parameters
  constant Real t_drop_start = 4.0 "Dropout start [s]";
  constant Real t_drop_end = 4.7 "Dropout end [s]";
  
  // States
  Real x1(start=0.0), y1(start=0.0), vx1(start=0.0), vy1(start=0.0);
  Real x2(start=-1.5), y2(start=1.5), vx2(start=0.0), vy2(start=0.0);
  Real x3(start=-1.5), y3(start=-1.5), vx3(start=0.0), vy3(start=0.0);
  
  // Rotor thrusts (12 independent groups)
  Real u1, u2, u3, u4;
  Real u5, u6, u7, u8;
  Real u9, u10, u11, u12;
  
  // Communication buffers (last received peer state)
  discrete Real x1_rcv(start=0.0), y1_rcv(start=0.0), vx1_rcv(start=0.0), vy1_rcv(start=0.0), t1_rcv(start=0.0);
  discrete Real x2_rcv(start=-1.5), y2_rcv(start=1.5), vx2_rcv(start=0.0), vy2_rcv(start=0.0), t2_rcv(start=0.0);
  discrete Real x3_rcv(start=-1.5), y3_rcv(start=-1.5), vx3_rcv(start=0.0), vy3_rcv(start=0.0), t3_rcv(start=0.0);
  
  // Predicted states used by peers
  Real x1_pred, y1_pred, x2_pred, y2_pred, x3_pred, y3_pred;
  
  Boolean dropout;
  
  // Effective states seen by peers
  Real x1_eff, y1_eff, x2_eff, y2_eff, x3_eff, y3_eff;
  
  // Commanded forces
  Real Fx1, Fy1, Fx2, Fy2, Fx3, Fy3;
  Real F1_mag, F2_mag, F3_mag;
  Real F1_bx, F1_by, F2_bx, F2_by, F3_bx, F3_by;
  
  // Desired states
  Real x_des, xd1, yd1, xd2, yd2, xd3, yd3;
  Real vd1, vd2, vd3;
  
  // Tracking errors
  Real err1, err2, err3, err_max;
  
  // Collision distances
  Real d12, d13, d23;
  Real rep12_x, rep12_y, rep13_x, rep13_y, rep23_x, rep23_y;
  
  // Disturbance active
  Real dist_active_x, dist_active_y;
  
equation
  x_des = time;
  
  xd1 = x_des; yd1 = 0.0;
  xd2 = x_des - 1.5; yd2 = 1.5;
  xd3 = x_des - 1.5; yd3 = -1.5;
  
  vd1 = 1.0; vd2 = 1.0; vd3 = 1.0;
  
  dropout = time >= t_drop_start and time <= t_drop_end;
  
  dist_active_x = if dropout then F_dist_x else 0.0;
  dist_active_y = if dropout then F_dist_y else 0.0;
  
  // Prediction during dropout
  x1_pred = x1_rcv + vx1_rcv * (time - t1_rcv);
  y1_pred = y1_rcv + vy1_rcv * (time - t1_rcv);
  x2_pred = x2_rcv + vx2_rcv * (time - t2_rcv);
  y2_pred = y2_rcv + vy2_rcv * (time - t2_rcv);
  x3_pred = x3_rcv + vx3_rcv * (time - t3_rcv);
  y3_pred = y3_rcv + vy3_rcv * (time - t3_rcv);
  
  // Effective states (actual if comms ok, predicted if dropout)
  x1_eff = if dropout then x1_pred else x1;
  y1_eff = if dropout then y1_pred else y1;
  x2_eff = if dropout then x2_pred else x2;
  y2_eff = if dropout then y2_pred else y2;
  x3_eff = if dropout then x3_pred else x3;
  y3_eff = if dropout then y3_pred else y3;
  
  // Distances with zero-error branch
  d12 = max(0.01, sqrt((x1-x2)^2 + (y1-y2)^2));
  d13 = max(0.01, sqrt((x1-x3)^2 + (y1-y3)^2));
  d23 = max(0.01, sqrt((x2-x3)^2 + (y2-y3)^2));
  
  // Repulsive forces
  rep12_x = if d12 < min_dist then K_rep * (min_dist - d12) * (x1 - x2) / d12 else 0.0;
  rep12_y = if d12 < min_dist then K_rep * (min_dist - d12) * (y1 - y2) / d12 else 0.0;
  rep13_x = if d13 < min_dist then K_rep * (min_dist - d13) * (x1 - x3) / d13 else 0.0;
  rep13_y = if d13 < min_dist then K_rep * (min_dist - d13) * (y1 - y3) / d13 else 0.0;
  rep23_x = if d23 < min_dist then K_rep * (min_dist - d23) * (x2 - x3) / d23 else 0.0;
  rep23_y = if d23 < min_dist then K_rep * (min_dist - d23) * (y2 - y3) / d23 else 0.0;
  
  // Distributed control law
  Fx1 = m * (Kp * (xd1 - x1) + Kd * (vd1 - vx1)) + 
        K_form * ((x2_eff - x1) - (xd2 - xd1) + (x3_eff - x1) - (xd3 - xd1)) + 
        rep12_x + rep13_x + dist_active_x;
  Fy1 = m * (Kp * (yd1 - y1) + Kd * (0.0 - vy1)) + 
        K_form * ((y2_eff - y1) - (yd2 - yd1) + (y3_eff - y1) - (yd3 - yd1)) + 
        rep12_y + rep13_y + dist_active_y;
        
  Fx2 = m * (Kp * (xd2 - x2) + Kd * (vd2 - vx2)) + 
        K_form * ((x1_eff - x2) - (xd1 - xd2) + (x3_eff - x2) - (xd3 - xd2)) - 
        rep12_x + rep23_x + dist_active_x;
  Fy2 = m * (Kp * (yd2 - y2) + Kd * (0.0 - vy2)) + 
        K_form * ((y1_eff - y2) - (yd1 - yd2) + (y3_eff - y2) - (yd3 - yd2)) - 
        rep12_y + rep23_y + dist_active_y;
        
  Fx3 = m * (Kp * (xd3 - x3) + Kd * (vd3 - vx3)) + 
        K_form * ((x1_eff - x3) - (xd1 - xd3) + (x2_eff - x3) - (xd2 - xd3)) - 
        rep13_x - rep23_x + dist_active_x;
  Fy3 = m * (Kp * (yd3 - y3) + Kd * (0.0 - vy3)) + 
        K_form * ((y1_eff - y3) - (yd1 - yd3) + (y2_eff - y3) - (yd2 - yd3)) - 
        rep13_y - rep23_y + dist_active_y;
  
  // Force magnitudes with zero-error branch
  F1_mag = sqrt(Fx1^2 + Fy1^2 + 0.0001);
  F2_mag = sqrt(Fx2^2 + Fy2^2 + 0.0001);
  F3_mag = sqrt(Fx3^2 + Fy3^2 + 0.0001);
  
  // Bounded force vectors
  F1_bx = if F1_mag > T_max_total then T_max_total * (Fx1 / F1_mag) else Fx1;
  F1_by = if F1_mag > T_max_total then T_max_total * (Fy1 / F1_mag) else Fy1;
  F2_bx = if F2_mag > T_max_total then T_max_total * (Fx2 / F2_mag) else Fx2;
  F2_by = if F2_mag > T_max_total then T_max_total * (Fy2 / F2_mag) else Fy2;
  F3_bx = if F3_mag > T_max_total then T_max_total * (Fx3 / F3_mag) else Fx3;
  F3_by = if F3_mag > T_max_total then T_max_total * (Fy3 / F3_mag) else Fy3;
  
  // Rotor thrust assignments (4 rotors per quadrotor, bounded by T_max_rotor)
  u1 = min(T_max_rotor, F1_mag / 4.0);
  u2 = u1; u3 = u1; u4 = u1;
  u5 = min(T_max_rotor, F2_mag / 4.0);
  u6 = u5; u7 = u5; u8 = u5;
  u9 = min(T_max_rotor, F3_mag / 4.0);
  u10 = u9; u11 = u9; u12 = u9;
  
  // Dynamics
  der(x1) = vx1;
  der(y1) = vy1;
  der(vx1) = F1_bx / m;
  der(vy1) = F1_by / m;
  
  der(x2) = vx2;
  der(y2) = vy2;
  der(vx2) = F2_bx / m;
  der(vy2) = F2_by / m;
  
  der(x3) = vx3;
  der(y3) = vy3;
  der(vx3) = F3_bx / m;
  der(vy3) = F3_by / m;
  
  // Tracking errors
  err1 = sqrt((x1 - xd1)^2 + (y1 - yd1)^2);
  err2 = sqrt((x2 - xd2)^2 + (y2 - yd2)^2);
  err3 = sqrt((x3 - xd3)^2 + (y3 - yd3)^2);
  err_max = max(err1, max(err2, err3));
  
algorithm
  when sample(0.0, 0.01) then
    // Update communication buffers with timestamps if not in dropout
    if not dropout then
      x1_rcv := x1; y1_rcv := y1; vx1_rcv := vx1; vy1_rcv := vy1; t1_rcv := time;
      x2_rcv := x2; y2_rcv := y2; vx2_rcv := vx2; vy2_rcv := vy2; t2_rcv := time;
      x3_rcv := x3; y3_rcv := y3; vx3_rcv := vx3; vy3_rcv := vy3; t3_rcv := time;
    end if;
  end when;
  
end AirTrioResilientB;