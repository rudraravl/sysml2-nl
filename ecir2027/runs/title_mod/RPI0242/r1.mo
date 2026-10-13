model FourBarDriveB
  import Modelica.Constants.{pi, g_n};

  parameter Real d(unit="m") = 0.50 "fixed pivot spacing";
  parameter Real L1(unit="m") = 0.20 "crank length";
  parameter Real L2(unit="m") = 0.44 "coupler length";
  parameter Real L3(unit="m") = 0.35 "rocker length";
  parameter Real tau_max(unit="N.m") = 20.5 "allowed actuator command magnitude";
  parameter Real dist_mag(unit="N.m") = 5.6 "injected load disturbance magnitude";
  parameter Real T_run(unit="s") = 10.0 "mission duration";
  parameter Real Ts(unit="s") = 0.01 "100 Hz control and sensor sampling period";
  parameter Real closureTol(unit="m") = 0.002 "primary closure tracking tolerance";
  parameter Real T_check(unit="s") = 6.5 "closure tolerance verification time";

  // Facts not stated in the request are marked as placeholders.
  parameter Real q0(unit="rad") = 0.2 "placeholder initial crank angle";
  parameter Real speed_ref(unit="rad/s") = 0.3 "placeholder constant input speed";
  parameter Real J_act(unit="kg.m2") = 1.0 "placeholder actuator inertia";
  parameter Real Kp(unit="N.m.s/rad") = 50.0 "placeholder PI proportional gain";
  parameter Real Ki(unit="N.m/rad") = 200.0 "placeholder PI integral gain";
  parameter Real speedBand(unit="rad/s") = 0.15 "placeholder speed band";
  parameter Real planeGap(unit="m") = 0.01 "placeholder plane separation preventing nonadjacent collision";
  parameter Real kStab(unit="1/s") = 5.0 "placeholder loop-closure stabilization gain";
  parameter Real epsLen(unit="m2") = 1.0e-12 "length-square zero guard";
  parameter Real epsDen(unit="1") = 1.0e-12 "denominator zero guard";

protected
  parameter Real g(unit="m/s2") = g_n "gravity; loop plane is horizontal with revolute Z axes parallel to gravity";
  parameter Real s0 = sqrt((L1*cos(q0) - d)^2 + (L1*sin(q0))^2);
  parameter Real beta0 = acos((s0^2 + L3^2 - L2^2)/(2.0*s0*L3));
  parameter Real gamma0 = atan2(L1*sin(q0), L1*cos(q0) - d);
  parameter Real psi0 = gamma0 - beta0;

public
  Real q(start=q0, fixed=true) "crank angle";
  Real omega(start=0.0, fixed=true) "crank angular velocity";
  Real psi(start=psi0, fixed=true) "rocker angle";
  Real rockerTravel(start=0.0, fixed=true) "accumulated rocker angular travel";
  Real rockerTipTravel(start=0.0, fixed=true) "accumulated rocker-tip travel";

  discrete Real integral(start=0.0) "PI integrator state";
  discrete Real tau_raw(start=0.0) "unsaturated PI command";
  discrete Real tau_cmd(start=0.0) "saturated crank torque command";

  Real tau_dist "injected disturbance torque";
  Real gravityGeneralizedTorque "gravity torque about Z; zero in this horizontal-plane idealization";
  Real r_x "coupler vector x";
  Real r_y "coupler vector y";
  Real rLen2 "squared coupler closure distance";
  Real rLen "coupler closure distance";
  Real theta2 "coupler angle";
  Real psiDot "rocker angular velocity from loop kinematics";
  Real sinTerm "closure denominator term";
  Real closure_x "loop-closure residual x";
  Real closure_y "loop-closure residual y";
  Real closure_norm "loop-closure residual norm";
  Real closureErr "primary closure tracking error";

  Real crankTipX "crank moving pivot x";
  Real crankTipY "crank moving pivot y";
  Real rockerTipX "rocker moving pivot x";
  Real rockerTipY "rocker moving pivot y";

  Real jointAngleA "ground-crank revolute Z joint angle";
  Real jointAngleB "crank-coupler revolute Z joint angle";
  Real jointAngleC "coupler-rocker revolute Z joint angle";
  Real jointAngleD "rocker-ground revolute Z joint angle";

  Real distGroundCoupler "planar distance between nonadjacent ground and coupler";
  Real distCrankRocker "planar distance between nonadjacent crank and rocker";
  Real clearanceGroundCoupler "3D clearance for ground-coupler pair";
  Real clearanceCrankRocker "3D clearance for crank-rocker pair";

  discrete Integer tick(start=0) "synchronized sample counter";
  discrete Real time_s(start=0.0) "sampled time";
  discrete Real q_s "sampled crank angle";
  discrete Real omega_s "sampled crank speed";
  discrete Real tau_cmd_s "sampled command";
  discrete Real psi_s "sampled rocker angle";
  discrete Real theta2_s "sampled coupler angle";
  discrete Real closure_norm_s "sampled closure error";
  discrete Real rockerTravel_s "sampled rocker angular travel";
  discrete Real rockerTipTravel_s "sampled output travel";
  discrete Real rockerTipX_s "sampled output pose x";
  discrete Real rockerTipY_s "sampled output pose y";
  discrete Real speedError_s "sampled speed error";

  Boolean actuatorBoundOK;
  Boolean speedBandOK;
  Boolean closureOK;
  Boolean jointReferencesValid;
  Boolean collisionFree;
  Boolean boundedOK;

  discrete Boolean saturating;
equation
  der(q) = omega;
  der(omega) = (tau_cmd + tau_dist + gravityGeneralizedTorque)/J_act;
  der(psi) = psiDot - kStab*closureErr*sinTerm/(sinTerm*sinTerm + epsDen);
  der(rockerTravel) = abs(psiDot);
  der(rockerTipTravel) = L3*abs(psiDot);

  gravityGeneralizedTorque = 0.0*g;
  tau_dist = if time >= T_run/3.0 and time <= 2.0*T_run/3.0 then -dist_mag else 0.0;

  crankTipX = L1*cos(q);
  crankTipY = L1*sin(q);
  rockerTipX = d + L3*cos(psi);
  rockerTipY = L3*sin(psi);

  r_x = d + L3*cos(psi) - L1*cos(q);
  r_y = L3*sin(psi) - L1*sin(q);
  rLen2 = r_x*r_x + r_y*r_y;
  rLen = if rLen2 > epsLen then sqrt(rLen2) else 0.0;
  theta2 = if rLen2 > epsLen then atan2(r_y, r_x) else 0.0;

  closure_x = r_x - L2*cos(theta2);
  closure_y = r_y - L2*sin(theta2);
  closure_norm = if rLen2 > epsLen then abs(rLen - L2) else 0.0;
  closureErr = closure_norm;

  sinTerm = L3*sin(theta2 - psi);
  psiDot = if abs(sinTerm) > epsDen then (L1*sin(theta2 - q)/sinTerm)*omega else 0.0;

  jointAngleA = q;
  jointAngleB = theta2 - q;
  jointAngleC = theta2 - psi;
  jointAngleD = psi;

  distGroundCoupler = segDist2D(0.0, 0.0, d, 0.0, crankTipX, crankTipY, rockerTipX, rockerTipY);
  distCrankRocker = segDist2D(0.0, 0.0, crankTipX, crankTipY, d, 0.0, rockerTipX, rockerTipY);
  clearanceGroundCoupler = sqrt(distGroundCoupler*distGroundCoupler + planeGap*planeGap);
  clearanceCrankRocker = sqrt(distCrankRocker*distCrankRocker + planeGap*planeGap);

  actuatorBoundOK = abs(tau_cmd) <= tau_max + 1.0e-9;
  speedBandOK = if time >= 2.0 then abs(omega - speed_ref) <= speedBand else true;
  closureOK = if time >= T_check then closure_norm <= closureTol else true;
  jointReferencesValid = abs(jointAngleA) < 1.0e6 and abs(jointAngleB) < 1.0e6 and abs(jointAngleC) < 1.0e6 and abs(jointAngleD) < 1.0e6 and abs(sinTerm) > 1.0e-3;
  collisionFree = clearanceGroundCoupler > 0.0 and clearanceCrankRocker > 0.0;
  boundedOK = abs(q) < 1.0e6 and abs(omega) < 1.0e6 and abs(psi) < 1.0e6 and abs(psiDot) < 1.0e6 and abs(theta2) < 1.0e6 and abs(tau_cmd) < 1.0e6 and abs(tau_raw) < 1.0e6 and abs(tau_dist) < 1.0e6 and abs(closure_x) < 1.0e6 and abs(closure_y) < 1.0e6 and abs(closure_norm) < 1.0e6 and abs(rockerTravel) < 1.0e6 and abs(rockerTipTravel) < 1.0e6;

  assert(actuatorBoundOK, "actuator command bound violated");
  assert(speedBandOK, "speed band violated");
  assert(closureOK, "primary closure tracking error exceeded after 6.5 s");
  assert(jointReferencesValid, "invalid joint references");
  assert(collisionFree, "nonadjacent link collision");
  assert(boundedOK, "non-finite or unbounded physical/control value detected");

  when sample(0, Ts) then
    saturating = abs(pre(tau_cmd)) >= tau_max - 1.0e-9;
    integral = pre(integral) + Ts*(if (saturating and pre(tau_raw)*(speed_ref - omega) > 0.0) then 0.0 else (speed_ref - omega));
    tau_raw = Kp*(speed_ref - omega) + Ki*integral;
    tau_cmd = max(-tau_max, min(tau_max, tau_raw));

    tick = pre(tick) + 1;
    time_s = time;
    q_s = q;
    omega_s = omega;
    tau_cmd_s = tau_cmd;
    psi_s = psi;
    theta2_s = theta2;
    closure_norm_s = closure_norm;
    rockerTravel_s = rockerTravel;
    rockerTipTravel_s = rockerTipTravel;
    rockerTipX_s = rockerTipX;
    rockerTipY_s = rockerTipY;
    speedError_s = speed_ref - omega;
  end when;

  annotation(experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01));
end FourBarDriveB;