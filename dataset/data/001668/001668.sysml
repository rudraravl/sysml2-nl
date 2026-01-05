package 'Marata Vision System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelDepth : Integer;
    }
    
    attribute def FrameRate :> Real;
    attribute def Brightness :> Real;
    attribute def Contrast :> Real;
    attribute def ExposureTime :> DurationValue;
    attribute def FocalLength :> LengthValue;
    attribute def Aperture :> Real;
    
    attribute def ProcessingMode {
        attribute edgeDetection : Boolean;
        attribute objectTracking : Boolean;
        attribute motionAnalysis : Boolean;
        attribute colorCorrection : Boolean;
    }
    
    item def RawImageFrame {
        attribute resolution : ImageResolution;
        attribute timestamp : TimeValue;
        attribute brightness : Brightness;
        attribute pixelData : Real[*];
    }
    
    item def ProcessedImageFrame {
        attribute sourceFrame : RawImageFrame;
        attribute detectedEdges : Real[*];
        attribute trackedObjects : String[*];
        attribute motionVectors : Real[*];
        attribute correctedColors : Real[*];
        attribute processingTimestamp : TimeValue;
    }
    
    item def VisionCommand {
        attribute mode : ProcessingMode;
        attribute targetFrameRate : FrameRate;
        attribute exposureSetting : ExposureTime;
    }
    
    item def SystemStatus {
        attribute operationalState : String;
        attribute currentFrameRate : FrameRate;
        attribute processingLoad : Real;
        attribute errorCount : Integer;
    }
    
    port def OpticalSensorPort {
        out item rawFrame : RawImageFrame;
        in attribute exposureControl : ExposureTime;
        in attribute apertureControl : Aperture;
        in attribute focusControl : FocalLength;
    }
    
    port def ImageProcessorPort {
        in item inputFrame : RawImageFrame;
        out item outputFrame : ProcessedImageFrame;
        in attribute config : ProcessingMode;
    }
    
    port def DisplayInterfacePort {
        in item frameData : ProcessedImageFrame;
        out attribute displayReady : Boolean;
    }
    
    port def ControlInterfacePort {
        in item command : VisionCommand;
        out item status : SystemStatus;
    }
    
    port def DataStoragePort {
        out item storedFrame : ProcessedImageFrame;
        in attribute storageCapacity : Real;
    }
    
    part def OpticalSensor {
        attribute sensorResolution : ImageResolution {
            width = 3840;
            height = 2160;
            pixelDepth = 12;
        }
        attribute maxFrameRate : FrameRate = 120.0;
        attribute currentExposure : ExposureTime;
        attribute currentAperture : Aperture;
        attribute focalDistance : FocalLength;
        
        port sensorOutput : OpticalSensorPort;
        
        perform action captureFrame {
            out capturedFrame : RawImageFrame;
        }
    }
    
    part def ImageProcessingUnit {
        attribute processingCapacity : Real = 100.0;
        attribute currentLoad : Real = 0.0;
        attribute processingLatency : DurationValue;
        
        port processorInput : ImageProcessorPort;
        
        perform action processFrame {
            in rawFrame : RawImageFrame;
            in processingConfig : ProcessingMode;
            out processedFrame : ProcessedImageFrame;
        }
    }
    
    part def DisplayController {
        attribute displayResolution : ImageResolution {
            width = 3840;
            height = 2160;
            pixelDepth = 10;
        }
        attribute refreshRate : FrameRate = 60.0;
        attribute displayBrightness : Brightness;
        
        port displayInput : DisplayInterfacePort;
        
        perform action renderFrame {
            in frameData : ProcessedImageFrame;
        }
    }
    
    part def SystemController {
        attribute operatingMode : String = "Standby";
        attribute systemUptime : DurationValue;
        
        port controlInterface : ControlInterfacePort;
        
        perform action manageSystem {
            in cmd : VisionCommand;
            out sysStatus : SystemStatus;
        }
    }
    
    part def DataStorageUnit {
        attribute storageCapacity : Real = 1000.0;
        attribute usedStorage : Real = 0.0;
        
        port storageInterface : DataStoragePort;
        
        perform action storeFrame {
            in frameToStore : ProcessedImageFrame;
        }
    }
    
    action def CaptureRawFrame {
        in exposureSetting : ExposureTime;
        in apertureSetting : Aperture;
        in focusSetting : FocalLength;
        out rawFrameOutput : RawImageFrame;
    }
    
    action def PerformEdgeDetection {
        in frameData : RawImageFrame;
        out edgeData : Real[*];
    }
    
    action def TrackObjects {
        in frameData : RawImageFrame;
        in previousEdges : Real[*];
        out objectList : String[*];
    }
    
    action def AnalyzeMotion {
        in currentFrame : RawImageFrame;
        in previousFrame : RawImageFrame;
        out motionVectors : Real[*];
    }
    
    action def CorrectColors {
        in frameData : RawImageFrame;
        out correctedData : Real[*];
    }
    
    action def ProcessVisionFrame {
        in rawInput : RawImageFrame;
        in mode : ProcessingMode;
        out processedOutput : ProcessedImageFrame;
        
        first start;
        then action detectEdges : PerformEdgeDetection {
            in frameData = rawInput;
            out edgeData;
        }
        then decide;
            if mode.objectTracking then trackObjects;
            if mode.motionAnalysis then analyzeMotion;
            if mode.colorCorrection then correctColors;
        
        action trackObjects : TrackObjects {
            in frameData = rawInput;
            in previousEdges = detectEdges.edgeData;
            out objectList;
        }
        then merge consolidate;
        
        action analyzeMotion : AnalyzeMotion {
            in currentFrame = rawInput;
            in previousFrame : RawImageFrame;
            out motionVectors;
        }
        then consolidate;
        
        action correctColors : CorrectColors {
            in frameData = rawInput;
            out correctedData;
        }
        then consolidate;
        
        then action assembleOutput {
            assign processedOutput := ProcessedImageFrame {
                sourceFrame = rawInput;
                detectedEdges = detectEdges.edgeData;
                trackedObjects = trackObjects.objectList;
                motionVectors = analyzeMotion.motionVectors;
                correctedColors = correctColors.correctedData;
            }
        }
        then done;
    }
    
    state def VisionSystemStates {
        entry; then standby;
        
        state standby;
        accept initializeCommand;
        then initializing;
        
        state initializing;
        then operational;
        
        state operational {
            state capturing;
            then processing;
            
            state processing;
            then displaying;
            
            state displaying;
            then capturing;
        }
        accept pauseCommand;
        then paused;
        
        state paused;
        accept resumeCommand;
        then operational;
        
        accept shutdownCommand;
        then shutdown;
        
        state shutdown;
    }
    
    part def MarataVisionSystem;
    
    part marataVisionSystem : MarataVisionSystem {
        doc /*
            The Marata Vision System is an advanced real-time imaging and analysis platform
            designed for high-performance visual perception and intelligent scene understanding.
            Its primary function is to continuously acquire high-resolution visual data from
            its environment, perform sophisticated real-time image processing including edge
            detection, object tracking, motion analysis, and color correction, and deliver
            processed visual intelligence for automated decision-making, surveillance,
            quality inspection, or augmented reality applications. The system operates as
            a coordinated pipeline integrating optical sensing, computational processing,
            display rendering, and data archival to transform raw visual input into
            actionable insights with minimal latency.
        */
        
        attribute systemResolution : ImageResolution {
            width = 3840;
            height = 2160;
            pixelDepth = 12;
        }
        attribute operatingFrameRate : FrameRate = 60.0;
        attribute maxProcessingLatency : DurationValue;
        
        part sensor : OpticalSensor {
            attribute sensorResolution = marataVisionSystem::systemResolution;
            attribute maxFrameRate = 120.0;
            attribute currentExposure : ExposureTime;
        }
        
        part processor : ImageProcessingUnit {
            attribute processingCapacity = 100.0;
            attribute currentLoad = 0.0;
        }
        
        part display : DisplayController {
            attribute displayResolution = marataVisionSystem::systemResolution;
            attribute refreshRate = marataVisionSystem::operatingFrameRate;
        }
        
        part controller : SystemController {
            attribute operatingMode = "Initialized";
        }
        
        part storage : DataStorageUnit {
            attribute storageCapacity = 1000.0;
            attribute usedStorage = 0.0;
        }
        
        connection sensorToProcessor connect 
            sensor.sensorOutput to processor.processorInput;
        
        connection processorToDisplay connect 
            processor.processorInput to display.displayInput;
        
        connection processorToStorage connect 
            processor.processorInput to storage.storageInterface;
        
        connection controlToSensor connect 
            controller.controlInterface to sensor.sensorOutput;
        
        perform action executeVisionPipeline {
            first start;
            then merge continuousOperation;
            
            then action captureFrame : CaptureRawFrame {
                in exposureSetting = sensor.currentExposure;
                in apertureSetting = sensor.currentAperture;
                in focusSetting = sensor.focalDistance;
                out rawFrameOutput;
            }
            
            then action processFrame : ProcessVisionFrame {
                in rawInput = captureFrame.rawFrameOutput;
                in mode : ProcessingMode {
                    edgeDetection = true;
                    objectTracking = true;
                    motionAnalysis = true;
                    colorCorrection = true;
                }
                out processedOutput;
            }
            
            then action displayFrame {
                in frameData = processFrame.processedOutput;
            }
            
            then action storeFrame {
                in frameToStore = processFrame.processedOutput;
            }
            
            then continuousOperation;
            
            accept terminateSignal;
            then done;
        }
        
        exhibit state visionStateMachine : VisionSystemStates;
    }
    
    requirement def VisionSystemRequirements {
        doc /* High-level requirements for the Marata Vision System */
        
        requirement <'MVS-001'> imageAcquisitionRequirement {
            doc /* The system shall continuously acquire images at a minimum frame rate of 60 fps with 4K resolution */
            subject marataVisionSystem;
        }
        
        requirement <'MVS-002'> processingLatencyRequirement {
            doc /* The system shall process each frame within 16.67 milliseconds to maintain real-time performance at 60 fps */
            subject marataVisionSystem.processor;
        }
        
        requirement <'MVS-003'> objectTrackingRequirement {
            doc /* The system shall detect and track multiple objects simultaneously with a minimum accuracy of 98% */
            subject marataVisionSystem.processor;
        }
        
        requirement <'MVS-004'> motionAnalysisRequirement {
            doc /* The system shall compute motion vectors for all detected objects with sub-pixel accuracy */
            subject marataVisionSystem.processor;
        }
        
        requirement <'MVS-005'> dataStorageRequirement {
            doc /* The system shall archive processed frames with metadata for a minimum of 1000 frames */
            subject marataVisionSystem.storage;
        }
        
        requirement <'MVS-006'> systemIntegrationRequirement {
            doc /* All subsystems shall operate in synchronized fashion to maintain continuous pipeline operation without frame drops */
            subject marataVisionSystem;
            require imageAcquisitionRequirement;
            require processingLatencyRequirement;
        }
    }
    
    requirement primaryFunctionRequirement : VisionSystemRequirements {
        doc /*
            The Marata Vision System shall provide real-time visual perception and intelligent
            scene analysis by integrating high-resolution image capture, advanced multi-stage
            processing, high-fidelity display rendering, and comprehensive data archival into
            a unified, continuously operating pipeline that transforms raw optical input into
            structured, analyzed visual intelligence suitable for automated interpretation,
            decision support, quality control, surveillance, and augmented reality applications
            with minimal latency and maximum accuracy.
        */
        subject marataVisionSystem;
    }
}
