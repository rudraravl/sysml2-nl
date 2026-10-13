model WheelLegTraverseF
  "Wheel-leg floating-base robot crossing a rocky/gapped height field.
   Reduced-order hybrid model: torso 3D (x,y,z,pitch,roll) with mass/inertia,
   four two-joint (hip+knee) massy feet, driven wheels, terrain contact with
   friction, foothold planner + swing-foot trajectory control at 500 Hz,
   controlled lateral push, and synchronized state/command/sensor traces.
   Unknown requirement facts (commanded speed numeric, wheel-torque numeric
   limit, exact gap/rock positions) are represented by labeled assumptions."

  import Modelica.Constants.pi;

  // ---------- Physical embodiment ----------
  parameter Real m_body  = 28.0  "torso mass [kg]";
  parameter Real m_foot   = 0.30  "foot/wheel lumped mass per leg [kg]";
  parameter Real I_pitch  = 0.80  "torso pitch inertia [kg.m2]";
  parameter Real I_roll   = 0.60  "torso roll inertia [kg.m2]";
  parameter Real g        = 9.81  "gravity [m/s2]";
  parameter Real mu       = 0.78  "contact friction coefficient";
  parameter Real r_w      = 0.10  "driven wheel radius [m]";
  parameter Real L1       = 0.18  "thigh length [m]";
  parameter Real L2       = 0.20  "shank length [m]";
  parameter Real Lx       = 0.40  "hip spacing fore-aft [m]";
  parameter Real Ly       = 0.30  "hip spacing lateral [m]";
  parameter Real h_hip    = 0.10  "hip height above torso COM [m]";

  // ---------- Actuation limits ----------
  parameter Real tau_lim   = 67.1 "leg joint torque limit [N.m] per joint";
  parameter Real tau_w_lim = 67.1 "wheel torque limit [N.m] (assumed: requirement states independently limited but gives no number)";

  // ---------- Commanded speed (numeric value not stated) ----------
  parameter Real v_cmd    = 0.50 "commanded average forward speed [m/s] (representative; exact value unknown)";

  // ---------- Control ----------
  parameter Real Ts_ctrl   = 0.002 "control period [s] (500 Hz)";
  parameter Real T_gait    = 0.80  "gait cycle [s]";
  parameter Real duty      = 0.60  "stance duty fraction";
  parameter Real T_swing   = T_gait*(1.0 - duty) "swing duration [s]";
  parameter Real stride    = 0.22  "nominal foothold stride [m]";
  parameter Real swing_lift = 0.13 "swing foot apex lift above terrain [m]";
  parameter Real Kp_j      = 220.0 "joint position gain [N.m/rad]";
  parameter Real Kd_j      = 18.0  "joint velocity gain [N.m.s/rad]";
  parameter Real Kw        = 6.0   "wheel speed gain [N.m.s/rad]";
  parameter Real I_w       = 0.010 "wheel inertia [kg.m2]";
  parameter Real k_c       = 6.0e4 "contact normal stiffness [N/m]";
  parameter Real d_c       = 250.0 "contact normal damping [N.s/m]";

  // ---------- Mission terrain geometry ----------
  parameter Real x_goal   = v_cmd*20.0 "route goal distance [m]";

  // ---------- Push disturbance ----------
  parameter Real F_push   = 130.0 "lateral push magnitude [N]";
  parameter Real t_push0  = 9.90  "push onset [s]";
  parameter Real t_push1  = 10.10  "push release [s]";

  // ---------- Hip layout & gait phase offsets (trot) ----------
  parameter Real hipx[4]      = { Lx/2,  Lx/2, -Lx/2, -Lx/2};
  parameter Real laty[4]      = { Ly/2, -Ly/2,  Ly/2, -Ly/2};
  parameter Real phase_off[4] = { 0.0,   0.5,   0.5,   0.0};

  // ---------- Torso states ----------
  Real x(start=0.0)       "forward position [m]";
  Real vx(start=0.0);
  Real z(start=0.34)      "torso COM height [m]";
  Real vz(start=0.0);
  Real pitch(start=0.0)   "pitch [rad]";
  Real pitch_d(start=0.0);
  Real y(start=0.0)       "lateral position [m]";
  Real vy(start=0.0);
  Real roll_a(start=0.0)  "roll [rad]";
  Real roll_d(start=0.0);
  Real ax, az, ay, apitch, aroll;

  // ---------- Leg & wheel states ----------
  Real q1[4](each start=0.70)   "hip angles [rad]";
  Real dq1[4](each start=0.0);
  Real q2[4](each start=-0.80) "knee angles [rad]";
  Real dq2[4](each start=0.0);
  Real th[4](each start=0.0)   "wheel angles [rad]";
  Real dth[4](each start=0.0);

  // ---------- Kinematics & forces ----------
  Real Hx[4],Hz[4],Hy[4];
  Real Fx[4],Fz[4],dFx[4],dFz[4];
  Real J11[4],J12[4],J21[4],J22[4],detJ[4],detJs[4];
  Real N[4]   "normal contact force [N]";
  Real Fcx[4] "tractive/longitudinal contact force [N]";
  Real Fxj[4],Fzj[4] "foot force from joint torques [N]";
  Real ddq1[4],ddq2[4],ddth[4];

  // ---------- Control targets & commands ----------
  Real foot_tx[4],foot_tz[4];
  Real dx_ik[4],dz_ik[4],c2[4];
  Real q1d[4],q2d[4];
  Real tau_hip[4],tau_knee[4],tau_w[4];
  Real ph[4] "swing phase 0..1";

  // ---------- Discrete control state ----------
  discrete Real stance[4](each start=1.0);
  discrete Real swing_active[4](each start=0.0);
  discrete Real swing_t0[4](each start=0.0);
  discrete Real swing_from_x[4](each start=0.0);
  discrete Real swing_to_x[4](each start=0.0);
  discrete Real foot_hold_x[4](each start=0.0);
  discrete Real foot_hold_z[4](each start=0.0);

  // ---------- Disturbance & reference ----------
  Real F_push_t "applied lateral push [N]";
  Real x_ref    "reference body path [m]";

  // ---------- Verification observables ----------
  Real clearance   "body clearance above terrain [m]";
  Real max_hip     "max |hip torque| [N.m]";
  Real max_knee    "max |knee torque| [N.m]";
  Real max_wheel   "max |wheel torque| [N.m]";
  Real max_tau     "max |actuator torque| [N.m]";
  Real max_att     "max |pitch|,|roll| [rad]";
  Real path_err    "body-path tracking error [m]";
  Boolean bounds_ok, clearance_ok, attitude_ok, route_ok, tracking_ok, finite_ok;

protected
  discrete Real phi_l;
  discrete Real nstance_l;
  discrete Real tgt_l;

  // ================= Functions =================
  function terrainHeight "forward depth / terrain height field at x [m]"
    input Real x;
    output Real h;
  protected
    constant Real rock1_x = 3.00;
    constant Real rock2_x = 7.00;
    constant Real rock_half = 0.20;
    constant Real rock_h = 0.08;
    constant Real gap1_x = 9.56;
    constant Real gap2_x = 13.56;
    constant Real gap_half = 0.06;
    Real r1,r2;
  algorithm
    r1 := 0.5*(1.0 + cos(Modelica.Constants.pi*(x-rock1_x)/rock_half));
    r2 := 0.5*(1.0 + cos(Modelica.Constants.pi*(x-rock2_x)/rock_half));
    h := 0.0;
    if abs(x-rock1_x) <= rock_half then
      h := rock_h*r1;
    end if;
    if abs(x-rock2_x) <= rock_half then
      h := h + rock_h*r2;
    end if;
    h := h - 1.0*exp(-((x-gap1_x)/gap_half)^2) - 1.0*exp(-((x-gap2_x)/gap_half)^2);
  end terrainHeight;

  function sat "symmetric saturation"
    input Real v;
    input Real lim;
    output Real y;
  algorithm
    if v > lim then
      y := lim;
    elseif v < -lim then
      y := -lim;
    else
      y := v;
    end if;
  end sat;

  function clmp "asymmetric clamp"
    input Real v;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    if v > hi then
      y := hi;
    elseif v < lo then
      y := lo;
    else
      y := v;
    end if;
  end clmp;

  // ================= Initialization =================
initial algorithm
  for i in 1:4 loop
    foot_hold_x[i]  := x + hipx[i];
    foot_hold_z[i]  := terrainHeight(foot_hold_x[i]);
    swing_from_x[i] := foot_hold_x[i];
    swing_to_x[i]   := foot_hold_x[i] + stride;
    swing_active[i] := 0.0;
    swing_t0[i]     := 0.0;
    stance[i]       := 1.0;
  end for;

  // ================= Discrete control @500 Hz =================
algorithm
  when sample(0, Ts_ctrl) then
    for i in 1:4 loop
      phi_l := mod(time/T_gait + phase_off[i], 1.0);
      if phi_l < duty then
        nstance_l := 1.0;
      else
        nstance_l := 0.0;
      end if;
      if pre(stance[i]) > 0.5 and nstance_l < 0.5 then
        swing_active[i] := 1.0;
        swing_t0[i]     := time;
        swing_from_x[i] := foot_hold_x[i];
        tgt_l           := x + stride;
        if terrainHeight(tgt_l) < -0.3 then
          tgt_l := tgt_l + 0.20;
        end if;
        swing_to_x[i] := tgt_l;
      elseif pre(swing_active[i]) > 0.5 and nstance_l > 0.5 then
        swing_active[i] := 0.0;
        foot_hold_x[i]  := swing_to_x[i];
        foot_hold_z[i]  := terrainHeight(swing_to_x[i]);
      end if;
      stance[i] := nstance_l;
    end for;
  end when;

equation
  // ---- disturbance & reference ----
  F_push_t = if (time >= t_push0 and time <= t_push1) then F_push else 0.0;
  x_ref    = v_cmd*time;

  // ---- hip positions & foot kinematics ----
  for i in 1:4 loop
    Hx[i] = x + hipx[i];
    Hz[i] = z + h_hip;
    Hy[i] = y + laty[i];
    Fx[i] = Hx[i] + L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    Fz[i] = Hz[i] - L1*cos(q1[i]) - L2*cos(q1[i]+q2[i]);
    dFx[i] = vx + (L1*cos(q1[i]) + L2*cos(q1[i]+q2[i]))*dq1[i] + L2*cos(q1[i]+q2[i])*dq2[i];
    dFz[i] = vz + (L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]))*dq1[i] + L2*sin(q1[i]+q2[i])*dq2[i];
    J11[i] = L1*cos(q1[i]) + L2*cos(q1[i]+q2[i]);
    J12[i] = L2*cos(q1[i]+q2[i]);
    J21[i] = L1*sin(q1[i]) + L2*sin(q1[i]+q2[i]);
    J22[i] = L2*sin(q1[i]+q2[i]);
    detJ[i] = J11[i]*J22[i] - J12[i]*J21[i];
    detJs[i] = if abs(detJ[i]) > 0.02 then detJ[i] else (if detJ[i] >= 0.0 then 0.02 else -0.02);
    N[i] = max(0.0, k_c*(terrainHeight(Fx[i]) - (Fz[i] - r_w)) - d_c*dFz[i]);
    Fcx[i] = clmp(mu*N[i]*tanh((r_w*dth[i] - dFx[i])/0.05), -mu*N[i], mu*N[i]);
    Fxj[i] = ( J22[i]*tau_hip[i] - J21[i]*tau_knee[i])/detJs[i];
    Fzj[i] = (-J12[i]*tau_hip[i] + J11[i]*tau_knee[i])/detJs[i];
  end for;

  // ---- swing/stance foot targets & inverse kinematics ----
  for i in 1:4 loop
    ph[i] = clmp((time - swing_t0[i])/T_swing, 0.0, 1.0);
    foot_tx[i] = if stance[i] > 0.5 then foot_hold_x[i]
                 else swing_from_x[i] + (swing_to_x[i]-swing_from_x[i])*0.5*(1.0 - cos(pi*ph[i]));
    foot_tz[i] = if stance[i] > 0.5 then foot_hold_z[i]
                 else terrainHeight(swing_from_x[i]) + swing_lift*sin(pi*ph[i]);
    dx_ik[i] = foot_tx[i] - Hx[i];
    dz_ik[i] = foot_tz[i] - Hz[i];
    c2[i]    = clmp((dx_ik[i]*dx_ik[i] + dz_ik[i]*dz_ik[i] - L1*L1 - L2*L2)/(2.0*L1*L2), -0.999, 0.999);
    q2d[i]   = -acos(c2[i]);
    q1d[i]   = atan2(dx_ik[i], -dz_ik[i]) - atan2(L2*sin(q2d[i]), L1 + L2*cos(q2d[i]));
    tau_hip[i]  = sat(Kp_j*(q1d[i]-q1[i]) - Kd_j*dq1[i], tau_lim);
    tau_knee[i] = sat(Kp_j*(q2d[i]-q2[i]) - Kd_j*dq2[i], tau_lim);
    tau_w[i]    = if stance[i] > 0.5 then sat(Kw*(v_cmd/r_w - dth[i]), tau_w_lim) else 0.0;
  end for;

  // ---- foot/joint dynamics ----
  for i in 1:4 loop
    ddq1[i] = ( J22[i]*((Fcx[i]+Fxj[i])/m_foot - ax)
              - J12[i]*((N[i]-m_foot*g+Fzj[i])/m_foot - az))/detJs[i];
    ddq2[i] = (-J21[i]*((Fcx[i]+Fxj[i])/m_foot - ax)
              + J11[i]*((N[i]-m_foot*g+Fzj[i])/m_foot - az))/detJs[i];
    ddth[i] = (tau_w[i] - Fcx[i]*r_w)/I_w;
  end for;

  // ---- torso dynamics ----
  ax = (-(Fxj[1]+Fxj[2]+Fxj[3]+Fxj[4]))/m_body;
  az = (-(Fzj[1]+Fzj[2]+Fzj[3]+Fzj[4]) - m_body*g)/m_body;
  ay = (F_push_t
        - (if stance[1]>0.5 then mu*N[1]*tanh(vy/0.05) else 0.0)
        - (if stance[2]>0.5 then mu*N[2]*tanh(vy/0.05) else 0.0)
        - (if stance[3]>0.5 then mu*N[3]*tanh(vy/0.05) else 0.0)
        - (if stance[4]>0.5 then mu*N[4]*tanh(vy/0.05) else 0.0))/m_body;
  apitch = ( hipx[1]*(-Fzj[1]) + hipx[2]*(-Fzj[2]) + hipx[3]*(-Fzj[3]) + hipx[4]*(-Fzj[4])
            - h_hip*((-Fxj[1])+(-Fxj[2])+(-Fxj[3])+(-Fxj[4])) )/I_pitch;
  aroll  = ( laty[1]*(-Fzj[1]) + laty[2]*(-Fzj[2]) + laty[3]*(-Fzj[3]) + laty[4]*(-Fzj[4])
            + h_hip*( (if stance[1]>0.5 then mu*N[1]*tanh(vy/0.05) else 0.0)
                    + (if stance[2]>0.5 then mu*N[2]*tanh(vy/0.05) else 0.0)
                    + (if stance[3]>0.5 then mu*N[3]*tanh(vy/0.05) else 0.0)
                    + (if stance[4]>0.5 then mu*N[4]*tanh(vy/0.05) else 0.0)) )/I_roll;

  // ---- state derivatives ----
  der(x) = vx;       der(vx) = ax;
  der(z) = vz;       der(vz) = az;
  der(pitch) = pitch_d;  der(pitch_d) = apitch;
  der(y) = vy;       der(vy) = ay;
  der(roll_a) = roll_d;  der(roll_d) = aroll;
  for i in 1:4 loop
    der(q1[i])  = dq1[i];   der(dq1[i]) = ddq1[i];
    der(q2[i])  = dq2[i];   der(dq2[i]) = ddq2[i];
    der(th[i])  = dth[i];   der(dth[i]) = ddth[i];
  end for;

  // ---- verification observables ----
  clearance = z - terrainHeight(x);
  max_hip   = max(max(abs(tau_hip[1]),abs(tau_hip[2])), max(abs(tau_hip[3]),abs(tau_hip[4])));
  max_knee  = max(max(abs(tau_knee[1]),abs(tau_knee[2])), max(abs(tau_knee[3]),abs(tau_knee[4])));
  max_wheel = max(max(abs(tau_w[1]),abs(tau_w[2])), max(abs(tau_w[3]),abs(tau_w[4])));
  max_tau   = max(max(max_hip, max_knee), max_wheel);
  max_att   = max(abs(pitch), abs(roll_a));
  path_err  = abs(x - x_ref);

  bounds_ok    = max_tau <= tau_lim + 1.0e-6;
  clearance_ok = clearance >= 0.03;
  attitude_ok  = max_att <= 0.45;
  route_ok     = x >= (x_goal - 0.20);
  tracking_ok  = (time < 13.0) or (path_err <= 0.12);
  finite_ok    = (x == x) and (z == z) and (pitch == pitch) and (roll_a == roll_a)
                 and (max_tau == max_tau) and (clearance == clearance) and (max_att == max_att);

  // ---- assertions ----
  assert(finite_ok, "Non-finite physical/control/estimator value detected");
  assert(z - terrainHeight(x) > 0.0, "Torso-terrain collision");

  annotation(
    experiment(StopTime=20.0, Tolerance=1.0e-4, Interval=0.002),
    Documentation(info="Synchronized state/command/sensor traces retained at 500 Hz over 20 s.
                       Commanded speed numeric value and wheel torque numeric limit are unknown
                       and represented by labeled assumed parameters."));
end WheelLegTraverseF;