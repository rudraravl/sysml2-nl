model FourBarPositionC
  function fourbar_solve
    input Real theta;
    input Real L0;
    input Real L2;
    input Real L3;
    input Real L4;
    input Real branchSign;
    output Real Bx;
    output Real By;
    output Real Cx;
    output Real Cy;
    output Real phi3;
    output Real phi4;
    output Real res1;
    output Real res2;
  protected
    Real Dx;
    Real Dy;
    Real px;
    Real py;
    Real h;
    Real ux;
    Real uy;
    Real nx;
    Real ny;
    Real aa;
    Real bb;
    Real distBC;
    Real distDC;
  algorithm
    Bx := L2*Modelica.Math.cos(theta);
    By := L2*Modelica.Math.sin(theta);
    Dx := L0;
    Dy := 0.0;
    px := Dx - Bx;
    py := Dy - By;
    h := Modelica.Math.sqrt(px*px + py*py);
    if h < 1.0e-12 then
      ux := 1.0;
      uy := 0.0;
    else
      ux := px/h;
      uy := py/h;
    end if;
    nx := -uy;
    ny := ux;
    if h < 1.0e-12 then
      aa := 0.0;
      bb := 0.0;
    else
      aa := (h*h + L4*L4 - L3*L3)/(2.0*h);
      bb := Modelica.Math.sqrt(max(L4*L4 - aa*aa, 0.0));
    end if;
    Cx := Dx - aa*ux + branchSign*bb*nx;
    Cy := Dy - aa*uy + branchSign*bb*ny;
    phi3 := Modelica.Math.atan2(Cy - By, Cx - Bx);
    phi4 := Modelica.Math.atan2(Cy - Dy, Cx - Dx);
    distBC := Modelica.Math.sqrt((Cx - Bx)*(Cx - Bx) + (Cy - By)*(Cy - By));
    distDC := Modelica.Math.sqrt((Cx - Dx)*(Cx - Dx) + (Cy - Dy)*(Cy - Dy));
    res1 := distBC - L3;
    res2 := distDC - L4;
  end fourbar_solve;

  function fourbar_platform
    input Real theta;
    input Real L0;
    input Real L2;
    input Real L3;
    input Real L4;
    input Real branchSign;
    output Real Px;
    output Real Py;
    output Real phi3;
    output Real phi4;
    output Real closureResidual;
  protected
    Real Bx;
    Real By;
    Real Cx;
    Real Cy;
    Real phi3loc;
    Real phi4loc;
    Real res1;
    Real res2;
  algorithm
    (Bx,By,Cx,Cy,phi3loc,phi4loc,res1,res2) := fourbar_solve(theta,L0,L2,L3,L4,branchSign);
    Px := 0.5*(Bx + Cx);
    Py := 0.5*(By + Cy);
    phi3 := phi3loc;
    phi4 := phi4loc;
    closureResidual := Modelica.Math.sqrt(res1*res1 + res2*res2);
  end fourbar_platform;

  function platformX
    input Real theta;
    input Real L0;
    input Real L2;
    input Real L3;
    input Real L4;
    input Real branchSign;
    output Real x;
  protected
    Real Bx;
    Real By;
    Real Cx;
    Real Cy;
    Real phi3;
    Real phi4;
    Real res1;
    Real res2;
  algorithm
    (Bx,By,Cx,Cy,phi3,phi4,res1,res2) := fourbar_solve(theta,L0,L2,L3,L4,branchSign);
    x := 0.5*(Bx + Cx);
  end platformX;

  function platformY
    input Real theta;
    input Real L0;
    input Real L2;
    input Real L3;
    input Real L4;
    input Real branchSign;
    output Real y;
  protected
    Real Bx;
    Real By;
    Real Cx;
    Real Cy;
    Real phi3;
    Real phi4;
    Real res1;
    Real res2;
  algorithm
    (Bx,By,Cx,Cy,phi3,phi4,res1,res2) := fourbar_solve(theta,L0,L2,L3,L4,branchSign);
    y := 0.5*(By + Cy);
  end platformY;

  function segmentDistance
    input Real ax;
    input Real ay;
    input Real bx;
    input Real by;
    input Real cx;
    input Real cy;
    input Real dx;
    input Real dy;
    input Integer n=50;
    output Real dist;
  protected
    Real minD;
    Real d;
    Real tx;
    Real ty;
    Real sx;
    Real sy;
    Integer i;
    Integer j;
  algorithm
    minD := 1.0e30;
    for i in 0:n loop
      tx := ax + (1.0*i/(1.0*n))*(bx - ax);
      ty := ay + (1.0*i/(1.0*n))*(by - ay);
      for j in 0:n loop
        sx := cx + (1.0*j/(1.0*n))*(dx - cx);
        sy := cy + (1.0*j/(1.0*n))*(dy - cy);
        d := Modelica.Math.sqrt(max((tx - sx)*(tx - sx) + (ty - sy)*(ty - sy), 0.0));
        if d < minD then
          minD := d;
        end if;
      end for;
    end for;
    dist := minD;
  end segmentDistance;

  // Plant geometry from requirement (SI units).
  parameter Real L0 = 0.50 "fixed pivot distance [m]";
  parameter Real L2 = 0.20 "crank length [m]";
  parameter Real L3 = 0.44 "coupler length [m]";
  parameter Real L4 = 0.35 "rocker length [m]";
  parameter Real branchSign = 1.0 "assembly branch for revolute Z-joint loop";

  // Control and run parameters from requirement.
  parameter Real tauMax = 23.0 "maximum crank command magnitude [N.m]";
  parameter Real loadMag = 12.6 "platform load disturbance magnitude [N]";
  parameter Real loadStart = 4.0 "middle third start [s]";
  parameter Real loadEnd = 8.0 "middle third end [s]";
  parameter Real Ts = 1.0/125.0 "sample period [s]";
  parameter Real stopTime = 12.0 "simulation horizon [s]";
  parameter Real trackingTol = 0.006 "primary pose error tolerance [m]";
  parameter Real trackingTime = 7.8 "tracking deadline [s]";

  // Unknown physical/control values: placeholders selected for code generation.
  parameter Real theta0 = 0.20 "initial crank angle [rad], nonzero and non-singular";
  parameter Real theta_ref_nominal = 1.0 "chosen nonzero reachable setpoint [rad]; actual desired pose not specified";
  parameter Real J_eff = 1.0 "effective crank inertia [kg.m^2], not specified; unit placeholder";
  parameter Real b_eff = 0.5 "viscous damping [N.m.s/rad], not specified; placeholder";
  parameter Real Kp = 200.0 "proportional gain, not specified; placeholder";
  parameter Real Kd = 30.0 "derivative gain, not specified; placeholder";
  parameter Real thetaMax = Modelica.Constants.pi "actuator travel limit [rad], not specified; placeholder";
  parameter Real closureTol = 1.0e-6 "closure residual tolerance [m]";
  parameter Real collisionClearance = 1.0e-3 "self-collision clearance [m], not specified; placeholder";
  parameter Real finiteLimit = 1.0e30 "finite-value bound for NaN/infinite checks";

  // Inverse-kinematics setpoint derived from the chosen nominal crank angle.
  parameter Real x_set = platformX(theta_ref_nominal,L0,L2,L3,L4,branchSign);
  parameter Real y_set = platformY(theta_ref_nominal,L0,L2,L3,L4,branchSign);

  // Continuous plant states.
  Real theta(start=theta0, fixed=true) "crank angle [rad]";
  Real omega(start=0.0, fixed=true) "crank angular velocity [rad/s]";

  // Forward kinematics and sensors.
  Real Bx "crank end x [m]";
  Real By "crank end y [m]";
  Real Cx "coupler/rocker joint x [m]";
  Real Cy "coupler/rocker joint y [m]";
  Real phi3 "coupler absolute angle [rad]";
  Real phi4 "rocker absolute angle [rad]";
  Real res1 "coupler closure residual [m]";
  Real res2 "rocker closure residual [m]";
  Real closureResidual "loop closure residual norm [m]";
  Real Px "output platform x [m]";
  Real Py "output platform y [m]";
  Real poseAngle "output platform angle [rad]";

  // Constrained inverse kinematics for desired pose.
  Real theta_ref(start=theta_ref_nominal) "inverse-kinematics crank setpoint [rad]";
  Real Px_ref "desired platform x [m]";
  Real Py_ref "desired platform y [m]";
  Real phi3_ref "desired platform angle [rad]";
  Real phi4_ref "desired rocker angle [rad]";
  Real closureRef "desired loop closure residual [m]";
  Real inverseResidual "inverse-kinematics residual [m^2]";

  // Kinematic Jacobian for generalized load mapping.
  Real den;
  Real denSafe;
  Real phi3d "dphi3/dtheta";
  Real phi4d "dphi4/dtheta";
  Real dPx "dPx/dtheta [m/rad]";
  Real dPy "dPy/dtheta [m/rad]";

  // Tracking errors.
  Real poseError "primary pose error [m]";
  Real orientationError "platform angle error [rad]";

  // Load disturbance.
  Real loadActive;
  Real Fx_load "platform load x [N]";
  Real Fy_load "platform load y [N]";
  Real Q_load "generalized load torque [N.m]";

  // Controller command.
  discrete Real tau_cmd(start=0.0) "sampled crank command [N.m]";
  Real tau_motor "applied bounded crank torque [N.m]";

  // Reaction force estimates (quasi-static, massless-strut approximation).
  Real FBx "crank-coupler joint force x [N]";
  Real FBy "crank-coupler joint force y [N]";
  Real FCx "rocker-coupler joint force x [N]";
  Real FCy "rocker-coupler joint force y [N]";
  Real FAx "fixed pivot A reaction x [N]";
  Real FAy "fixed pivot A reaction y [N]";
  Real FDx "fixed pivot D reaction x [N]";
  Real FDy "fixed pivot D reaction y [N]";

  // Self-collision checks between non-adjacent links.
  Real minDistCrankRocker "minimum crank-rocker distance [m]";
  Real minDistCouplerGround "minimum coupler-ground distance [m]";
  Real minDist "minimum non-adjacent link distance [m]";

  // Explicit sensor variables.
  Real sensorActuatorAngle;
  Real sensorActuatorVelocity;
  Real sensorOutputX;
  Real sensorOutputY;
  Real sensorOutputAngle;

  // Requirement checks.
  Boolean closureOK;
  Boolean inverseKinematicsOK;
  Boolean forceBoundOK;
  Boolean travelBoundOK;
  Boolean noCollisionOK;
  Boolean finiteOK;
  Boolean trackingOK;
  Boolean allOK;

  // Synchronized 125 Hz traces.
  discrete Real time_trace(start=0.0);
  discrete Real theta_trace(start=theta0);
  discrete Real omega_trace(start=0.0);
  discrete Real tau_trace(start=0.0);
  discrete Real poseError_trace(start=0.0);
  discrete Real closure_trace(start=0.0);
  discrete Real minDist_trace(start=1.0);
  discrete Real FAx_trace(start=0.0);
  discrete Real FAy_trace(start=0.0);
  discrete Real FDx_trace(start=0.0);
  discrete Real FDy_trace(start=0.0);

equation
  // Closed-chain forward kinematics for the four revolute Z joints.
  (Bx,By,Cx,Cy,phi3,phi4,res1,res2) = fourbar_solve(theta,L0,L2,L3,L4,branchSign);
  Px = 0.5*(Bx + Cx);
  Py = 0.5*(By + Cy);
  poseAngle = phi3;
  closureResidual = Modelica.Math.sqrt(res1*res1 + res2*res2);

  // Constrained inverse kinematics: solve crank angle for desired platform pose.
  (Px_ref,Py_ref,phi3_ref,phi4_ref,closureRef) = fourbar_platform(theta_ref,L0,L2,L3,L4,branchSign);
  inverseResidual = (Px_ref - x_set)*(Px_ref - x_set) + (Py_ref - y_set)*(Py_ref - y_set);
  inverseResidual = 0.0;

  poseError = Modelica.Math.sqrt((Px - Px_ref)*(Px - Px_ref) + (Py - Py_ref)*(Py - Py_ref));
  orientationError = abs(Modelica.Math.wrapAngle(phi3 - phi3_ref));

  // Closure-constrained Jacobian.
  den = Modelica.Math.sin(phi4 - phi3);
  denSafe = if noEvent(abs(den) > 1.0e-6) then den else 1.0e-6;
  phi3d = -(L2/L3)*Modelica.Math.sin(phi4 - theta)/denSafe;
  phi4d = -(L2/L4)*Modelica.Math.sin(phi3 - theta)/denSafe;
  dPx = -L2*Modelica.Math.sin(theta) + 0.5*L3*phi3d*(-Modelica.Math.sin(phi3));
  dPy = L2*Modelica.Math.cos(theta) + 0.5*L3*phi3d*(Modelica.Math.cos(phi3));

  // Controlled 12.6 N platform load during the middle third of the run.
  loadActive = if noEvent(time >= loadStart and time <= loadEnd) then 1.0 else 0.0;
  Fx_load = 0.0;
  Fy_load = -loadActive*loadMag;
  Q_load = Fx_load*dPx + Fy_load*dPy;

  // Single-DOF closed-chain dynamics driven by bounded crank torque.
  der(theta) = omega;
  J_eff*der(omega) = tau_motor - Q_load - b_eff*omega;

  // 125 Hz sampled pose-feedback controller with command saturation.
  when sample(0,Ts) then
    tau_cmd = max(-tauMax, min(tauMax, Kp*(theta_ref - theta) - Kd*omega));
    time_trace = time;
    theta_trace = theta;
    omega_trace = omega;
    tau_trace = tau_cmd;
    poseError_trace = poseError;
    closure_trace = closureResidual;
    minDist_trace = minDist;
    FAx_trace = FAx;
    FAy_trace = FAy;
    FDx_trace = FDx;
    FDy_trace = FDy;
  end when;
  tau_motor = tau_cmd;

  // Quasi-static reaction force sensors.
  FBx = (tau_motor/L2)*(-Modelica.Math.sin(theta));
  FBy = (tau_motor/L2)*(Modelica.Math.cos(theta));
  FCx = Fx_load - FBx;
  FCy = Fy_load - FBy;
  FAx = -FBx;
  FAy = -FBy;
  FDx = -FCx;
  FDy = -FCy;

  // Self-collision checks for non-adjacent links; adjacent revolute pairs are excluded.
  minDistCrankRocker = segmentDistance(0.0,0.0,Bx,By,L0,0.0,Cx,Cy);
  minDistCouplerGround = segmentDistance(Bx,By,Cx,Cy,0.0,0.0,L0,0.0);
  minDist = min(minDistCrankRocker, minDistCouplerGround);

  // Explicit instrumentation.
  sensorActuatorAngle = theta;
  sensorActuatorVelocity = omega;
  sensorOutputX = Px;
  sensorOutputY = Py;
  sensorOutputAngle = poseAngle;

  // Requirement assertions.
  closureOK = closureResidual <= closureTol;
  inverseKinematicsOK = inverseResidual <= 1.0e-8 and closureRef <= closureTol;
  forceBoundOK = abs(tau_motor) <= tauMax + 1.0e-9;
  travelBoundOK = abs(theta) <= thetaMax + 1.0e-9;
  noCollisionOK = minDist > collisionClearance;
  trackingOK = if time >= trackingTime then poseError <= trackingTol else true;
  finiteOK = abs(theta) <= finiteLimit and
             abs(omega) <= finiteLimit and
             abs(theta_ref) <= finiteLimit and
             abs(tau_motor) <= finiteLimit and
             abs(Px) <= finiteLimit and
             abs(Py) <= finiteLimit and
             abs(poseAngle) <= finiteLimit and
             abs(Px_ref) <= finiteLimit and
             abs(Py_ref) <= finiteLimit and
             abs(phi3_ref) <= finiteLimit and
             abs(phi4_ref) <= finiteLimit and
             abs(closureRef) <= finiteLimit and
             abs(inverseResidual) <= finiteLimit and
             abs(Q_load) <= finiteLimit and
             abs(FBx) <= finiteLimit and
             abs(FBy) <= finiteLimit and
             abs(FCx) <= finiteLimit and
             abs(FCy) <= finiteLimit and
             abs(FAx) <= finiteLimit and
             abs(FAy) <= finiteLimit and
             abs(FDx) <= finiteLimit and
             abs(FDy) <= finiteLimit and
             abs(closureResidual) <= finiteLimit and
             abs(minDist) <= finiteLimit and
             abs(poseError) <= finiteLimit and
             abs(orientationError) <= finiteLimit and
             abs(phi3d) <= finiteLimit and
             abs(phi4d) <= finiteLimit;
  allOK = closureOK and inverseKinematicsOK and forceBoundOK and travelBoundOK and noCollisionOK and finiteOK and trackingOK;

  annotation (experiment(StopTime=12, Interval=0.008, Tolerance=1.0e-6));
end FourBarPositionC;