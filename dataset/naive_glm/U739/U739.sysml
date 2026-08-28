package LIDAR_Perception_System {
    import ScalarValues::*;
    import SI::*;

    // ---- Value types with units ----
    value def Length_m :> Real { unit "m"; }
    value def Time_ns :> Real { unit "ns"; }
    value def Time_s :> Real { unit "s"; }
    value def Angle_deg :> Real { unit "deg"; }
    value def Frequency_Hz :> Real { unit "Hz"; }
    value def Rate_Hz :> Real { unit "Hz"; }
    value def Velocity_mps :> Real { unit "m/s"; }
    value def Reflectivity :> Real { unit "%"; }

    // ---- Item definitions ----
    item def LaserPulse {
        attribute pulseId : Integer;
        attribute timestamp : Time_ns;
        attribute wavelength : Length_m;
        attribute energy : Real;
        attribute mirrorAngleH : Angle_deg;
        attribute mirrorAngleV : Angle_deg;
    }

    item def Reflection {
        attribute pulseId : Integer;
        attribute returnTimestamp : Time_ns;
        attribute intensity : Reflectivity;
    }

    item def Point3D {
        attribute x : Length_m;
        attribute y : Length_m;
        attribute z : Length_m;
        attribute intensity : Reflectivity;
        attribute timestamp : Time_ns;
    }

    item def PointCloud {
        attribute frameId : Integer;
        attribute timestamp : Time_ns;
        attribute points : Point3D[0..*];
        attribute pointCount : Integer;
    }

    item def MotorCommand {
        attribute targetAngleH : Angle_deg;
        attribute targetAngleV : Angle_deg;
        attribute rotationSpeed : Rate_Hz;
    }

    item def ScanCommand {
        attribute mode : String; // "continuous" or "singleFrame"
        attribute frameCount : Integer;
    }

    item def StatusReport {
        attribute currentState : String;
        attribute errorCode : Integer;
        attribute lastFrameId : Integer;
    }

    // ---- Port definitions ----
    port def LaserOutPort {
        out item : LaserPulse;
    }

    port def LaserInPort {
        in item : LaserPulse;
    }

    port def ReflectionOutPort {
        out item : Reflection;
    }

    port def ReflectionInPort {
        in item : Reflection;
    }

    port def MotorCommandOutPort {
        out item : MotorCommand;
    }

    port def MotorCommandInPort {
        in item : MotorCommand;
    }

    port def ScanCommandInPort {
        in item : ScanCommand;
    }

    port def PointCloudOutPort {
        out item : PointCloud;
    }

    port def StatusOutPort {
        out item : StatusReport;
    }

    // ---- Part definitions ----
    part def LaserEmitter {
        port laserOut : LaserOutPort;
        attribute pulseRate : Rate_Hz = 200000;
        attribute wavelength : Length_m = 905e-6;
        attribute pulseEnergy : Real = 1.0;
        attribute enabled : Boolean = false;

        action def EmitPulse {
            in angleH : Angle_deg;
            in angleV : Angle_deg;
            out pulse : LaserPulse;
        }

        perform action emit : EmitPulse {
            in angleH;
            in angleV;
            out pulse;
        }
    }

    part def ScanningMirror {
        port laserIn : LaserInPort;
        port laserOut : LaserOutPort;
        port motorIn : MotorCommandInPort;
        attribute horizontalFOV : Angle_deg = 360;
        attribute verticalFOV : Angle_deg = 40;
        attribute currentAngleH : Angle_deg = 0;
        attribute currentAngleV : Angle_deg = 0;

        action def DirectPulse {
            in incoming : LaserPulse;
            in angleH : Angle_deg;
            in angleV : Angle_deg;
            out directed : LaserPulse;
        }

        perform action direct : DirectPulse {
            in incoming;
            in angleH;
            in angleV;
            out directed;
        }
    }

    part def Motor {
        port control : MotorCommandInPort;
        attribute rotationSpeed : Rate_Hz = 20;
        attribute currentAngleH : Angle_deg = 0;
        attribute currentAngleV : Angle_deg = 0;

        action def Rotate {
            in command : MotorCommand;
            out angleH : Angle_deg;
            out angleV : Angle_deg;
        }

        perform action rotate : Rotate {
            in command;
            out angleH;
            out angleV;
        }
    }

    part def OpticalReceiver {
        port reflectionOut : ReflectionOutPort;
        attribute sensitivity : Real = 0.95;
        attribute detectionThreshold : Real = 0.01;

        action def CaptureReflection {
            in incomingLight : Reflection;
            out captured : Reflection;
        }

        perform action capture : CaptureReflection {
            in incomingLight;
            out captured;
        }
    }

    part def SignalProcessingUnit {
        port reflectionIn : ReflectionInPort;
        port cloudOut : PointCloudOutPort;
        port commandIn : ScanCommandInPort;
        port statusOut : StatusOutPort;
        port motorControl : MotorCommandOutPort;
        attribute maxRange : Length_m = 150;
        attribute scanRate : Rate_Hz = 20;
        attribute speedOfLight : Velocity_mps = 299792458;
        attribute currentFrameId : Integer = 0;
        attribute pointBuffer : Point3D[0..*];

        action def CalculateTimeOfFlight {
            in reflection : Reflection;
            in pulseTimestamp : Time_ns;
            out distance : Length_m;
            out point : Point3D;
        }

        action def AssemblePointCloud {
            in points : Point3D[0..*];
            out cloud : PointCloud;
        }

        action def ProcessFrame {
            in reflections : Reflection[0..*];
            out cloud : PointCloud;
        }

        perform action processFrame : ProcessFrame {
            in reflections;
            out cloud;
        }
    }

    // ---- Composite LIDAR system ----
    part def LIDARSystem {
        port commandIn : ScanCommandInPort;
        port cloudOut : PointCloudOutPort;
        port statusOut : StatusOutPort;
        port opticalOut : LaserOutPort;
        port opticalIn : ReflectionInPort;

        attribute maxRange : Length_m = 150;
        attribute scanRate : Rate_Hz = 20;
        attribute horizontalFOV : Angle_deg = 360;
        attribute verticalFOV : Angle_deg = 40;
        attribute pulseRate : Rate_Hz = 200000;

        part emitter : LaserEmitter;
        part mirror : ScanningMirror;
        part motor : Motor;
        part receiver : OpticalReceiver;
        part processor : SignalProcessingUnit;

        // Internal connections
        connection emitter.laserOut to mirror.laserIn;
        connection mirror.laserOut to opticalOut;
        connection opticalIn to receiver.reflectionOut;
        connection receiver.reflectionOut to processor.reflectionIn;
        connection processor.motorControl to motor.control;
        connection motor.control to mirror.motorIn;
        connection processor.cloudOut to cloudOut;
        connection commandIn to processor.commandIn;
        connection processor.statusOut to statusOut;

        // ---- State machine ----
        state def LIDARStateMachine {
            attribute powered : Boolean = false;
            attribute calibrationComplete : Boolean = false;
            attribute calibrationFailed : Boolean = false;
            attribute scanCommand : Boolean = false;
            attribute scanComplete : Boolean = false;
            attribute errorDetected : Boolean = false;
            attribute reset : Boolean = false;

            state standby {
                entry { powered := false; }
            }
            state initializing {
                entry { calibrationComplete := false; calibrationFailed := false; }
            }
            state ready {
                entry { scanCommand := false; }
            }
            state activeScanning {
                entry { scanComplete := false; }
            }
            state fault {
                entry { reset := false; }
            }

            transition from standby to initializing when powered;
            transition from initializing to ready when calibrationComplete;
            transition from initializing to fault when calibrationFailed;
            transition from ready to activeScanning when scanCommand;
            transition from activeScanning to ready when scanComplete;
            transition from ready to fault when errorDetected;
            transition from activeScanning to fault when errorDetected;
            transition from fault to standby when reset;
        }

        exhibit state behavior : LIDARStateMachine;
    }

    // ---- Requirements ----
    requirement def MaxRangeRequirement {
        doc { The LIDAR shall have a maximum effective range of at least 150 m. }
        attribute requiredRange : Length_m = 150;
        subject lidar : LIDARSystem;
        require { lidar.maxRange >= requiredRange; }
    }

    requirement def ScanRateRequirement {
        doc { The LIDAR shall scan at least 20 times per second. }
        attribute requiredRate : Rate_Hz = 20;
        subject lidar : LIDARSystem;
        require { lidar.scanRate >= requiredRate; }
    }

    requirement def FieldOfViewRequirement {
        doc { The LIDAR shall cover 360 deg horizontally and 40 deg vertically. }
        attribute requiredHorizontalFOV : Angle_deg = 360;
        attribute requiredVerticalFOV : Angle_deg = 40;
        subject lidar : LIDARSystem;
        require { lidar.horizontalFOV >= requiredHorizontalFOV; }
        require { lidar.verticalFOV >= requiredVerticalFOV; }
    }

    requirement def PointCloudOutputRequirement {
        doc { The LIDAR shall output a point cloud containing 3D points with reflectivity. }
        subject lidar : LIDARSystem;
        require { lidar.cloudOut.item.points->size() > 0; }
    }

    requirement def StateBehaviorRequirement {
        doc { The LIDAR shall implement standby, initializing, ready, activeScanning, and fault states. }
        subject lidar : LIDARSystem;
        require { lidar.LIDARStateMachine.ownedState->size() >= 5; }
    }

    requirement def TimeOfFlightRequirement {
        doc { The LIDAR shall compute distance using time-of-flight measurement. }
        subject processor : SignalProcessingUnit;
        require { processor.maxRange <= 150; }
    }

    requirement def PulseRateRequirement {
        doc { The LIDAR shall emit hundreds of thousands of pulses per second. }
        attribute minPulseRate : Rate_Hz = 100000;
        subject emitter : LaserEmitter;
        require { emitter.pulseRate >= minPulseRate; }
    }

    requirement def LIDARSystemRequirements {
        requirement r1 : MaxRangeRequirement;
        requirement r2 : ScanRateRequirement;
        requirement r3 : FieldOfViewRequirement;
        requirement r4 : PointCloudOutputRequirement;
        requirement r5 : StateBehaviorRequirement;
        requirement r6 : TimeOfFlightRequirement;
        requirement r7 : PulseRateRequirement;
    }
}
