package MicrowaveRadiometerSystem {

    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit def Kelvin;
    unit def Volt;
    unit def Watt;
    unit def Gigahertz;
    unit def Second;
    unit def Decibel;
    unit def Radian;

    // ===== Value Type Definitions =====
    value def BrightnessTemperature :> Real { unit Kelvin; }
    value def PhysicalTemperature :> Real { unit Kelvin; }
    value def Voltage :> Real { unit Volt; }
    value def Power :> Real { unit Watt; }
    value def Frequency :> Real { unit Gigahertz; }
    value def Duration :> Real { unit Second; }
    value def GainValue :> Real { unit Decibel; }
    value def Angle :> Real { unit Radian; }

    // ===== Item Definitions =====
    item def MicrowaveRadiation {
        attribute frequency : Frequency;
        attribute power : Power;
        attribute brightnessTemp : BrightnessTemperature;
    }

    item def AmplifiedSignal {
        attribute frequency : Frequency;
        attribute power : Power;
    }

    item def DetectedVoltage {
        attribute voltage : Voltage;
    }

    item def IntegratedVoltage {
        attribute voltage : Voltage;
        attribute integrationTime : Duration;
    }

    item def TemperatureMeasurement {
        attribute brightnessTemp : BrightnessTemperature;
        attribute timestamp : Duration;
    }

    item def CalibrationData {
        attribute hotLoadTemp : PhysicalTemperature;
        attribute coldLoadTemp : PhysicalTemperature;
        attribute hotLoadVoltage : Voltage;
        attribute coldLoadVoltage : Voltage;
    }

    item def StatusMessage {
        attribute status : String;
        attribute timestamp : Duration;
    }

    // ===== Port Definitions =====
    port def MicrowavePort {
        out item radiation : MicrowaveRadiation;
    }

    port def SignalPort {
        out item signal : AmplifiedSignal;
    }

    port def VoltagePort {
        out item voltage : DetectedVoltage;
    }

    port def IntegratedVoltagePort {
        out item integratedVoltage : IntegratedVoltage;
    }

    port def MeasurementPort {
        out item measurement : TemperatureMeasurement;
    }

    port def CalibrationPort {
        out item calibrationRef : MicrowaveRadiation;
    }

    port def StatusPort {
        out item status : StatusMessage;
    }

    // ===== Action Definitions =====
    action def CollectRadiation {
        in item incoming : MicrowaveRadiation;
        out item collected : MicrowaveRadiation;
    }

    action def AmplifyAndFilter {
        in item input : MicrowaveRadiation;
        out item output : AmplifiedSignal;
    }

    action def DetectPower {
        in item input : AmplifiedSignal;
        out item output : DetectedVoltage;
    }

    action def IntegrateVoltage {
        in item input : DetectedVoltage;
        out item output : IntegratedVoltage;
    }

    action def ComputeBrightnessTemperature {
        in item integratedVoltage : IntegratedVoltage;
        in item calibrationData : CalibrationData;
        out item measurement : TemperatureMeasurement;
    }

    action def RunCalibration {
        in item hotRef : MicrowaveRadiation;
        in item coldRef : MicrowaveRadiation;
        out item calibrationData : CalibrationData;
    }

    action def PerformSelfTest {
        out item testPassed : Boolean;
    }

    action def MeasureScene {
        in item sceneRadiation : MicrowaveRadiation;
        out item measurement : TemperatureMeasurement;
    }

    action def ProvideCalibrationReferences {
        out item hotRef : MicrowaveRadiation;
        out item coldRef : MicrowaveRadiation;
    }

    // ===== Subsystem Definitions =====
    part def AntennaSubsystem {
        attribute apertureEfficiency : Real;
        attribute beamWidth : Angle;
        attribute pointingDirection : Angle;

        port microwaveIn : ~MicrowavePort;
        port microwaveOut : MicrowavePort;

        action collectRadiation : CollectRadiation;
    }

    part def ReceiverSubsystem {
        attribute gain : GainValue;
        attribute centerFrequency : Frequency;
        attribute bandwidth : Frequency;
        attribute noiseFigure : Real;

        port signalIn : ~MicrowavePort;
        port signalOut : SignalPort;

        action amplifyAndFilter : AmplifyAndFilter;
    }

    part def DetectorSubsystem {
        attribute sensitivity : Real;
        attribute linearity : Real;

        port detectorIn : ~SignalPort;
        port detectorOut : VoltagePort;

        action detectPower : DetectPower;
    }

    part def IntegratorSubsystem {
        attribute integrationTime : Duration;

        port integratorIn : ~VoltagePort;
        port integratorOut : IntegratedVoltagePort;

        action integrateVoltage : IntegrateVoltage;
    }

    part def ProcessorSubsystem {
        attribute algorithmVersion : String;
        attribute calibrationInterval : Duration;

        port processorIn : ~IntegratedVoltagePort;
        port measurementOut : MeasurementPort;
        port statusOut : StatusPort;

        action computeBrightnessTemperature : ComputeBrightnessTemperature;
        action runCalibration : RunCalibration;
        action performSelfTest : PerformSelfTest;
    }

    part def CalibrationSubsystem {
        attribute hotLoadTemp : PhysicalTemperature;
        attribute coldLoadTemp : PhysicalTemperature;

        port calibrationOut : CalibrationPort;

        part hotLoad {
            attribute temperature : PhysicalTemperature;
        }

        part coldLoad {
            attribute temperature : PhysicalTemperature;
        }

        action provideCalibrationReferences : ProvideCalibrationReferences;
    }

    // ===== State Machine Definition =====
    state def OperationalStates {
        initial first PoweredOff;

        state PoweredOff {
            entry action powerOffEntry;
        }

        transition powerOn first PoweredOff then Initializing {
            guard powerOnCommandReceived;
        }

        state Initializing {
            entry action initEntry;
            do action performSelfTestAction : PerformSelfTest;
        }

        transition initComplete first Initializing then Calibrating {
            guard selfTestPassed;
        }

        state Calibrating {
            entry action calibEntry;
            do action runCalibrationAction : RunCalibration;
        }

        transition calibComplete first Calibrating then Measuring {
            guard calibrationDone;
        }

        state Measuring {
            entry action measureEntry;
            do action measureSceneAction : MeasureScene;
        }

        transition recalibrate first Measuring then Calibrating {
            guard calibrationIntervalElapsed;
        }

        transition powerOffCommand first Measuring then PoweredOff {
            guard shutdownCommandReceived;
        }
    }

    // ===== Main System Definition =====
    part def MicrowaveRadiometer {
        attribute instrumentId : String;
        attribute operationalStatus : String;

        port sceneInput : ~MicrowavePort;
        port dataOutput : MeasurementPort;
        port statusOutput : StatusPort;

        part antenna : AntennaSubsystem {
            attribute apertureEfficiency = 0.7;
            attribute beamWidth = 0.02;
            attribute pointingDirection = 0.0;
        }

        part receiver : ReceiverSubsystem {
            attribute gain = 80.0;
            attribute centerFrequency = 36.5;
            attribute bandwidth = 0.4;
            attribute noiseFigure = 3.5;
        }

        part detector : DetectorSubsystem {
            attribute sensitivity = 1000.0;
            attribute linearity = 0.99;
        }

        part integrator : IntegratorSubsystem {
            attribute integrationTime = 1.0;
        }

        part processor : ProcessorSubsystem {
            attribute algorithmVersion = "v2.1";
            attribute calibrationInterval = 300.0;
        }

        part calibration : CalibrationSubsystem {
            attribute hotLoadTemp = 300.0;
            attribute coldLoadTemp = 2.7;
        }

        // Connections
        connection sceneToAntenna connect sceneInput to antenna.microwaveIn;
        connection antennaToReceiver connect antenna.microwaveOut to receiver.signalIn;
        connection receiverToDetector connect receiver.signalOut to detector.detectorIn;
        connection detectorToIntegrator connect detector.detectorOut to integrator.integratorIn;
        connection integratorToProcessor connect integrator.integratorOut to processor.processorIn;
        connection processorToOutput connect processor.measurementOut to dataOutput;
        connection calibrationToAntenna connect calibration.calibrationOut to antenna.microwaveIn;
        connection statusToOutput connect processor.statusOut to statusOutput;

        // State machine
        exhibit state operationalState : OperationalStates;

        // Requirement satisfactions
        satisfy radiometerFunctionalRequirement by this;
        satisfy antennaRequirement by antenna;
        satisfy receiverRequirement by receiver;
        satisfy detectorRequirement by detector;
        satisfy integratorRequirement by integrator;
        satisfy processorRequirement by processor;
        satisfy calibrationRequirement by calibration;
        satisfy operationalCycleRequirement by this;
    }

    // ===== Requirement Definitions =====
    requirement def RadiometerFunctionalRequirement {
        attribute id : String = "REQ-001";
        attribute text : String = "The Microwave Radiometer System shall passively measure the brightness temperature of a target scene.";
        attribute measurementAccuracy : BrightnessTemperature = 1.0;
    }

    requirement def AntennaRequirement {
        attribute id : String = "REQ-002";
        attribute text : String = "The Antenna Subsystem shall collect microwave radiation from the target scene and direct it to the receiver.";
        attribute minFrequency : Frequency = 1.0;
        attribute maxFrequency : Frequency = 200.0;
        attribute minApertureEfficiency : Real = 0.5;
    }

    requirement def ReceiverRequirement {
        attribute id : String = "REQ-003";
        attribute text : String = "The Receiver Subsystem shall amplify and filter the microwave signal to a usable power level.";
        attribute minGain : GainValue = 60.0;
        attribute maxNoiseFigure : Real = 5.0;
    }

    requirement def DetectorRequirement {
        attribute id : String = "REQ-004";
        attribute text : String = "The Detector Subsystem shall convert microwave power to a DC voltage proportional to signal strength.";
        attribute minLinearity : Real = 0.95;
    }

    requirement def IntegratorRequirement {
        attribute id : String = "REQ-005";
        attribute text : String = "The Integrator Subsystem shall average the detector voltage over a specified integration time to improve measurement precision.";
        attribute minIntegrationTime : Duration = 0.5;
    }

    requirement def ProcessorRequirement {
        attribute id : String = "REQ-006";
        attribute text : String = "The Processor Subsystem shall convert integrated voltage to brightness temperature using calibration data and shall manage overall instrument operation.";
    }

    requirement def CalibrationRequirement {
        attribute id : String = "REQ-007";
        attribute text : String = "The Calibration Subsystem shall provide hot and cold reference loads with known physical temperatures for periodic calibration.";
        attribute hotLoadTemp : PhysicalTemperature = 300.0;
        attribute coldLoadTemp : PhysicalTemperature = 2.7;
    }

    requirement def OperationalCycleRequirement {
        attribute id : String = "REQ-008";
        attribute text : String = "The system shall follow an operational cycle: power on, perform self-test, calibrate using hot and cold loads, measure the target scene, and periodically recalibrate.";
        attribute maxCalibrationInterval : Duration = 300.0;
    }

    // ===== Requirement Usages =====
    requirement radiometerFunctionalRequirement : RadiometerFunctionalRequirement;
    requirement antennaRequirement : AntennaRequirement;
    requirement receiverRequirement : ReceiverRequirement;
    requirement detectorRequirement : DetectorRequirement;
    requirement integratorRequirement : IntegratorRequirement;
    requirement processorRequirement : ProcessorRequirement;
    requirement calibrationRequirement : CalibrationRequirement;
    requirement operationalCycleRequirement : OperationalCycleRequirement;
}
