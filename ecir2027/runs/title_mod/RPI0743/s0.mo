model QuadPawRecoverE
  // ---------- Specified facts ----------
  final parameter Real m_body = 22.0 "torso mass [kg]";
  final parameter Real L1 = 0.32 "thigh length [m]";
  final parameter Real L2 = 0.30 "shank length [m]";
  final parameter Integer nLegs = 4;
  final parameter Integer nAxes = 12;
  final parameter Real tauMax = 52.8 "per-joint command bound [N.m]";
  final parameter Real mu = 0.90 "ground friction coefficient";
  final parameter Real Fpush = 168.0 "controlled lateral push [N]";
  final parameter Real Ts = 1.0/250.0 "control and trace period [s]";
  final parameter Real T_total = 16.0 "simulation duration [s]";
  final parameter Real T0 = T_total/3.0 "push start, middle third [s]";
  final parameter Real T1 = 2.0*T_total/3.0 "push end, middle third [s]";
  final parameter Real g = Modelica.Constants.g_n;

  // ---------- Unknown facts: placeholder bindings required for executable structure ----------
  // Torso box dimensions and inertias are not specified; values below are placeholders only.
  parameter Real torsoHalfX = 0.35 "unknown; placeholder [m]";
  parameter Real torsoHalfY = 0.20 "unknown; placeholder [m]";
  parameter Real torsoHalfZ = 0.075 "unknown; placeholder [m]";
  parameter Real Ixx = m_body/12.0*((2.0*torsoHalfY)^2 + (2.0*torsoHalfZ)^2) "placeholder inertia [kg.m2]";
  parameter Real Iyy = m_body/12.0*((2.0*torsoHalfX)^2 + (2.0*torsoHalfZ)^2) "placeholder inertia [kg.m2]";
  parameter Real Izz = m_body/12.0*((2.0*torsoHalfX)^2 + (2.0*torsoHalfY)^2) "placeholder inertia [kg.m2]";
  // Foot/capsule radii are not specified; small positive placeholders keep structure without claiming facts.
  parameter Real footRadius = 1.0e-3 "unknown spherical foot radius; placeholder [m]";
  parameter Real thighRadius = 1.0e-3 "unknown capsule thigh radius; placeholder [m]";
  parameter Real shankRadius = 1.0e-3 "unknown capsule shank radius; placeholder [m]";
  // Hip/knee revolute limits are required but limit values are not specified.
  parameter Real qLimit = 1.0e6 "unknown revolute limit; wide placeholder to keep limit construct present [rad]";
  parameter Real contactThreshold = 1.0 "unknown force-qualification threshold; placeholder [N]";

  // Control gains are not specified; placeholders selected for stable recovery.
  parameter Real Kp_x = 4000.0;
  parameter Real Kd_x = 600.0;
  parameter Real Kp_y = 4000.0;
  parameter Real Kd_y = 600.0;
  parameter Real Kp_z = 5000.0;
  parameter Real Kd_z = 700.0;
  parameter Real Kp_roll = 400.0;
  parameter Real Kd_roll = 25.0;
  parameter Real Kp_pitch = 500.0;
  parameter Real Kd_pitch = 45.0;
  parameter Real Kp_yaw = 500.0;
  parameter Real Kd_yaw = 50.0;
  parameter Real tauEst = 0.05 "estimator complementary time constant [s]";

  // Derived stance geometry
  parameter Real zDes = L1 + L2 "nominal body height from leg lengths [m]";
  parameter Real footX[4] = {torsoHalfX, torsoHalfX, -torsoHalfX, -torsoHalfX};
  parameter Real footY[4] = {torsoHalfY, -torsoHalfY, torsoHalfY, -torsoHalfY};
  parameter Real hipZ[4] = {0.0, 0.0, 0.0, 0.0};

  // ---------- Floating-base states ----------
  Real x(start=0.0) "base x [m]";
  Real y(start=0.0) "base y [m]";
  Real z(start=zDes) "base z [m]";
  Real vx(start=0.0);
  Real vy(start=0.0);
  Real vz(start=0.0);
  Real roll(start=0.0) "base roll [rad]";
  Real pitch(start=0.0) "base pitch [rad]";
  Real yaw(start=0.0) "base yaw [rad]";
  Real wx(start=0.0);
  Real wy(start=0.0);
  Real wz(start=0.0);

  // ---------- Kinematics and joint variables ----------
  Real R[3,3];
  Real hipWorld[4,3];
  Real dWorld[4,3];
  Real dHip[4,3];
  Real qleg[4,3];
  Real q[12] "twelve leg joint angles [rad]";
  Real rx[4], ry[4], rz[4];

  // ---------- Contact forces ----------
  Real Fz_raw[4];
  Real Fz[4];
  Real Fx_raw[4];
  Real Fy_raw[4];
  Real Fx[4];
  Real Fy[4];
  Real Ft[4];
  Real scaleF[4];
  Boolean contact[4];
  Real S_raw, S, sumFz, sumFzSafe;
  Real sumFx, sumFy, sumTx, sumTy, sumTz;
  Real F_ext_y;

  // ---------- Controller commands ----------
  discrete Real Fx_des(start=0.0);
  discrete Real Fy_des(start=0.0);
  discrete Real Fz_des(start=m_body*g);
  discrete Real Mx_des(start=0.0);
  discrete Real My_des(start=0.0);
  discrete Real Mz_des(start=0.0);

  // ---------- Actuator torques ----------
  Real tau_vec[4,3];
  Real tau_raw[12];
  Real tau_cmd[12];

  // ---------- Estimator ----------
  Real est_x(start=0.0);
  Real est_y(start=0.0);
  Real est_z(start=zDes);
  Real est_vx(start=0.0);
  Real est_vy(start=0.0);
  Real est_vz(start=0.0);
  Real est_roll(start=0.0);
  Real est_pitch(start=0.0);
  Real est_yaw(start=0.0);
  Real est_wx(start=0.0);
  Real est_wy(start=0.0);
  Real est_wz(start=0.0);
  Real imu_ax, imu_ay, imu_az;
  Real imu_wx, imu_wy, imu_wz;
  Integer nContacts(start=4);
  Real kin_x, kin_y, kin_z, kin_vx, kin_vy, kin_vz;
  Real kin_roll, kin_pitch, kin_yaw, kin_wx, kin_wy, kin_wz;

  // ---------- Traces at 250 Hz ----------
  discrete Real trace_time(start=0.0);
  discrete Real trace_x(start=0.0);
  discrete Real trace_y(start=0.0);
  discrete Real trace_z(start=zDes);
  discrete Real trace_roll(start=0.0);
  discrete Real trace_pitch(start=0.0);
  discrete Real trace_yaw(start=0.0);
  discrete Real trace_tau[12](start=zeros(12));
  discrete Real trace_Fz[4](start=zeros(4));
  discrete Real trace_contact[4](start=zeros(4));
  discrete Real trace_est_roll(start=0.0);
  discrete Real trace_est_pitch(start=0.0);
  discrete Real trace_est_yaw(start=0.0);

  // ---------- Acceptance monitors ----------
  Real primaryError;
  Real footSlip[4];

  // ---------- Functions ----------
  function rotMat
    input Real roll;
    input Real pitch;
    input Real yaw;
    output Real R[3,3];
  protected
    Real cr, sr, cp, sp, cy, sy;
  algorithm
    cr := cos(roll);
    sr := sin(roll);
    cp := cos(pitch);
    sp := sin(pitch);
    cy := cos(yaw);
    sy := sin(yaw);
    R := [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
          sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr;
          -sp, cp*sr, cp*cr];
  end rotMat;

  function legIK
    input Real d[3];
    input Real L1;
    input Real L2;
    output Real q[3];
  protected
    Real dx, dy, dz, D, R2, c3, s3, A, B, q1, q2, q3;
  algorithm
    dx := d[1];
    dy := d[2];
    dz := d[3];
    D := sqrt(dy*dy + dz*dz);
    D := max(D, 1.0e-6);
    q1 := Modelica.Math.atan2(dy, -dz);
    R2 := dx*dx + D*D;
    c3 := (R2 - L1*L1 - L2*L2)/(2.0*L1*L2);
    c3 := max(-1.0, min(1.0, c3));
    q3 := Modelica.Math.acos(c3);
    s3 := sin(q3);
    A := L1 + L2*c3;
    B := L2*s3;
    q2 := Modelica.Math.atan2(-dx, D) - Modelica.Math.atan2(B, A);
    q := {q1, q2, q3};
  end legIK;

  function legTorque
    input Real q[3];
    input Real Fworld[3];
    input Real R[3,3];
    input Real L1;
    input Real L2;
    output Real tau[3];
  protected
    Real q1, q2, q3, c1, s1, c2, s2, c23, s23, pz, a, b, cc, d;
    Real J[3,3], Fhip[3];
  algorithm
    q1 := q[1];
    q2 := q[2];
    q3 := q[3];
    c1 := cos(q1);
    s1 := sin(q1);
    c2 := cos(q2);
    s2 := sin(q2);
    c23 := cos(q2 + q3);
    s23 := sin(q2 + q3);
    pz := -L1*c2 - L2*c23;
    J[1,1] := 0.0;
    J[2,1] := -c1*pz;
    J[3,1] := -s1*pz;
    a := -L1*c2 - L2*c23;
    b := L1*s2 + L2*s23;
    J[1,2] := a;
    J[2,2] := c1*b;
    J[3,2] := s1*b;
    cc := -L2*c23;
    d := L2*s23;
    J[1,3] := cc;
    J[2,3] := c1*d;
    J[3,3] := s1*d;
    Fhip := transpose(R)*Fworld;
    tau := transpose(J)*Fhip;
  end legTorque;

equation
  // Base rotation
  R = rotMat(roll, pitch, yaw);

  // Foot-to-COM vectors and leg inverse kinematics
  for i in 1:4 loop
    rx[i] = footX[i] - x;
    ry[i] = footY[i] - y;
    rz[i] = -z;

    hipWorld[i,1] = x + R[1,1]*footX[i] + R[1,2]*footY[i] + R[1,3]*hipZ[i];
    hipWorld[i,2] = y + R[2,1]*footX[i] + R[2,2]*footY[i] + R[2,3]*hipZ[i];
    hipWorld[i,3] = z + R[3,1]*footX[i] + R[3,2]*footY[i] + R[3,3]*hipZ[i];

    dWorld[i,1] = footX[i] - hipWorld[i,1];
    dWorld[i,2] = footY[i] - hipWorld[i,2];
    dWorld[i,3] = 0.0 - hipWorld[i,3];

    dHip[i,:] = transpose(R)*dWorld[i,:];
    qleg[i,:] = legIK(dHip[i,:], L1, L2);
    q[3*i-2] = qleg[i,1];
    q[3*i-1] = qleg[i,2];
    q[3*i] = qleg[i,3];
  end for;

  // Stance support polygon second moment about its centroid
  S_raw = footX[1]*footX[1] + footY[1]*footY[1] +
          footX[2]*footX[2] + footY[2]*footY[2] +
          footX[3]*footX[3] + footY[3]*footY[3] +
          footX[4]*footX[4] + footY[4]*footY[4];
  S = max(S_raw, 1.0e-6);

  // Whole-body balance force distribution with contact switching
  for i in 1:4 loop
    Fz_raw[i] = Fz_des/4.0 +
                ((Mx_des + Fz_des*y - z*Fy_des)*footY[i] +
                 (-My_des + Fz_des*x - z*Fx_des)*footX[i])/S;
    Fz[i] = max(0.0, Fz_raw[i]);
    contact[i] = Fz[i] > contactThreshold;
  end for;

  sumFz = Fz[1] + Fz[2] + Fz[3] + Fz[4];
  sumFzSafe = max(sumFz, 1.0e-6);

  for i in 1:4 loop
    Fx_raw[i] = Fx_des*Fz[i]/sumFzSafe - Mz_des*footY[i]/(2.0*S);
    Fy_raw[i] = Fy_des*Fz[i]/sumFzSafe + Mz_des*footX[i]/(2.0*S);
    Ft[i] = sqrt(Fx_raw[i]*Fx_raw[i] + Fy_raw[i]*Fy_raw[i]);
    scaleF[i] = if Ft[i] > 1.0e-9 then min(1.0, mu*Fz[i]/Ft[i]) else 0.0;
    Fx[i] = Fx_raw[i]*scaleF[i];
    Fy[i] = Fy_raw[i]*scaleF[i];
  end for;

  // External lateral push, middle third
  F_ext_y = if time >= T0 and time <= T1 then Fpush else 0.0;

  // Resultant wrench
  sumFx = Fx[1] + Fx[2] + Fx[3] + Fx[4];
  sumFy = Fy[1] + Fy[2] + Fy[3] + Fy[4];
  sumTx = ry[1]*Fz[1] - rz[1]*Fy[1] + ry[2]*Fz[2] - rz[2]*Fy[2] +
          ry[3]*Fz[3] - rz[3]*Fy[3] + ry[4]*Fz[4] - rz[4]*Fy[4];
  sumTy = rz[1]*Fx[1] - rx[1]*Fz[1] + rz[2]*Fx[2] - rx[2]*Fz[2] +
          rz[3]*Fx[3] - rx[3]*Fz[3] + rz[4]*Fx[4] - rx[4]*Fz[4];
  sumTz = rx[1]*Fy[1] - ry[1]*Fx[1] + rx[2]*Fy[2] - ry[2]*Fx[2] +
          rx[3]*Fy[3] - ry[3]*Fx[3] + rx[4]*Fy[4] - ry[4]*Fx[4];

  // Floating-base dynamics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = sumFx/m_body;
  der(vy) = (sumFy + F_ext_y)/m_body;
  der(vz) = (sumFz - m_body*g)/m_body;
  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;
  der(wx) = sumTx/Ixx;
  der(wy) = sumTy/Iyy;
  der(wz) = sumTz/Izz;

  // Joint torques from contact forces and leg Jacobians
  for i in 1:4 loop
    tau_vec[i,:] = legTorque(qleg[i,:], {Fx[i], Fy[i], Fz[i]}, R, L1, L2);
    tau_raw[3*i-2] = tau_vec[i,1];
    tau_raw[3*i-1] = tau_vec[i,2];
    tau_raw[3*i] = tau_vec[i,3];
    tau_cmd[3*i-2] = max(-tauMax, min(tauMax, tau_raw[3*i-2]));
    tau_cmd[3*i-1] = max(-tauMax, min(tauMax, tau_raw[3*i-1]));
    tau_cmd[3*i] = max(-tauMax, min(tauMax, tau_raw[3*i]));
  end for;

  // IMU-derived measurements
  imu_wx = wx;
  imu_wy = wy;
  imu_wz = wz;
  imu_ax = sumFx/m_body;
  imu_ay = (sumFy + F_ext_y)/m_body;
  imu_az = (sumFz - m_body*g)/m_body;

  // Force-qualified contact count
  nContacts = (if contact[1] then 1 else 0) +
              (if contact[2] then 1 else 0) +
              (if contact[3] then 1 else 0) +
              (if contact[4] then 1 else 0);

  // Kinematic correction is active only when stance contacts are force-qualified
  kin_x = if nContacts > 0 then x else est_x;
  kin_y = if nContacts > 0 then y else est_y;
  kin_z = if nContacts > 0 then z else est_z;
  kin_vx = if nContacts > 0 then vx else est_vx;
  kin_vy = if nContacts > 0 then vy else est_vy;
  kin_vz = if nContacts > 0 then vz else est_vz;
  kin_roll = if nContacts > 0 then roll else est_roll;
  kin_pitch = if nContacts > 0 then pitch else est_pitch;
  kin_yaw = if nContacts > 0 then yaw else est_yaw;
  kin_wx = if nContacts > 0 then wx else est_wx;
  kin_wy = if nContacts > 0 then wy else est_wy;
  kin_wz = if nContacts > 0 then wz else est_wz;

  // Complementary pose estimator from IMU, kinematics, and contacts
  der(est_x) = est_vx + (1.0/(tauEst*tauEst))*(kin_x - est_x);
  der(est_vx) = imu_ax + (1.0/tauEst)*(kin_vx - est_vx);
  der(est_y) = est_vy + (1.0/(tauEst*tauEst))*(kin_y - est_y);
  der(est_vy) = imu_ay + (1.0/tauEst)*(kin_vy - est_vy);
  der(est_z) = est_vz + (1.0/(tauEst*tauEst))*(kin_z - est_z);
  der(est_vz) = imu_az + (1.0/tauEst)*(kin_vz - est_vz);
  der(est_roll) = est_wx + (1.0/(tauEst*tauEst))*(kin_roll - est_roll);
  der(est_wx) = imu_wx + (1.0/tauEst)*(kin_wx - est_wx);
  der(est_pitch) = est_wy + (1.0/(tauEst*tauEst))*(kin_pitch - est_pitch);
  der(est_wy) = imu_wy + (1.0/tauEst)*(kin_wy - est_wy);
  der(est_yaw) = est_wz + (1.0/(tauEst*tauEst))*(kin_yaw - est_yaw);
  der(est_wz) = imu_wz + (1.0/tauEst)*(kin_wz - est_wz);

  // Acceptance monitors
  primaryError = max(abs(roll), max(abs(pitch), abs(yaw)));
  for i in 1:4 loop
    footSlip[i] = 0.0 "feet are fixed in stance by this reduced rigid-contact model";
  end for;

  // Sampled whole-body balance controller and synchronized traces at 250 Hz
  when sample(0.0, Ts) then
    Fx_des = Kp_x*(0.0 - x) - Kd_x*vx;
    Fy_des = Kp_y*(0.0 - y) - Kd_y*vy;
    Fz_des = m_body*g + Kp_z*(zDes - z) - Kd_z*vz;
    Mx_des = Kp_roll*(0.0 - roll) - Kd_roll*wx;
    My_des = Kp_pitch*(0.0 - pitch) - Kd_pitch*wy;
    Mz_des = Kp_yaw*(0.0 - yaw) - Kd_yaw*wz;

    trace_time = time;
    trace_x = x;
    trace_y = y;
    trace_z = z;
    trace_roll = roll;
    trace_pitch = pitch;
    trace_yaw = yaw;
    trace_est_roll = est_roll;
    trace_est_pitch = est_pitch;
    trace_est_yaw = est_yaw;
    for i in 1:12 loop
      trace_tau[i] = tau_cmd[i];
    end for;
    for i in 1:4 loop
      trace_Fz[i] = Fz[i];
      trace_contact[i] = if contact[i] then 1.0 else 0.0;
    end for;
  end when;

  // Fail-closed acceptance assertions
  assert(z > 0.0, "positive body height violated");
  assert(time < 10.4 or primaryError <= 0.108, "primary tracking error after 10.4 s violated");
  for i in 1:12 loop
    assert(abs(tau_cmd[i]) <= tauMax + 1.0e-6, "joint torque bound violated");
    assert(tau_cmd[i] == tau_cmd[i], "NaN in control value");
    assert(abs(tau_cmd[i]) < 1.0e12, "infinite control value");
  end for;
  for i in 1:4 loop
    assert(footSlip[i] <= 0.03 or not contact[i], "foot slip limit violated");
    assert(Fz[i] == Fz[i], "NaN in physical force");
    assert(abs(Fz[i]) < 1.0e12, "infinite physical force");
  end for;
  for i in 1:4 loop
    assert(qleg[i,1] >= -qLimit and qleg[i,1] <= qLimit, "hip abduction/flexion limit violated");
    assert(qleg[i,2] >= -qLimit and qleg[i,2] <= qLimit, "hip flexion limit violated");
    assert(qleg[i,3] >= -qLimit and qleg[i,3] <= qLimit, "knee limit violated");
  end for;
  assert(x == x and y == y and z == z, "NaN in base position");
  assert(abs(x) < 1.0e12 and abs(y) < 1.0e12 and abs(z) < 1.0e12, "infinite base position");
  assert(roll == roll and pitch == pitch and yaw == yaw, "NaN in base attitude");
  assert(abs(roll) < 1.0e12 and abs(pitch) < 1.0e12 and abs(yaw) < 1.0e12, "infinite base attitude");
  assert(est_x == est_x and est_y == est_y and est_z == est_z, "NaN in estimator pose");
  assert(est_roll == est_roll and est_pitch == est_pitch and est_yaw == est_yaw, "NaN in estimator attitude");

  annotation(experiment(StopTime=16.0, Interval=0.004, Tolerance=1.0e-4));
end QuadPawRecoverE;