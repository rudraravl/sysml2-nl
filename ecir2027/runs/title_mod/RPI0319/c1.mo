model StewartTraceA
  // Platform and geometry parameters
  parameter Real Rb = 0.45 "Fixed base radius [m]";
  parameter Real Rp = 0.32 "Moving platform radius [m]";
  parameter Real m = 36.0 "Platform mass [kg]";
  parameter Real Lmin = 0.55 "Minimum strut length [m]";
  parameter Real Lmax = 0.85 "Maximum strut length [m]";
  parameter Real Fmax = 3024.0 "Per-strut force limit [N]";
  parameter Real z0 = 0.68 "Nominal platform height [m]";
  parameter Real Ts = 1.0/80.0 "Controller sample time [s]";
  parameter Real Rcircle = 0.10 "Circle radius [m]";
  parameter Real Tsim = 8.0 "Simulation time [s]";
  parameter Real Kp = 20000.0 "Strut proportional gain [N/m]";
  parameter Real Kd = 2000.0 "Strut derivative gain [Ns/m]";
  parameter Real obsX = 0.80 "Obstacle x position [m]";
  parameter Real obsY = 0.00 "Obstacle y position [m]";
  parameter Real obsR = 0.05 "Obstacle radius [m]";

  // Base and platform anchor angles
  parameter Real angleBase[6] = {0, Modelica.Constants.pi/3, 2*Modelica.Constants.pi/3, Modelica.Constants.pi, 4*Modelica.Constants.pi/3, 5*Modelica.Constants.pi/3};
  parameter Real anglePlat[6] = {Modelica.Constants.pi/6, Modelica.Constants.pi/2, 5*Modelica.Constants.pi/6, 7*Modelica.Constants.pi/6, 3*Modelica.Constants.pi/2, 11*Modelica.Constants.pi/6};
  
  // Precomputed anchor positions
  parameter Real Bx[6] = {Rb * cos(angleBase[1]), Rb * cos(angleBase[2]), Rb * cos(angleBase[3]), Rb * cos(angleBase[4]), Rb * cos(angleBase[5]), Rb * cos(angleBase[6])};
  parameter Real By[6] = {Rb * sin(angleBase[1]), Rb * sin(angleBase[2]), Rb * sin(angleBase[3]), Rb * sin(angleBase[4]), Rb * sin(angleBase[5]), Rb * sin(angleBase[6])};
  parameter Real Px[6] = {Rp * cos(anglePlat[1]), Rp * cos(anglePlat[2]), Rp * cos(anglePlat[3]), Rp * cos(anglePlat[4]), Rp * cos(anglePlat[5]), Rp * cos(anglePlat[6])};
  parameter Real Py[6] = {Rp * sin(anglePlat[1]), Rp * sin(anglePlat[2]), Rp * sin(anglePlat[3]), Rp * sin(anglePlat[4]), Rp * sin(anglePlat[5]), Rp * sin(anglePlat[6])};

  // States
  Real x(start = Rcircle, fixed = true);
  Real y(start = 0.0, fixed = true);
  Real z(start = z0, fixed = true);
  Real vx(start = 0.0, fixed = true);
  Real vy(start = 0.0, fixed = true);
  Real vz(start = 0.0, fixed = true);

  // Discrete controller variables
  discrete Real Lcmd[6](start = fill(sqrt((Rb - Rp)^2 + z0^2), 6));
  discrete Real fcmd[6](start = fill(0.0, 6));

  // Continuous kinematics and dynamics variables
  Real La[6];
  Real LaSafe[6];
  Real ux[6];
  Real uy[6];
  Real uz[6];
  Real dLa[6];
  
  Real Fx_total;
  Real Fy_total;
  Real Fz_total;
  Real Fdist_x;

  // Error and margin metrics
  Real pathError;
  Real closureError[6];
  Real closureErrorNorm;
  Real singularityMargin;
  Real clearance;
  Real jointMarginVec[6];
  Real effortMarginVec[6];
  Real jointMargin;
  Real effortMargin;
  Real M11, M22, M33;
  
  // Reference trajectory
  Real xd, yd, zd;

equation
  // Reference trajectory: circle in XY plane at z0
  xd = Rcircle * cos(2*Modelica.Constants.pi * time / Tsim);
  yd = Rcircle * sin(2*Modelica.Constants.pi * time / Tsim);
  zd = z0;

  // Disturbance force in X during middle third (8/3 to 16/3)
  Fdist_x = if time >= Tsim/3.0 and time <= 2.0*Tsim/3.0 then 5.0 else 0.0;

  // Kinematics
  for i in 1:6 loop
    La[i] = sqrt((x + Px[i] - Bx[i])^2 + (y + Py[i] - By[i])^2 + z^2);
    LaSafe[i] = if La[i] < 1.0e-6 then 1.0e-6 else La[i];
    ux[i] = (x + Px[i] - Bx[i]) / LaSafe[i];
    uy[i] = (y + Py[i] - By[i]) / LaSafe[i];
    uz[i] = (z) / LaSafe[i];
    dLa[i] = ux[i]*vx + uy[i]*vy + uz[i]*vz;
    closureError[i] = La[i] - Lcmd[i];
    jointMarginVec[i] = min(La[i] - Lmin, Lmax - La[i]);
    effortMarginVec[i] = Fmax - abs(fcmd[i]);
  end for;

  // Dynamics
  Fx_total = ux[1]*fcmd[1] + ux[2]*fcmd[2] + ux[3]*fcmd[3] + ux[4]*fcmd[4] + ux[5]*fcmd[5] + ux[6]*fcmd[6] + Fdist_x;
  Fy_total = uy[1]*fcmd[1] + uy[2]*fcmd[2] + uy[3]*fcmd[3] + uy[4]*fcmd[4] + uy[5]*fcmd[5] + uy[6]*fcmd[6];
  Fz_total = uz[1]*fcmd[1] + uz[2]*fcmd[2] + uz[3]*fcmd[3] + uz[4]*fcmd[4] + uz[5]*fcmd[5] + uz[6]*fcmd[6];

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = Fx_total / m;
  der(vy) = Fy_total / m;
  der(vz) = Fz_total / m;

  // Metrics
  pathError = sqrt((x - xd)^2 + (y - yd)^2 + (z - zd)^2);
  closureErrorNorm = sqrt(closureError[1]^2 + closureError[2]^2 + closureError[3]^2 + closureError[4]^2 + closureError[5]^2 + closureError[6]^2);
  
  // Singularity margin (sqrt of det of diagonal of JJ^T approximation)
  M11 = ux[1]*ux[1] + ux[2]*ux[2] + ux[3]*ux[3] + ux[4]*ux[4] + ux[5]*ux[5] + ux[6]*ux[6];
  M22 = uy[1]*uy[1] + uy[2]*uy[2] + uy[3]*uy[3] + uy[4]*uy[4] + uy[5]*uy[5] + uy[6]*uy[6];
  M33 = uz[1]*uz[1] + uz[2]*uz[2] + uz[3]*uz[3] + uz[4]*uz[4] + uz[5]*uz[5] + uz[6]*uz[6];
  singularityMargin = sqrt(M11 * M22 * M33);
  
  // Clearance from obstacle (distance from platform edge to obstacle)
  clearance = sqrt((x - obsX)^2 + (y - obsY)^2) - obsR - Rp;
  
  // Joint and effort margins
  jointMargin = min(jointMarginVec[1], min(jointMarginVec[2], min(jointMarginVec[3], min(jointMarginVec[4], min(jointMarginVec[5], jointMarginVec[6])))));
  effortMargin = min(effortMarginVec[1], min(effortMarginVec[2], min(effortMarginVec[3], min(effortMarginVec[4], min(effortMarginVec[5], effortMarginVec[6])))));

  // Discrete controller at 80 Hz
  when sample(0, Ts) then
    Lcmd[1] = sqrt((xd + Px[1] - Bx[1])^2 + (yd + Py[1] - By[1])^2 + zd^2);
    Lcmd[2] = sqrt((xd + Px[2] - Bx[2])^2 + (yd + Py[2] - By[2])^2 + zd^2);
    Lcmd[3] = sqrt((xd + Px[3] - Bx[3])^2 + (yd + Py[3] - By[3])^2 + zd^2);
    Lcmd[4] = sqrt((xd + Px[4] - Bx[4])^2 + (yd + Py[4] - By[4])^2 + zd^2);
    Lcmd[5] = sqrt((xd + Px[5] - Bx[5])^2 + (yd + Py[5] - By[5])^2 + zd^2);
    Lcmd[6] = sqrt((xd + Px[6] - Bx[6])^2 + (yd + Py[6] - By[6])^2 + zd^2);
    
    fcmd[1] = max(-Fmax, min(Fmax, Kp*(Lcmd[1] - La[1]) - Kd*dLa[1]));
    fcmd[2] = max(-Fmax, min(Fmax, Kp*(Lcmd[2] - La[2]) - Kd*dLa[2]));
    fcmd[3] = max(-Fmax, min(Fmax, Kp*(Lcmd[3] - La[3]) - Kd*dLa[3]));
    fcmd[4] = max(-Fmax, min(Fmax, Kp*(Lcmd[4] - La[4]) - Kd*dLa[4]));
    fcmd[5] = max(-Fmax, min(Fmax, Kp*(Lcmd[5] - La[5]) - Kd*dLa[5]));
    fcmd[6] = max(-Fmax, min(Fmax, Kp*(Lcmd[6] - La[6]) - Kd*dLa[6]));
  end when;

  annotation(experiment(StartTime = 0, StopTime = 8, Tolerance = 1e-6));
end StewartTraceA;