model TorqueObserverLocalizeE
  extends Modelica.Icons.Example;

  // Physical parameters
  parameter Real L = 0.58 "Capsule link length [m]";
  parameter Real m_link = 8.0 "Capsule link mass [kg]";
  parameter Real J_link = (1.0/3.0)*m_link*L*L "Inertia about pivot [kg.m2]";
  parameter Real N = 70.0 "Gearbox ratio";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real d_joint = 0.05 "Joint viscous damping [N.m.s/rad]";
  parameter Real mgl2 = m_link*g*(L/2.0) "Gravity torque coefficient [N.m]";

  // Motor drive limits
  parameter Real tau_out_max = 82.5 "Output torque command limit [N.m]";
  parameter Real V_max = 48.0 "Motor voltage limit [V]";
  parameter Real I_max = 40.0 "Motor current limit [A]";
  parameter Real Kt = 0.18 "Motor torque constant [N.m/A]";
  parameter Real Ke = 0.18 "Back-EMF constant [V.s/rad]";
  parameter Real R_m = 0.6 "Motor resistance [Ohm]";

  // Controller / route
  parameter Real Kp_track = 80.0 "Position gain [N.m/rad]";
  parameter Real Kd_track = 8.0 "Velocity gain [N.m.s/rad]";
  parameter Real tau_filt = 0.02 "Measurement filter time constant [s]";
  parameter Real q_ref_amp = 0.6 "Route amplitude [rad]";
  parameter Real q_ref_freq = 0.1 "Route frequency [Hz]";

  // Sensor rates, std devs, frames
  parameter Real f_base = 250.0 "Base / estimator rate [Hz]";
  parameter Real dt_base = 1.0/f_base "Base period [s]";
  parameter Real f_enc = 250.0 "Joint encoder rate [Hz]";
  parameter Real f_cur = 125.0 "Motor current rate [Hz]";
  parameter Real f_lm = 25.0 "Landmark bearing rate [Hz]";
  parameter Real sigma_enc = 0.002 "Encoder std dev [rad], frame: joint";
  parameter Real sigma_cur = 0.05 "Current std dev [A], frame: motor";
  parameter Real sigma_lm = 0.02 "Landmark bearing std dev [rad], frame: world";

  // Bias disturbance (middle third)
  parameter Real bias_step = 0.048 "Sensor-bias step magnitude [rad]";
  parameter Real t_on = 16.0/3.0 "Middle-third disturbance start [s]";
  parameter Real t_off = 2.0*16.0/3.0 "Middle-third disturbance end [s]";
  parameter Real tau_rise = 0.02 "Smooth step rise time [s]";

  // Fixed landmarks
  parameter Real lm1_x = 1.0 "Landmark 1 x [m], world frame";
  parameter Real lm1_y = 0.5 "Landmark 1 y [m], world frame";
  parameter Real lm2_x = -0.8 "Landmark 2 x [m], world frame";
  parameter Real lm2_y = 1.0 "Landmark 2 y [m], world frame";

  // EKF noise
  parameter Real q_q = 1e-5 "Process noise (angle) [rad2]";
  parameter Real q_w = 1e-3 "Process noise (rate) [(rad/s)2]";
  parameter Real q_be = 1e-5 "Process noise (encoder bias) [rad2]";
  parameter Real q_bc = 1e-6 "Process noise (current bias) [A2]";
  parameter Real q_bl = 1e-6 "Process noise (landmark bias) [rad2]";
  parameter Real R_enc = sigma_enc*sigma_enc "Encoder meas variance";
  parameter Real R_cur = sigma_cur*sigma_cur "Current meas variance";
  parameter Real R_lm = sigma_lm*sigma_lm "Landmark meas variance";

  // Acceptance
  parameter Real t_final = 16.0 "Final time [s]";
  parameter Real t_check = 10.4 "Tracking-error check time [s]";
  parameter Real t_settle = 12.0 "Bias settle time [s]";
  parameter Real track_limit = 0.18 "Primary tracking limit [m-or-rad]";
  parameter Real pos_band = 0.05 "Position error band [m]";
  parameter Real att_band = 0.05 "Attitude error band [rad]";
  parameter Real bias_tol = 0.02 "Bias convergence tolerance [rad]";
  parameter Real eps_r2 = 1e-6 "Range-squared guard [m2]";

  // Plant state
  output Real q(start=0.0, fixed=true) "Joint angle [rad]";
  output Real w(start=0.0, fixed=true) "Joint angular velocity [rad/s]";
  output Real x_tip "Tip x position [m]";
  output Real y_tip "Tip y position [m]";
  Real q_ref "Reference angle [rad]";
  Real q_ref_dot "Reference angular velocity [rad/s]";
  Real x_tip_ref "Reference tip x [m]";
  Real y_tip_ref "Reference tip y [m]";

  // Controller / motor
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

  // True sensor biases
  Real b_enc_true "True encoder bias [rad]";
  Real b_cur_true "True current bias [A]";
  Real b_lm_true "True landmark bias [rad]";

  // Continuous deterministic noise
  Real n_enc;
  Real n_cur;
  Real n_lm1;
  Real n_lm2;

  // Sampled measurements + timestamps
  output Real z_enc "Sampled encoder reading [rad]";
  output Real z_cur "Sampled current reading [A]";
  output Real z_lm1 "Sampled landmark 1 bearing [rad]";
  output Real z_lm2 "Sampled landmark 2 bearing [rad]";
  output Real t_enc "Encoder timestamp [s]";
  output Real t_cur "Current timestamp [s]";
  output Real t_lm1 "Landmark 1 timestamp [s]";
  output Real t_lm2 "Landmark 2 timestamp [s]";
  Integer tick(start=0) "Master tick counter";

  // Estimator state (scalar)
  output Real q_hat(start=0.02, fixed=true) "Estimated angle [rad]";
  output Real w_hat(start=0.0, fixed=true) "Estimated rate [rad/s]";
  output Real benc_hat(start=0.0, fixed=true) "Estimated encoder bias [rad]";
  output Real bcur_hat(start=0.0, fixed=true) "Estimated current bias [A]";
  output Real blm_hat(start=0.0, fixed=true) "Estimated landmark bias [rad]";
  output Real x_tip_hat "Estimated tip x [m]";
  output Real y_tip_hat "Estimated tip y [m]";

  // Covariance diagonal and key off-diagonal terms
  Real P11(start=0.01, fixed=true);
  Real P22(start=0.01, fixed=true);
  Real P33(start=1e-3, fixed=true);
  Real P44(start=1e-4, fixed=true);
  Real P55(start=1e-4, fixed=true);
  Real P12, P13, P14, P15;
  Real P23, P24, P25;
  Real P34, P35, P45;

  // Discrete temporaries
  Real a_p, Ca, Cw;
  Real qr1, qr2, qr3, qr4, qr5;
  Real Pr11, Pr22, Pr33, Pr44, Pr55;
  Real Pr12, Pr13, Pr14, Pr15;
  Real Pr23, Pr24, Pr25;
  Real Pr34, Pr35, Pr45;
  Real F11, F12, F21, F22;
  Real tmp11, tmp12, tmp21, tmp22;
  Real y_e, S_e, K1e, K2e, K3e, K4e, K5e;
  Real hcur, i_est, y_c, S_c, K1c, K2c, K3c, K4c, K5c;
  Real dx1, dy1, r21, hb1, y_l1, S_l1, K1l1, K2l1, K3l1, K4l1, K5l1;
  Real dx2, dy2, r22, hb2, y_l2, S_l2, K1l2, K2l2, K3l2, K4l2, K5l2;
  Boolean do_cur, do_lm;

  // Acceptance
  output Real track_err_tip "Primary tip tracking error [m]";
  output Real pos_err "Position estimation error [m]";
  output Real att_err "Attitude estimation error [rad]";
  output Real bias_err "Encoder bias estimation error [rad]";
  output Real cov_min "Minimum covariance diagonal";
  Boolean actuator_ok;
  Boolean finite_ok;
  Boolean fail_track(start=false, fixed=true);
  Boolean fail_pose(start=false, fixed=true);
  Boolean fail_bias(start=false, fixed=true);
  Boolean fail_cov(start=false, fixed=true);
  Boolean fail_act(start=false, fixed=true);
  Boolean fail_fin(start=false, fixed=true);
  output Boolean accept;
  output Boolean passed;

protected
  function fin "Finite-value check"
    input Real x;
    output Boolean y;
  algorithm
    y := (x >= -1e30) and (x <= 1e30);
  end fin;

initial equation
  P12 = 0.0;
  P13 = 0.0;
  P14 = 0.0;
  P15 = 0.0;
  P23 = 0.0;
  P24 = 0.0;
  P25 = 0.0;
  P34 = 0.0;
  P35 = 0.0;
  P45 = 0.0;

equation
  // Plant kinematics / dynamics
  x_tip = L*Modelica.Math.sin(q);
  y_tip = L*Modelica.Math.cos(q);
  der(q) = w;
  der(w) = (tau_out - mgl2*Modelica.Math.sin(q) - d_joint*w)/J_link;

  // Reference route
  q_ref = q_ref_amp*Modelica.Math.sin(2*Modelica.Constants.pi*q_ref_freq*time);
  q_ref_dot = q_ref_amp*2*Modelica.Constants.pi*q_ref_freq*Modelica.Math.cos(2*Modelica.Constants.pi*q_ref_freq*time);
  x_tip_ref = L*Modelica.Math.sin(q_ref);
  y_tip_ref = L*Modelica.Math.cos(q_ref);

  // True sensor bias (smooth middle-third step)
  b_enc_true = bias_step*0.5*(Modelica.Math.tanh((time - t_on)/tau_rise) - Modelica.Math.tanh((time - t_off)/tau_rise));
  b_cur_true = 0.0;
  b_lm_true = 0.0;

  // Continuous deterministic noise
  n_enc = sigma_enc*Modelica.Math.sin(2*Modelica.Constants.pi*13.7*time + 0.3);
  n_cur = sigma_cur*Modelica.Math.sin(2*Modelica.Constants.pi*27.3*time + 1.1);
  n_lm1 = sigma_lm*Modelica.Math.sin(2*Modelica.Constants.pi*7.9*time + 2.2);
  n_lm2 = sigma_lm*Modelica.Math.sin(2*Modelica.Constants.pi*11.3*time + 0.7);

  // Continuous measurement signal (controller side)
  q_meas = q + b_enc_true + n_enc;

  // Controller filter
  der(q_filt) = (q_meas - q_filt)/tau_filt;
  w_filt = (q_meas - q_filt)/tau_filt;

  // Controller + motor drive with voltage / current / torque limits
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

  // Estimator derived outputs
  x_tip_hat = L*Modelica.Math.sin(q_hat);
  y_tip_hat = L*Modelica.Math.cos(q_hat);

  // Acceptance quantities
  track_err_tip = Modelica.Math.sqrt(Modelica.Math.max((x_tip - x_tip_ref)^2 + (y_tip - y_tip_ref)^2, 0.0));
  pos_err = Modelica.Math.sqrt(Modelica.Math.max((x_tip - x_tip_hat)^2 + (y_tip - y_tip_hat)^2, 0.0));
  att_err = abs(q - q_hat);
  bias_err = abs(b_enc_true - benc_hat);
  cov_min = Modelica.Math.min(Modelica.Math.min(Modelica.Math.min(P11, P22), Modelica.Math.min(P33, P44)), P55);
  actuator_ok = (abs(tau_out) <= tau_out_max*1.001) and (abs(Vcmd) <= V_max*1.001) and (abs(i_motor) <= I_max*1.001);
  finite_ok = fin(q) and fin(w) and fin(q_hat) and fin(w_hat) and fin(benc_hat) and fin(tau_out) and fin(Vcmd) and fin(i_motor) and fin(P11) and fin(P55) and fin(track_err_tip);
  accept = (time >= t_check) and (not fail_track) and (not fail_pose) and (not fail_bias) and (not fail_cov) and (not fail_act) and (not fail_fin);
  passed = accept and (time >= t_final - dt_base);

  // Master asynchronous estimator + sensor sampling
  when sample(0, dt_base) then
    tick := tick + 1;
    do_cur := mod(tick, 2) == 1;
    do_lm := mod(tick, 10) == 0;

    // Predict
    a_p := (tau_out_cmd - mgl2*Modelica.Math.sin(q_hat) - d_joint*w_hat)/J_link;
    Ca := -mgl2*Modelica.Math.cos(q_hat)/J_link;
    Cw := -d_joint/J_link;

    F11 := 1.0;
    F12 := dt_base;
    F21 := Ca*dt_base;
    F22 := 1.0 + Cw*dt_base;

    qr1 := q_hat + w_hat*dt_base + 0.5*a_p*dt_base*dt_base;
    qr2 := w_hat + a_p*dt_base;
    qr3 := benc_hat;
    qr4 := bcur_hat;
    qr5 := blm_hat;

    // Predicted covariance: Pr = F*P*F' + Q
    // Only first 2 states have dynamics; states 3-5 are identity
    tmp11 := F11*P11 + F12*P21_val(P12);
    tmp12 := F11*P12 + F12*P22;
    tmp21 := F21*P11 + F22*P12;
    tmp22 := F21*P12 + F22*P22;
    Pr11 := tmp11*F11 + tmp12*F12 + q_q;
    Pr12 := tmp11*F21 + tmp12*F22;
    Pr13 := F11*P13 + F12*P23;
    Pr14 := F11*P14 + F12*P24;
    Pr15 := F11*P15 + F12*P25;
    Pr22 := tmp21*F21 + tmp22*F22 + q_w;
    Pr23 := F21*P13 + F22*P23;
    Pr24 := F21*P14 + F22*P24;
    Pr25 := F21*P15 + F22*P25;
    Pr33 := P33 + q_be;
    Pr34 := P34;
    Pr35 := P35;
    Pr44 := P44 + q_bc;
    Pr45 := P45;
    Pr55 := P55 + q_bl;

    // Encoder update (250 Hz, frame: joint)
    z_enc := q + b_enc_true + n_enc;
    t_enc := time;
    y_e := z_enc - (qr1 + qr3);
    S_e := Pr11 + Pr13 + Pr31_val(Pr13) + Pr33 + R_enc + 1e-12;
    K1e := (Pr11 + Pr13)/S_e;
    K2e := (Pr12 + Pr23)/S_e;
    K3e := (Pr13 + Pr33)/S_e;
    K4e := (Pr14 + Pr34)/S_e;
    K5e := (Pr15 + Pr35)/S_e;

    qr1 := qr1 + K1e*y_e;
    qr2 := qr2 + K2e*y_e;
    qr3 := qr3 + K3e*y_e;
    qr4 := qr4 + K4e*y_e;
    qr5 := qr5 + K5e*y_e;

    Pr11 := Pr11 - K1e*(Pr11 + Pr13);
    Pr12 := Pr12 - K1e*(Pr12 + Pr23);
    Pr13 := Pr13 - K1e*(Pr13 + Pr33);
    Pr14 := Pr14 - K1e*(Pr14 + Pr34);
    Pr15 := Pr15 - K1e*(Pr15 + Pr35);
    Pr12 := Pr12 - K2e*(Pr11 + Pr13);
    Pr22 := Pr22 - K2e*(Pr12 + Pr23);
    Pr23 := Pr23 - K2e*(Pr13 + Pr33);
    Pr24 := Pr24 - K2e*(Pr14 + Pr34);
    Pr25 := Pr25 - K2e*(Pr15 + Pr35);
    Pr13 := Pr13 - K3e*(Pr11 + Pr13);
    Pr23 := Pr23 - K3e*(Pr12 + Pr23);
    Pr33 := Pr33 - K3e*(Pr13 + Pr33);
    Pr34 := Pr34 - K3e*(Pr14 + Pr34);
    Pr35 := Pr35 - K3e*(Pr15 + Pr35);
    Pr14 := Pr14 - K4e*(Pr11 + Pr13);
    Pr24 := Pr24 - K4e*(Pr12 + Pr23);
    Pr34 := Pr34 - K4e*(Pr13 + Pr33);
    Pr44 := Pr44 - K4e*(Pr14 + Pr34);
    Pr45 := Pr45 - K4e*(Pr15 + Pr35);
    Pr15 := Pr15 - K5e*(Pr11 + Pr13);
    Pr25 := Pr25 - K5e*(Pr12 + Pr23);
    Pr35 := Pr35 - K5e*(Pr13 + Pr33);
    Pr45 := Pr45 - K5e*(Pr14 + Pr34);
    Pr55 := Pr55 - K5e*(Pr15 + Pr35);

    // Current update (125 Hz, asynchronous, frame: motor)
    if do_cur then
      z_cur := i_motor + b_cur_true + n_cur;
      t_cur := time;
      hcur := -Ke*N/R_m;
      i_est := (Vcmd - Ke*N*qr2)/R_m;
      y_c := z_cur - (i_est + qr4);
      S_c := hcur*hcur*Pr22 + hcur*Pr24 + hcur*Pr24 + Pr44 + R_cur + 1e-12;
      K1c := (hcur*Pr12 + Pr14)/S_c;
      K2c := (hcur*Pr22 + Pr24)/S_c;
      K3c := (hcur*Pr23 + Pr34)/S_c;
      K4c := (hcur*Pr24 + Pr44)/S_c;
      K5c := (hcur*Pr25 + Pr45)/S_c;

      qr1 := qr1 + K1c*y_c;
      qr2 := qr2 + K2c*y_c;
      qr3 := qr3 + K3c*y_c;
      qr4 := qr4 + K4c*y_c;
      qr5 := qr5 + K5c*y_c;

      Pr11 := Pr11 - K1c*(hcur*Pr12 + Pr14);
      Pr12 := Pr12 - K1c*(hcur*Pr22 + Pr24);
      Pr13 := Pr13 - K1c*(hcur*Pr23 + Pr34);
      Pr14 := Pr14 - K1c*(hcur*Pr24 + Pr44);
      Pr15 := Pr15 - K1c*(hcur*Pr25 + Pr45);
      Pr12 := Pr12 - K2c*(hcur*Pr12 + Pr14);
      Pr22 := Pr22 - K2c*(hcur*Pr22 + Pr24);
      Pr23 := Pr23 - K2c*(hcur*Pr23 + Pr34);
      Pr24 := Pr24 - K2c*(hcur*Pr24 + Pr44);
      Pr25 := Pr25 - K2c*(hcur*Pr25 + Pr45);
      Pr13 := Pr13 - K3c*(hcur*Pr12 + Pr14);
      Pr23 := Pr23 - K3c*(hcur*Pr22 + Pr24);
      Pr33 := Pr33 - K3c*(hcur*Pr23 + Pr34);
      Pr34 := Pr34 - K3c*(hcur*Pr24 + Pr44);
      Pr35 := Pr35 - K3c*(hcur*Pr25 + Pr45);
      Pr14 := Pr14 - K4c*(hcur*Pr12 + Pr14);
      Pr24 := Pr24 - K4c*(hcur*Pr22 + Pr24);
      Pr34 := Pr34 - K4c*(hcur*Pr23 + Pr34);
      Pr44 := Pr44 - K4c*(hcur*Pr24 + Pr44);
      Pr45 := Pr45 - K4c*(hcur*Pr25 + Pr45);
      Pr15 := Pr15 - K5c*(hcur*Pr12 + Pr14);
      Pr25 := Pr25 - K5c*(hcur*Pr22 + Pr24);
      Pr35 := Pr35 - K5c*(hcur*Pr23 + Pr34);
      Pr45 := Pr45 - K5c*(hcur*Pr24 + Pr44);
      Pr55 := Pr55 - K5c*(hcur*Pr25 + Pr45);
    end if;

    // Landmark updates (25 Hz, asynchronous, frame: world)
    if do_lm then
      z_lm1 := Modelica.Math.atan2(lm1_y - y_tip, lm1_x - x_tip) - q + b_lm_true + n_lm1;
      z_lm2 := Modelica.Math.atan2(lm2_y - y_tip, lm2_x - x_tip) - q + b_lm_true + n_lm2;
      t_lm1 := time;
      t_lm2 := time;

      // Landmark 1
      dx1 := lm1_x - L*Modelica.Math.sin(qr1);
      dy1 := lm1_y - L*Modelica.Math.cos(qr1);
      r21 := dx1*dx1 + dy1*dy1 + eps_r2;
      hb1 := L*(dx1*Modelica.Math.sin(qr1) + dy1*Modelica.Math.cos(qr1))/r21 - 1.0;
      y_l1 := z_lm1 - (Modelica.Math.atan2(dy1, dx1) - qr1 + qr5);
      S_l1 := hb1*hb1*Pr11 + hb1*Pr15 + hb1*Pr15 + Pr55 + R_lm + 1e-12;
      K1l1 := (hb1*Pr11 + Pr15)/S_l1;
      K2l1 := (hb1*Pr12 + Pr25)/S_l1;
      K3l1 := (hb1*Pr13 + Pr35)/S_l1;
      K4l1 := (hb1*Pr14 + Pr45)/S_l1;
      K5l1 := (hb1*Pr15 + Pr55)/S_l1;

      qr1 := qr1 + K1l1*y_l1;
      qr2 := qr2 + K2l1*y_l1;
      qr3 := qr3 + K3l1*y_l1;
      qr4 := qr4 + K4l1*y_l1;
      qr5 := qr5 + K5l1*y_l1;

      Pr11 := Pr11 - K1l1*(hb1*Pr11 + Pr15);
      Pr12 := Pr12 - K1l1*(hb1*Pr12 + Pr25);
      Pr13 := Pr13 - K1l1*(hb1*Pr13 + Pr35);
      Pr14 := Pr14 - K1l1*(hb1*Pr14 + Pr45);
      Pr15 := Pr15 - K1l1*(hb1*Pr15 + Pr55);
      Pr12 := Pr12 - K2l1*(hb1*Pr11 + Pr15);
      Pr22 := Pr22 - K2l1*(hb1*Pr12 + Pr25);
      Pr23 := Pr23 - K2l1*(hb1*Pr13 + Pr35);
      Pr24 := Pr24 - K2l1*(hb1*Pr14 + Pr45);
      Pr25 := Pr25 - K2l1*(hb1*Pr15 + Pr55);
      Pr13 := Pr13 - K3l1*(hb1*Pr11 + Pr15);
      Pr23 := Pr23 - K3l1*(hb1*Pr12 + Pr25);
      Pr33 := Pr33 - K3l1*(hb1*Pr13 + Pr35);
      Pr34 := Pr34 - K3l1*(hb1*Pr14 + Pr45);
      Pr35 := Pr35 - K3l1*(hb1*Pr15 + Pr55);
      Pr14 := Pr14 - K4l1*(hb1*Pr11 + Pr15);
      Pr24 := Pr24 - K4l1*(hb1*Pr12 + Pr25);
      Pr34 := Pr34 - K4l1*(hb1*Pr13 + Pr35);
      Pr44 := Pr44 - K4l1*(hb1*Pr14 + Pr45);
      Pr45 := Pr45 - K4l1*(hb1*Pr15 + Pr55);
      Pr15 := Pr15 - K5l1*(hb1*Pr11 + Pr15);
      Pr25 := Pr25 - K5l1*(hb1*Pr12 + Pr25);
      Pr35 := Pr35 - K5l1*(hb1*Pr13 + Pr35);
      Pr45 := Pr45 - K5l1*(hb1*Pr14 + Pr45);
      Pr55 := Pr55 - K5l1*(hb1*Pr15 + Pr55);

      // Landmark 2
      dx2 := lm2_x - L*Modelica.Math.sin(qr1);
      dy2 := lm2_y - L*Modelica.Math.cos(qr1);
      r22 := dx2*dx2 + dy2*dy2 + eps_r2;
      hb2 := L*(dx2*Modelica.Math.sin(qr1) + dy2*Modelica.Math.cos(qr1))/r22 - 1.0;
      y_l2 := z_lm2 - (Modelica.Math.atan2(dy2, dx2) - qr1 + qr5);
      S_l2 := hb2*hb2*Pr11 + hb2*Pr15 + hb2*Pr15 + Pr55 + R_lm + 1e-12;
      K1l2 := (hb2*Pr11 + Pr15)/S_l2;
      K2l2 := (hb2*Pr12 + Pr25)/S_l2;
      K3l2 := (hb2*Pr13 + Pr35)/S_l2;
      K4l2 := (hb2*Pr14 + Pr45)/S_l2;
      K5l2 := (hb2*Pr15 + Pr55)/S_l2;

      qr1 := qr1 + K1l2*y_l2;
      qr2 := qr2 + K2l2*y_l2;
      qr3 := qr3 + K3l2*y_l2;
      qr4 := qr4 + K4l2*y_l2;
      qr5 := qr5 + K5l2*y_l2;

      Pr11 := Pr11 - K1l2*(hb2*Pr11 + Pr15);
      Pr12 := Pr12 - K1l2*(hb2*Pr12 + Pr25);
      Pr13 := Pr13 - K1l2*(hb2*Pr13 + Pr35);
      Pr14 := Pr14 - K1l2*(hb2*Pr14 + Pr45);
      Pr15 := Pr15 - K1l2*(hb2*Pr15 + Pr55);
      Pr12 := Pr12 - K2l2*(hb2*Pr11 + Pr15);
      Pr22 := Pr22 - K2l2*(hb2*Pr12 + Pr25);
      Pr23 := Pr23 - K2l2*(hb2*Pr13 + Pr35);
      Pr24 := Pr24 - K2l2*(hb2*Pr14 + Pr45);
      Pr25 := Pr25 - K2l2*(hb2*Pr15 + Pr55);
      Pr13 := Pr13 - K3l2*(hb2*Pr11 + Pr15);
      Pr23 := Pr23 - K3l2*(hb2*Pr12 + Pr25);
      Pr33 := Pr33 - K3l2*(hb2*Pr13 + Pr35);
      Pr34 := Pr34 - K3l2*(hb2*Pr14 + Pr45);
      Pr35 := Pr35 - K3l2*(hb2*Pr15 + Pr55);
      Pr14 := Pr14 - K4l2*(hb2*Pr11 + Pr15);
      Pr24 := Pr24 - K4l2*(hb2*Pr12 + Pr25);
      Pr34 := Pr34 - K4l2*(hb2*Pr13 + Pr35);
      Pr44 := Pr44 - K4l2*(hb2*Pr14 + Pr45);
      Pr45 := Pr45 - K4l2*(hb2*Pr15 + Pr55);
      Pr15 := Pr15 - K5l2*(hb2*Pr11 + Pr15);
      Pr25 := Pr25 - K5l2*(hb2*Pr12 + Pr25);
      Pr35 := Pr35 - K5l2*(hb2*Pr13 + Pr35);
      Pr45 := Pr45 - K5l2*(hb2*Pr14 + Pr45);
      Pr55 := Pr55 - K5l2*(hb2*Pr15 + Pr55);
    end if;

    // Commit estimator state
    q_hat := qr1;
    w_hat := qr2;
    benc_hat := qr3;
    bcur_hat := qr4;
    blm_hat := qr5;
    P11 := Pr11;
    P12 := Pr12;
    P13 := Pr13;
    P14 := Pr14;
    P15 := Pr15;
    P22 := Pr22;
    P23 := Pr23;
    P24 := Pr24;
    P25 := Pr25;
    P33 := Pr33;
    P34 := Pr34;
    P35 := Pr35;
    P44 := Pr44;
    P45 := Pr45;
    P55 := Pr55;

    // Fail-closed acceptance latches
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