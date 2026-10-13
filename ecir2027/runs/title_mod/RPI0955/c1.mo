model SeaSnakeDockA
  "Reduced-order free-base marine robot: 32 kg articulated underwater snake with 12 bounded joints, docking funnel, cross-current, speed-scheduled pose control and compliant capture"

  // Local constants (avoid scope issues with Modelica.Constants references)
  parameter Real pi = 3.14159265358979;
  parameter Real g = 9.80665 "gravitational acceleration, m/s^2";

  // Physical constants
  parameter Real m = 32.0 "robot mass, kg";
  parameter Real moduleLength = 0.30 "capsule module length, m";
  parameter Integer nModules = 6 "number of capsule modules";
  parameter Integer nJoints = 12 "number of bounded joint actuators";
  parameter Real L = nModules * moduleLength "overall body length, m";
  parameter Real Iz = m * L * L / 12.0 "planar yaw inertia, kg.m^2";
  parameter Real cdrag = 80.0 "linear hydrodynamic drag coefficient, N.s/m";
  parameter Real cyaw = 30.0 "yaw rotational damping, N.m.s/rad";
  parameter Real rho = 1000.0 "water density (typical; exact value not stated)";
  parameter Real depth = 0.0 "operational depth unknown; finite default for pressure sensor";

  // Actuator and control bounds
  parameter Real UjointMax = 23.0 "per-joint command magnitude limit, N.m";
  parameter Real UpropMax = 15.0 "internal propulsion torque bias bound, N.m";
  parameter Real UsteerMax = 5.0 "internal steering torque bias bound, N.m";
  parameter Real Aund = 0.80 "undulation torque amplitude, N.m";
  parameter Real fUnd = 1.20 "undulation frequency, Hz";
  parameter Real vmax = 3.0 "speed bound and scheduled cruise speed, m/s";

  // Docking and compliant capture
  parameter Real rcapture = 0.12 "compliant capture ring radius, m";
  parameter Real kring = 1500.0 "capture ring stiffness, N/m";
  parameter Real dring = 300.0 "capture ring damping, N.s/m";
  parameter Real FcontactLimit = 500.0 "contact force limit, N";
  parameter Real trackingErrorLimit = 0.135 "primary tracking error limit after 5.2 s, m";

  // Scenario timing
  parameter Real T = 8.0 "scenario duration, s";
  parameter Real Ts = 1.0 / 80.0 "control and trace sample period, s";
  parameter Real eps = 1.0e-9 "finite divisor floor";

  // Controller gains
  parameter Real Kp_v = 2.0 "speed-control proportional gain";
  parameter Real Kthrust = 20.0 "thrust force per average joint torque, N/(N.m)";
  parameter Real Kyaw = 12.0 "yaw-control proportional gain, N.m/rad";
  parameter Real Kd_yaw = 3.0 "yaw-control damping gain, N.m.s/rad";
  parameter Real Ksteer2 = 10.0 "steering torque per steering bias, N.m/(N.m)";

  // State variables
  Real x(start = 8.0) "head x position, m";
  Real y(start = 0.0) "head y position, m";
  Real vx(start = 0.0) "head x velocity, m/s";
  Real vy(start = 0.0) "head y velocity, m/s";
  Real theta(start = pi) "heading yaw angle, rad";
  Real omega(start = 0.0) "yaw rate, rad/s";

  Real q[12](each start = 0.0) "joint angles, rad";
  Real qd[12](each start = 0.0) "joint angular velocities, rad/s";
  Real u_cmd[12] "unbounded joint torque commands, N.m";
  Real u_sat[12] "bounded joint torque commands, N.m";
  Real phase[12] "undulation phase per joint, rad";
  parameter Real steerSign[12] = {1,-1,1,-1,1,-1,1,-1,1,-1,1,-1} "alternating steering sign";

  // Discrete controller variables
  discrete Real Uprop_d(start = 12.0) "propulsion torque bias, N.m";
  discrete Real Usteer_d(start = 0.0) "steering torque bias, N.m";
  discrete Real vdes_d(start = 0.0) "scheduled desired speed, m/s";
  discrete Real thetaDes_d(start = pi) "desired heading, rad";
  discrete Real yawErr_d(start = 0.0) "yaw error, rad";
  discrete Real d_meas_d(start = 8.0) "measured distance, m";
  discrete Real speed_meas_d(start = 0.0) "measured speed, m/s";

  // Capture state
  discrete Boolean captured(start = false) "true after compliant capture is established";
  discrete Real captureTime(start = 0.0) "time of first capture, s";

  // Derived quantities
  Real d "distance to docking funnel center, m";
  Real speedOut "measured speed magnitude, m/s";
  Real speedSafe "speed magnitude with finite floor, m/s";
  Real nx "safe radial unit x component";
  Real ny "safe radial unit y component";
  Real vradial "radial velocity, m/s";
  Real Uavg "average bounded joint torque, N.m";
  Real FthrustRaw "raw propulsion force, N";
  Real Fthrust "limited propulsion force, N";
  Real FcurrentY "cross-current force, N";
  Real Fring "compliant capture ring force magnitude, N";
  Real FcapX "capture force x component, N";
  Real FcapY "capture force y component, N";
  Real Fx "total x force on robot, N";
  Real Fy "total y force on robot, N";
  Real Tyaw "total yaw torque, N.m";
  Real ax "x acceleration, m/s^2";
  Real ay "y acceleration, m/s^2";

  // Observable outputs
  output Real trackingError "primary radial tracking error, m";
  output Real contactForce "compliant capture contact force magnitude, N";
  output Real speedOutY "speed magnitude trace, m/s";
  output Real yawErrorOut "absolute yaw error, rad";
  output Real lateralErrorOut "lateral error y, m";
  output Real captureFlagOut "capture flag as Real, 1.0 captured";
  output Real sonarRangeOut "sonar range to dock, m";
  output Real pressureOut "pressure sensor reading, Pa";
  output Real imuOmegaOut "IMU yaw rate, rad/s";
  output Real imuAxOut "IMU x acceleration, m/s^2";
  output Real imuAyOut "IMU y acceleration, m/s^2";
  output Real optValidOut "short-range optical pose valid flag as Real";
  output Real optXOut "optical pose x, m";
  output Real optYOut "optical pose y, m";
  output Real optThetaOut "optical pose theta, rad";
  output Real UpropOut "propulsion torque bias trace, N.m";
  output Real UsteerOut "steering torque bias trace, N.m";
  output Real vdesOut "scheduled desired speed trace, m/s";

algorithm
  when sample(0, Ts) then
    // Measurements
    d_meas_d := max(sqrt(x * x + y * y), eps);
    speed_meas_d := max(sqrt(vx * vx + vy * vy), eps);

    // Capture event
    if d_meas_d <= rcapture and not pre(captured) then
      captured := true;
      captureTime := time;
    else
      captured := pre(captured);
      captureTime := pre(captureTime);
    end if;

    // Speed-scheduled pose control
    if captured then
      vdes_d := 0.0;
      Uprop_d := 0.0;
      Usteer_d := 0.0;
      thetaDes_d := pre(thetaDes_d);
    else
      if d_meas_d > 1.0 then
        vdes_d := vmax;
      else
        vdes_d := vmax * d_meas_d;
      end if;

      if d_meas_d > 1.0e-6 then
        thetaDes_d := atan2(-y, -x);
      else
        thetaDes_d := pre(thetaDes_d);
      end if;

      Uprop_d := max(-UpropMax, min(UpropMax, cdrag * vdes_d / Kthrust + Kp_v * (vdes_d - speed_meas_d)));
      Usteer_d := max(-UsteerMax, min(UsteerMax, Kyaw * (atan2(sin(thetaDes_d - theta), cos(thetaDes_d - theta))) - Kd_yaw * omega));
    end if;

    yawErr_d := atan2(sin(thetaDes_d - theta), cos(thetaDes_d - theta));
  end when;

equation
  // Safe norms and directions
  d = max(sqrt(x * x + y * y), eps);
  speedOut = sqrt(vx * vx + vy * vy);
  speedSafe = max(speedOut, eps);
  nx = if d > 1.0e-6 then x / d else 1.0;
  ny = if d > 1.0e-6 then y / d else 0.0;
  vradial = if d > 1.0e-6 then (x * vx + y * vy) / d else vx;

  // Joint undulation and bounded actuator commands
  for i in 1:12 loop
    phase[i] = 2.0 * pi * (i - 1) / 12.0;
    u_cmd[i] = Uprop_d + Usteer_d * steerSign[i] + Aund * sin(2.0 * pi * fUnd * time + phase[i]);
    u_sat[i] = if u_cmd[i] > UjointMax then UjointMax else if u_cmd[i] < -UjointMax then -UjointMax else u_cmd[i];
  end for;

  // Explicit scalar average to avoid array reduction ambiguity
  Uavg = (u_sat[1] + u_sat[2] + u_sat[3] + u_sat[4] + u_sat[5] + u_sat[6] +
          u_sat[7] + u_sat[8] + u_sat[9] + u_sat[10] + u_sat[11] + u_sat[12]) / 12.0;

  // Propulsion force with speed bound
  FthrustRaw = Kthrust * Uavg;
  Fthrust = if speedOut > vmax and FthrustRaw > 0.0 then 0.0 else FthrustRaw;

  // Cross-current disturbance during middle third of scenario
  FcurrentY = if time >= T / 3.0 and time <= 2.0 * T / 3.0 then 70.0 else 0.0;

  // Compliant capture ring: bilateral spring-damper about rcapture after capture
  Fring = if captured then (kring * (rcapture - d) - dring * vradial) else 0.0;
  FcapX = Fring * nx;
  FcapY = Fring * ny;

  // Rigid body planar dynamics
  Fx = Fthrust * cos(theta) + FcapX - cdrag * vx;
  Fy = Fthrust * sin(theta) + FcurrentY + FcapY - cdrag * vy;
  Tyaw = Ksteer2 * Usteer_d;

  ax = Fx / m;
  ay = Fy / m;

  der(x) = vx;
  der(y) = vy;
  der(vx) = ax;
  der(vy) = ay;
  der(theta) = omega;
  der(omega) = (Tyaw - cyaw * omega) / Iz;

  // Joint dynamics (yaw and pitch joints represented; pitch joints do not affect planar approach in this reduced model)
  for i in 1:12 loop
    der(q[i]) = qd[i];
    der(qd[i]) = (u_sat[i] - 0.2 * qd[i]) / 0.05;
  end for;

  // Sensor and trace outputs
  trackingError = d;
  contactForce = abs(Fring);
  speedOutY = speedOut;
  yawErrorOut = abs(atan2(sin(thetaDes_d - theta), cos(thetaDes_d - theta)));
  lateralErrorOut = y;
  captureFlagOut = if captured then 1.0 else 0.0;
  sonarRangeOut = d;
  pressureOut = rho * g * depth;
  imuOmegaOut = omega;
  imuAxOut = ax;
  imuAyOut = ay;
  optValidOut = if d < 1.0 then 1.0 else 0.0;
  optXOut = if optValidOut > 0.5 then x else 0.0;
  optYOut = if optValidOut > 0.5 then y else 0.0;
  optThetaOut = if optValidOut > 0.5 then theta else 0.0;
  UpropOut = Uprop_d;
  UsteerOut = Usteer_d;
  vdesOut = vdes_d;

  annotation(
    experiment(StopTime = 8.0, Tolerance = 1e-4, Interval = 0.0125),
    Documentation(info = "Standalone plant with embedded 80 Hz controller. Unknown facts (e.g. exact depth, hydrodynamic coefficients, detailed joint kinematics) are bound to finite defaults and labeled; no external unbound parameters are introduced."));
end SeaSnakeDockA;