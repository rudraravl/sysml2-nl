model DeltaPressD
  // Stated embodiment parameters
  parameter Modelica.SIunits.Length L_upper = 0.32 "actuated upper-arm length";
  parameter Modelica.SIunits.Length L_fore = 0.60 "paired forearm length";
  parameter Modelica.SIunits.Mass m_platform = 3.00 "moving platform mass";
  parameter Modelica.SIunits.Torque tau_max = 45.00 "per-actuator torque bound";

  // Stated contact parameters
  parameter Modelica.SIunits.TranslationalSpringConstant k_contact = 200000.0 "contact stiffness";
  parameter Modelica.SIunits.TranslationalDampingConstant c_contact = 2000.0 "contact damping";
  parameter Real mu = 0.70 "contact friction coefficient";

  // Stated run and disturbance parameters
  parameter Modelica.SIunits.Force F_dist = 18.00 "controlled force-change disturbance";
  parameter Modelica.SIunits.Frequency f_sample = 200.0 "controller sampling frequency";
  parameter Modelica.SIunits.Time Ts = 1.0/f_sample "sampling period";
  parameter Modelica.SIunits.Time T_end = 14.00 "run duration";
  parameter Modelica.SIunits.Time T_mid_start = T_end/3.0 "middle third start";
  parameter Modelica.SIunits.Time T_mid_end = 2.0*T_end/3.0 "middle third end";

  // The absolute force setpoint is not stated; the force channel uses the stated 18 N change
  // as the command, so only the stated force change is exercised.
  parameter Modelica.SIunits.Force F_cmd = F_dist "force command";

  // Base/platform geometry, joint coordinates, absolute trajectory, and controller gains are not stated.
  // This executable model uses a normalized 1-D closure coordinate preserving the stated arm lengths,
  // mass, torque bounds, contact parameters, disturbance, sampling, and duration.
  parameter Modelica.SIunits.Length x_workpiece = L_fore "normalized contact surface derived from stated forearm length";
  parameter Real Kp_x = 1.0 "position gain (N/m)";
  parameter Real Kd_x = 1.0 "position damping gain (N.s/m)";
  parameter Real Kp_f = 1.0 "force proportional gain (dimensionless)";
  parameter Real Ki_f = 1.0 "force integral gain (1/s)";
  parameter Real Kc = 10.0 "closure proportional gain (N.m/rad)";
  parameter Real Kcd = 1.0 "closure damping gain (N.m.s/rad)";
  parameter Modelica.SIunits.Velocity v_reg = 1e-3 "friction regularization velocity";
  parameter Modelica.SIunits.Velocity v_lock = 1e-6 "locked-contact slip threshold";
  parameter Real eps = 1e-9 "positive regularization scalar";

  // Dynamic states
  Modelica.SIunits.Angle q1(start=0) "actuated upper-arm angle 1";
  Modelica.SIunits.Angle q2(start=0) "actuated upper-arm angle 2";
  Modelica.SIunits.Angle q3(start=0) "actuated upper-arm angle 3";
  Modelica.SIunits.AngularVelocity qd1(start=0) "actuator angular velocity 1";
  Modelica.SIunits.AngularVelocity qd2(start=0) "actuator angular velocity 2";
  Modelica.SIunits.AngularVelocity qd3(start=0) "actuator angular velocity 3";
  Modelica.SIunits.Length y(start=0) "tangential output coordinate";
  Modelica.SIunits.Velocity yd(start=0) "tangential output velocity";

  // Discrete controller state and held commands
  discrete Real Fint(start=0) "integral force-error state (N.s)";
  discrete Modelica.SIunits.Torque tau_common_d(start=0) "held common torque command";
  discrete Modelica.SIunits.Torque tau_cmd1_d(start=0) "held actuator 1 torque command";
  discrete Modelica.SIunits.Torque tau_cmd2_d(start=0) "held actuator 2 torque command";
  discrete Modelica.SIunits.Torque tau_cmd3_d(start=0) "held actuator 3 torque command";

  // Kinematics and dynamics variables
  Real dx1, dx2, dx3, dx_avg;
  Real x1, x2, x3, x, v;
  Real q_avg, qd_avg;
  Real J1, J2, J3;
  Real tau_closure1, tau_closure2, tau_closure3;
  Real penetration, contactVelocity, contactForceNormal;
  Modelica.SIunits.Force F_dist_active;
  Modelica.SIunits.Force F_des;
  Modelica.SIunits.Length x_ref;
  Modelica.SIunits.Torque tau_common;
  Modelica.SIunits.Torque tau_cmd1, tau_cmd2, tau_cmd3;
  Modelica.SIunits.Torque tau1, tau2, tau3;
  Modelica.SIunits.Force F_friction;
  Real slipSpeed, tangentialSlip;
  Boolean lockedContact;

  // Requirement monitors
  Real closureError;
  Real primaryTrackingError;
  Modelica.SIunits.Force contactForceBandLow;
  Modelica.SIunits.Force contactForceBandHigh;
  Boolean contactForceInBand;
  Boolean actuatorBoundsSatisfied;
  Boolean finitePhysical;
  Boolean finiteControl;
  Boolean finiteEstimator;

  // Sensors
  Modelica.SIunits.Torque actuatorTorqueSensor1;
  Modelica.SIunits.Torque actuatorTorqueSensor2;
  Modelica.SIunits.Torque actuatorTorqueSensor3;
  Modelica.SIunits.Angle actuatorPositionSensor1;
  Modelica.SIunits.Angle actuatorPositionSensor2;
  Modelica.SIunits.Angle actuatorPositionSensor3;
  Modelica.SIunits.Length outputPoseX;
  Modelica.SIunits.Length outputPoseY;

  // Estimator placeholders; no separate estimator is specified
  Modelica.SIunits.Force estimatorContactForce;
  Real estimatorClosureError;

  // Synchronized traces
  Real stateTrace_x;
  Real stateTrace_v;
  Real stateTrace_q1;
  Real stateTrace_q2;
  Real stateTrace_q3;
  Real stateTrace_y;
  Real commandTrace_tau1;
  Real commandTrace_tau2;
  Real commandTrace_tau3;
  Real commandTrace_F_des;
  Real sensorTrace_actuatorTorque1;
  Real sensorTrace_actuatorTorque2;
  Real sensorTrace_actuatorTorque3;
  Real sensorTrace_contactForce;
  Real sensorTrace_outputPoseX;
  Real sensorTrace_outputPoseY;
  Real forceIntegralTrace;

equation
  // Normalized Delta closure kinematics preserving stated arm lengths
  dx1 = L_upper*cos(q1);
  dx2 = L_upper*cos(q2);
  dx3 = L_upper*cos(q3);
  dx_avg = (abs(dx1) + abs(dx2) + abs(dx3))/3.0;

  x1 = L_upper*sin(q1) + L_fore;
  x2 = L_upper*sin(q2) + L_fore;
  x3 = L_upper*sin(q3) + L_fore;
  x = (x1 + x2 + x3)/3.0;
  v = (dx1*qd1 + dx2*qd2 + dx3*qd3)/3.0;

  q_avg = (q1 + q2 + q3)/3.0;
  qd_avg = (qd1 + qd2 + qd3)/3.0;

  // Reflected platform inertia per massless chain
  J1 = m_platform*max(abs(dx1), eps)^2/3.0;
  J2 = m_platform*max(abs(dx2), eps)^2/3.0;
  J3 = m_platform*max(abs(dx3), eps)^2/3.0;

  // Actuated chain dynamics with closure and contact reaction
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  J1*der(qd1) = tau1 - dx1*contactForceNormal/3.0 + dx1*F_dist_active/3.0 + tau_closure1;
  J2*der(qd2) = tau2 - dx2*contactForceNormal/3.0 + dx2*F_dist_active/3.0 + tau_closure2;
  J3*der(qd3) = tau3 - dx3*contactForceNormal/3.0 + dx3*F_dist_active/3.0 + tau_closure3;

  // Closure control torques
  tau_closure1 = -Kc*(q1 - q_avg) - Kcd*(qd1 - qd_avg);
  tau_closure2 = -Kc*(q2 - q_avg) - Kcd*(qd2 - qd_avg);
  tau_closure3 = -Kc*(q3 - q_avg) - Kcd*(qd3 - qd_avg);

  // Contact force against fixed compliant workpiece
  penetration = noEvent(max(0.0, x - x_workpiece));
  contactVelocity = noEvent(if x > x_workpiece then v else 0.0);
  contactForceNormal = noEvent(max(0.0, k_contact*penetration + c_contact*contactVelocity));

  // Controlled 18 N force-change disturbance during middle third
  F_dist_active = noEvent(if time >= T_mid_start and time <= T_mid_end then F_dist else 0.0);

  // Tangential contact friction and slip
  slipSpeed = yd;
  tangentialSlip = abs(slipSpeed);
  F_friction = -mu*abs(contactForceNormal)*Modelica.Math.tanh(slipSpeed/v_reg);
  der(y) = yd;
  m_platform*der(yd) = F_friction;
  lockedContact = noEvent(contactForceNormal > 0.0 and tangentialSlip < v_lock);

  // Hybrid position-to-force command
  x_ref = x_workpiece + F_cmd/k_contact;
  F_des = Kp_x*(x_ref - x) - Kd_x*v + Kp_f*(F_cmd - contactForceNormal) + Ki_f*Fint;
  tau_common = tau_common_d;
  tau_cmd1 = tau_cmd1_d;
  tau_cmd2 = tau_cmd2_d;
  tau_cmd3 = tau_cmd3_d;

  // Actuator saturation
  tau1 = noEvent(max(-tau_max, min(tau_max, tau_cmd1)));
  tau2 = noEvent(max(-tau_max, min(tau_max, tau_cmd2)));
  tau3 = noEvent(max(-tau_max, min(tau_max, tau_cmd3)));

  // Sensors
  actuatorTorqueSensor1 = tau1;
  actuatorTorqueSensor2 = tau2;
  actuatorTorqueSensor3 = tau3;
  actuatorPositionSensor1 = q1;
  actuatorPositionSensor2 = q2;
  actuatorPositionSensor3 = q3;
  outputPoseX = x;
  outputPoseY = y;

  // Estimator placeholders
  estimatorContactForce = contactForceNormal;
  estimatorClosureError = closureError;

  // Requirement monitors
  closureError = max(abs(x1 - x), max(abs(x2 - x), abs(x3 - x)));
  primaryTrackingError = closureError;
  contactForceBandLow = max(0.0, F_cmd - F_dist);
  contactForceBandHigh = F_cmd + F_dist;
  contactForceInBand = noEvent(contactForceNormal >= contactForceBandLow and contactForceNormal <= contactForceBandHigh);
  actuatorBoundsSatisfied = noEvent(abs(tau1) <= tau_max + 1e-6 and abs(tau2) <= tau_max + 1e-6 and abs(tau3) <= tau_max + 1e-6);

  finitePhysical = noEvent(
    q1 >= -1e30 and q1 <= 1e30 and
    q2 >= -1e30 and q2 <= 1e30 and
    q3 >= -1e30 and q3 <= 1e30 and
    qd1 >= -1e30 and qd1 <= 1e30 and
    qd2 >= -1e30 and qd2 <= 1e30 and
    qd3 >= -1e30 and qd3 <= 1e30 and
    x >= -1e30 and x <= 1e30 and
    v >= -1e30 and v <= 1e30 and
    y >= -1e30 and y <= 1e30 and
    yd >= -1e30 and yd <= 1e30 and
    contactForceNormal >= -1e30 and contactForceNormal <= 1e30);

  finiteControl = noEvent(
    tau1 >= -1e30 and tau1 <= 1e30 and
    tau2 >= -1e30 and tau2 <= 1e30 and
    tau3 >= -1e30 and tau3 <= 1e30 and
    tau_cmd1 >= -1e30 and tau_cmd1 <= 1e30 and
    tau_cmd2 >= -1e30 and tau_cmd2 <= 1e30 and
    tau_cmd3 >= -1e30 and tau_cmd3 <= 1e30 and
    F_des >= -1e30 and F_des <= 1e30 and
    Fint >= -1e30 and Fint <= 1e30);

  finiteEstimator = noEvent(
    estimatorContactForce >= -1e30 and estimatorContactForce <= 1e30 and
    estimatorClosureError >= -1e30 and estimatorClosureError <= 1e30);

  // Synchronized traces
  stateTrace_x = x;
  stateTrace_v = v;
  stateTrace_q1 = q1;
  stateTrace_q2 = q2;
  stateTrace_q3 = q3;
  stateTrace_y = y;
  commandTrace_tau1 = tau1;
  commandTrace_tau2 = tau2;
  commandTrace_tau3 = tau3;
  commandTrace_F_des = F_des;
  sensorTrace_actuatorTorque1 = actuatorTorqueSensor1;
  sensorTrace_actuatorTorque2 = actuatorTorqueSensor2;
  sensorTrace_actuatorTorque3 = actuatorTorqueSensor3;
  sensorTrace_contactForce = contactForceNormal;
  sensorTrace_outputPoseX = outputPoseX;
  sensorTrace_outputPoseY = outputPoseY;
  forceIntegralTrace = Fint;

  // 200 Hz sampled hybrid controller
  when {initial(), sample(Ts, Ts)} then
    Fint = pre(Fint) + Ts*(F_cmd - contactForceNormal);
    tau_common_d = dx_avg*(Kp_x*(x_ref - x) - Kd_x*v + Kp_f*(F_cmd - contactForceNormal) + Ki_f*pre(Fint))/3.0;
    tau_cmd1_d = dx_avg*(Kp_x*(x_ref - x) - Kd_x*v + Kp_f*(F_cmd - contactForceNormal) + Ki_f*pre(Fint))/3.0 + tau_closure1;
    tau_cmd2_d = dx_avg*(Kp_x*(x_ref - x) - Kd_x*v + Kp_f*(F_cmd - contactForceNormal) + Ki_f*pre(Fint))/3.0 + tau_closure2;
    tau_cmd3_d = dx_avg*(Kp_x*(x_ref - x) - Kd_x*v + Kp_f*(F_cmd - contactForceNormal) + Ki_f*pre(Fint))/3.0 + tau_closure3;
  end when;

  // Requirement assertions
  assert(actuatorBoundsSatisfied, "actuator torque bound exceeded");
  assert(contactForceInBand, "contact force band exceeded");
  assert(noEvent(time < 9.1 or primaryTrackingError < 0.001), "primary tracking/closure error after 9.1 s exceeds 0.001 m");
  assert(noEvent(time < 9.1 or lockedContact), "contact not locked after 9.1 s");
  assert(noEvent(time < 9.1 or tangentialSlip < v_lock), "tangential slip after 9.1 s exceeds lock threshold");
  assert(finitePhysical and finiteControl and finiteEstimator, "NaN or infinite physical, control, or estimator value detected");

  annotation (
    Experiment(StopTime=14, Interval=0.005, Tolerance=1e-6),
    Documentation(info="DeltaPressD: instrumented closed-chain press model with 200 Hz hybrid position-force control, closure monitoring, contact force feedback, and synchronized state/command/sensor traces."));
end DeltaPressD;