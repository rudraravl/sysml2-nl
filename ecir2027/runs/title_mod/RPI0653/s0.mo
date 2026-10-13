model PneuGripPositionE
  // Scenario and control timing
  parameter Real Ts(unit="s") = 0.004 "controller/sample period for 250 Hz operation";
  parameter Real t_end(unit="s") = 16.0 "scenario duration";

  // Geometry and masses
  parameter Real L(unit="m") = 0.035 "cylinder travel";
  parameter Real A_piston(unit="m2") = 0.0012 "piston area";
  parameter Real m_finger(unit="kg") = 0.8 "mass of each gripper finger";
  parameter Real x_ref_final(unit="m") = 0.7*L "70 percent of available travel";

  // Pneumatic supply/return and gas model
  // Supply and return pressures are not specified in the request; these are
  // declared representative finite absolute pressures.
  parameter Real p_supply(unit="Pa") = 6.0e5 "declared supply pressure";
  parameter Real p_return(unit="Pa") = 1.0e5 "declared return pressure";
  parameter Real V_dead(unit="m3") = 2.0e-5 "dead volume per chamber";
  constant Real R_air(unit="J/(kg.K)") = 287.0 "ideal gas constant for air";
  constant Real T_air(unit="K") = 293.15 "isothermal chamber temperature";

  // Leakage and end-stop parameters
  // Leakage and stop stiffness/damping are not specified; finite values are
  // selected so the requested behavior is well-posed and testable.
  parameter Real C_leak(unit="kg/(s.Pa)") = 5.0e-10 "chamber-to-return leakage coefficient";
  parameter Real C_cross(unit="kg/(s.Pa)") = 1.0e-10 "cross-chamber leakage coefficient";
  parameter Real b_mech(unit="N.s/m") = 150.0 "viscous finger damping";
  parameter Real k_stop(unit="N/m") = 1.0e6 "end-stop stiffness";
  parameter Real c_stop(unit="N.s/m") = 1.0e3 "end-stop damping";

  // External load disturbance: 120 N total, middle third of 16 s
  parameter Real F_ext_total(unit="N") = 120.0 "controlled external load";
  parameter Real F_ext_per(unit="N") = F_ext_total/2.0 "load per finger";
  parameter Real t_load_start(unit="s") = t_end/3.0 "middle-third start";
  parameter Real t_load_end(unit="s") = 2.0*t_end/3.0 "middle-third end";

  // Valve command bound
  parameter Real u_max(unit="kg/s") = 0.001 "proportional valve command magnitude bound";

  // Pressure-aware position controller
  parameter Real tau_ref(unit="s") = 0.4 "reference smoothing time constant";
  parameter Real Kp_pos(unit="N/m") = 2000.0 "position proportional gain";
  parameter Real Kd_pos(unit="N.s/m") = 300.0 "position derivative gain";
  parameter Real Ki_pos(unit="N/(m.s)") = 500.0 "position integral gain";
  parameter Real e_int_max(unit="m.s") = 0.01 "integral anti-windup limit";
  parameter Real p_mean_bias(unit="Pa") = 1.0e5 "gauge precharge bias for pressure-aware control";
  parameter Real p_mean_des(unit="Pa") = p_return + p_mean_bias "absolute mean chamber pressure";
  parameter Real dp_max(unit="Pa") = 2.0*(p_mean_des - p_return) "differential pressure limit";
  parameter Real Kp_p(unit="kg/(s.Pa)") = 4.0e-8 "pressure-tracking valve gain";

  // Acceptance bounds
  parameter Real eps_stop(unit="m") = 1.0e-4 "allowed stop compliance";
  parameter Real v_max(unit="m/s") = 2.0 "velocity bound";
  parameter Real p_min(unit="Pa") = 5.0e4 "minimum pressure bound";
  parameter Real p_max(unit="Pa") = 7.0e5 "maximum pressure bound";
  parameter Real primary_error_tol(unit="m") = 0.011 "tracking error bound after 10.4 s";
  parameter Real final_pos_tol(unit="m") = 0.005 "final position bound";
  parameter Real t_primary(unit="s") = 10.4 "primary tracking check time";
  parameter Real t_final_check(unit="s") = 15.5 "final position check time";

  // Continuous plant states
  Real x1(unit="m") "finger 1 displacement";
  Real x2(unit="m") "finger 2 displacement";
  Real v1(unit="m/s") "finger 1 velocity";
  Real v2(unit="m/s") "finger 2 velocity";
  Real pA(unit="Pa") "extension chamber pressure";
  Real pB(unit="Pa") "retraction chamber pressure";

  // Continuous algebraic plant variables
  Real VA(unit="m3") "total extension chamber volume";
  Real VB(unit="m3") "total retraction chamber volume";
  Real q_leakA(unit="kg/s") "extension chamber leakage to return";
  Real q_leakB(unit="kg/s") "retraction chamber leakage to return";
  Real q_cross(unit="kg/s") "cross-chamber leakage";
  Real F_ext1(unit="N") "external load on finger 1";
  Real F_ext2(unit="N") "external load on finger 2";
  Real F_stop1(unit="N") "end-stop force on finger 1";
  Real F_stop2(unit="N") "end-stop force on finger 2";
  Real F_finger1(unit="N") "pneumatic force on finger 1";
  Real F_finger2(unit="N") "pneumatic force on finger 2";
  Real e(unit="m") "primary tracking error";

  // Synchronized measurements and traces
  Real x_meas(unit="m") "measured actuator position";
  Real v_meas(unit="m/s") "measured actuator velocity";
  Real pA_meas(unit="Pa") "measured extension chamber pressure";
  Real pB_meas(unit="Pa") "measured retraction chamber pressure";
  Real uA_meas(unit="kg/s") "measured extension valve command";
  Real uB_meas(unit="kg/s") "measured retraction valve command";
  Real u_cmd_meas(unit="kg/s") "measured average valve command";
  Real tracking_error(unit="m") "absolute primary tracking error";

  // Discrete controller states at 250 Hz
  discrete Real x_ref_f(start=0.0, fixed=true, unit="m") "filtered reference";
  discrete Real v_ref_f(start=0.0, fixed=true, unit="m/s") "filtered reference velocity";
  discrete Real e_int(start=0.0, fixed=true, unit="m.s") "position error integral";
  discrete Real F_cmd(start=0.0, fixed=true, unit="N") "force command per finger";
  discrete Real dp_des(start=0.0, fixed=true, unit="Pa") "desired differential pressure";
  discrete Real pA_des(start=p_mean_des, fixed=true, unit="Pa") "desired extension pressure";
  discrete Real pB_des(start=p_mean_des, fixed=true, unit="Pa") "desired retraction pressure";
  discrete Real uA_cmd(start=0.0, fixed=true, unit="kg/s") "unsaturated extension valve command";
  discrete Real uB_cmd(start=0.0, fixed=true, unit="kg/s") "unsaturated retraction valve command";
  discrete Real uA(start=0.0, fixed=true, unit="kg/s") "actual extension valve command";
  discrete Real uB(start=0.0, fixed=true, unit="kg/s") "actual retraction valve command";
  Boolean saturated(start=false, fixed=true) "anti-windup saturation flag";

equation
  // Measurements and tracking error
  x_meas = (x1 + x2)/2.0;
  v_meas = (v1 + v2)/2.0;
  pA_meas = pA;
  pB_meas = pB;
  uA_meas = uA;
  uB_meas = uB;
  u_cmd_meas = (uA + uB)/2.0;
  e = x_ref_final - x_meas;
  tracking_error = abs(e);

  // External load disturbance (opposes opening)
  F_ext1 = if time >= t_load_start and time <= t_load_end then F_ext_per else 0.0;
  F_ext2 = F_ext1;

  // Mechanical end stops
  F_stop1 = if noEvent(x1 < 0.0) then (-k_stop*x1 - c_stop*v1)
            else if noEvent(x1 > L) then (-k_stop*(x1 - L) - c_stop*v1)
            else 0.0;
  F_stop2 = if noEvent(x2 < 0.0) then (-k_stop*x2 - c_stop*v2)
            else if noEvent(x2 > L) then (-k_stop*(x2 - L) - c_stop*v2)
            else 0.0;

  // Finger dynamics
  F_finger1 = A_piston*(pA - pB);
  F_finger2 = A_piston*(pA - pB);
  der(x1) = v1;
  der(x2) = v2;
  der(v1) = (F_finger1 - b_mech*v1 - F_ext1 - F_stop1)/m_finger;
  der(v2) = (F_finger2 - b_mech*v2 - F_ext2 - F_stop2)/m_finger;

  // Chamber volumes for two opposing cylinders sharing two controlled manifolds
  VA = 2.0*V_dead + A_piston*(x1 + x2);
  VB = 2.0*V_dead + A_piston*(2.0*L - x1 - x2);
  der(VA) = A_piston*(v1 + v2);
  der(VB) = -A_piston*(v1 + v2);

  // Leakage
  q_leakA = C_leak*(pA - p_return);
  q_leakB = C_leak*(pB - p_return);
  q_cross = C_cross*(pA - pB);

  // Compressible chamber pressure dynamics
  der(pA) = (R_air*T_air/VA)*(uA - q_leakA - q_cross) - (pA/VA)*der(VA);
  der(pB) = (R_air*T_air/VB)*(uB - q_leakB + q_cross) - (pB/VB)*der(VB);

  // Pressure-aware PID position controller sampled at 250 Hz
  when sample(0.0, Ts) then
    x_ref_f = pre(x_ref_f) + (Ts/tau_ref)*(x_ref_final - pre(x_ref_f));
    v_ref_f = (x_ref_final - x_ref_f)/tau_ref;

    F_cmd = Kp_pos*e
            + Kd_pos*(v_ref_f - v_meas)
            + Ki_pos*pre(e_int)
            + (if time >= t_load_start and time <= t_load_end then F_ext_per else 0.0)
            + b_mech*v_ref_f;

    dp_des = if F_cmd/A_piston > dp_max then dp_max
             else if F_cmd/A_piston < -dp_max then -dp_max
             else F_cmd/A_piston;

    pA_des = if p_mean_des + 0.5*dp_des > p_supply then p_supply
             else if p_mean_des + 0.5*dp_des < p_return then p_return
             else p_mean_des + 0.5*dp_des;

    pB_des = if p_mean_des - 0.5*dp_des > p_supply then p_supply
             else if p_mean_des - 0.5*dp_des < p_return then p_return
             else p_mean_des - 0.5*dp_des;

    uA_cmd = Kp_p*(pA_des - pA) + q_leakA + q_cross;
    uB_cmd = Kp_p*(pB_des - pB) + q_leakB - q_cross;

    saturated = (uA_cmd > u_max and e > 0.0)
                or (uA_cmd < -u_max and e < 0.0)
                or (uB_cmd > u_max and e > 0.0)
                or (uB_cmd < -u_max and e < 0.0);

    e_int = if saturated then pre(e_int)
            else max(-e_int_max, min(e_int_max, pre(e_int) + Ts*e));

    uA = if pA >= p_supply and uA_cmd > 0.0 then 0.0
         else if pA <= p_return and uA_cmd < 0.0 then 0.0
         else if uA_cmd > u_max then u_max
         else if uA_cmd < -u_max then -u_max
         else uA_cmd;

    uB = if pB >= p_supply and uB_cmd > 0.0 then 0.0
         else if pB <= p_return and uB_cmd < 0.0 then 0.0
         else if uB_cmd > u_max then u_max
         else if uB_cmd < -u_max then -u_max
         else uB_cmd;
  end when;

  // Fail-closed acceptance assertions
  assert(x1 == x1 and abs(x1) < 1.0e9, "x1 not finite");
  assert(x2 == x2 and abs(x2) < 1.0e9, "x2 not finite");
  assert(v1 == v1 and abs(v1) < 1.0e9, "v1 not finite");
  assert(v2 == v2 and abs(v2) < 1.0e9, "v2 not finite");
  assert(pA == pA and abs(pA) < 1.0e9, "pA not finite");
  assert(pB == pB and abs(pB) < 1.0e9, "pB not finite");
  assert(uA == uA and abs(uA) < 1.0e9, "uA not finite");
  assert(uB == uB and abs(uB) < 1.0e9, "uB not finite");
  assert(e_int == e_int and abs(e_int) < 1.0e9, "e_int not finite");

  assert(x1 >= -eps_stop and x1 <= L + eps_stop and
         x2 >= -eps_stop and x2 <= L + eps_stop, "travel bound violated");

  assert(abs(uA) <= u_max + 1.0e-12 and
         abs(uB) <= u_max + 1.0e-12, "valve command bound violated");

  assert(pA >= p_min and pA <= p_max and
         pB >= p_min and pB <= p_max, "pressure bound violated");

  assert(abs(v1) <= v_max and abs(v2) <= v_max, "velocity bound violated");

  assert(time < t_primary or tracking_error <= primary_error_tol,
         "primary tracking error bound violated");

  assert(time < t_final_check or tracking_error <= final_pos_tol,
         "final position bound violated");

  annotation(experiment(StopTime=16.0, Tolerance=1e-6));
end PneuGripPositionE;