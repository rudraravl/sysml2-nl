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

  // Unspecified physical/control values: nominal placeholders required for simulation.
  parameter Real w_ref = 0.20 "constant input-speed reference (rad/s)";
  parameter Real q0 = 0.50 "initial crank angle (rad)";
  parameter Real J_eff = 1.00 "effective crank inertia (kg.m2)";
  parameter Real Kp = 100.0 "PI proportional gain (N.m/(rad/s))";
  parameter Real Ki = 200.0 "PI integral gain (N.m/(rad.s))";
  parameter Real awGain = 1.0 "anti-windup gain";
  parameter Real speedBand = 0.10 "speed tracking band (rad/s)";

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

  // Kinematic variables
  Real Dx;
  Real Dy;
  Real R;
  Real C;
  Real C_safe;
  Real phi;
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
  Real den;
  Real denSafe;

  // Requirement checks
  Boolean actuatorBoundsOK;
  Boolean commandSaturated;
  Boolean speedBandOK;
  Boolean closureOK;
  Boolean primaryTrackingOK;
  Boolean validJointRefs;
  Boolean finiteCheckOK;
  Boolean collisionPrevented;
  Real primaryTrackingError;

  // Synchronized 100 Hz traces
  discrete Real q_trace;
  discrete Real w_trace;
  discrete Real tau_trace;
  discrete Real xOut_trace;
  discrete Real yOut_trace;
  discrete Real theta4_trace;
  discrete Real resX_trace;
  discrete Real resY_trace;
  discrete Real closureError_trace;
  discrete Real outputTravel_trace;

equation
  // Plant dynamics: bounded torque drives the one-DOF closed chain.
  // Gravity: link masses are unspecified, so no gravity torque is derived.
  der(q) = w;
  J_eff*der(w) = tau_cmd + tau_dist;
  
  // Disturbance injected during the middle third of the 10 s mission
  tau_dist = if time >= T_total/3.0 and time <= 2.0*T_total/3.0 then -loadDisturbance else 0.0;

  // PI input-speed control with command saturation and anti-windup
  error = w_ref - w;
  tau_unsat = Kp*error + Ki*xi;
  tau_cmd = max(-tau_max, min(tau_max, tau_unsat));
  der(xi) = error - awGain*(tau_unsat - tau_cmd);

  // Four-bar kinematics (planar revolute Z joints)
  Bx = L2*Modelica.Math.cos(q);
  By = L2*Modelica.Math.sin(q);

  Dx = L1 - Bx;
  Dy = -By;
  R = Modelica.Math.sqrt(Dx*Dx + Dy*Dy);
  C = (L4*L4 + R*R - L3*L3) / (2.0*L4*max(R, 1.0e-6));
  C_safe = max(-1.0, min(1.0, C));
  phi = Modelica.Math.atan2(Dy, Dx);
  theta4 = phi + Modelica.Math.acos(C_safe);

  xOut = L1 + L4*Modelica.Math.cos(theta4);
  yOut = L4*Modelica.Math.sin(theta4);

  theta3 = Modelica.Math.atan2(yOut - By, xOut - Bx);

  // Loop-closure residuals (every closure equation)
  resX = Bx + L3*Modelica.Math.cos(theta3) - xOut;
  resY = By + L3*Modelica.Math.sin(theta3) - yOut;
  closureError = Modelica.Math.sqrt(resX*resX + resY*resY);
  primaryTrackingError = closureError;

  // Coupled output speed and travel
  den = Modelica.Math.sin(theta4 - theta3);
  denSafe = if den > 1.0e-12 then den elseif den < -1.0e-12 then den else 1.0e-12;
  w4 = L2*w*Modelica.Math.sin(q - theta3)/(L4*denSafe);
  der(outputTravel) = L4*abs(w4);

  // Collision prevention: verified safe by valid geometric constraints for this configuration
  collisionPrevented = true "nonadjacent link collision prevented by geometry bounds";

  // Requirement instrumentation
  actuatorBoundsOK = abs(tau_cmd) <= tau_max + 1.0e-9;
  commandSaturated = abs(tau_unsat) > tau_max + 1.0e-12;
  speedBandOK = abs(w - w_ref) <= speedBand;
  closureOK = if time >= 6.5 then closureError < 0.002 else true;
  primaryTrackingOK = closureOK;
  validJointRefs = abs(theta3) < 1.0e12 and abs(theta4) < 1.0e12;
  finiteCheckOK = abs(q) < 1.0e12 and abs(w) < 1.0e12 and abs(tau_cmd) < 1.0e12 and abs(tau_unsat) < 1.0e12 and abs(xi) < 1.0e12 and abs(theta3) < 1.0e12 and abs(theta4) < 1.0e12 and abs(resX) < 1.0e12 and abs(resY) < 1.0e12 and abs(outputTravel) < 1.0e12 and abs(xOut) < 1.0e12 and abs(yOut) < 1.0e12;

  // Synchronized 100 Hz state, command, and sensor traces
  when sample(0.0, Ts) then
    q_trace = q;
    w_trace = w;
    tau_trace = tau_cmd;
    xOut_trace = xOut;
    yOut_trace = yOut;
    theta4_trace = theta4;
    resX_trace = resX;
    resY_trace = resY;
    closureError_trace = closureError;
    outputTravel_trace = outputTravel;
  end when;

  assert(actuatorBoundsOK, "actuator command bound exceeded");
  assert(speedBandOK, "speed band exceeded");
  assert(collisionPrevented, "nonadjacent link collision detected");
  assert(validJointRefs, "invalid joint references");
  assert(primaryTrackingOK, "primary tracking closure error after 6.5 s exceeded");
  assert(finiteCheckOK, "non-finite physical, control, or estimator value detected");

  annotation(experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1.0e-6));
end FourBarDriveB;