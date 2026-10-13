model BallScrewPositionD
  import Modelica.Constants.pi;

  // Scenario timing and controller rate
  parameter Real T_run(unit="s") = 14.0 "simulation/run duration [s]";
  parameter Real Ts(unit="s") = 0.005 "controller sample period, 200 Hz [s]";
  parameter Real t_dist_start(unit="s") = T_run/3 "middle-third disturbance start [s]";
  parameter Real t_dist_end(unit="s") = 2*T_run/3 "middle-third disturbance end [s]";
  parameter Real t_check(unit="s") = 9.1 "tracking-error check time [s]";

  // Plant facts from requirement
  parameter Real Vmax(unit="V") = 24.0 "motor voltage limit [V]";
  parameter Real p_pitch(unit="m") = 0.005 "ball screw pitch, 5 mm/rev [m]";
  parameter Real m_carriage(unit="kg") = 18.0 "linear carriage mass [kg]";
  parameter Real L_travel(unit="m") = 0.65 "physical travel [m]";
  parameter Real F_dist_mag(unit="N") = 8.0 "output load disturbance magnitude [N]";

  // Target and initial condition (nonzero target; values are placeholders)
  parameter Real x_target(unit="m") = 0.40 "nonzero commanded output position [m]";
  parameter Real x0(unit="m") = 0.10 "initial carriage position [m]";

  // Belt reduction: ratio not specified; placeholder value for simulation completeness
  parameter Real N_belt(unit="1") = 2.0 "belt reduction ratio motor:screw, not specified [1]";
  parameter Real r_screw(unit="m/rad") = p_pitch/(2*pi*N_belt) "carriage travel per motor radian [m/rad]";

  // Motor electrical parameters: not specified; placeholder SI values
  parameter Real Kt(unit="N.m/A") = 0.05 "motor torque constant [N.m/A]";
  parameter Real Ke(unit="V.s/rad") = Kt "back EMF constant; SI equality to Kt assumed [V.s/rad]";
  parameter Real R(unit="Ohm") = 1.5 "winding resistance [Ohm]";
  parameter Real L_ind(unit="H") = 0.02 "winding inductance [H]";
  parameter Real J_motor(unit="kg.m2") = 0.0001 "motor rotor inertia [kg.m2]";

  // Friction parameters: Coulomb levels not specified; placeholder SI values
  parameter Real Fc_c(unit="N") = 2.0 "carriage Coulomb friction force [N]";
  parameter Real b_carriage(unit="N.s/m") = 5.0 "carriage viscous damping [N.s/m]";
  parameter Real v_eps_c(unit="m/s") = 0.001 "carriage friction smoothing velocity [m/s]";
  parameter Real Fc_m(unit="N.m") = 0.002 "motor Coulomb friction torque [N.m]";
  parameter Real b_motor(unit="N.m.s/rad") = 0.0005 "motor viscous damping [N.m.s/rad]";
  parameter Real omega_eps_m(unit="rad/s") = 1.0 "motor friction smoothing speed [rad/s]";

  // Backlash parameters: width/stiffness not specified; placeholder SI values
  parameter Real b_backlash(unit="m") = 0.001 "backlash width [m]";
  parameter Real k_back(unit="N/m") = 20000.0 "backlash contact stiffness [N/m]";
  parameter Real c_back(unit="N.s/m") = 200.0 "backlash contact damping [N.s/m]";
  parameter Real eps_back(unit="m") = 0.0001 "backlash smoothing length [m]";

  // Travel-stop collision parameters: not specified; placeholder SI values
  parameter Real k_stop(unit="N/m") = 100000.0 "end-stop stiffness [N/m]";
  parameter Real c_stop(unit="N.s/m") = 300.0 "end-stop damping [N.s/m]";

  // Thermal parameters: not specified; placeholder SI values
  parameter Real C_th(unit="J/K") = 20.0 "winding thermal capacitance [J/K]";
  parameter Real R_th(unit="K/W") = 5.0 "winding-to-ambient thermal resistance [K/W]";
  parameter Real T_amb(unit="K") = 293.15 "ambient temperature [K]";

  // Load orientation not specified; gravity load omitted by default
  parameter Real F_gravity(unit="N") = 0.0 "gravity load along travel, unknown orientation [N]";

  // Bounds: current/temperature bounds not specified; placeholder values
  parameter Real Imax(unit="A") = 5.0 "current command limit [A]";
  parameter Real I_bound(unit="A") = 6.0 "current bound [A]";
  parameter Real T_max(unit="K") = 340.0 "winding temperature bound [K]";
  parameter Real tracking_bound(unit="m") = 0.03 "primary tracking-error bound after t_check [m]";

  // Controller gains: not specified; placeholder SI values
  parameter Real Kp_pos(unit="A/m") = 8.0 "position-loop proportional gain [A/m]";
  parameter Real Kd_pos(unit="A.s/m") = 0.8 "position-loop velocity gain [A.s/m]";
  parameter Real Ki_pos(unit="A/(m.s)") = 1.0 "position-loop integral gain [A/(m.s)]";
  parameter Real Kaw_pos(unit="m.s/A") = 0.01 "position-loop anti-windup gain [m.s/A]";
  parameter Real Kp_cur(unit="V/A") = 2.0 "current-loop proportional gain [V/A]";
  parameter Real Ki_cur(unit="V/(A.s)") = 50.0 "current-loop integral gain [V/(A.s)]";
  parameter Real Kaw_cur(unit="A.s/V") = 0.005 "current-loop anti-windup gain [A.s/V]";

  // Continuous physical states
  Real i(unit="A") "winding current [A]";
  Real theta_m(unit="rad") "motor angle [rad]";
  Real omega_m(unit="rad/s") "motor angular velocity [rad/s]";
  Real x(unit="m") "carriage position [m]";
  Real v(unit="m/s") "carriage velocity [m/s]";
  Real T(unit="K") "winding temperature [K]";

  // Discrete controller states and commands
  discrete Real x_err(unit="m", start=0.0, fixed=true) "sampled position error [m]";
  discrete Real i_cmd(unit="A", start=0.0, fixed=true) "current command [A]";
  discrete Real i_raw(unit="A", start=0.0, fixed=true) "unlimited current command [A]";
  discrete Real int_pos(unit="m.s", start=0.0, fixed=true) "position-loop integrator state [m.s]";
  discrete Real i_err(unit="A", start=0.0, fixed=true) "sampled current error [A]";
  discrete Real v_raw(unit="V", start=0.0, fixed=true) "unlimited voltage command [V]";
  discrete Real v_cmd(unit="V", start=0.0, fixed=true) "motor voltage command [V]";
  discrete Real int_cur(unit="A.s", start=0.0, fixed=true) "current-loop integrator state [A.s]";

  // Observable traces and measurements
  Real i_meas(unit="A") "measured winding current [A]";
  Real x_meas(unit="m") "measured output position [m]";
  Real v_meas(unit="m/s") "measured output velocity [m/s]";
  Real T_meas(unit="K") "measured winding temperature [K]";
  Real v_motor(unit="V") "applied motor voltage [V]";
  Real Kforce(unit="N/A") "carriage force per motor current [N/A]";
  Real x_s(unit="m") "screw-equivalent position [m]";
  Real v_s(unit="m/s") "screw-equivalent velocity [m/s]";
  Real d_back(unit="m") "relative displacement across backlash [m]";
  Real d_plus(unit="1") "upper-side contact activation [1]";
  Real d_minus(unit="1") "lower-side contact activation [1]";
  Real F_contact(unit="N") "contact force through backlash [N]";
  Real F_stop(unit="N") "end-stop collision force [N]";
  Real F_friction_c(unit="N") "carriage Coulomb plus viscous friction [N]";
  Real tau_friction_m(unit="N.m") "motor Coulomb plus viscous friction torque [N.m]";
  Real F_dist(unit="N") "time-controlled output load disturbance [N]";
  Real F_load(unit="N") "total external load on carriage [N]";
  Real tracking_error(unit="m") "primary tracking error [m]";
  Real final_error(unit="m") "continuous final/tracking error [m]";

initial equation
  i = 0.0;
  theta_m = x0/r_screw;
  omega_m = 0.0;
  x = x0;
  v = 0.0;
  T = T_amb;

equation
  // Measurements
  i_meas = i;
  x_meas = x;
  v_meas = v;
  T_meas = T;
  v_motor = v_cmd;
  Kforce = Kt/r_screw;
  tracking_error = abs(x_target - x);
  final_error = tracking_error;

  // Screw and backlash kinematics
  x_s = r_screw*theta_m;
  v_s = r_screw*omega_m;
  d_back = x_s - x;
  d_plus = 0.5*(1.0 + tanh((d_back - b_backlash/2)/eps_back));
  d_minus = 0.5*(1.0 + tanh((-d_back - b_backlash/2)/eps_back));
  F_contact = d_plus*(k_back*(d_back - b_backlash/2) + c_back*max(0.0, v_s - v)) +
              d_minus*(k_back*(d_back + b_backlash/2) + c_back*min(0.0, v_s - v));

  // Physical travel limits with collision
  F_stop = if x < 0.0 then k_stop*(0.0 - x) + c_stop*max(0.0, -v)
           elseif x > L_travel then -k_stop*(x - L_travel) - c_stop*max(0.0, v)
           else 0.0;

  // Friction
  F_friction_c = Fc_c*tanh(v/v_eps_c) + b_carriage*v;
  tau_friction_m = Fc_m*tanh(omega_m/omega_eps_m) + b_motor*omega_m;

  // Load disturbance during middle third, plus optional unknown gravity load
  F_dist = if time >= t_dist_start and time <= t_dist_end then -F_dist_mag else 0.0;
  F_load = F_dist + F_gravity;

  // Electrical dynamics
  der(i) = (v_motor - R*i - Ke*omega_m)/L_ind;

  // Motor mechanical dynamics
  der(theta_m) = omega_m;
  der(omega_m) = (Kt*i - r_screw*F_contact - tau_friction_m)/J_motor;

  // Carriage dynamics
  der(x) = v;
  der(v) = (F_contact + F_stop - F_friction_c + F_load)/m_carriage;

  // Winding thermal dynamics
  der(T) = (R*i*i - (T - T_amb)/R_th)/C_th;

  // Cascaded current and position control at 200 Hz with anti-windup
  when sample(0.0, Ts) then
    x_err = x_target - x;
    i_raw = Kp_pos*x_err - Kd_pos*v + Ki_pos*pre(int_pos);
    i_cmd = if i_raw > Imax then Imax elseif i_raw < -Imax then -Imax else i_raw;
    int_pos = pre(int_pos) + Ts*x_err - Kaw_pos*(i_raw - i_cmd);

    i_err = i_cmd - i;
    v_raw = Kp_cur*i_err + Ki_cur*pre(int_cur);
    v_cmd = if v_raw > Vmax then Vmax elseif v_raw < -Vmax then -Vmax else v_raw;
    int_cur = pre(int_cur) + Ts*i_err - Kaw_cur*(v_raw - v_cmd);
  end when;

  // Bounds and no-NaN/infinite assertions
  assert(abs(v_cmd) <= Vmax + 1.0e-6, "voltage bound violated");
  assert(abs(i) <= I_bound + 1.0e-6, "current bound violated");
  assert(x >= -1.0e-4 and x <= L_travel + 1.0e-4, "travel bound violated");
  assert(T <= T_max + 1.0e-6, "temperature bound violated");
  assert(time <= t_check or final_error <= tracking_bound + 1.0e-6, "final/tracking error bound violated");
  assert(abs(i) < 1.0e20 and abs(x) < 1.0e20 and abs(v) < 1.0e20 and abs(T) < 1.0e20 and
         abs(theta_m) < 1.0e20 and abs(omega_m) < 1.0e20 and abs(v_cmd) < 1.0e20 and
         abs(i_cmd) < 1.0e20 and abs(int_pos) < 1.0e20 and abs(int_cur) < 1.0e20,
         "NaN/infinite physical/control/estimator value");

  annotation (experiment(StopTime = 14, Interval = 0.005, Tolerance = 1e-6));
end BallScrewPositionD;