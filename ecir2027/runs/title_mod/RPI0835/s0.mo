model WheelLegRecoverA
  "Floating-base wheel-leg quadruped with balance control and lateral push recovery"

  // Physical parameters (from requirement)
  parameter Real m_body(unit="kg") = 28.0 "torso mass";
  parameter Real r_wheel(unit="m") = 0.10 "driven wheel radius";
  parameter Real mu = 0.90 "ground friction coefficient";
  parameter Real tau_max(unit="N.m") = 39.6 "per-joint command torque limit";
  parameter Real dt_ctrl(unit="s") = 1.0/80.0 "controller period (80 Hz)";
  parameter Real T_sim(unit="s") = 8.0 "scenario duration";
  parameter Real F_push(unit="N") = 70.0 "lateral push force";
  parameter Real g(unit="m/s2") = 9.81 "gravitational acceleration";

  // Assumed parameters (not specified in requirement — labeled assumed)
  parameter Real I_body(unit="kg.m2") = 1.5 "assumed body inertia about roll/pitch";
  parameter Real L1(unit="m") = 0.18 "assumed thigh length";
  parameter Real L2(unit="m") = 0.18 "assumed shin length";
  parameter Real m_leg(unit="kg") = 0.80 "assumed leg segment mass";
  parameter Real I_leg(unit="kg.m2") = 0.10 "assumed leg joint inertia";
  parameter Real m_wheel(unit="kg") = 0.50 "assumed wheel mass";
  parameter Real I_wheel(unit="kg.m2") = 0.5*m_wheel*r_wheel^2 "assumed wheel inertia";
  parameter Real hw(unit="m") = 0.18 "assumed half body width";
  parameter Real hl(unit="m") = 0.22 "assumed half body length";
  parameter Real k_contact(unit="N/m") = 12000.0 "assumed contact stiffness";
  parameter Real d_contact(unit="N.s/m") = 400.0 "assumed contact damping";
  parameter Real k_fric(unit="s/m") = 400.0 "assumed friction regularization";
  parameter Real F_contact_thresh(unit="N") = 5.0 "assumed force-qualified contact threshold";

  // Controller gains (assumed)
  parameter Real kp_height(unit="N/m") = 2500.0;
  parameter Real kd_height(unit="N.s/m") = 250.0;
  parameter Real kp_roll(unit="N.m/rad") = 350.0;
  parameter Real kd_roll(unit="N.m.s/rad") = 50.0;
  parameter Real kp_pitch(unit="N.m/rad") = 350.0;
  parameter Real kd_pitch(unit="N.m.s/rad") = 50.0;
  parameter Real kp_lat(unit="N/m") = 800.0;
  parameter Real kd_lat(unit="N.s/m") = 100.0;
  parameter Real kp_fwd(unit="N/m") = 40.0;
  parameter Real kd_fwd(unit="N.s/m") = 8.0;

  // Estimator gains (assumed)
  parameter Real k_est_roll = 15.0;
  parameter Real k_est_pitch = 15.0;
  parameter Real k_est_z = 12.0;
  parameter Real k_est_y = 5.0;

  // Initial conditions (assumed)
  parameter Real q_hip_init = 0.60 "assumed initial hip angle [rad]";
  parameter Real q_knee_init = -1.20 "assumed initial knee angle [rad]";
  parameter Real h_ref(unit="m") = r_wheel + L1*cos(q_hip_init) + L2*cos(q_hip_init + q_knee_init)
    "reference body height from leg geometry";

  // Leg layout: 1=FL, 2=FR, 3=RL, 4=RR
  parameter Real sy[4] = {hw, -hw, hw, -hw} "lateral offsets";
  parameter Real sx[4] = {hl, hl, -hl, -hl} "forward offsets";

  // ===== Continuous states: floating base =====
  Real x_b(start=0, fixed=true) "body forward position [m]";
  Real y_b(start=0, fixed=true) "body lateral position [m]";
  Real z_b(start=h_ref, fixed=true) "body height [m]";
  Real roll(start=0, fixed=true) "body roll, positive=right side down [rad]";
  Real pitch(start=0, fixed=true) "body pitch, positive=nose up [rad]";
  Real vx_b(start=0, fixed=true) "forward velocity [m/s]";
  Real vy_b(start=0, fixed=true) "lateral velocity [m/s]";
  Real vz_b(start=0, fixed=true) "vertical velocity [m/s]";
  Real wroll(start=0, fixed=true) "roll rate [rad/s]";
  Real wpitch(start=0, fixed=true) "pitch rate [rad/s]";

  // ===== Continuous states: legs (4 legs x 2 joints) =====
  Real q_hip[4](each start=q_hip_init) "hip angles [rad]";
  Real q_knee[4](each start=q_knee_init) "knee angles [rad]";
  Real dq_hip[4](each start=0) "hip angular velocities [rad/s]";
  Real dq_knee[4](each start=0) "knee angular velocities [rad/s]";

  // ===== Continuous states: wheels (4 driven wheels) =====
  Real q_wheel[4](each start=0) "wheel angles [rad]";
  Real dq_wheel[4](each start=0) "wheel angular velocities [rad/s]";

  // ===== Discrete: controller commands =====
  discrete Real tau_hip_cmd[4] "commanded hip torques [N.m]";
  discrete Real tau_knee_cmd[4] "commanded knee torques [N.m]";
  discrete Real tau_wheel_cmd[4] "commanded wheel torques [N.m]";
  discrete Real ref_z(start=h_ref) "reference height [m]";
  discrete Real ref_y(start=0) "reference lateral position [m]";
  discrete Real ref_roll(start=0) "reference roll [rad]";
  discrete Real ref_pitch(start=0) "reference pitch [rad]";
  discrete Real ref_vx(start=0) "reference forward velocity [m/s]";
  discrete Integer ctrl_cnt(start=0) "controller step counter";

  // ===== Discrete: intermediate controller variables =====
  discrete Real d_F_des_z "desired vertical force [N]";
  discrete Real d_F_des_y "desired lateral force [N]";
  discrete Real d_F_des_x "desired forward force [N]";
  discrete Real d_M_des_roll "desired roll moment [N.m]";
  discrete Real d_M_des_pitch "desired pitch moment [N.m]";
  discrete Real d_F_n_des[4] "desired normal force per foot [N]";
  discrete Real d_F_fy_des[4] "desired lateral force per foot [N]";
  discrete Real d_F_fx_des[4] "desired forward force per foot [N]";

  // ===== Applied (saturated) torques =====
  Real tau_hip[4] "applied hip torques [N.m]";
  Real tau_knee[4] "applied knee torques [N.m]";
  Real tau_wheel[4] "applied wheel torques [N.m]";

  // ===== Foot kinematics =====
  Real fy_rel[4] "foot lateral offset from hip [m]";
  Real fz_rel[4] "foot vertical offset from hip [m]";
  Real foot_y[4] "foot lateral position (world) [m]";
  Real foot_z[4] "foot height (world) [m]";
  Real foot_x[4] "foot forward position (world) [m]";
  Real foot_vy[4] "foot lateral velocity [m/s]";
  Real foot_vz[4] "foot vertical velocity [m/s]";
  Real foot_vx[4] "foot forward velocity [m/s]";

  // ===== Jacobians =====
  Real J11[4], J12[4], J21[4], J22[4];

  // ===== Contact =====
  Real F_n[4] "normal contact force [N]";
  Real F_fy[4] "lateral friction force [N]";
  Real F_fx[4] "forward friction force [N]";
  Boolean stance[4] "force-qualified stance flag";
  Real slip_accum_y[4](each start=0) "accumulated lateral slip [m]";
  Real slip_accum_x[4](each start=0) "accumulated forward slip [m]";
  Real max_slip "maximum accumulated foot slip [m]";
  Real n_contact "number of contacting feet";
  Boolean any_contact "at least one foot in stance";

  // ===== Net body forces =====
  Real F_net_y, F_net_z, F_net_x;
  Real M_net_roll, M_net_pitch;

  // ===== IMU sensors =====
  Real imu_ay "lateral accelerometer [m/s2]";
  Real imu_az "vertical accelerometer [m/s2]";
  Real imu_wroll "roll rate gyro [rad/s]";
  Real imu_wpitch "pitch rate gyro [rad/s]";

  // ===== Estimator states =====
  Real est_y(start=0) "estimated lateral position [m]";
  Real est_z(start=h_ref) "estimated height [m]";
  Real est_roll(start=0) "estimated roll [rad]";
  Real est_pitch(start=0) "estimated pitch [rad]";
  Real est_vy(start=0) "estimated lateral velocity [m/s]";
  Real est_vz(start=0) "estimated vertical velocity [m/s]";
  Real kin_z "kinematic height estimate [m]";
  Real kin_roll "kinematic roll estimate [rad]";
  Real kin_pitch "kinematic pitch estimate [rad]";

  // ===== Output traces =====
  Real tracking_error "primary attitude tracking error [rad]";
  Real push_force_applied "applied lateral push [N]";
  Real body_height "body height [m]";

equation
  // ===================== FLOATING BASE DYNAMICS =====================
  der(x_b) = vx_b;
  der(y_b) = vy_b;
  der(z_b) = vz_b;
  der(roll) = wroll;
  der(pitch) = wpitch;

  // 70 N lateral push during middle third (2.667 s to 5.333 s)
  push_force_applied = if (time >= T_sim/3.0 and time < 2.0*T_sim/3.0) then F_push else 0.0;

  m_body * der(vx_b) = F_net_x;
  m_body * der(vy_b) = F_net_y + push_force_applied;
  m_body * der(vz_b) = F_net_z - m_body * g;
  I_body * der(wroll) = M_net_roll;
  I_body * der(wpitch) = M_net_pitch;

  // ===================== LEG KINEMATICS =====================
  for i in 1:4 loop
    fy_rel[i] = L1*sin(q_hip[i]) + L2*sin(q_hip[i] + q_knee[i]);
    fz_rel[i] = -(L1*cos(q_hip[i]) + L2*cos(q_hip[i] + q_knee[i]));

    foot_y[i] = y_b + sy[i] + fy_rel[i]*cos(roll);
    foot_z[i] = z_b + fz_rel[i] + sy[i]*sin(roll) + sx[i]*sin(pitch);
    foot_x[i] = x_b + sx[i];

    J11[i] = L1*cos(q_hip[i]) + L2*cos(q_hip[i] + q_knee[i]);
    J12[i] = L2*cos(q_hip[i] + q_knee[i]);
    J21[i] = L1*sin(q_hip[i]) + L2*sin(q_hip[i] + q_knee[i]);
    J22[i] = L2*sin(q_hip[i] + q_knee[i]);

    foot_vy[i] = vy_b + J11[i]*dq_hip[i] + J12[i]*dq_knee[i];
    foot_vz[i] = vz_b + J21[i]*dq_hip[i] + J22[i]*dq_knee[i] + sy[i]*wroll + sx[i]*wpitch;
    foot_vx[i] = vx_b;
  end for;

  // ===================== CONTACT MODEL (spring-damper + regularized friction) =====================
  for i in 1:4 loop
    F_n[i] = if foot_z[i] < r_wheel then
               max(k_contact*(r_wheel - foot_z[i]) - d_contact*foot_vz[i], 0.0)
             else 0.0;

    stance[i] = F_n[i] > F_contact_thresh;

    F_fy[i] = -mu * F_n[i] * tanh(k_fric * foot_vy[i]);
    F_fx[i] = -mu * F_n[i] * tanh(k_fric * (foot_vx[i] - r_wheel*dq_wheel[i]));

    der(slip_accum_y[i]) = if stance[i] then abs(foot_vy[i]) else 0.0;
    der(slip_accum_x[i]) = if stance[i] then abs(foot_vx[i] - r_wheel*dq_wheel[i]) else 0.0;
  end for;

  max_slip = max(max(slip_accum_y[1], slip_accum_y[2]),
                max(max(slip_accum_y[3], slip_accum_y[4]),
                    max(max(slip_accum_x[1], slip_accum_x[2]),
                        max(slip_accum_x[3], slip_accum_x[4]))));

  n_contact = (if stance[1] then 1.0 else 0.0) + (if stance[2] then 1.0 else 0.0)
            + (if stance[3] then 1.0 else 0.0) + (if stance[4] then 1.0 else 0.0);
  any_contact = stance[1] or stance[2] or stance[3] or stance[4];

  // ===================== NET BODY FORCES FROM CONTACT =====================
  F_net_y = F_fy[1] + F_fy[2] + F_fy[3] + F_fy[4];
  F_net_z = F_n[1] + F_n[2] + F_n[3] + F_n[4];
  F_net_x = F_fx[1] + F_fx[2] + F_fx[3] + F_fx[4];

  M_net_roll = (sy[1]*F_n[1] + sy[2]*F_n[2] + sy[3]*F_n[3] + sy[4]*F_n[4])
             - (fz_rel[1]*F_fy[1] + fz_rel[2]*F_fy[2] + fz_rel[3]*F_fy[3] + fz_rel[4]*F_fy[4]);

  M_net_pitch = (sx[1]*F_n[1] + sx[2]*F_n[2] + sx[3]*F_n[3] + sx[4]*F_n[4])
              - (fz_rel[1]*F_fx[1] + fz_rel[2]*F_fx[2] + fz_rel[3]*F_fx[3] + fz_rel[4]*F_fx[4]);

  // ===================== LEG DYNAMICS (8 leg torques) =====================
  for i in 1:4 loop
    der(q_hip[i]) = dq_hip[i];
    der(q_knee[i]) = dq_knee[i];

    I_leg * der(dq_hip[i]) = tau_hip[i] - (J11[i]*F_fy[i] + J21[i]*F_n[i])
        - m_leg*g*(1.5*L1*sin(q_hip[i]) + 0.5*L2*sin(q_hip[i]+q_knee[i]));

    I_leg * der(dq_knee[i]) = tau_knee[i] - (J12[i]*F_fy[i] + J22[i]*F_n[i])
        - m_leg*g*0.5*L2*sin(q_hip[i]+q_knee[i]);
  end for;

  // ===================== WHEEL DYNAMICS (4 wheel torques) =====================
  for i in 1:4 loop
    der(q_wheel[i]) = dq_wheel[i];
    I_wheel * der(dq_wheel[i]) = tau_wheel[i] - F_fx[i]*r_wheel;
  end for;

  // ===================== TORQUE SATURATION (independent per-joint, 39.6 N.m) =====================
  for i in 1:4 loop
    tau_hip[i] = max(-tau_max, min(tau_max, tau_hip_cmd[i]));
    tau_knee[i] = max(-tau_max, min(tau_max, tau_knee_cmd[i]));
    tau_wheel[i] = max(-tau_max, min(tau_max, tau_wheel_cmd[i]));
  end for;

  // ===================== WHOLE-BODY BALANCE CONTROLLER (80 Hz, zero-order hold) =====================
  when sample(0, dt_ctrl) then
    ctrl_cnt = pre(ctrl_cnt) + 1;

    // References: stand / step in place
    ref_z = h_ref;
    ref_y = 0.0;
    ref_roll = 0.0;
    ref_pitch = 0.0;
    ref_vx = 0.0;

    // Desired net body wrench (PD on estimated states + gravity feedforward)
    d_F_des_z = kp_height*(ref_z - est_z) + kd_height*(0.0 - est_vz) + m_body*g;
    d_F_des_y = kp_lat*(ref_y - est_y) + kd_lat*(0.0 - est_vy);
    d_M_des_roll = kp_roll*(ref_roll - est_roll) + kd_roll*(0.0 - imu_wroll);
    d_M_des_pitch = kp_pitch*(ref_pitch - est_pitch) + kd_pitch*(0.0 - imu_wpitch);
    d_F_des_x = kp_fwd*(ref_vx - vx_b) + kd_fwd*(0.0 - vx_b);

    // Distribute to feet and map to joint torques via Jacobian transpose
    for i in 1:4 loop
      d_F_n_des[i] = d_F_des_z/4.0
                     + d_M_des_roll*sy[i]/(4.0*hw*hw)
                     + d_M_des_pitch*sx[i]/(4.0*hl*hl);
      d_F_n_des[i] = max(d_F_n_des[i], 0.0);

      d_F_fy_des[i] = d_F_des_y/4.0;
      d_F_fx_des[i] = d_F_des_x/4.0;

      tau_hip_cmd[i] = J11[i]*d_F_fy_des[i] + J21[i]*d_F_n_des[i]
          + m_leg*g*(1.5*L1*sin(q_hip[i]) + 0.5*L2*sin(q_hip[i]+q_knee[i]));
      tau_knee_cmd[i] = J12[i]*d_F_fy_des[i] + J22[i]*d_F_n_des[i]
          + m_leg*g*0.5*L2*sin(q_hip[i]+q_knee[i]);
      tau_wheel_cmd[i] = r_wheel * d_F_fx_des[i];
    end for;
  end when;

  // ===================== IMU MODEL =====================
  imu_wroll = wroll;
  imu_wpitch = wpitch;
  imu_ay = der(vy_b) - g*sin(roll);
  imu_az = der(vz_b) + g*cos(roll);

  // ===================== STATE ESTIMATOR (IMU + kinematics + force-qualified contacts) =====================
  // Kinematic height from leg geometry when feet are on ground
  kin_z = if any_contact then
            ((if stance[1] then (r_wheel - fz_rel[1] - sy[1]*sin(est_roll) + sx[1]*sin(est_pitch)) else 0.0)
           + (if stance[2] then (r_wheel - fz_rel[2] - sy[2]*sin(est_roll) + sx[2]*sin(est_pitch)) else 0.0)
           + (if stance[3] then (r_wheel - fz_rel[3] - sy[3]*sin(est_roll) + sx[3]*sin(est_pitch)) else 0.0)
           + (if stance[4] then (r_wheel - fz_rel[4] - sy[4]*sin(est_roll) + sx[4]*sin(est_pitch)) else 0.0))
            / max(n_contact, 1.0)
          else est_z;

  // Kinematic roll from differential foot heights (left-right pair)
  kin_roll = if (stance[1] and stance[2]) then
               asin(max(-1.0, min(1.0, (fz_rel[2] - fz_rel[1])/(2.0*hw))))
             elseif (stance[3] and stance[4]) then
               asin(max(-1.0, min(1.0, (fz_rel[4] - fz_rel[3])/(2.0*hw))))
             else est_roll;

  // Kinematic pitch from differential foot heights (front-rear pair)
  kin_pitch = if (stance[1] and stance[3]) then
                asin(max(-1.0, min(1.0, (fz_rel[3] - fz_rel[1])/(2.0*hl))))
              elseif (stance[2] and stance[4]) then
                asin(max(-1.0, min(1.0, (fz_rel[4] - fz_rel[2])/(2.0*hl))))
              else est_pitch;

  // Complementary filter: integrate IMU, correct with kinematics when in contact
  der(est_roll) = imu_wroll + (if any_contact then k_est_roll*(kin_roll - est_roll) else 0.0);
  der(est_pitch) = imu_wpitch + (if any_contact then k_est_pitch*(kin_pitch - est_pitch) else 0.0);
  der(est_z) = est_vz + (if any_contact then k_est_z*(kin_z - est_z) else 0.0);
  der(est_vz) = (imu_az - g*cos(est_roll)) + (if any_contact then k_est_z*(kin_z - est_z)*0.5 else 0.0);
  der(est_y) = est_vy + (if any_contact then k_est_y*(ref_y - est_y)*0.01 else 0.0);
  der(est_vy) = imu_ay + g*sin(est_roll);

  // ===================== OUTPUT TRACES =====================
  body_height = z_b;
  tracking_error = abs(roll - ref_roll);

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-4, Interval=0.0125),
    Documentation(info="WheelLegRecoverA: 28 kg floating-base quadruped with four 2-joint wheel-legs (0.10 m wheels).
      Whole-body balance controller at 80 Hz with contact switching.
      70 N lateral push applied during middle third of 8 s scenario.
      State estimator fuses IMU, kinematics, and force-qualified stance contacts.
      Per-joint torque limit 39.6 N.m. Ground friction 0.90. Level rigid ground. No external support.
      Requirements: torque bounds, no foot slip > 0.03 m, positive body height,
      attitude recovery, primary tracking error < 0.162 rad after 5.2 s, no NaN/Inf.
      Unspecified parameters (link lengths, inertias, gains) are assumed with engineering defaults.")
  );
end WheelLegRecoverA;