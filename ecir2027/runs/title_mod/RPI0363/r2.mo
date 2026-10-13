model ParallelGripGraspC
  "Contact-rich parallel-grip grasp using impedance motion followed by force regulation"

  // Numerical constants
  constant Real pi = 3.141592653589793;
  constant Real g_n = 9.80665;
  constant Real eps_pen = 1.0e-9;
  constant Boolean collision_enabled = true;

  // Requirement-specified parameters
  parameter Real m_palm = 6.0 "kg, fixed palm mass";
  parameter Real m_finger = 0.5 "kg, each opposing box finger";
  parameter Real travel = 0.05 "m, prismatic joint travel";
  parameter Real mu = 0.78 "friction coefficient";
  parameter Real restitution = 0.03 "collision restitution";
  parameter Real Fmax = 41.4 "N, maximum command per finger";
  parameter Real Fdist = 7.2 "N, tangential load disturbance";
  parameter Real Ts = 1.0/125.0 "s, control and trace period";
  parameter Real Tfinal = 12.0 "s";
  parameter Real t_hold = 7.8 "s";
  parameter Real err_bound = 0.016 "m";

  // Nominal/unspecified plant and controller values needed for a well-posed simulation
  parameter Real m_object = 1.0 "kg, nominal rigid-object mass; not stated by request";
  parameter Real w_half = 0.01 "m, nominal object half-width along closure axis; not stated by request";
  parameter Real k_pad = 5000.0 "N/m, nominal compliant-pad stiffness; not stated by request";
  parameter Real k_table = 1.0e5 "N/m, nominal rigid support-table contact stiffness; not stated by request";
  parameter Real k_stop = 1.0e5 "N/m, nominal joint stop stiffness; not stated by request";
  parameter Real c_stop = 500.0 "N.s/m, nominal joint stop damping; not stated by request";
  parameter Real b_joint = 20.0 "N.s/m, nominal prismatic joint damping; not stated by request";
  parameter Real v_eps = 1.0e-3 "m/s, friction regularization velocity";
  parameter Real Fdes = 20.0 "N, desired regulated normal force per finger";
  parameter Real Fcontact_min = 1.0 "N, stable-contact threshold";
  parameter Real Kp = 1000.0 "N/m, impedance position gain";
  parameter Real Kd = 40.0 "N.s/m, impedance velocity gain";
  parameter Real Kf = 0.5 "force-regulation proportional gain";
  parameter Real Kif = 0.2 "force-regulation integral gain";
  parameter Real Fint_max = 10.0 "N, force integral saturation";
  parameter Real t_ramp = 2.0 "s, impedance motion ramp duration";
  parameter Real q_final = travel - w_half + Fdes/k_pad "m, closure target";

  // Derived damping coefficients using restitution
  parameter Real m_eff = m_finger*m_object/(m_finger + m_object);
  parameter Real zeta_e = sqrt((log(restitution))^2/(pi^2 + (log(restitution))^2));
  parameter Real c_pad = 2.0*zeta_e*sqrt(k_pad*m_eff);
  parameter Real c_table = 2.0*zeta_e*sqrt(k_table*m_object);

  // Fixed palm mass represented explicitly but with no dynamic state
  Real palm_mass "kg";

  // Continuous plant states
  Real qL(start=0.0, fixed=true) "m, left finger closure";
  Real vL(start=0.0, fixed=true) "m/s, left finger velocity";
  Real qR(start=0.0, fixed=true) "m, right finger closure";
  Real vR(start=0.0, fixed=true) "m/s, right finger velocity";
  Real x_obj(start=0.0, fixed=true) "m, object tangential pose";
  Real vx(start=0.0, fixed=true) "m/s, object tangential velocity";
  Real y_obj(start=0.0, fixed=true) "m, object normal pose";
  Real vy(start=0.0, fixed=true) "m/s, object normal velocity";
  Real z_obj(start=0.0, fixed=true) "m, object vertical pose";
  Real vz(start=0.0, fixed=true) "m/s, object vertical velocity";

  // Actuator and contact variables
  Real uL "N, bounded left actuator force";
  Real uR "N, bounded right actuator force";
  Real FL "N, left normal contact force";
  Real FR "N, right normal contact force";
  Real N_table "N, table normal contact force";
  Real Fdist_active "N, active disturbance force";
  Real FstopL "N, left joint stop generalized force";
  Real FstopR "N, right joint stop generalized force";

  // Contact geometry intermediates
  Real yL0 "m, left undeformed pad surface";
  Real yR0 "m, right undeformed pad surface";
  Real ysL "m, object left surface";
  Real ysR "m, object right surface";
  Real penL "m, left pad penetration";
  Real penR "m, right pad penetration";
  Real phiL "1, left contact indicator";
  Real phiR "1, right contact indicator";
  Real penL_lo "m";
  Real penL_hi "m";
  Real phiL_lo "1";
  Real phiL_hi "1";
  Real penR_lo "m";
  Real penR_hi "m";
  Real phiR_lo "1";
  Real phiR_hi "1";
  Real pen_z "m, table penetration";
  Real phi_z "1, table contact indicator";

  // Discrete controller variables at 125 Hz
  discrete Real u_cmdL(start=0.0) "N, left commanded force";
  discrete Real u_cmdR(start=0.0) "N, right commanded force";
  discrete Real intFerrL(start=0.0) "N.s, left force integral";
  discrete Real intFerrR(start=0.0) "N.s, right force integral";
  discrete Real q_ref(start=0.0) "m, impedance closure reference";
  discrete Real u_impL(start=0.0) "N, left impedance command";
  discrete Real u_impR(start=0.0) "N, right impedance command";
  discrete Real ferrL(start=0.0) "N, left force error";
  discrete Real ferrR(start=0.0) "N, right force error";
  discrete Real u_cmdL_raw(start=0.0) "N";
  discrete Real u_cmdR_raw(start=0.0) "N";
  Integer mode(start=0) "0=impedance motion, 1=force regulation";
  Integer mode_next(start=0);

  // Synchronized 125 Hz traces
  discrete Real trace_qL(start=0.0);
  discrete Real trace_qR(start=0.0);
  discrete Real trace_vL(start=0.0);
  discrete Real trace_vR(start=0.0);
  discrete Real trace_x(start=0.0);
  discrete Real trace_y(start=0.0);
  discrete Real trace_z(start=0.0);
  discrete Real trace_vx(start=0.0);
  discrete Real trace_vy(start=0.0);
  discrete Real trace_vz(start=0.0);
  discrete Real trace_uL(start=0.0);
  discrete Real trace_uR(start=0.0);
  discrete Real trace_FL(start=0.0);
  discrete Real trace_FR(start=0.0);
  discrete Real trace_N_table(start=0.0);
  discrete Real trace_mode(start=0);

  // Requirement checks
  Real tracking_error "m, primary object tangential displacement";
  Real object_displacement "m";
  Boolean travel_bound_ok;
  Boolean effort_bound_ok;
  Boolean stable_contact;
  Boolean grasp_loss;
  Boolean tracking_ok;

equation
  palm_mass = m_palm;

  // Disturbance during middle third of 12 s
  Fdist_active = noEvent(if time >= Tfinal/3.0 and time < 2.0*Tfinal/3.0 then Fdist else 0.0);

  // Bounded linear actuators
  uL = max(-Fmax, min(Fmax, u_cmdL));
  uR = max(-Fmax, min(Fmax, u_cmdR));

  // Finger dynamics on prismatic joints
  der(qL) = vL;
  m_finger*der(vL) = uL - b_joint*vL - FL + FstopL;

  der(qR) = vR;
  m_finger*der(vR) = uR - b_joint*vR - FR + FstopR;

  // Joint stops for travel bounds
  penL_lo = max(0.0, -qL);
  penL_hi = max(0.0, qL - travel);
  phiL_lo = penL_lo/(penL_lo + eps_pen);
  phiL_hi = penL_hi/(penL_hi + eps_pen);
  FstopL = k_stop*(penL_lo - penL_hi) + c_stop*(max(0.0, -vL)*phiL_lo - max(0.0, vL)*phiL_hi);

  penR_lo = max(0.0, -qR);
  penR_hi = max(0.0, qR - travel);
  phiR_lo = penR_lo/(penR_lo + eps_pen);
  phiR_hi = penR_hi/(penR_hi + eps_pen);
  FstopR = k_stop*(penR_lo - penR_hi) + c_stop*(max(0.0, -vR)*phiR_lo - max(0.0, vR)*phiR_hi);

  // Compliant pad contact
  yL0 = -travel + qL;
  yR0 = travel - qR;
  ysL = y_obj - w_half;
  ysR = y_obj + w_half;

  penL = max(0.0, yL0 - ysL);
  penR = max(0.0, ysR - yR0);
  phiL = penL/(penL + eps_pen);
  phiR = penR/(penR + eps_pen);

  FL = max(0.0, k_pad*penL + c_pad*(vL - vy)*phiL);
  FR = max(0.0, k_pad*penR + c_pad*(vy + vR)*phiR);

  // Rigid support table with collision enabled
  pen_z = max(0.0, -z_obj);
  phi_z = pen_z/(pen_z + eps_pen);
  N_table = max(0.0, k_table*pen_z + c_table*(-vz)*phi_z);

  // Object dynamics
  der(x_obj) = vx;
  m_object*der(vx) = Fdist_active - mu*(FL + FR + N_table)*tanh(vx/v_eps);

  der(y_obj) = vy;
  m_object*der(vy) = FL - FR - mu*N_table*tanh(vy/v_eps);

  der(z_obj) = vz;
  m_object*der(vz) = -m_object*g_n + N_table;

  // Requirement-check variables
  tracking_error = abs(x_obj);
  object_displacement = sqrt(x_obj*x_obj + y_obj*y_obj + z_obj*z_obj);
  travel_bound_ok = qL >= -1.0e-6 and qL <= travel + 1.0e-6 and
                   qR >= -1.0e-6 and qR <= travel + 1.0e-6;
  effort_bound_ok = abs(uL) <= Fmax + 1.0e-6 and abs(uR) <= Fmax + 1.0e-6;
  stable_contact = FL >= Fcontact_min and FR >= Fcontact_min;
  grasp_loss = not stable_contact;
  tracking_ok = time >= t_hold and tracking_error <= err_bound;

  // 125 Hz controller and synchronized traces
  when sample(0.0, Ts) then
    mode_next = if pre(mode) == 0 and (FL > Fcontact_min and FR > Fcontact_min) and time >= 1.5 then 1
                elseif pre(mode) == 1 then 1
                else 0;
    mode = mode_next;

    q_ref = noEvent(if time < t_ramp then q_final*time/t_ramp else q_final);

    u_impL = Kp*(q_ref - qL) - Kd*vL;
    u_impR = Kp*(q_ref - qR) - Kd*vR;

    ferrL = Fdes - FL;
    ferrR = Fdes - FR;

    if mode_next == 1 then
      intFerrL = max(-Fint_max, min(Fint_max, pre(intFerrL) + Ts*ferrL));
      intFerrR = max(-Fint_max, min(Fint_max, pre(intFerrR) + Ts*ferrR));
      u_cmdL_raw = u_impL + Fdes + Kf*ferrL + Kif*intFerrL;
      u_cmdR_raw = u_impR + Fdes + Kf*ferrR + Kif*intFerrR;
    else
      intFerrL = 0.0;
      intFerrR = 0.0;
      u_cmdL_raw = u_impL;
      u_cmdR_raw = u_impR;
    end if;

    u_cmdL = max(-Fmax, min(Fmax, u_cmdL_raw));
    u_cmdR = max(-Fmax, min(Fmax, u_cmdR_raw));

    trace_qL = qL;
    trace_qR = qR;
    trace_vL = vL;
    trace_vR = vR;
    trace_x = x_obj;
    trace_y = y_obj;
    trace_z = z_obj;
    trace_vx = vx;
    trace_vy = vy;
    trace_vz = vz;
    trace_uL = uL;
    trace_uR = uR;
    trace_FL = FL;
    trace_FR = FR;
    trace_N_table = N_table;
    trace_mode = mode;
  end when;

  annotation (experiment(StartTime=0.0, StopTime=12.0, Tolerance=1.0e-6));
end ParallelGripGraspC;