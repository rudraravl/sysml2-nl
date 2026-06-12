package ElectronicTongueSystemModel {

    import ScalarValues::*;
    import SI::*;

    item def LiquidSample {
        attribute sampleIdentifier : String;
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute pH : Real;
        attribute conductivity : Conductivity;
        attribute dissolvedSolids : MassConcentration;
        attribute aromaInterferenceIndex : Real;
    }

    item def ConditionedSample :> LiquidSample {
        attribute filtrationLevel : Real;
        attribute dilutionRatio : Real;
        attribute stabilizationTime : Time;
    }

    item def TasteFingerprint {
        attribute sournessIndex : Real;
        attribute bitternessIndex : Real;
        attribute saltinessIndex : Real;
        attribute sweetnessIndex : Real;
        attribute umamiIndex : Real;
        attribute metallicIndex : Real;
        attribute astringencyIndex : Real;
        attribute confidence : Real;
    }

    item def SensorResponseVector {
        attribute voltageResponse : ElectricPotential [12];
        attribute currentResponse : ElectricCurrent [12];
        attribute impedanceResponse : Resistance [12];
        attribute responseTime : Time;
        attribute baselineDrift : ElectricPotential;
    }

    item def ClassificationResult {
        attribute productClass : String;
        attribute adulterationDetected : Boolean;
        attribute freshnessScore : Real;
        attribute qualityGrade : String;
        attribute confidence : Real;
    }

    item def CleaningFluid {
        attribute cleaningAgent : String;
        attribute volume : Volume;
        attribute conductivity : Conductivity;
        attribute pH : Real;
    }

    item def WasteFluid {
        attribute volume : Volume;
        attribute hazardous : Boolean;
    }

    item def CalibrationSolution {
        attribute solutionName : String;
        attribute referencePH : Real;
        attribute referenceConductivity : Conductivity;
        attribute referenceTasteClass : String;
    }

    value type Volume :> Real {
        unit = L;
    }

    value type FlowRate :> Real {
        unit = L / min;
    }

    value type Temperature :> Real {
        unit = K;
    }

    value type Time :> Real {
        unit = s;
    }

    value type ElectricPotential :> Real {
        unit = V;
    }

    value type ElectricCurrent :> Real {
        unit = A;
    }

    value type Resistance :> Real {
        unit = Ohm;
    }

    value type Conductivity :> Real {
        unit = S / m;
    }

    value type MassConcentration :> Real {
        unit = kg / m^3;
    }

    value type Power :> Real {
        unit = W;
    }

    value type Pressure :> Real {
        unit = Pa;
    }

    part def ElectronicTongueSystem {

        attribute primaryFunction : String = "Analyze liquid samples with an array of cross-sensitive chemical sensors, transform sensor responses into a digital taste fingerprint, and classify sample quality, identity, freshness, or adulteration at a high level.";

        attribute measurementCycleTime : Time;
        attribute sampleThroughput : Real;
        attribute detectionConfidenceThreshold : Real;
        attribute maximumSampleVolume : Volume;
        attribute operatingTemperatureMin : Temperature;
        attribute operatingTemperatureMax : Temperature;
        attribute nominalPowerConsumption : Power;

        port sampleIn : SampleInputPort;
        port cleanIn : CleaningInputPort;
        port calibrationIn : CalibrationInputPort;
        port wasteOut : WasteOutputPort;
        port resultOut : ResultOutputPort;
        port operatorInterface : HumanMachineInterfacePort;
        port networkPort : DataNetworkPort;
        port powerPort : ElectricalPowerPort;

        part sampleHandlingSubsystem : SampleHandlingSubsystem;
        part sensorArraySubsystem : SensorArraySubsystem;
        part excitationAndReadoutSubsystem : ExcitationAndReadoutSubsystem;
        part signalProcessingSubsystem : SignalProcessingSubsystem;
        part classificationSubsystem : ClassificationSubsystem;
        part cleaningSubsystem : CleaningSubsystem;
        part calibrationSubsystem : CalibrationSubsystem;
        part controlSubsystem : ControlSubsystem;
        part dataStorageSubsystem : DataStorageSubsystem;
        part enclosure : Enclosure;

        connect sampleIn to sampleHandlingSubsystem.rawSampleIn;
        connect cleanIn to cleaningSubsystem.cleaningFluidIn;
        connect calibrationIn to calibrationSubsystem.calibrationSolutionIn;
        connect sampleHandlingSubsystem.conditionedSampleOut to sensorArraySubsystem.sampleExposureIn;
        connect sensorArraySubsystem.responseOut to excitationAndReadoutSubsystem.sensorSignalIn;
        connect excitationAndReadoutSubsystem.digitizedResponseOut to signalProcessingSubsystem.rawResponseIn;
        connect signalProcessingSubsystem.fingerprintOut to classificationSubsystem.fingerprintIn;
        connect classificationSubsystem.resultOut to resultOut;
        connect classificationSubsystem.resultOut to dataStorageSubsystem.resultRecordIn;
        connect signalProcessingSubsystem.fingerprintOut to dataStorageSubsystem.fingerprintRecordIn;
        connect cleaningSubsystem.wasteOut to wasteOut;
        connect sensorArraySubsystem.drainOut to cleaningSubsystem.contaminatedFluidIn;
        connect calibrationSubsystem.referenceSampleOut to sensorArraySubsystem.sampleExposureIn;
        connect calibrationSubsystem.referenceProfileOut to signalProcessingSubsystem.calibrationReferenceIn;
        connect controlSubsystem.commandOut to sampleHandlingSubsystem.commandIn;
        connect controlSubsystem.commandOut to sensorArraySubsystem.commandIn;
        connect controlSubsystem.commandOut to cleaningSubsystem.commandIn;
        connect controlSubsystem.commandOut to calibrationSubsystem.commandIn;
        connect operatorInterface to controlSubsystem.operatorPort;
        connect networkPort to dataStorageSubsystem.networkPort;
        connect powerPort to controlSubsystem.powerIn;
        connect powerPort to excitationAndReadoutSubsystem.powerIn;
        connect powerPort to cleaningSubsystem.powerIn;

        perform action analyzeLiquidSample;
        exhibit state electronicTongueOperatingState;
    }

    port def SampleInputPort {
        in item sample : LiquidSample;
    }

    port def CleaningInputPort {
        in item cleaningFluid : CleaningFluid;
    }

    port def CalibrationInputPort {
        in item calibrationSolution : CalibrationSolution;
    }

    port def WasteOutputPort {
        out item waste : WasteFluid;
    }

    port def ResultOutputPort {
        out item result : ClassificationResult;
        out item fingerprint : TasteFingerprint;
    }

    port def HumanMachineInterfacePort {
        in item operatorCommand : OperatorCommand;
        out item statusMessage : SystemStatus;
    }

    port def DataNetworkPort {
        in item remoteCommand : OperatorCommand;
        out item storedResult : ClassificationResult;
        out item diagnosticStatus : SystemStatus;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : ElectricPotential;
        in attribute availablePower : Power;
    }

    port def SensorExposurePort {
        in item conditionedSample : ConditionedSample;
        in item calibrationSolution : CalibrationSolution;
        out item waste : WasteFluid;
    }

    port def SensorResponsePort {
        out item responseVector : SensorResponseVector;
    }

    port def CommandPort {
        in item command : OperatorCommand;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : ElectricPotential;
        in attribute availablePower : Power;
    }

    item def OperatorCommand {
        attribute commandName : String;
        attribute requestedSampleIdentifier : String;
        attribute priority : Integer;
    }

    item def SystemStatus {
        attribute stateName : String;
        attribute readyForSample : Boolean;
        attribute faultActive : Boolean;
        attribute maintenanceRequired : Boolean;
        attribute message : String;
    }

    part def SampleHandlingSubsystem {
        attribute targetSampleVolume : Volume;
        attribute pumpFlowRate : FlowRate;
        attribute filterPoreSize : Length;
        attribute mixerSpeed : Real;
        attribute stabilizationTime : Time;

        port rawSampleIn : SampleInputPort;
        port conditionedSampleOut {
            out item sample : ConditionedSample;
        }
        port commandIn : CommandPort;

        part inletValve : MicroValve;
        part meteringPump : Pump;
        part microFilter : Filter;
        part dilutionMixer : Mixer;
        part temperatureController : TemperatureController;
        part bubbleDetector : BubbleDetector;

        action conditionSample {
            in item rawSample : LiquidSample;
            out item conditionedSample : ConditionedSample;

            first startPump;
            then filterSample;
            then regulateTemperature;
            then mixAndStabilize;
            then detectBubbles;
            then releaseConditionedSample;

            action startPump;
            action filterSample;
            action regulateTemperature;
            action mixAndStabilize;
            action detectBubbles;
            action releaseConditionedSample;
        }
    }

    part def SensorArraySubsystem {
        attribute sensorCount : Integer = 12;
        attribute exposureTime : Time;
        attribute operatingTemperature : Temperature;
        attribute maximumAllowedDrift : ElectricPotential;

        port sampleExposureIn : SensorExposurePort;
        port responseOut : SensorResponsePort;
        port drainOut : WasteOutputPort;
        port commandIn : CommandPort;

        part lipidPolymerSensor[4] : ChemicalSensor;
        part metalOxideSensor[3] : ChemicalSensor;
        part ionSelectiveSensor[3] : ChemicalSensor;
        part referenceElectrode : ReferenceElectrode;
        part temperatureProbe : TemperatureProbe;
        part flowCell : FlowCell;

        action exposeSensorArray {
            in item conditionedSample : ConditionedSample;
            out item responseVector : SensorResponseVector;

            first fillFlowCell;
            then waitForEquilibrium;
            then acquireElectrochemicalResponse;
            then measureTemperature;
            then drainFlowCell;

            action fillFlowCell;
            action waitForEquilibrium;
            action acquireElectrochemicalResponse;
            action measureTemperature;
            action drainFlowCell;
        }
    }

    part def ExcitationAndReadoutSubsystem {
        attribute excitationVoltageAmplitude : ElectricPotential;
        attribute excitationFrequency : Frequency;
        attribute analogResolutionBits : Integer;
        attribute samplingRate : Frequency;
        attribute readoutNoise : ElectricPotential;

        port sensorSignalIn : SensorResponsePort;
        port digitizedResponseOut {
            out item responseVector : SensorResponseVector;
        }
        port powerIn : PowerInputPort;

        part potentiostat : Potentiostat;
        part impedanceAnalyzer : ImpedanceAnalyzer;
        part analogFrontEnd : AnalogFrontEnd;
        part analogToDigitalConverter : AnalogToDigitalConverter;

        action acquireResponse {
            in item sensorResponse : SensorResponseVector;
            out item digitizedResponse : SensorResponseVector;

            first applyExcitationWaveform;
            then sampleElectrodeSignals;
            then digitizeSignals;
            then compensateReferenceElectrode;

            action applyExcitationWaveform;
            action sampleElectrodeSignals;
            action digitizeSignals;
            action compensateReferenceElectrode;
        }
    }

    part def SignalProcessingSubsystem {
        attribute baselineWindow : Time;
        attribute noiseRejectionRatio : Real;
        attribute driftCorrectionEnabled : Boolean;
        attribute featureVectorLength : Integer;

        port rawResponseIn {
            in item responseVector : SensorResponseVector;
        }

        port calibrationReferenceIn {
            in item calibrationSolution : CalibrationSolution;
        }

        port fingerprintOut {
            out item fingerprint : TasteFingerprint;
        }

        action generateTasteFingerprint {
            in item rawResponse : SensorResponseVector;
            in item reference : CalibrationSolution;
            out item fingerprint : TasteFingerprint;

            first validateSignalCompleteness;
            then removeBaseline;
            then correctTemperatureEffects;
            then normalizeSensorChannels;
            then extractTasteFeatures;
            then estimateFingerprintConfidence;

            action validateSignalCompleteness;
            action removeBaseline;
            action correctTemperatureEffects;
            action normalizeSensorChannels;
            action extractTasteFeatures;
            action estimateFingerprintConfidence;
        }
    }

    part def ClassificationSubsystem {
        attribute modelName : String;
        attribute modelVersion : String;
        attribute minimumConfidence : Real;
        attribute freshnessAlarmThreshold : Real;
        attribute adulterationAlarmThreshold : Real;

        port fingerprintIn {
            in item fingerprint : TasteFingerprint;
        }

        port resultOut : ResultOutputPort;

        part tastePatternClassifier : PatternClassifier;
        part anomalyDetector : AnomalyDetector;
        part freshnessEstimator : FreshnessEstimator;
        part decisionLogic : DecisionLogic;

        action classifySample {
            in item fingerprint : TasteFingerprint;
            out item result : ClassificationResult;

            first compareAgainstTasteLibrary;
            then estimateFreshness;
            then detectAdulteration;
            then assignQualityGrade;
            then publishClassification;

            action compareAgainstTasteLibrary;
            action estimateFreshness;
            action detectAdulteration;
            action assignQualityGrade;
            action publishClassification;
        }
    }

    part def CleaningSubsystem {
        attribute rinseVolume : Volume;
        attribute cleaningCycleTime : Time;
        attribute dryingAirPressure : Pressure;
        attribute carryoverLimit : Real;

        port cleaningFluidIn : CleaningInputPort;
        port contaminatedFluidIn {
            in item waste : WasteFluid;
        }
        port wasteOut : WasteOutputPort;
        port commandIn : CommandPort;
        port powerIn : PowerInputPort;

        part cleaningPump : Pump;
        part rinseValve : MicroValve;
        part wasteReservoir : WasteReservoir;
        part airPurgeUnit : AirPurgeUnit;

        action cleanFluidPath {
            in item cleaningFluid : CleaningFluid;
            out item waste : WasteFluid;

            first flushFlowCell;
            then rinseSensorSurface;
            then purgeAir;
            then verifyCarryoverBelowLimit;

            action flushFlowCell;
            action rinseSensorSurface;
            action purgeAir;
            action verifyCarryoverBelowLimit;
        }
    }

    part def CalibrationSubsystem {
        attribute calibrationInterval : Time;
        attribute acceptedReferenceError : Real;
        attribute lastCalibrationAge : Time;

        port calibrationSolutionIn : CalibrationInputPort;
        port referenceSampleOut : SensorExposurePort;
        port referenceProfileOut {
            out item reference : CalibrationSolution;
        }
        port commandIn : CommandPort;

        part referenceReservoir : CalibrationReservoir;
        part calibrationValve : MicroValve;
        part calibrationScheduler : CalibrationScheduler;

        action calibrateSensors {
            in item calibrationSolution : CalibrationSolution;
            out item calibrationReference : CalibrationSolution;

            first introduceReferenceSolution;
            then measureReferenceResponse;
            then updateSensorGain;
            then updateSensorOffset;
            then storeCalibrationRecord;

            action introduceReferenceSolution;
            action measureReferenceResponse;
            action updateSensorGain;
            action updateSensorOffset;
            action storeCalibrationRecord;
        }
    }

    part def ControlSubsystem {
        attribute firmwareVersion : String;
        attribute watchdogTimeout : Time;
        attribute activeFaultCode : String;

        port operatorPort : HumanMachineInterfacePort;
        port commandOut : CommandPort;
        port powerIn : PowerInputPort;

        part embeddedController : EmbeddedController;
        part scheduler : MeasurementScheduler;
        part faultManager : FaultManager;
        part userDisplay : UserDisplay;

        action coordinateMeasurementCycle {
            first receiveOperatorCommand;
            then verifySystemReady;
            then runSampleConditioning;
            then runSensorExposure;
            then runSignalProcessing;
            then runClassification;
            then runCleaningCycle;
            then reportStatus;

            action receiveOperatorCommand;
            action verifySystemReady;
            action runSampleConditioning;
            action runSensorExposure;
            action runSignalProcessing;
            action runClassification;
            action runCleaningCycle;
            action reportStatus;
        }
    }

    part def DataStorageSubsystem {
        attribute storageCapacity : Real;
        attribute retentionPeriod : Time;
        attribute encryptedStorageEnabled : Boolean;

        port resultRecordIn {
            in item result : ClassificationResult;
        }

        port fingerprintRecordIn {
            in item fingerprint : TasteFingerprint;
        }

        port networkPort : DataNetworkPort;

        part localDatabase : LocalDatabase;
        part auditLog : AuditLog;
        part networkExporter : NetworkExporter;

        action storeMeasurementRecord {
            in item result : ClassificationResult;
            in item fingerprint : TasteFingerprint;

            first createTimestampedRecord;
            then writeFingerprint;
            then writeClassificationResult;
            then exportIfRequested;

            action createTimestampedRecord;
            action writeFingerprint;
            action writeClassificationResult;
            action exportIfRequested;
        }
    }

    part def ChemicalSensor {
        attribute sensorMaterial : String;
        attribute sensitivity : ElectricPotential;
        attribute selectivityProfile : String;
        attribute responseTime : Time;
        attribute driftRate : ElectricPotential;
        attribute serviceLife : Time;

        port exposedSurface {
            in item sample : ConditionedSample;
        }

        port electricalTerminals {
            out attribute potential : ElectricPotential;
            out attribute current : ElectricCurrent;
            out attribute impedance : Resistance;
        }
    }

    part def ReferenceElectrode {
        attribute electrodeChemistry : String;
        attribute referencePotential : ElectricPotential;
        attribute stability : ElectricPotential;
    }

    part def FlowCell {
        attribute internalVolume : Volume;
        attribute maximumPressure : Pressure;
        attribute wettedMaterial : String;
    }

    part def Pump {
        attribute maximumFlowRate : FlowRate;
        attribute minimumFlowRate : FlowRate;
        attribute primingVolume : Volume;
    }

    part def MicroValve {
        attribute openTime : Time;
        attribute leakageRate : FlowRate;
        attribute normallyClosed : Boolean;
    }

    part def Filter {
        attribute poreSize : Length;
        attribute maximumPressureDrop : Pressure;
    }

    part def Mixer {
        attribute mixingVolume : Volume;
        attribute mixingEfficiency : Real;
    }

    part def TemperatureController {
        attribute setPoint : Temperature;
        attribute tolerance : Temperature;
        attribute heatingPower : Power;
    }

    part def BubbleDetector {
        attribute detectionThreshold : Real;
    }

    part def TemperatureProbe {
        attribute accuracy : Temperature;
        attribute responseTime : Time;
    }

    part def Potentiostat {
        attribute voltageRange : ElectricPotential;
        attribute currentRange : ElectricCurrent;
        attribute controlBandwidth : Frequency;
    }

    part def ImpedanceAnalyzer {
        attribute minimumFrequency : Frequency;
        attribute maximumFrequency : Frequency;
        attribute impedanceRange : Resistance;
    }

    part def AnalogFrontEnd {
        attribute gain : Real;
        attribute inputNoise : ElectricPotential;
        attribute channelCount : Integer;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer;
        attribute samplingRate : Frequency;
    }

    part def PatternClassifier {
        attribute algorithm : String;
        attribute trainingSetSize : Integer;
        attribute validationAccuracy : Real;
    }

    part def AnomalyDetector {
        attribute anomalyThreshold : Real;
        attribute falsePositiveRate : Real;
    }

    part def FreshnessEstimator {
        attribute modelType : String;
        attribute scoreRangeMinimum : Real;
        attribute scoreRangeMaximum : Real;
    }

    part def DecisionLogic {
        attribute decisionPolicy : String;
    }

    part def WasteReservoir {
        attribute capacity : Volume;
        attribute currentFillLevel : Volume;
    }

    part def AirPurgeUnit {
        attribute purgePressure : Pressure;
        attribute purgeDuration : Time;
    }

    part def CalibrationReservoir {
        attribute capacity : Volume;
        attribute remainingVolume : Volume;
    }

    part def CalibrationScheduler {
        attribute interval : Time;
        attribute calibrationDue : Boolean;
    }

    part def EmbeddedController {
        attribute processorClock : Frequency;
        attribute memoryCapacity : Real;
    }

    part def MeasurementScheduler {
        attribute queuedMeasurements : Integer;
    }

    part def FaultManager {
        attribute activeFaultCount : Integer;
        attribute highestSeverity : String;
    }

    part def UserDisplay {
        attribute displayTechnology : String;
        attribute brightness : Real;
    }

    part def LocalDatabase {
        attribute recordCount : Integer;
        attribute capacity : Real;
    }

    part def AuditLog {
        attribute entryCount : Integer;
    }

    part def NetworkExporter {
        attribute protocol : String;
        attribute encryptionEnabled : Boolean;
    }

    part def Enclosure {
        attribute ingressProtectionRating : String;
        attribute material : String;
        attribute externalVolume : Volume;
        attribute mass : Mass;
    }

    action def AnalyzeLiquidSample {
        in item sample : LiquidSample;
        in item calibrationSolution : CalibrationSolution;
        in item cleaningFluid : CleaningFluid;
        out item result : ClassificationResult;
        out item fingerprint : TasteFingerprint;

        first acceptSample;
        then conditionSample;
        then exposeSensorArray;
        then acquireSensorSignals;
        then generateTasteFingerprint;
        then classifyTastePattern;
        then cleanWetPath;
        then reportResult;

        action acceptSample;
        action conditionSample;
        action exposeSensorArray;
        action acquireSensorSignals;
        action generateTasteFingerprint;
        action classifyTastePattern;
        action cleanWetPath;
        action reportResult;
    }

    state def ElectronicTongueOperatingState {
        entry action initializeSystem;

        state Off;
        state Standby;
        state SelfTest;
        state Calibration;
        state Ready;
        state SampleIntake;
        state SampleConditioning;
        state SensorExposure;
        state SignalAcquisition;
        state FingerprintGeneration;
        state Classification;
        state Cleaning;
        state ResultReporting;
        state Fault;

        initial then Off;

        transition Off_to_Standby
            first Off
            accept PowerApplied
            then Standby;

        transition Standby_to_SelfTest
            first Standby
            accept StartSelfTest
            then SelfTest;

        transition SelfTest_to_Calibration
            first SelfTest
            if selfTestPassed
            then Calibration;

        transition Calibration_to_Ready
            first Calibration
            if calibrationValid
            then Ready;

        transition Ready_to_SampleIntake
            first Ready
            accept AnalyzeCommand
            then SampleIntake;

        transition SampleIntake_to_SampleConditioning
            first SampleIntake
            if sampleVolumeAccepted
            then SampleConditioning;

        transition SampleConditioning_to_SensorExposure
            first SampleConditioning
            if sampleConditioned
            then SensorExposure;

        transition SensorExposure_to_SignalAcquisition
            first SensorExposure
            if exposureTimeComplete
            then SignalAcquisition;

        transition SignalAcquisition_to_FingerprintGeneration
            first SignalAcquisition
            if responseVectorComplete
            then FingerprintGeneration;

        transition FingerprintGeneration_to_Classification
            first FingerprintGeneration
            if fingerprintConfidenceAcceptable
            then Classification;

        transition Classification_to_ResultReporting
            first Classification
            if classificationComplete
            then ResultReporting;

        transition ResultReporting_to_Cleaning
            first ResultReporting
            then Cleaning;

        transition Cleaning_to_Ready
            first Cleaning
            if carryoverBelowLimit
            then Ready;

        transition Any_to_Fault
            first Standby
            accept FaultDetected
            then Fault;

        transition Fault_to_Standby
            first Fault
            accept FaultCleared
            then Standby;
    }

    requirement def PrimaryFunctionRequirement {
        subject electronicTongue : ElectronicTongueSystem;
        doc
        /* The system shall determine a high-level digital taste and quality characterization of a liquid sample by exposing the sample to a cross-sensitive electronic sensor array, processing the resulting electrochemical responses, and producing a classified result with confidence. */
    }

    requirement def SampleVolumeRequirement {
        subject electronicTongue : ElectronicTongueSystem;
        attribute maximumRequiredSampleVolume : Volume = 0.010;
        doc
        /* The system shall complete one analysis using no more than 10 mL of liquid sample. */
    }

    requirement def ClassificationConfidenceRequirement {
        subject classifier : ClassificationSubsystem;
        attribute minimumConfidence : Real = 0.95;
        doc
        /* The classification subsystem shall report product class, freshness score, and adulteration status when the estimated confidence is at least 0.95. */
    }

    requirement def MeasurementCycleRequirement {
        subject electronicTongue : ElectronicTongueSystem;
        attribute maximumCycleTime : Time = 180.0;
        doc
        /* The system shall complete sample intake, conditioning, sensing, processing, classification, and cleaning within 180 seconds during normal operation. */
    }

    requirement def CleaningCarryoverRequirement {
        subject cleaning : CleaningSubsystem;
        attribute maximumCarryoverFraction : Real = 0.01;
        doc
        /* The cleaning subsystem shall reduce sample carryover to less than 1 percent before the next measurement begins. */
    }

    requirement def SensorArrayRequirement {
        subject sensorArray : SensorArraySubsystem;
        attribute minimumSensorCount : Integer = 10;
        doc
        /* The sensor array shall include at least ten partially selective sensors spanning lipid-polymer, metal-oxide, and ion-selective sensing principles. */
    }

    requirement def CalibrationRequirement {
        subject calibration : CalibrationSubsystem;
        attribute maximumCalibrationAge : Time = 86400.0;
        doc
        /* The system shall perform or request calibration at least once every 24 hours of operation. */
    }

    requirement def OperatingTemperatureRequirement {
        subject electronicTongue : ElectronicTongueSystem;
        attribute minimumOperatingTemperature : Temperature = 288.15;
        attribute maximumOperatingTemperature : Temperature = 308.15;
        doc
        /* The system shall maintain valid measurement performance for liquid samples between 15 degrees Celsius and 35 degrees Celsius. */
    }

    satisfy PrimaryFunctionRequirement by ElectronicTongueSystem;
    satisfy SampleVolumeRequirement by SampleHandlingSubsystem;
    satisfy ClassificationConfidenceRequirement by ClassificationSubsystem;
    satisfy MeasurementCycleRequirement by ElectronicTongueSystem;
    satisfy CleaningCarryoverRequirement by CleaningSubsystem;
    satisfy SensorArrayRequirement by SensorArraySubsystem;
    satisfy CalibrationRequirement by CalibrationSubsystem;
    satisfy OperatingTemperatureRequirement by SampleHandlingSubsystem;

    constraint def ConfidenceWithinRange {
        in confidence : Real;
        confidence >= 0.0 and confidence <= 1.0;
    }

    constraint def SampleTemperatureWithinOperatingRange {
        in sampleTemperature : Temperature;
        in minimumTemperature : Temperature;
        in maximumTemperature : Temperature;
        sampleTemperature >= minimumTemperature and sampleTemperature <= maximumTemperature;
    }

    constraint def CycleTimeLimit {
        in measuredCycleTime : Time;
        in maximumCycleTime : Time;
        measuredCycleTime <= maximumCycleTime;
    }

    constraint def CarryoverLimit {
        in carryoverFraction : Real;
        in maximumCarryoverFraction : Real;
        carryoverFraction <= maximumCarryoverFraction;
    }

    analysis def MeasurementPerformanceAnalysis {
        subject electronicTongue : ElectronicTongueSystem;

        objective evaluateCycleTime {
            doc /* Verify that the analysis cycle completes within the required duration. */
        }

        objective evaluateClassificationConfidence {
            doc /* Verify that classification confidence is adequate for reporting high-level taste and quality outputs. */
        }

        objective evaluateCleaningEffectiveness {
            doc /* Verify that fluid path carryover is below the allowable limit before a subsequent sample. */
        }
    }
}