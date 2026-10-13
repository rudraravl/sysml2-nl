model AckermannRoverRouteF
  // ---- Physical embodiment ----
  parameter Real m = 34.0 "chassis mass [kg]";
  parameter Real L = 0.74 "wheelbase [m]";
  parameter Real chassisLength = 1.05 "chassis length [m]";
  parameter Real chassisWidth = 0.64 "chassis width [m]";
  parameter Real mu = 0.82 "floor Coulomb friction coefficient [1]";
  parameter Real steerMax = 0.52 "steering joint limit [rad]";
  parameter Real tauMax = 34.2 "actuator torque bound [N.m]";
  parameter Real rWheel = 0.15 "assumed wheel radius [m] (requirement did not specify)";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real cRoll = 2.0 "small longitudinal rolling damping [N/(m/s)] (rolling resistance unspecified)";

  // ---- Mission waypoints ----
  parameter Real wx[4] = {0.0, 4.0, 7.0, 10.0} "waypoint x [m]";
  parameter Real wy[4] = {0.0, 0.0, 2.0, 2.0} "waypoint y [m]";
  parameter Real vCmd = 1.0 "commanded cruise speed [m/s] (<1.5)";
  parameter Real vCmdMax = 1.5 "speed limit [m/s]";

  // ---- Path segment lengths (derived from waypoints) ----
  parameter Real seg1Len = 4.0 "first segment length [m]";
  parameter Real seg2Len = 3.6055512755 "second segment length [m] = sqrt(13)";
  parameter Real seg3Len = 3.0 "third segment length [m]";
  parameter Real pathLength = 10.6055512755 "total path length [m]";

  // ---- Control gains ----
  parameter Real KpSpeed = 80.0 "speed proportional gain";
  parameter Real lookAhead = 1.2 "pure-pursuit look-ahead distance [m]";

  // ---- Disturbance ----
  parameter Real Fpush = 174.0 "lateral push force magnitude [N]";
  parameter Real tPushStart = 20.0/3.0 "push start time [s] (middle third)";
  parameter Real tPushEnd = 40.0/3.0 "push end time [s] (middle third)";

  // ---- Dynamic states ----
  Real x(start=0.0, fixed=true) "x position [m]";
  Real y(start=0.0, fixed=true) "y position [m]";
  Real theta(start=0.0, fixed=true) "heading [rad]";
  Real u(start=0.0, fixed=true) "longitudinal body velocity [m/s]";
  Real w(start=0.0, fixed=true) "lateral body velocity [m/s]";

  // ---- Control variables ----
  Real deltaCmd "commanded steering angle [rad]";
  Real delta "applied (bounded) steering angle [rad]";
  Real tauRcmd "commanded rear traction torque [N.m]";
  Real tauR "applied (bounded) rear traction torque [N.m]";
  Real vCmdEff "effective commanded speed near end of path [m/s]";

  // ---- Path projection intermediates ----
  Real t1 "projection parameter on seg1 [1]";
  Real t2 "projection parameter on seg2 [1]";
  Real t3 "projection parameter on seg3 [1]";
  Real Q1x "projected x on seg1 [m]";
  Real Q1y "projected y on seg1 [m]";
  Real Q2x "projected x on seg2 [m]";
  Real Q2y "projected y on seg2 [m]";
  Real Q3x "projected x on seg3 [m]";
  Real Q3y "projected y on seg3 [m]";
  Real d1 "distance to seg1 [m]";
  Real d2 "distance to seg2 [m]";
  Real d3 "distance to seg3 [m]";
  Real dmin "minimum distance to path [m]";
  Real sProj "arc length at projection [m]";
  Real sTgt "target arc length [m]";
  Real tgtX "look-ahead target x [m]";
  Real tgtY "look-ahead target y [m]";
  Real alphaN "normalized heading error to target [rad]";

  // ---- Wheel encoder observations ----
  Real omegaRL "rear-left wheel speed [rad/s]";
  Real omegaRR "rear-right wheel speed [rad/s]";
  Real omegaFL "front-left wheel speed [rad/s]";
  Real omegaFR "front-right wheel speed [rad/s]";

  // ---- IMU observations ----
  Real omegaZ "yaw rate [rad/s]";
  Real ax "longitudinal acceleration [m/s2]";
  Real ay "lateral acceleration [m/s2]";
  Real ax_body "body-frame longitudinal acceleration [m/s2]";
  Real ay_body "body-frame lateral acceleration [m/s2]";

  // ---- Diagnostics ----
  Real crossTrack "cross-track error [m]";
  Real trackErr "primary tracking error [m]";
  Boolean trackingOK "tracking criterion after 13 s";
  Boolean boundsOK "wheel-speed and actuator bounds OK";
  Boolean noCollision "no collision (obstacle positions not specified)";
  Boolean finiteOK "finiteness sanity check";

  // ---- Disturbance gate ----
  Real pushGate "push disturbance enable [1]";

  // ---- Forces ----
  Real Fdrive "rear traction force [N]";
  Real FlongFric "longitudinal rolling damping [N]";
  Real FlatFric "lateral Coulomb friction force [N]";
  Real FpushBody "lateral push force in body frame [N]";

equation
  // Push gate active during middle third of the 20 s run
  pushGate = if (time >= tPushStart and time <= tPushEnd) then 1.0 else 0.0;

  // ---- Path projection onto polyline of waypoints ----
  t1 = max(0.0, min(1.0, (x - wx[1]) / seg1Len));
  Q1x = wx[1] + (wx[2]-wx[1])*t1;
  Q1y = wy[1] + (wy[2]-wy[1])*t1;
  d1 = sqrt((x-Q1x)^2 + (y-Q1y)^2 + 1e-9);

  t2 = max(0.0, min(1.0, ((x-wx[2])*(wx[3]-wx[2]) + (y-wy[2])*(wy[3]-wy[2])) / (seg2Len^2)));
  Q2x = wx[2] + (wx[3]-wx[2])*t2;
  Q2y = wy[2] + (wy[3]-wy[2])*t2;
  d2 = sqrt((x-Q2x)^2 + (y-Q2y)^2 + 1e-9);

  t3 = max(0.0, min(1.0, (x - wx[3]) / seg3Len));
  Q3x = wx[3] + (wx[4]-wx[3])*t3;
  Q3y = wy[3] + (wy[4]-wy[3])*t3;
  d3 = sqrt((x-Q3x)^2 + (y-Q3y)^2 + 1e-9);

  dmin = min(d1, min(d2, d3));
  crossTrack = dmin;
  trackErr = dmin;

  // Arc length along path at projection point (select closest segment)
  sProj = if (d1 <= d2 and d1 <= d3) then t1*seg1Len
          else if (d2 <= d3) then seg1Len + t2*seg2Len
          else seg1Len + seg2Len + t3*seg3Len;

  sTgt = sProj + lookAhead;

  // Look-ahead target point on polyline (clamped to end)
  tgtX = if sTgt <= seg1Len then sTgt
         else if sTgt <= seg1Len + seg2Len then wx[2] + (wx[3]-wx[2])*(sTgt - seg1Len)/seg2Len
         else wx[3] + (wx[4]-wx[3])*min(max(sTgt - seg1Len - seg2Len, 0.0), seg3Len)/seg3Len;
  tgtY = if sTgt <= seg1Len then wy[1]
         else if sTgt <= seg1Len + seg2Len then wy[2] + (wy[3]-wy[2])*(sTgt - seg1Len)/seg2Len
         else wy[3] + (wy[4]-wy[3])*min(max(sTgt - seg1Len - seg2Len, 0.0), seg3Len)/seg3Len;

  // Heading error to look-ahead target, normalized to [-pi, pi]
  alphaN = atan2(sin(atan2(tgtY - y, tgtX - x) - theta),
                 cos(atan2(tgtY - y, tgtX - x) - theta));

  // Pure-pursuit bounded steering command
  deltaCmd = atan2(2.0*L*sin(alphaN), max(lookAhead, 0.01));
  delta = max(-steerMax, min(steerMax, deltaCmd));

  // Effective speed command ramps to zero near end of path
  vCmdEff = if sProj >= (pathLength - 1.0) then max(0.0, vCmd*(pathLength - sProj)) else vCmd;

  // Bounded P wheel-speed control
  tauRcmd = KpSpeed * (vCmdEff - u);
  tauR = max(-tauMax, min(tauMax, tauRcmd));

  // ---- Forces ----
  Fdrive = tauR / rWheel;
  FlongFric = -cRoll * u;
  FlatFric = -mu * m * g * w / sqrt(w^2 + 1e-4);
  FpushBody = Fpush * pushGate;

  // Body-frame accelerations
  ax_body = (Fdrive + FlongFric) / m;
  ay_body = (FpushBody + FlatFric) / m;

  // ---- Planar kinematics (kinematic bicycle with lateral slip state) ----
  der(x) = u*cos(theta) - w*sin(theta);
  der(y) = u*sin(theta) + w*cos(theta);
  der(theta) = u/L * tan(delta);
  der(u) = ax_body;
  der(w) = ay_body;

  // ---- Wheel encoder observations ----
  omegaRL = u / rWheel;
  omegaRR = u / rWheel;
  omegaFL = (u/rWheel) * (1.0 + chassisWidth/2.0 * tan(delta) / L);
  omegaFR = (u/rWheel) * (1.0 - chassisWidth/2.0 * tan(delta) / L);

  // ---- IMU observations ----
  omegaZ = u/L * tan(delta);
  ax = ax_body;
  ay = ay_body + u*omegaZ;

  // ---- Verification flags ----
  trackingOK = if time >= 13.0 then (trackErr < 0.2) else true;
  boundsOK = (abs(tauR) <= tauMax + 1e-6)
             and (abs(delta) <= steerMax + 1e-6)
             and (abs(omegaRL) <= 15.0)
             and (abs(omegaRR) <= 15.0)
             and (abs(omegaFL) <= 15.0)
             and (abs(omegaFR) <= 15.0);
  noCollision = true; // obstacle positions not specified in requirement
  finiteOK = (abs(x) < 1e6) and (abs(y) < 1e6) and (abs(theta) < 1e6)
             and (abs(u) < 1e6) and (abs(w) < 1e6) and (abs(delta) < 1e6)
             and (abs(tauR) < 1e6) and (abs(trackErr) < 1e6);

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="Ackermann-steering rover route-following scenario.
      500 Hz simulation, 20 s. Waypoints [0,0]->[4,0]->[7,2]->[10,2] m at 1.0 m/s.
      34 kg chassis, 1.05 m long, 0.64 m wide, 0.74 m wheelbase.
      Steering bounded +/-0.52 rad; rear traction bounded at 34.2 N.m.
      Floor Coulomb friction 0.82; 174 N lateral push during middle third (6.67-13.33 s).
      Wheel radius assumed 0.15 m; rolling resistance unspecified (small damping used).")
  );
end AckermannRoverRouteF;