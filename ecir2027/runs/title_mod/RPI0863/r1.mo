model AUVDockE
  // ---------- Physical parameters (SI) ----------
  parameter Real m = 85.0 "kg hull mass";
  parameter Real V = 0.083 "m3 displaced volume in seawater";
  parameter Real rho_sw = 1025.0 "kg/m3 seawater density";
  parameter Real L = 1.5 "m hull length";
  parameter Real g = 9.81 "m/s2 gravitational acceleration";
  parameter Real Fmax = 121.0 "N per-thruster command bound";
  parameter Real vmax = 2.0 "m/s planar speed bound";
  parameter Real arm = 0.3 "m surge thruster yaw moment arm";
  parameter Real Iz = 30.0 "kg m2 yaw moment of inertia";
  parameter Real dragX = 60.0 "kg/s surge linear drag";
  parameter Real dragY = 200.0 "kg/s sway linear drag";
  parameter Real dragZ = 40.0 "kg/s heave linear drag";
  parameter Real yawDamp = 12.0 "Nms/rad yaw rotational damping";

  // ---------- Controller gains ----------
  parameter Real Kp_v = 600.0 "N/(m/s) surge speed gain";
  parameter Real Kp_yaw = 120.0 "Nm/rad yaw gain";
  parameter Real Kd_yaw = 20.0 "Nms/rad yaw rate gain";
  parameter Real Kp_z = 800.0 "N/m heave position gain";
  parameter Real Kd_z = 200.0 "N/(m/s) heave velocity gain";

  // ---------- Speed schedule ----------
  parameter Real vApproach = 1.0 "m/s far approach speed";
  parameter Real vSlow = 0.15 "m/s near (<1 m) approach speed";
  parameter Real slowRadius = 1.0 "m speed reduction radius";

  // ---------- Dock and compliant capture ----------
  parameter Real captureRadius = 0.08 "m compliant capture ring radius";
  parameter Real kContact = 5000.0 "N/m contact stiffness";
  parameter Real cContact = 300.0 "N/(m/s) contact damping";

  // ---------- Cross-current disturbance ----------
  parameter Real Fcurrent = 168.0 "N current force magnitude";
  parameter Real tMidStart = 16.0/3.0 "s middle third start";
  parameter Real tMidEnd = 32.0/3.0 "s middle third end";

  // ---------- Dynamic states ----------
  Real x(start=-8.0, fixed=true) "m world x (toward dock)";
  Real vx(start=0.0, fixed=true) "m/s world x velocity";
  Real y(start=0.0, fixed=true) "m world y (lateral)";
  Real vy(start=0.0, fixed=true) "m/s world y velocity";
  Real z(start=0.0, fixed=true) "m depth";
  Real vz(start=0.0, fixed=true) "m/s heave velocity";
  Real psi(start=0.0, fixed=true) "rad yaw angle";
  Real omega(start=0.0, fixed=true) "rad/s yaw rate";

  // ---------- Thruster commands (raw and saturated) ----------
  Real Tcmd1 "N raw surge-a command";
  Real Tcmd2 "N raw surge-b command";
  Real Tcmd3 "N raw heave-a command";
  Real Tcmd4 "N raw heave-b command";
  Real T1 "N surge thruster 1 (bounded)";
  Real T2 "N surge thruster 2 (bounded)";
  Real T3 "N heave thruster 1 (bounded)";
  Real T4 "N heave thruster 2 (bounded)";

  // ---------- Aggregate body forces ----------
  Real Fsurge "N body surge force";
  Real Mz "Nm yaw moment";
  Real Fheave "N body heave force";

  // ---------- Control internals ----------
  Real d "m center distance to dock";
  Real dSafe "m guarded (nonzero) distance";
  Real psiRef "rad yaw reference (line of sight to dock)";
  Real vRef "m/s scheduled speed command";
  Real surgeSpeed "m/s body-frame surge speed";
  Real FsurgeCmd "N raw surge force command";
  Real MzCmd "Nm raw yaw moment command";
  Real FheaveCmd "N raw heave force command";

  // ---------- Disturbance ----------
  Real Fcur "N applied current force (world +y)";

  // ---------- Contact / capture ----------
  Real penetration "m penetration into capture ring";
  Real approachSpeed "m/s closing speed on dock";
  Real FcontactMag "N contact force magnitude";
  Real Fcx "N contact force x component";
  Real Fcy "N contact force y component";
  Real captured "capture flag (1.0 captured, 0.0 free)";

  // ---------- Sensors ----------
  Real sonarRange "m sonar range to dock";
  Real pressureDepth "m pressure-derived depth";
  Real imuYaw "rad IMU yaw angle";
  Real opticalX "m short-range optical pose x";
  Real opticalY "m short-range optical pose y";

  // ---------- Observables ----------
  Real trackError "m primary tracking error";
  Real planarSpeed "m/s planar speed magnitude";
  Real totalSpeed "m/s total speed magnitude";

equation
  // Distance to dock at origin (guarded divisor)
  d = sqrt(x*x + y*y);
  dSafe = max(d, 1.0e-6);

  // Line-of-sight heading reference from AUV to dock
  psiRef = atan2(-y, -x);

  // Body-frame surge speed (projection of world velocity on heading)
  surgeSpeed = vx*cos(psi) + vy*sin(psi);

  // Speed-scheduled pose control: far -> approach, near -> slow, captured -> hold
  vRef = if d > slowRadius then vApproach
         else if d > captureRadius then vSlow
         else 0.0;

  // Speed-scheduled pose control law
  FsurgeCmd = Kp_v*(vRef - surgeSpeed);
  MzCmd = Kp_yaw*(psiRef - psi) - Kd_yaw*omega;
  FheaveCmd = Kp_z*(0.0 - z) + Kd_z*(0.0 - vz);

  // Allocation to four bidirectional thrusters
  Tcmd1 = 0.5*FsurgeCmd + 0.5*MzCmd/arm;
  Tcmd2 = 0.5*FsurgeCmd - 0.5*MzCmd/arm;
  Tcmd3 = 0.5*FheaveCmd;
  Tcmd4 = 0.5*FheaveCmd;

  // Per-thruster command saturation (actuator bound)
  T1 = max(-Fmax, min(Fmax, Tcmd1));
  T2 = max(-Fmax, min(Fmax, Tcmd2));
  T3 = max(-Fmax, min(Fmax, Tcmd3));
  T4 = max(-Fmax, min(Fmax, Tcmd4));

  // Aggregate body-frame forces from thrusters
  Fsurge = T1 + T2;
  Mz = (T1 - T2)*arm;
  Fheave = T3 + T4;

  // Cross-current disturbance: 168 N during middle third of 16 s run
  Fcur = if time > tMidStart and time < tMidEnd then Fcurrent else 0.0;

  // Compliant capture ring: contact when within captureRadius
  penetration = max(0.0, captureRadius - d);
  approachSpeed = -(vx*x + vy*y)/dSafe;
  FcontactMag = kContact*penetration + cContact*max(0.0, approachSpeed);
  Fcx = (x/dSafe)*FcontactMag;
  Fcy = (y/dSafe)*FcontactMag;
  captured = if d <= captureRadius then 1.0 else 0.0;

  // Rigid-body dynamics: 3-DOF planar (surge/sway/yaw) plus heave
  m*der(vx) = Fsurge*cos(psi) + Fcx - dragX*vx;
  m*der(vy) = Fsurge*sin(psi) + Fcy + Fcur - dragY*vy;
  m*der(vz) = Fheave - dragZ*vz + (rho_sw*V - m)*g;
  Iz*der(omega) = Mz - yawDamp*omega;

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(psi) = omega;

  // Sensors (ideal models; 250 Hz synchronization handled by integration step)
  sonarRange = d;
  pressureDepth = z;
  imuYaw = psi;
  opticalX = x;
  opticalY = y;

  // Observables for acceptance
  trackError = d;
  planarSpeed = sqrt(vx*vx + vy*vy);
  totalSpeed = sqrt(vx*vx + vy*vy + vz*vz);

  // ---------- Fail-closed acceptance assertions ----------
  assert(abs(T1) <= Fmax + 1.0e-6, "Thruster 1 actuator bound violated");
  assert(abs(T2) <= Fmax + 1.0e-6, "Thruster 2 actuator bound violated");
  assert(abs(T3) <= Fmax + 1.0e-6, "Thruster 3 actuator bound violated");
  assert(abs(T4) <= Fmax + 1.0e-6, "Thruster 4 actuator bound violated");
  assert(totalSpeed <= vmax + 1.0e-6, "Speed bound violated");
  assert(FcontactMag <= 500.0, "Contact force exceeds 500 N");
  assert(captured >= 0.5 or time < 10.4, "Capture not established by 10.4 s");
  assert(time < 10.4 or trackError < 0.09, "Primary tracking error above 0.09 m after 10.4 s");
  assert(abs(y) < 0.5 or time < 10.4, "Lateral alignment not satisfied");
  assert(abs(omega) < 0.2 or time < 10.4, "Yaw alignment not satisfied");

  // No NaN / infinite values in physical, control, or estimator signals
  assert(not (x <> x), "NaN in physical state x");
  assert(not (y <> y), "NaN in physical state y");
  assert(not (z <> z), "NaN in physical state z");
  assert(not (vx <> vx), "NaN in physical state vx");
  assert(not (vy <> vy), "NaN in physical state vy");
  assert(not (vz <> vz), "NaN in physical state vz");
  assert(not (psi <> psi), "NaN in physical state psi");
  assert(not (omega <> omega), "NaN in physical state omega");
  assert(not (T1 <> T1), "NaN in control T1");
  assert(not (T2 <> T2), "NaN in control T2");
  assert(not (T3 <> T3), "NaN in control T3");
  assert(not (T4 <> T4), "NaN in control T4");
  assert(not (trackError <> trackError), "NaN in estimator trackError");
  assert(not (FcontactMag <> FcontactMag), "NaN in estimator FcontactMag");

  annotation(
    experiment(StartTime=0, StopTime=16.0, Interval=0.004, Tolerance=1.0e-6),
    Documentation(info="AUVDockE: free-base marine robot docking scenario. 250 Hz (Interval=0.004 s) for 16 s. Fixed docking funnel at origin; AUV starts 8 m away. 85 kg capsule, 1.5 m, 0.083 m3 displacement, 4 bidirectional thrusters bounded at 121 N each. Speed-scheduled pose control with contact transition and 168 N cross-current middle-third disturbance."));
end AUVDockE;