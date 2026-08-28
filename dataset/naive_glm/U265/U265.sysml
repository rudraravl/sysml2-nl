package ClinicalChemistryAnalyzer {

    import ScalarValues::*;
    
    // ============================================================
    // VALUE TYPES WITH UNITS
    // ============================================================
    
    value type ConcentrationValue :> Real {
        :>> unit = "mg/dL";
        doc /<<Concentration of an analyte measured in milligrams per deciliter.>>
    }
    
    value type VolumeValue :> Real {
        :>> unit = "uL";
        doc /<<Volume measured in microliters.>>
    }
    
    value type TemperatureValue :> Real {
        :>> unit = "degC";
        doc /<<Temperature measured in degrees Celsius.>>
    }
    
    value type DurationValue :> Real {
        :>> unit = "s";
        doc /<<Duration measured in seconds.>>
    }
    
    value type AbsorbanceValue :> Real {
        :>> unit = "AU";
        doc /<<Optical absorbance measured in absorbance units.>>
    }
    
    value type WavelengthValue :> Real {
        :>> unit = "nm";
        doc /<<Light wavelength measured in nanometers.>>
    }
    
    value type ThroughputValue :> Real {
        :>> unit = "tests/h";
        doc /<<Processing throughput measured in tests per hour.>>
    }
    
    value type PressureValue :> Real {
        :>> unit = "kPa";
        doc /<<Fluid pressure measured in kilopascals.>>
    }
    
    value type FlowRateValue :> Real {
        :>> unit = "uL/s";
        doc /<<Flow rate measured in microliters per second.>>
    }
    
    value type PercentageValue :> Real {
        :>> unit = "%";
        doc /<<Percentage value such as coefficient of variation.>>
    }
    
    value type LengthValue :> Real {
        :>> unit = "mm";
        doc /<<Length measured in millimeters.>>
    }
    
    value type FrequencyValue :> Real {
        :>> unit = "Hz";
        doc /<<Frequency measured in Hertz.>>
    }
    
    // ============================================================
    // ENUMERATIONS
    // ============================================================
    
    enum def SampleType {
        literal Blood;
        literal Serum;
        literal Plasma;
        literal Urine;
        literal CerebrospinalFluid;
        literal QCSample;
    }
    
    enum def AnalyteType {
        literal Glucose;
        literal Cholesterol;
        literal ALT;
        literal AST;
        literal Bilirubin;
        literal Creatinine;
        literal Urea;
        literal Triglycerides;
    }
    
    enum def ReagentState {
        literal Adequate;
        literal Low;
        literal Empty;
        literal Expired;
    }
    
    enum def ModuleStatus {
        literal Idle;
        literal Initializing;
        literal Ready;
        literal Running;
        literal Cleaning;
        literal Error;
        literal Maintenance;
    }
    
    enum def ResultFlag {
        literal Normal;
        literal High;
        literal Low;
        literal Critical;
        literal Invalid;
        literal PendingReview;
    }
    
    enum def SystemMode {
        literal Standby;
        literal Operating;
        literal Calibration;
        literal QCMode;
        literal Shutdown;
    }
    
    // ============================================================
    // ITEM DEFINITIONS
    // ============================================================
    
    item def BiologicalSample {
        doc /<<A biological specimen collected from a patient for clinical analysis.>>
        attribute sampleId : String;
        attribute patientId : String;
        attribute sampleType : SampleType;
        attribute volume : VolumeValue;
        attribute analytesRequested : AnalyteType[0..*];
        attribute collectedAt : String;
        attribute integrityVerified : Boolean default true;
    }
    
    item def Reagent {
        doc /<<A chemical reagent used to react with a biological sample for a specific analyte test.>>
        attribute reagentId : String;
        attribute analyte : AnalyteType;
        attribute lotNumber : String;
        attribute volume : VolumeValue;
        attribute state : ReagentState;
        attribute expirationDate : String;
        attribute storageTemp : TemperatureValue;
    }
    
    item def ReactionMixture {
        doc /<<A mixture of biological sample and reagent undergoing a chemical reaction.>>
        attribute mixtureId : String;
        attribute analyte : AnalyteType;
        attribute sampleVolume : VolumeValue;
        attribute reagentVolume : VolumeValue;
        attribute incubationTemp : TemperatureValue;
        attribute incubationDuration : DurationValue;
        attribute isReacted : Boolean default false;
    }
    
    item def RawOpticalData {
        doc /<<Raw absorbance measurement data from the optical detection module.>>
        attribute analyte : AnalyteType;
        attribute wavelength : WavelengthValue;
        attribute absorbance : AbsorbanceValue;
        attribute blankAbsorbance : AbsorbanceValue;
        attribute sampleId : String;
        attribute measuredAt : String;
    }
    
    item def CalibrationCurve {
        doc /<<A calibration curve mapping absorbance values to analyte concentrations.>>
        attribute analyte : AnalyteType;
        attribute slope : Real;
        attribute intercept : Real;
        attribute rSquared : Real;
        attribute validUntil : String;
    }
    
    item def ReferenceRange {
        doc /<<A clinically validated reference range for a specific analyte and sample type.>>
        attribute analyte : AnalyteType;
        attribute lowerBound : ConcentrationValue;
        attribute upperBound : ConcentrationValue;
        attribute applicableTo : SampleType;
    }
    
    item def AnalysisResult {
        doc /<<A single analyte result with calculated concentration and validation flag.>>
        attribute resultId : String;
        attribute sampleId : String;
        attribute analyte : AnalyteType;
        attribute concentration : ConcentrationValue;
        attribute flag : ResultFlag;
        attribute measuredAt : String;
        attribute isQC : Boolean default false;
    }
    
    item def DiagnosticReport {
        doc /<<A comprehensive diagnostic report containing all analyte results for a given sample.>>
        attribute reportId : String;
        attribute sampleId : String;
        attribute patientId : String;
        attribute results : AnalysisResult[0..*];
        attribute generatedAt : String;
        attribute verified : Boolean default false;
    }
    
    item def QCSample {
        doc /<<A quality control standard sample with known expected concentration for calibration and QC checks.>>
        attribute qcId : String;
        attribute analyte : AnalyteType;
        attribute expectedConcentration : ConcentrationValue;
        attribute acceptableLower : ConcentrationValue;
        attribute acceptableUpper : ConcentrationValue;
        attribute lotNumber : String;
    }
    
    item def MaintenanceLog {
        doc /<<A log entry recording a maintenance activity performed on the analyzer.>>
        attribute logId : String;
        attribute timestamp : String;
        attribute activity : String;
        attribute operatorId : String;
    }
    
    // ============================================================
    // PORT DEFINITIONS
    // ============================================================
    
    port def SampleIntakePort {
        in item incomingSample : BiologicalSample;
    }
    
    port def SampleDeliveryPort {
        out item dispensedSample : BiologicalSample;
    }
    
    port def ReagentDeliveryPort {
        out item dispensedReagent : Reagent;
    }
    
    port def ReagentIntakePort {
        in item incomingReagent : Reagent;
    }
    
    port def MixtureIntakePort {
        in item receivedMixture : ReactionMixture;
    }
    
    port def MixtureDeliveryPort {
        out item preparedMixture : ReactionMixture;
    }
    
    port def OpticalDataOutputPort {
        out item opticalReading : RawOpticalData;
    }
    
    port def OpticalDataInputPort {
        in item opticalReading : RawOpticalData;
    }
    
    port def ResultOutputPort {
        out item result : AnalysisResult;
        out item report : DiagnosticReport;
    }
    
    port def CalibrationOutputPort {
        out item calibrationCurve : CalibrationCurve;
    }
    
    port def CalibrationInputPort {
        in item calibrationCurve : CalibrationCurve;
    }
    
    port def QCSampleOutputPort {
        out item qcSample : QCSample;
    }
    
    port def QCSampleIntakePort {
        in item qcSample : QCSample;
    }
    
    port def LISInterfacePort {
        out item transmittedReport : DiagnosticReport;
        in item incomingCommand : String;
    }
    
    // ============================================================
    // ACTION DEFINITIONS
    // ============================================================
    
    action def LoadSample {
        in sample : BiologicalSample;
        out preparedSample : BiologicalSample;
    }
    
    action def AspirateSample {
        in sample : BiologicalSample;
        out aspiratedSample : BiologicalSample;
    }
    
    action def DispenseReagent {
        in analyte : AnalyteType;
        out reagent : Reagent;
    }
    
    action def MixSampleAndReagent {
        in sample : BiologicalSample;
        in reagent : Reagent;
        out mixture : ReactionMixture;
    }
    
    action def Incubate {
        in mixture : ReactionMixture;
        in temperature : TemperatureValue;
        in duration : DurationValue;
        out incubatedMixture : ReactionMixture;
    }
    
    action def MeasureAbsorbance {
        in mixture : ReactionMixture;
        in wavelength : WavelengthValue;
        out opticalData : RawOpticalData;
    }
    
    action def CalculateConcentration {
        in opticalData : RawOpticalData;
        in calibration : CalibrationCurve;
        out result : AnalysisResult;
    }
    
    action def ValidateResult {
        in result : AnalysisResult;
        in referenceRange : ReferenceRange;
        out validatedResult : AnalysisResult;
    }
    
    action def CompileReport {
        in results : AnalysisResult[0..*];
        in patientId : String;
        in sampleId : String;
        out report : DiagnosticReport;
    }
    
    action def TransmitToLIS {
        in report : DiagnosticReport;
    }
    
    action def RunCalibration {
        in qcSample : QCSample;
        out calibrationCurve : CalibrationCurve;
    }
    
    action def RunQC {
        in qcSample : QCSample;
        out result : AnalysisResult;
    }
    
    action def CleanTubing {
        out cleaningComplete : Boolean;
    }
    
    action def AnalysisWorkflow {
        doc /<<The fully automated end-to-end workflow from sample loading to LIS transmission.>>
        in inputSample : BiologicalSample;
        in analyte : AnalyteType;
        out report : DiagnosticReport;
        
        action loadSample : LoadSample;
        action aspirateSample : AspirateSample;
        action dispenseReagent : DispenseReagent;
        action mix : MixSampleAndReagent;
        action incubate : Incubate;
        action measure : MeasureAbsorbance;
        action calculate : CalculateConcentration;
        action validate : ValidateResult;
        action compile : CompileReport;
        action transmit : TransmitToLIS;
        
        succession loadSample then aspirateSample;
        succession aspirateSample then dispenseReagent;
        succession dispenseReagent then mix;
        succession mix then incubate;
        succession incubate then measure;
        succession measure then calculate;
        succession calculate then validate;
        succession validate then compile;
        succession compile then transmit;
    }
    
    // ============================================================
    // STATE MACHINE DEFINITIONS
    // ============================================================
    
    state def SampleHandlingStates {
        state idle;
        state loading;
        state aspirating;
        state dispensing;
        state washing;
        state error;
        
        transition initial to idle;
        transition from idle to loading on sampleReceived;
        transition from loading to aspirating when sampleLoaded;
        transition from aspirating to dispensing when aspirationComplete;
        transition from dispensing to washing when dispenseComplete;
        transition from washing to idle when washComplete;
        transition from idle to error on fault;
        transition from error to idle on reset;
    }
    
    state def ReagentManagementStates {
        state idle;
        state selecting;
        state dispensing;
        state monitoring;
        state error;
        
        transition initial to idle;
        transition from idle to selecting on reagentRequested;
        transition from selecting to dispensing when reagentSelected;
        transition from dispensing to monitoring when dispenseComplete;
        transition from monitoring to idle when monitoringComplete;
        transition from idle to error on reagentEmpty;
        transition from error to idle on refill;
    }
    
    state def FluidicsStates {
        state idle;
        state mixing;
        state incubating;
        state cleaning;
        state error;
        
        transition initial to idle;
        transition from idle to mixing on mixtureReceived;
        transition from mixing to incubating when mixingComplete;
        transition from incubating to idle when reactionComplete;
        transition from idle to cleaning on cleanCycle;
        transition from cleaning to idle when cleanComplete;
        transition from idle to error on leakDetected;
        transition from error to idle on reset;
    }
    
    state def OpticalDetectionStates {
        state idle;
        state calibrating;
        state measuring;
        state reading;
        state error;
        
        transition initial to idle;
        transition from idle to calibrating on calibrateCommand;
        transition from calibrating to idle when calibrationComplete;
        transition from idle to measuring on mixtureReady;
        transition from measuring to reading when measurementComplete;
        transition from reading to idle when dataTransmitted;
        transition from idle to error on detectorFault;
        transition from error to idle on reset;
    }
    
    state def DataProcessingStates {
        state idle;
        state receiving;
        state calculating;
        state validating;
        state reporting;
        state transmitting;
        state error;
        
        transition initial to idle;
        transition from idle to receiving on dataReceived;
        transition from receiving to calculating when dataParsed;
        transition from calculating to validating when calculationComplete;
        transition from validating to reporting when validationComplete;
        transition from reporting to transmitting when reportCompiled;
        transition from transmitting to idle when transmissionComplete;
        transition from idle to error on processingFault;
        transition from error to idle on reset;
    }
    
    state def QualityControlStates {
        state idle;
        state calibrating;
        state qcRunning;
        state qcEvaluating;
        state alerting;
        
        transition initial to idle;
        transition from idle to calibrating on calibrationDue;
        transition from calibrating to idle when calibrationComplete;
        transition from idle to qcRunning on qcScheduled;
        transition from qcRunning to qcEvaluating when qcMeasurementComplete;
        transition from qcEvaluating to idle when qcPassed;
        transition from qcEvaluating to alerting when qcFailed;
        transition from alerting to idle on operatorAck;
    }
    
    state def SystemStates {
        state standby;
        state initializing;
        state operating;
        state calibrating;
        state qcMode;
        state cleaning;
        state error;
        state shutdown;
        
        transition initial to standby;
        transition from standby to initializing on powerOn;
        transition from initializing to operating when allModulesReady;
        transition from operating to calibrating on calibrationRequired;
        transition from calibrating to operating when calibrationDone;
        transition from operating to qcMode on qcScheduled;
        transition from qcMode to operating when qcComplete;
        transition from operating to cleaning on cleanCycle;
        transition from cleaning to operating when cleanComplete;
        transition from operating to error on systemFault;
        transition from error to standby on reset;
        transition from operating to shutdown on powerOff;
    }
    
    // ============================================================
    // PART DEFINITIONS — MODULES
    // ============================================================
    
    part def SampleHandlingModule {
        doc /<<Manages the intake and preparation of patient samples for clinical chemistry analysis.>>
        
        port intake : SampleIntakePort;
        port delivery : SampleDeliveryPort;
        
        attribute status : ModuleStatus default Idle;
        attribute maxCapacity : Integer default 200;
        attribute currentLoad : Integer default 0;
        attribute throughput : ThroughputValue default 220;
        
        part sampleRack {
            attribute capacity : Integer default 200;
            attribute loadedCount : Integer default 0;
            item samples : BiologicalSample[0..*];
        }
        
        part aspirationUnit {
            attribute probeVolume : VolumeValue default 5.0;
            attribute probePrecision : PercentageValue default 1.5;
            attribute probeCapacity : VolumeValue default 100.0;
        }
        
        action loadSample : LoadSample;
        action aspirateSample : AspirateSample;
        
        state : SampleHandlingStates;
    }
    
    part def ReagentManagementModule {
        doc /<<Stores and accurately dispenses the specific chemical reagents needed for each type of test.>>
        
        port delivery : ReagentDeliveryPort;
        
        attribute status : ModuleStatus default Idle;
        attribute storageTemp : TemperatureValue default 4.0;
        attribute reagentCount : Integer default 0;
        
        part reagentCarousel {
            attribute capacity : Integer default 40;
            attribute refrigeratedTemp : TemperatureValue default 4.0;
            item reagents : Reagent[0..*];
        }
        
        part dispensingPump {
            attribute flowRate : FlowRateValue default 10.0;
            attribute precision : PercentageValue default 2.0;
            attribute maxVolume : VolumeValue default 500.0;
        }
        
        action dispenseReagent : DispenseReagent;
        
        state : ReagentManagementStates;
    }
    
    part def FluidicsModule {
        doc /<<Handles the precise mixing of samples and reagents, incubation at controlled temperature, and tubing cleaning between tests.>>
        
        port sampleIn : SampleIntakePort;
        port reagentIn : ReagentIntakePort;
        port mixtureOut : MixtureDeliveryPort;
        
        attribute status : ModuleStatus default Idle;
        attribute operatingTemp : TemperatureValue default 37.0;
        attribute pressure : PressureValue default 101.3;
        attribute flowRate : FlowRateValue default 50.0;
        
        part mixingChamber {
            attribute volume : VolumeValue default 500.0;
            attribute mixingDuration : DurationValue default 5.0;
        }
        
        part incubator {
            attribute targetTemp : TemperatureValue default 37.0;
            attribute tolerance : TemperatureValue default 0.5;
            attribute maxDuration : DurationValue default 600.0;
        }
        
        part tubingSystem {
            attribute totalLength : LengthValue default 200.0;
            attribute innerDiameter : Real default 0.8;
            attribute washVolume : VolumeValue default 100.0;
        }
        
        part fluidicsPump {
            attribute flowRate : FlowRateValue default 50.0;
            attribute maxPressure : PressureValue default 200.0;
        }
        
        action mixSampleAndReagent : MixSampleAndReagent;
        action incubate : Incubate;
        action cleanTubing : CleanTubing;
        
        state : FluidicsStates;
    }
    
    part def OpticalDetectionModule {
        doc /<<Performs the core measurement by shining light through the reacted mixture and measuring absorbance to determine the reaction outcome.>>
        
        port mixtureIn : MixtureIntakePort;
        port dataOut : OpticalDataOutputPort;
        port calibIn : CalibrationInputPort;
        
        attribute status : ModuleStatus default Idle;
        attribute currentWavelength : WavelengthValue default 505.0;
        attribute measurementPrecision : PercentageValue default 1.0;
        
        part lightSource {
            attribute wavelength : WavelengthValue default 505.0;
            attribute intensity : Real default 100.0;
            attribute lifetime : DurationValue default 50000.0;
        }
        
        part monochromator {
            attribute minWavelength : WavelengthValue default 340.0;
            attribute maxWavelength : WavelengthValue default 800.0;
            attribute resolution : Real default 2.0;
        }
        
        part photodetector {
            attribute sensitivity : Real default 0.001;
            attribute dynamicRange : Real default 3.0;
            attribute noiseLevel : Real default 0.0001;
        }
    
    part cuvette {
            attribute pathLength : LengthValue default 10.0;
            attribute volume : VolumeValue default 200.0;
            attribute isClean : Boolean default true;
        }
        
        action measureAbsorbance : MeasureAbsorbance;
        
        state : OpticalDetectionStates;
    }
    
    part def DataProcessingModule {
        doc /<<The brain of the instrument: calculates final concentrations, validates against reference ranges, and compiles diagnostic reports.>>
        
        port dataIn : OpticalDataInputPort;
        port resultOut : ResultOutputPort;
        port calibIn : CalibrationInputPort;
        port lisOut : LISInterfacePort;
        
        attribute status : ModuleStatus default Idle;
        item processingBuffer : AnalysisResult[0..*];
        item calibrationCurves : CalibrationCurve[0..*];
        item referenceRanges : ReferenceRange[0..*];
        
        part processor {
            attribute clockSpeed : FrequencyValue default 3.0e9;
            attribute cores : Integer default 4;
        }
        
        part memory {
            attribute capacity : Real default 16.0;
        }
        
        part storage {
            attribute capacity : Real default 1000.0;
            item storedReports : DiagnosticReport[0..*];
        }
        
        action calculateConcentration : CalculateConcentration;
        action validateResult : ValidateResult;
        action compileReport : CompileReport;
        action transmitToLIS : TransmitToLIS;
        
        state : DataProcessingStates;
    }
    
    part def QualityControlModule {
        doc /<<Ensures instrument accuracy and reliability by managing calibration and running periodic quality control checks using standard samples.>>
        
        port calibOut : CalibrationOutputPort;
        port qcSampleOut : QCSampleOutputPort;
        
        attribute status : ModuleStatus default Idle;
        attribute lastCalibrationDate : String;
        attribute calibrationInterval : DurationValue default 86400.0;
        attribute qcInterval : DurationValue default 14400.0;
        
        part qcSampleStorage {
            attribute capacity : Integer default 20;
            item samples : QCSample[0..*];
        }
        
        part calibrationEngine {
            item currentCurves : CalibrationCurve[0..*];
            attribute recalibrationThreshold : PercentageValue default 5.0;
        }
        
        action runCalibration : RunCalibration;
        action runQC : RunQC;
        
        state : QualityControlStates;
    }
    
    // ============================================================
    // EXTERNAL SYSTEM
    // ============================================================
    
    part def LaboratoryInformationSystem {
        doc /<<An external Laboratory Information System that receives diagnostic reports for storage and review by medical professionals.>>
        
        port lisInterface : LISInterfacePort;
        attribute systemId : String;
        attribute connectedAnalyzers : Integer default 0;
        item storedReports : DiagnosticReport[0..*];
    }
    
    // ============================================================
    // TOP-LEVEL ANALYZER SYSTEM
    // ============================================================
    
    part def ClinicalChemistryAnalyzerSystem {
        doc /<<A fully automated clinical chemistry analyzer for high-throughput medical laboratory environments.>>
        
        attribute systemMode : SystemMode default Standby;
        attribute maxThroughput : ThroughputValue default 200;
        attribute totalTestsRun : Integer default 0;
        attribute isClosedSystem : Boolean default true;
        attribute operatorId : String;
        
        part sampleHandling : SampleHandlingModule;
        part reagentManagement : ReagentManagementModule;
        part fluidics : FluidicsModule;
        part opticalDetection : OpticalDetectionModule;
        part dataProcessing : DataProcessingModule;
        part qualityControl : QualityControlModule;
        
        part externalLIS : LaboratoryInformationSystem;
        
        // External interface ports
        port sampleInput : SampleIntakePort;
        port lisOutput : LISInterfacePort;
        
        // Inter-module connections
        connection sampleToFluidics connect sampleHandling.delivery to fluidics.sampleIn;
        connection reagentToFluidics connect reagentManagement.delivery to fluidics.reagentIn;
        connection fluidicsToOptical connect fluidics.mixtureOut to opticalDetection.mixtureIn;
        connection opticalToData connect opticalDetection.dataOut to dataProcessing.dataIn;
        connection qcToOpticalCalib connect qualityControl.calibOut to opticalDetection.calibIn;
        connection qcToDataCalib connect qualityControl.calibOut to dataProcessing.calibIn;
        connection dataToLIS connect dataProcessing.lisOut to externalLIS.lisInterface;
        connection externalSampleToHandling connect sampleInput to sampleHandling.intake;
        connection lisOutputToExternal connect dataProcessing.lisOut to lisOutput;
        
        state : SystemStates;
        
        action analysisWorkflow : AnalysisWorkflow;
    }
    
    // ============================================================
    // REQUIREMENTS
    // ============================================================
    
    requirement def ThroughputRequirement {
        doc /<<The clinical chemistry analyzer shall process at least 200 tests per hour to support high-throughput clinical environments.>>
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.maxThroughput >= 200; }
    }
    
    requirement def PrecisionRequirement {
        doc /<<The analyzer shall achieve high precision with a coefficient of variation less than or equal to 3% for all analytes.>>
        attribute maxCV : PercentageValue = 3.0;
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.sampleHandling.aspirationUnit.probePrecision <= 3.0; }
    }
    
    requirement def SmallSampleVolumeRequirement {
        doc /<<The analyzer shall require a sample volume of no more than 10 uL per test, suitable for a wide range of patients including pediatric and geriatric.>>
        attribute maxSampleVolume : VolumeValue = 10.0;
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.sampleHandling.aspirationUnit.probeVolume <= 10.0; }
    }
    
    requirement def CalibrationStabilityRequirement {
        doc /<<The analyzer shall maintain long-term calibration stability with calibration validity of at least 24 hours to reduce maintenance frequency.>>
        attribute minInterval : DurationValue = 86400.0;
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.qualityControl.calibrationInterval >= 86400.0; }
    }
    
    requirement def BiosafetyRequirement {
        doc /<<The analyzer shall employ a closed-system design to ensure biosafety for laboratory operators by containing all biological materials.>>
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.isClosedSystem == true; }
    }
    
    requirement def AutomationRequirement {
        doc /<<The analyzer process shall be fully automated from sample loading through report transmission to the LIS, requiring no operator intervention during normal operation.>>
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.analysisWorkflow != null; }
    }
    
    requirement def DiagnosticReportRequirement {
        doc /<<The analyzer shall compile a comprehensive diagnostic report containing all analyte results validated against reference ranges and transmit it to the external LIS for review by medical professionals.>>
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.dataProcessing.resultOut.report != null; }
    }
    
    requirement def CleaningBetweenTestsRequirement {
        doc /<<The fluidics module shall clean the tubing system between tests to prevent cross-contamination between successive samples.>>
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.fluidics.tubingSystem.washVolume > 0.0; }
    }
    
    requirement def TemperatureControlRequirement {
        doc /<<The incubator shall maintain the reaction mixture within plus or minus 0.5 degrees Celsius of the target temperature.>>
        attribute tolerance : TemperatureValue = 0.5;
        subject analyzer : ClinicalChemistryAnalyzerSystem;
        constraint { analyzer.fluidics.incubator.tolerance <= 0.5; }
    }
    
    // ============================================================
    // REQUIREMENT SATISFACTION
    // ============================================================
    
    part analyzerInstance : ClinicalChemistryAnalyzerSystem {
        :>> maxThroughput = 200;
        :>> isClosedSystem = true;
        :>> operatorId = "lab_operator_01";
        
        :>> sampleHandling.aspirationUnit.probeVolume = 5.0;
        :>> sampleHandling.aspirationUnit.probePrecision = 1.5;
        :>> qualityControl.calibrationInterval = 86400.0;
        :>> fluidics.incubator.tolerance = 0.5;
        :>> fluidics.tubingSystem.washVolume = 100.0;
        
        satisfy ThroughputRequirement;
        satisfy PrecisionRequirement;
        satisfy SmallSampleVolumeRequirement;
        satisfy CalibrationStabilityRequirement;
        satisfy BiosafetyRequirement;
        satisfy AutomationRequirement;
        satisfy DiagnosticReportRequirement;
        satisfy CleaningBetweenTestsRequirement;
        satisfy TemperatureControlRequirement;
    }
    
}
