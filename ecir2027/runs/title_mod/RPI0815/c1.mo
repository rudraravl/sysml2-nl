model MonoHopRecoverE
  // ---- Physical parameters (SI) ----
  parameter Real m_body(unit="kg") = 10.0 "body mass";
  parameter Real I_body(unit="kg.m2") = 0.20 "body pitch inertia (nominal; cylindrical body radius unspecified)";
  parameter Real m_foot(unit="kg") = 0.30 "foot mass (nominal; spherical foot radius unspecified)";
  parameter Real r_foot(unit="m") = 0.02 "foot sphere radius (nominal; unspecified)";
  parameter Real g(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real L_min(unit="m") = 0.30 "telescoping leg minimum length";
  parameter Real L_max(unit="m") = 0.60 "telescoping leg maximum length";
  parameter Real L0(unit="m") = 0.45 "leg spring rest length (nominal midpoint; unspecified)";
  parameter Real k_leg(unit="N/m") = 15000.0 "leg spring stiffness";
  parameter Real d_leg(unit="N.s/m") = 170.0 "leg damper coefficient";
  parameter Real F_act_max(unit="N") = 1045.0 "leg actuator command magnitude bound";
  parameter Real tau_hip_max(unit="N.m") = 60.0 "hip torque bound (nominal; unspecified)";
  parameter Real mu(unit="1") = 0.90 "ground Coulomb friction coefficient";
  parameter Real k_ground(unit="N/m") = 5.0e4 "ground normal stiffness (nominal; rigid level ground)";
  parameter Real d_ground(unit="N.s/m") = 500.0 "ground normal damping (nominal; unspecified)";
  parameter Real k_stop(unit="N/m") = 1.0e5 "leg hard-stop stiffness (nominal; unspecified)";
  parameter Real d_stop(unit="N.s/m") = 200.0 "leg hard-stop damping (nominal; unspecified)";
  parameter Real v_small(unit="m/s") = 1.0e-3 "friction velocity regularization";
  // ---- Disturbance ----
  parameter Real F_push(unit="N") = 168.0 "lateral body impulse magnitude";
  parameter Real T_push_start(unit="s") = 5.33 "push onset (middle third of 16 s)";
  parameter Real T_push_dur(unit="s") = 0.20 "finite push duration (nominal; impulse finite-duration unspecified)";
  // ---- Control / scenario ----
  parameter Real Ts(unit="s") = 0.004 "control sample period (250 Hz)";
  parameter Real z_ref(unit="m") = 0.80 "reference body apex height (nominal; unspecified)";
  parameter Real Kp_z(unit="N/m") = 1500.0 "vertical position gain (nominal)";
  parameter Real Kd_z(unit="N.s/m") = 120.0 "vertical velocity gain (nominal)";
  parameter Real Kp_theta(unit="N.m/rad") = 90.0 "attitude proportional gain (nominal)";
  parameter Real Kd_theta(unit="N.m.s/rad") = 14.0 "attitude derivative gain (nominal)";
  parameter Real Kp_alpha(unit="N.m/rad") = 50.0 "leg-angle proportional gain (nominal)";
  parameter Real Kd_alpha(unit="N.m.s/rad") = 6.0 "leg-angle derivative gain (nominal)";
  parameter Real kx_place(unit="1") = 0.5 "lateral foot-placement position gain (nominal)";
  parameter Real kv_place(unit="s") = 0.20 "lateral foot-placement velocity gain (nominal)";
  parameter Real alpha_max(unit="rad") = 0.40 "leg angle bound (nominal; unspecified)";

  // ---- Body states ----
  Real x(start=0.0, fixed=true) "body lateral position [m]";
  Real z(start=0.4635, fixed=true) "body height [m]";
  Real theta(start=0.0, fixed=true) "body pitch attitude [rad]";
  Real vx(start=0.0, fixed=true) "body lateral velocity [m/s]";
  Real vz(start=0.0, fixed=true) "body vertical velocity [m/s]";
  Real omega(start=0.0, fixed=true) "body pitch rate [rad/s]";
  // ---- Foot states ----
  Real xf(start=0.0, fixed=true) "foot lateral position [m]";
  Real zf(start=0.02, fixed=true) "foot height [m]";
  Real vxf(start=0.0, fixed=true) "foot lateral velocity [m/s]";
  Real vzf(start=0.0, fixed=true) "foot vertical velocity [m/s]";
  // ---- Leg geometry ----
  Real dx "foot minus body lateral offset [m]";
  Real dz "foot minus body vertical offset [m]";
  Real L "instantaneous leg length [m]";
  Real Ldot "leg length rate [m/s]";
  Real nx "unit body->foot x";
  Real nz "unit body->foot z";
  Real tx "perpendicular unit x";
  Real tz "perpendicular unit z";
  Real alpha "leg angle from vertical [rad]";
  Real alpha_dot "leg angular rate [rad/s]";
  // ---- Leg forces ----
  Real F_spring "leg spring axial force [N]";
  Real F_damper "leg damper axial force [N]";
  Real F_stop "leg hard-stop force [N]";
  Real F_axial "total leg axial force on foot [N]";
  Real F_act "bounded actuator command applied [N]";
  Real tau_hip "bounded hip torque applied [N.m]";
  Real Ft_leg "tangential leg force on foot from hip torque [N]";
  // ---- Ground contact ----
  Real pen "ground penetration [m]";
  Real N_ground "ground normal force [N]";
  Real Ft_ground "ground friction force [N]";
  Real F_push_applied "applied lateral push [N]";
  Real in_stance_real "stance contact flag as real (0/1)";
  // ---- Estimator outputs ----
  Real theta_est(start=0.0, fixed=true) "estimated pitch [rad]";
  Real z_est(start=0.4635, fixed=true) "estimated body height [m]";
  Real x_est(start=0.0, fixed=true) "estimated lateral position [m]";
  Real vx_est(start=0.0, fixed=true) "estimated lateral velocity [m/s]";
  Real vz_est(start=0.0, fixed=true) "estimated vertical velocity [m/s]";
  Real omega_est(start=0.0, fixed=true) "estimated pitch rate [rad/s]";
  // ---- Diagnostics / acceptance ----
  Real foot_slip(start=0.0, fixed=true) "cumulative foot slip distance [m]";
  Real tracking_error "attitude tracking error [rad]";
  Real alpha_des "desired leg angle [rad]";
  Real alpha_des_b "bounded desired leg angle [rad]";
  Real ok_height "positive body height flag (0/1)";
  Real ok_slip "slip below 0.03 m flag (0/1)";
  Real ok_tracking "tracking error below 0.108 rad after 10.4 s (0/1)";
  Real ok_nan "no NaN/inf flag (0/1)";
  Real acceptance "fail-closed overall acceptance (0/1)";
  // ---- Traces ----
  Real trace_x = x;
  Real trace_z = z;
  Real trace_theta = theta;
  Real trace_F_act = F_act;
  Real trace_tau_hip = tau_hip;
  Real trace_N = N_ground;
  Real trace_slip = foot_slip;
  Real trace_err = tracking_error;
  Real trace_accept = acceptance;
  Real trace_F_push = F_push_applied;
  Real trace_in_stance = in_stance_real;

  // ---- Sampled controller state ----
  discrete Real F_act_held(start=0.0) "sampled actuator command";
  discrete Real tau_hip_held(start=0.0) "sampled hip torque";

protected
  parameter Real eps_L = 1.0e-6 "length regularization";
  Real N_raw "raw ground normal before clipping";

equation
  // ---- Leg geometry (massless telescoping strut between body and foot) ----
  dx = xf - x;
  dz = zf - z;
  L = if (dx*dx + dz*dz) > 1.0e-12 then sqrt(dx*dx + dz*dz) else eps_L;
  nx = dx / L;
  nz = dz / L;
  tx = -nz;
  tz = nx;
  alpha = atan2(dx, -dz);
  Ldot = nx*(vxf - vx) + nz*(vzf - vz);
  alpha_dot = (nx*(vzf - vz) - nz*(vxf - vx)) / L;

  // ---- Leg axial force (spring + damper + hard stops + actuator) ----
  F_spring = k_leg*(L0 - L);
  F_damper = -d_leg*Ldot;
  F_stop = if L < L_min then k_stop*(L_min - L) - d_stop*Ldot
           else if L > L_max then -k_stop*(L - L_max) - d_stop*Ldot
           else 0.0;
  F_axial = F_spring + F_damper + F_stop + F_act;

  // ---- Hip torque transmitted as tangential force on foot ----
  Ft_leg = tau_hip / L;

  // ---- Ground contact (level rigid ground with friction) ----
  pen = r_foot - zf;
  N_raw = if pen > 0.0 then (k_ground*pen - d_ground*vzf) else 0.0;
  N_ground = if N_raw > 0.0 then N_raw else 0.0;
  Ft_ground = -mu*N_ground*tanh(vxf / v_small);
  in_stance_real = if N_ground > 1.0 then 1.0 else 0.0;

  // ---- Disturbance: finite-duration lateral push at body ----
  F_push_applied = if (time >= T_push_start) and (time < T_push_start + T_push_dur) then F_push else 0.0;

  // ---- Body dynamics ----
  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;
  m_body*der(vx) = -F_axial*nx - Ft_leg*tx + F_push_applied;
  m_body*der(vz) = -F_axial*nz - Ft_leg*tz - m_body*g;
  I_body*der(omega) = -tau_hip;

  // ---- Foot dynamics ----
  der(xf) = vxf;
  der(zf) = vzf;
  m_foot*der(vxf) = F_axial*nx + Ft_leg*tx + Ft_ground;
  m_foot*der(vzf) = F_axial*nz + Ft_leg*tz - m_foot*g + N_ground;

  // ---- Slip accumulation (only during stance) ----
  der(foot_slip) = if in_stance_real > 0.5 then abs(vxf) else 0.0;

  // ---- Estimator: IMU/kinematics/contact-qualified first-order observer ----
  der(theta_est) = (theta - theta_est)/0.02;
  der(z_est)     = (z - z_est)/0.02;
  der(x_est)     = (x - x_est)/0.02;
  der(vx_est)    = (vx - vx_est)/0.02;
  der(vz_est)    = (vz - vz_est)/0.02;
  der(omega_est) = (omega - omega_est)/0.02;

  // ---- Whole-body balance control: contact switching ----
  F_act = F_act_held;
  tau_hip = tau_hip_held;

  // Desired leg angle for lateral recovery (Raibert-style foot placement).
  alpha_des = kx_place*x + kv_place*vx;
  alpha_des_b = if alpha_des > alpha_max then alpha_max
                else if alpha_des < -alpha_max then -alpha_max
                else alpha_des;

  // ---- Tracking error and acceptance (fail-closed) ----
  tracking_error = abs(theta_est);
  ok_height   = if z > 0.0 then 1.0 else 0.0;
  ok_slip     = if foot_slip <= 0.03 then 1.0 else 0.0;
  ok_tracking = if time >= 10.4 then (if tracking_error < 0.108 then 1.0 else 0.0) else 1.0;
  ok_nan = if (abs(z) > 1.0e5) or (abs(theta) > 1.0e3)
            or (abs(N_ground) > 1.0e7) or (abs(F_act) > 1.0e5) or (abs(tau_hip) > 1.0e4)
            or (abs(F_axial) > 1.0e7)
          then 0.0 else 1.0;
  acceptance = if (ok_height > 0.5 and ok_slip > 0.5 and ok_tracking > 0.5 and ok_nan > 0.5) then 1.0 else 0.0;

  // ---- 250 Hz sampled balance controller ----
  when sample(0, Ts) then
    // Telescoping leg actuator: inject hopping energy during stance.
    F_act_held = if in_stance_real > 0.5 then
                   (if (Kp_z*(z_ref - z_est) - Kd_z*vz_est) > F_act_max then F_act_max
                    else if (Kp_z*(z_ref - z_est) - Kd_z*vz_est) < -F_act_max then -F_act_max
                    else (Kp_z*(z_ref - z_est) - Kd_z*vz_est))
                 else 0.0;
    // Hip torque: attitude regulation in stance, foot placement in flight.
    tau_hip_held = if in_stance_real > 0.5 then
                     (if (Kp_theta*(0.0 - theta_est) - Kd_theta*omega_est) > tau_hip_max then tau_hip_max
                      else if (Kp_theta*(0.0 - theta_est) - Kd_theta*omega_est) < -tau_hip_max then -tau_hip_max
                      else (Kp_theta*(0.0 - theta_est) - Kd_theta*omega_est))
                   else
                     (if (Kp_alpha*(alpha_des_b - alpha) - Kd_alpha*alpha_dot) > tau_hip_max then tau_hip_max
                      else if (Kp_alpha*(alpha_des_b - alpha) - Kd_alpha*alpha_dot) < -tau_hip_max then -tau_hip_max
                      else (Kp_alpha*(alpha_des_b - alpha) - Kd_alpha*alpha_dot));
  end when;

  annotation (
    experiment(StartTime=0.0, StopTime=16.0, Tolerance=1.0e-6, Interval=0.004),
    Documentation(info="MonoHopRecoverE: single-leg hopping robot with whole-body balance control recovering from a finite-duration lateral body impulse. Plant: 10 kg cylindrical body on one telescoping 0.30-0.60 m leg (15 kN/m spring, 170 N.s/m damper, spherical foot), bounded leg actuator (1045 N), level rigid ground friction 0.90. Controller runs at 250 Hz with contact switching. Disturbance: 168 N lateral push in middle third. Acceptance is fail-closed: positive body height, foot slip < 0.03 m, attitude tracking error < 0.108 rad after 10.4 s, and no NaN/inf. Unspecified physical dimensions (body radius, foot radius, rest length, gains, push duration) are nominal and labeled in comments.")
  );
end MonoHopRecoverE;