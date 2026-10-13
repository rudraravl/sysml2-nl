model DeltaPressB
  "Closed-chain Delta press mechanism with hybrid position/force control.
   Unknown geometric and inertial values required for a compilable plant
   are explicitly assumed and labeled (assumed, unknown)."

  // ----- Geometry (specified where given) -----
  parameter Modelica.SIunits.Length L1 = 0.32 "upper arm length (specified)";
  parameter Modelica.SIunits.Length L2 = 0.60 "forearm length (specified)";
  parameter Modelica.SIunits.Length Rb = 0.12 "base circumradius (assumed, unknown)";
  parameter Modelica.SIunits.Length Rp = 0.05 "platform circumradius (assumed, unknown)";
  parameter Modelica.SIunits.Length h_rod =
    sqrt(max(L2^2 - (Rb - Rp)^2, 1.0e-6))
    "nominal vertical projection of forearm (derived)";

  // ----- Workpiece / pose -----
  parameter Modelica.SIunits.Length z_work = 0.70
    "workpiece top height measured downward from base (assumed, unknown)";
  parameter Modelica.SIunits.Length z_set  = 0.705
    "downward position command just past workpiece (assumed, unknown)";

  // ----- Inertia (specified where given) -----
  parameter Modelica.SIunits.Mass m_p = 3.0 "platform mass (specified)";
  parameter Modelica.SIunits.MomentOfInertia J_a = 0.03
    "upper arm inertia about base joint (assumed, unknown)";
  parameter Modelica.SIunits.Acceleration g_acc = 9.81
    "gravational acceleration (assumed, unknown)";

  // ----- Actuator -----
  parameter Modelica.SIunits.Torque tau_max = 36.9
    "allowed command magnitude per actuator (specified)";

  // ----- Contact -----
  parameter Modelica.SIunits.TranslationalSpringConstant kc = 200.0e3
    "contact stiffness (specified)";
  parameter Modelica.SIunits.TranslationalDampingConstant cc = 2.0e3
    "contact damping (specified)";
  parameter Real mu = 0.70 "friction coefficient (specified)";
  parameter Modelica.SIunits.Velocity v_lock = 1.0e-3
    "lock velocity threshold (assumed, unknown)";
  parameter Modelica.SIunits.Velocity v_smooth = 1.0e-4
    "Coulomb smoothing band (assumed, unknown)";

  // ----- Forearm closure (forearm modeled as stiff axial spring-damper) -----
  parameter Modelica.SIunits.TranslationalSpringConstant kL = 5.0e6
    "forearm axial stiffness (assumed, unknown)";
  parameter Modelica.SIunits.TranslationalDampingConstant cL = 5.0e2
    "forearm axial damping (assumed, unknown)";

  // ----- Disturbance -----
  parameter Modelica.SIunits.Force dF = 12.6
    "controlled force change injected in middle third (specified)";
  parameter Modelica.SIunits.Time t_end = 10.0 "mission duration (specified)";

  // ----- Control loop -----
  parameter Modelica.SIunits.Frequency fs = 100.0 "loop rate (specified)";
  parameter Modelica.SIunits.Force F_set = 25.0
    "contact force setpoint (assumed, unknown)";
  parameter Real Kp_pos = 1500.0 "position proportional gain (assumed, unknown)";
  parameter Real Kd_pos = 120.0  "position derivative gain (assumed, unknown)";
  parameter Real Kp_f   = 8.0   "force proportional gain (assumed, unknown)";
  parameter Real Ki_f   = 120.0 "force integral gain (assumed, unknown)";
  parameter Modelica.SIunits.Force F_contact_thresh = 0.5
    "contact detection threshold for mode blend (assumed, unknown)";

  // ----- Continuous states -----
  Modelica.SIunits.Angle q[3]          "upper arm angle from horizontal (downward increases q)";
  Modelica.SIunits.AngularVelocity w[3];
  Modelica.SIunits.Position z_p        "platform vertical position (downward positive)";
  Modelica.SIunits.Velocity vz_p;
  Modelica.SIunits.Position x_p        "platform lateral (tangential) position";
  Modelica.SIunits.Velocity vx_p;
  Modelica.SIunits.Force F_contact_meas "filtered contact-force sensor";

  // ----- Algebraic / kinematic -----
  Modelica.SIunits.Position z_chain[3]  "elbow (chain-end) vertical position";
  Modelica.SIunits.Velocity vz_chain[3];
  Modelica.SIunits.Force F_rod[3]      "forearm axial force on platform (downward positive)";
  Modelica.SIunits.Force F_contact     "normal contact force (>=0)";
  Modelica.SIunits.Force F_tan         "tangential friction force on platform";
  Modelica.SIunits.Velocity v_slip     "tangential slip velocity";
  Modelica.SIunits.Force F_dist        "injected disturbance force";
  Modelica.SIunits.Torque tau_cmd[3]   "raw commanded actuator torque";
  Modelica.SIunits.Torque tau[3]       "saturated applied actuator torque";

  // ----- Monitors / feedback signals -----
  Modelica.SIunits.Length closure_error "max forearm closure mismatch";
  Modelica.SIunits.Length tracking_error "primary tracking error (closure)";
  Modelica.SIunits.Length pos_error     "position command error";
  Real torque_violation                 "fractional overshoot of torque bound (0 if within)";
  Real contact_band_violation           "fractional deviation from force band (0 if within)";
  Boolean locked                         "locked-contact flag";
  Boolean in_contact;
  Boolean in_middle_third;
  Real sanity_check "finite-state indicator: 0 nominal, non-finite if blowup";

  // ----- Discrete (100 Hz) controller state -----
  discrete Real e_z_d;
  discrete Real e_f_d;
  discrete Real integ_f(start = 0.0);
  discrete Real z_p_d(start = 0.0);
  discrete Real vz_p_d(start = 0.0);
  discrete Real F_contact_d(start = 0.0);
  discrete Real mode_blend(start = 0.0);

initial equation
  q[1] = 0.10;
  q[2] = 0.10;
  q[3] = 0.10;
  w[1] = 0.0;
  w[2] = 0.0;
  w[3] = 0.0;
  z_p = L1*sin(0.10) + h_rod;
  vz_p = 0.0;
  x_p = 0.0;
  vx_p = 0.0;
  F_contact_meas = 0.0;

equation
  // ---- Chain-end kinematics (q measured from horizontal, downward increases q) ----
  for i in 1:3 loop
    z_chain[i]  = L1*sin(q[i]);
    vz_chain[i] = L1*cos(q[i])*w[i];
  end for;

  // ---- Forearm as stiff axial spring-damper (closure constraint) ----
  for i in 1:3 loop
    F_rod[i] = kL*(z_chain[i] - z_p + h_rod) + cL*(vz_chain[i] - vz_p);
  end for;

  // ---- Arm rotational dynamics ----
  for i in 1:3 loop
    der(q[i])  = w[i];
    J_a*der(w[i]) = tau[i] - L1*cos(q[i])*F_rod[i];
  end for;

  // ---- Platform vertical dynamics (downward positive) ----
  der(z_p) = vz_p;
  m_p*der(vz_p) = (F_rod[1] + F_rod[2] + F_rod[3]) + m_p*g_acc + F_dist - F_contact;

  // ---- Platform lateral dynamics (tangential slip) ----
  der(x_p) = vx_p;
  m_p*der(vx_p) = F_tan;
  v_slip = vx_p;

  // ---- Normal contact force (one-sided Hunt-Crossley style) ----
  in_contact = (z_p - z_work) > 0.0;
  if (z_p - z_work) > 0.0 then
    F_contact = max(0.0, kc*(z_p - z_work) + cc*vz_p);
  else
    F_contact = 0.0;
  end if;

  // ---- Tangential Coulomb friction (smoothed, only when in contact) ----
  if F_contact > 0.0 then
    F_tan = -mu*F_contact*tanh(v_slip / v_smooth);
  else
    F_tan = 0.0;
  end if;

  locked = (F_contact > 0.0) and (abs(v_slip) < v_lock);

  // ---- Disturbance injection: middle third of the 10 s mission ----
  in_middle_third = (time >= t_end/3.0) and (time <= 2.0*t_end/3.0);
  F_dist = if in_middle_third then dF else 0.0;

  // ---- Contact-force sensor (first-order filter) ----
  der(F_contact_meas) = 50.0*(F_contact - F_contact_meas);

  // ---- Closure / tracking errors ----
  closure_error = max(abs(z_p - z_chain[1] - h_rod),
               max(abs(z_p - z_chain[2] - h_rod),
                   abs(z_p - z_chain[3] - h_rod)));
  tracking_error = closure_error;
  pos_error = abs(z_set - z_p);

  // ---- Sampled hybrid controller at 100 Hz ----
  when sample(0, 1.0/fs) then
    z_p_d         = z_p;
    vz_p_d        = vz_p;
    F_contact_d   = F_contact_meas;
    e_z_d         = z_set - z_p_d;
    e_f_d         = F_set - F_contact_d;
    mode_blend    = if F_contact_d > F_contact_thresh then 1.0 else 0.0;
    integ_f       = integ_f + e_f_d*(1.0/fs);
  end when;

  // ---- Torque command: position PD in free space, force PI blended in contact ----
  for i in 1:3 loop
    tau_cmd[i] = (1.0/3.0)*(Kp_pos*e_z_d - Kd_pos*vz_p_d)
               + (1.0/3.0)*mode_blend*(Kp_f*e_f_d + Ki_f*integ_f);
    tau[i] = max(-tau_max, min(tau_max, tau_cmd[i]));
  end for;

  // ---- Bound / band monitors ----
  torque_violation =
    max(0.0, max(abs(tau_cmd[1]), max(abs(tau_cmd[2]), abs(tau_cmd[3]))) - tau_max)
      / max(tau_max, 1.0e-9);

  contact_band_violation = abs(F_contact_meas - F_set) / max(F_set, 1.0e-9);

  // ---- Sanity indicator (0 nominal; becomes non-finite if any signal blows up) ----
  sanity_check = (z_p*z_p + vz_p*vz_p + x_p*x_p + vx_p*vx_p
                + F_contact*F_contact + F_tan*F_tan
                + tau[1]*tau[1] + tau[2]*tau[2] + tau[3]*tau[3]
                + integ_f*integ_f) * 0.0;

end DeltaPressB;