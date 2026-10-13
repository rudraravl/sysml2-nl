model BLDCWheelPositionD
  /* Instrumented electromechanical robotic actuator.
     48 V three-phase PM motor (4 pole pairs) -> 9:1 gearbox -> 0.12 m wheel.
     "0.12 m wheel" interpreted here as wheel diameter (radius 0.06 m); any
     other interpretation is unknown and not fabricated.
     Cascaded PI current (inner) and position (outer) control with conditional
     anti-windup, sampled at 200 Hz for 14 s. Output load disturbance 8 N applied
     during the middle third of the run. Rigid output with spring-damper collision
     stops at travel limits. */

  // ---- Physical plant parameters (only request-stated facts are bound) ----
  parameter Real V_bus        = 48.0  "V DC bus supply (request-stated)";
  parameter Real R_batt       = 0.05  "Ohm battery internal resistance";
  parameter Real R_winding    = 0.20  "Ohm per-phase winding resistance (unknown->assumed)";
  parameter Real L_q          = 0.5e-3 "H q-axis inductance (unknown->assumed)";
  parameter Real Ke           = 0.05  "V/(rad/s electrical) back-EMF constant (unknown->assumed)";
  parameter Real Kt           = 0.05  "N.m/A torque constant (unknown->assumed, Kt≈Ke)";
  parameter Integer p         = 4     "pole pairs (request-stated)";
  parameter Real N            = 9.0   "gear ratio (request-stated)";
  parameter Real d_wheel      = 0.12  "m wheel diameter (request-stated 0.12 m wheel)";
  parameter Real r_wheel      = d_wheel/2 "m wheel radius";
  parameter Real J_m          = 1.0e-5 "kg.m2 motor inertia (unknown->assumed)";
  parameter Real J_l          = 1.0e-2 "kg.m2 output-side inertia (unknown->assumed)";
  parameter Real b_m          = 1.0e-6 "N.m.s/rad motor viscous friction (unknown->assumed)";
  parameter Real b_l          = 1.0e-3 "N.m.s/rad output viscous friction (unknown->assumed)";
  parameter Real m_load       = 2.0   "kg effective load mass (unknown->assumed)";
  parameter Real g_acc        = 9.81  "m/s2 gravity";
  parameter Real T_amb        = 25.0  "degC ambient winding temperature (unknown->assumed)";
  parameter Real Rth          = 1.0   "K/W winding-to-ambient thermal resistance (unknown->assumed)";
  parameter Real Cth          = 5.0   "J/K winding thermal capacitance (unknown->assumed)";

  // ---- Limits and bounds ----
  parameter Real I_max        = 30.0  "A phase current limit (unknown->assumed)";
  parameter Real V_lim        = V_bus "V q-axis voltage limit (request-stated bus)";
  parameter Real theta_max    = 3.14159265358979 "rad output travel limit (unknown->assumed)";
  parameter Real k_stop       = 1.0e4 "N.m/rad collision stiffness (unknown->assumed)";
  parameter Real d_stop       = 1.0e2 "N.m.s/rad collision damping (unknown->assumed)";
  parameter Real T_max        = 80.0  "degC winding temperature bound (unknown->assumed)";
  parameter Real target_pos   = 1.2   "rad nonzero output target (unknown->assumed nonzero)";
  parameter Real err_bound    = 0.03  "rad final tracking error bound (request-stated)";
  parameter Real F_disturb    = 8.0   "N output load disturbance (request-stated)";

  // ---- Control parameters ----
  parameter Real Ts           = 0.005 "s control period (200 Hz, request-stated)";
  parameter Real t_end        = 14.0  "s run length (request-stated)";
  parameter Real Kp_pos       = 10.0  "position proportional gain";
  parameter Real Ki_pos       = 100.0 "position integral gain";
  parameter Real Kp_cur       = 0.5   "current proportional gain";
  parameter Real Ki_cur       = 200.0 "current integral gain";

  // ---- Continuous states ----
  Real theta_m(start=0.0)    "rad motor shaft angle";
  Real omega_m(start=0.0)    "rad/s motor shaft speed";
  Real iq(start=0.0)         "A q-axis phase current (measured)";
  Real T_winding(start=T_amb)"degC winding temperature (measured)";

  // ---- Derived / observed quantities ----
  Real theta_out              "rad output position (measured)";
  Real omega_out             "rad/s output velocity (measured)";
  Real V_bus_actual          "V battery terminal voltage";
  Real I_batt                "A battery current";
  Real tau_em                "N.m motor electromagnetic torque";
  Real tau_grav_out          "N.m gravity load torque at output";
  Real tau_disturb_out       "N.m disturbance torque at output";
  Real tau_stop_out          "N.m collision-stop torque at output";
  Real error_pos             "rad primary tracking error";
  Real vq                    "V q-axis commanded voltage (held)";
  Real iq_ref                "A q-axis current reference (held)";
  Real omega_e               "rad/s electrical speed";

  // ---- Discrete controller state ----
  discrete Real integ_pos(start=0.0) "position integrator";
  discrete Real integ_cur(start=0.0) "current integrator";
  discrete Real iq_ref_held(start=0.0) "A held current reference";
  discrete Real vq_held(start=0.0)    "V held q-axis voltage";

protected
  Real err_p, unsat_iq;
  Real err_c, unsat_vq;

equation
  // ---- Output kinematics through gearbox ----
  theta_out  = theta_m / N;
  omega_out  = omega_m / N;
  omega_e    = p * omega_m;

  // ---- Electrical dynamics (q-axis, FOC, d-axis regulated to zero) ----
  der(iq) = (vq - R_winding*iq - Ke*omega_e) / L_q;

  // ---- Mechanical dynamics (reflected to motor side) ----
  tau_em        = Kt * iq;
  tau_grav_out  = m_load * g_acc * r_wheel * sin(theta_out);
  tau_disturb_out = (if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then F_disturb*r_wheel else 0.0);
  // Spring-damper collision stops at output travel limits (well-defined, zero branch at limit)
  if theta_out > theta_max then
    tau_stop_out = -k_stop*(theta_out - theta_max) - d_stop*omega_out;
  elseif theta_out < -theta_max then
    tau_stop_out = -k_stop*(theta_out + theta_max) - d_stop*omega_out;
  else
    tau_stop_out = 0.0;
  end if;

  der(theta_m) = omega_m;
  der(omega_m) = ( tau_em
                 - (b_m + b_l/(N*N))*omega_m
                 - (tau_grav_out + tau_disturb_out)/N
                 + tau_stop_out/N
                ) / (J_m + J_l/(N*N));

  // ---- Thermal dynamics of winding ----
  der(T_winding) = (R_winding*iq*iq - (T_winding - T_amb)/Rth) / Cth;

  // ---- Battery model (explicit approximation; safe denominator) ----
  I_batt        = (vq*iq) / V_bus;            // power balance, V_bus>0
  V_bus_actual  = V_bus - R_batt*I_batt;

  // ---- Zero-order-hold control outputs ----
  vq     = vq_held;
  iq_ref = iq_ref_held;

  // ---- Primary tracking error (synchronized sensor trace) ----
  error_pos = target_pos - theta_out;

algorithm
  when sample(0.0, Ts) then
    // ---- Outer position loop with conditional anti-windup ----
    err_p     := target_pos - theta_out;
    unsat_iq  := Kp_pos*err_p + Ki_pos*pre(integ_pos);
    if abs(unsat_iq) <= I_max
       or (unsat_iq >  I_max and err_p < 0.0)
       or (unsat_iq < -I_max and err_p > 0.0) then
      integ_pos := pre(integ_pos) + err_p*Ts;
    else
      integ_pos := pre(integ_pos);
    end if;
    iq_ref_held := max(-I_max, min(I_max, Kp_pos*err_p + Ki_pos*integ_pos));

    // ---- Inner current loop with conditional anti-windup ----
    err_c     := iq_ref_held - iq;
    unsat_vq  := Kp_cur*err_c + Ki_cur*pre(integ_cur);
    if abs(unsat_vq) <= V_lim
       or (unsat_vq >  V_lim and err_c < 0.0)
       or (unsat_vq < -V_lim and err_c > 0.0) then
      integ_cur := pre(integ_cur) + err_c*Ts;
    else
      integ_cur := pre(integ_cur);
    end if;
    vq_held := max(-V_lim, min(V_lim, Kp_cur*err_c + Ki_cur*integ_cur));
  end when;

equation
  // ---- Bounds and assertions ----
  assert(abs(vq)    <= V_lim + 1.0e-6, "Voltage bound violated");
  assert(abs(iq)    <= I_max + 1.0,   "Current bound violated (allowance for transients)");
  assert(abs(theta_out) <= theta_max + 1.0e-3, "Travel bound violated");
  assert(T_winding  <= T_max,         "Temperature bound violated");
  assert(time < 9.1 or abs(error_pos) < err_bound,
         "Primary tracking error bound violated after 9.1 s");
  assert(V_bus_actual > 0.0, "Bus voltage must remain positive");
  assert(abs(theta_out) < 1.0e9, "Non-finite or non-physical output position detected");
  assert(abs(iq)        < 1.0e9, "Non-finite or non-physical current detected");
  assert(abs(T_winding) < 1.0e9, "Non-finite or non-physical temperature detected");

  annotation(
    experiment(StopTime=14.0, Tolerance=1.0e-6, Interval=0.005),
    Documentation(info="BLDCWheelPositionD: 48 V PM motor, 4 pole pairs, 9:1 gearbox, 0.12 m wheel. "
                       "Cascaded current/position PI control at 200 Hz with anti-windup. "
                       "8 N output load disturbance during middle third (4.667-9.333 s). "
                       "Synchronized state, command, and sensor traces retained for 14 s."));
end BLDCWheelPositionD;