model FourBarDriveA
  "Closed-chain four-bar mechanism with bounded PI crank-speed control"
  import SI = Modelica.Units.SI;

  function segmentDistance "Shortest distance between two planar line segments"
    input Real P0x;
    input Real P0y;
    input Real ux;
    input Real uy;
    input Real Q0x;
    input Real Q0y;
    input Real vx;
    input Real vy;
    output Real dist;
  protected
    Real a,b,c,d1,d2,det,s,t,sc,tc,dInt;
    Real P1x,P1y,Q1x,Q1y;
    Real tP0,tP1,sQ0,sQ1,tP0c,tP1c,sQ0c,sQ1c;
    Real dP0,dP1,dQ0,dQ1,tmp1,tmp2,tmp3;
    Real sq;
  algorithm
    a := ux*ux + uy*uy;
    c := vx*vx + vy*vy;
    b := ux*vx + uy*vy;
    d1 := ux*(Q0x - P0x) + uy*(Q0y - P0y);
    d2 := vx*(P0x - Q0x) + vy*(P0y - Q0y);
    det := a*c - b*b;
    if det > 1e-12 then
      s := (c*d1 + b*d2)/det;
      t := (b*d1 + a*d2)/det;
    else
      s := 0.0;
      t := 0.0;
    end if;
    sc := if s < 0.0 then 0.0 elseif s > 1.0 then 1.0 else s;
    tc := if t < 0.0 then 0.0 elseif t > 1.0 then 1.0 else t;
    sq := (P0x + sc*ux - Q0x - tc*vx)^2 + (P0y + sc*uy - Q0y - tc*vy)^2;
    dInt := if sq > 0.0 then sqrt(sq) else 0.0;
    P1x := P0x + ux;
    P1y := P0y + uy;
    Q1x := Q0x + vx;
    Q1y := Q0y + vy;

    if c > 1e-12 then
      tP0 := (vx*(P0x - Q0x) + vy*(P0y - Q0y))/c;
    else
      tP0 := 0.0;
    end if;
    tP0c := if tP0 < 0.0 then 0.0 elseif tP0 > 1.0 then 1.0 else tP0;
    sq := (P0x - Q0x - tP0c*vx)^2 + (P0y - Q0y - tP0c*vy)^2;
    dP0 := if sq > 0.0 then sqrt(sq) else 0.0;

    if c > 1e-12 then
      tP1 := (vx*(P1x - Q0x) + vy*(P1y - Q0y))/c;
    else
      tP1 := 0.0;
    end if;
    tP1c := if tP1 < 0.0 then 0.0 elseif tP1 > 1.0 then 1.0 else tP1;
    sq := (P1x - Q0x - tP1c*vx)^2 + (P1y - Q0y - tP1c*vy)^2;
    dP1 := if sq > 0.0 then sqrt(sq) else 0.0;

    if a > 1e-12 then
      sQ0 := (ux*(Q0x - P0x) + uy*(Q0y - P0y))/a;
    else
      sQ0 := 0.0;
    end if;
    sQ0c := if sQ0 < 0.0 then 0.0 elseif sQ0 > 1.0 then 1.0 else sQ0;
    sq := (Q0x - P0x - sQ0c*ux)^2 + (Q0y - P0y - sQ0c*uy)^2;
    dQ0 := if sq > 0.0 then sqrt(sq) else 0.0;

    if a > 1e-12 then
      sQ1 := (ux*(Q1x - P0x) + uy*(Q1y - P0y))/a;
    else
      sQ1 := 0.0;
    end if;
    sQ1c := if sQ1 < 0.0 then 0.0 elseif sQ1 > 1.0 then 1.0 else sQ1;
    sq := (Q1x - P0x - sQ1c*ux)^2 + (Q1y - P0y - sQ1c*uy)^2;
    dQ1 := if sq > 0.0 then sqrt(sq) else 0.0;

    tmp1 := if dInt < dP0 then dInt else dP0;
    tmp2 := if tmp1 < dP1 then tmp1 else dP1;
    tmp3 := if tmp2 < dQ0 then tmp2 else dQ0;
    dist := if tmp3 < dQ1 then tmp3 else dQ1;
  end segmentDistance;

  // Geometry from requirement
  parameter SI.Length L0=0.50 "fixed pivot separation";
  parameter SI.Length L1=0.20 "crank length";
  parameter SI.Length L2=0.44 "coupler length";
  parameter SI.Length L3=0.35 "rocker length";

  // Unspecified physical/control values; placeholders are tunable and not claimed measured
  parameter SI.Inertia J1=1.0 "unspecified actuator/crank inertia";
  parameter SI.Mass m1=0.0 "unspecified crank mass; zero means gravity not applied to crank";
  parameter SI.Mass m2=0.0 "unspecified coupler mass; zero means gravity not applied to coupler";
  parameter SI.Mass m3=0.0 "unspecified rocker mass; zero means gravity not applied to rocker";
  parameter SI.Inertia J2=0.0 "unspecified coupler inertia about COM";
  parameter SI.Inertia J3=0.0 "unspecified rocker inertia about COM";
  parameter SI.Acceleration g=Modelica.Constants.g_n "gravity magnitude";
  parameter SI.AngularVelocity w_ref=0.10 "unspecified constant input speed";
  parameter Real Kp=2.0 "PI proportional gain";
  parameter Real Ki=10.0 "PI integral gain";
  parameter SI.Angle q1_start=0.30 "unspecified initial crank angle; selected to avoid zero-clearance alignment";

  // Scenario and control timing
  parameter SI.Time t_end=8.0;
  parameter SI.Time Ts=0.0125 "80 Hz control and trace period";
  parameter SI.Time t_dist_start=t_end/3.0 "middle-third disturbance start";
  parameter SI.Time t_dist_end=2.0*t_end/3.0 "middle-third disturbance end";
  parameter SI.Torque tau_max=18.0 "command magnitude limit";
  parameter SI.Torque tau_dist_mag=4.0 "controlled load disturbance magnitude";

  // Dynamic states
  SI.Angle q1(start=q1_start) "crank/input joint angle";
  SI.AngularVelocity qd1(start=w_ref) "crank/input speed";
  SI.AngularAcceleration qdd1 "crank/input acceleration";
  SI.Length s_out(start=0.0) "cumulative output joint path length";

  // Algebraic kinematic variables
  SI.Length Bx;
  SI.Length By;
  SI.Length Cx;
  SI.Length Cy;
  SI.Length dBD;
  SI.Length dBD_safe;
  SI.Angle alpha;
  SI.Angle beta;
  Real cosBeta;
  Real cosBetaC;
  SI.Angle q2 "coupler absolute angle";
  SI.Angle q3 "rocker absolute angle";
  SI.AngularVelocity qd2;
  SI.AngularVelocity qd3;
  Real phi2;
  Real phi3;
  Real phi2p;
  Real phi3p;
  SI.Length a11;
  SI.Length a12;
  SI.Length a13;
  SI.Length a21;
  SI.Length a22;
  SI.Length a23;
  Real detKin;
  Real detKinSafe;
  SI.Length b1;
  SI.Length b2;

  // Dynamics auxiliary variables
  SI.Length v1x;
  SI.Length v1y;
  SI.Length v2x;
  SI.Length v2y;
  SI.Length v3x;
  SI.Length v3y;
  SI.Length a2x;
  SI.Length a2y;
  SI.Length a3x;
  SI.Length a3y;
  SI.Inertia M;
  SI.Inertia M_safe;
  SI.Inertia C2coef;
  SI.Inertia C3coef;
  SI.Inertia Ccoef;
  SI.Torque gravityTorque;

  // Actuator and disturbance
  SI.Torque tau_dist;
  discrete SI.Torque tau_cmd_raw(start=0.0);
  discrete SI.Torque tau_cmd(start=0.0);
  SI.Torque tau_sat;

  // Controller variables
  discrete SI.AngularVelocity e_k(start=0.0);
  discrete SI.Angle integ(start=0.0);
  discrete Integer sample_index(start=0);

  // Closure residuals
  SI.Length closure_x;
  SI.Length closure_y;
  SI.Length closure_norm_sq;
  SI.Length closure_norm;

  // Output motion
  SI.Velocity Cxdot;
  SI.Velocity Cydot;
  Real out_speed_sq;
  SI.Length output_pose_x;
  SI.Length output_pose_y;
  SI.Angle output_angle;
  SI.Length output_travel;

  // Joint references
  SI.Angle joint1_ref;
  SI.Angle joint2_ref;
  SI.Angle joint3_ref;
  SI.Angle joint4_ref;

  // Nonadjacent link collision prevention
  SI.Length r1x;
  SI.Length r1y;
  SI.Length r3x;
  SI.Length r3y;
  SI.Length clearance_cr "crank-rocker clearance";
  SI.Length clearance_cg "coupler-ground clearance";
  SI.Length min_clearance;

  // Requirement traces
  SI.AngularVelocity speed_error;
  SI.AngularVelocity speed_band;
  SI.Length primary_tracking_error;
  Real sensor_time;
  Integer sensor_sample_index;
  Boolean command_saturated;
  Boolean actuator_bound_met;
  Boolean cosBetaValid;
  Boolean detKinValid;
  Boolean collision_prevented;
  Boolean joint_refs_valid;
  Boolean closure_requirement_met;

equation
  // Four-bar kinematics, selected assembly branch (branch not specified)
  Bx = L1*cos(q1);
  By = L1*sin(q1);
  dBD = sqrt((L0 - Bx)^2 + By^2);
  dBD_safe = if dBD > 1e-12 then dBD else 1e-12;
  alpha = Modelica.Math.atan2(-By, L0 - Bx);
  cosBeta = (dBD^2 + L2^2 - L3^2)/(2.0*dBD_safe*L2);
  cosBetaC = if cosBeta < -1.0 then -1.0 elseif cosBeta > 1.0 then 1.0 else cosBeta;
  beta = Modelica.Math.acos(cosBetaC);
  q2 = alpha + beta;
  Cx = Bx + L2*cos(q2);
  Cy = By + L2*sin(q2);
  q3 = Modelica.Math.atan2(Cy, Cx - L0);

  // Loop-closure residuals
  closure_x = L1*cos(q1) + L2*cos(q2) - L3*cos(q3) - L0;
  closure_y = L1*sin(q1) + L2*sin(q2) - L3*sin(q3);
  closure_norm_sq = closure_x*closure_x + closure_y*closure_y;
  closure_norm = if closure_norm_sq > 0.0 then sqrt(closure_norm_sq) else 0.0;

  // Kinematic coefficients for the one-degree-of-freedom loop
  a11 = -L1*sin(q1);
  a12 = -L2*sin(q2);
  a13 = L3*sin(q3);
  a21 = L1*cos(q1);
  a22 = L2*cos(q2);
  a23 = -L3*cos(q3);
  detKin = a12*a23 - a13*a22;
  detKinSafe = if detKin > 1e-12 then detKin elseif detKin < -1e-12 then detKin elseif detKin >= 0.0 then 1e-12 else -1e-12;
  phi2 = (-a11*a23 + a13*a21)/detKinSafe;
  phi3 = (-a12*a21 + a11*a22)/detKinSafe;
  qd2 = phi2*qd1;
  qd3 = phi3*qd1;

  // Derivatives of kinematic coefficients
  b1 = L1*cos(q1) + L2*cos(q2)*phi2*phi2 - L3*cos(q3)*phi3*phi3;
  b2 = L1*sin(q1) + L2*sin(q2)*phi2*phi2 - L3*sin(q3)*phi3*phi3;
  phi2p = (b1*a23 - a13*b2)/detKinSafe;
  phi3p = (a12*b2 - b1*a22)/detKinSafe;

  // Velocity and acceleration coefficients for generalized inertia
  v1x = -(L1/2.0)*sin(q1);
  v1y = (L1/2.0)*cos(q1);
  v2x = -L1*sin(q1) - (L2/2.0)*sin(q2)*phi2;
  v2y = L1*cos(q1) + (L2/2.0)*cos(q2)*phi2;
  v3x = -(L3/2.0)*sin(q3)*phi3;
  v3y = (L3/2.0)*cos(q3)*phi3;

  a2x = -L1*cos(q1) + (L2/2.0)*(-cos(q2)*phi2*phi2 - sin(q2)*phi2p);
  a2y = -L1*sin(q1) + (L2/2.0)*(-sin(q2)*phi2*phi2 + cos(q2)*phi2p);
  a3x = (L3/2.0)*(-cos(q3)*phi3*phi3 - sin(q3)*phi3p);
  a3y = (L3/2.0)*(-sin(q3)*phi3*phi3 + cos(q3)*phi3p);

  // Generalized inertia, Coriolis coefficient, and gravity torque
  M = J1 + m1*(L1/2.0)^2 + J2*phi2^2 + J3*phi3^2 + m2*(v2x^2 + v2y^2) + m3*(v3x^2 + v3y^2);
  M_safe = if M > 1e-12 then M else 1e-12;
  C2coef = m2*(a2x*v2x + a2y*v2y) + J2*phi2p*phi2;
  C3coef = m3*(a3x*v3x + a3y*v3y) + J3*phi3p*phi3;
  Ccoef = C2coef + C3coef;
  gravityTorque = g*(m1*(L1/2.0)*cos(q1) + m2*(L1*cos(q1) + (L2/2.0)*cos(q2)*phi2) + m3*((L3/2.0)*cos(q3)*phi3));

  // Plant dynamics
  qdd1 = (tau_cmd + tau_dist - Ccoef*qd1*qd1 - gravityTorque)/M_safe;
  der(q1) = qd1;
  der(qd1) = qdd1;

  // Disturbance torque during middle third
  tau_dist = if time >= t_dist_start and time < t_dist_end then -tau_dist_mag else 0.0;

  // Discrete PI speed control at 80 Hz with command saturation and anti-windup
  when sample(0, Ts) then
    sample_index = pre(sample_index) + 1;
    e_k = w_ref - qd1;
    tau_cmd_raw = Kp*e_k + Ki*(pre(integ) + Ts*e_k);
    tau_cmd = if tau_cmd_raw > tau_max then tau_max elseif tau_cmd_raw < -tau_max then -tau_max else tau_cmd_raw;
    integ = if (tau_cmd_raw > tau_max and e_k > 0.0) or (tau_cmd_raw < -tau_max and e_k < 0.0) then pre(integ) else pre(integ) + Ts*e_k;
  end when;

  tau_sat = tau_cmd;

  // Output pose and travel
  Cxdot = -L1*sin(q1)*qd1 - L2*sin(q2)*qd2;
  Cydot = L1*cos(q1)*qd1 + L2*cos(q2)*qd2;
  out_speed_sq = Cxdot*Cxdot + Cydot*Cydot;
  der(s_out) = if out_speed_sq > 0.0 then sqrt(out_speed_sq) else 0.0;
  output_pose_x = Cx;
  output_pose_y = Cy;
  output_angle = q3;
  output_travel = s_out;

  // Joint references for four revolute Z joints
  joint1_ref = q1;
  joint2_ref = q2 - q1;
  joint3_ref = q3 - q2;
  joint4_ref = q3;

  // Nonadjacent link collision prevention
  r1x = L1*cos(q1);
  r1y = L1*sin(q1);
  r3x = L3*cos(q3);
  r3y = L3*sin(q3);
  clearance_cr = segmentDistance(0.0, 0.0, r1x, r1y, L0, 0.0, r3x, r3y);
  clearance_cg = segmentDistance(Bx, By, L2*cos(q2), L2*sin(q2), 0.0, 0.0, L0, 0.0);
  min_clearance = if clearance_cr < clearance_cg then clearance_cr else clearance_cg;
  collision_prevented = min_clearance > 0.0;

  // Requirement variables
  speed_error = w_ref - qd1;
  speed_band = if qd1 > w_ref then qd1 - w_ref else w_ref - qd1;
  primary_tracking_error = closure_norm;
  sensor_time = time;
  sensor_sample_index = sample_index;
  command_saturated = tau_cmd_raw > tau_max or tau_cmd_raw < -tau_max;
  actuator_bound_met = tau_cmd <= tau_max + 1e-9 and tau_cmd >= -tau_max - 1e-9;
  cosBetaValid = cosBeta >= -1.0 and cosBeta <= 1.0;
  detKinValid = detKin > 1e-9 or detKin < -1e-9;
  joint_refs_valid = cosBetaValid and detKinValid and collision_prevented;
  closure_requirement_met = noEvent(time < 5.2 or closure_norm <= 0.002);

  annotation (experiment(StopTime=8.0, Tolerance=1e-6, Interval=0.0125));
end FourBarDriveA;