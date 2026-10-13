model SevenPathMoveC
  "Seven-revolute trajectory-controlled arm: cubic interpolation, PID plus velocity feedforward, operational-space and null-space effort, 125 Hz, 12 s";

  // Control timing
  parameter Modelica.SIunits.Time Ts=0.008 "125 Hz control period";
  parameter Modelica.SIunits.Time t1=4.0 "end of first third / midpoint time";
  parameter Modelica.SIunits.Time t2=8.0 "end of middle third / final time";
  parameter Modelica.SIunits.Time tEnd=12.0 "simulation stop time";

  // Bounds
  parameter Modelica.SIunits.Angle q_max=0.5 "position bound";
  parameter Modelica.SIunits.AngularVelocity qd_max=0.5 "velocity bound";
  parameter Modelica.SIunits.AngularAcceleration qdd_max=1.0 "acceleration bound";
  parameter Modelica.SIunits.Torque tauMax=106 "maximum command magnitude";
  parameter Modelica.SIunits.AngularVelocity qd_settle=0.05 "terminal settling velocity";
  parameter Modelica.SIunits.Angle intMax=1.0 "integrator anti-windup limit";

  // Declared waypoints and final state
  parameter Modelica.SIunits.Angle q0[7]={0,0,0,0,0,0,0} "initial zero state";
  parameter Modelica.SIunits.Angle qMid[7]={0.10,0.15,-0.10,0.12,0.08,-0.06,0.05} "declared midpoint";
  parameter Modelica.SIunits.Angle qFinal[7]={0.20,0.30,-0.20,0.25,0.15,-0.10,0.10} "declared final state";

  // Mechanism geometry: alternating Z and Y axes, capsule links 0.34 m to 0.12 m
  parameter Modelica.SIunits.Length L[7]={0.34,0.30,0.26,0.22,0.18,0.15,0.12};
  parameter Modelica.SIunits.Length capsuleRadius[7]={0.02,0.018,0.016,0.014,0.012,0.010,0.008}
    "capsule radii not specified; placeholder radii required for executable collision geometry";

  // Physical parameters not stated in request; placeholder bindings are labeled
  parameter Modelica.SIunits.Mass m[7]={1.0,0.8,0.6,0.5,0.4,0.3,0.2}
    "link masses not specified; placeholder for executable gravity compensation";
  parameter Modelica.SIunits.Inertia Jm[7]={0.05,0.04,0.03,0.02,0.015,0.01,0.008}
    "joint inertias not specified; placeholder for executable dynamics";
  parameter Real damp[7](unit="N.m.s/rad")={0.05,0.04,0.03,0.02,0.015,0.01,0.008}
    "joint damping not specified; placeholder for executable dynamics";
  parameter Modelica.SIunits.Mass payloadNom=0.5
    "nominal payload mass not specified; placeholder for executable disturbance model";
  parameter Real payloadChangeFraction=0.045 "4.5 percent payload change";
  parameter Modelica.SIunits.Mass deltaPayload=payloadChangeFraction*payloadNom;
  parameter Modelica.SIunits.Acceleration g=9.81;
  parameter Real eps=1e-6 "finite-difference step";

  // Controller gains
  parameter Real Kp_pid(unit="N.m/rad")=5.0;
  parameter Real Ki_pid(unit="N.m/rad")=1.0;
  parameter Real Kd_pid(unit="N.m.s/rad")=0.5;
  parameter Real Kff_v(unit="N.m.s/rad")=0.05 "velocity feedforward";
  parameter Real Kp_task(unit="N/m")=800.0;
  parameter Real Kd_task(unit="N.s/m")=80.0;
  parameter Real Kff_task(unit="N.s/m")=0.2;
  parameter Real Kp_null(unit="N.m/rad")=2.0;
  parameter Real Kd_null(unit="N.m.s/rad")=0.5;
  parameter Real Kff_null(unit="N.m.s/rad")=0.01;

  // Plant state
  Modelica.SIunits.Angle q[7](start=q0, each fixed=true);
  Modelica.SIunits.AngularVelocity qd[7](start={0,0,0,0,0,0,0}, each fixed=true);
  Modelica.SIunits.AngularAcceleration qdd[7];

  // Sensors
  Modelica.SIunits.Angle q_enc[7];
  Modelica.SIunits.AngularVelocity qd_enc[7];
  Modelica.SIunits.AngularAcceleration qdd_enc[7];

  // Command and control traces
  discrete Modelica.SIunits.Torque tau_cmd[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.Torque tau_unsat[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.Torque tau_task[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.Torque tau_null[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.Torque tau_grav_comp[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.Torque f_null[7](start={0,0,0,0,0,0,0});
  discrete Real Nmat[7,7](start=zeros(7,7));
  discrete Real Jmat[3,7](start=zeros(3,7));
  discrete Modelica.SIunits.Force f_task[3](start={0,0,0});

  // Trajectory setpoints
  discrete Modelica.SIunits.Angle q_des[7](start=q0);
  discrete Modelica.SIunits.AngularVelocity qd_des[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.AngularAcceleration qdd_des[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.Position p_des[3](start={1.57,0,0});
  discrete Modelica.SIunits.Velocity v_des[3](start={0,0,0});
  discrete Modelica.SIunits.Velocity v_enc[3](start={0,0,0});
  discrete Modelica.SIunits.Position e_pos[3](start={0,0,0});
  discrete Modelica.SIunits.Velocity e_vel[3](start={0,0,0});
  discrete Modelica.SIunits.Angle e_joint[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.AngularVelocity ed_joint[7](start={0,0,0,0,0,0,0});
  discrete Modelica.SIunits.Angle int_e[7](start={0,0,0,0,0,0,0});

  // Kinematic and gravity traces
  Modelica.SIunits.Position p_enc[3];
  Modelica.SIunits.Position linkPos[8,3];
  Modelica.SIunits.Length collisionClearance;
  Modelica.SIunits.Torque tau_grav_nom[7];
  Modelica.SIunits.Torque tau_payload_grav[7];
  Modelica.SIunits.Torque tau_payload_dist[7];

  // Evidence and bounds
  Modelica.SIunits.Length primaryTrackingError;
  Modelica.SIunits.Angle jointTrackingErrorMax;
  Boolean positionWithinBounds;
  Boolean velocityWithinBounds;
  Boolean accelerationWithinBounds;
  Boolean effortWithinBounds;
  Boolean desiredWithinBounds;
  Boolean settled;
  Boolean collisionFree;
  Boolean finiteValues;

function rotAxis
  input Real angle;
  input Integer axis "1=Z, 2=Y";
  output Real R[3,3];
algorithm
  if axis == 1 then
    R := {{cos(angle),-sin(angle),0.0},{sin(angle),cos(angle),0.0},{0.0,0.0,1.0}};
  else
    R := {{cos(angle),0.0,sin(angle)},{0.0,1.0,0.0},{-sin(angle),0.0,cos(angle)}};
  end if;
end rotAxis;

function fkPos7
  input Real q[7];
  input Real L[7];
  output Real p[3];
protected
  Real R[3,3];
  Integer ax;
algorithm
  R := {{1.0,0.0,0.0},{0.0,1.0,0.0},{0.0,0.0,1.0}};
  p := {0.0,0.0,0.0};
  for i in 1:7 loop
    ax := if mod(i,2) == 1 then 1 else 2;
    R := R * rotAxis(q[i],ax);
    p[1] := p[1] + R[1,1]*L[i];
    p[2] := p[2] + R[2,1]*L[i];
    p[3] := p[3] + R[3,1]*L[i];
  end for;
end fkPos7;

function fkLinks7
  input Real q[7];
  input Real L[7];
  output Real linkPos[8,3];
protected
  Real R[3,3];
  Integer ax;
algorithm
  R := {{1.0,0.0,0.0},{0.0,1.0,0.0},{0.0,0.0,1.0}};
  linkPos[1,1] := 0.0;
  linkPos[1,2] := 0.0;
  linkPos[1,3] := 0.0;
  for i in 1:7 loop
    ax := if mod(i,2) == 1 then 1 else 2;
    R := R * rotAxis(q[i],ax);
    linkPos[i+1,1] := linkPos[i,1] + R[1,1]*L[i];
    linkPos[i+1,2] := linkPos[i,2] + R[2,1]*L[i];
    linkPos[i+1,3] := linkPos[i,3] + R[3,1]*L[i];
  end for;
end fkLinks7;

function jacobian7
  input Real q[7];
  input Real L[7];
  input Real eps;
  output Real J[3,7];
protected
  Real qt[7];
  Real pp[3];
  Real pm[3];
algorithm
  for j in 1:7 loop
    for i in 1:7 loop
      qt[i] := q[i];
    end for;
    qt[j] := q[j] + eps;
    pp := fkPos7(qt,L);
    qt[j] := q[j] - eps;
    pm := fkPos7(qt,L);
    for k in 1:3 loop
      J[k,j] := (pp[k] - pm[k])/(2.0*eps);
    end for;
  end for;
end jacobian7;

function potentialEnergy7
  input Real q[7];
  input Real L[7];
  input Real m[7];
  input Real payload;
  input Real g;
  output Real U;
protected
  Real lp[8,3];
  Real zc;
algorithm
  lp := fkLinks7(q,L);
  U := 0.0;
  for i in 1:7 loop
    zc := 0.5*(lp[i,3] + lp[i+1,3]);
    U := U + m[i]*g*zc;
  end for;
  U := U + payload*g*lp[8,3];
end potentialEnergy7;

function gravityTorque7
  input Real q[7];
  input Real L[7];
  input Real m[7];
  input Real payload;
  input Real g;
  input Real eps;
  output Real tau[7];
protected
  Real qt[7];
  Real Up;
  Real Um;
algorithm
  for j in 1:7 loop
    for i in 1:7 loop
      qt[i] := q[i];
    end for;
    qt[j] := q[j] + eps;
    Up := potentialEnergy7(qt,L,m,payload,g);
    qt[j] := q[j] - eps;
    Um := potentialEnergy7(qt,L,m,payload,g);
    tau[j] := -(Up - Um)/(2.0*eps);
  end for;
end gravityTorque7;

function payloadGravityTorque7
  input Real q[7];
  input Real L[7];
  input Real payload;
  input Real g;
  input Real eps;
  output Real tau[7];
protected
  Real qt[7];
  Real pp[3];
  Real pm[3];
algorithm
  for j in 1:7 loop
    for i in 1:7 loop
      qt[i] := q[i];
    end for;
    qt[j] := q[j] + eps;
    pp := fkPos7(qt,L);
    qt[j] := q[j] - eps;
    pm := fkPos7(qt,L);
    tau[j] := -(payload*g*pp[3] - payload*g*pm[3])/(2.0*eps);
  end for;
end payloadGravityTorque7;

function minClearance7
  input Real linkPos[8,3];
  input Real radius[7];
  output Real clearance;
protected
  Real c[7,3];
  Real dmin;
  Real dist;
algorithm
  for i in 1:7 loop
    c[i,1] := 0.5*(linkPos[i,1] + linkPos[i+1,1]);
    c[i,2] := 0.5*(linkPos[i,2] + linkPos[i+1,2]);
    c[i,3] := 0.5*(linkPos[i,3] + linkPos[i+1,3]);
  end for;
  dmin := 1e9;
  for i in 1:7 loop
    for j in i+2:7 loop
      dist := sqrt((c[i,1]-c[j,1])^2 + (c[i,2]-c[j,2])^2 + (c[i,3]-c[j,3])^2) - radius[i] - radius[j];
      if dist < dmin then
        dmin := dist;
      end if;
    end for;
  end for;
  clearance := dmin;
end minClearance7;

function cubicTrajectory7
  input Real t;
  input Real qa[7];
  input Real qb[7];
  input Real ta;
  input Real tb;
  output Real q[7];
  output Real qd[7];
  output Real qdd[7];
protected
  Real T;
  Real s;
algorithm
  T := tb - ta;
  for i in 1:7 loop
    if t <= ta then
      q[i] := qa[i];
      qd[i] := 0.0;
      qdd[i] := 0.0;
    elseif t >= tb then
      q[i] := qb[i];
      qd[i] := 0.0;
      qdd[i] := 0.0;
    else
      s := (t - ta)/T;
      q[i] := qa[i] + (qb[i]-qa[i])*(3.0*s*s - 2.0*s*s*s);
      qd[i] := (qb[i]-qa[i])*(6.0*s - 6.0*s*s)/T;
      qdd[i] := (qb[i]-qa[i])*(6.0 - 12.0*s)/(T*T);
    end if;
  end for;
end cubicTrajectory7;

function maxAbs7
  input Real x[7];
  output Real m;
algorithm
  m := 0.0;
  for i in 1:7 loop
    if abs(x[i]) > m then
      m := abs(x[i]);
    end if;
  end for;
end maxAbs7;

function norm3
  input Real x[3];
  output Real y;
algorithm
  y := sqrt(x[1]*x[1] + x[2]*x[2] + x[3]*x[3]);
end norm3;

equation
  // Plant dynamics: seven independent effort-driven revolute inertias with gravity and payload disturbance
  for i in 1:7 loop
    der(q[i]) = qd[i];
    der(qd[i]) = qdd[i];
    Jm[i]*qdd[i] = tau_cmd[i] - damp[i]*qd[i] - tau_grav_nom[i] - tau_payload_dist[i];
  end for;

  // Full joint-state sensing
  for i in 1:7 loop
    q_enc[i] = q[i];
    qd_enc[i] = qd[i];
    qdd_enc[i] = qdd[i];
  end for;

  // Kinematics, gravity, collision geometry
  p_enc = fkPos7(q,L);
  linkPos = fkLinks7(q,L);
  collisionClearance = minClearance7(linkPos,capsuleRadius);
  tau_grav_nom = gravityTorque7(q,L,m,payloadNom,g,eps);
  tau_payload_grav = payloadGravityTorque7(q,L,deltaPayload,g,eps);
  for i in 1:7 loop
    tau_payload_dist[i] = if time >= t1 and time < t2 then tau_payload_grav[i] else 0.0;
  end for;

  // Tracking evidence
  primaryTrackingError = norm3({p_des[1]-p_enc[1],p_des[2]-p_enc[2],p_des[3]-p_enc[3]});
  jointTrackingErrorMax = maxAbs7({q_des[1]-q_enc[1],q_des[2]-q_enc[2],q_des[3]-q_enc[3],q_des[4]-q_enc[4],q_des[5]-q_enc[5],q_des[6]-q_enc[6],q_des[7]-q_enc[7]});

  // Bounds and settling
  positionWithinBounds = maxAbs7({q[1],q[2],q[3],q[4],q[5],q[6],q[7]}) <= q_max;
  velocityWithinBounds = maxAbs7({qd[1],qd[2],qd[3],qd[4],qd[5],qd[6],qd[7]}) <= qd_max;
  accelerationWithinBounds = maxAbs7({qdd[1],qdd[2],qdd[3],qdd[4],qdd[5],qdd[6],qdd[7]}) <= qdd_max;
  effortWithinBounds = maxAbs7({tau_cmd[1],tau_cmd[2],tau_cmd[3],tau_cmd[4],tau_cmd[5],tau_cmd[6],tau_cmd[7]}) <= tauMax;
  desiredWithinBounds = maxAbs7({q_des[1],q_des[2],q_des[3],q_des[4],q_des[5],q_des[6],q_des[7]}) <= q_max and
                        maxAbs7({qd_des[1],qd_des[2],qd_des[3],qd_des[4],qd_des[5],qd_des[6],qd_des[7]}) <= qd_max and
                        maxAbs7({qdd_des[1],qdd_des[2],qdd_des[3],qdd_des[4],qdd_des[5],qdd_des[6],qdd_des[7]}) <= qdd_max;
  settled = time >= 7.8 and primaryTrackingError < 0.032 and maxAbs7({qd[1],qd[2],qd[3],qd[4],qd[5],qd[6],qd[7]}) <= qd_settle;
  collisionFree = collisionClearance > 0.0;
  finiteValues = maxAbs7({q[1],q[2],q[3],q[4],q[5],q[6],q[7]}) < 1e6 and
                 maxAbs7({qd[1],qd[2],qd[3],qd[4],qd[5],qd[6],qd[7]}) < 1e6 and
                 maxAbs7({qdd[1],qdd[2],qdd[3],qdd[4],qdd[5],qdd[6],qdd[7]}) < 1e6 and
                 maxAbs7({tau_cmd[1],tau_cmd[2],tau_cmd[3],tau_cmd[4],tau_cmd[5],tau_cmd[6],tau_cmd[7]}) < 1e6 and
                 maxAbs7({int_e[1],int_e[2],int_e[3],int_e[4],int_e[5],int_e[6],int_e[7]}) < 1e6;

algorithm
  when sample(0,Ts) then
    // Synchronized cubic interpolation: zero -> midpoint -> final, then hold
    if time <= t1 then
      (q_des,qd_des,qdd_des) := cubicTrajectory7(time,q0,qMid,0.0,t1);
    elseif time <= t2 then
      (q_des,qd_des,qdd_des) := cubicTrajectory7(time,qMid,qFinal,t1,t2);
    else
      for i in 1:7 loop
        q_des[i] := qFinal[i];
        qd_des[i] := 0.0;
        qdd_des[i] := 0.0;
      end for;
    end if;

    for i in 1:7 loop
      assert(abs(q_des[i]) <= q_max, "desired position bound exceeded");
      assert(abs(qd_des[i]) <= qd_max, "desired velocity bound exceeded");
      assert(abs(qdd_des[i]) <= qdd_max, "desired acceleration bound exceeded");
    end for;

    // Operational-space task and Jacobian
    p_des := fkPos7(q_des,L);
    Jmat := jacobian7({q_enc[1],q_enc[2],q_enc[3],q_enc[4],q_enc[5],q_enc[6],q_enc[7]},L,eps);

    for k in 1:3 loop
      v_des[k] := 0.0;
      v_enc[k] := 0.0;
      for j in 1:7 loop
        v_des[k] := v_des[k] + Jmat[k,j]*qd_des[j];
        v_enc[k] := v_enc[k] + Jmat[k,j]*qd_enc[j];
      end for;
      e_pos[k] := p_des[k] - p_enc[k];
      e_vel[k] := v_des[k] - v_enc[k];
      f_task[k] := Kp_task*e_pos[k] + Kd_task*e_vel[k] + Kff_task*v_des[k];
    end for;

    for j in 1:7 loop
      tau_task[j] := Jmat[1,j]*f_task[1] + Jmat[2,j]*f_task[2] + Jmat[3,j]*f_task[3];
      e_joint[j] := q_des[j] - q_enc[j];
      ed_joint[j] := qd_des[j] - qd_enc[j];
      f_null[j] := Kp_null*e_joint[j] + Kd_null*ed_joint[j] + Kff_null*qd_des[j];
    end for;

    // Null-space projection N = I - J^T J
    for j in 1:7 loop
      for l in 1:7 loop
        Nmat[j,l] := (if j == l then 1.0 else 0.0) -
                     (Jmat[1,j]*Jmat[1,l] + Jmat[2,j]*Jmat[2,l] + Jmat[3,j]*Jmat[3,l]);
      end for;
    end for;

    for j in 1:7 loop
      tau_null[j] := Nmat[j,1]*f_null[1] + Nmat[j,2]*f_null[2] + Nmat[j,3]*f_null[3] +
                     Nmat[j,4]*f_null[4] + Nmat[j,5]*f_null[5] + Nmat[j,6]*f_null[6] + Nmat[j,7]*f_null[7];
    end for;

    // Gravity compensation for nominal payload
    tau_grav_comp := gravityTorque7({q_enc[1],q_enc[2],q_enc[3],q_enc[4],q_enc[5],q_enc[6],q_enc[7]},L,m,payloadNom,g,eps);

    for i in 1:7 loop
      // PID integral with anti-windup
      int_e[i] := pre(int_e[i]) + Ts*e_joint[i];
      if int_e[i] > intMax then
        int_e[i] := intMax;
      elseif int_e[i] < -intMax then
        int_e[i] := -intMax;
      end if;

      // PID plus velocity feedforward plus operational-space and null-space effort
      tau_unsat[i] := tau_task[i] + tau_null[i] +
                      Kp_pid*e_joint[i] + Ki_pid*int_e[i] + Kd_pid*ed_joint[i] +
                      Kff_v*qd_des[i] + tau_grav_comp[i];

      // Maximum command magnitude saturation
      if tau_unsat[i] > tauMax then
        tau_cmd[i] := tauMax;
      elseif tau_unsat[i] < -tauMax then
        tau_cmd[i] := -tauMax;
      else
        tau_cmd[i] := tau_unsat[i];
      end if;
    end for;
  end when;

  annotation(experiment(StopTime=12, Tolerance=1e-6, Interval=0.008));
end SevenPathMoveC;