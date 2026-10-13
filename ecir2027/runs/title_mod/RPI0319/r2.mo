model StewartTraceA
  "Closed-chain Stewart-type hexapod tracing a 0.10 m circle; 80 Hz, 8 s, 5 N mid-third load."
  import Modelica.Constants.pi;

  // ===== Plant parameters =====
  parameter Real m_p(unit="kg")     = 36.0  "Platform mass";
  parameter Real r_base(unit="m")   = 0.45  "Base anchor radius";
  parameter Real r_plat(unit="m")    = 0.32  "Platform anchor radius";
  parameter Real h0(unit="m")       = 0.68  "Nominal platform height";
  parameter Real L_min(unit="m")    = 0.55  "Minimum strut length";
  parameter Real L_max(unit="m")    = 0.85  "Maximum strut length";
  parameter Real F_max(unit="N")    = 3024.0 "Per-strut force command limit";
  parameter Real g_acc(unit="m/s2") = 9.81  "Gravity";

  // ===== Controller parameters =====
  parameter Real Kp(unit="N/m")   = 12000.0 "Strut position gain";
  parameter Real Kd(unit="N.s/m") = 400.0   "Strut damping gain";
  parameter Real track_freq(unit="Hz")   = 0.20 "Circle frequency";
  parameter Real track_radius(unit="m")   = 0.10 "Circle radius";

  // ===== Obstacle =====
  parameter Real obs_x(unit="m") = 0.55 "Obstacle x";
  parameter Real obs_y(unit="m") = 0.0  "Obstacle y";

  // ===== Scenario =====
  parameter Real T_end(unit="s") = 8.0 "Scenario duration";
  parameter Real fs(unit="Hz")   = 80.0 "Trace sample rate";

  parameter Real theta[6](unit="rad") = {0,1,2,3,4,5}*(pi/3) "Anchor angles";

  // ===== Continuous states (platform pose/velocity) =====
  Real x(unit="m", start=0.0, fixed=true)  "Platform x";
  Real y(unit="m", start=0.0, fixed=true)  "Platform y";
  Real z(unit="m", start=h0, fixed=true)   "Platform z";
  Real vx(unit="m/s", start=0.0, fixed=true);
  Real vy(unit="m/s", start=0.0, fixed=true);
  Real vz(unit="m/s", start=0.0, fixed=true);

  // ===== Strut quantities (encoders read L; commands are Lcmd) =====
  Real L[6](unit="m")      "Actual strut length (encoder)";
  Real Lcmd[6](unit="m")  "Commanded strut length (IK)";
  Real Lerr[6](unit="m")  "Length error";
  Real Ldot[6](unit="m/s") "Strut length rate";
  Real ux[6], uy[6], uz[6] "Strut unit vectors";
  Real F[6](unit="N")     "Limited strut force";
  Real Fraw[6](unit="N")  "Raw strut force";

  // ===== Trajectory / errors =====
  Real xd(unit="m"), yd(unit="m"), zd(unit="m");
  Real track_err(unit="m")            "Output path error";
  Real track_err_post(unit="m")       "Path error after 5.2 s";

  // ===== Disturbance =====
  Real Fdist_x(unit="N") "Output load disturbance (x)";

  // ===== Obstacle / clearance =====
  Real dist_obs(unit="m")  "Distance platform center to obstacle";
  Real clearance(unit="m") "Clearance = dist_obs - r_plat";

  // ===== Singularity margin =====
  Real horiz_proj[6];
  Real sing_margin "Min horizontal projection of strut unit vectors";

  // ===== Closure stabilization residual =====
  Real closure_err(unit="m") "Strut-space IK residual";

  // ===== Bounds (observable) =====
  Real L_min_now(unit="m"), L_max_now(unit="m"), F_max_now(unit="N");

  // ===== Sampled synchronized traces (80 Hz) =====
  discrete Real x_s(unit="m"), y_s(unit="m"), z_s(unit="m");
  discrete Real vx_s(unit="m/s"), vy_s(unit="m/s"), vz_s(unit="m/s");
  discrete Real L_s[6](unit="m");
  discrete Real Lcmd_s[6](unit="m");
  discrete Real F_s[6](unit="N");
  discrete Real track_err_s(unit="m");
  discrete Real closure_err_s(unit="m");
  discrete Real sing_margin_s;
  discrete Real clearance_s(unit="m");

equation
  // ----- Desired output pose (planar circle at nominal height) -----
  xd = track_radius*cos(2*pi*track_freq*time);
  yd = track_radius*sin(2*pi*track_freq*time);
  zd = h0;

  // ----- Inverse kinematics: desired pose -> commanded strut lengths -----
  for i in 1:6 loop
    Lcmd[i] = sqrt((r_plat*cos(theta[i]) + xd - r_base*cos(theta[i]))^2 +
                   (r_plat*sin(theta[i]) + yd - r_base*sin(theta[i]))^2 +
                   (zd)^2 + 1e-12);
  end for;

  // ----- Forward kinematics: actual pose -> strut lengths, unit vectors -----
  for i in 1:6 loop
    L[i] = sqrt((r_plat*cos(theta[i]) + x - r_base*cos(theta[i]))^2 +
                (r_plat*sin(theta[i]) + y - r_base*sin(theta[i]))^2 +
                (z)^2 + 1e-12);
    ux[i] = (r_plat*cos(theta[i]) + x - r_base*cos(theta[i]))/L[i];
    uy[i] = (r_plat*sin(theta[i]) + y - r_base*sin(theta[i]))/L[i];
    uz[i] = (z)/L[i];
    Lerr[i] = Lcmd[i] - L[i];
    Ldot[i] = ux[i]*vx + uy[i]*vy + uz[i]*vz;
    Fraw[i] = Kp*Lerr[i] - Kd*Ldot[i];
    F[i] = if Fraw[i] >  F_max then  F_max
           else if Fraw[i] < -F_max then -F_max
           else Fraw[i];
    horiz_proj[i] = sqrt(ux[i]^2 + uy[i]^2 + 1e-12);
  end for;

  // ----- Disturbance: 5 N during middle third of 8 s, i.e. [8/3, 16/3] -----
  Fdist_x = if (time >= 8.0/3.0 and time <= 16.0/3.0) then 5.0 else 0.0;

  // ----- Platform dynamics (closed-chain: 6 struts + load + gravity) -----
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (F[1]*ux[1] + F[2]*ux[2] + F[3]*ux[3] +
             F[4]*ux[4] + F[5]*ux[5] + F[6]*ux[6] + Fdist_x)/m_p;
  der(vy) = (F[1]*uy[1] + F[2]*uy[2] + F[3]*uy[3] +
             F[4]*uy[4] + F[5]*uy[5] + F[6]*uy[6])/m_p;
  der(vz) = (F[1]*uz[1] + F[2]*uz[2] + F[3]*uz[3] +
             F[4]*uz[4] + F[5]*uz[5] + F[6]*uz[6] - m_p*g_acc)/m_p;

  // ----- Tracking error (direct output-pose measurement) -----
  track_err = sqrt((x - xd)^2 + (y - yd)^2 + (z - zd)^2 + 1e-12);
  track_err_post = if time > 5.2 then track_err else 0.0;

  // ----- Obstacle clearance -----
  dist_obs  = sqrt((x - obs_x)^2 + (y - obs_y)^2 + 1e-12);
  clearance = dist_obs - r_plat;

  // ----- Singularity margin -----
  sing_margin = min({horiz_proj[1],horiz_proj[2],horiz_proj[3],
                     horiz_proj[4],horiz_proj[5],horiz_proj[6]});

  // ----- Closure stabilization residual (strut-space IK consistency) -----
  closure_err = sqrt((Lerr[1]^2 + Lerr[2]^2 + Lerr[3]^2 +
                      Lerr[4]^2 + Lerr[5]^2 + Lerr[6]^2)/6 + 1e-12);

  // ----- Joint / effort bounds (observable) -----
  L_min_now = min({L[1],L[2],L[3],L[4],L[5],L[6]});
  L_max_now = max({L[1],L[2],L[3],L[4],L[5],L[6]});
  F_max_now = max({abs(F[1]),abs(F[2]),abs(F[3]),
                   abs(F[4]),abs(F[5]),abs(F[6])});

  // ----- Synchronized 80 Hz trace retention -----
  when sample(0, 1/fs) then
    x_s = x;  y_s = y;  z_s = z;
    vx_s = vx; vy_s = vy; vz_s = vz;
    L_s[1] = L[1]; L_s[2] = L[2]; L_s[3] = L[3];
    L_s[4] = L[4]; L_s[5] = L[5]; L_s[6] = L[6];
    Lcmd_s[1] = Lcmd[1]; Lcmd_s[2] = Lcmd[2]; Lcmd_s[3] = Lcmd[3];
    Lcmd_s[4] = Lcmd[4]; Lcmd_s[5] = Lcmd[5]; Lcmd_s[6] = Lcmd[6];
    F_s[1] = F[1]; F_s[2] = F[2]; F_s[3] = F[3];
    F_s[4] = F[4]; F_s[5] = F[5]; F_s[6] = F[6];
    track_err_s   = track_err;
    closure_err_s = closure_err;
    sing_margin_s = sing_margin;
    clearance_s   = clearance;
  end when;

  // ----- Requirement assertions -----
  assert(L_min_now >= L_min - 1e-6, "Strut length below joint minimum");
  assert(L_max_now <= L_max + 1e-6, "Strut length above joint maximum");
  assert(F_max_now <= F_max + 1.0,  "Strut effort exceeded command limit");
  assert(clearance > 0.0,           "Obstacle clearance violated");
  assert(sing_margin > 0.02,        "Near-kinematic singularity");
  assert(if time > 5.2 then track_err < 0.011 else true,
         "Primary tracking error after 5.2 s exceeds 0.011 m");

end StewartTraceA;