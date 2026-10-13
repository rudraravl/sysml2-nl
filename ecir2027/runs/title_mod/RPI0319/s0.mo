model StewartTraceA
  parameter Real Rb = 0.45 "fixed base radius [m]";
  parameter Real Rp = 0.32 "moving platform radius [m]";
  parameter Real m = 36 "platform mass [kg]";
  parameter Real Lmin = 0.55 "lower strut-length bound [m]";
  parameter Real Lmax = 0.85 "upper strut-length bound [m]";
  parameter Real Fmax = 3024 "per-strut force limit [N]";
  parameter Real Ts = 1/80 "controller period [s]";
  final parameter Real omega = 2*Modelica.Constants.pi/8 "circle angular rate [rad/s]";
  parameter Real Tramp = 1.5 "smooth trajectory ramp time [s]";
  parameter Real z0 = 0.68 "design nominal height [m]";
  final parameter Real L0 = sqrt((Rb - Rp)^2 + z0^2) "nominal strut length [m]";
  parameter Real Kp = 10000 "strut length proportional gain [N/m]";
  parameter Real Kd = 3000 "strut length derivative gain [Ns/m]";
  parameter Real obsX = 0.80 "obstacle x position [m]";
  parameter Real obsY = 0.00 "obstacle y position [m]";
  parameter Real obsR = 0.03 "obstacle radius [m]";

  Real x(start = 0.10, fixed = true);
  Real y(start = 0.00, fixed = true);
  Real z(start = z0, fixed = true);
  Real vx(start = 0.0, fixed = true);
  Real vy(start = 0.0, fixed = true);
  Real vz(start = 0.0, fixed = true);

  Real Lcmd[6](start = fill(L0, 6));
  Real fcmd[6](start = fill(0.0, 6));
  Real encoderLength[6];
  Real La[6];
  Real Ld[6];
  Real u[6, 3];
  Real poseMeasured[3];

  Real phi;
  Real xd;
  Real yd;
  Real zd;
  Real Fdist;
  Real Fx;
  Real Fy;
  Real Fz;

  Real closureError[6];
  Real closureErrorNorm;
  Real pathError;
  Real primaryTrackingError;
  Real singularityMargin;
  Real clearance;
  Real jointMarginVec[6];
  Real jointMargin;
  Real effortMarginVec[6];
  Real effortMargin;
  Boolean satisfiesPrimaryTracking;
  Boolean finiteState;

  final parameter Integer N = 641;
  Real traceTime[N];
  Real traceState[N, 6];
  Real traceCommand[N, 6];
  Real traceSensor[N, 6];
  Real tracePose[N, 3];
  Integer sampleIndex(start = 0);

protected
  parameter Real angle[6] = {0, Modelica.Constants.pi/3, 2*Modelica.Constants.pi/3, Modelica.Constants.pi, 4*Modelica.Constants.pi/3, 5*Modelica.Constants.pi/3};
  Real LaSafe;

equation
  phi = if time < Tramp then omega*(0.5*time - Tramp/(4*Modelica.Constants.pi)*sin(2*Modelica.Constants.pi*time/Tramp)) else omega*(time - 0.5*Tramp);
  xd = 0.10*cos(phi);
  yd = 0.10*sin(phi);
  zd = z0;
  poseMeasured[1] = x;
  poseMeasured[2] = y;
  poseMeasured[3] = z;

  Fdist = if time >= 8.0/3.0 and time <= 16.0/3.0 then 5.0 else 0.0;

  for i in 1:6 loop
    Ld[i] = sqrt((xd - (Rb - Rp)*cos(angle[i]))^2 + (yd - (Rb - Rp)*sin(angle[i]))^2 + zd^2);
    La[i] = sqrt((x - (Rb - Rp)*cos(angle[i]))^2 + (y - (Rb - Rp)*sin(angle[i]))^2 + z^2);
    LaSafe = if La[i] < 1.0e-6 then 1.0e-6 else La[i];
    u[i, 1] = (x - (Rb - Rp)*cos(angle[i]))/LaSafe;
    u[i, 2] = (y - (Rb - Rp)*sin(angle[i]))/LaSafe;
    u[i, 3] = z/LaSafe;
    encoderLength[i] = La[i];
    closureError[i] = La[i] - Lcmd[i];
  end for;

  Fx = sum(u[i, 1]*fcmd[i] for i in 1:6);
  Fy = sum(u[i, 2]*fcmd[i] for i in 1:6);
  Fz = sum(u[i, 3]*fcmd[i] for i in 1:6);

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (Fx + Fdist)/m;
  der(vy) = Fy/m;
  der(vz) = Fz/m;

  pathError = sqrt((x - xd)^2 + (y - yd)^2 + (z - zd)^2);
  primaryTrackingError = pathError;
  closureErrorNorm = sqrt(closureError[1]^2 + closureError[2]^2 + closureError[3]^2 + closureError[4]^2 + closureError[5]^2 + closureError[6]^2);

  for i in 1:6 loop
    jointMarginVec[i] = min(La[i] - Lmin, Lmax - La[i]);
    effortMarginVec[i] = Fmax - abs(fcmd[i]);
  end for;

  jointMargin = min(jointMarginVec[1], min(jointMarginVec[2], min(jointMarginVec[3], min(jointMarginVec[4], min(jointMarginVec[5], jointMarginVec[6])))));
  effortMargin = min(effortMarginVec[1], min(effortMarginVec[2], min(effortMarginVec[3], min(effortMarginVec[4], min(effortMarginVec[5], effortMarginVec[6])))));

  singularityMargin = sqrt(max(u[1,1]*(u[1,1]*(u[2,2]*(u[2,2]*(u[3,3]*u[3,3] - u[2,3]*u[2,3]) - u[2,3]*(u[2,3]*u[3,3] - u[2,3]*u[3,3])) - u[1,2]*(u[1,2]*(u[2,2]*u[3,3] - u[2,3]*u[2,3]) - u[2,3]*(u[2,3]*u[3,3] - u[2,3]*u[3,3]))) + u[1,3]*(u[1,3]*(u[2,2]*u[2,2] - u[2,3]*u[2,3]) - u[1,2]*(u[2,2]*u[2,3] - u[2,3]*u[2,2]))), 1.0e-12));

  clearance = sqrt((x - obsX)^2 + (y - obsY)^2) - obsR - Rp;
  finiteState = x > -1.0e20 and x < 1.0e20 and y > -1.0e20 and y < 1.0e20 and z > -1.0e20 and z < 1.0e20;

  when sample(0, Ts) then
    sampleIndex = if pre(sampleIndex) < N then pre(sampleIndex) + 1 else N;
    for i in 1:6 loop
      Lcmd[i] = sqrt((xd - (Rb - Rp)*cos(angle[i]))^2 + (yd - (Rb - Rp)*sin(angle[i]))^2 + zd^2);
      fcmd[i] = max(-Fmax, min(Fmax, Kp*(Lcmd[i] - La[i]) - Kd*(u[i,1]*vx + u[i,2]*vy + u[i,3]*vz)));
      traceTime[sampleIndex] = time;
      traceState[sampleIndex, 1] = x;
      traceState[sampleIndex, 2] = y;
      traceState[sampleIndex, 3] = z;
      traceState[sampleIndex, 4] = vx;
      traceState[sampleIndex, 5] = vy;
      traceState[sampleIndex, 6] = vz;
      traceCommand[sampleIndex, i] = fcmd[i];
      traceSensor[sampleIndex, i] = encoderLength[i];
      tracePose[sampleIndex, 1] = poseMeasured[1];
      tracePose[sampleIndex, 2] = poseMeasured[2];
      tracePose[sampleIndex, 3] = poseMeasured[3];
    end for;
  end when;

  annotation(experiment(StartTime = 0, StopTime = 8, Tolerance = 1e-6));
end StewartTraceA;