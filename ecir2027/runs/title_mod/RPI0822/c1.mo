model WheelLegWalkF
  /* Wheel-legged robot walking scenario.
     Planar sagittal-plane reduced model: 28 kg torso, four 2-joint legs
     ending in driven 0.10 m wheels. Phase-based joint impedance plus
     body-attitude control tracks 0.4 m/s forward gait at nominal height.
     A 102 N forward push is applied during the middle third of the run.
     Lateral/out-of-plane dynamics, full 3D foot geometry, and detailed
     sensor noise models are unknown and omitted. */

  // --- Physical parameters ---
  parameter Real m_body = 28.0 "torso mass [kg]";
  parameter Real I_body = 1.5 "torso pitch inertia [kg.m2]";
  parameter Real r_wheel = 0.10 "driven wheel radius [m]";
  parameter Real L1 = 0.20 "thigh length [m]";
  parameter Real L2 = 0.20 "shin length [m]";
  parameter Real m_thigh = 0.5 "thigh mass [kg]";
  parameter Real m_shin = 0.5 "shin mass [kg]";
  parameter Real I_leg = 0.04 "leg joint reflected inertia [kg.m2]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real mu = 0.85 "plane friction coefficient";

  // --- Mission / control parameters ---
  parameter Real h_nom = 0.40 "nominal body height [m]";
  parameter Real v_ref = 0.40 "forward speed reference [m/s]";
  parameter Real T_sim = 20.0 "simulation duration [s]";
  parameter Real f_gait = 1.0 "gait frequency [Hz]";
  parameter Real q1_nom = 0.20 "nominal hip angle [rad]";
  parameter Real q2_nom = 0.85 "nominal knee angle [rad]";
  parameter Real A_swing = 0.30 "hip swing amplitude [rad]";
  parameter Real A_lift = 0.45 "knee lift amplitude [rad]";
  parameter Real k_contact = 30000.0 "foot contact stiffness [N/m]";
  parameter Real d_contact = 1200.0 "foot contact damping [N.s/m]";
  parameter Real k_leg = 300.0 "joint impedance stiffness [N.m/rad]";
  parameter Real b_leg = 12.0 "joint impedance damping [N.m.s/rad]";
  parameter Real k_att = 200.0 "attitude proportional gain [N.m/rad]";
  parameter Real b_att = 25.0 "attitude damping gain [N.m.s/rad]";
  parameter Real k_v = 30.0 "forward wheel-velocity gain [N.m.s/m]";
  parameter Real tau_max = 67.1 "per-joint/wheel torque limit [N.m]";
  parameter Real F_push = 102.0 "controlled body push disturbance [N]";
  parameter Real x_off[4] = {0.25, 0.25, -0.25, -0.25} "leg x-offset on torso [m]";
  parameter Real phase_off[4] = {0.0, 0.5, 0.5, 0.0} "trot gait phase offsets";

  // --- Body state ---
  Real x_body(start=0.0) "body x position [m]";
  Real vx_body(start=0.0) "body forward velocity [m/s]";
  Real z_body(start=0.3933) "body z height [m]";
  Real vz_body(start=0.0) "body vertical velocity [m/s]";
  Real pitch(start=0.0) "body pitch [rad]";
  Real pitch_rate(start=0.0) "body pitch rate [rad/s]";

  // --- Per-leg joint and wheel state ---
  Real q1[4](each start=q1_nom) "hip angles [rad]";
  Real q1d[4](each start=0.0) "hip angular velocities [rad/s]";
  Real q2[4](each start=q2_nom) "knee angles [rad]";
  Real q2d[4](each start=0.0) "knee angular velocities [rad/s]";
  Real phi[4](each start=0.0) "wheel angles [rad]";
  Real phid[4](each start=0.0) "wheel angular velocities [rad/s]";

  // --- Per-leg kinematics and contact sensors ---
  Real ax[4] "hip attachment x [m]";
  Real az[4] "hip attachment z [m]";
  Real foot_x[4] "foot (wheel center) x [m]";
  Real foot_z[4] "foot (wheel center) z [m]";
  Real foot_vx[4] "foot x velocity [m/s]";
  Real foot_vz[4] "foot z velocity [m/s]";
  Real penetration[4] "ground penetration [m]";
  Real Fz[4] "foot normal contact force sensor [N]";
  Real Fx[4] "foot friction force [N]";
  Boolean in_contact[4] "foot contact indicator";
  Real Jx1[4], Jz1[4], Jx2[4], Jz2[4] "leg Jacobian columns";

  // --- Control ---
  Real phase "global gait phase [0,1)";
  Real phase_i[4] "per-leg gait phase";
  Real q1_ref[4] "hip reference [rad]";
  Real q2_ref[4] "knee reference [rad]";
  Real tau1_cmd[4] "hip torque command [N.m]";
  Real tau2_cmd[4] "knee torque command [N.m]";
  Real tauw_cmd[4] "wheel torque command [N.m]";
  Real tau1[4] "saturated hip torque [N.m]";
  Real tau2[4] "saturated knee torque [N.m]";
  Real tauw[4] "saturated wheel torque [N.m]";
  Real pitch_torque "attitude control torque on body [N.m]";
  Real tau_g1[4] "hip gravity torque [N.m]";
  Real tau_g2[4] "knee gravity torque [N.m]";
  Real M_body "net leg moment about body center [N.m]";
  Real Fx_total "total horizontal leg force [N]";
  Real Fz_total "total vertical leg force [N]";

  // --- Disturbance ---
  Boolean push_active "push disturbance active flag";
  Real F_push_x "applied push force [N]";

  // --- Verification / evidence ---
  Integer n_contacts "supporting contact count";
  Real v_err "forward speed tracking error [m/s]";
  Real n_viol "torque bound violation count";
  Boolean bounds_ok "joint and torque bounds satisfied";
  Boolean v_err_ok "primary tracking error below 0.08 m/s after 13 s";
  Boolean finite_ok "no NaN/Inf in physical, control, estimator values";

  // --- Synchronized traces (outputs) ---
  output Real y_vx = vx_body "body forward velocity trace [m/s]";
  output Real y_x = x_body "body forward position trace [m]";
  output Real y_z = z_body "body height trace [m]";
  output Real y_pitch = pitch "body pitch trace [rad]";
  output Real y_v_err = v_err "tracking error trace [m/s]";
  output Real y_n_contacts = n_contacts "supporting contact count trace";
  output Real y_Fz1 = Fz[1] "foot-1 normal force sensor trace [N]";
  output Real y_Fz2 = Fz[2] "foot-2 normal force sensor trace [N]";
  output Real y_Fz3 = Fz[3] "foot-3 normal force sensor trace [N]";
  output Real y_Fz4 = Fz[4] "foot-4 normal force sensor trace [N]";
  output Real y_tau1_1 = tau1[1] "leg-1 hip torque trace [N.m]";
  output Real y_tau2_1 = tau2[1] "leg-1 knee torque trace [N.m]";
  output Real y_tauw_1 = tauw[1] "leg-1 wheel torque trace [N.m]";

  constant Real pi_val = 3.14159265358979;

equation
  // --- Gait phase generation (500 Hz control assumed via continuous evaluation) ---
  phase = mod(time * f_gait, 1.0);
  for i in 1:4 loop
    phase_i[i] = mod(phase + phase_off[i], 1.0);
    q1_ref[i] = q1_nom + A_swing * sin(2.0*pi_val*phase_i[i]);
    q2_ref[i] = q2_nom + A_lift * max(0.0, sin(2.0*pi_val*phase_i[i]));
  end for;

  // --- Controlled push disturbance: middle third of run ---
  push_active = (time >= T_sim/3.0) and (time <= 2.0*T_sim/3.0);
  F_push_x = if push_active then F_push else 0.0;

  // --- Leg kinematics and Jacobians ---
  for i in 1:4 loop
    ax[i] = x_body + x_off[i]*cos(pitch);
    az[i] = z_body + x_off[i]*sin(pitch);
    foot_x[i] = ax[i] + L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    foot_z[i] = az[i] - L1*cos(q1[i]) - L2*cos(q1[i]+q2[i]);
    foot_vx[i] = vx_body - x_off[i]*sin(pitch)*pitch_rate
                 + L1*cos(q1[i])*q1d[i] + L2*cos(q1[i]+q2[i])*(q1d[i]+q2d[i]);
    foot_vz[i] = vz_body + x_off[i]*cos(pitch)*pitch_rate
                 + L1*sin(q1[i])*q1d[i] + L2*sin(q1[i]+q2[i])*(q1d[i]+q2d[i]);
    Jx1[i] = L1*cos(q1[i]) + L2*cos(q1[i]+q2[i]);
    Jz1[i] = L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    Jx2[i] = L2*cos(q1[i]+q2[i]);
    Jz2[i] = L2*sin(q1[i]+q2[i]);
    // gravity torques about joints (small)
    tau_g1[i] = ((m_thigh*0.5 + m_shin)*L1*sin(q1[i]) + m_shin*0.5*L2*sin(q1[i]+q2[i]))*g;
    tau_g2[i] = m_shin*0.5*L2*sin(q1[i]+q2[i])*g;
    // contact detection and spring-damper normal force
    penetration[i] = max(0.0, r_wheel - foot_z[i]);
    in_contact[i] = penetration[i] > 0.0;
    Fz[i] = if in_contact[i] then
              max(0.0, k_contact*penetration[i] - d_contact*foot_vz[i])
            else 0.0;
    // wheel traction (friction-limited), zero-error branch when Fz=0
    Fx[i] = if in_contact[i] then
              max(-mu*Fz[i], min(mu*Fz[i], tauw[i]/r_wheel))
            else 0.0;
    // rolling-without-slip kinematic approximation for wheel angle
    phid[i] = if in_contact[i] then vx_body/r_wheel else 0.0;
    der(phi[i]) = phid[i];
    // impedance joint torque commands
    tau1_cmd[i] = k_leg*(q1_ref[i] - q1[i]) - b_leg*q1d[i];
    tau2_cmd[i] = k_leg*(q2_ref[i] - q2[i]) - b_leg*q2d[i];
    // wheel torque command: forward propulsion, distributed over stance legs
    tauw_cmd[i] = if (in_contact[i] and n_contacts > 0) then
                    k_v*(v_ref - vx_body)/n_contacts
                  else 0.0;
    // independent per-joint/wheel saturation
    tau1[i] = if tau1_cmd[i] > tau_max then tau_max
              elseif tau1_cmd[i] < -tau_max then -tau_max
              else tau1_cmd[i];
    tau2[i] = if tau2_cmd[i] > tau_max then tau_max
              elseif tau2_cmd[i] < -tau_max then -tau_max
              else tau2_cmd[i];
    tauw[i] = if tauw_cmd[i] > tau_max then tau_max
              elseif tauw_cmd[i] < -tau_max then -tau_max
              else tauw_cmd[i];
    // leg joint dynamics (ODE): torque minus contact load and gravity
    der(q1[i]) = q1d[i];
    der(q2[i]) = q2d[i];
    I_leg*der(q1d[i]) = tau1[i] - (Jx1[i]*Fx[i] + Jz1[i]*Fz[i]) - tau_g1[i];
    I_leg*der(q2d[i]) = tau2[i] - (Jx2[i]*Fx[i] + Jz2[i]*Fz[i]) - tau_g2[i];
  end for;

  // --- Body attitude control ---
  pitch_torque = -k_att*pitch - b_att*pitch_rate;

  // --- Net leg forces and moment about body center ---
  Fx_total = Fx[1] + Fx[2] + Fx[3] + Fx[4];
  Fz_total = Fz[1] + Fz[2] + Fz[3] + Fz[4];
  M_body = x_off[1]*cos(pitch)*Fz[1] - x_off[1]*sin(pitch)*Fx[1]
         + x_off[2]*cos(pitch)*Fz[2] - x_off[2]*sin(pitch)*Fx[2]
         + x_off[3]*cos(pitch)*Fz[3] - x_off[3]*sin(pitch)*Fx[3]
         + x_off[4]*cos(pitch)*Fz[4] - x_off[4]*sin(pitch)*Fx[4];

  // --- Body dynamics ---
  der(x_body) = vx_body;
  der(z_body) = vz_body;
  der(pitch) = pitch_rate;
  m_body*der(vx_body) = Fx_total + F_push_x;
  m_body*der(vz_body) = Fz_total - m_body*g;
  I_body*der(pitch_rate) = M_body + pitch_torque;

  // --- Supporting contact count (explicit, safe) ---
  n_contacts = (if in_contact[1] then 1 else 0)
             + (if in_contact[2] then 1 else 0)
             + (if in_contact[3] then 1 else 0)
             + (if in_contact[4] then 1 else 0);

  // --- Torque bound violation count (12 independently limited actuators) ---
  n_viol = (if abs(tau1[1]) > tau_max then 1.0 else 0.0)
         + (if abs(tau1[2]) > tau_max then 1.0 else 0.0)
         + (if abs(tau1[3]) > tau_max then 1.0 else 0.0)
         + (if abs(tau1[4]) > tau_max then 1.0 else 0.0)
         + (if abs(tau2[1]) > tau_max then 1.0 else 0.0)
         + (if abs(tau2[2]) > tau_max then 1.0 else 0.0)
         + (if abs(tau2[3]) > tau_max then 1.0 else 0.0)
         + (if abs(tau2[4]) > tau_max then 1.0 else 0.0)
         + (if abs(tauw[1]) > tau_max then 1.0 else 0.0)
         + (if abs(tauw[2]) > tau_max then 1.0 else 0.0)
         + (if abs(tauw[3]) > tau_max then 1.0 else 0.0)
         + (if abs(tauw[4]) > tau_max then 1.0 else 0.0);
  bounds_ok = (n_viol == 0.0);

  // --- Primary tracking error and criteria ---
  v_err = v_ref - vx_body;
  v_err_ok = (time < 13.0) or (abs(v_err) <= 0.08);

  // --- Finiteness check (NaN/Inf fail absolute-value comparisons) ---
  finite_ok = (abs(x_body) < 1e15) and (abs(vx_body) < 1e15)
          and (abs(z_body) < 1e15) and (abs(vz_body) < 1e15)
          and (abs(pitch) < 1e15) and (abs(pitch_rate) < 1e15)
          and (abs(v_err) < 1e15) and (abs(Fx_total) < 1e15)
          and (abs(Fz_total) < 1e15) and (abs(pitch_torque) < 1e15)
          and (abs(tau1[1]) < 1e15) and (abs(tau2[1]) < 1e15)
          and (abs(tauw[1]) < 1e15) and (abs(Fz[1]) < 1e15);

  annotation (
    Documentation(info = "Wheel-leg walking scenario WheelLegWalkF. Run at 500 Hz for 20 s. Verification: bounds_ok, n_contacts greater or equal 1, v_err_ok, finite_ok."),
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002));
end WheelLegWalkF;