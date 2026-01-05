package 'LORROS System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GeographicCoordinates {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }
    
    attribute def TargetSignature {
        attribute thermalProfile : TemperatureValue;
        attribute radarCrossSection : AreaValue;
        attribute visualCharacteristics : String;
    }
    
    attribute def TargetInformation {
        attribute location : GeographicCoordinates;
        attribute signature : TargetSignature;
        attribute classification : String;
        attribute threatLevel : Real;
        attribute trackingConfidence : Real;
    }
    
    attribute def LaserDesignationCode {
        attribute pulseRepetitionFrequency : FrequencyValue;
        attribute codeSequence : Integer;
    }
    
    attribute def SurveillanceCommand {
        attribute searchArea : GeographicCoordinates;
        attribute scanPattern : String;
        attribute priority : Integer;
    }
    
    attribute def TelemetryData {
        attribute systemStatus : String;
        attribute powerLevel : Real;
        attribute targetCount : Integer;
        attribute dataQuality : Real;
    }
    
    port def OpticalPort {
        out imageData : String;
        out videoStream : String;
    }
    
    port def LaserPort {
        out designationBeam : PowerValue;
        out rangingPulse : PowerValue;
        in reflectedEnergy : PowerValue;
    }
    
    port def DataLinkPort {
        in commands : SurveillanceCommand;
        out targetData : TargetInformation;
        out telemetry : TelemetryData;
    }
    
    port def SensorFusionPort {
        in opticalData : String;
        in laserData : LengthValue;
        in thermalData : TemperatureValue;
        out fusedData : TargetInformation;
    }
    
    part def ElectroOpticalSensor {
        attribute focalLength : LengthValue;
        attribute fieldOfView : Real;
        attribute resolution : Real;
        port opticalOut : OpticalPort;
        
        action def AcquireImagery {
            in targetArea : GeographicCoordinates;
            in zoomLevel : Real;
            out imageData : String;
            out videoStream : String;
        }
        
        action def TrackVisualTarget {
            in initialPosition : GeographicCoordinates;
            out trackedPosition : GeographicCoordinates;
            out trackingQuality : Real;
        }
    }
    
    part def LaserRangefinderDesignator {
        attribute wavelength : LengthValue;
        attribute maxRange : LengthValue;
        attribute beamDivergence : Real;
        port laserOut : LaserPort;
        
        action def MeasureRange {
            in targetPosition : GeographicCoordinates;
            out range : LengthValue;
            out accuracy : LengthValue;
        }
        
        action def DesignateTarget {
            in targetLocation : GeographicCoordinates;
            in designationCode : LaserDesignationCode;
            out designationActive : Boolean;
            out beamPower : PowerValue;
        }
    }
    
    part def InfraredSensor {
        attribute spectralBand : String;
        attribute sensitivity : TemperatureValue;
        
        action def DetectThermalSignature {
            in scanArea : GeographicCoordinates;
            out thermalImage : TemperatureValue;
            out hotspots : GeographicCoordinates[*];
        }
    }
    
    part def StabilizedGimbal {
        attribute azimuthRange : Real;
        attribute elevationRange : Real;
        attribute stabilizationAccuracy : Real;
        
        action def PointSensors {
            in targetBearing : Real;
            in targetElevation : Real;
            out pointingError : Real;
        }
        
        action def StabilizePlatform {
            in platformMotion : Real;
            out compensatedPosition : Real;
        }
    }
    
    part def TargetProcessingUnit {
        action def FuseSensorData {
            in opticalInput : String;
            in laserRange : LengthValue;
            in thermalInput : TemperatureValue;
            in platformPosition : GeographicCoordinates;
            out targetInfo : TargetInformation;
        }
        
        action def ClassifyTarget {
            in sensorData : TargetInformation;
            out classification : String;
            out confidence : Real;
        }
        
        action def PrioritizeTargets {
            in detectedTargets : TargetInformation[*];
            out prioritizedList : TargetInformation[*];
        }
        
        action def GenerateTrackFile {
            in currentTarget : TargetInformation;
            in previousTrack : TargetInformation;
            out updatedTrack : TargetInformation;
        }
    }
    
    part def CommunicationsSubsystem {
        attribute dataRate : Real;
        attribute linkRange : LengthValue;
        attribute encryptionLevel : String;
        port dataLink : DataLinkPort;
        
        action def TransmitTargetData {
            in targetInfo : TargetInformation;
            out transmissionSuccess : Boolean;
        }
        
        action def ReceiveCommands {
            out command : SurveillanceCommand;
        }
        
        action def SendTelemetry {
            in systemStatus : TelemetryData;
            out telemetrySent : Boolean;
        }
    }
    
    part def NavigationUnit {
        attribute positionAccuracy : LengthValue;
        
        action def DeterminePosition {
            out currentPosition : GeographicCoordinates;
            out positionError : LengthValue;
        }
        
        action def CalculateTargetCoordinates {
            in sensorBearing : Real;
            in sensorElevation : Real;
            in slantRange : LengthValue;
            in platformPosition : GeographicCoordinates;
            out targetCoordinates : GeographicCoordinates;
        }
    }
    
    part def PowerManagementUnit {
        attribute batteryCapacity : EnergyValue;
        attribute solarPanelOutput : PowerValue;
        
        action def MonitorPower {
            out remainingCapacity : Real;
            out powerConsumption : PowerValue;
        }
        
        action def ManagePowerDistribution {
            in systemDemand : PowerValue;
            out powerAllocation : PowerValue;
        }
    }
    
    action def SearchAndDetect {
        in searchArea : GeographicCoordinates;
        in scanPattern : String;
        out detectedTargets : TargetInformation[*];
    }
    
    action def TrackAndIdentify {
        in initialDetection : TargetInformation;
        out confirmedTarget : TargetInformation;
        out trackingActive : Boolean;
    }
    
    action def DesignateAndReport {
        in priorityTarget : TargetInformation;
        in designationCode : LaserDesignationCode;
        out designationStatus : Boolean;
        out reportTransmitted : Boolean;
    }
    
    action def LORROSMissionSequence {
        doc /*
            Primary mission sequence for Long-Range Reconnaissance and Observation System.
            Executes continuous surveillance cycle: search, detect, track, identify, designate, and report.
        */
        
        first start;
        then merge continuousSurveillance;
        
        action receiveTasking {
            action getCommand;
            out missionCommand : SurveillanceCommand;
        }
        
        then action searchPhase : SearchAndDetect {
            in searchArea = receiveTasking.missionCommand.searchArea;
            in scanPattern = receiveTasking.missionCommand.scanPattern;
            out detectedTargets;
        }
        
        then decide;
            if searchPhase.detectedTargets->notEmpty() then processTargets;
            if searchPhase.detectedTargets->isEmpty() then continuousSurveillance;
        
        action processTargets {
            action selectTarget {
                in candidates : TargetInformation[*] = searchPhase.detectedTargets;
                out selectedTarget : TargetInformation;
            }
            
            then action trackPhase : TrackAndIdentify {
                in initialDetection = selectTarget.selectedTarget;
                out confirmedTarget;
                out trackingActive;
            }
            
            then decide;
                if trackPhase.confirmedTarget.threatLevel >= 0.7 then designatePhase;
                if trackPhase.confirmedTarget.threatLevel < 0.7 then reportOnly;
            
            action designatePhase : DesignateAndReport {
                in priorityTarget = trackPhase.confirmedTarget;
                in designationCode;
                out designationStatus;
                out reportTransmitted;
            }
            
            then continuousSurveillance;
            
            action reportOnly {
                action transmitReport;
            }
            
            then continuousSurveillance;
        }
    }
    
    part def LORROSPlatform {
        doc /*
            Long-Range Reconnaissance and Observation System (LORROS)
            
            Primary Function: Provide persistent, long-range intelligence, surveillance, and 
            reconnaissance (ISR) capabilities with precision target location and laser designation 
            for remote weapon systems. The system autonomously detects, tracks, classifies, and 
            designates high-value targets while transmitting real-time intelligence data to 
            command and control elements.
        */
        
        attribute operationalRange : LengthValue;
        attribute missionDuration : TimeValue;
        attribute currentPosition : GeographicCoordinates;
        attribute systemMode : String;
        
        part eoSensor : ElectroOpticalSensor;
        part laserSystem : LaserRangefinderDesignator;
        part irSensor : InfraredSensor;
        part gimbal : StabilizedGimbal;
        part processor : TargetProcessingUnit;
        part comms : CommunicationsSubsystem;
        part navigation : NavigationUnit;
        part power : PowerManagementUnit;
    }
    
    part lorrosSystem : LORROSPlatform {
        attribute :>> operationalRange = 15000[m];
        attribute :>> missionDuration = 24[h];
        
        part :>> eoSensor {
            attribute :>> focalLength = 750[mm];
            attribute :>> fieldOfView = 2.5;
            attribute :>> resolution = 1920;
        }
        
        part :>> laserSystem {
            attribute :>> wavelength = 1064[nm];
            attribute :>> maxRange = 20000[m];
            attribute :>> beamDivergence = 0.3;
        }
        
        part :>> irSensor {
            attribute :>> spectralBand = "LWIR";
            attribute :>> sensitivity = 0.05[K];
        }
        
        part :>> gimbal {
            attribute :>> azimuthRange = 360;
            attribute :>> elevationRange = 180;
            attribute :>> stabilizationAccuracy = 0.01;
        }
        
        part :>> comms {
            attribute :>> dataRate = 10.0;
            attribute :>> linkRange = 50000[m];
            attribute :>> encryptionLevel = "AES-256";
        }
        
        part :>> navigation {
            attribute :>> positionAccuracy = 5[m];
        }
        
        part :>> power {
            attribute :>> batteryCapacity = 500[W*h];
            attribute :>> solarPanelOutput = 100[W];
        }
        
        connection eoToGimbal connect eoSensor to gimbal;
        connection laserToGimbal connect laserSystem to gimbal;
        connection irToGimbal connect irSensor to gimbal;
        connection sensorsToProcessor connect eoSensor.opticalOut to processor;
        connection laserToProcessor connect laserSystem.laserOut to processor;
        connection processorToComms connect processor to comms.dataLink;
        connection navToProcessor connect navigation to processor;
        connection powerToAll connect power to eoSensor;
        
        perform action missionExecution : LORROSMissionSequence;
    }
    
    requirement def MissionRequirement;
    requirement def PerformanceRequirement;
    requirement def OperationalRequirement;
    
    requirement <'LORROS-REQ-001'> primaryMissionCapability : MissionRequirement {
        doc /*
            The LORROS system shall provide persistent long-range reconnaissance, surveillance, 
            and target designation capabilities to support intelligence gathering and precision 
            strike operations across the full operational area.
        */
        
        subject lorrosSystem;
        
        require constraint operationalRangeConstraint {
            lorrosSystem.operationalRange >= 10000[m]
        }
        
        require constraint missionEnduranceConstraint {
            lorrosSystem.missionDuration >= 12[h]
        }
    }
    
    requirement <'LORROS-REQ-002'> targetDetectionPerformance : PerformanceRequirement {
        doc /*
            The system shall detect and classify vehicle-sized targets at ranges exceeding 
            10 kilometers with high probability of detection and low false alarm rate.
        */
        
        subject lorrosSystem.eoSensor;
    }
    
    requirement <'LORROS-REQ-003'> laserDesignationAccuracy : PerformanceRequirement {
        doc /*
            The laser designation subsystem shall provide target illumination with sufficient 
            accuracy and beam quality to enable precision-guided munition engagement at maximum 
            operational range.
        */
        
        subject lorrosSystem.laserSystem;
        
        require constraint designationAccuracyConstraint {
            lorrosSystem.laserSystem.beamDivergence <= 0.5
        }
        
        require constraint designationRangeConstraint {
            lorrosSystem.laserSystem.maxRange >= 15000[m]
        }
    }
    
    requirement <'LORROS-REQ-004'> dataLinkPerformance : OperationalRequirement {
        doc /*
            The communications subsystem shall maintain reliable, secure data links for 
            command reception and intelligence dissemination with minimal latency.
        */
        
        subject lorrosSystem.comms;
        
        require constraint linkRangeConstraint {
            lorrosSystem.comms.linkRange >= 30000[m]
        }
        
        require constraint encryptionConstraint {
            lorrosSystem.comms.encryptionLevel == "AES-256"
        }
    }
    
    requirement <'LORROS-REQ-005'> autonomousOperation : OperationalRequirement {
        doc /*
            The system shall operate autonomously for extended periods with minimal operator 
            intervention, automatically managing power, sensor tasking, and target processing.
        */
        
        subject lorrosSystem;
        
        require primaryMissionCapability;
        require targetDetectionPerformance;
        require laserDesignationAccuracy;
        require dataLinkPerformance;
    }
}
