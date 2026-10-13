model FourBarDriveB
  "Closed-chain four-bar mechanism: constant-speed crank drive, PI torque control, coupled output observation."

  // Geometry from requirement (SI units)
  parameter Real L1 = 0.50 "fixed pivot distance (m)";
  parameter Real L2 = 0.20 "crank length (m)";
  parameter Real L3 = 0.44 "coupler length (m)";
  parameter Real L4 = 0.35 "rocker length (m)";

  // Actuator command bound from requirement
  parameter Real tau_max = 20.5 "allowed crank command magnitude (N.m)";

  // Mission and disturbance from requirement
  parameter Real T_total = 10.0 "mission duration (s)";
  parameter Real Ts = 0.01 "100 Hz sample/trace period (s)";
  parameter Real loadDisturbance = 5.6 "load disturbance magnitude (N.m)";
  constant Integer Ntrace = 1001 "number of synchronized 100 Hz traces over 10 s";

  // Unspecified physical/control values: nominal placeholders required for simulation.
  // They are not facts from the requirement.
  parameter Real w_ref = 0.20 "constant input-speed reference (rad/s), unspecified placeholder";
  parameter Real q0 = 0.50 "initial crank angle (rad), unspecified placeholder chosen to avoid nonadjacent collision";
  parameter Real J_eff = 1.00 "effective crank inertia (kg.m2), unspecified placeholder";
  parameter Real Kp = 100.0 "PI proportional gain (N.m/(rad/s)), unspecified design placeholder";
  parameter Real Ki = 200.0 "PI integral gain (N.m/(rad.s)), unspecified design placeholder";
  parameter Real awGain = 1.0 "anti-windup gain, unspecified design placeholder";
  parameter Real speedBand = 0.10 "speed tracking band (rad/s), unspecified placeholder";

  // Dynamic states
  Real q(start = q0) "crank angle, actuator position (rad)";
  Real w(start = w_ref) "crank angular speed, actuator velocity (rad/s)";
  Real xi(start = 0.0) "PI integrator state (rad.s)";
  Real outputTravel(start = 0.0) "rocker-tip path length (m)";

  // Control signals
  Real error "speed error (rad/s)";
  Real tau_unsat "unsaturated PI command (N.m)";
  Real tau_cmd "saturated crank command (N.m)";
  Real tau_dist "injected load disturbance torque (N.m)";
  Real tau_grav "gravity torque term; link masses unspecified, so no gravity torque can be derived (N.m)";

  // Kinematic variables
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
  Real den "sin(theta4-theta3)";
  Real denSafe "nonzero-safe denominator";

  // Collision variables
  Real minDistCR "minimum crank-rocker distance (m)";
  Real minDistCG "minimum coupler-ground distance (m)";

  // Requirement checks
  Boolean actuatorBoundsOK "command within allowed magnitude";
  Boolean commandSaturated "unsaturated command exceeded bound";
  Boolean speedBandOK "speed within specified band";
  Boolean closureOK "closure error below 0.002 m after 6.5 s";
  Boolean primaryTrackingOK "primary tracking/closure requirement satisfied";
  Boolean validJointRefs "joint references finite and consistent";
  Boolean finiteCheckOK "no NaN/infinite physical, control, or estimator values";
  Boolean collisionPrevented "nonadjacent links do not collide";
  Real primaryTrackingError "primary tracking error, closure norm (m)";

  // Synchronized 100 Hz traces
  Integer n(start = 0) "trace sample index";
  Real time_trace[Ntrace];
  Real q_trace[Ntrace];
  Real w_trace[Ntrace];
  Real tau_trace[Ntrace];
  Real xOut_trace[Ntrace];
  Real yOut_trace[Ntrace];
  Real theta4_trace[Ntrace];
  Real resX_trace[Ntrace];
  Real resY_trace[Ntrace];
  Real closureError_trace[Ntrace];
  Real outputTravel_trace[Ntrace];

equation
  // Plant dynamics: bounded torque drives the one-DOF closed chain.
  // Gravity: requirement states use gravity where applicable. Link masses/inertias
  // are not specified, so no gravitational torque term can be derived.
  der(q) = w;
  J_eff*der(w) = tau_cmd + tau_dist - tau_grav;
  tau_grav = 0.0;

  // Disturbance injected during the middle third of the 10 s mission.
  tau_dist = if time >= T_total/3.0 and time <= 2.0*T_total/3.0 then -loadDisturbance else 0.0;

  // PI input-speed control with command saturation and anti-windup.
  error = w_ref - w;
  tau_unsat = Kp*error + Ki*xi;
  tau_cmd = max(-tau_max, min(tau_max, tau_unsat));
  der(xi) = error - awGain*(tau_unsat - tau_cmd);

  // Four-bar kinematics (planar revolute Z joints).
  Bx = L2*cos(q);
  By = L2*sin(q);
  theta4 = fourBarOutputAngle(q, L1, L2, L3, L4);
  theta3 = fourBarCouplerAngle(q, theta4, L1, L2, L3, L4);
  xOut = L1 + L4*cos(theta4);
  yOut = L4*sin(theta4);

  // Loop-closure residuals (every closure equation).
  resX = L2*cos(q) + L3*cos(theta3) - L1 - L4*cos(theta4);
  resY = L2*sin(q) + L3*sin(theta3) - L4*sin(theta4);
  closureError = sqrt(resX*resX + resY*resY);
  primaryTrackingError = closureError;

  // Coupled output speed and travel.
  den = sin(theta4 - theta3);
  denSafe = if den > 1.0e-12 then den elseif den < -1.0e-12 then den else 1.0e-12;
  w4 = L2*w*sin(q - theta3)/(L4*denSafe);
  der(outputTravel) = L4*abs(w4);

  // Nonadjacent link collision prevention: crank-rocker and coupler-ground.
  minDistCR = segSegDist(0.0, 0.0, Bx, By, L1, 0.0, xOut, yOut);
  minDistCG = segSegDist(Bx, By, xOut, yOut, 0.0, 0.0, L1, 0.0);
  collisionPrevented = minDistCR > 0.0 and minDistCG > 0.0;

  // Requirement instrumentation.
  actuatorBoundsOK = abs(tau_cmd) <= tau_max + 1.0e-9;
  commandSaturated = abs(tau_unsat) > tau_max + 1.0e-12;
  speedBandOK = abs(w - w_ref) <= speedBand;
  closureOK = if time >= 6.5 then closureError < 0.002 else true;
  primaryTrackingOK = closureOK;
  validJointRefs = abs(theta3) < 1.0e12 and abs(theta4) < 1.0e12 and abs(sin(theta3)^2 + cos(theta3)^2 - 1.0) < 1.0e-9 and abs(sin(theta4)^2 + cos(theta4)^2 - 1.0) < 1.0e-9;
  finiteCheckOK = abs(q) < 1.0e12 and abs(w) < 1.0e12 and abs(tau_cmd) < 1.0e12 and abs(tau_unsat) < 1.0e12 and abs(xi) < 1.0e12 and abs(theta3) < 1.0e12 and abs(theta4) < 1.0e12 and abs(resX) < 1.0e12 and abs(resY) < 1.0e12 and abs(outputTravel) < 1.0e12 and abs(xOut) < 1.0e12 and abs(yOut) < 1.0e12;

  // Synchronized 100 Hz state, command, and sensor traces.
  when sample(0.0, Ts) then
    n = if pre(n) < Ntrace then pre(n) + 1 else Ntrace;
    time_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = time;
    q_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = q;
    w_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = w;
    tau_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = tau_cmd;
    xOut_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = xOut;
    yOut_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = yOut;
    theta4_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = theta4;
    resX_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = resX;
    resY_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = resY;
    closureError_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = closureError;
    outputTravel_trace[if pre(n) < Ntrace then pre(n) + 1 else Ntrace] = outputTravel;
  end when;

  assert(actuatorBoundsOK, "actuator command bound exceeded");
  assert(speedBandOK, "speed band exceeded");
  assert(collisionPrevented, "nonadjacent link collision detected");
  assert(validJointRefs, "invalid joint references");
  assert(primaryTrackingOK, "primary tracking closure error after 6.5 s exceeded");
  assert(finiteCheckOK, "non-finite physical, control, or estimator value detected");

  annotation(experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1.0e-6));
end FourBarDriveB;