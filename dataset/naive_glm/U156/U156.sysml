package ClinicalECGAnalysisSystem {

    import ScalarValues::*;

    // ===== Units =====

    unit ms;
    unit mV;
    unit Hz;
    unit bpm;
    unit deg;

    // ===== Value Types =====

    value type TimeMs :> Real {
        unit ms;
    }

    value type VoltageMv :> Real {
        unit mV;
    }

    value type FrequencyHz :> Real {
        unit Hz;
    }

    value type HeartRateBpm :> Real {
        unit bpm;
    }

    value type AngleDeg :> Real {
        unit deg;
    }

    value type Dimensionless :> Real {
    }

    value type ConfidenceScore :> Real {
    }

    // ===== Enumerations =====

    enum def RhythmType {
        normalSinus;
        sinusBradycardia;
        sinusTachycardia;
        atrialFibrillation;
        atrialFlutter;
        supraventricularTachycardia;
        firstDegreeAVBlock;
        secondDegreeAVBlockType1;
        secondDegreeAVBlockType2;
        thirdDegreeAVBlock;
        ventricularTachycardia;
        ventricularFibrillation;
        asystole;
        pacedRhythm;
        unknown;
    }

    enum def AbnormalityType {
        none;
        anteroseptalSTEMI;
        anteriorSTEMI;
        inferiorSTEMI;
        lateralSTEMI;
        posteriorSTEMI;
        STdepressionIschemia;
        TWaveInversion;
        leftBundleBranchBlock;
        rightBundleBranchBlock;
        leftVentricularHypertrophy;
        rightVentricularHypertrophy;
        prolongedQTc;
        shortQTc;
        earlyRepolarization;
        hyperkalemiaPattern;
    }

    enum def SignalQualityStatus {
        acceptable;
        marginal;
        poor;
        reacquisitionRequired;
    }

    enum def UrgencyCategory {
        routine;
        urgent;
        critical;
    }

    enum def PhysicianReviewFlag {
        notRequired;
        recommended;
        mandatory;
    }

    enum def LeadName {
        leadI;
        leadII;
        leadIII;
        aVR;
        aVL;
        aVF;
        V1;
        V2;
        V3;
        V4;
        V5;
        V6;
    }

    // ===== Item Definitions =====

    item def RawECGSignal {
        attribute patientId : String;
        attribute samplingRate : FrequencyHz;
        attribute duration : TimeMs;
        attribute leadCount : Integer = 12;
        attribute leadNames : LeadName[12] ordered;
        attribute samples : Real[*] ordered;
        attribute acquisitionTimestamp : String;
    }

    item def CleanECGSignal {
        attribute samplingRate : FrequencyHz;
        attribute duration : TimeMs;
        attribute leadCount : Integer = 12;
        attribute leadNames : LeadName[12] ordered;
        attribute samples : Real[*] ordered;
        attribute filterBandwidth : FrequencyHz;
    }

    item def SignalQualityMetrics {
        attribute snr : Dimensionless;
        attribute baselineWanderAmplitude : VoltageMv;
        attribute powerLineInterference : VoltageMv;
        attribute electrodeImpedance : Dimensionless;
        attribute status : SignalQualityStatus;
        attribute qualityScore : Dimensionless;
    }

    item def ECGFeatures {
        attribute heartRate : HeartRateBpm;
        attribute ventricularRate : HeartRateBpm;
        attribute atrialRate : HeartRateBpm;
        attribute prInterval : TimeMs;
        attribute qrsDuration : TimeMs;
        attribute qtInterval : TimeMs;
        attribute qtCorrected : TimeMs;
        attribute rrIntervalMean : TimeMs;
        attribute rrIntervalStdDev : TimeMs;
        attribute pWaveAmplitude : VoltageMv;
        attribute pWaveDuration : TimeMs;
        attribute qWaveAmplitude : VoltageMv;
        attribute rWaveAmplitude : VoltageMv;
        attribute sWaveAmplitude : VoltageMv;
        attribute tWaveAmplitude : VoltageMv;
        attribute tWaveMorphology : String;
        attribute stSegmentElevation : VoltageMv;
        attribute stSegmentDepression : VoltageMv;
        attribute electricalAxis : AngleDeg;
        attribute axisDeviation : String;
        attribute rhythmRegularity : Boolean;
    }

    item def RhythmResult {
        attribute primaryRhythm : RhythmType;
        attribute secondaryRhythm : RhythmType;
        attribute confidence : ConfidenceScore;
        attribute ventricularRate : HeartRateBpm;
        attribute atrialRate : HeartRateBpm;
        attribute rhythmRegularity : Boolean;
        attribute lifeThreatening : Boolean;
        attribute modelVersion : String;
    }

    item def AbnormalityResult {
        attribute findings : AbnormalityType[*];
        attribute confidence : ConfidenceScore;
        attribute affectedLeads : LeadName[*];
        attribute severity : Dimensionless;
        attribute stElevationMax : VoltageMv;
        attribute stElevationLeads : LeadName[*];
        attribute modelVersion : String;
    }

    item def Diagnosis {
        attribute primaryDiagnosis : String;
        attribute secondaryFindings : String[*];
        attribute confidence : ConfidenceScore;
        attribute urgency : UrgencyCategory;
        attribute physicianReview : PhysicianReviewFlag;
        attribute differentialDiagnoses : String[*];
        attribute clinicalContext : String;
    }

    item def ClinicalReport {
        attribute reportId : String;
        attribute timestamp : String;
        attribute patientId : String;
        attribute diagnosis : Diagnosis;
        attribute features : ECGFeatures;
        attribute rhythmResult : RhythmResult;
        attribute abnormalityResult : AbnormalityResult;
        attribute recommendations : String[*];
        attribute physicianReviewRequired : Boolean;
        attribute processingTime : TimeMs;
        attribute systemVersion : String;
    }

    // ===== Port Definitions =====

    port def RawSignalOut {
        out raw : RawECGSignal;
    }

    port def RawSignalIn {
        in raw : RawECGSignal;
    }

    port def CleanSignalOut {
        out signal : CleanECGSignal;
    }

    port def CleanSignalIn {
        in signal : CleanECGSignal;
    }

    port def MetricsOut {
        out metrics : SignalQualityMetrics;
    }

    port def MetricsIn {
        in metrics : SignalQualityMetrics;
    }

    port def FeaturesOut {
        out features : ECGFeatures;
    }

    port def FeaturesIn {
        in features : ECGFeatures;
    }

    port def RhythmOut {
        out result : RhythmResult;
    }

    port def RhythmIn {
        in result : RhythmResult;
    }

    port def AbnormalityOut {
        out result : AbnormalityResult;
    }

    port def AbnormalityIn {
        in result : AbnormalityResult;
    }

    port def DiagnosisOut {
        out diagnosis : Diagnosis;
    }

    port def DiagnosisIn {
        in diagnosis : Diagnosis;
    }

    port def ReportOut {
        out report : ClinicalReport;
    }

    port def ReportIn {
        in report : ClinicalReport;
    }

    // ===== Action Definitions =====

    action def AcquireECGAction {
        in patientId : String;
        out rawSignal : RawECGSignal;
    }

    action def FilterSignalAction {
        in rawSignal : RawECGSignal;
        out cleanSignal : CleanECGSignal;
    }

    action def ValidateQualityAction {
        in cleanSignal : CleanECGSignal;
        out metrics : SignalQualityMetrics;
    }

    action def ExtractFeaturesAction {
        in cleanSignal : CleanECGSignal;
        in metrics : SignalQualityMetrics;
        out features : ECGFeatures;
    }

    action def ClassifyRhythmAction {
        in cleanSignal : CleanECGSignal;
        in features : ECGFeatures;
        out result : RhythmResult;
    }

    action def DetectAbnormalitiesAction {
        in cleanSignal : CleanECGSignal;
        in features : ECGFeatures;
        out result : AbnormalityResult;
    }

    action def SynthesizeDiagnosisAction {
        in features : ECGFeatures;
        in rhythmResult : RhythmResult;
        in abnormalityResult : AbnormalityResult;
        out diagnosis : Diagnosis;
    }

    action def GenerateReportAction {
        in diagnosis : Diagnosis;
        in features : ECGFeatures;
        in rhythmResult : RhythmResult;
        in abnormalityResult : AbnormalityResult;
        out report : ClinicalReport;
    }

    // ===== Part Definitions =====

    part def ECGAcquisitionModule {
        port rawOut : RawSignalOut;

        attribute samplingRate : FrequencyHz = 500;
        attribute acquisitionDuration : TimeMs = 10000;
        attribute leadCount : Integer = 12;
        attribute electrodeCheckEnabled : Boolean = true;

        action acquire : AcquireECGAction;

        state acquisitionStateMachine {
            state Idle;
            state CheckingElectrodes;
            state Acquiring;
            state Complete;
            state Error;

            transition from Idle to CheckingElectrodes when acquisitionTriggered;
            transition from CheckingElectrodes to Acquiring when electrodesValid;
            transition from CheckingElectrodes to Error when electrodesInvalid;
            transition from Acquiring to Complete when acquisitionDurationElapsed;
            transition from Error to Idle when errorAcknowledged;
            transition from Complete to Idle when reset;
        }
    }

    part def SignalProcessingModule {
        port rawIn : RawSignalIn;
        port cleanOut : CleanSignalOut;
        port metricsOut : MetricsOut;

        attribute lowCutoff : FrequencyHz = 0.5;
        attribute highCutoff : FrequencyHz = 150;
        attribute powerLineFreq : FrequencyHz = 50;
        attribute notchFilterEnabled : Boolean = true;
        attribute baselineWanderFilterEnabled : Boolean = true;
        attribute snrThreshold : Dimensionless = 10.0;

        action filter : FilterSignalAction;
        action validate : ValidateQualityAction;

        state processingStateMachine {
            state Waiting;
            state Filtering;
            state Validating;
            state QualityAcceptable;
            state QualityFlagged;
            state Done;

            transition from Waiting to Filtering when rawSignalReceived;
            transition from Filtering to Validating when filteringComplete;
            transition from Validating to QualityAcceptable when snrAboveThreshold;
            transition from Validating to QualityFlagged when snrBelowThreshold;
            transition from QualityAcceptable to Done when signalApproved;
            transition from QualityFlagged to Waiting when reacquisitionRequested;
        }
    }

    part def FeatureExtractionModule {
        port cleanIn : CleanSignalIn;
        port metricsIn : MetricsIn;
        port featuresOut : FeaturesOut;

        attribute detectionSensitivity : Dimensionless = 0.95;
        attribute waveletDecompositionLevel : Integer = 5;

        action extract : ExtractFeaturesAction;

        state extractionStateMachine {
            state Idle;
            state DetectingQRS;
            state MeasuringIntervals;
            state MeasuringAmplitudes;
            state ComputingAxis;
            state Complete;

            transition from Idle to DetectingQRS when cleanSignalReceived;
            transition from DetectingQRS to MeasuringIntervals when qrsDetected;
            transition from MeasuringIntervals to MeasuringAmplitudes when intervalsMeasured;
            transition from MeasuringAmplitudes to ComputingAxis when amplitudesMeasured;
            transition from ComputingAxis to Complete when axisComputed;
            transition from Complete to Idle when featuresDispatched;
        }
    }

    part def RhythmAnalysisModule {
        port cleanIn : CleanSignalIn;
        port featuresIn : FeaturesIn;
        port rhythmOut : RhythmOut;

        attribute modelVersion : String = "CNN-ECG-Rhythm-v3.2";
        attribute inferenceTime : TimeMs = 2000;
        attribute inputSegmentLength : TimeMs = 10000;
        attribute sensitivityThreshold : ConfidenceScore = 0.95;
        attribute architecture : String = "DeepConvolutionalNeuralNetwork";

        action classify : ClassifyRhythmAction;

        state analysisStateMachine {
            state Idle;
            state Preprocessing;
            state Inferring;
            state Postprocessing;
            state Complete;

            transition from Idle to Preprocessing when inputsReceived;
            transition from Preprocessing to Inferring when preprocessingComplete;
            transition from Inferring to Postprocessing when inferenceComplete;
            transition from Postprocessing to Complete when postprocessingComplete;
            transition from Complete to Idle when resultDispatched;
        }
    }

    part def AbnormalityDetectionModule {
        port cleanIn : CleanSignalIn;
        port featuresIn : FeaturesIn;
        port abnormalityOut : AbnormalityOut;

        attribute modelVersion : String = "AbnormalityNet-v2.1";
        attribute stElevationThreshold : VoltageMv = 0.1;
        attribute stElevationThresholdV2V3 : VoltageMv = 0.2;
        attribute architecture : String = "MultiScaleCNN";

        action detect : DetectAbnormalitiesAction;

        state detectionStateMachine {
            state Idle;
            state ScanningLeads;
            classifyingAbnormalities;
            state AssessingSeverity;
            state Complete;

            transition from Idle to ScanningLeads when inputsReceived;
            transition from ScanningLeads to classifyingAbnormalities when scanComplete;
            transition from classifyingAbnormalities to AssessingSeverity when classificationComplete;
            transition from AssessingSeverity to Complete when severityAssessed;
            transition from Complete to Idle when resultDispatched;
        }
    }

    part def DiagnosticEngine {
        port featuresIn : FeaturesIn;
        port rhythmIn : RhythmIn;
        port abnormalityIn : AbnormalityIn;
        port diagnosisOut : DiagnosisOut;

        attribute criticalConfidenceThreshold : ConfidenceScore = 0.85;
        attribute lifeThreateningRhythms : RhythmType[*] = [RhythmType::ventricularTachycardia, RhythmType::ventricularFibrillation, RhythmType::asystole];
        attribute ruleDatabaseVersion : String = "Rules-v4.0";

        action synthesize : SynthesizeDiagnosisAction;

        state diagnosticStateMachine {
            state Idle;
            state CollectingInputs;
            state Reasoning;
            state AssigningUrgency;
            state Complete;

            transition from Idle to CollectingInputs when anyInputReceived;
            transition from CollectingInputs to Reasoning when allInputsReceived;
            transition from Reasoning to AssigningUrgency when reasoningComplete;
            transition from AssigningUrgency to Complete when urgencyAssigned;
            transition from Complete to Idle when diagnosisDispatched;
        }
    }

    part def ReportGenerationModule {
        port diagnosisIn : DiagnosisIn;
        port featuresIn : FeaturesIn;
        port rhythmIn : RhythmIn;
        port abnormalityIn : AbnormalityIn;
        port reportOut : ReportOut;

        attribute reportFormat : String = "HL7-FHIR";
        attribute ehrIntegrationEnabled : Boolean = true;
        attribute includeWaveformSnippet : Boolean = true;
        attribute includeRecommendations : Boolean = true;

        action generate : GenerateReportAction;

        state reportStateMachine {
            state Idle;
            state CompilingData;
            state FormattingReport;
            state GeneratingRecommendations;
            state Dispatching;
            state Complete;

            transition from Idle to CompilingData when diagnosisReceived;
            transition from CompilingData to FormattingReport when dataCompiled;
            transition from FormattingReport to GeneratingRecommendations when reportFormatted;
            transition from GeneratingRecommendations to Dispatching when recommendationsGenerated;
            transition from Dispatching to Complete when reportDispatched;
            transition from Complete to Idle when reset;
        }
    }

    part def PatientInterface {
        attribute electrodeCount : Integer = 12;
        attribute cableType : String = "12-lead";
        attribute connected : Boolean = false;
    }

    part def EHRInterface {
        port reportIn : ReportIn;
        attribute endpoint : String;
        attribute protocol : String = "HL7-FHIR";
        attribute authenticated : Boolean = false;
    }

    // ===== Top-Level System =====

    part def ECGAnalysisSystem {
        attribute systemId : String;
        attribute systemVersion : String = "ECG-AI-v5.0";
        attribute maxProcessingTime : TimeMs = 15000;
        attribute operational : Boolean = true;

        part patientInterface : PatientInterface;
        part acquisition : ECGAcquisitionModule;
        part processing : SignalProcessingModule;
        part extraction : FeatureExtractionModule;
        part rhythmAnalysis : RhythmAnalysisModule;
        part abnormalityDetection : AbnormalityDetectionModule;
        part diagnosticEngine : DiagnosticEngine;
        part reportGeneration : ReportGenerationModule;
        part ehrInterface : EHRInterface;

        connection rawSignalLink connect acquisition.rawOut to processing.rawIn;
        connection cleanSignalToExtraction connect processing.cleanOut to extraction.cleanIn;
        connection metricsToExtraction connect processing.metricsOut to extraction.metricsIn;
        connection cleanSignalToRhythm connect processing.cleanOut to rhythmAnalysis.cleanIn;
        connection cleanSignalToAbnormality connect processing.cleanOut to abnormalityDetection.cleanIn;
        connection featuresToRhythm connect extraction.featuresOut to rhythmAnalysis.featuresIn;
        connection featuresToAbnormality connect extraction.featuresOut to abnormalityDetection.featuresIn;
        connection featuresToDiagnostic connect extraction.featuresOut to diagnosticEngine.featuresIn;
        connection rhythmToDiagnostic connect rhythmAnalysis.rhythmOut to diagnosticEngine.rhythmIn;
        connection abnormalityToDiagnostic connect abnormalityDetection.abnormalityOut to diagnosticEngine.abnormalityIn;
        connection diagnosisToReport connect diagnosticEngine.diagnosisOut to reportGeneration.diagnosisIn;
        connection featuresToReport connect extraction.featuresOut to reportGeneration.featuresIn;
        connection rhythmToReport connect rhythmAnalysis.rhythmOut to reportGeneration.rhythmIn;
        connection abnormalityToReport connect abnormalityDetection.abnormalityOut to reportGeneration.abnormalityIn;
        connection reportToEHR connect reportGeneration.reportOut to ehrInterface.reportIn;

        state systemStateMachine {
            state Standby;
            state Acquiring;
            state Processing;
            state Extracting;
            state Analyzing;
            state Diagnosing;
            state Reporting;
            state Complete;
            state QualityError;

            transition from Standby to Acquiring when acquisitionTriggered;
            transition from Acquiring to Processing when rawSignalAcquired;
            transition from Processing to Extracting when qualityAcceptable;
            transition from Processing to QualityError when qualityPoor;
            transition from QualityError to Acquiring when reacquisitionRequested;
            transition from Extracting to Analyzing when featuresExtracted;
            transition from Analyzing to Diagnosing when analysisComplete;
            transition from Diagnosing to Reporting when diagnosisComplete;
            transition from Reporting to Complete when reportGenerated;
            transition from Complete to Standby when reset;
        }
    }

    // ===== Requirements =====

    requirement def ProcessingTimeRequirement {
        subject system : ECGAnalysisSystem;
        constraint {
            system.maxProcessingTime <= 15000
        }
    }

    requirement def SignalQualityValidationRequirement {
        subject processing : SignalProcessingModule;
        constraint {
            processing.snrThreshold >= 10.0
        }
    }

    requirement def RhythmDetectionAccuracyRequirement {
        subject rhythm : RhythmAnalysisModule;
        constraint {
            rhythm.sensitivityThreshold >= 0.95
        }
    }

    requirement def STElevationDetectionRequirement {
        subject abnormality : AbnormalityDetectionModule;
        constraint {
            abnormality.stElevationThreshold == 0.1
        }
    }

    requirement def CriticalFindingsReviewRequirement {
        subject diagnosis : Diagnosis;
        constraint {
            diagnosis.urgency == UrgencyCategory::critical implies
                diagnosis.physicianReview == PhysicianReviewFlag::mandatory
        }
    }

    requirement def ReportCompletenessRequirement {
        subject report : ClinicalReport;
        constraint {
            report.diagnosis != null and
            report.features != null and
            report.rhythmResult != null and
            report.abnormalityResult != null
        }
    }

    requirement def EHRIntegrationRequirement {
        subject ehr : EHRInterface;
        constraint {
            ehr.protocol == "HL7-FHIR"
        }
    }

    requirement def LifeThreateningPriorityRequirement {
        subject rhythm : RhythmAnalysisModule;
        constraint {
            rhythm.lifeThreatening == true implies
                rhythm.confidence >= 0.90
        }
    }

}
