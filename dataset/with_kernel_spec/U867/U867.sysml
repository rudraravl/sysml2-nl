package SeismometerSystem {
    private import ScalarValues::*;

    attribute def AccelerationValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def TimeValue :> Real;
    attribute def MassValue :> Real;
    attribute def EnergyValue :> Real;

    item def GroundMotion {
        attribute acceleration : AccelerationValue;
    }
    item def AnalogSignal {
        attribute voltage : VoltageValue;
    }
    attribute def DigitalSample {
        attribute value : Integer;
        attribute timestamp : Real;
    }
    item def SeismicEvent {
        attribute id : String;
        attribute magnitude : Real;
        attribute peakAcceleration : AccelerationValue;
        attribute duration : TimeValue;
        attribute samples : DigitalSample[*];
    }

    attribute def StartMonitoring;
    attribute def StopMonitoring;
    attribute def Reset;
    attribute def SystemFault;
    attribute def EventDetected;
    attribute def RecordingComplete;
    attribute def TransmissionComplete;

    port def GroundMotionPort {
        in motion : GroundMotion;
    }
    port def AnalogInPort {
        in signal : AnalogSignal;
    }
    port def AnalogOutPort {
        out signal : AnalogSignal;
    }
    port def DigitalInPort {
        in data : DigitalSample[*];
    }
    port def DigitalOutPort {
        out data : DigitalSample[*];
    }
    port def EventInPort {
        in evt : SeismicEvent;
    }
    port def EventOutPort {
        out evt : SeismicEvent;
    }
    port def NetworkOutPort {
        out evt : SeismicEvent;
    }
    port def ControlPort {
        in startCmd : StartMonitoring;
        in stopCmd : StopMonitoring;
        in resetCmd : Reset;
    }
    port def PowerInPort {
        in voltage : VoltageValue;
        in current : Real;
    }
    port def PowerOutPort {
        out voltage : VoltageValue;
        out current : Real;
    }

    action def SenseGroundMotion {
        in motion : GroundMotion;
        out signal : AnalogSignal;
    }
    action def AmplifySignal {
        in inSignal : AnalogSignal;
        out outSignal : AnalogSignal;
    }
    action def ConvertToDigital {
        in inSignal : AnalogSignal;
        out outData : DigitalSample[*];
    }
    action def AnalyzeData {
        in digital : DigitalSample[*];
        out evt : SeismicEvent;
        out detected : Boolean;
    }
    action def RecordEvent {
        in evt : SeismicEvent;
    }
    action def TransmitEvent {
        in evt : SeismicEvent;
    }
    action def SupplyPower;
    action def EnterStandby;
    action def LogError;

    part def TransducerAssembly {
        attribute inertialMass : MassValue;
        attribute sensitivity : Real;
        port groundIn : GroundMotionPort;
        port analogOut : AnalogOutPort;
        port powerIn : PowerInPort;
        perform action sense : SenseGroundMotion;
    }

    part def Amplifier {
        attribute gain : Real;
        attribute noiseFloor : VoltageValue;
        port analogIn : AnalogInPort;
        port analogOut : AnalogOutPort;
        port powerIn : PowerInPort;
        perform action amplify : AmplifySignal;
    }

    part def AnalogDigitalConverter {
        attribute samplingRate : FrequencyValue;
        attribute resolution : Integer;
        port analogIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        port powerIn : PowerInPort;
        perform action convert : ConvertToDigital;
    }

    part def SignalProcessor {
        attribute detectionThreshold : AccelerationValue;
        port digitalIn : DigitalInPort;
        port eventOut : EventOutPort;
        port powerIn : PowerInPort;
        perform action analyze : AnalyzeData;
    }

    part def DataStorage {
        attribute capacity : Real;
        attribute retentionDays : Integer := 30;
        port eventIn : EventInPort;
        port powerIn : PowerInPort;
        perform action record : RecordEvent;
        assert constraint { retentionDays >= 30 }
    }

    part def CommunicationInterface {
        attribute protocol : String;
        attribute destination : String;
        port eventIn : EventInPort;
        port networkOut : NetworkOutPort;
        port powerIn : PowerInPort;
        perform action transmit : TransmitEvent;
    }

    part def PowerSupply {
        attribute batteryCapacity : EnergyValue;
        attribute outputVoltage : VoltageValue;
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        perform action supply : SupplyPower;
    }

    part def Seismometer {
        port groundPort : GroundMotionPort;
        port commandPort : ControlPort;
        port networkPort : NetworkOutPort;
        port powerPort : PowerInPort;

        part transducer : TransducerAssembly;
        part amplifier : Amplifier;
        part adc : AnalogDigitalConverter;
        part processor : SignalProcessor;
        part storage : DataStorage;
        part comm : CommunicationInterface;
        part powerSupply : PowerSupply;

        connect groundPort to transducer.groundIn;
        connect transducer.analogOut to amplifier.analogIn;
        connect amplifier.analogOut to adc.analogIn;
        connect adc.digitalOut to processor.digitalIn;
        connect processor.eventOut to storage.eventIn;
        connect processor.eventOut to comm.eventIn;
        connect comm.networkOut to networkPort;
        connect powerPort to powerSupply.powerIn;
        connect powerSupply.powerOut to transducer.powerIn;
        connect powerSupply.powerOut to amplifier.powerIn;
        connect powerSupply.powerOut to adc.powerIn;
        connect powerSupply.powerOut to processor.powerIn;
        connect powerSupply.powerOut to storage.powerIn;
        connect powerSupply.powerOut to comm.powerIn;

        exhibit state operationalStates {
            entry; then standby;
            state standby {
                entry action EnterStandby;
            }
            state active;
            state recording;
            state transmitting;
            state fault {
                entry action LogError;
            }
            transition first standby accept StartMonitoring via commandPort then active;
            transition first active accept EventDetected then recording;
            transition first recording accept RecordingComplete then transmitting;
            transition first transmitting accept TransmissionComplete then active;
            transition first active accept StopMonitoring via commandPort then standby;
            transition first active accept SystemFault then fault;
            transition first fault accept Reset via commandPort then standby;
        }
    }

    requirement def SensitivityRequirementDef {
        doc /* The seismometer shall detect ground accelerations of at least 1e-6 m/s^2. */
    }
    requirement def StorageRetentionRequirementDef {
        doc /* The data storage shall retain at least 30 days of continuous seismic data. */
    }
    requirement def EventDetectionRequirementDef {
        doc /* The system shall detect and record significant seismic events. */
    }
    requirement def EarlyWarningRequirementDef {
        doc /* The system shall transmit event data to a central monitoring station within 2 seconds of detection. */
    }
    requirement def PowerAutonomyRequirementDef {
        doc /* The power supply shall sustain operation for at least 30 days without external recharge. */
    }

    part seismometer : Seismometer;

    requirement sensitivityRequirement : SensitivityRequirementDef;
    requirement storageRetentionRequirement : StorageRetentionRequirementDef;
    requirement eventDetectionRequirement : EventDetectionRequirementDef;
    requirement earlyWarningRequirement : EarlyWarningRequirementDef;
    requirement powerAutonomyRequirement : PowerAutonomyRequirementDef;

    satisfy sensitivityRequirement by seismometer.transducer;
    satisfy storageRetentionRequirement by seismometer.storage;
    satisfy eventDetectionRequirement by seismometer.processor;
    satisfy earlyWarningRequirement by seismometer.comm;
    satisfy powerAutonomyRequirement by seismometer.powerSupply;
}
