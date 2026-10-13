model TorqueObserverLocalizeE
  extends Modelica.Icons.Example;

  // =================== Physical parameters ===================
  parameter Real L = 0.58 "Capsule link length [m]";
  parameter Real m_link = 8.0 "Capsule link mass [kg]";
  parameter Real J_link = (1.0/3.0)*m_link*L^2 "Inertia about pivot [kg.m2]";
  parameter Real N = 70.0 "Gearbox ratio [1]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real d_joint = 0.05 "Joint viscous damping [N.m.s/rad]";
  parameter Real mgl2 = m_link*g*(L/2.0) "Gravity torque coefficient [N.m]";

  // =================== Motor drive limits ===================
  parameter Real tau_out_max = 82.5 "Output torque command limit [N.m]";
  parameter Real V_max = 48.0 "Motor voltage limit [V]";
  parameter Real I_max = 40.0 "Motor current limit [A]";
  parameter Real Kt = 0.18 "Motor torque constant [N.m/A]";
  parameter Real Ke = 0.18 "Back-EMF constant [V.s/rad]";
  parameter Real R_m = 0.6 "Motor resistance [Ohm]";

  // =================== Controller / route ===================
  parameter Real Kp_track = 80.0 "Position gain [N.m/rad]";
  parameter Real Kd_track = 8.0 "Velocity gain [N.m.s/rad]";
  parameter Real tau_filt = 0.02 "Measurement filter time constant [s]";
  parameter Real q_ref_amp = 0.6 "Route amplitude [rad]";
  parameter Real q_ref_freq = 0.1 "Route frequency [Hz]";

  // =================== Sensor rates, std devs, frames ===================
  parameter Real f_base = 250.0 "Base / estimator rate [Hz]";
  parameter Real dt_base = 1.0/f_base "Base period [s]";
  parameter Real f_enc = 250.0 "Joint encoder rate [Hz]";
  parameter Real f_cur = 125.0 "Motor current rate [Hz]";
  parameter Real f_lm = 25.0 "Landmark bearing rate [Hz]";
  parameter Real sigma_enc = 0.002 "Encoder std dev [rad], frame: joint";
  parameter Real sigma_cur = 0.05 "Current std dev [A], frame: motor";
  parameter Real sigma_lm = 0.02 "Landmark bearing std dev [rad], frame: world";

  // =================== Bias disturbance (middle third) ===================
  parameter Real bias_step = 0.048 "Sensor-bias step magnitude [rad]";
  parameter Real t_on = 16.0/3.0 "Middle-third disturbance start [s]";
  parameter Real t_off = 2.0*16.0/3.0 "Middle-third disturbance end [s]";
  parameter Real tau_rise = 0.02 "Smooth step rise time [s]";

  // =================== Fixed landmarks (external references) ===================
  parameter Real lm1_x = 1.0 "Landmark 1 x [m], world frame";
  parameter Real lm1_y = 0.5 "Landmark 1 y [m], world frame";
  parameter Real lm2_x = -0.8 "Landmark 2 x [m], world frame";
  parameter Real lm2_y = 1.0 "Landmark 2 y [m], world frame";

  // =================== EKF noise ===================
  parameter Real q_q = 1e-5 "Process noise (angle) [rad2]";
  parameter Real q_w = 1e-3 "Process noise (rate) [(rad/s)2]";
  parameter Real q_be = 1e-5 "Process noise (encoder bias) [rad2]";
  parameter Real q_bc = 1e-6 "Process noise (current bias) [A2]";
  parameter Real q_bl = 1e-6 "Process noise (landmark bias) [rad2]";
  parameter Real R_enc = sigma_enc^2 "Encoder meas variance";
  parameter Real R_cur = sigma_cur^2 "Current meas variance";
  parameter Real R_lm = sigma_lm^2 "Landmark meas variance";
  parameter Real Qdiag[5] = {q_q, q_w, q_be, q_bc, q_bl};

  // =================== Acceptance ===================
  parameter Real t_final = 16.0 "Final time [s]";
  parameter Real t_check = 10.4 "Tracking-error check time [s]";
  parameter Real t_settle = 12.0 "Bias settle time [s]";
  parameter Real track_limit = 0.18 "Primary tracking limit [m-or-rad]";
  parameter Real pos_band = 0.05 "Position error band [m]";
  parameter Real att_band = 0.05 "Attitude error band [rad]";
  parameter Real bias_tol = 0.02 "Bias convergence tolerance [rad]";
  parameter Real eps_r2 = 1e-6 "Range-squared guard [m2]";

  // =================== Plant state ===================
  output Real q(start=0.0, fixed=true) "Joint angle [rad]";
  output Real w(start=0.0, fixed=true) "Joint angular velocity [rad/s]";
  output Real x_tip "Tip x position [m]";
  output Real y_tip "Tip y position [m]";
  Real q_ref "Reference angle [rad]";
  Real q_ref_dot "Reference angular velocity [rad/s]";
  Real x_tip_ref "Reference tip x [m]";
  Real y_tip_ref "Reference tip y [m]";

  // =================== Controller / motor ===================
  Real q_meas "Continuous encoder measurement signal [rad]";
  Real q_filt(start=0.0) "Filtered position [rad]";
  Real w_filt "Filtered velocity estimate [rad/s]";
  Real tau_des "Desired output torque pre-saturation [N.m]";
  output Real tau_out_cmd "Commanded output torque (bounded by 82.5) [N.m]";
  Real Vcmd_unsat "Unsaturated voltage command [V]";
  output Real Vcmd "Saturated motor voltage [V]";
  Real i_unsat "Unsaturated motor current [A]";
  output Real i_motor "Saturated motor current [A]";
  Real tau_m "Motor torque [N.m]";
  output Real tau_out "Actual output torque (post gearbox + limits) [N.m]";

  // =================== True sensor biases ===================
  Real b_enc_true "True encoder bias [rad]";
  Real b_cur_true "True current bias [A]";
  Real b_lm_true "True landmark bias [rad]";

  // =================== Continuous deterministic noise ===================
  Real n_enc, n_cur, n_lm1, n_lm2;

  // =================== Sampled measurements + timestamps ===================
  output Real z_enc "Sampled encoder reading [rad]";
  output Real z_cur "Sampled current reading [A]";
  output Real z_lm1 "Sampled landmark 1 bearing [rad]";
  output Real z_lm2 "Sampled landmark 2 bearing [rad]";
  output Real t_enc "Encoder timestamp [s]";
  output Real t_cur "Current timestamp [s]";
  output Real t_lm1 "Landmark 1 timestamp [s]";
  output Real t_lm2 "Landmark 2 timestamp [s]";
  Integer tick(start=0) "Master tick counter";

  // =================== Estimator state ===================
  Real x_hat[5] "Estimator state [q, w, b_enc, b_cur, b_lm]";
  Real P_hat[5,5] "Estimator covariance";
  output Real q_hat, w_hat, benc_hat, bcur_hat, blm_hat;
  output Real x_tip_hat, y_tip_hat;

  // Estimator temporaries (discrete)
  Real a_p, Ca, Cw;
  Real xr[5], Pr[5,5], Ptmp[5,5];
  Real F[5,5];
  Real y_e, S_e, K_e[5], HP_e[5];
  Real y_c, S_c, K_c[5], HP_c[5];
  Real y_l1, S_l1, K_l1[5], HP_l1[5];
  Real y_l2, S_l2, K_l2[5], HP_l2[5];
  Real hcur, hb1, hb2, dx1, dy1, r21, dx2, dy2, r22, i_est;
  Boolean do_cur, do_lm;

  // =================== Acceptance ===================
  output Real track_err_tip "Primary tip tracking error [m]";
  output Real pos_err "Position estimation error [m]";
  output Real att_err "Attitude estimation error [rad]";
  output Real bias_err "Encoder bias estimation error [rad]";
  output Real cov_min "Minimum covariance diagonal";
  Real cov_diag[5];
  Boolean actuator_ok, finite_ok;
  Boolean fail_track(start=false), fail_pose(start=false), fail_bias(start=false);
  Boolean fail_cov(start=false), fail_act(start=false), fail_fin(start=false);
  output Boolean accept;
  output Boolean passed "Fail-closed overall acceptance flag";

protected
  function fin "Finite-value check (rejects NaN and infinities)"
    input Real x;
    output Boolean y;
  algorithm
    y := (x >= -1e30) and (x <= 1e30);
  end fin;

initial equation
  x_hat = {0.02, 0.0, 0.0, 0.0, 0.0};
  P_hat[1,1] = 0.01;
  P_hat[2,2] = 0.01;
  P_hat[3,3] = 1e-3;
  P_hat[4,4] = 1e-4;
  P_hat[5,5] = 1e-4;

equation
  // ===== Plant kinematics / dynamics =====
  x_tip = L*Modelica.Math.sin(q);
  y_tip = L*Modelica.Math.cos(q);
  der(q) = w;
  der(w) = (tau_out - mgl2*Modelica.Math.sin(q) - d_joint*w)/J_link;

  // ===== Reference route =====
  q_ref = q_ref_amp*Modelica.Math.sin(2*Modelica.Constants.pi*q_ref_freq*time);
  q_ref_dot = q_ref_amp*2*Modelica.Constants.pi*q_ref_freq*Modelica.Math.cos(2*Modelica.Constants.pi*q_ref_freq*time);
  x_tip_ref = L*Modelica.Math.sin(q_ref);
  y_tip_ref = L*Modelica.Math.cos(q_ref);

  // ===== True sensor bias (smooth middle-third step) =====
  b_enc_true = bias_step*0.5*(Modelica.Math.tanh((time - t_on)/tau_rise) - Modelica.Math.tanh((time - t_off)/tau_rise));
  b_cur_true = 0.0;
  b_lm_true = 0.0;

  // ===== Continuous deterministic noise (bounded, zero-mean-ish) =====
  n_enc = sigma_enc*Modelica.Math.sin(2*Modelica.Constants.pi*13.7*time + 0.3);
  n_cur = sigma_cur*Modelica.Math.sin(2*Modelica.Constants.pi*27.3*time + 1.1);
  n_lm1 = sigma_lm*Modelica.Math.sin(2*Modelica.Constants.pi*7.9*time + 2.2);
  n_lm2 = sigma_lm*Modelica.Math.sin(2*Modelica.Constants.pi*11.3*time + 0.7);

  // ===== Continuous measurement signal (controller side) =====
  q_meas = q + b_enc_true + n_enc;

  // ===== Controller filter =====
  der(q_filt) = (q_meas - q_filt)/tau_filt;
  w_filt = (q_meas - q_filt)/tau_filt;

  // ===== Controller + motor drive with voltage / current / torque limits =====
  tau_des = Kp_track*(q_ref - q_meas) + Kd_track*(q_ref_dot - w_filt);
  tau_out_cmd = if tau_des > tau_out_max then tau_out_max
                else if tau_des < -tau_out_max then -tau_out_max else tau_des;
  Vcmd_unsat = R_m*(tau_out_cmd/N)/Kt + Ke*N*w;
  Vcmd = if Vcmd_unsat > V_max then V_max
         else if Vcmd_unsat < -V_max then -V_max else Vcmd_unsat;
  i_unsat = (Vcmd - Ke*N*w)/R_m;
  i_motor = if i_unsat > I_max then I_max
            else if i_unsat < -I_max then -I_max else i_unsat;
  tau_m = Kt*i_motor;
  tau_out = if N*tau_m > tau_out_max then tau_out_max
            else if N*tau_m < -tau_out_max then -tau_out_max else N*tau_m;

  // ===== Estimator derived outputs =====
  q_hat = x_hat[1];
  w_hat = x_hat[2];
  benc_hat = x_hat[3];
  bcur_hat = x_hat[4];
  blm_hat = x_hat[5];
  x_tip_hat = L*Modelica.Math.sin(q_hat);
  y_tip_hat = L*Modelica.Math.cos(q_hat);

  // ===== Acceptance quantities =====
  track_err_tip = Modelica.Math.sqrt(Modelica.Math.max((x_tip - x_tip_ref)^2 + (y_tip - y_tip_ref)^2, 0.0));
  pos_err = Modelica.Math.sqrt(Modelica.Math.max((x_tip - x_tip_hat)^2 + (y_tip - y_tip_hat)^2, 0.0));
  att_err = abs(q - q_hat);
  bias_err = abs(b_enc_true - benc_hat);
  cov_diag = {P_hat[1,1], P_hat[2,2], P_hat[3,3], P_hat[4,4], P_hat[5,5]};
  cov_min = min(cov_diag);
  actuator_ok = (abs(tau_out) <= tau_out_max*1.001) and (abs(Vcmd) <= V_max*1.001) and (abs(i_motor) <= I_max*1.001);
  finite_ok = fin(q) and fin(w) and fin(q_hat) and fin(w_hat) and fin(benc_hat) and fin(tau_out) and fin(Vcmd) and fin(i_motor) and fin(P_hat[1,1]) and fin(P_hat[5,5]) and fin(track_err_tip);
  accept = (time >= t_check) and (not fail_track) and (not fail_pose) and (not fail_bias) and (not fail_cov) and (not fail_act) and (not fail_fin);
  passed = accept and (time >= t_final - dt_base);

  // ===== Master asynchronous estimator + sensor sampling =====
  when sample(0, dt_base) then
    tick := tick + 1;
    do_cur := mod(tick,2) == 1;
    do_lm := mod(tick,10) == 0;

    // ---------- Predict ----------
    a_p := (tau_out_cmd - mgl2*Modelica.Math.sin(x_hat[1]) - d_joint*x_hat[2])/J_link;
    Ca := -mgl2*Modelica.Math.cos(x_hat[1])/J_link;
    Cw := -d_joint/J_link;
    for i in 1:5 loop for j in 1:5 loop F[i,j] := 0.0; end for; end for;
    for i in 1:5 loop F[i,i] := 1.0; end for;
    F[1,2] := dt_base;
    F[2,1] := Ca*dt_base;
    F[2,2] := 1.0 + Cw*dt_base;

    xr[1] := x_hat[1] + x_hat[2]*dt_base + 0.5*a_p*dt_base*dt_base;
    xr[2] := x_hat[2] + a_p*dt_base;
    xr[3] := x_hat[3];
    xr[4] := x_hat[4];
    xr[5] := x_hat[5];

    for i in 1:5 loop for j in 1:5 loop
      Ptmp[i,j] := 0.0;
      for k in 1:5 loop Ptmp[i,j] := Ptmp[i,j] + F[i,k]*P_hat[k,j]; end for;
    end for; end for;
    for i in 1:5 loop for j in 1:5 loop
      Pr[i,j] := 0.0;
      for k in 1:5 loop Pr[i,j] := Pr[i,j] + Ptmp[i,k]*F[j,k]; end for;
      if i == j then Pr[i,j] := Pr[i,j] + Qdiag[i]; end if;
    end for; end for;

    // ---------- Encoder update (250 Hz, frame: joint) ----------
    z_enc := q + b_enc_true + n_enc;
    t_enc := time;
    y_e := z_enc - (xr[1] + xr[3]);
    S_e := Pr[1,1] + Pr[1,3] + Pr[3,1] + Pr[3,3] + R_enc + 1e-12;
    for i in 1:5 loop K_e[i] := (Pr[i,1] + Pr[i,3])/S_e; end for;
    for j in 1:5 loop HP_e[j] := Pr[1,j] + Pr[3,j]; end for;
    for i in 1:5 loop xr[i] := xr[i] + K_e[i]*y_e; end for;
    for i in 1:5 loop for j in 1:5 loop Pr[i,j] := Pr[i,j] - K_e[i]*HP_e[j]; end for; end for;

    // ---------- Current update (125 Hz, asynchronous, frame: motor) ----------
    if do_cur then
      z_cur := i_motor + b_cur_true + n_cur;
      t_cur := time;
      hcur := -Ke*N/R_m;
      i_est := (Vcmd - Ke*N*xr[2])/R_m;
      y_c := z_cur - (i_est + xr[4]);
      S_c := hcur*hcur*Pr[2,2] + hcur*Pr[2,4] + hcur*Pr[4,2] + Pr[4,4] + R_cur + 1e-12;
      for i in 1:5 loop K_c[i] := (hcur*Pr[i,2] + Pr[i,4])/S_c; end for;
      for j in 1:5 loop HP_c[j] := hcur*Pr[2,j] + Pr[4,j]; end for;
      for i in 1:5 loop xr[i] := xr[i] + K_c[i]*y_c; end for;
      for i in 1:5 loop for j in 1:5 loop Pr[i,j] := Pr[i,j] - K_c[i]*HP_c[j]; end for; end for;
    end if;

    // ---------- Landmark updates (25 Hz, asynchronous, frame: world) ----------
    if do_lm then
      z_lm1 := Modelica.Math.atan2(lm1_y - y_tip, lm1_x - x_tip) - q + b_lm_true + n_lm1;
      z_lm2 := Modelica.Math.atan2(lm2_y - y_tip, lm2_x - x_tip) - q + b_lm_true + n_lm2;
      t_lm1 := time;
      t_lm2 := time;

      // Landmark 1
      dx1 := lm1_x - L*Modelica.Math.sin(xr[1]);
      dy1 := lm1_y - L*Modelica.Math.cos(xr[1]);
      r21 := dx1*dx1 + dy1*dy1 + eps_r2;
      hb1 := L*(dx1*Modelica.Math.sin(xr[1]) + dy1*Modelica.Math.cos(xr[1]))/r21 - 1.0;
      y_l1 := z_lm1 - (Modelica.Math.atan2(dy1,dx1) - xr[1] + xr[5]);
      S_l1 := hb1*hb1*Pr[1,1] + hb1*Pr[1,5] + hb1*Pr[5,1] + Pr[5,5] + R_lm + 1e-12;
      for i in 1:5 loop K_l1[i] := (hb1*Pr[i,1] + Pr[i,5])/S_l1; end for;
      for j in 1:5 loop HP_l1[j] := hb1*Pr[1,j] + Pr[5,j]; end for;
      for i in 1:5 loop xr[i] := xr[i] + K_l1[i]*y_l1; end for;
      for i in 1:5 loop for j in 1:5 loop Pr[i,j] := Pr[i,j] - K_l1[i]*HP_l1[j]; end for; end for;

      // Landmark 2
      dx2 := lm2_x - L*Modelica.Math.sin(xr[1]);
      dy2 := lm2_y - L*Modelica.Math.cos(xr[1]);
      r22 := dx2*dx2 + dy2*dy2 + eps_r2;
      hb2 := L*(dx2*Modelica.Math.sin(xr[1]) + dy2*Modelica.Math.cos(xr[1]))/r22 - 1.0;
      y_l2 := z_lm2 - (Modelica.Math.atan2(dy2,dx2) - xr[1] + xr[5]);
      S_l2 := hb2*hb2*Pr[1,1] + hb2*Pr[1,5] + hb2*Pr[5,1] + Pr[5,5] + R_lm + 1e-12;
      for i in 1:5 loop K_l2[i] := (hb2*Pr[i,1] + Pr[i,5])/S_l2; end for;
      for j in 1:5 loop HP_l2[j] := hb2*Pr[1,j] + Pr[5,j]; end for;
      for i in 1:5 loop xr[i] := xr[i] + K_l2[i]*y_l2; end for;
      for i in 1:5 loop for j in 1:5 loop Pr[i,j] := Pr[i,j] - K_l2[i]*HP_l2[j]; end for; end for;
    end if;

    // ---------- Commit estimator state ----------
    for i in 1:5 loop x_hat[i] := xr[i]; end for;
    for i in 1:5 loop for j in 1:5 loop P_hat[i,j] := Pr[i,j]; end for; end for;

    // ---------- Fail-closed acceptance latches ----------
    if time >= t_check and track_err_tip > track_limit then
      fail_track := true;
    end if;
    if time >= t_check and (pos_err > pos_band or att_err > att_band) then
      fail_pose := true;
    end if;
    if time >= t_settle and bias_err > bias_tol then
      fail_bias := true;
    end if;
    if (cov_min <= 1e-12) or (cov_min >= 1e6) or (not fin(Pr[1,1])) or (not fin(Pr[5,5])) then
      fail_cov := true;
    end if;
    if not actuator_ok then
      fail_act := true;
    end if;
    if not finite_ok then
      fail_fin := true;
    end if;
  end when;

  annotation (
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="TorqueObserverLocalizeE: 0.58 m / 8 kg capsule link, 70:1 gearbox, voltage/current/torque(82.5 N.m)-limited drive, joint encoder + motor current + world-frame landmark bearing sensors, asynchronous EKF estimating pose, velocity, and sensor biases under a 0.048 middle-third bias step. Runs at 250 Hz for 16 s with fail-closed acceptance."));
end TorqueObserverLocalizeE;