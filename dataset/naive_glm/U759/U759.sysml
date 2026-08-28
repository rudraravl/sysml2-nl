package MachineVisionQC {

    import ScalarValues::*;

    // ============================================================
    // Value Types and Units
    // ============================================================

    value def ConfidenceScore :> Real {
        doc /* Confidence score in the range [0.0, 1.0] */
    }

    value def SeverityLevel :> Integer {
        doc /* Defect severity from 1 (minor) to 5 (critical) */
    }

    value def PixelCount :> Integer;
    value def DefectCount :> Integer;
    value def MaxDefectsAllowed :> Integer;
    value def MinConfidenceThreshold :> Real;

    value def Duration :> Real;
    unit ms of Duration;

    // ============================================================
    // Enumerations
    // ============================================================

    enum def CommandStatus {
        accept;
        reject;
    }

    enum def DefectType {
        scratch;
        dent;
        crack;
        discoloration;
        deformation;
        missing_feature;
    }

    // ============================================================
    // Item Types
    // ============================================================

    item def TriggerSignal {
        attribute partId : String;
        attribute timestamp : Real;
    }

    item def ControlCommand {
        attribute partId : String;
        attribute status : CommandStatus;
    }

    item def Image {
        attribute partId : String;
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute isRaw : Boolean;
    }

    item def Defect {
        attribute defectType : DefectType;
        attribute locationX : Real;
        attribute locationY : Real;
        attribute severity : SeverityLevel;
        attribute confidence : ConfidenceScore;
    }

    item def InspectionReport {
        attribute partId : String;
        attribute defects : Defect[0..*];
        attribute defectCount : DefectCount;
        attribute overallConfidence : ConfidenceScore;
        attribute timestamp : Real;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def TriggerPort {
        out trigger : TriggerSignal;
    }

    port def LightControlPort {
        out activate : Boolean;
    }

    port def ImagePort {
        out image : Image;
    }

    port def ReportPort {
        out report : InspectionReport;
    }

    port def CommandPort {
        out command : ControlCommand;
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================

    part def ConveyorInterface {
        doc /* Monitors the production line and sends trigger signals when a part is in position. */

        port out triggerPort : TriggerPort;
        port out lightControlPort : LightControlPort;
        port in commandPort : CommandPort;
        port out lineCommandPort : CommandPort;

        attribute partPresent : Boolean = false;
        attribute currentPartId : String;

        action def DetectPart {
            in sensorReading : Boolean;
            out trigger : TriggerSignal;
        }

        action def ForwardCommand {
            in command : ControlCommand;
            out forwarded : ControlCommand;
        }
    }

    part def IlluminationUnit {
        doc /* Provides consistent lighting when activated by a trigger signal. */

        port in lightControlPort : LightControlPort;

        attribute intensity : Real = 0.0;
        attribute active : Boolean = false;

        action def ActivateLighting {
            in activate : Boolean;
            out lit : Boolean;
        }
    }

    part def DigitalCamera {
        doc /* High-resolution camera that captures detailed images upon trigger. */

        port in triggerPort : TriggerPort;
        port out imagePort : ImagePort;

        attribute resolutionWidth : PixelCount = 1920;
        attribute resolutionHeight : PixelCount = 1080;

        action def CaptureImage {
            in trigger : TriggerSignal;
            out image : Image;
        }
    }

    part def ImagePreprocessor {
        doc /* Cleans up raw images by reducing noise, enhancing contrast, and detecting edges. */

        port in imageIn : ImagePort;
        port out imageOut : ImagePort;

        action def Preprocess {
            in raw : Image;
            out enhanced : Image;

            action reduceNoise {
                in inputImage : Image;
                out denoised : Image;
            }
            action enhanceContrast {
                in denoised : Image;
                out contrasted : Image;
            }
            action detectEdges {
                in contrasted : Image;
                out edgeEnhanced : Image;
            }

            succession reduceNoise to enhanceContrast;
            succession enhanceContrast to detectEdges;

            flow raw to reduceNoise.inputImage;
            flow reduceNoise.denoised to enhanceContrast.denoised;
            flow enhanceContrast.contrasted to detectEdges.contrasted;
            flow detectEdges.edgeEnhanced to enhanced;
        }
    }

    part def DefectDetectionEngine {
        doc /* Analyzes enhanced images to identify, classify, and report defects. */

        port in imageIn : ImagePort;
        port out reportPort : ReportPort;

        action def Analyze {
            in image : Image;
            out report : InspectionReport;

            action identifyDefects {
                in image : Image;
                out defects : Defect[0..*];
            }
            action classifyDefects {
                in defects : Defect[0..*];
                out classifiedDefects : Defect[0..*];
            }
            action generateReport {
                in classifiedDefects : Defect[0..*];
                out report : InspectionReport;
            }

            succession identifyDefects to classifyDefects;
            succession classifyDefects to generateReport;

            flow image to identifyDefects.image;
            flow identifyDefects.defects to classifyDefects.defects;
            flow classifyDefects.classifiedDefects to generateReport.classifiedDefects;
            flow generateReport.report to report;
        }
    }

    part def QualityDecisionModule {
        doc /* Evaluates inspection reports against quality criteria and issues pass/fail commands. */

        port in reportPort : ReportPort;
        port out commandPort : CommandPort;

        attribute maxDefectsAllowed : MaxDefectsAllowed = 3;
        attribute minConfidenceThreshold : MinConfidenceThreshold = 0.85;

        action def Evaluate {
            in report : InspectionReport;
            out command : ControlCommand;
        }
    }

    // ============================================================
    // System Definition
    // ============================================================

    part def MachineVisionSystem {
        doc /* Automated machine vision system for quality control on a manufacturing production line. */

        port out lineCommand : CommandPort;

        part conveyorInterface : ConveyorInterface;
        part illuminationUnit : IlluminationUnit;
        part digitalCamera : DigitalCamera;
        part imagePreprocessor : ImagePreprocessor;
        part defectDetectionEngine : DefectDetectionEngine;
        part qualityDecisionModule : QualityDecisionModule;

        connection conveyorToCamera
            connect conveyorInterface.triggerPort to digitalCamera.triggerPort;
        connection conveyorToLight
            connect conveyorInterface.lightControlPort to illuminationUnit.lightControlPort;
        connection cameraToPreprocessor
            connect digitalCamera.imagePort to imagePreprocessor.imageIn;
        connection preprocessorToEngine
            connect imagePreprocessor.imageOut to defectDetectionEngine.imageIn;
        connection engineToDecision
            connect defectDetectionEngine.reportPort to qualityDecisionModule.reportPort;
        connection decisionToConveyor
            connect qualityDecisionModule.commandPort to conveyorInterface.commandPort;
        connection conveyorToLine
            connect conveyorInterface.lineCommandPort to lineCommand;

        attribute errorDetected : Boolean = false;

        state def InspectionLifecycle {
            entry; then idle;

            state idle {
                doc /* Waiting for the next part to arrive on the conveyor. */
            }

            state acquiring {
                doc /* Trigger sent to camera and illumination; image being captured. */
            }

            state processing {
                doc /* Raw image being preprocessed: noise reduction, contrast enhancement, edge detection. */
            }

            state analyzing {
                doc /* Enhanced image being analyzed for defects; report being generated. */
            }

            state deciding {
                doc /* Inspection report being evaluated against quality criteria; command being issued. */
            }

            state fault {
                doc /* Operational error detected; system in safe state awaiting reset. */
            }

            transition t_idle_acquiring
                first idle
                if conveyorInterface.partPresent
                then acquiring;

            transition t_acquiring_processing
                first acquiring
                then processing;

            transition t_processing_analyzing
                first processing
                then analyzing;

            transition t_analyzing_deciding
                first analyzing
                then deciding;

            transition t_deciding_idle
                first deciding
                then idle;

            transition t_idle_fault
                first idle
                if errorDetected
                then fault;

            transition t_acquiring_fault
                first acquiring
                if errorDetected
                then fault;

            transition t_processing_fault
                first processing
                if errorDetected
                then fault;

            transition t_analyzing_fault
                first analyzing
                if errorDetected
                then fault;

            transition t_deciding_fault
                first deciding
                if errorDetected
                then fault;

            transition t_fault_idle
                first fault
                then idle;
        }

        exhibit state : InspectionLifecycle;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def InspectionRequirement {
        doc /* The system shall automatically inspect parts on the production line, identify manufacturing defects, and make real-time accept or reject decisions. */
        subject system : MachineVisionSystem;
    }

    requirement def TriggerRequirement :> InspectionRequirement {
        doc /* The conveyor interface shall detect a part in position and emit a trigger signal that simultaneously activates the illumination unit and the digital camera. */
        subject conveyorInterface : ConveyorInterface;
    }

    requirement def ImageCaptureRequirement :> InspectionRequirement {
        doc /* The digital camera shall capture a high-resolution image of the part upon receiving a trigger signal. */
        subject digitalCamera : DigitalCamera;
        attribute minResolutionWidth : PixelCount = 1920;
        attribute minResolutionHeight : PixelCount = 1080;
    }

    requirement def PreprocessingRequirement :> InspectionRequirement {
        doc /* The image preprocessor shall reduce noise, enhance contrast, and detect edges to make potential defects more visible. */
        subject imagePreprocessor : ImagePreprocessor;
    }

    requirement def DefectDetectionRequirement :> InspectionRequirement {
        doc /* The defect detection engine shall identify, classify, and report each defect with its type, location, severity, and confidence score. */
        subject defectDetectionEngine : DefectDetectionEngine;
        attribute minConfidence : ConfidenceScore = 0.85;
    }

    requirement def DecisionRequirement :> InspectionRequirement {
        doc /* The quality decision module shall evaluate inspection reports against maximum allowable defects and minimum confidence threshold, then issue a pass or fail command. */
        subject qualityDecisionModule : QualityDecisionModule;
        attribute maxDefects : MaxDefectsAllowed = 3;
        attribute minConfidence : MinConfidenceThreshold = 0.85;
    }

    requirement def FaultHandlingRequirement :> InspectionRequirement {
        doc /* The system shall enter a fault state upon any operational error and return to idle only when the error is cleared. */
        subject system : MachineVisionSystem;
    }

    requirement def CycleTimeRequirement :> InspectionRequirement {
        doc /* The system shall complete one full inspection cycle for a single part within 500 milliseconds. */
        subject system : MachineVisionSystem;
        attribute maxCycleTime : Duration = 500 [ms];
    }
}
