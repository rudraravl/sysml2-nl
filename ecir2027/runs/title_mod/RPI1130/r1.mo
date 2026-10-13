model AirTrioFormB
  "Three 1.8 kg quadrotors following a leader trajectory with distributed formation control, bounded rotor commands, peer-relative range, delayed pose messages, and 0.056 s message delay during the middle third."

  // Mission timing
  parameter Real Ts = 0.01 "s, 100 Hz control and trace rate";
  parameter Real Tfinal = 10.0 "s, mission duration";
  parameter Real fSample = 100.0 "Hz";

  // Delay disturbance
  parameter Real delayDist = 0.056 "s, injected message delay";
  parameter Real delayMax = 0.10 "s, upper bound for Modelica delay operator";
  parameter Real delayStart = Tfinal/3.0 "s, start of middle third";
  parameter Real delayEnd = 2.0*Tfinal/3.0 "s, end of middle third";
  Boolean middleDelay;

  // Quadrotor physical parameters
  parameter Real m = 1.8 "kg, mass of each quadrotor";
  parameter Real g = 9.81 "m/s2";
  parameter Real rotorMax = 9.84 "N, allowed command magnitude per rotor";
  parameter Real rotorCount = 4.0 "rotors per quadrotor";
  parameter Real totalThrustMax = rotorCount*rotorMax "N";
  parameter Real accMaxUp = totalThrustMax/m - g "m/s2";
  parameter Real accMaxDown = -g "m/s2";

  // Leader trajectory (not specified in request; simple ramp placeholder for simulation)
  parameter Real zL0 = 2.0 "m, initial leader altitude";
  parameter Real vL = 0.2 "m/s, leader climb rate placeholder";
  Real zL_ref "m";
  Real vzL_ref "m/s";
  Real aL_ref "m/s2";

  // Formation geometry (not specified; placeholder declared offsets)
  parameter Real offset2 = -1.0 "m, robot 2 signed offset relative to robot 1";
  parameter Real offset3 = 1.0 "m, robot 3 signed offset relative to robot 1";
  parameter Real minimumSeparation = 0.5 "m, required pairwise separation placeholder";
  parameter Real collisionRadius = 0.1 "m, collision threshold placeholder";

  // Obstacles outside nominal path (not specified; placeholder positions)
  parameter Real obstacleZ1 = -5.0 "m";
  parameter Real obstacleZ2 = 15.0 "m";

  // Control gains (placeholder, stable for this simple model)
  parameter Real kp = 10.0 "1/s2";
  parameter Real kd = 8.0 "1/s";
  parameter Real kAvoid = 5.0 "1/s2";

  // Estimator gains
  parameter Real kPos = 20.0 "1/s";
  parameter Real kVel = 20.0 "1/s";
  parameter Real kRange = 1.0 "1/s";

  // Physical states
  Real z1(start=2.0, fixed=true) "m";
  Real vz1(start=0.0, fixed=true) "m/s";
  Real z2(start=1.0, fixed=true) "m";
  Real vz2(start=0.0, fixed=true) "m/s";
  Real z3(start=3.0, fixed=true) "m";
  Real vz3(start=0.0, fixed=true) "m/s";

  // Accelerations
  Real acc1 "m/s2";
  Real acc2 "m/s2";
  Real acc3 "m/s2";

  // Thrust and rotor groups (12 independent bounded commands)
  Real T1cmd "N";
  Real T2cmd "N";
  Real T3cmd "N";
  Real T1 "N";
  Real T2 "N";
  Real T3 "N";
  Real f1_1 "N";
  Real f1_2 "N";
  Real f1_3 "N";
  Real f1_4 "N";
  Real f2_1 "N";
  Real f2_2 "N";
  Real f2_3 "N";
  Real f2_4 "N";
  Real f3_1 "N";
  Real f3_2 "N";
  Real f3_3 "N";
  Real f3_4 "N";
  Boolean actuatorSat1;
  Boolean actuatorSat2;
  Boolean actuatorSat3;
  Real actuatorLimitFraction1;
  Real actuatorLimitFraction2;
  Real actuatorLimitFraction3;

  // Sampled bounded local acceleration commands
  discrete Real accCmd1(start=0.0) "m/s2";
  discrete Real accCmd2(start=0.0) "m/s2";
  discrete Real accCmd3(start=0.0) "m/s2";
  Real accCmd1Raw "m/s2";
  Real accCmd2Raw "m/s2";
  Real accCmd3Raw "m/s2";

  // Avoidance terms
  Real avoid1 "m/s2";
  Real avoid2 "m/s2";
  Real avoid3 "m/s2";
  Real rep12For1 "m/s2";
  Real rep13For1 "m/s2";
  Real rep12For2 "m/s2";
  Real rep23For2 "m/s2";
  Real rep13For3 "m/s2";
  Real rep23For3 "m/s2";

  // Delayed pose messages
  Real z1For2 "m";
  Real vz1For2 "m/s";
  Real z1For3 "m";
  Real vz1For3 "m/s";
  Real z2For1 "m";
  Real vz2For1 "m/s";
  Real z3For1 "m";
  Real vz3For1 "m/s";
  Real z3For2 "m";
  Real vz3For2 "m/s";
  Real z2For3 "m";
  Real vz2For3 "m/s";
  Real commAge21 "s";
  Real commAge31 "s";
  Real commAge12 "s";
  Real commAge13 "s";
  Real commAge23 "s";
  Real commAge32 "s";
  Real maxCommAge "s";

  // Sensors
  Real gpsZ1 "m";
  Real gpsV1 "m/s";
  Real imuAcc1 "m/s2";
  Real gpsZ2 "m";
  Real gpsV2 "m/s";
  Real imuAcc2 "m/s2";
  Real gpsZ3 "m";
  Real gpsV3 "m/s";
  Real imuAcc3 "m/s2";
  Real range12_sensor "m";
  Real range13_sensor "m";
  Real range23_sensor "m";

  // Estimator states
  Real zEst1(start=2.0, fixed=true) "m";
  Real vEst1(start=0.0, fixed=true) "m/s";
  Real zEst2(start=1.0, fixed=true) "m";
  Real vEst2(start=0.0, fixed=true) "m/s";
  Real zEst3(start=3.0, fixed=true) "m";
  Real vEst3(start=0.0, fixed=true) "m/s";
  Real range12_est "m";
  Real range13_est "m";
  Real range23_est "m";
  Real range12_res "m";
  Real range13_res "m";
  Real range23_res "m";

  // Requirements and traces
  Real ePrimary "m";
  Real eForm2 "m";
  Real eForm3 "m";
  Real formationError "m";
  Real sep12 "m";
  Real sep13 "m";
  Real sep23 "m";
  Real pairwiseSeparation "m";
  Boolean noCollision;
  Boolean separationOK;
  Boolean obstacleClear1;
  Boolean obstacleClear2;
  Boolean obstacleClear3;
  Boolean obstacleClear;
  parameter Real trackingThreshold = 0.36 "m";
  parameter Real trackingCheckTime = 6.5 "s";

  // 100 Hz synchronized traces
  discrete Real trace_z1(start=2.0) "m";
  discrete Real trace_z2(start=1.0) "m";
  discrete Real trace_z3(start=3.0) "m";
  discrete Real trace_vz1(start=0.0) "m/s";
  discrete Real trace_vz2(start=0.0) "m/s";
  discrete Real trace_vz3(start=0.0) "m/s";
  discrete Real trace_accCmd1(start=0.0) "m/s2";
  discrete Real trace_accCmd2(start=0.0) "m/s2";
  discrete Real trace_accCmd3(start=0.0) "m/s2";
  discrete Real trace_range12(start=1.0) "m";
  discrete Real trace_range13(start=1.0) "m";
  discrete Real trace_range23(start=2.0) "m";
  discrete Real trace_commAge(start=0.0) "s";
  discrete Real trace_primaryError(start=0.0) "m";
  discrete Real trace_formationError(start=0.0) "m";
  discrete Real trace_pairwiseSeparation(start=1.0) "m";

  function safeSign "Zero-error-safe sign for 1D range correction"
    input Real x;
    output Real y;
  algorithm
    if x >= 1e-6 then
      y := 1.0;
    elseif x <= -1e-6 then
      y := -1.0;
    else
      y := 0.0;
    end if;
  end safeSign;

equation
  // Mission timing and delay window
  middleDelay = time >= delayStart and time <= delayEnd;

  // Leader trajectory
  zL_ref = zL0 + vL*time;
  vzL_ref = vL;
  aL_ref = 0.0;

  // Physical dynamics
  der(z1) = vz1;
  der(vz1) = acc1;
  der(z2) = vz2;
  der(vz2) = acc2;
  der(z3) = vz3;
  der(vz3) = acc3;

  // Sensors
  gpsZ1 = z1;
  gpsV1 = vz1;
  imuAcc1 = acc1;
  gpsZ2 = z2;
  gpsV2 = vz2;
  imuAcc2 = acc2;
  gpsZ3 = z3;
  gpsV3 = vz3;
  imuAcc3 = acc3;

  range12_sensor = abs(z1 - z2);
  range13_sensor = abs(z1 - z3);
  range23_sensor = abs(z2 - z3);

  // Delayed pose messages between peers
  z1For2 = if middleDelay then delay(zEst1, delayDist, delayMax) else zEst1;
  vz1For2 = if middleDelay then delay(vEst1, delayDist, delayMax) else vEst1;
  z1For3 = if middleDelay then delay(zEst1, delayDist, delayMax) else zEst1;
  vz1For3 = if middleDelay then delay(vEst1, delayDist, delayMax) else vEst1;

  z2For1 = if middleDelay then delay(zEst2, delayDist, delayMax) else zEst2;
  vz2For1 = if middleDelay then delay(vEst2, delayDist, delayMax) else vEst2;
  z3For1 = if middleDelay then delay(zEst3, delayDist, delayMax) else zEst3;
  vz3For1 = if middleDelay then delay(vEst3, delayDist, delayMax) else vEst3;

  z3For2 = if middleDelay then delay(zEst3, delayDist, delayMax) else zEst3;
  vz3For2 = if middleDelay then delay(vEst3, delayDist, delayMax) else vEst3;
  z2For3 = if middleDelay then delay(zEst2, delayDist, delayMax) else zEst2;
  vz2For3 = if middleDelay then delay(vEst2, delayDist, delayMax) else vEst2;

  commAge21 = if middleDelay then delayDist else 0.0;
  commAge31 = if middleDelay then delayDist else 0.0;
  commAge12 = if middleDelay then delayDist else 0.0;
  commAge13 = if middleDelay then delayDist else 0.0;
  commAge23 = if middleDelay then delayDist else 0.0;
  commAge32 = if middleDelay then delayDist else 0.0;
  maxCommAge = max(commAge21, max(commAge31, max(commAge12, max(commAge13, max(commAge23, commAge32)))));

  // Estimator fusion: GPS/IMU correction plus peer-relative range residuals
  range12_est = abs(zEst1 - zEst2);
  range13_est = abs(zEst1 - zEst3);
  range23_est = abs(zEst2 - zEst3);
  range12_res = range12_sensor - range12_est;
  range13_res = range13_sensor - range13_est;
  range23_res = range23_sensor - range23_est;

  der(zEst1) = vEst1 + kPos*(gpsZ1 - zEst1) + kRange*range12_res*safeSign(zEst1 - zEst2) + kRange*range13_res*safeSign(zEst1 - zEst3);
  der(vEst1) = imuAcc1 + kVel*(gpsV1 - vEst1);

  der(zEst2) = vEst2 + kPos*(gpsZ2 - zEst2) + kRange*range12_res*safeSign(zEst2 - zEst1) + kRange*range23_res*safeSign(zEst2 - zEst3);
  der(vEst2) = imuAcc2 + kVel*(gpsV2 - vEst2);

  der(zEst3) = vEst3 + kPos*(gpsZ3 - zEst3) + kRange*range13_res*safeSign(zEst3 - zEst1) + kRange*range23_res*safeSign(zEst3 - zEst2);
  der(vEst3) = imuAcc3 + kVel*(gpsV3 - vEst3);

  // Local avoidance using delayed peer pose messages
  rep12For1 = if abs(z1 - z2For1) < minimumSeparation then kAvoid*(minimumSeparation - abs(z1 - z2For1)) else 0.0;
  rep13For1 = if abs(z1 - z3For1) < minimumSeparation then kAvoid*(minimumSeparation - abs(z1 - z3For1)) else 0.0;
  rep12For2 = if abs(z2 - z1For2) < minimumSeparation then kAvoid*(minimumSeparation - abs(z2 - z1For2)) else 0.0;
  rep23For2 = if abs(z2 - z3For2) < minimumSeparation then kAvoid*(minimumSeparation - abs(z2 - z3For2)) else 0.0;
  rep13For3 = if abs(z3 - z1For3) < minimumSeparation then kAvoid*(minimumSeparation - abs(z3 - z1For3)) else 0.0;
  rep23For3 = if abs(z3 - z2For3) < minimumSeparation then kAvoid*(minimumSeparation - abs(z3 - z2For3)) else 0.0;

  avoid1 = rep12For1*safeSign(z1 - z2For1) + rep13For1*safeSign(z1 - z3For1);
  avoid2 = rep12For2*safeSign(z2 - z1For2) + rep23For2*safeSign(z2 - z3For2);
  avoid3 = rep13For3*safeSign(z3 - z1For3) + rep23For3*safeSign(z3 - z2For3);

  // Distributed formation commands
  accCmd1Raw = kp*(zL_ref - z1) + kd*(vzL_ref - vz1) + aL_ref + avoid1;
  accCmd2Raw = kp*((z1For2 + offset2) - z2) + kd*(vz1For2 - vz2) + aL_ref + avoid2;
  accCmd3Raw = kp*((z1For3 + offset3) - z3) + kd*(vz1For3 - vz3) + aL_ref + avoid3;

  // Actuator mapping and limits
  T1cmd = m*(accCmd1 + g);
  T2cmd = m*(accCmd2 + g);
  T3cmd = m*(accCmd3 + g);

  T1 = max(0.0, min(totalThrustMax, T1cmd));
  T2 = max(0.0, min(totalThrustMax, T2cmd));
  T3 = max(0.0, min(totalThrustMax, T3cmd));

  f1_1 = max(0.0, min(rotorMax, T1/4.0));
  f1_2 = max(0.0, min(rotorMax, T1/4.0));
  f1_3 = max(0.0, min(rotorMax, T1/4.0));
  f1_4 = max(0.0, min(rotorMax, T1/4.0));

  f2_1 = max(0.0, min(rotorMax, T2/4.0));
  f2_2 = max(0.0, min(rotorMax, T2/4.0));
  f2_3 = max(0.0, min(rotorMax, T2/4.0));
  f2_4 = max(0.0, min(rotorMax, T2/4.0));

  f3_1 = max(0.0, min(rotorMax, T3/4.0));
  f3_2 = max(0.0, min(rotorMax, T3/4.0));
  f3_3 = max(0.0, min(rotorMax, T3/4.0));
  f3_4 = max(0.0, min(rotorMax, T3/4.0));

  acc1 = (f1_1 + f1_2 + f1_3 + f1_4)/m - g;
  acc2 = (f2_1 + f2_2 + f2_3 + f2_4)/m - g;
  acc3 = (f3_1 + f3_2 + f3_3 + f3_4)/m - g;

  actuatorSat1 = (T1cmd < 0.0) or (T1cmd > totalThrustMax);
  actuatorSat2 = (T2cmd < 0.0) or (T2cmd > totalThrustMax);
  actuatorSat3 = (T3cmd < 0.0) or (T3cmd > totalThrustMax);
  actuatorLimitFraction1 = max(f1_1, max(f1_2, max(f1_3, f1_4)))/rotorMax;
  actuatorLimitFraction2 = max(f2_1, max(f2_2, max(f2_3, f2_4)))/rotorMax;
  actuatorLimitFraction3 = max(f3_1, max(f3_2, max(f3_3, f3_4)))/rotorMax;

  // Requirement monitors
  ePrimary = abs(z1 - zL_ref);
  eForm2 = abs((z2 - z1) - offset2);
  eForm3 = abs((z3 - z1) - offset3);
  formationError = sqrt(ePrimary*ePrimary + eForm2*eForm2 + eForm3*eForm3);

  sep12 = abs(z1 - z2);
  sep13 = abs(z1 - z3);
  sep23 = abs(z2 - z3);
  pairwiseSeparation = min(sep12, min(sep13, sep23));
  noCollision = pairwiseSeparation >= collisionRadius;
  separationOK = pairwiseSeparation >= minimumSeparation;

  obstacleClear1 = (abs(z1 - obstacleZ1) > collisionRadius) and (abs(z1 - obstacleZ2) > collisionRadius);
  obstacleClear2 = (abs(z2 - obstacleZ1) > collisionRadius) and (abs(z2 - obstacleZ2) > collisionRadius);
  obstacleClear3 = (abs(z3 - obstacleZ1) > collisionRadius) and (abs(z3 - obstacleZ2) > collisionRadius);
  obstacleClear = obstacleClear1 and obstacleClear2 and obstacleClear3;

  assert(noCollision, "Collision requirement failed");
  assert(obstacleClear, "Obstacle collision requirement failed");
  assert(separationOK, "Minimum pairwise separation requirement failed");
  assert(time <= trackingCheckTime or ePrimary < trackingThreshold, "Primary tracking error requirement failed after 6.5 s");

  // 100 Hz sampled control and synchronized traces
  when sample(0, Ts) then
    accCmd1 = max(accMaxDown, min(accMaxUp, accCmd1Raw));
    accCmd2 = max(accMaxDown, min(accMaxUp, accCmd2Raw));
    accCmd3 = max(accMaxDown, min(accMaxUp, accCmd3Raw));

    trace_z1 = z1;
    trace_z2 = z2;
    trace_z3 = z3;
    trace_vz1 = vz1;
    trace_vz2 = vz2;
    trace_vz3 = vz3;
    trace_accCmd1 = accCmd1;
    trace_accCmd2 = accCmd2;
    trace_accCmd3 = accCmd3;
    trace_range12 = range12_sensor;
    trace_range13 = range13_sensor;
    trace_range23 = range23_sensor;
    trace_commAge = maxCommAge;
    trace_primaryError = ePrimary;
    trace_formationError = formationError;
    trace_pairwiseSeparation = pairwiseSeparation;
  end when;

  annotation(experiment(StartTime=0, StopTime=10, Tolerance=1e-4, Interval=0.01));
end AirTrioFormB;