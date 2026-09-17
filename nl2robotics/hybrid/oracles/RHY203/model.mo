model BranchingJointController
  parameter Real left_kp(unit="N.m/rad") = 8.0;
  parameter Real left_kd(unit="N.m.s/rad") = 1.2;
  parameter Real left_target(unit="rad") = Modelica.Constants.pi / 12;
  parameter Real left_limit(unit="N.m") = 3.0;
  parameter Real right_kp(unit="N.m/rad") = 0.5;
  parameter Real right_kd(unit="N.m.s/rad") = 0.07;
  parameter Real right_target(unit="rad") = -Modelica.Constants.pi / 15;
  parameter Real right_limit(unit="N.m") = 0.15;
  parameter Real tool_kp(unit="N/m") = 40.0;
  parameter Real tool_kd(unit="N.s/m") = 6.0;
  parameter Real tool_target(unit="m") = 0.05;
  parameter Real tool_limit(unit="N") = 8.0;
  input Real leftPosition(unit="rad");
  input Real leftVelocity(unit="rad/s");
  output Real leftEffort(unit="N.m");
  input Real rightPosition(unit="rad");
  input Real rightVelocity(unit="rad/s");
  output Real rightEffort(unit="N.m");
  input Real toolPosition(unit="m");
  input Real toolVelocity(unit="m/s");
  output Real toolEffort(unit="N");
equation
  leftEffort = max(-left_limit, min(left_limit,
    left_kp * (left_target - leftPosition) - left_kd * leftVelocity));
  rightEffort = max(-right_limit, min(right_limit,
    right_kp * (right_target - rightPosition) - right_kd * rightVelocity));
  toolEffort = max(-tool_limit, min(tool_limit,
    tool_kp * (tool_target - toolPosition) - tool_kd * toolVelocity));
end BranchingJointController;
