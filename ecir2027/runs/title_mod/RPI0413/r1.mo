model PlanarPusherGraspE
  // Given requirement values
  parameter Real L1 = 0.46 "m, capsule link 1 length";
  parameter Real L2 = 0.35 "m, capsule link 2 length";
  parameter Real tauMax = 55.0 "N.m, per-joint command bound";
  parameter Real mu = 0.78 "friction coefficient";
  parameter Real e = 0.03 "coefficient of restitution";
  parameter Real Fdist = 9.6 "N, tangential middle-third disturbance";
  parameter Real Ts = 1.0/250.0 "s, synchronized trace sample period";
  parameter Real Tfinal = 16.0 "s, run duration";
  parameter Real tErr = 10.4 "s, primary tracking error evaluation time";
  parameter Real errMax = 0.013 "m, primary tracking error bound";

  // Schedule
  parameter Real tApproach = 2.0 "s, impedance acquisition end";
  parameter Real tForceReg = 4.0 "s, force regulation established time";
  parameter Real tDistStart = Tfinal/3.0 "s";
  parameter Real tDistEnd = 2.0*Tfinal/3.0 "s";

  // Unknown placeholder physical values required for code generation; not specified by requirement
  parameter Real rCapsule1 = 0.02 "m, capsule link 1 radius, unknown placeholder";
  parameter Real rCapsule2 = 0.02 "m, capsule link 2 radius, unknown placeholder";
  parameter Real rTool = 0.02 "m, rounded contact tool radius, unknown placeholder";
  parameter Real objHalfX = 0.05 "m, object half-length along contact normal, unknown placeholder";
  parameter Real objHalfY = 0.05 "m, object half-height along tangent, unknown placeholder";
  parameter Real m1 = 1.0 "kg, link 1 mass, unknown placeholder";
  parameter Real m2 = 1.0 "kg, link 2 plus tool mass, unknown placeholder";
  parameter Real mArmEff = 1.0 "kg, effective arm mass at tool, unknown placeholder";
  parameter Real mObj = 4.0 "kg, object mass, unknown placeholder chosen so stated table friction can balance grasp and disturbance";
  parameter Real JObj = 0.01 "kg.m^2, object planar inertia, unknown placeholder";
  parameter Real I1 = 0.01 "kg.m^2, joint 1 reflected inertia, unknown placeholder";
  parameter Real I2 = 0.01 "kg.m^2, joint 2 reflected inertia, unknown placeholder";
  parameter Real b1 = 2.0 "N.m.s/rad, joint 1 damping, unknown placeholder";
  parameter Real b2 = 1.0 "N.m.s/rad, joint 2 damping, unknown placeholder";
  parameter Real Kp = 2000.0 "N/m, Cartesian impedance stiffness, unknown placeholder";
  parameter Real Kd = 200.0 "N.s/m, Cartesian impedance damping, unknown placeholder";
  parameter Real Freg = 15.0 "N, regulated normal grasp force, unknown placeholder";
  parameter Real kContact = 10000.0 "N/m, tool-object normal stiffness, unknown placeholder";
  parameter Real kTang = 100000.0 "N/m, tool-object tangential compliance, unknown placeholder";
  parameter Real cTang = 200.0 "N.s/m, tool-object tangential damping, unknown placeholder";
  parameter Real kTable = 100000.0 "N/m, table stiction stiffness, unknown placeholder";
  parameter Real cTable = 500.0 "N.s/m, table stiction damping, unknown placeholder";
  parameter Real kTheta = 1000.0 "N.m/rad, table rotational stiction stiffness, unknown placeholder";
  parameter Real cTheta = 10.0 "N.m.s/rad, table rotational stiction damping, unknown placeholder";
  parameter Real Tforce = 1.0 "s, force-regulation integral time constant, unknown placeholder";
  parameter Real xiMax = 0.002 "m, force-regulation position correction limit, unknown placeholder";
  parameter Real Treset = 0.1 "s, tangential patch reset time, unknown placeholder";
  parameter Real FgraspMin = 3.0 "N, grasp-loss normal-force threshold, unknown placeholder";
  parameter Real FmaxContact = 100.0 "N, stable contact upper normal-force bound, unknown placeholder";
  parameter Real jointTravelBound = 1.0 "rad, joint travel bound, unknown placeholder";
  parameter Real objectTravelBound = errMax "m, object travel bound";
  parameter Real thetaBound = 0.05 "rad, object rotation bound, unknown placeholder";
  parameter Boolean collisionEnabled = true;

  // Derived constants
  parameter Real g = 9.80665 "m/s^2";
  parameter Real Ntable = mObj*g "N, table normal force";
  parameter Real FtableLimit = mu*Ntable "N, table friction limit";
  parameter Real tauTableLimit = mu*Ntable*objHalfY "N.m, table rotational friction limit";
  parameter Real mEff = mArmEff*mObj/(mArmEff+mObj) "kg, contact reduced mass";
  parameter Real zeta = -log(e)/sqrt(Modelica.Constants.pi^2 + log(e)^2) "damping ratio from restitution";
  parameter Real cContact = 2.0*zeta*sqrt(kContact*mEff) "N.s/m, contact damping";

  // Initial kinematic condition
  parameter Real q1_start = 0.2 "rad";
  parameter Real q2_start = -0.1 "rad";
  parameter Real xObj0 = 0.90 "m";
  parameter Real yObj0 = 0.46*sin(0.2) + 0.35*sin(0.1) "m";
  parameter Real theta0 = 0.0 "rad";
  parameter Real xTool0 = 0.46*cos(0.2) + 0.35*cos(0.1) "m";
  parameter Real yTool0 = yObj0 "m";
  parameter Real pGraspX = xObj0 - objHalfX - rTool "m";
  parameter Real pGraspY = yObj0 "m";
  parameter Real detMin = 1.0e-6;
  parameter Real Big = 1.0e30;

  // Measured plant and acceptance outputs
  output Real q1(start=q1_start) "rad, actuator joint 1 position";
  output Real q2(start=q2_start) "rad, actuator joint 2 position";
  output Real w1(start=0) "rad/s, actuator joint 1 velocity";
  output Real w2(start=0) "rad/s, actuator joint 2 velocity";
  output Real tau1Cmd "N.m, joint 1 commanded torque";
  output Real tau2Cmd "N.m, joint 2 commanded torque";
  output Real F_tool_normal "N, tool-object normal contact force";
  output Real F_table_normal "N, table normal support force";
  output Real xObj(start=xObj0) "m, object x pose";
  output Real yObj(start=yObj0) "m, object y pose";
  output Real thetaObj(start=theta0) "rad, object orientation";
  output Real primaryTrackingError "m";
  output Boolean acceptance;

  // Internal dynamic states
  Real vxObj(start=0) "m/s";
  Real vyObj(start=0) "m/s";
  Real wObj(start=0) "rad/s";
  Real sT(start=0) "m, tool-object tangential patch deformation";
  Real xiForce(start=0) "m, force-regulation position correction";

  // Synchronized 250 Hz trace variables
  discrete Real sample_time(start=0);
  discrete Real sample_q1(start=0);
  discrete Real sample_q2(start=0);
  discrete Real sample_w1(start=0);
  discrete Real sample_w2(start=0);
  discrete Real sample_tau1(start=0);
  discrete Real sample_tau2(start=0);
  discrete Real sample_FN(start=0);
  discrete Real sample_Ntable(start=0);
  discrete Real sample_xObj(start=xObj0);
  discrete Real sample_yObj(start=yObj0);
  discrete Real sample_thetaObj(start=0);
  discrete Real sample_error(start=0);
  discrete Boolean sample_acceptance(start=true);

  // Kinematic and dynamic variables
  Real c1, s1, c12, s12, c2, s2;
  Real xTool, yTool, vxTool, vyTool;
  Real J11, J12, J21, J22;
  Real M11, M12, M22, C1, C2, detRaw, det, A1, A2, wd1, wd2;
  Real Q1, Q2;
  Real n_x, n_y, t_x, t_y;
  Real xFace, yFace, u, h_n, gap, delta, vRel_x, vRel_y, vNormal, vTangential;
  Real F_N, F_t_unsat, F_t, Fcontact_x, Fcontact_y, tauContact;
  Real Ftable_unsat_x, Ftable_unsat_y, Ftable_mag, Ftable_scale, Ftable_x, Ftable_y;
  Real tauTable_unsat, tauTable;
  Real Fdist_x, Fdist_y;
  Real rApproach, smoothRamp, vRamp, rForce, FregSchedule, deltaRegSchedule;
  Real p_base_x, p_base_y, v_des_x, v_des_y, p_d_x, p_d_y;
  Real Fdes_x, Fdes_y, tau1Raw, tau2Raw;
  Boolean contactPointOnFace, contactStable, effortOK, travelOK, trackingOK, finiteOK;

equation
  // Two revolute Z joints and capsule-link kinematics
  c1 = cos(q1);
  s1 = sin(q1);
  c12 = cos(q1 + q2);
  s12 = sin(q1 + q2);
  c2 = cos(q2);
  s2 = sin(q2);

  xTool = L1*c1 + L2*c12;
  yTool = L1*s1 + L2*s12;
  vxTool = -L1*s1*w1 - L2*s12*(w1 + w2);
  vyTool = L1*c1*w1 + L2*c12*(w1 + w2);

  J11 = -L1*s1 - L2*s12;
  J12 = -L2*s12;
  J21 = L1*c1 + L2*c12;
  J22 = L2*c12;

  // Planar 2R manipulator dynamics
  M11 = m1*L1^2 + m2*(L1^2 + L2^2 + 2.0*L1*L2*c2) + I1;
  M12 = m2*(L2^2 + L1*L2*c2);
  M22 = m2*L2^2 + I2;
  C1 = -m2*L1*L2*s2*(2.0*w1*w2 + w2^2);
  C2 = m2*L1*L2*s2*w1^2;
  detRaw = M11*M22 - M12*M12;
  det = if noEvent(detRaw < detMin) then detMin else detRaw;

  A1 = tau1Cmd + Q1 - C1 - b1*w1;
  A2 = tau2Cmd + Q2 - C2 - b2*w2;
  wd1 = (A1*M22 - A2*M12)/det;
  wd2 = (M11*A2 - M12*A1)/det;

  der(q1) = w1;
  der(q2) = w2;
  der(w1) = wd1;
  der(w2) = wd2;

  // Object pose states
  der(xObj) = vxObj;
  der(yObj) = vyObj;
  der(thetaObj) = wObj;

  // Contact geometry between rounded tool and flat object face
  n_x = cos(thetaObj);
  n_y = sin(thetaObj);
  t_x = -n_y;
  t_y = n_x;
  xFace = xObj - objHalfX*n_x;
  yFace = yObj - objHalfX*n_y;
  u = t_x*(xTool - xFace) + t_y*(yTool - yFace);
  h_n = n_x*(xFace - xTool) + n_y*(yFace - yTool);
  gap = h_n - rTool;
  delta = -gap;

  vRel_x = (vxObj - wObj*(yFace - yObj)) - vxTool;
  vRel_y = (vyObj + wObj*(xFace - xObj)) - vyTool;
  vNormal = n_x*vRel_x + n_y*vRel_y;
  vTangential = t_x*vRel_x + t_y*vRel_y;

  F_N = if noEvent(collisionEnabled and delta > 0.0) then
          (if noEvent(kContact*delta - cContact*vNormal > 0.0) then kContact*delta - cContact*vNormal else 0.0)
        else 0.0;
  F_tool_normal = F_N;

  // Tangential contact compliance with Coulomb limit
  der(sT) = if noEvent(collisionEnabled and F_N > 0.0) then vTangential else -sT/Treset;
  F_t_unsat = -kTang*sT - cTang*vTangential;
  F_t = if noEvent(collisionEnabled and F_N > 0.0) then
          (if noEvent(F_t_unsat > mu*F_N) then mu*F_N
           elseif noEvent(F_t_unsat < -mu*F_N) then -mu*F_N
           else F_t_unsat)
        else 0.0;

  Fcontact_x = F_N*n_x + F_t*t_x;
  Fcontact_y = F_N*n_y + F_t*t_y;
  tauContact = -u*F_N - objHalfX*F_t;

  // Generalized contact force on arm is negative of force on object
  Q1 = -(J11*Fcontact_x + J21*Fcontact_y);
  Q2 = -(J12*Fcontact_x + J22*Fcontact_y);

  // Rigid support table with friction, restitution parameter retained in contact damping
  F_table_normal = if collisionEnabled then Ntable else 0.0;
  Ftable_unsat_x = -kTable*(xObj - xObj0) - cTable*vxObj;
  Ftable_unsat_y = -kTable*(yObj - yObj0) - cTable*vyObj;
  Ftable_mag = sqrt(Ftable_unsat_x^2 + Ftable_unsat_y^2);
  Ftable_scale = if noEvent(Ftable_mag > FtableLimit) then FtableLimit/Ftable_mag else 1.0;
  Ftable_x = Ftable_unsat_x*Ftable_scale;
  Ftable_y = Ftable_unsat_y*Ftable_scale;

  tauTable_unsat = -kTheta*(thetaObj - theta0) - cTheta*wObj;
  tauTable = if noEvent(tauTable_unsat > tauTableLimit) then tauTableLimit
             elseif noEvent(tauTable_unsat < -tauTableLimit) then -tauTableLimit
             else tauTable_unsat;

  // Controlled middle-third tangential disturbance
  Fdist_x = 0.0;
  Fdist_y = if noEvent(time >= tDistStart and time <= tDistEnd) then Fdist else 0.0;

  // Object dynamics
  der(vxObj) = (Fcontact_x + Ftable_x + Fdist_x)/mObj;
  der(vyObj) = (Fcontact_y + Ftable_y + Fdist_y)/mObj;
  der(wObj) = (tauContact + tauTable)/JObj;

  // Impedance motion followed by force regulation
  rApproach = if noEvent(time < tApproach) then time/tApproach else 1.0;
  smoothRamp = 3.0*rApproach^2 - 2.0*rApproach^3;
  vRamp = if noEvent(time < tApproach) then (6.0*rApproach - 6.0*rApproach^2)/tApproach else 0.0;
  p_base_x = xTool0 + (pGraspX - xTool0)*smoothRamp;
  p_base_y = yTool0 + (pGraspY - yTool0)*smoothRamp;
  v_des_x = (pGraspX - xTool0)*vRamp;
  v_des_y = (pGraspY - yTool0)*vRamp;

  rForce = if noEvent(time < tApproach) then 0.0
           elseif noEvent(time < tForceReg) then (time - tApproach)/(tForceReg - tApproach)
           else 1.0;
  FregSchedule = Freg*(3.0*rForce^2 - 2.0*rForce^3);
  deltaRegSchedule = FregSchedule/kContact;

  der(xiForce) = if noEvent(time < tApproach) then 0.0
                 elseif noEvent(xiForce > xiMax and (FregSchedule - F_N) > 0.0) then 0.0
                 elseif noEvent(xiForce < -xiMax and (FregSchedule - F_N) < 0.0) then 0.0
                 else (FregSchedule - F_N)/Tforce;

  p_d_x = p_base_x + (deltaRegSchedule + xiForce)*n_x;
  p_d_y = p_base_y + (deltaRegSchedule + xiForce)*n_y;

  Fdes_x = Kp*(p_d_x - xTool) + Kd*(v_des_x - vxTool) + FregSchedule*n_x;
  Fdes_y = Kp*(p_d_y - yTool) + Kd*(v_des_y - vyTool) + FregSchedule*n_y;

  // Joint-torque drives with per-joint command magnitude bound
  tau1Raw = J11*Fdes_x + J21*Fdes_y;
  tau2Raw = J12*Fdes_x + J22*Fdes_y;
  tau1Cmd = if noEvent(tau1Raw > tauMax) then tauMax
            elseif noEvent(tau1Raw < -tauMax) then -tauMax
            else tau1Raw;
  tau2Cmd = if noEvent(tau2Raw > tauMax) then tauMax
            elseif noEvent(tau2Raw < -tauMax) then -tauMax
            else tau2Raw;

  // Acceptance, fail-closed
  primaryTrackingError = sqrt((xObj - xObj0)^2 + (yObj - yObj0)^2);
  contactPointOnFace = abs(u) <= objHalfY;
  contactStable = if noEvent(time > tForceReg) then
                    (F_N >= FgraspMin and F_N <= FmaxContact and contactPointOnFace)
                  else true;
  effortOK = abs(tau1Cmd) <= tauMax and abs(tau2Cmd) <= tauMax;
  travelOK = abs(q1 - q1_start) <= jointTravelBound and
             abs(q2 - q2_start) <= jointTravelBound and
             primaryTrackingError <= objectTravelBound and
             abs(thetaObj - theta0) <= thetaBound;
  trackingOK = if noEvent(time >= tErr) then primaryTrackingError <= errMax else true;
  finiteOK = abs(q1) < Big and abs(q2) < Big and abs(w1) < Big and abs(w2) < Big and
             abs(tau1Cmd) < Big and abs(tau2Cmd) < Big and
             abs(xObj) < Big and abs(yObj) < Big and abs(thetaObj) < Big and
             abs(vxObj) < Big and abs(vyObj) < Big and abs(wObj) < Big and
             abs(F_N) < Big and abs(F_t) < Big and
             abs(Ftable_x) < Big and abs(Ftable_y) < Big and
             abs(tauContact) < Big and abs(tauTable) < Big and
             abs(xiForce) < Big and abs(sT) < Big;
  acceptance = finiteOK and effortOK and travelOK and trackingOK and contactStable;

algorithm
  when sample(0, Ts) then
    sample_time := time;
    sample_q1 := q1;
    sample_q2 := q2;
    sample_w1 := w1;
    sample_w2 := w2;
    sample_tau1 := tau1Cmd;
    sample_tau2 := tau2Cmd;
    sample_FN := F_N;
    sample_Ntable := F_table_normal;
    sample_xObj := xObj;
    sample_yObj := yObj;
    sample_thetaObj := thetaObj;
    sample_error := primaryTrackingError;
    sample_acceptance := acceptance;
  end when;

  annotation (experiment(StopTime = 16.0));
end PlanarPusherGraspE;