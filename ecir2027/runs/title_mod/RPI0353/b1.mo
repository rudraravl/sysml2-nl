model DeltaPositionE
  import Modelica.Constants.pi;

  /* Delta closed-chain robotic mechanism.
     Plant: fixed triangular base with three actuated upper arms (0.32 m),
     three paired forearms (0.60 m) modeled as stiff spring-damper rods with
     spherical-equivalent joints, and a rigid 3 kg moving platform.
     Controller: 250 Hz joint-space PID with constrained inverse kinematics
     and rod-torque feedforward. Actuator commands bounded by 49.5 N.m.
     Self-collision checked via pairwise strut midpoint distances.
     16.8 N downward disturbance during middle third of 16 s mission.
     NOTE: q_travel_max is assumed (numeric actuator travel bound not stated). */

  // ===== Geometric and inertial parameters =====
  parameter Real L1 = 0.32 "Upper arm length [m]";
  parameter Real L2 = 0.60 "Forearm length [m]";
  parameter Real Rb = 0.15 "Base joint radius [m]";
  parameter Real Rp = 0.05 "Platform joint radius [m]";
  parameter Real mp = 3.0 "Platform mass [kg]";
  parameter Real Jarm = 0.05 "Upper arm inertia about base joint [kg.m^2]";

  // ===== Forearm compliance (rigid-link proxy via stiff spring-damper) =====
  parameter Real k_rod = 1.0e5 "Forearm axial stiffness [N/m]";
  parameter Real c_rod = 2.0e3 "Forearm axial damping [N.s/m]";

  // ===== Actuator / controller parameters =====
  parameter Real Tmax = 49.5 "Actuator torque command bound [N.m]";
  parameter Real fc = 250.0 "Controller sample rate [Hz]";
  parameter Real Kp = 100.0 "Joint PID proportional gain";
  parameter Real Ki = 200.0 "Joint PID integral gain";
  parameter Real Kd = 10.0 "Joint PID derivative gain";
  parameter Real q_travel_max = 1.5707963267948966 "Assumed actuator travel bound [rad] (pi/2; numeric bound not stated in request)";

  // ===== Mission parameters =====
  parameter Real Tend = 16.0 "Total mission time [s]";
  parameter Real px_tgt = 0.0 "Target platform x [m]";
  parameter Real py_tgt = 0.0 "Target platform y [m]";
  parameter Real pz_tgt = -0.5 "Target platform z [m] (nonzero pose)";
  parameter Real Fdist = 16.8 "Disturbance force magnitude [N]";
  parameter Real Tdist_on = 5.333333333333333 "Disturbance start [s] (middle third of 16 s)";
  parameter Real Tdist_off = 10.666666666666666 "Disturbance end [s] (middle third of 16 s)";
  parameter Real g = 9.81 "Gravity [m/s^2]";
  parameter Real col_clear = 0.01 "Self-collision clearance threshold [m]";
  parameter Real track_tol = 0.005 "Primary tracking tolerance [m]";
  parameter Real T_track_check = 10.4 "Tracking acceptance time [s]";

  // ===== Continuous states =====
  Real px(start=px_tgt, fixed=true) "Platform x [m]";
  Real py(start=py_tgt, fixed=true) "Platform y [m]";
  Real pz(start=pz_tgt, fixed=true) "Platform z [m]";
  Real vx(start=0, fixed=true) "Platform x velocity [m/s]";
  Real vy(start=0, fixed=true) "Platform y velocity [m/s]";
  Real vz(start=0, fixed=true) "Platform z velocity [m/s]";
  Real q1(start=0.2047, fixed=true) "Upper arm angle 1 (actuator coordinate) [rad]";
  Real q2(start=0.2047, fixed=true) "Upper arm angle 2 (actuator coordinate) [rad]";
  Real q3(start=0.2047, fixed=true) "Upper arm angle 3 (actuator coordinate) [rad]";
  Real w1(start=0, fixed=true) "Upper arm 1 angular velocity [rad/s]";
  Real w2(start=0, fixed=true) "Upper arm 2 angular velocity [rad/s]";
  Real w3(start=0, fixed=true) "Upper arm 3 angular velocity [rad/s]";

  // ===== Discrete controller states =====
  discrete Real tau_cmd1(start=0.0, fixed=true) "Saturated torque command 1 [N.m]";
  discrete Real tau_cmd2(start=0.0, fixed=true) "Saturated torque command 2 [N.m]";
  discrete Real tau_cmd3(start=0.0, fixed=true) "Saturated torque command 3 [N.m]";
  discrete Real err_int1(start=0.0, fixed=true) "Integral error 1 [rad]";
  discrete Real err_int2(start=0.0, fixed=true) "Integral error 2 [rad]";
  discrete Real err_int3(start=0.0, fixed=true) "Integral error 3 [rad]";
  discrete Real err_prev1(start=0.0, fixed=true) "Previous sample error 1 [rad]";
  discrete Real err_prev2(start=0.0, fixed=true) "Previous sample error 2 [rad]";
  discrete Real err_prev3(start=0.0, fixed=true) "Previous sample error 3 [rad]";

  // ===== Base geometry constants =====
  constant Real phi1 = 0.0 "Base joint 1 angular position [rad]";
  constant Real phi2 = 2.0*pi/3.0 "Base joint 2 angular position [rad]";
  constant Real phi3 = 4.0*pi/3.0 "Base joint 3 angular position [rad]";

  // ===== Kinematic intermediates per chain =====
  Real nx1, ny1, nx2, ny2, nx3, ny3 "Radial unit vectors";
  Real Bx1, By1, Bx2, By2, Bx3, By3 "Base joint positions [m]";
  Real Ux1, Uy1, Uz1, Ux2, Uy2, Uz2, Ux3, Uy3, Uz3 "Upper arm tips [m]";
  Real Pax1, Pay1, Paz1, Pax2, Pay2, Paz2, Pax3, Pay3, Paz3 "Platform attachments [m]";
  Real fx1, fy1, fz1, fx2, fy2, fz2, fx3, fy3, fz3 "Forearm vectors [m]";
  Real fl1, fl2, fl3 "Forearm lengths [m]";
  Real uxr1, uyr1, uzr1, uxr2, uyr2, uzr2, uxr3, uyr3, uzr3 "Forearm unit vectors";
  Real fdotx1, fdoty1, fdotz1, fdotx2, fdoty2, fdotz2, fdotx3, fdoty3, fdotz3 "Forearm vector rates [m/s]";
  Real fl_dot1, fl_dot2, fl_dot3 "Forearm length rates [m/s]";
  Real T_rod1, T_rod2, T_rod3 "Forearm axial tensions [N]";
  Real Fpx1, Fpy1, Fpz1, Fpx2, Fpy2, Fpz2, Fpx3, Fpy3, Fpz3 "Rod forces on platform [N]";
  Real tau_rod1, tau_rod2, tau_rod3 "Rod torques on upper arms [N.m]";

  // ===== Inverse kinematics intermediates =====
  Real Aa1, Aa2, Aa3 "IK radial offset [m]";
  Real Bb1, Bb2, Bb3 "IK B coefficient [m]";
  Real Cc1, Cc2, Cc3 "IK vertical offset [m]";
  Real dtt1, dtt2, dtt3 "IK tangential offset [m]";
  Real Leff2_1, Leff2_2, Leff2_3 "IK effective squared length [m^2]";
  Real Rr1, Rr2, Rr3 "IK cosine argument numerator [m^2]";
  Real argacos1, argacos2, argacos3 "IK cosine argument";
  Real q_ik1, q_ik2, q_ik3 "IK target joint angles [rad]";

  // ===== Disturbance =====
  Real Fdist_z "Disturbance force on platform z [N]";

  // ===== Platform dynamics =====
  Real ax, ay, az "Platform accelerations [m/s^2]";
  Real sum_Fx, sum_Fy, sum_Fz "Total platform forces [N]";

  // ===== Sensors and acceptance =====
  Real pose_err "Platform pose error magnitude [m]";
  Real closure_res1, closure_res2, closure_res3 "Closure residuals (rod length - L2) [m]";
  Real dist_12, dist_23, dist_31 "Pairwise strut midpoint distances [m]";
  Real min_dist "Minimum pairwise strut distance [m]";
  Boolean coll_flag "Self-collision flag (true = collision)";
  Boolean travel_ok1, travel_ok2, travel_ok3 "Actuator travel within bound";
  Boolean torque_ok1, torque_ok2, torque_ok3 "Actuator torque within bound";
  Boolean track_ok "Primary tracking acceptance (fail-closed)";
  Boolean nan_ok "No NaN or infinite values";
  Real nan_probe "NaN/inf probe accumulator";

equation
  // ===== Base geometry: radial unit vectors and joint positions =====
  nx1 = cos(phi1);  ny1 = sin(phi1);
  nx2 = cos(phi2);  ny2 = sin(phi2);
  nx3 = cos(phi3);  ny3 = sin(phi3);
  Bx1 = Rb*nx1;  By1 = Rb*ny1;
  Bx2 = Rb*nx2;  By2 = Rb*ny2;
  Bx3 = Rb*nx3;  By3 = Rb*ny3;

  // ===== Upper arm tip positions (q=0 is horizontal radial outward) =====
  Ux1 = Bx1 + L1*cos(q1)*nx1;
  Uy1 = By1 + L1*cos(q1)*ny1;
  Uz1 = -L1*sin(q1);
  Ux2 = Bx2 + L1*cos(q2)*nx2;
  Uy2 = By2 + L1*cos(q2)*ny2;
  Uz2 = -L1*sin(q2);
  Ux3 = Bx3 + L1*cos(q3)*nx3;
  Uy3 = By3 + L1*cos(q3)*ny3;
  Uz3 = -L1*sin(q3);

  // ===== Platform attachment points (rigid platform radius Rp) =====
  Pax1 = px + Rp*nx1;  Pay1 = py + Rp*ny1;  Paz1 = pz;
  Pax2 = px + Rp*nx2;  Pay2 = py + Rp*ny2;  Paz2 = pz;
  Pax3 = px + Rp*nx3;  Pay3 = py + Rp*ny3;  Paz3 = pz;

  // ===== Forearm vectors, lengths, unit vectors (zero-branch protected) =====
  fx1 = Pax1 - Ux1;  fy1 = Pay1 - Uy1;  fz1 = Paz1 - Uz1;
  fx2 = Pax2 - Ux2;  fy2 = Pay2 - Uy2;  fz2 = Paz2 - Uz2;
  fx3 = Pax3 - Ux3;  fy3 = Pay3 - Uy3;  fz3 = Paz3 - Uz3;
  fl1 = sqrt(fx1*fx1 + fy1*fy1 + fz1*fz1 + 1.0e-12);
  fl2 = sqrt(fx2*fx2 + fy2*fy2 + fz2*fz2 + 1.0e-12);
  fl3 = sqrt(fx3*fx3 + fy3*fy3 + fz3*fz3 + 1.0e-12);
  uxr1 = fx1/fl1;  uyr1 = fy1/fl1;  uzr1 = fz1/fl1;
  uxr2 = fx2/fl2;  uyr2 = fy2/fl2;  uzr2 = fz2/fl2;
  uxr3 = fx3/fl3;  uyr3 = fy3/fl3;  uzr3 = fz3/fl3;

  // ===== Forearm vector time derivatives (for damping) =====
  fdotx1 = vx + L1*sin(q1)*nx1*w1;
  fdoty1 = vy + L1*sin(q1)*ny1*w1;
  fdotz1 = vz + L1*cos(q1)*w1;
  fdotx2 = vx + L1*sin(q2)*nx2*w2;
  fdoty2 = vy + L1*sin(q2)*ny2*w2;
  fdotz2 = vz + L1*cos(q2)*w2;
  fdotx3 = vx + L1*sin(q3)*nx3*w3;
  fdoty3 = vy + L1*sin(q3)*ny3*w3;
  fdotz3 = vz + L1*cos(q3)*w3;
  fl_dot1 = (fx1*fdotx1 + fy1*fdoty1 + fz1*fdotz1)/fl1;
  fl_dot2 = (fx2*fdotx2 + fy2*fdoty2 + fz2*fdotz2)/fl2;
  fl_dot3 = (fx3*fdotx3 + fy3*fdoty3 + fz3*fdotz3)/fl3;

  // ===== Forearm axial tension (spring-damper; positive = stretched) =====
  T_rod1 = k_rod*(fl1 - L2) + c_rod*fl_dot1;
  T_rod2 = k_rod*(fl2 - L2) + c_rod*fl_dot2;
  T_rod3 = k_rod*(fl3 - L2) + c_rod*fl_dot3;

  // ===== Forces on platform from each rod =====
  Fpx1 = -T_rod1*uxr1;  Fpy1 = -T_rod1*uyr1;  Fpz1 = -T_rod1*uzr1;
  Fpx2 = -T_rod2*uxr2;  Fpy2 = -T_rod2*uyr2;  Fpz2 = -T_rod2*uzr2;
  Fpx3 = -T_rod3*uxr3;  Fpy3 = -T_rod3*uyr3;  Fpz3 = -T_rod3*uzr3;

  // ===== Torques on upper arms from rods (about tangent axis at base) =====
  tau_rod1 = -T_rod1*L1*(sin(q1)*(nx1*uxr1 + ny1*uyr1) + cos(q1)*uzr1);
  tau_rod2 = -T_rod2*L1*(sin(q2)*(nx2*uxr2 + ny2*uyr2) + cos(q2)*uzr2);
  tau_rod3 = -T_rod3*L1*(sin(q3)*(nx3*uxr3 + ny3*uyr3) + cos(q3)*uzr3);

  // ===== Disturbance load (if expression; downward during middle third) =====
  Fdist_z = if (time >= Tdist_on and time <= Tdist_off) then -Fdist else 0.0;

  // ===== Platform force balance and kinematics =====
  sum_Fx = Fpx1 + Fpx2 + Fpx3;
  sum_Fy = Fpy1 + Fpy2 + Fpy3;
  sum_Fz = Fpz1 + Fpz2 + Fpz3;
  ax = sum_Fx / mp;
  ay = sum_Fy / mp;
  az = (sum_Fz - mp*g + Fdist_z) / mp;
  der(px) = vx;
  der(py) = vy;
  der(pz) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  // ===== Upper arm dynamics =====
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(w1) = (tau_cmd1 + tau_rod1) / Jarm;
  der(w2) = (tau_cmd2 + tau_rod2) / Jarm;
  der(w3) = (tau_cmd3 + tau_rod3) / Jarm;

  // ===== Constrained inverse kinematics for target pose =====
  Aa1 = px_tgt*nx1 + py_tgt*ny1 + Rp - Rb;
  Aa2 = px_tgt*nx2 + py_tgt*ny2 + Rp - Rb;
  Aa3 = px_tgt*nx3 + py_tgt*ny3 + Rp - Rb;
  Cc1 = pz_tgt;
  Cc2 = pz_tgt;
  Cc3 = pz_tgt;
  dtt1 = -px_tgt*ny1 + py_tgt*nx1;
  dtt2 = -px_tgt*ny2 + py_tgt*nx2;
  dtt3 = -px_tgt*ny3 + py_tgt*nx3;
  Leff2_1 = L2*L2 - dtt1*dtt1;
  Leff2_2 = L2*L2 - dtt2*dtt2;
  Leff2_3 = L2*L2 - dtt3*dtt3;
  Bb1 = -Aa1;
  Bb2 = -Aa2;
  Bb3 = -Aa3;
  Rr1 = Leff2_1 - Aa1*Aa1 - Cc1*Cc1 - L1*L1;
  Rr2 = Leff2_2 - Aa2*Aa2 - Cc2*Cc2 - L1*L1;
  Rr3 = Leff2_3 - Aa3*Aa3 - Cc3*Cc3 - L1*L1;
  argacos1 = Rr1 / (2.0*L1*sqrt(Bb1*Bb1 + Cc1*Cc1 + 1.0e-12));
  argacos2 = Rr2 / (2.0*L1*sqrt(Bb2*Bb2 + Cc2*Cc2 + 1.0e-12));
  argacos3 = Rr3 / (2.0*L1*sqrt(Bb3*Bb3 + Cc3*Cc3 + 1.0e-12));
  q_ik1 = atan2(Cc1, Bb1) + acos(max(-1.0, min(1.0, argacos1)));
  q_ik2 = atan2(Cc2, Bb2) + acos(max(-1.0, min(1.0, argacos2)));
  q_ik3 = atan2(Cc3, Bb3) + acos(max(-1.0, min(1.0, argacos3)));

  // ===== 250 Hz sampled PID with feedforward and saturation (unrolled) =====
  when sample(0.0, 1.0/fc) then
    // Chain 1
    err_int1 = pre(err_int1) + (q_ik1 - q1)*(1.0/fc);
    tau_cmd1 = max(-Tmax, min(Tmax,
      Kp*(q_ik1 - q1) + Ki*err_int1
      + Kd*((q_ik1 - q1) - pre(err_prev1))*fc - tau_rod1));
    err_prev1 = q_ik1 - q1;
    // Chain 2
    err_int2 = pre(err_int2) + (q_ik2 - q2)*(1.0/fc);
    tau_cmd2 = max(-Tmax, min(Tmax,
      Kp*(q_ik2 - q2) + Ki*err_int2
      + Kd*((q_ik2 - q2) - pre(err_prev2))*fc - tau_rod2));
    err_prev2 = q_ik2 - q2;
    // Chain 3
    err_int3 = pre(err_int3) + (q_ik3 - q3)*(1.0/fc);
    tau_cmd3 = max(-Tmax, min(Tmax,
      Kp*(q_ik3 - q3) + Ki*err_int3
      + Kd*((q_ik3 - q3) - pre(err_prev3))*fc - tau_rod3));
    err_prev3 = q_ik3 - q3;
  end when;

  // ===== Pose error magnitude (zero-branch protected) =====
  pose_err = sqrt((px - px_tgt)^2 + (py - py_tgt)^2 + (pz - pz_tgt)^2 + 1.0e-12);

  // ===== Closure residuals (rod length deviations from nominal L2) =====
  closure_res1 = fl1 - L2;
  closure_res2 = fl2 - L2;
  closure_res3 = fl3 - L2;

  // ===== Self-collision check via pairwise forearm midpoint distances =====
  dist_12 = sqrt((Ux1 + fx1/2 - (Ux2 + fx2/2))^2
              + (Uy1 + fy1/2 - (Uy2 + fy2/2))^2
              + (Uz1 + fz1/2 - (Uz2 + fz2/2))^2 + 1.0e-12);
  dist_23 = sqrt((Ux2 + fx2/2 - (Ux3 + fx3/2))^2
              + (Uy2 + fy2/2 - (Uy3 + fy3/2))^2
              + (Uz2 + fz2/2 - (Uz3 + fz3/2))^2 + 1.0e-12);
  dist_31 = sqrt((Ux3 + fx3/2 - (Ux1 + fx1/2))^2
              + (Uy3 + fy3/2 - (Uy1 + fy1/2))^2
              + (Uz3 + fz3/2 - (Uz1 + fz1/2))^2 + 1.0e-12);
  min_dist = min(dist_12, min(dist_23, dist_31));
  coll_flag = min_dist < col_clear;

  // ===== Actuator travel and torque bound checks =====
  travel_ok1 = abs(q1) <= q_travel_max;
  travel_ok2 = abs(q2) <= q_travel_max;
  travel_ok3 = abs(q3) <= q_travel_max;
  torque_ok1 = abs(tau_cmd1) <= Tmax + 1.0e-9;
  torque_ok2 = abs(tau_cmd2) <= Tmax + 1.0e-9;
  torque_ok3 = abs(tau_cmd3) <= Tmax + 1.0e-9;

  // ===== Tracking acceptance (fail-closed: must pass after 10.4 s) =====
  track_ok = (time >= T_track_check) and (pose_err < track_tol);

  // ===== NaN / infinity checks =====
  nan_probe = px + py + pz + vx + vy + vz
            + q1 + q2 + q3 + w1 + w2 + w3
            + tau_cmd1 + tau_cmd2 + tau_cmd3
            + T_rod1 + T_rod2 + T_rod3
            + pose_err + min_dist;
  nan_ok = (nan_probe > -1.0e300) and (nan_probe < 1.0e300);

  annotation (experiment(StopTime=16.0, Tolerance=1.0e-6));
end DeltaPositionE;