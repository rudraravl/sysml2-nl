model BallScrewTorqueF
  "Electromechanical robotic actuator: 24V motor driving 18 kg carriage
   through a ball screw with belt reduction, backlash, Coulomb friction,
   compliant load contact, cascaded current/force control, 20 s run.
   Values not specified in the requirement are marked as assumed and
   chosen to keep the model well-posed and simulatable."

  // -------- Supply and limits --------
  parameter Real V_supply = 24.0  "V  motor supply (given)";
  parameter Real V_max    = 29.3  "V  voltage limit (given)";

  // -------- Motor electrical (assumed) --------
  parameter Real Ra = 1.2    "ohm armature resistance";
  parameter Real La = 1.5e-3 "H  armature inductance";
  parameter Real Ke = 0.052  "V.s/rad back-EMF constant";
  parameter Real Kt = 0.052  "N.m/A  torque constant";

  // -------- Motor mechanical (assumed) --------
  parameter Real Jm = 1.0e-4 "kg.m2 motor inertia";
  parameter Real Bm = 1.0e-6 "N.m.s/rad motor viscous friction";

  // -------- Belt reduction with backlash (ratio assumed) --------
  parameter Real N_belt = 3.0     "belt reduction ratio (assumed)";
  parameter Real kbelt  = 20.0    "N.m/rad belt torsional stiffness (assumed)";
  parameter Real bb     = 4.0e-3  "rad backlash half-width (assumed)";

  // -------- Ball screw (pitch given) --------
  parameter Real pitch   = 0.005   "m/rev screw pitch (given)";
  parameter Real lead    = pitch/(2.0*Modelica.Constants.pi) "m/rad screw lead";
  parameter Real Js      = 1.0e-4  "kg.m2 screw inertia (assumed)";
  parameter Real Bs      = 1.0e-6  "N.m.s/rad screw viscous friction (assumed)";
  parameter Real kscrew  = 5.0e5   "N/m   screw-nut compliance (assumed)";
  parameter Real dscrew  = 200.0   "N.s/m screw-nut damping (assumed)";

  // -------- Carriage (mass given) --------
  parameter Real m_c    = 18.0    "kg  carriage mass (given)";
  parameter Real b_c    = 5.0     "N.s/m carriage viscous (assumed)";
  parameter Real Fcoul  = 1.0     "N   Coulomb friction magnitude (assumed)";
  parameter Real x_min  = 0.0     "m   travel lower bound (given, 0.65 m travel)";
  parameter Real x_max  = 0.65    "m   travel upper bound (given)";
  parameter Real k_stop = 1.0e6   "N/m soft-stop stiffness (assumed)";
  parameter Real d_stop = 200.0   "N.s/m soft-stop damping (assumed)";

  // -------- Compliant load (assumed) --------
  parameter Real m_l = 2.0   "kg   load mass (assumed)";
  parameter Real b_l = 1.0   "N.s/m load viscous (assumed)";
  parameter Real kc  = 1.0e5 "N/m  contact stiffness (assumed)";
  parameter Real dc  = 50.0  "N.s/m contact damping (assumed)";

  // -------- Thermal (assumed) --------
  parameter Real Cth  = 200.0  "J/K thermal capacitance (assumed)";
  parameter Real Rth  = 1.0    "K/W thermal resistance (assumed)";
  parameter Real Tamb = 298.15 "K  ambient temperature (assumed)";

  // -------- Control gains (assumed, tuned for stable tracking) --------
  parameter Real Kp_f = 0.05   "A/N     force-loop proportional gain";
  parameter Real Ki_f = 0.4    "A/(N.s) force-loop integral gain";
  parameter Real Kp_c = 6.0    "V/A     current-loop proportional gain";
  parameter Real Ki_c = 150.0  "V/(A.s) current-loop integral gain";

  // -------- Command and disturbance --------
  parameter Real F_cmd_1 = 30.0 "N intermediate force command (assumed)";
  parameter Real F_cmd_2 = 50.0 "N final force command (assumed)";
  parameter Real F_dist  = 21.8 "N disturbance magnitude (given)";

  // -------- State variables --------
  Real i(start=0.0)       "A     motor current";
  Real wm(start=0.0)      "rad/s motor angular velocity";
  Real theta_m(start=0.0) "rad   motor angle";
  Real ws(start=0.0)      "rad/s screw angular velocity";
  Real theta_s(start=0.0) "rad   screw angle";
  Real x_c(start=0.0)     "m     carriage position";
  Real v_c(start=0.0)     "m/s   carriage velocity";
  Real x_l(start=0.0)     "m     load position";
  Real v_l(start=0.0)     "m/s   load velocity";
  Real T(start=298.15)    "K     motor temperature";
  Real integ_f(start=0.0) "A.s   force-loop integrator state";
  Real integ_c(start=0.0) "V.s   current-loop integrator state";

  // -------- Intermediate variables (observable) --------
  Real u              "V    applied motor voltage";
  Real u_unlim        "V    unlimited commanded voltage";
  Real F_cmd          "N    force command";
  Real i_cmd          "A    current command from force loop";
  Real F_dist_applied "N    applied disturbance load";
  Real tau_belt       "N.m  belt transmitted torque (motor side)";
  Real tau_screw_in   "N.m  torque applied to screw by belt";
  Real F_screw        "N    screw-nut transmitted force (transmission side 1)";
  Real F_contact      "N    carriage-load contact force (transmission side 2)";
  Real F_coulomb      "N    carriage Coulomb friction";
  Real F_stop         "N    travel-limit soft-stop force";
  Real F_cmd_err      "N    force tracking error";
  Real delta_belt     "rad  belt relative angle (motor/N - screw)";
  Real phi_belt       "rad  belt deadzone output";
  Real delta_screw    "m    screw-nut deflection (lead*theta_s - x_c)";
  Real upper_active   "soft-stop upper activation";
  Real lower_active   "soft-stop lower activation";
  Real P_diss         "W    dissipated power";
  Real tracking_err   "N    |F_cmd - F_contact| (verification)";

  // Bound helpers for verification
  Real abs_u;
  Real abs_delta_screw;
  Real abs_delta_belt;
  Real abs_F_contact;

equation
  // ---------- Command profile (smooth, event-free) ----------
  F_cmd = F_cmd_1 * 0.5*(1.0 + Modelica.Math.tanh((time - 5.0)/0.05))
                  * 0.5*(1.0 - Modelica.Math.tanh((time - 10.0)/0.05))
        + F_cmd_2 * 0.5*(1.0 + Modelica.Math.tanh((time - 10.0)/0.05));

  // Disturbance during the middle third (20/3 .. 40/3 s), event-free
  F_dist_applied = F_dist * ( 0.5*(1.0 + Modelica.Math.tanh((time - 20.0/3.0)/0.05))
                            - 0.5*(1.0 + Modelica.Math.tanh((time - 40.0/3.0)/0.05)) );

  // ---------- Motor electrical dynamics ----------
  der(i) = (u - Ra*i - Ke*wm)/La;

  // ---------- Motor mechanical dynamics ----------
  der(wm)  = (Kt*i - Bm*wm - tau_belt/N_belt)/Jm;
  der(theta_m) = wm;

  // ---------- Belt reduction with backlash (smooth deadzone) ----------
  delta_belt = theta_m/N_belt - theta_s;
  phi_belt = delta_belt - (bb*0.5)*Modelica.Math.tanh(delta_belt/1.0e-3);
  tau_belt = kbelt * phi_belt;
  tau_screw_in = tau_belt;

  // ---------- Screw dynamics ----------
  delta_screw = lead*theta_s - x_c;
  F_screw = kscrew*delta_screw + dscrew*(lead*ws - v_c);
  der(ws) = (tau_screw_in - F_screw*lead - Bs*ws)/Js;
  der(theta_s) = ws;

  // ---------- Carriage Coulomb friction ----------
  F_coulomb = Fcoul * Modelica.Math.tanh(v_c/1.0e-2);

  // ---------- Travel soft stops (event-free) ----------
  upper_active = 0.5*(1.0 + Modelica.Math.tanh((x_c - x_max)/1.0e-3));
  lower_active = 0.5*(1.0 + Modelica.Math.tanh((x_min - x_c)/1.0e-3));
  F_stop = k_stop*(lower_active*(x_min - x_c) - upper_active*(x_c - x_max))
         - d_stop*v_c*(lower_active + upper_active);

  // ---------- Carriage dynamics ----------
  der(v_c) = (F_screw - F_contact - b_c*v_c - F_coulomb + F_stop)/m_c;
  der(x_c) = v_c;

  // ---------- Compliant contact (bilateral spring-damper) ----------
  F_contact = kc*(x_c - x_l) + dc*(v_c - v_l);

  // ---------- Load dynamics with disturbance ----------
  der(v_l) = (F_contact - b_l*v_l - F_dist_applied)/m_l;
  der(x_l) = v_l;

  // ---------- Thermal dynamics ----------
  P_diss = i*i*Ra + Fcoul*abs(v_c) + b_c*v_c*v_c + b_l*v_l*v_l;
  der(T) = (P_diss - (T - Tamb)/Rth)/Cth;

  // ---------- Force (outer) loop ----------
  F_cmd_err = F_cmd - F_contact;
  der(integ_f) = F_cmd_err;
  i_cmd = 20.0 * Modelica.Math.tanh((Kp_f*F_cmd_err + Ki_f*integ_f)/20.0);

  // ---------- Current (inner) loop ----------
  u_unlim = Kp_c*(i_cmd - i) + Ki_c*integ_c + Ke*wm;
  // Anti-windup: stop integrating when voltage saturates
  der(integ_c) = (i_cmd - i)*(1.0 - Modelica.Math.tanh(u_unlim/V_max)
                              *Modelica.Math.tanh(u_unlim/V_max));
  // Saturate voltage (smooth, event-free, bounded by V_max)
  u = V_max * Modelica.Math.tanh(u_unlim/V_max);

  // ---------- Verification observation helpers ----------
  abs_u            = abs(u);
  abs_delta_screw  = abs(delta_screw);
  abs_delta_belt   = abs(delta_belt);
  abs_F_contact    = abs(F_contact);
  tracking_err     = abs(F_cmd - F_contact);

  // ---------- Verification bounds (no-event, non-blocking assertions) ----------
  assert(noEvent(abs_u <= V_max + 1.0e-3),
         "Electrical bound violated: motor voltage exceeds limit");
  assert(noEvent(i <= 25.0 + 1.0e-3),
         "Electrical bound violated: motor current exceeds 25 A");
  assert(noEvent(T < 400.0),
         "Thermal bound violated: temperature exceeds 400 K");
  assert(noEvent(x_c >= x_min - 1.0e-3 and x_c <= x_max + 1.0e-3),
         "Joint/travel bound violated: carriage outside 0..0.65 m");
  assert(noEvent(abs_delta_screw <= 2.0e-3),
         "Transmission-deflection bound violated: screw-nut deflection > 2 mm");
  assert(noEvent(abs_delta_belt <= 5.0e-2),
         "Transmission-deflection bound violated: belt deflection > 0.05 rad");
  assert(noEvent(abs_F_contact <= 200.0),
         "Contact-force bound violated: |F_contact| > 200 N");
  assert(noEvent(time < 13.0 or tracking_err <= 1.6),
         "Verification failed: primary tracking error exceeds 1.6 N after 13 s");
  assert(noEvent(i == i and wm == wm and u == u and x_c == x_c
                 and F_contact == F_contact and T == T),
         "Numerical integrity violated: NaN detected");

  annotation (
    Documentation(info = "Standalone plant+controller model for an electromechanical
      ball-screw robotic actuator tracking an output force command against a
      compliant load. Designed for direct simulation and FMI 2.0 Co-Simulation
      export. Run stop time = 20 s with output interval 0.002 s (500 Hz)."),
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1.0e-5,
               Interval = 0.002));
end BallScrewTorqueF;