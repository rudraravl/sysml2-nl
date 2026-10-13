model ElectroSoftAvoidB
  // Membrane facts from the request
  parameter Modelica.Units.SI.Length L0 = 0.20 "membrane rest length";
  parameter Modelica.Units.SI.Length W = 0.05 "membrane width";
  parameter Modelica.Units.SI.Length h0 = 0.8e-3 "membrane thickness";
  constant Real eps0(unit="F/m") = 8.8541878128e-12 "vacuum permittivity";
  parameter Real eps_r = 1.0 "relative permittivity; value not specified, neutral placeholder";

  // HV channel
  parameter Modelica.Units.SI.Voltage Vmax = 4100 "allowed command magnitude";
  parameter Real slewRate(unit="V/s") = 4100 "HV slew limit; value not specified, placeholder";
  parameter Real slewTau(unit="s") = 0.05 "HV slew smoothing time; value not specified, placeholder";

  // Membrane mechanics; values not specified are placeholder bindings for compilation
  parameter Modelica.Units.SI.Mass m_tip = 0.02 "lumped tip mass; not specified, placeholder";
  parameter Real k_ax(unit="N/m") = 100 "axial elastic stiffness; not specified, placeholder";
  parameter Real k_elec(unit="N/m") = 100 "voltage-dependent stiffness; not specified, placeholder";
  parameter Real k_stiffen(unit="N/m") = 200 "scheduled hold stiffness; not specified, placeholder";
  parameter Real c_ax(unit="N.s/m") = 2 "axial viscoelastic damping; not specified, placeholder";
  parameter Real k_lat(unit="N/m") = 200 "lateral shape stiffness; not specified, placeholder";
  parameter Real c_lat(unit="N.s/m") = 2 "lateral shape damping; not specified, placeholder";
  parameter Real b_tip(unit="N.s/m") = 0.5 "tip damping; not specified, placeholder";
  parameter Real alpha_act = 0.5 "voltage-to-strain coupling at Vmax; not specified, placeholder";

  // Fixed cylinder; position/radius not specified, placeholder bindings
  parameter Modelica.Units.SI.Length obsX = 0.225 "fixed cylinder center x; not specified, placeholder";
  parameter Modelica.Units.SI.Length obsY = 0.0 "fixed cylinder center y; not specified, placeholder";
  parameter Modelica.Units.SI.Length obsR = 0.02 "fixed cylinder radius; not specified, placeholder";
  parameter Real mu_obs = 0.55 "cylinder friction coefficient";
  parameter Real k_contact(unit="N/m") = 8000 "contact stiffness; not specified, placeholder";
  parameter Real d_contact(unit="N.s/m") = 20 "contact damping; not specified, placeholder";
  parameter Real v_t_small(unit="m/s") = 0.01 "friction smoothing velocity; not specified, placeholder";
  parameter Modelica.Units.SI.Force F_contact_max = 10 "bounded incidental contact force; not specified, placeholder";
  parameter Modelica.Units.SI.Length penetrationMax = 0.003 "maximum allowed penetration; not specified, placeholder";

  // Target; not specified, placeholder binding
  parameter Modelica.Units.SI.Length targetX = 0.30 "target tip x; not specified, placeholder";
  parameter Modelica.Units.SI.Length targetY = 0.0 "target tip y; not specified, placeholder";

  // Controller
  parameter Real Kp_track(unit="V/m") = 5000 "tracking gain; not specified, placeholder";
  parameter Real Kd_track(unit="V.s/m") = 50 "tracking damping; not specified, placeholder";
  parameter Real K_contact(unit="V/N") = 100 "contact-aware command reduction; not specified, placeholder";
  parameter Modelica.Units.SI.Force F_contact_gate = 2 "contact-aware threshold; not specified, placeholder";
  parameter Modelica.Units.SI.Voltage Vhold = 4100 "hold/stiffen voltage";

  // Leakage and thermal state; values not specified are placeholder bindings
  parameter Real G_leak(unit="S") = 1.0e-9 "leakage conductance; not specified, placeholder";
  parameter Real C_th(unit="J/K") = 0.01 "thermal capacitance; not specified, placeholder";
  parameter Real H_th(unit="W/K") = 1.0e-3 "thermal conductance; not specified, placeholder";
  parameter Modelica.Units.SI.Temperature T_amb = 293.15 "ambient temperature; not specified, placeholder";
  parameter Modelica.Units.SI.Temperature T_max = 333.15 "temperature bound; not specified, placeholder";

  // Disturbance and timing
  parameter Modelica.Units.SI.Force F_dist = 5.6 "lateral tip load disturbance";
  parameter Modelica.Units.SI.Time tDistStart = 10.0/3.0 "middle third start";
  parameter Modelica.Units.SI.Time tDistEnd = 20.0/3.0 "middle third end";
  parameter Modelica.Units.SI.Time tStiffen = tDistEnd "stiffen/hold schedule start";

  // Bounds
  parameter Real strainMax = 0.6 "axial deformation bound; not specified, placeholder";
  parameter Modelica.Units.SI.Length primaryTrackingErrorMax = 0.048 "primary tracking error bound after 6.5 s";
  parameter Modelica.Units.SI.Length finalTipErrorMax = 0.048 "final tip error bound; not specified, placeholder";

  // Continuous states
  Real x(unit="m") "tip x";
  Real y(unit="m") "tip y";
  Real vx(unit="m/s") "tip x velocity";
  Real vy(unit="m/s") "tip y velocity";
  Real V(unit="V") "HV actuator state";
  Real T(unit="K") "membrane thermal state";

  // Actuator/material variables
  Real actuationPressure(unit="Pa");
  Real electrostaticForce(unit="N");
  Real leakageCurrent(unit="A");
  Real leakagePower(unit="W");
  Real L(unit="m");
  Real L_safe(unit="m");
  Real derL(unit="m/s");
  Real L_eq(unit="m");
  Real k_eff(unit="N/m");
  Real elasticForce(unit="N");
  Real viscousForce(unit="N");
  Real T_mem(unit="N");
  Real F_mem_x(unit="N");
  Real F_mem_y(unit="N");
  Real F_shape_y(unit="N");
  Real F_disturb_y(unit="N");
  Real V_ff(unit="V");
  Real VcmdRaw(unit="V");
  Real Vcmd(unit="V");
  Real stiffnessSchedule;
  Real strainAxial(unit="1");
  Real sectionDeformation(unit="1");
  Real lateralDeformation(unit="1");

  // Contact variables
  Real dx(unit="m");
  Real dy(unit="m");
  Real d(unit="m");
  Real clearance(unit="m");
  Real penetration(unit="m");
  Real derClearance(unit="m/s");
  Real contactDampingFactor;
  Real nx;
  Real ny;
  Real tx;
  Real ty;
  Real v_t(unit="m/s");
  Real F_n_raw(unit="N");
  Real F_n(unit="N");
  Real F_t_scalar(unit="N");
  Real F_contact_x(unit="N");
  Real F_contact_y(unit="N");
  Real contactForceDistributed(unit="N/m");
  Real contactFrictionForce(unit="N");
  Real contactFrictionDistributed(unit="N/m");

  // Observables
  Modelica.Units.SI.Voltage actuatorState;
  Modelica.Units.SI.Voltage actuatorCommand;
  Real actuatorSlewRate(unit="V/s");
  Real thetaTip(unit="rad");
  Modelica.Units.SI.Length tipPoseX;
  Modelica.Units.SI.Length tipPoseY;
  Modelica.Units.SI.Angle tipPoseTheta;
  Real tipError(unit="m");
  Real T_C(unit="K") "Celsius-equivalent display temperature";

  // Bounds
  Boolean primaryTrackingErrorOK;
  Boolean finalTipErrorOK;
  Boolean boundsOK;

  // 100 Hz synchronized traces
  parameter Modelica.Units.SI.Time Ts = 0.01 "100 Hz trace sampling";
  discrete Integer sampleCounter(start=0);
  discrete Real t_sensor(unit="s", start=0.0);
  discrete Real V_sensor(unit="V", start=0.0);
  discrete Real Vcmd_sensor(unit="V", start=0.0);
  discrete Real x_sensor(unit="m", start=L0);
  discrete Real y_sensor(unit="m", start=0.0);
  discrete Real vx_sensor(unit="m/s", start=0.0);
  discrete Real vy_sensor(unit="m/s", start=0.0);
  discrete Real strain_sensor(unit="1", start=0.0);
  discrete Real contactForce_sensor(unit="N", start=0.0);
  discrete Real contactForceDistributed_sensor(unit="N/m", start=0.0);
  discrete Real temperature_sensor(unit="K", start=T_amb);
  discrete Real clearance_sensor(unit="m", start=0.0);
  discrete Real tipError_sensor(unit="m", start=0.0);
  discrete Real stiffnessSchedule_sensor(start=0.0);

initial equation
  x = L0;
  y = 1.0e-4;
  vx = 0.0;
  vy = 0.0;
  V = 0.0;
  T = T_amb;

equation
  // Geometry and section deformation
  L = sqrt(x*x + y*y + 1.0e-12);
  L_safe = L;
  derL = (x*vx + y*vy)/L_safe;
  strainAxial = (L - L0)/L0;
  sectionDeformation = strainAxial;
  lateralDeformation = y/L0;

  // Explicit permittivity, leakage, and thermal state
  actuationPressure = 0.5*eps0*eps_r*(V/h0)^2;
  electrostaticForce = actuationPressure*W*L0;
  leakageCurrent = G_leak*V;
  leakagePower = leakageCurrent*V;
  C_th*der(T) = leakagePower - H_th*(T - T_amb);
  T_C = T - 273.15;

  // Voltage-controlled elongation and bounded stiffness scheduling
  L_eq = L0*(1.0 + alpha_act*(V/Vmax)^2);
  stiffnessSchedule = if noEvent(time < tStiffen) then 0.0 else 1.0;
  k_eff = k_ax + k_elec*(V/Vmax)^2 + stiffnessSchedule*k_stiffen*(V/Vmax)^2;
  elasticForce = k_eff*(L - L_eq);
  viscousForce = c_ax*derL;
  T_mem = elasticForce + viscousForce;
  F_mem_x = -T_mem*x/L_safe;
  F_mem_y = -T_mem*y/L_safe;

  // Lateral shape restoring term
  F_shape_y = -k_lat*y - c_lat*vy;

  // Controlled lateral tip load during middle third
  F_disturb_y = if noEvent(time >= tDistStart and time <= tDistEnd) then F_dist else 0.0;

  // Fixed cylinder collision with friction
  dx = x - obsX;
  dy = y - obsY;
  d = sqrt(dx*dx + dy*dy + 1.0e-12);
  clearance = d - obsR;
  penetration = max(0.0, -clearance);
  derClearance = (dx*vx + dy*vy)/d;
  contactDampingFactor = penetration/(penetration + 1.0e-6);
  nx = dx/d;
  ny = dy/d;
  tx = -ny;
  ty = nx;
  v_t = vx*tx + vy*ty;
  F_n_raw = max(0.0, k_contact*penetration - d_contact*derClearance*contactDampingFactor);
  F_n = max(0.0, min(F_n_raw, F_contact_max));
  F_t_scalar = -mu_obs*F_n*tanh(v_t/v_t_small);
  F_contact_x = F_n*nx + F_t_scalar*tx;
  F_contact_y = F_n*ny + F_t_scalar*ty;
  contactForceDistributed = F_n/W;
  contactFrictionForce = abs(F_t_scalar);
  contactFrictionDistributed = contactFrictionForce/W;

  // Dynamics
  der(x) = vx;
  der(y) = vy;
  m_tip*der(vx) = F_mem_x + F_contact_x - b_tip*vx;
  m_tip*der(vy) = F_mem_y + F_contact_y + F_disturb_y + F_shape_y - b_tip*vy;

  // Contact-aware shape control with bounded stiffness scheduling
  V_ff = Vmax*sqrt(max(0.0, (targetX/L0 - 1.0)/alpha_act));
  VcmdRaw = if noEvent(time < tStiffen) then
              V_ff + Kp_track*(targetX - x) + Kd_track*(-vx) - K_contact*max(0.0, F_n - F_contact_gate)
            else
              Vhold;
  Vcmd = max(-Vmax, min(Vmax, VcmdRaw));
  der(V) = max(-slewRate, min(slewRate, (Vcmd - V)/slewTau));

  // Observables
  actuatorState = V;
  actuatorCommand = Vcmd;
  actuatorSlewRate = der(V);
  thetaTip = Modelica.Math.atan2(y, x);
  tipPoseX = x;
  tipPoseY = y;
  tipPoseTheta = thetaTip;
  tipError = sqrt((targetX - x)^2 + (targetY - y)^2 + 1.0e-18);

  // Bounds and zero-divisor guards; safe denominators prevent NaN/Inf
  primaryTrackingErrorOK = noEvent(time < 6.5) or tipError <= primaryTrackingErrorMax + 1.0e-6;
  finalTipErrorOK = noEvent(time < 10.0) or tipError <= finalTipErrorMax + 1.0e-6;
  boundsOK = abs(V) <= Vmax + 1.0e-6 and
             abs(Vcmd) <= Vmax + 1.0e-6 and
             abs(strainAxial) <= strainMax + 1.0e-6 and
             F_n <= F_contact_max + 1.0e-6 and
             T <= T_max + 1.0e-6 and
             clearance >= -penetrationMax - 1.0e-6 and
             primaryTrackingErrorOK and
             finalTipErrorOK;
  assert(boundsOK, "ElectroSoftAvoidB bound violated");
  assert(L_safe > 0.0 and d > 0.0, "ElectroSoftAvoidB zero divisor");

  // 100 Hz synchronized state, command, and sensor traces
  when sample(0, Ts) then
    sampleCounter = pre(sampleCounter) + 1;
    t_sensor = time;
    V_sensor = V;
    Vcmd_sensor = Vcmd;
    x_sensor = x;
    y_sensor = y;
    vx_sensor = vx;
    vy_sensor = vy;
    strain_sensor = strainAxial;
    contactForce_sensor = F_n;
    contactForceDistributed_sensor = contactForceDistributed;
    temperature_sensor = T_C;
    clearance_sensor = clearance;
    tipError_sensor = tipError;
    stiffnessSchedule_sensor = stiffnessSchedule;
  end when;

  annotation (experiment(StopTime=10.0, Interval=0.01, Tolerance=1e-6));
end ElectroSoftAvoidB;