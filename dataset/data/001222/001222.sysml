package RangeImagingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def DistanceValue :> ISQ::LengthValue;
    attribute def AngleValue :> Real;
    attribute def IntensityValue :> Real;
    attribute def FrameRateValue :> Real;
    
    item def Point3D {
        attribute x : DistanceValue;
        attribute y : DistanceValue;
        attribute z : DistanceValue;
        attribute intensity : IntensityValue;
    }
    
    item def DepthMap {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelData : DistanceValue[*] ordered;
        attribute timestamp : ISQ::TimeValue;
        attribute maxRange : DistanceValue;
    }
    
    item def PointCloud {
        attribute points : Point3D[*] ordered;
        attribute numberOfPoints : Integer;
        attribute captureTime : ISQ::TimeValue;
    }
    
    item def LaserPulse {
        attribute wavelength : ISQ::LengthValue;
        attribute power : ISQ::PowerValue;
        attribute emissionTime : ISQ::TimeValue;
        attribute duration : ISQ::TimeValue;
    }
    
    item def TriggerSignal {
        attribute active : Boolean;
    }
    
    item def ErrorSignal {
        attribute errorCode : Integer;
    }
    
    item def ResetSignal {
        attribute reset : Boolean;
    }
    
    port def LaserEmissionPort {
        out item pulse : LaserPulse;
    }
    
    port def LaserReceptionPort {
        in item returnPulse : LaserPulse;
    }
    
    port def DataOutputPort {
        out item depthData : DepthMap;
        out item cloudData : PointCloud;
    }
    
    port def PowerPort {
        in power : ISQ::PowerValue;
    }
    
    port def ControlPort {
        in trigger : Boolean;
        out status : Boolean;
    }
    
    part def LaserEmitter {
        attribute wavelength : ISQ::LengthValue = 905[nm];
        attribute pulseFrequency : Real = 100000;
        attribute pulsePower : ISQ::PowerValue = 50[W];
        attribute pulseDuration : ISQ::TimeValue = 10[ns];
        
        port emissionPort : LaserEmissionPort;
        port powerSupply : PowerPort;
        port control : ControlPort;
        
        perform action emitPulse {
            out pulse : LaserPulse;
        }
    }
    
    part def PhotodetectorArray {
        attribute pixelCount : Integer = 307200;
        attribute sensitivity : Real = 0.85;
        attribute detectionRange : DistanceValue = 200[m];
        
        port receptionPort : LaserReceptionPort;
        port powerSupply : PowerPort;
        
        perform action detectReturn {
            in reflectedPulse : LaserPulse;
            out detectionTime : ISQ::TimeValue;
            out intensity : IntensityValue;
        }
    }
    
    part def TimeOfFlightProcessor {
        attribute processingSpeed : Real = 1000000;
        attribute speedOfLight : ISQ::SpeedValue = 299792458[m/s];
        
        port powerSupply : PowerPort;
        
        perform action calculateDistance {
            in emissionTime : ISQ::TimeValue;
            in detectionTime : ISQ::TimeValue;
            out distance : DistanceValue;
        }
    }
    
    part def ScanningMirror {
        attribute horizontalFOV : AngleValue = 120;
        attribute verticalFOV : AngleValue = 30;
        attribute scanRate : Real = 10;
        
        port powerSupply : PowerPort;
        port control : ControlPort;
        
        perform action adjustAngle {
            in targetHorizontal : AngleValue;
            in targetVertical : AngleValue;
            out currentHorizontal : AngleValue;
            out currentVertical : AngleValue;
        }
    }
    
    part def DepthMapGenerator {
        attribute horizontalResolution : Integer = 640;
        attribute verticalResolution : Integer = 480;
        
        port powerSupply : PowerPort;
        
        perform action generateMap {
            in distances : DistanceValue[*];
            in intensities : IntensityValue[*];
            in scanAngles : AngleValue[*];
            out depthMap : DepthMap;
        }
    }
    
    part def PointCloudProcessor {
        attribute coordinateSystem : String = "Cartesian";
        
        port powerSupply : PowerPort;
        
        perform action convertToCloud {
            in depthMap : DepthMap;
            in scanAngles : AngleValue[*];
            out pointCloud : PointCloud;
        }
    }
    
    action def AcquireRangeImage {
        in attribute scanResolution : Integer = 307200;
        in attribute maxRange : DistanceValue = 200[m];
        out attribute resultDepthMap : DepthMap;
        out attribute resultPointCloud : PointCloud;
        
        private attribute currentPixelIndex : Integer = 0;
        private attribute collectedDistances : DistanceValue[*] := ();
        private attribute collectedIntensities : IntensityValue[*] := ();
        private attribute collectedAngles : AngleValue[*] := ();
        
        first start;
        then action initializeScan;
        then merge scanLoop;
        
        action emitLaser {
            out laserPulse : LaserPulse;
        }
        
        then action adjustMirror {
            in pixelIndex : Integer;
            out horizontalAngle : AngleValue;
            out verticalAngle : AngleValue;
        }
        
        then action detectReflection {
            in reflectedPulse : LaserPulse;
            out arrivalTime : ISQ::TimeValue;
            out signalIntensity : IntensityValue;
        }
        
        then action computeRange {
            in emitTime : ISQ::TimeValue;
            in receiveTime : ISQ::TimeValue;
            out measuredDistance : DistanceValue;
        }
        
        then action storePixelData {
            in distance : DistanceValue;
            in intensity : IntensityValue;
            in angle : AngleValue;
        }
        
        then assign currentPixelIndex := currentPixelIndex + 1;
        
        then decide;
            if currentPixelIndex < scanResolution then scanLoop;
            if currentPixelIndex >= scanResolution then processData;
        
        action processData;
        
        then action assembleDepthMap {
            in pixelDistances : DistanceValue[*];
            in pixelIntensities : IntensityValue[*];
            out depthImage : DepthMap;
        }
        
        then action generate3DCloud {
            in depthImage : DepthMap;
            in scanAngles : AngleValue[*];
            out cloud : PointCloud;
        }
        
        then action outputResults {
            in depthImage : DepthMap;
            in cloud : PointCloud;
        }
        
        then done;
    }
    
    state def RangeImagingStateMachine {
        entry; then idle;
        
        state idle {
            entry assign systemStatus := "Ready";
        }
        
        state scanning {
            entry assign systemStatus := "Scanning";
        }
        
        state processing {
            entry assign systemStatus := "Processing";
        }
        
        state outputting {
            entry assign systemStatus := "Outputting";
        }
        
        state error {
            entry assign systemStatus := "Error";
        }
        
        transition idle_to_scanning
            first idle
            accept trigger : TriggerSignal
            if powerAvailable and systemHealthy
            then scanning;
        
        transition scanning_to_processing
            first scanning
            if scanComplete
            then processing;
        
        transition processing_to_outputting
            first processing
            if dataReady
            then outputting;
        
        transition outputting_to_idle
            first outputting
            then idle;
        
        transition to_error
            first idle
            accept errorEvent : ErrorSignal
            then error;
        
        transition error_to_idle
            first error
            accept resetEvent : ResetSignal
            then idle;
        
        private attribute systemStatus : String;
        private attribute powerAvailable : Boolean;
        private attribute systemHealthy : Boolean;
        private attribute scanComplete : Boolean;
        private attribute dataReady : Boolean;
    }
    
    part def RangeImagingSystem {
        attribute operatingRange : DistanceValue = 200[m];
        attribute fieldOfViewHorizontal : AngleValue = 120;
        attribute fieldOfViewVertical : AngleValue = 30;
        attribute frameRate : FrameRateValue = 10;
        attribute resolution : Integer = 307200;
        attribute totalPower : ISQ::PowerValue = 100[W];
        
        part emitter : LaserEmitter {
            attribute :>> wavelength = 905[nm];
            attribute :>> pulseFrequency = 100000;
        }
        
        part detector : PhotodetectorArray {
            attribute :>> pixelCount = 307200;
            attribute :>> detectionRange = 200[m];
        }
        
        part mirror : ScanningMirror {
            attribute :>> horizontalFOV = 120;
            attribute :>> verticalFOV = 30;
        }
        
        part tofProcessor : TimeOfFlightProcessor;
        
        part depthGenerator : DepthMapGenerator {
            attribute :>> horizontalResolution = 640;
            attribute :>> verticalResolution = 480;
        }
        
        part cloudProcessor : PointCloudProcessor;
        
        port dataOutput : DataOutputPort;
        port systemControl : ControlPort;
        port mainPower : PowerPort;
        
        connection emitterToMirror connect emitter.emissionPort to mirror.control;
        connection mirrorToDetector connect mirror.control to detector.receptionPort;
        connection detectorToProcessor connect detector.receptionPort to tofProcessor.powerSupply;
        connection processorToGenerator connect tofProcessor.powerSupply to depthGenerator.powerSupply;
        connection generatorToCloud connect depthGenerator.powerSupply to cloudProcessor.powerSupply;
        
        perform action captureRangeImage[*] ordered references acquireImage;
        
        action acquireImage : AcquireRangeImage {
            first start;
            then emitter.emitPulse;
            then mirror.adjustAngle;
            then detector.detectReturn;
            then tofProcessor.calculateDistance;
            then depthGenerator.generateMap;
            then cloudProcessor.convertToCloud;
            then done;
        }
        
        exhibit state systemStateBehavior : RangeImagingStateMachine;
    }
    
    requirement <'REQ-001'> rangeImagingCapability {
        doc /* The system shall capture three-dimensional range images 
             * of the environment by measuring distance to objects 
             * using time-of-flight laser ranging technology.
             */
        subject system : RangeImagingSystem;
    }
    
    requirement <'REQ-002'> operatingRangeRequirement {
        doc /* The system shall accurately measure distances 
             * up to 200 meters from the sensor.
             */
        subject system : RangeImagingSystem;
        assert constraint {
            system.operatingRange >= 200[m]
        }
    }
    
    requirement <'REQ-003'> frameRateRequirement {
        doc /* The system shall acquire range images at a minimum 
             * frame rate of 10 frames per second.
             */
        subject system : RangeImagingSystem;
        assert constraint {
            system.frameRate >= 10
        }
    }
    
    requirement <'REQ-004'> resolutionRequirement {
        doc /* The system shall generate depth maps with a minimum 
             * resolution of 640x480 pixels.
             */
        subject generator : RangeImagingSystem::depthGenerator;
        assert constraint {
            generator.horizontalResolution >= 640 and 
            generator.verticalResolution >= 480
        }
    }
    
    requirement <'REQ-005'> fieldOfViewRequirement {
        doc /* The system shall provide a horizontal field of view 
             * of at least 120 degrees and vertical field of view 
             * of at least 30 degrees.
             */
        subject system : RangeImagingSystem;
        assert constraint {
            system.fieldOfViewHorizontal >= 120 and 
            system.fieldOfViewVertical >= 30
        }
    }
    
    requirement <'REQ-006'> powerConsumptionRequirement {
        doc /* The system shall operate within a total power budget 
             * of 100 watts.
             */
        subject system : RangeImagingSystem;
        assert constraint {
            system.totalPower <= 100[W]
        }
    }
    
    part rangeImager : RangeImagingSystem;
    
    satisfy rangeImagingCapability by rangeImager;
    satisfy operatingRangeRequirement by rangeImager;
    satisfy frameRateRequirement by rangeImager;
    satisfy resolutionRequirement by rangeImager.depthGenerator;
    satisfy fieldOfViewRequirement by rangeImager;
    satisfy powerConsumptionRequirement by rangeImager;
}
