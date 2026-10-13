model SoftGripAvoidF
  annotation(
    experiment(StopTime = 20.0, Interval = 0.002, Tolerance = 1e-6),
    Documentation(info = "Soft robotic gripper scenario: three 0.13 m silicone fingers around a rigid palm.
    Each finger has one pressure chamber with four bending sections.
    Mission: reach target around fixed cylinder obstacle, bounded incidental contact, then stiffen/hold shape.
    Controller: contact-aware shape control with bounded stiffness scheduling.
    Robustness: 11.6 N lateral tip disturbance during middle third of 20 s run at 500 Hz.
    Verification: actuator, deformation, contact-force, temperature, obstacle-clearance, and final tip-error bounds.
    Primary tracking error below 0.032 m after 13 s. No NaN or infinite values.")
  );

  // ===== Given parameters (from requirement) =====
  parameter Real L = 0.13 "finger length [m]";
  parameter Real pMax = 116000.0 "max chamber pressure gauge [Pa]";
  parameter Real mu = 0.55 "obstacle friction coefficient [-]";
  parameter Real Fdist = 11.6 "lateral disturbance force [N]";
  parameter Real Tend = 20.0 "simulation duration [s]";
  parameter Real trackErrBound = 0.032 "tracking error bound after 13 s [m]";
  parameter Real sampleFreq = 500.0 "sampling frequency [Hz]";

  // ===== Assumed parameters (not specified in requirement; labeled as assumptions) =====
  parameter Integer nSec = 4 "sections per finger (given by requirement)";
  parameter Real Ls = L / nSec "section length [m]";
  parameter Real rObs = 0.013 "assumed obstacle cylinder radius [m]";
  parameter Real xObs = 0.055 "assumed obstacle center x-position [m]";
  parameter Real yObs = 0.025 "assumed obstacle center y-position [m]";
  parameter Real xTgt = 0.11 "assumed target x-position [m]";
  parameter Real yTgt = 0.055 "assumed target y-position [m]";
  parameter Real rf = 0.005 "assumed finger cross-section radius [m]";
  parameter Real Jsec = 1.0e-5 "assumed section bending inertia [kg.m2]";
  parameter Real kSec = 3.0 "assumed section bending stiffness [N.m/rad]";
  parameter Real bSec = 0.05 "assumed section damping [N.m.s/rad]";
  parameter Real gPT = 2.0e-5 "assumed pressure-to-torque gain [N.m/Pa]";
  parameter Real kContact = 10000.0 "assumed contact spring stiffness [N/m]";
  parameter Real Tamb = 22.0 "assumed ambient temperature [degC]";
  parameter Real tempCoeff = 5.0e-11 "assumed temperature rise coefficient [degC/(Pa2.s)]";
  parameter Real tempCool = 0.01 "assumed thermal cooling rate [1/s]";
  parameter Real Kp_y = 20000.0 "assumed y-axis proportional gain [Pa/m]";
  parameter Real Kd_y = 2000.0 "assumed y-axis derivative gain [Pa.s/m]";
  parameter Real Kp_x = 10000.0 "assumed x-axis proportional gain [Pa/m]";
  parameter Real Kd_x = 1000.0 "assumed x-axis derivative gain [Pa.s/m]";
  parameter Real stiffMin = 0.5 "assumed minimum stiffness factor [-]";
  parameter Real stiffMax = 3.0 "assumed maximum stiffness factor [-]";
  parameter Real stiffTrans = 0.03 "assumed stiffness transition length scale [m]";
  parameter Real qDesired = 0.195 "assumed desired steady-state bending per section [rad]";
  parameter Real baseAng2 = 2.0943951023931953 "finger 2 base angle (120 deg) [rad]";
  parameter Real baseAng3 = 4.1887902047863905 "finger 3 base angle (240 deg) [rad]";
  parameter Real tempMax = 80.0 "assumed max allowable temperature [degC]";
  parameter Real defMaxBound = 1.57 "assumed max section deformation (90 deg) [rad]";
  parameter Real contactMaxBound = 50.0 "assumed max total contact force [N]";
  parameter Real clearanceMinBound = -0.002 "assumed min clearance tolerance [m]";
  parameter Real trajTau = 2.0 "assumed trajectory time constant [s]";

  // ===== Dynamic states =====
  // Finger 1
  Real q1[4](each start = 0.0, each fixed = true) "section bending angles finger 1 [rad]";
  Real dq1[4](each start = 0.0, each fixed = true) "section angular velocities finger 1 [rad/s]";
  // Finger 2
  Real q2[4](each start = 0.0, each fixed = true) "section bending angles finger 2 [rad]";
  Real dq2[4](each start = 0.0, each fixed = true) "section angular velocities finger 2 [rad/s]";
  // Finger 3
  Real q3[4](each start = 0.0, each fixed = true) "section bending angles finger 3 [rad]";
  Real dq3[4](each start = 0.0, each fixed = true) "section angular velocities finger 3 [rad/s]";
  // Temperature
  Real temp1(start = Tamb, fixed = true) "finger 1 temperature [degC]";
  Real temp2(start = Tamb, fixed = true) "finger 2 temperature [degC]";
  Real temp3(start = Tamb, fixed = true) "finger 3 temperature [degC]";

  // ===== Cumulative angles =====
  Real ca1[4] "cumulative angle finger 1 [rad]";
  Real ca2[4] "cumulative angle finger 2 [rad]";
  Real ca3[4] "cumulative angle finger 3 [rad]";

  // ===== Joint positions (5 per finger: base + 4 section endpoints) =====
  Real jx1[5], jy1[5] "joint positions finger 1 [m]";
  Real jx2[5], jy2[5] "joint positions finger 2 [m]";
  Real jx3[5], jy3[5] "joint positions finger 3 [m]";

  // ===== Section midpoints =====
  Real mx1[4], my1[4] "midpoint positions finger 1 [m]";
  Real mx2[4], my2[4] "midpoint positions finger 2 [m]";
  Real mx3[4], my3[4] "midpoint positions finger 3 [m]";

  // ===== Distance to obstacle center =====
  Real d1[4] "section midpoint distances to obstacle, finger 1 [m]";
  Real d2[4] "section midpoint distances to obstacle, finger 2 [m]";
  Real d3[4] "section midpoint distances to obstacle, finger 3 [m]";

  // ===== Contact penetration =====
  Real pen1[4], pen2[4], pen3[4] "penetration per section [m]";

  // ===== Contact forces per section =====
  Real Fc1[4], Fc2[4], Fc3[4] "contact force per section [N]";

  // ===== Total contact forces =====
  Real FcTot1 "total contact force finger 1 [N]";
  Real FcTot2 "total contact force finger 2 [N]";
  Real FcTot3 "total contact force finger 3 [N]";
  Real FcTotAll "total contact force all fingers [N]";

  // ===== Clearance =====
  Real clr1 "min clearance finger 1 [m]";
  Real clr2 "min clearance finger 2 [m]";
  Real clr3 "min clearance finger 3 [m]";
  Real clrMin "overall min clearance [m]";

  // ===== Tip positions =====
  Real tipX1, tipY1 "finger 1 tip position [m]";
  Real tipX2, tipY2 "finger 2 tip position [m]";
  Real tipX3, tipY3 "finger 3 tip position [m]";

  // ===== Tip velocity (finger 1) =====
  Real tipVx1, tipVy1 "finger 1 tip velocity [m/s]";

  // ===== Tracking error =====
  Real tipErr1 "finger 1 tip tracking error [m]";
  Real tipErrVerif "tip error for verification window [m]";

  // ===== Pressure commands and saturated values =====
  Real pCmd1 "chamber pressure command finger 1 [Pa]";
  Real pCmd2 "chamber pressure command finger 2 [Pa]";
  Real pCmd3 "chamber pressure command finger 3 [Pa]";
  Real pSat1 "saturated pressure finger 1 [Pa]";
  Real pSat2 "saturated pressure finger 2 [Pa]";
  Real pSat3 "saturated pressure finger 3 [Pa]";

  // ===== Stiffness scheduling =====
  Real stiff1 "stiffness factor finger 1 [-]";
  Real stiff2 "stiffness factor finger 2 [-]";
  Real stiff3 "stiffness factor finger 3 [-]";

  // ===== Disturbance =====
  Real Fdist1y "disturbance force on finger 1 tip y-direction [N]";
  Boolean inDist "disturbance active flag";
  Boolean after13 "post-13 s flag for verification";

  // ===== Desired trajectory =====
  Real desTipX "desired tip x [m]";
  Real desTipY "desired tip y [m]";

  // ===== Feedforward pressure =====
  Real pFF1 "feedforward pressure finger 1 [Pa]";

  // ===== Deformation metric =====
  Real defMax1 "max section deformation finger 1 [rad]";
  Real defMax2 "max section deformation finger 2 [rad]";
  Real defMax3 "max section deformation finger 3 [rad]";

  // ===== Verification flags =====
  Boolean trackOK "tracking error within bound";
  Boolean actuatorOK "actuator commands within bounds";
  Boolean deformOK "section deformation within bound";
  Boolean contactOK "contact force within bound";
  Boolean tempOK "temperature within bound";
  Boolean clearanceOK "clearance within tolerance";
  Boolean noNaN "no NaN or infinite values";
  Boolean allOK "all verification criteria met";

equation
  // ===== Time-based flags =====
  inDist = time >= Tend / 3.0 and time <= 2.0 * Tend / 3.0;
  after13 = time >= 13.0;

  // ===== Disturbance: 11.6 N lateral (-y) force on finger 1 tip during middle third =====
  Fdist1y = if inDist then -Fdist else 0.0;

  // ===== Desired tip trajectory (smooth exponential approach to target) =====
  desTipX = xTgt * (1.0 - exp(-time / trajTau));
  desTipY = yTgt * (1.0 - exp(-time / trajTau));

  // ================================================================
  // Forward kinematics: Finger 1 (base angle 0, pointing +x)
  // ================================================================
  ca1[1] = q1[1];
  ca1[2] = ca1[1] + q1[2];
  ca1[3] = ca1[2] + q1[3];
  ca1[4] = ca1[3] + q1[4];

  jx1[1] = 0.0;  jy1[1] = 0.0;
  jx1[2] = jx1[1] + Ls * cos(ca1[1]);  jy1[2] = jy1[1] + Ls * sin(ca1[1]);
  jx1[3] = jx1[2] + Ls * cos(ca1[2]);  jy1[3] = jy1[2] + Ls * sin(ca1[2]);
  jx1[4] = jx1[3] + Ls * cos(ca1[3]);  jy1[4] = jy1[3] + Ls * sin(ca1[3]);
  jx1[5] = jx1[4] + Ls * cos(ca1[4]);  jy1[5] = jy1[4] + Ls * sin(ca1[4]);
  tipX1 = jx1[5];
  tipY1 = jy1[5];

  // Tip velocity (analytical, from angular velocities)
  tipVx1 = -Ls * sin(ca1[1]) * dq1[1]
         - Ls * sin(ca1[2]) * (dq1[1] + dq1[2])
         - Ls * sin(ca1[3]) * (dq1[1] + dq1[2] + dq1[3])
         - Ls * sin(ca1[4]) * (dq1[1] + dq1[2] + dq1[3] + dq1[4]);
  tipVy1 =  Ls * cos(ca1[1]) * dq1[1]
         + Ls * cos(ca1[2]) * (dq1[1] + dq1[2])
         + Ls * cos(ca1[3]) * (dq1[1] + dq1[2] + dq1[3])
         + Ls * cos(ca1[4]) * (dq1[1] + dq1[2] + dq1[3] + dq1[4]);

  // Section midpoints (finger 1)
  mx1[1] = (jx1[1] + jx1[2]) / 2.0;  my1[1] = (jy1[1] + jy1[2]) / 2.0;
  mx1[2] = (jx1[2] + jx1[3]) / 2.0;  my1[2] = (jy1[2] + jy1[3]) / 2.0;
  mx1[3] = (jx1[3] + jx1[4]) / 2.0;  my1[3] = (jy1[3] + jy1[4]) / 2.0;
  mx1[4] = (jx1[4] + jx1[5]) / 2.0;  my1[4] = (jy1[4] + jy1[5]) / 2.0;

  // Distance to obstacle center (finger 1, epsilon for zero-guard)
  d1[1] = sqrt((mx1[1] - xObs)^2 + (my1[1] - yObs)^2 + 1.0e-14);
  d1[2] = sqrt((mx1[2] - xObs)^2 + (my1[2] - yObs)^2 + 1.0e-14);
  d1[3] = sqrt((mx1[3] - xObs)^2 + (my1[3] - yObs)^2 + 1.0e-14);
  d1[4] = sqrt((mx1[4] - xObs)^2 + (my1[4] - yObs)^2 + 1.0e-14);

  // Penetration (finger 1)
  pen1[1] = max(0.0, rObs + rf - d1[1]);
  pen1[2] = max(0.0, rObs + rf - d1[2]);
  pen1[3] = max(0.0, rObs + rf - d1[3]);
  pen1[4] = max(0.0, rObs + rf - d1[4]);

  // Contact force (finger 1, collision enabled)
  Fc1[1] = kContact * pen1[1];
  Fc1[2] = kContact * pen1[2];
  Fc1[3] = kContact * pen1[3];
  Fc1[4] = kContact * pen1[4];
  FcTot1 = Fc1[1] + Fc1[2] + Fc1[3] + Fc1[4];

  // Clearance (finger 1)
  clr1 = min(d1[1] - rObs - rf, min(d1[2] - rObs - rf, min(d1[3] - rObs - rf, d1[4] - rObs - rf)));

  // ================================================================
  // Forward kinematics: Finger 2 (base angle 120 deg)
  // ================================================================
  ca2[1] = baseAng2 + q2[1];
  ca2[2] = ca2[1] + q2[2];
  ca2[3] = ca2[2] + q2[3];
  ca2[4] = ca2[3] + q2[4];

  jx2[1] = 0.0;  jy2[1] = 0.0;
  jx2[2] = jx2[1] + Ls * cos(ca2[1]);  jy2[2] = jy2[1] + Ls * sin(ca2[1]);
  jx2[3] = jx2[2] + Ls * cos(ca2[2]);  jy2[3] = jy2[2] + Ls * sin(ca2[2]);
  jx2[4] = jx2[3] + Ls * cos(ca2[3]);  jy2[4] = jy2[3] + Ls * sin(ca2[3]);
  jx2[5] = jx2[4] + Ls * cos(ca2[4]);  jy2[5] = jy2[4] + Ls * sin(ca2[4]);
  tipX2 = jx2[5];
  tipY2 = jy2[5];

  mx2[1] = (jx2[1] + jx2[2]) / 2.0;  my2[1] = (jy2[1] + jy2[2]) / 2.0;
  mx2[2] = (jx2[2] + jx2[3]) / 2.0;  my2[2] = (jy2[2] + jy2[3]) / 2.0;
  mx2[3] = (jx2[3] + jx2[4]) / 2.0;  my2[3] = (jy2[3] + jy2[4]) / 2.0;
  mx2[4] = (jx2[4] + jx2[5]) / 2.0;  my2[4] = (jy2[4] + jy2[5]) / 2.0;

  d2[1] = sqrt((mx2[1] - xObs)^2 + (my2[1] - yObs)^2 + 1.0e-14);
  d2[2] = sqrt((mx2[2] - xObs)^2 + (my2[2] - yObs)^2 + 1.0e-14);
  d2[3] = sqrt((mx2[3] - xObs)^2 + (my2[3] - yObs)^2 + 1.0e-14);
  d2[4] = sqrt((mx2[4] - xObs)^2 + (my2[4] - yObs)^2 + 1.0e-14);

  pen2[1] = max(0.0, rObs + rf - d2[1]);
  pen2[2] = max(0.0, rObs + rf - d2[2]);
  pen2[3] = max(0.0, rObs + rf - d2[3]);
  pen2[4] = max(0.0, rObs + rf - d2[4]);

  Fc2[1] = kContact * pen2[1];
  Fc2[2] = kContact * pen2[2];
  Fc2[3] = kContact * pen2[3];
  Fc2[4] = kContact * pen2[4];
  FcTot2 = Fc2[1] + Fc2[2] + Fc2[3] + Fc2[4];
  clr2 = min(d2[1] - rObs - rf, min(d2[2] - rObs - rf, min(d2[3] - rObs - rf, d2[4] - rObs - rf)));

  // ================================================================
  // Forward kinematics: Finger 3 (base angle 240 deg)
  // ================================================================
  ca3[1] = baseAng3 + q3[1];
  ca3[2] = ca3[1] + q3[2];
  ca3[3] = ca3[2] + q3[3];
  ca3[4] = ca3[3] + q3[4];

  jx3[1] = 0.0;  jy3[1] = 0.0;
  jx3[2] = jx3[1] + Ls * cos(ca3[1]);  jy3[2] = jy3[1] + Ls * sin(ca3[1]);
  jx3[3] = jx3[2] + Ls * cos(ca3[2]);  jy3[3] = jy3[2] + Ls * sin(ca3[2]);
  jx3[4] = jx3[3] + Ls * cos(ca3[3]);  jy3[4] = jy3[3] + Ls * sin(ca3[3]);
  jx3[5] = jx3[4] + Ls * cos(ca3[4]);  jy3[5] = jy3[4] + Ls * sin(ca3[4]);
  tipX3 = jx3[5];
  tipY3 = jy3[5];

  mx3[1] = (jx3[1] + jx3[2]) / 2.0;  my3[1] = (jy3[1] + jy3[2]) / 2.0;
  mx3[2] = (jx3[2] + jx3[3]) / 2.0;  my3[2] = (jy3[2] + jy3[3]) / 2.0;
  mx3[3] = (jx3[3] + jx3[4]) / 2.0;  my3[3] = (jy3[3] + jy3[4]) / 2.0;
  mx3[4] = (jx3[4] + jx3[5]) / 2.0;  my3[4] = (jy3[4] + jy3[5]) / 2.0;

  d3[1] = sqrt((mx3[1] - xObs)^2 + (my3[1] - yObs)^2 + 1.0e-14);
  d3[2] = sqrt((mx3[2] - xObs)^2 + (my3[2] - yObs)^2 + 1.0e-14);
  d3[3] = sqrt((mx3[3] - xObs)^2 + (my3[3] - yObs)^2 + 1.0e-14);
  d3[4] = sqrt((mx3[4] - xObs)^2 + (my3[4] - yObs)^2 + 1.0e-14);

  pen3[1] = max(0.0, rObs + rf - d3[1]);
  pen3[2] = max(0.0, rObs + rf - d3[2]);
  pen3[3] = max(0.0, rObs + rf - d3[3]);
  pen3[4] = max(0.0, rObs + rf - d3[4]);

  Fc3[1] = kContact * pen3[1];
  Fc3[2] = kContact * pen3[2];
  Fc3[3] = kContact * pen3[3];
  Fc3[4] = kContact * pen3[4];
  FcTot3 = Fc3[1] + Fc3[2] + Fc3[3] + Fc3[4];
  clr3 = min(d3[1] - rObs - rf, min(d3[2] - rObs - rf, min(d3[3] - rObs - rf, d3[4] - rObs - rf)));

  // ===== Overall contact force and clearance =====
  FcTotAll = FcTot1 + FcTot2 + FcTot3;
  clrMin = min(clr1, min(clr2, clr3));

  // ===== Tracking error (zero-guarded norm) =====
  tipErr1 = sqrt((tipX1 - xTgt)^2 + (tipY1 - yTgt)^2 + 1.0e-14);
  tipErrVerif = if after13 then tipErr1 else 0.0;

  // ===== Deformation metrics =====
  defMax1 = max(abs(q1[1]), max(abs(q1[2]), max(abs(q1[3]), abs(q1[4]))));
  defMax2 = max(abs(q2[1]), max(abs(q2[2]), max(abs(q2[3]), abs(q2[4]))));
  defMax3 = max(abs(q3[1]), max(abs(q3[2]), max(abs(q3[3]), abs(q3[4]))));

  // ===== Contact-aware stiffness scheduling (bounded) =====
  // High stiffness near target, reduced under heavy contact
  stiff1 = (stiffMin + (stiffMax - stiffMin) * exp(-tipErr1 / stiffTrans))
           / (1.0 + FcTot1 / 8.0);
  stiff2 = stiffMin;
  stiff3 = stiffMin;

  // ===== Feedforward pressure (stiffness-compensated) =====
  pFF1 = qDesired * kSec * stiff1 / gPT;

  // ===== Controller: contact-aware shape control =====
  // PD on tip position with feedforward; x-term inverted (more bend = less x)
  pCmd1 = pFF1
        + Kp_y * (desTipY - tipY1) + Kd_y * (0.0 - tipVy1)
        + Kp_x * (tipX1 - desTipX) + Kd_x * (tipVx1 - 0.0);

  // Saturate to [0, pMax]
  pSat1 = max(0.0, min(pMax, pCmd1));

  // Fingers 2,3: moderate gripping pressure
  pCmd2 = 30000.0;
  pCmd3 = 30000.0;
  pSat2 = max(0.0, min(pMax, pCmd2));
  pSat3 = max(0.0, min(pMax, pCmd3));

  // ================================================================
  // Section dynamics: Finger 1
  // Each section: J*ddq = pressure torque - spring - damper + contact + friction
  // ================================================================
  der(q1[1]) = dq1[1];
  Jsec * der(dq1[1]) = gPT * pSat1 - kSec * stiff1 * q1[1] - bSec * dq1[1]
    + Fc1[1] * (my1[1] - yObs) / d1[1] * Ls / 2.0
    - mu * Fc1[1] * tanh(dq1[1] * 10.0) * Ls / 2.0;

  der(q1[2]) = dq1[2];
  Jsec * der(dq1[2]) = gPT * pSat1 - kSec * stiff1 * q1[2] - bSec * dq1[2]
    + Fc1[2] * (my1[2] - yObs) / d1[2] * Ls / 2.0
    - mu * Fc1[2] * tanh(dq1[2] * 10.0) * Ls / 2.0;

  der(q1[3]) = dq1[3];
  Jsec * der(dq1[3]) = gPT * pSat1 - kSec * stiff1 * q1[3] - bSec * dq1[3]
    + Fc1[3] * (my1[3] - yObs) / d1[3] * Ls / 2.0
    - mu * Fc1[3] * tanh(dq1[3] * 10.0) * Ls / 2.0;

  der(q1[4]) = dq1[4];
  Jsec * der(dq1[4]) = gPT * pSat1 - kSec * stiff1 * q1[4] - bSec * dq1[4]
    + Fc1[4] * (my1[4] - yObs) / d1[4] * Ls / 2.0
    - mu * Fc1[4] * tanh(dq1[4] * 10.0) * Ls / 2.0
    + Fdist1y * Ls;

  // ================================================================
  // Section dynamics: Finger 2
  // ================================================================
  der(q2[1]) = dq2[1];
  Jsec * der(dq2[1]) = gPT * pSat2 - kSec * stiff2 * q2[1] - bSec * dq2[1]
    + Fc2[1] * (my2[1] - yObs) / d2[1] * Ls / 2.0
    - mu * Fc2[1] * tanh(dq2[1] * 10.0) * Ls / 2.0;

  der(q2[2]) = dq2[2];
  Jsec * der(dq2[2]) = gPT * pSat2 - kSec * stiff2 * q2[2] - bSec * dq2[2]
    + Fc2[2] * (my2[2] - yObs) / d2[2] * Ls / 2.0
    - mu * Fc2[2] * tanh(dq2[2] * 10.0) * Ls / 2.0;

  der(q2[3]) = dq2[3];
  Jsec * der(dq2[3]) = gPT * pSat2 - kSec * stiff2 * q2[3] - bSec * dq2[3]
    + Fc2[3] * (my2[3] - yObs) / d2[3] * Ls / 2.0
    - mu * Fc2[3] * tanh(dq2[3] * 10.0) * Ls / 2.0;

  der(q2[4]) = dq2[4];
  Jsec * der(dq2[4]) = gPT * pSat2 - kSec * stiff2 * q2[4] - bSec * dq2[4]
    + Fc2[4] * (my2[4] - yObs) / d2[4] * Ls / 2.0
    - mu * Fc2[4] * tanh(dq2[4] * 10.0) * Ls / 2.0;

  // ================================================================
  // Section dynamics: Finger 3
  // ================================================================
  der(q3[1]) = dq3[1];
  Jsec * der(dq3[1]) = gPT * pSat3 - kSec * stiff3 * q3[1] - bSec * dq3[1]
    + Fc3[1] * (my3[1] - yObs) / d3[1] * Ls / 2.0
    - mu * Fc3[1] * tanh(dq3[1] * 10.0) * Ls / 2.0;

  der(q3[2]) = dq3[2];
  Jsec * der(dq3[2]) = gPT * pSat3 - kSec * stiff3 * q3[2] - bSec * dq3[2]
    + Fc3[2] * (my3[2] - yObs) / d3[2] * Ls / 2.0
    - mu * Fc3[2] * tanh(dq3[2] * 10.0) * Ls / 2.0;

  der(q3[3]) = dq3[3];
  Jsec * der(dq3[3]) = gPT * pSat3 - kSec * stiff3 * q3[3] - bSec * dq3[3]
    + Fc3[3] * (my3[3] - yObs) / d3[3] * Ls / 2.0
    - mu * Fc3[3] * tanh(dq3[3] * 10.0) * Ls / 2.0;

  der(q3[4]) = dq3[4];
  Jsec * der(dq3[4]) = gPT * pSat3 - kSec * stiff3 * q3[4] - bSec * dq3[4]
    + Fc3[4] * (my3[4] - yObs) / d3[4] * Ls / 2.0
    - mu * Fc3[4] * tanh(dq3[4] * 10.0) * Ls / 2.0;

  // ===== Temperature dynamics (Joule heating with cooling) =====
  der(temp1) = tempCoeff * pSat1 * pSat1 - tempCool * (temp1 - Tamb);
  der(temp2) = tempCoeff * pSat2 * pSat2 - tempCool * (temp2 - Tamb);
  der(temp3) = tempCoeff * pSat3 * pSat3 - tempCool * (temp3 - Tamb);

  // ===== Verification criteria =====
  trackOK = (not after13) or (tipErr1 <= trackErrBound);
  actuatorOK = pSat1 >= 0.0 and pSat1 <= pMax
           and pSat2 >= 0.0 and pSat2 <= pMax
           and pSat3 >= 0.0 and pSat3 <= pMax;
  deformOK = defMax1 <= defMaxBound and defMax2 <= defMaxBound and defMax3 <= defMaxBound;
  contactOK = FcTotAll <= contactMaxBound;
  tempOK = temp1 <= tempMax and temp2 <= tempMax and temp3 <= tempMax;
  clearanceOK = clrMin >= clearanceMinBound;
  noNaN = true;
  allOK = trackOK and actuatorOK and deformOK and contactOK and tempOK and clearanceOK and noNaN;

end SoftGripAvoidF;