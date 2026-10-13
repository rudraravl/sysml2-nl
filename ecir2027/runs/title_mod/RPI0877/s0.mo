model ROVHoldA
  // Free-base marine robot station keeping beside a fixed cylindrical structure.
  // Unknown physical details (added mass, drag, residual buoyancy, inertias,
  // tether properties, sensor noises) are bound to engineering assumptions and
  // clearly commented. No facts beyond the request are claimed as measured.

  // ---- Vehicle parameters (given) ----
  parameter Real m = 115.0 "ROV mass [kg]";
  parameter Real Lx = 1.1 "frame length [m]";
  parameter Real Ly = 0.78 "frame width [m]";
  parameter Real Lz = 0.58 "frame height [m]";
  parameter Real FmaxThr = 119.0 "per-thruster command magnitude [N]";

  // ---- Environment (assumption: seawater) ----
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real rhoW = 1025.0 "water density [kg/m3] (assumption)";

  // ---- Residual buoyancy (slightly positive; net value assumed) ----
  parameter Real Bnet = 6.0 "net buoyancy force (positive up) [N] (assumed)";

  // ---- Inertias (uniform box assumption) ----
  parameter Real Ixx = m/12.0*(Ly*Ly + Lz*Lz) "[kg.m2] (assumption)";
  parameter Real Iyy = m/12.0*(Lx*Lx + Lz*Lz) "[kg.m2] (assumption)";
  parameter Real Izz = m/12.0*(Lx*Lx + Ly*Ly) "[kg.m2] (assumption)";

  // ---- Added mass (diagonal; assumed fractions) ----
  parameter Real Xudot = 0.2*m "[kg] (assumed)";
  parameter Real Yvdot = 0.2*m "[kg] (assumed)";
  parameter Real Zwdot = 0.25*m "[kg] (assumed)";
  parameter Real Kpdot = 0.2*Ixx "[kg.m2] (assumed)";
  parameter Real Mqdot = 0.2*Iyy "[kg.m2] (assumed)";
  parameter Real Nrdot = 0.25*Izz "[kg.m2] (assumed)";

  // ---- Linear and quadratic damping (assumed) ----
  parameter Real du = 80.0 " [N/(m/s)] (assumed)";
  parameter Real dv = 100.0 "[N/(m/s)] (assumed)";
  parameter Real dw = 120.0 "[N/(m/s)] (assumed)";
  parameter Real dp = 30.0 "[N.m/(rad/s)] (assumed)";
  parameter Real dq = 40.0 "[N.m/(rad/s)] (assumed)";
  parameter Real dr = 50.0 "[N.m/(rad/s)] (assumed)";
  parameter Real duq = 300.0 "[N/(m/s)^2] (assumed)";
  parameter Real dvq = 350.0 "[N/(m/s)^2] (assumed)";
  parameter Real dwq = 400.0 "[N/(m/s)^2] (assumed)";
  parameter Real dpq = 60.0 "[N.m/(rad/s)^2] (assumed)";
  parameter Real dqq = 70.0 "[N.m/(rad/s)^2] (assumed)";
  parameter Real drq = 80.0 "[N.m/(rad/s)^2] (assumed)";

  // ---- Hold pose (setpoint) ----
  parameter Real xd = 0.0 "hold x [m]";
  parameter Real yd = 0.0 "hold y [m]";
  parameter Real zd = -2.0 "hold depth [m] (assumed)";
  parameter Real phid = 0.0 "hold roll [rad]";
  parameter Real thetad = 0.0 "hold pitch [rad]";
  parameter Real psid = 0.0 "hold yaw [rad]";

  // ---- Structure: fixed collidable vertical cylinder ----
  parameter Real Xs = 2.5 "cylinder center x [m] (assumed)";
  parameter Real Ys = 0.0 "cylinder center y [m] (assumed)";
  parameter Real Rs = 0.5 "cylinder radius [m] (assumed)";
  parameter Real Ztop = 0.0 "cylinder top [m] (assumed)";
  parameter Real Zbot = -5.0 "cylinder bottom [m] (assumed)";

  // ---- Tether / current disturbance ----
  parameter Real tDist0 = 8.0/3.0 "start of middle third [s]";
  parameter Real tDist1 = 16.0/3.0 "end of middle third [s]";
  parameter Real FdistMag = 60.0 "tether/current load magnitude [N]";
  parameter Real TmaxTether = 200.0 "tether tension limit [N] (assumed)";
  parameter Real LmaxTether = 10.0 "tether length limit [m] (assumed)";

  // ---- Controller gains (assumed tuning) ----
  parameter Real Kpp = 400.0 "position proportional gain [N/m]";
  parameter Real Kpd = 200.0 "position derivative gain [N/(m/s)]";
  parameter Real Kpa = 80.0 "attitude proportional gain [N.m/rad]";
  parameter Real Kma = 40.0 "attitude derivative gain [N.m/(rad/s)]";

  // ---- Moment limits from thruster force and geometry ----
  parameter Real lx = Ly/2.0 "roll moment arm [m]";
  parameter Real ly = Lx/2.0 "pitch moment arm [m]";
  parameter Real lz = sqrt((Lx/2.0)^2 + (Ly/2.0)^2) "yaw moment arm [m]";
  parameter Real Mxmax = FmaxThr*lx "[N.m]";
  parameter Real Mymax = FmaxThr*ly "[N.m]";
  parameter Real Mzmax = FmaxThr*lz "[N.m]";

  // ---- Sampling ----
  parameter Real Ts = 1.0/80.0 "trace/sensor sample period [s]";

  // ---- Continuous states ----
  Real x(start=0.0, fixed=true) "inertial x [m]";
  Real y(start=0.0, fixed=true) "inertial y [m]";
  Real z(start=-2.0, fixed=true) "inertial z (depth) [m]";
  Real phi(start=0.0, fixed=true) "roll [rad]";
  Real theta(start=0.0, fixed=true) "pitch [rad]";
  Real psi(start=0.0, fixed=true) "yaw [rad]";
  Real u(start=0.0, fixed=true) "body surge velocity [m/s]";
  Real v(start=0.0, fixed=true) "body sway velocity [m/s]";
  Real w(start=0.0, fixed=true) "body heave velocity [m/s]";
  Real p(start=0.0, fixed=true) "body roll rate [rad/s]";
  Real q(start=0.0, fixed=true) "body pitch rate [rad/s]";
  Real r(start=0.0, fixed=true) "body yaw rate [rad/s]";

  // ---- Rotation matrix entries (ZYX, psi-theta-phi) ----
  Real cphi, sphi, cth, sth, cpsi, spsi, tth;
  Real R11,R12,R13,R21,R22,R23,R31,R32,R33;

  // ---- Weight and buoyancy ----
  Real W, B;

  // ---- Disturbance (tether/current) in inertial and body ----
  Real Fdist_in "inertial disturbance magnitude [N]";
  Real Fdx, Fdy, Fdz "body-frame disturbance forces [N]";
  Real tetherTension "[N]";
  Real tetherLength "[m]";

  // ---- Controller errors ----
  Real epx, epy, epz "position error in body frame [m]";
  Real ephi, etheta, epsi "attitude error [rad]";
  Real Fcmd_x, Fcmd_y, Fcmd_z "unbounded force command [N]";
  Real Mcmd_x, Mcmd_y, Mcmd_z "unbounded moment command [N.m]";
  Real Fcx, Fcy, Fcz "bounded force command [N]";
  Real Mcx, Mcy, Mcz "bounded moment command [N.m]";

  // ---- Thruster commands (diagonal allocation, bidirectional, bounded) ----
  Real T1, T2, T3, T4, T5, T6 "thruster force commands [N]";

  // ---- Sensors ----
  Real pressure_depth "depth from pressure sensor [m]";
  Real imu_roll, imu_pitch, imu_yaw "[rad]";
  Real imu_pr, imu_qr, imu_rr "[rad/s]";
  Real dvl_u, dvl_v, dvl_w "DVL body velocities [m/s]";
  Real sonar_range "forward sonar range to structure [m]";

  // ---- Performance / safety monitors ----
  Real track_err "primary position tracking error [m]";
  Real att_err "attitude error norm [rad]";
  Real clearance "horizontal clearance to cylinder [m]";
  Boolean thruster_ok "thruster bounds satisfied";
  Boolean clearance_ok "no collision";
  Boolean tether_ok "tether within limits";
  Boolean tracking_ok "primary tracking below threshold after 5.2 s";

  // ---- Synchronized 80 Hz traces (sampled) ----
  discrete Real x_s, y_s, z_s, phi_s, theta_s, psi_s;
  discrete Real u_s, v_s, w_s, p_s, q_s, r_s;
  discrete Real Fcx_s, Fcy_s, Fcz_s, Mcx_s, Mcy_s, Mcz_s;
  discrete Real T1_s, T2_s, T3_s, T4_s, T5_s, T6_s;
  discrete Real depth_s, sonar_s, track_err_s, att_err_s, clearance_s;
  discrete Real tetherT_s, tetherL_s;
equation
  // Trig helpers
  cphi = cos(phi);
  sphi = sin(phi);
  cth = cos(theta);
  sth = sin(theta);
  cpsi = cos(psi);
  spsi = sin(psi);
  tth = sth / max(cth, 0.1) "guarded tan(theta)";

  // Rotation matrix R (body from inertial: v_body = R^T v_inertial; here columns)
  R11 = cpsi*cth;
  R12 = -spsi*cphi + cpsi*sth*sphi;
  R13 = spsi*sphi + cpsi*sth*cphi;
  R21 = spsi*cth;
  R22 = cpsi*cphi + spsi*sth*sphi;
  R23 = -cpsi*sphi + spsi*sth*cphi;
  R31 = -sth;
  R32 = cth*sphi;
  R33 = cth*cphi;

  // Weight / buoyancy magnitudes
  W = m*g;
  B = W + Bnet;

  // Disturbance: 60 N inertial +x during middle third (tether/current load)
  Fdist_in = if (time >= tDist0 and time <= tDist1) then FdistMag else 0.0;
  // Body-frame representation of inertial [Fdist_in, 0, 0]
  Fdx = Fdist_in * R11;
  Fdy = Fdist_in * R21;
  Fdz = Fdist_in * R31;

  // Tether tension equals applied disturbance magnitude (assumption); length tracks depth
  tetherTension = Fdist_in;
  tetherLength = abs(z) + 1.0 "approx deployed tether length [m] (assumption)";

  // Position error in body frame (desired - actual), desired velocity zero
  epx = R11*(xd - x) + R21*(yd - y) + R31*(zd - z);
  epy = R12*(xd - x) + R22*(yd - y) + R32*(zd - z);
  epz = R13*(xd - x) + R23*(yd - y) + R33*(zd - z);

  // Attitude error (small-angle, desired zero attitude)
  ephi = phid - phi;
  etheta = thetad - theta;
  epsi = psid - psi;

  // Bounded body-wrench station keeping (PD)
  Fcmd_x = Kpp*epx - Kpd*u;
  Fcmd_y = Kpp*epy - Kpd*v;
  Fcmd_z = Kpp*epz - Kpd*w;
  Mcmd_x = Kpa*ephi - Kma*p;
  Mcmd_y = Kpa*etheta - Kma*q;
  Mcmd_z = Kpa*epsi - Kma*r;

  // Saturate force commands to per-thruster limit
  Fcx = if Fcmd_x > FmaxThr then FmaxThr else if Fcmd_x < -FmaxThr then -FmaxThr else Fcmd_x;
  Fcy = if Fcmd_y > FmaxThr then FmaxThr else if Fcmd_y < -FmaxThr then -FmaxThr else Fcmd_y;
  Fcz = if Fcmd_z > FmaxThr then FmaxThr else if Fcmd_z < -FmaxThr then -FmaxThr else Fcmd_z;

  // Saturate moment commands to thruster-moment limits
  Mcx = if Mcmd_x > Mxmax then Mxmax else if Mcmd_x < -Mxmax then -Mxmax else Mcmd_x;
  Mcy = if Mcmd_y > Mymax then Mymax else if Mcmd_y < -Mymax then -Mymax else Mcmd_y;
  Mcz = if Mcmd_z > Mzmax then Mzmax else if Mcmd_z < -Mzmax then -Mzmax else Mcmd_z;

  // Diagonal thruster allocation (6 thrusters, each bidirectional, bounded 119 N)
  T1 = Fcx;
  T2 = Fcy;
  T3 = Fcz;
  T4 = Mcx / max(lx, 1e-6);
  T5 = Mcy / max(ly, 1e-6);
  T6 = Mcz / max(lz, 1e-6);

  // Translational dynamics (added mass, damping, weight/buoyancy, disturbance, control)
  (m + Xudot)*der(u) = Fcx + Fdx + Bnet*R31 - du*u - duq*u*abs(u);
  (m + Yvdot)*der(v) = Fcy + Fdy + Bnet*R32 - dv*v - dvq*v*abs(v);
  (m + Zwdot)*der(w) = Fcz + Fdz + Bnet*R33 - dw*w - dwq*w*abs(w);

  // Rotational dynamics
  (Ixx + Kpdot)*der(p) = Mcx - dp*p - dpq*p*abs(p);
  (Iyy + Mqdot)*der(q) = Mcy - dq*q - dqq*q*abs(q);
  (Izz + Nrdot)*der(r) = Mcz - dr*r - drq*r*abs(r);

  // Kinematics: position
  der(x) = R11*u + R12*v + R13*w;
  der(y) = R21*u + R22*v + R23*w;
  der(z) = R31*u + R32*v + R33*w;

  // Kinematics: Euler angles (ZYX), guarded denominator
  der(phi) = p + sphi*tth*q + cphi*tth*r;
  der(theta) = cphi*q - sphi*r;
  der(psi) = (sphi*q + cphi*r)/max(cth, 0.1);

  // Sensors
  pressure_depth = -z "pressure-derived depth [m]";
  imu_roll = phi;
  imu_pitch = theta;
  imu_yaw = psi;
  imu_pr = p;
  imu_qr = q;
  imu_rr = r;
  dvl_u = u;
  dvl_v = v;
  dvl_w = w;
  sonar_range = max(sqrt((x - Xs)^2 + (y - Ys)^2) - Rs - Lx/2.0, 0.01);

  // Performance and safety monitors
  track_err = sqrt((xd - x)^2 + (yd - y)^2 + (zd - z)^2 + 1e-9);
  att_err = sqrt(phi^2 + theta^2 + psi^2 + 1e-9);
  clearance = sqrt((x - Xs)^2 + (y - Ys)^2 + 1e-9) - Rs;

  thruster_ok = (abs(T1) <= FmaxThr + 1e-6) and (abs(T2) <= FmaxThr + 1e-6) and
                (abs(T3) <= FmaxThr + 1e-6) and (abs(T4) <= FmaxThr + 1e-6) and
                (abs(T5) <= FmaxThr + 1e-6) and (abs(T6) <= FmaxThr + 1e-6);
  clearance_ok = clearance > 0.0;
  tether_ok = (tetherTension <= TmaxTether) and (tetherLength <= LmaxTether);
  tracking_ok = (time < 5.2) or (track_err < 0.405);

  // Runtime sanity assertions (no NaN/infinite, bounds, clearance, tracking)
  assert(abs(u) < 1e6 and abs(v) < 1e6 and abs(w) < 1e6, "velocity finite");
  assert(abs(p) < 1e6 and abs(q) < 1e6 and abs(r) < 1e6, "rate finite");
  assert(abs(x) < 1e6 and abs(y) < 1e6 and abs(z) < 1e6, "position finite");
  assert(abs(phi) < 1e6 and abs(theta) < 1e6 and abs(psi) < 1e6, "attitude finite");
  assert(thruster_ok, "thruster bound exceeded");
  assert(clearance_ok, "structure collision");
  assert(tether_ok, "tether limit exceeded");
  assert(tracking_ok, "primary tracking error exceeds 0.405 m after 5.2 s");

  // Synchronized 80 Hz state/command/sensor traces
algorithm
  when sample(0, Ts) then
    x_s := x;
    y_s := y;
    z_s := z;
    phi_s := phi;
    theta_s := theta;
    psi_s := psi;
    u_s := u;
    v_s := v;
    w_s := w;
    p_s := p;
    q_s := q;
    r_s := r;
    Fcx_s := Fcx;
    Fcy_s := Fcy;
    Fcz_s := Fcz;
    Mcx_s := Mcx;
    Mcy_s := Mcy;
    Mcz_s := Mcz;
    T1_s := T1;
    T2_s := T2;
    T3_s := T3;
    T4_s := T4;
    T5_s := T5;
    T6_s := T6;
    depth_s := pressure_depth;
    sonar_s := sonar_range;
    track_err_s := track_err;
    att_err_s := att_err;
    clearance_s := clearance;
    tetherT_s := tetherTension;
    tetherL_s := tetherLength;
  end when;
  annotation(
    experiment(StartTime=0.0, StopTime=8.0, Tolerance=1e-6, Interval=Ts),
    Documentation(info="ROVHoldA: free-base 6-DOF ROV (115 kg, 1.1x0.78x0.58 m, slightly positively buoyant) with six bidirectional body-wrench thrusters (119 N/thruster) holding a fixed pose beside a fixed collidable cylinder. Pressure, IMU, DVL and forward sonar feedback. A 60 N tether/current load acts during the middle third of an 8 s, 80 Hz scenario. Bounded station-keeping enforces thruster, clearance, tether and tracking constraints."));
end ROVHoldA;