package ECGInterpretationSystem {
    private import ScalarValues::*;
    
    package DomainTypes {
        attribute def Voltage :> Real;
        attribute def TimeInterval :> Real;
        attribute def Duration :> Real;
        attribute def HeartRate :> Real;
        attribute def Angle :> Real;
        attribute def SNR :> Real;
        attribute def Confidence :> Real;
        
        enum def RhythmClass {
            NORMAL_SINUS;
            ATRIAL_FIBRILLATION;
            ATRIAL_FLUTTER;
            SUPRAVENTRICULAR_TACHYCARDIA;
            VENTRICULAR_TACHYCARDIA;
            VENTRICULAR_FIBRILLATION;
            BRADYCARDIA;
            FIRST_DEGREE_AV_BLOCK;
            SECOND_DEGREE_AV_BLOCK;
            THIRD_DEGREE_AV_BLOCK;
            ASYSTOLE;
        }
        
        enum def AbnormalityType {
            NONE;
            ST_ELEVATION;
            ST_DEPRESSION;
            LEFT_BUNDLE_BRANCH_BLOCK;
            RIGHT_BUNDLE_BRANCH_BLOCK;
            LEFT_VENTRICULAR_HYPERTROPHY;
            RIGHT_VENTRICULAR_HYPERTROPHY;
            PROLONGED_QT;
            T_WAVE_INVERSION;
            PATHOLOGIC_Q_WAVE;
        }
        
        enum def UrgencyLevel {
            ROUTINE;
            URGENT;
            CRITICAL;
        }
        
        item def RawECGSignal {
            attribute leadCount : Integer = 12;
            attribute voltageData : Voltage[12];
            attribute samplingRate : Real;
            attribute duration : Duration;
        }
        
        item def CleanECGSignal {
            attribute leadCount : Integer = 12;
            attribute filteredData : Voltage[12];
            attribute samplingRate : Real;
            attribute duration : Duration;
            attribute snr : SNR;
        }
        
        item def SignalQualityReport {
            attribute snr : SNR;
            attribute isAcceptable : Boolean;
            attribute requiresReacquisition : Boolean;
        }
        
        item def ECGFeatures {
            attribute heartRate : HeartRate;
            attribute prInterval : TimeInterval;
            attribute qrsDuration : TimeInterval;
            attribute qtInterval : TimeInterval;
            attribute qtcInterval : TimeInterval;
            attribute pWaveAmplitude : Voltage;
            attribute rWaveAmplitude : Voltage;
            attribute tWaveAmplitude : Voltage;
            attribute electricalAxis : Angle;
        }
        
        item def RhythmAnalysisResult {
            attribute rhythmClass : RhythmClass;
            attribute rhythmConfidence : Confidence;
            attribute isLifeThreatening : Boolean;
        }
        
        item def AbnormalityResult {
            attribute abnormalityType : AbnormalityType;
            attribute abnormalityConfidence : Confidence;
            attribute description : String;
        }
        
        item def DiagnosticResult {
            attribute diagnosis : String;
            attribute confidence : Confidence;
            attribute urgency : UrgencyLevel;
            attribute requiresPhysicianReview : Boolean;
        }
        
        item def ClinicalReport {
            attribute diagnosis : String;
            attribute confidence : Confidence;
            attribute urgency : UrgencyLevel;
            attribute features : ECGFeatures;
            attribute recommendations : String;
            attribute requiresPhysicianReview : Boolean;
            attribute ehrCompatible : Boolean;
            attribute timestamp : String;
        }
    }
    
    package ECGPorts {
        private import DomainTypes::*;
        
        port def RawSignalOutPort {
            out rawSignal : RawECGSignal;
        }
        
        port def RawSignalInPort {
            in rawSignal : RawECGSignal;
        }
        
        port def CleanSignalOutPort {
            out cleanSignal : CleanECGSignal;
        }
        
        port def CleanSignalInPort {
            in cleanSignal : CleanECGSignal;
        }
        
        port def QualityReportOutPort {
            out qualityReport : SignalQualityReport;
        }
        
        port def FeaturesOutPort {
            out features : ECGFeatures;
        }
        
        port def FeaturesInPort {
            in features : ECGFeatures;
        }
        
        port def RhythmOutPort {
            out rhythmResult : RhythmAnalysisResult;
        }
        
        port def RhythmInPort {
            in rhythmResult : RhythmAnalysisResult;
        }
        
        port def AbnormalityOutPort {
            out abnormalityResult : AbnormalityResult;
        }
        
        port def AbnormalityInPort {
            in abnormalityResult : AbnormalityResult;
        }
        
        port def DiagnosticResultOutPort {
            out diagnosticResult : DiagnosticResult;
        }
        
        port def DiagnosticResultInPort {
            in diagnosticResult : DiagnosticResult;
        }
        
        port def ReportOutPort {
            out report : ClinicalReport;
        }
    }
    
    package ECGActions {
        private import DomainTypes::*;
        
        action def AcquireRawSignal {
            out rawSignal : RawECGSignal;
        }
        
        action def ProcessSignal {
            in rawSignal : RawECGSignal;
            out cleanSignal : CleanECGSignal;
            out qualityReport : SignalQualityReport;
        }
        
        action def ValidateSignalQuality {
            in cleanSignal : CleanECGSignal;
            out qualityReport : SignalQualityReport;
        }
        
        action def ExtractFeatures {
            in cleanSignal : CleanECGSignal;
            out features : ECGFeatures;
        }
        
        action def AnalyzeRhythm {
            in cleanSignal : CleanECGSignal;
            in features : ECGFeatures;
            out rhythmResult : RhythmAnalysisResult;
        }
        
        action def DetectAbnormalities {
            in cleanSignal : CleanECGSignal;
            in features : ECGFeatures;
            out abnormalityResult : AbnormalityResult;
        }
        
        action def SynthesizeDiagnosis {
            in rhythmResult : RhythmAnalysisResult;
            in abnormalityResult : AbnormalityResult;
            in features : ECGFeatures;
            out diagnosticResult : DiagnosticResult;
        }
        
        action def GenerateReport {
            in diagnosticResult : DiagnosticResult;
            in features : ECGFeatures;
            out report : ClinicalReport;
        }
        
        action def ECGInterpretationPipeline {
            in patientSignal : RawECGSignal;
            out clinicalReport : ClinicalReport;
            
            action acquire : AcquireRawSignal {
                out rawSignal;
            }
            then process;
            flow from acquire.rawSignal to process.rawSignal;
            
            action process : ProcessSignal {
                in rawSignal;
                out cleanSignal;
                out qualityReport;
            }
            then validate;
            flow from process.cleanSignal to validate.cleanSignal;
            flow from process.cleanSignal to extract.cleanSignal;
            
            action validate : ValidateSignalQuality {
                in cleanSignal;
                out qualityReport;
            }
            then extract;
            
            action extract : ExtractFeatures {
                in cleanSignal;
                out features;
            }
            then analysisFork;
            flow from extract.features to analyzeRhythm.features;
            flow from extract.features to detectAbnormalities.features;
            flow from process.cleanSignal to analyzeRhythm.cleanSignal;
            flow from process.cleanSignal to detectAbnormalities.cleanSignal;
            
            fork analysisFork;
            then analyzeRhythm;
            then detectAbnormalities;
            
            action analyzeRhythm : AnalyzeRhythm {
                in cleanSignal;
                in features;
                out rhythmResult;
            }
            then analysisJoin;
            
            action detectAbnormalities : DetectAbnormalities {
                in cleanSignal;
                in features;
                out abnormalityResult;
            }
            then analysisJoin;
            
            join analysisJoin;
            then synthesize;
            
            action synthesize : SynthesizeDiagnosis {
                in rhythmResult;
                in abnormalityResult;
                in features;
                out diagnosticResult;
            }
            then generate;
            flow from analyzeRhythm.rhythmResult to synthesize.rhythmResult;
            flow from detectAbnormalities.abnormalityResult to synthesize.abnormalityResult;
            flow from extract.features to synthesize.features;
            
            action generate : GenerateReport {
                in diagnosticResult;
                in features;
                out report;
            }
            flow from synthesize.diagnosticResult to generate.diagnosticResult;
            flow from extract.features to generate.features;
            bind generate.report = clinicalReport;
        }
    }
    
    package ECGStateMachine {
        private import DomainTypes::*;
        
        state def ECGSystemStates {
            state Idle;
            state Acquiring;
            state Processing;
            state Validating;
            state ExtractingFeatures;
            state Analyzing;
            state Diagnosing;
            state Reporting;
            state AwaitingReacquisition;
            state Complete;
            
            transition t1 from Idle to Acquiring;
            transition t2 from Acquiring to Processing;
            transition t3 from Processing to Validating;
            transition t4 from Validating to ExtractingFeatures;
            transition t5 from Validating to AwaitingReacquisition;
            transition t6 from AwaitingReacquisition to Acquiring;
            transition t7 from ExtractingFeatures to Analyzing;
            transition t8 from Analyzing to Diagnosing;
            transition t9 from Diagnosing to Reporting;
            transition t10 from Reporting to Complete;
            transition t11 from Complete to Idle;
        }
    }
    
    package ECGSystemParts {
        private import DomainTypes::*;
        private import ECGPorts::*;
        private import ECGActions::*;
        
        part def SignalAcquisitionModule {
            port rawOut : RawSignalOutPort;
            perform AcquireRawSignal;
        }
        
        part def SignalProcessingModule {
            port rawIn : RawSignalInPort;
            port cleanOut : CleanSignalOutPort;
            port qualityOut : QualityReportOutPort;
            perform ProcessSignal;
            perform ValidateSignalQuality;
        }
        
        part def FeatureExtractionModule {
            port cleanIn : CleanSignalInPort;
            port featOut : FeaturesOutPort;
            perform ExtractFeatures;
        }
        
        part def RhythmAnalysisModule {
            port cleanIn : CleanSignalInPort;
            port featIn : FeaturesInPort;
            port rhythmOut : RhythmOutPort;
            perform AnalyzeRhythm;
            attribute modelType : String = "DeepCNN";
            attribute trainedOn : String = "2M+ ECG records";
        }
        
        part def AbnormalityDetectionModule {
            port cleanIn : CleanSignalInPort;
            port featIn : FeaturesInPort;
            port abnOut : AbnormalityOutPort;
            perform DetectAbnormalities;
            attribute modelType : String = "MultiLabelClassifier";
        }
        
        part def DiagnosticEngine {
            port rhythmIn : RhythmInPort;
            port abnIn : AbnormalityInPort;
            port featIn : FeaturesInPort;
            port diagOut : DiagnosticResultOutPort;
            perform SynthesizeDiagnosis;
        }
        
        part def ReportGenerationModule {
            port diagIn : DiagnosticResultInPort;
            port featIn : FeaturesInPort;
            port reportOut : ReportOutPort;
            perform GenerateReport;
            attribute ehrCompatible : Boolean = true;
        }
        
        part def ECGInterpretationSystem {
            port patientInput : RawSignalInPort;
            port reportOutput : ReportOutPort;
            
            part acquisition : SignalAcquisitionModule;
            part processing : SignalProcessingModule;
            part featureExtraction : FeatureExtractionModule;
            part rhythmAnalysis : RhythmAnalysisModule;
            part abnormalityDetection : AbnormalityDetectionModule;
            part diagnosticEngine : DiagnosticEngine;
            part reportGeneration : ReportGenerationModule;
            
            connect acquisition.rawOut to processing.rawIn;
            connect processing.cleanOut to featureExtraction.cleanIn;
            connect processing.cleanOut to rhythmAnalysis.cleanIn;
            connect processing.cleanOut to abnormalityDetection.cleanIn;
            connect featureExtraction.featOut to rhythmAnalysis.featIn;
            connect featureExtraction.featOut to abnormalityDetection.featIn;
            connect featureExtraction.featOut to diagnosticEngine.featIn;
            connect rhythmAnalysis.rhythmOut to diagnosticEngine.rhythmIn;
            connect abnormalityDetection.abnOut to diagnosticEngine.abnIn;
            connect diagnosticEngine.diagOut to reportGeneration.diagIn;
            connect featureExtraction.featOut to reportGeneration.featIn;
            connect reportGeneration.reportOut to reportOutput;
            
            perform ECGInterpretationPipeline;
            
            attribute maxInterpretationTime : Duration = 15.0;
            attribute systemVersion : String = "ECG-AI-v2.1";
        }
    }
    
    package ECGRequirements {
        private import DomainTypes::*;
        private import ECGSystemParts::*;
        
        requirement def PerformanceRequirement {
            doc "The system shall provide a full ECG interpretation in under 15 seconds."
            attribute maxTime : Duration = 15.0;
        }
        
        requirement def AccuracyRequirement {
            doc "The system shall achieve accuracy >98% for life-threatening arrhythmias."
            attribute minAccuracy : Confidence = 98.0;
        }
        
        requirement def SignalQualityRequirement {
            doc "The system shall validate signal quality and flag reacquisition if SNR is below threshold."
            attribute minSNR : SNR = 20.0;
        }
        
        requirement def RhythmDetectionRequirement {
            doc "The system shall classify heart rhythm including normal sinus, atrial fibrillation, and ventricular tachycardia."
            attribute minRhythmConfidence : Confidence = 90.0;
        }
        
        requirement def AbnormalityDetectionRequirement {
            doc "The system shall detect ST elevation, bundle branch blocks, and ventricular hypertrophy."
        }
        
        requirement def CriticalFindingsRequirement {
            doc "The system shall flag mandatory physician review for all critical findings."
        }
        
        requirement def ReportIntegrationRequirement {
            doc "The generated report shall be structured for integration into electronic health records."
        }
        
        requirement performanceReq : PerformanceRequirement;
        requirement accuracyReq : AccuracyRequirement;
        requirement signalQualityReq : SignalQualityRequirement;
        requirement rhythmDetectionReq : RhythmDetectionRequirement;
        requirement abnormalityDetectionReq : AbnormalityDetectionRequirement;
        requirement criticalFindingsReq : CriticalFindingsRequirement;
        requirement reportIntegrationReq : ReportIntegrationRequirement;
        
        part ecgSystem : ECGInterpretationSystem {
            satisfy performanceReq;
            satisfy accuracyReq;
            satisfy signalQualityReq by processing;
            satisfy rhythmDetectionReq by rhythmAnalysis;
            satisfy abnormalityDetectionReq by abnormalityDetection;
            satisfy criticalFindingsReq by diagnosticEngine;
            satisfy reportIntegrationReq by reportGeneration;
        }
    }
}
