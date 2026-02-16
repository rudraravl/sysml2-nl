package OmniviewSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelDepth : Integer;
    }
    
    attribute def FieldOfView {
        attribute horizontal : PlaneAngleValue;
        attribute vertical : PlaneAngleValue;
    }
    
    attribute def ProcessingLatency :> TimeValue;
    attribute def DataThroughput :> Real;
    
    item def RawImageFrame {
        attribute resolution : ImageResolution;
        attribute timestamp : TimeValue;
        attribute sensorIdentifier : String;
        attribute exposureTime : TimeValue;
    }
    
    item def StitchedPanorama {
        attribute resolution : ImageResolution;
        attribute totalCoverage : FieldOfView;
        attribute timestamp : TimeValue;
        attribute blendQuality : Real;
    }
    
    item def DetectedObject {
        attribute position : LengthValue[3];
        attribute velocity : SpeedValue[3];
        attribute objectType : String;
        attribute confidenceLevel : Real;
        attribute trackingId : Integer;
    }
    
    port def SensorDataPort {
        out item frameData : RawImageFrame;
    }
    
    port def ProcessedImagePort {
        in item rawFrames : RawImageFrame[*];
        out item panorama : StitchedPanorama;
    }
    
    port def AnalysisPort {
        in item panorama : StitchedPanorama;
        out item objects : DetectedObject[*];
    }
    
    port def ControlCommandPort {
        in attribute activateCapture : Boolean;
        in attribute operatingMode : String;
        in attribute sensitivityLevel : Real;
        out attribute systemState : String;
        out attribute healthStatus : String;
    }
    
    port def PowerPort {
        in flow voltage : ElectricPotentialValue;
        in flow current : ElectricCurrentValue;
        out flow consumedPower : PowerValue;
    }
    
    part def OpticalSensor {
        attribute sensorId : String;
        attribute fieldOfView : FieldOfView;
        attribute imageResolution : ImageResolution;
        attribute frameRate : FrequencyValue;
        
        port dataOutput : SensorDataPort;
        port power : PowerPort;
        
        perform action acquireFrame {
            out capturedFrame : RawImageFrame;
        }
    }
    
    part def ImageStitchingProcessor {
        attribute stitchingAlgorithm : String;
        attribute maxInputStreams : Integer;
        attribute processingLatency : ProcessingLatency;
        
        port imageInputs : ProcessedImagePort;
        port power : PowerPort;
        
        perform action stitchFrames {
            in inputFrames : RawImageFrame[*];
            out panoramicImage : StitchedPanorama;
        }
    }
    
    part def ObjectDetectionUnit {
        attribute detectionAlgorithm : String;
        attribute minimumConfidence : Real;
        attribute maximumTrackedObjects : Integer;
        
        port panoramaInput : AnalysisPort;
        port power : PowerPort;
        
        perform action analyzeScene {
            in sceneImage : StitchedPanorama;
            out identifiedObjects : DetectedObject[*];
        }
    }
    
    part def DataArchive {
        attribute storageCapacity : Real;
        attribute currentUtilization : Real;
        attribute retentionPeriod : TimeValue;
        
        port power : PowerPort;
        
        perform action archiveData {
            in panorama : StitchedPanorama;
            in objects : DetectedObject[*];
        }
    }
    
    part def SystemController {
        attribute controlMode : String;
        attribute cycleRate : FrequencyValue;
        
        port commandInterface : ControlCommandPort;
        port power : PowerPort;
        
        perform action coordinateOperation {
            in activationInput : Boolean;
            out controlSignals : String;
        }
    }
    
    action def AcquireMultiSensorData {
        in numberOfSensors : Integer;
        in captureRate : FrequencyValue;
        out collectedFrames : RawImageFrame[*];
    }
    
    action def SynthesizePanoramicView {
        in rawFrames : RawImageFrame[*];
        in blendingMode : String;
        out synthesizedPanorama : StitchedPanorama;
    }
    
    action def DetectAndTrackObjects {
        in panoramicView : StitchedPanorama;
        in detectionThreshold : Real;
        out trackedObjects : DetectedObject[*];
    }
    
    action def PersistSurveillanceData {
        in panorama : StitchedPanorama;
        in detectedObjects : DetectedObject[*];
        in archiveMetadata : String;
    }
    
    action def ProvideContinuousSituationalAwareness {
        in activationCommand : Boolean;
        in operationalMode : String;
        out detectedThreats : DetectedObject[*];
        out systemStatus : String;
        
        first start;
        then merge awaitActivation;
        
        action awaitActivation accept cmdSignal : Boolean;
        then decide;
            if cmdSignal then initiateCapture;
            if !cmdSignal then awaitActivation;
        
        action initiateCapture : AcquireMultiSensorData {
            in numberOfSensors = 8;
            in captureRate = 30.0[Hz];
            out acquiredFrames : RawImageFrame[*];
        }
        then action synthesizeView : SynthesizePanoramicView {
            in rawFrames = initiateCapture.acquiredFrames;
            in blendingMode = operationalMode;
            out panoramicOutput : StitchedPanorama;
        }
        then action detectThreats : DetectAndTrackObjects {
            in panoramicView = synthesizeView.panoramicOutput;
            in detectionThreshold = 0.80;
            out identifiedThreats : DetectedObject[*];
        }
        then action archiveResults : PersistSurveillanceData {
            in panorama = synthesizeView.panoramicOutput;
            in detectedObjects = detectThreats.identifiedThreats;
            in archiveMetadata = "Surveillance Cycle";
        }
        then assign detectedThreats := detectThreats.identifiedThreats;
        then assign systemStatus := "Cycle Complete";
        then awaitActivation;
    }
    
    state def OmniviewOperationalStates {
        entry; then Standby;
        
        state Standby;
        accept activationCommand : Boolean
        then Initializing;
        
        state Initializing;
        then Calibrating;
        
        state Calibrating;
        then ActiveSurveillance;
        
        state ActiveSurveillance;
        then Analyzing;
        accept deactivationCommand : Boolean
        then Standby;
        
        state Analyzing;
        then Archiving;
        
        state Archiving;
        then ActiveSurveillance;
        
        state Fault;
        accept resetCommand : Boolean
        then Standby;
    }
    
    requirement def <'REQ-OV-001'> CompleteCoverageRequirement {
        doc /* The Omniview system shall provide complete 360-degree horizontal 
               coverage and minimum 120-degree vertical coverage of the monitored area. */
        
        subject system : OmniviewPlatform;
        
        require constraint {
            system.totalFieldOfView.horizontal >= 360.0[deg] and
            system.totalFieldOfView.vertical >= 120.0[deg]
        }
    }
    
    requirement def <'REQ-OV-002'> RealTimeProcessingRequirement {
        doc /* The system shall process and stitch imagery from all sensors 
               with end-to-end latency not exceeding 500 milliseconds. */
        
        subject stitcher : ImageStitchingProcessor;
        
        require constraint {
            stitcher.processingLatency <= 500.0[ms]
        }
    }
    
    requirement def <'REQ-OV-003'> ObjectDetectionAccuracyRequirement {
        doc /* The system shall detect and classify objects with minimum 
               90% confidence in the panoramic field of view. */
        
        subject detector : ObjectDetectionUnit;
        
        require constraint {
            detector.minimumConfidence >= 0.90
        }
    }
    
    requirement def <'REQ-OV-004'> DataRetentionRequirement {
        doc /* The system shall archive panoramic imagery and detection data 
               for minimum 30 days with lossless compression. */
        
        subject archive : DataArchive;
        
        require constraint {
            archive.retentionPeriod >= 30.0[day]
        }
    }
    
    requirement <'REQ-OV-000'> omniviewMissionRequirement {
        doc /* The Omniview system shall provide comprehensive, real-time 
               situational awareness through continuous 360-degree surveillance, 
               object detection, and data archival capabilities. */
        
        assume constraint sensorOperational {
            doc /* All optical sensors are functional, calibrated, and synchronized. */
        }
        
        assume constraint powerAvailable {
            doc /* Sufficient electrical power is available for continuous operation. */
        }
        
        require <'REQ-OV-001'> coverageReq : CompleteCoverageRequirement;
        require <'REQ-OV-002'> latencyReq : RealTimeProcessingRequirement;
        require <'REQ-OV-003'> accuracyReq : ObjectDetectionAccuracyRequirement;
        require <'REQ-OV-004'> retentionReq : DataRetentionRequirement;
    }
    
    part def OmniviewPlatform {
        attribute totalFieldOfView : FieldOfView;
        attribute systemLatency : ProcessingLatency;
        attribute powerConsumption : PowerValue;
        
        port externalControl : ControlCommandPort;
        port externalPower : PowerPort;
        port detectionOutput : AnalysisPort;
        
        part controller : SystemController {
            attribute :>> controlMode = "Autonomous";
            attribute :>> cycleRate = 10.0[Hz];
        }
        
        part frontSensor : OpticalSensor {
            attribute :>> sensorId = "FRONT-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 90.0[deg];
                attribute :>> vertical = 75.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 3840;
                attribute :>> height = 2160;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part rightSensor : OpticalSensor {
            attribute :>> sensorId = "RIGHT-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 90.0[deg];
                attribute :>> vertical = 75.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 3840;
                attribute :>> height = 2160;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part rearSensor : OpticalSensor {
            attribute :>> sensorId = "REAR-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 90.0[deg];
                attribute :>> vertical = 75.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 3840;
                attribute :>> height = 2160;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part leftSensor : OpticalSensor {
            attribute :>> sensorId = "LEFT-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 90.0[deg];
                attribute :>> vertical = 75.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 3840;
                attribute :>> height = 2160;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part topSensor : OpticalSensor {
            attribute :>> sensorId = "TOP-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 120.0[deg];
                attribute :>> vertical = 120.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 4096;
                attribute :>> height = 4096;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part bottomSensor : OpticalSensor {
            attribute :>> sensorId = "BOTTOM-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 120.0[deg];
                attribute :>> vertical = 120.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 4096;
                attribute :>> height = 4096;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part frontLeftSensor : OpticalSensor {
            attribute :>> sensorId = "FRONT-LEFT-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 90.0[deg];
                attribute :>> vertical = 75.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 3840;
                attribute :>> height = 2160;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part rearRightSensor : OpticalSensor {
            attribute :>> sensorId = "REAR-RIGHT-01";
            attribute :>> fieldOfView {
                attribute :>> horizontal = 90.0[deg];
                attribute :>> vertical = 75.0[deg];
            }
            attribute :>> imageResolution {
                attribute :>> width = 3840;
                attribute :>> height = 2160;
                attribute :>> pixelDepth = 24;
            }
            attribute :>> frameRate = 30.0[Hz];
        }
        
        part stitchingProcessor : ImageStitchingProcessor {
            attribute :>> stitchingAlgorithm = "Multi-Band Blending";
            attribute :>> maxInputStreams = 8;
            attribute :>> processingLatency = 450.0[ms];
        }
        
        part detectionUnit : ObjectDetectionUnit {
            attribute :>> detectionAlgorithm = "Deep Neural Network";
            attribute :>> minimumConfidence = 0.92;
            attribute :>> maximumTrackedObjects = 100;
        }
        
        part dataArchive : DataArchive {
            attribute :>> storageCapacity = 10000.0;
            attribute :>> currentUtilization = 2500.0;
            attribute :>> retentionPeriod = 45.0[day];
        }
        
        connection frontToStitcher connect frontSensor.dataOutput to stitchingProcessor.imageInputs;
        connection rightToStitcher connect rightSensor.dataOutput to stitchingProcessor.imageInputs;
        connection rearToStitcher connect rearSensor.dataOutput to stitchingProcessor.imageInputs;
        connection leftToStitcher connect leftSensor.dataOutput to stitchingProcessor.imageInputs;
        connection topToStitcher connect topSensor.dataOutput to stitchingProcessor.imageInputs;
        connection bottomToStitcher connect bottomSensor.dataOutput to stitchingProcessor.imageInputs;
        connection frontLeftToStitcher connect frontLeftSensor.dataOutput to stitchingProcessor.imageInputs;
        connection rearRightToStitcher connect rearRightSensor.dataOutput to stitchingProcessor.imageInputs;
        
        connection stitcherToDetector connect stitchingProcessor.imageInputs to detectionUnit.panoramaInput;
        connection detectorToOutput connect detectionUnit.panoramaInput to detectionOutput;
        
        connection controlToController connect externalControl to controller.commandInterface;
        
        perform action provideSituationalAwareness : ProvideContinuousSituationalAwareness {
            in activationCommand = externalControl.activateCapture;
            in operationalMode = externalControl.operatingMode;
            out detectedThreats;
            out systemStatus;
        }
        
        exhibit state operationalStateMachine : OmniviewOperationalStates;
        
        binding provideSituationalAwareness.detectedThreats = detectionOutput.objects;
        binding provideSituationalAwareness.systemStatus = externalControl.systemState;
    }
    
    part omniviewSystem : OmniviewPlatform {
        attribute :>> totalFieldOfView {
            attribute :>> horizontal = 360.0[deg];
            attribute :>> vertical = 150.0[deg];
        }
        attribute :>> systemLatency = 450.0[ms];
        attribute :>> powerConsumption = 850.0[W];
        
        satisfy omniviewMissionRequirement by self;
    }
}
