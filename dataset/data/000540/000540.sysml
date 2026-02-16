package AutomatedECGInterpretationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SignalQualityMetrics {
        attribute signalToNoiseRatio : Real;
        attribute baselineWander : LengthValue;
        attribute artifactLevel : Real;
    }
    
    enum def RhythmClassification {
        enum normalSinusRhythm;
        enum atrialFibrillation;
        enum atrialFlutter;
        enum ventricularTachycardia;
        enum ventricularFibrillation;
        enum bradycardia;
        enum tachycardia;
        enum prematureVentricularContraction;
        enum prematureAtrialContraction;
    }
    
    enum def AbnormalityType {
        enum stElevation;
        enum stDepression;
        enum tWaveInversion;
        enum pathologicalQWave;
        enum prolongedQT;
        enum leftVentricularHypertrophy;
        enum rightBundleBranchBlock;
        enum leftBundleBranchBlock;
    }
    
    item def RawECGSignal {
        attribute leadI : ElectricPotentialValue;
        attribute leadII : ElectricPotentialValue;
        attribute leadIII : ElectricPotentialValue;
        attribute aVR : ElectricPotentialValue;
        attribute aVL : ElectricPotentialValue;
        attribute aVF : ElectricPotentialValue;
        attribute V1 : ElectricPotentialValue;
        attribute V2 : ElectricPotentialValue;
        attribute V3 : ElectricPotentialValue;
        attribute V4 : ElectricPotentialValue;
        attribute V5 : ElectricPotentialValue;
        attribute V6 : ElectricPotentialValue;
        attribute samplingRate : FrequencyValue;
        attribute timestamp : TimeValue;
    }
    
    item def FilteredECGSignal {
        attribute processedLeads : ElectricPotentialValue[12];
        attribute qualityMetrics : SignalQualityMetrics;
        attribute duration : TimeValue;
    }
    
    item def ECGFeatureSet {
        attribute heartRate : FrequencyValue;
        attribute rrIntervals : TimeValue[*];
        attribute pWaveDuration : TimeValue;
        attribute prInterval : TimeValue;
        attribute qrsDuration : TimeValue;
        attribute qtInterval : TimeValue;
        attribute qtcInterval : TimeValue;
        attribute stSegmentLevel : LengthValue[12];
        attribute tWaveAmplitude : LengthValue[12];
        attribute qrsAxis : Real;
        attribute pWaveAxis : Real;
    }
    
    item def DiagnosticResult {
        attribute rhythmType : RhythmClassification;
        attribute detectedAbnormalities : AbnormalityType[*];
        attribute confidenceScore : Real;
        attribute urgencyLevel : Integer;
        attribute clinicalFindings : String[*];
    }
    
    item def InterpretationReport {
        attribute patientID : String;
        attribute acquisitionTime : TimeValue;
        attribute diagnosticResult : DiagnosticResult;
        attribute featureSummary : ECGFeatureSet;
        attribute requiresPhysicianReview : Boolean;
        attribute recommendations : String[*];
    }
    
    port def ECGSignalInputPort {
        in rawSignal : RawECGSignal;
    }
    
    port def ECGSignalOutputPort {
        out processedSignal : FilteredECGSignal;
    }
    
    port def FeatureOutputPort {
        out features : ECGFeatureSet;
    }
    
    port def DiagnosticOutputPort {
        out diagnosis : DiagnosticResult;
    }
    
    port def ReportOutputPort {
        out report : InterpretationReport;
    }
    
    action def AcquireECGData {
        in patientID : String;
        in leadConfiguration : String;
        out rawSignal : RawECGSignal;
    }
    
    action def FilterSignal {
        in rawSignal : RawECGSignal;
        out filteredSignal : FilteredECGSignal;
    }
    
    action def ValidateSignalQuality {
        in signal : FilteredECGSignal;
        out qualityMetrics : SignalQualityMetrics;
        out isValid : Boolean;
    }
    
    action def ExtractFeatures {
        in signal : FilteredECGSignal;
        out features : ECGFeatureSet;
    }
    
    action def DetectRhythm {
        in features : ECGFeatureSet;
        out rhythmType : RhythmClassification;
        out confidence : Real;
    }
    
    action def IdentifyAbnormalities {
        in features : ECGFeatureSet;
        in signal : FilteredECGSignal;
        out abnormalities : AbnormalityType[*];
    }
    
    action def GenerateDiagnosis {
        in rhythmType : RhythmClassification;
        in abnormalities : AbnormalityType[*];
        in features : ECGFeatureSet;
        out diagnosis : DiagnosticResult;
    }
    
    action def CreateReport {
        in diagnosis : DiagnosticResult;
        in features : ECGFeatureSet;
        in patientID : String;
        out report : InterpretationReport;
    }
    
    action def PerformECGInterpretation {
        in patientID : String;
        out finalReport : InterpretationReport;
        
        first start;
        then action acquire : AcquireECGData {
            in patientID = patientID;
            in leadConfiguration = "12-lead";
            out rawSignal;
        }
        then action filter : FilterSignal {
            in rawSignal = acquire.rawSignal;
            out filteredSignal;
        }
        then action validate : ValidateSignalQuality {
            in signal = filter.filteredSignal;
            out qualityMetrics;
            out isValid;
        }
        then decide;
            if validate.isValid then extractFeatures;
            if !validate.isValid then reacquire;
        action reacquire : AcquireECGData {
            in patientID = patientID;
            in leadConfiguration = "12-lead";
            out rawSignal;
        }
        then merge continueAnalysis;
        action extractFeatures : ExtractFeatures {
            in signal = filter.filteredSignal;
            out features;
        }
        then continueAnalysis;
        then action detectRhythm : DetectRhythm {
            in features = extractFeatures.features;
            out rhythmType;
            out confidence;
        }
        then action identifyAbnormalities : IdentifyAbnormalities {
            in features = extractFeatures.features;
            in signal = filter.filteredSignal;
            out abnormalities;
        }
        then action generateDiagnosis : GenerateDiagnosis {
            in rhythmType = detectRhythm.rhythmType;
            in abnormalities = identifyAbnormalities.abnormalities;
            in features = extractFeatures.features;
            out diagnosis;
        }
        then action createReport : CreateReport {
            in diagnosis = generateDiagnosis.diagnosis;
            in features = extractFeatures.features;
            in patientID = patientID;
            out report;
        }
        then assign finalReport := createReport.report;
        then done;
    }
    
    state def ECGAnalysisStateMachine {
        entry; then idle;
        
        state idle {
            doc /* System waiting for ECG acquisition request */
        }
        transition idle_to_acquiring
            first idle
            accept AcquisitionRequest
            then acquiring;
        
        state acquiring {
            doc /* Acquiring ECG signal from electrodes */
            entry; then collectingData;
            state collectingData;
            transition collectingData_to_filtering
                first collectingData
                if dataComplete
                then filtering;
            state filtering;
        }
        transition acquiring_to_validating
            first acquiring
            then validating;
        
        state validating {
            doc /* Checking signal quality */
        }
        transition validating_to_acquiring
            first validating
            if signalQualityPoor
            then acquiring;
        transition validating_to_analyzing
            first validating
            if signalQualityGood
            then analyzing;
        
        state analyzing {
            doc /* Extracting features and performing interpretation */
            entry; then featureExtraction;
            state featureExtraction;
            transition featureExtraction_to_rhythmDetection
                first featureExtraction
                then rhythmDetection;
            state rhythmDetection;
            transition rhythmDetection_to_abnormalityDetection
                first rhythmDetection
                then abnormalityDetection;
            state abnormalityDetection;
        }
        transition analyzing_to_reporting
            first analyzing
            then reporting;
        
        state reporting {
            doc /* Generating interpretation report */
        }
        transition reporting_to_idle
            first reporting
            then idle;
    }
    
    part def ECGAcquisitionModule {
        port signalOut : ECGSignalOutputPort;
        attribute samplingFrequency : FrequencyValue = 500.0;
        attribute bitResolution : Integer = 16;
        perform action acquire : AcquireECGData;
    }
    
    part def SignalProcessingModule {
        port signalIn : ECGSignalInputPort;
        port signalOut : ECGSignalOutputPort;
        attribute highPassCutoff : FrequencyValue = 0.5;
        attribute lowPassCutoff : FrequencyValue = 150.0;
        attribute notchFrequency : FrequencyValue = 60.0;
        perform action filter : FilterSignal;
        perform action validate : ValidateSignalQuality;
    }
    
    part def FeatureExtractionModule {
        port signalIn : ECGSignalInputPort;
        port featuresOut : FeatureOutputPort;
        attribute peakDetectionThreshold : Real = 0.6;
        attribute windowSize : TimeValue = 10.0;
        perform action extract : ExtractFeatures;
    }
    
    part def RhythmAnalysisModule {
        port featuresIn : FeatureOutputPort;
        port diagnosticOut : DiagnosticOutputPort;
        attribute modelVersion : String = "v3.2.1";
        attribute classificationAlgorithm : String = "DeepConvolutionalNeuralNetwork";
        perform action detectRhythm : DetectRhythm;
    }
    
    part def AbnormalityDetectionModule {
        port featuresIn : FeatureOutputPort;
        port signalIn : ECGSignalInputPort;
        port diagnosticOut : DiagnosticOutputPort;
        attribute sensitivityLevel : Real = 0.92;
        attribute specificityLevel : Real = 0.88;
        perform action identifyAbnormalities : IdentifyAbnormalities;
    }
    
    part def DiagnosticEngineModule {
        port rhythmIn : DiagnosticOutputPort;
        port abnormalitiesIn : DiagnosticOutputPort;
        port featuresIn : FeatureOutputPort;
        port diagnosticOut : DiagnosticOutputPort;
        attribute knowledgeBaseVersion : String = "CardiacDB_2024";
        attribute confidenceThreshold : Real = 0.85;
        perform action generateDiagnosis : GenerateDiagnosis;
    }
    
    part def ReportGenerationModule {
        port diagnosticIn : DiagnosticOutputPort;
        port featuresIn : FeatureOutputPort;
        port reportOut : ReportOutputPort;
        attribute reportFormat : String = "HL7-FHIR";
        perform action createReport : CreateReport;
    }
    
    part def AutomatedECGInterpretationSystem {
        doc /* 
            The Automated ECG Interpretation System acquires, processes, and analyzes 
            electrocardiogram signals to provide rapid, accurate cardiac rhythm classification 
            and abnormality detection. The system automatically extracts clinical features, 
            applies machine learning algorithms for pattern recognition, and generates 
            comprehensive diagnostic reports to support clinical decision-making.
        */
        
        part acquisitionModule : ECGAcquisitionModule;
        part processingModule : SignalProcessingModule;
        part featureModule : FeatureExtractionModule;
        part rhythmModule : RhythmAnalysisModule;
        part abnormalityModule : AbnormalityDetectionModule;
        part diagnosticEngine : DiagnosticEngineModule;
        part reportModule : ReportGenerationModule;
        
        connect acquisitionModule.signalOut to processingModule.signalIn;
        connect processingModule.signalOut to featureModule.signalIn;
        connect processingModule.signalOut to abnormalityModule.signalIn;
        connect featureModule.featuresOut to rhythmModule.featuresIn;
        connect featureModule.featuresOut to abnormalityModule.featuresIn;
        connect featureModule.featuresOut to diagnosticEngine.featuresIn;
        connect rhythmModule.diagnosticOut to diagnosticEngine.rhythmIn;
        connect abnormalityModule.diagnosticOut to diagnosticEngine.abnormalitiesIn;
        connect diagnosticEngine.diagnosticOut to reportModule.diagnosticIn;
        connect featureModule.featuresOut to reportModule.featuresIn;
        
        perform action interpretECG : PerformECGInterpretation;
        exhibit state analysisStateMachine : ECGAnalysisStateMachine;
    }
    
    requirement def AccuracyRequirement {
        doc /* 
            The system shall achieve minimum 95% sensitivity and 92% specificity 
            for detecting life-threatening arrhythmias including ventricular 
            fibrillation and ventricular tachycardia.
        */
        attribute minimumSensitivity : Real = 0.95;
        attribute minimumSpecificity : Real = 0.92;
    }
    
    requirement def ProcessingTimeRequirement {
        doc /* 
            The system shall complete full ECG interpretation and generate 
            a diagnostic report within 15 seconds of signal acquisition completion.
        */
        attribute maximumProcessingTime : TimeValue = 15.0;
    }
    
    requirement def SignalQualityRequirement {
        doc /* 
            The system shall automatically assess signal quality and reject 
            signals with signal-to-noise ratio below 20 dB, requesting reacquisition.
        */
        attribute minimumSNR : Real = 20.0;
    }
    
    requirement def ReportCompletenessRequirement {
        doc /* 
            The interpretation report shall include rhythm classification, 
            all detected abnormalities with confidence scores, measured intervals, 
            and clinical recommendations.
        */
    }
    
    requirement def SafetyRequirement {
        doc /* 
            The system shall flag all critical findings for mandatory physician 
            review and shall not be used as the sole basis for clinical decisions.
        */
    }
    
    requirement systemMissionRequirement {
        doc /* 
            The Automated ECG Interpretation System shall provide rapid, accurate, 
            and consistent analysis of 12-lead electrocardiogram signals to support 
            timely clinical decision-making and improve patient outcomes.
        */
        
        require AccuracyRequirement;
        require ProcessingTimeRequirement;
        require SignalQualityRequirement;
        require ReportCompletenessRequirement;
        require SafetyRequirement;
    }
    
    part ecgSystem : AutomatedECGInterpretationSystem {
        satisfy systemMissionRequirement;
    }
}
