package LIDARPerceptionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LaserWavelength :> ISQ::LengthValue {
        doc /* Wavelength of the laser beam used in LIDAR */
    }
    
    attribute def ScanRate :> ISQ::FrequencyValue {
        doc /* Rate at which the LIDAR scans the environment */
    }
    
    attribute def AngularResolution :> Real {
        doc /* Angular resolution of the LIDAR sensor in degrees */
    }
    
    attribute def MaxRange :> ISQ::LengthValue {
        doc /* Maximum detection range of the LIDAR */
    }
    
    item def LaserPulse {
        attribute wavelength : LaserWavelength;
        attribute power : ISQ::PowerValue;
        attribute emissionTime : ISQ::TimeValue;
    }
    
    item def ReflectedSignal {
        attribute intensity : Real;
        attribute returnTime : ISQ::TimeValue;
        attribute azimuthAngle : Real;
        attribute elevationAngle : Real;
    }
    
    item def Point3D {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
        attribute reflectivity : Real;
    }
    
    item def PointCloud {
        attribute points : Point3D[*] ordered;
        attribute timestamp : ISQ::TimeValue;
        attribute frameId : Integer;
    }
    
    port def LaserEmitterPort {
        out item pulse : LaserPulse;
    }
    
    port def SignalReceiverPort {
        in item signal : ReflectedSignal;
    }
    
    port def PointCloudOutputPort {
        out item cloud : PointCloud;
    }
    
    port def ControlInputPort {
        in item command : ScanCommand;
    }
    
    item def ScanCommand {
        attribute mode : ScanMode;
        attribute targetRate : ISQ::FrequencyValue;
    }
    
    enum def ScanMode {
        continuous;
        singleFrame;
        regionOfInterest;
    }
    
    part def LaserEmitter {
        attribute wavelength : LaserWavelength;
        attribute peakPower : ISQ::PowerValue;
        port emissionPort : LaserEmitterPort;
        
        action emitPulse {
            in power : ISQ::PowerValue;
            in time : ISQ::TimeValue;
            out pulse : LaserPulse;
        }
    }
    
    part def ScanningMirror {
        attribute azimuthSpeed : Real;
        attribute elevationSpeed : Real;
        attribute currentAzimuth : Real;
        attribute currentElevation : Real;
        
        action rotateMirror {
            in targetAzimuth : Real;
            in targetElevation : Real;
            out actualAzimuth : Real;
            out actualElevation : Real;
        }
    }
    
    part def OpticalReceiver {
        attribute sensitivity : Real;
        attribute fieldOfView : Real;
        port receiverPort : SignalReceiverPort;
        
        action captureReflection {
            in reflectedLight : ReflectedSignal;
            out detectedSignal : ReflectedSignal;
        }
    }
    
    part def SignalProcessingUnit {
        attribute processingRate : ISQ::FrequencyValue;
        attribute bufferSize : Integer;
        
        action processSignals {
            in signals : ReflectedSignal[*];
            out pointCloud : PointCloud;
        }
    }
    
    part def MotorDriver {
        attribute maxTorque : Real;
        
        action controlMotor {
            in targetSpeed : Real;
            out actualSpeed : Real;
        }
    }
    
    action def EmitLaser {
        in wavelength : LaserWavelength;
        in power : ISQ::PowerValue;
        out emittedPulse : LaserPulse;
    }
    
    action def DeflectBeam {
        in pulse : LaserPulse;
        in azimuth : Real;
        in elevation : Real;
        out directedPulse : LaserPulse;
    }
    
    action def MeasureTimeOfFlight {
        in emissionTime : ISQ::TimeValue;
        in returnTime : ISQ::TimeValue;
        out distance : ISQ::LengthValue;
    }
    
    action def ConvertToCartesian {
        in distance : ISQ::LengthValue;
        in azimuth : Real;
        in elevation : Real;
        out point : Point3D;
    }
    
    action def BuildPointCloud {
        in points : Point3D[*];
        in timestamp : ISQ::TimeValue;
        out cloud : PointCloud;
    }
    
    action def PerformEnvironmentalScan {
        doc /* 
            Primary function: Emit laser pulses in a scanning pattern, 
            measure time-of-flight of reflections, and generate a 3D point cloud 
            representing the surrounding environment.
        */
        
        in attribute scanComplete : Boolean;
        
        first start;
        then merge continueScan;
        
        action emit : EmitLaser {
            in wavelength;
            in power;
            out laserPulse : LaserPulse;
        }
        
        then action deflect : DeflectBeam {
            in pulse = emit.laserPulse;
            in azimuth;
            in elevation;
            out directedBeam : LaserPulse;
        }
        
        then action waitForReturn;
        
        then action measure : MeasureTimeOfFlight {
            in emissionTime = emit.laserPulse.emissionTime;
            in returnTime;
            out measuredDistance : ISQ::LengthValue;
        }
        
        then action convert : ConvertToCartesian {
            in distance = measure.measuredDistance;
            in azimuth = deflect.azimuth;
            in elevation = deflect.elevation;
            out spatialPoint : Point3D;
        }
        
        then decide;
            if scanComplete then buildCloud;
            if not scanComplete then continueScan;
        
        action buildCloud : BuildPointCloud {
            in points;
            in timestamp;
            out finalCloud : PointCloud;
        }
        
        then done;
    }
    
    state def LIDAROperationalStates {
        entry; then standby;
        
        state standby;
        
        transition standby_to_initializing
            first standby
            accept powerOn
            then initializing;
        
        state initializing;
        
        transition initializing_to_ready
            first initializing
            accept calibrationComplete
            then ready;
        
        state ready;
        
        transition ready_to_scanning
            first ready
            accept startScanCommand
            then scanning;
        
        state scanning;
        
        transition scanning_to_processing
            first scanning
            accept frameAcquired
            then processing;
        
        state processing;
        
        transition processing_to_scanning
            first processing
            accept continuousMode
            then scanning;
        
        transition processing_to_ready
            first processing
            accept singleFrameMode
            then ready;
        
        transition scanning_to_fault
            first scanning
            accept errorDetected
            then fault;
        
        state fault;
        
        transition fault_to_standby
            first fault
            accept resetCommand
            then standby;
    }
    
    part def LIDARSensor {
        attribute maxRange : MaxRange;
        attribute scanRate : ScanRate;
        attribute angularResolution : AngularResolution;
        attribute horizontalFOV : Real;
        attribute verticalFOV : Real;
        
        port controlInput : ControlInputPort;
        port dataOutput : PointCloudOutputPort;
        
        part emitter : LaserEmitter {
            attribute :>> wavelength = 905[nm];
            attribute :>> peakPower = 50[W];
        }
        
        part scanMirror : ScanningMirror {
            attribute :>> azimuthSpeed = 300.0;
            attribute :>> elevationSpeed = 100.0;
        }
        
        part receiver : OpticalReceiver {
            attribute :>> sensitivity = 0.98;
            attribute :>> fieldOfView = 0.2;
        }
        
        part processor : SignalProcessingUnit {
            attribute :>> processingRate = 2000000[Hz];
            attribute :>> bufferSize = 100000;
        }
        
        part motorDriver : MotorDriver {
            attribute :>> maxTorque = 0.5;
        }
        
        connection emitterToMirror connect 
            emitter.emissionPort to scanMirror;
        
        connection mirrorToReceiver connect 
            scanMirror to receiver.receiverPort;
        
        connection receiverToProcessor connect 
            receiver to processor;
        
        connection processorToOutput connect 
            processor to dataOutput;
        
        connection controlToMotor connect 
            controlInput to motorDriver;
        
        perform action primaryScan : PerformEnvironmentalScan;
        
        exhibit state operationalBehavior : LIDAROperationalStates;
    }
    
    requirement def <'REQ-LIDAR-001'> EnvironmentalScanningCapability {
        doc /* 
            The LIDAR system shall perform high-resolution three-dimensional 
            environmental scanning by emitting laser pulses, measuring their 
            time-of-flight upon reflection from objects, and generating accurate 
            point cloud data representing the spatial geometry and position of 
            surrounding objects and surfaces.
        */
        
        subject lidar : LIDARSensor;
        
        require constraint rangeRequirement {
            doc /* Maximum detection range shall be at least 100 meters */
            lidar.maxRange >= 100[m]
        }
        
        require constraint scanRateRequirement {
            doc /* Scan rate shall be at least 10 Hz for real-time operation */
            lidar.scanRate >= 10[Hz]
        }
        
        require constraint resolutionRequirement {
            doc /* Angular resolution shall be 0.1 degrees or finer */
            lidar.angularResolution <= 0.1
        }
    }
    
    requirement def <'REQ-LIDAR-002'> PointCloudOutputRequirement {
        doc /* The system shall output structured point cloud data containing 3D coordinates and reflectivity */
        
        subject sensor : LIDARSensor;
    }
    
    requirement def <'REQ-LIDAR-003'> FieldOfViewRequirement {
        doc /* The system shall provide adequate field of view coverage */
        
        subject sensor : LIDARSensor;
        
        require constraint horizontalFOVRequirement {
            doc /* Horizontal field of view shall be at least 360 degrees */
            sensor.horizontalFOV >= 360.0
        }
        
        require constraint verticalFOVRequirement {
            doc /* Vertical field of view shall be at least 30 degrees */
            sensor.verticalFOV >= 30.0
        }
    }
    
    part lidarSystem : LIDARSensor {
        attribute :>> maxRange = 150[m];
        attribute :>> scanRate = 20[Hz];
        attribute :>> angularResolution = 0.08;
        attribute :>> horizontalFOV = 360.0;
        attribute :>> verticalFOV = 40.0;
        
        satisfy <'REQ-LIDAR-001'> by lidarSystem;
        satisfy <'REQ-LIDAR-002'> by lidarSystem;
        satisfy <'REQ-LIDAR-003'> by lidarSystem;
        
        perform action mainFunction : PerformEnvironmentalScan {
            in wavelength = 905[nm];
            in power = 50[W];
            in scanComplete = false;
            out environmentalMap : PointCloud;
        }
    }
}
