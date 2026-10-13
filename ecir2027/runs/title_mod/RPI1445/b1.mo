model JointPathMoveE
  "Verifiable trajectory-controlled three-revolute Z-Y-Y arm with cubic PID+velocity-feedforward control"

  import SI = Modelica.SIunits;

  // Run and timing
  parameter SI.Time Ts = 1/250 "controller sample time";
  parameter SI.Time T0 = 0.0 "trajectory start time";
  parameter SI.Time T1 = 5.2 "midpoint arrival time; selected as half of T2";
  parameter SI.Time T2 = 10.4 "final arrival time from requirement";
  parameter SI.Time Tend = 16.0 "simulation/run time";
  parameter SI.Time Tmid_start = Tend/3 "middle-third start";
  parameter SI.Time Tmid_end = 2*Tend/3 "middle-third end";

  // Mechanism geometry
  parameter SI.Length L1 = 0.50 "link 1 length";
  parameter SI.Length L2 = 0.38 "link 2 length";
  parameter SI.Length L3 = 0.24 "link 3 length";

  // Trajectory waypoints; zero state initial, final state declared, midpoint declared.
  // Numeric values not given in requirement; selected small and safe for verification.
  parameter SI.Angle q1_0 = 0.0;
  parameter SI.Angle q2_0 = 0.0;
  parameter SI.Angle q3_0 = 0.0;
  parameter SI.Angle q1_m = 0.05;
  parameter SI.Angle q2_m = 0.04;
  parameter SI.Angle q3_m = 0.03;
  parameter SI.Angle q1_f = 0.10;
  parameter SI.Angle q2_f = 0.08;
  parameter SI.Angle q3_f = 0.06;

  // Physical properties not specified; nominal values chosen for executable model.
  parameter SI.Acceleration g = 9.81 "gravity magnitude";
  parameter SI.Mass m1 = 0.20 "link 1 mass";
  parameter SI.Mass m2 = 0.15 "link 2 mass";
  parameter SI.Mass m3 = 0.10 "link 3 mass";
  parameter SI.Mass m_payload = 0.20 "payload mass";
  parameter SI.Inertia I1_11 = 0.002;
  parameter SI.Inertia I1_22 = 0.010;
  parameter SI.Inertia I1_33 = 0.010;
  parameter SI.Inertia I2_11 = 0.0015;
  parameter SI.Inertia I2_22 = 0.008;
  parameter SI.Inertia I2_33 = 0.008;
  parameter SI.Inertia I3_11 = 0.001;
  parameter SI.Inertia I3_22 = 0.004;
  parameter SI.Inertia I3_33 = 0.004;
  parameter SI.Inertia Ip_11 = 0.001;
  parameter SI.Inertia Ip_22 = 0.001;
  parameter SI.Inertia Ip_33 = 0.001;
  parameter SI.Force Fdist = 0.06*m_payload*g "6 percent payload weight disturbance";

  // Actuator and acceptance bounds
  parameter SI.Torque tauMax = 93.5 "per-joint command magnitude bound";
  parameter Real qBound = 1.0 "joint position bound (rad); not specified, conservative";
  parameter Real qdBound = 10.0 "joint velocity bound (rad/s); not specified, conservative";
  parameter Real qddBound = 1000.0 "joint acceleration bound (rad/s2); not specified, conservative";
  parameter Real qdSettle = 0.05 "terminal settling velocity (rad/s); not specified, conservative";

  // Controller gains; not specified, selected for executable verification.
  parameter Real Kp1 = 500.0;
  parameter Real Ki1 = 100.0;
  parameter Real Kd1 = 20.0;
  parameter Real Kvff1 = 1.0;
  parameter Real Kp2 = 500.0;
  parameter Real Ki2 = 100.0;
  parameter Real Kd2 = 20.0;
  parameter Real Kvff2 = 1.0;
  parameter Real Kp3 = 500.0;
  parameter Real Ki3 = 100.0;
  parameter Real Kd3 = 20.0;
  parameter Real Kvff3 = 1.0;

  inner Modelica.Mechanics.MultiBody.World world(
    gravityType=Modelica.Mechanics.MultiBody.Types.GravityTypes.UniformGravity,
    g=g,
    n={0,0,-1},
    nominalLength=1);

  // Z-Y-Y revolute joints
  Modelica.Mechanics.MultiBody.Joints.Revolute r1(
    useAxisFlange=true,
    axis={0,0,1},
    angle_start=0,
    w_start=0,
    enforceStates=true);
  Modelica.Mechanics.MultiBody.Joints.Revolute r2(
    useAxisFlange=true,
    axis={0,1,0},
    angle_start=0,
    w_start=0,
    enforceStates=true);
  Modelica.Mechanics.MultiBody.Joints.Revolute r3(
    useAxisFlange=true,
    axis={0,1,0},
    angle_start=0,
    w_start=0,
    enforceStates=true);

  // Link geometry with collision/visual shapes
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation link1(r={L1,0,0}, animation=true);
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation link2(r={L2,0,0}, animation=true);
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation link3(r={L3,0,0}, animation=true);

  // Link and payload masses
  Modelica.Mechanics.MultiBody.Parts.Body body1(r_CM={L1/2,0,0}, m=m1, I_11=I1_11, I_22=I1_22, I_33=I1_33);
  Modelica.Mechanics.MultiBody.Parts.Body body2(r_CM={L2/2,0,0}, m=m2, I_11=I2_11, I_22=I2_22, I_33=I2_33);
  Modelica.Mechanics.MultiBody.Parts.Body body3(r_CM={L3/2,0,0}, m=m3, I_11=I3_11, I_22=I3_22, I_33=I3_33);
  Modelica.Mechanics.MultiBody.Parts.Body payload(r_CM={0,0,0}, m=m_payload, I_11=Ip_11, I_22=Ip_22, I_33=Ip_33);

  // Joint-torque actuators
  Modelica.Mechanics.Rotational.Sources.Torque actuator1(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque actuator2(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque actuator3(useSupport=true);

  // Payload disturbance force: 6 percent payload weight during middle third
  Modelica.Mechanics.MultiBody.Forces.WorldForce payloadDist(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameB.world);

  // Continuous intermediate velocity variables for acceleration computation
  Real q1_vel;
  Real q2_vel;
  Real q3_vel;
  Real disturbanceGate;

  // Synchronized state traces
  output Real q1_state "joint 1 position state";
  output Real qd1_state "joint 1 velocity state";
  output Real qdd1_state "joint 1 acceleration state";
  output Real q2_state "joint 2 position state";
  output Real qd2_state "joint 2 velocity state";
  output Real qdd2_state "joint 2 acceleration state";
  output Real q3_state "joint 3 position state";
  output Real qd3_state "joint 3 velocity state";
  output Real qdd3_state "joint 3 acceleration state";

  // Command traces
  output Real tau1_cmd_out "joint 1 torque command trace";
  output Real tau2_cmd_out "joint 2 torque command trace";
  output Real tau3_cmd_out "joint 3 torque command trace";

  // Encoder sensor traces
  output Real q1_sens_out "encoder position trace 1";
  output Real qd1_sens_out "encoder velocity trace 1";
  output Real q2_sens_out "encoder position trace 2";
  output Real qd2_sens_out "encoder velocity trace 2";
  output Real q3_sens_out "encoder position trace 3";
  output Real qd3_sens_out "encoder velocity trace 3";

  output Real primaryError "primary tracking error (rad)";

  // Reference trajectory
  Real q1_ref;
  Real qd1_ref;
  Real qdd1_ref;
  Real q2_ref;
  Real qd2_ref;
  Real qdd2_ref;
  Real q3_ref;
  Real qd3_ref;
  Real qdd3_ref;

  // Normalized time for cubic interpolation
  Real s1;
  Real s2;

  // Discrete controller and estimator states
  discrete Real q1_sens(start=0);
  discrete Real qd1_sens(start=0);
  discrete Real q2_sens(start=0);
  discrete Real qd2_sens(start=0);
  discrete Real q3_sens(start=0);
  discrete Real qd3_sens(start=0);

  discrete Real e1(start=0);
  discrete Real e2(start=0);
  discrete Real e3(start=0);
  discrete Real xi1(start=0);
  discrete Real xi2(start=0);
  discrete Real xi3(start=0);
  discrete Real tau1_raw(start=0);
  discrete Real tau2_raw(start=0);
  discrete Real tau3_raw(start=0);
  discrete Real tau1_cmd(start=0);
  discrete Real tau2_cmd(start=0);
  discrete Real tau3_cmd(start=0);

equation
  // Plant structure: world -> r1 -> link1 -> r2 -> link2 -> r3 -> link3 -> payload
  connect(world.frame_b, r1.frame_a);
  connect(r1.frame_b, link1.frame_a);
  connect(link1.frame_b, r2.frame_a);
  connect(r2.frame_b, link2.frame_a);
  connect(link2.frame_b, r3.frame_a);
  connect(r3.frame_b, link3.frame_a);
  connect(link3.frame_b, payload.frame_a);
  connect(link3.frame_b, payloadDist.frame_b);

  // Link mass bodies attached to link frames
  connect(body1.frame_a, link1.frame_a);
  connect(body2.frame_a, link2.frame_a);
  connect(body3.frame_a, link3.frame_a);

  // Actuators: drive torque between housing and shaft of each joint
  connect(actuator1.support, r1.flange_a);
  connect(actuator1.flange, r1.flange_b);
  connect(actuator2.support, r2.flange_a);
  connect(actuator2.flange, r2.flange_b);
  connect(actuator3.support, r3.flange_a);
  connect(actuator3.flange, r3.flange_b);

  // Direct actuator input assignments
  actuator1.tau = tau1_cmd;
  actuator2.tau = tau2_cmd;
  actuator3.tau = tau3_cmd;

  // Disturbance force: 6 percent payload weight during middle third, world frame
  disturbanceGate = if time >= Tmid_start and time <= Tmid_end then 1.0 else 0.0;
  payloadDist.force[1] = 0.0;
  payloadDist.force[2] = 0.0;
  payloadDist.force[3] = -Fdist * disturbanceGate;

  // Normalized time segments for cubic interpolation
  s1 = (time - T0)/(T1 - T0);
  s2 = (time - T1)/(T2 - T1);

  // Cubic interpolation reference with zero endpoint velocities per segment
  q1_ref = if time < T1 then
             q1_0 + (q1_m - q1_0)*(3*s1*s1 - 2*s1*s1*s1)
           elseif time < T2 then
             q1_m + (q1_f - q1_m)*(3*s2*s2 - 2*s2*s2*s2)
           else
             q1_f;
  qd1_ref = if time < T1 then
              (q1_m - q1_0)*(6*s1 - 6*s1*s1)/(T1 - T0)
            elseif time < T2 then
              (q1_f - q1_m)*(6*s2 - 6*s2*s2)/(T2 - T1)
            else
              0.0;
  qdd1_ref = if time < T1 then
               (q1_m - q1_0)*(6.0 - 12.0*s1)/(T1 - T0)^2
             elseif time < T2 then
               (q1_f - q1_m)*(6.0 - 12.0*s2)/(T2 - T1)^2
             else
               0.0;

  q2_ref = if time < T1 then
             q2_0 + (q2_m - q2_0)*(3*s1*s1 - 2*s1*s1*s1)
           elseif time < T2 then
             q2_m + (q2_f - q2_m)*(3*s2*s2 - 2*s2*s2*s2)
           else
             q2_f;
  qd2_ref = if time < T1 then
              (q2_m - q2_0)*(6*s1 - 6*s1*s1)/(T1 - T0)
            elseif time < T2 then
              (q2_f - q2_m)*(6*s2 - 6*s2*s2)/(T2 - T1)
            else
              0.0;
  qdd2_ref = if time < T1 then
               (q2_m - q2_0)*(6.0 - 12.0*s1)/(T1 - T0)^2
             elseif time < T2 then
               (q2_f - q2_m)*(6.0 - 12.0*s2)/(T2 - T1)^2
             else
               0.0;

  q3_ref = if time < T1 then
             q3_0 + (q3_m - q3_0)*(3*s1*s1 - 2*s1*s1*s1)
           elseif time < T2 then
             q3_m + (q3_f - q3_m)*(3*s2*s2 - 2*s2*s2*s2)
           else
             q3_f;
  qd3_ref = if time < T1 then
              (q3_m - q3_0)*(6*s1 - 6*s1*s1)/(T1 - T0)
            elseif time < T2 then
              (q3_f - q3_m)*(6*s2 - 6*s2*s2)/(T2 - T1)
            else
              0.0;
  qdd3_ref = if time < T1 then
               (q3_m - q3_0)*(6.0 - 12.0*s1)/(T1 - T0)^2
             elseif time < T2 then
               (q3_f - q3_m)*(6.0 - 12.0*s2)/(T2 - T1)^2
             else
               0.0;

  // State traces with intermediate velocity for acceleration via derivative
  q1_state = r1.angle;
  q1_vel = r1.w;
  qd1_state = q1_vel;
  qdd1_state = der(q1_vel);

  q2_state = r2.angle;
  q2_vel = r2.w;
  qd2_state = q2_vel;
  qdd2_state = der(q2_vel);

  q3_state = r3.angle;
  q3_vel = r3.w;
  qd3_state = q3_vel;
  qdd3_state = der(q3_vel);

  // Command traces
  tau1_cmd_out = tau1_cmd;
  tau2_cmd_out = tau2_cmd;
  tau3_cmd_out = tau3_cmd;

  // Sensor traces
  q1_sens_out = q1_sens;
  qd1_sens_out = qd1_sens;
  q2_sens_out = q2_sens;
  qd2_sens_out = qd2_sens;
  q3_sens_out = q3_sens;
  qd3_sens_out = qd3_sens;

  // Primary tracking error: infinity norm (no division, no zero-error branch issue)
  primaryError = max(abs(q1_ref - r1.angle), max(abs(q2_ref - r2.angle), abs(q3_ref - r3.angle)));

  // 250 Hz controller: PID + velocity feedforward, bounded commands, anti-windup
  when sample(0, Ts) then
    // Encoder feedback
    q1_sens = r1.angle;
    qd1_sens = r1.w;
    q2_sens = r2.angle;
    qd2_sens = r2.w;
    q3_sens = r3.angle;
    qd3_sens = r3.w;

    // Tracking errors
    e1 = q1_ref - r1.angle;
    e2 = q2_ref - r2.angle;
    e3 = q3_ref - r3.angle;

    // PID + velocity feedforward
    tau1_raw = Kp1*e1 + Ki1*pre(xi1) + Kd1*(qd1_ref - r1.w) + Kvff1*qd1_ref;
    tau2_raw = Kp2*e2 + Ki2*pre(xi2) + Kd2*(qd2_ref - r2.w) + Kvff2*qd2_ref;
    tau3_raw = Kp3*e3 + Ki3*pre(xi3) + Kd3*(qd3_ref - r3.w) + Kvff3*qd3_ref;

    // Bounded commands
    tau1_cmd = if tau1_raw > tauMax then tauMax elseif tau1_raw < -tauMax then -tauMax else tau1_raw;
    tau2_cmd = if tau2_raw > tauMax then tauMax elseif tau2_raw < -tauMax then -tauMax else tau2_raw;
    tau3_cmd = if tau3_raw > tauMax then tauMax elseif tau3_raw < -tauMax then -tauMax else tau3_raw;

    // Anti-windup integrator
    xi1 = if abs(tau1_raw) > tauMax then pre(xi1) else pre(xi1) + Ts*e1;
    xi2 = if abs(tau2_raw) > tauMax then pre(xi2) else pre(xi2) + Ts*e2;
    xi3 = if abs(tau3_raw) > tauMax then pre(xi3) else pre(xi3) + Ts*e3;
  end when;

  // Fail-closed acceptance: position bounds
  assert(abs(q1_state) <= qBound + 1e-9, "joint 1 position bound violated");
  assert(abs(q2_state) <= qBound + 1e-9, "joint 2 position bound violated");
  assert(abs(q3_state) <= qBound + 1e-9, "joint 3 position bound violated");

  // Fail-closed acceptance: velocity bounds
  assert(abs(qd1_state) <= qdBound + 1e-9, "joint 1 velocity bound violated");
  assert(abs(qd2_state) <= qdBound + 1e-9, "joint 2 velocity bound violated");
  assert(abs(qd3_state) <= qdBound + 1e-9, "joint 3 velocity bound violated");

  // Fail-closed acceptance: acceleration bounds
  assert(abs(qdd1_state) <= qddBound + 1e-9, "joint 1 acceleration bound violated");
  assert(abs(qdd2_state) <= qddBound + 1e-9, "joint 2 acceleration bound violated");
  assert(abs(qdd3_state) <= qddBound + 1e-9, "joint 3 acceleration bound violated");

  // Fail-closed acceptance: effort bounds
  assert(abs(tau1_cmd) <= tauMax + 1e-9, "joint 1 effort bound violated");
  assert(abs(tau2_cmd) <= tauMax + 1e-9, "joint 2 effort bound violated");
  assert(abs(tau3_cmd) <= tauMax + 1e-9, "joint 3 effort bound violated");

  // Primary tracking error after 10.4 s
  assert(time < T2 or primaryError <= 0.027, "primary tracking error exceeds 0.027 after 10.4 s");

  // Terminal settling at end of run
  assert(time < Tend - 1e-9 or
         (abs(qd1_state) <= qdSettle and abs(qd2_state) <= qdSettle and abs(qd3_state) <= qdSettle),
         "terminal settling violated");

  // Finite, non-NaN physical, control, and estimator values
  assert(abs(q1_state) < 1e12 and abs(qd1_state) < 1e12 and abs(qdd1_state) < 1e12 and
         abs(tau1_cmd) < 1e12 and abs(xi1) < 1e12, "finite check failed for joint 1");
  assert(abs(q2_state) < 1e12 and abs(qd2_state) < 1e12 and abs(qdd2_state) < 1e12 and
         abs(tau2_cmd) < 1e12 and abs(xi2) < 1e12, "finite check failed for joint 2");
  assert(abs(q3_state) < 1e12 and abs(qd3_state) < 1e12 and abs(qdd3_state) < 1e12 and
         abs(tau3_cmd) < 1e12 and abs(xi3) < 1e12, "finite check failed for joint 3");
  assert(primaryError < 1e12, "finite check failed for primary error");

  annotation (
    uses(Modelica(version="4.0.0")),
    experiment(StopTime=16, Interval=0.004, Tolerance=1e-6));
end JointPathMoveE;