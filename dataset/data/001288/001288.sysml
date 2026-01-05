package TimeOfFlightCameraSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def DepthResolution {
        attribute horizontalPixels : Integer;
        attribute verticalPixels : Integer;
    }

    attribute def DepthRange {
        attribute minDistance : LengthValue;
        attribute maxDistance : LengthValue;
    }

    attribute def DepthMap {
        attribute resolution : DepthResolution;
        attribute depthValues : LengthValue[*] ordered;
        attribute timestamp : TimeValue;
    }

    attribute def LightPulse {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute emissionTime : TimeValue;
    }

    attribute def ReflectedSignal {
        attribute intensity : Real;
        attribute timeOfFlight : TimeValue;
        attribute pixelX : Integer;
        attribute pixelY : Integer;
    }

    port def DepthDataPort {
        out depthMap : DepthMap;
    }

    port def PowerPort {
        in voltage : ElectricPotentialValue;
        in current : ElectricCurrentValue;
    }

    port def ControlPort {
        in captureCommand : Boolean;
        out status : String;
    }

    part def LaserEmitter {
        attribute emissionWavelength : LengthValue;
        attribute pulseFrequency : FrequencyValue;
        attribute emissionPower : PowerValue;

        port powerIn : PowerPort;

        action emitPulse {
            out pulse : LightPulse;
            out emissionTimestamp : TimeValue;
        }
    }

    part def PhotodetectorArray {
        attribute arrayResolution : DepthResolution;
        attribute sensitivity : Real;
        attribute quantumEfficiency : Real;

        port powerIn : PowerPort;

        action detectReflection {
            in reflectedLight : LightPulse;
            out signal : ReflectedSignal;
            out detectionTimestamp : TimeValue;
        }
    }

    part def TimingCircuit {
        attribute clockFrequency : FrequencyValue;
        attribute timingPrecision : TimeValue;

        port powerIn : PowerPort;

        action measureTimeOfFlight {
            in emissionTime : TimeValue;
            in detectionTime : TimeValue;
            out tof : TimeValue;
        }
    }

    part def DepthProcessor {
        attribute speedOfLight : SpeedValue;

        port powerIn : PowerPort;

        action calculateDepth {
            in tof : TimeValue;
            out distance : LengthValue;
        }

        action generateDepthMap {
            in signals : ReflectedSignal[*];
            in distances : LengthValue[*];
            in resolution : DepthResolution;
            out depthMap : DepthMap;
        }
    }

    part def OpticalSystem {
        attribute focalLength : LengthValue;
        attribute aperture : Real;
        attribute fieldOfView : Real;

        action focusLight {
            in incomingLight : LightPulse;
            out focusedLight : LightPulse;
        }
    }

    action def CaptureDepthFrame {
        in captureRequest : Boolean;
        out depthFrame : DepthMap;

        first start;
        then action emitLight {
            out emittedPulse : LightPulse;
            out emissionTimestamp : TimeValue;
        }
        then action propagateToScene;
        then action reflectFromScene;
        then action focusReflection {
            in reflectedPulse : LightPulse;
            out focusedPulse : LightPulse;
        }
        then action detectReflections {
            in focusedSignals : LightPulse;
            out detectedSignals : ReflectedSignal[*];
            out detectionTimestamp : TimeValue;
        }
        then action computeTOF {
            in emitTime : TimeValue = emitLight.emissionTimestamp;
            in detectTime : TimeValue = detectReflections.detectionTimestamp;
            out timeOfFlight : TimeValue;
        }
        then action calculateDistances {
            in tofValue : TimeValue = computeTOF.timeOfFlight;
            out distances : LengthValue[*];
        }
        then action assembleDepthMap {
            in distanceData : LengthValue[*] = calculateDistances.distances;
            in signalData : ReflectedSignal[*] = detectReflections.detectedSignals;
            out finalDepthMap : DepthMap;
        }
        then done;
    }

    part def ToFCamera {
        attribute operatingWavelength : LengthValue;
        attribute depthResolution : DepthResolution;
        attribute depthRange : DepthRange;
        attribute frameRate : FrequencyValue;
        attribute depthAccuracy : LengthValue;

        port powerSupply : PowerPort;
        port controlInterface : ControlPort;
        port dataOutput : DepthDataPort;

        part emitter : LaserEmitter {
            attribute :>> emissionWavelength = operatingWavelength;
            attribute :>> pulseFrequency = frameRate;
        }

        part optics : OpticalSystem;

        part detector : PhotodetectorArray {
            attribute :>> arrayResolution = depthResolution;
        }

        part timer : TimingCircuit;

        part processor : DepthProcessor {
            attribute :>> speedOfLight = 299792458.0 [m/s];
        }

        connection emitterPower connect powerSupply to emitter.powerIn;
        connection detectorPower connect powerSupply to detector.powerIn;
        connection timerPower connect powerSupply to timer.powerIn;
        connection processorPower connect powerSupply to processor.powerIn;

        action captureDepth : CaptureDepthFrame {
            in captureRequest = controlInterface.captureCommand;
            out depthFrame;
        }

        perform captureDepth[*] ordered;

        part emitterSubsystem : LaserEmitter {
            perform captureDepth.emitLight;
        }

        part opticsSubsystem : OpticalSystem {
            perform captureDepth.focusReflection;
        }

        part detectorSubsystem : PhotodetectorArray {
            perform captureDepth.detectReflections;
        }

        part timerSubsystem : TimingCircuit {
            perform captureDepth.computeTOF;
        }

        part processorSubsystem : DepthProcessor {
            perform captureDepth.calculateDistances;
            perform captureDepth.assembleDepthMap;
        }

        binding captureDepth.assembleDepthMap.finalDepthMap = dataOutput.depthMap;
    }

    part tofCameraSystem : ToFCamera {
        attribute :>> operatingWavelength = 850.0 [nm];
        attribute :>> depthResolution = DepthResolution {
            attribute :>> horizontalPixels = 640;
            attribute :>> verticalPixels = 480;
        }
        attribute :>> depthRange = DepthRange {
            attribute :>> minDistance = 0.1 [m];
            attribute :>> maxDistance = 10.0 [m];
        }
        attribute :>> frameRate = 30.0 [Hz];
        attribute :>> depthAccuracy = 0.01 [m];
    }

    requirement def DepthMeasurementRequirement {
        doc /* The ToF camera shall measure distance to objects by emitting modulated light pulses
             and calculating the time difference between emission and detection of reflected signals. */

        subject camera : ToFCamera;

        require constraint {
            camera.depthAccuracy <= 0.02 [m]
        }
    }

    requirement def OperationalRangeRequirement {
        doc /* The ToF camera shall operate within specified minimum and maximum distance ranges
             for accurate depth measurement across the entire field of view. */

        subject camera : ToFCamera;

        require constraint {
            camera.depthRange.minDistance >= 0.05 [m] and
            camera.depthRange.maxDistance <= 15.0 [m]
        }
    }

    requirement def FrameRateRequirement {
        doc /* The ToF camera shall capture depth frames at a minimum rate to support
             real-time applications such as gesture recognition and obstacle detection. */

        subject camera : ToFCamera;

        require constraint {
            camera.frameRate >= 15.0 [Hz]
        }
    }

    requirement def ResolutionRequirement {
        doc /* The ToF camera shall provide sufficient spatial resolution to distinguish
             objects and features within the operational range. */

        subject camera : ToFCamera;

        require constraint {
            camera.depthResolution.horizontalPixels >= 320 and
            camera.depthResolution.verticalPixels >= 240
        }
    }
}
