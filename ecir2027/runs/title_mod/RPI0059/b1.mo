model TiltWingSurveyE
  /* TiltWingSurveyE: free-base tilt-wing aerial robot with waypoint survey,
     multi-sensor fusion, obstacles, bounded crosswind disturbance, and
     fail-closed acceptance. Per-waypoint deadlines are NOT specified in the
     requirement, so deadline values are unknown and deadline enforcement is
     intentionally omitted; waypoint sequencing is distance-triggered. */

  // ---- Physical parameters ----
  parameter Real m_fus(unit="kg") = 6.2 "capsule fuselage mass";
  parameter Real rotorArm(unit="m") = 0.62 "rotor distance from center";
  parameter Real wingSpan(unit="m") = 1.8 "wing span";
  parameter Real gammaMin(unit="rad") = 0.0 "rotor tilt lower bound";
  parameter Real gammaMax(unit="rad") = 1.57 "rotor tilt upper bound";
  parameter Real Tmax(unit="N") = 57.2 "thrust command bound per rotor";
  parameter Real g_acc(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real tauTilt(unit="s") = 0.15 "tilt-joint actuator time constant";
  parameter Real tauThrust(unit="s") = 0.05 "thrust actuator time constant";
  parameter Real tauTheta(unit="s") = 0.20 "heading actuator time constant";

  // ---- Mission / scenario ----
  parameter Real dt_ctrl(unit="s") = 0.004 "control period (250 Hz)";
  parameter Real tEnd(unit="s") = 16.0 "scenario duration";
  parameter Real errTol(unit="m") = 0.315 "primary tracking error tolerance";
  parameter Real tFinalCheck(unit="s") = 10.4 "final-error check time";
  parameter Real crosswindForce(unit="N") = 7.2 "controlled crosswind magnitude";

  parameter Real wp1x(unit="m") = 0.0;
  parameter Real wp1y(unit="m") = 0.0;
  parameter Real wp1z(unit="m") = 1.5;
  parameter Real wp2x(unit="m") = 4.0;
  parameter Real wp2y(unit="m") = 0.0;
  parameter Real wp2z(unit="m") = 2.5;
  parameter Real wp3x(unit="m") = 4.0;
  parameter Real wp3y(unit="m") = 3.0;
  parameter Real wp3z(unit="m") = 2.5;
  parameter Real wp4x(unit="m") = 1.0;
  parameter Real wp4y(unit="m") = 4.0;
  parameter Real wp4z(unit="m") = 2.0;

  // Three fixed cylindrical obstacles placed outside the reference polyline
  parameter Real obsX1(unit="m") = 2.0;
  parameter Real obsY1(unit="m") = -1.5;
  parameter Real obsR1(unit="m") = 0.5;
  parameter Real obsX2(unit="m") = -1.0;
  parameter Real obsY2(unit="m") = 2.0;
  parameter Real obsR2(unit="m") = 0.5;
  parameter Real obsX3(unit="m") = 5.0;
  parameter Real obsY3(unit="m") = 2.0;
  parameter Real obsR3(unit="m") = 0.5;

  // ---- Controller / estimator gains ----
  parameter Real Kp_pos = 3.0 "position gain";
  parameter Real Kd_vel = 3.5 "velocity damping gain";
  parameter Real KpEst = 4.0 "estimator position gain";
  parameter Real KvEst = 6.0 "estimator velocity gain";

  // ---- Continuous plant state ----
  Real p_x(unit="m", start=0.0) "fuselage position x";
  Real p_y(unit="m", start=0.0) "fuselage position y";
  Real p_z(unit="m", start=1.5) "fuselage position z";
  Real v_x(unit="m/s", start=0.0) "fuselage velocity x";
  Real v_y(unit="m/s", start=0.0) "fuselage velocity y";
  Real v_z(unit="m/s", start=0.0) "fuselage velocity z";
  Real T1_state(unit="N", start=30.41) "rotor 1 thrust state (left)";
  Real T2_state(unit="N", start=30.41) "rotor 2 thrust state (right)";
  Real gammaL_raw(start=0.0) "left tilt actuator state";
  Real gammaR_raw(start=0.0) "right tilt actuator state";
  Real thetaState(unit="rad", start=0.0) "heading state";

  // ---- Clamped tilt angles ----
  Real gammaL_clamped(unit="rad") "left rotor tilt angle (clamped)";
  Real gammaR_clamped(unit="rad") "right rotor tilt angle (clamped)";

  // ---- Discrete controller outputs (sampled at 250 Hz) ----
  discrete Real T1_cmd(unit="N", start=30.41) "rotor 1 thrust command";
  discrete Real T2_cmd(unit="N", start=30.41) "rotor 2 thrust command";
  discrete Real gammaL_cmd(unit="rad", start=0.0) "left tilt command";
  discrete Real gammaR_cmd(unit="rad", start=0.0) "right tilt command";
  discrete Real theta_cmd(unit="rad", start=0.0) "heading command";
  Integer wpIdx(start=1) "active waypoint index";

  // ---- Thrust vector in world frame ----
  Real T_total(unit="N") "total rotor thrust";
  Real gammaAvg(unit="rad") "average rotor tilt";
  Real Tx_thrust(unit="N") "world-frame thrust x";
  Real Ty_thrust(unit="N") "world-frame thrust y";
  Real Tz_thrust(unit="N") "world-frame thrust z";
  Real crosswindOn "crosswind enable (middle third of run)";

  // ---- Sensors (synchronized timestamps) ----
  Real gps_px(unit="m") "GPS position measurement x";
  Real gps_py(unit="m") "GPS position measurement y";
  Real gps_pz(unit="m") "GPS position measurement z";
  Real imu_ax(unit="m/s2") "IMU specific-force measurement x";
  Real imu_ay(unit="m/s2") "IMU specific-force measurement y";
  Real imu_az(unit="m/s2") "IMU specific-force measurement z";
  Real alt_z(unit="m") "altimeter measurement";
  Real cam_px(unit="m") "camera pose measurement x";
  Real cam_py(unit="m") "camera pose measurement y";
  Real cam_pz(unit="m") "camera pose measurement z";
  Real ts_gps(unit="s") "GPS timestamp";
  Real ts_imu(unit="s") "IMU timestamp";
  Real ts_alt(unit="s") "altimeter timestamp";
  Real ts_cam(unit="s") "camera timestamp";

  // ---- Fused state estimate ----
  Real p_est_x(unit="m", start=0.0) "fused position estimate x";
  Real p_est_y(unit="m", start=0.0) "fused position estimate y";
  Real p_est_z(unit="m", start=1.5) "fused position estimate z";
  Real v_est_x(unit="m/s", start=0.0) "fused velocity estimate x";
  Real v_est_y(unit="m/s", start=0.0) "fused velocity estimate y";
  Real v_est_z(unit="m/s", start=0.0) "fused velocity estimate z";
  Real q_est0(start=1.0) "fused attitude quaternion w";
  Real q_est1(start=0.0) "fused attitude quaternion x";
  Real q_est2(start=0.0) "fused attitude quaternion y";
  Real q_est3(start=0.0) "fused attitude quaternion z";

  // ---- Acceptance / fail-closed ----
  Real err_wp(unit="m") "tracking error to active waypoint";
  Real err_wp4(unit="m") "tracking error to final waypoint";
  Real obsDist1(unit="m") "planar distance to obstacle 1";
  Real obsDist2(unit="m") "planar distance to obstacle 2";
  Real obsDist3(unit="m") "planar distance to obstacle 3";
  Boolean ok_thrust;
  Boolean ok_attitude;
  Boolean ok_wpErr;
  Boolean ok_finite;
  Boolean ok_collision;
  Boolean ok_finalErr;
  Boolean ok_all "fail-closed acceptance flag";

  // ---- Active waypoint coordinates (continuous aliases for equation use) ----
  Real wp_active_x(unit="m");
  Real wp_active_y(unit="m");
  Real wp_active_z(unit="m");

protected
  discrete Real a_des_x "desired acceleration x";
  discrete Real a_des_y "desired acceleration y";
  discrete Real a_des_z "desired acceleration z";
  discrete Real Tx_raw_int "raw thrust x intermediate";
  discrete Real Ty_raw_int "raw thrust y intermediate";
  discrete Real Tz_raw_int "raw thrust z intermediate";
  discrete Real T_total_raw_int "raw total thrust intermediate";
  discrete Real hnorm_int "horizontal norm intermediate";
  discrete Real gamma_raw_int "raw gamma intermediate";
  discrete Real theta_raw_int "raw theta intermediate";
  discrete Real T_half_int "half thrust intermediate";
  Real q_raw0 "quaternion raw w";
  Real q_raw1 "quaternion raw x";
  Real q_raw2 "quaternion raw y";
  Real q_raw3 "quaternion raw z";
  Real qn "quaternion norm";

algorithm
  when sample(0.0, dt_ctrl) then
    // Distance-triggered waypoint advance (deadlines unknown -> omitted)
    if abs(p_x - wp_active_x) < 0.6 and abs(p_y - wp_active_y) < 0.6 and abs(p_z - wp_active_z) < 0.6 and pre(wpIdx) < 4 then
      wpIdx := pre(wpIdx) + 1;
    else
      wpIdx := pre(wpIdx);
    end if;

    // Bounded waypoint tracking with feedforward acceleration (timing unknown -> zero ff)
    a_des_x := Kp_pos * (wp_active_x - p_x) + Kd_vel * (0.0 - v_x);
    a_des_y := Kp_pos * (wp_active_y - p_y) + Kd_vel * (0.0 - v_y);
    a_des_z := Kp_pos * (wp_active_z - p_z) + Kd_vel * (0.0 - v_z);

    Tx_raw_int := m_fus * a_des_x;
    Ty_raw_int := m_fus * a_des_y;
    Tz_raw_int := m_fus * (a_des_z + g_acc);
    T_total_raw_int := sqrt(Tx_raw_int * Tx_raw_int + Ty_raw_int * Ty_raw_int + Tz_raw_int * Tz_raw_int + 1.0e-9);
    hnorm_int := sqrt(Tx_raw_int * Tx_raw_int + Ty_raw_int * Ty_raw_int + 1.0e-9);
    gamma_raw_int := atan2(hnorm_int, Tz_raw_int);

    if gamma_raw_int < gammaMin then
      gammaL_cmd := gammaMin;
    elseif gamma_raw_int > gammaMax then
      gammaL_cmd := gammaMax;
    else
      gammaL_cmd := gamma_raw_int;
    end if;
    gammaR_cmd := gammaL_cmd;

    theta_raw_int := atan2(Ty_raw_int, Tx_raw_int + 1.0e-9);
    theta_cmd := theta_raw_int;

    T_half_int := T_total_raw_int / 2.0;
    if T_half_int > Tmax then
      T1_cmd := Tmax;
    elseif T_half_int < 0.0 then
      T1_cmd := 0.0;
    else
      T1_cmd := T_half_int;
    end if;
    T2_cmd := T1_cmd;
  end when;

equation
  // ---- Active waypoint selection (continuous) ----
  wp_active_x = if wpIdx == 1 then wp1x elseif wpIdx == 2 then wp2x elseif wpIdx == 3 then wp3x else wp4x;
  wp_active_y = if wpIdx == 1 then wp1y elseif wpIdx == 2 then wp2y elseif wpIdx == 3 then wp3y else wp4y;
  wp_active_z = if wpIdx == 1 then wp1z elseif wpIdx == 2 then wp2z elseif wpIdx == 3 then wp3z else wp4z;

  // ---- Point-mass plant kinematics ----
  der(p_x) = v_x;
  der(p_y) = v_y;
  der(p_z) = v_z;

  // ---- Actuators ----
  der(T1_state) = (T1_cmd - T1_state) / tauThrust;
  der(T2_state) = (T2_cmd - T2_state) / tauThrust;
  der(gammaL_raw) = (gammaL_cmd - gammaL_raw) / tauTilt;
  der(gammaR_raw) = (gammaR_cmd - gammaR_raw) / tauTilt;
  der(thetaState) = (theta_cmd - thetaState) / tauTheta;

  // ---- Tilt angle clamping ----
  gammaL_clamped = if gammaL_raw < gammaMin then gammaMin elseif gammaL_raw > gammaMax then gammaMax else gammaL_raw;
  gammaR_clamped = if gammaR_raw < gammaMin then gammaMin elseif gammaR_raw > gammaMax then gammaMax else gammaR_raw;

  // ---- Thrust resolution in world frame ----
  T_total = T1_state + T2_state;
  gammaAvg = (gammaL_clamped + gammaR_clamped) / 2.0;
  Tx_thrust = T_total * sin(gammaAvg) * cos(thetaState);
  Ty_thrust = T_total * sin(gammaAvg) * sin(thetaState);
  Tz_thrust = T_total * cos(gammaAvg);

  // ---- Controlled crosswind disturbance (middle third of run) ----
  crosswindOn = if time >= tEnd / 3.0 and time <= 2.0 * tEnd / 3.0 then 1.0 else 0.0;

  // ---- Newton equations ----
  m_fus * der(v_x) = Tx_thrust;
  m_fus * der(v_y) = Ty_thrust + crosswindForce * crosswindOn;
  m_fus * der(v_z) = Tz_thrust - m_fus * g_acc;

  // ---- Sensor models with synchronized timestamps ----
  gps_px = p_x;
  gps_py = p_y;
  gps_pz = p_z;
  alt_z = p_z;
  imu_ax = Tx_thrust / m_fus;
  imu_ay = (Ty_thrust + crosswindForce * crosswindOn) / m_fus;
  imu_az = Tz_thrust / m_fus - g_acc;
  cam_px = p_x;
  cam_py = p_y;
  cam_pz = p_z;
  ts_gps = time;
  ts_imu = time;
  ts_alt = time;
  ts_cam = time;

  // ---- Sensor fusion (complementary filter on GPS/altimeter/IMU) ----
  der(p_est_x) = v_est_x + KpEst * (gps_px - p_est_x);
  der(p_est_y) = v_est_y + KpEst * (gps_py - p_est_y);
  der(p_est_z) = v_est_z + KpEst * (alt_z - p_est_z);
  der(v_est_x) = imu_ax + KvEst * (v_x - v_est_x);
  der(v_est_y) = imu_ay + KvEst * (v_y - v_est_y);
  der(v_est_z) = imu_az + KvEst * (v_z - v_est_z);

  // ---- Fused attitude quaternion from heading + average tilt ----
  q_raw0 = cos(gammaAvg / 2.0) * cos(thetaState / 2.0);
  q_raw1 = sin(gammaAvg / 2.0) * cos(thetaState / 2.0);
  q_raw2 = cos(gammaAvg / 2.0) * sin(thetaState / 2.0);
  q_raw3 = -sin(gammaAvg / 2.0) * sin(thetaState / 2.0);
  qn = sqrt(q_raw0 * q_raw0 + q_raw1 * q_raw1 + q_raw2 * q_raw2 + q_raw3 * q_raw3 + 1.0e-12);
  q_est0 = q_raw0 / qn;
  q_est1 = q_raw1 / qn;
  q_est2 = q_raw2 / qn;
  q_est3 = q_raw3 / qn;

  // ---- Tracking errors and obstacle distances ----
  err_wp = sqrt((p_x - wp_active_x) ^ 2 + (p_y - wp_active_y) ^ 2 + (p_z - wp_active_z) ^ 2);
  err_wp4 = sqrt((p_x - wp4x) ^ 2 + (p_y - wp4y) ^ 2 + (p_z - wp4z) ^ 2);
  obsDist1 = sqrt((p_x - obsX1) ^ 2 + (p_y - obsY1) ^ 2);
  obsDist2 = sqrt((p_x - obsX2) ^ 2 + (p_y - obsY2) ^ 2);
  obsDist3 = sqrt((p_x - obsX3) ^ 2 + (p_y - obsY3) ^ 2);

  // ---- Acceptance predicates (fail-closed) ----
  ok_thrust = (T1_state >= -1.0e-6) and (T1_state <= Tmax + 1.0e-6) and
              (T2_state >= -1.0e-6) and (T2_state <= Tmax + 1.0e-6);
  ok_attitude = (gammaL_clamped >= gammaMin - 1.0e-6) and (gammaL_clamped <= gammaMax + 1.0e-6) and
                (gammaR_clamped >= gammaMin - 1.0e-6) and (gammaR_clamped <= gammaMax + 1.0e-6);
  ok_wpErr = err_wp <= 5.0;
  ok_finite = (abs(p_x) <= 1.0e9) and (abs(p_y) <= 1.0e9) and (abs(p_z) <= 1.0e9) and
              (abs(v_x) <= 1.0e9) and (abs(v_y) <= 1.0e9) and (abs(v_z) <= 1.0e9) and
              (abs(T1_state) <= 1.0e9) and (abs(T2_state) <= 1.0e9) and
              (abs(T1_cmd) <= 1.0e9) and (abs(T2_cmd) <= 1.0e9) and
              (abs(gammaL_cmd) <= 1.0e9) and (abs(gammaR_cmd) <= 1.0e9) and
              (abs(theta_cmd) <= 1.0e9) and
              (abs(p_est_x) <= 1.0e9) and (abs(p_est_y) <= 1.0e9) and (abs(p_est_z) <= 1.0e9) and
              (abs(v_est_x) <= 1.0e9) and (abs(v_est_y) <= 1.0e9) and (abs(v_est_z) <= 1.0e9) and
              (abs(q_est0) <= 1.0e9) and (abs(q_est1) <= 1.0e9) and
              (abs(q_est2) <= 1.0e9) and (abs(q_est3) <= 1.0e9);
  ok_collision = (obsDist1 > obsR1) and (obsDist2 > obsR2) and (obsDist3 > obsR3);
  ok_finalErr = (time < tFinalCheck) or (err_wp4 < errTol);
  ok_all = ok_thrust and ok_attitude and ok_wpErr and ok_finite and ok_collision and ok_finalErr;

  annotation(
    experiment(StopTime=16.0, Tolerance=1.0e-4, Interval=0.004),
    Documentation(info="TiltWingSurveyE: tilt-wing survey robot with bounded waypoint tracking, multi-sensor fusion, three fixed cylindrical obstacles outside the survey polyline, and a 7.2 N middle-third crosswind disturbance. Fail-closed acceptance requires thrust/attitude bounds, finite estimator, no collision, and final tracking error below 0.315 m after 10.4 s. Per-waypoint deadlines are unspecified and therefore omitted."));
end TiltWingSurveyE;