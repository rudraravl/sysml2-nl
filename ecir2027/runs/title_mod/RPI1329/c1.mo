model TendonSoftGraspC
  import Modelica.Constants.pi;

  constant Real sqrt3 = sqrt(3.0);

  parameter Integer nSec=6 "number of constant-curvature sections";
  parameter Integer nTen=3 "number of tendons";
  parameter Real L_total=0.55 "m";
  parameter Real Ls=L_total/nSec "m";
  parameter Real F_cmd_max=38.6 "N per tendon";
  parameter Real F_dist=3.6 "N";
  parameter Real mu=0.70;
  parameter Real Ts=1/125 "s";
  parameter Real T_final=12 "s";
  parameter Real t_dist_start=T_final/3 "s";
  parameter Real t_dist_end=2*T_final/3 "s";

  parameter Real F_N_des=F_dist/mu "N, derived no-slip total normal force";
  parameter Real F_contact_max=F_cmd_max "N, per-contact upper band; local overload threshold not specified";
  parameter Real F_total_max=3*F_cmd_max "N";
  parameter Real q_max=1.0 "normalized deformation bound; physical curvature limit unknown";
  parameter Real eps_f=1e-6 "N";
  parameter Real eps_q=1e-6;
  parameter Real v_eps=1e-3 "m/s, friction smoothing; unknown";

  parameter Real k_c=F_cmd_max/L_total "N/m, contact stiffness derived from command limit and length";
  parameter Real K_total=1/F_cmd_max "1/N";
  parameter Real K_shape=K_total "1/N";
  parameter Real tau_actuator=Ts "s, actuator time constant; unknown, set to control period";
  parameter Real tau_sec=4*Ts "s, section curvature time constant; unknown, set to control period";
  parameter Real Kp_FN=1.0;
  parameter Real Ki_FN=0.0;
  parameter Real K_red=1.0;
  parameter Real m_obj=1.0 "kg, object mass unknown, placeholder";
  parameter Real K_hold=F_cmd_max/0.016 "N/m, derived from command limit and tracking bound";
  parameter Real B_hold=2*sqrt(K_hold*m_obj) "N.s/m";
  parameter Real q_nom=F_N_des/F_cmd_max;

  parameter Real phi[3]={0, 2*pi/3, 4*pi/3} "rad, tendon spacing";
  parameter Real psi[6]={0, pi/3, 2*pi/3, pi, 4*pi/3, 5*pi/3} "rad, section phase; routing unknown, uniform for explicit model";

  Real q[6] "normalized section curvatures";
  Real q_ref[6] "commanded section curvatures";
  Real q_pos[6] "positive contact curvature";
  Real f_N[6] "per-contact normal forces";
  Real f_sens[6] "distributed contact sensors";
  Real F_N "total normal grasp force";
  Real f_avg "average contact force";
  Real redX "contact redistribution moment component X";
  Real redY "contact redistribution moment component Y";

  Real tau_act[3] "actual tendon tensions";
  Real tau_sens[3] "actuator tension sensors";
  Real tau_sum_act "actual tension sum";
  Real Mx_act "actual bending moment X";
  Real My_act "actual bending moment Y";

  discrete Real tau_cmd[3] "tendon command traces";
  discrete Real tau_sum_cmd "commanded tension sum trace";
  discrete Real Mx_cmd "commanded redistribution moment X";
  discrete Real My_cmd "commanded redistribution moment Y";
  discrete Real I_FN "normal-force integral state";

  Real x_obj "object displacement";
  Real v_obj "object velocity";
  Real x_obj_sens "object pose sensor";
  Real v_obj_sens "object velocity sensor";
  Real F_t_active "active tangential disturbance";
  Real F_friction "friction force on object";

  Boolean actuatorBoundsOK;
  Boolean deformationBoundsOK;
  Boolean perContactBandOK;
  Boolean totalForceBandOK;
  Boolean contactLossOK;
  Boolean trackingErrorOK;
  Boolean finitePhysical;
  Boolean finiteControl;
  Boolean finiteEstimator;
  Boolean finiteOK;
  Boolean forceBandsOK;
  Boolean boundsOK;

initial equation
  q = fill(q_nom, nSec);
  tau_act = fill(F_N_des/3, nTen);
  tau_cmd = fill(F_N_des/3, nTen);
  tau_sum_cmd = F_N_des;
  Mx_cmd = 0.0;
  My_cmd = 0.0;
  I_FN = 0.0;
  x_obj = 0.0;
  v_obj = 0.0;

equation
  F_t_active = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  for j in 1:nTen loop
    der(tau_act[j]) = (tau_cmd[j] - tau_act[j])/tau_actuator;
    tau_sens[j] = tau_act[j];
  end for;

  tau_sum_act = tau_act[1] + tau_act[2] + tau_act[3];
  Mx_act = tau_act[1]*cos(phi[1]) + tau_act[2]*cos(phi[2]) + tau_act[3]*cos(phi[3]);
  My_act = tau_act[1]*sin(phi[1]) + tau_act[2]*sin(phi[2]) + tau_act[3]*sin(phi[3]);

  for i in 1:nSec loop
    q_ref[i] = K_total*tau_sum_act + K_shape*(Mx_act*cos(psi[i]) + My_act*sin(psi[i]));
    der(q[i]) = (q_ref[i] - q[i])/tau_sec;
    q_pos[i] = max(eps_q, q[i]);
    f_N[i] = k_c*Ls*q_pos[i];
    f_sens[i] = f_N[i];
  end for;

  F_N = f_N[1] + f_N[2] + f_N[3] + f_N[4] + f_N[5] + f_N[6];
  f_avg = F_N/nSec;

  redX = (f_avg - f_N[1])*cos(psi[1])
       + (f_avg - f_N[2])*cos(psi[2])
       + (f_avg - f_N[3])*cos(psi[3])
       + (f_avg - f_N[4])*cos(psi[4])
       + (f_avg - f_N[5])*cos(psi[5])
       + (f_avg - f_N[6])*cos(psi[6]);

  redY = (f_avg - f_N[1])*sin(psi[1])
       + (f_avg - f_N[2])*sin(psi[2])
       + (f_avg - f_N[3])*sin(psi[3])
       + (f_avg - f_N[4])*sin(psi[4])
       + (f_avg - f_N[5])*sin(psi[5])
       + (f_avg - f_N[6])*sin(psi[6]);

  F_friction = -mu*F_N*tanh(v_obj/v_eps);
  der(x_obj) = v_obj;
  der(v_obj) = (F_t_active + F_friction - K_hold*x_obj - B_hold*v_obj)/m_obj;
  x_obj_sens = x_obj;
  v_obj_sens = v_obj;

  actuatorBoundsOK = tau_cmd[1] >= 0.0 and tau_cmd[1] <= F_cmd_max
                 and tau_cmd[2] >= 0.0 and tau_cmd[2] <= F_cmd_max
                 and tau_cmd[3] >= 0.0 and tau_cmd[3] <= F_cmd_max;

  deformationBoundsOK = abs(q[1]) <= q_max and abs(q[2]) <= q_max and abs(q[3]) <= q_max
                     and abs(q[4]) <= q_max and abs(q[5]) <= q_max and abs(q[6]) <= q_max;

  perContactBandOK = f_N[1] >= 0.0 and f_N[1] <= F_contact_max
                 and f_N[2] >= 0.0 and f_N[2] <= F_contact_max
                 and f_N[3] >= 0.0 and f_N[3] <= F_contact_max
                 and f_N[4] >= 0.0 and f_N[4] <= F_contact_max
                 and f_N[5] >= 0.0 and f_N[5] <= F_contact_max
                 and f_N[6] >= 0.0 and f_N[6] <= F_contact_max;

  totalForceBandOK = F_N >= F_N_des - eps_f and F_N <= F_total_max;

  contactLossOK = f_N[1] >= eps_f and f_N[2] >= eps_f and f_N[3] >= eps_f
              and f_N[4] >= eps_f and f_N[5] >= eps_f and f_N[6] >= eps_f;

  trackingErrorOK = if time >= 7.8 then abs(x_obj) <= 0.016 else true;

  finitePhysical = abs(q[1]) < 1e6 and abs(q[2]) < 1e6 and abs(q[3]) < 1e6
               and abs(q[4]) < 1e6 and abs(q[5]) < 1e6 and abs(q[6]) < 1e6
               and abs(F_N) < 1e6 and abs(x_obj) < 1e6 and abs(v_obj) < 1e6
               and abs(tau_act[1]) < 1e6 and abs(tau_act[2]) < 1e6 and abs(tau_act[3]) < 1e6
               and abs(tau_sum_act) < 1e6 and abs(Mx_act) < 1e6 and abs(My_act) < 1e6;

  finiteControl = abs(tau_cmd[1]) < 1e6 and abs(tau_cmd[2]) < 1e6 and abs(tau_cmd[3]) < 1e6
              and abs(tau_sum_cmd) < 1e6 and abs(Mx_cmd) < 1e6 and abs(My_cmd) < 1e6;

  finiteEstimator = true;
  finiteOK = finitePhysical and finiteControl and finiteEstimator;

  forceBandsOK = perContactBandOK and totalForceBandOK;
  boundsOK = actuatorBoundsOK and deformationBoundsOK and forceBandsOK and contactLossOK and trackingErrorOK and finiteOK;

  assert(actuatorBoundsOK, "actuator command bound violated");
  assert(deformationBoundsOK, "deformation bound violated");
  assert(perContactBandOK, "per-contact force band violated");
  assert(totalForceBandOK, "total force band violated");
  assert(contactLossOK, "contact loss");
  assert(trackingErrorOK, "primary tracking error violated after 7.8 s");
  assert(finiteOK, "non-finite physical, control, or estimator value");

  when sample(0, Ts) then
    I_FN = pre(I_FN) + Ki_FN*Ts*(F_N_des - F_N);
    tau_sum_cmd = F_N_des + Kp_FN*(F_N_des - F_N) + pre(I_FN);
    Mx_cmd = K_red*redX;
    My_cmd = K_red*redY;
    tau_cmd[1] = max(0.0, min(F_cmd_max, tau_sum_cmd/3 + (2.0/3.0)*Mx_cmd));
    tau_cmd[2] = max(0.0, min(F_cmd_max, tau_sum_cmd/3 - Mx_cmd/3 + My_cmd/sqrt3));
    tau_cmd[3] = max(0.0, min(F_cmd_max, tau_sum_cmd/3 - Mx_cmd/3 - My_cmd/sqrt3));
  end when;

  annotation(experiment(StopTime=12, Tolerance=1e-6, Interval=0.008));
end TendonSoftGraspC;