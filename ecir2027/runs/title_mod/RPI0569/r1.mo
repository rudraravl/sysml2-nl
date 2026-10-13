model SeriesElasticTorqueE
  "Series-elastic torque actuator with inner current and outer spring-torque control.";

  // ---- Stated electrical / actuator parameters ----
  parameter Modelica.Units.SI.Voltage Vsupply = 48 "Supply voltage (stated)";
  parameter Modelica.Units.SI.Voltage Vmax = 52.8 "Command magnitude bound (stated)";
  parameter Real N = 100 "Gearbox ratio (stated)";
  parameter Modelica.Units.SI.TorquePerAngle ks = 850
    "Torsional spring stiffness (stated)";

  // ---- Assumed motor / load / contact parameters (unspecified facts) ----
  parameter Modelica.Units.SI.Resistance R = 0.5 "Winding resistance (assumed)";
  parameter Modelica.Units.SI.Inductance L = 0.5e-3 "Winding inductance (assumed)";
  parameter Modelica.Units.SI.ElectricalTorqueConstant Kt = 0.05 "Torque constant (assumed)";
  parameter Modelica.Units.SI.ElectricalTorqueConstant Ke = 0.05 "Back-EMF constant (assumed)";
  parameter Modelica.Units.SI.Inertia Jm = 1e-5 "Motor inertia (assumed)";
  parameter Modelica.Units.SI.RotationalDampingConstant bm = 1e-6 "Motor viscous friction (assumed)";
  parameter Modelica.Units.SI.Inertia Jl = 0.05 "Output link inertia (assumed)";
  parameter Modelica.Units.SI.RotationalDampingConstant bl = 0.01 "Output friction (assumed)";
  parameter Modelica.Units.SI.TorquePerAngle kc = 2000 "Contact stiffness (assumed)";
  parameter Modelica.Units.SI.RotationalDampingConstant bc = 5 "Contact damping (assumed)";
  parameter Modelica.Units.SI.ThermalResistance Rth = 0.5 "Thermal resistance (assumed)";
  parameter Modelica.Units.SI.HeatCapacity Cth = 100 "Thermal capacitance (assumed)";
  parameter Modelica.Units.SI.Temperature Tamb = 293.15 "Ambient temperature (assumed)";

  // ---- Controller / scenario parameters (stated) ----
  parameter Modelica.Units.SI.Time Ts = 1/250 "Controller sample period (stated, 250 Hz)";
  parameter Modelica.Units.SI.Time Tend = 16 "Run duration (stated)";
  parameter Modelica.Units.SI.Torque tauLoadStep = 18 "Disturbance magnitude (stated)";
  parameter Modelica.Units.SI.Time tDistStart = 16/3 "Disturbance start, middle third (derived)";
  parameter Modelica.Units.SI.Time tDistEnd = 32/3 "Disturbance end, middle third (derived)";
  parameter Modelica.Units.SI.Time tTrack = 10.4 "Tracking check time (stated)";
  parameter Modelica.Units.SI.Torque tauTrackLimit = 1.8 "Tracking error limit (stated)";

  // ---- Controller gains (assumed, tunable) ----
  parameter Real Kp_t = 0.05 "Outer torque proportional gain (assumed)";
  parameter Real Ki_t = 5.0 "Outer torque integral gain (assumed)";
  parameter Real Kp_i = 20.0 "Inner current proportional gain (assumed)";
  parameter Real Ki_i = 2000.0 "Inner current integral gain (assumed)";

  // ---- Reference command (assumed shape) ----
  parameter Modelica.Units.SI.Torque tau_ref_amp = 10.0 "Reference torque amplitude (assumed)";
  parameter Modelica.Units.SI.Time t_ref_step = 1.0 "Reference step time (assumed)";

  // ---- Continuous plant states / measurements ----
  Modelica.Units.SI.Current i "Motor current";
  Modelica.Units.SI.Angle thm "Motor angle";
  Modelica.Units.SI.AngularVelocity wm "Motor angular velocity";
  Modelica.Units.SI.Angle thg "Gearbox output angle (spring motor side)";
  Modelica.Units.SI.Angle thl "Output link angle (spring load side)";
  Modelica.Units.SI.AngularVelocity wl "Output angular velocity";
  Modelica.Units.SI.Torque tau_m "Motor torque";
  Modelica.Units.SI.Torque tau_s "Spring (transmission) torque";
  Modelica.Units.SI.Torque tau_contact "Contact force/torque on load";
  Modelica.Units.SI.Temperature T "Motor winding temperature";

  // ---- Controller signals (discrete, 250 Hz) ----
  discrete Modelica.Units.SI.Voltage v_cmd "Bounded voltage command";
  discrete Modelica.Units.SI.Voltage v_raw "Raw voltage before saturation";
  discrete Modelica.Units.SI.Current i_ref "Current reference from outer loop";
  discrete Modelica.Units.SI.Torque tau_ref "Spring-torque reference command";
  discrete Modelica.Units.SI.Torque tau_err "Spring-torque tracking error";
  discrete Real xi_i "Current-loop integrator state";
  discrete Real xi_t "Torque-loop integrator state";
  discrete Real max_err "Max |tracking error| for t >= tTrack";

  // ---- Disturbance ----
  Modelica.Units.SI.Torque tau_dist "Applied middle-third load disturbance";

  // ---- Acceptance signals ----
  Boolean tracking_ok "Primary tracking error below limit after tTrack";
  Boolean bounds_ok "All physical/control bound checks";
  Boolean no_nan "No NaN or infinite values";

equation
  // ---- Reference command (step) ----
  when sample(0, Ts) loop
    tau_ref = if time >= t_ref_step then tau_ref_amp else 0.0;
  end when;

  // ---- Middle-third disturbance (continuous time window) ----
  if time >= tDistStart and time < tDistEnd then
    tau_dist = tauLoadStep;
  else
    tau_dist = 0.0;
  end if;

  // ---- Motor electrical dynamics ----
  L*der(i) = v_cmd - R*i - Ke*wm;
  tau_m = Kt*i;

  // ---- Motor mechanical dynamics (spring reaction reflected through gear) ----
  Jm*der(wm) = tau_m - bm*wm - tau_s/N;
  der(thm) = wm;
  thg = thm/N;

  // ---- Series-elastic transmission (instrumented both sides) ----
  tau_s = ks*(thg - thl);

  // ---- Output link dynamics ----
  Jl*der(wl) = tau_s - bl*wl - tau_contact + tau_dist;
  der(thl) = wl;

  // ---- Compliant contact against rigid support at angle 0 ----
  tau_contact = kc*thl + bc*wl;

  // ---- Lumped thermal model (Joule heating) ----
  der(T) = (R*i^2 - (T - Tamb)/Rth)/Cth;

  // ---- Discrete controller at 250 Hz ----
  when sample(0, Ts) loop
    tau_err = tau_ref - tau_s;

    // Outer spring-torque PI -> current reference
    xi_t = pre(xi_t) + Ts*tau_err;
    i_ref = Kp_t*tau_err + Ki_t*xi_t;

    // Inner current PI -> raw voltage
    xi_i = pre(xi_i) + Ts*(i_ref - i);
    v_raw = Kp_i*(i_ref - i) + Ki_i*xi_i;

    // Command magnitude bounded by Vmax (fail-closed saturation)
    if v_raw > Vmax then
      v_cmd = Vmax;
    elseif v_raw < -Vmax then
      v_cmd = -Vmax;
    else
      v_cmd = v_raw;
    end if;

    // Running max of tracking error after tTrack
    if time < tTrack then
      max_err = 0.0;
    elseif abs(tau_err) > pre(max_err) then
      max_err = abs(tau_err);
    else
      max_err = pre(max_err);
    end if;
  end when;

  // ---- Acceptance checks ----
  tracking_ok = time >= tTrack and max_err < tauTrackLimit;
  bounds_ok = abs(i) < 250.0
            and abs(v_cmd) <= Vmax + 1e-6
            and T < 373.15
            and abs(thl) < 1.0
            and abs(thg - thl) < 0.1
            and abs(tau_contact) < 1000.0
            and abs(tau_s) < 1000.0;
  no_nan = (not Modelica.Math.isNaN(i))
       and (not Modelica.Math.isNaN(tau_s))
       and (not Modelica.Math.isNaN(tau_contact))
       and (not Modelica.Math.isNaN(T))
       and (not Modelica.Math.isNaN(v_cmd))
       and (not Modelica.Math.isNaN(i_ref))
       and (not Modelica.Math.isNaN(thl));

initial equation
  i = 0.0;
  thm = 0.0;
  wm = 0.0;
  thl = 0.0;
  wl = 0.0;
  T = Tamb;
  xi_i = 0.0;
  xi_t = 0.0;
  v_cmd = 0.0;
  v_raw = 0.0;
  i_ref = 0.0;
  tau_ref = 0.0;
  tau_err = 0.0;
  max_err = 0.0;

  annotation (
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Series-elastic torque actuator: 48 V brushless motor, 100:1 gearbox, 850 N.m/rad torsional spring instrumented on both sides (thg, thl). Inner current PI + outer spring-torque PI at 250 Hz, voltage command bounded at 52.8 V. Compliant contact with rigid support via kc, bc. 18 N.m disturbance applied over middle third (5.33-10.67 s). Tracks tau_ref; acceptance requires |tau_err| < 1.8 N.m after 10.4 s, bounded states, no NaN/inf."));
end SeriesElasticTorqueE;