// Create a part called AvionicMotor. It uses electrical power to generate mechanical torque. It has three properties: rated power in kilowatts, nominal voltage in volts, and maximum speed in RPM.
```sysml
part AvionicMotor {
  flow electricalPower: ElectricalPower in;
  flow mechanicalTorque: MechanicalTorque out;
  attribute ratedPower: Power value kW;
  attribute nominalVoltage: Voltage value V;
  attribute maximumSpeed: RotationalSpeed value RPM;
}
```
