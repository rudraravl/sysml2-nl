// Create a part called AvionicMotor. It uses electrical power to generate mechanical torque. It has three properties: rated power in kilowatts, nominal voltage in volts, and maximum speed in RPM.
package AvionicMotorModel {
    private import SI::*;
    private import ISQ::*;

    attribute <'rpm'> 'rotations per minute' : AngularSpeedUnit = 2 * pi * rad / min;

    part def AvionicMotor {
        attribute ratedPower :> ISQ::power { unit = kW; }
        attribute nominalVoltage :> ISQ::electricPotential { unit = V; }
        attribute maximumSpeed :> ISQ::angularSpeed { unit = 'rpm'; }
    }
}
