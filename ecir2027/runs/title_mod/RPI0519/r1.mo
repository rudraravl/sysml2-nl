model BLDCWheelTorqueC
  "Electromechanical robotic actuator: BLDC FOC current control with outer contact-force feedback driving a wheeled compliant load."

  // ----- Battery -----
  parameter Real V_bus(unit="V") = 48.0      "Battery nominal voltage";
  parameter Real R_int(unit="ohm") = 0.05    "Battery internal resistance";

  // ----- PM BLDC motor (48 V, 3-phase, 4 pole pairs) -----
  parameter Integer P = 4                    "Pole pairs";
  parameter Real R_ph(unit="ohm") = 0.30     "Q-axis phase resistance";
  parameter Real L_q(unit="H") = 0.5e-3      "Q-axis inductance";
  parameter Real Kt(unit="N.m/A") = 0.05     "Torque constant (mechanical side)";
  parameter Real Ke(unit="V.s/rad") = 0.05   "Back-EMF constant (mechanical side)";
  parameter Real J_m(unit="kg.m2") = 1.0e-5  "Motor rotor inertia";
  parameter Real b_m(unit="N.m.s/rad") = 1.0e-6 "Motor viscous friction";

  // ----- Transmission: gearbox + compliance -----
  parameter Real N_gb = 9.0                   "Gearbox ratio";
  parameter Real k_t(unit="N.m/rad") = 50.0   "Transmission torsional stiffness";
  parameter Real c_t(unit="N.m.s/rad") = 0.5  "Transmission torsional damping";

  // ----- Wheel (0.12 m diameter) -----
  parameter Real r_w(unit="m") = 0.06        "Wheel radius";
  parameter Real J_w(unit="kg.m2") = 0.010    "Wheel inertia";
  parameter Real b_w(unit="N.m.s/rad") = 1.0e-5 "Wheel viscous friction";

  // ----- Contact + compliant load -----
  parameter Real k_c(unit="N/m") = 1.0e4      "Contact stiffness";
  parameter Real c_c(unit="N.s/m") = 20.0     "Contact damping";
  parameter Real m_L(unit="kg") = 0.50        "Load mass";
  parameter Real k_L(unit="N/m") = 500.0      "Load-to-ground stiffness";
  parameter Real c_L(unit="N.s/m") = 5.0      "Load-to-ground damping";

  // ----- Thermal -----
  parameter Real T_amb(unit="K") = 293.15     "Ambient temperature";
  parameter Real C_th(unit="J/K") = 50.0      "Winding thermal capacitance";
  parameter Real R_th(unit="K/W") = 0.5       "Winding-to-ambient thermal resistance";

  // ----- Controller / command -----
  parameter Real V_cmd_max(unit="V") = 44.2   "Maximum voltage command magnitude";
  parameter Real iq_max(unit="A") = 20.0      "Current command limit";
  parameter Real F_cmd(unit="N") = 15.0       "Output force command";
  parameter Real F_dist(unit="N") = 13.5      "Disturbance load change magnitude";
  parameter Real Ts(unit="s") = 0.008         "Control period (125 Hz)";
  parameter Real KpF = 0.40                   "Outer force P gain (A/N)";
  parameter Real KiF = 3.0                    "Outer force I gain (A/(N.s))";
  parameter Real Kpc = 0.25                   "Inner current P gain (V/A)";
  parameter Real Kic = 150.0                   "Inner current I gain (V/(A.s))";
  parameter Real F_int_lim = 5.0              "Outer integrator clamp";
  parameter Real iq_int_lim = 0.3             "Inner integrator clamp";

  // ----- Bounds -----
  parameter Real T_max(unit="K") = 353.15     "Thermal bound";
  parameter Real omega_max(unit="rad/s") = 600.0 "Joint speed bound";
  parameter Real defl_max(unit="rad") = 0.10  "Transmission deflection bound";
  parameter Real F_max(unit="N") = 200.0       "Contact force bound";
  parameter Real track_tol(unit="N") = 2.1     "Tracking error bound after 7.8 s";

  // ----- Continuous states -----
  Real iq(start=0.0)              "Q-axis phase current (motor current sensor)";
  Real omega_m(start=0.0)         "Motor angular velocity";
  Real theta_m(start=0.0)         "Motor angle";
  Real omega_w(start=0.0)         "Wheel angular velocity (output state)";
  Real theta_w(start=0.0)         "Wheel angle (output state)";
  Real v_load(start=0.0)          "Load velocity";
  Real x_load(start=0.0)          "Load position";
  Real T_temp(start=T_amb)        "Winding temperature";

  // ----- Discrete controller states -----
  discrete Real vq_cmd(start=0.0)  "Q-axis voltage command (sampled, held)";
  discrete Real F_err(start=0.0);
  discrete Real F_int(start=0.0);
  discrete Real iq_cmd(start=0.0);
  discrete Real iq_err(start=0.0);
  discrete Real iq_int(start=0.0);

  // ----- Derived / sensor signals -----
  Real omega_g                    "Gearbox output speed (motor/transmission side)";
  Real theta_g                    "Gearbox output angle (motor/transmission side)";
  Real T_m                        "Motor electromagnetic torque";
  Real T_trans                    "Transmission torque";
  Real F_c                        "Contact force";
  Real T_contact                  "Wheel torque due to contact";
  Real back_emf                   "Back EMF";
  Real defl                       "Transmission deflection (both-sides measurement)";
  Real V_terminal                 "Battery terminal voltage";
  Real I_batt                     "Battery current";
  Real F_disturbance              "Applied load disturbance";
  Real F_meas                     "Measured contact force";

  // ----- Diagnostics -----
  Real track_err                  "Force tracking error";
  Boolean b_elec                  "Electrical bound (|vq_cmd| <= 44.2 V)";
  Boolean b_therm                 "Thermal bound";
  Boolean b_joint                 "Joint speed bound";
  Boolean b_defl                  "Transmission deflection bound";
  Boolean b_contact               "Contact force bound";
  Boolean track_ok                "Tracking error <= 2.1 N after 7.8 s";
  Boolean finite_check            "Finite-state sanity flag";

equation
  // Disturbance: 13.5 N load change during middle third (4 s .. 8 s)
  F_disturbance = if (time >= 4.0 and time <= 8.0) then F_dist else 0.0;

  // Battery
  I_batt = iq;
  V_terminal = V_bus - R_int*I_batt;

  // Motor electrical (q-axis FOC, pole-pair count carried in Kt/Ke scaling)
  back_emf = Ke*omega_m;
  der(iq) = (vq_cmd - R_ph*iq - back_emf)/L_q;
  T_m = Kt*iq;

  // Motor mechanical
  der(omega_m) = (T_m - T_trans/N_gb - b_m*omega_m)/J_m;
  der(theta_m) = omega_m;

  // Gearbox
  omega_g = omega_m/N_gb;
  theta_g = theta_m/N_gb;

  // Compliant transmission (both sides measured: theta_g and theta_w)
  defl = theta_g - theta_w;
  T_trans = k_t*defl + c_t*(omega_g - omega_w);

  // Wheel mechanical
  T_contact = F_c*r_w;
  der(omega_w) = (T_trans - T_contact - b_w*omega_w)/J_w;
  der(theta_w) = omega_w;

  // Contact compliance (rigid support geometry via load-to-ground spring)
  F_c = k_c*(r_w*theta_w - x_load) + c_c*(r_w*omega_w - v_load);

  // Load dynamics with ground reaction and disturbance
  der(v_load) = (F_c - F_disturbance - k_L*x_load - c_L*v_load)/m_L;
  der(x_load) = v_load;

  // Lumped thermal model
  der(T_temp) = (iq*iq*R_ph - (T_temp - T_amb)/R_th)/C_th;

  // Sensor / tracking
  F_meas = F_c;
  track_err = abs(F_meas - F_cmd);

  // Bounds
  b_elec = abs(vq_cmd) <= V_cmd_max + 1.0e-6;
  b_therm = T_temp <= T_max;
  b_joint = abs(omega_m) <= omega_max;
  b_defl = abs(defl) <= defl_max;
  b_contact = abs(F_c) <= F_max;
  track_ok = (time >= 7.8) and (track_err <= track_tol);

  // Finite sanity (all physical/control/estimator quantities finite)
  finite_check = not (
    isNaN(iq) or isInfinite(iq) or
    isNaN(omega_m) or isInfinite(omega_m) or
    isNaN(theta_m) or isInfinite(theta_m) or
    isNaN(omega_w) or isInfinite(omega_w) or
    isNaN(theta_w) or isInfinite(theta_w) or
    isNaN(v_load) or isInfinite(v_load) or
    isNaN(x_load) or isInfinite(x_load) or
    isNaN(T_temp) or isInfinite(T_temp) or
    isNaN(vq_cmd) or isInfinite(vq_cmd) or
    isNaN(iq_cmd) or isInfinite(iq_cmd) or
    isNaN(F_c) or isInfinite(F_c) or
    isNaN(F_meas) or isInfinite(F_meas));

  // ----- Discrete controller at 125 Hz -----
  // Outer force PI -> q-axis current command; inner current PI -> voltage command (saturated to 44.2 V)
  when sample(0, Ts) then
    F_err = F_cmd - F_meas;
    F_int = max(-F_int_lim, min(F_int_lim, pre(F_int) + Ts*F_err));
    iq_cmd = max(-iq_max, min(iq_max, KpF*F_err + KiF*F_int));
    iq_err = iq_cmd - iq;
    iq_int = max(-iq_int_lim, min(iq_int_lim, pre(iq_int) + Ts*iq_err));
    vq_cmd = max(-V_cmd_max, min(V_cmd_max, Kpc*iq_err + Kic*iq_int));
  end when;

  annotation (
    experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.008),
    Documentation(info="BLDCWheelTorqueC: 48V 3-phase PM motor (4 pole pairs) with FOC current loop and outer contact-force PI loop, 9:1 gearbox, 0.12m wheel, compliant transmission and compliant load contact. Battery internal resistance included. Disturbance 13.5 N applied 4-8 s. Control sampled at 125 Hz for 12 s."));
end BLDCWheelTorqueC;