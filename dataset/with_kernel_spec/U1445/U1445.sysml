package 'Precision Magnetic Field Control System' {
    private import ScalarValues::*;

    attribute def Tesla;
    attribute def Ampere;
    attribute def Second;

    attribute def MagneticFieldStrength :> ScalarValues::Real;
    attribute def ElectricCurrent :> ScalarValues::Real;
    attribute def TimeValue :> ScalarValues::Real;

    item def MagneticFieldVector {
        attribute strength : MagneticFieldStrength;
        attribute x : MagneticFieldStrength;
        attribute y : MagneticFieldStrength;
        attribute z : MagneticFieldStrength;
    }

    item def FieldReading {
        attribute field : MagneticFieldVector;
        attribute timestamp : TimeValue;
    }

    item def TargetField {
        attribute field : MagneticFieldVector;
    }

    item def CurrentCommand {
        attribute current : ElectricCurrent;
    }

    port def PowerOutputPort {
        out powerCurrent : ElectricCurrent;
    }
    port def PowerInputPort {
        in powerCurrent : ElectricCurrent;
    }
    port def FieldOutputPort {
        out field : MagneticFieldVector;
    }
    port def FieldInputPort {
        in field : MagneticFieldVector;
    }
    port def ReadingOutputPort {
        out reading : FieldReading;
    }
    port def ReadingInputPort {
        in reading : FieldReading;
    }
    port def CommandOutputPort {
        out command : CurrentCommand;
    }
    port def CommandInputPort {
        in command : CurrentCommand;
    }
    port def TargetOutputPort {
        out target : TargetField;
    }
    port def TargetInputPort {
        in target : TargetField;
    }

    part def Electromagnet {
        port powerIn : PowerInputPort;
        port controlIn : CommandInputPort;
        port fieldOut : FieldOutputPort;
        attribute fieldGain : ScalarValues::Real = 0.01;
    }

    part def PowerSupply {
        port powerOut : PowerOutputPort;
        attribute maxCurrent : ElectricCurrent = 1000.0;
    }

    part def FieldSensor {
        port fieldIn : FieldInputPort;
        port readingOut : ReadingOutputPort;
        attribute samplingInterval : TimeValue = 0.001;
    }

    part def FieldController {
        port targetIn : TargetInputPort;
        port sensorIn : ReadingInputPort;
        port commandOut : CommandOutputPort;
        attribute tolerance : MagneticFieldStrength = 0.0001;
        attribute maxCurrent : ElectricCurrent = 1000.0;
        attribute currentGain : ScalarValues::Real = 0.01;
        attribute adjustmentGain : ScalarValues::Real = 0.5;

        state machine ControllerStateMachine {
            state idle;
            state energizing;
            state stable;
            state adjusting;
            state deenergizing;

            transition initial to idle;
            transition idle to energizing;
            transition energizing to stable;
            transition stable to adjusting;
            transition adjusting to stable;
            transition stable to deenergizing;
            transition energizing to deenergizing;
            transition adjusting to deenergizing;
            transition deenergizing to idle;
        }
    }

    part def ShieldingEnclosure {
        attribute attenuation : ScalarValues::Real = 60.0;
        part electromagnet : Electromagnet;
        part powerSupply : PowerSupply;
        part fieldSensor : FieldSensor;
        part fieldController : FieldController;

        flow powerFlow of ElectricCurrent
            from powerSupply.powerOut.powerCurrent to electromagnet.powerIn.powerCurrent;
        flow fieldFlow of MagneticFieldVector
            from electromagnet.fieldOut.field to fieldSensor.fieldIn.field;
        flow readingFlow of FieldReading
            from fieldSensor.readingOut.reading to fieldController.sensorIn.reading;
        flow commandFlow of CurrentCommand
            from fieldController.commandOut.command to electromagnet.controlIn.command;
    }

    part def MagneticFieldControlSystem {
        port targetIn : TargetInputPort;
        part enclosure : ShieldingEnclosure;
        flow targetFlow of TargetField
            from targetIn.target to enclosure.fieldController.targetIn.target;
    }

    part magneticFieldControlSystem : MagneticFieldControlSystem;

    requirement def FieldStabilityRequirement {
        doc /* The system shall maintain the magnetic field strength within 0.01 percent of the target value during stable operation. */
        attribute tolerance : MagneticFieldStrength = 0.0001;
    }

    requirement def ShieldingEffectivenessRequirement {
        doc /* The shielding enclosure shall attenuate external magnetic interference by at least 60 dB. */
        attribute minAttenuation : ScalarValues::Real = 60.0;
    }

    requirement def SafeRampDownRequirement {
        doc /* The system shall deenergize the magnet safely, ramping current down to zero within 10 seconds. */
        attribute maxRampDownTime : TimeValue = 10.0;
    }

    satisfy fieldStabilitySatisfaction {
        satisfyingPart : magneticFieldControlSystem;
        satisfiedRequirement : FieldStabilityRequirement;
    }

    satisfy shieldingSatisfaction {
        satisfyingPart : magneticFieldControlSystem.enclosure;
        satisfiedRequirement : ShieldingEffectivenessRequirement;
    }

    satisfy safeRampDownSatisfaction {
        satisfyingPart : magneticFieldControlSystem;
        satisfiedRequirement : SafeRampDownRequirement;
    }
}
