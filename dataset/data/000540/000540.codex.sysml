package AutomatedECGInterpretationModel {

    import ScalarValues::*;
    import ISQ::*;

    value def ElectricPotential {
        :> ISQ::electricPotential;
        unit = "mV";
    }

    value def SamplingFrequency {
        :> ISQ::frequency;
        unit = "Hz";
    }

    value def TimeDuration {
        :> ISQ::duration;
        unit = "s";
    }

    value def HeartRate {
        :> ISQ::frequency;
        unit = "beats/min";
    }

    value def ConfidenceScore {
        :> ScalarValues::Real;
        range = "0.0..1.0";
    }

    value def Probability {
        :> ScalarValues::Real;
        range = "0.0..1.0";
    }

    value def PatientIdentifier {
        :> ScalarValues::String;
    }

    value def DiagnosticLabel {
        :> ScalarValues::String;
    }

    item def PatientContext {
        attribute patientId : PatientIdentifier;
        attribute ageYears : Integer;
        attribute sex : String;
        attribute clinicalSetting : String;
    }

    item def ElectrodeSignal {
        attribute leadName : String;
        attribute potential : ElectricPotential;
        attribute timestamp : TimeDuration;
        attribute contactImpedanceOhm : Real;
    }

    item def MultiLeadECGSample {
        attribute sampleTime : TimeDuration;
        attribute leadI : ElectricPotential;
        attribute leadII : ElectricPotential;
        attribute leadIII : ElectricPotential;
        attribute aVR : ElectricPotential;
        attribute aVL : ElectricPotential;
        attribute aVF : ElectricPotential;
        attribute v1 : ElectricPotential;
        attribute v2 : ElectricPotential;
        attribute v3 : ElectricPotential;
        attribute v4 : ElectricPotential;
        attribute v5 : ElectricPotential;
        attribute v6 : ElectricPotential;
    }

    item def FilteredECGSegment {
        attribute startTime : TimeDuration;
        attribute duration : TimeDuration;
        attribute samplingRate : SamplingFrequency;
        attribute baselineRemoved : Boolean;
        attribute muscleNoiseSuppressed : Boolean;
        attribute mainsInterferenceSuppressed : Boolean;
    }

    item def ECGFeatureSet {
        attribute heartRate : HeartRate;
        attribute rrIntervalMean : TimeDuration;
        attribute prInterval : TimeDuration;
        attribute qrsDuration : TimeDuration;
        attribute qtInterval : TimeDuration;
        attribute qtcInterval : TimeDuration;
        attribute stDeviationMv : ElectricPotential;
        attribute pWavePresent : Boolean;
        attribute rhythmRegularity : Real;
        attribute signalQuality : ConfidenceScore;
    }

    item def DiagnosticFinding {
        attribute label : DiagnosticLabel;
        attribute probability : Probability;
        attribute confidence : ConfidenceScore;
        attribute severity : String;
        attribute explanation : String;
    }

    item def ECGInterpretationReport {
        attribute patientId : PatientIdentifier;
        attribute acquisitionDuration : TimeDuration;
        attribute primaryRhythm : DiagnosticLabel;
        attribute heartRate : HeartRate;
        attribute overallConfidence : ConfidenceScore;
        attribute urgentFindingPresent : Boolean;
        attribute summary : String;
        attribute generatedAtSystemTime : String;
    }

    port def PatientContextPort {
        out context : PatientContext;
    }

    port def ECGInputPort {
        in ecg : MultiLeadECGSample;
    }

    port def ECGSegmentPort {
        out segment : FilteredECGSegment;
    }

    port def FeaturePort {
        out features : ECGFeatureSet;
    }

    port def FindingPort {
        out finding : DiagnosticFinding;
    }

    port def ReportPort {
        out report : ECGInterpretationReport;
    }

    port def AlertPort {
        out urgentFinding : DiagnosticFinding;
    }

    port def StoragePort {
        in storedReport : ECGInterpretationReport;
    }

    part def AutomatedECGInterpreter {
        doc /* Primary function: acquire multi-lead ECG data, assess signal quality, extract clinically relevant cardiac features, classify rhythm and morphology abnormalities, and produce a high-level interpretation report with confidence and urgent-finding alerts. */

        port patientContextIn : PatientContextPort;
        port ecgIn : ECGInputPort;
        port reportOut : ReportPort;
        port alertOut : AlertPort;
        port storageOut : StoragePort;

        part acquisition : ECGAcquisitionSubsystem;
        part preprocessing : SignalPreprocessingSubsystem;
        part featureExtraction : ECGFeatureExtractionSubsystem;
        part diagnosticEngine : DiagnosticClassificationSubsystem;
        part reportGenerator : InterpretationReportSubsystem;
        part safetyMonitor : ClinicalSafetyMonitor;
        part auditStore : InterpretationAuditStore;

        connect ecgIn to acquisition.rawEcgIn;
        connect acquisition.sampleOut to preprocessing.rawSampleIn;
        connect preprocessing.filteredOut to featureExtraction.filteredIn;
        connect featureExtraction.featuresOut to diagnosticEngine.featuresIn;
        connect diagnosticEngine.findingOut to reportGenerator.findingIn;
        connect featureExtraction.featuresOut to reportGenerator.featuresIn;
        connect patientContextIn to reportGenerator.patientContextIn;
        connect diagnosticEngine.findingOut to safetyMonitor.findingIn;
        connect safetyMonitor.alertOut to alertOut;
        connect reportGenerator.reportOut to reportOut;
        connect reportGenerator.reportOut to auditStore.reportIn;
        connect auditStore.archiveOut to storageOut;

        state interpretationLifecycle : ECGInterpretationLifecycle;

        perform action interpretECG : InterpretECGAction;
    }

    part def ECGAcquisitionSubsystem {
        port rawEcgIn : ECGInputPort;
        port sampleOut : ECGInputPort;

        attribute requiredLeadCount : Integer = 12;
        attribute samplingRate : SamplingFrequency = 500 [Hz];
        attribute acquisitionWindow : TimeDuration = 10 [s];
        attribute minimumContactQuality : ConfidenceScore = 0.85;

        perform action acquire : AcquireECGAction;
    }

    part def SignalPreprocessingSubsystem {
        port rawSampleIn : ECGInputPort;
        port filteredOut : ECGSegmentPort;

        attribute highPassCutoff : SamplingFrequency = 0.5 [Hz];
        attribute lowPassCutoff : SamplingFrequency = 150 [Hz];
        attribute notchFrequency : SamplingFrequency = 60 [Hz];
        attribute minimumAcceptableQuality : ConfidenceScore = 0.80;

        perform action preprocess : PreprocessECGAction;
    }

    part def ECGFeatureExtractionSubsystem {
        port filteredIn : ECGSegmentPort;
        port featuresOut : FeaturePort;

        attribute qrsDetectionSensitivity : Real = 0.98;
        attribute minimumBeatCount : Integer = 5;

        perform action extractFeatures : ExtractECGFeaturesAction;
    }

    part def DiagnosticClassificationSubsystem {
        port featuresIn : FeaturePort;
        port findingOut : FindingPort;

        attribute modelName : String = "HybridRuleAndMachineLearningECGClassifier";
        attribute minimumDiagnosticConfidence : ConfidenceScore = 0.70;
        attribute atrialFibrillationThreshold : Probability = 0.85;
        attribute ventricularTachycardiaThreshold : Probability = 0.90;
        attribute stElevationThresholdMv : ElectricPotential = 0.10 [mV];

        perform action classify : ClassifyECGAction;
    }

    part def InterpretationReportSubsystem {
        port patientContextIn : PatientContextPort;
        port featuresIn : FeaturePort;
        port findingIn : FindingPort;
        port reportOut : ReportPort;

        attribute reportFormat : String = "structured clinical summary";
        attribute includeMeasurements : Boolean = true;
        attribute includeConfidence : Boolean = true;

        perform action generateReport : GenerateInterpretationReportAction;
    }

    part def ClinicalSafetyMonitor {
        port findingIn : FindingPort;
        port alertOut : AlertPort;

        attribute urgentLabels : String = "ventricular tachycardia, acute myocardial infarction, complete heart block, extreme bradycardia, extreme tachycardia";
        attribute urgentConfidenceThreshold : ConfidenceScore = 0.80;

        perform action evaluateUrgency : EvaluateUrgencyAction;
    }

    part def InterpretationAuditStore {
        port reportIn : StoragePort;
        port archiveOut : StoragePort;

        attribute retentionPeriodDays : Integer = 2555;
        attribute immutableAuditTrail : Boolean = true;

        perform action archiveReport : ArchiveReportAction;
    }

    action def InterpretECGAction {
        in patientContext : PatientContext;
        in ecgStream : MultiLeadECGSample;
        out interpretation : ECGInterpretationReport;
        out urgentAlert : DiagnosticFinding;

        first start;
        then acquireECG;
        then assessAndFilterSignal;
        then deriveClinicalFeatures;
        then classifyDiagnosticFindings;
        then generateClinicalReport;
        then evaluateUrgentFindings;
        then archiveResult;
        then done;

        action acquireECG : AcquireECGAction;
        action assessAndFilterSignal : PreprocessECGAction;
        action deriveClinicalFeatures : ExtractECGFeaturesAction;
        action classifyDiagnosticFindings : ClassifyECGAction;
        action generateClinicalReport : GenerateInterpretationReportAction;
        action evaluateUrgentFindings : EvaluateUrgencyAction;
        action archiveResult : ArchiveReportAction;
    }

    action def AcquireECGAction {
        in rawSample : MultiLeadECGSample;
        out acceptedSample : MultiLeadECGSample;

        constraint validLeadSet {
            rawSample.leadI != null and rawSample.leadII != null and rawSample.v1 != null and rawSample.v6 != null
        }
    }

    action def PreprocessECGAction {
        in rawSample : MultiLeadECGSample;
        out filteredSegment : FilteredECGSegment;

        constraint samplingAdequate {
            filteredSegment.samplingRate >= 250 [Hz]
        }

        constraint artifactSuppressionApplied {
            filteredSegment.baselineRemoved == true and filteredSegment.mainsInterferenceSuppressed == true
        }
    }

    action def ExtractECGFeaturesAction {
        in filteredSegment : FilteredECGSegment;
        out features : ECGFeatureSet;

        constraint physiologicHeartRateRange {
            features.heartRate >= 20 [beats/min] and features.heartRate <= 250 [beats/min]
        }

        constraint intervalMeasurementsNonnegative {
            features.prInterval >= 0 [s] and features.qrsDuration >= 0 [s] and features.qtInterval >= 0 [s]
        }
    }

    action def ClassifyECGAction {
        in features : ECGFeatureSet;
        out finding : DiagnosticFinding;

        decision rhythmClassification;
        if features.rhythmRegularity < 0.55 and features.pWavePresent == false then atrialFibrillationFinding;
        if features.qrsDuration > 0.12 [s] and features.heartRate > 120 [beats/min] then wideComplexTachycardiaFinding;
        if features.stDeviationMv >= 0.10 [mV] then stElevationFinding;
        else normalOrNonspecificFinding;

        action atrialFibrillationFinding;
        action wideComplexTachycardiaFinding;
        action stElevationFinding;
        action normalOrNonspecificFinding;
    }

    action def GenerateInterpretationReportAction {
        in context : PatientContext;
        in features : ECGFeatureSet;
        in finding : DiagnosticFinding;
        out report : ECGInterpretationReport;

        constraint reportTraceability {
            report.patientId == context.patientId
        }

        constraint confidencePropagated {
            report.overallConfidence == finding.confidence
        }
    }

    action def EvaluateUrgencyAction {
        in finding : DiagnosticFinding;
        out urgentAlert : DiagnosticFinding;

        constraint urgentAlertCriteria {
            urgentAlert.confidence >= 0.80
        }
    }

    action def ArchiveReportAction {
        in report : ECGInterpretationReport;
        out storedReport : ECGInterpretationReport;

        constraint archivePreservesIdentity {
            storedReport.patientId == report.patientId
        }
    }

    state def ECGInterpretationLifecycle {
        entry; then Idle;

        state Idle;
        state AcquiringECG;
        state CheckingSignalQuality;
        state PreprocessingSignal;
        state ExtractingFeatures;
        state ClassifyingFindings;
        state GeneratingReport;
        state AlertingClinician;
        state Archiving;
        state Complete;
        state AcquisitionFailed;
        state LowSignalQuality;

        transition Idle_to_Acquiring first Idle then AcquiringECG;
        transition Acquiring_to_QualityCheck first AcquiringECG then CheckingSignalQuality;
        transition QualityPass_to_Preprocessing first CheckingSignalQuality if signalQuality >= 0.80 then PreprocessingSignal;
        transition QualityFail_to_LowSignalQuality first CheckingSignalQuality if signalQuality < 0.80 then LowSignalQuality;
        transition Preprocessing_to_Features first PreprocessingSignal then ExtractingFeatures;
        transition Features_to_Classification first ExtractingFeatures then ClassifyingFindings;
        transition Classification_to_Report first ClassifyingFindings then GeneratingReport;
        transition UrgentFinding_to_Alert first GeneratingReport if urgentFindingPresent == true then AlertingClinician;
        transition NonUrgent_to_Archive first GeneratingReport if urgentFindingPresent == false then Archiving;
        transition Alert_to_Archive first AlertingClinician then Archiving;
        transition Archive_to_Complete first Archiving then Complete;
        transition AcquisitionError first AcquiringECG if requiredLeadCountAvailable == false then AcquisitionFailed;

        attribute signalQuality : ConfidenceScore;
        attribute urgentFindingPresent : Boolean;
        attribute requiredLeadCountAvailable : Boolean;
    }

    requirement def PrimaryFunctionRequirement {
        subject interpreter : AutomatedECGInterpreter;

        require constraint {
            interpreter.reportOut.report.summary != ""
        }

        doc /* The automated ECG interpretation system shall transform acquired 12-lead ECG measurements into a high-level clinical interpretation report containing rhythm classification, key interval measurements, confidence, and urgent-finding status. */
    }

    requirement def SamplingRequirement {
        subject acquisition : ECGAcquisitionSubsystem;

        require constraint {
            acquisition.samplingRate >= 250 [Hz]
        }

        doc /* The ECG acquisition subsystem shall sample all required ECG leads at a rate sufficient for clinical rhythm and morphology analysis. */
    }

    requirement def SignalQualityRequirement {
        subject preprocessing : SignalPreprocessingSubsystem;

        require constraint {
            preprocessing.minimumAcceptableQuality >= 0.80
        }

        doc /* The system shall reject or flag ECG segments whose signal quality is insufficient for reliable automated interpretation. */
    }

    requirement def FeatureMeasurementRequirement {
        subject extractor : ECGFeatureExtractionSubsystem;

        require constraint {
            extractor.minimumBeatCount >= 5
        }

        doc /* The feature extraction subsystem shall derive heart rate, RR interval, PR interval, QRS duration, QT interval, corrected QT interval, ST deviation, P-wave presence, and rhythm regularity from accepted ECG segments. */
    }

    requirement def DiagnosticConfidenceRequirement {
        subject classifier : DiagnosticClassificationSubsystem;

        require constraint {
            classifier.minimumDiagnosticConfidence >= 0.70
        }

        doc /* The diagnostic classification subsystem shall assign confidence values to interpreted rhythm and morphology findings. */
    }

    requirement def UrgentAlertRequirement {
        subject monitor : ClinicalSafetyMonitor;

        require constraint {
            monitor.urgentConfidenceThreshold >= 0.80
        }

        doc /* The clinical safety monitor shall emit an urgent alert when a high-confidence potentially critical ECG finding is detected. */
    }

    requirement def AuditabilityRequirement {
        subject store : InterpretationAuditStore;

        require constraint {
            store.immutableAuditTrail == true
        }

        doc /* The system shall preserve generated ECG interpretation reports in an immutable audit trail for clinical traceability. */
    }

    part automatedECGInterpretationSystem : AutomatedECGInterpreter;

}