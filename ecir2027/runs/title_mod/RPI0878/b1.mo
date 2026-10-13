model ROVHoldB
  "Free-base marine robot ROVHoldB: 6-DOF pose holding beside a fixed offshore cylinder";

  // ---- Physical parameters (SI units) ----
  parameter Real m = 115.0 "kg, frame mass";
  parameter Real Lx = 1.1 "m, frame length";
  parameter Real Ly = 0.78 "m, frame width";
  parameter Real Lz = 0.58 "m, frame height";
  parameter Real rx = 0.55 "m, thruster x-offset (half length)";
  parameter Real ry = 0.39 "m, thruster y-offset (half width)";
  parameter Real rz = 0.29 "m, thruster z-offset (half height)";
  parameter Real Ixx = m*(Ly*Ly + Lz*Lz)/12 "kg.m2";
  parameter Real Iyy = m*(Lx*Lx + Lz*Lz)/12 "kg.m2";
  parameter Real Izz = m*(Lx*Lx + Ly*Ly)/12 "kg.m2";
  parameter Real rho_water = 1025.0 "kg/m3";
  parameter Real g = 9.81 "m/s2";
  parameter Real Bnet = 15.0 "N, net positive buoyancy (up)";
  parameter Real Fmax = 135.0 "N, per-thruster command bound";
  parameter Real Rcyl = 1.5 "m, structure cylinder radius";
  parameter Real TetherLimit = 200.0 "N, tether load limit";
  parameter Real p_atm = 101325.0 "Pa";

  // ---- Control gains ----
  parameter Real Kp_pos = 300.0 "N/m";
  parameter Real Kd_pos = 371.0 "N.s/m";
  parameter Real Kp_att = 50.0 "N.m/rad";
  parameter Real Kd_att = 59.0 "N.m.s/rad";

  // ---- Desired fixed pose ----
  parameter Real x_des = 4.0 "m";
  parameter Real y_des = 0.0 "m";
  parameter Real z_des = -5.0 "m";
  parameter Real phi_des = 0.0 "rad";
  parameter Real theta_des = 0.0 "rad";
  parameter Real psi_des = 0.0 "rad";

  // ---- Rigid-body states ----
  Real x(start=3.8, fixed=true) "m";
  Real y(start=0.0, fixed=true) "m";
  Real z(start=-5.0, fixed=true) "m";
  Real vx(start=0.0, fixed=true) "m/s";
  Real vy(start=0.0, fixed=true) "m/s";
  Real vz(start=0.0, fixed=true) "m/s";
  Real phi(start=0.0, fixed=true) "rad, roll";
  Real theta(start=0.0, fixed=true) "rad, pitch";
  Real psi(start=0.0, fixed=true) "rad, yaw";
  Real wp(start=0.0, fixed=true) "rad/s, body roll rate";
  Real wq(start=0.0, fixed=true) "rad/s, body pitch rate";
  Real wr(start=0.0, fixed=true) "rad/s, body yaw rate";

  // ---- Trig and rotation matrix (ZYX Euler) ----
  Real cph;
  Real sph;
  Real cth;
  Real sth;
  Real cpsi;
  Real spsi;
  Real cth_safe;
  Real R11;
  Real R12;
  Real R13;
  Real R21;
  Real R22;
  Real R23;
  Real R31;
  Real R32;
  Real R33;

  // ---- Thruster commands ----
  Real u1_raw "N";
  Real u2_raw "N";
  Real u3_raw "N";
  Real u4_raw "N";
  Real u5_raw "N";
  Real u6_raw "N";
  Real u1 "N";
  Real u2 "N";
  Real u3 "N";
  Real u4 "N";
  Real u5 "N";
  Real u6 "N";

  // ---- Body wrench from saturated thrusters ----
  Real Fbx "N";
  Real Fby "N";
  Real Fbz "N";
  Real Mbx "N.m";
  Real Mby "N.m";
  Real Mbz "N.m";

  // ---- World-frame force ----
  Real Fwx "N";
  Real Fwy "N";
  Real Fwz "N";

  // ---- Disturbance / tether load ----
  Real Fdist "N";
  Real tether_load "N";

  // ---- Controller variables ----
  Real ex "m";
  Real ey "m";
  Real ez "m";
  Real Fwx_cmd "N";
  Real Fwy_cmd "N";
  Real Fwz_cmd "N";
  Real Fbx_cmd "N";
  Real Fby_cmd "N";
  Real Fbz_cmd "N";
  Real ephi "rad";
  Real etheta "rad";
  Real epsi "rad";
  Real Mbx_cmd "N.m";
  Real Mby_cmd "N.m";
  Real Mbz_cmd "N.m";

  // ---- Sensors ----
  Real depth "m";
  Real pressure "Pa";
  Real vbx "m/s";
  Real vby "m/s";
  Real vbz "m/s";
  Real clearance "m";
  Real sonar_range "m";

  // ---- Performance metrics ----
  Real pos_err "m";
  Real att_err "rad";

equation
  // Trigonometric quantities
  cph = cos(phi);
  sph = sin(phi);
  cth = cos(theta);
  sth = sin(theta);
  cpsi = cos(psi);
  spsi = sin(psi);
  cth_safe = if cth < 0.1 then 0.1 else cth;

  // Rotation matrix (ZYX Euler, body-to-world)
  R11 = cpsi*cth;
  R12 = cpsi*sth*sph - spsi*cph;
  R13 = cpsi*sth*cph + spsi*sph;
  R21 = spsi*cth;
  R22 = spsi*sth*sph + cpsi*cph;
  R23 = spsi*sth*cph - cpsi*sph;
  R31 = -sth;
  R32 = cth*sph;
  R33 = cth*cph;

  // Translational kinematics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  // Translational dynamics (world frame)
  m*der(vx) = Fwx + Fdist;
  m*der(vy) = Fwy;
  m*der(vz) = Fwz + Bnet;

  // Rotational dynamics (body frame, Euler equations)
  Ixx*der(wp) = Mbx + (Iyy - Izz)*wq*wr;
  Iyy*der(wq) = Mby + (Izz - Ixx)*wr*wp;
  Izz*der(wr) = Mbz + (Ixx - Iyy)*wp*wq;

  // Euler angle kinematics (ZYX)
  der(phi) = wp + sph*sth/cth_safe*wq + cph*sth/cth_safe*wr;
  der(theta) = cph*wq - sph*wr;
  der(psi) = sph/cth_safe*wq + cph/cth_safe*wr;

  // Controller: position error (world frame)
  ex = x_des - x;
  ey = y_des - y;
  ez = z_des - z;

  // Controller: desired world force (PD)
  Fwx_cmd = Kp_pos*ex - Kd_pos*vx;
  Fwy_cmd = Kp_pos*ey - Kd_pos*vy;
  Fwz_cmd = Kp_pos*ez - Kd_pos*vz;

  // Rotate world force command to body frame (Fb = R^T Fw)
  Fbx_cmd = R11*Fwx_cmd + R21*Fwy_cmd + R31*Fwz_cmd;
  Fby_cmd = R12*Fwx_cmd + R22*Fwy_cmd + R32*Fwz_cmd;
  Fbz_cmd = R13*Fwx_cmd + R23*Fwy_cmd + R33*Fwz_cmd;

  // Attitude error and desired body moment (PD)
  ephi = phi_des - phi;
  etheta = theta_des - theta;
  epsi = psi_des - psi;
  Mbx_cmd = Kp_att*ephi - Kd_att*wp;
  Mby_cmd = Kp_att*etheta - Kd_att*wq;
  Mbz_cmd = Kp_att*epsi - Kd_att*wr;

  // Inverse allocation (block-diagonal B)
  u1_raw = 0.5*(Fbx_cmd - Mbz_cmd/ry);
  u2_raw = 0.5*(Fbx_cmd + Mbz_cmd/ry);
  u3_raw = 0.5*(Fby_cmd + Mbx_cmd/rz);
  u4_raw = 0.5*(Fby_cmd - Mbx_cmd/rz);
  u5_raw = 0.5*(Fbz_cmd - Mby_cmd/rx);
  u6_raw = 0.5*(Fbz_cmd + Mby_cmd/rx);

  // Bidirectional thruster saturation to +/- Fmax
  u1 = if u1_raw > Fmax then Fmax else if u1_raw < (-Fmax) then (-Fmax) else u1_raw;
  u2 = if u2_raw > Fmax then Fmax else if u2_raw < (-Fmax) then (-Fmax) else u2_raw;
  u3 = if u3_raw > Fmax then Fmax else if u3_raw < (-Fmax) then (-Fmax) else u3_raw;
  u4 = if u4_raw > Fmax then Fmax else if u4_raw < (-Fmax) then (-Fmax) else u4_raw;
  u5 = if u5_raw > Fmax then Fmax else if u5_raw < (-Fmax) then (-Fmax) else u5_raw;
  u6 = if u6_raw > Fmax then Fmax else if u6_raw < (-Fmax) then (-Fmax) else u6_raw;

  // Forward allocation: body wrench from saturated thrusters
  Fbx = u1 + u2;
  Fby = u3 + u4;
  Fbz = u5 + u6;
  Mbx = rz*(u3 - u4);
  Mby = (-rx)*(u5 - u6);
  Mbz = ry*(u2 - u1);

  // World-frame force from body wrench
  Fwx = R11*Fbx + R12*Fby + R13*Fbz;
  Fwy = R21*Fbx + R22*Fby + R23*Fbz;
  Fwz = R31*Fbx + R32*Fby + R33*Fbz;

  // Disturbance: 84 N tether/current load during middle third (3.33 s to 6.67 s)
  Fdist = if (time >= 10.0/3.0) and (time <= 20.0/3.0) then 84.0 else 0.0;
  tether_load = abs(Fdist);

  // Sensors
  depth = -z;
  pressure = p_atm + rho_water*g*depth;
  vbx = R11*vx + R21*vy + R31*vz;
  vby = R12*vx + R22*vy + R32*vz;
  vbz = R13*vx + R23*vy + R33*vz;
  clearance = sqrt(x*x + y*y) - Rcyl - 0.55;
  sonar_range = clearance;

  // Performance metrics
  pos_err = sqrt((x - x_des)*(x - x_des) + (y - y_des)*(y - y_des) + (z - z_des)*(z - z_des));
  att_err = sqrt(phi*phi + theta*theta + psi*psi);

  // Requirement assertions
  assert(Fmax > 0.0, "Thruster bound must be positive");
  assert(TetherLimit >= 0.0, "Tether limit must be non-negative");
  assert(abs(u1) <= Fmax + 1e-6, "u1 bound violated");
  assert(abs(u2) <= Fmax + 1e-6, "u2 bound violated");
  assert(abs(u3) <= Fmax + 1e-6, "u3 bound violated");
  assert(abs(u4) <= Fmax + 1e-6, "u4 bound violated");
  assert(abs(u5) <= Fmax + 1e-6, "u5 bound violated");
  assert(abs(u6) <= Fmax + 1e-6, "u6 bound violated");
  assert(tether_load <= TetherLimit + 1e-6, "Tether load limit violated");
  assert(clearance > 0.0, "Structure clearance violated (collision)");

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "ROVHoldB: 6-DOF station keeping beside a fixed cylinder. "
      "115 kg box frame, slightly positively buoyant, six bidirectional body-wrench "
      "thrusters bounded at 135 N. 84 N tether/current disturbance injected during "
      "the middle third (3.33 s to 6.67 s). Run at 100 Hz for 10 s. "
      "Sensors: pressure (depth), IMU (rates + attitude), DVL (body velocity), "
      "forward sonar (structure range/clearance)."));
end ROVHoldB;