package MachineVisionInspectionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PixelResolution {
        attribute width : Natural;
        attribute height : Natural;
    }
    
    attribute def PixelIntensity :> Real;
    
    attribute def ConfidenceScore :> Real;
    
    attribute def DefectType :> String;
    
    item def RawImage {
        attribute resolution : PixelResolution;
        attribute captureTime : TimeValue;
        attribute pixelData : PixelIntensity[*];
    }
    
    item def ProcessedImage {
        attribute resolution : PixelResolution;
        attribute processingTime : TimeValue;
        attribute enhancedData : PixelIntensity[*];
    }
    
    item def DefectData {
        attribute defectType : DefectType;
        attribute confidence : ConfidenceScore;
        attribute locationX : Natural;
        attribute locationY : Natural;
        attribute severity : Real;
    }
    
    item def InspectionReport {
        attribute partIdentifier : String;
        attribute inspectionTime : TimeValue;
        attribute defects : DefectData[*];
        attribute passStatus : Boolean;
        attribute overallConfidence : ConfidenceScore;
    }
    
    item def TriggerSignal {
        attribute timestamp : TimeValue;
    }
    
    item def ControlCommand {
        attribute commandType : String;
        attribute targetState : String;
    }
    
    port def CameraOutputPort {
        out item imageStream : RawImage;
    }
    
    port def ImageInputPort {
        in item imageStream : RawImage;
    }
    
    port def ProcessedImageOutputPort {
        out item processedStream : ProcessedImage;
    }
    
    port def ProcessedImageInputPort {
        in item processedStream : ProcessedImage;
    }
    
    port def InspectionOutputPort {
        out item report : InspectionReport;
    }
    
    port def InspectionInputPort {
        in item report : InspectionReport;
    }
    
    port def TriggerInputPort {
        in item trigger : TriggerSignal;
    }
    
    port def TriggerOutputPort {
        out item trigger : TriggerSignal;
    }
    
    port def ControlInputPort {
        in item command : ControlCommand;
    }
    
    port def ControlOutputPort {
        out item command : ControlCommand;
    }
    
    part def DigitalCamera {
        attribute exposureTime : TimeValue;
        attribute sensorResolution : PixelResolution {
            :>> width = 2048;
            :>> height = 1536;
        }
        attribute frameRate : FrequencyValue;
        
        port triggerInput : TriggerInputPort;
        port imageOutput : CameraOutputPort;
        
        perform action captureImage[*] ordered;
    }
    
    part def IlluminationUnit {
        attribute intensity : LuminousIntensityValue;
        attribute wavelength : LengthValue;
        attribute dutyCycle : Real;
        
        port triggerInput : TriggerInputPort;
        
        perform action illuminatePart[*] ordered;
    }
    
    part def ImagePreprocessor {
        port rawImageInput : ImageInputPort;
        port processedImageOutput : ProcessedImageOutputPort;
        
        perform action preprocessImage {
            in rawImage : RawImage;
            out processedImage : ProcessedImage;
            
            first start;
            then action noiseReduction {
                in image = rawImage;
                out cleanedImage : RawImage;
            }
            then action contrastEnhancement {
                in image = noiseReduction.cleanedImage;
                out enhancedImage : ProcessedImage;
            }
            then action edgeDetection {
                in image = contrastEnhancement.enhancedImage;
                out edgeImage : ProcessedImage;
            }
            then assign processedImage := edgeDetection.edgeImage;
            then done;
        }
    }
    
    part def DefectDetectionEngine {
        attribute detectionThreshold : ConfidenceScore := 0.80;
        attribute maxDefectsPerPart : Natural := 100;
        
        port processedImageInput : ProcessedImageInputPort;
        port inspectionOutput : InspectionOutputPort;
        
        perform action analyzeImage {
            in processedImage : ProcessedImage;
            out report : InspectionReport;
            
            first start;
            then action segmentRegions {
                in image = processedImage;
                out regions : DefectData[*];
            }
            then action classifyDefects {
                in regions = segmentRegions.regions;
                out classifiedDefects : DefectData[*];
            }
            then action filterByConfidence {
                in defects = classifyDefects.classifiedDefects;
                in threshold = detectionThreshold;
                out validDefects : DefectData[*];
            }
            then action generateReport {
                in defects = filterByConfidence.validDefects;
                out inspectionReport : InspectionReport;
            }
            then assign report := generateReport.inspectionReport;
            then done;
        }
    }
    
    part def QualityDecisionModule {
        attribute acceptanceThreshold : ConfidenceScore := 0.90;
        attribute maxAllowableDefects : Natural := 3;
        
        port reportInput : InspectionInputPort;
        port controlOutput : ControlOutputPort;
        
        perform action makeQualityDecision {
            in report : InspectionReport;
            out decision : ControlCommand;
            
            first start;
            then action evaluateReport {
                in inspectionReport = report;
                out defectCount : Natural;
                out averageConfidence : ConfidenceScore;
            }
            then decide;
                if evaluateReport.defectCount == 0 then acceptPart;
                if evaluateReport.defectCount > 0 and evaluateReport.defectCount <= maxAllowableDefects then conditionalAccept;
                if evaluateReport.defectCount > maxAllowableDefects then rejectPart;
            
            action acceptPart {
                out acceptCommand : ControlCommand;
            }
            then assign decision := acceptPart.acceptCommand;
            then done;
            
            action conditionalAccept {
                out conditionalCommand : ControlCommand;
            }
            then decide;
                if evaluateReport.averageConfidence >= acceptanceThreshold then acceptPart;
                if evaluateReport.averageConfidence < acceptanceThreshold then rejectPart;
            
            action rejectPart {
                out rejectCommand : ControlCommand;
            }
            then assign decision := rejectPart.rejectCommand;
            then done;
        }
    }
    
    part def ConveyorInterface {
        attribute conveyorSpeed : SpeedValue;
        
        port triggerOutput : TriggerOutputPort;
        port controlInput : ControlInputPort;
        
        perform action monitorConveyor[*] ordered;
    }
    
    part def MachineVisionSystem {
        attribute systemStatus : String;
        
        part camera : DigitalCamera;
        part lighting : IlluminationUnit;
        part preprocessor : ImagePreprocessor;
        part detector : DefectDetectionEngine;
        part decisionModule : QualityDecisionModule;
        part conveyor : ConveyorInterface;
    }
    
    state def SystemOperationStates {
        in attribute statusRef : String;
        
        entry; then idle;
        
        state idle {
            entry assign statusRef := "Ready";
        }
        
        state acquiring {
            entry assign statusRef := "Capturing Image";
        }
        
        state processing {
            entry assign statusRef := "Processing Image";
        }
        
        state analyzing {
            entry assign statusRef := "Analyzing Defects";
        }
        
        state deciding {
            entry assign statusRef := "Making Decision";
        }
        
        state fault {
            entry assign statusRef := "Fault Condition";
        }
        
        transition idle_to_acquiring
            first idle
            accept trigger : TriggerSignal
            then acquiring;
        
        transition acquiring_to_processing
            first acquiring
            then processing;
        
        transition processing_to_analyzing
            first processing
            then analyzing;
        
        transition analyzing_to_deciding
            first analyzing
            then deciding;
        
        transition deciding_to_idle
            first deciding
            then idle;
        
        transition any_to_fault
            first idle
            accept error : ControlCommand
            if error.commandType == "ERROR"
            then fault;
        
        transition fault_to_idle
            first fault
            accept reset : ControlCommand
            if reset.commandType == "RESET"
            then idle;
    }
    
    part visionSystem : MachineVisionSystem {
        doc /*
            The machine vision inspection system's primary function is to automatically 
            inspect manufactured parts on a production line for quality defects. It operates 
            by capturing high-resolution images of parts as they pass through the inspection 
            station, processing these images to enhance relevant features, analyzing them using 
            advanced defect detection algorithms, and making real-time accept/reject decisions 
            based on configurable quality criteria. This enables automated quality control, 
            reduces manual inspection labor, improves consistency, and increases production 
            throughput while maintaining high quality standards.
        */
        
        part :>> camera {
            :>> exposureTime = 5.0[ms];
            :>> frameRate = 60.0[Hz];
            perform action captureImage[*] ordered;
        }
        
        part :>> lighting {
            :>> intensity = 1000.0[cd];
            :>> wavelength = 450.0[nm];
            :>> dutyCycle = 0.75;
            perform action illuminatePart[*] ordered;
        }
        
        part :>> preprocessor {
            perform action preprocessImage[*] ordered;
        }
        
        part :>> detector {
            :>> detectionThreshold = 0.85;
            :>> maxDefectsPerPart = 50;
            perform action analyzeImage[*] ordered;
        }
        
        part :>> decisionModule {
            :>> acceptanceThreshold = 0.92;
            :>> maxAllowableDefects = 2;
            perform action makeQualityDecision[*] ordered;
        }
        
        part :>> conveyor {
            :>> conveyorSpeed = 0.5[m/s];
            perform action monitorConveyor[*] ordered;
        }
        
        connect conveyor.triggerOutput to camera.triggerInput;
        connect conveyor.triggerOutput to lighting.triggerInput;
        connect camera.imageOutput to preprocessor.rawImageInput;
        connect preprocessor.processedImageOutput to detector.processedImageInput;
        connect detector.inspectionOutput to decisionModule.reportInput;
        connect decisionModule.controlOutput to conveyor.controlInput;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def QualityRequirement;
    
    requirement <'MVS-REQ-001'> primaryInspectionFunction : FunctionalRequirement {
        doc /*
            The machine vision inspection system shall automatically inspect manufactured 
            parts for quality defects and make accept/reject decisions in real-time.
        */
    }
    
    requirement <'MVS-REQ-002'> imageAcquisitionRate : PerformanceRequirement {
        doc /*
            The system shall capture and process images at a minimum rate of 60 parts 
            per minute to support production throughput requirements.
        */
    }
    
    requirement <'MVS-REQ-003'> defectDetectionAccuracy : QualityRequirement {
        doc /*
            The system shall detect defects with a minimum confidence score of 85% 
            to ensure reliable quality control.
        */
    }
    
    requirement <'MVS-REQ-004'> processingLatency : PerformanceRequirement {
        doc /*
            The system shall complete the entire inspection cycle from image capture 
            to decision output within 1 second per part.
        */
    }
    
    requirement <'MVS-REQ-005'> illuminationConsistency : QualityRequirement {
        doc /*
            The illumination system shall maintain consistent light intensity within 
            5% variation to ensure repeatable image quality.
        */
    }
    
    requirement <'MVS-REQ-006'> systemReliability : PerformanceRequirement {
        doc /*
            The system shall operate continuously with an uptime of at least 98% 
            during production hours.
        */
    }
    
    requirement systemMission {
        doc /*
            The machine vision inspection system shall provide automated, high-speed, 
            and accurate quality inspection of manufactured parts to ensure only 
            conforming products proceed in the production line, thereby reducing 
            defects, minimizing manual inspection costs, and maintaining consistent 
            quality standards across all inspected parts.
        */
        
        require primaryInspectionFunction;
        require imageAcquisitionRate;
        require defectDetectionAccuracy;
        require processingLatency;
        require illuminationConsistency;
        require systemReliability;
    }
}
