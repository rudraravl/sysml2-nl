model JointPathMoveE
  "Verifiable trajectory-controlled three-revolute Z-Y-Y arm with cubic PID+velocity-feedforward control"

  // Run and timing
  parameter Real Ts = 1/250 "controller sample time [s]";
  parameter Real T0 = 0.0 "trajectory start time [s]";
  parameter Real T1 = 5.2 "midpoint arrival time [s]";
  parameter Real T2 = 10.4 "final arrival time [s]";
  parameter Real Tend = 16.0 "simulation/run time [s]";
  parameter Real Tmid_start = Tend/3 "middle-third start [s]";
  parameter Real Tmid_end = 2*Tend/3 "middle-third end [s]";

  // Mechanism geometry
  parameter Real L1 = 0.50 "link 1 length [m]";
  parameter Real L2 = 0.38 "link 2 length [m]";
  parameter Real L3 = 0.24 "link 3 length [m]";

  // Trajectory waypoints
  parameter Real q1_0 = 0.0 "joint 1 initial angle [rad]";
  parameter Real q2_0 = 0.0 "joint 2 initial angle [rad]";
  parameter Real q3_0 = 0.0 "joint 3 initial angle [rad]";
  parameter Real q1_m = 0.05 "joint 1 midpoint angle [rad]";
  parameter Real q2_m = 0.04 "joint 2 midpoint angle [rad]";
  parameter Real q3_m = 0.03 "joint 3 midpoint angle [rad]";
  parameter Real q1_f = 0.10 "joint 1 final angle [rad]";
  parameter Real q2_f = 0.08 "joint 2 final angle [rad]";
  parameter Real q3_f = 0.06 "joint 3 final angle [rad]";

  // Physical properties (nominal values chosen for executable model)
  parameter Real g_val = 9.81 "gravity magnitude [m/s^2]";
  parameter Real m1 = 0.20 "link 1 mass [kg]";
  parameter Real m2 = 0.15 "link 2 mass [kg]";
  parameter Real m3 = 0.10 "link 3 mass [kg]";
  parameter Real m_payload = 0.20 "payload mass [kg]";
  parameter Real I1_11 = 0.002 "link 1 inertia [kg.m^2]";
  parameter Real I1_22 = 0.010 "link 1 inertia about Y [kg.m^2]";
  parameter Real I1_33 = 0.010 "link 1 inertia about Z [kg.m^2]";
  parameter Real I2_11 = 0.0015 "link 2 inertia [kg.m^2]";
  parameter Real I2_22 = 0.008 "link 2 inertia about Y [kg.m^2]";
  parameter Real I2_33 = 0.008 "link 2 inertia about Z [kg.m^2]";
  parameter Real I3_11 = 0.001 "link 3 inertia [kg.m^2]";
  parameter Real I3_22 = 0.004 "link 3 inertia about Y [kg.m^2]";
  parameter Real I3_33 = 0.004 "link 3 inertia about Z [kg.m^2]";
  parameter Real Ip_11 = 0.001 "payload inertia [kg.m^2]";
  parameter Real Ip_22 = 0.001 "payload inertia [kg.m^2]";
  parameter Real Ip_33 = 0.001 "payload inertia [kg.m^2]";
  parameter Real Fdist = 0.06*m_payload*g_val "6 percent payload weight disturbance [N]";

  // Actuator and acceptance bounds
  parameter Real tauMax = 93.5 "per-joint command magnitude bound [N.m]";
  parameter Real qBound = 1.0 "joint position bound [rad]";
  parameter Real qdBound = 10.0 "joint velocity bound [rad/s]";
  parameter Real qddBound = 1000.0 "joint acceleration bound [rad/s^2]";
  parameter Real qdSettle = 0.05 "terminal settling velocity [rad/s]";

  // Controller gains
  parameter Real Kp1 = 500 "joint 1 proportional gain [N.m/rad]";
  parameter Real Ki1 = 100 "joint 1 integral gain [N.m/(rad.s)]";
  parameter Real Kd1 = 20 "joint 1 derivative gain [N.m.s/rad]";
  parameter Real Kvff1 = 1.0 "joint 1 velocity feedforward [N.m.s/rad]";
  parameter Real Kp2 = 500 "joint 2 proportional gain [N.m/rad]";
  parameter Real Ki2 = 100 "joint 2 integral gain [N.m/(rad.s)]";
  parameter Real Kd2 = 20 "joint 2 derivative gain [N.m.s/rad]";
  parameter Real Kvff2 = 1.0 "joint 2 velocity feedforward [N.m.s/rad]";
  parameter Real Kp3 = 500 "joint 3 proportional gain [N.m/rad]";
  parameter Real Ki3 = 100 "joint 3 integral gain [N.m/(rad.s)]";
  parameter Real Kd3 = 20 "joint 3 derivative gain [N.m.s/rad]";
  parameter Real Kvff3 = 1.0 "joint 3 velocity feedforward [N.m.s/rad]";

  inner Modelica.Mechanics.MultiBody.World world(
    gravityType=Modelica.Mechanics.MultiBody.Types.GravityTypes.UniformGravity,
    g=g_val,
    n={0,0,-1},
    nominalLength=1,
    enableAnimation=true);

  Modelica.Mechanics.MultiBody.Joints.Revolute r1(
    useAxisFlange=true,
    axis={0,0,1},
    phi_start=0,
    w_start=0,
    stateSelect=StateSelect.prefer);
  Modelica.Mechanics.MultiBody.Joints.Revolute r2(
    useAxisFlange=true,
    axis={0,1,0},
    phi_start=0,
    w_start=0,
    stateSelect=StateSelect.prefer);
  Modelica.Mechanics.MultiBody.Joints.Revolute r3(
    useAxisFlange=true,
    axis={0,1,0},
    phi_start=0,
    w_start=0,
    stateSelect=StateSelect.prefer);

  Modelica.Mechanics.MultiBody.Parts.FixedTranslation link1(r={L1,0,0}, animation=true);
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation link2(r={L2,0,0}, animation=true);
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation link3(r={L3,0,0}, animation=true);

  Modelica.Mechanics.MultiBody.Parts.Body body1(r_CM={L1/2,0,0}, m=m1, I_11=I1_11, I_22=I1_22, I_33=I1_33);
  Modelica.Mechanics.MultiBody.Parts.Body body2(r_CM={L2/2,0,0}, m=m2, I_11=I2_11, I_22=I2_22, I_33=I2_33);
  Modelica.Mechanics.MultiBody.Parts.Body body3(r_CM={L3/2,0,0}, m=m3, I_11=I3_11, I_22=I3_22, I_33=I3_33);
  Modelica.Mechanics.MultiBody.Parts.Body payload(r_CM={0,0,0}, m=m_payload, I_11=Ip_11, I_22=Ip_22, I_33=Ip_33);

  Modelica.Mechanics.Rotational.Sources.Torque actuator1(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque actuator2(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque actuator3(useSupport=true);

  Modelica.Mechanics.MultiBody.Forces.WorldForce payloadDist;
  Modelica.Blocks.Sources.Constant zeroX(k=0);
  Modelica.Blocks.Sources.Constant zeroY(k=0);
  Modelica.Blocks.Sources.TimeTable distZ(
    table=[0,0; Tmid_start - 1e-9,0; Tmid_start,-Fdist; Tmid_end,-Fdist; Tmid_end + 1e-9,0; Tend,0],
    startTime=0);

  // Synchronized state traces
  output Real q1_state "joint 1 position [rad]";
  output Real qd1_state "joint 1 velocity [rad/s]";
  output Real qdd1_state "joint 1 acceleration [rad/s^2]";
  output Real q2_state "joint 2 position [rad]";
  output Real qd2_state "joint 2 velocity [rad/s]";
  output Real qdd2_state "joint 2 acceleration [rad/s^2]";
  output Real q3_state "joint 3 position [rad]";
  output Real qd3_state "joint 3 velocity [rad/s]";
  output Real qdd3_state "joint 3 acceleration [rad/s^2]";

  // Command traces
  output Real tau1_cmd_out "joint 1 torque command [N.m]";
  output Real tau2_cmd_out "joint 2 torque command [N.m]";
  output Real tau3_cmd_out "joint 3 torque command [N.m]";

  // Sensor traces
  output Real q1_sens_out "encoder position trace 1 [rad]";
  output Real qd1_sens_out "encoder velocity trace 1 [rad/s]";
  output Real q2_sens_out "encoder position trace 2 [rad]";
  output Real qd2_sens_out "encoder velocity trace 2 [rad/s]";
  output Real q3_sens_out "encoder position trace 3 [rad]";
  output Real qd3_sens_out "encoder velocity trace 3 [rad/s]";

  output Real primaryError "primary tracking error [rad]";

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
  // Plant structure
  connect(world.frame_b, r1.frame_a);
  connect(r1.frame_b, link1.frame_a);
  connect(link1.frame_b, r2.frame_a);
  connect(r2.frame_b, link2.frame_a);
  connect(link2.frame_b, r3.frame_a);
  connect(r3.frame_b, link3.frame_a);
  connect(link3.frame_b, payload.frame_a);

  connect(body1.frame_a, link1.frame_a);
  connect(body2.frame_a, link2.frame_a);
  connect(body3.frame_a, link3.frame_a);

  // Actuators: axis flange receives torque, support flange reacts
  connect(actuator1.flange, r1.flange_a);
  connect(actuator1.support, r1.flange_b);
  connect(actuator2.flange, r2.flange_a);
  connect(actuator2.support, r2.flange_b);
  connect(actuator3.flange, r3.flange_a);
  connect(actuator3.support, r3.flange_b);

  // Direct torque command equations
  actuator1.tau = tau1_cmd;
  actuator2.tau = tau2_cmd;
  actuator3.tau = tau3_cmd;

  // Payload disturbance
  connect(payloadDist.frame_b, link3.frame_b);
  connect(zeroX.y, payloadDist.force[1]);
  connect(zeroY.y, payloadDist.force[2]);
  connect(distZ.y, payloadDist.force[3]);

  // Cubic interpolation reference with zero endpoint velocities per segment
  q1_ref = if time < T1 then
             q1_0 + (q1_m - q1_0)*(3*((time - T0)/(T1 - T0))^2 - 2*((time - T0)/(T1 - T0))^3)
           elseif time < T2 then
             q1_m + (q1_f - q1_m)*(3*((time - T1)/(T2 - T1))^2 - 2*((time - T1)/(T2 - T1))^3)
           else
             q1_f;
  qd1_ref = if time < T1 then
              (q1_m - q1_0)*(6*((time - T0)/(T1 - T0)) - 6*((time - T0)/(T1 - T0))^2)/(T1 - T0)
            elseif time < T2 then
              (q1_f - q1_m)*(6*((time - T1)/(T2 - T1)) - 6*((time - T1)/(T2 - T1))^2)/(T2 - T1)
            else
              0.0;
  qdd1_ref = if time < T1 then
               (q1_m - q1_0)*(6.0 - 12.0*((time - T0)/(T1 - T0)))/(T1 - T0)^2
             elseif time < T2 then
               (q1_f - q1_m)*(6.0 - 12.0*((time - T1)/(T2 - T1)))/(T2 - T1)^2
             else
               0.0;

  q2_ref = if time < T1 then
             q2_0 + (q2_m - q2_0)*(3*((time - T0)/(T1 - T0))^2 - 2*((time - T0)/(T1 - T0))^3)
           elseif time < T2 then
             q2_m + (q2_f - q2_m)*(3*((time - T1)/(T2 - T1))^2 - 2*((time - T1)/(T2 - T1))^3)
           else
             q2_f;
  qd2_ref = if time < T1 then
              (q2_m - q2_0)*(6*((time - T0)/(T1 - T0)) - 6*((time - T0)/(T1 - T0))^2)/(T1 - T0)
            elseif time < T2 then
              (q2_f - q2_m)*(6*((time - T1)/(T2 - T1)) - 6*((time - T1)/(T2 - T1))^2)/(T2 - T1)
            else
              0.0;
  qdd2_ref = if time < T1 then
               (q2_m - q2_0)*(6.0 - 12.0*((time - T0)/(T1 - T0)))/(T1 - T0)^2
             elseif time < T2 then
               (q2_f - q2_m)*(6.0 - 12.0*((time - T1)/(T2 - T1)))/(T2 - T1)^2
             else
               0.0;

  q3_ref = if time < T1 then
             q3_0 + (q3_m - q3_0)*(3*((time - T0)/(T1 - T0))^2 - 2*((time - T0)/(T1 - T0))^3)
           elseif time < T2 then
             q3_m + (q3_f - q3_m)*(3*((time - T1)/(T2 - T1))^2 - 2*((time - T1)/(T2 - T1))^3)
           else
             q3_f;
  qd3_ref = if time < T1 then
              (q3_m - q3_0)*(6*((time - T0)/(T1 - T0)) - 6*((time - T0)/(T1 - T0))^2)/(T1 - T0)
            elseif time < T2 then
              (q3_f - q3_m)*(6*((time - T1)/(T2 - T1)) - 6*((time - T1)/(T2 - T1))^2)/(T2 - T1)
            else
              0.0;
  qdd3_ref = if time < T1 then
               (q3_m - q3_0)*(6.0 - 12.0*((time - T0)/(T1 - T0)))/(T1 - T0)^2
             elseif time < T2 then
               (q3_f - q3_m)*(6.0 - 12.0*((time - T1)/(T2 - T1)))/(T2 - T1)^2
             else
               0.0;

  // State traces from MultiBody Revolute joints
  q1_state = r1.phi;
  qd1_state = r1.w;
  qdd1_state = r1.a;
  q2_state = r2.phi;
  qd2_state = r2.w;
  qdd2_state = r2.a;
  q3_state = r3.phi;
  qd3_state = r3.w;
  qdd3_state = r3.a;

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

  primaryError = max(abs(q1_ref - r1.phi), max(abs(q2_ref - r2.phi), abs(q3_ref - r3.phi)));

  // 250 Hz controller: PID + velocity feedforward, bounded commands, anti-windup
  when sample(0, Ts) then
    q1_sens = r1.phi;
    qd1_sens = r1.w;
    q2_sens = r2.phi;
    qd2_sens = r2.w;
    q3_sens = r3.phi;
    qd3_sens = r3.w;

    e1 = q1_ref - r1.phi;
    e2 = q2_ref - r2.phi;
    e3 = q3_ref - r3.phi;

    tau1_raw = Kp1*e1 + Ki1*pre(xi1) + Kd1*(qd1_ref - r1.w) + Kvff1*qd1_ref;
    tau2_raw = Kp2*e2 + Ki2*pre(xi2) + Kd2*(qd2_ref - r2.w) + Kvff2*qd2_ref;
    tau3_raw = Kp3*e3 + Ki3*pre(xi3) + Kd3*(qd3_ref - r3.w) + Kvff3*qd3_ref;

    tau1_cmd = if tau1_raw > tauMax then tauMax elseif tau1_raw < -tauMax then -tauMax else tau1_raw;
    tau2_cmd = if tau2_raw > tauMax then tauMax elseif tau2_raw < -tauMax then -tauMax else tau2_raw;
    tau3_cmd = if tau3_raw > tauMax then tauMax elseif tau3_raw < -tauMax then -tauMax else tau3_raw;

    xi1 = if abs(tau1_raw) > tauMax then pre(xi1) else pre(xi1) + Ts*e1;
    xi2 = if abs(tau2_raw) > tauMax then pre(xi2) else pre(xi2) + Ts*e2;
    xi3 = if abs(tau3_raw) > tauMax then pre(xi3) else pre(xi3) + Ts*e3;
  end when;

  // Fail-closed acceptance bounds
  assert(abs(q1_state) <= qBound + 1e-9, "joint 1 position bound violated");
  assert(abs(q2_state) <= qBound + 1e-9, "joint 2 position bound violated");
  assert(abs(q3_state) <= qBound + 1e-9, "joint 3 position bound violated");

  assert(abs(qd1_state) <= qdBound + 1e-9, "joint 1 velocity bound violated");
  assert(abs(qd2_state) <= qdBound + 1e-9, "joint 2 velocity bound violated");
  assert(abs(qd3_state) <= qdBound + 1e-9, "joint 3 velocity bound violated");

  assert(abs(qdd1_state) <= qddBound + 1e-9, "joint 1 acceleration bound violated");
  assert(abs(qdd2_state) <= qddBound + 1e-9, "joint 2 acceleration bound violated");
  assert(abs(qdd3_state) <= qddBound + 1e-9, "joint 3 acceleration bound violated");

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

  annotation (experiment(StopTime=16, Interval=0.004, Tolerance=1e-6));
end JointPathMoveE;