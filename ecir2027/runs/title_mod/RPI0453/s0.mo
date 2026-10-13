model ContactArmPolishC
  "Contact-rich manipulation: tangential trajectory control with normal-force regulation
   on a 6R arm (Z-Y-Y-X-Y-X axes) with capsule links, wrist sensor, rigid tool,
   and a fixed curved workpiece. Runs at 125 Hz for 12 s."

  // ===== Requirement-specified parameters =====
  parameter Real pathLength = 0.50 "Surface path length [m]";
  parameter Real tauMax = 110.0    "Maximum joint effort command magnitude [N.m]";
  parameter Real Fdist  = 6.3     "Surface-force disturbance magnitude [N]";
  parameter Real mu     = 0.50    "Friction coefficient [1]";
  parameter Real Fmin   = 12.0   "Minimum normal force bound [N]";
  parameter Real Fmax   = 30.0   "Maximum normal force bound [N]";
  parameter Real Fset   = 21.0   "Normal force setpoint (midpoint of [12,30]) [N]";
  parameter Real trackThresh = 0.021 "Tracking error threshold after 7.8 s [m]";
  parameter Real tConv  = 7.8    "Convergence time threshold [s]";
  parameter Real Ts     = 1.0/125.0 "Control/simulation sample period [s]";
  parameter Real Tend   = 12.0   "Simulation duration [s]";

  // ===== Design parameters (not specified in requirement; chosen for model functionality) =====
  // Arm geometry: planar projection of Z-Y-Y-X-Y-X 6R with capsule links
  parameter Real baseX = 0.0  "Base x position [m]";
  parameter Real baseY = 1.5  "Base y position [m]";
  parameter Real L[7] = {0.45, 0.35, 0.25, 0.06, 0.04, 0.03, 0.04}
    "Link lengths incl. replaceable rigid tool [m]";
  parameter Real Jl[6] = {0.10, 0.06, 0.03, 0.005, 0.002, 0.001}
    "Joint inertias [kg.m2]";
  parameter Real Bl[6] = {0.05, 0.04, 0.02, 0.005, 0.002, 0.001}
    "Joint damping [N.m.s/rad]";
  // Contact: compliant normal contact
  parameter Real kc    = 2000.0 "Contact stiffness [N/m]";
  parameter Real dc    = 30.0   "Contact damping [N.s/m]";
  parameter Real Rsurf = 2.0    "Surface radius of curvature [m]";
  parameter Real x0    = 0.327  "Path start x-coordinate [m]";
  parameter Real y0    = 0.3935 "Surface y-coordinate at path start [m]";
  // Controller gains
  parameter Real Kp_track = 200.0 "Tangential P gain [N/m]";
  parameter Real Kd_track = 20.0  "Tangential D gain [N.s/m]";
  parameter Real Kp_force = 0.5   "Force P gain [N/N]";
  parameter Real Ki_force = 2.0   "Force I gain [N/(N.s)]";
  parameter Real vEps    = 0.01   "Friction regularization velocity [m/s]";
  parameter Real qMax    = 3.14159265358979 "Joint angle bound [rad]";
  parameter Real q_init[6] = {-0.9, -0.5, -0.2, 0.0, 0.0, 0.0}
    "Initial joint angles [rad]";

  // ===== Joint states (encoder readings) =====
  Real q[6]  "Joint angles [rad]";
  Real qd[6] "Joint angular velocities [rad/s]";

  // ===== Effort =====
  Real tauCmd[6] "Joint effort commands [N.m]";
  Real tauSat[6] "Saturated joint efforts [N.m]";

  // ===== Forward kinematics =====
  Real cumQ[7]   "Cumulative joint angles [rad]";
  Real tipX      "Tool-tip x position [m]";
  Real tipY      "Tool-tip y position [m]";
  Real tipOrient "Tool-tip orientation [rad]";
  Real tipXdot   "Tool-tip x velocity [m/s]";
  Real tipYdot   "Tool-tip y velocity [m/s]";

  // ===== Jacobian (2x6, planar projection) =====
  Real Jmat[2,6] "Jacobian matrix [m/rad]";

  // ===== Surface =====
  Real surfY      "Surface height at tip x [m]";
  Real surfSlope  "Surface slope dy/dx [1]";
  Real surfNorm   "Surface normal magnitude [1]";
  Real surfTanX   "Surface tangent x-component [1]";
  Real surfTanY   "Surface tangent y-component [1]";
  Real surfNorX   "Surface normal x-component [1]";
  Real surfNorY   "Surface normal y-component [1]";

  // ===== Path =====
  Real sPath    "Path position (approx. arc length) [m]";
  Real sPathDot "Path velocity [m/s]";
  Real sDes     "Desired path position [m]";
  Real vDes     "Desired path velocity [m/s]";
  Real u        "Normalized time [1]";

  // ===== Contact =====
  Real penetration    "Penetration into surface (positive = in contact) [m]";
  Real penetrationDot "Penetration rate [m/s]";
  Real Fn             "Normal contact force [N]";
  Real Ft             "Tangential friction force [N]";
  Real vTan           "Tangential velocity [m/s]";
  Real Fd             "Disturbance force magnitude [N]";
  Boolean disturbanceActive "Disturbance active flag";
  Boolean inContact   "Contact flag";

  // ===== Forces =====
  Real FextX    "External force x (contact + disturbance) [N]";
  Real FextY    "External force y (contact + disturbance) [N]";
  Real Fcx      "Control force x [N]";
  Real Fcy      "Control force y [N]";
  Real FtanCtrl "Tangential control force [N]";
  Real FnorCtrl "Normal control force [N]";

  // ===== Controller =====
  Real pathError  "Path error [m]";
  Real trackError "Primary tracking error [m]";
  Real forceError "Normal force error [N]";
  Real forceInt   "Force error integral [N.s]";

  // ===== Sensors =====
  // Six-axis wrist wrench (measured at wrist, approximated at tip)
  Real wrenchFx "Wrist sensor force x [N]";
  Real wrenchFy "Wrist sensor force y [N]";
  Real wrenchFz "Wrist sensor force z [N]";
  Real wrenchTx "Wrist sensor torque x [N.m]";
  Real wrenchTy "Wrist sensor torque y [N.m]";
  Real wrenchTz "Wrist sensor torque z [N.m]";
  // Tool-tip pose
  Real tipPoseX     "Tool-tip pose x [m]";
  Real tipPoseY     "Tool-tip pose y [m]";
  Real tipPoseTheta "Tool-tip pose orientation [rad]";

  // ===== Monitors =====
  Boolean jointBoundsOK    "Joint bounds satisfied";
  Boolean effortBoundsOK   "Effort bounds satisfied";
  Boolean forceBoundsOK     "Force within [12, 30] N";
  Boolean trackErrorOK     "Tracking error below threshold after 7.8 s";
  Boolean continuousContact "Continuous contact maintained";
  Boolean noNaNInf         "No NaN or infinite values";

initial equation
  q = q_init;
  qd = zeros(6);
  forceInt = 0.0;

equation
  // ===== Forward kinematics (planar projection of Z-Y-Y-X-Y-X 6R) =====
  cumQ[1] = q[1];
  cumQ[2] = cumQ[1] + q[2];
  cumQ[3] = cumQ[2] + q[3];
  cumQ[4] = cumQ[3] + q[4];
  cumQ[5] = cumQ[4] + q[5];
  cumQ[6] = cumQ[5] + q[6];
  cumQ[7] = cumQ[6];

  tipX = baseX
        + L[1]*cos(cumQ[1]) + L[2]*cos(cumQ[2]) + L[3]*cos(cumQ[3])
        + L[4]*cos(cumQ[4]) + L[5]*cos(cumQ[5]) + L[6]*cos(cumQ[6])
        + L[7]*cos(cumQ[7]);
  tipY = baseY
        + L[1]*sin(cumQ[1]) + L[2]*sin(cumQ[2]) + L[3]*sin(cumQ[3])
        + L[4]*sin(cumQ[4]) + L[5]*sin(cumQ[5]) + L[6]*sin(cumQ[6])
        + L[7]*sin(cumQ[7]);
  tipOrient = cumQ[7];

  // ===== Jacobian (2x6) =====
  Jmat[1,1] = -(L[1]*sin(cumQ[1]) + L[2]*sin(cumQ[2]) + L[3]*sin(cumQ[3])
              + L[4]*sin(cumQ[4]) + L[5]*sin(cumQ[5]) + L[6]*sin(cumQ[6]) + L[7]*sin(cumQ[7]));
  Jmat[1,2] = -(L[2]*sin(cumQ[2]) + L[3]*sin(cumQ[3]) + L[4]*sin(cumQ[4])
              + L[5]*sin(cumQ[5]) + L[6]*sin(cumQ[6]) + L[7]*sin(cumQ[7]));
  Jmat[1,3] = -(L[3]*sin(cumQ[3]) + L[4]*sin(cumQ[4]) + L[5]*sin(cumQ[5])
              + L[6]*sin(cumQ[6]) + L[7]*sin(cumQ[7]));
  Jmat[1,4] = -(L[4]*sin(cumQ[4]) + L[5]*sin(cumQ[5]) + L[6]*sin(cumQ[6]) + L[7]*sin(cumQ[7]));
  Jmat[1,5] = -(L[5]*sin(cumQ[5]) + L[6]*sin(cumQ[6]) + L[7]*sin(cumQ[7]));
  Jmat[1,6] = -(L[6]*sin(cumQ[6]) + L[7]*sin(cumQ[7]));

  Jmat[2,1] = L[1]*cos(cumQ[1]) + L[2]*cos(cumQ[2]) + L[3]*cos(cumQ[3])
            + L[4]*cos(cumQ[4]) + L[5]*cos(cumQ[5]) + L[6]*cos(cumQ[6]) + L[7]*cos(cumQ[7]);
  Jmat[2,2] = L[2]*cos(cumQ[2]) + L[3]*cos(cumQ[3]) + L[4]*cos(cumQ[4])
            + L[5]*cos(cumQ[5]) + L[6]*cos(cumQ[6]) + L[7]*cos(cumQ[7]);
  Jmat[2,3] = L[3]*cos(cumQ[3]) + L[4]*cos(cumQ[4]) + L[5]*cos(cumQ[5])
            + L[6]*cos(cumQ[6]) + L[7]*cos(cumQ[7]);
  Jmat[2,4] = L[4]*cos(cumQ[4]) + L[5]*cos(cumQ[5]) + L[6]*cos(cumQ[6]) + L[7]*cos(cumQ[7]);
  Jmat[2,5] = L[5]*cos(cumQ[5]) + L[6]*cos(cumQ[6]) + L[7]*cos(cumQ[7]);
  Jmat[2,6] = L[6]*cos(cumQ[6]) + L[7]*cos(cumQ[7]);

  // Tip velocities via Jacobian
  tipXdot = Jmat[1,1]*qd[1] + Jmat[1,2]*qd[2] + Jmat[1,3]*qd[3]
          + Jmat[1,4]*qd[4] + Jmat[1,5]*qd[5] + Jmat[1,6]*qd[6];
  tipYdot = Jmat[2,1]*qd[1] + Jmat[2,2]*qd[2] + Jmat[2,3]*qd[3]
          + Jmat[2,4]*qd[4] + Jmat[2,5]*qd[5] + Jmat[2,6]*qd[6];

  // ===== Surface model (parabolic approximation of curved workpiece) =====
  surfY      = y0 + (tipX - x0)^2 / (2.0 * Rsurf);
  surfSlope  = (tipX - x0) / Rsurf;
  surfNorm   = sqrt(1.0 + surfSlope^2 + 1.0e-12);
  surfTanX   = 1.0 / surfNorm;
  surfTanY   = surfSlope / surfNorm;
  surfNorX   = -surfSlope / surfNorm;
  surfNorY   = 1.0 / surfNorm;

  // ===== Path trajectory (smoothstep from 0 to pathLength over Tend) =====
  sPath    = tipX - x0;
  sPathDot = tipXdot;
  u        = max(0.0, min(1.0, time / Tend));
  sDes     = pathLength * (3.0*u^2 - 2.0*u^3);
  vDes     = pathLength * (6.0*u - 6.0*u^2) / Tend;

  // ===== Contact model (compliant normal + Coulomb friction) =====
  penetration    = surfY - tipY;
  penetrationDot = surfSlope * tipXdot - tipYdot;
  inContact      = penetration > 0.0;
  Fn             = max(0.0, kc * penetration + dc * penetrationDot);

  // Tangential velocity and regularized friction
  vTan = tipXdot * surfTanX + tipYdot * surfTanY;
  Ft   = -mu * Fn * vTan / sqrt(vTan^2 + vEps^2);

  // Disturbance: controlled 6.3 N surface-force during middle third (4 s to 8 s)
  disturbanceActive = (time >= 4.0) and (time <= 8.0);
  Fd = if disturbanceActive then Fdist else 0.0;

  // External forces on tip in (x, y)
  FextX = Fn * surfNorX + (Ft - Fd) * surfTanX;
  FextY = Fn * surfNorY + (Ft - Fd) * surfTanY;

  // ===== Controller: tangential trajectory PD + normal force PI =====
  pathError  = abs(sDes - sPath);
  trackError = pathError;
  forceError = Fset - Fn;
  der(forceInt) = forceError;

  FtanCtrl = Kp_track * (sDes - sPath) + Kd_track * (vDes - sPathDot);
  FnorCtrl = -(Kp_force * forceError + Ki_force * forceInt);

  // Map to Cartesian control forces via surface frame
  Fcx = FtanCtrl * surfTanX + FnorCtrl * surfNorX;
  Fcy = FtanCtrl * surfTanY + FnorCtrl * surfNorY;

  // Joint torques via Jacobian transpose
  tauCmd[1] = Jmat[1,1]*Fcx + Jmat[2,1]*Fcy;
  tauCmd[2] = Jmat[1,2]*Fcx + Jmat[2,2]*Fcy;
  tauCmd[3] = Jmat[1,3]*Fcx + Jmat[2,3]*Fcy;
  tauCmd[4] = Jmat[1,4]*Fcx + Jmat[2,4]*Fcy;
  tauCmd[5] = Jmat[1,5]*Fcx + Jmat[2,5]*Fcy;
  tauCmd[6] = Jmat[1,6]*Fcx + Jmat[2,6]*Fcy;

  // Saturated actuators (max command magnitude 110 N.m)
  tauSat[1] = max(-tauMax, min(tauMax, tauCmd[1]));
  tauSat[2] = max(-tauMax, min(tauMax, tauCmd[2]));
  tauSat[3] = max(-tauMax, min(tauMax, tauCmd[3]));
  tauSat[4] = max(-tauMax, min(tauMax, tauCmd[4]));
  tauSat[5] = max(-tauMax, min(tauMax, tauCmd[5]));
  tauSat[6] = max(-tauMax, min(tauMax, tauCmd[6]));

  // ===== Joint dynamics =====
  der(q[1]) = qd[1];
  der(q[2]) = qd[2];
  der(q[3]) = qd[3];
  der(q[4]) = qd[4];
  der(q[5]) = qd[5];
  der(q[6]) = qd[6];

  Jl[1]*der(qd[1]) + Bl[1]*qd[1] = tauSat[1] + Jmat[1,1]*FextX + Jmat[2,1]*FextY;
  Jl[2]*der(qd[2]) + Bl[2]*qd[2] = tauSat[2] + Jmat[1,2]*FextX + Jmat[2,2]*FextY;
  Jl[3]*der(qd[3]) + Bl[3]*qd[3] = tauSat[3] + Jmat[1,3]*FextX + Jmat[2,3]*FextY;
  Jl[4]*der(qd[4]) + Bl[4]*qd[4] = tauSat[4] + Jmat[1,4]*FextX + Jmat[2,4]*FextY;
  Jl[5]*der(qd[5]) + Bl[5]*qd[5] = tauSat[5] + Jmat[1,5]*FextX + Jmat[2,5]*FextY;
  Jl[6]*der(qd[6]) + Bl[6]*qd[6] = tauSat[6] + Jmat[1,6]*FextX + Jmat[2,6]*FextY;

  // ===== Sensors =====
  // Six-axis wrist wrench
  wrenchFx = FextX;
  wrenchFy = FextY;
  wrenchFz = 0.0;
  wrenchTx = 0.0;
  wrenchTy = 0.0;
  wrenchTz = 0.0;
  // Tool-tip pose
  tipPoseX     = tipX;
  tipPoseY     = tipY;
  tipPoseTheta = tipOrient;

  // ===== Requirement monitors =====
  jointBoundsOK = (abs(q[1]) <= qMax) and (abs(q[2]) <= qMax) and (abs(q[3]) <= qMax)
               and (abs(q[4]) <= qMax) and (abs(q[5]) <= qMax) and (abs(q[6]) <= qMax);

  effortBoundsOK = (abs(tauSat[1]) <= tauMax + 1.0e-6) and (abs(tauSat[2]) <= tauMax + 1.0e-6)
                and (abs(tauSat[3]) <= tauMax + 1.0e-6) and (abs(tauSat[4]) <= tauMax + 1.0e-6)
                and (abs(tauSat[5]) <= tauMax + 1.0e-6) and (abs(tauSat[6]) <= tauMax + 1.0e-6);

  forceBoundsOK = (Fn >= Fmin) and (Fn <= Fmax);

  trackErrorOK = if time > tConv then (trackError < trackThresh) else true;

  continuousContact = inContact;

  noNaNInf = (abs(tipX) < 1.0e6) and (abs(tipY) < 1.0e6) and (abs(Fn) < 1.0e6)
          and (abs(q[1]) < 1.0e6) and (abs(q[2]) < 1.0e6) and (abs(q[3]) < 1.0e6)
          and (abs(q[4]) < 1.0e6) and (abs(q[5]) < 1.0e6) and (abs(q[6]) < 1.0e6)
          and (abs(tauSat[1]) < 1.0e6) and (abs(tauSat[2]) < 1.0e6) and (abs(tauSat[3]) < 1.0e6)
          and (abs(tauSat[4]) < 1.0e6) and (abs(tauSat[5]) < 1.0e6) and (abs(tauSat[6]) < 1.0e6)
          and (abs(forceInt) < 1.0e6) and (abs(Ft) < 1.0e6);

end ContactArmPolishC;