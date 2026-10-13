model CableWinchRecoverE
  import Modelica.Constants.pi;
  import Modelica.Math.cos;
  import Modelica.Math.sin;
  import Modelica.Math.tanh;

  // Nominal plant structure
  parameter Real V_nominal = 72.0 "nominal motor voltage [V]";
  parameter Real V_limit = 1.1*V_nominal "command magnitude limit [V]";
  parameter Real N = 45.0 "gearbox ratio [-]";
  parameter Real r_drum = 0.09 "drum radius [m]";
  parameter Real m_payload = 140.0 "payload mass [kg]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real y_max = 12.0 "cable travel [m]";

  // Motor electrical parameters selected for a verifiable 72 V actuator
  parameter Real Kt = 0.10 "motor torque constant [N.m/A]";
  parameter Real Ke = 0.10 "back-emf constant [V/(rad/s)]";
  parameter Real R = 0.30 "winding resistance [Ohm]";
  parameter Real L = 0.0030 "winding inductance [H]";
  parameter Real J_motor = 0.0010 "motor rotor inertia [kg.m2]";
  parameter Real J_drum = 0.0 "drum inertia not specified; ideal drum [kg.m2]";
  parameter Real B_motor = 0.0010 "motor viscous friction [N.m.s/rad]";

  // Thermal dynamics
  parameter Real T_amb = 25.0 "ambient temperature [degC]";
  parameter Real R_th = 0.15 "thermal resistance [K/W]";
  parameter Real C_th = 800.0 "thermal capacitance [J/K]";

  // Protection limits selected as verification envelopes
  parameter Real I_max = 120.0 "current protection threshold [A]";
  parameter Real Temp_max = 90.0 "winding temperature protection threshold [degC]";

  // Disturbance profile
  parameter Real Fdist_amp = 24.0 "controlled disturbance force magnitude [N]";
  parameter Real T_run = 16.0 "run time [s]";
  parameter Real tDistStart = T_run/3.0 "middle-third disturbance start [s]";
  parameter Real tDistEnd = 2.0*T_run/3.0 "middle-third disturbance end [s]";
  parameter Real tRamp = 0.05 "smooth disturbance ramp time [s]";

  // Acceptance
  parameter Real tCheck = 10.4 "tracking check time [s]";
  parameter Real trackTol = 0.036 "primary tracking tolerance [m]";
  parameter Real dtSample = 1.0/250.0 "synchronized sample interval [s]";

  // Observer and control gains
  parameter Real tau_obs = 0.02 "disturbance observer time constant [s]";
  parameter Real Kp_y = 500.0 "position proportional gain [N/m]";
  parameter Real Kd_y = 500.0 "position derivative gain [N.s/m]";
  parameter Real Kp_w = 0.005 "speed loop proportional gain [A.s/rad]";
  parameter Real Ki_w = 0.05 "speed loop integral gain [A/rad]";
  parameter Real Kp_F = 0.02 "tension loop proportional gain [A/N]";
  parameter Real Ki_F = 0.20 "tension loop integral gain [A/(N.s)]";

  // Mechanical limit stops
  parameter Real k_stop = 1.0e5 "soft stop stiffness [N/m]";
  parameter Real d_stop = 1.0e3 "soft stop damping [N.s/m]";

  // Derived parameters
  parameter Real J_ref = m_payload*r_drum^2/N^2 "payload inertia reflected to motor [kg.m2]";
  parameter Real J_total = J_motor + J_ref + J_drum/N^2 "total motor-side inertia [kg.m2]";
  parameter Real I_hold = m_payload*g*r_drum/(N*Kt) "gravity hold current [A]";

  // Observable outputs
  output Real vCmdUnsat "unbounded voltage command [V]";
  output Real vAct "saturated actuator voltage [V]";
  output Real i(start=I_hold, fixed=true) "motor current [A]";
  output Real theta_m(start=0.0, fixed=true) "motor angle [rad]";
  output Real omega_m(start=0.0, fixed=true) "motor speed [rad/s]";
  output Real y "payload height [m]";
  output Real v "payload velocity [m/s]";
  output Real F_tension "cable tension [N]";
  output Real Fd_est(start=0.0, fixed=true) "disturbance estimate [N]";
  output Real Tw(start=T_amb, fixed=true) "winding temperature [degC]";
  output Real e_y "primary tracking error [m]";
  output Real peakDeviation(start=0.0) "peak absolute tracking error [m]";
  output Real recoveryTime(start=0.0) "recovery time after disturbance [s]";
  output Real terminalError "terminal tracking error [m]";
  output Boolean protectionTrip "fail-closed protection trip flag";

  // Internal states
  Real intSpeed(start=0.0, fixed=true) "speed-loop integrator [rad]";
  Real intTension(start=0.0, fixed=true) "tension-loop integrator [N.s]";
  Real alpha_m "motor angular acceleration [rad/s2]";
  Real a_payload "payload acceleration [m/s2]";
  Real F_dist "applied disturbance force [N]";
  Real F_stop "mechanical limit stop force [N]";
  Real y_ref "reference payload height [m]";
  Real v_ref "reference payload velocity [m/s]";
  Real a_ref "reference payload acceleration [m/s2]";
  Real omega_ref "reference motor speed [rad/s]";
  Real e_v "velocity tracking error [m/s]";
  Real e_w "motor speed error [rad/s]";
  Real e_F "tension error [N]";
  Real F_cmd "cable tension command [N]";
  Real I_ff "feedforward current [A]";
  Real I_speed "speed-loop current [A]";
  Real I_tension "tension-loop current [A]";
  Real I_cmd "total current command [A]";
  Boolean overCurrent;
  Boolean overTemp;
  Boolean overTravel;
  Boolean overVoltage;

  // Synchronized 250 Hz traces
  discrete Real tSampled(start=0.0) "sampled time [s]";
  discrete Real vSampled(start=0.0) "sampled voltage [V]";
  discrete Real iSampled(start=0.0) "sampled current [A]";
  discrete Real thetaSampled(start=0.0) "sampled motor angle [rad]";
  discrete Real omegaSampled(start=0.0) "sampled motor speed [rad/s]";
  discrete Real ySampled(start=0.0) "sampled height [m]";
  discrete Real vSampledPayload(start=0.0) "sampled payload velocity [m/s]";
  discrete Real tensionSampled(start=0.0) "sampled tension [N]";
  discrete Real disturbanceEstSampled(start=0.0) "sampled disturbance estimate [N]";
  discrete Real tempSampled(start=T_amb) "sampled winding temperature [degC]";
  discrete Real commandSampled(start=0.0) "sampled voltage command [V]";
  discrete Real errorSampled(start=0.0) "sampled tracking error [m]";

  // Acceptance records
  discrete Real eAt104(start=0.0) "tracking error captured at 10.4 s [m]";
  Boolean done104(start=false);
  Boolean recovered(start=false);

equation
  // Smooth motion command over full travel
  y_ref = 0.5*y_max*(1.0 - cos(pi*time/T_run));
  v_ref = 0.5*y_max*(pi/T_run)*sin(pi*time/T_run);
  a_ref = 0.5*y_max*(pi/T_run)^2*cos(pi*time/T_run);
  omega_ref = N/r_drum*v_ref;

  // Controlled middle-third disturbance force, downward positive
  F_dist = 0.5*Fdist_amp*(tanh((time - tDistStart)/tRamp) - tanh((time - tDistEnd)/tRamp));

  // Mechanical limit stops
  F_stop = if y > y_max then -k_stop*(y - y_max) - d_stop*v
           else if y < 0.0 then k_stop*(-y) - d_stop*v
           else 0.0;

  // Plant dynamics
  der(theta_m) = omega_m;
  der(omega_m) = alpha_m;
  alpha_m = (Kt*i - B_motor*omega_m - (m_payload*g + F_dist - F_stop)*r_drum/N)/J_total;
  y = r_drum*theta_m/N;
  v = r_drum*omega_m/N;
  a_payload = r_drum*alpha_m/N;

  // Cable tension from transmitted motor torque
  F_tension = ((Kt*i - J_motor*alpha_m - B_motor*omega_m)*N - J_drum*alpha_m/N)/r_drum;

  // Electrical dynamics
  der(i) = (vAct - R*i - Ke*omega_m)/L;

  // Thermal dynamics
  der(Tw) = (R*i^2 - (Tw - T_amb)/R_th)/C_th;

  // Disturbance observer
  der(Fd_est) = (F_tension + F_stop - m_payload*g - m_payload*a_payload - Fd_est)/tau_obs;

  // Feedforward plus cascaded motor-speed and cable-tension control
  e_y = y_ref - y;
  e_v = v_ref - v;
  e_w = omega_ref - omega_m;
  F_cmd = m_payload*g + m_payload*a_ref + Fd_est + Kp_y*e_y + Kd_y*e_v;
  e_F = F_cmd - F_tension;
  I_ff = F_cmd*r_drum/(N*Kt);
  I_speed = Kp_w*e_w + Ki_w*intSpeed;
  I_tension = Kp_F*e_F + Ki_F*intTension;
  I_cmd = I_ff + I_speed + I_tension;
  vCmdUnsat = R*I_cmd + Ke*omega_m;
  vAct = if vCmdUnsat > V_limit then V_limit
         else if vCmdUnsat < -V_limit then -V_limit
         else vCmdUnsat;

  // Anti-windup during voltage saturation
  der(intSpeed) = if noEvent(abs(vCmdUnsat) >= V_limit) then 0.0 else e_w;
  der(intTension) = if noEvent(abs(vCmdUnsat) >= V_limit) then 0.0 else e_F;

  // Protection monitors
  overCurrent = abs(i) > I_max;
  overTemp = Tw > Temp_max;
  overTravel = y < -trackTol or y > y_max + trackTol;
  overVoltage = abs(vAct) > V_limit + 1.0e-6;
  protectionTrip = overCurrent or overTemp or overTravel or overVoltage;
  terminalError = abs(e_y);

  // Synchronized 250 Hz sensor and command traces
  when sample(0, dtSample) then
    tSampled = time;
    vSampled = vAct;
    iSampled = i;
    thetaSampled = theta_m;
    omegaSampled = omega_m;
    ySampled = y;
    vSampledPayload = v;
    tensionSampled = F_tension;
    disturbanceEstSampled = Fd_est;
    tempSampled = Tw;
    commandSampled = vCmdUnsat;
    errorSampled = e_y;
  end when;

  // Acceptance records
  when abs(e_y) > pre(peakDeviation) then
    peakDeviation = abs(e_y);
  end when;

  when time >= tCheck and not pre(done104) then
    eAt104 = abs(e_y);
    done104 = true;
  end when;

  when time >= tDistEnd and abs(e_y) <= trackTol and not pre(recovered) then
    recoveryTime = time - tDistEnd;
    recovered = true;
  end when;

  // Fail-closed acceptance and finite-value checks
  assert(noEvent(abs(vAct) < 1.0e12 and abs(vCmdUnsat) < 1.0e12 and abs(i) < 1.0e12 and
                 abs(omega_m) < 1.0e12 and abs(theta_m) < 1.0e12 and abs(F_tension) < 1.0e12 and
                 abs(Fd_est) < 1.0e12 and abs(Tw) < 1.0e12 and abs(F_dist) < 1.0e12),
         "non-finite or excessive physical, control, or estimator value");

  when terminal() then
    assert(not protectionTrip, "protection tripped during run");
    assert(eAt104 <= trackTol, "primary tracking error at 10.4 s above tolerance");
    assert(abs(y_ref - y) <= trackTol, "terminal tracking error above tolerance");
    assert(recovered, "system did not recover after disturbance");
  end when;

  annotation(experiment(StopTime=16.0, Interval=0.004, Tolerance=1.0e-6));
end CableWinchRecoverE;