model MarinePairHandoffA
  // Physical parameters
  parameter Real mass_kg = 80.0 "AUV mass kg";
  parameter Real thrustLimit_N = 75.6 "N per-thruster command limit";
  parameter Real damping = 50.0 "N.s/m linear drag coefficient";
  parameter Real Kp = 60.0 "N/m proportional gain per thruster";
  parameter Real Kd = 50.0 "N.s/m derivative gain per thruster";

  // Scenario timing
  parameter Real Ts = 0.0125 "s control period (80 Hz)";
  parameter Real T_total = 8.0 "s scenario duration";
  parameter Real t_mid_start = 8.0/3.0 "s middle third start";
  parameter Real t_mid_end = 16.0/3.0 "s middle third end";
  parameter Real delay_mid = 0.05 "s communication delay during middle third";
  parameter Real err_thresh = 0.54 "m tracking error threshold";
  parameter Real err_time = 5.2 "s tracking error check time";

  // World frame markers and survey features
  parameter Real m1x = 3.0 "m marker 1 x (inspection target A)";
  parameter Real m1z = 0.5 "m marker 1 z";
  parameter Real m2x = 6.0 "m marker 2 x (inspection target B)";
  parameter Real m2z = -1.0 "m marker 2 z";
  parameter Real wallX = 9.0 "m world wall boundary";
  parameter Real minSep = 1.0 "m minimum safe separation";

  // Robot A continuous states
  Real x_a(start=0.0, fixed=true) "m x-position A";
  Real z_a(start=0.0, fixed=true) "m z-position A";
  Real vx_a(start=0.0, fixed=true) "m/s x-velocity A";
  Real vz_a(start=0.0, fixed=true) "m/s z-velocity A";

  // Robot B continuous states
  Real x_b(start=1.0, fixed=true) "m x-position B";
  Real z_b(start=0.0, fixed=true) "m z-position B";
  Real vx_b(start=0.0, fixed=true) "m/s x-velocity B";
  Real vz_b(start=0.0, fixed=true) "m/s z-velocity B";

  // Eight bidirectional thruster channels
  discrete Real cmd1(start=0.0) "N A surge thr 1";
  discrete Real cmd2(start=0.0) "N A surge thr 2";
  discrete Real cmd3(start=0.0) "N A heave thr 1";
  discrete Real cmd4(start=0.0) "N A heave thr 2";
  discrete Real cmd5(start=0.0) "N B surge thr 1";
  discrete Real cmd6(start=0.0) "N B surge thr 2";
  discrete Real cmd7(start=0.0) "N B heave thr 1";
  discrete Real cmd8(start=0.0) "N B heave thr 2";
  Real f1 "N saturated A surge thr 1";
  Real f2 "N saturated A surge thr 2";
  Real f3 "N saturated A heave thr 1";
  Real f4 "N saturated A heave thr 2";
  Real f5 "N saturated B surge thr 1";
  Real f6 "N saturated B surge thr 2";
  Real f7 "N saturated B heave thr 1";
  Real f8 "N saturated B heave thr 2";
  Real Fx_a "N net surge force A";
  Real Fz_a "N net heave force A";
  Real Fx_b "N net surge force B";
  Real Fz_b "N net heave force B";

  // Sensors: IMU, pressure depth, DVL (local to each robot)
  Real ax_a "m/s2 IMU accel x A";
  Real az_a "m/s2 IMU accel z A";
  Real ax_b "m/s2 IMU accel x B";
  Real az_b "m/s2 IMU accel z B";
  Real depth_a "m pressure depth A";
  Real depth_b "m pressure depth B";
  Real dvl_vx_a "m/s DVL vx A";
  Real dvl_vz_a "m/s DVL vz A";
  Real dvl_vx_b "m/s DVL vx B";
  Real dvl_vz_b "m/s DVL vz B";

  // Control targets (discrete, updated by task allocation / replan)
  discrete Real tx_a(start=3.0) "m target x A";
  discrete Real tz_a(start=0.5) "m target z A";
  discrete Real tx_b(start=6.0) "m target x B";
  discrete Real tz_b(start=-1.0) "m target z B";

  // Tracking errors
  Real err_a "m primary tracking error robot A";
  Real err_b "m secondary tracking error robot B";

  // Handoff state machine
  Integer handoffState(start=0) "0 inspect 1 send 2 wait 3 replan 4 done";
  Boolean b_done(start=false) "B inspection complete";
  Boolean handoffComplete(start=false) "handoff completed";

  // Communication: delayed acoustic modem
  Real commDelayCurrent "s active communication delay";
  Boolean commSend(start=false) "send event flag";
  Boolean commReceive(start=false) "receive event flag";
  discrete Real dataAge(start=0.0) "s data age at receipt";
  Real dataAgeLive "s live data age since received timestamp";
  discrete Real sentTs(start=0.0) "s sent timestamp";
  discrete Real rcvdTs(start=0.0) "s received timestamp";
  discrete Real sentData_x(start=0.0) "m sent x";
  discrete Real sentData_z(start=0.0) "m sent z";
  discrete Real rcvdData_x(start=0.0) "m received x";
  discrete Real rcvdData_z(start=0.0) "m received z";
  Boolean msgInFlight(start=false) "message in transit";
  discrete Real msgArrivalTime(start=0.0) "s message arrival time";
  discrete Real msgData_x(start=0.0) "m buffered x";
  discrete Real msgData_z(start=0.0) "m buffered z";
  discrete Real msgData_ts(start=0.0) "s buffered timestamp";

  // Separation and bounds
  Real separation "m inter-robot separation";
  Boolean noCollision "separation constraint satisfied";
  Boolean boundsOK "position bounds satisfied";
  Boolean taskComplete "all tasks and handoff complete";
  Boolean trackingOK "primary tracking error within bound after check time";

equation
  // Robot A dynamics
  der(x_a) = vx_a;
  der(z_a) = vz_a;
  mass_kg * der(vx_a) = Fx_a - damping * vx_a;
  mass_kg * der(vz_a) = Fz_a - damping * vz_a;

  // Robot B dynamics
  der(x_b) = vx_b;
  der(z_b) = vz_b;
  mass_kg * der(vx_b) = Fx_b - damping * vx_b;
  mass_kg * der(vz_b) = Fz_b - damping * vz_b;

  // Net forces from 8 thruster channels
  Fx_a = f1 + f2;
  Fz_a = f3 + f4;
  Fx_b = f5 + f6;
  Fz_b = f7 + f8;

  // Thruster saturation bidirectional
  f1 = max(-thrustLimit_N, min(thrustLimit_N, cmd1));
  f2 = max(-thrustLimit_N, min(thrustLimit_N, cmd2));
  f3 = max(-thrustLimit_N, min(thrustLimit_N, cmd3));
  f4 = max(-thrustLimit_N, min(thrustLimit_N, cmd4));
  f5 = max(-thrustLimit_N, min(thrustLimit_N, cmd5));
  f6 = max(-thrustLimit_N, min(thrustLimit_N, cmd6));
  f7 = max(-thrustLimit_N, min(thrustLimit_N, cmd7));
  f8 = max(-thrustLimit_N, min(thrustLimit_N, cmd8));

  // IMU sensors acceleration
  ax_a = (Fx_a - damping * vx_a) / mass_kg;
  az_a = (Fz_a - damping * vz_a) / mass_kg;
  ax_b = (Fx_b - damping * vx_b) / mass_kg;
  az_b = (Fz_b - damping * vz_b) / mass_kg;

  // Pressure depth sensors
  depth_a = z_a;
  depth_b = z_b;

  // DVL velocity sensors
  dvl_vx_a = vx_a;
  dvl_vz_a = vz_a;
  dvl_vx_b = vx_b;
  dvl_vz_b = vz_b;

  // Communication delay 0.05 s during middle third otherwise 0
  commDelayCurrent = if (time >= t_mid_start and time < t_mid_end) then delay_mid else 0.0;

  // Tracking errors with well defined zero branch
  err_a = sqrt((x_a - tx_a)*(x_a - tx_a) + (z_a - tz_a)*(z_a - tz_a) + 1e-9);
  err_b = sqrt((x_b - tx_b)*(x_b - tx_b) + (z_b - tz_b)*(z_b - tz_b) + 1e-9);

  // Separation with well defined zero branch
  separation = sqrt((x_a - x_b)*(x_a - x_b) + (z_a - z_b)*(z_a - z_b) + 1e-9);

  // Live data age
  dataAgeLive = if handoffComplete then time - rcvdTs else 0.0;

  // Status flags
  noCollision = separation >= minSep * 0.5;
  boundsOK = (x_a >= -0.5) and (x_a <= wallX) and (x_b >= -0.5) and (x_b <= wallX);
  taskComplete = handoffComplete and (err_a < err_thresh) and (err_b < err_thresh);
  trackingOK = (time < err_time) or (err_a < err_thresh);

when sample(0, Ts) loop
  // Local motion control PD per thruster channel
  cmd1 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tx_a - x_a) - Kd * vx_a));
  cmd2 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tx_a - x_a) - Kd * vx_a));
  cmd3 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tz_a - z_a) - Kd * vz_a));
  cmd4 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tz_a - z_a) - Kd * vz_a));
  cmd5 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tx_b - x_b) - Kd * vx_b));
  cmd6 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tx_b - x_b) - Kd * vx_b));
  cmd7 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tz_b - z_b) - Kd * vz_b));
  cmd8 := max(-thrustLimit_N, min(thrustLimit_N, Kp * (tz_b - z_b) - Kd * vz_b));

  // Task allocation and explicit handoff state machine
  if handoffState == 0 then
    commSend := false;
    commReceive := false;
    if err_b < 0.5 then
      b_done := true;
      handoffState := 1;
    end if;
  elseif handoffState == 1 then
    commSend := true;
    commReceive := false;
    msgInFlight := true;
    msgArrivalTime := time + commDelayCurrent;
    msgData_x := x_b;
    msgData_z := z_b;
    msgData_ts := time;
    sentTs := time;
    sentData_x := x_b;
    sentData_z := z_b;
    handoffState := 2;
  elseif handoffState == 2 then
    commSend := false;
    if msgInFlight and time >= msgArrivalTime then
      msgInFlight := false;
      commReceive := true;
      rcvdTs := msgData_ts;
      rcvdData_x := msgData_x;
      rcvdData_z := msgData_z;
      dataAge := time - msgData_ts;
      handoffState := 3;
    else
      commReceive := false;
    end if;
  elseif handoffState == 3 then
    commReceive := false;
    commSend := false;
    tx_a := rcvdData_x - 2.5;
    tz_a := rcvdData_z + 1.5;
    handoffComplete := true;
    handoffState := 4;
  else
    commSend := false;
    commReceive := false;
  end if;
end when;

  annotation (experiment(StopTime = 8.0, Tolerance = 1e-6));
end MarinePairHandoffA;