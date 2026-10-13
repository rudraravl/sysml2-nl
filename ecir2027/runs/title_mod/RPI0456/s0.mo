model ContactArmPolishF
  "Contact-rich polishing scenario: 6R Z-Y-Y-X-Y-X arm, curved compliant workpiece, tangential trajectory and normal-force control"
  // Joint axes sequence: Z-Y-Y-X-Y-X (axis1=Z, axis2=Y, axis3=Y, axis4=X, axis5=Y, axis6=X).
  // Arm link masses, inertias, capsule dimensions, exact curvature, controller gains, and tool dimensions are not specified;
  // nominal tunable values below are used only to make the model executable and are labeled where relevant.

  constant Real eps = 1.0e-6;

  // Mission, context, and verification facts from the requirement
  parameter Real L_path = 0.50 "surface path length [m]";
  parameter Real mu = 0.50 "workpiece friction coefficient [1]";
  parameter Real tauMax = 146.0 "maximum joint effort [N.m]";
  parameter Real Ts = 0.002 "control and trace period, 500 Hz [s]";
  parameter Real tFinal = 20.0 "mission duration [s]";
  parameter Real tDistStart = tFinal/3.0 "start of middle-third disturbance [s]";
  parameter Real tDistEnd = 2.0*tFinal/3.0 "end of middle-third disturbance [s]";
  parameter Real F_dist_magnitude = 10.2 "surface-force disturbance magnitude [N]";
  parameter Real F_min = 12.0 "minimum normal force [N]";
  parameter Real F_max = 30.0 "maximum normal force [N]";
  parameter Real errThreshold = 0.016 "primary tracking-error threshold after 13 s [m]";

  // Nominal values not specified by the requirement
  parameter Real F_n_ref = 20.0 "constant normal-force setpoint selected inside the required 12-30 N band [N]";
  parameter Real tRamp = 10.0 "nominal path ramp time [s]";
  parameter Real kappa = 0.20 "nominal fixed workpiece curvature [1/m]";
  parameter Real k_c = 4000.0 "nominal normal contact stiffness [N/m]";
  parameter Real d_c = 150.0 "nominal normal contact damping [N.s/m]";
  parameter Real m_t = 1.0 "nominal tangential effective mass [kg]";
  parameter Real m_n = 1.0 "nominal normal effective mass [kg]";
  parameter Real v_reg = 0.01 "friction velocity regularization [m/s]";
  parameter Real toolLength = 0.05 "nominal rigid replaceable tool length [m]";
  parameter Real toolMass = 0.10 "nominal rigid replaceable tool mass [kg]";
  parameter Real qMax = Modelica.Constants.pi "nominal revolute travel limit; exact joint bound not specified [rad]";

  // Tangential trajectory-control gains
  parameter Real Kp_t = 4000.0 "path proportional gain [N/m]";
  parameter Real Kd_t = 120.0 "path derivative gain [N.s/m]";
  parameter Real Ki_t = 1000.0 "path integral gain [N/(m.s)]";
  parameter Real intMax_t = 0.05 "path integral clamp [m.s]";

  // Normal-force regulation gains
  parameter Real Kp_n = 2.0 "normal-force proportional gain [N/N]";
  parameter Real Kd_n = 2.0 "normal velocity damping gain [N.s/m]";

  // Joint actuator and encoder parameters
  parameter Real J1 = 0.10 "joint 1 inertia [kg.m2]";
  parameter Real J2 = 0.10 "joint 2 inertia [kg.m2]";
  parameter Real J3 = 0.10 "joint 3 inertia [kg.m2]";
  parameter Real J4 = 0.10 "joint 4 inertia [kg.m2]";
  parameter Real J5 = 0.10 "joint 5 inertia [kg.m2]";
  parameter Real J6 = 0.10 "joint 6 inertia [kg.m2]";
  parameter Real b1 = 0.20 "joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.20 "joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 0.20 "joint 3 viscous damping [N.m.s/rad]";
  parameter Real b4 = 0.20 "joint 4 viscous damping [N.m.s/rad]";
  parameter Real b5 = 0.20 "joint 5 viscous damping [N.m.s/rad]";
  parameter Real b6 = 0.20 "joint 6 viscous damping [N.m.s/rad]";
  parameter Real Kq1 = 50.0 "joint 1 position gain [N.m/rad]";
  parameter Real Kq2 = 50.0 "joint 2 position gain [N.m/rad]";
  parameter Real Kq3 = 50.0 "joint 3 position gain [N.m/rad]";
  parameter Real Kq4 = 50.0 "joint 4 position gain [N.m/rad]";
  parameter Real Kq5 = 50.0 "joint 5 position gain [N.m/rad]";
  parameter Real Kq6 = 50.0 "joint 6 position gain [N.m/rad]";
  parameter Real Kd1 = 5.0 "joint 1 velocity gain [N.m.s/rad]";
  parameter Real Kd2 = 5.0 "joint 2 velocity gain [N.m.s/rad]";
  parameter Real Kd3 = 5.0 "joint 3 velocity gain [N.m.s/rad]";
  parameter Real Kd4 = 5.0 "joint 4 velocity gain [N.m.s/rad]";
  parameter Real Kd5 = 5.0 "joint 5 velocity gain [N.m.s/rad]";
  parameter Real Kd6 = 5.0 "joint 6 velocity gain [N.m.s/rad]";
  parameter Real Bt1 = 0.05 "joint 1 tangential-force allocation [N.m/N]";
  parameter Real Bt2 = 0.05 "joint 2 tangential-force allocation [N.m/N]";
  parameter Real Bt3 = 0.05 "joint 3 tangential-force allocation [N.m/N]";
  parameter Real Bt4 = 0.05 "joint 4 tangential-force allocation [N.m/N]";
  parameter Real Bt5 = 0.05 "joint 5 tangential-force allocation [N.m/N]";
  parameter Real Bt6 = 0.05 "joint 6 tangential-force allocation [N.m/N]";
  parameter Real Bn1 = 0.01 "joint 1 normal-force allocation [N.m/N]";
  parameter Real Bn2 = 0.01 "joint 2 normal-force allocation [N.m/N]";
  parameter Real Bn3 = 0.01 "joint 3 normal-force allocation [N.m/N]";
  parameter Real Bn4 = 0.01 "joint 4 normal-force allocation [N.m/N]";
  parameter Real Bn5 = 0.01 "joint 5 normal-force allocation [N.m/N]";
  parameter Real Bn6 = 0.01 "joint 6 normal-force allocation [N.m/N]";
  parameter Real A1 = 1.00 "joint 1 inverse-kinematic slope [rad/m]";
  parameter Real A2 = 0.20 "joint 2 inverse-kinematic slope [rad/m]";
  parameter Real A3 = -0.20 "joint 3 inverse-kinematic slope [rad/m]";
  parameter Real A4 = 0.10 "joint 4 inverse-kinematic slope [rad/m]";
  parameter Real A5 = -0.10 "joint 5 inverse-kinematic slope [rad/m]";
  parameter Real A6 = 0.05 "joint 6 inverse-kinematic slope [rad/m]";
  parameter Real q0_1 = 0.0 "joint 1 offset [rad]";
  parameter Real q0_2 = 0.0 "joint 2 offset [rad]";
  parameter Real q0_3 = 0.0 "joint 3 offset [rad]";
  parameter Real q0_4 = 0.0 "joint 4 offset [rad]";
  parameter Real q0_5 = 0.0 "joint 5 offset [rad]";
  parameter Real q0_6 = 0.0 "joint 6 offset [rad]";

  // Capsule link dimensions: nominal placeholders, not specified by the requirement
  parameter Real capsuleLength1 = 0.15 "nominal [m]";
  parameter Real capsuleLength2 = 0.15 "nominal [m]";
  parameter Real capsuleLength3 = 0.15 "nominal [m]";
  parameter Real capsuleLength4 = 0.10 "nominal [m]";
  parameter Real capsuleLength5 = 0.10 "nominal [m]";
  parameter Real capsuleLength6 = 0.08 "nominal [m]";
  parameter Real capsuleRadius1 = 0.02 "nominal [m]";
  parameter Real capsuleRadius2 = 0.02 "nominal [m]";
  parameter Real capsuleRadius3 = 0.02 "nominal [m]";
  parameter Real capsuleRadius4 = 0.015 "nominal [m]";
  parameter Real capsuleRadius5 = 0.015 "nominal [m]";
  parameter Real capsuleRadius6 = 0.012 "nominal [m]";

  // Task-space physical states
  Real s_path(start=0.0) "actual tangential path coordinate [m]";
  Real v_path(start=0.0) "tangential path velocity [m/s]";
  Real n_pen(start=0.005) "normal penetration into compliant workpiece [m]";
  Real v_n(start=0.0) "normal penetration velocity [m/s]";

  // Joint states and encoders
  Real q1(start=0.0) "joint 1 encoder angle [rad]";
  Real q2(start=0.0) "joint 2 encoder angle [rad]";
  Real q3(start=0.0) "joint 3 encoder angle [rad]";
  Real q4(start=0.0) "joint 4 encoder angle [rad]";
  Real q5(start=0.0) "joint 5 encoder angle [rad]";
  Real q6(start=0.0) "joint 6 encoder angle [rad]";
  Real w1(start=0.0) "joint 1 velocity [rad/s]";
  Real w2(start=0.0) "joint 2 velocity [rad/s]";
  Real w3(start=0.0) "joint 3 velocity [rad/s]";
  Real w4(start=0.0) "joint 4 velocity [rad/s]";
  Real w5(start=0.0) "joint 5 velocity [rad/s]";
  Real w6(start=0.0) "joint 6 velocity [rad/s]";

  // Reference and command traces
  Real s_ref "tangential path reference [m]";
  Real v_ref "tangential path reference velocity [m/s]";
  Real q_ref1 "joint 1 reference [rad]";
  Real q_ref2 "joint 2 reference [rad]";
  Real q_ref3 "joint 3 reference [rad]";
  Real q_ref4 "joint 4 reference [rad]";
  Real q_ref5 "joint 5 reference [rad]";
  Real q_ref6 "joint 6 reference [rad]";
  Real rawTau1 "unsaturated joint 1 effort command [N.m]";
  Real rawTau2 "unsaturated joint 2 effort command [N.m]";
  Real rawTau3 "unsaturated joint 3 effort command [N.m]";
  Real rawTau4 "unsaturated joint 4 effort command [N.m]";
  Real rawTau5 "unsaturated joint 5 effort command [N.m]";
  Real rawTau6 "unsaturated joint 6 effort command [N.m]";
  Real tau1 "saturated joint 1 actuator effort [N.m]";
  Real tau2 "saturated joint 2 actuator effort [N.m]";
  Real tau3 "saturated joint 3 actuator effort [N.m]";
  Real tau4 "saturated joint 4 actuator effort [N.m]";
  Real tau5 "saturated joint 5 actuator effort [N.m]";
  Real tau6 "saturated joint 6 actuator effort [N.m]";

  // Contact and disturbance
  Real F_n "normal contact force [N]";
  Real F_friction "tangential friction force [N]";
  Real F_disturbance "applied surface-force disturbance [N]";
  Real disturbanceWindow "middle-third disturbance window [1]";

  // Tool-tip pose feedback
  Real surfaceX "workpiece surface x coordinate [m]";
  Real surfaceY "workpiece surface y coordinate [m]";
  Real tipPoseX "tool-tip x position [m]";
  Real tipPoseY "tool-tip y position [m]";
  Real tipPoseZ "tool-tip z position [m]";
  Real tipYaw "tool-tip yaw angle [rad]";
  Real tipPitch "tool-tip pitch angle [rad]";
  Real tipRoll "tool-tip roll angle [rad]";

  // Six-axis wrist wrench feedback
  Real wrenchFx "wrist force x [N]";
  Real wrenchFy "wrist force y [N]";
  Real wrenchFz "wrist force z [N]";
  Real wrenchTx "wrist torque x [N.m]";
  Real wrenchTy "wrist torque y [N.m]";
  Real wrenchTz "wrist torque z [N.m]";

  // Verification variables
  Real pathError "absolute tangential path error [m]";
  Real primaryTrackingError "primary tracking error [m]";
  Real continuousContactFlag "1.0 if contact is continuous, else 0.0 [1]";

  // Discrete 500 Hz controller state
  discrete Real s_ref_d(start=0.0) "sampled path reference [m]";
  discrete Real v_ref_d(start=0.0) "sampled path reference velocity [m/s]";
  discrete Real e_s_d(start=0.0) "sampled path error [m]";
  discrete Real int_e_s(start=0.0) "sampled path integral [m.s]";
  discrete Real u_t(start=0.0) "tangential control force command [N]";
  discrete Real e_F_d(start=0.0) "sampled normal-force error [N]";
  discrete Real u_n(start=20.0) "normal control force command [N]";

equation
  // Tangential trajectory reference: smooth ramp over nominal tRamp, then hold L_path
  s_ref = if time < tRamp then 0.5*L_path*(1.0 - cos(Modelica.Constants.pi*time/tRamp)) else L_path;
  v_ref = if time < tRamp then 0.5*L_path*(Modelica.Constants.pi/tRamp)*sin(Modelica.Constants.pi*time/tRamp) else 0.0;

  // Task-space plant
  der(s_path) = v_path;
  der(n_pen) = v_n;
  F_n = if n_pen > 0.0 then k_c*n_pen + d_c*v_n else 0.0;
  F_friction = mu*F_n*Modelica.Math.tanh(v_path/v_reg);
  disturbanceWindow = if time >= tDistStart and time <= tDistEnd then 1.0 else 0.0;
  F_disturbance = -F_dist_magnitude*disturbanceWindow;
  m_t*der(v_path) = u_t - F_friction + F_disturbance;
  m_n*der(v_n) = u_n - F_n;

  // Joint kinematic commands from reduced inverse kinematics
  q_ref1 = q0_1 + A1*s_ref;
  q_ref2 = q0_2 + A2*s_ref;
  q_ref3 = q0_3 + A3*s_ref;
  q_ref4 = q0_4 + A4*s_ref;
  q_ref5 = q0_5 + A5*s_ref;
  q_ref6 = q0_6 + A6*s_ref;

  // Six saturated joint effort actuators
  rawTau1 = Kq1*(q_ref1 - q1) - Kd1*w1 + Bt1*u_t + Bn1*u_n;
  rawTau2 = Kq2*(q_ref2 - q2) - Kd2*w2 + Bt2*u_t + Bn2*u_n;
  rawTau3 = Kq3*(q_ref3 - q3) - Kd3*w3 + Bt3*u_t + Bn3*u_n;
  rawTau4 = Kq4*(q_ref4 - q4) - Kd4*w4 + Bt4*u_t + Bn4*u_n;
  rawTau5 = Kq5*(q_ref5 - q5) - Kd5*w5 + Bt5*u_t + Bn5*u_n;
  rawTau6 = Kq6*(q_ref6 - q6) - Kd6*w6 + Bt6*u_t + Bn6*u_n;
  tau1 = if rawTau1 > tauMax then tauMax elseif rawTau1 < -tauMax then -tauMax else rawTau1;
  tau2 = if rawTau2 > tauMax then tauMax elseif rawTau2 < -tauMax then -tauMax else rawTau2;
  tau3 = if rawTau3 > tauMax then tauMax elseif rawTau3 < -tauMax then -tauMax else rawTau3;
  tau4 = if rawTau4 > tauMax then tauMax elseif rawTau4 < -tauMax then -tauMax else rawTau4;
  tau5 = if rawTau5 > tauMax then tauMax elseif rawTau5 < -tauMax then -tauMax else rawTau5;
  tau6 = if rawTau6 > tauMax then tauMax elseif rawTau6 < -tauMax then -tauMax else rawTau6;

  // Joint dynamics
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(q4) = w4;
  der(q5) = w5;
  der(q6) = w6;
  J1*der(w1) = tau1 - b1*w1;
  J2*der(w2) = tau2 - b2*w2;
  J3*der(w3) = tau3 - b3*w3;
  J4*der(w4) = tau4 - b4*w4;
  J5*der(w5) = tau5 - b5*w5;
  J6*der(w6) = tau6 - b6*w6;

  // Curved workpiece and tool-tip pose
  surfaceX = s_path;
  surfaceY = 0.5*kappa*s_path*s_path;
  tipPoseX = surfaceX;
  tipPoseY = surfaceY - n_pen;
  tipPoseZ = 0.0;
  tipYaw = Modelica.Math.atan2(kappa*s_path, 1.0);
  tipPitch = 0.0;
  tipRoll = q6;

  // Six-axis wrist wrench
  wrenchFx = F_friction + F_disturbance;
  wrenchFy = F_n;
  wrenchFz = 0.0;
  wrenchTx = 0.0;
  wrenchTy = 0.0;
  wrenchTz = wrenchFx*toolLength;

  // Verification metrics
  pathError = abs(s_path - s_ref);
  primaryTrackingError = pathError;
  continuousContactFlag = if n_pen > 0.0 and F_n > 0.0 then 1.0 else 0.0;

  // 500 Hz tangential trajectory control with normal-force regulation
  when sample(0.0, Ts) loop
    s_ref_d = s_ref;
    v_ref_d = v_ref;
    e_s_d = s_ref_d - s_path;
    int_e_s = max(-intMax_t, min(pre(int_e_s) + Ts*e_s_d, intMax_t));
    u_t = Kp_t*e_s_d + Kd_t*(v_ref_d - v_path) + Ki_t*pre(int_e_s);
    e_F_d = F_n_ref - F_n;
    u_n = F_n_ref + Kp_n*e_F_d - Kd_n*v_n;
  end when;

  // Verification criteria
  assert(abs(q1) <= qMax + eps, "joint 1 travel bound violated");
  assert(abs(q2) <= qMax + eps, "joint 2 travel bound violated");
  assert(abs(q3) <= qMax + eps, "joint 3 travel bound violated");
  assert(abs(q4) <= qMax + eps, "joint 4 travel bound violated");
  assert(abs(q5) <= qMax + eps, "joint 5 travel bound violated");
  assert(abs(q6) <= qMax + eps, "joint 6 travel bound violated");
  assert(abs(tau1) <= tauMax + eps, "joint 1 effort bound violated");
  assert(abs(tau2) <= tauMax + eps, "joint 2 effort bound violated");
  assert(abs(tau3) <= tauMax + eps, "joint 3 effort bound violated");
  assert(abs(tau4) <= tauMax + eps, "joint 4 effort bound violated");
  assert(abs(tau5) <= tauMax + eps, "joint 5 effort bound violated");
  assert(abs(tau6) <= tauMax + eps, "joint 6 effort bound violated");
  assert(F_n >= F_min - eps and F_n <= F_max + eps, "normal force outside 12-30 N band");
  assert(continuousContactFlag > 0.5, "continuous contact lost");
  assert(time <= 13.0 or pathError <= errThreshold + eps, "primary tracking error after 13 s violated");

  // Finite physical, control, and sensor checks
  assert(abs(s_path) < 1.0e12 and abs(v_path) < 1.0e12 and abs(n_pen) < 1.0e12 and abs(v_n) < 1.0e12, "non-finite task state");
  assert(abs(F_n) < 1.0e12 and abs(F_friction) < 1.0e12 and abs(F_disturbance) < 1.0e12, "non-finite force value");
  assert(abs(u_t) < 1.0e12 and abs(u_n) < 1.0e12 and abs(int_e_s) < 1.0e12, "non-finite control value");
  assert(abs(q1) < 1.0e12 and abs(q2) < 1.0e12 and abs(q3) < 1.0e12 and abs(q4) < 1.0e12 and abs(q5) < 1.0e12 and abs(q6) < 1.0e12, "non-finite joint state");
  assert(abs(tau1) < 1.0e12 and abs(tau2) < 1.0e12 and abs(tau3) < 1.0e12 and abs(tau4) < 1.0e12 and abs(tau5) < 1.0e12 and abs(tau6) < 1.0e12, "non-finite effort value");

  annotation (experiment(StopTime=20.0, Interval=0.002, Tolerance=1.0e-6));
end ContactArmPolishF;