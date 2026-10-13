model FourBarDriveB
  "Closed-chain four-bar: constant-speed crank drive, PI torque control, coupled output observation."

  parameter Real L1 = 0.50 "fixed pivot distance (m)";
  parameter Real L2 = 0.20 "crank length (m)";
  parameter Real L3 = 0.44 "coupler length (m)";
  parameter Real L4 = 0.35 "rocker length (m)";

  parameter Real tau_max = 20.5 "allowed crank command magnitude (N.m)";

  parameter Real T_total = 10.0 "mission duration (s)";
  parameter Real Ts = 0.01 "100 Hz sample/trace period (s)";
  parameter Real loadDisturbance = 5.6 "load disturbance magnitude (N.m)";

  // Unspecified values: chosen placeholders, clearly labeled.
  parameter Real w_ref = 0.20 "constant input-speed reference (rad/s), unspecified placeholder";
  parameter Real q0 = 0.50 "initial crank angle (rad), unspecified placeholder chosen to avoid collision";
  parameter Real J_eff = 1.00 "effective crank inertia (kg.m2), unspecified placeholder";
  parameter Real Kp = 100.0 "PI proportional gain, unspecified design placeholder";
  parameter Real Ki = 200.0 "PI integral gain, unspecified design placeholder";
  parameter Real awGain = 1.0 "anti-windup gain, unspecified design placeholder";
  parameter Real speedBand = 0.10 "speed tracking band (rad/s), unspecified placeholder";
  parameter Real branchSign = -1.0 "assembly branch sign for rocker solution (+1 or -1)";

  Real q(start = q0, fixed = true) "crank angle, actuator position (rad)";
  Real w(start = w_ref, fixed = true) "crank angular speed, actuator velocity (rad/s)";
  Real xi(start = 0.0, fixed = true) "PI integrator state (rad.s)";
  Real outputTravel(start = 0.0, fixed = true) "rocker-tip path length (m)";

  Real error "speed error (rad/s)";
  Real tau_unsat "unsaturated PI command (N.m)";
  Real tau_cmd "saturated crank command (N.m)";
  Real tau_dist "injected load disturbance torque (N.m)";
  Real tau_grav "gravity torque term (N.m)";

  Real theta4 "rocker angle (rad)";
  Real theta3 "coupler angle (rad)";
  Real Bx "crank-tip x (m)";
  Real By "crank-tip y (m)";
  Real xOut "rocker-tip x, output pose (m)";
  Real yOut "rocker-tip y, output pose (m)";
  Real resX "loop-closure residual in x (m)";
  Real resY "loop-closure residual in y (m)";
  Real closureError "loop-closure norm (m)";
  Real w4 "rocker angular speed (rad/s)";

  Real K2 "crank-tip x offset from rocker pivot (m)";
  Real Kdist "distance between crank tip and rocker pivot (m)";
  Real alpha "angle of vector from rocker pivot to crank tip (rad)";
  Real argA "law-of-cosines argument (-)";
  Real argClamped "clamped argument for acos (-)";
  Real beta "interior angle at rocker pivot (rad)";
  Real den "sin(theta4-theta3)";
  Real denSafe "nonzero-safe denominator";

  Boolean collisionPrevented "nonadjacent links do not collide";
  Boolean actuatorBoundsOK "command within allowed magnitude";
  Boolean commandSaturated "unsaturated command exceeded bound";
  Boolean speedBandOK "speed within specified band";
  Boolean closureOK "closure error below 0.002 m after 6.5 s";
  Boolean primaryTrackingOK "primary tracking/closure requirement satisfied";
  Boolean validJointRefs "joint references finite and consistent";
  Boolean finiteCheckOK "no NaN/infinite physical, control, or estimator values";
  Real primaryTrackingError "primary tracking error, closure norm (m)";

protected
  function segIntersect "Check if two 2D line segments intersect"
    input Real x1; input Real y1; input Real x2; input Real y2;
    input Real x3; input Real y3; input Real x4; input Real y4;
    output Boolean intersect;
  protected
    Real denVal;
    Real t;
    Real u;
  algorithm
    denVal := (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if abs(denVal) < 1.0e-12 then
      intersect := false;
    else
      t := ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denVal;
      u := -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denVal;
      intersect := (t >= 0.0) and (t <= 1.0) and (u >= 0.0) and (u <= 1.0);
    end if;
  end segIntersect;

equation
  // Actuator dynamics
  der(q) = w;
  J_eff * der(w) = tau_cmd + tau_dist - tau_grav;
  tau_grav = 0.0;

  // Disturbance during middle third of mission
  tau_dist = if (time >= T_total / 3.0) and (time <= 2.0 * T_total / 3.0) then -loadDisturbance else 0.0;

  // PI speed control with saturation and anti-windup
  error = w_ref - w;
  tau_unsat = Kp * error + Ki * xi;
  tau_cmd = max(-tau_max, min(tau_max, tau_unsat));
  der(xi) = error - awGain * (tau_unsat - tau_cmd);

  // Crank tip
  Bx = L2 * cos(q);
  By = L2 * sin(q);

  // Explicit four-bar position solution (Freudenstein / law of cosines)
  K2 = Bx - L1;
  Kdist = sqrt(K2 * K2 + By * By);
  alpha = atan2(By, K2);
  argA = (Kdist * Kdist + L4 * L4 - L3 * L3) / (2.0 * max(Kdist, 1.0e-9) * L4);
  argClamped = max(-1.0, min(1.0, argA));
  beta = acos(argClamped);
  theta4 = alpha + branchSign * beta;

  // Rocker tip (output pose)
  xOut = L1 + L4 * cos(theta4);
  yOut = L4 * sin(theta4);

  // Coupler angle
  theta3 = atan2(yOut - By, xOut - Bx);

  // Loop-closure residuals (should be ~0 by construction; instrumented)
  resX = L2 * cos(q) + L3 * cos(theta3) - L1 - L4 * cos(theta4);
  resY = L2 * sin(q) + L3 * sin(theta3) - L4 * sin(theta4);
  closureError = sqrt(resX * resX + resY * resY);
  primaryTrackingError = closureError;

  // Rocker angular speed via velocity loop closure
  den = sin(theta4 - theta3);
  denSafe = if den > 1.0e-12 then den elseif den < -1.0e-12 then den else 1.0e-12;
  w4 = L2 * w * sin(q - theta3) / (L4 * denSafe);
  der(outputTravel) = L4 * abs(w4);

  // Collision prevention between nonadjacent links (crank and rocker)
  collisionPrevented = (not segIntersect(0.0, 0.0, Bx, By, L1, 0.0, xOut, yOut)) and
                       (not segIntersect(Bx, By, xOut, yOut, 0.0, 0.0, L1, 0.0));

  // Requirement checks
  actuatorBoundsOK = abs(tau_cmd) <= tau_max + 1.0e-9;
  commandSaturated = abs(tau_unsat) > tau_max + 1.0e-12;
  speedBandOK = abs(w - w_ref) <= speedBand;
  closureOK = if time >= 6.5 then closureError < 0.002 else true;
  primaryTrackingOK = closureOK;
  validJointRefs = (abs(theta3) < 1.0e12) and (abs(theta4) < 1.0e12);
  finiteCheckOK = (abs(q) < 1.0e12) and (abs(w) < 1.0e12) and (abs(tau_cmd) < 1.0e12) and
                  (abs(tau_unsat) < 1.0e12) and (abs(xi) < 1.0e12) and (abs(theta3) < 1.0e12) and
                  (abs(theta4) < 1.0e12) and (abs(resX) < 1.0e12) and (abs(resY) < 1.0e12) and
                  (abs(outputTravel) < 1.0e12) and (abs(xOut) < 1.0e12) and (abs(yOut) < 1.0e12);

  assert(actuatorBoundsOK, "actuator command bound exceeded");
  assert(speedBandOK, "speed band exceeded");
  assert(collisionPrevented, "nonadjacent link collision detected");
  assert(validJointRefs, "invalid joint references");
  assert(primaryTrackingOK, "primary tracking closure error after 6.5 s exceeded");
  assert(finiteCheckOK, "non-finite physical, control, or estimator value detected");

  annotation(experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1.0e-6));
end FourBarDriveB;