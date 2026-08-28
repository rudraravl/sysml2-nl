package FotofinderMedicalImagingSystem {
    item def ReadySignal;
    item def StartSessionSignal;
    item def CaptureCompleteSignal;
    item def ProcessCompleteSignal;
    item def AnalyzeCompleteSignal;
    item def StoreCompleteSignal;
    item def ReportCompleteSignal;

    item def Patient {
        attribute id : String;
    }

    item def RawImage {
        attribute width : Integer = 6000;
        attribute height : Integer = 4000;
    }

    item def EnhancedImage {
        attribute width : Integer;
        attribute height : Integer;
    }

    item def AnalysisResult {
        attribute lesionDetected : Boolean;
        attribute riskScore : Real;
        attribute classification : String;
    }

    item def SessionData {
        attribute patientId : String;
    }

    item def SessionReport {
        attribute content : String;
        attribute timestamp : String;
    }

    enum BodyRegion {
        front;
        back;
        left;
        right;
    }

    attribute def Resolution {
        attribute width : Integer = 6000;
        attribute height : Integer = 4000;
    }

    attribute def IlluminationLuminance {
        attribute value : Real;
    }

    attribute def StorageCapacity {
        attribute value : Real;
    }

    port def RawImageOut {
        out item rawImage : RawImage;
    }
    port def RawImageIn {
        in item rawImage : RawImage;
    }
    port def EnhancedImageOut {
        out item enhancedImage : EnhancedImage;
    }
    port def EnhancedImageIn {
        in item enhancedImage : EnhancedImage;
    }
    port def AnalysisResultOut {
        out item result : AnalysisResult;
    }
    port def AnalysisResultIn {
        in item result : AnalysisResult;
    }
    port def SessionDataIn {
        in item data : SessionData;
    }
    port def SessionDataOut {
        out item data : SessionData;
    }
    port def ReportOut {
        out item report : SessionReport;
    }
    port def ControlPort {
        in item command : String;
        out item status : String;
    }

    action def CaptureImages {
        out item images : RawImage;
    }
    action def ProcessImages {
        in item rawImages : RawImage;
        out item enhancedImages : EnhancedImage;
    }
    action def AnalyzeImages {
        in item enhancedImages : EnhancedImage;
        out item result : AnalysisResult;
    }
    action def CompileData {
        in item patient : Patient;
        in item images : EnhancedImage;
        in item analysisResult : AnalysisResult;
        out item data : SessionData;
    }
    action def StoreData {
        in item data : SessionData;
    }
    action def GenerateReport {
        in item data : SessionData;
        out item report : SessionReport;
    }

    action def TotalBodyMapping {
        in item patient : Patient;
        out item report : SessionReport;

        action captureImages : CaptureImages {
            out item images;
        }
        action processImages : ProcessImages {
            in item rawImages;
            out item enhancedImages;
        }
        action analyzeImages : AnalyzeImages {
            in item enhancedImages;
            out item result;
        }
        action compileData : CompileData {
            in item patient;
            in item images;
            in item analysisResult;
            out item data;
        }
        action storeData : StoreData {
            in item data;
        }
        action generateReport : GenerateReport {
            in item data;
            out item report;
        }

        flow from captureImages.images to processImages.rawImages;
        flow from processImages.enhancedImages to analyzeImages.enhancedImages;
        flow from processImages.enhancedImages to compileData.images;
        flow from analyzeImages.result to compileData.analysisResult;
        flow from compileData.data to storeData.data;
        flow from compileData.data to generateReport.data;
        bind compileData.patient = patient;
        bind generateReport.report = report;

        first start;
        then captureImages;
        then processImages;
        then analyzeImages;
        then compileData;
        then storeData;
        then generateReport;
        then done;
    }

    state def FotofinderStates {
        entry;
        then idle;

        state idle;
        transition idle_to_ready
            first idle
            accept ReadySignal
            then ready;

        state ready;
        transition ready_to_capturing
            first ready
            accept StartSessionSignal
            then capturing;

        state capturing;
        transition capturing_to_processing
            first capturing
            accept CaptureCompleteSignal
            then processing;

        state processing;
        transition processing_to_analyzing
            first processing
            accept ProcessCompleteSignal
            then analyzing;

        state analyzing;
        transition analyzing_to_storing
            first analyzing
            accept AnalyzeCompleteSignal
            then storing;

        state storing;
        transition storing_to_reporting
            first storing
            accept StoreCompleteSignal
            then reporting;

        state reporting;
        transition reporting_to_ready
            first reporting
            accept ReportCompleteSignal
            then ready;
    }

    part def Camera {
        attribute resolution : Resolution;
        port imageOut : RawImageOut;
        port controlIn : ControlPort;
    }

    part def IlluminationUnit {
        attribute luminance : IlluminationLuminance;
        port controlIn : ControlPort;
    }

    part def ProcessingUnit {
        port imageIn : RawImageIn;
        port imageOut : EnhancedImageOut;
        port controlIn : ControlPort;
    }

    part def AIEngine {
        attribute accuracy : Real;
        port imageIn : EnhancedImageIn;
        port resultOut : AnalysisResultOut;
        port controlIn : ControlPort;
    }

    part def DataStorage {
        attribute capacity : StorageCapacity;
        port dataIn : SessionDataIn;
        port controlIn : ControlPort;
    }

    part def TouchscreenUI {
        port controlOut : ControlPort;
    }

    part def ControlComputer {
        part ui : TouchscreenUI;
        port cameraControl : ControlPort;
        port illuminationControl : ControlPort;
        port processorControl : ControlPort;
        port aiControl : ControlPort;
        port storageControl : ControlPort;
        port storagePort : SessionDataOut;
        port reportPort : ReportOut;
    }

    part def Fotofinder {
        part camera : Camera;
        part illumination : IlluminationUnit;
        part processor : ProcessingUnit;
        part aiEngine : AIEngine;
        part storage : DataStorage;
        part computer : ControlComputer;

        connection cameraToProcessor {
            end camera.imageOut;
            end processor.imageIn;
        }
        connection processorToAI {
            end processor.imageOut;
            end aiEngine.imageIn;
        }
        connection aiToStorage {
            end aiEngine.resultOut;
            end storage.dataIn;
        }
        connection computerToCamera {
            end computer.cameraControl;
            end camera.controlIn;
        }
        connection computerToIllumination {
            end computer.illuminationControl;
            end illumination.controlIn;
        }
        connection computerToProcessor {
            end computer.processorControl;
            end processor.controlIn;
        }
        connection computerToAI {
            end computer.aiControl;
            end aiEngine.controlIn;
        }
        connection computerToStorageControl {
            end computer.storageControl;
            end storage.controlIn;
        }

        exhibit state fotofinderState : FotofinderStates;
        perform action session : TotalBodyMapping;
    }

    requirement def HighResolutionImaging {
        subject camera : Camera;
        constraint { camera.resolution.width >= 6000 and camera.resolution.height >= 4000 }
    }

    requirement def ColorCalibratedIllumination {
        subject illumination : IlluminationUnit;
    }

    requirement def AIAnalysisAccuracy {
        subject aiEngine : AIEngine;
    }

    requirement def DataStorageCapacity {
        subject storage : DataStorage;
    }

    requirement def ComprehensiveReporting {
        subject computer : ControlComputer;
    }
}
