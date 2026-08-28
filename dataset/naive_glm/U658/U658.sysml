package ElectrochemicalFatigueCrackSensingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def Voltage :> Real { unit 'V'; }
    value def Resistance :> Real { unit 'Ohm'; }
    value def Current :> Real { unit 'A'; }
    value def LengthMeasure :> Real { unit 'mm'; }
    value def CrackDepth :> LengthMeasure;
    value def CrackLength :> LengthMeasure;
    value def GrowthRate :> Real { unit 'mm/cycle'; }
    value def TimeSeconds :> Real { unit 's'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Gain :> Real { unit 'dB'; }

    // ---- Item Definitions ----
    item def Electrolyte {
        attribute conductivity : Real { unit 'S/m'; }
        attribute pHLevel : Real;
        attribute volume : Real { unit 'mL'; }
    }

    item def ElectrodeArray {
        attribute electrodeCount : Integer;
        attribute electrodeSpacing : LengthMeasure;
        attribute material : String = "Platinum";
        attribute diameter : LengthMeasure;
    }

    item def TestComponent {
        attribute material : String;
        attribute surfaceArea : Real { unit 'mm^2'; }
        attribute thickness : LengthMeasure;
    }

    item def RawSignal {
        attribute resistance : Resistance;
        attribute appliedVoltage : Voltage;
        attribute measuredCurrent : Current;
        attribute timestamp : TimeSeconds;
        attribute electrodePairId : Integer;
    }

    item def ConditionedSignal {
        attribute resistance : Resistance;
        attribute amplifiedVoltage : Voltage;
        attribute gain : Gain;
        attribute timestamp : TimeSeconds;
        attribute noiseLevel : Resistance;
    }

    item def DigitalData {
        attribute resistanceValue : Resistance;
        attribute sampleId : Integer;
        attribute timestamp : TimeSeconds;
        attribute resolutionBits : Integer;
        attribute samplingRate : Frequency;
    }

    item def CrackMeasurement {
        attribute depth : CrackDepth;
        attribute length : CrackLength;
        attribute growthRate : GrowthRate;
        attribute timestamp : TimeSeconds;
        attribute locationId : Integer;
        attribute confidence : Real;
    }

    item def CalibrationData {
        attribute depthFactor : Real;
        attribute lengthFactor : Real;
        attribute baselineResistance : Resistance;
        attribute calibrationDate : String;
    }

    item def FaultReport {
        attribute faultCode : Integer;
        attribute description : String;
        attribute timestamp : TimeSeconds;
        attribute severity : Integer;
    }

    // ---- Requirements ----
    requirement def DetectFatigueCracks {
        doc "The system shall detect the presence of fatigue cracks on the surface of structural components.";
        attribute minDetectableDepth : CrackDepth = 0.05;
        attribute minDetectableLength : CrackLength = 0.5;
    }

    requirement def MeasureCrackCharacteristics {
        doc "The system shall calculate precise depth, length, and growth rate of detected cracks.";
        attribute depthAccuracy : Real = 0.1;
        attribute lengthAccuracy : Real = 0.2;
        attribute growthRateAccuracy : Real = 0.01;
    }

    requirement def ContinuousMonitoring {
        doc "The system shall continuously compare current resistance readings to a known baseline.";
        attribute samplingRate : Frequency = 100.0;
        attribute baselineTolerance : Resistance = 0.1;
    }

    requirement def SafeOperation {
        doc "The system shall include fault detection and shutdown procedures for safe and reliable operation.";
        attribute maxFaultResponseTime : TimeSeconds = 2.0;
    }

    requirement def SignalIntegrity {
        doc "The signal conditioner shall amplify raw signals and filter electrical noise before digitization.";
        attribute minGain : Gain = 40.0;
        attribute maxNoiseFloor : Resistance = 0.001;
    }

    // ---- Port Definitions ----
    port def RawSignalOutPort {
        out rawSignal : RawSignal;
    }

    port def RawSignalInPort {
        in rawSignal : RawSignal;
    }

    port def ConditionedSignalOutPort {
        out conditionedSignal : ConditionedSignal;
    }

    port def ConditionedSignalInPort {
        in conditionedSignal : ConditionedSignal;
    }

    port def DigitalDataOutPort {
        out digitalData : DigitalData;
    }

    port def DigitalDataInPort {
        in digitalData : DigitalData;
    }

    port def MeasurementResultOutPort {
        out crackMeasurement : CrackMeasurement;
    }

    port def PowerOutPort {
        out supplyVoltage : Voltage;
        out supplyCurrent : Current;
    }

    port def PowerInPort {
        in supplyVoltage : Voltage;
        in supplyCurrent : Current;
    }

    port def CommandInPort {
        in command : String;
    }

    port def FaultOutPort {
        out faultReport : FaultReport;
    }

    // ---- Part Definitions ----
    part def MeasurementCircuit {
        port powerPort : PowerInPort;
        port signalOutPort : RawSignalOutPort;
        port faultPort : FaultOutPort;

        attribute appliedVoltage : Voltage = 0.5;
        attribute measurementRange : Resistance = 100.0;
        attribute accuracy : Real = 0.01;

        action def ApplyVoltage {
            out voltage : Voltage;
        }

        action def MeasureResistance {
            in appliedVoltage : Voltage;
            out rawSignal : RawSignal;
        }

        action def PerformMeasurementSequence {
            out rawSignal : RawSignal;
            then ApplyVoltage;
            then MeasureResistance;
        }
    }

    part def SensingUnit {
        port commandPort : CommandInPort;
        port signalOutPort : RawSignalOutPort;
        port powerPort : PowerInPort;
        port faultPort : FaultOutPort;

        part electrodeArray : ElectrodeArray {
            attribute electrodeCount : Integer = 16;
            attribute electrodeSpacing : LengthMeasure = 2.0;
            attribute diameter : LengthMeasure = 0.5;
        }

        part electrolyte : Electrolyte {
            attribute conductivity : Real = 5.8;
            attribute pHLevel : Real = 7.0;
            attribute volume : Real = 10.0;
        }

        part measurementCircuit : MeasurementCircuit;

        attribute baselineResistance : Resistance;
        attribute currentResistance : Resistance;
        attribute resistanceThreshold : Resistance = 0.5;

        action def AcquireRawMeasurement {
            in testComponent : TestComponent;
            out rawSignal : RawSignal;
            perform measurementCircuit.PerformMeasurementSequence;
        }

        action def EstablishBaseline {
            out baseline : Resistance;
        }

        action def CompareToBaseline {
            in currentReading : Resistance;
            in baseline : Resistance;
            out deviation : Resistance;
        }
    }

    part def SignalConditioner {
        port inputPort : RawSignalInPort;
        port outputPort : ConditionedSignalOutPort;
        port powerPort : PowerInPort;

        attribute gain : Gain = 80.0;
        attribute lowCutoff : Frequency = 10.0;
        attribute highCutoff : Frequency = 5000.0;
        attribute noiseFloor : Resistance = 0.0005;

        action def Amplify {
            in rawSignal : RawSignal;
            out amplifiedSignal : ConditionedSignal;
        }

        action def FilterNoise {
            in amplifiedSignal : ConditionedSignal;
            out filteredSignal : ConditionedSignal;
        }

        action def ConditionSignal {
            in rawSignal : RawSignal;
            out conditionedSignal : ConditionedSignal;
            then Amplify;
            then FilterNoise;
        }
    }

    part def DataAcquisitionModule {
        port inputPort : ConditionedSignalInPort;
        port outputPort : DigitalDataOutPort;
        port powerPort : PowerInPort;

        attribute samplingRate : Frequency = 10000.0;
        attribute resolutionBits : Integer = 16;
        attribute inputRange : Voltage = 10.0;

        action def SampleAndHold {
            in conditionedSignal : ConditionedSignal;
            out sampledValue : Real;
        }

        action def Convert {
            in sampledValue : Real;
            out digitalData : DigitalData;
        }

        action def PerformAcquisition {
            in conditionedSignal : ConditionedSignal;
            out digitalData : DigitalData;
            then SampleAndHold;
            then Convert;
        }
    }

    part def CrackAnalysisProcessor {
        port inputPort : DigitalDataInPort;
        port resultPort : MeasurementResultOutPort;
        port powerPort : PowerInPort;
        port faultPort : FaultOutPort;

        attribute calibrationData : CalibrationData;
        attribute previousMeasurements : CrackMeasurement[0..*];
        attribute maxStoredMeasurements : Integer = 1000;

        action def CalculateDepth {
            in digitalData : DigitalData;
            in calibrationFactor : Real;
            out depth : CrackDepth;
        }

        action def CalculateLength {
            in digitalData : DigitalData;
            in calibrationFactor : Real;
            out length : CrackLength;
        }

        action def CalculateGrowthRate {
            in currentMeasurement : CrackMeasurement;
            in previousMeasurement : CrackMeasurement;
            out growthRate : GrowthRate;
        }

        action def AnalyzeCrack {
            in digitalData : DigitalData;
            in calibration : CalibrationData;
            out crackMeasurement : CrackMeasurement;
            then CalculateDepth;
            then CalculateLength;
            then CalculateGrowthRate;
        }
    }

    part def RegulatedPowerSupply {
        port outputPort : PowerOutPort;
        port faultPort : FaultOutPort;

        attribute outputVoltage : Voltage = 12.0;
        attribute maxCurrent : Current = 5.0;
        attribute efficiency : Real = 0.92;
        attribute temperatureThreshold : Temperature = 80.0;
        attribute currentTemperature : Temperature;

        action def RegulateVoltage {
            out regulatedVoltage : Voltage;
        }

        action def MonitorTemperature {
            out temperature : Temperature;
        }

        action def ShutdownPower {
            out faultReport : FaultReport;
        }
    }

    // ---- Top-Level System ----
    part def ElectrochemicalFatigueCrackSensingSystem {
        port commandPort : CommandInPort;
        port resultPort : MeasurementResultOutPort;
        port faultPort : FaultOutPort;

        part sensingUnit : SensingUnit;
        part signalConditioner : SignalConditioner;
        part dataAcquisition : DataAcquisitionModule;
        part crackProcessor : CrackAnalysisProcessor;
        part powerSupply : RegulatedPowerSupply;

        // Signal flow connections
        connection rawSignalFlow connect sensingUnit.signalOutPort to signalConditioner.inputPort;
        connection conditionedSignalFlow connect signalConditioner.outputPort to dataAcquisition.inputPort;
        connection digitalDataFlow connect dataAcquisition.outputPort to crackProcessor.inputPort;
        connection resultFlow connect crackProcessor.resultPort to resultPort;

        // Power distribution connections
        connection powerToSensing connect powerSupply.outputPort to sensingUnit.powerPort;
        connection powerToConditioner connect powerSupply.outputPort to signalConditioner.powerPort;
        connection powerToDAQ connect powerSupply.outputPort to dataAcquisition.powerPort;
        connection powerToProcessor connect powerSupply.outputPort to crackProcessor.powerPort;
        connection powerToMeasurementCircuit connect powerSupply.outputPort to sensingUnit.measurementCircuit.powerPort;

        // Command connection
        connection commandFlow connect commandPort to sensingUnit.commandPort;

        // Fault aggregation connections
        connection sensingFault connect sensingUnit.faultPort to faultPort;
        connection processorFault connect crackProcessor.faultPort to faultPort;
        connection powerFault connect powerSupply.faultPort to faultPort;

        // Requirements satisfaction
        satisfy DetectFatigueCracks by sensingUnit;
        satisfy MeasureCrackCharacteristics by crackProcessor;
        satisfy ContinuousMonitoring by sensingUnit;
        satisfy SafeOperation by self;
        satisfy SignalIntegrity by signalConditioner;

        // Operational state attributes
        attribute selfTestPassed : Boolean = false;
        attribute measurementComplete : Boolean = false;
        attribute reportComplete : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute shutdownComplete : Boolean = false;
        attribute calibrationComplete : Boolean = false;

        // ---- State Machine ----
        state def OperationalStateMachine {
            entry;
            exit;

            state idle {
                entry { /* System in low-power standby, awaiting command */ }
                do { /* Monitor for incoming commands */ }
            }

            state initializing {
                entry { /* Begin calibration and self-test sequence */ }
                do {
                    sensingUnit.EstablishBaseline;
                    sensingUnit.measurementCircuit.PerformMeasurementSequence;
                }
            }

            state measuring {
                entry { /* Begin active crack measurement cycle */ }
                do {
                    sensingUnit.AcquireRawMeasurement;
                    signalConditioner.ConditionSignal;
                    dataAcquisition.PerformAcquisition;
                    crackProcessor.AnalyzeCrack;
                }
            }

            state reporting {
                entry { /* Transmit crack measurement results */ }
                do { /* Format and output CrackMeasurement via resultPort */ }
            }

            state faultShutdown {
                entry { /* Fault detected, initiating safe shutdown */ }
                do {
                    powerSupply.ShutdownPower;
                }
            }

            transition idleToInitializing first idle then initializing
                when commandPort.command == "activate";

            transition initializingToMeasuring first initializing then measuring
                when selfTestPassed == true && calibrationComplete == true;

            transition measuringToReporting first measuring then reporting
                when measurementComplete == true;

            transition reportingToIdle first reporting then idle
                when reportComplete == true;

            transition idleToFault first idle then faultShutdown
                when faultDetected == true;

            transition initializingToFault first initializing then faultShutdown
                when faultDetected == true;

            transition measuringToFault first measuring then faultShutdown
                when faultDetected == true;

            transition reportingToFault first reporting then faultShutdown
                when faultDetected == true;

            transition faultToIdle first faultShutdown then idle
                when shutdownComplete == true;
        }

        exhibit OperationalStateMachine;
    }
}
