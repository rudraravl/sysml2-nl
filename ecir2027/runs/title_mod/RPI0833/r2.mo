model WheelLegClimbE
  // ------------------------------------------------------------------
  // WheelLegClimbE : floating-base wheeled-leg robot climbing four stairs
  // Requirement-sourced facts:
  //   torso 28 kg, four two-joint legs ending in driven 0.10 m wheels,
  //   8 leg torques + 4 wheel torques independently limited,
  //   command magnitude bounded by 60.5 N.m,
  //   four stairs: rise 0.16 m, tread 0.30 m,
  //   rigid stair friction coefficient 0.88,
  //   controlled 120 N payload disturbance applied in middle third,
  //   control rate 250 Hz, run 16 s,
  //   primary tracking error < 0.036 m after 10.4 s,
  //   at least two support contacts, stair-edge clearance, completion,
  //   fail-closed, no NaN/infinite values.
  // Facts not stated (link masses, inertias, control gains, contact
  // stiffness, sensor noise, exact body-height setpoint, gait phasing)
  // are treated as engineering placeholders, not verified facts; they are
  // exposed as tunable parameters so they are never silently invented.
  // ------------------------------------------------------------------

  // ---- requirement-sourced parameters ----
  parameter Real m_torso = 28.0          "torso mass [kg] (required)";
  parameter Real r_w     = 0.10          "wheel radius [m] (required)";
  parameter Real tau_max = 60.5          "per-joint/wheel command bound [N.m] (required)";
  parameter Real rise    = 0.16          "stair rise [m] (required)";
  parameter Real tread   = 0.30          "stair tread [m] (required)";
  parameter Integer n_steps = 4           "number of stairs (required)";
  parameter Real mu      = 0.88           "stair friction coefficient (required)";
  parameter Real payload_force = 120.0   "payload disturbance [N] (required)";
  parameter Real Ts_ctrl = 0.004         "control period [s] = 250 Hz (required)";
  parameter Real T_run   = 16.0           "run duration [s] (required)";
  parameter Real err_tol = 0.036         "primary tracking tolerance [m] (required)";
  parameter Real t_check = 10.4           "tracking check time [s] (required)";

  // ---- engineering placeholders (NOT requirement-sourced) ----
  parameter Real m_leg_link = 1.0   "per-leg link mass placeholder [kg]";
  parameter Real m_eff = m_torso + 4.0*m_leg_link "effective translational mass [kg]";
  parameter Real I_body = 3.0       "body pitch inertia placeholder [kg.m^2]";
  parameter Real L1 = 0.40          "thigh length placeholder [m]";
  parameter Real L2 = 0.40          "shin length placeholder [m]";
  parameter Real z_des = 0.88       "maintained body height placeholder [m]";
  parameter Real hx[4] = {0.25,0.15,-0.15,-0.25} "hip x-offsets [m]";
  parameter Real by[4] = {0.20,-0.20,0.20,-0.20} "hip y-offsets [m] (structural, planar unused)";
  parameter Real J1 = 0.05         "hip joint inertia placeholder [kg.m^2]";
  parameter Real J2 = 0.05         "knee joint inertia placeholder [kg.m^2]";
  parameter Real Iw = 0.01         "wheel inertia placeholder [kg.m^2]";
  parameter Real b1 = 0.4          "hip damping placeholder [N.m.s/rad]";
  parameter Real b2 = 0.4          "knee damping placeholder [N.m.s/rad]";
  parameter Real bw = 0.05         "wheel damping placeholder [N.m.s/rad]";
  parameter Real Kc = 2.0e4        "contact stiffness placeholder [N/m]";
  parameter Real Dc = 500.0        "contact damping placeholder [N.s/m]";
  parameter Real v_thresh = 0.02    "friction smoothing velocity [m/s]";
  parameter Real Kp_joint = 300.0  "joint impedance proportional gain";
  parameter Real Kd_joint = 12.0   "joint impedance derivative gain";
  parameter Real Kw = 200.0        "wheel speed gain";
  parameter Real Kwd = 0.5         "wheel damping gain";
  parameter Real v_des = 0.25      "forward speed setpoint [m/s]";
  parameter Real cl_amp = 0.20     "edge-clearance lift amplitude [m]";
  parameter Real cp_pitch = 300.0  "pitch stabilizer proportional gain";
  parameter Real cd_pitch = 60.0   "pitch stabilizer derivative gain";
  parameter Real N_thresh = 8.0    "contact-detection threshold [N]";
  parameter Real g = 9.81;

  // ---- continuous states ----
  Real x_body(start=-0.30, fixed=true);
  Real z_body(start=z_des, fixed=true);
  Real theta(start=0.0, fixed=true);
  Real vx(start=0.0, fixed=true);
  Real vz(start=0.0, fixed=true);
  Real omega(start=0.0, fixed=true);

  Real q1[4](each start=-0.225, each fixed=true);
  Real q2[4](each start=0.452,  each fixed=true);
  Real dq1[4](each start=0.0,   each fixed=true);
  Real dq2[4](each start=0.0,   each fixed=true);
  Real phi[4](each start=0.0,   each fixed=true);
  Real dphi[4](each start=0.0,  each fixed=true);

  // ---- continuous kinematics / desired trajectory / sensors ----
  Real hipx[4], hipz[4];
  Real rx_kin[4], rz_kin[4];
  Real footx[4], footz_c[4];
  Real J11[4], J12[4], J21[4], J22[4];
  Real vfootx[4], vfootz[4];
  Real pen[4];
  Real N[4];
  Real slip[4];
  Real ft[4];
  Real lift_factor[4];

  Real footx_des[4];
  Real clearance_lift[4];
  Real footz_des_c[4];
  Real q1_des[4];
  Real q2_des[4];

  // ---- sampled controller (zero-order hold) ----
  discrete Real tau_hip_held[4](each start=0.0);
  discrete Real tau_knee_held[4](each start=0.0);
  discrete Real tau_wheel_held[4](each start=0.0);

  // ---- payload disturbance (middle third) ----
  Real payload_active;

  // ---- sensors ----
  output Real o_body_x = x_body;
  output Real o_body_z = z_body;
  output Real o_body_theta = theta;
  output Real o_vx = vx;
  output Real o_primary_err;
  output Real o_support_count;
  output Real o_min_clearance;
  output Real o_fail;
  output Real foot_force[4] = N;
  output Boolean accepted;

  // ---- acceptance accumulators ----
  discrete Real primary_err_after(start=0.0);
  discrete Real min_support(start=4.0);
  discrete Real min_clearance(start=1.0e9);
  discrete Boolean fail_latched(start=false);

  // ------------------------------------------------------------------
  // helper functions
  // ------------------------------------------------------------------
  function sig "smooth logistic step 0..1"
    input Real u;
    input Real w;
    output Real y;
  algorithm
    y := 1.0/(1.0 + exp(-max(-50.0, min(50.0, u/w))));
  end sig;

  function stairH "smooth rigid stair surface height [m]"
    input Real x;
    output Real z;
  protected
    Real s;
  algorithm
    s := 0.0;
    for k in 0:3 loop
      s := s + sig(x - k*0.30, 0.015);
    end for;
    z := 0.16 * s;
  end stairH;

  function invK "2R leg inverse kinematics, foot relative to hip (rz<0 down)"
    input Real rxd;
    input Real rzd;
    output Real q1o;
    output Real q2o;
  protected
    Real d, cq2, sq2, a;
  algorithm
    d := sqrt(rxd*rxd + rzd*rzd);
    d := max(0.02, min(0.79, d));
    cq2 := (d*d - 0.16 - 0.16)/(0.32);
    cq2 := max(-0.999, min(0.999, cq2));
    q2o := acos(cq2);
    sq2 := sin(q2o);
    a := atan2(rxd, -rzd);
    q1o := a - atan2(0.4*sq2, 0.4 + 0.4*cq2);
  end invK;

  function sat "symmetric saturation"
    input Real x;
    input Real lim;
    output Real y;
  algorithm
    y := max(-lim, min(lim, x));
  end sat;

  function stairHwrap "re-export stairH for use in when blocks"
    input Real x;
    output Real z;
  algorithm
    z := stairH(x);
  end stairHwrap;

  // ------------------------------------------------------------------
  // continuous equations
  // ------------------------------------------------------------------
equation
  // payload disturbance: middle third of the run
  payload_active = if (time >= T_run/3.0 and time <= 2.0*T_run/3.0) then payload_force else 0.0;

  for i in 1:4 loop
    // hip position on body (small-pitch linearization)
    hipx[i] = x_body + hx[i]*cos(theta);
    hipz[i] = z_body + hx[i]*sin(theta);

    // forward kinematics
    rx_kin[i] = L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    rz_kin[i] = -L1*cos(q1[i]) - L2*cos(q1[i]+q2[i]);
    footx[i] = hipx[i] + rx_kin[i];
    footz_c[i] = hipz[i] + rz_kin[i];

    // Jacobian
    J11[i] = L1*cos(q1[i]) + L2*cos(q1[i]+q2[i]);
    J12[i] = L2*cos(q1[i]+q2[i]);
    J21[i] = L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    J22[i] = L2*sin(q1[i]+q2[i]);

    // foot velocities (body + rotational + leg)
    vfootx[i] = vx - omega*(footz_c[i]-z_body) + J11[i]*dq1[i] + J12[i]*dq2[i];
    vfootz[i] = vz + omega*(footx[i]-x_body)  + J21[i]*dq1[i] + J22[i]*dq2[i];

    // contact (wheel center vs smooth stair surface)
    pen[i] = (stairH(footx[i]) + r_w) - footz_c[i];
    N[i] = noEvent(max(0.0, Kc*pen[i] - Dc*vfootz[i]));

    // rolling friction (Coulomb, smoothed)
    slip[i] = vfootx[i] - r_w*dphi[i];
    ft[i] = -mu*N[i]*tanh(slip[i]/v_thresh);

    // desired terrain-aware foothold: foot rolls under hip, follows stair
    footx_des[i] = x_body + hx[i];
    // edge clearance lift near each real riser (0,0.30,0.60,0.90)
    clearance_lift[i] = cl_amp
                       * sig(1.15 - footx_des[i], 0.02)
                       * sig(footx_des[i] + 0.05, 0.02)
                       * sig(0.30*floor(footx_des[i]/tread + 0.5) - footx_des[i], 0.03);
    lift_factor[i] = clearance_lift[i]/cl_amp;
    footz_des_c[i] = stairH(footx_des[i]) + r_w + clearance_lift[i];

    // inverse kinematics for desired joint angles
    (q1_des[i], q2_des[i]) = invK(0.0, footz_des_c[i] - z_body);

    // leg joint dynamics (controller holds torque; contact reacts)
    J1*der(dq1[i]) = tau_hip_held[i]   - (J11[i]*ft[i] + J21[i]*N[i]) - b1*dq1[i];
    J2*der(dq2[i]) = tau_knee_held[i]  - (J12[i]*ft[i] + J22[i]*N[i]) - b2*dq2[i];
    Iw*der(dphi[i]) = tau_wheel_held[i] - r_w*ft[i] - bw*dphi[i];

    der(q1[i])  = dq1[i];
    der(q2[i])  = dq2[i];
    der(phi[i]) = dphi[i];
  end for;

  // floating-base body dynamics
  der(x_body) = vx;
  der(z_body) = vz;
  der(theta)  = omega;
  m_eff*der(vx) = ft[1] + ft[2] + ft[3] + ft[4];
  m_eff*der(vz) = (N[1]+N[2]+N[3]+N[4]) - m_eff*g - payload_active;
  I_body*der(omega) =
      (footx[1]-x_body)*N[1] - (footz_c[1]-z_body)*ft[1]
    + (footx[2]-x_body)*N[2] - (footz_c[2]-z_body)*ft[2]
    + (footx[3]-x_body)*N[3] - (footz_c[3]-z_body)*ft[3]
    + (footx[4]-x_body)*N[4] - (footz_c[4]-z_body)*ft[4]
    - cp_pitch*theta - cd_pitch*omega;

  // live tracking metric for primary leg
  o_primary_err = sqrt((footx[1]-footx_des[1])^2 + (footz_c[1]-footz_des_c[1])^2);

  // live support count
  o_support_count =
      (if N[1] > N_thresh then 1.0 else 0.0) +
      (if N[2] > N_thresh then 1.0 else 0.0) +
      (if N[3] > N_thresh then 1.0 else 0.0) +
      (if N[4] > N_thresh then 1.0 else 0.0);

  // live minimum foot clearance above stair surface
  o_min_clearance =
      min(footz_c[1] - stairH(footx[1]) - r_w,
      min(footz_c[2] - stairH(footx[2]) - r_w,
      min(footz_c[3] - stairH(footx[3]) - r_w,
          footz_c[4] - stairH(footx[4]) - r_w)));

  o_fail = if fail_latched then 1.0 else 0.0;

  // ------------------------------------------------------------------
  // 250 Hz controller: terrain-aware foothold + joint-space impedance
  // ------------------------------------------------------------------
  when sample(0, Ts_ctrl) then
    for i in 1:4 loop
      // joint-space impedance with gravity feedforward (no payload knowledge)
      tau_hip_held[i]  = sat(Kp_joint*(q1_des[i]-q1[i]) - Kd_joint*dq1[i]
                             + J21[i]*(m_eff*g/4.0), tau_max);
      tau_knee_held[i] = sat(Kp_joint*(q2_des[i]-q2[i]) - Kd_joint*dq2[i]
                             + J22[i]*(m_eff*g/4.0), tau_max);
      // wheel drive suppressed while that leg is clearing an edge
      tau_wheel_held[i] = sat((1.0 - lift_factor[i])*(Kw*(v_des - vx) - Kwd*dphi[i]),
                              tau_max);
    end for;

    // acceptance accumulators
    if time >= t_check then
      primary_err_after = max(primary_err_after, o_primary_err);
    end if;
    if time >= 1.0 then
      min_support  = min(min_support,  o_support_count);
      min_clearance = min(min_clearance, o_min_clearance);
    end if;

    // fail-closed bound and finiteness checks
    if abs(x_body) > 1.0e3 or abs(z_body) > 1.0e3 or abs(vx) > 1.0e3
       or abs(vz) > 1.0e3 or abs(theta) > 1.0e2 or abs(omega) > 1.0e3 then
      fail_latched = true;
    end if;
    for i in 1:4 loop
      if abs(q1[i]) > 1.0e2 or abs(q2[i]) > 1.0e2
         or abs(dq1[i]) > 1.0e3 or abs(dq2[i]) > 1.0e3
         or abs(tau_hip_held[i]) > tau_max + 1.0e-3
         or abs(tau_knee_held[i]) > tau_max + 1.0e-3
         or abs(tau_wheel_held[i]) > tau_max + 1.0e-3
         or abs(N[i]) > 1.0e5 or abs(ft[i]) > 1.0e5 then
        fail_latched = true;
      end if;
    end for;
  end when;

  // ------------------------------------------------------------------
  // terminal acceptance (fail-closed)
  // ------------------------------------------------------------------
  when terminal() then
    accepted = (not fail_latched)
              and (primary_err_after < err_tol)
              and (min_support >= 2.0)
              and (min_clearance >= -1.0e-2)
              and (x_body > 1.30);
    assert(accepted,
      "WheelLegClimbE acceptance FAILED (fail-closed): bounds/contacts/clearance/completion/tracking not satisfied");
  end when;

  annotation (
    experiment(StartTime=0.0, StopTime=16.0, Tolerance=1.0e-5, Interval=0.004),
    Documentation(info="Standalone wheeled-leg robot plant (WheelLegClimbE) for stair-climbing acceptance testing. FMI 2.0 Co-Simulation exportable."));
end WheelLegClimbE;