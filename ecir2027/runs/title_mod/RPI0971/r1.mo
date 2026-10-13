model DiffRoverClimbE
  function ridgeShape
    input Real xi;
    input Real w;
    output Real y;
  algorithm
    if abs(xi) < w/2 then
      y := 0.5*(1.0 - cos(2.0*Modelica.Constants.pi*xi/w));
    else
      y := 0.0;
    end if;
  end ridgeShape;

  function ridgeShapeDer
    input Real xi;
    input Real w;
    output Real y;
  algorithm
    if abs(xi) < w/2 then
      y := (Modelica.Constants.pi/w)*sin(2.0*Modelica.Constants.pi*xi/w);
    else
      y := 0.0;
    end if;
  end ridgeShapeDer;

  function finiteReal
    input Real x;
    output Boolean y;
  algorithm
    y := (x >= -1.0e12) and (x <= 1.0e12);
  end finiteReal;

  // Requirement facts
  parameter Real m = 19.0 "box chassis mass, kg";
  parameter Real L = 0.65 "chassis length, m";
  parameter Real W = 0.44 "chassis width, m";
  parameter Real H = 0.22 "chassis height, m";
  parameter Real r = 0.10 "driven wheel radius, m";
  parameter Real wheelSep = 0.46 "driven wheel separation, m";
  parameter Real mu = 0.76 "surface friction coefficient";
  parameter Real tauMax = 14.3 "wheel motor command magnitude bound, N.m";
  parameter Real payloadForce = 180.0 "payload force magnitude, N";
  parameter Real rampAngle = 12.0*Modelica.Constants.pi/180.0 "ramp angle, rad";
  parameter Real L_plateau = 2.0 "plateau length, m";
  parameter Real ridgeHeight = 0.05 "surface ridge height, m";
  parameter Real T = 16.0 "run duration, s";
  parameter Real Ts = 0.004 "control/sensor sample period, 250 Hz, s";

  // Selected bindings for quantities not specified by the requirement
  parameter Real L_ramp = 1.0 "selected ramp length; only ramp angle and plateau length are specified";
  parameter Real s_ridge1 = 1.3 "selected first ridge location on plateau";
  parameter Real s_ridge2 = 2.2 "selected second ridge location on plateau";
  parameter Real ridgeWidth = 0.6 "selected ridge support width";
  parameter Real Jw = 0.05 "selected wheel/motor inertia placeholder, kg.m2";
  parameter Real bw = 0.05 "selected wheel damping placeholder, N.m.s";
  parameter Real kTraction = 30.0 "selected traction creep gain, s/m";
  parameter Real N_drive_fraction = 2.0/3.0 "selected driven-axle load fraction; caster carries remainder";
  parameter Real Kp = 30.0 "selected speed controller gain, N.s/m";
  parameter Real Ki = 20.0 "selected speed controller integral gain, N/m";
  parameter Real integralLimit = 50.0 "selected anti-windup bound, N";
  parameter Real Kedge = 1.0 "selected edge-distance speed gain, 1/s";
  parameter Real v_nom = 0.30 "selected nominal traverse speed, m/s";
  parameter Real stopThreshold = 0.10 "selected stopping margin before descending edge, m";
  parameter Real Kslip = 10.0 "selected slip reduction gain";
  parameter Real slipTarget = 0.25 "selected slip target";
  parameter Real slipDenMin = 0.10 "selected low-speed slip denominator, m/s";
  parameter Real vStopTol = 0.02 "selected final stop speed tolerance, m/s";

  parameter Real tanA = tan(rampAngle);
  parameter Real H_ramp = L_ramp*tanA;
  parameter Real s_edge = L_ramp + L_plateau;

  constant Real g = 9.81 "m/s2";

  // Physical plant states
  Real s(start=0.0, fixed=true) "longitudinal path coordinate, m";
  Real v(start=0.0, fixed=true) "longitudinal base speed, m/s";
  Real omegaL(start=0.0, fixed=true) "left wheel angular speed about Y, rad/s";
  Real omegaR(start=0.0, fixed=true) "right wheel angular speed about Y, rad/s";

  // Floating-base pose
  Real x_base;
  Real z_base;
  Real h;
  Real h_ramp;
  Real dh_ramp;
  Real h_ridge;
  Real dh_ridge;
  Real dh_ds;
  Real pitch;
  Real roll;

  // Contact and force structure
  Real F_payload_z "payload force modeled vertical downward; direction not specified";
  Real N_total;
  Real N_L;
  Real N_R;
  Real N_caster "passive caster normal force";
  Real F_grade;
  Real F_L;
  Real F_R;
  Real tauL;
  Real tauR;
  Real slipL;
  Real slipR;

  // Continuous sensors
  Real vEnc;
  Real edgeDistSensor;
  Real pitchIMU;
  Real rollIMU;

  // Discrete control, estimator, and synchronized traces
  Real v_ref(start=0.0, fixed=true);
  Real integralError(start=0.0, fixed=true);
  Real tractionFactorL(start=1.0, fixed=true);
  Real tractionFactorR(start=1.0, fixed=true);
  Real F_cmd(start=0.0, fixed=true);
  Real tauTotal(start=0.0, fixed=true);
  Real tauCmdL(start=0.0, fixed=true);
  Real tauCmdR(start=0.0, fixed=true);

  Real sensor_vEnc_z(start=0.0, fixed=true);
  Real sensor_pitchIMU_z(start=0.0, fixed=true);
  Real sensor_rollIMU_z(start=0.0, fixed=true);
  Real sensor_edgeDist_z(start=s_edge, fixed=true);
  Real slipL_z(start=0.0, fixed=true);
  Real slipR_z(start=0.0, fixed=true);

  Real state_s_z(start=0.0, fixed=true);
  Real state_v_z(start=0.0, fixed=true);
  Real state_pitch_z(start=0.0, fixed=true);
  Real state_roll_z(start=0.0, fixed=true);
  Real command_tauL_z(start=0.0, fixed=true);
  Real command_tauR_z(start=0.0, fixed=true);

  Real primaryTrackingError;
  Real stoppingMargin;

  Boolean actuatorOK(start=true, fixed=true);
  Boolean slipOK(start=true, fixed=true);
  Boolean attitudeOK(start=true, fixed=true);
  Boolean trackingOK(start=true, fixed=true);
  Boolean edgeOK(start=true, fixed=true);
  Boolean stopOK(start=true, fixed=true);
  Boolean finiteOK(start=true, fixed=true);
  Boolean Acceptance(start=true, fixed=true) "fail-closed acceptance latch";

equation
  der(s) = v;
  der(v) = (F_L + F_R - F_grade)/m;
  der(omegaL) = (tauL - r*F_L - bw*omegaL)/Jw;
  der(omegaR) = (tauR - r*F_R - bw*omegaR)/Jw;

  x_base = s;
  z_base = h;

  h_ramp = if s < L_ramp then s*tanA
           else if s < s_edge then H_ramp
           else if s < s_edge + L_ramp then H_ramp - (s - s_edge)*tanA
           else 0.0;

  dh_ramp = if s < L_ramp then tanA
            else if s < s_edge then 0.0
            else if s < s_edge + L_ramp then -tanA
            else 0.0;

  h_ridge = ridgeHeight*(ridgeShape(s - s_ridge1, ridgeWidth) + ridgeShape(s - s_ridge2, ridgeWidth));
  dh_ridge = ridgeHeight*(ridgeShapeDer(s - s_ridge1, ridgeWidth) + ridgeShapeDer(s - s_ridge2, ridgeWidth));

  h = h_ramp + h_ridge;
  dh_ds = dh_ramp + dh_ridge;
  pitch = atan(dh_ds);
  roll = 0.0;

  F_payload_z = if time >= T/3.0 and time <= 2.0*T/3.0 then payloadForce else 0.0;
  F_grade = (m*g + F_payload_z)*sin(pitch);
  N_total = (m*g + F_payload_z)*cos(pitch);
  N_L = N_drive_fraction*N_total/2.0;
  N_R = N_drive_fraction*N_total/2.0;
  N_caster = (1.0 - N_drive_fraction)*N_total;

  F_L = mu*N_L*tanh(kTraction*(omegaL*r - v));
  F_R = mu*N_R*tanh(kTraction*(omegaR*r - v));

  tauL = max(-tauMax, min(tauMax, tauCmdL));
  tauR = max(-tauMax, min(tauMax, tauCmdR));

  slipL = (omegaL*r - v)/max(abs(omegaL*r) + abs(v), slipDenMin);
  slipR = (omegaR*r - v)/max(abs(omegaR*r) + abs(v), slipDenMin);

  vEnc = (omegaL + omegaR)/2.0*r;
  edgeDistSensor = max(0.0, s_edge - s);
  pitchIMU = pitch;
  rollIMU = roll;

  primaryTrackingError = abs(sensor_vEnc_z - v_ref);
  stoppingMargin = sensor_edgeDist_z;

  when sample(0.0, Ts) then
    sensor_vEnc_z = (omegaL + omegaR)/2.0*r;
    sensor_pitchIMU_z = pitch;
    sensor_rollIMU_z = roll;
    sensor_edgeDist_z = max(0.0, s_edge - s);
    slipL_z = (omegaL*r - v)/max(abs(omegaL*r) + abs(v), slipDenMin);
    slipR_z = (omegaR*r - v)/max(abs(omegaR*r) + abs(v), slipDenMin);

    state_s_z = s;
    state_v_z = v;
    state_pitch_z = pitch;
    state_roll_z = roll;

    if sensor_edgeDist_z > stopThreshold then
      v_ref = min(v_nom, Kedge*(sensor_edgeDist_z - stopThreshold));
    else
      v_ref = 0.0;
    end if;

    tractionFactorL = max(0.0, min(1.0, 1.0 - Kslip*max(0.0, abs(slipL_z) - slipTarget)));
    tractionFactorR = max(0.0, min(1.0, 1.0 - Kslip*max(0.0, abs(slipR_z) - slipTarget)));

    integralError = max(-integralLimit, min(integralLimit, pre(integralError) + Ts*(v_ref - sensor_vEnc_z)));
    F_cmd = Kp*(v_ref - sensor_vEnc_z) + Ki*integralError + (m*g + F_payload_z)*sin(sensor_pitchIMU_z);
    tauTotal = F_cmd*r/2.0;
    tauCmdL = max(-tauMax, min(tauMax, tauTotal*tractionFactorL));
    tauCmdR = max(-tauMax, min(tauMax, tauTotal*tractionFactorR));

    command_tauL_z = tauCmdL;
    command_tauR_z = tauCmdR;

    actuatorOK = (abs(tauL) <= tauMax + 1.0e-9) and (abs(tauR) <= tauMax + 1.0e-9);
    slipOK = (abs(slipL) < 0.35) and (abs(slipR) < 0.35);
    attitudeOK = (abs(roll) < 0.40) and (abs(pitch) < 0.40);
    trackingOK = if time >= 10.4 then (abs(sensor_vEnc_z - v_ref) < 0.162) else true;
    edgeOK = sensor_edgeDist_z > 0.0;
    stopOK = if time >= 15.5 then (abs(v) < vStopTol and sensor_edgeDist_z > 0.0) else true;

    finiteOK = finiteReal(s) and finiteReal(v) and finiteReal(omegaL) and finiteReal(omegaR) and
               finiteReal(pitch) and finiteReal(roll) and finiteReal(F_L) and finiteReal(F_R) and
               finiteReal(N_total) and finiteReal(F_payload_z) and finiteReal(tauL) and finiteReal(tauR) and
               finiteReal(v_ref) and finiteReal(tauCmdL) and finiteReal(tauCmdR) and finiteReal(integralError) and
               finiteReal(sensor_vEnc_z) and finiteReal(sensor_pitchIMU_z) and finiteReal(sensor_rollIMU_z) and
               finiteReal(sensor_edgeDist_z) and finiteReal(slipL) and finiteReal(slipR) and
               finiteReal(F_cmd) and finiteReal(tauTotal);

    Acceptance = pre(Acceptance) and actuatorOK and slipOK and attitudeOK and trackingOK and edgeOK and stopOK and finiteOK;
  end when;

  annotation(experiment(StopTime=16.0, Interval=0.004, Tolerance=1e-6));
end DiffRoverClimbE;