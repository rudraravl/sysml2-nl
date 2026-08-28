package ElectronicNose {

    import ScalarValues::*;

    // ============================================
    // Value Types with Units
    // ============================================

    attribute def VoltageValue :> Real { unit 'V'; }
    attribute def CurrentValue :> Real { unit 'A'; }
    attribute def ResistanceValue :> Real { unit 'Ohm'; }
    attribute def TimeValue :> Real { unit 's'; }
    attribute def ConcentrationValue :> Real { unit 'ppm'; }
    attribute def FrequencyValue :> Real { unit 'Hz'; }
    attribute def GainValue :> Real { unit 'V/V'; }
    attribute def ConfidenceValue :> Real { unit '%'; }
    attribute def PressureValue :> Real { unit 'Pa'; }
    attribute def FlowRateValue :> Real { unit 'L/min'; }
    attribute def TemperatureValue :> Real { unit 'K'; }

    // ============================================
    // Enumerations
    // ============================================

    enum def OdorCategory {
        Fruits;
        Chemicals;
        Solvents;
        Organic;
        Floral;
        Unknown;
    }

    enum def SystemMode {
        Off;
        Initializing;
        Sampling;
        Analyzing;
        Displaying;
        Cleaning;
    }

    enum def SensorMode {
        Idle;
        Heating;
        Sensing;
        Recovering;
    }

    // ============================================
    // Item Definitions
    // ============================================

    item def AirSample {
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute pressure : PressureValue;
    }

    item def FilteredAir :> AirSample {
        attribute particleCount : Integer;
    }

    item def ChemicalCompound {
        attribute name : String;
        attribute formula : String;
        attribute concentration : ConcentrationValue;
    }

    item def Odor {
        attribute category : OdorCategory;
        attribute compounds : ChemicalCompound[0..*];
    }

    item def SensorReading {
        attribute sensorId : Integer;
        attribute rawResistance : ResistanceValue;
        attribute baselineResistance : ResistanceValue;
        attribute deltaResistance : ResistanceValue;
    }

    item def SensorFingerprint {
        attribute readings : SensorReading[16];
        attribute timestamp : TimeValue;
    }

    item def ConditionedPattern {
        attribute normalizedValues : Real[16];
        attribute timestamp : TimeValue;
        attribute sampleId : String;
    }

    item def KnownOdorSignature {
        attribute category : OdorCategory;
        attribute featureVector : Real[16];
        attribute compounds : ChemicalCompound[0..*];
    }

    item def AnalysisResult {
        attribute identifiedCategory : OdorCategory;
        attribute compounds : ChemicalCompound[0..*];
        attribute confidence : ConfidenceValue;
        attribute processingTime : TimeValue;
        attribute sampleId : String;
    }

    item def DisplayMessage {
        attribute odorCategory : OdorCategory;
        attribute compounds : ChemicalCompound[0..*];
        attribute confidence : ConfidenceValue;
        attribute timestamp : TimeValue;
    }

    // ============================================
    // Port Definitions
    // ============================================

    port def AmbientAirInPort {
        attribute flowRate : FlowRateValue;
        in flow air : AirSample;
    }

    port def AirFlowOutPort {
        attribute flowRate : FlowRateValue;
        out flow air : AirSample;
    }

    port def FilteredAirInPort {
        in flow air : FilteredAir;
    }

    port def FilteredAirOutPort {
        out flow air : FilteredAir;
    }

    port def FingerprintOutPort {
        out flow fingerprint : SensorFingerprint;
    }

    port def FingerprintInPort {
        in flow fingerprint : SensorFingerprint;
    }

    port def PatternOutPort {
        out flow pattern : ConditionedPattern;
    }

    port def PatternInPort {
        in flow pattern : ConditionedPattern;
    }

    port def ResultOutPort {
        out flow result : AnalysisResult;
    }

    port def ResultInPort {
        in flow result : AnalysisResult;
    }

    port def DisplayOutPort {
        out flow message : DisplayMessage;
    }

    port def ReadingOutPort {
        out flow reading : SensorReading;
    }

    // ============================================
    // Action Definitions
    // ============================================

    action def DrawAirAction {
        in air : AirSample;
        out drawnAir : AirSample;
    }

    action def FilterAirAction {
        in air : AirSample;
        out filteredAir : FilteredAir;
    }

    action def SenseAction {
        in air : FilteredAir;
        out fingerprint : SensorFingerprint;
    }

    action def ConditionSignalAction {
        in fingerprint : SensorFingerprint;
        out pattern : ConditionedPattern;
    }

    action def ClassifyAction {
        in pattern : ConditionedPattern;
        out result : AnalysisResult;
    }

    action def DisplayAction {
        in result : AnalysisResult;
        out message : DisplayMessage;
    }

    // ============================================
    // State Machine Definitions
    // ============================================

    state def SystemStateMachine {
        state off;
        state initializing;
        state sampling;
        state analyzing;
        state displaying;
        state cleaning;
        transition from off to initializing when powerOn;
        transition from initializing to sampling when initComplete;
        transition from sampling to analyzing when sampleComplete;
        transition from analyzing to displaying when analysisComplete;
        transition from displaying to cleaning when displayComplete;
        transition from cleaning to sampling when cycleComplete;
        transition from cleaning to off when shutdown;
    }

    state def SensorStateMachine {
        state idle;
        state heating;
        state sensing;
        state recovering;
        transition from idle to heating when startHeating;
        transition from heating to sensing when targetTempReached;
        transition from sensing to recovering when sensingComplete;
        transition from recovering to idle when recoveryComplete;
    }

    // ============================================
    // Part Definitions – Components
    // ============================================

    part def Pump {
        attribute nominalFlowRate : FlowRateValue = 1.0;
        attribute operatingPressure : PressureValue = 101325.0;
        attribute powerConsumption : CurrentValue;
        in port intake : AmbientAirInPort;
        out port output : AirFlowOutPort;
        action drawAir : DrawAirAction;
        state pumpState :> SystemStateMachine;
    }

    part def ParticleFilter {
        attribute efficiency : Real = 0.99;
        attribute maxParticleSizeMicrons : Real = 5.0;
        in port intake : AmbientAirInPort;
        out port output : FilteredAirOutPort;
        action filterAir : FilterAirAction;
    }

    part def AirSamplingUnit {
        attribute samplingDuration : TimeValue = 5.0;
        part pump : Pump;
        part filter : ParticleFilter;
        in port airIntake : AmbientAirInPort;
        out port airOutput : FilteredAirOutPort;
        connect airIntake to pump.intake;
        connect pump.output to filter.intake;
        connect filter.output to airOutput;
    }

    part def ChemicalSensor {
        attribute sensorId : Integer;
        attribute baselineResistance : ResistanceValue;
        attribute currentResistance : ResistanceValue;
        attribute operatingTemperature : TemperatureValue;
        in port airIn : FilteredAirInPort;
        out port readingOut : ReadingOutPort;
        state sensorState :> SensorStateMachine;
    }

    part def MetalOxideSensor :> ChemicalSensor {
        attribute heaterVoltage : VoltageValue = 5.0;
        redef operatingTemperature = 573.15;
    }

    part def ConductivePolymerSensor :> ChemicalSensor {
        attribute polymerType : String;
        redef operatingTemperature = 298.15;
    }

    part def SensorArray {
        attribute sensorCount : Integer = 16;
        part metalOxideSensors : MetalOxideSensor[8];
        part polymerSensors : ConductivePolymerSensor[8];
        in port airIn : FilteredAirInPort;
        out port fingerprintOut : FingerprintOutPort;
        action sense : SenseAction;
    }

    part def SignalConditioner {
        attribute amplificationGain : GainValue = 10.0;
        attribute filterCutoffFrequency : FrequencyValue = 1000.0;
        attribute noiseFloor : VoltageValue = 0.001;
        in port rawSignalIn : FingerprintInPort;
        out port patternOut : PatternOutPort;
        action condition : ConditionSignalAction;
    }

    part def PatternRecognitionModule {
        attribute algorithmType : String = "neural network";
        attribute minConfidenceThreshold : ConfidenceValue = 75.0;
        attribute librarySize : Integer;
        part odorLibrary : KnownOdorSignature[0..*];
        in port patternIn : PatternInPort;
        out port resultOut : ResultOutPort;
        action classify : ClassifyAction;
    }

    part def UserInterface {
        attribute displayType : String = "LCD";
        attribute refreshRate : FrequencyValue = 60.0;
        in port resultIn : ResultInPort;
        out port displayOut : DisplayOutPort;
        action display : DisplayAction;
    }

    // ============================================
    // Top-Level System Part
    // ============================================

    part def ElectronicNoseSystem {
        attribute systemId : String;
        attribute analysisDuration : TimeValue;
        attribute maxAnalysisTime : TimeValue = 30.0;

        part airSamplingUnit : AirSamplingUnit;
        part sensorArray : SensorArray;
        part signalConditioner : SignalConditioner;
        part patternRecognition : PatternRecognitionModule;
        part userInterface : UserInterface;

        in port ambientAirIntake : AmbientAirInPort;
        out port displayOutput : DisplayOutPort;

        connect ambientAirIntake to airSamplingUnit.airIntake;
        connect airSamplingUnit.airOutput to sensorArray.airIn;
        connect sensorArray.fingerprintOut to signalConditioner.rawSignalIn;
        connect signalConditioner.patternOut to patternRecognition.patternIn;
        connect patternRecognition.resultOut to userInterface.resultIn;
        connect userInterface.displayOut to displayOutput;

        state systemState :> SystemStateMachine;
    }

    // ============================================
    // Requirements
    // ============================================

    requirement def ProcessingTimeRequirement {
        doc "The system shall complete the entire analysis process within a specified maximum time.";
        attribute maxTime : TimeValue;
    }

    requirement totalProcessingTime : ProcessingTimeRequirement {
        doc "The entire process from sampling air to displaying final classification shall be completed in under 30 seconds.";
        attribute maxTime = 30.0;
    }

    requirement def SamplingFlowRequirement {
        doc "The air sampling unit shall draw in ambient air at an adequate flow rate through a particle filter.";
        attribute requiredFlowRate : FlowRateValue;
        attribute filterEfficiency : Real;
    }

    requirement airSamplingFlow : SamplingFlowRequirement {
        doc "The Air Sampling Unit shall use an internal pump to draw in ambient air, pass it through a particle filter to remove dust and contaminants, and deliver a clean sample for analysis.";
        attribute requiredFlowRate = 1.0;
        attribute filterEfficiency = 0.99;
    }

    requirement def SensorArrayRequirement {
        doc "The sensor array shall contain the specified number and types of chemical sensors.";
        attribute metalOxideCount : Integer;
        attribute polymerCount : Integer;
        attribute totalSensorCount : Integer;
    }

    requirement sensorArrayConfig : SensorArrayRequirement {
        doc "The Sensor Array shall consist of 16 individual chemical sensors: 8 metal-oxide sensors and 8 conductive polymer sensors. The combined response from all 16 sensors shall create a unique digital fingerprint for the specific odor being analyzed.";
        attribute metalOxideCount = 8;
        attribute polymerCount = 8;
        attribute totalSensorCount = 16;
    }

    requirement def SignalConditioningRequirement {
        doc "The signal conditioner shall clean up raw electrical signals from the sensor array.";
        attribute requiredGain : GainValue;
        attribute maxNoiseFloor : VoltageValue;
    }

    requirement signalConditioningSpec : SignalConditioningRequirement {
        doc "The Signal Conditioner shall amplify the raw electrical signals, filter out noise, and normalize the data to produce a clear and consistent pattern.";
        attribute requiredGain = 10.0;
        attribute maxNoiseFloor = 0.001;
    }

    requirement def PatternRecognitionRequirement {
        doc "The pattern recognition module shall classify odors using a neural network algorithm.";
        attribute minConfidence : ConfidenceValue;
        attribute algorithmType : String;
    }

    requirement odorClassification : PatternRecognitionRequirement {
        doc "The Pattern Recognition Module shall use a neural network algorithm to analyze the conditioned pattern, extract key features, compare against a pre-existing library of known odor signatures, classify the odor, identify specific chemical compounds present, and calculate a confidence level.";
        attribute minConfidence = 75.0;
        attribute algorithmType = "neural network";
    }

    requirement def DisplayRequirement {
        doc "The user interface shall display analysis results clearly to the user.";
    }

    requirement displayOutputReq : DisplayRequirement {
        doc "The User Interface shall format the data and present a clear output to the user, displaying the detected odor category and the specific compounds identified.";
    }

    // ============================================
    // Satisfaction Relationships
    // ============================================

    satisfy totalProcessingTime by ElectronicNoseSystem;
    satisfy airSamplingFlow by AirSamplingUnit;
    satisfy sensorArrayConfig by SensorArray;
    satisfy signalConditioningSpec by SignalConditioner;
    satisfy odorClassification by PatternRecognitionModule;
    satisfy displayOutputReq by UserInterface;
}
