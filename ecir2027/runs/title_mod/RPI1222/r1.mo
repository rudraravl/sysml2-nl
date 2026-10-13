model WheelIMUMapD
  function wrapAngle
    input Real a;
    output Real w;
  algorithm
    w := mod(a + pi, 2.0*pi) - pi;
  end wrapAngle;

  // Plant parameters (mass and torque limit are specified; other geometry/friction values are chosen for simulation only)
  parameter Real m = 16.0 "kg";
  parameter Real I_z = 2.0 "kg.m2";
  parameter Real r = 0.10 "m";
  parameter Real L = 0.50 "m";
  parameter Real c_v = 8.0 "N.s/m";
  parameter Real c_omega = 4.0 "N.m.s/rad";
  parameter Real tauMax = 10.0 "N.m";
  parameter Real robotRadius = 0.25 "m";

  // Route parameters
  parameter Real R = 2.0 "m";
  parameter Real T = 14.0 "s";
  parameter Real x0 = R "m";
  parameter Real y0 = 0.0 "m";
  parameter Real psi0 = pi/2 "rad";
  parameter Real omega0 = 2.0*pi/T "rad/s";
  parameter Real v0 = R*omega0 "m/s";

  // Output/sample rate
  parameter Real outputRate_Hz = 200.0 "Hz";
  parameter Real Ts = 1.0/outputRate_Hz "s";

  // Controller gains (chosen for stable path following)
  parameter Real Kv_pos = 0.5;
  parameter Real Kw_yaw = 1.0;
  parameter Real Kcross = 0.1;
  parameter Real Kv_drive = 20.0;
  parameter Real Kw_drive = 10.0;
  parameter Real v_cmd_max = 1.5 "m/s";
  parameter Real omega_cmd_max = 2.0 "rad/s";

  // Sensor noise and bias parameters (values not stated are chosen and declared explicitly)
  parameter Real encoderNoise = 0.01 "rad/s";
  parameter Real gyroBiasX = 0.001 "rad/s";
  parameter Real gyroBiasY = 0.001 "rad/s";
  parameter Real gyroBiasZ = 0.002 "rad/s";
  parameter Real gyroNoiseX = 0.005 "rad/s";
  parameter Real gyroNoiseY = 0.005 "rad/s";
  parameter Real gyroNoiseZ = 0.005 "rad/s";
  parameter Real accelBiasX = 0.02 "m/s2";
  parameter Real accelBiasY = 0.02 "m/s2";
  parameter Real accelBiasZ = 0.02 "m/s2";
  parameter Real accelNoiseX = 0.05 "m/s2";
  parameter Real accelNoiseY = 0.05 "m/s2";
  parameter Real accelNoiseZ = 0.05 "m/s2";
  parameter Real rangeNoise = 0.01 "m";
  parameter Real cameraNoise = 0.01 "rad";
  parameter Real sonarNoise = 0.01 "m";

  // Landmark perturbation disturbance
  parameter Real landmarkPerturb = 0.2 "m";
  parameter Real tMidStart = T/3.0 "s";
  parameter Real tMidEnd = 2.0*T/3.0 "s";

  // Shared world-frame landmarks and obstacles
  parameter Real landmarkX[6] = {2.8, 1.4, -2.8, -1.4, 0.0, 0.0} "m";
  parameter Real landmarkY[6] = {0.0, 2.424, 0.0, -2.424, 2.8, -2.8} "m";
  parameter Real obstacleX[2] = {0.0, -0.8} "m";
  parameter Real obstacleY[2] = {0.0, 0.5} "m";

  // Estimator parameters
  parameter Real Qxx = 1e-4 "m2/s";
  parameter Real Qyy = 1e-4 "m2/s";
  parameter Real Qth = 1e-4 "rad2/s";
  parameter Real Qv = 1e-4 "(m/s)2/s";
  parameter Real Qw = 1e-4 "(rad/s)2/s";
  parameter Real Rv_od = 1e-4 "(m/s)2";
  parameter Real Rw_od = 1e-4 "(rad/s)2";
  parameter Real Rrange = 1e-4 "m2";
  parameter Real rangeGate = 0.10 "m";
  parameter Real closureStart = 13.9 "s";
  parameter Real closureGain = 0.1;

  // Plant state
  Real x(start=x0) "m";
  Real y(start=y0) "m";
  Real psi(start=psi0) "rad";
  Real v(start=v0) "m/s";
  Real omega(start=omega0) "rad/s";

  // Wheel torques
  output Real tauR "N.m";
  output Real tauL "N.m";
  Real tauR_cmd "N.m";
  Real tauL_cmd "N.m";

  // Command traces
  output Real v_cmd "m/s";
  output Real omega_cmd "rad/s";

  // Wheel encoder outputs
  Real wR_enc "rad/s";
  Real wL_enc "rad/s";
  output Real v_odom "m/s";
  output Real omega_odom "rad/s";

  // Six-axis IMU outputs
  output Real gyroMeasX "rad/s";
  output Real gyroMeasY "rad/s";
  output Real gyroMeasZ "rad/s";
  output Real axMeas "m/s2";
  output Real ayMeas "m/s2";
  output Real azMeas "m/s2";

  // Range, camera, and sonar observations
  output Real rangeMeas[6] "m";
  output Real cameraRawBearing[6] "rad";
  output Real sonarRawRange[2] "m";

  // Disturbance and obstacle monitoring
  output Real landmarkPerturbation "m";
  output Real minObstacleClearance "m";
  output Real collisionDetected "1 if collision, 0 otherwise";

  // Estimator outputs
  output Real primaryTrackingError "m";
  output Real estimatorPoseError "m";
  output Real estimatorHeadingError "rad";
  output Real covarianceNorm;
  output Real loopClosurePosError "m";
  output Real loopClosureHeadingError "rad";
  output Real outputRateOut = outputRate_Hz "Hz";

  // Synchronized traces sampled at outputRate_Hz
  output Real stateTrace[5](start={x0,y0,psi0,v0,omega0});
  output Real commandTrace[4](start={0.0,0.0,v0,omega0});
  output Real estimatorTrace[5](start={x0,y0,psi0,v0,omega0});
  output Real sensorTrace[8](start={0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0});
  output Real rangeTrace[6](start={0.0,0.0,0.0,0.0,0.0,0.0});
  output Real exteroceptiveRawTrace[8](start={0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0});

protected
  Real a_body "m/s2";
  Real theta_path "rad";
  Real x_d "m";
  Real y_d "m";
  Real psi_d "rad";
  Real ex "m";
  Real ey "m";
  Real ex_body "m";
  Real ey_body "m";
  Real epsi "rad";
  Real tau_sum_cmd "N.m";
  Real tau_diff_cmd "N.m";
  Real rangeObs1 "m";
  Real rangeObs2 "m";
  Boolean perturbActive;
  Boolean closureActive;

  // Estimator discrete states
  discrete Real x_est(start=x0) "m";
  discrete Real y_est(start=y0) "m";
  discrete Real psi_est(start=psi0) "rad";
  discrete Real v_est(start=v0) "m/s";
  discrete Real omega_est(start=omega0) "rad/s";
  discrete Real Pxx(start=0.01) "m2";
  discrete Real Pyy(start=0.01) "m2";
  discrete Real Pth(start=0.01) "rad2";
  discrete Real Pv(start=0.01) "(m/s)2";
  discrete Real Pw(start=0.01) "(rad/s)2";

  // Estimator temporaries
  Real dt;
  Real yawRateCorr;
  Real aBodyCorr;
  Real x_pred;
  Real y_pred;
  Real psi_pred;
  Real v_pred;
  Real omega_pred;
  Real Pxx_pred;
  Real Pyy_pred;
  Real Pth_pred;
  Real Pv_pred;
  Real Pw_pred;
  Real Kv_od;
  Real Kw_od;
  Real rPred;
  Real innov;
  Real Hx;
  Real Hy;
  Real S;
  Real Kx;
  Real Ky;
  Real eLoopX;
  Real eLoopY;
  Real eLoopPsi;

equation
  // Differential-drive dynamics
  der(x) = v*cos(psi);
  der(y) = v*sin(psi);
  der(psi) = omega;
  der(v) = ((tauR + tauL)/r - c_v*v)/m;
  der(omega) = ((tauR - tauL)*L/(2.0*r) - c_omega*omega)/I_z;

  // Reference closed route
  theta_path = 2.0*pi*time/T;
  x_d = R*cos(theta_path);
  y_d = R*sin(theta_path);
  psi_d = theta_path + pi/2;

  // Path-following controller
  ex = x_d - x;
  ey = y_d - y;
  ex_body = cos(psi)*ex + sin(psi)*ey;
  ey_body = -sin(psi)*ex + cos(psi)*ey;
  epsi = wrapAngle(psi_d - psi);
  v_cmd = max(0.0, min(v_cmd_max, v0 + Kv_pos*ex_body));
  omega_cmd = max(-omega_cmd_max, min(omega_cmd_max, omega0 + Kw_yaw*epsi + Kcross*ey_body));

  // Torque commands with per-wheel 10 N.m limit
  tau_sum_cmd = r*(c_v*v + Kv_drive*(v_cmd - v));
  tau_diff_cmd = (2.0*r/L)*(c_omega*omega + Kw_drive*(omega_cmd - omega));
  tauR_cmd = 0.5*tau_sum_cmd + 0.5*tau_diff_cmd;
  tauL_cmd = 0.5*tau_sum_cmd - 0.5*tau_diff_cmd;
  tauR = max(-tauMax, min(tauMax, tauR_cmd));
  tauL = max(-tauMax, min(tauMax, tauL_cmd));

  // Wheel encoders
  wR_enc = v/r + L*omega/(2.0*r) + encoderNoise*sin(2.0*pi*10.0*time);
  wL_enc = v/r - L*omega/(2.0*r) + encoderNoise*sin(2.0*pi*10.5*time + 1.0);
  v_odom = (r/2.0)*(wR_enc + wL_enc);
  omega_odom = (r/L)*(wR_enc - wL_enc);

  // Center-mounted six-axis IMU
  a_body = der(v);
  gyroMeasX = gyroBiasX + gyroNoiseX*sin(2.0*pi*9.0*time);
  gyroMeasY = gyroBiasY + gyroNoiseY*sin(2.0*pi*9.5*time + 1.0);
  gyroMeasZ = omega + gyroBiasZ + gyroNoiseZ*sin(2.0*pi*8.7*time + 2.0);
  axMeas = a_body + accelBiasX + accelNoiseX*sin(2.0*pi*7.0*time);
  ayMeas = -v*omega + accelBiasY + accelNoiseY*sin(2.0*pi*7.5*time + 1.0);
  azMeas = 9.81 + accelBiasZ + accelNoiseZ*sin(2.0*pi*6.5*time + 2.0);

  // Landmark perturbation disturbance during middle third
  perturbActive = time >= tMidStart and time < tMidEnd;
  landmarkPerturbation = if perturbActive then landmarkPerturb else 0.0;

  // Range updates (fused), camera raw bearings and sonar raw ranges kept separate
  for i in 1:6 loop
    rangeMeas[i] = sqrt(max((x - (landmarkX[i] + landmarkPerturbation))^2 + (y - landmarkY[i])^2, 1e-6)) + rangeNoise*sin(2.0*pi*(5+i)*time + i);
    cameraRawBearing[i] = wrapAngle(atan2(landmarkY[i] - y, landmarkX[i] + landmarkPerturbation - x) + cameraNoise*sin(2.0*pi*(6+i)*time + i));
  end for;
  for j in 1:2 loop
    sonarRawRange[j] = sqrt(max((x - obstacleX[j])^2 + (y - obstacleY[j])^2, 1e-6)) + sonarNoise*sin(2.0*pi*(7+j)*time + j);
  end for;

  // Obstacle clearance and collision flag
  rangeObs1 = sqrt(max((x - obstacleX[1])^2 + (y - obstacleY[1])^2, 1e-6));
  rangeObs2 = sqrt(max((x - obstacleX[2])^2 + (y - obstacleY[2])^2, 1e-6));
  minObstacleClearance = min(rangeObs1, rangeObs2) - robotRadius;
  collisionDetected = if minObstacleClearance <= 0.0 then 1.0 else 0.0;

  // Estimator and loop-closure error outputs
  closureActive = time >= closureStart;
  primaryTrackingError = sqrt(max((x_d - x)^2 + (y_d - y)^2, 1e-12));
  estimatorPoseError = sqrt(max((x_est - x)^2 + (y_est - y)^2, 1e-12));
  estimatorHeadingError = abs(wrapAngle(psi_est - psi));
  covarianceNorm = sqrt(max(Pxx^2 + Pyy^2 + Pth^2 + Pv^2 + Pw^2, 1e-12));
  loopClosurePosError = if closureActive then sqrt(max((x_est - x0)^2 + (y_est - y0)^2, 1e-12)) else 0.0;
  loopClosureHeadingError = if closureActive then abs(wrapAngle(psi_est - psi0)) else 0.0;

  // Safety and requirement assertions
  assert(noEvent(abs(x) < 100.0 and abs(y) < 100.0 and abs(v) < 100.0 and abs(omega) < 100.0), "physical value out of range");
  assert(noEvent(abs(tauR) <= 10.0001 and abs(tauL) <= 10.0001), "torque limit violated");
  assert(noEvent(abs(x_est) < 100.0 and abs(y_est) < 100.0 and abs(v_est) < 100.0 and abs(omega_est) < 100.0), "estimator value out of range");
  assert(noEvent(covarianceNorm < 100.0), "covariance not finite");
  assert(noEvent(time < 9.1 or primaryTrackingError < 0.25), "tracking error requirement violated");
  assert(noEvent(minObstacleClearance > 0.0), "collision detected");

algorithm
  when sample(Ts, Ts) then
    // Prediction using IMU
    dt := Ts;
    yawRateCorr := gyroMeasZ - gyroBiasZ;
    aBodyCorr := axMeas - accelBiasX;
    x_pred := pre(x_est) + pre(v_est)*cos(pre(psi_est))*dt;
    y_pred := pre(y_est) + pre(v_est)*sin(pre(psi_est))*dt;
    psi_pred := wrapAngle(pre(psi_est) + yawRateCorr*dt);
    v_pred := pre(v_est) + aBodyCorr*dt;
    omega_pred := yawRateCorr;

    Pxx_pred := pre(Pxx) + Qxx*dt + abs(pre(v_est))*dt*0.01;
    Pyy_pred := pre(Pyy) + Qyy*dt + abs(pre(v_est))*dt*0.01;
    Pth_pred := pre(Pth) + Qth*dt;
    Pv_pred := pre(Pv) + Qv*dt;
    Pw_pred := pre(Pw) + Qw*dt;

    // Odometry update
    Kv_od := Pv_pred/(Pv_pred + Rv_od);
    v_pred := v_pred + Kv_od*(v_odom - v_pred);
    Pv_pred := max((1.0 - Kv_od)*Pv_pred, 1e-9);

    Kw_od := Pw_pred/(Pw_pred + Rw_od);
    omega_pred := omega_pred + Kw_od*(omega_odom - omega_pred);
    Pw_pred := max((1.0 - Kw_od)*Pw_pred, 1e-9);

    // Range updates, gated and disabled during the controlled perturbation interval
    for i in 1:6 loop
      rPred := sqrt(max((x_pred - landmarkX[i])^2 + (y_pred - landmarkY[i])^2, 1e-6));
      innov := rangeMeas[i] - rPred;
      if (time < tMidStart or time >= tMidEnd) and abs(innov) < rangeGate then
        Hx := (x_pred - landmarkX[i])/rPred;
        Hy := (y_pred - landmarkY[i])/rPred;
        S := Hx*Hx*Pxx_pred + Hy*Hy*Pyy_pred + Rrange;
        if S > 1e-6 then
          Kx := Pxx_pred*Hx/S;
          Ky := Pyy_pred*Hy/S;
          x_pred := x_pred + Kx*innov;
          y_pred := y_pred + Ky*innov;
          Pxx_pred := max(Pxx_pred*(1.0 - Kx*Hx), 1e-9);
          Pyy_pred := max(Pyy_pred*(1.0 - Ky*Hy), 1e-9);
        end if;
      end if;
    end for;

    // Loop-closure correction near the end of the closed route
    if time >= closureStart then
      eLoopX := x0 - x_pred;
      eLoopY := y0 - y_pred;
      eLoopPsi := wrapAngle(psi0 - psi_pred);
      x_pred := x_pred + closureGain*eLoopX;
      y_pred := y_pred + closureGain*eLoopY;
      psi_pred := wrapAngle(psi_pred + closureGain*eLoopPsi);
      Pxx_pred := max(Pxx_pred*0.9, 1e-9);
      Pyy_pred := max(Pyy_pred*0.9, 1e-9);
      Pth_pred := max(Pth_pred*0.9, 1e-9);
    end if;

    // Store estimator states
    x_est := x_pred;
    y_est := y_pred;
    psi_est := psi_pred;
    v_est := v_pred;
    omega_est := omega_pred;
    Pxx := Pxx_pred;
    Pyy := Pyy_pred;
    Pth := Pth_pred;
    Pv := Pv_pred;
    Pw := Pw_pred;

    // Synchronized traces
    stateTrace[1] := x;
    stateTrace[2] := y;
    stateTrace[3] := psi;
    stateTrace[4] := v;
    stateTrace[5] := omega;
    commandTrace[1] := tauR;
    commandTrace[2] := tauL;
    commandTrace[3] := v_cmd;
    commandTrace[4] := omega_cmd;
    estimatorTrace[1] := x_est;
    estimatorTrace[2] := y_est;
    estimatorTrace[3] := psi_est;
    estimatorTrace[4] := v_est;
    estimatorTrace[5] := omega_est;
    sensorTrace[1] := v_odom;
    sensorTrace[2] := omega_odom;
    sensorTrace[3] := gyroMeasX;
    sensorTrace[4] := gyroMeasY;
    sensorTrace[5] := gyroMeasZ;
    sensorTrace[6] := axMeas;
    sensorTrace[7] := ayMeas;
    sensorTrace[8] := azMeas;
    for i in 1:6 loop
      rangeTrace[i] := rangeMeas[i];
      exteroceptiveRawTrace[i] := cameraRawBearing[i];
    end for;
    for j in 1:2 loop
      exteroceptiveRawTrace[6 + j] := sonarRawRange[j];
    end for;
  end when;

  annotation(experiment(StopTime=14, Tolerance=1e-6, Interval=0.005));
end WheelIMUMapD;