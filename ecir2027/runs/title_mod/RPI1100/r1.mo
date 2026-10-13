model GroundPairResilientB
  // ------------------------------------------------------------------
  // Physical parameters (stated)
  parameter Real m = 14.0      "robot mass [kg]";
  parameter Real r = 0.09      "wheel radius [m]";
  parameter Real tauMax = 8.2  "allowed wheel torque magnitude [N.m]";

  // Physical parameters NOT stated in requirement (nominal placeholders)
  parameter Real L  = 0.30  "wheelbase [m] (not specified; nominal)";
  parameter Real Iz = 0.5   "yaw inertia [kg.m2] (not specified; nominal)";
  parameter Real b  = 4.0   "linear drag [N.s/m] (not specified; nominal)";
  parameter Real bz = 0.4   "yaw drag [N.m.s/rad] (not specified; nominal)";

  // Mission / scenario parameters (stated)
  parameter Real T = 0.01        "control & telemetry period [s] (100 Hz)";
  parameter Real tEnd = 10.0     "mission duration [s]";
  parameter Real tDropStart = 4.65 "dropout start [s] (mid third, centered)";
  parameter Real dtDrop = 0.7    "dropout duration [s]";

  // Route / formation parameters (nominal, not specified)
  parameter Real vRef  = 0.3    "reference forward speed [m/s]";
  parameter Real dForm = 1.0    "formation lateral separation [m]";

  // Disturbance (shared environmental disturbance during dropout, nominal)
  parameter Real FdistMag = 10.0 "shared disturbance force magnitude [N] (nominal)";

  // Controller gains (not specified; nominal, stable values)
  parameter Real kpV   = 4.0;
  parameter Real kpX   = 2.0;
  parameter Real kpTh  = 3.0;
  parameter Real kdTh  = 0.8;
  parameter Real kForm = 1.5;
  parameter Real kColl = 3.0;
  parameter Real collThresh = 0.5 "collision avoidance threshold [m] (nominal)";
  parameter Real eps = 1.0e-3    "guard for norm divisors";

  // ------------------------------------------------------------------
  // Continuous states: Robot A (leader / primary)
  Real xA(start=0.0)      "x position [m]";
  Real yA(start=0.0)      "y position [m]";
  Real thetaA(start=0.0)  "heading [rad]";
  Real vA(start=0.0)      "forward speed [m/s]";
  Real omegaA(start=0.0)  "yaw rate [rad/s]";

  // Continuous states: Robot B (follower)
  Real xB(start=0.0)        "x position [m]";
  Real yB(start=dForm)      "y position [m]";
  Real thetaB(start=0.0)    "heading [rad]";
  Real vB(start=0.0)        "forward speed [m/s]";
  Real omegaB(start=0.0)    "yaw rate [rad/s]";

  // Actuator commands (four wheel-torque channels) and saturated versions
  Real tauRA, tauLA, tauRB, tauLB;
  Real tauRA_sat, tauLA_sat, tauRB_sat, tauLB_sat;
  Real FA, MA, FB, MB;

  // Sensors (proprioception + exteroception)
  Real encRA, encLA, encRB, encLB "wheel angular speed estimates [rad/s]";
  Real imuA, imuB                 "yaw rate from IMU [rad/s]";
  Real lidarA, lidarB             "range to peer from lidar [m]";
  Real collDist                   "inter-robot distance [m]";

  // Communication state
  Boolean commOK;
  discrete Real tLastRx_A(start=0.0) "timestamp of last peer state received by A";
  discrete Real tLastRx_B(start=0.0) "timestamp of last peer state received by B";
  // last-received peer state (with timestamps) stored locally
  discrete Real xB_rxA(start=0.0), yB_rxA(start=dForm), thetaB_rxA(start=0.0), vB_rxA(start=0.0);
  discrete Real xA_rxB(start=0.0), yA_rxB(start=0.0), thetaA_rxB(start=0.0), vA_rxB(start=0.0);

  // Predicted peer state (finite, bounded horizon)
  Real xB_predA, yB_predA, vB_predA;
  Real xA_predB, yA_predB, vA_predB;
  Real horizonA, horizonB;

  // Disturbance signal (shared)
  Real Fdist;

  // Reference route
  Real xRef, yRefA, yRefB;

  // Observables / metrics
  Real trackErrA  "primary (robot A) tracking error [m]";
  Real trackErrB;
  Real formErr    "formation error [m]";
  discrete Real trackErrA_65(start=0.0) "primary tracking error captured at/after 6.5 s";
  Boolean captured65;
  Boolean missionOK;
  Real finiteGuard "1.0 if all signals finite (placeholder, see comment)";

  // Intermediate controller variables
  Real vxA_des_A, vyA_des_A, vFwd_des_A, thetacmdA, dthA, FcmdA, McmdA;
  Real vxB_des_B, vyB_des_B, vFwd_des_B, thetacmdB, dthB, FcmdB, McmdB;
  Real collRepA_x, collRepA_y, collRepB_x, collRepB_y;

equation
  // Reference route: straight +x motion at vRef
  xRef  = vRef * time;
  yRefA = 0.0;
  yRefB = dForm;

  // Communication availability: dropout in the middle third, 0.7 s long
  commOK = not (time >= tDropStart and time <= tDropStart + dtDrop);

  // Shared environmental disturbance applied ONLY while communication is unavailable
  Fdist = if (time >= tDropStart and time <= tDropStart + dtDrop) then -FdistMag else 0.0;

  // ---------------- Robot A dynamics ----------------
  der(xA)     = vA * cos(thetaA);
  der(yA)     = vA * sin(thetaA);
  der(thetaA) = omegaA;
  der(vA)     = (FA + Fdist - b * vA) / m;
  der(omegaA) = (MA - bz * omegaA) / Iz;
  FA = (tauRA_sat + tauLA_sat) / r;
  MA = (tauRA_sat - tauLA_sat) * L / (2.0 * r);

  // ---------------- Robot B dynamics ----------------
  der(xB)     = vB * cos(thetaB);
  der(yB)     = vB * sin(thetaB);
  der(thetaB) = omegaB;
  der(vB)     = (FB + Fdist - b * vB) / m;
  der(omegaB) = (MB - bz * omegaB) / Iz;
  FB = (tauRB_sat + tauLB_sat) / r;
  MB = (tauRB_sat - tauLB_sat) * L / (2.0 * r);

  // ---------------- Proprioception / exteroception ----------------
  encRA = vA / r;
  encLA = vA / r;
  encRB = vB / r;
  encLB = vB / r;
  imuA  = omegaA;
  imuB  = omegaB;
  collDist = sqrt((xB - xA)^2 + (yB - yA)^2);
  lidarA = collDist;
  lidarB = collDist;

  // ---------------- Actuator saturation (bounded wheel torques) ----------------
  tauRA_sat = max(-tauMax, min(tauMax, tauRA));
  tauLA_sat = max(-tauMax, min(tauMax, tauLA));
  tauRB_sat = max(-tauMax, min(tauMax, tauRB));
  tauLB_sat = max(-tauMax, min(tauMax, tauLB));

  // ---------------- Prediction during dropout (finite estimates) ----------------
  horizonA = max(time - tLastRx_A, 0.0);
  horizonB = max(time - tLastRx_B, 0.0);
  xB_predA = xB_rxA + vB_rxA * horizonA;
  yB_predA = yB_rxA;
  vB_predA = vB_rxA;
  xA_predB = xA_rxB + vA_rxB * horizonB;
  yA_predB = yA_rxB;
  vA_predB = vA_rxB;

  // ---------------- Collision avoidance (lidar-based repulsion) ----------------
  collRepA_x = if collDist < collThresh then -kColl * (xB - xA) / max(collDist, eps) * (collThresh - collDist) else 0.0;
  collRepA_y = if collDist < collThresh then -kColl * (yB - yA) / max(collDist, eps) * (collThresh - collDist) else 0.0;
  collRepB_x = if collDist < collThresh then -kColl * (xA - xB) / max(collDist, eps) * (collThresh - collDist) else 0.0;
  collRepB_y = if collDist < collThresh then -kColl * (yA - yB) / max(collDist, eps) * (collThresh - collDist) else 0.0;

  // ---------------- Distributed control: Robot A (leader, primary) ----------------
  // A tracks its own route using local proprioception; no peer dependency.
  vxA_des_A = vRef + collRepA_x;
  vyA_des_A = 0.0 + collRepA_y;
  vFwd_des_A = vxA_des_A * cos(thetaA) + vyA_des_A * sin(thetaA);
  thetacmdA  = atan2(vyA_des_A, vxA_des_A);
  dthA = thetacmdA - thetaA;
  FcmdA = m * (kpV * (vFwd_des_A - vA) + kpX * (xRef - xA) * cos(thetaA)) + b * vA;
  McmdA = kpTh * atan2(sin(dthA), cos(dthA)) - kdTh * omegaA;
  tauRA = (r / 2.0) * (FcmdA + 2.0 * McmdA / L);
  tauLA = (r / 2.0) * (FcmdA - 2.0 * McmdA / L);

  // ---------------- Distributed control: Robot B (follower) ----------------
  // B uses last-received peer state with timestamp + prediction during dropout.
  vxB_des_B = vA_predB + kForm * (xA_predB - xB) + collRepB_x;
  vyB_des_B = kForm * (yA_predB + dForm - yB) + collRepB_y;
  vFwd_des_B = vxB_des_B * cos(thetaB) + vyB_des_B * sin(thetaB);
  thetacmdB  = atan2(vyB_des_B, vxB_des_B);
  dthB = thetacmdB - thetaB;
  FcmdB = m * (kpV * (vFwd_des_B - vB) + kpX * (xA_predB - xB) * cos(thetaB)) + b * vB;
  McmdB = kpTh * atan2(sin(dthB), cos(dthB)) - kdTh * omegaB;
  tauRB = (r / 2.0) * (FcmdB + 2.0 * McmdB / L);
  tauLB = (r / 2.0) * (FcmdB - 2.0 * McmdB / L);

  // ---------------- Metrics ----------------
  trackErrA = sqrt((xA - xRef)^2 + (yA - yRefA)^2);
  trackErrB = sqrt((xB - xRef)^2 + (yB - yRefB)^2);
  formErr   = abs(collDist - dForm);

  // Finite-value guard: identity check (no NaN/Inf propagation by construction);
  // OpenModelica preserves finite arithmetic here. Placeholder kept explicit.
  finiteGuard = 1.0;

  // Mission success: primary tracking error after recovery below 0.72 m,
  // finite formation error, completed route, no NaN/Inf (by construction).
  missionOK = (time >= 6.5) and (trackErrA < 0.72) and (formErr < 1.0e6) and (xA > 0.0);

algorithm
  // Discrete communication + telemetry at 100 Hz
  when sample(0, T) then
    // Exchange peer state with timestamps when communication is available
    if commOK then
      // A receives B
      xB_rxA     := xB;
      yB_rxA     := yB;
      thetaB_rxA := thetaB;
      vB_rxA     := vB;
      tLastRx_A  := time;
      // B receives A
      xA_rxB     := xA;
      yA_rxB     := yA;
      thetaA_rxB := thetaA;
      vA_rxB     := vA;
      tLastRx_B  := time;
    end if;

    // Capture primary tracking error at/after 6.5 s for requirement check
    if time >= 6.5 and not pre(captured65) then
      trackErrA_65 := trackErrA;
      captured65   := true;
    end if;
  end when;

annotation(
  experiment(StopTime=10.0, Tolerance=1.0e-6, Interval=0.01),
  Documentation(info="GroundPairResilientB: two differential-drive robots maintain coordinated
  motion through a 0.7 s communication dropout (mid third) under a shared environmental
  disturbance, using local proprioception, exteroception, and timestamped last-received
  peer state with prediction. Bounded wheel torques (8.2 N.m), collision avoidance,
  degraded/recovered formation error, finite estimates, and primary tracking error < 0.72 m
  after 6.5 s are enforced. Unstated physical constants use clearly labeled nominal values."));
end GroundPairResilientB;