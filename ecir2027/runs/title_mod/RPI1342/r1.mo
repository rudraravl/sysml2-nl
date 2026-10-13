model TendonSoftAvoidD
  "Instrumented tendon-driven soft robotic system with obstacle avoidance and bounded stiffness scheduling";

  // === Requirement-specified parameters ===
  parameter Real L = 0.55 "Continuum body length [m]";
  parameter Integer nSec = 6 "Number of constant-curvature sections";
  parameter Real Ls = L / nSec "Section length [m]";
  parameter Real maxTension = 42.0 "Max tendon tension per tendon [N]";
  parameter Real mu = 0.55 "Obstacle friction coefficient";
  parameter Real fDist = 8.0 "Lateral tip load disturbance [N]";
  parameter Real fSample = 200.0 "Sampling frequency [Hz]";
  parameter Real tStop = 14.0 "Simulation duration [s]";
  parameter Real errBound = 0.04 "Primary tracking error bound [m]";
  parameter Real tSettle = 9.1 "Settling time threshold [s]";

  // === Estimated parameters (not specified in requirement; labeled as such) ===
  parameter Real rTendon = 0.02 "Tendon routing radius [m] (estimated)";
  parameter Real EI = 0.3 "Bending stiffness [N.m^2] (estimated)";
  parameter Real rBody = 0.012 "Body radius [m] (estimated)";
  parameter Real rObs = 0.02 "Obstacle radius [m] (estimated)";
  parameter Real xObs = 0.30 "Obstacle center x [m] (estimated)";
  parameter Real yObs = -0.015 "Obstacle center y [m] (estimated)";
  parameter Real xTarget = 0.511 "Target x [m] (estimated)";
  parameter Real yTarget = 0.175 "Target y [m] (estimated)";
  parameter Real Tact = 0.06 "Actuator time constant [s] (estimated)";
  parameter Real Tpret = 10.0 "Tendon pretension [N] (estimated)";
  parameter Real kStiffMin = 5.0 "Min scheduled stiffness [N/m] (estimated)";
  parameter Real kStiffMax = 50.0 "Max scheduled stiffness [N/m] (estimated)";
  parameter Real mEff = 0.5 "Effective rotational inertia [kg.m] (estimated)";
  parameter Real kContact = 500.0 "Contact spring stiffness [N/m] (estimated)";
  parameter Real kAvoid = 3.0 "Obstacle avoidance curvature gain [1/m^2] (estimated)";
  parameter Real safetyMargin = 0.01 "Obstacle safety margin [m] (estimated)";
  parameter Real errScale = 0.08 "Error scale for stiffness scheduling [m] (estimated)";
  parameter Real distMomentFactor = 0.05 "Disturbance moment reduction factor (estimated)";
  parameter Real Ract = 0.01 "Actuator resistance [Ohm] (estimated)";
  parameter Real thermCap = 20.0 "Thermal capacity [J/K] (estimated)";
  parameter Real thermRes = 0.4 "Thermal resistance [K/W] (estimated)";
  parameter Real tempRef = 293.15 "Reference temperature [K] (estimated)";
  parameter Real tempRiseMax = 10.0 "Max temperature rise bound [K] (estimated)";
  parameter Real fContactMax = 20.0 "Max contact force bound [N] (estimated)";
  parameter Real clearanceBound = 0.02 "Max penetration bound [m] (estimated)";
  parameter Real kappaMax = 3.0 "Max curvature [1/m] (estimated)";
  parameter Real dt = 1.0 / fSample "Sample interval [s]";

  // Zero-branch safety constants
  constant Real epsKappa = 1e-6 "Curvature zero-branch threshold [1/m]";
  constant Real epsNorm = 1e-8 "Norm zero-branch threshold";

  // === Dynamic states ===
  Real T1(start = Tpret) "Tendon 1 tension — actuator state [N]";
  Real T2(start = Tpret) "Tendon 2 tension — actuator state [N]";
  Real T3(start = Tpret) "Tendon 3 tension — actuator state [N]";
  Real kappa(start = 0.0) "Body curvature — deformation state [1/m]";
  Real tempAct(start = tempRef) "Actuator temperature — thermal state [K]";

  // === Commands ===
  Real u1 "Tendon 1 command [N]";
  Real u2 "Tendon 2 command [N]";
  Real u3 "Tendon 3 command [N]";
  Real kappaCmd "Commanded curvature [1/m]";

  // === Sensor: tip pose ===
  Real xTip "Tip x position [m]";
  Real yTip "Tip y position [m]";
  Real phiTip "Tip tangent angle [rad]";

  // === Sensor: section deformations ===
  Real eps1 "Section 1 deformation (bending angle) [rad]";
  Real eps2 "Section 2 deformation (bending angle) [rad]";
  Real eps3 "Section 3 deformation (bending angle) [rad]";
  Real eps4 "Section 4 deformation (bending angle) [rad]";
  Real eps5 "Section 5 deformation (bending angle) [rad]";
  Real eps6 "Section 6 deformation (bending angle) [rad]";

  // === Section boundary positions ===
  Real x1 "Section 1 tip x [m]";  Real y1 "Section 1 tip y [m]";
  Real x2 "Section 2 tip x [m]";  Real y2 "Section 2 tip y [m]";
  Real x3 "Section 3 tip x [m]";  Real y3 "Section 3 tip y [m]";
  Real x4 "Section 4 tip x [m]";  Real y4 "Section 4 tip y [m]";
  Real x5 "Section 5 tip x [m]";  Real y5 "Section 5 tip y [m]";
  Real x6 "Section 6 tip x [m]";  Real y6 "Section 6 tip y [m]";

  // === Sensor: distributed contact force ===
  Real fc1 "Contact force at section 1 [N]";
  Real fc2 "Contact force at section 2 [N]";
  Real fc3 "Contact force at section 3 [N]";
  Real fc4 "Contact force at section 4 [N]";
  Real fc5 "Contact force at section 5 [N]";
  Real fc6 "Contact force at section 6 [N]";
  Real fContact "Maximum distributed contact force [N]";
  Real fFriction "Friction force from contact [N]";

  // === Obstacle clearance ===
  Real d0 "Distance obstacle to base [m]";
  Real d1 "Distance obstacle to section 1 tip [m]";
  Real d2 "Distance obstacle to section 2 tip [m]";
  Real d3 "Distance obstacle to section 3 tip [m]";
  Real d4 "Distance obstacle to section 4 tip [m]";
  Real d5 "Distance obstacle to section 5 tip [m]";
  Real d6 "Distance obstacle to section 6 tip [m]";
  Real dMin "Minimum distance [m]";
  Real clearance "Obstacle clearance [m]";
  Boolean inContact "Contact flag";

  // === Disturbance ===
  Real fDistApply "Applied disturbance force [N]";
  Real Mdist "Disturbance moment [N.m]";

  // === Control internals ===
  Real kappaTarget "Target curvature from inverse kinematics [1/m]";
  Real kStiff "Scheduled stiffness (bounded) [N/m]";
  Real kappaEq "Equilibrium curvature [1/m]";
  Real Mtendon "Tendon bending moment [N.m]";
  Real Mcontact "Contact moment [N.m]";
  Real errTip "Tip tracking error [m]";

  // === Temperature ===
  Real tempRise "Temperature rise above reference [K]";

  // === Bound monitors ===
  Real actuatorMargin "Min actuator margin to limit [N]";
  Real deformMax "Maximum section deformation [rad]";
  Real contactMargin "Contact force margin to bound [N]";
  Real tempMargin "Temperature margin to bound [K]";
  Real clearanceMonitor "Obstacle clearance (negative = penetration) [m]";
  Real tipErrorAfter "Tip error after settle time [m]";

equation
  // === Target curvature from target position (zero-branch safe) ===
  kappaTarget = noEvent(if (xTarget * xTarget + yTarget * yTarget) < epsNorm then 0.0
    else 2.0 * yTarget / (xTarget * xTarget + yTarget * yTarget));

  // === Tip kinematics — constant-curvature arc ===
  xTip = noEvent(if abs(kappa) < epsKappa then L else sin(kappa * L) / kappa);
  yTip = noEvent(if abs(kappa) < epsKappa then 0.0 else (1.0 - cos(kappa * L)) / kappa);
  phiTip = kappa * L;

  // === Section boundary kinematics ===
  x1 = noEvent(if abs(kappa) < epsKappa then Ls         else sin(kappa * Ls)         / kappa);
  y1 = noEvent(if abs(kappa) < epsKappa then 0.0        else (1.0 - cos(kappa * Ls))         / kappa);
  x2 = noEvent(if abs(kappa) < epsKappa then 2.0 * Ls   else sin(kappa * 2.0 * Ls)   / kappa);
  y2 = noEvent(if abs(kappa) < epsKappa then 0.0        else (1.0 - cos(kappa * 2.0 * Ls))   / kappa);
  x3 = noEvent(if abs(kappa) < epsKappa then 3.0 * Ls   else sin(kappa * 3.0 * Ls)   / kappa);
  y3 = noEvent(if abs(kappa) < epsKappa then 0.0        else (1.0 - cos(kappa * 3.0 * Ls))   / kappa);
  x4 = noEvent(if abs(kappa) < epsKappa then 4.0 * Ls   else sin(kappa * 4.0 * Ls)   / kappa);
  y4 = noEvent(if abs(kappa) < epsKappa then 0.0        else (1.0 - cos(kappa * 4.0 * Ls))   / kappa);
  x5 = noEvent(if abs(kappa) < epsKappa then 5.0 * Ls   else sin(kappa * 5.0 * Ls)   / kappa);
  y5 = noEvent(if abs(kappa) < epsKappa then 0.0        else (1.0 - cos(kappa * 5.0 * Ls))   / kappa);
  x6 = xTip;
  y6 = yTip;

  // === Section deformations (bending angle per section) ===
  eps1 = kappa * Ls;
  eps2 = kappa * Ls;
  eps3 = kappa * Ls;
  eps4 = kappa * Ls;
  eps5 = kappa * Ls;
  eps6 = kappa * Ls;

  // === Distances from obstacle center to body discretization points ===
  d0 = sqrt(xObs * xObs + yObs * yObs);
  d1 = sqrt((x1 - xObs) * (x1 - xObs) + (y1 - yObs) * (y1 - yObs));
  d2 = sqrt((x2 - xObs) * (x2 - xObs) + (y2 - yObs) * (y2 - yObs));
  d3 = sqrt((x3 - xObs) * (x3 - xObs) + (y3 - yObs) * (y3 - yObs));
  d4 = sqrt((x4 - xObs) * (x4 - xObs) + (y4 - yObs) * (y4 - yObs));
  d5 = sqrt((x5 - xObs) * (x5 - xObs) + (y5 - yObs) * (y5 - yObs));
  d6 = sqrt((x6 - xObs) * (x6 - xObs) + (y6 - yObs) * (y6 - yObs));

  // === Minimum distance and clearance ===
  dMin = min(d0, min(d1, min(d2, min(d3, min(d4, min(d5, d6))))));
  clearance = dMin - rObs - rBody;
  inContact = clearance < 0.0;

  // === Distributed contact forces (spring model, collision enabled) ===
  fc1 = kContact * max(0.0, rObs + rBody - d1);
  fc2 = kContact * max(0.0, rObs + rBody - d2);
  fc3 = kContact * max(0.0, rObs + rBody - d3);
  fc4 = kContact * max(0.0, rObs + rBody - d4);
  fc5 = kContact * max(0.0, rObs + rBody - d5);
  fc6 = kContact * max(0.0, rObs + rBody - d6);

  // === Maximum contact force and friction (mu = 0.55) ===
  fContact = max(fc1, max(fc2, max(fc3, max(fc4, max(fc5, fc6)))));
  fFriction = mu * fContact;

  // === Contact moment (approximate: normal force at obstacle x-location) ===
  Mcontact = fContact * xObs;

  // === Disturbance: 8 N lateral tip load during middle third ===
  fDistApply = if (time >= tStop / 3.0 and time <= 2.0 * tStop / 3.0) then fDist else 0.0;
  Mdist = fDistApply * L * distMomentFactor;

  // === Tip tracking error (zero-branch safe) ===
  errTip = noEvent(if (xTarget - xTip) * (xTarget - xTip) + (yTarget - yTip) * (yTarget - yTip) < epsNorm
    then 0.0
    else sqrt((xTarget - xTip) * (xTarget - xTip) + (yTarget - yTip) * (yTarget - yTip)));

  // === Bounded stiffness scheduling (increases near target for stiffen/hold) ===
  kStiff = kStiffMin + (kStiffMax - kStiffMin) * exp(-errTip / errScale);

  // === Contact-aware shape control ===
  kappaCmd = kappaTarget + kAvoid * max(0.0, safetyMargin - clearance);

  // === Tendon commands (inverse: T1 carries curvature, T2=T3=pretension) ===
  // Tendon spacing 120 deg: moment arm factors cos(0)=1, cos(120)=-0.5, cos(240)=-0.5
  u1 = max(0.0, min(maxTension, Tpret + kappaCmd * EI / rTendon));
  u2 = max(0.0, min(maxTension, Tpret));
  u3 = max(0.0, min(maxTension, Tpret));

  // === Tendon actuator dynamics (first-order) ===
  der(T1) = (u1 - T1) / Tact;
  der(T2) = (u2 - T2) / Tact;
  der(T3) = (u3 - T3) / Tact;

  // === Tendon bending moment (from 120-deg-spaced tendons) ===
  Mtendon = rTendon * (T1 - 0.5 * T2 - 0.5 * T3);

  // === Curvature dynamics (stiffness-scheduled time constant) ===
  kappaEq = Mtendon / EI + (Mdist + Mcontact) / (kStiff * L * L);
  der(kappa) = (kappaEq - kappa) * kStiff / mEff;

  // === Temperature dynamics (Joule heating + convective cooling) ===
  der(tempAct) = (T1 * T1 + T2 * T2 + T3 * T3) * Ract / thermCap
    - (tempAct - tempRef) / (thermCap * thermRes);
  tempRise = tempAct - tempRef;

  // === Bound monitors ===
  actuatorMargin = min(maxTension - T1, min(maxTension - T2, min(maxTension - T3,
    min(T1, min(T2, T3)))));
  deformMax = max(abs(eps1), max(abs(eps2), max(abs(eps3),
    max(abs(eps4), max(abs(eps5), abs(eps6))))));
  contactMargin = fContactMax - fContact;
  tempMargin = tempRiseMax - tempRise;
  clearanceMonitor = clearance;
  tipErrorAfter = noEvent(if time >= tSettle then errTip else 0.0);

  // === Runtime assertions for bounded behavior ===
  assert(T1 >= -0.001 and T1 <= maxTension + 0.001, "Tendon 1 tension out of bounds");
  assert(T2 >= -0.001 and T2 <= maxTension + 0.001, "Tendon 2 tension out of bounds");
  assert(T3 >= -0.001 and T3 <= maxTension + 0.001, "Tendon 3 tension out of bounds");
  assert(abs(kappa) <= kappaMax + 0.01, "Curvature out of bounds");
  assert(fContact <= fContactMax + 1.0, "Contact force exceeds bound");
  assert(tempRise <= tempRiseMax + 1.0, "Temperature exceeds bound");
  assert(clearance >= -clearanceBound - 0.001, "Obstacle penetration exceeds bound");
  assert(not IsNaN(T1) and not IsNaN(T2) and not IsNaN(T3), "NaN in actuator states");
  assert(not IsNaN(kappa) and not IsNaN(errTip) and not IsNaN(tempAct), "NaN in physical or estimator values");

end TendonSoftAvoidD;