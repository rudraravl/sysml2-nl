model AUVDiveA
  // ===== Stated physical parameters =====
  parameter Real m = 85.0 "Hull mass [kg]";
  parameter Real hullLength = 1.5 "Hull length [m]";
  parameter Real dispVol = 0.083 "Displaced volume [m3]";
  parameter Real rho_sw = 1025.0 "Seawater density [kg/m3]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real FmaxThr = 79.2 "Command magnitude limit per thruster [N]";

  // ===== Derived / assumed (flagged as assumptions) =====
  parameter Real Larm = 0.5*hullLength "Thruster lever arm [m] (assumed)";
  parameter Real Ixx = m*(hullLength/4.0)^2/3.0 "Roll inertia [kg.m2] (assumed)";
  parameter Real Iyy = m*(hullLength/4.0)^2/3.0 "Pitch inertia [kg.m2] (assumed)";
  parameter Real Izz = m*(hullLength/2.0)^2/3.0 "Yaw inertia [kg.m2] (assumed)";
  parameter Real CdSurge = 10.0 "Surge quadratic drag coeff [kg/m] (assumed)";
  parameter Real CdHeave = 10.0 "Heave quadratic drag coeff [kg/m] (assumed)";
  parameter Real CdYaw = 4.0 "Yaw quadratic drag coeff [kg.m2] (assumed)";
  parameter Real CdRoll = 3.0 "Roll quadratic drag coeff [kg.m2] (assumed)";
  parameter Real CdPitch = 3.0 "Pitch quadratic drag coeff [kg.m2] (assumed)";
  parameter Real GM = 0.05 "Metacentric height [m] (assumed)";
  parameter Real KrestRoll = m*g*GM "Roll restoring stiffness [N.m/rad]";
  parameter Real KrestPitch = m*g*GM "Pitch restoring stiffness [N.m/rad]";

  // ===== Control gains =====
  parameter Real Kp_depth = 3.0 "Depth outer-loop gain [1/s]";
  parameter Real Kw_heave = 4.0 "Heave inner-loop gain [1/s]";
  parameter Real Kp_surge = 2.0 "Surge position gain [1/s]";
  parameter Real Kw_surge = 4.0 "Surge inner-loop gain [1/s]";
  parameter Real Kp_yaw = 2.0 "Heading outer-loop gain [1/s]";
  parameter Real Kr_yaw = 3.0 "Yaw inner-loop gain [1/s]";
  parameter Real Kp_pitch = 4.0 "Pitch outer-loop gain [1/s]";
  parameter Real Kq_pitch = 3.0 "Pitch inner-loop gain [1/s]";
  parameter Real wlim = 3.5 "Heave velocity command limit [m/s]";
  parameter Real ulim = 2.0 "Surge velocity command limit [m/s]";
  parameter Real rlim = 1.0 "Rate command limit [rad/s]";

  // ===== Scenario =====
  parameter Real z_deep = 8.0 "Target deep depth [m]";
  parameter Real z_shallow = 3.0 "Target return depth [m]";
  parameter Real tEnd = 8.0 "Scenario duration [s]";
  parameter Real t1 = tEnd/3.0 "End of first third [s]";
  parameter Real t2 = 2.0*tEnd/3.0 "End of middle third [s]";
  parameter Real v_desc = z_deep/t1 "Descent reference speed [m/s]";
  parameter Real v_asc = (z_shallow - z_deep)/(tEnd - t2) "Ascent reference speed [m/s]";
  parameter Real Fdist = 40.0 "Current disturbance force [N]";

  // ===== Dynamic states =====
  Real z(start=0.0, fixed=true) "Depth [m], positive downward";
  Real w(start=0.0, fixed=true) "Heave velocity [m/s]";
  Real x(start=0.0, fixed=true) "Surge position [m]";
  Real u(start=0.0, fixed=true) "Surge velocity [m/s]";
  Real psi(start=0.0, fixed=true) "Yaw heading [rad]";
  Real r(start=0.0, fixed=true) "Yaw rate [rad/s]";
  Real phi(start=0.0, fixed=true) "Roll angle [rad]";
  Real p_ang(start=0.0, fixed=true) "Roll rate [rad/s]";
  Real theta(start=0.0, fixed=true) "Pitch angle [rad]";
  Real q(start=0.0, fixed=true) "Pitch rate [rad/s]";

  // ===== Constants =====
  Real W "Weight [N]";
  Real B "Buoyancy [N]";
  Real Wnet "Net weight (W-B) [N]";

  // ===== Disturbance =====
  Real Fcurrent "Current disturbance force [N]";

  // ===== Drag forces =====
  Real dragHeave "Heave drag [N]";
  Real dragSurge "Surge drag [N]";
  Real dragYaw "Yaw drag [N.m]";
  Real dragRoll "Roll drag [N.m]";
  Real dragPitch "Pitch drag [N.m]";

  // ===== Commanded body wrenches =====
  Real Fheave_cmd "Commanded heave force [N]";
  Real Fsurge_cmd "Commanded surge force [N]";
  Real Myaw_cmd "Commanded yaw moment [N.m]";
  Real Mpitch_cmd "Commanded pitch moment [N.m]";

  // ===== Actual body wrenches =====
  Real Fheave_act "Actual heave force [N]";
  Real Fsurge_act "Actual surge force [N]";
  Real Myaw_act "Actual yaw moment [N.m]";
  Real Mpitch_act "Actual pitch moment [N.m]";

  // ===== Individual thruster commands =====
  Real Th1 "Fore heave thruster [N]";
  Real Th2 "Aft heave thruster [N]";
  Real Ts1 "Port surge thruster [N]";
  Real Ts2 "Starboard surge thruster [N]";

  // ===== Reference and control signals =====
  Real z_ref "Depth reference [m]";
  Real v_ref "Depth reference rate [m/s]";
  Real psi_ref "Heading reference [rad]";
  Real depth_err "Signed depth tracking error [m]";
  Real track_err "Primary tracking error magnitude [m]";
  Real w_cmd "Heave velocity command [m/s]";
  Real u_cmd "Surge velocity command [m/s]";
  Real r_cmd "Yaw rate command [rad/s]";
  Real q_cmd "Pitch rate command [rad/s]";

  // ===== Sensor outputs =====
  Real z_meas "Depth sensor [m]";
  Real w_meas "Heave velocity sensor [m/s]";
  Real u_meas "Surge velocity sensor [m/s]";
  Real psi_meas "Heading sensor [rad]";
  Real r_meas "Yaw rate sensor [rad/s]";
  Real phi_meas "Roll sensor [rad]";
  Real p_meas "Roll rate sensor [rad/s]";
  Real theta_meas "Pitch sensor [rad]";
  Real q_meas "Pitch rate sensor [rad/s]";

equation
  // Gravity and buoyancy
  W = m*g;
  B = rho_sw*dispVol*g;
  Wnet = W - B;

  // Reference trajectory
  if time < t1 then
    z_ref = v_desc*time;
    v_ref = v_desc;
  elseif time < t2 then
    z_ref = z_deep;
    v_ref = 0.0;
  else
    z_ref = z_deep + v_asc*(time - t2);
    v_ref = v_asc;
  end if;
  psi_ref = 0.0;

  // Current disturbance: 40 N during middle third
  if time >= t1 and time < t2 then
    Fcurrent = Fdist;
  else
    Fcurrent = 0.0;
  end if;

  // Sensors (direct measurement)
  z_meas = z;
  w_meas = w;
  u_meas = u;
  psi_meas = psi;
  r_meas = r;
  phi_meas = phi;
  p_meas = p_ang;
  theta_meas = theta;
  q_meas = q;

  // Quadratic drag (using built-in abs)
  dragHeave = -CdHeave*abs(w)*w;
  dragSurge = -CdSurge*abs(u)*u;
  dragYaw = -CdYaw*abs(r)*r;
  dragRoll = -CdRoll*abs(p_ang)*p_ang;
  dragPitch = -CdPitch*abs(q)*q;

  // ===== Cascaded depth control =====
  depth_err = z_ref - z_meas;
  track_err = abs(depth_err);
  w_cmd = max(-wlim, min(wlim, v_ref + Kp_depth*depth_err));
  Fheave_cmd = m*(Kw_heave*(w_cmd - w_meas)) - Wnet - dragHeave;

  // ===== Surge control (hold x=0) =====
  u_cmd = max(-ulim, min(ulim, Kp_surge*(0.0 - x)));
  Fsurge_cmd = m*(Kw_surge*(u_cmd - u_meas)) - dragSurge;

  // ===== Heading control =====
  r_cmd = max(-rlim, min(rlim, Kp_yaw*(psi_ref - psi_meas)));
  Myaw_cmd = Izz*(Kr_yaw*(r_cmd - r_meas)) - dragYaw;

  // ===== Pitch control =====
  q_cmd = max(-rlim, min(rlim, Kp_pitch*(0.0 - theta_meas)));
  Mpitch_cmd = Iyy*(Kq_pitch*(q_cmd - q_meas)) - dragPitch;

  // ===== Bounded allocation to four thrusters =====
  // Heave pair: Fheave = Th1+Th2, Mpitch = (Th2-Th1)*Larm
  Th1 = max(-FmaxThr, min(FmaxThr, Fheave_cmd/2.0 - Mpitch_cmd/(2.0*Larm)));
  Th2 = max(-FmaxThr, min(FmaxThr, Fheave_cmd/2.0 + Mpitch_cmd/(2.0*Larm)));
  // Surge pair: Fsurge = Ts1+Ts2, Myaw = (Ts1-Ts2)*Larm
  Ts1 = max(-FmaxThr, min(FmaxThr, Fsurge_cmd/2.0 + Myaw_cmd/(2.0*Larm)));
  Ts2 = max(-FmaxThr, min(FmaxThr, Fsurge_cmd/2.0 - Myaw_cmd/(2.0*Larm)));

  // Actual body wrenches
  Fheave_act = Th1 + Th2;
  Fsurge_act = Ts1 + Ts2;
  Myaw_act = (Ts1 - Ts2)*Larm;
  Mpitch_act = (Th2 - Th1)*Larm;

  // ===== Rigid-body dynamics =====
  // Heave / depth
  der(z) = w;
  m*der(w) = Fheave_act + Wnet + dragHeave;
  // Surge
  der(x) = u;
  m*der(u) = Fsurge_act + Fcurrent + dragSurge;
  // Yaw
  der(psi) = r;
  Izz*der(r) = Myaw_act + dragYaw;
  // Roll (passively stable)
  der(phi) = p_ang;
  Ixx*der(p_ang) = -KrestRoll*phi + dragRoll;
  // Pitch (actively controlled + passive restoring)
  der(theta) = q;
  Iyy*der(q) = Mpitch_act - KrestPitch*theta + dragPitch;

  annotation (
    Documentation(info="Free-base marine robot AUVDiveA. 85 kg hull, 1.5 m, 0.083 m3 disp. "
      "Four bidirectional thrusters (2 surge, 2 heave), 79.2 N each. "
      "Cascaded depth + attitude control with bounded per-thruster allocation. "
      "40 N current disturbance during middle third. Run 8 s at 80 Hz. "
      "Unstated hydrodynamic parameters (drag, GM, inertias, lever arm) are explicit assumptions."),
    experiment(StartTime=0.0, StopTime=8.0, Tolerance=1e-6, Interval=0.0125));
end AUVDiveA;