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
  parameter Real Qdiag1 = q_q;
  parameter Real Qdiag2 = q_w;
  parameter Real Qdiag3 = q_be;
  parameter Real Qdiag4 = q_bc;
  parameter Real Qdiag5 = q_bl;

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
  discrete Real z_enc(start=0.0) "Sampled encoder reading [rad]";
  discrete Real z_cur(start=0.0) "Sampled current reading [A]";
  discrete Real z_lm1(start=0.0) "Sampled landmark 1 bearing [rad]";
  discrete Real z_lm2(start=0.0) "Sampled landmark 2 bearing [rad]";
  discrete Real t_enc(start=0.0) "Encoder timestamp [s]";
  discrete Real t_cur(start=0.0) "Current timestamp [s]";
  discrete Real t_lm1(start=0.0) "Landmark 1 timestamp [s]";
  discrete Real t_lm2(start=0.0) "Landmark 2 timestamp [s]";
  discrete Integer tick(start=0) "Master tick counter";

  // =================== Estimator state ===================
  discrete Real x_hat1(start=0.02) "Estimator angle [rad]";
  discrete Real x_hat2(start=0.0) "Estimator rate [rad/s]";
  discrete Real x_hat3(start=0.0) "Estimator encoder bias [rad]";
  discrete Real x_hat4(start=0.0) "Estimator current bias [A]";
  discrete Real x_hat5(start=0.0) "Estimator landmark bias [rad]";
  discrete Real P11(start=0.01), P12(start=0.0), P13(start=0.0), P14(start=0.0), P15(start=0.0);
  discrete Real P21(start=0.0), P22(start=0.01), P23(start=0.0), P24(start=0.0), P25(start=0.0);
  discrete Real P31(start=0.0), P32(start=0.0), P33(start=1e-3), P34(start=0.0), P35(start=0.0);
  discrete Real P41(start=0.0), P42(start=0.0), P43(start=0.0), P44(start=1e-4), P45(start=0.0);
  discrete Real P51(start=0.0), P52(start=0.0), P53(start=0.0), P54(start=0.0), P55(start=1e-4);
  output Real q_hat, w_hat, benc_hat, bcur_hat, blm_hat;
  output Real x_tip_hat, y_tip_hat;

  // Estimator temporaries (discrete)
  discrete Real a_p, Ca, Cw;
  discrete Real xr1, xr2, xr3, xr4, xr5;
  discrete Real Pr11, Pr12, Pr13, Pr14, Pr15;
  discrete Real Pr21, Pr22, Pr23, Pr24, Pr25;
  discrete Real Pr31, Pr32, Pr33, Pr34, Pr35;
  discrete Real Pr41, Pr42, Pr43, Pr44, Pr45;
  discrete Real Pr51, Pr52, Pr53, Pr54, Pr55;
  discrete Real Ptmp_ij;
  discrete Real F11, F12, F13, F14, F15;
  discrete Real F21, F22, F23, F24, F25;
  discrete Real F31, F32, F33, F34, F35;
  discrete Real F41, F42, F43, F44, F45;
  discrete Real F51, F52, F53, F54, F55;
  discrete Real y_e, S_e, K_e1, K_e2, K_e3, K_e4, K_e5;
  discrete Real HP_e1, HP_e2, HP_e3, HP_e4, HP_e5;
  discrete Real y_c, S_c, K_c1, K_c2, K_c3, K_c4, K_c5;
  discrete Real HP_c1, HP_c2, HP_c3, HP_c4, HP_c5;
  discrete Real y_l1, S_l1, K_l1_1, K_l1_2, K_l1_3, K_l1_4, K_l1_5;
  discrete Real HP_l1_1, HP_l1_2, HP_l1_3, HP_l1_4, HP_l1_5;
  discrete Real y_l2, S_l2, K_l2_1, K_l2_2, K_l2_3, K_l2_4, K_l2_5;
  discrete Real HP_l2_1, HP_l2_2, HP_l2_3, HP_l2_4, HP_l2_5;
  discrete Real hcur, hb1, hb2, dx1, dy1, r21, dx2, dy2, r22, i_est;
  discrete Boolean do_cur, do_lm;

  // =================== Acceptance ===================
  output Real track_err_tip "Primary tip tracking error [m]";
  output Real pos_err "Position estimation error [m]";
  output Real att_err "Attitude estimation error [rad]";
  output Real bias_err "Encoder bias estimation error [rad]";
  output Real cov_min "Minimum covariance diagonal";
  Boolean actuator_ok, finite_ok;
  discrete Boolean fail_track(start=false), fail_pose(start=false), fail_bias(start=false);
  discrete Boolean fail_cov(start=false), fail_act(start=false), fail_fin(start=false);
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
  x_hat1 = 0.02;
  x_hat2 = 0.0;
  x_hat3 = 0.0;
  x_hat4 = 0.0;
  x_hat5 = 0.0;
  P11 = 0.01; P12 = 0.0; P13 = 0.0; P14 = 0.0; P15 = 0.0;
  P21 = 0.0; P22 = 0.01; P23 = 0.0; P24 = 0.0; P25 = 0.0;
  P31 = 0.0; P32 = 0.0; P33 = 1e-3; P34 = 0.0; P35 = 0.0;
  P41 = 0.0; P42 = 0.0; P43 = 0.0; P44 = 1e-4; P45 = 0.0;
  P51 = 0.0; P52 = 0.0; P53 = 0.0; P54 = 0.0; P55 = 1e-4;

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
  q_hat = x_hat1;
  w_hat = x_hat2;
  benc_hat = x_hat3;
  bcur_hat = x_hat4;
  blm_hat = x_hat5;
  x_tip_hat = L*Modelica.Math.sin(q_hat);
  y_tip_hat = L*Modelica.Math.cos(q_hat);

  // ===== Acceptance quantities =====
  track_err_tip = Modelica.Math.sqrt(max((x_tip - x_tip_ref)^2 + (y_tip - y_tip_ref)^2, 0.0));
  pos_err = Modelica.Math.sqrt(max((x_tip - x_tip_hat)^2 + (y_tip - y_tip_hat)^2, 0.0));
  att_err = abs(q - q_hat);
  bias_err = abs(b_enc_true - benc_hat);
  cov_min = if P11 <= P22 and P11 <= P33 and P11 <= P44 and P11 <= P55 then P11
            else if P22 <= P33 and P22 <= P44 and P22 <= P55 then P22
            else if P33 <= P44 and P33 <= P55 then P33
            else if P44 <= P55 then P44
            else P55;
  actuator_ok = (abs(tau_out) <= tau_out_max*1.001) and (abs(Vcmd) <= V_max*1.001) and (abs(i_motor) <= I_max*1.001);
  finite_ok = fin(q) and fin(w) and fin(q_hat) and fin(w_hat) and fin(benc_hat) and fin(tau_out) and fin(Vcmd) and fin(i_motor) and fin(P11) and fin(P55) and fin(track_err_tip);
  accept = (time >= t_check) and (not fail_track) and (not fail_pose) and (not fail_bias) and (not fail_cov) and (not fail_act) and (not fail_fin);
  passed = accept and (time >= t_final - dt_base);

algorithm
  // ===== Master asynchronous estimator + sensor sampling =====
  when sample(0, dt_base) then
    tick := pre(tick) + 1;
    do_cur := mod(tick,2) == 1;
    do_lm := mod(tick,10) == 0;

    // ---------- Predict ----------
    a_p := (tau_out_cmd - mgl2*Modelica.Math.sin(pre(x_hat1)) - d_joint*pre(x_hat2))/J_link;
    Ca := -mgl2*Modelica.Math.cos(pre(x_hat1))/J_link;
    Cw := -d_joint/J_link;
    F11 := 1.0; F12 := dt_base; F13 := 0.0; F14 := 0.0; F15 := 0.0;
    F21 := Ca*dt_base; F22 := 1.0 + Cw*dt_base; F23 := 0.0; F24 := 0.0; F25 := 0.0;
    F31 := 0.0; F32 := 0.0; F33 := 1.0; F34 := 0.0; F35 := 0.0;
    F41 := 0.0; F42 := 0.0; F43 := 0.0; F44 := 1.0; F45 := 0.0;
    F51 := 0.0; F52 := 0.0; F53 := 0.0; F54 := 0.0; F55 := 1.0;

    xr1 := pre(x_hat1) + pre(x_hat2)*dt_base + 0.5*a_p*dt_base*dt_base;
    xr2 := pre(x_hat2) + a_p*dt_base;
    xr3 := pre(x_hat3);
    xr4 := pre(x_hat4);
    xr5 := pre(x_hat5);

    // Ptmp = F * pre(P)
    Pr11 := F11*pre(P11) + F12*pre(P21) + F13*pre(P31) + F14*pre(P41) + F15*pre(P51);
    Pr12 := F11*pre(P12) + F12*pre(P22) + F13*pre(P32) + F14*pre(P42) + F15*pre(P52);
    Pr13 := F11*pre(P13) + F12*pre(P23) + F13*pre(P33) + F14*pre(P43) + F15*pre(P53);
    Pr14 := F11*pre(P14) + F12*pre(P24) + F13*pre(P34) + F14*pre(P44) + F15*pre(P54);
    Pr15 := F11*pre(P15) + F12*pre(P25) + F13*pre(P35) + F14*pre(P45) + F15*pre(P55);
    Pr21 := F21*pre(P11) + F22*pre(P21) + F23*pre(P31) + F24*pre(P41) + F25*pre(P51);
    Pr22 := F21*pre(P12) + F22*pre(P22) + F23*pre(P32) + F24*pre(P42) + F25*pre(P52);
    Pr23 := F21*pre(P13) + F22*pre(P23) + F23*pre(P33) + F24*pre(P43) + F25*pre(P53);
    Pr24 := F21*pre(P14) + F22*pre(P24) + F23*pre(P34) + F24*pre(P44) + F25*pre(P54);
    Pr25 := F21*pre(P15) + F22*pre(P25) + F23*pre(P35) + F24*pre(P45) + F25*pre(P55);
    Pr31 := pre(P31);
    Pr32 := pre(P32);
    Pr33 := pre(P33);
    Pr34 := pre(P34);
    Pr35 := pre(P35);
    Pr41 := pre(P41);
    Pr42 := pre(P42);
    Pr43 := pre(P43);
    Pr44 := pre(P44);
    Pr45 := pre(P45);
    Pr51 := pre(P51);
    Pr52 := pre(P52);
    Pr53 := pre(P53);
    Pr54 := pre(P54);
    Pr55 := pre(P55);

    // Pr = Ptmp * F^T + Q
    Ptmp_ij := Pr11;
    Pr11 := Ptmp_ij*F11 + Pr12*F12 + Pr13*F13 + Pr14*F14 + Pr15*F15 + Qdiag1;
    Ptmp_ij := Pr11;
    Pr12 := Pr11*F12 + Pr12*F22 + Pr13*F32 + Pr14*F42 + Pr15*F52;
    Pr13 := Pr11*F13 + Pr12*F23 + Pr13*F33 + Pr14*F43 + Pr15*F53;
    Pr14 := Pr11*F14 + Pr12*F24 + Pr13*F34 + Pr14*F44 + Pr15*F54;
    Pr15 := Pr11*F15 + Pr12*F25 + Pr13*F35 + Pr14*F45 + Pr15*F55;

    // This manual covariance propagation is complex; use simpler approach below
    // Revert to direct: Pr = F*P*F^T + Q computed element-wise from pre(P)
    Pr11 := F11*pre(P11)*F11 + F11*pre(P12)*F21 + F11*pre(P13)*F31 + F11*pre(P14)*F41 + F11*pre(P15)*F51
          + F12*pre(P21)*F11 + F12*pre(P22)*F21 + F12*pre(P23)*F31 + F12*pre(P24)*F41 + F12*pre(P25)*F51
          + F13*pre(P31)*F11 + F13*pre(P32)*F21 + F13*pre(P33)*F31 + F13*pre(P34)*F41 + F13*pre(P35)*F51
          + F14*pre(P41)*F11 + F14*pre(P42)*F21 + F14*pre(P43)*F31 + F14*pre(P44)*F41 + F14*pre(P45)*F51
          + F15*pre(P51)*F11 + F15*pre(P52)*F21 + F15*pre(P53)*F31 + F15*pre(P54)*F41 + F15*pre(P55)*F51
          + Qdiag1;
    Pr12 := F11*pre(P11)*F12 + F11*pre(P12)*F22 + F11*pre(P13)*F32 + F11*pre(P14)*F42 + F11*pre(P15)*F52
          + F12*pre(P21)*F12 + F12*pre(P22)*F22 + F12*pre(P23)*F32 + F12*pre(P24)*F42 + F12*pre(P25)*F52
          + F13*pre(P31)*F12 + F13*pre(P32)*F22 + F13*pre(P33)*F32 + F13*pre(P34)*F42 + F13*pre(P35)*F52
          + F14*pre(P41)*F12 + F14*pre(P42)*F22 + F14*pre(P43)*F32 + F14*pre(P44)*F42 + F14*pre(P45)*F52
          + F15*pre(P51)*F12 + F15*pre(P52)*F22 + F15*pre(P53)*F32 + F15*pre(P54)*F42 + F15*pre(P55)*F52;
    Pr13 := F13*pre(P33) + F12*pre(P23) + F11*pre(P13);
    Pr14 := F14*pre(P44) + F12*pre(P24) + F11*pre(P14);
    Pr15 := F15*pre(P55) + F12*pre(P25) + F11*pre(P15);
    Pr21 := F21*pre(P11)*F11 + F21*pre(P12)*F21 + F21*pre(P13)*F31 + F21*pre(P14)*F41 + F21*pre(P15)*F51
          + F22*pre(P21)*F11 + F22*pre(P22)*F21 + F22*pre(P23)*F31 + F22*pre(P24)*F41 + F22*pre(P25)*F51
          + F23*pre(P31)*F11 + F23*pre(P32)*F21 + F23*pre(P33)*F31 + F23*pre(P34)*F41 + F23*pre(P35)*F51
          + F24*pre(P41)*F11 + F24*pre(P42)*F21 + F24*pre(P43)*F31 + F24*pre(P44)*F41 + F24*pre(P45)*F51
          + F25*pre(P51)*F11 + F25*pre(P52)*F21 + F25*pre(P53)*F31 + F25*pre(P54)*F41 + F25*pre(P55)*F51;
    Pr22 := F21*pre(P11)*F12 + F21*pre(P12)*F22 + F21*pre(P13)*F32 + F21*pre(P14)*F42 + F21*pre(P15)*F52
          + F22*pre(P21)*F12 + F22*pre(P22)*F22 + F22*pre(P23)*F32 + F22*pre(P24)*F42 + F22*pre(P25)*F52
          + F23*pre(P31)*F12 + F23*pre(P32)*F22 + F23*pre(P33)*F32 + F23*pre(P34)*F42 + F23*pre(P35)*F52
          + F24*pre(P41)*F12 + F24*pre(P42)*F22 + F24*pre(P43)*F32 + F24*pre(P44)*F42 + F24*pre(P45)*F52
          + F25*pre(P51)*F12 + F25*pre(P52)*F22 + F25*pre(P53)*F32 + F25*pre(P54)*F42 + F25*pre(P55)*F52
          + Qdiag2;
    Pr23 := F23*pre(P33) + F22*pre(P23) + F21*pre(P13);
    Pr24 := F24*pre(P44) + F22*pre(P24) + F21*pre(P14);
    Pr25 := F25*pre(P55) + F22*pre(P25) + F21*pre(P15);
    Pr31 := pre(P31)*F11 + pre(P32)*F21 + pre(P33)*F31 + pre(P34)*F41 + pre(P35)*F51;
    Pr32 := pre(P31)*F12 + pre(P32)*F22 + pre(P33)*F32 + pre(P34)*F42 + pre(P35)*F52;
    Pr33 := pre(P33) + Qdiag3;
    Pr34 := pre(P34);
    Pr35 := pre(P35);
    Pr41 := pre(P41)*F11 + pre(P42)*F21 + pre(P43)*F31 + pre(P44)*F41 + pre(P45)*F51;
    Pr42 := pre(P41)*F12 + pre(P42)*F22 + pre(P43)*F32 + pre(P44)*F42 + pre(P45)*F52;
    Pr43 := pre(P43);
    Pr44 := pre(P44) + Qdiag4;
    Pr45 := pre(P45);
    Pr51 := pre(P51)*F11 + pre(P52)*F21 + pre(P53)*F31 + pre(P54)*F41 + pre(P55)*F51;
    Pr52 := pre(P51)*F12 + pre(P52)*F22 + pre(P53)*F32 + pre(P54)*F42 + pre(P55)*F52;
    Pr53 := pre(P53);
    Pr54 := pre(P54);
    Pr55 := pre(P55) + Qdiag5;

    // ---------- Encoder update (250 Hz, frame: joint) ----------
    z_enc := q + b_enc_true + n_enc;
    t_enc := time;
    y_e := z_enc - (xr1 + xr3);
    S_e := Pr11 + Pr13 + Pr31 + Pr33 + R_enc + 1e-12;
    K_e1 := (Pr11 + Pr13)/S_e;
    K_e2 := (Pr21 + Pr23)/S_e;
    K_e3 := (Pr31 + Pr33)/S_e;
    K_e4 := (Pr41 + Pr43)/S_e;
    K_e5 := (Pr51 + Pr53)/S_e;
    HP_e1 := Pr11 + Pr31;
    HP_e2 := Pr12 + Pr32;
    HP_e3 := Pr13 + Pr33;
    HP_e4 := Pr14 + Pr34;
    HP_e5 := Pr15 + Pr35;
    xr1 := xr1 + K_e1*y_e;
    xr2 := xr2 + K_e2*y_e;
    xr3 := xr3 + K_e3*y_e;
    xr4 := xr4 + K_e4*y_e;
    xr5 := xr5 + K_e5*y_e;
    Pr11 := Pr11 - K_e1*HP_e1;
    Pr12 := Pr12 - K_e1*HP_e2;
    Pr13 := Pr13 - K_e1*HP_e3;
    Pr14 := Pr14 - K_e1*HP_e4;
    Pr15 := Pr15 - K_e1*HP_e5;
    Pr21 := Pr21 - K_e2*HP_e1;
    Pr22 := Pr22 - K_e2*HP_e2;
    Pr23 := Pr23 - K_e2*HP_e3;
    Pr24 := Pr24 - K_e2*HP_e4;
    Pr25 := Pr25 - K_e2*HP_e5;
    Pr31 := Pr31 - K_e3*HP_e1;
    Pr32 := Pr32 - K_e3*HP_e2;
    Pr33 := Pr33 - K_e3*HP_e3;
    Pr34 := Pr34 - K_e3*HP_e4;
    Pr35 := Pr35 - K_e3*HP_e5;
    Pr41 := Pr41 - K_e4*HP_e1;
    Pr42 := Pr42 - K_e4*HP_e2;
    Pr43 := Pr43 - K_e4*HP_e3;
    Pr44 := Pr44 - K_e4*HP_e4;
    Pr45 := Pr45 - K_e4*HP_e5;
    Pr51 := Pr51 - K_e5*HP_e1;
    Pr52 := Pr52 - K_e5*HP_e2;
    Pr53 := Pr53 - K_e5*HP_e3;
    Pr54 := Pr54 - K_e5*HP_e4;
    Pr55 := Pr55 - K_e5*HP_e5;

    // ---------- Current update (125 Hz, asynchronous, frame: motor) ----------
    if do_cur then
      z_cur := i_motor + b_cur_true + n_cur;
      t_cur := time;
      hcur := -Ke*N/R_m;
      i_est := (Vcmd - Ke*N*xr2)/R_m;
      y_c := z_cur - (i_est + xr4);
      S_c := hcur*hcur*Pr22 + hcur*Pr24 + hcur*Pr42 + Pr44 + R_cur + 1e-12;
      K_c1 := (hcur*Pr21 + Pr41)/S_c;
      K_c2 := (hcur*Pr22 + Pr42)/S_c;
      K_c3 := (hcur*Pr23 + Pr43)/S_c;
      K_c4 := (hcur*Pr24 + Pr44)/S_c;
      K_c5 := (hcur*Pr25 + Pr45)/S_c;
      HP_c1 := hcur*Pr21 + Pr41;
      HP_c2 := hcur*Pr22 + Pr42;
      HP_c3 := hcur*Pr23 + Pr43;
      HP_c4 := hcur*Pr24 + Pr44;
      HP_c5 := hcur*Pr25 + Pr45;
      xr1 := xr1 + K_c1*y_c;
      xr2 := xr2 + K_c2*y_c;
      xr3 := xr3 + K_c3*y_c;
      xr4 := xr4 + K_c4*y_c;
      xr5 := xr5 + K_c5*y_c;
      Pr11 := Pr11 - K_c1*HP_c1;
      Pr12 := Pr12 - K_c1*HP_c2;
      Pr13 := Pr13 - K_c1*HP_c3;
      Pr14 := Pr14 - K_c1*HP_c4;
      Pr15 := Pr15 - K_c1*HP_c5;
      Pr21 := Pr21 - K_c2*HP_c1;
      Pr22 := Pr22 - K_c2*HP_c2;
      Pr23 := Pr23 - K_c2*HP_c3;
      Pr24 := Pr24 - K_c2*HP_c4;
      Pr25 := Pr25 - K_c2*HP_c5;
      Pr31 := Pr31 - K_c3*HP_c1;
      Pr32 := Pr32 - K_c3*HP_c2;
      Pr33 := Pr33 - K_c3*HP_c3;
      Pr34 := Pr34 - K_c3*HP_c4;
      Pr35 := Pr35 - K_c3*HP_c5;
      Pr41 := Pr41 - K_c4*HP_c1;
      Pr42 := Pr42 - K_c4*HP_c2;
      Pr43 := Pr43 - K_c4*HP_c3;
      Pr44 := Pr44 - K_c4*HP_c4;
      Pr45 := Pr45 - K_c4*HP_c5;
      Pr51 := Pr51 - K_c5*HP_c1;
      Pr52 := Pr52 - K_c5*HP_c2;
      Pr53 := Pr53 - K_c5*HP_c3;
      Pr54 := Pr54 - K_c5*HP_c4;
      Pr55 := Pr55 - K_c5*HP_c5;
    end if;

    // ---------- Landmark updates (25 Hz, asynchronous, frame: world) ----------
    if do_lm then
      z_lm1 := Modelica.Math.atan2(lm1_y - y_tip, lm1_x - x_tip) - q + b_lm_true + n_lm1;
      z_lm2 := Modelica.Math.atan2(lm2_y - y_tip, lm2_x - x_tip) - q + b_lm_true + n_lm2;
      t_lm1 := time;
      t_lm2 := time;

      // Landmark 1
      dx1 := lm1_x - L*Modelica.Math.sin(xr1);
      dy1 := lm1_y - L*Modelica.Math.cos(xr1);
      r21 := dx1*dx1 + dy1*dy1 + eps_r2;
      hb1 := L*(dx1*Modelica.Math.sin(xr1) + dy1*Modelica.Math.cos(xr1))/r21 - 1.0;
      y_l1 := z_lm1 - (Modelica.Math.atan2(dy1,dx1) - xr1 + xr5);
      S_l1 := hb1*hb1*Pr11 + hb1*Pr15 + hb1*Pr51 + Pr55 + R_lm + 1e-12;
      K_l1_1 := (hb1*Pr11 + Pr51)/S_l1;
      K_l1_2 := (hb1*Pr21 + Pr52)/S_l1;
      K_l1_3 := (hb1*Pr31 + Pr53)/S_l1;
      K_l1_4 := (hb1*Pr41 + Pr54)/S_l1;
      K_l1_5 := (hb1*Pr51 + Pr55)/S_l1;
      HP_l1_1 := hb1*Pr11 + Pr51;
      HP_l1_2 := hb1*Pr12 + Pr52;
      HP_l1_3 := hb1*Pr13 + Pr53;
      HP_l1_4 := hb1*Pr14 + Pr54;
      HP_l1_5 := hb1*Pr15 + Pr55;
      xr1 := xr1 + K_l1_1*y_l1;
      xr2 := xr2 + K_l1_2*y_l1;
      xr3 := xr3 + K_l1_3*y_l1;
      xr4 := xr4 + K_l1_4*y_l1;
      xr5 := xr5 + K_l1_5*y_l1;
      Pr11 := Pr11 - K_l1_1*HP_l1_1;
      Pr12 := Pr12 - K_l1_1*HP_l1_2;
      Pr13 := Pr13 - K_l1_1*HP_l1_3;
      Pr14 := Pr14 - K_l1_1*HP_l1_4;
      Pr15 := Pr15 - K_l1_1*HP_l1_5;
      Pr21 := Pr21 - K_l1_2*HP_l1_1;
      Pr22 := Pr22 - K_l1_2*HP_l1_2;
      Pr23 := Pr23 - K_l1_2*HP_l1_3;
      Pr24 := Pr24 - K_l1_2*HP_l1_4;
      Pr25 := Pr25 - K_l1_2*HP_l1_5;
      Pr31 := Pr31 - K_l1_3*HP_l1_1;
      Pr32 := Pr32 - K_l1_3*HP_l1_2;
      Pr33 := Pr33 - K_l1_3*HP_l1_3;
      Pr34 := Pr34 - K_l1_3*HP_l1_4;
      Pr35 := Pr35 - K_l1_3*HP_l1_5;
      Pr41 := Pr41 - K_l1_4*HP_l1_1;
      Pr42 := Pr42 - K_l1_4*HP_l1_2;
      Pr43 := Pr43 - K_l1_4*HP_l1_3;
      Pr44 := Pr44 - K_l1_4*HP_l1_4;
      Pr45 := Pr45 - K_l1_4*HP_l1_5;
      Pr51 := Pr51 - K_l1_5*HP_l1_1;
      Pr52 := Pr52 - K_l1_5*HP_l1_2;
      Pr53 := Pr53 - K_l1_5*HP_l1_3;
      Pr54 := Pr54 - K_l1_5*HP_l1_4;
      Pr55 := Pr55 - K_l1_5*HP_l1_5;

      // Landmark 2
      dx2 := lm2_x - L*Modelica.Math.sin(xr1);
      dy2 := lm2_y - L*Modelica.Math.cos(xr1);
      r22 := dx2*dx2 + dy2*dy2 + eps_r2;
      hb2 := L*(dx2*Modelica.Math.sin(xr1) + dy2*Modelica.Math.cos(xr1))/r22 - 1.0;
      y_l2 := z_lm2 - (Modelica.Math.atan2(dy2,dx2) - xr1 + xr5);
      S_l2 := hb2*hb2*Pr11 + hb2*Pr15 + hb2*Pr51 + Pr55 + R_lm + 1e-12;
      K_l2_1 := (hb2*Pr11 + Pr51)/S_l2;
      K_l2_2 := (hb2*Pr21 + Pr52)/S_l2;
      K_l2_3 := (hb2*Pr31 + Pr53)/S_l2;
      K_l2_4 := (hb2*Pr41 + Pr54)/S_l2;
      K_l2_5 := (hb2*Pr51 + Pr55)/S_l2;
      HP_l2_1 := hb2*Pr11 + Pr51;
      HP_l2_2 := hb2*Pr12 + Pr52;
      HP_l2_3 := hb2*Pr13 + Pr53;
      HP_l2_4 := hb2*Pr14 + Pr54;
      HP_l2_5 := hb2*Pr15 + Pr55;
      xr1 := xr1 + K_l2_1*y_l2;
      xr2 := xr2 + K_l2_2*y_l2;
      xr3 := xr3 + K_l2_3*y_l2;
      xr4 := xr4 + K_l2_4*y_l2;
      xr5 := xr5 + K_l2_5*y_l2;
      Pr11 := Pr11 - K_l2_1*HP_l2_1;
      Pr12 := Pr12 - K_l2_1*HP_l2_2;
      Pr13 := Pr13 - K_l2_1*HP_l2_3;
      Pr14 := Pr14 - K_l2_1*HP_l2_4;
      Pr15 := Pr15 - K_l2_1*HP_l2_5;
      Pr21 := Pr21 - K_l2_2*HP_l2_1;
      Pr22 := Pr22 - K_l2_2*HP_l2_2;
      Pr23 := Pr23 - K_l2_2*HP_l2_3;
      Pr24 := Pr24 - K_l2_2*HP_l2_4;
      Pr25 := Pr25 - K_l2_2*HP_l2_5;
      Pr31 := Pr31 - K_l2_3*HP_l2_1;
      Pr32 := Pr32 - K_l2_3*HP_l2_2;
      Pr33 := Pr33 - K_l2_3*HP_l2_3;
      Pr34 := Pr34 - K_l2_3*HP_l2_4;
      Pr35 := Pr35 - K_l2_3*HP_l2_5;
      Pr41 := Pr41 - K_l2_4*HP_l2_1;
      Pr42 := Pr42 - K_l2_4*HP_l2_2;
      Pr43 := Pr43 - K_l2_4*HP_l2_3;
      Pr44 := Pr44 - K_l2_4*HP_l2_4;
      Pr45 := Pr45 - K_l2_4*HP_l2_5;
      Pr51 := Pr51 - K_l2_5*HP_l2_1;
      Pr52 := Pr52 - K_l2_5*HP_l2_2;
      Pr53 := Pr53 - K_l2_5*HP_l2_3;
      Pr54 := Pr54 - K_l2_5*HP_l2_4;
      Pr55 := Pr55 - K_l2_5*HP_l2_5;
    end if;

    // ---------- Commit estimator state ----------
    x_hat1 := xr1;
    x_hat2 := xr2;
    x_hat3 := xr3;
    x_hat4 := xr4;
    x_hat5 := xr5;
    P11 := Pr11; P12 := Pr12; P13 := Pr13; P14 := Pr14; P15 := Pr15;
    P21 := Pr21; P22 := Pr22; P23 := Pr23; P24 := Pr24; P25 := Pr25;
    P31 := Pr31; P32 := Pr32; P33 := Pr33; P34 := Pr34; P35 := Pr35;
    P41 := Pr41; P42 := Pr42; P43 := Pr43; P44 := Pr44; P45 := Pr45;
    P51 := Pr51; P52 := Pr52; P53 := Pr53; P54 := Pr54; P55 := Pr55;

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
    if (cov_min <= 1e-12) or (cov_min >= 1e6) or (not fin(Pr11)) or (not fin(Pr55)) then
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