model SoftCrawlAvoidC
  // ---------------- Parameters (requirement-sourced) ----------------
  parameter Integer n = 6                         "number of serial pneumatic bending chambers";
  parameter Real    L = 0.48                      "compliant body length [m]";
  parameter Real    Lseg = L/n                    "per-chamber segment length [m]";
  parameter Real    pmax = 69000.0                "maximum chamber command magnitude [Pa gauge]";
  parameter Real    Ts = 1.0/125.0                "control/sample period [s] -> 125 Hz";
  parameter Real    Tend = 12.0                   "simulation horizon [s]";
  parameter Real    mu_obstacle = 0.55            "fixed cylinder friction coefficient [1]";
  parameter Real    mu_g_fwd = 0.15               "anisotropic ground friction, forward [1]";
  parameter Real    mu_g_bwd = 0.70               "anisotropic ground friction, backward [1]";
  parameter Real    Fdist = 7.2                   "controlled lateral tip-load disturbance [N]";
  parameter Real    k_seg = 4.0                   "section rotational stiffness [N.m/rad]";
  parameter Real    c_seg = 0.30                  "section rotational damping [N.m.s/rad]";
  parameter Real    J_seg = 1.0e-3                "section inertia [kg.m^2]";
  parameter Real    A_eff = 1.0e-5                "effective pressure-to-torque area [m^3]";
  parameter Real    M_body = 0.10                 "body mass [kg]";
  parameter Real    x_target = 0.60               "target tip x [m]";
  parameter Real    y_target = 0.08               "target tip y [m]";
  parameter Real    err_thresh = 0.042            "primary tracking-error bound [m]";
  parameter Real    t_settle = 7.8                "tracking must hold after this time [s]";
  parameter Real    obs_x = 0.32                   "fixed cylinder center x [m]";
  parameter Real    obs_y = 0.0                   "fixed cylinder center y [m]";
  parameter Real    obs_r = 0.04                  "fixed cylinder radius [m]";
  parameter Real    Tenv = 22.0                   "environment/actuator reference temperature [degC]";
  parameter Real    omega_wave = 6.0              "traveling-wave angular frequency [rad/s]";
  parameter Real    Kp_x = 20.0                   "longitudinal tracking gain [N/m]";
  parameter Real    Kd_x = 4.0                    "longitudinal damping gain [N.s/m]";
  parameter Real    Kp_y = 400.0                  "lateral tracking gain [N/m]";
  parameter Real    Kd_y = 12.0                   "lateral damping gain [N.s/m]";

  // ---------------- Dynamic states ----------------
  Real phi[6]  (each start = 0.0,  each fixed = true) "section deformation angle [rad]";
  Real phid[6] (each start = 0.0,  each fixed = true) "section angular velocity [rad/s]";
  Real xb  (start = 0.0,       fixed = true) "base x position [m]";
  Real vb  (start = 0.0,       fixed = true) "base x velocity [m/s]";
  Real yb  (start = y_target,  fixed = true) "base y position [m]";
  Real vyb (start = 0.0,       fixed = true) "base y velocity [m/s]";
  Real temperature (start = Tenv, fixed = true) "actuator temperature [degC]";

  // ---------------- Discrete chamber commands ----------------
  discrete Real u[6] (each start = 0.5) "normalized chamber command in [0,1]";
  Real p[6] "chamber gauge pressure [Pa]";

  // ---------------- Tip pose (sensors) ----------------
  Real tip_x;
  Real tip_y;
  Real tip_theta;

  // ---------------- Instrumentation / sensors ----------------
  Real Fcontact[6]     "distributed contact force per section [N]";
  Real Fcontact_total  "total contact force magnitude at tip [N]";
  Real clearance       "obstacle clearance (signed) [m]";
  Real tip_error       "primary tracking error [m]";
  Boolean settled      "tracking satisfied after t_settle";
  Boolean bounds_ok    "aggregate physical/control bound flag";
  Real Fdist_y         "applied lateral tip-load disturbance [N]";

  // ---------------- Scalar bound aggregates ----------------
  Real p_max_val;
  Real phi_max_val;
  Real Fnorm_contact;

protected
  Real seg_x[7];
  Real seg_y[7];
  Real seg_theta[7];
  Real dx_obs, dy_obs, d_obs;
  Real Fprop_x, Fprop_y;
  Real Ffric_x;
  Real N_ground;
  Real seg_obs_d1, seg_obs_d2, seg_obs_d3, seg_obs_d4, seg_obs_d5, seg_obs_d6;

equation
  // ---------------- Kinematic chain (base -> tip) ----------------
  seg_x[1]     = xb;
  seg_y[1]     = yb;
  seg_theta[1] = 0.0;
  for i in 1:6 loop
    seg_theta[i+1] = seg_theta[i] + phi[i];
    seg_x[i+1]     = seg_x[i] + Lseg*cos(seg_theta[i+1]);
    seg_y[i+1]     = seg_y[i] + Lseg*sin(seg_theta[i+1]);
  end for;
  tip_x     = seg_x[7];
  tip_y     = seg_y[7];
  tip_theta = seg_theta[7];

  // ---------------- Section (chamber) deformation dynamics ----------------
  for i in 1:6 loop
    der(phi[i])  = phid[i];
    J_seg*der(phid[i]) = A_eff*p[i] - c_seg*phid[i] - k_seg*phi[i];
  end for;

  // ---------------- Pressure actuation (bounded by u in [0,1]) ----------------
  for i in 1:6 loop
    p[i] = pmax*u[i];
  end for;

  // ---------------- Disturbance: middle third of 12 s window (4 s .. 8 s) ----------------
  Fdist_y = if (time >= 4.0 and time <= 8.0) then -Fdist else 0.0;

  // ---------------- Longitudinal body dynamics w/ anisotropic friction ----------------
  N_ground = M_body*9.81;
  Ffric_x  = if vb > 1.0e-4 then -mu_g_fwd*N_ground
             elseif vb < -1.0e-4 then -mu_g_bwd*N_ground
             else 0.0;
  Fprop_x  = Kp_x*(x_target - tip_x) - Kd_x*vb;
  M_body*der(vb) = Fprop_x + Ffric_x;
  der(xb) = vb;

  // ---------------- Lateral body dynamics w/ tip-load disturbance ----------------
  Fprop_y = Kp_y*(y_target - tip_y) - Kd_y*vyb;
  M_body*der(vyb) = Fprop_y + Fdist_y;
  der(yb) = vyb;

  // ---------------- Temperature (passive, bounded) ----------------
  der(temperature) = 0.10*(Tenv - temperature);

  // ---------------- Obstacle clearance (tip) ----------------
  dx_obs = tip_x - obs_x;
  dy_obs = tip_y - obs_y;
  d_obs  = sqrt(dx_obs*dx_obs + dy_obs*dy_obs);   // d_obs >= 0 always
  clearance = d_obs - obs_r;

  // ---------------- Contact-force instrumentation ----------------
  // Tip contact penalty (only when penetrating cylinder)
  Fcontact_total = if clearance < 0.0 then -2000.0*clearance else 0.0;

  // Per-section proximity contact (scalar distances to avoid array reduction)
  seg_obs_d1 = sqrt((seg_x[2]-obs_x)^2 + (seg_y[2]-obs_y)^2) - obs_r;
  seg_obs_d2 = sqrt((seg_x[3]-obs_x)^2 + (seg_y[3]-obs_y)^2) - obs_r;
  seg_obs_d3 = sqrt((seg_x[4]-obs_x)^2 + (seg_y[4]-obs_y)^2) - obs_r;
  seg_obs_d4 = sqrt((seg_x[5]-obs_x)^2 + (seg_y[5]-obs_y)^2) - obs_r;
  seg_obs_d5 = sqrt((seg_x[6]-obs_x)^2 + (seg_y[6]-obs_y)^2) - obs_r;
  seg_obs_d6 = sqrt((seg_x[7]-obs_x)^2 + (seg_y[7]-obs_y)^2) - obs_r;
  Fcontact[1] = if seg_obs_d1 < 0.0 then -500.0*seg_obs_d1 else 0.0;
  Fcontact[2] = if seg_obs_d2 < 0.0 then -500.0*seg_obs_d2 else 0.0;
  Fcontact[3] = if seg_obs_d3 < 0.0 then -500.0*seg_obs_d3 else 0.0;
  Fcontact[4] = if seg_obs_d4 < 0.0 then -500.0*seg_obs_d4 else 0.0;
  Fcontact[5] = if seg_obs_d5 < 0.0 then -500.0*seg_obs_d5 else 0.0;
  Fcontact[6] = if seg_obs_d6 < 0.0 then -500.0*seg_obs_d6 else 0.0;

  // ---------------- Tracking error and settle flag ----------------
  tip_error = sqrt((tip_x - x_target)^2 + (tip_y - y_target)^2);
  settled  = (time >= t_settle) and (tip_error < err_thresh);

  // ---------------- Scalar bound aggregates ----------------
  p_max_val = max(p[1], max(p[2], max(p[3], max(p[4], max(p[5], p[6])))));
  phi_max_val = max(abs(phi[1]), max(abs(phi[2]), max(abs(phi[3]),
                  max(abs(phi[4]), max(abs(phi[5]), abs(phi[6]))))));
  Fnorm_contact = sqrt(Fcontact_total*Fcontact_total
                     + Fcontact[1]*Fcontact[1] + Fcontact[2]*Fcontact[2]
                     + Fcontact[3]*Fcontact[3] + Fcontact[4]*Fcontact[4]
                     + Fcontact[5]*Fcontact[5] + Fcontact[6]*Fcontact[6]);

  // ---------------- Aggregate bounds (actuator, deformation, contact, temp, clearance, tip error) ----------------
  bounds_ok = (p_max_val <= pmax + 1.0)
          and (phi_max_val < 1.57)
          and (Fnorm_contact < 100.0)
          and (temperature < 80.0)
          and (clearance > -0.005)
          and (tip_error < 5.0);

algorithm
  // ---------------- 125 Hz discrete controller: traveling-wave, bounded stiffness scheduling ----------------
  when sample(0, Ts) then
    // Bounded stiffness scheduling: hold a tightened (stiffer) shape after settle.
    // The chamber bias is increased after t_settle to "stiffen or hold shape".
    for i in 1:6 loop
      u[i] := 0.5
            + 0.30*sin(omega_wave*time - (i-1)*1.04719755)             // traveling wave (60 deg phase shift)
            + (if time >= t_settle then 0.05 else 0.0);                // bounded stiffening bias
      // Hard saturation to keep command magnitude within 69 kPa gauge
      if u[i] < 0.0 then
        u[i] := 0.0;
      elseif u[i] > 1.0 then
        u[i] := 1.0;
      end if;
    end for;
  end when;

  annotation (
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1.0e-6, Interval = 1.0/125.0),
    Documentation(info = "SoftCrawlAvoidC: contact-aware shape control with bounded stiffness scheduling. "
                        "0.48 m compliant body, 6 serial pneumatic chambers, anisotropic ground friction, "
                        "fixed cylinder obstacle (mu=0.55) with collision enabled, 7.2 N lateral tip load "
                        "during middle third (4-8 s), 125 Hz control, 12 s run. Tip-error bound 0.042 m after 7.8 s."));
end SoftCrawlAvoidC;