package 'Machine Vision QC System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    item def TriggerSignal;
    item def ImageData;
    item def EnhancedImageData;
    item def Error;
    item def Reset;
    item def ControlCommand {
        attribute pass : Boolean;
    }
    attribute def Coordinate {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }
    enum def DefectType {
        Scratch;
        Dent;
        Crack;
        Discoloration;
    }
    enum def Severity {
        Low;
        Medium;
        High;
    }
    attribute def Defect {
        attribute type : DefectType;
        attribute location : Coordinate;
        attribute severity : Severity;
        attribute confidence : Real;
    }
    item def InspectionReport {
        attribute defects : Defect[0..*];
    }
    attribute def QualityCriteria {
        attribute maxDefects : Integer = 5;
        attribute minConfidence : Real = 0.9;
    }
    
    port def TriggerPort {
        out signal : TriggerSignal;
    }
    port def ImagePort {
        out image : ImageData;
    }
    port def EnhancedImagePort {
        out enhancedImage : EnhancedImageData;
    }
    port def ReportPort {
        out report : InspectionReport;
    }
    port def CommandPort {
        out command : ControlCommand;
    }
    
    action def CaptureImage {
        in trigger : TriggerSignal;
        out image : ImageData;
    }
    action def ProvideIllumination {
        in trigger : TriggerSignal;
    }
    action def PreprocessImage {
        in rawImage : ImageData;
        out enhancedImage : EnhancedImageData;
    }
    action def AnalyzeImage {
        in enhancedImage : EnhancedImageData;
        out report : InspectionReport;
    }
    action def DecideQuality {
        in report : InspectionReport;
        in criteria : QualityCriteria;
        out command : ControlCommand;
    }
    action def HandlePart {
        in command : ControlCommand;
    }
    
    part def ConveyorInterface {
        port triggerOut : TriggerPort;
        action monitor;
    }
    part def IlluminationUnit {
        port triggerIn : TriggerPort;
        action illuminate : ProvideIllumination {
            in trigger : TriggerSignal = triggerIn.signal;
        }
    }
    part def DigitalCamera {
        port triggerIn : TriggerPort;
        port imageOut : ImagePort;
        action capture : CaptureImage {
            in trigger : TriggerSignal = triggerIn.signal;
            out image : ImageData;
        }
        flow from capture.image to imageOut.image;
    }
    part def ImagePreprocessor {
        port imageIn : ImagePort;
        port enhancedOut : EnhancedImagePort;
        action preprocess : PreprocessImage {
            in rawImage : ImageData = imageIn.image;
            out enhancedImage : EnhancedImageData;
        }
        flow from preprocess.enhancedImage to enhancedOut.enhancedImage;
    }
    part def DefectDetectionEngine {
        port imageIn : EnhancedImagePort;
        port reportOut : ReportPort;
        action analyze : AnalyzeImage {
            in enhancedImage : EnhancedImageData = imageIn.enhancedImage;
            out report : InspectionReport;
        }
        flow from analyze.report to reportOut.report;
    }
    part def QualityDecisionModule {
        port reportIn : ReportPort;
        port commandOut : CommandPort;
        attribute criteria : QualityCriteria;
        action evaluate : DecideQuality {
            in report : InspectionReport = reportIn.report;
            in criteria : QualityCriteria = criteria;
            out command : ControlCommand;
        }
        flow from evaluate.command to commandOut.command;
    }
    part def ConveyorSystem {
        port commandIn : CommandPort;
        action handle : HandlePart {
            in command : ControlCommand = commandIn.command;
        }
    }
    
    state def InspectionStates {
        entry; then idle;
        state idle;
        accept TriggerSignal
            then acquiring;
        state acquiring;
        transition first acquiring then processing;
        state processing;
        transition first processing then analyzing;
        state analyzing;
        transition first analyzing then deciding;
        state deciding;
        transition first deciding then idle;
        
        state fault;
        transition first idle accept Error then fault;
        transition first acquiring accept Error then fault;
        transition first processing accept Error then fault;
        transition first analyzing accept Error then fault;
        transition first deciding accept Error then fault;
        transition first fault accept Reset then idle;
    }
    
    part def MachineVisionSystem {
        port trigger : TriggerPort;
        part conveyorInterface : ConveyorInterface;
        part illuminationUnit : IlluminationUnit;
        part digitalCamera : DigitalCamera;
        part imagePreprocessor : ImagePreprocessor;
        part defectDetectionEngine : DefectDetectionEngine;
        part qualityDecisionModule : QualityDecisionModule;
        part conveyorSystem : ConveyorSystem;
        
        connect trigger to illuminationUnit.triggerIn;
        connect trigger to digitalCamera.triggerIn;
        connect conveyorInterface.triggerOut to illuminationUnit.triggerIn;
        connect conveyorInterface.triggerOut to digitalCamera.triggerIn;
        connect digitalCamera.imageOut to imagePreprocessor.imageIn;
        connect imagePreprocessor.enhancedOut to defectDetectionEngine.imageIn;
        connect defectDetectionEngine.reportOut to qualityDecisionModule.reportIn;
        connect qualityDecisionModule.commandOut to conveyorSystem.commandIn;
        
        exhibit state inspectionStates : InspectionStates;
    }
    
    requirement def QualityControlRequirement {
        doc /* The system shall automatically inspect parts on a conveyor belt, identify manufacturing defects, and make real-time pass/fail decisions. */
    }
    
    requirement def DefectDetectionRequirement {
        doc /* The system shall detect and classify defects including type, location, severity, and confidence score. */
    }
    
    requirement def InspectionCycleRequirement {
        doc /* The system shall execute an inspection cycle consisting of idle, acquiring, processing, analyzing, and deciding states, with a fault state for error handling. */
    }
    
    requirement qcReq : QualityControlRequirement;
    requirement ddReq : DefectDetectionRequirement;
    requirement icReq : InspectionCycleRequirement;
    
    satisfy qcReq by MachineVisionSystem;
    satisfy ddReq by MachineVisionSystem.defectDetectionEngine;
    satisfy icReq by MachineVisionSystem.inspectionStates;
}
