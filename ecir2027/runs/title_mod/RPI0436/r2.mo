model ContactArmGraspD
  "Instrumented contact-rich manipulation system.
   Joint sequence axes Z-Y-Y-X-Y-X are represented as q1 yaw (Z),
   q2 shoulder pitch (Y), q3 elbow pitch (Y), q4 tool roll (X),
   q5 wrist pitch (Y), q6 wrist roll (X). Capsule link radii,
   exact link inertias, tool geometry, object dimensions, tool-object
   friction, travel limits, and estimator details are not specified by
   the requirement; nominal SI placeholders are used only where needed
   for code generation and are labeled below."

  // Run and verification parameters
  parameter Real Ts = 0.005 "controller and trace synchronization period, 200 Hz";
  parameter Real tEnd = 14.0 "simulation duration";
  parameter Real tMidStart = 14.0/3.0 "start of middle third disturbance window";
  parameter Real tMidEnd = 28.0/3.0 "end of middle third disturbance window";
  parameter Real tTrack = 9.1 "tracking-error verification time";
  parameter Real eTrackMax = 0.015 "primary tracking error bound after tTrack";
  parameter Real tauMax = 120.0 "saturated joint effort bound";
  parameter Real qTravelMax = 3.14159265358979 "nominal travel bound; exact limit not specified";
  parameter Real objectDisplacementMax = 0.01 "nominal displacement bound; excessive threshold not specified";
  parameter Real fNormalMin = 1.0 "minimum normal force for no grasp loss after contact";

  // Table and disturbance parameters
  parameter Real muTable = 0.78 "table friction coefficient";
  parameter Real restitutionTable = 0.03 "table restitution coefficient";
  parameter Boolean collisionEnabled = true "collision enabled";
  parameter Real Fdist = 8.0 "controlled tangential load disturbance";
  parameter Real muTool = 0.78 "tool-object friction; not specified, nominal placeholder";

  // Kinematic and dynamic placeholders
  parameter Real H0 = 0.5 "base height";
  parameter Real L2 = 0.35 "shoulder link length";
  parameter Real L3 = 0.35 "elbow link length";
  parameter Real Ltool = 0.10 "rigid tool length";
  parameter Real L2cm = 0.175 "shoulder link center of mass";
  parameter Real L3cm = 0.175 "elbow link center of mass";
  parameter Real Ltoolcm = 0.05 "tool center of mass";
  parameter Real mLink2 = 1.0 "shoulder link mass";
  parameter Real mLink3 = 1.0 "elbow link mass";
  parameter Real mTool = 0.5 "replaceable rigid tool mass";
  parameter Real mObj = 0.5 "rigid object mass";
  parameter Real hObj = 0.01 "object half height";
  parameter Real gAccel = 9.81 "gravitational acceleration";

  // Joint inertias and damping
  parameter Real J1 = 0.20;
  parameter Real J2 = 0.50;
  parameter Real J3 = 0.30;
  parameter Real J4 = 0.05;
  parameter Real J5 = 0.05;
  parameter Real J6 = 0.05;
  parameter Real b1 = 0.20;
  parameter Real b2 = 0.20;
  parameter Real b3 = 0.20;
  parameter Real b4 = 0.10;
  parameter Real b5 = 0.10;
  parameter Real b6 = 0.10;

  // Controller gains
  parameter Real Kp1 = 80.0;
  parameter Real Kp2 = 400.0;
  parameter Real Kp3 = 300.0;
  parameter Real Kp4 = 20.0;
  parameter Real Kp5 = 50.0;
  parameter Real Kp6 = 20.0;
  parameter Real Kd1 = 16.0;
  parameter Real Kd2 = 80.0;
  parameter Real Kd3 = 60.0;
  parameter Real Kd4 = 4.0;
  parameter Real Kd5 = 10.0;
  parameter Real Kd6 = 4.0;

  // Reference trajectory
  parameter Real omegaRef = 2.0;
  parameter Real zetaRef = 1.0;

  // Force regulation
  parameter Real fNormalRef = 20.0 "regulated normal grasp force";
  parameter Real KfForce = 0.00040 "force-to-shoulder-reference gain";
  parameter Real TfForce = 0.05 "force regulation filter time constant";

  // Contact models
  parameter Real kContact = 5000.0 "tool-object normal contact stiffness";
  parameter Real dContact = 100.0 "tool-object normal contact damping";
  parameter Real kTable = 20000.0 "table-object normal contact stiffness";
  parameter Real zetaTable = -Modelica.Math.log(restitutionTable)/sqrt(Modelica.Constants.pi^2 + Modelica.Math.log(restitutionTable)^2);
  parameter Real dTable = 2.0*zetaTable*sqrt(kTable*mObj);
  parameter Real kTangential = 2000.0 "grasp tangential stiffness";
  parameter Real dTangential = 20.0 "grasp tangential damping";
  parameter Real vSmall = 0.01 "table friction regularization velocity";

  // Initial and grasp joint configurations
  parameter Real q1_0 = 0.0;
  parameter Real q2_0 = 0.40;
  parameter Real q3_0 = -0.80;
  parameter Real q4_0 = 0.0;
  parameter Real q5_0 = 0.40;
  parameter Real q6_0 = 0.0;

  parameter Real q1_g = 0.0;
  parameter Real q2_g = -1.40;
  parameter Real q3_g = 1.00;
  parameter Real q4_g = 0.0;
  parameter Real q5_g = 0.40;
  parameter Real q6_g = 0.0;

  // Derived target pose
  parameter Real xTarget = (L2*cos(q2_g) + L3*cos(q2_g + q3_g) + Ltool*cos(q2_g + q3_g + q5_g))*cos(q1_g);
  parameter Real zTarget = H0 + L2*sin(q2_g) + L3*sin(q2_g + q3_g) + Ltool*sin(q2_g + q3_g + q5_g);
  parameter Real zTopTarget = 2.0*hObj "initial object top height";
  parameter Real zObjStart = hObj - mObj*gAccel/kTable "static table contact initial height";

  // Actuator state outputs
  output Real q1(start=q1_0) "joint1 angle";
  output Real q2(start=q2_0) "joint2 angle";
  output Real q3(start=q3_0) "joint3 angle";
  output Real q4(start=q4_0) "joint4 angle";
  output Real q5(start=q5_0) "joint5 angle";
  output Real q6(start=q6_0) "joint6 angle";
  output Real dq1(start=0.0) "joint1 velocity";
  output Real dq2(start=0.0) "joint2 velocity";
  output Real dq3(start=0.0) "joint3 velocity";
  output Real dq4(start=0.0) "joint4 velocity";
  output Real dq5(start=0.0) "joint5 velocity";
  output Real dq6(start=0.0) "joint6 velocity";
  output Real tau1 "joint1 actuator effort";
  output Real tau2 "joint2 actuator effort";
  output Real tau3 "joint3 actuator effort";
  output Real tau4 "joint4 actuator effort";
  output Real tau5 "joint5 actuator effort";
  output Real tau6 "joint6 actuator effort";

  // Command traces
  output Real tau_cmd1 "joint1 commanded effort";
  output Real tau_cmd2 "joint2 commanded effort";
  output Real tau_cmd3 "joint3 commanded effort";
  output Real tau_cmd4 "joint4 commanded effort";
  output Real tau_cmd5 "joint5 commanded effort";
  output Real tau_cmd6 "joint6 commanded effort";
  output Real qr1 "joint1 reference";
  output Real qr2 "joint2 reference";
  output Real qr3 "joint3 reference";
  output Real qr4 "joint4 reference";
  output Real qr5 "joint5 reference";
  output Real qr6 "joint6 reference";
  output Real controlPhase "1 = impedance motion, 2 = force regulation";

  // Sensor traces
  output Real sensorForceX "wrist sensor force x";
  output Real sensorForceY "wrist sensor force y";
  output Real sensorForceZ "wrist sensor force z";
  output Real sensorTorqueX "wrist sensor torque x";
  output Real sensorTorqueY "wrist sensor torque y";
  output Real sensorTorqueZ "wrist sensor torque z";
  output Real normalContactForceTool "tool-object normal contact force";
  output Real normalContactForceTable "object-table normal contact force";

  // Object pose traces
  output Real x_o(start=xTarget) "object x position";
  output Real y_o "object y position";
  output Real z_o(start=zObjStart) "object z position";
  output Real phi_o(start=0.0) "object roll";
  output Real theta_o(start=0.0) "object pitch";
  output Real psi_o(start=0.0) "object yaw";
  output Real trackingError "primary end-effector tracking error";

  // Internal dynamic states
  Real vx_o(start=0.0) "object x velocity";
  Real vz_o(start=0.0) "object z velocity";
  Real qr1b(start=q1_0);
  Real vr1(start=0.0);
  Real qr2b(start=q2_0);
  Real vr2(start=0.0);
  Real qr3b(start=q3_0);
  Real vr3(start=0.0);
  Real qr4b(start=q4_0);
  Real vr4(start=0.0);
  Real qr5b(start=q5_0);
  Real vr5(start=0.0);
  Real qr6b(start=q6_0);
  Real vr6(start=0.0);
  Real qr2_force(start=0.0);
  Real dqr1, dqr2, dqr3, dqr4, dqr5, dqr6;
  Real qr2_force_target;
  Boolean forceRegActive;

  // Kinematics and contact variables
  Real r_ee, p_ee_x, p_ee_y, p_ee_z;
  Real drdq2, drdq3, drdq5, dzdq2, dzdq3, dzdq5;
  Real drdt, v_ee_x, v_ee_y, v_ee_z;
  Real zTop;
  Real penetration, fTool_raw, fTool;
  Real N_table_raw, N_table;
  Real F_grasp_raw, F_grasp_x;
  Real F_table_friction;
  Real Fdisturbance;
  Real gGrav2, gGrav3, gGrav5;
  Real e_x, e_y, e_z;
  Real objectDisplacement;

equation
  // Reference trajectory (impedance motion target)
  der(qr1b) = vr1;
  der(vr1) = omegaRef^2*(q1_g - qr1b) - 2.0*zetaRef*omegaRef*vr1;
  der(qr2b) = vr2;
  der(vr2) = omegaRef^2*(q2_g - qr2b) - 2.0*zetaRef*omegaRef*vr2;
  der(qr3b) = vr3;
  der(vr3) = omegaRef^2*(q3_g - qr3b) - 2.0*zetaRef*omegaRef*vr3;
  der(qr4b) = vr4;
  der(vr4) = omegaRef^2*(q4_g - qr4b) - 2.0*zetaRef*omegaRef*vr4;
  der(qr5b) = vr5;
  der(vr5) = omegaRef^2*(q5_g - qr5b) - 2.0*zetaRef*omegaRef*vr5;
  der(qr6b) = vr6;
  der(vr6) = omegaRef^2*(q6_g - qr6b) - 2.0*zetaRef*omegaRef*vr6;

  // Force regulation reference offset
  forceRegActive = fTool > 0.5;
  qr2_force_target = if forceRegActive then -KfForce*(fNormalRef - fTool) else 0.0;
  der(qr2_force) = (qr2_force_target - qr2_force)/TfForce;

  qr1 = qr1b;
  qr2 = qr2b + qr2_force;
  qr3 = qr3b;
  qr4 = qr4b;
  qr5 = qr5b;
  qr6 = qr6b;

  dqr1 = vr1;
  dqr2 = vr2 + (qr2_force_target - qr2_force)/TfForce;
  dqr3 = vr3;
  dqr4 = vr4;
  dqr5 = vr5;
  dqr6 = vr6;

  controlPhase = if forceRegActive then 2.0 else 1.0;

  // Gravity torques for pitch joints
  gGrav2 = gAccel*(mLink2*L2cm*cos(q2) + mLink3*(L2*cos(q2) + L3cm*cos(q2+q3)) + mTool*(L2*cos(q2) + L3*cos(q2+q3) + Ltoolcm*cos(q2+q3+q5)));
  gGrav3 = gAccel*(mLink3*L3cm*cos(q2+q3) + mTool*(L3*cos(q2+q3) + Ltoolcm*cos(q2+q3+q5)));
  gGrav5 = gAccel*(mTool*Ltoolcm*cos(q2+q3+q5));

  // Impedance/force controller commands
  tau_cmd1 = Kp1*(qr1 - q1) + Kd1*(dqr1 - dq1);
  tau_cmd2 = Kp2*(qr2 - q2) + Kd2*(dqr2 - dq2) + gGrav2;
  tau_cmd3 = Kp3*(qr3 - q3) + Kd3*(dqr3 - dq3) + gGrav3;
  tau_cmd4 = Kp4*(qr4 - q4) + Kd4*(dqr4 - dq4);
  tau_cmd5 = Kp5*(qr5 - q5) + Kd5*(dqr5 - dq5) + gGrav5;
  tau_cmd6 = Kp6*(qr6 - q6) + Kd6*(dqr6 - dq6);

  // Saturated effort actuators
  tau1 = if tau_cmd1 > tauMax then tauMax elseif tau_cmd1 < -tauMax then -tauMax else tau_cmd1;
  tau2 = if tau_cmd2 > tauMax then tauMax elseif tau_cmd2 < -tauMax then -tauMax else tau_cmd2;
  tau3 = if tau_cmd3 > tauMax then tauMax elseif tau_cmd3 < -tauMax then -tauMax else tau_cmd3;
  tau4 = if tau_cmd4 > tauMax then tauMax elseif tau_cmd4 < -tauMax then -tauMax else tau_cmd4;
  tau5 = if tau_cmd5 > tauMax then tauMax elseif tau_cmd5 < -tauMax then -tauMax else tau_cmd5;
  tau6 = if tau_cmd6 > tauMax then tauMax elseif tau_cmd6 < -tauMax then -tauMax else tau_cmd6;

  // Joint dynamics
  der(q1) = dq1;
  J1*der(dq1) = tau1 - b1*dq1;
  der(q2) = dq2;
  J2*der(dq2) = tau2 - b2*dq2 - gGrav2;
  der(q3) = dq3;
  J3*der(dq3) = tau3 - b3*dq3 - gGrav3;
  der(q4) = dq4;
  J4*der(dq4) = tau4 - b4*dq4;
  der(q5) = dq5;
  J5*der(dq5) = tau5 - b5*dq5 - gGrav5;
  der(q6) = dq6;
  J6*der(dq6) = tau6 - b6*dq6;

  // Forward kinematics
  r_ee = L2*cos(q2) + L3*cos(q2+q3) + Ltool*cos(q2+q3+q5);
  p_ee_x = r_ee*cos(q1);
  p_ee_y = r_ee*sin(q1);
  p_ee_z = H0 + L2*sin(q2) + L3*sin(q2+q3) + Ltool*sin(q2+q3+q5);

  drdq2 = -L2*sin(q2) - L3*sin(q2+q3) - Ltool*sin(q2+q3+q5);
  dzdq2 = L2*cos(q2) + L3*cos(q2+q3) + Ltool*cos(q2+q3+q5);
  drdq3 = -L3*sin(q2+q3) - Ltool*sin(q2+q3+q5);
  dzdq3 = L3*cos(q2+q3) + Ltool*cos(q2+q3+q5);
  drdq5 = -Ltool*sin(q2+q3+q5);
  dzdq5 = Ltool*cos(q2+q3+q5);

  drdt = drdq2*dq2 + drdq3*dq3 + drdq5*dq5;
  v_ee_x = drdt*cos(q1) - r_ee*sin(q1)*dq1;
  v_ee_y = drdt*sin(q1) + r_ee*cos(q1)*dq1;
  v_ee_z = dzdq2*dq2 + dzdq3*dq3 + dzdq5*dq5;

  // Object pose dynamics
  y_o = 0.0;
  der(phi_o) = 0.0;
  der(theta_o) = 0.0;
  der(psi_o) = 0.0;
  der(x_o) = vx_o;
  der(z_o) = vz_o;
  mObj*der(vx_o) = F_grasp_x + Fdisturbance + F_table_friction;
  mObj*der(vz_o) = N_table - mObj*gAccel - fTool;

  zTop = z_o + hObj;
  objectDisplacement = x_o - xTarget;

  // Disturbance during middle third
  Fdisturbance = if time >= tMidStart and time <= tMidEnd then Fdist else 0.0;

  // Tool-object normal contact
  penetration = zTop - p_ee_z;
  fTool_raw = kContact*penetration - dContact*(v_ee_z - vz_o);
  fTool = if collisionEnabled then max(0.0, fTool_raw) else 0.0;

  // Table normal contact
  N_table_raw = kTable*(hObj - z_o) - dTable*vz_o;
  N_table = if collisionEnabled then max(0.0, N_table_raw) else 0.0;

  // Table friction
  F_table_friction = -muTable*N_table*tanh(vx_o/vSmall);

  // Grasp tangential contact force, friction-limited
  F_grasp_raw = kTangential*(p_ee_x - x_o) + dTangential*(v_ee_x - vx_o);
  F_grasp_x = if (collisionEnabled and fTool > 0.0) then
    (if F_grasp_raw > muTool*fTool then muTool*fTool
     elseif F_grasp_raw < -muTool*fTool then -muTool*fTool
     else F_grasp_raw)
  else 0.0;

  // Six-axis wrist sensor measurement
  sensorForceX = -F_grasp_x;
  sensorForceY = 0.0;
  sensorForceZ = fTool;
  sensorTorqueX = 0.0;
  sensorTorqueY = 0.0;
  sensorTorqueZ = 0.0;

  normalContactForceTool = fTool;
  normalContactForceTable = N_table;

  // Tracking error
  e_x = p_ee_x - xTarget;
  e_y = p_ee_y - 0.0;
  e_z = p_ee_z - zTopTarget;
  trackingError = sqrt(e_x*e_x + e_y*e_y + e_z*e_z);

  // Requirement assertions
  assert(abs(tau1) <= tauMax + 1e-6, "effort bound violated joint 1");
  assert(abs(tau2) <= tauMax + 1e-6, "effort bound violated joint 2");
  assert(abs(tau3) <= tauMax + 1e-6, "effort bound violated joint 3");
  assert(abs(tau4) <= tauMax + 1e-6, "effort bound violated joint 4");
  assert(abs(tau5) <= tauMax + 1e-6, "effort bound violated joint 5");
  assert(abs(tau6) <= tauMax + 1e-6, "effort bound violated joint 6");

  assert(abs(q1) <= qTravelMax + 1e-6, "travel bound violated joint 1");
  assert(abs(q2) <= qTravelMax + 1e-6, "travel bound violated joint 2");
  assert(abs(q3) <= qTravelMax + 1e-6, "travel bound violated joint 3");
  assert(abs(q4) <= qTravelMax + 1e-6, "travel bound violated joint 4");
  assert(abs(q5) <= qTravelMax + 1e-6, "travel bound violated joint 5");
  assert(abs(q6) <= qTravelMax + 1e-6, "travel bound violated joint 6");

  assert(fTool >= 0.0, "stable contact violated: negative normal force");
  assert(N_table >= 0.0, "stable contact violated: negative table normal force");
  assert(time < 5.0 or fTool >= fNormalMin, "grasp loss or unstable contact after acquisition");
  assert(abs(objectDisplacement) <= objectDisplacementMax + 1e-6, "object displacement bound violated");
  assert(time < tTrack or trackingError <= eTrackMax, "primary tracking error bound violated after 9.1 s");

  annotation(experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6));
end ContactArmGraspD;