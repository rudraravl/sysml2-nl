model ROVHoldB
  "Free-base marine robot ROVHoldB: 6-DOF pose holding beside a fixed offshore cylinder"
  parameter Real m = 115.0 "kg, frame mass";
  parameter Real Lx = 1.1 "m, frame length";
  parameter Real Ly = 0.78 "m, frame width";
  parameter Real Lz = 0.58 "m, frame height";
  parameter Real rx = 0.55 "m, thruster x-offset";
  parameter Real ry = 0.39 "m, thruster y-offset";
  parameter Real rz = 0.29 "m, thruster z-offset";
  parameter Real Ixx = m*(Ly*Ly + Lz*Lz)/12 "kg.m2";
  parameter Real Iyy = m*(Lx*Lx + Lz*Lz)/12 "kg.m2";
  parameter Real Izz = m*(Lx*Lx + Ly*Ly)/12 "kg.m2";
  parameter Real rho_water = 1025.0 "kg/m3";
  parameter Real g = 9.81 "m/s2";
  parameter Real Bnet = 15.0 "N, net positive buoyancy";
  parameter Real Fmax = 135.0 "N, per-thruster command bound";
  parameter Real Rcyl = 1.5 "m, structure cylinder radius";
  parameter Real TetherLimit = 200.0 "N, tether load limit";
  parameter Real p_atm = 101325.0 "Pa";

  parameter Real Kp_pos = 300.0 "N/m";
  parameter Real Kd_pos = 371.0 "N.s/m";
  parameter Real Kp_att = 50.0 "N.m/rad";
  parameter Real Kd_att = 59.0 "N.m.s/rad";

  parameter Real x_des = 4.0 "m";
  parameter Real y_des = 0.0 "m";
  parameter Real z_des = -5.0 "m";
  parameter Real phi_des = 0.0 "rad";
  parameter Real theta_des = 0.0 "rad";
  parameter Real psi_des = 0.0 "rad";

  Real x(start=3.8, fixed=true) "m";
  Real y(start=0.0, fixed=true) "m";
  Real z(start=-5.0, fixed=true) "m";
  Real vx(start=0.0, fixed=true) "m/s";
  Real vy(start=0.0, fixed=true) "m/s";
  Real vz(start=0.0, fixed=true) "m/s";
  Real phi(start=0.0, fixed=true) "rad";
  Real theta(start=0.0, fixed=true) "rad";
  Real psi(start=0.0, fixed=true) "rad";
  Real wp(start=0.0, fixed=true) "rad/s";
  Real wq(start=0.0, fixed=true) "rad/s";
  Real wr(start=0.0, fixed=true) "rad/s";

  Real cph = cos(phi);
  Real sph = sin(phi);
  Real cth = cos(theta);
  Real sth = sin(theta);
  Real cpsi = cos(psi);
  Real spsi = sin(psi);
  Real cth_safe = if cth < 0.1 then 0.1 else cth;
  Real R11 = cpsi*cth;
  Real R12 = cpsi*sth*sph - spsi*cph;
  Real R13 = cpsi*sth*cph + spsi*sph;
  Real R21 = spsi*cth;
  Real R22 = spsi*sth*sph + cpsi*cph;
  Real R23 = spsi*sth*cph - cpsi*sph;
  Real R31 = -sth;
  Real R32 = cth*sph;
  Real R33 = cth*cph;

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

  Real Fbx = u1 + u2 "N";
  Real Fby = u3 + u4 "N";
  Real Fbz = u5 + u6 "N";
  Real Mbx = rz*(u3 - u4) "N.m";
  Real Mby = -rx*(u5 - u6) "N.m";
  Real Mbz = ry*(u2 - u1) "N.m";

  Real Fwx = R11*Fbx + R12*Fby + R13*Fbz "N";
  Real Fwy = R21*Fbx + R22*Fby + R23*Fbz "N";
  Real Fwz = R31*Fbx + R32*Fby + R33*Fbz "N";

  Boolean disturb_active = (time >= 10.0/3.0) and (time <= 20.0/3.0);
  Real Fdist = if disturb_active then 84.0 else 0.0 "N";
  Real tether_load = abs(Fdist) "N";

  Real ex = x_des - x "m";
  Real ey = y_des - y "m";
  Real ez = z_des - z "m";
  Real Fwx_cmd = Kp_pos*ex - Kd_pos*vx "N";
  Real Fwy_cmd = Kp_pos*ey - Kd_pos*vy "N";
  Real Fwz_cmd = Kp_pos*ez - Kd_pos*vz "N";

  Real Fbx_cmd = R11*Fwx_cmd + R21*Fwy_cmd + R31*Fwz_cmd "N";
  Real Fby_cmd = R12*Fwx_cmd + R22*Fwy_cmd + R32*Fwz_cmd "N";
  Real Fbz_cmd = R13*Fwx_cmd + R23*Fwy_cmd + R33*Fwz_cmd "N";

  Real ephi = phi_des - phi "rad";
  Real etheta = theta_des - theta "rad";
  Real epsi = psi_des - psi "rad";
  Real Mbx_cmd = Kp_att*ephi - Kd_att*wp "N.m";
  Real Mby_cmd = Kp_att*etheta - Kd_att*wq "N.m";
  Real Mbz_cmd = Kp_att*epsi - Kd_att*wr "N.m";

  Real u1_raw_eq = 0.5*(Fbx_cmd - Mbz_cmd/ry) "N";
  Real u2_raw_eq = 0.5*(Fbx_cmd + Mbz_cmd/ry) "N";
  Real u3_raw_eq = 0.5*(Fby_cmd + Mbx_cmd/rz) "N";
  Real u4_raw_eq = 0.5*(Fby_cmd - Mbx_cmd/rz) "N";
  Real u5_raw_eq = 0.5*(Fbz_cmd - Mby_cmd/rx) "N";
  Real u6_raw_eq = 0.5*(Fbz_cmd + Mby_cmd/rx) "N";

  Real depth = -z "m";
  Real pressure = p_atm + rho_water*g*depth "Pa";
  Real vbx = R11*vx + R21*vy + R31*vz "m/s";
  Real vby = R12*vx + R22*vy + R32*vz "m/s";
  Real vbz = R13*vx + R23*vy + R33*vz "m/s";
  Real clearance = sqrt(x*x + y*y) - Rcyl - 0.55 "m";
  Real sonar_range = clearance "m";

  Real pos_err = sqrt((x - x_des)^2 + (y - y_des)^2 + (z - z_des)^2) "m";
  Real att_err = sqrt(phi*phi + theta*theta + psi*psi) "rad";

equation
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  m*der(vx) = Fwx + Fdist;
  m*der(vy) = Fwy;
  m*der(vz) = Fwz + Bnet;

  Ixx*der(wp) = Mbx + (Iyy - Izz)*wq*wr;
  Iyy*der(wq) = Mby + (Izz - Ixx)*wr*wp;
  Izz*der(wr) = Mbz + (Ixx - Iyy)*wp*wq;

  der(phi) = wp + sph*sth/cth_safe*wq + cph*sth/cth_safe*wr;
  der(theta) = cph*wq - sph*wr;
  der(psi) = sph/cth_safe*wq + cph/cth_safe*wr;

  u1_raw = u1_raw_eq;
  u2_raw = u2_raw_eq;
  u3_raw = u3_raw_eq;
  u4_raw = u4_raw_eq;
  u5_raw = u5_raw_eq;
  u6_raw = u6_raw_eq;

  u1 = if u1_raw > Fmax then Fmax else if u1_raw < -Fmax then -Fmax else u1_raw;
  u2 = if u2_raw > Fmax then Fmax else if u2_raw < -Fmax then -Fmax else u2_raw;
  u3 = if u3_raw > Fmax then Fmax else if u3_raw < -Fmax then -Fmax else u3_raw;
  u4 = if u4_raw > Fmax then Fmax else if u4_raw < -Fmax then -Fmax else u4_raw;
  u5 = if u5_raw > Fmax then Fmax else if u5_raw < -Fmax then -Fmax else u5_raw;
  u6 = if u6_raw > Fmax then Fmax else if u6_raw < -Fmax then -Fmax else u6_raw;

  assert(Fmax > 0.0, "Thruster bound must be positive");
  assert(TetherLimit >= 0.0, "Tether limit must be non-negative");
  assert(abs(u1) <= Fmax + 1e-6, "Thruster 1 bound violated");
  assert(abs(u2) <= Fmax + 1e-6, "Thruster 2 bound violated");
  assert(abs(u3) <= Fmax + 1e-6, "Thruster 3 bound violated");
  assert(abs(u4) <= Fmax + 1e-6, "Thruster 4 bound violated");
  assert(abs(u5) <= Fmax + 1e-6, "Thruster 5 bound violated");
  assert(abs(u6) <= Fmax + 1e-6, "Thruster 6 bound violated");
  assert(tether_load <= TetherLimit + 1e-6, "Tether load limit violated");
  assert(clearance > 0.0, "Structure clearance violated");
  assert(time < 6.5 or pos_err < 0.36, "Tracking error requirement violated");

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "ROVHoldB: 6-DOF station keeping beside a fixed cylinder. 115 kg box frame, slightly positively buoyant, six bidirectional body-wrench thrusters bounded at 135 N. 84 N tether/current disturbance injected during the middle third. Run at 100 Hz for 10 s."));
end ROVHoldB;