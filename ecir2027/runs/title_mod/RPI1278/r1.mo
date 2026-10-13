model ContactStateLocalizeF
  import Modelica.Constants.pi;

  // Requirement constants
  parameter Real m = 24.0 "kg torso mass";
  parameter Real tauMax = 67.1 "N.m per joint";
  parameter Real Ts = 1.0/500.0 "s base rate";
  parameter Real StopTime = 20.0 "s";
  parameter Real tStepStart = StopTime/3.0 "s middle third start";
  parameter Real tStepEnd = 2.0*StopTime/3.0 "s middle third end";
  parameter Real biasStep = 0.058 "m/s^2 controlled sensor-bias step";
  parameter Real tPrimary = 13.0 "s verification time";
  parameter Real primaryLimit = 0.16 "m or rad primary error limit";

  // Frames
  constant Integer worldFrame = 1 "world frame";
  constant Integer bodyFrame = 2 "body frame";
  constant Integer footFrame = 3 "foot frame";
  constant Integer jointFrame = 4 "joint frame";

  // Sensor rates and frames (not specified; finite placeholders for codegen)
  parameter Real fImu = 500.0 "Hz";
  parameter Real fEnc = 500.0 "Hz";
  parameter Real fContact = 250.0 "Hz";
  parameter Real fForce = 500.0 "Hz";
  parameter Real fLand = 100.0 "Hz";
  parameter Real fAtt = 100.0 "Hz";
  parameter Real Timu = 1.0/fImu;
  parameter Real Tenc = 1.0/fEnc;
  parameter Real Tcontact = 1.0/fContact;
  parameter Real Tforce = 1.0/fForce;
  parameter Real Tland = 1.0/fLand;
  parameter Real Tatt = 1.0/fAtt;
  parameter Integer frameImu = bodyFrame;
  parameter Integer frameEnc = jointFrame;
  parameter Integer frameContact = footFrame;
  parameter Integer frameForce = footFrame;
  parameter Integer frameLand = worldFrame;
  parameter Integer frameAtt = worldFrame;

  // Sensor standard deviations (not specified; finite placeholders for codegen)
  parameter Real sigma_imu_acc = 0.001 "m/s^2";
  parameter Real sigma_imu_gyro = 0.0001 "rad/s";
  parameter Real sigma_enc = 1e-5 "rad";
  parameter Real sigma_contact = 0.001 "m/s";
  parameter Real sigma_force = 0.1 "N";
  parameter Real sigma_land = 0.001 "m";
  parameter Real sigma_att = 0.001 "rad";
  parameter Real sigma_accel_bias = 0.001 "m/s^2 bias update sigma";
  parameter Real sigma_gyro_bias = 0.1 "rad/s bias update sigma";
  parameter Real sigma_land_bias = 0.1 "m range bias update sigma";

  // Physical placeholders not stated in request
  parameter Real g = 9.81 "m/s^2";
  parameter Real g_world[3] = {0.0,0.0,-g};
  parameter Real Iatt[3] = {0.5,0.5,0.5} "kg m^2 placeholder";
  parameter Real Tgait = 1.0 "s gait period placeholder";
  parameter Real Tq = 0.05 "s joint tracking time constant placeholder";
  parameter Real phase[12] = {0.0,0.5,1.0,1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5};

  // Fixed external landmarks (placeholder positions, not ground truth)
  parameter Real Lm[4,3] = {{1.5,1.5,0.0},{-1.5,1.5,0.0},{-1.5,-1.5,0.0},{1.5,-1.5,0.0}};

  // Actuator mapping placeholders
  parameter Real kF = 20.0 "N per Nm";
  parameter Real kT = 2.0 "Nm per Nm";
  parameter Real W[6,12] = {
    {0,0,kF/2,0,0,0,0,0,-kF/2,0,0,0},
    {0,0,0,0,0,kF/2,0,0,0,0,0,-kF/2},
    {kF/8,kF/8,0,kF/8,kF/8,0,kF/8,kF/8,0,kF/8,kF/8,0},
    {kT/2,0,0,-kT/2,0,0,kT/2,0,0,-kT/2,0,0},
    {0,kT/2,0,0,-kT/2,0,0,kT/2,0,0,-kT/2,0},
    {0,0,kT/2,0,0,0,0,0,kT/2,0,0,0}
  };
  parameter Real Wpinv[12,6] = {
    {0,0,0.05,0.25,0,0},
    {0,0,0.05,0,0.25,0},
    {0.05,0,0,0,0,0.5},
    {0,0,0.05,-0.25,0,0},
    {0,0,0.05,0,-0.25,0},
    {0,0.05,0,0,0,0},
    {0,0,0.05,0.25,0,0},
    {0,0,0.05,0,0.25,0},
    {-0.05,0,0,0,0,0.5},
    {0,0,0.05,-0.25,0,0},
    {0,0,0.05,0,-0.25,0},
    {0,-0.05,0,0,0,0}
  };

  // Controller gains placeholders
  parameter Real KpPos = 100.0;
  parameter Real KdPos = 40.0;
  parameter Real KpAtt = 100.0;
  parameter Real KdAtt = 15.0;

  // Covariance bounds and process noise placeholders
  parameter Real Pmin = 1e-6;
  parameter Real Qp = 1e-5;
  parameter Real Qv = 1e-5;
  parameter Real Qatt = 1e-5;
  parameter Real Qba = 1e-5;
  parameter Real Qbg = 1e-9;
  parameter Real Qbf = 1e-8;
  parameter Real Qbl = 1e-9;
  parameter Real Pbc_const[3] = fill(1e-4,3);
  parameter Real Pbatt_const[3] = fill(1e-4,3);
  parameter Real Pbe_const[12] = fill(1e-4,12);

  // Verification bands
  parameter Real positionErrorBand = 0.25 "m";
  parameter Real attitudeErrorBand = 0.10 "rad";

  // True states
  Real p_true[3];
  Real v_true[3];
  Real rpy_true[3];
  Real omega_true[3];
  Real qJoint[12];

  // Estimator states
  Real p_est[3];
  Real v_est[3];
  Real rpy_est[3];
  Real b_a_est[3];
  Real b_g_est[3];
  Real b_f_est[4];
  Real b_land_est[4];
  Real b_contact_est[3];
  Real b_att_est[3];
  Real b_enc_est[12];

  // Dynamic covariances
  Real Pp[3];
  Real Pv[3];
  Real Patt[3];
  Real Pba[3];
  Real Pbg[3];
  Real Pbf[4];
  Real Pbl[4];

  // True sensor biases
  Real b_a_true[3];
  Real b_g_true[3];
  Real b_force_true[4];
  Real b_land_true[4];
  Real b_contact_true[3];
  Real b_att_true[3];
  Real b_enc_true[12];
  Real biasStepCommand;

  // Reference route
  Real pRef[3];
  Real vRef[3];
  Real aRef[3];
  Real rpyRef[3];
  Real omegaRef[3];
  Real angAccRef[3];

  // Commands and actuator variables
  Real Fdes[3];
  Real Tdes[3];
  Real wrenchDes[6];
  Real tauDes[12];
  Real tau[12];
  Real wrenchActual[6];
  Real F_actual[3];
  Real T_actual[3];
  Real qJointDes[12];

  // Kinematics and IMU variables
  Real R_true[3,3];
  Real R_est[3,3];
  Real f_body[3];
  Real a_est[3];

  // Sensor measurements
  Real imuAccelMeas[3];
  Real imuGyroMeas[3];
  Real qEncMeas[12];
  Real rangeMeas[4];
  Real attMeas[3];
  Real contactVelMeas[3];
  Real forceMeas[4];
  Boolean contactBool[4];
  Boolean contactMeas[4];
  Boolean contactValid;
  Real fNorm_true[4];
  Real nActive;

  // Dither placeholders tied to sigma
  Real ditherAcc[3];
  Real ditherGyro[3];
  Real ditherEnc[12];
  Real ditherContact[3];
  Real ditherForce[4];
  Real ditherLand[4];
  Real ditherAtt[3];

  // Timestamps
  discrete Real tImu(start=0.0);
  discrete Real tEnc(start=0.0);
  discrete Real tContact(start=0.0);
  discrete Real tForce(start=0.0);
  discrete Real tLand(start=0.0);
  discrete Real tAtt(start=0.0);

  // Temporary discrete update variables
  discrete Real p_new[3];
  discrete Real Pp_new[3];
  discrete Real bl_new[4];
  discrete Real Pbl_new[4];
  discrete Real v_new[3];
  discrete Real Pv_new[3];
  discrete Real ba_new[3];
  discrete Real Pba_new[3];
  discrete Real att_new[3];
  discrete Real Patt_new[3];
  discrete Real bg_new[3];
  discrete Real Pbg_new[3];
  discrete Real bf_new[4];
  discrete Real Pbf_new[4];
  discrete Real fPred[4];

  // Verification variables
  Real positionError;
  Real attitudeError;
  Real primaryError;
  Real biasConvergenceError;
  Boolean actuatorLimitSatisfied;
  Boolean covFinitePositive;
  Boolean finiteCheck;

  initial equation
    p_true = {0.0,0.4,0.45};
    v_true = {0.6*2.0*pi/10.0,0.0,0.0};
    rpy_true = zeros(3);
    omega_true = zeros(3);
    qJoint = zeros(12);

    p_est = {0.05,0.35,0.48};
    v_est = {0.6*2.0*pi/10.0,0.0,0.0};
    rpy_est = {0.02,-0.02,0.03};
    b_a_est = zeros(3);
    b_g_est = zeros(3);
    b_f_est = zeros(4);
    b_land_est = zeros(4);
    b_contact_est = zeros(3);
    b_att_est = zeros(3);
    b_enc_est = zeros(12);

    Pp = {0.01,0.01,0.01};
    Pv = {0.01,0.01,0.01};
    Patt = {0.01,0.01,0.01};
    Pba = {0.01,0.01,0.01};
    Pbg = {1e-6,1e-6,1e-6};
    Pbf = fill(1e-4,4);
    Pbl = fill(1e-6,4);

  equation
    // Bounded reference route
    pRef[1] = 0.6*sin(2.0*pi*time/10.0);
    pRef[2] = 0.4*cos(2.0*pi*time/8.0);
    pRef[3] = 0.45 + 0.03*sin(2.0*pi*time/5.0);
    vRef[1] = 0.6*(2.0*pi/10.0)*cos(2.0*pi*time/10.0);
    vRef[2] = -0.4*(2.0*pi/8.0)*sin(2.0*pi*time/8.0);
    vRef[3] = 0.03*(2.0*pi/5.0)*cos(2.0*pi*time/5.0);
    aRef[1] = -0.6*(2.0*pi/10.0)^2*sin(2.0*pi*time/10.0);
    aRef[2] = -0.4*(2.0*pi/8.0)^2*cos(2.0*pi*time/8.0);
    aRef[3] = -0.03*(2.0*pi/5.0)^2*sin(2.0*pi*time/5.0);

    rpyRef[1] = 0.05*sin(2.0*pi*time/9.0);
    rpyRef[2] = 0.04*cos(2.0*pi*time/7.0);
    rpyRef[3] = 0.10*sin(2.0*pi*time/12.0);
    omegaRef[1] = 0.05*(2.0*pi/9.0)*cos(2.0*pi*time/9.0);
    omegaRef[2] = -0.04*(2.0*pi/7.0)*sin(2.0*pi*time/7.0);
    omegaRef[3] = 0.10*(2.0*pi/12.0)*cos(2.0*pi*time/12.0);
    angAccRef[1] = -0.05*(2.0*pi/9.0)^2*sin(2.0*pi*time/9.0);
    angAccRef[2] = -0.04*(2.0*pi/7.0)^2*cos(2.0*pi*time/7.0);
    angAccRef[3] = -0.10*(2.0*pi/12.0)^2*sin(2.0*pi*time/12.0);

    // Plant dynamics
    for k in 1:3 loop
      der(p_true[k]) = v_true[k];
      der(v_true[k]) = (F_actual[k] + m*g_world[k])/m;
      der(rpy_true[k]) = omega_true[k];
      der(omega_true[k]) = T_actual[k]/Iatt[k];
    end for;

    // Controller and actuator mapping
    for k in 1:3 loop
      Fdes[k] = m*(aRef[k] + KpPos*(pRef[k] - p_true[k]) + KdPos*(vRef[k] - v_true[k])) - m*g_world[k];
      Tdes[k] = Iatt[k]*(angAccRef[k] + KpAtt*(rpyRef[k] - rpy_true[k]) + KdAtt*(omegaRef[k] - omega_true[k]));
    end for;
    wrenchDes = {Fdes[1],Fdes[2],Fdes[3],Tdes[1],Tdes[2],Tdes[3]};
    tauDes = Wpinv*wrenchDes;
    for j in 1:12 loop
      tau[j] = max(-tauMax, min(tauMax, tauDes[j]));
    end for;
    wrenchActual = W*tau;
    F_actual[1] = wrenchActual[1];
    F_actual[2] = wrenchActual[2];
    F_actual[3] = wrenchActual[3];
    T_actual[1] = wrenchActual[4];
    T_actual[2] = wrenchActual[5];
    T_actual[3] = wrenchActual[6];

    // Joint encoder states and measurements
    for j in 1:12 loop
      qJointDes[j] = 0.10*sin(2.0*pi*time/Tgait + phase[j]);
      der(qJoint[j]) = (qJointDes[j] - qJoint[j])/Tq;
      qEncMeas[j] = qJoint[j] + b_enc_true[j] + ditherEnc[j];
    end for;

    // Contact schedule and foot force sensors
    contactBool[1] = mod(time,Tgait) < Tgait/2.0;
    contactBool[2] = not contactBool[1];
    contactBool[3] = contactBool[1];
    contactBool[4] = not contactBool[1];
    for i in 1:4 loop
      contactMeas[i] = contactBool[i];
    end for;
    nActive = (if contactBool[1] then 1.0 else 0.0) +
              (if contactBool[2] then 1.0 else 0.0) +
              (if contactBool[3] then 1.0 else 0.0) +
              (if contactBool[4] then 1.0 else 0.0);
    for i in 1:4 loop
      fNorm_true[i] = if contactBool[i] then max(0.0, F_actual[3]/max(nActive,1.0)) else 0.0;
      forceMeas[i] = fNorm_true[i] + b_force_true[i] + ditherForce[i];
    end for;
    for k in 1:3 loop
      contactVelMeas[k] = v_true[k] + b_contact_true[k] + ditherContact[k];
    end for;
    contactValid = contactBool[1] or contactBool[2] or contactBool[3] or contactBool[4];

    // Controlled bias step disturbance
    biasStepCommand = if time >= tStepStart and time <= tStepEnd then biasStep else 0.0;
    b_a_true[1] = biasStepCommand;
    b_a_true[2] = 0.0;
    b_a_true[3] = 0.0;
    for k in 1:3 loop
      b_g_true[k] = 0.0;
      b_contact_true[k] = 0.0;
      b_att_true[k] = 0.0;
    end for;
    for i in 1:4 loop
      b_force_true[i] = 0.0;
      b_land_true[i] = 0.0;
    end for;
    for j in 1:12 loop
      b_enc_true[j] = 0.0;
    end for;

    // Deterministic dither placeholders
    for k in 1:3 loop
      ditherAcc[k] = sigma_imu_acc*0.5*sin(2.0*pi*13.0*time + k);
      ditherGyro[k] = sigma_imu_gyro*0.5*sin(2.0*pi*17.0*time + k);
      ditherAtt[k] = sigma_att*0.5*sin(2.0*pi*23.0*time + k);
      ditherContact[k] = sigma_contact*0.5*sin(2.0*pi*19.0*time + k);
    end for;
    for i in 1:4 loop
      ditherForce[i] = sigma_force*0.5*sin(2.0*pi*29.0*time + i);
      ditherLand[i] = sigma_land*0.5*sin(2.0*pi*11.0*time + i);
    end for;
    for j in 1:12 loop
      ditherEnc[j] = sigma_enc*0.5*sin(2.0*pi*31.0*time + j);
    end for;

    // IMU, landmark, and attitude observations
    R_true = rotMat(rpy_true);
    f_body = transpose(R_true)*(F_actual/m);
    imuAccelMeas = f_body + b_a_true + ditherAcc;
    imuGyroMeas = omega_true + b_g_true + ditherGyro;
    for i in 1:4 loop
      rangeMeas[i] = safeDist3({p_true[1] - Lm[i,1], p_true[2] - Lm[i,2], p_true[3] - Lm[i,3]}) + b_land_true[i] + ditherLand[i];
    end for;
    for k in 1:3 loop
      attMeas[k] = rpy_true[k] + b_att_true[k] + ditherAtt[k];
    end for;

    // EKF prediction (continuous, IMU driven)
    R_est = rotMat(rpy_est);
    a_est = R_est*(imuAccelMeas - b_a_est) + g_world;
    for k in 1:3 loop
      der(p_est[k]) = v_est[k];
      der(v_est[k]) = a_est[k];
      der(rpy_est[k]) = imuGyroMeas[k] - b_g_est[k];
      der(b_a_est[k]) = 0.0;
      der(b_g_est[k]) = 0.0;
      der(b_contact_est[k]) = 0.0;
      der(b_att_est[k]) = 0.0;
      der(Pp[k]) = Qp;
      der(Pv[k]) = Qv;
      der(Patt[k]) = Qatt;
      der(Pba[k]) = Qba;
      der(Pbg[k]) = Qbg;
    end for;
    for i in 1:4 loop
      der(b_f_est[i]) = 0.0;
      der(b_land_est[i]) = 0.0;
      der(Pbf[i]) = Qbf;
      der(Pbl[i]) = Qbl;
    end for;
    for j in 1:12 loop
      der(b_enc_est[j]) = 0.0;
    end for;

    // Asynchronous EKF correction updates
    when sample(0.0, Timu) then
      tImu := time;
    end when;

    when sample(0.0, Tenc) then
      tEnc := time;
    end when;

    when sample(0.0, Tcontact) then
      tContact := time;
      if contactValid then
        (v_new, Pv_new, ba_new, Pba_new) := contactUpdate(v_est, Pv, b_a_est, Pba, contactVelMeas, sigma_contact, sigma_accel_bias, Pmin);
        for k in 1:3 loop
          reinit(v_est[k], v_new[k]);
          reinit(Pv[k], Pv_new[k]);
          reinit(b_a_est[k], ba_new[k]);
          reinit(Pba[k], Pba_new[k]);
        end for;
      end if;
    end when;

    when sample(0.0, Tforce) then
      tForce := time;
      for i in 1:4 loop
        fPred[i] := if contactBool[i] then m*g/max(nActive,1.0) else 0.0;
      end for;
      (bf_new, Pbf_new) := forceUpdate(b_f_est, Pbf, forceMeas, fPred, sigma_force, Pmin);
      for i in 1:4 loop
        reinit(b_f_est[i], bf_new[i]);
        reinit(Pbf[i], Pbf_new[i]);
      end for;
    end when;

    when sample(0.0, Tland) then
      tLand := time;
      (p_new, Pp_new, bl_new, Pbl_new) := landmarkUpdate(p_est, Pp, b_land_est, Pbl, rangeMeas, Lm, sigma_land, sigma_land_bias, Pmin);
      for k in 1:3 loop
        reinit(p_est[k], p_new[k]);
        reinit(Pp[k], Pp_new[k]);
      end for;
      for i in 1:4 loop
        reinit(b_land_est[i], bl_new[i]);
        reinit(Pbl[i], Pbl_new[i]);
      end for;
    end when;

    when sample(0.0, Tatt) then
      tAtt := time;
      (att_new, Patt_new, bg_new, Pbg_new) := attUpdate(rpy_est, Patt, b_g_est, Pbg, attMeas, sigma_att, sigma_gyro_bias, Pmin);
      for k in 1:3 loop
        reinit(rpy_est[k], att_new[k]);
        reinit(Patt[k], Patt_new[k]);
        reinit(b_g_est[k], bg_new[k]);
        reinit(Pbg[k], Pbg_new[k]);
      end for;
    end when;

    // Verification metrics
    positionError = safeDist3({p_est[1] - p_true[1], p_est[2] - p_true[2], p_est[3] - p_true[3]});
    attitudeError = safeDist3({rpy_est[1] - rpy_true[1], rpy_est[2] - rpy_true[2], rpy_est[3] - rpy_true[3]});
    primaryError = positionError + abs(rpy_est[3] - rpy_true[3]);
    biasConvergenceError = abs(b_a_est[1] - b_a_true[1]);

    actuatorLimitSatisfied = max(abs(tau)) <= tauMax;
    covFinitePositive = min(Pp) > Pmin and min(Pv) > Pmin and min(Patt) > Pmin and min(Pba) > Pmin and min(Pbg) > Pmin and min(Pbf) > Pmin and min(Pbl) > Pmin and min(Pbc_const) > Pmin and min(Pbatt_const) > Pmin and min(Pbe_const) > Pmin;
    finiteCheck = max(abs(p_true)) < 1e9 and max(abs(p_est)) < 1e9 and max(abs(v_true)) < 1e9 and max(abs(v_est)) < 1e9 and max(abs(tau)) < 1e9 and max(abs(Pp)) < 1e9 and max(abs(Pba)) < 1e9;

    assert(actuatorLimitSatisfied, "Actuator limit exceeded");
    assert(covFinitePositive, "Covariance not finite positive");
    assert(finiteCheck, "Physical, control, or estimator value not finite");
    assert(time <= 1.0 or positionError < positionErrorBand, "Position error band violated");
    assert(time <= 1.0 or attitudeError < attitudeErrorBand, "Attitude error band violated");
    assert(time <= tPrimary or primaryError < primaryLimit, "Primary tracking error limit violated after 13 s");
    assert(time <= 15.0 or biasConvergenceError < 0.02, "Accelerometer bias convergence violated");

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Interval=0.002),
    Documentation(info="Synchronous 500 Hz, 20 s contact-aided localization scenario with asynchronous EKF updates. Non-requirement numeric values are finite placeholders.")
  );

  function rotMat
    input Real rpy[3];
    output Real R[3,3];
  algorithm
    R[1,1] := cos(rpy[3])*cos(rpy[2]);
    R[1,2] := cos(rpy[3])*sin(rpy[2])*sin(rpy[1]) - sin(rpy[3])*cos(rpy[1]);
    R[1,3] := cos(rpy[3])*sin(rpy[2])*cos(rpy[1]) + sin(rpy[3])*sin(rpy[1]);
    R[2,1] := sin(rpy[3])*cos(rpy[2]);
    R[2,2] := sin(rpy[3])*sin(rpy[2])*sin(rpy[1]) + cos(rpy[3])*cos(rpy[1]);
    R[2,3] := sin(rpy[3])*sin(rpy[2])*cos(rpy[1]) - cos(rpy[3])*sin(rpy[1]);
    R[3,1] := -sin(rpy[2]);
    R[3,2] := cos(rpy[2])*sin(rpy[1]);
    R[3,3] := cos(rpy[2])*cos(rpy[1]);
  end rotMat;

  function safeDist3
    input Real v[3];
    output Real d;
  algorithm
    d := sqrt(max(v[1]*v[1] + v[2]*v[2] + v[3]*v[3], 1e-9));
  end safeDist3;

  function landmarkUpdate
    input Real p[3];
    input Real Pp[3];
    input Real b_land[4];
    input Real Pbl[4];
    input Real ranges[4];
    input Real Lm[4,3];
    input Real sigmaRange;
    input Real sigmaRangeBias;
    input Real Pmin;
    output Real p_new[3];
    output Real Pp_new[3];
    output Real b_land_new[4];
    output Real Pbl_new[4];
  protected
    Real d[3];
    Real h;
    Real innov;
    Real S;
    Real K[3];
    Real H[3];
    Real Kbl;
  algorithm
    p_new := p;
    Pp_new := Pp;
    b_land_new := b_land;
    Pbl_new := Pbl;
    for i in 1:4 loop
      d[1] := p_new[1] - Lm[i,1];
      d[2] := p_new[2] - Lm[i,2];
      d[3] := p_new[3] - Lm[i,3];
      h := safeDist3(d);
      innov := ranges[i] - (h + b_land_new[i]);
      H[1] := d[1]/h;
      H[2] := d[2]/h;
      H[3] := d[3]/h;
      S := Pp_new[1]*H[1]*H[1] + Pp_new[2]*H[2]*H[2] + Pp_new[3]*H[3]*H[3] + sigmaRange*sigmaRange + Pbl_new[i];
      S := max(S, 1e-12);
      for k in 1:3 loop
        K[k] := Pp_new[k]*H[k]/S;
        p_new[k] := p_new[k] + K[k]*innov;
        Pp_new[k] := max(Pmin, Pp_new[k]*(1.0 - K[k]*H[k]));
      end for;
      Kbl := Pbl_new[i]/(Pbl_new[i] + sigmaRangeBias*sigmaRangeBias + 1e-9);
      b_land_new[i] := b_land_new[i] + Kbl*innov;
      Pbl_new[i] := max(Pmin, Pbl_new[i]*(1.0 - Kbl));
    end for;
  end landmarkUpdate;

  function contactUpdate
    input Real v[3];
    input Real Pv[3];
    input Real b_a[3];
    input Real Pba[3];
    input Real meas[3];
    input Real sigmaContact;
    input Real sigmaBa;
    input Real Pmin;
    output Real v_new[3];
    output Real Pv_new[3];
    output Real b_a_new[3];
    output Real Pba_new[3];
  protected
    Real innov;
    Real S;
    Real Kv;
    Real Kb;
  algorithm
    for k in 1:3 loop
      innov := meas[k] - v[k];
      S := Pv[k] + sigmaContact*sigmaContact;
      S := max(S, 1e-12);
      Kv := Pv[k]/S;
      v_new[k] := v[k] + Kv*innov;
      Pv_new[k] := max(Pmin, Pv[k]*(1.0 - Kv));
      Kb := Pba[k]/(Pba[k] + sigmaBa*sigmaBa + 1e-9);
      b_a_new[k] := b_a[k] - Kb*innov;
      Pba_new[k] := max(Pmin, Pba[k]*(1.0 - Kb));
    end for;
  end contactUpdate;

  function attUpdate
    input Real att[3];
    input Real Patt[3];
    input Real b_g[3];
    input Real Pbg[3];
    input Real meas[3];
    input Real sigmaAtt;
    input Real sigmaBg;
    input Real Pmin;
    output Real att_new[3];
    output Real Patt_new[3];
    output Real b_g_new[3];
    output Real Pbg_new[3];
  protected
    Real innov;
    Real S;
    Real K;
    Real Kb;
  algorithm
    for k in 1:3 loop
      innov := meas[k] - att[k];
      S := Patt[k] + sigmaAtt*sigmaAtt;
      S := max(S, 1e-12);
      K := Patt[k]/S;
      att_new[k] := att[k] + K*innov;
      Patt_new[k] := max(Pmin, Patt[k]*(1.0 - K));
      Kb := Pbg[k]/(Pbg[k] + sigmaBg*sigmaBg + 1e-9);
      b_g_new[k] := b_g[k] - Kb*innov;
      Pbg_new[k] := max(Pmin, Pbg[k]*(1.0 - Kb));
    end for;
  end attUpdate;

  function forceUpdate
    input Real bf[4];
    input Real Pbf[4];
    input Real meas[4];
    input Real pred[4];
    input Real sigmaForce;
    input Real Pmin;
    output Real bf_new[4];
    output Real Pbf_new[4];
  protected
    Real innov;
    Real S;
    Real K;
  algorithm
    for i in 1:4 loop
      innov := meas[i] - pred[i];
      S := Pbf[i] + sigmaForce*sigmaForce;
      S := max(S, 1e-12);
      K := Pbf[i]/S;
      bf_new[i] := bf[i] + K*innov;
      Pbf_new[i] := max(Pmin, Pbf[i]*(1.0 - K));
    end for;
  end forceUpdate;

end ContactStateLocalizeF;