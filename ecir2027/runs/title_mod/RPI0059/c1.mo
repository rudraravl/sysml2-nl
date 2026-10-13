model TiltWingSurveyE
  /* TiltWingSurveyE: free-base tilt-wing aerial robot with waypoint survey,
     multi-sensor fusion, obstacles, bounded crosswind disturbance, and
     fail-closed acceptance. Per-waypoint deadlines are NOT specified in the
     requirement, so deadline values are unknown and deadline enforcement is
     intentionally omitted; waypoint sequencing is distance-triggered. */

  // ---- Physical parameters ----
  parameter Real m(unit="kg") = 6.2 "capsule fuselage mass";
  parameter Real rotorArm(unit="m") = 0.62 "rotor distance from center";
  parameter Real wingSpan(unit="m") = 1.8 "wing span";
  parameter Real gammaMin(unit="rad") = 0.0 "rotor tilt lower bound";
  parameter Real gammaMax(unit="rad") = 1.57 "rotor tilt upper bound";
  parameter Real Tmax(unit="N") = 57.2 "thrust command bound per rotor";
  parameter Real g(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real tauTilt(unit="s") = 0.15 "tilt-joint actuator time constant";
  parameter Real tauThrust(unit="s") = 0.05 "thrust actuator time constant";
  parameter Real tauTheta(unit="s") = 0.20 "heading actuator time constant";

  // ---- Mission / scenario ----
  parameter Real dt(unit="s") = 0.004 "control period (250 Hz)";
  parameter Real tEnd(unit="s") = 16.0 "scenario duration";
  parameter Real errTol(unit="m") = 0.315 "primary tracking error tolerance";
  parameter Real tFinalCheck(unit="s") = 10.4 "final-error check time";
  parameter Real crosswindForce(unit="N") = 7.2 "controlled crosswind magnitude";
  parameter Real wp[4,3](each unit="m") = [0,0,1.5; 4,0,2.5; 4,3,2.5; 1,4,2]
    "survey waypoints";

  // Three fixed cylindrical obstacles placed outside the reference polyline
  parameter Real obsX[3](each unit="m") = {2.0,-1.0,5.0};
  parameter Real obsY[3](each unit="m") = {-1.5,2.0,2.0};
  parameter Real obsR[3](each unit="m") = {0.5,0.5,0.5};
  parameter Real obsH[3](each unit="m") = {3.0,3.0,3.0};

  // ---- Controller / estimator gains ----
  parameter Real Kp = 3.0 "position gain";
  parameter Real Kd = 3.5 "velocity damping gain";
  parameter Real KpEst = 4.0 "estimator position gain";
  parameter Real KvEst = 6.0 "estimator velocity gain";

  // ---- Continuous plant state ----
  Real p[3](each unit="m", start={0.0,0.0,1.5}) "fuselage position";
  Real v[3](each unit="m/s", start={0.0,0.0,0.0}) "fuselage velocity";
  Real T1(unit="N", start=30.41) "rotor 1 thrust (left)";
  Real T2(unit="N", start=30.41) "rotor 2 thrust (right)";
  Real gammaL_raw(start=0.0) "left tilt actuator state";
  Real gammaR_raw(start=0.0) "right tilt actuator state";
  Real gammaL(unit="rad") "left rotor tilt angle";
  Real gammaR(unit="rad") "right rotor tilt angle";
  Real thetaState(unit="rad", start=0.0) "heading state";

  // ---- Discrete controller outputs (sampled at 250 Hz) ----
  discrete Real T1_cmd(unit="N", start=30.41) "rotor 1 thrust command";
  discrete Real T2_cmd(unit="N", start=30.41) "rotor 2 thrust command";
  discrete Real gammaL_cmd(unit="rad", start=0.0) "left tilt command";
  discrete Real gammaR_cmd(unit="rad", start=0.0) "right tilt command";
  discrete Real theta_cmd(unit="rad", start=0.0) "heading command";
  discrete Real p_des[3](each unit="m", start={0.0,0.0,1.5}) "desired position";
  discrete Real v_des[3](each unit="m/s", start={0.0,0.0,0.0}) "desired velocity";
  discrete Real a_ff[3](each unit="m/s2", start={0.0,0.0,0.0}) "feedforward acceleration";
  Integer wpIdx(start=1) "active waypoint index";

  // ---- Thrust vector in world frame ----
  Real T_total(unit="N") "total rotor thrust";
  Real gammaAvg(unit="rad") "average rotor tilt";
  Real Tx(unit="N"), Ty(unit="N"), Tz(unit="N") "world-frame thrust components";
  Real crosswindOn "crosswind enable (middle third of run)";

  // ---- Sensors (synchronized timestamps) ----
  Real gps_p[3](each unit="m") "GPS position measurement";
  Real imu_a[3](each unit="m/s2") "IMU specific-force measurement";
  Real alt_z(unit="m") "altimeter measurement";
  Real cam_pose[3](each unit="m") "camera pose measurement";
  Real ts_gps(unit="s"), ts_imu(unit="s"), ts_alt(unit="s"), ts_cam(unit="s");

  // ---- Fused state estimate ----
  Real p_est[3](each unit="m", start={0.0,0.0,1.5}) "fused position estimate";
  Real v_est[3](each unit="m/s", start={0.0,0.0,0.0}) "fused velocity estimate";
  Real q_est[4] "fused attitude quaternion (normalized)";

  // ---- Acceptance / fail-closed ----
  Real err_wp(unit="m") "tracking error to active waypoint";
  Real err_wp4(unit="m") "tracking error to final waypoint";
  Real obsDist[3](each unit="m") "planar distance to each obstacle";
  Boolean ok_thrust;
  Boolean ok_attitude;
  Boolean ok_wpErr;
  Boolean ok_finite;
  Boolean ok_collision;
  Boolean ok_finalErr;
  Boolean ok_all "fail-closed acceptance flag";

protected
  Real a_des[3] "desired acceleration";
  Real Tx_raw, Ty_raw, Tz_raw, T_total_raw "raw thrust-vector intermediates";
  Real gamma_raw, theta_raw, T_half, hnorm;
  Real q_raw[4], qn;

algorithm
  when sample(0.0, dt) then
    // Distance-triggered waypoint advance (deadlines unknown -> omitted)
    if abs(p[1]-wp[pre(wpIdx),1]) < 0.6 and
       abs(p[2]-wp[pre(wpIdx),2]) < 0.6 and
       abs(p[3]-wp[pre(wpIdx),3]) < 0.6 and pre(wpIdx) < 4 then
      wpIdx := pre(wpIdx) + 1;
    else
      wpIdx := pre(wpIdx);
    end if;

    p_des[1] := wp[wpIdx,1];
    p_des[2] := wp[wpIdx,2];
    p_des[3] := wp[wpIdx,3];
    v_des[1] := 0.0;
    v_des[2] := 0.0;
    v_des[3] := 0.0;
    // Feedforward acceleration: trajectory timing unknown -> set to zero
    a_ff[1] := 0.0;
    a_ff[2] := 0.0;
    a_ff[3] := 0.0;

    a_des[1] := Kp*(p_des[1]-p[1]) + Kd*(v_des[1]-v[1]) + a_ff[1];
    a_des[2] := Kp*(p_des[2]-p[2]) + Kd*(v_des[2]-v[2]) + a_ff[2];
    a_des[3] := Kp*(p_des[3]-p[3]) + Kd*(v_des[3]-v[3]) + a_ff[3];

    Tx_raw := m*a_des[1];
    Ty_raw := m*a_des[2];
    Tz_raw := m*(a_des[3] + g);
    T_total_raw := sqrt(Tx_raw*Tx_raw + Ty_raw*Ty_raw + Tz_raw*Tz_raw + 1.0e-9);
    hnorm := sqrt(Tx_raw*Tx_raw + Ty_raw*Ty_raw + 1.0e-9);
    gamma_raw := atan2(hnorm, Tz_raw);
    gammaL_cmd := if gamma_raw < gammaMin then gammaMin
                  elseif gamma_raw > gammaMax then gammaMax
                  else gamma_raw;
    gammaR_cmd := gammaL_cmd;
    theta_raw := atan2(Ty_raw, Tx_raw + 1.0e-9);
    theta_cmd := theta_raw;

    T_half := T_total_raw/2.0;
    if T_half > Tmax then
      T1_cmd := Tmax;
    elseif T_half < 0.0 then
      T1_cmd := 0.0;
    else
      T1_cmd := T_half;
    end if;
    T2_cmd := T1_cmd;
  end when;

equation
  // ---- Point-mass plant kinematics ----
  der(p[1]) = v[1];
  der(p[2]) = v[2];
  der(p[3]) = v[3];

  // ---- Actuators ----
  der(T1) = (T1_cmd - T1)/tauThrust;
  der(T2) = (T2_cmd - T2)/tauThrust;
  der(gammaL_raw) = (gammaL_cmd - gammaL_raw)/tauTilt;
  der(gammaR_raw) = (gammaR_cmd - gammaR_raw)/tauTilt;
  der(thetaState) = (theta_cmd - thetaState)/tauTheta;
  gammaL = if gammaL_raw < gammaMin then gammaMin
           elseif gammaL_raw > gammaMax then gammaMax
           else gammaL_raw;
  gammaR = if gammaR_raw < gammaMin then gammaMin
           elseif gammaR_raw > gammaMax then gammaMax
           else gammaR_raw;

  // ---- Thrust resolution in world frame ----
  T_total = T1 + T2;
  gammaAvg = (gammaL + gammaR)/2.0;
  Tx = T_total*sin(gammaAvg)*cos(thetaState);
  Ty = T_total*sin(gammaAvg)*sin(thetaState);
  Tz = T_total*cos(gammaAvg);

  // ---- Controlled crosswind disturbance (middle third of run) ----
  crosswindOn = if time >= tEnd/3.0 and time <= 2.0*tEnd/3.0 then 1.0 else 0.0;

  // ---- Newton equations ----
  m*der(v[1]) = Tx;
  m*der(v[2]) = Ty + crosswindForce*crosswindOn;
  m*der(v[3]) = Tz - m*g;

  // ---- Sensor models with synchronized timestamps ----
  gps_p[1] = p[1]; gps_p[2] = p[2]; gps_p[3] = p[3];
  alt_z = p[3];
  imu_a[1] = Tx/m;
  imu_a[2] = (Ty + crosswindForce*crosswindOn)/m;
  imu_a[3] = Tz/m - g;
  cam_pose[1] = p[1]; cam_pose[2] = p[2]; cam_pose[3] = p[3];
  ts_gps = time; ts_imu = time; ts_alt = time; ts_cam = time;

  // ---- Sensor fusion (complementary filter on GPS/altimeter/IMU) ----
  der(p_est[1]) = v_est[1] + KpEst*(gps_p[1] - p_est[1]);
  der(p_est[2]) = v_est[2] + KpEst*(gps_p[2] - p_est[2]);
  der(p_est[3]) = v_est[3] + KpEst*(alt_z - p_est[3]);
  der(v_est[1]) = imu_a[1] + KvEst*(v[1] - v_est[1]);
  der(v_est[2]) = imu_a[2] + KvEst*(v[2] - v_est[2]);
  der(v_est[3]) = imu_a[3] + KvEst*(v[3] - v_est[3]);

  // ---- Fused attitude quaternion from heading + average tilt ----
  q_raw[1] = cos(gammaAvg/2.0)*cos(thetaState/2.0);
  q_raw[2] = sin(gammaAvg/2.0)*cos(thetaState/2.0);
  q_raw[3] = cos(gammaAvg/2.0)*sin(thetaState/2.0);
  q_raw[4] = -sin(gammaAvg/2.0)*sin(thetaState/2.0);
  qn = sqrt(q_raw[1]^2 + q_raw[2]^2 + q_raw[3]^2 + q_raw[4]^2 + 1.0e-12);
  q_est[1] = q_raw[1]/qn;
  q_est[2] = q_raw[2]/qn;
  q_est[3] = q_raw[3]/qn;
  q_est[4] = q_raw[4]/qn;

  // ---- Tracking errors and obstacle distances ----
  err_wp = sqrt((p[1]-wp[wpIdx,1])^2 + (p[2]-wp[wpIdx,2])^2 + (p[3]-wp[wpIdx,3])^2);
  err_wp4 = sqrt((p[1]-wp[4,1])^2 + (p[2]-wp[4,2])^2 + (p[3]-wp[4,3])^2);
  obsDist[1] = sqrt((p[1]-obsX[1])^2 + (p[2]-obsY[1])^2);
  obsDist[2] = sqrt((p[1]-obsX[2])^2 + (p[2]-obsY[2])^2);
  obsDist[3] = sqrt((p[1]-obsX[3])^2 + (p[2]-obsY[3])^2);

  // ---- Acceptance predicates (fail-closed) ----
  ok_thrust = (T1 >= -1.0e-6) and (T1 <= Tmax + 1.0e-6) and
              (T2 >= -1.0e-6) and (T2 <= Tmax + 1.0e-6);
  ok_attitude = (gammaL >= gammaMin - 1.0e-6) and (gammaL <= gammaMax + 1.0e-6) and
                (gammaR >= gammaMin - 1.0e-6) and (gammaR <= gammaMax + 1.0e-6);
  ok_wpErr = err_wp <= 5.0;
  ok_finite = (abs(p[1])<=1.0e9) and (abs(p[2])<=1.0e9) and (abs(p[3])<=1.0e9) and
              (abs(v[1])<=1.0e9) and (abs(v[2])<=1.0e9) and (abs(v[3])<=1.0e9) and
              (abs(T1)<=1.0e9) and (abs(T2)<=1.0e9) and
              (abs(T1_cmd)<=1.0e9) and (abs(T2_cmd)<=1.0e9) and
              (abs(gammaL_cmd)<=1.0e9) and (abs(gammaR_cmd)<=1.0e9) and
              (abs(theta_cmd)<=1.0e9) and
              (abs(p_est[1])<=1.0e9) and (abs(p_est[2])<=1.0e9) and (abs(p_est[3])<=1.0e9) and
              (abs(v_est[1])<=1.0e9) and (abs(v_est[2])<=1.0e9) and (abs(v_est[3])<=1.0e9) and
              (abs(q_est[1])<=1.0e9) and (abs(q_est[2])<=1.0e9) and
              (abs(q_est[3])<=1.0e9) and (abs(q_est[4])<=1.0e9);
  ok_collision = (obsDist[1] > obsR[1]) and (obsDist[2] > obsR[2]) and (obsDist[3] > obsR[3]);
  ok_finalErr = (time < tFinalCheck) or (err_wp4 < errTol);
  ok_all = ok_thrust and ok_attitude and ok_wpErr and ok_finite and ok_collision and ok_finalErr;

  annotation(
    experiment(StopTime=16.0, Tolerance=1.0e-4, Interval=0.004),
    Documentation(info="TiltWingSurveyE: tilt-wing survey robot with bounded waypoint tracking, multi-sensor fusion, three fixed cylindrical obstacles outside the survey polyline, and a 7.2 N middle-third crosswind disturbance. Fail-closed acceptance requires thrust/attitude bounds, finite estimator, no collision, and final tracking error below 0.315 m after 10.4 s. Per-waypoint deadlines are unspecified and therefore omitted."));
end TiltWingSurveyE;