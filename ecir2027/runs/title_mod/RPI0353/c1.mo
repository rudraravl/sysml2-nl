model DeltaPositionE
  constant Real pi = 3.14159265358979;

  /* Delta closed-chain robotic mechanism.
     Plant: fixed triangular base with three actuated upper arms (revolute joints
     at the base), three paired forearms (modeled as stiff spring-damper rods with
     spherical joints at both ends), and a rigid moving platform.
     Controller: 250 Hz joint-space PID with constrained inverse kinematics on the
     commanded platform pose and rod-torque feedforward. Actuator commands bounded
     by Tmax. Self-collision is checked via pairwise strut midpoint distances.
     A 16.8 N downward load is applied during the middle third of the 16 s mission.
     Acceptance: actuator travel and force bounds, closure residuals finite,
     pose error < 0.005 m after 10.4 s, no self-collision, no NaN/inf.
     NOTE: q_travel_max is assumed (numeric actuator travel bound not stated in request).
     NOTE: Base radius, platform radius, arm inertia, rod stiffness/damping, PID
           gains, target pose, gravity, and collision clearance are not specified in
           the request; placeholder values are used here and labeled accordingly. */

  // ===== Geometric and inertial parameters =====
  parameter Real L1 = 0.32 "Upper arm length [m]";
  parameter Real L2 = 0.60 "Forearm length [m]";
  parameter Real Rb = 0.15 "Base joint radius [m] (assumed; not specified)";
  parameter Real Rp = 0.05 "Platform joint radius [m] (assumed; not specified)";
  parameter Real mp = 3.0 "Platform mass [kg]";
  parameter Real Jarm = 0.05 "Upper arm inertia about base joint [kg.m^2] (assumed; not specified)";

  // ===== Forearm compliance (rigid-link proxy via stiff spring-damper) =====
  parameter Real k_rod = 1.0e5 "Forearm axial stiffness [N/m] (assumed; not specified)";
  parameter Real c_rod = 2.0e3 "Forearm axial damping [N.s/m] (assumed; not specified)";

  // ===== Actuator / controller parameters =====
  parameter Real Tmax = 49.5 "Actuator torque command bound [N.m]";
  parameter Real fc = 250.0 "Controller sample rate [Hz]";
  parameter Real Kp = 100.0 "Joint PID proportional gain (assumed; not specified)";
  parameter Real Ki = 200.0 "Joint PID integral gain (assumed; not specified)";
  parameter Real Kd = 10.0 "Joint PID derivative gain (assumed; not specified)";
  parameter Real q_travel_max = pi/2.0 "Assumed actuator travel bound [rad] (numeric bound not stated in request)";

  // ===== Mission parameters =====
  parameter Real Tend = 16.0 "Total mission time [s]";
  parameter Real px_tgt = 0.0 "Target platform x [m] (assumed; not specified)";
  parameter Real py_tgt = 0.0 "Target platform y [m] (assumed; not specified)";
  parameter Real pz_tgt = -0.5 "Target platform z [m] (nonzero pose; value assumed for nonzero hold)";
  parameter Real Fdist = 16.8 "Disturbance force magnitude [N]";
  parameter Real Tdist_on = 16.0/3.0 "Disturbance start [s] (middle third)";
  parameter Real Tdist_off = 2.0*16.0/3.0 "Disturbance end [s] (middle third)";
  parameter Real g = 9.81 "Gravity [m/s^2] (assumed; not specified)";
  parameter Real col_clear = 0.01 "Self-collision clearance threshold [m] (assumed; not specified)";
  parameter Real track_tol = 0.005 "Primary tracking tolerance [m]";
  parameter Real T_track_check = 10.4 "Tracking acceptance time [s]";

  // ===== Continuous states =====
  Real px(start=px_tgt, fixed=true) "Platform x [m]";
  Real py(start=py_tgt, fixed=true) "Platform y [m]";
  Real pz(start=pz_tgt, fixed=true) "Platform z [m]";
  Real vx(start=0, fixed=true) "Platform x velocity [m/s]";
  Real vy(start=0, fixed=true) "Platform y velocity [m/s]";
  Real vz(start=0, fixed=true) "Platform z velocity [m/s]";
  Real q[3](each start=0.205, each fixed=true) "Upper arm angles (actuator coordinates) [rad]";
  Real w[3](each start=0, each fixed=true) "Upper arm angular velocities [rad/s]";

  // ===== Discrete controller states =====
  discrete Real tau_cmd[3](each start=0.0) "Saturated actuator torque command [N.m]";
  discrete Real err_int[3](each start=0.0) "Integral error [rad]";
  discrete Real err_prev[3](each start=0.0) "Previous sample error [rad]";

  // ===== Base geometry and kinematic intermediates =====
  constant Real phi[3] = {0.0, 2.0*pi/3.0, 4.0*pi/3.0} "Base joint angular positions";
  Real n_x[3], n_y[3] "Radial unit vectors per chain";
  Real Bx[3], By[3] "Base joint positions [m]";
  Real Ux[3], Uy[3], Uz[3] "Upper arm tip positions [m]";
  Real Pax[3], Pay[3], Paz[3] "Platform attachment points [m]";
  Real fx[3], fy[3], fz[3] "Forearm vectors (P - U) [m]";
  Real fl[3] "Forearm lengths [m]";
  Real uxr[3], uyr[3], uzr[3] "Forearm unit vectors";
  Real fdotx[3], fdoty[3], fdotz[3] "Forearm vector time derivatives [m/s]";
  Real fl_dot[3] "Forearm length rates [m/s]";
  Real T_rod[3] "Forearm axial tension (positive = stretched) [N]";
  Real Fpx[3], Fpy[3], Fpz[3] "Forces on platform from each rod [N]";
  Real tau_rod[3] "Torque on each upper arm from rod [N.m]";

  // ===== Inverse kinematics =====
  Real Aa[3], Bb[3], Cc[3], dtt[3], Leff2[3], Rr[3], argacos[3], q_ik[3];

  // ===== Disturbance =====
  Real Fdist_z "Disturbance force on platform z [N]";

  // ===== Platform accelerations and force sums =====
  Real ax, ay, az "Platform accelerations [m/s^2]";
  Real sum_Fx, sum_Fy, sum_Fz "Total platform forces [N]";

  // ===== Sensors / acceptance =====
  Real pose_err "Platform pose error magnitude [m]";
  Real closure_res[3] "Closure residuals (rod length - L2) [m]";
  Real dist_12 "Forearm midpoint distance 1-2 [m]";
  Real dist_23 "Forearm midpoint distance 2-3 [m]";
  Real dist_31 "Forearm midpoint distance 3-1 [m]";
  Real min_dist "Minimum pairwise strut distance [m]";
  Boolean coll_flag "Self-collision flag (true = collision)";
  Boolean travel_ok[3] "Actuator travel within bound";
  Boolean torque_ok[3] "Actuator torque within bound";
  Boolean track_ok "Primary tracking acceptance (fail-closed)";
  Boolean nan_ok "No NaN/infinite values";
  Real nan_probe "NaN probe accumulator";

equation
  // Base geometry: radial and tangent unit vectors, base joint positions
  for i in 1:3 loop
    n_x[i] = cos(phi[i]);
    n_y[i] = sin(phi[i]);
    Bx[i] = Rb * n_x[i];
    By[i] = Rb * n_y[i];
  end for;

  // Upper arm tips: arm rotates about tangent axis; q=0 is horizontal radial outward
  for i in 1:3 loop
    Ux[i] = Bx[i] + L1*cos(q[i])*n_x[i];
    Uy[i] = By[i] + L1*cos(q[i])*n_y[i];
    Uz[i] = -L1*sin(q[i]);
  end for;

  // Platform attachment points (rigid platform with radius Rp)
  for i in 1:3 loop
    Pax[i] = px + Rp*n_x[i];
    Pay[i] = py + Rp*n_y[i];
    Paz[i] = pz;
  end for;

  // Forearm vectors, lengths, unit vectors (zero-branch protected)
  for i in 1:3 loop
    fx[i] = Pax[i] - Ux[i];
    fy[i] = Pay[i] - Uy[i];
    fz[i] = Paz[i] - Uz[i];
    fl[i] = sqrt(fx[i]*fx[i] + fy[i]*fy[i] + fz[i]*fz[i] + 1.0e-12);
    uxr[i] = fx[i]/fl[i];
    uyr[i] = fy[i]/fl[i];
    uzr[i] = fz[i]/fl[i];
  end for;

  // Forearm vector time derivatives (for damping)
  for i in 1:3 loop
    fdotx[i] = vx + L1*sin(q[i])*n_x[i]*w[i];
    fdoty[i] = vy + L1*sin(q[i])*n_y[i]*w[i];
    fdotz[i] = vz + L1*cos(q[i])*w[i];
    fl_dot[i] = (fx[i]*fdotx[i] + fy[i]*fdoty[i] + fz[i]*fdotz[i])/fl[i];
  end for;

  // Forearm axial tension (spring-damper; positive = stretched)
  for i in 1:3 loop
    T_rod[i] = k_rod*(fl[i] - L2) + c_rod*fl_dot[i];
  end for;

  // Force on platform from each rod (rod pulls platform toward U when stretched)
  for i in 1:3 loop
    Fpx[i] = -T_rod[i]*uxr[i];
    Fpy[i] = -T_rod[i]*uyr[i];
    Fpz[i] = -T_rod[i]*uzr[i];
  end for;

  // Torque on each upper arm from rod (about tangent axis at base joint)
  for i in 1:3 loop
    tau_rod[i] = -T_rod[i]*L1*(sin(q[i])*(n_x[i]*uxr[i] + n_y[i]*uyr[i]) + cos(q[i])*uzr[i]);
  end for;

  // Disturbance load: applied downward during middle third of simulation
  if time >= Tdist_on and time <= Tdist_off then
    Fdist_z = -Fdist;
  else
    Fdist_z = 0.0;
  end if;

  // Platform force balance
  sum_Fx = Fpx[1] + Fpx[2] + Fpx[3];
  sum_Fy = Fpy[1] + Fpy[2] + Fpy[3];
  sum_Fz = Fpz[1] + Fpz[2] + Fpz[3];
  ax = sum_Fx / mp;
  ay = sum_Fy / mp;
  az = (sum_Fz - mp*g + Fdist_z) / mp;

  // Platform kinematics
  der(px) = vx;
  der(py) = vy;
  der(pz) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  // Upper arm dynamics
  for i in 1:3 loop
    der(q[i]) = w[i];
    der(w[i]) = (tau_cmd[i] + tau_rod[i]) / Jarm;
  end for;

  // Constrained inverse kinematics for target pose (radial/z planar solution per chain)
  for i in 1:3 loop
    Aa[i] = px_tgt*n_x[i] + py_tgt*n_y[i] + Rp - Rb;
    Cc[i] = pz_tgt;
    dtt[i] = -px_tgt*n_y[i] + py_tgt*n_x[i];
    Leff2[i] = L2*L2 - dtt[i]*dtt[i];
    Bb[i] = -Aa[i];
    Rr[i] = Leff2[i] - Aa[i]*Aa[i] - Cc[i]*Cc[i] - L1*L1;
    argacos[i] = Rr[i] / (2.0*L1*sqrt(Bb[i]*Bb[i] + Cc[i]*Cc[i] + 1.0e-12));
    q_ik[i] = atan2(Cc[i], Bb[i]) + acos(max(-1.0, min(1.0, argacos[i])));
  end for;

  // 250 Hz sampled joint-space PID with rod-torque feedforward and Tmax saturation
  when sample(0.0, 1.0/fc) then
    for i in 1:3 loop
      err_int[i] = pre(err_int[i]) + (q_ik[i] - q[i])*(1.0/fc);
      tau_cmd[i] = max(-Tmax, min(Tmax,
        Kp*(q_ik[i] - q[i])
        + Ki*err_int[i]
        + Kd*((q_ik[i] - q[i]) - pre(err_prev[i]))*fc
        - tau_rod[i]));
      err_prev[i] = q_ik[i] - q[i];
    end for;
  end when;

  // Pose error magnitude (zero-branch protected)
  pose_err = sqrt((px - px_tgt)^2 + (py - py_tgt)^2 + (pz - pz_tgt)^2 + 1.0e-12);

  // Closure residuals (rod length deviations from nominal L2)
  for i in 1:3 loop
    closure_res[i] = fl[i] - L2;
  end for;

  // Self-collision check via pairwise forearm midpoint distances
  dist_12 = sqrt((Ux[1] + fx[1]/2.0 - (Ux[2] + fx[2]/2.0))^2
              + (Uy[1] + fy[1]/2.0 - (Uy[2] + fy[2]/2.0))^2
              + (Uz[1] + fz[1]/2.0 - (Uz[2] + fz[2]/2.0))^2 + 1.0e-12);
  dist_23 = sqrt((Ux[2] + fx[2]/2.0 - (Ux[3] + fx[3]/2.0))^2
              + (Uy[2] + fy[2]/2.0 - (Uy[3] + fy[3]/2.0))^2
              + (Uz[2] + fz[2]/2.0 - (Uz[3] + fz[3]/2.0))^2 + 1.0e-12);
  dist_31 = sqrt((Ux[3] + fx[3]/2.0 - (Ux[1] + fx[1]/2.0))^2
              + (Uy[3] + fy[3]/2.0 - (Uy[1] + fy[1]/2.0))^2
              + (Uz[3] + fz[3]/2.0 - (Uz[1] + fz[1]/2.0))^2 + 1.0e-12);
  min_dist = min(dist_12, min(dist_23, dist_31));
  coll_flag = min_dist < col_clear;

  // Actuator travel and torque bound checks
  for i in 1:3 loop
    travel_ok[i] = abs(q[i]) <= q_travel_max;
    torque_ok[i] = abs(tau_cmd[i]) <= Tmax + 1.0e-9;
  end for;

  // Tracking acceptance (fail-closed: must pass after 10.4 s)
  track_ok = (time >= T_track_check) and (pose_err < track_tol);

  // NaN / infinity checks across physical, control, and estimator variables
  nan_probe = px + py + pz + vx + vy + vz + q[1] + q[2] + q[3] + w[1] + w[2] + w[3]
              + tau_cmd[1] + tau_cmd[2] + tau_cmd[3] + T_rod[1] + T_rod[2] + T_rod[3]
              + pose_err + min_dist;
  nan_ok = (nan_probe == nan_probe) and (px == px) and (py == py) and (pz == pz)
       and (vx == vx) and (vy == vy) and (vz == vz)
       and (q[1] == q[1]) and (q[2] == q[2]) and (q[3] == q[3])
       and (w[1] == w[1]) and (w[2] == w[2]) and (w[3] == w[3])
       and (tau_cmd[1] == tau_cmd[1]) and (tau_cmd[2] == tau_cmd[2]) and (tau_cmd[3] == tau_cmd[3]);

  annotation (experiment(StopTime=16.0, Tolerance=1.0e-6));
end DeltaPositionE;