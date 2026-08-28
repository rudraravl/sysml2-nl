package RangeImagingSystem {
    import ScalarValues::*;

    value type Distance :> Real { unit "m"; }
    value type Duration :> Real { unit "s"; }
    value type Power :> Real { unit "W"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Angle :> Real { unit "deg"; }
    value type Intensity :> Real { unit "lux"; }
    value type Wavelength :> Distance { unit "nm"; }
    value type PixelValue :> Distance { unit "m"; }

    item def Trigger;

    item def LaserPulse {
        attribute wavelength : Wavelength = 905 [nm];
        attribute power : Power;
        attribute timestamp : Duration;
    }

    item def Reflection {
        attribute intensity : Intensity;
        attribute timestamp : Duration;
    }

    item def EmissionTiming {
        attribute timestamp : Duration;
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }

    item def DetectorSignal {
        attribute intensity : Intensity;
        attribute timestamp : Duration;
    }

    item def RawPointData {
        attribute distance : Distance;
        attribute intensity : Intensity;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute timestamp : Duration;
    }

    item def Point3D {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute intensity : Intensity;
    }

    item def DepthMap {
        attribute width : Integer = 640;
        attribute height : Integer = 480;
        attribute frameRate : Frequency = 10 [Hz];
        attribute maxRange : Distance = 200 [m];
        attribute pixels : PixelValue[0..*];
    }

    item def PointCloud {
        attribute pointCount : Integer = 300000;
        attribute frameRate : Frequency = 10 [Hz];
        attribute points : Point3D[0..*];
    }

    port def TriggerInPort {
        in item trigger : Trigger;
    }

    port def LaserOutPort {
        out item pulse : LaserPulse;
    }

    port def LaserInPort {
        in item pulse : LaserPulse;
    }

    port def ReflectionOutPort {
        out item reflection : Reflection;
    }

    port def ReflectionInPort {
        in item reflection : Reflection;
    }

    port def TimingOutPort {
        out item timing : EmissionTiming;
    }

    port def TimingInPort {
        in item timing : EmissionTiming;
    }

    port def SignalOutPort {
        out item signal : DetectorSignal;
    }

    port def SignalInPort {
        in item signal : DetectorSignal;
    }

    port def RawOutPort {
        out item raw : RawPointData;
    }

    port def RawInPort {
        in item raw : RawPointData;
    }

    port def DepthMapOutPort {
        out item map : DepthMap;
    }

    port def DepthMapInPort {
        in item map : DepthMap;
    }

    port def PointCloudOutPort {
        out item cloud : PointCloud;
    }

    port def PointCloudInPort {
        in item cloud : PointCloud;
    }

    part def LaserEmitter {
        port out laserOut : LaserOutPort;
        port out timingOut : TimingOutPort;
        attribute power : Power = 20 [W];
        attribute pulseRate : Frequency = 300000 [Hz];

        action emitPulse {
            out pulse : LaserPulse;
            out timing : EmissionTiming;
        }
    }

    part def ScanningMirror {
        port in laserIn : LaserInPort;
        port out beamOut : LaserOutPort;
        port in reflectedIn : ReflectionInPort;
        port out reflectedOut : ReflectionOutPort;
        attribute horizontalFOV : Angle = 120 [deg];
        attribute verticalFOV : Angle = 30 [deg];
        attribute sweepRate : Frequency = 10 [Hz];

        action sweep {
            in pulse : LaserPulse;
            out directedPulse : LaserPulse;
            in reflection : Reflection;
            out reflectedBeam : Reflection;
        }
    }

    part def Environment {
        port in emittedBeam : LaserInPort;
        port out reflectedBeam : ReflectionOutPort;

        action reflect {
            in pulse : LaserPulse;
            out reflection : Reflection;
        }
    }

    part def PhotodetectorArray {
        port in reflectionIn : ReflectionInPort;
        port out signalOut : SignalOutPort;
        attribute detectionRate : Frequency = 300000 [Hz];
        attribute sensitivity : Intensity = 0.01 [lux];

        action detect {
            in reflection : Reflection;
            out signal : DetectorSignal;
        }
    }

    part def TimeOfFlightProcessor {
        port in timingIn : TimingInPort;
        port in signalIn : SignalInPort;
        port out rawOut : RawOutPort;
        attribute processingRate : Frequency = 300000 [Hz];
        attribute speedOfLight : Real = 299792458 [m/s];

        action computeDistance {
            in timing : EmissionTiming;
            in signal : DetectorSignal;
            out raw : RawPointData;

            attribute roundTripTime : Duration = signal.timestamp - timing.timestamp;
            attribute distance : Distance = roundTripTime * speedOfLight / 2;
            attribute azimuth : Angle = timing.azimuth;
            attribute elevation : Angle = timing.elevation;
            attribute intensity : Intensity = signal.intensity;
        }
    }

    part def DepthMapGenerator {
        port in rawIn : RawInPort;
        port out mapOut : DepthMapOutPort;
        attribute width : Integer = 640;
        attribute height : Integer = 480;
        attribute frameRate : Frequency = 10 [Hz];

        action generateDepthMap {
            in raw : RawPointData;
            out map : DepthMap;
        }
    }

    part def PointCloudProcessor {
        port in rawIn : RawInPort;
        port out cloudOut : PointCloudOutPort;
        attribute maxPoints : Integer = 300000;
        attribute frameRate : Frequency = 10 [Hz];

        action generatePointCloud {
            in raw : RawPointData;
            out cloud : PointCloud;
        }
    }

    part def RangeImagingSystem {
        port in triggerIn : TriggerInPort;
        port out depthMapOut : DepthMapOutPort;
        port out pointCloudOut : PointCloudOutPort;

        part laserEmitter : LaserEmitter;
        part scanningMirror : ScanningMirror;
        part environment : Environment;
        part photodetectorArray : PhotodetectorArray;
        part tofProcessor : TimeOfFlightProcessor;
        part depthMapGenerator : DepthMapGenerator;
        part pointCloudProcessor : PointCloudProcessor;

        connection laserToMirror connect laserEmitter.laserOut to scanningMirror.laserIn;
        connection timingToMirror connect laserEmitter.timingOut to scanningMirror.timingIn;
        connection mirrorToEnv connect scanningMirror.beamOut to environment.emittedBeam;
        connection envToMirror connect environment.reflectedBeam to scanningMirror.reflectedIn;
        connection mirrorToDetector connect scanningMirror.reflectedOut to photodetectorArray.reflectionIn;
        connection detectorToTOF connect photodetectorArray.signalOut to tofProcessor.signalIn;
        connection timingToTOF connect laserEmitter.timingOut to tofProcessor.timingIn;
        connection tofToDepth connect tofProcessor.rawOut to depthMapGenerator.rawIn;
        connection tofToCloud connect tofProcessor.rawOut to pointCloudProcessor.rawIn;
        connection depthOut connect depthMapGenerator.mapOut to depthMapOut;
        connection cloudOut connect pointCloudProcessor.cloudOut to pointCloudOut;

        attribute maxRange : Distance = 200 [m];
        attribute frameRate : Frequency = 10 [Hz];
        attribute powerBudget : Power = 100 [W];
        attribute triggerReceived : Boolean = false;
        attribute scanComplete : Boolean = false;
        attribute processingComplete : Boolean = false;
        attribute outputComplete : Boolean = false;

        state machine Behavior {
            state idle;
            state scanning;
            state processing;
            state outputting;

            transition from idle to scanning when triggerReceived;
            transition from scanning to processing when scanComplete;
            transition from processing to outputting when processingComplete;
            transition from outputting to idle when outputComplete;
        }
    }

    requirement def RangeRequirement {
        attribute requiredRange : Distance = 200 [m];
        subject sensor : RangeImagingSystem;
        require sensor.maxRange >= requiredRange;
    }

    requirement def FrameRateRequirement {
        attribute requiredFrameRate : Frequency = 10 [Hz];
        subject sensor : RangeImagingSystem;
        require sensor.frameRate >= requiredFrameRate;
    }

    requirement def PowerBudgetRequirement {
        attribute maxPower : Power = 100 [W];
        subject sensor : RangeImagingSystem;
        require sensor.powerBudget <= maxPower;
    }

    requirement def FieldOfViewRequirement {
        attribute requiredHorizontalFOV : Angle = 120 [deg];
        attribute requiredVerticalFOV : Angle = 30 [deg];
        subject sensor : RangeImagingSystem;
        require sensor.scanningMirror.horizontalFOV >= requiredHorizontalFOV;
        require sensor.scanningMirror.verticalFOV >= requiredVerticalFOV;
    }

    requirement rangeReq : RangeRequirement {
        subject sensor : RangeImagingSystem;
    }

    requirement frameRateReq : FrameRateRequirement {
        subject sensor : RangeImagingSystem;
    }

    requirement powerReq : PowerBudgetRequirement {
        subject sensor : RangeImagingSystem;
    }

    requirement fovReq : FieldOfViewRequirement {
        subject sensor : RangeImagingSystem;
    }
}
