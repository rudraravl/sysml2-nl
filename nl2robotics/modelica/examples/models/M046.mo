model CableDrivenJoint
  parameter Real driveTorque = 1.00;
  Real q1(start=0, fixed=true);
  Real w1(start=0, fixed=true);
  Real q2(start=0, fixed=true);
  Real w2(start=0, fixed=true);
  Real q3(start=0, fixed=true);
  Real w3(start=0, fixed=true);
  Real loadAngle;
  Real commonAngle;
  Real jointAngle;
  Real leftPosition;
  Real outputAngle;
equation
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  0.1 * der(w1) = driveTorque - 0.2 * w1 - 9.00 * (q1 - q2);
  0.25 * der(w2) = 9.00 * (q1 - q2) - 0.2 * w2 - 4.50 * (q2 - q3);
  0.4 * der(w3) = 4.50 * (q2 - q3) - 0.25 * w3;
  loadAngle = q3;
  commonAngle = (q1 + q2) / 2;
  jointAngle = q3;
  leftPosition = q2;
  outputAngle = q3 / 2;
end CableDrivenJoint;
