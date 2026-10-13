model WheelLegWalkA
  // ===== Physical parameters =====
  parameter Real m_body(unit="kg") = 28.0 "torso mass";
  parameter Real I_body(unit="kg.m2") = 1.6 "torso pitch inertia";
  parameter Real g(unit="m/s2") = 9.81 "gravity";
  parameter Real mu = 0.85 "ground friction coefficient";
  parameter Real L_thigh(unit="m") = 0.25 "thigh length";
  parameter Real L_shank(unit="m") = 0.25 "shank length";
  parameter Real r_wheel(unit="m") = 0.10 "driven wheel radius";
  parameter Real I_joint(unit="kg.m2") = 0.05 "reflected joint inertia";
  parameter Real b_joint(unit="N.m.s/rad") = 0.30 "joint viscous friction";
  parameter Real k_gr(unit="N/m") = 20000.0 "rigid-plane vertical stiffness";
  parameter Real d_gr(unit="N.s/m") = 400.0 "rigid-plane vertical damping";

  // ===== Gait / control parameters =====
  parameter Real z_ref(unit="m") = 0.45 "nominal body height";
  parameter Real vx_ref(unit="m/s") = 0.40 "forward gait speed";
  parameter Real tau_max(unit="N.m") = 39.6 "per-joint command magnitude limit";
  parameter Real F_push(unit="N") = 35.0 "body push disturbance";
  parameter Real T_gait(unit="s") = 1.20 "gait period";
  parameter Real A_gait(unit="rad") = 0.12 "hip gait amplitude";
  parameter Real B_gait(unit="rad") = -0.18 "knee gait amplitude";
  parameter Real q1_nom(unit="rad") = 0.50 "nominal hip angle";
  parameter Real q2_nom(unit="rad") = -0.90 "nominal knee angle";
  parameter Real k_imp(unit="N.m/rad") = 80.0 "joint impedance stiffness";
  parameter Real d_imp(unit="N.m.s/rad") = 2.0 "joint impedance damping";
  parameter Real k_vert(unit="N/m") = 1200.0 "body-height stiffness";
  parameter Real d_vert(unit="N.s/m") = 80.0 "body-height damping";
  parameter Real k_att(unit="N.m/rad") = 300.0 "body-attitude stiffness";
  parameter Real d_att(unit="N.m.s/rad") = 25.0 "body-attitude damping";
  parameter Real K_w(unit="N.s/m") = 100.0 "wheel tractive gain on speed error";
  parameter Real F_contact_thresh(unit="N") = 2.0 "contact detection threshold";
  parameter Real hip_x[4](each unit="m") = {-0.22, -0.07, 0.07, 0.22} "hip x offsets from CoM";
  parameter Real phase_off[4](each unit="rad") = {0.0, 1.5708, 3.1416, 4.7124} "per-leg gait phase offsets";

  // ===== Floating-base states =====
  Real x(unit="m", start=0.0, fixed=true) "forward position";
  Real vx(unit="m/s", start=0.0, fixed=true) "forward velocity";
  Real z(unit="m", start=0.45, fixed=true) "body height";
  Real vz(unit="m/s", start=0.0, fixed=true) "vertical velocity";
  Real theta(unit="rad", start=0.0, fixed=true) "pitch";
  Real omega(unit="rad/s", start=0.0, fixed=true) "pitch rate";

  // ===== Leg joint states (4 legs x 2 joints) =====
  Real q1[4](each unit="rad", each start=0.50, each fixed=true) "hip angles";
  Real q2[4](each unit="rad", each start=-0.90, each fixed=true) "knee angles";
  Real dq1[4](each unit="rad/s", each start=0.0, each fixed=true) "hip rates";
  Real dq2[4](each unit="rad/s", each start=0.0, each fixed=true) "knee rates";

  // ===== Wheel encoder states (kinematic rolling) =====
  Real ph_w[4](each unit="rad", each start=0.0, each fixed=true) "wheel angles";
  Real dw[4](each unit="rad/s") "wheel angular rates";

  // ===== Sensors =====
  Real foot_x[4](each unit="m") "foot x position";
  Real foot_z[4](each unit="m") "foot z position";
  Real vz_foot[4](each unit="m/s") "foot vertical velocity";
  Real Fz_leg[4](each unit="N") "vertical contact force per leg (up on body)";
  Real Fx_leg[4](each unit="N") "horizontal traction per leg (forward on body)";
  Real F_contact[4](each unit="N") "foot contact-force sensor";
  Real cflag[4] "per-leg contact flag as Real";
  Real N_contact "supporting-contact count";
  Real IMU_pitch(unit="rad") "torso IMU pitch";
  Real IMU_pitch_rate(unit="rad/s") "torso IMU pitch rate";
  Real enc1[4](each unit="rad") "hip encoder";
  Real enc2[4](each unit="rad") "knee encoder";
  Real encw[4](each unit="rad") "wheel encoder";

  // ===== Commands / torques =====
  Real phase[4](each unit="rad") "gait phase";
  Real q1_ref[4](each unit="rad") "hip reference";
  Real q2_ref[4](each unit="rad") "knee reference";
  Real Fz_target[4](each unit="N") "per-leg vertical force target";
  Real Jz1[4] "dz/dq1";
  Real Jz2[4] "dz/dq2";
  Real tau1_cmd[4](each unit="N.m") "hip torque command (pre-limit)";
  Real tau2_cmd[4](each unit="N.m") "knee torque command (pre-limit)";
  Real tau1[4](each unit="N.m") "hip torque (limited)";
  Real tau2[4](each unit="N.m") "knee torque (limited)";
  Real tau_leg[8](each unit="N.m") "all eight leg torques (limited)";
  Real tau_wheel_cmd[4](each unit="N.m") "wheel torque command (pre-limit)";
  Real tau_wheel[4](each unit="N.m") "wheel torque (limited)";
  Real dw_ref(unit="rad/s") "wheel rate reference";

  // ===== Disturbance / monitoring =====
  Real push_force(unit="N") "applied push disturbance";
  Real height_err(unit="m") "body height error";
  Real pitch_err(unit="rad") "body pitch error";
  Real tracking_error(unit="m/s") "forward speed tracking error";
  Boolean valid "finite-range validity flag";

  // ===== Aggregates =====
  Real sum_Fz(unit="N");
  Real sum_Fx(unit="N");
  Real sum_Mpitch(unit="N.m");

  // ===== Intermediate for contact sum =====
  Real cflag_sum;

equation
  // ---- Floating-base kinematics ----
  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;

  // ---- Wheel rate reference ----
  dw_ref = vx_ref / r_wheel;

  // ---- Per-leg equations ----
  for i in 1:4 loop
    // foot kinematics (sagittal, small-pitch linearization)
    foot_x[i] = x + hip_x[i] + L_thigh*sin(q1[i]) + L_shank*sin(q1[i] + q2[i]);
    foot_z[i] = z - L_thigh*cos(q1[i]) - L_shank*cos(q1[i] + q2[i]);
    vz_foot[i] = vz + L_thigh*sin(q1[i])*dq1[i] + L_shank*sin(q1[i] + q2[i])*(dq1[i] + dq2[i]);

    // rigid-plane contact: normal force (up on body) with well-defined zero branch
    Fz_leg[i] = if foot_z[i] < 0.0 then (k_gr*(-foot_z[i]) + d_gr*(-vz_foot[i])) else 0.0;

    // phase-based gait references
    phase[i] = 2.0*Modelica.Constants.pi/T_gait*time + phase_off[i];
    q1_ref[i] = q1_nom + A_gait*sin(phase[i]);
    q2_ref[i] = q2_nom + B_gait*sin(phase[i]);

    // vertical Jacobian columns
    Jz1[i] = L_thigh*sin(q1[i]) + L_shank*sin(q1[i] + q2[i]);
    Jz2[i] = L_shank*sin(q1[i] + q2[i]);

    // per-leg vertical force target: weight share + height feedback + attitude feedback
    Fz_target[i] = (m_body*g)/4.0 + k_vert*(z_ref - z)/4.0 + d_vert*(-vz)/4.0 + k_att*theta*hip_x[i] + d_att*omega*hip_x[i];

    // joint torque command: Jacobian-transpose stance + phase impedance
    tau1_cmd[i] = Fz_target[i]*Jz1[i] + k_imp*(q1_ref[i] - q1[i]) + d_imp*(-dq1[i]);
    tau2_cmd[i] = Fz_target[i]*Jz2[i] + k_imp*(q2_ref[i] - q2[i]) + d_imp*(-dq2[i]);

    // independent torque saturation (8 leg torques)
    tau1[i] = if tau1_cmd[i] > tau_max then tau_max else if tau1_cmd[i] < -tau_max then -tau_max else tau1_cmd[i];
    tau2[i] = if tau2_cmd[i] > tau_max then tau_max else if tau2_cmd[i] < -tau_max then -tau_max else tau2_cmd[i];

    // wheel torque command (speed regulation), independently saturated
    tau_wheel_cmd[i] = K_w*(vx_ref - vx)*r_wheel;
    tau_wheel[i] = if tau_wheel_cmd[i] > tau_max then tau_max else if tau_wheel_cmd[i] < -tau_max then -tau_max else tau_wheel_cmd[i];

    // tractive force on body, friction-limited (zero branch when airborne)
    Fx_leg[i] = if foot_z[i] < 0.0 then (if tau_wheel[i]/r_wheel > mu*Fz_leg[i] then mu*Fz_leg[i] else if tau_wheel[i]/r_wheel < -mu*Fz_leg[i] then -mu*Fz_leg[i] else tau_wheel[i]/r_wheel) else 0.0;

    // contact-force sensor
    F_contact[i] = Fz_leg[i];
    cflag[i] = if Fz_leg[i] > F_contact_thresh then 1.0 else 0.0;

    // joint dynamics
    der(q1[i]) = dq1[i];
    der(q2[i]) = dq2[i];
    I_joint*der(dq1[i]) = tau1[i] - b_joint*dq1[i];
    I_joint*der(dq2[i]) = tau2[i] - b_joint*dq2[i];

    // kinematic rolling for wheel encoder (no-slip assumption)
    dw[i] = vx / r_wheel;
    der(ph_w[i]) = dw[i];

    // encoder readings
    enc1[i] = q1[i];
    enc2[i] = q2[i];
    encw[i] = ph_w[i];
  end for;

  // ---- Aggregate leg-torque vector (8) ----
  for i in 1:4 loop
    tau_leg[i] = tau1[i];
    tau_leg[i + 4] = tau2[i];
  end for;

  // ---- Sums ----
  sum_Fz = Fz_leg[1] + Fz_leg[2] + Fz_leg[3] + Fz_leg[4];
  sum_Fx = Fx_leg[1] + Fx_leg[2] + Fx_leg[3] + Fx_leg[4];
  sum_Mpitch = -(hip_x[1]*Fz_leg[1] + hip_x[2]*Fz_leg[2] + hip_x[3]*Fz_leg[3] + hip_x[4]*Fz_leg[4]) - z*(Fx_leg[1] + Fx_leg[2] + Fx_leg[3] + Fx_leg[4]);

  // ---- Floating-base dynamics ----
  der(vx) = (sum_Fx + push_force) / m_body;
  der(vz) = (sum_Fz - m_body*g) / m_body;
  der(omega) = sum_Mpitch / I_body;

  // ---- Push disturbance: middle third of 8 s (2.667 s .. 5.333 s) ----
  push_force = if time > 8.0/3.0 and time < 16.0/3.0 then F_push else 0.0;

  // ---- IMU readings ----
  IMU_pitch = theta;
  IMU_pitch_rate = omega;

  // ---- Supporting-contact count ----
  cflag_sum = cflag[1] + cflag[2] + cflag[3] + cflag[4];
  N_contact = cflag_sum;

  // ---- Errors / monitoring ----
  height_err = z_ref - z;
  pitch_err = -theta;
  tracking_error = abs(vx - vx_ref);

  // ---- Finite-range validity (no NaN/Inf proxy) ----
  valid = (abs(x) < 1.0e4) and (abs(vx) < 1.0e3) and (abs(z) < 1.0e2) and (abs(vz) < 1.0e3) and (abs(theta) < 10.0) and (abs(omega) < 1.0e3) and (abs(sum_Fz) < 1.0e5) and (abs(sum_Fx) < 1.0e5) and (abs(tau1[1]) <= tau_max) and (abs(tau2[1]) <= tau_max) and (abs(tau1[2]) <= tau_max) and (abs(tau2[2]) <= tau_max) and (abs(tau1[3]) <= tau_max) and (abs(tau2[3]) <= tau_max) and (abs(tau1[4]) <= tau_max) and (abs(tau2[4]) <= tau_max) and (abs(tau_wheel[1]) <= tau_max) and (abs(tau_wheel[2]) <= tau_max) and (abs(tau_wheel[3]) <= tau_max) and (abs(tau_wheel[4]) <= tau_max);

  // ---- Bound assertions ----
  assert(abs(tau1[1]) <= tau_max + 1e-6, "hip1 torque bound violated");
  assert(abs(tau2[1]) <= tau_max + 1e-6, "knee1 torque bound violated");
  assert(abs(tau1[2]) <= tau_max + 1e-6, "hip2 torque bound violated");
  assert(abs(tau2[2]) <= tau_max + 1e-6, "knee2 torque bound violated");
  assert(abs(tau1[3]) <= tau_max + 1e-6, "hip3 torque bound violated");
  assert(abs(tau2[3]) <= tau_max + 1e-6, "knee3 torque bound violated");
  assert(abs(tau1[4]) <= tau_max + 1e-6, "hip4 torque bound violated");
  assert(abs(tau2[4]) <= tau_max + 1e-6, "knee4 torque bound violated");
  assert(abs(tau_wheel[1]) <= tau_max + 1e-6, "wheel1 torque bound violated");
  assert(abs(tau_wheel[2]) <= tau_max + 1e-6, "wheel2 torque bound violated");
  assert(abs(tau_wheel[3]) <= tau_max + 1e-6, "wheel3 torque bound violated");
  assert(abs(tau_wheel[4]) <= tau_max + 1e-6, "wheel4 torque bound violated");
  assert(valid, "physical, control, or estimator values out of finite range");

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-5, Interval=0.0125),
    Documentation(info="WheelLegWalkA: floating-base 28 kg wheeled-leg quadruped. Four 2-joint legs ending in 0.10 m driven wheels; phase-based joint impedance and body-attitude control; 35 N body push during middle third (2.667-5.333 s); 80 Hz output for 8 s; friction 0.85, gravity 9.81 m/s2. Tracks 0.4 m/s forward gait at nominal height. Synchronized state/command/sensor traces retained."));
end WheelLegWalkA;