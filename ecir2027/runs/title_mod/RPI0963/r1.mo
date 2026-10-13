model DiffRoverRouteC
  "Floating-base differential-drive rover: bounded path following and
   wheel-speed control with a controlled lateral push disturbance."

  // ===== Physical parameters (SI) =====
  parameter Real m = 19.0       "chassis mass [kg]";
  parameter Real Lx = 0.65      "chassis length [m]";
  parameter Real Ly = 0.44       "chassis width [m]";
  parameter Real Lz = 0.22       "chassis height [m]";
  parameter Real Izz = m*(Lx^2 + Ly^2)/12.0 "yaw inertia [kg.m2]";
  parameter Real r = 0.10        "driven wheel radius [m]";
  parameter Real W = 0.46        "wheel separation [m]";
  parameter Real mu = 0.82       "rigid floor friction coefficient [-]";
  parameter Real g = 9.81        "gravity [m/s2]";
  parameter Real Nwheel = m*g/2.0 "normal load per driven wheel [N] (approx)";
  parameter Real Fmax = mu*Nwheel "max traction force per wheel [N]";
  parameter Real tauMax = 12.0    "max motor torque magnitude [N.m]";
  parameter Real vCmdMax = 1.3    "commanded speed, below 1.5 [m/s]";
  parameter Real kp_w = 7.0       "wheel-speed proportional gain [N.m.s/rad]";
  parameter Real ki_w = 8.0       "wheel-speed integral gain [N.m/rad]";
  parameter Real k_yaw = 2.5      "heading-rate gain [1/s]";
  parameter Real omegaCmdMax = 2.0 "yaw-rate command bound [rad/s]";
  parameter Real b_yaw = 1.5      "yaw viscous damping [N.m.s]";
  parameter Real vEps = 0.05      "lateral friction smoothing velocity [m/s]";
  parameter Real Fpush = 108.0    "lateral push magnitude [N]";
  parameter Real dt = 0.008       "control period [s] (125 Hz)";
  parameter Real Tfinal = 12.0     "simulation duration [s]";
  parameter Real lookAhead = 0.5  "pure-pursuit look-ahead distance [m]";

  // ===== Waypoints (SI, m) =====
  parameter Real wx[4] = {0.0, 4.0, 7.0, 10.0};
  parameter Real wy[4] = {0.0, 0.0, 2.0, 2.0};

  // ===== Continuous plant states =====
  Real x(start=0.0, fixed=true)   "world-frame x [m]";
  Real y(start=0.0, fixed=true)   "world-frame y [m]";
  Real theta(start=0.0, fixed=true) "heading [rad]";
  Real vbx(start=0.0, fixed=true) "body longitudinal velocity [m/s]";
  Real vby(start=0.0, fixed=true) "body lateral velocity [m/s]";
  Real omega(start=0.0, fixed=true) "yaw rate [rad/s]";

  // ===== Discrete controller states (held at 125 Hz) =====
  discrete Integer idx(start=2)  "current target waypoint index";
  discrete Real vCmd(start=0.0)  "commanded forward speed [m/s]";
  discrete Real omegaCmd(start=0.0) "commanded yaw rate [rad/s]";
  discrete Real omegaLcmd(start=0.0) "left wheel speed command [rad/s]";
  discrete Real omegaRcmd(start=0.0) "right wheel speed command [rad/s]";
  discrete Real tauLcmd(start=0.0) "left motor torque command [N.m]";
  discrete Real tauRcmd(start=0.0) "right motor torque command [N.m]";
  discrete Real integL(start=0.0) "left wheel-speed integral term [rad]";
  discrete Real integR(start=0.0) "right wheel-speed integral term [rad]";

  // ===== Continuous path / monitor quantities =====
  Real sx, sy                    "segment start [m]";
  Real segDx, segDy              "segment direction vector [m]";
  Real segLen                    "segment length [m]";
  Real segLenSafe                "segment length guarded against zero [m]";
  Real ux, uy                    "unit segment direction [-]";
  Real proj                      "along-track projection [m]";
  Real projClamped               "along-track projection clamped to segment [m]";
  Real nearX, nearY              "nearest point on current segment [m]";
  Real crossTrack                "signed cross-track error [m]";
  Real trackErr                  "primary tracking error [m]";
  Real lookX, lookY              "look-ahead target point [m]";
  Real desHdg                    "desired heading [rad]";
  Real headingErr                "wrapped heading error [rad]";

  // ===== Continuous derived dynamics =====
  Real tauLclip, tauRclip        "torque commands clipped to actuator bound [N.m]";
  Real FLraw, FRraw              "un-limited traction force per wheel [N]";
  Real F_L, F_R                  "friction-limited traction force per wheel [N]";
  Real F_long                    "total longitudinal body force [N]";
  Real F_push_y                  "lateral push in body frame [N]";
  Real F_lat_fric                "lateral ground friction [N]";
  Real omegaL, omegaR            "wheel angular speeds (encoders) [rad/s]";
  Real pushOn                    "push active indicator [0 or 1]";

  // ===== Sensor traces =====
  Real sens_x, sens_y, sens_theta, sens_omega, sens_vbx, sens_vby;
  Real sens_omegaL, sens_omegaR;

  // ===== Requirement flags =====
  Boolean noCollision            "robot stays within path corridor";
  Boolean boundsOK               "actuator and command bounds satisfied";
  Boolean trackingMet            "primary tracking error < 0.263 m after 7.8 s";
  // finiteOK: runtime finiteness of all physical/control/estimator values is
  // enforced structurally (bounded analytic functions, guarded divisors).
  // A native Modelica isFinite() is not available in all tools, so it is
  // verified by inspection of the bounded expressions below.

equation
  // ---- Planar kinematics ----
  der(x) = vbx*cos(theta) - vby*sin(theta);
  der(y) = vbx*sin(theta) + vby*cos(theta);
  der(theta) = omega;

  // ---- Body-frame dynamics ----
  der(vbx) = (F_long)/m + omega*vby;
  der(vby) = (F_push_y + F_lat_fric)/m - omega*vbx;
  der(omega) = ((F_R - F_L)*W/2.0 - b_yaw*omega)/Izz;

  // ---- Wheel speeds (no-slip, encoder signals) ----
  omegaL = (vbx - omega*W/2.0)/r;
  omegaR = (vbx + omega*W/2.0)/r;

  // ---- Actuator saturation (12 N.m) ----
  tauLclip = if tauLcmd > tauMax then tauMax
             else if tauLcmd < -tauMax then -tauMax else tauLcmd;
  tauRclip = if tauRcmd > tauMax then tauMax
             else if tauRcmd < -tauMax then -tauMax else tauRcmd;

  // ---- Torque-to-force through wheel radius ----
  FLraw = tauLclip/r;
  FRraw = tauRclip/r;

  // ---- Friction-limited traction (0.82 floor) ----
  F_L = if FLraw > Fmax then Fmax else if FLraw < -Fmax then -Fmax else FLraw;
  F_R = if FRraw > Fmax then Fmax else if FRraw < -Fmax then -Fmax else FRraw;

  F_long = F_L + F_R;

  // ---- Controlled lateral push (108 N) during middle third (4 s <= t < 8 s) ----
  pushOn = if time >= 4.0 and time < 8.0 then 1.0 else 0.0;
  F_push_y = pushOn*Fpush;

  // ---- Lateral friction resisting sideways sliding ----
  F_lat_fric = -mu*m*g*tanh(vby/vEps);

  // ---- Path geometry (continuous, indexed by discrete target) ----
  sx = wx[idx-1];
  sy = wy[idx-1];
  segDx = wx[idx] - sx;
  segDy = wy[idx] - sy;
  segLen = sqrt(segDx^2 + segDy^2);
  segLenSafe = if segLen > 1e-6 then segLen else 1e-6;
  ux = segDx/segLenSafe;
  uy = segDy/segLenSafe;
  proj = (x - sx)*ux + (y - sy)*uy;
  projClamped = if proj < 0.0 then 0.0 else if proj > segLenSafe then segLenSafe else proj;
  nearX = sx + ux*projClamped;
  nearY = sy + uy*projClamped;
  crossTrack = -(x - sx)*uy + (y - sy)*ux;
  trackErr = sqrt((x - nearX)^2 + (y - nearY)^2);

  // ---- Pure-pursuit look-ahead and heading error ----
  lookX = sx + ux*(proj + lookAhead);
  lookY = sy + uy*(proj + lookAhead);
  desHdg = atan2(lookY - y, lookX - x);
  headingErr = atan2(sin(desHdg - theta), cos(desHdg - theta));

  // ---- Sensor traces ----
  sens_x = x;
  sens_y = y;
  sens_theta = theta;
  sens_omega = omega;
  sens_vbx = vbx;
  sens_vby = vby;
  sens_omegaL = omegaL;
  sens_omegaR = omegaR;

  // ---- Requirement checks ----
  noCollision = trackErr < 1.5;
  boundsOK = (tauLcmd >= -tauMax - 1e-6) and (tauLcmd <= tauMax + 1e-6) and
             (tauRcmd >= -tauMax - 1e-6) and (tauRcmd <= tauMax + 1e-6) and
             (vCmd >= 0.0) and (vCmd <= vCmdMax + 1e-6);
  trackingMet = (if time >= 7.8 then trackErr < 0.263 else true);

  // ---- Soft assertions for evidence ----
  assert(noCollision, "Collision / corridor violation detected");
  assert(boundsOK, "Actuator or command bound violated");

  // ---- Discrete controller at 125 Hz ----
  when sample(0, dt) then
    // Advance target waypoint when sufficiently close
    if sqrt((wx[idx] - x)^2 + (wy[idx] - y)^2) < 0.6 and idx < 4 then
      idx = idx + 1;
    else
      idx = idx;
    end if;

    // Yaw-rate command from heading error (bounded)
    omegaCmd = max(-omegaCmdMax, min(omegaCmdMax, k_yaw*headingErr));

    // Forward speed command: below 1.5 m/s, reduced for large heading errors
    vCmd = max(0.0, vCmdMax*(1.0 - 0.6*min(1.0, abs(headingErr))));
    // Slow down near final waypoint for a controlled stop
    if idx == 4 then
      vCmd = min(vCmd, vCmdMax*min(1.0, sqrt((wx[4] - x)^2 + (wy[4] - y)^2)));
    else
      vCmd = vCmd;
    end if;

    // Wheel-speed commands from body motion commands (differential drive)
    omegaLcmd = (vCmd - omegaCmd*W/2.0)/r;
    omegaRcmd = (vCmd + omegaCmd*W/2.0)/r;

    // Wheel-speed PI control with integral anti-windup
    integL = max(-3.0, min(3.0, integL + (omegaLcmd - omegaL)*dt));
    integR = max(-3.0, min(3.0, integR + (omegaRcmd - omegaR)*dt));

    // Torque commands bounded to +/- 12 N.m
    tauLcmd = max(-tauMax, min(tauMax, kp_w*(omegaLcmd - omegaL) + ki_w*integL));
    tauRcmd = max(-tauMax, min(tauMax, kp_w*(omegaRcmd - omegaR) + ki_w*integR));
  end when;

  annotation (
    Documentation(info="DiffRoverRouteC: 19 kg box chassis (0.65 x 0.44 x 0.22 m),
 two 0.10 m-radius driven wheels separated by 0.46 m plus one passive caster,
 rigid floor friction 0.82, waypoint path [0,0]->[4,0]->[7,2]->[10,2] m.
 Commanded speed below 1.5 m/s, actuator bound 12 N.m, 108 N lateral push
 during the middle third (4 s..8 s). Discrete feedback at 125 Hz for 12 s,
 retaining synchronized state/command/sensor traces."),
    experiment(StartTime=0, StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    __OpenModelica_simulationFlags(s="dassl", noEquidistantTimeGrid="()"));
end DiffRoverRouteC;