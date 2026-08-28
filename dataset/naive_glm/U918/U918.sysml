package ToFCameraSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    def Distance :> Real {
        unit m;
    }
    def TimeValue :> Real {
        unit s;
    }
    def FrequencyValue :> Real {
        unit Hz;
    }
    def PowerValue :> Real {
        unit W;
    }
    def VoltageValue :> Real {
        unit V;
    }
    def CurrentValue :> Real {
        unit A;
    }
    def PixelCount :> Integer;
    def FrameRateValue :> Real {
        unit fps;
    }
    def SpeedValue :> Real {
        unit m/s;
    }

    attribute def SpeedOfLight : SpeedValue = 299792458 [m/s];

    // ---- Item Types ----
    item def LightPulse {
        attribute emissionTime : TimeValue;
        attribute wavelength : Distance = 850e-9 [m];
        attribute duration : TimeValue;
    }
    item def ReflectedLight {
        attribute intensity : Real;
        attribute arrivalTime : TimeValue;
        attribute pixelRow : PixelCount;
        attribute pixelCol : PixelCount;
    }
    item def DepthMap {
        attribute width : PixelCount = 640;
        attribute height : PixelCount = 480;
        attribute distances : Distance[0..*];
        attribute frameRate : FrameRateValue = 30 [fps];
    }
    item def CaptureCommand {
        attribute timestamp : TimeValue;
    }
    item def PowerSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    // ---- Port Definitions ----
    port def PowerPort {
        out power : PowerSignal;
    }
    port def CommandPort {
        in command : CaptureCommand;
    }
    port def DataPort {
        out depthMap : DepthMap;
    }
    port def OpticalEmissionPort {
        out pulse : LightPulse;
    }
    port def OpticalReceptionPort {
        in reflection : ReflectedLight;
    }
    port def TimingSignalPort {
        out emissionTimestamp : TimeValue;
        out detectionTimestamp : TimeValue;
    }
    port def PixelDataPort {
        out pixelRow : PixelCount;
        out pixelCol : PixelCount;
        out detectionTime : TimeValue;
    }
    port def ControlSignalPort {
        in trigger : CaptureCommand;
        out emissionTrigger : Boolean;
    }

    // ---- Parts ----
    part def LaserEmitter {
        attribute wavelength : Distance = 850e-9 [m];
        attribute maxPulseDuration : TimeValue = 5e-9 [s];
        attribute peakPower : PowerValue = 1.0 [W];

        port emissionPort : OpticalEmissionPort;
        port controlPort : ControlSignalPort;

        action def EmitPulse {
            in trigger : Boolean;
            out pulse : LightPulse;
        }
    }

    part def OpticalSystem {
        attribute focalLength : Distance = 4.0e-3 [m];
        attribute aperture : Distance = 8.0e-3 [m];
        attribute transmissionEfficiency : Real = 0.92;

        port receptionPort : OpticalReceptionPort;
        port focusedOutput : OpticalReceptionPort;

        action def FocusLight {
            in incoming : ReflectedLight;
            out focused : ReflectedLight;
        }
    }

    part def PhotodetectorArray {
        attribute width : PixelCount = 640;
        attribute height : PixelCount = 480;
        attribute quantumEfficiency : Real = 0.55;
        attribute minRange : Distance = 0.1 [m];
        attribute maxRange : Distance = 10.0 [m];

        port opticalInput : OpticalReceptionPort;
        port pixelOutput : PixelDataPort;

        action def DetectLight {
            in reflection : ReflectedLight;
            out pixelRow : PixelCount;
            out pixelCol : PixelCount;
            out detectionTime : TimeValue;
        }
    }

    part def TimingCircuit {
        attribute clockResolution : TimeValue = 1e-12 [s];
        attribute jitter : TimeValue = 50e-12 [s];

        port controlPort : ControlSignalPort;
        port timingOutput : TimingSignalPort;
        port pixelInput : PixelDataPort;

        action def MeasureTimeOfFlight {
            in emissionTime : TimeValue;
            in detectionTime : TimeValue;
            out roundTripTime : TimeValue;
        }
    }

    part def DepthProcessor {
        attribute frameRate : FrameRateValue = 30 [fps];
        attribute depthAccuracy : Distance = 0.01 [m];
        attribute speedOfLight : SpeedValue = 299792458 [m/s];

        port timingInput : TimingSignalPort;
        port dataOutput : DataPort;

        action def CalculateDistance {
            in roundTripTime : TimeValue;
            out distance : Distance;
        }

        action def AssembleDepthMap {
            in distances : Distance[0..*];
            out depthMap : DepthMap;
        }
    }

    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 12.0 [V];
        attribute maxCurrent : CurrentValue = 2.0 [A];

        port powerOutput : PowerPort;
    }

    part def ToFCamera {
        attribute resolutionWidth : PixelCount = 640;
        attribute resolutionHeight : PixelCount = 480;
        attribute effectiveRangeMin : Distance = 0.1 [m];
        attribute effectiveRangeMax : Distance = 10.0 [m];
        attribute depthAccuracy : Distance = 0.01 [m];
        attribute frameRate : FrameRateValue = 30 [fps];

        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port dataOut : DataPort;

        part laser : LaserEmitter;
        part optics : OpticalSystem;
        part detector : PhotodetectorArray;
        part timing : TimingCircuit;
        part processor : DepthProcessor;

        connection laser.emissionPort to optics.receptionPort;
        connection optics.focusedOutput to detector.opticalInput;
        connection detector.pixelOutput to timing.pixelInput;
        connection timing.timingOutput to processor.timingInput;
        connection processor.dataOutput to dataOut;

        // State machine describing camera operation
        state def CameraOperation {
            entry; then Idle;
            state Idle;
            transition from Idle to Emitting
                when commandIn.command->notEmpty() {
                laser.controlPort.trigger := commandIn.command;
            }
            state Emitting {
                entry {
                    laser.EmitPulse(trigger := true, pulse := LightPulse{emissionTime := now()});
                }
            }
            transition from Emitting to Detecting
                when detector.pixelOutput.detectionTime->notEmpty();
            state Detecting {
                entry {
                    detector.DetectLight();
                }
            }
            transition from Detecting to Measuring
                when timing.timingOutput.detectionTimestamp->notEmpty();
            state Measuring {
                entry {
                    timing.MeasureTimeOfFlight();
                }
            }
            transition from Measuring to Processing
                when processor.timingInput.detectionTimestamp->notEmpty();
            state Processing {
                entry {
                    processor.CalculateDistance();
                    processor.AssembleDepthMap();
                }
            }
            transition from Processing to Idle
                when dataOut.depthMap->notEmpty();
        }

        exhibit state CameraOperation;
    }

    // ---- Requirements ----
    requirement def ResolutionRequirement {
        attribute requiredWidth : PixelCount = 640;
        attribute requiredHeight : PixelCount = 480;
        require camera.resolutionWidth == requiredWidth;
        require camera.resolutionHeight == requiredHeight;
    }

    requirement def RangeRequirement {
        attribute minRange : Distance = 0.1 [m];
        attribute maxRange : Distance = 10.0 [m];
        require camera.effectiveRangeMin <= minRange;
        require camera.effectiveRangeMax >= maxRange;
    }

    requirement def AccuracyRequirement {
        attribute requiredAccuracy : Distance = 0.01 [m];
        require camera.depthAccuracy <= requiredAccuracy;
    }

    requirement def FrameRateRequirement {
        attribute requiredFrameRate : FrameRateValue = 30 [fps];
        require camera.frameRate >= requiredFrameRate;
    }

    requirement def PowerRequirement {
        attribute requiredVoltage : VoltageValue = 12.0 [V];
        require powerSupply.outputVoltage == requiredVoltage;
    }

    requirement def InterfaceRequirement {
        require camera.powerIn.provided;
        require camera.commandIn.provided;
        require camera.dataOut.provided;
    }

    part camera : ToFCamera;
    part powerSupply : PowerSupply;
    connection powerSupply.powerOutput to camera.powerIn;

    satisfy ResolutionRequirement by camera;
    satisfy RangeRequirement by camera;
    satisfy AccuracyRequirement by camera;
    satisfy FrameRateRequirement by camera;
    satisfy PowerRequirement by powerSupply;
    satisfy InterfaceRequirement by camera;
}

package ToFCameraTest {
    import ToFCameraSystem::*;

    part def TestBench {
        part power : PowerSupply;
        part unitUnderTest : ToFCamera;
        connection power.powerOutput to unitUnderTest.powerIn;

        action def RunCaptureTest {
            in command : CaptureCommand;
            out result : DepthMap;
        }

        action def VerifyDepthAccuracy {
            in depthMap : DepthMap;
            in expectedDistance : Distance;
            attribute tolerance : Distance = 0.01 [m];
        }
    }

    part testBench : TestBench;

    verify AccuracyRequirement by testBench.VerifyDepthAccuracy;
    verify FrameRateRequirement by testBench.RunCaptureTest;
}
