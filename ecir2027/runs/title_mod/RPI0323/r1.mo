model StewartTraceE
  "Stewart platform (6-strut hexapod) tracing a 0.10 m radius circle.
   IK-based PD strut control at 250 Hz, force-limited at 4620 N/strut.
   12 N radial disturbance in middle third. Fixed obstacle with clearance.
   Fail-closed acceptance: joint/effort bounds, closure, path, singularity,
   clearance, and NaN checks."

  // ===== Physical Parameters =====
  parameter Real R_b = 0.45 "Base anchor radius [m]";
  parameter Real R_p = 0.32 "Platform anchor radius [m]";
  parameter Real M_plat = 36.0 "Platform mass [kg]";
  parameter Real L_min = 0.55 "Minimum strut length [m]";
  parameter Real L_max = 0.85 "Maximum strut length [m]";
  parameter Real F_max = 4620.0 "Per-strut force command limit [N]";
  parameter Real h_nom = 0.60 "Nominal platform height [m]";
  parameter Real r_circle = 0.10 "Circle radius [m]";
  parameter Real T_circle = 8.0 "Circle period [s]";
  parameter Real Kp_strut = 30000.0 "Strut proportional gain [N/m]";
  parameter Real Kd_strut = 400.0 "Strut derivative gain [N*s/m]";
  parameter Real g_const = 9.81 "Gravity [m/s^2]";
  parameter Real T_total = 16.0 "Total run time [s]";
  parameter Real F_dist_mag = 12.0 "Disturbance magnitude [N]";
  parameter Real Ts = 0.004 "Controller period [s] (250 Hz)";
  parameter Real obs_x = 0.55 "Obstacle center x [m]";
  parameter Real obs_y = 0.0 "Obstacle center y [m]";
  parameter Real obs_r = 0.05 "Obstacle radius [m]";
  parameter Real path_tol = 0.007 "Path error tolerance [m]";
  parameter Real t_check = 10.4 "Acceptance check time [s]";
  parameter Real eps = 1.0e-12 "Regularization epsilon";
  parameter Real omega = 2.0*3.141592653589793/T_circle "Angular freq [rad/s]";

  // ===== Base Anchor Angles [rad] =====
  parameter Real th_b1 = 0.0;
  parameter Real th_b2 = 1.0471975511965977;
  parameter Real th_b3 = 2.0943951023931953;
  parameter Real th_b4 = 3.141592653589793;
  parameter Real th_b5 = 4.1887902047863905;
  parameter Real th_b6 = 5.235987755982988;

  // ===== Platform Anchor Angles [rad] =====
  parameter Real th_p1 = 0.5235987755982988;
  parameter Real th_p2 = 1.5707963267948966;
  parameter Real th_p3 = 2.6179938779914944;
  parameter Real th_p4 = 3.6651914291880923;
  parameter Real th_p5 = 4.71238898038469;
  parameter Real th_p6 = 5.759586531581287;

  // ===== Platform State =====
  Real x(start=0.10, fixed=true) "Platform center x [m]";
  Real y(start=0.0, fixed=true) "Platform center y [m]";
  Real z(start=0.60, fixed=true) "Platform center z [m]";
  Real vx(start=0.0, fixed=true) "Platform vx [m/s]";
  Real vy(start=0.07853981633974483, fixed=true) "Platform vy [m/s]";
  Real vz(start=0.0, fixed=true) "Platform vz [m/s]";
  Real ax "Platform ax [m/s^2]";
  Real ay "Platform ay [m/s^2]";
  Real az "Platform az [m/s^2]";

  // ===== Base Anchor Positions [m] =====
  Real bx1,by1,bx2,by2,bx3,by3,bx4,by4,bx5,by5,bx6,by6;

  // ===== Platform Anchor Positions [m] =====
  Real px1,py1,px2,py2,px3,py3,px4,py4,px5,py5,px6,py6;

  // ===== Strut Vectors [m] =====
  Real dx1,dy1,dz1,dx2,dy2,dz2,dx3,dy3,dz3;
  Real dx4,dy4,dz4,dx5,dy5,dz5,dx6,dy6,dz6;

  // ===== Strut Lengths [m] =====
  Real L1,L2,L3,L4,L5,L6;

  // ===== Direction Cosines =====
  Real u1,v1,w1,u2,v2,w2,u3,v3,w3;
  Real u4,v4,w4,u5,v5,w5,u6,v6,w6;

  // ===== Desired Strut Lengths [m] =====
  Real Ld1,Ld2,Ld3,Ld4,Ld5,Ld6;

  // ===== Strut Rates [m/s] =====
  Real Lr1,Lr2,Lr3,Lr4,Lr5,Lr6;

  // ===== Raw Force Commands [N] =====
  Real Fc1,Fc2,Fc3,Fc4,Fc5,Fc6;

  // ===== Discrete Force Commands (limited, ZOH) [N] =====
  discrete Real F1,F2,F3,F4,F5,F6;

  // ===== Encoder Readings [m] =====
  Real Le1,Le2,Le3,Le4,Le5,Le6;

  // ===== Pose Measurement [m] =====
  Real x_meas,y_meas,z_meas;

  // ===== Trajectory =====
  Real x_des,y_des,z_des;

  // ===== Disturbance =====
  Real Fdist_x,Fdist_y,Fdist_z,Fdist_active;

  // ===== Acceptance Metrics =====
  Real path_error "3D tracking error [m]";
  Real closure_error "RMS strut tracking error [m]";
  Real sing_margin "Min strut length margin [m]";
  Real clearance "Platform-to-obstacle clearance [m]";
  Real L_min_actual "Current min strut length [m]";
  Real L_max_actual "Current max strut length [m]";

  // ===== Latched Violation Flags (fail-closed) =====
  discrete Boolean joint_violation(start=false, fixed=true);
  discrete Boolean effort_violation(start=false, fixed=true);
  discrete Boolean closure_violation(start=false, fixed=true);
  discrete Boolean singularity_violation(start=false, fixed=true);
  discrete Boolean clearance_violation(start=false, fixed=true);
  discrete Boolean path_violation(start=false, fixed=true);
  discrete Boolean nan_violation(start=false, fixed=true);

  // ===== Acceptance =====
  Boolean accepted "Fail-closed acceptance";
  Boolean accepted_after_check "Acceptance evaluated at/after t_check";

equation
  // ===== Base anchor positions =====
  bx1 = R_b*cos(th_b1);  by1 = R_b*sin(th_b1);
  bx2 = R_b*cos(th_b2);  by2 = R_b*sin(th_b2);
  bx3 = R_b*cos(th_b3);  by3 = R_b*sin(th_b3);
  bx4 = R_b*cos(th_b4);  by4 = R_b*sin(th_b4);
  bx5 = R_b*cos(th_b5);  by5 = R_b*sin(th_b5);
  bx6 = R_b*cos(th_b6);  by6 = R_b*sin(th_b6);

  // ===== Platform anchor positions (no platform rotation) =====
  px1 = x + R_p*cos(th_p1);  py1 = y + R_p*sin(th_p1);
  px2 = x + R_p*cos(th_p2);  py2 = y + R_p*sin(th_p2);
  px3 = x + R_p*cos(th_p3);  py3 = y + R_p*sin(th_p3);
  px4 = x + R_p*cos(th_p4);  py4 = y + R_p*sin(th_p4);
  px5 = x + R_p*cos(th_p5);  py5 = y + R_p*sin(th_p5);
  px6 = x + R_p*cos(th_p6);  py6 = y + R_p*sin(th_p6);

  // ===== Strut vectors =====
  dx1 = px1 - bx1;  dy1 = py1 - by1;  dz1 = z;
  dx2 = px2 - bx2;  dy2 = py2 - by2;  dz2 = z;
  dx3 = px3 - bx3;  dy3 = py3 - by3;  dz3 = z;
  dx4 = px4 - bx4;  dy4 = py4 - by4;  dz4 = z;
  dx5 = px5 - bx5;  dy5 = py5 - by5;  dz5 = z;
  dx6 = px6 - bx6;  dy6 = py6 - by6;  dz6 = z;

  // ===== Strut lengths (regularized against zero) =====
  L1 = sqrt(dx1*dx1 + dy1*dy1 + dz1*dz1 + eps);
  L2 = sqrt(dx2*dx2 + dy2*dy2 + dz2*dz2 + eps);
  L3 = sqrt(dx3*dx3 + dy3*dy3 + dz3*dz3 + eps);
  L4 = sqrt(dx4*dx4 + dy4*dy4 + dz4*dz4 + eps);
  L5 = sqrt(dx5*dx5 + dy5*dy5 + dz5*dz5 + eps);
  L6 = sqrt(dx6*dx6 + dy6*dy6 + dz6*dz6 + eps);

  // ===== Direction cosines =====
  u1 = dx1/L1;  v1 = dy1/L1;  w1 = dz1/L1;
  u2 = dx2/L2;  v2 = dy2/L2;  w2 = dz2/L2;
  u3 = dx3/L3;  v3 = dy3/L3;  w3 = dz3/L3;
  u4 = dx4/L4;  v4 = dy4/L4;  w4 = dz4/L4;
  u5 = dx5/L5;  v5 = dy5/L5;  w5 = dz5/L5;
  u6 = dx6/L6;  v6 = dy6/L6;  w6 = dz6/L6;

  // ===== Desired trajectory: circle in xy-plane at height h_nom =====
  x_des = r_circle * cos(omega * time);
  y_des = r_circle * sin(omega * time);
  z_des = h_nom;

  // ===== Inverse kinematics: desired strut lengths from desired pose =====
  Ld1 = sqrt((x_des + R_p*cos(th_p1) - bx1)^2 + (y_des + R_p*sin(th_p1) - by1)^2 + z_des^2 + eps);
  Ld2 = sqrt((x_des + R_p*cos(th_p2) - bx2)^2 + (y_des + R_p*sin(th_p2) - by2)^2 + z_des^2 + eps);
  Ld3 = sqrt((x_des + R_p*cos(th_p3) - bx3)^2 + (y_des + R_p*sin(th_p3) - by3)^2 + z_des^2 + eps);
  Ld4 = sqrt((x_des + R_p*cos(th_p4) - bx4)^2 + (y_des + R_p*sin(th_p4) - by4)^2 + z_des^2 + eps);
  Ld5 = sqrt((x_des + R_p*cos(th_p5) - bx5)^2 + (y_des + R_p*sin(th_p5) - by5)^2 + z_des^2 + eps);
  Ld6 = sqrt((x_des + R_p*cos(th_p6) - bx6)^2 + (y_des + R_p*sin(th_p6) - by6)^2 + z_des^2 + eps);

  // ===== Strut rates =====
  Lr1 = (dx1*vx + dy1*vy + dz1*vz) / L1;
  Lr2 = (dx2*vx + dy2*vy + dz2*vz) / L2;
  Lr3 = (dx3*vx + dy3*vy + dz3*vz) / L3;
  Lr4 = (dx4*vx + dy4*vy + dz4*vz) / L4;
  Lr5 = (dx5*vx + dy5*vy + dz5*vz) / L5;
  Lr6 = (dx6*vx + dy6*vy + dz6*vz) / L6;

  // ===== Raw force commands: PD on strut length error (closure stabilization) =====
  Fc1 = Kp_strut*(Ld1 - L1) - Kd_strut*Lr1;
  Fc2 = Kp_strut*(Ld2 - L2) - Kd_strut*Lr2;
  Fc3 = Kp_strut*(Ld3 - L3) - Kd_strut*Lr3;
  Fc4 = Kp_strut*(Ld4 - L4) - Kd_strut*Lr4;
  Fc5 = Kp_strut*(Ld5 - L5) - Kd_strut*Lr5;
  Fc6 = Kp_strut*(Ld6 - L6) - Kd_strut*Lr6;

  // ===== Discrete controller at 250 Hz: force limiting + ZOH + latched checks =====
  when sample(0, Ts) then
    // Force-limited commands (effort bound)
    F1 = if Fc1 > F_max then F_max elseif Fc1 < -F_max then -F_max else Fc1;
    F2 = if Fc2 > F_max then F_max elseif Fc2 < -F_max then -F_max else Fc2;
    F3 = if Fc3 > F_max then F_max elseif Fc3 < -F_max then -F_max else Fc3;
    F4 = if Fc4 > F_max then F_max elseif Fc4 < -F_max then -F_max else Fc4;
    F5 = if Fc5 > F_max then F_max elseif Fc5 < -F_max then -F_max else Fc5;
    F6 = if Fc6 > F_max then F_max elseif Fc6 < -F_max then -F_max else Fc6;

    // Latched fail-closed violation checks
    joint_violation = pre(joint_violation) or
      (L1 < L_min or L1 > L_max or L2 < L_min or L2 > L_max or
       L3 < L_min or L3 > L_max or L4 < L_min or L4 > L_max or
       L5 < L_min or L5 > L_max or L6 < L_min or L6 > L_max);

    effort_violation = pre(effort_violation) or
      (abs(Fc1) > F_max or abs(Fc2) > F_max or abs(Fc3) > F_max or
       abs(Fc4) > F_max or abs(Fc5) > F_max or abs(Fc6) > F_max);

    closure_violation = pre(closure_violation) or (closure_error > 0.01);

    singularity_violation = pre(singularity_violation) or (sing_margin < 0.001);

    clearance_violation = pre(clearance_violation) or (clearance < 0.001);

    path_violation = pre(path_violation) or
      ((time >= t_check) and (path_error > path_tol));

    nan_violation = pre(nan_violation) or
      (abs(x) > 1.0e10 or abs(y) > 1.0e10 or abs(z) > 1.0e10 or
       abs(vx) > 1.0e10 or abs(vy) > 1.0e10 or abs(vz) > 1.0e10 or
       abs(F1) > 1.0e10 or abs(F2) > 1.0e10 or abs(F3) > 1.0e10 or
       abs(F4) > 1.0e10 or abs(F5) > 1.0e10 or abs(F6) > 1.0e10 or
       abs(path_error) > 1.0e10 or abs(closure_error) > 1.0e10);
  end when;

  // ===== Actuator encoders (ideal) =====
  Le1 = L1;  Le2 = L2;  Le3 = L3;
  Le4 = L4;  Le5 = L5;  Le6 = L6;

  // ===== Direct output-pose measurement (ideal) =====
  x_meas = x;  y_meas = y;  z_meas = z;

  // ===== Disturbance: 12 N radial outward during middle third =====
  Fdist_active = if (time >= T_total/3.0 and time <= 2.0*T_total/3.0) then F_dist_mag else 0.0;
  Fdist_x = Fdist_active * cos(omega * time);
  Fdist_y = Fdist_active * sin(omega * time);
  Fdist_z = 0.0;

  // ===== Platform dynamics (Newton-Euler translational) =====
  M_plat * ax = F1*u1 + F2*u2 + F3*u3 + F4*u4 + F5*u5 + F6*u6 + Fdist_x;
  M_plat * ay = F1*v1 + F2*v2 + F3*v3 + F4*v4 + F5*v5 + F6*v6 + Fdist_y;
  M_plat * az = F1*w1 + F2*w2 + F3*w3 + F4*w4 + F5*w5 + F6*w6 - M_plat*g_const + Fdist_z;

  // ===== State integration =====
  der(x)  = vx;   der(y)  = vy;   der(z)  = vz;
  der(vx) = ax;   der(vy) = ay;   der(vz) = az;

  // ===== Acceptance metrics =====
  path_error = sqrt((x - x_des)^2 + (y - y_des)^2 + (z - z_des)^2 + eps);

  closure_error = sqrt(((L1-Ld1)^2 + (L2-Ld2)^2 + (L3-Ld3)^2 +
                        (L4-Ld4)^2 + (L5-Ld5)^2 + (L6-Ld6)^2) / 6.0 + eps);

  L_min_actual = min(min(min(L1, L2), min(L3, L4)), min(L5, L6));
  L_max_actual = max(max(max(L1, L2), max(L3, L4)), max(L5, L6));
  sing_margin = min(L_min_actual - L_min, L_max - L_max_actual);

  clearance = sqrt((x - obs_x)^2 + (y - obs_y)^2 + eps) - R_p - obs_r;

  // ===== Fail-closed acceptance =====
  accepted = not (joint_violation or effort_violation or closure_violation or
                  singularity_violation or clearance_violation or
                  path_violation or nan_violation);

  accepted_after_check = if (time >= t_check) then accepted else true;

  annotation(
    experiment(StartTime=0, StopTime=16.0, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Stewart platform hexapod: 6 variable-length struts
      (0.55-0.85 m) connecting a 0.45 m-radius base to a 36 kg, 0.32 m-radius
      platform. Traces a 0.10 m radius circle at 250 Hz for 16 s.
      IK-based PD strut control with force limiting (4620 N/strut).
      12 N radial disturbance in middle third. Obstacle at (0.55,0) r=0.05 m.
      Fail-closed: path_error < 0.007 m after 10.4 s, no NaN/infinite values.")
  );
end StewartTraceE;