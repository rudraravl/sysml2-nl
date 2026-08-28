package VariableReluctanceSensingUnit {

    import ScalarValues::*;

    // ---- Units ----
    attribute def RPM :> Real;
    attribute def V :> Real;
    attribute def mV :> Real;
    attribute def mm :> Real;
    attribute def Hz :> Real;
    attribute def kHz :> Real;
    attribute def dB :> Real;
    attribute def ms :> Real;

    // ---- Value types ----
    attribute def RotationalSpeed :> Real { unit RPM; }
    attribute def Voltage :> Real { unit V; }
    attribute def Millivoltage :> Real { unit mV; }
    attribute def AirGap :> Real { unit mm; }
    attribute def Frequency :> Real { unit Hz; }
    attribute def Gain :> Real;
    attribute def DutyCycle :> Real;
    attribute def ToothCount :> Integer;

    // ---- Items ----
    item def MagneticFlux {
        attribute magnitude : Real;
        attribute direction : String;
    }

    item def RawAnalogSignal {
        attribute amplitude : Millivoltage;
        attribute frequency : Frequency;
        attribute noiseLevel : Real;
    }

    item def AmplifiedSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
        attribute noiseLevel : Real;
    }

    item def FilteredSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
        attribute noiseLevel : Real;
    }

    item def DigitalSquareWave {
        attribute frequency : Frequency;
        attribute dutyCycle : DutyCycle;
        attribute highLevel : Voltage;
        attribute lowLevel : Voltage;
    }

    // ---- Ports ----
    port def MagneticInterface {
        out flux : MagneticFlux;
    }

    port def AnalogSignalPort {
        out signal : RawAnalogSignal;
    }

    port def AmplifiedSignalPort {
        out signal : AmplifiedSignal;
    }

    port def FilteredSignalPort {
        out signal : FilteredSignal;
    }

    port def DigitalSignalPort {
        out signal : DigitalSquareWave;
    }

    // ---- Toothed Target ----
    part def ToothedTarget {
        attribute teeth : ToothCount;
        attribute speed : RotationalSpeed;
        attribute material : String;
        port magneticInteraction : MagneticInterface;

        action def Rotate {
            out flux : MagneticFlux;
        }
        perform Rotate;
    }

    // ---- Variable Reluctance Sensor ----
    part def VariableReluctanceSensor {
        attribute airGap : AirGap;
        attribute coilTurns : Integer;
        attribute magnetStrength : Real;
        attribute sensitivity : Real;

        port targetInterface : MagneticInterface;
        port analogOut : AnalogSignalPort;

        action def SenseRotation {
            in flux : MagneticFlux;
            out signal : RawAnalogSignal;
        }

        action def InduceVoltage {
            in flux : MagneticFlux;
            out induced : Millivoltage;
        }

        perform SenseRotation {
            perform InduceVoltage;
        }
    }

    // ---- Signal Conditioner ----
    part def SignalConditioner {
        attribute gain : Gain;
        attribute lowCutoff : Frequency;
        attribute highCutoff : Frequency;
        attribute threshold : Voltage;

        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalSignalPort;

        action def Amplify {
            in raw : RawAnalogSignal;
            out amplified : AmplifiedSignal;
        }

        action def Filter {
            in noisy : AmplifiedSignal;
            out clean : FilteredSignal;
        }

        action def Digitize {
            in analog : FilteredSignal;
            out digital : DigitalSquareWave;
        }

        action def ConditionSignal {
            in raw : RawAnalogSignal;
            out digital : DigitalSquareWave;
            perform Amplify;
            perform Filter;
            perform Digitize;
        }

        perform ConditionSignal;
    }

    // ---- Operational State Machine ----
    state def OperationalStates {
        attribute motionDetected : Boolean;
        attribute motionStopped : Boolean;
        attribute anomalyDetected : Boolean;
        attribute resetCommand : Boolean;

        state idle {
            entry { status = "idle"; }
        }

        state sensing {
            entry { status = "sensing"; }
        }

        state fault {
            entry { status = "fault"; }
        }

        transition initial to idle;
        transition idle to sensing when motionDetected;
        transition sensing to idle when motionStopped;
        transition sensing to fault when anomalyDetected;
        transition idle to fault when anomalyDetected;
        transition fault to idle when resetCommand;
    }

    // ---- Top-level Assembly ----
    part VariableReluctanceSensingUnit {
        attribute measuredSpeed : RotationalSpeed;
        attribute status : String;
        attribute poweredOn : Boolean;

        part target : ToothedTarget {
            attribute teeth = 60;
            attribute speed = 0 [RPM];
            attribute material = "Steel";
        }

        part sensor : VariableReluctanceSensor {
            attribute airGap = 1.0 [mm];
            attribute coilTurns = 1500;
            attribute magnetStrength = 1.2;
            attribute sensitivity = 0.05;
        }

        part conditioner : SignalConditioner {
            attribute gain = 100.0;
            attribute lowCutoff = 10.0 [Hz];
            attribute highCutoff = 20.0 [kHz];
            attribute threshold = 0.5 [V];
        }

        connection magneticLink connect target.magneticInteraction to sensor.targetInterface;
        connection analogLink connect sensor.analogOut to conditioner.analogIn;

        exhibit OperationalStates;

        action def MeasureSpeed {
            in digital : DigitalSquareWave;
            out speed : RotationalSpeed;
        }
        perform MeasureSpeed;
    }

    // ---- Requirements ----
    requirement def SpeedMeasurementRequirement {
        subject unit : VariableReluctanceSensingUnit;
        attribute maxSpeed : RotationalSpeed = 6000 [RPM];
        requirement {
            unit.measuredSpeed <= maxSpeed;
        }
    }

    requirement def AirGapRequirement {
        subject sensor : VariableReluctanceSensor;
        attribute minGap : AirGap = 0.5 [mm];
        attribute maxGap : AirGap = 2.0 [mm];
        requirement {
            sensor.airGap >= minGap and sensor.airGap <= maxGap;
        }
    }

    requirement def SignalConditioningRequirement {
        subject conditioner : SignalConditioner;
        attribute minGain : Gain = 50.0;
        attribute maxGain : Gain = 500.0;
        requirement {
            conditioner.gain >= minGain and conditioner.gain <= maxGain;
        }
    }

    requirement def DigitalOutputRequirement {
        subject unit : VariableReluctanceSensingUnit;
        attribute highLevel : Voltage = 5.0 [V];
        attribute lowLevel : Voltage = 0.0 [V];
        requirement {
            unit.conditioner.digitalOut.signal.highLevel == highLevel and
            unit.conditioner.digitalOut.signal.lowLevel == lowLevel;
        }
    }

    requirement def OperationalStateRequirement {
        subject unit : VariableReluctanceSensingUnit;
        attribute validStates : String = "idle, sensing, fault";
        requirement {
            unit.status in {"idle", "sensing", "fault"};
        }
    }

    requirement def FaultRecoveryRequirement {
        subject unit : VariableReluctanceSensingUnit;
        requirement {
            unit.status == "fault" implies unit can transition to "idle" on resetCommand;
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction SpeedMeasurementRequirement by VariableReluctanceSensingUnit;
    satisfaction AirGapRequirement by VariableReluctanceSensingUnit::sensor;
    satisfaction SignalConditioningRequirement by VariableReluctanceSensingUnit::conditioner;
    satisfaction DigitalOutputRequirement by VariableReluctanceSensingUnit;
    satisfaction OperationalStateRequirement by VariableReluctanceSensingUnit;
    satisfaction FaultRecoveryRequirement by VariableReluctanceSensingUnit;

}
