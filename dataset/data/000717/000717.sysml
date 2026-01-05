package OptoelectronicPlethysmographySystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;
    
    attribute def RespiratoryRate :> FrequencyValue;
    attribute def TidalVolume :> VolumeValue;
    attribute def ChestWallDisplacement :> LengthValue;
    attribute def MarkerReflectivity :> Real;
    attribute def FrameRate :> FrequencyValue;
    attribute def ProcessingLatency :> TimeValue;
    
    enum def MarkerLocation {
        anteriorRibCageUpper;
        anteriorRibCageLower;
        posteriorRibCageUpper;
        posteriorRibCageLower;
        abdomenUpper;
        abdomenLower;
    }
    
    enum def SystemMode {
        offline;
        calibrating;
        monitoring;
        analyzing;
        alerting;
    }
    
    item def InfraredLight;
    item def ReflectedLight;
    item def ImageFrame {
        attribute timestamp : TimeValue;
        attribute frameNumber : Integer;
    }
    item def MarkerCoordinates {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute markerID : Integer;
    }
    item def VolumeData {
        attribute ribCageVolume : VolumeValue;
        attribute abdominalVolume : VolumeValue;
        attribute totalVolume : VolumeValue;
        attribute timestamp : TimeValue;
    }
    item def RespiratoryMetrics {
        attribute tidalVolume : TidalVolume;
        attribute respiratoryRate : RespiratoryRate;
        attribute minuteVentilation : VolumeValue;
        attribute timestamp : TimeValue;
    }
    
    port def InfraredEmissionPort {
        out irLight : InfraredLight;
    }
    port def OpticalInputPort {
        in reflectedLight : ReflectedLight;
    }
    port def ImageOutputPort {
        out imageData : ImageFrame;
    }
    port def CoordinateDataPort {
        out coordinates : MarkerCoordinates[*];
    }
    port def VolumeDataPort {
        out volumeData : VolumeData;
    }
    port def MetricsOutputPort {
        out metrics : RespiratoryMetrics;
    }
    port def DisplayInputPort {
        in metrics : RespiratoryMetrics;
    }
    port def PowerInputPort {
        in power : PowerValue;
    }
    
    part def ReflectiveMarker {
        attribute location : MarkerLocation;
        attribute markerID : Integer;
        attribute diameter : LengthValue;
        attribute reflectivity : MarkerReflectivity;
    }
    
    part def InfraredIlluminator {
        attribute wavelength : LengthValue;
        attribute emissionPower : PowerValue;
        port irOut : InfraredEmissionPort;
        port powerIn : PowerInputPort;
    }
    
    part def InfraredCamera {
        attribute resolution : String;
        attribute frameRate : FrameRate;
        attribute focalLength : LengthValue;
        port opticalIn : OpticalInputPort;
        port imageOut : ImageOutputPort;
        port powerIn : PowerInputPort;
    }
    
    part def ImageProcessingUnit {
        attribute processingRate : FrameRate;
        attribute maxLatency : ProcessingLatency;
        port imageIn : ImageOutputPort;
        port coordOut : CoordinateDataPort;
        port powerIn : PowerInputPort;
        
        action processImages {
            in rawFrames : ImageFrame[*] ordered;
            out markerPositions : MarkerCoordinates[*];
            
            first start;
            then action detectMarkers {
                in frames = rawFrames;
                out detectedMarkers;
            }
            then action triangulatePositions {
                in markers = detectMarkers.detectedMarkers;
                out positions3D = markerPositions;
            }
            then done;
        }
    }
    
    part def VolumeComputationUnit {
        attribute computationAccuracy : Real;
        port coordIn : CoordinateDataPort;
        port volumeOut : VolumeDataPort;
        port powerIn : PowerInputPort;
        
        action computeVolumes {
            in markerCoords : MarkerCoordinates[*];
            out volumeResult : VolumeData;
            
            first start;
            then action segmentChestWall {
                in coords = markerCoords;
                out ribCageMarkers;
                out abdominalMarkers;
            }
            then fork;
                action calculateRibCageVolume {
                    in markers = segmentChestWall.ribCageMarkers;
                    out rcVolume;
                }
                action calculateAbdominalVolume {
                    in markers = segmentChestWall.abdominalMarkers;
                    out abdVolume;
                }
            then merge volumeIntegration;
            then action integrateCompartments {
                in rcVol = calculateRibCageVolume.rcVolume;
                in abdVol = calculateAbdominalVolume.abdVolume;
                out totalVol = volumeResult;
            }
            then done;
        }
    }
    
    part def RespiratoryAnalysisUnit {
        attribute normalRateMin : RespiratoryRate;
        attribute normalRateMax : RespiratoryRate;
        attribute normalTidalVolumeMin : TidalVolume;
        attribute normalTidalVolumeMax : TidalVolume;
        port volumeIn : VolumeDataPort;
        port metricsOut : MetricsOutputPort;
        port powerIn : PowerInputPort;
        
        action analyzeRespiration {
            in volumeTimeSeries : VolumeData[*] ordered;
            out respiratoryMetrics : RespiratoryMetrics;
            out abnormalityFlag : Boolean;
            
            first start;
            then merge continuousAnalysis;
            then action detectBreathCycles {
                in volumes = volumeTimeSeries;
                out breathCount;
                out breathDuration;
            }
            then action calculateMetrics {
                in count = detectBreathCycles.breathCount;
                in duration = detectBreathCycles.breathDuration;
                out rate;
                out tidalVol;
            }
            then action assessNormality {
                in respRate = calculateMetrics.rate;
                in tidVol = calculateMetrics.tidalVol;
                out isAbnormal = abnormalityFlag;
            }
            then decide;
                if assessNormality.isAbnormal == true then raiseAlert;
                if assessNormality.isAbnormal == false then continuousAnalysis;
            action raiseAlert;
            then continuousAnalysis;
        }
    }
    
    part def DisplayMonitor {
        attribute screenSize : LengthValue;
        attribute refreshRate : FrameRate;
        port dataIn : DisplayInputPort;
        port powerIn : PowerInputPort;
        
        action displayMetrics {
            in metrics : RespiratoryMetrics;
        }
    }
    
    part def SystemController {
        attribute currentMode : SystemMode;
        port powerIn : PowerInputPort;
        
        state systemStateMachine {
            entry; then offline;
            
            state offline;
            transition offline_to_calibrating
                first offline
                then calibrating;
            
            state calibrating {
                entry; then performCalibration;
                action performCalibration;
                then calibrationComplete;
                state calibrationComplete;
            }
            transition calibrating_to_monitoring
                first calibrating.calibrationComplete
                then monitoring;
            transition calibrating_to_offline
                first calibrating
                then offline;
            
            state monitoring {
                entry; then acquireData;
                action acquireData;
                then processData;
                action processData;
                then computeVolumes;
                action computeVolumes;
                then analyzeData;
                state analyzeData;
            }
            transition monitoring_to_analyzing
                first monitoring.analyzeData
                then analyzing;
            
            state analyzing {
                entry; then performAnalysis;
                action performAnalysis;
                then analysisComplete;
                state analysisComplete;
            }
            transition analyzing_to_alerting
                first analyzing.analysisComplete
                then alerting;
            transition analyzing_to_monitoring
                first analyzing.analysisComplete
                then monitoring;
            
            state alerting {
                entry; then issueAlert;
                action issueAlert;
                then alertAcknowledged;
                state alertAcknowledged;
            }
            transition alerting_to_monitoring
                first alerting.alertAcknowledged
                then monitoring;
            
            transition monitoring_to_offline
                first monitoring
                then offline;
            transition analyzing_to_offline
                first analyzing
                then offline;
            transition alerting_to_offline
                first alerting
                then offline;
        }
    }
    
    part def PowerSupply {
        attribute outputVoltage : Real;
        attribute maxCurrent : Real;
        attribute totalPower : PowerValue;
        port powerOut : PowerInputPort;
    }
    
    part def OEPSystem {
        doc /* Optoelectronic plethysmography system for non-invasive respiratory monitoring 
             * through three-dimensional chest wall motion tracking. */
        
        attribute systemID : String;
        attribute calibrationStatus : Boolean;
        attribute measurementAccuracy : Real;
        attribute markerCount : Integer;
        
        part markers : ReflectiveMarker[89] {
            doc /* Standard 89-marker configuration covering thoracoabdominal surface */
            attribute :>> diameter = 15.0 [mm];
            attribute :>> reflectivity = 0.95;
        }
        
        part illuminators : InfraredIlluminator[8] {
            attribute :>> wavelength = 850.0 [nm];
            attribute :>> emissionPower = 5.0 [W];
        }
        
        part cameras : InfraredCamera[8] {
            doc /* Eight cameras positioned for 360-degree coverage */
            attribute :>> resolution = "1920x1080";
            attribute :>> frameRate = 120.0 [Hz];
            attribute :>> focalLength = 8.0 [mm];
        }
        
        part imageProcessor : ImageProcessingUnit {
            attribute :>> processingRate = 120.0 [Hz];
            attribute :>> maxLatency = 0.15 [s];
        }
        
        part volumeComputer : VolumeComputationUnit {
            attribute :>> computationAccuracy = 0.98;
        }
        
        part respiratoryAnalyzer : RespiratoryAnalysisUnit {
            attribute :>> normalRateMin = 12.0 [Hz];
            attribute :>> normalRateMax = 20.0 [Hz];
            attribute :>> normalTidalVolumeMin = 400.0 [L];
            attribute :>> normalTidalVolumeMax = 600.0 [L];
        }
        
        part display : DisplayMonitor {
            attribute :>> screenSize = 24.0 [in];
            attribute :>> refreshRate = 60.0 [Hz];
        }
        
        part controller : SystemController {
            attribute :>> currentMode = SystemMode::offline;
        }
        
        part power : PowerSupply {
            attribute :>> outputVoltage = 24.0;
            attribute :>> maxCurrent = 20.0;
            attribute :>> totalPower = 480.0 [W];
        }
        
        connection powerToIlluminators connect power.powerOut to illuminators.powerIn;
        connection powerToCameras connect power.powerOut to cameras.powerIn;
        connection powerToProcessor connect power.powerOut to imageProcessor.powerIn;
        connection powerToComputer connect power.powerOut to volumeComputer.powerIn;
        connection powerToAnalyzer connect power.powerOut to respiratoryAnalyzer.powerIn;
        connection powerToDisplay connect power.powerOut to display.powerIn;
        connection powerToController connect power.powerOut to controller.powerIn;
        
        connection illuminationPath connect illuminators.irOut to cameras.opticalIn;
        connection imageDataFlow connect cameras.imageOut to imageProcessor.imageIn;
        connection coordinateDataFlow connect imageProcessor.coordOut to volumeComputer.coordIn;
        connection volumeDataFlow connect volumeComputer.volumeOut to respiratoryAnalyzer.volumeIn;
        connection metricsDataFlow connect respiratoryAnalyzer.metricsOut to display.dataIn;
        
        perform action monitorRespiration {
            first start;
            then merge continuousMonitoring;
            then action illuminateMarkers {
                doc /* Infrared illuminators activate reflective markers on chest wall */
            }
            then action captureMarkerImages {
                doc /* Multiple cameras simultaneously capture marker positions */
            }
            then action reconstructMarkerPositions {
                doc /* Triangulate 3D coordinates from multiple camera views */
            }
            then action calculateChestWallVolumes {
                doc /* Compute rib cage and abdominal compartment volumes */
            }
            then action deriveRespiratoryParameters {
                doc /* Extract tidal volume, respiratory rate, and ventilation metrics */
            }
            then decide;
                if true then alertClinician;
                if false then continuousMonitoring;
            action alertClinician {
                doc /* Notify clinical staff of abnormal respiratory patterns */
            }
            then continuousMonitoring;
        }
    }
    
    package Requirements {
        requirement <'REQ-OEP-001'> primaryFunction {
            doc /* The optoelectronic plethysmography system shall continuously monitor 
                 * respiratory function by tracking three-dimensional chest wall motion 
                 * to measure tidal volume, respiratory rate, and minute ventilation 
                 * in real-time without patient contact. */
            subject oepSystem : OEPSystem;
        }
        
        requirement <'REQ-OEP-002'> markerTrackingCapability {
            doc /* The system shall simultaneously track at least 89 reflective markers 
                 * positioned on the thoracoabdominal surface with spatial resolution 
                 * better than 1 millimeter. */
            subject oepSystem : OEPSystem;
            assert constraint {
                oepSystem.markerCount >= 89
            }
        }
        
        requirement <'REQ-OEP-003'> volumeAccuracy {
            doc /* The system shall calculate tidal volume with accuracy within 5% 
                 * compared to spirometric reference measurements. */
            subject volumeComputer : OEPSystem::volumeComputer;
            assert constraint {
                volumeComputer.computationAccuracy >= 0.95
            }
        }
        
        requirement <'REQ-OEP-004'> temporalResolution {
            doc /* The system shall acquire and process marker position data at 
                 * a minimum frame rate of 100 Hz to accurately capture respiratory dynamics. */
            subject cameras : OEPSystem::cameras;
            assert constraint {
                cameras.frameRate >= 100.0 [Hz]
            }
        }
        
        requirement <'REQ-OEP-005'> processingLatency {
            doc /* The system shall process and display respiratory parameters with 
                 * total latency not exceeding 200 milliseconds from image acquisition. */
            subject imageProcessor : OEPSystem::imageProcessor;
            assert constraint {
                imageProcessor.maxLatency <= 0.2 [s]
            }
        }
        
        requirement <'REQ-OEP-006'> respiratoryRateRange {
            doc /* The system shall accurately detect respiratory rates between 
                 * 4 and 60 breaths per minute. */
            subject analyzer : OEPSystem::respiratoryAnalyzer;
        }
        
        requirement <'REQ-OEP-007'> abnormalityDetection {
            doc /* The system shall automatically detect and alert clinicians when 
                 * respiratory parameters deviate from normal physiological ranges. */
            subject analyzer : OEPSystem::respiratoryAnalyzer;
        }
        
        requirement <'REQ-OEP-008'> calibrationRequirement {
            doc /* The system shall complete calibration procedure within 5 minutes 
                 * to establish baseline reference volumes. */
            subject controller : OEPSystem::controller;
        }
    }
    
    package ClinicalScenario {
        part clinicalOEPSystem : OEPSystem {
            attribute :>> systemID = "OEP-ICU-001";
            attribute :>> calibrationStatus = true;
            attribute :>> measurementAccuracy = 0.97;
            attribute :>> markerCount = 89;
        }
        
        satisfy Requirements::primaryFunction by clinicalOEPSystem;
        satisfy Requirements::markerTrackingCapability by clinicalOEPSystem;
        satisfy Requirements::volumeAccuracy by clinicalOEPSystem.volumeComputer;
        satisfy Requirements::temporalResolution by clinicalOEPSystem.cameras;
        satisfy Requirements::processingLatency by clinicalOEPSystem.imageProcessor;
        satisfy Requirements::respiratoryRateRange by clinicalOEPSystem.respiratoryAnalyzer;
        satisfy Requirements::abnormalityDetection by clinicalOEPSystem.respiratoryAnalyzer;
        satisfy Requirements::calibrationRequirement by clinicalOEPSystem.controller;
    }
}
