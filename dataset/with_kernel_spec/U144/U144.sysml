package AlgerBrushModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def SwitchOn;
    attribute def SwitchOff;
    attribute def EyeContact;
    attribute def ExcessiveForce;

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
    }

    item def MechanicalRotation {
        attribute torque : TorqueValue;
        attribute speed : Real;
    }

    port def ElectricalPowerPort {
        out power : ElectricalPower;
    }

    port def MechanicalDrivePort {
        out rotation : MechanicalRotation;
    }

    action def SupplyPower {
        out power : ElectricalPower;
    }

    action def GenerateRotation {
        in power : ElectricalPower;
        out rotation : MechanicalRotation;
    }

    action def TransferRotation {
        in rotationIn : MechanicalRotation;
        out rotationOut : MechanicalRotation;
    }

    action def AbradeCornea {
        in rotation : MechanicalRotation;
    }

    action def StopMotor;

    action def OperateAlgerBrush {
        action supply : SupplyPower;
        flow supply.power to generate.power;
        action generate : GenerateRotation;
        flow generate.rotation to transfer.rotationIn;
        action transfer : TransferRotation;
        flow transfer.rotationOut to abrade.rotation;
        action abrade : AbradeCornea;
    }

    part def Housing {
        attribute gripDiameter : LengthValue;
        attribute material : String;
    }

    part def BatteryCell {
        attribute nominalVoltage : Real;
        attribute capacity : Real;
        out powerPort : ElectricalPowerPort;
    }

    part def ActivationSwitch {
        attribute isPressed : Boolean;
        in powerIn : ElectricalPowerPort;
        out powerOut : ElectricalPowerPort;
    }

    part def LowSpeedMotor {
        attribute maxTorque : TorqueValue;
        attribute stallTorque : TorqueValue;
        attribute currentTorque : TorqueValue;
        attribute nominalSpeed : Real;
        in powerIn : ElectricalPowerPort;
        out drivePort : MechanicalDrivePort;
    }

    part def ChuckAdapter {
        in driveIn : MechanicalDrivePort;
        out driveOut : MechanicalDrivePort;
    }

    part def OphthalmicBurr {
        attribute diameter : LengthValue;
        attribute gritSize : LengthValue;
        in driveIn : MechanicalDrivePort;
    }

    part def Cornea {
        attribute bowmanLayerResistance : TorqueValue;
        attribute surfaceResistance : TorqueValue;
    }

    state def AlgerBrushStates {
        in activationSwitch : ActivationSwitch;
        in motor : LowSpeedMotor;
        entry; then idle;
        state idle {
            accept SwitchOn
                if activationSwitch.isPressed
                then rotating;
        }
        state rotating {
            do action supplyPower : SupplyPower;
            accept EyeContact
                then abrading;
            accept SwitchOff
                then idle;
        }
        state abrading {
            do action abrade : AbradeCornea {
                in rotation = motor.drivePort.rotation;
            }
            accept ExcessiveForce
                if motor.currentTorque >= motor.stallTorque
                then stalled;
            accept SwitchOff
                then idle;
        }
        state stalled {
            entry action stopMotor : StopMotor;
            accept SwitchOff
                then idle;
        }
    }

    part def AlgerBrush {
        part housing : Housing;
        part battery : BatteryCell;
        part activationSwitch : ActivationSwitch;
        part motor : LowSpeedMotor;
        part chuck : ChuckAdapter;
        part burr : OphthalmicBurr;

        connect battery.powerPort to activationSwitch.powerIn;
        connect activationSwitch.powerOut to motor.powerIn;
        connect motor.drivePort to chuck.driveIn;
        connect chuck.driveOut to burr.driveIn;

        exhibit state operationalStates : AlgerBrushStates {
            in activationSwitch = activationSwitch;
            in motor = motor;
        }
    }

    requirement def LowTorqueSafetyRequirement {
        doc /* The motor shall stall when encountering the resistance of Bowman's layer to prevent deep drilling. */
        subject motor : LowSpeedMotor;
        subject patientCornea : Cornea;
        require constraint { motor.maxTorque < patientCornea.bowmanLayerResistance }
    }

    requirement def ErgonomicGripRequirement {
        doc /* The housing shall provide an ergonomic grip with a diameter between 10 and 15 mm. */
        subject housingPart : Housing;
        require constraint { housingPart.gripDiameter >= 10[mm] and housingPart.gripDiameter <= 15[mm] }
    }

    requirement def LowSpeedOperationRequirement {
        doc /* The motor shall operate at a low rotational speed suitable for precise superficial corneal abrasion. */
        subject motor : LowSpeedMotor;
        require constraint { motor.nominalSpeed <= 5000 }
    }
}
