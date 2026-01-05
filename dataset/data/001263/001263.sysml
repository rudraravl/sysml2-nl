package 'Staring Array Surveillance System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PixelResolution {
        attribute horizontal : Integer;
        attribute vertical : Integer;
    }
    
    attribute def SpectralBand {
        attribute minWavelength : LengthValue;
        attribute maxWavelength : LengthValue;
    }
    
    attribute def TargetSignature {
        attribute azimuth : Real;
        attribute elevation : Real;
        attribute intensity : Real;
        attribute spectralProfile : Real[*];
        attribute timestamp : TimeValue;
    }
    
    attribute def DetectionCriteria {
        attribute minimumSNR : Real;
        attribute confidenceThreshold : Real;
        attribute minimumPixelCount : Integer;
    }
    
    item def RawImageData {
        attribute frameID : Integer;
        attribute captureTime : TimeValue;
        attribute pixelArray : Real[*];
        attribute integrationTime : TimeValue;
    }
    
    item def ProcessedImageData {
        attribute frameID : Integer;
        attribute enhancedPixels : Real[*];
        attribute noiseLevel : Real;
        attribute dynamicRange : Real;
    }
    
    item def TargetReport {
        attribute detectedTargets : TargetSignature[*];
        attribute frameReference : Integer;
        attribute processingTimestamp : TimeValue;
        attribute totalDetections : Integer;
    }
    
    item def SystemCommand {
        attribute commandType : String;
        attribute parameters : Real[*];
        attribute priority : Integer;
    }
    
    port def OpticalInputPort {
        in item incomingRadiation : RawImageData;
    }
    
    port def DataOutputPort {
        out item imageData : ProcessedImageData;
        out item targetData : TargetReport;
    }
    
    port def CommandPort {
        in item commands : SystemCommand;
        out attribute status : String;
    }
    
    port def CoolingPort {
        in attribute targetTemperature : TemperatureValue;
        out attribute actualTemperature : TemperatureValue;
    }
    
    part def FocalPlaneArray {
        attribute resolution : PixelResolution;
        attribute spectralResponse : SpectralBand;
        attribute pixelPitch : LengthValue;
        attribute fillFactor : Real;
        attribute operatingTemperature : TemperatureValue;
        attribute quantumEfficiency : Real;
        
        port opticalInput : OpticalInputPort;
        port rawDataOut : DataOutputPort;
        port cooling : CoolingPort;
        
        perform action acquireImage {
            in integrationPeriod : TimeValue;
            in currentTemperature : TemperatureValue;
            out rawFrame : RawImageData;
        }
    }
    
    part def ImageProcessor {
        attribute processingBandwidth : FrequencyValue;
        attribute bufferSize : Integer;
        attribute algorithmVersion : String;
        
        port rawDataIn : DataOutputPort;
        port processedDataOut : DataOutputPort;
        
        perform action enhanceImage {
            in rawImage : RawImageData;
            out enhancedImage : ProcessedImageData;
        }
        
        perform action applyFiltering {
            in inputImage : ProcessedImageData;
            out filteredImage : ProcessedImageData;
        }
    }
    
    part def TargetDetectionUnit {
        attribute detectionAlgorithm : String;
        attribute processingLatency : TimeValue;
        attribute criteria : DetectionCriteria;
        attribute maxConcurrentTargets : Integer;
        
        port imageInput : DataOutputPort;
        port detectionOutput : DataOutputPort;
        
        perform action detectTargets {
            in processedImage : ProcessedImageData;
            in detectionParams : DetectionCriteria;
            out targets : TargetSignature[*];
        }
        
        perform action classifyTargets {
            in detectedTargets : TargetSignature[*];
            out classifiedReport : TargetReport;
        }
    }
    
    part def CryogenicCooler {
        attribute coolingCapacity : PowerValue;
        attribute targetTemperature : TemperatureValue;
        attribute cooldownTime : TimeValue;
        attribute powerConsumption : PowerValue;
        
        port thermalInterface : CoolingPort;
        
        perform action regulateTemperature {
            in setpoint : TemperatureValue;
            in currentTemp : TemperatureValue;
            out coolingPower : PowerValue;
            out stabilizedTemp : TemperatureValue;
        }
    }
    
    part def SystemController {
        attribute operatingMode : String;
        attribute frameRate : FrequencyValue;
        attribute systemHealth : String;
        
        port commandInterface : CommandPort;
        
        perform action processCommand {
            in command : SystemCommand;
            out response : String;
        }
        
        perform action monitorHealth {
            out healthStatus : String;
            out diagnostics : String[*];
        }
    }
    
    state def SystemOperationStates {
        entry; then Initialization;
        
        state Initialization {
            entry action setInitializing;
        }
        
        state Standby {
            entry action setReady;
        }
        
        state ActiveSurveillance {
            entry action setOperating;
        }
        
        state Maintenance {
            entry action setMaintenance;
        }
        
        state Fault {
            entry action setFault;
        }
        
        transition Initialization to Standby;
        transition Standby to ActiveSurveillance;
        transition ActiveSurveillance to Standby;
        transition Standby to Maintenance;
        transition Maintenance to Standby;
        transition Fault to Initialization;
    }
    
    action def ContinuousSurveillance {
        in fieldOfView : Real[2];
        in surveillanceDuration : TimeValue;
        in detectionParams : DetectionCriteria;
        out surveillanceReport : TargetReport[*];
    }
    
    action def InitializeSystem {
        in coolingTarget : TemperatureValue;
        out initializationStatus : String;
    }
    
    action def PerformCalibration {
        in calibrationMode : String;
        out calibrationResults : Real[*];
    }
    
    part def StaringArraySystem;
    
    part staringArraySystem : StaringArraySystem {
        doc /*
            The Staring Array Surveillance System provides persistent, wide-area
            monitoring of a fixed field of regard without mechanical scanning.
            Its primary function is to continuously detect, locate, and characterize
            targets of interest within the sensor's field of view by maintaining
            constant observation of the scene through a two-dimensional focal plane
            array. The system integrates infrared detection, real-time image processing,
            and automated target recognition to deliver actionable surveillance data
            for security, reconnaissance, and threat warning applications.
        */
        
        attribute systemFieldOfView : Real[2] = (60.0, 45.0);
        attribute operationalFrameRate : FrequencyValue = 60.0;
        attribute surveillanceRange : LengthValue = 25000.0;
        attribute systemPowerBudget : PowerValue = 3500.0;
        
        part focalPlane : FocalPlaneArray {
            :>> resolution = PixelResolution {
                horizontal = 1920;
                vertical = 1080;
            }
            :>> spectralResponse = SpectralBand {
                minWavelength = 3.0e-6;
                maxWavelength = 5.0e-6;
            }
            :>> pixelPitch = 12.0e-6;
            :>> fillFactor = 0.92;
            :>> operatingTemperature = 77.0;
            :>> quantumEfficiency = 0.88;
        }
        
        part imageProc : ImageProcessor {
            :>> processingBandwidth = 500.0e6;
            :>> bufferSize = 10;
            :>> algorithmVersion = "v3.2.1";
        }
        
        part targetDetector : TargetDetectionUnit {
            :>> detectionAlgorithm = "AdaptiveThreshold";
            :>> processingLatency = 0.015;
            :>> criteria = DetectionCriteria {
                minimumSNR = 6.0;
                confidenceThreshold = 0.90;
                minimumPixelCount = 9;
            }
            :>> maxConcurrentTargets = 200;
        }
        
        part cooler : CryogenicCooler {
            :>> coolingCapacity = 150.0;
            :>> targetTemperature = 77.0;
            :>> cooldownTime = 300.0;
            :>> powerConsumption = 250.0;
        }
        
        part controller : SystemController {
            :>> operatingMode = "Surveillance";
            :>> frameRate = 60.0;
            :>> systemHealth = "Nominal";
        }
        
        port opticalAperture : OpticalInputPort;
        port surveillanceOutput : DataOutputPort;
        port systemControl : CommandPort;
        
        connect cooler.thermalInterface to focalPlane.cooling;
        connect focalPlane.rawDataOut to imageProc.rawDataIn;
        connect imageProc.processedDataOut to targetDetector.imageInput;
        connect targetDetector.detectionOutput to surveillanceOutput;
        connect systemControl to controller.commandInterface;
        
        perform action executeSurveillanceMission {
            first start;
            
            then action initialize : InitializeSystem {
                in coolingTarget = 77.0;
                out initializationStatus;
            }
            
            then action calibrate : PerformCalibration {
                in calibrationMode = "Full";
                out calibrationResults;
            }
            
            then merge surveillanceLoop;
            
            action surveillanceLoop {
                loop {
                    action captureFrame : FocalPlaneArray::acquireImage {
                        in integrationPeriod = 0.0167;
                        in currentTemperature = cooler.thermalInterface.actualTemperature;
                        out rawFrame;
                    }
                    
                    flow captureFrame.rawFrame to enhanceFrame.rawImage;
                    
                    then action enhanceFrame : ImageProcessor::enhanceImage {
                        in rawImage;
                        out enhancedImage;
                    }
                    
                    flow enhanceFrame.enhancedImage to filterFrame.inputImage;
                    
                    then action filterFrame : ImageProcessor::applyFiltering {
                        in inputImage;
                        out filteredImage;
                    }
                    
                    flow filterFrame.filteredImage to detectInFrame.processedImage;
                    
                    then action detectInFrame : TargetDetectionUnit::detectTargets {
                        in processedImage;
                        in detectionParams = targetDetector.criteria;
                        out targets;
                    }
                    
                    flow detectInFrame.targets to classifyDetections.detectedTargets;
                    
                    then action classifyDetections : TargetDetectionUnit::classifyTargets {
                        in detectedTargets;
                        out classifiedReport;
                    }
                    
                    then action maintainCooling : CryogenicCooler::regulateTemperature {
                        in setpoint = 77.0;
                        in currentTemp = focalPlane.cooling.actualTemperature;
                        out coolingPower;
                        out stabilizedTemp;
                    }
                    
                    then action checkHealth : SystemController::monitorHealth {
                        out healthStatus;
                        out diagnostics;
                    }
                    
                    then decide;
                        if checkHealth.healthStatus == "Nominal" then surveillanceLoop;
                        if checkHealth.healthStatus == "Degraded" then handleDegradation;
                        if checkHealth.healthStatus == "Critical" then emergencyShutdown;
                }
            }
            
            action handleDegradation {
                action reducedModeOperation;
                then surveillanceLoop;
            }
            
            action emergencyShutdown {
                action safePowerDown;
            }
            
            then done;
        }
    }
    
    requirement <'SAR-SYS-001'> continuousMonitoringRequirement {
        doc /*
            The staring array system shall maintain continuous surveillance of
            the designated field of view at the specified frame rate without
            interruption during normal operations.
        */
        
        subject staringArraySystem;
        
        require constraint {
            staringArraySystem.operationalFrameRate >= 60.0
        }
    }
    
    requirement <'SAR-SYS-002'> detectionPerformanceRequirement {
        doc /*
            The system shall detect targets meeting the minimum signal-to-noise
            ratio with confidence exceeding the specified threshold while
            maintaining false alarm rates below acceptable limits.
        */
        
        subject staringArraySystem.targetDetector;
        
        require constraint {
            staringArraySystem.targetDetector.criteria.minimumSNR >= 6.0 and
            staringArraySystem.targetDetector.criteria.confidenceThreshold >= 0.90
        }
    }
    
    requirement <'SAR-SYS-003'> thermalStabilityRequirement {
        doc /*
            The focal plane array shall be maintained at cryogenic operating
            temperature within specified tolerance to ensure optimal detector
            performance and sensitivity.
        */
        
        subject staringArraySystem.cooler;
        
        require constraint {
            staringArraySystem.focalPlane.operatingTemperature <= 77.0 and
            staringArraySystem.cooler.targetTemperature == 77.0
        }
    }
    
    requirement <'SAR-SYS-004'> spatialResolutionRequirement {
        doc /*
            The system shall provide sufficient spatial resolution to detect
            and resolve targets of interest at the maximum surveillance range.
        */
        
        subject staringArraySystem.focalPlane;
        
        require constraint {
            staringArraySystem.focalPlane.resolution.horizontal >= 1920 and
            staringArraySystem.focalPlane.resolution.vertical >= 1080
        }
    }
    
    requirement <'SAR-SYS-005'> processingLatencyRequirement {
        doc /*
            The system shall process acquired imagery and generate target reports
            within the specified latency to support real-time decision making.
        */
        
        subject staringArraySystem.targetDetector;
        
        require constraint {
            staringArraySystem.targetDetector.processingLatency <= 0.020
        }
    }
    
    requirement <'SAR-SYS-006'> powerConsumptionRequirement {
        doc /*
            The total system power consumption shall not exceed the allocated
            power budget during sustained surveillance operations.
        */
        
        subject staringArraySystem;
        
        require constraint {
            staringArraySystem.systemPowerBudget <= 3500.0
        }
    }
    
    requirement <'SAR-MISSION-001'> surveillanceMissionRequirement {
        doc /*
            The staring array system shall provide persistent wide-area surveillance
            capability for continuous target detection, tracking, and reporting in
            support of security and reconnaissance missions.
        */
        
        require continuousMonitoringRequirement;
        require detectionPerformanceRequirement;
        require thermalStabilityRequirement;
        require spatialResolutionRequirement;
        require processingLatencyRequirement;
        require powerConsumptionRequirement;
    }
}
