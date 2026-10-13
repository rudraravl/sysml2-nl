model PneuGripPositionE
  extends Modelica.Icons.Example;

  // ===== Geometry & mass (from requirement) =====
  parameter Modelica.SIunits.Length   L     = 0.035  "Cylinder stroke";
  parameter Modelica.SIunits.Area     A_p   = 0.0012 "Piston area";
  parameter Modelica.SIunits.Mass     m_f   = 0.8    "Each gripper finger mass";

  // ===== Fluid assumptions (values not specified by requirement) =====
  parameter Real n_poly(unit="1") = 1.2                                   "Polytropic exponent (assumed)";
  parameter Modelica.SIunits.SpecificHeatCapacity R_air = 287.058        "Gas constant dry air (assumed)";
  parameter Modelica.SIunits.Temperature  T_gas  = 293.15               "Gas temperature (assumed)";
  parameter Modelica.SIunits.Volume       V_dead = 5.0e-6               "Chamber dead volume (assumed)";
  parameter Modelica.SIunits.Pressure     P_supply = 6.0e5              "Supply pressure (declared/assumed)";
  parameter Modelica.SIunits.Pressure     P_return = 1.01325e5          "Return pressure (declared/assumed)";
  parameter Real C_leak(unit="kg/(s.Pa)") = 5.0e-9                      "Leakage conductance to return (assumed)";

  // ===== Mechanical assumptions =====
  parameter Modelica.SIunits.TranslationalDampingConstant b_damp = 150.0 "Viscous damping (assumed)";
  parameter Real k_stop(unit="N/m") = 1.0e7                              "End-stop stiffness (assumed)";
  parameter Modelica.SIunits.Length d_stop = 5.0e-4                     "End-stop engagement margin (assumed)";

  // ===== Valve (from requirement) =====
  parameter Modelica.SIunits.MassFlowRate u_max = 0.001 "Valve command magnitude bound";

  // ===== Controller (pressure-aware PID + disturbance estimator, gains assumed) =====
  parameter Real Kp(unit="kg/(s.m)")  = 0.5   "Proportional gain";
  parameter Real Ki(unit="kg/(s.m.s)") = 3.0 "Integral gain";
  parameter Real Kd(unit="kg/s2")     = 0.02  "Derivative gain";
  parameter Real Kaw(unit="1/s")      = 10.0  "Anti-windup back-calculation gain";
  parameter Real Kff(unit="kg/(N.s)") = 2.0e-6 "Force-estimate feedforward gain";
  parameter Modelica.SIunits.Time tau_est = 0.15 "Disturbance estimator time constant";

  // ===== Setpoint & disturbance (from requirement) =====
  parameter Modelica.SIunits.Length x_target = 0.7*L                  "70 % of travel setpoint";
  parameter Modelica.SIunits.Force F_ext_mag = 120.0                  "External load magnitude";
  parameter Modelica.SIunits.Time  t_dist_start = 16.0/3.0           "Disturbance onset (middle third)";
  parameter Modelica.SIunits.Time  t_dist_end   = 2.0*16.0/3.0        "Disturbance end   (middle third)";

  // ===== Initial conditions =====
  parameter Modelica.SIunits.Pressure P_init = P_return "Initial chamber pressure";

  // ===== Dynamic states =====
  Modelica.SIunits.Length   x1(start=0.0,    fixed=true) "Finger 1 position";
  Modelica.SIunits.Velocity v1(start=0.0,    fixed=true) "Finger 1 velocity";
  Modelica.SIunits.Pressure Pa1(start=P_init,fixed=true) "Cylinder 1 chamber A pressure";
  Modelica.SIunits.Pressure Pb1(start=P_init,fixed=true) "Cylinder 1 chamber B pressure";

  Modelica.SIunits.Length   x2(start=0.0,    fixed=true) "Finger 2 position";
  Modelica.SIunits.Velocity v2(start=0.0,    fixed=true) "Finger 2 velocity";
  Modelica.SIunits.Pressure Pa2(start=P_init,fixed=true) "Cylinder 2 chamber A pressure";
  Modelica.SIunits.Pressure Pb2(start=P_init,fixed=true) "Cylinder 2 chamber B pressure";

  // Estimator & controller states
  Modelica.SIunits.Force F_est(start=0.0, fixed=true) "Estimated external load per finger";
  Real integ_err(start=0.0, fixed=true)               "Integrated position error";

  // ===== Measurements (observable traces) =====
  Modelica.SIunits.Length       x      "Actuator position (gripper opening)";
  Modelica.SIunits.Velocity     v      "Actuator velocity";
  Modelica.SIunits.Pressure     Pa_meas "Chamber A pressure (measured, avg)";
  Modelica.SIunits.Pressure     Pb_meas "Chamber B pressure (measured, avg)";
  Modelica.SIunits.MassFlowRate u_cmd   "Valve command (measured)";

  // ===== Internal signals =====
  Real e "Position error";
  Modelica.SIunits.MassFlowRate u_raw "Unsaturated command";
  Modelica.SIunits.MassFlowRate u_sat "Saturated command";
  Modelica.SIunits.Force  F_dist      "Active external disturbance";
  Modelica.SIunits.Volume Va1, Vb1, Va2, Vb2 "Chamber volumes";
  Modelica.SIunits.Force  Fstop1_lo, Fstop1_hi, Fstop2_lo, Fstop2_hi;

protected
  function sat
    input  Real x_in;
    input  Real lim;
    output Real y;
  algorithm
    y := if x_in > lim then lim else if x_in < -lim then -lim else x_in;
  end sat;

  function safeDiv
    input  Real num;
    input  Real den;
    output Real y;
  algorithm
    y := if abs(den) < 1.0e-12 then 0.0 else num/den;
  end safeDiv;

equation
  // ----- Aggregate sensor measurements -----
  x      = x1 + x2;
  v      = v1 + v2;
  Pa_meas = 0.5*(Pa1 + Pa2);
  Pb_meas = 0.5*(Pb1 + Pb2);

  // ----- Disturbance: 120 N opposing opening, middle third of 16 s run -----
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_ext_mag else 0.0;

  // ----- Chamber volumes -----
  Va1 = V_dead + A_p*x1;
  Vb1 = V_dead + A_p*(L - x1);
  Va2 = V_dead + A_p*x2;
  Vb2 = V_dead + A_p*(L - x2);

  // ----- Chamber pressure dynamics (polytropic ideal gas, leakage to return) -----
  // dP/dt = (n/V) * ( R*T*mdot_net - P * dV/dt )
  der(Pa1) = safeDiv(n_poly, Va1) * (R_air*T_gas*(u_cmd - C_leak*(Pa1 - P_return)) - Pa1*A_p*v1);
  der(Pb1) = safeDiv(n_poly, Vb1) * (R_air*T_gas*(-u_cmd - C_leak*(Pb1 - P_return)) + Pb1*A_p*v1);
  der(Pa2) = safeDiv(n_poly, Va2) * (R_air*T_gas*(u_cmd - C_leak*(Pa2 - P_return)) - Pa2*A_p*v2);
  der(Pb2) = safeDiv(n_poly, Vb2) * (R_air*T_gas*(-u_cmd - C_leak*(Pb2 - P_return)) + Pb2*A_p*v2);

  // ----- Mechanical end stops (compressive, keep finger in [0, L]) -----
  Fstop1_lo = k_stop*max(0.0, d_stop - x1);
  Fstop1_hi = k_stop*max(0.0, x1 - (L - d_stop));
  Fstop2_lo = k_stop*max(0.0, d_stop - x2);
  Fstop2_hi = k_stop*max(0.0, x2 - (L - d_stop));

  // ----- Finger dynamics -----
  der(x1) = v1;
  der(x2) = v2;
  m_f*der(v1) = A_p*(Pa1 - Pb1) - b_damp*v1 - F_dist/2.0 + Fstop1_lo - Fstop1_hi;
  m_f*der(v2) = A_p*(Pa2 - Pb2) - b_damp*v2 - F_dist/2.0 + Fstop2_lo - Fstop2_hi;

  // ----- Disturbance estimator (first-order observer of per-finger external load) -----
  // Steady force balance per finger: A_p*(Pa-Pb) - b_damp*(v/2) - F_ext/2 = 0
  der(F_est) = safeDiv(A_p*(Pa_meas - Pb_meas) - b_damp*(v/2.0) - F_est, tau_est);

  // ----- Pressure-aware PID position controller -----
  e = x_target - x;
  // Back-calculation anti-windup (continuous, no event generation)
  der(integ_err) = e + Kaw*(u_sat - u_raw);
  // PID + pressure/force feedforward (derivative of error = -velocity)
  u_raw = Kp*e + Ki*integ_err - Kd*v + Kff*F_est;
  u_sat = sat(u_raw, u_max);
  u_cmd = u_sat;

  // ================================================================
  //        ACCEPTANCE BOUNDS  (fail-closed)
  // ================================================================
  // Travel bound
  assert(x >= -1.0e-4 and x <= 2.0*L + 1.0e-4, "FAIL: travel bound violated");
  // Valve command bound
  assert(abs(u_cmd) <= u_max + 1.0e-9, "FAIL: valve command bound violated");
  // Pressure bounds (physical admissibility)
  assert(Pa_meas > 0.0, "FAIL: chamber A pressure non-positive");
  assert(Pb_meas > 0.0, "FAIL: chamber B pressure non-positive");
  assert(Pa_meas < 2.0*P_supply, "FAIL: chamber A pressure exceeds 2*supply");
  assert(Pb_meas < 2.0*P_supply, "FAIL: chamber B pressure exceeds 2*supply");
  // Velocity bound
  assert(abs(v) <= 2.0, "FAIL: velocity bound violated");
  // Final-position / primary tracking error bound after 10.4 s
  assert(time < 10.4 or abs(e) <= 0.011, "FAIL: primary tracking error > 0.011 m after 10.4 s");
  // NaN / infinity checks (physical, control, estimator)
  assert(not Modelica.Math.isNaN(x),         "FAIL: NaN in position");
  assert(not Modelica.Math.isNaN(v),         "FAIL: NaN in velocity");
  assert(not Modelica.Math.isNaN(Pa_meas),   "FAIL: NaN in chamber A pressure");
  assert(not Modelica.Math.isNaN(Pb_meas),   "FAIL: NaN in chamber B pressure");
  assert(not Modelica.Math.isNaN(u_cmd),     "FAIL: NaN in valve command");
  assert(not Modelica.Math.isNaN(F_est),     "FAIL: NaN in estimator state");
  assert(not Modelica.Math.isNaN(integ_err), "FAIL: NaN in controller state");
  assert(not Modelica.Math.isNaN(u_raw),     "FAIL: NaN in raw command");
  assert(not Modelica.Math.isNaN(u_sat),     "FAIL: NaN in saturated command");
  assert(x < 1.0e9,       "FAIL: non-finite position");
  assert(abs(u_cmd) < 1.0e9, "FAIL: non-finite valve command");
  assert(abs(F_est) < 1.0e9, "FAIL: non-finite estimator");

  annotation (
    uses(Modelica(version="4.0.0")),
    experiment(StopTime=16.0, Tolerance=1.0e-6, Interval=0.004),
    Documentation(info="PneuGripPositionE: two-chamber pneumatic gripper position control.
Two opposing cylinders (stroke 0.035 m, piston area 0.0012 m2) drive 0.8 kg fingers.
Two proportional valves (command bounded to 0.001 kg/s) command compressible chambers
with declared supply/return pressure, fluid compressibility (polytropic), leakage, and
mechanical end stops. Pressure-aware PID with first-order disturbance estimator and
back-calculation anti-windup. 120 N external load disturbance in the middle third of a
16 s run at 250 Hz (Interval=0.004 s). Setpoint = 70 % of travel. Fail-closed assertions
enforce travel, valve, pressure, velocity, final-tracking-error, and NaN/inf bounds."));
end PneuGripPositionE;