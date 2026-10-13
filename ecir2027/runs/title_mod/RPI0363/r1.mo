model ParallelGripGraspC
  "Parallel-grip grasp: impedance closure followed by normal-force regulation, with explicit plant, contacts, table, and 125 Hz traces";

  // Requested specified values
  parameter Real m_palm = 6.0 "fixed palm mass (kg)";
  parameter Real m_finger = 0.5 "mass of each opposing box finger (kg)";
  parameter Real d_travel = 0.05 "prismatic joint travel (m)";
  parameter Real Fmax = 41.4 "maximum command magnitude per finger (N)";
  parameter Real F_dist = 7.2 "tangential load disturbance (N)";
  parameter Real mu = 0.78 "friction coefficient";
  parameter Real restitution = 0.03 "collision restitution";
  parameter Real Ts = 1.0/125.0 "control and trace sample period (s)";
  parameter Real StopTime = 12.0 "simulation duration (s)";

  // Representative bindings for quantities not stated in the request; replace by identified values if available
  parameter Real g = 9.80665 "SI gravity (m/s^2)";
  parameter Real pi = 3.141592653589793;
  parameter Real m_obj = 1.0 "object mass not specified; representative";
  parameter Real Wo = 0.03 "object width along closure not specified; representative";
  parameter Real Ho = 0.04 "object height not specified; representative";
  parameter Real gapOpen = 0.08 "initial finger gap not specified; representative";
  parameter Real k_pad = 2000.0 "pad stiffness not specified; representative";
  parameter Real k_table = 1.0e5 "table normal stiffness not specified; representative";
  parameter Real k_stop = 1.0e5 "joint stop stiffness not specified; representative";
  parameter Real k_table_tan = 1.0e5 "table tangential stiffness not specified; representative";
  parameter Real k_tan = 1.0e5 "pad tangential stiffness not specified; representative";
  parameter Real tau_act = 0.02 "actuator time constant not specified; representative";
  parameter Real F_des = 10.0 "desired normal force per finger not specified; representative";
  parameter Real tForceStart = 2.0 "force-regulation start time not specified; representative";
  parameter Real Kp_imp = 400.0 "impedance position gain not specified; representative";
  parameter Real Kd_imp = 30.0 "impedance damping gain not specified; representative";
  parameter Real Kp_force = 100.0 "force-loop position gain not specified; representative";
  parameter Real Kd_force = 20.0 "force-loop damping gain not specified; representative";
  parameter Real Kf = 2.0 "force-loop gain not specified; representative";

  // Derived constants
  parameter Real x0L = -0.5*gapOpen "left pad open surface x (m)";
  parameter Real x0R = 0.5*gapOpen "right pad open surface x (m)";
  parameter Real q_contact = 0.5*(gapOpen - Wo) "closure at first contact (m)";
  parameter Real q_start = 0.2*q_contact "initial non-singular closure (m)";
  parameter Real q_close = q_contact + F_des/k_pad "closure setpoint for desired pad force (m)";
  parameter Real z0 = 0.5*Ho - m_obj*g/k_table "table equilibrium object center height (m)";
  parameter Real zeta = -log(restitution)/sqrt(pi*pi + log(restitution)*log(restitution)) "damping ratio from restitution";
  parameter Real d_pad = 2.0*sqrt(k_pad*m_finger)*zeta "pad normal damping (N.s/m)";
  parameter Real d_table = 2.0*sqrt(k_table*m_obj)*zeta "table normal damping (N.s/m)";
  parameter Real c_stop = 2.0*sqrt(k_stop*m_finger)*zeta "joint stop damping (N.s/m)";
  parameter Real c_table_tan = 2.0*sqrt(k_table_tan*m_obj)*0.5 "table tangential damping (N.s/m)";
  parameter Real c_tan = 2.0*sqrt(k_tan*m_obj)*0.5 "pad tangential damping (N.s/m)";
  parameter Real tDistStart = 4.0 "middle-third disturbance start (s)";
  parameter Real tDistEnd = 8.0 "middle-third disturbance end (s)";

  // Plant states
  Real qL(start=q_start), qLdot(start=0) "left finger closure and rate (m, m/s)";
  Real qR(start=q_start), qRdot(start=0) "right finger closure and rate (m, m/s)";
  Real F_actL(start=0), F_actR(start=0) "bounded linear actuator forces (N)";
  Real x(start=0), xdot(start=0) "object pose x and rate (m, m/s)";
  Real y(start=0), ydot(start=0) "object pose y and rate (m, m/s)";
  Real z(start=z0), zdot(start=0) "object pose z and rate (m, m/s)";
  Real objectTheta(start=0) "object pose orientation; no rotational torque specified (rad)";

  // Contact and force variables
  Real penL, penLdot, FL_n "left pad penetration, rate, normal force";
  Real penR, penRdot, FR_n "right pad penetration, rate, normal force";
  Real penTable, penTableDot, N_table "table penetration, rate, normal force";
  Real F_stopL, F_stopR "joint stop forces";
  Real FL_tan, FR_tan "finger-object tangential friction forces";
  Real F_table_x, F_table_y "table tangential friction forces";
  Real F_disturb "applied tangential disturbance";

  // Controller and traces
  discrete Real cmdL(start=0, fixed=true) "left finger command (N)";
  discrete Real cmdR(start=0, fixed=true) "right finger command (N)";
  discrete Boolean forcePhase(start=false, fixed=true) "true after impedance phase";

  discrete Real sensorTime(start=0, fixed=true);
  discrete Real sensorqL(start=0, fixed=true);
  discrete Real sensorqR(start=0, fixed=true);
  discrete Real sensorqLdot(start=0, fixed=true);
  discrete Real sensorqRdot(start=0, fixed=true);
  discrete Real sensorActuatorL(start=0, fixed=true);
  discrete Real sensorActuatorR(start=0, fixed=true);
  discrete Real sensorNormalL(start=0, fixed=true);
  discrete Real sensorNormalR(start=0, fixed=true);
  discrete Real sensorPoseX(start=0, fixed=true);
  discrete Real sensorPoseY(start=0, fixed=true);
  discrete Real sensorPoseZ(start=0, fixed=true);
  discrete Real sensorPoseTheta(start=0, fixed=true);
  discrete Real sensorPrimaryTrackingError(start=0, fixed=true);
  discrete Real sensorCommandL(start=0, fixed=true);
  discrete Real sensorCommandR(start=0, fixed=true);
  discrete Boolean sensorGraspActive(start=false, fixed=true);
  discrete Boolean sensorPrimaryTrackingMet(start=false, fixed=true);

  // Requirement observables
  Real primaryTrackingError "object displacement from hold pose (m)";
  Real minContactForce "minimum finger normal force (N)";
  Boolean boundedTravelL;
  Boolean boundedTravelR;
  Boolean boundedEffortL;
  Boolean boundedEffortR;
  Boolean graspActive;
  Boolean noGraspLoss;
  Boolean primaryTrackingMet;
  Real finiteCheck "sum of magnitudes for NaN/infinity sanity";
  Boolean noNaNInf;

  // FMU-facing outputs
  output Real outPrimaryTrackingError = primaryTrackingError;
  output Real outCommandLeft = cmdL;
  output Real outCommandRight = cmdR;
  output Real outNormalForceLeft = FL_n;
  output Real outNormalForceRight = FR_n;
  output Real outObjectPoseX = x;
  output Real outObjectPoseY = y;
  output Real outObjectPoseZ = z;
  output Real outObjectPoseTheta = objectTheta;
  output Real outFingerLeftClosure = qL;
  output Real outFingerRightClosure = qR;
  output Real outActuatorLeftForce = F_actL;
  output Real outActuatorRightForce = F_actR;

  assert(m_palm > 0.0, "palm mass must be positive");
  assert(m_finger > 0.0, "finger mass must be positive");
  assert(m_obj > 0.0, "object mass must be positive");
  assert(restitution > 0.0, "restitution must be positive for damping computation");
  assert(q_close <= d_travel, "desired closure exceeds travel");
  assert(q_close > q_contact, "desired closure must be beyond contact");

  initial equation
    qL = q_start;
    qLdot = 0.0;
    qR = q_start;
    qRdot = 0.0;
    F_actL = 0.0;
    F_actR = 0.0;
    x = 0.0;
    xdot = 0.0;
    y = 0.0;
    ydot = 0.0;
    z = z0;
    zdot = 0.0;
    objectTheta = 0.0;

equation
  // Finger actuator dynamics: bounded linear force actuators
  der(F_actL) = (cmdL - F_actL)/tau_act;
  der(F_actR) = (cmdR - F_actR)/tau_act;

  // Finger closure dynamics
  der(qL) = qLdot;
  der(qR) = qRdot;
  m_finger*der(qLdot) = F_actL + F_stopL - FL_n;
  m_finger*der(qRdot) = F_actR + F_stopR - FR_n;

  // Prismatic joint travel stops with collision enabled
  F_stopL = if noEvent(qL < 0.0) then -k_stop*qL - c_stop*qLdot
            else if noEvent(qL > d_travel) then -k_stop*(qL - d_travel) - c_stop*qLdot
            else 0.0;
  F_stopR = if noEvent(qR < 0.0) then -k_stop*qR - c_stop*qRdot
            else if noEvent(qR > d_travel) then -k_stop*(qR - d_travel) - c_stop*qRdot
            else 0.0;

  // Finger-object pad normal contacts
  penL = (x0L + qL) - (x - 0.5*Wo);
  penLdot = qLdot - xdot;
  FL_n = if noEvent(penL > 0.0) then max(0.0, k_pad*penL + d_pad*penLdot) else 0.0;

  penR = (x + 0.5*Wo) - (x0R - qR);
  penRdot = xdot + qRdot;
  FR_n = if noEvent(penR > 0.0) then max(0.0, k_pad*penR + d_pad*penRdot) else 0.0;

  // Object dynamics
  der(x) = xdot;
  der(y) = ydot;
  der(z) = zdot;
  m_obj*der(xdot) = FL_n - FR_n + F_table_x;
  m_obj*der(ydot) = F_disturb + F_table_y + FL_tan + FR_tan;
  m_obj*der(zdot) = N_table - m_obj*g;
  der(objectTheta) = 0.0 "rotational dynamics not specified";

  // Rigid support table normal contact
  penTable = 0.5*Ho - z;
  penTableDot = -zdot;
  N_table = if noEvent(penTable > 0.0) then max(0.0, k_table*penTable + d_table*penTableDot) else 0.0;

  // Table friction with requested coefficient
  F_table_x = max(-mu*N_table, min(mu*N_table, -k_table_tan*x - c_table_tan*xdot));
  F_table_y = max(-mu*N_table, min(mu*N_table, -k_table_tan*y - c_table_tan*ydot));

  // Finger-object friction with requested coefficient
  FL_tan = if noEvent(FL_n > 0.0) then max(-mu*FL_n, min(mu*FL_n, -k_tan*y - c_tan*ydot)) else 0.0;
  FR_tan = if noEvent(FR_n > 0.0) then max(-mu*FR_n, min(mu*FR_n, -k_tan*y - c_tan*ydot)) else 0.0;

  // Disturbance during middle third
  F_disturb = if time >= tDistStart and time <= tDistEnd then F_dist else 0.0;

  // Requirement checks
  primaryTrackingError = sqrt(x*x + y*y + (z - z0)*(z - z0));
  minContactForce = if FL_n < FR_n then FL_n else FR_n;
  boundedTravelL = qL >= -1.0e-6 and qL <= d_travel + 1.0e-6;
  boundedTravelR = qR >= -1.0e-6 and qR <= d_travel + 1.0e-6;
  boundedEffortL = abs(cmdL) <= Fmax + 1.0e-6;
  boundedEffortR = abs(cmdR) <= Fmax + 1.0e-6;
  graspActive = time > tForceStart and FL_n > 0.0 and FR_n > 0.0;
  noGraspLoss = FL_n > 0.0 and FR_n > 0.0;
  primaryTrackingMet = time > 7.8 and primaryTrackingError < 0.016;
  finiteCheck = abs(x) + abs(y) + abs(z) + abs(qL) + abs(qR) + abs(FL_n) + abs(FR_n) + abs(cmdL) + abs(cmdR) + abs(F_actL) + abs(F_actR);
  noNaNInf = finiteCheck < 1.0e12;

  // 125 Hz controller and synchronized traces
  when sample(0.0, Ts) then
    forcePhase := time >= tForceStart;

    cmdL := max(-Fmax, min(Fmax,
              if forcePhase then
                F_des + Kf*(F_des - FL_n) + Kp_force*(q_close - qL) - Kd_force*qLdot
              else
                Kp_imp*(q_close - qL) - Kd_imp*qLdot));

    cmdR := max(-Fmax, min(Fmax,
              if forcePhase then
                F_des + Kf*(F_des - FR_n) + Kp_force*(q_close - qR) - Kd_force*qRdot
              else
                Kp_imp*(q_close - qR) - Kd_imp*qRdot));

    sensorTime := time;
    sensorqL := qL;
    sensorqR := qR;
    sensorqLdot := qLdot;
    sensorqRdot := qRdot;
    sensorActuatorL := F_actL;
    sensorActuatorR := F_actR;
    sensorNormalL := FL_n;
    sensorNormalR := FR_n;
    sensorPoseX := x;
    sensorPoseY := y;
    sensorPoseZ := z;
    sensorPoseTheta := objectTheta;
    sensorPrimaryTrackingError := primaryTrackingError;
    sensorCommandL := cmdL;
    sensorCommandR := cmdR;
    sensorGraspActive := graspActive;
    sensorPrimaryTrackingMet := primaryTrackingMet;
  end when;

  annotation(experiment(StopTime = 12.0, Tolerance = 1.0e-6, Interval = Ts));
end ParallelGripGraspC;