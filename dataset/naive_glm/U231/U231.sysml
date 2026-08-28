package FotofinderSystem {
    import ScalarValues::*;
    
    package ValueTypes {
        attribute def PixelCount :> Integer;
        attribute def ColorTemperature :> Integer;
        attribute def Illuminance :> Real;
        attribute def StorageCapacity :> Real;
        attribute def AccuracyPct :> Real;
        attribute def FrequencyHertz :> Real;
        attribute def DiagonalInches :> Real;
        attribute def MemoryGB :> Real;
        attribute def PatientID :> String;
        attribute def Timestamp :> String;
        attribute def RegionLabel :> String;
        attribute def RiskLevel :> String;
    }
    
    package Items {
        use ValueTypes::*;
        
        item def RawImage {
            attribute width : PixelCount;
            attribute height : PixelCount;
            attribute region : RegionLabel;
            attribute timestamp : Timestamp;
            attribute bitsPerPixel : Integer;
        }
        item def EnhancedImage {
            attribute region : RegionLabel;
            attribute timestamp : Timestamp;
            attribute enhancementApplied : String[0..*];
        }
        item def AnnotatedImage {
            attribute region : RegionLabel;
            attribute lesionBoundingBoxes : String[0..*];
        }
        item def Lesion {
            attribute lesionID : String;
            attribute location : RegionLabel;
            attribute diameter_mm : Real;
            attribute asymmetry : Real;
            attribute borderIrregularity : Real;
            attribute colorVariegation : Real;
            attribute riskScore : Real;
            attribute riskLevel : RiskLevel;
        }
        item def AnalysisResult {
            attribute imageCount : Integer;
            attribute lesions : Lesion[0..*];
            attribute overallRiskScore : Real;
            attribute summaryText : String;
            attribute generatedAt : Timestamp;
        }
        item def SessionData {
            attribute patientID : PatientID;
            attribute sessionStart : Timestamp;
            attribute images : RawImage[0..*];
            attribute enhancedImages : EnhancedImage[0..*];
            attribute analysis : AnalysisResult[0..*];
        }
        item def PatientRecord {
            attribute patientID : PatientID;
            attribute sessions : SessionData[0..*];
        }
        item def SessionReport {
            attribute patientID : PatientID;
            attribute sessionStart : Timestamp;
            attribute generatedAt : Timestamp;
            attribute findings : AnalysisResult[0..*];
            attribute conclusion : String;
            attribute recommendedFollowup : String;
        }
        item def OperatorCommand {
            attribute kind : String;
            attribute patientID : PatientID;
            attribute operatorID : String;
        }
        item def ControlSignal {
            attribute command : String;
            attribute region : RegionLabel;
        }
        item def StatusReport {
            attribute state : String;
            attribute detail : String;
            attribute progressPct : Real;
        }
    }
    
    package Ports {
        use Items::*;
        
        port def ImageOutPort {
            out image : RawImage;
        }
        port def ImageInPort {
            in image : RawImage;
        }
        port def EnhancedImageOutPort {
            out image : EnhancedImage;
        }
        port def EnhancedImageInPort {
            in image : EnhancedImage;
        }
        port def AnnotatedOutPort {
            out image : AnnotatedImage;
        }
        port def AnnotatedInPort {
            in image : AnnotatedImage;
        }
        port def AnalysisOutPort {
            out result : AnalysisResult;
        }
        port def AnalysisInPort {
            in result : AnalysisResult;
        }
        port def SessionDataInPort {
            in data : SessionData;
        }
        port def PatientRecordOutPort {
            out record : PatientRecord;
        }
        port def PatientRecordQueryPort {
            in query : PatientID;
            out record : PatientRecord;
        }
        port def OperatorCommandPort {
            in command : OperatorCommand;
            out status : StatusReport;
        }
        port def ControlOutPort {
            out signal : ControlSignal;
        }
        port def ControlInPort {
            in signal : ControlSignal;
        }
        port def StatusOutPort {
            out status : StatusReport;
        }
        port def IlluminationSyncPort {
            out intensity : Real;
            out colorTemp : Integer;
        }
        port def ReportOutPort {
            out report : SessionReport;
        }
    }
    
    package Connections {
        use Ports::*;
        
        connection def ImageTransfer {
            end source : ImageOutPort;
            end target : ImageInPort;
        }
        connection def EnhancedImageTransfer {
            end source : EnhancedImageOutPort;
            end target : EnhancedImageInPort;
        }
        connection def AnnotatedImageTransfer {
            end source : AnnotatedOutPort;
            end target : AnnotatedInPort;
        }
        connection def AnalysisTransfer {
            end source : AnalysisOutPort;
            end target : AnalysisInPort;
        }
        connection def SessionDataTransfer {
            end source : AnalysisOutPort;
            end target : SessionDataInPort;
        }
        connection def ControlTransfer {
            end sourceControl : ControlOutPort;
            end targetControl : ControlInPort;
        }
        connection def StatusReturn {
            end sourceStatus : StatusOutPort;
            end targetStatus : OperatorCommandPort;
        }
        connection def RecordQuery {
            end sourceQuery : PatientRecordQueryPort;
            end targetQuery : PatientRecordQueryPort;
        }
        connection def ReportFlow {
            end sourceReport : ReportOutPort;
            end targetReport : ReportOutPort;
        }
    }
    
    package Components {
        use ValueTypes::*;
        use Items::*;
        use Ports::*;
        
        part def HighResolutionCamera {
            attribute sensorWidth : PixelCount = 6000;
            attribute sensorHeight : PixelCount = 4000;
            attribute colorDepthBits : Integer = 14;
            attribute frameRateHz : FrequencyHertz = 6.0;
            attribute regionsPerSession : Integer = 4;
            
            port imageOut : ImageOutPort;
            port controlIn : ControlInPort;
            port illuminationSync : IlluminationSyncPort;
            
            action def captureImage(in region : RegionLabel) : RawImage {
                /* trigger sensor, capture frame, output RawImage on imageOut */
            }
            
            state cameraState {
                entry; exit;
                state standby;
                state priming;
                state active;
                transition from standby to priming when controlIn.signal.command == "arm";
                transition from priming to active when illuminationSync.intensity > 9000;
                transition from active to standby when imageOut.image != null;
            }
        }
        
        part def IlluminationUnit {
            attribute colorTempKelvin : ColorTemperature = 5500;
            attribute illuminanceLux : Illuminance = 10000;
            attribute colorCalibrated : Boolean = true;
            attribute shadowFree : Boolean = true;
            attribute warmupSec : Real = 1.5;
            
            port controlIn : ControlInPort;
            port lightSync : IlluminationSyncPort;
            
            action def illuminate(in region : RegionLabel) {
                /* provide calibrated, shadow-free lighting for given region */
            }
        }
        
        part def ControlComputer {
            attribute osName : String = "FotofinderMedicalOS";
            attribute osVersion : String = "3.5";
            attribute cpuCores : Integer = 8;
            attribute ramGB : MemoryGB = 32;
            attribute cycleTimeMs : Real = 50;
            
            port operatorInterface : OperatorCommandPort;
            port cameraControl : ControlOutPort;
            port illuminationControl : ControlOutPort;
            port processingControl : ControlOutPort;
            port aiControl : ControlOutPort;
            port storageControl : ControlOutPort;
            port reportControl : ControlOutPort;
            port statusIn : ControlInPort;
            
            action def startSession(in command : OperatorCommand) {
                /* initialize a total body mapping session */
            }
            action def coordinateCapture(in regions : RegionLabel[0..*]) {
                /* orchestrate sequential capture across regions */
            }
            action def endSession() {
                /* finalize session, return system to ready */
            }
        }
        
        part def TouchscreenUI {
            attribute screenDiagonalIn : DiagonalInches = 27;
            attribute resolutionWidthPx : PixelCount = 3840;
            attribute resolutionHeightPx : PixelCount = 2160;
            attribute multitouch : Boolean = true;
            
            port operatorCommand : OperatorCommandPort;
            port systemStatus : StatusOutPort;
            
            action def displaySessionProgress(in state : String, in progressPct : Real) {
                /* show current session state and progress to operator */
            }
            action def receiveOperatorCommand() : OperatorCommand {
                /* capture operator input via touchscreen */
            }
            action def renderReport(in report : SessionReport) {
                /* display generated report on screen */
            }
        }
        
        part def ImageProcessingUnit {
            attribute enhancementPipeline : String[0..*] = ("denoise", "colorBalance", "contrast", "shadowRemoval");
            attribute throughputFPS : FrequencyHertz = 5.0;
            attribute latencyMs : Real = 200;
            
            port imageIn : ImageInPort;
            port enhancedOut : EnhancedImageOutPort;
            port controlIn : ControlInPort;
            
            action def enhance(in raw : RawImage) : EnhancedImage {
                /* apply denoise, color balance, contrast, and shadow removal to raw image */
            }
            action def processBatch(in images : RawImage[0..*]) : EnhancedImage[0..*] {
                /* enhance each image in batch */
            }
        }
        
        part def AIAnalysisEngine {
            attribute modelVersion : String = "FotofinderAI-v3.2";
            attribute trainingDatasetSize : Integer = 250000;
            attribute accuracyPct : AccuracyPct = 96.5;
            attribute falsePositiveRatePct : Real = 2.1;
            attribute falseNegativeRatePct : Real = 1.4;
            attribute lesionDetectionEnabled : Boolean = true;
            attribute identificationEnabled : Boolean = true;
            attribute riskAssessmentEnabled : Boolean = true;
            
            port enhancedIn : EnhancedImageInPort;
            port annotatedOut : AnnotatedOutPort;
            port analysisOut : AnalysisOutPort;
            port controlIn : ControlInPort;
            
            action def detect(in image : EnhancedImage) : Lesion[0..*] {
                /* detect suspicious lesions in enhanced image */
            }
            action def identify(in lesion : Lesion) : Lesion {
                /* classify lesion characteristics */
            }
            action def assessRisk(in lesions : Lesion[0..*]) : AnalysisResult {
                /* compute risk score per lesion and overall risk summary */
            }
            action def analyzeBatch(in images : EnhancedImage[0..*]) : AnalysisResult {
                /* process all enhanced images and produce overall session analysis */
            }
        }
        
        part def DataStorage {
            attribute capacityGB : StorageCapacity = 4096;
            attribute raidLevel : Integer = 6;
            attribute encryptionEnabled : Boolean = true;
            attribute backupEnabled : Boolean = true;
            attribute retentionYears : Integer = 10;
            
            port dataIn : SessionDataInPort;
            port recordOut : PatientRecordOutPort;
            port queryPort : PatientRecordQueryPort;
            port controlIn : ControlInPort;
            
            action def store(in data : SessionData) {
                /* persist session data with encryption and backup */
            }
            action def retrieve(in pid : PatientID) : PatientRecord {
                /* retrieve historical record for the patient */
            }
            action def compareSessions(in current : SessionData, in previous : PatientRecord) : AnalysisResult {
                /* compare current session with prior records to identify changes */
            }
        }
        
        part def ReportGenerator {
            attribute templateType : String = "DermatologyStandard";
            attribute includeImages : Boolean = true;
            attribute includeRiskTrends : Boolean = true;
            
            port analysisIn : AnalysisInPort;
            port recordIn : PatientRecordQueryPort;
            port reportOut : ReportOutPort;
            port controlIn : ControlInPort;
            
            action def generateReport(in pid : PatientID, in findings : AnalysisResult[0..*], in history : PatientRecord) : SessionReport {
                /* compile a comprehensive report of findings, trends, and follow-up */
            }
        }
    }
    
    package SystemAssembly {
        use Components::*;
        use Connections::*;
        use Items::*;
        use Ports::*;
        use ValueTypes::*;
        
        part def Fotofinder {
            attribute systemName : String = "Fotofinder";
            attribute systemVersion : String = "4.2";
            attribute clinicalUse : String = "Dermatology total body photography and melanoma early detection";
            attribute regionsPerSession : RegionLabel[6] = ("front", "back", "leftSide", "rightSide", "headNeck", "extremities");
            
            part camera : HighResolutionCamera;
            part illumination : IlluminationUnit;
            part controlComputer : ControlComputer;
            part ui : TouchscreenUI;
            part imageProcessor : ImageProcessingUnit;
            part aiEngine : AIAnalysisEngine;
            part storage : DataStorage;
            part reportGen : ReportGenerator;
            
            port operatorUI : OperatorCommandPort;
            port reportExport : ReportOutPort;
            port recordQuery : PatientRecordQueryPort;
            
            connection : ControlTransfer connect ui.operatorCommand to controlComputer.operatorInterface;
            connection : ControlTransfer connect controlComputer.cameraControl to camera.controlIn;
            connection : ControlTransfer connect controlComputer.illuminationControl to illumination.controlIn;
            connection : ControlTransfer connect controlComputer.processingControl to imageProcessor.controlIn;
            connection : ControlTransfer connect controlComputer.aiControl to aiEngine.controlIn;
            connection : ControlTransfer connect controlComputer.storageControl to storage.controlIn;
            connection : ControlTransfer connect controlComputer.reportControl to reportGen.controlIn;
            
            connection : ImageTransfer connect camera.imageOut to imageProcessor.imageIn;
            connection : EnhancedImageTransfer connect imageProcessor.enhancedOut to aiEngine.enhancedIn;
            connection : AnalysisTransfer connect aiEngine.analysisOut to reportGen.analysisIn;
            connection : SessionDataTransfer connect aiEngine.analysisOut to storage.dataIn;
            connection : ReportFlow connect reportGen.reportOut to reportExport;
            connection : RecordQuery connect recordQuery to storage.queryPort;
            
            state operatingState {
                entry; exit;
                
                state idle {
                    entry { /* system initialized, awaiting power-on self-test completion */ }
                }
                state ready {
                    entry { /* system ready for new patient session */ }
                }
                state imagingSession {
                    state capturing;
                    state processing;
                    state analyzing;
                    state storing;
                    state reportGeneration;
                }
                
                attribute initialized : Boolean = false;
                attribute captureComplete : Boolean = false;
                attribute enhancementComplete : Boolean = false;
                attribute analysisComplete : Boolean = false;
                attribute storageComplete : Boolean = false;
                attribute reportComplete : Boolean = false;
                attribute sessionStarted : Boolean = false;
                
                transition from idle to ready when initialized;
                transition from ready to imagingSession::capturing when operatorUI.command.kind == "startSession";
                transition from capturing to processing when captureComplete;
                transition from processing to analyzing when enhancementComplete;
                transition from analyzing to storing when analysisComplete;
                transition from storing to reportGeneration when storageComplete;
                transition from reportGeneration to ready when reportComplete;
            }
            
            action def performTotalBodyMapping(in pid : PatientID) {
                first captureAllRegions(pid);
                then enhanceImages();
                then analyzeImages();
                then storeSession(pid);
                then generateReport(pid);
            }
            
            action def captureAllRegions(in pid : PatientID) {
                /* orchestrate sequential capture across all body regions */
            }
            action def enhanceImages() {
                /* pass captured raw images to the image processing unit */
            }
            action def analyzeImages() {
                /* pass enhanced images to the AI analysis engine */
            }
            action def storeSession(in pid : PatientID) {
                /* persist session data in the data storage system */
            }
            action def generateReport(in pid : PatientID) {
                /* generate the comprehensive session report */
            }
        }
    }
    
    package Requirements {
        use ValueTypes::*;
        use Items::*;
        use Components::*;
        use SystemAssembly::*;
        
        requirement def TotalBodyMappingCapability {
            subject system : Fotofinder;
            doc /* The system shall create a complete high-resolution photographic map of a patient's skin. */;
            objective {
                doc /* The Fotofinder shall produce a complete photographic map covering all major body regions. */;
            }
        }
        
        requirement def HighResolutionImaging {
            subject camera : HighResolutionCamera;
            attribute minResolutionWidth : PixelCount = 6000;
            attribute minResolutionHeight : PixelCount = 4000;
            objective {
                doc /* The camera shall capture images at a resolution of at least 6000x4000 pixels. */;
            }
        }
        
        requirement def CalibratedIllumination {
            subject illumination : IlluminationUnit;
            attribute targetColorTemp : ColorTemperature = 5500;
            attribute minIlluminance : Illuminance = 9000;
            objective {
                doc /* The illumination unit shall provide consistent, color-calibrated, shadow-free lighting to enable comparable images across sessions. */;
            }
        }
        
        requirement def AutomatedCaptureSequence {
            subject system : Fotofinder;
            attribute requiredRegions : RegionLabel[6] = ("front", "back", "leftSide", "rightSide", "headNeck", "extremities");
            objective {
                doc /* The system shall automatically capture images covering the front, back, and both sides of the patient during a total body mapping session. */;
            }
        }
        
        requirement def ImageEnhancement {
            subject processor : ImageProcessingUnit;
            objective {
                doc /* Raw images shall be enhanced by the image processing unit before AI analysis. */;
            }
        }
        
        requirement def AILesionDetection {
            subject engine : AIAnalysisEngine;
            attribute minAccuracy : AccuracyPct = 90.0;
            objective {
                doc /* The AI analysis engine shall detect, identify, and provide risk assessments for suspicious skin lesions with high accuracy. */;
            }
        }
        
        requirement def DataPersistence {
            subject storage : DataStorage;
            attribute minCapacity : StorageCapacity = 2000;
            objective {
                doc /* All session data including patient ID, captured images, and AI analysis results shall be stored to enable historical tracking. */;
            }
        }
        
        requirement def HistoricalTracking {
            subject system : Fotofinder;
            objective {
                doc /* The system shall allow clinicians to track changes in moles and other skin lesions over time per patient. */;
            }
        }
        
        requirement def ReportGeneration {
            subject reportGen : ReportGenerator;
            objective {
                doc /* The system shall generate a comprehensive report summarizing the findings of each session. */;
            }
        }
        
        requirement def OperatorInterface {
            subject ui : TouchscreenUI;
            attribute minDiagonalInches : DiagonalInches = 20;
            objective {
                doc /* The operator shall interact with the system through a large touchscreen user interface. */;
            }
        }
        
        requirement def CentralControl {
            subject computer : ControlComputer;
            attribute osName : String = "FotofinderMedicalOS";
            objective {
                doc /* A central control computer running a dedicated medical operating system shall manage the entire imaging process. */;
            }
        }
        
        requirement def StateDrivenOperation {
            subject system : Fotofinder;
            attribute requiredStates : String[7] = ("idle", "ready", "capturing", "processing", "analyzing", "storing", "reportGeneration");
            objective {
                doc /* The system shall transition through idle, ready, capturing, processing, analyzing, storing, and report generation states before returning to ready. */;
            }
        }
        
        requirement FotofinderRequirements {
            subject system : Fotofinder;
            requirement t1 : TotalBodyMappingCapability;
            requirement t2 : HighResolutionImaging;
            requirement t3 : CalibratedIllumination;
            requirement t4 : AutomatedCaptureSequence;
            requirement t5 : ImageEnhancement;
            requirement t6 : AILesionDetection;
            requirement t7 : DataPersistence;
            requirement t8 : HistoricalTracking;
            requirement t9 : ReportGeneration;
            requirement t10 : OperatorInterface;
            requirement t11 : CentralControl;
            requirement t12 : StateDrivenOperation;
        }
    }
}
