model ElectroSoftCrawlA
  // Membrane geometry and material facts stated in the requirement
  parameter Real L0(unit="m") = 0.20 "membrane length";
  parameter Real W(unit="m") = 0.05 "membrane width";
  parameter Real h(unit="m") = 0.8e-3 "membrane thickness";
  parameter Real V_max(unit="V") = 3600.0 "command magnitude limit";

  // Explicit dielectric permittivity; eps_r is a nominal unknown to be calibrated
  parameter Real eps0(unit="F/m") = 8.854187817e-12 "vacuum permittivity";
  parameter Real eps_r = 2.5 "relative permittivity, nominal unknown";
  parameter Real A_mem(unit="m2") = L0*W "membrane area";
  parameter Real A_section(unit="m2") = W*h "section cross-section area";
  parameter Real L_section(unit="m") = L0/2 "two lumped sections";
  parameter Real volume_section(unit="m3") = A_section*L_section;

  // Viscoelasticity; moduli and viscosity are nominal unknowns requiring calibration
  parameter Real E_inf(unit="Pa") = 5.0e4 "equilibrium elastomer modulus";
  parameter Real E1(unit="Pa") = 5.0e4 "Maxwell spring modulus";
  parameter Real eta1(unit="Pa.s") = 5.0e3 "Maxwell viscosity";
  parameter Real tau_m(unit="s") = eta1/E1 "Maxwell relaxation time";
  parameter Real b_mem(unit="N.s") = 20.0 "strain-rate damping";
  parameter Real T_pre(unit="N") = 2.0 "pre-tension";

  // Leakage and thermal state; parameters are nominal unknowns
  parameter Real G_leak(unit="S") = 1.0e-12 "leakage conductance";
  parameter Real C_th(unit="J/K") = 1.0e-2 "thermal capacitance";
  parameter Real R_th(unit="K/W") = 100.0 "thermal resistance";
  parameter Real thetaAmb(unit="K") = 293.15 "ambient temperature";

  // High-voltage channel
  parameter Real slewRate(unit="V/s") = 20000.0 "slew limit";
  parameter Real tau_slew(unit="s") = 0.01 "slew smoothing time";
  parameter Real V_bias(unit="V") = 1000.0 "bias voltage";
  parameter Real K_eps(unit="V") = 1.0e5 "strain-to-voltage gain";
  parameter Real K_track_pos(unit="V/m") = 5000.0 "position tracking voltage gain";

  // Gait
  parameter Real f_g(unit="Hz") = 1.0 "gait frequency";
  parameter Real T_g(unit="s") = 1.0/f_g "gait period";
  parameter Real pi = 3.141592653589793;
  parameter Real psi = pi "phase shift between rear and front contact pressure";
  parameter Real eps_mean = 0.05 "mean commanded strain";
  parameter Real eps_amp = 0.02 "strain amplitude";
  parameter Real eps_min = 0.0 "lower strain bound";
  parameter Real eps_max = 0.15 "upper strain bound";
  parameter Real kappa_max(unit="1/m") = 1.0 "curvature bound";
  parameter Real strideRef(unit="m") = 0.02 "reference forward progress per cycle";

  // Body, friction, ridges, and disturbance
  parameter Real m_body(unit="kg") = 0.8 "body mass, nominal unknown";
  parameter Real g_n(unit="m/s2") = 9.81 "gravity";
  parameter Real mu_forward = 1.2 "forward friction coefficient";
  parameter Real mu_backward = 1.5 "backward friction coefficient";
  parameter Real b_ground(unit="N.s/m") = 2.0 "ground damping";
  parameter Real K_crawl = 0.5 "tension-to-propulsion gain";
  parameter Real Kp_pos(unit="N/m") = 800.0 "position tracking gain";
  parameter Real Kd_pos(unit="N.s/m") = 50.0 "velocity tracking gain";
  parameter Real K_odom(unit="m") = 0.1 "odometry strain correction gain";
  parameter Real h_ridge(unit="m") = 0.002 "low ridge height, nominal unknown";
  parameter Real x_ridge1(unit="m") = 0.0 "first ridge position";
  parameter Real x_ridge2(unit="m") = L0 "second ridge position";
  parameter Real k_ridge = 0.5 "ridge friction amplification";
  parameter Real F_drag_val(unit="N") = 2.5 "drag disturbance magnitude";
  parameter Real t_drag_start(unit="s") = 8.0/3.0 "middle third start";
  parameter Real t_drag_end(unit="s") = 16.0/3.0 "middle third end";
  parameter Real Ts(unit="s") = 1.0/80.0 "80 Hz metric sampling";

  // Continuous states
  Real x(unit="m", start=0.0) "body displacement";
  Real v(unit="m/s", start=0.0) "body velocity";
  Real eps1(start=eps_mean) "rear section strain";
  Real eps2(start=eps_mean) "front section strain";
  Real q1(unit="Pa", start=0.0) "rear Maxwell stress";
  Real q2(unit="Pa", start=0.0) "front Maxwell stress";
  Real V_hv(unit="V", start=0.0) "slew-limited high voltage";
  Real theta(unit="K", start=thetaAmb) "actuator temperature";
  Real eps1_hat(start=eps_mean) "rear strain sensor estimate";
  Real eps2_hat(start=eps_mean) "front strain sensor estimate";
  Real x_hat(unit="m", start=0.0) "odometry estimate";

  // Discrete metric states
  Integer nCycles(start=0) "completed gait cycles";
  discrete Real lastCycleX(unit="m", start=0.0) "displacement at last cycle boundary";
  discrete Real slipPerCycle(unit="m", start=0.0) "per-cycle slip";

  // Algebraic physical variables
  Real C_dea(unit="F") "DEA capacitance";
  Real V_eff(unit="V") "effective bounded voltage";
  Real V_cmd(unit="V") "magnitude-limited command";
  Real V_cmd_raw(unit="V") "unclamped command";
  Real p_e(unit="Pa") "Maxwell pressure";
  Real I_leak(unit="A") "leakage current";
  Real I_cap(unit="A") "capacitive current";
  Real I_supply(unit="A") "supply current";
  Real P_leak(unit="W") "leakage power";
  Real P_visco(unit="W") "viscoelastic loss power";
  Real T1(unit="N") "rear membrane tension";
  Real T2(unit="N") "front membrane tension";
  Real T_avg(unit="N") "average tension";
  Real eps1_dot(unit="1/s") "rear strain rate";
  Real eps2_dot(unit="1/s") "front strain rate";
  Real T_ref1(unit="N") "rear reference tension";
  Real T_ref2(unit="N") "front reference tension";
  Real eps_ref1 "rear commanded strain";
  Real eps_ref2 "front commanded strain";
  Real eps_ref1_raw "unclamped rear command";
  Real eps_ref2_raw "unclamped front command";
  Real phi(unit="rad") "gait phase";
  Real pRear "rear contact pressure duty";
  Real pFront "front contact pressure duty";
  Real gaitDrive "positive gait drive waveform";
  Real L_current(unit="m") "current membrane length";
  Real kappa(unit="1/m") "section curvature";
  Real kappa_hat(unit="1/m") "estimated curvature";
  Real eps_avg "average strain";
  Real N_plane(unit="N") "plane normal force";
  Real mu_eff "directional friction coefficient";
  Real r1 "ridge profile at rear contact";
  Real r2 "ridge profile at front contact";
  Real ridgeAmp "ridge friction amplification";
  Real F_limit(unit="N") "friction force bound";
  Real F_prop_raw(unit="N") "unclamped propulsion force";
  Real F_prop(unit="N") "friction-limited propulsion force";
  Real F_drag(unit="N") "drag load";
  Real v_ref(unit="m/s") "reference velocity";
  Real v_hat(unit="m/s") "odometry velocity estimate";
  Boolean dragActive "drag disturbance active";
  Boolean commandWithinBounds;
  Boolean actuatorStrainWithinBounds;
  Boolean actuatorWithinBounds;
  Boolean curvatureWithinBounds;
  Boolean boundsOK;
  Boolean meetsPrimary;

  // Metric variables
  Real nCyclesReal "completed cycles as Real";
  Real x_ref(unit="m") "reference displacement";
  Real progress(unit="m") "forward progress";
  Real averageSpeed(unit="m/s") "average speed";
  Real e_primary(unit="m/cycle") "primary tracking error per cycle";
  Real allRequirementsMet "combined requirement flag";

equation
  // Gait phase and phase-shifted pressure/tension control
  phi = 2.0*pi*f_g*time;
  pRear = 0.5*(1.0 + cos(phi));
  pFront = 0.5*(1.0 + cos(phi - psi));
  gaitDrive = 0.5*(1.0 + sin(phi));

  eps_ref1_raw = eps_mean + eps_amp*sin(phi);
  eps_ref2_raw = eps_mean + eps_amp*sin(phi - psi);
  eps_ref1 = max(eps_min, min(eps_max, eps_ref1_raw));
  eps_ref2 = max(eps_min, min(eps_max, eps_ref2_raw));

  // Dielectric elastomer electrical model
  C_dea = eps0*eps_r*A_mem/h;
  V_cmd_raw = V_bias + K_eps*(0.5*(eps_ref1 + eps_ref2) - eps_avg) + K_track_pos*(x_ref - x);
  V_cmd = max(0.0, min(V_max, V_cmd_raw));
  der(V_hv) = max(-slewRate, min(slewRate, (V_cmd - V_hv)/tau_slew));
  V_eff = max(0.0, min(V_max, V_hv));
  p_e = eps0*eps_r*(V_eff/h)^2;
  I_leak = G_leak*V_eff;
  I_cap = C_dea*der(V_hv);
  I_supply = I_cap + I_leak;
  P_leak = V_eff*I_leak;

  // Viscoelastic section dynamics
  eps_avg = 0.5*(eps1 + eps2);
  T_ref1 = T_pre + A_section*E_inf*eps_ref1;
  T_ref2 = T_pre + A_section*E_inf*eps_ref2;
  T1 = T_pre + A_section*(E_inf*eps1 + q1 - p_e);
  T2 = T_pre + A_section*(E_inf*eps2 + q2 - p_e);
  T_avg = 0.5*(T1 + T2);
  eps1_dot = (T_ref1 - T1)/b_mem;
  eps2_dot = (T_ref2 - T2)/b_mem;
  der(eps1) = eps1_dot;
  der(eps2) = eps2_dot;
  der(q1) = E1*eps1_dot - q1/tau_m;
  der(q2) = E1*eps2_dot - q2/tau_m;

  // Thermal state
  P_visco = abs(q1*eps1_dot*volume_section + q2*eps2_dot*volume_section);
  der(theta) = (P_leak + P_visco - (theta - thetaAmb)/R_th)/C_th;

  // Strain sensing and odometry
  der(eps1_hat) = (eps1 - eps1_hat)/0.02;
  der(eps2_hat) = (eps2 - eps2_hat)/0.02;
  v_hat = v_ref + K_odom*((eps1_hat + eps2_hat) - (eps1 + eps2));
  der(x_hat) = v_hat;

  // Curvature and bounds
  L_current = L0*(1.0 + eps_avg);
  kappa = (eps2 - eps1)/L_section;
  kappa_hat = (eps2_hat - eps1_hat)/L_section;
  commandWithinBounds = V_cmd <= V_max + 1.0e-6 and V_cmd >= -1.0e-6;
  actuatorStrainWithinBounds = eps1 <= eps_max + 1.0e-6 and eps1 >= eps_min - 1.0e-6 and
                               eps2 <= eps_max + 1.0e-6 and eps2 >= eps_min - 1.0e-6;
  actuatorWithinBounds = commandWithinBounds and actuatorStrainWithinBounds;
  curvatureWithinBounds = abs(kappa) <= kappa_max + 1.0e-6;
  boundsOK = actuatorWithinBounds and curvatureWithinBounds;

  // Rigid plane, directional friction, and two low ridges
  N_plane = m_body*g_n;
  r1 = h_ridge*h_ridge/(h_ridge*h_ridge + (x - x_ridge1)^2);
  r2 = h_ridge*h_ridge/(h_ridge*h_ridge + (x + L_current - x_ridge2)^2);
  ridgeAmp = 1.0 + k_ridge*(r1 + r2);
  mu_eff = if v >= 0.0 then mu_forward else mu_backward;
  F_limit = mu_eff*N_plane*0.5*(pFront + pRear)*ridgeAmp;

  // Body dynamics and tracking controller
  v_ref = strideRef/T_g;
  F_prop_raw = K_crawl*T_avg*gaitDrive + Kp_pos*(x_ref - x) + Kd_pos*(v_ref - v);
  F_prop = max(-F_limit, min(F_limit, F_prop_raw));
  dragActive = time >= t_drag_start and time <= t_drag_end;
  F_drag = if dragActive then F_drag_val else 0.0;
  der(x) = v;
  m_body*der(v) = F_prop - F_drag - b_ground*v;

  // Cycle metrics at 80 Hz synchronized sampling
  nCyclesReal = nCycles;
  x_ref = strideRef*nCycles;
  when sample(0, Ts) then
    if integer(floor(time/T_g)) > pre(nCycles) then
      nCycles = integer(floor(time/T_g));
      slipPerCycle = abs(strideRef - (x - pre(lastCycleX)));
      lastCycleX = x;
    else
      nCycles = pre(nCycles);
      slipPerCycle = pre(slipPerCycle);
      lastCycleX = pre(lastCycleX);
    end if;
  end when;

  progress = x;
  averageSpeed = if time > 1.0e-6 then x/time else 0.0;
  e_primary = if time >= 5.2 then abs(x - x_ref)/max(nCyclesReal, 1.0) else 0.0;
  meetsPrimary = if time >= 5.2 then e_primary <= 0.054 else true;
  allRequirementsMet = if boundsOK and meetsPrimary then 1.0 else 0.0;

  annotation(experiment(StopTime=8.0, Interval=0.0125));
end ElectroSoftCrawlA;