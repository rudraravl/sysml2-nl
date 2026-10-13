model StewartTraceA
  parameter Real Rb = 0.45 "fixed base radius [m]";
  parameter Real Rp = 0.32 "moving platform radius [m]";
  parameter Real m = 36.0 "platform mass [kg]";
  parameter Real Lmin = 0.55 "lower strut-length bound [m]";
  parameter Real Lmax = 0.85 "upper strut-length bound [m]";
  parameter Real Fmax = 3024.0 "per-strut force limit [N]";
  parameter Real Ts = 1.0/80.0 "controller period [s]";
  final parameter Real omega = 2.0*Modelica.Constants.pi/8.0 "circle angular rate [rad/s]";
  parameter Real Tramp = 1.5 "smooth trajectory ramp time [s]";
  parameter Real z0 = 0.68 "design nominal height [m]";
  final parameter Real L0 = sqrt((Rb - Rp)*(Rb - Rp) + z0*z0) "nominal strut length [m]";
  parameter Real Kp = 10000.0 "strut length proportional gain [N/m]";
  parameter Real Kd = 3000.0 "strut length derivative gain [Ns/m]";
  parameter Real obsX = 0.80 "obstacle x position [m]";
  parameter Real obsY = 0.0 "obstacle y position [m]";
  parameter Real obsR = 0.03 "obstacle radius [m]";

  Real x(start = 0.10, fixed = true);
  Real y(start = 0.0, fixed = true);
  Real z(start = 0.68, fixed = true);
  Real vx(start = 0.0, fixed = true);
  Real vy(start = 0.0, fixed = true);
  Real vz(start = 0.0, fixed = true);

  discrete Real Lcmd[6](start = fill(L0, 6));
  discrete Real fcmd[6](start = fill(0.0, 6));
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
  Real JtJ11;
  Real JtJ12;
  Real JtJ13;
  Real JtJ22;
  Real JtJ23;
  Real JtJ33;
  Real detJtJ;
  Real singularityMargin;
  Real clearance;
  Real jointMarginVec[6];
  Real jointMargin;
  Real effortMarginVec[6];
  Real effortMargin;
  Boolean satisfiesPrimaryTracking;
  Boolean finiteState;

protected
  parameter Real angle[6] = {0.0, Modelica.Constants.pi/3, 2.0*Modelica.Constants.pi/3, Modelica.Constants.pi, 4.0*Modelica.Constants.pi/3, 5.0*Modelica.Constants.pi/3};

equation
  // Trajectory generation with smooth ramp
  phi = if time < Tramp then
    omega*(0.5*time - Tramp/(4.0*Modelica.Constants.pi)*sin(2.0*Modelica.Constants.pi*time/Tramp))
  else
    omega*(time - 0.5*Tramp);
  xd = 0.10*cos(phi);
  yd = 0.10*sin(phi);
  zd = z0;

  // Direct output-pose measurement
  poseMeasured[1] = x;
  poseMeasured[2] = y;
  poseMeasured[3] = z;

  // Disturbance: 5 N during middle third [8/3, 16/3] s
  Fdist = if time >= 8.0/3.0 and time <= 16.0/3.0 then 5.0 else 0.0;

  // Inverse kinematics, actuator encoders, closure error
  for i in 1:6 loop
    Ld[i] = sqrt((xd - (Rb - Rp)*cos(angle[i]))^2 + (yd - (Rb - Rp)*sin(angle[i]))^2 + zd*zd);
    La[i] = sqrt((x - (Rb - Rp)*cos(angle[i]))^2 + (y - (Rb - Rp)*sin(angle[i]))^2 + z*z);
    u[i, 1] = (x - (Rb - Rp)*cos(angle[i])) / (if La[i] < 1.0e-6 then 1.0e-6 else La[i]);
    u[i, 2] = (y - (Rb - Rp)*sin(angle[i])) / (if La[i] < 1.0e-6 then 1.0e-6 else La[i]);
    u[i, 3] = z / (if La[i] < 1.0e-6 then 1.0e-6 else La[i]);
    encoderLength[i] = La[i];
    closureError[i] = La[i] - Lcmd[i];
    jointMarginVec[i] = min(La[i] - Lmin, Lmax - La[i]);
    effortMarginVec[i] = Fmax - abs(fcmd[i]);
  end for;

  // Resultant platform force from struts
  Fx = sum(u[i, 1]*fcmd[i] for i in 1:6);
  Fy = sum(u[i, 2]*fcmd[i] for i in 1:6);
  Fz = sum(u[i, 3]*fcmd[i] for i in 1:6);

  // Platform dynamics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (Fx + Fdist) / m;
  der(vy) = Fy / m;
  der(vz) = Fz / m;

  // Error metrics
  pathError = sqrt((x - xd)*(x - xd) + (y - yd)*(y - yd) + (z - zd)*(z - zd));
  closureErrorNorm = sqrt(sum(closureError[i]*closureError[i] for i in 1:6));

  // Joint and effort margins (explicit scalar reduction)
  jointMargin = min(jointMarginVec[1], min(jointMarginVec[2], min(jointMarginVec[3], min(jointMarginVec[4], min(jointMarginVec[5], jointMarginVec[6])))));
  effortMargin = min(effortMarginVec[1], min(effortMarginVec[2], min(effortMarginVec[3], min(effortMarginVec[4], min(effortMarginVec[5], effortMarginVec[6])))));

  // Singularity margin: sqrt(det(J'*J)) where J rows are unit strut directions
  JtJ11 = sum(u[i,1]*u[i,1] for i in 1:6);
  JtJ12 = sum(u[i,1]*u[i,2] for i in 1:6);
  JtJ13 = sum(u[i,1]*u[i,3] for i in 1:6);
  JtJ22 = sum(u[i,2]*u[i,2] for i in 1:6);
  JtJ23 = sum(u[i,2]*u[i,3] for i in 1:6);
  JtJ33 = sum(u[i,3]*u[i,3] for i in 1:6);
  detJtJ = JtJ11*(JtJ22*JtJ33 - JtJ23*JtJ23) - JtJ12*(JtJ12*JtJ33 - JtJ23*JtJ13) + JtJ13*(JtJ12*JtJ23 - JtJ22*JtJ13);
  singularityMargin = sqrt(max(detJtJ, 1.0e-12));

  // Clearance from fixed obstacle outside the trace circle
  clearance = sqrt((x - obsX)*(x - obsX) + (y - obsY)*(y - obsY)) - obsR - Rp;

  // Primary tracking requirement: path error below 0.011 m after 5.2 s
  satisfiesPrimaryTracking = if time >= 5.2 then pathError < 0.011 else true;

  // Finite state check: no NaN or infinite values
  finiteState = (x > -1.0e20) and (x < 1.0e20) and (y > -1.0e20) and (y < 1.0e20) and (z > -1.0e20) and (z < 1.0e20);

algorithm
  // Discrete inverse-kinematic trajectory controller at 80 Hz with closure stabilization
  when sample(0, Ts) then
    Lcmd[1] := sqrt((xd - (Rb - Rp)*cos(angle[1]))^2 + (yd - (Rb - Rp)*sin(angle[1]))^2 + zd*zd);
    Lcmd[2] := sqrt((xd - (Rb - Rp)*cos(angle[2]))^2 + (yd - (Rb - Rp)*sin(angle[2]))^2 + zd*zd);
    Lcmd[3] := sqrt((xd - (Rb - Rp)*cos(angle[3]))^2 + (yd - (Rb - Rp)*sin(angle[3]))^2 + zd*zd);
    Lcmd[4] := sqrt((xd - (Rb - Rp)*cos(angle[4]))^2 + (yd - (Rb - Rp)*sin(angle[4]))^2 + zd*zd);
    Lcmd[5] := sqrt((xd - (Rb - Rp)*cos(angle[5]))^2 + (yd - (Rb - Rp)*sin(angle[5]))^2 + zd*zd);
    Lcmd[6] := sqrt((xd - (Rb - Rp)*cos(angle[6]))^2 + (yd - (Rb - Rp)*sin(angle[6]))^2 + zd*zd);
    fcmd[1] := max(-Fmax, min(Fmax, Kp*(Lcmd[1] - La[1]) - Kd*(u[1,1]*vx + u[1,2]*vy + u[1,3]*vz)));
    fcmd[2] := max(-Fmax, min(Fmax, Kp*(Lcmd[2] - La[2]) - Kd*(u[2,1]*vx + u[2,2]*vy + u[2,3]*vz)));
    fcmd[3] := max(-Fmax, min(Fmax, Kp*(Lcmd[3] - La[3]) - Kd*(u[3,1]*vx + u[3,2]*vy + u[3,3]*vz)));
    fcmd[4] := max(-Fmax, min(Fmax, Kp*(Lcmd[4] - La[4]) - Kd*(u[4,1]*vx + u[4,2]*vy + u[4,3]*vz)));
    fcmd[5] := max(-Fmax, min(Fmax, Kp*(Lcmd[5] - La[5]) - Kd*(u[5,1]*vx + u[5,2]*vy + u[5,3]*vz)));
    fcmd[6] := max(-Fmax, min(Fmax, Kp*(Lcmd[6] - La[6]) - Kd*(u[6,1]*vx + u[6,2]*vy + u[6,3]*vz)));
  end when;

  annotation(experiment(StartTime = 0, StopTime = 8, Tolerance = 1e-6));
end StewartTraceA;