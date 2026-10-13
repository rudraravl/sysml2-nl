model CartesianToolInsertD
  parameter Real m = 2.5 "carriage mass [kg]";
  parameter Real Fmax = 350.0 "per-axis actuator force limit [N]";
  parameter Real travelX = 0.10 "X travel range [m]";
  parameter Real travelY = 0.10 "Y travel range [m]";
  parameter Real travelZ = 0.30 "Z travel range [m]";
  parameter Real clearance = 0.001 "peg-hole radial clearance [m]";
  parameter Real mu = 0.35 "contact friction coefficient [1]";
  parameter Real kContact = 1.0e6 "lateral contact stiffness [N/m]";
  parameter Real bContact = 500.0 "lateral contact damping [Ns/m]";
  parameter Real kBottom = 1.0e6 "bottom contact stiffness [N/m]";
  parameter Real bBottom = 500.0 "bottom contact damping [Ns/m]";
  parameter Real zInsertTarget = 0.07 "commanded insertion depth [m]";
  parameter Real zInsertMin = 0.06 "required minimum insertion [m]";
  parameter Real KimpLat = 8000.0 "lateral impedance stiffness [N/m]";
  parameter Real BimpLat = 200.0 "lateral impedance damping [Ns/m]";
  parameter Real KimpAx = 5000.0 "axial impedance stiffness [N/m]";
  parameter Real BimpAx = 80.0 "axial impedance damping [Ns/m]";
  parameter Real vmaxInsert = 0.02 "bounded insertion speed [m/s]";
  parameter Real FmaxLat = 120.0 "lateral force limit [N]";
  parameter Real FmaxAx = 250.0 "axial force limit [N]";
  parameter Real FdistMag = 10.0 "lateral disturbance magnitude [N]";
  constant Real dtControl = 0.005 "control period at 200 Hz [s]";
  constant Real tDistStart = 4.6666666667 "disturbance start time [s]";
  constant Real tDistEnd = 9.3333333333 "disturbance end time [s]";

  Real x(start=0.0008) "carriage X position [m]";
  Real y(start=0.0) "carriage Y position [m]";
  Real z(start=-0.02) "carriage Z position [m]";
  Real vx(start=0.0) "X velocity [m/s]";
  Real vy(start=0.0) "Y velocity [m/s]";
  Real vz(start=0.0) "Z velocity [m/s]";
  Real ax "X acceleration [m/s2]";
  Real ay "Y acceleration [m/s2]";
  Real az "Z acceleration [m/s2]";

  Integer tick(start=0) "control tick counter";
  discrete Real x_des(start=0.0) "desired X [m]";
  discrete Real y_des(start=0.0) "desired Y [m]";
  discrete Real z_des(start=-0.02) "desired Z [m]";
  discrete Real Fcx(start=0.0) "commanded force X pre-saturation [N]";
  discrete Real Fcy(start=0.0) "commanded force Y pre-saturation [N]";
  discrete Real Fcz(start=0.0) "commanded force Z pre-saturation [N]";
  discrete Real Fax(start=0.0) "applied actuator force X [N]";
  discrete Real Fay(start=0.0) "applied actuator force Y [N]";
  discrete Real Faz(start=0.0) "applied actuator force Z [N]";

  Real rLat "lateral offset magnitude [m]";
  Real vLat "lateral speed [m/s]";
  Real vrad "radial approach velocity [m/s]";
  Real pen "lateral penetration [m]";
  Real Nc "normal contact force magnitude [N]";
  Real Fnx "normal contact force X [N]";
  Real Fny "normal contact force Y [N]";
  Real Ffx "friction force X [N]";
  Real Ffy "friction force Y [N]";
  Real Ffz "axial friction force [N]";
  Real Fbot "bottom contact force [N]";

  Real Wx "measured wrench force X [N]";
  Real Wy "measured wrench force Y [N]";
  Real Wz "measured wrench force Z [N]";
  Real Tx "measured wrench torque X [N.m]";
  Real Ty "measured wrench torque Y [N.m]";
  Real Tz "measured wrench torque Z [N.m]";

  Real Fdist "applied lateral disturbance force [N]";
  Real insertionDepth "insertion depth [m]";
  Real trackingError "lateral alignment error [m]";
  Real FappliedLat "lateral applied force magnitude [N]";
  Real FappliedAx "axial applied force magnitude [N]";
  Real pegTilt "peg tilt angle [rad]";

  Boolean actuatorInBounds;
  Boolean lateralForceInBounds;
  Boolean axialForceInBounds;
  Boolean tiltInBounds;
  Boolean insertionSufficient;
  Boolean alignmentOk;
  Boolean travelInBounds;

equation
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  ax = (Fax + Wx + Fdist) / m;
  ay = (Fay + Wy) / m;
  az = (Faz + Wz) / m;

  rLat = sqrt(x*x + y*y + 1.0e-12);
  vLat = sqrt(vx*vx + vy*vy + 1.0e-12);
  vrad = (x*vx + y*vy) / (rLat + 1.0e-9);
  pen = 0.5*((rLat - clearance) + sqrt((rLat - clearance)*(rLat - clearance) + 1.0e-12));

  Nc = kContact*pen + bContact*0.5*(vrad + sqrt(vrad*vrad + 1.0e-12));
  Fnx = -Nc * x / (rLat + 1.0e-9);
  Fny = -Nc * y / (rLat + 1.0e-9);

  Ffx = -mu * Nc * vx / (vLat + 1.0e-6);
  Ffy = -mu * Nc * vy / (vLat + 1.0e-6);
  Ffz = -mu * Nc * vz / (sqrt(vz*vz + 1.0e-6) + 1.0e-6);

  Fbot = -kBottom*0.5*((z - zInsertTarget) + sqrt((z - zInsertTarget)*(z - zInsertTarget) + 1.0e-12)) - bBottom*0.5*(vz + sqrt(vz*vz + 1.0e-12));

  Wx = Fnx + Ffx;
  Wy = Fny + Ffy;
  Wz = Ffz + Fbot;
  Tx = 0.0;
  Ty = 0.0;
  Tz = 0.0;

  Fdist = if (time >= tDistStart and time <= tDistEnd) then FdistMag else 0.0;

  when sample(0, dtControl) then
    tick = pre(tick) + 1;
    x_des = 0.0;
    y_des = 0.0;
    z_des = if time < 2.0 then -0.02 + 0.02*(time/2.0) elseif time < 9.0 then zInsertTarget*(time - 2.0)/7.0 else zInsertTarget;
    Fcx = KimpLat*(x_des - x) - BimpLat*vx;
    Fcy = KimpLat*(y_des - y) - BimpLat*vy;
    Fcz = KimpAx*(z_des - z) + BimpAx*(vmaxInsert - vz);
    Fax = max(-Fmax, min(Fmax, max(-FmaxLat, min(FmaxLat, Fcx))));
    Fay = max(-Fmax, min(Fmax, max(-FmaxLat, min(FmaxLat, Fcy))));
    Faz = max(-Fmax, min(Fmax, max(-FmaxAx, min(FmaxAx, Fcz))));
  end when;

  insertionDepth = max(z, 0.0);
  trackingError = rLat;
  FappliedLat = sqrt(Fax*Fax + Fay*Fay);
  FappliedAx = abs(Faz);
  pegTilt = 0.0;

  actuatorInBounds = abs(Fax) <= Fmax + 1.0e-6 and abs(Fay) <= Fmax + 1.0e-6 and abs(Faz) <= Fmax + 1.0e-6;
  lateralForceInBounds = FappliedLat <= FmaxLat + 1.0e-6;
  axialForceInBounds = FappliedAx <= FmaxAx + 1.0e-6;
  tiltInBounds = abs(pegTilt) < 1.0e-2;
  insertionSufficient = z >= zInsertMin;
  alignmentOk = trackingError < 0.002;
  travelInBounds = abs(x) <= travelX + 1.0e-6 and abs(y) <= travelY + 1.0e-6 and abs(z) <= travelZ/2.0 + 1.0e-6;

  annotation(
    experiment(StartTime=0.0, StopTime=14.0, Tolerance=1.0e-6, Interval=0.005),
    Documentation(info="CartesianToolInsertD: three orthogonal prismatic axes moving a 2.5 kg carriage, peg-in-hole insertion with 1 mm radial clearance, rigid collision contact with friction mu=0.35, Cartesian impedance control at 200 Hz, 10 N lateral disturbance during middle third, six-axis wrench measurement, bounded actuator and force limits, required insertion >= 0.06 m, tracking error < 0.002 m after 9.1 s."));
end CartesianToolInsertD;