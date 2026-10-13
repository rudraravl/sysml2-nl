model WheelLegClimbE
  // ============================================================
  // WheelLegClimbE: Floating-base wheel-legged robot climbing
  // four stairs (0.16 m rise, 0.30 m tread) while maintaining
  // body height.  28 kg torso, four 2-joint legs with 0.10 m
  // driven wheels.  250 Hz control, 16 s duration.
  // ============================================================

  // --- Physical Parameters ---
  parameter Real m_torso = 28.0    "Torso mass [kg]";
  parameter Real m_link  = 1.25    "Per-link leg mass [kg]";
  parameter Real m_whl    = 0.50    "Wheel mass [kg]";
  parameter Real L1       = 0.25    "Thigh length [m]";
  parameter Real L2       = 0.25    "Shank length [m]";
  parameter Real r_w      = 0.10    "Wheel radius [m]";
  parameter Real hip_x[4] = {-0.30, -0.30, 0.30, 0.30}
    "Hip x-offset from base centre (rear-L, rear-R, front-L, front-R) [m]";
  parameter Real g_grav   = 9.81    "Gravity [m/s^2]";
  parameter Real mu       = 0.88    "Friction coefficient [-]";
  parameter Real tau_max   = 60.5    "Per-joint torque limit [N.m]";

  // --- Stair Geometry ---
  parameter Real rise  = 0.16  "Stair rise [m]";
  parameter Real tread = 0.30  "Stair tread [m]";

  // --- Control / Mission ---
  parameter Real dt_ctrl = 1.0/250.0  "Control period [s]";
  parameter Real T_end   = 16.0       "Simulation duration [s]";
  parameter Real T_stair = 4.0         "Time per stair [s]";
  parameter Real h_des   = 0.50       "Desired body height above support [m]";
  parameter Real F_pld   = 120.0      "Payload disturbance [N]";

  // --- Gains ---
  parameter Real Kp_imp = 300.0  "Impedance P [N.m/rad]";
  parameter Real Kd_imp = 20.0   "Impedance D [N.m.s/rad]";
  parameter Real Kp_fwd = 300.0  "Forward-velocity P [N.s/m]";

  // --- Contact ---
  parameter Real k_c = 60000.0  "Contact stiffness [N/m]";
  parameter Real b_c = 600.0    "Contact damping [N.s/m]";

  // --- Derived Inertias ---
  parameter Real m_tot = m_torso + 4.0*(2.0*m_link + m_whl);
  parameter Real I_bas = m_torso*(0.30^2)/12.0;
  parameter Real I_jnt = m_link*(L1^2)/3.0 + (m_link+m_whl)*((L1+L2)^2)/4.0;
  parameter Real I_whl = 0.5*m_whl*(r_w^2);

  // ===== State Variables =====
  Real x_b(start=0.0)    "Base x [m]";
  Real z_b(start=0.50)   "Base z [m]";
  Real th(start=0.0)     "Base pitch [rad]";
  Real vx(start=0.0)     "Base x-velocity [m/s]";
  Real vz(start=0.0)     "Base z-velocity [m/s]";
  Real om(start=0.0)     "Base pitch-rate [rad/s]";

  Real q1[4](start={0,0,0,0})      "Hip angles [rad]";
  Real q2[4](start={0.9273,0.9273,0.9273,0.9273}) "Knee angles [rad]";
  Real qd1[4](start={0,0,0,0})      "Hip rates [rad/s]";
  Real qd2[4](start={0,0,0,0})      "Knee rates [rad/s]";

  Real phi[4](start={0,0,0,0})     "Wheel angles [rad]";
  Real phid[4](start={0,0,0,0})    "Wheel rates [rad/s]";

  // ===== Kinematics =====
  Real hx[4], hz[4];
  Real fx[4], fz[4];
  Real vfx[4], vfz[4];
  Real J11[4], J12[4], J21[4], J22[4];

  // ===== Contact =====
  Real sh[4]   "Stair height at foot x [m]";
  Real pen[4]  "Penetration [m]";
  Real Cx[4], Cz[4];
  Real Fdrv[4];

  // ===== Gravity Comp =====
  Real tg1[4], tg2[4];

  // ===== Controller =====
  Real q1d[4], q2d[4], qd1d[4], qd2d[4];
  Real fxd[4], fzd[4];
  Real xd, zd, vd;
  Real sf "stair fraction";
  Real tr1[4], tr2[4];
  Real tau1[4], tau2[4];
  Real twr[4], tw[4];

  // ===== IK Intermediates =====
  Real idx[4], idz[4], ir2[4], icq[4], isq[4], igm[4], ial[4];

  // ===== Tracking / Sensors =====
  Real fherr "Foothold error [m]";
  Real bherr "Body height error [m]";
  Real fe[4] "Per-foot error [m]";
  Real gap[4] "Foot clearance above stair [m]";
  Real Fpld_act "Active payload [N]";
  Real ax_imu, az_imu, om_imu;
  Real enc[8];
  Real ff[4] "Foot force magnitude [N]";
  Real drng  "Depth-camera range proxy [m]";
  Real cr[4] "Contact indicator";
  Integer nc "Number of support contacts";

  // ===== Acceptance =====
  Boolean jnt_ok, eff_ok, clr_ok, con_ok, cmp_ok, trk_ok, fin_ok, all_ok;
  discrete Real clr_max(start=0.0) "Max clearance ever observed [m]";
  Real q1m, q2m, t1m, t2m, twm;

equation
  // ===== Stair schedule =====
  sf = time / T_stair;
  vd = tread / T_stair;
  xd = min(sf, 4.0)*tread;
  zd = min(sf, 4.0)*rise + h_des;

  // ===== Desired foot positions (terrain-aware foothold plan) =====
  // Front legs (3,4): one stair ahead
  fxd[3] = min(sf + 0.5, 4.5)*tread;
  fxd[4] = min(sf + 0.5, 4.5)*tread;
  fzd[3] = min(max(sf + 1.0, 0.0), 4.0)*rise + r_w;
  fzd[4] = min(max(sf + 1.0, 0.0), 4.0)*rise + r_w;
  // Rear legs (1,2): current stair
  fxd[1] = max(sf - 0.5, 0.0)*tread;
  fxd[2] = max(sf - 0.5, 0.0)*tread;
  fzd[1] = max(sf - 0.5, 0.0)*rise + r_w;
  fzd[2] = max(sf - 0.5, 0.0)*rise + r_w;

  // ===== Inverse kinematics for desired joint angles =====
  for i in 1:4 loop
    idx[i] = fxd[i] - (xd + hip_x[i]);
    idz[i] = fzd[i] - zd;
    ir2[i] = idx[i]*idx[i] + idz[i]*idz[i];
    icq[i] = (ir2[i] - L1*L1 - L2*L2) / (2.0*L1*L2);
    q2d[i] = acos(max(-0.999, min(0.999, icq[i])));
    isq[i] = sin(q2d[i]);
    igm[i] = atan2(idx[i], -idz[i]);
    ial[i] = atan2(L2*isq[i], L1 + L2*icq[i]);
    q1d[i]  = igm[i] - ial[i];
    qd1d[i] = 0.0;
    qd2d[i] = 0.0;
  end for;

  // ===== Forward kinematics =====
  for i in 1:4 loop
    hx[i] = x_b + hip_x[i]*cos(th);
    hz[i] = z_b + hip_x[i]*sin(th);
    fx[i] = hx[i] + L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    fz[i] = hz[i] - L1*cos(q1[i]) - L2*cos(q1[i]+q2[i]);
  end for;

  // ===== Jacobian =====
  for i in 1:4 loop
    J11[i] = L1*cos(q1[i]) + L2*cos(q1[i]+q2[i]);
    J12[i] = L2*cos(q1[i]+q2[i]);
    J21[i] = L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    J22[i] = L2*sin(q1[i]+q2[i]);
  end for;

  // ===== Foot velocities =====
  for i in 1:4 loop
    vfx[i] = vx + J11[i]*qd1[i] + J12[i]*qd2[i];
    vfz[i] = vz + J21[i]*qd1[i] + J22[i]*qd2[i];
  end for;

  // ===== Stair surface height at foot x =====
  for i in 1:4 loop
    sh[i] = if fx[i] < 0.0 then 0.0
      elseif fx[i] < tread then rise
      elseif fx[i] < 2.0*tread then 2.0*rise
      elseif fx[i] < 3.0*tread then 3.0*rise
      else 4.0*rise;
  end for;

  // ===== Penetration (pen > 0 = contact) =====
  for i in 1:4 loop
    pen[i] = max(0.0, sh[i] - fz[i] + r_w);
  end for;

  // ===== Contact forces =====
  for i in 1:4 loop
    Cz[i] = if pen[i] > 0.0 then max(0.0, k_c*pen[i] - b_c*vfz[i]) else 0.0;
    Fdrv[i] = tw[i] / r_w;
    Cx[i] = if pen[i] > 0.0 and Cz[i] > 0.0
      then max(-mu*Cz[i], min(mu*Cz[i], Fdrv[i]))
      else 0.0;
  end for;

  // ===== Gravity compensation torques =====
  for i in 1:4 loop
    tg1[i] = (1.5*m_link + m_whl)*g_grav*L1*sin(q1[i])
           + (m_link + m_whl)*g_grav*(L2/2.0)*sin(q1[i]+q2[i]);
    tg2[i] = (m_link + m_whl)*g_grav*(L2/2.0)*sin(q1[i]+q2[i]);
  end for;

  // ===== Impedance controller with saturation =====
  for i in 1:4 loop
    tr1[i]  = Kp_imp*(q1d[i]-q1[i]) + Kd_imp*(qd1d[i]-qd1[i]) + tg1[i];
    tr2[i]  = Kp_imp*(q2d[i]-q2[i]) + Kd_imp*(qd2d[i]-qd2[i]) + tg2[i];
    tau1[i] = max(-tau_max, min(tau_max, tr1[i]));
    tau2[i] = max(-tau_max, min(tau_max, tr2[i]));
    twr[i]  = Kp_fwd*(vd - vx)*r_w/4.0;
    tw[i]   = max(-tau_max, min(tau_max, twr[i]));
  end for;

  // ===== Base dynamics =====
  der(x_b) = vx;
  der(z_b) = vz;
  der(th)  = om;
  m_tot*der(vx) = Cx[1]+Cx[2]+Cx[3]+Cx[4];
  m_tot*der(vz) = Cz[1]+Cz[2]+Cz[3]+Cz[4] - m_tot*g_grav - Fpld_act;
  I_bas*der(om) = (fx[1]-x_b)*Cz[1]-(fz[1]-z_b)*Cx[1]
                + (fx[2]-x_b)*Cz[2]-(fz[2]-z_b)*Cx[2]
                + (fx[3]-x_b)*Cz[3]-(fz[3]-z_b)*Cx[3]
                + (fx[4]-x_b)*Cz[4]-(fz[4]-z_b)*Cx[4];

  // ===== Leg joint dynamics =====
  for i in 1:4 loop
    der(q1[i])  = qd1[i];
    der(q2[i])  = qd2[i];
    I_jnt*der(qd1[i]) = tau1[i] - (J11[i]*Cx[i] + J21[i]*Cz[i]) - tg1[i];
    I_jnt*der(qd2[i]) = tau2[i] - (J12[i]*Cx[i] + J22[i]*Cz[i]) - tg2[i];
  end for;

  // ===== Wheel dynamics =====
  for i in 1:4 loop
    der(phi[i])  = phid[i];
    I_whl*der(phid[i]) = tw[i] - r_w*Cx[i];
  end for;

  // ===== Payload disturbance (middle third) =====
  Fpld_act = if (time > T_end/3.0 and time < 2.0*T_end/3.0) then F_pld else 0.0;

  // ===== Sensors =====
  ax_imu  = (Cx[1]+Cx[2]+Cx[3]+Cx[4])/m_tot;
  az_imu  = (Cz[1]+Cz[2]+Cz[3]+Cz[4]-m_tot*g_grav-Fpld_act)/m_tot;
  om_imu  = om;
  for i in 1:4 loop
    enc[i]    = q1[i];
    enc[i+4]  = q2[i];
    ff[i]     = sqrt(Cx[i]*Cx[i]+Cz[i]*Cz[i]);
  end for;
  drng = z_b - sh[3];

  // ===== Tracking errors =====
  for i in 1:4 loop
    fe[i]  = if pen[i] > 0.001
      then sqrt((fx[i]-fxd[i])*(fx[i]-fxd[i]) + (fz[i]-fzd[i])*(fz[i]-fzd[i]))
      else 0.0;
    gap[i] = fz[i] - r_w - sh[i];
  end for;
  fherr = max(fe);
  bherr = z_b - zd;

  // ===== Contact count =====
  for i in 1:4 loop
    cr[i] = if pen[i] > 0.001 then 1.0 else 0.0;
  end for;
  nc = integer(cr[1]+cr[2]+cr[3]+cr[4]);

  // ===== Acceptance metrics =====
  q1m = max(abs(q1));
  q2m = max(abs(q2));
  t1m = max(abs(tau1));
  t2m = max(abs(tau2));
  twm = max(abs(tw));

  jnt_ok = (q1m < 1.57) and (q2m < 3.14);
  eff_ok = (t1m <= tau_max) and (t2m <= tau_max) and (twm <= tau_max);
  clr_ok = clr_max > 0.01;
  con_ok = nc >= 2;
  cmp_ok = x_b >= 4.0*tread - 0.05;
  trk_ok = if time > 10.4 then fherr < 0.036 else true;
  fin_ok = (abs(x_b) < 1e8) and (abs(z_b) < 1e8) and (abs(th) < 1e8)
       and (abs(fherr) < 1e8) and (abs(bherr) < 1e8);
  all_ok = jnt_ok and eff_ok and clr_ok and con_ok and cmp_ok and trk_ok and fin_ok;

  // ===== Sampled stair-edge clearance tracking (250 Hz) =====
  when sample(0, dt_ctrl) loop
    clr_max = max(clr_max, max(gap));
  end when;

  // ===== Fail-closed termination =====
  when time > 0.5 and not fin_ok loop
    terminate("NaN or infinite value detected — fail-closed");
  end when;
  when time > 2.0 and not jnt_ok loop
    terminate("Joint bounds violated — fail-closed");
  end when;
  when time > 10.4 and not trk_ok loop
    terminate("Tracking error exceeded after 10.4 s — fail-closed");
  end when;
  when time > 1.0 and not con_ok loop
    terminate("Fewer than two support contacts — fail-closed");
  end when;
  when time >= T_end and not all_ok loop
    terminate("Acceptance criteria not met at end — fail-closed");
  end when;

end WheelLegClimbE;